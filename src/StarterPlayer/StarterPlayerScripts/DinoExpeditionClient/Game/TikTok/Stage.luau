--[[
	Stage — local props for TikTok shots. Everything here is a client-only clone in its own folder: the real
	game (server dinos, your rover, your character) is never moved, so recording can't break a run.

	  local set = Stage.new("ShotName")              a folder; set:Show() / set:Destroy()
	  set:Dino(species, { Scale?, Baby? })  -> actor  actor:Place(groundPos, faceDir) / :Loco("Run") / :Act("Roar")
	  set:Rover(name?)                       -> rover  rover:Place(groundPos, faceDir, travelled)
	  set:Crew(i)                            -> crew   your avatar (i = 1) or a recoloured expedition double
	                                                    crew:Place(groundPos, faceDir, velocity?) / :Act("Grab") / :Sit(seatCF)
	  set:Egg(species, rarity)               -> model  set:PlaceModel(m, groundPos, yaw)
	  Stage.Ground(p)                        the top of the world under p (ignores every stage prop and player)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurAnimations = require(Shared:WaitForChild("DinosaurAnimations"))
local Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))
local Net = require(script.Parent.Parent.Net)
local PlayerAnim = require(script.Parent.Parent.PlayerAnim)
local RarityFx = require(script.Parent.Parent.RarityFx)

local player = Players.LocalPlayer
local Stage = {}
Stage.__index = Stage

local function root(): Folder
	local f = Workspace:FindFirstChild("DinoTikTok")
	if not f then
		f = Instance.new("Folder")
		f.Name = "DinoTikTok"
		f.Parent = Workspace
	end
	return f :: Folder
end
Stage.Root = root

--------------------------------------------------------------------------------
-- ground
--------------------------------------------------------------------------------
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = false
local function filter()
	local list = { root() :: Instance }
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(list, plr.Character) end end
	for _, n in ipairs({ "ActiveVehicles", "DinoExpeditionLocal", "DinoAmbience" }) do
		local f = Workspace:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	ray.FilterDescendantsInstances = list
end

function Stage.Ground(p: Vector3, up: number?): Vector3
	filter()
	local hit = Workspace:Raycast(p + Vector3.new(0, up or 80, 0), Vector3.new(0, -((up or 80) + 200), 0), ray)
	-- only solid ground counts: leaves and invisible markers would float a foot in the air
	local tries = 0
	while hit and tries < 6 and (hit.Instance.Transparency > 0.6 or (hit.Instance:IsA("BasePart") and not hit.Instance.CanCollide and hit.Instance ~= Workspace.Terrain)) do
		local skip = table.clone(ray.FilterDescendantsInstances)
		table.insert(skip, hit.Instance)
		ray.FilterDescendantsInstances = skip
		hit = Workspace:Raycast(p + Vector3.new(0, up or 80, 0), Vector3.new(0, -((up or 80) + 200), 0), ray)
		tries += 1
	end
	return hit and hit.Position or p
end

-- is the straight line a -> b clear of solid scenery? (camera sanity)
function Stage.Clear(a: Vector3, b: Vector3): boolean
	filter()
	local hit = Workspace:Raycast(a, b - a, ray)
	return hit == nil or hit.Instance.Transparency > 0.6
end

--------------------------------------------------------------------------------
-- sets
--------------------------------------------------------------------------------
function Stage.new(name: string)
	local folder = Instance.new("Folder")
	folder.Name = name
	return setmetatable({ Folder = folder, Actors = {} }, Stage)
end

function Stage:Show()
	self.Folder.Parent = root()
end

function Stage:Hide()
	self.Folder.Parent = nil
end

function Stage:Destroy()
	for _, a in ipairs(self.Actors) do
		if a.Cleanup then pcall(a.Cleanup, a) end
	end
	self.Folder:Destroy()
end

-- freeze or thaw every animator on this set (PAUSE)
function Stage:SetPaused(on: boolean)
	for _, a in ipairs(self.Actors) do
		if a.Anim then a.Anim.Paused = on end
	end
end

local function rigParts(m: Model)
	local r = m.PrimaryPart
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = d == r
			d.Massless = d ~= r
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- dinos
--------------------------------------------------------------------------------
local Actor = {}
Actor.__index = Actor

function Stage.ScaleOf(species: string): number
	local c = Config.Combat[species]
	return (c and c.Scale) or 1
end

function Stage:Dino(species: string, opts)
	opts = opts or {}
	local folder = Shared:FindFirstChild(opts.Baby and "Babies" or "Dinosaurs")
	local t = folder and folder:FindFirstChild(species)
	if not t then warn("[TikTok] no model for", species) return nil end
	local m = t:Clone() :: Model
	m.Name = "TT_" .. species
	m:SetAttribute("Species", species)
	rigParts(m)
	local scale = opts.Scale or (opts.Baby and 1 or Stage.ScaleOf(species))
	if scale ~= 1 then m:ScaleTo(scale) end
	m:SetAttribute("AnimScale", scale)
	local bb, size = m:GetBoundingBox()
	local r = m.PrimaryPart :: BasePart
	local lift = r.Position.Y - (bb.Position.Y - size.Y / 2)
	m.Parent = self.Folder
	local anim = DinosaurAnimations.get(m)
	if anim then anim.Time = 0 end -- same idle breath every take
	local prof = anim and anim.Profile
	local a = setmetatable({
		Model = m, Root = r, Anim = anim, Lift = lift, Size = size, Scale = scale, Species = species,
		WalkSpeed = (prof and prof.Gait.Walk.Speed or 6) * scale,
		RunSpeed = (prof and prof.Gait.Run.Speed or 16) * scale,
	}, Actor)
	if opts.Rarity then RarityFx.Apply(m, opts.Rarity, size.Y) end
	table.insert(self.Actors, a)
	return a
end

-- stand on the ground at p, facing dir (flat)
function Actor:Place(p: Vector3, dir: Vector3, pitch: number?)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local base = Vector3.new(p.X, p.Y + self.Lift, p.Z)
	local cf = CFrame.lookAt(base, base + flat)
	if pitch then cf *= CFrame.Angles(pitch, 0, 0) end
	self.Root.CFrame = cf
	if self.Anim then self.Anim.HomeCFrame = cf end
end

function Actor:Loco(mode: string, fade: number?)
	if self.Anim then self.Anim:SetLocomotion(mode, fade or 0.2) end
end

function Actor:Act(name: string, speed: number?)
	if self.Anim and self.Anim:HasAction(name) then return self.Anim:Play(name, { Speed = speed or 1 }) end
	return nil
end

-- the first of these a species has (signature actions differ per dino)
function Actor:ActAny(names: { string }, speed: number?)
	for _, n in ipairs(names) do
		if self.Anim and self.Anim:HasAction(n) then return self.Anim:Play(n, { Speed = speed or 1 }), n end
	end
	return nil, nil
end

function Actor:Head(): Vector3
	local h = self.Model:FindFirstChild("Head", true)
	if h and h:IsA("BasePart") then return h.Position end
	return self.Root.Position + Vector3.new(0, self.Size.Y * 0.35, 0)
end

-- the mouth attachment if the rig has one (roars / bites aim the lens here)
function Actor:Mouth(): CFrame
	for _, n in ipairs({ "VFX_Mouth", "Mouth", "VFX_Head" }) do
		local a = self.Model:FindFirstChild(n, true)
		if a and a:IsA("Attachment") then return a.WorldCFrame end
	end
	return CFrame.new(self:Head())
end

--------------------------------------------------------------------------------
-- rovers (the real vehicle templates, anchored; wheels roll with distance travelled)
--------------------------------------------------------------------------------
local Rover = {}
Rover.__index = Rover

function Stage:Rover(name: string?)
	local gear = (Net.Profile and Net.Profile.Gear) or {}
	local templates = Shared:FindFirstChild("Vehicles")
	local want = name or gear.Vehicle or "RookieRanger"
	local t = templates and (templates:FindFirstChild(want) or templates:FindFirstChild("RookieRanger"))
	if not t then warn("[TikTok] no rover template") return nil end
	local m = t:Clone() :: Model
	m.Name = "TT_Rover"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Constraint") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("VehicleSeat") or d:IsA("Seat") then
			(d :: any).Disabled = true
		end
	end
	m.Parent = self.Folder
	local r = m.PrimaryPart :: BasePart
	local wheels = {}
	for _, w in ipairs(m:GetDescendants()) do
		if w:IsA("Model") and w.Name:match("^Wheel[FR][LR]$") then
			table.insert(wheels, { M = w, Off = r.CFrame:ToObjectSpace(w:GetPivot()), R = w:GetAttribute("Radius") or 1.4, Front = w.Name:sub(6, 6) == "F" })
		end
	end
	local seat = m:FindFirstChild("DriverSeat", true) :: BasePart?
	local seat2 = m:FindFirstChild("PassengerSeat", true) :: BasePart?
	local slots = {}
	for _, a in ipairs(r:GetChildren()) do
		local n = a:IsA("Attachment") and tonumber(a.Name:match("^EggSlot(%d+)$"))
		if n then slots[n] = a end
	end
	local rv = setmetatable({
		Model = m, Root = r, Wheels = wheels, RootHeight = m:GetAttribute("RootHeight") or 2.6,
		PivotOff = r.CFrame:ToObjectSpace(m:GetPivot()),
		SeatOff = seat and r.CFrame:ToObjectSpace(seat.CFrame) or CFrame.new(-1.3, 0.6, -0.7),
		Seat2Off = seat2 and r.CFrame:ToObjectSpace(seat2.CFrame) or CFrame.new(1.3, 0.6, -0.7),
		Slots = slots,
	}, Rover)
	table.insert(self.Actors, rv)
	return rv
end

-- p on the ground; dir = travel; travelled = studs driven so far (wheel roll); steer in radians; roll/pitch body sway
function Rover:Place(p: Vector3, dir: Vector3, travelled: number?, steer: number?, sway: Vector2?)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	-- pitch with the ground: sample front and back
	local half = 4
	local front = Stage.Ground(p + flat * half, 12)
	local back = Stage.Ground(p - flat * half, 12)
	local mid = (front + back) / 2
	local y = math.max(mid.Y, p.Y)
	local pos = Vector3.new(p.X, y + self.RootHeight, p.Z)
	local look = (front - back)
	if look.Magnitude < 0.1 or math.abs(look.Unit.Y) > 0.6 then look = flat end
	local cf = CFrame.lookAt(pos, pos + look.Unit)
	if sway then cf *= CFrame.Angles(sway.X, 0, sway.Y) end
	self.CF = cf
	self.Model:PivotTo(cf * self.PivotOff)
	local d = travelled or 0
	for _, w in ipairs(self.Wheels) do
		w.M:PivotTo(cf * w.Off * CFrame.Angles(0, w.Front and (steer or 0) or 0, 0) * CFrame.Angles(-d / w.R, 0, 0))
	end
end

-- the exact frame the director baked: root CFrame, metres driven (wheel roll) and front-wheel steer
function Rover:Set(root: CFrame, travelled: number, steer: number)
	self.CF = root
	self.Model:PivotTo(root * self.PivotOff)
	for _, w in ipairs(self.Wheels) do
		w.M:PivotTo(root * w.Off * CFrame.Angles(0, w.Front and steer or 0, 0) * CFrame.Angles(-travelled / w.R, 0, 0))
	end
end

function Rover:Seat(which: number?): CFrame
	return (self.CF or self.Root.CFrame) * (which == 2 and self.Seat2Off or self.SeatOff)
end

-- where an egg rides on the roof rack (the game seats them the same way)
function Rover:Slot(n: number): CFrame?
	local a = self.Slots[n]
	return a and a.WorldCFrame * CFrame.new(0, -0.5, 0) or nil
end

--------------------------------------------------------------------------------
-- crew: your avatar and expedition doubles, posed by PlayerAnim (anchored root, velocity drives the legs)
--------------------------------------------------------------------------------
local CREW_COLORS = {
	{ Color3.fromRGB(240, 170, 60), Color3.fromRGB(70, 90, 60) },
	{ Color3.fromRGB(70, 160, 220), Color3.fromRGB(50, 55, 70) },
	{ Color3.fromRGB(230, 80, 70), Color3.fromRGB(90, 70, 50) },
	{ Color3.fromRGB(120, 200, 90), Color3.fromRGB(60, 60, 60) },
}

local Crew = {}
Crew.__index = Crew

-- from: another character to double instead of you (the Prologue's Quartermaster); keeps its own outfit
function Stage:Crew(i: number, from: Model?)
	local char = from or player.Character
	if not char then return nil end
	local was = char.Archivable
	char.Archivable = true
	local m = char:Clone()
	char.Archivable = was
	if not m then return nil end
	m.Name = "TT_Crew" .. i
	-- the take hides your real character; its double must not inherit that
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
		if d:IsA("Decal") and d.Name == "face" then d.Transparency = 0 end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Tool") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = d.Name == "HumanoidRootPart"
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.PlatformStand = true
	end
	-- doubles: same build as you, expedition colours instead of your outfit, no hats
	if i > 1 and not from then
		local pal = CREW_COLORS[(i - 2) % #CREW_COLORS + 1]
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then d:Destroy() end
		end
		local bc = m:FindFirstChildOfClass("BodyColors")
		if bc then bc:Destroy() end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				local n = d.Name
				if n:find("Torso") or n:find("Arm") or n:find("Hand") then d.Color = pal[1]
				elseif n:find("Leg") or n:find("Foot") then d.Color = pal[2]
				elseif n == "Head" then d.Color = Color3.fromRGB(255, 205, 160) end
			end
		end
	end
	m.Parent = self.Folder
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local c = setmetatable({ Model = m, Root = hrp, Hip = hum and hum.HipHeight or 2, R15 = hum and hum.RigType == Enum.HumanoidRigType.R15 }, Crew)
	c.Cleanup = function() PlayerAnim.SetCombat(m, false) end
	table.insert(self.Actors, c)
	return c
end

-- p on the ground; vel drives the procedural run cycle (studs/s along dir)
function Crew:Place(p: Vector3, dir: Vector3, speed: number?)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local h = self.Root.Size.Y / 2 + (self.R15 and self.Hip or 2)
	local pos = Vector3.new(p.X, p.Y + h, p.Z)
	self.Root.CFrame = CFrame.lookAt(pos, pos + flat)
	self.Root.AssemblyLinearVelocity = flat * (speed or 0)
end

-- Roblox's own default walk / run / idle, matched to how fast the double actually moves (a real player's look)
local DEFAULT_ANIMS = {
	R15 = { Idle = "rbxassetid://507766388", Walk = "rbxassetid://507777826", Run = "rbxassetid://507767714" },
	R6 = { Idle = "rbxassetid://180435571", Walk = "rbxassetid://180426354", Run = "rbxassetid://180426354" },
}
function Crew:Locomote(speed: number)
	local hum = self.Model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	self.Tracks = self.Tracks or {}
	local set = DEFAULT_ANIMS[self.R15 and "R15" or "R6"]
	local want = speed < 0.6 and "Idle" or (speed > 14 and "Run" or "Walk")
	for name, id in pairs(set) do
		local tr = self.Tracks[name]
		if not tr then
			local a = Instance.new("Animation")
			a.AnimationId = id
			local ok, loaded = pcall(function() return animator:LoadAnimation(a) end)
			if ok and loaded then
				loaded.Looped = true
				self.Tracks[name] = loaded
				tr = loaded
			end
		end
		if tr then
			if name == want and not tr.IsPlaying then tr:Play(0.15)
			elseif name ~= want and tr.IsPlaying then tr:Stop(0.15) end
		end
	end
	local tr = self.Tracks[want]
	if tr and want ~= "Idle" then tr:AdjustSpeed(math.clamp(speed / (want == "Run" and 16 or 9), 0.5, 2)) end
end

-- carrying an egg in both arms (PlayerAnim's carry stance, the same one players get)
function Crew:Carry(on: boolean)
	local rig = PlayerAnim.Rig and PlayerAnim.Rig(self.Model)
	if rig then rig.Stance = on and "Carry" or nil end
end

function Crew:Combat(on: boolean, sprint: boolean?)
	PlayerAnim.SetCombat(self.Model, on)
	local hum = self.Model:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = sprint and 30 or 16 end
end

function Crew:Act(name: string)
	PlayerAnim.SetCombat(self.Model, true)
	PlayerAnim.Act(self.Model, name)
end

function Crew:Aim(pitch: number)
	PlayerAnim.SetCombat(self.Model, true)
	PlayerAnim.SetAim(self.Model, pitch, true)
end

-- sitting in a rover: root placed at the seat, legs folded forward (written straight to the hips)
function Crew:Sit(seat: CFrame)
	self.Root.CFrame = seat * CFrame.new(0, self.R15 and 1.6 or 1.5, 0)
	self.Root.AssemblyLinearVelocity = Vector3.zero
	for _, n in ipairs({ "RightHip", "LeftHip", "Right Hip", "Left Hip" }) do
		local j = self.Model:FindFirstChild(n, true)
		if j and j:IsA("Motor6D") then
			local side = (n:find("Right") and 1 or -1)
			j.Transform = self.R15 and CFrame.Angles(math.rad(85), 0, 0) or CFrame.Angles(0, 0, side * math.rad(85))
		end
	end
	for _, n in ipairs({ "RightKnee", "LeftKnee" }) do
		local j = self.Model:FindFirstChild(n, true)
		if j and j:IsA("Motor6D") then j.Transform = CFrame.Angles(math.rad(-80), 0, 0) end
	end
end

--------------------------------------------------------------------------------
-- eggs and plain props
--------------------------------------------------------------------------------
function Stage:Egg(species: string, rarity: string?, scale: number?): Model?
	local t = Shared:FindFirstChild("Eggs") and Shared.Eggs:FindFirstChild(species .. "Egg")
	if not t then return nil end
	local m = t:Clone() :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("ProximityPrompt") then d:Destroy() end
	end
	if scale and scale ~= 1 then m:ScaleTo(scale) end
	if not m.PrimaryPart then
		local p = m:FindFirstChildWhichIsA("BasePart", true)
		if p then m.PrimaryPart = p end
	end
	m.Parent = self.Folder
	-- offset from the pivot down to the bottom of the egg, so placement can stand it on a point
	local cf, size = m:GetBoundingBox()
	m:SetAttribute("TTUp", m:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2))
	if rarity and m.PrimaryPart then RarityFx.Apply(m, rarity, size.Y) end
	return m
end

function Stage:PlaceModel(m: Model, ground: Vector3, yaw: number?, lift: number?)
	local cf, size = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local bottom = cf.Position.Y - size.Y / 2
	local up = pivot.Position.Y - bottom
	m:PivotTo(CFrame.new(ground + Vector3.new(0, up + (lift or 0), 0)) * CFrame.Angles(0, yaw or 0, 0))
end

function Stage:Part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do (p :: any)[k] = v end
	p.Parent = self.Folder
	return p
end

return Stage
