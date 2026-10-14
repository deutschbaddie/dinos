--[[
	Encounter — server-wide encounter sites. Every era runs a handful of sites (Config.Eras[].Sites) plus its
	ruler's den; anyone in the era can join a running one or start an idle one, and everyone there works together.

	  Idle      the dinos rest at the nest
	  Active    players are here. Two ways to win:
	              takedown: dart them (combo + weak spot), dodge telegraphed attacks, rodeo the big one → knock-out
	              escape:   hold the nest prompt to grab → alarm: the eggs spill and the dinos go wild
	  Scramble  players + 1 eggs spill out; grab what your roof rack holds (takedown eggs roll better odds)
	  Chase     everyone is pulled into their rover; Expedition runs the autopilot chase to the portal
	  Cooldown  the site rearms

	Dinos are Configurations in Runtime.Chasers (Owner 0, Site=key) so every client renders them with the
	shared models + animations; attacks are broadcast as telegraph shapes the client draws on the ground.
	The ruler's den runs the same machinery with phases (Bosses.luau drives those).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local RouteMath = require(ReplicatedStorage.DinoExpedition.Game.RouteMath)
local Runtime = ReplicatedStorage.DinoExpedition.Runtime
local ChaserFolder = Runtime:WaitForChild("Chasers")

local Encounter = {}
local Data, Net, Vehicles, Dinos, Quests, Expedition
local rng = Random.new()
local E = Config.Encounter

local SiteFolder = Runtime:FindFirstChild("Sites") or Instance.new("Folder")
SiteFolder.Name = "Sites"
SiteFolder.Parent = Runtime
local EggFolder = Runtime:FindFirstChild("SiteEggs") or Instance.new("Folder")
EggFolder.Name = "SiteEggs"
EggFolder.Parent = Runtime

local sites = {} :: { [string]: any } -- key "Era/SiteId"
local playerSite = {} :: { [Player]: any }
local nextActor = 100000
local nextEgg = 0

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------
local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
local function yawOf(d: Vector3): number
	if d.Magnitude < 1e-4 then return 0 end
	return math.atan2(-d.X, -d.Z)
end
local function dirOf(yaw: number): Vector3 return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)) end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.RespectCanCollide = true
local groundLists = setmetatable({}, { __mode = "k" }) :: { [Instance]: { Instance } }
local groundFor: Instance? = nil
local function groundY(site, p: Vector3, fallback: number): number
	local zm = Workspace:FindFirstChild(site.Era)
	if not zm then return fallback end
	-- only the era's walkable surfaces (whichever of these folders it has: GiantPlains has Swells, not Hills).
	-- the list is built once per era map and only re-assigned when the era changes (this runs per actor per tick)
	local cached = groundLists[zm]
	if not cached then
		local list = {}
		for _, n in ipairs({ "Ground", "Hills", "Swells", "Roads", "SeaMouth", "TheMaw" }) do -- (+ Spine River's docks and the Maw: walkable)
			local f = zm:FindFirstChild(n)
			if f then table.insert(list, f) end
		end
		cached = #list > 0 and list or { zm }
		groundLists[zm] = cached
	end
	if groundFor ~= zm then
		groundFor = zm
		groundParams.FilterDescendantsInstances = cached
	end
	local hit = Workspace:Raycast(Vector3.new(p.X, fallback + 14, p.Z), Vector3.new(0, -40, 0), groundParams)
	if hit and hit.Position.Y < fallback + 6 then return hit.Position.Y end
	return fallback
end

local function hrpOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- where a knockback is "from": away from the dino - except near the edge of a boss arena, where it throws you
-- back IN (being knocked out of the arena left you unable to fight, and the boss went after you)
local function knockFrom(site, player: Player, from: Vector3): Vector3
	if not site.Boss then return from end
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not h then return from end
	local out = Vector3.new(h.Position.X - site.Center.X, 0, h.Position.Z - site.Center.Z)
	if out.Magnitude > (site.Radius or 40) * 0.55 then return h.Position + out.Unit * 6 end
	return from
end

-- how high you're standing ON something that isn't the era's floor (a boulder, a log, a rover roof): what's under
-- your feet vs the real ground below it. 0 on the ground or a hill; nil in mid-air (a jump isn't a perch)
local standParams = RaycastParams.new()
standParams.FilterType = Enum.RaycastFilterType.Exclude
standParams.RespectCanCollide = true
local function perchHeight(site, hrp: BasePart): number?
	local list: { Instance } = {}
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(list, plr.Character) end end
	standParams.FilterDescendantsInstances = list
	local stand = Workspace:Raycast(hrp.Position, Vector3.new(0, -9, 0), standParams)
	if not stand then return nil end
	local zm = Workspace:FindFirstChild(site.Era)
	if not zm then return 0 end
	local floors = groundLists[zm]
	if not floors then groundY(site, hrp.Position, site.Center.Y) floors = groundLists[zm] end
	for _, f in ipairs(floors or {}) do if stand.Instance:IsDescendantOf(f) then return 0 end end
	groundParams.FilterDescendantsInstances = floors or {}
	groundFor = zm
	local floor = Workspace:Raycast(stand.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, -80, 0), groundParams)
	if not floor then return 0 end
	return stand.Position.Y - floor.Position.Y
end

local function fireSite(site, kind: string, payload)
	for plr in pairs(site.Players) do Net.Fire(plr, kind, payload) end
end
Encounter.FireSite = fireSite

local function rollMood(site)
	local total = 0
	for _, m in ipairs(E.Moods) do total += m.Weight end
	local pick = rng:NextNumber() * total
	site.Mood = E.Moods[1]
	for _, m in ipairs(E.Moods) do
		pick -= m.Weight
		if pick <= 0 then site.Mood = m break end
	end
	if site.Folder then site.Folder:SetAttribute("Mood", site.Mood.Id) end
end

local function publishSite(site)
	local f = site.Folder
	f:SetAttribute("Mood", site.Mood and site.Mood.Id or nil)
	f:SetAttribute("State", site.State)
	f:SetAttribute("Players", site.Count)
	f:SetAttribute("Until", site.Until or 0)
	f:SetAttribute("Tier", site.Tier or 1)
	f:SetAttribute("Phase", site.Phase or 0)
	f:SetAttribute("Alarm", site.Alarm == true)
	f:SetAttribute("Takedown", site.Takedown == true)
	local calm, max = 0, 0
	for _, a in ipairs(site.Actors) do if not a.Minion then calm += a.Calm max += a.CalmMax end end
	f:SetAttribute("Calm", calm)
	f:SetAttribute("CalmMax", max)
end

--------------------------------------------------------------------------------
-- actors (dinos)
--------------------------------------------------------------------------------
local function newActor(site, species: string, pos: Vector3, opts)
	opts = opts or {}
	nextActor += 1
	local stats = Config.Combat[species]
	local calm = (opts.Calm or stats.Calm) * (site.CalmMult or 1)
	local a = {
		Id = nextActor, Species = species, Pos = pos, Yaw = opts.Yaw or 0, State = opts.State or "Idle", T = 0, Aware = 0,
		Calm = 0, CalmMax = calm, Speed = (opts.Speed or stats.Speed), Stats = stats, Home = pos,
		NextAttack = os.clock() + rng:NextNumber(1.2, 2.4), Minion = opts.Minion, Boss = opts.Boss, Lead = opts.Lead,
		Scale = opts.Scale or stats.Scale or 1, StunUntil = 0, Attack = nil,
	}
	local cfg = Instance.new("Configuration")
	cfg.Name = species .. a.Id
	cfg:SetAttribute("Owner", 0)
	cfg:SetAttribute("Id", a.Id)
	cfg:SetAttribute("Site", site.Key)
	cfg:SetAttribute("Species", species)
	cfg:SetAttribute("Scale", a.Scale)
	cfg:SetAttribute("State", opts.State or "Idle")
	cfg:SetAttribute("P", pos)
	cfg:SetAttribute("Yaw", a.Yaw)
	cfg:SetAttribute("V", 0)
	cfg:SetAttribute("Calm", 0)
	cfg:SetAttribute("CalmMax", calm)
	if opts.Boss then
		cfg:SetAttribute("Boss", true)
		cfg:SetAttribute("DisplayName", opts.Name)
	end
	if opts.Lead then cfg:SetAttribute("Lead", true) end
	if opts.Minion then cfg:SetAttribute("Minion", true) end -- (EraView's scope-out skips a boss's pack; it was never set. 2026-10-14)
	cfg.Parent = ChaserFolder
	a.Cfg = cfg
	table.insert(site.Actors, a)
	return a
end
Encounter.NewActor = newActor

local function setState(a, s: string)
	-- the weak spot only glows while it's actually open: a stun, a distraction or the rodeo window cutting a
	-- recovery short used to leave "WEAK SPOT OPEN" on a dino that had none
	if (a.State == "Recover" or a.State == "Dazed") and s ~= a.State and a.Cfg.Parent then a.Cfg:SetAttribute("Weak", nil) end
	a.State = s
	a.T = 0
	a.Vel = 0 -- (it gets going again from a standstill: no stale full speed after a wind-up)
	if s ~= "Telegraph" and s ~= "Attack" then a.GlideFromY = nil end -- (a dive cut short doesn't glide the next lunge)
	if s ~= "Attack" then a.DashDur = nil end
	a.Cfg:SetAttribute("State", s)
end

local function removeActors(site)
	for _, a in ipairs(site.Actors) do a.Cfg:Destroy() end
	table.clear(site.Actors)
	for _, b in pairs(site.Buddies) do b.Cfg:Destroy() end
	table.clear(site.Buddies)
end

-- the dinos a site starts with
local function spawnResidents(site)
	local def = site.Def
	local c = site.Center
	if def.Kind == "Pack" then
		for k = 1, def.Count or 3 do
			local spot = site.Spots[k] or (c + Vector3.new(math.cos(k * 2.1) * 9, 0, math.sin(k * 2.1) * 9))
			newActor(site, def.Species, spot, { Yaw = rng:NextNumber(0, 6.28), State = "Unaware" })
		end
	elseif def.Kind == "Herd" then
		local lead = newActor(site, def.Species, site.Spots[1] or c + Vector3.new(8, 0, 0), { Lead = true, Calm = Config.Combat[def.Species].Calm * 2.2, Scale = 1.15, State = "Unaware" })
		lead.Rodeo = true
		for k = 2, def.Count or 3 do
			newActor(site, def.Species, site.Spots[k] or (c + Vector3.new(-8, 0, k * 4)), { Calm = Config.Combat[def.Species].Calm * 0.6, Scale = 0.85, State = "Unaware" })
		end
	elseif def.Kind == "Brute" then
		local b = newActor(site, def.Species, site.Spots[1] or c + Vector3.new(9, 0, 0), { Lead = true, State = "Unaware" })
		b.Rodeo = true
		-- a wild one that glows (WildLife.luau): clients dress it in that rarity's aura
		if def.Wild and def.WildFloor then b.Cfg:SetAttribute("WildRarity", def.WildFloor) end
	elseif def.Kind == "Swarm" then
		-- SWARM (Compy, Log Warren): a crowd of tiny biters round the nest, each out in a couple of darts. One notices
		-- you and they all come; anything that hits an area (a splash launcher, a gadget) takes out a handful
		local n = def.Count or 10
		local stats = Config.Combat[def.Species]
		for k = 1, n do
			local ang = k / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local r = 6 + (k % 3) * 3
			local p = c + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
			p = Vector3.new(p.X, groundY(site, p, c.Y), p.Z)
			local a = newActor(site, def.Species, p, { Yaw = rng:NextNumber(0, 6.28), State = "Unaware", Calm = stats.Calm * 0.32, Scale = (stats.Scale or 1) * 0.9 })
			a.Swarm = true
			a.DmgMult = 0.6
		end
	elseif def.Kind == "Rival" then
		-- RIVAL (Oviraptor, Thief's Ledge): another pack is here for the same eggs. They wait at the edge, then sneak
		-- in egg by egg - every egg one reaches first, it carries off (dart it and it drops it)
		for k = 1, def.Count or 3 do
			local ang = k * 2.1 + 0.4
			local p = c + Vector3.new(math.cos(ang) * 30, 0, math.sin(ang) * 30)
			p = Vector3.new(p.X, groundY(site, p, c.Y), p.Z)
			local a = newActor(site, def.Species, p, { Yaw = yawOf(flat(c - p)), State = "Unaware" })
			a.Rival = true
			a.RivalAt = os.clock() + 7 + k * 3
		end
	elseif def.Kind == "Flyer" then
		-- FLYER (Microraptor, Glider Pines): up in the trees on the perches over the nest. Spotted, they glide down onto
		-- you; mid-fight one climbs back up a trunk to dive again
		for k = 1, def.Count or 3 do
			local spot = site.Perches and site.Perches[k]
			local p = spot or (c + Vector3.new(math.cos(k * 2.1) * 9, 0, math.sin(k * 2.1) * 9))
			local a = newActor(site, def.Species, p, { Yaw = rng:NextNumber(0, 6.28), State = "Unaware" })
			if spot then
				a.Perch = spot
				a.Perched = true
			end
		end
	end
	-- GUARDS (Config site Guards): extra dinos beside the lead - a baby Triceratops that charges you. Scale is a
	-- share of the species' own size, Calm a share of its calm; a baby hits for its size, too
	for i, g in ipairs(def.Guards or {}) do
		local stats = Config.Combat[g.Species]
		if not stats then continue end
		local base = site.Spots[1] or c + Vector3.new(9, 0, 0)
		local ang = i * 2.4 + 0.6
		local p = base + Vector3.new(math.cos(ang) * 6, 0, math.sin(ang) * 6)
		p = Vector3.new(p.X, groundY(site, p, c.Y), p.Z)
		local gd = newActor(site, g.Species, p, { Scale = (stats.Scale or 1) * (g.Scale or 1), Calm = stats.Calm * (g.Calm or 1), State = "Unaware", Yaw = rng:NextNumber(0, 6.28) })
		gd.DmgMult = math.clamp(g.Dmg or g.Scale or 1, 0.2, 1)
		gd.IsGuard = true
	end
end

--------------------------------------------------------------------------------
-- players at a site
--------------------------------------------------------------------------------
local function maxHP(profile): number
	local a = Config.Armors[profile.Gear.Armor] or Config.Armors.None
	return math.floor(a.HP * (1 + Config.LevelBonus * ((profile.Gear.ArmorLvl or 1) - 1)))
end

local function setHP(st, player: Player)
	player:SetAttribute("HP", math.max(0, math.floor(st.HP)))
	player:SetAttribute("MaxHP", st.MaxHP)
	player:SetAttribute("Downed", st.Downed or nil)
end

local function expedition() return require(script.Parent.Expedition) end

-- how long / wide a companion's body is at its size (so it follows with room to spare, not on your heels)
local bodyCache = {} :: { [string]: Vector3 }
local function bodySize(species: string, scale: number): (number, number)
	local base = bodyCache[species]
	if not base then
		local t = game:GetService("ReplicatedStorage").DinoExpedition.Dinosaurs:FindFirstChild(species)
		local ok, ext = pcall(function() return (t :: Model):GetExtentsSize() end)
		base = ok and ext or Vector3.new(4, 4, 8)
		bodyCache[species] = base :: Vector3
	end
	local b = base :: Vector3
	return math.max(b.X, b.Z) * scale, math.min(b.X, b.Z) * scale
end

local function spawnBuddies(site, player: Player)
	local profile = Data.Peek(player)
	if not profile then return end
	local dps = Config.LauncherDps(profile.Gear, Config.DartMult(profile.Gear, Dinos.BuddyList(profile), profile.TrainPower))
	-- they hop out of the rover and trot over (if it's parked here)
	local rover = Vehicles.Root(player)
	for i, d in ipairs(Dinos.BuddyList(profile)) do
		if expedition().Fallen(player, d.Id) then continue end -- knocked out earlier this run: it stays in the rover
		local hrp = hrpOf(player)
		local p = hrp and hrp.Position or site.Center
		if rover and hrp and (rover.Position - hrp.Position).Magnitude < 60 then p = rover.Position end
		local bond = Dinos.BondLevel(profile, d.Id)
		local hp = Config.BuddyHP(d, bond)
		nextActor += 1
		local cfg = Instance.new("Configuration")
		cfg.Name = "Buddy" .. nextActor
		cfg:SetAttribute("Owner", player.UserId)
		cfg:SetAttribute("Id", nextActor)
		cfg:SetAttribute("Site", site.Key)
		cfg:SetAttribute("Species", d.Species)
		cfg:SetAttribute("Buddy", true)
		cfg:SetAttribute("Rarity", d.Rarity)
		cfg:SetAttribute("Scale", Config.BuddyScale(d))
		cfg:SetAttribute("State", "Follow")
		cfg:SetAttribute("P", p + Vector3.new(i * 3, 0, 2))
		cfg:SetAttribute("Yaw", 0)
		cfg:SetAttribute("HP", hp)
		cfg:SetAttribute("MaxHP", hp)
		cfg:SetAttribute("Name", string.upper((Config.Species[d.Species] or { Name = d.Species }).Name))
		cfg:SetAttribute("Bond", bond)
		cfg.Parent = ChaserFolder
		local b = { Cfg = cfg, Owner = player, Dino = d, Dps = dps, HP = hp, MaxHP = hp, Pos = p, Next = os.clock() + 2, Slot = i, Bond = bond }
		b.Len, b.Wide = bodySize(d.Species, Config.DinoScale(d) * 0.75)
		local function has(perk: string) return Config.HasPerk(d.Species, bond, perk) end
		b.Perks = { Sniffer = has("Sniffer"), Carry = has("Carry"), Shield = has("Shield"), Rescue = has("Rescue") }
		-- at a nest of its own kind it goes undercover: a family reunion (they share an egg) or an inside job (it
		-- keeps them busy and shows you the eggs) - one companion per visit
		local undercover = false
		for _, o in pairs(site.Buddies) do if o.Owner == player and o.Under then undercover = true end end
		if not undercover and not site.Boss and not site.Alarm and site.Def and site.Def.Species == d.Species then
			b.Under = rng:NextNumber() < 0.5 and "Reunion" or "Inside"
		end
		if b.Perks.Sniffer and not site.Boss then b.SniffAt = os.clock() + 4 end
		site.Buddies[cfg] = b
	end
	-- a companion that can carry: your egg prompts stay on when your hands are full
	local canCarry = false
	for _, b in pairs(site.Buddies) do if b.Owner == player and b.Perks and b.Perks.Carry then canCarry = true end end
	player:SetAttribute("CompanionCarry", canCarry or nil)
end

-- a little bubble over a companion (the client draws it): Alert, Chat, Egg, Love, Shield, Sniff, Dig, Help
local function emote(site, b, kind: string, at: Vector3?)
	fireSite(site, "BuddyEmote", { Buddy = b.Cfg:GetAttribute("Id"), Emote = kind, At = at })
end

-- a downed buddy that nobody revived (or was left behind): out for this run, and lost if its owner faints
local function fall(site, b)
	if b.Fallen then return end
	b.Fallen = true
	b.Downed = false
	b.Cfg:SetAttribute("State", "Fainted")
	fireSite(site, "BuddyFallen", { Buddy = b.Cfg:GetAttribute("Id"), Owner = b.Owner.UserId })
	expedition().BuddyFell(b.Owner, b.Dino)
	-- carried back to the rover
	local cfg = b.Cfg
	task.delay(2.5, function()
		if site.Buddies[cfg] == b then site.Buddies[cfg] = nil end
		cfg:Destroy()
	end)
end

local function despawnBuddies(site, player: Player)
	for cfg, b in pairs(site.Buddies) do
		if b.Owner == player then
			if b.Downed then fall(site, b) end
			-- an egg it was carrying for you is set down here, not deleted with it
			if b.CarryEgg and Encounter.PlaceEgg then
				local rec = b.CarryEgg
				b.CarryEgg = nil
				Encounter.PlaceEgg(site, { Species = rec.Species, Rarity = rec.Rarity, KG = rec.KG, FromRack = rec.FromRack, BossEgg = rec.BossEgg }, b.Pos, player.UserId)
			end
			cfg:Destroy()
			site.Buddies[cfg] = nil
		end
	end
end

local function hurtBuddy(site, b, dmg: number)
	if b.Downed or b.Fallen then return end
	b.HP -= dmg
	if b.HP <= 0 then
		b.HP = 0
		b.Downed = true
		b.DownAt = os.clock()
		if b.CarryEgg then
			Encounter.SpillEgg(site, b.CarryEgg, b.Pos)
			b.CarryEgg = nil
			b.Cfg:SetAttribute("CarryEgg", nil)
		end
		b.Cfg:SetAttribute("State", "Downed")
		fireSite(site, "BuddyDown", { Buddy = b.Cfg:GetAttribute("Id"), Owner = b.Owner.UserId, Name = b.Cfg:GetAttribute("Name"), Time = Config.Buddy.Bleed })
	end
	b.Cfg:SetAttribute("HP", math.floor(b.HP))
end

-- you fainted: whoever's still lying downed can't be helped now
function Encounter.FallDowned(player: Player)
	for _, site in pairs(sites) do
		for _, b in pairs(site.Buddies) do
			if b.Owner == player and b.Downed then fall(site, b) end
		end
	end
end

-- (defined further down, used by Leave: a won boss den's eggs, and rack eggs you took off at a nest)
local claimBossEggs, returnRackEggs, upgradeEgg

function Encounter.Join(player: Player, site)
	if playerSite[player] then Encounter.Leave(player) end
	local profile = Data.Peek(player)
	if not profile then return false end
	local hp = maxHP(profile)
	site.Players[player] = { HP = hp, MaxHP = hp, Downed = false, Invuln = 0, Combo = 0, ComboT = 0, NextDart = 0, Contribution = 0, Carried = {}, Gadgets = {}, Joined = os.clock() }
	-- your very first fight (the scripted Horn Meadow Triceratops): its hits sting, so you learn to dodge - but you
	-- can't go down in it (a guaranteed win)
	if site.Def and site.Def.Id == "HornNest" and (profile.Stats.Runs or 0) == 0 then site.Players[player].FirstFight = true end
	site.Count += 1
	playerSite[player] = site
	player:SetAttribute("Site", site.Key)
	player:SetAttribute("Launcher", profile.Gear.Launcher) -- other clients build the right launcher in your hand
	setHP(site.Players[player], player)
	if site.State == "Idle" or site.State == "Cooldown" then
		if site.State == "Cooldown" and not site.Boss then
			-- someone arrives while it was resetting: a fresh nest and fresh dinos
			removeActors(site)
			for _, e in pairs(site.Eggs) do e.Cfg:Destroy() end
			table.clear(site.Eggs)
			site.EggsMade = 0
			site.Takedown, site.Enraged = nil, nil
		end
		site.State = "Active"
		site.Started = os.clock()
		site.Alarm = false
		if #site.Actors == 0 and site.Def.Kind ~= "Boss" then spawnResidents(site) end
		-- the dinos hold still through the signature intro (the client says when it's done or skipped)
		for _, a in ipairs(site.Actors) do a.NextAttack = os.clock() + 10 end
	end
	if Encounter.FillNest then Encounter.FillNest(site) end
	spawnBuddies(site, player)
	publishSite(site)
	return true
end

function Encounter.Leave(player: Player)
	player:SetAttribute("RiderTook", nil) -- (clients hide a nest's eggs once a rider's had theirs: EncounterView)
	local site = playerSite[player]
	if not site then return end
	local st0 = site.Players[player]
	if st0 and st0.Holding and Encounter.DropHeld then Encounter.DropHeld(site, player) end
	if st0 and st0.Key then Net.Fire(player, "KeyLost", { Id = st0.Key.Id }) end
	playerSite[player] = nil
	site.Players[player] = nil
	site.Count = math.max(0, site.Count - 1)
	-- (someone everyone was waiting on left mid-intro)
	if site.IntroPending and site.IntroPending[player] then Encounter.IntroFinished(site, player) end
	despawnBuddies(site, player)
	-- what's yours comes with you (after everything you or your companion carried has been set down, flags and all):
	-- a won boss den's egg, and eggs you took off your own rack (back on, if there's room)
	claimBossEggs(site, player, nil)
	returnRackEggs(site, player, nil)
	player:SetAttribute("Site", nil)
	player:SetAttribute("HP", nil)
	player:SetAttribute("Downed", nil)
	player:SetAttribute("SpeedBuff", nil)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = Config.Player.WalkSpeed end
	if site.Count == 0 and (site.State == "Active" or site.State == "Scramble") and not site.Boss then
		-- everyone left mid-fight: the dinos settle back down
		site.State = "Cooldown"
		site.Until = os.clock() + 4
	end
	publishSite(site)
end

-- an intro cutscene everyone at the site is watching (the spotted signature, a boss reveal): the dinos stay frozen
-- until EVERY hunter who was there has finished or skipped it (one player skipping used to unleash the boss on
-- teammates still in their cutscene) - with the 30 s cap as the backstop
function Encounter.HoldForIntro(site, source)
	site.IntroPending = {}
	for plr in pairs(site.Players) do site.IntroPending[plr] = true end
	-- caught up close: when the scene's over, the dino that charged you in it really hits you - you're thrown back
	-- and hurt (sneak in carelessly and it costs you; from a distance it doesn't)
	site.CaughtNear = nil
	if source and source.Pos then
		local reach = 12 + (source.Scale or 1) * 4
		for plr in pairs(site.Players) do
			local h = hrpOf(plr)
			if h and flat(h.Position - source.Pos).Magnitude < reach then
				site.CaughtNear = site.CaughtNear or {}
				site.CaughtNear[plr] = { From = source.Pos, Actor = source.Id }
			end
		end
	end
end
-- the hit you took in the cutscene, landing for real the moment it ends (never a knockout: a scene can't down you)
local function caughtHit(site, player: Player)
	local c = site.CaughtNear and site.CaughtNear[player]
	if not c then return end
	site.CaughtNear[player] = nil
	local st = site.Players[player]
	if not st or st.Downed then return end
	st.HP = math.max(st.MaxHP * 0.1, st.HP - st.MaxHP * 0.15)
	setHP(st, player)
	Net.Fire(player, "PlayerHit", { Damage = st.MaxHP * 0.15, HP = st.HP, Kind = "Caught" })
	Net.Fire(player, "Knockback", { From = knockFrom(site, player, c.From), Force = 46, Up = 30, Caught = true })
end
function Encounter.IntroFinished(site, player: Player?)
	if site.IntroPending then
		if player then site.IntroPending[player] = nil end
		for plr in pairs(site.IntroPending) do
			if not (plr.Parent and site.Players[plr]) then site.IntroPending[plr] = nil end
		end
		if next(site.IntroPending) then return end
		site.IntroPending = nil
	end
	-- a breath after the cutscene before anything swings: you get your bearings first
	local soon = os.clock() + 1.6
	for _, a in ipairs(site.Actors) do if a.NextAttack > soon then a.NextAttack = soon end end
	if (site.FreezeUntil or 0) > os.clock() + 0.6 then site.FreezeUntil = os.clock() + 0.6 end
end

function Encounter.SiteOf(player: Player)
	return playerSite[player]
end

--------------------------------------------------------------------------------
-- damage to players
--------------------------------------------------------------------------------
-- difficulty comes from YOUR power vs the fight's recommended power (a site's Power, a ruler's Power x its tier):
-- well under = really hard (you hit soft, it hits hard), at it = a fair fight, well over = easy
local function recommendedPower(site): number?
	if site.Boss and site.BossId and Config.Bosses[site.BossId] then
		return Config.Bosses[site.BossId].Power * ((site.TierInfo and site.TierInfo.Power) or 1)
	end
	return site.Def and site.Def.Power or nil
end
local powerCache = {} :: { [Player]: { P: number, At: number } }
local function powerOf(player: Player): number?
	local c = powerCache[player]
	if c and os.clock() < c.At then return c.P end
	local profile = Data.Peek(player)
	if not profile then return nil end
	local p = Config.PowerOf(profile, Dinos.BuddyList(profile)) -- (gear + companions + the power trainer's TrainPower)
	powerCache[player] = { P = p, At = os.clock() + 8 }
	return p
end
-- returns (damage you take x, calm you deal x)
local function powerMults(site, player: Player): (number, number)
	local rec, mine = recommendedPower(site), powerOf(player)
	if not rec or rec <= 0 or not mine then return 1, 1 end
	local r = mine / rec
	if r < 1 then return 1 + (1 - r) * 1.8, math.max(0.25, r ^ 1.4) end
	return math.max(0.4, 1 - (r - 1) * 0.55), math.min(2.2, 1 + (r - 1) * 0.7)
end
Encounter.PowerMults = powerMults

local function hurt(site, player: Player, dmg: number, kind: string)
	local st = site.Players[player]
	if not st or st.Downed then return false end
	local now = os.clock()
	if now < st.Invuln then
		-- rolled THROUGH the hit: a perfect dodge refunds the roll and charges the next dart
		if now < (st.DodgeUntil or 0) and now - (st.PerfectAt or 0) > 0.5 then
			st.PerfectAt = now
			-- (a quicker next roll, not a free one: chained perfect dodges used to skip the cooldown entirely)
			st.NextDodge = math.min(st.NextDodge or now, now + (Config.Player.PerfectRefund or 0.5))
			st.Charged = true
			st.ReloadUntil = 0 -- and a fresh magazine
			st.Mag = nil
			Net.Fire(player, "PerfectDodge", { Kind = kind })
		end
		return false
	end
	st.HP -= dmg * (site.DamageMult or 1) * (powerMults(site, player)) * (st.FirstFight and (E.FirstFightHurt or 1) or 1)
	if st.FirstFight and st.HP < st.MaxHP * 0.12 then st.HP = st.MaxHP * 0.12 end -- (never down in your first fight)
	st.Combo = 0
	-- a hard knock (a fifth of your health in one go) shakes the egg out of your arms - relative, so it's the same
	-- in every era (a flat 20 meant every scaled-up nip from Giant Plains on dropped it)
	if st.Holding and dmg * (site.DamageMult or 1) >= st.MaxHP * 0.2 and Encounter.DropHeld then Encounter.DropHeld(site, player) end
	if st.HP <= 0 then
		st.HP = 0
		st.Downed = true
		st.DownAt = os.clock()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = 4 end
		fireSite(site, "Downed", { UserId = player.UserId, Name = player.DisplayName, Time = Config.Player.DownedTime })
		-- dropped eggs you were carrying on foot fall back in the scramble
		for _, egg in ipairs(st.Carried) do Encounter.SpillEgg(site, egg, hrpOf(player) and (hrpOf(player) :: BasePart).Position or site.Center) end
		table.clear(st.Carried)
		if site.Boss then site.RevivePool = (site.RevivePool or 0) end
	end
	setHP(st, player)
	Net.Fire(player, "PlayerHit", { Damage = dmg, HP = st.HP, Kind = kind })
	return true
end

local function revive(site, player: Player, hpFrac: number)
	local st = site.Players[player]
	if not st then return end
	st.Downed = false
	st.HP = st.MaxHP * hpFrac
	st.Invuln = os.clock() + 1.5
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = Config.Player.WalkSpeed end
	setHP(st, player)
	fireSite(site, "Revived", { UserId = player.UserId })
end

--------------------------------------------------------------------------------
-- attack shapes
--------------------------------------------------------------------------------
local function inShape(shape, p: Vector3): boolean
	local o = shape.O
	-- "Reach" attacks (the answer to camping on a rock) hit at any height
	if not shape.Reach and math.abs(p.Y - o.Y) > 10 then return false end
	local d = flat(p - o)
	if shape.Shape == "Circle" then return d.Magnitude <= shape.R end
	if shape.Shape == "Ring" then return d.Magnitude <= shape.R and d.Magnitude >= (shape.Inner or 0) end
	local dir = shape.Dir
	if shape.Shape == "Line" then
		local along = d:Dot(dir)
		local perp = (d - dir * along).Magnitude
		return along >= -2 and along <= shape.Len and perp <= shape.Width / 2
	end
	if shape.Shape == "Cone" then
		if d.Magnitude > shape.Len then return false end
		if d.Magnitude < 2 then return true end
		return math.deg(math.acos(math.clamp(d.Unit:Dot(dir), -1, 1))) <= shape.Angle / 2
	end
	return false
end

local function makeShape(a, atk, target: Vector3)
	local to = flat(target - a.Pos)
	local dir = to.Magnitude > 0.1 and to.Unit or dirOf(a.Yaw)
	-- a tail attack sweeps BEHIND the body (it punishes whoever's sneaking round the back), whatever it's facing
	if atk.Back then dir = -dirOf(a.Yaw) end
	local o = a.Pos
	if atk.AtTarget then o = Vector3.new(target.X, a.Pos.Y, target.Z) end
	return {
		Shape = atk.Shape, O = o, Dir = dir, Len = atk.Len, Width = atk.Width, R = atk.Radius, Inner = atk.Inner,
		Angle = atk.Angle, Id = atk.Id, Dmg = atk.Dmg * (a.DmgMult or 1), Dash = atk.Dash, Tele = atk.Tele, Stun = atk.Stun, Reach = atk.Reach,
		Snatch = atk.Snatch, Steal = atk.Steal,
	}
end

--------------------------------------------------------------------------------
-- the brain: one tick per site
--------------------------------------------------------------------------------
local function alivePlayers(site)
	local list = {}
	for plr, st in pairs(site.Players) do
		local hrp = hrpOf(plr)
		if hrp and not st.Downed then table.insert(list, { P = plr, Pos = hrp.Position, St = st }) end
	end
	return list
end

local function nearest(list, p: Vector3)
	local best, bd = nil, math.huge
	for _, e in ipairs(list) do
		local d = flat(e.Pos - p).Magnitude
		if d < bd then best, bd = e, d end
	end
	return best, bd
end

-- obstacle sense: dinos feel ahead for rocks, trunks, rovers and walls and steer round them
local obstacleParams = RaycastParams.new()
obstacleParams.FilterType = Enum.RaycastFilterType.Exclude
obstacleParams.RespectCanCollide = true
local function obstacleFilter(site)
	if not site.ObstacleEx then
		local ex = {}
		local zm = Workspace:FindFirstChild(site.Era)
		if zm then
			for _, n in ipairs({ "Ground", "Hills", "Swells", "Roads" }) do
				local f = zm:FindFirstChild(n)
				if f then table.insert(ex, f) end
			end
		end
		site.ObstacleEx = ex
	end
	local list = table.clone(site.ObstacleEx)
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(list, plr.Character) end end
	obstacleParams.FilterDescendantsInstances = list
end
local function rotY(v: Vector3, ang: number): Vector3
	local c, sn = math.cos(ang), math.sin(ang)
	return Vector3.new(v.X * c - v.Z * sn, 0, v.X * sn + v.Z * c)
end
local function steer(site, a, d: Vector3): Vector3?
	obstacleFilter(site)
	local probe = 3 + (a.Scale or 1) * 3.2
	local origin = a.Pos + Vector3.new(0, 1.8 + (a.Scale or 1) * 0.6, 0)
	local function clear(dir: Vector3): boolean
		return Workspace:Raycast(origin, dir * probe, obstacleParams) == nil
	end
	if clear(d) then
		if a.AvoidUntil and os.clock() > a.AvoidUntil then a.AvoidSide = nil end
		return d
	end
	local side = a.AvoidSide or (rng:NextNumber() < 0.5 and -1 or 1)
	for _, ang in ipairs({ 35, 65, 95, 130 }) do
		for _, sg in ipairs({ side, -side }) do
			local dd = rotY(d, math.rad(ang * sg))
			if clear(dd) then
				a.AvoidSide = sg -- keep going round the same way for a moment (no jitter)
				a.AvoidUntil = os.clock() + 0.8
				return dd
			end
		end
	end
	return nil -- boxed in: wait
end

-- other sites' dinos and parked rovers are bodies too (2026-10-14, user screenshot after a Tyrant King win: the Horn
-- Nest Triceratops stood inside the knocked-out boss, nose-first in a parked rover). Separation used to be per site
-- only. Now a nest's dinos stay out of a live boss arena (the boss, its body and its nest are there), every dino
-- keeps clear of a neighbouring site's dinos, and nobody walks into a rover
local function keepClear(site, a, np: Vector3, myR: number): Vector3
	local function out(from: Vector3, minD: number, p: Vector3): Vector3
		local away = flat(p - from)
		local dist = away.Magnitude
		if dist >= minD then return p end
		local dir = dist > 0.05 and away.Unit or Vector3.new(math.cos(a.Id), 0, math.sin(a.Id))
		return p + dir * (minD - dist)
	end
	for _, other in pairs(sites) do
		if other == site or other.Era ~= site.Era or not other.Center then continue end
		if flat(other.Center - site.Center).Magnitude > (other.Radius or 44) + (site.Radius or 44) + 40 then continue end
		if other.Boss and not site.Boss and (other.Phase or 0) >= 1 then
			-- (the boss's centre stops at its radius; its body reaches on past it)
			np = out(other.Center, (other.Radius or 40) + myR + 8, np)
		end
		for _, o in ipairs(other.Actors) do
			if not o.Herd and o.State ~= "Hidden" then np = out(o.Pos, myR + 1.6 + (o.Scale or 1) * 2.2, np) end
		end
	end
	if Vehicles then
		for _, plr in ipairs(Players:GetPlayers()) do
			local vr = Vehicles.Root(plr)
			if vr and flat(vr.Position - np).Magnitude < 30 then
				-- the rover's footprint (about 9 x 16), grown by the dino's body: pushed out the short way
				local l = vr.CFrame:PointToObjectSpace(np)
				local hx, hz = 4.5 + myR * 0.8, 8.5 + myR * 0.8
				local px, pz = hx - math.abs(l.X), hz - math.abs(l.Z)
				if px > 0 and pz > 0 then
					if px < pz then l = Vector3.new((l.X >= 0 and 1 or -1) * hx, l.Y, l.Z) else l = Vector3.new(l.X, l.Y, (l.Z >= 0 and 1 or -1) * hz) end
					np = vr.CFrame:PointToWorldSpace(l)
				end
			end
		end
	end
	return np
end

local function moveActor(site, a, toward: Vector3, speed: number, dt: number)
	local d0 = flat(toward - a.Pos)
	if d0.Magnitude < 0.3 then a.Vel = 0 return end
	local dir = steer(site, a, d0.Unit)
	if not dir then a.Vel = 0 return end
	-- room to move: the others in the fight are bodies too (a pack spreads out instead of stacking in one spot)
	local push = Vector3.zero
	local myR = 1.6 + (a.Scale or 1) * 2.2
	for _, o in ipairs(site.Actors) do
		if o ~= a and not o.Custom then
			local away = flat(a.Pos - o.Pos)
			local minD = myR + 1.6 + (o.Scale or 1) * 2.2
			local dist = away.Magnitude
			if dist < minD then
				push += (dist > 0.05 and away.Unit or Vector3.new(math.cos(a.Id), 0, math.sin(a.Id))) * ((minD - dist) / minD)
			end
		end
	end
	if push.Magnitude > 0.01 then
		local mixed = dir + push * 1.4
		if mixed.Magnitude > 0.05 then dir = mixed.Unit end
	end
	local d = dir * d0.Magnitude
	-- it gets going and slows down like a body with weight (no instant full speed, no dead stops)
	local accel = 70 / math.max(1, (a.Scale or 1) * 0.8)
	local v = a.Vel or 0
	v = v < speed and math.min(speed, v + accel * dt) or math.max(speed, v - accel * 1.5 * dt)
	a.Vel = v
	local step = math.min(d0.Magnitude, v * dt)
	local np = a.Pos + dir * step
	-- stay in the arena
	local fromC = flat(np - site.Center)
	if fromC.Magnitude > site.Radius then np = site.Center + fromC.Unit * site.Radius + Vector3.new(0, np.Y - site.Center.Y, 0) end
	np = keepClear(site, a, np, myR)
	np = Vector3.new(np.X, groundY(site, np, site.Center.Y), np.Z)
	a.Pos = np
	a.Yaw = yawOf(d)
end

-- position updates go to every client: at most ~20 a second per actor (boss moves called this every Heartbeat -
-- 60 Hz x 3 attributes x every actor in the move; the clients interpolate between samples anyway). a stop, a
-- jump or a speed change always goes out at once so nothing lands in the wrong spot
local function publishActor(a, v: number)
	local now = os.clock()
	local last = a.PubP
	local jump = last == nil or (a.Pos - last).Magnitude > 10
	if not jump and now < (a.PubAt or 0) and (v == a.PubV or (v ~= 0 and a.PubV ~= 0)) then return end
	a.PubAt, a.PubP, a.PubV = now + 0.05, a.Pos, v
	a.Cfg:SetAttribute("P", a.Pos)
	a.Cfg:SetAttribute("Yaw", a.Yaw)
	a.Cfg:SetAttribute("V", v)
end

local tickActor -- forward

-- how long a lunge / charge takes to cover its lane (the client times its strike animation to this too)
local DASH_TIME = 0.35

-- one attack landing on one hunter: a shield companion in the way takes half, a blinded dino whiffs
local function strikePlayer(site, a, atk, plr: Player, blind: boolean)
	local now = os.clock()
	local hrp = hrpOf(plr)
	if not hrp then return end
	local guard = nil
	for _, b in pairs(site.Buddies) do
		if b.Owner == plr and b.Block and now < b.Block.Until and not b.Downed then
			local toAtk = flat(a.Pos - hrp.Position)
			local toB = flat(b.Pos - hrp.Position)
			if toB.Magnitude < 6 and toAtk.Magnitude > 0.1 and toB.Magnitude > 0.1 and toB.Unit:Dot(toAtk.Unit) > 0.3 then guard = b end
		end
	end
	if blind then
		-- blinded by a spitting buddy: it swings at nothing
		Net.Fire(plr, "BuddyHelp", { Kind = "Miss" })
	elseif guard then
		hurtBuddy(site, guard, atk.Dmg * 0.5 * (site.DamageMult or 1))
		emote(site, guard, "Blocked")
	else
		local landed = hurt(site, plr, atk.Dmg, atk.Id)
		-- the hit that ends a camping spot throws you clear of it
		if landed and atk.Reach then Net.Fire(plr, "Knockback", { From = knockFrom(site, plr, a.Pos), Force = 52, Up = 34 }) end
		-- the Oviraptor's beak snatch: the egg in your arms is out of them - a thief makes off with it
		local held = landed and atk.Snatch and site.Players[plr] and site.Players[plr].Holding
		if held then
			-- (a thief only runs off with a plain nest egg; anything that's yours - off your rack, a boss egg - is just
			-- knocked out of your arms and stays yours on the ground)
			if a.Rival and not a.Carry and not held.BossEgg and not held.FromRack and not held.Owner then
				local pst = site.Players[plr]
				pst.Holding = nil
				plr:SetAttribute("Holding", nil)
				Dinos.ClearHeld(plr)
				a.Carry = { Species = held.Species, Rarity = held.Rarity, KG = held.KG }
				a.Cfg:SetAttribute("CarryEgg", held.Species)
			elseif Encounter.DropHeld then
				Encounter.DropHeld(site, plr)
			end
		end
		-- a Compy snatches darts right out of your magazine
		local pst = site.Players[plr]
		if atk.Steal and pst and pst.Mag and pst.Mag > 1 then
			pst.Mag = math.max(1, pst.Mag - atk.Steal)
			Net.Fire(plr, "BuddyHelp", { Kind = "Steal", Mag = pst.Mag })
		end
	end
end

-- can a dino see a point? (anything solid or leafy in between hides you: ferns and bushes are cover)
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.RespectCanCollide = false
local function canSee(site, a, p: Vector3): boolean
	local list = { ChaserFolder, EggFolder }
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(list, plr.Character) end end
	sightParams.FilterDescendantsInstances = list
	local eye = a.Pos + Vector3.new(0, 2.5 * (a.Scale or 1), 0)
	local to = p + Vector3.new(0, 1.5, 0) - eye
	return Workspace:Raycast(eye, to * 0.97, sightParams) == nil
end

-- can a dart get from the muzzle to the dino? only solid (collidable) things block: leaves and ferns don't.
-- two aim points (chest and head) so a bump in the ground doesn't eat a fair shot
local shotParams = RaycastParams.new()
shotParams.FilterType = Enum.RaycastFilterType.Exclude
shotParams.RespectCanCollide = true
shotParams.IgnoreWater = true
local function clearShot(from: Vector3, a): (boolean, Vector3?)
	local list: { Instance } = { ChaserFolder, EggFolder }
	local veh = Workspace:FindFirstChild("ActiveVehicles")
	if veh then table.insert(list, veh) end
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(list, plr.Character) end end
	shotParams.FilterDescendantsInstances = list
	local s = a.Scale or 1
	-- (all the way to its hide: the old ray stopped 10% short, so a wall right in front of the dino never counted)
	local body = 1.2 * s
	local first: Vector3? = nil
	for _, h in ipairs({ 1.4 * s, 3.2 * s }) do
		local to = a.Pos + Vector3.new(0, h, 0) - from
		local len = math.max(0, to.Magnitude - body)
		if len < 0.5 then return true, nil end
		local hit = Workspace:Raycast(from, to.Unit * len, shotParams)
		if not hit then return true, nil end
		first = first or hit.Position
	end
	return false, first
end

function Encounter.Alarm(site, player: Player?, by)
	if site.Alarm then return end
	site.Alarm = true
	for _, b in pairs(site.Buddies) do
		if b.Under then
			-- the game's up: it runs back to you. Family forgives; the ones it tricked are cross with it
			if b.Under == "Inside" then
				for _, x in ipairs(site.Actors) do
					if flat(x.Pos - b.Pos).Magnitude < 16 then x.FocusBuddy = b x.FocusUntil = os.clock() + 34 end
				end
			end
			b.Under = nil
			b.Chatting = nil
		end
	end
	for _, x in ipairs(site.Actors) do
		x.Aware = 1
		x.Cfg:SetAttribute("Aware", 1)
		x.Cfg:SetAttribute("Sus", nil)
		if x.State == "Unaware" or x.State == "Idle" then setState(x, "Chase") end
		x.NextAttack = os.clock() + 30 -- held until the spotted cutscene says it's done (IntroDone); 30 s is only a safety cap
	end
	site.FreezeUntil = os.clock() + 30
	Encounter.HoldForIntro(site, by and by.Pos and by or nil)
	fireSite(site, "Spotted", { Actor = by and by.Id, UserId = player and player.UserId, Name = player and player.DisplayName, Species = site.Def.Species })
	publishSite(site)
end

local function sneakTick(site, a, dt: number, players)
	local now = os.clock()
	local S = E.Sneak
	-- grazing: amble between spots near home, pausing to eat and look around
	if not a.WanderTo or flat(a.WanderTo - a.Pos).Magnitude < 1 or now > (a.WanderUntil or 0) then
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(2, 7)
		local to = a.Home + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		-- graze around the nest, never standing on it (the eggs have to be reachable, and it looks wrong)
		local off = flat(to - site.Center)
		local keep = 6 + (a.Scale or 1) * 3.4
		if off.Magnitude < keep then
			off = off.Magnitude > 0.1 and off.Unit or Vector3.new(math.cos(ang), 0, math.sin(ang))
			to = Vector3.new(site.Center.X, to.Y, site.Center.Z) + off * keep
		end
		a.WanderTo = to
		a.WanderUntil = now + rng:NextNumber(5, 9)
		a.PauseUntil = now + rng:NextNumber(1.5, 4)
	end
	local focus, maxGain = nil, 0
	if now >= a.NextAttack then -- not during the intro
		for _, e in ipairs(players) do
			local d = flat(e.Pos - a.Pos).Magnitude
			local hrp = hrpOf(e.P)
			local speed = hrp and flat(hrp.AssemblyLinearVelocity).Magnitude or 0
			local gain = 0
			-- noise: sprinting carries, walking up close too; sneaking is silent unless you bump into it
			-- distances are from its body, not its middle: a Triceratops is ten studs long
			local body = 2 + (a.Scale or 1) * 3.4
			-- a parent knows the smell of its own egg: carrying one is loud and easy to spot
			local st = site.Players[e.P]
			local carrying = st ~= nil and st.Holding ~= nil and not st.Holding.Gift
			local mood = site.Mood or E.Moods[1]
			if carrying and d < S.WalkHear + body + 14 then gain += 0.45 * mood.Hear * (1 - d / (S.WalkHear + body + 14)) end
			if d < body + 1.5 then gain += 6 -- walked right into it
			elseif speed > 19 and d < S.SprintHear * mood.Hear then gain += S.SprintRate * (1 - d / (S.SprintHear * mood.Hear)) + 0.5
			elseif speed > 12.5 and d < (S.WalkHear + body) * mood.Hear then gain += 0.55 * (1 - d / ((S.WalkHear + body) * mood.Hear))
			elseif d < body + 4.5 then gain += 0.9 end
			-- sight: a cone in front, with line of sight; closer is faster, holding still halves it
			local range = S.SightRange * (0.85 + (a.Scale or 1) * 0.15) * (0.8 + mood.Sight * 0.2)
			if d < range then
				local to = flat(e.Pos - a.Pos)
				local fwd = dirOf(a.Yaw)
				local ang = to.Magnitude > 0.1 and math.deg(math.acos(math.clamp(to.Unit:Dot(fwd), -1, 1))) or 0
				if ang < S.SightAngle / 2 and canSee(site, a, e.Pos) then
					gain += S.SightRate * mood.Sight * (1 - d / range) * (speed < 2 and 0.5 or 1) * (carrying and 1.8 or 1)
				end
			end
			if gain > maxGain then maxGain, focus = gain, e end
		end
	end
	-- a companion chatting with it (undercover): it's far too busy to notice you
	local charm = nil
	for _, b in pairs(site.Buddies) do
		if b.Chatting and b.Under and not b.Downed and flat(b.Pos - a.Pos).Magnitude < 15 then charm = b break end
	end
	if charm then maxGain *= (charm.Under == "Reunion" and 0.15 or 0.3) end
	-- a camouflaged buddy at your heels hides you too
	if focus and maxGain > 0 then
		for cfg, b in pairs(site.Buddies) do
			if b.Owner == focus.P and not b.Downed and not b.Fallen then
				local r = Config.BuddyRoleOf(cfg:GetAttribute("Species") or "")
				if r.Camo then maxGain *= r.Camo break end
			end
		end
	end
	local before = a.Aware
	if maxGain > 0 then a.Aware = math.min(1, a.Aware + maxGain * dt) else a.Aware = math.max(0, a.Aware - S.Decay * dt) end
	-- lookout: about to be spotted - your companion warns you ("!")
	if focus and before < 0.55 and a.Aware >= 0.55 and now > (a.LookoutAt or 0) then
		a.LookoutAt = now + 6
		for _, b in pairs(site.Buddies) do
			if b.Owner == focus.P and not b.Downed and not b.Fallen and not b.Chatting then emote(site, b, "Alert", a.Pos) break end
		end
	end
	if charm and a.Aware < 0.35 then
		-- they turn to the visitor and stay put
		a.Yaw = yawOf(flat(charm.Pos - a.Pos))
		a.PauseUntil = math.max(a.PauseUntil or 0, now + 0.5)
	end
	local shown = math.floor(a.Aware * 20) / 20
	if a.Cfg:GetAttribute("Aware") ~= shown then a.Cfg:SetAttribute("Aware", shown) end
	if a.Aware >= 1 and focus then Encounter.Alarm(site, focus.P, a) return end
	-- suspicious: stops and stares at what it noticed
	if focus and a.Aware > 0.35 then
		a.Yaw = yawOf(flat(focus.Pos - a.Pos))
		if not a.Cfg:GetAttribute("Sus") then a.Cfg:SetAttribute("Sus", true) end
		publishActor(a, 0)
		return
	end
	if a.Cfg:GetAttribute("Sus") then a.Cfg:SetAttribute("Sus", nil) end
	-- up on its perch: it stays there, looking round now and then
	if a.Perched then
		if now >= (a.PauseUntil or 0) then a.PauseUntil = now + rng:NextNumber(2, 4) a.Yaw += rng:NextNumber(-1.2, 1.2) end
		publishActor(a, 0)
		return
	end
	-- a rival thief doesn't graze: it's here for the eggs (tickActor moves it)
	if a.Rival then return end
	if now < (a.PauseUntil or 0) then publishActor(a, 0) return end
	moveActor(site, a, a.WanderTo, a.Speed * 0.22, dt)
	publishActor(a, a.Speed * 0.22)
end

-- can a distraction (a ball, meat bait, a honk, a terror roar) pull it off what it's doing? Never a boss, a
-- scripted runner, or one that's out cold, being ridden, or waiting for its rider
local function swayable(a): boolean
	return not a.Boss and not a.Custom and a.State ~= "KO" and a.State ~= "Exhausted" and a.State ~= "Rodeo"
end
-- can darts / companions hit it right now? (the client's FIGHTABLE list, enforced here too)
local UNTARGETABLE = { KO = true, Hidden = true, Burrow = true, Stalk = true, Herd = true, Charge = true, Rodeo = true, Exhausted = true }
local function targetable(a): boolean
	return not UNTARGETABLE[a.State or ""] and not a.Herd
end
Encounter.Targetable = targetable

-- carpool: riding along in someone else's rover (no run, rack or rover of your own - your eggs go to your bag)
local function isRider(player: Player): boolean
	return Expedition ~= nil and Expedition.RiderRun ~= nil and Expedition.Get(player) == nil and Expedition.RiderRun(player) ~= nil
end
local function bagEgg(player: Player, rec, force: boolean?): boolean
	local profile = Data.Peek(player)
	if not profile then return false end
	-- (force: a boss egg always fits - it's never lost to a full bag)
	local e = Dinos.AddEgg(player, rec.Species, rec.Rarity, rec.Luck or 0, rec.KG, force == true)
	if not e then return false end
	Data.Changed(player)
	return true
end
Encounter.IsRider = isRider

-- RIVAL thieves: sneak to the nearest free egg, pick it up and run back to the edge with it; get there and it's
-- gone for good. A dart (any calm) makes it drop the egg (Encounter.Calm)
local function rivalTick(site, a, dt: number)
	local now = os.clock()
	if a.Carry then
		if a.State ~= "Chase" and a.State ~= "Unaware" then setState(a, "Chase") end -- (running: no weak spot open)
		if flat(a.Home - a.Pos).Magnitude < 3 then
			a.Carry = nil
			a.Cfg:SetAttribute("CarryEgg", nil)
			a.RivalAt = now + rng:NextNumber(4, 7)
			publishActor(a, 0)
			return
		end
		moveActor(site, a, a.Home, a.Speed * 0.75, dt)
		publishActor(a, a.Speed * 0.75)
		return
	end
	if now < (a.RivalAt or 0) then publishActor(a, 0) return end
	local best, bid, bd = nil, nil, math.huge
	for id, e in pairs(site.Eggs) do
		if not e.Owner and not e.BossEgg then
			local d = flat(e.Pos - a.Pos).Magnitude
			if d < bd then best, bid, bd = e, id, d end
		end
	end
	if not best then publishActor(a, 0) return end
	if bd < 2.6 then
		site.Eggs[bid] = nil
		best.Cfg:Destroy()
		a.Carry = { Species = best.Species, Rarity = best.Rarity, KG = best.KG, Luck = best.Luck }
		a.Cfg:SetAttribute("CarryEgg", best.Species)
		publishSite(site)
		return
	end
	moveActor(site, a, best.Pos, a.Speed * 0.4, dt) -- (it sneaks in, like you)
	publishActor(a, a.Speed * 0.4)
end
-- a thief that gets hit (or knocked out) drops what it's carrying
local function dropCarry(site, a)
	if not a.Carry then return end
	local egg = a.Carry
	a.Carry = nil
	a.Cfg:SetAttribute("CarryEgg", nil)
	Encounter.SpillEgg(site, egg, a.Pos)
end

tickActor = function(site, a, dt: number, players)
	a.T += dt
	local now = os.clock()
	local st = a.State
	-- (the rodeo watchdog runs even for a scripted boss: the sea boss stays Custom for its whole fight, and a rider
	-- who left mid-ride used to leave it stuck in Rodeo forever)
	if st == "Rodeo" then
		-- the rider left, dropped, or its result never came: it shakes them off (2026-10-12: it stayed in Rodeo
		-- for good - untouchable, and the site could never be taken down)
		local rider = a.Rider
		if now - (a.RodeoAt or now) > E.RodeoTime + 3 or not (rider and rider.Parent and site.Players[rider]) then
			a.Rider = nil
			a.Calm = a.CalmMax * E.RodeoFailCalm
			a.Cfg:SetAttribute("Calm", a.Calm)
			setState(a, "Chase")
			a.NextAttack = now + 1.2
			fireSite(site, "RodeoEnd", { Actor = a.Id, Success = false, UserId = rider and rider.UserId or 0 })
			publishSite(site)
		end
		return
	end
	if a.Custom then return end -- a boss script is moving it (perches, leaps, phase changes)
	if st == "KO" then return end
	if st == "Exhausted" then
		-- rodeo window: it stands panting; if nobody jumps on, it recovers (nothing stuns it out of this window)
		a.StunUntil = 0
		if a.T > 7 then a.Calm = a.CalmMax * E.RodeoFailCalm a.Cfg:SetAttribute("Calm", a.Calm) a.Cfg:SetAttribute("RodeoOpen", nil) setState(a, "Chase") end
		publishActor(a, 0)
		return
	end
	if now < a.StunUntil then
		if st ~= "Stunned" then setState(a, "Stunned") end
		publishActor(a, 0)
		return
	elseif st == "Stunned" then
		if a.ClimbAt then a.ClimbAt = nil end
		setState(a, "Chase")
	end
	if st == "Distracted" then
		if a.Bait then moveActor(site, a, a.Bait, a.Speed * 0.8, dt) end
		if now > (a.DistractUntil or 0) then
			a.Bait = nil
			-- a calm one that wandered over to sniff a ball just goes back to grazing
			setState(a, (a.AfterDistract and not site.Alarm) and a.AfterDistract or "Chase")
			a.AfterDistract = nil
		end
		publishActor(a, a.Speed * 0.8)
		return
	end
	if site.State == "Idle" or site.Count == 0 then
		local rest = (site.Boss or site.Alarm) and "Idle" or "Unaware"
		if st ~= rest then setState(a, rest) end
		publishActor(a, 0)
		return
	end
	if st == "Unaware" then
		if site.Alarm then
			setState(a, "Chase")
		else
			sneakTick(site, a, dt, players)
			if a.Rival and a.State == "Unaware" then rivalTick(site, a, dt) end
			return
		end
	end
	-- a thief with an egg keeps running for the edge, fight or no fight (stop it with a dart)
	if a.Rival and a.Carry and st ~= "Telegraph" and st ~= "Attack" then rivalTick(site, a, dt) return end
	-- frozen while the spotted cutscene plays (they turn to face you, nothing more)
	if os.clock() < (site.FreezeUntil or 0) then
		local tgt = nearest(players, a.Pos)
		if tgt then a.Yaw = yawOf(flat(tgt.Pos - a.Pos)) end
		publishActor(a, 0)
		return
	end
	local target, dist = nearest(players, a.Pos)
	-- a buddy that keeps biting it: it turns on the buddy for a few seconds
	local fb = a.FocusBuddy
	if fb and (fb.Downed or fb.Fallen or now > (a.FocusUntil or 0) or not site.Buddies[fb.Cfg]) then a.FocusBuddy = nil fb = nil end
	if fb and target then target, dist = { Pos = fb.Pos, Buddy = fb }, flat(fb.Pos - a.Pos).Magnitude end
	if not target then
		if st ~= "Idle" then setState(a, "Idle") end
		publishActor(a, 0)
		return
	end
	if st == "Idle" then
		-- notices you when you get close, when it's hit, or when the alarm goes off
		if (dist < 34 and now > a.NextAttack) or site.Alarm or a.Calm > 0 or now > a.NextAttack + 4 then setState(a, "Chase") end
		publishActor(a, 0)
		return
	end
	if st == "Telegraph" then
		local atk = a.Attack
		if a.T >= atk.Tele then
			setState(a, "Attack")
			if atk.Dash then a.DashFrom = a.Pos a.DashTo = atk.O + atk.Dir * atk.Len * 0.92 end
			if atk.Id == "ShakeOff" or atk.Id == "Leap" then
				-- it slams into the rock under you (dash to the foot of it), or leaps over what's in its way onto you
				local to = flat(atk.O - a.Pos)
				a.Attack.Dash = true
				a.Attack.Len = math.max(0, to.Magnitude - (atk.Id == "Leap" and 1.5 or 3))
				a.DashFrom = a.Pos
				a.DashTo = a.Pos + (to.Magnitude > 0.1 and to.Unit or Vector3.zero) * a.Attack.Len
				-- (a long one takes real time: crossing 60 studs in a third of a second read as a teleport)
				a.DashDur = math.clamp(a.Attack.Len / 40, DASH_TIME, 1.1)
			end
			-- every dash ends inside the arena (a leap or a ram at someone outside it used to carry a boss out, where
			-- nobody could fight it)
			if a.DashTo then
				local off = flat(a.DashTo - site.Center)
				local maxR = (site.Radius or 44) - 2
				if off.Magnitude > maxR then a.DashTo = site.Center + off.Unit * maxR + Vector3.new(0, a.DashTo.Y - site.Center.Y, 0) end
			end
			-- a lunge or a charge hits you when its body GETS to you (not the moment it sets off): the further down the
			-- lane you are, the later it lands - and the longer you have to roll out of the lane
			local blind = (a.BlindLeft or 0) > 0
			local function arrival(p: Vector3): number
				if atk.Id == "ShakeOff" or atk.Id == "Leap" then return (a.DashDur or DASH_TIME) * 0.85 end -- (it lands when it reaches the rock / you)
				if not (atk.Dash and a.DashTo and atk.Dir and (atk.Len or 0) > 1) then return 0 end
				local along = math.clamp(flat(p - atk.O):Dot(atk.Dir) / atk.Len, 0, 1) * 0.92
				return DASH_TIME * (1 - math.sqrt(1 - along)) -- (the dash eases out: it covers the near lane fastest)
			end
			local function later(delay: number, fn: () -> ())
				if delay <= 0.03 then fn() return end
				task.delay(delay, function()
					if a.Cfg.Parent and a.State ~= "KO" and a.Attack == atk then fn() end
				end)
			end
			for plr in pairs(site.Players) do
				local hrp = hrpOf(plr)
				if hrp and inShape(atk, hrp.Position) then
					later(arrival(hrp.Position), function()
						-- still in its path when it gets there? (rolled clear = missed)
						local h2 = hrpOf(plr)
						if not (h2 and site.Players[plr] and inShape(atk, h2.Position)) then return end
						strikePlayer(site, a, atk, plr, blind)
					end)
				end
			end
			if blind then a.BlindLeft -= 1 end
			-- buddies standing in it get hit too
			for _, b in pairs(site.Buddies) do
				if not b.Downed and not b.Fallen and inShape(atk, b.Pos) then
					later(arrival(b.Pos), function()
						if site.Buddies[b.Cfg] == b and not b.Downed and not b.Fallen and inShape(atk, b.Pos) then hurtBuddy(site, b, atk.Dmg * (site.DamageMult or 1)) end
					end)
				end
			end
			-- parked rovers caught in it take a dent too (60%: it's armoured)
			for plr in pairs(site.Players) do
				local vr = Vehicles and Vehicles.Root(plr)
				if vr and inShape(atk, vr.Position) and Expedition and Expedition.HurtParked then
					later(arrival(vr.Position), function()
						if not site.Players[plr] then return end -- (drove off in the meantime)
						Expedition.HurtParked(plr, atk.Dmg * 0.6 * (site.DamageMult or 1), atk.Id)
					end)
				end
			end
			fireSite(site, "Strike", { Actor = a.Id, Id = atk.Id, Dash = atk.Dash and (a.DashDur or DASH_TIME) or nil })
		end
		publishActor(a, 0)
		return
	end
	if st == "Attack" then
		local atk = a.Attack
		if atk.Dash and a.DashTo then
			-- the lunge: explodes off the mark and digs in at the end (ease out)
			local dd = a.DashDur or DASH_TIME
			local u = math.clamp(a.T / dd, 0, 1)
			local e = 1 - (1 - u) * (1 - u)
			local p = a.DashFrom:Lerp(a.DashTo, e)
			local y = groundY(site, p, site.Center.Y)
			if a.GlideFromY then y = a.GlideFromY + (y - a.GlideFromY) * e -- (gliding down off its perch)
			elseif atk.Id == "Leap" then y += math.sin(u * math.pi) * 7 end -- (a leap arcs over what's in the way)
			a.Pos = Vector3.new(p.X, y, p.Z)
			publishActor(a, atk.Len / dd)
		else
			publishActor(a, 0)
		end
		if a.T >= (atk.Dash and (a.DashDur or DASH_TIME) + 0.08 or 0.3) then
			a.GlideFromY = nil
			local alone = true
			for _, o in ipairs(site.Actors) do if o ~= a and o.State ~= "KO" and not o.Buddy then alone = false break end end
			local chain = math.max(alone and (E.ChainLone or 0) or 0, a.Enraged and (E.ChainEnraged or 0.4) or 0, a.Boss and E.BossPace and E.BossPace.Chain or 0)
			if not a.ChainedLast and chain > 0 and rng:NextNumber() < chain then
				-- a follow-up: no opening this time, keep dodging
				a.ChainedLast = true
				a.NextAttack = now
				setState(a, "Chase")
			else
				a.ChainedLast = false
				-- recovering: the glowing weak spot is open
				setState(a, "Recover")
				a.Cfg:SetAttribute("Weak", true)
			end
		end
		return
	end
	if st == "Recover" then
		publishActor(a, 0)
		if a.T >= (a.Stats.Recover or 1.3) * (E.RecoverMult or 1) * (a.Boss and E.BossPace and E.BossPace.Recover or 1) then
			a.Cfg:SetAttribute("Weak", nil)
			local alone = true
			for _, o in ipairs(site.Actors) do if o ~= a and o.State ~= "KO" and not o.Buddy then alone = false break end end
			a.NextAttack = now + rng:NextNumber(a.Stats.Gap[1], a.Stats.Gap[2]) * ((site.Enraged or a.Enraged) and 0.7 or 1) * (E.Aggression or 1) * (alone and (E.LoneAggression or 1) or 1) * (a.Boss and E.BossPace and E.BossPace.Gap or 1)
			if a.Perch and not a.Perched and rng:NextNumber() < 0.35 then
				a.ClimbAt = nil
				setState(a, "Climb") -- (back up the trunk to dive again)
			else
				setState(a, "Chase")
			end
		end
		return
	end
	-- FLYER: climbing back up its trunk, or up on its perch waiting to dive
	if a.Perch then
		if st == "Climb" then
			local base = Vector3.new(a.Perch.X, groundY(site, a.Perch, site.Center.Y), a.Perch.Z)
			if not a.ClimbAt then
				-- (can't get to the foot of its tree: it gives up and fights on the ground)
				if a.T > 5 then setState(a, "Chase") return end
				if flat(base - a.Pos).Magnitude > 2.5 then
					moveActor(site, a, base, a.Speed, dt)
					publishActor(a, a.Speed)
					return
				end
				a.ClimbAt, a.ClimbFrom = now, a.Pos
			end
			local u = math.clamp((now - a.ClimbAt) / 1.2, 0, 1)
			a.Pos = (a.ClimbFrom :: Vector3):Lerp(a.Perch, u)
			publishActor(a, 0)
			if u >= 1 then
				a.ClimbAt = nil
				a.Perched = true
				a.NextAttack = now + rng:NextNumber(0.8, 1.8)
				setState(a, "Chase")
			end
			return
		end
		if a.Perched then
			a.Yaw = yawOf(flat(target.Pos - a.Pos))
			local busy = 0
			for _, o in ipairs(site.Actors) do if o.State == "Telegraph" or o.State == "Attack" then busy += 1 end end
			if now >= a.NextAttack and busy < 2 then
				-- the dive: off the perch in a long glide, straight at you (the outline is on the ground below)
				local d0 = nil
				for _, x in ipairs(a.Stats.Attacks) do if x.Id == "DiveStrike" then d0 = x end end
				local to = flat(target.Pos - a.Pos)
				local dive = { Id = "DiveStrike", Shape = "Line", Len = math.clamp(to.Magnitude + 3, 12, 60), Width = 4.5, Tele = 0.9, Dmg = d0 and d0.Dmg or 30, Dash = true }
				local ground = Vector3.new(a.Pos.X, groundY(site, a.Pos, site.Center.Y), a.Pos.Z)
				a.Attack = makeShape(a, dive, target.Pos)
				a.Attack.O = ground
				a.Attack.Tele = dive.Tele
				a.GlideFromY = a.Pos.Y
				a.Perched = false
				a.Cfg:SetAttribute("Attack", "DiveStrike")
				a.Cfg:SetAttribute("TeleTime", dive.Tele)
				a.Cfg:SetAttribute("TeleDash", DASH_TIME)
				setState(a, "Telegraph")
				fireSite(site, "Tele", { Actor = a.Id, Id = "DiveStrike", Shape = "Line", O = ground, Dir = a.Attack.Dir, Len = dive.Len, Width = dive.Width, Time = dive.Tele })
				return
			end
			publishActor(a, 0)
			return
		end
	end
	-- a sidestep (it read your dart coming): a quick hop to the side, then back on you
	if a.SidestepUntil then
		if now < a.SidestepUntil and a.SidestepTo then
			moveActor(site, a, a.SidestepTo, 24, dt)
			publishActor(a, 24)
			return
		end
		a.SidestepUntil, a.SidestepTo = nil, nil
	end
	local smart = E.Smart and E.Smart[site.Era]
	-- Chase: close in, then pick an attack that reaches
	local atks = a.Attacks or a.Stats.Attacks
	local reach = 0
	for _, atk in ipairs(atks) do reach = math.max(reach, (atk.Len or atk.Radius or 10) * 0.75) end
	local mad = site.Enraged or a.Enraged
	local lone = true
	for _, o in ipairs(site.Actors) do if o ~= a and o.State ~= "KO" and not o.Buddy then lone = false break end end
	local speed = a.Speed * (mad and 1.25 or 1) * ((a.SlowUntil and now < a.SlowUntil) and (a.SlowMult or 0.5) or 1) * (lone and (E.LoneSpeed or 1) or 1) * (a.Boss and E.BossPace and E.BossPace.Speed or 1)
		* ((a.RallyUntil and now < a.RallyUntil) and 1.3 or 1) -- (answering a call for help)
	if dist > reach * 0.6 then
		local goal = target.Pos
		local flankers = 0
		if smart and smart.Flank and target.P and dist > 8 then
			for _, o in ipairs(site.Actors) do if o.State ~= "KO" and not o.Custom then flankers += 1 end end
		end
		if flankers > 1 then
			-- FLANKING: they spread round you and the first one comes at your back (turn to face one, another's behind)
			local idx, k = 0, 0
			for _, o in ipairs(site.Actors) do
				if o.State ~= "KO" and not o.Custom then
					k += 1
					if o == a then idx = k end
				end
			end
			local h = hrpOf(target.P)
			local back = h and flat(-h.CFrame.LookVector) or flat(a.Pos - target.Pos)
			back = back.Magnitude > 0.1 and back.Unit or Vector3.new(1, 0, 0)
			goal = target.Pos + rotY(back, (idx - 1) / flankers * math.pi * 2) * math.max(4, reach * 0.55)
		elseif site.Def and (site.Def.Kind == "Pack" or site.Def.Kind == "Swarm" or site.Def.Kind == "Rival" or site.Def.Kind == "Flyer") and #site.Actors > 1 and dist > 8 then
			local idx = 0
			for i, o in ipairs(site.Actors) do if o == a then idx = i end end
			local from = flat(a.Pos - target.Pos)
			from = from.Magnitude > 0.1 and from.Unit or Vector3.new(1, 0, 0)
			local spread = (idx - (#site.Actors + 1) / 2) * 0.9
			goal = target.Pos + rotY(from, spread) * reach * 0.5
		end
		moveActor(site, a, goal, speed, dt)
		publishActor(a, speed)
	else
		publishActor(a, 0)
		a.Yaw = yawOf(flat(target.Pos - a.Pos))
	end
	-- camping on a rock or ledge doesn't work: after a moment the dino rams / leaps at that spot (the hit knocks you
	-- off it), and from up there your darts only tickle (FireAt). PerchSince is kept by the site tick
	if target.St and target.St.PerchSince and now - target.St.PerchSince > 0.8 and dist < (site.Boss and 45 or 95) then
		if st ~= "Telegraph" and now >= (a.NextReach or 0) then
			a.NextReach = now + 2.5
			-- (as hard as its own first attack: written once, right for every era)
			local first = atks[1]
			local reachAtk = { Id = "ShakeOff", Shape = "Circle", Radius = 9, Tele = 0.9, Dmg = (first and first.Dmg or 26) * 0.9, AtTarget = true, Reach = true }
			a.Attack = makeShape(a, reachAtk, target.Pos)
			a.Attack.Tele = reachAtk.Tele
			a.Cfg:SetAttribute("Attack", a.Boss and "Pounce" or "Charge")
			a.Cfg:SetAttribute("TeleTime", reachAtk.Tele)
			a.Cfg:SetAttribute("TeleDash", math.clamp((dist - 3) / 40, DASH_TIME, 1.1))
			setState(a, "Telegraph")
			fireSite(site, "Tele", { Actor = a.Id, Id = "ShakeOff", Shape = "Circle", O = a.Attack.O, R = 9, Time = a.Attack.Tele, Reach = true })
			return
		end
	end
	-- can't get to you at all (a wall, a gap, a cliff it can't climb): after a few seconds of getting nowhere it
	-- LEAPS - straight over whatever's in the way, onto your spot - and meanwhile your darts go soft
	if dist > reach and target.P and target.St and not site.Boss and not a.Boss then
		-- (stuck = its body has hardly moved while it's trying to get to you - a wall, a gap. Not "you're backing
		-- off faster than it walks": kiting a slow dino is fair)
		if not a.ProgAt or now - a.ProgAt > 1.5 then
			if a.ProgAt and a.ProgPos and flat(a.Pos - a.ProgPos).Magnitude < 1.5 then a.Stuck = (a.Stuck or 0) + 1 else a.Stuck = 0 end
			a.ProgAt, a.ProgPos = now, a.Pos
		end
		if (a.Stuck or 0) >= 2 then
			target.St.UnreachUntil = now + 4
			if st ~= "Telegraph" and now >= (a.NextReach or 0) and dist < 95 then
				a.Stuck = 0
				a.NextReach = now + 3
				local first = atks[1]
				local leap = { Id = "Leap", Shape = "Circle", Radius = 8, Tele = 1.0, Dmg = (first and first.Dmg or 26) * 0.9, AtTarget = true, Reach = true }
				a.Attack = makeShape(a, leap, target.Pos)
				a.Attack.Tele = leap.Tele
				a.Cfg:SetAttribute("Attack", "Pounce")
				a.Cfg:SetAttribute("TeleTime", leap.Tele)
				a.Cfg:SetAttribute("TeleDash", math.clamp((dist - 1.5) / 40, DASH_TIME, 1.1))
				setState(a, "Telegraph")
				fireSite(site, "Tele", { Actor = a.Id, Id = "Leap", Shape = "Circle", O = a.Attack.O, R = 8, Time = a.Attack.Tele, Reach = true })
				return
			end
		end
	else
		a.Stuck = 0
		a.ProgAt = nil
	end
	-- only two dinos wind up at once, so a pack stays readable
	if now >= a.NextAttack then
		local busy = 0
		for _, o in ipairs(site.Actors) do if o.State == "Telegraph" or o.State == "Attack" then busy += 1 end end
		if busy >= 2 then a.NextAttack = now + 0.6 return end
		local options = {}
		local fwd = dirOf(a.Yaw)
		for _, atk in ipairs(atks) do
			local r = atk.Len or atk.Radius or 10
			if atk.Back then
				-- only worth swinging when someone is actually behind it
				for _, e in ipairs(players) do
					local to = flat(e.Pos - a.Pos)
					if to.Magnitude <= r * 0.95 and to.Magnitude > 0.1 and to.Unit:Dot(fwd) < -0.25 then table.insert(options, atk) break end
				end
			elseif dist <= r * 0.95 or atk.AtTarget then
				table.insert(options, atk)
			end
		end
		if #options > 0 then
			-- the move that suits the gap (a bite up close, the lunge from range), rarely the same move twice in a row
			local atk, bw = options[1], -math.huge
			for _, o in ipairs(options) do
				local r = o.Len or o.Radius or 10
				local fit = o.Back and 0.9 or (o.AtTarget and 0.6 or (1 - math.abs(dist / math.max(1, r) - 0.55) * 1.4))
				local w = math.max(0.12, fit) * (o.Id == a.LastAtk and 0.35 or 1) * rng:NextNumber(0.75, 1.25)
				if w > bw then atk, bw = o, w end
			end
			a.LastAtk = atk.Id
			a.Attack = makeShape(a, atk, target.Pos)
			-- it squares up to what it's swinging at (a tail attack keeps its back to you)
			if not atk.Back and a.Attack.Dir then a.Yaw = yawOf(a.Attack.Dir) end
			a.Attack.Tele = atk.Tele * (mad and 0.8 or 1) * (E.TeleMult or 1) * (a.Boss and E.BossPace and E.BossPace.Tele or 1)
			-- aimed at a player with an armoured companion close by: it steps in front (Shield Wall)
			if target.P and (atk.Shape == "Line" or atk.Shape == "Cone") then
				for _, b in pairs(site.Buddies) do
					if b.Owner == target.P and b.Perks and b.Perks.Shield and not b.Downed and not b.Fallen and now >= (b.ShieldReady or 0)
						and flat(b.Pos - target.Pos).Magnitude < 26 then
						b.Block = { From = a.Pos, Until = now + a.Attack.Tele + 0.7 }
						b.ShieldReady = now + 8
						emote(site, b, "Shield")
						break
					end
				end
			end
			-- (what and how long first: the client times the wind-up animation off these the moment the state flips)
			a.Cfg:SetAttribute("Attack", atk.Id)
			a.Cfg:SetAttribute("TeleTime", a.Attack.Tele)
			a.Cfg:SetAttribute("TeleDash", atk.Dash and DASH_TIME or nil)
			setState(a, "Telegraph")
			fireSite(site, "Tele", {
				Actor = a.Id, Id = atk.Id, Shape = atk.Shape, O = a.Attack.O, Dir = a.Attack.Dir, Len = atk.Len, Width = atk.Width,
				R = atk.Radius, Inner = atk.Inner, Angle = atk.Angle, Time = a.Attack.Tele,
			})
			-- your first fight: the first time it winds up at you, the game tells you to roll
			if target.P and target.St and target.St.FirstFight and not target.St.DodgeHinted then
				target.St.DodgeHinted = true
				Net.Fire(target.P, "DodgeHint", { Time = a.Attack.Tele })
			end
		else
			a.NextAttack = now + 0.4
		end
	end
end

local function tickBuddies(site, dt: number)
	local now = os.clock()
	-- while nobody's been seen, buddies stay low at your heels: they never give the sneak away
	local fighting = site.Alarm or site.Boss or site.State == "Scramble"
	for cfg, b in pairs(site.Buddies) do
		if b.Fallen then continue end
		if b.Downed then
			-- lying there: revive it (hold E) before it bleeds out
			if now - (b.DownAt or now) >= Config.Buddy.Bleed then fall(site, b) end
			continue
		end
		local hrp = hrpOf(b.Owner)
		if not hrp then continue end
		local role = Config.BuddyRoleOf(cfg:GetAttribute("Species") or "")
		-- its own jobs come first: fetch a ball, rescue you, stand in front of a charge, go undercover, sniff out eggs
		local special, jobPace = nil, 20
		local ownerSt = site.Players[b.Owner]
		local ball = b.Fetch
		if ball and not ball.Cfg.Parent then b.Fetch, ball = nil, nil end
		if ball then
			if ball.State == "Flying" then
				special = ball.To
			elseif ball.State == "Ground" then
				special = ball.Pos
				if flat(ball.Pos - b.Pos).Magnitude < 2.5 then ball.State = "Carried" ball.Cfg:SetAttribute("State", "Carried") ball.Cfg:SetAttribute("By", cfg:GetAttribute("Id")) end
			elseif ball.State == "Carried" then
				-- trots back and drops it at your feet
				special = hrp.Position - hrp.CFrame.LookVector * -2.5
				ball.Pos = b.Pos + Vector3.new(0, 1.5, 0)
				ball.Cfg:SetAttribute("P", ball.Pos)
				if flat(hrp.Position - b.Pos).Magnitude < 4.5 then
					ball.State = "Dropped"
					ball.Pos = Vector3.new(b.Pos.X, groundY(site, b.Pos, site.Center.Y), b.Pos.Z)
					ball.Cfg:SetAttribute("State", "Dropped")
					ball.Cfg:SetAttribute("P", ball.Pos)
					ball.Cfg:SetAttribute("By", nil)
					emote(site, b, "Love")
					b.Fetch = nil
				end
			end
			jobPace = 26
		elseif ownerSt and ownerSt.Downed and b.Perks and b.Perks.Rescue then
			-- you're down and nobody's coming: it gets you back up (once a trip)
			local run = expedition().Get(b.Owner)
			local friend = false
			for plr, st in pairs(site.Players) do
				local h2 = hrpOf(plr)
				if plr ~= b.Owner and not st.Downed and h2 and flat(h2.Position - hrp.Position).Magnitude < 25 then friend = true end
			end
			if run and not run.RescueUsed and not friend then
				special = hrp.Position
				jobPace = 28
				if flat(hrp.Position - b.Pos).Magnitude < 4 then
					b.RescueT = (b.RescueT or 0) + dt
					if not b.Helping then b.Helping = true emote(site, b, "Help") end
					if b.RescueT >= 3 then
						run.RescueUsed = true
						b.RescueT, b.Helping = 0, nil
						revive(site, b.Owner, 0.4)
						Net.Fire(b.Owner, "Toast", { Text = (cfg:GetAttribute("Name") or "YOUR COMPANION") .. " GOT YOU BACK UP!", Color = "Teal" })
					end
				end
			end
		elseif b.Block and now < b.Block.Until then
			-- Shield Wall: plant itself between you and what's coming
			local toAtk = flat(b.Block.From - hrp.Position)
			special = hrp.Position + (toAtk.Magnitude > 0.1 and toAtk.Unit or hrp.CFrame.LookVector) * 3.2
			jobPace = 34
		elseif not fighting and b.Under then
			-- undercover: walks over to its own kind and keeps them company
			local friendA, fd = nil, math.huge
			for _, a in ipairs(site.Actors) do
				local d = flat(a.Pos - b.Pos).Magnitude
				if a.Species == b.Dino.Species and d < fd then friendA, fd = a, d end
			end
			if friendA then
				local stand = 3 + (friendA.Scale or 1) * 2.4
				special = friendA.Pos + flat(b.Pos - friendA.Pos).Unit * stand
				jobPace = 9
				if fd < stand + 2 then
					if not b.Chatting then b.Chatting = true b.ChatAt = now end
					if now >= (b.NextEmote or 0) then
						b.NextEmote = now + 3.5
						-- the family: hearts; the inside job: chatter, and now and then it glances at the eggs for you
						if b.Under == "Reunion" then emote(site, b, (rng:NextNumber() < 0.6) and "Love" or "Chat")
						else emote(site, b, (rng:NextNumber() < 0.5) and "Egg" or "Chat", site.Center) end
					end
				end
			end
		elseif not fighting and b.SniffAt and now >= b.SniffAt then
			-- Egg Sniffer: noses round the nest, finds the best egg (and sometimes digs another one up)
			special = site.Center
			jobPace = 12
			if flat(site.Center - b.Pos).Magnitude < 5 then
				b.SniffAt = nil
				emote(site, b, "Sniff")
				local best = nil
				for _, egg in pairs(site.Eggs) do
					if (egg.Owner == nil or egg.Owner == b.Owner.UserId) and not egg.Cfg:GetAttribute("Sniffed") then best = egg break end
				end
				if best then
					best.Luck = (best.Luck or 0) + 1.5
					if best.Fresh then upgradeEgg(site, best, best.Luck) end -- (sniffed out: a second, luckier roll; it keeps the better)
					best.Cfg:SetAttribute("Luck", best.Luck)
					best.Cfg:SetAttribute("Sniffed", true)
				end
				if rng:NextNumber() < 0.3 then
					task.delay(1.2, function()
						if not cfg.Parent then return end
						emote(site, b, "Dig")
						Encounter.PlaceEgg(site, { Species = site.Def.Species, Luck = 1 }, b.Pos + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), b.Owner.UserId)
					end)
				end
			end
		end
		if special then
			local d = flat(special - b.Pos)
			if d.Magnitude > 1 then
				b.Pos += d.Unit * math.min(d.Magnitude, jobPace * dt)
				b.Pos = Vector3.new(b.Pos.X, groundY(site, b.Pos, site.Center.Y), b.Pos.Z)
				cfg:SetAttribute("Yaw", yawOf(d))
			elseif b.Chatting and b.Under then
				local look = b.Under == "Inside" and (now % 7 > 5.5) and site.Center or nil
				if look then cfg:SetAttribute("Yaw", yawOf(flat(look - b.Pos))) end
			end
			cfg:SetAttribute("P", b.Pos)
			cfg:SetAttribute("V", d.Magnitude > 1 and jobPace * 0.8 or 0)
			continue
		end
		if b.Helping then b.Helping, b.RescueT = nil, 0 end
		-- diggers go and nose round the nest once a trip (the Egg Sniffer job, no bond needed)
		if role.Dig and not fighting and not b.Dug then b.Dug = true b.SniffAt = now + 1.5 end
		-- scavenger: runs your darts back to you mid-reload
		if role.Reload and ownerSt and now >= (b.NextReload or 0) and now < (ownerSt.ReloadUntil or 0) then
			b.NextReload = now + role.Reload
			ownerSt.ReloadUntil = now
			emote(site, b, "Help")
			Net.Fire(b.Owner, "BuddyHelp", { Kind = "Reload" })
		end
		-- pick the dino its owner is fighting (or the nearest awake one)
		local target, td = nil, math.huge
		if fighting then
			for _, a in ipairs(site.Actors) do
				if targetable(a) and a.State ~= "Idle" and a.State ~= "Unaware" then
					local d = flat(a.Pos - b.Pos).Magnitude
					if d < td then target, td = a, d end
				end
			end
		end
		local reach = role.Area and math.min(role.Area * 0.6, 8) or 5
		-- (outside its body, never inside it: a Brachiosaurus is far wider than a fixed 5-8 studs, so companions stood
		-- in its legs - 2026-10-14, user: "don't allow the companion to walk inside the dino you're fighting")
		if target then
			local tLen, tWide = bodySize(target.Species or "", target.Scale or 1)
			reach = math.max(reach, (tLen + tWide) * 0.28 + (b.Wide or 3) * 0.5 + 1.5)
		end
		local goal
		if target and td < 60 then goal = target.Pos + flat(b.Pos - target.Pos).Unit * reach
		else
			-- behind you with room for its whole body, on the side its slot says; it follows the way you're moving
			-- (not where you face), so turning on the spot doesn't send it circling round you
			local len, wide = b.Len or 6, b.Wide or 3
			local v = flat(hrp.AssemblyLinearVelocity)
			if v.Magnitude > 3 then b.Heading = v.Unit elseif not b.Heading then b.Heading = flat(hrp.CFrame.LookVector).Unit end
			local fwd = b.Heading :: Vector3
			local right = fwd:Cross(Vector3.yAxis)
			local sideK = b.Slot == 1 and 1 or (b.Slot == 2 and -1 or 0)
			-- (a little more room: a big one like a Triceratops was right on your heels - 2026-10-14)
			goal = hrp.Position - fwd * (5 + len * 0.8 + (sideK == 0 and 5 or 0)) + right * sideK * (4 + wide * 0.9)
		end
		local d = flat(goal - b.Pos)
		local pace = fighting and 24 or 12
		-- it only sets off once it's properly out of place (or right on top of you), instead of shuffling after every step
		local crowding = not target and flat(hrp.Position - b.Pos).Magnitude < (b.Len or 6) * 0.5 + 4
		if target then b.Moving = d.Magnitude > 1
		elseif d.Magnitude > 2.5 + (b.Len or 6) * 0.15 or crowding then b.Moving = true
		elseif d.Magnitude < 1 then b.Moving = false end
		if d.Magnitude > 1 and b.Moving then
			b.Pos += d.Unit * math.min(d.Magnitude, pace * dt)
			b.Pos = Vector3.new(b.Pos.X, groundY(site, b.Pos, site.Center.Y), b.Pos.Z)
			cfg:SetAttribute("Yaw", yawOf(d))
		end
		cfg:SetAttribute("P", b.Pos)
		cfg:SetAttribute("V", (d.Magnitude > 1 and b.Moving) and pace * 0.8 or 0)
		if target and td < reach + 4 and now >= b.Next then
			b.Next = now + role.Every
			cfg:SetAttribute("State", "Bite")
			task.delay(0.5, function() if cfg.Parent then cfg:SetAttribute("State", "Follow") end end)
			-- a share of its owner's own launcher damage (see Config.Buddy): a help, never the whole fight
			local amount = Config.BuddyHit(b.Dino, role, b.Dps, b.Bond)
			local hit = { target }
			if role.Area then
				for _, o in ipairs(site.Actors) do
					if o ~= target and o.State ~= "KO" and flat(o.Pos - b.Pos).Magnitude < role.Area then table.insert(hit, o) end
				end
			end
			for _, o in ipairs(hit) do
				Encounter.Calm(site, o, amount, b.Owner, "Buddy")
				if role.Stun and o.State ~= "KO" and o.State ~= "Exhausted" and o.State ~= "Rodeo" and not o.Boss then
					o.StunUntil = math.max(o.StunUntil or 0, now + role.Stun)
				end
			end
			-- bite a dino and it may turn on you for a bit
			if target.State ~= "KO" and rng:NextNumber() < (target.Boss and Config.Buddy.BossAggro or Config.Buddy.Aggro) then
				target.FocusBuddy = b
				target.FocusUntil = now + Config.Buddy.AggroTime
			end
			if role.Distract and swayable(target) then
				target.Bait = b.Pos
				target.DistractUntil = now + role.Distract
				setState(target, "Distracted")
			end
			-- the new jobs (2026-10-12 roster): shred, slow, pin, blind, terror, heal
			for _, o in ipairs(hit) do
				if o.State == "KO" then continue end
				if role.Shred then o.ShredUntil, o.ShredMult = now + role.Shred[2], role.Shred[1] end
				if role.Slow then o.SlowUntil, o.SlowMult = now + role.Slow[2], role.Slow[1] end
				if role.Pin and not o.Boss then o.PinUntil = now + role.Pin end
				if role.Blind then o.BlindLeft = math.max(o.BlindLeft or 0, role.Blind) end
				if role.Terror and swayable(o) and (o.Scale or 1) <= 1.3 then
					local away = flat(o.Pos - b.Pos)
					o.Bait = o.Pos + (away.Magnitude > 0.1 and away.Unit or dirOf(o.Yaw)) * 24
					o.DistractUntil = now + role.Terror
					setState(o, "Distracted")
				end
			end
			if role.Heal then
				local ost = site.Players[b.Owner]
				if ost and not ost.Downed and ost.HP < ost.MaxHP then
					local before = ost.HP
					ost.HP = math.min(ost.MaxHP, ost.HP + ost.MaxHP * role.Heal)
					setHP(ost, b.Owner)
					Net.Fire(b.Owner, "BuddyHelp", { Kind = "Heal", Amount = math.floor(ost.HP - before) })
					emote(site, b, "Love")
				end
			end
			fireSite(site, "BuddyAct", { Buddy = cfg:GetAttribute("Id"), Owner = b.Owner.UserId, Role = role.Name, P = b.Pos, T = target.Pos, Amount = math.floor(amount), Area = role.Area, Stun = role.Stun ~= nil, Count = #hit })
		end
	end
end

--------------------------------------------------------------------------------
-- calm (the knock-out bar)
--------------------------------------------------------------------------------
local function allKO(site): boolean
	for _, a in ipairs(site.Actors) do
		if not a.Minion and a.State ~= "KO" then return false end
	end
	return #site.Actors > 0
end

function Encounter.Calm(site, a, amount: number, by: Player?, source: string?)
	if a.State == "KO" or a.State == "Rodeo" or a.State == "Exhausted" then return "None" end
	if site.Boss and os.clock() < (site.FreezeUntil or 0) then return "None" end -- mid-reveal: untouchable
	if site.Shield and a.Boss then amount *= 0.25 end -- e.g. the Queen while her pack is up
	if a.ShredUntil and os.clock() < a.ShredUntil then amount *= a.ShredMult or 1.4 end -- a buddy slashed its armour
	a.Calm = math.min(a.CalmMax, a.Calm + amount)
	if site.CapCalm then a.Calm = math.min(a.Calm, site.CapCalm(site, a)) end
	if a.Carry and amount > 0 then dropCarry(site, a) end
	a.Cfg:SetAttribute("Calm", a.Calm)
	if by and site.Players[by] then site.Players[by].Contribution += amount end
	-- a boss fight's shared rewards follow how much calm each hunter dealt
	local part = by and site.Participants and site.Participants[by]
	if type(part) == "table" then part.Score += amount end
	if a.State == "Idle" then setState(a, "Chase") end
	if a.State == "Unaware" then Encounter.Alarm(site, by, a) end
	-- a smart dino that's badly hurt roars for help: every other dino here comes running, fast, and swings sooner
	local smart = E.Smart and E.Smart[site.Era]
	if smart and smart.Help and not a.CalledHelp and not a.Boss and not a.Minion and a.Calm >= a.CalmMax * smart.Help and a.Calm < a.CalmMax then
		a.CalledHelp = true
		local n = 0
		for _, o in ipairs(site.Actors) do
			if o ~= a and o.State ~= "KO" and o.State ~= "Exhausted" and o.State ~= "Rodeo" and not o.Custom then
				if o.State == "Unaware" or o.State == "Idle" then setState(o, "Chase") end
				o.RallyUntil = os.clock() + 4
				o.NextAttack = math.min(o.NextAttack, os.clock() + 0.9)
				n += 1
			end
		end
		if n > 0 then fireSite(site, "CallHelp", { Actor = a.Id, Count = n }) end
	end
	-- half way down it gets angry: faster, shorter wind-ups, and it chains attacks
	if not a.Enraged and not a.Minion and (a.Lead or a.Rodeo or a.Boss) and a.Calm >= a.CalmMax * 0.5 then
		a.Enraged = true
		a.Cfg:SetAttribute("Enraged", true)
		a.NextAttack = os.clock() + 1.3
		fireSite(site, "Enrage", { Actor = a.Id, Species = a.Species })
	end
	local result = "Calm"
	if a.Rodeo and a.Calm >= a.CalmMax * E.RodeoAt then
		-- the big one is exhausted: someone jump on for the rodeo finisher
		setState(a, "Exhausted")
		a.Cfg:SetAttribute("RodeoOpen", true)
		fireSite(site, "RodeoOpen", { Actor = a.Id })
		result = "Exhausted"
	elseif a.Calm >= a.CalmMax then
		Encounter.KO(site, a)
		result = "KO"
	end
	publishSite(site)
	if site.OnCalm then site.OnCalm(site, a) end
	return result
end

function Encounter.KO(site, a)
	if a.State == "KO" then return end
	dropCarry(site, a)
	a.Calm = a.CalmMax
	a.Cfg:SetAttribute("Calm", a.Calm)
	a.Cfg:SetAttribute("RodeoOpen", nil)
	a.Cfg:SetAttribute("Weak", nil)
	setState(a, "KO")
	fireSite(site, "KnockedOut", { Actor = a.Id, Species = a.Species, Boss = a.Boss })
	if site.OnKO then site.OnKO(site, a) end
	if not site.Boss and allKO(site) then
		Encounter.StartScramble(site, true)
		-- a knockout with your companions there: their bond grows
		for plr in pairs(site.Players) do
			local ids = {}
			for _, b in pairs(site.Buddies) do if b.Owner == plr and not b.Fallen then table.insert(ids, b.Dino.Id) end end
			task.defer(Dinos.AddBond, plr, ids, Config.Bond.Gain.Takedown)
		end
	end
end

--------------------------------------------------------------------------------
-- eggs: the scramble
--------------------------------------------------------------------------------
-- a nest egg's rarity is rolled the moment it's placed, so it SHOWS (glow, tip) before anyone grabs it: the best
-- luck among the hunters it's for (just its owner for a prize egg). A takedown or a companion's sniff can only
-- ever lift it (a visible upgrade), never lower it
local function eggProfiles(site, owner: number?): { any }
	local list = {}
	for plr in pairs(site.Players) do
		if not owner or plr.UserId == owner then
			local pf = Data.Peek(plr)
			if pf then table.insert(list, pf) end
		end
	end
	return list
end
local function rollEgg(site, luck: number?, owner: number?): string
	return Dinos.PeekRarity(eggProfiles(site, owner), luck or 0)
end
upgradeEgg = function(site, e, luck: number)
	local new = rollEgg(site, luck, e.Owner)
	local cur = Config.Rarity[e.Rarity or ""]
	if Config.Rarity[new] and Config.Rarity[new].Order > (cur and cur.Order or 0) then
		e.Rarity = new
		e.Cfg:SetAttribute("Rarity", new)
	end
end
Encounter.UpgradeEgg = upgradeEgg

function Encounter.SpillEgg(site, egg, from: Vector3)
	nextEgg += 1
	local cfg = Instance.new("Configuration")
	cfg.Name = "Egg" .. nextEgg
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(3, 11)
	local p = from + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	p = Vector3.new(p.X, groundY(site, p, site.Center.Y), p.Z)
	local fresh = false
	if not egg.Rarity or egg.Rarity == "" then egg.Rarity, fresh = rollEgg(site, egg.Luck, nil), true end
	cfg:SetAttribute("Id", nextEgg)
	cfg:SetAttribute("Site", site.Key)
	cfg:SetAttribute("Species", egg.Species)
	cfg:SetAttribute("Rarity", egg.Rarity or "")
	cfg:SetAttribute("Luck", egg.Luck or 0)
	egg.KG = egg.KG or Dinos.RollKG(egg.Species)
	cfg:SetAttribute("KG", egg.KG)
	cfg:SetAttribute("P", p)
	cfg:SetAttribute("From", from)
	-- (an egg that was somebody's - off their rack, their boss egg - stays theirs when it's knocked loose)
	local owner = (egg.FromRack or egg.BossEgg) and egg.Owner or nil
	if owner then cfg:SetAttribute("Owner", owner) end
	if egg.BossEgg then cfg:SetAttribute("BossEgg", true) end
	cfg.Parent = EggFolder
	site.Eggs[nextEgg] = { Cfg = cfg, Species = egg.Species, Luck = egg.Luck or 0, Rarity = egg.Rarity, KG = egg.KG, Pos = p, Fresh = fresh,
		Owner = owner, FromRack = egg.FromRack, BossEgg = egg.BossEgg }
end

-- a place on the nest bed for egg k
local function nestSpot(site, k: number): Vector3
	local ang = (k / 5) * math.pi * 2 + 0.3
	local r = 1.2 + math.floor((k - 1) / 5) * 1.1
	return site.Center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
end

function Encounter.PlaceEgg(site, egg, at: Vector3, owner: number?)
	nextEgg += 1
	local cfg = Instance.new("Configuration")
	cfg.Name = "Egg" .. nextEgg
	local p = Vector3.new(at.X, groundY(site, at, site.Center.Y), at.Z)
	local fresh = false
	if not egg.Rarity or egg.Rarity == "" then egg.Rarity, fresh = rollEgg(site, egg.Luck, owner), true end
	cfg:SetAttribute("Id", nextEgg)
	cfg:SetAttribute("Site", site.Key)
	cfg:SetAttribute("Species", egg.Species)
	cfg:SetAttribute("Rarity", egg.Rarity or "")
	cfg:SetAttribute("Luck", egg.Luck or 0)
	egg.KG = egg.KG or Dinos.RollKG(egg.Species)
	cfg:SetAttribute("KG", egg.KG)
	cfg:SetAttribute("P", p)
	cfg:SetAttribute("From", p)
	if owner then cfg:SetAttribute("Owner", owner) end
	if egg.BossEgg then cfg:SetAttribute("BossEgg", true) end
	cfg.Parent = EggFolder
	site.Eggs[nextEgg] = { Cfg = cfg, Species = egg.Species, Luck = egg.Luck or 0, Rarity = egg.Rarity, KG = egg.KG, Pos = p, Owner = owner, Fresh = fresh or egg.Fresh == true, BossEgg = egg.BossEgg, FromRack = egg.FromRack }
	return nextEgg
end

-- the nest holds (hunters here + 1) eggs; a new hunter joining adds one
function Encounter.FillNest(site)
	if site.Boss or (site.Def and site.Def.Wild) then return end -- (a wild dino has no nest: its egg drops when it goes down)
	site.EggsMade = site.EggsMade or 0
	local want = site.Count + E.EggsBonus + (site.Mood and site.Mood.Eggs or 0)
	while site.EggsMade < want do
		site.EggsMade += 1
		Encounter.PlaceEgg(site, { Species = site.Def.Species, Luck = 0 }, nestSpot(site, site.EggsMade))
	end
end

-- THE BOSS NEST: the knocked-out boss's eggs, laid in the nest for every hunter who won (Bosses.victory). `center`:
-- where the nest goes (beside the boss lying there - it used to be the arena's middle, often under the body)
function Encounter.PlaceBossEgg(site, egg, k: number, center: Vector3?)
	local at = nestSpot(site, k)
	if center then at = center + (at - site.Center) end
	return Encounter.PlaceEgg(site, { Species = egg.Species, Rarity = egg.Rarity, KG = egg.KG, BossEgg = true, Fresh = true }, at, nil)
end

-- leaving a won boss den: what's yours comes with you - the egg in your arms, one you set down, or (if you never
-- grabbed one) your share from what's left in the nest. A boss egg goes straight to your bag (always fits); a rack
-- egg back on your rack, or to the bag for a rider
local function keepEgg(player: Player, rec)
	-- (2026-10-14, "my friend can't take the egg - the car's not theirs": a boss egg never depends on whose rover is
	-- parked where. Rack eggs go on your rack if you have a run; otherwise - a rider, or a ride just ended - the bag)
	if not rec.BossEgg and not isRider(player) and Expedition and Expedition.Get and Expedition.Get(player) then
		Expedition.LoadEgg(player, { Species = rec.Species, Rarity = rec.Rarity, KG = rec.KG }, rec.FromRack == true)
	else
		bagEgg(player, rec, rec.BossEgg == true)
	end
end
claimBossEggs = function(site, player: Player, st)
	if not (site.Boss and (site.Phase or 0) >= 4 and site.BossWinners and player.Parent) then return end
	local uid = player.UserId
	if st and st.Holding and st.Holding.BossEgg then
		keepEgg(player, st.Holding)
		st.Holding = nil
		player:SetAttribute("Holding", nil)
		Dinos.ClearHeld(player)
	end
	for id, e in pairs(site.Eggs) do
		if e.BossEgg and e.Owner == uid then
			keepEgg(player, e)
			e.Cfg:Destroy()
			site.Eggs[id] = nil
		end
	end
	if site.BossWinners[uid] and not (site.BossTaken and site.BossTaken[uid]) then
		-- you never grabbed one: the plainest one left is yours (first come got first pick)
		local pick, pid = nil, nil
		for id, e in pairs(site.Eggs) do
			if e.BossEgg and e.Owner == nil then
				local o = Config.Rarity[e.Rarity or ""] and Config.Rarity[e.Rarity].Order or 0
				local po = pick and Config.Rarity[pick.Rarity or ""] and Config.Rarity[pick.Rarity].Order or math.huge
				if o < po then pick, pid = e, id end
			end
		end
		if pick then
			site.BossTaken = site.BossTaken or {}
			site.BossTaken[uid] = true
			local fl = site.BossFloor and site.BossFloor[uid] or 0
			local rec = { Species = pick.Species, Rarity = pick.Rarity, KG = pick.KG, BossEgg = true }
			if fl > 0 and (Config.Rarity[rec.Rarity or ""] and Config.Rarity[rec.Rarity].Order or 0) < fl then rec.Rarity = Config.RarityOrder[fl] end
			local pf = Data.Peek(player)
			if pf then
				rec.Rarity = Dinos.PityFloor(pf, rec.Rarity)
				Dinos.NotePity(pf, rec.Rarity)
			end
			pick.Cfg:Destroy()
			site.Eggs[pid] = nil
			keepEgg(player, rec)
		end
	end
end

-- leaving a site: an egg you took off your own rack (in your arms, or set down here) goes back on it while there's
-- room. A full rack means you swapped it out for something better: that one stays behind
returnRackEggs = function(site, player: Player, st)
	if not player.Parent or isRider(player) or not (Expedition and Expedition.Get and Expedition.Get(player)) then return end
	local function room(): boolean return Expedition.CarriedCount(player) < Expedition.RackCapacity(player) end
	if st and st.Holding and st.Holding.FromRack and room() then
		keepEgg(player, st.Holding)
		st.Holding = nil
		player:SetAttribute("Holding", nil)
		Dinos.ClearHeld(player)
	end
	for id, e in pairs(site.Eggs) do
		if e.FromRack and e.Owner == player.UserId and room() then
			keepEgg(player, e)
			e.Cfg:Destroy()
			site.Eggs[id] = nil
		end
	end
end

-- mid-run at a nest: take an egg off your own rack to carry (hands full: a straight swap - the one you're holding
-- goes into its slot). Set it down by the nest and grab the better one; it's yours, nobody else can take it
function Encounter.TakeRackEgg(player: Player, index: number)
	local site = playerSite[player]
	local st = site and site.Players[player]
	if not st or st.Downed or isRider(player) then return { Ok = false } end
	if site.State == "Cooldown" or site.State == "Chase" then return { Ok = false } end
	local hrp, root = hrpOf(player), Vehicles.Root(player)
	if not (hrp and root) or flat(hrp.Position - root.Position).Magnitude > 16 then return { Ok = false, Err = "GET CLOSER TO YOUR ROVER" } end
	local put = st.Holding
	if put and put.BossEgg and site.Boss and (site.Phase or 0) >= 4 then put = put end -- (a boss egg swaps like any other)
	local old = Expedition.SwapRackEgg(player, index, put)
	if not old then return { Ok = false } end
	local rec = { Species = old.Species, Rarity = old.Rarity, KG = old.KG, Owner = player.UserId, FromRack = true }
	st.Holding = rec
	player:SetAttribute("Holding", rec.Species)
	Dinos.ShowHeld(player, rec)
	return { Ok = true, Egg = rec, Swapped = put ~= nil }
end

-- every dino here is out cold: the nest is yours (eggs roll with takedown luck); nobody is timed out
function Encounter.StartScramble(site, takedown: boolean)
	if site.State == "Scramble" or site.State == "Chase" then return end
	site.State = "Scramble"
	site.Takedown = takedown
	-- a WILD dino's one egg, dropped where it went down: takedown luck, and its glow is the floor (WildLife.luau)
	if site.Def and site.Def.Wild and next(site.Eggs) == nil then
		local a = site.Actors[1]
		local at = (a and a.Pos) or site.Center
		local rarity = rollEgg(site, Config.TakedownLuck, nil)
		local floorR = site.Def.WildFloor
		if floorR and Config.Rarity[floorR] and Config.Rarity[rarity].Order < Config.Rarity[floorR].Order then rarity = floorR end
		Encounter.PlaceEgg(site, { Species = site.Def.Species, Luck = Config.TakedownLuck, Rarity = rarity }, at + Vector3.new(2, 0, 2))
	end
	local n = 0
	for _, e in pairs(site.Eggs) do
		-- (a takedown's luck: every egg in the nest gets a second roll and keeps the better one - you SEE them brighten)
		if takedown and e.Fresh and (e.Luck or 0) < Config.TakedownLuck then upgradeEgg(site, e, Config.TakedownLuck) end
		e.Luck = math.max(e.Luck or 0, takedown and Config.TakedownLuck or 0)
		e.Cfg:SetAttribute("Luck", e.Luck)
		n += 1
	end
	fireSite(site, "Scramble", { Count = n, Takedown = takedown })
	publishSite(site)
	if takedown then Encounter.DropKeys(site) end
end

-- BOSS KEYS: a takedown can knock a key out of the dino. It's a real thing on the ground (each hunter rolls
-- their own; only they see theirs): walk over, pick it up. Leave without it and it's gone.
local nextKey = 0
function Encounter.DropKeys(site)
	if site.Boss then return end
	local era = Config.Era(site.Era)
	if not (era and era.Boss) then return end
	-- it flies out of one of the knocked-out dinos
	local from = site.Center
	if #site.Actors > 0 then from = site.Actors[rng:NextInteger(1, #site.Actors)].Pos end
	for player, st in pairs(site.Players) do
		-- onboarding: from your 3rd expedition, your first takedown in an era whose boss you've never beaten (and
		-- have no key for) always drops its key - the build-up to the first boss fight is a promise, not a dice roll
		local profile = Data.Peek(player)
		local sure = profile ~= nil and (profile.Stats.Runs or 0) >= 2 and (profile.Keys[era.Boss] or 0) == 0
			and not (profile.Bosses[era.Boss] and (profile.Bosses[era.Boss].Best or 0) >= 1)
		-- (random keys only from your 3rd expedition too: before that the boss is still being built up - footprints,
		-- the roar, the road crossing - and a run-1 key skipped all of it)
		if sure or ((profile ~= nil and (profile.Stats.Runs or 0) >= 2) and rng:NextNumber() < Config.KeyChance) then
			nextKey += 1
			local a = rng:NextNumber() * math.pi * 2
			local spot = from + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(5, 8)
			spot = Vector3.new(spot.X, groundY(site, spot, from.Y), spot.Z)
			st.Key = { Id = nextKey, Pos = spot, From = from, Boss = era.Boss }
			Net.Fire(player, "KeySpawn", { Id = nextKey, Pos = spot, From = from, Boss = era.Boss })
		end
	end
end

function Encounter.PickKey(player: Player, id: number)
	local site = playerSite[player]
	local st = site and site.Players[player]
	local key = st and st.Key
	local hrp = hrpOf(player)
	if not (key and key.Id == id and hrp) then return { Ok = false } end
	if st.Downed then return { Ok = false } end
	if flat(hrp.Position - key.Pos).Magnitude > 12 and not (key.From and flat(hrp.Position - key.From).Magnitude < 14) then return { Ok = false, Err = "TOO FAR" } end
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	st.Key = nil
	profile.Keys[key.Boss] = (profile.Keys[key.Boss] or 0) + 1
	Data.Changed(player)
	-- everyone around sees you hold it up
	player:SetAttribute("PickupTick", (player:GetAttribute("PickupTick") or 0) + 1)
	return { Ok = true, Boss = key.Boss, Count = profile.Keys[key.Boss] }
end

-- an egg spills from your arms (a big hit, leaving): it lands where you stood, rarity already rolled
function Encounter.DropHeld(site, player: Player)
	local st = site.Players[player]
	if not st or not st.Holding then return end
	local egg = st.Holding
	st.Holding = nil
	player:SetAttribute("Holding", nil)
	Dinos.ClearHeld(player)
	local hrp = hrpOf(player)
	local at = hrp and hrp.Position or site.Center
	Encounter.PlaceEgg(site, { Species = egg.Species, Rarity = egg.Rarity, KG = egg.KG, BossEgg = egg.BossEgg, FromRack = egg.FromRack }, at + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), (egg.BossEgg or egg.FromRack) and player.UserId or egg.Owner)
	Net.Fire(player, "EggDropped", {})
end

-- set the egg in your arms down in front of you (rarity kept; it stays yours, so nobody else can grab it)
function Encounter.PutDown(player: Player)
	local site = playerSite[player]
	local st = site and site.Players[player]
	if not st or not st.Holding then return { Ok = false } end
	local hrp = hrpOf(player)
	local egg = st.Holding
	st.Holding = nil
	player:SetAttribute("Holding", nil)
	Dinos.ClearHeld(player)
	local at = hrp and (hrp.Position + flat(hrp.CFrame.LookVector).Unit * 3) or site.Center
	Encounter.PlaceEgg(site, { Species = egg.Species, Rarity = egg.Rarity, KG = egg.KG, BossEgg = egg.BossEgg, FromRack = egg.FromRack }, at, player.UserId)
	return { Ok = true }
end

-- pick an egg up (a prompt on it): one at a time, in your arms; taking it from under their noses is risky
function Encounter.PickEgg(player: Player, id: number)
	local site = playerSite[player]
	if not site or site.State == "Cooldown" or site.State == "Chase" then return { Ok = false } end
	local st = site.Players[player]
	local egg = site.Eggs[id]
	local hrp = hrpOf(player)
	if not st or st.Downed or not egg or not hrp then return { Ok = false } end
	-- a BOSS EGG goes straight into the winner's bag the moment they pick it up (2026-10-14, user: "when you do a boss
	-- with your friend they can't take the egg cus the car's not theirs, and you can't take it because it's not
	-- yours"). Carrying it to a rover meant it hung on having a rover of your own, parked within reach - a rider has
	-- none, and two rovers parked on one spot shoved each other off. The bag needs no rover, never fills up for it,
	-- and nothing on the way home can lose it. Hands full doesn't matter either
	local bossEgg = egg.BossEgg == true
	-- hands full: a companion that's learned to carry takes this one for you
	local carrier = nil
	if st.Holding and not bossEgg then
		for _, b in pairs(site.Buddies) do
			if b.Owner == player and b.Perks and b.Perks.Carry and not b.CarryEgg and not b.Downed and not b.Fallen and flat(b.Pos - hrp.Position).Magnitude < 30 then carrier = b break end
		end
		if not carrier then return { Ok = false, Err = "HANDS FULL - LOAD IT ON YOUR ROVER" } end
	end
	if egg.Owner and egg.Owner ~= player.UserId then return { Ok = false, Err = "THAT ONE IS SOMEONE ELSE'S" } end
	if flat(hrp.Position - egg.Pos).Magnitude > 10 then return { Ok = false, Err = "TOO FAR" } end
	-- the boss nest: for the hunters who won, first come first served - one each while a teammate still has none
	local bossPick = egg.BossEgg and egg.Owner == nil
	if bossPick then
		local uid = player.UserId
		if not (site.BossWinners and site.BossWinners[uid]) then return { Ok = false, Err = "THESE ARE FOR THE HUNTERS WHO WON" } end
		site.BossTaken = site.BossTaken or {}
		if site.BossTaken[uid] then
			for plr in pairs(site.Players) do
				if plr ~= player and site.BossWinners[plr.UserId] and not site.BossTaken[plr.UserId] then
					return { Ok = false, Err = "YOU HAVE YOURS - LEAVE ONE FOR YOUR TEAM" }
				end
			end
		end
	end
	if bossEgg then carrier = nil end
	local rider = isRider(player)
	if rider then
		-- a rider takes ONE egg from each nest (straight to the bag - no rack, no carry, no chase risk), plus their
		-- share of a boss nest
		if st.RiderTook and not bossEgg then return { Ok = false, Err = "YOU'VE GOT YOURS FROM THIS NEST" } end
		local pf = Data.Peek(player)
		if pf and #pf.Eggs >= Config.Inventory.MaxEggs and not bossEgg then return { Ok = false, Err = "EGG BAG FULL - HATCH SOME FIRST" } end
		carrier = nil -- (a rider's egg goes straight to their bag: no hands, no companion carry)
	end
	site.Eggs[id] = nil
	egg.Cfg:Destroy()
	local profile = Data.Peek(player)
	local rarity = egg.Rarity
	local rolled = not rarity or rarity == ""
	if rolled then rarity = Dinos.RollRarity(profile, math.max(site.Takedown and Config.TakedownLuck or 0, egg.Luck or 0)) end
	if bossPick then
		-- your first-clear promise (EPIC for your very first boss, RARE for a new one) rides on whichever egg you grab
		local uid = player.UserId
		local fl = site.BossFloor and site.BossFloor[uid] or 0
		if fl > 0 and (Config.Rarity[rarity] and Config.Rarity[rarity].Order or 0) < fl then rarity = Config.RarityOrder[fl] end
		if site.BossFloor then site.BossFloor[uid] = nil end
		site.BossTaken[uid] = true
	end
	-- (rolled when it was placed: YOUR pity applies now - due, and it's at least EPIC - and the counter moves, once
	-- per egg, for whoever actually takes it)
	if not rolled and profile and egg.Fresh then
		rarity = Dinos.PityFloor(profile, rarity)
		Dinos.NotePity(profile, rarity)
	end
	local rec = { Species = egg.Species, Rarity = rarity, KG = egg.KG, Owner = egg.Owner, BossEgg = egg.BossEgg, FromRack = egg.FromRack }
	local bagged = rider or bossEgg
	if bossEgg then
		-- (the boss egg: in the bag now, rarity card and all - whoever's rover is wherever)
		bagEgg(player, rec, true)
		Quests.Progress(player, "Eggs", { Count = 1 })
	elseif rider then
		st.RiderTook = true
		player:SetAttribute("RiderTook", site.Key)
		bagEgg(player, rec, false)
	elseif carrier then
		carrier.CarryEgg = rec
		carrier.Cfg:SetAttribute("CarryEgg", rec.Species)
		emote(site, carrier, "Egg")
	else
		st.Holding = rec
		player:SetAttribute("Holding", rec.Species)
		Dinos.ShowHeld(player, rec)
	end
	-- your companion undercover: a family reunion gives you one egg as a present (nobody minds); on an inside job
	-- they're too busy chatting to notice much
	local under = nil
	for _, b in pairs(site.Buddies) do if b.Owner == player and b.Chatting and b.Under then under = b end end
	local alertK = 1
	if under and under.Under == "Reunion" and not st.GiftUsed then
		st.GiftUsed = true
		rec.Gift = true
		alertK = 0
		emote(site, under, "Love")
	elseif under and under.Under == "Inside" then
		alertK = 0.25
	end
	-- lifting an egg out of the nest is never silent: every dino nearby whips round, the close ones nearly see you
	for _, a in ipairs(site.Actors) do
		local d = flat(a.Pos - hrp.Position).Magnitude
		if a.State == "Unaware" and d < 34 and alertK > 0 then
			a.Aware = math.min(0.92, (a.Aware or 0) + (d < 18 and 0.6 or 0.35) * alertK)
			if alertK >= 1 then a.Yaw = yawOf(flat(hrp.Position - a.Pos)) end
		end
	end
	fireSite(site, "EggTaken", { Id = id, UserId = player.UserId })
	return { Ok = true, Egg = rec, Companion = carrier and carrier.Cfg:GetAttribute("Name") or nil, Bagged = bagged or nil, Boss = bossEgg or nil }
end

-- the egg your companion's carrying goes on the rack too (if there's room)
local function loadCompanionEggs(site, player: Player): number
	local n = 0
	for _, b in pairs(site.Buddies) do
		if b.Owner == player and b.CarryEgg and Expedition.CarriedCount(player) < Expedition.RackCapacity(player) then
			local rec = b.CarryEgg
			b.CarryEgg = nil
			b.Cfg:SetAttribute("CarryEgg", nil)
			Expedition.LoadEgg(player, { Species = rec.Species, Rarity = rec.Rarity, KG = rec.KG }, rec.FromRack == true)
			if not rec.FromRack then Quests.Progress(player, "Eggs", { Count = 1 }) end
			n += 1
		end
	end
	return n
end

-- load what you're carrying onto your rover's roof rack (a prompt on the rover)
function Encounter.LoadEgg(player: Player)
	local site = playerSite[player]
	local st = site and site.Players[player]
	if not st then return { Ok = false } end
	local hrp, root = hrpOf(player), Vehicles.Root(player)
	-- (18, the same reach as DRIVE OFF: driving off from 17 studs used to drop the egg in your hands)
	if not (hrp and root) or flat(hrp.Position - root.Position).Magnitude > 18 then return { Ok = false, Err = "GET CLOSER TO YOUR ROVER" } end
	if not st.Holding then
		if loadCompanionEggs(site, player) > 0 then
			return { Ok = true, Loaded = Expedition.CarriedCount(player), Capacity = Expedition.RackCapacity(player) }
		end
		return { Ok = false }
	end
	if Expedition.CarriedCount(player) >= Expedition.RackCapacity(player) then return { Ok = false, Err = "ROOF RACK FULL - DRIVE OFF!" } end
	local rec = st.Holding
	st.Holding = nil
	player:SetAttribute("Holding", nil)
	Dinos.ClearHeld(player)
	Expedition.LoadEgg(player, { Species = rec.Species, Rarity = rec.Rarity, KG = rec.KG }, rec.FromRack == true)
	if not rec.FromRack then Quests.Progress(player, "Eggs", { Count = 1 }) end -- (your own rack egg going back on isn't a new egg)
	loadCompanionEggs(site, player)
	return { Ok = true, Egg = rec, Loaded = Expedition.CarriedCount(player), Capacity = Expedition.RackCapacity(player) }
end

-- get in and go: the escape chase starts now (the parents chase you; a knocked-out site sends its mate)
function Encounter.DriveOff(player: Player)
	local site = playerSite[player]
	local st = site and site.Players[player]
	if not st or st.Downed then return { Ok = false } end
	if isRider(player) then return { Ok = false, Err = "YOUR DRIVER HAS THE WHEEL" } end
	local hrp, root = hrpOf(player), Vehicles.Root(player)
	if not (hrp and root) or flat(hrp.Position - root.Position).Magnitude > 18 then return { Ok = false, Err = "GET TO YOUR ROVER" } end
	if st.Key then
		local key = st.Key
		local hk = flat(hrp.Position - key.Pos).Magnitude
		if hk > 60 then return { Ok = false, Err = "GRAB YOUR BOSS KEY FIRST - IT'S ON THE GROUND!" } end
		-- close enough: your crew throws it in the rover (never a dead end at the rover)
		local profile = Data.Peek(player)
		if profile then
			st.Key = nil
			profile.Keys[key.Boss] = (profile.Keys[key.Boss] or 0) + 1
			Data.Changed(player)
			Net.Fire(player, "KeyAuto", { Id = key.Id, Boss = key.Boss })
		end
	end
	if st.Holding then
		local r = Encounter.LoadEgg(player)
		if not r.Ok then Encounter.DropHeld(site, player) end
	end
	loadCompanionEggs(site, player)
	local carried = Expedition.CarriedCount(player)
	-- (a won boss fight: the boss egg is already in your bag and a boss den has no MAP - you can always drive off)
	local won = site.Boss and (site.Phase or 0) >= 4
	if carried == 0 and not won then return { Ok = false, Err = "LOAD AN EGG FIRST (OR OPEN THE MAP)" } end
	local takedown = site.Takedown == true
	local profile = Data.Peek(player)
	-- (eggs from an earlier nest ride along now - a chase you shake off sends you roaming on with them: driving off
	-- from a nest you took nothing from is still a chase, but no escape pay or quest step for it. 2026-10-14)
	if profile and not site.Boss and (takedown or Expedition.TakenHere(player) > 0) then
		Expedition.AddRunCoins(player, (takedown and E.TakedownCoins or E.EscapeCoins) * Config.EraTier(site.Era))
		if takedown then
			profile.Stats.Takedowns += 1
			Quests.Progress(player, "Takedown", { Site = site.Def.Id, Count = 1 })
		else
			profile.Stats.Escapes += 1
			Quests.Progress(player, "Escape", { Site = site.Def.Id, Count = 1 })
		end
		-- fights pay POWER too (2026-10-14: active players never have to stand on the trainer pad to keep up)
		pcall(function() require(script.Parent.Trainer).Reward(player, takedown and "Takedown" or "Escape") end)
		Data.Changed(player)
	end
	local opts = site.DriveOffOpts and site.DriveOffOpts(site) or nil
	local pursuer = site.Pursuer or site.Def.Species
	-- driving off from a boss fight that's still on gives up your share of it
	if site.Boss and site.Participants and (site.Phase or 0) < 4 then site.Participants[player] = nil end
	Encounter.Leave(player)
	Expedition.StartChase(player, site, {}, pursuer, takedown, opts)
	return { Ok = true }
end

local function startChase(site)
	site.State = "Chase"
	for _, e in pairs(site.Eggs) do e.Cfg:Destroy() end
	table.clear(site.Eggs)
	local pursuer = site.Def.Species
	local list = {}
	for plr, st in pairs(site.Players) do table.insert(list, { plr, st }) end
	for _, pair in ipairs(list) do
		local plr, st = pair[1], pair[2]
		local carried = st.Carried
		Encounter.Leave(plr)
		Expedition.StartChase(plr, site, carried, pursuer, site.Takedown)
	end
	-- the dinos leave with the chase; the site rearms
	removeActors(site)
	site.State = "Cooldown"
	site.Until = os.clock() + E.ResetTime
	publishSite(site)
end
Encounter.StartChaseFor = startChase

--------------------------------------------------------------------------------
-- player actions
--------------------------------------------------------------------------------
local function launcherOf(profile)
	local l = Config.Launchers[profile.Gear.Launcher] or Config.Launchers.Rookie
	-- (2026-10-14) your training makes every dart hit harder (Config.DartMult, x1..x2) - it replaced launcher levels
	local mult = Config.DartMult(profile.Gear, Dinos.BuddyList(profile), profile.TrainPower)
	return l, l.Damage * mult * (1 + (profile.Stars or 0) * Config.StarPerk.Damage)
end

function Encounter.FireAt(player: Player, actorId: number, charge: number?)
	local site = playerSite[player]
	if not site then return { Ok = false } end
	local st = site.Players[player]
	local profile = Data.Peek(player)
	local hrp = hrpOf(player)
	if not st or st.Downed or not profile or not hrp then return { Ok = false } end
	local l, dmg = launcherOf(profile)
	local now = os.clock()
	if now < st.NextDart then return { Ok = false } end
	-- magazine: holding the trigger down is never the answer. empty it, reload (or perfect-dodge to reload)
	local magSize = l.Mag or 6
	if now < (st.ReloadUntil or 0) then return { Ok = false, Reloading = true } end
	st.Mag = st.Mag or magSize
	st.NextDart = now + l.Rate * 0.9
	local a
	for _, x in ipairs(site.Actors) do if x.Id == actorId then a = x end end
	if not a or a.State == "KO" then return { Ok = false } end
	if a.State == "Exhausted" then return { Ok = false, Err = "RODEO TIME!" } end
	if not targetable(a) then return { Ok = false } end
	if flat(a.Pos - hrp.Position).Magnitude > l.Range then return { Ok = false, Err = "OUT OF RANGE" } end
	-- no cheese: nothing lands while the intro plays, through solid rock, or from outside a boss's arena
	if now < (site.FreezeUntil or 0) then return { Ok = false } end
	if site.Boss and site.Radius then
		local margin = site.Water and 22 or 10
		if flat(hrp.Position - site.Center).Magnitude > site.Radius + margin then return { Ok = false, Err = "GET INTO THE ARENA" } end
	end
	-- through a wall: the dart just thunks into it (no message, no calm - you see it hit the rock). It still costs
	-- the dart: spamming at a dino behind cover gets you nothing
	local open, wallAt = clearShot(hrp.Position + Vector3.new(0, 1.5, 0), a)
	if not open then
		st.Mag -= 1
		if st.Mag <= 0 then st.Mag = magSize st.ReloadUntil = now + E.Reload end
		st.Combo = 0
		return { Ok = true, Result = "Wall", Amount = 0, HitPos = wallAt, Combo = 0, Mag = st.Mag, Reload = math.max(0, (st.ReloadUntil or 0) - os.clock()) }
	end
	-- combo: keep hitting to calm them faster
	if now - st.ComboT <= E.ComboWindow then st.Combo = math.min(E.ComboMax, st.Combo + 1) else st.Combo = 1 end
	st.ComboT = now
	local ambush = a.State == "Unaware" and not site.Alarm
	local weak = a.State == "Recover" or a.State == "Dazed" or st.Charged == true or (a.PinUntil ~= nil and now < a.PinUntil) -- held by a death roll / a dazed boss
	st.Charged = nil
	-- a held (charged) shot hits harder; the hold time is checked here, not trusted from the client
	local held = math.clamp(charge or 0, 0, 1)
	-- (the client fills a full charge in 0.9 s of holding: that much time since the last shot is enough)
	if held > 0 and now - (st.LastShot or 0) < held * 0.9 - 0.15 then held = 0 end
	st.LastShot = now
	local _, dealt = powerMults(site, player)
	-- shooting from somewhere it can't get at you (up on a rock, behind something it can't get round): the darts
	-- go soft, quietly - and the dino is already coming to knock you out of there
	local camping = (st.PerchSince ~= nil and now - st.PerchSince > 1.5) or now < (st.UnreachUntil or 0)
	local total = dmg * (1 + E.ComboBonus * (st.Combo - 1)) * (weak and E.WeakSpotMult or 1) * (1 + held * 1.6) * (ambush and E.Sneak.AmbushMult or 1) * dealt * (camping and 0.3 or 1)
	-- a boss behind its guard (the Scythe King's crossed claws): darts glance off - and it answers
	local guarded = a.Guard == true and not weak
	if guarded then total *= 0.12 end
	st.Mag -= 1
	if st.Mag <= 0 then
		st.Mag = magSize
		st.ReloadUntil = now + E.Reload
	end
	-- a smart dino reads a dart coming and sidesteps it (only while it's closing in - never mid-swing, never an
	-- ambush, a weak-spot or a charged shot - and not twice in a row)
	local smart = E.Smart and E.Smart[site.Era]
	local dodgeP = (smart and smart.Dodge) or a.Stats.Dodge -- (an era's smart dinos, or a species that's quick on its feet)
	if dodgeP and a.State == "Chase" and not a.Boss and not a.Custom and not weak and not ambush and held < 0.5
		and now >= (a.NextSidestep or 0) and rng:NextNumber() < dodgeP then
		a.NextSidestep = now + ((smart and smart.DodgeGap) or 3)
		local away = flat(a.Pos - hrp.Position)
		local side = away.Magnitude > 0.1 and Vector3.new(-away.Unit.Z, 0, away.Unit.X) or Vector3.new(1, 0, 0)
		if rng:NextNumber() < 0.5 then side = -side end
		a.SidestepTo = a.Pos + side * 6
		a.SidestepUntil = now + 0.35
		st.Combo = 0
		fireSite(site, "SiteDart", { UserId = player.UserId, Actor = a.Id, Weak = false, Combo = 0, Amount = 0, Result = "Dodge", Heavy = false })
		return { Ok = true, Combo = 0, Weak = false, Result = "Dodge", Amount = 0, Calm = a.Calm, CalmMax = a.CalmMax, Heavy = false, Mag = st.Mag, Reload = math.max(0, (st.ReloadUntil or 0) - os.clock()) }
	end
	local result = Encounter.Calm(site, a, total, player, "Dart")
	if guarded and result ~= "Exhausted" and result ~= "KO" then
		result = "Guard"
		if site.OnGuardHit then task.spawn(site.OnGuardHit, site, a, player) end
	end
	-- launcher perks
	if l.Chain then
		local n = 0
		for _, o in ipairs(site.Actors) do
			if o ~= a and targetable(o) and flat(o.Pos - a.Pos).Magnitude < 16 and n < l.Chain then
				n += 1
				Encounter.Calm(site, o, total * 0.5, player, "Chain")
				fireSite(site, "DartChain", { From = a.Id, To = o.Id })
			end
		end
	end
	if l.Splash then
		for _, o in ipairs(site.Actors) do
			if o ~= a and targetable(o) and flat(o.Pos - a.Pos).Magnitude < l.Splash then Encounter.Calm(site, o, total * 0.6, player, "Splash") end
		end
	end
	fireSite(site, "SiteDart", { UserId = player.UserId, Actor = a.Id, Weak = weak, Combo = st.Combo, Amount = math.floor(total), Result = result, Heavy = held > 0.5 })
	return { Ok = true, Combo = st.Combo, Weak = weak, Result = result, Amount = math.floor(total), Calm = a.Calm, CalmMax = a.CalmMax, Heavy = held > 0.5, Ambush = ambush, Mag = st.Mag, Reload = math.max(0, (st.ReloadUntil or 0) - os.clock()) }
end

function Encounter.Dodge(player: Player)
	local site = playerSite[player]
	local st = site and site.Players[player]
	if not st or st.Downed then return { Ok = false } end
	local now = os.clock()
	local profile = Data.Peek(player)
	local cd = Config.Player.DodgeCooldown * ((profile and profile.Gear.Armor == "RaptorHide") and 0.8 or 1)
	-- (a little slack: the client starts its cooldown at the key press, we start ours when the request lands, so
	-- network jitter alone made about half of the back-to-back rolls come back refused - and refused rolls get
	-- no i-frames, while the client still plays the whole roll)
	if now < (st.NextDodge or 0) - 0.25 then return { Ok = false } end
	-- no rolling off a dino you're riding, or out of the sea boss's jaws (that turned every bite into a free
	-- perfect dodge)
	for _, a in ipairs(site.Actors) do if a.Rider == player then return { Ok = false } end end
	if site.Grab and site.Grab.Player == player then return { Ok = false } end
	st.NextDodge = math.max(now, st.NextDodge or 0) + cd
	-- untouchable for the first part of the roll (+ a little for the trip from your client), not all of it - and a
	-- roll never SHORTENS protection you already had (a revive's grace)
	st.Invuln = math.max(st.Invuln or 0, now + (Config.Player.DodgeInvuln or Config.Player.DodgeTime) + 0.08)
	st.DodgeUntil = st.Invuln
	fireSite(site, "PlayerAct", { UserId = player.UserId, Act = "Dodge" })
	return { Ok = true }
end

function Encounter.Gadget(player: Player, slot: number)
	local site = playerSite[player]
	local st = site and site.Players[player]
	local profile = Data.Peek(player)
	local hrp = hrpOf(player)
	if not st or st.Downed or not profile or not hrp then return { Ok = false } end
	local id = profile.Gear.Gadgets[slot]
	local info = id and Config.Gadgets[id]
	if not info then return { Ok = false } end
	local now = os.clock()
	if now < (st.Gadgets[id] or 0) then return { Ok = false, Err = "RECHARGING" } end
	st.Gadgets[id] = now + info.Cooldown
	fireSite(site, "PlayerAct", { UserId = player.UserId, Act = "Throw" })
	local p = hrp.Position
	if id == "Bait" then
		local spot = p + hrp.CFrame.LookVector * 14
		for _, a in ipairs(site.Actors) do
			if swayable(a) and flat(a.Pos - spot).Magnitude < 45 then
				a.Bait = spot
				a.DistractUntil = now + 4
				setState(a, "Distracted")
			end
		end
		fireSite(site, "GadgetFx", { Id = id, P = spot, UserId = player.UserId })
	elseif id == "Flare" then
		for _, a in ipairs(site.Actors) do
			if a.State ~= "KO" and flat(a.Pos - p).Magnitude < 16 then a.StunUntil = now + 2.5 end
		end
		fireSite(site, "GadgetFx", { Id = id, P = p, UserId = player.UserId })
	elseif id == "Earthshaker" then
		for _, a in ipairs(site.Actors) do
			if a.State ~= "KO" and not a.Herd and flat(a.Pos - p).Magnitude < 20 then
				a.StunUntil = now + 3
				-- 12% of a site dino's bar; a boss takes what six of YOUR darts would (a flat 12% of a boss was a few
				-- throws per phase, whatever your gear)
				local amount = a.CalmMax * 0.12
				if a.Boss then
					local _, dmg = launcherOf(profile)
					local _, dealt = powerMults(site, player)
					amount = math.min(amount, dmg * dealt * 6)
				end
				Encounter.Calm(site, a, amount, player, "Gadget")
			end
		end
		fireSite(site, "GadgetFx", { Id = id, P = p, UserId = player.UserId })
	end
	return { Ok = true, Cooldown = info.Cooldown }
end

function Encounter.Revive(player: Player, targetId: number)
	local site = playerSite[player]
	if not site then return { Ok = false } end
	local me = site.Players[player]
	local target = Players:GetPlayerByUserId(targetId)
	local ts = target and site.Players[target]
	if not me or me.Downed or not ts or not ts.Downed then return { Ok = false } end
	local a, b = hrpOf(player), target and hrpOf(target)
	if not a or not b or (a.Position - b.Position).Magnitude > 10 then return { Ok = false, Err = "GET CLOSER" } end
	-- (the prompt is a hold: nobody gets back up quicker than that hold takes)
	if os.clock() - (ts.DownAt or 0) < (Config.Player.ReviveTime or 2.2) * 0.8 then return { Ok = false } end
	if site.Boss then
		if (site.RevivePool or 0) <= 0 then return { Ok = false, Err = "NO REVIVES LEFT" } end
		site.RevivePool -= 1
		site.Folder:SetAttribute("Revives", site.RevivePool)
		-- (a revive counts toward your share of the win)
		local part = site.Participants and site.Participants[player]
		if type(part) == "table" then part.Score += 1 end
	end
	revive(site, target :: Player, 0.5)
	me.Contribution += 50
	return { Ok = true }
end

-- a toy ball thrown at a nest site: it arcs over, every dino near where it lands turns to look (the calm ones wander
-- over to sniff it), and your companion bounds after it and brings it back to your feet. Grab it again, or leave it
-- (it's gone after a few minutes).
local BallFolder = Runtime:FindFirstChild("Balls") or Instance.new("Folder")
BallFolder.Name = "Balls"
BallFolder.Parent = Runtime
local nextBall = 0
local balls = {} :: { [number]: any }
function Encounter.BallThrown(site, player: Player, target: Vector3)
	local hrp = hrpOf(player)
	if not hrp then return end
	local d = flat(target - hrp.Position)
	if d.Magnitude > 70 then target = hrp.Position + d.Unit * 70 end
	target = Vector3.new(target.X, groundY(site, target, site.Center.Y), target.Z)
	local T = math.clamp(flat(target - hrp.Position).Magnitude / 30, 0.55, 1.4)
	nextBall += 1
	local cfg = Instance.new("Configuration")
	cfg.Name = "Ball" .. nextBall
	cfg:SetAttribute("Id", nextBall)
	cfg:SetAttribute("Owner", player.UserId)
	cfg:SetAttribute("Site", site.Key)
	cfg:SetAttribute("From", hrp.Position + Vector3.new(0, 1.5, 0))
	cfg:SetAttribute("To", target)
	cfg:SetAttribute("T0", Workspace:GetServerTimeNow())
	cfg:SetAttribute("Flight", T)
	cfg:SetAttribute("State", "Flying")
	cfg:SetAttribute("P", target)
	cfg.Parent = BallFolder
	local ball = { Cfg = cfg, Id = nextBall, Owner = player, To = target, Pos = target, State = "Flying" }
	balls[nextBall] = ball
	local now = os.clock()
	-- dinos near where it lands look over (and calm ones go to sniff it): a distraction, not a disappearing trick
	for _, a in ipairs(site.Actors) do
		if swayable(a) and flat(a.Pos - target).Magnitude < Config.Balls.Radius then
			a.Bait = target
			a.DistractUntil = now + T + (site.Alarm and Config.Balls.FightDistract or Config.Balls.Distract)
			if a.State == "Unaware" or a.State == "Idle" then a.AfterDistract = a.State end
			if a.State ~= "Telegraph" and a.State ~= "Attack" then setState(a, "Distracted") end
		end
	end
	task.delay(T, function()
		if ball.State == "Flying" then ball.State = "Ground" cfg:SetAttribute("State", "Ground") end
	end)
	-- your companion goes after it
	for _, b in pairs(site.Buddies) do
		if b.Owner == player and not b.Downed and not b.Fallen and not b.Fetch then b.Fetch = ball break end
	end
	task.delay(Config.Balls.Despawn, function() balls[ball.Id] = nil cfg:Destroy() end)
end
function Encounter.PickBall(player: Player, id: number)
	local ball = balls[id]
	local hrp = hrpOf(player)
	if not ball or not hrp or ball.Owner ~= player or ball.State == "Flying" or ball.State == "Carried" then return { Ok = false } end
	if flat(ball.Pos - hrp.Position).Magnitude > 12 then return { Ok = false, Err = "GET CLOSER" } end
	balls[id] = nil
	ball.Cfg:Destroy()
	return Dinos.TakeBall(player)
end

-- revive a downed buddy (yours or a friend's): hold E next to it
function Encounter.ReviveBuddy(player: Player, buddyId: number)
	local site = playerSite[player]
	local me = site and site.Players[player]
	if not me or me.Downed then return { Ok = false } end
	local hrp = hrpOf(player)
	for _, b in pairs(site.Buddies) do
		if b.Cfg:GetAttribute("Id") == buddyId then
			if not b.Downed then return { Ok = false } end
			if not hrp or flat(hrp.Position - b.Pos).Magnitude > 11 then return { Ok = false, Err = "GET CLOSER" } end
			b.Downed = false
			b.HP = b.MaxHP * Config.Buddy.ReviveHP
			b.Cfg:SetAttribute("HP", math.floor(b.HP))
			b.Cfg:SetAttribute("State", "Follow")
			b.Next = os.clock() + 1
			me.Contribution += 30
			fireSite(site, "BuddyRevived", { Buddy = buddyId, Owner = b.Owner.UserId })
			return { Ok = true }
		end
	end
	return { Ok = false }
end

-- how far p is from a dino's BODY, not its middle (2026-10-14, user: the 32-stud Tidebreaker beached on the Maw
-- said GET CLOSER to someone standing right at its head - its middle was 16 away). The body is a capsule along its
-- length: the species' template extents x its Scale, the same numbers EncounterView's RODEO! prompt is placed with
local function bodyGap(a, p: Vector3): number
	local len, wide = bodySize(a.Species or "", a.Scale or 1)
	local r = wide * 0.35
	local half = math.max(0, len / 2 - r)
	local fwd = dirOf(a.Yaw or 0)
	local d = flat(p - a.Pos)
	local along = math.clamp(d:Dot(fwd), -half, half)
	return math.max(0, (d - fwd * along).Magnitude - r)
end
Encounter.BodyGap = bodyGap
Encounter.BodySize = bodySize
-- the RODEO! prompt opens 9 from the body's surface (EncounterView RODEO_REACH); the server allows a few more for
-- lag (you took a step, it heaved) - one rule for every species and size, land bosses too
local RODEO_REACH, RODEO_SLACK = 9, 5

-- the rodeo finisher: jump on the exhausted dino; the client plays the balance minigame
function Encounter.RodeoStart(player: Player, actorId: number)
	local site = playerSite[player]
	local st = site and site.Players[player]
	local hrp = hrpOf(player)
	if not st or st.Downed or not hrp then return { Ok = false } end
	for _, a in ipairs(site.Actors) do
		if a.Id == actorId and a.State == "Exhausted" then
			if bodyGap(a, hrp.Position) > RODEO_REACH + RODEO_SLACK then return { Ok = false, Err = "GET CLOSER" } end
			setState(a, "Rodeo")
			a.Cfg:SetAttribute("RodeoOpen", nil)
			a.Rider = player
			a.RodeoAt = os.clock()
			a.RodeoPulses, a.RodeoOut, a.RodeoPulseAt = 0, 0, 0
			st.Invuln = os.clock() + E.RodeoTime + 2
			fireSite(site, "Rodeo", { Actor = a.Id, UserId = player.UserId, Time = E.RodeoTime })
			return { Ok = true, Time = E.RodeoTime }
		end
	end
	return { Ok = false }
end

-- the ride as it happens: the client reports where the needle is four times a second; the server keeps its own
-- count of time spent out of the green, ends the ride the moment that's lost, and only accepts a win from a ride it
-- actually watched (a client can't just send "I won")
local function rodeoFail(site, a, player: Player)
	a.Rider = nil
	a.Calm = a.CalmMax * E.RodeoFailCalm
	a.Cfg:SetAttribute("Calm", a.Calm)
	setState(a, "Chase")
	a.NextAttack = os.clock() + 1.2
	fireSite(site, "RodeoEnd", { Actor = a.Id, Success = false, UserId = player.UserId })
	publishSite(site)
end
function Encounter.RodeoPulse(player: Player, actorId: number, x: number)
	local site = playerSite[player]
	if not site then return { Ok = false } end
	local now = os.clock()
	for _, a in ipairs(site.Actors) do
		if a.Id == actorId and a.State == "Rodeo" and a.Rider == player then
			if now - (a.RodeoPulseAt or 0) < 0.15 then return { Ok = true } end -- (one per beat)
			a.RodeoPulseAt = now
			a.RodeoPulses = (a.RodeoPulses or 0) + 1
			local u = math.clamp((now - (a.RodeoAt or now)) / E.RodeoTime, 0, 1)
			local half = 0.36 - u * 0.04
			if math.abs(math.clamp(x, -1, 1)) >= half then
				a.RodeoOut = (a.RodeoOut or 0) + 0.25
			else
				a.RodeoOut = math.max(0, (a.RodeoOut or 0) - 0.225)
			end
			if a.RodeoOut > 2.25 then rodeoFail(site, a, player) end
			return { Ok = true }
		end
	end
	return { Ok = false }
end

function Encounter.RodeoResult(player: Player, actorId: number, success: boolean)
	local site = playerSite[player]
	if not site then return { Ok = false } end
	for _, a in ipairs(site.Actors) do
		if a.Id == actorId and a.State == "Rodeo" and a.Rider == player then
			a.Rider = nil
			local held = os.clock() - (a.RodeoAt or 0)
			local watched = (a.RodeoPulses or 0) >= math.floor(E.RodeoTime * 4 * 0.6) and (a.RodeoOut or 0) <= 2.25
			if success and held >= E.RodeoTime * 0.85 and watched then
				site.Players[player].Contribution += 200
				fireSite(site, "RodeoEnd", { Actor = a.Id, Success = true, UserId = player.UserId })
				Encounter.KO(site, a)
			else
				a.Calm = a.CalmMax * E.RodeoFailCalm
				a.Cfg:SetAttribute("Calm", a.Calm)
				setState(a, "Chase")
				a.NextAttack = os.clock() + 1.2
				fireSite(site, "RodeoEnd", { Actor = a.Id, Success = false, UserId = player.UserId })
			end
			publishSite(site)
			return { Ok = true }
		end
	end
	return { Ok = false }
end

-- escape: grab from the nest → the alarm. Eggs spill, every dino goes wild, then the chase.
function Encounter.Grab(player: Player, site)
	if site.State ~= "Active" or site.Alarm or site.Boss then return end
	local st = site.Players[player]
	if not st or st.Downed then return end
	site.Alarm = true
	site.Enraged = true
	for _, a in ipairs(site.Actors) do
		if a.State == "Idle" then setState(a, "Chase") end
		a.NextAttack = os.clock() + 0.8
	end
	fireSite(site, "Alarm", { UserId = player.UserId, Name = player.DisplayName })
	Encounter.StartScramble(site, false)
end

--------------------------------------------------------------------------------
-- sites
--------------------------------------------------------------------------------
local function nestAnchor(zm: Model, nestId: number)
	for _, n in ipairs(zm:GetDescendants()) do
		if n:IsA("Model") and n:GetAttribute("NestId") == nestId then
			local core = n:FindFirstChild("NestCore", true) :: BasePart?
			local spots = {}
			for k = 1, 3 do
				local g = n:FindFirstChild("GuardSpot" .. k, true) :: BasePart?
				if g then spots[k] = g.Position - Vector3.new(0, g.Size.Y / 2, 0) end
			end
			return n, core, spots
		end
	end
	return nil, nil, {}
end

-- bosses register their dens here so they share the whole fight machinery
function Encounter.AddSite(site)
	local folder = Instance.new("Configuration")
	folder.Name = site.Key:gsub("/", "_")
	folder:SetAttribute("Key", site.Key)
	folder:SetAttribute("Era", site.Era)
	folder:SetAttribute("Site", site.Def.Id)
	folder:SetAttribute("Name", site.Def.Name)
	folder:SetAttribute("Species", site.Def.Species)
	folder:SetAttribute("Center", site.Center)
	folder:SetAttribute("Boss", site.Boss and true or nil)
	folder.Parent = SiteFolder
	site.Folder = folder
	site.Players, site.Count, site.Actors, site.Buddies, site.Eggs = {}, 0, {}, {}, {}
	sites[site.Key] = site
	publishSite(site)
	return site
end
Encounter.SetState = setState
Encounter.PublishActor = publishActor
Encounter.InShape = inShape
Encounter.HurtBuddy = hurtBuddy
Encounter.DashTime = DASH_TIME
-- one shaped blow landing on one hunter (shield companions, blinded dinos and dodge rolls all apply)
function Encounter.StrikePlayer(site, a, shape, plr: Player)
	strikePlayer(site, a, shape, plr, false)
end
-- a scripted blow (a boss move) landing now on everyone inside it; returns how many hunters it really hurt
function Encounter.LandShape(site, a, shape): number
	local n = 0
	for plr, st in pairs(site.Players) do
		local h = hrpOf(plr)
		if h and inShape(shape, h.Position) then
			local before = st.HP
			strikePlayer(site, a, shape, plr, false)
			if st.HP < before then n += 1 end
		end
	end
	for _, b in pairs(site.Buddies) do
		if not b.Downed and not b.Fallen and inShape(shape, b.Pos) then hurtBuddy(site, b, shape.Dmg * (site.DamageMult or 1)) end
	end
	fireSite(site, "Strike", { Actor = a.Id, Id = shape.Id, Key = shape.Key })
	return n
end
-- draw a scripted blow on the ground for everyone at the site (each gets its own Key, so several at once - the
-- roar's rings - each keep their own drawing until their own strike)
local nextShapeKey = 0
function Encounter.ShowShape(site, a, shape, time: number)
	nextShapeKey += 1
	shape.Key = "S" .. nextShapeKey
	fireSite(site, "Tele", {
		Actor = a.Id, Key = shape.Key, Id = shape.Id, Shape = shape.Shape, O = shape.O, Dir = shape.Dir, Len = shape.Len, Width = shape.Width,
		R = shape.R, Inner = shape.Inner, Angle = shape.Angle, Time = time, Reach = shape.Reach,
	})
end
Encounter.RemoveActors = removeActors
Encounter.PublishSite = publishSite
Encounter.RevivePlayer = revive
Encounter.HrpOf = hrpOf
Encounter.GroundY = groundY
Encounter.Hurt = hurt

function Encounter.SiteByKey(key: string)
	return sites[key]
end

-- a site with no nest model (free roam's WILD dinos, WildLife.luau): one dino on open ground, its egg dropped where it
-- goes down, the chase leaving on the nearest stretch of road. MoveSite puts it somewhere new (it rearms there)
function Encounter.MoveSite(site, center: Vector3)
	site.Center = center
	site.Spots = { center }
	site.Park = nil
	local route = RouteMath.get(site.Era)
	if route then
		local s0, x0 = route:Project(1, center)
		site.Variant, site.S, site.X = 1, s0, x0
	end
	site.Folder:SetAttribute("Center", center)
end
function Encounter.MakeSite(eraId: string, def, center: Vector3)
	local key = eraId .. "/" .. def.Id
	local folder = Instance.new("Configuration")
	folder.Name = key:gsub("/", "_")
	folder:SetAttribute("Key", key)
	folder:SetAttribute("Era", eraId)
	folder:SetAttribute("Site", def.Id)
	folder:SetAttribute("Name", def.Name)
	folder:SetAttribute("Species", def.Species)
	folder:SetAttribute("Wild", true)
	folder.Parent = SiteFolder
	local site = {
		Key = key, Era = eraId, Def = def, Center = center, Radius = 34, Spots = { center }, Model = nil,
		Variant = 1, S = 0, X = 0, Players = {}, Count = 0, Actors = {}, Buddies = {}, Eggs = {},
		State = "Idle", Folder = folder, Perches = {},
	}
	Encounter.MoveSite(site, center)
	rollMood(site)
	sites[key] = site
	publishSite(site)
	return site
end

function Encounter.Sites(eraId: string)
	local out = {}
	for _, s in pairs(sites) do if s.Era == eraId then table.insert(out, s) end end
	return out
end

local function buildSites()
	for _, era in ipairs(Config.Eras) do
		local zm = Workspace:FindFirstChild(era.Id)
		local route = RouteMath.get(era.Id)
		if not era.Sites or not zm or not route then continue end
		for _, def in ipairs(era.Sites) do
			local model, core, spots = nestAnchor(zm :: Model, def.Nest)
			if not core then warn("[Encounter] missing nest for", era.Id, def.Id) continue end
			local nest = nil
			for _, n in ipairs(route.Data.Nests) do if n.Id == def.Nest then nest = n end end
			if not nest then continue end
			-- the chase leaves on the first route variant that passes this nest
			local variant, s0 = 1, -1
			for vi = 1, #route.Data.Variants do
				if (nest.S[vi] or -1) >= 0 then variant, s0 = vi, nest.S[vi] break end
			end
			local center = (core :: BasePart).Position - Vector3.new(0, (core :: BasePart).Size.Y / 2 + 0.9, 0)
			local key = era.Id .. "/" .. def.Id
			local folder = Instance.new("Configuration")
			folder.Name = key:gsub("/", "_")
			folder:SetAttribute("Key", key)
			folder:SetAttribute("Era", era.Id)
			folder:SetAttribute("Site", def.Id)
			folder:SetAttribute("Name", def.Name)
			folder:SetAttribute("Species", def.Species)
			folder:SetAttribute("Center", center)
			folder.Parent = SiteFolder
			local site = {
				Key = key, Era = era.Id, Def = def, Center = center, Radius = 44, Spots = spots, Model = model,
				Variant = variant, S = s0, X = nest.X, Players = {}, Count = 0, Actors = {}, Buddies = {}, Eggs = {},
				State = "Idle", Folder = folder,
			}
			-- FLYER nests: the perches up in the trees over the nest (PerchSpot markers carry the nest's id)
			local perches = {}
			for _, d in ipairs((zm :: Instance):GetDescendants()) do
				if d:IsA("BasePart") and d:GetAttribute("Perch") and d:GetAttribute("NestId") == def.Nest and flat(d.Position - center).Magnitude < 40 then
					table.insert(perches, { Name = d.Name, P = d.Position })
				end
			end
			table.sort(perches, function(x, y) return x.Name < y.Name end)
			site.Perches = {}
			for i, pr in ipairs(perches) do site.Perches[i] = pr.P end
			rollMood(site)
			sites[key] = site
			-- the nest's grab prompt is the escape trigger
			local prompt = (core :: BasePart):FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function(plr)
					if playerSite[plr] == site then Encounter.Grab(plr, site) end
				end)
			end
			publishSite(site)
		end
	end
end

-- where a player's rover parks for a site: on the road you came in on, ParkBack behind the nest, at the verge on
-- the nest side. A spot with something solid on it, or where trees or a hill hide the rover from the nest (you'd
-- never find it again), moves to the nearest good one. Worked out once per site, so the drive there, the drop-off
-- and the chase all use the same spot.
-- (2026-10-14, user: "the car gets put in the floor, make it stay on the road") every spot is now checked on the real
-- map, not just the road's data: the road's line is flat across, but a banked bend, a hill that comes up over the
-- road (Spine River's shore climb) or a verge that drops away isn't - a rover put there sat half in the ground. A good
-- spot has every wheel on the ground at its own height (on the road itself, unless there's no road there at all),
-- nothing solid in the body, and room for the biggest rover (one spot per site for every body: the drive there, the
-- parking and the chase all agree). It's never inside another nest's reach (walking back to your rover pulled you into
-- that fight) and never inside its own (walking back to it is leaving the nest).
local PARK_W, PARK_L, PARK_H = 11.5, 23, 8 -- (Titan Transport 10.7 x 22.4 plus a little: whatever fits it fits them all)
local PARK_TOL = 0.4 -- how far off the ground a wheel may be (the road's merged tiles are within ~0.1 of its line)
local WHEEL_AT = { { 0.4, 0.4 }, { -0.4, 0.4 }, { 0.4, -0.4 }, { -0.4, -0.4 }, { 0, 0 } } -- (x, z) of the footprint
local parkRay = RaycastParams.new()
parkRay.FilterType = Enum.RaycastFilterType.Include
parkRay.RespectCanCollide = false -- leaves and ferns hide a rover too
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include
groundRay.RespectCanCollide = true -- (what a wheel stands on: grass tufts and flowers aren't ground)
groundRay.IgnoreWater = false -- (a sea lane's rover rides the water)
local bodyRoom = OverlapParams.new()
bodyRoom.FilterType = Enum.RaycastFilterType.Include
bodyRoom.RespectCanCollide = true
local function parkSeen(from: Vector3, to: Vector3): boolean
	local o = from
	for _ = 1, 4 do -- (invisible markers hide nothing: look straight through them)
		local hit = Workspace:Raycast(o, to - o, parkRay)
		if not hit then return true end
		if (hit.Instance :: BasePart).Transparency < 0.95 then return false end
		o = hit.Position + (to - o).Unit * 0.05
	end
	return false
end
local function parkVisible(site, cf: CFrame): boolean
	-- seen from the nest at camera height: its nose, middle or tail is enough (a signpost doesn't hide it)
	local eye = site.Center + Vector3.new(0, 8, 0)
	for _, z in ipairs({ -6, 0, 6 }) do
		if parkSeen(eye, (cf * CFrame.new(0, 3, z)).Position) then return true end
	end
	return false
end
local function parkFilters(era: string): boolean
	local zm = Workspace:FindFirstChild(era)
	if not zm then return false end
	parkRay.FilterDescendantsInstances = { zm }
	groundRay.FilterDescendantsInstances = { zm, Workspace.Terrain }
	bodyRoom.FilterDescendantsInstances = { zm }
	return true
end
-- every wheel (and the middle) on something solid right at its height; how many of them are on the road itself
local function parkGround(cf: CFrame): (boolean, number)
	local roads = 0
	for _, w in ipairs(WHEEL_AT) do
		local p = (cf * CFrame.new(w[1] * PARK_W, 0, w[2] * PARK_L)).Position
		local hit = Workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -9, 0), groundRay)
		if not hit or math.abs(hit.Position.Y - p.Y) > PARK_TOL then return false, 0 end
		if hit.Instance:FindFirstAncestor("Roads") then roads += 1 end
	end
	return true, roads
end
local function parkBodyClear(cf: CFrame): boolean
	return #Workspace:GetPartBoundsInBox(cf * CFrame.new(0, 0.9 + PARK_H / 2, 0), Vector3.new(PARK_W, PARK_H, PARK_L), bodyRoom) == 0
end
-- inside some other nest's reach (or this one's own): no parking there
local function parkInReach(site, p: Vector3, own: boolean): boolean
	for _, s in pairs(sites) do
		if s.Era ~= site.Era or s.Boss or not s.Center or (s.Def and s.Def.Wild) then continue end
		if s == site and not own then continue end
		if flat(p - s.Center).Magnitude < (s.Radius or 44) + (s == site and 4 or 12) then return true end
	end
	return false
end
-- the nearest good spot to sMid along the road (4 studs nearer, then 4 further back...), trying each x across it.
-- Passes: on the road and seen from the site; on the road; then any solid ground (a ford, a sea lane, a bridge end)
local function parkSearch(route, site, vi: number, sMid: number, lo: number, hi: number, xsAt: (s: number) -> { number }, opts): (number?, number?)
	local len = route:Length(vi)
	lo, hi = math.max(4, lo), math.min(len - 6, hi)
	for pass = opts.Seen and 1 or 2, 3 do
		for k = 0, math.ceil(math.max(hi - sMid, sMid - lo, 0) / 4) do
			for _, s in ipairs(k == 0 and { sMid } or { sMid + k * 4, sMid - k * 4 }) do
				if s < lo or s > hi then continue end
				for _, x in ipairs(xsAt(s)) do
					local cf = route:Frame(vi, s, x)
					local ok, roads = parkGround(cf)
					if not ok or (pass < 3 and roads < 4) or not parkBodyClear(cf) then continue end
					if opts.Reach and parkInReach(site, cf.Position, opts.Own == true) then continue end
					if pass == 1 and not parkVisible(site, cf) then continue end
					return s, x
				end
			end
		end
	end
	return nil, nil
end
-- across the road: the verge on the given side first (the biggest rover just inside the edge), then nearer the middle
local function parkXs(route, vi: number, side: number): (s: number) -> { number }
	return function(s: number)
		local edge = math.max(0, route:HalfWidth(vi, s) - PARK_W / 2 - 1)
		return { side * edge, side * edge * 0.5, 0 }
	end
end
local function parkSpot(route, site, vi: number, s0: number, x0: number, sMid: number, lo: number, hi: number, xsAt, opts)
	local s, x = nil, nil
	if parkFilters(site.Era) then s, x = parkSearch(route, site, vi, sMid, lo, hi, xsAt, opts) end
	if not s then
		-- nothing passes (a map without its road built yet): the old spot, never no spot
		warn("[Encounter] no clear park spot for", site.Key, "- using the road's own")
		s, x = s0, x0
	end
	return { CF = route:Frame(vi, s :: number, x :: number), S = s :: number, X = x :: number }
end
function Encounter.ParkCFrame(site): (CFrame, number, number)
	local route = RouteMath.get(site.Era)
	local vi = site.Variant or 1
	if site.Boss then
		if (site.Phase or 0) >= 3 and site.FinalS then
			-- the final stand: park just short of the final arena (where the chase after it sets off from)
			if not site.FinalPark then
				local s0, x0 = math.max(4, site.FinalS - 2), site.FinalX or 0
				local side = x0 >= 0 and 1 or -1
				site.FinalPark = parkSpot(route, site, vi, s0, x0, s0, s0 - 24, s0, function(s: number)
					local xs = parkXs(route, vi, side)(s)
					table.insert(xs, 1, math.clamp(x0, -math.abs(xs[1]), math.abs(xs[1])))
					return xs
				end, {})
			end
			return site.FinalPark.CF, site.FinalPark.S, site.FinalPark.X
		end
		if not site.Park then
			local s0 = math.max(4, site.S - 14)
			local side = (site.X or 0) >= 0 and 1 or -1
			site.Park = parkSpot(route, site, vi, s0, side * (route:HalfWidth(vi, s0) - 4), s0, site.S - 40, site.S - 6, parkXs(route, vi, side), { Reach = true })
		end
		return site.Park.CF, site.Park.S, site.Park.X
	end
	if not site.Park then
		local side = (site.X or 0) >= 0 and 1 or -1
		local wild = site.Def and site.Def.Wild
		-- (a wild one has no road of its own: the stretch nearest it, a little back)
		local far = wild and math.max(4, site.S - 40) or math.max(4, site.S - E.ParkBack)
		local lo, hi = far - 20, site.S - 30
		if wild then lo, hi = far - 30, site.S + 30 end
		site.Park = parkSpot(route, site, vi, far, side * (route:HalfWidth(vi, far) - 4), far, lo, hi, parkXs(route, vi, side), { Seen = true, Reach = true, Own = true })
	end
	return site.Park.CF, site.Park.S, site.Park.X
end

-- EVERY PLAYER THEIR OWN PLACE (2026-10-14): two hunters at one nest had their rovers parked inside each other on the
-- one park spot. Place 0 is the park spot itself; each further place is the nearest good spot (the same checks) at
-- or behind it - side by side across the road first, then back down it - that doesn't overlap an earlier place.
-- Worked out once per site (a den's final arena keeps its own line). Expedition hands the places out (siteSlot).
local SLOT_BACK = 120 -- (how far back down the road the line may run)
local function slotFree(cf: CFrame, taken): boolean
	for _, t in ipairs(taken) do
		local lp = t.CF:PointToObjectSpace(cf.Position)
		if math.abs(lp.X) < PARK_W + 0.5 and math.abs(lp.Z) < PARK_L + 1 then return false end
	end
	return true
end
function Encounter.ParkSlot(site, k: number): (CFrame, number, number)
	local cf0, s0, x0 = Encounter.ParkCFrame(site)
	if k <= 0 then return cf0, s0, x0 end
	local final = site.Boss and (site.Phase or 0) >= 3 and site.FinalS
	local list = final and site.FinalSlots or site.Slots
	if not list or list[1].S ~= s0 or list[1].X ~= x0 then
		list = { { CF = cf0, S = s0, X = x0 } }
		if final then site.FinalSlots = list else site.Slots = list end
	end
	if list[k + 1] then return list[k + 1].CF, list[k + 1].S, list[k + 1].X end
	local route = RouteMath.get(site.Era)
	local vi = site.Variant or 1
	local filters = parkFilters(site.Era)
	for i = #list, k do
		local found = nil
		if filters then
			local side = x0 >= 0 and 1 or -1
			for s = s0, math.max(4, s0 - SLOT_BACK), -4 do
				local edge = math.max(0, route:HalfWidth(vi, s) - PARK_W / 2 - 1)
				for _, x in ipairs({ side * edge, -side * edge, side * edge * 0.5, -side * edge * 0.5, 0 }) do
					local cf = route:Frame(vi, s, x)
					if not slotFree(cf, list) then continue end
					local ok = parkGround(cf)
					if ok and parkBodyClear(cf) and not parkInReach(site, cf.Position, not site.Boss) then found = { CF = cf, S = s, X = x } break end
				end
				if found then break end
			end
		end
		if not found then
			-- (no room left that passes: one more rover length back on the road, never on top of another)
			local last = list[#list]
			local s = math.max(4, last.S - (PARK_L + 2))
			found = { CF = route:Frame(vi, s, last.X), S = s, X = last.X }
		end
		list[i + 1] = found
	end
	return list[k + 1].CF, list[k + 1].S, list[k + 1].X
end

-- FREE ROAM (2026-10-14, user: "getting out and then sneaking up leaves the car back behind ... the car should come a
-- little closer"): where your rover pulls up when you walk into a fight with a wild dino out on open ground, far from
-- any road: a clear, level patch of ground just outside its reach, on the side you came from, the rover facing back the
-- way it came (ready to drive off), never within a rover's length of `avoid` (other hunters' rovers). nil = the road's
-- park places are as good (a nest or den always uses those: Encounter.ParkSlot).
function Encounter.RoamParkCFrame(site, from: Vector3?, avoid: { Vector3 }?): CFrame?
	if not (site.Def and site.Def.Wild) or not site.Center then return nil end
	local road = Encounter.ParkCFrame(site)
	local r0 = (site.Radius or 34)
	if flat(road.Position - site.Center).Magnitude <= r0 + 50 then return nil end
	if not parkFilters(site.Era) then return nil end
	local c = site.Center
	local toward = from and flat(from - c) or Vector3.zero
	local a0 = toward.Magnitude > 1 and math.atan2(toward.X, toward.Z) or 0
	for _, r in ipairs({ r0 + 8, r0 + 16, r0 + 26 }) do
		for k = 0, 11 do -- (the side you came from first, then round both ways)
			local a = a0 + (k % 2 == 0 and 1 or -1) * math.ceil(k / 2) * math.pi / 6
			local p = c + Vector3.new(math.sin(a), 0, math.cos(a)) * r
			local near = false
			for _, o in ipairs(avoid or {}) do if flat(o - p).Magnitude < PARK_L then near = true break end end
			if near then continue end
			local hit = Workspace:Raycast(Vector3.new(p.X, c.Y + 14, p.Z), Vector3.new(0, -30, 0), groundRay)
			if not hit or hit.Material == Enum.Material.Water or math.abs(hit.Position.Y - c.Y) > 6 then continue end
			local out = Vector3.new(math.sin(a), 0, math.cos(a))
			local cf = CFrame.lookAt(hit.Position, hit.Position + out)
			-- level enough: every wheel's ground within a stud of the others; it rests on the highest (never sunk)
			local lo, hi, ok = math.huge, -math.huge, true
			for _, w in ipairs(WHEEL_AT) do
				local q = (cf * CFrame.new(w[1] * PARK_W, 0, w[2] * PARK_L)).Position
				local h = Workspace:Raycast(q + Vector3.new(0, 5, 0), Vector3.new(0, -11, 0), groundRay)
				if not h or h.Material == Enum.Material.Water then ok = false break end
				lo, hi = math.min(lo, h.Position.Y), math.max(hi, h.Position.Y)
			end
			if not ok or hi - lo > 1 then continue end
			cf = cf + Vector3.new(0, hi - cf.Position.Y, 0)
			if parkBodyClear(cf) and not parkInReach(site, cf.Position, true) then return cf end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
function Encounter.Start(deps)
	Data, Net, Vehicles, Dinos, Quests, Expedition = deps.Data, deps.Net, deps.Vehicles, deps.Dinos, deps.Quests, deps.Expedition
	buildSites()
	Net.On("FireAt", function(player, args) return Encounter.FireAt(player, tonumber(args.Id) or 0, tonumber(args.Charge)) end)
	Net.On("Dodge", function(player) return Encounter.Dodge(player) end)
	Net.On("Gadget", function(player, args) return Encounter.Gadget(player, math.clamp(tonumber(args.Slot) or 1, 1, Config.GadgetSlots)) end)
	Net.On("Revive", function(player, args) return Encounter.Revive(player, tonumber(args.UserId) or 0) end)
	-- down and nobody's coming: GIVE UP skips the wait (the same faint the timer would bring - 2026-10-14)
	Net.On("GiveUp", function(player)
		local site = playerSite[player]
		local st = site and site.Players[player]
		if not (st and st.Downed) then return { Ok = false } end
		if site.Boss and (site.Phase or 0) >= 4 then return { Ok = false } end -- (the fight's already won: you'll be helped up)
		task.spawn(require(script.Parent.Expedition).Faint, player)
		return { Ok = true }
	end)
	Net.On("ReviveBuddy", function(player, args) return Encounter.ReviveBuddy(player, tonumber(args.Id) or 0) end)
	Net.On("PickSiteBall", function(player, args) return Encounter.PickBall(player, tonumber(args.Id) or 0) end)
	Net.On("RodeoStart", function(player, args) return Encounter.RodeoStart(player, tonumber(args.Id) or 0) end)
	Net.On("RodeoResult", function(player, args) return Encounter.RodeoResult(player, tonumber(args.Id) or 0, args.Success == true) end)
	Net.On("RodeoPulse", function(player, args) return Encounter.RodeoPulse(player, tonumber(args.Id) or 0, tonumber(args.X) or 0) end)
	Net.On("PickEgg", function(player, args) return Encounter.PickEgg(player, tonumber(args.Id) or 0) end)
	Net.On("TakeRackEgg", function(player, args)
		local i = tonumber(args.Index)
		if not i or i ~= math.floor(i) or i < 1 then return { Ok = false } end
		return Encounter.TakeRackEgg(player, i)
	end)
	Net.On("PutDownEgg", function(player) return Encounter.PutDown(player) end)
	Net.On("PickKey", function(player, args) return Encounter.PickKey(player, tonumber(args.Id) or 0) end)
	Net.On("LoadEgg", function(player) return Encounter.LoadEgg(player) end)
	Net.On("DriveOff", function(player) return Encounter.DriveOff(player) end)
	Net.On("DropEggHere", function(player)
		local site = playerSite[player]
		if site then Encounter.DropHeld(site, player) end
		return { Ok = true }
	end)
	Net.On("IntroDone", function(player)
		local site = playerSite[player]
		if not site then return { Ok = false } end
		Encounter.IntroFinished(site, player)
		caughtHit(site, player)
		return { Ok = true }
	end)
	Players.PlayerRemoving:Connect(function(p) Encounter.Leave(p) end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end
		local step = acc
		acc = 0
		local now = os.clock()
		for _, site in pairs(sites) do
			local ok, err = pcall(function()
				if site.State == "Cooldown" and now >= (site.Until or 0) and not site.Boss then
					site.State = "Idle"
					removeActors(site)
					for _, e in pairs(site.Eggs) do e.Cfg:Destroy() end
					table.clear(site.Eggs)
					site.EggsMade = 0
					if site.OnRearm then site.OnRearm(site) end -- (a wild dino turns up somewhere else)
					rollMood(site)
					spawnResidents(site)
					site.Takedown, site.Alarm, site.Enraged = nil, nil, nil
					publishSite(site)
				elseif site.State == "Idle" and #site.Actors == 0 and site.Def.Kind ~= "Boss" then
					spawnResidents(site)
				end
				if site.Tick then site.Tick(site, step) end
				local players = alivePlayers(site)
				for _, a in ipairs(site.Actors) do tickActor(site, a, step, players) end
				tickBuddies(site, step)
				-- not really here any more (respawned / teleported to camp, run gone): out of this fight
				-- a SPRINT buddy (Gallimimus) here: everyone at this nest runs faster (EncounterView reads SpeedBuff)
				local sprint = 0
				for _, b in pairs(site.Buddies) do
					if not b.Downed and not b.Fallen and b.Dino then
						local role = Config.BuddyRoleOf(b.Dino.Species)
						if role.Sprint then sprint = math.max(sprint, role.Sprint) end
					end
				end
				for plr in pairs(site.Players) do
					local want = sprint > 0 and (1 + sprint) or nil
					if plr:GetAttribute("SpeedBuff") ~= want then plr:SetAttribute("SpeedBuff", want) end
				end
				-- who's perched up on something (a rock, a log, a rover roof) and since when
				for plr, pst in pairs(site.Players) do
					local h = hrpOf(plr)
					local ph: number? = 0
					if h and not pst.Downed then ph = perchHeight(site, h) end
					if ph == nil then
						-- (mid-jump: keep whatever it was)
					elseif ph > 3.5 then
						pst.PerchSince = pst.PerchSince or os.clock()
					else
						pst.PerchSince = nil
					end
				end
				local stale = {}
				for plr in pairs(site.Players) do
					local h = hrpOf(plr)
					-- (a carpool rider has no run of their own: riding in the driver's counts)
					local inRun = Expedition.InRun and Expedition.InRun(plr) or Expedition.Get(plr) ~= nil
					if not plr.Parent or not inRun or (h and flat(h.Position - site.Center).Magnitude > 900) then table.insert(stale, plr) end
				end
				for _, plr in ipairs(stale) do
					if plr.Parent and Expedition.Get(plr) and site.Boss and (site.Phase or 0) >= 4 then
						-- (a WON boss fight, wandered off exploring: nothing to punish - the egg goes on your rack (Leave) and
						-- the run's orphan rule has you roaming again. A faint here lost the boss egg - 2026-10-14)
						Encounter.Leave(plr)
					elseif plr.Parent and Expedition.Get(plr) then
						-- (wandered off for good: the faint's black, home, WokeUp. A bare Abort + WokeUp left you standing
						-- out in the era with the camp's light on and your rover held there - 2026-10-14)
						Encounter.Leave(plr)
						task.spawn(Expedition.Faint, plr)
					elseif plr.Parent and isRider(plr) and Expedition.Reseat then
						Expedition.Reseat(plr)
					else
						Encounter.Leave(plr)
					end
				end
				-- downed timers: nobody came in time, so you're carried home (the expedition is over)
				local fainted = {}
				for plr, st in pairs(site.Players) do
					if st.Downed and now - (st.DownAt or now) >= Config.Player.DownedTime and not (site.Boss and (site.Phase or 0) >= 4) then table.insert(fainted, plr) end
				end
				for _, plr in ipairs(fainted) do
					local Expedition = require(script.Parent.Expedition)
					task.spawn(Expedition.Faint, plr)
				end
				-- an empty site calms down (a boss den manages itself)
				if (site.State == "Active" or site.State == "Scramble") and site.Count == 0 and not site.Boss then site.State = "Cooldown" site.Until = now + 4 end
			end)
			if not ok then warn("[Encounter] site tick error", site.Key, err) end
		end
	end)
end

return Encounter
