--[[
	DevTools — the Settings > Test Tools actions. Allowed in Studio, for the place creator, and for the
	owner/admins of a group-owned place. Everything a tester needs to reach any part of the loop fast.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local DevTools = {}
local Data, Net, Plots, Vehicles, Dinos, Expedition, Bosses

function DevTools.Allowed(player: Player): boolean
	if RunService:IsStudio() then return true end
	if game.CreatorType == Enum.CreatorType.User then return player.UserId == game.CreatorId end
	local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
	return ok and rank >= 254
end

local function teleport(player: Player, cf: CFrame)
	local char = player.Character
	if char then char:PivotTo(cf + Vector3.new(0, 3, 0)) end
end

local function find(root: Instance?, name: string): BasePart?
	local p = root and root:FindFirstChild(name, true)
	return p and p:IsA("BasePart") and p or nil
end

local ACTIONS = {}

ACTIONS.AddCoins = function(player, args)
	local p = Data.Peek(player)
	local n = math.clamp(tonumber(args.Amount) or 1000, 0, 1e9)
	p.Coins += n
	p.Earned += n
	Data.Changed(player)
	return "+" .. Config.FormatNumber(n) .. " COINS"
end

ACTIONS.UnlockGear = function(player)
	local p = Data.Peek(player)
	for name in pairs(Config.Vehicles) do p.Gear.Vehicles[name] = true end
	for name in pairs(Config.Launchers) do p.Gear.Launchers[name] = true end
	for name in pairs(Config.Armors) do p.Gear.Armors[name] = true end
	for name in pairs(Config.Gadgets) do p.Gear.GadgetsOwned[name] = true end
	p.Gear.Gadgets = { "Bait", "Flare" }
	Plots.Sync(player)
	Data.Changed(player)
	return "ALL GEAR UNLOCKED"
end

-- every rover part and paint (build-your-own testing)
ACTIONS.UnlockRideParts = function(player)
	local Rides = require(ReplicatedStorage.DinoExpedition.Game.Rides)
	local p = Data.Peek(player)
	p.RideOwned = p.RideOwned or {}
	for _, slot in ipairs(Rides.Slots) do
		for _, it in ipairs(Rides.List(slot)) do p.RideOwned[Rides.Key(slot, it.Id)] = true end
	end
	Data.Changed(player)
	return "EVERY RIDE PART UNLOCKED"
end

ACTIONS.GiveEgg = function(player, args)
	local sp = Config.Species[args.Species] and args.Species or "Velociraptor"
	local rarity = Config.Rarity[args.Rarity] and args.Rarity or nil
	local egg = Dinos.AddEgg(player, sp, rarity, 0)
	if egg then egg.Dev = true end -- (a test egg: its hatch is never announced to the server - Dinos announceHatch)
	Data.Changed(player)
	return egg and (Config.Rarity[egg.Rarity].Name .. " " .. Config.Species[sp].Name .. " EGG") or "EGG BAG FULL"
end

ACTIONS.GiveEggs = function(player)
	local n = 0
	for _, r in ipairs(Config.RarityOrder) do
		local egg = Dinos.AddEgg(player, "Velociraptor", r, 0)
		if egg then egg.Dev = true n += 1 end
	end
	Data.Changed(player)
	return n .. " EGGS (ONE OF EVERY RARITY)"
end

-- one egg of every boss species (for testing star pens: Config.Island.Pens)
ACTIONS.GiveBossEggs = function(player)
	local n = 0
	for _, sp in ipairs(Config.Island.PenOrder) do
		local egg = Dinos.AddEgg(player, sp, "Rare", 0)
		if egg then egg.Dev = true n += 1 end
	end
	Data.Changed(player)
	return n .. " BOSS EGGS"
end

ACTIONS.FinishIncubators = function(player)
	local p = Data.Peek(player)
	for _, inc in ipairs(p.Incubators) do inc.Start = os.time() - inc.Duration - 1 end
	Plots.Sync(player)
	Data.Changed(player)
	return "ALL EGGS READY"
end

ACTIONS.MaxBase = function(player)
	local p = Data.Peek(player)
	p.Island = p.Island or { Hatchery = 1, Garage = 1, Pens = {} }
	p.Island.Hatchery, p.Island.Garage = #Config.Island.Hatchery, #Config.Island.Garage
	p.IncubatorCount = Config.IncubatorMax(p)
	p.PenSlots = Config.Pen.Max
	p.Gear.Rack = #Config.Rack.Prices
	p.Gear.BuddySlots = Config.BuddySlots.Max
	Plots.Sync(player)
	Data.Changed(player)
	return "BASE MAXED"
end

ACTIONS.GiveMaterials = function(player)
	local p = Data.Peek(player)
	for id in pairs(Config.Materials) do p.Materials[id] = (p.Materials[id] or 0) + 10 end
	for id in pairs(Config.Bosses) do p.Keys[id] = (p.Keys[id] or 0) + 3 end
	Data.Changed(player)
	return "+10 OF EVERY MATERIAL, +3 KEYS"
end

ACTIONS.UnlockEras = function(player)
	local p = Data.Peek(player)
	for _, e in ipairs(Config.Eras) do if e.Built then p.Unlocked[e.Id] = true end end
	Data.Changed(player)
	return "BUILT ERAS UNLOCKED"
end

ACTIONS.OpenBoss = function(player, args)
	-- the ruler of the era your Time Gate is set to (so WAKE RULER tests whichever era you're working on)
	local prof = Data.Peek(player)
	local era = prof and Config.Era(prof.Era or "")
	local id = Config.Bosses[args.Boss] and args.Boss or (era and era.Boss) or "TyrantKing"
	return Bosses.Open(id, tonumber(args.Tier) or 1, player) and (Config.Bosses[id].Name .. " IS AWAKE") or "ALREADY AWAKE"
end

ACTIONS.Reset = function(player)
	Expedition.Abort(player)
	Vehicles.Despawn(player)
	Data.Reset(player)
	Plots.Sync(player)
	Data.Changed(player)
	local cf = Plots.SpawnCFrame(player)
	if cf then teleport(player, cf) end
	Net.Fire(player, "ProgressReset", {})
	return "PROGRESS RESET"
end

ACTIONS.ReplayTutorial = function(player)
	local p = Data.Peek(player)
	p.Flags.Tutorial = 0
	p.Flags.Tips = {}
	p.Flags.SeenWarp = false
	Data.Changed(player)
	Net.Fire(player, "ReplayTutorial", {})
	return "TUTORIAL RESTARTED"
end

ACTIONS.Teleport = function(player, args)
	-- teleporting out of a run ends it properly (it used to leave you "at a site": combat mode at the hub)
	if Expedition.Get(player) then
		Expedition.Abort(player)
		Net.Fire(player, "WokeUp", {})
	end
	local where = args.Where
	local camp = Workspace:FindFirstChild("BaseCamp")
	if where == "Plot" then
		local cf = Plots.SpawnCFrame(player)
		if cf then teleport(player, cf) end
	elseif where == "Plaza" then
		local m = find(camp, "CampArrival")
		if m then teleport(player, m.CFrame) end
	elseif where == "Gate" then
		local m = find(camp, "GateArrival")
		if m then teleport(player, m.CFrame) end
	elseif where == "Showcase" then
		teleport(player, CFrame.new(-1034, 4, 480)) -- build.js SHOWCASE_SHIFT: its own pad out past the west rim
	else
		return "UNKNOWN PLACE"
	end
	Vehicles.Despawn(player)
	return "TELEPORTED"
end

ACTIONS.StartRun = function(player)
	if Expedition.Get(player) then return "ALREADY ON A RUN" end
	if not Vehicles.Get(player) then
		local camp = Workspace:FindFirstChild("BaseCamp")
		local m = find(camp, "GateArrival")
		Vehicles.Spawn(player, m and (m.CFrame * CFrame.new(0, 3, 0)) or nil)
		task.wait(0.6)
	end
	local p = Data.Peek(player)
	p.Unlocked[p.Era or "FernValley"] = true
	Expedition.Begin(player, p.Era or "FernValley")
	return "WARPING!"
end

ACTIONS.JumpTo = function(player, args)
	local s = tonumber(args.S) or 0
	return Expedition.DevJump(player, s) and "JUMPED" or "START A RUN FIRST"
end

ACTIONS.Refill = function(player)
	return Expedition.DevRefill(player) and "ARMOR + DARTS REFILLED" or "START A RUN FIRST"
end

ACTIONS.EndRun = function(player)
	local run = Expedition.Get(player)
	if not run then return "NOT ON A RUN" end
	if run.Phase == "Driving" or run.Phase == "OnFoot" then Expedition.Extract(run) return "EXTRACTING" end
	local r = Expedition.GoHome(player)
	return (r and r.Ok) and "GOING HOME" or "CAN'T END THE RUN FROM HERE"
end

-- run one Test Tools action on a player (the admin panel uses these on other players)
function DevTools.Run(player: Player, action: string, args: any?): string?
	local fn = ACTIONS[action]
	if not fn then return nil end
	return fn(player, args or {})
end

function DevTools.Start(deps)
	Data, Net, Plots, Vehicles, Dinos, Expedition, Bosses = deps.Data, deps.Net, deps.Plots, deps.Vehicles, deps.Dinos, deps.Expedition, deps.Bosses
	Net.On("Dev", function(player, args)
		if not DevTools.Allowed(player) then return { Ok = false, Err = "TEST TOOLS ARE FOR DEVELOPERS" } end
		local fn = ACTIONS[args.Action]
		if not fn or not Data.Peek(player) then return { Ok = false, Err = "UNKNOWN ACTION" } end
		local msg = fn(player, args)
		return { Ok = true, Message = msg }
	end)
	Net.On("IsDev", function(player) return { Ok = true, Dev = DevTools.Allowed(player) } end)
	Players.PlayerAdded:Connect(function(p) p:SetAttribute("Dev", DevTools.Allowed(p)) end)
	for _, p in ipairs(Players:GetPlayers()) do p:SetAttribute("Dev", DevTools.Allowed(p)) end
end

return DevTools
