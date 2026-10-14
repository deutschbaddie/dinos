--[[
	Icons3D — every icon in the UI is a tiny 3D model rendered in a ViewportFrame, built from the same
	chunky studded bricks as the world (and, where it fits, the real game models: eggs, babies, vehicles).

	Icons3D.Make(name, opts) -> ViewportFrame        opts: { Size, Position, AnchorPoint, ZIndex, Spin, Species, Vehicle, Tint }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Dino = ReplicatedStorage:WaitForChild("DinoExpedition")

local Icons3D = {}
local cache = {}
local spinners = setmetatable({}, { __mode = "k" })

local function part(m: Model, size: Vector3, cf: CFrame, color: Color3, props: any?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then for k, v in pairs(props) do (p :: any)[k] = v end end
	p.Parent = m
	return p
end
local function cyl(m, len, d, cf, color, props)
	local p = part(m, Vector3.new(len, d, d), cf, color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function studs(p: Part) p.TopSurface = Enum.SurfaceType.Studs p.Material = Enum.Material.Plastic end

local rgb = Color3.fromRGB
local BUILD = {}

BUILD.Coin = function(m)
	local face = CFrame.Angles(0, 0, 0)
	cyl(m, 0.6, 4, face, rgb(214, 150, 20), { Material = Enum.Material.Metal })
	cyl(m, 0.7, 3.2, face, rgb(255, 200, 50))
	cyl(m, 0.74, 2.2, face, rgb(255, 226, 120))
	local st = part(m, Vector3.new(0.5, 1.1, 1.1), CFrame.new(0.5, 0, 0), rgb(255, 200, 50))
	st.Shape = Enum.PartType.Cylinder
	return CFrame.Angles(0.25, -0.9, 0), 1.0
end

BUILD.Gear = function(m)
	local axis = CFrame.Angles(0, math.pi / 2, 0)
	cyl(m, 0.8, 3.2, axis, rgb(150, 156, 168), { Material = Enum.Material.Metal })
	cyl(m, 0.9, 1.3, axis, rgb(60, 64, 72))
	for k = 0, 7 do
		local a = k * math.pi / 4
		part(m, Vector3.new(0.9, 0.9, 0.8), CFrame.Angles(0, 0, a) * CFrame.new(1.75, 0, 0), rgb(150, 156, 168), { Material = Enum.Material.Metal })
	end
	return CFrame.Angles(0.15, 0.3, 0), 1.0
end

BUILD.Wrench = function(m)
	part(m, Vector3.new(0.7, 4.2, 0.5), CFrame.new(0, -0.6, 0), rgb(184, 190, 196), { Material = Enum.Material.Metal })
	part(m, Vector3.new(0.75, 1.6, 0.55), CFrame.new(0, -2.0, 0), rgb(232, 64, 52))
	part(m, Vector3.new(0.6, 1.2, 0.5), CFrame.new(-0.55, 1.95, 0), rgb(184, 190, 196), { Material = Enum.Material.Metal })
	part(m, Vector3.new(0.6, 1.2, 0.5), CFrame.new(0.55, 1.95, 0), rgb(184, 190, 196), { Material = Enum.Material.Metal })
	part(m, Vector3.new(1.7, 0.6, 0.5), CFrame.new(0, 1.35, 0), rgb(184, 190, 196), { Material = Enum.Material.Metal })
	return CFrame.Angles(0, 0.4, -0.75), 1.0
end

BUILD.Gate = function(m)
	local R = 2.2
	for k = 0, 5 do
		local a0, a1 = k * math.pi / 3, (k + 1) * math.pi / 3
		local p0, p1 = Vector3.new(math.cos(a0) * R, math.sin(a0) * R, 0), Vector3.new(math.cos(a1) * R, math.sin(a1) * R, 0)
		local mid = (p0 + p1) / 2
		part(m, Vector3.new((p1 - p0).Magnitude + 0.5, 0.55, 0.7), CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(p1.Y - p0.Y, p1.X - p0.X)), rgb(60, 64, 72))
		part(m, Vector3.new(0.7, 0.7, 0.8), CFrame.new(p0) * CFrame.Angles(0, 0, a0), rgb(255, 196, 46))
	end
	for k = 0, 2 do part(m, Vector3.new(1.9, 3.3, 0.15), CFrame.Angles(0, 0, k * math.pi / 3), rgb(63, 224, 200), { Material = Enum.Material.Neon, Transparency = 0.15 }) end
	return CFrame.Angles(0, 0.35, 0), 1.0
end

BUILD.Home = function(m)
	local b = part(m, Vector3.new(3, 2, 2.6), CFrame.new(0, -0.6, 0), rgb(233, 223, 196))
	studs(b)
	local w = Instance.new("WedgePart")
	w.Anchored = true w.Size = Vector3.new(3.6, 1.4, 1.6) w.Color = rgb(232, 64, 52)
	w.CFrame = CFrame.new(0, 1.1, -0.75) * CFrame.Angles(0, math.pi, 0) w.Parent = m
	local w2 = w:Clone() w2.CFrame = CFrame.new(0, 1.1, 0.75) w2.Parent = m
	part(m, Vector3.new(0.8, 1.2, 0.1), CFrame.new(0, -1.0, -1.35), rgb(47, 107, 58))
	return CFrame.Angles(0.25, 0.6, 0), 1.05
end

BUILD.Shield = function(m)
	local p = part(m, Vector3.new(3, 3, 0.6), CFrame.new(0, 0.3, 0), rgb(242, 182, 50))
	studs(p)
	local w = Instance.new("WedgePart")
	w.Anchored = true w.Size = Vector3.new(0.6, 1.4, 1.5) w.Color = rgb(242, 182, 50)
	w.CFrame = CFrame.new(-0.75, -1.9, 0) * CFrame.Angles(0, math.pi / 2, math.pi) w.Parent = m
	local w2 = w:Clone() w2.CFrame = CFrame.new(0.75, -1.9, 0) * CFrame.Angles(0, -math.pi / 2, math.pi) w2.Parent = m
	part(m, Vector3.new(0.6, 2.6, 0.65), CFrame.new(0, 0, 0), rgb(47, 107, 58))
	part(m, Vector3.new(2.4, 0.6, 0.65), CFrame.new(0, 0.6, 0), rgb(47, 107, 58))
	return CFrame.Angles(0.1, 0.4, 0), 1.0
end

BUILD.Bolt = function(m)
	local c = rgb(120, 230, 255)
	part(m, Vector3.new(0.9, 2.2, 0.7), CFrame.new(0.4, 1.0, 0) * CFrame.Angles(0, 0, -0.45), c, { Material = Enum.Material.Neon })
	part(m, Vector3.new(2.0, 0.7, 0.7), CFrame.new(0, 0, 0), c, { Material = Enum.Material.Neon })
	part(m, Vector3.new(0.9, 2.2, 0.7), CFrame.new(-0.4, -1.0, 0) * CFrame.Angles(0, 0, -0.45), c, { Material = Enum.Material.Neon })
	return CFrame.Angles(0, 0.3, 0), 1.05
end

BUILD.Dart = function(m)
	local axis = CFrame.Angles(0, 0, 0)
	cyl(m, 3.2, 0.55, axis, rgb(184, 190, 196), { Material = Enum.Material.Metal })
	cyl(m, 1.1, 0.75, CFrame.new(-0.6, 0, 0), rgb(63, 224, 200), { Material = Enum.Material.Neon })
	part(m, Vector3.new(1.0, 0.18, 0.18), CFrame.new(2.1, 0, 0), rgb(240, 240, 240), { Material = Enum.Material.Metal })
	for k = 0, 2 do
		part(m, Vector3.new(0.9, 0.9, 0.08), CFrame.new(-1.5, 0, 0) * CFrame.Angles(k * math.pi * 2 / 3, 0, 0) * CFrame.new(0, 0.45, 0), rgb(255, 138, 36))
	end
	return CFrame.Angles(0, 0.5, 0.6), 1.0
end

BUILD.Star = function(m)
	for k = 0, 4 do
		local w = Instance.new("WedgePart")
		w.Anchored = true w.Size = Vector3.new(0.6, 1.8, 1.1) w.Color = rgb(255, 196, 46)
		w.CFrame = CFrame.Angles(0, 0, k * math.pi * 2 / 5) * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.pi / 2, 0) w.Parent = m
	end
	cyl(m, 0.7, 1.9, CFrame.Angles(0, math.pi / 2, 0), rgb(255, 214, 92))
	return CFrame.Angles(0, 0.3, 0), 1.0
end

BUILD.Lock = function(m)
	local b = part(m, Vector3.new(2.6, 2.2, 1.0), CFrame.new(0, -0.6, 0), rgb(255, 196, 46))
	studs(b)
	part(m, Vector3.new(0.35, 1.4, 0.4), CFrame.new(-0.8, 1.0, 0), rgb(184, 190, 196), { Material = Enum.Material.Metal })
	part(m, Vector3.new(0.35, 1.4, 0.4), CFrame.new(0.8, 1.0, 0), rgb(184, 190, 196), { Material = Enum.Material.Metal })
	part(m, Vector3.new(1.95, 0.35, 0.4), CFrame.new(0, 1.6, 0), rgb(184, 190, 196), { Material = Enum.Material.Metal })
	part(m, Vector3.new(0.4, 0.7, 0.1), CFrame.new(0, -0.6, -0.55), rgb(40, 40, 46))
	return CFrame.Angles(0.1, 0.35, 0), 1.0
end

BUILD.Eye = function(m)
	local e = part(m, Vector3.new(3.2, 2.0, 1), CFrame.new(), rgb(250, 250, 250))
	local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = e
	local p = part(m, Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 0, -0.25), rgb(232, 64, 52), { Shape = Enum.PartType.Ball })
	part(m, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0, -0.62), rgb(20, 20, 24), { Shape = Enum.PartType.Ball })
	return CFrame.Angles(0, 0, 0), 1.05
end

BUILD.Alert = function(m)
	part(m, Vector3.new(0.9, 2.4, 0.9), CFrame.new(0, 0.6, 0), rgb(232, 64, 52))
	part(m, Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, -1.4, 0), rgb(232, 64, 52))
	return CFrame.Angles(0, 0.5, 0), 1.0
end

BUILD.Trophy = function(m)
	cyl(m, 0.5, 2.2, CFrame.new(0, -1.7, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(60, 64, 72))
	part(m, Vector3.new(0.5, 1.2, 0.5), CFrame.new(0, -0.9, 0), rgb(255, 196, 46), { Material = Enum.Material.Metal })
	local cup = part(m, Vector3.new(2.4, 1.8, 2.4), CFrame.new(0, 0.6, 0), rgb(255, 196, 46), { Material = Enum.Material.Metal })
	studs(cup)
	part(m, Vector3.new(0.4, 1.0, 0.4), CFrame.new(-1.4, 0.7, 0), rgb(255, 196, 46), { Material = Enum.Material.Metal })
	part(m, Vector3.new(0.4, 1.0, 0.4), CFrame.new(1.4, 0.7, 0), rgb(255, 196, 46), { Material = Enum.Material.Metal })
	return CFrame.Angles(0.15, 0.4, 0), 1.0
end

-- icons made from the real game models
local function fromTemplate(folder: string, name: string): Model?
	local f = Dino:FindFirstChild(folder)
	local t = f and f:FindFirstChild(name)
	if not t then return nil end
	local m = t:Clone() :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ProximityPrompt") or d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	return m
end

local function frameModel(vp: ViewportFrame, m: Model, view: CFrame, zoom: number, spin: boolean)
	m:PivotTo(view)
	m.Parent = vp
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 26
	local dist = (size.Magnitude * 0.5) / math.tan(math.rad(13)) * (1 / zoom)
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0, -dist), cf.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	if spin then spinners[vp] = { Model = m, Base = view, Center = cf.Position, A = math.random() * 6 } end
end

function Icons3D.Make(name: string, opts)
	opts = opts or {}
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Icon_" .. name
	vp.BackgroundTransparency = 1
	vp.Size = opts.Size or UDim2.fromOffset(40, 40)
	vp.Position = opts.Position or UDim2.new()
	vp.AnchorPoint = opts.AnchorPoint or Vector2.zero
	vp.ZIndex = opts.ZIndex or 6
	vp.Ambient = Color3.fromRGB(190, 190, 200)
	vp.LightColor = Color3.fromRGB(255, 246, 232)
	vp.LightDirection = Vector3.new(-0.5, -1, 0.6)
	local m: Model?
	local view, zoom = CFrame.new(), 1
	if name == "Egg" then
		m = fromTemplate("Eggs", (opts.Species or "Velociraptor") .. "Egg")
		view, zoom = CFrame.Angles(0.15, 2.6, 0), 1.05
	elseif name == "Dino" then
		m = fromTemplate("Babies", opts.Species or "Velociraptor")
		view, zoom = CFrame.Angles(0, 2.4, 0), 1.0
	elseif name == "Jeep" then
		m = fromTemplate("Vehicles", opts.Vehicle or "RookieRanger")
		view, zoom = CFrame.Angles(0.12, 2.35, 0), 1.0
	else
		local builder = BUILD[name]
		if builder then
			m = Instance.new("Model")
			view, zoom = builder(m)
		end
	end
	if m then
		if opts.Silhouette then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and d.Transparency < 1 then d.Color = Color3.fromRGB(16, 16, 22) d.Material = Enum.Material.SmoothPlastic end
			end
		end
		frameModel(vp, m, view, zoom * (opts.Zoom or 1), opts.Spin == true)
	end
	if opts.Parent then vp.Parent = opts.Parent end
	return vp
end

-- a gentle idle rotation on icons that asked for it
RunService.RenderStepped:Connect(function(dt)
	for vp, s in pairs(spinners) do
		if vp.Parent and vp.Visible then
			s.A += dt * 0.8
			s.Model:PivotTo(CFrame.new(s.Center) * CFrame.Angles(0, s.A, 0) * CFrame.new(-s.Center) * s.Base)
		end
	end
end)

function Icons3D.Spin(vp: ViewportFrame, on: boolean)
	local s = spinners[vp]
	if s then s.Fast = on end
end

return Icons3D
