--[[
	TikTok.Fx — the extra cue kinds the boss reveals use (tools/gen/anim/reveals.js), plus per-shot colour grades,
	silhouettes and the cutscene letterbox. Everything is local and cleaned up by Fx.Reset (per shot) and
	Fx.RestoreWorld (end of the take: felled map trees stand back up).

	  Sfx slot vol pitch | Sting slot vol | Fx actorId event arg | Ripple pt scale | Leaves pt radius count
	  RoarWave actorId scale | Splash pt scale | LensDrops a | Snow density | White a dur | TreeFall basePt towardPt dur | TimeScale k
	  Title text sub color | Slash color | Grade preset dur | Splinter pt scale | Bubbles pt scale | Unblack
	  Bars height dur (2026-10-15: a film letterbox, each bar `height` of the screen, sliding in over `dur`; 0 opens it.
		A cut clears it - the map tour's aerials are the only letterboxed shots)
	  Birds pt count towardPt (a flock bursting out of the trees and flying off)
	  (2026-10-14) DustWave pt towardPt scale | Cracks pt scale | Glint pt scale | LensDrops a color | White a dur color
		(a coloured haze: "Dust" for the Titan) | actor Rim (the silhouette's rim light) | grades Deep, Storm, Ember
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurVFX = require(Shared:WaitForChild("DinosaurVFX"))

local Game = script.Parent.Parent
local CineKit = require(Game.UI.CineKit)
local Kit = require(Game.UI.Kit)

local Fx = {}

-- title colours by name (the boss's own colour family)
local COLORS = {
	Orange = Color3.fromRGB(255, 150, 60), Teal = Color3.fromRGB(90, 220, 205), Cream = Color3.fromRGB(245, 228, 196),
	Ice = Color3.fromRGB(190, 232, 255), Sand = Color3.fromRGB(255, 214, 140), Red = Color3.fromRGB(255, 90, 70),
	Gold = Color3.fromRGB(255, 214, 80),
	Mud = Color3.fromRGB(92, 64, 40), Dust = Color3.fromRGB(226, 190, 130), Snow = Color3.fromRGB(240, 246, 255),
}
Fx.Colors = COLORS

-- per-shot grades on top of the take's film look: { Brightness, Contrast, Saturation, Tint }
local GRADES = {
	Hero = { 0, 0.14, 0.24, Color3.fromRGB(255, 246, 232) },
	Dark = { -0.14, 0.22, -0.2, Color3.fromRGB(200, 214, 230) },
	Golden = { 0.02, 0.16, 0.3, Color3.fromRGB(255, 226, 176) },
	Underwater = { -0.08, 0.1, -0.05, Color3.fromRGB(150, 210, 235) },
	Dusk = { -0.02, 0.18, 0.18, Color3.fromRGB(255, 214, 186) },
	Whiteout = { 0.08, -0.1, -0.5, Color3.fromRGB(232, 242, 255) },
	Frost = { 0.02, 0.16, 0.05, Color3.fromRGB(222, 238, 255) },
	Dawn = { 0.02, 0.16, 0.28, Color3.fromRGB(255, 214, 190) },
	Backlit = { -0.04, 0.3, 0.2, Color3.fromRGB(255, 196, 150) },
	-- the lights go out (a boss reveal's darkness: the world near black, only glowing eyes read)
	Night = { -0.34, 0.34, -0.85, Color3.fromRGB(140, 155, 210) },
	-- (2026-10-14) the bay holding its breath; a storm rolling in; a dawn sky on fire
	Deep = { -0.16, 0.24, -0.35, Color3.fromRGB(160, 196, 232) },
	Storm = { -0.06, 0.05, -0.6, Color3.fromRGB(214, 228, 245) },
	Ember = { -0.02, 0.28, 0.3, Color3.fromRGB(255, 186, 140) },
}

local ui = {} :: any
local snow = nil :: any
local felled = {} :: { [BasePart]: CFrame }
local fellGen = 0 -- (RestoreWorld bumps it: a fall still animating when a take is skipped stops instead of knocking
-- the map's tree back over after it was stood up again)
-- (2026-10-14) the grade / haze tweens in flight: a slow grade fade cued near a shot's end (TB_Dock's Deep, 2.2 s)
-- kept running past the cut and dragged the next shot off its own grade; the end of a take stops both
local gradeTween = nil :: Tween?
local whiteTween = nil :: Tween?

--------------------------------------------------------------------------------
-- overlays
--------------------------------------------------------------------------------
local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end

function Fx.Init(gui: ScreenGui)
	if ui.Gui == gui then return end
	ui.Gui = gui
	ui.White = frame(gui, { Name = "White", BackgroundColor3 = Color3.fromRGB(240, 246, 255), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 })
	ui.Lens = frame(gui, { Name = "Lens", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 33, ClipsDescendants = true })
	ui.Bars = {}
	for i, a in ipairs({ 0, 1 }) do
		ui.Bars[i] = frame(gui, { Name = "Bar", BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, a), Position = UDim2.fromScale(0, a), Size = UDim2.fromScale(1, 0.075), ZIndex = 38, Visible = false })
	end
	ui.Film = {}
	for i, a in ipairs({ 0, 1 }) do
		ui.Film[i] = frame(gui, { Name = "FilmBar", BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, a), Position = UDim2.fromScale(0, a), Size = UDim2.fromScale(1, 0), ZIndex = 37 })
	end
end

-- the film letterbox (the Bars cue)
local filmTweens = {} :: { Tween }
local function film(h: number, dur: number)
	for _, tw in ipairs(filmTweens) do tw:Cancel() end
	table.clear(filmTweens)
	for _, b in ipairs(ui.Film or {}) do
		local goal = UDim2.fromScale(1, h)
		if dur <= 0.02 then
			b.Size = goal
		else
			local tw = TweenService:Create(b, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = goal })
			tw:Play()
			table.insert(filmTweens, tw)
		end
	end
end

-- the cutscene's letterbox (in-game reveals; recordings stay full frame)
function Fx.Letterbox(on: boolean)
	for _, b in ipairs(ui.Bars or {}) do b.Visible = on end
end

--------------------------------------------------------------------------------
-- grades + silhouettes
--------------------------------------------------------------------------------
function Fx.Grade(grade: ColorCorrectionEffect?, preset: string?, dur: number?)
	if not grade then return end
	local g = GRADES[preset or "Hero"] or GRADES.Hero
	local goal = { Brightness = g[1], Contrast = g[2], Saturation = g[3], TintColor = g[4] }
	if gradeTween then gradeTween:Cancel() gradeTween = nil end
	if (dur or 0) <= 0.02 then
		for k, v in pairs(goal) do (grade :: any)[k] = v end
	else
		gradeTween = TweenService:Create(grade, TweenInfo.new(dur :: number, Enum.EasingStyle.Sine), goal)
		;(gradeTween :: Tween):Play()
	end
end

-- black body, a warm rim and glowing eyes (a backlit or in-the-dark shape)
function Fx.Silhouette(model: Model, on: boolean, rim: Color3?, eyesOnly: boolean?)
	local h = model:FindFirstChild("TTSilhouette") :: Highlight?
	if on and not h then
		local nh = Instance.new("Highlight")
		nh.Name = "TTSilhouette"
		nh.FillColor = Color3.fromRGB(6, 6, 9)
		nh.FillTransparency = 0
		nh.OutlineColor = rim or Color3.fromRGB(255, 186, 110)
		-- (in the dark there's no rim light: only the eyes show)
		nh.OutlineTransparency = eyesOnly and 1 or 0.15
		nh.DepthMode = Enum.HighlightDepthMode.Occluded
		nh.Parent = model
		DinosaurVFX.EyeGlow(model, 8)
	elseif not on and h then
		h:Destroy()
	end
end

--------------------------------------------------------------------------------
-- effects
--------------------------------------------------------------------------------
local function fxFolder(): Instance
	return Workspace:FindFirstChild("DinoTikTok") or Workspace
end

local function ring(at: Vector3, r0: number, r1: number, dur: number, delay: number)
	task.delay(delay, function()
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(220, 240, 255)
		p.Transparency = 0.45
		p.Size = Vector3.new(0.04, r0 * 2, r0 * 2)
		p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
		p.Parent = fxFolder()
		-- an inner disc of the same water so only a thin ring shows
		local inner = p:Clone()
		inner.Material = Enum.Material.Glass
		inner.Color = Color3.fromRGB(70, 110, 120)
		inner.Transparency = 0.2
		inner.Size = Vector3.new(0.05, r0 * 2 - 0.3, r0 * 2 - 0.3)
		inner.Parent = p.Parent
		local t0 = os.clock()
		while os.clock() - t0 < dur and p.Parent do
			local u = (os.clock() - t0) / dur
			local r = r0 + (r1 - r0) * (1 - (1 - u) ^ 2)
			p.Size = Vector3.new(0.04, r * 2, r * 2)
			inner.Size = Vector3.new(0.05, math.max(0.1, r * 2 - 0.35), math.max(0.1, r * 2 - 0.35))
			p.Transparency = 0.45 + u * 0.55
			inner.Transparency = 0.2 + u * 0.8
			RunService.RenderStepped:Wait()
		end
		p:Destroy()
		inner:Destroy()
	end)
end

local function lensDrops(a: number, color: Color3?)
	if not ui.Lens then return end
	local tint = color or Color3.fromRGB(220, 240, 255)
	-- the same drops every take (seeded): a splash hitting the camera, sliding and drying off
	local rng = Random.new(77)
	for i = 1, math.floor(8 + a * 10) do
		local d = frame(ui.Lens, {
			BackgroundColor3 = tint, BackgroundTransparency = color and 0.3 or 0.72,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rng:NextNumber(0.05, 0.95), rng:NextNumber(0.05, 0.9)),
			Size = UDim2.fromOffset(rng:NextInteger(18, 70), rng:NextInteger(18, 70)), ZIndex = 33,
		})
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = d
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(255, 255, 255)
		s.Transparency = 0.45
		s.Thickness = 2
		s.Parent = d
		local dur = 1.2 + rng:NextNumber(0, 0.9)
		TweenService:Create(d, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1, Position = d.Position + UDim2.fromScale(0, rng:NextNumber(0.03, 0.12)) }):Play()
		TweenService:Create(s, TweenInfo.new(dur), { Transparency = 1 }):Play()
		task.delay(dur + 0.05, function() d:Destroy() end)
		if i == 1 then
			-- a quick wet smear over the whole frame
			local smear = frame(ui.Lens, { BackgroundColor3 = color or Color3.fromRGB(200, 230, 255), BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), ZIndex = 32 })
			TweenService:Create(smear, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			task.delay(0.55, function() smear:Destroy() end)
		end
	end
end

local function setSnow(density: number)
	if density <= 0 then
		if snow then snow.Part:Destroy() snow = nil end
		return
	end
	if not snow then
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(40, 1, 40)
		p.Parent = fxFolder()
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(245, 250, 255))
		e.LightEmission = 0.3
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.25) })
		e.Lifetime = NumberRange.new(1.2, 1.8)
		e.Speed = NumberRange.new(18, 30)
		e.SpreadAngle = Vector2.new(25, 25)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Acceleration = Vector3.new(-22, 0, 8)
		e.Parent = p
		snow = { Part = p, E = e }
		task.spawn(function()
			while snow and snow.Part == p and p.Parent do
				local cam = Workspace.CurrentCamera
				if cam then p.CFrame = cam.CFrame * CFrame.new(0, 10, -10) end
				RunService.RenderStepped:Wait()
			end
		end)
	end
	snow.E.Rate = 900 * density
end

local function white(a: number, dur: number, color: Color3?)
	if not ui.White then return end
	-- (a fade-out keeps the haze's own colour: "White 0 1.2" after a dust wall must not flip it to snow white)
	if color or a >= 0.05 then ui.White.BackgroundColor3 = color or Color3.fromRGB(240, 246, 255) end
	if whiteTween then whiteTween:Cancel() whiteTween = nil end
	if dur <= 0.02 then ui.White.BackgroundTransparency = 1 - a return end
	whiteTween = TweenService:Create(ui.White, TweenInfo.new(dur, Enum.EasingStyle.Quad, a < 0.05 and Enum.EasingDirection.Out or Enum.EasingDirection.In), { BackgroundTransparency = 1 - a })
	;(whiteTween :: Tween):Play()
end

-- topple a real map tree at this spot (all of its parts, around its base), in a gravity ease; restored after the take
local TREE = { "Trunk", "Crown", "Conifer", "Pine", "Canopy", "Branch", "Leaves", "Top" }
local function treeParts(at: Vector3): ({ BasePart }, Vector3?)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fxFolder() }
	local base, best = nil :: BasePart?, math.huge
	for _, p in ipairs(Workspace:GetPartBoundsInRadius(at + Vector3.new(0, 2, 0), 4, params)) do
		if string.find(p.Name, "Trunk") and not felled[p] then
			local d = (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(at.X, 0, at.Z)).Magnitude
			if d < best then base, best = p, d end
		end
	end
	if not base then return {}, nil end
	-- the tree: its model if it's a small one, else everything tree-like stacked on this trunk's column
	local mdl = base:FindFirstAncestorWhichIsA("Model")
	local list = {}
	if mdl and #mdl:GetDescendants() < 120 then
		for _, d in ipairs(mdl:GetDescendants()) do if d:IsA("BasePart") then table.insert(list, d) end end
	else
		local c = Vector3.new(base.Position.X, 0, base.Position.Z)
		local box = Workspace:GetPartBoundsInBox(CFrame.new(base.Position.X, base.Position.Y + 30, base.Position.Z), Vector3.new(16, 70, 16), params)
		for _, p in ipairs(box) do
			for _, w in ipairs(TREE) do
				if string.find(p.Name, w) and (Vector3.new(p.Position.X, 0, p.Position.Z) - c).Magnitude < 9 then table.insert(list, p) break end
			end
		end
	end
	local lowest = math.huge
	for _, p in ipairs(list) do lowest = math.min(lowest, p.Position.Y - p.Size.Y / 2) end
	return list, Vector3.new(base.Position.X, lowest, base.Position.Z)
end

local function treeFall(at: Vector3, toward: Vector3, dur: number)
	local parts, pivot = treeParts(at)
	if #parts == 0 or not pivot then return end
	for _, p in ipairs(parts) do if felled[p] == nil then felled[p] = p.CFrame end end
	local start = {}
	for _, p in ipairs(parts) do start[p] = p.CFrame end
	local flat = Vector3.new(toward.X - at.X, 0, toward.Z - at.Z)
	local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local axis = Vector3.yAxis:Cross(dir).Unit
	local gen = fellGen
	task.spawn(function()
		local t0 = os.clock()
		local pv = CFrame.new(pivot :: Vector3)
		while os.clock() - t0 < dur do
			if gen ~= fellGen then return end
			local u = (os.clock() - t0) / dur
			local a = (u ^ 2.2) * math.rad(86) -- slow tip, then it comes down fast
			local rot = pv * CFrame.fromAxisAngle(axis, a) * pv:Inverse()
			for p, cf in pairs(start) do if p.Parent then p.CFrame = rot * cf end end
			RunService.RenderStepped:Wait()
		end
		if gen ~= fellGen then return end
		local rot = pv * CFrame.fromAxisAngle(axis, math.rad(86)) * pv:Inverse()
		for p, cf in pairs(start) do if p.Parent then p.CFrame = rot * cf end end
		local land = (pivot :: Vector3) + dir * 22
		DinosaurVFX.FoliageBurst(land, 2)
		DinosaurVFX.FootstepDust(land, 2.5)
	end)
end

-- a flock bursting out of the trees: dark birds flap up and away toward `toward` (seeded: the same flock every take)
local function birds(at: Vector3, count: number, toward: Vector3?)
	local rng = Random.new(31)
	local folder = fxFolder()
	local goal = toward or (at + Vector3.new(0, 30, 0))
	for i = 1, math.clamp(count, 1, 40) do
		local col = Color3.fromRGB(26 + rng:NextInteger(0, 22), 24 + rng:NextInteger(0, 12), 30)
		local function piece(size: Vector3): Part
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = col
			p.Size = size
			p.Parent = folder
			return p
		end
		local k = rng:NextNumber(0.85, 1.25)
		local body = piece(Vector3.new(0.45, 0.4, 1.1) * k)
		local lw = piece(Vector3.new(1.5, 0.1, 0.65) * k)
		local rw = piece(Vector3.new(1.5, 0.1, 0.65) * k)
		local start = at + Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-2, 4), rng:NextNumber(-6, 6))
		local dir = (goal - start).Unit
		dir = (dir + Vector3.new(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 0.3), rng:NextNumber(-0.35, 0.35))).Unit
		local speed = rng:NextNumber(20, 32)
		local lift = rng:NextNumber(3, 9)
		local phase = rng:NextNumber(0, 6)
		local delay = (i - 1) / count * 0.45 + rng:NextNumber(0, 0.12)
		local hide = function() body.Transparency, lw.Transparency, rw.Transparency = 1, 1, 1 end
		hide()
		task.delay(delay, function()
			local t0 = os.clock()
			body.Transparency, lw.Transparency, rw.Transparency = 0, 0, 0
			while body.Parent and os.clock() - t0 < 3.6 do
				local t = os.clock() - t0
				-- a hard first burst of wingbeats, then a steadier flap as they climb away
				local pos = start + dir * speed * t + Vector3.new(0, lift * t + 2 * t * t, 0)
				local flap = math.sin(t * (t < 0.6 and 34 or 24) + phase) * 0.95
				local cf = CFrame.lookAt(pos, pos + dir + Vector3.new(0, 0.25, 0))
				body.CFrame = cf
				lw.CFrame = cf * CFrame.new(-0.2 * k, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.75 * k, 0, 0)
				rw.CFrame = cf * CFrame.new(0.2 * k, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.75 * k, 0, 0)
				RunService.RenderStepped:Wait()
			end
			body:Destroy()
			lw:Destroy()
			rw:Destroy()
		end)
	end
end

local function slash(color: Color3?)
	if not ui.Gui then return end
	-- a bright cut across the frame, the picture jolts apart along it, then it seals
	local holder = frame(ui.Gui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 36 })
	local line = frame(holder, { BackgroundColor3 = color or Color3.fromRGB(255, 244, 220), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 0, 0, 10), Rotation = -28, ZIndex = 37 })
	local glow = Instance.new("UIStroke")
	glow.Color = Color3.new(1, 1, 1)
	glow.Thickness = 4
	glow.Transparency = 0.3
	glow.Parent = line
	local dark = frame(holder, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.6, 0, 0, 0), Rotation = -28, ZIndex = 36 })
	TweenService:Create(line, TweenInfo.new(0.12, Enum.EasingStyle.Quint), { Size = UDim2.new(1.7, 0, 0, 10) }):Play()
	TweenService:Create(dark, TweenInfo.new(0.16, Enum.EasingStyle.Quint), { Size = UDim2.new(1.7, 0, 0.12, 0) }):Play()
	task.delay(0.5, function()
		TweenService:Create(line, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(glow, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		TweenService:Create(dark, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.new(1.7, 0, 0, 0) }):Play()
	end)
	task.delay(1, function() holder:Destroy() end)
	CineKit.ImpactFrame(0.5)
end

--------------------------------------------------------------------------------
-- the cue table: returns true if it handled the cue
--------------------------------------------------------------------------------
function Fx.Cue(rt, kind: string, a1, a2, a3, grade: ColorCorrectionEffect?): boolean
	local Audio = require(Game.Audio)
	local function model(id): Model?
		local o = rt and rt.ById and rt.ById[id]
		return o and o.Model or nil
	end
	if kind == "Bars" then
		film(math.clamp(tonumber(a1) or 0, 0, 0.45), tonumber(a2) or 0)
	elseif kind == "Sfx" then
		Audio.Play(a1, { Volume = a2 or 1, Pitch = a3 or 1, Exact = true, Gap = 0 })
	elseif kind == "Sting" then
		Audio.Sting(a1, a2)
	elseif kind == "Fx" then
		local m = model(a1)
		if m then DinosaurVFX.HandleEvent(m, a2, a3) end
	elseif kind == "Ripple" and typeof(a1) == "Vector3" then
		local k = a2 or 1
		for i = 0, 2 do ring(a1, 0.3, (2.2 + i * 0.6) * k, 1.1 + i * 0.15, i * 0.12) end
	elseif kind == "Leaves" and typeof(a1) == "Vector3" then
		DinosaurVFX.FallingLeaves(a1, a2 or 20, a3 or 40, 18)
	elseif kind == "RoarWave" then
		local m = model(a1)
		local mouth = m and (DinosaurVFX.findAttachment(m, "VFX_Mouth") or DinosaurVFX.findAttachment(m, "VFX_Head"))
		local cam = Workspace.CurrentCamera
		if mouth and cam then DinosaurVFX.RoarShockwave(CFrame.lookAt(mouth.WorldPosition, cam.CFrame.Position), a2 or 1.5) end
	elseif kind == "Splash" and typeof(a1) == "Vector3" then
		DinosaurVFX.WaterSplash(a1, a2 or 1.5)
	elseif kind == "LensDrops" then
		lensDrops(a1 or 0.7, a2 and COLORS[a2] or nil)
	elseif kind == "Snow" then
		setSnow(a1 or 0)
	elseif kind == "White" then
		white(a1 or 0, a2 or 0.3, a3 and COLORS[a3] or nil)
	elseif kind == "TreeFall" and typeof(a1) == "Vector3" and typeof(a2) == "Vector3" then
		treeFall(a1, a2, a3 or 1.2)
	elseif kind == "Title" then
		CineKit.RayTitle(ui.Gui, tostring(a1 or ""), a2 and tostring(a2) or nil, COLORS[a3 or "Gold"] or COLORS.Gold, 1.9, 0.27)
	elseif kind == "Slash" then
		slash(COLORS[a1 or "Cream"])
	elseif kind == "Grade" then
		Fx.Grade(grade, a1 and tostring(a1) or nil, tonumber(a2))
	elseif kind == "Splinter" and typeof(a1) == "Vector3" then
		DinosaurVFX.Debris(a1, a2 or 1.2, Color3.fromRGB(140, 100, 62))
		DinosaurVFX.Cubes(a1, 14, { Color3.fromRGB(150, 108, 66), Color3.fromRGB(110, 78, 46), Color3.fromRGB(235, 248, 255) }, 0.5, 26, 1.1)
	elseif kind == "TimeScale" then
		-- slow motion for the dinos' animation (the shot's own movement is authored slow to match); 1 = normal
		require(Shared:WaitForChild("DinosaurAnimations")).TimeScale = tonumber(a1) or 1
	elseif kind == "Birds" and typeof(a1) == "Vector3" then
		birds(a1, tonumber(a2) or 14, typeof(a3) == "Vector3" and a3 or nil)
	elseif kind == "DustWave" and typeof(a1) == "Vector3" then
		-- a wall of dust rolling out from a roar or a stomp, toward a point (the lens)
		local toward = typeof(a2) == "Vector3" and a2 or (a1 + Vector3.new(0, 0, -10))
		DinosaurVFX.DustWave(a1, toward - a1, a3 or 1.5)
		DinosaurVFX.FootstepDust(a1, (a3 or 1.5) * 1.2)
	elseif kind == "Cracks" and typeof(a1) == "Vector3" then
		DinosaurVFX.GroundCracks(a1, a2 or 1.5)
	elseif kind == "Glint" and typeof(a1) == "Vector3" then
		-- a blade catching the light: a white star on the claw tip
		CineKit.Sparkle(a1, Color3.new(1, 1, 1), a2 or 0.8)
	elseif kind == "Bubbles" and typeof(a1) == "Vector3" then
		DinosaurVFX.Cubes(a1, math.floor(10 * (a2 or 1)), { Color3.fromRGB(220, 245, 255), Color3.fromRGB(180, 225, 245) }, 0.3, 6, 1.4)
	else
		return false
	end
	return true
end

-- between shots: nothing carries over - except a haze fade already under way, which finishes across the cut (GT_Dust's
-- dust wall thinning out over GT_Tilt's first second, as authored; snapping it clear and letting the old tween pull it
-- back flickered). hard: the end of the take, everything off
function Fx.Reset(hard: boolean?)
	setSnow(0)
	require(Shared:WaitForChild("DinosaurAnimations")).TimeScale = 1
	if gradeTween then gradeTween:Cancel() gradeTween = nil end
	local fading = whiteTween ~= nil and whiteTween.PlaybackState == Enum.PlaybackState.Playing
	if hard or not fading then
		if whiteTween then whiteTween:Cancel() whiteTween = nil end
	end
	if ui.White and (hard or not fading) then
		ui.White.BackgroundTransparency = 1
		ui.White.BackgroundColor3 = Color3.fromRGB(240, 246, 255)
	end
	if ui.Lens then ui.Lens:ClearAllChildren() end
	film(0, 0)
end

-- end of the take: the felled trees stand back up
function Fx.RestoreWorld()
	Fx.Reset(true)
	fellGen += 1
	for p, cf in pairs(felled) do if p.Parent then p.CFrame = cf end end
	table.clear(felled)
	Fx.Letterbox(false)
end

local _ = Lighting
local _k = Kit
return Fx
