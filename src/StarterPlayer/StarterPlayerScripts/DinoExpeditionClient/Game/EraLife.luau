--[[
	EraLife — the valley is alive while you roam it (2026-10-14, free roam). Reads the era map's LifePaths folder
	(tools/gen/fernValley.js writes Fern Valley's; any era that gets one comes alive the same way).

	  HERDS       LifePath markers: a family of one species strung out along a path of ground points, the grown-ups
	              in front and the young behind. Open paths are walked there and back (at each end they mill about,
	              look round, call); loops just keep going. Now and then they stop to graze. Get close and they spook:
	              a call, they part to both sides of the trail and trot on, then settle back into line.
	  PTEROSAURS  LifePerch: a few perched on a landmark (the Elder Tree's crown, Arch Rock) burst up when you come
	              near, wheel round it and settle again once you've gone. LifeSky: a flock wheeling over a spot.

	Everything is local, anchored and non-colliding, tagged AmbientDino (TikTok takes and cutscenes hide that tag),
	built the first time you arrive in the era and parked (Parent = nil) while you're anywhere else. Nothing far from
	the camera steps (and DinosaurAnimations stops animating it), so a quiet valley costs almost nothing.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurAnimations = require(DinoShared:WaitForChild("DinosaurAnimations"))
local Zone = require(script.Parent.Zone)
local Cinema = require(script.Parent.UI.Cinema)

local EraLife = {}

local DinoT = DinoShared:WaitForChild("Dinosaurs")
local player = Players.LocalPlayer

local HERD_CULL = 560 -- studs from the camera: past this a herd holds still (inside DinosaurAnimations' 600-stud LOD, so
-- nothing ever glides along unanimated at the edge of it)
local BIRD_CULL = 700
local SPOOK = 26 -- you this close to any of them: they spook
local CALM_AFTER = 5 -- seconds of trotting before they settle

type Path = { Pts: { Vector3 }, Cum: { number }, Len: number, Loop: boolean }
type Member = { Model: Model, Root: BasePart, Anim: any, Lift: number, Len: number, Side: number, Lat: number, Yaw: number?, Pos: Vector3 }
type Herd = { Path: Path, Members: { Member }, Order: { number }, S: number, Dir: number, Speed: number, Pause: number, Graze: number, Spooked: number, Cool: number, Center: Vector3 }

local folder: Folder? = nil
local built = {} :: { [string]: { Herds: { Herd }, Flocks: { any }, Parts: { Instance } } }
local current: string? = nil

local function lf(): Folder
	if folder and folder.Parent then return folder end
	local f = Instance.new("Folder")
	f.Name = "DinoEraLife"
	f.Parent = Workspace
	folder = f
	return f
end

--------------------------------------------------------------------------------
-- paths
--------------------------------------------------------------------------------
local function parsePath(s: string, loop: boolean): Path?
	local pts = {}
	for chunk in string.gmatch(s, "[^;]+") do
		local x, y, z = string.match(chunk, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
		if x then table.insert(pts, Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number)) end
	end
	if #pts < 2 then return nil end
	if loop then table.insert(pts, pts[1]) end
	local cum = { 0 }
	for i = 2, #pts do cum[i] = cum[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
	return { Pts = pts, Cum = cum, Len = cum[#cum], Loop = loop }
end

-- position and flat heading at distance s along a path (wrapped on loops, clamped on open paths)
local function pathAt(p: Path, s: number): (Vector3, Vector3)
	if p.Loop then s %= p.Len else s = math.clamp(s, 0, p.Len) end
	local i = 1
	while i < #p.Pts - 1 and p.Cum[i + 1] < s do i += 1 end
	local a, b = p.Pts[i], p.Pts[i + 1]
	local seg = p.Cum[i + 1] - p.Cum[i]
	local t = seg > 1e-3 and (s - p.Cum[i]) / seg or 0
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	return a:Lerp(b, t), d.Magnitude > 1e-3 and d.Unit or Vector3.new(0, 0, -1)
end

--------------------------------------------------------------------------------
-- herds
--------------------------------------------------------------------------------
local function prep(m: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = false
		end
	end
end

local function member(species: string, scale: number): Member?
	local t = DinoT:FindFirstChild(species)
	if not (t and t:IsA("Model")) then return nil end
	local m = t:Clone()
	prep(m)
	if scale ~= 1 then m:ScaleTo(scale) end
	m:SetAttribute("AnimScale", scale)
	m:SetAttribute("Species", species)
	local root = m.PrimaryPart
	if not root then m:Destroy() return nil end
	root.Anchored = true
	local cf0, size = m:GetBoundingBox()
	CollectionService:AddTag(m, "AmbientDino")
	m.Parent = lf()
	local anim = DinosaurAnimations.get(m)
	if anim then anim:SetLocomotion("Walk") end
	return {
		Model = m, Root = root, Anim = anim, Lift = root.Position.Y - (cf0.Position.Y - size.Y / 2),
		Len = math.max(size.X, size.Z), Side = 0, Lat = 0, Yaw = nil, Pos = root.Position,
	}
end

local function play(m: Member, names: { string })
	local a = m.Anim
	if not a then return end
	for _, n in ipairs(names) do
		if a:HasAction(n) then a:Play(n) return end
	end
end

local function makeHerd(marker: BasePart): Herd?
	local loop = marker:GetAttribute("Loop") == true
	local points, species = marker:GetAttribute("Points"), marker:GetAttribute("Species")
	if type(points) ~= "string" or type(species) ~= "string" then return nil end
	local path = parsePath(points, loop)
	if not path then return nil end
	local count = math.clamp(tonumber(marker:GetAttribute("Count")) or 3, 1, 6)
	local adults = math.max(1, math.ceil(count / 2))
	local members = {}
	for k = 1, count do
		-- the grown-ups a touch different in size, the young about half (a family, not clones)
		local scale = k <= adults and (1 - (k - 1) * 0.08) or (0.5 + (k - adults) * 0.06)
		local m = member(species, scale)
		if m then
			-- strung out along the trail, a little to either side of it
			m.Side = (k % 2 == 0) and 1 or -1
			m.Lat = (k == 1) and 0 or m.Side * (1.5 + (k % 3))
			table.insert(members, m)
		end
	end
	if #members == 0 then return nil end
	local order = {}
	for i = 1, #members do order[i] = i end
	local h: Herd = {
		Path = path, Members = members, Order = order, S = 0, Dir = 1, Speed = tonumber(marker:GetAttribute("Speed")) or 4,
		Pause = 0, Graze = 18 + math.random() * 20, Spooked = 0, Cool = 0, Center = path.Pts[1],
	}
	-- start partway along (everyone fits behind the leader) so a herd isn't always found at the same end
	local back = 0
	for i = 2, #members do back += (members[i - 1].Len + members[i].Len) / 2 * 0.7 + 2 end
	h.S = math.min(path.Len, back + math.random() * math.max(0, path.Len - back))
	return h
end

-- spacing between consecutive members (nose to tail, a little room)
local function gapAfter(h: Herd, k: number): number
	local a, b = h.Members[h.Order[k - 1]], h.Members[h.Order[k]]
	return (a.Len + b.Len) / 2 * 0.7 + 2
end

local function setLoco(h: Herd, mode: string, fade: number?)
	for _, m in ipairs(h.Members) do
		if m.Anim and m.Anim:GetLocomotion() ~= mode then m.Anim:SetLocomotion(mode, fade or 0.5) end
	end
end

local function stepHerd(h: Herd, dt: number, me: Vector3?)
	local p = h.Path
	h.Cool = math.max(0, h.Cool - dt)
	-- spook: you came too close. They call, part to the sides and trot on (turning round first on an open path if
	-- you're in front of them, so they never run at you)
	if me and h.Cool <= 0 then
		local near = false
		for _, m in ipairs(h.Members) do
			if Vector3.new(m.Pos.X - me.X, 0, m.Pos.Z - me.Z).Magnitude < SPOOK and math.abs(m.Pos.Y - me.Y) < 20 then near = true break end
		end
		if near then
			h.Spooked = CALM_AFTER
			h.Cool = CALM_AFTER + 6
			h.Pause = 0
			local lead = h.Members[h.Order[1]]
			local _, tan = pathAt(p, h.S)
			local toMe = Vector3.new(me.X - lead.Pos.X, 0, me.Z - lead.Pos.Z)
			if not p.Loop and toMe:Dot(tan * h.Dir) > 0 then
				-- the last in line leads the way back (positions stay put: the line just reverses)
				local total = 0
				for k = 2, #h.Order do total += gapAfter(h, k) end
				h.S -= h.Dir * total
				h.Dir = -h.Dir
				local rev = {}
				for k = #h.Order, 1, -1 do table.insert(rev, h.Order[k]) end
				h.Order = rev
			end
			setLoco(h, "Run", 0.3)
			play(lead, { "HerdCall", "Roar", "LookAround" })
		end
	end
	local moving = true
	if h.Spooked > 0 then
		h.Spooked -= dt
		if h.Spooked <= 0 then setLoco(h, "Walk", 0.8) end
	elseif h.Pause > 0 then
		moving = false
		h.Pause -= dt
		if h.Pause <= 0 then setLoco(h, "Walk", 0.8) end
	else
		-- a stop to graze now and then
		h.Graze -= dt
		if h.Graze <= 0 then
			h.Graze = 25 + math.random() * 25
			h.Pause = 5 + math.random() * 4
			setLoco(h, "Idle", 0.8)
			for _, m in ipairs(h.Members) do task.delay(math.random() * 1.5, play, m, { "Graze", "LookAround", "HerdResponse" }) end
			moving = false
		end
	end
	if moving then
		local v = h.Speed * (h.Spooked > 0 and 2.4 or 1)
		h.S += h.Dir * v * dt
		if p.Loop then
			h.S %= p.Len
		elseif (h.Dir > 0 and h.S >= p.Len) or (h.Dir < 0 and h.S <= 0) then
			-- the end of the trail: mill about, look round, call - then the back of the line leads the way home
			h.S = math.clamp(h.S, 0, p.Len)
			local total = 0
			for k = 2, #h.Order do total += gapAfter(h, k) end
			h.S -= h.Dir * total
			h.Dir = -h.Dir
			local rev = {}
			for k = #h.Order, 1, -1 do table.insert(rev, h.Order[k]) end
			h.Order = rev
			h.Pause = 6 + math.random() * 4
			h.Spooked = 0
			setLoco(h, "Idle", 0.8)
			play(h.Members[h.Order[1]], { "LookAround" })
			for k = 2, #h.Order do task.delay(1 + math.random() * 2, play, h.Members[h.Order[k]], { "HerdResponse", "Graze", "LookAround" }) end
		end
	end
	-- lay the line out behind the leader
	local s = h.S
	local sum = Vector3.zero
	for k, idx in ipairs(h.Order) do
		if k > 1 then s -= h.Dir * gapAfter(h, k) end
		local m = h.Members[idx]
		local pos, tan = pathAt(p, s)
		local heading = tan * h.Dir
		local right = Vector3.new(-heading.Z, 0, heading.X)
		-- spooked: everyone steps well off the line to their own side (the herd parts round you)
		local want = h.Spooked > 0 and m.Side * 9 or (k == 1 and 0 or m.Side * (1.5 + (idx % 3)))
		m.Lat += (want - m.Lat) * math.min(1, dt * (h.Spooked > 0 and 2.5 or 0.6))
		local at = pos + right * m.Lat
		local moved = Vector3.new(at.X - m.Pos.X, 0, at.Z - m.Pos.Z)
		m.Pos = at
		-- (facing where it's going; the very first layout faces along the trail, not from wherever the template was)
		local dir = (m.Yaw ~= nil and moved.Magnitude > 0.02) and moved.Unit or heading
		local yaw = math.atan2(-dir.X, -dir.Z)
		m.Yaw = m.Yaw and (m.Yaw + math.atan2(math.sin(yaw - m.Yaw), math.cos(yaw - m.Yaw)) * math.min(1, dt * 3)) or yaw
		m.Root.CFrame = CFrame.new(at + Vector3.new(0, m.Lift, 0)) * CFrame.Angles(0, m.Yaw :: number, 0)
		sum += at
	end
	h.Center = sum / #h.Members
end

--------------------------------------------------------------------------------
-- pterosaurs: chunky blocky Pteranodon, flown by hand (no rig)
--------------------------------------------------------------------------------
local BODY = Color3.fromRGB(201, 122, 74)
local WING = Color3.fromRGB(168, 90, 58)
local WING_TIP = Color3.fromRGB(217, 154, 106)
local CREST = Color3.fromRGB(224, 74, 58)

local function bpart(m: Model, size: Vector3, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = true
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local function pterosaur(scale: number)
	local m = Instance.new("Model")
	m.Name = "AmbientPterosaur"
	local k = scale
	local b = {
		Body = bpart(m, Vector3.new(1.3, 1.1, 3.2) * k, BODY),
		Head = bpart(m, Vector3.new(0.9, 0.9, 1.5) * k, BODY),
		Beak = bpart(m, Vector3.new(0.45, 0.4, 2.6) * k, Color3.fromRGB(236, 196, 120)),
		Crest = bpart(m, Vector3.new(0.3, 1.2, 2.2) * k, CREST),
		LIn = bpart(m, Vector3.new(4, 0.18, 1.8) * k, WING),
		LOut = bpart(m, Vector3.new(4, 0.14, 1.2) * k, WING_TIP),
		RIn = bpart(m, Vector3.new(4, 0.18, 1.8) * k, WING),
		ROut = bpart(m, Vector3.new(4, 0.14, 1.2) * k, WING_TIP),
		Tail = bpart(m, Vector3.new(0.3, 0.3, 1.4) * k, BODY),
	}
	CollectionService:AddTag(m, "AmbientDino")
	m.Parent = lf()
	return { Model = m, P = b, K = k, Seed = math.random() * 100 }
end

local SIDES = { -1, 1 }
-- every part of one pterosaur from its body frame, a wing beat (-1..1 up/down) and how far the wings fold (0..1)
local function poseBird(bird, cf: CFrame, beat: number, fold: number, parts: { BasePart }, cfs: { CFrame })
	local k, P = bird.K, bird.P
	local function put(p: BasePart, c: CFrame) table.insert(parts, p) table.insert(cfs, c) end
	put(P.Body, cf)
	local head = cf * CFrame.new(0, 0.35 * k, -2.1 * k) * CFrame.Angles(-0.12, 0, 0)
	put(P.Head, head)
	put(P.Beak, head * CFrame.new(0, -0.15 * k, -1.9 * k) * CFrame.Angles(0.06, 0, 0))
	put(P.Crest, head * CFrame.new(0, 0.5 * k, 1.1 * k) * CFrame.Angles(0.5, 0, 0))
	put(P.Tail, cf * CFrame.new(0, 0, 2.1 * k) * CFrame.Angles(0.15, 0, 0))
	for _, side in ipairs(SIDES) do
		-- shoulder up/down with the beat; folded (perched), both segments lie swept back along the body like a dart
		local up = beat * 0.55 * (1 - fold) - fold * 0.15
		local sweep = fold * 1.35
		local shoulder = cf * CFrame.new(side * 0.6 * k, 0.25 * k, -0.4 * k) * CFrame.Angles(0, side * -sweep, side * up)
		local inner = shoulder * CFrame.new(side * 2 * k, 0, 0)
		local elbow = shoulder * CFrame.new(side * 4 * k, 0, 0) * CFrame.Angles(0, side * -fold * 0.25, side * beat * 0.35 * (1 - fold))
		local outer = elbow * CFrame.new(side * 2 * k, 0, 0.2 * k)
		put(side < 0 and P.LIn or P.RIn, inner)
		put(side < 0 and P.LOut or P.ROut, outer)
	end
end

local function makeFlock(marker: BasePart, perched: boolean)
	local count = math.clamp(tonumber(marker:GetAttribute("Count")) or 3, 1, 8)
	local f = {
		Home = marker.Position - Vector3.new(0, marker.Size.Y / 2, 0), Perched = perched, Up = not perched, Timer = 0,
		Radius = tonumber(marker:GetAttribute("Radius")) or 26, Spook = tonumber(marker:GetAttribute("Spook")) or 34, Birds = {},
	}
	for i = 1, count do
		local b = pterosaur(0.85 + math.random() * 0.35)
		-- a perch spot each (a small ring on the landmark's top), a lane each in the sky
		local a = (i / count) * math.pi * 2 + math.random() * 0.4
		b.Perch = f.Home + Vector3.new(math.cos(a) * (1.2 + (i % 3) * 1.2), 0, math.sin(a) * (1.2 + (i % 3) * 1.2))
		b.PerchYaw = math.random() * math.pi * 2
		b.Phase = (i / count) * math.pi * 2
		b.R = f.Radius * (0.75 + math.random() * 0.5)
		b.H = 12 + math.random() * 16
		b.Speed = 0.32 + math.random() * 0.12
		b.Blend = perched and 0 or 1 -- 0 perched .. 1 flying
		table.insert(f.Birds, b)
	end
	return f
end

local function stepFlock(f, dt: number, me: Vector3?, parts: { BasePart }, cfs: { CFrame })
	local t = os.clock()
	if f.Perched then
		-- you come near: they all go up; once you've been gone a while they come back down
		local near = me ~= nil and (me - f.Home).Magnitude < f.Spook
		if near then f.Up = true f.Timer = 14 + math.random() * 6
		elseif f.Up then f.Timer -= dt if f.Timer <= 0 then f.Up = false end end
	end
	for _, b in ipairs(f.Birds) do
		local wantBlend = f.Up and 1 or 0
		-- (take off fast, land slowly)
		b.Blend += (wantBlend - b.Blend) * math.min(1, dt * (wantBlend > b.Blend and 1.6 or 0.5))
		b.Phase += dt * b.Speed * (24 / b.R)
		local a = b.Phase
		local fly = f.Home + Vector3.new(math.cos(a) * b.R, b.H + math.sin(t * 0.4 + b.Seed) * 3, math.sin(a) * b.R)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		local flyCF = CFrame.lookAt(fly, fly + tangent) * CFrame.Angles(0, 0, -0.35) -- banked into the turn
		local sitCF = CFrame.new(b.Perch + Vector3.new(0, 0.9 * b.K, 0)) * CFrame.Angles(0, b.PerchYaw + math.sin(t * 0.3 + b.Seed) * 0.3, 0) * CFrame.Angles(-0.35, 0, 0)
		local e = b.Blend
		local cf
		if e >= 0.999 then cf = flyCF
		elseif e <= 0.001 then cf = sitCF
		else
			-- the hop in between: lerp the frames and lift on an arc so they don't slide along the ground
			cf = sitCF:Lerp(flyCF, e) + Vector3.new(0, math.sin(e * math.pi) * 6, 0)
		end
		-- flapping hard taking off, a slow beat and long glides up high, folded when perched
		local beatRate = 5 + (1 - e) * 4
		local glide = (math.sin(t * 0.5 + b.Seed) > 0.3) and e > 0.95
		local beat = glide and 0.15 or math.sin(t * beatRate + b.Seed)
		local fold = 1 - math.clamp(e * 3, 0, 1)
		poseBird(b, cf, beat, fold, parts, cfs)
	end
end

--------------------------------------------------------------------------------
-- life per era: built the first time you arrive
--------------------------------------------------------------------------------
local function build(zoneId: string)
	local zm = Workspace:FindFirstChild(zoneId)
	local lp = zm and zm:FindFirstChild("LifePaths", true)
	local life = { Herds = {}, Flocks = {}, Parts = {} }
	built[zoneId] = life
	if not lp then return life end
	for _, mk in ipairs(lp:GetChildren()) do
		if not mk:IsA("BasePart") then continue end
		local ok, err = pcall(function()
			if mk.Name == "LifePath" then
				local h = makeHerd(mk)
				if h then table.insert(life.Herds, h) end
			elseif mk.Name == "LifePerch" or mk.Name == "LifeSky" then
				table.insert(life.Flocks, makeFlock(mk, mk.Name == "LifePerch"))
			end
		end)
		if not ok then warn("[EraLife]", zoneId, mk.Name, err) end
	end
	-- lay everyone out once now: anything far from the camera only moves when you get near, and must never be left
	-- standing wherever the template was
	local parts, cfs = {}, {}
	for _, h in ipairs(life.Herds) do
		pcall(stepHerd, h, 0, nil)
		for _, m in ipairs(h.Members) do table.insert(life.Parts, m.Model) end
	end
	for _, f in ipairs(life.Flocks) do
		stepFlock(f, 0, nil, parts, cfs)
		for _, b in ipairs(f.Birds) do table.insert(life.Parts, b.Model) end
	end
	if #parts > 0 then Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
	return life
end

local function park(zoneId: string?, shown: boolean)
	local life = zoneId and built[zoneId]
	if not life then return end
	for _, m in ipairs(life.Parts) do m.Parent = shown and lf() or nil end
end

local framePs, frameCfs = {} :: { BasePart }, {} :: { CFrame }
local hidden = false -- (out of the picture while a cutscene plays: the scenes frame their own dinos)
local function step(dt: number)
	local z = Zone.Current
	if z ~= current then
		park(current, false)
		current = z
		hidden = false
		if z and Workspace:FindFirstChild(z) then
			if not built[z] then build(z) end
			park(z, true)
		end
	end
	local life = z and built[z]
	if not life or (#life.Herds == 0 and #life.Flocks == 0) then return end
	local inScene = Cinema.Playing()
	if inScene ~= hidden then
		hidden = inScene
		park(z, not inScene)
	end
	if hidden then return end
	local cam = Workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or Vector3.zero
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local me = hrp and hrp.Position or nil
	dt = math.min(dt, 0.1)
	for _, h in ipairs(life.Herds) do
		if (h.Center - eye).Magnitude < HERD_CULL then
			local ok, err = pcall(stepHerd, h, dt, me)
			if not ok then warn("[EraLife] herd:", err) h.Center = Vector3.new(1e6, 0, 0) end
		end
	end
	-- (the same two lists every frame: no garbage at 60 fps)
	local parts, cfs = framePs, frameCfs
	table.clear(parts)
	table.clear(cfs)
	for _, f in ipairs(life.Flocks) do
		if (f.Home - eye).Magnitude < BIRD_CULL then stepFlock(f, dt, me, parts, cfs) end
	end
	if #parts > 0 then Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end

function EraLife.Start()
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then warn("[EraLife]", err) end
	end)
end

return EraLife
