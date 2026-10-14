--[[
	RED CLIFFS — the Scythe King (Therizinosaurus). Its idea: CALM. It eats leaves. It could cut you in half.

	  SIGN      CLEAN CUTS: trees along the road cut clean through, pale cut faces at a slant, the trunks laid down
	            beside their stumps, and three long claw gouges raked across the canyon wall at head height.
	  GLIMPSE   ON THE RIM: leaves drift down into the canyon. The lens follows them up the red wall to the rim, where
	            it's raking a tree bare against the sky, unhurried. A pebble clicks. It FREEZES mid-rake. Slowly its
	            head comes round to the lens. Nothing moves. Then, very slowly, the claws rise and cross - hard cut
	            to black.
	  CLOSE     THE MATADOR: on the escape it's standing in the middle of the road ahead, claws crossed, not moving.
	            You're going to hit it - at the last instant it steps aside, and its claws go through the tree beside
	            you instead. The top of the tree falls away behind you.
]]

return function(K)
	local E = { Zone = "RedCliffs", Boss = "Scythe", Species = "Therizinosaurus" }
	E.Names = { "SIGN", "GLIMPSE", "CLOSE CALL" }
	local Bark, BarkDark = Color3.fromRGB(110, 76, 52), Color3.fromRGB(84, 58, 40)
	local CutFace, Ring = Color3.fromRGB(232, 200, 150), Color3.fromRGB(196, 158, 106)
	local Needles = { Color3.fromRGB(58, 96, 60), Color3.fromRGB(70, 112, 66), Color3.fromRGB(48, 84, 54) }
	local Gouge = Color3.fromRGB(96, 40, 30)

	-- a stump with a clean slanted cut (h tall, d across)
	local function stump(parent: Instance, at: Vector3, h: number, d: number, yaw: number)
		local g = K.Ground(at, 12)
		K.Part(parent, { Shape = "Cylinder", Size = Vector3.new(h, d, d), CFrame = CFrame.new(g + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, yaw, math.pi / 2), Color = Bark, Material = Enum.Material.Wood, Shadow = true })
		local top = CFrame.new(g + Vector3.new(0, h + 0.02, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(24), 0, 0)
		K.Part(parent, { Shape = "Cylinder", Size = Vector3.new(0.12, d * 1.06, d * 1.06), CFrame = top * CFrame.Angles(0, 0, math.pi / 2), Color = CutFace, Material = Enum.Material.SmoothPlastic })
		K.Part(parent, { Shape = "Cylinder", Size = Vector3.new(0.14, d * 0.62, d * 0.62), CFrame = top * CFrame.new(0, 0.01, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Ring, Material = Enum.Material.SmoothPlastic })
		K.Part(parent, { Shape = "Cylinder", Size = Vector3.new(0.16, d * 0.22, d * 0.22), CFrame = top * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = CutFace, Material = Enum.Material.SmoothPlastic })
	end

	-- a felled trunk lying on the ground, cut end showing
	local function trunk(parent: Instance, at: Vector3, len: number, d: number, yaw: number)
		local g = K.Ground(at, 12)
		local cf = CFrame.new(g + Vector3.new(0, d / 2, 0)) * CFrame.Angles(0, yaw, 0)
		K.Part(parent, { Shape = "Cylinder", Size = Vector3.new(len, d, d), CFrame = cf * CFrame.Angles(0, math.pi / 2, 0), Color = Bark, Material = Enum.Material.Wood, Shadow = true })
		K.Part(parent, { Shape = "Cylinder", Size = Vector3.new(0.12, d * 1.04, d * 1.04), CFrame = cf * CFrame.new(0, 0, len / 2 + 0.05) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, math.rad(20), 0), Color = CutFace })
		for i = 1, 3 do
			local bcf = cf * CFrame.new((i % 2 == 0 and 1 or -1) * d * 0.4, d * 0.2, -len / 2 + i * len / 4) * CFrame.Angles(0, (i % 2 == 0 and 1 or -1) * 0.9, 0)
			K.Part(parent, { Size = Vector3.new(0.4, 0.4, d * 1.8), CFrame = bcf * CFrame.new(0, 0, -d * 0.9), Color = BarkDark, Material = Enum.Material.Wood })
			K.Part(parent, { Size = Vector3.new(d * 1.6, 0.9, d * 1.4), CFrame = bcf * CFrame.new(0, 0.2, -d * 1.9), Color = Needles[i], Material = Enum.Material.Grass })
		end
	end

	-- a standing conifer: returns its parts so it can be cut (lower trunk stays, the rest falls)
	local function conifer(parent: Instance, at: Vector3, h: number): ({ BasePart }, CFrame)
		local g = K.Ground(at, 20)
		local cut = h * 0.32
		local fallen = {}
		K.Part(parent, { Size = Vector3.new(1.6, cut, 1.6), CFrame = CFrame.new(g + Vector3.new(0, cut / 2, 0)), Color = Bark, Material = Enum.Material.Wood, Shadow = true })
		table.insert(fallen, K.Part(parent, { Size = Vector3.new(1.4, h - cut, 1.4), CFrame = CFrame.new(g + Vector3.new(0, cut + (h - cut) / 2, 0)), Color = Bark, Material = Enum.Material.Wood, Shadow = true }))
		for i = 0, 3 do
			local w = (h * 0.42) * (1 - i * 0.22)
			local y = h * 0.45 + i * h * 0.15
			table.insert(fallen, K.Part(parent, { Size = Vector3.new(w, h * 0.13, w), CFrame = CFrame.new(g + Vector3.new(0, y, 0)) * CFrame.Angles(0, i * 0.4, 0), Color = Needles[(i % 3) + 1], Material = Enum.Material.Grass, Shadow = true }))
		end
		return fallen, CFrame.new(g + Vector3.new(0, cut, 0))
	end

	-- the top of a cut tree topples away (pivot = the cut, dir = the way it falls)
	local function topple(parts: { BasePart }, pivot: CFrame, dir: Vector3, dur: number)
		local offs = {}
		for i, p in ipairs(parts) do offs[i] = pivot:ToObjectSpace(p.CFrame) end
		local axis = Vector3.yAxis:Cross(K.Flat(dir))
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < dur do
				local u = K.easeIn((os.clock() - t0) / dur)
				local rot = CFrame.fromAxisAngle(axis, u * math.rad(84))
				local cf = CFrame.new(pivot.Position) * rot * (pivot - pivot.Position)
				for i, p in ipairs(parts) do if p.Parent then p.CFrame = cf * offs[i] end end
				K.Step()
			end
			local land = pivot.Position + K.Flat(dir) * 8
			K.VFX.Debris(K.Ground(land, 20), 1.6, BarkDark)
			K.VFX.FoliageBurst(K.Ground(land, 20) + Vector3.new(0, 2, 0), 2)
			K.Audio.Play("StompBig", { At = land, Volume = 0.8, Pitch = 1.2 })
		end)
	end

	----------------------------------------------------------------------------
	-- SIGN: clean cuts
	----------------------------------------------------------------------------
	function E.Trace(): Folder?
		local route = K.RouteMath.get(E.Zone)
		if not route then return nil end
		local f = K.Props("Omen_RedCliffs")
		local s = 128
		local hw = route:HalfWidth(1, s)
		local p0, fwd, right = route:Sample(1, s)
		local yaw = math.atan2(-fwd.X, -fwd.Z)
		-- the stumps, along both verges, every cut at the same angle (one stroke)
		for i, st in ipairs({ { -1, -8, 3.4, 2.6 }, { -1, 4, 2.6, 3.0 }, { 1, -2, 3.0, 2.4 }, { 1, 10, 2.2, 2.8 }, { -1, 15, 2.8, 2.2 } }) do
			stump(f, p0 + right * (st[1] * (hw + 5 + (i % 2) * 2.5)) + fwd * st[2], st[3], st[4], yaw + 0.3)
		end
		-- their trunks, laid down beside them pointing away from the road
		trunk(f, p0 - right * (hw + 12) - fwd * 6, 18, 2.4, yaw + math.rad(70))
		trunk(f, p0 + right * (hw + 11) + fwd * 4, 15, 2.2, yaw - math.rad(64))
		trunk(f, p0 - right * (hw + 14) + fwd * 13, 13, 2.0, yaw + math.rad(100))
		-- three claw gouges raked across the nearest canyon wall (or a boulder if there's no wall in reach)
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { K.Root(), K.Stage.Root() }
		local placed = false
		for _, side in ipairs({ 1, -1 }) do
			if placed then break end
			for _, ds in ipairs({ 0, 12, -12, 24 }) do
				local from = route:Position(1, s + ds, 0) + Vector3.new(0, 9, 0)
				local hit = workspace:Raycast(from, right * side * 70, ray)
				if hit and hit.Normal.Y < 0.4 and hit.Instance.Anchored then
					local n = hit.Normal
					local along = n:Cross(Vector3.yAxis).Unit
					for k = -1, 1 do
						local c = hit.Position + along * (k * 1.7) + Vector3.new(0, k * 0.6, 0)
						local cf = CFrame.lookAt(c, c - n) * CFrame.Angles(0, 0, math.rad(58))
						K.Part(f, { Size = Vector3.new(0.75, 13, 0.5), CFrame = cf, Color = Gouge, Material = Enum.Material.Slate })
						K.Part(f, { Size = Vector3.new(0.3, 12, 0.56), CFrame = cf * CFrame.new(0.1, 0, 0), Color = Gouge:Lerp(Color3.new(0, 0, 0), 0.4), Material = Enum.Material.Slate })
					end
					placed = true
					break
				end
			end
		end
		if not placed then
			local b = K.Ground(p0 + right * (hw + 9) + fwd * 18, 12)
			local rock = K.Part(f, { Size = Vector3.new(7, 6, 6), CFrame = CFrame.new(b + Vector3.new(0, 3, 0)) * CFrame.Angles(0, yaw + 0.3, 0), Color = Color3.fromRGB(176, 92, 62), Material = Enum.Material.Sandstone, Shadow = true })
			for k = -1, 1 do
				K.Part(f, { Size = Vector3.new(0.5, 5.4, 0.3), CFrame = rock.CFrame * CFrame.new(k * 1.4, 0, -3.05) * CFrame.Angles(0, 0, math.rad(55)), Color = Gouge })
			end
		end
		-- a few leaves still drifting down when you're near
		local nextLeaf = 0
		K.Near(f, p0, 120, function()
			if os.clock() > nextLeaf then
				nextLeaf = os.clock() + 4
				K.VFX.FallingLeaves(p0 + right * (hw + 6), 8, 6, 10)
			end
		end)
		return f
	end

	----------------------------------------------------------------------------
	-- GLIMPSE: on the rim
	----------------------------------------------------------------------------
	-- a canyon rim beside the road ahead that you can actually see from the bonnet: stand right at the edge (so it
	-- looms over the drop), on flat rock, with a clear line from the lens to its chest. QC'd: the canyon gate
	-- ~50 studs ahead (rims 40-75 up) is the spot in Red Cliffs. Returns (stand point, outward direction).
	local function findRim(route, vi: number, s0: number, eye: Vector3): (Vector3?, Vector3?)
		local best, bestScore, bestDir = nil, -math.huge, nil
		for ds = 30, 220, 10 do
			local s = s0 + ds
			local base, _, right = route:Sample(vi, s)
			for _, side in ipairs({ 1, -1 }) do
				for x = 16, 100, 3 do
					local top = K.Top(route:Position(vi, s, side * x), 160)
					if top.Y - base.Y > 25 then
						-- (it stands on the real cliff top: K.Top also counts canopies and boulders, so the floor there
						-- must BE the top - nothing standing over the spot)
						local sp, fp = route:Position(vi, s, side * (x + 3)), route:Position(vi, s, side * (x + 9))
						local stand, far = K.Floor(sp, 160), K.Floor(fp, 160)
						local h = stand.Y - base.Y
						local bare = math.abs(K.Top(sp, 160).Y - stand.Y) < 2 and math.abs(K.Top(fp, 160).Y - far.Y) < 2
						if bare and math.abs(stand.Y - far.Y) < 4 and h > 25 then
							local chest = stand + Vector3.new(0, 10, 0)
							if K.Clear(eye, chest) and K.Clear(eye, chest + Vector3.new(0, 8, 0)) then
								local dist = (chest - eye).Magnitude
								local score = -math.abs(dist - 90) + math.min(h, 60) * 0.5
								if score > bestScore then best, bestScore, bestDir = stand, score, right * side end
							end
						end
						break
					end
				end
			end
		end
		return best, bestDir
	end

	function E.Sight(ctx, sc)
		local route, vi = ctx.Route, ctx.Vi
		local root: CFrame = ctx.Root
		local fwd = K.Flat(root.LookVector)
		local eye = root.Position + fwd * 2.4 + Vector3.new(0, 3.2, 0)
		local stand, out = findRim(route, vi, ctx.S, eye)
		local set = K.Stage.new("OmenScytheRim")
		set:Show()
		local fx = Instance.new("Folder")
		fx.Parent = set.Folder
		if not stand then
			-- no rim in sight (should never happen in Red Cliffs): a rise beside the road instead
			out = fwd:Cross(Vector3.yAxis)
			stand = K.Floor(route:Position(vi, ctx.S + 150, 60), 60)
		end
		local standP, outDir = stand :: Vector3, out :: Vector3
		local along = K.Flat(outDir:Cross(Vector3.yAxis))
		local sk = set:Dino(E.Species, { Scale = 1.0 })
		if not sk then set:Destroy() return end
		local treeAt = standP + along * 9 + outDir * 2
		conifer(fx, treeAt, 24)
		sk:Place(standP, along) -- side-on to the lens, facing its tree
		if sk.Anim then
			local tr = sk.Anim:Play("Browse", { Loop = true })
			if tr then tr.Loop = true end
		end
		sc:Grade("Dusk", 0.01)
		local roadAhead = K.Road(route, vi, ctx.S + 26, 0)
		local headAim = function(): Vector3 return sk:Head() end
		local rimLook = standP + Vector3.new(0, sk.Size.Y * 0.55, 0)
		-- 1. leaves drifting down onto the road
		K.VFX.FallingLeaves(roadAhead + Vector3.new(0, 0, 0), 9, 16, 9)
		local lowLook = roadAhead + Vector3.new(0, 3, 0)
		local skipped = sc:Run(1.1, function() sc:Cam(CFrame.lookAt(eye, lowLook), 58) end)
		-- 2. up the wall to the rim (following where they come from)
		local rakeAt = 0
		local fovRim = math.clamp(math.deg(2 * math.atan((sk.Size.Y * 1.5) / (rimLook - eye).Magnitude)), 10, 40)
		if not skipped then
			skipped = sc:Run(1.9, function(u, t)
				local k = K.smooth(u)
				sc:Cam(CFrame.lookAt(eye, lowLook:Lerp(rimLook, k)), 58 + (fovRim - 58) * k)
				if t > rakeAt then
					rakeAt = t + 1.1
					K.VFX.FallingLeaves(treeAt + Vector3.new(0, 10, 0), 5, 10, 6)
				end
			end)
		end
		-- 3. it rakes the tree bare, unhurried; the lens creeps closer
		if not skipped then
			skipped = sc:Run(1.5, function(u, t)
				if t > rakeAt then
					rakeAt = t + 1.0
					K.VFX.FoliageBurst(treeAt + Vector3.new(0, 14, 0), 0.9)
					K.Audio.Play("TreeCrack", { At = treeAt, Volume = 0.3, Pitch = 1.6 })
				end
				sc:Cam(CFrame.lookAt(eye + fwd * u * 0.8, rimLook), fovRim * (1 - 0.06 * u))
			end)
		end
		-- 4. a pebble clicks; it FREEZES. Silence.
		if not skipped then
			K.Audio.Play("Glance", { Volume = 0.35, Pitch = 1.7, Exact = true })
			sc:Hush(true)
			if sk.Anim then sk.Anim.Paused = true end
			skipped = sc:Run(0.85, function() sc:Cam(CFrame.lookAt(eye + fwd * 0.8, rimLook), fovRim * 0.94) end)
		end
		-- 5. its head comes round to the lens, slowly (the whole body turns; the pose stays frozen)
		local toCam = K.Flat(eye - standP)
		if not skipped then
			skipped = sc:Run(1.3, function(u)
				local k = K.smooth(u)
				sk:Place(standP, along:Lerp(toCam, k), math.rad(-6) * k)
				sc:Cam(CFrame.lookAt(eye + fwd * 0.8, rimLook:Lerp(headAim(), 0.4 * k)), fovRim * (0.94 - 0.18 * k))
			end)
		end
		if not skipped then
			K.VFX.EyeGlow(sk.Model, 3)
			skipped = sc:Run(0.7, function() sc:Cam(CFrame.lookAt(eye + fwd * 0.8, rimLook:Lerp(headAim(), 0.4)), fovRim * 0.76) end)
		end
		-- 6. very slowly the claws rise and cross... cut to black
		if not skipped then
			if sk.Anim then
				sk.Anim.Paused = false
				sk.Anim:StopActions(0.25)
				sk.Anim:Play("CrossGuard", { Speed = 0.5 })
			end
			K.Audio.Play("Growl", { Volume = 0.35, Pitch = 0.7, Exact = true })
			skipped = sc:Run(1.0, function(u) sc:Cam(CFrame.lookAt(eye + fwd * 0.8, rimLook:Lerp(headAim(), 0.4)), fovRim * (0.76 - 0.05 * u)) end)
			sc:Fade(1, 0)
			K.Audio.Play("Slash", { Volume = 0.6, Pitch = 0.8, Exact = true })
			K.Audio.Play("Snap", { Volume = 0.45, Pitch = 0.6, Exact = true })
			sc:Run(0.65)
		end
		set:Destroy()
	end

	----------------------------------------------------------------------------
	-- CLOSE: the matador
	----------------------------------------------------------------------------
	function E.Close(ctx): boolean
		local route, vi = ctx.Route, ctx.Vi
		local sm = ctx.S() + 170
		if sm + 80 > route:Length(vi) then return false end
		local hw = route:HalfWidth(vi, sm)
		local side = K.OpenSide(route, vi, sm - 20, sm + 20, hw + 10)
		local p, f = route:Sample(vi, sm)
		local set = K.Stage.new("OmenScytheMatador")
		set:Show()
		local fx = Instance.new("Folder")
		fx.Parent = set.Folder
		local sk = set:Dino(E.Species, { Scale = 1.0 })
		if not sk then set:Destroy() return false end
		local mid = K.Floor(p, 20)
		sk:Place(mid, -f)
		if sk.Anim then
			local tr = sk.Anim:Play("CrossGuard", { Loop = true })
			if tr then tr.Loop = true end
		end
		K.VFX.FootstepDust(mid, 2)
		local r = f:Cross(Vector3.yAxis)
		local treeAt = route:Position(vi, sm - 4, side * (hw + 5))
		local treeParts, pivot = conifer(fx, treeAt, 22)
		local growled, stepped, slashed = false, false, false
		local stepT0 = 0
		-- it steps out to the verge just past its tree, then turns back on it: the tree falls along the verge
		-- behind you (never across the road)
		local stepTo = K.Floor(route:Position(vi, sm + 6, side * (hw + 7.5)), 20)
		local toTree = K.Flat(treeAt - stepTo)
		local fallDir = (-f + r * side * 0.45).Unit
		local t0 = os.clock()
		while ctx.Active() and os.clock() - t0 < 12 do
			local s = ctx.S()
			local gap = sm - s
			if not growled and gap < 100 then
				growled = true
				K.Audio.Play("Growl", { At = mid, Volume = 1.0, Pitch = 0.75 })
			end
			if not stepped and gap < ctx.Speed() * 0.62 + 6 then
				stepped = true
				stepT0 = os.clock()
				if sk.Anim then sk.Anim:StopActions(0.12) end
				sk:Loco("Run", 0.05)
				K.Audio.Play("Dodge", { At = mid, Volume = 1.0, Pitch = 0.7 })
			end
			if stepped then
				local u = math.clamp((os.clock() - stepT0) / 0.32, 0, 1)
				local k = K.easeOut(u)
				-- a sidestep and a quarter turn, so it ends side-on to the road with the tree at its claws
				sk:Place(mid:Lerp(stepTo, k), (-f):Lerp(toTree, k))
				if u >= 1 and not slashed then
					slashed = true
					sk:Loco("Idle", 0.1)
					sk:Act("ScytheSweep", 2.1)
					task.delay(0.42, function()
						if not fx.Parent then return end
						K.Audio.Play("Slash", { At = pivot.Position, Volume = 1.2 })
						K.Audio.Play("Snap", { At = pivot.Position, Volume = 1.0, Pitch = 1.3 })
						K.VFX.BiteImpact(pivot.Position + Vector3.new(0, 1, 0), 2.2)
						K.VFX.FoliageBurst(pivot.Position + Vector3.new(0, 6, 0), 1.6)
						K.VFX.Shake(0.9, 0.4)
						topple(treeParts, pivot, fallDir, 1.1)
						ctx.Knock(-side, 2.5)
					end)
					task.delay(1.6, function()
						if fx.Parent then
							sk:Act("Roar", 1.0)
							K.Audio.Play("RoarBig", { At = stepTo, Volume = 1.0, Pitch = 0.85 })
						end
					end)
				end
			end
			if slashed and s > sm + 90 then break end
			K.Step()
		end
		task.wait(0.3)
		set:Destroy()
		return slashed
	end

	return E
end
