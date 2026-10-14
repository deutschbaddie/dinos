-- Dawn Desert reveal beats (loaded by EraView: returns function(BEATS, REVEAL, H)). Mystery -> reveal, no captions.
--
-- COELOPHYSIS — "oasis": a still oasis at sunrise. Rings spread on the water from nothing. Low on the surface:
--   pairs of yellow eyes glint in the reflections. The camera lifts to the reeds... and the heads rise out of them
--   in a line, one after another. The pack rises with its leader on the reveal.
-- PLATEOSAURUS — "cycad": a tall cycad at the edge of the scrub shakes and sheds fronds with nobody near it. The
--   camera tilts up the trunk, slow... to a head up in the canopy, chewing, eyes lit — something tall enough to
--   eat the treetops while standing on two legs.
-- DILOPHOSAURUS — "haze": heat shimmer rolling over the sand. Far off, two crests burn through it like flames. A pair
--   circles in the haze, crest to crest. One steps out of it toward you, head bobbing.
-- POSTOSUCHUS (ruler) — "bonewash": a dry riverbed of cracked mud and old bones. A dust devil wanders through. The
--   mud bubbles. Cracks run across it toward the lens; two yellow eyes open in the mud... and it erupts.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TEAL = Color3.fromRGB(63, 184, 200)
local REED = { Color3.fromRGB(111, 154, 58), Color3.fromRGB(88, 128, 44), Color3.fromRGB(130, 160, 70) }
local SAND = { Color3.fromRGB(227, 165, 96), Color3.fromRGB(201, 132, 74) }
local TRUNK = { Color3.fromRGB(122, 90, 52), Color3.fromRGB(140, 106, 62) }
local FROND = { Color3.fromRGB(79, 154, 58), Color3.fromRGB(63, 138, 50), Color3.fromRGB(58, 122, 46) }
local MUD = { Color3.fromRGB(107, 70, 48), Color3.fromRGB(140, 106, 72), Color3.fromRGB(154, 118, 80) }
local BONE = Color3.fromRGB(239, 228, 200)
local EYE = Color3.fromRGB(255, 214, 40)

return function(BEATS, REVEAL, H)
	REVEAL.Coelophysis = { Kick = "THE FIRST HUNTERS", Beat = "oasis", Act = { "Roar" }, Hero = "Low", Warm = true }
	REVEAL.Plateosaurus = { Kick = "THE FIRST GIANT", Beat = "cycad", Act = { "Roar" }, Hero = "Up", Warm = true, AtMark = true }
	REVEAL.Dilophosaurus = { Kick = "TWO CRESTS, ONE AMBUSH", Beat = "haze", Act = { "CrestDisplay", "Roar" }, Hero = "Low", Warm = true }
	REVEAL.Postosuchus = { Kick = "BEFORE THE DINOSAURS, THIS RULED", Beat = "bonewash", Act = { "Roar" }, Hero = "Up", AtMark = true }

	local DinosaurVFX = H.DinosaurVFX
	local CineKit = H.CineKit

	-- a thin glowing hoop lying flat on the water that grows and fades
	local function ring(set: Instance, at: Vector3, r0: number, r1: number, dur: number)
		local h = H.prop(set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, r0 * 2, r0 * 2), Color = Color3.fromRGB(190, 245, 250), Material = Enum.Material.Neon, Transparency = 0.3, CastShadow = false, CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2) })
		TweenService:Create(h, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, r1 * 2, r1 * 2), Transparency = 1 }):Play()
	end
	-- a clump of horsetail reeds
	local function reeds(set: Instance, at: Vector3, h: number, n: number)
		for _ = 1, n do
			local k = h * (0.75 + math.random() * 0.45)
			local p = at + Vector3.new((math.random() - 0.5) * 1.4, 0, (math.random() - 0.5) * 1.4)
			H.prop(set, { Size = Vector3.new(0.3, k, 0.3), Color = REED[math.random(1, #REED)], Material = Enum.Material.Grass, CFrame = CFrame.new(p + Vector3.new(0, k / 2, 0)) * CFrame.Angles((math.random() - 0.5) * 0.25, math.random() * 3, (math.random() - 0.5) * 0.25) })
		end
	end
	-- the camera on a path for dur seconds: camFn(u) -> (CFrame, fov)
	local function track(dur: number, skipped, camFn: (number) -> (CFrame, number))
		local cam = Workspace.CurrentCamera
		local t0 = os.clock()
		while os.clock() - t0 < dur and not skipped() do
			local u = (os.clock() - t0) / dur
			local cf, fov = camFn(u)
			cam.CFrame = cf
			cam.FieldOfView = fov
			RunService.RenderStepped:Wait()
		end
	end
	local function smooth(u: number): number
		return u * u * (3 - 2 * u)
	end

	----------------------------------------------------------------------------------------------------------------
	-- COELOPHYSIS: ripples, eyes in the reflections, heads rising out of the reeds in a line
	----------------------------------------------------------------------------------------------------------------
	BEATS.oasis = function(ctx, skipped)
		local F, S, size = ctx.Face, ctx.Side, ctx.Size
		local lineAt = ctx.Start + F * (size * 0.45)
		local poolC = H.ground(lineAt + F * (size * 0.85))
		local poolW, poolD = size * 2.4, size * 1.15
		local wy = poolC.Y + 0.1
		local water = Vector3.new(poolC.X, wy, poolC.Z)
		H.prop(ctx.Set, { Size = Vector3.new(poolW, 0.14, poolD), Color = TEAL, Material = Enum.Material.Glass, Transparency = 0.12, Reflectance = 0.35, CastShadow = false, CFrame = CFrame.lookAt(water, water + F) })
		H.prop(ctx.Set, { Size = Vector3.new(poolW + 1.4, 0.08, poolD + 1.4), Color = SAND[2], Material = Enum.Material.Sand, CFrame = CFrame.lookAt(water - Vector3.new(0, 0.07, 0), water - Vector3.new(0, 0.07, 0) + F) })
		for i = -6, 6 do reeds(ctx.Set, H.ground(lineAt + S * (i * size * 0.2) + F * ((i % 2) * 0.6)), ctx.Ext.Y * 0.62, 3) end

		-- the pack crouched low behind the reeds in a line, the leader in the middle (heads under the reed tops)
		local sink = ctx.Ext.Y * 0.72
		local line = {}
		local scale = H.scaleOf(ctx.Species)
		for i, k in ipairs({ -2, -1, 1, 2 }) do
			local p = H.ground(lineAt - F * (size * 0.3) + S * (k * size * 0.42))
			local m, a = H.standIn(ctx.Species, scale * (0.84 + (i % 2) * 0.08), CFrame.lookAt(p, p + F - S * k * 0.08))
			if m then
				m.Parent = ctx.Set
				H.silhouette(m)
				local r = m.PrimaryPart :: BasePart
				r.CFrame -= Vector3.new(0, sink, 0)
				table.insert(line, { Model = m, Anim = a, Root = r, K = k })
			end
		end
		ctx.Teleport(lineAt - F * (size * 0.3), F)
		ctx.Root.CFrame -= Vector3.new(0, sink, 0)
		table.insert(line, 3, { Model = ctx.Model, Anim = ctx.Anim, Root = ctx.Root, K = 0, Lead = true })
		ctx.Extras = {}
		for _, x in ipairs(line) do if not x.Lead then table.insert(ctx.Extras, x.Model) end end

		-- 1. low over the still water: rings spread from nothing, one, then another
		local eye1 = water + F * (poolD * 0.5 + 1.2) - S * (size * 0.3) + Vector3.new(0, 0.55, 0)
		local look1 = water - F * (poolD * 0.15) + Vector3.new(0, 0.3, 0)
		local spots = { water + S * (size * 0.2) - F * (poolD * 0.1), water - S * (size * 0.35) + F * (poolD * 0.05), water + S * (size * 0.5) - F * (poolD * 0.25) }
		for i, sp in ipairs(spots) do
			task.delay(0.15 + (i - 1) * 0.42, function()
				if skipped() then return end
				ring(ctx.Set, sp + Vector3.new(0, 0.08, 0), 0.2, size * 0.28, 1.4)
				task.delay(0.2, function() ring(ctx.Set, sp + Vector3.new(0, 0.08, 0), 0.2, size * 0.18, 1.1) end)
			end)
		end
		H.move(CFrame.lookAt(eye1, look1), CFrame.lookAt(eye1 - F * 1.2 + S * 0.6, look1), 1.4, skipped, 44, 40, look1)
		if skipped() then return end

		-- 2. down on the surface: in the reflections, pairs of yellow eyes (one for each head behind the reeds)
		local glints = {}
		for _, x in ipairs(line) do
			local hp = x.Root.Position
			local at = Vector3.new(hp.X, wy + 0.08, hp.Z) + F * (size * 0.55 + poolD * 0.15)
			for _, e in ipairs({ -1, 1 }) do
				local p = H.prop(ctx.Set, { Size = Vector3.new(0.18, 0.04, 0.32) * math.max(1, size / 9), Color = EYE, Material = Enum.Material.Neon, Transparency = 0.25, CastShadow = false, CFrame = CFrame.lookAt(at + S * e * 0.22 * math.max(1, size / 9), at + S * e * 0.22 + F) })
				table.insert(glints, { Part = p, Home = p.CFrame, Ph = math.random() * 6 })
			end
		end
		local mid = water - F * (poolD * 0.15)
		track(1.3, skipped, function(u)
			local e = smooth(u)
			for _, gl in ipairs(glints) do
				gl.Part.CFrame = gl.Home * CFrame.new(math.sin(os.clock() * 5 + gl.Ph) * 0.06, 0, 0)
				gl.Part.Transparency = 0.25 + 0.3 * math.max(0, math.sin(os.clock() * 7 + gl.Ph))
			end
			local eye = mid + F * (poolD * 0.55 - e * 0.8) + Vector3.new(0, 0.45, 0)
			return CFrame.lookAt(eye, mid + Vector3.new(0, 0.05, 0)), 34 - e * 4
		end)
		if skipped() then return end
		for _, gl in ipairs(glints) do gl.Part:Destroy() end

		-- 3. the camera lifts to the reeds... and the heads rise out of them in a line, one after another
		local risen = sink * 0.42
		for i, x in ipairs(line) do
			local order = (x.K + 3) -- left to right
			task.delay(0.12 + order * 0.17, function()
				if skipped() or not x.Root.Parent then return end
				TweenService:Create(x.Root, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = x.Root.CFrame + Vector3.new(0, risen, 0) }):Play()
				DinosaurVFX.FoliageBurst(x.Root.Position + Vector3.new(0, ctx.Ext.Y * 0.5, 0), 0.35)
			end)
			local _ = i
		end
		local reedTop = lineAt + Vector3.new(0, ctx.Ext.Y * 0.5, 0)
		local eye3 = water + F * (poolD * 0.5 + 2.5) + Vector3.new(0, 0.7, 0)
		track(1.5, skipped, function(u)
			local e = smooth(math.min(1, u * 1.4))
			return CFrame.lookAt(eye3 - F * (u * 1.5), (water - F * (poolD * 0.2)):Lerp(reedTop, e)), 40 - u * 6
		end)
		if skipped() then return end
		-- the others finish rising with the reveal (EraView tweens ctx.Pack up and they scream)
		ctx.Pack = {}
		for _, x in ipairs(line) do
			if not x.Lead then table.insert(ctx.Pack, { Model = x.Model, Anim = x.Anim, Root = x.Root, Rise = sink - risen }) end
		end
		CineKit.ImpactFrame(0.4)
	end

	----------------------------------------------------------------------------------------------------------------
	-- PLATEOSAURUS: a tree shakes with nobody near it; tilt up to a head in the canopy
	----------------------------------------------------------------------------------------------------------------
	BEATS.cycad = function(ctx, skipped)
		local F, S, size = ctx.Face, ctx.Side, ctx.Size
		-- it stands at its mark, half-reared into the crown of a tall cycad beside it
		ctx.Teleport(ctx.Mark, F)
		if ctx.Anim and ctx.Anim:HasAction("Browse") then
			local tr = ctx.Anim:Play("Browse", { Loop = true })
			if tr then tr.Loop = true end
		end
		local base = H.ground(ctx.Mark + F * (size * 0.24) + S * (size * 0.22))
		local th = ctx.Ext.Y * 1.25
		local trunk = {} :: { BasePart }
		local n = 8
		for i = 0, n - 1 do
			local w = math.max(0.9, size * 0.075) * (1 - i * 0.03)
			table.insert(trunk, H.prop(ctx.Set, { Size = Vector3.new(w, th / n + 0.05, w), Color = TRUNK[i % 2 + 1], Material = Enum.Material.Wood, CFrame = CFrame.new(base + Vector3.new(0, th / n * (i + 0.5), 0)) * CFrame.Angles(0, i * 0.4, 0) }))
		end
		local top = base + Vector3.new(0, th, 0)
		local crown = {} :: { BasePart }
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			local len = size * 0.17
			local cf = CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.Angles(-0.35, 0, 0) * CFrame.new(0, 0, -len / 2)
			table.insert(crown, H.prop(ctx.Set, { Size = Vector3.new(len * 0.28, 0.25, len), Color = FROND[i % 3 + 1], Material = Enum.Material.Grass, CFrame = cf }))
		end
		local homes = {}
		for _, p in ipairs(trunk) do homes[p] = p.CFrame end
		for _, p in ipairs(crown) do homes[p] = p.CFrame end
		-- the tree shakes: everything sways about its base
		local shaking = true
		task.spawn(function()
			while shaking and not skipped() do
				local t = os.clock()
				local rot = CFrame.Angles(math.sin(t * 9) * 0.02, 0, math.sin(t * 7.3) * 0.025)
				for p, h in pairs(homes) do
					if p.Parent then p.CFrame = CFrame.new(base + rot:VectorToWorldSpace(h.Position - base)) * rot * h.Rotation end
				end
				RunService.RenderStepped:Wait()
			end
		end)

		-- 1. the foot of the tree, nobody there. fronds and leaves rain down; the trunk shudders
		local low = base + F * (size * 0.65) - S * (size * 0.5) + Vector3.new(0, 1.2, 0)
		DinosaurVFX.FallingLeaves(top, size * 0.25, 16, 0)
		task.delay(0.6, function()
			if skipped() then return end
			local f = crown[3]
			if f and f.Parent then
				homes[f] = nil
				H.shatter(ctx.Set, f, top + Vector3.new(0, 3, 0), 6)
			end
		end)
		H.move(CFrame.lookAt(low, base + Vector3.new(0, 1.5, 0)), CFrame.lookAt(low - F * 1.2, base + Vector3.new(0, 2.5, 0)), 1.5, skipped, 46, 44, nil)
		if skipped() then
			shaking = false
			return
		end

		-- 2. the long, slow tilt up the trunk... into the crown: a head up there, chewing, eyes lit
		local eye = base + F * (size * 0.9) - S * (size * 0.2) + Vector3.new(0, 1.0, 0)
		task.delay(1.2, function()
			if skipped() then return end
			local f = crown[7]
			if f and f.Parent then
				homes[f] = nil
				H.shatter(ctx.Set, f, ctx.Head(), 9)
			end
			DinosaurVFX.FoliageBurst(top, 1.0)
		end)
		track(2.2, skipped, function(u)
			local e = smooth(u)
			local target = (base + Vector3.new(0, 1.5, 0)):Lerp(ctx.Head(), e)
			return CFrame.lookAt(eye - F * (e * 1.5), target), 50 - e * 14
		end)
		shaking = false
		if skipped() then return end
		-- 3. it stops chewing. the head turns down toward you
		local hp = ctx.Head()
		H.move(CFrame.lookAt(eye - F * 1.5, hp), CFrame.lookAt(eye - F * 1.8 + Vector3.new(0, 0.4, 0), hp), 0.6, skipped, 36, 32, hp)
	end

	----------------------------------------------------------------------------------------------------------------
	-- DILOPHOSAURUS: crests burning through the heat haze; a pair circles; one steps out, bobbing
	----------------------------------------------------------------------------------------------------------------
	-- flame-like glow on a crest (particles show through the black silhouette)
	local function crestFlame(m: Model): ParticleEmitter?
		local a = DinosaurVFX.findAttachment(m, "VFX_Crest")
		if not a then return nil end
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/fire_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 30))
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.2) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.35, 0.6)
		e.Rate = 40
		e.Speed = NumberRange.new(1, 2.5)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = Vector3.new(0, 4, 0)
		e.Parent = a
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 130, 50)
		l.Range = 10
		l.Brightness = 2
		l.Parent = a
		return e
	end

	BEATS.haze = function(ctx, skipped)
		local F, S, size = ctx.Face, ctx.Side, ctx.Size
		TweenService:Create(ctx.Dark, TweenInfo.new(0.8), { Brightness = 0.04, Saturation = 0.1, Contrast = 0.15, TintColor = Color3.fromRGB(255, 196, 140) }):Play()
		-- the partner, and both crests burning
		local center = H.ground(ctx.Start + F * (size * 0.1))
		local scale = H.scaleOf(ctx.Species)
		local pm, pa = H.standIn(ctx.Species, scale * 0.92, CFrame.lookAt(center + S * (size * 0.4), center))
		local pr: BasePart? = nil
		if pm then
			pm.Parent = ctx.Set
			H.silhouette(pm)
			pr = pm.PrimaryPart
			crestFlame(pm)
			ctx.Extras = { pm }
		end
		crestFlame(ctx.Model)
		ctx.Teleport(center - S * (size * 0.4), S)
		-- heat shimmer: tall sheets of glassy air between us and them, wobbling
		local sheets = {}
		for i = 1, 4 do
			local at = H.ground(ctx.Mark + F * (size * (0.4 + i * 0.25))) + Vector3.new(0, ctx.Ext.Y * 0.6, 0)
			local p = H.prop(ctx.Set, { Size = Vector3.new(size * 3.5, ctx.Ext.Y * 1.4, 0.2), Color = Color3.fromRGB(255, 225, 190), Material = Enum.Material.Glass, Transparency = 0.86, Reflectance = 0.05, CastShadow = false, CFrame = CFrame.lookAt(at, at + F) })
			table.insert(sheets, { Part = p, Home = p.CFrame, Ph = i * 1.3 })
		end
		local alive = true
		local t0 = os.clock()
		task.spawn(function()
			while alive and not skipped() do
				local t = os.clock() - t0
				for _, sh in ipairs(sheets) do
					sh.Part.CFrame = sh.Home * CFrame.new(math.sin(t * 2.2 + sh.Ph) * 0.4, math.sin(t * 3.1 + sh.Ph) * 0.15, 0) * CFrame.Angles(0, 0, math.sin(t * 1.7 + sh.Ph) * 0.02)
				end
				RunService.RenderStepped:Wait()
			end
		end)
		-- they circle each other, crest to crest
		local circling = true
		task.spawn(function()
			local c0 = os.clock()
			while circling and not skipped() do
				local a = (os.clock() - c0) * 0.55
				for k, root in ipairs({ ctx.Root, pr }) do
					if root and root.Parent then
						local ang = a + (k - 1) * math.pi
						local p = H.ground(center + (S * math.cos(ang) + F * math.sin(ang)) * (size * 0.4))
						local tangent = (S * -math.sin(ang) + F * math.cos(ang))
						local lift = k == 1 and ctx.Lift or 0
						if k == 1 then
							root.CFrame = CFrame.lookAt(p, p + tangent) * CFrame.new(0, lift, 0)
						else
							local cf = root.CFrame
							root.CFrame = CFrame.lookAt(Vector3.new(p.X, cf.Position.Y, p.Z), Vector3.new(p.X, cf.Position.Y, p.Z) + tangent)
						end
					end
				end
				RunService.RenderStepped:Wait()
			end
		end)
		if ctx.Anim then ctx.Anim:SetLocomotion("Walk", 0.2) end
		if pa then pa:SetLocomotion("Walk", 0.2) end

		-- 1. long lens through the shimmer: two flames bobbing in the haze, far off
		local far = ctx.Mark + F * (size * 2.6 + 18) + Vector3.new(0, 1.4, 0)
		track(1.7, skipped, function(u)
			return CFrame.lookAt(far - F * (u * 2), center + Vector3.new(0, ctx.Ext.Y * 0.75, 0)), 16 - u * 2
		end)
		if skipped() then
			alive, circling = false, false
			return
		end
		-- 2. closer, low on the sand: the pair circling, crests burning
		local near = ctx.Mark + F * (size * 1.2 + 6) - S * (size * 0.4) + Vector3.new(0, 1.0, 0)
		track(1.5, skipped, function(u)
			return CFrame.lookAt(near + S * (u * 2.5), center + Vector3.new(0, ctx.Ext.Y * 0.5, 0)), 36
		end)
		circling = false
		if skipped() then
			alive = false
			return
		end
		-- 3. one breaks off and steps out of the haze toward you, head bobbing
		if pa then pa:SetLocomotion("Idle", 0.3) end
		ctx.Turn(F, 0.25)
		if ctx.Anim and ctx.Anim:HasAction("CrestDisplay") then ctx.Anim:Play("CrestDisplay") end
		local low = ctx.Mark + F * (size * 0.9 + 5) + S * (size * 0.25) + Vector3.new(0, 0.8, 0)
		-- the haze clears as it comes through it (and is gone before the reveal frames it)
		for _, sh in ipairs(sheets) do TweenService:Create(sh.Part, TweenInfo.new(1.1), { Transparency = 1 }):Play() end
		ctx.Walk(H.ground(ctx.Mark + F * (size * 0.1)), 1.2, skipped, function(u)
			local cam = Workspace.CurrentCamera
			cam.CFrame = CFrame.lookAt(low - F * u, ctx.Head())
			cam.FieldOfView = 40 + u * 6
		end)
		alive = false
		for _, sh in ipairs(sheets) do if sh.Part.Parent then sh.Part:Destroy() end end
		-- the crests keep burning through the reveal, then cool
		task.delay(2.5, function()
			for _, m in ipairs({ ctx.Model, pm }) do
				local a = m and DinosaurVFX.findAttachment(m, "VFX_Crest")
				if a then
					for _, c in ipairs(a:GetChildren()) do
						if c:IsA("ParticleEmitter") then c.Enabled = false end
						if c:IsA("PointLight") then c:Destroy() end
					end
				end
			end
		end)
	end

	----------------------------------------------------------------------------------------------------------------
	-- POSTOSUCHUS: the bone wash — bubbles, cracks running at the lens, two eyes in the mud, the eruption
	----------------------------------------------------------------------------------------------------------------
	BEATS.bonewash = function(ctx, skipped)
		local F, S, size = ctx.Face, ctx.Side, ctx.Size
		TweenService:Create(ctx.Dark, TweenInfo.new(0.8), { Brightness = -0.05, Saturation = -0.15, Contrast = 0.25, TintColor = Color3.fromRGB(255, 190, 150) }):Play()
		local g = H.ground(ctx.Mark)
		-- the wash: a mud bed, crust plates, bones
		H.prop(ctx.Set, { Size = Vector3.new(size * 0.55, 0.1, size * 1.3), Color = MUD[1], Material = Enum.Material.Mud, CFrame = CFrame.lookAt(g + Vector3.new(0, 0.04, 0), g + Vector3.new(0, 0.04, 0) + F) })
		local crust = {}
		for i = 1, 14 do
			local p = g + S * ((math.random() - 0.5) * size * 0.5) + F * ((i / 14 - 0.5) * size * 1.1)
			table.insert(crust, H.prop(ctx.Set, { Size = Vector3.new(1.8 + math.random(), 0.22, 1.6 + math.random()), Color = MUD[math.random(2, 3)], Material = Enum.Material.Slate, CFrame = CFrame.new(p + Vector3.new(0, 0.13, 0)) * CFrame.Angles((math.random() - 0.5) * 0.08, math.random() * 3, (math.random() - 0.5) * 0.08) }))
		end
		local skullAt = H.ground(ctx.Mark + F * (size * 0.62) + S * (size * 0.12))
		local skull = H.prop(ctx.Set, { Size = Vector3.new(1.4, 1.0, 1.9), Color = BONE, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.lookAt(skullAt + Vector3.new(0, 0.5, 0), skullAt + Vector3.new(0, 0.5, 0) - S) })
		H.prop(ctx.Set, { Size = Vector3.new(1.0, 0.7, 1.4), Color = BONE, CFrame = skull.CFrame * CFrame.new(0, -0.12, -1.5) })
		H.prop(ctx.Set, { Size = Vector3.new(1.44, 0.3, 0.4), Color = Color3.fromRGB(58, 42, 32), CFrame = skull.CFrame * CFrame.new(0, 0.15, -0.3) })
		for i = -2, 2 do
			local rp = H.ground(ctx.Mark + F * (size * 0.4) - S * (size * 0.2) + F * (i * 0.7))
			H.prop(ctx.Set, { Size = Vector3.new(0.22, 1.6, 0.22), Color = BONE, CFrame = CFrame.new(rp + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, 0.6) })
		end
		-- it lies buried under the mark: only the eyes will come up
		ctx.Teleport(ctx.Mark, F)
		local buried = ctx.Root.CFrame
		local depth = ctx.Ext.Y * 0.95
		ctx.Root.CFrame = buried - Vector3.new(0, depth, 0)
		for _, h in ipairs(ctx.Model:GetChildren()) do
			if h:IsA("Highlight") and h.FillTransparency < 0.5 then h.Enabled = false end
		end
		-- a dust devil wandering across the wash
		local devil = {}
		for i = 1, 7 do
			table.insert(devil, H.prop(ctx.Set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 1 + i * 0.35, 1 + i * 0.35), Color = Color3.fromRGB(222, 178, 128), Material = Enum.Material.SmoothPlastic, Transparency = 0.55 + i * 0.04, CastShadow = false, CFrame = CFrame.new(g) }))
		end
		local d0 = os.clock()
		local spinning = true
		task.spawn(function()
			while spinning and not skipped() do
				local t = os.clock() - d0
				local c = H.ground(ctx.Mark + F * (size * 0.9) - S * (size * 0.9) + S * (t * size * 0.35))
				for i, p in ipairs(devil) do
					local y = i * 0.85
					p.CFrame = CFrame.new(c + Vector3.new(math.sin(t * 4 + i) * 0.3 * i * 0.3, y, math.cos(t * 4 + i) * 0.3 * i * 0.3)) * CFrame.Angles(0, t * 9 + i, math.pi / 2)
				end
				RunService.RenderStepped:Wait()
			end
			for _, p in ipairs(devil) do if p.Parent then TweenService:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play() end end
		end)

		-- 1. low across the cracked mud, the skull in the foreground, the dust devil passing
		local eye1 = skullAt + F * 4 - S * 2.5 + Vector3.new(0, 0.9, 0)
		H.move(CFrame.lookAt(eye1, g + Vector3.new(0, 0.5, 0)), CFrame.lookAt(eye1 - F * 1.0, g + Vector3.new(0, 0.5, 0)), 1.6, skipped, 46, 44, nil)
		spinning = false
		if skipped() then return end
		-- 2. the mud bubbles; a crack runs across it, straight at the lens
		DinosaurVFX.HandleEvent(ctx.Model, "MudBubble", { Scale = 1.4 })
		DinosaurVFX.Shake(0.25, 0.25)
		local crackFrom = g - F * (size * 0.1)
		local crackTo = skullAt + F * 1.5
		task.spawn(function()
			for i = 1, 9 do
				if skipped() then return end
				local p = crackFrom:Lerp(crackTo, i / 9) + S * (math.random() - 0.5) * 0.6
				H.prop(ctx.Set, { Size = Vector3.new(0.18, 0.06, (crackTo - crackFrom).Magnitude / 8), Color = Color3.fromRGB(40, 26, 18), CastShadow = false, CFrame = CFrame.lookAt(p + Vector3.new(0, 0.26, 0), p + Vector3.new(0, 0.26, 0) + F + S * (math.random() - 0.5) * 0.5) })
				task.wait(0.07)
			end
		end)
		local eye2 = skullAt + F * 2.2 + Vector3.new(0, 0.6, 0)
		H.move(CFrame.lookAt(eye2, crackFrom + Vector3.new(0, 0.2, 0)), CFrame.lookAt(eye2 - F * 0.6, crackFrom + Vector3.new(0, 0.3, 0)), 0.9, skipped, 40, 34, nil)
		if skipped() then return end
		-- 3. two yellow eyes come up out of the mud
		local eyeUp = 0
		local la = DinosaurVFX.findAttachment(ctx.Model, "VFX_LeftEye") or DinosaurVFX.findAttachment(ctx.Model, "VFX_Head")
		if la then eyeUp = (g.Y + 0.35) - la.WorldPosition.Y end
		TweenService:Create(ctx.Root, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { CFrame = ctx.Root.CFrame + Vector3.new(0, eyeUp, 0) }):Play()
		DinosaurVFX.EyeGlow(ctx.Model, 6)
		local hp = ctx.Head()
		local eye3 = Vector3.new(hp.X, g.Y, hp.Z) + F * (size * 0.3 + 2) - S * 1.2 + Vector3.new(0, 0.55, 0)
		H.move(CFrame.lookAt(eye3, Vector3.new(hp.X, g.Y + 0.3, hp.Z)), CFrame.lookAt(eye3 - F * 0.4, Vector3.new(hp.X, g.Y + 0.3, hp.Z)), 1.0, skipped, 26, 20, nil)
		if skipped() then return end
		-- it erupts: the crust flies, the skull is flung, and it's up on its mark for the reveal
		for _, c in ipairs(crust) do if c.Parent then H.shatter(ctx.Set, c, ctx.Root.Position, 30) end end
		H.shatter(ctx.Set, skull, ctx.Root.Position, 20)
		DinosaurVFX.HandleEvent(ctx.Model, "MudBurst", { Scale = 2.2 })
		local from = ctx.Root.CFrame
		local t0 = os.clock()
		while os.clock() - t0 < 0.3 do
			local u = (os.clock() - t0) / 0.3
			ctx.Root.CFrame = from:Lerp(buried, 1 - (1 - u) ^ 3)
			RunService.RenderStepped:Wait()
		end
		ctx.Root.CFrame = buried
		H.punch(8)
		CineKit.ImpactFrame(0.9)
		DinosaurVFX.Shake(1.1, 0.4)
	end
end
