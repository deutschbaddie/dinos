--[[
	Carpool (client) — the driver's side of "can I ride along?" (server: ServerScriptService Game/Carpool).
	A card drops in at the top of the screen: "<NAME> WANTS A RIDE", YES / NO, a bar running down 12 seconds.
	Keys: Y / N, D-pad up / down on a gamepad, or tap. Ignoring it is a no.

	And the rider's side once they're knocked out of a fight (RiderOut: they wake in the back seat): the camera follows
	the driver through the rest of it, with LEAVE TO HUB (L / B on a gamepad) to head home instead. It ends by itself
	when they step out at the next stop, the driver's back at the wheel, or the ride's over.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local C = Theme.C

local Carpool = {}
local gui, canvas
local open: { Holder: Frame, Id: number }? = nil

local function answer(id: number, yes: boolean)
	if not (open and open.Id == id) then return end
	local holder = open.Holder
	open = nil
	ContextActionService:UnbindAction("DinoRideYes")
	ContextActionService:UnbindAction("DinoRideNo")
	if holder.Parent then Kit.Exit(holder, true) end
	task.spawn(function() Net.Ask("RideAnswer", { Id = id, Yes = yes }) end)
end

local function show(info)
	if open then answer(open.Id, false) end
	if not gui then gui, canvas = Kit.Screen("DinoRideRequest", 40, false) end
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(440, 150)
	holder.Position = UDim2.new(0.5, 0, 0, 96)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Parent = canvas
	local _, cc = Kit.Card(holder, { Size = UDim2.fromScale(1, 1), Color = "Forest", Border = C.Teal, ZIndex = 50 })
	Kit.Icon(cc, "Jeep", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(8, 8), ZIndex = 53, Rotation = -6 })
	Kit.Text(cc, string.upper(tostring(info.Name or "SOMEONE")), { Size = UDim2.new(1, -90, 0, 30), Position = UDim2.fromOffset(80, 10), Align = Enum.TextXAlignment.Left, ZIndex = 53, MaxSize = 28, Color = C.TealHi })
	Kit.Text(cc, "WANTS TO RIDE IN YOUR ROVER", { Pixel = true, Size = UDim2.new(1, -90, 0, 10), Position = UDim2.fromOffset(80, 48), Align = Enum.TextXAlignment.Left, ZIndex = 53, MaxSize = 10 })
	local pad = Kit.Gamepad()
	local id = info.Id
	Kit.Button(cc, { Text = pad and "YES  [UP]" or "YES  [Y]", Color = "Lime", Size = UDim2.new(0.5, -14, 0, 48), Position = UDim2.fromOffset(8, 78), ZIndex = 53, MaxText = 20, Lip = 4, OnClick = function() answer(id, true) end })
	Kit.Button(cc, { Text = pad and "NO  [DOWN]" or "NO  [N]", Color = "Red", Size = UDim2.new(0.5, -14, 0, 48), Position = UDim2.new(0.5, 6, 0, 78), ZIndex = 53, MaxText = 20, Lip = 4, OnClick = function() answer(id, false) end })
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = C.Teal
	bar.Size = UDim2.new(1, -16, 0, 5)
	bar.Position = UDim2.new(0, 8, 1, -12)
	bar.ZIndex = 53
	bar.Parent = cc
	local t = tonumber(info.Time) or 12
	TweenService:Create(bar, TweenInfo.new(t, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 5) }):Play()
	Kit.Pop(holder, 0.3)
	open = { Holder = holder, Id = id }
	ContextActionService:BindActionAtPriority("DinoRideYes", function(_, state)
		if state == Enum.UserInputState.Begin then answer(id, true) return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end, false, 2200, Enum.KeyCode.Y, Enum.KeyCode.DPadUp)
	ContextActionService:BindActionAtPriority("DinoRideNo", function(_, state)
		if state == Enum.UserInputState.Begin then answer(id, false) return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end, false, 2200, Enum.KeyCode.N, Enum.KeyCode.DPadDown)
	task.delay(t, function() answer(id, false) end)
end

--------------------------------------------------------------------------------
-- out of the fight as a rider: watch the driver, or go home
--------------------------------------------------------------------------------
local player = Players.LocalPlayer
local out = nil :: any -- { Gui, Conn, Driver }

local function endOut()
	local o = out
	if not o then return end
	out = nil
	o.Conn:Disconnect()
	ContextActionService:UnbindAction("DinoRiderLeave")
	if o.Gui then o.Gui:Destroy() end
	local cam = Workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if cam and hum and cam.CameraSubject ~= hum and cam.CameraType == Enum.CameraType.Custom then cam.CameraSubject = hum end
end

local function leave()
	if not out then return end
	local res = Net.Ask("RiderLeave", {})
	if res and res.Ok then endOut() elseif res and res.Err then Kit.Toast(res.Err, "Orange", "Alert") end
end

local function riderOut(info)
	endOut()
	local driver = typeof(info) == "table" and Players:GetPlayerByUserId(tonumber(info.Driver) or 0) or nil
	if not driver then return end
	local g, cv = Kit.Screen("DinoRiderOut", 38, false)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(300, 108)
	holder.Position = UDim2.new(0.5, 0, 1, -24)
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Parent = cv
	local _, cc = Kit.Card(holder, { Size = UDim2.fromScale(1, 1), Color = "Forest", Border = C.Teal, ZIndex = 50 })
	Kit.Icon(cc, "Eye", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(10, 8), ZIndex = 53 })
	Kit.Text(cc, string.upper(driver.DisplayName), { Size = UDim2.new(1, -64, 0, 26), Position = UDim2.fromOffset(52, 12), Align = Enum.TextXAlignment.Left, ZIndex = 53, MaxSize = 24, Color = C.TealHi })
	Kit.Button(cc, { Text = "LEAVE TO HUB", Icon = "Home", IconSize = 0.8, TextLeft = 0.26, Color = "Red", Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 53, MaxText = 20, OnClick = leave })
	Kit.Pop(holder, 0.5)
	ContextActionService:BindAction("DinoRiderLeave", function(_, st)
		if st == Enum.UserInputState.Begin then leave() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.L, Enum.KeyCode.ButtonB)
	local t0 = os.clock()
	local o = { Gui = g, Driver = driver }
	o.Conn = RunService.Heartbeat:Connect(function()
		local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local dHum = driver.Character and driver.Character:FindFirstChildOfClass("Humanoid")
		-- done: you're out of your seat (the next stop), the driver's at the wheel again, or the ride's over
		local seated = myHum ~= nil and myHum.SeatPart ~= nil
		local driving = dHum ~= nil and dHum.SeatPart ~= nil and dHum.SeatPart:IsA("VehicleSeat")
		if not driver.Parent or not player:GetAttribute("RidingWith") or (os.clock() - t0 > 1 and (not seated or driving)) then
			endOut()
			return
		end
		local cam = Workspace.CurrentCamera
		if cam and dHum and cam.CameraType == Enum.CameraType.Custom and cam.CameraSubject ~= dHum then cam.CameraSubject = dHum end
	end)
	out = o
end

function Carpool.Start()
	Net.On("RideRequest", show)
	Net.On("RiderOut", riderOut)
	Net.On("RideReturn", endOut)
end

return Carpool
