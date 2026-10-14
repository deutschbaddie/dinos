--[[
	WildLife — what free roam has to find (2026-10-13, user picks: "rare wild dinos" + "hidden egg stashes", and "eggs
	should be rare because getting it from the creatures is better").

	WILD DINOS: two per era, out on open ground away from the road and the nests - one of the era's own species, alone.
	  Most are plain; some glow RARE, a few SHINY (the aura is Config.Rarity's look for Rare / Legendary). Walk up and
	  it's a fight like any nest (Encounter.MakeSite, a "Brute" with a rodeo finish); knock it out and its ONE egg drops
	  where it fell - takedown luck, and the glow is the egg's floor (Rare / Epic). Then the chase home on the nearest
	  road. No pin, no map entry: you find them by exploring. Once it's rested (Encounter's cooldown) it turns up
	  somewhere else, freshly rolled.
	EGG STASHES: two per era, tucked away from everything. One ordinary egg (a normal roll - never takedown luck,
	  never better than a nest's) straight into your bag. Then it's gone for STASH_BACK seconds and turns up somewhere new.
	HIDING PLACES (2026-10-14): an era map can mark them - a RoamSpots folder of StashSpot / WildSpot parts (Fern Valley:
	  the grotto behind Sky Falls, the Elder Tree's lookout, Arch Rock's shoulder, the hollow log's back, the lake islet;
	  wild ones on the flats below the falls, in a glade behind Rock Canyon's south wall, on the Arch Rock lookout and on
	  Horn Meadow's south flats).
	  Those are used first (a different one each time); open ground at random is only the fallback. A marked stash is
	  easier to learn than a random one, so a taken stash stays gone longer (STASH_BACK).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local RouteMath = require(ReplicatedStorage.DinoExpedition.Game.RouteMath)

local WildLife = {}
-- hooks for the Index's SECRETS (Discover.luau, 2026-10-14): who took a stash / calmed a wild one
WildLife.OnStash = nil :: ((Player, string, Vector3) -> ())?
WildLife.OnWildCalm = nil :: ((any) -> ())?
local Net, Data, Dinos, Encounter, Expedition
local rng = Random.new()

local WILD_PER_ERA = 2
local STASH_PER_ERA = 2
local STASH_BACK = 900 -- (2026-10-14: was 600; the marked hiding places are learnable, so they come back slower)
local FLOOR_NAMES = { Ground = true, Hills = true, Swells = true }

-- the glow: plain 65%, rare 28%, shiny 7% (the egg's rarity floor)
local function rollGlow(): (string?, string)
	local r = rng:NextNumber()
	if r < 0.07 then return "Epic", "SHINY" end
	if r < 0.35 then return "Rare", "RARE" end
	return nil, "WILD"
end

local function speciesPool(era): { string }
	local seen, out = {}, {}
	for _, def in ipairs(era.Sites or {}) do
		local c = Config.Combat[def.Species]
		if c and (c.Calm or 0) >= 100 and def.Kind ~= "Swarm" and def.Kind ~= "Flyer" and not seen[def.Species] then
			seen[def.Species] = true
			table.insert(out, def.Species)
		end
	end
	return out
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- an open, walkable spot well away from the road, the nests, the portals and anything else already placed
local taken = {} :: { [string]: { Vector3 } } -- era -> spots in use
local function pickSpot(eraId: string, minRoad: number): Vector3?
	local zm = Workspace:FindFirstChild(eraId)
	local route = RouteMath.get(eraId)
	if not (zm and zm:IsA("Model") and route) then return nil end
	local floors = {}
	for _, c in ipairs(zm:GetChildren()) do if FLOOR_NAMES[c.Name] then table.insert(floors, c) end end
	if #floors == 0 then return nil end
	local groundRay = RaycastParams.new()
	groundRay.FilterType = Enum.RaycastFilterType.Include
	groundRay.FilterDescendantsInstances = floors
	local anyRay = RaycastParams.new()
	anyRay.FilterType = Enum.RaycastFilterType.Exclude
	anyRay.RespectCanCollide = false
	local room = OverlapParams.new()
	room.FilterType = Enum.RaycastFilterType.Exclude
	room.FilterDescendantsInstances = floors
	room.RespectCanCollide = true
	local cf, size = zm:GetBoundingBox()
	local ends = { route:Position(1, 4, 0), route:Position(1, route:Length(1) - 4, 0) }
	for _ = 1, 80 do
		local x = cf.X + rng:NextNumber(-0.4, 0.4) * size.X
		local z = cf.Z + rng:NextNumber(-0.4, 0.4) * size.Z
		local top = cf.Y + size.Y / 2 + 40
		local hit = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(size.Y + 120), 0), groundRay)
		if not hit then continue end
		local p = hit.Position
		-- (not under water: the first thing above the ground mustn't be a lake or a river)
		local first = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top - p.Y) - 0.5, 0), anyRay)
		if first and (first.Material == Enum.Material.Water or string.find(first.Instance.Name, "Water", 1, true) or string.find(first.Instance.Name, "Pond", 1, true) or string.find(first.Instance.Name, "Lake", 1, true)) then continue end
		-- room to stand: nothing solid round it (a cliff foot, a rock, a trunk)
		if #Workspace:GetPartBoundsInRadius(p + Vector3.new(0, 5, 0), 5, room) > 0 then continue end
		local _, _, dRoad = route:Project(1, p)
		if dRoad < minRoad then continue end
		local ok = true
		for _, s in ipairs(Encounter.Sites(eraId)) do
			if s.Center and not (s.Def and s.Def.Wild) and flat(p, s.Center) < 90 then ok = false break end
		end
		for _, e in ipairs(ends) do if flat(p, e) < 80 then ok = false end end
		for _, q in ipairs(taken[eraId] or {}) do if flat(p, q) < 80 then ok = false end end
		if ok then return p end
	end
	return nil
end
-- a marked hiding place (RoamSpots/<kind> in the era map) that's free: not in use, and for a wild dino well clear
-- of the era's own sites. Tried in a random order, so it turns up somewhere different each time.
local function pickMarked(eraId: string, kind: string, clearOfSites: boolean): Vector3?
	local zm = Workspace:FindFirstChild(eraId)
	local f = zm and zm:FindFirstChild("RoamSpots")
	if not f then return nil end
	local list = {}
	for _, m in ipairs(f:GetChildren()) do
		-- (each marker's bottom is the ground)
		if m:IsA("BasePart") and m.Name == kind then table.insert(list, m.Position - Vector3.new(0, m.Size.Y / 2, 0)) end
	end
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	for _, p in ipairs(list) do
		local ok = true
		for _, q in ipairs(taken[eraId] or {}) do if flat(p, q) < 20 then ok = false break end end
		if ok and clearOfSites then
			for _, s in ipairs(Encounter.Sites(eraId)) do
				if s.Center and not (s.Def and s.Def.Wild) and flat(p, s.Center) < 90 then ok = false break end
			end
		end
		if ok then return p end
	end
	return nil
end

local function claim(eraId: string, p: Vector3)
	taken[eraId] = taken[eraId] or {}
	table.insert(taken[eraId], p)
end
local function release(eraId: string, p: Vector3)
	for i, q in ipairs(taken[eraId] or {}) do if q == p then table.remove(taken[eraId], i) return end end
end

--------------------------------------------------------------------------------
-- wild dinos
--------------------------------------------------------------------------------
local function dressWild(site, pool: { string })
	local species = pool[rng:NextInteger(1, #pool)]
	local floorR, tag = rollGlow()
	local sp = Config.Species[species]
	site.Def.Species = species
	site.Def.WildFloor = floorR
	site.Def.Name = tag .. " " .. string.upper(sp and sp.Name or species)
	site.Folder:SetAttribute("Species", species)
	site.Folder:SetAttribute("Name", site.Def.Name)
	site.Folder:SetAttribute("WildRarity", floorR)
end

local function spawnWild(era, i: number, pool: { string })
	local p = pickMarked(era.Id, "WildSpot", true) or pickSpot(era.Id, 45)
	if not p then
		task.delay(120, function() -- (same as a stash: try again rather than lose it)
			local ok, err = pcall(spawnWild, era, i, pool)
			if not ok then warn("[WildLife] wild:", era.Id, err) end
		end)
		return
	end
	claim(era.Id, p)
	local def = { Id = "Wild" .. i, Name = "WILD", Species = pool[1], Kind = "Brute", Count = 1, Wild = true }
	local site = Encounter.MakeSite(era.Id, def, p)
	dressWild(site, pool)
	-- calmed: the Index's secrets count it (Discover.luau sets WildLife.OnWildCalm; a wild site is one dino)
	site.OnKO = function(s)
		if WildLife.OnWildCalm then
			local ok, err = pcall(WildLife.OnWildCalm, s)
			if not ok then warn("[WildLife] OnWildCalm:", err) end
		end
	end
	-- rested: somewhere new, someone new
	site.OnRearm = function(s)
		local was = s.Center
		local q = pickMarked(era.Id, "WildSpot", true) or pickSpot(era.Id, 45)
		if q then
			release(era.Id, was)
			claim(era.Id, q)
			Encounter.MoveSite(s, q)
		end
		dressWild(s, pool)
	end
end

--------------------------------------------------------------------------------
-- egg stashes
--------------------------------------------------------------------------------
local folder: Folder? = nil
local function stashModel(p: Vector3, species: string): Model
	local m = Instance.new("Model")
	m.Name = "EggStash"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
		local b = Instance.new("Part")
		b.Name = name
		b.Anchored, b.CanCollide, b.CanTouch, b.CastShadow = true, false, false, true
		b.Size = size
		b.CFrame = cf
		b.Color = color
		b.Material = mat or Enum.Material.SmoothPlastic
		b.TopSurface, b.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		b.Parent = m
		return b
	end
	-- a little nest of twigs and leaves
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		part("Twig", Vector3.new(0.5, 0.45, 2.2), CFrame.new(p + Vector3.new(math.cos(a) * 1.4, 0.25, math.sin(a) * 1.4)) * CFrame.Angles(0, -a + 0.4, 0.2), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
	end
	part("Leaves", Vector3.new(3.4, 0.3, 3.4), CFrame.new(p + Vector3.new(0, 0.12, 0)), Color3.fromRGB(86, 120, 54), Enum.Material.Grass)
	local sp = Config.Species[species]
	local egg = part("Egg", Vector3.new(1.5, 1.9, 1.5), CFrame.new(p + Vector3.new(0, 1.15, 0)), sp and sp.Color or Color3.fromRGB(240, 230, 210))
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(1.7, 1.7, 1.7)
	-- (a faint glint, so a sharp eye spots it from a distance - no marker, no pin)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 1.5
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.Size = NumberSequence.new(0.5, 0)
	pe.LightEmission = 0.4
	pe.Parent = egg
	m.PrimaryPart = egg
	return m
end

local function spawnStash(era, pool: { string })
	local p = pickMarked(era.Id, "StashSpot", false) or pickSpot(era.Id, 35)
	if not p then
		-- (no free spot this time - the random search can come up empty: try again later rather than lose this
		-- stash for the rest of the server's life. 2026-10-14)
		task.delay(120, function()
			local ok, err = pcall(spawnStash, era, pool)
			if not ok then warn("[WildLife] stash:", era.Id, err) end
		end)
		return
	end
	claim(era.Id, p)
	local species = pool[rng:NextInteger(1, #pool)]
	local m = stashModel(p, species)
	m:SetAttribute("Era", era.Id)
	m:SetAttribute("Species", species)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "StashPrompt"
	pr.ActionText = "Take"
	pr.ObjectText = "Egg"
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.GamepadKeyCode = Enum.KeyCode.ButtonX
	pr.HoldDuration = 0.5
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Parent = m.PrimaryPart
	local gone = false
	pr.Triggered:Connect(function(plr: Player)
		if gone then return end
		local run = Expedition.Get(plr) or (Expedition.RiderRun and Expedition.RiderRun(plr))
		if not run or run.Zone ~= era.Id then return end
		local profile = Data.Peek(plr)
		if not profile then return end
		-- an ordinary egg: a normal roll, no takedown luck
		local rarity = Dinos.RollRarity(profile, 0)
		local e = Dinos.AddEgg(plr, species, rarity, 0, Dinos.RollKG(species))
		if not e then return end -- (bag full: AddEgg said so; it stays for later)
		gone = true
		Data.Changed(plr)
		Net.Fire(plr, "StashFound", { Species = species, Rarity = rarity, At = p })
		if WildLife.OnStash then pcall(WildLife.OnStash, plr, era.Id, p) end -- (the Index's secrets: Discover.luau)
		m:Destroy()
		release(era.Id, p)
		-- (guarded: a throw here lost this era's stash for the rest of the server's life)
		task.delay(STASH_BACK, function()
			local ok, err = pcall(spawnStash, era, pool)
			if not ok then warn("[WildLife] stash:", era.Id, err) end
		end)
	end)
	m.Parent = folder
end

function WildLife.Start(deps)
	Net, Data, Dinos, Encounter, Expedition = deps.Net, deps.Data, deps.Dinos, deps.Encounter, deps.Expedition
	local f = Instance.new("Folder")
	f.Name = "DinoWild"
	f.Parent = Workspace
	folder = f
	-- (after the eras' own sites exist: the spots keep clear of them)
	task.delay(3, function()
		for _, era in ipairs(Config.Eras) do
			if not (era :: any).Built or not Workspace:FindFirstChild(era.Id) then continue end
			local pool = speciesPool(era)
			if #pool == 0 then continue end
			for i = 1, WILD_PER_ERA do
				local ok, err = pcall(spawnWild, era, i, pool)
				if not ok then warn("[WildLife] wild:", era.Id, err) end
			end
			for _ = 1, STASH_PER_ERA do
				local ok, err = pcall(spawnStash, era, pool)
				if not ok then warn("[WildLife] stash:", era.Id, err) end
			end
		end
	end)
	local _ = Players
end

return WildLife
