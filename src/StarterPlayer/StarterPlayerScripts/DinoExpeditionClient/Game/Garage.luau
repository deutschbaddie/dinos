--[[
	Garage — taking your vehicle out.
	Own more than one? A picker opens. Then the roll-out cutscene: the roll-up door lifts, the bay
	lights flicker on, and your vehicle rolls out past a low tracking camera onto the driveway
	before the camera swings in behind it and hands you the wheel.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)
local Theme = require(script.Parent.UI.Theme)
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)

local player = Players.LocalPlayer
local C = Theme.C
local Garage = {}
local Panels, HUD
local busy = false

local function ownGarage(): Model?
	local idx = player:GetAttribute("Plot")
	local camp = Workspace:FindFirstChild("BaseCamp")
	local plot = camp and idx and camp:FindFirstChild("Plot" .. idx, true)
	return plot and plot:FindFirstChild("Garage", true) :: Model?
end

local function bars(root: Frame)
	local list = {}
	for i, anchor in ipairs({ 0, 1 }) do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchor)
		f.Position = UDim2.fromScale(0, anchor)
		f.Size = UDim2.fromScale(1, 0)
		f.ZIndex = 20
		f.Parent = root
		list[i] = f
		TweenService:Create(f, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0.1) }):Play()
	end
	return list
end

local function waitForVehicle(timeout: number): Model?
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local v = Drive.State.Vehicle
		if v and v.Parent and v:GetAttribute("RollOut") then return v end
		task.wait()
	end
	return Drive.State.Vehicle
end

local activeCine = nil
local function rollOut(name: string)
	local garage = ownGarage()
	local vehicle = waitForVehicle(4)
	if not (garage and vehicle and vehicle.PrimaryPart) then return end
	local pivot = garage:FindFirstChild("GarageDoorPivot", true) :: BasePart?
	local outPt = garage:FindFirstChild("RollOutPoint", true) :: BasePart?
	if not (pivot and outPt) then return end
	local info = Config.Vehicles[name] or Config.Vehicles.RookieRanger
	local root = vehicle.PrimaryPart :: BasePart
	local startCF = root.CFrame
	local rh = vehicle:GetAttribute("RootHeight") or 2.6
	local out = pivot.CFrame.LookVector
	local right = pivot.CFrame.RightVector
	local endPos = Vector3.new(outPt.Position.X, startCF.Position.Y, outPt.Position.Z)
	local endCF = CFrame.lookAt(endPos, endPos + out)
	local doorPos = pivot.Position
	local cam = Workspace.CurrentCamera
	Drive.HoldCamera(true)
	activeCine = Cinema.Begin("DinoGarageCut")
	cam.CameraType = Enum.CameraType.Scriptable
	local gui, canvas = Kit.Screen("DinoGarageCut", 50, true)
	local root2 = gui:FindFirstChild("Root") :: Frame
	local bar = bars(root2)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DinoGarageGrade"
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(0.5), { Contrast = 0.12, Saturation = 0.15 }):Play()
	-- skip
	local skipped = false
	local tap = Instance.new("TextButton")
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 40
	tap.Parent = root2
	local cutStart = os.clock() -- no skipping in the first second (stops spam-taps skipping the whole thing)
	tap.Activated:Connect(function() if os.clock() - cutStart > 1 then skipped = true end end)
	local conn2 = UserInputService.InputBegan:Connect(function(input)
		if (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return) and os.clock() - cutStart > 1 then skipped = true end
	end)
	-- interior lights flicker on
	task.spawn(function()
		local lights = {}
		for _, p in ipairs(garage:GetDescendants()) do if p:IsA("BasePart") and p.Name == "GarageLight" then table.insert(lights, p) end end
		for _, flick in ipairs({ 1, 0, 1, 0.6, 1, 0, 0 }) do
			for _, l in ipairs(lights) do l.Transparency = flick end
			task.wait(0.07)
		end
	end)
	-- title card (bottom-left)
	local title = Instance.new("Frame")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0, 1)
	title.Position = UDim2.new(0, 40, 1, -88)
	title.Size = UDim2.fromOffset(560, 110)
	title.Visible = false
	title.Parent = canvas
	Kit.Text(title, info.Tier, { Pixel = true, Size = UDim2.fromOffset(320, 14), Align = Enum.TextXAlignment.Left, Color = info.Color:Lerp(Color3.new(1, 1, 1), 0.3), Shadow = 2, Stroke = 2, ZIndex = 24 })
	Kit.Text(title, info.Name, { Pixel = true, Size = UDim2.fromOffset(560, 40), Position = UDim2.fromOffset(0, 22), Align = Enum.TextXAlignment.Left, Color = C.YellowHi, Color2 = C.Orange, Shadow = 5, Stroke = 4, ZIndex = 24 })
	local stripe = Instance.new("Frame")
	stripe.BorderSizePixel = 0
	stripe.BackgroundColor3 = info.Color
	stripe.Size = UDim2.fromOffset(0, 6)
	stripe.Position = UDim2.fromOffset(0, 72)
	stripe.ZIndex = 24
	stripe.Parent = title
	local gear = (Net.Profile and Net.Profile.Gear) or {}
	Kit.Text(title, (Config.Rack.Base + (gear.Rack or 0)) .. " EGG SLOTS  -  " .. info.HP .. " ARMOR  -  " .. (info.Darts or 6) .. " DARTS", { Pixel = true, Size = UDim2.fromOffset(520, 10), Position = UDim2.fromOffset(0, 88), Align = Enum.TextXAlignment.Left, Color = C.Cream, Shadow = 2, Stroke = 2, ZIndex = 24 })

	local DUR = 4.6
	local dustAt, revved = 0, false
	local t0 = os.clock()
	local titleShown = false
	local done = false
	local conn
	local function frame()
		local t = os.clock() - t0
		if skipped then t = DUR end
		-- vehicle: wait for the door, then roll out with an ease-in-out
		local u = math.clamp((t - 1.1) / 2.6, 0, 1)
		local e = u * u * (3 - 2 * u)
		local vcf = startCF:Lerp(endCF, e)
		-- drive it like a vehicle, not a slide: the nose lifts as it accelerates out and dips as it brakes,
		-- a bump over the door sill, rear wheels kicking dust while it moves
		local accel = (u > 0 and u < 1) and (6 - 12 * u) or 0 -- d2(smoothstep)/du2
		local sill = math.max(0, 1 - math.abs(e - 0.18) / 0.06) -- crossing the door line
		local pitch = accel * 0.012 + math.sin(t * 40) * 0.004 * (u > 0 and u < 1 and 1 or 0)
		vcf = vcf * CFrame.new(0, sill * 0.35, 0) * CFrame.Angles(pitch, 0, math.sin(t * 23) * 0.004 * (u > 0 and u < 1 and 1 or 0))
		if u > 0.02 and u < 0.95 and os.clock() > (dustAt or 0) then
			dustAt = os.clock() + 0.15
			DinosaurVFX.FootstepDust(vcf.Position - out * 4 - Vector3.new(0, rh - 0.3, 0), 0.7)
		end
		if t > 1.05 and not revved then
			revved = true
			DinosaurVFX.Shake(0.3, 0.25) -- the engine catches
		end
		vehicle:PivotTo(vcf * root.CFrame:ToObjectSpace(vehicle:GetPivot()))
		Drive.Place(vcf)
		-- camera
		local camCF
		if t < 1.4 then
			-- low wide on the driveway, door lifting
			local p = doorPos + out * 15 + right * 7 + Vector3.new(0, 2.2, 0)
			camCF = CFrame.lookAt(p, doorPos + Vector3.new(0, 6.5 - t, 0))
			cam.FieldOfView = 62
		elseif t < 3.7 then
			-- tracking dolly as the nose comes out into the light
			local k = (t - 1.4) / 2.3
			local p = doorPos + out * (10 + k * 10) + right * (10 - k * 3) + Vector3.new(0, 2.6 + k * 1.5, 0)
			camCF = CFrame.lookAt(p, vcf.Position + out * 3 + Vector3.new(0, 1.5, 0))
			cam.FieldOfView = 56 - k * 6
		else
			-- swing in behind for the handoff
			local k = math.clamp((t - 3.7) / 0.9, 0, 1)
			local behind = vcf.Position - out * 18 + Vector3.new(0, 7, 0)
			-- never back inside the bay (the rover stops only a few studs past the door): out on the driveway, a
			-- little higher so the roof still reads
			local along = (behind - doorPos):Dot(out)
			if along < 5 then behind += out * (5 - along) + Vector3.new(0, (5 - along) * 0.35, 0) end
			local side = doorPos + out * 20 + right * 7 + Vector3.new(0, 4.1, 0)
			local p = side:Lerp(behind, k * k * (3 - 2 * k))
			camCF = CFrame.lookAt(p, vcf.Position + out * 8 + Vector3.new(0, 2, 0))
			cam.FieldOfView = 50 + k * 18
		end
		cam.CFrame = camCF
		if not titleShown and t > 2.2 then
			titleShown = true
			title.Visible = true
			title.Position = UDim2.new(0, 10, 1, -88)
			TweenService:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Position = UDim2.new(0, 40, 1, -88) }):Play()
			TweenService:Create(stripe, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(330, 6) }):Play()
			DinosaurVFX.FootstepDust(vcf.Position - Vector3.new(0, rh - 0.3, 0), 1.4)
		end
		if t >= DUR then done = true end
	end
	-- (an error mid-shot - the rover despawned, the garage reloaded - must never leave the camera and HUD held)
	conn = RunService.RenderStepped:Connect(function()
		if done then return end
		local ok, err = pcall(frame)
		if not ok then
			warn("[Garage] roll-out:", err)
			done = true
		end
	end)
	local waitFrom = os.clock()
	while not done and os.clock() - waitFrom < DUR + 3 do task.wait() end
	done = true
	conn:Disconnect()
	conn2:Disconnect()
	if vehicle.Parent and root.Parent then
		vehicle:PivotTo(endCF * root.CFrame:ToObjectSpace(vehicle:GetPivot()))
		Drive.Place(endCF)
		Drive.SyncFromVehicle(10)
	end
	Drive.HoldCamera(false)
	Cinema.End(activeCine)
	activeCine = nil
	for _, f in ipairs(bar) do TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0) }):Play() end
	Kit.PopOut(title)
	TweenService:Create(cc, TweenInfo.new(0.4), { Contrast = 0, Saturation = 0 }):Play()
	task.wait(0.45)
	gui:Destroy()
	cc:Destroy()
end

-- away from your base: no garage, you transform into the rover where you stand. A puff of smoke and a burst of
-- blocks, you vanish, the rover pops out of the cloud with a spin and a bounce, and you're driving. ~1 second.
local function blockBurst(at: Vector3, color: Color3, n: number, outward: boolean)
	for i = 1, n do
		local b = Instance.new("Part")
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.SmoothPlastic
		b.Color = (i % 3 == 0) and Color3.new(1, 1, 1) or color
		b.Size = Vector3.one * (0.5 + math.random() * 0.5)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.1, math.random() - 0.5).Unit
		local far = at + dir * (5 + math.random() * 4)
		b.CFrame = CFrame.new(outward and at or far) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		b.Parent = Workspace
		local goal = outward and far or at
		TweenService:Create(b, TweenInfo.new(outward and 0.45 or 0.28, outward and Enum.EasingStyle.Quad or Enum.EasingStyle.Quad, outward and Enum.EasingDirection.Out or Enum.EasingDirection.In), { CFrame = CFrame.new(goal) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Size = Vector3.one * 0.1, Transparency = 0.2 }):Play()
		task.delay(0.5, function() b:Destroy() end)
	end
end

local function puff(at: Vector3, count: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	p.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(7, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 5
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	e.LightEmission = 0
	e.Parent = p
	e:Emit(count)
	task.delay(1.2, function() p:Destroy() end)
end

-- every visible part of a model, hidden or shown for this client only
local function localHide(m: Instance, hidden: boolean)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then (d :: any).LocalTransparencyModifier = hidden and 1 or 0 end
	end
end

local function transform(name: string)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local accent = (Config.Vehicles[name] and Config.Vehicles[name].Color) or Color3.fromRGB(255, 196, 60)
	local at = hrp and hrp.Position or Vector3.zero
	local cam = Workspace.CurrentCamera
	-- 1. poof: you burst into blocks and smoke (no driving off until the rover has landed)
	Drive.HoldCamera(true)
	puff(at, 22)
	blockBurst(at, accent, 14, true)
	if char then localHide(char, true) end
	local fov0 = cam.FieldOfView
	TweenService:Create(cam, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { FieldOfView = fov0 - 6 }):Play()
	local vehicle = waitForVehicle(3)
	if not (vehicle and vehicle.PrimaryPart) then
		if char then localHide(char, false) end
		-- (the rover was hidden the moment it arrived: never leave it invisible)
		local late = vehicle or Drive.State.Vehicle
		if late then localHide(late, false) end
		local av = Workspace:FindFirstChild("ActiveVehicles")
		for _, m in ipairs(av and av:GetChildren() or {}) do
			if m:IsA("Model") and m:GetAttribute("Owner") == player.UserId then localHide(m, false) end
		end
		cam.FieldOfView = fov0
		Drive.HoldCamera(false)
		return
	end
	local root = vehicle.PrimaryPart :: BasePart
	-- 2. the real rover stays hidden while a stand-in pops out of the cloud
	localHide(vehicle, true)
	local ghost = vehicle:Clone()
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Seat") or d:IsA("VehicleSeat") or d:IsA("ProximityPrompt") or d:IsA("Sound") then
			if not d:IsA("BasePart") then d:Destroy() end
		end
	end
	-- the driver's character was seated inside: drop it from the stand-in
	for _, d in ipairs(ghost:GetChildren()) do if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then d:Destroy() end end
	ghost.Name = "TransformGhost"
	ghost.Parent = Workspace
	local base = root.CFrame
	local rel = root.CFrame:ToObjectSpace(vehicle:GetPivot())
	blockBurst(base.Position, accent, 10, false)
	local t0 = os.clock()
	local DUR = 0.42
	while os.clock() - t0 < DUR + 0.16 do
		local t = os.clock() - t0
		local s
		if t < DUR then
			local u = t / DUR
			local c1, c3 = 1.70158, 2.70158
			s = 0.08 + 0.92 * (1 + c3 * (u - 1) ^ 3 + c1 * (u - 1) ^ 2) -- back-out: overshoots to ~1.1, lands on exactly 1
		else
			s = 1
		end
		local spin = (1 - math.clamp(t / DUR, 0, 1)) ^ 2 * math.pi * 2
		pcall(function() ghost:ScaleTo(math.max(0.05, s)) end)
		ghost:PivotTo(base * CFrame.Angles(0, spin, 0) * (rel.Rotation + rel.Position * math.max(0.05, s)))
		RunService.RenderStepped:Wait()
	end
	-- 3. swap in the real rover, a little dust as it lands
	ghost:Destroy()
	localHide(vehicle, false)
	if char then localHide(char, false) end
	puff(base.Position - Vector3.new(0, 1.5, 0), 10)
	DinosaurVFX.FootstepDust(base.Position - Vector3.new(0, 1.5, 0), 1.2)
	TweenService:Create(cam, TweenInfo.new(0.3, Enum.EasingStyle.Back), { FieldOfView = fov0 }):Play()
	Drive.Place(root.CFrame)
	Drive.SyncFromVehicle(0)
	Drive.HoldCamera(false)
end

local function take(name: string)
	if busy then return end
	busy = true
	-- away from the base the rover appears at your feet: hide it the instant it replicates, before the transform
	local hideConn = nil
	local av = Workspace:FindFirstChild("ActiveVehicles")
	if av then
		hideConn = av.ChildAdded:Connect(function(m)
			if m:GetAttribute("Owner") == player.UserId then
				task.defer(function()
					local garage = ownGarage()
					local pivot = garage and garage:FindFirstChild("GarageDoorPivot", true) :: BasePart?
					local pv = (m :: Model):GetPivot().Position
					-- the garage spawn stays visible (the door cutscene shows it); anything else hides
					if not pivot or (pv - pivot.Position).Magnitude > 40 then localHide(m, true) end
				end)
			end
		end)
	end
	local res = Net.Ask("TakeVehicle", { Name = name })
	if hideConn then hideConn:Disconnect() end
	if not res.Ok then
		Kit.Toast(res.Err or "CAN'T TAKE THE VEHICLE", "Red", "Jeep")
		busy = false
		return
	end
	if res.Mode == "Parked" then busy = false return end -- (you just got back into your parked rover: no cutscene)
	local ok, err = pcall(res.Mode == "Here" and transform or rollOut, name)
	if not ok then
		warn("[Garage] roll-out failed:", err)
		Drive.HoldCamera(false)
		if activeCine then Cinema.End(activeCine) activeCine = nil end
		if res.Mode == "Here" then
			-- the transform broke: just show everything and drive from where the rover is
			local v = Drive.State.Vehicle
			if v then localHide(v, false) end
			if player.Character then localHide(player.Character, false) end
			local g = Workspace:FindFirstChild("TransformGhost")
			if g then g:Destroy() end
			if v and v.PrimaryPart then Drive.Place(v.PrimaryPart.CFrame) Drive.SyncFromVehicle(0) end
			Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			busy = false
			return
		end
		-- whatever went wrong, never leave the rover shut in the bay: put it on the driveway
		local garage = ownGarage()
		local outPt = garage and garage:FindFirstChild("RollOutPoint", true) :: BasePart?
		local pivot = garage and garage:FindFirstChild("GarageDoorPivot", true) :: BasePart?
		local v = Drive.State.Vehicle
		if outPt and pivot and v and v.PrimaryPart then
			local rh = v:GetAttribute("RootHeight") or 2.6
			local p = outPt.Position + Vector3.new(0, rh, 0)
			local cf = CFrame.lookAt(p, p + pivot.CFrame.LookVector)
			v:PivotTo(cf * v.PrimaryPart.CFrame:ToObjectSpace(v:GetPivot()))
			Drive.Place(cf)
			Drive.SyncFromVehicle(0)
		end
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
	busy = false
end

function Garage.Request()
	if busy or Drive.State.Mode == "Route" or Drive.State.Mode == "Roam" then return end
	if Drive.State.Mode == "Camp" then Kit.Toast("YOU'RE ALREADY DRIVING!", "Orange", "Jeep") return end
	local p = Net.Profile
	if not p then return end
	local owned = 0
	local gear = p.Gear or {}
	for _ in pairs(gear.Vehicles or {}) do owned += 1 end
	if owned > 1 then
		Panels.Open("Picker")
	else
		task.spawn(take, gear.Vehicle or "RookieRanger")
	end
end

function Garage.Start(panels, hud)
	Panels, HUD = panels, hud
	Panels.OnPick = function(name) task.spawn(take, name) end
	HUD.OnDrive = Garage.Request
	-- the garage's TAKE VEHICLE prompt is pointless (and in the way) while you're already behind the wheel
	local garagePrompts = (setmetatable({}, { __mode = "k" }) :: any) :: { [ProximityPrompt]: boolean }
	local function track(d: Instance)
		local a = d:IsA("ProximityPrompt") and d:GetAttribute("CampAction")
		if a == "Garage" or a == "Customize" then garagePrompts[d] = true end -- TAKE VEHICLE + the paint shop
	end
	for _, d in ipairs(Workspace:GetDescendants()) do track(d) end
	Workspace.DescendantAdded:Connect(track)
	-- (a rover parked at camp keeps your Vehicle attribute: that's not driving - the RIDE SHOP is where you go next)
	local function ownRoverParked(): boolean
		local av = Workspace:FindFirstChild("ActiveVehicles")
		for _, m in ipairs(av and av:GetChildren() or {}) do
			if m:GetAttribute("Owner") == player.UserId then return m:GetAttribute("Parked") == true end
		end
		return false
	end
	task.spawn(function()
		while true do
			local driving = Drive.State.Mode ~= "None" or (player:GetAttribute("Vehicle") ~= nil and not ownRoverParked())
			for pr in pairs(garagePrompts) do
				if pr.Parent and pr.Enabled == driving then pr.Enabled = not driving end
			end
			task.wait(0.25)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("CampAction") ~= "Garage" then return end
		local idx = player:GetAttribute("Plot")
		if not prompt:FindFirstAncestor("Plot" .. tostring(idx or 0)) then
			Kit.Toast("THAT'S NOT YOUR GARAGE", "Red", "Jeep")
			return
		end
		Garage.Request()
	end)
end

return Garage
