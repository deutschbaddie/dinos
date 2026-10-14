--[[
	Config — every number the game is balanced on lives here (mirrors the design doc).
	Shared by server and client so the UI always shows the same values the server enforces.

	Core loop: expeditions (server-wide encounter sites) → eggs (rolled rarity) → hatch (rolled KG) → dinos earn
	money per second → upgrades and boss gear → Hunter Power → bosses (tiers, mastery) → next era.
]]

local Config = {}

Config.Version = 2
Config.MaxPlayers = 8

--------------------------------------------------------------------------------
-- rarity: every egg rolls its own; six tiers, nothing else
--------------------------------------------------------------------------------
Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" }
Config.Rarity = {
	Common = { Order = 1, Name = "COMMON", Odds = 64, Mult = 1, Hatch = 30, Color = Color3.fromHex("A7ADB5") },
	Uncommon = { Order = 2, Name = "UNCOMMON", Odds = 25, Mult = 2, Hatch = 60, Color = Color3.fromHex("66D86B") },
	Rare = { Order = 3, Name = "RARE", Odds = 8, Mult = 5, Hatch = 180, Color = Color3.fromHex("48A8FF") },
	Epic = { Order = 4, Name = "EPIC", Odds = 2.5, Mult = 15, Hatch = 420, Color = Color3.fromHex("AD66FF") },
	Legendary = { Order = 5, Name = "LEGENDARY", Odds = 0.45, Mult = 50, Hatch = 720, Color = Color3.fromHex("FFD447") },
	Secret = { Order = 6, Name = "SECRET", Odds = 0.05, Mult = 250, Hatch = 1200, Color = Color3.fromHex("FF5252") },
}
Config.Pity = 40 -- an EPIC or better at least every this many eggs (never shown)
-- luck shifts weight from Common toward the top tiers: 0 = base odds, TakedownLuck = a knockout nest, 2.5 = boss,
-- more = boosts. (2026-10-12 progression pass: rarer odds so an EPIC is an event, not a Tuesday)
Config.TakedownLuck = 0.6
Config.BossLuck = 2.5
function Config.RarityWeights(luck: number): { [string]: number }
	local w = {}
	for _, r in ipairs(Config.RarityOrder) do
		local info = Config.Rarity[r]
		w[r] = info.Odds * (info.Order == 1 and 1 / (1 + luck * 0.35) or (1 + luck * (info.Order - 1) * 0.45))
	end
	return w
end

-- LUCK MULTIPLIERS + BOOSTS (2026-10-14 round 2; server Boosts.luau owns them). On top of the additive luck above,
-- a luck MULTIPLIER multiplies the chance of every RARE-or-better tier and Common / Uncommon make room - so "2x LUCK"
-- really is twice the chance of a RARE, EPIC, LEGENDARY or SECRET egg. Multipliers from every source multiply
-- together, capped at Max. (The LUCK BOOST product stays additive - Potion.Add - so the shop's odds stay exact.)
Config.Luck = {
	Max = 6, PowerMax = 3, CoinMax = 4, -- every source together, capped
	TopShare = 0.97, -- however lucky, Common + Uncommon keep at least this much of a roll's room (1 - TopShare)
	-- the server-wide 2x LUCK event: on a timer (the first FirstAfter minutes into a server, then a new one Every
	-- minutes after each start), from Settings > ADMIN, or later a developer product (Boosts.StartLuckEvent).
	-- Another start while one runs adds its minutes (never past MaxMinutes left) - it never stacks to 4x.
	Event = { Mult = 2, Minutes = 15, FirstAfter = { 15, 35 }, Every = { 45, 75 }, MaxMinutes = 60 },
	-- each Roblox friend in your server: +Luck and +Power (x), up to Max friends (4 = +40%)
	Friend = { Luck = 0.1, Power = 0.1, Max = 4 },
	Potion = { Add = 1.5 }, -- profile.LuckUntil (LUCK BOOST product): additive luck while it lasts
	-- a BOSS knocked out together (riders and separate rovers alike): per teammate (up to MaxMates) +Coins of your
	-- coins and PowerSecs of your trainer's rate, and TEAM LUCK (x Luck) for Minutes
	Coop = { Coins = 0.15, PowerSecs = 120, MaxMates = 3, Luck = 1.25, Minutes = 10 },
}
-- weights -> chances with a luck multiplier applied (mult <= 1: the weights back unchanged)
function Config.LuckBoosted(w: { [string]: number }, mult: number?): { [string]: number }
	local m = tonumber(mult) or 1
	if not (m > 1.0001 and m < 1000) then return w end
	local total = 0
	for _, r in ipairs(Config.RarityOrder) do total += w[r] or 0 end
	if total <= 0 then return w end
	local out, top, low = {}, 0, 0
	for _, r in ipairs(Config.RarityOrder) do
		local p = (w[r] or 0) / total
		if Config.Rarity[r].Order >= 3 then p *= m top += p else low += p end
		out[r] = p
	end
	local cap = Config.Luck.TopShare
	if top > cap then
		-- saturated: the top tiers keep their shape and share the cap
		for _, r in ipairs(Config.RarityOrder) do if Config.Rarity[r].Order >= 3 then out[r] *= cap / top end end
		top = cap
	end
	local k = low > 0 and (1 - top) / low or 0
	for _, r in ipairs(Config.RarityOrder) do if Config.Rarity[r].Order < 3 then out[r] *= k end end
	return out
end
-- how much likelier a RARE-or-better egg is with this luck (additive + multiplier) than with none: the honest
-- number the boost strip shows ("2.3x")
function Config.LuckShow(add: number, mult: number?): number
	local function top(w)
		local s, t = 0, 0
		for _, r in ipairs(Config.RarityOrder) do
			s += w[r]
			if Config.Rarity[r].Order >= 3 then t += w[r] end
		end
		return s > 0 and t / s or 0
	end
	local base = top(Config.RarityWeights(0))
	return base > 0 and top(Config.LuckBoosted(Config.RarityWeights(math.max(0, add)), mult)) / base or 1
end

--------------------------------------------------------------------------------
-- species: base income is per second for a COMMON of median weight; KG is the baby's weight range
-- Boss = true: only that era's boss lays it (never a site, the daily chest or a premium egg). A boss species is
-- priced for the era its boss rules (~2x that era's best site dino), so a boss egg is a real step up, not a jackpot.
--------------------------------------------------------------------------------
Config.Species = {
	Velociraptor = { Name = "VELOCIRAPTOR", Era = "FernValley", Income = 3, KG = { 8, 40 }, Color = Color3.fromRGB(123, 138, 58) },
	Triceratops = { Name = "TRICERATOPS", Era = "FernValley", Income = 4, KG = { 120, 600 }, Color = Color3.fromRGB(192, 118, 58) },
	Parasaurolophus = { Name = "PARASAUROLOPHUS", Era = "FernValley", Income = 5, KG = { 90, 420 }, Color = Color3.fromRGB(227, 184, 58) },
	Stegosaurus = { Name = "STEGOSAURUS", Era = "GiantPlains", Income = 12, KG = { 150, 700 }, Color = Color3.fromRGB(95, 138, 58) },
	Ankylosaurus = { Name = "ANKYLOSAURUS", Era = "GiantPlains", Income = 15, KG = { 200, 900 }, Color = Color3.fromRGB(111, 115, 120) },
	Brachiosaurus = { Name = "BRACHIOSAURUS", Era = "GiantPlains", Income = 20, KG = { 400, 2200 }, Color = Color3.fromRGB(201, 164, 106) },
	Carnotaurus = { Name = "CARNOTAURUS", Era = "SpineRiver", Income = 45, KG = { 60, 300 }, Color = Color3.fromRGB(168, 36, 42) },
	Spinosaurus = { Name = "SPINOSAURUS", Era = "SpineRiver", Income = 40, KG = { 150, 800 }, Color = Color3.fromRGB(31, 111, 115) },
	TyrannosaurusRex = { Name = "T. REX", Era = "FernValley", Income = 12, Boss = true, KG = { 200, 1100 }, Color = Color3.fromRGB(74, 138, 60) },
	Giganotosaurus = { Name = "GIGANOTOSAURUS", Era = "GiantPlains", Income = 45, Boss = true, KG = { 220, 1200 }, Color = Color3.fromRGB(58, 58, 68) },
	Mosasaurus = { Name = "MOSASAURUS", Era = "SpineRiver", Income = 130, Boss = true, KG = { 150, 900 }, Color = Color3.fromRGB(42, 90, 168) },
	PrimalRex = { Name = "PRIMAL REX", Era = "TheLab", Income = 500, KG = { 500, 3000 }, Color = Color3.fromRGB(232, 226, 212) },
	-- 2026-10-12 roster expansion
	Sarcosuchus = { Name = "SARCOSUCHUS", Era = "SpineRiver", Income = 55, KG = { 180, 950 }, Color = Color3.fromRGB(94, 111, 46) },
	Oviraptor = { Name = "OVIRAPTOR", Era = "RedCliffs", Income = 70, KG = { 15, 70 }, Color = Color3.fromRGB(42, 143, 163) },
	Protoceratops = { Name = "PROTOCERATOPS", Era = "RedCliffs", Income = 60, KG = { 90, 420 }, Color = Color3.fromRGB(217, 173, 114) },
	Gallimimus = { Name = "GALLIMIMUS", Era = "RedCliffs", Income = 90, KG = { 120, 480 }, Color = Color3.fromRGB(112, 146, 196) },
	Therizinosaurus = { Name = "THERIZINOSAURUS", Era = "RedCliffs", Income = 180, Boss = true, KG = { 600, 3200 }, Color = Color3.fromRGB(180, 90, 40) },
	Microraptor = { Name = "MICRORAPTOR", Era = "FrostForest", Income = 150, KG = { 1, 6 }, Color = Color3.fromRGB(46, 197, 214) },
	Psittacosaurus = { Name = "PSITTACOSAURUS", Era = "FrostForest", Income = 120, KG = { 10, 45 }, Color = Color3.fromRGB(168, 100, 46) },
	Compy = { Name = "COMPY", Era = "FrostForest", Income = 130, KG = { 2, 9 }, Color = Color3.fromRGB(216, 118, 44) },
	Yutyrannus = { Name = "YUTYRANNUS", Era = "FrostForest", Income = 300, Boss = true, KG = { 300, 1400 }, Color = Color3.fromRGB(143, 210, 245) },
	Coelophysis = { Name = "COELOPHYSIS", Era = "DawnDesert", Income = 260, KG = { 10, 30 }, Color = Color3.fromRGB(232, 150, 60) },
	Plateosaurus = { Name = "PLATEOSAURUS", Era = "DawnDesert", Income = 320, KG = { 300, 1500 }, Color = Color3.fromRGB(111, 138, 50) },
	Dilophosaurus = { Name = "DILOPHOSAURUS", Era = "DawnDesert", Income = 380, KG = { 120, 600 }, Color = Color3.fromRGB(184, 196, 58) },
	Postosuchus = { Name = "POSTOSUCHUS", Era = "DawnDesert", Income = 800, Boss = true, KG = { 250, 1200 }, Color = Color3.fromRGB(163, 61, 44) },
}
Config.SpeciesOrder = {
	"Velociraptor", "Triceratops", "Parasaurolophus", "Stegosaurus", "Ankylosaurus", "Brachiosaurus",
	"Spinosaurus", "Carnotaurus", "Sarcosuchus",
	"Oviraptor", "Protoceratops", "Gallimimus", "Therizinosaurus",
	"Microraptor", "Psittacosaurus", "Compy", "Yutyrannus",
	"Coelophysis", "Plateosaurus", "Dilophosaurus", "Postosuchus",
	"Giganotosaurus", "TyrannosaurusRex", "Mosasaurus", "PrimalRex",
}

-- how heavy a dino is within its species, 0..1
function Config.WeightT(species: string, kg: number): number
	local sp = Config.Species[species]
	if not sp then return 0.5 end
	return math.clamp((kg - sp.KG[1]) / math.max(1, sp.KG[2] - sp.KG[1]), 0, 1)
end
-- money per second for one dino (before mastery perks)
function Config.DinoIncome(d): number
	local sp = Config.Species[d.Species]
	local r = Config.Rarity[d.Rarity]
	if not sp or not r then return 0 end
	return sp.Income * r.Mult * (0.75 + 0.75 * Config.WeightT(d.Species, d.KG or sp.KG[1]))
end
-- the full dinosaur model's scale at your base: most are small, a heavy one is a monster (and rare)
function Config.DinoScale(d): number
	local t = Config.WeightT(d.Species, d.KG or 0)
	return 0.4 + 0.75 * t ^ 1.15 -- (raised: babies read better in the yard and the hatch)
end
-- an EQUIPPED companion (following you, fighting beside you) at near its wild size - still bigger with more KG
-- (2026-10-13 tester: "my dinosaurs are the size of dogs when they're equipped": fights used 0.75 x DinoScale, a
-- third the size of the wild ones they were fighting)
function Config.BuddyScale(d): number
	local t = Config.WeightT(d.Species, d.KG or 0)
	return 0.82 + 0.45 * t ^ 1.15
end
-- an egg's size follows its KG: heavy eggs are huge
function Config.EggScale(species: string, kg: number?): number
	local t = Config.WeightT(species, kg or 0)
	return 0.95 + 2.0 * t ^ 1.1 -- (raised: eggs should feel like a prize in your arms)
end
-- where a carried egg sits, in torso space: pressed to the belly, its bottom just below the belt (the legs swing
-- behind it); a big one rises in front of the face and PlayerAnim has the carrier peek round it. The server welds
-- it here, clients refine it.
function Config.CarrySpot(egg: Vector3, torso: Vector3): Vector3
	local y = -torso.Y / 2 - 0.3 + egg.Y / 2
	return Vector3.new(0, y, -(torso.Z / 2 + egg.Z / 2) + 0.1)
end
-- what the Egg Keeper pays for a dino: five minutes of its income, at least 10
function Config.SellValue(d): number
	return math.max(10, math.floor(Config.DinoIncome(d) * 300))
end
-- DINO NAMES (2026-10-14, server Showcase.luau): a dino you named goes by its name (filtered by the server, stored
-- filtered on the record as d.Name, at most Names.Max characters); otherwise by its species. Shown in capitals like
-- every other name in the game. Names.Every = seconds between renames, PerWindow renames per Window seconds.
Config.Names = { Max = 16, Every = 3, Window = 600, PerWindow = 10 }
function Config.DinoName(d): string
	local n = d and d.Name
	if typeof(n) == "string" and n ~= "" then return string.upper(n) end
	local sp = d and Config.Species[d.Species]
	return sp and sp.Name or string.upper(tostring(d and d.Species or "?"))
end
-- the SHOWCASE pedestal by your bridge: a sea species shows off in a water tank on it
function Config.ShowcaseTank(species: string?): boolean
	return species ~= nil and Config.PenLotKind(species) == "Sea"
end
-- fighting power of a buddy dino
-- what each species does as your buddy in a fight: who you bring is a real choice, not just a number
-- Every = seconds between moves, Mult = x its power, Stun = seconds (cancels a wind-up), Area = studs (hits every dino
-- near it), Distract = seconds the target chases the buddy instead of you
Config.BuddyRole = {
	Velociraptor = { Name = "QUICK BITES", Desc = "BITES FAST AND OFTEN", Every = 1.1, Mult = 0.55 },
	Triceratops = { Name = "HORN CHARGE", Desc = "RAMS - STUNS AND CANCELS ATTACKS", Every = 6, Mult = 2.2, Stun = 0.9 },
	Parasaurolophus = { Name = "HONK", Desc = "PULLS THE DINO OFF YOU", Every = 8, Mult = 0.6, Distract = 2.5 },
	Stegosaurus = { Name = "TAIL SWEEP", Desc = "HITS EVERY DINO AROUND IT", Every = 3, Mult = 1.0, Area = 10 },
	Ankylosaurus = { Name = "CLUB SMASH", Desc = "HEAVY HIT THAT STUNS", Every = 5, Mult = 1.6, Stun = 1.2 },
	Brachiosaurus = { Name = "STOMP", Desc = "SHOCKWAVE - STAGGERS EVERYTHING", Every = 7, Mult = 1.4, Area = 14, Stun = 0.6 },
	-- 2026-10-12 roster: new jobs, not just new numbers (engine: Encounter.tickBuddies / Calm / sneakTick)
	--   Shred = { x, s } target takes x calm for s seconds - Slow = { x, s } moves at x speed - Pin = s held (every
	--   dart is a weak-spot hit) - Blind = n its next n attacks miss - Terror = s small dinos run - Heal = share of
	--   your max health per move - Camo = x sneak awareness - Reload = s instant reload this often - Dig = digs eggs
	Oviraptor = { Name = "EGG GUARD", Desc = "SNIFFS OUT THE BEST EGG, CATCHES ONE FALLING EGG A RUN", Every = 1.6, Mult = 0.6, Dig = true, EggGuard = true },
	Protoceratops = { Name = "DIGGER", Desc = "DIGS UP BURIED EGGS, FRILL BASH", Every = 3, Mult = 1.0, Dig = true },
	Gallimimus = { Name = "SPRINT", Desc = "TEAM RUNS 20% FASTER, ROVER BOOST REFILLS FASTER", Every = 1.6, Mult = 0.6, Sprint = 0.2 },
	Therizinosaurus = { Name = "SHRED", Desc = "SLASHES ARMOUR - THE DINO TAKES +40% FOR 5S", Every = 5, Mult = 1.8, Shred = { 1.4, 5 } },
	Microraptor = { Name = "GLIDE", Desc = "HOLD JUMP TO GLIDE - YOUR DODGE BECOMES AN AIR DASH", Every = 1.6, Mult = 0.6, Glide = true },
	Psittacosaurus = { Name = "CAMO", Desc = "HIDES YOU - DINOS SPOT YOU 40% SLOWER", Every = 2.4, Mult = 0.8, Camo = 0.6 },
	Compy = { Name = "SCAVENGER", Desc = "BRINGS YOU DARTS - AN INSTANT RELOAD EVERY 10S", Every = 1.0, Mult = 0.4, Reload = 10 },
	Yutyrannus = { Name = "FROST ROAR", Desc = "SLOWS EVERY DINO AROUND IT FOR 4S", Every = 7, Mult = 1.4, Area = 14, Slow = { 0.5, 4 } },
	Coelophysis = { Name = "PACK CALL", Desc = "CALLS ITS PACK - THREE BITES AT ONCE", Every = 4, Mult = 1.2, Area = 6 },
	Plateosaurus = { Name = "FORAGER", Desc = "HEALS YOU A LITTLE EVERY FEW SECONDS", Every = 4, Mult = 0.8, Heal = 0.07 },
	Dilophosaurus = { Name = "BLINDING SPIT", Desc = "THE DINO'S NEXT 2 ATTACKS MISS", Every = 7, Mult = 0.9, Blind = 2 },
	Postosuchus = { Name = "TERROR", Desc = "SMALL DINOS RUN FROM IT FOR 4S", Every = 8, Mult = 1.6, Area = 16, Terror = 4 },
	Sarcosuchus = { Name = "DEATH ROLL", Desc = "HOLDS A DINO 2.5S - EVERY DART HITS THE WEAK SPOT", Every = 7, Mult = 1.6, Stun = 2.5, Pin = 2.5 },
	Default = { Name = "BITE", Desc = "STEADY BITES", Every = 2.2, Mult = 1 },
}
function Config.BuddyRoleOf(species: string)
	return Config.BuddyRole[species] or Config.BuddyRole.Default
end

-- Buddies (your companion first, then any extra buddy slots) ride along in your rover and fight beside you - but
-- you're the main act. A buddy's bites add up to a share of YOUR launcher's damage (rarer = a bigger share, a heavy
-- one a little more), so a great dino helps a lot without carrying you. Dinos hit them too: knocked down, a buddy can
-- be revived like a friend (hold E). If it bleeds out it's HURT: it rides home in the back and rests for RestSecs
-- (can't fight) unless you pay to heal it. Nobody's pet is ever lost (user call 2026-10-12: too harsh for kids).
Config.Buddy = {
	Share = { 0.14, 0.18, 0.23, 0.29, 0.36, 0.44 }, -- of your launcher's damage per second, by rarity order
	HPBase = 70, HPPer = 32, -- health: base + per rarity step (x0.85..1.15 by weight)
	Bleed = 20, -- seconds to revive a downed buddy before it bleeds out (then HURT: rests RestSecs at home)
	SafeRuns = 3, -- (old rule, unused since 2026-10-12: nobody's pet dies any more)
	RestSecs = 600, -- a companion that bled out goes home hurt: it rests this long (no fighting) or you pay to heal it
	ReviveTime = 2.2, ReviveHP = 0.5,
	Aggro = 0.3, BossAggro = 0.18, AggroTime = 5, -- chance a dino it bites turns on it for a few seconds
	-- in the chase, the companion bites a latched raptor off you (rarer = sooner), then needs a breather
	ChaseHelp = { 2.6, 2.3, 2.0, 1.7, 1.4, 1.1 }, ChaseCooldown = 7,
}
-- BOND: every expedition a companion comes along on (and gets home from) builds its bond. Each level teaches it
-- something, and what it learns makes sense for that dino: only big armoured ones can be a shield, only ones big
-- enough to carry you can be ridden; the others get tougher / fiercer instead. Bond also adds a little to its bites.
Config.Bond = {
	Levels = { 0, 2, 5, 9, 14, 20 }, -- xp to reach level 1..6
	Gain = { Home = 2, Visit = 1, Takedown = 1 }, -- made it home from a chase / went along but left early / a knockout
	Share = 0.02, -- + of your launcher damage per bond level above 1
	Shield = { Stegosaurus = true, Ankylosaurus = true, Triceratops = true, Brachiosaurus = true },
	NoRide = { Velociraptor = true, Mosasaurus = true },
	Tough = 0.15, Fierce = 0.03,
}
-- what each level unlocks: 1 Lookout (+ Undercover at its own kind's nest), 2 Egg Sniffer, 3 Carries an Egg,
-- 4 Shield Wall (or Tough), 5 Rescue, 6 Ride It Home (or Fierce)
function Config.BondLevel(xp: number?): number
	local lv = 1
	for i, need in ipairs(Config.Bond.Levels) do if (xp or 0) >= need then lv = i end end
	return lv
end
function Config.BondPerk(species: string, level: number): string?
	if level == 1 then return "Lookout"
	elseif level == 2 then return "Sniffer"
	elseif level == 3 then return "Carry"
	elseif level == 4 then return Config.Bond.Shield[species] and "Shield" or "Tough"
	elseif level == 5 then return "Rescue"
	elseif level == 6 then return Config.Bond.NoRide[species] and "Fierce" or "Ride" end
	return nil
end
function Config.HasPerk(species: string, level: number, perk: string): boolean
	for l = 1, level do if Config.BondPerk(species, l) == perk then return true end end
	return false
end
Config.PerkText = {
	Lookout = { "LOOKOUT", "WARNS YOU BEFORE A DINO SPOTS YOU" },
	Sniffer = { "EGG SNIFFER", "SNIFFS OUT THE BEST EGG - SOMETIMES DIGS ONE UP" },
	Carry = { "CARRIES AN EGG", "HOLDS A 2ND EGG FOR YOU (DROPS IT IF KNOCKED DOWN)" },
	Shield = { "SHIELD WALL", "STANDS IN FRONT OF YOU WHEN A DINO CHARGES" },
	Tough = { "TOUGH", "+15% HEALTH" },
	Rescue = { "RESCUE", "GETS YOU BACK UP WHEN YOU'RE DOWN (ONCE A TRIP)" },
	Ride = { "RIDE IT HOME", "IF YOUR ROVER FLIPS, RIDE IT HOME WITH ALL YOUR EGGS" },
	Fierce = { "FIERCE", "BITES HARDER" },
}

function Config.BuddyHP(d, bond: number?): number
	local r = Config.Rarity[d.Rarity]
	local order = r and r.Order or 1
	local hp = (Config.Buddy.HPBase + Config.Buddy.HPPer * (order - 1)) * (0.85 + 0.3 * Config.WeightT(d.Species, d.KG or 0))
	if bond and Config.HasPerk(d.Species, bond, "Tough") then hp *= 1 + Config.Bond.Tough end
	return math.floor(hp)
end
-- one bite's calm for a buddy with this role, given its owner's launcher damage per second
function Config.BuddyHit(d, role, launcherDps: number, bond: number?): number
	local r = Config.Rarity[d.Rarity]
	local share = (Config.Buddy.Share[r and r.Order or 1] or Config.Buddy.Share[1]) + Config.Bond.Share * ((bond or 1) - 1)
	if bond and Config.HasPerk(d.Species, bond, "Fierce") then share += Config.Bond.Fierce end
	return launcherDps * share * role.Every * (role.Area and 0.7 or 1) * (0.9 + 0.2 * Config.WeightT(d.Species, d.KG or 0))
end
-- balls from the toy crate: you can carry a few; throw one and your companion fetches it (and any dino near where
-- it lands turns to look)
Config.Balls = { Max = 3, Despawn = 180, Distract = 3, FightDistract = 1.5, Radius = 22 }
-- your launcher's calm per second. mult = Config.DartMult (what your training adds); launcher levels are gone
-- (2026-10-14: the power trainer replaced them)
function Config.LauncherDps(gear, mult: number?): number
	local l = Config.Launchers[gear.Launcher] or Config.Launchers.Rookie
	return l.Damage * (mult or 1) / l.Rate
end

-- the POWER a companion adds to yours: rarer and heavier is more, and a dino from a later era is worth far more
-- (x era tier ^ 1.5: Fern Valley 1, Giant Plains 8, ... Dawn Desert ~1840), so companions keep up with the
-- exponential power curve (Config.Trainer) instead of fading to nothing. Also the "POWER" on its card.
function Config.BuddyPower(d): number
	local r = Config.Rarity[d.Rarity]
	local sp = Config.Species[d.Species]
	local era = sp and Config.EraTiers and Config.EraTiers[sp.Era] or 1
	return math.floor(((r and r.Order or 1) ^ 1.6) * 3 * (era ^ 1.5) * (0.8 + 0.6 * Config.WeightT(d.Species, d.KG or 0)))
end

--------------------------------------------------------------------------------
-- base: incubators, pen, buddies, cash pad
--------------------------------------------------------------------------------
Config.Incubator = { Base = 3, Max = 12, FirstPrice = 1100 }
function Config.IncubatorPrice(owned: number): number
	if owned >= 12 then
		-- the 13th nest and on (a bigger hatchery's row): +22% each from the 12th's price, not +80%
		-- (at x1.8 nests 13-15 cost 1.3M together, 13x the upgrade that makes room for them)
		return math.floor(Config.Incubator.FirstPrice * 1.8 ^ (11 - Config.Incubator.Base) * 1.22 ^ (owned - 11))
	end
	return math.floor(Config.Incubator.FirstPrice * 1.8 ^ (owned - Config.Incubator.Base))
end
--------------------------------------------------------------------------------
-- your island (2026-10-12, Base Camp Islands): building upgrades and star pens, paid in coins + boss materials.
-- Upgrades are bought at the UPGRADE board by each building; every tier changes how the building looks.
--------------------------------------------------------------------------------
Config.Island = {
	-- (2026-10-12, first-hour sim: claws are what's scarce early - every Fern Valley craft wants them - so upgrades
	-- ask for few claws and more coins, and each one does something you notice the moment you buy it)
	Hatchery = {
		{ Name = "HATCHERY", Nests = 12, Speed = 1 },
		{ Name = "HATCHERY II", Nests = 15, Speed = 0.6, Perk = "EGGS HATCH 40% FASTER + ROOM FOR 15 NESTS",
			Cost = { Coins = 100000, Mats = { QueenClaw = 2 } } },
		{ Name = "HATCHERY III", Nests = 18, Speed = 0.4, Perk = "EGGS HATCH 60% FASTER + ROOM FOR 18 NESTS",
			Cost = { Coins = 2500000, Mats = { TideScale = 2, MatriarchScale = 1 } } },
	},
	-- EggSafe scales the chance a hit knocks an egg off your rack, or a flip cracks one (rack straps)
	Garage = {
		{ Name = "GARAGE", Repair = 1, RepairHP = 0.6, EggSafe = 1 },
		{ Name = "WORKSHOP", Repair = 0.7, RepairHP = 0.8, EggSafe = 0.5, Perk = "RACK STRAPS: HALF AS MANY EGGS LOST + REPAIRS 30% CHEAPER",
			Cost = { Coins = 60000, Mats = { QueenClaw = 1 } } },
		{ Name = "HANGAR", Repair = 0.4, RepairHP = 1, EggSafe = 0.25, Perk = "EGGS ALMOST NEVER FALL OFF + REPAIRS 60% CHEAPER",
			Cost = { Coins = 6000000, Mats = { ScytheClaw = 2, TideScale = 1 } } },
	},
	-- every star pen with a star living in it: +10% income for your whole island
	PenIncome = 0.10,
	-- a pen per boss species (the dino must be that species); Sea = the lagoon lot, else a land lot
	Pens = {
		TyrannosaurusRex = { Name = "REX PIT", Cost = { Coins = 75000, Mats = { QueenClaw = 1 } } },
		Giganotosaurus = { Name = "GIGA RUN", Cost = { Coins = 900000, Mats = { MatriarchScale = 2 } } },
		Mosasaurus = { Name = "SEA PEN", Sea = true, Cost = { Coins = 4000000, Mats = { TideScale = 2 } } },
		Therizinosaurus = { Name = "SCYTHE GROVE", Cost = { Coins = 16000000, Mats = { ScytheClaw = 2 } } },
		Yutyrannus = { Name = "FROST DEN", Cost = { Coins = 64000000, Mats = { FrostPlume = 2 } } },
		Postosuchus = { Name = "MUD WALLOW", Cost = { Coins = 260000000, Mats = { DawnScute = 2 } } },
	},
	PenOrder = { "TyrannosaurusRex", "Giganotosaurus", "Mosasaurus", "Therizinosaurus", "Yutyrannus", "Postosuchus" },
	-- the four star lots on every island (tools/gen/islandLayout.js PLAN.star)
	Lots = { StarA = "Land", StarB = "Land", StarC = "Land", StarD = "Sea" },
	LotOrder = { "StarA", "StarB", "StarC", "StarD" },
}
function Config.IslandTier(profile, kind: string): number
	local t = profile and profile.Island and tonumber(profile.Island[kind]) or 1
	return math.clamp(t or 1, 1, #Config.Island[kind])
end
Config.NestSpots = 18 -- nests built into every hatchery (tools/gen/hub.js); the tiers unlock them
function Config.IncubatorMax(profile): number
	local n = Config.Island.Hatchery[Config.IslandTier(profile, "Hatchery")].Nests
	if profile and profile.Flags and profile.Flags.PassIncubators then n += 2 end -- (the +2 INCUBATORS pass)
	return math.min(n, Config.NestSpots)
end
function Config.HatchSpeed(profile): number
	return Config.Island.Hatchery[Config.IslandTier(profile, "Hatchery")].Speed
end
function Config.GarageTier(profile)
	return Config.Island.Garage[Config.IslandTier(profile, "Garage")]
end
-- the star pens that have a star living in them
function Config.StarPensFilled(profile): number
	local n = 0
	for _, pen in pairs(profile and profile.Island and profile.Island.Pens or {}) do
		if typeof(pen) == "table" and (pen.Dino or "") ~= "" then n += 1 end
	end
	return n
end
-- which lot kind a boss species' pen goes on
function Config.PenLotKind(species: string): string?
	local p = Config.Island.Pens[species]
	if not p then return nil end
	return p.Sea and "Sea" or "Land"
end

Config.Pen = { Base = 6, Max = 24, FirstPrice = 1700 }
function Config.PenPrice(owned: number): number
	return math.floor(Config.Pen.FirstPrice * 1.55 ^ (owned - Config.Pen.Base))
end
Config.Inventory = { MaxEggs = 60, MaxDinos = 100 }
-- EGG FUSION (2026-10-14; server Fusion.luau, client FusionView.luau, the Fusion Nest by the Egg Keeper): 3 eggs of
-- the same species AND rarity become 1 egg of that species one rarity up. It weighs the three's average plus KGBonus
-- of the species' KG range (never over its max), so fusing never makes a lighter egg. MaxResult caps the ladder: an
-- EPIC trio makes a LEGENDARY, nothing makes a SECRET (luck only).
-- (later: MUTATION / HYBRID eggs don't fuse yet - CanFuse says no and they're left alone. When they do, a mutated egg
-- should only fuse with the same mutation and keep it)
Config.Fusion = { Count = 3, MaxResult = "Legendary", KGBonus = 0.06 }
function Config.FuseTo(rarity: string): string?
	local r = Config.Rarity[rarity]
	local top = Config.Rarity[Config.Fusion.MaxResult]
	if not (r and top) or r.Order >= top.Order then return nil end
	return Config.RarityOrder[r.Order + 1]
end
function Config.CanFuse(egg): boolean
	return type(egg) == "table" and egg.Mutation == nil and egg.Hybrid == nil and Config.Species[egg.Species] ~= nil
		and Config.FuseTo(egg.Rarity) ~= nil
end
function Config.FuseKG(species: string, kgs: { number }): number
	local sp = Config.Species[species]
	local sum = 0
	for _, kg in ipairs(kgs) do sum += kg end
	local avg = sum / math.max(1, #kgs)
	if not sp then return math.floor(avg + 0.5) end
	return math.min(sp.KG[2], math.floor(avg + (sp.KG[2] - sp.KG[1]) * Config.Fusion.KGBonus + 0.5))
end
-- TRADING (2026-10-14, server Trade.luau / client TradeView.luau): dinos and eggs only, opened from VIEW PROFILE.
-- MinPlaytime is in SECONDS of total playtime (profile.Stats.Playtime); both players need it.
Config.Trade = {
	MinPlaytime = 60 * 60, -- 60 minutes
	MaxItems = 8, -- per side
	RequestTime = 20, -- an unanswered request expires after this
	Countdown = 5, -- both READY: this long before CONFIRM unlocks (any change cancels it)
	Cooldown = 15, -- after a decline / no answer: before you can ask the same player again
	RequestGap = 3, -- between any two of your requests
	Range = 40, -- studs: how close you must be to send a request (the profile card needs you close anyway)
	MaxTime = 600, -- a trade window left open this long closes itself
	LogSize = 20, -- trades kept in each profile's TradeLog (support)
	StudioBypass = true, -- Studio test servers skip the playtime rule (live servers never do)
}
-- the Dino Index pays: every new species x rarity entry gives coins (more for rarer tiers and later eras), and
-- milestones of total entries give a permanent income bonus (stacking). 25 species x 6 rarities = 150 entries.
Config.IndexEntryCoins = 120 -- x rarity order^2 x era tier (Fern Valley 1, Giant Plains 4, later eras higher)
Config.IndexMilestones = {
	{ Count = 5, Coins = 2500, Income = 0.02 },
	{ Count = 10, Coins = 8000, Income = 0.03 },
	{ Count = 20, Coins = 40000, Income = 0.05 },
	{ Count = 36, Coins = 250000, Income = 0.05 },
	{ Count = 72, Coins = 2000000, Income = 0.1 },
	-- (2026-10-12: 25 species x 6 rarities = 150 entries)
	{ Count = 110, Coins = 25000000, Income = 0.1 },
	{ Count = 150, Coins = 200000000, Income = 0.15 },
}
function Config.IndexBonus(found: number): number
	local b = 0
	for _, m in ipairs(Config.IndexMilestones) do if found >= m.Count then b += m.Income end end
	return b
end
-- offline money (2026-10-14, user): on rejoin you get Share of what your yard earned per second at logout, for
-- the time away (at most MaxHours). Under MinMinutes away pays nothing (a quick rejoin isn't a "while you were away")
Config.Offline = { Share = 0.25, MaxHours = 8, MinMinutes = 5 }
-- (old offline rule, unused since 2026-10-14's Config.Offline: a dino paid once per this many seconds while away)
function Config.OfflineEvery(d): number
	local ri = table.find(Config.RarityOrder, d.Rarity) or 1
	local rt = (ri - 1) / math.max(1, #Config.RarityOrder - 1)
	local sp = Config.Species[d.Species]
	local wt = sp and Config.WeightT(d.Species, d.KG or sp.KG[1]) or 0
	return 600 - 540 * (rt * 0.5 + wt * 0.5)
end
Config.FirstEggHatch = 12 -- the very first egg hatches fast so new players see the payoff

--------------------------------------------------------------------------------
-- gear: stat levels (coins) + tier unlocks (boss materials + coins). Hunter Power sums it all.
--------------------------------------------------------------------------------
Config.Materials = {
	QueenClaw = { Name = "REX CLAW", Boss = "TyrantKing", Color = Color3.fromRGB(255, 196, 80) },
	MatriarchScale = { Name = "TITAN SCALE", Boss = "Titan", Color = Color3.fromRGB(120, 220, 200) },
	TideScale = { Name = "TIDE SCALE", Boss = "Tidebreaker", Color = Color3.fromRGB(70, 175, 235) },
	ScytheClaw = { Name = "SCYTHE CLAW", Boss = "Scythe", Color = Color3.fromRGB(240, 226, 196) },
	FrostPlume = { Name = "FROST PLUME", Boss = "Frostfang", Color = Color3.fromRGB(190, 230, 255) },
	DawnScute = { Name = "DAWN SCUTE", Boss = "DawnKing", Color = Color3.fromRGB(255, 120, 70) },
}
Config.Launchers = {
	Rookie = { Order = 1, Name = "ROOKIE LAUNCHER", Damage = 6, Rate = 0.42, Range = 90, Mag = 6, Color = Color3.fromRGB(242, 182, 50) },
	QueensFang = { Order = 2, Name = "TYRANT FANG", Damage = 10, Rate = 0.33, Range = 100, Chain = 2, Mag = 8, Color = Color3.fromRGB(255, 150, 60),
		Craft = { Coins = 6000, Mats = { QueenClaw = 3 } }, Perk = "DARTS CHAIN TO 2 MORE TARGETS" },
	MatriarchMortar = { Order = 3, Name = "TITAN MORTAR", Damage = 32, Rate = 0.5, Range = 110, Splash = 9, Mag = 5, Color = Color3.fromRGB(110, 220, 200),
		Craft = { Coins = 126000, Mats = { MatriarchScale = 3, QueenClaw = 2 } }, Perk = "SHOTS BURST ON IMPACT" },
}
	-- (Spine River: crafted from the Tidebreaker's scales)
Config.Launchers.TideHarpoon = { Order = 4, Name = "TIDE HARPOON", Damage = 65, Rate = 0.48, Range = 120, Splash = 10, Chain = 1, Mag = 5, Color = Color3.fromRGB(70, 175, 235),
	Craft = { Coins = 576000, Mats = { TideScale = 3, MatriarchScale = 2 } }, Perk = "SHOTS BURST AND CHAIN" }
	-- (new periods: each boss's gear is the key to the next one)
Config.Launchers.ScytheRepeater = { Order = 5, Name = "SCYTHE REPEATER", Damage = 120, Rate = 0.42, Range = 120, Chain = 3, Mag = 7, Color = Color3.fromRGB(240, 226, 196),
	Craft = { Coins = 2500000, Mats = { ScytheClaw = 3, TideScale = 2 } }, Perk = "DARTS CHAIN TO 3 MORE TARGETS" }
Config.Launchers.FrostCannon = { Order = 6, Name = "FROST CANNON", Damage = 300, Rate = 0.5, Range = 125, Splash = 13, Mag = 5, Color = Color3.fromRGB(190, 230, 255),
	Craft = { Coins = 10800000, Mats = { FrostPlume = 3, ScytheClaw = 2 } }, Perk = "BIG FROSTY BURSTS" }
Config.Launchers.DawnBreaker = { Order = 7, Name = "DAWN BREAKER", Damage = 605, Rate = 0.48, Range = 130, Splash = 14, Chain = 2, Mag = 6, Color = Color3.fromRGB(255, 120, 70),
	Craft = { Coins = 45000000, Mats = { DawnScute = 3, FrostPlume = 2 } }, Perk = "BURSTS THAT CHAIN" }
Config.LauncherOrder = { "Rookie", "QueensFang", "MatriarchMortar", "TideHarpoon", "ScytheRepeater", "FrostCannon", "DawnBreaker" }
Config.Armors = {
	None = { Order = 1, Name = "FIELD VEST", HP = 100 },
	RaptorHide = { Order = 2, Name = "REX HIDE", HP = 210, Craft = { Coins = 9000, Mats = { QueenClaw = 3 } }, Perk = "2X HEALTH, FASTER DODGE" },
	MatriarchPlate = { Order = 3, Name = "TITAN PLATE", HP = 440, Craft = { Coins = 126000, Mats = { MatriarchScale = 3 } }, Perk = "4X HEALTH, STOMP PROOF" },
}
Config.Armors.TideShell = { Order = 4, Name = "TIDE SHELL", HP = 920, Craft = { Coins = 576000, Mats = { TideScale = 3 } }, Perk = "9X HEALTH" }
Config.Armors.ScytheMail = { Order = 5, Name = "SCYTHE MAIL", HP = 1930, Craft = { Coins = 2500000, Mats = { ScytheClaw = 3 } }, Perk = "19X HEALTH" }
Config.Armors.FrostCoat = { Order = 6, Name = "FROST COAT", HP = 4050, Craft = { Coins = 10800000, Mats = { FrostPlume = 3 } }, Perk = "40X HEALTH" }
Config.Armors.DawnScutes = { Order = 7, Name = "DAWN SCUTES", HP = 8500, Craft = { Coins = 45000000, Mats = { DawnScute = 3 } }, Perk = "85X HEALTH" }
Config.ArmorOrder = { "None", "RaptorHide", "MatriarchPlate", "TideShell", "ScytheMail", "FrostCoat", "DawnScutes" }
Config.Gadgets = {
	Bait = { Name = "MEAT BAIT", Cooldown = 18, Price = 1200, Desc = "DINOS CHASE IT FOR 4S" },
	Flare = { Name = "FLASH FLARE", Cooldown = 22, Craft = { Coins = 4500, Mats = { QueenClaw = 1 } }, Desc = "STUNS ALL NEARBY 2.5S" },
	Earthshaker = { Name = "EARTHSHAKER", Cooldown = 30, Craft = { Coins = 220000, Mats = { MatriarchScale = 1 } }, Desc = "3S STUN + BIG CALM HIT" },
}
Config.GadgetOrder = { "Bait", "Flare", "Earthshaker" }
Config.GadgetSlots = 2
Config.MaxLevel = 10
-- cost of the next stat level (from level L to L+1) for an item of a tier order
-- (progression pass 2026-10-12, tuned with a 2-hour sim: each tier's ten levels cost about that era's income, so
-- leveling fills the time between bosses; every tier at level 1 beats the tier before it at level 10)
Config.LevelTierCost = { 1, 12, 70, 320, 1400, 6000, 25000 }
function Config.LevelPrice(order: number, level: number): number
	return math.floor(300 * (Config.LevelTierCost[order] or Config.LevelTierCost[#Config.LevelTierCost]) * 1.45 ^ (level - 1))
end
Config.LevelBonus = 0.10 -- +10% damage (launcher) / health (armor) / armour (rover) per level
Config.Rack = { Base = 2, Max = 6, Prices = { 1700, 11000, 70000, 260000 } }
Config.BuddySlots = { Base = 1, Max = 3, Crafts = {
	{ Coins = 15000, Mats = { QueenClaw = 2 } },
	{ Coins = 580000, Mats = { MatriarchScale = 2 } },
} }

-- rovers (the expedition vehicle). Plating is a crafted upgrade on top.
Config.Vehicles = {
	RookieRanger = { Name = "ROOKIE RANGER", Tier = "STARTER ROVER", Price = 0, HP = 100, Cruise = 42, Boost = 62, Darts = 8, Order = 1, Color = Color3.fromRGB(242, 182, 50) },
	RaptorRunner = { Name = "RAPTOR RUNNER", Tier = "PURSUIT ROVER", Price = 20000, HP = 210, Cruise = 48, Boost = 72, Darts = 10, Order = 2, Color = Color3.fromRGB(255, 122, 26) },
	TitanTransport = { Name = "TITAN TRANSPORT", Tier = "ARMORED ROVER", Price = 300000, Mats = { MatriarchScale = 2 }, HP = 440, Cruise = 44, Boost = 64, Darts = 12, Order = 3, Color = Color3.fromRGB(217, 100, 43) },
}
Config.VehicleOrder = { "RookieRanger", "RaptorRunner", "TitanTransport" }
-- healing a hurt companion now instead of waiting: scales with rarity and how long is left
function Config.HealPrice(d, secsLeft: number): number
	local r = table.find(Config.RarityOrder, d.Rarity) or 1
	local full = 150 * r * r
	return math.max(25, math.floor(full * math.clamp(secsLeft / Config.Buddy.RestSecs, 0, 1) / 5 + 0.5) * 5)
end
function Config.Hurt(d, now: number): number -- seconds of rest left (0 = fit)
	return math.max(0, (d.HurtUntil or 0) - now)
end

-- tiers unlock in order: the one before id in its list (nil for the first / unlisted)
function Config.PrevTier(order: { string }, id: string): string?
	for i, x in ipairs(order) do
		if x == id then return order[i - 1] end
	end
	return nil
end
Config.Plating = { Name = "TITAN PLATING", Craft = { Coins = 300000, Mats = { MatriarchScale = 2 } }, HPMult = 1.4, Perk = "+40% ARMOUR, STOMP PROOF" }

--------------------------------------------------------------------------------
-- POWER (2026-10-14 rework: the POWER TRAINER replaced launcher levels)
--   POWER = TrainPower (earned standing on your trainer's pad, plus a share of every fight you win)
--         + your gear (launcher, armour, rover, gadgets: each tier is worth a fixed amount, Config.GearPower)
--         + your companions (Config.BuddyPower)
-- Everything grows EXPONENTIALLY era to era: each boss is 5x the one before, each trainer tier trains ~3.4x
-- faster than the last, gear tiers ~5x. Recommended POWER only matters as a ratio (Encounter.PowerMults: under it
-- you hit soft and get hit hard, over it the other way round), so the numbers can be as big and fun as we like.
--
-- THE CURVE ON PAPER (an era-level model, 2026-10-14; times are total time in the game). Boss POWER and when people get
-- there:
--     boss            POWER    mixed player   pure active    era sites (x the boss: 0.5 / 0.65 / 0.8)
--     TYRANT KING      2,000     ~20 min        ~22 min       (Fern Valley is soft: 300 / 650 / 1,000)
--     PLAINS TITAN    10,000     ~1h            ~50 min       5K / 6.5K / 8K
--     TIDEBREAKER     50,000     ~2h            ~1h40         25K / 32K / 40K
--     SCYTHE KING    250,000     ~3h45          ~2h50         125K / 160K / 200K
--     FROSTFANG     1,250,000    ~6h            ~4h30         625K / 800K / 1M
--     DAWN KING     6,250,000    ~9h45          ~7h           3.1M / 4M / 5M
--   (each era also has a minimum of play - keys, sites, the boss event - so an AFK pile of power never skips them)
--
-- THREE PLAYERS (total time in the game; "3 days" = left on the pad between sessions):
--                     30 min                  2 h                      8 h                        3 days
--   pure AFK        ~6K  (trainer LV4)       ~28K (LV4)              ~115K (LV4)                 ~1M (LV4)
--     (never fights: stuck in Fern Valley with Tyrant King-crushing POWER. The first time they play they
--      steamroll the first eras - "come back stronger" - but tiers past LV4 need boss wins)
--   pure active     ~9K  (LV8, Giant Plains)  ~200K (LV16, Red Cliffs) ~18M (LV25, every boss)    endgame
--     (never stands on the pad: takedowns / escapes / boss wins pay POWER = your rate x Rewards seconds)
--   mixed (30% pad) ~12K (LV8, Giant Plains)  ~130K (LV12, Spine River) ~10M (LV24, Dawn Desert)  endgame
--   An 8-hour AFK session at your current tier is worth ~1.5-2 eras of POWER: a real jump, never a skip (the
--   tier gate below holds the trainer at your boss progress, and offline coins - Config.Offline, 2 h of yard
--   income for 8 h away - can fill at most the 4 levels of your current tier).
--------------------------------------------------------------------------------
-- what each gear tier is worth (armour and rover levels add +10% each; plating x1.4 on the rover)
Config.GearPower = {
	Launchers = { Rookie = 250, QueensFang = 1500, MatriarchMortar = 7000, TideHarpoon = 35000, ScytheRepeater = 170000, FrostCannon = 850000, DawnBreaker = 4200000 },
	Armors = { None = 150, RaptorHide = 900, MatriarchPlate = 4500, TideShell = 22000, ScytheMail = 110000, FrostCoat = 550000, DawnScutes = 2700000 },
	Vehicles = { RookieRanger = 50, RaptorRunner = 300, TitanTransport = 2000 },
	Gadgets = { Bait = 50, Flare = 300, Earthshaker = 2000 },
}
-- POWER without training (gear + companions)
function Config.GearPowerOf(gear, buddies: { any }?): number
	local G = Config.GearPower
	local p = (G.Launchers[gear.Launcher] or G.Launchers.Rookie)
		+ (G.Armors[gear.Armor] or G.Armors.None) * (1 + Config.LevelBonus * ((gear.ArmorLvl or 1) - 1))
		+ (G.Vehicles[gear.Vehicle] or G.Vehicles.RookieRanger) * (1 + Config.LevelBonus * ((gear.RoverLvl or 1) - 1)) * (gear.Plating and Config.Plating.HPMult or 1)
	for _, g in ipairs(gear.Gadgets or {}) do if g ~= "" then p += G.Gadgets[g] or 0 end end
	for _, d in ipairs(buddies or {}) do p += Config.BuddyPower(d) end
	return p
end
-- Hunter Power: one number for "am I ready for this boss". trainPower = profile.TrainPower
function Config.HunterPower(gear, buddies: { any }?, trainPower: number?): number
	return math.floor(Config.GearPowerOf(gear, buddies) + math.max(0, tonumber(trainPower) or 0))
end
-- the same from a whole profile (buddies = Dinos.BuddyList(profile) on the server)
function Config.PowerOf(profile, buddies: { any }?): number
	if not profile then return 0 end
	return Config.HunterPower(profile.Gear or {}, buddies, profile.TrainPower)
end
-- how much harder your darts hit from training: x sqrt(POWER / gear POWER), 1..2 (x2 = training worth 3x your gear).
-- Replaces the old +10%-per-launcher-level (which topped out at x1.9). A fresh craft lowers it a little, but the new
-- launcher's base damage more than makes up for it.
function Config.DartMult(gear, buddies: { any }?, trainPower: number?): number
	local g = math.max(1, Config.GearPowerOf(gear, buddies))
	return math.clamp(math.sqrt((g + math.max(0, tonumber(trainPower) or 0)) / g), 1, 2)
end

-- THE POWER TRAINER: stand on your trainer's glowing pad and gain PerSec POWER every second (server-checked). Coins
-- buy the next level: more POWER per second, and every 4th level swaps in a bigger, cooler machine (Tier).
-- Levels[i] = level i: Cost = coins to REACH it (the HUD reads Levels[level + 1].Cost as the next price), PerSec at it.
-- Tier gate: the first level of tier k+1 (5, 9, 13, ...) needs boss k beaten (TierBoss[k]) - one machine per boss.
-- Costs follow each era's yard income (about a third of it goes here, like the old launcher levels).
Config.Trainer = {
	FirstFree = true, -- the first upgrade is free (after your first expedition; shares Flags.FreeUpgradeUsed)
	PerTier = 4,
	Levels = {
		{ Cost = 0, PerSec = 1 }, { Cost = 150, PerSec = 2 }, { Cost = 600, PerSec = 3 }, { Cost = 2000, PerSec = 4 },
		{ Cost = 6000, PerSec = 6 }, { Cost = 18000, PerSec = 8 }, { Cost = 32000, PerSec = 11 }, { Cost = 55000, PerSec = 14 },
		{ Cost = 95000, PerSec = 20 }, { Cost = 160000, PerSec = 26 }, { Cost = 260000, PerSec = 35 }, { Cost = 420000, PerSec = 46 },
		{ Cost = 650000, PerSec = 65 }, { Cost = 1000000, PerSec = 85 }, { Cost = 1500000, PerSec = 115 }, { Cost = 2300000, PerSec = 150 },
		{ Cost = 3400000, PerSec = 210 }, { Cost = 5000000, PerSec = 280 }, { Cost = 7500000, PerSec = 370 }, { Cost = 11000000, PerSec = 490 },
		{ Cost = 16000000, PerSec = 680 }, { Cost = 24000000, PerSec = 900 }, { Cost = 36000000, PerSec = 1200 }, { Cost = 54000000, PerSec = 1600 },
		{ Cost = 80000000, PerSec = 2200 }, { Cost = 120000000, PerSec = 3000 }, { Cost = 180000000, PerSec = 4000 }, { Cost = 270000000, PerSec = 5500 },
	},
	TierBoss = { "TyrantKing", "Titan", "Tidebreaker", "Scythe", "Frostfang", "DawnKing" },
	-- the machine each tier builds (tools/gen/islandKit.js Trainer1..Trainer7)
	TierNames = { "DART RANGE", "TRAINING YARD", "TARGET RAIL", "MECHA RANGE", "AMBER LAB", "FOSSIL ENGINE", "TITAN RIG" },
	-- fights pay POWER too (so you never HAVE to stand still): your trainer's PerSec x this many seconds
	Rewards = { Takedown = 90, Escape = 30, Boss = 600 },
	-- the pad: how close (studs, flat) and how far above it you must stand
	PadRadius = 4.6, PadHeight = 7,
}
function Config.TrainerLevel(profile): number
	local t = profile and profile.Trainer
	return math.clamp(math.floor(tonumber(t and t.Level) or 1), 1, #Config.Trainer.Levels)
end
function Config.TrainerTier(level: number): number
	return math.floor((math.max(1, level) - 1) / Config.Trainer.PerTier) + 1
end
function Config.TrainerPerSec(level: number): number
	local L = Config.Trainer.Levels
	return L[math.clamp(level, 1, #L)].PerSec
end
-- the boss you must beat before buying `level` (nil = no gate)
function Config.TrainerGate(level: number): string?
	if level <= 1 or (level - 1) % Config.Trainer.PerTier ~= 0 then return nil end
	return Config.Trainer.TierBoss[(level - 1) // Config.Trainer.PerTier]
end

--------------------------------------------------------------------------------
-- eras, encounter sites, bosses
--------------------------------------------------------------------------------
-- Kind: Pack (several small dinos, knock them all out), Brute (one big dino, rodeo finisher), Herd (a lead + herd)
Config.Eras = {
	{ Id = "FernValley", Name = "FERN VALLEY", Year = "68,000,000 BC", Built = true, Color = Color3.fromRGB(95, 211, 90), Boss = "TyrantKing",
		Sites = {
			-- (2026-10-14 power trainer curve, see Config.Trainer: a brand-new hunter is ~450 POWER, so the meadow is a
			-- soft start; the raptors and the herd want a few minutes on your trainer pad, the Tyrant King ~10 of them.
			-- Every later era's sites sit at 0.5 / 0.65 / 0.8 of its boss, and each boss is 5x the one before.)
			{ Id = "RaptorPack", Power = 650, Name = "RAPTOR PACK", Species = "Velociraptor", Kind = "Pack", Nest = 1, Count = 4, Blurb = "FOUR RAPTORS GUARD A NEST IN THE WILDS" },
			-- Guards: extra non-lead dinos that join the alarm (Encounter spawns them; a baby that charges you)
			{ Id = "HornNest", Power = 300, Name = "HORN MEADOW", Species = "Triceratops", Kind = "Brute", Nest = 2, Blurb = "A TRICERATOPS AND HER BABY NEST IN THE FLOWER MEADOW",
				Guards = { { Species = "Triceratops", Scale = 0.5, Calm = 0.3 } } },
			{ Id = "CrestLagoon", Power = 1000, Name = "CREST LAGOON", Species = "Parasaurolophus", Kind = "Herd", Nest = 3, Count = 4, Blurb = "A PARASAUROLOPHUS HERD BY THE LAKE" },
		} },
	{ Id = "GiantPlains", Name = "GIANT PLAINS", Year = "150,000,000 BC", Built = true, Color = Color3.fromRGB(226, 196, 106), Boss = "Titan", Unlock = { Boss = "TyrantKing", Coins = 25000 },
		Sites = {
			{ Id = "PlateRidge", Power = 5000, Name = "PLATE RIDGE", Species = "Stegosaurus", Kind = "Brute", Nest = 1, Blurb = "A STEGOSAURUS BASKS ON THE RIDGE" },
			{ Id = "ClubHollow", Power = 6500, Name = "CLUB HOLLOW", Species = "Ankylosaurus", Kind = "Brute", Nest = 2, Blurb = "AN ANKYLOSAURUS GUARDS THE HOLLOW" },
			{ Id = "TallGrove", Power = 8000, Name = "TALL GROVE", Species = "Brachiosaurus", Kind = "Brute", Nest = 3, Blurb = "A YOUNG BRACHIOSAURUS FEEDS IN THE GROVE" },
		} },
	{ Id = "SpineRiver", Name = "SPINE RIVER", Year = "97,000,000 BC", Built = true, Color = Color3.fromRGB(63, 200, 210), Boss = "Tidebreaker", Unlock = { Boss = "Titan", Coins = 300000 },
		Sites = {
			{ Id = "FishingBank", Power = 25000, Name = "FISHING BANK", Species = "Spinosaurus", Kind = "Brute", Nest = 1, Blurb = "A SPINOSAURUS FISHES FROM THE BANK" },
			{ Id = "CarnoRidge", Power = 32000, Name = "CARNO RIDGE", Species = "Carnotaurus", Kind = "Pack", Nest = 2, Count = 2, Blurb = "TWO CARNOTAURUS HUNT THE RIDGE" },
			{ Id = "CrocCreek", Power = 40000, Name = "CROC CREEK", Species = "Sarcosuchus", Kind = "Brute", Nest = 3, Blurb = "A SARCOSUCHUS LURKS IN THE MANGROVES" },
		} },
	-- 2026-10-12 new periods (Claude Doc "New Dinos and Eras"): maps tools/gen/redCliffs|frostForest|dawnDesert.js
	{ Id = "RedCliffs", Name = "RED CLIFFS", Year = "75,000,000 BC", Built = true, Color = Color3.fromRGB(232, 92, 48), Boss = "Scythe", Unlock = { Boss = "Tidebreaker", Coins = 2000000 },
		Sites = {
			{ Id = "ThiefsLedge", Power = 160000, Name = "THIEF'S LEDGE", Species = "Oviraptor", Kind = "Rival", Nest = 1, Count = 3, Blurb = "OVIRAPTORS RAID THE CLIFF NESTS - BEAT THEM TO THE EGGS" },
			{ Id = "DuneBurrows", Power = 125000, Name = "DUNE BURROWS", Species = "Protoceratops", Kind = "Herd", Nest = 2, Count = 4, Blurb = "A PROTOCERATOPS HERD BURIES ITS EGGS" },
			{ Id = "RunnerFlats", Power = 200000, Name = "RUNNER FLATS", Species = "Gallimimus", Kind = "Herd", Nest = 3, Count = 3, Blurb = "A GALLIMIMUS FLOCK RACES THE FLATS" },
		} },
	{ Id = "FrostForest", Name = "FROST FOREST", Year = "125,000,000 BC", Built = true, Color = Color3.fromRGB(120, 200, 255), Boss = "Frostfang", Unlock = { Boss = "Scythe", Coins = 12000000 },
		Sites = {
			{ Id = "GliderPines", Power = 800000, Name = "GLIDER PINES", Species = "Microraptor", Kind = "Flyer", Nest = 1, Count = 3, Blurb = "MICRORAPTORS GLIDE FROM THE PINES" },
			{ Id = "FernHollow", Power = 625000, Name = "FERN HOLLOW", Species = "Psittacosaurus", Kind = "Herd", Nest = 2, Count = 4, Blurb = "A PSITTACOSAURUS HERD HIDES IN THE FERNS" },
			{ Id = "LogWarren", Power = 1000000, Name = "LOG WARREN", Species = "Compy", Kind = "Swarm", Nest = 3, Count = 10, Blurb = "A COMPY SWARM NESTS IN THE FALLEN LOGS" },
		} },
	{ Id = "DawnDesert", Name = "DAWN DESERT", Year = "215,000,000 BC", Built = true, Color = Color3.fromRGB(255, 140, 90), Boss = "DawnKing", Unlock = { Boss = "Frostfang", Coins = 70000000 },
		Sites = {
			{ Id = "OasisPack", Power = 3100000, Name = "OASIS PACK", Species = "Coelophysis", Kind = "Pack", Nest = 1, Count = 5, Blurb = "FIVE COELOPHYSIS HUNT THE OASIS" },
			{ Id = "TallCycads", Power = 4000000, Name = "TALL CYCADS", Species = "Plateosaurus", Kind = "Herd", Nest = 2, Count = 3, Blurb = "A PLATEOSAURUS HERD FEEDS IN THE CYCADS" },
			{ Id = "CrestRocks", Power = 5000000, Name = "CREST ROCKS", Species = "Dilophosaurus", Kind = "Pack", Nest = 3, Count = 2, Blurb = "TWO DILOPHOSAURUS GUARD THE RED ROCKS" },
		} },
	{ Id = "AshCanyon", Name = "ASH CANYON", Year = "70,000,000 BC", Built = false, Color = Color3.fromRGB(255, 106, 42) },
	{ Id = "RexJungle", Name = "REX JUNGLE", Year = "66,000,000 BC", Built = false, Color = Color3.fromRGB(60, 160, 70) },
	{ Id = "DeepSea", Name = "DEEP SEA", Year = "80,000,000 BC", Built = false, Color = Color3.fromRGB(42, 110, 220) },
	{ Id = "TheLab", Name = "THE LAB", Year = "PRESENT DAY", Built = false, Color = Color3.fromRGB(255, 48, 48) },
}
-- how much an era is worth: run coins, index entries and repairs scale by it (Fern Valley 1 ... Dawn Desert 150)
Config.EraTiers = { FernValley = 1, GiantPlains = 4, SpineRiver = 10, RedCliffs = 25, FrostForest = 60, DawnDesert = 150, AshCanyon = 400, RexJungle = 1000, DeepSea = 2500, TheLab = 6000 }
function Config.EraTier(id: string?): number
	return id and Config.EraTiers[id] or 1
end
function Config.Era(id: string)
	for _, e in ipairs(Config.Eras) do if e.Id == id then return e end end
	return nil
end
function Config.Site(eraId: string, siteId: string)
	local e = Config.Era(eraId)
	if not e or not e.Sites then return nil end
	for _, s in ipairs(e.Sites) do if s.Id == siteId then return s end end
	return nil
end

Config.Bosses = {
	-- every ruler is a species that never shows up at its era's sites (2026-10-11: was a raptor queen and a
	-- brachiosaurus matriarch). ids changed too; Data migrates old saves (RaptorQueen -> TyrantKing, Matriarch -> Titan)
	TyrantKing = { Name = "TYRANT KING", Era = "FernValley", Species = "TyrannosaurusRex", Power = 2000, Calm = 900, Scale = 1.15,
		Material = "QueenClaw", Title = "BOSS OF FERN VALLEY", Color = Color3.fromRGB(255, 120, 60) },
	Titan = { Name = "PLAINS TITAN", Era = "GiantPlains", Species = "Giganotosaurus", Power = 10000, Calm = 4200, Scale = 1.05,
		Material = "MatriarchScale", Title = "BOSS OF GIANT PLAINS", Color = Color3.fromRGB(110, 220, 200) },
	-- a sea ruler: Water = true hands the fight to SeaKing.luau (docks in the bay, a boat chase, the Maw)
	Tidebreaker = { Name = "TIDEBREAKER", Era = "SpineRiver", Species = "Mosasaurus", Power = 50000, Calm = 9000, Scale = 0.9,
		Material = "TideScale", Title = "BOSS OF SPINE RIVER", Color = Color3.fromRGB(70, 175, 235), Water = true },
	-- new periods (2026-10-12): a claw-handed plant-eater, a feathered tyrant, and the croc-cousin that ruled before dinosaurs
	Scythe = { Name = "SCYTHE KING", Era = "RedCliffs", Species = "Therizinosaurus", Power = 250000, Calm = 15000, Scale = 1.0,
		Material = "ScytheClaw", Title = "BOSS OF RED CLIFFS", Color = Color3.fromRGB(240, 226, 196) },
	Frostfang = { Name = "FROSTFANG", Era = "FrostForest", Species = "Yutyrannus", Power = 1250000, Calm = 26000, Scale = 1.05,
		Material = "FrostPlume", Title = "BOSS OF FROST FOREST", Color = Color3.fromRGB(190, 230, 255) },
	DawnKing = { Name = "DAWN KING", Era = "DawnDesert", Species = "Postosuchus", Power = 6250000, Calm = 40000, Scale = 1.1,
		Material = "DawnScute", Title = "BOSS OF DAWN DESERT", Color = Color3.fromRGB(255, 120, 70) },
}
-- boss tiers: index 1 Normal, 2 Hard, 3 Nightmare, 4+ Apex 1, 2, ...
function Config.BossTier(i: number)
	if i <= 1 then return { Name = "NORMAL", Calm = 1, Damage = 1, Power = 1, Mats = 3, Luck = 2.5 } end
	if i == 2 then return { Name = "HARD", Calm = 1.8, Damage = 1.4, Power = 1.6, Mats = 4, Luck = 3.2 } end
	if i == 3 then return { Name = "NIGHTMARE", Calm = 3, Damage = 1.9, Power = 2.6, Mats = 5, Luck = 4 } end
	local n = i - 3
	return { Name = "APEX " .. n, Calm = 3 + 0.8 * n, Damage = 1.9 + 0.15 * n, Power = 2.6 + 0.6 * n, Mats = 5 + n, Luck = 4 + 0.4 * n }
end
Config.BossEventEvery = 600 -- seconds between server-wide ruler events
Config.BossEventWindow = 120 -- seconds to join one
Config.KeyChance = 0.25 -- chance an encounter takedown drops a Boss Key for that era's ruler
-- mastery: one star per boss tier cleared; each star is a small permanent perk
Config.StarPerk = { Damage = 0.02, Luck = 0.04, Income = 0.03 }

--------------------------------------------------------------------------------
-- encounters (on foot) and the escape chase
--------------------------------------------------------------------------------
-- the dodge is a real ROLL (tester feedback 2026-10-12: "barely moves you", "spammable"): ~22 studs in half a second,
-- untouchable for the first DodgeInvuln of it, then a proper cooldown. A perfect dodge (rolling THROUGH a hit) cuts
-- the rest of that cooldown down to PerfectRefund instead of wiping it.
Config.Player = { WalkSpeed = 16, SprintSpeed = 24, DodgeCooldown = 1.6, DodgeTime = 0.5, DodgeDistance = 22, DodgeInvuln = 0.36, PerfectRefund = 0.5, ReviveTime = 2.2, DownedTime = 15 }
Config.Encounter = {
	-- how hard the dinos press (2026-10-12: "combat is too easy, especially for one dino"): gaps between attacks,
	-- the weak-spot window after one, wind-up times, and follow-up chains. A dino fighting alone hits hardest.
	Aggression = 0.62, -- x the species' gap between attacks
	LoneAggression = 0.78, -- x again when it's the only dino left standing
	-- smarter dinos, per era (2026-10-13, Fern Valley first): Dodge = chance to sidestep a dart it sees coming (not
	-- mid-swing, not an ambush or a weak-spot shot), DodgeGap = seconds between sidesteps; Flank = a pack spreads round
	-- you and one comes from behind; Help = how hurt (share of its calm) it is when it roars for the others
	Smart = {
		FernValley = { Dodge = 0.22, DodgeGap = 3.5, Flank = true, Help = 0.5 },
	},
	FirstFightHurt = 1.4, -- the scripted first Triceratops fight: its hits sting (you'll want to dodge once) - but you can't go down
	LoneSpeed = 1.15, -- a lone dino closes in faster
	RecoverMult = 0.75, -- x the weak-spot window after an attack
	TeleMult = 0.9, -- x every wind-up (still readable)
	ChainLone = 0.35, ChainEnraged = 0.5, -- chance of an instant follow-up attack (no weak spot between)
	-- bosses press harder than anything else (2026-10-13 "bosses are easy, make boss attacks quicker"): x the gap
	-- between attacks, x the wind-up, x the weak-spot opening, a chance to chain, x move speed, x the time between
	-- signature moves (LandKings) and between the sea boss's moves (SeaKing)
	BossPace = { Gap = 0.6, Tele = 0.82, Recover = 0.72, Chain = 0.45, Speed = 1.12, Sig = 0.68, SeaCircle = 0.68 },
	EggsBonus = 2, -- eggs in a nest = players + this (solo: 3, so a bigger roof rack always pays)
	ScrambleTime = 12, -- seconds to grab eggs before the chase
	GetInTime = 10, -- seconds to reach your rover when the chase starts (then you're pulled in)
	ResetTime = 20, -- an empty site rearms after this
	ComboWindow = 2.6, ComboMax = 5, ComboBonus = 0.15, -- each combo step adds 15% calm damage
	WeakSpotMult = 2, -- darts while a dino recovers from an attack hit its glowing weak spot
	Reload = 1.3, -- a launcher's magazine (Launchers[].Mag) empties, then this; a perfect dodge reloads instantly
	-- every time a site resets it rolls a mood (shown on the map card): a real reason to pick one site over another
	Moods = {
		{ Id = "Calm", Name = "CALM", Desc = "", Sight = 1, Hear = 1, Eggs = 0, Weight = 50 },
		{ Id = "Drowsy", Name = "DROWSY", Desc = "EASIER TO SNEAK", Sight = 0.6, Hear = 0.7, Eggs = 0, Weight = 25 },
		{ Id = "Restless", Name = "RESTLESS", Desc = "SHARP SENSES - +1 EGG", Sight = 1.35, Hear = 1.3, Eggs = 1, Weight = 25 },
	},
	RodeoAt = 0.85, -- calm fraction that opens the rodeo finisher (Brute / boss)
	-- (2026-10-12 testers: "hard" and "tedious" - a shorter ride, and a throw-off only knocks it back a little,
	-- so the rodeo re-opens after a few more darts instead of a whole second calm-down)
	RodeoTime = 3, RodeoFailCalm = 0.78,
	TakedownCoins = 350, EscapeCoins = 120, -- x the era tier (Config.EraTier)
	ParkBack = 80, -- you park this far back along the road and sneak in (Encounter.ParkCFrame shifts it if it would be blocked or hidden from the nest)
	-- the sneak phase: dinos graze until they notice you. Awareness fills from sight (a cone in front, line of
	-- sight, faster up close, half as fast if you hold still) and noise (sprinting is loud, walking near them is too)
	Sneak = { SightRange = 30, SightAngle = 120, SightRate = 1.5, SprintHear = 36, SprintRate = 2.2, WalkHear = 12, Decay = 0.22, AmbushMult = 3, SneakSpeed = 10 },
}
-- per species: calm (knock-out bar), move speed, attack cadence and damage. Attacks are telegraphed shapes.
Config.Combat = {
	TyrannosaurusRex = { Calm = 900, Speed = 16, Scale = 1.15, Gap = { 1.4, 2.4 }, Attacks = {
		{ Id = "Bite", Shape = "Cone", Len = 16, Angle = 70, Tele = 0.85, Dmg = 28 },
		{ Id = "Charge", Shape = "Line", Len = 34, Width = 8, Tele = 1.0, Dmg = 34, Dash = true },
		{ Id = "TailWhip", Shape = "Cone", Len = 15, Angle = 110, Tele = 0.9, Dmg = 22, Back = true },
	} },
	Giganotosaurus = { Calm = 4200, Speed = 15, Scale = 1.05, Gap = { 1.5, 2.6 }, Attacks = {
		{ Id = "Lunge", Shape = "Line", Len = 30, Width = 7, Tele = 0.9, Dmg = 38, Dash = true },
		{ Id = "JawSweep", Shape = "Cone", Len = 18, Angle = 95, Tele = 1.0, Dmg = 34 },
		{ Id = "Stomp", Shape = "Circle", Radius = 15, Tele = 1.1, Dmg = 32, Self = true },
	} },
	Velociraptor = { Calm = 70, Speed = 22, Scale = 1.4, Gap = { 1.6, 2.8 }, Attacks = {
		{ Id = "Pounce", Shape = "Line", Len = 18, Width = 5, Tele = 0.75, Dmg = 18, Dash = true },
		{ Id = "Bite", Shape = "Cone", Len = 9, Angle = 50, Tele = 0.55, Dmg = 14 },
	} },
	Triceratops = { Calm = 420, Speed = 14, Scale = 1.1, Gap = { 1.8, 3 }, Attacks = {
		{ Id = "Charge", Shape = "Line", Len = 38, Width = 9, Tele = 1.1, Dmg = 30, Dash = true },
		{ Id = "HornSweep", Shape = "Cone", Len = 13, Angle = 70, Tele = 0.8, Dmg = 22 },
		{ Id = "Stomp", Shape = "Circle", Radius = 12, Tele = 1, Dmg = 20, Self = true },
	} },
	Parasaurolophus = { Calm = 160, Speed = 18, Scale = 1.0, Gap = { 2, 3.2 }, Attacks = {
		{ Id = "Stampede", Shape = "Line", Len = 34, Width = 7, Tele = 1, Dmg = 22, Dash = true },
		{ Id = "Honk", Shape = "Ring", Radius = 18, Inner = 7, Tele = 1.1, Dmg = 16, Self = true },
		{ Id = "TailWhip", Shape = "Cone", Len = 10, Angle = 80, Tele = 0.6, Dmg = 14, Back = true },
	} },
	Stegosaurus = { Calm = 900, Speed = 12, Scale = 1.0, Gap = { 1.8, 3 }, Attacks = {
		{ Id = "TailSwipe", Shape = "Cone", Len = 16, Angle = 120, Tele = 0.9, Dmg = 32, Back = true },
		{ Id = "PlateRush", Shape = "Line", Len = 30, Width = 10, Tele = 1.1, Dmg = 34, Dash = true },
	} },
	Ankylosaurus = { Calm = 1100, Speed = 11, Scale = 1.0, Gap = { 2, 3.2 }, Attacks = {
		{ Id = "ClubSmash", Shape = "Circle", Radius = 14, Tele = 1.1, Dmg = 38, Self = true },
		{ Id = "ArmoredRoll", Shape = "Line", Len = 34, Width = 10, Tele = 1, Dmg = 34, Dash = true },
	} },
	Spinosaurus = { Calm = 2100, Speed = 13, Scale = 1.0, Gap = { 1.6, 2.8 }, Attacks = {
		{ Id = "ClawSwipe", Shape = "Cone", Len = 15, Angle = 80, Tele = 0.85, Dmg = 40 },
		{ Id = "SnapLunge", Shape = "Line", Len = 30, Width = 7, Tele = 0.95, Dmg = 44, Dash = true },
		{ Id = "TailSlap", Shape = "Cone", Len = 16, Angle = 110, Tele = 0.9, Dmg = 36, Back = true },
	} },
	Carnotaurus = { Calm = 1300, Speed = 20, Scale = 1.0, Gap = { 1.5, 2.6 }, Attacks = {
		{ Id = "HornRam", Shape = "Line", Len = 32, Width = 6, Tele = 0.85, Dmg = 38, Dash = true },
		{ Id = "Bite", Shape = "Cone", Len = 11, Angle = 60, Tele = 0.6, Dmg = 30 },
	} },
	-- the Tidebreaker's moves are scripted in SeaKing.luau; this set is only a fallback
	Mosasaurus = { Calm = 9000, Speed = 16, Scale = 0.9, Gap = { 1.6, 2.6 }, Attacks = {
		{ Id = "Bite", Shape = "Cone", Len = 18, Angle = 70, Tele = 0.9, Dmg = 40 },
	} },
	-- the SuperCroc: slow on land, every attack an ambush. BankLunge telegraph = bubbles, then the eyes sink;
	-- JawTrap = it lies still with the jaws wide open and snaps if you walk into the cone
	Sarcosuchus = { Calm = 3000, Speed = 11, Scale = 1.0, Gap = { 1.8, 3.0 }, Attacks = {
		{ Id = "BankLunge", Shape = "Line", Len = 30, Width = 7, Tele = 1.3, Dmg = 46, Dash = true },
		{ Id = "TailWave", Shape = "Cone", Len = 18, Angle = 120, Tele = 0.95, Dmg = 36, Back = true },
		{ Id = "JawTrap", Shape = "Cone", Len = 14, Angle = 55, Tele = 2.2, Dmg = 54 },
	} },
	-- Red Cliffs (2026-10-12)
	Oviraptor = { Calm = 1700, Speed = 22, Scale = 1.5, Gap = { 1.4, 2.6 }, Attacks = {
		{ Id = "BeakSnatch", Shape = "Line", Len = 16, Width = 5, Tele = 0.7, Dmg = 20, Dash = true, Snatch = true },
		{ Id = "KickFlurry", Shape = "Cone", Len = 9, Angle = 70, Tele = 0.6, Dmg = 28 },
		{ Id = "Screech", Shape = "Ring", Radius = 16, Inner = 6, Tele = 1.0, Dmg = 14, Self = true },
	} },
	Protoceratops = { Calm = 1060, Speed = 15, Scale = 1.3, Gap = { 1.6, 2.8 }, Attacks = {
		{ Id = "FrillBash", Shape = "Cone", Len = 11, Angle = 110, Tele = 0.8, Dmg = 34 },
		{ Id = "BeakBite", Shape = "Cone", Len = 8, Angle = 50, Tele = 0.55, Dmg = 25 },
		{ Id = "HerdCharge", Shape = "Line", Len = 30, Width = 7, Tele = 1.0, Dmg = 36, Dash = true },
	} },
	-- (Dodge: it sidesteps a dart it sees coming - lead your shots, or hit it mid-swing)
	Gallimimus = { Calm = 1700, Speed = 26, Scale = 1.0, Gap = { 1.4, 2.4 }, Dodge = 0.3, Attacks = {
		{ Id = "Peck", Shape = "Cone", Len = 12, Angle = 45, Tele = 0.6, Dmg = 28 },
		{ Id = "FlockKick", Shape = "Circle", Radius = 11, Tele = 0.85, Dmg = 39, Self = true },
		{ Id = "Stampede", Shape = "Line", Len = 40, Width = 6, Tele = 0.9, Dmg = 42, Dash = true },
	} },
	Therizinosaurus = { Calm = 15000, Speed = 13, Scale = 1.0, Gap = { 1.6, 2.8 }, Attacks = {
		{ Id = "ScytheSweep", Shape = "Cone", Len = 22, Angle = 140, Tele = 1.0, Dmg = 62 },
		{ Id = "XSlash", Shape = "Line", Len = 26, Width = 9, Tele = 1.3, Dmg = 73, Dash = true },
		{ Id = "ClawHook", Shape = "Line", Len = 30, Width = 8, Tele = 1.1, Dmg = 56, Dash = true },
	} },
	-- Frost Forest (2026-10-12). Steal = darts a hit takes out of your magazine
	Microraptor = { Calm = 2750, Speed = 24, Scale = 1.5, Gap = { 1.4, 2.4 }, Attacks = {
		{ Id = "DiveStrike", Shape = "Line", Len = 22, Width = 4, Tele = 0.8, Dmg = 34, Dash = true },
		{ Id = "Peck", Shape = "Cone", Len = 7, Angle = 60, Tele = 0.45, Dmg = 20 },
		{ Id = "WingBuffet", Shape = "Circle", Radius = 7, Tele = 0.7, Dmg = 24, Self = true },
	} },
	Psittacosaurus = { Calm = 1750, Speed = 17, Scale = 1.2, Gap = { 1.8, 3 }, Attacks = {
		{ Id = "BeakNip", Shape = "Cone", Len = 8, Angle = 60, Tele = 0.55, Dmg = 22 },
		{ Id = "HerdRush", Shape = "Line", Len = 24, Width = 6, Tele = 0.9, Dmg = 30, Dash = true },
		{ Id = "QuillRattle", Shape = "Ring", Radius = 12, Inner = 4, Tele = 1.0, Dmg = 18, Self = true },
	} },
	Compy = { Calm = 1580, Speed = 23, Scale = 1.3, Gap = { 1.0, 1.8 }, Attacks = {
		{ Id = "Nip", Shape = "Cone", Len = 5, Angle = 70, Tele = 0.4, Dmg = 12 },
		{ Id = "DartSnatch", Shape = "Line", Len = 14, Width = 3, Tele = 0.6, Dmg = 8, Dash = true, Steal = 1 },
		{ Id = "SwarmLeap", Shape = "Circle", Radius = 4, Tele = 0.7, Dmg = 16, AtTarget = true },
	} },
	Yutyrannus = { Calm = 26000, Speed = 15, Scale = 1.1, Gap = { 1.4, 2.5 }, Attacks = {
		{ Id = "FrostBite", Shape = "Cone", Len = 17, Angle = 70, Tele = 0.85, Dmg = 64 },
		{ Id = "IceStomp", Shape = "Circle", Radius = 15, Tele = 1.1, Dmg = 60, Self = true },
		{ Id = "FrostRoar", Shape = "Cone", Len = 26, Angle = 60, Tele = 1.2, Dmg = 36, Stun = true },
		{ Id = "TailSweep", Shape = "Cone", Len = 16, Angle = 120, Tele = 0.9, Dmg = 48, Back = true },
	} },
	-- Dawn Desert (2026-10-12). Each attack Id is also the action the client plays
	Coelophysis = { Calm = 2200, Speed = 23, Scale = 1.3, Gap = { 1.4, 2.6 }, Attacks = {
		{ Id = "SnapBite", Shape = "Cone", Len = 8, Angle = 55, Tele = 0.5, Dmg = 24 },
		{ Id = "DartLunge", Shape = "Line", Len = 16, Width = 4, Tele = 0.65, Dmg = 30, Dash = true },
	} },
	Plateosaurus = { Calm = 3700, Speed = 12, Scale = 1.0, Gap = { 2.0, 3.2 }, Attacks = {
		{ Id = "RearSlam", Shape = "Circle", Radius = 13, Tele = 1.2, Dmg = 64, Self = true, Stun = true },
		{ Id = "ThumbSwipe", Shape = "Cone", Len = 12, Angle = 80, Tele = 0.8, Dmg = 48 },
		{ Id = "TailSwipe", Shape = "Cone", Len = 17, Angle = 110, Tele = 0.9, Dmg = 48, Back = true },
	} },
	Dilophosaurus = { Calm = 7000, Speed = 19, Scale = 1.0, Gap = { 1.5, 2.6 }, Attacks = {
		{ Id = "BlindingSpit", Shape = "Line", Len = 26, Width = 4, Tele = 0.9, Dmg = 20 },
		{ Id = "CrestDisplay", Shape = "Circle", Radius = 14, Tele = 1.0, Dmg = 12, Self = true, Stun = true },
		{ Id = "DoubleBite", Shape = "Cone", Len = 11, Angle = 60, Tele = 0.7, Dmg = 56 },
	} },
	Postosuchus = { Calm = 40000, Speed = 16, Scale = 1.0, Gap = { 1.4, 2.4 }, Attacks = {
		{ Id = "MudAmbush", Shape = "Circle", Radius = 11, Tele = 1.3, Dmg = 80, AtTarget = true },
		{ Id = "UprightCharge", Shape = "Line", Len = 36, Width = 8, Tele = 1.0, Dmg = 84, Dash = true },
		{ Id = "BiteShake", Shape = "Cone", Len = 15, Angle = 70, Tele = 0.85, Dmg = 92 },
		{ Id = "TailLash", Shape = "Cone", Len = 17, Angle = 110, Tele = 0.9, Dmg = 64, Back = true },
	} },
	Brachiosaurus = { Calm = 1500, Speed = 8, Scale = 0.9, Gap = { 2.2, 3.4 }, Attacks = {
		{ Id = "StompWave", Shape = "Ring", Radius = 26, Inner = 10, Tele = 1.3, Dmg = 36, Self = true },
		{ Id = "NeckSweep", Shape = "Cone", Len = 30, Angle = 60, Tele = 1.2, Dmg = 32 },
	} },
}

-- era scaling (progression pass 2026-10-12): gear now grows ~2x per tier so a new launcher / armour is always a
-- real step up. The Combat numbers above are written for the OLD gear curve; this scales each era's dinos (and its
-- boss) so a fight at the gear you're expected to have there lasts as long and hurts as much as it did before.
-- Calm = x knock-out bar, Dmg = x attack damage, Chase = x rover damage in that era's chase.
Config.EraScale = {
	FernValley = { Calm = 1.1, Dmg = 1.25, Chase = 1.15 }, -- (2026-10-13: a little harder; still under Giant Plains)
	GiantPlains = { Calm = 1.23, Dmg = 1.5, Chase = 1.6 },
	SpineRiver = { Calm = 2.14, Dmg = 1.96, Chase = 4.5 },
	RedCliffs = { Calm = 2.68, Dmg = 2.74, Chase = 5.5 },
	FrostForest = { Calm = 3.21, Dmg = 3.98, Chase = 6 },
	DawnDesert = { Calm = 5.18, Dmg = 5.7, Chase = 6.5 },
}
function Config.EraScaleOf(eraId: string?)
	return eraId and Config.EraScale[eraId] or Config.EraScale.FernValley
end
for species, c in pairs(Config.Combat) do
	local sp = Config.Species[species]
	local k = Config.EraScaleOf(sp and sp.Era)
	c.Calm = math.floor(c.Calm * k.Calm + 0.5)
	for _, a in ipairs(c.Attacks or {}) do
		if a.Dmg then a.Dmg = math.floor(a.Dmg * k.Dmg + 0.5) end
	end
end
for _, b in pairs(Config.Bosses) do
	b.Calm = math.floor(b.Calm * Config.EraScaleOf(b.Era).Calm + 0.5)
end

-- the rover chase that ends every encounter (driving is autopilot; you're the gunner)
Config.Expedition = {
	BoostDrain = 0.28, BoostRefill = 0.06, BoostPickup = 0.45, RepairPickup = 25, CoinPickup = 30,
	ExtractBonus = 150,
	BrakeSpeed = 6,
	Damage = { Lunge = 22, Charge = 37, Stampede = 27, Log = 13, Boulder = 17, Branch = 11, Pillar = 19, Latch = 15, Gnaw = 8, OnFoot = 34 },
	-- the rover flips at 0 HP (not an instant wreck): some eggs crack, then repair for coins or run for it on foot
	ToppleBreak = 0.4, -- chance each egg on the rack cracks when the rover flips
	RepairBase = 250, -- coins to flip it back, x the era's tier (Fern Valley 1, Giant Plains 4)
	RepairHP = 0.6, -- of max armour after a repair
	FootHP = 100, -- on foot you black out after this much (an on-foot bite is Damage.OnFoot)
	ToppleHold = 6, -- seconds the chasers circle before closing in again (time to decide)
	LatchDropChance = 0.25, -- each chew can shake an egg off the rack
	EggDropChance = 0.35, -- chance a big hit knocks an egg off the roof rack
	GrabSpeed = 14, GrabRange = 26,
	DartRange = 85, DartSpeed = 140, DartCooldown = 0.8, DartPickup = 3, DartRegen = 9,
	StunTime = 2.1, BossReward = 450,
}
Config.Chase = {
	Velociraptor = { Scale = 1.55, Run = 56, Catchup = 66, Lunge = 0.34, Telegraph = 0.72, Recover = 1.0, Stamina = 100, Tire = 9 },
	Alpha = { Scale = 1.15, Calm = 5, Damage = 30, Name = "TYRANT KING", Gap = 11 },
	Triceratops = { Scale = 1.0, Charge = 34, Telegraph = 1.3 },
	Parasaurolophus = { Scale = 0.95, Charge = 30, Telegraph = 0.9 },
}

--------------------------------------------------------------------------------
-- quests (optional, from NPCs) and the daily chest
--------------------------------------------------------------------------------
-- Story: the Professor's chain, one step at a time. Goal kinds: Hatch, Takedown, Escape, Eggs, Craft, Boss, Rarity
Config.Story = {
	{ Id = "S1", Npc = "Professor", Title = "FIRST STEPS", Goal = { Kind = "Expedition", Count = 1 }, Reward = { Coins = 450 },
		Text = "Welcome to Base Camp, rookie! Take your rover through the Time Gate and bring me back an egg." },
	{ Id = "S2", Npc = "Professor", Title = "NEW LIFE", Goal = { Kind = "Hatch", Count = 1 }, Reward = { Coins = 600 },
		Text = "An egg! Pop it in an incubator on your island and let's see what hatches." },
	{ Id = "S3", Npc = "Professor", Title = "THE KNOCKOUT", Goal = { Kind = "Takedown", Count = 1 }, Reward = { Coins = 1150 },
		Text = "Grabbing eggs is fine, but knock a dino out first and the nest gives you better eggs. Try a takedown." },
	{ Id = "S4", Npc = "Professor", Title = "THE TYRANT KING", Goal = { Kind = "Boss", Boss = "TyrantKing", Count = 1 }, Reward = { Coins = 4350 },
		Text = "The thing that flipped your rover is the boss of Fern Valley. A T. rex, older than the trees. Knock it out and the Time Gate's next dial opens." },
	{ Id = "S5", Npc = "Mechanic", Title = "FANG AND CLAW", Goal = { Kind = "Craft", Count = 1, Mat = "QueenClaw" }, Reward = { Coins = 2900 },
		Text = "Bring me the Rex's claws and I'll stitch you armor that laughs at teeth." },
	{ Id = "S6", Npc = "Professor", Title = "GIANT STEPS", Goal = { Kind = "Boss", Boss = "Titan", Count = 1 }, Reward = { Coins = 30000 },
		Text = "The Giant Plains boss is a Giganotosaurus they call the Titan. Bring a big launcher." },
	{ Id = "S7", Npc = "Mechanic", Title = "TITAN FORGED", Goal = { Kind = "Craft", Count = 1, Mat = "MatriarchScale" }, Reward = { Coins = 60000 },
		Text = "Titan scales! Hand them over and I'll forge you a plate no stomp can dent." },
	{ Id = "S8", Npc = "Professor", Title = "THE TIDEBREAKER", Goal = { Kind = "Boss", Boss = "Tidebreaker", Count = 1 }, Reward = { Coins = 150000 },
		Text = "Something huge circles the Spine River docks. Mind the water - it pulls you in." },
	{ Id = "S9", Npc = "Professor", Title = "THE SCYTHE KING", Goal = { Kind = "Boss", Boss = "Scythe", Count = 1 }, Reward = { Coins = 400000 },
		Text = "Red Cliffs is ruled by a plant-eater with claws like scythes. Don't let the leaves fool you." },
	{ Id = "S10", Npc = "Professor", Title = "FROSTFANG", Goal = { Kind = "Boss", Boss = "Frostfang", Count = 1 }, Reward = { Coins = 1000000 },
		Text = "A feathered tyrant hunts the Frost Forest. Its roar freezes you on the spot - keep moving." },
	{ Id = "S11", Npc = "Professor", Title = "THE DAWN KING", Goal = { Kind = "Boss", Boss = "DawnKing", Count = 1 }, Reward = { Coins = 2500000 },
		Text = "Before the dinosaurs there was the Dawn King. It hides in the mud. Bring everything you've got." },
}
-- repeatable side quests (Ranger in each era, Egg Keeper at camp); one offered at a time per NPC. Rewards are in
-- Fern Valley coins and grow with the furthest era you've opened (x Config.EraTier)
Config.SideQuests = {
	Ranger = {
		{ Title = "PACK HUNTER", Goal = { Kind = "Takedown", Count = 2 }, Reward = { Coins = 850 } },
		{ Title = "QUICK HANDS", Goal = { Kind = "Eggs", Count = 6 }, Reward = { Coins = 900 } },
		{ Title = "CLEAN GETAWAY", Goal = { Kind = "Escape", Count = 2 }, Reward = { Coins = 700 } },
		{ Title = "BIG GAME", Goal = { Kind = "Takedown", Count = 4 }, Reward = { Coins = 1600 } },
	},
	EggKeeper = {
		{ Title = "INCUBATOR DUTY", Goal = { Kind = "Hatch", Count = 3 }, Reward = { Coins = 850 } },
		{ Title = "SOMETHING SHINY", Goal = { Kind = "Rarity", Rarity = "Rare", Count = 1 }, Reward = { Coins = 1750 } },
		{ Title = "FULL NURSERY", Goal = { Kind = "Hatch", Count = 6 }, Reward = { Coins = 1800 } },
	},
}
Config.MaxQuests = 3
Config.Daily = { Coins = { 450, 750, 1200, 1800, 2700, 3900, 6000 }, EggOn = { [3] = true, [7] = true }, Every = 20 * 3600, Reset = 48 * 3600,
	Enabled = false } -- (switched off 2026-10-13, user: "remove daily chest for now" - the chest leaves the plaza; true brings it back)

--------------------------------------------------------------------------------
-- monetization (ids are filled in when the products are created on the Creator Hub)
--------------------------------------------------------------------------------
Config.Passes = {
	DoubleMoney = { Id = 0, Name = "2X MONEY" },
	MoreIncubators = { Id = 0, Name = "+2 INCUBATORS" },
	VipRack = { Id = 0, Name = "VIP EGG RACK" },
	AutoCollect = { Id = 0, Name = "AUTO COLLECT" },
}
-- Developer products (2026-10-14 shop). Id 0 = not created on Roblox yet (the shop shows SOON); create each one in the
-- Creator Hub with this Price, paste its id here. The live price shown in the shop comes from Roblox (GetProductInfo).
Config.Products = {
	-- starter pack ladder: one of each per player (Flags.Packs)
	StarterPack1 = { Id = 0, Name = "EXPLORER PACK", Price = 49, OneTime = true },
	StarterPack2 = { Id = 0, Name = "RANGER PACK", Price = 199, OneTime = true },
	StarterPack3 = { Id = 0, Name = "TITAN PACK", Price = 499, OneTime = true },
	-- eggs (straight to your bag; odds in Config.EggOdds, shown before buying)
	PremiumEgg = { Id = 0, Name = "PREMIUM EGG", Price = 49 },
	PremiumEgg3 = { Id = 0, Name = "3 PREMIUM EGGS", Price = 129 },
	PremiumEgg10 = { Id = 0, Name = "10 PREMIUM EGGS", Price = 399 },
	RareEgg = { Id = 0, Name = "RARE+ EGG", Price = 99 },
	EpicEgg = { Id = 0, Name = "EPIC+ EGG", Price = 249 },
	LegendaryEgg = { Id = 0, Name = "LEGENDARY EGG", Price = 599 },
	-- boosts
	LuckBoost = { Id = 0, Name = "LUCK BOOST - 15 MIN", Price = 49 },
	LuckBoost60 = { Id = 0, Name = "LUCK BOOST - 1 HOUR", Price = 149 },
	InstantHatch = { Id = 0, Name = "INSTANT HATCH", Price = 25 },
	InstantHatch5 = { Id = 0, Name = "5 INSTANT HATCHES", Price = 99 },
	CompanionSlot = { Id = 0, Name = "+1 COMPANION SLOT", Price = 149 }, -- (also in the companion tablet)
}
-- what each product gives: { Kind = "Egg", Egg = <Config.ShopEggs key>, Count } | { Kind = "Coins", Amount } |
-- { Kind = "Luck", Minutes } | { Kind = "Hatch", Count } | { Kind = "Slot" }
Config.ProductGrants = {
	StarterPack1 = { { Kind = "Egg", Egg = "Rare", Count = 1 }, { Kind = "Coins", Amount = 5000 }, { Kind = "Luck", Minutes = 15 } },
	StarterPack2 = { { Kind = "Egg", Egg = "Epic", Count = 1 }, { Kind = "Egg", Egg = "Premium", Count = 3 }, { Kind = "Coins", Amount = 25000 }, { Kind = "Hatch", Count = 2 } },
	StarterPack3 = { { Kind = "Egg", Egg = "Legendary", Count = 1 }, { Kind = "Egg", Egg = "Premium", Count = 5 }, { Kind = "Coins", Amount = 100000 }, { Kind = "Slot" } },
	PremiumEgg = { { Kind = "Egg", Egg = "Premium", Count = 1 } },
	PremiumEgg3 = { { Kind = "Egg", Egg = "Premium", Count = 3 } },
	PremiumEgg10 = { { Kind = "Egg", Egg = "Premium", Count = 10 } },
	RareEgg = { { Kind = "Egg", Egg = "Rare", Count = 1 } },
	EpicEgg = { { Kind = "Egg", Egg = "Epic", Count = 1 } },
	LegendaryEgg = { { Kind = "Egg", Egg = "Legendary", Count = 1 } },
	LuckBoost = { { Kind = "Luck", Minutes = 15 } },
	LuckBoost60 = { { Kind = "Luck", Minutes = 60 } },
	InstantHatch = { { Kind = "Hatch", Count = 1 } },
	InstantHatch5 = { { Kind = "Hatch", Count = 5 } },
	CompanionSlot = { { Kind = "Slot" } },
}
-- shop eggs: a rarity floor + a fixed luck, so the odds are exact and the same for everyone (boosts don't touch them)
Config.ShopEggs = {
	Premium = { Name = "PREMIUM EGG", Floor = 1, Luck = 3, Price = "PremiumEgg" },
	Rare = { Name = "RARE+ EGG", Floor = 3, Luck = 3, Price = "RareEgg" },
	Epic = { Name = "EPIC+ EGG", Floor = 4, Luck = 3, Price = "EpicEgg" },
	Legendary = { Name = "LEGENDARY EGG", Floor = 5, Luck = 3, Price = "LegendaryEgg" },
}
-- exact rarity odds of a shop egg: { { Rarity, Pct } } in rarity order, percentages to 2 places summing to exactly 100
-- (Roblox's paid-random-items rule; the server rolls from the same weights: Config.ShopEggRoll)
function Config.EggOdds(kind: string): { { any } }
	local def = Config.ShopEggs[kind] or Config.ShopEggs.Premium
	local w = Config.RarityWeights(def.Luck)
	local sum = 0
	for _, r in ipairs(Config.RarityOrder) do if Config.Rarity[r].Order >= def.Floor then sum += w[r] end end
	local out, total, big = {}, 0, 1
	for _, r in ipairs(Config.RarityOrder) do
		if Config.Rarity[r].Order >= def.Floor then
			local pct = math.floor(w[r] / sum * 10000 + 0.5) / 100
			table.insert(out, { r, pct })
			total += pct
			if pct > out[big][2] then big = #out end
		end
	end
	out[big][2] = math.floor((out[big][2] + (100 - total)) * 100 + 0.5) / 100 -- (rounding remainder on the biggest)
	return out
end
-- roll a shop egg's rarity from those exact odds (r: a number in [0, 1))
function Config.ShopEggRoll(kind: string, r: number): string
	local acc = 0
	local odds = Config.EggOdds(kind)
	for _, o in ipairs(odds) do
		acc += o[2] / 100
		if r < acc then return o[1] end
	end
	return odds[#odds][1]
end
-- the species a shop egg can be: every non-boss dino of the eras you've unlocked (equal chance each)
function Config.ShopEggSpecies(unlocked): { string }
	local out = {}
	for _, sp in ipairs(Config.SpeciesOrder) do
		local info = Config.Species[sp]
		if info and not info.Boss and unlocked and unlocked[info.Era] then table.insert(out, sp) end
	end
	if #out == 0 then out = { "Velociraptor" } end
	return out
end
-- what a product's contents would cost bought one by one (coins aren't sold, so they count as 0): the honest
-- "X VALUE" on a pack
function Config.ProductValue(id: string): number
	local each = { Premium = 49, Rare = 99, Epic = 249, Legendary = 599 }
	local v = 0
	for _, g in ipairs(Config.ProductGrants[id] or {}) do
		if g.Kind == "Egg" then v += (each[g.Egg] or 49) * (g.Count or 1)
		elseif g.Kind == "Luck" then local m = g.Minutes or 15 v += m >= 60 and math.floor(149 * m / 60) or 49 * math.ceil(m / 15)
		elseif g.Kind == "Hatch" then v += 25 * (g.Count or 1)
		elseif g.Kind == "Slot" then v += 149 end
	end
	return v
end

--------------------------------------------------------------------------------
function Config.FormatNumber(n: number): string
	n = math.floor(n + 0.5)
	if n >= 1e12 then return string.format("%.1fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return out
end

function Config.FormatTime(sec: number): string
	sec = math.max(0, math.ceil(sec))
	if sec >= 3600 then return string.format("%dh %02dm", sec // 3600, (sec % 3600) // 60) end
	if sec >= 60 then return string.format("%d:%02d", sec // 60, sec % 60) end
	return string.format("%ds", sec)
end

function Config.FormatKG(kg: number): string
	return Config.FormatNumber(kg) .. " KG"
end

return Config
