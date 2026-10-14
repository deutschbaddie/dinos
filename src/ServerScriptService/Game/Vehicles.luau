--[[
	Vehicles — spawns a player's equipped vehicle, seats them, and hands physics to their client.

	Every vehicle is one welded assembly with two rigid constraints on its root (AlignPosition +
	AlignOrientation in one-attachment mode). The owning client moves their targets each frame
	(free driving in camp, road-guided on expeditions); network ownership replicates it to everyone.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local Rides = require(ReplicatedStorage.DinoExpedition.Game.Rides)
local Templates = ReplicatedStorage.DinoExpedition:WaitForChild("Vehicles")

local Vehicles = {}
local active = {} :: { [Player]: Model }
local seatConn = {} :: { [Player]: RBXScriptConnection }
local Data, Net
Vehicles.Locked = {} :: { [Player]: boolean } -- true while on an expedition (no getting out)
Vehicles.Parked = {} :: { [Player]: boolean } -- true while the driver is out on foot during a raid

-- vehicles are driven kinematically by their owner's client (terrain-following raycasts + bumpers), so their
-- physics never touches the world: no snagging on humps, curbs or fence posts. The seated driver joins the group.
local Shore = require(script.Parent.Shore)
local Carpool = require(script.Parent.Carpool) -- (passengers: out when the driver is) -- (out of the seat you're a walker again: the shore walls stop you)
local GROUP = "DinoVehicles"
pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP)
	PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end)
local function setGroup(model: Instance?, group: string)
	if not model then return end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.CollisionGroup = group end
	end
end

-- let a held (anchored) rover go, smoothly: the server's copy of its drive targets is wherever the server last put it
-- (the gate, the last teleport) - the client's own targets never replicate - so for the moment the server simulated
-- it after unanchoring it was yanked toward that old spot, then snapped back once the driver owned it again (the jolt
-- getting back in after a site / free-roam stop). Targets to where it stands, and the driver owns it at once.
-- 2026-10-14
local function release(player: Player, root: BasePart)
	local ap = root:FindFirstChild("DrivePosition") :: AlignPosition?
	local ao = root:FindFirstChild("DriveOrientation") :: AlignOrientation?
	if ap then ap.Position = root.Position end
	if ao then ao.CFrame = root.CFrame.Rotation end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = false
	pcall(function() root:SetNetworkOwner(player) end)
	task.delay(0.1, function() if root.Parent and not root.Anchored then pcall(function() root:SetNetworkOwner(player) end) end end)
end

-- set a held (anchored) rover's wheels down exactly on what's under them. Wherever it's held, the height came from
-- somewhere that can be a little off: the driver's copy mid-bob, a stale ride height on their client, the solver's sag
-- under a seated driver - and anchored, it stayed there, tyres sunk into the road (2026-10-14, user: "it goes into the
-- floor a little"). Every wheel's tread bottom is RootHeight under the root (the templates' tyres touch y = 0; a lift
-- moves the root up with them), so: probe the ground under each wheel and lift / drop it so the highest one touches.
-- Never more than 1.5 studs either way (more than that, the probe found a bridge over it or a hole: leave it be).
local settleRay = RaycastParams.new()
settleRay.FilterType = Enum.RaycastFilterType.Exclude
settleRay.RespectCanCollide = true
settleRay.IgnoreWater = false
local function settleWheels(v: Model)
	local root = v.PrimaryPart
	if not (root and root.Anchored) then return end
	local rh = v:GetAttribute("RootHeight") or 2.6
	local skip = { v :: Instance }
	local af = Workspace:FindFirstChild("ActiveVehicles")
	if af then table.insert(skip, af) end
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(skip, p.Character) end end
	settleRay.FilterDescendantsInstances = skip
	local lift, n = -math.huge, 0
	for _, m in ipairs(root:GetChildren()) do
		if m:IsA("Motor6D") and m.Name:match("^Wheel") then
			local c0 = (m :: Motor6D).C0.Position
			local foot = (root.CFrame * CFrame.new(c0.X, -rh, c0.Z)).Position
			local hit = Workspace:Raycast(foot + Vector3.new(0, 3, 0), Vector3.new(0, -7, 0), settleRay)
			if hit then
				n += 1
				lift = math.max(lift, hit.Position.Y - foot.Y)
			end
		end
	end
	if n < 3 or math.abs(lift) < 0.02 or math.abs(lift) > 1.5 then return end
	v:PivotTo(v:GetPivot() + Vector3.new(0, lift, 0))
	local ap = root:FindFirstChild("DrivePosition") :: AlignPosition?
	if ap then ap.Position = root.Position end
end
Vehicles.Settle = settleWheels

-- hold a rover the driver was just driving: the moment you're out your own client stops it dead, but the server's
-- copy is a beat behind (replication) - anchoring at once froze it there and the rover jumped back a few studs on your
-- screen. Held now; anchored once the server has caught up. Getting back in (Held cleared) cancels it. 2026-10-14
local function holdSoon(player: Player, v: Model)
	v:SetAttribute("Held", true)
	task.delay(0.3, function()
		local root = v.PrimaryPart
		if not (root and v.Parent and v:GetAttribute("Held") and active[player] == v) then return end
		local seatPart = v:FindFirstChild("DriverSeat", true) :: VehicleSeat?
		local occ = seatPart and seatPart.Occupant
		if occ and occ.Parent == player.Character then return end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
		settleWheels(v)
	end)
end

local function folder(): Folder
	local f = Workspace:FindFirstChild("ActiveVehicles")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ActiveVehicles"
		f.Parent = Workspace
	end
	return f :: Folder
end

function Vehicles.Get(player: Player): Model?
	local v = active[player]
	if v and v.Parent then return v end
	return nil
end

function Vehicles.Root(player: Player): BasePart?
	local v = Vehicles.Get(player)
	return v and v.PrimaryPart
end

-- keepRack: the eggs stay strapped on (Spawn swapping you into a fresh rover carries the rack over to it)
function Vehicles.Despawn(player: Player, keepRack: boolean?)
	if seatConn[player] then seatConn[player]:Disconnect() seatConn[player] = nil end
	local v = active[player]
	active[player] = nil
	Vehicles.Locked[player] = nil
	Vehicles.Parked[player] = nil
	Vehicles.CampParked[player] = nil
	setGroup(player.Character, Shore.WALKERS)
	if v then
		Carpool.EjectAll(v)
		Net.FireAll("VehiclePoof", { Position = v:GetPivot().Position })
		v:Destroy()
	end
	player:SetAttribute("Vehicle", nil)
	if not keepRack then Vehicles.RackToBag(player) end
end

-- (2026-10-13) hopping out at camp PARKS the rover instead of making it vanish: it waits where you left it with its
-- eggs still on the rack (tap one to carry it to a nest), you hop back in with its DRIVE prompt, and it goes home on
-- its own if you wander off (Vehicles.Start's cleanup), call another one, or set off through the gate on foot.
Vehicles.CampParked = {} :: { [Player]: number } -- os.clock() when you got out
local PARK_AWAY, PARK_FAR = 120, 220 -- seconds out of range before it goes home / how far "out of range" is
local function parkPrompt(v: Model, on: boolean)
	local seatPart = v:FindFirstChild("DriverSeat", true) :: BasePart?
	if not seatPart then return end
	local pr = seatPart:FindFirstChild("ParkedDrive") :: ProximityPrompt?
	if not on then if pr then pr:Destroy() end return end
	if pr then return end
	pr = Instance.new("ProximityPrompt")
	pr.Name = "ParkedDrive"
	pr.ActionText = "Drive"
	pr.ObjectText = "Your rover"
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.GamepadKeyCode = Enum.KeyCode.ButtonX
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr:SetAttribute("OwnerOnly", v:GetAttribute("Owner")) -- (only its owner sees it: client Prompt.luau)
	pr.Parent = seatPart
	pr.Triggered:Connect(function(who)
		if who.UserId == v:GetAttribute("Owner") and active[who] == v then Vehicles.GetIn(who) end
	end)
end
function Vehicles.Park(player: Player): boolean
	local v = active[player]
	if not (v and v.Parent and v.PrimaryPart) then return false end
	if Vehicles.CampParked[player] then return true end
	Vehicles.CampParked[player] = os.clock()
	Carpool.EjectAll(v) -- (the driver's out: so is everyone)
	local seatPart = v:FindFirstChild("DriverSeat", true) :: VehicleSeat?
	local hum = seatPart and seatPart.Occupant
	if seatPart and hum then
		local weld = seatPart:FindFirstChild("SeatWeld")
		if weld then weld:Destroy() end
		hum.Sit = false
	end
	local root = v.PrimaryPart :: BasePart
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true -- (nobody's driving it: it mustn't roll off or sink while it waits)
	settleWheels(v)
	v:SetAttribute("Parked", true)
	parkPrompt(v, true)
	task.defer(setGroup, player.Character, Shore.WALKERS)
	return true
end
local function unpark(player: Player, v: Model)
	if not Vehicles.CampParked[player] then return end
	Vehicles.CampParked[player] = nil
	v:SetAttribute("Parked", nil)
	parkPrompt(v, false)
	local root = v.PrimaryPart
	if root then release(player, root) end
end

-- hopping out at camp despawns the rover, so whatever's strapped to the rack comes with you into your bag
function Vehicles.RackToBag(player: Player)
	local profile = Data.Peek(player)
	if not profile or #(profile.RoverEggs or {}) == 0 then return end
	local res = (require :: any)(script.Parent.Dinos).UnloadAll(player) -- lazy: Dinos requires Vehicles too
	if res and res.Ok and player.Parent then Net.Fire(player, "EggsToBag", { Count = res.Count }) end
end

local function seat(player: Player, v: Model)
	local seatPart = v:FindFirstChild("DriverSeat", true) :: VehicleSeat?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (seatPart and hum and hum.Health > 0) then return false end
	if seatPart.Occupant == hum then return true end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then char:PivotTo(seatPart.CFrame * CFrame.new(0, 2, 0)) end
	seatPart:Sit(hum)
	return true
end

-- rootCF: where VehicleRoot should be; nil = the player's garage
-- the eggs strapped to the roof rack between an expedition and unloading at home (clients draw them)
function Vehicles.ShowRack(player: Player)
	local v = Vehicles.Get(player)
	local profile = Data.Peek(player)
	if not (v and profile) then return end
	local ok, json = pcall(function() return game:GetService("HttpService"):JSONEncode(profile.RoverEggs or {}) end)
	v:SetAttribute("RackEggs", ok and json or "[]")
end

function Vehicles.Spawn(player: Player, rootCF: CFrame?, name: string?)
	local profile = Data.Peek(player)
	if not profile then return nil end
	name = name or profile.Gear.Vehicle
	if not profile.Gear.Vehicles[name] then name = "RookieRanger" end
	Vehicles.Despawn(player, true) -- (a fresh rover takes over the old one's rack)
	local template = Templates:FindFirstChild(name)
	if not template then warn("[Vehicles] missing template", name) return nil end
	local v = template:Clone() :: Model
	v.Name = player.Name .. "_" .. name
	v:SetAttribute("Owner", player.UserId)
	v:SetAttribute("VehicleName", name)
	-- your build: paint, kits, wheels, wraps, glow (fitted while the clone is still in template space)
	local okStyle, styleErr = pcall(Rides.Apply, v, name, Rides.StyleFor(profile, name))
	if not okStyle then warn("[Vehicles] styling failed:", styleErr) end
	local root = v.PrimaryPart :: BasePart
	local rh = v:GetAttribute("RootHeight") or 2.6
	if not rootCF then
		local Plots = require(script.Parent.Plots)
		local plot = Plots.Get(player)
		local spawnMarker = plot and plot:FindFirstChild("VehicleSpawn", true) :: BasePart?
		if spawnMarker then
			local floorY = spawnMarker.Position.Y - 0.05 -- garage floor top
			rootCF = CFrame.new(spawnMarker.Position.X, floorY + rh, spawnMarker.Position.Z) * spawnMarker.CFrame.Rotation
		else
			rootCF = CFrame.new(600, 5, 30)
		end
	end
	v:PivotTo(rootCF * root.CFrame:ToObjectSpace(v:GetPivot()))
	-- rigid drive constraints, targets driven by the owner's client
	local att = Instance.new("Attachment")
	att.Name = "DriveAttachment"
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Name = "DrivePosition"
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.RigidityEnabled = true
	ap.MaxForce = math.huge
	ap.MaxVelocity = math.huge
	ap.Responsiveness = 200
	ap.Position = rootCF.Position
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Name = "DriveOrientation"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.MaxTorque = math.huge
	ao.MaxAngularVelocity = math.huge
	ao.Responsiveness = 200
	ao.CFrame = rootCF.Rotation
	ao.Parent = root
	v.Parent = folder()
	task.defer(Vehicles.ShowRack, player)
	for _, p in ipairs(v:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = false p.CollisionGroup = GROUP end
	end
	local ok = pcall(function() root:SetNetworkOwner(player) end)
	if not ok then warn("[Vehicles] could not set network owner") end
	active[player] = v
	player:SetAttribute("Vehicle", name)
	-- seat the driver; in camp, getting out parks (removes) the vehicle
	task.defer(function()
		for _ = 1, 10 do
			if seat(player, v) then break end
			task.wait(0.2)
		end
		-- seating welds the character into the assembly: hand the whole thing to the driver again
		task.wait(0.1)
		if v.Parent and v.PrimaryPart then pcall(function() (v.PrimaryPart :: BasePart):SetNetworkOwner(player) end) end
		local seatPart = v:FindFirstChild("DriverSeat", true) :: VehicleSeat?
		if not seatPart then return end
		if seatPart.Occupant then setGroup(seatPart.Occupant.Parent, GROUP) end
		seatConn[player] = seatPart:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seatPart.Occupant then
				setGroup(seatPart.Occupant.Parent, GROUP)
				-- (whoever sits it back down: never leave a driven rover anchored / marked parked)
				if seatPart.Occupant.Parent == player.Character then
					unpark(player, v)
					-- (a site / arena get-out holds it anchored: any way back into the seat lets it go, not just GetIn)
					if v:GetAttribute("Held") then
						v:SetAttribute("Held", nil)
						local root = v.PrimaryPart
						if root then release(player, root) end
					end
				end
				return
			end
			setGroup(player.Character, Shore.WALKERS)
			-- FREE ROAM (2026-10-13): hopping out anywhere in an era parks it right there, held, until you get back in
			if Vehicles.Roaming and Vehicles.Roaming(player) then
				Vehicles.Parked[player] = true
				if v.PrimaryPart and active[player] == v and not v:GetAttribute("Held") then holdSoon(player, v) end
				return
			end
			if Vehicles.Parked[player] then return end -- out on foot (a nest raid): the jeep waits
			if Vehicles.Locked[player] then
				task.wait(0.1)
				if active[player] == v then seat(player, v) end
			else
				-- (not during the garage roll-out: the cutscene can drop you out of the seat for a moment, and parking
				-- anchored the rover mid-drive - it sank into the driveway once physics took it back. 2026-10-14)
				task.wait(0.8)
				if active[player] == v and not seatPart.Occupant and not v:GetAttribute("RollOut") then Vehicles.Park(player) end
			end
		end)
	end)
	return v
end

-- the garage roll-out: spawn inside the bay, open the roll-up door, seat the driver; the client plays
-- the cutscene and drives the vehicle out before handing over control
local doorTokens = {}
-- returns the vehicle and how it arrived: "Garage" (at your own base: the roll-out cutscene) or "Here" (anywhere
-- else in camp: it appears right where you stand and the client plays the transform)
function Vehicles.TakeVehicle(player: Player, name: string?): (Model?, string?)
	local profile = Data.Peek(player)
	if not profile then return nil end
	if name and not profile.Gear.Vehicles[name] then return nil end
	-- your rover's parked close by (the same body): DRIVE just gets you back in it, no second roll-out
	do
		local pv = active[player]
		local hrp0 = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Vehicles.CampParked[player] and pv and pv.PrimaryPart and hrp0 and (not name or pv:GetAttribute("VehicleName") == name)
			and (hrp0.Position - pv.PrimaryPart.Position).Magnitude < 60 then
			if Vehicles.GetIn(player) then return pv, "Parked" end
		end
	end
	if name and profile.Gear.Vehicle ~= name then profile.Gear.Vehicle = name Data.Changed(player) end
	local Plots = require(script.Parent.Plots)
	local plot = Plots.Get(player)
	-- at your base? (anywhere inside your plot's footprint: yard, garage, paddock)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local atBase = true
	if hrp and plot then
		-- (islands: the PlotCenter marker is the island's own box; the model's bounding box is axis-aligned round a
		-- rotated wedge and reached over the bridge and onto the next island)
		local box = plot:FindFirstChild("PlotCenter", true) :: BasePart?
		local cf, size
		if box then cf, size = box.CFrame, box.Size else cf, size = plot:GetBoundingBox() end
		local lp = cf:PointToObjectSpace(hrp.Position)
		atBase = math.abs(lp.X) < size.X / 2 + 4 and math.abs(lp.Z) < size.Z / 2 + 4
	end
	-- away from your island it appears right where you're standing (2026-10-14, user: "spawn my car exactly where i
	-- am"). Facing your way if it fits; turned to fit if not (across a bridge: along it); only with no room at all
	-- there does it shift, by the smallest step that fits. The garage is for your island - or a swim in the lagoon
	local here: CFrame? = nil
	local tmpl = Templates:FindFirstChild(name or profile.Gear.Vehicle)
	local rh0 = tmpl and tmpl:GetAttribute("RootHeight") or 2.6
	if hrp and not atBase then
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { char :: Instance, folder() }
		rp.RespectCanCollide = true -- trigger volumes and prompt hosts aren't ground
		rp.IgnoreWater = false
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = { char :: Instance, folder() }
		op.RespectCanCollide = true
		local w, l = (tmpl and tmpl:GetAttribute("Width")) or 8, (tmpl and tmpl:GetAttribute("Length")) or 16
		local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
		local side = Vector3.new(-look.Z, 0, look.X)
		local hit0 = Workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), rp)
		local ground0 = hit0 and hit0.Position.Y or (hrp.Position.Y - 3)
		local swimming = hit0 ~= nil and hit0.Material == Enum.Material.Water
		-- a rover-sized box of room on dry ground at p, facing dir
		local function fits(p: Vector3, dir: Vector3): CFrame?
			local hit = Workspace:Raycast(p + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), rp)
			if not hit or hit.Material == Enum.Material.Water or hit.Normal.Y < 0.75 then return nil end
			if math.abs(hit.Position.Y - ground0) > 3 then return nil end
			local pos = Vector3.new(p.X, hit.Position.Y + rh0, p.Z)
			local cf = CFrame.lookAt(pos, pos + dir)
			if #Workspace:GetPartBoundsInBox(cf + Vector3.new(0, 2, 0), Vector3.new(w * 0.9, 3.5, l * 0.9), op) > 0 then return nil end
			return cf
		end
		if not swimming then
			local dirs = { look, side, -side, -look }
			for _, r in ipairs({ 0, 2, 4, 6, 9, 12 }) do
				for k = 0, (r == 0 and 0 or 7) do
					local a = k / 8 * math.pi * 2
					local off = (look * math.cos(a) + side * math.sin(a)) * r
					for _, dir in ipairs(dirs) do
						here = fits(hrp.Position + off, dir)
						if here then break end
					end
					if here then break end
				end
				if here then break end
			end
		end
	end
	if here then
		local v = Vehicles.Spawn(player, here, name)
		if not v then return nil end
		-- a lifted / monster build raises its RootHeight while it's styled: lift it to match
		local rh1 = v:GetAttribute("RootHeight") or rh0
		if math.abs(rh1 - rh0) > 0.01 then Vehicles.Teleport(player, here + Vector3.new(0, rh1 - rh0, 0)) end
		v:SetAttribute("RollOut", true)
		task.delay(6, function() if v.Parent then v:SetAttribute("RollOut", nil) end end)
		return v, "Here"
	end
	local v = Vehicles.Spawn(player, nil, name)
	if not v then return nil end
	v:SetAttribute("RollOut", true)
	local garage = plot and plot:FindFirstChild("Garage", true)
	if garage then
		garage:SetAttribute("DoorOpen", true)
		local token = {}
		doorTokens[garage] = token
		-- the door stays up until the rover is really out of the bay (or gone), never on a timer
		local pivot = garage:FindFirstChild("GarageDoorPivot", true) :: BasePart?
		task.spawn(function()
			local t0 = os.clock()
			task.wait(3)
			while doorTokens[garage] == token and os.clock() - t0 < 120 do
				local root = v.Parent and v.PrimaryPart
				if not root then break end
				if pivot then
					local lp = pivot.CFrame:PointToObjectSpace(root.Position)
					-- out of the bay AND well clear of the door (2026-10-12: it shut ~0.7 s after the roll-out cutscene handed
					-- the camera over, still inside the bay - the slats came down between the lens and the rover)
					if lp.Z < -10 and (root.Position - pivot.Position).Magnitude > 30 then break end
				end
				task.wait(0.5)
			end
			task.wait(1.5)
			if doorTokens[garage] == token then garage:SetAttribute("DoorOpen", false) end
		end)
	end
	task.delay(6, function() if v.Parent then v:SetAttribute("RollOut", nil) end end)
	return v, "Garage"
end

-- server-side teleport (used as a safety net when a client never moved its own vehicle)
function Vehicles.Teleport(player: Player, rootCF: CFrame)
	local v = Vehicles.Get(player)
	if not v then return end
	local root = v.PrimaryPart :: BasePart
	pcall(function() root:SetNetworkOwner(nil) end)
	v:PivotTo(rootCF * root.CFrame:ToObjectSpace(v:GetPivot()))
	local ap = root:FindFirstChild("DrivePosition") :: AlignPosition?
	local ao = root:FindFirstChild("DriveOrientation") :: AlignOrientation?
	if ap then ap.Position = rootCF.Position end
	if ao then ao.CFrame = rootCF.Rotation end
	task.delay(0.2, function()
		if root.Parent then pcall(function() root:SetNetworkOwner(player) end) end
	end)
end

-- make sure the driver's client really simulates their vehicle (unanchored, not welded to the world, owned)
function Vehicles.Claim(player: Player)
	local v = Vehicles.Get(player)
	if not v or not v.PrimaryPart then return { Ok = false, Err = "no vehicle" } end
	local root = v.PrimaryPart :: BasePart
	local anchored, foreign = 0, 0
	if root.Anchored then
		local ap = root:FindFirstChild("DrivePosition") :: AlignPosition?
		local ao = root:FindFirstChild("DriveOrientation") :: AlignOrientation?
		if ap then ap.Position = root.Position end
		if ao then ao.CFrame = root.CFrame.Rotation end
	end
	for _, p in ipairs(v:GetDescendants()) do
		if p:IsA("BasePart") and p.Anchored then anchored += 1 p.Anchored = false end
		if p:IsA("JointInstance") or p:IsA("WeldConstraint") then
			local a, b = (p :: any).Part0, (p :: any).Part1
			local char = player.Character
			for _, q in ipairs({ a, b }) do
				if q and not q:IsDescendantOf(v) and not (char and q:IsDescendantOf(char)) then foreign += 1 p:Destroy() break end
			end
		end
	end
	unpark(player, v) -- (a claim means you're driving it)
	v:SetAttribute("Held", nil)
	local seatPart = v:FindFirstChild("DriverSeat", true) :: VehicleSeat?
	if seatPart and not seatPart.Occupant then seat(player, v) end
	local ok, err = pcall(function() root:SetNetworkOwner(player) end)
	local owner = nil
	pcall(function() owner = root:GetNetworkOwner() end)
	local report = string.format("anchored=%d foreignJoints=%d setOwner=%s owner=%s auto=%s", anchored, foreign, tostring(ok and "ok" or err), tostring(owner), tostring(root:GetNetworkOwnershipAuto()))
	warn("[Vehicles] claim for", player.Name, report)
	return { Ok = ok, Report = report }
end

-- step out beside the vehicle (raids): the vehicle stays where it is, the character lands on the given side
-- hold: it stays exactly where you got out until you get back in (sites, the boss arena). 2026-10-13: an empty
-- rover was left unanchored under its driver's physics and drifted / got dragged off while you fought on foot
-- settle: it was being driven freely right up to now (free roam) - hold it once the server has caught up (holdSoon)
function Vehicles.GetOut(player: Player, toward: Vector3?, hold: boolean?, settle: boolean?): boolean
	local v = Vehicles.Get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seatPart = v and v:FindFirstChild("DriverSeat", true) :: VehicleSeat?
	if not (v and char and hum and seatPart and v.PrimaryPart) then return false end
	Vehicles.Parked[player] = true
	-- (only a driver really in the seat is moved out beside it: someone already on foot - walked off from a flipped
	-- rover, or into a nest - was pulled back to the rover's side. 2026-10-14)
	local inSeat = seatPart.Occupant == hum or hum.SeatPart == seatPart
	local weld = seatPart:FindFirstChild("SeatWeld")
	if weld then weld:Destroy() end
	if inSeat then hum.Sit = false end
	local root = v.PrimaryPart :: BasePart
	if hold and settle and inSeat then
		holdSoon(player, v)
	elseif hold then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
		v:SetAttribute("Held", true)
		settleWheels(v)
	end
	if not inSeat then return true end
	local right = root.CFrame.RightVector
	local side = 1
	if toward and (toward - root.Position):Dot(right) < 0 then side = -1 end
	local w = (v:GetAttribute("Width") or 7) / 2 + 3
	local p = root.Position + right * side * w
	local look = toward and Vector3.new(toward.X, p.Y, toward.Z) or (p + right * side)
	if (look - p).Magnitude < 0.1 then look = p + right * side end
	task.defer(function()
		setGroup(char, Shore.WALKERS)
		char:PivotTo(CFrame.lookAt(p, look))
	end)
	return true
end

-- move your parked rover to rootCF and hold it there (free roam: it pulls up by the fight you walked into; the travel's
-- park spot made exact). Only an empty rover: never with you or a passenger sitting in it. Server-side and anchored,
-- so every client sees the same spot and nobody's physics drags it back; getting in lets it go as usual (release:
-- the drive targets come from where it stands - no jolt). 2026-10-14
function Vehicles.HoldAt(player: Player, rootCF: CFrame): boolean
	local v = Vehicles.Get(player)
	local root = v and v.PrimaryPart
	if not (v and root) then return false end
	for _, d in ipairs(v:GetDescendants()) do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			if (d :: any).Occupant then return false end
		end
	end
	Vehicles.Parked[player] = true
	v:SetAttribute("Held", true)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	v:PivotTo(rootCF * root.CFrame:ToObjectSpace(v:GetPivot()))
	local ap = root:FindFirstChild("DrivePosition") :: AlignPosition?
	local ao = root:FindFirstChild("DriveOrientation") :: AlignOrientation?
	if ap then ap.Position = rootCF.Position end
	if ao then ao.CFrame = rootCF.Rotation end
	settleWheels(v)
	return true
end

function Vehicles.GetIn(player: Player): boolean
	local v = Vehicles.Get(player)
	if not v then return false end
	Vehicles.Parked[player] = nil
	unpark(player, v)
	if v:GetAttribute("Held") then
		v:SetAttribute("Held", nil)
		local root = v.PrimaryPart
		if root then release(player, root) end
	end
	return seat(player, v)
end

function Vehicles.Reseat(player: Player)
	local v = Vehicles.Get(player)
	if v then seat(player, v) end
end

function Vehicles.Stats(player: Player)
	local v = Vehicles.Get(player)
	local name = v and v:GetAttribute("VehicleName") or "RookieRanger"
	return Rides.Stats(name, Rides.StyleFor(Data.Peek(player), name)), name
end

function Vehicles.Start(deps)
	Data, Net = deps.Data, deps.Net
	Players.PlayerRemoving:Connect(function(p) Vehicles.Despawn(p) end)
	-- a parked rover goes home once you've been out of range a while (into your garage: its rack into your bag)
	task.spawn(function()
		local away = {} :: { [Player]: number }
		while true do
			task.wait(5)
			for player, at in pairs(Vehicles.CampParked) do
				local v = active[player]
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not (v and v.PrimaryPart) then Vehicles.CampParked[player] = nil continue end
				local far = not hrp or (hrp.Position - v.PrimaryPart.Position).Magnitude > PARK_FAR
				if far then
					away[player] = away[player] or os.clock()
					if os.clock() - away[player] >= PARK_AWAY and os.clock() - at >= PARK_AWAY then
						away[player] = nil
						Vehicles.Despawn(player)
						Net.Fire(player, "Toast", { Text = "YOUR ROVER DROVE ITSELF HOME", Color = "Blue" })
					end
				else
					away[player] = nil
				end
			end
			for player in pairs(away) do if not Vehicles.CampParked[player] then away[player] = nil end end
		end
	end)
	-- eggs left on a rack from an older session (no rover out yet): straight into the bag once the profile loads
	Players.PlayerAdded:Connect(function(player)
		for _ = 1, 20 do
			task.wait(1)
			if not player.Parent then return end
			if Data.Peek(player) then
				if not active[player] then Vehicles.RackToBag(player) end
				return
			end
		end
	end)
end

return Vehicles
