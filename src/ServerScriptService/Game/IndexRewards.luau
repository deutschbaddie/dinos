--[[
	IndexRewards — the DINO INDEX pays out (2026-10-14, round 2 #4). The numbers live in IndexDefs (shared with the
	client's track); this validates and pays.

	IndexClaim { Key }    claim one reward that's ready: "Species/10" (a species-track node) or "Era/FernValley"
	                      (an era page). Coins land at once; the luck / power bonuses are permanent (Boosts source
	                      "Index"); a title is yours to wear; an era page also gilds that boss's trophy at home.
	IndexTitle { Title }  wear one of your earned titles ("" = none). It shows over your head (player attribute
	                      IndexTitle = "NAME|RRGGBB|rainbow") and on your profile card.
	Plot attribute IndexGold = JSON { bossId = true } (CampView gilds those trophy statues).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Defs = require(ReplicatedStorage.DinoExpedition.Game.IndexDefs)

local IndexRewards = {}
local Net, Data, Plots

local function state(profile)
	if typeof(profile.IndexRewards) ~= "table" then profile.IndexRewards = {} end
	local ir = profile.IndexRewards
	if typeof(ir.Claimed) ~= "table" then ir.Claimed = {} end
	if typeof(ir.Title) ~= "string" then ir.Title = "" end
	return ir
end

-- the nametag line: "NAME|RRGGBB" (+ "|rainbow"), or nil
local function titleAttr(profile): string?
	local id = state(profile).Title
	local t = id ~= "" and Defs.Titles[id]
	if not t then return nil end
	return t.Name .. "|" .. t.Color:ToHex() .. (t.Rainbow and "|rainbow" or "")
end

-- what other players see: the title over your head and the gold trophies on your island
local function publish(player: Player, profile)
	local want = titleAttr(profile)
	if player:GetAttribute("IndexTitle") ~= want then player:SetAttribute("IndexTitle", want) end
	local plot = Plots and Plots.Get(player)
	if plot then
		local ok, json = pcall(HttpService.JSONEncode, HttpService, Defs.GoldTrophies(profile))
		if ok and plot:GetAttribute("IndexGold") ~= json then plot:SetAttribute("IndexGold", json) end
	end
end

local function claim(player: Player, args)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local key = args.Key
	if typeof(key) ~= "string" or #key > 40 then return { Ok = false, Err = "UNKNOWN REWARD" } end
	local r = Defs.Find(profile, key)
	if not r then return { Ok = false, Err = "UNKNOWN REWARD" } end
	if r.Claimed then return { Ok = false, Err = "ALREADY CLAIMED" } end
	if not r.Ready then return { Ok = false, Err = "NOT YET - KEEP HATCHING!" } end
	local ir = state(profile)
	ir.Claimed[key] = true
	local pay = Defs.Payout(r)
	local coins = math.floor(tonumber(pay.Coins) or 0)
	if coins > 0 then
		profile.Coins += coins
		profile.Earned += coins
	end
	-- a new title goes straight on (you can swap back in the Index)
	if pay.Title and Defs.Titles[pay.Title] then ir.Title = pay.Title end
	publish(player, profile)
	Data.Changed(player)
	if pay.Title or pay.Gold then
		local t = pay.Title and Defs.Titles[pay.Title]
		Net.FireOthers(player, "Announce", { Text = string.format("%s IS NOW A %s!", string.upper(player.DisplayName), t and t.Name or "DINO EXPERT"), Color = "Blue" })
	end
	return { Ok = true, Key = key, Kind = r.Kind, Era = r.Era and r.Era.Id or nil, Luck = pay.Luck, Power = pay.Power, Coins = coins, Title = pay.Title, Gold = pay.Gold }
end

local function wear(player: Player, args)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local id = args.Title
	if typeof(id) ~= "string" then return { Ok = false } end
	if id ~= "" and not table.find(Defs.EarnedTitles(profile), id) then return { Ok = false, Err = "EARN THAT TITLE FIRST" } end
	state(profile).Title = id
	publish(player, profile)
	Data.Changed(player)
	return { Ok = true, Title = id }
end

-- the Boosts module (BOOSTS agent, round 2) reads every source's bonus through Boosts.AddSource; it may land after
-- us, so keep trying for a while (a bonus that isn't hooked up is just not counted yet - never an error)
local function hookBoosts()
	task.spawn(function()
		for _ = 1, 60 do
			local mod = script.Parent:FindFirstChild("Boosts")
			if mod then
				local ok, err = pcall(function()
					local Boosts = require(mod :: ModuleScript) :: any
					Boosts.AddSource("Index", function(player: Player)
						local profile = Data.Peek(player)
						if not profile then return {} end
						local luck, power = Defs.Bonus(profile)
						return { Luck = luck, Power = power }
					end)
				end)
				if not ok then warn("[IndexRewards] Boosts source:", err) end
				return
			end
			task.wait(2)
		end
	end)
end

function IndexRewards.Start(deps)
	Net, Data, Plots = deps.Net, deps.Data, deps.Plots
	Net.On("IndexClaim", claim)
	Net.On("IndexTitle", wear)
	-- (every push: the title + gold trophies follow a load, a claim, a reset, a fresh island)
	Data.OnChanged(function(player, profile)
		if typeof(profile) == "table" then publish(player, profile) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local plot = Plots and Plots.Get(player)
		if plot then plot:SetAttribute("IndexGold", nil) end
	end)
	hookBoosts()
end

return IndexRewards
