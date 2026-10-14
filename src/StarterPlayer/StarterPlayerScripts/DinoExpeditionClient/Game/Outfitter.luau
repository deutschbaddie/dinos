--[[
	Outfitter — the Armorer's turntable shows what YOU are working toward: a mannequin wearing the next
	armor you can get (fully kitted, every piece), slowly turning, with a sign. It holds YOUR launcher: launchers
	come from your power trainer since 2026-10-14 (the Armorer only does armor + gadgets now).
	Local to you (everyone sees their own next upgrade). Got everything? It shows off your top set instead.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local Gear = require(DinoShared:WaitForChild("Game"):WaitForChild("Gear"))
local Kit = require(script.Parent.UI.Kit)
local Net = require(script.Parent.Net)

local Outfitter = {}
local C = Kit.Colors
local state = { Model = nil :: Model?, Key = nil :: string?, Yaw = 0, Anchor = nil :: BasePart? }

local function picks()
	local g = (Net.Profile and Net.Profile.Gear) or {}
	local armor = Gear.NextTier(Config.ArmorOrder, g.Armors)
	local maxed = armor == nil
	return armor or g.Armor or "None", g.Launcher or "Rookie", maxed, armor ~= nil
end

local function build()
	local anchor = state.Anchor
	local g = DinoShared:FindFirstChild("Gear")
	local tpl = g and g:FindFirstChild("Mannequin")
	if not (anchor and tpl) then return end
	local armor, launcher, maxed, newArmor = picks()
	local key = armor .. "|" .. launcher
	if key == state.Key and state.Model and state.Model.Parent then return end
	if state.Model then state.Model:Destroy() end
	state.Key = key
	local m = tpl:Clone() :: Model
	m.Name = "OutfitterMannequin"
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false p.CanQuery = false p.CanTouch = false end
	end
	m.Parent = Workspace
	Gear.DressArmor(m, armor, 10)
	Gear.Hold(m, launcher)
	-- the sign over it
	local head = m:FindFirstChild("Head") :: BasePart?
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Name = "OutfitterSign"
		bb.Size = UDim2.fromOffset(260, 96)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = false
		bb.LightInfluence = 0
		bb.MaxDistance = 90
		bb.Adornee = head
		local title = maxed and "FULLY KITTED!" or "NEXT UP"
		Kit.Text(bb, title, { Size = UDim2.new(1, 0, 0, 30), Color = C.YellowHi, Color2 = C.Orange, Stroke = 3.5, Shadow = 3, MaxSize = 30 })
		local a = Config.Armors[armor] :: any
		local lines = {}
		if newArmor or maxed then table.insert(lines, (a and a.Name) or armor) end
		Kit.Text(bb, table.concat(lines, "  +  "), { Pixel = true, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 40), Color = C.Cream, Stroke = 2.5, Shadow = 2, MaxSize = 12 })
		Kit.Text(bb, maxed and "THE BEST GEAR THERE IS" or "ASK THE ARMORER", { Pixel = true, Size = UDim2.new(1, 0, 0, 9), Position = UDim2.fromOffset(0, 62), Color = C.Muted, Stroke = 2, Shadow = 1, MaxSize = 9 })
		bb.Parent = head
	end
	state.Model = m
end

function Outfitter.Start()
	task.spawn(function()
		local camp = Workspace:WaitForChild("BaseCamp", 60)
		if not camp then return end
		for _ = 1, 30 do
			local a = camp:FindFirstChild("TurntableAnchor", true)
			if a and a:IsA("BasePart") then state.Anchor = a break end
			task.wait(1)
		end
		if not state.Anchor then return end
		build()
		Net.On("Profile", function() pcall(build) end)
		RunService.RenderStepped:Connect(function(dt)
			local m = state.Model
			local anchor = state.Anchor
			if not (m and m.Parent and anchor) then return end
			-- only bother turning it when you're near enough to see it
			local cam = Workspace.CurrentCamera
			if cam and (cam.CFrame.Position - anchor.Position).Magnitude > 160 then return end
			state.Yaw += dt * 0.5
			local base = CFrame.new(anchor.Position) * CFrame.Angles(0, state.Yaw, 0) -- the marker sits on the turntable top
			m:PivotTo(base * CFrame.new(0, 4.5, 0)) -- the dummy's root sits 4.5 above its stand's foot
		end)
	end)
	local _ = Players
end

return Outfitter
