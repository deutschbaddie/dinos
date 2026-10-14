--[[
	Monetization — game passes (checked on join, marked as player attributes "Pass_<Name>") and developer
	products (luck boost, instant hatch, premium egg). Ids live in Config.Passes / Config.Products; a 0 id
	means "not created yet" and is simply skipped.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Monetization = {}
local Data, Net, Dinos, Plots

local function checkPasses(player: Player)
	for name, pass in pairs(Config.Passes) do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id) end)
			if ok and owns then player:SetAttribute("Pass_" .. name, true) end
		end
	end
	local profile = Data.Get(player)
	if profile and player:GetAttribute("Pass_MoreIncubators") and not profile.Flags.PassIncubators then
		profile.Flags.PassIncubators = true
		profile.IncubatorCount = math.min(Config.IncubatorMax(profile), profile.IncubatorCount + 2)
		Plots.Sync(player)
		Data.Changed(player)
	end
end

-- (also called by init.server once the profile has loaded, in case the PRE-BETA gate held the join past Data.Get's wait)
Monetization.Refresh = checkPasses

local PRODUCT = {}
local rng = Random.new()

-- one shop egg into the bag (paid: it always fits): species even across your unlocked eras, rarity from the exact
-- shop odds (Config.EggOdds, the numbers SEE ODDS shows)
local function giveEgg(player: Player, profile, kind: string)
	local pool = Config.ShopEggSpecies(profile.Unlocked)
	local species = pool[rng:NextInteger(1, #pool)]
	local rarity = Config.ShopEggRoll(kind, rng:NextNumber())
	return Dinos.AddEgg(player, species, rarity, nil, nil, true)
end

-- the contents of a product (Config.ProductGrants), applied; returns what was given for the receipt card
local function applyGrants(player: Player, profile, id: string)
	local got = { Eggs = {}, Coins = 0, Luck = 0, Hatch = 0, Slot = 0 }
	for _, g in ipairs(Config.ProductGrants[id] or {}) do
		if g.Kind == "Egg" then
			for _ = 1, g.Count or 1 do
				local e = giveEgg(player, profile, g.Egg)
				if e then table.insert(got.Eggs, { Species = e.Species, Rarity = e.Rarity }) end
			end
		elseif g.Kind == "Coins" then
			profile.Coins += g.Amount or 0 -- (bought coins don't count towards Earned: the leaderboard is earned money)
			got.Coins += g.Amount or 0
		elseif g.Kind == "Luck" then
			profile.LuckUntil = math.max(os.time(), profile.LuckUntil or 0) + (g.Minutes or 15) * 60
			got.Luck += g.Minutes or 15
		elseif g.Kind == "Hatch" then
			-- each one finishes an egg that's incubating now; the rest wait for your next eggs
			for _ = 1, g.Count or 1 do
				local done = false
				for _, inc in ipairs(profile.Incubators) do
					if os.time() < inc.Start + inc.Duration then inc.Start = os.time() - inc.Duration done = true break end
				end
				if not done then profile.InstantHatches = (profile.InstantHatches or 0) + 1 end
			end
			got.Hatch += g.Count or 1
			Plots.Sync(player)
		elseif g.Kind == "Slot" then
			local gear = profile.Gear
			if (gear.BuddySlots or 1) >= Config.BuddySlots.Max then
				-- every slot already open: a premium egg instead, never nothing
				local e = giveEgg(player, profile, "Premium")
				if e then table.insert(got.Eggs, { Species = e.Species, Rarity = e.Rarity }) end
			else
				gear.BuddySlots = (gear.BuddySlots or 1) + 1
				got.Slot += 1
				Plots.Sync(player)
			end
		end
	end
	return got
end

local function grant(player: Player, productId: number): boolean
	local profile = Data.Peek(player)
	if not profile then return false end
	local name = PRODUCT[productId]
	if not name or not Config.ProductGrants[name] then return false end
	local def = Config.Products[name]
	local got = applyGrants(player, profile, name)
	if def.OneTime then
		profile.Flags.Packs = typeof(profile.Flags.Packs) == "table" and profile.Flags.Packs or {}
		profile.Flags.Packs[name] = true
	end
	Data.Changed(player)
	-- the client shows what came out (ShopReveal): eggs best first
	table.sort(got.Eggs, function(a, b) return (Config.Rarity[a.Rarity].Order) > (Config.Rarity[b.Rarity].Order) end)
	Net.Fire(player, "ShopGot", { Product = name, Name = def.Name, Got = got })
	return true
end

function Monetization.Start(deps)
	Data, Net, Dinos, Plots = deps.Data, deps.Net, deps.Dinos, deps.Plots
	for name, p in pairs(Config.Products) do if p.Id ~= 0 then PRODUCT[p.Id] = name end end
	Players.PlayerAdded:Connect(function(p) task.spawn(checkPasses, p) end)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(checkPasses, p) end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if bought then task.spawn(checkPasses, player) end
		local _ = passId
	end)
	-- a purchase only counts once it's saved: Roblox re-sends an unconfirmed receipt (next join too), and the
	-- PurchaseId log stops that re-send granting twice. A temporary (unsaved) profile never takes Robux,
	-- except in Studio, where purchases are free tests.
	local studio = game:GetService("RunService"):IsStudio()
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local profile = Data.Peek(player)
		if not profile or (Data.Offline[player] and not studio) then return Enum.ProductPurchaseDecision.NotProcessedYet end
		profile.Receipts = typeof(profile.Receipts) == "table" and profile.Receipts or {}
		local log = profile.Receipts
		if not log[info.PurchaseId] then
			local ok, granted = pcall(grant, player, info.ProductId)
			if not (ok and granted) then
				if not ok then warn("[Monetization] grant failed:", granted) end
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			log[info.PurchaseId] = os.time()
			-- keep the newest 50
			local ids = {}
			for id, t in pairs(log) do table.insert(ids, { id, t }) end
			if #ids > 50 then
				table.sort(ids, function(a, b) return a[2] > b[2] end)
				for i = 51, #ids do log[ids[i][1]] = nil end
			end
		end
		if studio and Data.Offline[player] then return Enum.ProductPurchaseDecision.PurchaseGranted end
		if Data.Save(player) then return Enum.ProductPurchaseDecision.PurchaseGranted end
		return Enum.ProductPurchaseDecision.NotProcessedYet -- (granted in this session; the log stops a second grant on retry)
	end
end

return Monetization
