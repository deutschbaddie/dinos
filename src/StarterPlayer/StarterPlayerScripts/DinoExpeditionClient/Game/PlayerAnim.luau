--[[
	PlayerAnim — procedural animation for player characters (R6 and R15), the same idea as the dinos: poses are
	code, written to each joint's Transform every frame after Roblox's own Animator.

	Layers, per joint:
	  Roblox walk/idle (the Animator)  --lerp by Weight-->  our full-body pose (fights, sneaking, carrying, loops)
	  one-shot actions and launcher recoil are offsets on top of whichever is showing (a fist pump works in camp too)

	Full-body poses are foot-planted: once a pose is built, the legs go through forward kinematics (using the real
	joint offsets, so any avatar scale works) and the body is raised or lowered until the lowest foot sits on the
	floor. Crouches never sink into the ground, and the walk's bob falls out of the leg swing by itself.

	Hands go to real things. After the body pose is planted, a second pass knows exactly where the torso is and
	solves the arms by IK (R6 aims each straight arm, R15 solves shoulder + elbow, elbows out):
	  carrying     an egg (the server welds it to the torso as "HoldWeld"; this module places it with
	               Config.CarrySpot) or anything you Hold (a newborn) - both palms on its sides, any size
	  reaching     a dino's head to pet, a mouth to feed, a nest to set an egg in, the floor to pick something
	               up, the steering wheel's rim (hands turn with the steering)
	  looking      the head turns to what you're dealing with (PlayerAnim.Look)

	It runs for every character in view (yours and other players'), so it looks the same on every screen:
	  locomotion   walk / strafe / back-pedal leg cycles, knees (R15), body lean, banking into turns, idle breathing
	  stances      launcher raised and following your aim pitch; sprint with pumping arms; sneaking crouch; carry
	  driving      automatic in any VehicleSeat: seated, hands on the wheel, leaning into turns, bumps; a hop in
	               and a hop out
	  actions      Fire (recoil), Dodge (somersault), Hit/BigHit (flinch), Throw, Lift (egg out of a nest), Receive
	               (egg out of your bag), Place (egg into a nest), Pet, Feed, Pickup ("item get!"), Wave, Tap
	               (knock on an egg), Startle, Victory (fist pump)
	  loops        Downed (prone crawl), Revive (kneel + chest pumps), Rodeo (bucking dino), Kneel (watching an
	               egg), Work (hammering at the bench), Drive

	Pose convention (parent-part space, every joint world-aligned at rest; left side is mirrored by `sym`):
	  rx  + swings a hanging limb forward / tilts the torso and head back
	  ry  + turns left
	  rz  + swings a right limb outward (raw rz pushes any limb towards +x)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))

local PlayerAnim = {}

local rigs = {} :: { [Model]: any }

local R6_JOINTS = {
	Root = { "HumanoidRootPart", "RootJoint" }, Neck = { "Torso", "Neck" },
	ShoulderR = { "Torso", "Right Shoulder" }, ShoulderL = { "Torso", "Left Shoulder" },
	HipR = { "Torso", "Right Hip" }, HipL = { "Torso", "Left Hip" },
}
local R15_JOINTS = {
	Root = { "LowerTorso", "Root" }, Waist = { "UpperTorso", "Waist" }, Neck = { "Head", "Neck" },
	ShoulderR = { "RightUpperArm", "RightShoulder" }, ElbowR = { "RightLowerArm", "RightElbow" }, WristR = { "RightHand", "RightWrist" },
	ShoulderL = { "LeftUpperArm", "LeftShoulder" }, ElbowL = { "LeftLowerArm", "LeftElbow" }, WristL = { "LeftHand", "LeftWrist" },
	HipR = { "RightUpperLeg", "RightHip" }, KneeR = { "RightLowerLeg", "RightKnee" }, AnkleR = { "RightFoot", "RightAnkle" },
	HipL = { "LeftUpperLeg", "LeftHip" }, KneeL = { "LeftLowerLeg", "LeftKnee" }, AnkleL = { "LeftFoot", "LeftAnkle" },
}
-- joints we pose, and the order forward kinematics walks the tree (parents first; wrists and ankles ride along)
local NAMES = { "Root", "Waist", "Neck", "ShoulderR", "ElbowR", "ShoulderL", "ElbowL", "HipR", "KneeR", "HipL", "KneeL" }
local CHAIN = { "Root", "Waist", "Neck", "ShoulderR", "ElbowR", "WristR", "ShoulderL", "ElbowL", "WristL", "HipR", "KneeR", "AnkleR", "HipL", "KneeL", "AnkleL" }
local I = CFrame.identity
local DEFAULT_EGG = Vector3.new(1.6, 2.2, 1.6)

local function flat3(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
local function ease(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end
-- 0 -> 1 over `inT`, holds, 1 -> 0 over the last `outT` (fractions of the action)
local function envelope(u: number, inT: number, outT: number): number
	return math.min(ease(u / inT), 1 - ease((u - (1 - outT)) / outT))
end
local function resolve(target: any): Vector3?
	if typeof(target) == "function" then target = target() end
	if typeof(target) == "Instance" then return target:IsA("BasePart") and target.Parent and target.Position or nil end
	if typeof(target) == "CFrame" then return target.Position end
	if typeof(target) == "Vector3" then return target end
	return nil
end

-- a pose is { Joint = { rx, ry, rz, px, py, pz } } (position only matters for Root), plus R (IK rotations,
-- applied inside the angles), RootRoll (a whole-body spin), Plant (how much the feet are kept on the floor),
-- Reach (world points the hands go to) and Look (a world point the head turns to)
local function newPose()
	local p = { R = {}, Plant = 1, PlantAll = 0, Reach = {}, Look = nil, LookW = 0 } :: any
	for _, n in ipairs(NAMES) do p[n] = { 0, 0, 0, 0, 0, 0 } end
	return p
end
local function add(pose, joint: string, rx: number, ry: number?, rz: number?, px: number?, py: number?, pz: number?, w: number?)
	local v = pose[joint]
	local k = w or 1
	v[1] += rx * k
	v[2] += (ry or 0) * k
	v[3] += (rz or 0) * k
	v[4] += (px or 0) * k
	v[5] += (py or 0) * k
	v[6] += (pz or 0) * k
end
-- mirrored pair: right gets (rx, ry, rz), left gets (rx, -ry, -rz)
local function sym(pose, base: string, rx: number, ry: number, rz: number, w: number?)
	add(pose, base .. "R", rx, ry, rz, 0, 0, 0, w)
	add(pose, base .. "L", rx, -ry, -rz, 0, 0, 0, w)
end
-- dst += src * w (IK rotations blend from rest; reaches and looks keep the strongest)
local function mix(dst, src, w: number)
	for _, n in ipairs(NAMES) do
		local a, b = dst[n], src[n]
		for k = 1, 6 do a[k] += b[k] * w end
		local r = src.R[n]
		if r then dst.R[n] = (dst.R[n] or I):Lerp(r, w) end
	end
	for side, r in pairs(src.Reach) do
		local cur = dst.Reach[side]
		if not cur or r.W * w > cur.W then dst.Reach[side] = { P = r.P, W = r.W * w } end
	end
	if src.Look and src.LookW * w > dst.LookW then dst.Look, dst.LookW = src.Look, src.LookW * w end
end
-- a crouch of depth k (0..1): the planting drops the body to suit the bent legs
local function crouch(rig, pose, k: number)
	if k <= 0 then return end
	if rig.R15 then
		add(pose, "Root", -0.45 * k)
		sym(pose, "Hip", 1.3 * k, 0, 0.12 * k)
		add(pose, "KneeR", -2.0 * k) add(pose, "KneeL", -2.0 * k)
	else
		add(pose, "Root", -0.85 * k)
		sym(pose, "Hip", 0.75 * k, 0, 0.1 * k)
	end
end

-- the shortest rotation taking unit vector a onto unit vector b
local function fromTo(a: Vector3, b: Vector3): CFrame
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-5 then return I end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(a:Dot(b), -1, 1)))
end

--------------------------------------------------------------------------------
-- rig binding
--------------------------------------------------------------------------------
-- a joint is a Motor6D, or an AnimationConstraint on avatars with Roblox's Avatar Joint Upgrade on (same name,
-- same Transform property; its frames are its attachments instead of C0/C1)
local function findJoint(char: Model, spec): (Instance?, CFrame?, CFrame?, BasePart?, BasePart?)
	local part = char:FindFirstChild(spec[1])
	local m = part and part:FindFirstChild(spec[2])
	if not m then
		for _, d in ipairs(char:GetDescendants()) do
			if d.Name == spec[2] and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then m = d break end
		end
	end
	if m and m:IsA("Motor6D") and m.Part0 and m.Part1 then return m, m.C0, m.C1, m.Part0, m.Part1 end
	if m and m:IsA("AnimationConstraint") and m.Attachment0 and m.Attachment1 then
		local p0, p1 = m.Attachment0.Parent, m.Attachment1.Parent
		if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then return m, m.Attachment0.CFrame, m.Attachment1.CFrame, p0, p1 end
	end
	return nil, nil, nil, nil, nil
end

local function jointRot(pose, name: string): (CFrame, { number }?)
	local v = pose and pose[name]
	if not v then return I, nil end
	local rot = CFrame.Angles(v[1], v[2], v[3])
	local r = pose.R[name]
	if r then rot = rot * r end
	if name == "Root" and pose.RootRoll then rot = pose.RootRoll * rot end
	return rot, v
end

-- every part's CFrame relative to the HumanoidRootPart for a pose (nil = rest). A joint moves its child as
-- Part0 * (C0 * Transform * C1^-1) = Part0 * pivot * offset * rot * K, with K = C0.Rotation * C1^-1.
local function fk(rig, pose): { [BasePart]: CFrame }
	local cfs = { [rig.HRP] = I }
	for _, name in ipairs(CHAIN) do
		local j = rig.Joints[name]
		local parent = j and cfs[j.Part0]
		if not parent then continue end
		local rot, v = jointRot(pose, name)
		local off = v and Vector3.new(v[4], v[5], v[6]) or Vector3.zero
		cfs[j.Part1] = parent * CFrame.new(j.P0 + off) * rot * j.K
	end
	return cfs
end

-- the lowest point of either foot (a box's lowest corner, so a tilted foot isn't buried)
local function lowest(rig, cfs, parts): number?
	local low = math.huge
	for _, foot in ipairs(parts or rig.Feet) do
		local cf = cfs[foot]
		if cf then
			local s = foot.Size
			local e = (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
			low = math.min(low, cf.Position.Y - e)
		end
	end
	return if low < math.huge then low else nil
end

local warned = {} :: { [Model]: boolean }
local function bind(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (hum and hrp) then return nil end
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local joints = {}
	local count, kind = 0, "Motor6D"
	for name, spec in pairs(r15 and R15_JOINTS or R6_JOINTS) do
		local m, c0, c1, p0, p1 = findJoint(char, spec)
		if m and c0 and c1 then
			local c0r = c0.Rotation
			joints[name] = { Motor = m, C0r = c0r, C0rInv = c0r:Inverse(), P0 = c0.Position, K = c0r * c1:Inverse(), Part0 = p0, Part1 = p1 }
			count += 1
			kind = m.ClassName
		end
	end
	if not joints.Root then
		if not warned[char] then
			warned[char] = true
			warn(string.format("[PlayerAnim] no Root joint on %s (%s) - player poses are off", char.Name, r15 and "R15" or "R6"))
		end
		return nil
	end
	print(string.format("[PlayerAnim] bound %s: %s, %d joints (%s)", char.Name, r15 and "R15" or "R6", count, kind))
	local rig = {
		Char = char, Hum = hum, HRP = hrp, R15 = r15, Joints = joints,
		Weight = 0, Combat = false, Phase = 0, Move = 0, Aiming = true, AimPitch = 0, Sprint = false,
		Actions = {}, Loop = nil :: string?, LoopW = 0, LoopT = 0, Recoil = 0, RecoilV = 0,
		Tilt = 0, Lean = 0, Bank = 0, Air = 0, Active = false, Carrying = false,
		Feet = {}, Parts = {}, Arms = {}, Ground = -3, NeckY = 1,
		Driving = false, Steer = 0, Bump = 0, SeatVY = 0, LookW = 0,
	}
	-- feet for planting, the floor height at rest, and the arm chains for carrying and reaching
	for _, side in ipairs({ "R", "L" }) do
		local j = joints["Ankle" .. side] or joints["Knee" .. side] or joints["Hip" .. side]
		if j then table.insert(rig.Feet, j.Part1) end
	end
	for _, j in pairs(joints) do table.insert(rig.Parts, j.Part1) end
	local rest = fk(rig, nil)
	rig.Ground = lowest(rig, rest) or -3
	local torso = joints.ShoulderR and joints.ShoulderR.Part0
	rig.Torso = torso
	if joints.Neck then rig.NeckY = joints.Neck.Part0 == torso and joints.Neck.P0.Y or 1 end
	local t0 = torso and rest[torso]
	if t0 then
		for _, side in ipairs({ "R", "L" }) do
			local sh = joints["Shoulder" .. side]
			if not sh then continue end
			local sgn = side == "R" and 1 or -1
			local el = joints["Elbow" .. side]
			local wr = joints["Wrist" .. side]
			local hand = (r15 and ((wr and wr.Part1) or (el and el.Part1))) or sh.Part1
			local hcf = rest[hand]
			if not hcf then continue end
			-- the "palm": low on the inner face of the hand (R6: of the whole arm)
			local s = hand.Size
			local palm = r15 and Vector3.new(-sgn * s.X * 0.3, -s.Y * 0.2, 0) or Vector3.new(-sgn * s.X * 0.45, -s.Y * 0.44, 0)
			local arm = { Sgn = sgn, S = sh.P0, H = t0:PointToObjectSpace(hcf:PointToWorldSpace(palm)) }
			if r15 and el and rest[el.Part0] then
				arm.E = t0:PointToObjectSpace(rest[el.Part0]:PointToWorldSpace(el.P0))
				arm.L1 = (arm.E - arm.S).Magnitude
				arm.L2 = (arm.H - arm.E).Magnitude
			end
			rig.Arms[side] = arm
		end
	end
	local old = rigs[char]
	if old then
		-- rebinding (joints were rebuilt): keep what the body was doing
		for _, k in ipairs({ "Stance", "Combat", "Carrying", "Loop", "WantLoop", "UserLoop", "LoopW", "Proxy", "LookAt" }) do rig[k] = old[k] end
	else
		char.AncestryChanged:Connect(function() if not char.Parent then rigs[char] = nil warned[char] = nil end end)
	end
	rigs[char] = rig
	return rig
end

-- avatar loading can swap body parts (and their joints) after spawn: rebind when a bound joint goes away
local function stale(rig): boolean
	for _, j in pairs(rig.Joints) do
		if not j.Motor.Parent then return true end
	end
	return false
end

local function rigOf(char: Model?)
	if not char then return nil end
	local rig = rigs[char]
	if rig and stale(rig) then return bind(char) end
	return rig or bind(char)
end

--------------------------------------------------------------------------------
-- public API
--------------------------------------------------------------------------------
local DUR = {
	Fire = 0.22, Dodge = 0.42, Hit = 0.4, Throw = 0.5, Lift = 0.75, Receive = 0.4, Victory = 1.3, BigHit = 0.7,
	Place = 0.85, Pet = 1.9, Feed = 1.6, Pickup = 1.7, Wave = 1.6, Tap = 0.55, Startle = 0.7, GetIn = 0.45, GetOut = 0.45,
}
-- these take over the whole body while they play (they need the hands on something, or the legs planted)
local FULL = { Lift = true, Place = true, Pet = true, Feed = true, Pickup = true, Tap = true, Startle = true, GetOut = true }

-- opts: Duration, and per action - Dir (Dodge), Side (Hit), Target (Pet/Feed/Tap: a world point or a function
-- returning one; Place: the CFrame the egg ends at), Model/Size (Place: the egg you're setting down), Done (Place:
-- called once the egg is in)
function PlayerAnim.Act(char: Model?, name: string, opts)
	local rig = rigOf(char)
	if not rig then return end
	if name == "Fire" then
		rig.RecoilV += 9
		return
	end
	if name == "Grab" then name = "Lift" end
	-- an echo of one we just started (local call + the replicated attribute): don't restart it
	local cur = rig.Actions[name]
	if cur and (name == "Pickup" or name == "Wave") and cur.T < 0.35 then return end
	rig.Actions[name] = { T = 0, D = (opts and opts.Duration) or DUR[name] or 0.4, Opts = opts or {} }
end

function PlayerAnim.SetLoop(char: Model?, name: string?)
	local rig = rigOf(char)
	if rig then rig.UserLoop = name end
end

function PlayerAnim.SetRodeoTilt(char: Model?, tilt: number)
	local rig = rigOf(char)
	if rig then rig.Tilt = tilt end
end

function PlayerAnim.SetAim(char: Model?, pitch: number, aiming: boolean)
	local rig = rigOf(char)
	if not rig then return end
	rig.AimPitch = pitch
	rig.Aiming = aiming
end

function PlayerAnim.SetCombat(char: Model?, on: boolean)
	local rig = rigOf(char)
	if rig then rig.Combat = on end
end

-- turn the head to a world point (or a function returning one); nil to stop
function PlayerAnim.Look(char: Model?, target: any)
	local rig = rigOf(char)
	if rig then rig.LookAt = target end
end

-- hold any model in both arms like an egg (a newborn after hatching): this module places it every frame.
-- opts.Rot turns it in your arms (a newborn lies across them). nil model to let go.
function PlayerAnim.Hold(char: Model?, model: Model?, opts)
	local rig = rigOf(char)
	if not rig then return end
	if not model then rig.Proxy = nil return end
	local rot = (opts and opts.Rot) or I
	local cf, size = model:GetBoundingBox()
	-- the box's centre relative to the model's pivot, and its size as it will sit in your arms
	local off = model:GetPivot():ToObjectSpace(cf)
	local s = rot:VectorToWorldSpace(size)
	rig.Proxy = { Model = model, Off = off, Rot = rot, Size = Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z)) }
end

--------------------------------------------------------------------------------
-- the held egg (or anything else in your arms)
--------------------------------------------------------------------------------
-- where it sits this frame (torso space) and how big it is, or nil when your arms are empty
local function eggState(rig)
	if not rig.Torso then return nil end
	local size
	if rig.Proxy and rig.Proxy.Model.Parent then
		size = rig.Proxy.Size
	else
		rig.Proxy = nil
		if not (rig.Carrying or rig.Stance == "Carry") then return nil end
		local m = rig.Char:FindFirstChild("HeldEggModel")
		if m ~= rig.EggModel then
			rig.EggModel = m
			rig.EggWeld = m and m:FindFirstChild("HoldWeld", true)
			local sz = m and m:GetAttribute("HoldSize")
			rig.EggSize = typeof(sz) == "Vector3" and sz or (m and (m :: Model):GetExtentsSize()) or nil
			-- a held dino lies side-on, and its root isn't its middle: keep both when we move the weld
			local rot, off = m and m:GetAttribute("HoldRot"), m and m:GetAttribute("HoldOff")
			rig.EggTail = (typeof(rot) == "number" and CFrame.Angles(0, rot, 0) or I) * (typeof(off) == "Vector3" and CFrame.new(off):Inverse() or I)
		end
		if not m then return nil end
		size = rig.EggSize or DEFAULT_EGG
	end
	local spot = Config.CarrySpot(size, rig.Torso.Size)
	-- something tall covers your face: shift it right so the head can peek round the left side
	local over = math.clamp((spot.Y + size.Y / 2 - rig.NeckY - 0.5) / 1.2, 0, 1)
	spot += Vector3.new(0.22 * over, 0, 0)
	-- out of a nest: it starts down by your feet and comes up with you
	local lift = rig.Actions.Lift
	if lift then
		local u = lift.T / lift.D
		local g = u < 0.3 and 1 or 1 - ease((u - 0.3) / 0.7)
		spot += Vector3.new(0, -1.25 * g, -0.45 * g)
	end
	-- out of the bag: it drops into your arms with a little give
	local rec = rig.Actions.Receive
	if rec then
		local u = rec.T / rec.D
		spot += Vector3.new(0, 0.5 * (1 - ease(u * 1.8)) - 0.12 * math.sin(u * math.pi), 0)
	end
	return { Spot = spot, Size = size, Over = over, W = 1 }
end

-- one arm onto a torso-space point T (the palm goes there, or as close as the arm reaches): sets pose.R
local function solveArm(rig, pose, side: string, T: Vector3, w: number)
	local arm = rig.Arms[side]
	if not arm or w <= 0.001 then return end
	local R1, R2
	if arm.E == nil then
		R1 = fromTo((arm.H - arm.S).Unit, (T - arm.S).Unit)
	else
		-- two bones: the elbow swings out to the side and a little down and back
		local sgn = arm.Sgn
		local d = T - arm.S
		local dist = math.clamp(d.Magnitude, math.abs(arm.L1 - arm.L2) + 0.05, arm.L1 + arm.L2 - 0.02)
		local dir = d.Magnitude > 1e-4 and d.Unit or Vector3.new(0, -1, 0)
		local cosA = math.clamp((arm.L1 * arm.L1 + dist * dist - arm.L2 * arm.L2) / (2 * arm.L1 * dist), -1, 1)
		local pole = Vector3.new(sgn, -0.55, 0.4)
		local perp = pole - dir * pole:Dot(dir)
		perp = if perp.Magnitude > 1e-4 then perp.Unit else Vector3.new(sgn, 0, 0)
		local E = arm.S + dir * arm.L1 * cosA + perp * arm.L1 * math.sqrt(1 - cosA * cosA)
		R1 = fromTo((arm.E - arm.S).Unit, (E - arm.S).Unit)
		local fore = R1:VectorToWorldSpace((arm.H - arm.E).Unit)
		local Q = fromTo(fore, (arm.S + dir * dist - E).Unit)
		R2 = R1:Inverse() * Q * R1
	end
	local sh, el = "Shoulder" .. side, "Elbow" .. side
	-- the IK owns the arm in proportion to w: fade out whatever angles the arm had
	for k = 1, 3 do pose[sh][k] *= (1 - w) end
	pose.R[sh] = (pose.R[sh] or I):Lerp(R1, w)
	if R2 then
		for k = 1, 3 do pose[el][k] *= (1 - w) end
		pose.R[el] = (pose.R[el] or I):Lerp(R2, w)
	end
end

-- put both palms on the egg's sides: as far round the front as the arms reach, a little below its middle
local function solveCarry(rig, pose, egg)
	local spot, size = egg.Spot, egg.Size
	local a, b, c = size.X / 2, size.Y / 2, size.Z / 2
	local function edge(y: number, z: number): number
		local q = 1 - ((y - spot.Y) / b) ^ 2 - ((z - spot.Z) / c) ^ 2
		return a * math.sqrt(math.max(q, 0))
	end
	for side, arm in pairs(rig.Arms) do
		local sgn = arm.Sgn
		local one = arm.E == nil
		local reach = if one then (arm.H - arm.S).Magnitude * 0.97 else (arm.L1 + arm.L2) * 0.9
		local y = spot.Y - b * (one and 0.12 or 0.35)
		local margin = one and 0 or 0.1
		local function at(z: number): Vector3 return Vector3.new(sgn * (edge(y, z) + margin), y, z) end
		local lo, hi = spot.Z + c * 0.8, spot.Z - c * (one and 0.45 or 0.7)
		local z
		if (at(hi) - arm.S).Magnitude <= reach then
			z = hi
		elseif (at(lo) - arm.S).Magnitude > reach then
			z = lo
		else
			for _ = 1, 10 do
				local mid = (lo + hi) / 2
				if (at(mid) - arm.S).Magnitude <= reach then lo = mid else hi = mid end
			end
			z = lo
		end
		solveArm(rig, pose, side, at(z), egg.W)
	end
end

-- the rim of the steering wheel in a vehicle seat: where each hand goes this frame
local function wheelOf(rig, seat: BasePart): BasePart?
	if rig.WheelSeat ~= seat then
		rig.WheelSeat = seat
		rig.Wheel = nil
		local m: Instance? = seat.Parent
		while m and m ~= workspace do
			local w = m:FindFirstChild("SteeringWheel", true)
			if w and w:IsA("BasePart") then rig.Wheel = w break end
			m = m.Parent
		end
	end
	return rig.Wheel
end
local function rimPoint(wheel: BasePart, seat: BasePart, angle: number): Vector3
	local axis = wheel.CFrame.RightVector -- a cylinder's axis is its X
	local up = seat.CFrame.UpVector
	up = (up - axis * up:Dot(axis))
	up = up.Magnitude > 1e-3 and up.Unit or Vector3.yAxis
	local right = seat.CFrame.RightVector
	right = (right - axis * right:Dot(axis) - up * right:Dot(up))
	right = right.Magnitude > 1e-3 and right.Unit or axis:Cross(up)
	local r = wheel.Size.Y / 2 * 0.92
	return wheel.Position + (right * math.sin(angle) + up * math.cos(angle)) * r
end

--------------------------------------------------------------------------------
-- pose building
--------------------------------------------------------------------------------
local function locomotion(rig, pose, dt: number, egg)
	local root = rig.HRP
	local vel = root.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local v = flat.Magnitude
	local lv = root.CFrame:VectorToObjectSpace(flat)
	local f, s = 0, 0
	if v > 0.5 then f, s = -lv.Z / v, lv.X / v end
	local carry = egg ~= nil
	local sneak = rig.Stance == "Sneak" and not rig.Sprint and not carry
	local t0 = os.clock()
	local sprint = (rig.Sprint or v > 19) and not sneak
	local heavy = carry and math.clamp((egg.Size.Y - 1.4) / 3, 0, 1) or 0
	-- one cycle = two steps; heavier and sneakier steps are shorter
	local stride = sprint and 7.6 or (sneak and 5.6 or (carry and (4.6 - heavy) or 5.4))
	rig.Phase = (rig.Phase + dt * (v / stride) * math.pi * 2) % (math.pi * 2)
	rig.Move += ((v > 0.6 and 1 or 0) - rig.Move) * math.min(1, dt * 10)
	local A = math.clamp(v / 16, 0, 1.25) * rig.Move
	local ph = rig.Phase
	local sR, sL = math.sin(ph), -math.sin(ph)
	local cR, cL = math.cos(ph), -math.cos(ph)

	-- legs: swing along the move direction (forward / back / strafe); the swinging leg bends its knee
	if not sneak then
		local swing = (sprint and 0.82 or 0.56) * math.min(A, 1.1) * (carry and (0.8 - 0.2 * heavy) or 1)
		add(pose, "HipR", sR * swing * f, 0, sR * swing * s * 0.6)
		add(pose, "HipL", sL * swing * f, 0, sL * swing * s * 0.6)
		if rig.R15 then
			local bend = (sprint and 1.55 or 1.05) * math.min(A, 1)
			add(pose, "KneeR", -math.max(0, cR) * bend - 0.05)
			add(pose, "KneeL", -math.max(0, cL) * bend - 0.05)
		end
	end

	-- body: lean into the run (back under an egg), twist with the stride, bank into turns, waddle when heavy
	local lean = -(sprint and 0.26 or 0.08) * A * f
	if carry then lean += 0.05 + 0.1 * heavy end
	rig.Lean += (lean - rig.Lean) * math.min(1, dt * 8)
	local yawRate = root.AssemblyAngularVelocity.Y
	rig.Bank += (math.clamp(-yawRate * 0.035 * A, -0.18, 0.18) - rig.Bank) * math.min(1, dt * 6)
	local waddle = carry and sR * (0.03 + 0.05 * heavy) * A or 0
	add(pose, "Root", rig.Lean, sR * 0.07 * A * f, -s * 0.1 * A + rig.Bank + waddle)
	if rig.R15 then add(pose, "Waist", 0, -sR * 0.1 * A * f, 0) end
	add(pose, "Neck", -rig.Lean * 0.6, 0, -rig.Bank * 0.5)

	-- airborne: tuck the legs (the leading one higher on the way up)
	local air = (rig.Hum.FloorMaterial == Enum.Material.Air) and 1 or 0
	rig.Air += (air - rig.Air) * math.min(1, dt * 10)
	if rig.Air > 0.01 then
		local up = vel.Y > 2
		add(pose, "HipR", 0.8, 0, 0.05, 0, 0, 0, rig.Air)
		add(pose, "HipL", up and 0.15 or 0.45, 0, -0.05, 0, 0, 0, rig.Air)
		if rig.R15 then
			add(pose, "KneeR", -1.25, 0, 0, 0, 0, 0, rig.Air)
			add(pose, "KneeL", up and -0.5 or -0.9, 0, 0, 0, 0, 0, rig.Air)
		end
	end
	pose.Plant = 1 - rig.Air

	-- sneaking: a cartoon creep. Crouched and leaning in; each knee lifts high and the foot reaches forward and is
	-- set down carefully, then the body rolls over it (the planting supplies the dip); the weight rocks onto the
	-- planted leg; the head stays up, peeking about
	if sneak then
		local k = math.clamp(v / 10, 0, 1.2) * rig.Move
		for _, leg in ipairs({ { "R", 0 }, { "L", math.pi } }) do
			local u = ((ph + leg[2]) % (math.pi * 2)) / (math.pi * 2)
			local hip, lift
			if u < 0.42 then
				local q = u / 0.42
				hip = -0.4 + 1.15 * ease(q)
				lift = math.sin(q * math.pi)
			else
				hip = 0.75 - 1.15 * ((u - 0.42) / 0.58)
				lift = 0
			end
			hip *= k * f
			lift *= k
			if rig.R15 then
				add(pose, "Hip" .. leg[1], 0.85 + hip + lift * 0.55, 0, (leg[1] == "R" and 1 or -1) * 0.08)
				add(pose, "Knee" .. leg[1], -1.3 - lift * 1.25)
			else
				add(pose, "Hip" .. leg[1], 0.45 + hip * 0.9 + lift * 0.45, 0, (leg[1] == "R" and 1 or -1) * 0.06)
			end
		end
		local peek = math.sin(t0 * 0.8) * 0.4 * (1 - rig.Move) + math.sin(ph) * 0.12 * k
		add(pose, "Root", -0.42, math.sin(ph) * 0.06 * k, math.sin(ph) * 0.07 * k)
		add(pose, "Neck", 0.38, peek, 0)
	end

	-- arms (when carrying, the IK pass after planting puts them on the egg)
	local t = os.clock()
	if carry then
		-- the weight bounces in the arms with each step
		local bounce = math.abs(sR) * 0.035 * A
		add(pose, "ShoulderR", bounce) add(pose, "ShoulderL", bounce)
		-- peek round a tall egg
		add(pose, "Neck", -0.1, 0.55 * egg.Over, 0.3 * egg.Over)
		if egg.Over > 0 then add(pose, "Root", 0, 0, 0.05 * egg.Over) end
	elseif sprint or not rig.Aiming or not rig.Combat then
		-- run: arms pump opposite the legs, launcher swings low
		local pump = (sprint and 0.95 or 0.5) * math.min(A, 1.1)
		add(pose, "ShoulderR", -sR * pump * math.max(f, 0.35) + (sprint and 0.18 or 0.04), 0, 0.07)
		add(pose, "ShoulderL", -sL * pump * math.max(f, 0.35) + (sprint and 0.18 or 0.04), 0, -0.07)
		if rig.R15 then
			local e = sprint and 1.35 or 0.3 + 0.35 * math.min(A, 1)
			add(pose, "ElbowR", e + math.max(0, -sR) * 0.3) add(pose, "ElbowL", e + math.max(0, -sL) * 0.3)
		end
	elseif sneak then
		-- low ready: the launcher held in close, pointing ahead and down, rocking a little with each step
		local p = math.clamp(rig.AimPitch, -0.9, 0.9) * 0.5
		local bob = math.sin(ph * 2) * 0.04 * math.min(A, 1)
		add(pose, "ShoulderR", 0.75 + p + bob, 0.3, -0.05)
		add(pose, "ShoulderL", 0.95 + p + bob, -0.55, 0.05)
		if rig.R15 then add(pose, "ElbowR", 0.75) add(pose, "ElbowL", 1.15) end
	else
		-- aim: launcher up and following the pitch; off hand braces the barrel
		local p = math.clamp(rig.AimPitch, -0.9, 0.9)
		local sway = math.sin(t * 1.7) * 0.025 + sR * 0.035 * A
		add(pose, "ShoulderR", 1.5 + p + sway, 0.18, -0.05)
		add(pose, "ShoulderL", 1.32 + p + sway, -0.62, 0.05)
		if rig.R15 then add(pose, "ElbowR", 0.12) add(pose, "ElbowL", 0.72) end
		add(pose, "Neck", -p * 0.55, 0.05)
		if rig.R15 then add(pose, "Waist", -p * 0.25, 0.08) end
	end

	-- standing still: breathing and a slow shift of weight
	local still = 1 - rig.Move
	if still > 0.01 then
		local br = math.sin(t * 2.1)
		add(pose, "Root", br * 0.012, 0, math.sin(t * 0.6) * 0.02, 0, 0, 0, still)
		add(pose, "Neck", -br * 0.03, 0, 0, 0, 0, 0, still)
		if not carry then sym(pose, "Shoulder", br * 0.02, 0, 0.04 + br * 0.015, still) end
	end
end

local function actionPose(rig, pose, name: string, a, u: number): number
	local w = math.sin(math.min(u, 1) * math.pi) -- in and out
	local O = a.Opts
	if name == "Dodge" then
		-- a somersault along the roll direction (local axis), legs and arms tucked; the body leaves the floor
		local dir = O.Dir or Vector3.new(0, 0, -1)
		local axis = Vector3.yAxis:Cross(dir)
		if axis.Magnitude < 0.01 then axis = Vector3.xAxis end
		local e = ease(u)
		local tuck = math.sin(math.min(u * 1.15, 1) * math.pi)
		local roll = CFrame.fromAxisAngle(axis.Unit, e * math.pi * 2)
		pose.RootRoll = roll
		pose.PlantAll = 1 -- the tucked body rolls along the floor (planted on whatever part is lowest)
		-- spin about the body's middle (the root part's centre), not the Root joint (low down on R15)
		local p0 = rig.Joints.Root.P0
		local swing = roll:VectorToWorldSpace(p0) - p0
		add(pose, "Root", 0, 0, 0, swing.X, swing.Y, swing.Z)
		sym(pose, "Hip", 1.7, 0, 0.12, tuck)
		sym(pose, "Shoulder", 1.25, 0.2, 0.1, tuck)
		if rig.R15 then
			add(pose, "KneeR", -2.0, 0, 0, 0, 0, 0, tuck) add(pose, "KneeL", -2.0, 0, 0, 0, 0, 0, tuck)
			add(pose, "ElbowR", 1.3, 0, 0, 0, 0, 0, tuck) add(pose, "ElbowL", 1.3, 0, 0, 0, 0, 0, tuck)
		end
		add(pose, "Neck", -0.5, 0, 0, 0, 0, 0, tuck)
		return 1
	elseif name == "Hit" or name == "BigHit" then
		-- snapped back from the blow, knees giving, then recovering
		local big = name == "BigHit"
		local k = (u < 0.12 and ease(u / 0.12) or 1 - ease((u - 0.12) / 0.88)) * (big and 1.4 or 1)
		local side = O.Side or 0
		add(pose, "Root", 0.16 * k, side * 0.22 * k, side * 0.1 * k)
		add(pose, "Neck", 0.4 * k, -side * 0.3 * k)
		sym(pose, "Shoulder", -0.4 * k, 0, 0.65 * k)
		-- legs stay under the body (hips undo the torso's tilt)
		add(pose, "HipR", -0.16 * k + 0.12 * k, 0, 0.06 * k) add(pose, "HipL", -0.16 * k - 0.05 * k, 0, -0.06 * k)
		if rig.R15 then
			add(pose, "Waist", 0.28 * k)
			add(pose, "KneeR", -0.45 * k) add(pose, "KneeL", -0.25 * k)
			add(pose, "ElbowR", 0.7 * k) add(pose, "ElbowL", 0.7 * k)
		end
		return 1
	elseif name == "Startle" then
		-- jumps back with the arms up in front of the face (an egg bursting right in front of you)
		local k = u < 0.15 and ease(u / 0.15) or 1 - ease((u - 0.15) / 0.85)
		add(pose, "Root", 0.22 * k)
		add(pose, "Neck", 0.3 * k)
		sym(pose, "Shoulder", 1.7 * k, 0.35 * k, 0.25 * k)
		if rig.R15 then add(pose, "ElbowR", 1.4 * k) add(pose, "ElbowL", 1.4 * k) add(pose, "Waist", 0.2 * k) end
		add(pose, "HipR", -0.12 * k) add(pose, "HipL", -0.2 * k)
		return 1
	elseif name == "Throw" then
		-- wind up over the shoulder, step into it, whip through and follow down
		local wind = u < 0.4 and ease(u / 0.4) or 1 - ease((u - 0.4) / 0.25)
		local through = u < 0.4 and 0 or math.sin(math.min((u - 0.4) / 0.6, 1) * math.pi)
		add(pose, "ShoulderR", 2.8 * wind + 1.0 * through, 0, 0.35 * wind)
		add(pose, "ShoulderL", 1.0 * wind + 0.3 * through, -0.3, -0.1)
		add(pose, "Root", 0.1 * wind - 0.18 * through, 0.35 * wind - 0.3 * through, 0)
		add(pose, "HipL", 0.35 * through) add(pose, "HipR", -0.2 * through)
		if rig.R15 then add(pose, "ElbowR", 1.3 * wind + 0.2 * through) add(pose, "Waist", 0, 0.45 * wind - 0.4 * through) end
		return 1
	elseif name == "Lift" then
		-- crouch to the nest (quick), then stand up with the egg; the arms follow the egg by IK (eggState)
		local g = u < 0.3 and ease(u / 0.3) or 1 - ease((u - 0.3) / 0.7)
		crouch(rig, pose, g)
		add(pose, "Neck", 0.4 * g)
		return 1
	elseif name == "Place" then
		-- crouch down and set the egg in the nest, let go, stand back up (the egg's path is in placeEgg)
		local g = u < 0.55 and ease(u / 0.55) or 1 - ease((u - 0.6) / 0.4)
		crouch(rig, pose, 0.8 * g)
		add(pose, "Neck", -0.35 * g)
		local p = resolve(O.Target)
		if p then pose.Look, pose.LookW = p, g end
		return 1
	elseif name == "Receive" then
		-- the egg drops into your arms: knees give a little, body rocks back to take the weight
		local k = math.sin(math.min(u * 1.4, 1) * math.pi)
		add(pose, "Root", 0.06 * k)
		if rig.R15 then sym(pose, "Hip", 0.3 * k, 0, 0) add(pose, "KneeR", -0.5 * k) add(pose, "KneeL", -0.5 * k) end
		add(pose, "Neck", -0.12 * k)
		return 1
	elseif name == "Pet" or name == "Feed" then
		-- reach out to the head (crouching for a small dino, stretching up for a big one) and pat it - or, with a
		-- treat, hold it still at the mouth while it eats
		local p = resolve(O.Target)
		if not p then return 0 end
		local env = envelope(u, 0.12, 0.18)
		local h = rig.HRP.CFrame:PointToObjectSpace(p).Y
		crouch(rig, pose, math.clamp((-0.3 - h) / 1.6, 0, 1) * env)
		add(pose, "Root", -0.12 * env)
		local hand = p
		if name == "Pet" then
			-- three gentle pats: the hand lifts and comes back down
			hand += Vector3.new(0, 0.32 * math.max(0, math.sin(u * math.pi * 7)) * env, 0)
		else
			hand += Vector3.new(0, math.sin(u * 30) * 0.03, 0)
		end
		pose.Reach.R = { P = hand, W = env }
		add(pose, "ShoulderL", 0.25 * env, 0, -0.1 * env)
		pose.Look, pose.LookW = p, env
		return 1
	elseif name == "Tap" then
		-- knock-knock on an egg: the hand goes to it twice
		local p = resolve(O.Target)
		if not p then return 0 end
		local env = envelope(u, 0.2, 0.2)
		crouch(rig, pose, math.clamp((-0.4 - rig.HRP.CFrame:PointToObjectSpace(p).Y) / 2.2, 0, 1) * env * (rig.Loop == "Kneel" and 0 or 1))
		local away = rig.HRP.Position - p
		away = Vector3.new(away.X, 0, away.Z)
		away = away.Magnitude > 1e-3 and away.Unit or Vector3.zero
		pose.Reach.R = { P = p + away * 0.45 * math.max(0, math.sin(u * math.pi * 4)), W = env }
		pose.Look, pose.LookW = p, env
		return 1
	elseif name == "Pickup" then
		-- "item get!": crouch and grab it off the floor, stand and hold it up high, bounce, bring the arm down
		local s = u * a.D
		local down, up, hold, lower = 0, 0, 0, 0
		if s < 0.3 then down = ease(s / 0.3)
		elseif s < 0.75 then down, up = 1 - ease((s - 0.3) / 0.45), ease((s - 0.3) / 0.45)
		elseif s < 1.4 then up, hold = 1, 1
		else lower = ease((s - 1.4) / 0.3) up = 1 - lower end
		crouch(rig, pose, down)
		local floor = rig.HRP.CFrame:PointToWorldSpace(Vector3.new(0.5, rig.Ground + 0.35, -1.4))
		pose.Reach.R = { P = floor, W = down }
		local bounce = hold * math.abs(math.sin((s - 0.75) * 9)) * 0.12
		add(pose, "ShoulderR", (3.0 + bounce) * up, 0, 0.12 * up)
		if rig.R15 then add(pose, "ElbowR", 0.05 * up) add(pose, "ElbowL", 1.3 * up) end
		add(pose, "ShoulderL", 0.15 * up, 0, -0.5 * up)
		add(pose, "Neck", 0.35 * up - 0.3 * down)
		add(pose, "Root", 0.06 * up, 0.12 * up, 0, 0, bounce * 1.2, 0)
		return 1
	elseif name == "Wave" then
		-- a big friendly wave: the arm goes up and out, the forearm (the whole arm on R6) swings side to side
		local env = envelope(u, 0.15, 0.2)
		local sway = math.sin(u * a.D * 13) * env
		if rig.R15 then
			add(pose, "ShoulderR", 0.3 * env, 0, 2.2 * env)
			add(pose, "ElbowR", 0.15 * env, 0, 0.45 * sway)
		else
			add(pose, "ShoulderR", 0.3 * env, 0, (2.45 + 0.3 * sway) * env)
		end
		add(pose, "Neck", 0.08 * env, 0, -0.12 * env)
		add(pose, "Root", 0, 0, -0.04 * env)
		return 1
	elseif name == "GetIn" then
		-- dropping into the seat: from a little above, ducking in, legs swinging down into place
		local k = 1 - ease(u)
		add(pose, "Root", -0.3 * k, 0, 0, 0, 0.9 * k, 0)
		sym(pose, "Hip", -1.0 * k, 0, 0.1 * k)
		if rig.R15 then add(pose, "KneeR", 1.0 * k) add(pose, "KneeL", 1.0 * k) end
		return 1
	elseif name == "GetOut" then
		-- hopped down: land with bent knees and stand
		local k = 1 - ease(u)
		crouch(rig, pose, 0.55 * k)
		sym(pose, "Shoulder", 0.4 * k, 0, 0.3 * k)
		return 1
	elseif name == "Victory" then
		-- a hop and three fist pumps, the other hand on the hip
		local pump = math.abs(math.sin(u * math.pi * 3))
		add(pose, "ShoulderR", 2.6 + pump * 0.35, 0, 0.3)
		if rig.R15 then add(pose, "ElbowR", 0.9 - pump * 0.6) add(pose, "ElbowL", 1.4) end
		add(pose, "ShoulderL", 0.15, 0, -0.55)
		add(pose, "Root", 0.08 + pump * 0.04, 0.15, 0, 0, pump * 0.22, 0)
		add(pose, "Neck", 0.25)
		return w
	end
	return 0
end

local function loopPose(rig, pose, name: string, t: number, dt: number)
	local rootY = rig.Joints.Root.P0.Y
	if name == "Downed" then
		-- prone on the ground, reaching forward in a slow crawl
		local c = math.sin(t * 2.4)
		pose.Plant = 0
		add(pose, "Root", -1.5, 0, c * 0.05, 0, rig.Ground + 0.55 - rootY, 0)
		add(pose, "ShoulderR", 2.7 + c * 0.35, 0, 0.25)
		add(pose, "ShoulderL", 2.7 - c * 0.35, 0, -0.25)
		sym(pose, "Hip", 0.08, 0, 0.15)
		add(pose, "Neck", 0.95)
		if rig.R15 then add(pose, "KneeR", -0.3 - math.max(0, c) * 0.6) add(pose, "KneeL", -0.3 - math.max(0, -c) * 0.6) end
	elseif name == "Revive" or name == "Kneel" then
		-- down on one knee: pumping a friend's chest, or watching an egg with your hands on your knee
		local revive = name == "Revive"
		local c = revive and math.sin(t * 11) or math.sin(t * 2) * 0.3
		add(pose, "Root", (revive and -0.22 or -0.12) - c * 0.04)
		if rig.R15 then
			-- a real kneel: the planting puts the left knee and the right foot on the floor
			add(pose, "HipR", 1.5) add(pose, "KneeR", -1.5)
			add(pose, "HipL", 0.05) add(pose, "KneeL", -1.5)
		else
			-- R6 has no knees: the back leg sinks below the floor, which reads as kneeling
			pose.Plant = 0
			add(pose, "Root", 0, 0, 0, 0, -1.0, 0)
			add(pose, "HipR", 1.5) add(pose, "HipL", -0.2, 0, -0.05)
		end
		if revive then
			if rig.R15 then add(pose, "ElbowR", 0.35 + c * 0.2) add(pose, "ElbowL", 0.35 + c * 0.2) end
			sym(pose, "Shoulder", 0.95 + c * 0.25, 0.3, 0)
			add(pose, "Neck", -0.35)
		else
			add(pose, "ShoulderR", 0.75 + c * 0.05, 0.1, -0.05) add(pose, "ShoulderL", 0.55, -0.1, 0.1)
			if rig.R15 then add(pose, "ElbowR", 0.7) add(pose, "ElbowL", 0.9) end
			add(pose, "Neck", -0.2)
		end
	elseif name == "Work" then
		-- hammering at the bench: wind up slow, slam down fast; the other hand steadies the work
		local P = 0.62
		local k = (t % P) / P
		local a = k < 0.68 and ease(k / 0.68) or 1 - ((k - 0.68) / 0.32) ^ 0.5
		add(pose, "ShoulderR", 0.8 + 2.0 * a, 0, 0.12)
		if rig.R15 then add(pose, "ElbowR", 0.25 + 0.9 * a) add(pose, "ElbowL", 0.6) add(pose, "Waist", 0.06 * a, 0.12 * a) end
		add(pose, "ShoulderL", 1.0, -0.25, 0.05)
		add(pose, "Root", -0.12 - 0.06 * (1 - a), 0.05 * a)
		add(pose, "Neck", -0.3)
	elseif name == "Drive" then
		-- seated, hands on the wheel (the IK pass puts them on its rim), leaning into turns, bumps up the spine
		pose.Plant = 0
		local seat = rig.Hum.SeatPart
		local yawRate = seat and seat.AssemblyAngularVelocity.Y or 0
		rig.Steer += (math.clamp(yawRate * 0.45, -1, 1) - rig.Steer) * math.min(1, dt * 8)
		local vy = seat and seat.AssemblyLinearVelocity.Y or 0
		local accel = (vy - rig.SeatVY) / math.max(dt, 1e-3)
		rig.SeatVY = vy
		rig.Bump += (math.clamp(-accel * 0.004, -0.4, 0.4) - rig.Bump) * math.min(1, dt * 14)
		local st = rig.Steer
		add(pose, "Root", 0.08 + rig.Bump * 0.25, 0, -st * 0.12, 0, rig.Bump * 0.5, 0)
		if rig.R15 then
			sym(pose, "Hip", 1.45, 0, 0.08)
			add(pose, "KneeR", -1.35) add(pose, "KneeL", -1.35)
		else
			sym(pose, "Hip", 1.57, 0, 0.04)
		end
		add(pose, "Neck", -0.06 - rig.Bump * 0.4, st * 0.25, st * 0.06)
		local wheel = seat and wheelOf(rig, seat)
		if seat and wheel then
			-- ten and two, turning with the wheel
			local turn = -st * 0.95
			pose.Reach.R = { P = rimPoint(wheel, seat, 0.95 + turn), W = 1 }
			pose.Reach.L = { P = rimPoint(wheel, seat, -0.95 + turn), W = 1 }
		else
			sym(pose, "Shoulder", 1.25, 0, -0.1)
		end
	elseif name == "Ride" then
		-- on your companion's back, galloping for the portal: legs either side, leaning in, hands forward
		pose.Plant = 0
		local v = flat3(rig.HRP.AssemblyLinearVelocity).Magnitude
		local gallop = math.min(1, v / 20)
		local bob = math.abs(math.sin(t * 11)) * 0.18 * gallop
		add(pose, "Root", -0.18 - 0.1 * gallop, 0, 0, 0, bob, 0)
		sym(pose, "Hip", 1.05, 0, 0.55)
		if rig.R15 then add(pose, "KneeR", -1.2) add(pose, "KneeL", -1.2) end
		sym(pose, "Shoulder", 0.9 + bob, 0.15, -0.05)
		if rig.R15 then add(pose, "ElbowR", 0.7) add(pose, "ElbowL", 0.7) end
		add(pose, "Neck", 0.25 + 0.1 * gallop)
	elseif name == "Rodeo" then
		local tilt = rig.Tilt
		local buck = math.sin(t * 9) * 0.12
		pose.Plant = 0
		add(pose, "Root", -0.25 + buck, 0, -tilt * 0.6, 0, -0.9 + math.abs(buck) * 2, 0)
		sym(pose, "Hip", 1.35, 0, 0.75)
		if rig.R15 then add(pose, "KneeR", -1.3) add(pose, "KneeL", -1.3) end
		add(pose, "ShoulderR", 1.1 - buck * 2, 0.4, 0.2 + tilt * 0.4)
		add(pose, "ShoulderL", 1.1 + buck * 2, -0.4, -0.2 + tilt * 0.4)
		add(pose, "Neck", 0.2 + buck, 0, tilt * 0.3)
	end
end

--------------------------------------------------------------------------------
-- writing the joints
--------------------------------------------------------------------------------
-- a parent-space pose entry as this joint's Transform
local function toTransform(j, v, R: CFrame?, roll: CFrame?): CFrame
	local rot = CFrame.Angles(v[1], v[2], v[3])
	if R then rot = rot * R end
	if roll then rot = roll * rot end
	return CFrame.new(j.C0rInv:VectorToWorldSpace(Vector3.new(v[4], v[5], v[6]))) * (j.C0rInv * rot * j.C0r)
end

local function isZero(v): boolean
	return v[1] == 0 and v[2] == 0 and v[3] == 0 and v[4] == 0 and v[5] == 0 and v[6] == 0
end

-- out = (offsets * what the Animator wrote) blended towards the full-body pose by wb
local function write(rig, full, offs, wb: number)
	for _, name in ipairs(NAMES) do
		local j = rig.Joints[name]
		if not j then continue end
		local m = j.Motor :: any
		local cur = m.Transform
		-- a joint no animation track touches keeps what we wrote last frame: don't stack on top of ourselves
		local base = if j.Last and cur == j.Last then j.Base else cur
		j.Base = base
		local roll = name == "Root" and offs.RootRoll or nil
		local out = base
		local ov = offs[name]
		if roll or not isZero(ov) then out = toTransform(j, ov, nil, roll) * base end
		if wb > 0.002 then
			local target = toTransform(j, full[name], full.R[name], roll)
			out = if wb >= 0.999 then target else out:Lerp(target, wb)
		end
		m.Transform = out
		j.Last = out
	end
end

-- hand the joints back to the Animator (or to rest, if nothing animates them)
local function restore(rig)
	for _, j in pairs(rig.Joints) do
		local m = j.Motor :: any
		if j.Last and m.Transform == j.Last then m.Transform = j.Base or I end
		j.Last = nil
	end
end

-- the egg you're setting into a nest: from your arms down to its seat, then you let go
local function placeEgg(rig, a, torsoW: CFrame, carrySpot: Vector3?)
	local O = a.Opts
	local u = a.T / a.D
	local target = typeof(O.Target) == "CFrame" and O.Target or (resolve(O.Target) and CFrame.new(resolve(O.Target) :: Vector3)) or nil
	if not target then return nil end
	local size = O.Size or DEFAULT_EGG
	local from = torsoW * CFrame.new(carrySpot or Config.CarrySpot(size, rig.Torso.Size))
	local e = ease(u / 0.55)
	local cf = from:Lerp(target, e)
	if O.Model and O.Model.Parent then (O.Model :: Model):PivotTo(cf) end
	if u >= 0.58 and not a.Landed then
		a.Landed = true
		if O.Done then task.spawn(O.Done) end
	end
	-- hands on it until it's down, then let go
	return { Spot = torsoW:PointToObjectSpace(cf.Position), Size = size, Over = 0, W = 1 - ease((u - 0.6) / 0.22) }
end

local function step(dt: number)
	dt = math.min(dt, 1 / 20)
	for char, rig in pairs(rigs) do
		if not char.Parent then continue end
		if stale(rig) then
			rig = bind(char)
			if not rig then continue end
		end
		if rig.Hum.Health <= 0 then continue end
		-- swimming: Swim.luau drives the body (attribute "Swimming" on the player); hand the joints back and wait
		local owner = Players:GetPlayerFromCharacter(char)
		if owner and owner:GetAttribute("Swimming") then
			if rig.Active then restore(rig) rig.Active = false end
			continue
		end
		-- driving: sitting in any vehicle seat (yours or another player's), with a hop in and a hop out
		local seat = rig.Hum.SeatPart
		local driving = seat ~= nil and seat:IsA("VehicleSeat")
		if driving ~= rig.Driving then
			rig.Driving = driving
			rig.Actions[driving and "GetIn" or "GetOut"] = { T = 0, D = DUR[driving and "GetIn" or "GetOut"], Opts = {} }
			if driving then rig.SeatVY = seat.AssemblyLinearVelocity.Y end
		end
		local wantLoop = rig.UserLoop or (rig.Mounted and "Ride") or (driving and "Drive") or nil
		if wantLoop ~= rig.WantLoop then
			if wantLoop and rig.Loop ~= wantLoop then rig.Loop, rig.LoopT = wantLoop, 0 end
			rig.WantLoop = wantLoop
		end
		local egg = eggState(rig)
		-- fights, carrying and hands-on actions take over the whole body; elsewhere Roblox's own walk shows
		local full = rig.Combat or egg ~= nil
		for name in pairs(rig.Actions) do if FULL[name] then full = true break end end
		rig.Weight += ((full and 1 or 0) - rig.Weight) * math.min(1, dt * 7)
		if rig.WantLoop then rig.LoopW = math.min(1, rig.LoopW + dt * 5) else rig.LoopW = math.max(0, rig.LoopW - dt * 4) end
		if rig.LoopW <= 0 then rig.Loop = nil end
		-- recoil spring
		rig.RecoilV += (-rig.Recoil * 260 - rig.RecoilV * 22) * dt
		rig.Recoil += rig.RecoilV * dt
		local recoiling = math.abs(rig.Recoil) > 0.001 or math.abs(rig.RecoilV) > 0.01
		local wb = math.max(rig.Weight, rig.LoopW)
		if wb < 0.002 and next(rig.Actions) == nil and not recoiling and not rig.LookAt then
			if rig.Active then restore(rig) rig.Active = false end
			continue
		end
		rig.Active = true

		-- full-body layer: locomotion and stances, crossfaded with a loop
		local pose = newPose()
		pose.Plant = 0
		if wb > 0.002 then
			local base = 1 - rig.LoopW
			if base > 0 then
				local lp = newPose()
				locomotion(rig, lp, dt, egg)
				mix(pose, lp, base)
				pose.Plant += lp.Plant * base
			end
			if rig.Loop and rig.LoopW > 0 then
				rig.LoopT += dt
				local lp = newPose()
				loopPose(rig, lp, rig.Loop, rig.LoopT, dt)
				mix(pose, lp, rig.LoopW)
				pose.Plant += lp.Plant * rig.LoopW
			end
		end

		-- offsets: launcher recoil and one-shot actions (each fades its own weight)
		local offs = newPose()
		if recoiling then
			add(offs, "ShoulderR", rig.Recoil * 0.06, 0, 0)
			add(offs, "ShoulderL", rig.Recoil * 0.04, 0, 0)
			add(offs, "Root", rig.Recoil * 0.012, 0, 0, 0, 0, rig.Recoil * 0.015)
			if rig.R15 then add(offs, "ElbowR", rig.Recoil * 0.05) end
		end
		local plantAll = 0
		for name, a in pairs(rig.Actions) do
			a.T += dt
			local u = a.T / a.D
			if u >= 1 then
				rig.Actions[name] = nil
				if name == "Place" and a.Opts.Done and not a.Landed then task.spawn(a.Opts.Done) end
				continue
			end
			local ap = newPose()
			local k = actionPose(rig, ap, name, a, u)
			if ap.RootRoll then offs.RootRoll = ap.RootRoll end
			plantAll = math.max(plantAll, ap.PlantAll * k)
			mix(offs, ap, k)
		end
		mix(pose, offs, 1)
		pose.RootRoll = offs.RootRoll

		-- plant the feet: raise or lower the body so the lowest foot is on the floor (mid-roll: the lowest anything)
		local cfs = fk(rig, pose)
		local all = plantAll > 0.5
		local plant = if all then 1 else pose.Plant
		if wb > 0.002 and plant > 0.001 then
			local low = lowest(rig, cfs, all and rig.Parts or nil)
			if low then
				local dy = (rig.Ground - low) * plant
				pose.Root[5] += dy
				for p, cf in pairs(cfs) do if p ~= rig.HRP then cfs[p] = cf + Vector3.new(0, dy, 0) end end
			end
		end

		-- hands and head on real things: now we know where the torso is
		local torsoW = rig.Torso and cfs[rig.Torso] and rig.HRP.CFrame * cfs[rig.Torso]
		if torsoW and wb > 0.002 then
			local placing = rig.Actions.Place
			local held = placing and placeEgg(rig, placing, torsoW, egg and egg.Spot) or egg
			if held then solveCarry(rig, pose, held) end
			for side, r in pairs(pose.Reach) do
				if not (held and held.W > 0.5) then solveArm(rig, pose, side, torsoW:PointToObjectSpace(r.P), r.W) end
			end
		end
		-- the head turns to what you're looking at (an action's target, or PlayerAnim.Look)
		local lookP = resolve(rig.LookAt)
		local lookWant = lookP and 1 or 0
		if not lookP and pose.Look then lookP, lookWant = pose.Look, pose.LookW end
		rig.LookW += (lookWant - rig.LookW) * math.min(1, dt * 6)
		if lookP then rig.LookP = lookP end
		if torsoW and rig.LookP and rig.LookW > 0.01 and rig.Joints.Neck then
			local d = torsoW:PointToObjectSpace(rig.LookP) - Vector3.new(0, rig.NeckY + 0.5, 0)
			local yaw = math.clamp(math.atan2(-d.X, -d.Z), -1.1, 1.1)
			local pitch = math.clamp(math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z)), -0.8, 0.6)
			local k = rig.LookW
			-- full body: replace the head's own angles with the look; over Roblox's walk: add it on top
			local target = pose.Neck
			target[1] = target[1] * (1 - k) + pitch * k
			target[2] = target[2] * (1 - k) + yaw * k
			if wb < 0.999 then add(offs, "Neck", pitch * k * (1 - wb), yaw * k * (1 - wb)) end
		end
		write(rig, pose, offs, wb)

		-- the egg goes where the arms are (the weld is the server's; where it sits is ours, on every screen)
		if egg and torsoW then
			local wobble = CFrame.Angles(0, 0, math.sin(rig.Phase) * 0.03 * rig.Move)
			if rig.Proxy then
				local px = rig.Proxy
				local sway = CFrame.Angles(0, 0, math.sin(os.clock() * 2.2) * 0.06)
				px.Model:PivotTo(torsoW * CFrame.new(egg.Spot) * sway * px.Rot * px.Off:Inverse())
			elseif rig.EggWeld and rig.EggWeld.Parent and not rig.Actions.Place then
				rig.EggWeld.C0 = CFrame.new(egg.Spot) * wobble * (rig.EggTail or I)
			end
		end
	end
end

--------------------------------------------------------------------------------
local started = false
function PlayerAnim.Start()
	if started then return end
	started = true
	-- everyone standing at a site is animated by us (attribute Site is set by the server)
	local function watch(plr: Player)
		local function apply()
			local char = plr.Character
			if not char then return end
			local rig = rigOf(char)
			if rig then rig.Combat = plr:GetAttribute("Site") ~= nil end
		end
		plr:GetAttributeChangedSignal("Site"):Connect(apply)
		-- an egg in your arms (a nest raid sets Holding, camp sets HeldEgg): everyone sees you carry it. Lifting
		-- one out of a nest crouches down for it; one out of your bag just drops into your arms.
		local function carry()
			local char = plr.Character
			local rig = char and rigOf(char)
			if not rig then return end
			local fromNest = plr:GetAttribute("Holding") ~= nil
			local holding = fromNest or plr:GetAttribute("HeldEgg") ~= nil or plr:GetAttribute("HeldDino") ~= nil
			if holding and not rig.Carrying then
				rig.Carrying = true
				PlayerAnim.Act(char, fromNest and "Lift" or "Receive")
			elseif not holding and rig.Carrying then
				rig.Carrying = false
				rig.Actions.Lift, rig.Actions.Receive = nil, nil
			end
		end
		plr:GetAttributeChangedSignal("Holding"):Connect(carry)
		plr:GetAttributeChangedSignal("HeldEgg"):Connect(carry)
		plr:GetAttributeChangedSignal("HeldDino"):Connect(carry)
		plr:GetAttributeChangedSignal("Downed"):Connect(function()
			PlayerAnim.SetLoop(plr.Character, plr:GetAttribute("Downed") and "Downed" or nil)
		end)
		-- riding a companion home (the rover flipped): the Ride pose while "Mount" is set
		local function mount()
			local rig = plr.Character and rigOf(plr.Character)
			if rig then rig.Mounted = plr:GetAttribute("Mount") ~= nil end
		end
		plr:GetAttributeChangedSignal("Mount"):Connect(mount)
		-- picking an item up off the floor (Boss Keys, ...): the server bumps PickupTick, everyone sees it
		plr:GetAttributeChangedSignal("PickupTick"):Connect(function()
			if plr.Character then PlayerAnim.Act(plr.Character, "Pickup") end
		end)
		plr.CharacterAdded:Connect(function(c)
			c:WaitForChild("Humanoid", 10)
			c:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.2)
			bind(c)
			apply()
			carry()
		end)
		if plr.Character then task.spawn(function() bind(plr.Character :: Model) apply() carry() end) end
	end
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
	Players.PlayerAdded:Connect(watch)
	-- after the Animator has written its tracks for this frame
	RunService.PreSimulation:Connect(step)
end

PlayerAnim.Rig = rigOf
return PlayerAnim
