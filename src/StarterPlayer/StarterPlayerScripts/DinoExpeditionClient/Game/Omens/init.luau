--[[
	Omens — every era's boss is out there before you ever fight it (Fern Valley's Tyrant King has its own three
	beats in Foreshadow.luau; these are the other five eras, each with its own idea, see Game/Omens/<Era>.luau).

	Until you've beaten that era's boss, per era:
	  SIGN       always lying beside the road near the arrival portal (you drive past it on every trip)
	  GLIMPSE    your SECOND trip into the era, on arrival, before the map: a short wordless cutscene
	  CLOSE CALL the first escape after the glimpse: it happens around you while you drive (no cutscene, no stop)
	Each beat plays once (Flags.Tips "Omen_<Zone>_Visit/Glimpse/Close"); a close call that can't happen on this
	stretch of road (Spine River needs water beside you) waits for the next escape. No words anywhere.

	Settings > CUTSCENES plays all fifteen on location (Omens.Gallery()).
]]

local Workspace = game:GetService("Workspace")

local K = require(script.Kit)
local Drive = K.Drive_
local Net = K.Net

local Omens = {}
local ORDER = { "GiantPlains", "SpineRiver", "RedCliffs", "FrostForest", "DawnDesert" }
local ERAS = {} :: { [string]: any }
for _, name in ipairs(ORDER) do
	local mod = script:FindFirstChild(name)
	if mod then
		local ok, res = pcall(function() return (require(mod :: ModuleScript) :: any)(K) end)
		if ok then ERAS[name] = res else warn("[Omens] " .. name .. ":", res) end
	end
end
-- where each era's sign lies (s along the first stretch of road, shared by every fork)
local SIGN_S = { GiantPlains = 168, SpineRiver = 215, RedCliffs = 128, FrostForest = 220, DawnDesert = 176 }
-- where a gallery close call starts driving (Spine River starts just before the river crossing)
local CLOSE_S = { GiantPlains = 320, SpineRiver = 300, RedCliffs = 420, FrostForest = 420, DawnDesert = 420 }

local function key(zone: string, beat: string): string return "Omen_" .. zone .. "_" .. beat end

--------------------------------------------------------------------------------
-- signs (world props, rebuilt / cleared as bosses fall)
--------------------------------------------------------------------------------
local signs = {} :: { [string]: Instance }
local function refreshSigns()
	for zone, E in pairs(ERAS) do
		local have = signs[zone]
		if K.Beaten(E.Boss) then
			if have then have:Destroy() signs[zone] = nil end
		elseif not (have and have.Parent) then
			local ok, f = pcall(E.Trace)
			if ok and f then signs[zone] = f elseif not ok then warn("[Omens] sign " .. zone .. ":", f) end
		end
	end
end

--------------------------------------------------------------------------------
-- glimpse (on arrival) and close call (on the escape)
--------------------------------------------------------------------------------
function Omens.BeforeMap(zone: string)
	local E = ERAS[zone]
	if not E or K.Beaten(E.Boss) or K.Busy() then return end
	if not K.Seen(key(zone, "Visit")) then
		K.MarkSeen(key(zone, "Visit")) -- the first trip has the era's own arrival; the glimpse waits for the next
		return
	end
	if K.Seen(key(zone, "Glimpse")) then return end
	local ctx = K.LiveArrivalCtx(zone)
	if not ctx then return end
	K.MarkSeen(key(zone, "Glimpse"))
	task.wait(0.35)
	K.Scene("Omen_" .. zone, function(sc) E.Sight(ctx, sc) end)
end

local closing = false
local function liveCtx(zone: string)
	local st = Drive.State
	local route = st.Route
	local vi = st.Variant or 1
	return {
		Zone = zone, Route = route, Vi = vi,
		S = function() return st.S or 0 end,
		Speed = function() return math.max(st.Speed or 0, 24) end,
		-- (and never under a cutscene: the ESCAPED! beat or the warp home ends a close call still running)
		Active = function() return st.Mode == "Route" and st.Route == route and not st.Toppled and not st.OnFoot and not K.Cinema.Playing() end,
		RoverCF = function() return st.Root and st.Root.CFrame or route:Frame(vi, st.S or 0, 0) end,
		-- a jolt you feel (camera only: an omen never costs you speed in a real escape)
		Knock = function(_, strength: number?) Drive.Kick(math.min(1, (strength or 2) * 0.35)) end,
	}
end

local function onChase(info)
	if info and info.Boss then return end
	local st = Drive.State
	local zone = st.Zone
	local E = zone and ERAS[zone]
	if not E or closing or K.Beaten(E.Boss) then return end
	if not K.Seen(key(zone, "Glimpse")) or K.Seen(key(zone, "Close")) then return end
	if st.Mode ~= "Route" or st.Route ~= K.RouteMath.get(zone) then return end
	closing = true
	task.delay(4.5, function()
		-- let the escape's own beat finish first
		local t0 = os.clock()
		while K.Cinema.Playing() and os.clock() - t0 < 8 do task.wait(0.1) end
		local ctx = liveCtx(zone)
		if ctx.Active() then -- (still a cutscene up after the wait: skip it - unseen, it comes on a later escape)
			local ok, played = K.Guarded(E.Close, ctx)
			if not ok then warn("[Omens] close " .. zone .. ":", played)
			elseif played then K.MarkSeen(key(zone, "Close")) end
		end
		closing = false
	end)
end

function Omens.Start(EraView)
	-- chain after Foreshadow (Fern Valley's beats) instead of replacing it
	local prev = EraView.BeforeMap
	EraView.BeforeMap = function(zone: string)
		if prev then prev(zone) end
		Omens.BeforeMap(zone)
	end
	Net.On("Profile", function() task.defer(refreshSigns) end)
	task.delay(1, refreshSigns)
	Net.On("ChaseStart", onChase)
end

--------------------------------------------------------------------------------
-- the cutscene gallery: each beat on location (a stand-in rover; nothing of yours moves)
--------------------------------------------------------------------------------
local function withLook(zone: string, fn: () -> ())
	local was = K.Zone.Current
	K.Zone.Apply(zone, true)
	local ok, err = pcall(fn)
	if not ok then warn("[Omens] preview:", err) end
	K.Zone.Apply(was, true)
end

function Omens.PreviewSign(zone: string)
	local E = ERAS[zone]
	if not E then return end
	local temp = nil
	if not (signs[zone] and signs[zone].Parent) then
		local ok, f = pcall(E.Trace)
		if ok then temp = f end
	end
	K.PreviewDrive(zone, SIGN_S[zone] - 150, 4.6, function() end)
	if temp then temp:Destroy() end
end

function Omens.PreviewGlimpse(zone: string)
	local E = ERAS[zone]
	if not E then return end
	withLook(zone, function()
		local set = K.Stage.new("OmenPreviewArrival")
		set:Show()
		local ctx = K.ArrivalCtx(set, zone)
		if ctx then K.Scene("OmenPreview_" .. zone, function(sc) E.Sight(ctx, sc) end) end
		set:Destroy()
	end)
end

function Omens.PreviewClose(zone: string)
	local E = ERAS[zone]
	if not E then return end
	K.PreviewDrive(zone, CLOSE_S[zone], 11, function(ctx)
		local ok, played = pcall(E.Close, ctx)
		if not ok then warn("[Omens] preview close:", played) end
	end)
end

-- { label, icon, colour, play } rows for Settings > CUTSCENES
function Omens.Gallery(): { any }
	local rows = {}
	local colors = { GiantPlains = "Orange", SpineRiver = "Teal", RedCliffs = "Red", FrostForest = "Teal", DawnDesert = "Yellow" }
	for _, zone in ipairs(ORDER) do
		local E = ERAS[zone]
		local boss = E and K.Config.Bosses[E.Boss]
		if E and boss then
			local n = boss.Name
			table.insert(rows, { n .. ": SIGN", "Map", colors[zone], function() Omens.PreviewSign(zone) end })
			table.insert(rows, { n .. ": GLIMPSE", "Film", colors[zone], function() Omens.PreviewGlimpse(zone) end })
			table.insert(rows, { n .. ": CLOSE CALL", "Jeep", colors[zone], function() Omens.PreviewClose(zone) end })
		end
	end
	return rows
end

-- (the camera is always handed back to the player by K.Scene; this is only for a dev reset)
function Omens.Reset()
	for _, f in pairs(signs) do f:Destroy() end
	table.clear(signs)
	local root = Workspace:FindFirstChild("DinoOmens")
	if root then root:Destroy() end
	refreshSigns()
end

return Omens
