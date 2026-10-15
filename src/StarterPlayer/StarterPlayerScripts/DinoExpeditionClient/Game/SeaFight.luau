--[[
	SeaFight — what the sea ruler's moves look and feel like on your screen (the server rules are in SeaKing.luau).
	  SeaBubbles  a boiling ring of bubbles + foam where it's about to erupt (the red Tele disc marks the danger)
	  SeaSplash   a column of water + spray when it bursts out / crashes down
	  SeaWave     a rolling crest that sweeps across the ring (the server hits you as the crest REACHES you: jump it)
	  SeaGrab     you're caught: dragged along in its jaws (your camera keeps working). A big round button throbs on
	              your screen and every press - jump, click, tap, a face button - is a kick against its jaws, a ring
	              filling up as you fight free; everyone else sees the boss flash red while it holds someone.
	              (2026-10-14, show don't tell: no "MASH JUMP" / "DART IT!" / "JUMP!" text any more)
	  SeaRelease  let go: you're thrown back onto the nearest dock / the ring
	  SeaWhirl    the whirlpool: a spinning vortex in the middle that pulls you in while you stand near it
	  docks       a DockSection the server marks Broken splinters into flying planks; it floats back up later
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DinosaurVFX = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("DinosaurVFX"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)

local player = Players.LocalPlayer
local SeaFight = {}
local View = nil -- ExpeditionView (creatures)

local function fxPart(at: Vector3): BasePart
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	p.Parent = Workspace
	return p
end

local function emitter(host: BasePart, o)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.Texture or "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = o.Rate or 0
	e.Lifetime = NumberRange.new(o.Life[1], o.Life[2])
	e.Speed = NumberRange.new(o.Speed[1], o.Speed[2])
	e.SpreadAngle = Vector2.new(o.Spread or 20, o.Spread or 20)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = o.Accel or Vector3.zero
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Size[1]), NumberSequenceKeypoint.new(1, o.Size[2]) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.T or 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(o.Color or Color3.fromRGB(230, 248, 255))
	e.LightEmission = 0.15
	e.Parent = host
	return e
end

local function creatureById(id: number)
	if not View then return nil end
	for cfg, c in pairs(View.Creatures()) do
		if cfg:GetAttribute("Id") == id then return c end
	end
	return nil
end

--------------------------------------------------------------------------------
-- effects
--------------------------------------------------------------------------------
local function bubbles(info)
	local at, t, r = info.At, info.Time or 1.5, info.R or 8
	local host = fxPart(at + Vector3.new(0, 0.2, 0))
	host.Size = Vector3.new(r * 1.6, 0.4, r * 1.6)
	local b = emitter(host, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 60, Life = { 0.4, 0.8 }, Speed = { 2, 5 }, Spread = 10, Size = { 0.7, 0.2 }, T = 0.1 })
	local foam = emitter(host, { Rate = 10, Life = { 0.6, 1 }, Speed = { 0.5, 1.5 }, Spread = 80, Size = { 1.6, 3.2 }, T = 0.35 })
	-- it rises toward the end: the boil gets violent
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < t do
			local u = (os.clock() - t0) / t
			b.Rate = 40 + u * 160
			foam.Rate = 6 + u * 30
			task.wait(0.1)
		end
		b.Enabled, foam.Enabled = false, false
		task.delay(1.2, function() host:Destroy() end)
	end)
end

local function splash(info)
	local at, size = info.At, info.Size or 1.5
	DinosaurVFX.WaterSplash(at, size)
	require(script.Parent.Audio).Play(size >= 3 and "Breach" or "Splash", { At = at, Volume = math.clamp(size / 2.5, 0.6, 1.4) })
	local host = fxPart(at)
	emitter(host, { Life = { 0.6, 1.1 }, Speed = { 18 * size, 30 * size }, Spread = 18, Accel = Vector3.new(0, -60, 0), Size = { 1.6 * size, 3.4 * size }, T = 0.15 }):Emit(40)
	emitter(host, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Life = { 0.5, 1 }, Speed = { 10, 22 }, Spread = 60, Accel = Vector3.new(0, -40, 0), Size = { 0.5, 0.2 }, T = 0 }):Emit(50)
	task.delay(1.6, function() host:Destroy() end)
	-- a jolt for everyone close by (as big as the splash)
	DinosaurVFX.Shake(math.clamp(size * 0.4, 0.3, 1.3), 0.35 + size * 0.06, at, 90)
end

local function wave(info)
	local o, from, to, t = info.O, info.From or 20, info.To or 40, info.Time or 1.3
	local mid = (from + to) / 2
	local n = 40
	local blocks = {}
	for k = 1, n do
		local a = (k / n) * math.pi * 2
		local b = Instance.new("Part")
		b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
		b.Material = Enum.Material.SmoothPlastic
		b.Color = k % 3 == 0 and Color3.fromRGB(235, 250, 255) or Color3.fromRGB(80, 180, 220)
		b.Transparency = 0.25
		b.Size = Vector3.new((2 * math.pi * mid) / n + 0.6, 0.2, 3)
		b.CFrame = CFrame.new(o + Vector3.new(math.cos(a) * from, 0.2, math.sin(a) * from)) * CFrame.Angles(0, -a, 0)
		b.Parent = Workspace
		blocks[k] = { Part = b, A = a }
	end
	-- the crest builds at the inner edge, then rolls out across the band and breaks at the moment it hits
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local u = (os.clock() - t0) / t
			if u >= 1.25 then break end
			local r = from + (to - from) * math.clamp((u - 0.3) / 0.75, 0, 1)
			local h = math.sin(math.clamp(u, 0, 1) * math.pi * 0.95) * 3.6 + 0.4
			for _, bk in ipairs(blocks) do
				bk.Part.Size = Vector3.new(bk.Part.Size.X, h, 3)
				bk.Part.CFrame = CFrame.new(o + Vector3.new(math.cos(bk.A) * r, h / 2, math.sin(bk.A) * r)) * CFrame.Angles(0, -bk.A, 0)
				bk.Part.Transparency = u > 1 and math.clamp(0.25 + (u - 1) * 3, 0, 1) or 0.25
			end
			RunService.Heartbeat:Wait()
		end
		for _, bk in ipairs(blocks) do bk.Part:Destroy() end
	end)
end

--------------------------------------------------------------------------------
-- the grab
--------------------------------------------------------------------------------
local grab = nil :: any
local cueGui = nil :: any
local bannerToken = 0
local function banner(text: string, color: Color3, dur: number)
	if not cueGui then
		local _, canvas = Kit.Screen("DinoSeaBanner", 12, false, 0.75)
		cueGui = Kit.Text(canvas, "", { Size = UDim2.fromOffset(640, 54), Position = UDim2.new(0.5, 0, 0.22, 0), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 4, Shadow = 4, MaxSize = 44, ZIndex = 30 })
	end
	Kit.SetText(cueGui, text)
	Kit.SetTextColor(cueGui, color)
	cueGui.Visible = true
	bannerToken += 1
	local mine = bannerToken
	task.delay(dur, function() if cueGui and bannerToken == mine then cueGui.Visible = false end end)
end

-- the struggle button: a big round button with an up-arrow, throbbing in the middle of the screen while you're in
-- its jaws. Every press kicks it (punch + splash) and fills the white ring inside it - the picture says "keep
-- hitting it", no words
local struggle = nil :: any
local function struggleUi(on: boolean)
	if not on then
		if struggle then struggle.Gui:Destroy() struggle = nil end
		return
	end
	if struggle then return end
	local gui, canvas = Kit.Screen("DinoSeaStruggle", 13, false, 0.75)
	local btn = Instance.new("Frame")
	btn.Name = "Struggle"
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.new(0.5, 0, 0.68, 0)
	btn.Size = UDim2.fromOffset(132, 132)
	btn.BackgroundColor3 = Color3.fromRGB(64, 186, 240)
	btn.Parent = canvas
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = btn
	local scale = Instance.new("UIScale")
	scale.Parent = btn
	-- the fill: a white disc growing from the middle with every press
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.fromScale(0.5, 0.5)
	fill.Size = UDim2.fromScale(0, 0)
	fill.BackgroundColor3 = Color3.fromRGB(190, 240, 255)
	fill.BorderSizePixel = 0
	fill.Parent = btn
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	-- the up-arrow: two thick bars in a chevron
	for _, sgn in ipairs({ -1, 1 }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(0.5, sgn * 15, 0.5, -2)
		bar.Size = UDim2.fromOffset(48, 16)
		bar.Rotation = sgn * 42
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BorderSizePixel = 0
		bar.ZIndex = 3
		bar.Parent = btn
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = bar
		local bs = Instance.new("UIStroke")
		bs.Thickness = 3
		bs.Color = Color3.new(0, 0, 0)
		bs.Parent = bar
	end
	struggle = { Gui = gui, Btn = btn, Fill = fill, Scale = scale, Kick = 0 }
end

-- a teammate is in its jaws: the boss throbs red (dart it!) until it lets go
local heldGlow: Highlight? = nil
local glowUntil = 0 -- (the grab's own time + a little: a release you were too far to hear never leaves it on)
local function glowHolder(actor: number?)
	if heldGlow then heldGlow:Destroy() heldGlow = nil end
	local c = actor and creatureById(actor)
	if not (c and c.Model) then return end
	local h = Instance.new("Highlight")
	h.Name = "DinoGrabGlow"
	h.FillColor = Color3.fromRGB(255, 60, 40)
	h.OutlineColor = Color3.fromRGB(255, 230, 120)
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = c.Model
	heldGlow = h
end

local function onGrab(info)
	do
		local c = creatureById(info.Actor)
		local root = c and c.Root
		require(script.Parent.Audio).Play("SeaRoar", { At = root or (Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position) })
	end
	if info.UserId ~= player.UserId then
		glowHolder(info.Actor)
		glowUntil = os.clock() + (tonumber(info.Time) or 5.5) + 2
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	grab = { Actor = info.Actor, Until = os.clock() + (info.Time or 5.5), Presses = 0 }
	hrp.Anchored = true
	struggleUi(true)
end

local function onRelease(info)
	glowHolder(nil)
	if info.UserId ~= player.UserId then
		if info.How == "Freed" then banner("FREED!", Color3.fromRGB(140, 255, 120), 1.4) end
		return
	end
	grab = nil
	struggleUi(false)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = false
		if typeof(info.To) == "Vector3" then
			-- flung back up onto the planks
			char:PivotTo(CFrame.new(info.To + Vector3.new(0, 3.2, 0)))
			hrp.AssemblyLinearVelocity = Vector3.new(0, 26, 0)
		end
		splash({ At = hrp.Position, Size = 1 })
	end
	banner(info.How == "Timeout" and "IT LET YOU GO!" or "BROKE FREE!", Color3.fromRGB(140, 255, 120), 1.4)
end

--------------------------------------------------------------------------------
-- the whirlpool
--------------------------------------------------------------------------------
local whirl = nil :: any
local function onWhirl(info)
	if whirl and whirl.Fx then whirl.Fx:Destroy() end
	whirl = nil
	if (info.Time or 0) <= 0 then return end
	local o = info.O
	local fx = Instance.new("Model")
	fx.Name = "Whirlpool"
	local rings = {}
	for k = 1, 3 do
		local r = Instance.new("Part")
		r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch, r.CastShadow = true, false, false, false, false
		r.Shape = Enum.PartType.Cylinder
		r.Material = Enum.Material.SmoothPlastic
		r.Color = k == 1 and Color3.fromRGB(20, 70, 100) or Color3.fromRGB(150, 220, 240)
		r.Transparency = 0.35 + k * 0.12
		-- (the vortex fills the Maw's pool, whatever its size)
		local pool = (info.Inner or 14) * 2 - 4
		r.Size = Vector3.new(0.3, pool * (0.45 + k * 0.18), pool * (0.45 + k * 0.18))
		r.Parent = fx
		rings[k] = r
	end
	local host = fxPart(o + Vector3.new(0, 0.3, 0))
	host.Parent = fx
	emitter(host, { Rate = 30, Life = { 0.8, 1.4 }, Speed = { 2, 6 }, Spread = 90, Size = { 2, 5 }, T = 0.4 })
	-- the roar of the water, from the middle of it (it goes when the whirlpool's model does)
	local roar = require(script.Parent.Audio).Loop("Whirlpool", host)
	if roar then roar.RollOffMaxDistance = 220 roar.RollOffMinDistance = 20 end
	fx.Parent = Workspace
	whirl = { O = o, Until = os.clock() + info.Time, Pull = info.Pull or 10, R = info.R or 38, Fx = fx, Rings = rings }
end

--------------------------------------------------------------------------------
-- docks: splinter + float back
--------------------------------------------------------------------------------
local function watchDock(m: Instance)
	m:GetAttributeChangedSignal("Broken"):Connect(function()
		local broken = m:GetAttribute("Broken") == true
		if broken then
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "Plank" and math.random() < 0.6 then
					-- a plank flies off
					local c = p:Clone()
					c.Anchored = false
					c.CanCollide = false
					c.Transparency = 0
					c.Parent = Workspace
					c.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 30, 30 + math.random() * 25, (math.random() - 0.5) * 30)
					c.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
					task.delay(2.2, function() c:Destroy() end)
				end
			end
		else
			-- back up from the water: the planks rise into place
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.Transparency < 1 then
					local cf = p.CFrame
					p.CFrame = cf - Vector3.new(0, 4, 0)
					TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Back), { CFrame = cf }):Play()
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
function SeaFight.Start(expeditionView)
	View = expeditionView
	Net.On("SeaBubbles", bubbles)
	Net.On("SeaSplash", splash)
	Net.On("SeaWave", wave)
	Net.On("SeaGrab", onGrab)
	Net.On("SeaRelease", onRelease)
	Net.On("SeaWhirl", onWhirl)
	for _, m in ipairs(CollectionService:GetTagged("DockSection")) do watchDock(m) end
	CollectionService:GetInstanceAddedSignal("DockSection"):Connect(watchDock)
	-- struggling while caught: whatever you mash counts (jump, a click, a tap, any face button or trigger)
	local MASH = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.ButtonA] = true, [Enum.KeyCode.ButtonB] = true, [Enum.KeyCode.ButtonX] = true,
		[Enum.KeyCode.ButtonY] = true, [Enum.KeyCode.ButtonR2] = true, [Enum.KeyCode.ButtonL2] = true, [Enum.KeyCode.E] = true }
	-- (2026-10-14: the ring fills only with the kicks the server COUNTED. Requests are rate-limited server-side to one
	-- per 0.15 s, so a kid mashing 10 a second filled the ring in a second while the server had counted 7 - a full
	-- ring and still stuck. Every press still kicks and splashes; one goes to the server every 0.17 s)
	local lastSend = 0
	local function press()
		if not grab then return end
		local g = grab
		g.Presses += 1
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then DinosaurVFX.WaterSplash(hrp.Position, 0.5) end
		if struggle then struggle.Kick = 1 end
		if os.clock() - lastSend < 0.17 then return end
		lastSend = os.clock()
		task.spawn(function()
			local res = Net.Ask("SeaMash")
			if not (res and res.Ok) or grab ~= g then return end
			g.Counted = (g.Counted or 0) + 1
			if struggle then
				local k = math.clamp(g.Counted / 12, 0, 1)
				TweenService:Create(struggle.Fill, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.fromScale(k * 0.92, k * 0.92) }):Play()
			end
		end)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not grab then return end
		if MASH[input.KeyCode] or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then press() end
		local _ = processed
	end)
	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- caught: ride in its jaws
		if grab and hrp then
			local c = creatureById(grab.Actor)
			if c and c.Root then
				local head = c.Root.CFrame * CFrame.new(0, 1.5, -(c.Rad or 8) * 0.8)
				hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(head.Position) * CFrame.Angles(0, os.clock() * 3, 0.6), math.min(1, dt * 8))
			end
			if os.clock() > grab.Until + 2 then grab = nil hrp.Anchored = false struggleUi(false) end -- (the server always releases; a safety net)
		end
		-- the struggle button throbs, and jumps on every press
		if struggle then
			if not grab then struggleUi(false) else
				struggle.Kick = math.max(0, struggle.Kick - dt * 6)
				struggle.Scale.Scale = 1 + math.abs(math.sin(os.clock() * 9)) * 0.08 + struggle.Kick * 0.18
			end
		end
		if heldGlow and (os.clock() > glowUntil or player:GetAttribute("Site") == nil) then glowHolder(nil) end
		if heldGlow then
			if not heldGlow.Parent then heldGlow = nil else heldGlow.FillTransparency = 0.35 + math.abs(math.sin(os.clock() * 8)) * 0.4 end
		end
		-- the whirlpool: spin the vortex, drag nearby feet toward the middle
		if whirl then
			if os.clock() > whirl.Until then
				if whirl.Fx then whirl.Fx:Destroy() end
				whirl = nil
			else
				local t = os.clock()
				for k, r in ipairs(whirl.Rings) do
					r.CFrame = CFrame.new(whirl.O + Vector3.new(0, 0.15 + k * 0.05, 0)) * CFrame.Angles(0, t * (1.5 + k), 0) * CFrame.Angles(0, 0, math.pi / 2)
				end
				-- (only a hunter on foot still in the fight: sitting in the boat / a rover, sliding the root would drag the
				-- whole vehicle - 2026-10-14)
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local onFoot = player:GetAttribute("Site") ~= nil and not (hum and hum.SeatPart)
				if hrp and not grab and onFoot and not hrp.Anchored then
					local d = Vector3.new(whirl.O.X - hrp.Position.X, 0, whirl.O.Z - hrp.Position.Z)
					if d.Magnitude < whirl.R and d.Magnitude > 1 then
						local pull = d.Unit * whirl.Pull * (1 - d.Magnitude / whirl.R * 0.5)
						local swirl = Vector3.new(-d.Unit.Z, 0, d.Unit.X) * whirl.Pull * 0.4
						-- slide the body (the walk controller would undo a velocity nudge): you can still run against it
						hrp.CFrame += (pull + swirl) * dt * 0.55
					end
				end
			end
		end
	end)
end

return SeaFight
