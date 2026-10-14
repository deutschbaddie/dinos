--[[
	HatchStyles — the different ways an egg can hatch. Hatch.luau runs the scene (the shot over your shoulder, the
	cracks, the burst, the rarity stamp, the info card, handing you back); a style decides how the egg behaves on the
	way there, where the camera looks, how it pops and the baby's first seconds:

	  WOBBLE     the classic: it rocks (or bounces) harder and harder and bursts. Epic+ keep their own staging here
	             (the vortex lift, the golden pillar from the sky, the Secret blackout and implode)
	  PEEK       a chip of shell falls out and two little eyes peek through the hole: left, right, at you (you wave),
	             blink... POP. It sniffs the lens, tilts its head one way then the other, two happy hops
	  SPINPOP    it spins up like a top and lifts off inside a ring of orbiting cubes, stops dead, pops in mid-air
	             and the baby twirls down into the nest with a thump
	  SLEEPY     a dozing egg (Zzz) jolts at two sleepy cracks; the lid pops off and lands on the baby's head like a
	             hat. It's still asleep... a huge yawn, eyes open, it shakes the hat off
	  ERUPTION   Epic+ only: glowing fissures split the floor, light geysers burst from them, a beam blasts up out of
	             the egg into the roof and is sucked back in - BOOM - the baby stands in the fading light as a glowing
	             silhouette, eyes lit, and roars

	HatchStyles.Pick(rarity) never plays the same style twice in a row, and the grand ones belong to the rare tiers.
	(2026-10-14: "make some more hatching animations so it's not the same every time")

	A style: { Name, Shoulder (s of the over-the-shoulder shot), Build(tier) -> s, Hold (s after the pop before the
	TAP TO CONTINUE prompt; a tap carries on from 1.6 s whatever the style), Cracks(S)?, Setup(S)?, Egg(S, t, u, dt), Tick(S, t, dt)?, Cam(S, t) -> (CFrame, fov)?,
	OnBurst(S, at)?, Spawn(S, rest, R) -> CFrame?, Reveal(S, baby, anim, R)?, Soft?, NoPillar? }
	S is the scene Hatch hands over (the egg, the nest frame, sizes, the UI, flags); R is the newborn (Root, Rest,
	Head, Size, Chirp). A reveal runs in its own thread and must stop the moment S.Alive goes false (you tapped on).
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Kit = require(script.Parent.UI.Kit)
local Audio = require(script.Parent.Audio)

local HatchStyles = {}

local WHITE = Color3.new(1, 1, 1)
local TAU = math.pi * 2

-- helpers ---------------------------------------------------------------------------------------------------------

local function block(size: Vector3, color: Color3, cf: CFrame, parent: Instance, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end
HatchStyles.Block = block

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0 → 1 between a and b (smoothed)
local function ramp(t: number, a: number, b: number): number
	return smooth((t - a) / math.max(0.001, b - a))
end

-- a soft hump: 0 at a, 1 in the middle, 0 at b
local function bump(t: number, a: number, b: number): number
	if t <= a or t >= b then return 0 end
	return math.sin((t - a) / (b - a) * math.pi)
end

local function fadeAway(inst: Instance, dur: number)
	local parts = {}
	if inst:IsA("BasePart") then table.insert(parts, inst) end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end
	for _, p in ipairs(parts) do
		TweenService:Create(p, TweenInfo.new(dur), { Transparency = 1 }):Play()
	end
	Debris:AddItem(inst, dur + 0.05)
end

-- throw something (a part or a model) under gravity: it tumbles, lands on floorY, bounces once, rests, fades.
-- (anchored and moved by hand: no physics, nothing to collide with in the hatchery)
local function toss(obj: PVInstance, vel: Vector3, floorY: number, life: number, opts: any?)
	opts = opts or {}
	task.spawn(function()
		local t0 = os.clock()
		local v = vel
		local spin = opts.Spin or Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14
		local bounced = false
		local lift = opts.Lift or 0 -- pivot height above its lowest point
		while obj.Parent and os.clock() - t0 < life do
			local dt = RunService.Heartbeat:Wait()
			v += Vector3.new(0, -64 * dt, 0)
			local cf = obj:GetPivot()
			local pos = cf.Position + v * dt
			if pos.Y - lift < floorY and v.Y < 0 then
				pos = Vector3.new(pos.X, floorY + lift, pos.Z)
				if not bounced and v.Y < -5 then
					bounced = true
					v = Vector3.new(v.X * 0.45, -v.Y * 0.32, v.Z * 0.45)
					spin *= 0.35
					if opts.OnLand then task.spawn(opts.OnLand) end
				else
					v = Vector3.zero
					spin = Vector3.zero
				end
			end
			obj:PivotTo(CFrame.new(pos) * cf.Rotation * CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt))
		end
		if obj.Parent then fadeAway(obj, 0.3) end
	end)
end
HatchStyles.Toss = toss

-- a floating sleepy "Z" (a little pixel letter on a billboard that drifts up and fades)
local function zzz(parent: Instance, pos: Vector3, scale: number, drift: Vector3)
	local host = block(Vector3.new(0.2, 0.2, 0.2), WHITE, CFrame.new(pos), parent)
	host.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(scale, scale)
	bb.LightInfluence = 0
	bb.Adornee = host
	bb.Parent = host
	local z = Kit.Text(bb, math.random() < 0.5 and "Z" or "z", { Pixel = true, Color = Color3.fromRGB(205, 228, 255), Stroke = 2, Shadow = 0, MaxSize = 100 })
	z.Rotation = (math.random() - 0.5) * 30
	TweenService:Create(host, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = pos + drift }):Play()
	TweenService:Create(bb, TweenInfo.new(1.1), { Size = UDim2.fromScale(scale * 1.7, scale * 1.7) }):Play()
	task.delay(0.55, function()
		for _, d in ipairs(z:GetDescendants()) do
			if d:IsA("TextLabel") then TweenService:Create(d, TweenInfo.new(0.5), { TextTransparency = 1 }):Play() end
			if d:IsA("UIStroke") then TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play() end
		end
	end)
	Debris:AddItem(host, 1.15)
end

-- how far a part reaches along a direction from its centre
local function extent(p: BasePart, d: Vector3): number
	local cf = p.CFrame
	local s = p.Size
	return math.abs(cf.RightVector:Dot(d)) * s.X / 2 + math.abs(cf.UpVector:Dot(d)) * s.Y / 2 + math.abs(cf.LookVector:Dot(d)) * s.Z / 2
end

-- a spot on the egg's OUTSIDE for a crack (the end face of one of its shell slabs - always the outermost bit), in
-- its current pose, looking outward. (The old cracks sat on a fixed 0.72-stud circle round the nest: on a big egg
-- they were buried inside the shell, and on a lifted egg they floated under it.) S.Avoid keeps them off one side
function HatchStyles.CrackSpot(S): CFrame?
	local shell = S.Shell
	if #shell == 0 then return nil end
	local pv = S.Egg:GetPivot()
	for _ = 1, 12 do
		local p = shell[math.random(1, #shell)]
		local h = (pv:PointToObjectSpace(p.Position).Y - S.BottomL) / S.EggH
		if h > 0.14 and h < 0.86 then
			local sz = p.Size
			local alongX = sz.X >= sz.Z
			local side = math.random() < 0.5 and -1 or 1
			local n = p.CFrame:VectorToWorldSpace(alongX and Vector3.new(side, 0, 0) or Vector3.new(0, 0, side))
			if not (S.Avoid and n:Dot(S.Avoid) > 0.35) then
				local across = (math.random() - 0.5) * (alongX and sz.Z or sz.X) * 0.55
				local lp = alongX and Vector3.new(side * sz.X / 2, 0, across) or Vector3.new(across, 0, side * sz.Z / 2)
				local w = p.CFrame:PointToWorldSpace(lp)
				return CFrame.lookAt(w, w + n)
			end
		end
	end
	return nil
end

-- the top of its skull (the Head joint is a tiny invisible bone; the skull is welded to it): the "Cranium" block
-- when it has one, else the biggest visible block on the head
local function crownOf(baby: Model, bone: BasePart?): BasePart?
	if not bone then return nil end
	local best, vol = nil, 0
	for _, d in ipairs(baby:GetDescendants()) do
		if (d:IsA("Weld") or d:IsA("WeldConstraint")) then
			local a, b = (d :: any).Part0, (d :: any).Part1
			local other = (a == bone and b) or (b == bone and a) or nil
			if other and other:IsA("BasePart") and other.Transparency < 0.9 then
				if other.Name == "Cranium" then return other end
				local v = other.Size.X * other.Size.Y * other.Size.Z
				if v > vol then best, vol = other, v end
			end
		end
	end
	return best
end
HatchStyles.CrownOf = crownOf

local function alive(S, baby: Model): boolean
	return S.Alive and baby.Parent ~= nil
end

-- wait while the reveal is still on (false: you tapped on or it's gone)
local function hold(S, baby: Model, secs: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < secs do
		RunService.RenderStepped:Wait()
		if not alive(S, baby) then return false end
	end
	return true
end

local function neckChain(anim, pitch: number, yaw: number)
	local neck = (anim.Profile.Gait and anim.Profile.Gait.Neck) or {}
	local n = math.max(1, #neck)
	for _, j in ipairs(neck) do anim:Add(j, pitch / n, yaw / n, 0) end
end

local function gaitScale(anim): number
	return (anim.Profile.Gait and anim.Profile.Gait.Scale) or 1
end

-- the classic first moment: a little roar (or a look round) and a chirp
local function classicReveal(S, baby: Model, anim, R)
	if not hold(S, baby, 0.15) then return end
	if anim then anim:Play(anim:HasAction("Roar") and "Roar" or "LookAround") end
	if not hold(S, baby, 0.2) then return end
	Audio.Play("BabyChirp", { Pitch = R.Chirp })
end

local Styles = {}

-- WOBBLE ----------------------------------------------------------------------------------------------------------
Styles.Wobble = {
	Name = "Wobble",
	Shoulder = 0.9,
	Hold = 1.6,
	Build = function(tier) return tier.Build end,
	Setup = function(S)
		local tier = S.Tier
		-- (the big tiers keep their own staging: pillar, blackout, implode)
		S.Sub = (tier.Pillar or tier.Blackout or tier.Implode) and "Rock" or (math.random() < 0.5 and "Rock" or "Hop")
		S.LastLand = 0
	end,
	Egg = function(S, t, u, dt)
		local tier, base, build = S.Tier, S.Base, S.Build
		local amp = u ^ 1.6
		local rock = math.sin(t * (6 + t * 5)) * (0.05 + amp * 0.28)
		local jitter = amp > 0.5 and (math.random() - 0.5) * amp * 0.12 or 0
		local lift = tier.Lift * math.clamp((t - build * 0.35) / (build * 0.5), 0, 1)
		local spin = tier.Lift > 0 and (t * t * 0.6) or 0
		if S.Sub == "Hop" then
			-- bouncing in the nest, higher and faster, a puff of nest dust on every landing
			local rate = 1.1 + u * 3.4
			local wave = math.sin(t * math.pi * rate)
			local hop = (0.12 + amp * 1.2) * math.abs(wave)
			local tilt = math.sin(t * math.pi * rate * 2) * 0.14 * amp
			S.Egg:PivotTo(base * CFrame.new(0, lift + hop, 0) * CFrame.Angles(tilt, t * 0.7, -tilt * 0.6))
			if math.abs(wave) < 0.12 and t - S.LastLand > 0.18 and t > 0.3 then
				S.LastLand = t
				DinosaurVFX.FootstepDust(base.Position, 0.4 + amp * 0.6)
				DinosaurVFX.Shake(0.08 + amp * 0.2, 0.08)
			end
		else
			S.Egg:PivotTo(base * CFrame.new(jitter, lift + math.max(0, math.sin(t * 9)) * amp * 0.25, 0) * CFrame.Angles(rock * 0.4, spin, rock))
		end
		-- the Secret implode: the shell blackens into an orb before it goes
		if tier.Implode and t >= tier.Implode - 0.6 and not S.Imploded then
			for _, d in ipairs(S.Shell) do d.Color = d.Color:Lerp(Color3.new(0, 0, 0), math.min(1, dt * 6)) end
			if t >= tier.Implode then S.Imploded = true end
		end
	end,
	Cam = function(S, t)
		local tier, build, K = S.Tier, S.Build, S.K
		local center = S.Center
		local shoulder = 0.9
		if t < build * 0.6 and S.Sub == "Hop" then
			-- down at the nest rim looking up at it bouncing
			local v = (t - shoulder) / math.max(0.1, build * 0.6 - shoulder)
			local pos = S.At((3.4 - v * 0.8) * K, 0.5, (-2.4 + v * 0.6) * K)
			return CFrame.lookAt(pos, center + Vector3.new(0, 0.5, 0)), 50 - v * 6
		elseif t < build * 0.6 then
			local v = (t - shoulder) / math.max(0.1, build * 0.6 - shoulder)
			local pos = S.At((4.2 - v * 1.2) * K, S.MidY + 0.3 + v * 0.4 + tier.Lift * 0.5 * v, (-2.6 + v * 0.9) * K)
			return CFrame.lookAt(pos, center + Vector3.new(0, tier.Lift * 0.4 * v, 0)), 46 - v * 6
		end
		local v = (t - build * 0.6) / (build * 0.4)
		local pos = S.At((2.2 + math.sin(v * 2) * 0.6) * K, S.MidY + 3.4 + tier.Lift - v * 0.6, 2.2 * K)
		return CFrame.lookAt(pos, center + Vector3.new(0, tier.Lift, 0)) * CFrame.Angles(0, 0, math.sin(t * 30) * 0.02 * v), 52 - v * 8
	end,
	Reveal = classicReveal,
}

-- PEEK ------------------------------------------------------------------------------------------------------------
-- (the eyes live in the egg's own frame: HoleL is the hole's spot on the shell, looking out of it)
local function peekPlace(S)
	local pv = S.Egg:GetPivot() * S.HoleL
	local s = S.EggScale
	local open = S.EyeOpen
	local look = S.EyeLook
	local wide = S.EyeWide
	local ey = 0.17 * s * math.max(0.06, open)
	for i, e in ipairs(S.Eyes) do
		local x = (i == 1 and -0.11 or 0.11) * s
		local es = 0.17 * s * wide
		e.Size = Vector3.new(es, ey * wide, 0.05 * s)
		e.CFrame = pv * CFrame.new(x, 0.02 * s, -0.055 * s)
		local pu = S.Pupils[i]
		local ps = 0.085 * s / math.max(1, wide * 0.85)
		pu.Size = Vector3.new(ps, math.min(ps, ey * wide * 0.9), 0.03 * s)
		pu.Transparency = open < 0.35 and 1 or 0
		pu.CFrame = pv * CFrame.new(x + look * 0.04 * s, 0.01 * s, -0.085 * s)
	end
	S.Patch.CFrame = pv * CFrame.new(0, 0, -0.02 * s)
end

Styles.Peek = {
	Name = "Peek",
	Shoulder = 0.5,
	Hold = 1.6,
	Build = function(tier) return tier.Build end,
	Cracks = function(S)
		-- all the cracks come before the chip falls out (squeezed into the time before it)
		local out = {}
		local span = math.max(0.2, S.PopAt - 0.12)
		for _, c in ipairs(S.Tier.Cracks) do table.insert(out, 0.12 + (c / S.Tier.Build) * (span - 0.12)) end
		return out
	end,
	Setup = function(S)
		S.PopAt = math.max(0.5, S.Build - 0.95)
		-- the hole faces the side the reveal camera looks from
		local d = S.Base.RightVector
		S.Avoid = d
		local pv = S.Egg:GetPivot()
		local best, bestExt = nil, -1
		for _, p in ipairs(S.Shell) do
			local h = (pv:PointToObjectSpace(p.Position).Y - S.BottomL) / S.EggH
			if h > 0.3 and h < 0.72 then
				local e = extent(p, d)
				if e > bestExt then best, bestExt = p, e end
			end
		end
		local holeW
		if best then
			-- straight out from the egg's middle line at that layer's height
			local axis = pv:PointToWorldSpace(Vector3.new(0, pv:PointToObjectSpace(best.Position).Y, 0))
			local reach = extent(best, d) + (best.Position - axis):Dot(d)
			holeW = axis + d * reach
			S.ShellColor = best.Color
		else
			holeW = S.Center + d * (S.EggW * 0.5)
			S.ShellColor = Color3.fromRGB(243, 234, 210)
		end
		S.HoleL = pv:ToObjectSpace(CFrame.lookAt(holeW, holeW + d))
		S.HoleRest = holeW
		S.EyeOpen, S.EyeLook, S.EyeWide = 0, 0, 1
		S.Eyes, S.Pupils = {}, {}
		S.Done = {}
	end,
	Egg = function(S, t, _u, _dt)
		local base, s, pop = S.Base, S.EggScale, S.PopAt
		if t < pop then
			local amp = math.clamp(t / pop, 0, 1) ^ 1.5
			local rock = math.sin(t * (7 + t * 6)) * (0.04 + amp * 0.16)
			S.Egg:PivotTo(base * CFrame.Angles(rock * 0.5, 0, rock))
		elseif t < pop + 0.14 then
			-- the jolt as the chip falls out
			local k = 1 - (t - pop) / 0.14
			S.Egg:PivotTo(base * CFrame.new(0, 0.1 * s * k, 0) * CFrame.Angles(0, 0, -0.1 * k))
		elseif t < pop + 0.8 then
			-- still: something in there is looking around
			S.Egg:PivotTo(base * CFrame.Angles(0, 0, math.sin(t * 5) * 0.012))
		else
			-- it's coming: a hard shiver
			local j = 0.06 * s
			S.Egg:PivotTo(base * CFrame.new((math.random() - 0.5) * j, 0, (math.random() - 0.5) * j) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.14))
		end
	end,
	Tick = function(S, t, dt)
		local pop, s = S.PopAt, S.EggScale
		local done = S.Done
		if not done.Knock and t >= pop - 0.22 then
			done.Knock = true
			S.Knock()
		end
		if not done.Pop and t >= pop then
			done.Pop = true
			-- the chip pops out and drops into the nest; behind it, the dark
			Audio.Play("EggCrack", { Pitch = 1.12, Exact = true })
			DinosaurVFX.Shake(0.25, 0.15)
			local hole = S.Egg:GetPivot() * S.HoleL
			local chip = block(Vector3.new(0.5 * s, 0.38 * s, 0.16 * s), S.ShellColor, hole * CFrame.new(0, 0, -0.06 * s), S.Folder, Enum.Material.SmoothPlastic)
			local out = hole.LookVector
			toss(chip, out * (5 + s) + Vector3.new(0, 7, 0) + S.Base.LookVector * (math.random() - 0.5) * 2, S.FloorY, 4, {
				Lift = 0.08 * s,
				OnLand = function() Audio.Play("EggPlace", { Pitch = 1.35, Volume = 0.8 }) end,
			})
			DinosaurVFX.Burst(CFrame.new(hole.Position), 6, { Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(1, 3), Color = Color3.fromRGB(240, 228, 200), Size = NumberSequence.new(0.25 * s, 0.7 * s) })
			S.Patch = block(Vector3.new(0.46 * s, 0.34 * s, 0.05 * s), Color3.fromRGB(18, 14, 22), hole, S.Folder, Enum.Material.SmoothPlastic)
			for i = 1, 2 do
				S.Eyes[i] = block(Vector3.new(0.17 * s, 0.01, 0.05 * s), WHITE, hole, S.Folder, Enum.Material.SmoothPlastic)
				S.Pupils[i] = block(Vector3.new(0.08 * s, 0.08 * s, 0.03 * s), Color3.fromRGB(16, 16, 20), hole, S.Folder, Enum.Material.SmoothPlastic)
			end
		end
		if not done.Pop then return end
		local e = t - pop
		if not done.Chirp and e >= 0.14 then
			done.Chirp = true
			Audio.Play("BabyChirp", { Pitch = 1.55, Volume = 0.8 })
		end
		if not done.Wave and e >= 0.58 then
			done.Wave = true
			S.Act("Wave") -- (it looked right at you: you wave hello)
		end
		if not done.Eep and e >= 0.8 then
			done.Eep = true
			Audio.Play("BabyChirp", { Pitch = 1.75, Volume = 0.9 })
			DinosaurVFX.Shake(0.3, 0.2)
		end
		-- the eyes: open, dart left, right, back to you, a blink, then wide ("here I come!")
		local blink = bump(e, 0.64, 0.74)
		S.EyeOpen = ramp(e, 0.08, 0.2) * (1 - blink)
		local want = (e < 0.28 and 0) or (e < 0.42 and -1) or (e < 0.56 and 1) or 0
		S.EyeLook += (want - S.EyeLook) * math.min(1, dt * 28)
		S.EyeWide = 1 + 0.3 * ramp(e, 0.8, 0.88)
		-- (a rare one: the eyes glow its colour once the cracks have turned)
		if S.Teased and not done.Glow then
			done.Glow = true
			for _, eye in ipairs(S.Eyes) do
				eye.Material = Enum.Material.Neon
				eye.Color = S.Rc:Lerp(WHITE, 0.35)
			end
			local l = Instance.new("PointLight")
			l.Color = S.Rc
			l.Range = 4 * s
			l.Brightness = 2
			l.Parent = S.Patch
		end
		peekPlace(S)
	end,
	Cam = function(S, t)
		local pop, K = S.PopAt, S.K
		if t < pop - 0.05 then
			-- easing round to the side it'll peek out of
			local v = (t - 0.5) / math.max(0.1, pop - 0.55)
			local pos = S.At((3.2 - v * 0.6) * K, S.MidY + 0.4 - v * 0.2, (-2.2 + v * 1.6) * K)
			return CFrame.lookAt(pos, S.Center), 46 - v * 4
		end
		-- straight on the hole, close, a slow push (and a little zoom when the eyes go wide)
		local d = S.Base.RightVector
		local v = math.clamp((t - pop) / 0.95, 0, 1)
		local dist = (1.7 - v * 0.3) * K
		local pos = S.HoleRest + d * dist + S.Base.LookVector * 0.22 * K + Vector3.new(0, 0.12 * K, 0)
		return CFrame.lookAt(pos, S.HoleRest), 40 - 6 * ramp(t - pop, 0.8, 0.9)
	end,
	OnBurst = function(S, at)
		-- the two halves of the shell fly apart
		local s = S.EggScale
		local side = S.Base.LookVector
		for i = -1, 1, 2 do
			local half = block(Vector3.new(0.85 * s, 1.1 * s, 0.22 * s), S.ShellColor, CFrame.new(at + side * i * 0.4 * s) * CFrame.Angles(0, math.atan2(side.X, side.Z), i * 0.4), S.Folder, Enum.Material.SmoothPlastic)
			toss(half, side * i * (9 + s * 2) + Vector3.new(0, 11, 0), S.FloorY, 1.6, { Lift = 0.2 * s })
		end
		for _, p in ipairs(S.Eyes) do p:Destroy() end
		for _, p in ipairs(S.Pupils) do p:Destroy() end
		if S.Patch then S.Patch:Destroy() end
	end,
	Reveal = function(S, baby, anim, R)
		if not anim then classicReveal(S, baby, anim, R) return end
		-- curious: it sniffs at the lens and tilts its head one way, then the other (who are YOU?), then two happy hops
		local t0 = os.clock()
		local gs = gaitScale(anim)
		local function layer(a, _dt)
			local t = os.clock() - t0
			local tilt = 0.38 * ramp(t, 0.2, 0.42) - 0.7 * ramp(t, 0.6, 0.78) + 0.32 * ramp(t, 0.82, 0.96)
			a:Add("Head", 0, 0, tilt)
			neckChain(a, -0.08 * bump(t, 0.1, 0.95), 0)
			local hop = math.max(bump(t, 1.0, 1.2), bump(t, 1.22, 1.42))
			a:Add("Pelvis", 0, 0, 0, 0, hop * 0.4 * gs, 0)
		end
		anim.Layer = layer
		if hold(S, baby, 0.12) then
			anim:Play(anim:HasAction("Sniff") and "Sniff" or "LookAround")
			if hold(S, baby, 0.25) then
				Audio.Play("BabyChirp", { Pitch = R.Chirp + 0.15 })
				if hold(S, baby, 0.73) then
					Audio.Play("Stomp", { Volume = 0.6, Pitch = 1.2 })
					if hold(S, baby, 0.22) then
						Audio.Play("Stomp", { Volume = 0.6, Pitch = 1.3 })
						Audio.Play("BabyChirp", { Pitch = R.Chirp + 0.25 })
						hold(S, baby, 0.25)
					end
				end
			end
		end
		if anim.Layer == layer then anim.Layer = nil end
	end,
}

-- SPINPOP ---------------------------------------------------------------------------------------------------------
Styles.SpinPop = {
	Name = "SpinPop",
	Shoulder = 0.6,
	Hold = 1.6,
	Build = function(tier) return tier.Build end,
	Setup = function(S)
		local s = S.EggScale
		local h = (1.3 + S.Order * 0.35) * math.sqrt(s)
		-- (under the hatchery roof)
		if S.CeilY then h = math.min(h, S.CeilY - (S.Center.Y + S.EggH * 0.6) - 1.5) end
		S.LiftH = math.max(0.8, h)
		S.Spin = 0
		S.Orbit = {}
		local n = 6 + S.Order * 2
		local cols = { S.Rc, S.Rc:Lerp(WHITE, 0.5), WHITE }
		for i = 1, n do
			local c = block(Vector3.new(0.22, 0.22, 0.22) * math.sqrt(s), cols[(i % #cols) + 1], S.Egg:GetPivot(), S.Folder)
			c.Transparency = 1
			S.Orbit[i] = c
		end
		S.Done = {}
	end,
	Egg = function(S, t, u, dt)
		local base, build, s = S.Base, S.Build, S.EggScale
		local amp = u ^ 1.6
		-- spins up like a top... and in the last moment stops dead
		local brake = math.clamp((build - t) / 0.22, 0, 1)
		S.Spin += dt * (1.5 + u * u * 34) * brake
		local liftK = ramp(t, build * 0.3, build * 0.82)
		local lift = S.LiftH * liftK + math.sin(t * 3) * 0.06 * liftK
		local prec = (0.05 + amp * 0.26) * (1 - liftK * 0.6) * brake
		local swell = (1 - brake) * 0.08 * s
		S.Egg:PivotTo(base * CFrame.new(0, lift + swell, 0) * CFrame.Angles(math.sin(S.Spin * 0.35) * prec, S.Spin, math.cos(S.Spin * 0.35) * prec))
		-- a ring of cubes orbiting it, closing in and speeding up
		local mid = S.EggMid()
		local n = #S.Orbit
		local r = (S.EggW * 0.5 + 0.7 * math.sqrt(s)) * (1.35 - u * 0.45)
		local vis = ramp(t, build * 0.2, build * 0.4)
		for i, c in ipairs(S.Orbit) do
			local a = S.Spin * 0.45 + i / n * TAU
			local y = math.sin(a * 2 + t * 3) * 0.25 * S.EggH
			c.CFrame = CFrame.new(mid + base:VectorToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)) + Vector3.new(0, y, 0)) * CFrame.Angles(t * 3, a, t * 2)
			c.Transparency = 1 - vis * 0.9
		end
	end,
	Tick = function(S, t, _dt)
		local build, done = S.Build, S.Done
		if not done.Lift and t >= build * 0.3 then
			done.Lift = true
			Audio.Play("Dodge", { Pitch = 0.85 })
			DinosaurVFX.FootstepDust(S.Base.Position, 0.9 + S.EggScale * 0.3)
		end
		if not done.Charge and t >= build * 0.5 then
			done.Charge = true
			Audio.Play("ChargeReady", { Pitch = 0.9 + S.Order * 0.06, Volume = 1.4 })
		end
		if not done.Stop and t >= build - 0.22 then
			done.Stop = true
			DinosaurVFX.Shake(0.35, 0.2)
			S.Flash(0.2, S.Rc)
		end
	end,
	Cam = function(S, t)
		local build, K = S.Build, S.K
		local mid = S.EggMid()
		if t < build - 0.3 then
			-- low, looking up at it spinning and rising, circling round to the reveal side
			local v = (t - 0.6) / math.max(0.1, build - 0.9)
			local a = -1.0 + v * 0.85
			local r = (3.8 - v * 0.4) * K
			local pos = S.At(math.cos(a) * r, 0.45 + v * 0.5, math.sin(a) * r)
			return CFrame.lookAt(pos, mid), 52 - v * 6
		end
		-- whip to the reveal side for the pop
		local pos = S.At(5.4 * K, S.MidY + S.LiftH * 0.5, 0.4 * K)
		return CFrame.lookAt(pos, mid), 50
	end,
	OnBurst = function(S, at)
		-- the orbiting cubes fly off
		for _, c in ipairs(S.Orbit) do
			local out = c.Position - at
			out = Vector3.new(out.X, 0, out.Z)
			out = out.Magnitude > 0.01 and out.Unit or Vector3.new(1, 0, 0)
			toss(c, out * (14 + math.random() * 6) + Vector3.new(0, 8, 0), S.FloorY, 1)
		end
		S.Orbit = {}
	end,
	Spawn = function(S, rest, R)
		-- it appears up in the pop... (its head under the roof). (Where it popped, not S.EggMid(): the egg model is
		-- already destroyed by now, and its pivot no longer says where it was)
		local popY = (S.BurstAt or S.Center).Y
		local h = math.max(0, popY - S.Center.Y)
		if S.CeilY then h = math.min(h, S.CeilY - (rest.Position.Y - R.Lift + R.Size.Y) - 0.3) end
		S.DropH = math.max(0, h)
		S.AimLift = S.DropH * 0.85
		return rest + Vector3.new(0, S.DropH, 0)
	end,
	Reveal = function(S, baby, anim, R)
		-- ...hangs a beat, then twirls down into the nest and lands with a thump
		local root = R.Root
		local H = S.DropH or 0
		S.AimLift = H * 0.85
		if not hold(S, baby, 0.1) then root.CFrame = R.Rest S.AimLift = 0 return end
		local g = 72
		local fall = math.sqrt(2 * math.max(H, 0.01) / g)
		local t0 = os.clock()
		while true do
			RunService.RenderStepped:Wait()
			if not alive(S, baby) then root.CFrame = R.Rest S.AimLift = 0 return end
			local t = os.clock() - t0
			local k = math.clamp(t / math.max(fall, 0.05), 0, 1)
			local y = H * (1 - k * k)
			root.CFrame = (R.Rest + Vector3.new(0, y, 0)) * CFrame.Angles(0, (1 - smooth(k)) * TAU, 0)
			S.AimLift = y * 0.85
			if k >= 1 then break end
		end
		root.CFrame = R.Rest
		S.AimLift = 0
		local big = R.Size.Y > 4
		Audio.Play(big and "StompBig" or "Stomp", { Volume = big and 0.8 or 1 })
		DinosaurVFX.FootstepDust(R.Rest.Position - Vector3.new(0, R.Lift, 0), 0.9 + math.min(R.Size.Y, 8) * 0.18)
		DinosaurVFX.BlockRing(CFrame.new(R.Rest.Position - Vector3.new(0, R.Lift - 0.2, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 16, R0 = 0.6, R1 = 3 + R.Size.X * 0.4, Color = Color3.fromRGB(196, 170, 128), Transparency = 0.35, Duration = 0.45, Block = 0.35 })
		DinosaurVFX.Shake(0.35 + (big and 0.35 or 0), 0.25)
		if not anim then return end
		-- squash on landing
		local t1 = os.clock()
		local gs = gaitScale(anim)
		local function layer(a, _dt)
			local t = os.clock() - t1
			local sq = bump(t, 0, 0.32)
			a:Add("Pelvis", 0, 0, 0, 0, -0.3 * gs * sq, 0)
			neckChain(a, -0.25 * sq, 0)
		end
		anim.Layer = layer
		if hold(S, baby, 0.22) then
			anim:Play(anim:HasAction("Roar") and "Roar" or "LookAround")
			if hold(S, baby, 0.15) then Audio.Play("BabyChirp", { Pitch = R.Chirp }) end
			hold(S, baby, 0.2)
		end
		if anim.Layer == layer then anim.Layer = nil end
	end,
}

-- SLEEPY ----------------------------------------------------------------------------------------------------------
Styles.Sleepy = {
	Name = "Sleepy",
	Shoulder = 0.6,
	-- (shorter build: the gag is in the wake-up, and the whole thing still takes no longer than the classic)
	Build = function(tier) return math.max(1, tier.Build - 0.5) end,
	Hold = 2.05,
	Soft = true,
	Cracks = function(S) return { S.Build * 0.42, S.Build * 0.74 } end,
	Setup = function(S)
		-- the top of the shell becomes its hat
		local pv = S.Egg:GetPivot()
		S.LidParts = {}
		for _, p in ipairs(S.Shell) do
			if (pv:PointToObjectSpace(p.Position).Y - S.BottomL) / S.EggH > 0.66 then table.insert(S.LidParts, p) end
		end
		S.ShellCol = S.LidParts[1] and S.LidParts[1].Color or Color3.fromRGB(243, 234, 210)
		S.NextZ = 0.12
	end,
	Egg = function(S, t, _u, _dt)
		local base, s = S.Base, S.EggScale
		-- dozing: a slow cradle rock; each crack jolts it for a moment, then it nods off again
		local jolt = 0
		for _, ct in ipairs(S.CrackTimes) do
			local d = t - ct
			if d > 0 and d < 0.3 then jolt = math.max(jolt, 1 - d / 0.3) end
		end
		local rock = math.sin(t * 2.4) * 0.07
		local shiver = t > S.Build - 0.18 and (math.random() - 0.5) * 0.08 * s or 0
		S.Egg:PivotTo(base * CFrame.new(shiver, jolt * jolt * 0.18 * s, 0) * CFrame.Angles(0, 0, rock + jolt * math.sin(t * 40) * 0.06))
	end,
	Tick = function(S, t, _dt)
		-- Zzz (not right after a crack: it's stirring)
		local stirring = false
		for _, ct in ipairs(S.CrackTimes) do
			if t > ct and t < ct + 0.2 then stirring = true end
		end
		if t >= S.NextZ and t < S.Build - 0.2 and not stirring then
			S.NextZ = t + 0.25
			local top = S.EggMid() + Vector3.new(0, S.EggH * 0.55, 0)
			zzz(S.Folder, top + S.Base.LookVector * 0.2, 0.7 + S.EggScale * 0.25, Vector3.new(0, 1.6, 0) + S.Base.LookVector * 0.5 + S.Base.RightVector * 0.3)
		end
	end,
	Cam = function(S, t)
		local K = S.K
		-- a gentle push-in at the egg's height
		local v = (t - 0.6) / math.max(0.1, S.Build - 0.6)
		local pos = S.At((3.7 - v * 0.7) * K, S.MidY + 0.3, (1.6 - v * 0.6) * K)
		return CFrame.lookAt(pos, S.Center + Vector3.new(0, 0.3 * S.EggScale, 0)), 44 - v * 4
	end,
	OnBurst = function(S, _at)
		-- (a soft pop - it's still asleep) the lid lifts off in one piece
		if #S.LidParts == 0 then return end
		local lid = Instance.new("Model")
		lid.Name = "HatchLid"
		local minY = math.huge
		for _, p in ipairs(S.LidParts) do
			local c = p:Clone()
			c.Anchored = true
			c.CanCollide = false
			c.Parent = lid
			minY = math.min(minY, c.Position.Y - c.Size.Y / 2)
		end
		local pv = S.Egg:GetPivot()
		lid.WorldPivot = CFrame.new(pv.Position.X, minY, pv.Position.Z) * pv.Rotation
		lid.Parent = S.Folder
		S.Lid = lid
		DinosaurVFX.FootstepDust(S.Base.Position, 0.7)
	end,
	Reveal = function(S, baby, anim, R)
		local lid = S.Lid :: Model?
		local head = crownOf(baby, R.Head)
		if not anim then
			if lid then toss(lid, S.Base.LookVector * 5 + Vector3.new(0, 7, 0), S.FloorY, 1.4) end
			classicReveal(S, baby, anim, R)
			return
		end
		local gs = gaitScale(anim)
		local t0 = os.clock()
		local hatOn = false
		local from = lid and lid:GetPivot()
		local fit = 1
		if lid and head then
			local _, ls = lid:GetBoundingBox()
			local lw = math.max(ls.X, ls.Z)
			fit = math.clamp(math.max(head.Size.X, head.Size.Z) * 1.15 / math.max(lw, 0.01), 0.15, 1)
		end
		local function hatSpot(): CFrame
			local h = head :: BasePart
			return h.CFrame * CFrame.new(0, h.Size.Y * 0.5 - 0.02, 0) * CFrame.Angles(0, 0, 0.22)
		end
		-- asleep (w), the yawn (y), the head-shake (k)
		local function layer(a, _dt)
			local t = os.clock() - t0
			local w = 1 - ramp(t, 0.85, 1.3)
			local y = bump(t, 0.72, 1.36)
			local k = bump(t, 1.36, 1.72)
			neckChain(a, -0.34 * w + 0.32 * y, 0)
			a:Add("Head", -0.24 * w + 0.3 * y, math.sin(t * 34) * 0.12 * k, math.sin(t * 42) * 0.34 * k)
			a:Add("Jaw", -0.85 * y, 0, 0)
			a:Add("Pelvis", 0, 0, 0, 0, -0.12 * gs * w, 0)
			local tail = (a.Profile.Gait and a.Profile.Gait.Tail) or {}
			for _, j in ipairs(tail) do a:Add(j, 0, 0.15 * w, 0) end
		end
		anim.Layer = layer
		anim.EyesClosed = true
		local nextZ, chirp, woke, flung, look = 0.1, false, false, false, false
		while true do
			RunService.RenderStepped:Wait()
			if not alive(S, baby) then break end
			local t = os.clock() - t0
			-- the lid floats up off the shell and settles on its head
			if lid and lid.Parent and head and not flung then
				if t < 0.45 and from then
					local k = smooth(t / 0.45)
					local goal = hatSpot()
					local p = from.Position:Lerp(goal.Position, k) + Vector3.new(0, math.sin(k * math.pi) * 1.4, 0)
					lid:ScaleTo(1 + (fit - 1) * k)
					lid:PivotTo(CFrame.new(p) * from.Rotation:Lerp(goal.Rotation, k) * CFrame.Angles(0, k * math.pi, 0))
				else
					if not hatOn then
						hatOn = true
						lid:ScaleTo(fit)
						Audio.Play("EggPlace", { Pitch = 1.45 })
					end
					lid:PivotTo(hatSpot() * CFrame.Angles(0, math.pi, 0))
				end
			elseif lid and lid.Parent and not head and not flung then
				-- (no head joint to sit on: it just tumbles off)
				flung = true
				toss(lid, S.Base.LookVector * 5 + Vector3.new(0, 7, 0), S.FloorY, 1.4)
			end
			if t >= nextZ and t < 0.75 and head then
				nextZ = t + 0.3
				zzz(S.Folder, head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.6, 0), 0.6 + R.Size.Y * 0.06, Vector3.new(0, 1.4, 0) + S.Base.LookVector * 0.4)
			end
			if not chirp and t >= 0.8 then
				chirp = true
				Audio.Play("BabyChirp", { Pitch = math.max(0.7, R.Chirp - 0.45), Volume = 0.9 }) -- (a yawny squeak)
			end
			if not woke and t >= 1.3 then
				woke = true
				anim.EyesClosed = false
				Audio.Play("Pet", { Pitch = 1.1 })
			end
			if not flung and t >= 1.48 then
				flung = true
				if lid and lid.Parent then
					-- shaken off: the hat goes flying, crumbs everywhere
					local side = S.Base.LookVector * (math.random() < 0.5 and -1 or 1)
					toss(lid, side * 8 + Vector3.new(0, 10, 0), S.FloorY, 1.3, { Spin = Vector3.new(0, 8, 14), OnLand = function() Audio.Play("EggPlace", { Pitch = 1.2 }) end })
					Audio.Play("Dodge", { Pitch = 1.3, Volume = 0.6 })
				end
				if head then DinosaurVFX.Cubes(head.Position + Vector3.new(0, head.Size.Y * 0.5, 0), 8, { S.ShellCol, Color3.fromRGB(243, 234, 210) }, 0.14 + R.Size.Y * 0.02, 7, 0.7) end
			end
			if not look and t >= 1.58 then
				look = true
				Audio.Play("BabyChirp", { Pitch = R.Chirp + 0.1 })
			end
			if t >= 1.75 then
				anim:Play(anim:HasAction("LookAround") and "LookAround" or "Roar")
				break
			end
		end
		if anim.Layer == layer then anim.Layer = nil end
		anim.EyesClosed = false
		-- (tapped on with the hat still on: it falls off)
		if lid and lid.Parent and not flung then toss(lid, S.Base.LookVector * 5 + Vector3.new(0, 6, 0), S.FloorY, 1.2) end
	end,
}

-- ERUPTION --------------------------------------------------------------------------------------------------------
local function eruptColor(S, t: number, i: number): Color3
	if S.Rarity == "Secret" then return Color3.fromHSV((t * 0.6 + i * 0.09) % 1, 0.75, 1) end
	return S.Rc
end

Styles.Eruption = {
	Name = "Eruption",
	Shoulder = 0.9,
	Hold = 1.8,
	NoPillar = true,
	Build = function(tier) return tier.Build end,
	Setup = function(S)
		local K, build, base = S.K, S.Build, S.Base
		S.Fissures = {}
		local n = 7 + S.Order
		for i = 1, n do
			local a = i / n * TAU + (math.random() - 0.5) * 0.35
			local dir = base:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
			local r0 = S.EggW * 0.55 + 0.4
			local start = base.Position + dir * r0
			local t0 = 0.75 + math.random() * build * 0.32
			-- two jagged segments each: out, then a kink
			local segs = {}
			local p = start
			local d = dir
			for k = 1, 2 do
				local len = (1.6 + math.random() * 1.8) * K
				local mid = p + d * (len * 0.5)
				local fy = S.FloorAt(mid) or (S.FloorY or base.Position.Y)
				local part = block(Vector3.new(0.24, 0.06, 0.01), S.Rc, CFrame.lookAt(Vector3.new(p.X, fy + 0.04, p.Z), Vector3.new(p.X + d.X, fy + 0.04, p.Z + d.Z)), S.Folder)
				part.Transparency = 1
				table.insert(segs, { Part = part, From = Vector3.new(p.X, fy + 0.04, p.Z), Dir = d, Len = len, T0 = t0 + (k - 1) * 0.35 })
				p = p + d * len
				d = CFrame.fromAxisAngle(Vector3.yAxis, (math.random() < 0.5 and -1 or 1) * (0.35 + math.random() * 0.3)):VectorToWorldSpace(d)
			end
			S.Fissures[i] = segs
		end
		S.BeamAt = build * 0.6
		S.Collapse = build - 0.38
		S.Done = {}
		S.Cracked = 0
		S.NextRing = 0
	end,
	Egg = function(S, t, u, _dt)
		local base, s, build = S.Base, S.EggScale, S.Build
		local amp = u ^ 1.6
		-- it hovers up off the nest as the power builds, trembling
		local hover = 0.45 * s * ramp(t, build * 0.3, build * 0.6)
		local sh = amp * 0.08 * s * (t > S.Collapse and 2 or 1)
		S.Egg:PivotTo(base * CFrame.new((math.random() - 0.5) * sh, hover + math.sin(t * 6) * 0.04, (math.random() - 0.5) * sh) * CFrame.Angles(math.sin(t * 13) * amp * 0.06, t * u * 1.4, math.cos(t * 11) * amp * 0.06))
	end,
	Tick = function(S, t, _dt)
		local done, s = S.Done, S.EggScale
		-- the fissures race out across the floor
		local any = false
		for i, segs in ipairs(S.Fissures) do
			for _, f in ipairs(segs) do
				local k = math.clamp((t - f.T0) / 0.45, 0, 1)
				if k > 0 then
					any = true
					local len = f.Len * smooth(k)
					f.Part.Size = Vector3.new(0.24 + 0.1 * s * (1 - k * 0.3), 0.06, math.max(0.01, len))
					f.Part.CFrame = CFrame.lookAt(f.From, f.From + f.Dir) * CFrame.new(0, 0, -len / 2)
					local flick = 0.15 + math.sin(t * 22 + i) * 0.1
					f.Part.Transparency = t > S.Collapse and math.max(0, 0.1 - (t - S.Collapse)) or flick
					f.Part.Color = t > S.Collapse and WHITE or eruptColor(S, t, i)
				end
			end
		end
		if any and not done.Rumble then
			done.Rumble = true
			Audio.Play("Earthshaker", { Volume = 0.55, Pitch = 0.85 })
			DinosaurVFX.Shake(0.35, 0.4)
		end
		-- a geyser of light at a fissure's end on every crack
		if S.CrackDone > S.Cracked then
			S.Cracked = S.CrackDone
			local segs = S.Fissures[math.random(1, #S.Fissures)]
			local f = segs[#segs]
			if f.Part.Transparency < 1 and S.Cracked >= 2 then
				local tip = f.Part.CFrame * CFrame.new(0, 0, -f.Part.Size.Z / 2)
				local col = eruptColor(S, t, S.Cracked)
				local g = block(Vector3.new(0.5, 0.4, 0.5) * S.K, col, CFrame.new(tip.Position), S.Folder)
				g.Transparency = 0.15
				TweenService:Create(g, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = Vector3.new(0.25, 6, 0.25) * S.K, CFrame = CFrame.new(tip.Position + Vector3.new(0, 3 * S.K, 0)), Transparency = 1 }):Play()
				Debris:AddItem(g, 0.5)
				DinosaurVFX.Cubes(tip.Position, 7, { col, WHITE }, 0.22, 16, 0.7)
			end
		end
		-- the beam blasts up out of the egg
		if not done.Beam and t >= S.BeamAt then
			done.Beam = true
			local top = S.EggMid() + Vector3.new(0, S.EggH * 0.4, 0)
			local h = S.CeilY and math.max(4, S.CeilY - top.Y) or 70
			S.BeamH = h
			S.BeamFrom = top
			local beam = block(Vector3.new(h, 0.3, 0.3), eruptColor(S, t, 0), CFrame.new(top + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), S.Folder)
			beam.Shape = Enum.PartType.Cylinder
			beam.Transparency = 0.2
			S.Beam = beam
			Audio.Play("Flare", { Pitch = 0.8, Volume = 1.3 })
			DinosaurVFX.Shake(0.7, 0.35)
			S.Flash(0.35, S.Rc)
			if S.CeilY then
				-- it hits the roof: a splash of light up there
				local roof = top + Vector3.new(0, h - 0.2, 0)
				DinosaurVFX.BlockRing(CFrame.new(roof) * CFrame.Angles(-math.pi / 2, 0, 0), { Count = 18, R0 = 0.6, R1 = 7, Color = S.Rc, Duration = 0.6, Block = 0.6 })
				DinosaurVFX.Burst(CFrame.new(roof), 16, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(4, 9), Spread = Vector2.new(180, 180), Color = S.Rc, LightEmission = 1, Size = NumberSequence.new(0.5, 0), Direction = Enum.NormalId.Bottom })
			end
		end
		if S.Beam then
			local w
			if t < S.Collapse then
				w = (0.3 + 1.5 * s * ramp(t, S.BeamAt, S.BeamAt + 0.25)) * (1 + math.sin(t * 26) * 0.08)
			else
				-- sucked back into the egg
				w = 1.8 * s * (1 - ramp(t, S.Collapse, S.Collapse + 0.3)) + 0.02
			end
			S.Beam.Size = Vector3.new(S.BeamH, w, w)
			S.Beam.Color = eruptColor(S, t, 0)
			-- rings of power climbing it
			if t >= S.NextRing and t < S.Collapse then
				S.NextRing = t + 0.28
				DinosaurVFX.BlockRing(CFrame.new(S.BeamFrom) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 12, R0 = 0.5 * s, R1 = 1.6 * s, Travel = math.min(S.BeamH, 24), Color = WHITE, Transparency = 0.3, Duration = 0.7, Block = 0.35 })
			end
		end
		if not done.Suck and t >= S.Collapse then
			done.Suck = true
			Audio.Play("Warp", { Pitch = 0.75, Volume = 1.2 })
		end
	end,
	Cam = function(S, t)
		local K, center = S.K, S.Center
		if t < S.BeamAt then
			-- wide and low: the floor splitting all round the nest
			local v = (t - 0.9) / math.max(0.1, S.BeamAt - 0.9)
			local a = -1.25 + v * 0.8
			local r = (7.6 - v * 1.4) * K
			local pos = S.At(math.cos(a) * r, 1.1 + v * 0.7, math.sin(a) * r)
			return CFrame.lookAt(pos, center + Vector3.new(0, 0.2, 0)), 56 - v * 6
		elseif t < S.Collapse then
			-- down low by the egg, looking up the beam
			local v = (t - S.BeamAt) / math.max(0.1, S.Collapse - S.BeamAt)
			local pos = S.At(3.2 * K, 0.45, (-1.8 + v * 0.5) * K)
			local up = math.min(S.BeamH or 10, 12)
			local look = center:Lerp(center + Vector3.new(0, up, 0), 0.25 + 0.35 * smooth(v))
			return CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, -0.06 * v), 64
		end
		-- back round to the reveal side, pushing in as it's sucked back in
		local v = (t - S.Collapse) / math.max(0.1, S.Build - S.Collapse)
		local pos = S.At((5.6 - v * 0.6) * K, S.MidY + 0.9, 0.6 * K)
		return CFrame.lookAt(pos, center), 48 - v * 4
	end,
	OnBurst = function(S, at)
		local floor = Vector3.new(S.Base.Position.X, S.FloorY, S.Base.Position.Z)
		DinosaurVFX.GroundImpact(floor, 1.5 + S.Order * 0.15)
		local base = S.Base
		for k = 0, 3 do
			DinosaurVFX.DustWave(floor, base:VectorToWorldSpace(Vector3.new(math.cos(k * math.pi / 2), 0, math.sin(k * math.pi / 2))), 1.1)
		end
		DinosaurVFX.Cubes(at, 22, { S.Rc, WHITE, S.Rc:Lerp(WHITE, 0.5) }, 0.3, 30, 1.3)
		if S.Rarity == "Legendary" or S.Rarity == "Secret" then Audio.Play("Reveal", { Volume = 0.8 }) end
		-- one last thick column of light it stands in, fading
		if S.Beam then
			S.Beam.Size = Vector3.new(S.BeamH, 3.2 * S.EggScale, 3.2 * S.EggScale)
			S.Beam.Transparency = 0.1
			S.Beam.CFrame = CFrame.new(Vector3.new(at.X, S.FloorY + S.BeamH / 2, at.Z)) * CFrame.Angles(0, 0, math.pi / 2)
			TweenService:Create(S.Beam, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Transparency = 1, Size = Vector3.new(S.BeamH, 0.2, 0.2) }):Play()
			S.Beam = nil
		end
		for _, segs in ipairs(S.Fissures) do
			for _, f in ipairs(segs) do
				f.Part.Color = S.Rc
				TweenService:Create(f.Part, TweenInfo.new(0.7), { Transparency = 1 }):Play()
			end
		end
	end,
	Reveal = function(S, baby, anim, R)
		-- a glowing silhouette in the light, the colour flooding in, eyes lit - and a roar. (A Legendary / Secret
		-- already wears a rarity Highlight: it steps aside while this one fades, then comes back)
		local others = {}
		for _, d in ipairs(baby:GetDescendants()) do
			if d:IsA("Highlight") and d.Enabled then
				d.Enabled = false
				table.insert(others, d)
			end
		end
		task.delay(1.95, function()
			for _, d in ipairs(others) do
				if d.Parent then d.Enabled = true end
			end
		end)
		local hl = Instance.new("Highlight")
		hl.Adornee = baby
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.FillColor = S.Rc:Lerp(WHITE, 0.6)
		hl.FillTransparency = 0
		hl.OutlineColor = S.Rc
		hl.OutlineTransparency = 0
		hl.Parent = baby
		TweenService:Create(hl, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25), { FillTransparency = 1 }):Play()
		TweenService:Create(hl, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.7), { OutlineTransparency = 1 }):Play()
		Debris:AddItem(hl, 2.1)
		if not hold(S, baby, 0.3) then return end
		DinosaurVFX.EyeGlow(baby, 1.8)
		if anim then anim:Play(anim:HasAction("Roar") and "Roar" or "LookAround") end
		if not hold(S, baby, 0.35) then return end
		Audio.Play("BabyChirp", { Pitch = R.Chirp - 0.05, Volume = 1.2 })
		local mouth = DinosaurVFX.findAttachment(baby, "VFX_Mouth") or DinosaurVFX.findAttachment(baby, "VFX_Head")
		if mouth then
			local cam = Workspace.CurrentCamera
			DinosaurVFX.RoarShockwave(CFrame.lookAt(mouth.WorldPosition, cam.CFrame.Position), math.clamp(R.Size.Y / 4, 0.5, 1.6), true)
		end
		DinosaurVFX.Shake(0.45, 0.3)
	end,
}

-- choosing ----------------------------------------------------------------------------------------------------------
-- (the grand ones belong to the rarer tiers; a common never gets the eruption, a legendary never just wobbles twice)
local POOLS = {
	Common = { "Wobble", "Peek", "SpinPop", "Sleepy" },
	Uncommon = { "Wobble", "Peek", "SpinPop", "Sleepy" },
	Rare = { "Wobble", "Peek", "SpinPop" },
	Epic = { "Wobble", "SpinPop", "Eruption" },
	Legendary = { "Wobble", "Eruption" },
	Secret = { "Wobble", "Eruption" },
}
local last: string? = nil

function HatchStyles.Pick(rarity: string, force: string?)
	if force and Styles[force] then
		last = force
		return Styles[force]
	end
	local pool = POOLS[rarity] or POOLS.Common
	local opts = {}
	for _, n in ipairs(pool) do
		if n ~= last then table.insert(opts, n) end
	end
	if #opts == 0 then opts = pool end
	local name = opts[math.random(1, #opts)]
	last = name
	return Styles[name]
end

HatchStyles.Styles = Styles
HatchStyles.Names = { "Wobble", "Peek", "SpinPop", "Sleepy", "Eruption" }

return HatchStyles
