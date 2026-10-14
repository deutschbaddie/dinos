--[[
	LandKings — each land boss's signature move, on top of its species' normal attacks (Bosses.luau runs the den;
	the sea boss has its own fight in SeaKing.luau). One idea per boss, and each one asks something different of you:

	  TYRANT KING   KING'S ROAR   it plants its feet and roars three shockwave rings out across the lair: ROLL
	                              THROUGH each ring as it reaches you (a perfect dodge), or be flattened
	                RAMPAGE       (the final stand) three charges in a row across the arena; the last one ends in the
	                              wall and it's dazed for a long weak-spot window
	  PLAINS TITAN  STAMPEDE      it bellows and a herd thunders across the den in lanes: find the gap
	                BONE BREAKER  a huge charge at you: get out of the lane and it ploughs into the rocks, dazed
	  SCYTHE KING   CROSSGUARD    it crosses its claws: darts glance off, and every dart that does is answered with a
	                              lightning slash at the shooter. Roll THROUGH that slash and the guard breaks open
	                HARVEST       a full spinning sweep around it: the only safe place is hugging its legs
	  FROSTFANG     WHITEOUT      a blizzard swallows the arena; it vanishes into it and circles you - watch for the
	                              eyes - then pounces out of the white
	  DAWN KING     MUD DIVE      it sinks into the ground and a ridge of sand hunts you; when it stops, it erupts:
	                              keep moving and roll when the ground goes red
	                TERROR ROAR   (once it's angry) an old-world roar: anyone in front is slowed with fear

	New moves (2026-10-14, "make the fights more epic"): one more each, all telegraphed, all beatable with a roll:
	  TYRANT KING   TRIPLE CHOMP  three snapping bites, stepping in after you with each one; winded after
	  PLAINS TITAN  GROUND POUND  it rears and slams: a shockwave ring rolls out - JUMP or roll it as it reaches you
	  SCYTHE KING   RAZOR WIND    a fan of crescent blades flies out: stand in a gap (angry: a second fan fills them)
	  FROSTFANG     ICE SPIKES    spikes burst out of the ground in a line racing at you (angry: three lines)
	  DAWN KING     SAND TRAP     it plunges its jaws into the sand: a sinkhole drags everyone toward its mouth -
	                              run against it; it snaps shut, then it's stuck in the sand for a moment

	THE ARENA TURNS (a set piece, twice a fight: at 20% calm in the den, and when it gets angry at the final stand):
	it stops, roars, the camera shakes, and from then on the arena itself is a hazard - each one drawn red before
	it lands: falling trees (Tyrant King), fissures splitting the plain (Titan), boulders off the cliffs (Scythe),
	icicles (Frostfang), sand geysers (Dawn King).
	KNOCKED DOWN (teamwork): hit it hard and fast - weak-spot darts count double, buddies' bites count too - and
	it crashes onto its side for a long weak window. The more hunters, the more it takes; once every ~25 s.

	Moves are scripted coroutines that own the boss while they run (q.Custom); they stop at once if the fight moves on
	(a phase change, the rodeo window, a knockout). Damage is a share of the boss's own first attack (already
	scaled for its era), so every move hits as hard as that boss should.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").DinoExpedition.Game.Config)

local LandKings = {}
local Encounter, Net
local rng = Random.new()

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
local function unit(v: Vector3, fallback: Vector3?): Vector3
	local f = flat(v)
	return f.Magnitude > 0.05 and f.Unit or (fallback or Vector3.new(0, 0, -1))
end
local function yawOf(d: Vector3): number return math.atan2(-d.X, -d.Z) end

function LandKings.Setup(deps)
	Encounter, Net = deps.Encounter, deps.Net
end

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------
-- hunters standing in the den right now (not downed)
local function hunters(den)
	local out = {}
	for plr, st in pairs(den.Players) do
		local h = Encounter.HrpOf(plr)
		if h and not st.Downed then table.insert(out, { Player = plr, Hrp = h, St = st }) end
	end
	return out
end
local function nearestHunter(den, p: Vector3)
	local best, bd = nil, math.huge
	for _, h in ipairs(hunters(den)) do
		local d = flat(h.Hrp.Position - p).Magnitude
		if d < bd then best, bd = h, d end
	end
	return best, bd
end
local function base(q): number
	local a = q.Attacks and q.Attacks[1]
	return (a and a.Dmg) or 30
end
local function floorAt(den, p: Vector3): Vector3
	return Vector3.new(p.X, Encounter.GroundY(den, p, den.Center.Y), p.Z)
end
local airRay = RaycastParams.new()
airRay.FilterType = Enum.RaycastFilterType.Exclude
airRay.RespectCanCollide = true
-- off the ground right now? (jumping a shockwave)
local function airborne(hrp: BasePart): boolean
	airRay.FilterDescendantsInstances = hrp.Parent and { hrp.Parent } or {}
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -9, 0), airRay)
	return hit == nil or (hrp.Position.Y - hit.Position.Y) > 4.1
end
local function face(q, toward: Vector3)
	q.Yaw = yawOf(unit(toward - q.Pos, Vector3.new(-math.sin(q.Yaw), 0, -math.cos(q.Yaw))))
	Encounter.PublishActor(q, 0)
end
local function announce(den, q, move: string, name: string, hint: string)
	Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = move, Name = name, Hint = hint, Actor = q.Id })
end

-- is this move still allowed to run? (a phase change, the rodeo window or a knockout takes the boss back)
local function live(den, q, token: number): boolean
	if not q.Cfg.Parent or q.MoveToken ~= token then return false end
	local st = q.State
	if st == "Exhausted" or st == "Rodeo" or st == "KO" or st == "Hidden" then return false end
	return den.Phase == 1 or den.Phase == 3
end
-- sleep inside a move; false if it was interrupted meanwhile
local function waitLive(den, q, token: number, t: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < t do
		task.wait(math.min(0.05, t))
		if not live(den, q, token) then return false end
	end
	return true
end

-- hand the boss back to its normal fighting brain
local function release(q, token: number)
	if q.MoveToken ~= token then return end
	q.Custom = nil
	q.Guard = nil
	q.Cfg:SetAttribute("Guard", nil)
	local st = q.State
	if st ~= "Exhausted" and st ~= "Rodeo" and st ~= "KO" and st ~= "Hidden" then
		Encounter.SetState(q, "Chase")
		q.NextAttack = os.clock() + 1.1
	end
end

-- dazed: the long weak-spot window a good read earns you
local function daze(den, q, token: number, dur: number)
	Encounter.SetState(q, "Dazed")
	q.Cfg:SetAttribute("Weak", true)
	Encounter.PublishActor(q, 0)
	waitLive(den, q, token, dur)
	if q.Cfg.Parent then q.Cfg:SetAttribute("Weak", nil) end
end

-- a charge down a lane: drawn, wound up, then the body really travels it and hits whoever is still in the lane
-- when it gets to them. Returns (how many it hit, did it stop short against the arena edge)
local function charge(den, q, token: number, dir: Vector3, len: number, width: number, tele: number, dmg: number, id: string, speed: number?)
	dir = unit(dir)
	-- never out of the arena: a charge that would leave it stops at the edge (that's the "wall")
	local from = q.Pos
	local edge = false
	local fitted = false
	for k = len, 4, -2 do
		local to = from + dir * k
		if flat(to - den.Center).Magnitude <= den.Radius - 2 then
			edge = k < len - 0.5
			len = k
			fitted = true
			break
		end
	end
	if not fitted then
		-- already at the edge facing out: a short lunge, and that's the wall
		len = 6
		edge = true
	end
	local shape = { Id = id, Shape = "Line", O = from, Dir = dir, Len = len, Width = width, Dmg = dmg, Key = nil :: string? }
	q.Yaw = yawOf(dir)
	q.Cfg:SetAttribute("Attack", id)
	q.Cfg:SetAttribute("TeleTime", tele)
	local dur = len / (speed or 70)
	q.Cfg:SetAttribute("TeleDash", dur)
	Encounter.SetState(q, "Telegraph")
	Encounter.PublishActor(q, 0)
	Encounter.ShowShape(den, q, shape, tele)
	if not waitLive(den, q, token, tele) then return 0, false end
	Encounter.SetState(q, "Attack")
	Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = id, Dash = dur, Key = shape.Key })
	local hit = {} :: { [Player]: boolean }
	local n = 0
	local t0 = os.clock()
	while true do
		local u = math.clamp((os.clock() - t0) / dur, 0, 1)
		local done = len * u
		q.Pos = floorAt(den, from + dir * done)
		Encounter.PublishActor(q, len / dur)
		-- the body reaches you: still in the lane = hit (a roll through it = a perfect dodge)
		for plr, st in pairs(den.Players) do
			if not hit[plr] and not st.Downed then
				local h = Encounter.HrpOf(plr)
				if h then
					local along = flat(h.Position - from):Dot(dir)
					if along <= done + 2 and along >= done - 6 and Encounter.InShape(shape, h.Position) then
						hit[plr] = true
						local before = st.HP
						Encounter.StrikePlayer(den, q, shape, plr)
						if st.HP < before then n += 1 end
					end
				end
			end
		end
		for _, b in pairs(den.Buddies) do
			if not hit[b] and not b.Downed and not b.Fallen and Encounter.InShape(shape, b.Pos) and flat(b.Pos - from):Dot(dir) <= done + 2 then
				hit[b] = true
				Encounter.HurtBuddy(den, b, dmg * (den.DamageMult or 1))
			end
		end
		if u >= 1 or not live(den, q, token) then break end
		RunService.Heartbeat:Wait()
	end
	return n, edge
end

--------------------------------------------------------------------------------
-- the moves
--------------------------------------------------------------------------------
local Moves = {}

-- TYRANT KING: three shockwave rings rolling out from it
function Moves.KingsRoar(den, q, token)
	announce(den, q, "KingsRoar", "KING'S ROAR!", "")
	local t = nearestHunter(den, q.Pos)
	if t then face(q, t.Hrp.Position) end
	Encounter.SetState(q, "Roaring")
	if not waitLive(den, q, token, 0.55) then return end
	local B = base(q)
	local o = q.Pos
	local rings = { { 3, 11 }, { 11, 20 }, { 20, 30 } }
	for i, rr in ipairs(rings) do
		task.spawn(function()
			local shape = { Id = "KingsRoar", Shape = "Ring", O = o, R = rr[2], Inner = rr[1], Dmg = B * 0.55 }
			Encounter.ShowShape(den, q, shape, 0.8)
			task.wait(0.8)
			if live(den, q, token) then Encounter.LandShape(den, q, shape) end
		end)
		if i < #rings and not waitLive(den, q, token, 0.42) then return end
	end
	if not waitLive(den, q, token, 1.0) then return end
	-- winded after the roar: a short opening
	Encounter.SetState(q, "Recover")
	q.Cfg:SetAttribute("Weak", true)
	waitLive(den, q, token, 1.4)
	if q.Cfg.Parent then q.Cfg:SetAttribute("Weak", nil) end
end

-- TYRANT KING (final stand): three charges, the last into the wall
function Moves.Rampage(den, q, token)
	announce(den, q, "Rampage", "RAMPAGE!", "")
	local B = base(q)
	local crashed = false
	for i = 1, 3 do
		local t = nearestHunter(den, q.Pos)
		local dir = t and (t.Hrp.Position - q.Pos) or -flat(q.Pos - den.Center)
		-- the first two run THROUGH where you are and pull up; the third doesn't stop until the wall
		local dist = flat(dir).Magnitude
		local len = i < 3 and math.clamp(dist + 14, 18, 46) or 80
		charge(den, q, token, dir, len, 9, i == 1 and 1.0 or 0.7, B * 1.0, "Rampage", 74)
		if not live(den, q, token) then return end
		if i == 3 then
			crashed = true
			Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Crash", At = q.Pos, Actor = q.Id, Name = "CRASHED!", Hint = "" })
			break
		end
		Encounter.SetState(q, "Chase")
		if not waitLive(den, q, token, 0.35) then return end
	end
	if crashed then daze(den, q, token, 3.0) end
end

-- PLAINS TITAN: a herd stampedes across the den in lanes
function Moves.Stampede(den, q, token)
	announce(den, q, "Stampede", "STAMPEDE!", "")
	Encounter.SetState(q, "Roaring")
	if not waitLive(den, q, token, 0.9) then return end
	local B = base(q)
	local axis = unit(Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
	local side = axis:Cross(Vector3.yAxis)
	local R = math.max(24, den.Radius - 4)
	local lanes = { -16, 0, 16, -8, 8 }
	-- one gap stays open (a lane nobody runs): shuffle and leave one out
	for i = #lanes, 2, -1 do local j = rng:NextInteger(1, i) lanes[i], lanes[j] = lanes[j], lanes[i] end
	table.remove(lanes)
	local herd = { "Parasaurolophus", "Triceratops" }
	for i, lane in ipairs(lanes) do
		local from = floorAt(den, den.Center - axis * R + side * lane)
		local runner = Encounter.NewActor(den, herd[(i % 2) + 1], from, { Minion = true, Calm = 1e9, Scale = 0.9 })
		runner.Custom = true
		runner.Herd = true
		runner.Yaw = yawOf(axis)
		Encounter.SetState(runner, "Herd") -- (not a dart target: it's scenery that hurts)
		Encounter.PublishActor(runner, 0)
		task.spawn(function()
			local tele = 1.0 + (i - 1) * 0.35
			local shape = { Id = "Stampede", Shape = "Line", O = from, Dir = axis, Len = R * 2, Width = 9, Dmg = B * 0.8 }
			runner.Cfg:SetAttribute("Attack", "Stampede")
			Encounter.ShowShape(den, runner, shape, tele)
			task.wait(tele)
			if not runner.Cfg.Parent then return end
			Encounter.SetState(runner, "Charge")
			local speed = 52
			local dur = (R * 2) / speed
			local hit = {} :: { [any]: boolean }
			local t0 = os.clock()
			while runner.Cfg.Parent do
				local u = math.clamp((os.clock() - t0) / dur, 0, 1)
				local done = R * 2 * u
				runner.Pos = floorAt(den, from + axis * done)
				Encounter.PublishActor(runner, speed)
				-- (the herd thunders on through the rodeo window, but it never tramples the rider)
				local riding = q.State == "Rodeo" or q.State == "KO"
				for plr, st in pairs(den.Players) do
					local h = not riding and Encounter.HrpOf(plr)
					if h and not hit[plr] and not st.Downed then
						local along = flat(h.Position - from):Dot(axis)
						if along <= done + 3 and along >= done - 7 and Encounter.InShape(shape, h.Position) then
							hit[plr] = true
							Encounter.StrikePlayer(den, runner, shape, plr)
						end
					end
				end
				if u >= 1 then break end
				RunService.Heartbeat:Wait()
			end
			-- off into the long grass
			if runner.Cfg.Parent then runner.Cfg:Destroy() end
			local idx = table.find(den.Actors, runner)
			if idx then table.remove(den.Actors, idx) end
		end)
	end
	if not waitLive(den, q, token, 1.0 + #lanes * 0.35 + (R * 2) / 52) then return end
end

-- PLAINS TITAN: bait the big charge into the rocks
function Moves.BoneBreaker(den, q, token)
	announce(den, q, "BoneBreaker", "BONE BREAKER!", "")
	local t = nearestHunter(den, q.Pos)
	if not t then return end
	face(q, t.Hrp.Position)
	Encounter.SetState(q, "Roaring")
	if not waitLive(den, q, token, 0.5) then return end
	local n = charge(den, q, token, t.Hrp.Position - q.Pos, 90, 11, 1.25, base(q) * 1.25, "BoneBreaker", 80)
	if not live(den, q, token) then return end
	if n == 0 then
		-- missed everyone: it runs out of arena and ploughs into the rocks
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Crash", At = q.Pos, Actor = q.Id, Name = "CRASHED!", Hint = "" })
		daze(den, q, token, 3.2)
	end
end

-- SCYTHE KING: the guard (answered on the dart hook below)
function Moves.Crossguard(den, q, token)
	announce(den, q, "Crossguard", "CROSSGUARD!", "")
	local t = nearestHunter(den, q.Pos)
	if t then face(q, t.Hrp.Position) end
	Encounter.SetState(q, "Guard")
	q.Guard = true
	q.Cfg:SetAttribute("Guard", true)
	q.GuardBroken = nil
	q.Countering = nil
	local t0 = os.clock()
	while os.clock() - t0 < 5.0 do
		if not waitLive(den, q, token, 0.1) then return end
		if q.GuardBroken then
			-- somebody rolled through the counter: the claws are open
			q.Guard = nil
			q.Cfg:SetAttribute("Guard", nil)
			Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "GuardBreak", At = q.Pos, Actor = q.Id, Name = "GUARD BROKEN!", Hint = "" })
			daze(den, q, token, 2.8)
			return
		end
	end
	-- nobody took the bait: it opens with a sweep
	q.Guard = nil
	q.Cfg:SetAttribute("Guard", nil)
	local tt = nearestHunter(den, q.Pos)
	if tt then
		local dir = unit(tt.Hrp.Position - q.Pos)
		local shape = { Id = "ScytheSweep", Shape = "Cone", O = q.Pos, Dir = dir, Len = 22, Angle = 140, Dmg = base(q) * 0.9 }
		q.Yaw = yawOf(dir)
		q.Cfg:SetAttribute("Attack", "ScytheSweep")
		q.Cfg:SetAttribute("TeleTime", 0.9)
		q.Cfg:SetAttribute("TeleDash", nil)
		Encounter.SetState(q, "Telegraph")
		Encounter.ShowShape(den, q, shape, 0.9)
		if not waitLive(den, q, token, 0.9) then return end
		Encounter.LandShape(den, q, shape)
		waitLive(den, q, token, 0.4)
	end
end

-- SCYTHE KING: a dart hit its guard: an instant slash at the shooter. Roll through it to break the guard
function LandKings.OnGuardHit(den, q, player: Player)
	-- (not if the dart that hit the guard just left it exhausted: the rodeo window wins)
	if not q.Guard or q.Countering or not live(den, q, q.MoveToken) then return end
	local h = Encounter.HrpOf(player)
	local st = den.Players[player]
	if not (h and st) then return end
	q.Countering = true
	local token = q.MoveToken
	local dir = unit(h.Position - q.Pos)
	local shape = { Id = "XSlash", Shape = "Line", O = q.Pos, Dir = dir, Len = 28, Width = 8, Dmg = base(q) * 0.85 }
	q.Yaw = yawOf(dir)
	q.Cfg:SetAttribute("Attack", "XSlash")
	q.Cfg:SetAttribute("TeleTime", 0.55)
	q.Cfg:SetAttribute("TeleDash", nil)
	Encounter.SetState(q, "Telegraph")
	Encounter.PublishActor(q, 0)
	Encounter.ShowShape(den, q, shape, 0.55)
	local perfectBefore = st.PerfectAt or 0
	task.wait(0.55)
	-- (the slash was drawn: it lands as long as this guard move is still the one running)
	if not (q.Cfg.Parent and q.MoveToken == token and live(den, q, token)) then q.Countering = nil return end
	Encounter.LandShape(den, q, shape)
	-- a perfect dodge THROUGH the slash (Encounter.hurt sets PerfectAt) breaks it open
	if (st.PerfectAt or 0) > perfectBefore then q.GuardBroken = true end
	task.wait(0.3)
	if q.Cfg.Parent and q.Guard and q.MoveToken == token and live(den, q, token) then Encounter.SetState(q, "Guard") end
	q.Countering = nil
end

-- SCYTHE KING: a spinning sweep - hug its legs
function Moves.Harvest(den, q, token)
	announce(den, q, "Harvest", "HARVEST!", "")
	Encounter.SetState(q, "Harvest")
	local shape = { Id = "Harvest", Shape = "Ring", O = q.Pos, R = 22, Inner = 6.5, Dmg = base(q) * 0.95 }
	Encounter.ShowShape(den, q, shape, 1.3)
	if not waitLive(den, q, token, 1.3) then return end
	Encounter.LandShape(den, q, shape)
	if not waitLive(den, q, token, 0.5) then return end
	Encounter.SetState(q, "Recover")
	q.Cfg:SetAttribute("Weak", true)
	waitLive(den, q, token, 1.5)
	if q.Cfg.Parent then q.Cfg:SetAttribute("Weak", nil) end
end

-- FROSTFANG: the whiteout stalk and the pounce out of it
function Moves.Whiteout(den, q, token)
	announce(den, q, "Whiteout", "WHITEOUT!", "")
	Encounter.SetState(q, "Roaring")
	if not waitLive(den, q, token, 0.8) then return end
	den.Folder:SetAttribute("Whiteout", true)
	Encounter.SetState(q, "Stalk")
	local t = nearestHunter(den, q.Pos)
	local ang = t and math.atan2(q.Pos.Z - t.Hrp.Position.Z, q.Pos.X - t.Hrp.Position.X) or 0
	local t0 = os.clock()
	local last = t0
	while os.clock() - t0 < 4.2 do
		RunService.Heartbeat:Wait()
		if not live(den, q, token) then den.Folder:SetAttribute("Whiteout", nil) return end
		local now = os.clock()
		local dt = now - last
		last = now
		t = nearestHunter(den, q.Pos) or t
		if t then
			-- circling you at the edge of what you can see
			ang += dt * 0.55
			local c = t.Hrp.Position
			local want = c + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 24
			if flat(want - den.Center).Magnitude > den.Radius - 3 then want = den.Center + unit(want - den.Center) * (den.Radius - 3) end
			local step = flat(want - q.Pos)
			if step.Magnitude > 0.2 then
				q.Pos = floorAt(den, q.Pos + step.Unit * math.min(step.Magnitude, 17 * dt))
				q.Yaw = yawOf(step)
			end
			Encounter.PublishActor(q, 17)
		end
	end
	if not t then den.Folder:SetAttribute("Whiteout", nil) return end
	-- out of the white
	charge(den, q, token, t.Hrp.Position - q.Pos, 40, 8, 0.8, base(q) * 1.05, "Pounce", 78)
	den.Folder:SetAttribute("Whiteout", nil)
	if live(den, q, token) then waitLive(den, q, token, 0.4) end
end

-- DAWN KING: under the sand, hunting
function Moves.MudDive(den, q, token)
	announce(den, q, "MudDive", "MUD DIVE!", "")
	Encounter.SetState(q, "Burrow")
	if not waitLive(den, q, token, 0.6) then return end
	local t = nearestHunter(den, q.Pos)
	local t0 = os.clock()
	local last = t0
	while os.clock() - t0 < 3.2 do
		RunService.Heartbeat:Wait()
		if not live(den, q, token) then return end
		local now = os.clock()
		local dt = now - last
		last = now
		-- (a hunter who went down or left the fight stops being the one it hunts)
		if not (t and t.Hrp.Parent and den.Players[t.Player] and not t.St.Downed) then t = nearestHunter(den, q.Pos) end
		if t then
			local step = flat(t.Hrp.Position - q.Pos)
			if step.Magnitude > 0.5 then
				local np = q.Pos + step.Unit * math.min(step.Magnitude, 19 * dt)
				-- never out of the arena: it surfaces inside it
				if flat(np - den.Center).Magnitude > den.Radius - 3 then np = den.Center + unit(np - den.Center) * (den.Radius - 3) end
				q.Pos = floorAt(den, np)
				q.Yaw = yawOf(step)
			end
			Encounter.PublishActor(q, 19)
		end
	end
	-- it stops; the ground goes red; it erupts
	local shape = { Id = "MudAmbush", Shape = "Circle", O = q.Pos, R = 10, Dmg = base(q) * 1.0 }
	q.Cfg:SetAttribute("Attack", "MudAmbush")
	Encounter.ShowShape(den, q, shape, 0.85)
	if not waitLive(den, q, token, 0.85) then return end
	Encounter.SetState(q, "Erupt")
	Encounter.LandShape(den, q, shape)
	if not waitLive(den, q, token, 0.7) then return end
	daze(den, q, token, 1.6)
end

-- DAWN KING: the terror roar (anyone in front is slowed for a few seconds)
function Moves.TerrorRoar(den, q, token)
	announce(den, q, "TerrorRoar", "TERROR ROAR!", "")
	local t = nearestHunter(den, q.Pos)
	if not t then return end
	local dir = unit(t.Hrp.Position - q.Pos)
	q.Yaw = yawOf(dir)
	Encounter.SetState(q, "Roaring")
	local shape = { Id = "TerrorRoar", Shape = "Cone", O = q.Pos, Dir = dir, Len = 30, Angle = 80, Dmg = base(q) * 0.35 }
	Encounter.ShowShape(den, q, shape, 1.0)
	if not waitLive(den, q, token, 1.0) then return end
	for plr, st in pairs(den.Players) do
		local h = Encounter.HrpOf(plr)
		if h and not st.Downed and Encounter.InShape(shape, h.Position) and os.clock() >= (st.Invuln or 0) then
			plr:SetAttribute("FearUntil", workspace:GetServerTimeNow() + 3)
		end
	end
	Encounter.LandShape(den, q, shape)
	waitLive(den, q, token, 0.8)
end

--------------------------------------------------------------------------------
-- the new moves (2026-10-14)
--------------------------------------------------------------------------------
-- a wind-up the client can time its animation to (the attack id is also the action it plays)
local function windUp(q, anim: string, tele: number)
	q.Cfg:SetAttribute("Attack", anim)
	q.Cfg:SetAttribute("TeleTime", tele)
	q.Cfg:SetAttribute("TeleDash", nil)
	Encounter.SetState(q, "Telegraph")
	Encounter.PublishActor(q, 0)
end

-- a shockwave ring rolling out from o (from -> to over t): it hits each hunter as its crest REACHES them, so the
-- jump (or the roll) is timed to the wave you can see. Its drawing was put up by the caller (key)
local function shockRing(den, q, token: number, o: Vector3, from: number, to: number, t: number, dmg: number, id: string, k: string?)
	local shape = { Id = id, Shape = "Ring", O = o, R = to, Inner = from, Dmg = dmg, Key = k }
	Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Shockwave", At = o, From = from, To = to, Time = t, Actor = q.Id })
	local done = {} :: { [any]: boolean }
	local t0 = os.clock()
	while true do
		RunService.Heartbeat:Wait()
		if not live(den, q, token) then break end
		local u = math.clamp((os.clock() - t0) / t, 0, 1)
		local crest = from + (to - from) * u
		for plr, st in pairs(den.Players) do
			if not done[plr] and not st.Downed then
				local h = Encounter.HrpOf(plr)
				if h then
					local d = flat(h.Position - o).Magnitude
					if d >= from - 0.5 and d <= to + 1 and crest >= d - 0.5 then
						done[plr] = true
						if not airborne(h) and math.abs(h.Position.Y - o.Y) < 10 then Encounter.StrikePlayer(den, q, shape, plr) end
					end
				end
			end
		end
		for _, b in pairs(den.Buddies) do
			if not done[b] and not b.Downed and not b.Fallen then
				local d = flat(b.Pos - o).Magnitude
				if d >= from - 0.5 and d <= to + 1 and crest >= d - 0.5 then
					done[b] = true
					Encounter.HurtBuddy(den, b, dmg * 0.6 * (den.DamageMult or 1))
				end
			end
		end
		if u >= 1 then break end
	end
	Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = id, Key = k })
end

-- TYRANT KING: three snapping bites, stepping in after you with each one
function Moves.TripleChomp(den, q, token)
	announce(den, q, "TripleChomp", "TRIPLE CHOMP!", "")
	local B = base(q)
	local angry = q.Enraged or den.Phase >= 3
	for i = 1, 3 do
		local t = nearestHunter(den, q.Pos)
		if not t then return end
		local dir = unit(t.Hrp.Position - q.Pos, Vector3.new(-math.sin(q.Yaw), 0, -math.cos(q.Yaw)))
		-- each bite steps in toward you first (a quick lunge, never out of the arena)
		if i > 1 then
			local from = q.Pos
			local step = math.clamp(flat(t.Hrp.Position - q.Pos).Magnitude - 8, 0, 7)
			local to = from + dir * step
			if flat(to - den.Center).Magnitude > den.Radius - 3 then to = from end
			local t0 = os.clock()
			while os.clock() - t0 < 0.14 do
				RunService.Heartbeat:Wait()
				if not live(den, q, token) then return end
				q.Pos = floorAt(den, from:Lerp(to, math.clamp((os.clock() - t0) / 0.14, 0, 1)))
				Encounter.PublishActor(q, step / 0.14)
			end
		end
		q.Yaw = yawOf(dir)
		local tele = (i == 1 and 0.7 or 0.5) * (angry and 0.85 or 1)
		local shape = { Id = "TripleChomp", Shape = "Cone", O = q.Pos, Dir = dir, Len = 16, Angle = 75, Dmg = B * 0.7 }
		windUp(q, "Bite", tele)
		Encounter.ShowShape(den, q, shape, tele)
		if not waitLive(den, q, token, tele) then return end
		Encounter.LandShape(den, q, shape)
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Chomp", At = q.Pos + dir * 9, Big = i == 3, Actor = q.Id })
		Encounter.SetState(q, "Attack")
		if not waitLive(den, q, token, 0.12) then return end
	end
	-- winded after the third: the opening
	Encounter.SetState(q, "Recover")
	q.Cfg:SetAttribute("Weak", true)
	waitLive(den, q, token, 1.6)
	if q.Cfg.Parent then q.Cfg:SetAttribute("Weak", nil) end
end

-- PLAINS TITAN: rears up and slams - a shockwave ring rolls out across the plain. Jump it (or roll it)
function Moves.GroundPound(den, q, token)
	announce(den, q, "GroundPound", "GROUND POUND!", "")
	local B = base(q)
	local n = (q.Enraged or den.Phase >= 3) and 3 or 2
	for i = 1, n do
		local o = floorAt(den, q.Pos)
		local wind = i == 1 and 0.9 or 0.6
		local roll = 1.15
		-- the ring is drawn from the moment it rears (wind-up + roll), so you see it coming the whole way
		local k = { Id = "GroundPound", Shape = "Ring", O = o, R = 32, Inner = 5, Dmg = B * 0.6, Key = nil :: string? }
		windUp(q, "Stomp", wind)
		Encounter.ShowShape(den, q, k, wind + roll)
		if not waitLive(den, q, token, wind) then return end
		Encounter.SetState(q, "Attack")
		shockRing(den, q, token, o, 5, 32, roll, B * 0.6, "GroundPound", k.Key)
		if not live(den, q, token) then return end
		if i < n and not waitLive(den, q, token, 0.15) then return end
	end
	Encounter.SetState(q, "Recover")
	q.Cfg:SetAttribute("Weak", true)
	waitLive(den, q, token, 1.4)
	if q.Cfg.Parent then q.Cfg:SetAttribute("Weak", nil) end
end

-- SCYTHE KING: a fan of crescent blades flies out of a cross-slash; each hits you when it reaches you
local function razorFan(den, q, token, center: Vector3, angles: { number }, B: number)
	local o = floorAt(den, q.Pos)
	local tele = 0.8
	local shapes = {}
	for _, a in ipairs(angles) do
		local dir = unit(CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(center))
		local s = { Id = "RazorWind", Shape = "Line", O = o, Dir = dir, Len = 44, Width = 5, Dmg = B * 0.75, Key = nil :: string? }
		Encounter.ShowShape(den, q, s, tele + 44 / 50)
		table.insert(shapes, s)
	end
	windUp(q, "XSlash", tele)
	if not waitLive(den, q, token, tele) then return false end
	Encounter.SetState(q, "Attack")
	for _, s in ipairs(shapes) do
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Razor", At = s.O, Dir = s.Dir, Len = s.Len, Speed = 50, Actor = q.Id })
	end
	-- the blades travel: in a lane when one gets to you = hit (one blade per hunter per fan)
	local hit = {} :: { [Player]: boolean }
	local t0 = os.clock()
	local dur = 44 / 50
	while true do
		RunService.Heartbeat:Wait()
		if not live(den, q, token) then return false end
		local done = 44 * math.clamp((os.clock() - t0) / dur, 0, 1)
		for plr, st in pairs(den.Players) do
			local h = not hit[plr] and not st.Downed and Encounter.HrpOf(plr)
			if h then
				for _, s in ipairs(shapes) do
					local along = flat(h.Position - s.O):Dot(s.Dir)
					if along <= done + 1.5 and along >= done - 5 and Encounter.InShape(s, h.Position) then
						hit[plr] = true
						Encounter.StrikePlayer(den, q, s, plr)
						break
					end
				end
			end
		end
		if done >= 44 then break end
	end
	for _, s in ipairs(shapes) do Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = "RazorWind", Key = s.Key }) end
	return true
end
function Moves.RazorWind(den, q, token)
	announce(den, q, "RazorWind", "RAZOR WIND!", "")
	local t = nearestHunter(den, q.Pos)
	if not t then return end
	local center = unit(t.Hrp.Position - q.Pos)
	q.Yaw = yawOf(center)
	local B = base(q)
	if not razorFan(den, q, token, center, { -26, 0, 26 }, B) then return end
	if q.Enraged or den.Phase >= 3 then
		-- the second fan fills the gaps the first one left
		if not waitLive(den, q, token, 0.2) then return end
		if not razorFan(den, q, token, center, { -39, -13, 13, 39 }, B) then return end
	end
	Encounter.SetState(q, "Recover")
	q.Cfg:SetAttribute("Weak", true)
	waitLive(den, q, token, 1.3)
	if q.Cfg.Parent then q.Cfg:SetAttribute("Weak", nil) end
end

-- FROSTFANG: ice spikes burst out of the ground in a line racing at you
local function spikeLine(den, q, token, dir: Vector3, B: number)
	local o = floorAt(den, q.Pos)
	local len, gap = 42, 4.5
	local s = { Id = "IceSpikes", Shape = "Line", O = o, Dir = dir, Len = len, Width = 6, Dmg = B * 0.6, Key = nil :: string? }
	Encounter.ShowShape(den, q, s, 0.9 + len / 60)
	return s, o, len, gap
end
function Moves.IceSpikes(den, q, token)
	announce(den, q, "IceSpikes", "ICE SPIKES!", "")
	local t = nearestHunter(den, q.Pos)
	if not t then return end
	local B = base(q)
	local center = unit(t.Hrp.Position - q.Pos)
	q.Yaw = yawOf(center)
	local angles = (q.Enraged or den.Phase >= 3) and { -32, 0, 32 } or { 0 }
	local lines = {}
	for _, a in ipairs(angles) do
		local dir = unit(CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(center))
		local s, o, len, gap = spikeLine(den, q, token, dir, B)
		table.insert(lines, { S = s, O = o, Len = len, Gap = gap })
	end
	windUp(q, "IceStomp", 0.9)
	if not waitLive(den, q, token, 0.9) then return end
	Encounter.SetState(q, "Attack")
	-- the spikes race out at 60 studs a second; each one hits whoever's standing over it as it bursts
	for _, l in ipairs(lines) do
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Spikes", At = l.O, Dir = l.S.Dir, Len = l.Len, Gap = l.Gap, Speed = 60, Actor = q.Id })
	end
	local hit = {} :: { [any]: boolean }
	local t0 = os.clock()
	local dur = 42 / 60
	while true do
		RunService.Heartbeat:Wait()
		if not live(den, q, token) then return end
		local done = 42 * math.clamp((os.clock() - t0) / dur, 0, 1)
		for _, l in ipairs(lines) do
			for plr, st in pairs(den.Players) do
				if not hit[plr] and not st.Downed then
					local h = Encounter.HrpOf(plr)
					if h then
						local along = flat(h.Position - l.O):Dot(l.S.Dir)
						if along <= done + 1 and along >= done - 4 and Encounter.InShape(l.S, h.Position) then
							hit[plr] = true
							Encounter.StrikePlayer(den, q, l.S, plr)
						end
					end
				end
			end
		end
		if done >= 42 then break end
	end
	for _, l in ipairs(lines) do Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = "IceSpikes", Key = l.S.Key }) end
	waitLive(den, q, token, 0.5)
end

-- DAWN KING: jaws plunged into the sand, a sinkhole drags everyone toward them (the client pulls you: run against
-- it), then they snap shut - and it's stuck in the sand for a moment
function Moves.SandTrap(den, q, token)
	announce(den, q, "SandTrap", "SAND TRAP!", "")
	local o = floorAt(den, q.Pos)
	local T = (q.Enraged or den.Phase >= 3) and 3.0 or 3.4
	local shape = { Id = "SandTrap", Shape = "Circle", O = o, R = 9, Dmg = base(q) * 1.1 }
	windUp(q, "MudAmbush", T)
	Encounter.ShowShape(den, q, shape, T)
	Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "SandTrap", At = o, R = 34, Inner = 9, Pull = 8, Time = T, Actor = q.Id })
	if not waitLive(den, q, token, T) then
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "SandTrap", At = o, Time = 0, Actor = q.Id })
		return
	end
	Encounter.SetState(q, "Erupt")
	Encounter.LandShape(den, q, shape)
	if not waitLive(den, q, token, 0.5) then return end
	daze(den, q, token, 1.8)
end

--------------------------------------------------------------------------------
-- the arena turns: a set piece, then hazards for the rest of that stretch of the fight
--------------------------------------------------------------------------------
local HAZARD = {
	TyrantKing = { Kind = "Tree", Name = "TIMBER!", Shape = "Line", Count = 2, Len = 28, Width = 6, Tele = 1.5, Every = 6.5 },
	Titan = { Kind = "Fissure", Name = "EARTHQUAKE!", Shape = "Line", Count = 2, Len = 30, Width = 5, Tele = 1.35, Every = 6.5 },
	Scythe = { Kind = "Boulder", Name = "ROCKSLIDE!", Shape = "Circle", Count = 2, R = 6, Tele = 1.4, Every = 6 },
	Frostfang = { Kind = "Icicle", Name = "ICEFALL!", Shape = "Circle", Count = 3, R = 4.5, Tele = 1.25, Every = 6 },
	DawnKing = { Kind = "Geyser", Name = "SAND GEYSERS!", Shape = "Circle", Count = 2, R = 5.5, Tele = 1.35, Every = 6 },
}

local function inArena(den, p: Vector3, margin: number): Vector3
	local off = flat(p - den.Center)
	if off.Magnitude > den.Radius - margin then p = den.Center + unit(off) * (den.Radius - margin) end
	return floorAt(den, p)
end

-- one wave of the arena's hazard, aimed near the hunters (one lands close to each, the rest anywhere)
local function hazardWave(den, q, hz, fight: number)
	local phase = den.Phase
	local list = hunters(den)
	if #list == 0 then return end
	local dmg = base(q) * 0.45
	for i = 1, hz.Count do
		local h = list[(i - 1) % #list + 1]
		local near = i <= #list
		local shape
		if hz.Shape == "Line" then
			local hp = h.Hrp.Position
			local dir, o
			if hz.Kind == "Tree" then
				-- a tree from the edge of the clearing, falling in across where you are (the extra ones anywhere)
				local base = math.atan2(hp.Z - den.Center.Z, hp.X - den.Center.X)
				local ang = near and base + rng:NextNumber(-0.35, 0.35) or rng:NextNumber(0, math.pi * 2)
				o = floorAt(den, den.Center + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (den.Radius - 2))
				local aim = near and hp or (den.Center + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)))
				dir = unit(aim - o)
			else
				-- a crack that runs right under you (or anywhere, for the extra ones)
				dir = unit(Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
				local mid = near and hp or (den.Center + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * den.Radius * 0.5)
				o = inArena(den, mid - dir * hz.Len * 0.5, 3)
			end
			shape = { Id = "Hazard", Shape = "Line", O = o, Dir = dir, Len = hz.Len, Width = hz.Width, Dmg = dmg }
		else
			local p = near and (h.Hrp.Position + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)))
				or (den.Center + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * den.Radius * 0.7)
			shape = { Id = "Hazard", Shape = "Circle", O = inArena(den, p, 4), R = hz.R, Dmg = dmg }
		end
		local tele = hz.Tele + (i - 1) * 0.18 -- (a little staggered: a rumble, not one thud)
		Encounter.ShowShape(den, q, shape, tele)
		Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Hazard", Kind = hz.Kind, At = shape.O, Dir = shape.Dir, Len = shape.Len, R = shape.R, Time = tele, Actor = q.Id })
		task.delay(tele, function()
			if den.Fight ~= fight or den.Phase ~= phase or not q.Cfg.Parent or q.State == "Rodeo" or q.State == "KO" then
				Encounter.FireSite(den, "Strike", { Actor = q.Id, Id = "Hazard", Key = shape.Key })
				return
			end
			Encounter.LandShape(den, q, shape)
		end)
	end
end

-- the set piece: it stops, roars, the arena turns
local function arenaShift(den, q, hz)
	q.MoveToken = (q.MoveToken or 0) + 1
	local token = q.MoveToken
	q.Custom = true
	q.Cfg:SetAttribute("Weak", nil)
	task.spawn(function()
		local ok, err = pcall(function()
			local t = nearestHunter(den, q.Pos)
			if t then face(q, t.Hrp.Position) end
			Encounter.SetState(q, "Roaring")
			Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "ArenaShift", Kind = hz.Kind, Name = hz.Name, Hint = "", At = q.Pos, Center = den.Center, Radius = den.Radius, Actor = q.Id })
			waitLive(den, q, token, 1.6)
		end)
		if not ok then warn("[LandKings] arena shift:", err) end
		release(q, token)
	end)
end

-- the hazards' own clock (one per fight): runs beside the boss's brain, never on top of a move's wind-up
local function hazardLoop(den, q, fight: number)
	local hz = HAZARD[den.BossId]
	if not hz then return end
	local nextAt = math.huge
	while den.Fight == fight and q.Cfg.Parent and den.Phase >= 1 and den.Phase <= 3 do
		task.wait(0.25)
		local now = os.clock()
		-- (the chase's darts add calm without passing through Encounter.Calm: the stagger starts from there, it
		-- doesn't count the whole chase as one burst at the final stand)
		if den.Phase == 2 then q.PoiseSeen = q.Calm end
		if now < (den.FreezeUntil or 0) or not den.Started then continue end
		local phase = den.Phase
		-- the set piece: the den at 20% calm, the final stand when it gets angry (once each)
		local want = (phase == 1 and q.Calm >= q.CalmMax * 0.2 and not q.Shift1) or (phase == 3 and q.Enraged and not q.Shift3)
		if want and not q.Custom and q.State == "Chase" then
			if phase == 1 then q.Shift1 = true else q.Shift3 = true end
			arenaShift(den, q, hz)
			nextAt = now + 2.6
			q.NextSig = math.max(q.NextSig or 0, now + 5)
		end
		local on = (phase == 1 and q.Shift1) or (phase == 3 and q.Shift3)
		-- (2026-10-14: no hazards while it's down for the rodeo or being ridden - nothing lands on the rider)
		local resting = q.State == "Exhausted" or q.State == "Rodeo" or q.State == "KO"
		if on and resting then
			nextAt = math.max(nextAt, now + 2)
		elseif on and now >= nextAt and not q.Custom then
			nextAt = now + hz.Every * ((q.Enraged or phase >= 3) and 0.85 or 1)
			hazardWave(den, q, hz, fight)
		elseif not on then
			nextAt = math.max(nextAt, now) -- (between phases: the clock waits for the next set piece)
		end
	end
end

--------------------------------------------------------------------------------
-- knocked down: hit it hard and fast and it goes over (teamwork pays)
--------------------------------------------------------------------------------
local function knockDown(den, q)
	q.MoveToken = (q.MoveToken or 0) + 1
	local token = q.MoveToken
	q.Custom = true
	q.NextKnock = os.clock() + 25
	task.spawn(function()
		local ok, err = pcall(function()
			q.Cfg:SetAttribute("Knocked", true)
			Encounter.FireSite(den, "BossMove", { Boss = den.BossId, Move = "Knockdown", Name = "KNOCKED DOWN!", Hint = "", At = q.Pos, Actor = q.Id })
			daze(den, q, token, 3.2)
		end)
		if not ok then warn("[LandKings] knockdown:", err) end
		if q.Cfg.Parent then q.Cfg:SetAttribute("Knocked", nil) end
		release(q, token)
		q.NextSig = math.max(q.NextSig or 0, os.clock() + 3)
	end)
end

-- every calm it takes (darts, buddies, gadgets) adds to its stagger; a big burst in a short window knocks it down.
-- Weak-spot hits count double; the more hunters in the fight, the bigger the burst it takes
local function onCalm(den, q)
	local now = os.clock()
	local seen = q.PoiseSeen or 0
	local dealt = q.Calm - seen
	q.PoiseSeen = q.Calm
	if dealt <= 0 then return end
	if q.Custom or (q.State ~= "Chase" and q.State ~= "Telegraph" and q.State ~= "Attack" and q.State ~= "Recover") then return end
	if den.Phase ~= 1 and den.Phase ~= 3 then return end
	local log = q.PoiseLog or {}
	q.PoiseLog = log
	table.insert(log, { T = now, A = dealt }) -- (a weak-spot dart already deals double)
	local sum = 0
	for i = #log, 1, -1 do
		if now - log[i].T > 3 then table.remove(log, i) else sum += log[i].A end
	end
	local n = 0
	for plr, st in pairs(den.Players) do if not st.Downed and plr.Parent then n += 1 end end
	local need = q.CalmMax * 0.08 * (1 + 0.6 * math.max(0, n - 1)) -- (solo: about a magazine of weak-spot darts)
	if sum >= need and now >= (q.NextKnock or 0) then
		table.clear(log)
		knockDown(den, q)
	end
end

--------------------------------------------------------------------------------
-- which boss does what, and when
--------------------------------------------------------------------------------
local SETS = {
	TyrantKing = { Den = { "KingsRoar", "TripleChomp" }, Final = { "Rampage", "TripleChomp", "KingsRoar" } },
	Titan = { Den = { "Stampede", "GroundPound", "BoneBreaker" }, Final = { "BoneBreaker", "GroundPound", "Stampede" } },
	Scythe = { Den = { "Crossguard", "RazorWind", "Harvest" }, Final = { "Harvest", "RazorWind", "Crossguard" } },
	Frostfang = { Den = { "Whiteout", "IceSpikes" }, Final = { "IceSpikes", "Whiteout" } },
	DawnKing = { Den = { "MudDive", "SandTrap" }, Final = { "MudDive", "SandTrap", "TerrorRoar" } },
}

function LandKings.Begin(den, q)
	q.NextSig = os.clock() + 9
	q.SigIndex = 0
	q.MoveToken = 0
	den.OnGuardHit = function(site, a, player)
		if a == q then LandKings.OnGuardHit(site, a, player) end
	end
	-- the knock-down stagger, and the arena's own clock (set pieces + hazards) for this fight
	q.PoiseSeen = q.Calm
	q.NextKnock = os.clock() + 20
	den.OnCalm = function(site, a)
		if a == q then onCalm(site, q) end
	end
	task.spawn(function()
		local ok, err = pcall(hazardLoop, den, q, den.Fight)
		if not ok then warn("[LandKings] hazards:", err) end
	end)
end

function LandKings.Tick(den, q, _dt: number)
	local set = SETS[den.BossId]
	if not set then return end
	local now = os.clock()
	if now < (den.FreezeUntil or 0) then q.NextSig = math.max(q.NextSig or 0, now + 6) return end
	if q.Custom or q.State ~= "Chase" or now < (q.NextSig or math.huge) then return end
	-- only when it's actually in the fight with someone close enough to read the move
	local _, d = nearestHunter(den, q.Pos)
	if d > 60 then return end
	local list = den.Phase >= 3 and set.Final or set.Den
	-- the next move in its rotation (the final stand can pick the angry one when it's angry)
	q.SigIndex = (q.SigIndex or 0) % #list + 1
	local move = list[q.SigIndex]
	if move == "TerrorRoar" and not (q.Enraged or den.Enraged) then move = list[1] end
	local fn = Moves[move]
	if not fn then return end
	q.MoveToken = (q.MoveToken or 0) + 1
	local token = q.MoveToken
	q.Custom = true
	q.Cfg:SetAttribute("Weak", nil)
	task.spawn(function()
		local ok, err = pcall(fn, den, q, token)
		if not ok then warn("[LandKings] " .. move .. ":", err) end
		release(q, token)
		local angry = den.Phase >= 3 or q.Enraged
		local pace = Config.Encounter.BossPace and Config.Encounter.BossPace.Sig or 1
		q.NextSig = os.clock() + (angry and rng:NextNumber(8, 11) or rng:NextNumber(12, 16)) * pace
	end)
end

-- the fight moved on (a phase change): whatever it was doing stops now
function LandKings.Cancel(den, q)
	if not q then return end
	q.MoveToken = (q.MoveToken or 0) + 1
	q.Custom = nil
	q.Guard = nil
	if q.Cfg.Parent then
		q.Cfg:SetAttribute("Guard", nil)
		q.Cfg:SetAttribute("Knocked", nil)
	end
	den.Folder:SetAttribute("Whiteout", nil)
	-- any herd still running leaves
	for i = #den.Actors, 1, -1 do
		local a = den.Actors[i]
		if a.Herd then
			a.Cfg:Destroy()
			table.remove(den.Actors, i)
		end
	end
	local _ = Players
	local _n = Net
end

return LandKings
