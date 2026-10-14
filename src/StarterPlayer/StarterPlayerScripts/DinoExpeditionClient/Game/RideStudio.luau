--[[
	RideStudio — the RIDE SHOP at your garage: everything about your rover in one place.

	Your car turns on a turntable in the open space on the left; the shop window sits on the right, in the same
	jungle-window style as every other panel. Eight big category tabs (UPGRADE, PAINT, WHEELS, BODY KIT, WRAPS,
	GLOW, BOOST, HORN), a grid of big tiles, and a footer that says what you picked and what it does.
	Tap a tile and the car changes right there (things you don't own still try on; the footer's BUY button buys
	them). Closing keeps everything you own.

	Kid-simple: tap, see, buy. Car-guy deep: every part's SPEED / BOOST / ARMOR / GRIP trade-off, the build's
	numbers against what you had, levels / new bodies / plating / roof rack under UPGRADE, rarer parts behind eras
	and rulers. Mobile: big tap targets, drag to spin, pinch to zoom, everything fits a phone in landscape.

	RideStudio.Open(body?, tab?)    (garage RIDE SHOP prompt, the ride picker)
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local Rides = require(DinoShared:WaitForChild("Game"):WaitForChild("Rides"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local CineKit = require(script.Parent.UI.CineKit)
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)
local Audio = require(script.Parent.Audio)
local RideFx = require(script.Parent.RideFx)

local player = Players.LocalPlayer
local C = Theme.C
local RideStudio = {}

local Templates = DinoShared:WaitForChild("Vehicles")
local Kits = DinoShared:WaitForChild("RoverKits")

local S = nil :: any -- the open shop

-- the tabs: UPGRADE first (levels, bodies, plating, rack), then the looks from the shared catalog
local TABS = { { Id = "Upgrade", Name = "UPGRADE", Icon = "Jeep" } }
for _, t in ipairs(Rides.Tabs) do table.insert(TABS, t) end
local function tabDef(id: string)
	for _, t in ipairs(TABS) do if t.Id == id then return t end end
	return TABS[2]
end

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------
local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	for k, v in pairs(props or {}) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end
local function pixel(parent, s: string, props)
	props.Pixel = true
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2
	props.Shadow = props.Shadow or 1
	props.MaxSize = props.MaxSize or 12
	return Kit.Text(parent, s, props)
end
local function text(parent, s: string, props)
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 3
	props.Shadow = props.Shadow or 2
	return Kit.Text(parent, s, props)
end
local function clear(parent: Instance)
	for _, c in ipairs(parent:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
end

-- toasts are hidden while the shop holds the screen, so the shop calls things out itself
local function notice(msg: string, color: Color3?)
	if not S or not S.Gui then return end
	local canvas = S.Gui:FindFirstChild("Canvas", true)
	if not canvas then return end
	local box = Kit.Text(canvas, msg, { Size = UDim2.fromOffset(560, 34), Position = UDim2.new(0.5, -240, 0, 186), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 60, Color = color or C.LimeHi, Stroke = 3.5, Shadow = 3, MaxSize = 30 })
	Kit.Pop(box :: any, 0.4)
	task.delay(1.6, function() if box.Parent then Kit.Exit(box :: any, true) end end)
end

local function ownGarage(): Instance?
	local idx = player:GetAttribute("Plot")
	local camp = Workspace:FindFirstChild("BaseCamp")
	local plot = camp and idx and camp:FindFirstChild("Plot" .. idx, true)
	return plot and plot:FindFirstChild("Garage", true)
end

local function ownedBodies(): { string }
	local p = Net.Profile
	local list = {}
	for _, n in ipairs(Config.VehicleOrder) do
		if p and p.Gear and p.Gear.Vehicles and p.Gear.Vehicles[n] then table.insert(list, n) end
	end
	return list
end

-- price band colours, like rarity bands: you can read how special a part is at a glance
local function tierColor(price: number): Color3
	if price <= 0 then return C.JungleLo end
	if price < 5000 then return C.GreyLo end
	if price < 25000 then return C.BlueLo end
	if price < 150000 then return C.PurpleLo end
	return C.OrangeLo
end

local STAT_NAME = { Speed = "SPEED", Boost = "BOOST", Armor = "ARMOR", Grip = "GRIP" }
local function statChips(item): { { string } }
	local out = {}
	for _, k in ipairs({ "Speed", "Boost", "Armor", "Grip" }) do
		local v = item and item.Stats and item.Stats[k]
		if v and v ~= 0 then
			local unit = (k == "Armor" or k == "Grip") and "%" or ""
			table.insert(out, { (v > 0 and "+" or "") .. tostring(v) .. unit .. " " .. STAT_NAME[k], v > 0 and "Up" or "Down" })
		end
	end
	return out
end

local function stockHex(attr: string): string?
	local tpl = Templates:FindFirstChild(S.Body)
	return tpl and tpl:GetAttribute(attr)
end
local function paintColor(): Color3
	local c = Rides.Color(S.Style.Paint)
	if c then return c end
	local hex = stockHex("StockP")
	return hex and Color3.fromHex(hex) or Color3.fromRGB(242, 182, 50)
end

-- each slot's camera: yaw (0 = in front of the car), pitch, how much of the car to fit, what to look at, and
-- whether the turntable swings the car round to show its back (the camera stays out on the yard side)
local SHOTS = {
	Upgrade = { -34, 13, 1, "Center" },
	Paint = { -38, 13, 1, "Center" }, Paint2 = { 36, 14, 1, "Center" }, Finish = { -30, 18, 1, "Center" },
	Rims = { -74, 5, 0.32, "Wheel" }, RimColor = { -74, 5, 0.32, "Wheel" }, Tires = { -80, 4, 0.32, "Wheel" }, Lift = { -90, 4, 1, "Center" },
	Front = { -26, 10, 0.55, "Front" }, Rear = { 28, 13, 0.55, "Rear", true }, Roof = { -30, 30, 0.62, "Roof" },
	Wrap = { -90, 8, 1, "Center" }, WrapColor = { -90, 8, 1, "Center" },
	Glow = { -40, 5, 1, "Low" }, GlowColor = { -40, 5, 1, "Low" },
	Trail = { 22, 10, 1, "Rear", true }, Horn = { -18, 10, 0.75, "Front" },
}

--------------------------------------------------------------------------------
-- the preview car
--------------------------------------------------------------------------------
local function buildPreview()
	local old = S.Model
	if old then
		RideFx.Untrack(old)
		old:Destroy()
	end
	local tpl = Templates:FindFirstChild(S.Body)
	if not tpl then return end
	local v = tpl:Clone() :: Model
	v.Name = "DinoRidePreview"
	pcall(Rides.Apply, v, S.Body, S.Style)
	local root = v.PrimaryPart :: BasePart
	for _, p in ipairs(v:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = p == root
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	S.RH = v:GetAttribute("RootHeight") or 2.6
	S.Lift = v:GetAttribute("Lift") or 0
	S.Len = v:GetAttribute("Length") or 15
	S.Wid = v:GetAttribute("Width") or 8
	S.Height = v:GetAttribute("Height") or 8
	root.CFrame = S.Stage * CFrame.new(0, S.RH, 0) * CFrame.Angles(0, S.CarYaw, 0)
	v.Parent = Workspace
	S.Model = v
	S.Root = root
	RideFx.Track(v)
	RideFx.Trail(v, S.Tab == "Boost")
end

-- where a shot looks, in turntable space (ground level = 0)
local function focusPoint(kind: string): Vector3
	local L, H = S.Len, S.Height
	if kind == "Front" then return Vector3.new(0, H * 0.42, -L * 0.42) end
	if kind == "Rear" then return Vector3.new(0, H * 0.45, L * 0.42) end
	if kind == "Roof" then return Vector3.new(0, H * 0.8, -L * 0.15) end
	if kind == "Low" then return Vector3.new(0, H * 0.25, 0) end
	if kind == "Wheel" and S.WheelLP then return S.WheelLP + Vector3.new(0, S.RH - S.Lift, 0) end
	return Vector3.new(0, H * 0.42, 0)
end

--------------------------------------------------------------------------------
-- tile visuals
--------------------------------------------------------------------------------
local function viewport(parent: Instance, model: Instance?, dir: Vector3, z: number, bg: Color3?)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundColor3 = bg or C.InkSoft
	vp.BackgroundTransparency = bg and 0 or 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(190, 190, 190)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.4)
	vp.ZIndex = z
	vp.Parent = parent
	Kit.Corner(vp, 10)
	if not model then return vp end
	local m = model
	m.Parent = vp
	local ok, cf, size = pcall(function() return (m :: Model):GetBoundingBox() end)
	if not ok then return vp end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	local r = math.max(0.5, (size :: Vector3).Magnitude / 2)
	local d = r / math.tan(math.rad(14)) * 1.02
	cam.CFrame = CFrame.lookAt((cf :: CFrame).Position + dir.Unit * d, (cf :: CFrame).Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

local function cloneParts(list: { Instance }): Model
	local m = Instance.new("Model")
	for _, p in ipairs(list) do
		local c = p:Clone()
		for _, j in ipairs(c:GetDescendants()) do if j:IsA("JointInstance") then j:Destroy() end end
		if c:IsA("BasePart") then c.Anchored = true end
		c.Parent = m
	end
	return m
end

-- the template's own bits for a slot (what FACTORY means on this body)
local function stockModel(slot: string): Model?
	local tpl = Templates:FindFirstChild(S.Body)
	if not tpl then return nil end
	local list = {}
	if slot == "Rims" or slot == "Tires" then
		local names = slot == "Rims" and { Rim = 1, RimLip = 1, RimAccent = 1, Spoke = 1, LugNut = 1, Hub = 1 } or { Tire = 1, Sidewall = 1, Tread = 1 }
		local w = S.WheelName and tpl:FindFirstChild(S.WheelName, true)
		if w then for _, p in ipairs(w:GetDescendants()) do if p:IsA("BasePart") and names[p.Name] then table.insert(list, p) end end end
	else
		for _, p in ipairs(tpl:GetDescendants()) do
			if p:IsA("BasePart") and p:GetAttribute("KitSlot") == slot then table.insert(list, p) end
		end
	end
	if #list == 0 then return nil end
	return cloneParts(list)
end

local function kitModel(slot: string, id: string): Model?
	local body = Kits:FindFirstChild(S.Body)
	if not body then return nil end
	if slot == "Rims" or slot == "Tires" then
		local g = body:FindFirstChild("Wheels")
		local k = g and g:FindFirstChild((slot == "Rims" and "Rim_" or "Tire_") .. id)
		local w = k and S.WheelName and k:FindFirstChild(S.WheelName)
		return w and (w:Clone() :: Model) or nil
	end
	local g = body:FindFirstChild(slot)
	local k = g and g:FindFirstChild(id)
	if not k then return nil end
	if slot == "Wrap" then
		-- just the right-hand side, so it reads flat from the side
		local list = {}
		for _, p in ipairs(k:GetDescendants()) do if p:IsA("BasePart") and p.Position.X > 0 then table.insert(list, p) end end
		return cloneParts(list)
	end
	return k:Clone() :: Model
end

local VIEW_DIR = {
	Rims = Vector3.new(1, 0.1, -0.15), Tires = Vector3.new(1, 0.15, -0.25),
	Front = Vector3.new(0.55, 0.35, -1), Rear = Vector3.new(0.6, 0.4, 1), Roof = Vector3.new(0.5, 0.6, -1), Wrap = Vector3.new(1, 0.05, 0),
}

local RAINBOW_SEQ = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 60)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 255)) })

local function swatchTile(parent: Instance, color: Color3, z: number, finish: string?)
	local sw = frame(parent, { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = color, ZIndex = z })
	Instance.new("UIAspectRatioConstraint").Parent = sw
	Kit.Corner(sw, 14)
	Kit.Stroke(sw, C.Ink, 3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	if finish == "Matte" then
		g.Color = ColorSequence.new(Kit.Shade(color, 0.9), Kit.Shade(color, 0.82))
	elseif finish == "Metallic" then
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Kit.Shade(color, 1.35)), ColorSequenceKeypoint.new(0.45, color), ColorSequenceKeypoint.new(0.55, Kit.Shade(color, 1.25)), ColorSequenceKeypoint.new(1, Kit.Shade(color, 0.7)) })
	elseif finish == "Chrome" then
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.48, Kit.Shade(color, 1.5)), ColorSequenceKeypoint.new(0.52, Kit.Shade(color, 0.55)), ColorSequenceKeypoint.new(1, Kit.Shade(color, 1.2)) })
	elseif finish == "Neon" then
		g.Color = ColorSequence.new(Kit.Shade(color, 1.5), color)
		local glow = Kit.Stroke(sw, Kit.Shade(color, 1.5), 6)
		glow.Transparency = 0.2
	elseif finish == "Ghost" then
		sw.BackgroundTransparency = 0.55
		g.Color = ColorSequence.new(Kit.Shade(color, 1.4), color)
	else
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Kit.Shade(color, 1.25)), ColorSequenceKeypoint.new(0.5, Kit.Shade(color, 1.08)), ColorSequenceKeypoint.new(0.52, color), ColorSequenceKeypoint.new(1, Kit.Shade(color, 0.85)) })
	end
	g.Parent = sw
	-- a little glossy highlight so it reads as paint, not a flat square
	local hl = frame(sw, { Size = UDim2.new(0.5, 0, 0, 4), Position = UDim2.fromOffset(7, 6), BackgroundTransparency = 0.45, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 1 })
	Kit.Corner(hl, 2)
	return sw
end

local TRAIL_COLORS = {
	Flame = { Color3.fromRGB(150, 230, 255), Color3.fromRGB(60, 120, 255) }, Fire = { Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 80, 20) },
	Toxic = { Color3.fromRGB(220, 255, 90), Color3.fromRGB(60, 200, 40) }, Leaves = { Color3.fromRGB(120, 210, 70), Color3.fromRGB(230, 170, 50) },
	Sparkle = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 170, 255) }, Ghost = { Color3.fromRGB(190, 120, 255), Color3.fromRGB(60, 30, 120) },
	Lightning = { Color3.fromRGB(230, 250, 255), Color3.fromRGB(80, 160, 255) }, Comet = { Color3.fromRGB(255, 250, 210), Color3.fromRGB(255, 150, 40) },
	Spray = { Color3.fromRGB(240, 252, 255), Color3.fromRGB(90, 180, 235) },
}

local function darkPlate(holder: Instance, z: number): Frame
	local base = frame(holder, { Size = UDim2.fromScale(0.9, 0.86), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(14, 16, 28), ZIndex = z })
	Kit.Corner(base, 10)
	return base
end

local function tileVisual(holder: Frame, slot: string, item, z: number)
	local id = item.Id
	if Rides.ColorSlots[slot] then
		local col = item.Color
		if id == "Stock" then
			if slot == "WrapColor" then col = Rides.StockWrap
			elseif slot == "GlowColor" then col = Rides.StockGlow
			elseif slot == "RimColor" then col = Color3.fromRGB(201, 166, 107)
			else
				local hex = stockHex(slot == "Paint2" and "StockS" or "StockP")
				col = hex and Color3.fromHex(hex) or nil
			end
		end
		local sw = swatchTile(holder, col or Color3.new(1, 1, 1), z)
		if slot == "GlowColor" then
			local glow = Kit.Stroke(sw, col or Color3.new(1, 1, 1), 5)
			glow.Transparency = 0.35
		end
		return
	end
	if slot == "Finish" then
		swatchTile(holder, paintColor(), z, id)
		return
	end
	if slot == "Lift" then
		local lift = item.Lift or 0
		local body = frame(holder, { Size = UDim2.fromScale(0.74, 0.28), Position = UDim2.new(0.5, 0, 0.46, -lift * 9), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = paintColor(), ZIndex = z + 1 })
		Kit.Corner(body, 6)
		Kit.Stroke(body, C.Ink, 3)
		for _, x in ipairs({ 0.27, 0.73 }) do
			local w = frame(holder, { Size = UDim2.fromScale(0.3, 0.3), Position = UDim2.fromScale(x, 0.76), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = C.Ink, ZIndex = z + 2 })
			Instance.new("UIAspectRatioConstraint").Parent = w
			Kit.Corner(w, 40)
			Kit.Stroke(w, C.Grey, 2)
			if lift > 0 then
				local strut = frame(holder, { Size = UDim2.new(0, 6, 0, lift * 9 + 8), Position = UDim2.new(x, 0, 0.64, 0), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 0, BackgroundColor3 = C.Red, ZIndex = z })
				Kit.Corner(strut, 3)
			end
		end
		return
	end
	if slot == "Glow" then
		local base = darkPlate(holder, z)
		if id ~= "None" then
			local col = Rides.Color(S.Style.GlowColor) or Rides.StockGlow
			local car = frame(base, { Size = UDim2.fromScale(0.7, 0.24), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(40, 44, 56), ZIndex = z + 2 })
			Kit.Corner(car, 5)
			local bar = frame(base, { Size = UDim2.fromScale(0.8, 0.14), Position = UDim2.fromScale(0.5, 0.64), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = col, ZIndex = z + 1 })
			Kit.Corner(bar, 4)
			local glow = Kit.Stroke(bar, col, 8)
			glow.Transparency = 0.45
			local g = Instance.new("UIGradient")
			if id == "Rainbow" then
				g.Color = RAINBOW_SEQ
				bar.BackgroundColor3 = Color3.new(1, 1, 1)
			elseif id == "Police" then
				g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 40)), ColorSequenceKeypoint.new(0.49, Color3.fromRGB(255, 40, 40)), ColorSequenceKeypoint.new(0.51, Color3.fromRGB(40, 90, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 90, 255)) })
				bar.BackgroundColor3 = Color3.new(1, 1, 1)
			elseif id == "Pulse" or id == "Chase" then
				g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.7) })
			end
			g.Parent = bar
		else
			pixel(base, "OFF", { Size = UDim2.fromScale(0.8, 0.3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 2, MaxSize = 14, Color = C.Muted })
		end
		return
	end
	if slot == "Trail" then
		local cols = TRAIL_COLORS[id] or TRAIL_COLORS.Flame
		local base = darkPlate(holder, z)
		local streak = frame(base, { Size = UDim2.fromScale(0.86, 0.3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 1 })
		Kit.Corner(streak, 8)
		local g = Instance.new("UIGradient")
		g.Color = id == "Rainbow" and RAINBOW_SEQ or ColorSequence.new(cols[1], cols[2])
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = streak
		for i = 1, 5 do
			frame(base, { Size = UDim2.fromOffset(5, 5), Position = UDim2.fromScale(0.2 + i * 0.13, 0.25 + ((i * 37) % 50) / 100), BackgroundTransparency = 0, BackgroundColor3 = cols[1], ZIndex = z + 2, Rotation = 45 })
		end
		return
	end
	if slot == "Horn" then
		local base = darkPlate(holder, z)
		Kit.Icon(base, "Alert", { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 1 })
		pixel(base, item.Say or "BEEP", { Size = UDim2.new(0.94, 0, 0, 9), Position = UDim2.fromScale(0.5, 0.84), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 2, MaxSize = 9, Color = C.YellowHi })
		return
	end
	if slot == "Wrap" and id == "None" then
		swatchTile(holder, paintColor(), z)
		return
	end
	-- 3D parts: the real kit model in a little viewport (FACTORY shows the body's own bits)
	local m = (id == "Stock") and stockModel(slot) or kitModel(slot, id)
	if m then
		Rides.Paint(m, S.Style, stockHex("StockP"), stockHex("StockS"))
		viewport(holder, m, VIEW_DIR[slot] or Vector3.new(0.6, 0.4, -1), z + 1, slot == "Wrap" and paintColor() or nil)
	else
		Kit.Icon(holder, "Jeep", { Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 1, Vehicle = S.Body })
	end
end

--------------------------------------------------------------------------------
-- state helpers
--------------------------------------------------------------------------------
local refreshAll, refreshStatus, refreshFooter, refreshStats, buildGrid

local function rowSlot(): string?
	local t = tabDef(S.Tab)
	if not t.Rows then return nil end
	return t.Rows[S.Row] and t.Rows[S.Row][1] or t.Rows[1][1]
end

local function setShot()
	local slot = rowSlot() or "Upgrade"
	local shot = SHOTS[slot] or SHOTS.Paint
	S.Shot = shot
	-- focused shots bring the car back round to face the camera's frame
	if shot[4] ~= "Center" or (S.Tab ~= "Paint" and S.Tab ~= "Upgrade") then
		local tau = math.pi * 2
		local off = (shot[5] and math.pi or 0) + (S.ViewYaw or 0)
		S.CarYawTarget = math.floor((S.CarYawTarget - off) / tau + 0.5) * tau + off
	end
	if S.Model then RideFx.Trail(S.Model, S.Tab == "Boost") end
	if S.Grade then
		-- underglow reads best in the dark
		local dark = S.Tab == "Glow"
		TweenService:Create(S.Grade, TweenInfo.new(0.5), { Brightness = dark and -0.3 or 0, Contrast = dark and 0.25 or 0.08, Saturation = dark and 0.2 or 0.12 }):Play()
	end
end

-- the camera never shoots into the garage, a fence or a tree: rays only count solid, visible, colliding parts
local blockParams = RaycastParams.new()
blockParams.FilterType = Enum.RaycastFilterType.Exclude
blockParams.RespectCanCollide = true
local function clearance(from: Vector3, dir: Vector3, dist: number): number
	local ignore = {}
	for _, x in ipairs({ S.Model, S.Stand, player.Character, Workspace:FindFirstChild("ActiveVehicles"), Workspace:FindFirstChild("DinoPickups") } :: { any }) do
		if x then table.insert(ignore, x) end
	end
	blockParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(from, dir * dist, blockParams)
	if hit and hit.Instance.Transparency < 0.5 then return hit.Distance end
	return dist
end

local function shotDir(yawDeg: number, pitchDeg: number): Vector3
	return S.Stage.Rotation * (CFrame.Angles(0, math.rad(yawDeg) + S.ViewYaw, 0) * CFrame.Angles(-math.rad(pitchDeg), 0, 0) * Vector3.new(0, 0, -1))
end

-- the most open side of the driveway (out of the bay preferred): every shot is turned to face it
local function openYaw(): number
	local c = S.Stage.Position + Vector3.new(0, 4, 0)
	local best, bestScore = 0, -math.huge
	for i = 0, 7 do
		local yaw = i * 45
		local d = yaw > 180 and yaw - 360 or yaw
		local free = clearance(c, S.Stage.Rotation * (CFrame.Angles(0, math.rad(d), 0) * Vector3.new(0, 0, -1)), 40)
		local score = free - math.abs(d) / 45 * 2.5
		if score > bestScore then best, bestScore = d, score end
	end
	return math.rad(best)
end

-- a clear camera line for this shot: nudge the angle round, then lift it, before ever pulling in
local function solveShot(f: Vector3, shot, dist: number): (Vector3, number)
	local bestDir, bestClear = nil, -1
	for _, up in ipairs({ 0, 12, 24, 38 }) do
		for _, dy in ipairs({ 0, 20, -20, 40, -40, 65, -65 }) do
			local dir = shotDir(shot[1] + dy, math.min(shot[2] + up, 62))
			local c = clearance(f, dir, dist + 2)
			if c >= dist + 1.9 then return dir, dist end
			if c > bestClear then bestDir, bestClear = dir, c end
		end
	end
	return bestDir :: Vector3, math.max(dist * 0.8, math.min(dist, bestClear - 1.5))
end

local function carWorld(local3: Vector3): Vector3
	return (S.Stage * CFrame.Angles(0, S.CarYaw, 0)):PointToWorldSpace(local3)
end

local function fx(slot: string, id: string)
	if not S.Root then return end
	local pos = S.Root.Position
	if Rides.ColorSlots[slot] then
		local col = Rides.Color(id) or Color3.new(1, 1, 1)
		CineKit.Sparkle(pos + Vector3.new(0, 2, 0), col, 1.2)
		Audio.Sting("Spray", 0.5)
	elseif slot == "Horn" then
		RideFx.HonkAt(S.Model, id)
	elseif slot == "Finish" then
		CineKit.Sparkle(pos + Vector3.new(0, 3, 0), Color3.new(1, 1, 1), 1.4)
	elseif slot ~= "Trail" and slot ~= "Glow" then
		DinosaurVFX.Cubes(carWorld(focusPoint((SHOTS[slot] or SHOTS.Paint)[4])), 14, { Color3.new(1, 1, 1), C.YellowHi, C.Grey }, 0.3, 14, 0.7)
		DinosaurVFX.Shake(0.25, 0.2)
		Audio.Sting("Clunk", 0.5)
	end
end

local function pick(slot: string, id: string)
	if not S then return end
	S.Sel = { slot, id }
	if S.Style[slot] == id then
		if slot == "Horn" then RideFx.HonkAt(S.Model, id) end
		refreshFooter()
		return
	end
	S.Style[slot] = id
	buildPreview()
	fx(slot, id)
	refreshStatus()
	refreshStats()
	refreshFooter()
end

--------------------------------------------------------------------------------
-- tiles (built once per row; only their status updates on a pick, so phones don't hitch)
--------------------------------------------------------------------------------
local function buildTile(parent: Instance, slot: string, item, order: number)
	local outer, content = Kit.Card(parent, { Size = UDim2.fromOffset(96, 120), Color = "Card", ZIndex = 32 })
	outer.LayoutOrder = order
	outer.Name = item.Id
	local vis = frame(content, { Size = UDim2.new(1, -12, 0, 66), Position = UDim2.fromOffset(6, 6), ZIndex = 34, ClipsDescendants = true })
	tileVisual(vis, slot, item, 34)
	local veil = frame(vis, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.3, BackgroundColor3 = C.Ink, ZIndex = 42, Visible = false })
	Kit.Corner(veil, 10)
	Kit.Icon(veil, "Lock", { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 43 })
	pixel(content, item.Name, { Size = UDim2.new(1, -6, 0, 11), Position = UDim2.new(0.5, 0, 0, 74), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 36, MaxSize = 11 })
	-- the price band (rarity-band style)
	local band = frame(content, { Size = UDim2.new(1, -10, 0, 20), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 0, BackgroundColor3 = tierColor(item.Price or 0), ZIndex = 35 })
	Kit.Corner(band, 8)
	Kit.Stroke(band, C.Ink, 2)
	local coin = Kit.Icon(band, "Coin", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0, -4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 37 })
	local label = pixel(band, "", { Size = UDim2.new(1, -24, 0, 12), Position = UDim2.new(0.5, 8, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 37, MaxSize = 12 })
	-- selection ring + tick
	local ring = frame(outer, { Size = UDim2.new(1, 6, 1, 10), Position = UDim2.fromOffset(-3, -3), ZIndex = 45, Visible = false })
	Kit.Corner(ring, 15)
	local ringStroke = Kit.Stroke(ring, C.LimeHi, 4)
	local tick = frame(outer, { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, 6, 0, -8), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 0, BackgroundColor3 = C.Lime, ZIndex = 46, Visible = false })
	Kit.Corner(tick, 13)
	Kit.Stroke(tick, C.Ink, 3)
	Kit.Glyph(tick, "Check", { Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 47 })
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 50
	hit.Selectable = true
	hit.Parent = outer
	local sc = Instance.new("UIScale")
	sc.Parent = outer
	hit.MouseEnter:Connect(function() Kit.Tween(sc, 0.12, { Scale = 1.05 }, Enum.EasingStyle.Back) end)
	hit.MouseLeave:Connect(function() Kit.Tween(sc, 0.12, { Scale = 1 }) end)
	hit.SelectionGained:Connect(function() Kit.Tween(sc, 0.12, { Scale = 1.05 }, Enum.EasingStyle.Back) end)
	hit.SelectionLost:Connect(function() Kit.Tween(sc, 0.12, { Scale = 1 }) end)
	hit.Activated:Connect(function()
		Kit.Sound("Click", 0.45)
		Kit.Punch(outer, 0.08)
		pick(slot, item.Id)
	end)
	S.Tiles[item.Id] = { Slot = slot, Item = item, Veil = veil, Band = band, Coin = coin, Label = label, Ring = ring, RingStroke = ringStroke, Tick = tick, Hit = hit }
	return hit
end

refreshStatus = function()
	if not S then return end
	local p = Net.Profile
	for id, t in pairs(S.Tiles) do
		local item = t.Item
		local owned = Rides.Owns(p, t.Slot, id)
		local lock = (not owned) and Rides.LockReason(p, item) or nil
		local on = S.Style[t.Slot] == id
		t.Veil.Visible = lock ~= nil
		t.Ring.Visible = on
		t.RingStroke.Color = owned and C.LimeHi or C.YellowHi
		t.Tick.Visible = on and owned
		local word, col, coin
		if on and not owned then word, col = "TRYING", C.YellowHi
		elseif on then word, col = "ON RIDE", C.LimeHi
		elseif owned then word, col = (item.Price or 0) > 0 and "OWNED" or "FACTORY", C.Muted
		elseif lock then word, col = "LOCKED", C.RedHi
		else word, col, coin = Config.FormatNumber(item.Price or 0), C.YellowHi, true end
		t.Coin.Visible = coin == true
		Kit.SetText(t.Label, word)
		Kit.SetTextColor(t.Label, col)
		t.Label.Position = UDim2.new(0.5, coin and 8 or 0, 0.5, 0)
	end
end

--------------------------------------------------------------------------------
-- UPGRADE tab: rover level, bodies, roof rack, plating (all rover upgrades live here now)
--------------------------------------------------------------------------------
local function costChips(parent: Instance, cost, x: number, y: number, z: number)
	local p = Net.Profile or {}
	local cx = x
	local function chip(icon: string, label: string, ok: boolean)
		local w = #label * 8 + 40
		local f = frame(parent, { Size = UDim2.fromOffset(w, 22), Position = UDim2.fromOffset(cx, y), BackgroundTransparency = 0.2, BackgroundColor3 = ok and C.InkSoft or C.RedLo, ZIndex = z })
		Kit.Corner(f, 11)
		Kit.Stroke(f, C.Ink, 2)
		Kit.Icon(f, icon, { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, -4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 2 })
		pixel(f, label, { Size = UDim2.new(1, -26, 0, 11), Position = UDim2.new(0, 22, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = z + 2, MaxSize = 11, Color = ok and C.Cream or C.RedHi })
		cx += w + 4
	end
	if (cost.Coins or 0) > 0 then chip("Coin", Config.FormatNumber(cost.Coins), (p.Coins or 0) >= cost.Coins) end
	for mat, n in pairs(cost.Mats or {}) do
		local have = (p.Materials and p.Materials[mat]) or 0
		chip("Mat_" .. mat, have .. "/" .. n, have >= n)
	end
end

local function canAfford(cost): boolean
	local p = Net.Profile
	if not p then return false end
	if (cost.Coins or 0) > (p.Coins or 0) then return false end
	for mat, n in pairs(cost.Mats or {}) do if ((p.Materials or {})[mat] or 0) < n then return false end end
	return true
end

local function celebrate(msg: string, _icon: string?)
	notice(msg, C.LimeHi)
	Audio.Sting("Purchase", 0.7)
	if S and S.Root then CineKit.Burst(S.Root.Position + Vector3.new(0, 3, 0), 0.9, { C.YellowHi, C.LimeHi, Color3.new(1, 1, 1) }) end
end

local function upgradeCard(list: Instance, order: number, icon: string, title: string, sub: string, opts)
	local card, cc = Kit.Card(list, { Size = UDim2.new(1, -8, 0, 92), Color = opts.Highlight and "Forest" or "Card", Border = opts.Highlight and C.LimeHi or nil, ZIndex = 32 })
	card.LayoutOrder = order
	Kit.Icon(cc, icon, { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0, 2, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 35, Vehicle = opts.Vehicle, Rotation = -6 })
	text(cc, title, { Size = UDim2.new(1, -240, 0, 20), Position = UDim2.fromOffset(76, 8), Align = Enum.TextXAlignment.Left, ZIndex = 35, MaxSize = 20, Color = C.YellowHi })
	pixel(cc, sub, { Size = UDim2.new(1, -240, 0, 11), Position = UDim2.fromOffset(76, 33), Align = Enum.TextXAlignment.Left, ZIndex = 35, MaxSize = 11, Color = C.Muted })
	if opts.Cost then costChips(cc, opts.Cost, 76, 52, 35) end
	if opts.Level then
		local set = Kit.Segments(cc, Config.MaxLevel, { Size = UDim2.fromOffset(150, 12), Position = UDim2.fromOffset(76, 56), ZIndex = 35 })
		set(opts.Level / Config.MaxLevel, C.Lime)
	end
	if opts.Button then
		local b = opts.Button
		Kit.Button(cc, { Text = b.Text, Icon = b.Icon, IconSize = 0.85, TextLeft = b.Icon and 0.3 or 0.06, Color = b.Color or "Lime", Disabled = b.Disabled, Shine = b.Shine, Size = UDim2.fromOffset(150, 52), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 36, MaxText = 18, OnClick = b.OnClick })
	elseif opts.Tag then
		pixel(cc, opts.Tag, { Size = UDim2.fromOffset(140, 11), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 35, MaxSize = 11, Color = opts.TagColor or C.LimeHi })
	end
end

local function buildUpgrades()
	local list = S.List
	clear(list)
	local p = Net.Profile
	if not p then return end
	local g = p.Gear or {}
	local order = 0
	local function nextOrder() order += 1 return order end
	-- 1. levels (for the body you drive)
	local cur = Config.Vehicles[g.Vehicle] or Config.Vehicles.RookieRanger
	local lvl = g.RoverLvl or 1
	local hpNow = math.floor(Rides.Stats(g.Vehicle, Rides.StyleFor(p, g.Vehicle)).HP * (1 + Config.LevelBonus * (lvl - 1)) * (g.Plating and Config.Plating.HPMult or 1))
	if lvl < Config.MaxLevel then
		local price = Config.LevelPrice(cur.Order, lvl)
		local free = not (p.Flags and p.Flags.FreeUpgradeUsed) and ((p.Stats and p.Stats.Runs) or 0) >= 1
		local ok = free or (p.Coins or 0) >= price
		upgradeCard(list, nextOrder(), "Shield", cur.Name .. "  LV " .. lvl, "+8% ARMOR A LEVEL  -  ARMOR " .. hpNow, { Level = lvl, Highlight = true, Button = {
			Text = free and "FREE!" or Config.FormatNumber(price), Icon = "Coin", Color = ok and "Lime" or "Grey", Disabled = not ok, Shine = ok,
			OnClick = function()
				local res = Net.Ask("LevelUp", { What = "Rover" })
				if res and res.Ok then celebrate("ROVER LEVEL " .. tostring(res.Level) .. "!", "Shield") else notice((res and res.Err) or "CAN'T DO THAT", C.RedHi) end
			end,
		} })
	else
		upgradeCard(list, nextOrder(), "Shield", cur.Name .. "  LV " .. lvl, "MAX LEVEL  -  ARMOR " .. hpNow, { Level = lvl, Highlight = true, Tag = "MAXED!", TagColor = C.YellowHi })
	end
	-- 2. bodies
	for _, n in ipairs(Config.VehicleOrder) do
		local d = Config.Vehicles[n]
		local owned = g.Vehicles and g.Vehicles[n]
		local sub = d.HP .. " ARMOR  -  " .. d.Cruise .. " SPEED  -  " .. (d.Darts or 8) .. " DARTS"
		if g.Vehicle == n then
			upgradeCard(list, nextOrder(), "Jeep", d.Name, sub, { Vehicle = n, Tag = "YOUR RIDE" })
		elseif owned then
			upgradeCard(list, nextOrder(), "Jeep", d.Name, sub, { Vehicle = n, Button = { Text = "DRIVE THIS", Color = "Blue", OnClick = function()
				local res = Net.Ask("EquipGear", { What = "Rover", Id = n })
				if res and res.Ok then
					notice(d.Name .. " IS YOUR RIDE", C.BlueHi)
					RideStudio.LoadBody(n)
				end
			end } })
		elseif Config.PrevTier(Config.VehicleOrder, n) and not (g.Vehicles and g.Vehicles[Config.PrevTier(Config.VehicleOrder, n) :: string]) then
			-- bodies unlock in order
			local prev = Config.Vehicles[Config.PrevTier(Config.VehicleOrder, n) :: string]
			upgradeCard(list, nextOrder(), "Jeep", d.Name, "BUILD THE " .. string.upper(prev.Name) .. " FIRST", { Vehicle = n, Tag = "LOCKED", TagColor = C.Muted })
		else
			local cost = { Coins = d.Price or 0, Mats = d.Mats }
			local can = canAfford(cost)
			upgradeCard(list, nextOrder(), "Jeep", d.Name, d.Tier, { Vehicle = n, Cost = cost, Button = { Text = d.Mats and "CRAFT" or "BUY", Icon = "Hammer", Color = can and "Orange" or "Grey", Disabled = not can, Shine = can, OnClick = function()
				local res = Net.Ask("Craft", { What = "Rover", Id = n })
				if res and res.Ok then
					celebrate("NEW BODY: " .. d.Name .. "!", "Jeep")
					RideStudio.LoadBody(n)
				else
					notice((res and res.Err) or "CAN'T DO THAT", C.RedHi)
				end
			end } })
		end
	end
	-- 3. roof rack
	local rack = Config.Rack.Base + (g.Rack or 0)
	if rack < Config.Rack.Max then
		local cost = { Coins = Config.Rack.Prices[(g.Rack or 0) + 1] }
		local can = canAfford(cost)
		upgradeCard(list, nextOrder(), "Rack", "ROOF RACK", rack .. " / " .. Config.Rack.Max .. " EGGS PER RUN", { Cost = cost, Button = { Text = "+1 SLOT", Icon = "Egg", Color = can and "Lime" or "Grey", Disabled = not can, OnClick = function()
			local res = Net.Ask("BuyBase", { What = "Rack" })
			if res and res.Ok then celebrate("BIGGER ROOF RACK!", "Egg") else notice((res and res.Err) or "CAN'T DO THAT", C.RedHi) end
		end } })
	else
		upgradeCard(list, nextOrder(), "Rack", "ROOF RACK", rack .. " / " .. Config.Rack.Max .. " EGGS PER RUN", { Tag = "MAXED!", TagColor = C.YellowHi })
	end
	-- 4. plating
	local pl = Config.Plating
	if g.Plating then
		upgradeCard(list, nextOrder(), "Shield", pl.Name, pl.Perk, { Tag = "FITTED" })
	else
		local can = canAfford(pl.Craft)
		upgradeCard(list, nextOrder(), "Shield", pl.Name, pl.Perk, { Cost = pl.Craft, Button = { Text = "CRAFT", Icon = "Hammer", Color = can and "Orange" or "Grey", Disabled = not can, OnClick = function()
			local res = Net.Ask("Craft", { What = "Plating", Id = "Plating" })
			if res and res.Ok then celebrate(pl.Name .. " FITTED!", "Shield") else notice((res and res.Err) or "CAN'T DO THAT", C.RedHi) end
		end } })
	end
end

--------------------------------------------------------------------------------
-- grid / chips / footer / stats
--------------------------------------------------------------------------------
buildGrid = function()
	if not S then return end
	local up = S.Tab == "Upgrade"
	S.Grid.Visible = not up
	S.List.Visible = up
	S.Footer.Visible = not up
	S.RowBar.Visible = not up
	clear(S.RowBar)
	for id, b in pairs(S.TabButtons) do Kit.SetPanelColor(b, id == S.Tab and "Yellow" or "Slate") end
	if up then
		S.Tiles = {}
		buildUpgrades()
		return
	end
	-- row chips
	local t = tabDef(S.Tab)
	local x = 0
	for i, r in ipairs(t.Rows) do
		local w = #r[2] * 9 + 34
		Kit.Button(S.RowBar, { Text = r[2], Color = i == S.Row and "Purple" or "Slate", Size = UDim2.fromOffset(w, 32), Position = UDim2.fromOffset(x, 0), ZIndex = 34, Lip = 3, Radius = 10, MaxText = 15, OnClick = function()
			if S.Row == i then return end
			S.Row = i
			S.Sel = nil
			setShot()
			buildGrid()
			refreshFooter()
		end })
		x += w + 6
	end
	-- tiles
	clear(S.Grid)
	S.Tiles = {}
	local slot = rowSlot() :: string
	local first, sel
	for i, item in ipairs(Rides.List(slot)) do
		local hit = buildTile(S.Grid, slot, item, i)
		first = first or hit
		if S.Style[slot] == item.Id then sel = hit end
	end
	S.Grid.CanvasPosition = Vector2.zero
	refreshStatus()
	if Kit.Gamepad() then game:GetService("GuiService").SelectedObject = sel or first end
end

refreshFooter = function()
	if not S or S.Tab == "Upgrade" then return end
	local slot = rowSlot() :: string
	local id = (S.Sel and S.Sel[1] == slot) and S.Sel[2] or S.Style[slot]
	local item = Rides.Item(slot, id)
	local p = Net.Profile
	clear(S.FootInfo)
	S.BuyBtn.Visible = false
	S.OnTag.Visible = false
	if not item then return end
	text(S.FootInfo, item.Name, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 2), Align = Enum.TextXAlignment.Left, ZIndex = 36, MaxSize = 22, Color = C.YellowHi })
	pixel(S.FootInfo, item.Desc or "", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 27), Align = Enum.TextXAlignment.Left, ZIndex = 36, MaxSize = 12, Color = C.Muted })
	local cx = 0
	for _, chip in ipairs(statChips(item)) do
		local w = #chip[1] * 7 + 16
		local f = frame(S.FootInfo, { Size = UDim2.fromOffset(w, 18), Position = UDim2.fromOffset(cx, 42), BackgroundTransparency = 0, BackgroundColor3 = chip[2] == "Up" and C.LimeLo or C.RedLo, ZIndex = 36 })
		Kit.Corner(f, 9)
		Kit.Stroke(f, C.Ink, 2)
		pixel(f, chip[1], { Size = UDim2.new(1, -8, 0, 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 37, MaxSize = 10 })
		cx += w + 4
	end
	local owned = Rides.Owns(p, slot, id)
	if owned then
		S.OnTag.Visible = S.Style[slot] == id
		return
	end
	local lock = Rides.LockReason(p, item)
	local price = item.Price or 0
	local can = not lock and (p and p.Coins or 0) >= price
	S.BuyBtn.Visible = true
	Kit.SetText(S.BuyLabel, lock or Config.FormatNumber(price))
	Kit.SetPanelColor(S.BuyBtn, lock and "Grey" or (can and "Lime" or "Orange"))
	S.BuyState = { Slot = slot, Id = id, Lock = lock, Can = can }
end

local STAT_ROWS = {
	{ "SPEED", "Cruise", 60, function(v) return tostring(math.floor(v + 0.5)) end },
	{ "BOOST", "Boost", 90, function(v) return tostring(math.floor(v + 0.5)) end },
	{ "ARMOR", "HP", 600, function(v) return tostring(math.floor(v + 0.5)) end },
	{ "GRIP", "Grip", 1.4, function(v) return math.floor(v * 100 + 0.5) .. "%" end },
}

local function fullStats(style)
	local s = Rides.Stats(S.Body, style)
	local g = (Net.Profile and Net.Profile.Gear) or {}
	if g.Vehicle == S.Body then
		s.HP = math.floor(s.HP * (1 + Config.LevelBonus * ((g.RoverLvl or 1) - 1)) * (g.Plating and Config.Plating.HPMult or 1))
	elseif g.Plating then
		s.HP = math.floor(s.HP * Config.Plating.HPMult)
	end
	return s
end

refreshStats = function()
	if not S then return end
	local now = fullStats(S.Style)
	local was = fullStats(S.Saved)
	for i, row in ipairs(STAT_ROWS) do
		local r = S.StatRows[i]
		local v, w = now[row[2]], was[row[2]]
		r.Set(math.clamp(v / row[3], 0.05, 1), v > w + 1e-6 and C.Lime or (v < w - 1e-6 and C.Red or C.Blue))
		Kit.SetText(r.Value, row[4](v))
		local d = v - w
		local ds = ""
		if math.abs(d) > 1e-6 then
			ds = row[2] == "Grip" and string.format("%+d%%", math.floor(d * 100 + (d > 0 and 0.5 or -0.5))) or string.format("%+d", math.floor(d + (d > 0 and 0.5 or -0.5)))
		end
		Kit.SetText(r.Delta, ds)
		Kit.SetTextColor(r.Delta, d > 0 and C.LimeHi or C.RedHi)
	end
	Kit.SetText(S.Coins, Config.FormatNumber((Net.Profile and Net.Profile.Coins) or 0))
end

refreshAll = function()
	if not S then return end
	if S.Tab == "Upgrade" then buildUpgrades() else refreshStatus() end
	refreshFooter()
	refreshStats()
end

local function buy()
	local b = S and S.BuyState
	if not b then return end
	if b.Lock then notice(b.Lock .. " TO UNLOCK", C.RedHi) return end
	if not b.Can then notice("NOT ENOUGH COINS", C.RedHi) return end
	local res = Net.Ask("RideBuy", { Slot = b.Slot, Id = b.Id })
	if res and res.Ok then
		local item = Rides.Item(b.Slot, b.Id)
		celebrate((item and item.Name or "PART") .. " IS YOURS!")
		task.delay(0.15, refreshAll)
	else
		notice((res and res.Err) or "CAN'T BUY THAT", C.RedHi)
	end
end

-- dice: a random build from what you own (kids love it; car people use it for ideas)
local function surprise()
	local p = Net.Profile
	for _, slot in ipairs(Rides.Slots) do
		if slot == "Horn" then continue end
		local owned = {}
		for _, it in ipairs(Rides.List(slot)) do if Rides.Owns(p, slot, it.Id) then table.insert(owned, it.Id) end end
		if #owned > 0 then S.Style[slot] = owned[math.random(1, #owned)] end
	end
	S.Sel = nil
	buildPreview()
	if S.Root then CineKit.Burst(S.Root.Position + Vector3.new(0, 3, 0), 1, { paintColor(), Rides.Color(S.Style.Paint2) or C.Lime, Color3.new(1, 1, 1) }) end
	if S.Tab ~= "Upgrade" then buildGrid() end
	refreshFooter()
	refreshStats()
end

local function saveCurrent(): boolean
	local res = Net.Ask("RideSave", { Body = S.Body, Style = S.Style })
	if res and res.Ok and res.Style then
		local changed = false
		for k, v in pairs(res.Style) do if S.Saved[k] ~= v then changed = true end end
		S.Saved = table.clone(res.Style)
		return changed
	end
	return false
end

local function loadBody(name: string)
	local list = ownedBodies()
	local i = table.find(list, name) or 1
	S.Body = list[i] or name
	S.Style = Rides.StyleFor(Net.Profile, S.Body)
	S.Saved = table.clone(S.Style)
	S.Sel = nil
	-- the front right road wheel: its rim / tyre thumbnails and the wheel shot (template space, before any lift)
	S.WheelName, S.WheelLP = nil, nil
	local tpl = Templates:FindFirstChild(S.Body)
	if tpl and tpl.PrimaryPart then
		for _, w in ipairs(tpl:GetDescendants()) do
			if w:IsA("Model") and w.Name:match("^Wheel%u") then
				local hub = w:FindFirstChild("Hub", true) :: BasePart?
				if hub then
					local lp = tpl.PrimaryPart.CFrame:PointToObjectSpace(hub.Position)
					if lp.X > 0 and (not S.WheelLP or lp.Z < S.WheelLP.Z) then S.WheelName, S.WheelLP = w.Name, lp end
				end
			end
		end
	end
	buildPreview()
	local info = Config.Vehicles[S.Body]
	Kit.SetText(S.BodyName, info and info.Name or S.Body)
	Kit.SetText(S.BodyTier, (info and info.Tier or "") .. (#list > 1 and ("   " .. i .. " / " .. #list) or ""))
	if S.BodyIcon then S.BodyIcon:Destroy() end
	S.BodyIcon = Kit.Icon(S.BodyCard, "Jeep", { Vehicle = S.Body, Size = UDim2.fromOffset(78, 78), Position = UDim2.new(0, 40, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 33, Rotation = -6 })
	S.Arrows.Visible = #list > 1
	buildGrid()
	refreshFooter()
	refreshStats()
end
function RideStudio.LoadBody(name: string)
	if S then
		saveCurrent()
		loadBody(name)
		if S.Root then CineKit.Burst(S.Root.Position + Vector3.new(0, 3, 0), 0.7) end
	end
end

local function switchBody(dir: number)
	local list = ownedBodies()
	if #list < 2 then return end
	local i = table.find(list, S.Body) or 1
	RideStudio.LoadBody(list[(i - 1 + dir) % #list + 1])
end

local function setTab(id: string)
	if not S or S.Tab == id then return end
	S.Tab = id
	S.Row = 1
	S.Sel = nil
	setShot()
	buildGrid()
	refreshFooter()
end

--------------------------------------------------------------------------------
-- open / close
--------------------------------------------------------------------------------
local function close()
	if not S or S.Closing then return end
	S.Closing = true
	local changed = false
	pcall(function() changed = saveCurrent() end)
	local st = S
	for _, c in ipairs(st.Conns) do c:Disconnect() end
	-- (everything hidden from the shot comes back)
	for d, was in pairs(st.Hidden or {}) do
		if d.Parent then
			if d:IsA("BasePart") then d.LocalTransparencyModifier = typeof(was) == "number" and was or 0 else (d :: any).Enabled = true end
		end
	end
	if st.Model then RideFx.Untrack(st.Model) st.Model:Destroy() end
	if st.Stand then st.Stand:Destroy() end
	if st.Grade then st.Grade:Destroy() end
	if st.Gui then st.Gui:Destroy() end
	local char = player.Character
	if char then
		for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and st.Walk then hum.WalkSpeed = st.Walk end
	end
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	Cinema.End(st.Cine)
	S = nil
	if changed then Kit.Toast("RIDE SAVED! LOOKING GOOD", "Green", "Jeep") end
end
RideStudio.Close = close

function RideStudio.IsOpen(): boolean
	return S ~= nil
end

local function buildUI()
	local touch = Kit.Platform() == "Touch"
	local gui, canvas = Kit.Screen("DinoRideStudio", 25, false)
	S.Gui = gui
	local PW = 470
	-- the shop window (right)
	local win, body, header = Kit.Window(canvas, { Title = "RIDE SHOP", Color = "Purple", Icon = "Jeep", Size = UDim2.new(0, PW, 1, -40), Position = UDim2.new(1, -10, 0.5, 12), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 30, OnClose = close })
	S.Win = win
	-- coins in the title strip
	local coinPill = frame(header, { Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -82, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 0.15, BackgroundColor3 = C.Ink, ZIndex = 38 })
	Kit.Corner(coinPill, 20)
	Kit.Icon(coinPill, "Coin", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, -10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 40, Rotation = -8 })
	S.Coins = text(coinPill, "0", { Size = UDim2.new(1, -46, 0, 24), Position = UDim2.new(0, 38, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 40, MaxSize = 24, Color = C.YellowHi })
	-- category tabs: one row of big icon tiles
	local tabRow = frame(body, { Size = UDim2.new(1, 0, 0, 56), ZIndex = 33 })
	local n = #TABS
	for i, t in ipairs(TABS) do
		local b = Kit.Button(tabRow, { Text = t.Name, Icon = t.Icon, Stack = true, IconSize = 0.62, LabelPx = 7, Color = "Slate", Size = UDim2.new(1 / n, -4, 1, -4), Position = UDim2.new((i - 1) / n, 2, 0, 0), ZIndex = 34, Lip = 4, Radius = 12, OnClick = function() setTab(t.Id) end })
		S.TabButtons[t.Id] = b
	end
	-- sub-row chips
	S.RowBar = frame(body, { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 62), ZIndex = 33 })
	-- the grid of tiles
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Tiles"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, 8, 1, -172)
	grid.Position = UDim2.fromOffset(-4, 98)
	grid.ScrollBarThickness = touch and 4 or 8
	grid.ScrollBarImageColor3 = C.LimeHi
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ZIndex = 32
	grid.Parent = body
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(96, 120)
	gl.CellPadding = UDim2.fromOffset(8, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.Parent = grid
	local gp = Instance.new("UIPadding")
	gp.PaddingTop, gp.PaddingBottom = UDim.new(0, 8), UDim.new(0, 12)
	gp.Parent = grid
	S.Grid = grid
	-- the upgrade list (same spot, full height)
	local list = Instance.new("ScrollingFrame")
	list.Name = "Upgrades"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, 8, 1, -64)
	list.Position = UDim2.fromOffset(-4, 62)
	list.ScrollBarThickness = touch and 4 or 8
	list.ScrollBarImageColor3 = C.LimeHi
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 32
	list.Visible = false
	list.Parent = body
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 10)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.Parent = list
	local lp = Instance.new("UIPadding")
	lp.PaddingTop, lp.PaddingBottom = UDim.new(0, 6), UDim.new(0, 12)
	lp.Parent = list
	S.List = list
	-- footer: what you picked, what it does, BUY
	local foot, fc = Kit.Card(body, { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 1, 2), AnchorPoint = Vector2.new(0, 1), Color = "Forest", ZIndex = 34 })
	S.Footer = foot
	S.FootInfo = frame(fc, { Size = UDim2.new(1, -176, 1, -12), Position = UDim2.fromOffset(12, 6), ZIndex = 36 })
	local buyBtn, _, buyLabel = Kit.Button(fc, { Text = "BUY", Icon = "Coin", IconSize = 0.9, TextLeft = 0.3, Color = "Lime", Shine = true, Size = UDim2.fromOffset(156, 52), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 38, MaxText = 22, OnClick = buy })
	S.BuyBtn, S.BuyLabel = buyBtn, buyLabel
	S.OnTag = frame(fc, { Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 0, BackgroundColor3 = C.LimeLo, ZIndex = 37, Visible = false })
	Kit.Corner(S.OnTag, 12)
	Kit.Stroke(S.OnTag, C.Ink, 3)
	pixel(S.OnTag, "ON YOUR RIDE", { Size = UDim2.new(1, -12, 0, 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 39, MaxSize = 10, Color = C.Cream })

	-- left side, over the car: which body, dice, the build's numbers
	local bodyCard, bc = Kit.Card(canvas, { Size = UDim2.fromOffset(340, 76), Position = UDim2.fromOffset(12, 12), Color = "Forest", Border = C.YellowHi, ZIndex = 30 })
	S.BodyCard = bc
	S.BodyName = text(bc, "", { Size = UDim2.new(1, -190, 0, 24), Position = UDim2.fromOffset(84, 12), Align = Enum.TextXAlignment.Left, ZIndex = 33, MaxSize = 24, Color = C.YellowHi })
	S.BodyTier = pixel(bc, "", { Size = UDim2.new(1, -190, 0, 12), Position = UDim2.fromOffset(84, 42), Align = Enum.TextXAlignment.Left, ZIndex = 33, MaxSize = 12, Color = C.Muted })
	local arrows = frame(bc, { Size = UDim2.fromOffset(104, 50), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 33 })
	S.Arrows = arrows
	local back = Kit.Button(arrows, { Glyph = "Chevron", Color = "Blue", Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(0, 0), ZIndex = 34, Radius = 12, Lip = 3, OnClick = function() switchBody(-1) end })
	back.Rotation = 180
	Kit.Button(arrows, { Glyph = "Chevron", Color = "Blue", Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(56, 0), ZIndex = 34, Radius = 12, Lip = 3, OnClick = function() switchBody(1) end })
	local _ = bodyCard
	local _ = surprise -- (SURPRISE ME removed 2026-10-13, user)
	local _, sc = Kit.Card(canvas, { Size = UDim2.fromOffset(280, 158), Position = UDim2.new(0, 12, 1, -12), AnchorPoint = Vector2.new(0, 1), Color = "Forest", ZIndex = 30 })
	pixel(sc, "YOUR BUILD", { Size = UDim2.fromOffset(180, 13), Position = UDim2.fromOffset(14, 10), Align = Enum.TextXAlignment.Left, ZIndex = 33, MaxSize = 13, Color = C.YellowHi })
	S.StatRows = {}
	for i, row in ipairs(STAT_ROWS) do
		local y = 32 + (i - 1) * 30
		pixel(sc, row[1], { Size = UDim2.fromOffset(64, 12), Position = UDim2.fromOffset(14, y + 2), Align = Enum.TextXAlignment.Left, ZIndex = 33, MaxSize = 12 })
		local set = Kit.Segments(sc, 10, { Size = UDim2.fromOffset(110, 15), Position = UDim2.fromOffset(78, y + 1), ZIndex = 33 })
		local value = pixel(sc, "", { Size = UDim2.fromOffset(46, 12), Position = UDim2.fromOffset(196, y + 2), Align = Enum.TextXAlignment.Left, ZIndex = 33, MaxSize = 12 })
		local delta = pixel(sc, "", { Size = UDim2.fromOffset(40, 11), Position = UDim2.fromOffset(240, y + 3), Align = Enum.TextXAlignment.Left, ZIndex = 33, MaxSize = 11 })
		S.StatRows[i] = { Set = set, Value = value, Delta = delta }
	end
	-- (no "drag to spin" line: you find it - drag, A / D, or the right stick turn the car. User 2026-10-13)
	local _t = touch
	Kit.Enter(win)
end

function RideStudio.Open(body: string?, tab: string?)
	if S or Cinema.Playing() then return end
	local p = Net.Profile
	if not p then return end
	if Drive.State.Vehicle or Drive.State.Mode ~= "None" then
		Kit.Toast("HOP OUT OF YOUR RIDE FIRST (PARK IT!)", "Orange", "Jeep")
		return
	end
	local garage = ownGarage()
	local outPt = garage and garage:FindFirstChild("RollOutPoint", true) :: BasePart?
	local pivot = garage and garage:FindFirstChild("GarageDoorPivot", true) :: BasePart?
	if not (outPt and pivot) then
		Kit.Toast("FIND YOUR GARAGE FIRST", "Orange", "Jeep")
		return
	end
	local list = ownedBodies()
	body = body or (p.Gear and p.Gear.Vehicle) or list[1]
	if not table.find(list, body) then body = list[1] end
	-- the stage: a turntable on your driveway, the car nosing out of the bay
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: any, Workspace:FindFirstChild("ActiveVehicles") :: any }
	local hit = Workspace:Raycast(outPt.Position + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	local groundY = hit and hit.Position.Y or (outPt.Position.Y - 0.2)
	local out = pivot.CFrame.LookVector
	local center = Vector3.new(outPt.Position.X, groundY, outPt.Position.Z) + out * 2
	local stage = CFrame.lookAt(center, center + out) * CFrame.new(0, 0.32, 0)

	S = {
		Body = body :: string, Style = {}, Saved = {}, Tab = tab or "Paint", Row = 1, Sel = nil,
		CarYaw = math.pi * 0.15, CarYawTarget = math.pi * 0.15, Stage = stage, Conns = {}, TabButtons = {}, Tiles = {},
		CamCF = nil, Dragging = false, Touches = {}, Zoom = 1, LastInput = os.clock(), Closing = false,
	}
	S.Cine = Cinema.Begin("DinoRideStudio")
	S.Cine.Long = true

	-- turntable + light rig
	local stand = Instance.new("Model")
	stand.Name = "DinoRideStand"
	local function sp(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?)
		local q = Instance.new("Part")
		q.Name = name
		q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch = true, false, false, false
		q.Size = size
		q.CFrame = cf
		q.Color = color
		q.Material = mat or Enum.Material.SmoothPlastic
		if shape then q.Shape = shape end
		q.Parent = stand
		return q
	end
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	sp("Turntable", Vector3.new(0.5, 24, 24), stage * CFrame.new(0, -0.07, 0) * flat, Color3.fromRGB(36, 38, 46), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
	local ring = sp("TurntableRing", Vector3.new(0.52, 25, 25), stage * CFrame.new(0, -0.1, 0) * flat, Color3.fromRGB(150, 96, 220), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	ring.Reflectance = 0.15
	local lamp = sp("StudioLamp", Vector3.new(1, 1, 1), stage * CFrame.new(0, 26, -4), Color3.new(1, 1, 1))
	lamp.Transparency = 1
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 70
	spot.Range = 40
	spot.Brightness = 1.2 -- a soft key light, not a stage blast (nothing in the garage should glow)
	spot.Color = Color3.fromRGB(255, 244, 225)
	spot.Parent = lamp
	stand.Parent = Workspace
	S.Stand = stand
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DinoRideGrade"
	grade.Contrast, grade.Saturation = 0.08, 0.12
	grade.Parent = Lighting
	S.Grade = grade

	-- you step aside: hidden locally, can't wander off
	local char = player.Character
	if char then
		S.CharParts = {}
		for _, q in ipairs(char:GetDescendants()) do if q:IsA("BasePart") then table.insert(S.CharParts, q) end end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then S.Walk = hum.WalkSpeed hum.WalkSpeed = 0 end
	end

	S.ViewYaw = 0
	S.ViewYaw = openYaw()
	S.CarYaw = S.ViewYaw + math.pi * 0.15
	S.CarYawTarget = S.CarYaw
	-- (any error building the shop used to leave you frozen with no HUD and a studio that never reopened: the
	-- Cinema token is Long, so no 40 s safety either - one close() cleans up whatever got built)
	local okUi, errUi = pcall(function()
		buildUI()
		loadBody(body :: string)
		setShot()
	end)
	if not okUi then
		warn("[RideStudio] open failed:", errUi)
		close()
		Kit.Toast("THE RIDE SHOP HICCUPED - TRY AGAIN", "Red", "Jeep")
		return
	end
	-- backup: a studio left untouched for 5 minutes closes itself
	local mine = S
	task.spawn(function()
		while S == mine do
			task.wait(10)
			if S == mine and os.clock() - mine.LastInput > 300 then close() end
		end
	end)

	-- input: drag (one finger / mouse) spins the car, pinch / wheel zooms, B / Escape leaves
	table.insert(S.Conns, UserInputService.InputBegan:Connect(function(input, processed)
		if not S then return end
		S.LastInput = os.clock() -- (any input at all: button clicks too, for the idle backup)
		if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then close() return end
		if input.KeyCode == Enum.KeyCode.ButtonL1 then local i = 1 for k, t in ipairs(TABS) do if t.Id == S.Tab then i = k end end setTab(TABS[math.max(1, i - 1)].Id) end
		if input.KeyCode == Enum.KeyCode.ButtonR1 then local i = 1 for k, t in ipairs(TABS) do if t.Id == S.Tab then i = k end end setTab(TABS[math.min(#TABS, i + 1)].Id) end
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			S.Dragging = true
			S.LastInput = os.clock()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			S.Touches[input] = true
			S.LastInput = os.clock()
		end
	end))
	table.insert(S.Conns, UserInputService.InputEnded:Connect(function(input)
		if not S then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then S.Dragging = false end
		if input.UserInputType == Enum.UserInputType.Touch then S.Touches[input] = nil end
	end))
	table.insert(S.Conns, UserInputService.InputChanged:Connect(function(input, processed)
		if not S then return end
		local touches = 0
		for _ in pairs(S.Touches) do touches += 1 end
		if input.UserInputType == Enum.UserInputType.MouseMovement and S.Dragging then
			S.CarYawTarget += input.Delta.X * 0.012
			S.LastInput = os.clock()
		elseif input.UserInputType == Enum.UserInputType.Touch and S.Touches[input] and touches == 1 then
			S.CarYawTarget += input.Delta.X * 0.014
			S.LastInput = os.clock()
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			S.Zoom = math.clamp(S.Zoom * (1 - input.Position.Z * 0.1), 0.55, 1.6)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			if math.abs(input.Position.X) > 0.2 then S.CarYawTarget += input.Position.X * 0.06 S.LastInput = os.clock() end
			if math.abs(input.Position.Y) > 0.3 then S.Zoom = math.clamp(S.Zoom * (1 - input.Position.Y * 0.03), 0.55, 1.6) end
		end
	end))
	table.insert(S.Conns, UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
		if not S or processed then return end
		if state == Enum.UserInputState.Begin or not S.PinchBase then S.PinchBase = S.Zoom end
		S.Zoom = math.clamp(S.PinchBase / math.max(0.2, scale), 0.55, 1.6)
		if state == Enum.UserInputState.End then S.PinchBase = nil end
	end))

	-- camera + turntable
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	-- nothing walks through the shot (2026-10-13, user: "things outside of customization mode get in the way of
	-- visuals"): other players, every dino (companions, yard, riders) and other rovers near the stage are hidden while
	-- the shop is open, and come back when it closes
	S.Hidden = {}
	local veilAt = 0
	table.insert(S.Conns, RunService.Heartbeat:Connect(function()
		if not S or os.clock() < veilAt then return end
		veilAt = os.clock() + 0.25
		local st = S
		local center = st.Stage.Position
		local roots = {} :: { Instance }
		for _, n in ipairs({ "DinoCampLocal", "DinoCrewRiders", "DinoExpeditionLocal", "DinoPaddockProps" }) do
			local f = Workspace:FindFirstChild(n)
			if f then table.insert(roots, f) end
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then table.insert(roots, plr.Character) end
		end
		local av = Workspace:FindFirstChild("ActiveVehicles")
		for _, v in ipairs(av and av:GetChildren() or {}) do if v ~= st.Model then table.insert(roots, v) end end
		for _, r in ipairs(roots) do
			for _, d in ipairs(r:GetDescendants()) do
				if d:IsA("BasePart") and (d.Position - center).Magnitude < 90 then
					-- (kept hidden even if something else - a dino's own fade - puts it back)
					if st.Hidden[d] == nil then st.Hidden[d] = d.LocalTransparencyModifier end
					if d.LocalTransparencyModifier < 1 then d.LocalTransparencyModifier = 1 end
				elseif (d:IsA("BillboardGui") or d:IsA("ParticleEmitter")) and d.Enabled and not st.Hidden[d] then
					local holder = d.Parent
					if holder and holder:IsA("BasePart") and (holder.Position - center).Magnitude < 90 then
						st.Hidden[d] = true
						d.Enabled = false
					end
				end
			end
		end
	end))
	table.insert(S.Conns, RunService.RenderStepped:Connect(function(dt)
		if not S or not S.Root then return end
		for _, q in ipairs(S.CharParts or {}) do q.LocalTransparencyModifier = 1 end -- the default camera likes to undo it
		-- idle spin on the overview tabs
		local idle = os.clock() - S.LastInput > 2.5 and not S.Dragging and next(S.Touches) == nil
		if idle and S.Shot[4] == "Center" then S.CarYawTarget += dt * 0.35 end
		-- A / D and the right stick (held) turn it too
		local spin = 0
		if not UserInputService:GetFocusedTextBox() then
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then spin -= 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then spin += 1 end
			for _, st in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
				if st.KeyCode == Enum.KeyCode.Thumbstick2 and math.abs(st.Position.X) > 0.2 then spin += st.Position.X end
			end
		end
		if spin ~= 0 then S.CarYawTarget += spin * dt * 2.4 S.LastInput = os.clock() end
		S.CarYaw += (S.CarYawTarget - S.CarYaw) * math.min(1, dt * 6)
		-- boost tab: the car lunges and settles like it's revving, so the trail streams out behind it
		local surge = CFrame.identity
		if S.Tab == "Boost" then
			local k = math.sin(os.clock() * 2.4)
			surge = CFrame.new(0, 0, -(k * k) * 3) * CFrame.Angles(k * k * 0.05, 0, 0)
		end
		S.Root.CFrame = S.Stage * CFrame.new(0, S.RH, 0) * CFrame.Angles(0, S.CarYaw, 0) * surge
		local turntable = S.Stand:FindFirstChild("Turntable") :: BasePart?
		if turntable then turntable.CFrame = S.Stage * CFrame.new(0, -0.07, 0) * CFrame.Angles(0, S.CarYaw, 0) * flat end
		-- frame the shot in the free space left of the shop window, whatever the screen shape
		local vs = cam.ViewportSize
		local panelX = S.Win.AbsolutePosition.X
		local free = math.clamp(panelX / math.max(1, vs.X), 0.4, 1)
		local fov = 40
		local tv = math.tan(math.rad(fov / 2))
		local th = tv * vs.X / math.max(1, vs.Y)
		local shot = S.Shot
		local center = shot[4] == "Center" or shot[4] == "Low"
		local radius = center and (math.sqrt(S.Len * S.Len + S.Wid * S.Wid) / 2) or (S.Len * shot[3] * 0.5)
		-- (2026-10-13: "the car isn't all the way visible" - more air round it, top and sides)
		local dist = math.max(radius / (th * free * 0.7), center and (S.Height * 0.75) / (tv * 0.7) or 0, 7) * S.Zoom
		local f = S.Stage:PointToWorldSpace(center and focusPoint(shot[4]) or (CFrame.Angles(0, S.CarYaw, 0) * focusPoint(shot[4])))
		-- a clear line to the car (re-checked a few times a second, not every frame, so it doesn't twitch)
		local key = tostring(shot) .. ":" .. string.format("%.2f", S.Zoom)
		local sol = S.Solve
		if not sol or sol.Key ~= key or os.clock() - sol.T > 0.4 then
			local dir, d = solveShot(f, shot, dist)
			sol = { Key = key, T = os.clock(), Dir = dir, Dist = d }
			S.Solve = sol
		end
		local dir = sol.Dir
		dist = sol.Dist
		local pos = f + dir * dist
		-- never below the driveway
		local floor = S.Stage.Position.Y + 1.2
		if pos.Y < floor then pos = Vector3.new(pos.X, floor, pos.Z) end
		local target = CFrame.lookAt(pos, f)
		-- slide sideways so the car sits in the middle of the free area (not behind the window), unless that
		-- would put the camera into something
		local slid = target * CFrame.new((1 - free) * th * dist, 0, 0)
		local toSlid = slid.Position - f
		if clearance(f, toSlid.Unit, toSlid.Magnitude + 1) >= toSlid.Magnitude + 0.9 then
			target = slid
		else
			-- no room to slide (a wall beside the lens): turn the lens instead, so the car still sits left of the window
			target = target * CFrame.Angles(0, -math.atan((1 - free) * th), 0)
		end
		S.CamCF = S.CamCF and S.CamCF:Lerp(target, math.min(1, dt * 5)) or target
		cam.CFrame = S.CamCF
		cam.FieldOfView = fov
	end))
end

function RideStudio.Start()
	local ProximityPromptService = game:GetService("ProximityPromptService")
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("CampAction") ~= "Customize" then return end
		local idx = player:GetAttribute("Plot")
		if not prompt:FindFirstAncestor("Plot" .. tostring(idx or 0)) then
			Kit.Toast("THAT'S NOT YOUR GARAGE", "Red", "Jeep")
			return
		end
		RideStudio.Open()
	end)
	-- a purchase / new coins refresh the open shop
	Net.On("Profile", function()
		if S and not S.Closing then refreshAll() end
	end)
end

return RideStudio
