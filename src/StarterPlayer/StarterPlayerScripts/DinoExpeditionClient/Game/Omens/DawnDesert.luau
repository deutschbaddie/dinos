--[[
	DAWN DESERT — the Dawn King (Postosuchus). Its idea: it's UNDER you, and it's BEHIND you, and the sun is on
	its side.

	  SIGN      IT'S BREATHING: beside the road, a mud wallow in the middle of the dry sand. A drag trench crosses the
	            road into it, crocodile hand-prints either side, a shed back plate. Slow, big bubbles swell and pop.
	            Something down there is breathing.
	  GLIMPSE   THE SHADOW: low sunrise. You're looking at your rover; a shadow - huge, long, four-legged - slides
	            over it and down the road. The lens whips round into the sun: on the rise behind you, black against
	            the sunrise, it rears up onto its hind legs and holds there... drops, turns, and is gone over the crest.
	  CLOSE     SNAP: on the escape, the sand beside the road ahead lifts in a long hump with bubbles popping along
	            its back - and as you draw level it bursts out, jaws slamming shut a hand's width behind your
	            bumper, and sinks away again.
]]

return function(K)
	local E = { Zone = "DawnDesert", Boss = "DawnKing", Species = "Postosuchus" }
	E.Names = { "SIGN", "GLIMPSE", "CLOSE CALL" }
	local Mud, MudWet = Color3.fromRGB(92, 64, 44), Color3.fromRGB(70, 48, 34)
	local Sand, SandDark = Color3.fromRGB(226, 182, 128), Color3.fromRGB(184, 140, 92)
	local Scute = Color3.fromRGB(120, 58, 42)

	-- a four-fingered crocodilian print (hand) pressed into the sand
	local function handPrint(parent: Instance, at: Vector3, dir: Vector3)
		local g = K.Ground(at, 10)
		local cf = CFrame.lookAt(g, g + K.Flat(dir))
		K.Slab(parent, (cf * CFrame.new(0, 0, 0.3)).Position, Vector3.new(1.6, 0.06, 1.4), math.atan2(-dir.X, -dir.Z), { Color = SandDark, Material = Enum.Material.Sand })
		for i = -1.5, 1.5 do
			local toe = cf * CFrame.new(i * 0.55, 0, -0.9 - (1.5 - math.abs(i)) * 0.25)
			K.Slab(parent, toe.Position, Vector3.new(0.34, 0.06, 0.9), math.atan2(-dir.X, -dir.Z) + i * 0.18, { Color = SandDark, Material = Enum.Material.Sand })
		end
	end

	----------------------------------------------------------------------------
	-- SIGN: it's breathing
	----------------------------------------------------------------------------
	function E.Trace(): Folder?
		local route = K.RouteMath.get(E.Zone)
		if not route then return nil end
		local f = K.Props("Omen_DawnDesert")
		local s = 176
		local hw = route:HalfWidth(1, s)
		local p0, fwd, right = route:Sample(1, s)
		local pool = K.Ground(p0 + right * (hw + 13), 12)
		-- the wallow: wet rim, dark mud, a glossy centre
		K.Part(f, { Shape = "Cylinder", Size = Vector3.new(0.1, 17, 15), CFrame = CFrame.new(pool + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0.4, math.pi / 2), Color = SandDark, Material = Enum.Material.Sand })
		K.Part(f, { Shape = "Cylinder", Size = Vector3.new(0.14, 13.5, 11.5), CFrame = CFrame.new(pool + Vector3.new(0, 0.09, 0)) * CFrame.Angles(0, 0.4, math.pi / 2), Color = Mud, Material = Enum.Material.Mud })
		K.Part(f, { Shape = "Cylinder", Size = Vector3.new(0.16, 8, 6.5), CFrame = CFrame.new(pool + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0.9, math.pi / 2), Color = MudWet, Material = Enum.Material.SmoothPlastic, Reflectance = 0.12 })
		-- the drag trench: from the far verge, across the road, into the wallow
		local a = p0 - right * (hw + 18) - fwd * 7
		local b = pool - right * 5
		local d = K.Flat(b - a)
		local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
		local yaw = math.atan2(-d.X, -d.Z)
		local side = d:Cross(Vector3.yAxis)
		local n = math.ceil(len / 6)
		for i = 0, n - 1 do
			local c = a + d * ((i + 0.5) * len / n)
			K.Slab(f, c, Vector3.new(2.6, 0.06, len / n + 0.3), yaw, { Color = SandDark, Material = Enum.Material.Sand, Lift = 0.05 })
			K.Slab(f, c + side * 1.8, Vector3.new(0.7, 0.24, len / n), yaw, { Color = Sand, Material = Enum.Material.Sand })
			K.Slab(f, c - side * 1.8, Vector3.new(0.7, 0.24, len / n), yaw, { Color = Sand, Material = Enum.Material.Sand })
			if i % 2 == 0 and i > 0 and i < n - 1 then
				handPrint(f, c + side * 4.2 * ((i % 4 == 0) and 1 or -1), d)
			end
		end
		-- a shed back plate on the sand by the wallow
		local sp = K.Ground(pool - fwd * 9 - right * 2, 10)
		local plate = CFrame.new(sp + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 1.1, 0.25)
		K.Part(f, { Size = Vector3.new(2.2, 0.35, 2.8), CFrame = plate, Color = Scute, Material = Enum.Material.Slate, Shadow = true })
		K.Part(f, { Class = "WedgePart", Size = Vector3.new(0.4, 0.8, 2.4), CFrame = plate * CFrame.new(0, 0.55, 0), Color = Scute:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Slate, Shadow = true })
		-- the breathing: big slow bubbles, sometimes two in a row
		local nextBubble = 0
		local function bubble(at: Vector3, k: number)
			local b = K.Part(f, { Shape = "Ball", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(at), Color = MudWet, Material = Enum.Material.SmoothPlastic, Reflectance = 0.15 })
			task.spawn(function()
				local t0 = os.clock()
				local grow = 0.9 + math.random() * 0.6
				while os.clock() - t0 < grow and b.Parent do
					local u = (os.clock() - t0) / grow
					local sz = 0.4 + 2.2 * k * K.easeOut(u)
					b.Size = Vector3.new(sz, sz * 0.7, sz)
					b.CFrame = CFrame.new(at + Vector3.new(0, sz * 0.12, 0))
					K.Step()
				end
				if b.Parent then
					K.VFX.BlockRing(CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 10, R0 = 0.6, R1 = 2.6 * k, Block = 0.25, Color = Mud, Transparency = 0.2, Duration = 0.5 })
					K.VFX.Cubes(at + Vector3.new(0, 0.4, 0), 4, { Mud, MudWet }, 0.25, 5, 0.6)
					K.Audio.Play("Splash", { At = at, Volume = 0.3 * k, Pitch = 0.45, Range = 80 })
					b:Destroy()
				end
			end)
		end
		K.Near(f, pool, 130, function()
			if os.clock() > nextBubble then
				nextBubble = os.clock() + 1.8 + math.random() * 1.6
				local at = pool + Vector3.new(math.random() * 5 - 2.5, 0.15, math.random() * 5 - 2.5)
				bubble(at, 1)
				if math.random() < 0.4 then task.delay(0.5, function() bubble(at + Vector3.new(1.5, 0, 0.8), 0.6) end) end
			end
		end)
		return f
	end

	----------------------------------------------------------------------------
	-- GLIMPSE: the shadow
	----------------------------------------------------------------------------
	function E.Sight(ctx, sc)
		local root: CFrame = ctx.Root
		local fwd = K.Flat(root.LookVector)
		local R = root.Position
		local G0 = K.Ground(R, 10)
		local sun = game:GetService("Lighting"):GetSunDirection()
		local h = K.Flat(sun)
		local elev = math.clamp(math.asin(math.clamp(sun.Y, -1, 1)), 0.07, 1.3)
		local set = K.Stage.new("OmenDawnShadow")
		set:Show()
		local dk = set:Dino(E.Species, { Scale = 1.1 })
		if not dk then set:Destroy() return end
		local perp = h:Cross(Vector3.yAxis)
		local H = dk.Size.Y
		-- stand where its body's shadow lands across the rover
		local D = math.clamp((H * 0.55) / math.tan(elev), 12, 80)
		local P = G0 + h * D
		sc:Grade("Dawn", 0.01)
		sc:Hush(true)
		local shadowPass = elev < 0.9
		local skipped = false
		if shadowPass then
			-- 1. looking down at your rover, the sun over your shoulder; then the shadow slides over it
			local eye = R + h * 6 - perp * 3 + Vector3.new(0, 8.5, 0)
			local look = R - h * 6 + Vector3.new(0, -1, 0)
			local from, to = P - perp * 26, P + perp * 26
			dk:Place(K.Floor(from, 30), perp)
			dk:Loco("Walk", 0.01)
			local steps = 0
			sc:Cam(CFrame.lookAt(eye, look), 52)
			skipped = sc:Run(0.6, function() sc:Cam(CFrame.lookAt(eye, look), 52) end)
			if not skipped then
				local dur = 3.0
				skipped = sc:Run(dur, function(u, t, dt)
					local p = K.Floor(from:Lerp(to, u), 30)
					dk:Place(p, perp)
					K.Pace(dk, (to - from).Magnitude / dur, dt)
					if t > steps then
						steps = t + 0.62
						K.Audio.Play("StompBig", { Volume = 0.3, Pitch = 0.5, Exact = true })
						sc:Shake(0.12, 0.2)
					end
					-- the light drops as it passes between you and the sun
					local cover = math.max(0, 1 - math.abs(u - 0.5) / 0.28)
					sc.GradeFx.Brightness = 0.02 - 0.2 * cover
					sc:Cam(CFrame.lookAt(eye, look), 52 - 4 * u)
				end)
			end
		end
		-- 2. whip round into the sun: on the rise behind you, black against the sunrise
		if not skipped then
			-- (the highest point of the real floor: K.Ground hit rocks and hoodoos, so it picked boulder tops)
			local crest, cy = G0 + h * 40, -math.huge
			for d = 26, 90, 4 do
				local g = K.Floor(G0 + h * d, 60)
				if g.Y > cy + 0.5 then crest, cy = g, g.Y end
			end
			if cy < G0.Y - 2 then crest = K.Floor(G0 + h * 36, 60) end
			dk:Place(crest, -h)
			dk:Loco("Idle", 0.01)
			K.Fx.Silhouette(dk.Model, true, Color3.fromRGB(255, 186, 120))
			local eye2 = R + Vector3.new(0, 4.2, 0) - h * 2
			local head = crest + Vector3.new(0, H * 0.8, 0)
			local fov = math.clamp(math.deg(2 * math.atan((H * 2.2) / (head - eye2).Magnitude)), 16, 40)
			local start = sc.Camera.CFrame
			K.Audio.Play("Dodge", { Volume = 0.9, Pitch = 0.7, Exact = true })
			sc:Grade("Backlit", 0.25)
			skipped = sc:Run(0.36, function(u)
				local k = K.smooth(u)
				local cf = start:Lerp(CFrame.lookAt(eye2, head), k)
				sc:Cam(cf, 52 + (fov - 52) * k)
			end)
			if not skipped then
				K.CineKit.SunBurst(0.8)
				sc:Shake(0.35, 0.3)
				-- it rears up onto its hind legs... and holds
				local tr = dk.Anim and dk.Anim:Play("UprightCharge", { Speed = 0.55 })
				K.Audio.Play("Growl", { Volume = 1.1, Pitch = 0.62, Exact = true })
				local held = false
				skipped = sc:Run(2.2, function(u, t)
					if tr and not held and t > 0.9 then
						held = true
						dk.Anim.Paused = true
					end
					sc:Cam(CFrame.lookAt(eye2, head + Vector3.new(0, H * 0.25 * K.smooth(t / 0.9), 0)), fov * (1 - 0.08 * u))
				end)
			end
			-- drops, turns, and is gone over the crest
			if not skipped then
				if dk.Anim then
					dk.Anim.Paused = false
					dk.Anim:StopActions(0.35)
				end
				K.Audio.Play("StompBig", { Volume = 0.8, Pitch = 0.55, Exact = true })
				K.VFX.FootstepDust(crest, 2.2)
				dk:Loco("Walk", 0.2)
				local fovNow = sc.Camera.FieldOfView
				sc:Run(1.6, function(u, t, dt)
					local turn = K.smooth(math.min(1, t / 0.5))
					local away = K.easeIn(math.max(0, (t - 0.35) / 1.25))
					-- over the crest on the real floor (it used to sink 4 studs into the sand), fading as it drops away
					local p = K.Floor(crest + h * 14 * away, 40)
					dk:Place(p, (-h):Lerp(h, turn))
					local gone = math.clamp((away - 0.6) / 0.4, 0, 1)
					if gone > 0 then
						for _, d in ipairs(dk.Model:GetDescendants()) do
							if d:IsA("BasePart") or d:IsA("Decal") then (d :: any).LocalTransparencyModifier = gone end
						end
					end
					K.Pace(dk, 9, dt)
					sc:Cam(CFrame.lookAt(eye2, head:Lerp(crest + Vector3.new(0, H * 0.4, 0), u)), fovNow)
				end)
			end
		end
		set:Destroy()
		local _ = fwd
	end

	----------------------------------------------------------------------------
	-- CLOSE: snap
	----------------------------------------------------------------------------
	function E.Close(ctx): boolean
		local route, vi = ctx.Route, ctx.Vi
		local sa = ctx.S() + 150
		if sa + 60 > route:Length(vi) then return false end
		local hw = route:HalfWidth(vi, sa)
		local side = K.OpenSide(route, vi, sa - 20, sa + 20, hw + 6)
		local _, f = route:Sample(vi, sa)
		local at = K.Floor(route:Position(vi, sa, side * (hw + 4)), 20)
		local set = K.Stage.new("OmenDawnSnap")
		set:Show()
		local fx = Instance.new("Folder")
		fx.Parent = set.Folder
		local dk = set:Dino(E.Species, { Scale = 1.1 })
		if not dk then set:Destroy() return false end
		-- it lies along the verge facing the oncoming rover, head turned in toward the road
		local face = K.Flat(-f - f:Cross(Vector3.yAxis) * side * 0.6)
		dk:Place(at - Vector3.new(0, 30, 0), face) -- out of sight until the hump shows
		-- the hump: sand lifting in a long ridge with bubbles along it
		local hump = K.Part(fx, { Size = Vector3.new(5, 0.2, 14), CFrame = CFrame.lookAt(at, at + face), Color = Sand, Material = Enum.Material.Sand, Shadow = true })
		local humpT, started, bit = 0, false, false
		local track = nil
		local t0 = os.clock()
		while ctx.Active() and os.clock() - t0 < 12 do
			local gap = sa - ctx.S()
			local speed = math.max(20, ctx.Speed())
			-- 1. the hump rises when you're ~2 s out
			if humpT == 0 and gap < speed * 2.0 then
				humpT = os.clock()
				K.Audio.Play("StompBig", { At = at, Volume = 0.6, Pitch = 0.4 })
			end
			if humpT > 0 and not started then
				local u = math.clamp((os.clock() - humpT) / 0.9, 0, 1)
				hump.Size = Vector3.new(5 + u, 0.2 + 1.8 * K.easeOut(u), 14)
				hump.CFrame = CFrame.lookAt(at, at + face) + Vector3.new(0, hump.Size.Y / 2 - 0.3, 0)
				if math.random() < 0.12 then K.VFX.Cubes(at + Vector3.new(math.random() * 4 - 2, 1.5, math.random() * 8 - 4), 2, { Sand, SandDark }, 0.3, 4, 0.8) end
			end
			-- 2. under the hump: buried, mid-ambush, timed so the jaws come up as you draw level
			if not started and gap < speed * 0.86 then
				started = true
				dk:Place(at, face)
				if dk.Anim then
					track = dk.Anim:Play("MudAmbush", { Speed = 1.0 })
					if track then
						track.T = 1.0
						track.EventIndex = 2 -- (its sink-in burst already happened, out of sight)
					end
				end
			end
			if started and not bit and track and track.T >= 1.7 then
				bit = true
				hump:Destroy()
				K.VFX.Debris(at + Vector3.new(0, 1, 0), 2.2, Sand)
				K.VFX.Cubes(at + Vector3.new(0, 2, 0), 30, { Sand, SandDark, Mud }, 0.6, 26, 1.4)
				K.Audio.Play("Breach", { At = at, Volume = 1.0, Pitch = 1.3 })
				task.delay(0.1, function()
					if fx.Parent then
						K.Audio.Play("Snap", { At = at, Volume = 1.4, Pitch = 0.75 })
						K.VFX.BiteImpact(dk:Mouth().Position, 2.0)
						K.VFX.Shake(1.0, 0.45)
						ctx.Knock(-side, 2.5)
					end
				end)
			end
			if bit and gap < -40 then break end
			K.Step()
		end
		-- 3. it sinks back into the sand
		if bit then
			local sinkFrom = dk.Root.CFrame
			local t1 = os.clock()
			while os.clock() - t1 < 1.4 do
				local u = K.easeIn((os.clock() - t1) / 1.4)
				dk.Root.CFrame = sinkFrom - Vector3.new(0, dk.Size.Y * 1.3 * u, 0)
				if math.random() < 0.3 then K.VFX.Cubes(at + Vector3.new(0, 0.5, 0), 3, { Sand, SandDark }, 0.35, 6, 0.8) end
				K.Step()
			end
		end
		set:Destroy()
		return bit
	end

	return E
end
