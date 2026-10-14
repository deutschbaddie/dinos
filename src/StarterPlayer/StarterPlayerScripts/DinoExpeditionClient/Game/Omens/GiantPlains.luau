--[[
	GIANT PLAINS — the Plains Titan (Giganotosaurus). Its idea: SCALE, and patience. It never roars at you here.

	  SIGN      THE TOOTH: a serrated tooth longer than your arm, snapped off and driven into the verge at the end of
	            a fresh furrow, bitten cycad fronds and a split boulder around it. It glints in the low sun.
	  GLIMPSE   THROUGH THE BONES: a locked-off long lens from your bonnet, framed by the Giant Ribcage. Behind the
	            arch a black, rim-lit shape walks across the road, stops dead centre in the bones, turns its head
	            to the lens... the lens creeps in on it. A snort of dust. It walks on. Only footsteps.
	  CLOSE     PACING: on the escape it comes out of the grass beside the road and runs WITH you, matching your
	            speed, closing in, jaws snapping once at your door, then peels off into its own dust.
]]

return function(K)
	local E = { Zone = "GiantPlains", Boss = "Titan", Species = "Giganotosaurus" }
	E.Names = { "SIGN", "GLIMPSE", "CLOSE CALL" }
	local Ivory, IvoryDark = Color3.fromRGB(238, 230, 206), Color3.fromRGB(196, 178, 140)
	local Soil, SoilLip = Color3.fromRGB(104, 78, 50), Color3.fromRGB(176, 140, 88)
	local Frond = { Color3.fromRGB(86, 140, 62), Color3.fromRGB(110, 158, 70) }

	----------------------------------------------------------------------------
	-- SIGN: the tooth
	----------------------------------------------------------------------------
	function E.Trace(): Folder?
		local route = K.RouteMath.get(E.Zone)
		if not route then return nil end
		local f = K.Props("Omen_GiantPlains")
		local s = 168
		local hw = route:HalfWidth(1, s)
		local _, fwd, right = route:Sample(1, s)
		-- the furrow: dragged in from the grass at a slant, ending at the tooth on the verge
		local tip = route:Position(1, s, hw + 4.5)
		local dir = (fwd * -0.55 + right * 0.83).Unit -- the direction it was dragged (away from the road)
		local along = -dir
		for i = 0, 5 do
			local c = tip + dir * (2 + i * 2.6)
			local yaw = math.atan2(-along.X, -along.Z)
			local w = 2.6 - i * 0.22
			K.Slab(f, c, Vector3.new(w, 0.08, 2.9), yaw, { Color = Soil, Material = Enum.Material.Ground })
			K.Slab(f, c + along:Cross(Vector3.yAxis) * (w / 2 + 0.35), Vector3.new(0.7, 0.32, 2.7), yaw + (i % 2) * 0.08, { Color = SoilLip, Material = Enum.Material.Ground })
			K.Slab(f, c - along:Cross(Vector3.yAxis) * (w / 2 + 0.35), Vector3.new(0.7, 0.28, 2.7), yaw - (i % 2) * 0.08, { Color = SoilLip, Material = Enum.Material.Ground })
		end
		-- the tooth: a tapered, curved blade with a serrated back edge, leaning back the way it was dragged
		local g = K.Ground(tip, 12)
		local base = CFrame.lookAt(g, g + along) * CFrame.Angles(math.rad(-22), 0, 0)
		local blade = {
			{ 0.0, Vector3.new(1.7, 1.2, 1.15), IvoryDark },
			{ 1.1, Vector3.new(1.55, 1.2, 1.05), Ivory },
			{ 2.2, Vector3.new(1.3, 1.2, 0.92), Ivory },
			{ 3.25, Vector3.new(1.0, 1.1, 0.78), Ivory },
			{ 4.2, Vector3.new(0.66, 1.0, 0.6), Ivory },
			{ 5.05, Vector3.new(0.34, 0.8, 0.4), Ivory },
		}
		for i, b in ipairs(blade) do
			-- each block curves a little further back (a real tooth hooks inward)
			local cf = base * CFrame.new(0, b[1], -0.06 * i * i) * CFrame.Angles(math.rad(-3 * i), 0, 0)
			K.Part(f, { Size = b[2], CFrame = cf, Color = b[3], Material = Enum.Material.SmoothPlastic, Shadow = true, Name = "TitanTooth" })
			if i >= 2 and i <= 5 then
				-- serrations down the back edge
				K.Part(f, { Size = Vector3.new(b[2].X * 0.7, 0.22, 0.22), CFrame = cf * CFrame.new(0, 0.3, b[2].Z / 2 + 0.06) * CFrame.Angles(math.rad(45), 0, 0), Color = Ivory, Shadow = true })
			end
		end
		K.Slab(f, tip, Vector3.new(3.6, 0.3, 3.6), 0.4, { Color = SoilLip, Material = Enum.Material.Ground }) -- the dirt it's driven into
		-- bitten fronds strewn about, and a boulder split clean in two
		for i = 1, 7 do
			local a = i * 2.1
			local p = tip + right * (2 + math.cos(a) * 5) + fwd * (math.sin(a) * 7)
			K.Slab(f, p, Vector3.new(0.7, 0.08, 3.4 - (i % 3) * 0.7), a, { Color = Frond[(i % 2) + 1], Material = Enum.Material.Grass })
		end
		local rock = tip + right * 6 - fwd * 6
		local rg = K.Ground(rock, 12)
		for side = -1, 1, 2 do
			local cf = CFrame.new(rg) * CFrame.Angles(0, 0.5, 0) * CFrame.new(side * 1.9, 1.5, 0) * CFrame.Angles(0, 0, side * 0.32)
			K.Part(f, { Size = Vector3.new(2.6, 3.4, 4.2), CFrame = cf, Color = Color3.fromRGB(150, 138, 120), Material = Enum.Material.Slate, Shadow = true })
		end
		-- it catches the light every few seconds
		local glintAt = (base * CFrame.new(0, 3.2, -0.5)).Position
		local nextGlint = 0
		K.Near(f, glintAt, 160, function()
			if os.clock() > nextGlint then
				nextGlint = os.clock() + 3.5 + math.random() * 2
				K.Glint(glintAt, 1.4)
			end
		end)
		return f
	end

	----------------------------------------------------------------------------
	-- GLIMPSE: through the bones
	----------------------------------------------------------------------------
	function E.Sight(ctx, sc)
		local route, vi = ctx.Route, ctx.Vi
		local root: CFrame = ctx.Root
		local fwd = K.Flat(root.LookVector)
		local eye = root.Position + fwd * 2.6 + Vector3.new(0, 3.2, 0)
		local crossS = math.max(ctx.S + 150, 175)
		local centre = K.Road(route, vi, crossS, 0)
		local _, rf, rr = route:Sample(vi, crossS)
		local set = K.Stage.new("OmenTitanBones")
		set:Show()
		local giga = set:Dino(E.Species, { Scale = 1.05 })
		if not giga then set:Destroy() return end
		K.Fx.Silhouette(giga.Model, true, Color3.fromRGB(255, 196, 120))
		local fromX, stopX, toX = -30, 0, 34
		local function at(x: number): Vector3 return K.Floor(centre + rr * x, 30) end
		giga:Place(at(fromX), rr)
		giga:Loco("Walk", 0.01)
		local headH = giga.Size.Y * 0.78
		local function lookAt(): Vector3 return centre + Vector3.new(0, headH, 0) end
		sc:Grade("Golden", 0.01)
		sc:Hush(true)
		local fovWide = math.clamp(math.deg(2 * math.atan(30 / (centre - eye).Magnitude)) * 1.35, 18, 34)
		-- 1. the bones, quiet; a far footstep
		local stepAt = 0
		local function footstep(vol: number)
			K.Audio.Play("StompBig", { Volume = vol, Pitch = 0.55, Exact = true })
			sc:Shake(0.18 + vol * 0.2, 0.35)
		end
		sc:Cam(CFrame.lookAt(eye, lookAt()), fovWide)
		task.delay(0.35, function() footstep(0.35) end)
		if sc:Run(0.7, function() sc:Cam(CFrame.lookAt(eye, lookAt()), fovWide) end) then set:Destroy() return end
		-- 2. it walks into the frame from the left and stops dead centre
		local walkDur = 2.0
		local speed = (stopX - fromX) / walkDur
		local skipped = sc:Run(walkDur, function(u, t, dt)
			local x = fromX + (stopX - fromX) * (u < 0.85 and u / 0.85 * 0.92 or 0.92 + (u - 0.85) / 0.15 * 0.08)
			giga:Place(at(x), rr)
			K.Pace(giga, speed, dt)
			if t > stepAt then stepAt = t + 0.78 footstep(0.5) end
			sc:Cam(CFrame.lookAt(eye, lookAt()), fovWide)
		end)
		if skipped then set:Destroy() return end
		giga:Loco("Idle", 0.35)
		-- 3. it turns its head to the lens; the lens creeps in through the ribs
		local toCam = K.Flat(eye - centre)
		local snorted = false
		skipped = sc:Run(2.3, function(u, t)
			local k = K.smooth(math.min(1, t / 0.9))
			local face = rr:Lerp(toCam, k * 0.85)
			giga:Place(at(stopX), face)
			local fov = fovWide + (math.max(7, fovWide * 0.42) - fovWide) * K.smooth(u)
			sc:Cam(CFrame.lookAt(eye + fwd * u * 1.2, lookAt():Lerp(giga:Head(), K.smooth(u) * 0.6)), fov)
			if not snorted and t > 1.45 then
				snorted = true
				local m = giga:Mouth()
				K.VFX.Burst(m * CFrame.new(0, -0.3, -0.6), 14, {
					Speed = NumberRange.new(4, 8), Spread = Vector2.new(25, 25), Direction = Enum.NormalId.Front,
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
					Color = Color3.fromRGB(226, 196, 150), Lifetime = NumberRange.new(0.9, 1.4), Drag = 3,
				})
				K.Audio.Play("Growl", { Volume = 0.9, Pitch = 0.5, Exact = true })
				sc:Shake(0.35, 0.5)
			end
		end)
		if skipped then set:Destroy() return end
		-- 4. it turns away and walks on out of the bones; the dust hangs
		giga:Loco("Walk", 0.3)
		local fov2 = sc.Camera.FieldOfView
		local exitDur = 2.1
		local nextStep = 0.3
		skipped = sc:Run(exitDur, function(u, t, dt)
			local k = K.smooth(math.min(1, t / 0.6))
			local x = stopX + (toX - stopX) * K.easeIn(u) * 0.9
			giga:Place(at(x), toCam:Lerp(rr, k))
			K.Pace(giga, (toX - stopX) / exitDur, dt)
			if t > nextStep then nextStep = t + 0.78 footstep(0.4 * (1 - u * 0.5)) end
			sc:Cam(CFrame.lookAt(eye + fwd * 1.2, lookAt()), fov2 + (fovWide - fov2) * K.smooth(u) * 0.5)
		end)
		if not skipped then
			K.VFX.FootstepDust(at(toX * 0.6), 2.4)
			sc:Run(0.6, function() sc:Cam(CFrame.lookAt(eye + fwd * 1.2, lookAt()), nil) end)
		end
		local _ = rf
		set:Destroy()
	end

	----------------------------------------------------------------------------
	-- CLOSE: pacing the rover
	----------------------------------------------------------------------------
	function E.Close(ctx): boolean
		local route, vi = ctx.Route, ctx.Vi
		local s0 = ctx.S()
		if s0 + 320 > route:Length(vi) then return false end
		local side = K.OpenSide(route, vi, s0 + 60, s0 + 260, 40)
		local set = K.Stage.new("OmenTitanPace")
		set:Show()
		local giga = set:Dino(E.Species, { Scale = 1.05 })
		if not giga then set:Destroy() return false end
		giga:Loco("Run", 0.05)
		local t0 = os.clock()
		local dur = 6.2
		local lastStep, snapped, roared = 0, false, false
		local lastPos: Vector3? = nil
		local burst = route:Position(vi, s0 + 70, side * (route:HalfWidth(vi, s0 + 70) + 46))
		K.CineKit.Burst(K.Ground(burst, 30) + Vector3.new(0, 3, 0), 1.3, { Color3.fromRGB(214, 190, 120), Color3.fromRGB(168, 140, 88) })
		K.Audio.Play("RoarBig", { At = burst, Volume = 1, Pitch = 0.8 })
		while ctx.Active() do
			local t = os.clock() - t0
			if t > dur then break end
			local dt = K.Step()
			local s = ctx.S()
			local hw = route:HalfWidth(vi, s)
			-- lead: starts ahead (you drive up to it), settles level with your door, drops back as it peels away
			-- (kept inside the chase camera's view: it sits ~17 behind you, so alongside means a little ahead)
			local lead, lat, lean = 0, 0, 0
			if t < 3.0 then
				lead = 70 - 54 * K.smooth(t / 3.0)
				lat = hw + 46 - 30 * K.smooth((t - 0.6) / 2.4)
			elseif t < 3.9 then
				local u = math.clamp((t - 3.0) / 0.9, 0, 1)
				lead = 16 - 4 * K.smooth(u)
				lat = hw + 16 - 7 * math.sin(u * math.pi)
				lean = math.sin(u * math.pi) * 0.45 -- the head swings in at your door
			else
				local u = (t - 3.9) / (dur - 3.9)
				lead = 12 - 74 * K.easeIn(u)
				lat = hw + 16 + 64 * K.smooth(u)
			end
			local p, f, r = route:Sample(vi, s + lead)
			local pos = K.Floor(p + r * (side * lat), 30)
			local vel = lastPos and (pos - (lastPos :: Vector3)) / math.max(dt, 1e-3) or f * ctx.Speed()
			local heading = K.Flat(K.Flat(vel.Magnitude > 2 and vel or f):Lerp(-r * side, lean))
			giga:Place(pos, heading)
			K.Pace(giga, vel.Magnitude, dt)
			lastPos = pos
			if t - lastStep > 0.32 then
				lastStep = t
				K.VFX.FootstepDust(pos, 2.2)
				K.Audio.Play("StompBig", { At = pos, Volume = 0.8, Pitch = 0.6, Gap = 0.1 })
				K.VFX.Shake(0.35, 0.25, pos, 90)
			end
			if not snapped and t > 3.25 then
				snapped = true
				giga:Act("Attack", 1.25)
				task.delay(0.4, function()
					if giga.Model.Parent then
						K.Audio.Play("Snap", { At = giga:Head(), Volume = 1.2, Pitch = 0.7 })
						K.VFX.BiteImpact(giga:Mouth().Position, 1.6)
						K.VFX.Shake(0.9, 0.4)
						ctx.Knock(-side, 3)
					end
				end)
			end
			if not roared and t > 4.4 then
				roared = true
				K.Audio.Play("Growl", { At = pos, Volume = 1, Pitch = 0.6 })
				K.VFX.DustWave(pos, -heading, 2.2)
			end
		end
		set:Destroy()
		return true
	end

	return E
end
