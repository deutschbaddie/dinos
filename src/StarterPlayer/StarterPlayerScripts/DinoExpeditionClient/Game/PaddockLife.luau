--[[
	PaddockLife — things to do with the dinos in your paddock (client-side; CampView owns their roaming).

	  petting     every dino in your yard has a Pet prompt. It walks up so its head is right in front of you, turns
	              to you and leans into your hand: eyes shut, tail wagging, then a happy hop and hearts. You crouch
	              for a small one and reach up for a big one; a giant one bows its whole neck down to you. Each
	              species takes it its own way (REACT: a raptor nuzzles, a Triceratops head-butts your hand ...).
	  companion   the Companion Machine at the back of the paddock: press its button and every dino lights up with
	              a Choose prompt; pick one and it's your companion (server: Dinos.SetCompanion - it's your lead
	              buddy too). It follows you round camp (everyone sees it follow you; a giant one shrinks to a
	              walkable size while it's out), mooches about when you stop, and when you come home from an
	              expedition it runs over to greet you. Out of camp it waits in the paddock.
	  play        the treat barrel: take a treat and the Pet prompts become Feed (it eats from your hand). The toy
	              crate: take a ball, a ring shows where it'll land, click (tap THROW, R2) to throw - the dinos race
	              for it and the winner brings it back and drops it at your feet.

	Props come from ReplicatedStorage.DinoExpedition.CampProps (tools/gen/campProps.js) and are placed in every
	paddock from its PaddockBounds marker; only the owner's prompts are on.
]]

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local DinosaurAnimations = require(DinoShared:WaitForChild("DinosaurAnimations"))
local Kit = require(script.Parent.UI.Kit)
local CampView = require(script.Parent.CampView)
local Crew = require(script.Parent.Crew) -- (Crew.SizeClass: who fits in the rover)
local PlayerAnim = require(script.Parent.PlayerAnim)
local Panels = require(script.Parent.UI.Panels)
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)

local player = Players.LocalPlayer
local PaddockLife = {}

local Props = DinoShared:WaitForChild("CampProps")
local DinoT = DinoShared:WaitForChild("Dinosaurs")

local CAMP_CENTER = Vector3.new(600, 0, 0)
-- (2026-10-12) Base Camp Islands: the crater's box, hub-local (the rim runs ~700 out). Not a circle: a 760 circle
-- reached Fern Valley's arrival portal (634 out, north-west), so hurt companions popped in behind you there
local function inCampBox(p: Vector3): boolean
	local d = p - CAMP_CENTER
	return math.abs(d.X) < 720 and d.Z > -440 and d.Z < 740 and math.abs(d.Y) < 120
end
local FOLLOW_MAX_HEIGHT = 14 -- a giant companion is capped at this while it walks round camp with you (was 7.5: dog-sized)
local PINK, PINK_HI = Color3.fromRGB(255, 92, 150), Color3.fromRGB(255, 190, 215)
local TEAL = Color3.fromRGB(95, 242, 216)

-- how each species takes a pat. Bow: how far it lowers its head to you; Nuzzle: rubs side to side; Butt: little
-- head-butts into your hand; Wag: tail
local REACT = {
	Velociraptor = { Bow = 0.6, Nuzzle = 0.32, Butt = 0, Wag = 1.2 },
	Triceratops = { Bow = 0.5, Nuzzle = 0.08, Butt = 1, Wag = 0.7 },
	Parasaurolophus = { Bow = 0.7, Nuzzle = 0.2, Butt = 0, Wag = 0.8 },
	Stegosaurus = { Bow = 0.4, Nuzzle = 0.12, Butt = 0, Wag = 1.0 },
	Ankylosaurus = { Bow = 0.3, Nuzzle = 0.1, Butt = 0.6, Wag = 1.4 },
	Brachiosaurus = { Bow = 1.0, Nuzzle = 0.15, Butt = 0, Wag = 0.5 },
	Carnotaurus = { Bow = 0.6, Nuzzle = 0.25, Butt = 0.5, Wag = 1.0 },
	Sarcosuchus = { Bow = 0.25, Nuzzle = 0.06, Butt = 0, Wag = 1.4 },
	Oviraptor = { Bow = 0.6, Nuzzle = 0.35, Butt = 0, Wag = 1.3 },
	Protoceratops = { Bow = 0.5, Nuzzle = 0.12, Butt = 1.0, Wag = 0.9 },
	Gallimimus = { Bow = 0.85, Nuzzle = 0.2, Butt = 0, Wag = 0.6 },
	Therizinosaurus = { Bow = 1.0, Nuzzle = 0.2, Butt = 0, Wag = 0.6 },
	Microraptor = { Bow = 0.5, Nuzzle = 0.35, Butt = 0, Wag = 1.4 },
	Psittacosaurus = { Bow = 0.6, Nuzzle = 0.3, Butt = 0.2, Wag = 1.1 },
	Compy = { Bow = 0.5, Nuzzle = 0.4, Butt = 0, Wag = 1.6 },
	Yutyrannus = { Bow = 0.75, Nuzzle = 0.2, Butt = 0.3, Wag = 0.7 },
	Coelophysis = { Bow = 0.55, Nuzzle = 0.3, Butt = 0, Wag = 1.4 },
	Plateosaurus = { Bow = 0.9, Nuzzle = 0.2, Butt = 0, Wag = 0.6 },
	Dilophosaurus = { Bow = 0.6, Nuzzle = 0.22, Butt = 0.2, Wag = 1.1 },
	Postosuchus = { Bow = 0.5, Nuzzle = 0.12, Butt = 0.6, Wag = 1.3 },
	Spinosaurus = { Bow = 0.7, Nuzzle = 0.22, Butt = 0, Wag = 0.9 },
	TyrannosaurusRex = { Bow = 0.75, Nuzzle = 0.18, Butt = 0.3, Wag = 0.8 },
	Giganotosaurus = { Bow = 0.75, Nuzzle = 0.18, Butt = 0.3, Wag = 0.8 },
	PrimalRex = { Bow = 0.75, Nuzzle = 0.15, Butt = 0.4, Wag = 0.7 },
	Default = { Bow = 0.6, Nuzzle = 0.2, Butt = 0, Wag = 1.0 },
}
local IDLES = { "LookAround", "Sniff", "Graze", "Browse", "Hop" }

local folder: Folder
local function lf(): Folder
	if folder and folder.Parent then return folder end
	folder = Instance.new("Folder")
	folder.Name = "DinoPaddockProps"
	folder.Parent = Workspace
	return folder
end

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
local function ease01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function myRoot(): BasePart? return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart? end
local function myHum(): Humanoid? return player.Character and player.Character:FindFirstChildOfClass("Humanoid") end
local function swimmer(rec): boolean return rec.Species == "Mosasaurus" end
local function speciesName(sp: string): string
	local s = Config.Species[sp]
	return s and s.Name or sp
end

-- the floor under a point (ignoring characters, dinos, vehicles and our own props)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function refreshRay()
	local list = { lf() }
	local camp = Workspace:FindFirstChild("DinoCampLocal")
	if camp then table.insert(list, camp) end
	local vehicles = Workspace:FindFirstChild("ActiveVehicles")
	if vehicles then table.insert(list, vehicles) end
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
	rayParams.FilterDescendantsInstances = list
end
local function groundAt(pos: Vector3): number?
	local hit = Workspace:Raycast(pos + Vector3.new(0, 14, 0), Vector3.new(0, -60, 0), rayParams)
	return hit and hit.Position.Y or nil
end

-- the head (and mouth) of a yard dino
local function headOf(rec): BasePart?
	local m = rec.Anim and rec.Anim.Motors.Head
	return m and m.Part1 or rec.Root
end
local function mouthOf(rec): Vector3
	local head = headOf(rec) :: BasePart
	local jaw = rec.Anim and rec.Anim.Motors.Jaw and rec.Anim.Motors.Jaw.Part1
	local look = flat(rec.Root.CFrame.LookVector)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local p = (jaw or head).Position
	return p + look * (head.Size.Z * 0.45)
end

--------------------------------------------------------------------------------
-- hearts: a little pixel heart that floats up and fades (the blocky style)
--------------------------------------------------------------------------------
local HEART = { "01010", "11111", "11111", "01110", "00100" }
local function heart(pos: Vector3, size: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = pos + Vector3.new((math.random() - 0.5) * 1.2, 0, (math.random() - 0.5) * 1.2)
	anchor.Parent = lf()
	local bb = Instance.new("BillboardGui")
	local px = (size or 1) * 34
	bb.Size = UDim2.fromOffset(px, px)
	bb.LightInfluence = 0
	bb.Parent = anchor
	local cells = {}
	for r, row in ipairs(HEART) do
		for c = 1, #row do
			if row:sub(c, c) == "1" then
				local f = Instance.new("Frame")
				f.BorderSizePixel = 0
				f.BackgroundColor3 = (r <= 2 and c == 2) and PINK_HI or PINK
				f.Size = UDim2.fromScale(1 / 5, 1 / 5)
				f.Position = UDim2.fromScale((c - 1) / 5, (r - 1) / 5)
				f.Parent = bb
				table.insert(cells, f)
			end
		end
	end
	local rise = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, rise, { Position = anchor.Position + Vector3.new(0, 2.6, 0) }):Play()
	task.delay(0.5, function()
		for _, f in ipairs(cells) do TweenService:Create(f, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play() end
	end)
	task.delay(1.2, function() anchor:Destroy() end)
end
local function heartBurst(pos: Vector3, n: number)
	for i = 1, n do task.delay((i - 1) * 0.07, heart, pos, 0.8 + math.random() * 0.5) end
	DinosaurVFX.Cubes(pos, 8, { PINK, PINK_HI, Color3.new(1, 1, 1) }, 0.22, 7, 0.8)
	local Audio = require(script.Parent.Audio)
	Audio.Play("Pet", { At = pos })
	Audio.Play("BabyChirp", { At = pos, Volume = 0.8, Pitch = 1.1 })
end
PaddockLife.Heart = heart
PaddockLife.Hearts = heartBurst

--------------------------------------------------------------------------------
-- props in every paddock
--------------------------------------------------------------------------------
local placed = {} :: { [Model]: any }
local state = {
	Busy = false, Holding = nil :: string?, HeldModel = nil :: Model?, Fetch = nil :: any, Reticle = nil :: BasePart?,
}
local onPrompt -- forward

local function prepModel(m: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true d.CanQuery = false d.CanTouch = false end
	end
	return m
end

local function placeProp(name: string, yard: BasePart, x: number, z: number): Model?
	local t = Props:FindFirstChild(name)
	if not t then return nil end
	local m = t:Clone() :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true d.CanTouch = false d.CanQuery = d.CanCollide end
	end
	local p = yard.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
	local floor = groundAt(p) or (yard.Position.Y - 0.3)
	m:PivotTo(CFrame.new(p.X, floor + 0.2, p.Z) * yard.CFrame.Rotation)
	m.Parent = lf()
	return m
end

-- the hologram in the machine's dome: your companion, small and teal, slowly turning
local function holoFor(entry, species: string?)
	if entry.HoloSpecies == species then return end
	entry.HoloSpecies = species
	if entry.Holo then entry.Holo:Destroy() entry.Holo = nil end
	if entry.Ask then entry.Ask.Enabled = species == nil end
	local t = species and DinoT:FindFirstChild(species)
	local centre = entry.Machine:FindFirstChild("DomeCenter", true) :: BasePart?
	if not (t and centre) then return end
	local m = prepModel(t:Clone() :: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.Material = Enum.Material.ForceField
			d.Color = TEAL
		elseif d:IsA("Decal") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local _, size = m:GetBoundingBox()
	m:ScaleTo(2.3 / math.max(size.X, size.Y, size.Z))
	m.Parent = lf()
	entry.Holo = m
	entry.HoloCentre = centre
end

local function bindPaddock(pd)
	local yard = pd.Yard :: BasePart?
	if not yard or placed[pd.Plot] then return end
	refreshRay()
	local entry = { Plot = pd.Plot }
	entry.Machine = placeProp("CompanionMachine", yard, -9, 48)
	entry.Barrel = placeProp("TreatBarrel", yard, -2.6, 49.2)
	entry.Crate = placeProp("ToyCrate", yard, 1.8, 49.2)
	-- the yard kit, just left of the Companion pad (or right of the play corner if the yard's too narrow there)
	local kitX = (yard.Size.X / 2 > 20) and -17 or 7
	entry.Yard = placeProp("YardKit", yard, kitX, 48.6)
	if entry.Yard and pd.Own then PaddockLife.YardKit = entry.Yard end
	if not entry.Machine then return end
	placed[pd.Plot] = entry
	entry.Screen = entry.Machine:FindFirstChild("Screen", true)
	entry.Button = entry.Machine:FindFirstChild("BigButton", true) or entry.Machine:FindFirstChild("HomeButton", true)
	entry.Tiles = {}
	for i = 1, 3 do entry.Tiles[i] = entry.Machine:FindFirstChild("SlotTile" .. i, true) end
	entry.ButtonCF = entry.Button and entry.Button.CFrame
	-- a "?" in the empty dome until you've picked a companion
	local centre = entry.Machine:FindFirstChild("DomeCenter", true)
	if centre then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(60, 60)
		bb.LightInfluence = 0
		bb.MaxDistance = 90
		Kit.Text(bb, "?", { Size = UDim2.fromScale(1, 1), Stroke = 3, Shadow = 2 })
		bb.Parent = centre
		entry.Ask = bb
	end
	for _, m in ipairs({ entry.Machine, entry.Barrel, entry.Crate, entry.Yard }) do
		for _, pr in ipairs(m and m:GetDescendants() or {}) do
			if pr:IsA("ProximityPrompt") then
				pr.Triggered:Connect(function() onPrompt(pr:GetAttribute("CampAction"), entry) end)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- holding things (a treat or a ball in your right hand)
--------------------------------------------------------------------------------
local function handCF(): CFrame?
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then return nil end
	return hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.2, -0.15)
end

local function setHolding(what: string?)
	if state.HeldModel then state.HeldModel:Destroy() state.HeldModel = nil end
	state.Holding = what
	if what then
		local t = Props:FindFirstChild(what == "Ball" and "PlayBall" or "Treat")
		if t then
			local m = prepModel(t:Clone() :: Model)
			for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end
			m.Parent = lf()
			state.HeldModel = m
		end
	end
	-- (a toy ball in your hand: at a nest site the click throws it instead of a dart)
	player:SetAttribute("HoldingBall", what == "Ball" or nil)
end
-- balls in your pocket: the last reply from the server wins until the next profile snapshot catches up
local pocketCount = { N = nil :: number?, At = 0 }
local function setBalls(n: number?)
	if typeof(n) == "number" then pocketCount.N, pocketCount.At = n, os.clock() end
end
local function ballsLeft(): number
	if pocketCount.N and os.clock() - pocketCount.At < 4 then return pocketCount.N end
	return (Net.Profile and Net.Profile.Balls) or 0
end

--------------------------------------------------------------------------------
-- companions (every plot's, so everyone sees everyone's companion follow them)
--------------------------------------------------------------------------------
local comps = {} :: { [Model]: { [string]: any } } -- plot -> dino id -> companion state
local returning = {} :: { [any]: boolean }

-- a blue outline on a companion while it's out with you: it's your friend
local function friendOutline(model: Model, on: boolean)
	local h = model:FindFirstChild("FriendOutline") :: Highlight?
	if on and not h then
		local nh = Instance.new("Highlight")
		nh.Name = "FriendOutline"
		nh.FillTransparency = 1
		nh.OutlineColor = Color3.fromRGB(70, 160, 255)
		nh.OutlineTransparency = 0.05
		nh.DepthMode = Enum.HighlightDepthMode.Occluded
		nh.Parent = model
	elseif not on and h then
		h:Destroy()
	end
end

local function setLoco(c, mode: string)
	if c.Loco ~= mode and c.Rec.Anim then
		c.Loco = mode
		c.Rec.Anim:SetLocomotion(mode, 0.25)
	end
end

local function sendHome(c)
	-- back to roaming the paddock at its full size
	local rec = c.Rec
	if c.ScaleK ~= 1 and rec.Model.Parent then
		rec.Model:ScaleTo(rec.Model:GetScale() / c.ScaleK)
		if rec.Anim then rec.Anim.AnimScale /= c.ScaleK end
		rec.Lift /= c.ScaleK
		c.ScaleK = 1
	end
	if c.Out and rec.Root.Parent then
		local p = rec.Random()
		rec.Root.CFrame = CFrame.new(p.X, rec.FloorY + rec.Lift, p.Z) * rec.Root.CFrame.Rotation
	end
	c.Out = false
	friendOutline(rec.Model, false)
	rec.Hold = false
	rec.Wait = 1 + math.random() * 2
	if rec.Anim then rec.Anim:SetLocomotion("Idle", 0.3) end
	c.Loco = "Idle"
end

-- out with you, it stands at its companion size (Config.BuddyScale - near its wild size), not its yard size;
-- only a giant is capped, so it still fits over the bridges and through the garage
local function shrinkForWalk(c)
	if c.ScaleK ~= 1 then return end
	local rec = c.Rec
	local d = { Species = rec.Species, KG = rec.KG or 0 }
	local k = (rec.KG and Config.BuddyScale(d) / math.max(0.05, Config.DinoScale(d))) or 1
	local h = rec.Model:GetExtentsSize().Y * k
	if h > FOLLOW_MAX_HEIGHT then k *= FOLLOW_MAX_HEIGHT / h end
	if math.abs(k - 1) < 0.02 then return end
	rec.Model:ScaleTo(rec.Model:GetScale() * k)
	if rec.Anim then rec.Anim.AnimScale *= k end
	rec.Lift *= k
	c.ScaleK = k
end

--------------------------------------------------------------------------------
-- getting about: a dino walks on the floor under its feet (it never pops up onto a roof overhead), jumps up onto
-- ledges and hops down off them, and when a wall's in the way it routes round it (PathfindingService, sized to the
-- dino), sliding along the wall while the route is worked out
--------------------------------------------------------------------------------
local STEP_UP = 1.4 -- walks straight up anything lower than this
local JUMP_UP = 7 -- jumps up onto anything up to this high
local obstacleParams = RaycastParams.new()
obstacleParams.FilterType = Enum.RaycastFilterType.Exclude
obstacleParams.RespectCanCollide = true
local function refreshObstacles()
	local list = {}
	for _, n in ipairs({ "DinoCampLocal", "DinoCrewRiders" }) do
		local f = Workspace:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
	obstacleParams.FilterDescendantsInstances = list
end

-- the floor at a spot, looking down from just above the dino's own feet height
local function floorNear(p: Vector3, refY: number, up: number): number?
	local hit = Workspace:Raycast(Vector3.new(p.X, refY + up, p.Z), Vector3.new(0, -(up + 24), 0), rayParams)
	return hit and hit.Position.Y or nil
end
-- (2026-10-12) Base Camp is islands in a Terrain-water lagoon: the floor rays land on the water's surface, so a
-- companion checks for it and waits on the shore (or the bridge) instead of walking out over the water
local function wetAt(p: Vector3, refY: number): boolean
	local hit = Workspace:Raycast(Vector3.new(p.X, refY + 4, p.Z), Vector3.new(0, -28, 0), rayParams)
	return hit ~= nil and hit.Material == Enum.Material.Water
end

local function startJump(rec, nav, from: Vector3, to: Vector3)
	local rise = math.max(0, to.Y - from.Y)
	nav.Jump = { From = from, To = to, T = 0, D = math.clamp(0.38 + rise * 0.04 + flat(to - from).Magnitude * 0.03, 0.4, 0.75), H = rise * 0.5 + 1.4 }
	local anim = rec.Anim
	if anim then
		local a = (anim:HasAction("Jump") and "Jump") or (anim:HasAction("Hop") and "Hop") or nil
		if a then anim:Play(a, { Speed = 1.4 }) end
	end
end

local function requestPath(rec, nav, from: Vector3, goal: Vector3)
	if nav.Computing or os.clock() < (nav.NextPath or 0) then return end
	nav.Computing = true
	nav.NextPath = os.clock() + 1
	local ext = rec.Model:GetExtentsSize()
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = math.clamp(math.min(ext.X, ext.Z) * 0.4, 1.2, 4), AgentHeight = math.clamp(ext.Y, 2.5, 9),
			AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 5,
		})
		local ok = pcall(function() path:ComputeAsync(from, goal) end)
		nav.Computing = false
		if ok and path.Status == Enum.PathStatus.Success then
			nav.Path, nav.WP, nav.PathGoal, nav.Failed = path:GetWaypoints(), 2, goal, 0
		else
			nav.Path = nil
			nav.Failed = (nav.Failed or 0) + 1
		end
	end)
end

-- one frame of walking / running a held dino toward a point on the ground; returns the flat distance left
local function moveToward(rec, c, goal: Vector3, speed: number, dt: number): number
	local root = rec.Root
	rec.Nav = rec.Nav or {}
	local nav = rec.Nav
	local feet = root.Position - Vector3.new(0, rec.Lift, 0)
	local left = flat(goal - feet).Magnitude
	-- mid-jump: ride the arc
	if nav.Jump then
		local j = nav.Jump
		j.T += dt
		local u = math.min(j.T / j.D, 1)
		local p = j.From:Lerp(j.To, u) + Vector3.new(0, math.sin(u * math.pi) * j.H, 0)
		root.CFrame = CFrame.new(p + Vector3.new(0, rec.Lift, 0)) * root.CFrame.Rotation
		if u >= 1 then
			nav.Jump = nil
			DinosaurVFX.FootstepDust(j.To, 0.4)
		end
		if c then setLoco(c, "Idle") end
		return left
	end
	if left < 0.3 then
		if c then setLoco(c, "Idle") end
		return left
	end
	-- heading for a waypoint while routing round something, else straight at the goal
	local aim = goal
	if nav.Path and nav.PathGoal and flat(nav.PathGoal - goal).Magnitude < 10 then
		local wp = nav.Path[nav.WP]
		while wp and flat(wp.Position - feet).Magnitude < 1.6 do
			nav.WP += 1
			wp = nav.Path[nav.WP]
		end
		if wp then aim = wp.Position else nav.Path = nil end
	else
		nav.Path = nil
	end
	local d = flat(aim - feet)
	if d.Magnitude < 0.05 then return left end
	local dir = d.Unit
	local stepLen = math.min(d.Magnitude, speed * dt)
	local ext = rec.Model:GetExtentsSize()
	-- something solid ahead at knee height: a ledge to jump onto, or a wall to go round
	local hit = Workspace:Raycast(feet + Vector3.new(0, STEP_UP + 0.2, 0), dir * (math.max(ext.X, ext.Z) * 0.35 + stepLen + 0.6), obstacleParams)
	if hit then
		local over = hit.Position + dir * 0.9
		local top = floorNear(over, feet.Y, JUMP_UP + 0.5)
		local clear = top ~= nil and Workspace:Raycast(Vector3.new(over.X, top + 0.3, over.Z), Vector3.new(0, math.min(ext.Y, 6), 0), obstacleParams) == nil
		if top and clear and top - feet.Y <= JUMP_UP and top > feet.Y + STEP_UP * 0.5 then
			startJump(rec, nav, feet, Vector3.new(over.X, top, over.Z) + dir * math.min(1.5, ext.Z * 0.3))
			return left
		end
		requestPath(rec, nav, feet, goal)
		if nav.Path then return left end
		local n = hit.Normal
		local slide = flat(dir - n * dir:Dot(n))
		if slide.Magnitude < 0.25 then
			if c then setLoco(c, "Idle") end
			return left
		end
		dir = slide.Unit
	end
	local nx = feet + dir * stepLen
	if wetAt(nx + dir * 1.5, feet.Y) then
		if c then setLoco(c, "Idle") end
		return left
	end
	local floor = floorNear(nx, feet.Y, STEP_UP)
	if not floor then
		-- a long drop: find another way
		requestPath(rec, nav, feet, goal)
		if c then setLoco(c, "Idle") end
		return left
	end
	if floor < feet.Y - 2.2 then
		-- hop down off the ledge
		local land = nx + dir * 1.2
		startJump(rec, nav, feet, Vector3.new(land.X, floorNear(land, floor, 2) or floor, land.Z))
		return left
	end
	local y = feet.Y + (floor - feet.Y) * math.min(1, dt * 14)
	local yaw = math.atan2(-dir.X, -dir.Z)
	local _, cy = root.CFrame:ToEulerAnglesYXZ()
	local ny = cy + math.atan2(math.sin(yaw - cy), math.cos(yaw - cy)) * math.min(1, dt * 8)
	root.CFrame = CFrame.new(nx.X, y + rec.Lift, nx.Z) * CFrame.Angles(0, ny, 0)
	if c then setLoco(c, speed > 11 and "Run" or "Walk") end
	return left
end

local function faceToward(rec, point: Vector3, dt: number, rate: number?)
	local root = rec.Root
	local d = flat(point - root.Position)
	if d.Magnitude < 0.1 then return end
	local yaw = math.atan2(-d.X, -d.Z)
	local _, cy = root.CFrame:ToEulerAnglesYXZ()
	local ny = cy + math.atan2(math.sin(yaw - cy), math.cos(yaw - cy)) * math.min(1, dt * (rate or 5))
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, ny, 0)
end

local function stepCompanion(c, owner: Player?, dt: number)
	local rec = c.Rec
	if not rec.Root.Parent then return end
	local hrp = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- on an expedition it rides in your rover (Crew.luau) instead
	local inCamp = hrp ~= nil and inCampBox(hrp.Position)
		and not (owner :: Player):GetAttribute("Crew")
	if not inCamp then
		-- you're away: it waits in the paddock, and runs over to greet you when you're back
		if c.Mode ~= "Home" then
			if c.Mode ~= nil then c.Missed = true end
			c.Mode = "Home"
			sendHome(c)
		end
		return
	end
	if c.Pause then return end -- being petted / chasing a ball
	if c.Mode == "Home" or c.Mode == nil then
		c.Mode = c.Missed and "Greet" or "Follow"
		c.Missed = false
		c.Greeted = false
	end
	rec.Hold = true
	c.Out = true
	friendOutline(rec.Model, true)
	shrinkForWalk(c)
	-- (2026-10-13) you're driving at camp: a small companion hops in beside you (your lead one gets shotgun, the others
	-- the back), a medium one rides in the back; a big one keeps running alongside (the follow below)
	do
		local hum = owner and owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
		local seatPart = hum and hum.SeatPart
		local veh: Instance? = seatPart and seatPart.Parent
		while veh and not (veh:IsA("Model") and veh:GetAttribute("Owner") ~= nil) do veh = veh.Parent end
		local class = veh and Crew.SizeClass(rec.Species)
		local pass = veh and veh:FindFirstChild("PassengerSeat", true) :: BasePart?
		-- a friend aboard: it runs along behind the rover instead (2026-10-14, user: "when a friend gets in the car it
		-- should follow behind")
		local occ = pass and pass:IsA("Seat") and pass.Occupant
		local guest = (occ ~= nil and occ.Parent ~= nil and Players:GetPlayerFromCharacter(occ.Parent) ~= owner) or (pass ~= nil and pass:GetAttribute("Taken") ~= nil)
		c.Behind = (veh ~= nil and guest) and (veh :: Model) or nil
		if veh and pass and class ~= "Big" and not guest then
			local at
			if class == "Small" and c.Slot == 1 and not pass:GetAttribute("Taken") then
				at = pass.CFrame * CFrame.new(0, pass.Size.Y / 2, 0.1)
			else
				at = pass.CFrame * CFrame.new(-0.4 - ((c.Slot or 1) - 1) * 1.7, pass.Size.Y / 2 + 0.5, 2.6)
			end
			rec.Root.CFrame = at * CFrame.new(0, rec.Lift, 0)
			if c.Loco ~= "Idle" and rec.Anim then c.Loco = "Idle" rec.Anim:SetLocomotion("Idle", 0.2) end
			c.Riding = true
			return
		elseif c.Riding then
			-- out of the rover: it hops down beside your door
			c.Riding = false
			local out = (hrp :: BasePart).CFrame:PointToWorldSpace(Vector3.new(4, 0, 2))
			local floor = floorNear(out, (hrp :: BasePart).Position.Y - 3, 4) or ((hrp :: BasePart).Position.Y - 3)
			rec.Root.CFrame = CFrame.new(out.X, floor + rec.Lift, out.Z) * rec.Root.CFrame.Rotation
		end
	end
	local hrpP = (hrp :: BasePart).Position
	local size = rec.Model:GetExtentsSize()
	local away = flat(rec.Root.Position - hrpP).Magnitude
	-- too far behind (you drove off): catch up off-screen, just behind you
	if away > 75 then
		local back = (hrp :: BasePart).CFrame:PointToWorldSpace(Vector3.new(4, 0, 14 + size.Z))
		-- you're swimming: it waits until you're back on land (a land spot with water just behind you - a beach, the
		-- gate pier - just moves the spot beside you instead)
		if owner and owner:GetAttribute("Swimming") then return end
		if wetAt(back, hrpP.Y - 3) then back = (hrp :: BasePart).CFrame:PointToWorldSpace(Vector3.new(6 + size.X * 0.5, 0, 0)) end
		if wetAt(back, hrpP.Y - 3) then return end
		local floor = floorNear(back, hrpP.Y - 3, 4) or hrpP.Y - 3
		rec.Root.CFrame = CFrame.new(back.X, floor + rec.Lift, back.Z) * rec.Root.CFrame.Rotation
		return
	end
	local ownerSpeed = flat((hrp :: BasePart).AssemblyLinearVelocity).Magnitude
	if c.Mode == "Greet" then
		-- runs straight to you, hops, hearts
		local front = hrpP + flat((hrp :: BasePart).CFrame.LookVector) * (2.5 + size.Z * 0.5)
		local left = moveToward(rec, c, front, 26, dt)
		if left < 1 then
			c.Mode = "Follow"
			faceToward(rec, hrpP, 1, 1)
			if rec.Anim then rec.Anim:Play(rec.Anim:HasAction("Hop") and "Hop" or (rec.Anim:HasAction("Roar") and "Roar" or "LookAround")) end
			heartBurst((headOf(rec) :: BasePart).Position + Vector3.new(0, 1, 0), 5)
			c.IdleAt = os.clock() + 2
		end
		return
	end
	-- follow: a spot behind you (the lead to your right, the second to your left, the third straight behind), with
	-- room for its whole body. (2026-10-12: big ones crowded you.) The spot follows the way you're WALKING, not where
	-- you face, so turning on the spot doesn't send it circling round you; standing still, it keeps its last spot.
	local slot = c.Slot or 1
	c.Size = c.Size or size -- (a steady size: the animated extents breathe every frame)
	local sz = c.Size :: Vector3
	local vel = flat((hrp :: BasePart).AssemblyLinearVelocity)
	if vel.Magnitude > 3 then
		local want = vel.Unit
		c.Heading = c.Heading and (c.Heading :: Vector3):Lerp(want, math.min(1, dt * 3)) or want
		if (c.Heading :: Vector3).Magnitude > 0.01 then c.Heading = (c.Heading :: Vector3).Unit end
	elseif not c.Heading then
		c.Heading = flat((hrp :: BasePart).CFrame.LookVector).Unit
	end
	local fwd = c.Heading :: Vector3
	local right = fwd:Cross(Vector3.yAxis)
	-- (more room than before: a Triceratops followed too closely - 2026-10-14)
	local back = 5.5 + sz.Z * 0.85
	local side = 4.5 + sz.X * 0.8
	if c.Behind and c.Behind.Parent then
		-- running behind the rover a friend's riding in: clear of its tail, roughly in its tracks
		local ok, ext = pcall(function() return (c.Behind :: Model):GetExtentsSize() end)
		back += (ok and math.max(ext.X, ext.Z) * 0.5 or 7) + 2
		side = 1.5 + sz.X * 0.4
	end
	local spot = slot == 1 and (hrpP - fwd * back + right * side)
		or (slot == 2 and (hrpP - fwd * back - right * side) or (hrpP - fwd * (back + 4 + sz.Z * 0.4)))
	-- route-finding gave up and it's well behind: pop over to you (with a puff) rather than stand stuck
	if (rec.Nav and (rec.Nav.Failed or 0) >= 3) and flat(spot - rec.Root.Position).Magnitude > 30 and not wetAt(spot, hrpP.Y - 3) then
		DinosaurVFX.FootstepDust(rec.Root.Position, 1)
		local floor = floorNear(spot, hrpP.Y - 3, 4) or (hrpP.Y - 3)
		rec.Root.CFrame = CFrame.new(spot.X, floor + rec.Lift, spot.Z) * rec.Root.CFrame.Rotation
		rec.Nav.Failed = 0
		DinosaurVFX.FootstepDust(spot, 1)
		return
	end
	local dist = flat(spot - rec.Root.Position).Magnitude
	-- personal space: a companion right on top of you backs off; otherwise it only sets off once it's properly out of
	-- place (and settles a little short), instead of shuffling after every step you take
	local room = sz.Z * 0.5 + 4.5
	local tooClose = away < room
	local startAt = 2.5 + sz.Z * 0.2
	if dist > startAt or tooClose or c.Moving then
		c.Moving = dist > 1.2
		local speed = math.clamp(dist * 2.2, 4, math.max(14, ownerSpeed * 1.15 + 4))
		moveToward(rec, c, spot, speed, dt)
		c.IdleAt = os.clock() + 4 + math.random() * 4
	else
		setLoco(c, "Idle")
		faceToward(rec, hrpP, dt, 3)
		-- standing about with you: looks around, sniffs, now and then
		if os.clock() > (c.IdleAt or 0) and rec.Anim and not rec.Anim:IsPlaying() then
			c.IdleAt = os.clock() + 6 + math.random() * 6
			for _ = 1, 4 do
				local a = IDLES[math.random(1, #IDLES)]
				if rec.Anim:HasAction(a) then rec.Anim:Play(a) break end
			end
		end
	end
end

-- a plot's companion list, decoded only when the attribute changes (this was two JSON decodes per plot per frame)
local compCache = setmetatable({}, { __mode = "k" }) :: { [Instance]: { Raw: string, Ids: { any } } }
local function companionIds(plot: Instance): { any }
	local raw = plot:GetAttribute("Companions") or "[]"
	local c = compCache[plot]
	if c and c.Raw == raw then return c.Ids end
	local ok, ids = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or typeof(ids) ~= "table" then ids = {} end
	compCache[plot] = { Raw = raw, Ids = ids }
	return ids
end

local function stepCompanions(dt: number)
	for _, pd in ipairs(CampView.Paddocks()) do
		local plot = pd.Plot
		local ids = companionIds(plot)
		local mine = comps[plot] or {}
		comps[plot] = mine
		local want = {}
		for slot, id in ipairs(ids) do
			local rec = pd.Dinos[id]
			if rec and not swimmer(rec) then want[id] = { Rec = rec, Slot = slot } end
		end
		-- unequipped (it walks back into the pen through the gate), or the model was rebuilt / sold / stored
		for id, c in pairs(mine) do
			local w = want[id]
			if not w or w.Rec ~= c.Rec then
				if w == nil and c.Out and c.Rec.Root.Parent and c.Rec.Model.Parent then
					c.Gate = plot:FindFirstChild("PaddockGateIn", true)
					c.Yard = pd.Yard
					returning[c] = true
				elseif c.Rec.Root.Parent then
					sendHome(c)
				end
				mine[id] = nil
			end
		end
		local owner = Players:GetPlayerByUserId(plot:GetAttribute("Owner") or 0)
		local lead = nil
		for id, w in pairs(want) do
			local c = mine[id]
			if not c then
				-- re-equipped while it was still walking home: that walk stops (two things steered it at once)
				for r in pairs(returning) do if r.Rec == w.Rec then returning[r] = nil end end
				c = { Rec = w.Rec, Plot = plot, ScaleK = 1, Mode = nil, Loco = nil }
				mine[id] = c
			end
			c.Slot = w.Slot
			if w.Slot == 1 then lead = w.Rec end
			stepCompanion(c, owner, dt)
		end
		local entry = placed[plot]
		if entry and entry.Machine then holoFor(entry, lead and lead.Species or nil) end
	end
	-- the Pal Pad's three slot tiles: a lit tile with the companion's name, an open "+", or LOCKED
	for plot, entry in pairs(placed) do
		local ids = companionIds(plot)
		local open = plot:GetAttribute("CompanionSlots") or 1
		local key = table.concat(ids, ",") .. "|" .. tostring(open)
		if entry.TileKey ~= key and entry.Tiles then
			entry.TileKey = key
			local dinos = nil
			for _, pd in ipairs(CampView.Paddocks()) do if pd.Plot == plot then dinos = pd.Dinos end end
			for i, tile in ipairs(entry.Tiles) do
				local rec = ids[i] and dinos and dinos[ids[i]]
				local label = tile:FindFirstChild("TileText", true)
				local sp = rec and Config.Species[rec.Species]
				if rec then
					tile.Color = (sp and sp.Color or TEAL):Lerp(Color3.new(1, 1, 1), 0.25)
				elseif i <= open then
					tile.Color = Color3.fromRGB(42, 107, 99)
				else
					tile.Color = Color3.fromRGB(58, 61, 66)
				end
				if label then
					local text = rec and string.upper(sp and sp.Name or rec.Species) or (i <= open and "+" or "LOCKED")
					for _, l in ipairs(label:GetDescendants()) do if l:IsA("TextLabel") then l.Text = text end end
				end
			end
		end
	end
	-- the holograms turn
	local t = os.clock()
	for _, entry in pairs(placed) do
		if entry.Holo and entry.HoloCentre then
			entry.Holo:PivotTo(CFrame.new(entry.HoloCentre.Position + Vector3.new(0, math.sin(t * 2) * 0.1, 0)) * CFrame.Angles(0, t * 0.8, 0))
		end
	end
end

-- unequipped companions walking home: to the paddock gate, then in; once inside they roam again at full size
local function stepReturning(dt: number)
	for c in pairs(returning) do
		local rec = c.Rec
		if not (rec.Root.Parent and rec.Model.Parent and c.Gate) then returning[c] = nil continue end
		local yard = c.Yard :: BasePart?
		local inside = false
		if yard then
			local lp = yard.CFrame:PointToObjectSpace(rec.Root.Position)
			inside = math.abs(lp.X) < yard.Size.X / 2 - 2 and math.abs(lp.Z) < yard.Size.Z / 2 - 2
		end
		local goal = c.Gate.Position
		local left = inside and 0 or moveToward(rec, c, goal, 12, dt)
		if inside or left < 1.5 then
			c.Out = false -- it's walked in: no teleport
			sendHome(c)
			returning[c] = nil
		else
			-- (islands: from the hub or another island the way home can be over water; a companion that stops making
			-- progress - at a shore - or takes too long pops home instead of standing there for good)
			local now = os.clock()
			c.ReturnT0 = c.ReturnT0 or now
			if not c.ReturnBest or left < c.ReturnBest - 1 then c.ReturnBest, c.ReturnAt = left, now end
			if now - (c.ReturnAt or now) > 2.5 or now - c.ReturnT0 > 25 then
				c.ReturnT0, c.ReturnBest, c.ReturnAt = nil, nil, nil
				sendHome(c) -- (c.Out still set: the teleport home)
				returning[c] = nil
			end
		end
	end
end

local function compOf(rec)
	for _, mine in pairs(comps) do
		for _, c in pairs(mine) do if c.Rec == rec then return c end end
	end
	return nil
end

--------------------------------------------------------------------------------
-- petting and feeding
--------------------------------------------------------------------------------
-- the dino's side of it: leans its head into your hand, eyes shut, tail going; chomps when it's a treat
local function reactLayer(rec, react, opts)
	local t0 = os.clock()
	return function(anim, _dt)
		local t = os.clock() - t0
		local env = opts.Env()
		if env <= 0.001 then return end
		local hrp = myRoot()
		local head = headOf(rec)
		local root = rec.Root
		local yaw, bow = 0, 0
		if hrp and head then
			local rel = root.CFrame:PointToObjectSpace(hrp.Position)
			yaw = math.clamp(math.atan2(-rel.X, -rel.Z), -0.9, 0.9)
			-- lower the head to your chest (a giant bows its whole neck)
			local above = head.Position.Y - (hrp.Position.Y + 1.0)
			bow = -math.clamp(above / 6, 0, 1.2) * react.Bow
			-- a little one lifts its head up to your hand
			if above < -1.2 then bow = math.min(0.35, (-1.2 - above) / 5) end
		end
		local G = anim.Profile.Gait
		local neck = G.Neck or {}
		local n = math.max(1, #neck)
		for _, j in ipairs(neck) do anim:Add(j, bow / n, yaw * 0.6 / n, 0, 0, 0, 0, env) end
		local pat = opts.Pat and opts.Pat() or 0
		local nuzzle = math.sin(t * 7) * react.Nuzzle
		local butt = react.Butt > 0 and -math.max(0, math.sin(t * 5.5)) * 0.22 * react.Butt or 0
		anim:Add("Head", bow * 0.2 + butt - pat * 0.12, yaw * 0.4 + nuzzle, nuzzle * 0.7, 0, 0, 0, env)
		local tail = G.Tail or {}
		for i, j in ipairs(tail) do
			anim:Add(j, 0, math.sin(t * 10 - i * 0.6) * 0.16 * react.Wag * (0.4 + i / #tail), 0, 0, 0, 0, env)
		end
		if opts.Chomp then anim:Add("Jaw", -0.55 * opts.Chomp(), 0, 0, 0, 0, 0, env) end
		if opts.Hop then anim:Add("Pelvis", 0, 0, 0, 0, opts.Hop(), 0, 1) end
	end
end

local function pet(rec, feed: boolean)
	if state.Busy then return end
	local char = player.Character
	local hrp, hum = myRoot(), myHum()
	local anim = rec.Anim
	local head = headOf(rec)
	if not (char and hrp and hum and anim and head) or hum.SeatPart then return end
	state.Busy = true
	local c = compOf(rec)
	if c then c.Pause = true end
	rec.Hold = true
	anim:StopActions(0.2)
	local react = REACT[rec.Species] or REACT.Default
	local oldRotate = hum.AutoRotate
	hum:SetAttribute("Frozen", true)
	hum.AutoRotate = false
	local root = rec.Root

	-- 1. it comes over so its head is just in front of you
	local headFwd = math.max(0, -root.CFrame:PointToObjectSpace(head.Position).Z)
	local t0 = os.clock()
	while os.clock() - t0 < 1.6 do
		local dt = RunService.RenderStepped:Wait()
		local toMe = flat(hrp.Position - root.Position)
		if toMe.Magnitude < 0.1 then break end
		-- a low head comes in close (you bend down to it); a high one stays back a bit so you can reach up
		local low = math.clamp((hrp.Position.Y - head.Position.Y) / 2.5, 0, 1)
		local stand = hrp.Position - toMe.Unit * (headFwd + 2.3 - 0.8 * low)
		local left = moveToward(rec, nil, Vector3.new(stand.X, root.Position.Y, stand.Z), math.max(6, rec.Speed * 2), dt)
		faceToward(rec, hrp.Position, dt, 8)
		anim:SetLocomotion(left > 0.4 and "Walk" or "Idle", 0.2)
		local face = flat(head.Position - hrp.Position)
		if face.Magnitude > 0.1 then
			hrp.CFrame = hrp.CFrame:Lerp(CFrame.lookAt(hrp.Position, hrp.Position + face), math.min(1, dt * 10))
		end
		if left <= 0.4 then break end
	end
	anim:SetLocomotion("Idle", 0.2)

	-- 2. the pat (or the treat): your hand goes to the top of its head (or its mouth); a giant's flank if
	-- even bowing it can't get its head down to you
	local D = feed and 1.6 or 1.9
	local start = os.clock()
	local function u(): number return math.clamp((os.clock() - start) / D, 0, 1) end
	local function target(): Vector3
		local p = feed and mouthOf(rec) or (head.Position + Vector3.new(0, head.Size.Y * 0.5, 0))
		if p.Y > hrp.Position.Y + 3.4 then
			local toMe = flat(hrp.Position - root.Position)
			toMe = toMe.Magnitude > 0.1 and toMe.Unit or Vector3.zero
			local ext = rec.Model:GetExtentsSize()
			p = root.Position + toMe * math.min(ext.X, ext.Z) * 0.45
			p = Vector3.new(p.X, hrp.Position.Y + 0.8, p.Z)
		end
		return p
	end
	local env = function()
		local x = u()
		return math.min(ease01(x / 0.12), 1 - ease01((x - 0.82) / 0.18))
	end
	local hop = 0
	anim.Layer = reactLayer(rec, react, {
		Env = function() return math.max(env(), hop > 0 and 1 or 0) end,
		Pat = function() return feed and 0 or math.max(0, math.sin(u() * math.pi * 7)) end,
		Chomp = feed and function() local x = u() return (x > 0.3 and x < 0.8) and math.abs(math.sin(x * 40)) or 0 end or nil,
		Hop = function() return hop end,
	})
	PlayerAnim.Act(char, feed and "Feed" or "Pet", { Target = target, Duration = D })
	local nextHeart = 0.35
	while u() < 1 do
		RunService.RenderStepped:Wait()
		local x = u()
		anim.EyesClosed = not feed and x > 0.18 and x < 0.85
		if x >= nextHeart and x < 0.9 then
			nextHeart += feed and 0.3 or 0.22
			heart(head.Position + Vector3.new(0, head.Size.Y * 0.6 + 0.4, 0))
		end
		if feed and x > 0.55 and state.HeldModel then
			-- the treat's gone
			DinosaurVFX.Cubes(mouthOf(rec), 6, { Color3.fromRGB(200, 69, 42), Color3.fromRGB(243, 234, 210) }, 0.18, 5, 0.6)
			setHolding(nil)
		end
	end
	anim.EyesClosed = false

	-- 3. a happy hop and a burst of hearts, then back to what it was doing
	heartBurst(head.Position + Vector3.new(0, head.Size.Y * 0.6 + 0.5, 0), 4)
	if anim:HasAction("Hop") then
		anim:Play("Hop")
	else
		local h0 = os.clock()
		while os.clock() - h0 < 0.4 do
			RunService.RenderStepped:Wait()
			hop = math.sin((os.clock() - h0) / 0.4 * math.pi) * 0.6
		end
		hop = 0
	end
	anim.Layer = nil
	hum:SetAttribute("Frozen", nil)
	hum.AutoRotate = oldRotate
	if c then c.Pause = false else rec.Hold = false end
	if feed then setHolding(nil) end
	state.Busy = false
end

--------------------------------------------------------------------------------
-- the Companion Machine
--------------------------------------------------------------------------------
local function ownPaddock()
	for _, pd in ipairs(CampView.Paddocks()) do if pd.Own then return pd end end
	return nil
end

local function pressButton(entry)
	local char = player.Character
	if entry.Button and char then
		PlayerAnim.Act(char, "Tap", { Target = entry.Button.Position, Duration = 0.45 })
		local base = entry.ButtonCF
		if base then
			task.delay(0.15, function()
				entry.Button.CFrame = base * CFrame.new(0, -0.18, 0)
				task.wait(0.15)
				entry.Button.CFrame = base
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- fetch
--------------------------------------------------------------------------------
local function aimPoint(): Vector3?
	local hrp = myRoot()
	if not hrp then return nil end
	local p
	if Kit.Platform() == "Touch" or Kit.Gamepad() then
		local look = flat(Workspace.CurrentCamera.CFrame.LookVector)
		look = look.Magnitude > 0.01 and look.Unit or flat(hrp.CFrame.LookVector).Unit
		p = hrp.Position + look * 30
	else
		local mouse = player:GetMouse()
		p = mouse.Hit.Position
	end
	local d = flat(p - hrp.Position)
	local len = math.clamp(d.Magnitude, 8, 60)
	p = hrp.Position + (d.Magnitude > 0.01 and d.Unit or flat(hrp.CFrame.LookVector).Unit) * len
	local floor = groundAt(p) or (hrp.Position.Y - 3)
	return Vector3.new(p.X, floor, p.Z)
end

local function endFetch(f)
	for _, r in ipairs(f.Runners) do
		local c = compOf(r.Rec)
		if c then c.Pause = false else r.Rec.Hold = false end
		if r.Rec.Anim then r.Rec.Anim:SetLocomotion("Idle", 0.3) end
	end
	state.Fetch = nil
end

local function dropBallAtFeet(f, rec)
	local ball = f.Ball
	ball.Anchored = false
	ball.CanCollide = true
	ball.AssemblyLinearVelocity = Vector3.new(0, 4, 0)
	-- grab it again from the floor
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Grab Ball"
	pr.ObjectText = "Ball"
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Parent = ball
	pr.Triggered:Connect(function()
		local char = player.Character
		if char then PlayerAnim.Act(char, "Tap", { Target = ball.Position, Duration = 0.4 }) end
		task.wait(0.2)
		ball:Destroy()
		local res = Net.Ask("PickBall")
		if res and res.Ok then setBalls(res.Balls) setHolding("Ball") end
	end)
	task.delay(Config.Balls.Despawn, function() if ball.Parent then ball:Destroy() end end)
	local head = headOf(rec)
	if rec.Anim then rec.Anim:Play(rec.Anim:HasAction("Hop") and "Hop" or "LookAround") end
	if head then heartBurst(head.Position + Vector3.new(0, 1, 0), 4) end
end

local function stepFetch(dt: number)
	local f = state.Fetch
	if not f then return end
	f.T += dt
	local ball = f.Ball
	local hrp = myRoot()
	if not (ball.Parent and hrp) or f.T > 16 then
		if ball.Parent and not f.Winner then task.delay(2, function() if ball.Parent then ball:Destroy() end end) end
		endFetch(f)
		return
	end
	if f.T < 0.35 then return end -- a beat: they watch it fly
	if not f.Winner then
		for _, r in ipairs(f.Runners) do
			if not r.Rec.Root.Parent then continue end
			moveToward(r.Rec, nil, ball.Position, r.Speed, dt)
			r.Rec.Anim:SetLocomotion("Run", 0.2)
			local head = headOf(r.Rec) :: BasePart
			if (flat(head.Position - ball.Position)).Magnitude < 1.4 + head.Size.Z and ball.AssemblyLinearVelocity.Magnitude < 30 then
				f.Winner = r
				ball.Anchored = true
				ball.CanCollide = false
				-- the others give up
				for _, o in ipairs(f.Runners) do
					if o ~= r then
						local c = compOf(o.Rec)
						if c then c.Pause = false else o.Rec.Hold = false end
						if o.Rec.Anim then
							o.Rec.Anim:SetLocomotion("Idle", 0.3)
							if o.Rec.Anim:HasAction("LookAround") then o.Rec.Anim:Play("LookAround") end
						end
					end
				end
				break
			end
		end
	else
		-- the winner trots back with it in its mouth and drops it at your feet
		local rec = f.Winner.Rec
		ball.CFrame = CFrame.new(mouthOf(rec))
		local head = headOf(rec) :: BasePart
		local headFwd = math.max(0, -rec.Root.CFrame:PointToObjectSpace(head.Position).Z)
		local toMe = flat(hrp.Position - rec.Root.Position)
		local stand = hrp.Position - (toMe.Magnitude > 0.1 and toMe.Unit or Vector3.zero) * (headFwd + 2.5)
		local left = moveToward(rec, nil, stand, f.Winner.Speed * 0.8, dt)
		rec.Anim:SetLocomotion(left > 0.4 and "Run" or "Idle", 0.2)
		if left <= 0.4 then
			faceToward(rec, hrp.Position, 1, 1)
			dropBallAtFeet(f, rec)
			f.Runners = { f.Winner }
			endFetch(f)
		end
	end
end

local function throw()
	if state.Holding ~= "Ball" or state.Busy or state.Fetch then return end
	if require(script.Parent.UI.Cinema).Playing() then return end -- (never mid-cutscene: a click there is a skip)
	local char = player.Character
	local hrp, hum = myRoot(), myHum()
	local target = aimPoint()
	if not (char and hrp and hum and target) or hum.SeatPart then return end
	state.Busy = true
	-- turn to face the throw
	local face = flat(target - hrp.Position)
	if face.Magnitude > 0.1 then hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + face) end
	PlayerAnim.Act(char, "Throw")
	local atSite = player:GetAttribute("Site") ~= nil
	task.delay(0.24, function()
		local from = handCF()
		local t = Props:FindFirstChild("PlayBall")
		setHolding(nil)
		state.Busy = false
		setBalls(math.max(0, ballsLeft() - 1))
		local res = Net.Ask("ThrowBall", { Target = target })
		if not (res and res.Ok) or atSite or res.AtSite then return end
		if not (from and t) then return end
		local m = t:Clone() :: Model
		local ball = m.PrimaryPart :: BasePart
		ball.Parent = lf()
		m:Destroy()
		ball.Name = "FetchBall"
		ball.Anchored = false
		ball.CanCollide = true
		ball.CanQuery = false
		ball.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0.55)
		ball.CFrame = from
		local g = Workspace.Gravity
		local d = target - from.Position
		local T = math.clamp(flat(d).Magnitude / 30, 0.55, 1.4)
		ball.AssemblyLinearVelocity = d / T + Vector3.new(0, 0.5 * g * T, 0)
		-- the race: up to three dinos closest to where it lands
		local pd = ownPaddock()
		local runners = {}
		if pd then
			local list = {}
			for _, rec in pairs(pd.Dinos) do
				if swimmer(rec) or not rec.Root.Parent or rec.Hold and not compOf(rec) then continue end
				local dist = flat(rec.Root.Position - target).Magnitude
				if dist < 90 then table.insert(list, { Rec = rec, D = dist }) end
			end
			table.sort(list, function(a, b) return a.D < b.D end)
			for i = 1, math.min(3, #list) do
				local rec = list[i].Rec
				local c = compOf(rec)
				if c then c.Pause = true end
				rec.Hold = true
				if rec.Anim then rec.Anim:StopActions(0.15) end
				local size = rec.Model:GetExtentsSize()
				table.insert(runners, { Rec = rec, Speed = math.clamp(13 + 8 / math.max(1, size.Y) + math.random() * 4, 12, 22) })
			end
		end
		state.Fetch = { Ball = ball, Runners = runners, T = 0, Winner = nil }
	end)
end

--------------------------------------------------------------------------------
-- prompts
--------------------------------------------------------------------------------
onPrompt = function(action: string?, entry)
	local pd = ownPaddock()
	if not (pd and pd.Plot == entry.Plot) then return end
	if action == "Companion" then
		pressButton(entry)
		task.delay(0.3, function() Panels.Open("Companions") end)
	elseif action == "Yard" then
		-- one more yard space, paid on the spot (the cost is on the prompt)
		local char = player.Character
		if char and entry.Yard then PlayerAnim.Act(char, "Tap", { Target = entry.Yard:GetPivot().Position + Vector3.new(0, 3, 0), Duration = 0.4 }) end
		task.spawn(function()
			local res = Net.Ask("BuyBase", { What = "Pen" })
			if res and res.Ok then
				local p = Net.Profile
				local n = (p and p.PenSlots) or 0
				Kit.Toast("YARD EXPANDED!" .. (n > 0 and ("  " .. #((p and p.Placed) or {}) .. " / " .. n) or ""), "Green", "Paddock")
				if entry.Yard then
					local at = entry.Yard:GetPivot().Position + Vector3.new(0, 3, 0)
					DinosaurVFX.Cubes(at, 14, { Color3.fromRGB(160, 114, 63), Color3.fromRGB(255, 194, 31) }, 0.3, 12, 0.8)
					DinosaurVFX.BlockRing(CFrame.new(at - Vector3.new(0, 2.6, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 14, R0 = 1, R1 = 7, Color = Color3.fromRGB(255, 194, 31), Duration = 0.45 })
				end
				pcall(function() require(script.Parent.Audio).Play("Purchase", { Volume = 0.8 }) end)
			elseif res and res.Err then
				Kit.Toast(res.Err, "Orange", "Coin")
			end
		end)
	elseif action == "Treat" then
		setHolding(state.Holding ~= "Treat" and "Treat" or nil)
		local char = player.Character
		if char and entry.Barrel then PlayerAnim.Act(char, "Tap", { Target = entry.Barrel:GetPivot().Position + Vector3.new(0, 2.8, 0), Duration = 0.4 }) end
	elseif action == "Ball" then
		task.spawn(function()
			local res = Net.Ask("TakeBall")
			if res and res.Ok then setBalls(res.Balls) setHolding("Ball") end
		end)
		local char = player.Character
		if char and entry.Crate then PlayerAnim.Act(char, "Tap", { Target = entry.Crate:GetPivot().Position + Vector3.new(0, 2, 0), Duration = 0.4 }) end
	end
end

local function dinoPrompt(rec)
	if state.Holding == "Treat" then
		task.spawn(pet, rec, true)
	elseif state.Holding ~= "Ball" then
		task.spawn(pet, rec, false)
	end
end

local function stepPrompts()
	-- no petting / feeding prompts while you're driving or sat in a seat, at a nest site, or in a fight: they'd pop
	-- up on your companion as if you were aiming at it
	local hum = myHum()
	local touch = Kit.Platform() == "Touch"
	local busyElsewhere = Drive.State.Mode ~= "None" or (hum ~= nil and hum.SeatPart ~= nil) or player:GetAttribute("Site") ~= nil
	for _, pd in ipairs(CampView.Paddocks()) do
		local entry = placed[pd.Plot]
		if entry then
			-- (the props' prompts, collected once per set of props - not a descendant scan of all three every frame)
			local key = tostring(entry.Machine) .. tostring(entry.Barrel) .. tostring(entry.Crate)
			if entry.PromptKey ~= key then
				entry.PromptKey = key
				entry.PromptList = {}
				for _, m in ipairs({ entry.Machine, entry.Barrel, entry.Crate, entry.Yard }) do
					for _, pr in ipairs(m and m:GetDescendants() or {}) do
						if pr:IsA("ProximityPrompt") then table.insert(entry.PromptList, pr) end
					end
				end
			end
			local on = pd.Own == true and not busyElsewhere
			for _, pr in ipairs(entry.PromptList) do
				if pr.Enabled ~= on then pr.Enabled = on end
			end
			-- the yard kit's prompt shows what you've got and what the next space costs
			if pd.Own and entry.Yard then
				local prof = Net.Profile
				local slots = (prof and prof.PenSlots) or Config.Pen.Base
				local yp = entry.Yard:FindFirstChild("YardPrompt", true) :: ProximityPrompt?
				if yp then
					local txt = slots >= Config.Pen.Max and ("Yard " .. slots .. " / " .. slots .. " - full size")
						or ("Yard space " .. #((prof and prof.Placed) or {}) .. " / " .. slots .. "  -  " .. Config.FormatNumber(Config.PenPrice(slots)) .. " coins")
					if yp.ObjectText ~= txt then yp.ObjectText = txt end
					local act = slots >= Config.Pen.Max and "Maxed" or "Bigger yard"
					if yp.ActionText ~= act then yp.ActionText = act end
				end
			end
		end
		if not pd.Own then continue end
		for _, rec in pairs(pd.Dinos) do
			local root = rec.Root
			if not root.Parent or swimmer(rec) then continue end
			local pr = root:FindFirstChild("PetPrompt") :: ProximityPrompt?
			if not pr then
				local ext = rec.Model:GetExtentsSize()
				local p = Instance.new("ProximityPrompt")
				p.Name = "PetPrompt"
				p.ObjectText = string.upper(speciesName(rec.Species))
				p.KeyboardKeyCode = Enum.KeyCode.E
				p.GamepadKeyCode = Enum.KeyCode.ButtonX
				p.RequiresLineOfSight = false
				p.MaxActivationDistance = math.max(ext.X, ext.Z) * 0.55 + 6
				p.HoldDuration = 0
				p.Parent = root
				p.Triggered:Connect(function() dinoPrompt(rec) end)
				pr = p
			end
			local p = pr :: ProximityPrompt
			p.ActionText = state.Holding == "Treat" and "Feed" or "Pet"
			-- (touch: only while you're really looking at it - the dino near the middle of the screen. On a phone the
			-- prompt button sat under your thumb and tester players kept petting dinos by accident, 2026-10-13)
			local aimed = true
			if touch then
				local cam = Workspace.CurrentCamera
				local to = root.Position - cam.CFrame.Position
				local dist = to.Magnitude
				if dist > 0.1 then
					local ext = rec.Model:GetExtentsSize()
					local allow = math.atan(math.max(ext.X, ext.Z) * 0.35 / dist) + math.rad(7)
					aimed = cam.CFrame.LookVector:Dot(to.Unit) > math.cos(allow)
				end
			end
			p.Enabled = not state.Busy and state.Holding ~= "Ball" and not busyElsewhere and aimed
		end
	end
end

--------------------------------------------------------------------------------
-- the ball pocket: a little red ball button (with how many you've got) whenever there's one in your pocket - tap it
-- to take one out; no words, it's just there to find
--------------------------------------------------------------------------------
local pocket = {} :: any
local function buildPocket()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoBallPocket"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(62, 62)
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -24, 1, -320)
	b.BackgroundColor3 = Color3.fromRGB(232, 71, 58)
	b.Parent = gui
	local cr = Instance.new("UICorner") cr.CornerRadius = UDim.new(0.5, 0) cr.Parent = b
	local st = Instance.new("UIStroke") st.Thickness = 4 st.Color = Color3.fromRGB(26, 28, 32) st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border st.Parent = b
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, 0, 10)
	band.Position = UDim2.fromScale(0, 0.5)
	band.AnchorPoint = Vector2.new(0, 0.5)
	band.BackgroundColor3 = Color3.fromRGB(255, 194, 31)
	band.BorderSizePixel = 0
	band.Parent = b
	local shine = Instance.new("Frame")
	shine.Size = UDim2.fromOffset(14, 14)
	shine.Position = UDim2.fromOffset(12, 10)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.35
	shine.Parent = b
	local cr2 = Instance.new("UICorner") cr2.CornerRadius = UDim.new(0.5, 0) cr2.Parent = shine
	local count = Kit.Text(b, "", { Size = UDim2.fromOffset(34, 22), Position = UDim2.new(1, 6, 1, 4), AnchorPoint = Vector2.new(1, 1), Stroke = 3, MaxSize = 22 })
	b.Activated:Connect(function()
		if state.Holding == "Ball" then setHolding(nil) elseif ballsLeft() > 0 and not state.Busy then setHolding("Ball") end
	end)
	pocket.Gui, pocket.Button, pocket.Count, pocket.Stroke = gui, b, count, st
end
local function stepPocket()
	if not pocket.Gui then return end
	local n = ballsLeft()
	local cine = Workspace.CurrentCamera and Workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable
	pocket.Gui.Enabled = (n > 0 or state.Holding == "Ball") and not cine
	Kit.SetText(pocket.Count, n > 1 and ("x" .. n) or "")
	pocket.Stroke.Color = state.Holding == "Ball" and Color3.fromRGB(255, 240, 120) or Color3.fromRGB(26, 28, 32)
	pocket.Stroke.Thickness = state.Holding == "Ball" and 6 or 4
	-- ran out (thrown elsewhere): nothing left to hold
	if state.Holding == "Ball" and n <= 0 and not state.Busy then setHolding(nil) end
end

-- balls thrown at nest sites (the server's): arc in, lie there, ride in your companion's mouth, wait at your feet
local siteBalls = {} :: { [Instance]: any }
local function stepSiteBalls(dt: number)
	local folder = DinoShared:FindFirstChild("Runtime") and DinoShared.Runtime:FindFirstChild("Balls")
	local now = Workspace:GetServerTimeNow()
	for cfg, sb in pairs(siteBalls) do
		if not cfg.Parent then sb.Part:Destroy() siteBalls[cfg] = nil end
	end
	for _, cfg in ipairs(folder and folder:GetChildren() or {}) do
		local sb = siteBalls[cfg]
		if not sb then
			local t = Props:FindFirstChild("PlayBall")
			if not t then continue end
			local part = (t:Clone() :: Model).PrimaryPart :: BasePart
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.Parent = lf()
			sb = { Part = part, P = cfg:GetAttribute("From") or cfg:GetAttribute("P") }
			siteBalls[cfg] = sb
			if cfg:GetAttribute("Owner") == player.UserId then
				local pr = Instance.new("ProximityPrompt")
				pr.ActionText = "Grab Ball"
				pr.ObjectText = "Ball"
				pr.KeyboardKeyCode = Enum.KeyCode.E
				pr.MaxActivationDistance = 10
				pr.RequiresLineOfSight = false
				pr.Parent = part
				pr.Triggered:Connect(function()
					task.spawn(function()
						local res = Net.Ask("PickSiteBall", { Id = cfg:GetAttribute("Id") })
						if res and res.Ok then setBalls(res.Balls) setHolding("Ball") end
					end)
				end)
				sb.Prompt = pr
			end
		end
		local st = cfg:GetAttribute("State")
		local p
		if st == "Flying" then
			local from, to = cfg:GetAttribute("From") :: Vector3, cfg:GetAttribute("To") :: Vector3
			local T = cfg:GetAttribute("Flight") or 1
			local u = math.clamp((now - (cfg:GetAttribute("T0") or now)) / T, 0, 1)
			p = from:Lerp(to, u) + Vector3.new(0, math.sin(u * math.pi) * (4 + (to - from).Magnitude * 0.12), 0)
		else
			p = (cfg:GetAttribute("P") :: Vector3) + Vector3.new(0, st == "Carried" and 0 or 0.55, 0)
			p = sb.P:Lerp(p, math.min(1, dt * 12))
		end
		sb.P = p
		sb.Part.CFrame = CFrame.new(p) * CFrame.Angles(os.clock() * 3, 0, 0)
		if sb.Prompt then sb.Prompt.Enabled = st == "Ground" or st == "Dropped" end
	end
end

-- dinos held in someone's arms (hotbar / bag): alive in your arms (looks about, now and then a snuggle), and its
-- copy in the pen steps out of sight while it's being carried
local heldAnims: any = setmetatable({}, { __mode = "k" })
local function stepHeldDinos()
	local heldIds = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local id = plr:GetAttribute("HeldDino")
		if typeof(id) == "string" then heldIds[id] = true end
		local m = plr.Character and plr.Character:FindFirstChild("HeldEggModel") :: Model?
		if m and m:GetAttribute("HeldDino") then
			local h = heldAnims[m]
			if not h then
				local anim = DinosaurAnimations.get(m)
				h = { Anim = anim, Next = os.clock() + 1.5 }
				heldAnims[m] = h
				if anim then anim:SetLocomotion("Idle", 0.2) end
			end
			if h.Anim and os.clock() > h.Next then
				h.Next = os.clock() + 3 + math.random() * 4
				local snuggle = math.random() < 0.35
				h.Anim.EyesClosed = snuggle
				if not snuggle and h.Anim:HasAction("LookAround") then h.Anim:Play("LookAround") end
			end
		end
	end
	for _, pd in ipairs(CampView.Paddocks()) do
		for id, rec in pairs(pd.Dinos) do
			if heldIds[id] then
				if rec.Model.Parent then rec.HiddenFrom = rec.Model.Parent rec.Model.Parent = nil end
			elseif rec.HiddenFrom and not rec.Model.Parent then
				rec.Model.Parent = rec.HiddenFrom
				rec.HiddenFrom = nil
			end
		end
	end
end

function PaddockLife.Start()
	task.spawn(buildPocket)
	lf()
	-- throwing: click (not on UI), R2, or the touch THROW button - only while you hold a ball
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or state.Holding ~= "Ball" then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then throw() end
	end)
	local bound = false
	local filtersAt = 0
	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		-- (the ray filters only change when characters / vehicles come and go: a few times a second is plenty)
		if os.clock() >= filtersAt then
			filtersAt = os.clock() + 0.25
			refreshRay()
			refreshObstacles()
		end
		for _, pd in ipairs(CampView.Paddocks()) do bindPaddock(pd) end
		stepPrompts()
		stepCompanions(dt)
		stepReturning(dt)
		stepFetch(dt)
		stepPocket()
		stepSiteBalls(dt)
		stepHeldDinos()
		-- whatever's in your hand
		if state.HeldModel then
			local cf = handCF()
			if cf then state.HeldModel:PivotTo(cf) end
		end
		-- the throw: a ring where the ball will land, and the THROW button / R2 while you hold it
		local aiming = state.Holding == "Ball" and not state.Busy and not state.Fetch
		if aiming ~= bound then
			bound = aiming
			if aiming then
				ContextActionService:BindAction("PaddockThrow", function(_, inputState)
					if inputState == Enum.UserInputState.Begin then throw() end
					return Enum.ContextActionResult.Sink
				end, true, Enum.KeyCode.ButtonR2)
				ContextActionService:SetTitle("PaddockThrow", "THROW")
			else
				ContextActionService:UnbindAction("PaddockThrow")
			end
		end
		if aiming then
			if not state.Reticle then
				local r = Instance.new("Part")
				r.Name = "ThrowRing"
				r.Shape = Enum.PartType.Cylinder
				r.Size = Vector3.new(0.12, 3, 3)
				r.Material = Enum.Material.Neon
				r.Color = Color3.fromRGB(255, 194, 31)
				r.Transparency = 0.35
				r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch = true, false, false, false
				r.Parent = lf()
				state.Reticle = r
			end
			local p = aimPoint()
			if p and state.Reticle then
				local s = 2.6 + math.sin(os.clock() * 5) * 0.3
				state.Reticle.Size = Vector3.new(0.12, s, s)
				state.Reticle.CFrame = CFrame.new(p + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			end
		elseif state.Reticle then
			state.Reticle:Destroy()
			state.Reticle = nil
		end
	end)
end

return PaddockLife
