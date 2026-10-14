--[[
	Wardrobe — the launcher slung across everyone's back out in the eras (drawn on every client from the Launcher
	attribute; at a site EncounterView puts it in your hand instead). Hidden while you drive or carry an egg, and
	never in camp - there you just wear your armour (2026-10-13, user: "the gun sits weird - get rid of it in hub").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Gear"))

local Wardrobe = {}
local Runs = ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Runtime"):WaitForChild("Runs")

local function wants(plr: Player, char: Model): boolean
	if plr:GetAttribute("Site") ~= nil then return false end -- in hand at a site
	-- (only out on an expedition: your own run, or riding along in someone's)
	if not Runs:FindFirstChild(tostring(plr.UserId)) and not plr:GetAttribute("RidingWith") then return false end
	if plr:GetAttribute("Holding") or plr:GetAttribute("HeldEgg") then return false end -- arms full
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or hum.Sit then return false end -- driving
	return true
end

local function step()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if not char then continue end
		local id = plr:GetAttribute("Launcher")
		local cur = char:FindFirstChild("DinoLauncherBack")
		if typeof(id) == "string" and wants(plr, char) then
			if not cur or cur:GetAttribute("Id") ~= id then
				local m = Gear.Holster(char, id)
				if m then m:SetAttribute("Id", id) end
			end
		elseif cur then
			cur:Destroy()
		end
	end
end

function Wardrobe.Start()
	task.spawn(function()
		while true do
			pcall(step)
			task.wait(0.25)
		end
	end)
end

return Wardrobe
