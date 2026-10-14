--[[
	GearView — your armor, on you, for everyone to see. The tier you wear sets the look; levelling it adds pieces
	(vest, then shoulder plates, gauntlets, a helmet, and a cape at level 10). Re-dressed whenever your gear
	changes or you respawn. Also publishes Launcher / Armor / ArmorLvl attributes (clients draw the launcher on
	your back in camp and in your hand at sites), and kits the Quartermaster out in top gear.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Gear = require(ReplicatedStorage.DinoExpedition.Game.Gear)

local GearView = {}
local Data

local function dress(player: Player)
	local profile = Data.Peek(player)
	local char = player.Character
	if not (profile and char and char.Parent) then return end
	local g = profile.Gear or {}
	local tier = g.Armor or "None"
	local lvl = g.ArmorLvl or 1
	player:SetAttribute("Launcher", g.Launcher or "Rookie")
	player:SetAttribute("Armor", tier)
	player:SetAttribute("ArmorLvl", lvl)
	local cur = char:FindFirstChild("DinoArmor")
	if cur and cur:GetAttribute("Tier") == tier and cur:GetAttribute("Level") == lvl then return end
	Gear.DressArmor(char, tier, lvl)
end

-- the Quartermaster wears what he sells: a top set with every piece and a launcher on his back
local function dressQuartermaster(npc: Model)
	if npc:FindFirstChild("DinoArmor") then return end
	Gear.DressArmor(npc, "MatriarchPlate", 10)
	Gear.Holster(npc, "MatriarchMortar")
end

function GearView.Start(deps)
	Data = deps.Data
	local function watch(player: Player)
		local function onChar(char: Model)
			char:WaitForChild("HumanoidRootPart", 10)
			-- after the avatar's own parts and accessories are in, so pieces hug the final body
			if not player:HasAppearanceLoaded() then player.CharacterAppearanceLoaded:Wait() end
			task.wait(0.2)
			if player.Character == char then dress(player) end
		end
		player.CharacterAdded:Connect(onChar)
		if player.Character then task.spawn(onChar, player.Character) end
	end
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
	Players.PlayerAdded:Connect(watch)
	Data.OnChanged(function(player) dress(player) end)
	-- the Quartermaster (spawned by Npcs with attribute Npc = "Mechanic")
	-- (Npcs parents each NPC to its NpcSpot_<kind> marker)
	task.spawn(function()
		local camp = Workspace:WaitForChild("BaseCamp", 30)
		if not camp then return end
		for _, spot in ipairs(camp:GetDescendants()) do
			if spot.Name == "NpcSpot_Mechanic" then
				local function check(c: Instance)
					if c:IsA("Model") and c:GetAttribute("Npc") == "Mechanic" then task.delay(0.5, function() pcall(dressQuartermaster, c) end) end
				end
				for _, c in ipairs(spot:GetChildren()) do check(c) end
				spot.ChildAdded:Connect(check)
			end
		end
	end)
end

return GearView
