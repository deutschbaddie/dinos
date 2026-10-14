-- Frost Forest reveal beats (loaded by EraView: returns function(BEATS, REVEAL, H)).
-- No captions while the mystery plays; the picture, the light and the motion tell it. Each beat ends with the dino
-- where the reveal wants it (on its mark unless the entry says otherwise).
--
-- MICRORAPTOR "canopy": low under snowy branches. Snow sifts down off one... a branch overhead bounces and sheds
-- its snow... a dark four-winged shape glides right over the lens and lands in front of you.
-- PSITTACOSAURUS "eyes": a band of frosty ferns. One clump rustles - nothing. Another - nothing. Close by - nothing.
-- In the dark, pairs of eyes blink open all along the ferns... and the herd pops up.
-- COMPY "tracks": an empty snowy clearing. Tiny three-toed tracks print themselves into the snow from every side,
-- closing in on the camera, right up to your feet. Silence. Then they burst up out of the snow all around you.
-- YUTYRANNUS "whiteout" (the ruler's gallery reveal): white, driving snow, nothing else. Two amber eyes. A foot slams
-- down onto the ice in front of the lens and the cracks race at you; the white thins and it is right over you.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SNOW = { Color3.fromRGB(244, 248, 255), Color3.fromRGB(222, 233, 247), Color3.fromRGB(205, 222, 242) }
local BARK = { Color3.fromRGB(91, 66, 50), Color3.fromRGB(110, 81, 64) }
local FERN = { Color3.fromRGB(63, 138, 74), Color3.fromRGB(79, 156, 82), Color3.fromRGB(52, 120, 66) }
local PRINT = Color3.fromRGB(150, 170, 196)
local ICE = Color3.fromRGB(160, 214, 240)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

return function(BEATS, REVEAL, H)
	local DV = H.DinosaurVFX
	local CineKit = H.CineKit

	REVEAL.Microraptor = { Kick = "THE FOUR-WINGED SHADOW", Beat = "canopy", Act = { "WingDisplay", "Roar" }, Hero = "Low", AtMark = true }
	REVEAL.Psittacosaurus = { Kick = "HIDE AND SQUEAK", Beat = "eyes", Act = { "Roar" }, Hero = "Low", AtMark = true }
	REVEAL.Compy = { Kick = "NEVER JUST ONE", Beat = "tracks", Act = { "Roar" }, Hero = "Low" }
	REVEAL.Yutyrannus = { Kick = "THE BLIZZARD KING", Beat = "whiteout", Act = { "Roar" }, Hero = "Up", AtMark = true }

	-- powder snow sifting down off something (a soft cloud + a few falling chunks)
	local function sift(set: Instance, at: Vector3, k: number)
		DV.Burst(CFrame.new(at), math.floor(8 + k * 6), {
			Color = SNOW[1], Texture = SMOKE, Speed = NumberRange.new(0.5, 2), Spread = Vector2.new(30, 30), Direction = Enum.NormalId.Bottom,
			Acceleration = Vector3.new(0, -10, 0), Drag = 1, Lifetime = NumberRange.new(1.0, 1.8), LightInfluence = 0.6,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * k), NumberSequenceKeypoint.new(1, 1.8 * k) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		})
		for _ = 1, 3 do
			local c = H.prop(set, { Size = Vector3.new(0.4, 0.3, 0.4) * k, Color = SNOW[math.random(1, 3)], CastShadow = false, CFrame = CFrame.new(at + Vector3.new((math.random() - 0.5) * k, 0, (math.random() - 0.5) * k)) })
			c.Anchored = false
			TweenService:Create(c, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), { Transparency = 1 }):Play()
		end
	end
	-- powder puffing up off the ground
	local function puff(at: Vector3, k: number)
		DV.Burst(CFrame.new(at), math.floor(6 + k * 6), {
			Color = SNOW[1], Texture = SMOKE, Speed = NumberRange.new(2 * k, 6 * k), Spread = Vector2.new(80, 80),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * k), NumberSequenceKeypoint.new(1, 2 * k) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.7, 1.3), LightInfluence = 0.6,
		})
		DV.Cubes(at, math.floor(3 + k * 3), SNOW, 0.25 * k, 8 + k * 4, 0.8)
	end
	-- a part-group shiver (ferns, branches)
	local function shiver(parts: { BasePart }, amp: number, dur: number)
		local home = {}
		for _, p in ipairs(parts) do home[p] = p.CFrame end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < dur do
				local u = 1 - (os.clock() - t0) / dur
				for _, p in ipairs(parts) do
					if p.Parent then p.CFrame = home[p] * CFrame.Angles((math.random() - 0.5) * amp * u, 0, (math.random() - 0.5) * amp * u) end
				end
				task.wait(0.03)
			end
			for _, p in ipairs(parts) do if p.Parent then p.CFrame = home[p] end end
		end)
	end
	local function lookCF(from: Vector3, to: Vector3): CFrame
		return CFrame.lookAt(from, to)
	end

	-- MICRORAPTOR -------------------------------------------------------------------------------------------------
	BEATS.canopy = function(ctx, skipped)
		local cam = Workspace.CurrentCamera
		local k = math.clamp(ctx.Size / 6, 0.8, 2)
		local eye = H.ground(ctx.Mark + ctx.Face * (ctx.Size * 1.3 + 7)) + Vector3.new(0, 1.1, 0)
		local markG = H.ground(ctx.Mark)
		-- two frost-dead trees flanking the lens, branches reaching across overhead
		local branchTops = {}
		local branchParts = {}
		for i, s in ipairs({ -1, 1 }) do
			local base = H.ground(eye + ctx.Side * s * 4.5 * k + ctx.Face * (i == 1 and 0.5 or 2.5) * k)
			local h = 13 * k
			H.prop(ctx.Set, { Size = Vector3.new(1.1, h, 1.1) * Vector3.new(k, 1, k), Color = BARK[i], Material = Enum.Material.Wood, CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) })
			local y = (i == 1 and 7.5 or 8.6) * k
			local mid = base + Vector3.new(0, y, 0) - ctx.Side * s * 3.2 * k
			local b = H.prop(ctx.Set, { Size = Vector3.new(6.4 * k, 0.55 * k, 0.6 * k), Color = BARK[3 - i], Material = Enum.Material.Wood, CFrame = lookCF(mid, mid + ctx.Face) * CFrame.Angles(0, 0, -s * 0.12) })
			local cap = H.prop(ctx.Set, { Size = Vector3.new(5.2 * k, 0.2 * k, 0.66 * k), Color = SNOW[1], CFrame = b.CFrame * CFrame.new(-s * 0.4 * k, 0.36 * k, 0) })
			branchTops[i] = cap.Position + Vector3.new(0, 0.1 * k, 0)
			branchParts[i] = { b, cap }
		end
		local skyLook = eye + Vector3.new(0, 9 * k, 0) + ctx.Face * 3 * k
		-- 1. under the branches, looking up: snow sifts off the first one
		task.delay(0.5, function() if not skipped() then sift(ctx.Set, branchTops[1], k) end end)
		H.move(lookCF(eye, skyLook), lookCF(eye - ctx.Face * 0.6, skyLook + ctx.Side * 1.5), 1.3, skipped, 58, 54, nil)
		if skipped() then return end
		-- 2. the other branch bounces - something just pushed off it
		shiver(branchParts[2], 0.08, 0.5)
		sift(ctx.Set, branchTops[2], k * 1.3)
		DV.Shake(0.15, 0.2)
		H.move(lookCF(eye, branchTops[2]), lookCF(eye, branchTops[2] + Vector3.new(0, 0.5, 0)), 0.45, skipped, 44, 40, nil)
		if skipped() then return end
		-- 3. a dark shape glides right over the lens and on down to its mark
		local p0 = branchTops[2] + Vector3.new(0, 0.2, 0)
		local p1 = eye + Vector3.new(0, 2.4 * k, 0) - ctx.Face * 1.5 * k
		local p2 = markG
		H.playAny(ctx.Anim, { "Glide" })
		local t0 = os.clock()
		local dur = 1.25
		while os.clock() - t0 < dur and not skipped() do
			local u = (os.clock() - t0) / dur
			local a = p0:Lerp(p1, u)
			local b = p1:Lerp(p2, u)
			local p = a:Lerp(b, u)
			local dp = (b - a)
			local flat = Vector3.new(dp.X, 0, dp.Z)
			if flat.Magnitude < 0.01 then flat = -ctx.Face end
			local dive = dp.Magnitude > 0.01 and math.clamp(-dp.Unit.Y, -0.5, 0.5) or 0
			ctx.Root.CFrame = CFrame.lookAt(p, p + flat) * CFrame.new(0, ctx.Lift * 0.4, 0) * CFrame.Angles(-dive * 0.6, 0, math.sin(u * math.pi) * 0.4)
			-- whip pan: the lens tracks it overhead, then swings down after it
			cam.CFrame = CFrame.lookAt(eye, p + Vector3.new(0, 0.3, 0))
			cam.FieldOfView = 62 - u * 10
			RunService.RenderStepped:Wait()
		end
		if skipped() then return end
		ctx.Teleport(ctx.Mark, ctx.Face)
		if ctx.Anim then ctx.Anim:StopActions(0.12) end
		puff(markG + Vector3.new(0, 0.2, 0), 0.7 * k)
		H.punch(4)
		local low = H.ground(ctx.Mark + ctx.Face * (ctx.Size * 0.9 + 3) + ctx.Side * 1.2) + Vector3.new(0, 0.6, 0)
		H.move(lookCF(low, ctx.Head()), lookCF(low - ctx.Face * 0.4, ctx.Head()), 0.45, skipped, 44, 40, nil)
	end

	-- PSITTACOSAURUS ----------------------------------------------------------------------------------------------
	BEATS.eyes = function(ctx, skipped)
		local cam = Workspace.CurrentCamera
		local k = math.clamp(ctx.Size / 7, 0.8, 2)
		local markG = H.ground(ctx.Mark)
		-- the fern band: clumps along the line, a few in front of each hider
		local slots = { -3, -2, -1, 0, 1, 2, 3 }
		local spots = {}
		for _, i in ipairs(slots) do
			spots[i] = H.ground(ctx.Mark + ctx.Side * (i * 2.2 * k) - ctx.Face * ((i % 2) * 0.8 * k))
		end
		-- the lead hides in the middle, the herd either side (all tucked down, lids shut)
		ctx.Teleport(ctx.Mark, ctx.Face)
		local hiders = { { Model = ctx.Model, Anim = ctx.Anim } }
		local pack = {}
		for _, i in ipairs({ -3, -2, 2, 3, -1 }) do
			local p = spots[i] - ctx.Face * 0.6 * k
			local e, ea = H.standIn(ctx.Species, H.scaleOf(ctx.Species) * (0.75 + (i % 2) * 0.12), CFrame.lookAt(p, p + ctx.Face + ctx.Side * i * 0.05))
			if e then
				e.Parent = ctx.Set
				H.silhouette(e, false)
				table.insert(hiders, { Model = e, Anim = ea })
				table.insert(pack, { Model = e, Anim = ea, Root = e.PrimaryPart, Rise = 0 })
			end
		end
		ctx.Extras = {}
		for _, x in ipairs(pack) do table.insert(ctx.Extras, x.Model) end
		ctx.Pack = pack
		for _, h in ipairs(hiders) do
			if h.Anim then
				h.Anim:Play("Hide")
				h.Anim.EyesClosed = true
			end
		end
		local clumps = {}
		for _, i in ipairs(slots) do
			local c = spots[i] + ctx.Face * 1.3 * k
			local parts = {}
			for j = 1, 6 do
				local a = j * 60 + i * 17
				table.insert(parts, H.prop(ctx.Set, { Size = Vector3.new(0.6, 0.14, 2.3) * k, Color = FERN[(j + i) % 3 + 1], Material = Enum.Material.Grass, CFrame = CFrame.new(c) * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0.75 * k, -1.0 * k) * CFrame.Angles(math.rad(-30), 0, 0) }))
			end
			table.insert(parts, H.prop(ctx.Set, { Size = Vector3.new(1.0, 0.12, 1.0) * k, Color = SNOW[2], CFrame = CFrame.new(c + Vector3.new(0, 1.25 * k, 0)) * CFrame.Angles(0, i, 0) }))
			clumps[i] = { Parts = parts, At = c }
		end
		local wide = H.ground(ctx.Mark + ctx.Face * (ctx.Size * 1.8 + 9)) + Vector3.new(0, 1.3, 0)
		local fernLine = markG + Vector3.new(0, 1.0 * k, 0) + ctx.Face * 1.3 * k
		-- 1. the quiet fern line
		H.move(lookCF(wide, fernLine), lookCF(wide - ctx.Face * 1.2, fernLine), 0.9, skipped, 46, 44, nil)
		if skipped() then return end
		-- 2. a rustle... the lens whips over: nothing. again. and close by: nothing.
		for n, i in ipairs({ -3, 2, 0 }) do
			local cl = clumps[i]
			shiver(cl.Parts, 0.16, 0.45)
			sift(ctx.Set, cl.At + Vector3.new(0, 1.4 * k, 0), 0.5 * k)
			local near = cl.At + ctx.Face * (3.5 + n) * k + Vector3.new(0, 0.8 * k, 0) + ctx.Side * (n == 2 and -1 or 1) * 1.2
			H.move(lookCF(near, cl.At + Vector3.new(0, 0.8 * k, 0)), lookCF(near - ctx.Face * 0.3, cl.At + Vector3.new(0, 0.7 * k, 0)), 0.62, skipped, 38, 35, nil)
			if skipped() then return end
		end
		-- 3. pulled back into the gloom: pairs of eyes blink open all along the ferns
		TweenService:Create(ctx.Dark, TweenInfo.new(0.4), { Brightness = -0.3, Saturation = -0.7 }):Play()
		cam.CFrame = lookCF(wide - ctx.Face * 2, fernLine)
		cam.FieldOfView = 40
		local order = { 3, 1, 5, 2, 6, 4 }
		for _, idx in ipairs(order) do
			local h = hiders[idx]
			if h and h.Anim then
				h.Anim.EyesClosed = false
				DV.EyeGlow(h.Model, 6)
			end
			H.hold(0.2, skipped)
			if skipped() then return end
		end
		H.hold(0.5, skipped)
		-- the herd pops up as the reveal hits
		for _, h in ipairs(hiders) do
			if h.Anim then
				h.Anim.EyesClosed = false
				h.Anim:StopActions(0.18)
			end
		end
		for _, i in ipairs(slots) do
			local cl = clumps[i]
			task.delay(0.05 + math.random() * 0.2, function() shiver(cl.Parts, 0.3, 0.4) end)
		end
	end

	-- COMPY --------------------------------------------------------------------------------------------------------
	BEATS.tracks = function(ctx, skipped)
		local cam = Workspace.CurrentCamera
		local k = math.clamp(ctx.Size / 4, 0.8, 2)
		local camG = H.ground(ctx.Mark + ctx.Face * (ctx.Size * 1.2 + 6))
		local eye = camG + Vector3.new(0, 1.6, 0)
		-- the lead waits out of sight until the reveal (it scurries in to its mark then)
		local hideAt = ctx.Start
		ctx.Root.CFrame += Vector3.new(0, -ctx.Ext.Y * 3, 0)
		-- the swarm around the camera, buried in the snow until the reveal
		local pack = {}
		local ends = {}
		local angles = { -2.3, -1.25, -0.4, 0.45, 1.3, 2.35 }
		for n, a in ipairs(angles) do
			local dir = (CFrame.fromAxisAngle(Vector3.yAxis, a):VectorToWorldSpace(-ctx.Face))
			ends[n] = { Dir = dir, End = H.ground(camG + dir * (2.4 + (n % 2) * 0.8) * k) }
		end
		for n = 1, 6, 1 do
			if n ~= 3 then
				local p = ends[n].End
				local e, ea = H.standIn(ctx.Species, H.scaleOf(ctx.Species) * (0.8 + (n % 3) * 0.1), CFrame.lookAt(p, Vector3.new(camG.X, p.Y, camG.Z)))
				if e then
					e.Parent = ctx.Set
					H.silhouette(e)
					local r = e.PrimaryPart :: BasePart
					local rise = ctx.Ext.Y * 1.1
					r.CFrame -= Vector3.new(0, rise, 0)
					table.insert(pack, { Model = e, Anim = ea, Root = r, Rise = rise })
				end
			end
		end
		ctx.Extras = {}
		for _, x in ipairs(pack) do table.insert(ctx.Extras, x.Model) end
		ctx.Pack = pack
		-- tracks print themselves into the snow along six paths closing in on the lens
		local paths = {}
		for n, e in ipairs(ends) do
			local start = e.End + e.Dir * (13 + (n % 3) * 2) * k
			paths[n] = { From = start, To = e.End, Steps = 9, Done = 0, Delay = (n % 3) * 0.18 }
		end
		local function printAt(p: Vector3, dir: Vector3, left: boolean)
			local flat = Vector3.new(dir.X, 0, dir.Z).Unit
			local side = flat:Cross(Vector3.yAxis)
			local at = p + side * (left and -0.18 or 0.18) * k + Vector3.new(0, 0.03, 0)
			local base = CFrame.lookAt(at, at + flat)
			local s = 0.75 * k
			local parts = {
				H.prop(ctx.Set, { Size = Vector3.new(0.16, 0.04, 0.2) * s, Color = PRINT, Material = Enum.Material.Snow, CastShadow = false, CFrame = base }),
			}
			for _, ry in ipairs({ -0.5, 0, 0.5 }) do
				table.insert(parts, H.prop(ctx.Set, { Size = Vector3.new(0.06, 0.04, 0.3) * s, Color = PRINT, Material = Enum.Material.Snow, CastShadow = false, CFrame = base * CFrame.Angles(0, ry, 0) * CFrame.new(0, 0, -0.2 * s) }))
			end
			for _, q in ipairs(parts) do
				q.Transparency = 1
				TweenService:Create(q, TweenInfo.new(0.12), { Transparency = 0.1 }):Play()
			end
		end
		local t0 = os.clock()
		local total = 2.8
		local yaw0 = -0.55
		while os.clock() - t0 < total and not skipped() do
			local t = os.clock() - t0
			local u = t / total
			for _, pth in ipairs(paths) do
				local want = math.clamp(math.floor((t - pth.Delay) / ((total - 0.6) / pth.Steps)), 0, pth.Steps)
				while pth.Done < want do
					pth.Done += 1
					local f = pth.Done / pth.Steps
					local p = H.ground(pth.From:Lerp(pth.To, f))
					printAt(p, pth.To - pth.From, pth.Done % 2 == 0)
				end
			end
			-- the lens turns slowly across the clearing, tracks coming at it from every side, tilting down to its feet
			local yaw = yaw0 + u * 1.1
			local look = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(-ctx.Face)
			cam.CFrame = CFrame.lookAt(eye, camG + look * (9 - u * 6.5) * k + Vector3.new(0, -0.2 * u, 0))
			cam.FieldOfView = 58 + u * 8
			RunService.RenderStepped:Wait()
		end
		if skipped() then return end
		-- silence: the last prints, right at the lens
		H.hold(0.45, skipped)
		-- back at the mark for the reveal: it scurries in while the swarm bursts out of the snow
		ctx.Teleport(hideAt, ctx.Face)
		for i, x in ipairs(pack) do
			task.delay(0.06 + 0.08 * i, function()
				if x.Root.Parent then puff(x.Root.Position + Vector3.new(0, 0.3, 0), 0.6 * k) end
			end)
		end
		task.delay(0.2, function()
			if ctx.Model.Parent then DV.Extra.CompySwarm(ctx.Model, { Count = 6, From = { 0, -0.72, 1.5 }, Radius = 5, ChirpIn = 1.2 }, 1) end
		end)
	end

	-- YUTYRANNUS (the ruler's gallery reveal) ----------------------------------------------------------------------
	BEATS.whiteout = function(ctx, skipped)
		local cam = Workspace.CurrentCamera
		local markG = H.ground(ctx.Mark)
		local eye = H.ground(ctx.Mark + ctx.Face * (ctx.Size * 0.75 + 5)) + Vector3.new(0, 1.0, 0)
		-- thin ice in front of its mark
		local iceAt = markG + ctx.Face * (ctx.Size * 0.18)
		H.prop(ctx.Set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, ctx.Size * 0.9, ctx.Size * 0.9), Color = ICE, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.2, CastShadow = false, CFrame = CFrame.new(iceAt + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
		-- white-out: the light goes flat and white, snow driving across the lens
		TweenService:Create(ctx.Dark, TweenInfo.new(0.5), { Brightness = 0.32, Contrast = -0.35, Saturation = -0.85, TintColor = Color3.fromRGB(228, 238, 255) }):Play()
		local host = H.prop(ctx.Set, { Size = Vector3.new(30, 14, 30), Transparency = 1, CastShadow = false, CFrame = CFrame.new(eye:Lerp(ctx.Start, 0.5) + Vector3.new(0, 5, 0)) })
		local emitters = {}
		for _, spec in ipairs({ { 7, 90, 0.3 }, { 0.6, 220, 0 } }) do
			local e = Instance.new("ParticleEmitter")
			e.Shape = Enum.ParticleEmitterShape.Box
			e.Texture = SMOKE
			e.Color = ColorSequence.new(SNOW[1])
			e.LightInfluence = 0.3
			e.Lifetime = NumberRange.new(1.0, 1.8)
			e.Speed = NumberRange.new(8, 16)
			e.EmissionDirection = Enum.NormalId.Right
			e.Acceleration = ctx.Side * 14 - Vector3.new(0, 3, 0)
			e.Size = NumberSequence.new(spec[1], spec[1] * 1.6)
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, spec[3]), NumberSequenceKeypoint.new(1, 1) })
			e.Rate = spec[2]
			e.Parent = host
			e:Emit(math.floor(spec[2] * 0.8))
			table.insert(emitters, e)
		end
		ctx.Teleport(ctx.Start:Lerp(ctx.Mark, 0.55), ctx.Face)
		-- 1. white, wind... two amber eyes, coming closer
		ctx.Walk(ctx.Mark - ctx.Face * (ctx.Size * 0.05), 2.4, skipped, function(u)
			cam.CFrame = CFrame.lookAt(eye, ctx.Head():Lerp(markG + Vector3.new(0, ctx.Ext.Y * 0.5, 0), 0.3)) * CFrame.Angles(math.noise(u * 7, 3) * 0.02, math.noise(u * 7, 9) * 0.02, 0)
			cam.FieldOfView = 46 - u * 6
			if u > 0.4 and u < 0.45 then DV.Shake(0.25, 0.3) end
		end)
		if skipped() then return end
		-- 2. a foot slams down on the ice by the lens: the cracks race at you
		ctx.Teleport(ctx.Mark, ctx.Face)
		local foot = DV.findAttachment(ctx.Model, "VFX_RightFoot")
		local fp = foot and foot.WorldPosition or iceAt
		DV.Extra.IceCrack(ctx.Model, { At = "VFX_RightFoot", Scale = 2.2, Ring = true }, 3)
		DV.Shake(1.1, 0.4)
		H.punch(6)
		CineKit.ImpactFrame(0.8)
		CineKit.HitStop(0.12)
		local low = H.ground(fp + ctx.Face * 7 + ctx.Side * 3) + Vector3.new(0, 0.5, 0)
		H.move(lookCF(low, fp + Vector3.new(0, 1, 0)), lookCF(low - ctx.Face * 0.4, fp + Vector3.new(0, 1.2, 0)), 0.7, skipped, 50, 46, nil)
		if skipped() then return end
		-- 3. the white thins: it's right over you, breath steaming
		for _, e in ipairs(emitters) do e.Rate = e.Rate * 0.3 end
		TweenService:Create(ctx.Dark, TweenInfo.new(1.2), { Brightness = -0.05, Contrast = 0.1, Saturation = -0.4, TintColor = Color3.fromRGB(205, 220, 255) }):Play()
		DV.Extra.BreathPlume(ctx.Model, { Scale = 1.6 }, 3)
		local t0 = os.clock()
		while os.clock() - t0 < 1.3 and not skipped() do
			local u = (os.clock() - t0) / 1.3
			local e = u * u * (3 - 2 * u)
			cam.CFrame = CFrame.lookAt(low, (fp + Vector3.new(0, 1.2, 0)):Lerp(ctx.Head(), e))
			cam.FieldOfView = 46 + e * 14
			if u > 0.6 and u < 0.63 then DV.Extra.BreathPlume(ctx.Model, { Scale = 1.4 }, 3) end
			RunService.RenderStepped:Wait()
		end
		for _, e in ipairs(emitters) do e.Enabled = false end
		task.delay(0.5, function()
			if ctx.Model.Parent then DV.Extra.PineDump(ctx.Model, {}, 3) end
		end)
	end
end
