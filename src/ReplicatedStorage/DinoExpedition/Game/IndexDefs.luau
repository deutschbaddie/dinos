--[[
	IndexDefs — what the DINO INDEX pays out, and every era's SECRETS (2026-10-14, round 2: #4 index rewards, #6
	the discovery tracker). Shared: the server (IndexRewards.luau, Discover.luau) validates and pays from these, the
	client (IndexView.luau, DiscoverView.luau) draws the same numbers.

	INDEX REWARDS   permanent and claimed by hand in the Index (a node glows when it's ready):
	  the SPECIES track    every few species discovered (any rarity counts): +LUCK, +POWER/SEC, coins, a title
	  ERA PAGES            every species of one era found (its boss too): a GOLD trophy of that era's boss in your
	                       island's trophy hall, an era title, +POWER/SEC, coins
	  Titles show on your profile card and over your head (player attribute IndexTitle; you pick which).
	  Saved in profile.IndexRewards = { Claimed = { ["Species/10"] = true, ["Era/FernValley"] = true, ... },
	  Title = "<title id>" }. LATER: MUTATIONS and HYBRIDS get their own tracks in Defs.Tracks (their own Count over
	  their own index entries); index keys this doesn't recognise are simply not counted.

	SECRETS         per era: its landmarks (DiscoverSpot markers the era generator places, listed in the era's route
	                data as Secrets), every nest, a hidden egg stash, a wild dino calmed, a SHINY wild calmed, and the
	                boss beaten. The server spots them (Discover.luau); profile.Discover[era][id] = true.
	                Finding them all: a rover paint only that gives (Rides.Colors, Award = "Secrets") + coins.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local Defs = {}

--------------------------------------------------------------------------------
-- titles (id -> look). The nametag and the profile card both draw Name in Color.
--------------------------------------------------------------------------------
Defs.Titles = {
	Spotter = { Name = "DINO SPOTTER", Color = Color3.fromRGB(168, 237, 72) },
	Tracker = { Name = "DINO TRACKER", Color = Color3.fromRGB(72, 168, 255) },
	Expert = { Name = "DINO EXPERT", Color = Color3.fromRGB(173, 102, 255) },
	Master = { Name = "DINO MASTER", Color = Color3.fromRGB(255, 212, 71), Rainbow = true },
	-- one per era page
	FernValley = { Name = "VALLEY KEEPER", Color = Color3.fromRGB(95, 211, 90) },
	GiantPlains = { Name = "PLAINS WALKER", Color = Color3.fromRGB(226, 196, 106) },
	SpineRiver = { Name = "RIVER RUNNER", Color = Color3.fromRGB(63, 200, 210) },
	RedCliffs = { Name = "CLIFF CLIMBER", Color = Color3.fromRGB(232, 92, 48) },
	FrostForest = { Name = "FROST WARDEN", Color = Color3.fromRGB(120, 200, 255) },
	DawnDesert = { Name = "DAWN SEEKER", Color = Color3.fromRGB(255, 140, 90) },
}

--------------------------------------------------------------------------------
-- the tracks: nodes you claim as a count climbs. Luck / Power are permanent bonuses (0.05 = +5%), fed to
-- Boosts.luau as the "Index" source. At = "All" means every species you can get today (Defs.SpeciesTotal).
--------------------------------------------------------------------------------
Defs.Tracks = {
	{
		Id = "Species", Name = "SPECIES FOUND",
		Nodes = {
			{ At = 3, Power = 0.05, Coins = 2500, Title = "Spotter" },
			{ At = 5, Luck = 0.05, Coins = 12000 },
			{ At = 10, Power = 0.10, Coins = 150000, Title = "Tracker" },
			{ At = 15, Luck = 0.10, Coins = 1500000 },
			{ At = 20, Power = 0.15, Coins = 15000000, Title = "Expert" },
			{ At = "All", Luck = 0.15, Power = 0.10, Coins = 60000000, Title = "Master" },
		},
	},
	-- (MUTATIONS / HYBRIDS: { Id = "Mutation", Name = "MUTATIONS FOUND", Nodes = {...} } + a counter in Defs.Count)
}
-- an era page: every species of that era found (any rarity)
Defs.EraPage = { Power = 0.03, CoinsPerTier = 12000 } -- coins x the era's tier (Config.EraTiers)

-- the species every player can get today: those whose era is built (THE LAB's Primal Rex isn't yet)
function Defs.SpeciesTotal(): number
	local n = 0
	for _, sp in ipairs(Config.SpeciesOrder) do
		local info = Config.Species[sp]
		local era = info and Config.Era(info.Era)
		if era and era.Built then n += 1 end
	end
	return n
end

-- species discovered: an index key "Species:Rarity" with a species Config knows (any other key is ignored, so
-- mutation / hybrid entries added later never inflate this count)
function Defs.SpeciesSet(index): { [string]: boolean }
	local set = {}
	if typeof(index) ~= "table" then return set end
	for key, v in pairs(index) do
		if v and typeof(key) == "string" then
			local sp = key:match("^([^:]+):")
			if sp and Config.Species[sp] then set[sp] = true end
		end
	end
	return set
end

function Defs.Count(profile, trackId: string): number
	if trackId == "Species" then
		local n = 0
		for _ in pairs(Defs.SpeciesSet(profile and profile.Index)) do n += 1 end
		return n
	end
	return 0
end

function Defs.NodeAt(node): number
	return node.At == "All" and Defs.SpeciesTotal() or tonumber(node.At) or math.huge
end
function Defs.NodeKey(trackId: string, node): string
	return trackId .. "/" .. tostring(node.At)
end

-- the eras that have a page: built ones with a boss, in era order
function Defs.PageEras(): { any }
	local out = {}
	for _, e in ipairs(Config.Eras) do
		if e.Built and e.Boss then table.insert(out, e) end
	end
	return out
end

-- one era's species (site dinos + its boss), in Index order
function Defs.EraSpecies(eraId: string): { string }
	local out = {}
	for _, sp in ipairs(Config.SpeciesOrder) do
		local info = Config.Species[sp]
		if info and info.Era == eraId then table.insert(out, sp) end
	end
	return out
end

function Defs.EraProgress(profile, eraId: string): (number, number)
	local set = Defs.SpeciesSet(profile and profile.Index)
	local list = Defs.EraSpecies(eraId)
	local n = 0
	for _, sp in ipairs(list) do if set[sp] then n += 1 end end
	return n, #list
end

local function claimed(profile, key: string): boolean
	local ir = profile and profile.IndexRewards
	return typeof(ir) == "table" and typeof(ir.Claimed) == "table" and ir.Claimed[key] == true
end
Defs.Claimed = claimed

-- every reward there is, in display order: { Key, Kind = "Node" | "Era", Ready, Claimed, Def, Era?, Track? }
function Defs.Rewards(profile): { any }
	local out = {}
	for _, track in ipairs(Defs.Tracks) do
		local count = Defs.Count(profile, track.Id)
		for _, node in ipairs(track.Nodes) do
			local key = Defs.NodeKey(track.Id, node)
			table.insert(out, { Key = key, Kind = "Node", Track = track, Def = node, At = Defs.NodeAt(node), Ready = count >= Defs.NodeAt(node), Claimed = claimed(profile, key) })
		end
	end
	for _, e in ipairs(Defs.PageEras()) do
		local key = "Era/" .. e.Id
		local n, total = Defs.EraProgress(profile, e.Id)
		table.insert(out, { Key = key, Kind = "Era", Era = e, Def = Defs.EraPage, Ready = total > 0 and n >= total, Claimed = claimed(profile, key), Found = n, Total = total })
	end
	return out
end

function Defs.Find(profile, key: string)
	for _, r in ipairs(Defs.Rewards(profile)) do if r.Key == key then return r end end
	return nil
end

-- what a reward gives: { Luck, Power, Coins, Title, Gold = boss id }
function Defs.Payout(r): any
	if r.Kind == "Era" then
		local era = r.Era
		return { Power = Defs.EraPage.Power, Coins = Defs.EraPage.CoinsPerTier * Config.EraTier(era.Id), Title = era.Id, Gold = era.Boss }
	end
	local d = r.Def
	return { Luck = d.Luck, Power = d.Power, Coins = d.Coins, Title = d.Title }
end

function Defs.ClaimableCount(profile): number
	local n = 0
	for _, r in ipairs(Defs.Rewards(profile)) do if r.Ready and not r.Claimed then n += 1 end end
	return n
end

-- the permanent bonuses from everything claimed: Luck, Power (fractions, 0.3 = +30%)
function Defs.Bonus(profile): (number, number)
	local luck, power = 0, 0
	for _, r in ipairs(Defs.Rewards(profile)) do
		if r.Claimed then
			local pay = Defs.Payout(r)
			luck += pay.Luck or 0
			power += pay.Power or 0
		end
	end
	return luck, power
end

-- titles this profile has earned (claimed), in track order
function Defs.EarnedTitles(profile): { string }
	local out = {}
	for _, r in ipairs(Defs.Rewards(profile)) do
		local t = r.Claimed and Defs.Payout(r).Title
		if t and Defs.Titles[t] then table.insert(out, t) end
	end
	return out
end

-- boss id -> true for every era page claimed (the gold trophies)
function Defs.GoldTrophies(profile): { [string]: boolean }
	local out = {}
	for _, e in ipairs(Defs.PageEras()) do
		if claimed(profile, "Era/" .. e.Id) and e.Boss then out[e.Boss] = true end
	end
	return out
end

--------------------------------------------------------------------------------
-- SECRETS
--------------------------------------------------------------------------------
-- the rover paint each era's secrets unlock (Rides.Colors ids) and the coins (x the era's tier)
Defs.SecretPaint = {
	FernValley = "SecretFern", GiantPlains = "SecretPlains", SpineRiver = "SecretRiver",
	RedCliffs = "SecretCliffs", FrostForest = "SecretFrost", DawnDesert = "SecretDawn",
}
Defs.SecretCoinsPerTier = 6000
-- how close counts as "there": a nest (from its centre), and a landmark's own Radius if its marker has none
Defs.NestRadius = 55
Defs.SpotRadius = 26

-- landmark list from the era's generated route data (Routes/<era>.luau: Secrets = { { Id, Name, Kind, Pos, R, Up } })
local routeCache = {} :: { [string]: any }
local function landmarks(eraId: string): { any }
	if routeCache[eraId] == nil then
		local ok, data = pcall(function()
			local folder = ReplicatedStorage:WaitForChild("DinoExpedition"):FindFirstChild("Routes")
			local mod = folder and folder:FindFirstChild(eraId)
			return mod and require(mod :: ModuleScript) or nil
		end)
		routeCache[eraId] = (ok and typeof(data) == "table" and typeof(data.Secrets) == "table") and data.Secrets or false
	end
	return routeCache[eraId] or {}
end
Defs.Landmarks = landmarks

-- every secret of one era, in page order: { Id, Name, Kind, Species?, Hint }
-- Kind: one of the landmark kinds (Falls, Arch, Tree, Lookout, Ruins, Fossil, Cave, Log, Island, Spring, Wreck,
-- Rock, Grove, Pond, Totem, Bridge, Dune) | "Nest" | "Boss" | "Stash" | "Wild" | "Shiny"
local secretCache = {} :: { [string]: { any } }
function Defs.Secrets(eraId: string): { any }
	if secretCache[eraId] then return secretCache[eraId] end
	local era = Config.Era(eraId)
	local out = {}
	if not era then return out end
	for _, s in ipairs(landmarks(eraId)) do
		if typeof(s) == "table" and typeof(s.Id) == "string" then
			table.insert(out, { Id = s.Id, Name = tostring(s.Name or s.Id), Kind = tostring(s.Kind or "Rock"), Landmark = true })
		end
	end
	for _, site in ipairs(era.Sites or {}) do
		table.insert(out, { Id = "Nest_" .. site.Id, Name = site.Name, Kind = "Nest", Species = site.Species, Site = site.Id })
	end
	local boss = era.Boss and Config.Bosses[era.Boss]
	if boss then table.insert(out, { Id = "Boss", Name = boss.Name, Kind = "Boss", Species = boss.Species }) end
	table.insert(out, { Id = "Stash", Name = "HIDDEN STASH", Kind = "Stash" })
	table.insert(out, { Id = "Wild", Name = "WILD DINO", Kind = "Wild" })
	table.insert(out, { Id = "Shiny", Name = "SHINY WILD", Kind = "Shiny" })
	-- (only cached once the landmarks are in: an era read before its route module replicated tries again)
	if #landmarks(eraId) > 0 then secretCache[eraId] = out end
	return out
end

function Defs.SecretOf(eraId: string, id: string)
	for _, s in ipairs(Defs.Secrets(eraId)) do if s.Id == id then return s end end
	return nil
end

function Defs.SecretProgress(profile, eraId: string): (number, number)
	local found = profile and typeof(profile.Discover) == "table" and profile.Discover[eraId]
	local list = Defs.Secrets(eraId)
	local n = 0
	if typeof(found) == "table" then
		for _, s in ipairs(list) do if found[s.Id] == true then n += 1 end end
	end
	return n, #list
end

function Defs.SecretFound(profile, eraId: string, id: string): boolean
	local found = profile and typeof(profile.Discover) == "table" and profile.Discover[eraId]
	return typeof(found) == "table" and found[id] == true
end

return Defs
