--[[
	DinosaurVFX — lightweight, client-side effects in the chunky Roblox style.

	Effects are built from blocky Parts (debris cubes, block-ring shockwaves) plus ParticleEmitters
	using Roblox's built-in particle textures. Everything is client-only and self-cleaning.
	The dinosaurs look complete with VFX disabled: set DinosaurVFX.Enabled = false.

	API:
		FootstepDust(position, scale)        RoarShockwave(mouthCFrame, scale, screech?)
		GroundImpact(position, scale)        BiteImpact(position, scale)
		TailSwing(model, duration)           WaterSplash(position, scale)
		EyeGlow(model, duration)             ChargeDust(model, duration)
		Debris(position, scale, color?)      Stunned(model, duration)
		FoliageBurst(position, scale)        Shake(intensity, duration, position?)
		Curtain(model, open)                 HandleEvent(model, eventName, arg)  -- animator event hook
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local DinosaurVFX = {}
DinosaurVFX.Enabled = true

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local DUST = Color3.fromRGB(196, 170, 128)
local DIRT = { Color3.fromRGB(122, 92, 60), Color3.fromRGB(150, 116, 76), Color3.fromRGB(98, 76, 52) }
local LEAF = { Color3.fromRGB(63, 154, 58), Color3.fromRGB(79, 176, 67), Color3.fromRGB(54, 134, 58) }

local fxFolder: Folder? = nil
local propState -- forward-declared: used by ResetEnvironment, created with the prop helpers below
local function folder()
	if fxFolder and fxFolder.Parent then return fxFolder end
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DinoVFX_Client"
	fxFolder.Parent = Workspace
	return fxFolder
end

local function anchorPart(cf: CFrame)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = folder()
	return p
end

local function burst(cf: CFrame, count: number, props)
	local host = anchorPart(cf)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = props.Texture or SMOKE
	e.Lifetime = props.Lifetime or NumberRange.new(0.6, 1.1)
	e.Speed = props.Speed or NumberRange.new(4, 8)
	e.SpreadAngle = props.Spread or Vector2.new(70, 70)
	e.Size = props.Size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
	e.Transparency = props.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(props.Color or DUST)
	e.Acceleration = props.Acceleration or Vector3.new(0, 2, 0)
	e.Drag = props.Drag or 3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.LightEmission = props.LightEmission or 0
	e.LightInfluence = props.LightInfluence or 1
	e.EmissionDirection = props.Direction or Enum.NormalId.Top
	e.Parent = host
	e:Emit(count)
	Debris:AddItem(host, (props.Lifetime and props.Lifetime.Max or 1.1) + 0.5)
	return host
end

-- Blocky debris: small physical cubes that pop out and fade away
local function cubes(pos: Vector3, n: number, colors, size: number, speed: number, life: number?)
	for _ = 1, n do
		local p = Instance.new("Part")
		local s = size * (0.6 + math.random() * 0.8)
		p.Size = Vector3.new(s, s, s)
		p.Color = colors[math.random(1, #colors)]
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		-- (they still fall and tumble, but they don't collide: dozens of colliding cubes per boss footstep were a
		-- physics cost on every client)
		p.CanCollide = false
		p.CFrame = CFrame.new(pos + Vector3.new(math.random() - 0.5, math.random() * 0.5, math.random() - 0.5) * size * 2)
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Parent = folder()
		local dir = Vector3.new(math.random() - 0.5, 0.6 + math.random() * 0.8, math.random() - 0.5).Unit
		p.AssemblyLinearVelocity = dir * speed * (0.6 + math.random() * 0.6)
		p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 12
		local l = (life or 1.3) + math.random() * 0.5
		task.delay(l, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.35), { Transparency = 1, Size = p.Size * 0.3 }):Play()
			end
		end)
		Debris:AddItem(p, l + 0.4)
	end
end

-- Ring of glowing blocks expanding outward in cf's XY plane (normal = LookVector)
local function blockRing(cf: CFrame, opts)
	local n = opts.Count or 14
	local r0, r1 = opts.R0 or 0.5, opts.R1 or 6
	local dur = opts.Duration or 0.5
	local travel = opts.Travel or 0
	local bs = opts.Block or 0.5
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = opts.Color or Color3.fromRGB(255, 244, 214)
		p.Transparency = opts.Transparency or 0.15
		p.Size = Vector3.new(bs, bs, bs * 0.5)
		local function at(r, z) return cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, -z) * CFrame.Angles(0, 0, a) end
		p.CFrame = at(r0, 0)
		p.Parent = folder()
		TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = at(r1, travel), Transparency = 1, Size = Vector3.new(bs * 1.6, bs * 0.35, bs * 0.3),
		}):Play()
		Debris:AddItem(p, dur + 0.1)
	end
end

-- Camera shake ---------------------------------------------------------------
local shakes = {}
local shakeBound = false
local function bindShake()
	if shakeBound then return end
	shakeBound = true
	RunService:BindToRenderStep("DinoCameraShake", Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock()
		local amp = 0
		for i = #shakes, 1, -1 do
			local s = shakes[i]
			local age = (now - s.Start) / s.Duration
			if age >= 1 then
				table.remove(shakes, i)
			else
				amp += s.Intensity * (1 - age) ^ 2
			end
		end
		if amp <= 0.001 then return end
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local t = now * 24
		amp = math.min(amp, 2.5)
		cam.CFrame = cam.CFrame
			* CFrame.new(math.noise(t, 1.1) * amp * 0.25, math.noise(t, 2.3) * amp * 0.25, 0)
			* CFrame.Angles(math.noise(t, 3.7) * amp * 0.02, math.noise(t, 5.9) * amp * 0.02, math.noise(t, 7.3) * amp * 0.012)
	end)
end

DinosaurVFX.ShakeScale = 1 -- Settings > Camera Shake sets this to 0
-- optional gate for footstep camera shake: (model) -> boolean (nil = always shake)
DinosaurVFX.FootstepShake = nil :: ((Model) -> boolean)?

function DinosaurVFX.Shake(intensity: number, duration: number?, position: Vector3?, radius: number?)
	intensity *= DinosaurVFX.ShakeScale
	if intensity <= 0 then return end
	if position then
		local cam = Workspace.CurrentCamera
		if cam then
			local d = (cam.CFrame.Position - position).Magnitude
			intensity *= math.clamp(1 - d / (radius or 120), 0, 1)
			if intensity <= 0.01 then return end
		end
	end
	bindShake()
	table.insert(shakes, { Intensity = intensity, Duration = duration or 0.6, Start = os.clock() })
end

-- Effects ------------------------------------------------------------------
function DinosaurVFX.FootstepDust(position: Vector3, scale: number?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	burst(CFrame.new(position), math.floor(4 + scale * 3), {
		Speed = NumberRange.new(2 * scale, 5 * scale), Spread = Vector2.new(80, 80),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * scale), NumberSequenceKeypoint.new(1, 1.8 * scale) }),
		Acceleration = Vector3.new(0, 1, 0),
	})
	if scale > 1.5 then
		cubes(position, math.floor(scale * 2), DIRT, 0.25 * scale, 10 + scale * 2, 0.9)
		blockRing(CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 12, R0 = 0.8 * scale, R1 = 3.2 * scale, Block = 0.3 * scale, Color = DUST, Transparency = 0.4, Duration = 0.45 })
	end
end

function DinosaurVFX.RoarShockwave(mouth: CFrame, scale: number?, screech: boolean?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	local color = screech and Color3.fromRGB(255, 226, 150) or Color3.fromRGB(255, 244, 214)
	for k = 0, 2 do
		task.delay(k * 0.22, function()
			blockRing(mouth, { Count = 16, R0 = 0.6 * scale, R1 = (3 + k) * scale * 1.4, Travel = 5 * scale, Block = 0.35 * scale, Color = color, Transparency = 0.25 + k * 0.15, Duration = 0.65 })
		end)
	end
	burst(mouth, math.floor(8 + scale * 4), {
		Texture = SPARKLE, Direction = Enum.NormalId.Front, Spread = Vector2.new(25, 25),
		Speed = NumberRange.new(10 * scale, 18 * scale), Lifetime = NumberRange.new(0.4, 0.7),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * scale), NumberSequenceKeypoint.new(1, 0.1) }),
		Color = color, LightEmission = 0.6, Drag = 4, Acceleration = Vector3.zero,
	})
	-- breath vapor
	burst(mouth, math.floor(5 + scale * 2), {
		Direction = Enum.NormalId.Front, Spread = Vector2.new(30, 30), Speed = NumberRange.new(6 * scale, 10 * scale),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * scale), NumberSequenceKeypoint.new(1, 3 * scale) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Color = Color3.fromRGB(235, 235, 235), Drag = 5, Acceleration = Vector3.zero,
	})
end

function DinosaurVFX.GroundImpact(position: Vector3, scale: number?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	blockRing(CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 18, R0 = 0.8 * scale, R1 = 6 * scale, Block = 0.45 * scale, Color = DUST, Transparency = 0.3, Duration = 0.6 })
	cubes(position, math.floor(5 + scale * 3), DIRT, 0.35 * scale, 14 + scale * 3, 1.1)
	burst(CFrame.new(position), math.floor(10 + scale * 4), {
		Speed = NumberRange.new(4 * scale, 9 * scale), Spread = Vector2.new(85, 85),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 * scale), NumberSequenceKeypoint.new(1, 3.5 * scale) }),
	})
end

function DinosaurVFX.BiteImpact(position: Vector3, scale: number?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	blockRing(CFrame.new(position, position + Vector3.new(0, 1, 0)), { Count = 10, R0 = 0.3 * scale, R1 = 2.4 * scale, Block = 0.3 * scale, Color = Color3.new(1, 1, 1), Duration = 0.3 })
	burst(CFrame.new(position), math.floor(6 + scale * 3), {
		Texture = SPARKLE, Speed = NumberRange.new(6 * scale, 12 * scale), Spread = Vector2.new(180, 180), Lifetime = NumberRange.new(0.25, 0.45),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * scale), NumberSequenceKeypoint.new(1, 0) }),
		Color = Color3.new(1, 1, 1), LightEmission = 0.8, Acceleration = Vector3.zero,
	})
end

function DinosaurVFX.WaterSplash(position: Vector3, scale: number?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	local water = { Color3.fromRGB(110, 190, 255), Color3.fromRGB(170, 220, 255), Color3.fromRGB(80, 160, 230) }
	cubes(position, math.floor(8 + scale * 4), water, 0.35 * scale, 18 + scale * 4, 0.9)
	blockRing(CFrame.new(position) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 18, R0 = scale, R1 = 7 * scale, Block = 0.4 * scale, Color = water[2], Transparency = 0.3, Duration = 0.7 })
	burst(CFrame.new(position), math.floor(12 + scale * 5), {
		Speed = NumberRange.new(10 * scale, 20 * scale), Spread = Vector2.new(35, 35), Acceleration = Vector3.new(0, -30, 0),
		Color = water[2], Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * scale), NumberSequenceKeypoint.new(1, 1.6 * scale) }),
	})
end

function DinosaurVFX.Debris(position: Vector3, scale: number?, color: Color3?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	cubes(position, math.floor(8 + scale * 4), color and { color } or { Color3.fromRGB(125, 122, 115), Color3.fromRGB(108, 105, 98), Color3.fromRGB(140, 136, 128) }, 0.5 * scale, 16 + scale * 4, 1.6)
	DinosaurVFX.GroundImpact(position, scale * 0.8)
end

function DinosaurVFX.FoliageBurst(position: Vector3, scale: number?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	cubes(position, math.floor(10 + scale * 4), LEAF, 0.4 * scale, 12 + scale * 3, 1.4)
	burst(CFrame.new(position), math.floor(8 + scale * 3), { Color = Color3.fromRGB(120, 190, 90), Speed = NumberRange.new(4, 10), Spread = Vector2.new(90, 90) })
end


-- Radial ground cracks: dark plates fanning out from an impact, fading after a moment
function DinosaurVFX.GroundCracks(position: Vector3, scale: number?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	local n = 5 + math.floor(scale)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + math.random() * 0.5
		local len = (1.2 + math.random() * 1.4) * scale
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Slate
		p.Color = Color3.fromRGB(58, 46, 36)
		p.Size = Vector3.new(0.18 * scale, 0.06, 0.01)
		local base = CFrame.new(position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, a, 0)
		p.CFrame = base * CFrame.new(0, 0, -len * 0.5)
		p.Parent = folder()
		TweenService:Create(p, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = Vector3.new(0.18 * scale, 0.06, len) }):Play()
		task.delay(1.6, function()
			if p.Parent then TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1 }):Play() end
		end)
		Debris:AddItem(p, 2.4)
	end
	cubes(position, 3 + math.floor(scale * 2), { Color3.fromRGB(125, 122, 115), Color3.fromRGB(98, 76, 52) }, 0.18 * scale, 7 + scale * 2, 0.7)
end

-- Leaves shaken loose from the canopy, drifting and swaying down
function DinosaurVFX.FallingLeaves(center: Vector3, radius: number, count: number, height: number?)
	if not DinosaurVFX.Enabled then return end
	local leaves = {}
	for i = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Color = LEAF[math.random(1, #LEAF)]
		p.Size = Vector3.new(0.5, 0.06, 0.8) * (0.7 + math.random() * 0.6)
		p.Parent = folder()
		local start = center + Vector3.new((math.random() * 2 - 1) * radius, (height or 14) + math.random() * 6, (math.random() * 2 - 1) * radius)
		leaves[i] = { Part = p, Start = start, Phase = math.random() * 6, Speed = 2.5 + math.random() * 2, Delay = math.random() * 0.6 }
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 4.2 then
			conn:Disconnect()
			for _, l in ipairs(leaves) do l.Part:Destroy() end
			return
		end
		for _, l in ipairs(leaves) do
			local lt = math.max(0, t - l.Delay)
			local fall = l.Speed * lt
			local sway = math.sin(lt * 3 + l.Phase)
			l.Part.CFrame = CFrame.new(l.Start + Vector3.new(sway * 1.2, -fall, math.cos(lt * 2.3 + l.Phase) * 0.8))
				* CFrame.Angles(sway * 0.8, lt * 2 + l.Phase, math.cos(lt * 3 + l.Phase) * 0.6)
			if t > 3.4 then l.Part.Transparency = (t - 3.4) / 0.8 end
		end
	end)
end

-- A rolling wave of dust pushed along the ground by a roar (forward cone)
function DinosaurVFX.DustWave(origin: Vector3, forward: Vector3, scale: number?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	local flat = Vector3.new(forward.X, 0, forward.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	for k = 1, 4 do
		task.delay(k * 0.12, function()
			local d = k * 2.2 * scale
			for j = -2, 2 do
				local dir = CFrame.fromAxisAngle(Vector3.yAxis, j * 0.32):VectorToWorldSpace(flat)
				burst(CFrame.new(origin + dir * d), 2, {
					Speed = NumberRange.new(3 * scale, 6 * scale), Spread = Vector2.new(30, 30), Direction = Enum.NormalId.Top,
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * scale), NumberSequenceKeypoint.new(1, 3.4 * scale) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
					Lifetime = NumberRange.new(0.8, 1.3), Acceleration = flat * 6 * scale + Vector3.new(0, 1.5, 0),
				})
			end
		end)
	end
end

-- Spittle spray from a roaring mouth: tiny bright cubes arcing forward under gravity
function DinosaurVFX.Spittle(mouth: CFrame, scale: number?)
	if not DinosaurVFX.Enabled then return end
	scale = scale or 1
	for _ = 1, math.floor(6 + scale * 3) do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.12, 0.12, 0.12) * scale
		p.Color = Color3.fromRGB(235, 245, 255)
		p.Material = Enum.Material.Glass
		p.Transparency = 0.3
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = mouth * CFrame.new((math.random() - 0.5) * scale, (math.random() - 0.5) * 0.5 * scale, 0)
		p.Parent = folder()
		local dir = (mouth.LookVector + Vector3.new((math.random() - 0.5) * 0.6, math.random() * 0.4, (math.random() - 0.5) * 0.6)).Unit
		p.AssemblyLinearVelocity = dir * (12 + math.random() * 10) * math.sqrt(scale)
		Debris:AddItem(p, 0.9)
	end
end

-- Model-bound effects --------------------------------------------------------
local attCache = setmetatable({}, { __mode = "k" }) :: { [Model]: { [string]: Attachment | false } }
local function findAttachment(model: Model, name: string): Attachment?
	-- cached per model (footsteps asked for the same foot with a recursive search many times a second)
	local per = attCache[model]
	if not per then per = {} attCache[model] = per end
	local hit = per[name]
	if hit and hit.Parent and hit:IsDescendantOf(model) then return hit end
	if hit == false then return nil end
	local a = model:FindFirstChild(name, true)
	local ok = (a and a:IsA("Attachment")) and a :: Attachment or nil
	per[name] = ok or false
	return ok
end
DinosaurVFX.findAttachment = findAttachment

local scaleCache = setmetatable({}, { __mode = "k" })
function DinosaurVFX.ModelScale(model: Model): number
	if scaleCache[model] then return scaleCache[model] end
	local _, size = model:GetBoundingBox()
	local s = math.max(0.6, size.Y / 4)
	scaleCache[model] = s
	return s
end

function DinosaurVFX.EyeGlow(model: Model, duration: number?)
	if not DinosaurVFX.Enabled then return end
	local eyes = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "DinoEye") then table.insert(eyes, d) end
	end
	for _, e in ipairs(eyes) do
		if e:GetAttribute("_glowing") then continue end
		e:SetAttribute("_glowing", true)
		local mat = e.Material
		e.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = e.Color
		light.Range = 4 * DinosaurVFX.ModelScale(model)
		light.Brightness = 2
		light.Parent = e
		task.delay(duration or 1.5, function()
			if e.Parent then e.Material = mat end
			light:Destroy()
			e:SetAttribute("_glowing", nil)
		end)
	end
end

function DinosaurVFX.TailSwing(model: Model, duration: number?)
	if not DinosaurVFX.Enabled then return end
	local tip = findAttachment(model, "VFX_TailTip")
	if not tip then return end
	local s = DinosaurVFX.ModelScale(model)
	local a0 = Instance.new("Attachment")
	a0.Position = tip.Position + Vector3.new(0, 0.25 * s, 0)
	a0.Parent = tip.Parent
	local a1 = Instance.new("Attachment")
	a1.Position = tip.Position - Vector3.new(0, 0.25 * s, 0)
	a1.Parent = tip.Parent
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.25
	trail.LightEmission = 0.5
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 244, 214))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.FaceCamera = true
	trail.Parent = tip.Parent
	Debris:AddItem(trail, duration or 1)
	Debris:AddItem(a0, (duration or 1) + 0.3)
	Debris:AddItem(a1, (duration or 1) + 0.3)
end

function DinosaurVFX.ChargeDust(model: Model, duration: number?)
	if not DinosaurVFX.Enabled then return end
	local s = DinosaurVFX.ModelScale(model)
	for _, side in ipairs({ "Right", "Left" }) do
		local foot = findAttachment(model, `VFX_{side}Foot`)
		if foot then
			local e = Instance.new("ParticleEmitter")
			e.Texture = SMOKE
			e.Rate = 18
			e.Lifetime = NumberRange.new(0.6, 1)
			e.Speed = NumberRange.new(2, 5)
			e.SpreadAngle = Vector2.new(60, 60)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 * s), NumberSequenceKeypoint.new(1, 2.2 * s) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
			e.Color = ColorSequence.new(DUST)
			e.Drag = 3
			e.Parent = foot
			Debris:AddItem(e, duration or 2)
		end
	end
end

function DinosaurVFX.Stunned(model: Model, duration: number?)
	if not DinosaurVFX.Enabled then return end
	local head = findAttachment(model, "VFX_Head")
	if not head then return end
	local s = DinosaurVFX.ModelScale(model)
	local stars = {}
	for i = 1, 4 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = i % 2 == 0 and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(255, 255, 210)
		p.Size = Vector3.new(0.35, 0.35, 0.35) * s
		p.Parent = folder()
		stars[i] = p
	end
	local start = os.clock()
	local dur = duration or 2.2
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > dur or not head.Parent then
			conn:Disconnect()
			for _, p in ipairs(stars) do p:Destroy() end
			return
		end
		local center = head.WorldPosition + Vector3.new(0, 1.1 * s, 0)
		for i, p in ipairs(stars) do
			local a = t * 5 + i * (math.pi / 2)
			p.CFrame = CFrame.new(center + Vector3.new(math.cos(a), math.sin(a * 2) * 0.15, math.sin(a)) * 0.9 * s) * CFrame.Angles(t * 4, t * 3, 0)
		end
	end)
end

-- Environment: the cinematic stage's foliage curtain -------------------------
local curtainHome = setmetatable({}, { __mode = "k" })
local CURTAIN_CLOSE = 7

local function nearbyCurtains(model: Model)
	local list = {}
	local pos = model:GetPivot().Position
	for _, c in ipairs(CollectionService:GetTagged("CinematicFoliage")) do
		if c:IsA("Model") and c:IsDescendantOf(Workspace) and (c:GetPivot().Position - pos).Magnitude < 60 then
			table.insert(list, c)
		end
	end
	return list
end

local function tweenPivot(m: Model, target: CFrame, info: TweenInfo)
	local v = Instance.new("CFrameValue")
	v.Value = m:GetPivot()
	v.Changed:Connect(function(cf) m:PivotTo(cf) end)
	local tw = TweenService:Create(v, info, { Value = target })
	tw.Completed:Connect(function() v:Destroy() end)
	tw:Play()
end

-- open=false snaps the curtain closed (hiding the creature); open=true bursts it apart
function DinosaurVFX.Curtain(model: Model, open: boolean)
	for _, c in ipairs(nearbyCurtains(model)) do
		curtainHome[c] = curtainHome[c] or c:GetPivot()
		local home = curtainHome[c]
		local side = c:GetAttribute("Side") or 1
		if open then
			tweenPivot(c, home, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		else
			c:PivotTo(home * CFrame.new(-side * (c:GetAttribute("CloseDistance") or CURTAIN_CLOSE), 0, 0))
		end
	end
end

function DinosaurVFX.ResetEnvironment(model: Model)
	for _, c in ipairs(nearbyCurtains(model)) do
		if curtainHome[c] then c:PivotTo(curtainHome[c]) end
	end
	for prop in pairs(propState) do
		if prop.Parent then DinosaurVFX.RestoreProp(prop) end
	end
end


-- Cinematic props: destructible set pieces (log, boulder, crates, gate, trees) --------------------
-- Props are Models tagged "CinematicProp" with a "PropId" attribute, placed in the creature's display.
-- Breaking hides the originals and flings client-side fragment copies; everything restores itself.
propState = setmetatable({}, { __mode = "k" })

local function findProp(model: Model, propId: string): Model?
	local scope = model.Parent
	while scope and scope ~= Workspace do
		for _, d in ipairs(scope:GetDescendants()) do
			if d:IsA("Model") and d:GetAttribute("PropId") == propId and CollectionService:HasTag(d, "CinematicProp") then return d end
		end
		if scope:IsA("Model") and (scope:GetAttribute("DinoName") or scope.Name == "CinematicStage") then break end
		scope = scope.Parent
	end
	return nil
end
DinosaurVFX.findProp = findProp

local function stateFor(prop: Model)
	local st = propState[prop]
	if not st then
		st = { Parts = {}, Fragments = {}, Home = prop:GetPivot(), Children = {} }
		for _, d in ipairs(prop:GetDescendants()) do
			if d:IsA("BasePart") then st.Parts[d] = { Transparency = d.Transparency, CanCollide = d.CanCollide } end
			if d:IsA("Model") then st.Children[d] = d:GetPivot() end
		end
		propState[prop] = st
	end
	return st
end

function DinosaurVFX.RestoreProp(prop: Model)
	local st = propState[prop]
	if not st then return end
	for _, f in ipairs(st.Fragments) do f:Destroy() end
	table.clear(st.Fragments)
	prop:PivotTo(st.Home)
	for m, cf in pairs(st.Children) do if m.Parent then m:PivotTo(cf) end end
	for part, orig in pairs(st.Parts) do
		if part.Parent then
			part.CanCollide = orig.CanCollide
			if part:GetAttribute("HiddenUntilStage") then
				part.Transparency = 1
			else
				part.Transparency = 1
				TweenService:Create(part, TweenInfo.new(0.6), { Transparency = orig.Transparency }):Play()
			end
		end
	end
	st.Broken = false
end

function DinosaurVFX.BreakProp(model: Model, propId: string, power: number?, origin: Vector3?)
	local prop = findProp(model, propId)
	if not prop then return end
	local st = stateFor(prop)
	if st.Broken then return end
	st.Broken = true
	power = power or 1
	origin = origin or model:GetPivot().Position
	local center = prop:GetPivot().Position
	for part in pairs(st.Parts) do
		if part.Parent and part.Transparency < 1 then
			local frag = part:Clone()
			for _, c in ipairs(frag:GetChildren()) do
				if not c:IsA("SpecialMesh") then c:Destroy() end
			end
			frag.Anchored = false
			frag.CanCollide = true
			frag.CanQuery = false
			frag.CanTouch = false
			frag.Parent = folder()
			local away = part.Position - origin
			away = Vector3.new(away.X, 0, away.Z)
			away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, 1)
			frag.AssemblyLinearVelocity = away * power * (12 + math.random() * 12) + Vector3.new((math.random() - 0.5) * 8, power * (10 + math.random() * 14), (math.random() - 0.5) * 8)
			frag.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 10
			table.insert(st.Fragments, frag)
			part.Transparency = 1
			part.CanCollide = false
			task.delay(3 + math.random(), function()
				if frag.Parent then TweenService:Create(frag, TweenInfo.new(0.8), { Transparency = 1 }):Play() end
			end)
		end
	end
	local _, size = prop:GetBoundingBox()
	local s = math.max(1, size.Magnitude / 8)
	DinosaurVFX.GroundImpact(Vector3.new(center.X, center.Y - size.Y / 2, center.Z), s)
	cubes(center, math.floor(8 + s * 4), { Color3.fromRGB(125, 122, 115), Color3.fromRGB(150, 116, 76), Color3.fromRGB(98, 76, 52) }, 0.35 * s, 16 * power, 1.4)
	task.delay(7, function() DinosaurVFX.RestoreProp(prop) end)
end

-- Trees in a prop model topple away from the creature, one after another
function DinosaurVFX.FellTrees(model: Model, propId: string)
	local prop = findProp(model, propId)
	if not prop then return end
	local st = stateFor(prop)
	local headAtt = findAttachment(model, "VFX_Head")
	local origin = headAtt and headAtt.WorldPosition or model:GetPivot().Position
	local i = 0
	for tree, home in pairs(st.Children) do
		if tree.Parent == prop then
			i += 1
			local away = home.Position - origin
			away = Vector3.new(away.X, 0, away.Z)
			away = away.Magnitude > 0.01 and away.Unit or Vector3.new(1, 0, 0)
			local axis = Vector3.yAxis:Cross(away)
			local target = CFrame.new(home.Position) * CFrame.fromAxisAngle(axis, math.rad(78 + math.random() * 10)) * home.Rotation
			task.delay(i * 0.12, function()
				tweenPivot(tree, target, TweenInfo.new(0.9 + math.random() * 0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out))
				local _, size = tree:GetBoundingBox()
				task.delay(0.55, function()
					local hitPos = home.Position + away * size.Y * 0.8
					DinosaurVFX.GroundImpact(Vector3.new(hitPos.X, home.Position.Y, hitPos.Z), 1.2)
					DinosaurVFX.FoliageBurst(hitPos + Vector3.new(0, 1, 0), 1.2)
					DinosaurVFX.Shake(0.35, 0.4, hitPos, 70)
				end)
			end)
		end
	end
	task.delay(9, function() DinosaurVFX.RestoreProp(prop) end)
end

-- Containment gate: each hit shakes it and reveals the next crack stage; GateBreak bursts it open
function DinosaurVFX.GateHit(model: Model, propId: string, stage: number)
	local prop = findProp(model, propId)
	if not prop then return end
	local st = stateFor(prop)
	for part in pairs(st.Parts) do
		local need = part:GetAttribute("HiddenUntilStage")
		if need and need <= stage then part.Transparency = 0 end
	end
	local home = st.Home
	task.spawn(function()
		for k = 1, 6 do
			local a = (7 - k) / 6
			prop:PivotTo(home * CFrame.new((math.random() - 0.5) * 0.5 * a, 0, -0.35 * a * (k % 2 == 0 and 1 or -1)) * CFrame.Angles(math.rad((math.random() - 0.5) * 2 * a), 0, 0))
			task.wait(0.03)
		end
		prop:PivotTo(home)
	end)
	local _, size = prop:GetBoundingBox()
	local top = home.Position + Vector3.new(0, size.Y / 2, 0)
	cubes(top, 6 + stage * 3, { Color3.fromRGB(120, 124, 130), Color3.fromRGB(90, 94, 100) }, 0.3, 6, 1.2)
	burst(CFrame.new(home.Position), 10 + stage * 4, { Speed = NumberRange.new(4, 10), Spread = Vector2.new(80, 80), Size = NumberSequence.new(1.5, 4) })
	DinosaurVFX.Shake(0.4 + stage * 0.25, 0.5, home.Position, 90)
end

-- Sound rings for calls (crest honks, deep sauropod calls)
function DinosaurVFX.SoundRings(model: Model, attachmentName: string, scale: number?, color: Color3?, count: number?)
	if not DinosaurVFX.Enabled then return end
	local a = findAttachment(model, attachmentName) or findAttachment(model, "VFX_Mouth")
	if not a then return end
	scale = scale or 1
	local head = findAttachment(model, "VFX_Head")
	local dir = head and (a.WorldPosition - head.WorldPosition) or a.WorldCFrame.LookVector
	if dir.Magnitude < 0.01 then dir = a.WorldCFrame.LookVector end
	local cf = CFrame.lookAt(a.WorldPosition, a.WorldPosition + dir)
	for k = 0, (count or 4) - 1 do
		task.delay(k * 0.28, function()
			blockRing(cf, { Count = 18, R0 = 0.5 * scale, R1 = (4 + k) * scale, Travel = 7 * scale, Block = 0.3 * scale, Color = color or Color3.fromRGB(200, 236, 255), Transparency = 0.35, Duration = 1.0 })
		end)
	end
end

local function waterSurfaceY(model: Model, fallback: number): number
	local scope = model.Parent
	if scope then
		for _, d in ipairs(scope:GetDescendants()) do
			if d:IsA("BasePart") and CollectionService:HasTag(d, "DinoWater") then return d.Position.Y + d.Size.Y / 2 end
		end
	end
	-- out in the world (an era's creatures live in their own folder): any tagged water surface under the model
	local here = model:GetPivot().Position
	for _, d in ipairs(CollectionService:GetTagged("DinoWater")) do
		if d:IsA("BasePart") then
			local lp = d.CFrame:PointToObjectSpace(here)
			if math.abs(lp.X) <= d.Size.X / 2 and math.abs(lp.Z) <= d.Size.Z / 2 and math.abs(lp.Y) < 40 then return d.Position.Y + d.Size.Y / 2 end
		end
	end
	return fallback
end

-- Stegosaurus plates flush blood-red and glow when it feels threatened
function DinosaurVFX.PlateFlush(model: Model, duration: number)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and (CollectionService:HasTag(d, "StegoPlate") or d.Name == "PlateInset") then
			local orig, mat = d.Color, d.Material
			TweenService:Create(d, TweenInfo.new(0.35), { Color = Color3.fromRGB(255, 70, 40) }):Play()
			if d.Name == "PlateInset" then d.Material = Enum.Material.Neon end
			task.delay(duration, function()
				if d.Parent then
					d.Material = mat
					TweenService:Create(d, TweenInfo.new(0.8), { Color = orig }):Play()
				end
			end)
		end
	end
end

-- Something big is moving in the undergrowth: shake nearby foliage and drop a few leaves
function DinosaurVFX.Rustle(model: Model)
	local targets = {}
	for _, c in ipairs(nearbyCurtains(model)) do table.insert(targets, c) end
	local wall = findProp(model, "JungleWall")
	if wall then for _, t in ipairs(wall:GetChildren()) do if t:IsA("Model") then table.insert(targets, t) end end end
	for _, m in ipairs(targets) do
		local home = m:GetPivot()
		task.spawn(function()
			for k = 1, 8 do
				m:PivotTo(home * CFrame.Angles(math.rad((math.random() - 0.5) * 3), 0, math.rad((math.random() - 0.5) * 3)))
				task.wait(0.04)
			end
			m:PivotTo(home)
		end)
		local _, size = m:GetBoundingBox()
		DinosaurVFX.FallingLeaves(home.Position, size.X * 0.4, 5, size.Y * 0.6)
	end
end

-- Containment alarm: red lights pulse
function DinosaurVFX.Alarm(model: Model, duration: number)
	local scope = model.Parent
	if not scope then return end
	local lights = {}
	for _, d in ipairs(scope:GetDescendants()) do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "AlarmLight") then table.insert(lights, { Part = d, Color = d.Color, Mat = d.Material }) end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		local on = (t % 0.6) < 0.3 and t < duration
		for _, l in ipairs(lights) do
			l.Part.Material = on and Enum.Material.Neon or l.Mat
			l.Part.Color = on and Color3.fromRGB(255, 40, 30) or l.Color
		end
		if t >= duration then conn:Disconnect() end
	end)
end

function DinosaurVFX.waterSurface(model: Model): number?
	local y = waterSurfaceY(model, -math.huge)
	return y > -math.huge and y or nil
end

function DinosaurVFX.HerdCall(model: Model)
	local Animations = require(script.Parent:WaitForChild("DinosaurAnimations"))
	local scope = model.Parent
	if not scope then return end
	local i = 0
	local showcase = Workspace:FindFirstChild("DinoExpeditionShowcase")
	local here = model:GetPivot().Position
	for _, d in ipairs(scope:GetDescendants()) do
		if d ~= model and d:IsA("Model") and d:GetAttribute("HerdLeader") == model.Name and not (showcase and d:IsDescendantOf(showcase))
			and (d:GetPivot().Position - here).Magnitude < 120 then
			i += 1
			task.delay(0.5 + i * 0.45, function()
				local anim = Animations.find(d)
				if anim then anim:Play("HerdResponse") end
			end)
		end
	end
end

-- Animator event hook ---------------------------------------------------------
local crackAt = setmetatable({}, { __mode = "k" }) :: { [Model]: number }
function DinosaurVFX.HandleEvent(model: Model, name: string, arg)
	local s = DinosaurVFX.ModelScale(model)
	if name == "Footstep" then
		-- no dust for footsteps nobody can see (every dino on the map steps)
		local cam = workspace.CurrentCamera
		local pv = model.PrimaryPart
		if cam and pv and (pv.Position - cam.CFrame.Position).Magnitude > 140 then return end
		local foot = findAttachment(model, `VFX_{arg and arg.Side or "Right"}Foot`)
		if foot then
			DinosaurVFX.FootstepDust(foot.WorldPosition, s * (arg and arg.Running and 1.2 or 1))
			if s > 1.5 then
				-- the ground-shaking footfall is a signal, not wallpaper: the game decides when it's earned
				local allow = DinosaurVFX.FootstepShake
				if not allow or allow(model) then DinosaurVFX.Shake(0.12 * s, 0.35, foot.WorldPosition, 40 * s) end
				-- (cracks at most every 0.4 s per animal: a boss at a run stepped 3-4 times a second, ~35 parts each)
				local now = os.clock()
				if now >= (crackAt[model] or 0) then
					crackAt[model] = now + 0.4
					DinosaurVFX.GroundCracks(foot.WorldPosition, s * 0.7)
				end
			end
		end
	elseif name == "Roar" then
		local mouth = findAttachment(model, "VFX_Mouth")
		if mouth then
			local head = findAttachment(model, "VFX_Head")
			local dir = head and (mouth.WorldPosition - head.WorldPosition) or mouth.WorldCFrame.LookVector
			local cf = CFrame.lookAt(mouth.WorldPosition, mouth.WorldPosition + dir)
			local sc = (arg and arg.Scale) or s
			DinosaurVFX.RoarShockwave(cf, sc, arg and arg.Screech)
			DinosaurVFX.Spittle(cf, sc)
			local foot = findAttachment(model, "VFX_RightFoot")
			local groundY = foot and foot.WorldPosition.Y or model:GetPivot().Y
			local under = Vector3.new(mouth.WorldPosition.X, groundY + 0.2, mouth.WorldPosition.Z)
			DinosaurVFX.DustWave(under, dir, sc)
			if sc > 1.2 then
				task.delay(0.35, function() DinosaurVFX.FallingLeaves(model:GetPivot().Position, 14 * sc / 1.9, math.floor(14 * sc), 10 * sc / 1.9 + 6) end)
			end
		end
	elseif name == "CameraShake" then
		DinosaurVFX.Shake(arg or 0.5, 0.5 + (arg or 0.5) * 0.9, model:GetPivot().Position, 50 * s)
	elseif name == "Growl" then
		DinosaurVFX.Shake(0.15 * s, 0.6, model:GetPivot().Position, 40 * s)
	elseif name == "Bite" then
		local mouth = findAttachment(model, "VFX_Mouth")
		if mouth then DinosaurVFX.BiteImpact(mouth.WorldPosition, (arg and arg.Scale) or s) end
	elseif name == "EyeGlow" then
		DinosaurVFX.EyeGlow(model, arg)
	elseif name == "TailSwing" then
		DinosaurVFX.TailSwing(model, arg)
	elseif name == "Land" or name == "JumpDust" then
		-- feet are near the ground at take-off / landing, so use them for the ground height
		local pivot = model:GetPivot()
		local foot = findAttachment(model, "VFX_RightFoot")
		local ground = Vector3.new(pivot.X, foot and foot.WorldPosition.Y or pivot.Y, pivot.Z)
		if name == "Land" then
			DinosaurVFX.GroundImpact(ground, (arg and arg.Scale) or s)
			DinosaurVFX.GroundCracks(ground, ((arg and arg.Scale) or s) * 1.2)
		else DinosaurVFX.FootstepDust(ground, (arg and arg.Scale) or s) end
	elseif name == "Stunned" then
		DinosaurVFX.Stunned(model, 2.2)
	elseif name == "Sniff" then
		local mouth = findAttachment(model, "VFX_Mouth")
		if mouth then
			burst(mouth.WorldCFrame, 3, { Speed = NumberRange.new(1, 2), Size = NumberSequence.new(0.3 * s, 0.9 * s), Color = Color3.fromRGB(230, 230, 230), Transparency = NumberSequence.new(0.6, 1) })
		end
	elseif name == "CurtainClose" then
		DinosaurVFX.Curtain(model, false)
	elseif name == "CurtainOpen" then
		DinosaurVFX.Curtain(model, true)
	elseif name == "BreakProp" then
		local at = arg and arg.At and findAttachment(model, arg.At)
		DinosaurVFX.BreakProp(model, arg.Prop, arg.Power, at and at.WorldPosition)
	elseif name == "FellTrees" then
		DinosaurVFX.FellTrees(model, arg.Prop)
	elseif name == "GateHit" then
		DinosaurVFX.GateHit(model, arg.Prop, arg.Stage or 1)
	elseif name == "Impact" then
		-- ground impact under an attachment (head-butt, tail club, stomp)
		local at = findAttachment(model, (arg and arg.At) or "VFX_Head")
		if at then
			local foot = findAttachment(model, "VFX_RightFoot")
			local gy = foot and foot.WorldPosition.Y or at.WorldPosition.Y
			local pos = Vector3.new(at.WorldPosition.X, gy, at.WorldPosition.Z)
			local sc = (arg and arg.Scale) or s
			DinosaurVFX.GroundImpact(pos, sc)
			DinosaurVFX.GroundCracks(pos, sc)
			DinosaurVFX.Shake(0.3 * sc, 0.6, pos, 60 * sc)
		end
	elseif name == "Charge" then
		DinosaurVFX.ChargeDust(model, arg or 2)
	elseif name == "Call" then
		local col = arg and arg.Color
		if type(col) == "table" then col = Color3.fromRGB(col[1], col[2], col[3]) end
		DinosaurVFX.SoundRings(model, (arg and arg.At) or "VFX_Mouth", (arg and arg.Scale) or s, col, arg and arg.Count)
	elseif name == "Scrape" then
		local at = findAttachment(model, (arg and arg.At) or "VFX_RightFoot")
		if at then
			DinosaurVFX.FootstepDust(at.WorldPosition + at.WorldCFrame.LookVector * 0.5, s * 0.9)
			cubes(at.WorldPosition, 4, DIRT, 0.2 * s, 6, 0.6)
		end
	elseif name == "Flush" then
		DinosaurVFX.PlateFlush(model, arg or 3)
	elseif name == "Rustle" then
		DinosaurVFX.Rustle(model)
	elseif name == "Alarm" then
		DinosaurVFX.Alarm(model, arg or 8)
	elseif name == "HerdCall" then
		DinosaurVFX.SoundRings(model, (arg and arg.At) or "VFX_Crest", (arg and arg.Scale) or s, nil, 5)
		DinosaurVFX.HerdCall(model)
	elseif name == "Splash" then
		local at = findAttachment(model, (arg and arg.At) or "VFX_Head")
		if at then
			local y = waterSurfaceY(model, at.WorldPosition.Y)
			DinosaurVFX.WaterSplash(Vector3.new(at.WorldPosition.X, y, at.WorldPosition.Z), (arg and arg.Scale) or s)
		end
	elseif name == "FoliageBurst" then
		local head = findAttachment(model, "VFX_Head")
		if head then
			DinosaurVFX.FoliageBurst(head.WorldPosition, (arg and arg.Scale) or 1)
			DinosaurVFX.FallingLeaves(head.WorldPosition, 6 * s / 2, 18, 4 + s)
		end
	elseif DinosaurVFX.Extra[name] then
		-- species events added by the Extra_* modules (2026-10-12 roster expansion)
		DinosaurVFX.Extra[name](model, arg, s)
	end
end

-- shared building blocks for gameplay effects
DinosaurVFX.Cubes = cubes
DinosaurVFX.Burst = burst
DinosaurVFX.BlockRing = blockRing
DinosaurVFX.Folder = folder
DinosaurVFX.findAttachment = DinosaurVFX.findAttachment or findAttachment

-- Extra_<Group> child modules: each returns function(VFX) and registers VFX.Extra[EventName] = function(model, arg, scale)
-- (new species' signature effects live there, one module per era, so parallel work never edits this file)
DinosaurVFX.Extra = DinosaurVFX.Extra or {}
for _, child in ipairs(script:GetChildren()) do
	if child:IsA("ModuleScript") and string.sub(child.Name, 1, 6) == "Extra_" then
		local ok, fn = pcall(require, child)
		if ok and type(fn) == "function" then
			local ok2, err = pcall(fn, DinosaurVFX)
			if not ok2 then warn("[DinosaurVFX] " .. child.Name .. ": " .. tostring(err)) end
		else
			warn("[DinosaurVFX] " .. child.Name .. " failed to load: " .. tostring(fn))
		end
	end
end

return DinosaurVFX
