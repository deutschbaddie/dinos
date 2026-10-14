--[[
	Carpool — riding in someone else's rover at camp (2026-10-13).
	Every passenger seat on a rover out at camp carries a RIDE prompt (its owner never sees it). Pressing it asks the
	driver (a YES / NO card on their screen, 12 seconds); YES sits you in that seat. A seat a player is in is marked
	Taken, so a companion that would ride there moves to the back (Crew / PaddockLife). When the driver gets out,
	parks, or the rover goes away, every passenger gets out too (Vehicles.EjectPassengers).
	Seats: Rookie Ranger + Raptor Runner have one passenger seat, the Titan Transport three (PassengerSeat,
	PassengerSeat2, PassengerSeat3 - tools/gen/vehicles/titanTransport.js).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Carpool = {}
local Net, Vehicles, Expedition
local Shore = require(script.Parent.Shore)

local REQUEST_TIME = 12
local pending = {} :: { [Player]: { Owner: Player, Seat: Seat, At: number, Id: number } }
local nextId = 0
local riding = {} :: { [Player]: { Seat: Seat, Conn: RBXScriptConnection, Out: boolean? } }
-- set by Expedition: a rider on a run can't just hop out on the road (they're sat straight back down)
Carpool.Locked = nil :: ((Player) -> boolean)?

local function passengerSeats(v: Model): { Seat }
	local out = {}
	for _, d in ipairs(v:GetDescendants()) do
		if d:IsA("Seat") and d.Name:match("^PassengerSeat%d*$") then table.insert(out, d) end
	end
	return out
end

local function ownerOf(v: Instance): Player?
	local m: Instance? = v
	while m and not (m:IsA("Model") and m:GetAttribute("Owner") ~= nil) do m = m.Parent end
	return m and Players:GetPlayerByUserId(m:GetAttribute("Owner")) or nil
end

local function setGroup(char: Instance?, group: string, massless: boolean)
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = group
			p.Massless = massless -- (a passenger's weight would drag the driver's kinematic rover)
		end
	end
end

local function standUp(plr: Player)
	local r = riding[plr]
	if not r then return end
	riding[plr] = nil
	r.Conn:Disconnect()
	local seat = r.Seat
	seat:SetAttribute("Taken", nil)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and seat.Occupant == hum then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then weld:Destroy() end
		hum.Sit = false
	end
	seat.Disabled = true
	setGroup(char, Shore.WALKERS, false)
	-- out beside the rover, on the seat's side
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local v = seat:FindFirstAncestorWhichIsA("Model")
	while v and v:GetAttribute("Owner") == nil and v.Parent and v.Parent:IsA("Model") do v = v.Parent :: Model end
	if hrp and v then
		local pivot = (v :: Model):GetPivot()
		local lx = pivot:PointToObjectSpace(seat.Position).X
		local out = seat.Position + pivot.RightVector * (lx >= 0 and 1 or -1) * ((v:GetAttribute("Width") or 8) / 2 + 3)
		task.defer(function()
			if char and char.Parent then char:PivotTo(CFrame.new(out + Vector3.new(0, 3, 0))) end
		end)
	end
	Net.Fire(plr, "RideOver", {})
end

local function sitIn(plr: Player, seat: Seat): boolean
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) or seat.Occupant or seat:GetAttribute("Taken") then return false end
	seat.Disabled = false -- (template seats are Disabled so nobody sits by bumping into them; CanTouch is off too)
	char:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
	seat:Sit(hum)
	seat:SetAttribute("Taken", plr.UserId)
	setGroup(char, "DinoVehicles", true)
	local conn
	conn = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == hum then return end
		local r = riding[plr]
		if r and r.Out then return end -- (stepped out on purpose: a site on the driver's run)
		if r and Carpool.Locked and Carpool.Locked(plr) then
			task.delay(0.1, function()
				local cur = riding[plr]
				if cur == r and not cur.Out and not seat.Occupant and hum.Parent and hum.Health > 0 then seat:Sit(hum) end
			end)
			return
		end
		standUp(plr)
	end)
	riding[plr] = { Seat = seat, Conn = conn }
	return true
end

-- everyone riding in this rover right now (in their seats, not stepped out at a site)
function Carpool.Passengers(v: Model): { Player }
	local out = {}
	for plr, r in pairs(riding) do
		if r.Seat:IsDescendantOf(v) and not r.Out then table.insert(out, plr) end
	end
	return out
end

-- a site on the driver's run: out of the seat (it stays theirs) and onto their feet at `at`
function Carpool.StepOut(plr: Player, at: CFrame?)
	local r = riding[plr]
	if not r or r.Out then return end
	r.Out = true
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and r.Seat.Occupant == hum then
		local weld = r.Seat:FindFirstChild("SeatWeld")
		if weld then weld:Destroy() end
		hum.Sit = false
	end
	setGroup(char, Shore.WALKERS, false)
	if at and char then task.defer(function() if char.Parent then char:PivotTo(at) end end) end
end

-- back into the seat they stepped out of (the driver's leaving the site)
function Carpool.SitBack(plr: Player)
	local r = riding[plr]
	if not r or not r.Out then return end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hum and r.Seat.Parent) then return end
	if hum.Health <= 0 then hum.Health = hum.MaxHealth end
	hum.PlatformStand = false
	r.Out = false
	char:PivotTo(r.Seat.CFrame * CFrame.new(0, 2, 0))
	r.Seat:Sit(hum)
	setGroup(char, "DinoVehicles", true)
end

-- done riding for good; `to` puts them somewhere (home) instead of beside the rover
function Carpool.Release(plr: Player, to: CFrame?)
	-- (already out of the seat - the rover went first: the driver left the game and Vehicles despawned it - still goes
	-- to `to`: they were left standing in the era while their screen warped home. 2026-10-14)
	if riding[plr] then standUp(plr) end
	local char = plr.Character
	if to and char then task.delay(0.05, function() if char.Parent then char:PivotTo(to) end end) end
end

-- the driver's rover is going away / parking: everyone out
function Carpool.EjectAll(v: Model?)
	if not v then return end
	for plr, r in pairs(riding) do
		if r.Seat:IsDescendantOf(v) then standUp(plr) end
	end
end

function Carpool.IsPassenger(plr: Player): boolean
	return riding[plr] ~= nil
end

local function promptFor(seat: Seat, owner: number)
	if seat:FindFirstChild("RidePrompt") then return end
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "RidePrompt"
	pr.ActionText = "Ride along"
	pr.ObjectText = (Players:GetPlayerByUserId(owner) and Players:GetPlayerByUserId(owner).DisplayName or "Someone") .. "'s rover"
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr:SetAttribute("NotOwner", owner) -- (its owner never sees it: client Prompt.luau)
	pr:SetAttribute("PromptColor", "Teal")
	pr.Parent = seat
	pr.Triggered:Connect(function(plr) Carpool.Ask(plr, seat) end)
end

-- a rover just rolled out: its passenger seats get their RIDE prompts
function Carpool.Dress(v: Model)
	local owner = v:GetAttribute("Owner")
	if not owner then return end
	for _, seat in ipairs(passengerSeats(v)) do promptFor(seat, owner) end
end

function Carpool.Ask(plr: Player, seat: Seat)
	local driver = ownerOf(seat)
	if not driver or driver == plr then return end
	local function no(text: string) Net.Fire(plr, "Toast", { Text = text, Color = "Orange" }) end
	if Expedition.Get(plr) or Expedition.Get(driver) then return no("NOT DURING AN EXPEDITION") end
	if riding[plr] then return no("YOU'RE ALREADY RIDING") end
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then return no("HOP OUT FIRST") end
	if seat.Occupant or seat:GetAttribute("Taken") then return no("THAT SEAT'S TAKEN") end
	local dh = driver.Character and driver.Character:FindFirstChildOfClass("Humanoid")
	local v = Vehicles.Get(driver)
	if not (v and seat:IsDescendantOf(v)) then return end
	if not (dh and dh.SeatPart and dh.SeatPart:IsDescendantOf(v)) then return no("WAIT FOR THE DRIVER TO GET IN") end
	local p = pending[plr]
	if p and os.clock() - p.At < REQUEST_TIME then return no("ASKING " .. string.upper(driver.DisplayName) .. "...") end
	nextId += 1
	pending[plr] = { Owner = driver, Seat = seat, At = os.clock(), Id = nextId }
	Net.Fire(driver, "RideRequest", { Id = nextId, From = plr.UserId, Name = plr.DisplayName, Time = REQUEST_TIME })
	Net.Fire(plr, "Toast", { Text = "ASKING " .. string.upper(driver.DisplayName) .. " FOR A RIDE...", Color = "Teal" })
end

function Carpool.Start(deps)
	Net, Vehicles, Expedition = deps.Net, deps.Vehicles, deps.Expedition
	Net.On("RideAnswer", function(driver, args)
		if typeof(args.Id) ~= "number" then return { Ok = false } end
		for plr, p in pairs(pending) do
			if p.Id == args.Id and p.Owner == driver then
				pending[plr] = nil
				if args.Yes ~= true then
					Net.Fire(plr, "Toast", { Text = string.upper(driver.DisplayName) .. " SAID NO THIS TIME", Color = "Orange" })
					return { Ok = true }
				end
				if os.clock() - p.At > REQUEST_TIME + 2 or not plr.Parent then return { Ok = false } end
				local v = Vehicles.Get(driver)
				local seat = p.Seat
				if not (v and seat:IsDescendantOf(v)) or Expedition.Get(driver) or Expedition.Get(plr) then return { Ok = false } end
				-- the asked-for seat, or any other free one
				if seat.Occupant or seat:GetAttribute("Taken") then
					seat = nil :: any
					for _, s in ipairs(passengerSeats(v)) do if not s.Occupant and not s:GetAttribute("Taken") then seat = s break end end
				end
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not seat or not hrp or (hrp.Position - seat.Position).Magnitude > 60 then
					Net.Fire(plr, "Toast", { Text = "MISSED YOUR RIDE", Color = "Orange" })
					return { Ok = false }
				end
				if sitIn(plr, seat) then
					Net.Fire(plr, "Toast", { Text = "RIDING WITH " .. string.upper(driver.DisplayName) .. "!", Color = "Teal" })
					return { Ok = true }
				end
				return { Ok = false }
			end
		end
		return { Ok = false }
	end)
	-- a passenger can always hop out (jump, or the HUD's EXIT)
	Net.On("RideLeave", function(plr)
		-- (riding along on someone's run: home on foot, the proper way - a bare stand-up left you on the road in the
		-- era, still "riding", while the rover drove off. 2026-10-14)
		if Carpool.Locked and Carpool.Locked(plr) then return Expedition.RiderLeave(plr) end
		standUp(plr)
		return { Ok = true }
	end)
	-- every rover that rolls out gets its prompts
	local function watch(f: Instance)
		f.ChildAdded:Connect(function(v)
			if v:IsA("Model") then task.defer(Carpool.Dress, v) end
		end)
		for _, v in ipairs(f:GetChildren()) do if v:IsA("Model") then Carpool.Dress(v) end end
	end
	local f = Workspace:FindFirstChild("ActiveVehicles")
	if f then watch(f) else
		Workspace.ChildAdded:Connect(function(c) if c.Name == "ActiveVehicles" then watch(c) end end)
	end
	Players.PlayerRemoving:Connect(function(plr)
		standUp(plr)
		pending[plr] = nil
		for other, p in pairs(pending) do if p.Owner == plr then pending[other] = nil end end
	end)
end

return Carpool
