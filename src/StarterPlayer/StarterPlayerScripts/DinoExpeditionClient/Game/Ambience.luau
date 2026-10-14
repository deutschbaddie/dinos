--[[
	Ambience — the world is alive around you, everywhere, cheaply: glowing motes drifting in the light, leaves
	tumbling down, butterflies flitting near the ground (cutscenes only, never at camp) and birds wheeling overhead. Everything is local, follows
	the camera and is sized to the zone's palette. Lower graphics settings get fewer of everything.
]]

local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Workspace = game:GetService("Workspace")

local Zone = require(script.Parent.Zone)
local Cinema = require(script.Parent.UI.Cinema)

local Ambience = {}

-- per zone: motes (colour), leaves (colours, rate), butterflies (count, colours), birds (count)
local LOOK = {
	BaseCamp = { Motes = Color3.fromRGB(255, 236, 170), MoteRate = 5, Leaves = { Color3.fromRGB(120, 200, 70), Color3.fromRGB(255, 170, 60) }, LeafRate = 1.5,
		Butterflies = 0, Wings = { Color3.fromRGB(255, 140, 60), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 230, 90) }, Birds = 4 },
	FernValley = { Motes = Color3.fromRGB(220, 255, 170), MoteRate = 8, Leaves = { Color3.fromRGB(90, 190, 70), Color3.fromRGB(150, 220, 80), Color3.fromRGB(255, 160, 50) }, LeafRate = 4,
		Butterflies = 8, Wings = { Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 220, 70) }, Birds = 6 },
	GiantPlains = { Motes = Color3.fromRGB(255, 220, 160), MoteRate = 10, Leaves = { Color3.fromRGB(220, 190, 110), Color3.fromRGB(190, 160, 90) }, LeafRate = 2,
		Butterflies = 4, Wings = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 255, 255) }, Birds = 8 },
	SpineRiver = { Motes = Color3.fromRGB(190, 250, 240), MoteRate = 9, Leaves = { Color3.fromRGB(70, 180, 80), Color3.fromRGB(120, 210, 90) }, LeafRate = 3,
		Butterflies = 10, Wings = { Color3.fromRGB(60, 190, 255), Color3.fromRGB(120, 255, 210), Color3.fromRGB(255, 120, 200) }, Birds = 10 },
	-- snow falls as the motes (MoteFall), golden ginkgo leaves + ash flakes + snow clumps tumble, no butterflies in winter
	FrostForest = { Motes = Color3.fromRGB(248, 252, 255), MoteRate = 22, MoteFall = true, Leaves = { Color3.fromRGB(255, 196, 40), Color3.fromRGB(240, 168, 30), Color3.fromRGB(70, 68, 76), Color3.fromRGB(245, 248, 255) }, LeafRate = 2.5,
		Butterflies = 0, Wings = { Color3.fromRGB(255, 255, 255) }, Birds = 3 },
	-- warm dust, a few fern fronds; the "butterflies" are teal dragonflies and the birds early pterosaurs (no birds yet)
	DawnDesert = { Motes = Color3.fromRGB(255, 196, 150), MoteRate = 9, Leaves = { Color3.fromRGB(90, 176, 70), Color3.fromRGB(122, 196, 84) }, LeafRate = 0.8,
		Butterflies = 3, Wings = { Color3.fromRGB(70, 210, 200), Color3.fromRGB(120, 150, 255) }, Birds = 5 },
	-- warm sand motes, a few dry saxaul leaves, hardly any butterflies in the desert
	RedCliffs = { Motes = Color3.fromRGB(255, 196, 136), MoteRate = 11, Leaves = { Color3.fromRGB(168, 172, 90), Color3.fromRGB(214, 168, 108), Color3.fromRGB(196, 120, 80) }, LeafRate = 1,
		Butterflies = 2, Wings = { Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 240, 210) }, Birds = 5 },
}

local folder: Folder
local anchor: Part
local motes: ParticleEmitter
local leafParts = {} :: { any }
local critters = {} :: { any }
local current = nil

local function quality(): number
	-- 0..1 from the player's graphics slider (automatic counts as mid)
	local q = UserGameSettings.SavedQualityLevel.Value
	if q == 0 then return 0.6 end
	return math.clamp(q / 10, 0.25, 1)
end

local function part(size: Vector3, color: Color3, parent: Instance, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function clearCritters()
	for _, c in ipairs(critters) do c.Model:Destroy() end
	table.clear(critters)
end

local function butterfly(color: Color3): any
	local m = Instance.new("Model")
	local l = part(Vector3.new(0.5, 0.05, 0.4), color, m)
	local r = part(Vector3.new(0.5, 0.05, 0.4), color, m)
	local body = part(Vector3.new(0.1, 0.1, 0.4), Color3.fromRGB(40, 30, 30), m)
	m.Parent = folder
	return { Model = m, L = l, R = r, Body = body, Kind = "Butterfly", Seed = math.random() * 100, Home = nil }
end

local function bird(): any
	local m = Instance.new("Model")
	local col = Color3.fromRGB(40, 36, 44)
	local l = part(Vector3.new(1.8, 0.12, 0.5), col, m)
	local r = part(Vector3.new(1.8, 0.12, 0.5), col, m)
	m.Parent = folder
	return { Model = m, L = l, R = r, Kind = "Bird", Seed = math.random() * 100, Radius = 50 + math.random() * 60, Height = 70 + math.random() * 40 }
end

local function setZone(zone: string)
	if zone == current then return end
	current = zone
	clearCritters()
	local look = LOOK[zone]
	if not look then
		motes.Enabled = false
		for _, l in ipairs(leafParts) do l.Part:Destroy() end
		table.clear(leafParts)
		return
	end
	local q = quality()
	motes.Color = ColorSequence.new(look.Motes)
	motes.Rate = look.MoteRate * q
	motes.Enabled = true
	-- snow: falling, matte, a touch bigger; everything else keeps the glowing upward drift
	local fall = (look :: any).MoteFall == true
	motes.Acceleration = fall and Vector3.new(0.6, -1.4, 0.3) or Vector3.new(0, 0.15, 0)
	motes.LightEmission = fall and 0 or 1
	motes.Speed = fall and NumberRange.new(1, 2) or NumberRange.new(0.3, 1)
	motes.Size = fall and NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.1, 0.32), NumberSequenceKeypoint.new(0.9, 0.28), NumberSequenceKeypoint.new(1, 0) })
		or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 0) })
	-- leaves: little tumbling blocks recycled around the camera (a particle texture would read as glitter)
	for _, l in ipairs(leafParts) do l.Part:Destroy() end
	table.clear(leafParts)
	for i = 1, math.floor(look.LeafRate * 5 * q + 0.5) do
		local lp = part(Vector3.new(0.45, 0.06, 0.32), look.Leaves[(i - 1) % #look.Leaves + 1], folder)
		table.insert(leafParts, { Part = lp, Pos = nil, Seed = math.random() * 100, Fall = 2 + math.random() * 2 })
	end
	for i = 1, math.floor(look.Butterflies * q + 0.5) do table.insert(critters, butterfly(look.Wings[(i - 1) % #look.Wings + 1])) end
	for _ = 1, math.floor(look.Birds * q + 0.5) do table.insert(critters, bird()) end
end

function Ambience.Start()
	folder = Instance.new("Folder")
	folder.Name = "DinoAmbience"
	folder.Parent = Workspace
	anchor = part(Vector3.new(110, 34, 110), Color3.new(), folder)
	anchor.Transparency = 1
	motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new(0.25)
	motes.Lifetime = NumberRange.new(6, 9)
	motes.Speed = NumberRange.new(0.3, 1)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Acceleration = Vector3.new(0, 0.15, 0)
	motes.Enabled = false
	motes.Parent = anchor
	setZone(Zone.Current)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc > 0.5 then
			acc = 0
			setZone(Zone.Current)
		end
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local cp = cam.CFrame.Position
		anchor.CFrame = CFrame.new(cp + Vector3.new(0, 6, 0))
		local t = os.clock()
		-- butterflies are set dressing for cutscenes; out in the open world they'd just flutter in your face
		local inCine = Cinema.Playing() or cam.CameraType == Enum.CameraType.Scriptable
		for _, l in ipairs(leafParts) do
			-- drift down and sideways, tumbling; start again above you once it's low or far
			if not l.Pos or l.Pos.Y < cp.Y - 14 or (Vector3.new(l.Pos.X - cp.X, 0, l.Pos.Z - cp.Z)).Magnitude > 50 then
				local a = math.random() * math.pi * 2
				local r = 6 + math.random() * 38
				l.Pos = cp + Vector3.new(math.cos(a) * r, 16 + math.random() * 14, math.sin(a) * r)
			end
			local s = l.Seed
			l.Pos += Vector3.new(math.sin(t * 1.3 + s) * 1.6 + 0.6, -l.Fall, math.cos(t * 1.1 + s) * 1.2) * dt
			l.Part.CFrame = CFrame.new(l.Pos) * CFrame.Angles(t * 2.1 + s, t * 1.4 + s, math.sin(t * 3 + s) * 0.8)
		end
		for _, c in ipairs(critters) do
			local s = c.Seed
			if c.Kind == "Butterfly" then
				c.Model.Parent = inCine and folder or nil
				if not inCine then
					c.Home = nil
					continue
				end
				-- a lazy loop near the ground around wherever you are, wings beating fast
				c.Home = c.Home and c.Home:Lerp(cp, dt * 0.15) or cp
				local h = c.Home
				local p = h + Vector3.new(math.noise(t * 0.15, s) * 26, 0, math.noise(s, t * 0.15) * 26)
				local hit = Workspace:Raycast(p + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0))
				local y = (hit and hit.Position.Y or (cp.Y - 4)) + 1.6 + math.sin(t * 1.3 + s) * 0.6
				local pos = Vector3.new(p.X, y, p.Z)
				local dir = Vector3.new(math.noise(t * 0.15 + 0.1, s) - math.noise(t * 0.15, s), 0, math.noise(s, t * 0.15 + 0.1) - math.noise(s, t * 0.15))
				local cf = dir.Magnitude > 1e-4 and CFrame.lookAt(pos, pos + dir) or CFrame.new(pos)
				local flap = math.sin(t * 22 + s) * 0.9
				c.Body.CFrame = cf
				c.L.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.27, 0, 0)
				c.R.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.27, 0, 0)
			else
				-- a slow wheel high overhead
				local a = t * (6 / c.Radius) + s
				local pos = Vector3.new(cp.X + math.cos(a) * c.Radius, cp.Y + c.Height + math.sin(t * 0.3 + s) * 4, cp.Z + math.sin(a) * c.Radius)
				local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
				local cf = CFrame.lookAt(pos, pos + tangent)
				local flap = math.sin(t * 6 + s) * 0.45
				c.L.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.85, 0, 0)
				c.R.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.85, 0, 0)
			end
		end
	end)
end

return Ambience
