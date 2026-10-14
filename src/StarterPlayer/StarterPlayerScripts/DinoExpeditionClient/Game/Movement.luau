--[[
	Movement — sprinting on foot everywhere outside a fight (Base Camp, the hub, era camps).
	Hold Shift (keyboard), click the left stick (gamepad, toggles) or tap RUN (touch, toggles).
	At encounter sites EncounterView owns walk speeds (sneaking, sprinting, carrying eggs).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)
local Drive = require(script.Parent.Drive)

local player = Players.LocalPlayer
local Movement = {}

local WALK, SPRINT = 20, 32
local held, toggled = false, false
local fov = 0

local function onFoot(): boolean
	-- (free roam: on your feet out in an era counts too)
	local st = Drive.State
	return (st.Mode == "None" or (st.Mode == "Roam" and st.OnFoot)) and player:GetAttribute("Site") == nil and not Cinema.Playing()
end

function Movement.Start()
	local _, canvas = Kit.Screen("DinoMoveUI", 9, false, 0.75)
	local runBtn = Kit.Tile(canvas, { Name = "Run", Icon = "Footprints", Label = "RUN", Color = "Teal", Size = UDim2.fromOffset(84, 84), Position = UDim2.new(1, -24, 1, -230), AnchorPoint = Vector2.new(1, 1), OnClick = function()
		toggled = not toggled
	end })
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then held = true end
		if input.KeyCode == Enum.KeyCode.ButtonL3 then toggled = not toggled end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then held = false end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local free = onFoot()
		runBtn.Visible = free and Kit.Platform() == "Touch"
		local body = runBtn:FindFirstChild("Body") :: Frame?
		if body then body.BackgroundTransparency = toggled and 0 or 0.35 end
		if not free then return end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum:GetAttribute("Frozen") then hum.WalkSpeed = 0 return end -- petting a dino, setting an egg down
		if not hum or player:GetAttribute("HeldEgg") then
			if hum then hum.WalkSpeed = WALK - 4 end -- carrying an egg: careful steps
			return
		end
		local moving = hum.MoveDirection.Magnitude > 0.1
		local sprint = (held or toggled) and moving
		if toggled and not moving then toggled = Kit.Platform() == "Touch" and toggled or false end
		hum.WalkSpeed = sprint and SPRINT or WALK
		-- a little wider view at speed
		local want = sprint and 6 or 0
		fov += (want - fov) * math.min(1, dt * 6)
		local cam = Workspace.CurrentCamera
		if cam.CameraType == Enum.CameraType.Custom then cam.FieldOfView = 70 + fov end
	end)
end

return Movement
