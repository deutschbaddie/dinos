--[[
	Trainer — the POWER TRAINER on every island (2026-10-14: it replaced launcher levels).

	  stand on your trainer's glowing pad   -> +PerSec POWER every second (checked here, on the server)
	  TrainerUpgrade                        -> coins buy the next level (more POWER / s; every 4th level a bigger
	                                           machine, gated by that era's boss: Config.TrainerGate)
	  TrainerCraft / TrainerEquip           -> boss launchers are crafted and swapped at the trainer now (Shop does
	                                           the work, so the rules - tier order, costs, quests - stay in one place)
	  fights pay POWER too                  -> Trainer.Reward(player, "Takedown" | "Escape" | "Boss")
	  minigames (the dino quiz)             -> Trainer.AddPower(player, amount, reason), Trainer.PerSec(player)

	profile.Trainer = { Level }, profile.TrainPower = the POWER trained so far (Config.PowerOf adds gear + companions).
	The plot attribute "TrainerLevel" tells IslandView which machine to stand on the island (and every client the
	level for the board). The player attribute "Training" is set while someone trains (their pad FX, for everyone).
	Fires "TrainTick" { Gain, TrainPower, Power, Reason? } to the owner: once a second on the pad, and on rewards.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Trainer = {}
local Data, Net, Plots, Dinos, Expedition, Shop
local T = Config.Trainer

local onPad = {} :: { [Player]: number } -- seconds in a row on the pad
local plotOf = {} :: { [Player]: Model } -- (kept so the island can go back to tier 1 after Plots.Release)
local PUSH_EVERY = 10 -- while training, a full profile push this often (the popups are live every second)

--------------------------------------------------------------------------------
-- profile fields + migration of pre-trainer saves
--------------------------------------------------------------------------------
-- (2026-10-14) a save from before the trainer had launcher LEVELS. They become TrainPower and a trainer level so
-- nobody comes back weaker: the POWER a regular player has trained when that launcher tier is new (BASE, by
-- launcher order), plus 70% of the way to the next tier's for the levels they'd bought on it; the trainer level is
-- that tier's first level plus one per three launcher levels, never past a tier gate they haven't beaten.
local BASE = { 0, 1500, 7000, 40000, 190000, 950000, 4600000, 23000000 }
local function beaten(profile, bossId: string): boolean
	local rec = profile.Bosses and profile.Bosses[bossId]
	return typeof(rec) == "table" and (tonumber(rec.Best) or 0) >= 1
end
local function maxAllowed(profile): number
	local top = 1
	for lvl = 2, #T.Levels do
		local gate = Config.TrainerGate(lvl)
		if gate and not beaten(profile, gate) then break end
		top = lvl
	end
	return top
end
local function ensure(profile)
	if typeof(profile.Trainer) ~= "table" then profile.Trainer = { Level = 1 } end
	profile.Trainer.Level = Config.TrainerLevel(profile)
	local tp = tonumber(profile.TrainPower) or 0
	if tp ~= tp or tp < 0 or tp == math.huge then tp = 0 end
	profile.TrainPower = tp
	profile.Flags = profile.Flags or {}
	if profile.Flags.PowerV2 then return end
	profile.Flags.PowerV2 = true
	local g = profile.Gear
	if typeof(g) ~= "table" then return end
	local l = Config.Launchers[g.Launcher or ""] or Config.Launchers.Rookie
	local order = l.Order or 1
	local lvl = math.clamp(math.floor(tonumber(g.LauncherLvl) or 1), 1, Config.MaxLevel)
	local base, nxt = BASE[order] or 0, BASE[order + 1] or (BASE[order] or 0) * 5
	local gained = base + (lvl - 1) / (Config.MaxLevel - 1) * 0.7 * (nxt - base)
	if gained > profile.TrainPower then profile.TrainPower = math.floor(gained) end
	local level = math.min(T.PerTier * (order - 1) + 1 + (lvl - 1) // 3, T.PerTier * order, maxAllowed(profile))
	if level > profile.Trainer.Level then profile.Trainer.Level = level end
	if lvl > 1 then profile.Flags.OldLauncherLvl = lvl end
	g.LauncherLvl = 1
end
Trainer.Ensure = ensure

local function levelOf(profile): number
	return Config.TrainerLevel(profile)
end

function Trainer.PerSec(player: Player): number
	local profile = Data.Peek(player)
	return profile and Config.TrainerPerSec(levelOf(profile)) or 0
end

-- POWER boosts from the Boosts module (luck / friend / event sources, 2026-10-14 round 2), if it's there: x1 without it
local function boostOf(player: Player): number
	local mod = script.Parent:FindFirstChild("Boosts")
	if not mod then return 1 end
	local ok, m = pcall(function() return (require(mod :: ModuleScript) :: any).PowerMult(player) end)
	m = ok and tonumber(m) or 1
	return (m == m and m > 0 and m < 100) and m or 1
end

local function powerOf(profile): number
	return Config.PowerOf(profile, Dinos.BuddyList(profile))
end

local function setLeaderstat(player: Player, profile)
	local ls = player:FindFirstChild("leaderstats")
	local pw = ls and ls:FindFirstChild("Power")
	if pw and pw:IsA("IntValue") then pw.Value = math.min(powerOf(profile), 2 ^ 53) end
end

local function syncPlot(player: Player, profile)
	local plot = Plots.Get(player)
	if not plot then return end
	plotOf[player] = plot
	local lvl = levelOf(profile)
	if plot:GetAttribute("TrainerLevel") ~= lvl then plot:SetAttribute("TrainerLevel", lvl) end
end

--------------------------------------------------------------------------------
-- power from anything but the pad
--------------------------------------------------------------------------------
-- (for minigames, rewards and admin tools) adds POWER, never more than an hour of your trainer's rate in one go.
-- Returns what was really added.
function Trainer.AddPower(player: Player, amount: number, reason: string?): number
	local profile = Data.Peek(player)
	if not profile then return 0 end
	ensure(profile)
	local n = tonumber(amount) or 0
	if n ~= n or n <= 0 or n == math.huge then return 0 end
	local cap = Config.TrainerPerSec(levelOf(profile)) * 3600
	if n > cap then
		warn(`[Trainer] AddPower capped for {player.Name}: {n} -> {cap} ({reason or "?"})`)
		n = cap
	end
	n = math.floor(n)
	if n <= 0 then return 0 end
	profile.TrainPower += n
	Net.Fire(player, "TrainTick", { Gain = n, TrainPower = profile.TrainPower, Power = powerOf(profile), Reason = reason or "Bonus" })
	setLeaderstat(player, profile)
	Data.Changed(player)
	return n
end

-- a fight's POWER: your trainer's rate x Config.Trainer.Rewards[kind] seconds (x mult, e.g. a boss tier's Power)
function Trainer.Reward(player: Player, kind: string, mult: number?): number
	local secs = T.Rewards[kind]
	if not secs then return 0 end
	return Trainer.AddPower(player, Trainer.PerSec(player) * secs * math.clamp(tonumber(mult) or 1, 0, 3) * boostOf(player), kind)
end

--------------------------------------------------------------------------------
-- upgrades + launchers
--------------------------------------------------------------------------------
local function upgrade(player: Player)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	ensure(profile)
	local lvl = levelOf(profile)
	local nxt = lvl + 1
	local def = T.Levels[nxt]
	if not def then return { Ok = false, Err = "YOUR TRAINER IS MAXED!" } end
	local gate = Config.TrainerGate(nxt)
	if gate and not beaten(profile, gate) then
		local b = Config.Bosses[gate]
		return { Ok = false, Err = "BEAT THE " .. (b and b.Name or "BOSS") .. " TO BUILD THE " .. (T.TierNames[Config.TrainerTier(nxt)] or "NEXT MACHINE"), Gate = gate }
	end
	local cost = def.Cost
	-- the first upgrade is free once you've been on an expedition (the same free first upgrade the Armorer gives)
	local free = T.FirstFree and not profile.Flags.FreeUpgradeUsed and (tonumber(profile.Stats and profile.Stats.Runs) or 0) >= 1
	if free then cost = 0 end
	if profile.Coins < cost then return { Ok = false, Err = "NOT ENOUGH COINS" } end
	profile.Coins -= cost
	profile.Trainer.Level = nxt
	if free then profile.Flags.FreeUpgradeUsed = true end
	local newTier = Config.TrainerTier(nxt) ~= Config.TrainerTier(lvl)
	syncPlot(player, profile)
	setLeaderstat(player, profile)
	Data.Changed(player)
	if newTier then
		Net.FireAll("Announce", { Text = string.format("%s BUILT A %s!", string.upper(player.DisplayName), T.TierNames[Config.TrainerTier(nxt)] or "NEW TRAINER"), Color = "Orange" })
	end
	return { Ok = true, Level = nxt, Tier = Config.TrainerTier(nxt), NewTier = newTier, PerSec = def.PerSec, Free = free }
end

--------------------------------------------------------------------------------
-- the pad
--------------------------------------------------------------------------------
local function padOf(player: Player): BasePart?
	local plot = Plots.Get(player)
	local kit = plot and plot:FindFirstChild("IslandKit")
	if not kit then return nil end
	for _, m in ipairs(kit:GetChildren()) do
		if m:IsA("Model") and m.Name:match("^Trainer%d+$") then
			local pad = m:FindFirstChild("TrainerPad", true)
			if pad and pad:IsA("BasePart") then return pad end
		end
	end
	return nil
end
Trainer.PadOf = padOf

local function standingOn(player: Player, pad: BasePart): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 or hum.SeatPart ~= nil then return false end
	if Expedition.Get(player) or Expedition.InRun(player) then return false end
	local d = hrp.Position - pad.Position
	return Vector3.new(d.X, 0, d.Z).Magnitude <= T.PadRadius and d.Y > -1 and d.Y < T.PadHeight
end

-- standing on your own trainer pad right now (the quiz pays only there)
function Trainer.OnPad(player: Player): boolean
	local pad = padOf(player)
	return pad ~= nil and standingOn(player, pad :: BasePart)
end

local function tick()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = Data.Peek(player)
		if not profile then continue end
		local pad = padOf(player)
		local on = pad ~= nil and standingOn(player, pad :: BasePart)
		if on then
			ensure(profile)
			local gain = math.floor(Config.TrainerPerSec(levelOf(profile)) * boostOf(player) + 0.5)
			profile.TrainPower += gain
			local n = (onPad[player] or 0) + 1
			onPad[player] = n
			if not player:GetAttribute("Training") then player:SetAttribute("Training", true) end
			Net.Fire(player, "TrainTick", { Gain = gain, TrainPower = profile.TrainPower, Power = powerOf(profile) })
			setLeaderstat(player, profile)
			if n % PUSH_EVERY == 0 then Data.Changed(player) end
		elseif onPad[player] then
			onPad[player] = nil
			player:SetAttribute("Training", nil)
			Data.Changed(player)
		end
	end
end

function Trainer.Start(deps)
	Data, Net, Plots, Dinos, Expedition, Shop = deps.Data, deps.Net, deps.Plots, deps.Dinos, deps.Expedition, deps.Shop
	-- every profile push: fields in place (and an old save migrated, before the snapshot that follows goes out),
	-- the island's machine kept in step
	Data.OnChanged(function(player, profile)
		ensure(profile)
		syncPlot(player, profile)
	end)
	Net.On("TrainerUpgrade", function(player) return upgrade(player) end)
	Net.On("TrainerCraft", function(player, args)
		if typeof(args.Id) ~= "string" or not Config.Launchers[args.Id] then return { Ok = false } end
		return Shop.Craft(player, "Launcher", args.Id)
	end)
	Net.On("TrainerEquip", function(player, args)
		if typeof(args.Id) ~= "string" or not Config.Launchers[args.Id] then return { Ok = false } end
		return Shop.Equip(player, "Launcher", args.Id)
	end)
	Players.PlayerRemoving:Connect(function(player)
		onPad[player] = nil
		local plot = plotOf[player]
		plotOf[player] = nil
		-- (Plots.Release ran first or runs next; a freed island shows the first machine again)
		if plot then
			local owner = plot:GetAttribute("Owner")
			if owner == 0 or owner == player.UserId then plot:SetAttribute("TrainerLevel", nil) end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then warn("[Trainer] tick failed:", err) end
		end
	end)
end

return Trainer
