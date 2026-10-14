--[[
	Boosts — the one place every multiplier comes from (2026-10-14 round 2). Config.Luck holds the numbers.

	  Boosts.Luck(player)        x luck (every source's luck multiplied, capped at Config.Luck.Max) - Dinos' rolls
	  Boosts.LuckAdd(player)     additive luck (the LUCK BOOST product, profile.LuckUntil - its shop odds stay exact)
	  Boosts.LuckFor(profile)    (add, mult) for a profile: what Dinos.RollRarity / PeekRarity use
	  Boosts.PowerMult(player)   x POWER / s on the trainer pad (+ its rewards)          - Trainer.luau
	  Boosts.CoinMult(player)    x yard income (live only: never offline money)          - Dinos.Rate
	  Boosts.AddSource(name, fn) other systems plug in: fn(player) -> nil (off) or
	                             { Luck?, Power?, Coins? (multipliers, 1.1 = +10%), LuckAdd?, Name?, Icon?, Color?,
	                               Ends? (os.time() it runs out), Quiet? (true: counts, but never shows the strip) }
	  Boosts.List(player)        what's active, for the HUD strip: { Id, Name, Icon, Color, Short, Effects, Ends?, Quiet? }
	  Boosts.Grant(player, id, minutes)   a saved timed boost (profile.Boosts[id] = os.time() it ends): "Team"
	  Boosts.StartLuckEvent(opts)         the server-wide 2x LUCK - a timer, Settings > ADMIN, or (later) a developer
	                                      product: Monetization would call Boosts.StartLuckEvent({ By = player.DisplayName,
	                                      Source = "Product" }) from its grant (no purchase is wired up yet)
	  Boosts.Coop(player, mates, coins)   a BOSS beaten together: coins, a power burst, TEAM LUCK (Bosses.luau)

	Built-in sources: the 2x LUCK event, FRIENDS in this server (Player:IsFriendsWith, cached, pcall'd), the LUCK BOOST
	product, TEAM LUCK after a co-op boss win.
	To the client: "Boosts" { List, Totals, T } to each player whenever their list changes (and on request), and
	"LuckEvent" { Ends, Mult, By?, Extended?, Minutes } to everyone when a 2x LUCK starts / grows / ends. The
	DinoExpedition folder carries LuckEventEnds / LuckEventMult attributes, so a late joiner sees the badge too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)

local Boosts = {}
local L = Config.Luck
local rng = Random.new()
local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")

type Entry = { Luck: number?, Power: number?, Coins: number?, LuckAdd: number?, Name: string?, Icon: string?, Color: string?, Ends: number?, Quiet: boolean? }
local sources = {} :: { { Name: string, Fn: (Player) -> any } }

local function num(v: any, lo: number, hi: number, default: number): number
	local n = tonumber(v)
	if not n or n ~= n then return default end
	return math.clamp(n, lo, hi)
end

-- a source plugs in (same name again = replaced, so a module that reloads never doubles up)
function Boosts.AddSource(name: string, fn: (Player) -> any)
	for i, s in ipairs(sources) do
		if s.Name == name then sources[i] = { Name = name, Fn = fn } return end
	end
	table.insert(sources, { Name = name, Fn = fn })
end

-- every active entry for this player (a source that errors is skipped, never the roll)
local function collect(player: Player?): { any }
	local out = {}
	for _, s in ipairs(sources) do
		local ok, e = pcall(s.Fn, player)
		if not ok then
			warn(`[Boosts] source {s.Name} failed: {e}`)
		elseif typeof(e) == "table" then
			local entry = {
				Id = s.Name,
				Luck = num(e.Luck, 1, 100, 1), Power = num(e.Power, 1, 100, 1), Coins = num(e.Coins, 1, 100, 1),
				LuckAdd = num(e.LuckAdd, 0, 5, 0),
				Name = typeof(e.Name) == "string" and e.Name or string.upper(s.Name),
				Icon = typeof(e.Icon) == "string" and e.Icon or "Star",
				Color = typeof(e.Color) == "string" and e.Color or "Lime",
				Ends = tonumber(e.Ends), Quiet = e.Quiet == true,
			}
			if entry.Luck > 1 or entry.Power > 1 or entry.Coins > 1 or entry.LuckAdd > 0 then table.insert(out, entry) end
		end
	end
	return out
end

local function totals(list: { any })
	local luck, power, coins, add = 1, 1, 1, 0
	for _, e in ipairs(list) do
		luck *= e.Luck
		power *= e.Power
		coins *= e.Coins
		add += e.LuckAdd
	end
	return math.min(luck, L.Max), math.min(power, L.PowerMax), math.min(coins, L.CoinMax), math.min(add, 3)
end

function Boosts.Luck(player: Player?): number
	local m = totals(collect(player))
	return m
end
function Boosts.LuckAdd(player: Player?): number
	local _, _, _, a = totals(collect(player))
	return a
end
function Boosts.PowerMult(player: Player): number
	local _, p = totals(collect(player))
	return p
end
function Boosts.CoinMult(player: Player): number
	local _, _, c = totals(collect(player))
	return c
end

-- (add, mult) for a profile's rolls: its player's boosts (the server-wide ones if it has none)
function Boosts.LuckFor(profile: any): (number, number)
	local owner = nil
	if profile then
		for plr, p in pairs(Data.Profiles) do
			if p == profile then owner = plr break end
		end
	end
	local m, _, _, a = totals(collect(owner))
	return a, m
end

--------------------------------------------------------------------------------
-- the strip's list
--------------------------------------------------------------------------------
-- 1.2 -> "+20%", 2 -> "2x", 2.34 -> "2.3x"
local function fmt(m: number): string
	if m >= 1.995 then
		local s = string.format("%.1f", m):gsub("%.0$", "")
		return s .. "x"
	end
	return "+" .. math.floor((m - 1) * 100 + 0.5) .. "%"
end
Boosts.Format = fmt

function Boosts.List(player: Player): ({ any }, any)
	local list = collect(player)
	local out = {}
	for _, e in ipairs(list) do
		local luck = e.LuckAdd > 0 and Config.LuckShow(e.LuckAdd, e.Luck) or e.Luck
		local effects = {}
		if luck > 1.001 then table.insert(effects, "LUCK " .. fmt(luck)) end
		if e.Power > 1.001 then table.insert(effects, "POWER " .. fmt(e.Power)) end
		if e.Coins > 1.001 then table.insert(effects, "COINS " .. fmt(e.Coins)) end
		-- the chip's one number: the biggest thing it does
		local big = math.max(luck, e.Power, e.Coins)
		table.insert(out, { Id = e.Id, Name = e.Name, Icon = e.Icon, Color = e.Color, Short = fmt(big), Effects = effects, Ends = e.Ends, Quiet = e.Quiet })
	end
	-- the event first, then whatever runs out soonest, then the lasting ones
	table.sort(out, function(a, b)
		if (a.Id == "Event") ~= (b.Id == "Event") then return a.Id == "Event" end
		local ea, eb = a.Ends or math.huge, b.Ends or math.huge
		if ea ~= eb then return ea < eb end
		return a.Id < b.Id
	end)
	local m, p, c, a = totals(list)
	return out, { Luck = Config.LuckShow(a, m), Power = p, Coins = c, LuckMax = L.Max }
end

--------------------------------------------------------------------------------
-- saved timed boosts (profile.Boosts: id -> os.time() it ends)
--------------------------------------------------------------------------------
local function timed(profile, id: string): number
	local b = profile and profile.Boosts
	local t = typeof(b) == "table" and tonumber(b[id]) or 0
	return (t and t > os.time()) and t or 0
end

local push -- (below)
function Boosts.Grant(player: Player, id: string, minutes: number)
	local profile = Data.Peek(player)
	if not profile then return end
	if typeof(profile.Boosts) ~= "table" then profile.Boosts = {} end
	-- (a second grant tops it back up to full; it never stacks past one go)
	profile.Boosts[id] = math.max(timed(profile, id), os.time() + math.floor(minutes * 60))
	push(player)
end

--------------------------------------------------------------------------------
-- 2x LUCK events
--------------------------------------------------------------------------------
local event = { Ends = 0, Started = 0 }
local nextAt = 0 -- os.time() of the next timed event

local function eventOn(): boolean
	return event.Ends > os.time()
end

local function pushAll()
	for _, p in ipairs(Players:GetPlayers()) do push(p) end
end

-- opts: Minutes? (default Config.Luck.Event.Minutes), By? (a name for the banner: "SICKLEEDGE STARTED 2x LUCK!"),
-- Source? ("Timer" / "Admin" / "Product"). Returns ok, message.
function Boosts.StartLuckEvent(opts: any?): (boolean, string)
	local o = typeof(opts) == "table" and opts or {}
	local cfg = L.Event
	local now = os.time()
	local mins = math.floor(num(o.Minutes, 1, cfg.MaxMinutes, cfg.Minutes))
	local extended = eventOn()
	if extended then
		if event.Ends - now >= cfg.MaxMinutes * 60 - 30 then return false, "2x LUCK IS ALREADY AT ITS LONGEST" end
		event.Ends = math.min(event.Ends + mins * 60, now + cfg.MaxMinutes * 60)
	else
		event.Ends = now + mins * 60
		event.Started = now
	end
	-- the timer counts from this start (an admin's event doesn't get a timed one stacked right after it)
	nextAt = now + rng:NextInteger(cfg.Every[1], cfg.Every[2]) * 60
	Shared:SetAttribute("LuckEventEnds", event.Ends)
	Shared:SetAttribute("LuckEventMult", cfg.Mult)
	local by = typeof(o.By) == "string" and string.upper(o.By):sub(1, 20) or nil
	Net.FireAll("LuckEvent", { Ends = event.Ends, Mult = cfg.Mult, By = by, Extended = extended, Minutes = mins, T = now })
	pushAll()
	print(`[Boosts] 2x LUCK {extended and "extended" or "started"} ({o.Source or "?"}{by and (", " .. by) or ""}): ends in {event.Ends - now}s`)
	local left = event.Ends - now
	return true, string.format("2x LUCK: %d:%02d LEFT", left // 60, left % 60)
end

local function endEvent()
	event.Ends = 0
	Shared:SetAttribute("LuckEventEnds", nil)
	Shared:SetAttribute("LuckEventMult", nil)
	Net.FireAll("LuckEvent", { Ends = 0, Ended = true, T = os.time() })
	pushAll()
end

--------------------------------------------------------------------------------
-- friends in this server
--------------------------------------------------------------------------------
local friendPair = {} :: { [string]: boolean } -- "lowId:highId" -> friends?
local friendCount = {} :: { [Player]: number }

local function pairKey(a: number, b: number): string
	return a < b and (a .. ":" .. b) or (b .. ":" .. a)
end

local function recount()
	for _, p in ipairs(Players:GetPlayers()) do
		local n = 0
		for _, q in ipairs(Players:GetPlayers()) do
			if q ~= p and friendPair[pairKey(p.UserId, q.UserId)] then n += 1 end
		end
		if friendCount[p] ~= n then
			friendCount[p] = n
			push(p)
		end
	end
end

-- (IsFriendsWith is a web call: it can fail or be slow - once more later, then we let it be)
local function check(p: Player, q: Player)
	local key = pairKey(p.UserId, q.UserId)
	if friendPair[key] ~= nil or p.UserId <= 0 or q.UserId <= 0 then return end -- (Studio test players are never friends)
	for attempt = 1, 2 do
		local ok, res = pcall(function() return p:IsFriendsWith(q.UserId) end)
		if ok then
			friendPair[key] = res == true
			if res == true then recount() end
			return
		end
		if attempt == 1 then task.wait(10) end
		if not (p.Parent and q.Parent) then return end
	end
end

local function onJoin(p: Player)
	friendCount[p] = 0
	for _, q in ipairs(Players:GetPlayers()) do
		if q ~= p then task.spawn(check, p, q) end
	end
end

local function onLeave(p: Player)
	friendCount[p] = nil
	for key in pairs(friendPair) do
		local a, b = key:match("^(%-?%d+):(%-?%d+)$")
		if tonumber(a) == p.UserId or tonumber(b) == p.UserId then friendPair[key] = nil end
	end
	recount()
end

function Boosts.Friends(player: Player): number
	return friendCount[player] or 0
end

--------------------------------------------------------------------------------
-- co-op boss wins
--------------------------------------------------------------------------------
-- mates: how many OTHER winners there were. coins: this winner's boss coins. Pays the power burst and the team luck
-- here; returns { Mates, Coins (the extra, for the caller to pay with the rest), Power, Luck, Minutes } or nil solo.
function Boosts.Coop(player: Player, mates: number, coins: number): any
	local c = L.Coop
	local m = math.min(math.floor(tonumber(mates) or 0), c.MaxMates)
	if m < 1 or not Data.Peek(player) then return nil end
	local extra = math.floor(math.max(0, tonumber(coins) or 0) * c.Coins * m)
	local power = 0
	pcall(function()
		local Trainer = require(script.Parent.Trainer) :: any
		power = Trainer.AddPower(player, Trainer.PerSec(player) * c.PowerSecs * m, "TeamBonus") or 0
	end)
	Boosts.Grant(player, "Team", c.Minutes)
	return { Mates = math.floor(mates), Coins = extra, Power = power, Luck = c.Luck, Minutes = c.Minutes, Pct = math.floor(c.Coins * m * 100 + 0.5) }
end

--------------------------------------------------------------------------------
-- pushing the list to each player
--------------------------------------------------------------------------------
local sent = {} :: { [Player]: string }
local function signature(list: { any }, tot): string
	local parts = {}
	for _, e in ipairs(list) do table.insert(parts, e.Id .. "=" .. e.Short .. "@" .. tostring(e.Ends or "")) end
	return table.concat(parts, "|") .. "#" .. string.format("%.2f/%.2f/%.2f", tot.Luck, tot.Power, tot.Coins)
end
push = function(player: Player, force: boolean?)
	if not player.Parent or not Data.Peek(player) then return end
	local ok, list, tot = pcall(Boosts.List, player)
	if not ok then warn("[Boosts] list failed: " .. tostring(list)) return end
	local sig = signature(list, tot)
	if sig == sent[player] and not force then return end
	local coinsChanged = sent[player] ~= nil and (sent[player]:match("/[%d%.]+$") ~= sig:match("/[%d%.]+$"))
	sent[player] = sig
	Net.Fire(player, "Boosts", { List = list, Totals = tot, T = os.time() })
	-- (the yard's +/s in the profile snapshot includes coin boosts: refresh it when they change)
	if coinsChanged then Data.Changed(player) end
end
Boosts.Push = push

--------------------------------------------------------------------------------
-- the built-in sources
--------------------------------------------------------------------------------
Boosts.AddSource("Event", function()
	if not eventOn() then return nil end
	return { Luck = L.Event.Mult, Name = L.Event.Mult .. "x LUCK EVENT", Icon = "Star", Color = "Yellow", Ends = event.Ends }
end)
Boosts.AddSource("Friends", function(player)
	local n = player and math.min(friendCount[player] or 0, L.Friend.Max) or 0
	if n <= 0 then return nil end
	return { Luck = 1 + L.Friend.Luck * n, Power = 1 + L.Friend.Power * n, Name = n == 1 and "1 FRIEND HERE" or (n .. " FRIENDS HERE"), Icon = "Buddy", Color = "Teal" }
end)
Boosts.AddSource("LuckBoost", function(player)
	local profile = player and Data.Peek(player)
	local untilT = profile and tonumber(profile.LuckUntil) or 0
	if not (untilT and untilT > os.time()) then return nil end
	return { LuckAdd = L.Potion.Add, Name = "LUCK BOOST", Icon = "Star", Color = "Orange", Ends = untilT }
end)
Boosts.AddSource("Team", function(player)
	local t = player and timed(Data.Peek(player), "Team") or 0
	if t <= 0 then return nil end
	return { Luck = L.Coop.Luck, Name = "TEAM LUCK", Icon = "Trophy", Color = "Purple", Ends = t }
end)

--------------------------------------------------------------------------------
function Boosts.Start(_deps)
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function(p)
		onLeave(p)
		sent[p] = nil
	end)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end
	Net.On("Boosts", function(player)
		local ok, list, tot = pcall(Boosts.List, player)
		if not ok then return { Ok = false } end
		sent[player] = signature(list, tot)
		return { Ok = true, List = list, Totals = tot, T = os.time(), Event = eventOn() and { Ends = event.Ends, Mult = L.Event.Mult } or nil }
	end)
	-- the 2x LUCK timer, plus each list kept fresh (timed boosts start and run out on their own)
	nextAt = os.time() + rng:NextInteger(L.Event.FirstAfter[1], L.Event.FirstAfter[2]) * 60
	task.spawn(function()
		local wasOn = false
		while true do
			task.wait(2)
			local ok, err = pcall(function()
				local now = os.time()
				if wasOn and not eventOn() then endEvent() end
				if not eventOn() and now >= nextAt then
					-- (an empty server waits for someone to be there)
					if #Players:GetPlayers() > 0 then Boosts.StartLuckEvent({ Source = "Timer" }) else nextAt = now + 60 end
				end
				wasOn = eventOn()
				for _, p in ipairs(Players:GetPlayers()) do push(p) end
			end)
			if not ok then warn("[Boosts] tick failed: " .. tostring(err)) end
		end
	end)
end

return Boosts
