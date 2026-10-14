--[[
	Drive — the vehicle controller (runs only for the local player's own vehicle).

	Camp mode:  free arcade driving. Throttle/steer come from the VehicleSeat (keyboard, gamepad and the
	            mobile thumbstick all work), ground-following raycasts, bumpers stop you at walls.
	Route mode: the road carries you. You own the speed (hold forward or BOOST to floor it, brake to
	            slow) and the full road width (steer freely, no snapping lanes), and you pick each fork
	            by steering into a branch. Hits knock you sideways and scrub speed.
	Both modes move the vehicle through two rigid constraints on its root (the client owns physics),
	animate the wheels, and drive a chase camera with speed FOV, look-ahead and body roll.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game")
local Config = require(Shared:WaitForChild("Config"))
local Rides = require(Shared:WaitForChild("Rides"))
local RouteMath = require(Shared:WaitForChild("RouteMath"))
local Net = require(script.Parent.Net)
local Cinema = require(script.Parent.UI.Cinema)

local player = Players.LocalPlayer
local Drive = {}

-- input: the seat's ThrottleFloat/SteerFloat (Roblox's vehicle controller fills them for keyboard, gamepad
-- and touch). If the seat reports nothing, fall back to the control module's move vector and then to raw keys.
local controls = nil
task.spawn(function()
	local ok, pm = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10))
	end)
	if ok and pm then controls = pm:GetControls() end
end)
-- (2026-10-12) touch fallback: a phone player whose Roblox thumbstick is gone (hidden by a cutscene, controls left
-- off) could only BOOST. Any drag on the left half of the screen that nothing else took drives the rover:
-- up = gas, down = reverse, sideways = steer.
local touchDrive = { Input = nil :: InputObject?, Start = Vector2.zero, Vec = Vector2.zero }
UserInputService.TouchStarted:Connect(function(input, processed)
	if processed or touchDrive.Input then return end
	local cam = Workspace.CurrentCamera
	if not cam or input.Position.X > cam.ViewportSize.X * 0.5 then return end
	touchDrive.Input = input
	touchDrive.Start = Vector2.new(input.Position.X, input.Position.Y)
	touchDrive.Vec = Vector2.zero
end)
UserInputService.TouchMoved:Connect(function(input)
	if input ~= touchDrive.Input then return end
	local d = Vector2.new(input.Position.X, input.Position.Y) - touchDrive.Start
	touchDrive.Vec = Vector2.new(math.clamp(d.X / 70, -1, 1), math.clamp(-d.Y / 70, -1, 1))
end)
UserInputService.TouchEnded:Connect(function(input)
	if input == touchDrive.Input then touchDrive.Input = nil touchDrive.Vec = Vector2.zero end
end)

local function readInput(seat: VehicleSeat?): (number, number)
	local throttle = seat and seat.ThrottleFloat or 0
	local steer = seat and seat.SteerFloat or 0
	if math.abs(throttle) < 0.01 and math.abs(steer) < 0.01 then
		if controls then
			local ok, mv = pcall(function() return controls:GetMoveVector() end)
			if ok and mv then throttle, steer = -mv.Z, mv.X end
		end
		if math.abs(throttle) < 0.01 and math.abs(steer) < 0.01 and touchDrive.Input then
			throttle, steer = touchDrive.Vec.Y, touchDrive.Vec.X
		end
		if math.abs(throttle) < 0.01 and math.abs(steer) < 0.01 and not UserInputService:GetFocusedTextBox() then
			local k = UserInputService
			throttle = ((k:IsKeyDown(Enum.KeyCode.W) or k:IsKeyDown(Enum.KeyCode.Up)) and 1 or 0) - ((k:IsKeyDown(Enum.KeyCode.S) or k:IsKeyDown(Enum.KeyCode.Down)) and 1 or 0)
			steer = ((k:IsKeyDown(Enum.KeyCode.D) or k:IsKeyDown(Enum.KeyCode.Right)) and 1 or 0) - ((k:IsKeyDown(Enum.KeyCode.A) or k:IsKeyDown(Enum.KeyCode.Left)) and 1 or 0)
		end
	end
	return math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
end

-- public state (HUD / other modules read this)
Drive.State = {
	Mode = "None", -- None | Camp | Route | Frozen
	Vehicle = nil :: Model?, Root = nil :: BasePart?, Seat = nil :: VehicleSeat?,
	Speed = 0, Boosting = false, Boost = 1, Braking = false,
	S = 0, X = 0, Variant = 1, C1 = nil :: number?, C2 = nil :: number?, Route = nil, Zone = nil :: string?,
	Cruise = 42, BoostSpeed = 62, Grip = 1, HalfWidth = 12, Length = 1,
	Steer = 0, Throttle = 0,
	OnFoot = false, -- out of the vehicle on a nest raid
	StopAt = nil :: number?, -- the autopilot pulls over here (a nest)
	LockVariant = nil :: number?, -- a scripted drive follows this branch at every fork
	Toppled = false, -- flipped on its side after a chase wreck (waiting on repair or abandoned)
	Autopilot = true, -- steers itself when you don't
	Frozen = false, -- parked (era map / travel set-up): the autopilot holds still
}
local St = Drive.State
local listeners = {}
function Drive.OnChanged(fn) table.insert(listeners, fn) end
local function changed(what: string) for _, fn in ipairs(listeners) do task.spawn(fn, what) end end

local boostHeld = false
local brakeHeld = false
local camCF: CFrame? = nil
local camFov = 70
local camYaw: number? = nil -- the chase camera's heading: eases after the rover's instead of snapping with it
local camPull = 1 -- 0..1 of the full chase distance (walls pull it in fast, it eases back out)
local faded = {} :: { [BasePart]: boolean } -- small scenery between the lens and the rover, see-through for now
local camShakeKick = 0
local free = { Pos = Vector3.zero, Yaw = 0, V = 0, Up = Vector3.yAxis, Pitch = 0, Roll = 0, Bob = 0, VY = 0, Air = 0, TiltP = 0, TiltR = 0 }
local route = { V = 0, XVel = 0, Yaw = 0, Roll = 0, Knock = 0, Bob = 0, Air = 0, SendAt = 0 }
local wheelSpin = 0
local cameraOverride = false
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function ownedVehicleFor(seat: Instance?): Model?
	if not seat then return nil end
	-- walk up every ancestor Model (the seat sits in a sub-model like Interior) to the one tagged with an Owner
	local m: Instance? = seat.Parent
	while m and not (m:IsA("Model") and m:GetAttribute("Owner") ~= nil) do m = m.Parent end
	if m and m:GetAttribute("Owner") == player.UserId then return m :: Model end
	return nil
end

local function lockJump(on: boolean)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, not on) end
end

local function rootHeight(): number
	if St.Vehicle and St.Vehicle.Parent then return St.Vehicle:GetAttribute("RootHeight") or 2.6 end
	-- (not seated yet - a site picked on foot, a fresh rover: the default 2.6 put a Titan or a lifted build into the
	-- road on the travel's SetRoutePos. Our own rover's real ride height. 2026-10-14)
	local vf = Workspace:FindFirstChild("ActiveVehicles")
	for _, v in ipairs(vf and vf:GetChildren() or {}) do
		if v:GetAttribute("Owner") == player.UserId then return v:GetAttribute("RootHeight") or 2.6 end
	end
	return 2.6
end

local lastTarget: Vector3? = nil
local function setTargets(cf: CFrame)
	local root = St.Root
	if not root then return end
	local ap = root:FindFirstChild("DrivePosition") :: AlignPosition?
	local ao = root:FindFirstChild("DriveOrientation") :: AlignOrientation?
	if ap then ap.Position = cf.Position end
	if ao then ao.CFrame = cf.Rotation end
	lastTarget = cf.Position
end

-- watchdog: this client must simulate its own vehicle. ReceiveAge > 0 means the server is still sending us
-- its physics (we don't own it), and a root far from its target means something holds it. Either way ask
-- the server to fix ownership, and log why so a playtest Output shows the cause.
local watch = { Bad = 0, NextClaim = 0 }
local function watchdog(dt: number)
	local root = St.Root
	-- (free roam too: a rover that wasn't handed back after a stop sat still under the throttle - 2026-10-14)
	if not root or (St.Mode ~= "Camp" and St.Mode ~= "Roam") then watch.Bad = 0 return end
	local notOwner = root.ReceiveAge > 0.25
	local stuck = lastTarget ~= nil and (root.Position - (lastTarget :: Vector3)).Magnitude > 8
	if notOwner or stuck then watch.Bad += dt else watch.Bad = 0 end
	if watch.Bad > 0.8 and os.clock() > watch.NextClaim then
		watch.NextClaim = os.clock() + 4
		warn(string.format("[Drive] vehicle not following (owner=%s, off by %.1f studs) - asking the server to hand it over",
			notOwner and "server" or "me", lastTarget and (root.Position - (lastTarget :: Vector3)).Magnitude or -1))
		task.spawn(function()
			local res = Net.Ask("ClaimVehicle")
			warn("[Drive] claim result:", res and res.Report or (res and res.Err) or "?")
			-- restart from wherever the vehicle really is
			Drive.SyncFromVehicle(0)
		end)
	end
end

--------------------------------------------------------------------------------
-- input: boost (Shift / gamepad X / R1 / touch), brake (touch) — throttle & steer from the seat
--------------------------------------------------------------------------------
local lookBack = false
local function bindInput()
	ContextActionService:BindActionAtPriority("DinoBoost", function(_, state)
		boostHeld = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		if state == Enum.UserInputState.Cancel then boostHeld = false end
		return Enum.ContextActionResult.Sink
	end, false, 2000, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonR1)
	-- hold C (or click the right stick) to look back over the roof at whatever's chasing you
	ContextActionService:BindActionAtPriority("DinoLookBack", function(_, state)
		lookBack = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		return Enum.ContextActionResult.Sink
	end, false, 2000, Enum.KeyCode.C, Enum.KeyCode.ButtonR3)
end
local function unbindInput()
	ContextActionService:UnbindAction("DinoBoost")
	ContextActionService:UnbindAction("DinoLookBack")
	lookBack = false
	boostHeld = false
end

function Drive.SetBoostHeld(on: boolean) boostHeld = on end
function Drive.SetBrakeHeld(on: boolean) brakeHeld = on end

--------------------------------------------------------------------------------
-- camera
--------------------------------------------------------------------------------
-- free look while driving: right-drag (mouse), drag on an empty part of the screen (touch), right stick (pad),
-- wheel / pinch to zoom. It eases back behind the vehicle a couple of seconds after you let go while moving.
local orbit = { Yaw = 0, Pitch = 0, Zoom = 1, LastInput = 0, Dragging = false, Touch = nil :: InputObject? }
local function orbitInput(dx: number, dy: number)
	-- horizontal as you asked; drag down looks down
	orbit.Yaw -= dx * 0.008
	orbit.Pitch = math.clamp(orbit.Pitch + dy * 0.006, -0.35, 0.95)
	orbit.LastInput = os.clock()
end
-- Roblox's dynamic thumbstick doesn't sink its touches (its own camera special-cases them): the finger
-- driving the stick must never orbit the camera too (it swung the view and made steering look inverted)
local function inThumbstick(pos: Vector3): boolean
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local tg = pg and pg:FindFirstChild("TouchGui")
	local fr = tg and (tg:FindFirstChild("DynamicThumbstickFrame", true) or tg:FindFirstChild("ThumbstickFrame", true))
	if fr and fr:IsA("GuiObject") and fr.AbsoluteSize.X > 0 then
		local a, b = fr.AbsolutePosition, fr.AbsolutePosition + fr.AbsoluteSize
		return pos.X >= a.X and pos.X <= b.X and pos.Y >= a.Y and pos.Y <= b.Y
	end
	local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	return pos.X < vp.X * 0.4 and pos.Y > vp.Y / 3 -- Roblox's default stick zone
end
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
		orbit.Dragging = true
	elseif input.UserInputType == Enum.UserInputType.Touch and not processed and not orbit.Touch and not inThumbstick(input.Position) then
		orbit.Touch = input
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then orbit.Dragging = false end
	if orbit.Touch == input then orbit.Touch = nil end
end)
UserInputService.InputChanged:Connect(function(input, processed)
	if St.Mode ~= "Camp" and St.Mode ~= "Route" then return end
	if St.OnFoot then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement and orbit.Dragging then
		orbitInput(input.Delta.X, input.Delta.Y)
	elseif input == orbit.Touch then
		orbitInput(input.Delta.X * 1.4, input.Delta.Y * 1.4)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		orbit.Zoom = math.clamp(orbit.Zoom - input.Position.Z * 0.12, 0.65, 1.9)
	end
end)
UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
	if processed or St.OnFoot or (St.Mode ~= "Camp" and St.Mode ~= "Route") then return end
	if state == Enum.UserInputState.Change then orbit.Zoom = math.clamp(orbit.Zoom / math.clamp(scale, 0.9, 1.1), 0.65, 1.9) end
end)

local function updateCamera(dt: number, rootCF: CFrame, speed: number, boosting: boolean, routeMode: boolean)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	cam.CameraType = Enum.CameraType.Scriptable
	local len = (St.Vehicle and St.Vehicle:GetAttribute("Length")) or 13
	local back = len * 0.62 + 9 + math.clamp(speed, 0, 80) * 0.06
	local up = 5.2 + len * 0.12
	local flat = Vector3.new(rootCF.LookVector.X, 0, rootCF.LookVector.Z)
	if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
	flat = flat.Unit
	-- free driving: the camera's heading follows the rover's with a soft lag, so quick turns and bumps don't
	-- whip the whole view around
	local yaw = math.atan2(-flat.X, -flat.Z)
	if routeMode or not camYaw then camYaw = yaw end
	local dy = math.atan2(math.sin(yaw - (camYaw :: number)), math.cos(yaw - (camYaw :: number)))
	camYaw = (camYaw :: number) + dy * (1 - math.exp(-dt * 3.2))
	local cflat = Vector3.new(-math.sin(camYaw :: number), 0, -math.cos(camYaw :: number))
	local focus = rootCF.Position + Vector3.new(0, 2.2, 0) + cflat * (6 + speed * 0.08)
	local want = rootCF.Position - cflat * back + Vector3.new(0, up, 0)
	-- keep the camera out of walls in camp: only real structure pulls it in (fast in, eased back out); thin things
	-- passing through the shot (palms, lamp posts, signs) used to yank it forward every time - now they fade out
	if not routeMode then
		rayParams.FilterDescendantsInstances = { St.Vehicle, player.Character }
		local origin = rootCF.Position + Vector3.new(0, 3, 0)
		local dir = want - origin
		local hit = Workspace:Raycast(origin, dir, rayParams)
		local pull = 1
		-- (invisible walls - the bridges' BridgeGuard sides - stop the rover, not the camera)
		if hit and hit.Instance:IsA("BasePart") and hit.Instance.Size.Magnitude > 12 and hit.Instance.Transparency < 0.99 then
			pull = math.clamp((hit.Distance - 1.5) / math.max(dir.Magnitude, 1e-3), 0.2, 1)
		end
		camPull = pull < camPull and pull or camPull + (pull - camPull) * (1 - math.exp(-dt * 1.8))
		want = origin + dir * camPull
		-- fade whatever small scenery is still between the lens and the rover
		local fp = RaycastParams.new()
		fp.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { St.Vehicle, player.Character } :: { Instance }
		local now = {} :: { [BasePart]: boolean }
		for _ = 1, 4 do
			fp.FilterDescendantsInstances = skip
			local h = Workspace:Raycast(want, (rootCF.Position + Vector3.new(0, 1.5, 0)) - want, fp)
			if not h then break end
			local part = h.Instance
			if part:IsA("BasePart") and part.Size.Magnitude <= 12 then now[part] = true end
			table.insert(skip, part)
		end
		for part in pairs(faded) do
			if not now[part] then part.LocalTransparencyModifier = 0 faded[part] = nil end
		end
		for part in pairs(now) do
			part.LocalTransparencyModifier = 0.75
			faded[part] = true
		end
	elseif next(faded) then
		for part in pairs(faded) do part.LocalTransparencyModifier = 0 end
		faded = {}
	end
	-- never under the ground or the water (the chase camera dipped into the river at fords): stay a little above
	-- whatever surface is under the lens, water parts included
	do
		local fp = RaycastParams.new()
		fp.FilterType = Enum.RaycastFilterType.Exclude
		fp.FilterDescendantsInstances = { St.Vehicle, player.Character } :: { Instance }
		fp.IgnoreWater = false
		-- (from the rover's own height, never from high above: rolling out of the garage, a ray from 40 up hit the
		-- solid garage roof and parked the camera on top of it, staring at the back of the sign. 2026-10-13)
		local top = math.max(want.Y, focus.Y) + 2
		local h = Workspace:Raycast(Vector3.new(want.X, top, want.Z), Vector3.new(0, -(top - want.Y) - 40, 0), fp)
		-- (only real surfaces count: solid ground or water, never a leafy canopy overhead)
		local surface = h and (h.Material == Enum.Material.Water or h.Instance:IsA("Terrain") or string.find(h.Instance.Name, "Water", 1, true) ~= nil
			or (h.Instance:IsA("BasePart") and h.Instance.CanCollide and h.Instance.Transparency < 0.99)) -- (not the bridges' invisible guards)
		if h and surface and h.Position.Y + 2.2 > want.Y and h.Position.Y < want.Y + 8 then want = Vector3.new(want.X, h.Position.Y + 2.2, want.Z) end
	end
	local target = CFrame.lookAt(want, focus)
	if not camCF then camCF = target end
	local k = 1 - math.exp(-dt * (routeMode and 7 or 6))
	camCF = (camCF :: CFrame):Lerp(target, k)
	local fovWant = 68 + math.clamp(speed - 30, 0, 50) * 0.18 + (boosting and 9 or 0)
	camFov += (fovWant - camFov) * (1 - math.exp(-dt * 4))
	local roll = routeMode and (-route.XVel * 0.004) or 0
	-- free look: gamepad right stick, mouse lock while right-dragging, then orbit the chase shot around the vehicle
	for _, st in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		if st.KeyCode == Enum.KeyCode.Thumbstick2 and st.Position.Magnitude > 0.18 then
			orbitInput(st.Position.X * 900 * dt, -st.Position.Y * 600 * dt)
		end
	end
	UserInputService.MouseBehavior = orbit.Dragging and Enum.MouseBehavior.LockCurrentPosition or Enum.MouseBehavior.Default
	if lookBack then
		-- swing round to look behind the rover (eased, a touch higher so the road behind is in view)
		local d = math.atan2(math.sin(math.pi - orbit.Yaw), math.cos(math.pi - orbit.Yaw))
		orbit.Yaw += d * math.min(1, dt * 9)
		orbit.Pitch += (0.12 - orbit.Pitch) * math.min(1, dt * 6)
		orbit.LastInput = os.clock() - 1.6 -- swings back quickly once you let go
	end
	if os.clock() - orbit.LastInput > 2.2 and speed > 8 then
		local k2 = 1 - math.exp(-dt * 1.6)
		orbit.Yaw = math.atan2(math.sin(orbit.Yaw), math.cos(orbit.Yaw)) * (1 - k2)
		orbit.Pitch *= (1 - k2)
	end
	local camOut = camCF :: CFrame
	local looking = math.abs(orbit.Yaw) > 0.01 or math.abs(orbit.Pitch) > 0.01 or math.abs(orbit.Zoom - 1) > 0.01
	if looking then
		local pivot = rootCF.Position + Vector3.new(0, 2.6, 0)
		local off = (camOut.Position - pivot) * orbit.Zoom
		off = CFrame.Angles(0, orbit.Yaw, 0):VectorToWorldSpace(off)
		local horiz = Vector3.new(off.X, 0, off.Z)
		local dist = off.Magnitude
		local pitch0 = math.asin(math.clamp(off.Y / math.max(dist, 1e-3), -1, 1))
		local pitch = math.clamp(pitch0 + orbit.Pitch, -0.15, 1.3)
		local dir = horiz.Magnitude > 1e-3 and horiz.Unit or Vector3.new(0, 0, 1)
		local p = pivot + dir * math.cos(pitch) * dist + Vector3.new(0, math.sin(pitch) * dist, 0)
		-- blend the look target from "ahead of the vehicle" to "the vehicle" as you swing around
		local aim = camOut.Position + camOut.LookVector * 20
		local w = math.clamp(math.abs(orbit.Yaw) / 0.6 + math.abs(orbit.Pitch) / 0.5, 0, 1)
		camOut = CFrame.lookAt(p, aim:Lerp(pivot, w))
	end
	cam.CFrame = camOut * CFrame.Angles(0, 0, roll)
	cam.FieldOfView = camFov
	camShakeKick = math.max(0, camShakeKick - dt * 3)
end

function Drive.Kick(amount: number)
	camShakeKick = math.max(camShakeKick, amount)
end

local function releaseCamera()
	for part in pairs(faded) do part.LocalTransparencyModifier = 0 end
	faded = {}
	orbit.Yaw, orbit.Pitch, orbit.Dragging = 0, 0, false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
	end
	camCF = nil
end

--------------------------------------------------------------------------------
-- wheels (every client animates every vehicle's wheels from its motion)
--------------------------------------------------------------------------------
local wheelState = setmetatable({}, { __mode = "k" })
local function animateWheels(dt: number)
	local folder = Workspace:FindFirstChild("ActiveVehicles")
	if not folder then return end
	for _, v in ipairs(folder:GetChildren()) do
		local root = v:IsA("Model") and v.PrimaryPart
		if not root then continue end
		local ws = wheelState[v]
		if not ws then
			ws = { Spin = 0, Motors = {}, Yaw = 0, LastYaw = nil }
			for _, m in ipairs(root:GetChildren()) do
				if m:IsA("Motor6D") and m.Name:match("^Wheel") then
					local w = v:FindFirstChild(m.Name, true)
					local r = (w and w:GetAttribute("Radius")) or 1.5
					table.insert(ws.Motors, { M = m, Front = m.Name:sub(6, 6) == "F", R = r })
				end
			end
			wheelState[v] = ws
		end
		local vel = root.AssemblyLinearVelocity
		local fwd = -(root.CFrame.LookVector:Dot(vel))
		local _, yaw = root.CFrame:ToEulerAnglesYXZ()
		local dyaw = ws.LastYaw and math.atan2(math.sin(yaw - ws.LastYaw), math.cos(yaw - ws.LastYaw)) / math.max(dt, 1e-3) or 0
		ws.LastYaw = yaw
		-- (+steer is right, which is a negative turn about Y: the old +steer pointed the wheels the wrong way)
		local steer = (v == St.Vehicle) and -St.Steer * 0.45 or math.clamp(dyaw * 0.3, -0.45, 0.45)
		ws.Yaw += (steer - ws.Yaw) * math.min(1, dt * 10)
		for _, w in ipairs(ws.Motors) do
			w.Spin = (w.Spin or 0) + fwd * dt / w.R
			w.M.Transform = CFrame.Angles(0, w.Front and ws.Yaw or 0, 0) * CFrame.Angles(w.Spin, 0, 0)
		end
	end
end

--------------------------------------------------------------------------------
-- camp: free driving
--------------------------------------------------------------------------------
local CAMP_CENTER = Vector3.new(600, 0, 0)
local CAMP_RADIUS = 760 -- (2026-10-12) Base Camp Islands: the crater rim around the lagoon is about 700 out
-- off-road: a jeep mounts anything up to MAX_STEP tall (curbs, humps, logs, ramps, low walls); only real walls stop it
local MAX_STEP = 6.5
local GRAVITY = 90
-- FREE ROAM in an era (St.Mode "Roam", 2026-10-13): the same free driving, inside that era's own bounds. Era tree
-- trunks only collide up to ~5.2 studs, so the climb there is lower (a trunk is a wall, not a ramp); the blocky hills'
-- tallest steps are 3.6
local ROAM_STEP = 4.2
local roamBounds = {} :: { [string]: { Center: Vector3, Radius: number } }
local function bounds(): (Vector3, number)
	if St.Mode ~= "Roam" or not St.Zone then return CAMP_CENTER, CAMP_RADIUS end
	local b = roamBounds[St.Zone]
	if not b then
		local m = Workspace:FindFirstChild(St.Zone)
		if m and m:IsA("Model") then
			local cf, size = m:GetBoundingBox()
			b = { Center = cf.Position, Radius = math.max(size.X, size.Z) / 2 }
		else
			b = { Center = (St.Root and St.Root.Position) or Vector3.zero, Radius = 900 }
		end
		roamBounds[St.Zone] = b
	end
	return b.Center, b.Radius
end
local function stepMax(): number
	return St.Mode == "Roam" and ROAM_STEP or MAX_STEP
end

local function filterList()
	local list = { St.Vehicle, Workspace:FindFirstChild("ActiveVehicles") }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(list, p.Character) end
	end
	return list
end

-- the highest walkable surface under a point, searching from MAX_STEP above the reference height
local function groundAt(pos: Vector3, refY: number): (number?, Vector3)
	local ms = stepMax()
	local hit = Workspace:Raycast(Vector3.new(pos.X, refY + ms + 0.5, pos.Z), Vector3.new(0, -(ms + 60), 0), rayParams)
	if hit then return hit.Position.Y, hit.Normal end
	return nil, Vector3.yAxis
end

-- (2026-10-12) the camp lagoon is Terrain water and the rays land on its surface: without this the rover would
-- drive across it. Water under the leading bumper is a shoreline, and the rover stops there like at a wall.
local function waterAt(pos: Vector3, refY: number): boolean
	local ms = stepMax()
	local hit = Workspace:Raycast(Vector3.new(pos.X, refY + ms + 0.5, pos.Z), Vector3.new(0, -(ms + 60), 0), rayParams)
	return hit ~= nil and hit.Material == Enum.Material.Water
end

-- your build's speeds (cached per rover: a restyle spawns a new one)
local statsCache = setmetatable({}, { __mode = "k" })
local function campStats(v: Model)
	local s = statsCache[v]
	if not s then
		local name = v:GetAttribute("VehicleName") or "RookieRanger"
		s = Rides.Stats(name, Rides.StyleFor(Net.Profile, name))
		statsCache[v] = s
	end
	return s
end

-- THE TIME GATE, caught on your own screen (2026-10-13, user: "you shouldn't see the car go through the gate and not
-- get teleported"): the server only notices a beat later (replication + its tick), long enough to watch the rover
-- come out the other side. So the moment its nose touches the membrane it stops right there, half in the glow, under
-- a quick white-out.
-- (2026-10-14, user: "i just used the time gate and didn't get put into it, make it flawless") The catch now ASKS the
-- server (EnterGate) instead of hoping its proximity check sees the rover in time, retries while the rover rolls in,
-- and the white-out only ever ends in the warp (BeginRoute) or a refusal you can read: the rover backs out of the
-- glow, the toast says why (it used to play under the white, unseen), and the membrane is a wall for a moment.
-- THE RETURN PORTAL gets the same catch (user: "when you boost through the exit gate you can kind of see the car go
-- through the gate"): free roam and the chase stop the rover nose-in at the membrane and ask (EnterPortal); the
-- white lifts the moment the trip home starts (Extracted: the ESCAPED! beat films the rover held in the glow;
-- ReturnHome: the warp), and the rover stays held there until the warp takes it.
local TweenService = game:GetService("TweenService")
local gateTrig: BasePart? = nil
local gateFlash: ScreenGui? = nil
local catch = {
	Kind = nil :: string?, -- "Gate" (Base Camp's Time Gate) | "Portal" (an era's return portal)
	Token = nil :: any, -- the request in flight: whatever takes over clears it, and its answer is dropped
	Ok = nil :: number?, -- when the server said yes
	From = nil :: Vector3?, -- free driving: where it was when it caught (backed out to on a refusal)
	FromS = nil :: number?, -- the chase: the same, on the road
	HoldS = nil :: number?, -- the chase: the road position it's held at
	Wall = 0, -- after a refusal the membrane is a wall until then (no white-out loop while you nose against it)
	Home = false, -- the server already sent you home (Extracted / ReturnHome): the membrane just stops the rover
}
local function gateCatch(np: Vector3, fwd: Vector3, len: number): boolean
	if St.Mode ~= "Camp" then return false end
	if not (gateTrig and gateTrig.Parent) then
		local camp = Workspace:FindFirstChild("BaseCamp")
		gateTrig = camp and camp:FindFirstChild("GateTrigger", true) :: BasePart?
		if not gateTrig then return false end
	end
	local trig = gateTrig :: BasePart
	local lp = trig.CFrame:PointToObjectSpace(np + fwd * len)
	local h = trig.Size / 2
	return math.abs(lp.X) < h.X and math.abs(lp.Y) < h.Y + 4 and math.abs(lp.Z) < h.Z + 1.5
end
-- the era's return portal: its membrane's frame (object -Z = on down the road), half-width and half-height
local portalCache = { Zone = nil :: string?, CF = nil :: CFrame?, HW = 0, HH = 0, At = 0 }
local function portalFrame(): CFrame?
	local z = St.Zone
	if not z then return nil end
	if portalCache.Zone ~= z or (not portalCache.CF and os.clock() - portalCache.At > 1) then
		portalCache.Zone, portalCache.CF, portalCache.At = z, nil, os.clock()
		local zm = Workspace:FindFirstChild(z)
		local p = zm and zm:FindFirstChild("ReturnPortal", true)
		local m = p and p:FindFirstChild("Membrane", true)
		if m and m:IsA("BasePart") then
			local look = Vector3.new(m.CFrame.LookVector.X, 0, m.CFrame.LookVector.Z)
			if look.Magnitude > 0.01 then
				portalCache.CF = CFrame.lookAt(m.Position, m.Position + look.Unit)
				portalCache.HW, portalCache.HH = m.Size.X, m.Size.Y / 2
			end
		end
	end
	return portalCache.CF
end
-- does the point moving a -> b this frame reach the membrane (from either side)? the fraction of the way, or nil
local function portalCross(a: Vector3, b: Vector3): number?
	local cf = portalFrame()
	if not cf then return nil end
	local la, lb = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
	if (la.Z > 0) == (lb.Z > 0) then return nil end
	local t = math.clamp(la.Z / (la.Z - lb.Z), 0, 1)
	local at = la:Lerp(lb, t)
	-- (the whole frame counts, not only the glow: the beams aren't solid and going past them is going through)
	if math.abs(at.X) > portalCache.HW + 3 or math.abs(at.Y) > portalCache.HH + 8 then return nil end
	return t
end
-- your run's phase on the server (Runtime/Runs/<you>), for the portal: only the chase and free roam go home there
local runsFolder: Instance? = nil
local function runPhase(): string?
	if not runsFolder then
		local de = ReplicatedStorage:FindFirstChild("DinoExpedition")
		local rt = de and de:FindFirstChild("Runtime")
		runsFolder = rt and rt:FindFirstChild("Runs")
	end
	local f = runsFolder and runsFolder:FindFirstChild(tostring(player.UserId))
	return f and f:GetAttribute("Phase")
end

local function liftWhite(t: number)
	local g = gateFlash
	gateFlash = nil
	if not g then return end
	local f = g:FindFirstChildOfClass("Frame")
	if f and t > 0 then
		TweenService:Create(f, TweenInfo.new(t), { BackgroundTransparency = 1 }):Play()
		task.delay(t + 0.05, function() g:Destroy() end)
	else
		g:Destroy()
	end
end
local function setWhite(kind: string)
	if gateFlash then gateFlash:Destroy() end
	local g = Instance.new("ScreenGui")
	g.Name = "DinoGateFlash"
	g.IgnoreGuiInset = true
	g.DisplayOrder = 90
	g.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.BackgroundColor3 = kind == "Gate" and Color3.fromRGB(220, 250, 255) or Color3.fromRGB(255, 242, 210)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = g
	g.Parent = player:WaitForChild("PlayerGui")
	gateFlash = g
	TweenService:Create(f, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
	-- (last resort only: every path above lifts it long before this)
	task.delay(16, function() if g.Parent then g:Destroy() if gateFlash == g then gateFlash = nil end end end)
end
-- let go: the warp / the trip home took over, or the run's over
local function clearCatch(fade: number?)
	catch.Token, catch.Ok, catch.Kind, catch.HoldS, catch.From, catch.FromS = nil, nil, nil, nil, nil, nil
	St.GateHold = nil
	liftWhite(fade or 0.25)
end
-- refused (or no answer): back out of the glow, say why, and the membrane is a wall for a moment. token = nil: forced
local function refuse(token: any, err: string?)
	if token ~= nil and catch.Token ~= token then return end
	local kind = catch.Kind
	if catch.From then free.Pos, free.V = catch.From, 0 end
	if catch.FromS and St.Mode == "Route" then St.S = math.max(0, catch.FromS - 2) route.V = 0 end
	catch.Wall = os.clock() + 2.5
	clearCatch(0.25)
	Net.Emit("Toast", { Text = err or (kind == "Gate" and "THE GATE DIDN'T TAKE YOU - DRIVE IN AGAIN" or "THE PORTAL DIDN'T TAKE YOU - DRIVE IN AGAIN"), Color = "Red" })
end
local RETRY = { ["slow down"] = true, ["CONNECTION ERROR"] = true, ["server error"] = true }
-- caught in the membrane: hold it there and ask (once the server's sending you home anyway, just hold)
local function startCatch(kind: string)
	St.GateHold = os.clock()
	catch.Kind = kind
	catch.Ok = nil
	-- (Home is per run: BeginRoute clears it, and the hub's gate never trusts it - always asks)
	if catch.Home and kind == "Portal" then catch.Token = nil return end
	if kind == "Gate" then catch.Home = false end
	setWhite(kind)
	local token = {}
	catch.Token = token
	task.spawn(function()
		local t0 = os.clock()
		local res
		while true do
			res = Net.Ask(kind == "Gate" and "EnterGate" or "EnterPortal")
			if catch.Token ~= token then return end
			if res and res.Ok then catch.Ok = os.clock() return end
			-- (the server's copy of the rover lags a few frames behind this one: it asks again while it rolls in)
			local again = res and (res.Retry or RETRY[res.Err or ""])
			if not again or os.clock() - t0 > 3.5 then break end
			task.wait(0.25)
			if catch.Token ~= token then return end
		end
		refuse(token, res and not res.Retry and res.Err or nil)
	end)
end
-- held in the membrane: true while it holds (the caller skips its own driving this frame)
local function holding(): boolean
	if not St.GateHold then return false end
	local age = os.clock() - St.GateHold
	if catch.Home then
		-- (sent home: the warp's on its way and freezes everything; never left parked here if it somehow isn't)
		if age > 15 then clearCatch(0.2) return false end
		return true
	end
	-- (asked and answered yes: the warp / the trip home lands any moment. No answer or no warp: let go, saying so)
	if age > 12 then refuse(nil, nil) return false end
	return true
end

local function stepCamp(dt: number)
	if holding() then
		if catch.Kind == "Gate" and St.Mode == "Camp" then
			-- under the white-out it rolls on until its middle is inside the membrane (what the server's backup check
			-- looks for), then holds there
			local trig = gateTrig
			if trig and trig.Parent then
				local lp = trig.CFrame:PointToObjectSpace(free.Pos + Vector3.new(0, rootHeight(), 0))
				if math.abs(lp.Z) > trig.Size.Z / 2 * 0.5 then
					local fwd = Vector3.new(-math.sin(free.Yaw), 0, -math.cos(free.Yaw))
					free.Pos += fwd * math.sign(St.GateDir or 1) * 24 * dt
				end
			end
		end
		free.V = 0
		St.Speed = 0
		St.Boosting = false
		local cf = CFrame.new(free.Pos) * CFrame.Angles(0, free.Yaw, 0) * CFrame.Angles(free.TiltP, 0, free.TiltR) * CFrame.new(0, rootHeight(), 0)
		setTargets(cf)
		-- (the ESCAPED! beat films the held rover: never write the chase cam over a scene's)
		if not cameraOverride then updateCamera(dt, cf, 0, false, false) end
		return
	end
	local throttle, steer = readInput(St.Seat)
	St.Throttle, St.Steer = throttle, steer
	local stats = campStats(St.Vehicle)
	-- (infinite at camp and in free roam - 2026-10-14, user: "allow for infinite boost". The chase keeps its meter in
	-- stepRoute: that's where running it dry is the danger)
	St.Boost, St.BoostDry = 1, false
	local boosting = boostHeld and throttle >= 0 and not St.NoBoost
	St.Boosting = boosting
	local vmax = boosting and stats.Boost * 0.8 or stats.Cruise * 0.72
	local v = free.V
	local airborne = free.Air > 0.05
	if boosting then throttle = 1 end
	if not airborne then
		if throttle > 0.05 then
			v += (v < 0 and 90 or 38) * throttle * dt
		elseif throttle < -0.05 then
			v += (v > 0 and -80 or -26) * -throttle * dt
		else
			v -= math.sign(v) * math.min(math.abs(v), 26 * dt)
		end
	end
	v = math.clamp(v, -16, vmax)
	-- steering scales with speed (no spinning on the spot); less grip in the air
	local grip = math.clamp(math.abs(v) / 14, 0, 1) * (airborne and 0.35 or 1)
	local turn = (1.9 - math.clamp(math.abs(v) / 60, 0, 0.8)) * grip
	free.Yaw -= steer * turn * dt * math.sign(v ~= 0 and v or 1)
	local fwd = Vector3.new(-math.sin(free.Yaw), 0, -math.cos(free.Yaw))
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local step = fwd * v * dt
	local len = (St.Vehicle:GetAttribute("Length") or 13) / 2
	local wid = (St.Vehicle:GetAttribute("Width") or 7) / 2
	rayParams.FilterDescendantsInstances = filterList()
	-- bumpers sit above the climbable height: anything lower is driven over, anything taller is a wall
	local blocked = false
	if math.abs(v) > 0.1 then
		local dir = fwd * math.sign(v)
		for _, off in ipairs({ 0, wid * 0.8, -wid * 0.8 }) do
			local o = free.Pos + Vector3.new(0, stepMax() + 0.3, 0) + right * off
			local hit = Workspace:Raycast(o, dir * (len + math.abs(v) * dt + 0.6), rayParams)
			if hit and hit.Normal.Y < 0.5 then blocked = true break end
		end
		if not blocked then
			for _, off in ipairs({ wid * 0.8, -wid * 0.8 }) do
				if waterAt(free.Pos + dir * (len + math.abs(v) * dt + 1) + right * off, free.Pos.Y) then blocked = true break end
			end
		end
	end
	if blocked then
		if math.abs(v) > 18 then Drive.Kick(0.6) Net.Emit("LocalBump", { Speed = math.abs(v) }) end
		v = -v * 0.25
		step = Vector3.zero
	end
	local np = free.Pos + step
	if math.abs(v) > 1 then
		local dir = fwd * math.sign(v)
		if St.Mode == "Camp" and gateCatch(np, dir, len) then
			if os.clock() < catch.Wall then
				-- (just refused: the glow is a wall for a moment)
				v, np = 0, free.Pos
			else
				catch.From = free.Pos
				catch.FromS = nil
				St.GateDir = math.sign(v)
				startCatch("Gate")
			end
		elseif St.Mode == "Roam" then
			-- the return portal: the nose (plus a little, so it dips into the glow) reaching the membrane this frame
			local ph = runPhase()
			if ph == "Map" or ph == "Site" or ph == "Extracting" or catch.Home then
				local t = portalCross(free.Pos + dir * (len + 1.5), np + dir * (len + 1.5))
				if t then
					if os.clock() < catch.Wall and not catch.Home then
						v, np = 0, free.Pos
					else
						catch.From = free.Pos
						catch.FromS = nil
						np = free.Pos + (np - free.Pos) * t
						v = 0
						startCatch("Portal")
					end
				end
			end
		end
	end
	-- stay inside the valley (camp) / the era (free roam)
	local bc, br = bounds()
	local flat = Vector3.new(np.X - bc.X, 0, np.Z - bc.Z)
	if flat.Magnitude > br then np = Vector3.new(bc.X, 0, bc.Z) + flat.Unit * br + Vector3.new(0, np.Y, 0) v *= 0.5 end
	-- four wheel contacts: the body follows the terrain under each wheel (suspension), so humps tilt it
	local refY = free.Pos.Y
	local fl = groundAt(np + fwd * len * 0.72 - right * wid * 0.8, refY)
	local fr = groundAt(np + fwd * len * 0.72 + right * wid * 0.8, refY)
	local rl = groundAt(np - fwd * len * 0.72 - right * wid * 0.8, refY)
	local rr = groundAt(np - fwd * len * 0.72 + right * wid * 0.8, refY)
	local mid = groundAt(np, refY)
	local hs = {}
	for _, h in ipairs({ fl, fr, rl, rr, mid }) do if h then table.insert(hs, h) end end
	local groundY = nil
	if #hs > 0 then
		local sum, top = 0, -math.huge
		for _, h in ipairs(hs) do sum += h top = math.max(top, h) end
		-- mostly the average, biased to the highest wheel so the body never sinks into a hump
		groundY = sum / #hs * 0.6 + top * 0.4
	end
	-- vertical: climb fast onto whatever is under the wheels, fall with gravity off crests (small jumps)
	local y = free.Pos.Y
	if groundY then
		if groundY >= y - 0.05 then
			y += (groundY - y) * math.min(1, dt * 22)
			if groundY - y < 0.05 then y = groundY end
			if free.VY < -30 then Drive.Kick(0.5) end
			free.VY = math.min(22, math.max(0, (groundY - free.Pos.Y) / math.max(dt, 1e-3)) * 0.4)
			free.Air = 0
		elseif y - groundY < 0.35 and free.VY <= 2 then
			-- gentle downhill: stay glued to the ground
			y = groundY
			free.VY = 0
			free.Air = 0
		else
			free.VY -= GRAVITY * dt
			y += free.VY * dt
			if y <= groundY then
				if free.VY < -28 then Drive.Kick(math.clamp(-free.VY / 60, 0.3, 1)) end
				y = groundY
				free.VY = 0
				free.Air = 0
			else
				free.Air += dt
			end
		end
	end
	np = Vector3.new(np.X, y, np.Z)
	free.Pos = np
	free.V = v
	St.Speed = math.abs(v)
	-- tilt from the wheel heights (pitch front/back, roll left/right), smoothed like springs
	local function h(x: number?) return x or y end
	local wantPitch = math.atan2(((h(fl) + h(fr)) - (h(rl) + h(rr))) / 2, len * 1.44)
	local wantRoll = math.atan2(((h(fr) + h(rr)) - (h(fl) + h(rl))) / 2, wid * 1.6)
	if free.Air > 0.05 then wantPitch, wantRoll = free.TiltP * 0.98, free.TiltR * 0.98 end
	wantPitch = math.clamp(wantPitch, -0.6, 0.6)
	wantRoll = math.clamp(wantRoll, -0.45, 0.45)
	free.TiltP += (wantPitch - free.TiltP) * math.min(1, dt * 12)
	free.TiltR += (wantRoll - free.TiltR) * math.min(1, dt * 12)
	-- body: lean into turns, squat when accelerating
	local lean = -steer * grip * 0.07
	free.Roll += (lean - free.Roll) * math.min(1, dt * 6)
	local squat = math.clamp(throttle * 0.03, -0.03, 0.03)
	free.Pitch += (squat - free.Pitch) * math.min(1, dt * 5)
	free.Bob += dt * (6 + math.abs(v) * 0.25)
	local bob = math.sin(free.Bob) * 0.03 * math.clamp(math.abs(v) / 20, 0, 1)
	local base = CFrame.new(free.Pos) * CFrame.Angles(0, free.Yaw, 0) * CFrame.Angles(free.TiltP, 0, free.TiltR)
	local cf = base * CFrame.new(0, rootHeight() + bob, 0) * CFrame.Angles(free.Pitch, 0, free.Roll)
	setTargets(cf)
	-- (a cutscene that films the rover while it rolls - the ESCAPED! beat as you roam into the portal - owns the lens:
	-- this used to write the chase cam over it every frame, a shaking fight between two cameras. 2026-10-14)
	if not cameraOverride then updateCamera(dt, cf, math.abs(v), boosting, false) end
end

--------------------------------------------------------------------------------
-- route: guided driving
--------------------------------------------------------------------------------
local function forkChoice(x: number): number
	return x < 0 and 1 or 2
end

function Drive.ForkInfo()
	-- the next undecided fork ahead: { Index, S, Labels, Choice }
	local r = St.Route
	if not r then return nil end
	local forks = r.Data.Forks
	if not St.C1 then
		return { Index = 1, S = forks[1].S[St.Variant], Labels = forks[1].Labels, Choice = forkChoice(St.X) }
	elseif not St.C2 then
		return { Index = 2, S = forks[2].S[St.Variant], Labels = forks[2].Labels, Choice = forkChoice(St.X) }
	end
	return nil
end

-- autopilot: when you aren't steering, the jeep holds the road itself: around obstacles, toward pickups,
-- away from a telegraphed lunge. Driving is travel; the action is at the nests and on the launcher.
local auto = { Idle = 0, DodgeX = 0, DodgeUntil = 0, BrakeUntil = 0 }
function Drive.Dodge(side: number)
	auto.DodgeX = -side * 8
	auto.DodgeUntil = os.clock() + 1.1
end
function Drive.AutoBrake(t: number)
	auto.BrakeUntil = os.clock() + t
end
local function autoSteer(r): number
	local vi, S = St.Variant, St.S
	local hw = r:HalfWidth(vi, S) - 4
	local want = 0
	if os.clock() < auto.DodgeUntil then
		want = auto.DodgeX
	else
		local bestObs, bestPick = nil, nil
		for _, f in ipairs(r.Data.Features) do
			local fs = f.S[vi]
			if not fs or fs < 0 then continue end
			local ahead = fs - S
			if ahead > 0 and ahead < 46 then
				if f.Type == "Log" or f.Type == "Branch" or f.Type == "Boulder" or f.Type == "Pillar" then
					if not bestObs or ahead < bestObs[2] then bestObs = { f, ahead } end
				elseif (f.Type == "Coin" or f.Type == "Darts" or f.Type == "Repair" or f.Type == "Boost") and ahead < 34 then
					if not bestPick or ahead < bestPick[2] then bestPick = { f, ahead } end
				end
			end
		end
		if bestObs then
			local f = bestObs[1]
			local w = (f.W or 6) / 2 + 5
			local left, right = f.X - w, f.X + w
			want = (math.abs(left - St.X) < math.abs(right - St.X) and left >= -hw) and left or right
			if right > hw then want = left end
		elseif bestPick then
			want = bestPick[1].X
		end
	end
	want = math.clamp(want, -hw, hw)
	return math.clamp((want - St.X) / 5, -1, 1)
end

-- (ice under the wheels: see stepRoute)
local iceCheckAt = 0
local iceParams = RaycastParams.new()
iceParams.FilterType = Enum.RaycastFilterType.Exclude

local function stepRoute(dt: number)
	local r = St.Route
	local throttle, steer = readInput(St.Seat)
	if math.abs(steer) > 0.05 then auto.Idle = 0 else auto.Idle += dt end
	if St.Autopilot and auto.Idle > 0.35 then steer = autoSteer(r) end
	St.Throttle, St.Steer = throttle, steer
	-- (never while frozen or on the autopilot - the first hunt's banner, a travel cutscene: the drive keeps its own pace;
	-- 2026-10-13, user: "no friction for onboarding, don't let them boost when it says your first hunt")
	if St.Boost <= 0.02 then St.BoostDry = true elseif St.Boost >= 0.35 then St.BoostDry = false end
	local wantBoost = not St.Frozen and not St.NoBoost and not St.BoostDry and (boostHeld or throttle > 0.5) and St.Boost > 0.02
	local braking = brakeHeld or throttle < -0.3
	St.Braking = braking
	St.Boosting = wantBoost and not braking
	local X = Config.Expedition
	if St.Boosting then St.Boost = math.max(0, St.Boost - X.BoostDrain * dt) else St.Boost = math.min(1, St.Boost + X.BoostRefill * (St.BoostRefill or 1) * dt) end
	local target = St.Boosting and St.BoostSpeed or (braking and X.BrakeSpeed or St.Cruise)
	if os.clock() < auto.BrakeUntil and not St.Boosting then target = math.min(target, X.BrakeSpeed) end
	-- pulling over at a nest: ease down to a stop at StopAt
	if St.StopAt then
		local remain = St.StopAt - St.S
		if remain <= 0.5 then target = 0
		else target = math.min(target, math.sqrt(2 * 26 * remain)) end
	end
	if St.Frozen then target = 0 end
	local accel = (target > route.V) and (St.Boosting and 30 or 18) or ((braking or St.StopAt) and 55 or 22) -- pulling over brakes hard enough to land on the mark
	if route.V < target then route.V = math.min(target, route.V + accel * dt) else route.V = math.max(target, route.V - accel * dt) end
	-- lateral: responsive but with grip (a little slide), knockback from hits decays
	local lat = 15 * math.clamp(route.V / 22, 0.35, 1.15) * math.clamp(St.Grip or 1, 0.8, 1.3) -- tyres / wings
	local wantXV = steer * lat
	-- ICE (Frost Forest's frozen lake road): the tyres barely bite - steering is slow to take and slow to let go,
	-- so the rover slides wide through every turn (checked under the wheels a few times a second)
	if St.Root and os.clock() >= (iceCheckAt or 0) then
		iceCheckAt = os.clock() + 0.12
		iceParams.FilterDescendantsInstances = { St.Vehicle or St.Root, player.Character :: Instance }
		local hit = Workspace:Raycast(St.Root.Position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), iceParams)
		St.OnIce = hit ~= nil and (hit.Material == Enum.Material.Ice or hit.Material == Enum.Material.Glacier)
	end
	route.XVel += (wantXV - route.XVel) * math.min(1, dt * (St.OnIce and 1.8 or 7))
	route.Knock *= math.exp(-dt * 5)
	local x = St.X + (route.XVel + route.Knock) * dt
	local hw = r:HalfWidth(St.Variant, St.S) - 2.6
	if x > hw then x = hw route.XVel = math.min(route.XVel, 0) if route.V > 25 then Net.Emit("Scrape", { Side = 1 }) end end
	if x < -hw then x = -hw route.XVel = math.max(route.XVel, 0) if route.V > 25 then Net.Emit("Scrape", { Side = -1 }) end end
	St.X = x
	local s = St.S + route.V * dt
	-- forks: steering side when you cross the fork point picks the branch
	local forks = r.Data.Forks
	-- a scripted drive (travel to a site) locks the branch it must take; otherwise your steering picks it
	local locked = St.LockVariant and (r:Variant(St.LockVariant).Choices or { 1, 1 }) or nil
	if not St.C1 and s >= forks[1].S[St.Variant] then
		St.C1 = locked and locked[1] or forkChoice(St.X)
		St.Variant = r:VariantFor(St.C1, nil)
		changed("Fork")
	elseif St.C1 and not St.C2 then
		local fs = forks[2].S[St.Variant]
		if s >= fs then
			St.C2 = locked and locked[2] or forkChoice(St.X)
			St.Variant = r:VariantFor(St.C1, St.C2)
			changed("Fork")
		end
	end
	St.Length = r:Length(St.Variant)
	s = math.min(s, St.Length)
	-- THE RETURN PORTAL on the chase (see gateCatch): held nose-in at the membrane until the trip home takes over -
	-- the server's own check used to fire 8 studs PAST the end, with the rover on camera out the far side
	if holding() then
		s = catch.HoldS and math.min(s, catch.HoldS) or St.S
		route.V = 0
		St.Boosting = false
	else
		local ph = (St.Boosting or route.V > 0.5) and runPhase() or nil
		if ph == "Driving" or ph == "Extracting" or (catch.Home and ph ~= nil) then
			local len = ((St.Vehicle and St.Vehicle:GetAttribute("Length")) or 13) / 2 + 1.5
			local t = portalCross(r:Position(St.Variant, St.S + len, St.X), r:Position(St.Variant, s + len, St.X))
			if t then
				if os.clock() < catch.Wall and not catch.Home then
					s = St.S
				else
					catch.From = nil
					catch.FromS = St.S
					s = St.S + (s - St.S) * t
					catch.HoldS = s
					startCatch("Portal")
				end
				route.V = 0
			end
		end
	end
	St.S = s
	St.Speed = route.V
	-- body: yaw into the steer, roll out of it, bob on the road
	local yawWant = -route.XVel * 0.012
	route.Yaw += (yawWant - route.Yaw) * math.min(1, dt * 8)
	route.Roll += ((route.XVel * 0.006) - route.Roll) * math.min(1, dt * 6)
	route.Bob += dt * (8 + route.V * 0.3)
	-- (only while it's rolling: stopped at a park spot it kept bobbing, and whatever phase it was held at, it sat that
	-- far into the road - 2026-10-14, "it goes into the floor a little")
	local bob = (math.sin(route.Bob) * 0.05 + math.sin(route.Bob * 2.3) * 0.025) * math.clamp(route.V / 8, 0, 1)
	local cf = r:Frame(St.Variant, s, x, route.Yaw) * CFrame.new(0, rootHeight() + bob, 0) * CFrame.Angles(0, 0, route.Roll)
	setTargets(cf)
	if not cameraOverride then updateCamera(dt, cf, route.V, St.Boosting, true) end
	-- report to the server (15 Hz)
	if os.clock() >= route.SendAt then
		route.SendAt = os.clock() + 1 / 15
		Net.SendDrive(St.S, St.X, route.V, St.Boosting, St.C1, St.C2)
	end
end

function Drive.Knock(side: number, strength: number?)
	route.Knock = -side * (strength or 9)
	route.V *= 0.72
	Drive.Kick(1)
end

function Drive.Bump()
	route.V *= 0.5
	Drive.Kick(0.8)
end

function Drive.AddBoost(amount: number)
	St.Boost = math.min(1, St.Boost + amount)
end

--------------------------------------------------------------------------------
-- mode control (Warp / Expedition call these)
--------------------------------------------------------------------------------
function Drive.BeginRoute(zone: string, info)
	-- (the warp took over from the gate catch: the white melts into the warp's own flash)
	catch.Home = false
	clearCatch(0.25)
	St.BoostRefill = 1 -- (a Sprint buddy's faster refill is per chase: ChaseStart sets it)
	St.Route = RouteMath.get(zone)
	St.Zone = zone
	St.Mode = "Route"
	-- start where the server put the rover (clear of the arrival portal), never a hard-coded spot
	St.S, St.X, St.Variant, St.C1, St.C2 = tonumber(info.S) or 4, 0, 1, nil, nil
	St.Cruise = info.Cruise or 42
	St.BoostSpeed = info.BoostSpeed or 62
	St.Grip = info.Grip or 1
	St.Boost = 1
	St.Frozen = false
	route.V, route.XVel, route.Knock, route.Yaw, route.Roll = 0, 0, 0, 0, 0
	St.Length = St.Route and St.Route:Length(1) or 1
	camCF = nil
	changed("Mode")
end

function Drive.EndRoute(arrivalCF: CFrame?)
	-- (home: the return portal's hold is over)
	catch.Home = false
	clearCatch(0.2)
	St.Route = nil
	St.Zone = nil
	St.Mode = St.Vehicle and "Camp" or "None"
	if arrivalCF then
		local look = arrivalCF.LookVector
		free.Pos = arrivalCF.Position - Vector3.new(0, rootHeight(), 0)
		free.Yaw = math.atan2(-look.X, -look.Z)
		free.V = 14
		setTargets(arrivalCF)
	end
	camCF = nil
	changed("Mode")
end

function Drive.Freeze(on: boolean)
	St.Frozen = on
end

-- free roam in an era (on) / back to the road (off: a travel autopilot or a chase takes over)
function Drive.SetRoam(on: boolean)
	if on then
		local cf = (St.Mode == "Route" and St.Route and not St.OnFoot and not St.Toppled and St.Root)
			and St.Route:Frame(St.Variant, St.S, St.X, route.Yaw) or nil
		-- (only while the rover really is where the road has it: anything that moved it off the road - a travel scene's
		-- teleport - reads the rover itself, below)
		if cf and St.Root and (St.Root.Position - cf.Position).Magnitude > rootHeight() + 8 then cf = nil end
		if cf then
			-- (the chase shaken off, 2026-10-14: free driving picks up from exactly where the road had the rover - its own
			-- target, not the lagging physics copy - still rolling at the chase's speed. No jump, no dead stop)
			local look = cf.LookVector
			St.Mode = "Roam"
			St.StopAt = nil
			free.Pos = cf.Position
			free.Yaw = math.atan2(-look.X, -look.Z)
			free.V = math.max(0, route.V)
			free.Up = Vector3.yAxis
			free.VY, free.Air, free.TiltP, free.TiltR = 0, 0, 0, 0
			route.V, route.XVel, route.Knock = 0, 0, 0
			St.Braking = false
		elseif St.Mode ~= "Roam" then
			St.Mode = "Roam"
			St.StopAt = nil
			Drive.SyncFromVehicle(0)
		end
		St.Frozen = false
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seated = hum ~= nil and hum.SeatPart ~= nil
		St.OnFoot = not seated
		if seated then bindInput() lockJump(true) else unbindInput() lockJump(false) releaseCamera() end
		changed("OnFoot")
	elseif St.Mode == "Roam" then
		St.Mode = "Route"
		-- (off to a site on the autopilot: whoever's in the seat is driving. Picked from the map on foot, the server
		-- sits you in and Mode was already Route when the seat arrived - OnFoot stayed set and the travel scene
		-- filmed a rover that never moved. onSeated covers a seat that lands after this. 2026-10-14)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart and ownedVehicleFor(hum.SeatPart) and St.OnFoot and not player:GetAttribute("Site") then
			St.OnFoot = false
			bindInput()
			lockJump(true)
			changed("OnFoot")
		end
	end
	camCF = nil
	changed("Mode")
end

-- place the vehicle (used by the warp before the route starts)
function Drive.Place(rootCF: CFrame)
	setTargets(rootCF)
end

local frozenCam = false
function Drive.HoldCamera(on: boolean) frozenCam = on end

-- a cutscene can take the camera while the vehicle keeps driving (boss intros)
function Drive.SetCameraOverride(on: boolean)
	cameraOverride = on
	if not on then camCF = nil end
end

-- re-read the vehicle's real position into the free-drive state (after a scripted move like the roll-out)
function Drive.SyncFromVehicle(speed: number?)
	local root = St.Root
	if not root then return end
	local cf = root.CFrame
	free.Pos = cf.Position - cf.UpVector * rootHeight()
	local look = cf.LookVector
	free.Yaw = math.atan2(-look.X, -look.Z)
	free.V = speed or 0
	free.Up = Vector3.yAxis
	free.VY, free.Air, free.TiltP, free.TiltR = 0, 0, 0, 0
	camCF = nil
end

-- touch: the LOOK button holds this
function Drive.SetLookBack(on: boolean) lookBack = on end
function Drive.LookingBack(): boolean return lookBack end

-- the rover flipped onto its side (0 armour in a chase): it stops being driven and lies there until repaired
function Drive.SetToppled(on: boolean)
	St.Toppled = on
	local root, v = St.Root, St.Vehicle
	if not (root and v) then return end
	if on then
		root.Anchored = true
		local cf = root.CFrame
		v:PivotTo((CFrame.new(cf.Position + Vector3.new(0, 1.6, 0)) * cf.Rotation * CFrame.Angles(0, 0, math.rad(96))) * root.CFrame:ToObjectSpace(v:GetPivot()))
	else
		root.Anchored = false
	end
end

-- set the rover back on its wheels on the road where it is (after a repair)
function Drive.Upright()
	local r, root, v = St.Route, St.Root, St.Vehicle
	if not (r and root and v) then return end
	local cf = r:Frame(St.Variant, St.S, St.X, 0) * CFrame.new(0, rootHeight() + 0.4, 0)
	v:PivotTo(cf * root.CFrame:ToObjectSpace(v:GetPivot()))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	setTargets(cf)
end

-- knocked out on an expedition: no rover, no route, just you on foot at home with the normal camera
function Drive.ResetOnFoot()
	catch.Home = false
	clearCatch(0.2)
	St.Toppled = false
	St.Route, St.Zone, St.StopAt = nil, nil, nil
	St.Mode = "None"
	St.OnFoot = false
	St.Frozen = false
	St.Vehicle, St.Root, St.Seat = nil, nil, nil
	frozenCam, cameraOverride = false, false
	route.V = 0
	unbindInput()
	lockJump(false)
	releaseCamera()
	changed("OnFoot")
	changed("Mode")
end

-- step out (raid) / back in: while on foot the vehicle holds its last target and the default camera follows you
function Drive.SetOnFoot(on: boolean)
	St.OnFoot = on
	route.V = 0
	if on then
		unbindInput() -- Shift is sprint on foot
		lockJump(false)
		releaseCamera()
	else
		bindInput()
		camCF = nil
	end
	changed("OnFoot")
end

function Drive.JumpTo(s: number)
	St.S = s
	route.V = St.Cruise
end

-- put the rover at a road position on a variant; forks already behind it count as taken
function Drive.SetRoutePos(s: number, x: number, variant: number?, speed: number?)
	local r = St.Route
	if not r then return end
	local vi = variant or St.Variant
	local choices = r:Variant(vi).Choices or { 1, 1 }
	local forks = r.Data.Forks
	St.Variant = vi
	St.C1 = (forks[1] and s >= forks[1].S[vi]) and choices[1] or nil
	St.C2 = (St.C1 and forks[2] and s >= forks[2].S[vi]) and choices[2] or nil
	St.S, St.X = s, x
	St.Length = r:Length(vi)
	route.V, route.XVel, route.Knock = speed or 0, 0, 0
	local cf = r:Frame(vi, s, x, 0) * CFrame.new(0, rootHeight(), 0)
	setTargets(cf)
	-- a jump along the road (a cutscene cut, a chase start) is a teleport: without this the rover's physics
	-- constraints dragged it across the map to the new target, straight through hills, camera and all
	local root, v = St.Root, St.Vehicle
	if root and v and (root.Position - cf.Position).Magnitude > 6 then
		v:PivotTo(cf * root.CFrame:ToObjectSpace(v:GetPivot()))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	changed("Fork")
end

-- the chase that ends every encounter: back in the rover at the site, autopilot rolling
function Drive.StartChase(info)
	if not St.Route then return end
	St.Mode = "Route"
	St.Cruise = info.Cruise or St.Cruise
	St.BoostSpeed = info.BoostSpeed or St.BoostSpeed
	St.Grip = info.Grip or St.Grip or 1
	St.BoostRefill = info.BoostRefill or 1 -- (a Sprint buddy riding along refills it faster)
	St.Boost = 1
	St.Frozen = false
	St.StopAt = info.StopS
	St.OnFoot = false
	Drive.SetRoutePos(info.S or St.S, info.X or St.X, info.Variant, math.max(8, tonumber(info.Speed) or 0)) -- (a boss chase starts rolling)
	bindInput()
	camCF = nil
	changed("OnFoot")
	changed("Mode")
end

--------------------------------------------------------------------------------
-- seat detection
--------------------------------------------------------------------------------
-- a run of your own is on (the server's Runtime/Runs folder has one under your id)
local function inRun(): boolean
	local rt = ReplicatedStorage:FindFirstChild("DinoExpedition")
	local runs = rt and rt:FindFirstChild("Runtime") and rt.Runtime:FindFirstChild("Runs")
	return runs ~= nil and runs:FindFirstChild(tostring(player.UserId)) ~= nil
end

local function onSeated(active: boolean, seatPart: Instance?)
	-- (touch has no raw-key fallback: make sure Roblox's controls are on whenever you sit in your rover)
	if active and controls then pcall(function() controls:Enable() end) end
	if active and seatPart and seatPart:IsA("VehicleSeat") then
		local v = ownedVehicleFor(seatPart)
		if v then
			St.Vehicle, St.Root, St.Seat = v, v.PrimaryPart, seatPart
			local root = v.PrimaryPart :: BasePart
			local cf = root.CFrame
			free.Pos = cf.Position - cf.UpVector * rootHeight()
			local look = cf.LookVector
			free.Yaw = math.atan2(-look.X, -look.Z)
			free.V = 0
			free.Up = Vector3.yAxis
			free.VY, free.Air, free.TiltP, free.TiltR = 0, 0, 0, 0
			-- (no run of yours going on: whatever an expedition or a ride along left behind - Route / Roam, on foot,
			-- frozen - is stale. At camp your own rover always drives)
			if (St.Mode == "Route" or St.Mode == "Roam") and not inRun() then
				St.Mode, St.Route, St.Zone, St.StopAt = "Camp", nil, nil, nil
			end
			if St.Mode ~= "Route" and St.Mode ~= "Roam" then
				St.Mode = "Camp"
				St.Frozen = false
				if St.OnFoot then
					St.OnFoot = false
					changed("OnFoot")
				end
			end
			if St.Mode == "Roam" and St.OnFoot then
				-- back at the wheel out in the era: drive on from right here
				St.OnFoot = false
				changed("OnFoot")
			elseif St.Mode == "Route" and St.OnFoot and not St.Toppled and not player:GetAttribute("Site") then
				-- sat in for a trip (a site picked from the map on foot): at the wheel, not still "on foot" (at a nest
				-- you stay on foot - the server holds the rover there)
				St.OnFoot = false
				changed("OnFoot")
			end
			camCF, camYaw, camPull = nil, nil, 1
			bindInput()
			lockJump(true)
			changed("Seated")
			return
		end
	end
	lockJump(false)
	if St.Mode == "Roam" then
		-- hopped out in the era: on your feet with the normal camera; the rover waits, held, where it stands
		St.OnFoot = true
		free.V = 0
		unbindInput()
		releaseCamera()
		changed("OnFoot")
		changed("Seated")
		return
	end
	if St.Mode == "Route" then return end -- the server re-seats us on expeditions
	St.Vehicle, St.Root, St.Seat = nil, nil, nil
	St.Mode = "None"
	unbindInput()
	releaseCamera()
	changed("Seated")
end

local function hookCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.Seated:Connect(onSeated)
	St.Vehicle, St.Root, St.Seat = nil, nil, nil
	if St.Mode ~= "Route" then St.Mode = "None" end
end

-- free roam: while any cutscene is on your screen the server mustn't pull you into a nest (a join under a scene left
-- a black screen). Sent on change; retried until the server took it (requests are rate-limited). 2026-10-14
local hold = { Want = false, Sent = false, At = 0, Busy = false }
local function roamHold()
	local want = St.Mode == "Roam" and Cinema.Playing()
	hold.Want = want
	if want == hold.Sent or hold.Busy or os.clock() - hold.At < 0.3 then return end
	hold.Busy = true
	hold.At = os.clock()
	task.spawn(function()
		local w = hold.Want
		local res = Net.Ask("RoamHold", { On = w })
		if res and res.Ok then hold.Sent = w elseif not w then hold.Sent = false end -- (no run any more: nothing held)
		hold.Busy = false
	end)
end

function Drive.Start()
	-- the trip home started (the ESCAPED! beat / the warp): the portal's white-out lifts, the rover stays held in the
	-- glow, and the membrane stops it if it wasn't there yet (the server's backup check got there first)
	local function homeBound(fade: number)
		catch.Home = true
		catch.Token = nil
		liftWhite(fade)
	end
	Net.On("Extracted", function() homeBound(0.2) end)
	Net.On("ReturnHome", function() homeBound(0.3) end)
	for _, kind in ipairs({ "Wrecked", "Fainted" }) do Net.On(kind, function() clearCatch(0.2) end) end
	if player.Character then task.spawn(hookCharacter, player.Character) end
	player.CharacterAdded:Connect(hookCharacter)
	RunService:BindToRenderStep("DinoDrive", Enum.RenderPriority.Camera.Value + 1, function(dt)
		dt = math.min(dt, 1 / 20)
		animateWheels(dt)
		roamHold()
		if not (St.Vehicle and St.Vehicle.Parent and St.Root and St.Seat) then
			-- fallback: notice we're sitting in our own vehicle even if Humanoid.Seated never reached us
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local sp = hum and hum.SeatPart
			if sp and sp:IsA("VehicleSeat") and ownedVehicleFor(sp) then
				onSeated(true, sp)
			elseif St.Mode == "Camp" then
				onSeated(false, nil)
			elseif (St.Mode == "Route" or St.Mode == "Roam") and not St.OnFoot and not frozenCam and not cameraOverride then
				-- just teleported (warp / travel) and the seat hasn't registered yet: keep the camera on the rover
				-- instead of leaving it wherever the last shot was
				local vf = Workspace:FindFirstChild("ActiveVehicles")
				for _, v in ipairs(vf and vf:GetChildren() or {}) do
					if v:GetAttribute("Owner") == player.UserId and v:IsA("Model") and v.PrimaryPart then
						updateCamera(dt, v.PrimaryPart.CFrame, 0, false, true)
						break
					end
				end
			end
			return
		end
		if frozenCam then return end -- a cinematic (the warp) owns the vehicle and camera
		if St.OnFoot then return end -- parked at a nest; the player is walking (Roblox's own camera)
		watchdog(dt)
		if St.Mode == "Camp" then stepCamp(dt)
		elseif St.Mode == "Roam" then
			if St.Frozen then free.V = 0 else stepCamp(dt) end
		elseif St.Mode == "Route" and St.Route then stepRoute(dt) end
	end)
end

return Drive
