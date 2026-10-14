-- Spine River reveal beats (loaded by EraView: returns function(BEATS, REVEAL, H)).
--
-- SARCOSUCHUS — "logs": four logs drift on dark water. The camera checks them one by one, close and low: bark,
-- moss, birds lifting off one, another rolling lazily in the current. Nothing. The last one... its eyes come up
-- out of the water. It blinks. Then the reveal lifts it out of the river, jaws gaping, hissing.
-- Works in the river water set (ctx.WaterY) and on location: with no WaterY it finds a DinoWater surface at the
-- site, and with none at all the "logs" lie in the mud.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local BARK = { Color3.fromRGB(94, 65, 40), Color3.fromRGB(107, 74, 43), Color3.fromRGB(125, 87, 51), Color3.fromRGB(86, 60, 38) }
local MOSS = Color3.fromRGB(95, 143, 62)
local HEART = Color3.fromRGB(201, 154, 98)

return function(BEATS, REVEAL, H)
	REVEAL.Sarcosuchus = { Kick = "THE LOG THAT ISN'T", Beat = "logs", Act = { "Hiss", "Roar" }, Hero = "Low" }

	-- the water surface at a point: the set's own height, else a DinoWater part over it, else the ground
	local function waterAt(ctx, p: Vector3): (number, boolean)
		if ctx.WaterY then return ctx.WaterY, true end
		for _, d in ipairs(CollectionService:GetTagged("DinoWater")) do
			if d:IsA("BasePart") then
				local lp = d.CFrame:PointToObjectSpace(p)
				if math.abs(lp.X) <= d.Size.X / 2 and math.abs(lp.Z) <= d.Size.Z / 2 and math.abs(lp.Y) < 60 then
					return d.Position.Y + d.Size.Y / 2, true
				end
			end
		end
		return H.ground(p).Y, false
	end

	-- a big drifting log lying along `dir`, half awash: trunk segments, bark rings, cut end, moss, a snapped branch
	local function makeLog(set: Instance, at: Vector3, dir: Vector3, len: number, d: number, seed: number): { BasePart }
		local parts = {} :: { BasePart }
		local base = CFrame.lookAt(at, at + dir) * CFrame.Angles(0, math.pi / 2, (seed % 3 - 1) * 0.05)
		local n = math.max(3, math.floor(len / 2.2))
		local seg = len / n
		for i = 0, n - 1 do
			local x = -len / 2 + seg * (i + 0.5)
			table.insert(parts, H.prop(set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(seg + 0.02, d - i * 0.04, d - i * 0.04), Color = BARK[(i + seed) % #BARK + 1], Material = Enum.Material.Wood, CFrame = base * CFrame.new(x, 0, 0) }))
			if i % 2 == 1 then
				table.insert(parts, H.prop(set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, d + 0.12 - i * 0.04, d + 0.12 - i * 0.04), Color = Color3.fromRGB(78, 52, 32), CFrame = base * CFrame.new(x - seg / 2, 0, 0) }))
			end
		end
		table.insert(parts, H.prop(set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, d * 0.86, d * 0.86), Color = HEART, CFrame = base * CFrame.new(-len / 2 - 0.03, 0, 0) }))
		table.insert(parts, H.prop(set, { Size = Vector3.new(len * 0.35, 0.22, d * 0.55), Color = MOSS, Material = Enum.Material.Grass, CFrame = base * CFrame.new(-len * 0.12, d / 2 - 0.02, 0) }))
		table.insert(parts, H.prop(set, { Size = Vector3.new(0.45, 1.5, 0.45), Color = BARK[1], Material = Enum.Material.Wood, CFrame = base * CFrame.new(len * 0.18, d / 2 + 0.55, 0.1) * CFrame.Angles(0.3, 0, 0.45) }))
		return parts
	end

	-- move a group of parts by an offset (and an optional roll about their own centre line)
	local function shiftParts(parts: { BasePart }, home: { [BasePart]: CFrame }, off: Vector3, rot: CFrame?)
		local c = Vector3.zero
		for _, p in ipairs(parts) do c += home[p].Position end
		c /= math.max(1, #parts)
		for _, p in ipairs(parts) do
			if p.Parent then
				local h = home[p]
				if rot then
					local rel = h.Position - c
					p.CFrame = CFrame.new(c + rot:VectorToWorldSpace(rel) + off) * rot * h.Rotation
				else
					p.CFrame = h + off
				end
			end
		end
	end

	BEATS.logs = function(ctx, skipped)
		local cam = Workspace.CurrentCamera
		local F, S = ctx.Face, ctx.Side
		local mark = Vector3.new(ctx.Mark.X, 0, ctx.Mark.Z)
		local wy, wet = waterAt(ctx, ctx.Mark)
		local up = Vector3.new(0, wy, 0)
		-- the river current runs along Side: everything drifts with it
		local flow = S * 0.7

		-- it plays the log: no black silhouette giving it away (the dusk grade does the mood), lying along the
		-- current, floating with only its back and (soon) its eyes at the surface
		for _, h in ipairs(ctx.Model:GetChildren()) do
			if h:IsA("Highlight") and h.FillTransparency < 0.5 then h.Enabled = false end
		end
		local crocAt = mark - S * 3
		ctx.Teleport(crocAt, S)
		if ctx.Anim and ctx.Anim:HasAction("Lurk") then
			local tr = ctx.Anim:Play("Lurk", { Loop = true })
			if tr then tr.Loop = true end
		end
		RunService.Heartbeat:Wait()
		local function eyeY(): number
			local a = H.DinosaurVFX.findAttachment(ctx.Model, "VFX_RightEye")
			return a and a.WorldPosition.Y or ctx.Head().Y
		end
		-- eyes just under the surface for now (the drift loop keeps them there while the float pose settles in)
		ctx.Root.CFrame += Vector3.new(0, (wy - 0.2) - eyeY(), 0)
		local crocHome = ctx.Root.CFrame
		local lift = 0

		-- three real logs, scattered on the water between us and it
		local size = math.clamp(ctx.Size, 20, 40)
		local d = math.clamp(size * 0.07, 1.6, 2.6)
		local defs = {
			{ mark + F * (size * 0.45) + S * (size * 0.3), S + F * 0.25, size * 0.42, 1 },
			{ mark + F * (size * 0.34) - S * (size * 0.36), S - F * 0.15, size * 0.48, 2 },
			{ mark + F * (size * 0.18) + S * (size * 0.45), S + F * 0.1, size * 0.38, 3 },
		}
		local logs = {}
		for _, def in ipairs(defs) do
			local at = def[1] + up + Vector3.new(0, wet and -d * 0.12 or d * 0.45, 0)
			local parts = makeLog(ctx.Set, at, def[2].Unit, def[3], d, def[4])
			local home = {}
			for _, p in ipairs(parts) do home[p] = p.CFrame end
			table.insert(logs, { Parts = parts, Home = home, At = at, Dir = def[2].Unit, Len = def[3], Roll = nil :: CFrame? })
		end

		-- everything drifts with the current for the whole beat (logs bob; one rolls when we look at it)
		local t0 = os.clock()
		local alive = true
		task.spawn(function()
			while alive and not skipped() do
				local t = os.clock() - t0
				for i, l in ipairs(logs) do
					local bob = wet and math.sin(t * 1.4 + i * 1.7) * 0.07 or 0
					shiftParts(l.Parts, l.Home, flow * t + Vector3.new(0, bob, 0), l.Roll)
				end
				if ctx.Root.Parent then
					-- hold the eyes at their mark on the surface (just under it, until they come up)
					local want = wy - 0.2 + (ctx.EyesUp or 0)
					lift += (want - eyeY()) * 0.35
					ctx.Root.CFrame = crocHome + flow * t + Vector3.new(0, lift, 0)
				end
				RunService.RenderStepped:Wait()
			end
		end)
		local function logPos(i: number): Vector3
			return logs[i].At + flow * (os.clock() - t0)
		end
		-- each log is checked from just off one of its ends, looking back along it (cut end and bark up close)
		local function endView(i: number, sign: number, out: number): (() -> Vector3, Vector3)
			local l = logs[i]
			local aim = l.Dir * (l.Len * 0.12 * sign)
			return function() return logPos(i) + aim end, l.Dir * (sign * (l.Len / 2 + out)) - aim + F * out + Vector3.new(0, 1.1, 0)
		end
		-- a close check on something that drifts: the camera rides along with it
		local function check(target: () -> Vector3, offset: Vector3, push: Vector3, dur: number, fovA: number, fovB: number)
			local t1 = os.clock()
			while os.clock() - t1 < dur and not skipped() do
				local u = (os.clock() - t1) / dur
				local e = u * u * (3 - 2 * u)
				local p = target()
				local eye = p + offset + push * e
				eye = Vector3.new(eye.X, math.max(eye.Y, wy + 0.5), eye.Z)
				cam.CFrame = CFrame.lookAt(eye, p) * CFrame.Angles(math.noise(u * 3, 1.3) * 0.01, math.noise(u * 3, 4.1) * 0.012, 0)
				cam.FieldOfView = fovA + (fovB - fovA) * e
				RunService.RenderStepped:Wait()
			end
		end

		-- 1. the water, the logs. still. (a low wide drifting with them)
		local wideAt = H.clearSpot({
			mark + F * (size * 0.95) - S * (size * 0.15) + up + Vector3.new(0, 3.2, 0),
			mark + F * (size * 0.8) + S * (size * 0.2) + up + Vector3.new(0, 3.6, 0),
			mark + F * (size * 0.7) + up + Vector3.new(0, 4.5, 0),
		}, { mark + up }, { ctx.Model })
		local look = mark + F * (size * 0.25) + up
		check(function() return look + flow * (os.clock() - t0) end, wideAt - look, -F * 1.5, 1.1, 46, 43)
		if skipped() then
			alive = false
			return
		end

		-- 2. the near log: bark, moss... nothing
		local t1, o1 = endView(1, 1, 3.5)
		check(t1, o1, -F * 1.2, 0.6, 40, 36)
		if skipped() then
			alive = false
			return
		end

		-- 3. the next: a couple of birds lift off it. nothing
		H.birdsUp(ctx.Set, logPos(2) + Vector3.new(0, d * 0.6, 0), 3, 3)
		local t2, o2 = endView(2, -1, 3.5)
		check(t2, o2, -F * 1.2, 0.6, 40, 36)
		if skipped() then
			alive = false
			return
		end

		-- 4. the third rolls lazily over in the current. a slap of water. nothing
		task.spawn(function()
			local r0 = os.clock()
			while alive and os.clock() - r0 < 0.6 do
				local u = (os.clock() - r0) / 0.6
				logs[3].Roll = CFrame.fromAxisAngle(S, math.sin(u * math.pi) * 0.5)
				RunService.RenderStepped:Wait()
			end
			logs[3].Roll = nil
		end)
		if wet then H.DinosaurVFX.WaterSplash(logPos(3) + Vector3.new(0, 0.1, 0), 0.4) end
		local t3, o3 = endView(3, 1, 3)
		check(t3, o3, -F * 1.0, 0.55, 40, 36)
		if skipped() then
			alive = false
			return
		end

		-- 5. the last log. low on the water, slow push toward its front end... the eyes come up. it BLINKS.
		local function eyePos(): Vector3
			local a = H.DinosaurVFX.findAttachment(ctx.Model, "VFX_LeftEye") or H.DinosaurVFX.findAttachment(ctx.Model, "VFX_RightEye")
			return a and a.WorldPosition or ctx.Head()
		end
		local camSide = (F + S * 0.35).Unit -- a little ahead of its face, looking back along the snout
		task.delay(0.35, function()
			if not alive then return end
			local e0 = os.clock()
			while alive and os.clock() - e0 < 0.5 do
				local u = (os.clock() - e0) / 0.5
				ctx.EyesUp = 0.42 * (1 - (1 - u) ^ 2)
				RunService.RenderStepped:Wait()
			end
			if H.DinosaurVFX.Extra and H.DinosaurVFX.Extra.EyeRipple then H.DinosaurVFX.Extra.EyeRipple(ctx.Model, { Scale = 1 }, 1) end
		end)
		task.delay(1.12, function()
			if not alive then return end
			-- the blink: lids down for a beat, then open (the animator's own lid state, so its blinking agrees)
			if ctx.Anim then ctx.Anim.EyesClosed = true end
			task.delay(0.16, function() if ctx.Anim then ctx.Anim.EyesClosed = false end end)
		end)
		check(function()
			local p = eyePos()
			return Vector3.new(p.X, math.max(p.Y, wy + 0.1), p.Z)
		end, camSide * 6.8 + Vector3.new(0, 0.55, 0), -camSide * 2.8, 1.75, 32, 24)
		alive = false
		if skipped() then return end

		-- set up the reveal: square on to us at the mark, sunk to the eyes; the reveal lifts it out with the spray
		if ctx.Anim then ctx.Anim:StopActions(0.05) end
		ctx.EyesUp = nil
		ctx.Teleport(mark, F)
		for _ = 1, 6 do RunService.Heartbeat:Wait() end
		if wet then
			ctx.Root.CFrame += Vector3.new(0, (wy + 0.1) - eyeY(), 0)
			ctx.Rise = 0.5
			ctx.Breach = true
		end
		H.DinosaurVFX.WaterSplash(Vector3.new(ctx.Mark.X, wy, ctx.Mark.Z), 0.6)
	end
end
