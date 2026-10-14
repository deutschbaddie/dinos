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
local view: Wheel? = nil
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

-- a live copy of the camp wheel in a viewport
local function buildViewport(parent: Frame): Wheel?
	local src = findCamp()
	local vf = Instance.new("ViewportFrame")
	vf.Name = "WheelView"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(170, 160, 150)
	vf.LightColor = Color3.fromRGB(255, 244, 225)
	vf.LightDirection = Vector3.new(-0.4, -1, 0.6)
	vf.ZIndex = 24
	vf.Parent = parent
	if not src then
		pixel(parent, "THE WHEEL IS AT CAMP, BY THE TIME GATE", { Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 26, MaxSize = 12, Color = C.Muted })
		return nil
	end
	local world = Instance.new("WorldModel")
	world.Parent = vf
	local copy = Instance.new("Model")
	copy.Name = "SpinWheel"
	for _, ch in ipairs((src :: Model):GetChildren()) do
		-- (the wheel, its frame, the skull and pointer: not the base, the crystals or the planting)
		if ch.Name == "Rotor" or ch.Name == "Flapper" or ch.Name:match("^Frame") or ch.Name:match("^Skull") or ch.Name == "Bulb" or ch.Name == "BulbSocket" or ch.Name:match("^Axle") then
			local c = ch:Clone()
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("SurfaceGui") then d:Destroy() end
			end
			c.Parent = copy
		end
	end
	copy.Parent = world
	local w = wheelOf(copy)
	if not w then return nil end
	local axle = w.Base
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	-- (the wheel faces its local -Z: stand in front of it, a little above the hub so the skull pointer is in shot)
	local eye = (axle * CFrame.new(0, 1.2, -27)).Position
	cam.CFrame = CFrame.lookAt(eye, (axle * CFrame.new(0, 1.4, 0)).Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
	-- the camp wheel's current angle, so both read the same
	if camp then setAngle(w, camp.Angle) end
	return w
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
		Audio.Sting(seg and seg.Kind == "Jackpot" and "HatchLegendary" or "QuestDone", 0.7)
		showPrize(res.Prize or {})
		Kit.Toast(tostring(res.Prize and res.Prize.Text or "PRIZE!"), "Gold", res.Prize and res.Prize.Icon or "Star")
		refreshButton()
	end
	if view then
		spinTo(view, index, SpinWheel.SpinTime, function() tickSound(nil) end, landed)
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
	Kit.Button(holder, { Text = label, Icon = "Star", IconSize = 0.85, TextLeft = 0.24, Color = color, Size = UDim2.fromScale(1, 1), ZIndex = 26, MaxText = 30, Shine = color ~= "Grey", Disabled = spinning or total <= 0, OnClick = doSpin })
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
	view = buildViewport(wc)
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
