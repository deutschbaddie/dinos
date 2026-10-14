--[[
	Frost Forest species effects (Microraptor, Psittacosaurus, Compy, Yutyrannus), registered as DinosaurVFX.Extra events.
	Positions given as { x, y, z } are studs in the creature's RootPart frame (x right, y up, -z forward), scaled with it.

	SnowPuff { At, Scale, Fall }      a puff of powder snow at an attachment (Fall: it drops off a branch instead)
	Iridesce (dur)                    the Microraptor's sheen: a teal-blue-violet shimmer sweeps across its feathers
	PropFallback { Prop, Kind, At, Dur, SnapIn }  the stage prop a signature needs (Branch / Stump / Ferns / Twig / HollowLog); when
	                                  the stage has none (out in the era, a reveal) a temporary one stands in for Dur seconds
	                                  (SnapIn: the stand-in twig snaps after that many seconds)
	RustleProp { Prop }               a prop (ferns, a log) shivers and sheds snow; without one, snow sifts off the dino
	CompySwarm { Count, From, Radius, ChirpIn }  a dozen compies pour out (from a hollow log) and fan out around the
	                                  camera, all chirp at once, then scatter away (client-side stand-ins, self-cleaning)
	Snatch { At }                     a quick grab flash at the mouth (a stolen dart / pickup)
	BreathPlume { Scale, Roar }       frosty breath from the mouth; Roar = a freezing cone of ice-blue breath
	SnowShake { Scale, At }           a cloud of snow shaken off the whole body (or off one attachment)
	Whiteout { Dur, At }              a wall of driving snow around (behind) the dino for Dur seconds
	IceCrack { At, Scale, Ring }      thin ice cracking out from a foot: glowing crack lines, shards, a cold ring
	PineDump { Prop }                 the pines around it shake and dump their snow (the stage's SnowPines, or snow
	                                  falling all around when there is no prop)
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SNOW = { Color3.fromRGB(244, 248, 255), Color3.fromRGB(222, 233, 247), Color3.fromRGB(205, 222, 242) }
local ICE = Color3.fromRGB(150, 215, 245)
local ICE_DEEP = Color3.fromRGB(95, 175, 230)
local BARK = { Color3.fromRGB(91, 66, 50), Color3.fromRGB(110, 81, 64), Color3.fromRGB(138, 100, 72) }
local FERN = { Color3.fromRGB(63, 138, 74), Color3.fromRGB(79, 156, 82) }

return function(VFX)
	local function att(model: Model, name: string): Attachment?
		return VFX.findAttachment(model, name)
	end
	local function scaleK(model: Model): number
		local ok, k = pcall(function() return model:GetScale() end)
		return (ok and typeof(k) == "number") and k or 1
	end
	-- { x, y, z } in the root frame (studs, scaled with the model) -> world
	local function local2world(model: Model, at): Vector3
		local root = model.PrimaryPart
		local cf = root and root.CFrame or model:GetPivot()
		if type(at) ~= "table" then return cf.Position end
		local k = scaleK(model)
		return cf:PointToWorldSpace(Vector3.new((at[1] or 0) * k, (at[2] or 0) * k, (at[3] or 0) * k))
	end
	-- an attachment name or a root-frame offset -> world point
	local function pointOf(model: Model, at, default: string?): Vector3
		if type(at) == "table" then return local2world(model, at) end
		local a = att(model, (type(at) == "string" and at) or default or "VFX_Head")
		if a then return a.WorldPosition end
		return model:GetPivot().Position
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function groundY(model: Model?, p: Vector3): number
		local list: { Instance } = { VFX.Folder() }
		if model then table.insert(list, model) end
		rayParams.FilterDescendantsInstances = list
		local hit = Workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), rayParams)
		return hit and hit.Position.Y or p.Y
	end
	local function anchored(props): Part
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		for k, v in pairs(props) do (p :: any)[k] = v end
		p.Parent = VFX.Folder()
		return p
	end
	local function fadeOut(parts: { BasePart }, after: number, t: number?)
		task.delay(after, function()
			for _, p in ipairs(parts) do
				if p.Parent then TweenService:Create(p, TweenInfo.new(t or 0.6), { Transparency = 1 }):Play() end
			end
			task.delay((t or 0.6) + 0.1, function()
				for _, p in ipairs(parts) do if p.Parent then p:Destroy() end end
			end)
		end)
	end
	-- powder snow: a soft white cloud plus a few white blocks
	local function powder(pos: Vector3, scale: number, fall: boolean?)
		if not VFX.Enabled then return end
		VFX.Burst(CFrame.new(pos), math.floor(6 + scale * 6), {
			Color = SNOW[1], Texture = SMOKE,
			Speed = fall and NumberRange.new(0.5, 2) or NumberRange.new(2 * scale, 6 * scale),
			Spread = fall and Vector2.new(25, 25) or Vector2.new(80, 80),
			Direction = fall and Enum.NormalId.Bottom or Enum.NormalId.Top,
			Acceleration = fall and Vector3.new(0, -9, 0) or Vector3.new(0, 1.5, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * scale), NumberSequenceKeypoint.new(1, 1.8 * scale) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.7, 1.3), LightInfluence = 0.6,
		})
		if not fall then VFX.Cubes(pos, math.floor(2 + scale * 4), SNOW, 0.22 * math.max(0.4, scale), 6 + scale * 5, 0.8) end
	end
	-- snow sifting down over an area for a while
	local function snowfall(center: Vector3, size: Vector3, dur: number, rate: number, flake: number)
		if not VFX.Enabled then return end
		local host = anchored({ Size = size, CFrame = CFrame.new(center), Transparency = 1, CastShadow = false })
		local e = Instance.new("ParticleEmitter")
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Texture = SMOKE
		e.Color = ColorSequence.new(SNOW[1])
		e.LightInfluence = 0.5
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(20, 20)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Acceleration = Vector3.new(0, -14, 0)
		e.Drag = 1.5
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, flake), NumberSequenceKeypoint.new(1, flake * 2.2) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		e.Rate = rate
		e.Parent = host
		task.delay(dur, function() e.Enabled = false end)
		Debris:AddItem(host, dur + 2.5)
	end

	------------------------------------------------------------------------------------------------------------------
	VFX.Extra.SnowPuff = function(model: Model, arg, _s)
		local a = arg or {}
		local pos = pointOf(model, a.At, "VFX_RightFoot")
		powder(pos, (a.Scale or 0.5) * scaleK(model), a.Fall)
	end

	-- the Microraptor's iridescence: a moving teal -> blue -> violet sweep over the sheen feathers (black feathers pick
	-- up a little of it too), sparkles off the wing tips, then everything settles back to glossy black
	local IRIDESCENT = { Sheen = 1, WingTip = 1, WingPrimary = 0.4, WingFeather = 0.35, WingCovert = 0.3, TailFan = 0.35, LegFeather = 0.3 }
	local shimmering: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	VFX.Extra.Iridesce = function(model: Model, arg, _s)
		if not VFX.Enabled then return end
		local dur = (type(arg) == "number" and arg) or 1.0
		local untilT = os.clock() + dur
		if shimmering[model] then
			shimmering[model] = math.max(shimmering[model], untilT)
			return
		end
		shimmering[model] = untilT
		local parts = {}
		local root = model.PrimaryPart
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and IRIDESCENT[d.Name] then
				local lp = root and root.CFrame:PointToObjectSpace(d.Position) or d.Position
				table.insert(parts, { Part = d, Color = d.Color, Material = d.Material, W = IRIDESCENT[d.Name], Phase = lp.X * 1.8 + lp.Z * 1.1 })
			end
		end
		for _, n in ipairs({ "VFX_RightWingTip", "VFX_LeftWingTip", "VFX_TailTip" }) do
			local a = att(model, n)
			if a then VFX.Burst(a.WorldCFrame, 6, { Texture = SPARKLE, Color = Color3.fromRGB(120, 235, 255), LightEmission = 1, Speed = NumberRange.new(1, 3), Size = NumberSequence.new(0.35, 0), Lifetime = NumberRange.new(0.4, 0.8), Acceleration = Vector3.zero }) end
		end
		local t0 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local stop = now >= (shimmering[model] or 0) or not model.Parent
			if stop then
				conn:Disconnect()
				shimmering[model] = nil
				for _, r in ipairs(parts) do
					if r.Part.Parent then
						r.Part.Material = r.Material
						TweenService:Create(r.Part, TweenInfo.new(0.35), { Color = r.Color }):Play()
					end
				end
				return
			end
			local t = now - t0
			local env = math.min(1, t / 0.15)
			for _, r in ipairs(parts) do
				local h = 0.5 + 0.22 * (0.5 + 0.5 * math.sin(t * 9 - r.Phase))
				local c = Color3.fromHSV(h, 0.78, 1)
				r.Part.Color = r.Color:Lerp(c, r.W * env)
				if r.W >= 1 then r.Part.Material = Enum.Material.Neon end
			end
		end)
	end

	-- a stand-in prop when the stage has none
	local function buildFallback(model: Model, kind: string, at): { BasePart }
		local root = model.PrimaryPart
		local cf = root and root.CFrame or model:GetPivot()
		local k = scaleK(model)
		local p = local2world(model, at)
		local yaw = CFrame.lookAt(Vector3.zero, Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z))
		local out = {}
		local function add(props)
			local part = anchored(props)
			table.insert(out, part)
			return part
		end
		if kind == "Branch" then
			-- a frost-dead tree whose branch runs under the perch point
			local trunkAt = p + cf.RightVector * 3.1 * k
			local gy = groundY(model, trunkAt)
			local h = (p.Y - gy) + 2.6 * k
			add({ Name = "Trunk", Size = Vector3.new(1.0, h, 1.0) * Vector3.new(k, 1, k), Color = BARK[1], Material = Enum.Material.Wood, CFrame = CFrame.new(trunkAt.X, gy + h / 2, trunkAt.Z) * yaw })
			add({ Name = "Branch", Size = Vector3.new(4.6 * k, 0.34 * k, 0.42 * k), Color = BARK[2], Material = Enum.Material.Wood, CFrame = CFrame.new(p - Vector3.new(0, 0.17 * k, 0) + cf.RightVector * 0.8 * k) * yaw })
			add({ Name = "SnowCap", Size = Vector3.new(3.6 * k, 0.1 * k, 0.46 * k), Color = SNOW[1], CFrame = CFrame.new(p + Vector3.new(0, 0.05 * k, 0) + cf.RightVector * 0.6 * k) * yaw })
		elseif kind == "Stump" then
			local gy = groundY(model, p)
			local h = math.max(0.3, p.Y - gy)
			add({ Name = "Stump", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.2 * k, 1.2 * k), Color = BARK[1], Material = Enum.Material.Wood, CFrame = CFrame.new(p.X, gy + h / 2, p.Z) * CFrame.Angles(0, 0, math.pi / 2) })
			add({ Name = "SnowCap", Size = Vector3.new(0.6 * k, 0.06 * k, 0.5 * k), Color = SNOW[1], CFrame = CFrame.new(p.X, p.Y + 0.02 * k, p.Z) * yaw })
		elseif kind == "Ferns" then
			for i, off in ipairs({ Vector3.new(-1.3, 0, 0), Vector3.new(1.3, 0, 0.1), Vector3.new(0, 0, -0.8) }) do
				local c = cf:PointToWorldSpace(cf:PointToObjectSpace(p) + off * k)
				local gy = groundY(model, c)
				for j = 1, 5 do
					local a = j * 72 + i * 20
					add({ Name = "FernLeaf", Size = Vector3.new(0.5, 0.12, 1.9) * k, Color = FERN[(j % 2) + 1], CFrame = CFrame.new(c.X, gy, c.Z) * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0.6 * k, -0.85 * k) * CFrame.Angles(math.rad(-32), 0, 0) })
				end
			end
		elseif kind == "Twig" then
			local gy = groundY(model, p)
			add({ Name = "Twig", Size = Vector3.new(1.6, 0.2, 0.2) * k, Color = BARK[3], CFrame = CFrame.new(p.X, gy + 0.1 * k, p.Z) * yaw * CFrame.Angles(0, math.rad(25), 0) })
			add({ Name = "Twig", Size = Vector3.new(0.6, 0.14, 0.14) * k, Color = BARK[3], CFrame = CFrame.new(p.X, gy + 0.12 * k, p.Z) * yaw * CFrame.new(0.35 * k, 0, 0.35 * k) * CFrame.Angles(0, math.rad(-25), 0) })
			add({ Name = "SnowCap", Size = Vector3.new(0.7, 0.06, 0.22) * k, Color = SNOW[1], CFrame = CFrame.new(p.X, gy + 0.23 * k, p.Z) * yaw * CFrame.Angles(0, math.rad(25), 0) })
		elseif kind == "HollowLog" then
			local gy = groundY(model, p)
			local center = CFrame.new(p.X, gy + 0.85 * k, p.Z) * yaw
			for i = 0, 9 do
				local a = (i / 10) * math.pi * 2
				add({ Name = "LogStave", Size = Vector3.new(0.22, 0.52, 5.0) * k, Color = BARK[(i % 2) + 1], Material = Enum.Material.Wood, CFrame = center * CFrame.new(math.cos(a) * 0.78 * k, math.sin(a) * 0.78 * k, 0) * CFrame.Angles(0, 0, a) })
			end
			add({ Name = "SnowCap", Size = Vector3.new(1.1, 0.16, 4.6) * k, Color = SNOW[1], CFrame = center * CFrame.new(0, 0.98 * k, 0.1 * k) })
		end
		return out
	end
	VFX.Extra.PropFallback = function(model: Model, arg, _s)
		if not arg or (arg.Prop and VFX.findProp(model, arg.Prop)) then return end
		local parts = buildFallback(model, arg.Kind or "Stump", arg.At)
		if arg.SnapIn then
			-- a stand-in twig snaps (the stage's real one breaks through BreakProp)
			task.delay(arg.SnapIn, function()
				for _, part in ipairs(parts) do
					if part.Parent then
						part.Anchored = false
						part.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 8, 6 + math.random() * 4, (math.random() - 0.5) * 8)
						part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14
					end
				end
				if parts[1] then powder(parts[1].Position, 0.4) end
			end)
		end
		fadeOut(parts, arg.Dur or 5, 0.5)
	end

	VFX.Extra.RustleProp = function(model: Model, arg, _s)
		local prop = arg and arg.Prop and VFX.findProp(model, arg.Prop)
		if not prop then
			powder(pointOf(model, "VFX_Head") + Vector3.new(0, 1, 0), 0.4 * scaleK(model), true)
			return
		end
		local home = prop:GetPivot()
		task.spawn(function()
			for i = 1, 7 do
				local a = (8 - i) / 7
				prop:PivotTo(home * CFrame.Angles(math.rad((math.random() - 0.5) * 3 * a), 0, math.rad((math.random() - 0.5) * 3 * a)))
				task.wait(0.035)
			end
			prop:PivotTo(home)
		end)
		local cf, size = prop:GetBoundingBox()
		for _ = 1, 2 do
			powder(cf.Position + Vector3.new((math.random() - 0.5) * size.X * 0.6, size.Y * 0.4, (math.random() - 0.5) * size.Z * 0.6), 0.45, true)
		end
	end

	-- the swarm: stand-in compies pour out of the log, fan out around the camera, chirp together, then scatter
	VFX.Extra.CompySwarm = function(model: Model, arg, _s)
		if not VFX.Enabled then return end
		local Animations = require(script.Parent.Parent:WaitForChild("DinosaurAnimations")) :: any
		local a = arg or {}
		local count = a.Count or 11
		local root = model.PrimaryPart
		if not root then return end
		local k = scaleK(model)
		local cf = root.CFrame
		local from = local2world(model, a.From or { 0, 0, 2.6 })
		local cam = Workspace.CurrentCamera
		local lead = cf.Position
		-- the swarm fans out on an arc between the lead and the camera (or in front of it), never onto the lens
		local toward = cam and (cam.CFrame.Position - lead) or (cf.LookVector * 10)
		toward = Vector3.new(toward.X, 0, toward.Z)
		local dist = math.clamp(toward.Magnitude, 4 * k, 40)
		toward = toward.Magnitude > 0.01 and toward.Unit or cf.LookVector
		local side = toward:Cross(Vector3.yAxis)
		local radius = (a.Radius or 7) * k
		local chirpIn = a.ChirpIn or 1.3
		powder(from + cf.LookVector * 1.6 * k, 0.6 * k)
		for i = 1, count do
			task.delay((i - 1) * 0.08, function()
				if not model.Parent then return end
				local m = model:Clone()
				CollectionService:RemoveTag(m, "DinoExpeditionDinosaur")
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("Highlight") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then d:Destroy()
					elseif d:IsA("BasePart") then d.CanCollide, d.CanQuery, d.CanTouch = false, false, false end
				end
				m.Name = "CompySwarmling"
				m:SetAttribute("HerdLeader", nil)
				local sk = 0.78 + math.random() * 0.3
				m:ScaleTo(k * sk)
				m:SetAttribute("AnimScale", k * sk)
				local mr = m.PrimaryPart :: BasePart
				local bb, size = m:GetBoundingBox()
				local lift = mr.Position.Y - (bb.Position.Y - size.Y / 2) -- root height above its feet
				mr.CFrame = CFrame.lookAt(from, from + cf.LookVector) * CFrame.new(0, lift, 0)
				m.Parent = VFX.Folder()
				local anim = Animations.get(m)
				-- where it ends up: spread across the arc, alternating sides, a few right up near the lens
				local u = (i - 0.5) / count
				local ang = (u - 0.5) * math.pi * 1.3
				local r = radius * (0.45 + 0.55 * ((i * 37) % 10) / 10)
				local reach = math.min(dist * 0.7, r)
				local target = lead + toward * (reach * math.cos(ang) * 0.9 + 0.8 * k) + side * (r * math.sin(ang))
				local mouth = from + cf.LookVector * 2.4 * k
				local gyA, gyB = groundY(nil, mouth), groundY(nil, target)
				local runT = 0.7 + math.random() * 0.45
				if anim then anim:SetLocomotion("Run", 0.1) end
				local t0 = os.clock()
				local last = from
				local conn: RBXScriptConnection
				conn = RunService.RenderStepped:Connect(function()
					if not m.Parent then
						conn:Disconnect()
						return
					end
					local t = os.clock() - t0
					local p: Vector3
					if t < 0.22 then
						local e = t / 0.22
						p = from:Lerp(mouth, e)
						p = Vector3.new(p.X, gyA, p.Z)
					else
						local e = math.min(1, (t - 0.22) / runT)
						local s = 1 - (1 - e) ^ 2
						-- a curving run: bow out to the side on the way
						local mid = mouth:Lerp(target, 0.5) + side * math.sin(ang) * 1.5 * k
						local q1 = mouth:Lerp(mid, s)
						local q2 = mid:Lerp(target, s)
						p = q1:Lerp(q2, s)
						p = Vector3.new(p.X, gyA + (gyB - gyA) * s, p.Z)
						if e >= 1 then
							conn:Disconnect()
							if anim then anim:SetLocomotion("Idle", 0.15) end
							-- face the camera (or the lead), twitch, chirp with the others
							local look = cam and Vector3.new(cam.CFrame.Position.X, p.Y, cam.CFrame.Position.Z) or lead
							mr.CFrame = CFrame.lookAt(p, look) * CFrame.new(0, lift, 0)
							local left = chirpIn - (os.clock() - t0) - (i - 1) * 0.08
							task.delay(math.max(0, left) + math.random() * 0.2, function()
								if anim and m.Parent then anim:Play("Roar") end
							end)
							-- then they scatter away and fade
							task.delay(math.max(0, left) + 1.9 + math.random() * 0.5, function()
								if not m.Parent then return end
								if anim then anim:SetLocomotion("Run", 0.1) end
								local away = (p - lead)
								away = Vector3.new(away.X, 0, away.Z)
								away = away.Magnitude > 0.01 and away.Unit or side
								local s0 = mr.CFrame
								local tt0 = os.clock()
								local c2: RBXScriptConnection
								c2 = RunService.RenderStepped:Connect(function()
									local tt = os.clock() - tt0
									if not m.Parent or tt > 1.0 then
										c2:Disconnect()
										if m.Parent then m:Destroy() end
										return
									end
									local q = s0.Position + away * tt * 14 * k
									mr.CFrame = CFrame.lookAt(q, q + away)
									if tt > 0.6 then
										for _, d in ipairs(m:GetDescendants()) do
											if d:IsA("BasePart") and d.Transparency < 1 then d.LocalTransparencyModifier = (tt - 0.6) / 0.4 end
										end
									end
								end)
							end)
							return
						end
					end
					local dir = p - last
					dir = Vector3.new(dir.X, 0, dir.Z)
					if dir.Magnitude > 0.001 then mr.CFrame = CFrame.lookAt(p, p + dir) * CFrame.new(0, lift, 0) end
					last = p
				end)
				task.delay(chirpIn + 5, function() if m.Parent then m:Destroy() end end)
			end)
		end
	end

	VFX.Extra.Snatch = function(model: Model, arg, _s)
		if not VFX.Enabled then return end
		local pos = pointOf(model, arg and arg.At, "VFX_Mouth")
		VFX.Burst(CFrame.new(pos), 8, { Texture = SPARKLE, Color = Color3.fromRGB(255, 220, 90), LightEmission = 1, Speed = NumberRange.new(2, 5), Size = NumberSequence.new(0.4, 0), Lifetime = NumberRange.new(0.3, 0.6), Acceleration = Vector3.zero })
		VFX.Cubes(pos, 3, { Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 220, 90) }, 0.15, 6, 0.5)
	end

	-- frosty breath from the mouth (a Roar = a freezing cone of ice-blue breath with crystals)
	VFX.Extra.BreathPlume = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local a = arg or {}
		local mouth = att(model, "VFX_Mouth")
		if not mouth then return end
		local head = att(model, "VFX_Head")
		local dir = head and (mouth.WorldPosition - head.WorldPosition) or mouth.WorldCFrame.LookVector
		dir = dir.Magnitude > 0.01 and dir.Unit or mouth.WorldCFrame.LookVector
		local sc = (a.Scale or 1) * math.max(0.6, s / 3)
		local cf = CFrame.lookAt(mouth.WorldPosition, mouth.WorldPosition + dir)
		VFX.Burst(cf, math.floor(6 + sc * (a.Roar and 10 or 4)), {
			Color = a.Roar and Color3.fromRGB(215, 238, 255) or SNOW[1], Texture = SMOKE, Direction = Enum.NormalId.Front,
			Speed = a.Roar and NumberRange.new(14 * sc, 26 * sc) or NumberRange.new(2 * sc, 5 * sc),
			Spread = a.Roar and Vector2.new(22, 22) or Vector2.new(14, 14),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * sc), NumberSequenceKeypoint.new(1, (a.Roar and 6 or 3) * sc) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, a.Roar and 0.25 or 0.45), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.9, 1.6), Drag = a.Roar and 2.5 or 1.5, Acceleration = Vector3.new(0, 1.2, 0), LightInfluence = 0.5,
		})
		if a.Roar then
			VFX.BlockRing(cf, { Count = 16, R0 = 0.6 * sc, R1 = 5 * sc, Travel = 10 * sc, Block = 0.4 * sc, Color = ICE, Transparency = 0.25, Duration = 0.7 })
			for _ = 1, math.floor(6 + sc * 3) do
				local p = anchored({ Size = Vector3.new(0.3, 0.3, 0.3) * sc * (0.6 + math.random() * 0.6), Color = math.random() < 0.5 and ICE or SNOW[1], Material = Enum.Material.Glass, Transparency = 0.2, CastShadow = false, CFrame = cf * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6) })
				p.Anchored = false
				local d = (dir + Vector3.new((math.random() - 0.5) * 0.5, (math.random() - 0.2) * 0.4, (math.random() - 0.5) * 0.5)).Unit
				p.AssemblyLinearVelocity = d * (18 + math.random() * 14) * math.sqrt(sc)
				Debris:AddItem(p, 1.1)
			end
		end
	end

	-- shaking the snow off: powder bursts all over the body, blocks of snow thrown off
	VFX.Extra.SnowShake = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local a = arg or {}
		local sc = (a.Scale or 1) * math.max(0.5, s / 3)
		if a.At then
			powder(pointOf(model, a.At), sc)
			return
		end
		local cf, size = model:GetBoundingBox()
		for _, off in ipairs({ Vector3.new(0, 0.25, 0), Vector3.new(0, 0.3, -0.3), Vector3.new(0, 0.2, 0.3), Vector3.new(0.4, 0.05, 0), Vector3.new(-0.4, 0.05, 0), Vector3.new(0, 0.4, -0.15) }) do
			local p = cf:PointToWorldSpace(off * size)
			VFX.Burst(CFrame.new(p), math.floor(5 + sc * 5), {
				Color = SNOW[1], Texture = SMOKE, Speed = NumberRange.new(4 * sc, 10 * sc), Spread = Vector2.new(120, 120),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * sc), NumberSequenceKeypoint.new(1, 4 * sc) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(1.0, 1.8), Drag = 2, Acceleration = Vector3.new(0, -2, 0), LightInfluence = 0.5,
			})
			VFX.Cubes(p, math.floor(2 + sc * 2), SNOW, 0.3 * sc, 10 + sc * 4, 1.0)
		end
		VFX.Shake(0.25 * sc, 0.4, cf.Position, 60 * sc)
	end

	-- a wall of driving snow around (and behind) the dino
	VFX.Extra.Whiteout = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local a = arg or {}
		local dur = a.Dur or 2.5
		local root = model.PrimaryPart
		local cf = root and root.CFrame or model:GetPivot()
		local _, size = model:GetBoundingBox()
		local center = local2world(model, a.At or { 0, 0, 0 })
		local box = Vector3.new(math.max(size.X, size.Z) * 1.4, size.Y * 1.5, math.max(size.X, size.Z) * 1.4)
		local host = anchored({ Size = box, CFrame = CFrame.new(center + Vector3.new(0, box.Y * 0.35, 0)) * (cf - cf.Position), Transparency = 1, CastShadow = false })
		local wind = cf.RightVector * 12
		for _, spec in ipairs({ { Size = 6, Rate = 70, T = 0.35, Speed = 6 }, { Size = 0.5, Rate = 160, T = 0.0, Speed = 14 } }) do
			local e = Instance.new("ParticleEmitter")
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.Texture = SMOKE
			e.Color = ColorSequence.new(SNOW[1])
			e.LightInfluence = 0.4
			e.Lifetime = NumberRange.new(1.0, 1.8)
			e.Speed = NumberRange.new(spec.Speed * 0.5, spec.Speed)
			e.SpreadAngle = Vector2.new(30, 30)
			e.EmissionDirection = Enum.NormalId.Right
			e.Acceleration = wind - Vector3.new(0, 3, 0)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.Size * math.max(0.6, s / 3)), NumberSequenceKeypoint.new(1, spec.Size * 1.6 * math.max(0.6, s / 3)) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, spec.T), NumberSequenceKeypoint.new(1, 1) })
			e.Rate = spec.Rate
			e.Parent = host
			e:Emit(math.floor(spec.Rate * 0.6))
			task.delay(dur, function() e.Enabled = false end)
		end
		Debris:AddItem(host, dur + 2.2)
	end

	-- thin ice cracking under a foot: glowing jagged lines racing out, shards popping up, a cold ring
	VFX.Extra.IceCrack = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local a = arg or {}
		local foot = pointOf(model, a.At, "VFX_RightFoot")
		local sc = (a.Scale or 1) * math.max(0.6, s / 3)
		local gy = groundY(model, foot)
		local base = Vector3.new(foot.X, gy + 0.04, foot.Z)
		local parts = {}
		local n = 7 + math.floor(sc * 2)
		for i = 1, n do
			local ang = (i / n) * math.pi * 2 + math.random() * 0.4
			local p0 = base
			for seg = 1, 3 do
				local len = (1.4 + math.random() * 1.8) * sc * (1 - (seg - 1) * 0.2)
				ang += (math.random() - 0.5) * 0.7
				local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
				local p1 = p0 + dir * len
				local c = anchored({ Name = "IceCrack", Size = Vector3.new(0.14 * sc, 0.05, 0.01), Color = Color3.fromRGB(235, 250, 255), Material = Enum.Material.Neon, Transparency = 0.1, CastShadow = false, CFrame = CFrame.lookAt(p0, p1) * CFrame.new(0, 0, -len / 2) })
				task.delay((seg - 1) * 0.07, function()
					if c.Parent then TweenService:Create(c, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Size = Vector3.new(0.14 * sc, 0.05, len) }):Play() end
				end)
				table.insert(parts, c)
				p0 = p1
			end
		end
		if a.Ring then
			VFX.BlockRing(CFrame.new(base + Vector3.new(0, 0.15, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 22, R0 = 1.5 * sc, R1 = 9 * sc, Block = 0.45 * sc, Color = ICE, Transparency = 0.3, Duration = 0.7 })
		end
		VFX.BlockRing(CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 14, R0 = 0.8 * sc, R1 = 4.5 * sc, Block = 0.3 * sc, Color = SNOW[1], Transparency = 0.4, Duration = 0.5 })
		VFX.Cubes(base, math.floor(5 + sc * 3), { ICE, ICE_DEEP, SNOW[1] }, 0.28 * sc, 10 + sc * 3, 1.0)
		powder(base, 0.6 * sc)
		VFX.Shake(0.35 * sc, 0.4, base, 60 * sc)
		fadeOut(parts, 2.4, 0.8)
	end

	-- the pines dump their snow: each tree shivers, its snow caps vanish and come down in a cloud
	VFX.Extra.PineDump = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local prop = arg and arg.Prop and VFX.findProp(model, arg.Prop)
		local here = model:GetPivot().Position
		if not prop then
			-- out in the forest: snow comes down all around it
			local _, size = model:GetBoundingBox()
			local r = math.max(size.X, size.Z) * 0.9
			for i = 1, 6 do
				local ang = i / 6 * math.pi * 2
				local p = here + Vector3.new(math.cos(ang) * r, size.Y * 0.9, math.sin(ang) * r)
				task.delay(i * 0.1, function() snowfall(p, Vector3.new(6, 2, 6) * math.max(0.6, s / 3), 1.2, 60, 1.2) end)
			end
			return
		end
		local trees = {}
		for _, t in ipairs(prop:GetChildren()) do
			if t:IsA("Model") then table.insert(trees, { Model = t, D = (t:GetPivot().Position - here).Magnitude }) end
		end
		table.sort(trees, function(x, y) return x.D < y.D end)
		for i, tr in ipairs(trees) do
			task.delay(0.08 * i, function()
				local m = tr.Model
				if not m.Parent then return end
				local home = m:GetPivot()
				task.spawn(function()
					for j = 1, 8 do
						local amp = (9 - j) / 8
						m:PivotTo(home * CFrame.Angles(math.rad((math.random() - 0.5) * 4 * amp), 0, math.rad((math.random() - 0.5) * 4 * amp)))
						task.wait(0.04)
					end
					m:PivotTo(home)
				end)
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") and d.Name == "SnowCap" and d.Transparency < 1 then
						local orig = d.Transparency
						local pos = d.Position
						d.Transparency = 1
						-- the cap comes down as a falling cloud plus a few chunks
						VFX.Burst(CFrame.new(pos), 6, {
							Color = SNOW[1], Texture = SMOKE, Speed = NumberRange.new(1, 4), Spread = Vector2.new(60, 60), Direction = Enum.NormalId.Bottom,
							Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d.Size.X * 0.5), NumberSequenceKeypoint.new(1, d.Size.X * 1.1) }),
							Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
							Lifetime = NumberRange.new(1.2, 2.0), Acceleration = Vector3.new(0, -12, 0), Drag = 1, LightInfluence = 0.5,
						})
						VFX.Cubes(pos, 2, SNOW, math.min(1.2, d.Size.X * 0.25), 4, 1.2)
						task.delay(6.5, function()
							if d.Parent then TweenService:Create(d, TweenInfo.new(1.0), { Transparency = orig }):Play() end
						end)
					end
				end
			end)
		end
		VFX.Shake(0.5, 0.6, here, 120)
	end
end
