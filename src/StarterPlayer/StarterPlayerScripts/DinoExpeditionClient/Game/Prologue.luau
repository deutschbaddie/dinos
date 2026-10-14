--[[
	Prologue — the cold open, a new player's first ~37 seconds (2026-10-13 remake: "the first shots are inside
	walls, the shot on top of the car and the bird's-eye are bad - remake it, very cinematic, 35-40 s, not playable").

	  ~31 s of baked cinematic in Fern Valley (tools/gen/anim/prologue.js -> TikTok sequence PROLOGUE): every camera is
	  solved against the real map and QC'd for clipping / blocked subjects, so nothing films the inside of a wall.
	    black, the radio -> you carry the last egg away from the nest to the starter rover -> a giant print, a puddle
	    ripples on each thud -> birds burst off the ridge, a roar behind it, a palm goes down -> the king rises over
	    the rim (a black shape, burning eyes) and roars as the light hits him -> he leaps into the meadow ("THAT'S NOT
	    THUNDER. DRIVE!") -> the rover peels out, the king charging in -> it snaps at the bumper -> an egg goes, slow
	    motion -> the portal ahead -> it rams you, the rover cartwheels (slow) -> it roars after you -> white
	  Sound: silence and jungle under the build-up (the jungle hushes on the first thud), the chase track on DRIVE, the
	  rover's engine under the chase until the hit.
	  ~6 s waking up at camp: your eyes clear on a two-shot of you and the Armorer, then a single on him; every
	  lens is checked clear of the map and of both bodies.

	Three radio lines in all. The T. rex is never named: its name card is saved for the real fight. Nothing here touches
	the server, so it can't break a run. Prologue.Play(opts) yields until you're at camp (opts are ignored now).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurVFX = require(Shared:WaitForChild("DinosaurVFX"))
local DinoAnims = require(Shared:WaitForChild("DinosaurAnimations"))

local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local Stage = require(script.Parent.TikTok.Stage)
local Zone = require(script.Parent.Zone)
local Audio = require(script.Parent.Audio)
local PlayerAnim = require(script.Parent.PlayerAnim)

local player = Players.LocalPlayer
local C = Theme.C
local Prologue = {}
Prologue.Playing = false
local activeCine = nil -- the Cinema token, so a failure can always hand the screen back

local SEQ = "PROLOGUE"

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- seconds into the sequence at which `shot` has played `beat` beats (from the baked data, so retiming the shots in
-- prologue.js moves the radio lines with them)
local function timing(): ((shot: string, beat: number) -> number?, number)
	local Data = require(script.Parent.TikTok.Data) :: any
	local seq = nil
	for _, s in ipairs(Data.Sequences) do if s.Id == SEQ then seq = s end end
	local bpm = (seq and seq.BPM) or (Data.Music and Data.Music.BPM) or 123
	local starts, at = {}, 0
	for _, e in ipairs(seq and seq.Shots or {}) do
		starts[e[1]] = starts[e[1]] or at
		at += e[2]
	end
	return function(shot: string, beat: number): number?
		local b = starts[shot]
		return b and (b + beat) * 60 / bpm or nil
	end, at * 60 / bpm
end

--------------------------------------------------------------------------------
-- THE ARMORER's portrait for the radio card (the Mechanic NPC; he was the Quartermaster until 2026-10-14)
--------------------------------------------------------------------------------
local function mechanicModel(): Model?
	for _, m in ipairs(CollectionService:GetTagged("DinoNpc")) do
		if m:IsA("Model") and m:GetAttribute("Npc") == "Mechanic" and m:FindFirstChild("Head") then return m end
	end
	return nil
end

-- a ViewportFrame in `parent` showing his head and shoulders; returns a refresh that swaps the real NPC in once he
-- has spawned (until then a blocky stand-in in his colours: green cap, goggles, orange overalls)
local function portrait(parent: GuiObject): () -> ()
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, -10, 1, -10)
	vp.Position = UDim2.fromOffset(5, 5)
	vp.BackgroundColor3 = Color3.fromRGB(40, 64, 50)
	vp.Ambient = Color3.fromRGB(175, 175, 175)
	vp.LightColor = Color3.fromRGB(255, 240, 220)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.ZIndex = 48
	vp.Parent = parent
	Kit.Corner(vp, 9)
	-- (a WorldModel: the way a rigged character is meant to sit in a viewport)
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local vcam = Instance.new("Camera")
	vcam.FieldOfView = 28
	vcam.Parent = vp
	vp.CurrentCamera = vcam
	local function frameOn(head: Vector3, fwd: Vector3)
		local c = head + Vector3.new(0, -0.4, 0)
		local right = fwd:Cross(Vector3.yAxis)
		vcam.CFrame = CFrame.lookAt(c + fwd * 5.8 + right * 1.1 + Vector3.new(0, 0.4, 0), c)
	end
	local real = false
	local function useReal(): boolean
		local m = mechanicModel()
		if not m then return false end
		local was = m.Archivable
		m.Archivable = true
		local ok, c = pcall(function() return m:Clone() end)
		m.Archivable = was
		if not ok or not c then return false end
		local head = c:FindFirstChild("Head") :: BasePart?
		if not head then c:Destroy() return false end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				pcall(function() (d :: any).LocalTransparencyModifier = 0 end)
			elseif d:IsA("Decal") and d.Name == "face" then
				d.Transparency = 0
			end
		end
		world:ClearAllChildren()
		c.Parent = world
		local root = c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local look = (root or head).CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		frameOn(head.Position, fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1))
		real = true
		return true
	end
	local function standIn()
		local m = Instance.new("Model")
		local function block(size: Vector3, at: Vector3, color: Color3, neon: boolean?): Part
			local p = Instance.new("Part")
			p.Anchored = true
			p.Size = size
			p.CFrame = CFrame.new(at)
			p.Color = color
			p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = m
			return p
		end
		local orange, green, dark = Color3.fromRGB(255, 138, 36), Color3.fromRGB(47, 107, 58), Color3.fromRGB(43, 45, 49)
		local head = block(Vector3.new(1.25, 1.25, 1.25), Vector3.zero, Color3.fromRGB(201, 140, 94))
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
		block(Vector3.new(1.35, 0.45, 1.3), Vector3.new(0, 0.7, 0), green) -- cap
		block(Vector3.new(1.05, 0.12, 0.7), Vector3.new(0, 0.5, 0.85), green) -- brim (worn backwards)
		block(Vector3.new(1.3, 0.28, 0.12), Vector3.new(0, 0.42, -0.64), dark) -- goggle strap
		for _, s in ipairs({ -1, 1 }) do block(Vector3.new(0.36, 0.22, 0.06), Vector3.new(s * 0.28, 0.42, -0.71), Color3.fromRGB(127, 227, 255), true) end
		block(Vector3.new(2, 2, 1), Vector3.new(0, -1.62, 0), orange) -- torso
		block(Vector3.new(1.3, 1.1, 0.08), Vector3.new(0, -1.95, -0.53), Color3.fromRGB(224, 115, 26)) -- bib
		for _, s in ipairs({ -1, 1 }) do
			block(Vector3.new(0.28, 1.0, 0.08), Vector3.new(s * 0.55, -1.15, -0.53), Color3.fromRGB(224, 115, 26)) -- straps
			block(Vector3.new(1, 2, 1), Vector3.new(s * 1.5, -1.62, 0), orange) -- arms
		end
		m.Parent = world
		frameOn(Vector3.zero, Vector3.new(0, 0, -1))
	end
	if not useReal() then standIn() end
	return function()
		if not real then useReal() end
	end
end

--------------------------------------------------------------------------------
local engineLoop: Sound? = nil -- (the rover's engine under the chase; module-level so a failure can always stop it)

local function run()
	local cam = Workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	-- our own layer over the cutscene: the radio and the white burn into camp
	local cine = Cinema.Begin("DinoPrologue")
	cine.Long = true
	activeCine = cine
	local gui, canvas = Kit.Screen("DinoPrologue", 56, true)
	gui.DisplayOrder = 220 -- (over the cutscene player's own screen)
	local root = gui:FindFirstChild("Root") :: Frame
	canvas.ZIndex = 30
	local fade = Instance.new("Frame")
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BorderSizePixel = 0
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 50
	fade.Parent = root

	-- THE ARMORER on the radio: his face, his name, one short typed line at a time. On the radio his picture
	-- crackles with static; in person (the wake-up at camp) it's clean.
	local radio = {}
	do
		-- (sits just above the cutscene's bottom letterbox bar, never under it)
		local box, body = Kit.Brick(canvas, { Name = "Radio", Size = UDim2.fromOffset(560, 104), Position = UDim2.new(0, 24, 0.925, -12), AnchorPoint = Vector2.new(0, 1), Color = "Forest", Radius = 16, Lip = 5, ZIndex = 44, ShadowT = 0.4 })
		box.Visible = false
		local _, ptBody = Kit.Brick(body, { Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0, 10, 0.5, -2), AnchorPoint = Vector2.new(0, 0.5), Color = "Orange", Radius = 12, Lip = 4, ZIndex = 46 })
		-- his face (2026-10-14 playtest: "the Quartermaster's icon doesn't show up"): the cold open starts a second after
		-- a brand-new player joins, often before the server has finished building him from his HumanoidDescription, so
		-- the card used to come up empty. Now a blocky stand-in in his colours always fills it, and the real NPC is
		-- swapped in the moment he exists (checked on every line).
		local refreshFace = portrait(ptBody)
		-- radio static over the picture: rolling bands + a flicker
		local static = Instance.new("Frame")
		static.BackgroundColor3 = Color3.fromRGB(220, 255, 230)
		static.BorderSizePixel = 0
		static.Size = UDim2.new(1, -10, 1, -10)
		static.Position = UDim2.fromOffset(5, 5)
		static.ZIndex = 50
		static.Parent = ptBody
		Kit.Corner(static, 9)
		local bands = Instance.new("UIGradient")
		bands.Rotation = 90
		bands.Parent = static
		-- name tab + the RADIO chip
		local _, tabBody = Kit.Brick(body, { Size = UDim2.fromOffset(196, 28), Position = UDim2.new(0, 106, 0, -15), Color = "Orange", Radius = 10, Lip = 3, ZIndex = 47 })
		Kit.Text(tabBody, "THE ARMORER", { Pixel = true, Size = UDim2.new(1, -16, 0, 11), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 49, Stroke = 2, Shadow = 1, MaxSize = 11 })
		local chip = Instance.new("Frame")
		chip.BackgroundTransparency = 1
		chip.Size = UDim2.fromOffset(84, 14)
		chip.Position = UDim2.new(1, -96, 0, 10)
		chip.ZIndex = 47
		chip.Parent = body
		local dot = Instance.new("Frame")
		dot.BackgroundColor3 = C.Red
		dot.Size = UDim2.fromOffset(9, 9)
		dot.Position = UDim2.new(0, 0, 0.5, 0)
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.ZIndex = 48
		dot.Parent = chip
		Kit.Corner(dot, 5)
		Kit.Text(chip, "RADIO", { Pixel = true, Size = UDim2.new(1, -16, 0, 9), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 48, Stroke = 1.5, Shadow = 1, MaxSize = 9, Color = C.RedHi })
		local line = Kit.Text(body, "", { Size = UDim2.new(1, -124, 0, 58), Position = UDim2.fromOffset(108, 26), Align = Enum.TextXAlignment.Left, ZIndex = 47, Stroke = 3, Shadow = 2, MaxSize = 25 })
		local labels = {}
		for _, l in ipairs(line:GetChildren()) do if l:IsA("TextLabel") then l.TextYAlignment = Enum.TextYAlignment.Top table.insert(labels, l) end end
		local token = 0
		local onRadio = true
		local hideTween: Tween? = nil
		task.spawn(function()
			while box.Parent do
				local t = os.clock()
				static.Visible = onRadio
				if onRadio then
					local o = (t * 1.7) % 1
					bands.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.93), NumberSequenceKeypoint.new(math.clamp(o - 0.05, 0.01, 0.97), 0.93),
						NumberSequenceKeypoint.new(math.clamp(o, 0.02, 0.98), 0.7), NumberSequenceKeypoint.new(math.clamp(o + 0.05, 0.03, 0.99), 0.93), NumberSequenceKeypoint.new(1, 0.93),
					})
					static.BackgroundTransparency = 0.82 + math.noise(t * 14, 2.2) * 0.12
				end
				chip.Visible = onRadio
				dot.BackgroundTransparency = (math.floor(t * 2.5) % 2 == 0) and 0 or 0.7
				RunService.RenderStepped:Wait()
			end
		end)
		-- one line: pops the box in (if it was down), types it out with blips, holds, then lets it go
		function radio.Say(text: string, hold: number?, inPerson: boolean?)
			token += 1
			local my = token
			onRadio = not inPerson
			refreshFace()
			for _, l in ipairs(labels) do l.MaxVisibleGraphemes = 0 end
			Kit.SetText(line, text)
			if hideTween then hideTween:Cancel() hideTween = nil Kit.UIScale(box).Scale = 1 end
			if not box.Visible then box.Visible = true Kit.Pop(box, 0.6) end
			Kit.Punch(box, 0.04)
			task.spawn(function()
				local n = utf8.len(text) or #text
				local t0 = os.clock()
				local shown = 0
				while shown < n and token == my and box.Parent do
					shown = math.min(n, math.floor((os.clock() - t0) * 42) + 1)
					for _, l in ipairs(labels) do l.MaxVisibleGraphemes = shown end
					if shown % 3 == 0 then Kit.Sound("Click", 0.12, onRadio and 1.6 or 1.3) end
					RunService.RenderStepped:Wait()
				end
				for _, l in ipairs(labels) do l.MaxVisibleGraphemes = -1 end
				task.wait(hold or 2.2)
				if token == my and box.Parent then
					local sc = Kit.UIScale(box)
					local tw = TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.6 })
					tw.Completed:Connect(function(state) if token == my and state == Enum.PlaybackState.Completed then box.Visible = false sc.Scale = 1 end end)
					hideTween = tw
					tw:Play()
				end
			end)
		end
		function radio.Hide()
			token += 1
			box.Visible = false
		end
	end

	-- the real character waits at camp, hidden and still (its controls off and anchored: on touch the cutscene's
	-- skip hold is the same screen the thumbstick lives on)
	if hum then hum:SetAttribute("Frozen", true) end
	Prologue.SetControls(false)
	local rootWas = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local anchoredWas = rootWas and rootWas.Anchored
	if rootWas then rootWas.Anchored = true end
	local hidden = {}
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				hidden[d] = d.LocalTransparencyModifier
				d.LocalTransparencyModifier = 1
			end
		end
	end
	Zone.Apply("FernValley", true)
	-- the sound: no music under the build-up, only the jungle (which goes quiet on the first thud); the chase track
	-- slams in with DRIVE, and the rover's engine runs under the chase until the hit
	Audio.SetMusic(nil)

	-- 1. THE CINEMATIC (baked). The radio rides along on the sequence's own clock.
	local TikTok = require(script.Parent.TikTok) :: any
	local at, total = timing()
	local alive = true
	local function cueAt(t: number?, fn: () -> ())
		if not t then return end
		task.delay(t, function() if alive and TikTok.Playing then fn() end end)
	end
	fade.BackgroundTransparency = 1
	cueAt(0.15, function() radio.Say("RANGER... DID YOU GET THE EGGS?", 1.6) end)
	-- (Audio's zone watcher starts the Fern Valley track within half a second of the zone change: hush it again)
	cueAt(0.6, function() Audio.SetMusic(nil) end)
	cueAt(at("PRO_Print", 1.0), function() Audio.AmbienceLevel(0.25) end)
	cueAt(at("PRO_Leap", 2.9), function() radio.Say("THAT'S NOT THUNDER. DRIVE!", 1.5) end)
	local pushed = false
	cueAt(at("PRO_PeelOut", 0), function() pushed = true Audio.Push("Chase") end)
	cueAt(at("PRO_PeelOut", 0.3), function()
		if engineLoop then engineLoop:Destroy() end
		local s = Audio.Loop("EngineLoop")
		if s then
			s.PlaybackSpeed = 1.3
			s.Volume = 0
			TweenService:Create(s, TweenInfo.new(0.4), { Volume = 0.55 }):Play()
		end
		engineLoop = s
	end)
	cueAt(at("PRO_Slam", 1.4), function()
		local s = engineLoop
		engineLoop = nil
		if s then
			-- the engine chokes off on the hit
			TweenService:Create(s, TweenInfo.new(0.5), { Volume = 0, PlaybackSpeed = 0.6 }):Play()
			task.delay(0.55, function() s:Destroy() end)
		end
	end)
	cueAt(at("PRO_Slam", 1.5), function() radio.Say("RANGER?!", 1.4) end)
	-- the last shot burns to white: our own white takes over a beat before the sequence lets go, so the world
	-- never flashes back between the cutscene and camp
	cueAt(total - 0.45, function()
		fade.BackgroundColor3 = Color3.new(1, 1, 1)
		TweenService:Create(fade, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	end)
	TikTok.PlayCutscene(SEQ)
	alive = false
	local skipped = TikTok.LastSkipped == true
	radio.Hide()
	-- under white: everything back the way it was
	fade.BackgroundColor3 = Color3.new(1, 1, 1)
	fade.BackgroundTransparency = 0
	if pushed then Audio.Pop() end
	if engineLoop then engineLoop:Destroy() engineLoop = nil end
	Audio.AmbienceLevel(1)
	DinoAnims.TimeScale = 1
	for d, v in pairs(hidden) do if d.Parent then d.LocalTransparencyModifier = v end end
	Zone.Apply("BaseCamp", true)
	Audio.SetMusic("Camp")
	cam.CameraType = Enum.CameraType.Scriptable
	-- (TikTok.Stop let go of the rover's camera: hold it again for the wake-up, or replaying this from the gallery
	-- while sat in your rover has the chase cam fighting every shot)
	local Drive = require(script.Parent.Drive)
	Drive.HoldCamera(true)
	Drive.SetCameraOverride(true)

	-- 2. WAKE UP at camp: two low shots (no bird's-eye): a two-shot from the side as you come to, your eyes clearing
	-- (a lone wheel off your rover rolls in behind you and tips over), then a clean single on him from beside you, on
	-- the same side of the line. Every lens is checked clear of walls AND of both bodies (2026-10-14 playtest: "the
	-- first shot of the Quartermaster is inside his arm") - your island has a lodge and a garage close by.
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and not skipped then
		local at0 = hrp.Position
		local fwd = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
		local side = fwd:Cross(Vector3.yAxis)
		local campSet = Stage.new("PrologueCamp")
		campSet:Show()
		-- a clear lens: nothing solid within a stud of it, and nothing between it and what it looks at
		local occl = RaycastParams.new()
		occl.FilterType = Enum.RaycastFilterType.Exclude
		occl.FilterDescendantsInstances = { campSet.Folder, char :: Instance }
		local olap = OverlapParams.new()
		olap.FilterType = Enum.RaycastFilterType.Exclude
		olap.FilterDescendantsInstances = { campSet.Folder, char :: Instance }
		local function lensClear(e: Vector3, look: Vector3): boolean
			if e.Y < Stage.Ground(e, 10).Y + 1.2 then return false end
			for _, p in ipairs(Workspace:GetPartBoundsInRadius(e, 1.2, olap)) do
				if p.CanCollide and p.Transparency < 0.6 then return false end
			end
			return Workspace:Raycast(look, e - look, occl) == nil
		end
		-- he stands over you, on whichever side of you is open
		local qmAt = Stage.Ground(at0 + fwd * 4.5 + side * 2.5, 10)
		for _, o in ipairs({ fwd * 4.5 + side * 2.5, fwd * 4.5 - side * 2.5, -fwd * 4.5 + side * 2.5, side * 4.5, -side * 4.5 }) do
			local p = Stage.Ground(at0 + o, 10)
			if not Workspace:Raycast(at0 + Vector3.new(0, 2, 0), (p - at0) + Vector3.new(0, 0, 0), occl) then qmAt = p break end
		end
		local toYou = Vector3.new(at0.X - qmAt.X, 0, at0.Z - qmAt.Z)
		toYou = toYou.Magnitude > 0.1 and toYou.Unit or -fwd
		local qside = toYou:Cross(Vector3.yAxis)
		local qm = nil
		for _, m in ipairs(CollectionService:GetTagged("DinoNpc")) do
			if m:IsA("Model") and m:GetAttribute("Npc") == "Mechanic" then qm = campSet:Crew(2, m) break end
		end
		if qm then qm:Place(qmAt, toYou, 0) qm:Locomote(0) end
		-- the wheel: off the starter rover's template, rolling in behind you
		local wheel: Model? = nil
		local templates = Shared:FindFirstChild("Vehicles")
		local t = templates and (templates:FindFirstChild("RookieRanger") or templates:FindFirstChild("RaptorRunner"))
		local wf = t and t:FindFirstChild("Wheels")
		local w = (wf and wf:FindFirstChild("WheelFL")) or (t and t:FindFirstChild("WheelFL", true))
		if w and w:IsA("Model") then
			wheel = w:Clone()
			for _, d in ipairs((wheel :: Model):GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
				elseif not (d:IsA("SpecialMesh") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance")) then d:Destroy() end
			end
			(wheel :: Model).Parent = campSet.Folder
		end
		local feet = Stage.Ground(at0, 4)
		local him = qmAt + Vector3.new(0, 4.1, 0) -- (his face: R6, feet on the ground)
		-- the two bodies as boxes (a character is 4 wide across the arms, ~5.2 tall; he carries a wrench in front):
		-- no lens may sit inside one, and the line to whoever is in shot may not pass through the other
		local bodies = {
			You = { CF = CFrame.lookAt(feet + Vector3.new(0, 2.6, 0), feet + Vector3.new(0, 2.6, 0) + fwd), Half = Vector3.new(1.8, 2.8, 1.8) }, -- (any facing)
			Him = { CF = CFrame.lookAt(qmAt + Vector3.new(0, 2.6, 0), qmAt + Vector3.new(0, 2.6, 0) + toYou), Half = Vector3.new(2.0, 2.8, 1.3) },
		}
		local function inBox(b, p: Vector3, pad: number): boolean
			local l = b.CF:PointToObjectSpace(p)
			return math.abs(l.X) < b.Half.X + pad and math.abs(l.Y) < b.Half.Y + pad and math.abs(l.Z) < b.Half.Z + pad
		end
		local function crosses(b, a: Vector3, c: Vector3, pad: number): boolean
			local la, lc = b.CF:PointToObjectSpace(a), b.CF:PointToObjectSpace(c)
			local d = lc - la
			local t0, t1 = 0, 1
			for _, k in ipairs({ "X", "Y", "Z" }) do
				local h = (b.Half :: any)[k] + pad
				local o, v = (la :: any)[k], (d :: any)[k]
				if math.abs(v) < 1e-6 then
					if math.abs(o) > h then return false end
				else
					local e1, e2 = (-h - o) / v, (h - o) / v
					if e1 > e2 then e1, e2 = e2, e1 end
					t0, t1 = math.max(t0, e1), math.min(t1, e2)
					if t0 > t1 then return false end
				end
			end
			return true
		end
		-- a lens that is clear of the map, of both bodies at both ends of its move, and sees its subject past the other
		local function pick(cands: { { Vector3 } }, look: Vector3, subject: string): ({ Vector3 }?)
			for _, c in ipairs(cands) do
				local ok = true
				for i = 1, 2 do
					local e = c[i]
					for name, b in pairs(bodies) do
						if inBox(b, e, 0.9) or (name ~= subject and crosses(b, e, look, 0.25)) then ok = false end
					end
					if ok and not lensClear(e, look) then ok = false end
				end
				if ok then return c end
			end
			return nil
		end
		local mid = (feet + qmAt) / 2
		local midLook = mid + Vector3.new(0, 3.3, 0)
		-- shot A: a low two-shot from the side, dollying in (either side, a few distances)
		local candA = {}
		for _, d in ipairs({ 9.5, 8, 11.5, 6.5 }) do
			for _, s in ipairs({ 1, -1 }) do
				local e0 = mid + qside * s * d + Vector3.new(0, 2.4, 0)
				table.insert(candA, { e0, e0 + (midLook - e0).Unit * 1.6, Vector3.new(s, 0, 0) })
			end
		end
		local shotA = pick(candA, midLook, "")
		local sideA = shotA and shotA[3].X or 1
		-- shot B: a clean single on him from beside you (same side of the line as A first), pushing in a little
		local toHim = -toYou
		local candB = {}
		for _, s in ipairs({ sideA, -sideA }) do
			for _, o in ipairs({ { 1.0, 2.8, 4.1 }, { 0.2, 3.4, 4.3 }, { -1.2, 3.0, 4.6 } }) do
				local e0 = feet + toHim * o[1] + qside * s * o[2] + Vector3.new(0, o[3], 0)
				table.insert(candB, { e0, e0 + (him - e0).Unit * 0.9 })
			end
		end
		local shotB = pick(candB, him, "Him")
		-- (nothing clean: high and behind you, always open)
		local safe = feet - toHim * 7 + Vector3.new(0, 7, 0)
		local eyeA0, eyeA1 = shotA and shotA[1] or safe, shotA and shotA[2] or safe
		local eyeB0, eyeB1 = shotB and shotB[1] or safe, shotB and shotB[2] or safe
		-- the wheel comes from the far side of the two-shot, so it never rolls at the lens
		local wheelFrom = feet - qside * sideA * 14 - toHim * 2.5
		local wheelTo = feet - qside * sideA * 2.9 - toHim * 1.4
		-- your eyes clearing
		local blur = Instance.new("BlurEffect")
		blur.Name = "DinoPrologueBlur"
		blur.Size = 18
		blur.Parent = game:GetService("Lighting")
		TweenService:Create(blur, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 0 }):Play()
		task.delay(2, function() blur:Destroy() end)
		TweenService:Create(fade, TweenInfo.new(1.1), { BackgroundTransparency = 1 }):Play()
		local LINES = {
			{ 0.9, "THE EGGS ARE GONE. NOBODY OUTRUNS THAT THING... YET." },
			{ 3.6, "HATCH DINOS. GET STRONGER. THEN WE TAKE IT BACK." },
		}
		local said = 0
		local startled = false
		local wheelDown = false
		local D, CUT = 6.4, 3.4
		local tF = os.clock()
		-- skippable like every scene: a fresh press after the first second
		local wakeSkip = false
		local skipConn = game:GetService("UserInputService").InputBegan:Connect(function(input)
			if os.clock() - tF < 1 then return end
			local k, t = input.KeyCode, input.UserInputType
			if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA or k == Enum.KeyCode.E
				or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				wakeSkip = true
			end
		end)
		while os.clock() - tF < D and not wakeSkip do
			RunService.RenderStepped:Wait()
			local el = os.clock() - tF
			if el < CUT then
				local u = smooth(el / CUT)
				cam.CFrame = CFrame.lookAt(eyeA0:Lerp(eyeA1, u), midLook:Lerp(midLook + Vector3.new(0, 0.3, 0), u))
				cam.FieldOfView = 44 - u * 5
			else
				local u = smooth((el - CUT) / (D - CUT))
				cam.CFrame = CFrame.lookAt(eyeB0:Lerp(eyeB1, u), him)
				cam.FieldOfView = 40 - u * 4
			end
			if not startled and el > 0.5 then
				startled = true
				PlayerAnim.Act(char, "Startle")
			end
			if said < #LINES and el >= LINES[said + 1][1] then
				said += 1
				radio.Say(LINES[said][2], 2.0, true)
				if said == #LINES and qm then task.delay(1.6, function() if qm.Model.Parent then PlayerAnim.Act(qm.Model, "Wave") end end) end
			end
			if wheel then
				-- rolls in, wobbles, tips over beside you
				local wu = math.clamp((el - 0.3) / 2.0, 0, 1)
				local p = Stage.Ground(wheelFrom:Lerp(wheelTo, smooth(wu)), 10)
				local tip = math.clamp((el - 2.3) / 0.6, 0, 1)
				if tip >= 1 and not wheelDown then
					wheelDown = true
					Audio.Play("Clunk", { At = p, Volume = 0.8, Pitch = 0.8 })
					DinosaurVFX.FootstepDust(p, 0.8)
				end
				local wob = (1 - tip) * math.sin(os.clock() * 14) * 0.12 * wu
				local dir = (wheelTo - wheelFrom) * Vector3.new(1, 0, 1)
				local cf = CFrame.lookAt(p + Vector3.new(0, 1.4 * (1 - tip) + 0.5, 0), p + Vector3.new(0, 1.4 * (1 - tip) + 0.5, 0) + dir.Unit:Cross(Vector3.yAxis)) * CFrame.Angles(0, 0, wob + tip * math.pi / 2) * CFrame.Angles(-wu * 9, 0, 0)
				wheel:PivotTo(cf)
				if wu > 0 and wu < 1 and math.random() < 0.15 then DinosaurVFX.FootstepDust(p, 0.4) end
			end
		end
		skipConn:Disconnect()
		-- he heads back to his bench in the plaza (walking off, then gone once he's well away)
		if qm then
			local camp = Workspace:FindFirstChild("BaseCamp")
			local plaza = camp and camp:FindFirstChild("PlazaFloor", true)
			local dest = plaza and plaza:IsA("BasePart") and plaza.Position or (qmAt - toYou * 60)
			local dir = Vector3.new(dest.X - qmAt.X, 0, dest.Z - qmAt.Z)
			dir = dir.Magnitude > 0.1 and dir.Unit or -toYou
			task.spawn(function()
				local t0 = os.clock()
				local p = qmAt
				while os.clock() - t0 < 5 and qm.Model.Parent do
					local dt = RunService.RenderStepped:Wait()
					p = Stage.Ground(p + dir * 9 * dt, 10)
					qm:Place(p, dir, 9)
					qm:Locomote(9)
					local fadeT = math.clamp((os.clock() - t0 - 3.8) / 1.0, 0, 1)
					if fadeT > 0 then
						for _, d in ipairs(qm.Model:GetDescendants()) do
							if d:IsA("BasePart") or d:IsA("Decal") then (d :: any).LocalTransparencyModifier = fadeT end
						end
					end
				end
				campSet:Destroy()
			end)
		else
			task.delay(4, function() campSet:Destroy() end)
		end
	else
		TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	end

	-- back to you
	radio.Hide()
	Drive.HoldCamera(false)
	Drive.SetCameraOverride(false)
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	if rootWas and rootWas.Parent then rootWas.Anchored = anchoredWas == true end
	Prologue.SetControls(true)
	-- (the character may have been replaced while we played: follow the one that's here now)
	hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid") or hum
	if hum then
		cam.CameraSubject = hum
		hum:SetAttribute("Frozen", nil)
	end
	task.delay(0.9, function() gui:Destroy() end)
	Cinema.End(cine)
	activeCine = nil
end

-- Roblox's own movement controls (the touch thumbstick, WASD): off while the cold open plays
function Prologue.SetControls(on: boolean)
	pcall(function()
		local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5) :: any)
		local controls = pm:GetControls()
		if on then controls:Enable() else controls:Disable() end
	end)
end

function Prologue.Play(_opts)
	if Prologue.Playing then return end
	Prologue.Playing = true
	local ok, err = pcall(run)
	if not ok then
		-- never strand a new player: put everything back
		warn("[Prologue] failed:", err)
		DinoAnims.TimeScale = 1
		pcall(function() (require(script.Parent.TikTok) :: any).Stop() end)
		local cam = Workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		Prologue.SetControls(true)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then root.Anchored = false end
		if hum then cam.CameraSubject = hum hum:SetAttribute("Frozen", nil) end
		if char then
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end
			end
		end
		local g = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("DinoPrologue")
		if g then g:Destroy() end
		local f = Stage.Root():FindFirstChild("PrologueCamp")
		if f then f:Destroy() end
		local blur = game:GetService("Lighting"):FindFirstChild("DinoPrologueBlur")
		if blur then blur:Destroy() end
		if engineLoop then engineLoop:Destroy() engineLoop = nil end
		Audio.AmbienceLevel(1)
		Zone.Apply("BaseCamp", true)
		Audio.SetMusic("Camp")
		-- (the run held the driving camera: hand it back too, or the rover can't be driven until the next roll-out)
		pcall(function()
			local D = require(script.Parent.Drive) :: any
			D.HoldCamera(false)
			D.SetCameraOverride(false)
		end)
	end
	if activeCine then Cinema.End(activeCine) activeCine = nil end
	Prologue.Playing = false
end

return Prologue
