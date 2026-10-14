--[[
	Cam — authored camera language for TikTok shots. Every function is pure: give it the shot's local time
	and it returns a CFrame, so a shot looks identical on every take.

	  Cam.ease(kind, u)                     "linear" | "in" | "out" | "inout" | "snap" (fast start, long settle)
	  Cam.dolly(fromPos, toPos, look, u)    straight move, always looking at `look`
	  Cam.orbit(center, radius, height, a0, a1, u, lookY?)
	  Cam.chase(subjectCF, back, up, side, lookAhead)
	  Cam.low(subjectPos, dir, dist, side)  ground-hugging angle that makes things huge
	  Cam.whip(baseCF, yawFrom, yawTo, u)   a fast pan with a snap at the end
	  Cam.handheld(cf, t, amount)           deterministic breathing (noise, not random)
	  Cam.Shake:new() / :Kick(strength, t) / :Apply(cf, t)   impulse shake on cue (footfall, roar, slam)
]]

local Cam = {}

function Cam.ease(kind: string?, u: number): number
	u = math.clamp(u, 0, 1)
	if kind == "in" then return u * u * u end
	if kind == "out" then return 1 - (1 - u) ^ 3 end
	if kind == "inout" then return u < 0.5 and 4 * u * u * u or 1 - (-2 * u + 2) ^ 3 / 2 end
	if kind == "snap" then return 1 - (1 - u) ^ 5 end
	return u
end

function Cam.dolly(a: Vector3, b: Vector3, look: Vector3, u: number): CFrame
	return CFrame.lookAt(a:Lerp(b, u), look)
end

function Cam.orbit(center: Vector3, radius: number, height: number, a0: number, a1: number, u: number, lookY: number?): CFrame
	local a = a0 + (a1 - a0) * u
	local p = center + Vector3.new(math.cos(a) * radius, height, math.sin(a) * radius)
	return CFrame.lookAt(p, center + Vector3.new(0, lookY or 0, 0))
end

-- behind a moving subject (its LookVector = travel direction)
function Cam.chase(subject: CFrame, back: number, up: number, side: number?, lookAhead: number?): CFrame
	local f = Vector3.new(subject.LookVector.X, 0, subject.LookVector.Z)
	f = f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1)
	local r = Vector3.new(-f.Z, 0, f.X)
	local p = subject.Position - f * back + Vector3.new(0, up, 0) + r * (side or 0)
	return CFrame.lookAt(p, subject.Position + f * (lookAhead or 10))
end

-- low angle near the ground looking up at something
function Cam.low(subject: Vector3, from: Vector3, height: number, lookUp: number): CFrame
	local p = Vector3.new(from.X, from.Y + height, from.Z)
	return CFrame.lookAt(p, subject + Vector3.new(0, lookUp, 0))
end

function Cam.whip(base: CFrame, yawFrom: number, yawTo: number, u: number): CFrame
	local e = Cam.ease("snap", u)
	return base * CFrame.Angles(0, yawFrom + (yawTo - yawFrom) * e, 0)
end

function Cam.handheld(cf: CFrame, t: number, amount: number?): CFrame
	local a = amount or 1
	local rx = math.noise(t * 0.9, 1.3) * 0.012 * a
	local ry = math.noise(t * 0.8, 7.1) * 0.016 * a
	local rz = math.noise(t * 0.6, 3.7) * 0.008 * a
	return cf * CFrame.Angles(rx, ry, rz)
end

-- deterministic impulse shake: kicks decay; frequency fixed so every take shakes the same
local Shake = {}
Shake.__index = Shake
Cam.Shake = Shake

function Shake.new()
	return setmetatable({ Kicks = {} }, Shake)
end

function Shake:Kick(strength: number, at: number, decay: number?)
	table.insert(self.Kicks, { S = strength, T = at, D = decay or 0.45 })
end

function Shake:Apply(cf: CFrame, t: number): CFrame
	local x, y, z = 0, 0, 0
	for i, k in ipairs(self.Kicks) do
		local dt = t - k.T
		if dt >= 0 and dt < k.D * 3 then
			local env = k.S * math.exp(-dt / k.D * 2.2)
			x += math.sin(dt * 47 + i) * env * 0.035
			y += math.sin(dt * 39 + i * 2) * env * 0.03
			z += math.sin(dt * 31 + i * 3) * env * 0.02
		end
	end
	if x == 0 and y == 0 then return cf end
	return cf * CFrame.Angles(x, y, z)
end

return Cam
