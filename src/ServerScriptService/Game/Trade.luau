--[[
	Trade — player-to-player trading of DINOS and EGGS (2026-10-14). It's opened from another player's VIEW PROFILE
	card (client: Game/TradeView.luau). Kids use it and scammers target it, so the server decides everything:

	  request -> accept   TradeRequest / TradeAnswer. A request expires after Config.Trade.RequestTime. A decline or no
	                      answer puts that pair on cooldown, and each player has one outgoing and one incoming request at most.
	                      You can't trade with yourself, or with anyone trading, on a run or in a fight. Both players need
	                      Config.Trade.MinPlaytime of total playtime (profile.Stats.Playtime, nil = 0).
	  the window          TradeSetOffer replaces your whole side (Config.Trade.MaxItems at most, only your own tradable
	                      dinos / bag eggs). ANY change to either side bumps the Version and clears BOTH players' READY and
	                      CONFIRM.
	  READY x2            starts a Config.Trade.Countdown countdown. Any change, or an un-ready, cancels it.
	  CONFIRM x2          executes. READY and CONFIRM carry the Version the client was looking at, and a stale one is
	                      refused: nobody can confirm an offer that changed under them.
	  execute             checks every item again (still owned, not a companion / star pen / nest / rack, both bags have
	                      room, no id clash), then moves it all in one step with no yields: all or nothing. Records keep
	                      their id, rarity, KG and bond. Both profiles save straight away, each keeps a TradeLog (last
	                      Config.Trade.LogSize) and the server prints a log line.

	While a trade is open the player has attribute Trading, so Dinos refuses hatch / sell / place / unload / incubate.
	The trade closes itself if either player leaves, heads out on a run, joins a fight, or it's open too long. An
	offered item that changes some other way (lost on a run, moved into a star pen...) drops out of the offer and
	READY resets.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Trade = {}
local Data, Net, Dinos, Plots, Expedition
local T = Config.Trade

local requests = {} :: { [number]: any } -- request id -> { Id, From, To, Expires }
local outgoing = {} :: { [Player]: any }
local incoming = {} :: { [Player]: any }
local lastAsk = {} :: { [Player]: number }
local pairCool = {} :: { [string]: number } -- "fromUserId:toUserId" -> os.clock() it's allowed again
local sessions = {} :: { [Player]: any }
local nextReq = 0

local function findIn(list, id: string)
	for i, v in ipairs(list or {}) do if v.Id == id then return v, i end end
	return nil, nil
end

-- records are flat today; a deep copy means nothing is ever shared between two profiles
local function copy(v: any): any
	if typeof(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = copy(x) end
	return out
end

local function upper(p: Player): string
	return string.upper(p.DisplayName)
end

--------------------------------------------------------------------------------
-- who can trade
--------------------------------------------------------------------------------
-- seconds of playtime still needed. Data.Playtime counts up to this moment (this session included); the saved
-- profile.Stats.Playtime is the fallback (nil = 0)
local function playtimeLeft(player: Player, profile): number
	if T.StudioBypass and RunService:IsStudio() then return 0 end
	local played = 0
	if typeof(Data.Playtime) == "function" then
		played = tonumber(Data.Playtime(player)) or 0
	else
		local st = profile and profile.Stats
		played = (typeof(st) == "table" and tonumber(st.Playtime)) or 0
	end
	return math.max(0, T.MinPlaytime - played)
end
Trade.PlaytimeLeft = playtimeLeft

local function busyReason(plr: Player): string?
	if Expedition and Expedition.InRun(plr) then return "ON AN EXPEDITION" end
	if plr:GetAttribute("Site") ~= nil or plr:GetAttribute("Downed") then return "IN A FIGHT" end
	if plr:GetAttribute("AdminFrozen") then return "BUSY" end
	return nil
end

local function near(a: Player, b: Player): boolean
	local ra = a.Character and a.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rb = b.Character and b.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return ra ~= nil and rb ~= nil and (ra.Position - rb.Position).Magnitude <= T.Range
end

-- nil = these two may trade; else why not (worded for `a`)
local function check(a: Player, b: Player): string?
	if a == b then return "YOU CAN'T TRADE WITH YOURSELF" end
	if not b.Parent then return "THEY LEFT" end
	local pa, pb = Data.Peek(a), Data.Peek(b)
	if not pa then return "STILL LOADING YOUR SAVE" end
	if not pb then return "THEY'RE STILL LOADING" end
	-- a temporary profile (saves were down when they joined) never trades with a real one: what it got would vanish
	if (Data.Offline[a] == true) ~= (Data.Offline[b] == true) then return "SAVES ARE DOWN RIGHT NOW - TRY AGAIN LATER" end
	local mins = math.floor(T.MinPlaytime / 60)
	local left = playtimeLeft(a, pa)
	if left > 0 then return `TRADING UNLOCKS AFTER {mins} MIN OF PLAY ({math.ceil(left / 60)} MIN TO GO)` end
	if playtimeLeft(b, pb) > 0 then return `{upper(b)} CAN'T TRADE YET (NEEDS {mins} MIN OF PLAY)` end
	if sessions[a] then return "YOU'RE ALREADY IN A TRADE" end
	if sessions[b] then return `{upper(b)} IS ALREADY TRADING` end
	local why = busyReason(a)
	if why then return "NOT WHILE YOU'RE " .. why end
	why = busyReason(b)
	if why then return `{upper(b)} IS {why}` end
	return nil
end

--------------------------------------------------------------------------------
-- the window's state, as each side sees it
--------------------------------------------------------------------------------
local function itemView(profile, it)
	local rec = findIn(it.Kind == "Dino" and profile.Dinos or profile.Eggs, it.Id)
	if not rec then return nil end
	return {
		Kind = it.Kind, Id = it.Id, Species = rec.Species, Rarity = rec.Rarity, KG = rec.KG, Name = rec.Name, -- (Name: a named dino's filtered name)
		Bond = it.Kind == "Dino" and Dinos.BondLevel(profile, it.Id) or nil,
	}
end

local function sideView(s, p: Player)
	local profile = Data.Peek(p)
	local items = {}
	for _, it in ipairs(s.Offer[p] or {}) do
		local v = profile and itemView(profile, it)
		if v then table.insert(items, v) end
	end
	return { UserId = p.UserId, Name = p.DisplayName, Items = items, Ready = s.Ready[p] == true, Confirm = s.Confirm[p] == true }
end

local function view(s, v: Player)
	local other = s.A == v and s.B or s.A
	return {
		Id = s.Id, Phase = s.Phase, Version = s.Version,
		CountLeft = s.CountEnd and math.max(0, s.CountEnd - os.clock()) or nil,
		Me = sideView(s, v), Them = sideView(s, other),
		Changed = s.ChangedBy and (s.ChangedBy == v and "Me" or "Them") or nil,
		Max = T.MaxItems,
	}
end

local function broadcast(s)
	if s.Closed then return end
	Net.Fire(s.A, "TradeState", view(s, s.A))
	Net.Fire(s.B, "TradeState", view(s, s.B))
	s.ChangedBy = nil
end

-- either offer changed: both READY and CONFIRM clear, the countdown stops, the Version moves on
local function changed(s, by: Player?)
	s.Version += 1
	table.clear(s.Ready)
	table.clear(s.Confirm)
	s.Phase = "Offer"
	s.CountEnd, s.CountToken = nil, nil
	s.ChangedBy = by
	broadcast(s)
end

-- textFor(p) = what that player is told
local function close(s, textFor: (Player) -> string?)
	if s.Closed then return end
	s.Closed = true
	s.CountToken = nil
	if sessions[s.A] == s then sessions[s.A] = nil end
	if sessions[s.B] == s then sessions[s.B] = nil end
	for _, p in ipairs({ s.A, s.B }) do
		if p.Parent then
			p:SetAttribute("Trading", nil)
			Net.Fire(p, "TradeClosed", { Id = s.Id, Text = textFor(p) })
		end
	end
end

--------------------------------------------------------------------------------
-- requests
--------------------------------------------------------------------------------
local function dropRequest(req, why: string)
	if requests[req.Id] ~= req then return end
	requests[req.Id] = nil
	if outgoing[req.From] == req then outgoing[req.From] = nil end
	if incoming[req.To] == req then incoming[req.To] = nil end
	if req.To.Parent then Net.Fire(req.To, "TradeRequestGone", { Id = req.Id }) end
	if why == "Declined" or why == "Expired" or why == "Busy" then
		pairCool[req.From.UserId .. ":" .. req.To.UserId] = os.clock() + T.Cooldown
	end
	if req.From.Parent then
		local text = (why == "Declined" and `{upper(req.To)} SAID NO THANKS`)
			or (why == "Expired" and `{upper(req.To)} DIDN'T ANSWER`)
			or (why == "Busy" and `{upper(req.To)} IS BUSY RIGHT NOW`)
			or nil
		if text then Net.Fire(req.From, "Toast", { Text = text, Color = "Orange" }) end
	end
end

local function open(a: Player, b: Player)
	local s = {
		Id = HttpService:GenerateGUID(false):sub(1, 8), A = a, B = b,
		Offer = { [a] = {}, [b] = {} }, Ready = {}, Confirm = {},
		Phase = "Offer", Version = 1, Started = os.clock(),
	}
	sessions[a], sessions[b] = s, s
	-- any other request either of them had going is off
	for _, p in ipairs({ a, b }) do
		if outgoing[p] then dropRequest(outgoing[p], "Gone") end
		if incoming[p] then dropRequest(incoming[p], "Busy") end
		p:SetAttribute("Trading", true)
	end
	print(`[Trade] {s.Id} opened: {a.Name} ({a.UserId}) + {b.Name} ({b.UserId})`)
	broadcast(s)
	return s
end

local function accept(req, by: Player)
	dropRequest(req, "Accepted")
	local from, to = req.From, req.To
	if not from.Parent then return { Ok = false, Err = "THEY LEFT" } end
	local err = check(by, by == to and from or to)
	if err then
		local other = by == to and from or to
		if other.Parent then Net.Fire(other, "Toast", { Text = `THE TRADE WITH {upper(by)} COULDN'T START`, Color = "Orange" }) end
		return { Ok = false, Err = err }
	end
	open(from, to)
	return { Ok = true }
end

--------------------------------------------------------------------------------
-- the move: everything or nothing
--------------------------------------------------------------------------------
local function count(items, kind: string): number
	local n = 0
	for _, it in ipairs(items) do if it.Kind == kind then n += 1 end end
	return n
end

-- out of the giver's profile (yard, hotbar, bond, hands); returns the records with their bond
local function take(player: Player, profile, items)
	local out = {}
	for _, it in ipairs(items) do
		if it.Kind == "Dino" then
			local d, i = findIn(profile.Dinos, it.Id)
			table.remove(profile.Dinos, i)
			local y = table.find(profile.Placed, it.Id)
			if y then table.remove(profile.Placed, y) end
			local b = table.find(profile.Buddies, it.Id)
			if b then table.remove(profile.Buddies, b) end
			Dinos.LeavePen(profile, it.Id)
			local pins = profile.HotbarPins
			local pin = typeof(pins) == "table" and table.find(pins, it.Id)
			if pin then pins[pin] = "" end
			local bond = profile.Bond and profile.Bond[it.Id]
			if profile.Bond then profile.Bond[it.Id] = nil end
			if player:GetAttribute("HeldDino") == it.Id then Dinos.ClearHeld(player) end
			table.insert(out, { Kind = "Dino", Rec = d, Bond = bond })
		else
			local e, i = findIn(profile.Eggs, it.Id)
			table.remove(profile.Eggs, i)
			if player:GetAttribute("HeldEgg") == it.Id then Dinos.ClearHeld(player) end
			table.insert(out, { Kind = "Egg", Rec = e })
		end
	end
	return out
end

-- into the receiver's: a dino walks into the yard if there's room (a sea star swims to the sea pen if it's free),
-- else it waits in the bag; eggs go in the bag
local function put(player: Player, profile, moved)
	for _, m in ipairs(moved) do
		local rec = copy(m.Rec)
		if m.Kind == "Dino" then
			table.insert(profile.Dinos, rec)
			if m.Bond then
				profile.Bond = profile.Bond or {}
				profile.Bond[rec.Id] = m.Bond
			end
			if Dinos.IsMarine(rec.Species) then
				Dinos.SeaHome(profile, player, rec.Id)
			elseif #profile.Placed < (profile.PenSlots or 0) then
				table.insert(profile.Placed, rec.Id)
			end
		else
			table.insert(profile.Eggs, rec)
		end
	end
end

local function summary(moved)
	local out = {}
	for _, m in ipairs(moved) do
		table.insert(out, { K = m.Kind, Id = m.Rec.Id, S = m.Rec.Species, R = m.Rec.Rarity, KG = m.Rec.KG })
	end
	return out
end

local function views(moved)
	local out = {}
	for _, m in ipairs(moved) do
		table.insert(out, { Kind = m.Kind, Id = m.Rec.Id, Species = m.Rec.Species, Rarity = m.Rec.Rarity, KG = m.Rec.KG, Name = m.Rec.Name })
	end
	return out
end

local function logLine(list): string
	local parts = {}
	for _, x in ipairs(list) do table.insert(parts, `{x.K}:{x.Id}:{x.R}:{x.S}:{x.KG}`) end
	return #parts > 0 and table.concat(parts, ",") or "-"
end

local function writeLog(profile, id: string, other: Player, gave, got)
	if typeof(profile.TradeLog) ~= "table" then profile.TradeLog = {} end
	table.insert(profile.TradeLog, 1, { Id = id, T = os.time(), With = other.UserId, Name = other.Name, Gave = gave, Got = got })
	while #profile.TradeLog > T.LogSize do table.remove(profile.TradeLog) end
end

local function execute(s)
	s.Executing = true
	local a, b = s.A, s.B
	local function fail(text: string, log: string)
		warn(`[Trade] {s.Id} FAILED ({log}): {a.Name} <-> {b.Name} - nothing moved`)
		s.Executing = false
		close(s, function() return text end)
		return { Ok = false, Err = text }
	end
	local pa, pb = Data.Peek(a), Data.Peek(b)
	if not (a.Parent and b.Parent and pa and pb) then return fail("SOMEONE LEFT - NOTHING WAS TRADED", "left") end
	if busyReason(a) or busyReason(b) then return fail("SOMEONE GOT BUSY - NOTHING WAS TRADED", "busy") end
	local giveA, giveB = s.Offer[a], s.Offer[b]
	if #giveA + #giveB == 0 then return fail("NOTHING TO TRADE", "empty") end
	-- every item: still theirs, still tradable, listed once
	for _, side in ipairs({ { a, pa, giveA }, { b, pb, giveB } }) do
		local seen = {}
		if #side[3] > T.MaxItems then return fail("TOO MANY ITEMS - NOTHING WAS TRADED", "cap") end
		for _, it in ipairs(side[3]) do
			if seen[it.Id] then return fail("TRADE ERROR - NOTHING WAS TRADED", "double " .. it.Id) end
			seen[it.Id] = true
			local why = Dinos.TradeBlock(side[2], it.Kind, it.Id)
			if why then return fail(`{upper(side[1])}: {why} - NOTHING WAS TRADED`, "blocked " .. it.Id) end
		end
	end
	-- room in both bags (a bag already over the cap - bought eggs always fit - may shrink but never grow)
	local inv = Config.Inventory
	local function fits(have: number, gives: number, gets: number, max: number): boolean
		local after = have - gives + gets
		return after <= max or after <= have
	end
	for _, side in ipairs({ { a, pa, giveA, giveB }, { b, pb, giveB, giveA } }) do
		local p, prof, gives, gets = side[1], side[2], side[3], side[4]
		if not fits(#prof.Dinos, count(gives, "Dino"), count(gets, "Dino"), inv.MaxDinos) then
			return fail(`{upper(p)}'S DINO BAG IS FULL - NOTHING WAS TRADED`, "dino bag")
		end
		if not fits(#prof.Eggs, count(gives, "Egg"), count(gets, "Egg"), inv.MaxEggs) then
			return fail(`{upper(p)}'S EGG BAG IS FULL - NOTHING WAS TRADED`, "egg bag")
		end
	end
	-- an id belongs to one record in the whole game: a clash means something's wrong, so never merge
	for _, side in ipairs({ { giveA, pb }, { giveB, pa } }) do
		for _, it in ipairs(side[1]) do
			if findIn(side[2].Dinos, it.Id) or findIn(side[2].Eggs, it.Id) then return fail("TRADE ERROR - NOTHING WAS TRADED", "id clash " .. it.Id) end
		end
	end

	-- the move. NO YIELDS from here to the end of the commit: both profiles change together or not at all
	local toB = take(a, pa, giveA)
	local toA = take(b, pb, giveB)
	put(a, pa, toA)
	put(b, pb, toB)
	local gaveA, gaveB = summary(toB), summary(toA)
	writeLog(pa, s.Id, b, gaveA, gaveB)
	writeLog(pb, s.Id, a, gaveB, gaveA)
	s.Executing = false
	s.Closed = true
	sessions[a], sessions[b] = nil, nil
	a:SetAttribute("Trading", nil)
	b:SetAttribute("Trading", nil)
	-- (commit done)

	print(`[Trade] {s.Id} DONE {os.time()}: {a.Name} ({a.UserId}) gave [{logLine(gaveA)}] <-> {b.Name} ({b.UserId}) gave [{logLine(gaveB)}]`)
	for _, p in ipairs({ a, b }) do
		Plots.Sync(p) -- the yard: the dinos that left walk off, the new ones walk in
		Data.Changed(p)
	end
	-- saved right away, both at once, so a crash can't leave one side traded and the other not
	task.spawn(Data.Save, a)
	task.spawn(Data.Save, b)
	Net.Fire(a, "TradeDone", { Id = s.Id, Name = b.DisplayName, Got = views(toA), Gave = views(toB) })
	Net.Fire(b, "TradeDone", { Id = s.Id, Name = a.DisplayName, Got = views(toB), Gave = views(toA) })
	return { Ok = true, Done = true }
end

--------------------------------------------------------------------------------
-- requests from clients
--------------------------------------------------------------------------------
local function sameSet(x, y): boolean
	if #x ~= #y then return false end
	local ids = {}
	for _, it in ipairs(x) do ids[it.Kind .. ":" .. it.Id] = true end
	for _, it in ipairs(y) do if not ids[it.Kind .. ":" .. it.Id] then return false end end
	return true
end

local function onRequest(player: Player, args)
	local target = typeof(args.UserId) == "number" and Players:GetPlayerByUserId(args.UserId) or nil
	if not target then return { Ok = false, Err = "THEY LEFT" } end
	local err = check(player, target)
	if err then return { Ok = false, Err = err } end
	-- they already asked you: that's a yes from both sides
	local theirs = outgoing[target]
	if theirs and theirs.To == player and requests[theirs.Id] == theirs then return accept(theirs, player) end
	if not near(player, target) then return { Ok = false, Err = "GET CLOSER TO THEM" } end
	local now = os.clock()
	if outgoing[player] then return { Ok = false, Err = "WAITING FOR AN ANSWER TO YOUR LAST REQUEST" } end
	if now - (lastAsk[player] or -1e9) < T.RequestGap then return { Ok = false, Err = "SLOW DOWN A LITTLE" } end
	local key = player.UserId .. ":" .. target.UserId
	if (pairCool[key] or 0) > now then return { Ok = false, Err = `ASK AGAIN IN {math.ceil(pairCool[key] - now)}S` } end
	if incoming[target] then return { Ok = false, Err = `{upper(target)} HAS A REQUEST OPEN - TRY AGAIN SOON` } end
	nextReq += 1
	local req = { Id = nextReq, From = player, To = target, Expires = now + T.RequestTime }
	requests[req.Id] = req
	outgoing[player], incoming[target] = req, req
	lastAsk[player] = now
	Net.Fire(target, "TradeRequest", { Id = req.Id, From = player.UserId, Name = player.DisplayName, Time = T.RequestTime })
	task.delay(T.RequestTime + 0.5, function()
		if requests[req.Id] == req then dropRequest(req, "Expired") end
	end)
	return { Ok = true, Time = T.RequestTime, Name = target.DisplayName }
end

local function onSetOffer(player: Player, args)
	local s = sessions[player]
	if not s or s.Executing or s.Closed then return { Ok = false, Err = "NO TRADE OPEN" } end
	if typeof(args.Items) ~= "table" then return { Ok = false } end
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local list, seen = {}, {}
	for _, it in ipairs(args.Items) do
		if typeof(it) ~= "table" or (it.Kind ~= "Dino" and it.Kind ~= "Egg") or typeof(it.Id) ~= "string" or #it.Id > 40 then
			return { Ok = false, Err = "CAN'T TRADE THAT" }
		end
		if not seen[it.Id] then
			seen[it.Id] = true
			if #list >= T.MaxItems then return { Ok = false, Err = `UP TO {T.MaxItems} ITEMS A TRADE` } end
			local why = Dinos.TradeBlock(profile, it.Kind, it.Id)
			if why then return { Ok = false, Err = why } end
			table.insert(list, { Kind = it.Kind, Id = it.Id })
		end
	end
	if sameSet(list, s.Offer[player]) then return { Ok = true, Version = s.Version } end
	s.Offer[player] = list
	changed(s, player)
	return { Ok = true, Version = s.Version }
end

local function onReady(player: Player, args)
	local s = sessions[player]
	if not s or s.Executing or s.Closed then return { Ok = false, Err = "NO TRADE OPEN" } end
	if args.On == false then
		-- (un-ready: the countdown stops; nothing else changed, so the Version stays)
		if s.Ready[player] or s.Confirm[player] or s.Phase ~= "Offer" then
			s.Ready[player] = nil
			table.clear(s.Confirm)
			s.Phase = "Offer"
			s.CountEnd, s.CountToken = nil, nil
			broadcast(s)
		end
		return { Ok = true }
	end
	if tonumber(args.Version) ~= s.Version then return { Ok = false, Err = "THE OFFER JUST CHANGED - CHECK IT AGAIN", Version = s.Version } end
	if #s.Offer[s.A] + #s.Offer[s.B] == 0 then return { Ok = false, Err = "PICK SOMETHING TO TRADE FIRST" } end
	if s.Phase ~= "Offer" then return { Ok = true } end
	s.Ready[player] = true
	if s.Ready[s.A] and s.Ready[s.B] then
		s.Phase = "Countdown"
		s.CountEnd = os.clock() + T.Countdown
		local token = {}
		s.CountToken = token
		task.delay(T.Countdown, function()
			if s.CountToken ~= token or s.Closed then return end
			s.CountToken, s.CountEnd = nil, nil
			s.Phase = "Confirm"
			broadcast(s)
		end)
	end
	broadcast(s)
	return { Ok = true }
end

local function onConfirm(player: Player, args)
	local s = sessions[player]
	if not s or s.Executing or s.Closed then return { Ok = false, Err = "NO TRADE OPEN" } end
	if s.Phase ~= "Confirm" then return { Ok = false, Err = "WAIT FOR THE COUNTDOWN" } end
	if tonumber(args.Version) ~= s.Version then return { Ok = false, Err = "THE OFFER JUST CHANGED - CHECK IT AGAIN", Version = s.Version } end
	s.Confirm[player] = true
	if s.Confirm[s.A] and s.Confirm[s.B] then return execute(s) end
	broadcast(s)
	return { Ok = true }
end

local function onCancel(player: Player)
	local s = sessions[player]
	if s and not s.Executing then
		close(s, function(p) return p == player and "TRADE CANCELLED" or `{upper(player)} CANCELLED THE TRADE` end)
		return { Ok = true }
	end
	-- (a request you sent: take it back)
	local req = outgoing[player]
	if req then dropRequest(req, "Gone") end
	return { Ok = true }
end

--------------------------------------------------------------------------------
function Trade.Start(deps)
	Data, Net, Dinos, Plots, Expedition = deps.Data, deps.Net, deps.Dinos, deps.Plots, deps.Expedition
	Net.On("TradeRequest", onRequest)
	Net.On("TradeAnswer", function(player, args)
		local req = requests[tonumber(args.Id) or -1]
		if not req or req.To ~= player then return { Ok = false, Err = "THAT REQUEST IS GONE" } end
		if args.Yes ~= true then
			dropRequest(req, args.Busy == true and "Busy" or "Declined")
			return { Ok = true }
		end
		if os.clock() > req.Expires then
			dropRequest(req, "Expired")
			return { Ok = false, Err = "THAT REQUEST EXPIRED" }
		end
		return accept(req, player)
	end)
	-- the TRADE button on a profile card: can we? (greys the button and says why)
	Net.On("TradeCheck", function(player, args)
		local target = typeof(args.UserId) == "number" and Players:GetPlayerByUserId(args.UserId) or nil
		if not target then return { Ok = false, Err = "THEY LEFT" } end
		local err = check(player, target)
		return { Ok = true, Can = err == nil, Err = err }
	end)
	Net.On("TradeSetOffer", onSetOffer)
	Net.On("TradeReady", onReady)
	Net.On("TradeConfirm", onConfirm)
	Net.On("TradeCancel", onCancel)
	Net.On("TradeSync", function(player)
		local s = sessions[player]
		return s and { Ok = true, State = view(s, player) } or { Ok = false }
	end)

	Players.PlayerRemoving:Connect(function(p)
		local s = sessions[p]
		if s then close(s, function() return `{upper(p)} LEFT - THE TRADE WAS CANCELLED` end) end
		if outgoing[p] then dropRequest(outgoing[p], "Gone") end
		if incoming[p] then dropRequest(incoming[p], "Gone") end
		lastAsk[p] = nil
	end)

	-- the watch: a trade closes when someone gets busy or it's been open too long, and an offered item that changed
	-- some other way drops out of the offer (READY resets)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local seen = {}
			for _, s in pairs(sessions) do
				if seen[s] or s.Closed or s.Executing then continue end
				seen[s] = true
				if os.clock() - s.Started > T.MaxTime then
					close(s, function() return "THE TRADE TIMED OUT" end)
					continue
				end
				local stop = nil
				for _, p in ipairs({ s.A, s.B }) do
					local why = busyReason(p)
					if why or not Data.Peek(p) then stop = p break end
				end
				if stop then
					local who = stop :: Player
					close(s, function(p) return p == who and "TRADE CANCELLED - YOU GOT BUSY" or `TRADE CANCELLED - {upper(who)} GOT BUSY` end)
					continue
				end
				for _, p in ipairs({ s.A, s.B }) do
					local profile = Data.Peek(p)
					local kept, dropped = {}, false
					for _, it in ipairs(s.Offer[p]) do
						if Dinos.TradeBlock(profile, it.Kind, it.Id) then dropped = true else table.insert(kept, it) end
					end
					if dropped then
						s.Offer[p] = kept
						changed(s, p)
					end
				end
			end
		end
	end)
end

-- (for other modules: is this player in a trade window right now?)
function Trade.InTrade(player: Player): boolean
	return sessions[player] ~= nil
end

return Trade
