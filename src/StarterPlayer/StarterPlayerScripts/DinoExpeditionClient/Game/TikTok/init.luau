--[[
	TikTok — the recording director. Plays the sequences baked by tools/gen/tiktok.js (Data.luau) frame-exact:
	every actor, camera key and cue comes from the bake, so a take looks the same every time and matches the
	QC frames in tools/preview/tiktok.html. Nothing here touches the real game: every dino, rover, egg and
	player double is a local clone in Workspace.DinoTikTok, and the live world (players, rovers, site dinos,
	the sleeping ruler) is hidden for the take.

	  TikTok.Play(seqId, { FromShot?, FromBeat?, Countdown? })   TikTok.PlayShot(shotName)   TikTok.Stop()
	  Settings > TIKTOKS lists them. While playing (keyboard):
	    SPACE pause/resume   LEFT/RIGHT previous/next shot   [ ] back/forward one beat   R restart (with count-in)
	    H hide this help (clean frame for recording)   G safe-area guides   C caption preview   X stop
	A 9:16 sequence (Aspect) shows the vertical frame instead: G dims what a phone crop cuts (set Studio's device
	emulator to a 9:16 screen, e.g. 1080 x 1920, and the whole view is the frame). A sequence's Lines (its voice-over
	script, by beat) show in the caption preview as they come up, so you can read along while you record.
	A sequence's Overlay (a word, e.g. the map tour's "SOON.") is held big in the middle of the whole take, its fill a
	shifting holographic gradient that changes look on every cut; T hides it (record clean and add your own in the edit).
	A shot baked OnPlot (Plot = the island it was staged on) plays on the island YOU own: the whole shot - actors,
	camera, effects - is moved by the turn between the two islands (they're the same island, rotated round the hub).

	Timing: every shot is a whole number of beats at Data.Music.BPM (Timeline.luau). Beat 0 is the first frame after
	the black count-in, so a recording lines up with the music by putting the first kick on that cut.
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurVFX = require(Shared:WaitForChild("DinosaurVFX"))
local Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))

local Game = script.Parent
local Data = require(script.Data)
local Fx = require(script.Fx)
local Timeline = require(script.Timeline)
local Cam = require(script.Cam)
local Stage = require(script.Stage)
local Cinema = require(Game.UI.Cinema)
local Kit = require(Game.UI.Kit)
local CineKit = require(Game.UI.CineKit)
local Zone = require(Game.Zone)
local Drive = require(Game.Drive)
local PlayerAnim = require(Game.PlayerAnim)
local HUD = require(Game.UI.HUD)
local Darts = require(Game.Darts)
local RouteMath = require(Shared.Game.RouteMath)

local player = Players.LocalPlayer
local TikTok = {}
TikTok.Data = Data
TikTok.Playing = false

Timeline.Music.BPM = Data.Music.BPM
Timeline.Music.MusicOffset = Data.Music.MusicOffset or 0

local COUNT_IN = 4 -- beats of black before beat 0

--------------------------------------------------------------------------------
-- overlay: black / flash layers, CineKit titles, the help HUD, guides, caption preview
--------------------------------------------------------------------------------
local ui = {} :: any
local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end

local function buildUi()
	if ui.Gui then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoTikTokUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.Enabled = false
	ui.Gui = gui
	ui.Black = frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 40, Visible = false })
	ui.Flash = frame(gui, { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 41, BackgroundTransparency = 1 })
	ui.Count = Kit.Text(gui, "", { Pixel = true, Size = UDim2.fromScale(0.3, 0.16), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(255, 244, 214), Stroke = 4, Shadow = 5, ZIndex = 45, MaxSize = 96 })
	-- help HUD (H hides it for a clean recording)
	local hud = frame(gui, { BackgroundColor3 = Color3.fromRGB(10, 12, 18), BackgroundTransparency = 0.25, Position = UDim2.new(0, 12, 0, 12), Size = UDim2.fromOffset(470, 74), ZIndex = 50 })
	Kit.Corner(hud, 10)
	ui.Hud = hud
	local function line(y: number, size: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(10, y)
		l.Size = UDim2.new(1, -20, 0, size + 4)
		l.Font = Enum.Font.GothamBold
		l.TextSize = size
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = color
		l.ZIndex = 51
		l.Text = ""
		l.Parent = hud
		return l
	end
	ui.Line1 = line(6, 15, Color3.fromRGB(255, 226, 120))
	ui.Line2 = line(28, 13, Color3.fromRGB(230, 236, 245))
	ui.Line3 = line(50, 11, Color3.fromRGB(150, 160, 180))
	ui.Line3.Text = "SPACE pause  ←/→ shot  [ ] beat  R restart  H hide  G guides  C captions  X stop"
	ui.Beat = frame(hud, { BackgroundColor3 = Color3.fromRGB(255, 226, 120), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(14, 14), ZIndex = 52 })
	Kit.Corner(ui.Beat, 7)
	-- 16:9 guides: centre safe box + the caption band
	local guides = frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Visible = false })
	local safe = frame(guides, { BackgroundTransparency = 1, Position = UDim2.fromScale(0.1, 0.06), Size = UDim2.fromScale(0.8, 0.79), ZIndex = 30 })
	Kit.Stroke(safe, Color3.fromRGB(120, 255, 160), 2)
	frame(guides, { BackgroundColor3 = Color3.fromRGB(255, 70, 70), BackgroundTransparency = 0.82, Position = UDim2.fromScale(0, 0.85), Size = UDim2.fromScale(1, 0.15), ZIndex = 30 })
	ui.Guides = guides
	-- 9:16: the vertical frame, centred and as tall as the screen (the whole screen on a 9:16 one). Its guides dim what
	-- a phone crop cuts (the pillars run off the column's sides) and tint where TikTok's own UI sits: the caption
	-- and the bottom bar, and the like / comment / share rail on the right
	local col = frame(gui, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 30 })
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 9 / 16
	ar.Parent = col
	ui.Col = col
	local tall = frame(col, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Visible = false })
	for _, side in ipairs({ 0, 1 }) do
		frame(tall, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(1 - side, 0), Position = UDim2.fromScale(side, 0), Size = UDim2.new(0, 4000, 1, 0), ZIndex = 30 })
	end
	local safe916 = frame(tall, { BackgroundTransparency = 1, Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.79, 0.7), ZIndex = 30 })
	Kit.Stroke(safe916, Color3.fromRGB(120, 255, 160), 2)
	frame(tall, { BackgroundColor3 = Color3.fromRGB(255, 70, 70), BackgroundTransparency = 0.82, Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.2), ZIndex = 30 })
	frame(tall, { BackgroundColor3 = Color3.fromRGB(255, 70, 70), BackgroundTransparency = 0.82, Position = UDim2.fromScale(0.85, 0.35), Size = UDim2.fromScale(0.15, 0.45), ZIndex = 30 })
	ui.Guides916 = tall
	-- caption preview: where the editor's text goes (never baked into the footage)
	ui.Caption = Kit.Text(gui, "", { Size = UDim2.fromScale(0.7, 0.07), Position = UDim2.fromScale(0.5, 0.9), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.new(1, 1, 1), Stroke = 4, Shadow = 0, ZIndex = 31, MaxSize = 44 })
	ui.Caption.Visible = false
	-- the sequence's Overlay word (the map tour's "SOON."): a drop shadow and the word, filled with a moving gradient
	local ov = Instance.new("TextLabel")
	ov.Name = "Overlay"
	ov.BackgroundTransparency = 1
	ov.AnchorPoint = Vector2.new(0.5, 0.5)
	ov.Font = Enum.Font.GothamBlack
	ov.TextScaled = true
	ov.TextColor3 = Color3.new(1, 1, 1)
	ov.Text = ""
	ov.ZIndex = 36
	ov.Visible = false
	local shade = ov:Clone()
	shade.Name = "OverlayShade"
	shade.TextColor3 = Color3.new(0, 0, 0)
	shade.TextTransparency = 0.7
	shade.ZIndex = 35
	shade.Parent = gui
	ov.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 16, 60)
	stroke.Transparency = 0.65
	stroke.Thickness = 1.5
	stroke.Parent = ov
	local grad = Instance.new("UIGradient")
	grad.Parent = ov
	ui.Overlay, ui.OverlayShade, ui.OverlayGrad = ov, shade, grad
	Fx.Init(gui)
	-- in-game cutscenes (boss reveals): hold to skip
	local skip = frame(gui, { Name = "Skip", BackgroundColor3 = Color3.fromRGB(10, 12, 18), BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0.075, 12), Size = UDim2.fromOffset(190, 40), ZIndex = 52, Visible = false })
	Kit.Corner(skip, 10)
	ui.SkipFill = frame(skip, { BackgroundColor3 = Color3.fromRGB(255, 226, 120), BackgroundTransparency = 0.35, Size = UDim2.fromScale(0, 1), ZIndex = 53 })
	Kit.Corner(ui.SkipFill, 10)
	ui.SkipText = Kit.Text(skip, "HOLD TO SKIP", { Pixel = true, Size = UDim2.new(1, -16, 0, 11), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 54, Stroke = 2, Shadow = 1, MaxSize = 11 })
	ui.Skip = skip
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- the take's frame: "9:16" (a vertical sequence) or 16:9. G shows that frame's guides; the caption preview sits where
-- that frame's caption goes
local function showGuides()
	local on = ui.GuidesOn == true
	ui.Guides.Visible = on and not ui.Tall
	ui.Guides916.Visible = on and ui.Tall
end
local function placeOverlay()
	local host = ui.Tall and ui.Col or ui.Gui
	local size = ui.Tall and UDim2.fromScale(0.9, 0.16) or UDim2.fromScale(0.6, 0.27)
	for i, l in ipairs({ ui.Overlay, ui.OverlayShade }) do
		l.Parent = host
		l.Size = size
		l.Position = i == 1 and UDim2.fromScale(0.5, 0.5) or UDim2.new(0.5, 4, 0.5, 5)
	end
end
local function setAspect(aspect: string?)
	ui.Tall = aspect == "9:16"
	placeOverlay()
	if ui.Tall then
		ui.Caption.Parent = ui.Col
		ui.Caption.Size = UDim2.fromScale(0.86, 0.07)
		ui.Caption.Position = UDim2.fromScale(0.46, 0.84)
	else
		ui.Caption.Parent = ui.Gui
		ui.Caption.Size = UDim2.fromScale(0.7, 0.07)
		ui.Caption.Position = UDim2.fromScale(0.5, 0.9)
	end
	ui.Line3.Text = (ui.Tall and "9:16  " or "") .. "SPACE pause  ←/→ shot  [ ] beat  R restart  H hide  G guides  C captions  T title  X stop"
	showGuides()
end

-- the Overlay word's holographic fills: one per cut, in turn (the "footage in the letters" look: blue / violet /
-- pink / cyan / white), each drifting across the letters while it's up
local HOLO = {
	{ Color3.fromRGB(60, 120, 255), Color3.fromRGB(150, 90, 255), Color3.fromRGB(255, 150, 230), Color3.fromRGB(110, 200, 255) },
	{ Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 170, 255), Color3.fromRGB(150, 210, 255) },
	{ Color3.fromRGB(40, 70, 200), Color3.fromRGB(110, 190, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(80, 120, 240) },
	{ Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 220, 255), Color3.fromRGB(230, 160, 255) },
	{ Color3.fromRGB(120, 60, 220), Color3.fromRGB(70, 140, 255), Color3.fromRGB(150, 255, 220), Color3.fromRGB(160, 110, 255) },
}
local function overlayLook(i: number)
	local cols = HOLO[(i - 1) % #HOLO + 1]
	local keys = {}
	for k, c in ipairs(cols) do table.insert(keys, ColorSequenceKeypoint.new((k - 1) / (#cols - 1), c)) end
	ui.OverlayGrad.Color = ColorSequence.new(keys)
	ui.OverlayRot = (i * 67) % 360
end
local function overlayStep(clock: number)
	if not ui.Overlay.Visible then return end
	ui.OverlayGrad.Rotation = (ui.OverlayRot or 0) + math.sin(clock * 0.9) * 20
	ui.OverlayGrad.Offset = Vector2.new(math.sin(clock * 2.3) * 0.35, math.cos(clock * 1.7) * 0.2)
end

local function flash(a: number)
	ui.Flash.BackgroundTransparency = 1 - a
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.3 do
			ui.Flash.BackgroundTransparency = 1 - a * (1 - (os.clock() - t0) / 0.3)
			RunService.RenderStepped:Wait()
		end
		ui.Flash.BackgroundTransparency = 1
	end)
end

--------------------------------------------------------------------------------
-- the live world steps out of frame for the take (local only, all restored after)
--------------------------------------------------------------------------------
local hidden = {} :: { [Instance]: any }
local function hideTree(root: Instance?)
	if not root then return end
	for _, d in ipairs(root:GetDescendants()) do
		if hidden[d] == nil then
			if d:IsA("BasePart") then
				hidden[d] = d.LocalTransparencyModifier
				d.LocalTransparencyModifier = 1
			elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
				hidden[d] = (d :: any).Enabled
				;(d :: any).Enabled = false
			elseif d:IsA("Decal") then
				hidden[d] = d.Transparency
				d.Transparency = 1
			end
		end
	end
end
local function hideWorld()
	for _, plr in ipairs(Players:GetPlayers()) do hideTree(plr.Character) end
	for _, n in ipairs({ "ActiveVehicles", "DinoExpeditionLocal" }) do hideTree(Workspace:FindFirstChild(n)) end
	-- the sleeping boss on its throne (EraView's stand-in lives in DinoCutsceneActors; older builds left it loose)
	local actors = Workspace:FindFirstChild("DinoCutsceneActors")
	for _, d in ipairs(Workspace:GetChildren()) do if d.Name == "SleepingRuler" and d:IsA("Model") then hideTree(d) end end
	for _, d in ipairs(actors and actors:GetChildren() or {}) do if d.Name == "SleepingRuler" and d:IsA("Model") then hideTree(d) end end
	-- camp NPCs stand where shots are staged (the Egg Keeper is on the hatch stage)
	for _, m in ipairs(CollectionService:GetTagged("DinoNpc")) do hideTree(m) end
	-- the ambient herds (CampView: the Horn Meadow Triceratops, the ridge Brachiosaurus...): a take stages its own
	-- dinos, and a live grazer standing in frame read as the T. rex landing on top of a Triceratops
	for _, m in ipairs(CollectionService:GetTagged("AmbientDino")) do hideTree(m) end
	-- the hatch stage's big display would fill the background of the hatch shots
	local camp = Workspace:FindFirstChild("BaseCamp")
	local screen = camp and camp:FindFirstChild("HatchScreen", true)
	if screen and screen:IsA("SurfaceGui") and hidden[screen] == nil then
		hidden[screen] = screen.Enabled
		screen.Enabled = false
	end
end

-- every other prompt in the world stays quiet for the take (only the staged prompt cards show)
local mutedPrompts = {} :: { [ProximityPrompt]: boolean }
local promptsMuted = false
local function mutePrompts()
	if promptsMuted then return end
	promptsMuted = true
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled and not d:IsDescendantOf(Stage.Root()) then
			mutedPrompts[d] = true
			d.Enabled = false
		end
	end
end
local function unmutePrompts()
	for p in pairs(mutedPrompts) do if p.Parent then p.Enabled = true end end
	table.clear(mutedPrompts)
	promptsMuted = false
end
local function showWorld()
	for d, was in pairs(hidden) do
		if d.Parent then
			if d:IsA("BasePart") then d.LocalTransparencyModifier = was
			elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then (d :: any).Enabled = was
			elseif d:IsA("Decal") then d.Transparency = was end
		end
	end
	table.clear(hidden)
end

--------------------------------------------------------------------------------
-- film look for the whole take (the CineKit reference grade: saturated, strong bloom, focus on the subject)
--------------------------------------------------------------------------------
local look = {} :: any
local function gradeOn()
	look.Dof = Instance.new("DepthOfFieldEffect")
	look.Dof.Name = "DinoTikTokDOF"
	look.Dof.FarIntensity = 0.4
	look.Dof.NearIntensity = 0.15
	look.Dof.Parent = Lighting
	look.Grade = Instance.new("ColorCorrectionEffect")
	look.Grade.Name = "DinoTikTokGrade"
	look.Grade.Contrast = 0.14
	look.Grade.Saturation = 0.24
	look.Grade.TintColor = Color3.fromRGB(255, 246, 232)
	look.Grade.Parent = Lighting
	local bloom = (Lighting:FindFirstChild("DinoBloom") or Lighting:FindFirstChildOfClass("BloomEffect")) :: BloomEffect?
	if bloom then
		look.Bloom, look.BloomWas = bloom, { bloom.Intensity, bloom.Threshold, bloom.Size }
		bloom.Intensity, bloom.Threshold, bloom.Size = 0.9, 1.15, 34
	end
end
local function gradeOff()
	if look.Dof then look.Dof:Destroy() end
	if look.Grade then look.Grade:Destroy() end
	-- (the game's own bloom goes back to the zone's look, not a snapshot that may have been mid-tween)
	local zl = Zone.Look and Zone.Look()
	if look.Bloom and look.Bloom.Name == "DinoBloom" and zl and zl.Bloom then
		for k, v in pairs(zl.Bloom) do (look.Bloom :: any)[k] = v end
	elseif look.Bloom and look.BloomWas then
		look.Bloom.Intensity, look.Bloom.Threshold, look.Bloom.Size = look.BloomWas[1], look.BloomWas[2], look.BloomWas[3]
	end
	table.clear(look)
end

--------------------------------------------------------------------------------
-- a shot: build its local set from the bake, then drive it from its own clock
--------------------------------------------------------------------------------
local STRIDE = { Dino = 5, Baby = 5, Rover = 8 }

local function lerpAngle(a: number, b: number, u: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * u
end

-- a shot staged on island `from` (its Plot) plays on the island you own: this is the turn + shift between the two
-- (every island is the same island turned round the hub; each one's PlotCenter marker carries its frame). No move when
-- it's your island already, you haven't got one yet, or the markers can't be found (it plays where it was staged).
local function plotXf(from: number?): (CFrame?, number)
	if not from then return nil, 0 end
	local mine = tonumber(player:GetAttribute("Plot"))
	if not mine or mine == from then return nil, 0 end
	local camp = Workspace:FindFirstChild("BaseCamp")
	local a = camp and camp:FindFirstChild("Plot" .. from, true)
	local b = camp and camp:FindFirstChild("Plot" .. mine, true)
	local ca = a and a:FindFirstChild("PlotCenter", true)
	local cb = b and b:FindFirstChild("PlotCenter", true)
	if not (ca and cb and ca:IsA("BasePart") and cb:IsA("BasePart")) then return nil, 0 end
	local xf = cb.CFrame * ca.CFrame:Inverse()
	local _, yaw = xf:ToEulerAnglesYXZ()
	return xf, yaw
end

local function buildShot(name: string)
	local d = Data.Shots[name]
	if not d then return nil end
	local set = Stage.new("TT_" .. name)
	local rt = { Name = name, D = d, Set = set, Actors = {}, ById = {} } :: any
	rt.Xf, rt.XfYaw = plotXf(d.Plot)
	for _, a in ipairs(d.Actors) do
		local o = { D = a, Kind = a.Kind, Stride = STRIDE[a.Kind] or 4, ActIdx = 0, Xf = rt.Xf, XfYaw = rt.XfYaw } :: any
		if a.Kind == "Dino" then o.A = set:Dino(a.Species, { Scale = a.Scale, Rarity = a.Rarity })
		elseif a.Kind == "Baby" then o.A = set:Dino(a.Species, { Baby = true, Scale = 1, Rarity = a.Rarity })
		elseif a.Kind == "Rover" then o.A = set:Rover(a.Name)
		elseif a.Kind == "Crew" then o.A = set:Crew(a.Crew)
		elseif a.Kind == "Egg" then o.M = set:Egg(a.Species, a.Rarity, a.Scale)
		elseif a.Kind == "Prop" then
			-- a simple staged set piece (a puddle on the lair floor...)
			local pr = a.Prop or {}
			local sz = pr.Size or { 6, 0.1, 6 }
			local cyl = pr.Shape == "Cylinder"
			local part = set:Part({
				Name = "TTProp_" .. a.Id, Shape = cyl and Enum.PartType.Cylinder or Enum.PartType.Block,
				Size = cyl and Vector3.new(sz[2], sz[1], sz[3]) or Vector3.new(sz[1], sz[2], sz[3]),
				Color = Color3.fromHex(((pr.Color or "#5aa0c8"):gsub("#", ""))), Material = (Enum.Material :: any)[pr.Material or "SmoothPlastic"] or Enum.Material.SmoothPlastic,
				Transparency = pr.Transparency or 0, Reflectance = pr.Reflectance or 0, CastShadow = false,
			})
			local m = Instance.new("Model")
			m.Name = "TTProp"
			part.Parent = m
			m.PrimaryPart = part
			m.Parent = set.Folder
			o.M = m
			o.PropLift = (pr.Lift or 0) + sz[2] / 2
			o.PropCyl = cyl
		end
		local model = (o.A and o.A.Model) or o.M
		if a.Glow and model then
			local h = Instance.new("Highlight")
			h.Name = "TTWarnGlow"
			h.FillColor = Color3.fromRGB(255, 40, 40)
			h.OutlineColor = Color3.fromRGB(255, 120, 120)
			h.FillTransparency = 0.45
			h.Enabled = false
			h.Parent = model
			o.Glow = h
		end
		o.Model = model
		rt.ById[a.Id] = o
		table.insert(rt.Actors, o)
	end
	set:Hide()
	return rt
end

local function trackAt(o, f: number, n: number): { number }
	local tr = o.D.Track
	local s = o.Stride
	local i = math.clamp(math.floor(f), 0, n - 1)
	local j = math.min(i + 1, n - 1)
	local u = math.clamp(f - i, 0, 1)
	local out = {}
	for k = 1, s do
		local a, b = tr[i * s + k], tr[j * s + k]
		out[k] = (k == 4) and lerpAngle(a, b, u) or a + (b - a) * u
	end
	if o.Xf then
		local p = o.Xf * Vector3.new(out[1], out[2], out[3])
		out[1], out[2], out[3] = p.X, p.Y, p.Z
		out[4] += o.XfYaw
	end
	return out
end

local function inWindows(list, t: number): boolean
	for _, w in ipairs(list or {}) do
		if t >= w[1] and t < w[2] then return true end
	end
	return false
end

local function driveDino(o, t: number, v: { number }, f: number, n: number)
	local A = o.A
	if not A then return end
	A.Root.CFrame = CFrame.new(v[1], v[2] + A.Lift, v[3]) * CFrame.Angles(0, v[4], 0)
	local anim = A.Anim
	if not anim then return end
	anim.Time = t
	local mode = "Idle"
	for _, k in ipairs(o.D.Loco or {}) do if t >= k[1] then mode = k[2] end end
	if anim.LocoTarget ~= mode or o.LocoSet ~= mode then
		anim.LocoTarget = mode
		for m in pairs(anim.LocoWeights) do anim.LocoWeights[m] = (m == mode) and 1 or 0 end
		o.LocoSet = mode
	end
	anim.GaitPhase = v[5] or 0
	-- the action on this frame and its own clock (set every frame: seekable, never drifts)
	local want, T = nil, 0
	if o.D.Sig and o.D.SigT then
		want = o.D.Sig.Action
		local st = o.D.SigT
		local i = math.clamp(math.floor(f), 0, n - 1)
		local j = math.min(i + 1, n - 1)
		T = st[i + 1] + (st[j + 1] - st[i + 1]) * (f - i)
	else
		for _, ac in ipairs(o.D.Acts or {}) do
			if t >= ac[1] then want, T = ac[2], (t - ac[1]) * (ac[3] or 1) end
		end
	end
	if not want then return end
	local def = anim.Profile.Actions[want]
	if not def then return end
	if not def.Loop and T > def.Duration then return end
	local live = o.Track and table.find(anim.Actions, o.Track) ~= nil
	if o.ActName ~= want or not live then
		if o.ActName == want and not live then return end -- it already finished on its own
		o.Track = anim:Play(want)
		o.ActName = want
	end
	if o.Track then
		o.Track.Speed = 0
		o.Track.T = def.Loop and (T % def.Duration) or T
	end
end

local function driveShot(rt, t: number, dt: number)
	local d = rt.D
	local n = d.N
	local f = math.clamp(t * d.Rate, 0, n - 1)
	for _, o in ipairs(rt.Actors) do
		local a = o.D
		local v = trackAt(o, f, n)
		-- visibility windows (a hatch: the egg goes, the baby arrives)
		if o.Model then
			local show = (a.ShowAt == nil or t >= a.ShowAt) and (a.HideAt == nil or t < a.HideAt)
			local want = show and rt.Set.Folder or nil
			if o.Model.Parent ~= want then o.Model.Parent = want end
		end
		if o.Glow then o.Glow.Enabled = inWindows(a.Glow, t) end
		if a.Silhouette and o.Model then
			local on = false
			for k = 1, #a.Silhouette - 1, 2 do
				if t >= a.Silhouette[k] and t < a.Silhouette[k + 1] then on = true end
			end
			if on ~= (o.SilOn == true) then
				o.SilOn = on
				Fx.Silhouette(o.Model, on, a.Rim and Fx.Colors[a.Rim] or nil, a.EyesOnly == true)
			end
		end
		if o.Kind == "Prop" and o.M and o.M.PrimaryPart then
			local cf = CFrame.new(v[1], v[2] + (o.PropLift or 0), v[3]) * CFrame.Angles(0, v[4], 0)
			o.M.PrimaryPart.CFrame = o.PropCyl and cf * CFrame.Angles(0, 0, math.pi / 2) or cf
		end
		if o.Kind == "Dino" or o.Kind == "Baby" then
			driveDino(o, t, v, f, n)
		elseif o.Kind == "Rover" and o.A then
			local root = CFrame.new(v[1], v[2] + o.A.RootHeight, v[3]) * CFrame.Angles(0, v[4], 0) * CFrame.Angles(v[5], 0, v[6])
			o.A:Set(root, v[7], v[8])
		elseif o.Kind == "Crew" and o.A then
			if a.Ride then
				local rv = rt.ById[a.Ride]
				if rv and rv.A and rv.A.CF then o.A:Sit(rv.A:Seat(a.Seat)) end
			else
				local p = Vector3.new(v[1], v[2], v[3])
				local ahead = trackAt(o, math.min(f + 1, n - 1), n)
				local back = trackAt(o, math.max(f - 1, 0), n)
				local vel = (Vector3.new(ahead[1], 0, ahead[3]) - Vector3.new(back[1], 0, back[3])) * d.Rate / 2
				o.A:Place(p, Vector3.new(-math.sin(v[4]), 0, -math.cos(v[4])), vel.Magnitude)
				-- out of a fight and empty-handed: Roblox's own walk, like a real player
				if not a.Combat and not a.Loop then o.A:Locomote(vel.Magnitude) end
			end
			if a.Carry and not o.Carrying and t >= a.Carry then
				o.Carrying = true
				local rig = PlayerAnim.Rig(o.A.Model)
				if rig then rig.Carrying = true end
			end
			-- gestures fire once as their beat passes
			local acts = a.Acts or {}
			while o.ActIdx < #acts and t >= acts[o.ActIdx + 1][1] do
				o.ActIdx += 1
				o.A:Act(acts[o.ActIdx][2])
			end
		elseif o.Kind == "Egg" and o.M then
			local up = o.M:GetAttribute("TTUp") or 1
			if a.Rack then
				local rv = rt.ById[a.Rack]
				local slot = rv and rv.A and rv.A:Slot(a.Slot)
				if slot then o.M:PivotTo(slot * CFrame.Angles(0, t * 0.6, 0)) end
			elseif a.HeldBy and t >= (a.HeldFrom or 0) then
				-- in the carrier's arms: PlayerAnim places it every frame, exactly like a player carrying an egg
				local c = rt.ById[a.HeldBy]
				if c and c.A and not o.Held then
					o.Held = true
					PlayerAnim.Hold(c.A.Model, o.M)
				end
			else
				o.M:PivotTo(CFrame.new(v[1], v[2] + up, v[3]) * CFrame.Angles(0, v[4], 0))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- gameplay clips: the real HUD on screen (camp hotbar, or the run HUD staged with the shot's numbers)
--------------------------------------------------------------------------------
local function gui(name: string): ScreenGui?
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local g = pg and pg:FindFirstChild(name)
	return (g and g:IsA("ScreenGui")) and g or nil
end

-- the HUD's own mode when the take started ("Camp" | "Run" | "Ride") and the zone it was in: a staged run HUD is put
-- back exactly as it was, never forced to camp (2026-10-14: a take played mid-run - a boss reveal - left the camp
-- HUD on over the fight). Read off DinoHUD's Camp / Run roots, since HUD keeps its mode private.
local takeHud = { Mode = "Camp", Zone = nil :: string? }
local function hudMode(): string
	local hud = gui("DinoHUD")
	if not hud then return "Camp" end
	for _, d in ipairs(hud:GetDescendants()) do
		if d.Name == "Run" and d:IsA("Frame") and d.Parent and d.Parent:FindFirstChild("Camp") then
			local camp = d.Parent:FindFirstChild("Camp") :: GuiObject
			if d.Visible or camp.Visible then return d.Visible and "Run" or "Camp" end
			-- (neither up: riding along - or a run on foot, whose HUD hides itself off the wheel; ShowRide there
			-- would have taken a driver's run HUD away for good)
			return player:GetAttribute("RidingWith") ~= nil and "Ride" or "Run"
		end
	end
	return "Camp"
end

local function uiOn(rt)
	local U = rt.D.UI
	if not U then return end
	rt.UI = true
	if U.HUD == "Run" then
		HUD.Puppet = {
			HP = math.floor((U.HP or 1) * 10 + 0.5), MaxHP = 10, Slots = U.Slots or 2, Coins = U.Coins or 0,
			Darts = U.Darts or 8, MaxDarts = U.MaxDarts or 8,
			Eggs = HttpService:JSONEncode(U.Eggs or {}),
			State = { Route = RouteMath.get(rt.D.Zone), Variant = 1, S = U.S or 0, Length = U.Length or 1000, Zone = rt.D.Zone, Boost = 0.65, Boosting = false },
		}
		local veh = U.Vehicle and Config.Vehicles[U.Vehicle]
		HUD.ShowRun({ Zone = rt.D.Zone, VehicleName = veh and veh.Name or nil })
		rt.RunShown = true
	end
	-- gameplay looks like gameplay: no film grade or focus pull on these
	if look.Dof then look.Dof.Enabled = false end
	if look.Grade then look.Grade.Enabled = false end
	mutePrompts() -- (only the staged prompt cards may show; a no-op if the take already muted them)
	ProximityPromptService.Enabled = true
end

local function uiStep(rt, t: number)
	if not rt.UI then return end
	local U = rt.D.UI
	local hud = gui("DinoHUD")
	if hud then hud.Enabled = (U.HUD == "Camp" or U.HUD == "Run") end
	local toasts = gui("DinoToasts")
	if toasts then toasts.Enabled = true end
	if HUD.Puppet and HUD.Puppet.State then HUD.Puppet.State.S = (U.S or 0) + (U.Speed or 0) * t end
end

local function uiOff(rt)
	if not rt or not rt.UI then return end
	rt.UI = false
	HUD.Puppet = nil
	if rt.RunShown then
		rt.RunShown = false
		if takeHud.Mode == "Run" then HUD.ShowRun({ Zone = takeHud.Zone })
		elseif takeHud.Mode == "Ride" then HUD.ShowRide()
		else HUD.ShowCamp() end
	end
	for _, name in ipairs({ "DinoHUD", "DinoToasts" }) do
		local g = gui(name)
		if g then g.Enabled = false end
	end
	for _, p in pairs(rt.Prompts or {}) do p:Destroy() end
	rt.Prompts = nil
	if look.Dof then look.Dof.Enabled = true end
	if look.Grade then look.Grade.Enabled = true end
	ProximityPromptService.Enabled = false
end

--------------------------------------------------------------------------------
-- cues
--------------------------------------------------------------------------------
local fx = { FovKick = 0, Shake = Cam.Shake.new() } :: any

local function cueFn(rt, cue): () -> ()
	local kind = cue[2]
	local a1, a2, a3 = cue[3], cue[4], cue[5]
	if rt.Xf then
		-- (a shot moved onto your island: its effects' world points move with it)
		local function mv(v) return typeof(v) == "Vector3" and rt.Xf * v or v end
		a1, a2, a3 = mv(a1), mv(a2), mv(a3)
	end
	return function()
		if Fx.Cue(rt, kind, a1, a2, a3, look.Grade) then return end
		if kind == "Unblack" then ui.Black.Visible = false return end
		if kind == "Shake" then fx.Shake:Kick(a1 or 1, fx.T or 0)
		elseif kind == "Punch" then fx.FovKick -= (a1 or 6)
		elseif kind == "Flash" then flash(a1 or 0.7)
		elseif kind == "Black" then ui.Black.Visible = true
		elseif kind == "Burst" and typeof(a1) == "Vector3" then CineKit.Burst(a1, a2 or 1)
		elseif kind == "Dust" and typeof(a1) == "Vector3" then DinosaurVFX.FootstepDust(a1, a2 or 1.5) DinosaurVFX.Debris(a1, (a2 or 1.5) * 0.6)
		elseif kind == "Impact" and typeof(a1) == "Vector3" then DinosaurVFX.GroundImpact(a1, a2 or 1.5)
		elseif kind == "Sparkle" and typeof(a1) == "Vector3" then
			local r = Config.Rarity[a2 or "Rare"]
			CineKit.Sparkle(a1, r and r.Color or Color3.new(1, 1, 1), 1.6)
		elseif kind == "ImpactFrame" then CineKit.ImpactFrame(a1 or 0.6)
		elseif kind == "SunBurst" then CineKit.SunBurst(a1 or 0.6)
		elseif kind == "Speed" then CineKit.SpeedLines(ui.Gui, a1 or 0.6)
		elseif kind == "Stamp" then CineKit.Stamp(ui.Gui, a1 or "", nil, Kit.Colors[a2 or "Yellow"] or Kit.Colors.Yellow, 1.2, 0.3)
		elseif kind == "RayTitle" then CineKit.RayTitle(ui.Gui, a1 or "", a2, nil, 1.6, 0.28)
		elseif kind == "Stun" then
			local o = rt.ById[a1]
			if o and o.Model then DinosaurVFX.Stunned(o.Model, a2 or 3) end
		elseif kind == "Crack" then
			local o = rt.ById[a1]
			if o and o.Model then
				local p = o.Model:GetPivot().Position
				DinosaurVFX.Debris(p, 1.2, Color3.fromRGB(240, 230, 200))
				CineKit.Burst(p, 0.7)
			end
		elseif kind == "Banner" then HUD.Banner(a1 or "", a2, a3)
		elseif kind == "Toast" then Kit.Toast(a1 or "", a2 or "Lime", a3)
		elseif kind == "Warn" then HUD.Warn(a1 or -1, 0.9)
		elseif kind == "Prompt" then
			-- the game's own prompt card (UI/Prompt.luau draws it), staged on a local prop
			local o = rt.ById[a1]
			local host = o and o.Model and (o.Model.PrimaryPart or o.Model:FindFirstChildWhichIsA("BasePart", true))
			if host then
				local pr = Instance.new("ProximityPrompt")
				pr.ActionText = a2 or "Pick up"
				pr.ObjectText = a3 or ""
				pr.HoldDuration = cue[6] or 0.45
				pr.MaxActivationDistance = 100000
				pr.RequiresLineOfSight = false
				pr.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
				pr.KeyboardKeyCode = Enum.KeyCode.E
				pr.GamepadKeyCode = Enum.KeyCode.ButtonX
				pr.Style = Enum.ProximityPromptStyle.Custom
				pr:SetAttribute("Outline", true)
				pr.Parent = host
				rt.Prompts = rt.Prompts or {}
				rt.Prompts[a1] = pr
			end
		elseif kind == "PromptHold" then
			local pr = rt.Prompts and rt.Prompts[a1]
			if pr then
				pr:InputHoldBegin()
				task.delay(pr.HoldDuration + 0.05, function() if pr.Parent then pr:InputHoldEnd() end end)
			end
		elseif kind == "PromptHide" then
			local pr = rt.Prompts and rt.Prompts[a1]
			if pr then pr.Enabled = false end
		elseif kind == "Perfect" and typeof(a1) == "Vector3" then
			-- the chase's PERFECT! hit, as Darts.luau plays it
			if Darts.Floater then Darts.Floater(a1, "PERFECT!", Kit.Colors.YellowHi) end
			DinosaurVFX.Shake(0.7, 0.25)
			DinosaurVFX.Cubes(a1, 22, { Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 255, 255), Color3.fromRGB(63, 224, 200) }, 0.45, 22, 0.8)
			DinosaurVFX.BlockRing(CFrame.new(a1) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 18, R0 = 1, R1 = 10, Color = Color3.fromRGB(255, 226, 120), Duration = 0.5, Block = 0.8 })
		elseif kind == "Dart" and typeof(a1) == "Vector3" and typeof(a2) == "Vector3" then
			local dart = rt.Set:Part({ Size = Vector3.new(0.35, 0.35, 2.4), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 90), CFrame = CFrame.lookAt(a1, a2) })
			local dur = a3 or 0.25
			task.spawn(function()
				local t0 = os.clock()
				while dart.Parent and os.clock() - t0 < dur do
					local u = (os.clock() - t0) / dur
					local p = a1:Lerp(a2, u) + Vector3.new(0, math.sin(u * math.pi) * 1.2, 0)
					dart.CFrame = CFrame.lookAt(p, a2)
					RunService.RenderStepped:Wait()
				end
				if dart.Parent then dart:Destroy() end
				CineKit.Sparkle(a2, Color3.fromRGB(255, 230, 90), 0.8)
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- the player
--------------------------------------------------------------------------------
local st = nil :: any

-- the voice-over script (a sequence's Lines, by beat) in the caption preview: each line as the take reaches it (the
-- first one through the count-in, so you can read ahead)
local function updateLine()
	local lines = st and st.Seq.Lines
	if not lines or #lines == 0 then return end
	local beat = st.Clock < 0 and -math.huge or Timeline.SecondsToBeat(st.Clock, st.Layout.BPM)
	local idx = 1
	for i, l in ipairs(lines) do if beat >= l[1] then idx = i end end
	if st.Line ~= idx then
		st.Line = idx
		Kit.SetText(ui.Caption, string.upper(tostring(lines[idx][2])))
	end
end

local function exitShot()
	if st and st.Cur then
		uiOff(st.Cur.Rt)
		st.Cur:Destroy()
		st.Cur = nil
	end
end

local function destroyShot(rt)
	if rt then rt.Set:Destroy() end
end

local function enterShot(idx: number, localT: number)
	local L = st.Layout.Shots[idx]
	local rt = (st.Next and st.NextIdx == idx) and st.Next or buildShot(L.Name)
	if st.Next and st.Next ~= rt then destroyShot(st.Next) end
	st.Next, st.NextIdx = nil, nil
	if not rt then return end
	if Zone.Current ~= rt.D.Zone then Zone.Apply(rt.D.Zone, true) end
	rt.Set:Show()
	rt.Cues = Timeline.NewCues(st.Layout.BPM)
	for _, cue in ipairs(rt.D.Cues or {}) do rt.Cues:AtTime(cue[1], cueFn(rt, cue)) end
	rt.Cues:Advance(localT - 1e-3, true)
	fx.Shake = Cam.Shake.new()
	fx.FovKick = 0
	ui.Black.Visible = false
	Fx.Reset()
	Fx.Grade(look.Grade, rt.D.Grade, 0)
	-- crew loops and aims are states, set once
	for _, o in ipairs(rt.Actors) do
		if o.Kind == "Crew" and o.A then
			-- riders sit in the driving pose players get in a vehicle seat
			if o.D.Loop then PlayerAnim.SetLoop(o.A.Model, o.D.Loop) elseif o.D.Ride then PlayerAnim.SetLoop(o.A.Model, "Drive") end
			if o.D.Aim then o.A:Aim(o.D.Aim) end
			if o.D.Combat then o.A:Combat(true, false) end
			while o.ActIdx < #(o.D.Acts or {}) and localT > o.D.Acts[o.ActIdx + 1][1] do o.ActIdx += 1 end
		end
	end
	uiOn(rt)
	if st.OverlayOn then overlayLook(idx) end
	st.Cur = { Destroy = function() destroyShot(rt) end, Rt = rt, Index = idx }
	st.Shot = idx
	-- build the next shot now, off the cut, so the next cut doesn't hitch
	local nextIdx = idx + 1
	if st.Layout.Shots[nextIdx] then
		task.defer(function()
			if st and st.Shot == idx and not st.Next then
				st.Next = buildShot(st.Layout.Shots[nextIdx].Name)
				st.NextIdx = nextIdx
			end
		end)
	end
end

local function seek(clock: number)
	exitShot()
	if st.Next then destroyShot(st.Next) st.Next, st.NextIdx = nil, nil end
	st.Clock = clock
	st.Shot = 0
end

local function updateHud()
	if not st then return end
	local L = st.Layout
	local s = L.Shots[st.Shot]
	ui.Line1.Text = string.format("%s%s", st.Seq.Name or st.Seq.Id, st.Paused and "   [PAUSED]" or "")
	if st.Clock < 0 then
		ui.Line2.Text = string.format("COUNT-IN  %.1f   (%d shots, %.2f s @ %d BPM)", st.Clock, #L.Shots, L.Dur, L.BPM)
	else
		ui.Line2.Text = string.format("SHOT %d/%d  %s   BEAT %.2f   %.2f s", st.Shot, #L.Shots, s and s.Name or "-", Timeline.SecondsToBeat(st.Clock, L.BPM), st.Clock)
	end
	local beatPhase = (Timeline.SecondsToBeat(st.Clock, L.BPM)) % 1
	ui.Beat.BackgroundTransparency = beatPhase < 0.15 and 0 or 0.75
end

local function stepFrame(dt: number)
	if not st then return end
	if not st.Paused then st.Clock += dt end
	local L = st.Layout
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	updateHud()
	-- count-in: black, numbers on the beat
	if st.Clock < 0 then
		ui.Black.Visible = true
		local beatsLeft = math.ceil(-Timeline.SecondsToBeat(st.Clock, L.BPM))
		ui.Count.Visible = st.HudOn
		Kit.SetText(ui.Count, tostring(beatsLeft))
		if not st.Cur and not st.Next then
			st.Next = buildShot(L.Shots[1].Name)
			st.NextIdx = 1
		end
		return
	end
	ui.Count.Visible = false
	if st.Clock >= L.Dur then
		if st.Paused then st.Clock = L.Dur - 1e-3 else TikTok.Stop() return end
	end
	local idx = Timeline.ShotAtBeat(L, Timeline.SecondsToBeat(st.Clock, L.BPM))
	if not st.Cur or st.Cur.Index ~= idx then
		exitShot()
		enterShot(idx, st.Clock - L.Shots[idx].Start + (L.Shots[idx].Offset or 0))
	end
	local cur = st.Cur and st.Cur.Rt
	if not cur then return end
	-- a sequence can start a shot part-way in (Offset): the shot's own clock runs from there
	local t = math.clamp(st.Clock - L.Shots[idx].Start, 0, L.Shots[idx].Dur - 1e-4) + (L.Shots[idx].Offset or 0)
	fx.T = t
	driveShot(cur, t, dt)
	uiStep(cur, t)
	cur.Cues:Advance(t)
	-- camera from the bake + handheld + impulses
	local d = cur.D
	local n = d.N
	local f = math.clamp(t * d.Rate, 0, n - 1)
	local i = math.floor(f)
	local j = math.min(i + 1, n - 1)
	local u = f - i
	local c = d.Cam
	local function ch(k: number): number return c[i * 8 + k] + (c[j * 8 + k] - c[i * 8 + k]) * u end
	local pos = Vector3.new(ch(1), ch(2), ch(3))
	local lookAt = Vector3.new(ch(4), ch(5), ch(6))
	if cur.Xf then pos, lookAt = cur.Xf * pos, cur.Xf * lookAt end
	local cf = CFrame.lookAt(pos, lookAt) * CFrame.Angles(0, 0, math.rad(ch(8)))
	cf = Cam.handheld(cf, st.Clock, d.Hand or 0)
	cf = fx.Shake:Apply(cf, t)
	if not st.Paused then fx.FovKick *= math.exp(-dt * 6) end
	cam.CFrame = cf
	cam.FieldOfView = math.clamp(ch(7) + fx.FovKick, 10, 110)
	if look.Dof then
		local dist = (lookAt - pos).Magnitude
		look.Dof.FocusDistance = math.clamp(dist, 1, 200)
		look.Dof.InFocusRadius = math.clamp(dist * 0.4, 3, 60)
	end
	-- the hidden world can grow (a new player joins, a site respawns): re-hide now and then
	st.Rehide = (st.Rehide or 0) + dt
	if st.Rehide > 0.5 then
		st.Rehide = 0
		hideWorld()
		hideTree(Workspace:FindFirstChild("DinoAmbience"))
		if st.HideCamp then hideTree(Workspace:FindFirstChild("DinoCampLocal")) end
		for _, m in ipairs(st.HideExtra or {}) do hideTree(m) end
	end
	updateLine()
	overlayStep(st.Clock)
	-- keep the cutscene token alive past Cinema's 40 s safety release
	if os.clock() - st.TokenAt > 25 then
		local fresh = Cinema.Begin("DinoTikTokUI")
		Cinema.End(st.Token)
		st.Token, st.TokenAt = fresh, os.clock()
	end
end

-- (2026-10-14) a frame that throws must never strand anyone in a cutscene: an in-game reveal ends on the first error
-- (the camera goes back, the fight starts); a recording take only gives up if it keeps failing
local function step(dt: number)
	local ok, err = pcall(stepFrame, dt)
	if ok or not st then return end
	warn("[TikTok] frame:", err)
	st.Errors = (st.Errors or 0) + 1
	if st.Cutscene or st.Errors > 30 then TikTok.Stop() end
end

local KEYS = {
	Enum.KeyCode.Space, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.LeftBracket, Enum.KeyCode.RightBracket,
	Enum.KeyCode.R, Enum.KeyCode.H, Enum.KeyCode.G, Enum.KeyCode.C, Enum.KeyCode.T, Enum.KeyCode.X, Enum.KeyCode.Backspace,
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
}
local function onKey(_, state, input)
	if state ~= Enum.UserInputState.Begin or not st then return Enum.ContextActionResult.Sink end
	local L = st.Layout
	local k = input.KeyCode
	if k == Enum.KeyCode.Space then
		st.Paused = not st.Paused
		require(Shared:WaitForChild("DinosaurAnimations")).TimeScale = st.Paused and 0 or 1
	elseif k == Enum.KeyCode.Right or k == Enum.KeyCode.Left then
		local cur = math.max(1, st.Shot)
		local to = math.clamp(cur + (k == Enum.KeyCode.Right and 1 or -1), 1, #L.Shots)
		if st.Clock < 0 then to = 1 end
		seek(L.Shots[to].Start)
	elseif k == Enum.KeyCode.RightBracket or k == Enum.KeyCode.LeftBracket then
		local beat = math.floor(Timeline.SecondsToBeat(math.max(0, st.Clock), L.BPM) + 0.5) + (k == Enum.KeyCode.RightBracket and 1 or -1)
		seek(Timeline.BeatToSeconds(math.clamp(beat, 0, L.Beats - 1), L.BPM))
	elseif k == Enum.KeyCode.R then
		seek(-Timeline.BeatToSeconds(COUNT_IN, L.BPM))
		st.Paused = false
		require(Shared:WaitForChild("DinosaurAnimations")).TimeScale = 1
	elseif k == Enum.KeyCode.H then
		st.HudOn = not st.HudOn
		ui.Hud.Visible = st.HudOn
	elseif k == Enum.KeyCode.G then
		ui.GuidesOn = not ui.GuidesOn
		showGuides()
	elseif k == Enum.KeyCode.C then
		ui.Caption.Visible = not ui.Caption.Visible
	elseif k == Enum.KeyCode.T then
		-- the Overlay word on / off (only a sequence with one has it)
		local on = st.OverlayOn == true and not ui.Overlay.Visible
		ui.Overlay.Visible = on
		ui.OverlayShade.Visible = on
	elseif k == Enum.KeyCode.X or k == Enum.KeyCode.Backspace then
		TikTok.Stop()
	end
	return Enum.ContextActionResult.Sink
end

-- the in-game cutscene's skip: hold E / X / a click / a touch for 0.6 s (after the first second)
local skipConn = nil :: RBXScriptConnection?
-- (UserInputService has no GetTouches - that call threw every frame and broke the skip: count fingers down instead)
local touchesDown = {} :: { [InputObject]: boolean }
do
	local UIS = game:GetService("UserInputService")
	UIS.TouchStarted:Connect(function(t) touchesDown[t] = true end)
	UIS.TouchEnded:Connect(function(t) touchesDown[t] = nil end)
end
local function skipStep(dt: number)
	if not (st and st.Cutscene) then return end
	local UIS = game:GetService("UserInputService")
	local held = UIS:IsKeyDown(Enum.KeyCode.E) or UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	for _, gp in ipairs({ Enum.UserInputType.Gamepad1 }) do
		for _, k in ipairs(UIS:GetGamepadState(gp)) do
			if (k.KeyCode == Enum.KeyCode.ButtonX or k.KeyCode == Enum.KeyCode.ButtonA) and k.UserInputState == Enum.UserInputState.Begin then held = true end
		end
	end
	if next(touchesDown) ~= nil then held = true end
	local ready = st.Clock > 1
	ui.Skip.Visible = ready
	-- (a fresh press only: a fire button or a finger already down when the scene started - mid-charge, on the
	-- thumbstick - must be let go first, or the scene skipped itself a second in)
	if ready and not held then st.SkipArmed = true end
	held = held and st.SkipArmed == true
	st.SkipHold = (held and ready) and (st.SkipHold or 0) + dt or math.max(0, (st.SkipHold or 0) - dt * 2)
	ui.SkipFill.Size = UDim2.fromScale(math.clamp(st.SkipHold / 0.6, 0, 1), 1)
	if st.SkipHold >= 0.6 then
		st.Skipped = true
		TikTok.Stop()
	end
end

-- opts: { FromShot?, FromBeat?, Countdown? (default true), Cutscene? (in-game: letterbox, no help HUD or keys,
-- hold to skip), Hide? { Instance } (more of the live world to hide, e.g. the real boss) }
function TikTok.PlaySequence(seq, opts)
	opts = opts or {}
	if TikTok.Playing then TikTok.Stop() end
	buildUi()
	local layout = Timeline.Layout(seq)
	if #layout.Shots == 0 then return end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	st = {
		Seq = seq, Layout = layout, Clock = 0, Shot = 0, Paused = false, HudOn = true,
		Token = Cinema.Begin("DinoTikTokUI"), TokenAt = os.clock(),
		ZoneWas = Zone.Current, Hum = hum, WalkWas = hum and hum.WalkSpeed, JumpWas = hum and hum.JumpPower,
	}
	if opts.FromShot then st.Clock = layout.Shots[math.clamp(opts.FromShot, 1, #layout.Shots)].Start
	elseif opts.FromBeat then st.Clock = Timeline.BeatToSeconds(opts.FromBeat, layout.BPM)
	elseif opts.Countdown ~= false then st.Clock = -Timeline.BeatToSeconds(COUNT_IN, layout.BPM) end
	TikTok.Playing = true
	takeHud.Mode, takeHud.Zone = hudMode(), Zone.Current
	st.Cutscene = opts.Cutscene == true
	if hum then hum.WalkSpeed = 0 hum.JumpPower = 0 end
	Drive.HoldCamera(true)
	Drive.SetCameraOverride(true)
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	hideWorld()
	hideTree(Workspace:FindFirstChild("DinoAmbience"))
	-- a take on your island stages its own dinos in your paddock: your real ones (and the nest eggs) step out of it
	local stagedOn = nil
	for _, sh in ipairs(layout.Shots) do
		local d = Data.Shots[sh.Name]
		if d and d.Plot then st.HideCamp, stagedOn = true, stagedOn or d.Plot end
	end
	if st.HideCamp then
		hideTree(Workspace:FindFirstChild("DinoCampLocal"))
		-- ...and so do the loose boulders scattered in it (every island throws its own, where a staged dino may stand;
		-- the take was baked on bare ground, clear of the staging island's)
		local camp = Workspace:FindFirstChild("BaseCamp")
		local plot = camp and camp:FindFirstChild("Plot" .. tostring(tonumber(player:GetAttribute("Plot")) or stagedOn), true)
		local paddock = plot and plot:FindFirstChild("Paddock", true)
		for _, d in ipairs(paddock and paddock:GetDescendants() or {}) do
			if d:IsA("BasePart") and d.Name == "Rock" and hidden[d] == nil then
				hidden[d] = d.LocalTransparencyModifier
				d.LocalTransparencyModifier = 1
			end
		end
	end
	for _, m in ipairs(opts.Hide or {}) do hideTree(m) end
	st.HideExtra = opts.Hide
	-- (2026-10-14: an in-game reveal keeps the prompt service off throughout, so it skips the whole-workspace sweep -
	-- every era map is loaded, and that sweep was a hitch on the reveal's first frame. uiOn mutes them if needed)
	if not st.Cutscene then mutePrompts() end
	ProximityPromptService.Enabled = false
	gradeOn()
	ui.Gui.Enabled = true
	ui.Hud.Visible = not st.Cutscene
	st.HudOn = not st.Cutscene
	Fx.Letterbox(st.Cutscene)
	ui.Skip.Visible = false
	st.Line = nil
	Kit.SetText(ui.Caption, string.upper(seq.Hook ~= "" and seq.Hook or "your caption here"))
	setAspect(seq.Aspect)
	updateLine()
	st.OverlayOn = typeof(seq.Overlay) == "string" and seq.Overlay ~= ""
	ui.Overlay.Text = st.OverlayOn and seq.Overlay or ""
	ui.OverlayShade.Text = ui.Overlay.Text
	ui.Overlay.Visible = st.OverlayOn
	ui.OverlayShade.Visible = st.OverlayOn
	overlayLook(1)
	if st.Cutscene then
		skipConn = RunService.RenderStepped:Connect(skipStep)
	else
		ContextActionService:BindActionAtPriority("DinoTikTokKeys", onKey, false, Enum.ContextActionPriority.High.Value + 50, table.unpack(KEYS))
	end
	RunService:BindToRenderStep("DinoTikTok", Enum.RenderPriority.Camera.Value + 1, step)
end

function TikTok.Play(seqId: string, opts)
	for _, s in ipairs(Data.Sequences) do
		if s.Id == seqId then
			TikTok.PlaySequence(s, opts)
			return
		end
	end
	warn("[TikTok] no sequence", seqId)
end

-- an in-game cutscene (a boss reveal): plays the sequence with a letterbox and hold-to-skip, and yields until it
-- ends. Returns false if there's no such sequence (the caller falls back to its own scene).
function TikTok.PlayCutscene(seqId: string, opts): boolean
	local seq = nil
	for _, s in ipairs(Data.Sequences) do if s.Id == seqId then seq = s end end
	if not seq then return false end
	opts = opts or {}
	local ok, err = pcall(TikTok.PlaySequence, seq, { Countdown = false, Cutscene = true, Hide = opts.Hide })
	if not ok then
		-- (it never got going: put everything back and let the caller play its own scene)
		warn("[TikTok] cutscene:", err)
		if st and st.Seq == seq then TikTok.Stop() end
		return false
	end
	if not (st and st.Seq == seq) then return false end -- (an empty sequence never starts: same as a failure)
	local t0 = os.clock()
	while st and st.Seq == seq and os.clock() - t0 < 40 do task.wait() end
	if st and st.Seq == seq then TikTok.Stop() end
	return true
end

-- the boss reveal sequence for a boss id, if one is baked
function TikTok.RevealFor(bossId: string): string?
	for _, s in ipairs(Data.Sequences) do if s.Boss == bossId then return s.Id end end
	return nil
end

function TikTok.PlayShot(name: string)
	local d = Data.Shots[name]
	if not d then return end
	TikTok.PlaySequence({ Id = name, Name = "SHOT: " .. name, Hook = "", Shots = { { name, d.Beats } } })
end

function TikTok.Stop()
	if not st then return end
	local s = st
	st = nil
	TikTok.Playing = false
	-- (2026-10-14) every step on its own: one that throws (a set that won't destroy, a zone that won't apply) must
	-- not skip the rest - above all the camera and the screen going back to the player
	local function try(what: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then warn("[TikTok] stop (" .. what .. "):", err) end
	end
	try("unbind", function()
		RunService:UnbindFromRenderStep("DinoTikTok")
		ContextActionService:UnbindAction("DinoTikTokKeys")
		if skipConn then skipConn:Disconnect() skipConn = nil end
	end)
	try("fx", function()
		if ui.Skip then ui.Skip.Visible = false end
		Fx.RestoreWorld()
	end)
	TikTok.LastSkipped = s.Skipped == true
	try("timescale", function() require(Shared:WaitForChild("DinosaurAnimations")).TimeScale = 1 end)
	try("sets", function()
		if s.Cur then uiOff(s.Cur.Rt) s.Cur.Destroy() end
		if s.Next then destroyShot(s.Next) end
		local folder = Workspace:FindFirstChild("DinoTikTok")
		if folder then folder:ClearAllChildren() end
	end)
	try("overlay", function()
		ui.Gui.Enabled = false
		ui.Black.Visible = false
		ui.Overlay.Visible = false
		ui.OverlayShade.Visible = false
	end)
	try("grade", gradeOff)
	try("world", function()
		showWorld()
		unmutePrompts()
	end)
	try("zone", function() if s.ZoneWas and Zone.Current ~= s.ZoneWas then Zone.Apply(s.ZoneWas, true) end end)
	try("humanoid", function()
		if s.Hum and s.Hum.Parent then
			s.Hum.WalkSpeed = s.WalkWas or 16
			s.Hum.JumpPower = s.JumpWas or 50
		end
	end)
	try("camera", function()
		local cam = Workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		if s.Hum and s.Hum.Parent then cam.CameraSubject = s.Hum end
	end)
	try("drive", function()
		Drive.HoldCamera(false)
		Drive.SetCameraOverride(false)
	end)
	try("cinema", function() Cinema.End(s.Token) end)
end

-- the menu: sequences grouped by category, plus every single shot
function TikTok.Catalog()
	local out = {}
	for _, cat in ipairs(Data.Categories or {}) do
		local list = {}
		if cat == "SHOTS" then
			local names = {}
			for name in pairs(Data.Shots) do table.insert(names, name) end
			table.sort(names)
			for _, name in ipairs(names) do table.insert(list, { Kind = "Shot", Id = name, Name = name, Beats = Data.Shots[name].Beats }) end
		else
			for _, s in ipairs(Data.Sequences) do
				if s.Category == cat then
					local beats = 0
					for _, sh in ipairs(s.Shots) do beats += sh[2] end
					table.insert(list, { Kind = "Sequence", Id = s.Id, Name = s.Name, Beats = beats })
				end
			end
		end
		if #list > 0 then table.insert(out, { Name = cat, Items = list }) end
	end
	return out
end

return TikTok
