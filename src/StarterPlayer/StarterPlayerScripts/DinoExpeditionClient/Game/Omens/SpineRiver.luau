--[[
	SPINE RIVER — the Tidebreaker (Mosasaurus). Its idea: the WATER COMES TO YOU. It's never on land, but the river
	keeps arriving where it shouldn't.

	  SIGN      THE TIDE LINE: a long way from any water, a wet band across the road: puddles, kelp, a splintered dock
	            plank, a canoe flung onto the verge, fish flapping on the road. Something threw the river this far.
	  GLIMPSE   THE SPLASH YOU HEAR FIRST: quiet. A deep boom from off to the side. The lens turns: over the jungle a
	            white column of water climbs into the sky, and at its top a black shape hangs, impossibly big for a
	            second, and drops. The second boom arrives late. Then it rains fish around the rover; one smacks onto
	            the bonnet and flops.
	  CLOSE     OVERHEAD: on the escape, where the road runs between the water, it leaps out of the river on one side,
	            sails over the road in front of you and crashes down on the other. The spray rains on the road.
]]

return function(K)
	local E = { Zone = "SpineRiver", Boss = "Tidebreaker", Species = "Mosasaurus" }
	E.Names = { "SIGN", "GLIMPSE", "CLOSE CALL" }
	local Wet = Color3.fromRGB(70, 54, 40)
	local Kelp = { Color3.fromRGB(84, 96, 48), Color3.fromRGB(64, 82, 40), Color3.fromRGB(102, 110, 52) }
	local Plank = Color3.fromRGB(122, 86, 56)
	local FishBody, FishBelly = Color3.fromRGB(110, 158, 190), Color3.fromRGB(214, 226, 232)
	local Spray = { Color3.fromRGB(235, 248, 255), Color3.fromRGB(176, 222, 245), Color3.fromRGB(120, 196, 230) }

	-- a fish: { Parts = { {part, offset} }, CF } moved with fishTo
	local function fish(parent: Instance, cf: CFrame, k: number?)
		local s = k or 1
		local list = {}
		local function add(off: CFrame, props)
			props.CFrame = cf * off
			local p = K.Part(parent, props)
			table.insert(list, { p, off })
		end
		add(CFrame.new(), { Size = Vector3.new(0.5, 0.62, 1.5) * s, Color = FishBody, Reflectance = 0.15, Name = "Fish" })
		add(CFrame.new(0, -0.16 * s, 0), { Size = Vector3.new(0.46, 0.3, 1.3) * s, Color = FishBelly })
		add(CFrame.new(0, 0.38 * s, 0.1 * s), { Size = Vector3.new(0.12, 0.25, 0.6) * s, Color = FishBody:Lerp(Color3.new(0, 0, 0), 0.25) })
		add(CFrame.new(0, 0, 0.98 * s) * CFrame.Angles(math.rad(45), 0, 0), { Size = Vector3.new(0.12, 0.55, 0.55) * s, Color = FishBody:Lerp(Color3.new(0, 0, 0), 0.2) })
		for side = -1, 1, 2 do
			add(CFrame.new(side * 0.26 * s, 0.1 * s, -0.48 * s), { Size = Vector3.new(0.04, 0.14, 0.14) * s, Color = Color3.fromRGB(20, 20, 24) })
		end
		return { Parts = list, CF = cf }
	end
	local function fishTo(f, cf: CFrame)
		f.CF = cf
		for _, e in ipairs(f.Parts) do e[1].CFrame = cf * e[2] end
	end
	-- lying on its side on the ground at p
	local function onGround(p: Vector3, yaw: number, flop: number?): CFrame
		return CFrame.new(p + Vector3.new(0, 0.28 + (flop or 0), 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(84) + (flop or 0) * 0.6)
	end

	----------------------------------------------------------------------------
	-- SIGN: the tide line
	----------------------------------------------------------------------------
	function E.Trace(): Folder?
		local route = K.RouteMath.get(E.Zone)
		if not route then return nil end
		local f = K.Props("Omen_SpineRiver")
		local s = 215
		local hw = route:HalfWidth(1, s)
		local p0, fwd, right = route:Sample(1, s)
		local yaw = math.atan2(-fwd.X, -fwd.Z)
		-- the wet band (ragged edges: overlapping strips) and puddles
		for i = -3, 3 do
			local x = i * (hw + 9) / 3.4
			local depth = 6 + ((i * 7) % 5)
			K.Slab(f, p0 + right * x + fwd * ((i % 2) * 1.6 - 0.8), Vector3.new((hw + 9) / 3, 0.05, depth), yaw, { Color = Wet, Transparency = 0.3, Reflectance = 0.16, Lift = 0.02 })
		end
		for i, spot in ipairs({ { -5, 1.5, 4.2 }, { 3.5, -1.2, 3.0 }, { 9, 2.2, 2.4 }, { -hw - 3, -1, 3.4 }, { hw + 4, 0.8, 2.6 } }) do
			local g = K.Ground(p0 + right * spot[1] + fwd * spot[2], 12)
			K.Part(f, { Shape = "Cylinder", Size = Vector3.new(0.06, spot[3], spot[3] * (1 + (i % 2) * 0.3)), CFrame = CFrame.new(g + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, yaw + i, math.pi / 2), Color = Color3.fromRGB(120, 176, 196), Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.3 })
		end
		-- kelp strands lying across the road
		for i = 1, 7 do
			local base = p0 + right * ((i - 4) * 3.4) + fwd * (math.sin(i * 2.3) * 2.5)
			local a = yaw + i * 0.9
			for j = 0, 2 do
				local dir = Vector3.new(-math.sin(a + j * 0.5), 0, -math.cos(a + j * 0.5))
				K.Slab(f, base + dir * (j * 1.2), Vector3.new(0.38, 0.06, 1.5), a + j * 0.5, { Color = Kelp[(i + j) % 3 + 1], Material = Enum.Material.Grass, Lift = 0.05 })
			end
		end
		-- planks off a broken dock, one snapped
		for i, pl in ipairs({ { -hw - 4, 3, 0.4, 6 }, { hw + 6, -2, 1.3, 5 }, { hw + 7.5, 1.2, 2.1, 2.6 }, { -2, -3.5, -0.3, 3.2 } }) do
			K.Slab(f, p0 + right * pl[1] + fwd * pl[2], Vector3.new(1.2, 0.36, pl[4]), yaw + pl[3], { Color = Plank:Lerp(Color3.new(0, 0, 0), (i % 2) * 0.12), Material = Enum.Material.WoodPlanks, Shadow = true })
		end
		-- a canoe flung onto the verge, on its side
		do
			local c = K.Ground(p0 - right * (hw + 7) - fwd * 4, 12)
			local base = CFrame.new(c + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, yaw + 0.5, 0) * CFrame.Angles(0, 0, math.rad(72))
			local wood, dark = Color3.fromRGB(150, 98, 58), Color3.fromRGB(104, 68, 42)
			K.Part(f, { Size = Vector3.new(1.4, 0.25, 7), CFrame = base * CFrame.new(0, -0.55, 0), Color = dark, Material = Enum.Material.Wood, Shadow = true })
			for side = -1, 1, 2 do
				K.Part(f, { Size = Vector3.new(0.25, 1.0, 7), CFrame = base * CFrame.new(side * 0.78, 0, 0) * CFrame.Angles(0, 0, side * -0.25), Color = wood, Material = Enum.Material.Wood, Shadow = true })
			end
			for e = -1, 1, 2 do
				K.Part(f, { Class = "WedgePart", Size = Vector3.new(1.4, 1.1, 1.6), CFrame = base * CFrame.new(0, 0, e * 4.25) * CFrame.Angles(0, e > 0 and math.pi or 0, 0), Color = wood, Material = Enum.Material.Wood, Shadow = true })
			end
			K.Part(f, { Size = Vector3.new(0.3, 0.3, 4.6), CFrame = CFrame.new(c + right * 2.2 + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, yaw + 1.2, 0), Color = Plank, Material = Enum.Material.Wood }) -- its paddle
		end
		-- fish on the road; every so often one flaps
		local fishes = {}
		for i, fp in ipairs({ { -6, 0.5 }, { -1.5, 2.8 }, { 4.5, -0.6 }, { 8.5, 2.6 }, { hw + 2.5, -1.8 } }) do
			local g = K.Ground(p0 + right * fp[1] + fwd * fp[2], 12)
			local y = yaw + i * 1.7
			local fi = fish(f, onGround(g, y), 0.9 + (i % 3) * 0.15)
			table.insert(fishes, { F = fi, G = g, Yaw = y, T = -1 })
		end
		local nextFlap = 0
		K.Near(f, p0, 140, function()
			local now = os.clock()
			if now > nextFlap then
				nextFlap = now + 0.6 + math.random() * 1.4
				local one = fishes[math.random(1, #fishes)]
				if one.T < 0 then one.T = now end
			end
			for _, fi in ipairs(fishes) do
				if fi.T >= 0 then
					task.spawn(function()
						local t0 = fi.T
						fi.T = -2
						while os.clock() - t0 < 0.42 do
							local u = (os.clock() - t0) / 0.42
							fishTo(fi.F, onGround(fi.G, fi.Yaw + math.sin(u * math.pi * 2) * 0.3, math.sin(u * math.pi) * 0.7))
							K.Step()
						end
						fishTo(fi.F, onGround(fi.G, fi.Yaw))
						fi.T = -1
					end)
				end
			end
		end)
		return f
	end

	----------------------------------------------------------------------------
	-- GLIMPSE: the splash you hear first
	----------------------------------------------------------------------------
	-- river spots east of the arrival (QC'd: from the bonnet the first clears the jungle hills above ~y 23)
	local BREACH_SPOTS = { Vector3.new(-10, 0, -2240), Vector3.new(-62, 0, -2440), Vector3.new(-73, 0, -2513), Vector3.new(-22, 0, -2300) }

	-- how high something over `at` must be before you can see it from eye (the hills in between)
	local function visibleAbove(eye: Vector3, at: Vector3): number
		local flatD = Vector3.new(at.X - eye.X, 0, at.Z - eye.Z).Magnitude
		local need = -math.huge
		for d = 10, flatD - 12, 8 do
			local p = eye:Lerp(Vector3.new(at.X, eye.Y, at.Z), d / flatD)
			local t = K.Top(p, 140).Y
			need = math.max(need, eye.Y + (t - eye.Y) * flatD / d)
		end
		return need
	end

	-- a column of water climbing out of the river (spray cubes, mist, a towering plume of white blocks)
	local function column(parent: Instance, at: Vector3, height: number, rise: number)
		K.VFX.Cubes(at, 40, Spray, 1.8, 58, 2.2)
		K.VFX.WaterSplash(at, 5)
		local plumes = {}
		for i = 1, 9 do
			local p = K.Part(parent, { Shape = "Ball", Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(at), Color = Spray[(i % 3) + 1], Transparency = 0.12, Material = Enum.Material.SmoothPlastic })
			plumes[i] = { P = p, H = height * (i / 9) ^ 0.8, R = 10 - i * 0.6, Off = Vector3.new(math.sin(i * 2.4) * 2.5, 0, math.cos(i * 2.4) * 2.5) }
		end
		task.spawn(function()
			local t0 = os.clock()
			local life = rise + 1.6
			while os.clock() - t0 < life and parent.Parent do
				local t = os.clock() - t0
				for i, pl in ipairs(plumes) do
					local u = math.clamp(t / (rise * (0.6 + i * 0.05)), 0, 1)
					local fall = math.max(0, t - rise - i * 0.05)
					local y = pl.H * K.easeOut(u) - fall * fall * 30
					local r = pl.R * (0.6 + 0.4 * u) * (1 + fall * 0.8)
					pl.P.Size = Vector3.new(r, r * 1.3, r)
					pl.P.CFrame = CFrame.new(at + pl.Off * (1 + fall) + Vector3.new(0, math.max(0, y), 0))
					pl.P.Transparency = 0.12 + math.clamp(fall / 1.2, 0, 1) * 0.88
				end
				if math.random() < 0.25 then
					K.VFX.Burst(CFrame.new(at + Vector3.new(0, math.random() * height * 0.8, 0)), 4, {
						Speed = NumberRange.new(4, 10), Spread = Vector2.new(90, 90), Color = Color3.fromRGB(240, 250, 255),
						Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 10) }),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
						Lifetime = NumberRange.new(1.2, 2.0), Acceleration = Vector3.new(0, -6, 0),
					})
				end
				K.Step()
			end
			for _, pl in ipairs(plumes) do pl.P:Destroy() end
		end)
	end

	function E.Sight(ctx, sc)
		local root: CFrame = ctx.Root
		local fwd = K.Flat(root.LookVector)
		local right = fwd:Cross(Vector3.yAxis)
		local eye = root.Position + fwd * 2.4 + Vector3.new(0, 3.4, 0)
		-- the river spot you can see best from here (real water first; the column reads either way)
		local at, wy, need = BREACH_SPOTS[1], 0, math.huge
		for _, spot in ipairs(BREACH_SPOTS) do
			local ok, y = K.Water(spot)
			local v = visibleAbove(eye, Vector3.new(spot.X, y, spot.Z)) + (ok and 0 or 40)
			if v < need then at, wy, need = spot, ok and y or 0, v end
		end
		at = Vector3.new(at.X, wy, at.Z)
		local set = K.Stage.new("OmenTideSplash")
		set:Show()
		local fx = Instance.new("Folder")
		fx.Name = "Fx"
		fx.Parent = set.Folder
		local mosa = set:Dino(E.Species, { Scale = 0.9 })
		if not mosa then set:Destroy() return end
		K.Fx.Silhouette(mosa.Model, true, Color3.fromRGB(220, 244, 255))
		local deep = CFrame.new(at + Vector3.new(0, -80, 0))
		mosa.Root.CFrame = deep
		local toward = K.Flat(at - eye)
		local hop = toward:Cross(Vector3.yAxis) -- it leaps across the lens's view, not at it
		-- high enough to clear whatever hills are in the way, with room to spare
		local peak = math.clamp(need - wy + 34, 66, 120)
		sc:Grade("Jungle", 0.01)
		sc:Hush(true)
		local roadLook = eye + fwd * 60 + Vector3.new(0, -1, 0)
		local skyLook = at + Vector3.new(0, peak * 0.62, 0)
		local fovRoad, fovFar = 64, math.clamp(math.deg(2 * math.atan((peak * 0.8) / (at - eye).Magnitude)), 14, 32)
		-- the breach itself runs on its own clock (light first, the boom later)
		local breachAt = 0.5
		local function mosaAt(t: number)
			-- t from launch: up out of the water, hang, roll over and drop
			local up, hang, down = 1.05, 0.55, 0.8
			local h, pitch
			if t < up then
				local u = K.easeOut(t / up)
				h, pitch = -12 + (peak + 12) * u, math.rad(72 - 40 * u)
			elseif t < up + hang then
				local u = (t - up) / hang
				h, pitch = peak + 2 * math.sin(u * math.pi), math.rad(32 - 70 * u)
			else
				local u = math.clamp((t - up - hang) / down, 0, 1)
				h, pitch = peak + 2 - (peak + 16) * K.easeIn(u), math.rad(-38 - 46 * u)
			end
			local side = (t / (1.05 + 0.55 + 0.8)) * 10 - 5
			local p = at + hop * side + Vector3.new(0, h, 0)
			mosa.Root.CFrame = CFrame.lookAt(p, p + hop) * CFrame.Angles(pitch, 0, 0)
			if mosa.Anim then mosa.Anim.HomeCFrame = mosa.Root.CFrame end
		end
		local launched, booms, splashed = false, 0, false
		local skipped = sc:Run(3.6, function(_, t)
			-- the breach
			local bt = t - breachAt
			if bt >= 0 and not launched then
				launched = true
				mosa:Loco("Run", 0.05)
				column(fx, at, peak + 18, 1.1)
			end
			if launched and bt < 2.45 then mosaAt(bt) end
			if launched and bt >= 2.45 and not splashed then
				splashed = true
				mosa.Root.CFrame = deep
				column(fx, at + hop * 5, peak * 0.7, 0.7)
			end
			-- the booms arrive late (it's a long way off)
			if booms == 0 and t > breachAt + 0.35 then
				booms = 1
				K.Audio.Play("Breach", { Volume = 1.4, Pitch = 0.45, Exact = true })
				K.Audio.Play("StompBig", { Volume = 0.9, Pitch = 0.32, Exact = true })
				sc:Shake(0.45, 0.6)
			elseif booms == 1 and t > breachAt + 2.45 + 0.75 then
				booms = 2
				K.Audio.Play("Splash", { Volume = 1.6, Pitch = 0.42, Exact = true })
				K.Audio.Play("SeaRoar", { Volume = 0.5, Pitch = 0.6, Exact = true })
				sc:Shake(0.3, 0.5)
			end
			-- the lens: on the road, then a turn to the sound, then it follows the shape in the sky
			local look, fov
			if t < 0.95 then
				look, fov = roadLook, fovRoad
			elseif t < 1.85 then
				local u = K.smooth((t - 0.95) / 0.9)
				look, fov = roadLook:Lerp(skyLook, u), fovRoad + (fovFar - fovRoad) * u
			else
				local m = launched and not splashed and mosa.Root.Position or skyLook
				look, fov = skyLook:Lerp(m, 0.35), fovFar * (1 - 0.12 * K.smooth((t - 1.85) / 1.2))
			end
			sc:Cam(CFrame.lookAt(eye, look), fov)
		end)
		if skipped then set:Destroy() return end
		-- it rains fish: down on the road around the rover, one onto the bonnet (low on the road ahead, looking back)
		local low = root.Position + fwd * 11 + right * 1.5
		local lowG = K.Ground(low, 10)
		local bonnet = K.RoverTop(ctx, root.Position + fwd * 2.2, 1.35)
		local camP = Vector3.new(low.X, lowG.Y + 1.1, low.Z)
		local drops = {
			{ bonnet, 0.25, true }, { root.Position + right * 3.5 + fwd * 6, 0.0 }, { root.Position - right * 4 + fwd * 7.5, 0.45 },
			{ root.Position + right * 6 + fwd * 1, 0.7 }, { root.Position - right * 6 + fwd * 3, 0.95 }, { root.Position - right * 1.5 + fwd * 8.5, 1.2 },
		}
		local rain = {}
		for i, d in ipairs(drops) do
			local land = d[3] and d[1] or K.Ground(d[1], 10)
			local fi = fish(fx, CFrame.new(land + Vector3.new(0, 40, 0)), d[3] and 1.15 or 0.9 + (i % 3) * 0.12)
			table.insert(rain, { F = fi, Land = land, Start = d[2], Yaw = i * 1.9, Landed = false, Bonnet = d[3] })
		end
		K.VFX.Cubes(root.Position + Vector3.new(0, 26, 0) + fwd * 8, 24, Spray, 0.4, 6, 2.0)
		sc:Grade("Neutral", 0.6)
		local lookAt = bonnet + Vector3.new(0, 1.2, 0)
		sc:Run(2.7, function(_, t)
			for _, r in ipairs(rain) do
				local ft = t - r.Start
				if ft >= 0 and not r.Landed then
					local u = math.clamp(ft / 0.75, 0, 1)
					local h = 40 * (1 - u * u)
					fishTo(r.F, CFrame.new(r.Land + Vector3.new(0, h + 0.3, 0)) * CFrame.Angles(ft * 9, r.Yaw, ft * 5))
					if u >= 1 then
						r.Landed = true
						r.At = t
						K.Audio.Play(r.Bonnet and "Clunk" or "Splash", { At = r.Land, Volume = r.Bonnet and 0.9 or 0.35, Pitch = r.Bonnet and 1.4 or 1.8 })
						K.VFX.WaterSplash(r.Land, 0.35)
						if r.Bonnet then sc:Shake(0.35, 0.25) end
					end
				elseif r.Landed then
					local lt = t - r.At
					local flop = math.max(0, math.sin(lt * 9)) * 0.5 * math.max(0, 1 - lt / 1.6)
					local base = onGround(r.Land, r.Yaw, flop)
					fishTo(r.F, base)
				end
			end
			sc:Cam(CFrame.lookAt(camP, lookAt), 58)
		end)
		set:Destroy()
	end

	----------------------------------------------------------------------------
	-- CLOSE: over the road
	----------------------------------------------------------------------------
	local function waterBeside(route, vi: number, s: number, side: number): (number?, number)
		local hw = route:HalfWidth(vi, s)
		for _, x in ipairs({ hw + 8, hw + 18, hw + 30, hw + 44 }) do
			local ok, y = K.Water(route:Position(vi, s, side * x))
			if ok then return x, y end
		end
		return nil, 0
	end

	function E.Close(ctx): boolean
		local route, vi = ctx.Route, ctx.Vi
		local s0 = ctx.S()
		-- the first stretch ahead with water on both sides of the road
		local sw, xa, xb, wy = nil, 0, 0, 0
		for s = s0 + 140, math.min(route:Length(vi) - 40, s0 + 700), 6 do
			local a, ya = waterBeside(route, vi, s, -1)
			if a then
				local b, yb = waterBeside(route, vi, s, 1)
				if b then sw, xa, xb, wy = s, a, b, math.max(ya, yb) break end
			end
		end
		if not sw then return false end
		local swS = sw :: number
		-- wait for the rover to come up on it
		local launchLead = function() return ctx.Speed() * 0.8 + 26 end
		local waitFrom = os.clock()
		while ctx.Active() and ctx.S() < swS - launchLead() do
			if os.clock() - waitFrom > 30 then return false end
			K.Step()
		end
		if not ctx.Active() or ctx.S() > swS - 12 then return false end
		local side = math.random() < 0.5 and 1 or -1 -- the side it leaps from
		local fromX, toX = (side == 1 and xb or xa) * side, (side == 1 and xa or xb) * -side
		local sLaunch = swS + 6
		local A = route:Position(vi, sLaunch, fromX + side * 6)
		local B = route:Position(vi, sLaunch - 4, toX - side * 6)
		A, B = Vector3.new(A.X, wy, A.Z), Vector3.new(B.X, wy, B.Z)
		local set = K.Stage.new("OmenTideLeap")
		set:Show()
		local mosa = set:Dino(E.Species, { Scale = 0.9 })
		if not mosa then set:Destroy() return false end
		mosa:Loco("Run", 0.05)
		local roadY = route:Sample(vi, swS).Y
		local apex = math.max(roadY + 15, wy + 18)
		local dur = 1.55
		K.VFX.WaterSplash(A, 3)
		K.VFX.Cubes(A, 26, Spray, 0.7, 30, 1.4)
		K.Audio.Play("Breach", { At = A, Volume = 1.3, Pitch = 0.9 })
		local t0 = os.clock()
		local roared = false
		local last = A + Vector3.new(0, -8, 0)
		while os.clock() - t0 < dur do
			local u = (os.clock() - t0) / dur
			local p = A:Lerp(B, u) + Vector3.new(0, (apex - wy + 8) * (1 - (2 * u - 1) ^ 2) - 8, 0)
			local vel = p - last
			if vel.Magnitude > 0.01 then
				mosa.Root.CFrame = CFrame.lookAt(p, p + vel.Unit)
				if mosa.Anim then mosa.Anim.HomeCFrame = mosa.Root.CFrame end
			end
			last = p
			if math.random() < 0.5 then K.VFX.Cubes(p, 2, Spray, 0.45, 4, 1.0) end
			if not roared and u > 0.42 then
				roared = true
				mosa:Act("Attack", 1.3)
				K.Audio.Play("SeaRoar", { At = p, Volume = 1.2, Pitch = 1.0 })
				K.VFX.Shake(0.7, 0.5)
				-- the spray comes down on the road ahead of you
				K.VFX.Cubes(p, 34, Spray, 0.5, 10, 1.6)
			end
			K.Step()
		end
		mosa.Root.CFrame = CFrame.new(B + Vector3.new(0, -80, 0))
		K.VFX.WaterSplash(B, 4)
		K.VFX.Cubes(B, 30, Spray, 0.8, 34, 1.4)
		K.Audio.Play("Splash", { At = B, Volume = 1.5, Pitch = 0.7 })
		K.VFX.Shake(0.8, 0.5, B, 120)
		task.wait(0.8)
		set:Destroy()
		return true
	end

	return E
end
