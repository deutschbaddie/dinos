--[[
	Expedition — one run per player, start to finish:

	  Time Gate → Warping → Map (establishing shots, then the era map: pick a live or idle site)
	  → Travel (cinematic ride; the rover is parked at the site) → Site (on foot: Encounter.luau)
	  → Driving (the escape chase: autopilot to the return portal, you're the gunner) → Extract / Wreck → home

	The chase is per player: your rover rides the route from the site to the portal while your pursuers
	(Chase.luau) hunt it. Eggs you grabbed ride in the roof rack; big hits can knock one off.
	The owning client drives (it owns its rover's physics) and reports (s, x, speed) at 15 Hz; the server
	validates every report and is the authority for pickups, hits, darts, eggs and HP.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.DinoExpedition.Game
local Config = require(Shared.Config)
local RouteMath = require(Shared.RouteMath)
local Rides = require(Shared.Rides)
local Chase = require(script.Parent.Chase)
local RunsFolder = ReplicatedStorage.DinoExpedition.Runtime.Runs

local Expedition = {}
local Analytics = require(script.Parent.Analytics)
local runs = {} :: { [Player]: any }
local Data, Net, Vehicles, Plots, Dinos, Quests, Encounter, Bosses
local rng = Random.new()
local X = Config.Expedition

local OBSTACLES = { Log = true, Branch = true, Boulder = true, Pillar = true }
local PICKUPS = { Boost = true, Repair = true, Coin = true, Darts = true }

-- your crew: the buddies riding along in your rover (everyone's client seats them; fallen ones lie in the back)
local function publishCrew(run)
	local profile = Data.Peek(run.Player)
	-- the crew that set out (run.Crew, taken the first time): BuddyList leaves hurt dinos out, so a buddy that bled out
	-- mid-run used to vanish from the rover instead of lying in the back (Fallen)
	if not run.Crew then
		run.Crew = {}
		for _, d in ipairs(profile and Dinos.BuddyList(profile) or {}) do table.insert(run.Crew, d) end
	end
	local list = {}
	for _, d in ipairs(run.Crew) do
		table.insert(list, { Id = d.Id, Species = d.Species, Rarity = d.Rarity, KG = d.KG, Fallen = run.Fallen[d.Id] ~= nil or nil })
	end
	run.Player:SetAttribute("Crew", #list > 0 and HttpService:JSONEncode(list) or nil)
end
Expedition.PublishCrew = publishCrew

--------------------------------------------------------------------------------
-- riders (Carpool, 2026-10-13): players sat in the driver's rover when the run began come along. They step out and
-- fight at every site with the driver, get their eggs straight to their own bag (Encounter), ride the chases in their
-- seats, and come home with the rover - or are sent home on foot if the rover's lost (topple, faint, the driver left).
--------------------------------------------------------------------------------
local Carpool = require(script.Parent.Carpool)
local riderOf = {} :: { [Player]: any }
function Expedition.RiderRun(plr: Player)
	local run = riderOf[plr]
	if run and runs[run.Player] == run then return run end
	riderOf[plr] = nil
	return nil
end
-- on a run of your own, or riding along in someone else's
function Expedition.InRun(plr: Player): boolean
	return runs[plr] ~= nil or Expedition.RiderRun(plr) ~= nil
end
-- a rider back into their seat (the driver's leaving the site / the map / setting off)
function Expedition.Reseat(plr: Player)
	if not Expedition.RiderRun(plr) then return end
	-- (Bosses.Leave first: it only gives up a boss share for a den you're really standing in - 2026-10-14)
	if Bosses then Bosses.Leave(plr) end
	Encounter.Leave(plr)
	plr:SetAttribute("Holding", nil)
	Dinos.ClearHeld(plr)
	Carpool.SitBack(plr)
end
local function reseatRiders(run)
	for plr in pairs(run.Riders or {}) do
		if riderOf[plr] == run then Expedition.Reseat(plr) end
	end
end
-- the rover's lost (or the run ended somewhere it can't bring them): home on foot, to their own island
local function sendRidersHome(run)
	for plr in pairs(run.Riders or {}) do
		if riderOf[plr] == run then
			riderOf[plr] = nil
			plr:SetAttribute("RidingWith", nil)
			if Bosses then Bosses.Leave(plr) end
			Encounter.Leave(plr)
			plr:SetAttribute("Holding", nil)
			Dinos.ClearHeld(plr)
			local cf = Plots.SpawnCFrame(plr)
			Carpool.Release(plr, cf and (cf + Vector3.new(0, 2.5, 0)) or nil)
			Net.Fire(plr, "RideReturn", { OnFoot = true, Arrival = cf })
		end
	end
	run.Riders = {}
end
-- a rider knocked out of the fight (back in their seat) who'd rather go home than watch: home on foot, alone
function Expedition.RiderLeave(plr: Player)
	local run = Expedition.RiderRun(plr)
	if not run then return { Ok = false } end
	if Encounter.SiteOf(plr) then return { Ok = false, Err = "YOU'RE STILL IN THE FIGHT" } end
	riderOf[plr] = nil
	if run.Riders then run.Riders[plr] = nil end
	plr:SetAttribute("RidingWith", nil)
	plr:SetAttribute("Holding", nil)
	Dinos.ClearHeld(plr)
	local cf = Plots.SpawnCFrame(plr)
	Carpool.Release(plr, cf and (cf + Vector3.new(0, 2.5, 0)) or nil)
	Net.Fire(plr, "RideReturn", { OnFoot = true, Arrival = cf })
	return { Ok = true }
end
-- a rider whose character died (reset, the void) respawns at home: they're off the ride for good (2026-10-14: they
-- stayed "riding", and the driver's next stop pulled the fresh character out of camp and into the fight)
local function riderRespawned(plr: Player)
	local run = Expedition.RiderRun(plr)
	if not run or runs[plr] then return end
	riderOf[plr] = nil
	if run.Riders then run.Riders[plr] = nil end
	plr:SetAttribute("RidingWith", nil)
	if Bosses then Bosses.Leave(plr) end
	Encounter.Leave(plr)
	plr:SetAttribute("Holding", nil)
	Dinos.ClearHeld(plr)
	-- (with somewhere to stand: a bare Release stands you up beside the rover's seat - out in the era - 2026-10-14)
	local cf = Plots.SpawnCFrame(plr)
	Carpool.Release(plr, cf and (cf + Vector3.new(0, 2.5, 0)) or nil)
	Net.Fire(plr, "RideReturn", { OnFoot = true, Arrival = cf })
end

-- the rover's going home with them in it
local function ridersComeHome(run, cf: CFrame)
	run.CameHome = true
	for plr in pairs(run.Riders or {}) do
		if riderOf[plr] == run then
			Expedition.Reseat(plr)
			Net.Fire(plr, "RideReturn", { OnFoot = false, Arrival = cf })
		end
	end
end
-- the run is over: let go of its riders (anyone not sat in the rover goes home on foot)
local function settleRiders(run)
	for plr in pairs(run.Riders or {}) do
		if riderOf[plr] == run and run.CameHome then
			-- (only a rover that drove home brings them: a driver who left the game, or a run that ended in the era,
			-- sends everyone home on foot below)
			local seated = false
			local v = Vehicles.Get(run.Player)
			for _, p in ipairs(v and Carpool.Passengers(v) or {}) do if p == plr then seated = true end end
			if seated then
				riderOf[plr] = nil
				plr:SetAttribute("RidingWith", nil)
			end
		end
	end
	sendRidersHome(run)
end

function Expedition.Get(player: Player)
	return runs[player]
end

local function zoneModel(zone: string): Model?
	return Workspace:FindFirstChild(zone) :: Model?
end

function Expedition.RackCapacity(player: Player): number
	local profile = Data.Peek(player)
	if not profile then return Config.Rack.Base end
	return math.min(Config.Rack.Max + 2, Config.Rack.Base + (profile.Gear.Rack or 0) + (player:GetAttribute("Pass_VipRack") and 2 or 0))
end

function Expedition.CarriedCount(player: Player): number
	local run = runs[player]
	return run and #run.Eggs or 0
end

-- eggs on the rack that came from the site you're at (not the ones you rode in with from an earlier nest)
function Expedition.TakenHere(player: Player): number
	local run = runs[player]
	return run and math.max(0, #run.Eggs - (run.JoinEggs or 0)) or 0
end

local function publish(run)
	local f = run.Folder
	f:SetAttribute("HP", math.max(0, math.floor(run.HP + 0.5)))
	f:SetAttribute("MaxHP", run.MaxHP)
	f:SetAttribute("Slots", Expedition.RackCapacity(run.Player))
	f:SetAttribute("Eggs", HttpService:JSONEncode(run.Eggs))
	f:SetAttribute("Phase", run.Phase)
	f:SetAttribute("Variant", run.Variant)
	f:SetAttribute("Coins", run.Coins)
	f:SetAttribute("Darts", run.Darts)
	f:SetAttribute("MaxDarts", run.MaxDarts)
	f:SetAttribute("Site", run.SiteKey)
	f:SetAttribute("Era", run.Zone)
end

-- an egg goes onto the roof rack (loaded by hand at a site). fromRack: one that came off this rack here, going back
-- (JoinEggs counts the rack eggs that aren't "taken here": every egg off the rack takes one away, every rack egg put
-- back gives one back - otherwise swapping your own egg for a nest egg left the count untouched, MAP / GO HOME let
-- you leave with no chase, and your own egg went back on the rack as you left: a free egg)
function Expedition.LoadEgg(player: Player, egg, fromRack: boolean?)
	local run = runs[player]
	if not run then return end
	table.insert(run.Eggs, egg)
	if fromRack then run.JoinEggs = (run.JoinEggs or 0) + 1 end
	publish(run)
end

-- mid-run, at a nest: take egg i off your rack (and, hands full, the egg you're carrying goes into its slot - a
-- swap). Returns the egg that came off, or nil
function Expedition.SwapRackEgg(player: Player, index: number, put: any?): any?
	local run = runs[player]
	if not run or run.Phase ~= "Site" then return nil end
	local old = run.Eggs[index]
	if not old then return nil end
	if put then
		run.Eggs[index] = { Species = put.Species, Rarity = put.Rarity, KG = put.KG }
	else
		table.remove(run.Eggs, index)
	end
	-- (one off the rack; a rack egg swapped back into its slot evens it out - see LoadEgg)
	if not (put and put.FromRack) then run.JoinEggs = math.max(0, (run.JoinEggs or 0) - 1) end
	publish(run)
	return old
end

function Expedition.AddRunCoins(player: Player, n: number)
	local run = runs[player]
	if run then run.Coins += n publish(run) end
end

local function rootCFrameOnRoad(run, s: number, x: number): CFrame
	local rh = 2.6
	local v = Vehicles.Get(run.Player)
	if v then rh = v:GetAttribute("RootHeight") or rh end
	return run.Route:Frame(run.Variant, s, x) * CFrame.new(0, rh, 0)
end

-- how far down the era road the rover comes out of the arrival portal (clear of the membrane behind it)
local ARRIVE_S = 30

local function hubArrivalCFrame(player: Player): CFrame
	local camp = Workspace:FindFirstChild("BaseCamp")
	local m = camp and camp:FindFirstChild("GateArrival", true) :: BasePart?
	local v = Vehicles.Get(player)
	local rh = v and v:GetAttribute("RootHeight") or 2.6
	if m then
		-- come out well clear of the gate: any closer and the follow camera sits inside the glowing membrane
		local trig = camp and camp:FindFirstChild("GateTrigger", true) :: BasePart?
		local away = trig and (m.Position - trig.Position) * Vector3.new(1, 0, 1)
		local push = (away and away.Magnitude > 0.1) and away.Unit * 26 or Vector3.zero
		local p = Vector3.new(m.Position.X, m.Position.Y - m.Size.Y / 2 + 0.1 + rh, m.Position.Z) + push
		return CFrame.new(p) * m.CFrame.Rotation
	end
	return CFrame.new(600, 10, -150)
end

-- the body's stats after your build (armour plates, tyres, wings...)
local function rideStats(profile)
	return Rides.Stats(profile.Gear.Vehicle, Rides.StyleFor(profile, profile.Gear.Vehicle))
end

local function roverHP(profile): number
	local v = rideStats(profile)
	return math.floor(v.HP * (1 + Config.LevelBonus * ((profile.Gear.RoverLvl or 1) - 1)) * (profile.Gear.Plating and Config.Plating.HPMult or 1))
end

--------------------------------------------------------------------------------
-- damage, eggs
--------------------------------------------------------------------------------
-- a boss's egg is strapped down: it never falls off and never cracks (2026-10-12: about 1 in 4 new players lost
-- their first boss egg - the guaranteed EPIC - on the drive home)
local function isBossEgg(e): boolean
	local sp = e and Config.Species[e.Species]
	return sp ~= nil and sp.Boss == true
end
-- which egg you keep when you can only keep one: a boss egg first, then the rarest
local function eggKeepOrder(a, b): boolean
	if isBossEgg(a) ~= isBossEgg(b) then return isBossEgg(a) end
	return (Config.Rarity[a.Rarity] and Config.Rarity[a.Rarity].Order or 1) > (Config.Rarity[b.Rarity] and Config.Rarity[b.Rarity].Order or 1)
end
-- your island's WORKSHOP / HANGAR strap the rack down better (Config.Island.Garage[].EggSafe)
local function eggSafe(run): number
	return Config.GarageTier(run.Player and Data.Peek(run.Player)).EggSafe or 1
end
local function loseEgg(run): any
	local pool = {}
	for i, e in ipairs(run.Eggs) do if not isBossEgg(e) then table.insert(pool, i) end end
	if #pool == 0 then return nil end
	return table.remove(run.Eggs, pool[rng:NextInteger(1, #pool)])
end

local function damage(run, amount: number, kind: string, side: number?, canDrop: boolean)
	if run.Phase == "OnFoot" then
		-- running for the portal with an egg in your arms: three bites and you black out
		if os.clock() < run.Invuln then return end
		run.Invuln = os.clock() + 0.8
		if run.Mount then
			-- riding your companion: it takes the bites; worn out, it lies down and you run the rest with your best egg
			local m = run.Mount
			m.HP -= X.Damage.OnFoot * (run.FootMult or 1)
			Net.Fire(run.Player, "FootHit", { HP = math.max(0, m.HP), Max = m.MaxHP, Side = side or 0, Mount = true })
			if m.HP <= 0 then
				run.Mount = nil
				run.Player:SetAttribute("Mount", nil)
				Expedition.BuddyFell(run.Player, m.Dino)
				table.sort(run.Eggs, eggKeepOrder) -- (a boss egg always comes first: it never stays behind)
				run.Eggs = { run.Eggs[1] }
				if run.Eggs[1] then
					run.Player:SetAttribute("Holding", run.Eggs[1].Species)
					Dinos.ShowHeld(run.Player, run.Eggs[1])
				end
				run.FootHP = X.FootHP
				Net.Fire(run.Player, "MountDown", { HP = run.FootHP, Max = X.FootHP })
			end
			return
		end
		run.FootHP = math.max(0, (run.FootHP or X.FootHP) - X.Damage.OnFoot * (run.FootMult or 1))
		Net.Fire(run.Player, "FootHit", { HP = run.FootHP, Max = X.FootHP, Side = side or 0,
			Bites = math.ceil(run.FootHP / math.max(1, X.Damage.OnFoot * (run.FootMult or 1)) - 0.001) })
		if run.FootHP <= 0 then task.spawn(Expedition.Faint, run.Player) end
		return
	end
	if run.Phase ~= "Driving" then return end
	if os.clock() < run.Invuln then return end
	run.Invuln = os.clock() + 0.6
	run.HP = math.max(0, run.HP - amount)
	local lost = nil
	if canDrop and rng:NextNumber() < X.EggDropChance * eggSafe(run) then
		local droppable = false
		for _, e in ipairs(run.Eggs) do if not isBossEgg(e) then droppable = true break end end
		if not droppable then
			-- (only boss eggs on the rack: they never fall, nothing to catch)
		elseif run.EggGuard and not run.EggGuardUsed then
			-- your Egg Guard lunges and catches it before it hits the road (once a run)
			run.EggGuardUsed = true
			Net.Fire(run.Player, "EggCaught", { Species = run.EggGuard, Side = side or 0 })
		else
			lost = loseEgg(run)
		end
	end
	Net.Fire(run.Player, "Hit", { Kind = kind, Damage = amount, Side = side or 0, Lost = lost and lost.Species, LostRarity = lost and lost.Rarity, HP = run.HP })
	publish(run)
	if run.HP <= 0 then Expedition.Topple(run) end
end

--------------------------------------------------------------------------------
-- lifecycle
--------------------------------------------------------------------------------
-- opts: { Site = "Era/SiteId" } to ride straight to a site (a boss event joined from camp); Quiet = the caller shows
-- the refusal itself (the Time Gate: a toast under the gate's white-out was never seen - 2026-10-14)
-- returns { Ok, Err }: every refusal says why (it used to return nothing, and the gate sat there in white)
function Expedition.Begin(player: Player, zone: string, opts): { Ok: boolean, Err: string? }
	opts = opts or {}
	local function no(err: string)
		if not opts.Quiet then Net.Fire(player, "Toast", { Text = err, Color = "Red" }) end
		return { Ok = false, Err = err }
	end
	if runs[player] then return { Ok = false, Err = "ALREADY ON AN EXPEDITION" } end
	-- (riding along in someone else's rover - on their run, or just sat in it at camp: JOIN from a seat started a run of
	-- your own while you still counted as their rider. Refused: hop out first. 2026-10-14)
	if Expedition.RiderRun(player) or Carpool.IsPassenger(player) then return no("YOU'RE RIDING WITH A FRIEND - HOP OUT FIRST") end
	local profile = Data.Peek(player)
	if not profile then return no("STILL LOADING - TRY AGAIN") end
	if not profile.Unlocked[zone] then return no("THAT ERA IS LOCKED") end
	-- (checked before anything changes hands: a refusal here used to come after the rack had been emptied)
	local route = RouteMath.get(zone)
	if not route or not zoneModel(zone) then return no("THAT ERA ISN'T OPEN YET") end
	-- (a rover parked back at camp doesn't come along on its own: a fresh one takes its place at the gate)
	local vehicle = (not Vehicles.CampParked[player] and Vehicles.Get(player)) or Vehicles.Spawn(player, hubArrivalCFrame(player))
	if not vehicle then return no("NO ROVER - CALL ONE FIRST") end
	-- whatever's still on the rack from last time goes to your bag: the rack is for this run's eggs
	Vehicles.RackToBag(player)
	if runs[player] then return { Ok = false, Err = "ALREADY ON AN EXPEDITION" } end -- (in case unloading yielded)
	-- whoever's riding along comes too (unless they're on a run of their own)
	local riders = {}
	for _, plr in ipairs(Carpool.Passengers(vehicle)) do
		if runs[plr] or riderOf[plr] then Carpool.Release(plr) else table.insert(riders, plr) end
	end
	local stats = rideStats(profile)
	local folder = Instance.new("Configuration")
	folder.Name = tostring(player.UserId)
	folder:SetAttribute("Zone", zone)
	folder.Parent = RunsFolder
	local hp = roverHP(profile)
	local run = {
		Player = player, Zone = zone, Route = route, Variant = 1,
		S = ARRIVE_S, X = 0, V = 0, Boosting = false, Boost = 1, LastReport = os.clock(),
		HP = hp, MaxHP = hp, Stats = stats,
		Eggs = {}, Handled = {}, Chasers = {}, Packs = {},
		Coins = 0, Phase = "Warping", Started = os.clock(), Invuln = 0, Folder = folder,
		Darts = stats.Darts or 8, MaxDarts = stats.Darts or 8, NextDart = 0, DartRegenAt = 0,
		Pending = opts.Site,
		Fallen = {}, -- buddy dino id -> dino: knocked out for good this run (lost if you faint too)
		Riders = {}, -- players riding along (Carpool): Player -> true
	}
	local arrival = rootCFrameOnRoad(run, ARRIVE_S, 0)
	runs[player] = run
	-- (2026-10-14: a throw from here on, before the warp went out, left runs[player] set - no warp, and every later
	-- drive into the gate was skipped as "already on a run" until you rejoined. Guarded: the run is let go of again)
	local ok, err = pcall(function()
		for _, plr in ipairs(riders) do
			run.Riders[plr] = true
			riderOf[plr] = run
			plr:SetAttribute("RidingWith", player.UserId)
		end
		publishCrew(run)
		Vehicles.Locked[player] = true
		publish(run)
		local firstTime = not profile.Flags.SeenWarp
		profile.Flags.SeenWarp = true
		Net.Fire(player, "Warp", {
			Zone = zone, Arrival = arrival, S = ARRIVE_S, Full = firstTime, Name = route.Data.Name, Era = route.Data.Era,
			MaxHP = run.MaxHP, Cruise = stats.Cruise, BoostSpeed = stats.Boost, Grip = stats.Grip, Site = opts.Site,
		})
		run.WarpSent = true
		-- (riders' clients play the warp too: EraView follows the driver's run from here)
		for plr in pairs(run.Riders) do
			Net.Fire(plr, "RideWarp", { Driver = player.UserId, Zone = zone, Arrival = arrival, Name = route.Data.Name, Era = route.Data.Era, Full = false })
		end
	end)
	if not ok then
		warn("[Expedition] begin:", err)
		if not run.WarpSent then
			if runs[player] == run then Expedition.Finish(run) end
			return no("THE GATE SPUTTERED - TRY AGAIN")
		end
	end
	-- safety net: if the client hasn't brought the rover through within a few seconds, do it here
	task.delay(7, function()
		if runs[player] ~= run or run.Phase ~= "Warping" then return end
		Vehicles.Teleport(player, arrival)
		Expedition.Arrived(player)
	end)
	Analytics.Onboard(player, "FirstTrip")
	Analytics.RunStep(player, run, "Start")
	return { Ok = true }
end

-- the warp finished: you're at the arrival portal; the client shows the establishing shots + the era map
function Expedition.Arrived(player: Player)
	local run = runs[player]
	if not run or run.Phase ~= "Warping" then return { Ok = false } end
	run.Phase = "Map" -- (free roam: "Map" is you out exploring the era, at the wheel or on foot)
	Vehicles.Locked[player] = nil -- (hop out anywhere: Vehicles.Roaming holds the rover where you left it)
	publish(run)
	Analytics.Onboard(player, "ArrivedInEra")
	Analytics.RunStep(player, run, "Arrived")
	return { Ok = true, Site = run.Pending }
end

-- your own place in a site's parking line (Encounter.ParkSlot: place 0 is its park spot, then side by side, then back
-- down the road): two hunters at one nest used to get one spot and their rovers parked inside each other. A place is
-- someone else's while they're on their way to the site or at it with it booked, or while any rover stands on it.
-- keep: the place booked when the trip was picked (the client drove to it: TravelDone parks on the same one). 2026-10-14
local slotBook = {} :: { [string]: { [Player]: number } }
local function siteSlot(player: Player, site, keep: boolean?): (CFrame, number, number)
	local book = slotBook[site.Key]
	if not book then book = {} slotBook[site.Key] = book end
	local mine = book[player]
	if keep and mine then return Encounter.ParkSlot(site, mine) end
	local used = {}
	for plr, k in pairs(book) do
		local r = runs[plr]
		if plr ~= player and plr.Parent and r and r.SiteKey == site.Key and (r.Phase == "Travel" or r.Phase == "Site") then used[k] = true end
	end
	local rovers = {}
	for plr in pairs(runs) do
		local root = plr ~= player and Vehicles.Root(plr)
		if root then table.insert(rovers, root.Position) end
	end
	local function free(k: number): boolean
		if used[k] then return false end
		local p = (Encounter.ParkSlot(site, k)).Position
		for _, o in ipairs(rovers) do if (o - p).Magnitude < 10 then return false end end
		return true
	end
	local k = (mine and free(mine)) and mine or nil
	if not k then
		k = 0
		while k < 7 and not free(k) do k += 1 end
	end
	book[player] = k
	for plr in pairs(book) do if not plr.Parent then book[plr] = nil end end
	return Encounter.ParkSlot(site, k)
end

-- pick a site on the era map: the client plays the travel cutscene, then calls TravelDone
function Expedition.ChooseSite(player: Player, key: string)
	local run = runs[player]
	if not run or run.Phase ~= "Map" then return { Ok = false } end
	local site = Encounter.SiteByKey(key) or (Bosses and Bosses.SiteByKey(key))
	if not site or site.Era ~= run.Zone then return { Ok = false, Err = "UNKNOWN SITE" } end
	-- (a WILD dino has no pin: it's found by exploring, never driven to - its key is guessable)
	if site.Def and site.Def.Wild then return { Ok = false, Err = "UNKNOWN SITE" } end
	if site.Boss then
		local ok, err = Bosses.CanJoin(player, site)
		if not ok then return { Ok = false, Err = err } end
	elseif site.State == "Chase" then
		return { Ok = false, Err = "THAT SITE IS EMPTY RIGHT NOW - TRY ANOTHER" }
	end
	-- (on foot in free roam: back into the rover first - the autopilot drives you there)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.SeatPart) then Vehicles.GetIn(player) end
	Vehicles.Locked[player] = true
	run.Phase = "Travel"
	run.SiteKey = key
	run.Variant = site.Variant
	publish(run)
	local park, parkS, parkX = siteSlot(player, site) -- (your own place: the client's drive stops on it)
	return { Ok = true, Site = key, Name = site.Def.Name, Species = site.Def.Species, Park = park, S = parkS, X = parkX, Variant = site.Variant, Center = site.Center }
end

-- in at a site: out of the rover (held where it stands), the fight joined, riders hop out beside you
local function joinSite(player: Player, run, site)
	-- (in free roam you may walk in: only a seated driver steps out - GetOut would pull you back beside the rover)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local drove = hum ~= nil and hum.SeatPart ~= nil
	-- (rolled in from free roam: you were driving it a moment ago - it settles before it's held, no jump back)
	if drove then Vehicles.GetOut(player, site.Center, true, run.Phase == "Map") end
	run.Phase = "Site"
	run.SiteKey = site.Key
	run.Variant = site.Variant or run.Variant
	run.Visited = true
	run.NoRejoin = nil
	run.JoinEggs = #run.Eggs -- (what was already on the rack - a boss's prize - doesn't count as taken from here)
	publish(run)
	if site.Boss then Bosses.Join(player, site) else Encounter.Join(player, site) end
	-- riders hop out beside the driver and join the fight too
	local k = 0
	for plr in pairs(run.Riders) do
		if riderOf[plr] == run then
			k += 1
			-- (beside the rover you drove in with; walked in, beside you - the rover may be parked far off)
			-- (a checked spot by the rover, never inside a wall: each rider the next free one along)
			local v = Vehicles.Get(player)
			local at
			if drove and v and v.PrimaryPart then
				at = Vehicles.SafeStand(v, site.Center, nil, k + 1)
			else
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local base = hrp and hrp.CFrame or CFrame.new(site.Center)
				at = base * CFrame.new((k % 2 == 1 and -1 or 1) * (4 + math.floor((k - 1) / 2) * 3), 0, 3)
			end
			Carpool.StepOut(plr, at)
			task.delay(0.2, function()
				if riderOf[plr] ~= run or run.Phase ~= "Site" then return end
				if site.Boss then Bosses.Join(plr, site) else Encounter.Join(plr, site) end
			end)
		end
	end
end

-- joinSite, but a throw part-way (a site's residents, its buddies...) puts you back out exploring instead of leaving
-- the server in "Site" with no fight while your screen roams (nothing would ever join or take you home again)
local function safeJoin(player: Player, run, site): boolean
	local ok, err = pcall(joinSite, player, run, site)
	if ok then return true end
	warn("[Expedition] join failed:", site.Key, err)
	pcall(function()
		if Bosses then Bosses.Leave(player) end
		Encounter.Leave(player)
	end)
	run.Phase = "Map"
	run.SiteKey = nil
	run.NoRejoin = site.Key
	Vehicles.Locked[player] = nil
	publish(run)
	return false
end

function Expedition.TravelDone(player: Player)
	local run = runs[player]
	if not run or run.Phase ~= "Travel" or run.Parking then return { Ok = false } end
	local site = Encounter.SiteByKey(run.SiteKey) or (Bosses and Bosses.SiteByKey(run.SiteKey))
	if not site then run.Phase = "Map" Vehicles.Locked[player] = nil publish(run) return { Ok = false } end
	if site.Boss then
		-- the fight may have ended (or moved on) during the travel cutscene
		local ok, err = Bosses.CanJoin(player, site)
		if not ok then
			run.Phase = "Map"
			run.SiteKey = nil
			Vehicles.Locked[player] = nil
			publish(run)
			return { Ok = false, Err = err }
		end
	end
	local park = siteSlot(player, site, true) -- (the place ChooseSite gave the client)
	local v = Vehicles.Get(player)
	local rh = v and v:GetAttribute("RootHeight") or 2.6
	-- (one arrival per trip: the travel scene's own call and the client's stall-heal used to both get through the
	-- 0.25 s wait below and join the fight twice)
	run.Parking = true
	Vehicles.Teleport(player, park * CFrame.new(0, rh, 0))
	task.wait(0.25)
	run.Parking = nil
	if runs[player] ~= run or run.Phase ~= "Travel" then return { Ok = false } end -- (aborted while parking: never join a fight with no run)
	if site.Boss and site.Phase == 2 then
		-- she's already on the run: you stay in the rover and join the chase
		run.Visited = true
		Bosses.Join(player, site)
		return { Ok = true, Chase = true }
	end
	if not safeJoin(player, run, site) then return { Ok = false, Err = "COULDN'T REACH THE SITE" } end
	-- (held exactly on its park spot - the checked one, on the road and on the ground: if the client's drive left its
	-- copy somewhere else, that's where the get-out had anchored it. 2026-10-14, "the car gets put in the floor")
	task.delay(0.3, function()
		if runs[player] ~= run or (run :: any).Phase ~= "Site" or run.SiteKey ~= site.Key then return end -- (any: the join set it)
		local root = Vehicles.Root(player)
		local want = park * CFrame.new(0, rh, 0)
		-- (always: HoldAt also sets its wheels down exactly on the road - Vehicles.Settle)
		if root then Vehicles.HoldAt(player, want) end
	end)
	return { Ok = true }
end

-- leave a site (or the map) and go back to choosing
-- (lying downed at a site you can't walk away to the map or home: leaving used to wipe the downed state and
-- rejoining gave full health - and in a boss fight a fresh revive for the pool)
local function downedAtSite(player: Player): boolean
	local site = Encounter.SiteOf(player)
	local st = site and site.Players[player]
	return st ~= nil and st.Downed == true
end

-- (a beaten boss isn't chasing anyone: its den says it the friendly way)
local function takenErr(player: Player): string
	local site = Encounter.SiteOf(player)
	if site and site.Boss and (site.Phase or 0) >= 4 then return "DRIVE OFF WITH YOUR EGG!" end
	return "THEY WON'T LET YOU GO - DRIVE OFF!"
end

function Expedition.BackToMap(player: Player)
	local run = runs[player]
	if not run or (run.Phase ~= "Site" and run.Phase ~= "Map") then return { Ok = false } end
	if downedAtSite(player) then return { Ok = false, Err = "YOU'RE DOWN - WAIT FOR A REVIVE" } end
	-- (eggs taken from this nest mean the chase: loading up, then MAP, then the portal skipped it - 2026-10-14)
	if run.Phase == "Site" and player:GetAttribute("Site") ~= nil and #run.Eggs > (run.JoinEggs or 0) then
		return { Ok = false, Err = takenErr(player) }
	end
	local left = run.SiteKey
	if Bosses then Bosses.Leave(player) end
	Encounter.Leave(player)
	Vehicles.GetIn(player)
	reseatRiders(run)
	run.Phase = "Map"
	run.SiteKey = nil
	-- (back at the wheel, often parked right inside the nest's reach: never straight back into it - 2026-10-14)
	run.NoRejoin = left
	run.ArriveHold = os.clock() + 1.5
	Vehicles.Locked[player] = nil -- (free roam again)
	publish(run)
	return { Ok = true }
end

--------------------------------------------------------------------------------
-- FREE ROAM (2026-10-13, user: "there should be freeroam on the maps - the graphics look good, let players explore").
-- Out of the portal you're driving the era yourself (phase "Map"), and can hop out anywhere. WALK up to a nest - or an
-- awake boss den, or a wild dino - and you're in it (the same arrival as the road's travel). Walk away from a nest with
-- nothing taken and you're exploring again. Drive into the return portal to go home. The chase with eggs still runs on
-- the road, joining it beside the rover.
-- (2026-10-14, user: "i wanted to drive to the t rex but it made me fight the velociraptor") driving never pulls you
-- into anything - only stepping in on foot does, and only stepping in from outside: wherever roaming (re)starts - the
-- arrival, MAP, walking off, a den resting after a win, getting out of the rover - a reach you're already standing in
-- doesn't take you until you've left it (or you walk right up to its middle: that's on purpose). While a boss fight is
-- on (or just won), the nests next to its den and final arena don't take you either: walking back to your rover after
-- the Tyrant King put people in the Horn Nest fight.
-- (2026-10-14, user: "getting out and then sneaking up leaves the car back behind ... the car should come a little
-- closer") walk into a fight with your rover left well back, and it pulls up at the site's park spot (the road spot
-- beside a nest, or a clear patch near a wild dino) while the scope-out plays: the rack and DRIVE OFF are right there.
--------------------------------------------------------------------------------
function Expedition.RoamOut(player: Player)
	local run = runs[player]
	if not run or run.Phase ~= "Map" then return { Ok = false } end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.SeatPart) then return { Ok = false } end
	Vehicles.GetOut(player, nil, true, true)
	return { Ok = true }
end
function Expedition.RoamIn(player: Player)
	local run = runs[player]
	if not run or run.Phase ~= "Map" then return { Ok = false } end
	local root = Vehicles.Root(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (root and hrp) or (hrp.Position - root.Position).Magnitude > 24 then return { Ok = false } end
	Vehicles.GetIn(player)
	return { Ok = true }
end

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
-- your rover pulls up: you walked into a fight with it left well back, so it comes to the site's park spot (a nest's or
-- den's road spot, a clear patch beside a wild dino) - under the scope-out, a beat after the join (your riders are out
-- of their seats by then: an occupied rover never moves). Already about as close, or closer: it stays where you left it.
local ROVER_SLACK = 15 -- (studs further out than the park spot before it bothers)
local function roverComes(run, site)
	local player = run.Player
	local root = Vehicles.Root(player)
	if not (root and site.Center) or site.Water then return end -- (a sea boss's arena: its own way of parking)
	-- (a den's final arena: Bosses lines the rovers up there itself)
	if site.Boss and (site.Phase or 0) >= 3 then return end
	-- a wild one in the open: a patch beside it clear of the other hunters' rovers; otherwise your place in the line
	local avoid = {}
	for plr in pairs(runs) do
		local r = plr ~= player and Vehicles.Root(plr)
		if r then table.insert(avoid, r.Position) end
	end
	local park = Encounter.RoamParkCFrame(site, root.Position, avoid) or (siteSlot(player, site))
	if flatDist(root.Position, site.Center) <= flatDist(park.Position, site.Center) + ROVER_SLACK then return end
	task.delay(0.4, function()
		if runs[player] ~= run or run.Phase ~= "Site" or run.SiteKey ~= site.Key then return end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart then return end
		local v = Vehicles.Get(player)
		if not v then return end
		Vehicles.HoldAt(player, park * CFrame.new(0, v:GetAttribute("RootHeight") or 2.6, 0))
	end)
end
local function reachSite(run, site)
	local player = run.Player
	if site.Boss then
		local ph = site.Phase or 0
		if ph ~= 1 and ph ~= 3 then return end -- (asleep, or on the run: the den's own flow)
		if not Bosses.CanJoin(player, site) then return end
	elseif site.State == "Chase" then
		return
	end
	local wasIdle = site.State == "Idle" or site.State == "Cooldown"
	if not safeJoin(player, run, site) then return end
	pcall(roverComes, run, site)
	Net.Fire(player, "SiteArrive", { Site = site.Key, Name = site.Def and site.Def.Name or nil, Species = site.Def and site.Def.Species or nil, Boss = site.Boss or nil, WasIdle = wasIdle })
end
-- a boss fight that's on (or just won) keeps the nests beside its den and its final arena to itself: you walk past them
-- to your rover (FV: the final arena's park spot is inside Horn Nest's reach)
local function bossNear(run, site): boolean
	if site.Boss or not site.Center then return false end
	local den = Bosses and Bosses.DenFor and Bosses.DenFor(run.Zone)
	if not den or (den.Phase or 0) < 1 then return false end
	local r = site.Radius or 44
	local dc = den.DenCenter or den.Center
	if dc and flatDist(site.Center, dc) < r + (den.Radius or 40) + 10 then return true end
	if (den.Phase or 0) >= 2 and den.FinalCenter then
		local fp = den.FinalPark and den.FinalPark.CF.Position or den.FinalCenter
		if flatDist(site.Center, fp) < r + 30 or flatDist(site.Center, den.FinalCenter) < r + 50 then return true end
	end
	return false
end
-- which reaches you're standing in that don't take you (see FREE ROAM): run.Inside[key] = the furthest you've been from
-- its middle since. Walking out of the reach clears it; walking on in from outside its core to the middle joins.
local ROAM_CORE = 20
local function roamJoins(run, pos: Vector3, seated: boolean)
	-- (roaming (re)started: nothing ticked here for a moment - another phase, a cutscene hold - so what you're
	-- standing in now was never stepped into)
	local fresh = run.Inside == nil or os.clock() - (run.InsideAt or 0) > 1
	run.InsideAt = os.clock()
	if fresh then run.Inside = {} end
	local inside = run.Inside
	local list = Encounter.Sites(run.Zone)
	local den = Bosses and Bosses.DenFor and Bosses.DenFor(run.Zone)
	if den and not table.find(list, den) then table.insert(list, den) end
	local enter = {}
	for _, site in ipairs(list) do
		if not site.Center then continue end
		local r = site.Radius or (site.Boss and 40 or 44)
		local d = flatDist(pos, site.Center)
		local was = inside[site.Key]
		if was then
			if d > r + 8 then inside[site.Key] = nil else inside[site.Key] = math.max(was, d) end
			-- (you walked on in from outside its middle, right up to it: that's on purpose - hopped out a little way
			-- from a nest and went for it, say)
			if not seated and d < ROAM_CORE and was >= ROAM_CORE and was - d >= 6 then table.insert(enter, site) end
		elseif d < r then
			-- (at the wheel, just (re)started, or a boss fight's: you're in its reach without having stepped in)
			if fresh or seated or bossNear(run, site) then inside[site.Key] = d else table.insert(enter, site) end
		end
	end
	for _, site in ipairs(enter) do
		if site.Key ~= run.NoRejoin then reachSite(run, site) end
		if run.Phase ~= "Map" then return end
		-- (it couldn't take you - a den asleep, a nest emptied by a chase: standing on in its reach never pulls you in
		-- the moment it can, you step in again)
		inside[site.Key] = math.max(inside[site.Key] or 0, flatDist(pos, site.Center))
	end
end
local function roamTick(run)
	if os.clock() < (run.RoamAt or 0) then return end
	run.RoamAt = os.clock() + 0.25
	local player = run.Player
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) or hum.Health <= 0 then return end
	local pos = hrp.Position
	if run.Phase == "Map" then
		-- (not until your game says the arrival shots are over: walking into a nest mid-intro left a black screen)
		if not run.RoamReady or os.clock() < (run.ArriveHold or 0) then return end
		-- (any cutscene on your screen holds it too: Drive reports while one plays - RoamHold. Capped, never stuck)
		if run.RoamHold and os.clock() - run.RoamHold < 90 then return end
		local seated = hum.SeatPart ~= nil
		-- (the nest you just left only takes you back once you've really been away from it: leaving with MAP puts
		-- you in your rover, often parked inside its reach, and you were straight back in - 2026-10-14)
		if run.NoRejoin then
			local s0 = Encounter.SiteByKey(run.NoRejoin) or (Bosses and Bosses.SiteByKey(run.NoRejoin))
			if not (s0 and s0.Center) or flatDist(pos, s0.Center) > (s0.Radius or 44) + 12 then run.NoRejoin = nil end
		end
		-- on foot, stepping in from outside (roamJoins); at the wheel nothing ever pulls you in
		roamJoins(run, pos, seated)
		if run.Phase ~= "Map" then return end
		-- (the way home - the return portal at the far end of the road - is portalTick's: on the membrane, every tick)
	elseif run.Phase == "Site" and run.SiteKey then
		-- walked well away from a nest with nothing taken: you're exploring again
		local site = Encounter.SiteByKey(run.SiteKey) or (Bosses and Bosses.SiteByKey(run.SiteKey))
		local st = site and site.Players[player]
		-- out of the fight without the run hearing of it (a site that failed, a den that reset round you): exploring
		-- again after a moment, never left in "Site" with nothing on (no joins, no portal, no way on - 2026-10-14)
		if not st and Encounter.SiteOf(player) == nil then
			run.Orphan = run.Orphan or os.clock()
			if os.clock() - run.Orphan < 4 then return end
		else
			run.Orphan = nil
			if not st then return end
			if site.Boss then return end
			if st.Downed or player:GetAttribute("Holding") or #run.Eggs > (run.JoinEggs or 0) then return end
			if flatDist(pos, site.Center) <= (site.Radius or 44) + 45 then return end
		end
		run.Orphan = nil
		if Bosses then Bosses.Leave(player) end
		Encounter.Leave(player)
		reseatRiders(run) -- (riders ride on with you; they step out again at the next site - joinSite)
		run.NoRejoin = run.SiteKey
		run.Phase = "Map"
		run.SiteKey = nil
		run.ArriveHold = os.clock() + 1.5
		Vehicles.Locked[player] = nil
		publish(run)
		Net.Fire(player, "SiteLeft", {})
	end
end

-- losing the pack (loseTick, below): studs of lead held for GapHold s, or nobody left hunting for OutHold s, or Cap s
-- of chase; never within NearEnd studs of the portal
local LOSE = { Gap = 75, GapHold = 2, OutHold = 1, Cap = 24, NearEnd = 90 }

-- the chase that ends every encounter. pursuer: species chasing you; opts: { Boss = {...}, StopS = number, OnStop = fn }
function Expedition.StartChase(player: Player, site, carried: { any }, pursuer: string, takedown: boolean?, opts)
	local run = runs[player]
	if not run then return end
	opts = opts or {}
	-- (a chase starts from a site, or straight off the travel; a stale timer - the 3 s after a lost boss fight - must
	-- never yank a player who already went back to the map or is already driving off)
	if run.Phase ~= "Site" and run.Phase ~= "Travel" and run.Phase ~= "Driving" then return end
	-- (a new chase replaces one still running - the fight ended under a boss chase: its pack must not stack on the
	-- new one's)
	if run.Phase == "Driving" then Chase.Clear(run) end
	Chase.DropGivenUp(run) -- (a pack you lost earlier that's still jogging off: never part of this one)
	for _, egg in ipairs(carried or {}) do table.insert(run.Eggs, egg) end
	Vehicles.GetIn(player)
	Vehicles.Locked[player] = true
	reseatRiders(run)
	run.Handled = {}
	-- (pickups are laid out once per run and the client drops each one you take: a second chase on the same road
	-- - a boss run's escort, another nest - must never pay out an invisible one again)
	run.Taken = run.Taken or {}
	run.Phase = "Driving"
	run.Variant = site.Variant
	local _, parkS, parkX = Encounter.ParkCFrame(site)
	-- FREE ROAM: the rover can be parked anywhere round the site - the chase joins the road right beside it (never
	-- further on than just past the site's own spot: no parking by the portal for a short chase)
	local nearS, nearX = nil, nil
	if not opts.S then
		local root = Vehicles.Root(player)
		if root then
			local vi = site.Variant or run.Variant
			local s, x, d = run.Route:Project(vi, root.Position)
			if d < 160 then
				local hw = run.Route:HalfWidth(vi, s) or 10
				nearS, nearX = math.min(s, parkS + 40), math.clamp(x, -hw + 3, hw - 3)
			end
		end
	end
	run.S, run.X, run.V = opts.S or nearS or parkS, opts.X or nearX or parkX, opts.Rolling or 0 -- (a boss chase starts already rolling: hot pursuit)
	run.PrevS = run.S
	run.LastReport = os.clock()
	run.StopS, run.OnStop, run.OnDart = opts.StopS, opts.OnStop, opts.OnDart
	-- LOSING THE PACK (loseTick): any nest's / wild dino's / escort's chase can be shaken off; the boss on the run
	-- (phase 2, it's out ahead and you're after IT) never - it ends at its last stand
	run.Losable = not opts.Boss and not opts.StopS
	run.ChaseSite = site.Key
	run.ChaseT, run.LoseFor = 0, 0
	-- (a full boost tank every chase, as the client's: it only refills while driving one, and a tank you ran dry
	-- shaking off the last pack had the server refusing a boost the screen showed)
	run.Boost = 1
	-- pursuers: takedowns leave fewer (the parent is out cold; its mate / the rest of the pack comes)
	-- stolen without a knockout: the whole family comes after you (a knockout leaves just one angry mate)
	local packish = site.Def and (site.Def.Kind == "Pack" or site.Def.Kind == "Swarm" or site.Def.Kind == "Rival" or site.Def.Kind == "Flyer")
	local count = takedown and 1 or (packish and 3 or 2)
	if site.Def and site.Def.Kind == "Herd" and not takedown then count = 3 end
	-- the very first escape is a lesson, not a wall: one chaser, half damage
	-- later eras hit the rover harder (their rovers are much tougher); on foot it's always three bites
	run.DamageMult, run.FootMult = Config.EraScaleOf(run.Zone).Chase, 1
	local prof = Data.Peek(player)
	if prof and (prof.Stats.Runs or 0) == 0 and not opts.Boss then
		count = 1
		run.DamageMult, run.FootMult = 0.5 * run.DamageMult, 0.5
	end
	-- (the time-out only once you've been home with eggs once: the very first escape runs all the way to the portal -
	-- it's where the lesson ends. Shaking them off by skill still counts)
	run.LoseCap = (prof and (prof.Stats.Runs or 0) > 0) and LOSE.Cap or nil
	-- your companion rides shotgun and bites latched raptors off (if it's still fit to)
	run.Helper = nil
	for _, d in ipairs(prof and Dinos.BuddyList(prof) or {}) do
		if not run.Fallen[d.Id] then
			local r = Config.Rarity[d.Rarity]
			run.Helper = { Delay = Config.Buddy.ChaseHelp[r and r.Order or 1] or 2.6, Name = string.upper((Config.Species[d.Species] or { Name = d.Species }).Name) }
			break
		end
	end
	-- buddy perks that ride along: an EGG GUARD (Oviraptor) catches one egg that would fall off the rack each run;
	-- a SPRINT buddy (Gallimimus) refills the boost faster
	run.EggGuard, run.BoostMult = nil, 1
	for _, d in ipairs(prof and Dinos.BuddyList(prof) or {}) do
		if not run.Fallen[d.Id] then
			local role = Config.BuddyRoleOf(d.Species)
			if role.EggGuard and not run.EggGuard then run.EggGuard = d.Species end
			if role.Sprint then run.BoostMult = math.max(run.BoostMult, 1 + role.Sprint * 1.75) end
		end
	end
	if opts.Boss and opts.Boss.Runner then
		-- the boss on the run: it's out ahead and you chase IT (its pack, if it has one, snaps at you from behind)
		Chase.SpawnRunner(run, pursuer, opts.Boss)
		if (opts.Boss.Count or 1) > 1 then Chase.SpawnPursuers(run, pursuer, opts.Boss.Count - 1, {}) end
	elseif opts.Boss then
		Chase.SpawnPursuers(run, pursuer, opts.Boss.Count or 1, opts.Boss)
	else
		Chase.SpawnPursuers(run, pursuer, count, { LeadScale = takedown and 1 or 1.1 })
		-- THE FORD: on a road that runs through a river, a Sarcosuchus may be lying in wait where it goes in
		local water = run.Route.Data.Water and run.Route.Data.Water[run.Variant]
		if water and rng:NextNumber() < 0.65 then
			for _, span in ipairs(water) do
				if span[1] > run.S + 70 then Chase.SpawnAmbush(run, "Sarcosuchus", span[1]) break end
			end
		end
	end
	publish(run)
	Net.Fire(player, "ChaseStart", { S = run.S, X = run.X, Variant = run.Variant, Cruise = run.Stats.Cruise, BoostSpeed = run.Stats.Boost, Grip = run.Stats.Grip, StopS = run.StopS, Boss = opts.Boss and opts.Boss.Name, Eggs = #run.Eggs, BoostRefill = run.BoostMult, Speed = run.V })
end


-- a buddy bled out (or was left behind downed): out for the rest of this run, then HURT at home for a while
function Expedition.BuddyFell(player: Player, d)
	local run = runs[player]
	if not run or run.Fallen[d.Id] then return end
	run.Fallen[d.Id] = d
	-- never lost (user call 2026-10-12): it rides home hurt and rests, or you pay to patch it up
	local dead = false
	d.HurtUntil = os.time() + Config.Buddy.RestSecs
	Data.Changed(player)
	publishCrew(run) -- (it lies in the back for the rest of the run)
	local name = string.upper((Config.Species[d.Species] or { Name = d.Species }).Name)
	Net.Fire(player, "BuddyFallen", { Id = d.Id, Name = name, Species = d.Species, Dead = dead })
end
function Expedition.Fallen(player: Player, id: string): boolean
	local run = runs[player]
	return run ~= nil and run.Fallen[id] ~= nil
end

-- the companion that can carry you home if the rover flips (bond 6, big enough to ride, still fit)
local function rider(run)
	local profile = Data.Peek(run.Player)
	if not profile then return nil end
	for _, d in ipairs(Dinos.BuddyList(profile)) do
		if not run.Fallen[d.Id] and Config.HasPerk(d.Species, Dinos.BondLevel(profile, d.Id), "Ride") then return d end
	end
	return nil
end

local function finish(run)
	-- (2026-10-14: every step is guarded and the run is ALWAYS let go of at the end - a throw in one of these used to
	-- leave runs[player] set: no Time Gate, no new run, a faint's black screen never lifted)
	local player = run.Player
	local function try(what: string, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then warn("[Expedition] finish:", what, err) end
	end
	-- the hurt ones made it home: they pull through after a rest
	if next(run.Fallen) and player.Parent then
		local names = {}
		for _, d in pairs(run.Fallen) do table.insert(names, string.upper((Config.Species[d.Species] or { Name = d.Species }).Name)) end
		Net.Fire(player, "BuddySaved", { Names = names })
	end
	player:SetAttribute("Crew", nil)
	player:SetAttribute("Mount", nil)
	player:SetAttribute("Holding", nil) -- (an on-foot run's egg in your arms doesn't follow you home)
	try("held", Dinos.ClearHeld, player)
	if Bosses then try("boss", Bosses.Leave, player) end
	try("site", Encounter.Leave, player)
	try("riders", settleRiders, run)
	try("chase", Chase.Clear, run)
	if runs[player] == run then runs[player] = nil end
	Vehicles.Locked[player] = nil
	Vehicles.Parked[player] = nil
	if run.Folder then run.Folder:Destroy() end
end
Expedition.Finish = finish

-- your own driveway (where the garage rolls out), for coming home knocked out
local function plotArrivalCFrame(player: Player): CFrame?
	local Plots = require(script.Parent.Plots)
	local plot = Plots.Get(player)
	local out = plot and plot:FindFirstChild("RollOutPoint", true) :: BasePart?
	local pivot = plot and plot:FindFirstChild("GarageDoorPivot", true) :: BasePart?
	if not (out and pivot) then return nil end
	local v = Vehicles.Get(player)
	local rh = v and v:GetAttribute("RootHeight") or 2.6
	local p = out.Position + Vector3.new(0, rh, 0)
	return CFrame.lookAt(p, p + pivot.CFrame.LookVector)
end

local function returnHome(run, delay: number, toPlot: boolean?)
	local player = run.Player
	task.delay(delay, function()
		if not player.Parent then return end
		-- on foot: the rover was left flipped in the era (or you ran / rode for the portal). It stays behind, and you
		-- land on your island while the warp tunnel still covers the screen. (2026-10-12: a flipped rover that still
		-- existed counted as "driving home" - the camera came home, you stayed standing in the era)
		local v = Vehicles.Get(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seated = v ~= nil and hum ~= nil and hum.SeatPart ~= nil and hum.SeatPart:IsDescendantOf(v)
		if v and not seated then sendRidersHome(run) Vehicles.Despawn(player) end
		local cf = (toPlot and plotArrivalCFrame(player)) or hubArrivalCFrame(player)
		Net.Fire(player, "ReturnHome", { Arrival = cf, OnFoot = not seated })
		if seated then ridersComeHome(run, cf) else sendRidersHome(run) end
		if seated then
			task.delay(3, function()
				local root = Vehicles.Root(player)
				if root and (root.Position - cf.Position).Magnitude > 300 then Vehicles.Teleport(player, cf) end
			end)
		else
			task.delay(1, function()
				local char = player.Character
				local spawn = require(script.Parent.Plots).SpawnCFrame(player)
				if char and spawn then char:PivotTo(spawn + Vector3.new(0, 2.5, 0)) end
			end)
		end
	end)
end

function Expedition.Extract(run)
	if run.Phase ~= "Driving" and run.Phase ~= "OnFoot" then return end
	local onFoot = run.Phase == "OnFoot"
	run.Phase = "Extracting"
	local player = run.Player
	local profile = Data.Peek(player)
	local banked = {}
	local coins = run.Coins + X.ExtractBonus * Config.EraTier(run.Zone)
	if onFoot then
		player:SetAttribute("Holding", nil)
		Dinos.ClearHeld(player)
	end
	if profile then
		-- the eggs stay strapped on the rack: you drive them home and carry each one to a nest
		-- (made it on foot: the egg in your arms goes straight into your bag)
		profile.RoverEggs = profile.RoverEggs or {}
		for _, e in ipairs(run.Eggs) do
			-- (on foot into your bag - AddEgg counts it in Stats.Eggs; a full bag keeps it on your rack instead of
			-- losing it while the summary said it was banked)
			if not (onFoot and Dinos.AddEgg(player, e.Species, e.Rarity, nil, e.KG)) then
				table.insert(profile.RoverEggs, { Species = e.Species, Rarity = e.Rarity, KG = e.KG })
				profile.Stats.Eggs += 1
			end
			table.insert(banked, e)
		end
		Vehicles.ShowRack(player)
		-- your companions made it home with you: their bond grows
		local came = {}
		for _, d in ipairs(Dinos.BuddyList(profile)) do if not run.Fallen[d.Id] then table.insert(came, d.Id) end end
		task.defer(Dinos.AddBond, player, came, Config.Bond.Gain.Home)
		profile.Coins += coins
		profile.Earned += coins
		Analytics.Coins(player, "Source", coins, "Gameplay", "Expedition_" .. tostring(run.Zone))
		Analytics.RunStep(player, run, "Home")
		profile.Stats.Runs += 1
		Quests.Progress(player, "Expedition", { Count = 1 })
		-- (eggs count for the Eggs quest once they're home, as it says - not when they went on the rack)
		if #banked > 0 then Quests.Progress(player, "Eggs", { Count = #banked }) end
		Data.Changed(player)
	end
	publish(run)
	Net.Fire(player, "Extracted", { Eggs = banked, Coins = coins, Time = os.clock() - run.Started, HP = run.HP, MaxHP = run.MaxHP, Zone = run.Zone })
	returnHome(run, 2.2)
	task.delay(2.4, function() if runs[player] == run then finish(run) end end)
end

function Expedition.Wreck(run)
	if run.Phase ~= "Driving" then return end
	run.Phase = "Wrecked"
	local player = run.Player
	local lost = table.clone(run.Eggs)
	table.clear(run.Eggs)
	local profile = Data.Peek(player)
	if profile then
		profile.Stats.Wrecks += 1
		profile.Coins += run.Coins -- you keep the coins you picked up
		profile.Earned = (profile.Earned or 0) + run.Coins
		Data.Changed(player)
	end
	publish(run)
	Net.Fire(player, "Wrecked", { Lost = lost, Coins = run.Coins })
	returnHome(run, 3.4)
	task.delay(3.6, function() if runs[player] == run then finish(run) end end)
end

-- 0 HP doesn't end the run: the rover flips. some eggs crack; the chasers circle for a few seconds while you
-- choose: pay to flip it back and keep driving, or grab your best egg and run for the portal on foot
local function repairCost(run): number
	-- a WORKSHOP / HANGAR at home makes repairs cheaper (Config.Island.Garage)
	local profile = run.Player and Data.Peek(run.Player)
	return math.floor(X.RepairBase * Config.EraTier(run.Zone) * Config.GarageTier(profile).Repair)
end
-- a dino's attack lands on your rover while it's parked at a site: it takes the dent (it can't flip while parked -
-- it's your getaway - so it stops at 1 HP; the damage carries into the chase)
function Expedition.HurtParked(player: Player, amount: number, kind: string)
	local run = runs[player]
	if not run or not run.HP then return end
	if os.clock() < (run.ParkInvuln or 0) then return end
	run.ParkInvuln = os.clock() + 0.6
	run.HP = math.max(1, run.HP - amount * (run.DamageMult or 1))
	Net.Fire(player, "RoverHit", { Damage = math.floor(amount), HP = run.HP, MaxHP = run.MaxHP, Kind = kind })
	publish(run)
end

function Expedition.Topple(run)
	if run.Phase ~= "Driving" then return end
	run.Phase = "Toppled"
	-- (it's lying still: the pack reads your speed, and a stale 40 sent them sprinting off down the road instead of
	-- circling the wreck)
	run.V = 0
	run.Boosting = false
	local token = {}
	run.ToppleToken = token
	local player = run.Player
	run.ChaseHold = os.clock() + X.ToppleHold
	local broken, kept = {}, {}
	for _, e in ipairs(run.Eggs) do
		if not isBossEgg(e) and rng:NextNumber() < X.ToppleBreak * eggSafe(run) then table.insert(broken, e) else table.insert(kept, e) end
	end
	run.Eggs = kept
	Vehicles.GetOut(player, nil)
	publish(run)
	local profile = Data.Peek(player)
	local cost = repairCost(run)
	local r = rider(run)
	Net.Fire(player, "Toppled", { Broken = broken, Kept = kept, Cost = cost, CanAfford = profile ~= nil and profile.Coins >= cost, Hold = X.ToppleHold,
		Ride = r and string.upper((Config.Species[r.Species] or { Name = r.Species }).Name) or nil })
	-- nobody chose: you're on your feet and running
	task.delay(X.ToppleHold + 8, function()
		-- (only for THIS flip: a repaired-then-flipped-again rover gets its own full countdown)
		if runs[player] == run and (run.Phase :: string) == "Toppled" and run.ToppleToken == token then Expedition.ToppleChoice(player, "Run") end
	end)
end

function Expedition.ToppleChoice(player: Player, choice: string)
	local run = runs[player]
	if not run or run.Phase ~= "Toppled" then return { Ok = false } end
	local profile = Data.Peek(player)
	if choice == "Repair" then
		local cost = repairCost(run)
		if not profile or profile.Coins < cost then return { Ok = false, Err = "NOT ENOUGH COINS" } end
		profile.Coins -= cost
		Data.Changed(player)
		run.HP = math.floor(run.MaxHP * Config.GarageTier(Data.Peek(player)).RepairHP)
		run.Phase = "Driving"
		run.Invuln = os.clock() + 2.5
		run.ChaseHold = os.clock() + 2.5
		Vehicles.GetIn(player)
		publish(run)
		Net.Fire(player, "Repaired", { S = run.S, X = run.X, Variant = run.Variant, HP = run.HP, MaxHP = run.MaxHP })
		return { Ok = true }
	elseif choice == "Ride" then
		-- Ride It Home: hop on your companion's back; it carries you AND every egg left (it takes the bites now)
		local d = rider(run)
		if not d then return { Ok = false, Err = "NOBODY TO RIDE" } end
		if #run.Eggs == 0 then return { Ok = false, Err = "NO EGGS LEFT TO CARRY" } end
		local hp = Config.BuddyHP(d, Dinos.BondLevel(profile, d.Id))
		run.Mount = { Dino = d, HP = hp, MaxHP = hp }
		run.Phase = "OnFoot"
		run.OnFoot = true
		run.FootHP = X.FootHP
		run.ChaseHold = os.clock() + 2
		Vehicles.GetOut(player, nil)
		sendRidersHome(run)
		player:SetAttribute("Mount", d.Species)
		task.delay(1.5, function() if runs[player] == run then Vehicles.Despawn(player) end end)
		publish(run)
		Net.Fire(player, "OnFootRun", { Mount = string.upper((Config.Species[d.Species] or { Name = d.Species }).Name), HP = hp, Max = hp, Eggs = #run.Eggs })
		return { Ok = true }
	elseif choice == "Run" then
		if #run.Eggs == 0 then
			-- nothing left to save: the rangers tow you home
			run.Phase = "Driving"
			Expedition.Wreck(run)
			return { Ok = true }
		end
		-- the best egg comes with you; the rest stay in the wreck
		table.sort(run.Eggs, eggKeepOrder) -- (a boss egg always comes first: it never stays behind)
		local best = run.Eggs[1]
		run.Eggs = { best }
		run.Phase = "OnFoot"
		run.OnFoot = true
		run.FootHP = X.FootHP
		run.ChaseHold = os.clock() + 2
		Vehicles.GetOut(player, nil)
		sendRidersHome(run)
		player:SetAttribute("Holding", best.Species)
		Dinos.ShowHeld(player, best)
		task.delay(1.5, function() if runs[player] == run then Vehicles.Despawn(player) end end)
		publish(run)
		Net.Fire(player, "OnFootRun", { Egg = best, HP = run.FootHP, Max = X.FootHP })
		return { Ok = true }
	end
	return { Ok = false }
end

-- go home from the era map without an encounter
function Expedition.GoHome(player: Player)
	local run = runs[player]
	if not run or (run.Phase ~= "Map" and run.Phase ~= "Site") then return { Ok = false } end
	if downedAtSite(player) then return { Ok = false, Err = "YOU'RE DOWN - WAIT FOR A REVIVE" } end
	-- (the same rule as BackToMap: eggs taken from the nest you're standing in mean the chase. Since GoHome banks the
	-- rack, a GoHome sent from a nest skipped the chase outright - 2026-10-14)
	if run.Phase == "Site" and player:GetAttribute("Site") ~= nil and #run.Eggs > (run.JoinEggs or 0) then
		return { Ok = false, Err = takenErr(player) }
	end
	if Bosses then Bosses.Leave(player) end
	Encounter.Leave(player)
	Vehicles.GetIn(player)
	reseatRiders(run)
	if #run.Eggs > 0 then
		-- eggs on the rack (a boss's prize after its den rests, a rack you drove off the map with): they come home
		-- like any escape's. (2026-10-14: GoHome dropped them - the roam's "DRIVE INTO THE PORTAL" lost a boss egg)
		run.Phase = "Driving"
		Chase.Clear(run)
		Expedition.Extract(run)
		return { Ok = true }
	end
	run.Phase = "Extracting"
	publish(run)
	local profile = Data.Peek(player)
	if profile and run.Visited then
		local came = {}
		for _, d in ipairs(Dinos.BuddyList(profile)) do if not run.Fallen[d.Id] then table.insert(came, d.Id) end end
		task.defer(Dinos.AddBond, player, came, Config.Bond.Gain.Visit)
	end
	returnHome(run, 0.2)
	task.delay(0.6, function() if runs[player] == run then finish(run) end end)
	return { Ok = true }
end

function Expedition.DevJump(player: Player, s: number)
	local run = runs[player]
	if not run or run.Phase ~= "Driving" then return false end
	run.S = math.clamp(s, 0, run.Route:Length(run.Variant) - 20)
	run.PrevS = run.S
	Net.Fire(player, "DevJump", { S = run.S })
	return true
end

function Expedition.DevRefill(player: Player)
	local run = runs[player]
	if not run then return false end
	run.HP, run.Darts, run.Boost = run.MaxHP, run.MaxDarts, 1
	publish(run)
	return true
end

-- downed and nobody came: the rangers carry you home. The run ends and the eggs on your rack are lost.
-- nobody picked you up: the screen fades to black, you wake up on foot at your own plot (no rover, no warp).
-- the eggs from this run are lost; coins you picked up are kept
local FAINT_BLACK = 1.1 -- the client's fade-out time; the move home happens behind the black
function Expedition.Faint(player: Player)
	local run = runs[player]
	-- a rider who went down and wasn't revived: no run of their own to end - they wake up back in their seat
	if not run and Expedition.RiderRun(player) then
		local driver = (Expedition.RiderRun(player) :: any).Player
		Expedition.Reseat(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = hum.MaxHealth end
		-- out of the fight: your camera follows the driver, or you head home (client Carpool)
		Net.Fire(player, "RiderOut", { Driver = driver.UserId })
		return
	end
	if not run or run.Phase == "Wrecked" or run.Phase == "Extracting" then return end
	run.Phase = "Wrecked"
	local okR, errR = pcall(sendRidersHome, run)
	if not okR then warn("[Expedition] faint riders:", errR) end
	local lost = table.clone(run.Eggs)
	table.clear(run.Eggs)
	-- you're out cold: anyone still lying downed can't be helped now, and every buddy that fell this run is gone
	pcall(Encounter.FallDowned, player)
	-- (they already died when they bled out; a new player's spared pets still come home)
	if next(run.Fallen) then run.LostApplied = true end
	local profile = Data.Peek(player)
	if profile then
		profile.Coins += run.Coins
		profile.Earned = (profile.Earned or 0) + run.Coins
		Data.Changed(player)
	end
	publish(run)
	Net.Fire(player, "Fainted", { Lost = lost, Coins = run.Coins, Black = FAINT_BLACK })
	task.delay(FAINT_BLACK + 0.15, function()
		if runs[player] == run then finish(run) end
		if not player.Parent then return end
		-- (whatever goes wrong moving you home, WokeUp always goes out: it's what lifts the client's black screen)
		local ok, err = pcall(function()
			Vehicles.Despawn(player)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Sit = false
				hum.PlatformStand = false
				if hum.Health > 0 then hum.Health = hum.MaxHealth end
				hum.WalkSpeed = Config.Player.WalkSpeed
			end
			local cf = Plots.SpawnCFrame(player)
			if char and cf then char:PivotTo(cf + Vector3.new(0, 2.5, 0)) end
		end)
		if not ok then warn("[Expedition] faint home:", err) end
		Net.Fire(player, "WokeUp", {})
	end)
end

function Expedition.Abort(player: Player)
	local run = runs[player]
	if run then finish(run) end
end

--------------------------------------------------------------------------------
-- driving reports (chase only)
--------------------------------------------------------------------------------
local function onDrive(player: Player, s: number, x: number, v: number, boosting: boolean, c1: number?, c2: number?)
	local run = runs[player]
	if not run or run.Phase ~= "Driving" then return end
	if s ~= s or x ~= x or v ~= v then return end
	-- the branch the rover actually took at each fork: lengths differ per branch, so without this the server
	-- could think you were still short of the portal while your screen said 0m (you got stuck there)
	-- (a fork's choice can change on the way up to it, and is locked once you're 30 studs past it: a client can't
	-- hop branches later to skip road)
	if (c1 == 1 or c1 == 2) and (c2 == nil or c2 == 1 or c2 == 2) then
		local cur = run.Route:Variant(run.Variant).Choices or { 1, 1 }
		local forks = run.Route.Data.Forks or {}
		local function past(i: number): boolean
			local f = forks[i]
			local fs = f and f.S and (f.S[run.Variant] or f.S[1])
			return fs ~= nil and fs >= 0 and run.S > fs + 30
		end
		local w1 = past(1) and cur[1] or c1
		local w2 = past(2) and cur[2] or (c2 or cur[2])
		local vi = run.Route:VariantFor(w1, w2)
		if vi and vi ~= run.Variant then run.Variant = vi end
	end
	local now = os.clock()
	local elapsed = math.min(now - run.LastReport, 1)
	run.LastReport = now
	local route = run.Route
	local canBoost = boosting and run.Boost > 0.02
	local vmax = canBoost and run.Stats.Boost or run.Stats.Cruise * 1.1
	-- how far you may have driven: a budget that refills with real time (reports sent faster don't buy distance -
	-- a per-report allowance with a free +2 let a spammed client teleport down the road)
	run.Budget = math.min((run.Budget or 0) + (vmax * 1.3 + 6) * elapsed, 14)
	local ds = s - run.S
	if ds > 0 then
		local adv = math.min(ds, run.Budget)
		run.Budget -= adv
		s = run.S + adv
	elseif ds < -2 then
		s = run.S
	end
	local hw = route:HalfWidth(run.Variant, s)
	-- sideways too: a swerve is quick, a teleport across the road isn't
	local maxX = 34 * elapsed + 1.5
	x = math.clamp(x, run.X - maxX, run.X + maxX)
	run.X = math.clamp(x, -hw + 2, hw - 2)
	run.S = s
	run.V = math.clamp(v, 0, vmax)
	run.Boosting = canBoost
end

local function onChaserEvent(run)
	return function(kind: string, c)
		local side = (c.X > run.X) and 1 or -1
		if kind == "Telegraph" then
			Net.Fire(run.Player, "Warning", { Side = side, Species = c.Species, Id = c.Id, Kind = "Lunge", Time = c.TeleDur or 0.9 })
		elseif kind == "Lunge" then
			local dmg = c.Boss and Config.Chase.Alpha.Damage or ((c.Species == "Velociraptor") and X.Damage.Lunge or X.Damage.Charge)
			damage(run, dmg * (run.DamageMult or 1), "Lunge", side, true)
		elseif kind == "Charge" then
			damage(run, X.Damage.Charge * (run.DamageMult or 1), "Charge", side, true)
		elseif kind == "Kick" then
			-- the boss on the run lashes back at you (you were sitting on its tail in its lane)
			damage(run, Config.Chase.Alpha.Damage * (run.DamageMult or 1), "Charge", side, true)
		elseif kind == "Ambush" then
			-- the ford croc's lunge across the water
			damage(run, X.Damage.Charge * (run.DamageMult or 1), "Charge", side, true)
		elseif kind == "Stampede" then
			damage(run, X.Damage.Stampede * (run.DamageMult or 1), "Stampede", side, true)
		elseif kind == "Latch" and c.Species == "Oviraptor" and not c.Boss and not c.Carrying then
			-- an Oviraptor doesn't hang on: it plucks an egg right off the rack and peels away with it. Dart it before
			-- it's gone and it drops the egg back on (FireDart)
			damage(run, X.Damage.Latch * (run.DamageMult or 1), "Bite", side, false)
			if run.Phase ~= "Driving" then return end
			local egg = loseEgg(run)
			if egg then
				c.Carrying = egg
				c.Cfg:SetAttribute("CarryEgg", egg.Species)
				publish(run)
				Net.Fire(run.Player, "EggPlucked", { Side = side, Species = egg.Species, Rarity = egg.Rarity, Id = c.Id })
			end
			Chase.Flee(run, c)
		elseif kind == "Latch" then
			damage(run, X.Damage.Latch * (run.DamageMult or 1), "Bite", side, false)
			if run.Phase ~= "Driving" then return end -- (that bite flipped it: no "SWERVE!" banner over the FLIPPED card)
			Net.Fire(run.Player, "Latched", { Side = side, Id = c.Id, Species = c.Species })
			-- three hanging off it: too heavy, the rover goes over
			local n = Chase.Latched(run)
			if n >= 3 and run.Phase == "Driving" then
				Net.Fire(run.Player, "Toast", { Text = "TOO MANY ON BOARD!", Color = "Red" })
				run.Invuln = 0
				damage(run, run.HP + 1, "Swarm", side, false)
			elseif n == 2 then
				Net.Fire(run.Player, "Toast", { Text = "SWERVE! SHAKE THEM OFF!", Color = "Red" })
			end
		elseif kind == "Gnaw" then
			local before = run.Invuln
			run.Invuln = 0 -- a chew always lands while it's hanging on
			damage(run, X.Damage.Gnaw * (run.DamageMult or 1), "Gnaw", side, rng:NextNumber() < X.LatchDropChance / X.EggDropChance)
			if run.Invuln == 0 then run.Invuln = before end
		elseif kind == "ShakenOff" then
			Net.Fire(run.Player, "ShakenOff", { Side = side, Id = c.Id })
		elseif kind == "BuddyBite" then
			Net.Fire(run.Player, "ShakenOff", { Side = side, Id = c.Id, Buddy = true })
			Net.Fire(run.Player, "Toast", { Text = (run.Helper and run.Helper.Name or "YOUR BUDDY") .. " BIT IT OFF!", Color = "Orange" })
		elseif kind == "Miss" then
			Net.Fire(run.Player, "Dodged", { Side = side, Species = c.Species })
		end
	end
end

--------------------------------------------------------------------------------
-- LOSING THE PACK (2026-10-14, user: "allow for driving with an egg and not going to the exit gate so you can get
-- more eggs"). Lose them and the chase is over: a LOST THEM! beat, then you're out roaming again from right where you
-- are, the eggs still on the rack - another nest, a wild one, the den, until the rack's full. The return portal
-- banks everything (GoHome -> Extract), and reaching it mid-chase still does. Every chase after puts what's already on
-- board at risk again (a flip cracks eggs): pushing your luck is the game. Lost means one of:
--   * a long enough lead, held: the nearest one still hunting is Gap studs back for GapHold s (stun the lunger with
--     a dart on its warning flash, then boost - their catch-up sprint is about a boost's pace, so the lead holds)
--   * nobody left hunting you: every one worn out (boosting / darts drain their stamina), calmed or gone, for OutHold s
--   * they give up: Cap s of driving (toppled time doesn't count) with nobody on you at that moment. Chases from the
--     nests deep down the road reach the portal first - those still end there, as before
-- Never the boss on the run (Losable), never in the last stretch before the portal (you're as good as home), and
-- each player's chase is their own (runs are per player: two rovers fleeing one nest lose their packs separately).
--------------------------------------------------------------------------------
local function loseTick(run, dt: number)
	if not run.Losable then return end
	run.ChaseT = (run.ChaseT or 0) + dt
	if run.S > run.Route:Length(run.Variant) - LOSE.NearEnd then run.LoseFor = 0 return end
	local gap, onYou, hunters = Chase.Pursuit(run)
	local need = (hunters == 0 and LOSE.OutHold) or (gap >= LOSE.Gap and LOSE.GapHold) or nil
	run.LoseFor = need and (run.LoseFor or 0) + dt or 0
	local lost = need ~= nil and run.LoseFor >= need
	if not lost and run.LoseCap and run.ChaseT >= run.LoseCap and not onYou and os.clock() >= (run.Invuln or 0) then lost = true end
	if not lost then return end
	local player = run.Player
	run.Phase = "Map"
	run.Losable = false
	run.StopS, run.OnStop, run.OnDart = nil, nil, nil
	run.Boosting = false
	run.LoseFor, run.ChaseT = 0, 0
	Chase.GiveUp(run)
	-- roaming again from right here (the rover isn't moved): the nest you fled doesn't take you back until you've been
	-- away from it, and no reach you're in pulls you in under the beat (roamJoins starts fresh after the hold)
	run.NoRejoin = run.ChaseSite
	run.SiteKey = nil
	run.Inside = nil
	run.ArriveHold = os.clock() + 2
	Vehicles.Locked[player] = nil -- (free roam: hop out anywhere again)
	publish(run)
	Net.Fire(player, "ChaseLost", { Eggs = #run.Eggs, Slots = Expedition.RackCapacity(player) })
	-- riders stay in their seats and roam on with you (they step out at the next stop - joinSite); they see the beat too
	for plr in pairs(run.Riders or {}) do
		if riderOf[plr] == run then Net.Fire(plr, "ChaseLost", { Rider = true, Eggs = #run.Eggs }) end
	end
end

local function tickRun(run, dt: number)
	if run.Phase == "Map" or run.Phase == "Site" then roamTick(run) end
	if run.Phase == "OnFoot" then
		local char = run.Player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			-- (the client owns its character: cap how far down the road a tick can move you - walking, sprinting or on
			-- your companion's back - and ignore you while you're far off the road. Unchecked, a teleport ran you home)
			local s, x, d = run.Route:Project(run.Variant, hrp.Position, run.S)
			if d < 60 then
				s = math.min(s, run.S + ((run.Mount and 45 or 34) * 1.25 + 4) * dt)
				run.V = math.max(0, (s - run.S) / math.max(dt, 1e-3))
				run.S, run.X = s, x
			end
		end
		Chase.Update(run, dt, onChaserEvent(run))
		if run.S >= run.Route:Length(run.Variant) - 8 then Expedition.Extract(run) end
		return
	end
	if run.Phase ~= "Driving" then
		Chase.Update(run, dt, function() end)
		return
	end
	local route, vi, S, Xp = run.Route, run.Variant, run.S, run.X
	if run.Darts < run.MaxDarts then
		run.DartRegenAt += dt
		if run.DartRegenAt >= X.DartRegen then run.DartRegenAt = 0 run.Darts += 1 publish(run) end
	end
	if run.Boosting then run.Boost = math.max(0, run.Boost - X.BoostDrain * dt) else run.Boost = math.min(1, run.Boost + X.BoostRefill * (run.BoostMult or 1) * dt) end
	local prevS = run.PrevS or S
	run.PrevS = S
	for _, f in ipairs(route.Data.Features) do
		if run.Handled[f.Id] then continue end
		local fs = f.S[vi]
		if not fs or fs < 0 then continue end
		if f.Type == "Charge" or f.Type == "Stampede" then run.Handled[f.Id] = true continue end
		if fs > S + 1.5 then continue end
		if fs < prevS - 6 then run.Handled[f.Id] = true continue end
		local dx = math.abs(Xp - f.X)
		if OBSTACLES[f.Type] then
			if dx < (f.W / 2 + 2.6) and math.abs(S - fs) < 3.5 then
				run.Handled[f.Id] = true
				damage(run, X.Damage[f.Type] or 10, f.Type, (f.X > Xp) and 1 or -1, false)
				Net.Fire(run.Player, "Bump", { Id = f.Id, Kind = f.Type })
			elseif S > fs + 3.5 then
				run.Handled[f.Id] = true
			end
		elseif PICKUPS[f.Type] then
			if run.Taken and run.Taken[f.Id] then
				run.Handled[f.Id] = true
			elseif dx < 3.8 and math.abs(S - fs) < 3.5 then
				if run.Taken then run.Taken[f.Id] = true end
				run.Handled[f.Id] = true
				if f.Type == "Boost" then run.Boost = math.min(1, run.Boost + X.BoostPickup)
				elseif f.Type == "Repair" then run.HP = math.min(run.MaxHP, run.HP + X.RepairPickup)
				elseif f.Type == "Coin" then run.Coins += X.CoinPickup * Config.EraTier(run.Zone)
				elseif f.Type == "Darts" then run.Darts = math.min(run.MaxDarts, run.Darts + X.DartPickup) end
				Net.Fire(run.Player, "Pickup", { Id = f.Id, Kind = f.Type, Boost = run.Boost, HP = run.HP, Darts = run.Darts })
				publish(run)
			elseif S > fs + 3.5 then
				run.Handled[f.Id] = true
			end
		else
			run.Handled[f.Id] = true
		end
	end
	Chase.Update(run, dt, onChaserEvent(run))
	-- a boss fight can stop the chase partway (the final stand)
	if run.StopS and S >= run.StopS - 2 and run.OnStop then
		local fn = run.OnStop
		run.OnStop = nil
		task.spawn(fn, run)
		return
	end
	if S >= route:Length(vi) - 8 then Expedition.Extract(run) return end
	if run.Phase == "Driving" then loseTick(run, dt) end
end

-- THE TIME GATE (2026-10-14, user: "i just used the time gate and didn't get put into it, make it flawless"). Two ways
-- in, one door: the driver's client catches the rover in the membrane and asks (EnterGate, Drive.luau), and this
-- server's own check of the rover's root is the backup. Why it used to fail silently:
--   * any refusal's toast played UNDER the client's opaque white-out (toasts sit lower) - nobody ever saw it
--   * the 3 s cooldown was armed before Begin, so a start that didn't take (a throw, a refusal) got no second try
--     while you sat in the glow - the white lifted at 3 s, just before the server looked again
--   * the server wanted the root's centre inside the trigger's width with no slack, while the client catches the
--     nose and rolls along its heading: an angled entry near the edge stopped with the root just outside
--   * a throw inside Begin after the run was registered left runs[player] set: the gate skipped you until you rejoined
-- Now the client asks with a generous zone (replication lags the server's copy), every answer carries a reason the
-- client shows once its white-out lifts, and a start in progress is never begun twice.
local gateTrig: BasePart? = nil -- (cached: a recursive search of Base Camp's ~30k parts, 20 times a second, was wasteful)
local gateAt = {} :: { [Player]: number } -- the backup's next try after a refusal (said once, not 20 times a second)
local gateAsked = {} :: { [Player]: number } -- when the client last asked itself (the backup stays quiet meanwhile)
local gateBusy = {} :: { [Player]: boolean }
local function gateTrigger(): BasePart?
	if not (gateTrig and gateTrig.Parent) then
		local camp = Workspace:FindFirstChild("BaseCamp")
		gateTrig = camp and camp:FindFirstChild("GateTrigger", true) :: BasePart?
	end
	return gateTrig
end
local function inGate(root: BasePart, trig: BasePart, slack: number): boolean
	local lp = trig.CFrame:PointToObjectSpace(root.Position)
	local h = trig.Size / 2
	return math.abs(lp.X) < h.X + slack and math.abs(lp.Y) < h.Y + 4 + slack and math.abs(lp.Z) < h.Z + 3 + slack
end
local function enterGate(player: Player, quiet: boolean): { Ok: boolean, Err: string?, Retry: boolean? }
	local run = runs[player]
	-- (already on the way: the other path got there first - the warp is coming, not a refusal)
	if run then return run.Phase == "Warping" and { Ok = true } or { Ok = false, Err = "ALREADY ON AN EXPEDITION" } end
	if gateBusy[player] then return { Ok = false, Retry = true } end
	if Expedition.RiderRun(player) then return { Ok = false, Err = "YOU'RE RIDING IN SOMEONE ELSE'S ROVER" } end
	local trig = gateTrigger()
	local root = Vehicles.Root(player)
	if not (trig and root) then return { Ok = false, Err = "NO ROVER - CALL ONE FIRST" } end
	-- (the client stops its rover in the glow; this copy of it can be a few frames behind - 14 studs of slack, and the
	-- client asks again while it rolls in)
	if not inGate(root, trig, 14) then return { Ok = false, Err = "DRIVE RIGHT INTO THE GATE", Retry = true } end
	local profile = Data.Peek(player)
	gateBusy[player] = true
	local ok, res = pcall(Expedition.Begin, player, profile and profile.Era or "FernValley", { Site = player:GetAttribute("PendingSite"), Quiet = quiet })
	gateBusy[player] = nil
	if not ok then
		warn("[Expedition] gate:", res)
		return { Ok = false, Err = "THE GATE SPUTTERED - TRY AGAIN" }
	end
	if res and res.Ok then player:SetAttribute("PendingSite", nil) end
	return res or { Ok = false, Err = "THE GATE SPUTTERED - TRY AGAIN" }
end
function Expedition.EnterGate(player: Player)
	gateAsked[player] = os.clock()
	return enterGate(player, true)
end
local function tickGate()
	local trig = gateTrigger()
	if not trig then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if runs[plr] or gateBusy[plr] or os.clock() < (gateAt[plr] or 0) then continue end
		-- (the client is handling it: it asked within the last few seconds and shows its own answer)
		if os.clock() - (gateAsked[plr] or -99) < 4 then continue end
		local root = Vehicles.Root(plr)
		if not (root and inGate(root, trig, 0)) then continue end
		-- (driven in: a rover left parked in the glow doesn't start a run for its owner wherever they are)
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.SeatPart and hum.SeatPart:IsDescendantOf(Vehicles.Get(plr) :: Model)) then continue end
		local res = enterGate(plr, false)
		if not res.Ok and not res.Retry then gateAt[plr] = os.clock() + 3 end
	end
end

-- THE RETURN PORTAL (2026-10-14, user: "when you boost through the exit gate you can kind of see the car go through
-- the gate"): the server noticed a beat late (4 checks a second in free roam, the chase at 8 studs PAST the end), so
-- the rover drove out the far side on camera. The driver's client now catches it in the membrane and asks
-- (EnterPortal); the checks here are the backup, on the membrane itself. Where it stands, per era (cached):
local portalAt = {} :: { [string]: { CF: CFrame, HW: number } | false }
local function returnPortal(zone: string): { CF: CFrame, HW: number }?
	local c = portalAt[zone]
	if c == nil then
		c = false
		local zm = zoneModel(zone)
		local p = zm and zm:FindFirstChild("ReturnPortal", true)
		local m = p and p:FindFirstChild("Membrane", true)
		if m and m:IsA("BasePart") then
			local look = Vector3.new(m.CFrame.LookVector.X, 0, m.CFrame.LookVector.Z)
			-- (frame faces down the road: object -Z is "past the portal". HW: the membrane hexagon's half-width)
			if look.Magnitude > 0.01 then c = { CF = CFrame.lookAt(m.Position, m.Position + look.Unit), HW = m.Size.X } end
		end
		portalAt[zone] = c
	end
	return c or nil
end
-- where a point is against the portal: along (+ before it, - past it) and across; nil without a portal model
local function portalLocal(run, pos: Vector3): Vector3?
	local pt = returnPortal(run.Zone)
	if not pt then return nil end
	local lp = pt.CF:PointToObjectSpace(pos)
	if math.abs(lp.X) > pt.HW + 6 or math.abs(lp.Y) > 40 then return Vector3.new(lp.X, lp.Y, math.huge) end
	return lp
end
local function seatedRoot(player: Player): BasePart?
	local v = Vehicles.Get(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (v and v.PrimaryPart and hum and hum.SeatPart and hum.SeatPart:IsDescendantOf(v)) then return nil end
	return v.PrimaryPart
end
-- the chase / free roam reached the portal: the trip home starts (Extract with eggs aboard, else GoHome)
local function throughPortal(run): { Ok: boolean, Err: string? }
	local player = run.Player
	if run.Phase == "Driving" then
		Expedition.Extract(run)
		return { Ok = (run.Phase :: string) == "Extracting" }
	end
	local res = Expedition.GoHome(player)
	return res or { Ok = false }
end
function Expedition.EnterPortal(player: Player)
	local run = runs[player]
	if not run then return { Ok = false } end
	-- (the backup already took it: home's on its way)
	if run.Phase == "Extracting" then return { Ok = true } end
	local pos: Vector3?
	if run.Phase == "Driving" then
		pos = run.Route:Position(run.Variant, run.S, run.X)
	elseif run.Phase == "Map" or run.Phase == "Site" then
		local root = seatedRoot(player)
		if not root then return { Ok = false, Err = "GET IN YOUR ROVER FIRST" } end
		pos = root.Position
	else
		return { Ok = false, Err = "NOT NOW - FINISH WHAT YOU'RE DOING" }
	end
	-- (generous: the client holds its rover nose-in at the membrane, this copy lags it a little)
	local lp = pos and portalLocal(run, pos :: Vector3)
	local near
	if lp then near = lp.Z < 34 and lp.Z > -40 else near = flatDist(pos :: Vector3, run.Route:Position(1, run.Route:Length(1) - 14, 0)) < 40 end
	if not near then return { Ok = false, Err = "DRIVE RIGHT INTO THE PORTAL", Retry = true } end
	return throughPortal(run)
end
-- the backup, every server tick: a rover whose root reached the membrane goes home even if its client never asked
local function portalTick(run)
	local pos: Vector3?
	if run.Phase == "Driving" then
		pos = run.Route:Position(run.Variant, run.S, run.X)
	elseif run.Phase == "Map" then
		-- (the same holds as the nest joins: not under the arrival shots or any cutscene - roamTick)
		if not run.RoamReady or os.clock() < (run.ArriveHold or 0) then return end
		if run.RoamHold and os.clock() - run.RoamHold < 90 then return end
		local root = seatedRoot(run.Player)
		pos = root and root.Position
	end
	if not pos then return end
	local lp = portalLocal(run, pos)
	local hit
	if lp then
		-- (root within a rover's half-length of the membrane either side: the client holds it nose-in at about +8)
		hit = lp.Z < 11 and lp.Z > -6
	else
		hit = run.Phase == "Map" and flatDist(pos, run.Route:Position(1, run.Route:Length(1) - 4, 0)) < 24 -- (no portal model: the old spot)
	end
	if hit then throughPortal(run) end
end

--------------------------------------------------------------------------------
-- the safety net under every site: someone who ended up below the ground there (pushed into a cliff, through a
-- seam) for a few seconds in a row is lifted back out beside the rover (2026-10-15, tester: stuck underground at
-- the Scythe King). "Below": well under both the site's ground and the rover's wheels, with something solid
-- right over their head - so a cave or an overhang at road level never counts.
local buried = {} :: { [Player]: number }
local function underground(plr: Player, driver: Player): boolean
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) or hum.SeatPart or hum.Health <= 0 then return false end
	local site = Encounter.SiteOf(plr) or (Bosses and Bosses.SiteOf and Bosses.SiteOf(plr))
	local ref = site and site.Center and site.Center.Y or nil
	local v = Vehicles.Get(driver)
	if v and v.PrimaryPart then
		local g = v.PrimaryPart.Position.Y - (v:GetAttribute("RootHeight") or 2.6)
		ref = ref and math.min(ref, g) or g
	end
	if not ref or hrp.Position.Y > ref - 10 then return false end
	local skip = {} :: { Instance }
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(skip, p.Character) end end
	local f = Workspace:FindFirstChild("ActiveVehicles")
	if f then table.insert(skip, f) end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = skip
	rp.RespectCanCollide = true
	return Workspace:Raycast(hrp.Position, Vector3.new(0, 120, 0), rp) ~= nil
end
local function unbury(plr: Player, driver: Player)
	local char = plr.Character
	if not char then return end
	local v = Vehicles.Get(driver)
	local site = Encounter.SiteOf(plr) or (Bosses and Bosses.SiteOf and Bosses.SiteOf(plr))
	local toward = site and site.Center or nil
	local at
	if v and v.PrimaryPart then
		at = Vehicles.SafeStand(v, toward)
	elseif toward then
		at = CFrame.new(toward + Vector3.new(0, 5, 0))
	end
	if not at then return end
	warn(`[Expedition] {plr.Name} was under the ground at a site - lifted out`)
	char:PivotTo(at)
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
end
local function checkBuried()
	local seen = {} :: { [Player]: boolean }
	local function check(plr: Player, driver: Player)
		seen[plr] = true
		if plr:GetAttribute("Site") == nil or not underground(plr, driver) then
			buried[plr] = nil
			return
		end
		buried[plr] = (buried[plr] or 0) + 1
		if buried[plr] >= 3 then
			buried[plr] = nil
			unbury(plr, driver)
		end
	end
	for plr, run in pairs(runs) do
		if plr.Parent and run.Phase == "Site" then check(plr, plr) end
	end
	for plr, run in pairs(riderOf) do
		if plr.Parent and runs[run.Player] == run then check(plr, run.Player) end
	end
	for plr in pairs(buried) do if not seen[plr] then buried[plr] = nil end end
end

function Expedition.Start(deps)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(checkBuried)
			if not ok then warn("[Expedition] buried check: " .. tostring(err)) end
		end
	end)
	Data, Net, Vehicles, Plots, Dinos, Quests, Encounter, Bosses = deps.Data, deps.Net, deps.Vehicles, deps.Plots, deps.Dinos, deps.Quests, deps.Encounter, deps.Bosses
	Net.OnDrive(onDrive)
	Net.On("Arrived", function(player) return Expedition.Arrived(player) end)
	Net.On("ChooseSite", function(player, args) return typeof(args.Site) == "string" and Expedition.ChooseSite(player, args.Site) or { Ok = false } end)
	Net.On("TravelDone", function(player) return Expedition.TravelDone(player) end)
	Net.On("ToppleChoice", function(player, args) return typeof(args.Choice) == "string" and Expedition.ToppleChoice(player, args.Choice) or { Ok = false } end)
	Net.On("BackToMap", function(player) return Expedition.BackToMap(player) end)
	Net.On("GoHome", function(player) return Expedition.GoHome(player) end)
	-- the driver's client caught its rover in the Time Gate / the era's return portal (Drive.luau): in, or why not
	Net.On("EnterGate", function(player) return Expedition.EnterGate(player) end)
	Net.On("EnterPortal", function(player) return Expedition.EnterPortal(player) end)
	Net.On("RoamOut", function(player) return Expedition.RoamOut(player) end)
	Net.On("RoamReady", function(player)
		local run = runs[player]
		if run then run.RoamReady = true end
		return { Ok = run ~= nil }
	end)
	Net.On("RoamIn", function(player) return Expedition.RoamIn(player) end)
	-- a cutscene is on this player's screen while they roam (Drive.luau): nothing pulls them into a nest under it
	Net.On("RoamHold", function(player, args)
		local run = runs[player]
		if run then run.RoamHold = args.On == true and os.clock() or nil end
		return { Ok = run ~= nil }
	end)
	Vehicles.Roaming = function(p: Player) local r = runs[p] return r ~= nil and r.Phase == "Map" end
	Net.On("RiderLeave", function(player) return Expedition.RiderLeave(player) end)
	Net.On("FireDart", function(player, args)
		local run = runs[player]
		if not run or run.Phase ~= "Driving" then return { Ok = false } end
		local now = os.clock()
		if now < run.NextDart then return { Ok = false, Err = "RELOADING" } end
		if run.Darts <= 0 then return { Ok = false, Err = "NO DARTS" } end
		local id = tonumber(args.Id)
		local c = id and Chase.Find(run, id)
		if not c then return { Ok = false, Err = "NO TARGET" } end
		local target = c.Cfg:GetAttribute("P")
		local me = run.Route:Position(run.Variant, run.S, run.X)
		if not target or (target - me).Magnitude > X.DartRange + 10 then return { Ok = false, Err = "OUT OF RANGE" } end
		run.NextDart = now + X.DartCooldown
		run.Darts -= 1
		publish(run)
		local travel = math.clamp((target - me).Magnitude / X.DartSpeed, 0.08, 0.7)
		task.delay(travel, function()
			if runs[player] ~= run then return end
			-- a thief hit while it still has your egg: it drops it and the egg lands back on your rack
			local thief = Chase.Find(run, id)
			if thief and thief.Carrying and thief.State ~= "Gone" and run.Phase == "Driving" then
				table.insert(run.Eggs, thief.Carrying)
				thief.Carrying = nil
				thief.Cfg:SetAttribute("CarryEgg", nil)
				publish(run)
				Net.Fire(player, "EggBack", { Id = id })
			end
			local result, ch = Chase.Dart(run, id)
			-- (a boss chase: its darts calm the real boss back in the den, so OnDart says what to show - the
			-- runner's own counter is a placeholder 9999 that read "CALM 9998/9999" to testers)
			local shown = run.OnDart and run.OnDart(run, result, ch) or nil
			-- (a boss runner whose fight is already over has no real meter: never show its 9999 placeholder)
			local placeholder = ch and ch.Boss and run.OnDart and not shown
			Net.Fire(player, "DartHit", { Id = id, Result = result, Calm = not placeholder and (shown and shown.Calm or (ch and ch.Calm)) or nil,
				CalmMax = not placeholder and (shown and shown.CalmMax or (ch and ch.Cfg:GetAttribute("CalmMax"))) or nil, Pct = shown and shown.Pct })
		end)
		return { Ok = true, Darts = run.Darts, Travel = travel }
	end)
	Net.On("SetEra", function(player, args)
		local profile = Data.Peek(player)
		if not profile then return { Ok = false } end
		local era = Config.Era(args.Era)
		if not era then return { Ok = false, Err = "UNKNOWN ERA" } end
		if not era.Built then return { Ok = false, Err = "COMING SOON" } end
		if not profile.Unlocked[era.Id] then return { Ok = false, Err = "BEAT THE PREVIOUS BOSS TO UNLOCK" } end
		profile.Era = era.Id
		Data.Changed(player)
		return { Ok = true }
	end)
	-- unlock the next era: beat its ruler gate, then pay to repair the Time Gate's dial
	Net.On("UnlockEra", function(player, args)
		local profile = Data.Peek(player)
		local era = profile and Config.Era(args.Era)
		if not era or not era.Unlock then return { Ok = false } end
		if profile.Unlocked[era.Id] then return { Ok = false, Err = "ALREADY OPEN" } end
		if not (profile.Bosses[era.Unlock.Boss] and (profile.Bosses[era.Unlock.Boss].Best or 0) >= 1) then
			return { Ok = false, Err = "BEAT THE " .. Config.Bosses[era.Unlock.Boss].Name .. " FIRST" }
		end
		if profile.Coins < era.Unlock.Coins then return { Ok = false, Err = "NOT ENOUGH COINS" } end
		profile.Coins -= era.Unlock.Coins
		profile.Unlocked[era.Id] = true
		profile.Era = era.Id -- the Time Gate dials straight to the era you just opened
		Analytics.Coins(player, "Sink", era.Unlock.Coins, "Shop", "TimeGate_" .. era.Id)
		Analytics.EraOpened(player, era.Id)
		Data.Changed(player)
		Net.FireAll("Announce", { Text = string.upper(player.DisplayName) .. " OPENED " .. era.Name .. "!", Color = "Gold" })
		return { Ok = true }
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then return end
		local step = acc
		acc = 0
		for _, run in pairs(runs) do
			local ok, err = pcall(tickRun, run, step)
			if not ok then warn("[Expedition] tick error:", err) end
			if runs[run.Player] == run then
				local okP, errP = pcall(portalTick, run)
				if not okP then warn("[Expedition] portal tick error:", errP) end
			end
		end
		local okG, errG = pcall(tickGate) -- (unguarded, one throw in a gate start skipped every player's check that tick)
		if not okG then warn("[Expedition] gate tick error:", errG) end
	end)
	-- a rider who dies respawns at home: off the ride (riderRespawned)
	local function hookRider(p: Player)
		p.CharacterAdded:Connect(function()
			if Expedition.RiderRun(p) and not runs[p] then task.defer(riderRespawned, p) end
		end)
	end
	Players.PlayerAdded:Connect(hookRider)
	for _, p in ipairs(Players:GetPlayers()) do hookRider(p) end
	Players.PlayerRemoving:Connect(function(p)
		gateAt[p] = nil
		gateAsked[p] = nil
		gateBusy[p] = nil
		local rr = riderOf[p]
		if rr and rr.Riders then rr.Riders[p] = nil end
		riderOf[p] = nil
		for _, b in pairs(slotBook) do b[p] = nil end
		Expedition.Abort(p)
	end)
	Carpool.Locked = function(plr: Player) return Expedition.RiderRun(plr) ~= nil end
end

return Expedition
