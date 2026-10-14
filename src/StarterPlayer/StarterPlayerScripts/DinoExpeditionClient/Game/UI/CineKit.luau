--[[
	CineKit — the big-moment language every cutscene and reward shares (the user's reference bar):
	  CineKit.RayTitle(gui, title, sub?, color?, hold?)  a huge pixel title slamming in letter by letter over
	                                                     a spinning burst of sun rays, a line under it
	  CineKit.Burst(pos, scale?, palette?)               blocks + leaves blown toward the lens, a block ring, a pop
	  CineKit.Punch(amount?)                              FOV kick + a blink of motion blur (slams, whips, reveals)
	  CineKit.Sparkle(pos, color, scale?)                 a rarity-coloured shower for rewards (eggs, hatches, loot)
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Kit)
local DinosaurVFX = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("DinosaurVFX"))

local CineKit = {}

CineKit.Leaf = { Color3.fromRGB(230, 70, 40), Color3.fromRGB(255, 150, 40), Color3.fromRGB(120, 200, 70), Color3.fromRGB(70, 160, 60) }

local function new(class: string, props, parent: Instance?)
	local i = Instance.new(class)
	for k, v in pairs(props) do (i :: any)[k] = v end
	if parent then i.Parent = parent end
	return i
end

local function fadeText(box: Instance, a: number, t: number)
	for _, l in ipairs(box:GetDescendants()) do
		if l:IsA("TextLabel") then
			TweenService:Create(l, TweenInfo.new(t), { TextTransparency = 1 - a }):Play()
		elseif l:IsA("UIStroke") then
			TweenService:Create(l, TweenInfo.new(t), { Transparency = 1 - a }):Play()
		end
	end
end

function CineKit.RayTitle(gui: Instance, title: string, sub: string?, color: Color3?, hold: number?, y: number?)
	local col = color or Color3.fromRGB(255, 226, 120)
	local holder = new("Frame", { Name = "RayTitle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y or 0.3), Size = UDim2.fromScale(0.9, 0.3), ZIndex = 40 }, gui)
	local rays = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = 40 }, holder)
	for i = 1, 14 do
		local ray = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.08, 0.5), Rotation = i * (360 / 14), BackgroundColor3 = (i % 2 == 0) and col or Color3.fromRGB(255, 200, 80), BackgroundTransparency = 0.25, ZIndex = 40 }, rays)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, ray)
	end
	TweenService:Create(rays, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromScale(2.2, 2.2) }):Play()
	local spin = RunService.RenderStepped:Connect(function(dt) rays.Rotation += dt * 22 end)
	local row = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(1, 0.46), ZIndex = 42 }, holder)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local n = #title
	for i = 1, n do
		local ch = title:sub(i, i)
		local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Size = UDim2.fromScale(ch == " " and 0.025 or math.min(0.075, 0.9 / n), 1), ZIndex = 42 }, row)
		if ch ~= " " then
			local l = Kit.Text(cell, ch, { Pixel = true, Size = UDim2.fromScale(1, 1), Color = Color3.fromRGB(255, 244, 214), Color2 = col, Stroke = 5, Shadow = 7, ZIndex = 43, MaxSize = 90 })
			l.Visible = false
			task.delay(0.04 * i, function()
				if not l.Parent then return end
				l.Visible = true
				Kit.Pop(l, 1.9)
			end)
		end
	end
	if sub and sub ~= "" then
		local st = Kit.Text(holder, sub, { Pixel = true, Size = UDim2.fromScale(0.8, 0.1), Position = UDim2.fromScale(0.5, 0.78), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(255, 226, 120), Stroke = 2.5, Shadow = 3, ZIndex = 43, MaxSize = 20 })
		fadeText(st, 0, 0)
		task.delay(0.04 * n + 0.15, function() if st.Parent then fadeText(st, 1, 0.3) end end)
	end
	task.delay(hold or 2.2, function()
		spin:Disconnect()
		if not holder.Parent then return end
		TweenService:Create(rays, TweenInfo.new(0.3), { Size = UDim2.fromScale(0, 0) }):Play()
		fadeText(holder, 0, 0.3)
		task.delay(0.35, function() holder:Destroy() end)
	end)
	return holder
end

-- SLAM: one giant word drops from huge to size with a white flash band behind it (FIGHT!, ESCAPE!, KNOCKOUT!)
function CineKit.Slam(gui: Instance, word: string, sub: string?, color: Color3?, hold: number?, y: number?)
	local col = color or Color3.fromRGB(255, 226, 120)
	local holder = new("Frame", { Name = "Slam", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y or 0.42), Size = UDim2.fromScale(1, 0.22), ZIndex = 40 }, gui)
	local band = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0, 0.62), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.15, ZIndex = 40, Rotation = -4 }, holder)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, band)
	TweenService:Create(band, TweenInfo.new(0.18, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1.1, 0.62) }):Play()
	TweenService:Create(band, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25), { BackgroundTransparency = 1 }):Play()
	local text = Kit.Text(holder, word, { Pixel = true, Size = UDim2.fromScale(0.9, 0.7), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(255, 248, 230), Color2 = col, Stroke = 6, Shadow = 8, ZIndex = 42, MaxSize = 110 })
	local sc = new("UIScale", { Scale = 3.2 }, text)
	text.Rotation = -4
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if sub and sub ~= "" then
		local st = Kit.Text(holder, sub, { Pixel = true, Size = UDim2.fromScale(0.8, 0.16), Position = UDim2.fromScale(0.5, 0.95), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(255, 236, 190), Stroke = 2.5, Shadow = 3, ZIndex = 43, MaxSize = 20 })
		fadeText(st, 0, 0)
		task.delay(0.25, function() if st.Parent then fadeText(st, 1, 0.25) end end)
	end
	task.delay(hold or 1.4, function()
		if not holder.Parent then return end
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
		fadeText(holder, 0, 0.25)
		task.delay(0.3, function() holder:Destroy() end)
	end)
	return holder
end

-- STAMP: a rubber stamp thunks onto the screen at a tilt, a box round it (ESCAPED!, a hatch's rarity)
function CineKit.Stamp(gui: Instance, word: string, sub: string?, color: Color3?, hold: number?, y: number?)
	local col = color or Color3.fromRGB(255, 226, 120)
	local holder = new("Frame", { Name = "Stamp", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y or 0.3), Size = UDim2.fromScale(0.62, 0.17), Rotation = -9, ZIndex = 40 }, gui)
	local box = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40 }, holder)
	new("UIStroke", { Thickness = 7, Color = col }, box)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, box)
	Kit.Text(holder, word, { Pixel = true, Size = UDim2.fromScale(0.9, 0.62), Position = UDim2.fromScale(0.5, sub and 0.4 or 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = col, Color2 = col:Lerp(Color3.new(1, 1, 1), 0.45), Stroke = 4, Shadow = 5, ZIndex = 42, MaxSize = 80 })
	if sub and sub ~= "" then
		Kit.Text(holder, sub, { Pixel = true, Size = UDim2.fromScale(0.86, 0.2), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(255, 244, 214), Stroke = 2.5, Shadow = 3, ZIndex = 43, MaxSize = 18 })
	end
	local sc = new("UIScale", { Scale = 1.9 }, holder)
	TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 }):Play()
	task.delay(0.16, function() DinosaurVFX.Shake(0.5, 0.15) end)
	task.delay(hold or 1.8, function()
		if not holder.Parent then return end
		TweenService:Create(sc, TweenInfo.new(0.25), { Scale = 1.15 }):Play()
		fadeText(holder, 0, 0.25)
		task.delay(0.3, function() holder:Destroy() end)
	end)
	return holder
end

-- SLASH CARD: a coloured slash wipes across the lower third and the name drops in letter by letter (dino reveals)
function CineKit.SlashCard(gui: Instance, kicker: string?, name: string, sub: string?, color: Color3?, hold: number?)
	local col = color or Color3.fromRGB(255, 176, 46)
	local holder = new("Frame", { Name = "SlashCard", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.05, 0.86), Size = UDim2.fromScale(0.7, 0.26), ZIndex = 40 }, gui)
	local slash = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = col, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(-0.05, 0.5), Size = UDim2.fromScale(0, 0.5), Rotation = -6, ZIndex = 40 }, holder)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.75, 0.35), NumberSequenceKeypoint.new(1, 1) }) }, slash)
	TweenService:Create(slash, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1.05, 0.5) }):Play()
	if kicker and kicker ~= "" then
		local k = Kit.Text(holder, kicker, { Pixel = true, Size = UDim2.fromScale(0.8, 0.13), Position = UDim2.fromScale(0.02, 0.1), Align = Enum.TextXAlignment.Left, Color = Color3.fromRGB(255, 244, 214), Stroke = 2.5, Shadow = 3, ZIndex = 43, MaxSize = 20 })
		fadeText(k, 0, 0)
		task.delay(0.2, function() if k.Parent then fadeText(k, 1, 0.25) end end)
	end
	local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.02, 0.28), Size = UDim2.fromScale(0.98, 0.42), ZIndex = 42 }, holder)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local n = #name
	for i = 1, n do
		local ch = name:sub(i, i)
		local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Size = UDim2.fromScale(ch == " " and 0.025 or math.min(0.06, 0.95 / n), 1), ZIndex = 42 }, row)
		if ch ~= " " then
			local l = Kit.Text(cell, ch, { Pixel = true, Size = UDim2.fromScale(1, 1), Color = Color3.fromRGB(255, 248, 230), Color2 = col:Lerp(Color3.new(1, 1, 1), 0.3), Stroke = 4, Shadow = 6, ZIndex = 43, MaxSize = 70 })
			l.Position = UDim2.fromScale(0, -0.6)
			fadeText(l, 0, 0)
			task.delay(0.12 + 0.03 * i, function()
				if not l.Parent then return end
				fadeText(l, 1, 0.12)
				TweenService:Create(l, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0, 0) }):Play()
			end)
		end
	end
	if sub and sub ~= "" then
		local st = Kit.Text(holder, sub, { Pixel = true, Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.02, 0.78), Align = Enum.TextXAlignment.Left, Color = Color3.fromRGB(230, 236, 245), Stroke = 2, Shadow = 3, ZIndex = 43, MaxSize = 18 })
		fadeText(st, 0, 0)
		task.delay(0.3 + 0.03 * n, function() if st.Parent then fadeText(st, 1, 0.3) end end)
	end
	task.delay(hold or 2.6, function()
		if not holder.Parent then return end
		TweenService:Create(slash, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.fromScale(0, 0.5) }):Play()
		fadeText(holder, 0, 0.3)
		task.delay(0.35, function() holder:Destroy() end)
	end)
	return holder
end

-- IMPACT FRAME: one or two frames of crushed, high-contrast black and white on the biggest hits (anime-style)
function CineKit.ImpactFrame(strength: number?)
	local k = strength or 1
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DinoImpactFrame"
	cc.Contrast = 0.9 * k
	cc.Saturation = -1 * k
	cc.Brightness = 0.12 * k
	cc.Parent = Lighting
	task.delay(0.05, function()
		cc.Contrast, cc.Saturation, cc.Brightness = -0.4 * k, -0.6 * k, 0.25 * k -- the second frame inverts the punch
		task.delay(0.04, function() cc:Destroy() end)
	end)
end

-- HIT-STOP / SLOW MO: every dino's animation freezes (or crawls) for a beat, then snaps back to speed
local DinoAnims = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("DinosaurAnimations"))
local slowToken = 0
function CineKit.HitStop(dur: number?, scale: number?, recover: number?)
	slowToken += 1
	local my = slowToken
	DinoAnims.TimeScale = scale or 0
	task.delay(dur or 0.1, function()
		if slowToken ~= my then return end
		local r = recover or 0.25
		local t0 = os.clock()
		local from = DinoAnims.TimeScale
		while os.clock() - t0 < r and slowToken == my do
			DinoAnims.TimeScale = from + (1 - from) * ((os.clock() - t0) / r)
			RunService.Heartbeat:Wait()
		end
		if slowToken == my then DinoAnims.TimeScale = 1 end
	end)
end
function CineKit.ResetTime()
	slowToken += 1
	DinoAnims.TimeScale = 1
end

-- SPEED LINES: streaks rushing in from the edges of the screen (charges, whips, the escape)
function CineKit.SpeedLines(gui: Instance, dur: number?, color: Color3?)
	local holder = new("Frame", { Name = "SpeedLines", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 35 }, gui)
	local lines = {}
	for i = 1, 28 do
		local a = (i / 28) * 360 + math.random() * 8
		local l = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 3 + math.random() * 3, 0.5, 0), Rotation = a, BackgroundColor3 = color or Color3.new(1, 1, 1), BackgroundTransparency = 0.3, ZIndex = 35 }, holder)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(1, 1) }) }, l)
		table.insert(lines, l)
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - t0) / (dur or 0.8)
		if u >= 1 or not holder.Parent then conn:Disconnect() holder:Destroy() return end
		for _, l in ipairs(lines) do
			l.Visible = math.random() < 0.7
			l.Size = UDim2.new(0, l.Size.X.Offset, 0.42 + math.random() * 0.2, 0)
			l.BackgroundTransparency = 0.25 + u * 0.7
		end
	end)
	return holder
end

-- SUN BURST: the sun rays and bloom spike for a moment (reveals, victories)
-- (two bursts close together used to read the first one's half-faded glow as "normal" and settle back to it: the
-- bloom crept up a little with every reveal. The resting value is kept until the last burst has faded)
local burstBase = {} :: { [Instance]: { Value: number, Gen: number } }
local function burstOf(fx: Instance, dur: number, peak: (number) -> number)
	local rec = burstBase[fx]
	if not rec then
		rec = { Value = (fx :: any).Intensity, Gen = 0 }
		burstBase[fx] = rec
	end
	rec.Gen += 1
	local gen = rec.Gen
	local base = rec.Value
	;(fx :: any).Intensity = peak(base)
	TweenService:Create(fx, TweenInfo.new(dur, Enum.EasingStyle.Quad), { Intensity = base }):Play()
	task.delay(dur + 0.05, function()
		if burstBase[fx] == rec and rec.Gen == gen then burstBase[fx] = nil end
	end)
end
function CineKit.SunBurst(strength: number?)
	local k = strength or 1
	local rays = (Lighting:FindFirstChild("DinoSunRays") or Lighting:FindFirstChildOfClass("SunRaysEffect")) :: SunRaysEffect?
	local bloom = (Lighting:FindFirstChild("DinoBloom") or Lighting:FindFirstChildOfClass("BloomEffect")) :: BloomEffect?
	if rays then burstOf(rays, 1.4, function(was) return math.max(was, 0.35 * k) end) end
	if bloom then burstOf(bloom, 1.0, function(was) return was + 1.2 * k end) end
end

-- THE BIG HIT: everything at once (a reveal, a knockout, a ruler) - impact frame, hit-stop, sun burst
function CineKit.BigHit(gui: Instance?, strength: number?)
	local k = strength or 1
	CineKit.ImpactFrame(k)
	CineKit.HitStop(0.12 * k, 0, 0.3)
	CineKit.SunBurst(k)
	if gui then CineKit.SpeedLines(gui, 0.45, Color3.new(1, 1, 1)) end
	DinosaurVFX.Shake(0.9 * k, 0.35)
end

function CineKit.Burst(pos: Vector3, scale: number?, palette: { Color3 }?)
	local k = scale or 1
	local cols = palette or CineKit.Leaf
	DinosaurVFX.Cubes(pos, math.floor(26 * k), cols, 0.55 * k, 26 * k, 1.1)
	DinosaurVFX.Cubes(pos, math.floor(10 * k), { Color3.new(1, 1, 1), Color3.fromRGB(255, 226, 120) }, 0.3 * k, 34 * k, 0.6)
	DinosaurVFX.BlockRing(CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0), { Count = math.floor(20 * k), R0 = 1, R1 = 14 * k, Color = cols[1], Duration = 0.6, Block = 0.9 * k })
	DinosaurVFX.FoliageBurst(pos, 1.2 * k)
	DinosaurVFX.Shake(0.8 * k, 0.4)
end

function CineKit.Sparkle(pos: Vector3, color: Color3, scale: number?)
	local k = scale or 1
	DinosaurVFX.Cubes(pos, math.floor(18 * k), { color, color:Lerp(Color3.new(1, 1, 1), 0.5), Color3.new(1, 1, 1) }, 0.3 * k, 16 * k, 0.9)
	DinosaurVFX.BlockRing(CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 14, R0 = 0.5, R1 = 7 * k, Color = color, Duration = 0.5 })
end

function CineKit.Punch(amount: number?)
	local cam = Workspace.CurrentCamera
	cam.FieldOfView += amount or 8
	local blur = Instance.new("BlurEffect")
	blur.Name = "DinoPunchBlur"
	blur.Size = 10
	blur.Parent = Lighting
	TweenService:Create(blur, TweenInfo.new(0.3), { Size = 0 }):Play()
	task.delay(0.32, function() blur:Destroy() end)
end

return CineKit
