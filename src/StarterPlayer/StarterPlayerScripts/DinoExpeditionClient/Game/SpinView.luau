--[[
	SpinView — the DAILY SPIN (server: Spin.luau, prizes: Game/SpinWheel.luau, the wheel at camp: tools/gen/spinWheel.js).

	  the window   DAILY SPIN (the wheel's prompt, or the SPIN button on the HUD): a live copy of the camp wheel in a
	               viewport, a big SPIN button (FREE SPIN! / SPIN x3 / the time to the next free one), extra spins
	               for Robux, and every slice's odds. The server picks the slice; the wheel turns onto it, the pointer
	               ticks over every peg, and the prize lands when it stops.
	  the camp wheel  turns for everyone when someone spins near it ("WheelSpin"); its bulbs chase while YOU have a
	               free spin ready, and its tag says so (or how long until the next).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game")
local Config = require(Shared:WaitForChild("Config"))
local SpinWheel = require(Shared:WaitForChild("SpinWheel"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer
local C = Theme.C
local SEG = SpinWheel.Segments
local N = #SEG
local STEP = 360 / N

local SpinView = {}
local Panels: any = nil

local function now(): number
	return Net.ServerTime()
end
local function clock(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
end

--------------------------------------------------------------------------------
-- a wheel (the one at camp, or its copy in the window): turning the rotor, kicking the pointer
--------------------------------------------------------------------------------
type Wheel = { Rotor: Model, Base: CFrame, Flapper: Model?, FlapBase: CFrame?, Angle: number, Token: any?, Kick: number }

local function wheelOf(model: Instance): Wheel?
	local rotor = model:FindFirstChild("Rotor", true)
	if not (rotor and rotor:IsA("Model") and rotor.PrimaryPart) then return nil end
	local fl = model:FindFirstChild("Flapper", true)
	local flapper = (fl and fl:IsA("Model") and fl.PrimaryPart) and fl or nil
	return { Rotor = rotor, Base = rotor:GetPivot(), Flapper = flapper, FlapBase = flapper and flapper:GetPivot() or nil, Angle = 0, Token = nil, Kick = 0 }
end

-- (positive = clockwise as you face the wheel: a slice drawn at angle a shows at a + Angle; the pointer is at the top)
local function setAngle(w: Wheel, deg: number)
	w.Angle = deg
	w.Rotor:PivotTo(w.Base * CFrame.Angles(0, 0, math.rad(deg)))
end

-- the pointer swings a little each time a peg passes under it, and settles back
local function stepFlapper(w: Wheel, dt: number)
	if not (w.Flapper and w.FlapBase) then return end
	w.Kick = math.max(0, w.Kick - dt * 3.2)
	w.Flapper:PivotTo((w.FlapBase :: CFrame) * CFrame.Angles(0, 0, math.rad(-28 * w.Kick)))
end

-- turn onto slice `index` over `dur` seconds (a few full turns first), then call done
local function spinTo(w: Wheel, index: number, dur: number, onTick: (() -> ())?, done: (() -> ())?)
	local token = {}
	w.Token = token
	local from = w.Angle
	-- where it has to stop: the slice's middle under the pointer, nudged a little inside it so it's never exact
	local target = -((index - 1) * STEP) + (math.random() - 0.5) * STEP * 0.6
	local delta = ((target - from) % 360) + 360 * 5
	local t0 = os.clock()
	local lastPeg = math.floor((from - STEP / 2) / STEP)
	task.spawn(function()
		while w.Token == token do
			local u = math.clamp((os.clock() - t0) / dur, 0, 1)
			local e = 1 - (1 - u) ^ 3.4
			setAngle(w, from + delta * e)
			local peg = math.floor((w.Angle - STEP / 2) / STEP)
			if peg ~= lastPeg then
				lastPeg = peg
				w.Kick = 1
				if onTick then onTick() end
			end
			if u >= 1 then break end
			local dt = RunService.RenderStepped:Wait()
			stepFlapper(w, dt)
		end
		if w.Token == token then
			w.Token = nil
			local settle = os.clock()
			while os.clock() - settle < 0.4 and w.Token == nil do stepFlapper(w, RunService.RenderStepped:Wait()) end
			if done then done() end
		end
	end)
end

--------------------------------------------------------------------------------
-- the wheel at camp
--------------------------------------------------------------------------------
local campModel: Model? = nil
local camp: Wheel? = nil
local function findCamp(): Model?
	if campModel and campModel.Parent then return campModel end
	campModel, camp = nil, nil
	local bc = Workspace:FindFirstChild("BaseCamp")
	local m = bc and bc:FindFirstChild("SpinWheel", true)
	if m and m:IsA("Model") then
		campModel = m
		camp = wheelOf(m)
	end
	return campModel
end

local function tickSound(at: Instance?)
	Audio.Play("Click", { Volume = 0.35, Pitch = 1.3, At = at })
end

--------------------------------------------------------------------------------
-- the window
--------------------------------------------------------------------------------
local canvas: Frame? = nil
local dim: TextButton? = nil
local win: Frame? = nil
local view: Big? = nil
local spinning = false
local spinBtn: Frame? = nil
local result: Frame? = nil
local wheelCard: Frame? = nil -- (the prize lands over the bottom of the wheel)

local function close()
	if spinning then return end -- (it closes itself once the prize is out)
	local w = win
	win, view = nil, nil
	if w then Kit.Exit(w, true) end
	if dim then TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play() end
	task.delay(0.22, function() if not win and dim then dim.Visible = false end end)
end
SpinView.Close = close
function SpinView.IsOpen(): boolean
	return win ~= nil
end

local function ensureScreen()
	if canvas then return end
	local _, cv = Kit.Screen("DinoSpin", 21)
	canvas = cv
	local d = Instance.new("TextButton")
	d.Name = "Dim"
	d.Text = ""
	d.AutoButtonColor = false
	d.BackgroundColor3 = Color3.fromRGB(8, 16, 10)
	d.BackgroundTransparency = 1
	d.Size = UDim2.fromScale(4, 4)
	d.Position = UDim2.fromScale(-1.5, -1.5)
	d.Visible = false
	d.ZIndex = 1
	d.Parent = cv
	d.Activated:Connect(close)
	dim = d
end

local function pixel(parent: Instance, s: string, props)
	props.Pixel = true
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2
	props.Shadow = props.Shadow or 1
	props.MaxSize = props.MaxSize or 12
	return Kit.Text(parent, s, props)
end

--------------------------------------------------------------------------------
-- the window's wheel (2026-10-15, user: "make the free spin better animation ... perfect for every single device").
-- Its own wheel, not a copy of the camp one: crisp slices in a viewport (two wedges each), and everything that has
-- to read on a phone - the icons, the pointer, the rim lights - drawn as UI over it in scale units, so it's the same
-- picture at any size. A spin: a wind-up, a fast blur of turns that eases into a slow creep past the last pegs (the
-- pointer clicks over each one), a little rock back as it stops, then the winning slice flashes, the lights burst
-- and the prize card lands.
--------------------------------------------------------------------------------
type Big = {
	Rotor: Model, Slices: { { BasePart } }, Icons: { GuiObject }, Bulbs: { Frame }, Pointer: GuiObject,
	Angle: number, Token: any?, Kick: number, Frame: Frame, Glow: Frame, Win: number?,
}
local R = 10 -- the wheel's radius (studs, in its own little world)
local CAM_D, CAM_FOV = 31, 46
-- the wheel's radius as a fraction of the viewport's half-height (for the overlay)
local FRAC = R / (CAM_D * math.tan(math.rad(CAM_FOV / 2)))

local function wedge(parent: Instance, color: Color3, mat: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored, w.CanCollide, w.CastShadow = true, false, false
	w.Color = color
	w.Material = mat or Enum.Material.SmoothPlastic
	w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end
-- a flat triangle a-b-c from two right-angle wedges (the classic way to draw any triangle in Roblox)
local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, color: Color3, th: number): { BasePart }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1 = wedge(parent, color)
	w1.Size = Vector3.new(th, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	local w2 = wedge(parent, color)
	w2.Size = Vector3.new(th, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	return { w1, w2 }
end
local function disc(parent: Instance, d: number, z: number, th: number, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CastShadow = true, false, false
	p.Size = Vector3.new(th, d, d)
	-- (a cylinder's axis is its X: turned to face the camera along Z)
	p.CFrame = CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(90), 0)
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end
-- where a slice drawn at `deg` (clockwise from the top, as you look at it) sits; the wheel faces -Z, you look along +Z
local function rim(deg: number, r: number, z: number): Vector3
	local a = math.rad(deg)
	return Vector3.new(-math.sin(a) * r, math.cos(a) * r, z)
end

local function buildWheel(parent: Frame): Big
	-- a square stage in the card, as big as fits
	local stage = Instance.new("Frame")
	stage.Name = "Wheel"
	stage.BackgroundTransparency = 1
	stage.Size = UDim2.fromScale(0.94, 0.94)
	stage.Position = UDim2.fromScale(0.5, 0.44)
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.ZIndex = 23
	stage.Parent = parent
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = stage
	-- a soft glow behind it (it flares when you win)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.BackgroundColor3 = C.YellowHi
	glow.BackgroundTransparency = 0.82
	glow.Size = UDim2.fromScale(FRAC * 1.12, FRAC * 1.12)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.ZIndex = 23
	glow.Parent = stage
	Kit.Corner(glow, 999)
	local vf = Instance.new("ViewportFrame")
	vf.Name = "View"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(200, 196, 190)
	vf.LightColor = Color3.fromRGB(255, 246, 230)
	vf.LightDirection = Vector3.new(-0.3, -0.6, 1)
	vf.ZIndex = 24
	vf.Parent = stage
	local world = Instance.new("WorldModel")
	world.Parent = vf
	-- the frame behind (dark wood, a gold band) - it doesn't turn
	local fixed = Instance.new("Model")
	fixed.Parent = world
	disc(fixed, R * 2 + 2.6, 1.2, 1.2, Color3.fromRGB(86, 52, 30), Enum.Material.Wood)
	disc(fixed, R * 2 + 1.1, 0.7, 0.7, Color3.fromRGB(255, 196, 46), Enum.Material.SmoothPlastic)
	-- the rotor: the slices, white spokes between them, the hub
	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	rotor.Parent = world
	local hub = disc(rotor, 4.2, -0.5, 0.9, Color3.fromRGB(255, 214, 72), Enum.Material.SmoothPlastic)
	disc(rotor, 2.4, -0.75, 0.5, Color3.fromRGB(255, 246, 214), Enum.Material.SmoothPlastic)
	rotor.PrimaryPart = hub
	local slices = {}
	for i, seg in ipairs(SEG) do
		local a = (i - 1) * STEP
		local parts = {}
		-- (two triangles a slice: the arc edge stays round enough at 8 slices)
		local half = STEP / 2
		for _, pair in ipairs({ { a - half, a }, { a, a + half } }) do
			for _, p in ipairs(triangle(rotor, Vector3.new(0, 0, 0), rim(pair[1], R, 0), rim(pair[2], R, 0), seg.Color, 0.4)) do
				table.insert(parts, p)
			end
		end
		slices[i] = parts
		-- the spoke on its leading edge
		local mid = rim(a - half, R / 2, -0.25)
		local spoke = Instance.new("Part")
		spoke.Anchored, spoke.CanCollide, spoke.CastShadow = true, false, false
		spoke.Size = Vector3.new(0.28, R, 0.12)
		spoke.CFrame = CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1)) * CFrame.Angles(0, 0, math.rad(a - half))
		spoke.Color = Color3.fromRGB(255, 250, 236)
		spoke.Parent = rotor
	end
	-- the pegs round the edge (what the pointer clicks over)
	for i = 1, N do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Anchored, p.CanCollide, p.CastShadow = true, false, false
		p.Size = Vector3.new(0.7, 0.7, 0.7)
		p.CFrame = CFrame.new(rim((i - 1) * STEP - STEP / 2, R - 0.45, -0.4))
		p.Color = Color3.fromRGB(255, 250, 236)
		p.Parent = rotor
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = CAM_FOV
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, -CAM_D), Vector3.zero)
	cam.Parent = vf
	vf.CurrentCamera = cam
	-- the overlay: an icon on every slice, rim lights, the pointer (scale units: the same at any size)
	local icons = {}
	for i, seg in ipairs(SEG) do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(0.13, 0.13)
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.ZIndex = 26
		holder.Parent = stage
		Kit.Icon(holder, seg.Icon or "Star", { Size = UDim2.fromScale(1, 1), ZIndex = 27 })
		icons[i] = holder
	end
	local bulbs = {}
	local nb = 24
	for i = 1, nb do
		local b = Instance.new("Frame")
		b.BackgroundColor3 = C.YellowHi
		b.Size = UDim2.fromScale(0.03, 0.03)
		local a = math.rad((i - 1) / nb * 360)
		local r = FRAC * 0.5 * 1.06
		b.Position = UDim2.fromScale(0.5 + math.sin(a) * r, 0.5 - math.cos(a) * r)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.ZIndex = 26
		b.Parent = stage
		Kit.Corner(b, 999)
		Kit.Stroke(b, C.Ink, 1.5)
		bulbs[i] = b
	end
	-- the pointer: a fat red arrow over the top, hinged at its top so it flicks as the pegs pass
	local pointer = Instance.new("Frame")
	pointer.Name = "Pointer"
	pointer.BackgroundTransparency = 1
	pointer.Size = UDim2.fromScale(0.13, 0.15)
	pointer.Position = UDim2.fromScale(0.5, 0.5 - FRAC * 0.5 - 0.035)
	pointer.AnchorPoint = Vector2.new(0.5, 0.15)
	pointer.ZIndex = 28
	pointer.Parent = stage
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.Font = Enum.Font.FredokaOne
	arrow.TextColor3 = C.RedHi or Color3.fromRGB(255, 90, 80)
	arrow.ZIndex = 29
	arrow.Parent = pointer
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = C.Ink
	st.Parent = arrow
	local w: Big = { Rotor = rotor, Slices = slices, Icons = icons, Bulbs = bulbs, Pointer = pointer, Angle = 0, Token = nil, Kick = 0, Frame = stage, Glow = glow, Win = nil }
	return w
end

-- turn it to `deg` (clockwise as you look at it) and keep the overlay with it
local function setBig(w: Big, deg: number)
	w.Angle = deg
	w.Rotor:PivotTo(CFrame.Angles(0, 0, math.rad(deg)))
	local r = FRAC * 0.5 * 0.66
	for i, icon in ipairs(w.Icons) do
		local a = math.rad((i - 1) * STEP + deg)
		icon.Position = UDim2.fromScale(0.5 + math.sin(a) * r, 0.5 - math.cos(a) * r)
		icon.Rotation = (i - 1) * STEP + deg
	end
end

-- the rim lights: a slow chase when idle, a fast one while it spins, every other one flashing on a win
local function stepBulbs(w: Big, t: number, mode: string)
	for i, b in ipairs(w.Bulbs) do
		local on
		if mode == "Win" then
			on = (math.floor(t * 8) + i) % 2 == 0
		elseif mode == "Spin" then
			on = (math.floor(t * 18) - i) % 4 ~= 0
		else
			on = (math.floor(t * 3) - i) % 6 == 0 or (math.floor(t * 3) - i) % 6 == 3
		end
		b.BackgroundColor3 = on and C.YellowHi or Color3.fromRGB(120, 92, 40)
	end
end

local function flick(w: Big, dt: number)
	w.Kick = math.max(0, w.Kick - dt * 4)
	w.Pointer.Rotation = -26 * w.Kick
end

-- the spin itself: wind-up, the turns, the creep, the rock back, then done()
local function spinBig(w: Big, index: number, done: () -> ())
	local token = {}
	w.Token = token
	w.Win = nil
	local from = w.Angle
	local target = -((index - 1) * STEP) + (math.random() - 0.5) * STEP * 0.55
	local total = SpinWheel.SpinTime
	local windT, rockT = 0.35, 0.45
	local mainT = math.max(1.5, total - windT - rockT)
	local wind = 14
	local over = 3.2 -- (it overshoots the stop a hair and rocks back)
	local turns = ((target - (from - wind)) % 360) + 360 * 6
	local t0 = os.clock()
	local lastPeg = math.floor((from - STEP / 2) / STEP)
	local function pegCheck()
		local peg = math.floor((w.Angle - STEP / 2) / STEP)
		if peg ~= lastPeg then
			lastPeg = peg
			w.Kick = 1
			tickSound(nil)
		end
	end
	task.spawn(function()
		while w.Token == token do
			local dt = RunService.RenderStepped:Wait()
			local t = os.clock() - t0
			if t < windT then
				local u = t / windT
				setBig(w, from - wind * math.sin(u * math.pi / 2))
			elseif t < windT + mainT then
				local u = (t - windT) / mainT
				-- (fast off the mark, a long slow creep at the end: the last few pegs take their time)
				local e = 1 - (1 - u) ^ 4
				setBig(w, (from - wind) + (turns + over) * e)
				pegCheck()
			elseif t < windT + mainT + rockT then
				local u = (t - windT - mainT) / rockT
				local e = math.sin(u * math.pi / 2)
				setBig(w, (from - wind) + turns + over * (1 - e))
				pegCheck()
			else
				setBig(w, (from - wind) + turns)
				break
			end
			flick(w, dt)
			stepBulbs(w, os.clock(), "Spin")
		end
		if w.Token ~= token then return end
		w.Token = nil
		w.Win = index
		done()
	end)
end

-- the win: the slice flashes, the glow flares, a burst of sparks off the rim
local function celebrate(w: Big, index: number)
	local parts = w.Slices[index] or {}
	local base = SEG[index] and SEG[index].Color or Color3.new(1, 1, 1)
	task.spawn(function()
		for k = 1, 6 do
			for _, p in ipairs(parts) do p.Color = (k % 2 == 1) and Color3.new(1, 1, 1):Lerp(base, 0.25) or base end
			task.wait(0.11)
			if not w.Frame.Parent then return end
		end
		for _, p in ipairs(parts) do p.Color = base end
	end)
	w.Glow.BackgroundColor3 = base
	w.Glow.BackgroundTransparency = 0.25
	w.Glow.Size = UDim2.fromScale(FRAC * 1.0, FRAC * 1.0)
	TweenService:Create(w.Glow, TweenInfo.new(0.9, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.82, Size = UDim2.fromScale(FRAC * 1.12, FRAC * 1.12) }):Play()
	-- sparks out of the top, where the pointer is
	for k = 1, 18 do
		local s = Instance.new("Frame")
		s.BackgroundColor3 = (k % 3 == 0) and C.YellowHi or base:Lerp(Color3.new(1, 1, 1), 0.35)
		s.Size = UDim2.fromScale(0.025, 0.025)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(0.5, 0.5 - FRAC * 0.5)
		s.Rotation = 45
		s.ZIndex = 30
		s.Parent = w.Frame
		local a = math.rad(-90 + (k / 18) * 180 + (math.random() - 0.5) * 20)
		local d = 0.18 + math.random() * 0.14
		local to = UDim2.fromScale(0.5 + math.cos(a) * d, 0.5 - FRAC * 0.5 + math.sin(a) * d + 0.05)
		TweenService:Create(s, TweenInfo.new(0.7 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = to, BackgroundTransparency = 1, Rotation = 45 + math.random(-180, 180) }):Play()
		task.delay(1.1, function() s:Destroy() end)
	end
	Kit.Punch(w.Frame, 0.12)
end

local function buy(id: string)
	local prod = Config.Products[id]
	if not prod or prod.Id == 0 then Kit.Toast("COMING SOON!", "Purple", "Gem") return end
	MarketplaceService:PromptProductPurchase(player, prod.Id)
end

local refreshButton: () -> ()

local function showPrize(prize)
	if not win then return end
	if result then result:Destroy() end
	local col = typeof(prize.Color) == "Color3" and prize.Color or C.YellowHi
	local holder = Instance.new("Frame")
	holder.Name = "Prize"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -20, 0, 70)
	holder.Position = UDim2.new(0.5, 0, 1, -12)
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.ZIndex = 30
	holder.Parent = wheelCard
	local _, cc = Kit.Brick(holder, { Size = UDim2.fromScale(1, 1), Color = Theme.Swatchify(col), Radius = 14, Lip = 5, ZIndex = 31, Stripes = 0.85 })
	Kit.Icon(cc, prize.Icon or "Star", { Size = UDim2.fromOffset(62, 62), Position = UDim2.new(0, -6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 35, Rotation = -8 })
	Kit.Text(cc, tostring(prize.Text or "PRIZE!"), { Size = UDim2.new(1, -70, 0, 34), Position = UDim2.new(0, 60, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 35, Stroke = 3.5, Shadow = 3, MaxSize = 30 })
	Kit.Pop(holder, 0.3)
	result = holder
end

local function doSpin()
	if spinning or not win then return end
	spinning = true
	if spinBtn then Kit.Shake(spinBtn) end
	local res = Net.Ask("Spin")
	if not (res and res.Ok) then
		spinning = false
		Kit.Toast(string.upper(tostring(res and res.Err or "CAN'T SPIN RIGHT NOW")), res and res.NoSpins and "Orange" or "Red", "Clock")
		refreshButton()
		return
	end
	if result then result:Destroy() result = nil end
	Audio.Play("Boost", { Volume = 0.6 })
	local index = tonumber(res.Index) or 1
	local function landed()
		spinning = false
		local seg = SEG[index]
		if view then celebrate(view, index) end
		Audio.Sting(seg and seg.Kind == "Jackpot" and "HatchLegendary" or "QuestDone", 0.7)
		showPrize(res.Prize or {})
		Kit.Toast(tostring(res.Prize and res.Prize.Text or "PRIZE!"), "Gold", res.Prize and res.Prize.Icon or "Star")
		refreshButton()
	end
	if view then
		spinBig(view, index, landed)
	else
		task.delay(1.2, landed)
	end
	refreshButton()
end

refreshButton = function()
	if not (win and spinBtn) then return end
	local p = Net.Profile
	local total, free, nextFree = SpinWheel.State(p, now())
	local label: string
	local color = "Grey"
	if spinning then
		label = "SPINNING..."
	elseif free then
		label = total > 1 and ("FREE SPIN!  (+" .. (total - 1) .. ")") or "FREE SPIN!"
		color = "Yellow"
	elseif total > 0 then
		label = "SPIN  x" .. total
		color = "Orange"
	else
		label = "FREE SPIN IN " .. clock(nextFree - now())
	end
	local holder = spinBtn :: Frame
	local key = label .. color
	if holder:GetAttribute("Key") == key then return end
	holder:SetAttribute("Key", key)
	holder:ClearAllChildren()
	local _, hit = Kit.Button(holder, { Text = label, Icon = "Star", IconSize = 0.85, TextLeft = 0.24, Color = color, Size = UDim2.fromScale(1, 1), ZIndex = 26, MaxText = 30, Shine = color ~= "Grey", Disabled = spinning or total <= 0, OnClick = doSpin })
	-- (a controller lands on the SPIN button: A spins)
	if hit and Kit.Gamepad() and not spinning and total > 0 then game:GetService("GuiService").SelectedObject = hit end
end

local function open()
	if Cinema.Playing() then return end
	ensureScreen()
	if Panels and Panels.IsOpen and Panels.IsOpen() then Panels.Close() end
	if win then win:Destroy() win = nil end
	if dim then
		dim.Visible = true
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.4 }):Play()
	end
	local root, content = Kit.Window(canvas :: Frame, { Fit = true, Title = "DAILY SPIN", Color = "Orange", Icon = "Star", Size = UDim2.fromOffset(820, 500), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20, OnClose = close })
	win = root
	result = nil
	-- left: the wheel
	local _, wc = Kit.Card(content, { Size = UDim2.fromOffset(380, 400), ZIndex = 22, Border = C.OrangeHi })
	wheelCard = wc
	view = buildWheel(wc)
	setBig(view :: Big, ((camp and camp.Angle) or 0))
	-- right: the button, the time, the shop, the odds
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Size = UDim2.new(1, -396, 1, 0)
	right.Position = UDim2.fromOffset(396, 0)
	right.ZIndex = 22
	right.Parent = content
	pixel(right, "ONE FREE SPIN EVERY DAY.  THE PRIZE IS YOURS THE MOMENT IT STOPS!", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 6), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 10, Color = C.YellowHi })
	local b = Instance.new("Frame")
	b.Name = "SpinButton"
	b.BackgroundTransparency = 1
	b.Size = UDim2.new(1, 0, 0, 78)
	b.Position = UDim2.fromOffset(0, 28)
	b.ZIndex = 26
	b.Parent = right
	spinBtn = b
	refreshButton()
	-- more spins
	pixel(right, "MORE SPINS", { Size = UDim2.new(1, 0, 0, 11), Position = UDim2.fromOffset(0, 124), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 11 })
	for i, id in ipairs({ "Spin1", "Spin3", "Spin10" }) do
		local prod = Config.Products[id]
		local w = 128
		Kit.Button(right, { Text = (prod.Name or id) .. "\nR$ " .. tostring(prod.Price), Color = "Purple", Size = UDim2.fromOffset(w, 58), Position = UDim2.fromOffset((i - 1) * (w + 8), 142), ZIndex = 26, MaxText = 18, TextSize = 0.7, OnClick = function() buy(id) end })
	end
	-- the odds
	pixel(right, "ODDS", { Size = UDim2.new(1, 0, 0, 11), Position = UDim2.fromOffset(0, 218), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 11 })
	for i, s in ipairs(SEG) do
		local col, row = (i - 1) % 2, (i - 1) // 2
		local x, y = col * 206, 236 + row * 34
		local chip = Instance.new("Frame")
		chip.BackgroundColor3 = s.Color
		chip.Size = UDim2.fromOffset(24, 24)
		chip.Position = UDim2.fromOffset(x, y)
		chip.ZIndex = 26
		chip.Parent = right
		Kit.Corner(chip, 6)
		Kit.Stroke(chip, C.Ink, 2)
		local pct = SpinWheel.Chance(i) * 100
		pixel(right, string.format("%s  %s%%", s.Name, pct >= 10 and string.format("%d", math.floor(pct + 0.5)) or string.format("%.1f", pct)), { Size = UDim2.fromOffset(170, 10), Position = UDim2.fromOffset(x + 32, y + 7), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 10 })
	end
	Kit.Enter(root)
end
SpinView.Open = open

--------------------------------------------------------------------------------
-- the camp wheel's own life: bulbs, the tag, other people's spins
--------------------------------------------------------------------------------
local function stepCamp(t: number)
	local m = findCamp()
	if not m then return end
	local p = Net.Profile
	local total, free, nextFree = SpinWheel.State(p, now())
	-- the marquee: a chase while you have a free spin, a slow glow otherwise
	for _, b in ipairs(CollectionService:GetTagged("SpinBulb")) do
		if b:IsA("BasePart") and b:IsDescendantOf(m) then
			local seq = tonumber(b:GetAttribute("Seq")) or 0
			local on = free and ((math.floor(t * 8) - seq) % 4 == 0) or (not free and math.sin(t * 1.5 + seq * 0.4) > 0.3)
			b.Transparency = on and 0 or 0.55
		end
	end
	local tag = m:FindFirstChild("SpinTag", true)
	local status = tag and tag:FindFirstChild("Status", true)
	local text = free and "FREE SPIN READY!" or (total > 0 and (total .. " SPINS READY") or ("FREE SPIN IN " .. clock(nextFree - now())))
	if status then
		for _, l in ipairs(status:GetDescendants()) do if l:IsA("TextLabel") then l.Text = text end end
		if status:IsA("TextLabel") then status.Text = text end
	end
end

function SpinView.Start(panels: any?)
	Panels = panels
	ProximityPromptService.PromptTriggered:Connect(function(pr)
		if pr:GetAttribute("CampAction") == "Spin" then open() end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if win and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then close() end
	end)
	-- the camp wheel turns for everyone nearby when someone spins at it
	Net.On("WheelSpin", function(info)
		if typeof(info) ~= "table" then return end
		findCamp()
		local w = camp
		if not w then return end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and (hrp.Position - w.Base.Position).Magnitude > 220 then return end
		local axle = w.Rotor.PrimaryPart
		spinTo(w, tonumber(info.Index) or 1, SpinWheel.SpinTime, function() tickSound(axle) end, nil)
	end)
	-- the window's wheel between spins: the lights chase (flash after a win), the pointer settles
	RunService.RenderStepped:Connect(function(dt)
		local w = view
		if not (w and w.Frame.Parent) or w.Token ~= nil then return end
		stepBulbs(w, os.clock(), w.Win and "Win" or "Idle")
		flick(w, dt)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.12 then return end
		acc = 0
		pcall(stepCamp, os.clock())
		if win and not spinning then pcall(refreshButton) end
		if camp and not camp.Token then pcall(stepFlapper, camp, 0.12) end
	end)
end

return SpinView
