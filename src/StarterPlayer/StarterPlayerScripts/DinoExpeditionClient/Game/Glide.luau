--[[
	Glide — the Microraptor companion's perk (Config.BuddyRole.Microraptor.Glide): with one following you, HOLD JUMP
	while you're falling and you glide - the fall slows to a drift and you sail forward, feathers trailing. Off a
	ledge, a rock, a cliff. (Its other half - your dodge becomes an air dash - is in EncounterView.View.Dodge.)

	Glide.Has() -> boolean   is a glide companion following you right now?
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))
local Net = require(script.Parent.Net)

local player = Players.LocalPlayer
local Glide = {}

-- (the profile only changes now and then: the answer is cached for a moment)
local hasAt, hasIt = -math.huge, false
function Glide.Has(): boolean
	if os.clock() - hasAt < 1 then return hasIt end
	hasAt = os.clock()
	hasIt = false
	local p = Net.Profile
	if not p or not p.Buddies then return false end
	for _, id in ipairs(p.Buddies) do
		for _, d in ipairs(p.Dinos or {}) do
			if d.Id == id and Config.BuddyRoleOf(d.Species).Glide and not ((d.HurtUntil or 0) > os.time()) then
				hasIt = true
				return true
			end
		end
	end
	return false
end

local FALL = -7 -- the slowest it lets you drop (studs/s)
local AHEAD = 26 -- how fast you sail forward

function Glide.Start()
	local trail = nil :: ParticleEmitter?
	local gliding = false
	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local on = false
		if hum and root and not hum.SeatPart and hum:GetState() == Enum.HumanoidStateType.Freefall and hum.Jump
			and not player:GetAttribute("Swimming") and not player:GetAttribute("Downed") and Glide.Has() then
			local v = root.AssemblyLinearVelocity
			-- a moment into the fall (not the top of a normal jump)
			if v.Y < -2 then
				on = true
				local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
				look = look.Magnitude > 0.1 and look.Unit or Vector3.zero
				local move = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection.Unit or look
				local flat = Vector3.new(v.X, 0, v.Z)
				flat = flat:Lerp(move * AHEAD, math.min(1, dt * 3))
				root.AssemblyLinearVelocity = Vector3.new(flat.X, math.max(v.Y, FALL), flat.Z)
			end
		end
		if on ~= gliding then
			gliding = on
			if on and root then
				if not trail or not trail.Parent then
					local pe = Instance.new("ParticleEmitter")
					pe.Name = "DinoGlideTrail"
					pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					pe.Rate = 26
					pe.Lifetime = NumberRange.new(0.4, 0.8)
					pe.Speed = NumberRange.new(0.5, 2)
					pe.SpreadAngle = Vector2.new(40, 40)
					pe.Size = NumberSequence.new(0.35, 0)
					pe.Color = ColorSequence.new(Color3.fromRGB(46, 197, 214))
					pe.LightEmission = 0.6
					pe.Parent = root
					trail = pe
				end
				(trail :: ParticleEmitter).Enabled = true
			elseif trail then
				trail.Enabled = false
			end
		end
	end)
end

return Glide
