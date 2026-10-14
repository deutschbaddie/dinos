-- Red Cliffs reveal beats (loaded by EraView: returns function(BEATS, REVEAL, H)). Mystery -> reveal, no captions.
--
-- OVIRAPTOR — "heist": a nest of long teal eggs at golden dusk. Cut. One egg fewer. Cut. Another gone, and a
--   black shape flits between the rocks behind it. Cut. One egg left... the camera whips round: there it stands,
--   black against the sun, eyes lit, an egg tucked under its arm. Caught red-handed.
-- PROTOCERATOPS — "dunes": a ring of low dune mounds. They breathe - the sand heaves and sighs. Tight on one: a
--   scalloped frill edge slides up out of it. The camera turns slowly in the middle of the ring as every mound
--   trembles... and four of them burst up out of the sand around you.
-- GALLIMIMUS — "stampede": a long lens on the shimmering horizon; a dust plume racing closer, the ground jumping.
--   Low on the flat: a stampede of black shapes blurs across the lens at full tilt. The last one skids... and stops
--   dead, side-on, one lit eye on you.
-- THERIZINOSAURUS (ruler, gallery) — "grove": a tall tree in a quiet grove, leaves drifting. The canopy shudders;
--   three long pale blades slide down through the leaves; branches rain down; a small head lowers out of the green.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SAND = { Color3.fromRGB(217, 173, 114), Color3.fromRGB(232, 194, 138), Color3.fromRGB(196, 150, 96) }
local SANDSTONE = { Color3.fromRGB(180, 80, 46), Color3.fromRGB(198, 95, 54), Color3.fromRGB(156, 65, 38) }
local TWIG = { Color3.fromRGB(122, 90, 50), Color3.fromRGB(143, 108, 60) }
local EGG = Color3.fromRGB(47, 111, 138)
local EGG_STRIPE = Color3.fromRGB(255, 106, 42)
local DUST = Color3.fromRGB(226, 190, 140)

return function(BEATS, REVEAL, H)
	REVEAL.Oviraptor = { Kick = "THE EGG THIEF?", Beat = "heist", Act = { "Roar" }, Hero = "Low", Warm = true, AtMark = true }
	REVEAL.Protoceratops = { Kick = "THE DUNE DIGGERS", Beat = "dunes", Act = { "Roar" }, Hero = "Low", Warm = true, AtMark = true }
	REVEAL.Gallimimus = { Kick = "THE FASTEST IN THE FLOCK", Beat = "stampede", Act = { "Roar" }, Hero = "Low", Warm = true, AtMark = true }
	REVEAL.Therizinosaurus = { Kick = "THE SCYTHE OF THE CLIFFS", Beat = "grove", Act = { "CrossGuard", "Roar" }, Hero = "Up", Warm = true, AtMark = true }

	local DinosaurVFX = H.DinosaurVFX
	local CineKit = H.CineKit

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
	-- a long egg (an ellipsoid) with an orange band
	local function egg(set: Instance, cf: CFrame, k: number): { BasePart }
		local e = H.prop(set, { Name = "RevealEgg", Size = Vector3.new(0.36, 0.5, 0.36) * k, Color = EGG, CFrame = cf })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = e
		local band = H.prop(set, { Name = "RevealEggBand", Size = Vector3.new(0.3, 0.06, 0.37) * k, Color = EGG_STRIPE, CFrame = cf * CFrame.new(0, 0.04 * k, 0), CastShadow = false })
		return { e, band }
	end
	local function sandstone(set: Instance, at: Vector3, k: number)
		local y = 0
		for i = 1, 3 do
			local w, h = (2.4 - i * 0.55) * k, (0.9 + math.random() * 0.3) * k
			H.prop(set, { Size = Vector3.new(w, h, w * 0.9), Color = SANDSTONE[i], Material = Enum.Material.Sandstone, CFrame = CFrame.new(at + Vector3.new(0, y + h / 2, 0)) * CFrame.Angles(0, math.random() * 3, 0) })
			y += h
		end
	end
	-- weld an egg into a creature's hand (an Oviraptor's left forearm)
	local function holdEgg(set: Instance, m: Model, k: number)
		local bone = m:FindFirstChild("LeftForearm")
		local claw = DinosaurVFX.findAttachment(m, "VFX_LeftClaw")
		if not (bone and bone:IsA("BasePart") and claw) then return end
		for _, p in ipairs(egg(set, claw.WorldCFrame * CFrame.new(0, 0.12 * k, 0) * CFrame.Angles(0, 0, math.rad(25)), k)) do
			local w = Instance.new("WeldConstraint")
			w.Part0 = bone
			w.Part1 = p
			w.Parent = p
			p.Massless = true
			p.Anchored = false
		end
	end

	----------------------------------------------------------------------------------------------------------------
	-- OVIRAPTOR: eggs vanish one by one between cuts; a shadow flits behind the rocks; caught red-handed
	----------------------------------------------------------------------------------------------------------------
	BEATS.heist = function(ctx, skipped)
		local F, S, size = ctx.Face, ctx.Side, ctx.Size
		local k = math.max(1, size / 7)
		local nestAt = H.ground(ctx.Mark + F * (size * 0.42 + 1))
		-- the nest: a ring of twigs and four eggs
		H.prop(ctx.Set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 1.9 * k, 1.9 * k), Color = Color3.fromRGB(154, 122, 74), CFrame = CFrame.new(nestAt + Vector3.new(0, 0.11, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
		for i = 1, 10 do
			local a = (i / 10) * math.pi * 2
			H.prop(ctx.Set, { Size = Vector3.new(0.16, 0.18, 0.8) * k, Color = TWIG[(i % 2) + 1], CFrame = CFrame.new(nestAt + Vector3.new(math.cos(a), 0.3, math.sin(a)) * Vector3.new(0.9 * k, 1, 0.9 * k)) * CFrame.Angles(0, -a, math.rad(14)) })
		end
		local eggs = {}
		for i = 1, 4 do
			local a = (i / 4) * math.pi * 2 + 0.4
			table.insert(eggs, egg(ctx.Set, CFrame.new(nestAt + Vector3.new(math.cos(a) * 0.42 * k, 0.42 * k, math.sin(a) * 0.42 * k)) * CFrame.Angles(0, -a, math.rad(35)), k))
		end
		-- rocks behind the nest, with gaps the thief flits past
		local rockLine = ctx.Mark - F * (size * 0.6 + 2)
		for i = -2, 2 do sandstone(ctx.Set, H.ground(rockLine + S * (i * size * 0.7)), k * (0.9 + (i % 2) * 0.25)) end
		-- the thief waits off to one side, out of every shot
		ctx.Teleport(ctx.Mark - F * (size * 1.4 + 3) - S * (size * 3.5), S)
		local function take(n: number)
			for _, p in ipairs(eggs[n] or {}) do if p.Parent then p:Destroy() end end
		end
		local nestLook = nestAt + Vector3.new(0, 0.4 * k, 0)
		-- 1. four eggs, low and still, the sun behind them
		H.move(CFrame.lookAt(nestAt + F * 5 * k + S * 2 * k + Vector3.new(0, 1.1 * k, 0), nestLook), CFrame.lookAt(nestAt + F * 4.5 * k + S * 1.8 * k + Vector3.new(0, 1.0 * k, 0), nestLook), 1.0, skipped, 40, 38, nestLook)
		if skipped() then return end
		-- 2. cut: three
		take(1)
		H.move(CFrame.lookAt(nestAt - S * 4.5 * k + F * 2.5 * k + Vector3.new(0, 0.7 * k, 0), nestLook), CFrame.lookAt(nestAt - S * 4.2 * k + F * 2.2 * k + Vector3.new(0, 0.7 * k, 0), nestLook), 0.85, skipped, 36, 34, nestLook)
		if skipped() then return end
		-- 3. cut: two... and a black shape flits between the rocks behind
		take(2)
		local eye = nestAt + F * 4 * k - S * 1.2 * k + Vector3.new(0, 1.6 * k, 0)
		local from = ctx.Root.Position
		local to = from + S * (size * 7)
		if ctx.Anim then ctx.Anim:SetLocomotion("Run", 0.05) end
		track(0.95, skipped, function(u)
			local p = H.ground(from:Lerp(to, smooth(u)))
			ctx.Root.CFrame = CFrame.lookAt(p, p + S) * CFrame.new(0, ctx.Lift, 0)
			return CFrame.lookAt(eye, nestLook:Lerp(rockLine + Vector3.new(0, 1.2 * k, 0), 0.55)), 44
		end)
		if ctx.Anim then ctx.Anim:SetLocomotion("Idle", 0.2) end
		if skipped() then return end
		-- 4. cut: one egg left. Silence.
		take(3)
		H.move(CFrame.lookAt(nestAt + F * 2.4 * k + Vector3.new(0, 2.6 * k, 0), nestLook), CFrame.lookAt(nestAt + F * 2.2 * k + Vector3.new(0, 2.4 * k, 0), nestLook), 0.8, skipped, 34, 32, nestLook)
		if skipped() then return end
		-- 5. the last egg is gone too - whip round: it's standing right there, the egg under its arm
		take(4)
		ctx.Teleport(ctx.Mark, F)
		holdEgg(ctx.Set, ctx.Model, k)
		if ctx.Anim then H.playAny(ctx.Anim, { "Sniff" }) end
		CineKit.Punch(4)
		local hp = ctx.Head()
		H.move(CFrame.lookAt(nestAt + F * 1.5 * k + S * 1.5 * k + Vector3.new(0, 0.5, 0), hp), CFrame.lookAt(nestAt + F * 1.2 * k + S * 1.0 * k + Vector3.new(0, 0.5, 0), hp), 0.9, skipped, 46, 40, hp)
	end

	----------------------------------------------------------------------------------------------------------------
	-- PROTOCERATOPS: the dunes breathe; a frill edge rises out of one; four burst up around you
	----------------------------------------------------------------------------------------------------------------
	BEATS.dunes = function(ctx, skipped)
		local F, S, size = ctx.Face, ctx.Side, ctx.Size
		local ringC = H.ground(ctx.Mark + F * (size * 0.95))
		local r = size * 1.05
		local sinkK = 0.86
		-- the lead buried at its mark, the herd buried round the ring (each facing the middle). (put the lead ON its
		-- mark first: it starts wherever the reveal spawned it, and used to rise out of bare sand away from its mound)
		ctx.Teleport(ctx.Mark, F)
		local pack = {}
		local spots = { { Pos = ctx.Mark, Root = ctx.Root, Model = ctx.Model, Anim = ctx.Anim } }
		for _, deg in ipairs({ 100, -100, 175 }) do
			local a = math.rad(deg)
			local dir = (-F * math.cos(a) + S * math.sin(a))
			local p = H.ground(ringC + dir * r)
			local e, ea = H.standIn(ctx.Species, H.scaleOf(ctx.Species) * (0.85 + math.random() * 0.15), CFrame.lookAt(p, Vector3.new(ringC.X, p.Y, ringC.Z)))
			if e then
				e.Parent = ctx.Set
				H.silhouette(e)
				table.insert(spots, { Pos = p, Root = e.PrimaryPart, Model = e, Anim = ea })
			end
		end
		ctx.Extras = {}
		local mounds = {}
		for i, sp in ipairs(spots) do
			local root = sp.Root :: BasePart
			local _, ext = sp.Model:GetBoundingBox()
			local rise = ext.Y * sinkK
			root.CFrame -= Vector3.new(0, rise, 0)
			if i > 1 then table.insert(ctx.Extras, sp.Model) end
			table.insert(pack, { Model = sp.Model, Anim = sp.Anim, Root = root, Rise = rise })
			-- its mound: stacked sand slabs over where it lies
			local look = root.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z).Unit
			local base = H.ground(sp.Pos)
			local list = {}
			for j, dims in ipairs({ { 1.0, 0.45, 1.0 }, { 0.78, 0.4, 0.82 }, { 0.52, 0.32, 0.6 } }) do
				local w, h, d = ext.X * dims[1] * 1.3, ext.Y * dims[2] * 0.6, ext.Z * dims[3]
				local y = (j - 1) * ext.Y * 0.2
				table.insert(list, H.prop(ctx.Set, { Size = Vector3.new(w, h, d), Color = SAND[j], Material = Enum.Material.Sand, CFrame = CFrame.lookAt(base + Vector3.new(0, y + h / 2, 0), base + Vector3.new(0, y + h / 2, 0) + flat) }))
			end
			table.insert(mounds, list)
		end
		ctx.Pack = pack
		-- 1. the dune field at dusk: the mounds heave, slowly, like breathing
		local eye = ringC + F * (size * 1.6) + S * (size * 0.5) + Vector3.new(0, 1.4, 0)
		local homes = {}
		for _, list in ipairs(mounds) do for _, p in ipairs(list) do homes[p] = p.CFrame end end
		local function breathe(t: number, amp: number)
			for i, list in ipairs(mounds) do
				local b = math.max(0, math.sin(t * 2.6 + i * 1.3)) * amp
				for j, p in ipairs(list) do p.CFrame = homes[p] + Vector3.new(0, b * (0.4 + j * 0.3), 0) end
			end
		end
		local t0 = os.clock()
		local puffed = {}
		track(1.7, skipped, function(u)
			local t = os.clock() - t0
			breathe(t, 0.3)
			for i, list in ipairs(mounds) do
				local phase = math.sin(t * 2.6 + i * 1.3)
				if phase > 0.95 and not puffed[i] then
					puffed[i] = true
					DinosaurVFX.Burst(CFrame.new(list[3].Position + Vector3.new(0, 0.6, 0)), 4, { Color = DUST, Speed = NumberRange.new(1, 3), Size = NumberSequence.new(0.6, 1.8), Transparency = NumberSequence.new(0.5, 1) })
				elseif phase < 0.5 then
					puffed[i] = nil
				end
			end
			return CFrame.lookAt(eye - F * u * 2, ringC + Vector3.new(0, 1, 0)), 46 - u * 4
		end)
		if skipped() then return end
		-- 2. tight on the lead's mound: a scalloped frill edge slides up out of the sand
		local lead = pack[1]
		local leadMound = mounds[1][3]
		local low = H.ground(ctx.Mark) + F * (size * 0.55) + S * (size * 0.2) + Vector3.new(0, 0.5, 0)
		local riseBy = lead.Rise * 0.2
		local r0 = lead.Root.CFrame
		track(1.4, skipped, function(u)
			local e = smooth(u)
			lead.Root.CFrame = r0 + Vector3.new(0, riseBy * e, 0)
			if math.random() < 0.15 then DinosaurVFX.Cubes(leadMound.Position + Vector3.new(0, leadMound.Size.Y / 2, 0), 2, SAND, 0.12, 4, 0.5) end
			return CFrame.lookAt(low, leadMound.Position + Vector3.new(0, leadMound.Size.Y * 0.6 + riseBy * e, 0)), 34
		end)
		lead.Rise -= riseBy
		if skipped() then return end
		-- 3. in the middle of the ring, turning slowly; every mound trembles harder... harder...
		local mid = ringC + Vector3.new(0, 1.3, 0)
		track(1.5, skipped, function(u)
			for _, list in ipairs(mounds) do
				for j, p in ipairs(list) do p.CFrame = homes[p] * CFrame.new((math.random() - 0.5) * 0.12 * u, (math.random() - 0.5) * 0.08 * u + j * 0.02, 0) end
			end
			if math.random() < u * 0.4 then DinosaurVFX.Shake(0.15 + u * 0.3, 0.1) end
			local yaw = math.rad(-40 + 80 * smooth(u))
			local dir = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(-F)
			return CFrame.lookAt(mid, mid + dir + Vector3.new(0, -0.15, 0)), 54 + u * 6
		end)
		if skipped() then return end
		-- the sand blows apart (the reveal lifts all four out of it)
		for _, list in ipairs(mounds) do
			for _, p in ipairs(list) do if p.Parent then H.shatter(ctx.Set, p, p.Position - Vector3.new(0, 2, 0), 26) end end
		end
		for _, x in ipairs(pack) do DinosaurVFX.HandleEvent(x.Model, "SandBurst", { Scale = 0.8 }) end
		ctx.Teleport(ctx.Mark, F)
		ctx.Root.CFrame -= Vector3.new(0, lead.Rise, 0)
	end

	----------------------------------------------------------------------------------------------------------------
	-- GALLIMIMUS: a dust plume racing in; shadows stampede across the lens; the lead stops dead
	----------------------------------------------------------------------------------------------------------------
	BEATS.stampede = function(ctx, skipped)
		local F, S, size = ctx.Face, ctx.Side, ctx.Size
		local far = ctx.Mark - F * (size * 8) - S * (size * 3)
		local near = ctx.Mark - S * (size * 1.2)
		-- 1. long lens on the horizon: a plume of dust racing closer, the ground starting to jump
		local eye = ctx.Mark + F * (size * 1.2) + Vector3.new(0, 1.6, 0)
		local lastPuff = 0
		track(1.8, skipped, function(u)
			local p = H.ground(far:Lerp(near, u * 0.6))
			if os.clock() - lastPuff > 0.08 then
				lastPuff = os.clock()
				DinosaurVFX.Burst(CFrame.new(p + S * (math.random() - 0.5) * size), 6, { Color = DUST, Speed = NumberRange.new(3, 8), Spread = Vector2.new(60, 60), Size = NumberSequence.new(3, 9), Lifetime = NumberRange.new(1.2, 2), Transparency = NumberSequence.new(0.3, 1), Acceleration = Vector3.new(0, 2, 0) })
				if u > 0.4 then DinosaurVFX.Shake(0.05 + u * 0.2, 0.1) end
			end
			return CFrame.lookAt(eye, p + Vector3.new(0, size * 0.25, 0)), 20 + u * 6
		end)
		if skipped() then return end
		-- 2. low on the flat: black shapes stampede across the lens at full tilt
		local runners = {}
		ctx.Extras = {}
		-- (built standing on the real floor where they start: built at the mark's height on a slope, their ride
		-- height was measured from the wrong floor and they ran sunk into the sand or floating over it)
		local startAt = H.ground(ctx.Mark - S * size * 4)
		for i = 1, 5 do
			local m, a = H.standIn(ctx.Species, H.scaleOf(ctx.Species) * (0.85 + math.random() * 0.2), CFrame.lookAt(startAt, startAt + S))
			if m then
				m.Parent = ctx.Set
				H.silhouette(m)
				if a then
					a.GaitPhase = math.random()
					a:SetLocomotion("Run", 0.05)
				end
				table.insert(ctx.Extras, m)
				local root = m.PrimaryPart :: BasePart
				table.insert(runners, { Root = root, Lift = root.Position.Y - startAt.Y, Lane = (i - 3) * size * 0.32 + (i % 2) * size * 0.15, Delay = (i - 1) * 0.12 })
			end
		end
		local lens = ctx.Mark + F * (size * 0.9) + Vector3.new(0, 0.9, 0)
		local t1 = os.clock()
		track(1.3, skipped, function(u)
			local t = os.clock() - t1
			for _, r in ipairs(runners) do
				local v = math.clamp((t - r.Delay) / 0.9, 0, 1)
				local p = H.ground(ctx.Mark - S * size * 4 + S * size * 8 * v - F * r.Lane)
				r.Root.CFrame = CFrame.lookAt(p, p + S) * CFrame.new(0, r.Lift, 0)
			end
			if math.random() < 0.3 then DinosaurVFX.FootstepDust(H.ground(ctx.Mark + S * (math.random() - 0.5) * size * 3), 1.2) end
			return CFrame.lookAt(lens, ctx.Mark + Vector3.new(0, size * 0.25, 0)), 62
		end)
		if skipped() then return end
		DinosaurVFX.Shake(0.5, 0.25)
		-- 3. the last one: it skids in... and stops dead, side-on, one lit eye on you
		ctx.Teleport(ctx.Mark - S * size * 1.6, S)
		if ctx.Anim then ctx.Anim:SetLocomotion("Run", 0.05) end
		local from = ctx.Root.Position
		local side = ctx.Mark + F * (size * 0.9) + S * (size * 0.3) + Vector3.new(0, ctx.Ext.Y * 0.55, 0)
		track(0.55, skipped, function(u)
			local p = H.ground(from:Lerp(ctx.Mark, 1 - (1 - u) ^ 2))
			ctx.Root.CFrame = CFrame.lookAt(p, p + S) * CFrame.new(0, ctx.Lift, 0)
			return CFrame.lookAt(side, ctx.Head()), 44
		end)
		if ctx.Anim then ctx.Anim:SetLocomotion("Idle", 0.1) end
		DinosaurVFX.FootstepDust(H.ground(ctx.Mark), 1.6)
		DinosaurVFX.HandleEvent(ctx.Model, "Scrape", { At = "VFX_RightFoot" })
		if skipped() then return end
		local hp = ctx.Head()
		H.move(CFrame.lookAt(hp + F * (size * 0.6) + S * 1.2, hp), CFrame.lookAt(hp + F * (size * 0.45) + S * 0.8, hp), 1.0, skipped, 30, 24, hp)
	end

	----------------------------------------------------------------------------------------------------------------
	-- THERIZINOSAURUS (gallery): a quiet grove; the canopy shudders; long pale blades slide down through the leaves
	----------------------------------------------------------------------------------------------------------------
	BEATS.grove = function(ctx, skipped)
		local F, S, size = ctx.Face, ctx.Side, ctx.Size
		local treeAt = H.ground(ctx.Mark + F * (size * 0.3) + S * (size * 0.25))
		local h = ctx.Ext.Y * 1.05
		local parts = H.tree(ctx.Set, treeAt, h)
		ctx.Teleport(ctx.Mark, F)
		local eye = ctx.Mark + F * (size * 1.5 + 6) + Vector3.new(0, 2, 0)
		local canopy = treeAt + Vector3.new(0, h, 0)
		-- 1. the grove, still; a few leaves drifting down
		DinosaurVFX.FallingLeaves(canopy, 6, 8, 2)
		H.move(CFrame.lookAt(eye, canopy), CFrame.lookAt(eye - F * 2, canopy + Vector3.new(0, 1, 0)), 1.4, skipped, 44, 40, canopy)
		if skipped() then return end
		-- 2. the canopy shudders; the blades rake down through it; branches come down
		for _, p in ipairs(parts) do
			local c0 = p.CFrame
			TweenService:Create(p, TweenInfo.new(0.07, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 6, true), { CFrame = c0 * CFrame.new(0.3, 0, 0) }):Play()
		end
		H.birdsUp(ctx.Set, canopy, 8, 8)
		H.playAny(ctx.Anim, { "Browse", "Attack" })
		H.move(CFrame.lookAt(treeAt + F * 6 + S * 3 + Vector3.new(0, 1.5, 0), canopy - Vector3.new(0, 2, 0)), CFrame.lookAt(treeAt + F * 5.5 + S * 2.5 + Vector3.new(0, 1.5, 0), canopy - Vector3.new(0, 3, 0)), 1.3, skipped, 52, 56, canopy)
		if skipped() then return end
		for i = 2, #parts do if parts[i].Parent then H.shatter(ctx.Set, parts[i], canopy + Vector3.new(0, 4, 0), 14) end end
		DinosaurVFX.FallingLeaves(canopy, 10, 26, 2)
		DinosaurVFX.HandleEvent(ctx.Model, "ClawRake", { Scale = 1.4, Arm = "Both" })
		DinosaurVFX.Shake(0.6, 0.3)
		CineKit.ImpactFrame(0.6)
		-- 3. through the falling leaves, the small head lowers into frame, eyes lit
		local hp = ctx.Head()
		H.move(CFrame.lookAt(eye - F * 4 + Vector3.new(0, -1, 0), hp), CFrame.lookAt(eye - F * 5 + Vector3.new(0, -1.2, 0), hp - Vector3.new(0, 1, 0)), 1.2, skipped, 40, 34, hp)
	end
end
