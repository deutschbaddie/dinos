--[[
	FROST FOREST — Frostfang (Yutyrannus). Its idea: you NEVER SEE IT COMING. The forest tells you where it is.

	  SIGN      FROZEN IN PLACE: a fan of blue ice blasted across the road from the trees, crystals grown along it the
	            way the breath went, and at the end of it a little compy frozen solid mid-run in a block of ice.
	  GLIMPSE   THE WAVE: snow falling, quiet. Far up the road a pine dumps its snow. Then the next one, closer. And the
	            next - something big is coming through the forest toward you, faster and faster, and the last tree
	            empties right over the lens. White. Silence. One huge frosted feather spins down out of the sky and
	            lands in the snow in front of you. A growl, a long way off. You never see it.
	  CLOSE     BREATH: on the escape a head leans out of the pines ahead and breathes across the road. The road
	            freezes into a sheet right in front of you; you slide over it.
]]

return function(K)
	local E = { Zone = "FrostForest", Boss = "Frostfang", Species = "Yutyrannus" }
	E.Names = { "SIGN", "GLIMPSE", "CLOSE CALL" }
	local Ice, IceDeep = Color3.fromRGB(186, 228, 250), Color3.fromRGB(110, 176, 228)
	local Snow = { Color3.fromRGB(246, 250, 255), Color3.fromRGB(226, 236, 250), Color3.fromRGB(210, 226, 246) }

	-- a powder of snow falling off a branch at p (k = size)
	local function snowDump(p: Vector3, k: number)
		K.VFX.Burst(CFrame.new(p), math.floor(10 + 8 * math.min(k, 2.5)), {
			Speed = NumberRange.new(2, 6 * k), Spread = Vector2.new(70, 70), Color = Color3.fromRGB(246, 250, 255),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6 * k), NumberSequenceKeypoint.new(1, 5 * k) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.4, 2.4), Acceleration = Vector3.new(0, -9, 0), Drag = 1.5,
		})
		K.VFX.Cubes(p, math.floor(8 + 8 * math.min(k, 2)), Snow, 0.5 * k, 5, 1.6)
	end

	-- a flat run of ice along the ground from a to b (segments hug uneven ground)
	local function iceStrip(parent: Instance, a: Vector3, b: Vector3, w0: number, w1: number, parts: { BasePart }?)
		local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = d.Magnitude
		if len < 0.5 then return end
		local dir = d.Unit
		local yaw = math.atan2(-dir.X, -dir.Z)
		local n = math.max(1, math.ceil(len / 9))
		for i = 0, n - 1 do
			local c = a + dir * ((i + 0.5) * len / n)
			local w = w0 + (w1 - w0) * ((i + 0.5) / n)
			local p = K.Slab(parent, c, Vector3.new(w, 0.07, len / n + 0.4), yaw, { Color = Ice, Material = Enum.Material.Ice, Transparency = 0.18, Reflectance = 0.22, Lift = 0.04 })
			if parts then table.insert(parts, p) end
		end
	end

	----------------------------------------------------------------------------
	-- SIGN: frozen in place
	----------------------------------------------------------------------------
	function E.Trace(): Folder?
		local route = K.RouteMath.get(E.Zone)
		if not route then return nil end
		local f = K.Props("Omen_FrostForest")
		local s = 220
		local hw = route:HalfWidth(1, s)
		local p0, fwd, right = route:Sample(1, s)
		local origin = p0 + right * (hw + 24)
		-- the fan: rays of ice from where it stood, across the road
		for a = -4, 4 do
			local ang = a * math.rad(7)
			local dir = (CFrame.fromAxisAngle(Vector3.yAxis, ang):VectorToWorldSpace(-right))
			local reach = (hw * 2 + 30) * (1 - math.abs(a) * 0.045)
			iceStrip(f, origin + dir * 2, origin + dir * reach, 1.2, 4.2)
			if a % 3 == 0 then
				-- a crack line down the middle of every third ray
				local mid = origin + dir * (reach * 0.55)
				K.Slab(f, mid, Vector3.new(0.18, 0.09, reach * 0.8), math.atan2(-dir.X, -dir.Z), { Color = IceDeep, Material = Enum.Material.Ice, Lift = 0.07 })
			end
		end
		-- frost crystals grown along the blast, leaning the way it went
		for i = 1, 9 do
			local a = (i - 5) * math.rad(8)
			local dir = CFrame.fromAxisAngle(Vector3.yAxis, a):VectorToWorldSpace(-right)
			local at = K.Ground(origin + dir * (3 + (i % 3) * 3.5), 12)
			local h = 2.4 + (i % 4) * 0.9
			local cf = CFrame.lookAt(at, at + dir) * CFrame.Angles(math.rad(-58), 0, 0) * CFrame.new(0, 0, -h / 2)
			K.Part(f, { Size = Vector3.new(0.6, 0.6, h), CFrame = cf, Color = Ice, Material = Enum.Material.Ice, Transparency = 0.1, Reflectance = 0.3, Shadow = true, Name = "FrostCrystal" })
		end
		-- the compy that didn't get away: frozen mid-run in a block of ice on the far verge
		local cAt = p0 - right * (hw + 6) + fwd * 1.5
		local statue = K.Statue(f, "Compy", 1.7, cAt, fwd + right * 0.4)
		local blockAt = cAt
		if statue then
			local bb, size = statue:GetBoundingBox()
			blockAt = bb.Position
			K.Part(f, { Size = size * 1.25 + Vector3.new(0.6, 0.4, 0.6), CFrame = bb * CFrame.Angles(0, 0.2, 0.06), Color = Ice, Material = Enum.Material.Ice, Transparency = 0.5, Reflectance = 0.2, Shadow = true, Name = "IceBlock" })
		end
		K.Slab(f, cAt, Vector3.new(5, 0.35, 5), 0.5, { Color = Snow[1], Material = Enum.Material.Snow })
		local nextGlint = 0
		K.Near(f, p0, 150, function()
			if os.clock() > nextGlint then
				nextGlint = os.clock() + 2.5 + math.random() * 2.5
				K.Glint(blockAt + Vector3.new(0, 1.2, 0), 1.0)
			end
		end)
		return f
	end

	----------------------------------------------------------------------------
	-- GLIMPSE: the wave
	----------------------------------------------------------------------------
	local function feather(parent: Instance)
		local parts = {}
		local function add(off: CFrame, size: Vector3, col: Color3)
			local p = K.Part(parent, { Size = size, CFrame = off, Color = col, Material = Enum.Material.SmoothPlastic, Shadow = true, Name = "Feather" })
			table.insert(parts, { p, off })
		end
		add(CFrame.new(), Vector3.new(0.14, 0.14, 4.6), Color3.fromRGB(240, 246, 255))
		for i = 0, 5 do
			local z = -1.8 + i * 0.62
			local w = 0.55 + math.sin((i + 0.5) / 6 * math.pi) * 0.75
			local col = Color3.fromRGB(240, 246, 255):Lerp(Color3.fromRGB(150, 200, 240), i / 6)
			for side = -1, 1, 2 do
				add(CFrame.new(side * (w / 2 + 0.06), 0, z) * CFrame.Angles(0, side * 0.35, 0), Vector3.new(w, 0.04, 0.66), col)
			end
		end
		return parts
	end
	local function featherTo(parts, cf: CFrame)
		for _, e in ipairs(parts) do e[1].CFrame = cf * e[2] end
	end

	function E.Sight(ctx, sc)
		local route, vi = ctx.Route, ctx.Vi
		local root: CFrame = ctx.Root
		local fwd = K.Flat(root.LookVector)
		local eye = root.Position + fwd * 2.4 + Vector3.new(0, 3.2, 0)
		local s0 = ctx.S
		-- the treeline with the most trees in it
		local side = -K.OpenSide(route, vi, s0 + 40, s0 + 200, route:HalfWidth(vi, s0 + 60) + 18)
		local dumps = {}
		for i = 0, 11 do
			local s = s0 + 210 - i * 15
			local hw = route:HalfWidth(vi, s)
			local x = side * (hw + 10 + ((i * 7) % 5) * 4)
			local base = route:Position(vi, s, x)
			local top = K.Top(base, 90)
			local g = K.Ground(base, 30)
			local h = top.Y - g.Y
			table.insert(dumps, { P = (h > 8) and top or g + Vector3.new(0, 16, 0), Tree = h > 8 })
		end
		local set = K.Stage.new("OmenFrostWave")
		set:Show()
		local fx = Instance.new("Folder")
		fx.Parent = set.Folder
		sc:Grade("Frost", 0.01)
		sc:Hush(true)
		-- 1. quiet; snow coming down
		local snowing = true
		task.spawn(function()
			while snowing and fx.Parent do
				local c = sc.Camera.CFrame
				K.VFX.Cubes(c.Position + c.LookVector * 14 + c.RightVector * (math.random() * 16 - 8) + Vector3.new(0, 10, 0), 1, Snow, 0.18, 1, 2.5)
				task.wait(0.05)
			end
		end)
		local look = dumps[1].P
		local fov = 46
		local skipped = sc:Run(0.8, function() sc:Cam(CFrame.lookAt(eye, look), fov) end)
		-- 2. the wave: tree after tree dumping its snow, closer and faster
		if not skipped then
			local t = 0
			local times = {}
			for i = 1, #dumps do
				times[i] = t
				t += 0.4 * (1 - (i - 1) / #dumps * 0.55)
			end
			local fired = 0
			skipped = sc:Run(t + 0.25, function(_, tt, dt)
				while fired < #dumps and tt >= times[fired + 1] do
					fired += 1
					local d = dumps[fired]
					-- far trees dump bigger clouds so the first ones still read from the bonnet
					local k = math.max(1 + fired / #dumps, (d.P - eye).Magnitude / 45)
					snowDump(d.P, k)
					K.Audio.Play("StompBig", { Volume = 0.25 + fired * 0.06, Pitch = 1.6 - fired * 0.05, Exact = true })
					sc:Shake(0.05 + fired * 0.03, 0.25)
				end
				local target = dumps[math.max(1, fired)].P
				look = look:Lerp(target, math.min(1, dt * 5))
				fov = fov + (58 - fov) * math.min(1, dt * 1.5)
				sc:Cam(CFrame.lookAt(eye, look), fov)
			end)
		end
		-- 3. the last tree empties right over the lens: white
		if not skipped then
			K.Audio.Play("StompBig", { Volume = 1.0, Pitch = 1.1, Exact = true })
			sc:Shake(0.6, 0.5)
			snowDump(eye + Vector3.new(0, 8, 0) + fwd * 2, 2.2)
			sc:Fade(0.92, 0.12, Color3.fromRGB(244, 248, 255))
			skipped = sc:Run(0.5, function() sc:Cam(CFrame.lookAt(eye, look), fov) end)
			sc:Fade(0, 1.1)
		end
		-- 4. silence; one feather spins down and lands in the snow in front of you
		if not skipped then
			local land = K.Ground(root.Position + fwd * 9 - fwd:Cross(Vector3.yAxis) * side * 2, 20)
			local parts = feather(fx)
			local from = land + Vector3.new(0, 22, 0) + fwd * 3
			local landYaw = math.rad(30)
			local growled = false
			skipped = sc:Run(3.0, function(u, t)
				local fall = K.easeOut(math.min(1, t / 2.6))
				local sway = math.sin(t * 3.1) * (1 - fall) * 2.4
				local pos = from:Lerp(land + Vector3.new(0, 0.12, 0), fall) + fwd:Cross(Vector3.yAxis) * sway
				local spin = t * 2.2 * (1 - fall)
				local tilt = math.sin(t * 3.1) * 0.55 * (1 - fall)
				featherTo(parts, CFrame.new(pos) * CFrame.Angles(0, landYaw + spin, 0) * CFrame.Angles(tilt, 0, tilt * 0.6))
				local aim = pos:Lerp(land, 0.3)
				sc:Cam(CFrame.lookAt(eye, aim), 50 - 16 * K.smooth(u))
				if t > 2.55 and not growled then
					growled = true
					local far = route:Position(vi, s0 + 260, side * 60)
					K.Audio.Play("Growl", { At = far, Volume = 2.0, Pitch = 0.5, Exact = true, Range = 800, Near = 200 })
				end
			end)
			if not skipped then sc:Run(0.7, function() sc:Cam(CFrame.lookAt(eye, land), 34) end) end
		end
		snowing = false
		set:Destroy()
	end

	----------------------------------------------------------------------------
	-- CLOSE: breath across the road
	----------------------------------------------------------------------------
	function E.Close(ctx): boolean
		local route, vi = ctx.Route, ctx.Vi
		local sb = ctx.S() + 160
		if sb + 80 > route:Length(vi) then return false end
		local hw = route:HalfWidth(vi, sb)
		local p, f, r = route:Sample(vi, sb)
		local side = -K.OpenSide(route, vi, sb - 20, sb + 20, hw + 16) -- the side with trees to hide in
		local set = K.Stage.new("OmenFrostBreath")
		set:Show()
		local fx = Instance.new("Folder")
		fx.Parent = set.Folder
		local ff = set:Dino(E.Species, { Scale = 1.05 })
		if not ff then set:Destroy() return false end
		local standAt = K.Floor(route:Position(vi, sb + 8, side * (hw + 13)), 20)
		local face = K.Flat(-r * side - f * 0.5)
		ff:Place(standAt, face)
		ff:Act("Listen", 1.0)
		snowDump(standAt + Vector3.new(0, 14, 0), 1.6)
		local roared, iced, slid = false, false, false
		local iceParts = {}
		local t0 = os.clock()
		local roarT = 0
		while ctx.Active() and os.clock() - t0 < 12 do
			local s = ctx.S()
			local gap = sb - s
			if not roared and gap < ctx.Speed() * 1.55 + 18 then
				roared = true
				roarT = os.clock()
				ff:Act("FrostRoar", 1.0)
			end
			-- the breath reaches the road ~1 s into the roar: ice races across in a sheet
			if roared and not iced and os.clock() - roarT > 0.95 then
				iced = true
				local mouth = ff:Mouth()
				for k = 0, 5 do
					task.delay(k * 0.08, function()
						if not fx.Parent then return end
						K.VFX.Burst(CFrame.lookAt(mouth.Position, mouth.Position + (-r * side) * 10 + Vector3.new(0, -3, 0)), 10, {
							Direction = Enum.NormalId.Front, Spread = Vector2.new(18, 12), Speed = NumberRange.new(26, 36), Color = Color3.fromRGB(214, 238, 255),
							Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) }),
							Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
							Lifetime = NumberRange.new(0.8, 1.2), Drag = 2, LightEmission = 0.3,
						})
					end)
				end
				K.Audio.Play("IceCrack", { At = p, Volume = 1.0 })
				task.spawn(function()
					-- the sheet grows from the far verge across to your side
					local fromX, toX = side * (hw + 6), -side * (hw + 3)
					for i = 0, 6 do
						if not fx.Parent then return end
						local x0 = fromX + (toX - fromX) * (i / 7)
						local x1 = fromX + (toX - fromX) * ((i + 1) / 7)
						for _, ds in ipairs({ -6, 0, 6 }) do
							iceStrip(fx, route:Position(vi, sb + ds, x0), route:Position(vi, sb + ds, x1), 6.4, 6.4, iceParts)
						end
						K.VFX.GroundCracks(K.Ground(route:Position(vi, sb, x1), 10), 1.2)
						K.Audio.Play("Glance", { At = route:Position(vi, sb, x1), Volume = 0.6, Pitch = 0.5 + i * 0.05, Gap = 0.01 })
						task.wait(0.05)
					end
				end)
			end
			-- you slide over it
			if iced and not slid and math.abs(s - sb) < 9 then
				slid = true
				ctx.Knock(math.random() < 0.5 and 1 or -1, 2.2)
				K.Audio.Play("Dodge", { Volume = 0.8, Pitch = 0.6 })
				K.VFX.Cubes(ctx.RoverCF().Position, 14, Snow, 0.35, 12, 0.8)
			end
			-- then it sinks back into the trees
			if roared and os.clock() - roarT > 2.6 then
				local u = math.clamp((os.clock() - roarT - 2.6) / 1.4, 0, 1)
				if not ff.Retreating then ff.Retreating = true ff:Loco("Walk", 0.2) end
				-- (walking, on the floor: it used to slide sideways at its old height, floating or sinking on the slope)
				ff:Place(K.Floor(standAt + r * side * 14 * K.smooth(u), 20), face)
			end
			if slid and gap < -80 then break end
			K.Step()
		end
		task.wait(0.2)
		set:Destroy()
		return roared
	end

	return E
end
