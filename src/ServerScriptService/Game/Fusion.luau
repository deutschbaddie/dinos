--[[
	Fusion — EGG FUSION at the Egg Keeper's Fusion Nest (2026-10-14): three eggs of one species and one rarity become
	one egg of that species a rarity up (Config.Fusion / FuseTo / FuseKG / CanFuse).

	  "Fuse"     { Ids = { a, b, c } } -> { Ok, Result = { Egg, From, Used = { kg, kg, kg } } }
	  "FuseAll"  {}                    -> { Ok, Results = { ... } }  every group that has 3+ RIGHT NOW, heaviest eggs
	                                     first. The new eggs don't fuse again in the same press: what glows in the
	                                     window is exactly what fuses (9 commons make 3 uncommons, not a surprise rare)

	Only eggs in your BAG fuse - never one in a nest (profile.Incubators), on your rover's rack (RoverEggs) or while a
	trade is open (the Trading attribute locks the whole bag, like Dinos' other bag actions; Dinos.TradeBlock is the
	"is it in the bag" check). 3 -> 1 always frees room, so a full bag never blocks it. Every swap runs with no yield
	between the checks and the change (atomic), then one Data.Changed.
	MUTATION / HYBRID eggs (later) are skipped by Config.CanFuse and left untouched.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Fusion = {}
local Data, Net, Dinos, Expedition

local RANGE = 45 -- studs from the Fusion Nest (or the Egg Keeper) - the window only opens there
local MAX_PER_PRESS = 24 -- FUSE ALL: the rest stay glowing for the next press

local spots = {} :: { BasePart }
local function findSpots()
	table.clear(spots)
	local camp = Workspace:FindFirstChild("BaseCamp")
	if not camp then return end
	for _, name in ipairs({ "FusionPod", "NpcSpot_EggKeeper" }) do
		local p = camp:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then table.insert(spots, p) end
	end
end

local function near(player: Player): boolean
	if #spots == 0 then findSpots() end
	if #spots == 0 then return true end -- (an old map without the nest or the keeper: don't lock the feature out)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end
	for _, s in ipairs(spots) do
		if (s.Position - hrp.Position).Magnitude <= RANGE then return true end
	end
	return false
end

-- can this player fuse right now? nil = yes, else why not (player-facing)
local function blocked(player: Player, profile): string?
	if not profile then return "STILL LOADING" end
	if player:GetAttribute("Trading") then return "FINISH YOUR TRADE FIRST" end
	if Expedition and Expedition.Get(player) then return "NOT DURING AN EXPEDITION" end
	if not near(player) then return "COME BACK TO THE EGG KEEPER" end
	return nil
end

local function indexOf(list, id: string): number?
	for i, v in ipairs(list) do if v.Id == id then return i end end
	return nil
end

-- the swap itself: the eggs (already checked) out, the new one in. No yields.
local function swap(player: Player, profile, used: { any })
	local first = used[1]
	local to = Config.FuseTo(first.Rarity) :: string
	local kgs, dev = {}, false
	for _, e in ipairs(used) do
		table.insert(kgs, e.KG or 0)
		if e.Dev then dev = true end
	end
	local egg = { Id = Data.NewId(), Species = first.Species, Rarity = to, KG = Config.FuseKG(first.Species, kgs) }
	-- (a Test Tools egg makes a test egg: its hatch stays unannounced, like the eggs that went in)
	if dev then (egg :: any).Dev = true end
	local held = player:GetAttribute("HeldEgg")
	for _, e in ipairs(used) do
		local i = indexOf(profile.Eggs, e.Id)
		if i then table.remove(profile.Eggs, i) end
		if held == e.Id then Dinos.ClearHeld(player) end
	end
	table.insert(profile.Eggs, egg)
	profile.Stats.Fused = (profile.Stats.Fused or 0) + 1
	return { Egg = egg, From = first.Rarity, Used = kgs }
end

function Fusion.Fuse(player: Player, ids: any)
	local profile = Data.Peek(player)
	local why = blocked(player, profile)
	if why then return { Ok = false, Err = why } end
	if type(ids) ~= "table" or #ids ~= Config.Fusion.Count then return { Ok = false, Err = "PICK 3 MATCHING EGGS" } end
	local used, seen = {}, {}
	for _, id in ipairs(ids) do
		if typeof(id) ~= "string" or seen[id] then return { Ok = false, Err = "PICK 3 MATCHING EGGS" } end
		seen[id] = true
		local bad = Dinos.TradeBlock(profile, "Egg", id)
		if bad then return { Ok = false, Err = bad } end
		local e = profile.Eggs[indexOf(profile.Eggs, id) :: number]
		if not Config.CanFuse(e) then
			return { Ok = false, Err = (e.Mutation or e.Hybrid) and "SPECIAL EGGS CAN'T FUSE (YET!)" or "THAT EGG IS ALREADY THE BEST IT CAN BE" }
		end
		if #used > 0 and (e.Species ~= used[1].Species or e.Rarity ~= used[1].Rarity) then
			return { Ok = false, Err = "THEY MUST BE THE SAME DINO AND RARITY" }
		end
		table.insert(used, e)
	end
	local result = swap(player, profile, used)
	Data.Changed(player)
	return { Ok = true, Result = result }
end

function Fusion.FuseAll(player: Player)
	local profile = Data.Peek(player)
	local why = blocked(player, profile)
	if why then return { Ok = false, Err = why } end
	-- the groups as they are now (nothing made below joins them)
	local groups, order = {}, {}
	for _, e in ipairs(profile.Eggs) do
		if Config.CanFuse(e) then
			local key = e.Species .. "|" .. e.Rarity
			if not groups[key] then groups[key] = {} table.insert(order, key) end
			table.insert(groups[key], e)
		end
	end
	local triples = {}
	for _, key in ipairs(order) do
		local g = groups[key]
		if #g >= Config.Fusion.Count then
			table.sort(g, function(a, b) return (a.KG or 0) > (b.KG or 0) end)
			for k = 0, math.floor(#g / Config.Fusion.Count) - 1 do
				table.insert(triples, { g[k * 3 + 1], g[k * 3 + 2], g[k * 3 + 3] })
			end
		end
	end
	if #triples == 0 then return { Ok = false, Err = "NO 3 MATCHING EGGS YET" } end
	-- lowest first, so the rarest one is the last reveal of the quick cutscene
	table.sort(triples, function(a, b)
		local ra, rb = Config.Rarity[a[1].Rarity].Order, Config.Rarity[b[1].Rarity].Order
		if ra ~= rb then return ra < rb end
		return (table.find(Config.SpeciesOrder, a[1].Species) or 99) < (table.find(Config.SpeciesOrder, b[1].Species) or 99)
	end)
	local results = {}
	for i, t in ipairs(triples) do
		if i > MAX_PER_PRESS then break end
		table.insert(results, swap(player, profile, t))
	end
	Data.Changed(player)
	return { Ok = true, Results = results, More = #triples > MAX_PER_PRESS }
end

function Fusion.Start(deps)
	Data, Net, Dinos, Expedition = deps.Data, deps.Net, deps.Dinos, deps.Expedition
	task.defer(findSpots)
	Net.On("Fuse", function(player, args) return Fusion.Fuse(player, args.Ids) end)
	Net.On("FuseAll", function(player) return Fusion.FuseAll(player) end)
end

return Fusion
