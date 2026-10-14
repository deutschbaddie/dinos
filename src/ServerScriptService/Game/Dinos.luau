--[[
	Dinos — everything you own that's alive (or about to be): eggs, incubators, hatched dinos, the yard,
	buddies, selling, income and the Dino Index.

	  Eggs roll their rarity when they're created (encounter, boss, chest, product); a hidden pity counter
	  guarantees an EPIC or better at least every Config.Pity eggs.
	  Hatching rolls KG (skewed: heavy ones are rare); heavier = more income and a bigger dino.
	  Placed dinos roam your yard and earn into the cash pad; buddies fight beside you on expeditions.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local IndexDefs = require(ReplicatedStorage.DinoExpedition.Game.IndexDefs)

local Dinos = {}
local Data, Net, Plots, Quests
local rng = Random.new()

local function find(list, id: string)
	for i, v in ipairs(list) do if v.Id == id then return v, i end end
	return nil, nil
end
local function has(list: { string }, id: string): number?
	return table.find(list, id)
end

--------------------------------------------------------------------------------
-- rolls
--------------------------------------------------------------------------------
-- luck: 0 base, 1 takedown, 2.5+ boss (see Config.RarityWeights); mastery stars add to it. BOOSTS (2026-10-14,
-- Boosts.luau - the one source of truth): the LUCK BOOST product's additive luck, and the luck MULTIPLIER (2x LUCK
-- events, friends, team luck, ... - Config.LuckBoosted). Without that module: the LUCK BOOST alone, as before.
local boostsMod: any = nil
local function boosts(): any
	if boostsMod == nil then
		local m = script.Parent:FindFirstChild("Boosts")
		local ok, res = pcall(function() return m and require(m :: ModuleScript) end)
		boostsMod = (ok and res) or false
	end
	return boostsMod or nil
end
local function boostLuck(profile): (number?, number)
	local B = boosts()
	if B then
		local ok, add, mult = pcall(B.LuckFor, profile)
		if ok and typeof(add) == "number" and typeof(mult) == "number" and mult == mult and mult >= 1 and mult < 1000 then return add, mult end
	end
	return nil, 1
end
local function luckOf(profile, luck: number): (number, number)
	local add, mult = boostLuck(profile)
	if add == nil then add = (profile.LuckUntil or 0) > os.time() and 1.5 or 0 end
	return luck + (profile.Stars or 0) * Config.StarPerk.Luck + (add :: number), mult
end
local function pickRarity(total: number, forcing: boolean, mult: number?): string
	local w = Config.LuckBoosted(Config.RarityWeights(total), mult)
	local sum = 0
	for _, r in ipairs(Config.RarityOrder) do
		if not forcing or Config.Rarity[r].Order >= 4 then sum += w[r] end
	end
	local pick = rng:NextNumber() * sum
	local result = "Common"
	for _, r in ipairs(Config.RarityOrder) do
		if not forcing or Config.Rarity[r].Order >= 4 then
			pick -= w[r]
			if pick <= 0 then result = r break end
		end
	end
	return result
end

-- an egg that's SHOWN before anyone owns it (a nest egg, a boss egg): rolled with the best luck among the players
-- it's for. Pity never forces a shown egg (one friend due their pity would have turned every nest egg EPIC for the
-- whole group): it applies to the egg YOU pick up (Dinos.PityFloor), and only then is it counted (Dinos.NotePity)
function Dinos.PeekRarity(profiles: { any }, luck: number): string
	local best, mult = luck, nil
	for _, profile in ipairs(profiles) do
		local l, m = luckOf(profile, luck)
		best = math.max(best, l)
		mult = math.max(mult or 1, m)
	end
	-- (nobody's: the server-wide boosts still count - a 2x LUCK event lifts every nest)
	if mult == nil then mult = select(2, boostLuck(nil)) end
	return pickRarity(best, false, mult)
end
-- the egg you just picked up, if your pity is due: at least EPIC
function Dinos.PityFloor(profile, rarity: string): string
	local r = Config.Rarity[rarity]
	if (profile.Pity or 0) >= Config.Pity - 1 and (not r or r.Order < 4) then return Config.RarityOrder[4] end
	return rarity
end
function Dinos.NotePity(profile, rarity: string?)
	local r = rarity and Config.Rarity[rarity]
	if not r then return end
	if r.Order >= 4 then profile.Pity = 0 else profile.Pity = (profile.Pity or 0) + 1 end
end

function Dinos.RollRarity(profile, luck: number): string
	local total, mult = luckOf(profile, luck)
	-- hidden pity: force EPIC+ once the counter is due
	local forcing = (profile.Pity or 0) >= Config.Pity - 1
	local result = pickRarity(total, forcing, mult)
	if Config.Rarity[result].Order >= 4 then profile.Pity = 0 else profile.Pity = (profile.Pity or 0) + 1 end
	return result
end

function Dinos.RollKG(species: string, heavy: number?): number
	local sp = Config.Species[species]
	if not sp then return 10 end
	-- skewed toward light: most dinos are small, a heavy one is a flex (boss eggs roll heavier)
	local t = rng:NextNumber() ^ (2.2 / (heavy or 1))
	if rng:NextNumber() < 0.03 then t = 0.85 + rng:NextNumber() * 0.15 end -- the occasional chonk
	return math.floor(sp.KG[1] + (sp.KG[2] - sp.KG[1]) * t + 0.5)
end

--------------------------------------------------------------------------------
-- eggs
--------------------------------------------------------------------------------
-- returns the egg (or nil when the egg bag is full)
function Dinos.AddEgg(player: Player, species: string, rarity: string?, luck: number?, kg: number?, paid: boolean?)
	local profile = Data.Peek(player)
	if not profile then return nil end
	if #profile.Eggs >= Config.Inventory.MaxEggs and not paid then -- (a bought egg always fits: Robux never vanishes)
		Net.Fire(player, "Toast", { Text = "EGG BAG FULL! HATCH SOME FIRST", Color = "Red" })
		return nil
	end
	local egg = { Id = Data.NewId(), Species = species, Rarity = rarity or Dinos.RollRarity(profile, luck or 0), KG = kg or Dinos.RollKG(species) }
	table.insert(profile.Eggs, egg)
	profile.Stats.Eggs += 1
	return egg
end

local function incubatorAt(profile, slot: number)
	for i, inc in ipairs(profile.Incubators) do if inc.Slot == slot then return inc, i end end
	return nil, nil
end

-- put an egg from your bag into an incubator (slot nil = first free one)
local function clearHeld(player: Player)
	player:SetAttribute("HeldEgg", nil)
	player:SetAttribute("HeldDino", nil)
	local char = player.Character
	local old = char and char:FindFirstChild("HeldEggModel")
	if old then old:Destroy() end
end

-- a nest / companion slot from a client: a whole number or nothing (2026-10-12: 1.001, 1.002... each passed
-- the range check - unlimited incubators - and 1.5 wrote a non-array key into a saved list)
local function wholeSlot(n: any): number?
	if typeof(n) ~= "number" or n ~= n or n % 1 ~= 0 then return nil end
	return n
end
Dinos.WholeSlot = wholeSlot

function Dinos.Incubate(player: Player, eggId: string, slot: number?)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	if slot ~= nil and not wholeSlot(slot) then return { Ok = false } end
	local egg, idx = find(profile.Eggs, eggId)
	if not egg then return { Ok = false, Err = "NO SUCH EGG" } end
	if not slot then
		for s = 1, profile.IncubatorCount do
			if not incubatorAt(profile, s) then slot = s break end
		end
	end
	if not slot or slot < 1 or slot > profile.IncubatorCount then return { Ok = false, Err = "ALL INCUBATORS ARE BUSY" } end
	if incubatorAt(profile, slot) then return { Ok = false, Err = "THAT INCUBATOR IS BUSY" } end
	table.remove(profile.Eggs, idx)
	if player:GetAttribute("HeldEgg") == eggId then clearHeld(player) end
	local first = (profile.Stats.Hatched or 0) == 0 and #profile.Incubators == 0
	-- (a bigger hatchery hatches faster: Config.Island.Hatchery[tier].Speed; the very first egg stays quick)
	local duration = first and Config.FirstEggHatch or math.ceil(Config.Rarity[egg.Rarity].Hatch * Config.HatchSpeed(profile))
	if (profile.InstantHatches or 0) > 0 then duration = 0 profile.InstantHatches -= 1 end
	-- (Dev: a Test Tools / admin egg - its hatch is never announced to the server, see announceHatch)
	table.insert(profile.Incubators, { Slot = slot, EggId = egg.Id, Species = egg.Species, Rarity = egg.Rarity, KG = egg.KG, Start = os.time(), Duration = duration, Dev = egg.Dev or nil })
	Plots.Sync(player)
	Data.Changed(player)
	return { Ok = true, Slot = slot }
end

-- fill every free incubator from your bag, rarest eggs first
function Dinos.AutoIncubate(player: Player)
	local profile = Data.Peek(player)
	if not profile then return 0 end
	table.sort(profile.Eggs, function(a, b) return Config.Rarity[a.Rarity].Order > Config.Rarity[b.Rarity].Order end)
	local n = 0
	for s = 1, profile.IncubatorCount do
		if #profile.Eggs == 0 then break end
		if not incubatorAt(profile, s) then
			local res = Dinos.Incubate(player, profile.Eggs[1].Id, s)
			if res.Ok then n += 1 end
		end
	end
	return n
end

--------------------------------------------------------------------------------
-- hatching
--------------------------------------------------------------------------------
-- RARE HATCH ANNOUNCEMENTS (2026-10-14): an EPIC or better hatch is news for the whole server - a banner slides
-- in at the top of every screen (client RareHatch.luau: small for EPIC, big for LEGENDARY, extra for SECRET).
-- Test Tools / admin eggs stay quiet on live servers (Studio announces them, so the banner can be checked solo).
-- One EPIC per player per 20 s: a full hatchery of pity EPICs would otherwise be a wall of banners.
local lastEpic = {} :: { [number]: number }
Players.PlayerRemoving:Connect(function(plr) lastEpic[plr.UserId] = nil end)
local function announceHatch(player: Player, dino, dev: boolean)
	local r = Config.Rarity[dino.Rarity]
	local sp = Config.Species[dino.Species]
	if not (r and sp) or r.Order < 4 then return end
	if dev and not RunService:IsStudio() then return end
	if r.Order == 4 then
		local now = os.clock()
		if now - (lastEpic[player.UserId] or -math.huge) < 20 then return end
		lastEpic[player.UserId] = now
	end
	-- a heavy one is a flex: the top fifth of its species' KG range gets its weight on the banner
	local kg = tonumber(dino.KG) or 0
	local span = sp.KG and (sp.KG[2] - sp.KG[1]) or 0
	local heavy = span > 0 and (kg - sp.KG[1]) / span >= 0.8
	Net.FireAll("RareHatch", { UserId = player.UserId, Name = player.DisplayName, Species = dino.Species, Rarity = dino.Rarity, KG = kg, Heavy = heavy or nil, T = Workspace:GetServerTimeNow() })
end

function Dinos.Hatch(player: Player, slot: number)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	if not wholeSlot(slot) then return { Ok = false } end
	local inc, idx = incubatorAt(profile, slot)
	if not inc then return { Ok = false, Err = "EMPTY INCUBATOR" } end
	if os.time() < inc.Start + inc.Duration then return { Ok = false, Err = "NOT READY YET" } end
	if #profile.Dinos >= Config.Inventory.MaxDinos then return { Ok = false, Err = "DINO BAG FULL - SELL SOME" } end
	table.remove(profile.Incubators, idx)
	local dino = { Id = Data.NewId(), Species = inc.Species, Rarity = inc.Rarity, KG = inc.KG or Dinos.RollKG(inc.Species), Hatched = os.time() }
	table.insert(profile.Dinos, dino)
	profile.Stats.Hatched = (profile.Stats.Hatched or 0) + 1
	local key = dino.Species .. ":" .. dino.Rarity
	local newEntry = not profile.Index[key]
	profile.Index[key] = true
	-- the Index pays: coins per new entry right away; its milestones (coins + a permanent income bonus) are claimed
	-- in the Index's REWARDS tab now (IndexDefs "Entries", 2026-10-14) - the hatch just says one is ready
	local indexCoins, readyBefore, readyNow = 0, 0, 0
	if newEntry then
		local sp = Config.Species[dino.Species]
		local eraTier = sp and Config.EraTier(sp.Era) or 1
		local ord = Config.Rarity[dino.Rarity].Order
		indexCoins = Config.IndexEntryCoins * ord * ord * eraTier
		profile.Coins += indexCoins
		profile.Earned += indexCoins
		profile.Index[key] = nil
		readyBefore = IndexDefs.ClaimableCount(profile)
		profile.Index[key] = true
		readyNow = IndexDefs.ClaimableCount(profile)
	end
	-- straight into the yard if there's room (a sea star: straight into the sea pen, never the yard)
	local placed = false
	local seaPen = Dinos.IsMarine(dino.Species) and Dinos.SeaHome(profile, player, dino.Id) or false
	if Dinos.IsMarine(dino.Species) then
		-- (in the sea pen, or - one's already there - waiting in your bag)
	elseif #profile.Placed < profile.PenSlots then
		table.insert(profile.Placed, dino.Id)
		placed = true
	end
	if Quests then Quests.Progress(player, "Hatch", { Count = 1 }) Quests.Progress(player, "Rarity", { Rarity = dino.Rarity, Count = 1 }) end
	-- where it goes next (automatic, 2026-10-12): a free companion slot -> it stays at your side as a companion;
	-- else the yard (it walks off to the paddock); yard full -> it's pinned to your hotbar (held in your arms later)
	local autoBuddy = false
	if #profile.Buddies < (profile.Gear.BuddySlots or 1) and placed and dino.Species ~= "Mosasaurus" then
		table.insert(profile.Buddies, dino.Id)
		autoBuddy = true
	end
	local pinned = nil
	if not placed and not Dinos.IsMarine(dino.Species) then pinned = require(script.Parent.Hotbar).AutoPin(profile, dino.Id) end
	Plots.Sync(player)
	Data.Changed(player)
	-- the plaza's Hatch Stage shows the server's latest hatch
	local stage = Workspace:FindFirstChild("BaseCamp") and Workspace.BaseCamp:FindFirstChild("HatchStage", true)
	if stage then
		stage:SetAttribute("Species", dino.Species)
		stage:SetAttribute("Rarity", dino.Rarity)
		stage:SetAttribute("Owner", player.DisplayName)
		stage:SetAttribute("At", os.time())
	end
	announceHatch(player, dino, inc.Dev == true)
	return { Ok = true, Dino = dino, Slot = slot, NewEntry = newEntry, Placed = placed, SeaPen = seaPen or nil, Income = Config.DinoIncome(dino), Buddy = autoBuddy, Pinned = pinned, IndexCoins = indexCoins, RewardReady = readyNow > readyBefore or nil }
end

--------------------------------------------------------------------------------
-- yard, buddies, selling
--------------------------------------------------------------------------------
function Dinos.Place(player: Player, id: string)
	local profile = Data.Peek(player)
	if not profile or not find(profile.Dinos, id) then return { Ok = false } end
	if has(profile.Placed, id) then return { Ok = true } end
	local d0 = find(profile.Dinos, id)
	if d0 and Dinos.IsMarine(d0.Species) then
		-- (a sea star swims to the sea pen instead)
		local ok = Dinos.SeaHome(profile, player, id)
		if ok then Plots.Sync(player) Data.Changed(player) end
		return ok and { Ok = true, SeaPen = true } or { Ok = false, Err = "YOUR SEA PEN ALREADY HAS ONE" }
	end
	if #profile.Placed >= profile.PenSlots then return { Ok = false, Err = "YARD IS FULL - BUILD MORE ROOM AT THE BENCH IN YOUR PEN" } end
	Dinos.LeavePen(profile, id)
	table.insert(profile.Placed, id)
	Plots.Sync(player)
	Data.Changed(player)
	return { Ok = true }
end

function Dinos.Store(player: Player, id: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local i = has(profile.Placed, id)
	if i then table.remove(profile.Placed, i) end
	local b = has(profile.Buddies, id)
	if b then table.remove(profile.Buddies, b) end
	Dinos.LeavePen(profile, id)
	Plots.Sync(player)
	Data.Changed(player)
	return { Ok = true }
end

-- STAR PENS (Config.Island.Pens): a boss-species dino can live in its own pen on your island. It earns like a yard
-- dino without taking a yard slot, and every filled pen adds Config.Island.PenIncome to your island's income.
function Dinos.PenOf(profile, id: string): string?
	for lot, pen in pairs(profile.Island and profile.Island.Pens or {}) do
		if typeof(pen) == "table" and pen.Dino == id then return lot end
	end
	return nil
end
-- an empty pen stays built (its star moved out, was sold or lost)
function Dinos.LeavePen(profile, id: string)
	local lot = Dinos.PenOf(profile, id)
	if lot then profile.Island.Pens[lot].Dino = "" end
end
-- into a pen: out of the yard and your companions (Shop's IslandBuild sets the pen's Dino)
function Dinos.MoveToPen(profile, player: Player, id: string)
	local i = has(profile.Placed, id)
	if i then table.remove(profile.Placed, i) end
	local b = has(profile.Buddies, id)
	if b then table.remove(profile.Buddies, b) end
	Dinos.LeavePen(profile, id)
	if player:GetAttribute("HeldDino") == id then clearHeld(player) end
end
-- SEA STARS (2026-10-13, user: "we have marine animals on a terrestrial plot - make a star pen automatically a
-- marine plot"): a sea species (Config.PenLotKind = "Sea", the Mosasaurus) never lives on land. The island's sea lot
-- builds itself for free the moment you own one and it swims straight in; a second one waits in your bag (one sea
-- pen per island). Yard and companions never take one.
function Dinos.IsMarine(species: string?): boolean
	return species ~= nil and Config.PenLotKind(species) == "Sea"
end
local function seaLot(): string?
	for _, lot in ipairs(Config.Island.LotOrder or {}) do if Config.Island.Lots[lot] == "Sea" then return lot end end
	for lot, kind in pairs(Config.Island.Lots) do if kind == "Sea" then return lot end end
	return nil
end
-- into the sea pen if it's free (builds it). true = it's in there now
function Dinos.SeaHome(profile, player: Player?, id: string): boolean
	local d = find(profile.Dinos, id)
	local lot = seaLot()
	if not (d and lot and Dinos.IsMarine(d.Species)) then return false end
	profile.Island = profile.Island or { Hatchery = 1, Garage = 1, Pens = {} }
	profile.Island.Pens = profile.Island.Pens or {}
	local pen = profile.Island.Pens[lot]
	if typeof(pen) == "table" and pen.Dino == id then return true end
	if typeof(pen) == "table" and (pen.Dino or "") ~= "" and find(profile.Dinos, pen.Dino) then return false end
	if player then Dinos.MoveToPen(profile, player, id) else
		local i = has(profile.Placed, id)
		if i then table.remove(profile.Placed, i) end
		local b = has(profile.Buddies, id)
		if b then table.remove(profile.Buddies, b) end
	end
	profile.Island.Pens[lot] = { Species = d.Species, Dino = id }
	return true
end
-- every sea star off the land (old saves had them in the yard): the best one into the sea pen, the rest to the bag
function Dinos.SettleMarine(profile, player: Player?)
	local marine = {}
	for _, d in ipairs(profile.Dinos or {}) do
		if Dinos.IsMarine(d.Species) then
			local i = has(profile.Placed, d.Id)
			if i then table.remove(profile.Placed, i) end
			local b = has(profile.Buddies, d.Id)
			if b then table.remove(profile.Buddies, b) end
			table.insert(marine, d)
		end
	end
	table.sort(marine, function(a, b) return Config.DinoIncome(a) > Config.DinoIncome(b) end)
	for _, d in ipairs(marine) do if Dinos.SeaHome(profile, player, d.Id) then break end end
end

function Dinos.PenList(profile): { [string]: any }
	local out = {}
	for lot, pen in pairs(profile.Island and profile.Island.Pens or {}) do
		if typeof(pen) == "table" then
			local d = (pen.Dino or "") ~= "" and find(profile.Dinos, pen.Dino) or nil
			out[lot] = { Species = pen.Species, Dino = d }
		end
	end
	return out
end

function Dinos.SetBuddy(player: Player, id: string, on: boolean)
	if on then return Dinos.EquipCompanion(player, id) end
	return Dinos.UnequipCompanion(player, id)
end

-- companions (Buddies): yard dinos that follow you round camp, ride along on expeditions and fight beside you.
-- Gear.BuddySlots of them (1 to start; crafted or bought). Equip into a slot (slot nil = the first free one; a taken
-- slot is swapped); unequip and it just stays in the pen.
function Dinos.EquipCompanion(player: Player, id: string, slot: number?)
	slot = slot and wholeSlot(slot) or nil
	local profile = Data.Peek(player)
	local d = profile and find(profile.Dinos, id)
	if not d then return { Ok = false, Err = "THAT DINO IS GONE" } end
	if d.Species == "Mosasaurus" then return { Ok = false, Err = "IT CAN'T LEAVE THE WATER!" } end
	if Dinos.PenOf(profile, id) then return { Ok = false, Err = "IT LIVES IN ITS STAR PEN" } end
	local slots = profile.Gear.BuddySlots or 1
	-- every slot taken and none picked to swap: say so before anything moves (it used to slip into the yard anyway)
	if not has(profile.Buddies, id) and #profile.Buddies >= slots and not (slot and slot >= 1 and slot <= slots) then
		return { Ok = false, Err = "ALL COMPANION SLOTS ARE FULL - UNEQUIP ONE" }
	end
	if not has(profile.Placed, id) then
		-- a companion lives in your paddock: put it there if there's room
		if #profile.Placed >= profile.PenSlots then return { Ok = false, Err = "YOUR PADDOCK IS FULL" } end
		table.insert(profile.Placed, id)
	end
	local i = has(profile.Buddies, id)
	if i then table.remove(profile.Buddies, i) end
	if slot and slot >= 1 and slot <= slots then
		if slot <= #profile.Buddies then profile.Buddies[slot] = id else table.insert(profile.Buddies, id) end
	elseif #profile.Buddies < slots then
		table.insert(profile.Buddies, id)
	else
		if i then table.insert(profile.Buddies, i, id) end
		return { Ok = false, Err = "ALL COMPANION SLOTS ARE FULL - UNEQUIP ONE" }
	end
	while #profile.Buddies > slots do table.remove(profile.Buddies) end
	Plots.Sync(player)
	Data.Changed(player)
	return { Ok = true, Species = d.Species }
end

function Dinos.UnequipCompanion(player: Player, id: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local i = has(profile.Buddies, id)
	if i then table.remove(profile.Buddies, i) end
	Plots.Sync(player)
	Data.Changed(player)
	return { Ok = true }
end

-- a hurt companion (it bled out on a run) rests at home; pay to patch it up now instead of waiting
function Dinos.Heal(player: Player, id: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local d = find(profile.Dinos, id)
	if not d then return { Ok = false, Err = "NO SUCH DINO" } end
	local left = Config.Hurt(d, os.time())
	if left <= 0 then d.HurtUntil = nil return { Ok = true } end
	local price = Config.HealPrice(d, left)
	if (profile.Coins or 0) < price then return { Ok = false, Err = "NOT ENOUGH COINS" } end
	profile.Coins -= price
	d.HurtUntil = nil
	Data.Changed(player)
	return { Ok = true, Price = price }
end

-- place your highest-earning dinos, and make your strongest your buddies
function Dinos.EquipBest(player: Player)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	-- (stars living in their star pens stay there: they already earn, and a dino can't be in two places)
	Dinos.SettleMarine(profile, player)
	local list = {}
	for _, d in ipairs(profile.Dinos) do if not Dinos.PenOf(profile, d.Id) and not Dinos.IsMarine(d.Species) then table.insert(list, d) end end
	table.sort(list, function(a, b) return Config.DinoIncome(a) > Config.DinoIncome(b) end)
	table.clear(profile.Placed)
	for i = 1, math.min(profile.PenSlots, #list) do table.insert(profile.Placed, list[i].Id) end
	-- companions: the strongest of the dinos now in the yard (not the water-bound)
	local yard = {}
	local now = os.time()
	for _, d in ipairs(list) do
		if has(profile.Placed, d.Id) and d.Species ~= "Mosasaurus" and not ((d.HurtUntil or 0) > now) then table.insert(yard, d) end
	end
	table.sort(yard, function(a, b) return Config.BuddyPower(a) > Config.BuddyPower(b) end)
	table.clear(profile.Buddies)
	for i = 1, math.min(profile.Gear.BuddySlots or 1, #yard) do table.insert(profile.Buddies, yard[i].Id) end
	Plots.Sync(player)
	Data.Changed(player)
	return { Ok = true }
end

function Dinos.Sell(player: Player, ids: { string })
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local total, n = 0, 0
	for _, id in ipairs(ids) do
		if typeof(id) ~= "string" then continue end
		local d, idx = find(profile.Dinos, id)
		if d then
			total += Config.SellValue(d)
			table.remove(profile.Dinos, idx)
			local p = has(profile.Placed, id)
			if p then table.remove(profile.Placed, p) end
			local b = has(profile.Buddies, id)
			if b then table.remove(profile.Buddies, b) end
			Dinos.LeavePen(profile, id)
			if player:GetAttribute("HeldDino") == id then clearHeld(player) end
			if profile.Bond then profile.Bond[id] = nil end
			local pin = profile.HotbarPins and table.find(profile.HotbarPins, id)
			if pin then profile.HotbarPins[pin] = "" end
			n += 1
		end
	end
	if n == 0 then return { Ok = false, Err = "NOTHING SOLD" } end
	profile.Coins += total
	profile.Earned += total
	Plots.Sync(player)
	Data.Changed(player)
	return { Ok = true, Coins = total, Count = n }
end

-- bond: companions that came along gain xp; a new level teaches them something (Config.BondPerk)
function Dinos.BondLevel(profile, id: string): number
	return Config.BondLevel((profile.Bond or {})[id])
end
function Dinos.AddBond(player: Player, ids: { string }, amount: number)
	local profile = Data.Peek(player)
	if not profile or amount <= 0 then return end
	profile.Bond = profile.Bond or {}
	for _, id in ipairs(ids) do
		local d = find(profile.Dinos, id)
		if not d then continue end
		local before = Config.BondLevel(profile.Bond[id])
		profile.Bond[id] = (profile.Bond[id] or 0) + amount
		local after = Config.BondLevel(profile.Bond[id])
		if after > before then
			local perk = Config.BondPerk(d.Species, after)
			Net.Fire(player, "BondUp", { Name = string.upper((Config.Species[d.Species] or { Name = d.Species }).Name), Level = after, Perk = perk, Species = d.Species })
		end
	end
	Data.Changed(player)
end

-- toy balls: take them from the crate at home, throw them anywhere; a fetched one comes back into your pocket
function Dinos.TakeBall(player: Player)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	if (profile.Balls or 0) >= Config.Balls.Max then return { Ok = true, Balls = profile.Balls } end
	profile.Balls = (profile.Balls or 0) + 1
	Data.Changed(player)
	return { Ok = true, Balls = profile.Balls }
end
function Dinos.UseBall(player: Player): boolean
	local profile = Data.Peek(player)
	if not profile or (profile.Balls or 0) <= 0 then return false end
	profile.Balls -= 1
	Data.Changed(player)
	return true
end

-- buddies that fell on a run where you fainted too: gone for good (out of your dinos, yard, buddies and companion
-- slot). Returns their names for the message.
function Dinos.LoseDinos(player: Player, fallen: { [string]: any }): { string }
	local profile = Data.Peek(player)
	local names = {}
	if not profile then return names end
	for id, d in pairs(fallen) do
		local _, idx = find(profile.Dinos, id)
		if idx then
			table.remove(profile.Dinos, idx)
			local p = has(profile.Placed, id)
			if p then table.remove(profile.Placed, p) end
			local b = has(profile.Buddies, id)
			if b then table.remove(profile.Buddies, b) end
			if profile.Bond then profile.Bond[id] = nil end
			Dinos.LeavePen(profile, id)
			table.insert(names, string.upper((Config.Species[d.Species] or { Name = d.Species }).Name))
		end
	end
	Plots.Sync(player)
	Data.Changed(player)
	return names
end

-- drop an egg on the ground (it's gone; kept simple and safe from duping)
function Dinos.DropEgg(player: Player, id: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local egg, idx = find(profile.Eggs, id)
	if not egg then return { Ok = false } end
	table.remove(profile.Eggs, idx)
	Data.Changed(player)
	return { Ok = true, Egg = egg }
end

-- TRADING (2026-10-14, Trade.luau): can this dino / egg be traded right now? nil = yes, else why not (player-facing).
-- A yard dino is fine (it walks out of your yard). Your companion and a star in its pen aren't; an egg in a nest or on
-- your rover's rack isn't in your bag at all.
function Dinos.TradeBlock(profile, kind: string, id: string): string?
	if not profile then return "STILL LOADING" end
	if kind == "Dino" then
		if not find(profile.Dinos, id) then return "THAT DINO IS GONE" end
		if has(profile.Buddies, id) then return "IT'S YOUR COMPANION - UNEQUIP IT FIRST" end
		if Dinos.PenOf(profile, id) then return "IT LIVES IN ITS STAR PEN" end
		return nil
	elseif kind == "Egg" then
		if not find(profile.Eggs, id) then return "THAT EGG ISN'T IN YOUR BAG" end
		return nil
	end
	return "ONLY DINOS AND EGGS CAN BE TRADED"
end

--------------------------------------------------------------------------------
-- income
--------------------------------------------------------------------------------
-- raw: without timed coin boosts (Boosts.CoinMult) - what a save keeps for offline money (2026-10-14)
function Dinos.Rate(profile, player: Player?, offline: boolean?, raw: boolean?): number
	-- (offline: each dino pays its income once every 1-10 minutes instead of every second - Config.OfflineEvery)
	local function earn(d): number
		return offline and Config.DinoIncome(d) / Config.OfflineEvery(d) or Config.DinoIncome(d)
	end
	local r = 0
	for _, id in ipairs(profile.Placed) do
		local d = find(profile.Dinos, id)
		if d then r += earn(d) end
	end
	-- stars in their pens earn too (they're not in Placed), and every filled pen lifts the whole island
	for _, pen in pairs(profile.Island and profile.Island.Pens or {}) do
		if typeof(pen) == "table" and (pen.Dino or "") ~= "" and not has(profile.Placed, pen.Dino) then
			local d = find(profile.Dinos, pen.Dino)
			if d then r += earn(d) end
		end
	end
	r *= 1 + Config.StarPensFilled(profile) * Config.Island.PenIncome
	r *= 1 + (profile.Stars or 0) * Config.StarPerk.Income
	-- (the Index's claimed INCOME rewards: IndexDefs "Entries")
	local _, _, indexIncome = IndexDefs.Bonus(profile)
	r *= 1 + indexIncome
	if player and player:GetAttribute("Pass_DoubleMoney") then r *= 2 end
	-- live income only: a coin boost never reaches offline money (Boosts.luau)
	if player and not offline and not raw then
		local B = boosts()
		local ok, m = false, nil
		if B then ok, m = pcall(B.CoinMult, player) end
		if ok and typeof(m) == "number" and m > 1 and m < 100 then r *= m end
	end
	return r
end

function Dinos.PlacedList(profile): { any }
	local out = {}
	for _, id in ipairs(profile.Placed) do
		local d = find(profile.Dinos, id)
		if d then table.insert(out, d) end
	end
	return out
end

function Dinos.BuddyList(profile): { any }
	local out = {}
	-- the companions that are fit to come along (a hurt one rests at home until it's better or healed)
	local now = os.time()
	for _, id in ipairs(profile.Buddies) do
		local d = find(profile.Dinos, id)
		if d and Config.Hurt(d, now) <= 0 then table.insert(out, d) end
	end
	return out
end

--------------------------------------------------------------------------------
-- holding an egg: picked from the hotbar, it sits in your hands (everyone sees it) until you set it in a nest
--------------------------------------------------------------------------------
-- an egg in your arms (everyone sees it): used for carrying eggs at camp and at encounter sites
function Dinos.ShowHeld(player: Player, egg)
	local char = player.Character
	local old = char and char:FindFirstChild("HeldEggModel")
	if old then old:Destroy() end
	local arm = char and (char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")) :: BasePart?
	local t = ReplicatedStorage.DinoExpedition.Eggs:FindFirstChild(egg.Species .. "Egg")
	if not (char and arm and t) then return end
	local m = t:Clone() :: Model
	m.Name = "HeldEggModel"
	m:SetAttribute("Rarity", egg.Rarity)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false d.CanCollide = false d.CanQuery = false d.CanTouch = false d.Massless = true end
	end
	m:ScaleTo(0.62 * Config.EggScale(egg.Species, egg.KG))
	local size = m:GetExtentsSize()
	m:SetAttribute("HoldSize", size)
	-- carried in front of the chest, both arms around it: a real Weld, so every client's PlayerAnim can move the
	-- egg with the arms (the lift out of a nest, the step bounce) by setting C0
	local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or arm) :: BasePart
	local primary = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
	local spot = CFrame.new(Config.CarrySpot(size, torso.Size))
	m:PivotTo(torso.CFrame * spot)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = primary, d
			w.Parent = d
		end
	end
	local w = Instance.new("Weld")
	w.Name = "HoldWeld"
	w.Part0, w.Part1 = torso, primary
	w.C0 = spot
	w.Parent = primary
	m.Parent = char
end

-- a dino in your arms (from the hotbar / bag), like an egg: cradled sideways across your chest, scaled so a small
-- one is pet-sized and a giant one is a big armful (everyone sees it; PlayerAnim hugs it and places it)
local DinoT = ReplicatedStorage.DinoExpedition:WaitForChild("Dinosaurs")
function Dinos.ShowHeldDino(player: Player, d)
	local char = player.Character
	local old = char and char:FindFirstChild("HeldEggModel")
	if old then old:Destroy() end
	local t = DinoT:FindFirstChild(d.Species)
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not (char and t and torso) then return end
	local m = t:Clone() :: Model
	m.Name = "HeldEggModel"
	m:SetAttribute("HeldDino", d.Id)
	m:SetAttribute("Species", d.Species)
	m:SetAttribute("Rarity", d.Rarity)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = false p.CanCollide = false p.CanQuery = false p.CanTouch = false p.Massless = true end
	end
	local full = m:GetExtentsSize()
	local long = math.max(full.X, full.Z, full.Y)
	local want = 2.2 + 2.4 * math.clamp((long - 8) / 32, 0, 1)
	local k = want / long
	m:ScaleTo(k)
	m:SetAttribute("AnimScale", k)
	-- lying across your arms: turned side-on
	local rot = CFrame.Angles(0, math.pi / 2, 0)
	local cf, size = m:GetBoundingBox()
	local s = rot:VectorToWorldSpace(size)
	local held = Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z))
	m:SetAttribute("HoldSize", held)
	m:SetAttribute("HoldRot", math.pi / 2)
	local primary = m.PrimaryPart :: BasePart
	-- the weld aims the box's middle at the carry spot (the root isn't the middle of a dino)
	local off = primary.CFrame:ToObjectSpace(cf)
	local spot = CFrame.new(Config.CarrySpot(held, torso.Size)) * rot * off:Inverse()
	m:SetAttribute("HoldOff", off.Position)
	m:PivotTo(torso.CFrame * spot)
	local w = Instance.new("Weld")
	w.Name = "HoldWeld"
	w.Part0, w.Part1 = torso, primary
	w.C0 = spot
	w.Parent = primary
	m.Parent = char
end

function Dinos.HoldDino(player: Player, id: string?)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	clearHeld(player)
	if not id or id == "" then return { Ok = true } end
	if player:GetAttribute("Site") then return { Ok = false, Err = "NOT HERE!" } end
	local d = find(profile.Dinos, id)
	if not d then return { Ok = false, Err = "THAT DINO IS GONE" } end
	if d.Species == "Mosasaurus" then return { Ok = false, Err = "IT NEEDS THE WATER!" } end
	if Dinos.PenOf(profile, id) then return { Ok = false, Err = "IT LIVES IN ITS STAR PEN" } end
	player:SetAttribute("HeldDino", id)
	Dinos.ShowHeldDino(player, d)
	return { Ok = true }
end

function Dinos.ClearHeld(player: Player)
	local char = player.Character
	local old = char and char:FindFirstChild("HeldEggModel")
	if old then old:Destroy() end
	-- (the attributes too: after a run the model was gone but HeldEgg stayed set - slow walk, no sprint, PUT AWAY
	-- showing, "WALK TO A NEST" with empty arms)
	player:SetAttribute("HeldEgg", nil)
	player:SetAttribute("HeldDino", nil)
end

function Dinos.Hold(player: Player, id: string?)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	clearHeld(player)
	if not id or id == "" then return { Ok = true } end
	local egg = find(profile.Eggs, id)
	if not egg then return { Ok = false, Err = "THAT EGG IS GONE" } end
	player:SetAttribute("HeldEgg", id)
	Dinos.ShowHeld(player, egg)
	return { Ok = true }
end

-- eggs on the rack: tap one (index = its rack slot) to take it off and carry it to a nest. Anywhere in camp now, by
-- your parked rover (2026-10-13: it used to be home-only, the first egg only, and nothing on screen ever asked)
function Dinos.Unload(player: Player, index: number?)
	local profile = Data.Peek(player)
	if not profile or #(profile.RoverEggs or {}) == 0 then return { Ok = false, Err = "NO EGGS ON YOUR ROVER" } end
	local Vehicles = require(script.Parent.Vehicles)
	local root = Vehicles.Root(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hrp) then return { Ok = false } end
	if hum and hum.SeatPart then return { Ok = false, Err = "HOP OUT FIRST" } end
	if (hrp.Position - root.Position).Magnitude > 18 then return { Ok = false, Err = "GET CLOSER TO YOUR ROVER" } end
	if player:GetAttribute("HeldEgg") then return { Ok = false, Err = "HANDS FULL - PUT THAT ONE IN A NEST" } end
	local i = wholeSlot(index or 1) or 1
	if i < 1 or i > #profile.RoverEggs then return { Ok = false, Err = "THAT EGG IS GONE" } end
	local e = table.remove(profile.RoverEggs, i)
	local egg = Dinos.AddEgg(player, e.Species, e.Rarity, nil, e.KG)
	if not egg then table.insert(profile.RoverEggs, i, e) return { Ok = false, Err = "EGG BAG FULL" } end
	profile.Stats.Eggs -= 1 -- counted when it came home
	Dinos.Hold(player, egg.Id)
	Vehicles.ShowRack(player)
	Data.Changed(player)
	return { Ok = true, Egg = egg, Left = #profile.RoverEggs }
end

-- unload every egg straight into your bag (from the bag window)
function Dinos.UnloadAll(player: Player)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local n = 0
	while #(profile.RoverEggs or {}) > 0 do
		local e = profile.RoverEggs[1]
		local egg = Dinos.AddEgg(player, e.Species, e.Rarity, nil, e.KG)
		if not egg then break end
		profile.Stats.Eggs -= 1
		table.remove(profile.RoverEggs, 1)
		n += 1
	end
	require(script.Parent.Vehicles).ShowRack(player)
	Data.Changed(player)
	return { Ok = n > 0, Count = n }
end

--------------------------------------------------------------------------------
function Dinos.Start(deps)
	Data, Net, Plots, Quests = deps.Data, deps.Net, deps.Plots, deps.Quests
	-- TRADING (2026-10-14): while a trade window is open (attribute Trading, set by Trade.luau) nothing in your bag
	-- changes: no hatch / incubate / sell / drop / place / equip / unload. (Unequip and store stay open: that's how you
	-- free a companion to trade it.)
	local function locked(name: string, fn)
		Net.On(name, function(player, args)
			if player:GetAttribute("Trading") then return { Ok = false, Err = "FINISH YOUR TRADE FIRST" } end
			return fn(player, args)
		end)
	end
	locked("Incubate", function(player, args)
		if typeof(args.Id) ~= "string" then return { Ok = false } end
		return Dinos.Incubate(player, args.Id, tonumber(args.Slot))
	end)
	locked("AutoIncubate", function(player)
		local n = Dinos.AutoIncubate(player)
		return { Ok = n > 0, Count = n, Err = n == 0 and "NO FREE INCUBATOR OR NO EGGS" or nil }
	end)
	locked("Hatch", function(player, args) return Dinos.Hatch(player, tonumber(args.Slot) or 0) end)
	locked("PlaceDino", function(player, args) return typeof(args.Id) == "string" and Dinos.Place(player, args.Id) or { Ok = false } end)
	Net.On("StoreDino", function(player, args) return typeof(args.Id) == "string" and Dinos.Store(player, args.Id) or { Ok = false } end)
	Net.On("TakeBall", function(player) return Dinos.TakeBall(player) end)
	Net.On("PickBall", function(player) return Dinos.TakeBall(player) end)
	Net.On("ThrowBall", function(player, args)
		if typeof(args.Target) ~= "Vector3" then return { Ok = false } end
		if not Dinos.UseBall(player) then return { Ok = false } end
		-- at a nest site the dinos turn to look and your companion goes after it
		local Encounter = require(script.Parent.Encounter)
		local site = Encounter.SiteOf(player)
		if site then Encounter.BallThrown(site, player, args.Target) end
		return { Ok = true, AtSite = site ~= nil }
	end)
	locked("EquipCompanion", function(player, args) return typeof(args.Id) == "string" and Dinos.EquipCompanion(player, args.Id, tonumber(args.Slot)) or { Ok = false } end)
	Net.On("UnequipCompanion", function(player, args) return typeof(args.Id) == "string" and Dinos.UnequipCompanion(player, args.Id) or { Ok = false } end)
	Net.On("HealDino", function(player, args) return typeof(args.Id) == "string" and Dinos.Heal(player, args.Id) or { Ok = false } end)
	Net.On("SetBuddy", function(player, args)
		if args.On == true and player:GetAttribute("Trading") then return { Ok = false, Err = "FINISH YOUR TRADE FIRST" } end
		return typeof(args.Id) == "string" and Dinos.SetBuddy(player, args.Id, args.On == true) or { Ok = false }
	end)
	locked("EquipBest", function(player) return Dinos.EquipBest(player) end)
	locked("SellDinos", function(player, args) return typeof(args.Ids) == "table" and Dinos.Sell(player, args.Ids) or { Ok = false } end)
	locked("DropEgg", function(player, args)
		if typeof(args.Id) ~= "string" then return { Ok = false } end
		if player:GetAttribute("HeldEgg") == args.Id then clearHeld(player) end
		return Dinos.DropEgg(player, args.Id)
	end)
	locked("UnloadEgg", function(player, args)
		local Expedition = require(script.Parent.Expedition)
		if Expedition.Get(player) then return { Ok = false, Err = "NOT DURING A RUN" } end -- (a run's rack: Expedition)
		return Dinos.Unload(player, tonumber(args.Index))
	end)
	locked("UnloadAll", function(player)
		if require(script.Parent.Expedition).Get(player) then return { Ok = false } end -- (a run's rack: Expedition)
		return Dinos.UnloadAll(player)
	end)
	Net.On("HoldEgg", function(player, args) return Dinos.Hold(player, typeof(args.Id) == "string" and args.Id or nil) end)
	Net.On("HoldDino", function(player, args) return Dinos.HoldDino(player, typeof(args.Id) == "string" and args.Id or nil) end)
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			plr:SetAttribute("HeldEgg", nil)
			plr:SetAttribute("HeldDino", nil)
			-- a dino in your arms is put down when you sit in a vehicle (it'd be squashed)
			local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
			if hum then
				hum.Seated:Connect(function(active)
					if active and (plr:GetAttribute("HeldDino") or plr:GetAttribute("HeldEgg")) then clearHeld(plr) end -- (back in your bag)
				end)
			end
		end)
		-- and when you head out on an expedition
		plr:GetAttributeChangedSignal("Site"):Connect(function()
			if plr:GetAttribute("Site") and (plr:GetAttribute("HeldDino") or plr:GetAttribute("HeldEgg")) then clearHeld(plr) end
		end)
	end)
	-- incubator prompts in every plot: hatch a ready egg, or fill an empty one from your bag
	local camp = Workspace:WaitForChild("BaseCamp")
	for _, prompt in ipairs(camp:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("CampAction") == "Hatch" then
			prompt.Triggered:Connect(function(player)
				local plot = prompt:FindFirstAncestor("Plot" .. tostring(player:GetAttribute("Plot") or 0))
				if not plot then return end
				local slot = prompt:GetAttribute("Slot") or 0
				local profile = Data.Peek(player)
				if not profile then return end
				if player:GetAttribute("Trading") then Net.Fire(player, "Toast", { Text = "FINISH YOUR TRADE FIRST", Color = "Red" }) return end
				if not incubatorAt(profile, slot) then
					local eggId = player:GetAttribute("HeldEgg")
					local res
					if typeof(eggId) == "string" and find(profile.Eggs, eggId) then res = Dinos.Incubate(player, eggId, slot)
					elseif #profile.Eggs > 0 then res = Dinos.Incubate(player, profile.Eggs[1].Id, slot)
					else res = { Ok = false, Err = "NO EGGS - GO ON AN EXPEDITION!" } end
					if not res.Ok then Net.Fire(player, "Toast", { Text = res.Err or "CAN'T", Color = "Red" }) end
					return
				end
				local res = Dinos.Hatch(player, slot)
				if res.Ok then Net.Fire(player, "HatchReveal", res) else Net.Fire(player, "Toast", { Text = res.Err or "NOT READY", Color = "Red" }) end
			end)
		end
	end
	-- ready pings
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, plr in ipairs(Players:GetPlayers()) do
				local profile = Data.Peek(plr)
				if not profile then continue end
				for _, inc in ipairs(profile.Incubators) do
					if not inc.Notified and now >= inc.Start + inc.Duration then
						inc.Notified = true
						Net.Fire(plr, "EggReady", { Slot = inc.Slot, Species = inc.Species, Rarity = inc.Rarity })
						Plots.Sync(plr)
					end
				end
			end
		end
	end)
end

return Dinos
