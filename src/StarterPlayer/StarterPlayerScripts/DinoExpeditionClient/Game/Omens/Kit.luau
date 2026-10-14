--[[
	Omens.Kit — the shared toolbox for the era omens (Game/Omens/<Era>.luau).

	  K.Scene(name, body)            a wordless camera beat: letterbox, grade, skip after 1 s (tap / Space / A), and the
	                                 camera, HUD and drive camera always handed back, even if the body errors
	    sc:Run(dur, fn(u, t, dt))    per-frame loop for dur seconds (stops early on a skip); returns true if skipped
	    sc:Cam(cf, fov)              place the camera (with the scene's own shake on top)
	    sc:Shake(amp, dur)  sc:Fade(a, t, color?)  sc:Grade(preset, t)  sc:Hush(on)  sc:Skipped()
	  K.Props(name)                  a world folder for a trace (anchored, no collision, never in a raycast)
	  K.Part(parent, props)          one prop part; K.Flat(v); K.Ground(p); K.Clear(a, b); K.Water(p)
	  K.Pace(actor, speed, dt)       speeds a running/walking rig's legs up to match how fast it is really moving
	  K.PreviewDrive(zone, s0, dur, body)  a stand-in rover driving the road under a chase camera (gallery previews)
	  K.Step()  K.Glint(pos)  K.Top(p) (canopies count)  K.Road(route, vi, s, x)  K.OpenSide(...)  K.Statue(...)
	Everything is client-side; nothing here touches the server, so a beat can never break a run.
]]

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Game = script.Parent.Parent

local K = {}
K.Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))
K.RouteMath = require(Shared:WaitForChild("Game"):WaitForChild("RouteMath"))
K.VFX = require(Shared:WaitForChild("DinosaurVFX"))
K.Net = require(Game.Net)
K.Drive_ = require(Game.Drive)
K.Audio = require(Game.Audio)
K.Cinema = require(Game.UI.Cinema)
K.CineKit = require(Game.UI.CineKit)
K.Stage = require(Game.TikTok.Stage)
K.Fx = require(Game.TikTok.Fx)
K.Zone = require(Game.Zone)

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- profile flags (a beat plays once; Flags.Tips "Omen_<Zone>_<Beat>")
--------------------------------------------------------------------------------
function K.Profile() return K.Net.Profile end

function K.Seen(key: string): boolean
	local p = K.Net.Profile
	return p ~= nil and p.Flags ~= nil and p.Flags.Tips ~= nil and p.Flags.Tips[key] == true
end

function K.MarkSeen(key: string)
	local p = K.Net.Profile
	if p and p.Flags then
		p.Flags.Tips = p.Flags.Tips or {}
		p.Flags.Tips[key] = true
	end
	task.spawn(function()
		for _ = 1, 4 do
			local res = K.Net.Ask("Tip", { Key = key })
			if not (res and res.Err == "slow down") then return end
			task.wait(0.3)
		end
	end)
end

function K.Beaten(bossId: string): boolean
	local p = K.Net.Profile
	return p ~= nil and p.Bosses ~= nil and p.Bosses[bossId] ~= nil and (p.Bosses[bossId].Best or 0) >= 1
end

--------------------------------------------------------------------------------
-- maths + world
--------------------------------------------------------------------------------
function K.smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end
function K.easeOut(u: number): number
	u = math.clamp(u, 0, 1)
	return 1 - (1 - u) * (1 - u)
end
function K.easeIn(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u
end
function K.Flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
end
K.Ground = function(p: Vector3, up: number?): Vector3 return K.Stage.Ground(p, up) end
-- where a dinosaur stands: the era's walkable floor only (never on a rock, log or bush - Floor.luau)
K.Floor = require(Game.Floor).At
K.Clear = function(a: Vector3, b: Vector3): boolean return K.Stage.Clear(a, b) end

-- the highest thing under p, leaves and canopies included (the snow on a pine, the top of a cliff)
local topRay = RaycastParams.new()
topRay.FilterType = Enum.RaycastFilterType.Exclude
function K.Top(p: Vector3, up: number?): Vector3
	local skip = { K.Stage.Root() :: Instance }
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(skip, plr.Character) end end
	for _, n in ipairs({ "ActiveVehicles", "DinoExpeditionLocal", "DinoAmbience", "DinoOmens" }) do
		local f = Workspace:FindFirstChild(n)
		if f then table.insert(skip, f) end
	end
	topRay.FilterDescendantsInstances = skip
	local h = up or 120
	local hit = Workspace:Raycast(p + Vector3.new(0, h, 0), Vector3.new(0, -(h + 200), 0), topRay)
	return hit and hit.Position or p
end

-- Terrain water under p? (returns the surface height)
local waterRay = RaycastParams.new()
waterRay.FilterType = Enum.RaycastFilterType.Include
waterRay.IgnoreWater = false
function K.Water(p: Vector3): (boolean, number)
	waterRay.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(p.X, 60, p.Z), Vector3.new(0, -120, 0), waterRay)
	if hit and hit.Material == Enum.Material.Water then return true, hit.Position.Y end
	return false, 0
end

-- a point on the road (s along it, x across it: + is right of travel), on the ground
function K.Road(route, vi: number, s: number, x: number): (Vector3, Vector3, Vector3)
	local p, f, r = route:Sample(vi, s)
	return K.Ground(p + r * x, 30), f, r
end

-- which side of the road is more open between s0 and s1 (lower scenery at x = +-dist)? -> 1 (right) / -1 (left)
function K.OpenSide(route, vi: number, s0: number, s1: number, dist: number): number
	local score = { [1] = 0, [-1] = 0 }
	local base = 0
	for s = s0, s1, math.max(8, (s1 - s0) / 6) do
		local p = route:Sample(vi, s)
		base = p.Y
		for _, side in ipairs({ 1, -1 }) do
			local q = route:Position(vi, s, side * dist)
			score[side] += math.max(0, K.Top(q, 60).Y - base)
		end
	end
	return score[1] <= score[-1] and 1 or -1
end

--------------------------------------------------------------------------------
-- props
--------------------------------------------------------------------------------
local function omenRoot(): Folder
	local f = Workspace:FindFirstChild("DinoOmens")
	if not f then
		f = Instance.new("Folder")
		f.Name = "DinoOmens"
		f.Parent = Workspace
	end
	return f :: Folder
end
K.Root = omenRoot

function K.Props(name: string): Folder
	local old = omenRoot():FindFirstChild(name)
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = omenRoot()
	return f
end

-- props: Size, CFrame, Color, Material, Transparency, Reflectance, Shape ("Ball"/"Cylinder"), Class ("WedgePart"),
-- Shadow (cast a shadow), Name
function K.Part(parent: Instance, props): BasePart
	local p = Instance.new(props.Class or "Part") :: any
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = props.Shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Transparency = props.Transparency or 0
	p.Reflectance = props.Reflectance or 0
	if props.Shape then p.Shape = Enum.PartType[props.Shape] end
	p.Size = props.Size or Vector3.new(1, 1, 1)
	p.CFrame = props.CFrame or CFrame.new()
	p.Name = props.Name or "OmenProp"
	p.Parent = parent
	return p
end

-- a flat slab lying on the ground at p (yaw about up), its top just above the surface
function K.Slab(parent: Instance, p: Vector3, size: Vector3, yaw: number, props): BasePart
	local g = K.Ground(p, 12)
	local q = table.clone(props or {})
	q.Size = size
	q.CFrame = CFrame.new(g.X, g.Y + size.Y / 2 + (q.Lift or 0.03), g.Z) * CFrame.Angles(0, yaw, 0)
	return K.Part(parent, q)
end

-- a clean copy of a dinosaur rig as a still prop (a frozen compy, a trophy)
function K.Statue(parent: Instance, species: string, scale: number, at: Vector3, face: Vector3): Model?
	local t = Shared:FindFirstChild("Dinosaurs") and Shared.Dinosaurs:FindFirstChild(species)
	if not t then return nil end
	local m = t:Clone() :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	if scale ~= 1 then m:ScaleTo(scale) end
	local bb, size = m:GetBoundingBox()
	local lift = m:GetPivot().Position.Y - (bb.Position.Y - size.Y / 2)
	local g = K.Ground(at, 12)
	local base = Vector3.new(g.X, g.Y + lift, g.Z)
	m:PivotTo(CFrame.lookAt(base, base + K.Flat(face)))
	m.Parent = parent
	return m
end

-- an idle loop for a trace: runs fn(dt) only while the camera is within `range` (so five eras cost nothing)
function K.Near(folder: Instance, centre: Vector3, range: number, fn: (number) -> ())
	task.spawn(function()
		while folder.Parent do
			local cam = Workspace.CurrentCamera
			if cam and (cam.CFrame.Position - centre).Magnitude < range then
				local ok, err = pcall(fn, 0.1)
				if not ok then warn("[Omens] trace loop:", err) return end
				task.wait(0.1)
			else
				task.wait(0.6)
			end
		end
	end)
end

-- one rendered frame; returns dt
function K.Step(): number
	return RunService.RenderStepped:Wait()
end

-- a star of light catching the sun (a tooth, an ice crystal): a neon cross that blooms and fades
function K.Glint(pos: Vector3, size: number?)
	local k = size or 1
	local f = omenRoot()
	local cam = Workspace.CurrentCamera
	local face = cam and CFrame.lookAt(pos, cam.CFrame.Position) or CFrame.new(pos)
	for i = 0, 1 do
		local p = K.Part(f, { Size = Vector3.new(0.06, 0.06, 0.02), CFrame = face * CFrame.Angles(0, 0, i * math.pi / 2 + math.pi / 4), Color = Color3.fromRGB(255, 248, 225), Material = Enum.Material.Neon, Name = "OmenGlint" })
		local grow = TweenService:Create(p, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(2.4 * k, 0.12 * k, 0.02) })
		grow:Play()
		grow.Completed:Connect(function()
			TweenService:Create(p, TweenInfo.new(0.32), { Size = Vector3.new(0.1, 0.04, 0.02), Transparency = 1 }):Play()
		end)
		task.delay(0.6, function() p:Destroy() end)
	end
end

-- legs keep up with the body: a rig moving faster than its gait gets its step rate raised to match
function K.Pace(actor, speed: number, dt: number)
	local anim = actor and actor.Anim
	if not anim then return end
	local gait = anim.Profile.Gait
	local w = anim.LocoWeights
	local own = (w.Run or 0) > (w.Walk or 0) and actor.RunSpeed or actor.WalkSpeed
	local freq = (w.Run or 0) > (w.Walk or 0) and gait.Run.Freq or gait.Walk.Freq
	if own <= 0 then return end
	local k = math.clamp(speed / own, 0.5, 2.6)
	anim.GaitPhase += dt * freq * (k - 1)
end

--------------------------------------------------------------------------------
-- scenes (wordless, short, skippable after a second)
--------------------------------------------------------------------------------
local GRADES = {
	Neutral = { 0, 0.06, 0.08, Color3.fromRGB(255, 252, 246) },
	Golden = { 0.02, 0.16, 0.28, Color3.fromRGB(255, 226, 176) },
	Dusk = { -0.04, 0.2, 0.16, Color3.fromRGB(255, 208, 180) },
	Frost = { 0.03, 0.1, -0.12, Color3.fromRGB(222, 236, 255) },
	Jungle = { -0.02, 0.14, 0.22, Color3.fromRGB(236, 255, 236) },
	Dawn = { 0.02, 0.18, 0.26, Color3.fromRGB(255, 212, 186) },
	Shadow = { -0.22, 0.22, -0.1, Color3.fromRGB(196, 186, 214) },
	Backlit = { -0.06, 0.3, 0.18, Color3.fromRGB(255, 192, 146) },
}

local busy = false
function K.Busy(): boolean return busy end

local Scene = {}
Scene.__index = Scene

local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end

-- run a beat; if it errors part-way, whatever stage sets it put up (the silhouetted boss, its props) come down with it
function K.Guarded(fn: (...any) -> any, ...): (boolean, any)
	local rootF = K.Stage.Root()
	local before = {}
	for _, c in ipairs(rootF:GetChildren()) do before[c] = true end
	local ok, res = pcall(fn, ...)
	if not ok then
		for _, c in ipairs(rootF:GetChildren()) do if not before[c] then c:Destroy() end end
	end
	return ok, res
end

function K.Scene(name: string, body: (any) -> (), opts: any?): boolean
	opts = opts or {}
	if busy then return false end
	busy = true
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoOmenUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = pg
	local token = K.Cinema.Begin("DinoOmenUI")
	local bars = {}
	for i, a in ipairs({ 0, 1 }) do
		bars[i] = frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, a), Position = UDim2.fromScale(0, a), Size = UDim2.fromScale(1, 0), ZIndex = 5 })
		TweenService:Create(bars[i], TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 0.085) }):Play()
	end
	local veil = frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DinoOmenGrade"
	grade.Parent = Lighting
	local cam = Workspace.CurrentCamera
	local savedFov = cam.FieldOfView
	K.Drive_.HoldCamera(true)
	K.Drive_.SetCameraOverride(true)
	cam.CameraType = Enum.CameraType.Scriptable

	local sc = setmetatable({ Name = name, Gui = gui, Veil = veil, GradeFx = grade, Camera = cam, Start = os.clock(), SkippedFlag = false, ShakeAmp = 0, ShakeUntil = 0, Hushed = false }, Scene)
	local function trySkip()
		if os.clock() - sc.Start > 1 then sc.SkippedFlag = true end
	end
	ContextActionService:BindAction("DinoOmenSkip", function(_, st)
		if st == Enum.UserInputState.Begin then trySkip() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
	local tapConn = UserInputService.TouchTap:Connect(trySkip)
	local clickConn = UserInputService.InputBegan:Connect(function(io, gp)
		if not gp and io.UserInputType == Enum.UserInputType.MouseButton1 then trySkip() end
	end)

	local ok, err = K.Guarded(body, sc)
	if not ok then warn("[Omens] scene " .. name .. ":", err) end

	tapConn:Disconnect()
	clickConn:Disconnect()
	ContextActionService:UnbindAction("DinoOmenSkip")
	-- out through black, so the hand-back never pops
	TweenService:Create(veil, TweenInfo.new(0.15), { BackgroundTransparency = 0 }):Play()
	task.wait(0.16)
	if sc.Hushed then K.Audio.AmbienceLevel(1) end
	K.CineKit.ResetTime()
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = savedFov
	K.Drive_.HoldCamera(false)
	K.Drive_.SetCameraOverride(false)
	grade:Destroy()
	for _, b in ipairs(bars) do TweenService:Create(b, TweenInfo.new(0.3), { Size = UDim2.fromScale(1, 0) }):Play() end
	TweenService:Create(veil, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	task.delay(0.4, function() gui:Destroy() end)
	K.Cinema.End(token)
	busy = false
	return ok
end

function Scene:Skipped(): boolean return self.SkippedFlag end

function Scene:Shake(amp: number, dur: number)
	amp *= K.VFX.ShakeScale or 1
	self.ShakeAmp = math.max(self.ShakeAmp, amp)
	self.ShakeUntil = math.max(self.ShakeUntil, os.clock() + dur)
end

function Scene:Cam(cf: CFrame, fov: number?)
	local now = os.clock()
	if now < self.ShakeUntil then
		local k = self.ShakeAmp * math.clamp((self.ShakeUntil - now) / 0.4, 0, 1)
		local n = now * 23
		cf *= CFrame.new(math.noise(n, 1.3) * k * 0.3, math.noise(n, 7.1) * k * 0.3, 0) * CFrame.Angles(math.noise(n, 4.1) * k * 0.012, math.noise(n, 9.7) * k * 0.012, math.noise(n, 3.7) * k * 0.02)
	else
		self.ShakeAmp = 0
	end
	self.Camera.CFrame = cf
	if fov then self.Camera.FieldOfView = fov end
end

-- runs fn(u, t, dt) every frame for dur seconds; returns true if the player skipped
function Scene:Run(dur: number, fn: ((number, number, number) -> ())?): boolean
	local t0 = os.clock()
	local last = t0
	while true do
		local now = os.clock()
		local t = now - t0
		if self.SkippedFlag then return true end
		if fn then fn(math.clamp(t / math.max(dur, 1e-3), 0, 1), t, now - last) end
		last = now
		if t >= dur then return false end
		RunService.RenderStepped:Wait()
	end
end

function Scene:Fade(a: number, t: number, color: Color3?)
	if color then self.Veil.BackgroundColor3 = color end
	if t <= 0 then
		self.Veil.BackgroundTransparency = 1 - a
	else
		TweenService:Create(self.Veil, TweenInfo.new(t, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 - a }):Play()
	end
end

function Scene:Grade(preset: string, t: number?)
	local g = GRADES[preset] or GRADES.Neutral
	local goal = { Brightness = g[1], Contrast = g[2], Saturation = g[3], TintColor = g[4] }
	if (t or 0) <= 0.02 then
		for k, v in pairs(goal) do (self.GradeFx :: any)[k] = v end
	else
		TweenService:Create(self.GradeFx, TweenInfo.new(t :: number, Enum.EasingStyle.Sine), goal):Play()
	end
end

-- the era's ambience drops away (the hush before something big)
function Scene:Hush(on: boolean)
	self.Hushed = on
	K.Audio.AmbienceLevel(on and 0.25 or 1)
end

--------------------------------------------------------------------------------
-- previews (Settings > CUTSCENES): a beat played on location with a stand-in rover
--------------------------------------------------------------------------------

-- the arrival spot: a stand-in rover parked where the warp drops you; returns ctx for a sighting
function K.ArrivalCtx(set, zone: string)
	local route = K.RouteMath.get(zone)
	if not route then return nil end
	local s = 30
	local p, f = route:Sample(1, s)
	local rv = set:Rover()
	if rv then rv:Place(K.Ground(p, 20), f, 0) end
	local root = rv and rv.CF or CFrame.lookAt(p + Vector3.new(0, 2.6, 0), p + Vector3.new(0, 2.6, 0) + f)
	return { Zone = zone, Route = route, Vi = 1, S = s, Root = root }
end

-- the real arrival: your rover, parked at the start of the road
function K.LiveArrivalCtx(zone: string)
	local route = K.RouteMath.get(zone)
	local st = K.Drive_.State
	local root = st.Root
	if not (route and root) then return nil end
	return { Zone = zone, Route = route, Vi = st.Variant or 1, S = st.S or 30, Root = root.CFrame, Model = st.Vehicle }
end

-- the top of the rover's body at a point (the bonnet): a ray against the real rover, else a fair guess
function K.RoverTop(ctx, at: Vector3, guess: number): Vector3
	local m = ctx.Model
	if m and m.Parent then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { m }
		local hit = Workspace:Raycast(at + Vector3.new(0, 12, 0), Vector3.new(0, -24, 0), params)
		if hit then return hit.Position end
	end
	return Vector3.new(at.X, ctx.Root.Position.Y + guess, at.Z)
end

-- a stand-in rover drives the road at speed from s0 under a chase camera; the close-call beat reads ctx.S()
-- like it reads the real chase. Returns once `body` has finished (or after `dur`).
function K.PreviewDrive(zone: string, s0: number, dur: number, body: (any) -> ())
	local route = K.RouteMath.get(zone)
	if not route then return end
	local was = K.Zone.Current
	K.Zone.Apply(zone, true)
	local set = K.Stage.new("OmenPreviewDrive")
	set:Show()
	local rv = set:Rover()
	local state = { S = s0, Speed = 46, Done = false }
	local ctx = {
		Zone = zone, Route = route, Vi = 1, Preview = true,
		S = function() return state.S end,
		Speed = function() return state.Speed end,
		Active = function() return not state.Done end,
		RoverCF = function() return rv and rv.CF or route:Frame(1, state.S, 0) end,
		Knock = function() end,
	}
	K.Scene("OmenPreviewDrive", function(sc)
		local cam = sc.Camera
		local camPos: Vector3? = nil
		local travelled = 0
		task.spawn(function()
			local ok, err = pcall(body, ctx)
			if not ok then warn("[Omens] preview:", err) end
		end)
		sc:Run(dur, function(_, _, dt)
			dt = math.min(dt, 1 / 20)
			state.S += state.Speed * dt
			travelled += state.Speed * dt
			local p, f = route:Sample(1, state.S)
			local g = K.Ground(p, 20)
			if rv then rv:Place(g, f, travelled) end
			local want = g - f * 17 + Vector3.new(0, 7.5, 0)
			camPos = camPos and camPos:Lerp(want, math.min(1, dt * 6)) or want
			sc:Cam(CFrame.lookAt(camPos :: Vector3, g + f * 16 + Vector3.new(0, 2, 0)), 70)
			local _ = cam
		end)
		state.Done = true
	end)
	set:Destroy()
	K.Zone.Apply(was, true)
end

return K
