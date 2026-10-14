--[[
	Chase — server-authoritative creature AI for expeditions. Nothing is scripted to a timeline:
	every beat each chaser reads the player's real (s, x, speed) and picks what to do.

	Pack (Velociraptor x3):  Sleep → Wake → Pursue ⇄ Flank → Telegraph → Lunge → Recover → … → Tired → Gone
	  - only one raptor lunges at a time; the next lunge is 1.4–3.2 s later (random)
	  - the lunge aims where you WILL be (speed-predicted), so changing lane or speed after the
	    warning is what dodges it; holding boost drains their stamina until they give up
	Charger (Triceratops) / Stampede (Parasaurolophus herd): cross the road from one side,
	  timed to intercept your current speed — brake or boost to slip past.

	Each chaser is replicated as a Configuration under ReplicatedStorage.DinoExpedition.Runtime.Chasers
	(attributes P, Yaw, V, State, Species, Owner) and rendered smoothly on every client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local Folder = ReplicatedStorage.DinoExpedition.Runtime.Chasers

local Chase = {}
local nextId = 0
local rng = Random.new()

local function approach(a: number, b: number, rate: number): number
	if a < b then return math.min(b, a + rate) end
	return math.max(b, a - rate)
end

local function newChaser(run, species: string, state: string)
	nextId += 1
	local c = {
		Id = nextId, Species = species, State = state, T = 0, S = run.S, X = 0, V = 0, PrevX = 0,
		Stamina = 100, Side = 1, Run = run,
	}
	local cfg = Instance.new("Configuration")
	cfg.Name = species .. nextId
	cfg:SetAttribute("Owner", run.Player.UserId)
	cfg:SetAttribute("Id", nextId)
	cfg:SetAttribute("Species", species)
	cfg:SetAttribute("State", state)
	cfg:SetAttribute("V", 0)
	cfg:SetAttribute("Scale", (Config.Chase[species] and Config.Chase[species].Scale) or 1)
	cfg:SetAttribute("Zone", run.Zone)
	c.Cfg = cfg
	return c
end

local function setState(c, state: string)
	c.State = state
	c.T = 0
	c.Cfg:SetAttribute("State", state)
end

local function publish(c, route, variant: number, dt: number)
	local pos, f, r = route:Sample(variant, c.S)
	local world = pos + r * c.X
	-- face along the road, turned toward lateral motion
	local dx = (c.X - c.PrevX) / math.max(dt, 1e-3)
	c.PrevX = c.X
	local dir = f * math.max(c.V, 0.5) + r * dx
	if c.Facing then dir = c.Facing end
	local yaw = math.atan2(-dir.X, -dir.Z)
	c.Cfg:SetAttribute("P", world)
	c.Cfg:SetAttribute("Yaw", yaw)
	c.Cfg:SetAttribute("V", c.V)
end

-- a lone guard for an on-foot raid (Triceratops / Parasaurolophus parents); the Raid module drives it
function Chase.NewGuard(run, species: string, pos: Vector3, yaw: number)
	local c = newChaser(run, species, "Doze")
	c.Cfg:SetAttribute("P", pos)
	c.Cfg:SetAttribute("Yaw", yaw)
	c.Cfg.Parent = Folder
	return c
end

--------------------------------------------------------------------------------
-- Pack
--------------------------------------------------------------------------------
function Chase.SpawnPack(run, nest, guardSpots: { CFrame })
	local pack = { Kind = "Pack", Members = {}, Token = nil, NextLunge = os.clock() + 2.5, Nest = nest, Awake = false }
	local acfg = Config.Chase.Alpha
	for k = 1, 4 do
		local c = newChaser(run, "Velociraptor", "Sleep")
		c.K = math.min(k, 3)
		if k == 4 then
			-- the parent: a big alpha that leads the pack (boss) — sedate it with darts to end the chase
			c.Boss = true
			c.Calm = acfg.Calm
			c.Cfg:SetAttribute("Boss", true)
			c.Cfg:SetAttribute("DisplayName", acfg.Name)
			c.Cfg:SetAttribute("Calm", acfg.Calm)
			c.Cfg:SetAttribute("CalmMax", acfg.Calm)
			c.Cfg:SetAttribute("Scale", acfg.Scale)
		end
		local nestPos = Vector3.new(nest.Pos[1], nest.Pos[2], nest.Pos[3])
		local spot = guardSpots[k]
		if not spot then
			-- the alpha sleeps behind the nest, away from the road
			local ns = nest.S[run.Variant] or nest.S[1]
			local road = run.Route:Position(run.Variant, math.max(0, ns), 0)
			local away = Vector3.new(nestPos.X - road.X, 0, nestPos.Z - road.Z)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
			local p = nestPos + away * 10
			spot = CFrame.lookAt(p, p - away)
		end
		c.Cfg:SetAttribute("P", spot.Position)
		c.Cfg:SetAttribute("Yaw", select(2, spot:ToEulerAnglesYXZ()))
		local s, x = run.Route:Project(run.Variant, spot.Position, run.S)
		c.S, c.X, c.PrevX = s, x, x
		c.Cfg.Parent = Folder
		pack.Members[k] = c
	end
	table.insert(run.Chasers, pack)
	return pack
end

-- the escape: the dinos you just robbed (or knocked out the mate of) come after your rover.
-- Any species runs the pack logic (pursue, flank, telegraphed lunge); a big one is slower but hits harder.
local PURSUE = {
	Velociraptor = { Scale = 1.5, Run = 54, Catchup = 64, Lunge = 0.36, Telegraph = 0.8, Recover = 1.1 },
	Triceratops = { Scale = 1.05, Run = 50, Catchup = 58, Lunge = 0.5, Telegraph = 1.1, Recover = 1.5 },
	Parasaurolophus = { Scale = 1.0, Run = 52, Catchup = 60, Lunge = 0.42, Telegraph = 0.9, Recover = 1.2 },
	Stegosaurus = { Scale = 1.0, Run = 48, Catchup = 56, Lunge = 0.55, Telegraph = 1.2, Recover = 1.6 },
	Ankylosaurus = { Scale = 1.0, Run = 46, Catchup = 54, Lunge = 0.55, Telegraph = 1.2, Recover = 1.6 },
	Brachiosaurus = { Scale = 0.9, Run = 46, Catchup = 52, Lunge = 0.7, Telegraph = 1.4, Recover = 1.8 },
	TyrannosaurusRex = { Scale = 1.0, Run = 52, Catchup = 62, Lunge = 0.5, Telegraph = 1.0, Recover = 1.4 },
	Giganotosaurus = { Scale = 0.95, Run = 54, Catchup = 64, Lunge = 0.45, Telegraph = 0.95, Recover = 1.3 },
	Spinosaurus = { Scale = 0.95, Run = 52, Catchup = 62, Lunge = 0.48, Telegraph = 1.0, Recover = 1.4 },
	Carnotaurus = { Scale = 1.1, Run = 58, Catchup = 68, Lunge = 0.38, Telegraph = 0.85, Recover = 1.1 },
	Sarcosuchus = { Scale = 0.85, Run = 46, Catchup = 54, Lunge = 0.6, Telegraph = 1.3, Recover = 1.8 },
	Oviraptor = { Scale = 1.5, Run = 56, Catchup = 66, Lunge = 0.34, Telegraph = 0.75, Recover = 1.0 },
	Protoceratops = { Scale = 1.3, Run = 50, Catchup = 58, Lunge = 0.45, Telegraph = 1.0, Recover = 1.3 },
	Gallimimus = { Scale = 1.0, Run = 62, Catchup = 74, Lunge = 0.4, Telegraph = 0.8, Recover = 1.0 },
	Therizinosaurus = { Scale = 0.95, Run = 50, Catchup = 60, Lunge = 0.55, Telegraph = 1.2, Recover = 1.6 },
	Microraptor = { Scale = 1.5, Run = 58, Catchup = 70, Lunge = 0.32, Telegraph = 0.7, Recover = 0.9 },
	Psittacosaurus = { Scale = 1.15, Run = 50, Catchup = 58, Lunge = 0.45, Telegraph = 0.9, Recover = 1.2 },
	Compy = { Scale = 1.3, Run = 56, Catchup = 68, Lunge = 0.3, Telegraph = 0.6, Recover = 0.8 },
	Yutyrannus = { Scale = 1.0, Run = 53, Catchup = 63, Lunge = 0.5, Telegraph = 1.0, Recover = 1.4 },
	Coelophysis = { Scale = 1.4, Run = 58, Catchup = 68, Lunge = 0.32, Telegraph = 0.65, Recover = 0.9 },
	Plateosaurus = { Scale = 1.0, Run = 46, Catchup = 54, Lunge = 0.6, Telegraph = 1.2, Recover = 1.6 },
	Dilophosaurus = { Scale = 1.05, Run = 54, Catchup = 64, Lunge = 0.42, Telegraph = 0.9, Recover = 1.2 },
	Postosuchus = { Scale = 1.0, Run = 55, Catchup = 66, Lunge = 0.45, Telegraph = 1.0, Recover = 1.3 },
	-- the sea ruler alongside your boat: fast in the water, big wind-ups (you see the wake coming)
	Mosasaurus = { Scale = 0.75, Run = 56, Catchup = 66, Lunge = 0.55, Telegraph = 1.2, Recover = 1.5 },
}
function Chase.SpawnPursuers(run, species: string, count: number, opts)
	opts = opts or {}
	local base = PURSUE[species] or PURSUE.Velociraptor
	local pack = { Kind = "Pack", Members = {}, Token = nil, NextLunge = os.clock() + 3, Awake = true, Species = species,
		Cfg = { Run = base.Run, Catchup = base.Catchup, Lunge = base.Lunge, Telegraph = base.Telegraph, Recover = base.Recover, Stamina = 100, Tire = 9 } }
	for k = 1, count do
		local c = newChaser(run, species, "Wake")
		c.K = math.min(k, 3)
		c.Cfg:SetAttribute("Scale", (opts.Scale or base.Scale) * (k == 1 and (opts.LeadScale or 1) or 1))
		if k == 1 and opts.Boss then
			c.Boss = true
			c.Calm = opts.Calm or 5
			c.Cfg:SetAttribute("Boss", true)
			c.Cfg:SetAttribute("DisplayName", opts.Name)
			c.Cfg:SetAttribute("Calm", c.Calm)
			c.Cfg:SetAttribute("CalmMax", c.Calm)
		end
		c.S = math.max(0, run.S - 30 - k * 8)
		c.X = (k - 2) * 5
		c.PrevX = c.X
		c.WakeTime = 0.6 + k * 0.3
		c.Cfg:SetAttribute("P", run.Route:Position(run.Variant, c.S, c.X)) -- (placed before it appears, never at the origin)
		c.Cfg.Parent = Folder
		pack.Members[k] = c
	end
	table.insert(run.Chasers, pack)
	return pack
end

function Chase.WakePack(pack, headStart: boolean)
	if pack.Awake then return end
	pack.Awake = true
	for _, c in ipairs(pack.Members) do
		setState(c, "Wake")
		-- a sleeping pack takes longer to get going: that's your head start
		c.WakeTime = (headStart and 1.9 or 0.9) + c.K * 0.25 + (c.Boss and 0.4 or 0)
	end
	pack.NextLunge = os.clock() + (headStart and 4.5 or 2.5)
end

local LANES = { -6, 6, 0 } -- first two take the flanks (in frame), a third tucks in behind

local function updatePack(pack, run, dt: number, now: number, hit)
	if pack.Raiding then return true end -- the raid owns these guards while you're on foot
	local cfg = pack.Cfg or Config.Chase.Velociraptor
	local pS, pX, pV = run.S, run.X, run.V
	local hw = run.Route:HalfWidth(run.Variant, pS)
	local alive = 0
	-- which sides of the rover are already taken by a latched raptor (left, right, or the back bumper = 0)
	local taken = {}
	for _, o in ipairs(pack.Members) do if o.State == "Latch" then taken[o.Side or 1] = true end end
	local swarm = next(taken) ~= nil -- one's already on: the rest pile in, quicker
	for _, c in ipairs(pack.Members) do
		c.T += dt
		c.Facing = nil
		local st = c.State
		if st == "Sleep" then
			alive += 1
			continue -- position stays at the guard spot
		elseif st == "Wake" then
			c.Facing = run.Route:Position(run.Variant, pS, pX) - run.Route:Position(run.Variant, c.S, c.X)
			if c.T >= c.WakeTime then setState(c, "Pursue") end
		elseif st == "Pursue" or st == "Flank" then
			local targetS, targetX
			if st == "Pursue" then
				-- run up alongside the back wheels, not behind: the follow camera sits ~20 studs back, so anything
				-- further back than ~14 is under the lens (invisible, then clipping through it)
				targetS = pS - (c.Boss and Config.Chase.Alpha.Gap or (3 + c.K * 3.5))
				targetX = math.clamp(pX + LANES[c.K], -hw + 2, hw - 2)
			else
				targetS = pS - (c.Side == 0 and 5 or 1.5)
				targetX = pX + c.Side * 7
				if c.T > 4 then -- couldn't get alongside: give up this attempt
					setState(c, "Pursue")
					pack.Token = nil
					pack.NextLunge = now + 1.2
				end
			end
			local e = targetS - c.S
			local desired = pV + math.clamp(e * 1.4, -16, 22)
			if c.S < pS - 60 then desired = cfg.Catchup end
			desired = math.min(desired, (c.S < pS - 30) and cfg.Catchup or cfg.Run)
			c.V = approach(c.V, math.max(0, desired), 34 * dt)
			c.X = approach(c.X, targetX, (st == "Flank" and (swarm and 18 or 13) or 9) * dt)
			c.S += c.V * dt
			if st == "Flank" and math.abs(c.S - targetS) < 2.5 and math.abs(c.X - targetX) < 1.6 then
				-- right at the car (or one's already on): a quicker wind-up
				c.TeleDur = cfg.Telegraph * (swarm and 0.72 or 1) + rng:NextNumber(-0.1, 0.15)
				-- (the client times the wind-up so the jaws close as the lunge lands: wind-up + lunge)
				c.Cfg:SetAttribute("TeleTime", c.TeleDur)
				c.Cfg:SetAttribute("TeleDash", cfg.Lunge)
				setState(c, "Telegraph")
				hit("Telegraph", c)
			end
			-- claim the lunge token: closest awake raptor once the cooldown is over
			if st == "Pursue" and not pack.Token and now >= pack.NextLunge and now >= (run.ChaseHold or 0) and c.S > pS - 16 and (run.Phase == "Driving" or run.Phase == "OnFoot") then
				pack.Token = c
				c.Side = (pX > 0) and -1 or 1
				if math.abs(pX) < 3 then c.Side = (c.X >= pX) and 1 or -1 end
				-- that side's taken: the other one, else the back bumper
				if taken[c.Side] then c.Side = taken[-c.Side] and 0 or -c.Side end
				setState(c, "Flank")
			end
		elseif st == "Telegraph" then
			-- hold position alongside, matching speed
			c.V = pV
			c.S = approach(c.S, pS - (c.Side == 0 and 5 or 1.5), 10 * dt) + pV * dt
			c.X = approach(c.X, pX + c.Side * 7, 10 * dt)
			if c.T >= c.TeleDur then
				c.LungeFrom = Vector2.new(c.S, c.X)
				c.LungeTo = Vector2.new(pS + pV * cfg.Lunge + 1, pX)
				setState(c, "Lunge")
			end
		elseif st == "Lunge" then
			local u = math.clamp(c.T / cfg.Lunge, 0, 1)
			local e = 1 - (1 - u) ^ 2
			c.S = c.LungeFrom.X + (c.LungeTo.X - c.LungeFrom.X) * u
			c.X = c.LungeFrom.Y + (c.LungeTo.Y - c.LungeFrom.Y) * e
			c.V = (c.LungeTo.X - c.LungeFrom.X) / cfg.Lunge
			if u >= 1 then
				if math.abs(pS - c.S) < 4.4 and math.abs(pX - c.X) < 3.7 then
					if run.OnFoot then
						hit("Lunge", c)
						setState(c, "Recover")
					else
						-- it doesn't just bump you: it bites on and hangs off the side, chewing, until you shake it off
						if c.Side ~= 0 then c.Side = (c.X >= pX) and 1 or -1 end
						c.LatchPX = pX
						c.GnawT = 0
						-- your companion riding with you bites it off after a moment (if it's not still catching its breath)
						c.HelpAt = (run.Helper and now >= (run.HelpReady or 0)) and now + run.Helper.Delay or nil
						setState(c, "Latch")
						-- it's hanging on: the next one can come in already
						if pack.Token == c then pack.Token = nil end
						pack.NextLunge = now + rng:NextNumber(0.35, 0.75)
						hit("Latch", c)
					end
				else
					hit("Miss", c)
					setState(c, "Recover")
				end
			end
		elseif st == "Latch" then
			-- hanging off the rover's flank: chews every second (and can shake an egg loose); a hard swerve throws
			-- it off, a dart knocks it off (Chase.Dart), or it lets go after a few seconds
			c.V = pV
			c.S = pS - (c.Side == 0 and 3.4 or 1.2)
			c.X = pX + c.Side * 4.4
			c.GnawT += dt
			if c.GnawT >= 1 then
				c.GnawT = 0
				hit("Gnaw", c)
			end
			if run.Phase ~= "Driving" then
				setState(c, "Recover")
			elseif math.abs(pX - (c.LatchPX or pX)) > 6.2 / ((run.Stats and run.Stats.Grip) or 1) then -- grippier tyres / wings: a smaller swerve does it
				setState(c, "Stunned")
				if pack.Token == c then pack.Token = nil end
				pack.NextLunge = now + 2
				hit("ShakenOff", c)
			elseif c.HelpAt and now >= c.HelpAt and run.Helper then
				setState(c, "Stunned")
				if pack.Token == c then pack.Token = nil end
				pack.NextLunge = now + 2
				run.HelpReady = now + Config.Buddy.ChaseCooldown
				hit("BuddyBite", c)
			elseif c.T > 3.6 then
				setState(c, "Recover")
			end
		elseif st == "Recover" then
			c.V = approach(c.V, math.max(0, pV - 14), 40 * dt)
			c.S += c.V * dt
			c.X = approach(c.X, math.clamp(c.X, -hw + 1, hw - 1), 6 * dt)
			if c.T >= cfg.Recover then
				setState(c, "Pursue")
				if pack.Token == c then pack.Token = nil end
				-- still right at the car: back in sooner
				pack.NextLunge = now + ((pS - c.S < 9 or swarm) and rng:NextNumber(0.35, 0.8) or rng:NextNumber(0.8, 1.9))
			end
		elseif st == "Stunned" or st == "Flinch" then
			-- darted: stagger, lose ground, then get back in the hunt
			c.V = approach(c.V, pV * (st == "Flinch" and 0.7 or 0.25), 40 * dt)
			c.S += c.V * dt
			c.X = approach(c.X, math.clamp(c.X + c.Side * 2, -hw - 6, hw + 6), 3 * dt)
			if c.T >= (st == "Flinch" and 0.7 or Config.Expedition.StunTime) then
				setState(c, "Pursue")
				pack.NextLunge = math.max(pack.NextLunge, now + 0.8)
			end
		elseif st == "Sedated" then
			c.V = approach(c.V, 0, 30 * dt)
			c.S += c.V * dt
			if c.S < pS - 140 then setState(c, "Gone") end
		elseif st == "Tired" then
			c.V = approach(c.V, pV * 0.35, 18 * dt)
			c.S += c.V * dt
			c.X = approach(c.X, c.Side * (hw + 4), 4 * dt)
			if c.S < pS - 95 or c.T > 9 then setState(c, "Gone") end
		end
		-- stamina: boosting away wears them out, cruising lets them recover
		if st == "Pursue" or st == "Flank" then
			-- boosting wears them out; otherwise they get their wind back (faster once darts stop landing)
			local rested = os.clock() - (c.LastDart or 0) > 2.5
			if run.Boosting and c.S < pS - 6 then c.Stamina -= 13 * dt else c.Stamina = math.min(100, c.Stamina + (rested and 8.5 or 2.5) * dt) end
			if c.Stamina <= 0 and not c.Boss then
				setState(c, "Tired")
				if pack.Token == c then pack.Token = nil end
				c.Side = (c.X >= 0) and 1 or -1
				hit("Tired", c)
			end
		end
		if c.State ~= "Gone" then
			alive += 1
			publish(c, run.Route, run.Variant, dt)
		end
	end
	return alive > 0
end

--------------------------------------------------------------------------------
-- Crossers: Triceratops charge / Parasaurolophus stampede
--------------------------------------------------------------------------------
function Chase.SpawnCrossers(run, species: string, count: number, kind: string)
	local cfg = Config.Chase[species]
	local group = { Kind = kind, Members = {}, Species = species }
	local side = rng:NextInteger(0, 1) == 0 and -1 or 1
	local lead = math.clamp(run.V, 24, 70) * (cfg.Telegraph + 1.25) + 14
	for k = 1, count do
		local c = newChaser(run, species, "Telegraph")
		c.K = k
		c.Side = side
		c.S = run.S + lead + (k - 1) * 15
		c.X = side * (46 + (k - 1) * 3)
		c.PrevX = c.X
		c.Delay = (k - 1) * 0.42
		c.Speed = cfg.Charge * rng:NextNumber(0.95, 1.08)
		c.Cfg:SetAttribute("Side", side)
		c.Cfg.Parent = Folder
		group.Members[k] = c
	end
	table.insert(run.Chasers, group)
	return group
end

local function updateCrossers(group, run, dt: number, hit)
	local cfg = Config.Chase[group.Species]
	local pS, pX, pV = run.S, run.X, run.V
	local alive = 0
	for _, c in ipairs(group.Members) do
		c.T += dt
		local r = run.Route
		local _, f, rt = r:Sample(run.Variant, c.S)
		if c.State == "Telegraph" then
			c.Facing = -rt * c.Side
			c.V = 0
			if c.T >= cfg.Telegraph + c.Delay then
				-- aim: be at the player's lane exactly when they get there at their current speed
				local tReach = math.abs(c.X - pX) / c.Speed
				local aim = pS + pV * tReach
				if math.abs(aim - c.S) < 40 then c.S = aim + (c.K - 1) * 13 end
				setState(c, "Charge")
				if c.K == 1 then hit("Telegraph", c) end
			end
		elseif c.State == "Stunned" then
			c.Facing = rt * c.Side
			c.V = 0
			if c.T >= 1.4 then setState(c, "Retreat") end
		elseif c.State == "Retreat" then
			c.Facing = rt * c.Side
			c.X += c.Side * 9 * dt
			c.V = 9
			if math.abs(c.X) > 48 then setState(c, "Gone") end
		elseif c.State == "Charge" then
			c.Facing = -rt * c.Side + f * 0.15
			c.X -= c.Side * c.Speed * dt
			c.V = c.Speed
			if not c.Hit and math.abs(pS - c.S) < 6.5 and math.abs(pX - c.X) < 5.2 then
				c.Hit = true
				hit(group.Kind, c)
			end
			if math.abs(c.X) > 50 and math.sign(c.X) ~= c.Side then setState(c, "Gone") end
		end
		if c.State ~= "Gone" then
			alive += 1
			publish(c, r, run.Variant, dt)
		end
	end
	return alive > 0
end

--------------------------------------------------------------------------------
-- THE BOSS ON THE RUN (phase 2 of a boss fight): it bolted out of its den and YOU chase IT. It runs ahead of your
-- rover down the road to its last stand, keeping a lead - pull close and it surges, drop back and it lets you catch
-- up (it's always there in front of you). It weaves between the lanes; sit right on its tail in its lane and it
-- kicks back at you (swerve). Every dart makes it stumble. Just before the arena it peels off the road into it
--------------------------------------------------------------------------------
local RUN_LEAD = 34
function Chase.SpawnRunner(run, species: string, opts)
	local base = PURSUE[species] or PURSUE.Velociraptor
	local group = { Kind = "Runner", Members = {}, Species = species }
	local c = newChaser(run, species, "Pursue")
	c.K = 1
	c.Boss = true
	c.Calm = opts.Calm or 9999
	c.S = run.S + 42
	c.X = 0
	c.PrevX = 0
	c.V = math.max(run.V, 30)
	c.LaneX, c.LaneAt = 0, os.clock() + 1.5
	c.NextKick = os.clock() + 4
	c.Cfg:SetAttribute("Scale", (opts.Scale or base.Scale))
	c.Cfg:SetAttribute("Boss", true)
	c.Cfg:SetAttribute("DisplayName", opts.Name)
	c.Cfg:SetAttribute("Calm", c.Calm)
	c.Cfg:SetAttribute("CalmMax", c.Calm)
	c.Cfg:SetAttribute("P", run.Route:Position(run.Variant, c.S, c.X))
	c.Cfg.Parent = Folder
	group.Members[1] = c
	table.insert(run.Chasers, group)
	return group
end

local function updateRunner(group, run, dt: number, hit)
	local now = os.clock()
	local pS, pX, pV = run.S, run.X, run.V
	local r = run.Route
	local len = r:Length(run.Variant)
	local alive = 0
	for _, c in ipairs(group.Members) do
		c.T += dt
		local hw = r:HalfWidth(run.Variant, c.S)
		local _, f, rt = r:Sample(run.Variant, c.S)
		local lead = c.S - pS
		if c.State == "Arena" then
			-- off the road and into its last stand
			c.Facing = f + rt * (c.Side or 1) * 1.4
			c.V = approach(c.V, 30, 20 * dt)
			c.S += c.V * dt * 0.5
			c.X = approach(c.X, (c.Side or 1) * (hw + 30), 26 * dt)
			if c.T > 1.6 then setState(c, "Gone") end
		else
			-- the pace: hold a lead, surge when you close, ease off when you fall behind (never out of sight)
			local want
			if lead < RUN_LEAD then want = pV + (RUN_LEAD - lead) * 0.9 else want = pV - (lead - RUN_LEAD) * 0.6 end
			want = math.clamp(want, 22, 84)
			if c.State == "Stunned" then
				want = math.min(want, math.max(16, pV * 0.5)) -- (it stumbles: your chance to close the gap)
				if c.T >= 0.7 then setState(c, "Pursue") end
			end
			c.V = approach(c.V, want, (c.State == "Stunned" and 60 or 34) * dt)
			c.S = math.min(c.S + c.V * dt, len - 4)
			-- weaving: a new lane every few seconds
			if now >= (c.LaneAt or 0) then
				c.LaneAt = now + 1.8 + math.random() * 1.8
				c.LaneX = (math.random() * 2 - 1) * math.max(0, hw - 5) * 0.7
			end
			-- the kick: you're right on its tail in its lane - it winds up, then lashes back
			if c.State == "Pursue" and lead > 5 and lead < 18 and math.abs(pX - c.X) < 7 and now >= (c.NextKick or 0) then
				c.NextKick = now + 4.5 + math.random() * 2
				c.TeleDur = 0.85
				c.Cfg:SetAttribute("Attack", "TailSweep")
				c.Cfg:SetAttribute("TeleTime", 0.85)
				setState(c, "Telegraph")
				hit("Telegraph", c)
			elseif c.State == "Telegraph" and c.T >= 0.85 then
				setState(c, "Lunge")
				if lead < 17 and math.abs(pX - c.X) < 5.5 then hit("Kick", c) end
			elseif c.State == "Lunge" and c.T >= 0.4 then
				setState(c, "Pursue")
			end
			c.X = approach(c.X, c.State == "Telegraph" and pX or c.LaneX, (c.State == "Telegraph" and 12 or 8) * dt)
			c.Facing = nil
			-- its last stand is just ahead: off the road it goes
			if run.StopS and c.S >= run.StopS - 14 then
				c.Side = (c.X >= 0) and 1 or -1
				setState(c, "Arena")
			end
		end
		if c.State ~= "Gone" then
			alive += 1
			publish(c, r, run.Variant, dt)
		end
	end
	return alive > 0
end

--------------------------------------------------------------------------------
-- THE FORD AMBUSH (Sarcosuchus, Spine River): it lies in wait where the road runs into the river, eyes just
-- above the water. When your rover splashes in close it lunges across the ford - brake, swerve or dart it
--------------------------------------------------------------------------------
function Chase.SpawnAmbush(run, species: string, s0: number)
	local group = { Kind = "Ambush", Members = {}, Species = species }
	local hw = run.Route:HalfWidth(run.Variant, s0)
	local side = rng:NextInteger(0, 1) == 0 and -1 or 1
	local c = newChaser(run, species, "Lurk")
	c.K = 1
	c.Side = side
	c.S = s0 + 8
	c.X = side * (hw + 3)
	c.PrevX = c.X
	c.Cfg:SetAttribute("Scale", (PURSUE[species] and PURSUE[species].Scale) or 0.85)
	c.Cfg:SetAttribute("Side", side)
	c.Cfg:SetAttribute("P", run.Route:Position(run.Variant, c.S, c.X))
	c.Cfg.Parent = Folder
	group.Members[1] = c
	table.insert(run.Chasers, group)
	return group
end

local function updateAmbush(group, run, dt: number, hit)
	local base = PURSUE[group.Species] or PURSUE.Velociraptor
	local pS, pX = run.S, run.X
	local alive = 0
	for _, c in ipairs(group.Members) do
		c.T += dt
		local r = run.Route
		local _, f, rt = r:Sample(run.Variant, c.S)
		if c.State == "Lurk" then
			c.Facing = -rt * c.Side
			c.V = 0
			-- you've driven past it without coming close: it sinks back down
			if pS > c.S + 25 then setState(c, "Gone")
			elseif c.S - pS < 26 then
				setState(c, "Telegraph")
				hit("Telegraph", c)
			end
		elseif c.State == "Telegraph" then
			c.Facing = -rt * c.Side
			if c.T >= (base.Telegraph or 1.3) * 0.75 then
				-- across the ford at the lane you're in when it goes
				c.AimX = pX
				setState(c, "Lunge")
			end
		elseif c.State == "Lunge" then
			c.Facing = -rt * c.Side + f * 0.2
			local speed = 46
			c.X = approach(c.X, (c.AimX or pX) - c.Side * 6, speed * dt)
			c.V = speed * 0.3
			if not c.Hit and math.abs(pS - c.S) < 7 and math.abs(pX - c.X) < 5 then
				c.Hit = true
				hit("Ambush", c)
			end
			if c.T > 0.9 then setState(c, "Retreat") end
		elseif c.State == "Stunned" then
			c.Facing = rt * c.Side
			c.V = 0
			if c.T >= 1.4 then setState(c, "Retreat") end
		elseif c.State == "Retreat" then
			c.Facing = rt * c.Side
			c.X = approach(c.X, c.Side * (r:HalfWidth(run.Variant, c.S) + 8), 10 * dt)
			c.V = 6
			if c.T > 2.2 or pS > c.S + 60 then setState(c, "Gone") end
		end
		if c.State ~= "Gone" then
			alive += 1
			publish(c, r, run.Variant, dt)
		end
	end
	return alive > 0
end

--------------------------------------------------------------------------------
-- tranq darts
--------------------------------------------------------------------------------
function Chase.Find(run, id: number)
	for _, g in ipairs(run.Chasers) do
		for _, c in ipairs(g.Members) do
			if c.Id == id then return c, g end
		end
	end
	return nil, nil
end

-- world position of a chaser (for range checks)
function Chase.Position(run, c): Vector3?
	local p = c.Cfg:GetAttribute("P")
	return p
end

-- returns "Stun" | "Calm" | "Sedated" | "None"
function Chase.Dart(run, id: number): (string, any)
	local c, g = Chase.Find(run, id)
	if not c then return "None", nil end
	local st = c.State
	-- (the boss on the run: every dart counts - even one landing while it's still stumbling from the last)
	if g.Kind == "Runner" then
		if st == "Arena" or st == "Gone" then return "None", c end
		if st ~= "Stunned" then setState(c, "Stunned") end -- (it stumbles for a moment)
		return "Calm", c
	end
	if st == "Sleep" or st == "Gone" or st == "Sedated" or st == "Tired" or st == "Retreat" or st == "Stunned" then return "None", c end
	if g.Kind == "Pack" then
		if g.Token == c then g.Token = nil end
		c.Side = (c.X >= run.X) and 1 or -1
		if c.Boss then
			c.Calm -= 1
			c.Cfg:SetAttribute("Calm", c.Calm)
			if c.Calm <= 0 then
				setState(c, "Sedated")
				-- the pack loses its leader and scatters
				for _, m in ipairs(g.Members) do
					if m ~= c and m.State ~= "Gone" and m.State ~= "Sleep" then
						m.Side = (m.X >= 0) and 1 or -1
						setState(m, "Tired")
					end
				end
				g.Token = nil
				return "Sedated", c
			end
			setState(c, "Flinch")
			g.NextLunge = os.clock() + 0.9
			return "Calm", c
		end
		-- timing is everything: a dart into a raptor that's lining up its lunge (the warning flash) knocks it
		-- flat; anything else just stings. spamming darts at a pack that's only following you barely slows it
		c.LastDart = os.clock()
		if st == "Telegraph" or st == "Lunge" or st == "Latch" then
			c.Stamina -= 45
			setState(c, "Stunned")
			g.NextLunge = math.max(g.NextLunge, os.clock() + 1.6)
			return "Perfect", c
		end
		if st == "Recover" then
			c.Stamina -= 25
			setState(c, "Flinch")
			return "Stun", c
		end
		-- following you: raptors weave out of the way of plenty of them
		if c.Species == "Velociraptor" and rng:NextNumber() < 0.4 then return "Dodge", c end
		c.Stamina -= 12
		setState(c, "Flinch")
		return "Glance", c
	end
	-- crossers: stop dead, then back off the road
	c.Hit = true
	setState(c, "Stunned")
	return "Stun", c
end

-- a thief with what it came for (an Oviraptor that plucked an egg off your rack): it peels off and drops back
function Chase.Flee(run, c)
	local _, g = Chase.Find(run, c.Id)
	if g and g.Token == c then g.Token = nil end
	c.Side = (c.X >= run.X) and 1 or -1
	setState(c, "Tired")
end

--------------------------------------------------------------------------------
function Chase.Update(run, dt: number, hit)
	local now = os.clock()
	for i = #run.Chasers, 1, -1 do
		local g = run.Chasers[i]
		local alive
		if g.Kind == "Pack" then alive = updatePack(g, run, dt, now, hit)
		elseif g.Kind == "Ambush" then alive = updateAmbush(g, run, dt, hit)
		elseif g.Kind == "Runner" then alive = updateRunner(g, run, dt, hit)
		else alive = updateCrossers(g, run, dt, hit) end
		if not alive then
			for _, c in ipairs(g.Members) do c.Cfg:Destroy() end
			table.remove(run.Chasers, i)
		else
			for _, c in ipairs(g.Members) do
				if c.State == "Gone" and c.Cfg.Parent then c.Cfg:Destroy() end
			end
		end
	end
end

function Chase.Clear(run)
	for _, g in ipairs(run.Chasers) do
		for _, c in ipairs(g.Members) do c.Cfg:Destroy() end
	end
	table.clear(run.Chasers)
end

-- how many are hanging off the rover right now (three and it goes over)
function Chase.Latched(run): number
	local n = 0
	for _, g in ipairs(run.Chasers) do
		for _, c in ipairs(g.Members) do if c.State == "Latch" then n += 1 end end
	end
	return n
end

function Chase.Threats(run): number
	local n = 0
	for _, g in ipairs(run.Chasers) do
		for _, c in ipairs(g.Members) do
			if c.State ~= "Sleep" and c.State ~= "Gone" and c.State ~= "Tired" and c.State ~= "Sedated" and c.State ~= "Retreat" then n += 1 end
		end
	end
	return n
end

--------------------------------------------------------------------------------
-- LOSING THE PACK (2026-10-14, user: "allow for driving with an egg and not going to the exit gate so you can get
-- more eggs"): Expedition asks how the hunt behind you stands, and when you've lost them the pack gives up
--------------------------------------------------------------------------------
-- the pursuers still hunting you (not tired, calmed, asleep or gone; never a ford croc or a crosser - they're not
-- following you): how far back the nearest is, whether one is on you right now (lining up, lunging, hanging on),
-- and how many are left
function Chase.Pursuit(run): (number, boolean, number)
	local gap, onYou, n = math.huge, false, 0
	for _, g in ipairs(run.Chasers) do
		if g.Kind ~= "Pack" or g.Raiding or g.GaveUp then continue end
		for _, c in ipairs(g.Members) do
			local st = c.State
			-- (a thief running off with your egg isn't hunting you, but it isn't over while you can still dart it back)
			if (st == "Sleep" or st == "Gone" or st == "Tired" or st == "Sedated") and not (c.Carrying and st ~= "Gone") then continue end
			n += 1
			gap = math.min(gap, run.S - c.S)
			if st == "Flank" or st == "Telegraph" or st == "Lunge" or st == "Latch" or c.Carrying then onYou = true end
		end
	end
	return gap, onYou, n
end

-- you lost them: the pack slows, peels off to the roadside and drops out of sight a few seconds later (the ford croc
-- and any crossers just go - they were never following you)
function Chase.GiveUp(run)
	for i = #run.Chasers, 1, -1 do
		local g = run.Chasers[i]
		if g.Kind == "Pack" and not g.Raiding then
			g.GaveUp = true
			g.Token = nil
			for _, c in ipairs(g.Members) do
				if c.State ~= "Gone" and c.State ~= "Sleep" then
					c.Side = (c.X >= run.X) and 1 or -1
					if c.State ~= "Sedated" then setState(c, "Tired") end
					c.T = 5 -- (Tired lets go at 9 s: about four seconds of jogging off, then gone)
				end
			end
		elseif not g.Raiding then
			for _, c in ipairs(g.Members) do c.Cfg:Destroy() end
			table.remove(run.Chasers, i)
		end
	end
end

-- a new chase starting: whatever's left of a pack that already gave up on you goes now (never mixed into the new one)
function Chase.DropGivenUp(run)
	for i = #run.Chasers, 1, -1 do
		local g = run.Chasers[i]
		if g.GaveUp then
			for _, c in ipairs(g.Members) do c.Cfg:Destroy() end
			table.remove(run.Chasers, i)
		end
	end
end

return Chase
