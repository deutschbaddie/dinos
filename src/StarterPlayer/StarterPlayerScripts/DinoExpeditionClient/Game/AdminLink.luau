--[[
	AdminLink — the admin tools that have to run on a player's own game (Admin.luau on the server checks every request):

	  AdminTP     GO TO / BRING: the server moves your body, and your own game lands you there too, in that world's
	              light (your game owns your character, and a run ending under you used to snap you straight back)
	  CamStream   (every player) while the owner is watching you, your camera is quietly reported - nothing on your
	              screen changes, nothing tells you
	  WatchFrame  (the owner) the watched player's camera: yours follows it, smoothed, in their world's light

	AdminLink.Watch(target) / AdminLink.Unwatch() / AdminLink.Watching() -> Player?   (the ADMIN tab's buttons)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent.Net)
local Zone = require(script.Parent.Zone)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)

local player = Players.LocalPlayer
local AdminLink = {}

--------------------------------------------------------------------------------
-- teleports that stick
--------------------------------------------------------------------------------
local function land(at: CFrame)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hum and root) then return end
	if hum.SeatPart then hum.Sit = false end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	char:PivotTo(at)
end

local function onTP(d)
	if typeof(d) ~= "table" or typeof(d.At) ~= "CFrame" then return end
	local at: CFrame = d.At
	local zone = typeof(d.Zone) == "string" and d.Zone or nil
	land(at)
	if zone and Zone.Current ~= zone then Zone.Apply(zone, true) end
	-- (leaving a run resets you to camp a beat later - land again once that's settled, and hand the camera back)
	for _, after in ipairs({ 0.45, 1.3 }) do
		task.delay(after, function()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - at.Position).Magnitude > 14 then land(at) end
			if zone and Zone.Current ~= zone then Zone.Apply(zone, true) end
			local cam = Workspace.CurrentCamera
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if cam and hum and not Cinema.Playing() and not AdminLink.Watching() then
				cam.CameraType = Enum.CameraType.Custom
				cam.CameraSubject = hum
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- being watched (any player): report the camera, show nothing
--------------------------------------------------------------------------------
local streaming = 0 -- a generation: a new On/Off ends the old loop
local function onStream(d)
	streaming += 1
	if not (typeof(d) == "table" and d.On) then return end
	local gen = streaming
	task.spawn(function()
		while streaming == gen do
			local cam = Workspace.CurrentCamera
			if cam then
				local cf = cam.CFrame
				-- (the server says Stop once nobody's watching any more)
				local ok, r = pcall(Net.Ask, "CamFrame", { P = cf.Position, L = cf.LookVector, F = cam.FieldOfView })
				if ok and typeof(r) == "table" and r.Stop then break end
			end
			task.wait(0.17) -- (the server takes one a name every 0.15 s)
		end
		if streaming == gen then streaming += 1 end
	end)
end

--------------------------------------------------------------------------------
-- watching (the owner): your camera follows theirs
--------------------------------------------------------------------------------
local W = nil :: any -- { Target, Gui, Conn, Goal, Fov, Was = { Zone, Type, Subject, Fov }, Token }

function AdminLink.Watching(): Player?
	return W and W.Target or nil
end

local function stopLocal()
	local w = W
	if not w then return end
	W = nil
	w.Conn:Disconnect()
	if w.Gui then w.Gui:Destroy() end
	Cinema.End(w.Token)
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		cam.CameraSubject = hum or w.Was.Subject
		cam.FieldOfView = w.Was.Fov
	end
	if Zone.Current ~= w.Was.Zone then Zone.Apply(w.Was.Zone, true) end
end

function AdminLink.Unwatch()
	local w = W
	if not w then return end
	stopLocal()
	if w.Target.Parent then Net.Ask("Admin", { Action = "Unwatch", UserId = w.Target.UserId }) end
end

function AdminLink.Watch(target: Player): (boolean, string?)
	if W then AdminLink.Unwatch() end
	local r = Net.Ask("Admin", { Action = "Watch", UserId = target.UserId })
	if not (r and r.Ok) then return false, (r and r.Err) or "FAILED" end
	return true, nil
end

local function startLocal(d)
	local cam = Workspace.CurrentCamera
	local target = Players:GetPlayerByUserId(d.UserId)
	if not (cam and target) then return end
	if W then stopLocal() end
	-- everything of yours steps aside: the screen is theirs (only the name + a way out stay, small, at the bottom)
	local token = Cinema.Begin("DinoAdminWatch")
	token.Long = true
	local gui, canvas = Kit.Screen("DinoAdminWatch", 60)
	Kit.Text(canvas, "WATCHING " .. string.upper(target.Name), { Size = UDim2.fromOffset(360, 22), Position = UDim2.new(0, 18, 1, -78), AnchorPoint = Vector2.new(0, 1), Align = Enum.TextXAlignment.Left, MaxSize = 20, Color = Theme.C.Cream, Stroke = 2.5, ZIndex = 5 })
	Kit.Button(canvas, { Text = "STOP", Icon = "Eye", IconSize = 0.85, TextLeft = 0.34, Color = "Red", Size = UDim2.fromOffset(150, 46), Position = UDim2.new(0, 18, 1, -18), AnchorPoint = Vector2.new(0, 1), ZIndex = 6, OnClick = AdminLink.Unwatch })
	local w = {
		Target = target, Gui = gui, Token = token, Goal = nil :: CFrame?, Fov = cam.FieldOfView,
		Was = { Zone = Zone.Current, Subject = cam.CameraSubject, Fov = cam.FieldOfView },
	}
	if typeof(d.Zone) == "string" and d.Zone ~= Zone.Current then Zone.Apply(d.Zone, true) end
	w.Conn = RunService.RenderStepped:Connect(function(dt)
		local c = Workspace.CurrentCamera
		if not (c and w.Goal) then return end
		c.CameraType = Enum.CameraType.Scriptable
		local a = 1 - math.exp(-dt * 14)
		c.CFrame = c.CFrame:Lerp(w.Goal, a)
		c.FieldOfView += (w.Fov - c.FieldOfView) * a
	end)
	W = w
end

local function onFrame(d)
	if typeof(d) ~= "table" then return end
	if d.Start then startLocal(d) return end
	if d.Stop then stopLocal() return end
	local w = W
	if not w or typeof(d.P) ~= "Vector3" or typeof(d.L) ~= "Vector3" then return end
	local goal = CFrame.lookAt(d.P, d.P + d.L)
	-- (the first frame, or a cut: jump straight there rather than sweeping across the map)
	local cam = Workspace.CurrentCamera
	if cam and (not w.Goal or (w.Goal.Position - goal.Position).Magnitude > 60) then cam.CFrame = goal end
	w.Goal = goal
	w.Fov = math.clamp(tonumber(d.F) or 70, 1, 120)
	if typeof(d.Zone) == "string" and d.Zone ~= Zone.Current then Zone.Apply(d.Zone) end
end

function AdminLink.Start()
	Net.On("AdminTP", onTP)
	Net.On("CamStream", onStream)
	Net.On("WatchFrame", onFrame)
	Players.PlayerRemoving:Connect(function(p) if W and W.Target == p then stopLocal() end end)
end

return AdminLink
