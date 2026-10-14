--[[
	Crew — your buddies riding along in your rover on an expedition (every client draws everyone's).

	The server lists a run's crew on the player ("Crew" attribute: Id, Species, Rarity, KG, Fallen). Your companion
	(the lead buddy) rides shotgun in the passenger seat; any others sit in the back behind the seats. They hop out
	at a site (the server walks them out of the rover) and the riding copies hide while they're on foot. One that's
	been knocked out for the run lies in the back with its eyes shut.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurAnimations = require(DinoShared:WaitForChild("DinosaurAnimations"))
local Templates = DinoShared:WaitForChild("Dinosaurs")
local Chasers = DinoShared:WaitForChild("Runtime"):WaitForChild("Chasers")

local Crew = {}
local riders = {} :: { [Player]: { [string]: any } }
local MAX_H, MAX_L = 3.0, 3.8 -- (old: every rider shrunk to fit the cab)
-- (2026-10-13) riders by real size: a SMALL one rides shotgun as it is, a MEDIUM one in the back (shrunk only if it
-- wouldn't fit the bed), a BIG one runs alongside the rover at full size instead of being squashed into a seat
local SMALL_H, SMALL_L = 4.6, 7
local MEDIUM_H, MEDIUM_L = 9, 15
local BED_H, BED_L = 4.6, 6.5
local BIG_CAP = 14 -- a really huge one is capped to this height so it doesn't swallow the screen
Crew.SizeClass = function(species: string): string
	local t = Templates:FindFirstChild(species)
	if not t then return "Medium" end
	local _, size = (t :: Model):GetBoundingBox()
	local l = math.max(size.X, size.Z)
	if size.Y <= SMALL_H and l <= SMALL_L then return "Small" end
	if size.Y <= MEDIUM_H and l <= MEDIUM_L then return "Medium" end
	return "Big"
end
local _ = MAX_H + MAX_L

local folder: Folder
local function lf(): Folder
	if folder and folder.Parent then return folder end
	folder = Instance.new("Folder")
	folder.Name = "DinoCrewRiders"
	folder.Parent = Workspace
	return folder
end

-- (decoded once per change of the string: this is asked per player per frame)
local decoded = {} :: { [string]: { any } }
local EMPTY = {}
local function decode(s: any): { any }
	if typeof(s) ~= "string" or s == "" then return EMPTY end
	local hit = decoded[s]
	if hit then return hit end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, s)
	local out = (ok and typeof(v) == "table") and v or EMPTY
	if next(decoded) and math.random() < 0.02 then table.clear(decoded) end -- (keep the cache small)
	decoded[s] = out
	return out
end

-- a rover's passenger seat, found once per rover model (a recursive search over a custom rover each frame)
local seatOf = setmetatable({}, { __mode = "k" }) :: { [Model]: BasePart | false }
local function passengerSeat(v: Model): BasePart?
	local hit = seatOf[v]
	if hit == nil or (hit and not hit:IsDescendantOf(v)) then
		hit = (v:FindFirstChild("PassengerSeat", true) :: BasePart?) or false
		seatOf[v] = hit
	end
	return hit or nil
end

local function vehicleOf(plr: Player): Model?
	local f = Workspace:FindFirstChild("ActiveVehicles")
	for _, v in ipairs(f and f:GetChildren() or {}) do
		if v:IsA("Model") and v:GetAttribute("Owner") == plr.UserId then return v end
	end
	return nil
end

-- the rover a player rides in when it isn't their own (a friend's, as a rider)
local function ridingIn(plr: Player): Model?
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local f = Workspace:FindFirstChild("ActiveVehicles")
	if not (seat and f) then return nil end
	local v: Instance? = seat
	while v and v.Parent ~= f do v = v.Parent end
	return (v and v:IsA("Model")) and v or nil
end

-- a friend aboard (anyone seated who isn't the owner): then the companions run behind instead of riding
-- (2026-10-14, user: "when a friend gets in the car it should follow behind")
local seatsOf = setmetatable({}, { __mode = "k" }) :: { [Model]: { Seat | VehicleSeat } }
local function hasGuest(v: Model): boolean
	local seats = seatsOf[v]
	if not seats then
		seats = {}
		for _, d in ipairs(v:GetDescendants()) do
			if d:IsA("Seat") or d:IsA("VehicleSeat") then table.insert(seats, d) end
		end
		seatsOf[v] = seats
	end
	local owner = v:GetAttribute("Owner")
	for _, st in ipairs(seats) do
		local occ = st.Occupant
		local p = occ and occ.Parent and Players:GetPlayerFromCharacter(occ.Parent)
		if p and p.UserId ~= owner then return true end
	end
	return false
end
local lenOf = setmetatable({}, { __mode = "k" }) :: { [Model]: number }
local function vehicleLen(v: Model): number
	local l = lenOf[v]
	if not l then
		local ok, ext = pcall(function() return v:GetExtentsSize() end)
		l = ok and math.max(ext.X, ext.Z) or 14
		lenOf[v] = l
	end
	return l :: number
end

local function onFoot(plr: Player): boolean
	for _, cfg in ipairs(Chasers:GetChildren()) do
		if cfg:GetAttribute("Buddy") and cfg:GetAttribute("Owner") == plr.UserId then return true end
	end
	return false
end

local function makeRider(entry): any?
	local t = Templates:FindFirstChild(entry.Species)
	if not t then return nil end
	local m = t:Clone() :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false end
	end
	local _, size = m:GetBoundingBox()
	local class = Crew.SizeClass(entry.Species)
	local k = 1
	if class == "Medium" then k = math.min(BED_H / size.Y, BED_L / math.max(size.X, size.Z), 1)
	elseif class == "Big" then k = math.min(1, BIG_CAP / size.Y) end
	m:ScaleTo(k)
	m:SetAttribute("AnimScale", k)
	local cf0, s2 = m:GetBoundingBox()
	local root = m.PrimaryPart :: BasePart
	local lift = root.Position.Y - (cf0.Position.Y - s2.Y / 2)
	m.Parent = lf()
	local friend = Instance.new("Highlight")
	friend.FillTransparency = 1
	friend.OutlineColor = Color3.fromRGB(70, 160, 255)
	friend.DepthMode = Enum.HighlightDepthMode.Occluded
	friend.Parent = m
	local anim = DinosaurAnimations.get(m)
	return { Model = m, Root = root, Anim = anim, Lift = lift, Size = s2, Class = class, Next = os.clock() + 2 + math.random() * 4 }
end

-- riding your companion home (the rover flipped): it gallops along under you, pony-sized
local mounts = {} :: { [Player]: any }
local function stepMounts()
	for _, plr in ipairs(Players:GetPlayers()) do
		local sp = plr:GetAttribute("Mount")
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cur = mounts[plr]
		if cur and (cur.Species ~= sp or not hrp) then cur.Model:Destroy() mounts[plr] = nil cur = nil end
		if not (typeof(sp) == "string" and hrp) then continue end
		if not cur then
			local t = Templates:FindFirstChild(sp)
			if not t then continue end
			local m = t:Clone() :: Model
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false end
			end
			local _, size = m:GetBoundingBox()
			local k = math.min(2.9 / size.Y, 5.5 / math.max(size.X, size.Z))
			m:ScaleTo(k)
			m:SetAttribute("AnimScale", k)
			local cf0, s2 = m:GetBoundingBox()
			local root = m.PrimaryPart :: BasePart
			local friend = Instance.new("Highlight")
			friend.FillTransparency = 1
			friend.OutlineColor = Color3.fromRGB(70, 160, 255)
			friend.DepthMode = Enum.HighlightDepthMode.Occluded
			friend.Parent = m
			m.Parent = lf()
			cur = { Model = m, Root = root, Lift = root.Position.Y - (cf0.Position.Y - s2.Y / 2), Anim = DinosaurAnimations.get(m), Species = sp }
			mounts[plr] = cur
		end
		local h = hrp :: BasePart
		local look = Vector3.new(h.CFrame.LookVector.X, 0, h.CFrame.LookVector.Z)
		look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
		local feet = h.Position - Vector3.new(0, 3, 0)
		cur.Root.CFrame = CFrame.lookAt(feet + Vector3.new(0, cur.Lift, 0), feet + Vector3.new(0, cur.Lift, 0) + look) * CFrame.new(0, 0, 0.4)
		if cur.Anim then
			local v = Vector3.new(h.AssemblyLinearVelocity.X, 0, h.AssemblyLinearVelocity.Z).Magnitude
			cur.Anim:SetLocomotion(v > 14 and "Run" or (v > 1 and "Walk" or "Idle"), 0.2)
		end
	end
end

local trail = {} :: { [Model]: number } -- (how many are already running behind each rover this frame)
local function step()
	stepMounts()
	table.clear(trail)
	for _, plr in ipairs(Players:GetPlayers()) do
		local crew = decode(plr:GetAttribute("Crew"))
		local mine = riders[plr] or {}
		riders[plr] = mine
		local want = {}
		for _, e in ipairs(crew) do want[e.Id] = e end
		for id, r in pairs(mine) do
			if not want[id] then r.Model:Destroy() mine[id] = nil end
		end
		local vehicle = #crew > 0 and (vehicleOf(plr) or ridingIn(plr)) or nil
		local seat = vehicle and passengerSeat(vehicle)
		local guest = vehicle ~= nil and hasGuest(vehicle)
		local away = #crew > 0 and onFoot(plr)
		local back, beside = 0, 0
		local shotgun = false
		for _, e in ipairs(crew) do
			local r = mine[e.Id]
			if not r then
				r = makeRider(e)
				if not r then continue end
				mine[e.Id] = r
			end
			-- hidden while it's out of the rover at a site (or there's no rover to ride in)
			local show = seat ~= nil and (e.Fallen or not away)
			if not show then
				if r.Model.Parent then r.Model.Parent = nil end
				continue
			end
			if not r.Model.Parent then r.Model.Parent = lf() end
			local s = seat :: BasePart
			local at
			local running = false
			if guest and not e.Fallen and vehicle and vehicle.PrimaryPart then
				-- a friend's aboard: everyone's companions run along behind the rover, in pairs
				local v = vehicle :: Model
				trail[v] = (trail[v] or 0) + 1
				local n = trail[v]
				running = true
				local vr = v.PrimaryPart :: BasePart
				local sideSign = n % 2 == 1 and 1 or -1
				local row = math.floor((n - 1) / 2)
				local ground = vr.CFrame * CFrame.new(0, -(v:GetAttribute("RootHeight") or 2.6), 0)
				at = ground * CFrame.new(sideSign * (2 + r.Size.X * 0.4), 0, vehicleLen(v) / 2 + 3 + r.Size.Z / 2 + row * (r.Size.Z + 4))
			elseif r.Class == "Small" and not shotgun and not e.Fallen and not s:GetAttribute("Taken") then
				shotgun = true
				at = s.CFrame * CFrame.new(0, s.Size.Y / 2, 0.1) -- shotgun (Taken: a player's sitting there)
			elseif r.Class == "Big" and not e.Fallen and vehicle and vehicle.PrimaryPart then
				-- alongside: off the passenger side, then the driver's side, a little behind, feet on the ground
				beside += 1
				running = true
				local vr = vehicle.PrimaryPart :: BasePart
				local w = (vehicle:GetAttribute("Width") or 8) / 2
				local sideSign = beside % 2 == 1 and 1 or -1
				local ground = vr.CFrame * CFrame.new(0, -(vehicle:GetAttribute("RootHeight") or 2.6), 0)
				at = ground * CFrame.new(sideSign * (w + 3 + r.Size.X / 2), 0, 2 + math.floor((beside - 1) / 2) * (r.Size.Z + 3))
			else
				back += 1
				at = s.CFrame * CFrame.new(-0.4 - (back - 1) * 1.7, s.Size.Y / 2 + 0.5, 2.6) -- in the back
			end
			local pose = at * CFrame.new(0, r.Lift, 0)
			if r.Anim then
				local sp = vehicle and vehicle.PrimaryPart and vehicle.PrimaryPart.AssemblyLinearVelocity.Magnitude or 0
				local want = running and (sp > 20 and "Run" or (sp > 2 and "Walk" or "Idle")) or "Idle"
				if r.Loco ~= want then r.Loco = want r.Anim:SetLocomotion(want, 0.25) end
			end
			if e.Fallen then pose = pose * CFrame.new(0, -r.Lift * 0.4, 0) * CFrame.Angles(0, 0, 1.35) end
			r.Root.CFrame = pose
			if r.Anim then
				r.Anim.EyesClosed = e.Fallen == true
				-- along for the ride: looks about, now and then a roar at whatever's chasing you
				if not e.Fallen and os.clock() > r.Next and not r.Anim:IsPlaying() then
					r.Next = os.clock() + 4 + math.random() * 5
					local speed = vehicle and vehicle.PrimaryPart and vehicle.PrimaryPart.AssemblyLinearVelocity.Magnitude or 0
					local a = (speed > 30 and math.random() < 0.5 and r.Anim:HasAction("Roar")) and "Roar" or "LookAround"
					if r.Anim:HasAction(a) then r.Anim:Play(a) end
				end
			end
		end
	end
	for plr, mine in pairs(riders) do
		if not plr.Parent then
			for _, r in pairs(mine) do r.Model:Destroy() end
			riders[plr] = nil
		end
	end
end

function Crew.Start()
	RunService.RenderStepped:Connect(step)
end

return Crew
