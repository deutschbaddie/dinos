--[[
	TradeLedger — trades survive a server crash (2026-10-14).

	The problem: a trade changes two profiles, and they save one after the other. A crash (or a failed save) between
	the two saves would leave one side traded and the other not: a dino in both bags, or in neither.

	The fix, a write-ahead journal in its own DataStore (one key per player, "t<userId>": { [tradeId] = entry }):
	  1. Trade.execute writes BOTH players' entries (what each gives and gets, full records) BEFORE it moves anything
	     (Ledger.Write). If that fails the trade is refused and nothing moves.
	  2. The move (no yields), stamping profile.TradesApplied[tradeId] in both profiles, then both save.
	  3. Once both saves have landed, both entries are cleared (Ledger.Clear).
	As a profile LOADS (Data.Load calls Ledger.Resolve), every entry still in its journal is settled:
	  - this profile already has the trade (TradesApplied)        -> it saved fine: clear the entry
	  - the OTHER player's saved profile (or their live one on this server) has it -> the trade happened but this
	    side's save never landed: apply this side now (take what was given, add what was got) and clear the entry
	  - the other player is loaded on another server right now, without it -> can't tell yet: keep it for next time
	  - neither has it                                             -> the crash came before any save: the trade never
	    happened for anyone. Clear the entry.
	TradesApplied keeps ids for 60 days (at most 400), far longer than an entry can stay open.
	In Studio without API access there's no store: trades just run (nothing saves there anyway).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Ledger = {}

local KEEP_APPLIED = 60 * 86400
local MAX_APPLIED = 400

local store: DataStore? = nil
local storeName: string? = nil

-- Data hands over its store name at start (the PRE-BETA store gets its own ledger too)
function Ledger.Init(profileStoreName: string)
	storeName = profileStoreName .. "_TradeLedger"
	local ok, res = pcall(function() return DataStoreService:GetDataStore(storeName :: string) end)
	store = ok and res or nil
	if not ok then warn("[TradeLedger] no ledger store: " .. tostring(res)) end
end

local function retry(fn, tries: number): (boolean, any)
	local err
	for i = 1, tries do
		local ok, res = pcall(fn)
		if ok then return true, res end
		err = res
		if tostring(res):find("Studio") then return false, res end
		if i < tries then task.wait(0.6 * i) end
	end
	return false, err
end

function Ledger.Available(): boolean
	return store ~= nil
end

-- both sides' entries, before anything moves. entries: { [userId] = { With, Gave = {records}, Got = {records} } }
function Ledger.Write(tradeId: string, entries: { [number]: any }): boolean
	local st = store
	if not st then return true end
	local results = {}
	local threads = 0
	for uid, e in pairs(entries) do
		threads += 1
		task.spawn(function()
			local ok = retry(function()
				st:UpdateAsync("t" .. uid, function(old)
					local rec = typeof(old) == "table" and old or {}
					rec[tradeId] = { With = e.With, Gave = e.Gave, Got = e.Got, T = os.time() }
					return rec
				end)
			end, 3)
			results[uid] = ok
			threads -= 1
		end)
	end
	local t0 = os.clock()
	while threads > 0 and os.clock() - t0 < 20 do task.wait(0.05) end
	for uid in pairs(entries) do
		if results[uid] ~= true then
			-- (a half-written journal is harmless - an entry nobody applied is cleared at the next load - but tidy up)
			Ledger.Clear(tradeId, entries)
			return false
		end
	end
	return true
end

-- the entries go once the trade is safely in both saves (or never happened)
function Ledger.Clear(tradeId: string, users: { [number]: any })
	local st = store
	if not st then return end
	for uid in pairs(users) do
		task.spawn(retry, function()
			st:UpdateAsync("t" .. uid, function(old)
				if typeof(old) ~= "table" or old[tradeId] == nil then return nil end
				old[tradeId] = nil
				return old
			end)
		end, 3)
	end
end

-- a trade went into this profile (and keep the list from growing forever)
function Ledger.MarkApplied(profile, tradeId: string)
	if typeof(profile.TradesApplied) ~= "table" then profile.TradesApplied = {} end
	local applied = profile.TradesApplied
	local now = os.time()
	applied[tradeId] = now
	local n, oldestId, oldestT = 0, nil, math.huge
	for id, t in pairs(applied) do
		local tt = tonumber(t) or 0
		if now - tt > KEEP_APPLIED then
			applied[id] = nil
		else
			n += 1
			if tt < oldestT then oldestId, oldestT = id, tt end
		end
	end
	if n > MAX_APPLIED and oldestId then applied[oldestId] = nil end
end

local function has(profile, tradeId: string): boolean
	return typeof(profile) == "table" and typeof(profile.TradesApplied) == "table" and profile.TradesApplied[tradeId] ~= nil
end

local function indexOf(list, id: string): number?
	for i, r in ipairs(list) do
		if typeof(r) == "table" and r.Id == id then return i end
	end
	return nil
end

-- this side of a trade that happened, put into a profile that missed it
local function applyTo(profile, tradeId: string, e)
	profile.Dinos = typeof(profile.Dinos) == "table" and profile.Dinos or {}
	profile.Eggs = typeof(profile.Eggs) == "table" and profile.Eggs or {}
	for _, g in ipairs(typeof(e.Gave) == "table" and e.Gave or {}) do
		local id = typeof(g) == "table" and g.Rec and g.Rec.Id
		if typeof(id) ~= "string" then continue end
		local list = g.Kind == "Dino" and profile.Dinos or profile.Eggs
		local i = indexOf(list, id)
		if i then table.remove(list, i) end
		if g.Kind == "Dino" then
			for _, key in ipairs({ "Placed", "Buddies" }) do
				local l = profile[key]
				local j = typeof(l) == "table" and table.find(l, id)
				if j then table.remove(l, j) end
			end
			local pins = profile.HotbarPins
			local p = typeof(pins) == "table" and table.find(pins, id)
			if p then pins[p] = "" end
			if typeof(profile.Bond) == "table" then profile.Bond[id] = nil end
			pcall(function() (require(script.Parent.Dinos) :: any).LeavePen(profile, id) end) -- (out of a star pen)
		end
	end
	for _, g in ipairs(typeof(e.Got) == "table" and e.Got or {}) do
		local rec = typeof(g) == "table" and g.Rec
		if typeof(rec) ~= "table" or typeof(rec.Id) ~= "string" then continue end
		local list = g.Kind == "Dino" and profile.Dinos or profile.Eggs
		if not indexOf(list, rec.Id) then
			table.insert(list, rec)
			if g.Kind == "Dino" and g.Bond ~= nil then
				profile.Bond = typeof(profile.Bond) == "table" and profile.Bond or {}
				profile.Bond[rec.Id] = g.Bond
			end
		end
	end
	Ledger.MarkApplied(profile, tradeId)
end

-- Data.Load, with this player's profile locked to this server. profileStore / lockedByOther / peek are Data's.
-- Returns how many trades it applied (they're in the profile; the first save keeps them).
function Ledger.Resolve(userId: number, profile, profileStore: DataStore, lockedByOther: (any) -> boolean, peek: (Player) -> any): number
	local st = store
	if not st then return 0 end
	local ok, journal = retry(function() return st:GetAsync("t" .. userId) end, 3)
	if not ok or typeof(journal) ~= "table" or next(journal) == nil then return 0 end
	local applied = 0
	local done = {} :: { [string]: boolean }
	for tradeId, e in pairs(journal) do
		if typeof(tradeId) ~= "string" or typeof(e) ~= "table" then continue end
		if has(profile, tradeId) then
			done[tradeId] = true
			continue
		end
		local other = tonumber(e.With)
		if not other then
			done[tradeId] = true
			continue
		end
		-- the other side: live on this server, or its last save
		local otherHas, otherBusyElsewhere = false, false
		local live = Players:GetPlayerByUserId(other)
		local liveProfile = live and peek(live)
		if liveProfile then
			otherHas = has(liveProfile, tradeId)
		else
			local ok2, rec = retry(function() return profileStore:GetAsync("u" .. other) end, 3)
			if not ok2 then continue end -- (can't tell right now: keep it for the next load)
			otherHas = has(rec, tradeId)
			otherBusyElsewhere = not otherHas and lockedByOther(rec)
		end
		if otherHas then
			applyTo(profile, tradeId, e)
			applied += 1
			done[tradeId] = true
			warn(`[TradeLedger] {userId}: trade {tradeId} with {other} was missing from this save - applied it now`)
		elseif not otherBusyElsewhere then
			done[tradeId] = true -- (it never landed anywhere: it didn't happen)
		end
	end
	if next(done) then
		task.spawn(retry, function()
			st:UpdateAsync("t" .. userId, function(old)
				if typeof(old) ~= "table" then return nil end
				for id in pairs(done) do old[id] = nil end
				return old
			end)
		end, 3)
	end
	return applied
end

return Ledger
