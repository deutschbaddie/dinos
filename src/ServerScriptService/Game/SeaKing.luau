--[[
	SeaKing — the fight for a sea boss (Config.Bosses[id].Water), run inside Bosses' den.

	Phase 1, THE SEA MOUTH (docks around open water). It never leaves the water for long:
	  CIRCLE     its back + fin cut circles inside the dock ring (dart it!)
	  BREACH     it goes under and its FIN comes for you, homing in; a ring of bubbles boils under you (jump clear),
	             then it erupts straight up through the dock, arcs over and crashes down beside the hole: WEAK
	  TAILSLAM   it dives, comes up in the middle, rears and slaps rolling waves across the ring: each one hits you
	             as its crest REACHES you - jump it (or roll through it)
	  GRAB       the fin homes in on someone in the water (or near the edge), it drags them under: teammates dart it
	             to make it let go, the victim struggles free; it lets go on its own after a few seconds
	  CANNONBALL (2026-10-14, from 15% calm) it ducks under, then launches clean out of the sea and sails over the
	             docks - its shadow grows on the planks where it'll land - and belly-flops onto them. Out of the
	             circle in time, then jump the ripple that rolls out of the impact. It's stuck flapping on the deck
	             afterwards: the big weak window, everyone pile in. Then it rolls off, smashing the planks
	Phase 2 (Bosses.toChase) is the boat chase down the Sea Lane. Phase 3, THE MAW (a rock ring out at sea):
	  circle / breach / tail-slam / cannonball as before (the fin rounds the OUTSIDE of the rock, never through
	  it); once it's angry a storm rolls in over the Maw (den attribute Storm: rain, dark sky, lightning), and below
	  25% calm left it spins a WHIRLPOOL in the middle pool: everyone is dragged toward it while it lunges out of the
	  centre. At the rodeo point it hurls itself up onto the ring: jump on for the finisher.

	Motion (2026-10-14, "no jittery movement"): it never pops from one place to another where you can see it. Any
	relocation happens deep under the surface (State Submerge with no Fin), the circle starts from wherever it is
	and eases onto its radius, and the client draws every surfacing, arc and beaching as a smooth blend
	(ExpeditionView's swimmer branch). Moves are coroutines with a token: anything that takes the boss (the rodeo
	point, a phase change, a reset) bumps q.SeaTok and every running move stops at its next step.

	Everything the client needs arrives as site events: Tele (shapes, Surface = drawn on the water, never the
	seabed), SeaBubbles, SeaWave, SeaSplash, SeaGrab / SeaRelease, SeaWhirl, BossMove (Cannonball / SeaShadow /
	Ripple / Flop / Beach), plus the actor's State (Swim, Submerge (+ Fin attribute), Breach, Leap (+ LeapTime),
	Recover, TailSlam, Grab, Drag, Whirl, Dazed, Exhausted...).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SeaKing = {}
local Encounter, Net
local Config = require(game:GetService("ReplicatedStorage").DinoExpedition.Game.Config)
-- its blows are written for the old gear curve: scaled like every other Spine River attack (Config.EraScale)
local function dmg(den, x: number): number
	return x * Config.EraScaleOf(den.Era).Dmg
end
local rng = Random.new()

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
-- (a zero vector's .Unit is NaN: one NaN position sent the whole body to nowhere on every client)
local function unitOr(v: Vector3, fallback: Vector3): Vector3
	local f = flat(v)
	return f.Magnitude > 0.05 and f.Unit or fallback
end

local function marker(zm: Instance, name: string): BasePart?
	local m = zm:FindFirstChild(name, true)
	return m and m:IsA("BasePart") and m or nil
end

local floorRay = RaycastParams.new()
floorRay.FilterType = Enum.RaycastFilterType.Exclude
floorRay.RespectCanCollide = true
-- off the ground right now? (jumping a wave). Swimmers count as off the deck too.
local function airborne(hrp: BasePart): boolean
	local list = {}
	if hrp.Parent then table.insert(list, hrp.Parent) end
	floorRay.FilterDescendantsInstances = list
	local hit = Workspace:Raycast(hrp.Position, Vector3.new(0, -9, 0), floorRay)
	return hit == nil or (hrp.Position.Y - hit.Position.Y) > 4.1
end

-- the deck / rock top under a hunter (2026-10-14: the cannonball used to aim at their feet height, so a target in
-- mid-jump left it lying in the air above the planks). Falls back to the old guess over open water
local Players = game:GetService("Players")
local function deckUnder(den, p: Vector3): number
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(list, plr.Character) end end
	floorRay.FilterDescendantsInstances = list
	local hit = Workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, -16, 0), floorRay)
	if hit and hit.Position.Y > den.WaterY - 0.5 then return math.max(den.WaterY + 0.5, hit.Position.Y) end
	return math.max(den.WaterY + 0.5, p.Y - 3.1)
end

--------------------------------------------------------------------------------
-- setup (Bosses.Start, once per water den)
--------------------------------------------------------------------------------
function SeaKing.Setup(den, zm: Instance, deps)
	Encounter, Net = deps.Encounter, deps.Net
	local bay = marker(zm, "BayCenter")
	den.Water = true
	den.WaterY = zm:GetAttribute("WaterY") or 0
	den.Bay = bay and Vector3.new(bay.Position.X, den.WaterY, bay.Position.Z) or den.DenCenter
	den.BayR = bay and (bay:GetAttribute("Radius") or 26) or 26
	den.DockSpots = {}
	for k = 1, 12 do
		local m = marker(zm, "DockSpot" .. k)
		if not m then break end
		table.insert(den.DockSpots, m.Position)
	end
	den.Docks = {}
	for _, m in ipairs(CollectionService:GetTagged("DockSection")) do
		if m:IsDescendantOf(zm) then
			local parts = {}
			for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts, { Part = p, T = p.Transparency, C = p.CanCollide }) end end
			local cf, size = (m :: Model):GetBoundingBox()
			table.insert(den.Docks, { Model = m, Parts = parts, Center = cf.Position, R = math.max(size.X, size.Z) / 2, Broken = false })
		end
	end
	local final = marker(zm, "FinalArena")
	if final then
		den.Maw = { Center = Vector3.new(final.Position.X, den.WaterY, final.Position.Z), Inner = final:GetAttribute("Inner") or 14, Outer = final:GetAttribute("Outer") or 32, Top = final:GetAttribute("Top") or 2.2, Spots = {} }
		for k = 1, 8 do
			local m = marker(zm, "MawSpot" .. k)
			if not m then break end
			table.insert(den.Maw.Spots, m.Position)
		end
	end
	-- teammates' darts free a grabbed hunter
	den.OnCalm = function(site, a)
		if a.State == "Exhausted" or a.State == "Rodeo" or a.State == "KO" then return end
		if a.Boss and site.Grab then
			site.Grab.Hits += 1
			if site.Grab.Hits >= 3 then SeaKing.Release(site, "Freed") end
		end
	end
end

--------------------------------------------------------------------------------
-- docks: smash + float back
--------------------------------------------------------------------------------
local function breakDocks(den, at: Vector3, r: number)
	for _, d in ipairs(den.Docks) do
		if not d.Broken and flat(d.Center - at).Magnitude < r + d.R * 0.6 then
			d.Broken = true
			d.Model:SetAttribute("Broken", true)
			for _, p in ipairs(d.Parts) do p.Part.CanCollide = false p.Part.Transparency = 1 end
			d.FixAt = os.clock() + 26
		end
	end
end

local function fixDocks(den, all: boolean)
	local now = os.clock()
	for _, d in ipairs(den.Docks) do
		if d.Broken and (all or now >= (d.FixAt or 0)) then
			d.Broken = false
			for _, p in ipairs(d.Parts) do p.Part.CanCollide = p.C p.Part.Transparency = p.T end
			d.Model:SetAttribute("Broken", nil) -- (after the parts are back: the client tweens them up from below)
		end
	end
end

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------
local function hunters(den)
	local out = {}
	for plr, st in pairs(den.Players) do
		local h = Encounter.HrpOf(plr)
		if h and not st.Downed then table.insert(out, { Player = plr, Hrp = h }) end
	end
	return out
end

local function inWater(den, h: BasePart): boolean
	return h.Position.Y < den.WaterY + 2.2
end

local function setPos(q, p: Vector3, faceTo: Vector3?, v: number?)
	local dir = faceTo and flat(faceTo - p) or flat(p - q.Pos)
	if dir.Magnitude > 0.05 then q.Yaw = math.atan2(-dir.X, -dir.Z) end
	q.Pos = p
	Encounter.PublishActor(q, v or 0)
end

-- the arena it's fighting in right now: centre, the radius it circles at, and the deck height hunters stand on
local function arena(den)
	if den.Phase >= 3 and den.Maw then
		return den.Maw.Center, (den.Maw.Outer + 9), den.Maw.Top
	end
	return den.Bay, den.BayR, 1.6
end

-- out at the Maw its body (~32 long) has to stay in open water: in the middle pool, or outside the ring. A hunter
-- standing on the rock gets attacked from the nearer side, jaws reaching the ring's edge, never through it.
-- Returns where its body goes and what it faces.
local function mawSpot(den, target: Vector3): (Vector3, Vector3)
	local m = den.Maw
	local c = m.Center
	local d = flat(target - c)
	local r = d.Magnitude
	local dir = r > 0.1 and d.Unit or Vector3.new(1, 0, 0)
	local poolR, outR = math.max(2, m.Inner - 17), m.Outer + 18
	if r <= poolR then return Vector3.new(target.X, den.WaterY, target.Z), c + dir * (m.Inner + 5) end
	if r >= outR then return Vector3.new(target.X, den.WaterY, target.Z), c end
	if r < (m.Inner + m.Outer) / 2 then
		local at = c + dir * poolR
		return Vector3.new(at.X, den.WaterY, at.Z), c + dir * (m.Inner + 5)
	end
	local at = c + dir * outR
	return Vector3.new(at.X, den.WaterY, at.Z), c
end

-- telegraphs on the sea are drawn on the WATER (the client's ground ray ignores water and would put them on the
-- seabed, out of sight): Surface is the lowest they may sit
local function surface(den): number
	return den.WaterY + 0.15
end

local nextKey = 0
local function key(): string
	nextKey += 1
	return "SK" .. nextKey
end

-- the move that owns the boss right now: a new one bumps the token; everything older stops at its next step
local function claim(q): number
	q.SeaTok = (q.SeaTok or 0) + 1
	q.Mode = "Busy"
	q.BusySince = os.clock()
	q.Cfg:SetAttribute("Weak", nil)
	return q.SeaTok
end
local function alive(den, q, tok: number, phase: number): boolean
	if not q.Cfg.Parent or q.SeaTok ~= tok or den.Phase ~= phase then return false end
	local st = q.State
	return st ~= "Exhausted" and st ~= "Rodeo" and st ~= "KO" and st ~= "Hidden"
end
local function sleep(den, q, tok: number, phase: number, t: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < t do
		task.wait(math.min(0.05, t))
		if not alive(den, q, tok, phase) then return false end
	end
	return true
end

--------------------------------------------------------------------------------
-- moves
--------------------------------------------------------------------------------
-- back to swimming its circle, from wherever it is: the circle picks up at its own angle and eases out to its
-- radius. A body that can't swim round from where it is (up on a dock or the rock, in the Maw's pool) dives
-- first and comes up on the circle (Circle tick)
local function startCircle(den, q, dur: number?)
	q.Mode = "Circle"
	local pace = Config.Encounter.BossPace and Config.Encounter.BossPace.SeaCircle or 1
	q.ModeUntil = os.clock() + (dur or rng:NextNumber(3.2, 4.6) * pace * (q.Enraged and 0.8 or 1))
	q.Cfg:SetAttribute("Weak", nil)
	q.Cfg:SetAttribute("Fin", nil)
	local c, r = arena(den)
	local d = flat(q.Pos - c)
	q.Angle = math.atan2(d.Z, d.X)
	q.CR = d.Magnitude
	if math.abs(q.CR - r) > 8 or q.Pos.Y > den.WaterY + 0.5 then
		q.DiveUntil = os.clock() + 0.55
		q.ModeUntil += 0.55
		Encounter.SetState(q, "Submerge")
	else
		q.DiveUntil = nil
		Encounter.SetState(q, "Swim")
	end
end

local function pickTarget(den, preferWater: boolean)
	local list = hunters(den)
	if #list == 0 then return nil end
	if preferWater then
		for _, h in ipairs(list) do if inWater(den, h.Hrp) then return h end end
	end
	return list[rng:NextInteger(1, #list)]
end

-- the fin: just under the surface, only the fin cutting the water, homing in on goal() for dur seconds. In the
-- bay it crosses the open water (never closer to the docks than the edge of it); at the Maw it rounds the OUTSIDE
-- of the rock ring toward the hunter's side. False if the move was interrupted
local FIN_SPEED = 34
local function finGlide(den, q, tok: number, phase: number, goal: () -> Vector3?, dur: number): boolean
	q.Cfg:SetAttribute("Fin", true)
	Encounter.SetState(q, "Submerge")
	local c = arena(den)
	local maw = den.Phase >= 3 and den.Maw
	local t0, last = os.clock(), os.clock()
	while os.clock() - t0 < dur do
		RunService.Heartbeat:Wait()
		if not alive(den, q, tok, phase) then return false end
		local now = os.clock()
		local dt = math.min(0.1, now - last)
		last = now
		local g = goal()
		if g then
			local to: Vector3
			if maw then
				local R = den.Maw.Outer + 9
				local a0 = math.atan2(q.Pos.Z - c.Z, q.Pos.X - c.X)
				local a1 = math.atan2(g.Z - c.Z, g.X - c.X)
				local da = math.atan2(math.sin(a1 - a0), math.cos(a1 - a0))
				local cr = flat(q.Pos - c).Magnitude
				local step = math.clamp(da, -FIN_SPEED * dt / math.max(8, cr), FIN_SPEED * dt / math.max(8, cr))
				cr += math.clamp(R - cr, -10 * dt, 10 * dt)
				to = c + Vector3.new(math.cos(a0 + step), 0, math.sin(a0 + step)) * cr
			else
				local want = g
				local off = flat(want - c)
				if off.Magnitude > den.BayR - 3 then want = c + off.Unit * (den.BayR - 3) end
				local d = flat(want - q.Pos)
				to = d.Magnitude > 0.2 and (q.Pos + d.Unit * math.min(d.Magnitude, FIN_SPEED * dt)) or q.Pos
			end
			setPos(q, Vector3.new(to.X, den.WaterY, to.Z), nil, FIN_SPEED)
		end
	end
	return true
end

local function doBreach(den, q)
	local t = pickTarget(den, false)
	if not t then startCircle(den, q) return end
	local tok, phase = claim(q), den.Phase
	task.spawn(function()
		local enr = q.Enraged and 0.85 or 1
		local c = arena(den)
		-- the fin comes for you
		if not finGlide(den, q, tok, phase, function() return t.Hrp.Parent and t.Hrp.Position or nil end, 1.0 * enr) then return end
		local spot = t.Hrp.Parent and t.Hrp.Position or q.Pos
		local o = Vector3.new(spot.X, den.WaterY, spot.Z)
		local tele = 1.35 * enr
		-- the red disc where the hunter stands (on the planks / the rock); the bubbles boil at the waterline
		local teleO = Vector3.new(spot.X, math.max(den.WaterY, spot.Y - 3.1), spot.Z)
		local k = key()
		Encounter.FireSite(den, "Tele", { Actor = q.Id, Key = k, Id = "Breach", Shape = "Circle", O = teleO, R = 9, Time = tele, Surface = surface(den) })
		Encounter.FireSite(den, "SeaBubbles", { At = o, Time = tele, R = 9 })
		-- the fin hangs there a moment, then it's gone - deep - and the water boils
		if not sleep(den, q, tok, phase, tele * 0.35) then return end
		q.Cfg:SetAttribute("Fin", nil)
		if not sleep(den, q, tok, phase, tele * 0.3) then return end
		local body, face
		if den.Phase >= 3 and den.Maw then body, face = mawSpot(den, o) else body, face = Vector3.new(o.X, den.WaterY, o.Z), c end
		setPos(q, body, face) -- (deep under: the move to the spot is hidden)
		if not sleep(den, q, tok, phase, tele * 0.35) then return end
		Encounter.SetState(q, "Breach")
		for _, h in ipairs(hunters(den)) do
			if flat(h.Hrp.Position - o).Magnitude <= 9 and math.abs(h.Hrp.Position.Y - den.WaterY) < 14 then
				Encounter.Hurt(den, h.Player, dmg(den, 44), "Breach")
			end
		end
		if den.Phase < 3 then breakDocks(den, o, 7) end
		Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = "Breach", Key = k })
		Encounter.FireSite(den, "SeaSplash", { At = o, Size = 2.2 })
		-- up, over and down beside the hole (the body really travels while the client draws the arc)
		local back = c + unitOr(o - c, Vector3.new(1, 0, 0)) * math.max(4, flat(o - c).Magnitude - 9)
		local land, landFace
		if den.Phase >= 3 and den.Maw then land, landFace = mawSpot(den, back) else land, landFace = Vector3.new(back.X, den.WaterY, back.Z), c end
		local t0 = os.clock()
		while os.clock() - t0 < 1.0 do
			RunService.Heartbeat:Wait()
			if not alive(den, q, tok, phase) then return end
			local u = math.clamp((os.clock() - t0) / 1.0, 0, 1)
			setPos(q, body:Lerp(land, u), (face :: Vector3):Lerp(landFace, u), flat(land - body).Magnitude)
		end
		setPos(q, land, landFace)
		-- the crash back down: a wall of spray, then it wallows there, dazed - the weak window
		Encounter.FireSite(den, "SeaSplash", { At = Vector3.new(land.X, den.WaterY, land.Z), Size = 1.8 })
		Encounter.SetState(q, "Recover")
		q.Cfg:SetAttribute("Weak", true)
		q.Mode = "Recover"
		q.ModeUntil = os.clock() + 2.6
	end)
end

-- a wave of water rolling out across a band (inner -> outer): it hits each hunter as its crest REACHES them, so
-- the jump (or the roll) is timed to the wave you can see. Time t; the crest rolls from 30% to 105% of it (the
-- same curve SeaFight draws)
local function rollingWave(den, q, tok: number, phase: number, o: Vector3, deck: number, inner: number, outer: number, t: number, hurt: number, id: string, drawn: boolean?)
	local k = key()
	Encounter.FireSite(den, "Tele", { Actor = q.Id, Key = k, Id = id, Shape = "Ring", O = Vector3.new(o.X, deck, o.Z), R = outer, Inner = inner, Time = t * 1.05, Surface = surface(den) })
	if not drawn then Encounter.FireSite(den, "SeaWave", { O = Vector3.new(o.X, den.WaterY, o.Z), From = inner, To = outer, Time = t }) end
	local done = {} :: { [Player]: boolean }
	local t0 = os.clock()
	while true do
		RunService.Heartbeat:Wait()
		if not alive(den, q, tok, phase) then break end
		local u = (os.clock() - t0) / t
		local crest = inner + (outer - inner) * math.clamp((u - 0.3) / 0.75, 0, 1)
		for _, h in ipairs(hunters(den)) do
			if not done[h.Player] then
				local d = flat(h.Hrp.Position - o).Magnitude
				if d >= inner - 1 and d <= outer + 1 and crest >= d - 0.5 then
					done[h.Player] = true
					if not airborne(h.Hrp) and math.abs(h.Hrp.Position.Y - deck) < 10 then Encounter.Hurt(den, h.Player, dmg(den, hurt), id) end
				end
			end
		end
		if u >= 1.06 then break end
	end
	Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = id, Key = k })
end

local function doTailSlam(den, q)
	local tok, phase = claim(q), den.Phase
	task.spawn(function()
		local c, _, deck = arena(den)
		-- under, across to the middle (hidden), and up
		q.Cfg:SetAttribute("Fin", nil)
		Encounter.SetState(q, "Submerge")
		if not sleep(den, q, tok, phase, 0.55) then return end
		local nearest = nil
		for _, h in ipairs(hunters(den)) do nearest = h.Hrp.Position break end
		setPos(q, Vector3.new(c.X, den.WaterY, c.Z), nearest)
		Encounter.SetState(q, "Swim")
		if not sleep(den, q, tok, phase, 0.6) then return end
		local inner, outer
		if den.Phase >= 3 and den.Maw then inner, outer = den.Maw.Inner - 2, den.Maw.Outer + 3 else
			local r = 34
			inner, outer = r - 8, r + 8
		end
		local t = 1.3 * (q.Enraged and 0.85 or 1)
		local n = q.Enraged and 3 or 2
		for i = 1, n do
			Encounter.SetState(q, "TailSlam")
			task.spawn(rollingWave, den, q, tok, phase, c, deck, inner, outer, t, 30, "TailWave")
			if not sleep(den, q, tok, phase, i < n and 1.6 or t * 1.1) then return end
		end
		startCircle(den, q, 2.6)
	end)
end

local function doGrab(den, q)
	local t = pickTarget(den, true)
	if not t then startCircle(den, q) return end
	local tok, phase = claim(q), den.Phase
	q.NextGrab = os.clock() + 14
	task.spawn(function()
		local enr = q.Enraged and 0.85 or 1
		if not finGlide(den, q, tok, phase, function() return t.Hrp.Parent and t.Hrp.Position or nil end, 0.9 * enr) then return end
		local o = Vector3.new(t.Hrp.Position.X, den.WaterY, t.Hrp.Position.Z)
		local tele = 1.05 * enr
		local k = key()
		Encounter.FireSite(den, "Tele", { Actor = q.Id, Key = k, Id = "Grab", Shape = "Circle", O = Vector3.new(o.X, math.max(den.WaterY, t.Hrp.Position.Y - 3.1), o.Z), R = 6, Time = tele, Surface = surface(den) })
		Encounter.FireSite(den, "SeaBubbles", { At = o, Time = tele, R = 6 })
		if not sleep(den, q, tok, phase, tele * 0.45) then return end
		q.Cfg:SetAttribute("Fin", nil)
		if not sleep(den, q, tok, phase, tele * 0.2) then return end
		-- (deep: hidden). At the Maw its body stays in open water - the pool or outside the ring - with the jaws
		-- reaching for you: it used to come up inside the rock and drag you round through it (2026-10-14)
		if den.Phase >= 3 and den.Maw then
			local body, face = mawSpot(den, o)
			setPos(q, body, face)
		else
			setPos(q, o, (arena(den)))
		end
		if not sleep(den, q, tok, phase, tele * 0.35) then return end
		local st = den.Players[t.Player]
		local h = Encounter.HrpOf(t.Player)
		Encounter.SetState(q, "Grab")
		Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = "Grab", Key = k })
		Encounter.FireSite(den, "SeaSplash", { At = o, Size = 1.4 })
		if h and st and not st.Downed and flat(h.Position - o).Magnitude <= 6.5 and os.clock() >= (st.Invuln or 0) then
			-- caught: dragged under until freed
			den.Grab = { Player = t.Player, Hits = 0, Mash = 0, Until = os.clock() + 5.5, NextBite = os.clock() + 1 }
			Encounter.SetState(q, "Drag")
			Encounter.FireSite(den, "SeaGrab", { Actor = q.Id, UserId = t.Player.UserId, Name = t.Player.DisplayName, Time = 5.5 })
			q.Mode = "Drag"
		else
			-- (rolled clear through the jaws: that's a perfect dodge)
			if h and st and flat(h.Position - o).Magnitude <= 6.5 and os.clock() < (st.Invuln or 0) then Encounter.Hurt(den, t.Player, 0, "Grab") end
			if not sleep(den, q, tok, phase, 0.5) then return end
			startCircle(den, q, 2.2)
		end
	end)
end

-- CANNONBALL: out of the sea, over the docks, belly-first onto whoever's standing there
local function ballTargets(den)
	local c = arena(den)
	local out = {}
	for _, h in ipairs(hunters(den)) do
		if not inWater(den, h.Hrp) then
			local r = flat(h.Hrp.Position - c).Magnitude
			local ok
			if den.Phase >= 3 and den.Maw then ok = r >= den.Maw.Inner - 2 and r <= den.Maw.Outer + 2
			else ok = r <= den.BayR + 14 end
			if ok then table.insert(out, h) end
		end
	end
	return out
end

local function doCannonball(den, q)
	local list = ballTargets(den)
	if #list == 0 then return false end
	local t = list[rng:NextInteger(1, #list)]
	local tok, phase = claim(q), den.Phase
	q.NextBall = os.clock() + 20
	task.spawn(function()
		local enr = q.Enraged and 0.88 or 1
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Cannonball", Name = "CANNONBALL!", Actor = q.Id })
		-- it ducks under where it is (the bubbles say where it's coming from)...
		q.Cfg:SetAttribute("Fin", nil)
		Encounter.SetState(q, "Submerge")
		Encounter.FireSite(den, "SeaBubbles", { At = Vector3.new(q.Pos.X, den.WaterY, q.Pos.Z), Time = 0.6, R = 7 })
		if not sleep(den, q, tok, phase, 0.6) then return end
		local spot = t.Hrp.Parent and t.Hrp.Position or q.Pos
		local L = Vector3.new(spot.X, deckUnder(den, spot), spot.Z) -- (the deck / rock under them, even mid-jump)
		local from = Vector3.new(q.Pos.X, den.WaterY, q.Pos.Z)
		local T = 1.5 * enr
		-- ...and launches: the red circle and its growing shadow mark where it comes down
		local k = key()
		Encounter.FireSite(den, "Tele", { Actor = q.Id, Key = k, Id = "Cannonball", Shape = "Circle", O = L, R = 11, Time = T, Surface = surface(den) })
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "SeaShadow", At = L, R = 11, Time = T, Actor = q.Id })
		Encounter.FireSite(den, "SeaSplash", { At = from, Size = 2.6 })
		q.Cfg:SetAttribute("LeapTime", T)
		Encounter.SetState(q, "Leap")
		local face = L + unitOr(L - from, unitOr(L - (arena(den)), Vector3.new(0, 0, -1))) * 10
		local t0 = os.clock()
		while os.clock() - t0 < T do
			RunService.Heartbeat:Wait()
			if not alive(den, q, tok, phase) then return end
			local u = math.clamp((os.clock() - t0) / T, 0, 1)
			local p = from:Lerp(L, u)
			setPos(q, Vector3.new(p.X, L.Y, p.Z), face, flat(L - from).Magnitude / T)
		end
		setPos(q, L, face)
		-- SPLAT
		Encounter.SetState(q, "Dazed")
		q.Cfg:SetAttribute("Weak", true)
		for _, h in ipairs(hunters(den)) do
			if flat(h.Hrp.Position - L).Magnitude <= 11 and math.abs(h.Hrp.Position.Y - L.Y) < 10 then
				if Encounter.Hurt(den, h.Player, dmg(den, 50), "Cannonball") then
					Net.Fire(h.Player, "Knockback", { From = L, Force = 14, Up = 42 })
				end
			end
		end
		Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = "Cannonball", Key = k })
		Encounter.FireSite(den, "SeaSplash", { At = Vector3.new(L.X, den.WaterY, L.Z), Size = 3 })
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Flop", At = L, Actor = q.Id })
		-- the ripple out of the impact: jump it (or roll it) as it reaches you
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Ripple", At = L, From = 11, To = 23, Time = 0.85, Actor = q.Id })
		task.spawn(rollingWave, den, q, tok, phase, L, L.Y, 11, 23, 0.85, 20, "Ripple", true)
		-- stuck flapping on the deck: everyone pile in
		if not sleep(den, q, tok, phase, 3.2) then return end
		q.Cfg:SetAttribute("Weak", nil)
		-- it rolls off: the planks under it go with it
		if den.Phase < 3 then
			breakDocks(den, L, 5)
			Encounter.FireSite(den, "SeaSplash", { At = Vector3.new(L.X, den.WaterY, L.Z), Size = 1.6 })
		end
		startCircle(den, q, 2.2)
	end)
	return true
end

function SeaKing.Release(den, how: string)
	local g = den.Grab
	if not g then return end
	den.Grab = nil
	local q
	for _, a in ipairs(den.Actors) do if a.Boss then q = a end end
	-- put the victim back on a dock (or the Maw)
	local spots = (den.Phase >= 3 and den.Maw) and den.Maw.Spots or den.DockSpots
	local h = Encounter.HrpOf(g.Player)
	local best = spots[1]
	if h then
		local bd = math.huge
		for _, p in ipairs(spots) do
			-- (never back onto a dock it just smashed: its planks don't collide, you'd drop straight into the sea)
			local broken = false
			for _, dk in ipairs(den.Docks or {}) do
				if dk.Broken and flat(dk.Center - p).Magnitude < dk.R then broken = true break end
			end
			local d = flat(p - h.Position).Magnitude + (broken and 1e4 or 0)
			if d < bd then best, bd = p, d end
		end
	end
	if how == "Timeout" then Encounter.Hurt(den, g.Player, dmg(den, 22), "Drag") end
	local payload = { UserId = g.Player.UserId, To = best, How = how }
	Encounter.FireSite(den, "SeaRelease", payload)
	-- (the victim may already be out of the site: a reset, a defeat, a phase change - they still need letting go)
	if not den.Players[g.Player] and g.Player.Parent then Net.Fire(g.Player, "SeaRelease", payload) end
	if q and q.State ~= "KO" and q.State ~= "Exhausted" and q.State ~= "Rodeo" and q.State ~= "Hidden" then
		if how == "Freed" or how == "Mash" then
			-- shaken loose: it's stunned for a moment, a great time to hit it
			Encounter.SetState(q, "Recover")
			q.Cfg:SetAttribute("Weak", true)
			q.Mode = "Recover"
			q.ModeUntil = os.clock() + 2.4
		else
			startCircle(den, q, 2)
		end
	end
end

function SeaKing.Mash(den, player: Player)
	local g = den.Grab
	if not g or g.Player ~= player then return end
	g.Mash += 1
	if g.Mash >= 12 then SeaKing.Release(den, "Mash") end
end

-- the whirlpool (phase 3, the last stretch): pulls everyone toward the middle while it lunges out of it. It dives
-- first and comes up spinning in the middle (it used to blink there from out past the rock)
local function doWhirl(den, q)
	local tok, phase = claim(q), den.Phase
	q.NextWhirl = os.clock() + 26
	task.spawn(function()
		local c = den.Maw and den.Maw.Center or den.Bay
		q.Cfg:SetAttribute("Fin", nil)
		Encounter.SetState(q, "Submerge")
		if not sleep(den, q, tok, phase, 0.6) then return end
		setPos(q, Vector3.new(c.X, den.WaterY - 3, c.Z))
		q.Mode = "Whirl"
		q.ModeUntil = os.clock() + 9
		q.NextLunge = os.clock() + 1.8
		Encounter.SetState(q, "Whirl")
		Encounter.FireSite(den, "SeaWhirl", { O = c, Time = 9, Pull = 11, R = (den.Maw and den.Maw.Outer or 34) + 6, Inner = den.Maw and den.Maw.Inner or 14 })
	end)
end

--------------------------------------------------------------------------------
-- per tick
--------------------------------------------------------------------------------
function SeaKing.Begin(den, q)
	q.Custom = true
	q.Water = true
	local c, r = arena(den)
	-- (straight onto its circle: it's revealed swimming, not mid-dive)
	setPos(q, Vector3.new(c.X + r, den.WaterY, c.Z), c + Vector3.new(r, 0, 10))
	q.NextGrab = os.clock() + 20
	q.NextBall = os.clock() + 24
	startCircle(den, q, 6)
	fixDocks(den, true)
end

function SeaKing.Final(den, q)
	-- out at the Maw: it surfaces in the pool in the middle, then dives and comes round the outside
	q.Custom = true
	q.SeaTok = (q.SeaTok or 0) + 1
	q.Cfg:SetAttribute("Hidden", nil)
	local c = den.Maw and den.Maw.Center or den.Bay
	setPos(q, Vector3.new(c.X, den.WaterY, c.Z))
	Encounter.SetState(q, "Swim")
	q.NextWhirl = os.clock() + 8
	q.NextBall = os.clock() + 10
	q.Mode = "Recover" -- (a beat in the pool before it goes round: Recover's timer hands it to the circle)
	q.ModeUntil = os.clock() + 2.5
end

function SeaKing.PlaceOnMaw(player: Player, den)
	local spots = den.Maw and den.Maw.Spots
	if not spots or #spots == 0 then return end
	local char = player.Character
	if not char then return end
	local p = spots[rng:NextInteger(1, #spots)]
	char:PivotTo(CFrame.new(p + Vector3.new(0, 3.2, 0)))
end

-- where it throws itself when it's spent (the rodeo point). 2026-10-14, user: "the rodeo happens out of bounds, and
-- when it happens in bounds you can't do it". It always lands on solid footing every hunter can walk to, right
-- beside the hunter nearest it, inside the arena:
--   the Maw: lying ALONG the rock ring (a 32-stud body across it hung its head out over the open sea and its tail
--     in the pool), its head a few steps from that hunter, on the side with nobody under it
--   the bay: head and shoulders up on the nearest INTACT dock platform (a smashed one is fixed first if that's
--     all there is), tail trailing into the bay
--   already lying on the rock after a belly flop: it stays where it fell (no hop across the ring)
-- Returns where its body goes and the point it faces.
local function beachSpot(den, q): (Vector3, Vector3)
	local list = hunters(den)
	local len = Encounter.BodySize(q.Species or "", q.Scale or 1)
	local half = len / 2
	local function covers(p: Vector3, face: Vector3): number
		local probe = { Species = q.Species, Scale = q.Scale, Pos = p, Yaw = math.atan2(-(face - p).X, -(face - p).Z) }
		local n = 0
		for _, h in ipairs(list) do if Encounter.BodyGap(probe, h.Hrp.Position) < 1.5 then n += 1 end end
		return n
	end
	if den.Phase >= 3 and den.Maw then
		local m = den.Maw
		local c = m.Center
		local top = m.Top
		local r0 = flat(q.Pos - c).Magnitude
		if q.Pos.Y > den.WaterY + 0.5 and r0 >= m.Inner + 2 and r0 <= m.Outer - 2 then
			return Vector3.new(q.Pos.X, top, q.Pos.Z), q.Pos + Vector3.new(-math.sin(q.Yaw or 0), 0, -math.cos(q.Yaw or 0)) * 10
		end
		-- (the middle of the rock, a little in from it: flippers over the pool's lip, clear of the teeth on the rim)
		local rr = (m.Inner + m.Outer) / 2 - 2
		-- the hunter to land beside: whoever's on the rock (or nearest it, if everyone's swimming)
		local who, wd = nil, math.huge
		for _, h in ipairs(list) do
			local d = math.abs(flat(h.Hrp.Position - c).Magnitude - rr) + (inWater(den, h.Hrp) and 20 or 0)
			if d < wd then who, wd = h, d end
		end
		local a0
		if who then
			local d = flat(who.Hrp.Position - c)
			a0 = math.atan2(d.Z, d.X)
		else
			local s1 = m.Spots[1] or (c + Vector3.new(rr, 0, 0))
			a0 = math.atan2(s1.Z - c.Z, s1.X - c.X)
		end
		local ringAt = function(a: number): Vector3 return Vector3.new(c.X + math.cos(a) * rr, top, c.Z + math.sin(a) * rr) end
		local gap = (half + 5) / rr -- its head ~5 studs short of them, along the ring
		local best, bestFace, bestN = nil, nil, math.huge
		for _, side in ipairs(rng:NextNumber() < 0.5 and { 1, -1 } or { -1, 1 }) do
			local p = ringAt(a0 + side * gap)
			local face = ringAt(a0 + side * gap * 0.5) -- (head along the ring, toward them)
			local n = covers(p, face)
			if n < bestN then best, bestFace, bestN = p, face, n end
		end
		return best :: Vector3, bestFace :: Vector3
	end
	-- the bay's docks
	local c = den.Bay
	local function brokenAt(sp: Vector3)
		for _, d in ipairs(den.Docks or {}) do
			if d.Broken and flat(d.Center - sp).Magnitude < d.R then return d end
		end
		return nil
	end
	local spots = den.DockSpots or {}
	local best, bd, bestBroken = nil, math.huge, nil
	for pass = 1, 2 do
		for _, sp in ipairs(spots) do
			local br = brokenAt(sp)
			if pass == 1 and br then continue end
			local dd = 0
			if #list > 0 then
				dd = math.huge
				for _, h in ipairs(list) do dd = math.min(dd, flat(h.Hrp.Position - sp).Magnitude) end
			end
			if dd < bd then best, bd, bestBroken = sp, dd, br end
		end
		if best then break end
	end
	if not best then
		local p = c + Vector3.new(0, 0, den.BayR)
		return Vector3.new(p.X, den.WaterY + 0.5, p.Z), c
	end
	if bestBroken then
		-- every dock near anyone is smashed: this one floats back up as it hauls itself onto it
		bestBroken.FixAt = 0
		fixDocks(den, false)
	end
	local out = flat(best - c)
	out = out.Magnitude > 0.1 and out.Unit or Vector3.new(0, 0, 1)
	local deck = math.max(den.WaterY + 0.5, best.Y - 0.5) -- (DockSpot markers sit 0.5 over the planks)
	-- head over the platform (its nose at the far edge), body and tail down into the bay
	local p = Vector3.new(best.X, deck, best.Z) + out * (4 - half)
	return p, p + out * 10
end

function SeaKing.Tick(den, q, dt: number)
	local now = os.clock()
	fixDocks(den, false)
	if now < (den.FreezeUntil or 0) then return end
	-- the storm: once it's angry out at the Maw, the sky goes with it
	if den.Phase >= 3 and q.Enraged and not den.Folder:GetAttribute("Storm") then den.Folder:SetAttribute("Storm", true) end
	-- the rodeo point: it beaches itself on the ring/dock nearest the hunters, belly up, waiting for a rider
	if q.State == "Exhausted" then
		if not q.Beached then
			-- whatever it was doing stops: let go of anyone in its jaws, the whirlpool spins down
			q.SeaTok = (q.SeaTok or 0) + 1
			q.Cfg:SetAttribute("Fin", nil)
			q.Cfg:SetAttribute("Weak", nil)
			if den.Grab then SeaKing.Release(den, "Lost") end
			if q.Mode == "Whirl" then Encounter.FireSite(den, "SeaWhirl", { O = den.Maw and den.Maw.Center or den.Bay, Time = 0 }) end
			q.Mode = "Exhausted"
			q.ExhaustedAt = now
			q.Beached = true
			local at, face = beachSpot(den, q)
			q.PubAt = nil -- (never throttled away: this spot is where the rodeo is checked from)
			setPos(q, at, face)
			-- (the client draws the heave up onto the deck; this is the crash of it landing)
			Encounter.FireSite(den, "SeaSplash", { At = Vector3.new(at.X, den.WaterY, at.Z), Size = 2.4 })
			Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Beach", At = at, Actor = q.Id })
		end
		-- nobody climbed on in time: it slides back into the water, recovered a little
		if now - (q.ExhaustedAt or now) > 7 then
			q.Calm = q.CalmMax * 0.7
			q.Cfg:SetAttribute("Calm", q.Calm)
			q.Cfg:SetAttribute("RodeoOpen", nil)
			q.Beached = nil
			startCircle(den, q, 2.5)
			Encounter.PublishSite(den)
		end
		return
	end
	q.Beached = nil
	if q.State == "Rodeo" or q.State == "KO" then return end
	-- a failed rodeo throws it back to "Chase": back to circling
	if q.State == "Chase" or q.State == "Idle" then
		q.SeaTok = (q.SeaTok or 0) + 1
		startCircle(den, q, 2.5)
	end
	-- the grab: drag the victim toward the middle, chewing; teammates dart it free, or the victim mashes free
	if q.Mode == "Drag" then
		local g = den.Grab
		if not g then startCircle(den, q, 1.5) return end
		local st = den.Players[g.Player]
		if not st or st.Downed or not g.Player.Parent then SeaKing.Release(den, "Lost") return end
		local c = arena(den)
		local to = flat(c - q.Pos)
		-- (at the Maw it drags you round through the water it's in - the pool or outside - never through the rock)
		if den.Phase >= 3 and den.Maw then
			local r = math.max(4, flat(q.Pos - c).Magnitude)
			local a = math.atan2(q.Pos.Z - c.Z, q.Pos.X - c.X) + dt * 7 / r
			local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * r
			setPos(q, Vector3.new(p.X, den.WaterY, p.Z), nil, 7)
		elseif to.Magnitude > 3 then
			setPos(q, q.Pos + to.Unit * math.min(to.Magnitude, 7 * dt), c, 7)
		end
		if now >= g.NextBite then g.NextBite = now + 1 Encounter.Hurt(den, g.Player, dmg(den, 9), "Drag") end
		if now >= g.Until then SeaKing.Release(den, "Timeout") end
		return
	end
	if q.Mode == "Recover" then
		if now >= (q.ModeUntil or 0) then startCircle(den, q, 2.4) end
		return
	end
	if q.Mode == "Whirl" then
		-- lunges out of the vortex every couple of seconds; when it spins down it's left exhausted for a moment
		local c = den.Maw and den.Maw.Center or den.Bay
		if now >= (q.NextLunge or 0) then
			q.NextLunge = now + 2.4
			local t = 1.05
			local k = key()
			local R = (den.Maw and den.Maw.Inner or 14) + 3
			Encounter.FireSite(den, "Tele", { Actor = q.Id, Key = k, Id = "WhirlLunge", Shape = "Circle", O = Vector3.new(c.X, den.Maw and den.Maw.Top or 1.6, c.Z), R = R, Time = t, Surface = surface(den) })
			task.delay(t, function()
				-- (a reset, a defeat or the rodeo point since it was drawn: no lunge out of a whirlpool that's gone)
				if not q.Cfg.Parent or den.Phase ~= 3 or q.Mode ~= "Whirl" or q.State == "Exhausted" or q.State == "Rodeo" or q.State == "KO" then return end
				Encounter.SetState(q, "Breach")
				setPos(q, Vector3.new(c.X, den.WaterY, c.Z))
				for _, h in ipairs(hunters(den)) do
					if flat(h.Hrp.Position - c).Magnitude <= R then Encounter.Hurt(den, h.Player, dmg(den, 38), "WhirlLunge") end
				end
				Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = "WhirlLunge", Key = k })
				Encounter.FireSite(den, "SeaSplash", { At = c, Size = 2 })
				task.delay(0.8, function() if q.Cfg.Parent and den.Phase == 3 and q.Mode == "Whirl" and q.State == "Breach" then Encounter.SetState(q, "Whirl") setPos(q, Vector3.new(c.X, den.WaterY - 3, c.Z)) end end)
			end)
		end
		if now >= (q.ModeUntil or 0) then
			Encounter.FireSite(den, "SeaWhirl", { O = c, Time = 0 })
			setPos(q, Vector3.new(c.X, den.WaterY, c.Z))
			Encounter.SetState(q, "Recover")
			q.Cfg:SetAttribute("Weak", true)
			q.Mode = "Recover"
			q.ModeUntil = now + 3.4
		end
		return
	end
	if q.Mode == "Busy" then
		-- (a scripted move is playing out; a safety net in case one got stuck)
		q.BusySince = q.BusySince or now
		if now - q.BusySince > 12 then
			q.BusySince = nil
			q.SeaTok = (q.SeaTok or 0) + 1
			startCircle(den, q, 2)
		end
		return
	end
	q.BusySince = nil
	if q.Mode == "Circle" then
		local c, r = arena(den)
		-- going under to get round to its circle (from a dock, the rock or the pool): when it's deep, it moves there
		-- unseen and comes up swimming
		if q.DiveUntil then
			if now < q.DiveUntil then return end
			q.DiveUntil = nil
			q.CR = r
			local p0 = c + Vector3.new(math.cos(q.Angle or 0), 0, math.sin(q.Angle or 0)) * r
			setPos(q, Vector3.new(p0.X, den.WaterY, p0.Z), p0 + Vector3.new(-math.sin(q.Angle or 0), 0, math.cos(q.Angle or 0)))
			Encounter.SetState(q, "Swim")
		end
		-- swim the circle, back out of the water: easy to hit, a bit faster when enraged. It eases out to its
		-- radius from wherever it surfaced (no jump to the circle)
		q.CR = (q.CR or r) + math.clamp(r - (q.CR or r), -8 * dt, 8 * dt)
		local cr = math.max(8, q.CR)
		local speed = (q.Enraged and 26 or 21) / cr
		q.Angle = (q.Angle or 0) + speed * dt
		local p = Vector3.new(c.X + math.cos(q.Angle) * cr, den.WaterY, c.Z + math.sin(q.Angle) * cr)
		local tangent = Vector3.new(-math.sin(q.Angle), 0, math.cos(q.Angle))
		setPos(q, p, p + tangent, speed * cr)
		if now >= (q.ModeUntil or 0) then
			-- pick the next move: grabs when someone's in the water, the whirlpool near the end, the cannonball when
			-- it's ready (once it's been hurt a little), else breach/slam
			local frac = q.Calm / q.CalmMax
			local anyWet = false
			for _, h in ipairs(hunters(den)) do if inWater(den, h.Hrp) then anyWet = true end end
			local ballReady = now >= (q.NextBall or 0) and (den.Phase >= 3 or frac >= 0.15)
			if den.Phase >= 3 and frac >= 0.74 and now >= (q.NextWhirl or 0) then doWhirl(den, q)
			elseif (anyWet or rng:NextNumber() < 0.25) and now >= (q.NextGrab or 0) then doGrab(den, q)
			elseif ballReady and rng:NextNumber() < 0.6 and doCannonball(den, q) then -- (doCannonball: false = nobody to land on)
			elseif rng:NextNumber() < 0.55 then doBreach(den, q)
			else doTailSlam(den, q) end
		end
	end
end

function SeaKing.Reset(den)
	den.Grab = nil
	-- (a whirlpool still spinning when the fight ends spins down on every screen, not after its full 9 s of pull)
	for _, a in ipairs(den.Actors or {}) do
		if a.Boss and a.Mode == "Whirl" then
			a.Mode = nil
			Encounter.FireSite(den, "SeaWhirl", { O = den.Maw and den.Maw.Center or den.Bay, Time = 0 })
		end
	end
	if den.Docks then fixDocks(den, true) end
	if den.Folder then den.Folder:SetAttribute("Storm", nil) end
	for _, a in ipairs(den.Actors or {}) do
		if a.Boss then
			a.SeaTok = (a.SeaTok or 0) + 1
			if a.Cfg.Parent then a.Cfg:SetAttribute("Fin", nil) end
		end
	end
end

return SeaKing
