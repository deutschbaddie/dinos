--[[
	RideShop — the paint shop next to every garage: buy rover parts and paints, save a body's build, honk.
	All rules live in the shared Rides module (prices, unlocks, what a style may contain); this enforces them.

	RideBuy  { Slot, Id }        pay once, own it for every body
	RideSave { Body, Style }     save a build (anything you don't own falls back to what you had)
	Honk     {}                  everyone nearby hears your horn
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local Rides = require(ReplicatedStorage.DinoExpedition.Game.Rides)

local RideShop = {}
local Data, Net, Vehicles
local lastHonk = {} :: { [Player]: number }

local function buy(player: Player, slot: string, id: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local item = Rides.Item(slot, id)
	if not item then return { Ok = false, Err = "UNKNOWN PART" } end
	if Rides.Owns(profile, slot, id) then return { Ok = true, Already = true } end
	local lock = Rides.LockReason(profile, item)
	if lock then return { Ok = false, Err = lock } end
	local price = item.Price or 0
	if profile.Coins < price then return { Ok = false, Err = "NOT ENOUGH COINS" } end
	profile.Coins -= price
	profile.RideOwned = profile.RideOwned or {}
	profile.RideOwned[Rides.Key(slot, id)] = true
	Data.Changed(player)
	if price >= 20000 then
		Net.FireAll("Announce", { Text = string.format("%s FITTED %s TO THEIR RIDE!", string.upper(player.DisplayName), item.Name), Color = "Purple" })
	end
	return { Ok = true, Name = item.Name }
end

-- respawn the rover in place so a new build shows up on the one you're driving around camp
local function restyle(player: Player, body: string)
	local v = Vehicles.Get(player)
	-- (a rover parked at camp stays as it is - respawning it seated you in it from inside the shop; the next DRIVE
	-- brings out the new build)
	if not v or Vehicles.Locked[player] or Vehicles.CampParked[player] or v:GetAttribute("VehicleName") ~= body then return end
	local root = v.PrimaryPart
	if not root then return end
	local oldRH = v:GetAttribute("RootHeight") or 2.6
	local cf = root.CFrame
	local nv = Vehicles.Spawn(player, cf, body)
	if nv and nv.PrimaryPart then
		local dy = (nv:GetAttribute("RootHeight") or 2.6) - oldRH
		if math.abs(dy) > 0.01 then Vehicles.Teleport(player, cf + Vector3.new(0, dy, 0)) end
	end
end

local function save(player: Player, body: string, style: any)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	if not (profile.Gear.Vehicles and profile.Gear.Vehicles[body]) then return { Ok = false, Err = "YOU DON'T OWN THAT BODY" } end
	local want = Rides.Fill(style)
	local had = Rides.StyleFor(profile, body)
	-- anything not owned (a preview you didn't buy) keeps what was saved before
	for _, slot in ipairs(Rides.Slots) do
		if not Rides.Owns(profile, slot, want[slot]) then want[slot] = had[slot] end
	end
	profile.Rides = profile.Rides or {}
	profile.Rides[body] = want
	Data.Changed(player)
	task.defer(restyle, player, body)
	return { Ok = true, Style = want }
end

-- a second prompt at every garage door: the paint shop
local function addPaintShop(garage: Instance)
	if garage:FindFirstChild("PaintShopHost", true) then return end
	local host = garage:FindFirstChild("GaragePromptHost", true) :: BasePart?
	local pivot = garage:FindFirstChild("GarageDoorPivot", true) :: BasePart?
	if not (host and pivot) then return end
	-- mirror the door-button host to the other side of the door
	local lp = pivot.CFrame:PointToObjectSpace(host.Position)
	local pos = pivot.CFrame:PointToWorldSpace(Vector3.new(-lp.X, lp.Y, lp.Z))
	local m = Instance.new("Model")
	m.Name = "PaintShop"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local face = CFrame.lookAt(pos, pos + pivot.CFrame.LookVector)
	local panel = part("PaintShopHost", Vector3.new(1.6, 2.2, 0.4), face * CFrame.new(0, 0, 0.3), Color3.fromRGB(43, 45, 49))
	-- a paint can with drips on the panel, so you know what this button does from across the yard
	local can = part("PaintCan", Vector3.new(0.9, 0.8, 0.9), face * CFrame.new(0, 0.2, -0.25), Color3.fromRGB(200, 205, 212), Enum.Material.Metal)
	can.Shape = Enum.PartType.Cylinder
	can.CFrame = face * CFrame.new(0, 0.2, -0.25) * CFrame.Angles(0, 0, math.pi / 2)
	local cols = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 160, 255), Color3.fromRGB(150, 230, 50) }
	for i, c in ipairs(cols) do
		part("PaintDrip", Vector3.new(0.2, 0.25 + i * 0.12, 0.08), face * CFrame.new(-0.45 + i * 0.2, 0.55 - (0.25 + i * 0.12) / 2, -0.47), c, Enum.Material.Neon)
	end
	part("PaintShopSign", Vector3.new(1.5, 0.45, 0.1), face * CFrame.new(0, 1.1, 0.08), Color3.fromRGB(173, 102, 255), Enum.Material.Neon)
	local a = Instance.new("Attachment")
	a.Name = "PromptAttachment"
	a.Parent = panel
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "PaintShopPrompt"
	pr.ActionText = "Ride Shop"
	pr.ObjectText = "Garage"
	pr.KeyboardKeyCode = Enum.KeyCode.R
	pr.GamepadKeyCode = Enum.KeyCode.ButtonY
	pr.MaxActivationDistance = 16
	pr.HoldDuration = 0
	pr.RequiresLineOfSight = false
	pr:SetAttribute("CampAction", "Customize")
	pr:SetAttribute("PromptColor", "Purple")
	pr.Parent = a
	m.Parent = garage
end

function RideShop.Start(deps)
	Data, Net, Vehicles = deps.Data, deps.Net, deps.Vehicles
	Net.On("RideBuy", function(player, args)
		if typeof(args.Slot) ~= "string" or typeof(args.Id) ~= "string" then return { Ok = false } end
		return buy(player, args.Slot, args.Id)
	end)
	Net.On("RideSave", function(player, args)
		if typeof(args.Body) ~= "string" or typeof(args.Style) ~= "table" then return { Ok = false } end
		return save(player, args.Body, args.Style)
	end)
	Net.On("Honk", function(player)
		local now = os.clock()
		if now - (lastHonk[player] or 0) < 0.7 then return { Ok = false } end
		lastHonk[player] = now
		local v = Vehicles.Get(player)
		if not v then return { Ok = false } end
		Net.FireAll("Honk", { Owner = player.UserId, Horn = v:GetAttribute("Horn") or "Beep" })
		return { Ok = true }
	end)
	Players.PlayerRemoving:Connect(function(p) lastHonk[p] = nil end)
	task.spawn(function()
		local camp = Workspace:WaitForChild("BaseCamp", 30)
		if not camp then return end
		for _, d in ipairs(camp:GetDescendants()) do
			if d:IsA("Model") and d.Name == "Garage" then pcall(addPaintShop, d) end
		end
	end)
	local _ = Config
end

return RideShop
