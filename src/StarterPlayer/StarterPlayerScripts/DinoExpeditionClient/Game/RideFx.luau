--[[
	RideFx — the living bits of everyone's build-your-own rover, animated on every client:
	underglow modes (steady / pulse / running / rescue / rainbow), flashing sirens, the spinning radar dish,
	boost trails (fire, toxic, leaves, sparkle, ghost, rainbow, lightning, comet) and the horn.

	H / gamepad D-pad up / the HONK button honks. The garage studio uses Track / Trail / HonkAt on its preview.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game")
local Config = require(Shared:WaitForChild("Config"))
local Rides = require(Shared:WaitForChild("Rides"))
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)

local player = Players.LocalPlayer
local RideFx = {}

local tracked = (setmetatable({}, { __mode = "k" }) :: any) :: { [Model]: any }
local previews = (setmetatable({}, { __mode = "k" }) :: any) :: { [Model]: boolean }

--------------------------------------------------------------------------------
-- boost trails
--------------------------------------------------------------------------------
local TEX = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}
local rgb = Color3.fromRGB
local function seq(...) return ColorSequence.new(...) end
local function nseq(a: number, b: number) return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }) end
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 60, 60)), ColorSequenceKeypoint.new(0.2, rgb(255, 170, 40)), ColorSequenceKeypoint.new(0.4, rgb(255, 240, 60)),
	ColorSequenceKeypoint.new(0.6, rgb(80, 230, 90)), ColorSequenceKeypoint.new(0.8, rgb(60, 140, 255)), ColorSequenceKeypoint.new(1, rgb(170, 80, 255)),
})

local function emitter(at: Attachment, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "RideTrail"
	e.EmissionDirection = Enum.NormalId.Back
	e.Enabled = false
	for k, v in pairs(props) do (e :: any)[k] = v end
	e.Parent = at
	return e
end

local function ribbon(at: Attachment, color: ColorSequence, life: number, width: number, light: number?): Trail
	local a0 = Instance.new("Attachment")
	a0.Name = "RideTrailA"
	a0.Position = at.Position + Vector3.new(0, width / 2, 0)
	a0.Parent = at.Parent
	local a1 = Instance.new("Attachment")
	a1.Name = "RideTrailB"
	a1.Position = at.Position - Vector3.new(0, width / 2, 0)
	a1.Parent = at.Parent
	local t = Instance.new("Trail")
	t.Name = "RideTrail"
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = color
	t.Lifetime = life
	t.LightEmission = light or 1
	t.FaceCamera = true
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	t.Enabled = false
	t.Parent = at.Parent
	return t
end

-- every effect object for one trail point; returns the list to toggle
local function buildTrail(at: Attachment, style: string): { Instance }
	local out = {}
	local function add(x) table.insert(out, x) end
	if style == "Flame" or style == "Fire" then
		local hot = style == "Fire"
		add(emitter(at, { Texture = TEX.Fire, Rate = 70, Lifetime = NumberRange.new(0.15, 0.32), Speed = NumberRange.new(10, 16), SpreadAngle = Vector2.new(12, 12),
			Size = nseq(1.5, 0), LightEmission = 1, Color = hot and seq(rgb(255, 230, 120), rgb(255, 90, 20)) or seq(rgb(150, 230, 255), rgb(60, 120, 255)) }))
		if hot then add(emitter(at, { Texture = TEX.Smoke, Rate = 18, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(25, 25),
			Size = nseq(1, 3), Transparency = nseq(0.5, 1), Color = seq(rgb(70, 60, 60)) })) end
	elseif style == "Toxic" then
		add(emitter(at, { Texture = TEX.Fire, Rate = 60, Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(9, 14), SpreadAngle = Vector2.new(14, 14),
			Size = nseq(1.4, 0), LightEmission = 1, Color = seq(rgb(220, 255, 90), rgb(60, 220, 40)) }))
		add(emitter(at, { Texture = TEX.Sparkle, Rate = 25, Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(40, 40),
			Size = nseq(0.7, 0.2), LightEmission = 1, Acceleration = Vector3.new(0, 6, 0), Color = seq(rgb(170, 255, 60)) }))
	elseif style == "Leaves" then
		add(emitter(at, { Texture = TEX.Sparkle, Rate = 45, Lifetime = NumberRange.new(0.9, 1.5), Speed = NumberRange.new(5, 11), SpreadAngle = Vector2.new(45, 45),
			Size = nseq(0.9, 0.5), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200), Acceleration = Vector3.new(0, -6, 0),
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(120, 210, 70)), ColorSequenceKeypoint.new(0.5, rgb(70, 160, 50)), ColorSequenceKeypoint.new(1, rgb(230, 170, 50)) }) }))
		add(ribbon(at, seq(rgb(120, 220, 80), rgb(40, 120, 40)), 0.35, 0.6, 0.3))
	elseif style == "Sparkle" then
		add(emitter(at, { Texture = TEX.Sparkle, Rate = 80, Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(3, 8), SpreadAngle = Vector2.new(50, 50),
			Size = nseq(1.0, 0), LightEmission = 1, Color = seq(rgb(255, 255, 255), rgb(255, 210, 255)) }))
		add(ribbon(at, seq(rgb(255, 230, 255), rgb(200, 160, 255)), 0.3, 0.5))
	elseif style == "Ghost" then
		add(emitter(at, { Texture = TEX.Smoke, Rate = 40, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(30, 30),
			Size = nseq(1.2, 4.5), Transparency = nseq(0.35, 1), LightEmission = 0.6, Color = seq(rgb(190, 120, 255), rgb(80, 40, 160)) }))
	elseif style == "Rainbow" then
		add(ribbon(at, RAINBOW, 0.9, 1.4))
		add(emitter(at, { Texture = TEX.Sparkle, Rate = 30, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(40, 40),
			Size = nseq(0.8, 0), LightEmission = 1, Color = RAINBOW }))
	elseif style == "Lightning" then
		add(ribbon(at, seq(rgb(220, 245, 255), rgb(80, 160, 255)), 0.45, 0.9))
		add(emitter(at, { Texture = TEX.Sparkle, Rate = 90, Lifetime = NumberRange.new(0.08, 0.2), Speed = NumberRange.new(14, 26), SpreadAngle = Vector2.new(60, 60),
			Size = nseq(1.6, 0), LightEmission = 1, Color = seq(rgb(230, 250, 255), rgb(90, 170, 255)) }))
	elseif style == "Spray" then
		-- a rooster tail of river water: a white-blue plume that arcs up and falls, droplets glinting
		add(emitter(at, { Texture = TEX.Smoke, Rate = 55, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(10, 16), SpreadAngle = Vector2.new(14, 22),
			Size = nseq(0.8, 3.2), Transparency = nseq(0.25, 1), Acceleration = Vector3.new(0, -26, 0), Color = seq(rgb(235, 250, 255), rgb(120, 200, 240)) }))
		add(emitter(at, { Texture = TEX.Sparkle, Rate = 40, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(30, 30),
			Size = nseq(0.5, 0), LightEmission = 0.5, Acceleration = Vector3.new(0, -30, 0), Color = seq(rgb(255, 255, 255), rgb(150, 220, 255)) }))
	elseif style == "Comet" then
		add(ribbon(at, seq(rgb(255, 245, 190), rgb(255, 150, 40)), 1.1, 1.2))
		add(emitter(at, { Texture = TEX.Sparkle, Rate = 70, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(35, 35),
			Size = nseq(1.2, 0), LightEmission = 1, Color = seq(rgb(255, 255, 220), rgb(255, 200, 80)) }))
	end
	return out
end

--------------------------------------------------------------------------------
-- per-vehicle state
--------------------------------------------------------------------------------
local function setup(v: Model)
	local root = v.PrimaryPart
	if not root then return nil end
	local st = { Glow = {}, Light = nil, Red = {}, Blue = {}, Spin = {}, Trail = {}, Style = v:GetAttribute("Trail") or "Flame", Cruise = 42 }
	local info = Config.Vehicles[v:GetAttribute("VehicleName") or ""]
	st.Cruise = info and info.Cruise or 42
	for _, p in ipairs(v:GetDescendants()) do
		if p:IsA("BasePart") then
			if p.Name == "GlowStrip" then table.insert(st.Glow, p)
			elseif p.Name == "SirenRed" then table.insert(st.Red, p)
			elseif p.Name == "SirenBlue" then table.insert(st.Blue, p)
			elseif p:GetAttribute("Spin") then
				local w = p:FindFirstChildOfClass("Weld")
				if w then table.insert(st.Spin, { W = w, C0 = w.C0 }) end
			end
		elseif p:IsA("SurfaceLight") and p.Parent and p.Parent.Name == "GlowPlate" then
			st.Light = p
		end
	end
	-- the dish turns about its mast
	local mast = v:FindFirstChild("DishMast", true) :: BasePart?
	if mast then st.Pivot = root.CFrame:PointToObjectSpace(mast.Position) end
	-- boost trail points: kit exhausts / rockets first, else the body's own flame point
	local points = {}
	for _, a in ipairs(v:GetDescendants()) do
		if a:IsA("Attachment") and a.Name == "TrailPoint" then table.insert(points, a) end
	end
	if #points == 0 then
		local b = root:FindFirstChild("BoostFlame") :: Attachment?
		if b then table.insert(points, b) end
	end
	for _, a in ipairs(points) do
		for _, x in ipairs(buildTrail(a, st.Style)) do table.insert(st.Trail, x) end
	end
	st.Mode = v:GetAttribute("Glow") or "None"
	st.Color = Rides.Color(v:GetAttribute("GlowColor")) or Rides.StockGlow
	return st
end

local function setTrail(st, on: boolean)
	if st.TrailOn == on then return end
	st.TrailOn = on
	for _, x in ipairs(st.Trail) do (x :: any).Enabled = on end
end

local function step(v: Model, st, t: number, boosting: boolean)
	-- underglow
	if #st.Glow > 0 then
		local mode, c = st.Mode, st.Color
		for _, p in ipairs(st.Glow) do
			local i = p:GetAttribute("GlowIndex") or 0
			local col = c
			if mode == "Pulse" then
				col = Rides.Shade(c, 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 3)))
			elseif mode == "Chase" then
				local k = (math.floor(t * 6) % 4)
				col = (k == i) and Rides.Shade(c, 1.3) or Rides.Shade(c, 0.3)
			elseif mode == "Police" then
				local on = math.floor(t * 5) % 2 == 0
				col = ((i % 2 == 0) == on) and rgb(255, 40, 40) or rgb(40, 90, 255)
			elseif mode == "Rainbow" then
				col = Color3.fromHSV((t * 0.25 + i * 0.25) % 1, 0.85, 1)
			end
			p.Color = Rides.Shade(col, 0.7) -- neon under bloom: a glow, not a floodlight
		end
		if st.Light then
			st.Light.Color = st.Glow[1].Color
			st.Light.Brightness = mode == "Pulse" and (1 + 1.5 * (0.5 + 0.5 * math.sin(t * 3))) or 2
		end
	end
	-- sirens
	if #st.Red > 0 then
		local a = math.floor(t * 4) % 2 == 0
		for _, p in ipairs(st.Red) do p.Transparency = a and 0 or 0.65 end
		for _, p in ipairs(st.Blue) do p.Transparency = a and 0.65 or 0 end
	end
	-- radar dish
	if st.Pivot and #st.Spin > 0 then
		local rot = CFrame.new(st.Pivot) * CFrame.Angles(0, t * 1.6, 0) * CFrame.new(-st.Pivot)
		for _, s in ipairs(st.Spin) do
			if s.W.Parent then s.W.C0 = rot * s.C0 end
		end
	end
	setTrail(st, boosting)
end

local function isMine(v: Model): boolean
	return v == Drive.State.Vehicle
end

--------------------------------------------------------------------------------
-- horn
--------------------------------------------------------------------------------
local function bubble(at: BasePart, text: string, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "DinoHonk"
	bb.Size = UDim2.fromOffset(260, 80)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 220
	bb.Adornee = at
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = holder
	Kit.Text(holder, text, { Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(255, 233, 138), Color2 = Color3.fromRGB(255, 150, 51), Stroke = 4, Shadow = 3, MaxSize = 46, Rotation = math.random(-8, 8) })
	bb.Parent = at
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(bb, TweenInfo.new(1.1), { StudsOffsetWorldSpace = Vector3.new(0, height + 2.5, 0) }):Play()
	task.delay(0.85, function() TweenService:Create(sc, TweenInfo.new(0.25), { Scale = 0 }):Play() end)
	task.delay(1.2, function() bb:Destroy() end)
end

function RideFx.HonkAt(v: Model, horn: string?)
	local root = v.PrimaryPart
	if not root then return end
	horn = horn or v:GetAttribute("Horn") or "Beep"
	local item = Rides.Item("Horn", horn :: string)
	local id = Audio.IDS["Horn" .. tostring(horn)]
	if id and id ~= "" and Audio.Enabled() then
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = 0.8
		s.RollOffMaxDistance = 220
		s.Parent = root
		s:Play()
		s.Ended:Connect(function() s:Destroy() end)
		task.delay(8, function() if s.Parent then s:Destroy() end end)
	end
	bubble(root, item and item.Say or "BEEP!", (v:GetAttribute("Height") or 8) - (v:GetAttribute("RootHeight") or 2.6) + 2)
end

local lastHonk = 0
local function honk()
	if os.clock() - lastHonk < 0.7 or Cinema.Playing() then return end
	if not Drive.State.Vehicle or Drive.State.OnFoot then return end
	lastHonk = os.clock()
	task.spawn(Net.Ask, "Honk")
end
RideFx.Honk = honk

--------------------------------------------------------------------------------
-- preview hooks (garage studio)
--------------------------------------------------------------------------------
function RideFx.Track(v: Model)
	previews[v] = true
	tracked[v] = nil
end
function RideFx.Untrack(v: Model)
	previews[v] = nil
	tracked[v] = nil
end
local previewTrail = (setmetatable({}, { __mode = "k" }) :: any) :: { [Model]: boolean }
function RideFx.Trail(v: Model, on: boolean)
	previewTrail[v] = on
end

function RideFx.Start()
	local touchBtn
	local function makeTouch()
		if touchBtn or not UserInputService.TouchEnabled then return end
		local _, canvas = Kit.Screen("DinoHonk", 14, false, 0.8)
		touchBtn = Kit.Button(canvas, { Name = "Honk", Text = "HONK", Color = "Purple", Size = UDim2.fromOffset(96, 52), Position = UDim2.new(1, -210, 1, -270), AnchorPoint = Vector2.new(1, 1), ZIndex = 5, MaxText = 20, OnClick = honk })
	end
	makeTouch()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.H or input.KeyCode == Enum.KeyCode.DPadUp then honk() end
	end)
	Net.On("Honk", function(info)
		local folder = Workspace:FindFirstChild("ActiveVehicles")
		if not folder then return end
		for _, v in ipairs(folder:GetChildren()) do
			if v:IsA("Model") and v:GetAttribute("Owner") == info.Owner then RideFx.HonkAt(v, info.Horn) break end
		end
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if touchBtn then touchBtn.Visible = Drive.State.Vehicle ~= nil and not Drive.State.OnFoot and not Cinema.Playing() end
		local folder = Workspace:FindFirstChild("ActiveVehicles")
		local list = folder and folder:GetChildren() or {}
		for v in pairs(previews) do table.insert(list, v) end
		for _, v in ipairs(list) do
			if not (v:IsA("Model") and v.Parent and v.PrimaryPart) then continue end
			local st = tracked[v]
			if not st then
				st = setup(v)
				if not st then continue end
				tracked[v] = st
			end
			local boosting
			if previews[v] then
				boosting = previewTrail[v] == true
			elseif isMine(v) then
				boosting = Drive.State.Boosting and (Drive.State.Mode == "Route" or Drive.State.Speed > 6)
			else
				boosting = (v.PrimaryPart :: BasePart).AssemblyLinearVelocity.Magnitude > st.Cruise * 1.08
			end
			step(v, st, t, boosting)
		end
	end)
end

return RideFx
