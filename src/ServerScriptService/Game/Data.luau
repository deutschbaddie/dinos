--[[
	Data — player profiles in a DataStore. Loaded on join, autosaved, saved on leave and on shutdown.
	Studio without API access (or any DataStore outage) falls back to an in-memory profile that is
	never written, so a bad session can't wipe real progress.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Data = {}
Data.Profiles = {} :: { [Player]: any }
Data.Offline = {} :: { [Player]: boolean }
local loadedSignals = {} :: { [Player]: BindableEvent }
local changedHandlers = {}

local STORE_NAME = "DinoExpedition_Profiles_v2" -- v2: rarity eggs, inventory, gear, bosses (fresh saves)
-- the PRE-BETA test phase saves to its own store on live servers (launch starts everyone fresh); Studio never switches
local Testing = require(ReplicatedStorage.DinoExpedition.Game.Testing)
if Testing.Enabled and not game:GetService("RunService"):IsStudio() then STORE_NAME = Testing.SaveStore end
local AUTOSAVE = 90

local store: DataStore? = nil
do
	local ok, result = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
	if ok then store = result else warn("[Data] DataStore unavailable, progress will not save:", result) end
end

local function default()
	return {
		Version = Config.Version,
		Coins = 0, Earned = 0,
		Pending = 0, -- coins sitting on the cash pad
		-- eggs and dinos you own. Eggs: { Id, Species, Rarity }. Dinos: { Id, Species, Rarity, KG, Hatched }
		Eggs = {}, Dinos = {},
		RoverEggs = {}, -- eggs still strapped to your rover's roof rack (unload them at home)
		Placed = {}, -- dino ids roaming your yard (they earn)
		Buddies = {}, -- your companions (Gear.BuddySlots of them): yard dinos that follow you, ride along and fight
		Companion = "", -- (old single-companion field, folded into Buddies on load)
		Bond = {}, -- dino id -> bond xp (Config.Bond)
		Balls = 0, -- toy balls in your pocket (Config.Balls)
		Incubators = {}, -- { Slot, EggId, Species, Rarity, Start, Duration }
		IncubatorCount = Config.Incubator.Base, PenSlots = Config.Pen.Base,
		-- your island's buildings (Config.Island): tiers, and the star pens (lot -> { Species, Dino = dino id or "" })
		Island = { Hatchery = 1, Garage = 1, Pens = {} },
		Gear = {
			Launcher = "Rookie", Launchers = { Rookie = true }, LauncherLvl = 1,
			Armor = "None", Armors = { None = true }, ArmorLvl = 1,
			Vehicle = "RookieRanger", Vehicles = { RookieRanger = true }, RoverLvl = 1, Plating = false,
			Rack = 0, -- extra roof rack slots bought
			Gadgets = { "", "" }, GadgetsOwned = {},
			BuddySlots = Config.BuddySlots.Base,
		},
		Rides = {}, -- body -> build-your-own style (Rides.Default slots)
		RideOwned = {}, -- "Slot:Id" / "Color:Id" -> true (bought rover parts and paints)
		Materials = {}, -- material id -> count
		Keys = {}, -- boss id -> count
		Bosses = {}, -- boss id -> { Best = tier index cleared, Clears, BestTime }
		Stars = 0,
		Pity = 0,
		Index = {}, -- "Species:Rarity" -> true
		IndexRewards = { Claimed = {}, Title = "", EntriesMigrated = true }, -- the Index's claimed rewards ("Species/10", "Era/FernValley", "Secrets/<era>") + the title you wear (IndexDefs)
		Discover = {}, -- era -> secret id -> true (the Index's SECRETS page, Discover.luau)
		Showcase = "", -- the dino id on your SHOWCASE pedestal ("" = empty; Showcase.luau)
		Unlocked = { FernValley = true },
		Quests = { Story = 1, Active = {}, Progress = {}, Side = {} },
		Daily = { Last = 0, Streak = 0 },
		Stats = { Runs = 0, Eggs = 0, Wrecks = 0, Takedowns = 0, Escapes = 0, Bosses = 0, Hatched = 0, Playtime = 0 }, -- Playtime: seconds online (trading needs Config.Trade.MinPlaytime)
		Flags = { SeenWarp = false, Tutorial = 0, Tips = {}, Seen = {}, ColdOpenSeen = false }, -- ColdOpenSeen: watched the first cutscene (a reset wipes it)
		Settings = { Shake = true, SkipWarp = false, Hints = true, Music = true },
		Era = "FernValley",
		LastSeen = 0, -- os.time() of the last save (offline money counts from here)
		AwayRate = 0, -- the yard's coins/s at that save (offline money pays Config.Offline.Share of it)
	}
end
Data.Default = default

-- fill any missing keys from the default (old saves keep working when we add fields)
local function reconcile(p, d)
	for k, v in pairs(d) do
		if p[k] == nil then
			p[k] = typeof(v) == "table" and table.clone(v) or v
		elseif typeof(v) == "table" and typeof(p[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(p[k], v)
		end
	end
	return p
end

-- Studio without "Enable Studio Access to API Services": stop asking after the first refusal
Data.NoAccess = false
local function retry(fn, tries: number)
	local lastErr
	for i = 1, tries do
		if Data.NoAccess then return false, "Studio API access is off" end
		local ok, res = pcall(fn)
		if ok then return true, res end
		lastErr = res
		if tostring(res):find("Studio access") or tostring(res):find("StudioAccessToApisNotAllowed") then
			Data.NoAccess = true
			warn("[Data] Studio has no DataStore access (Game Settings > Security > Enable Studio Access to API Services). Using temporary profiles; nothing will save.")
			return false, res
		end
		task.wait(1.5 * i)
	end
	return false, lastErr
end

-- session lock: a profile is owned by one server at a time. without it, someone hopping servers fast could
-- have the old server's last save land after the new server's, wiping progress
local JOB = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))
local LOCK_STALE = 300 -- a lock this old belongs to a server that died without releasing it
local function lockedByOther(rec): boolean
	local lock = typeof(rec) == "table" and rec._Lock
	return typeof(lock) == "table" and lock.Id ~= JOB and os.time() - (tonumber(lock.T) or 0) < LOCK_STALE
end

-- offline money (2026-10-14): Config.Offline.Share of the yard's coins/s at the last save, for the time since it
-- (capped). Paid once, as the profile loads, straight into Coins - and LastSeen moves to now in the same table, so
-- the save that keeps these coins also keeps the new LastSeen (a crash before that save loses both: never twice).
-- Server clocks only (os.time()); a gap that runs backwards or is shorter than MinMinutes pays nothing.
Data.Away = {} :: { [Player]: any } -- this session's payout, for the client's WHILE YOU WERE AWAY card
local function payAway(player: Player, profile)
	local now = os.time()
	local last = tonumber(profile.LastSeen) or 0
	profile.LastSeen = now
	local cfg = Config.Offline
	if last <= 0 then return nil end -- first visit: nothing to pay
	local gap = now - last
	if gap < cfg.MinMinutes * 60 then return nil end
	local away = math.min(gap, cfg.MaxHours * 3600)
	local rate = tonumber(profile.AwayRate) or 0
	-- (saves from before AwayRate: work it out from the yard they left)
	if not (rate > 0) then
		local ok, r = pcall(function() return require(script.Parent.Dinos).Rate(profile, player, false, true) end)
		rate = ok and tonumber(r) or 0
	end
	if not (rate > 0 and rate < math.huge) then return nil end
	local coins = math.floor(rate * cfg.Share * away)
	if coins <= 0 then return nil end
	profile.Coins = (tonumber(profile.Coins) or 0) + coins
	profile.Earned = (tonumber(profile.Earned) or 0) + coins
	return { Seconds = away, Coins = coins, Capped = gap > away, Id = now }
end

-- playtime (2026-10-14): whole seconds online, added to Stats.Playtime as they pass (the remainder carries over)
local playMark = {} :: { [Player]: number }
local function tickPlaytime(player: Player)
	local profile, mark = Data.Profiles[player], playMark[player]
	if not (profile and mark and typeof(profile.Stats) == "table") then return end
	local secs = math.floor(os.clock() - mark)
	if secs <= 0 then return end
	playMark[player] = mark + secs
	profile.Stats.Playtime = (tonumber(profile.Stats.Playtime) or 0) + secs
end

-- total seconds online, up to this moment (trading's Config.Trade.MinPlaytime gate)
function Data.Playtime(player: Player): number
	tickPlaytime(player)
	local profile = Data.Profiles[player]
	return profile and typeof(profile.Stats) == "table" and tonumber(profile.Stats.Playtime) or 0
end

function Data.Load(player: Player)
	local key = "u" .. player.UserId
	local profile
	local away = nil
	if store then
		local ok, res
		for attempt = 1, 8 do
			local blocked = false
			ok, res = retry(function()
				return store:UpdateAsync(key, function(old)
					if lockedByOther(old) and attempt < 8 then blocked = true return nil end -- still held: don't write
					local rec = typeof(old) == "table" and old or {}
					rec._Lock = { Id = JOB, T = os.time() }
					return rec
				end)
			end, 3)
			if not ok or not blocked then break end
			-- the last server is still saving them out: wait for it to let go (last attempt takes over)
			task.wait(4)
			if not player.Parent then return nil end
		end
		if ok then
			local raw = typeof(res) == "table" and res or nil
			local fresh = raw == nil or next(raw) == nil or (next(raw) == "_Lock" and next(raw, "_Lock") == nil)
			-- saves from before the cold open had its own flag: anyone past the start has seen it
			if raw and typeof(raw.Flags) == "table" and raw.Flags.ColdOpenSeen == nil then
				raw.Flags.ColdOpenSeen = (tonumber(raw.Flags.Tutorial) or 0) > 0 or (typeof(raw.Stats) == "table" and (tonumber(raw.Stats.Runs) or 0) > 0)
			end
			profile = fresh and default() or reconcile(raw, default())
			profile._Lock = { Id = JOB, T = os.time() }
			-- the single companion (2026-10-12) became the companion list: it's the lead one
			if typeof(profile.Companion) == "string" and profile.Companion ~= "" then
				local i = table.find(profile.Buddies, profile.Companion)
				if i then table.remove(profile.Buddies, i) end
				table.insert(profile.Buddies, 1, profile.Companion)
				profile.Companion = ""
			end
			-- sea stars never live on land (2026-10-13): out of the yard, the best one into the island's sea pen
			pcall(function() require(script.Parent.Dinos).SettleMarine(profile, nil) end)
			-- rulers were renamed (2026-10-11): carry clears, keys and quest goals across to the new ids
			local RENAMED = { RaptorQueen = "TyrantKing", Matriarch = "Titan" }
			for old, new in pairs(RENAMED) do
				if profile.Bosses and profile.Bosses[old] then
					profile.Bosses[new] = profile.Bosses[new] or profile.Bosses[old]
					profile.Bosses[old] = nil
				end
				if profile.Keys and profile.Keys[old] then
					profile.Keys[new] = (profile.Keys[new] or 0) + profile.Keys[old]
					profile.Keys[old] = nil
				end
				for _, q in ipairs((profile.Quests and profile.Quests.Active) or {}) do
					if typeof(q) == "table" and typeof(q.Goal) == "table" and q.Goal.Boss == old then q.Goal.Boss = new end
				end
			end
			if not fresh then away = payAway(player, profile) end
			-- the Index's entry milestones became claimable rewards (2026-10-14): ones already paid count as claimed
			pcall(function() require(ReplicatedStorage.DinoExpedition.Game.IndexDefs).MigrateEntries(profile) end)
		else
			warn(`[Data] load failed for {player.Name}: {res} — playing with a temporary profile`)
			Data.Offline[player] = true
		end
	else
		Data.Offline[player] = true
	end
	profile = profile or default()
	if not player.Parent then
		-- they left while it loaded: nobody will save this profile, so let go of the session lock now (left in place it
		-- held their next join on another server in the loading wait for ~30 s)
		local wasOffline = Data.Offline[player] == true -- (a temporary profile never took the lock)
		Data.Offline[player] = nil
		if store and not wasOffline then
			local key2 = "u" .. player.UserId
			local st = store :: DataStore
			task.spawn(pcall, function()
				st:UpdateAsync(key2, function(old)
					-- (only ours, and only if they haven't rejoined this same server meanwhile: that session owns it now)
					if typeof(old) == "table" and typeof(old._Lock) == "table" and old._Lock.Id == JOB and not Players:GetPlayerByUserId(player.UserId) then
						old._Lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return nil
	end
	Data.Profiles[player] = profile
	Data.Away[player] = away
	playMark[player] = playMark[player] or os.clock()
	if loadedSignals[player] then loadedSignals[player]:Fire(profile) end
	return profile
end

function Data.Save(player: Player, final: boolean?)
	local profile = Data.Profiles[player]
	if not profile or Data.Offline[player] or not store then return false end
	tickPlaytime(player)
	profile.LastSeen = os.time()
	-- the yard's rate right now (with its gamepass): what offline money pays a share of if this is the last save
	-- (raw: a timed coin boost running at this save never pays out offline - Boosts.luau, 2026-10-14)
	pcall(function() profile.AwayRate = require(script.Parent.Dinos).Rate(profile, player, false, true) end)
	local key = "u" .. player.UserId
	local stolen = false
	local ok, err = retry(function()
		store:UpdateAsync(key, function(old)
			if lockedByOther(old) then stolen = true return nil end -- another server owns them now: never overwrite
			-- (a save that lands after they left - a trade's, an autosave's retry - never locks them again)
			profile._Lock = (not final and player.Parent ~= nil) and { Id = JOB, T = os.time() } or nil
			return profile
		end)
	end, final and 3 or 2)
	if not ok then warn(`[Data] save failed for {player.Name}: {err}`) end
	if stolen then warn(`[Data] {player.Name} is loaded on another server; skipped this save`) end
	return ok and not stolen -- (Monetization only grants a purchase once it is really saved)
end

-- yields until the profile is loaded (nil if the player left first)
function Data.Get(player: Player)
	local p = Data.Profiles[player]
	if p then return p end
	if not player.Parent then return nil end
	loadedSignals[player] = loadedSignals[player] or Instance.new("BindableEvent")
	local ev = loadedSignals[player]
	local result = nil
	local conn
	conn = ev.Event:Connect(function(prof) result = prof end)
	local t0 = os.clock()
	while not result and not Data.Profiles[player] and player.Parent and os.clock() - t0 < 30 do task.wait(0.1) end
	conn:Disconnect()
	return result or Data.Profiles[player]
end

function Data.Peek(player: Player)
	return Data.Profiles[player]
end

function Data.OnChanged(fn)
	table.insert(changedHandlers, fn)
end

-- call after mutating a profile: pushes the snapshot to the client + updates leaderstats
function Data.Changed(player: Player)
	local profile = Data.Profiles[player]
	if not profile then return end
	for _, fn in ipairs(changedHandlers) do task.spawn(fn, player, profile) end
end

function Data.Release(player: Player)
	Data.Profiles[player] = nil
	Data.Offline[player] = nil
	Data.Away[player] = nil
	playMark[player] = nil
	if loadedSignals[player] then loadedSignals[player]:Destroy() loadedSignals[player] = nil end
end

-- wipe a profile back to a brand-new player (developer reset)
function Data.Reset(player: Player)
	local fresh = default()
	Data.Profiles[player] = fresh
	return fresh
end

function Data.NewId(): string
	return HttpService:GenerateGUID(false):sub(1, 8)
end

function Data.Start()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for _, plr in ipairs(Players:GetPlayers()) do task.spawn(Data.Save, plr) end
		end
	end)
	-- playtime keeps ticking between saves (the client's snapshot and trading read it live)
	task.spawn(function()
		while true do
			task.wait(10)
			for plr in pairs(playMark) do tickPlaytime(plr) end
		end
	end)
	game:BindToClose(function()
		local threads = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			table.insert(threads, task.spawn(Data.Save, plr, true))
		end
		local t0 = os.clock()
		while os.clock() - t0 < 20 do
			local busy = false
			for _, th in ipairs(threads) do if coroutine.status(th) ~= "dead" then busy = true end end
			if not busy then break end
			task.wait(0.2)
		end
	end)
end

return Data
