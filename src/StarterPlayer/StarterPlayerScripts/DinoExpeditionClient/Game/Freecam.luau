--[[
	Freecam — a free-flying camera for testers and for filming (Settings > TEST TOOLS > FREECAM, or F8).
	Developers only (the Dev attribute, or Studio). While it's on, every screen is hidden (Cinema) and your
	character stays put; turning it off puts the camera, the UI and your controls back exactly as they were.

	  Keyboard + mouse   WASD fly, E / Q up / down, hold RIGHT-CLICK to look, wheel or 1 / 2 = slower / faster,
	                     Shift = boost, Z / X = zoom in / out, R = level the horizon, H = hide the help, F8 exit
	  Controller         left stick fly, right stick look, RT / LT up / down, RB / LB faster / slower,
	                     L3 = boost, D-pad up / down = zoom, B = exit
	  Touch              drag the left half to fly, the right half to look; UP / DOWN / EXIT buttons
	Movement and turning ease in and out, so a slow pan reads as a real camera move.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local Drive = require(script.Parent.Drive)

local player = Players.LocalPlayer
local C = Theme.C
local Freecam = {}

local SPEEDS = { 4, 10, 24, 50, 100, 200 } -- studs per second
local on = false
local st = nil :: any

local function allowed(): boolean
	return player:GetAttribute("Dev") == true or RunService:IsStudio()
end

-- the help card (bottom left) + touch buttons (its screen is Cinema's to keep: Begin("DinoFreecam"))
local function buildGui()
	local gui, canvas = Kit.Screen("DinoFreecam", 90, false, 0.8)
	local card = Instance.new("Frame")
	card.Name = "Help"
	card.BackgroundColor3 = Color3.fromRGB(10, 14, 12)
	card.BackgroundTransparency = 0.35
	card.Size = UDim2.fromOffset(330, 112)
	card.Position = UDim2.new(0, 16, 1, -16)
	card.AnchorPoint = Vector2.new(0, 1)
	card.Parent = canvas
	Kit.Corner(card, 10)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local lines = touch and "LEFT: FLY   RIGHT: LOOK\nUP / DOWN BUTTONS\nEXIT TO LEAVE"
		or (Kit.Gamepad() and "STICKS: FLY + LOOK   RT/LT: UP/DOWN\nRB/LB: SPEED   L3: BOOST   DPAD: ZOOM\nB: EXIT"
		or "WASD FLY   E/Q UP/DOWN   RIGHT-CLICK LOOK\nWHEEL / 1-2 SPEED   SHIFT BOOST   Z/X ZOOM\nR LEVEL   H HIDE   F8 EXIT")
	local text = Kit.Text(card, lines, { Pixel = true, Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, 8), Align = Enum.TextXAlignment.Left, Color = C.Cream, Stroke = 2, Shadow = 1, MaxSize = 11 })
	local stat = Kit.Text(card, "", { Pixel = true, Size = UDim2.new(1, -20, 0, 14), Position = UDim2.new(0, 10, 1, -24), Align = Enum.TextXAlignment.Left, Color = C.LimeHi, Stroke = 2, Shadow = 1, MaxSize = 12 })
	local buttons = {}
	if UserInputService.TouchEnabled then
		local function btn(label: string, pos: UDim2, color: string, fn)
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(110, 56)
			holder.Position = pos
			holder.AnchorPoint = Vector2.new(1, 1)
			holder.Parent = canvas
			local _, hit = Kit.Button(holder, { Text = label, Color = color, Size = UDim2.fromScale(1, 1), ZIndex = 5, MaxText = 20 })
			return holder, hit
		end
		local _, up = btn("UP", UDim2.new(1, -16, 1, -150), "Teal", nil)
		local _, down = btn("DOWN", UDim2.new(1, -16, 1, -86), "Teal", nil)
		local _, exit = btn("EXIT", UDim2.new(1, -16, 0, 80), "Red", nil)
		buttons = { Up = up, Down = down, Exit = exit }
	end
	return gui, card, stat, buttons, text
end

local function sinkMovement(_, state)
	return Enum.ContextActionResult.Sink
end

function Freecam.On(): boolean
	if on or not allowed() then return false end
	local cam = Workspace.CurrentCamera
	if not cam then return false end
	on = true
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	st = {
		Type = cam.CameraType, Subject = cam.CameraSubject, Fov = cam.FieldOfView,
		Pos = cam.CFrame.Position, Vel = Vector3.zero,
		Yaw = 0, Pitch = 0, Roll = 0, YawV = 0, PitchV = 0,
		Speed = 3, Fov2 = cam.FieldOfView, Look = false, Mouse = UserInputService.MouseBehavior,
		Hum = hum, Walk = hum and hum.WalkSpeed, Jump = hum and hum.JumpPower, JumpH = hum and hum.JumpHeight,
		Touch = {} :: { [InputObject]: { Side: string, Last: Vector2 } }, TouchMove = Vector2.zero, TouchLook = Vector2.zero,
		Up = 0, Conns = {},
	}
	local look = cam.CFrame.LookVector
	st.Yaw = math.atan2(-look.X, -look.Z)
	st.Pitch = math.asin(math.clamp(look.Y, -1, 1))
	st.Token = Cinema.Begin("DinoFreecam")
	st.Token.Long = true
	Drive.HoldCamera(true)
	cam.CameraType = Enum.CameraType.Scriptable
	-- your character stays where it is (and the keys only fly the camera)
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
	end
	ContextActionService:BindActionAtPriority("DinoFreecamSink", sinkMovement, false, 3000,
		Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.Q,
		Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)
	st.Gui, st.Card, st.Stat, st.Buttons, st.Text = buildGui()
	if st.Buttons.Up then
		st.Buttons.Up.MouseButton1Down:Connect(function() st.Up = 1 end)
		st.Buttons.Up.MouseButton1Up:Connect(function() st.Up = 0 end)
		st.Buttons.Down.MouseButton1Down:Connect(function() st.Up = -1 end)
		st.Buttons.Down.MouseButton1Up:Connect(function() st.Up = 0 end)
		st.Buttons.Exit.Activated:Connect(function() Freecam.Off() end)
	end
	-- input
	table.insert(st.Conns, UserInputService.InputBegan:Connect(function(input, processed)
		if not on then return end
		local kc = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			st.Look = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local cam2 = Workspace.CurrentCamera
			local side = (cam2 and input.Position.X < cam2.ViewportSize.X / 2) and "Move" or "Look"
			-- (the left half counts even over Roblox's own thumbstick, which marks touches as taken; on the right our
			-- UP / DOWN / EXIT buttons take theirs)
			if side == "Look" and processed then return end
			st.Touch[input] = { Side = side, Start = Vector2.new(input.Position.X, input.Position.Y), Last = Vector2.new(input.Position.X, input.Position.Y) }
		elseif kc == Enum.KeyCode.One or kc == Enum.KeyCode.ButtonL1 then
			st.Speed = math.max(1, st.Speed - 1)
		elseif kc == Enum.KeyCode.Two or kc == Enum.KeyCode.ButtonR1 then
			st.Speed = math.min(#SPEEDS, st.Speed + 1)
		elseif kc == Enum.KeyCode.R then
			st.Roll = 0
		elseif kc == Enum.KeyCode.H then
			st.Card.Visible = not st.Card.Visible
		elseif kc == Enum.KeyCode.ButtonB then
			Freecam.Off()
		end
	end))
	table.insert(st.Conns, UserInputService.InputEnded:Connect(function(input)
		if not on then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			st.Look = false
			UserInputService.MouseBehavior = st.Mouse
		elseif st.Touch[input] then
			st.Touch[input] = nil
		end
	end))
	table.insert(st.Conns, UserInputService.InputChanged:Connect(function(input, processed)
		if not on then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement and st.Look then
			st.YawV -= input.Delta.X * 0.0045
			st.PitchV -= input.Delta.Y * 0.0045
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			st.Speed = math.clamp(st.Speed + (input.Position.Z > 0 and 1 or -1), 1, #SPEEDS)
		elseif input.UserInputType == Enum.UserInputType.Touch and st.Touch[input] then
			local t = st.Touch[input]
			local p = Vector2.new(input.Position.X, input.Position.Y)
			if t.Side == "Look" then
				local d = p - t.Last
				st.YawV -= d.X * 0.006
				st.PitchV -= d.Y * 0.006
			end
			t.Last = p
		end
	end))
	-- the flight
	RunService:BindToRenderStep("DinoFreecam", Enum.RenderPriority.Camera.Value + 5, function(dt)
		if not on then return end
		dt = math.min(dt, 1 / 20)
		local c = Workspace.CurrentCamera
		if not c then return end
		c.CameraType = Enum.CameraType.Scriptable
		local k = UserInputService
		local move = Vector3.zero
		local typing = k:GetFocusedTextBox() ~= nil
		if not typing then
			if k:IsKeyDown(Enum.KeyCode.W) then move += Vector3.new(0, 0, -1) end
			if k:IsKeyDown(Enum.KeyCode.S) then move += Vector3.new(0, 0, 1) end
			if k:IsKeyDown(Enum.KeyCode.A) then move += Vector3.new(-1, 0, 0) end
			if k:IsKeyDown(Enum.KeyCode.D) then move += Vector3.new(1, 0, 0) end
			if k:IsKeyDown(Enum.KeyCode.E) or k:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
			if k:IsKeyDown(Enum.KeyCode.Q) then move += Vector3.new(0, -1, 0) end
			if k:IsKeyDown(Enum.KeyCode.Z) then st.Fov2 = math.max(8, st.Fov2 - 40 * dt) end
			if k:IsKeyDown(Enum.KeyCode.X) then st.Fov2 = math.min(110, st.Fov2 + 40 * dt) end
		end
		local boost = k:IsKeyDown(Enum.KeyCode.LeftShift)
		-- controller
		for _, s in ipairs(k:GetGamepadState(Enum.UserInputType.Gamepad1)) do
			if s.KeyCode == Enum.KeyCode.Thumbstick1 and s.Position.Magnitude > 0.15 then
				move += Vector3.new(s.Position.X, 0, -s.Position.Y)
			elseif s.KeyCode == Enum.KeyCode.Thumbstick2 and s.Position.Magnitude > 0.15 then
				st.YawV -= s.Position.X * 2.4 * dt
				st.PitchV += s.Position.Y * 2.0 * dt
			elseif s.KeyCode == Enum.KeyCode.ButtonR2 and s.Position.Z > 0.1 then
				move += Vector3.new(0, s.Position.Z, 0)
			elseif s.KeyCode == Enum.KeyCode.ButtonL2 and s.Position.Z > 0.1 then
				move -= Vector3.new(0, s.Position.Z, 0)
			elseif s.KeyCode == Enum.KeyCode.ButtonL3 and s.UserInputState == Enum.UserInputState.Begin then
				boost = true
			elseif s.KeyCode == Enum.KeyCode.DPadUp and s.UserInputState == Enum.UserInputState.Begin then
				st.Fov2 = math.max(8, st.Fov2 - 40 * dt)
			elseif s.KeyCode == Enum.KeyCode.DPadDown and s.UserInputState == Enum.UserInputState.Begin then
				st.Fov2 = math.min(110, st.Fov2 + 40 * dt)
			end
		end
		-- touch: the left-half drag is a stick
		for _, t in pairs(st.Touch) do
			if t.Side == "Move" then
				local d = (t.Last - t.Start) / 70
				move += Vector3.new(math.clamp(d.X, -1, 1), 0, math.clamp(d.Y, -1, 1))
			end
		end
		move += Vector3.new(0, st.Up, 0)
		-- turning eases (the velocity bleeds off), so pans glide
		st.Yaw += st.YawV
		st.Pitch = math.clamp(st.Pitch + st.PitchV, -1.5, 1.5)
		local damp = math.exp(-dt * 14)
		st.YawV *= damp
		st.PitchV *= damp
		local rot = CFrame.Angles(0, st.Yaw, 0) * CFrame.Angles(st.Pitch, 0, 0)
		local want = Vector3.zero
		if move.Magnitude > 0 then
			local m = move.Magnitude > 1 and move.Unit or move
			want = rot:VectorToWorldSpace(Vector3.new(m.X, 0, m.Z)) + Vector3.new(0, m.Y, 0)
			want *= SPEEDS[st.Speed] * (boost and 4 or 1)
		end
		st.Vel = st.Vel:Lerp(want, 1 - math.exp(-dt * 6))
		st.Pos += st.Vel * dt
		c.CFrame = CFrame.new(st.Pos) * rot
		c.FieldOfView += (st.Fov2 - c.FieldOfView) * (1 - math.exp(-dt * 8))
		Kit.SetText(st.Stat, string.format("SPEED %d  -  ZOOM %d", SPEEDS[st.Speed], math.floor(c.FieldOfView + 0.5)))
	end)
	return true
end

function Freecam.Off()
	if not on then return end
	on = false
	local s = st
	st = nil
	RunService:UnbindFromRenderStep("DinoFreecam")
	ContextActionService:UnbindAction("DinoFreecamSink")
	for _, c in ipairs(s.Conns) do c:Disconnect() end
	if s.Gui then s.Gui:Destroy() end
	UserInputService.MouseBehavior = s.Mouse or Enum.MouseBehavior.Default
	local hum = s.Hum
	if hum and hum.Parent then
		if s.Walk then hum.WalkSpeed = s.Walk end
		if s.Jump then hum.JumpPower = s.Jump end
		if s.JumpH then hum.JumpHeight = s.JumpH end
	end
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = s.Type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or s.Type
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		cam.CameraSubject = (s.Subject and s.Subject.Parent) and s.Subject or h
		cam.FieldOfView = s.Fov
	end
	Drive.HoldCamera(false)
	Cinema.End(s.Token)
end

function Freecam.Toggle()
	if on then Freecam.Off() else Freecam.On() end
end

function Freecam.Active(): boolean
	return on
end

function Freecam.Start()
	-- F8 (not Shift+P: that's Roblox's own dev freecam, and P is the dev panel's)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.F8 then return end
		if allowed() then Freecam.Toggle() end
	end)
	-- (a respawn mid-flight: the old character's speeds are gone - just leave freecam cleanly)
	player.CharacterAdded:Connect(function() if on then Freecam.Off() end end)
end

return Freecam
