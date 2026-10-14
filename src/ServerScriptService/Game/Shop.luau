--[[
	Shop — the Quartermaster's workshop (+ the garage ride shop's rover upgrades): stat levels (coins) and tier crafts (boss materials + coins) for the
	launcher, armour, rover, roof rack, gadgets, buddy slots; plus incubators and yard slots.
	Every purchase answers with what was built so the client can play the in-person crafting scene.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Shop = {}
local Data, Net, Plots, Vehicles, Expedition, Quests

local function canPay(profile, cost): (boolean, string?)
	if (cost.Coins or 0) > profile.Coins then return false, "NOT ENOUGH COINS" end
	for mat, n in pairs(cost.Mats or {}) do
		if (profile.Materials[mat] or 0) < n then return false, "NEED " .. n .. "x " .. Config.Materials[mat].Name end
	end
	return true, nil
end

local function pay(profile, cost)
	profile.Coins -= cost.Coins or 0
	for mat, n in pairs(cost.Mats or {}) do profile.Materials[mat] -= n end
end

local function done(player: Player, result)
	local profile = Data.Peek(player)
	if profile then
		Plots.Sync(player)
		Data.Changed(player)
	end
	return result
end

-- what: "Armor" | "Rover"  (stat level +1). Launcher levels are gone (2026-10-14): the POWER TRAINER on your
-- island (Trainer.luau) is where launcher power comes from now; launchers are only crafted (at the trainer).
local function levelUp(player: Player, what: string)
	if what ~= "Armor" and what ~= "Rover" then return { Ok = false, Err = "TRAIN AT YOUR POWER TRAINER" } end
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local g = profile.Gear
	local key = what == "Armor" and "ArmorLvl" or "RoverLvl"
	local order = what == "Armor" and Config.Armors[g.Armor].Order or Config.Vehicles[g.Vehicle].Order
	local lvl = g[key] or 1
	if lvl >= Config.MaxLevel then return { Ok = false, Err = "MAX LEVEL - CRAFT THE NEXT TIER" } end
	local cost = { Coins = Config.LevelPrice(order, lvl) }
	-- onboarding: your very first upgrade is free (Quartermaster or ride shop) (after your first expedition)
	local free = not profile.Flags.FreeUpgradeUsed and (profile.Stats.Runs or 0) >= 1
	if free then cost = { Coins = 0 } end
	local ok, err = canPay(profile, cost)
	if not ok then return { Ok = false, Err = err } end
	pay(profile, cost)
	g[key] = lvl + 1
	if free then profile.Flags.FreeUpgradeUsed = true end
	return done(player, { Ok = true, Kind = "Level", What = what, Level = lvl + 1, Free = free })
end

local function craft(player: Player, what: string, id: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local g = profile.Gear
	local info, owned
	if what == "Launcher" then info, owned = Config.Launchers[id], g.Launchers
	elseif what == "Armor" then info, owned = Config.Armors[id], g.Armors
	elseif what == "Gadget" then info, owned = Config.Gadgets[id], g.GadgetsOwned
	elseif what == "Rover" then info, owned = Config.Vehicles[id], g.Vehicles
	elseif what == "Plating" then info, owned = Config.Plating, nil
	else return { Ok = false } end
	if not info then return { Ok = false, Err = "UNKNOWN ITEM" } end
	if what == "Plating" then
		if g.Plating then return { Ok = false, Err = "ALREADY FITTED" } end
	elseif owned[id] then
		return { Ok = false, Err = "ALREADY OWNED" }
	end
	-- tiers go in order: no skipping from the Rookie straight to the Titan Mortar
	local tiers = (what == "Launcher" and Config.LauncherOrder) or (what == "Armor" and Config.ArmorOrder) or (what == "Rover" and Config.VehicleOrder) or nil
	if tiers then
		local prevId = Config.PrevTier(tiers, id)
		if prevId and not owned[prevId] then
			local prev = (what == "Launcher" and Config.Launchers[prevId]) or (what == "Armor" and Config.Armors[prevId]) or Config.Vehicles[prevId]
			return { Ok = false, Err = "CRAFT THE " .. string.upper(prev and prev.Name or prevId) .. " FIRST" }
		end
	end
	local cost = info.Craft or { Coins = info.Price or 0, Mats = info.Mats }
	local ok, err = canPay(profile, cost)
	if not ok then return { Ok = false, Err = err } end
	pay(profile, cost)
	if what == "Plating" then
		g.Plating = true
	else
		owned[id] = true
		-- equip what you just built (a new tier starts at level 1)
		if what == "Launcher" then g.Launcher = id g.LauncherLvl = 1
		elseif what == "Armor" then g.Armor = id g.ArmorLvl = 1
		elseif what == "Rover" then g.Vehicle = id g.RoverLvl = 1
		elseif what == "Gadget" then
			for i = 1, Config.GadgetSlots do if (g.Gadgets[i] or "") == "" then g.Gadgets[i] = id break end end
		end
	end
	if Quests and info.Craft then Quests.Progress(player, "Craft", { Count = 1 }) end
	if what == "Rover" and Vehicles.Get(player) and not Vehicles.CampParked[player] and not Expedition.Get(player) then Vehicles.Spawn(player) end
	Net.FireAll("Announce", { Text = string.format("%s BUILT THE %s!", string.upper(player.DisplayName), info.Name), Color = "Orange" })
	return done(player, { Ok = true, Kind = "Craft", What = what, Id = id, Name = info.Name, Perk = info.Perk })
end

local function equip(player: Player, what: string, id: string, slot: number?)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local g = profile.Gear
	if what == "Launcher" and g.Launchers[id] then g.Launcher = id
	elseif what == "Armor" and g.Armors[id] then g.Armor = id
	elseif what == "Rover" and g.Vehicles[id] then
		g.Vehicle = id
		if Vehicles.Get(player) and not Vehicles.CampParked[player] and not Expedition.Get(player) then Vehicles.Spawn(player) end
	elseif what == "Gadget" and (id == "" or g.GadgetsOwned[id]) then
		-- whole slots only (a client sending 1.5 used to write a non-array key into the saved gadget list)
		local s = math.clamp(math.floor(tonumber(slot) or 1), 1, Config.GadgetSlots)
		if s ~= s then s = 1 end
		for i = 1, Config.GadgetSlots do if g.Gadgets[i] == id then g.Gadgets[i] = "" end end
		g.Gadgets[s] = id
	else
		return { Ok = false, Err = "NOT OWNED" }
	end
	return done(player, { Ok = true })
end

local function buyBase(player: Player, what: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local g = profile.Gear
	local cost, apply
	if what == "Incubator" then
		if profile.IncubatorCount >= Config.IncubatorMax(profile) then
			return { Ok = false, Err = profile.IncubatorCount < Config.Island.Hatchery[#Config.Island.Hatchery].Nests and "UPGRADE YOUR HATCHERY FOR MORE NESTS" or "ALL INCUBATORS BUILT" }
		end
		cost = { Coins = Config.IncubatorPrice(profile.IncubatorCount) }
		apply = function() profile.IncubatorCount += 1 end
	elseif what == "Pen" then
		if profile.PenSlots >= Config.Pen.Max then return { Ok = false, Err = "YARD IS MAXED" } end
		cost = { Coins = Config.PenPrice(profile.PenSlots) }
		apply = function() profile.PenSlots += 1 end
	elseif what == "Rack" then
		if Config.Rack.Base + g.Rack >= Config.Rack.Max then return { Ok = false, Err = "RACK IS MAXED" } end
		cost = { Coins = Config.Rack.Prices[g.Rack + 1] }
		apply = function() g.Rack += 1 end
	elseif what == "Buddy" then
		local n = g.BuddySlots or 1
		local c = Config.BuddySlots.Crafts[n]
		if not c then return { Ok = false, Err = "ALL COMPANION SLOTS OPEN" } end
		cost = c
		apply = function() g.BuddySlots = n + 1 end
	elseif what == "GadgetBait" then
		if g.GadgetsOwned.Bait then return { Ok = false, Err = "ALREADY OWNED" } end
		cost = { Coins = Config.Gadgets.Bait.Price }
		apply = function()
			g.GadgetsOwned.Bait = true
			if (g.Gadgets[1] or "") == "" then g.Gadgets[1] = "Bait" end
		end
	else
		return { Ok = false }
	end
	local ok, err = canPay(profile, cost)
	if not ok then return { Ok = false, Err = err } end
	pay(profile, cost)
	apply()
	return done(player, { Ok = true, Kind = "Base", What = what })
end

-- ISLAND BUILDS (Config.Island): what = "Hatchery" | "Garage" (next tier), or "Pen" (lot, dino):
-- build a star pen for that dino's species on an empty lot, or move a different star of the same species in
local Dinos
local function islandBuild(player: Player, args)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	profile.Island = profile.Island or { Hatchery = 1, Garage = 1, Pens = {} }
	local isl = profile.Island
	isl.Pens = isl.Pens or {}
	local what = args.What
	if what == "Hatchery" or what == "Garage" then
		local tiers = Config.Island[what]
		local cur = Config.IslandTier(profile, what)
		local nxt = tiers[cur + 1]
		if not nxt then return { Ok = false, Err = "FULLY UPGRADED" } end
		local ok, err = canPay(profile, nxt.Cost)
		if not ok then return { Ok = false, Err = err } end
		pay(profile, nxt.Cost)
		isl[what] = cur + 1
		-- a faster hatchery speeds up the eggs already in it, too (you see the timers drop right away)
		if what == "Hatchery" then
			local k = nxt.Speed / tiers[cur].Speed
			local now = os.time()
			for _, inc in ipairs(profile.Incubators) do
				local left = inc.Start + inc.Duration - now
				if left > 0 then inc.Duration = (now - inc.Start) + math.ceil(left * k) end
			end
		end
		return done(player, { Ok = true, Kind = "Island", What = what, Tier = cur + 1, Name = nxt.Name })
	elseif what == "Pen" then
		local lot, dinoId = args.Lot, args.Dino
		if typeof(lot) ~= "string" or not Config.Island.Lots[lot] or typeof(dinoId) ~= "string" then return { Ok = false } end
		local dino
		for _, d in ipairs(profile.Dinos) do if d.Id == dinoId then dino = d break end end
		if not dino then return { Ok = false, Err = "NO SUCH DINO" } end
		local penDef = Config.Island.Pens[dino.Species]
		if not penDef then return { Ok = false, Err = "ONLY BOSS DINOS GET A STAR PEN" } end
		if Config.PenLotKind(dino.Species) ~= Config.Island.Lots[lot] then
			return { Ok = false, Err = penDef.Sea and "THE SEA PEN IS OUT IN THE WATER" or "THIS ONE NEEDS A LAND LOT" }
		end
		for other, pen in pairs(isl.Pens) do
			if other ~= lot and pen.Dino == dinoId then return { Ok = false, Err = "ALREADY IN A STAR PEN" } end
		end
		local pen = isl.Pens[lot]
		local built = false
		-- every check first, then change anything (CHANGE PEN used to knock the old pen down, then fail a check)
		local replacing = pen ~= nil and pen.Species ~= dino.Species
		if replacing and args.Rebuild ~= true then return { Ok = false, Err = "THAT PEN IS FOR A " .. ((Config.Species[pen.Species] or {}).Name or "DIFFERENT DINO") } end
		-- one pen per boss species: collect them all, don't stack one
		for other, op in pairs(isl.Pens) do
			if other ~= lot and op.Species == dino.Species then return { Ok = false, Err = "YOU ALREADY HAVE A " .. penDef.Name } end
		end
		if not pen or replacing then
			local ok, err = canPay(profile, penDef.Cost)
			if not ok then return { Ok = false, Err = err } end
		end
		local oldStar = nil
		if replacing then
			-- a different pen on a built lot (CHANGE PEN): the old one comes down, its star moves out
			oldStar = pen.Dino
			isl.Pens[lot] = nil
			pen = nil
		end
		if not pen then
			pay(profile, penDef.Cost)
			pen = { Species = dino.Species, Dino = "" }
			isl.Pens[lot] = pen
			built = true
		end
		-- the star moves in: it leaves the yard / your companions (a pen star earns without taking a yard slot).
		-- The one it replaces goes back to your yard if there's room (else it waits in your bag).
		local old = (pen.Dino ~= "" and pen.Dino) or oldStar
		Dinos.MoveToPen(profile, player, dinoId)
		pen.Dino = dinoId
		local oldTo = nil
		local stillOwned = false
		for _, d in ipairs(profile.Dinos) do if d.Id == old then stillOwned = true break end end
		if stillOwned and old ~= dinoId and not table.find(profile.Placed, old) then
			if #profile.Placed < profile.PenSlots then table.insert(profile.Placed, old) oldTo = "Yard" else oldTo = "Bag" end
		end
		return done(player, { Ok = true, Kind = "Island", What = "Pen", Lot = lot, Species = dino.Species, Built = built, Name = penDef.Name, OldTo = oldTo })
	end
	return { Ok = false }
end

-- (the trainer crafts and equips launchers through these: Trainer.luau TrainerCraft / TrainerEquip)
Shop.Craft = craft
Shop.Equip = equip

function Shop.Start(deps)
	Data, Net, Plots, Vehicles, Expedition, Quests = deps.Data, deps.Net, deps.Plots, deps.Vehicles, deps.Expedition, deps.Quests
	Net.On("LevelUp", function(player, args) return typeof(args.What) == "string" and levelUp(player, args.What) or { Ok = false } end)
	Net.On("Craft", function(player, args)
		if typeof(args.What) ~= "string" or typeof(args.Id) ~= "string" then return { Ok = false } end
		return craft(player, args.What, args.Id)
	end)
	Net.On("EquipGear", function(player, args)
		if typeof(args.What) ~= "string" or typeof(args.Id) ~= "string" then return { Ok = false } end
		return equip(player, args.What, args.Id, tonumber(args.Slot))
	end)
	Net.On("BuyBase", function(player, args) return typeof(args.What) == "string" and buyBase(player, args.What) or { Ok = false } end)
	Dinos = deps.Dinos
	Net.On("IslandBuild", function(player, args) return typeof(args) == "table" and typeof(args.What) == "string" and islandBuild(player, args) or { Ok = false } end)
end

return Shop
