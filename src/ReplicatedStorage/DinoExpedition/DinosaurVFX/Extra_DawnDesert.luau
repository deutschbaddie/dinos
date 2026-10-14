--[[
	Dawn Desert species effects (Coelophysis, Plateosaurus, Dilophosaurus, Postosuchus), registered as
	DinosaurVFX.Extra events. All client-side and self-cleaning.

	Ripple { Scale }                  rings spreading on the water (or dust on dry ground) under the mouth: drinking
	PackCue { Action, Stagger }       its pack / partner (models with HerdLeader = this model's name, the showcase's
	                                  pack-mates included) play Action together, Stagger seconds apart
	CrestFlush (dur | { Dur })        the Dilophosaurus crests flush bright: plates turn hot neon orange-red and glow
	SpitGlob { Splat, Range, Scale }  a green glob of spit arcs out of the mouth; with Splat it flies at the camera
	                                  when the camera is in front of it within Range and splats across the screen
	                                  (drips run down, then it clears); otherwise it lands in a hissing puddle
	DustRing { Scale }                a big ring of dust rolling out from its feet (a heavy slam)
	MudBubble { Scale }               mud bubbles swelling and popping over a buried body
	MudBurst { Scale, Spray }         an eruption of mud clods out of the ground; Spray = flung off the body as it shakes
	HealPulse { Scale }               a soft green pulse of leaves and sparkles rising around it (the Forager)
	TerrorWave { Scale }              a dark shock ring rolling over the ground (the ruler's terror roar)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST = Color3.fromRGB(214, 160, 110)
local SAND = { Color3.fromRGB(227, 165, 96), Color3.fromRGB(201, 132, 74), Color3.fromRGB(184, 87, 58) }
local MUD = { Color3.fromRGB(107, 70, 48), Color3.fromRGB(86, 55, 38), Color3.fromRGB(140, 106, 72) }
local WATER = Color3.fromRGB(150, 230, 235)
local SPIT = Color3.fromRGB(128, 232, 64)
local SPIT_DEEP = Color3.fromRGB(70, 170, 40)
local LEAF = { Color3.fromRGB(110, 200, 80), Color3.fromRGB(150, 225, 95), Color3.fromRGB(80, 170, 70) }

return function(VFX)
	local function att(model: Model, name: string): Attachment?
		return VFX.findAttachment(model, name)
	end
	local function part(props): Part
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		for k, v in pairs(props) do (p :: any)[k] = v end
		p.Parent = VFX.Folder()
		return p
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- the ground (or water) height under a point, ignoring the creature itself
	local function groundY(model: Model, p: Vector3): number
		local water = VFX.waterSurface(model)
		rayParams.FilterDescendantsInstances = { model, VFX.Folder() }
		local hit = Workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), rayParams)
		local y = hit and hit.Position.Y or nil
		if water and (not y or water > y) and water < p.Y + 4 then return water end
		if y then return y end
		local foot = att(model, "VFX_RightFoot")
		return foot and foot.WorldPosition.Y or model:GetPivot().Position.Y
	end
	local function flatRing(pos: Vector3, r0: number, r1: number, block: number, color: Color3, dur: number?, count: number?)
		VFX.BlockRing(CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0), {
			Count = count or 16, R0 = r0, R1 = r1, Block = block, Color = color, Transparency = 0.35, Duration = dur or 0.8,
		})
	end
	-- a thin glowing hoop lying flat that grows and fades (water rings)
	local function hoop(pos: Vector3, r0: number, r1: number, dur: number, color: Color3)
		local h = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, r0 * 2, r0 * 2), Color = color, Material = Enum.Material.Neon, Transparency = 0.35, CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2) })
		local inner = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.07, r0 * 1.7, r0 * 1.7), Color = Color3.fromRGB(46, 120, 130), Material = Enum.Material.SmoothPlastic, Transparency = 0.2, CFrame = h.CFrame })
		TweenService:Create(h, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, r1 * 2, r1 * 2), Transparency = 1 }):Play()
		TweenService:Create(inner, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.07, r1 * 1.85, r1 * 1.85), Transparency = 1 }):Play()
		Debris:AddItem(h, dur + 0.1)
		Debris:AddItem(inner, dur + 0.1)
	end

	-- drinking: rings spread from where the snout touches the water (a dust puff on dry ground)
	VFX.Extra.Ripple = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local k = ((arg and arg.Scale) or 0.5) * math.max(0.6, s)
		local mouth = att(model, "VFX_Mouth") or att(model, "VFX_Head")
		if not mouth then return end
		local p = mouth.WorldPosition
		local y = groundY(model, p)
		local water = VFX.waterSurface(model)
		local at = Vector3.new(p.X, y + 0.06, p.Z)
		if water and math.abs(water - y) < 0.05 then
			for i = 0, 2 do
				task.delay(i * 0.22, function() hoop(at, 0.2 * k, (1.6 + i * 0.7) * k, 1.1 + i * 0.2, WATER) end)
			end
			VFX.Cubes(at, math.floor(3 + k * 3), { WATER, Color3.fromRGB(110, 200, 220) }, 0.12 * k, 4, 0.5)
		else
			VFX.FootstepDust(at, 0.5 * k)
			flatRing(at, 0.3 * k, 1.8 * k, 0.15 * k, DUST, 0.6, 10)
		end
	end

	-- the pack (or the partner) answers: every model led by this one plays the action
	VFX.Extra.PackCue = function(model: Model, arg, _s)
		local action = arg and arg.Action
		if type(action) ~= "string" then return end
		local Animations = require(script.Parent.Parent:WaitForChild("DinosaurAnimations")) :: any
		local scope = model.Parent
		if not scope then return end
		local here = model:GetPivot().Position
		local stagger = (arg and arg.Stagger) or 0.08
		local i = 0
		for _, d in ipairs(scope:GetDescendants()) do
			if d ~= model and d:IsA("Model") and d:GetAttribute("HerdLeader") == model.Name and (d:GetPivot().Position - here).Magnitude < 80 then
				i += 1
				task.delay(stagger * (i - 1) + math.random() * 0.04, function()
					local anim = Animations.find(d)
					if anim and anim:HasAction(action) then anim:Play(action) end
				end)
			end
		end
	end

	-- Dilophosaurus: the crests flush hot and glow
	local CREST = { CrestPlate = true, CrestFront = true, CrestBack = true, CrestEdge = true }
	VFX.Extra.CrestFlush = function(model: Model, arg, s)
		local dur = (type(arg) == "number" and arg) or (type(arg) == "table" and arg.Dur) or 3
		if model:GetAttribute("_crestFlush") then return end
		model:SetAttribute("_crestFlush", true)
		local saved = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and (CREST[d.Name] or d.Name == "CrestStripe") then
				table.insert(saved, { Part = d, Color = d.Color, Mat = d.Material })
				local hot = d.Name == "CrestStripe" and Color3.fromRGB(255, 250, 220) or (d.Color.G > 0.4 and Color3.fromRGB(255, 196, 64) or Color3.fromRGB(255, 72, 36))
				d.Material = Enum.Material.Neon
				TweenService:Create(d, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Color = hot }):Play()
			end
		end
		local host = att(model, "VFX_Crest") or att(model, "VFX_Head")
		local light: PointLight? = nil
		if host then
			local pl = Instance.new("PointLight")
			pl.Color = Color3.fromRGB(255, 120, 50)
			pl.Range = 7 * s
			pl.Brightness = 0
			pl.Parent = host
			light = pl
			TweenService:Create(pl, TweenInfo.new(0.25), { Brightness = 2.2 }):Play()
			VFX.Burst(host.WorldCFrame, math.floor(6 + s * 2), {
				Texture = SPARKLE, Speed = NumberRange.new(2, 5), Lifetime = NumberRange.new(0.4, 0.8), Spread = Vector2.new(60, 60),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * s), NumberSequenceKeypoint.new(1, 0) }),
				Color = Color3.fromRGB(255, 170, 70), LightEmission = 1, Acceleration = Vector3.new(0, 3, 0),
			})
		end
		task.delay(dur, function()
			for _, r in ipairs(saved) do
				if r.Part.Parent then
					r.Part.Material = r.Mat
					TweenService:Create(r.Part, TweenInfo.new(0.7), { Color = r.Color }):Play()
				end
			end
			if light then
				TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
				Debris:AddItem(light, 0.7)
			end
			if model.Parent then model:SetAttribute("_crestFlush", nil) end
		end)
	end

	-- the screen splat: green globs across the "lens", drips running down, a green blur that clears
	local function splatScreen(k: number, hold: number)
		local plr = Players.LocalPlayer
		local pg = plr and plr:FindFirstChildOfClass("PlayerGui")
		if not pg then return end
		local gui = Instance.new("ScreenGui")
		gui.Name = "DiloSpitSplat"
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 55
		gui.ResetOnSpawn = false
		local tint = Instance.new("Frame")
		tint.Size = UDim2.fromScale(1, 1)
		tint.BackgroundColor3 = SPIT_DEEP
		tint.BackgroundTransparency = 0.45
		tint.BorderSizePixel = 0
		tint.Parent = gui
		local blobs = {}
		local function blob(x: number, y: number, w: number, color: Color3, t: number)
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(x, y)
			f.Size = UDim2.fromScale(w * 0.3, w * 0.3)
			f.BackgroundColor3 = color
			f.BackgroundTransparency = t
			f.BorderSizePixel = 0
			f.Rotation = math.random(-30, 30)
			local ar = Instance.new("UIAspectRatioConstraint")
			ar.AspectRatio = 0.8 + math.random() * 0.5
			ar.Parent = f
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.45, 0)
			c.Parent = f
			local hi = Instance.new("Frame")
			hi.AnchorPoint = Vector2.new(0.5, 0.5)
			hi.Position = UDim2.fromScale(0.34, 0.3)
			hi.Size = UDim2.fromScale(0.22, 0.16)
			hi.BackgroundColor3 = Color3.fromRGB(235, 255, 210)
			hi.BackgroundTransparency = 0.35
			hi.BorderSizePixel = 0
			local hc = Instance.new("UICorner")
			hc.CornerRadius = UDim.new(0.5, 0)
			hc.Parent = hi
			hi.Parent = f
			f.Parent = gui
			-- splats land with a squash
			TweenService:Create(f, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(w, w) }):Play()
			table.insert(blobs, f)
			return f
		end
		blob(0.5, 0.48, 0.42 * k, SPIT, 0.08)
		for _ = 1, 7 do
			local a = math.random() * math.pi * 2
			local d = 0.12 + math.random() * 0.22
			blob(0.5 + math.cos(a) * d, 0.48 + math.sin(a) * d * 1.3, (0.06 + math.random() * 0.12) * k, math.random() < 0.5 and SPIT or SPIT_DEEP, 0.12)
		end
		-- drips running down the glass
		for _ = 1, 6 do
			local x = 0.35 + math.random() * 0.3
			local d = Instance.new("Frame")
			d.AnchorPoint = Vector2.new(0.5, 0)
			d.Position = UDim2.fromScale(x, 0.5 + (math.random() - 0.5) * 0.15)
			d.Size = UDim2.fromScale(0.012 + math.random() * 0.012, 0.03)
			d.BackgroundColor3 = SPIT_DEEP
			d.BackgroundTransparency = 0.15
			d.BorderSizePixel = 0
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = d
			d.Parent = gui
			TweenService:Create(d, TweenInfo.new(hold + 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(d.Size.X.Scale, 0.18 + math.random() * 0.25) }):Play()
			table.insert(blobs, d)
		end
		gui.Parent = pg
		task.delay(hold, function()
			TweenService:Create(tint, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
			for _, b in ipairs(blobs) do
				TweenService:Create(b, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1, Position = b.Position + UDim2.fromScale(0, 0.08) }):Play()
				for _, ch in ipairs(b:GetChildren()) do
					if ch:IsA("Frame") then TweenService:Create(ch, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play() end
				end
			end
		end)
		Debris:AddItem(gui, hold + 1.2)
	end

	-- a puddle of spit hissing on the ground
	local function puddle(model: Model, at: Vector3, k: number)
		local y = groundY(model, at)
		local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.4, 0.4), Color = SPIT, Material = Enum.Material.Neon, Transparency = 0.2, CFrame = CFrame.new(at.X, y + 0.05, at.Z) * CFrame.Angles(0, 0, math.pi / 2) })
		TweenService:Create(p, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = Vector3.new(0.08, 2.4 * k, 2.4 * k) }):Play()
		task.delay(1.6, function() if p.Parent then TweenService:Create(p, TweenInfo.new(0.8), { Transparency = 1 }):Play() end end)
		Debris:AddItem(p, 2.6)
		VFX.Burst(CFrame.new(at.X, y + 0.2, at.Z), 6, {
			Speed = NumberRange.new(1, 3), Lifetime = NumberRange.new(0.8, 1.3), Color = Color3.fromRGB(190, 240, 160),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * k), NumberSequenceKeypoint.new(1, 1.6 * k) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }), Acceleration = Vector3.new(0, 2, 0),
		})
	end

	-- Dilophosaurus: a glob of blinding spit
	VFX.Extra.SpitGlob = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local k = (arg and arg.Scale) or 1
		local mouth = att(model, "VFX_Mouth")
		local head = att(model, "VFX_Head")
		if not mouth then return end
		local from = mouth.WorldPosition
		local dir = head and (from - head.WorldPosition) or mouth.WorldCFrame.LookVector
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1)
		local cam = Workspace.CurrentCamera
		local toLens = false
		local to = from + Vector3.new(dir.X, 0, dir.Z).Unit * 16 * math.max(1, s * 0.6)
		if arg and arg.Splat and cam then
			local camPos = cam.CFrame.Position
			local off = camPos - from
			local flat = Vector3.new(dir.X, 0, dir.Z)
			local ahead = flat.Magnitude > 0.01 and Vector3.new(off.X, 0, off.Z).Unit:Dot(flat.Unit) or 1
			if off.Magnitude < ((arg and arg.Range) or 40) and ahead > 0.25 then
				toLens = true
				to = camPos + cam.CFrame.LookVector * 1.4
			end
		end
		VFX.Burst(CFrame.lookAt(from, from + dir), 8, {
			Texture = SPARKLE, Direction = Enum.NormalId.Front, Spread = Vector2.new(25, 25), Speed = NumberRange.new(8, 14),
			Lifetime = NumberRange.new(0.25, 0.45), Color = SPIT, LightEmission = 0.6, Acceleration = Vector3.zero,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * k), NumberSequenceKeypoint.new(1, 0) }),
		})
		local glob = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 0.75, 0.75) * k * math.max(0.8, s * 0.6), Color = SPIT, Material = Enum.Material.Neon, Transparency = 0.05, CFrame = CFrame.new(from) })
		local trail = {}
		for i = 1, 4 do
			trail[i] = part({ Shape = Enum.PartType.Ball, Size = glob.Size * (0.7 - i * 0.12), Color = i % 2 == 0 and SPIT_DEEP or SPIT, Material = Enum.Material.Neon, Transparency = 0.2 + i * 0.1, CFrame = CFrame.new(from) })
		end
		local dist = (to - from).Magnitude
		local dur = math.clamp(dist / 34, 0.22, 0.55)
		local arc = toLens and dist * 0.08 or dist * 0.2
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local u = math.min(1, (os.clock() - t0) / dur)
			local function at(v: number): Vector3
				v = math.clamp(v, 0, 1)
				return from:Lerp(to, v) + Vector3.new(0, math.sin(v * math.pi) * arc, 0)
			end
			glob.CFrame = CFrame.new(at(u)) * CFrame.Angles(u * 6, u * 4, 0)
			for i, tp in ipairs(trail) do tp.CFrame = CFrame.new(at(u - i * 0.07)) end
			if u >= 1 then
				conn:Disconnect()
				glob:Destroy()
				for _, tp in ipairs(trail) do tp:Destroy() end
				if toLens then
					splatScreen(k, (arg and arg.Hold) or 1.3)
					VFX.Shake(0.25, 0.25)
				else
					puddle(model, to, k)
				end
			end
		end)
	end

	-- a heavy slam: a ring of dust rolling out from its feet
	VFX.Extra.DustRing = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local k = (arg and arg.Scale) or s
		local c = model:GetPivot().Position
		local y = groundY(model, c)
		local at = Vector3.new(c.X, y + 0.25, c.Z)
		flatRing(at, 1.5 * k, 9 * k, 0.6 * k, DUST, 0.9, 26)
		task.delay(0.12, function() flatRing(at, 1.0 * k, 6 * k, 0.45 * k, SAND[1], 0.75, 20) end)
		for i = 1, 10 do
			local a = (i / 10) * math.pi * 2
			VFX.Burst(CFrame.new(at + Vector3.new(math.cos(a), 0, math.sin(a)) * 2.5 * k), 3, {
				Speed = NumberRange.new(4 * k, 8 * k), Spread = Vector2.new(30, 30), Color = DUST, Lifetime = NumberRange.new(0.9, 1.5),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * k), NumberSequenceKeypoint.new(1, 3.6 * k) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
				Acceleration = Vector3.new(math.cos(a), 0.2, math.sin(a)) * 5 * k,
			})
		end
		VFX.Cubes(at, math.floor(6 + k * 3), SAND, 0.3 * k, 10 + k * 3, 1.0)
	end

	-- mud bubbles swelling and popping over the buried ruler
	VFX.Extra.MudBubble = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local k = ((arg and arg.Scale) or 1) * math.max(0.7, s * 0.5)
		local head = att(model, "VFX_Head")
		local base = head and head.WorldPosition or model:GetPivot().Position
		local fwd = model:GetPivot().LookVector
		for i = 1, 4 do
			task.delay((i - 1) * 0.18 + math.random() * 0.1, function()
				local p = base - fwd * (math.random() * 8 - 2) * k + model:GetPivot().RightVector * (math.random() - 0.5) * 3 * k
				local y = groundY(model, p)
				local b = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.2, 0.2, 0.2), Color = MUD[math.random(1, #MUD)], Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.15, CFrame = CFrame.new(p.X, y, p.Z) })
				local r = (0.5 + math.random() * 0.6) * k
				TweenService:Create(b, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Size = Vector3.new(r, r, r), CFrame = CFrame.new(p.X, y + r * 0.2, p.Z) }):Play()
				task.delay(0.5, function()
					if b.Parent then
						VFX.Cubes(b.Position, 3, MUD, 0.12 * k, 4, 0.4)
						hoop(Vector3.new(p.X, y + 0.04, p.Z), r * 0.4, r * 1.6, 0.5, MUD[3])
						b:Destroy()
					end
				end)
			end)
		end
	end

	-- an eruption of mud clods out of the dry riverbed (or flung off the body as it shakes: Spray)
	VFX.Extra.MudBurst = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local k = (arg and arg.Scale) or 1
		local spray = arg and arg.Spray
		if spray then
			for _, name in ipairs({ "VFX_Chest", "VFX_Head", "VFX_TailTip" }) do
				local a = att(model, name)
				if a then
					VFX.Cubes(a.WorldPosition, math.floor(5 + k * 4), MUD, 0.18 * k * math.max(1, s * 0.5), 14 * k, 0.8)
					VFX.Burst(a.WorldCFrame, 4, { Speed = NumberRange.new(6, 12), Spread = Vector2.new(90, 90), Color = MUD[3], Size = NumberSequence.new(0.6 * k, 1.6 * k), Lifetime = NumberRange.new(0.4, 0.7), Acceleration = Vector3.new(0, -20, 0) })
				end
			end
			return
		end
		local head = att(model, "VFX_Head")
		local chest = att(model, "VFX_Chest")
		local pts = {}
		if head then table.insert(pts, head.WorldPosition) end
		if chest then table.insert(pts, chest.WorldPosition) end
		table.insert(pts, model:GetPivot().Position)
		for _, p in ipairs(pts) do
			local y = groundY(model, p)
			local at = Vector3.new(p.X, y + 0.2, p.Z)
			VFX.Cubes(at, math.floor(8 + k * 5), MUD, 0.35 * k, 16 + k * 5, 1.4)
			VFX.Cubes(at, math.floor(4 + k * 2), SAND, 0.3 * k, 12 + k * 3, 1.2)
			flatRing(at, 1.0 * k, 5 * k, 0.45 * k, MUD[3], 0.7, 18)
			VFX.Burst(CFrame.new(at), math.floor(8 + k * 4), {
				Speed = NumberRange.new(6 * k, 14 * k), Spread = Vector2.new(40, 40), Color = MUD[1], Lifetime = NumberRange.new(0.6, 1.1),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0 * k), NumberSequenceKeypoint.new(1, 2.8 * k) }), Acceleration = Vector3.new(0, -14, 0),
			})
			VFX.Burst(CFrame.new(at), math.floor(6 + k * 3), {
				Speed = NumberRange.new(3 * k, 6 * k), Spread = Vector2.new(80, 80), Color = DUST, Lifetime = NumberRange.new(1.0, 1.6),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * k), NumberSequenceKeypoint.new(1, 4 * k) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
			})
		end
		VFX.Shake(0.35 * k, 0.4, model:GetPivot().Position, 60 * s)
	end

	-- the Forager's gift: leaves and green sparkles rising in a soft pulse
	VFX.Extra.HealPulse = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local k = ((arg and arg.Scale) or 1) * math.max(0.7, s * 0.5)
		local c = model:GetPivot().Position
		local y = groundY(model, c)
		local at = Vector3.new(c.X, y + 0.3, c.Z)
		flatRing(at, 1.0 * k, 7 * k, 0.4 * k, Color3.fromRGB(150, 240, 120), 1.0, 18)
		for i = 1, 8 do
			local a = (i / 8) * math.pi * 2
			VFX.Burst(CFrame.new(at + Vector3.new(math.cos(a), 0, math.sin(a)) * 3 * k), 2, {
				Texture = SPARKLE, Speed = NumberRange.new(2, 4), Spread = Vector2.new(15, 15), Lifetime = NumberRange.new(0.9, 1.4),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * k), NumberSequenceKeypoint.new(1, 0) }),
				Color = Color3.fromRGB(170, 255, 140), LightEmission = 0.8, Acceleration = Vector3.new(0, 4, 0),
			})
		end
		VFX.Cubes(at + Vector3.new(0, 1, 0), 6, LEAF, 0.22 * k, 6, 0.9)
	end

	-- the ruler's terror roar: a dark shock ring rolling over the ground
	VFX.Extra.TerrorWave = function(model: Model, arg, s)
		if not VFX.Enabled then return end
		local k = (arg and arg.Scale) or s
		local c = model:GetPivot().Position
		local y = groundY(model, c)
		local at = Vector3.new(c.X, y + 0.3, c.Z)
		for i = 0, 2 do
			task.delay(i * 0.18, function()
				flatRing(at, 2 * k, (10 + i * 4) * k, 0.55 * k, i == 1 and Color3.fromRGB(120, 30, 24) or Color3.fromRGB(60, 18, 14), 1.0, 28)
			end)
		end
		VFX.Burst(CFrame.new(at), math.floor(10 + k * 4), {
			Speed = NumberRange.new(8 * k, 14 * k), Spread = Vector2.new(85, 85), Color = DUST, Lifetime = NumberRange.new(0.8, 1.3),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * k), NumberSequenceKeypoint.new(1, 3.5 * k) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		})
	end
end
