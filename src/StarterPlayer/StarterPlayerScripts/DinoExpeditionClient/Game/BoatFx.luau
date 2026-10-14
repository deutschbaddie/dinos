--[[
	BoatFx — when a rover is out on deep water (Spine River's Sea Lane, the ford) it becomes a boat: a hull skirt
	in its paint colour, a bow wave, a foaming wake behind and spray when it boosts. Purely local visuals: the
	parts live in a client folder and follow the rover's root every frame (nothing is added to the server model).
	Underglow is hidden on water. Every rover in view is dressed, yours and other players'.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BoatFx = {}
local folder: Folder? = nil
local boats = {} :: { [Model]: any }

local waterRay = RaycastParams.new()
waterRay.FilterType = Enum.RaycastFilterType.Include
waterRay.IgnoreWater = false

-- the water surface under a point, if it's deep enough to float on (nil on land / shallows)
local function deepWater(p: Vector3): number?
	waterRay.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -14, 0), waterRay)
	if hit and hit.Material == Enum.Material.Water then return hit.Position.Y end
	return nil
end

local function part(parent: Instance, name: string, size: Vector3, color: Color3, mat: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = 1
	p.Parent = parent
	return p
end

local function emitter(host: BasePart, rate: number, life: number, speed: number, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, -14, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
	e.LightEmission = 0.1
	e.Parent = host
	e:SetAttribute("BaseRate", rate)
	return e
end

local function paintOf(v: Model): Color3
	-- the body colour: the biggest non-wheel part
	local best, area = Color3.fromRGB(230, 200, 90), 0
	for _, d in ipairs(v:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.5 and not d.Name:find("Tire") and not d.Name:find("Wheel") and not d.Name:find("Rim") then
			local a = d.Size.X * d.Size.Z
			if a > area and d.Size.Y < 4 then best, area = d.Color, a end
		end
	end
	return best
end

local function dress(v: Model)
	local root = v.PrimaryPart
	if not root or not folder then return nil end
	local W = ((v:GetAttribute("Width") or 8) :: number) + 1.2
	local L = ((v:GetAttribute("Length") or 16) :: number) * 0.92
	local RH = v:GetAttribute("RootHeight") or 2.6
	local m = Instance.new("Model")
	m.Name = "Boat_" .. v.Name
	local paint = paintOf(v)
	local b = {}
	-- the hull: a deep body, a raked bow, a white waterline stripe, a dark keel
	b.Hull = part(m, "Hull", Vector3.new(W, 2.4, L * 0.78), paint)
	b.Bow = part(m, "Bow", Vector3.new(W, 2.4, L * 0.24), paint)
	local bowMesh = Instance.new("SpecialMesh")
	bowMesh.MeshType = Enum.MeshType.Wedge
	bowMesh.Parent = b.Bow
	b.Stripe = part(m, "Stripe", Vector3.new(W + 0.12, 0.45, L * 0.78 + 0.1), Color3.fromRGB(245, 245, 240))
	b.Keel = part(m, "Keel", Vector3.new(W * 0.5, 0.8, L * 0.8), Color3.fromRGB(40, 44, 50))
	b.Fx = part(m, "BowFx", Vector3.new(W, 0.2, 0.2), paint)
	b.Back = part(m, "WakeFx", Vector3.new(W, 0.2, 0.2), paint)
	b.Spray = emitter(b.Fx, 50, 0.5, 14, 1.2)
	b.Wake = emitter(b.Back, 40, 1.4, 4, 2.2)
	m.Parent = folder
	return { Model = m, Parts = b, Root = root, W = W, L = L, RH = RH, On = 0, Vehicle = v }
end

local function setUnderglow(v: Model, hidden: boolean)
	local u = v:FindFirstChild("Underglow", true)
	if not u then return end
	for _, d in ipairs(u:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = hidden and 1 or 0 end
	end
end

function BoatFx.Start()
	local f = Instance.new("Folder")
	f.Name = "DinoBoats"
	f.Parent = Workspace
	folder = f
	local scanAt = 0
	RunService.RenderStepped:Connect(function(dt)
		if not Workspace:FindFirstChild("SpineRiver") then return end -- only Spine River has water to float on
		local now = os.clock()
		local av = Workspace:FindFirstChild("ActiveVehicles")
		if av and now >= scanAt then
			scanAt = now + 0.5
			for _, v in ipairs(av:GetChildren()) do
				if v:IsA("Model") and not boats[v] and v.PrimaryPart then boats[v] = dress(v) or false end
			end
		end
		for v, b in pairs(boats) do
			if not b then continue end
			if not v.Parent or not b.Root.Parent then
				b.Model:Destroy()
				boats[v] = nil
				continue
			end
			local rc = b.Root.CFrame
			local surf = deepWater(rc.Position)
			local afloat = surf ~= nil and (rc.Position.Y - b.RH) < surf + 0.6
			local target = afloat and 1 or 0
			if target ~= (b.Was or 0) then
				b.Was = target
				setUnderglow(v, afloat)
				if afloat then require(script.Parent.Audio).Play("Splash", { At = rc.Position, Pitch = 0.8, Volume = 1.3, Gap = 0.3 }) end
			end
			b.On += (target - b.On) * math.min(1, dt * 6)
			local tr = 1 - b.On
			local base = rc * CFrame.new(0, -b.RH + 1.0, 0)
			local p = b.Parts
			p.Hull.CFrame = base * CFrame.new(0, 0, b.L * 0.1)
			p.Bow.CFrame = base * CFrame.new(0, 0, -b.L * 0.39 + b.L * 0.1) * CFrame.Angles(0, 0, math.pi) -- raked: deck flat on top, slope underneath
			p.Stripe.CFrame = base * CFrame.new(0, 0.9, b.L * 0.1)
			p.Keel.CFrame = base * CFrame.new(0, -1.4, b.L * 0.05)
			for _, x in ipairs({ p.Hull, p.Bow, p.Stripe, p.Keel }) do x.Transparency = tr > 0.98 and 1 or tr end
			-- bow spray + wake at the waterline, by speed
			local v3 = b.Root.AssemblyLinearVelocity
			local speed = Vector3.new(v3.X, 0, v3.Z).Magnitude
			if surf then
				p.Fx.CFrame = CFrame.new(Vector3.new(0, surf + 0.3 - (rc * CFrame.new(0, 0, -b.L * 0.5)).Position.Y, 0) + (rc * CFrame.new(0, 0, -b.L * 0.5)).Position) * rc.Rotation
				p.Back.CFrame = CFrame.new(Vector3.new(0, surf + 0.2 - (rc * CFrame.new(0, 0, b.L * 0.5)).Position.Y, 0) + (rc * CFrame.new(0, 0, b.L * 0.5)).Position) * rc.Rotation
			end
			local k = afloat and math.clamp(speed / 40, 0, 1.4) or 0
			p.Spray.Rate = k * 60
			p.Wake.Rate = k * 45
		end
	end)
	local _ = Players
end

return BoatFx
