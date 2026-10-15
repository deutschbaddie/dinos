--[[
	Bosses — each era's ruler. The den is an Encounter site with phases on top:

	  Open      a server-wide event (every Config.BossEventEvery) or a Boss Key summon opens the den for joiners
	  Phase 1   on foot in the den: the ruler + her pack. While two or more of the pack are up she's shielded;
	            she perches on the ledges, screeches the pack back in, and leap-slams whoever she's watching
	  Phase 2   at 40% calm she flees: everyone is pulled into their rover for the chase; darts that land on her
	            in any rover add to her shared calm
	  Phase 3   the final stand at the arena down the road: enraged, faster; at 85% the rodeo finisher knocks her out
	  Victory   materials, a boss egg (the best odds), coins, mastery stars, the trophy, then a short ride out

	Tiers (Normal, Hard, Nightmare, Apex n) scale her calm, damage and the rewards. Downed players share a
	revive pool (3 + 1 per player, +1 per late joiner).

	Multiplayer: any live phase can be joined from camp (BossHype card / Time Gate) or the era map. Phase 1 and 3
	joiners land on foot in the arena, phase 2 joiners go straight into the chase. Everyone who helped (Participants,
	scored by calm dealt + revives) shares the win; a fight nobody is in any more resets after ABANDON seconds.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local RouteMath = require(ReplicatedStorage.DinoExpedition.Game.RouteMath)

local Bosses = {}
local SeaKing = require(script.Parent.SeaKing) -- sea rulers (Config.Bosses[id].Water)
local LandKings = require(script.Parent.LandKings) -- every land ruler's signature move
Bosses.OnClear = nil :: ((Player, string, number, number) -> ())?
local Data, Net, Dinos, Quests, Encounter, Expedition, Plots, Vehicles
local rng = Random.new()
local dens = {} :: { [string]: any } -- boss id -> den site

-- used only if a ruler's species has no attack set in Config.Combat
local QUEEN_ATTACKS = {
	{ Id = "Pounce", Shape = "Line", Len = 26, Width = 6, Tele = 0.8, Dmg = 26, Dash = true },
	{ Id = "Rake", Shape = "Cone", Len = 12, Angle = 80, Tele = 0.6, Dmg = 20 },
	{ Id = "Screech", Shape = "Ring", Radius = 22, Inner = 7, Tele = 1.0, Dmg = 14 },
}

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end

local function marker(zm: Instance, name: string): BasePart?
	local m = zm:FindFirstChild(name, true)
	return m and m:IsA("BasePart") and m or nil
end

-- who chases you home after a ruler fight: her own era's guards
function Bosses.Escort(den): string
	local era = Config.Era(den.Era)
	local first = era and era.Sites and era.Sites[1]
	return first and first.Species or "Velociraptor"
end

-- the boss den in an era (free roam walks into it)
function Bosses.DenFor(era: string)
	for _, den in pairs(dens) do if den.Era == era then return den end end
	return nil
end

function Bosses.SiteByKey(key: string)
	for _, d in pairs(dens) do if d.Key == key then return d end end
	return nil
end

function Bosses.CanJoin(player: Player, den): (boolean, string?)
	if den.Phase == 0 then return false, "THE BOSS IS ASLEEP - WAIT FOR THE EVENT OR USE A BOSS KEY" end
	if den.Phase >= 4 then return false, "THAT FIGHT JUST ENDED - CATCH THE NEXT ONE" end
	-- any live phase is joinable: the den (1), the chase (2) or the final stand (3)
	local profile = Data.Peek(player)
	if not profile then return false, nil end
	if not profile.Unlocked[den.Era] then return false, "THAT ERA IS LOCKED" end
	return true, nil
end

local function queenOf(den)
	for _, a in ipairs(den.Actors) do if a.Boss then return a end end
	return nil
end

local function minions(den): number
	local n = 0
	for _, a in ipairs(den.Actors) do if a.Minion and a.State ~= "KO" then n += 1 end end
	return n
end

-- a fight nobody is in any more (everyone left, quit or got sent home) resets after this long, so a den never sticks
local ABANDON = 20

-- everyone who has helped this fight (in the den, in the chase, at the final stand); Score is how much calm they dealt
local function enlist(den, player: Player)
	if not den.Participants[player] then den.Participants[player] = { Score = 0, At = os.clock() } end
end

-- participants still in the game and still out on a run (on foot in the den, or driving the chase)
local function hunters(den): number
	local n = 0
	for plr in pairs(den.Participants) do
		if plr.Parent and Expedition.InRun(plr) then n += 1 end
	end
	return n
end

local function spawnMinion(den)
	local a = math.random() * math.pi * 2
	local p = den.Center + Vector3.new(math.cos(a) * 20, 0, math.sin(a) * 20)
	local m = Encounter.NewActor(den, "Velociraptor", Vector3.new(p.X, Encounter.GroundY(den, p, den.Center.Y), p.Z), { Minion = true, Calm = 55 })
	Encounter.SetState(m, "Chase")
	return m
end

--------------------------------------------------------------------------------
-- opening, phases, victory
--------------------------------------------------------------------------------
function Bosses.Open(id: string, tier: number, by: Player?)
	local den = dens[id]
	if not den or den.Phase ~= 0 then return false end
	local boss = Config.Bosses[id]
	local t = Config.BossTier(tier)
	den.Tier = tier
	den.TierInfo = t
	den.CalmMult = t.Calm
	den.DamageMult = t.Damage
	den.Phase = 1
	den.State = "Active"
	den.OpenedAt = os.clock()
	den.Until = os.clock() + Config.BossEventWindow
	den.Started = nil
	den.Participants = {}
	den.ParkSlots = {}
	den.ReviveGiven = {} -- (userIds that already brought their spare revive to this fight)
	den.Fight = (den.Fight or 0) + 1 -- stale chase callbacks from an earlier fight check this
	den.EmptySince = nil
	den.Folder:SetAttribute("Hunters", 0)
	den.Folder:SetAttribute("Phase", 1)
	Encounter.PublishSite(den)
	Net.FireAll("BossEvent", {
		Boss = id, Name = boss.Name, Era = boss.Era, Tier = t.Name, Site = den.Key, Until = Config.BossEventWindow,
		By = by and by.DisplayName or nil,
	})
	return true
end

local function beginFight(den)
	local boss = Config.Bosses[den.BossId]
	den.Started = os.clock()
	den.Folder:SetAttribute("Started", true)
	den.RevivePool = 3 + den.Count
	den.Folder:SetAttribute("Revives", den.RevivePool)
	den.ReviveGiven = den.ReviveGiven or {}
	for plr in pairs(den.Players) do den.ReviveGiven[plr.UserId] = true end
	local stats = Config.Combat[boss.Species]
	local q = Encounter.NewActor(den, boss.Species, den.Center + Vector3.new(0, 0, 0), {
		Boss = true, Name = boss.Name, Calm = boss.Calm, Scale = boss.Scale, Speed = (stats.Speed or 14) * 0.95,
	})
	-- its own species' attack set (rulers are species that never appear at the era's sites)
	q.Attacks = (stats and stats.Attacks) or QUEEN_ATTACKS
	q.Rodeo = true
	q.Stats = { Speed = q.Speed, Gap = { 1.3, 2.2 }, Attacks = q.Attacks, Recover = 1.4 }
	q.NextPerch = os.clock() + 32 -- after the intro (IntroDone pulls this in)
	Encounter.SetState(q, "Chase")
	if boss.Water then SeaKing.Begin(den, q) else LandKings.Begin(den, q) end
	if boss.Pack then
		-- (a pack ruler: shielded while its pack is up)
		for _ = 1, 3 do spawnMinion(den) end
		den.Shield = true
	end
	Encounter.FireSite(den, "BossIntro", { Boss = den.BossId, Name = boss.Name, Title = boss.Title, Tier = den.TierInfo.Name, Actor = q.Id })
	-- everyone freezes for the intro cutscene
	for _, a in ipairs(den.Actors) do a.NextAttack = os.clock() + 40 end
	den.FreezeUntil = os.clock() + 40 -- the mystery -> reveal intro; IntroDone lets them loose (40 s safety cap: the longest reveal + its waits run ~27 s)
	Encounter.HoldForIntro(den, q) -- (when every hunter here has finished or skipped it; anyone right in its face takes the hit)
end

-- one hunter's rover gives chase (everyone in the den when she flees, and anyone who joins mid-chase)
local function chaseFor(den, plr: Player)
	enlist(den, plr)
	local boss = Config.Bosses[den.BossId]
	local fight = den.Fight
	Expedition.StartChase(plr, den, {}, boss.Species, false, {
		Boss = { Name = boss.Name, Boss = true, Calm = 9999, Scale = boss.Scale * 0.8, Count = (boss :: any).Pack and 3 or 1, Runner = true },
		Rolling = 40, -- (you're already moving when the chase starts: it's out ahead and you're after it)
		StopS = den.FinalS,
		OnStop = function(run) Bosses.ArriveFinal(plr, den, fight) end,
		OnDart = function(run, result, c)
			if not (c and c.Boss and result ~= "None") then return end
			if den.Fight ~= fight or den.Phase ~= 2 then return end -- (that chase outlived its fight)
			local q = queenOf(den)
			if not q then return end
			-- every rover's darts calm the same boss
			local _, dealt = Encounter.PowerMults(den, plr)
			local amount = q.CalmMax * 0.012 * dealt
			q.Calm = math.min(q.CalmMax * 0.75, q.Calm + amount)
			q.Cfg:SetAttribute("Calm", q.Calm)
			local p = den.Participants[plr]
			if p then p.Score += amount end
			Encounter.PublishSite(den)
			return { Pct = math.floor(q.Calm / q.CalmMax * 100 + 0.5) }
		end,
	})
end

local function toChase(den)
	-- phase 2: she flees down the road; every rover gives chase
	if den.Water then SeaKing.Release(den, "Lost") SeaKing.Reset(den) end
	den.Phase = 2
	den.Folder:SetAttribute("Phase", 2)
	local boss = Config.Bosses[den.BossId]
	local q = queenOf(den)
	LandKings.Cancel(den, q)
	if q then
		q.Custom = true
		q.Cfg:SetAttribute("Hidden", true)
		Encounter.SetState(q, "Hidden")
	end
	for _, a in ipairs(den.Actors) do if a.Minion then a.Cfg:Destroy() end end
	for i = #den.Actors, 1, -1 do if den.Actors[i].Minion then table.remove(den.Actors, i) end end
	den.Shield = false
	Encounter.FireSite(den, "BossPhase", { Phase = 2, Name = boss.Name })
	local players = {}
	for plr in pairs(den.Players) do table.insert(players, plr) end
	task.wait(3.2) -- the flee cutscene
	-- riders first, out of the den without a word (their share stays): their driver's StartChase seats them, and its
	-- Reseat -> Bosses.Leave found them still standing in the den and took the share they'd earned. 2026-10-14
	for _, plr in ipairs(players) do
		if den.Players[plr] and Encounter.IsRider(plr) then Encounter.Leave(plr) end
	end
	for _, plr in ipairs(players) do
		-- (anyone who quit or backed out to the map during the cutscene stays out)
		if not (plr.Parent and Expedition.InRun(plr) and den.Players[plr]) then continue end
		if Encounter.IsRider(plr) then continue end -- (a rider goes with their driver: its StartChase seats them)
		Encounter.Leave(plr)
		chaseFor(den, plr)
	end
end

-- every hunter's rover gets its own place in a line back down the road from the den's park spot (2026-10-14: every
-- rover was put on the one spot - two hunters' rovers stacked inside each other and shoved one off, and the friend
-- whose rover went flying "couldn't take the egg, the car's not theirs"). A place is kept for the whole fight
local SLOT = 14
local function slotCF(den, k: number): CFrame
	local park, s, x = Encounter.ParkCFrame(den)
	if k == 0 then return park end
	local route = RouteMath.get(den.Era)
	if route and typeof(s) == "number" and typeof(x) == "number" then
		return route:Frame(den.Variant, math.max(4, s - k * SLOT), x)
	end
	return park * CFrame.new(0, 0, k * SLOT)
end
local function parkSlot(den, player: Player): CFrame
	den.ParkSlots = den.ParkSlots or {}
	local k = den.ParkSlots[player]
	if not k then
		-- the first free place: not anyone else's, and nobody's rover already standing on it (slot or not)
		local used = {}
		for plr, i in pairs(den.ParkSlots) do if plr.Parent and plr ~= player then used[i] = true end end
		local others = {}
		for plr in pairs(den.Players) do
			local r = plr ~= player and Expedition.Get(plr) and Vehicles.Root(plr)
			if r then table.insert(others, r.Position) end
		end
		k = 0
		while k < 12 do
			if not used[k] then
				local p = slotCF(den, k).Position
				local free = true
				for _, o in ipairs(others) do if (o - p).Magnitude < 8 then free = false break end end
				if free then break end
			end
			k += 1
		end
		den.ParkSlots[player] = k
	end
	return slotCF(den, k)
end

-- your rover parked on the road just short of the final arena (the boss den's own park spot once it's in phase 3),
-- in your own place in the line
local function parkAtArena(player: Player, den)
	-- (a rider has no rover out here - their driver's is in the line; one they own is back at camp: never moved)
	if not Expedition.Get(player) or Encounter.IsRider(player) then return end
	local root = Vehicles.Root(player)
	if not root then return end
	local park = parkSlot(den, player)
	if (root.Position - park.Position).Magnitude < 4 then return end
	local v = Vehicles.Get(player)
	local rh = v and v:GetAttribute("RootHeight") or 2.6
	local was = root.Anchored
	if was then root.Anchored = false end
	Vehicles.Teleport(player, park * CFrame.new(0, rh, 0))
	if was then
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = true
	end
	-- (tyres down on the ground, not in it: the same settle every other hold does)
	if v and (Vehicles :: any).Settle then pcall((Vehicles :: any).Settle, v) end
end

function Bosses.ArriveFinal(player: Player, den, fight: number?)
	-- phase 3: out of the rover at the final arena
	local run = Expedition.Get(player)
	if not run then return end
	local Chase = require(script.Parent.Chase)
	if (fight and den.Fight ~= fight) or den.Phase < 2 or den.Phase >= 4 then
		-- the fight ended (or reset) while you were still driving: her guards chase you home from the arena
		Chase.Clear(run)
		Expedition.StartChase(player, den, {}, Bosses.Escort(den), false, den.FinalS and { S = den.FinalS, X = den.FinalX } or nil)
		return
	end
	local first = den.Phase < 3
	if den.Phase < 3 then
		den.Phase = 3
		den.FinalAt = os.clock()
		den.Folder:SetAttribute("Phase", 3)
		den.Center = den.FinalCenter
		den.Radius = 46
		den.Enraged = true
		local q = queenOf(den)
		if q and den.Water then
			SeaKing.Final(den, q)
		elseif q then
			q.Custom = nil
			q.Cfg:SetAttribute("Hidden", nil)
			q.Pos = den.FinalCenter + Vector3.new(0, 0, -14)
			Encounter.PublishActor(q, 0)
			Encounter.SetState(q, "Chase")
			q.NextAttack = os.clock() + 5
			q.NextSig = os.clock() + 7 -- its signature comes out early at the final stand
		end
		-- (where it stands now: the client's copy of the model may still be back at the den for a frame or two)
		Encounter.FireSite(den, "BossPhase", { Phase = 3, At = q and q.Pos or den.FinalCenter })
	end
	-- stop the rover and step out - parked on the road just short of the arena, every time (2026-10-13, user video:
	-- "the car is never where it should be after a boss" - it could be left anywhere the chase ended)
	Chase.Clear(run)
	run.Phase = "Site"
	if not den.Water then parkAtArena(player, den) end
	Vehicles.GetOut(player, den.FinalCenter, true)
	if den.Water then task.delay(0.35, SeaKing.PlaceOnMaw, player, den) end -- stepped off the boat onto the ring
	Encounter.Join(player, den)
	enlist(den, player)
	-- carpool: everyone riding along steps out beside the driver and joins the last stand (same as a late joiner)
	for rider in pairs(run.Riders or {}) do
		if rider.Parent and Expedition.RiderRun(rider) == run then
			require(script.Parent.Carpool).StepOut(rider, CFrame.new(den.FinalCenter + Vector3.new(rng:NextNumber(-5, 5), 3, rng:NextNumber(4, 8))))
			task.delay(0.2, function()
				if rider.Parent and Expedition.RiderRun(rider) == run and den.Phase == 3 then Bosses.Join(rider, den) end
			end)
		end
	end
	-- (sent to this hunter directly: the site-wide one above went out before anyone was in the arena). Where the
	-- boss really is now, and whether the last stand is already well under way (then no cutscene: you're dropped
	-- straight into it - a 3 s scene with your legs frozen mid-fight got people killed)
	local q = queenOf(den)
	local late = not first and os.clock() - (den.FinalAt or 0) > 4
	Net.Fire(player, "BossPhase", { Phase = 3, At = q and q.Pos or den.FinalCenter, Late = late or nil })
end

local function victory(den)
	if den.Water then SeaKing.Release(den, "Lost") end
	LandKings.Cancel(den, queenOf(den))
	local id = den.BossId
	local boss = Config.Bosses[id]
	local t = den.TierInfo
	local time = os.clock() - (den.Started or os.clock())
	den.Phase = 4
	-- knocked out = the fire's out (2026-10-14, user screenshot: the beaten Tyrant King still had its rage aura and
	-- burning eyes). Every fight flag on it goes, so nothing keeps drawing an angry, guarded or weak boss
	local q0 = queenOf(den)
	if q0 and q0.Cfg.Parent then
		q0.Enraged = nil
		for _, k in ipairs({ "Enraged", "Shield", "Weak", "Guard", "Knocked", "RodeoOpen", "Attack" }) do q0.Cfg:SetAttribute(k, nil) end
	end
	den.Enraged, den.Shield = nil, nil
	Encounter.FireSite(den, "BossDown", { Boss = id, Name = boss.Name, Tier = t.Name, Time = time })
	Net.FireAll("Announce", { Text = boss.Name .. " (" .. t.Name .. ") WAS KNOCKED OUT!", Color = "Gold" })
	-- everyone who helped shares the win: in the arena, still driving the chase, or back on the map, as long as
	-- they're still out on a run and actually landed something (calm or a revive)
	-- the fight's won: anyone still lying downed gets up (they'd otherwise faint at the timer and lose the boss egg
	-- and their whole rack, at the end of a fight they helped win)
	for plr, st in pairs(den.Players) do
		if st.Downed then Encounter.RevivePlayer(den, plr, 0.5) end
	end
	local winners, total = {}, 0
	for plr, p in pairs(den.Participants) do
		-- (standing in the arena at the knockout counts too: the rodeo finisher lands no darts)
		if plr.Parent and Expedition.InRun(plr) and (p.Score > 0 or den.Players[plr]) then
			table.insert(winners, plr)
			total += p.Score
		end
	end
	local players = {}
	for plr in pairs(den.Players) do table.insert(players, plr) end
	-- THE BOSS NEST (2026-10-13, "the eggs aren't just for you"): one boss egg per winner standing in the arena,
	-- laid in the nest for any of them to grab - first come, first served, one each while a teammate still has none
	-- (Encounter.PickEgg). Rarity: the best luck among them; your first-clear floor rides on the egg you pick up. A
	-- winner still out on the road gets theirs on the rack, as before.
	den.BossWinners, den.BossTaken, den.BossFloor = {}, {}, {}
	local arenaProfiles = {}
	for _, plr in ipairs(winners) do
		local pf = Data.Peek(plr)
		if pf and den.Players[plr] then
			den.BossWinners[plr.UserId] = true
			plr:SetAttribute("BossWinner", den.Key) -- (only winners see the boss nest's eggs: EncounterView)
			table.insert(arenaProfiles, pf)
		end
	end
	local nestEggs = #arenaProfiles
	for _, plr in ipairs(winners) do
		local profile = Data.Peek(plr)
		if not profile then continue end
		-- coins follow your share: an even split (or better) pays in full, a small part still pays half
		local share = total > 0 and den.Participants[plr].Score / total or 1
		local cut = math.clamp(0.5 + 0.5 * share * #winners, 0.5, 1)
		profile.Materials[boss.Material] = (profile.Materials[boss.Material] or 0) + t.Mats
		local rec = profile.Bosses[id] or { Best = 0, Clears = 0 }
		local firstClear = (rec.Best or 0) < den.Tier
		rec.Best = math.max(rec.Best or 0, den.Tier)
		rec.Clears = (rec.Clears or 0) + 1
		if not rec.BestTime or time < rec.BestTime then rec.BestTime = math.floor(time) end
		profile.Bosses[id] = rec
		local stars = 0
		for _, r in pairs(profile.Bosses) do stars += r.Best or 0 end
		profile.Stars = stars
		profile.Stats.Bosses += 1
		local coins = math.floor(1450 * t.Power * Config.EraTier(boss.Era) * cut) -- scales with the boss's era
		-- CO-OP (2026-10-14, Boosts.luau): won together - riders and separate rovers alike - pays each winner a team
		-- bonus: more coins, a POWER burst and TEAM LUCK (before the eggs below are rolled, so they feel it too)
		local coop = nil
		if #winners >= 2 then
			local ok, res = pcall(function() return (require(script.Parent.Boosts) :: any).Coop(plr, #winners - 1, coins) end)
			if ok and typeof(res) == "table" then coop = res coins += math.max(0, math.floor(tonumber(res.Coins) or 0)) end
		end
		local rider = Encounter.IsRider(plr)
		if rider then
			-- a rider has no run purse: straight into their own coins
			profile.Coins += coins
			profile.Earned = (profile.Earned or 0) + coins
		else
			Expedition.AddRunCoins(plr, coins)
		end
		Quests.Progress(plr, "Boss", { Boss = id, Count = 1 })
		-- a boss win pays POWER (your trainer's rate x Config.Trainer.Rewards.Boss seconds, more for a harder tier)
		pcall(function() require(script.Parent.Trainer).Reward(plr, "Boss", t.Power) end)
		-- the boss egg: the best odds in the game. The first boss you ever beat always lays an EPIC (that hatch is
		-- the moment rarity clicks); the first time you beat any other boss it's at least a RARE
		local floor = 0
		if rec.Clears == 1 then floor = profile.Stats.Bosses == 1 and 4 or 3 end
		if den.BossWinners[plr.UserId] then
			-- in the arena: your egg is in the nest (go and grab it); your floor waits for whichever you pick up
			den.BossFloor[plr.UserId] = floor > 0 and floor or nil
			Net.Fire(plr, "BossLoot", { Boss = id, Mats = t.Mats, Material = boss.Material, Coins = coins, Nest = nestEggs, Species = boss.Species, FirstClear = firstClear, Tier = t.Name, Stars = stars, Coop = coop })
			Plots.Sync(plr)
			Data.Changed(plr)
			if Bosses.OnClear then Bosses.OnClear(plr, id, den.Tier, time) end
			continue
		end
		local rarity = Dinos.RollRarity(profile, t.Luck)
		if Config.Rarity[rarity].Order < floor then rarity = Config.RarityOrder[floor] end
		local kg = Dinos.RollKG(boss.Species, 1.6 + den.Tier * 0.3)
		Net.Fire(plr, "BossLoot", { Boss = id, Mats = t.Mats, Material = boss.Material, Coins = coins, Egg = { Species = boss.Species, Rarity = rarity, KG = kg }, FirstClear = firstClear, Tier = t.Name, Stars = stars, Coop = coop })
		Plots.Sync(plr)
		Data.Changed(plr)
		local egg = { Species = boss.Species, Rarity = rarity, KG = kg }
		if rider then
			-- (a rider's prize goes straight to their bag; a full bag gets it dropped in the arena to make room for)
			-- (forced: a boss egg always fits - a rider away from the arena has nowhere else for it, and the loot card
			-- already showed it)
			local e = Dinos.AddEgg(plr, egg.Species, egg.Rarity, 0, egg.KG, true)
			if e then
				Data.Changed(plr)
			elseif den.Players[plr] then
				local q = queenOf(den)
				Encounter.PlaceEgg(den, egg, (q and q.Pos or den.Center) + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), plr.UserId)
			end
		elseif den.Players[plr] then
			-- the prize lands in the arena for you to carry to your rover (only you can pick yours up)
			local q = queenOf(den)
			local at = (q and q.Pos or den.Center) + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
			Encounter.PlaceEgg(den, egg, at, plr.UserId)
		else
			-- not in the arena (still driving the chase): it goes straight onto your roof rack
			Expedition.LoadEgg(plr, egg)
		end
		if Bosses.OnClear then Bosses.OnClear(plr, id, den.Tier, time) end
	end
	-- everyone who won it in the arena finds their rover where they left it: just short of the arena, held there
	if not den.Water then
		for plr in pairs(den.Players) do
			if Expedition.Get(plr) then pcall(parkAtArena, plr, den) end
		end
	end
	-- the nest goes by its head, clear of the body lying there (2026-10-14: always the arena's middle - often under the
	-- knocked-out boss). Its nose first; if that's out of the arena, its back, its legs, its tail; else the middle
	local nestAt = nil
	local qk = queenOf(den)
	if qk and not den.Water then
		local yaw, sc = qk.Yaw or 0, qk.Scale or 1
		local look, right = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)), Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
		for _, off in ipairs({ look * (9 + 6 * sc), -right * (7 + 4 * sc), right * (8 + 4 * sc), -look * (14 + 8 * sc) }) do
			local p = qk.Pos + off
			if flat(p - den.Center).Magnitude <= den.Radius - 6 then nestAt = Vector3.new(p.X, den.Center.Y, p.Z) break end
		end
		if not nestAt and flat(qk.Pos - den.Center).Magnitude < 10 + 6 * sc then nestAt = qk.Pos + look * (9 + 6 * sc) end
	end
	for k = 1, nestEggs do
		local rarity = Dinos.PeekRarity(arenaProfiles, t.Luck)
		Encounter.PlaceBossEgg(den, { Species = boss.Species, Rarity = rarity, KG = Dinos.RollKG(boss.Species, 1.6 + den.Tier * 0.3) }, k, nestAt)
	end
	-- the den rests once every hunter has driven off (or after a few minutes)
	task.spawn(function()
		local t0 = os.clock()
		while den.Count > 0 and os.clock() - t0 < 240 do task.wait(1) end
		for _, plr in ipairs(players) do
			if den.Players[plr] and Encounter.IsRider(plr) then
				-- (a rider: their prize is already in their bag; the driver's way out takes them along)
				if Expedition.Reseat then Expedition.Reseat(plr) end
			elseif den.Players[plr] then
				-- still here when the den rests: your share of the nest (if you never grabbed it) goes to your bag, and
				-- you're back on the era map (2026-10-12: you were left at an empty den with no MAP and no DRIVE OFF,
				-- and the reset deleted the egg)
				Encounter.Leave(plr) -- (Leave bags your boss egg: in your arms, set down, or your share)
				-- (and your screen hears of it: it used to sit in the den's state until the roam heal noticed)
				local res = Expedition.BackToMap(plr)
				if res and res.Ok then Net.Fire(plr, "SiteLeft", {}) end
			end
		end
		Bosses.Reset(den)
	end)
end

local function defeat(den)
	if den.Water then SeaKing.Release(den, "Lost") end
	LandKings.Cancel(den, queenOf(den))
	local was = den.Phase -- (where they lost decides where the ride home starts)
	den.Phase = 4
	Encounter.FireSite(den, "BossFail", { Name = Config.Bosses[den.BossId].Name })
	local players = {}
	for plr in pairs(den.Players) do table.insert(players, plr) end
	for _, plr in ipairs(players) do
		task.delay(3, function()
			if not plr.Parent then return end
			if Encounter.SiteOf(plr) ~= den then return end -- (already left: back on the map, or driving off)
			if Encounter.IsRider(plr) then return end -- (their driver's escort chase seats them)
			Encounter.Leave(plr)
			Expedition.StartChase(plr, den, {}, Bosses.Escort(den), false, den.FinalS and was >= 3 and { S = den.FinalS, X = den.FinalX } or nil)
		end)
	end
	task.delay(5, function() Bosses.Reset(den) end)
end

function Bosses.Reset(den)
	if den.Water then SeaKing.Release(den, "Lost") SeaKing.Reset(den) end
	LandKings.Cancel(den, queenOf(den))
	Encounter.RemoveActors(den)
	for _, e in pairs(den.Eggs or {}) do e.Cfg:Destroy() end
	if den.Eggs then table.clear(den.Eggs) end
	den.Phase = 0
	den.State = "Idle"
	den.Center = den.DenCenter
	den.Radius = 40
	den.Enraged, den.Shield, den.Started = nil, nil, nil
	den.StartAt, den.EmptySince, den.FreezeUntil = nil, nil, nil
	den.Participants = {}
	den.BossWinners, den.BossTaken, den.BossFloor = nil, nil, nil
	den.ParkSlots = nil
	-- (a winner who drove off kept BossWinner = this den, and saw the next fight's boss nest as theirs. 2026-10-14)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("BossWinner") == den.Key then plr:SetAttribute("BossWinner", nil) end
	end
	den.Folder:SetAttribute("Phase", 0)
	den.Folder:SetAttribute("Revives", nil)
	den.Folder:SetAttribute("Started", nil)
	den.Folder:SetAttribute("Hunters", nil)
	Encounter.PublishSite(den)
end

function Bosses.Join(player: Player, den)
	den.ReviveGiven = den.ReviveGiven or {}
	if den.Started and not den.Participants[player] and not den.ReviveGiven[player.UserId] then
		-- a late joiner brings a spare revive with them (once per fight: walking out and back in used to add one
		-- every time - endless revives)
		den.ReviveGiven[player.UserId] = true
		den.RevivePool = (den.RevivePool or 0) + 1
		den.Folder:SetAttribute("Revives", den.RevivePool)
	end
	enlist(den, player)
	if den.Phase == 2 then
		-- she's on the run: straight into your rover and after her
		chaseFor(den, player)
		return
	end
	Encounter.Join(player, den)
	-- your rover into its own place in the line (the travel drops every rover on the den's one park spot). The final
	-- stand always parks you there, as the chase's arrival does; the den only when it landed on someone else's
	if not den.Water then
		task.delay(0.3, function()
			if not (den.Players[player] and Expedition.Get(player)) then return end
			local root = Vehicles.Root(player)
			if not root then return end
			local stacked = false
			for plr in pairs(den.Players) do
				local other = plr ~= player and Vehicles.Root(plr)
				if other and (other.Position - root.Position).Magnitude < 10 then stacked = true end
			end
			if den.Phase == 3 or stacked then pcall(parkAtArena, player, den) end
		end)
	end
	if den.Phase == 1 and not den.Started then
		-- the fight starts a few seconds after the first hunter arrives
		den.StartAt = den.StartAt or (os.clock() + 4)
	elseif den.Phase == 3 then
		-- straight into the final stand
		if den.Water then task.delay(0.35, SeaKing.PlaceOnMaw, player, den) end
		task.delay(1, function()
			if den.Phase == 3 and den.Players[player] then Net.Fire(player, "BossPhase", { Phase = 3, Late = true }) end
		end)
	end
	Net.Fire(player, "BossArrive", { Boss = den.BossId, Phase = den.Phase, Started = den.Started ~= nil })
end

function Bosses.Leave(player: Player)
	player:SetAttribute("BossWinner", nil)
	for _, den in pairs(dens) do
		-- (walking out of a live fight gives up your share. Only a den you're really standing in: a rider sat back
		-- down for the boss chase - and anyone driving it - kept losing a share they'd earned. 2026-10-14)
		if den.Players[player] then
			Encounter.Leave(player)
			if den.Phase >= 1 and den.Phase <= 3 then den.Participants[player] = nil end
		end
	end
end

--------------------------------------------------------------------------------
-- per-tick phase logic (runs inside the Encounter loop via site.Tick)
--------------------------------------------------------------------------------
local function denTick(den, dt: number)
	local now = os.clock()
	if den.Phase >= 1 and den.Phase <= 3 then
		-- the camp card and the era map show how many are in it
		local n = hunters(den)
		if den.Folder:GetAttribute("Hunters") ~= n then den.Folder:SetAttribute("Hunters", n) end
		-- a fight everyone has left (quit, went home, backed out) resets instead of sticking
		if n == 0 and (den.Started or den.Phase >= 2) then
			den.EmptySince = den.EmptySince or now
			if now - den.EmptySince >= ABANDON then
				for plr in pairs(den.Players) do Encounter.Leave(plr) end
				Bosses.Reset(den)
				return
			end
		else
			den.EmptySince = nil
		end
	end
	if den.Phase == 1 then
		if not den.Started then
			-- (only with someone still in it: a hunter who left in those 4 s used to start it for nobody - a boss frozen
			-- in its intro for 40 s, the join window cut short. Empty, it waits out its window as usual)
			if den.StartAt and now >= den.StartAt then
				den.StartAt = nil
				if hunters(den) > 0 then beginFight(den) end
			elseif not den.StartAt and now > (den.Until or 0) then Bosses.Reset(den) end
			return
		end
		local q = queenOf(den)
		if not q then return end
		-- the pack shields her; KO'd pack members come back while she screeches them in
		if (Config.Bosses[den.BossId] :: any).Pack then
			den.Shield = minions(den) >= 2
			q.Cfg:SetAttribute("Shield", den.Shield or nil)
			if minions(den) < 2 and now >= (den.NextWave or 0) then
				den.NextWave = now + 14
				spawnMinion(den)
				spawnMinion(den)
				Encounter.FireSite(den, "BossWave", {})
			end
		end
		if den.Water then
			SeaKing.Tick(den, q, dt)
		elseif not q.Custom and q.State == "Chase" and not ((Config.Bosses[den.BossId] :: any).Perch and now >= (q.NextPerch or 0) and #den.Ledges > 0) then
			LandKings.Tick(den, q, dt)
		-- perch on a ledge, then leap-slam the player she's watching
		elseif not q.Custom and (Config.Bosses[den.BossId] :: any).Perch and now >= (q.NextPerch or 0) and now >= (den.FreezeUntil or 0) and #den.Ledges > 0 and q.State == "Chase" then
			q.Custom = true
			local ledge = den.Ledges[rng:NextInteger(1, #den.Ledges)]
			q.Pos = ledge
			q.PerchT = now
			Encounter.SetState(q, "Perch")
			Encounter.PublishActor(q, 0)
			Encounter.FireSite(den, "BossPerch", { Actor = q.Id, P = ledge })
		elseif q.Custom and q.State == "Perch" and now - (q.PerchT or now) >= 2.6 then
			-- pick a target and slam
			local best, bd = nil, math.huge
			for plr, st in pairs(den.Players) do
				local h = Encounter.HrpOf(plr)
				if h and not st.Downed then
					local d = flat(h.Position - q.Pos).Magnitude
					if d < bd then best, bd = h.Position, d end
				end
			end
			local target = best or den.Center
			local land = Vector3.new(target.X, Encounter.GroundY(den, target, den.Center.Y), target.Z)
			local shape = { Shape = "Circle", O = land, R = 10, Dmg = ((q.Attacks and q.Attacks[1] and q.Attacks[1].Dmg) or 30) * 1.1, Id = "LeapSlam" }
			Encounter.FireSite(den, "Tele", { Actor = q.Id, Id = "LeapSlam", Shape = "Circle", O = land, R = 10, Time = 1.1 })
			Encounter.SetState(q, "Leap")
			q.PerchT = math.huge
			task.delay(1.1, function()
				if not q.Cfg.Parent then return end
				q.Pos = land
				Encounter.PublishActor(q, 0)
				for plr in pairs(den.Players) do
					local h = Encounter.HrpOf(plr)
					if h and flat(h.Position - land).Magnitude <= shape.R and math.abs(h.Position.Y - land.Y) < 10 then
						Encounter.Hurt(den, plr, shape.Dmg, "LeapSlam")
					end
				end
				Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = "LeapSlam" })
				q.Custom = nil
				q.NextPerch = os.clock() + rng:NextNumber(10, 14)
				Encounter.SetState(q, "Recover")
				q.Cfg:SetAttribute("Weak", true)
			end)
		end
		if q.Calm >= q.CalmMax * 0.4 and den.FinalS then
			task.spawn(toChase, den)
		end
	end
	if den.Phase == 3 then
		local q = queenOf(den)
		if q and den.Water then SeaKing.Tick(den, q, dt) elseif q and den.Started then LandKings.Tick(den, q, dt) end
	end
	-- everyone down and no revives left: the ruler wins this one
	if (den.Phase == 1 or den.Phase == 3) and den.Started and den.Count > 0 then
		local up = 0
		for _, st in pairs(den.Players) do if not st.Downed then up += 1 end end
		if up == 0 and (den.RevivePool or 0) <= 0 then defeat(den) end
	end
end

local function denKO(den, a)
	if a.Boss and den.Phase == 3 then victory(den) end
end

--------------------------------------------------------------------------------
function Bosses.Start(deps)
	Data, Net, Dinos, Quests, Encounter, Expedition, Plots, Vehicles = deps.Data, deps.Net, deps.Dinos, deps.Quests, deps.Encounter, deps.Expedition, deps.Plots, deps.Vehicles
	LandKings.Setup(deps)
	for id, boss in pairs(Config.Bosses) do
		local zm = Workspace:FindFirstChild(boss.Era)
		local route = RouteMath.get(boss.Era)
		if not zm or not route then continue end
		local center = marker(zm, "DenCenter")
		local final = marker(zm, "FinalArena")
		if not center then warn("[Bosses] no den for", id) continue end
		local ledges = {}
		for k = 1, 6 do
			local l = marker(zm, "DenLedge" .. k)
			if l then table.insert(ledges, l.Position + Vector3.new(0, l.Size.Y / 2, 0)) end
		end
		local den = {
			Key = boss.Era .. "/Den", Era = boss.Era, BossId = id, Boss = true,
			Def = { Id = "Den", Name = boss.Name, Species = boss.Species, Kind = "Boss" },
			Center = center.Position - Vector3.new(0, center.Size.Y / 2, 0), DenCenter = center.Position - Vector3.new(0, center.Size.Y / 2, 0),
			Radius = 40, Ledges = ledges, Variant = center:GetAttribute("Variant") or 1,
			S = center:GetAttribute("RouteS") or 0, X = center:GetAttribute("RouteX") or -20,
			FinalCenter = final and (final.Position - Vector3.new(0, final.Size.Y / 2, 0)) or nil,
			FinalS = final and final:GetAttribute("RouteS") or nil, FinalX = final and final:GetAttribute("RouteX") or 0,
			Phase = 0, State = "Idle", Tier = 1, Participants = {},
		}
		Encounter.AddSite(den)
		den.Tick = denTick
		if boss.Water then SeaKing.Setup(den, zm, deps) end
		den.Pursuer = Bosses.Escort(den)
		-- driving off from the final arena starts the chase from there
		den.DriveOffOpts = function(d) return (d.Phase >= 3 and d.FinalS) and { S = d.FinalS, X = d.FinalX } or nil end
		den.OnKO = denKO
		-- each phase caps how far her calm can go, so the phase changes always happen
		den.CapCalm = function(site, a)
			if not a.Boss then return a.CalmMax end
			if site.Phase == 1 then return a.CalmMax * 0.4 end
			if site.Phase == 2 then return a.CalmMax * 0.75 end
			return a.CalmMax
		end
		dens[id] = den
	end
	-- dens someone at camp is summoning right now (their 10 s build-up): the server event leaves those alone
	local summoning = {} :: { [string]: boolean }
	-- server-wide ruler events
	task.spawn(function()
		-- clients count down to the next event from this (the era map and the camp HUD show it)
		local runtime = ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Runtime")
		-- the last RISE seconds are a build-up every client plays (camp shakes, gates go red, a siren)
		local RISE = 15
		runtime:SetAttribute("NextBossAt", workspace:GetServerTimeNow() + 90)
		task.wait(90 - RISE)
		while true do
			Net.FireAll("BossRising", { All = true, In = RISE })
			task.wait(RISE)
			for id, den in pairs(dens) do
				if den.Phase == 0 and not summoning[id] then Bosses.Open(id, 1, nil) end
			end
			runtime:SetAttribute("NextBossAt", workspace:GetServerTimeNow() + Config.BossEventEvery)
			task.wait(Config.BossEventEvery - RISE)
		end
	end)
	local lastMash = {} :: { [Player]: number }
	Players.PlayerRemoving:Connect(function(p) lastMash[p] = nil end)
	Net.On("SeaMash", function(player)
		-- (a human can't mash faster than this: a script firing it 50 times was an instant escape)
		local now = os.clock()
		if now - (lastMash[player] or 0) < 0.08 then return { Ok = false } end
		lastMash[player] = now
		for _, d in pairs(dens) do if d.Water and d.Grab and d.Grab.Player == player then SeaKing.Mash(d, player) end end
		return { Ok = true }
	end)
	Net.On("SummonBoss", function(player, args)
		local id = args.Boss
		local den = typeof(id) == "string" and dens[id]
		local profile = Data.Peek(player)
		if not den or not profile then return { Ok = false } end
		if (profile.Keys[id] or 0) <= 0 then return { Ok = false, Err = "YOU NEED A BOSS KEY (TAKEDOWNS DROP THEM)" } end
		-- (not while a camp summon is counting it down either: that one is someone else's)
		if den.Phase ~= 0 or summoning[id] then return { Ok = false, Err = "THE BOSS IS ALREADY AWAKE - JOIN IN!" } end
		local best = profile.Bosses[id] and profile.Bosses[id].Best or 0
		local tier = math.clamp(math.floor(tonumber(args.Tier) or 1), 1, best + 1)
		profile.Keys[id] -= 1
		Data.Changed(player)
		Bosses.Open(id, tier, player)
		return { Ok = true, Tier = tier }
	end)
	-- summoning from Base Camp (a boss key + the Time Gate): the whole server gets a 10 s build-up (camp shakes,
	-- the gate turns red, a siren), then the den opens for everyone and the summoner rides straight in
	local SUMMON_DELAY = 10
	Net.On("SummonFromCamp", function(player, args)
		local id = args.Boss
		local den = typeof(id) == "string" and dens[id]
		local profile = Data.Peek(player)
		if not den or not profile then return { Ok = false } end
		if (profile.Keys[id] or 0) <= 0 then return { Ok = false, Err = "YOU NEED A BOSS KEY (TAKEDOWNS DROP THEM)" } end
		if den.Phase ~= 0 or summoning[id] then return { Ok = false, Err = "THE BOSS IS ALREADY AWAKE - JOIN IN!" } end
		if Expedition.Get(player) then return { Ok = false, Err = "FINISH YOUR EXPEDITION FIRST" } end
		if not profile.Unlocked[den.Era] then return { Ok = false, Err = "THAT ERA IS LOCKED" } end
		profile.Keys[id] -= 1
		Data.Changed(player)
		summoning[id] = true
		local boss = Config.Bosses[id]
		Net.FireAll("BossRising", { Boss = id, Name = boss.Name, Era = boss.Era, By = player.DisplayName, ByUserId = player.UserId, In = SUMMON_DELAY })
		task.delay(SUMMON_DELAY, function()
			summoning[id] = nil
			if not Bosses.Open(id, 1, player) then
				-- it didn't wake (something else got there first): you keep your key
				local p2 = Data.Peek(player)
				if p2 then p2.Keys[id] = (p2.Keys[id] or 0) + 1 Data.Changed(player) end
				return
			end
			if player.Parent and not Expedition.Get(player) then
				local p2 = Data.Peek(player)
				if p2 then p2.Era = den.Era end
				Expedition.Begin(player, den.Era, { Site = den.Key })
			end
		end)
		return { Ok = true, In = SUMMON_DELAY }
	end)
	-- joining an event from Base Camp: ride the Time Gate straight to the den
	Net.On("JoinBoss", function(player, args)
		local den = typeof(args.Boss) == "string" and dens[args.Boss]
		if not den then return { Ok = false, Err = "THAT EVENT IS OVER" } end
		-- any live phase: the den, the chase or the final stand (TravelDone lands you in the right one)
		local ok, err = Bosses.CanJoin(player, den)
		if not ok then return { Ok = false, Err = err or "THAT EVENT IS OVER" } end
		if Expedition.Get(player) then return { Ok = false, Err = "FINISH YOUR EXPEDITION FIRST" } end
		local profile = Data.Peek(player)
		if not profile then return { Ok = false } end
		profile.Era = den.Era
		-- (its refusal reaches you: a rider in a friend's rover is told to hop out first)
		local res = Expedition.Begin(player, den.Era, { Site = den.Key })
		if typeof(res) == "table" then return res end
		return { Ok = true }
	end)
	local _ = RunService
	local _p = Players
end

return Bosses
