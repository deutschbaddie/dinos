--[[
	Gaits — procedural locomotion generators and keyframe action evaluation.

	Pose values: { rx, ry, rz, px, py, pz }. In keyframe poses, a joint name prefixed with "~"
	(e.g. "~Arm") expands to a mirrored Right/Left pair: RightArm gets the values as written,
	LeftArm gets ry, rz and px negated.
]]

local Gaits = {}

local TAU = math.pi * 2
local SIDES = { { "Right", 1, 0 }, { "Left", -1, 0.5 } } -- name, mirror sign, phase offset

local function easeFn(name)
	local E = Gaits.Ease
	return E[name] or E.Sine
end

-- Easing table is shared with init (assigned below to avoid a require cycle)
Gaits.Ease = {
	Linear = function(a) return a end,
	Sine = function(a) return 0.5 - math.cos(a * math.pi) * 0.5 end,
	In = function(a) return a * a end,
	Out = function(a) return 1 - (1 - a) * (1 - a) end,
	Snap = function(a) return 1 - (1 - a) ^ 4 end,
	Back = function(a)
		local c1, c3 = 1.70158, 2.70158
		return 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
	end,
}

-- Footstep detection: fires "Footstep" on the animator when a foot plants
function Gaits.footsteps(anim, phase: number, running: boolean, store)
	for _, s in ipairs(SIDES) do
		local side, _, offset = s[1], s[2], s[3]
		local p = (phase + offset - 0.25) % 1
		local last = store[side]
		if last and p < last then
			anim:_fire("Footstep", { Side = side, Running = running })
		end
		store[side] = p
	end
end

-- Distribute a rotation across a chain of joints (weights grow toward the tip)
local function chain(anim, joints, rx, ry, rz, w)
	local n = #joints
	if n == 0 then return end
	for i, j in ipairs(joints) do
		local k = (i / n) / ((n + 1) / 2) -- sums to 1 across the chain
		anim:Add(j, rx * k, ry * k, rz * k, 0, 0, 0, w)
	end
end
Gaits.chain = chain

--------------------------------------------------------------------------------
-- BIPED (theropods: Velociraptor, T. rex, Carnotaurus, Spinosaurus, ...)
--------------------------------------------------------------------------------
local Biped = {}
Gaits.Biped = Biped

function Biped.Idle(anim, t: number, w: number, G)
	local I = G.Idle
	local S = G.Scale or 1
	local b = math.sin(t * TAU * I.Breath)
	local amp = I.BreathAmp or 1
	-- breathing: chest rises, torso pitches a touch, belly expands
	anim:Add("Torso", 0.014 * b * amp, 0, 0, 0, 0, 0, w)
	anim:Add("Chest", 0, 0, 0, 0, -0.045 * S * b * amp, -0.06 * S * b * amp, w)
	anim:Add("Pelvis", 0, 0.018 * math.sin(t * 0.55), 0.014 * math.sin(t * 0.8), 0, 0.025 * S * b * amp, 0, w)
	-- weight shifts between legs
	local shift = math.sin(t * 0.8)
	for _, s in ipairs(SIDES) do
		local side, sign = s[1], s[2]
		anim:Add(side .. "Thigh", 0.025 * b + 0.035 * shift * sign, 0, 0, 0, 0, 0, w)
		anim:Add(side .. "Shin", -0.05 * b - 0.03 * shift * sign, 0, 0, 0, 0, 0, w)
		anim:Add(side .. "Foot", 0.025 * b, 0, 0, 0, 0, 0, w)
		anim:Add(side .. "Arm", 0.06 * b, 0, -0.03 * sign, 0, 0, 0, w)
		anim:Add(side .. "Forearm", 0.05 * math.sin(t * 1.1 + sign), 0, 0, 0, 0, 0, w)
	end
	-- head look: twitchy snaps (raptors) or slow heavy sweeps (big predators)
	local yaw, pitch, tilt
	if I.Twitch then
		local st = anim.State.look
		if not st then
			st = { yaw = 0, pitch = 0, ty = 0, tp = 0, nextT = t, lastT = t }
			anim.State.look = st
		end
		local dt = math.clamp(t - st.lastT, 0, 0.1)
		st.lastT = t
		if t >= st.nextT then
			st.ty = (math.random() * 2 - 1) * I.Look
			st.tp = (math.random() * 2 - 1) * I.Look * 0.35
			st.nextT = t + 0.5 + math.random() * 1.8
		end
		local k = 1 - math.exp(-dt * 14)
		st.yaw += (st.ty - st.yaw) * k
		st.pitch += (st.tp - st.pitch) * k
		yaw, pitch = st.yaw, st.pitch
		tilt = math.noise(t * 0.4, 7.1) * 0.12
	else
		yaw = math.noise(t * 0.11, 1.7) * I.Look * 1.6
		pitch = math.noise(t * 0.09, 4.2) * I.Look * 0.5
		tilt = math.noise(t * 0.13, 9.4) * 0.08
	end
	chain(anim, G.Neck, 0.03 * b + pitch * 0.5, yaw * 0.55, 0, w)
	anim:Add("Head", pitch * 0.5 - 0.02 * b, yaw * 0.45, tilt, 0, 0, 0, w)
	anim:Add("Jaw", -(I.JawIdle or 0.03) * (0.6 + 0.4 * b), 0, 0, 0, 0, 0, w)
	-- tail: slow traveling wave
	for i, j in ipairs(G.Tail) do
		anim:Add(j, 0.02 * math.sin(t * 0.9 - i * 0.4), (I.Sway or 0.08) * math.sin(t * 1.3 - i * 0.55) * (0.6 + i * 0.22), 0, 0, 0, 0, w)
	end
end

function Biped.Locomote(anim, phase: number, w: number, G, P, running: boolean)
	local S = G.Scale or 1
	local phi = phase * TAU
	for _, s in ipairs(SIDES) do
		local side, sign, offset = s[1], s[2], s[3]
		local sp = phi + offset * TAU
		local swing = math.sin(sp)
		local lift = math.max(0, math.cos(sp))
		local thigh = P.Stride * swing + (P.ThighBias or 0)
		local shin = -P.Knee * lift - (P.KneeBias or 0.08)
		local foot = -(thigh + shin) * 0.85 + 0.35 * lift
		anim:Add(side .. "Thigh", thigh, 0, -0.03 * sign, 0, 0, 0, w)
		anim:Add(side .. "Shin", shin, 0, 0, 0, 0, 0, w)
		anim:Add(side .. "Foot", foot, 0, 0, 0, 0, 0, w)
		anim:Add(side .. "Toes", -0.35 * lift + 0.1 * math.max(0, -math.cos(sp)), 0, 0, 0, 0, 0, w)
		anim:Add(side .. "SickleClaw", -0.25 - 0.2 * lift, 0, 0, 0, 0, 0, w)
		if running then
			anim:Add(side .. "Arm", 0.45 + 0.08 * swing, 0, -0.08 * sign, 0, 0, 0, w)
			anim:Add(side .. "Forearm", -0.55, 0, 0, 0, 0, 0, w)
		else
			anim:Add(side .. "Arm", 0.1 - 0.12 * swing, 0, 0, 0, 0, 0, w)
			anim:Add(side .. "Forearm", -0.1, 0, 0, 0, 0, 0, w)
		end
	end
	local c2 = math.cos(2 * phi)
	anim:Add("Pelvis", 0, P.Yaw * math.sin(phi), P.Roll * math.sin(phi), 0, P.Bob * S * 0.5 * c2, 0, w)
	anim:Add("Torso", -P.Lean + 0.03 * math.cos(2 * phi + 0.4), -P.Yaw * 0.6 * math.sin(phi), 0, 0, 0, 0, w)
	anim:Add("Chest", 0, 0, 0, 0, -0.03 * S * c2, 0, w)
	chain(anim, G.Neck, P.Lean * 0.7 + P.HeadBob * math.cos(2 * phi - 0.6), -P.Yaw * 0.2 * math.sin(phi), 0, w)
	anim:Add("Head", P.Lean * 0.25 - P.HeadBob * 0.6 * math.cos(2 * phi - 0.9), -P.Yaw * 0.25 * math.sin(phi), 0, 0, 0, 0, w)
	anim:Add("Jaw", running and (-0.12 - 0.06 * math.sin(2 * phi)) or -0.03, 0, 0, 0, 0, 0, w)
	for i, j in ipairs(G.Tail) do
		anim:Add(j, (running and -0.05 or 0) + 0.04 * math.cos(2 * phi - i * 0.5), P.TailSway * math.sin(phi - i * 0.6) * (0.7 + i * 0.2), 0, 0, 0, 0, w)
	end
end


--------------------------------------------------------------------------------
-- QUADRUPED (Triceratops, Stegosaurus, Ankylosaurus, Brachiosaurus)
-- Legs: {Side}HindThigh/HindShin/HindFoot and {Side}FrontUpper/FrontLower/FrontFoot
--------------------------------------------------------------------------------
local Quadruped = {}
Gaits.Quadruped = Quadruped

-- walk = lateral 4-beat (RH, RF, LH, LF); run = trot (diagonal pairs)
local QUAD_WALK = { RightHind = 0, RightFront = 0.25, LeftHind = 0.5, LeftFront = 0.75 }
local QUAD_TROT = { RightHind = 0, LeftFront = 0, LeftHind = 0.5, RightFront = 0.5 }

function Quadruped.Idle(anim, t: number, w: number, G)
	local I = G.Idle
	local S = G.Scale or 1
	local b = math.sin(t * TAU * I.Breath)
	local amp = I.BreathAmp or 1
	anim:Add("Torso", 0.01 * b * amp, 0, 0, 0, 0, 0, w)
	anim:Add("Chest", 0, 0, 0, 0, -0.04 * S * b * amp, 0, w)
	anim:Add("Pelvis", 0, 0.012 * math.sin(t * 0.5), 0.018 * math.sin(t * 0.7), 0, 0.02 * S * b * amp, 0, w)
	local shift = math.sin(t * 0.7)
	for _, s in ipairs(SIDES) do
		local side, sign = s[1], s[2]
		anim:Add(side .. "HindThigh", 0.02 * b, 0, 0.02 * shift * sign, 0, 0, 0, w)
		anim:Add(side .. "HindShin", -0.03 * b, 0, 0, 0, 0, 0, w)
		anim:Add(side .. "FrontUpper", 0.015 * b, 0, 0.015 * shift * sign, 0, 0, 0, w)
	end
	local yaw = math.noise(t * 0.12, 2.1) * I.Look * 1.5
	local pitch = math.noise(t * 0.1, 6.6) * I.Look * 0.5 + 0.02 * b
	chain(anim, G.Neck, pitch * 0.6, yaw * 0.6, 0, w)
	anim:Add("Head", pitch * 0.4, yaw * 0.4, math.noise(t * 0.15, 3.3) * 0.06, 0, 0, 0, w)
	anim:Add("Jaw", -(I.JawIdle or 0.02) * (0.6 + 0.4 * b), 0, 0, 0, 0, 0, w)
	for i, j in ipairs(G.Tail) do
		anim:Add(j, 0.015 * math.sin(t * 0.8 - i * 0.4), (I.Sway or 0.06) * math.sin(t * 1.1 - i * 0.5) * (0.6 + i * 0.2), 0, 0, 0, 0, w)
	end
end

function Quadruped.Locomote(anim, phase: number, w: number, G, P, running: boolean)
	local S = G.Scale or 1
	local offsets = running and QUAD_TROT or QUAD_WALK
	for _, s in ipairs(SIDES) do
		local side = s[1]
		for _, limb in ipairs({ "Hind", "Front" }) do
			local sp = (phase + offsets[side .. limb]) * TAU
			local swing = math.sin(sp)
			local lift = math.max(0, math.cos(sp))
			if limb == "Hind" then
				local thigh = P.Stride * swing
				local shin = -P.Knee * lift - 0.04
				anim:Add(side .. "HindThigh", thigh, 0, 0, 0, 0, 0, w)
				anim:Add(side .. "HindShin", shin, 0, 0, 0, 0, 0, w)
				anim:Add(side .. "HindFoot", -(thigh + shin) * 0.9 + 0.2 * lift, 0, 0, 0, 0, 0, w)
			else
				local upper = P.Stride * 0.9 * swing
				local lower = -P.Knee * 0.9 * lift
				anim:Add(side .. "FrontUpper", upper, 0, 0, 0, 0, 0, w)
				anim:Add(side .. "FrontLower", lower, 0, 0, 0, 0, 0, w)
				anim:Add(side .. "FrontFoot", -(upper + lower) * 0.9 + 0.25 * lift, 0, 0, 0, 0, 0, w)
			end
		end
	end
	local phi = phase * TAU
	local beats = running and 2 or 4
	local bob = math.cos(beats * phi)
	anim:Add("Pelvis", 0, P.Yaw * math.sin(phi), P.Roll * math.sin(phi), 0, P.Bob * S * 0.5 * bob, 0, w)
	anim:Add("Torso", -P.Lean + 0.02 * math.cos(beats * phi + 0.6), -P.Yaw * 0.5 * math.sin(phi), -P.Roll * 0.7 * math.sin(phi + 1.2), 0, 0, 0, w)
	anim:Add("Chest", 0, 0, 0, 0, -0.02 * S * bob, 0, w)
	chain(anim, G.Neck, P.HeadBob * math.cos(beats * phi - 0.7), -P.Yaw * 0.3 * math.sin(phi), 0, w)
	anim:Add("Head", -P.HeadBob * 0.5 * math.cos(beats * phi - 1.0), 0, 0, 0, 0, 0, w)
	for i, j in ipairs(G.Tail) do
		anim:Add(j, 0.03 * math.cos(beats * phi - i * 0.5), P.TailSway * math.sin(phi - i * 0.55) * (0.7 + i * 0.18), 0, 0, 0, 0, w)
	end
end

--------------------------------------------------------------------------------
-- SWIM (Mosasaurus): traveling body wave + paddling flippers; Idle = slow hover
--------------------------------------------------------------------------------
local Swim = {}
Gaits.Swim = Swim

local function swimWave(anim, phase: number, w: number, G, amp: number, flip: number, bob: number)
	local S = G.Scale or 1
	local phi = phase * TAU
	anim:Add("Pelvis", 0, amp * 0.25 * math.sin(phi), 0, 0, bob * S * math.sin(phi * 0.5), 0, w)
	anim:Add("Torso", 0, -amp * 0.35 * math.sin(phi + 0.6), 0, 0, 0, 0, w)
	chain(anim, G.Neck, 0.02 * math.sin(phi), amp * 0.3 * math.sin(phi + 1.4), 0, w)
	anim:Add("Head", 0, amp * 0.2 * math.sin(phi + 1.8), 0, 0, 0, 0, w)
	for i, j in ipairs(G.Tail) do
		anim:Add(j, 0.02 * math.sin(phi - i * 0.4), amp * math.sin(phi - i * 0.7) * (0.5 + i * 0.28), 0, 0, 0, 0, w)
	end
	for _, s in ipairs(SIDES) do
		local side, sign = s[1], s[2]
		local f = math.sin(phi + (sign > 0 and 0 or math.pi) * 0.2)
		anim:Add(side .. "FrontFlipper", 0.15 * flip * f, 0.25 * flip * math.cos(phi) * sign, 0.35 * flip * f * sign, 0, 0, 0, w)
		anim:Add(side .. "HindFlipper", 0.12 * flip * math.sin(phi - 1.2), 0, 0.25 * flip * math.sin(phi - 1.2) * sign, 0, 0, 0, w)
	end
end

function Swim.Idle(anim, t: number, w: number, G)
	local I = G.Idle
	swimWave(anim, t * I.Freq, w, G, I.Amp, I.Flip, I.Bob)
	anim:Add("Jaw", -(I.JawIdle or 0.03), 0, 0, 0, 0, 0, w)
end

function Swim.Locomote(anim, phase: number, w: number, G, P, _running: boolean)
	swimWave(anim, phase, w, G, P.Amp, P.Flip, P.Bob)
end

--------------------------------------------------------------------------------
-- Keyframed actions
--------------------------------------------------------------------------------
local ZERO = { 0, 0, 0, 0, 0, 0 }

local function expandPose(pose)
	local out = {}
	for joint, v in pairs(pose) do
		local vals = { v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 0, v[5] or 0, v[6] or 0 }
		if string.sub(joint, 1, 1) == "~" then
			local base = string.sub(joint, 2)
			out["Right" .. base] = vals
			out["Left" .. base] = { vals[1], -vals[2], -vals[3], -vals[4], vals[5], vals[6] }
		else
			out[joint] = vals
		end
	end
	return out
end

function Gaits.compileKeys(action)
	local tracks = {}
	local dur = action.Duration
	for _, key in ipairs(action.Keys or {}) do
		local t, pose, ease = key[1], expandPose(key[2]), key[3] or "Sine"
		for joint, vals in pairs(pose) do
			local tr = tracks[joint]
			if not tr then
				tr = {}
				tracks[joint] = tr
			end
			table.insert(tr, { t, vals, ease })
		end
	end
	for _, tr in pairs(tracks) do
		table.sort(tr, function(a, b) return a[1] < b[1] end)
		if tr[1][1] > 0 then table.insert(tr, 1, { 0, ZERO, "Linear" }) end
		if tr[#tr][1] < dur - 1e-3 and not action.HoldEnd then
			table.insert(tr, { dur, ZERO, action.EndEase or "Sine" })
		end
	end
	if action.Events then table.sort(action.Events, function(a, b) return a[1] < b[1] end) end
	return tracks
end

local function sampleTrack(tr, t)
	local n = #tr
	if t <= tr[1][1] then return tr[1][2], tr[1][2], 0 end
	if t >= tr[n][1] then return tr[n][2], tr[n][2], 0 end
	for i = 1, n - 1 do
		local a, b = tr[i], tr[i + 1]
		if t < b[1] then
			local span = b[1] - a[1]
			local alpha = span > 1e-6 and (t - a[1]) / span or 1
			return a[2], b[2], easeFn(b[3])(alpha)
		end
	end
	return tr[n][2], tr[n][2], 0
end

function Gaits.evalAction(anim, tr, w: number)
	local action = tr.Action
	local t = math.clamp(tr.T, 0, action.Duration)
	for joint, track in pairs(action._tracks) do
		local a, b, k = sampleTrack(track, t)
		anim:Add(joint,
			a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k,
			a[4] + (b[4] - a[4]) * k, a[5] + (b[5] - a[5]) * k, a[6] + (b[6] - a[6]) * k, w)
	end
	-- vibration overlays (roar shudder, screech, stunned wobble...)
	if action.Shake then
		for _, sh in ipairs(action.Shake) do
			local joint, t0, t1, amp, freq, axis = sh[1], sh[2], sh[3], sh[4], sh[5], sh[6] or 3
			if t >= t0 and t <= t1 then
				local env = math.min(1, (t - t0) / 0.12, (t1 - t) / 0.2)
				local v = amp * env * math.sin(t * TAU * freq)
				local joints = string.sub(joint, 1, 1) == "~" and { "Right" .. string.sub(joint, 2), "Left" .. string.sub(joint, 2) } or { joint }
				for _, j in ipairs(joints) do
					if axis == 1 then anim:Add(j, v, 0, 0, 0, 0, 0, w)
					elseif axis == 2 then anim:Add(j, 0, v, 0, 0, 0, 0, w)
					else anim:Add(j, 0, 0, v, 0, 0, 0, w) end
				end
			end
		end
	end
	-- embedded locomotion windows (e.g. walk out of the jungle during an intro)
	if action.Gait then
		local G = anim.Profile.Gait
		tr._steps = tr._steps or {}
		for _, g in ipairs(action.Gait) do
			local t0, t1, mode, gw = g[1], g[2], g[3], g[4] or 1
			if t >= t0 and t <= t1 then
				local ramp = math.min(1, (t - t0) / 0.3, (t1 - t) / 0.3)
				local P = G[mode]
				local phase = (t - t0) * P.Freq * (g[5] or 1)
				Gaits[G.Type].Locomote(anim, phase, w * ramp * gw, G, P, mode == "Run")
				if G.Type ~= "Swim" then Gaits.footsteps(anim, phase, mode == "Run", tr._steps) end
			end
		end
	end
	if action.Procedural then
		local fn = Gaits.Procedural[action.Procedural.Type]
		if fn then fn(anim, t, w, action.Procedural, anim.Profile.Gait) end
	end
end

-- Data-driven procedural overlays referenced by profiles (Procedural = { Type = "...", ... })
Gaits.Procedural = {
	-- dizzy head circles after an impact
	Dizzy = function(anim, t, w, p, G)
		if t > p.T0 and t < p.T1 then
			local env = math.min(1, (t - p.T0) / 0.3, (p.T1 - t) / 0.3)
			anim:Add("Head", 0, p.Head[1] * math.sin(t * p.Rate) * env, p.Head[2] * math.cos(t * p.Rate) * env, 0, 0, 0, w)
			anim:Add(G.Neck[#G.Neck], 0, p.Neck * math.sin(t * p.Rate - 0.6) * env, 0, 0, 0, 0, w)
			anim:Add("Pelvis", 0, 0, p.Roll * math.sin(t * p.Rate * 0.5) * env, 0, 0, 0, w)
		end
	end,
}

return Gaits
