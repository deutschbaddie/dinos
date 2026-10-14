--[[
	DinoExpedition game server — boots every system and wires players through the core loop:
	  join → plot + profile → rover → Time Gate → era map → encounter (escape / takedown) → egg scramble
	  → rover chase → home → incubate → hatch (rarity, KG) → income → upgrades + boss gear → bosses → next era
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local Net = require(script.Net)
local Data = require(script.Data)
local Plots = require(script.Plots)
local Vehicles = require(script.Vehicles)
local Dinos = require(script.Dinos)
local Quests = require(script.Quests)
local Encounter = require(script.Encounter)
local Bosses = require(script.Bosses)
local Expedition = require(script.Expedition)
local Shop = require(script.Shop)
local Monetization = require(script.Monetization)
local Leaderboards = require(script.Leaderboards)
local DevTools = require(script.DevTools)
local Npcs = require(script.Npcs)
local RideShop = require(script.RideShop)
local GearView = require(script.GearView)
local Access = require(script.Access) -- the PRE-BETA tester gate (live servers only) + profile cards

Players.CharacterAutoLoads = true

local deps = {
	Net = Net, Data = Data, Plots = Plots, Vehicles = Vehicles, Dinos = Dinos, Quests = Quests,
	Encounter = Encounter, Bosses = Bosses, Expedition = Expedition, Shop = Shop,
}
Data.Start()
Plots.Start(deps)
Vehicles.Start(deps)
Dinos.Start(deps)
Quests.Start(deps)
require(script.WaterSetup).Start() -- Terrain water for Spine River (before the sites read the ground)
require(script.Shore).Start() -- Base Camp's invisible shore walls (after Vehicles registered its collision group)
local Carpool = require(script.Carpool)
Carpool.Start({ Net = Net, Vehicles = Vehicles, Expedition = Expedition }) -- riding in other players' rovers
Encounter.Start(deps)
Expedition.Start(deps)
require(script.Hotbar).Start(deps) -- dinos pinned to the hotbar (drag from the Bag)
Bosses.Start(deps)
require(script.WildLife).Start(deps) -- free roam's finds: wild (some rare / shiny) dinos + hidden egg stashes
Shop.Start(deps)
require(script.Trainer).Start(deps) -- the power trainer on every island (after Shop: it crafts launchers through it)
require(script.Boosts).Start(deps) -- every multiplier: 2x LUCK events, friend boosts, team luck (Dinos / Trainer / yard read it)
Monetization.Start(deps)
Leaderboards.Start(deps)
DevTools.Start(deps)
Npcs.Start()
RideShop.Start(deps)
GearView.Start(deps)
task.spawn(function() require(script.IslandView).Start() end) -- island upgrades + star pens, dressed for everyone
Access.Start(deps)
require(script.Admin).Start(deps) -- Settings > ADMIN (owner + admins in Admins.luau)
require(script.Trade).Start(deps) -- player-to-player trading of dinos + eggs (opened from VIEW PROFILE)
require(script.Fusion).Start(deps) -- EGG FUSION: 3 matching eggs -> 1 a rarity up, at the Egg Keeper's Fusion Nest
require(script.Quiz).Start(deps) -- GUESS THE DINO, the minigame on your trainer pad (pays power through Trainer)
require(script.IndexRewards).Start(deps) -- the Index pays: species milestones, era pages (gold trophies), titles
require(script.Discover).Start(deps) -- every era's SECRETS (landmarks, nests, stashes, wilds, the boss) for the Index
require(script.Showcase).Start(deps) -- DINO NAMES + the SHOWCASE pedestal by your bridge (Plots.Sync publishes it)
require(script.Spin).Start(deps) -- the DAILY SPIN: a free spin every day + bought spins (prizes in Game/SpinWheel)
require(script.Weather).Start(deps) -- the server's sky: rain, storms, fog, wind, hail (STORM LUCK in a thunderstorm)
require(script.Meteors).Start(deps) -- METEOR SHOWERS over Base Camp: meteorites to collect (Game/WorldEvents)
Bosses.OnClear = function(player) Leaderboards.Push(player) end

-- snapshot sent to the owning client whenever the profile changes
local function snapshot(player: Player, profile)
	return {
		Coins = profile.Coins, Earned = profile.Earned, Pending = profile.Pending,
		Eggs = profile.Eggs, Dinos = profile.Dinos, RoverEggs = profile.RoverEggs or {}, Placed = profile.Placed, Buddies = profile.Buddies,
		Bond = profile.Bond or {}, Balls = profile.Balls or 0, HotbarPins = profile.HotbarPins or {},
		Incubators = profile.Incubators, IncubatorCount = profile.IncubatorCount, PenSlots = profile.PenSlots,
		Island = profile.Island or { Hatchery = 1, Garage = 1, Pens = {} },
		Gear = profile.Gear, Rides = profile.Rides or {}, RideOwned = profile.RideOwned or {}, Materials = profile.Materials, Keys = profile.Keys, Bosses = profile.Bosses, Stars = profile.Stars,
		Index = profile.Index, IndexRewards = profile.IndexRewards, Showcase = profile.Showcase or "", Spin = profile.Spin, Discover = profile.Discover, Unlocked = profile.Unlocked, Quests = profile.Quests, Daily = profile.Daily,
		Stats = profile.Stats, Flags = profile.Flags, Settings = profile.Settings, Era = profile.Era,
		Rate = Dinos.Rate(profile, player), Power = Config.PowerOf(profile, Dinos.BuddyList(profile)),
		Trainer = profile.Trainer or { Level = 1 }, TrainPower = profile.TrainPower or 0, -- (the power trainer, Trainer.luau)
		RackCapacity = Expedition.RackCapacity(player), LuckUntil = profile.LuckUntil,
		Plot = player:GetAttribute("Plot"), ServerTime = os.time(), Offline = Data.Offline[player] == true,
		-- offline money paid as this session loaded (the WHILE YOU WERE AWAY card) + when the last save was
		Away = Data.Away[player], LastSeen = profile.LastSeen,
	}
end

local function leaderstats(player: Player, profile)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local c = Instance.new("IntValue")
		c.Name = "Coins"
		c.Parent = ls
		local b = Instance.new("IntValue")
		b.Name = "Power"
		b.Parent = ls
		ls.Parent = player
	end
	ls.Coins.Value = math.floor(profile.Coins)
	ls.Power.Value = Config.PowerOf(profile, Dinos.BuddyList(profile))
end

Data.OnChanged(function(player, profile)
	leaderstats(player, profile)
	Net.Fire(player, "Profile", snapshot(player, profile))
end)

-- spawn at home. Only Base Camp's own spawn counts: a place's stock baseplate SpawnLocation would otherwise
-- drop half the joins at the world origin, away from the game.
local camp = Workspace:WaitForChild("BaseCamp", 30)
for _, sp in ipairs(Workspace:GetDescendants()) do
	if sp:IsA("SpawnLocation") and not (camp and sp:IsDescendantOf(camp)) then
		sp.Enabled = false
		sp.Neutral = false
	end
end
local function placeAtPlot(player: Player, char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then return end
	-- the plot is assigned after the profile loads; wait for it, then place (and re-check once the default
	-- spawn has settled, so nobody is left standing somewhere else)
	for _ = 1, 3 do
		local cf
		for _ = 1, 100 do
			cf = Plots.SpawnCFrame(player)
			if cf or not char.Parent then break end
			task.wait(0.1)
		end
		if not cf or not char.Parent then return end
		task.wait(0.1)
		char:PivotTo(cf + Vector3.new(0, 2.5, 0))
		task.wait(0.4)
		if (root.Position - cf.Position).Magnitude < 25 then return end
	end
end

local function onPlayer(player: Player)
	-- dying on a run (Reset, knocked off a cliff, the void) ends it like a faint: nobody respawns at camp still
	-- "at a site" (stuck in combat mode at the hub)
	local function hookDeath(char: Model)
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		if not hum then return end
		hum.Died:Connect(function()
			if Expedition.Get(player) then Expedition.Faint(player) else Encounter.Leave(player) end
		end)
	end
	player.CharacterAdded:Connect(function(char) task.spawn(hookDeath, char) placeAtPlot(player, char) end)
	if player.Character then task.spawn(hookDeath, player.Character) task.spawn(placeAtPlot, player, player.Character) end
	-- PRE-BETA: nobody loads a profile until the gate lets them in (not a tester = kicked; Studio is never gated)
	if not Access.Gate(player) then return end
	local profile = Data.Load(player)
	if not profile or not player.Parent then return end
	Plots.Assign(player)
	-- the gate or a slow save load can outlast placeAtPlot's wait for a plot: put them home now
	if player.Character then task.spawn(placeAtPlot, player, player.Character) end
	Plots.Sync(player)
	-- every OnChanged hook (leaderstats, the client snapshot, GearView's dressing) sees the fresh profile
	Data.Changed(player)
	-- these used to race the load on PlayerAdded timers, which the PRE-BETA gate can now outlast
	task.spawn(Monetization.Refresh, player)
	if not Vehicles.Get(player) then Vehicles.RackToBag(player) end
	-- (offline money is paid in Data.Load and shown by the client's WHILE YOU WERE AWAY card - Away in the snapshot)
	-- couldn't reach saves (Roblox outage): say so up front instead of letting them lose a session silently
	if Data.Offline[player] and not Data.NoAccess and RunService:IsStudio() == false then
		task.delay(3, function()
			if player.Parent then Net.Fire(player, "Toast", { Text = "SAVES ARE DOWN RIGHT NOW - REJOIN LATER TO KEEP PROGRESS", Color = "Red" }) end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

Players.PlayerRemoving:Connect(function(player)
	Expedition.Abort(player)
	Vehicles.Despawn(player)
	Data.Save(player, true)
	Plots.Release(player)
	Data.Release(player)
end)

-- the garage prompt / DRIVE button: the client picks a vehicle (if it owns several), then asks for the roll-out
Net.On("TakeVehicle", function(player, args)
	if Expedition.Get(player) then return { Ok = false, Err = "YOU'RE ON AN EXPEDITION" } end
	-- (riding in someone's rover: out of their seat first - seating you in yours dragged theirs along)
	if Carpool.IsPassenger(player) then Carpool.Release(player) end
	local v, mode = Vehicles.TakeVehicle(player, typeof(args.Name) == "string" and args.Name or nil)
	return { Ok = v ~= nil, Mode = mode, Err = v == nil and "CAN'T TAKE THAT VEHICLE" or nil }
end)
-- the driving client noticed it doesn't own its vehicle's physics: fix it and report what was wrong
Net.On("ClaimVehicle", function(player)
	return Vehicles.Claim(player)
end)
Net.On("SetSetting", function(player, args)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local KNOWN = { Shake = "boolean", SkipWarp = "boolean", Hints = "boolean", Music = "boolean", UiSize = "number" }
	if KNOWN[args.Key] and typeof(args.Value) == KNOWN[args.Key] then
		if args.Key == "UiSize" and not (args.Value >= 0.7 and args.Value <= 1.3) then return { Ok = false } end
		profile.Settings[args.Key] = args.Value
		return { Ok = true }
	end
	return { Ok = false }
end)
Net.On("Tip", function(player, args)
	local profile = Data.Peek(player)
	-- (capped: a client looping random keys could otherwise grow the save past the DataStore's 4 MB limit)
	local tips = profile and profile.Flags.Tips
	-- (site keys carry a "/": "Found_FernValley/HornMeadow" - the map's discoveries; 2026-10-13 a filter without it
	-- dropped every discovery, so sites went back to "???" on the next profile push)
	if tips and typeof(args.Key) == "string" and #args.Key <= 64 and args.Key:match("^[%w_%-%.:/]+$") and not tips[args.Key] then
		local n = 0
		for _ in pairs(tips) do n += 1 end
		if n < 300 then tips[args.Key] = true end
	end
	return { Ok = true }
end)
Net.On("ExitVehicle", function(player)
	if Expedition.Get(player) then return { Ok = false, Err = "NOT DURING AN EXPEDITION" } end
	-- (it parks where it is now, eggs and all; Vehicles.Park)
	if not Vehicles.Park(player) then Vehicles.Despawn(player) end
	return { Ok = true }
end)
Net.On("Home", function(player)
	if Expedition.Get(player) then return { Ok = false } end
	local cf = Plots.SpawnCFrame(player)
	-- (a passenger: out of the seat and home through Carpool - moving a body welded into a seat moved the driver's rover)
	if Carpool.IsPassenger(player) then
		Carpool.Release(player, cf and cf + Vector3.new(0, 2.5, 0))
		return { Ok = true }
	end
	Vehicles.Despawn(player)
	local char = player.Character
	if char and cf then char:PivotTo(cf + Vector3.new(0, 2.5, 0)) end
	return { Ok = true }
end)
Net.On("Profile", function(player)
	local profile = Data.Peek(player)
	return profile and { Ok = true, Profile = snapshot(player, profile) } or { Ok = false }
end)
Net.On("Tutorial", function(player, args)
	local profile = Data.Peek(player)
	if profile and typeof(args.Step) == "number" then
		profile.Flags.Tutorial = math.max(profile.Flags.Tutorial or 0, math.floor(args.Step))
	end
	if profile and args.ColdOpen == true then profile.Flags.ColdOpenSeen = true end
	return { Ok = true }
end)

print("[DinoExpedition] game server ready")
