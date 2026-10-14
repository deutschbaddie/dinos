--[[
	DinoQuiz — GUESS THE DINO (2026-10-14): a little game to play while you train on your power trainer's pad.
	TrainerView's button opens it: require(script.Parent.DinoQuiz).Open(). Training keeps ticking underneath.

	A dino turns on a glowing turntable (the real species model in a ViewportFrame + WorldModel, idling through
	DinosaurAnimations); pick its name from four big buttons. Right: green flash, confetti, "+N POWER", the streak
	climbs. Wrong: red shake, the right answer lights up, the streak resets. Long streaks get harder (lookalike names,
	then an all-black SHADOW). The server (ServerScriptService/Game/Quiz.luau) picks the dino, keeps the answer and
	pays the power; this only draws it.

	Input: tap / click an answer, keys 1-4, a gamepad's selection + A. X / B / Esc / the red tile close it.
	It closes itself when you step off your pad, a cutscene or warp starts, or you get in a ride.

	DinoQuiz.Open()     DinoQuiz.Close()     DinoQuiz.IsOpen()
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local Audio = require(script.Parent.Audio)
local Drive = require(script.Parent.Drive)
local Warp = require(script.Parent.Warp)
local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))
local DinosaurAnimations = require(Shared:WaitForChild("DinosaurAnimations"))
local DinosaurCinematics = require(Shared:WaitForChild("DinosaurCinematics"))

local C = Theme.C
local player = Players.LocalPlayer

local DinoQuiz = {}

local READY = 1.6 -- a pick made sooner waits (locked in) until then: the server wants 1.5 s per question
local OPTION_COLORS = { "Blue", "Orange", "Purple", "Teal" }
local TIER_TAG = {
	{ "WHO'S THAT DINO?", C.Blue },
	{ "TRICKY ONES!", C.Orange },
	{ "SHADOW ROUND!", C.Purple },
	{ "SHADOW MASTER!", C.Red },
}
local SHADOW = Color3.fromRGB(20, 22, 30)
local STRIP = { "ParticleEmitter", "Light", "Sound", "Highlight", "BillboardGui", "ProximityPrompt", "Script", "LocalScript", "Beam", "Trail", "Fire", "Smoke", "Sparkles" }

local S: any = nil -- the open quiz (nil = closed)
local opening = false

--------------------------------------------------------------------------------
-- when it may be open
--------------------------------------------------------------------------------
-- (TrainerView is required lazily: it requires this module for its button)
local function trainerView(): any
	local m = script.Parent:FindFirstChild("TrainerView")
	if not (m and m:IsA("ModuleScript")) then return nil end
	local ok, tv = pcall(require, m)
	return (ok and type(tv) == "table") and tv or nil
end

local function myPad(): BasePart?
	local tv = trainerView()
	if tv and type(tv.Pad) == "function" then
		local ok, pad = pcall(tv.Pad)
		if ok and typeof(pad) == "Instance" and pad:IsA("BasePart") then return pad end
	end
	local idx = player:GetAttribute("Plot")
	local camp = Workspace:FindFirstChild("BaseCamp")
	local plot = camp and idx and camp:FindFirstChild("Plot" .. tostring(idx), true)
	local pad = plot and plot:FindFirstChild("TrainerPad", true)
	return (pad and pad:IsA("BasePart")) and pad or nil
end

-- on your own pad: TrainerView's answer if it has one, else the trainer's rule (Config.Trainer.PadRadius / PadHeight)
local function onPad(): boolean
	local tv = trainerView()
	if tv and type(tv.OnPad) == "function" then
		local ok, on = pcall(tv.OnPad)
		if ok and type(on) == "boolean" then return on end
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hrp:IsA("BasePart")) or not hum or hum.Health <= 0 then return false end
	local pad = myPad()
	if not pad then return false end
	local cfg = (Config :: any).Trainer
	local radius = (cfg and tonumber(cfg.PadRadius)) or math.max(pad.Size.X, pad.Size.Z) / 2
	local height = (cfg and tonumber(cfg.PadHeight)) or 7
	local d = hrp.Position - pad.Position
	return Vector3.new(d.X, 0, d.Z).Magnitude <= radius + 1 and d.Y > -2 and d.Y < height + 1
end

-- a cutscene, a warp, a ride: not now
local function busy(): boolean
	if Cinema.Playing() or Warp.Playing then return true end
	local ok, cine = pcall(DinosaurCinematics.IsPlaying)
	if ok and cine then return true end
	return Drive.State.Mode ~= "None"
end

--------------------------------------------------------------------------------
-- small pieces
--------------------------------------------------------------------------------
-- recolour a Kit button / brick, keeping its two-tone toy-tile face
local function paint(outer: Instance, color: any)
	local sw = Kit.Swatch(color)
	local lip = outer:FindFirstChild("Lip") :: Frame?
	local body = outer:FindFirstChild("Body") :: Frame?
	if lip then lip.BackgroundColor3 = sw[3] end
	if body then
		body.BackgroundColor3 = sw[1]
		local g = body:FindFirstChildOfClass("UIGradient")
		if g then
			g.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Kit.Shade(sw[1], 1.16)), ColorSequenceKeypoint.new(0.48, Kit.Shade(sw[1], 1.1)),
				ColorSequenceKeypoint.new(0.52, sw[1]), ColorSequenceKeypoint.new(1, Kit.Shade(sw[1], 0.94)),
			})
		end
	end
end

local function setTag(bar: Frame, text: string, color: Color3)
	local label = bar:FindFirstChild("Label")
	if label then Kit.SetText(label, text) end
	local g = bar:FindFirstChildOfClass("UIGradient")
	if g then g.Color = ColorSequence.new(color, Kit.Shade(color, 0.7)) end
end

-- blocky confetti bursting out of a point
local function confetti(host: GuiObject, at: UDim2, n: number)
	local cols = { C.LimeHi, C.YellowHi, C.Orange, C.BlueHi, C.PurpleHi, C.Cream }
	for i = 1, n do
		local sz = math.random(9, 16)
		local f = Kit.New("Frame", { BackgroundColor3 = cols[(i % #cols) + 1], Size = UDim2.fromOffset(sz, sz), AnchorPoint = Vector2.new(0.5, 0.5), Position = at, ZIndex = 40, Rotation = math.random(0, 90) }, host)
		Kit.Corner(f, 3)
		local st = Kit.Stroke(f, C.Ink, 2)
		local ang = (i / n) * math.pi * 2 + math.random() * 0.5
		local dist = 90 + math.random() * 90
		local to = at + UDim2.fromOffset(math.cos(ang) * dist, math.sin(ang) * dist * 0.8 - 30)
		Kit.Tween(f, 0.6, { Position = to, Rotation = f.Rotation + math.random(-240, 240) }, Enum.EasingStyle.Quad)
		local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35)
		TweenService:Create(f, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(st, fade, { Transparency = 1 }):Play()
		task.delay(0.7, function() f:Destroy() end)
	end
end

--------------------------------------------------------------------------------
-- the stage: the dino on a turntable
--------------------------------------------------------------------------------
local function cloneDino(species: string): Model?
	local folder = Shared:FindFirstChild("Dinosaurs")
	local t = folder and folder:FindFirstChild(species)
	if not (t and t:IsA("Model")) then return nil end
	local m = t:Clone()
	local root = m.PrimaryPart
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			-- (only the root is anchored: the rest hangs off its Motor6Ds so the animator can pose it)
			d.Anchored = (root == nil) or d == root
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		else
			for _, cls in ipairs(STRIP) do
				if d:IsA(cls) then d:Destroy() break end
			end
		end
	end
	return m
end

local function cylinder(parent: Instance, dia: number, h: number, y: number, color: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.Size = Vector3.new(h, dia, dia)
	p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2)
	p.Color = color
	p.Material = mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- an all-black shadow; returns the reveal (colours fade back in over `t` seconds). Invisible parts go black too:
-- the animator shows the eyelids when it blinks
local function shadow(m: Model): (number) -> ()
	local parts, decals = {}, {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, { d, d.Color, d.Material })
			d.Color = SHADOW
			d.Material = Enum.Material.SmoothPlastic
		elseif d:IsA("Decal") then -- (Textures are Decals too)
			table.insert(decals, { d, d.Transparency })
			d.Transparency = 1
		end
	end
	local done = false
	return function(t: number)
		if done then return end
		done = true
		for _, e in ipairs(parts) do e[1].Material = e[3] end
		for _, e in ipairs(decals) do e[1].Transparency = e[2] end
		local t0 = os.clock()
		task.spawn(function()
			while m.Parent do
				local a = math.clamp((os.clock() - t0) / t, 0, 1)
				local k = 1 - (1 - a) ^ 2
				for _, e in ipairs(parts) do e[1].Color = SHADOW:Lerp(e[2], k) end
				if a >= 1 then break end
				RunService.RenderStepped:Wait()
			end
		end)
	end
end

-- put `species` on the turntable (replacing what's there) and frame it
local function stageDino(s, species: string, silhouette: boolean)
	if s.Stage then s.Stage:Destroy() end
	s.Stage, s.Anim, s.Reveal = nil, nil, nil
	local m = cloneDino(species)
	if not m then return end
	local stage = Instance.new("Model")
	stage.Name = "Stage"
	-- the dino stands centred on the origin, feet at y = 0 (measured on the parts you can see: the root and the
	-- eyelids are invisible)
	m:PivotTo(CFrame.new())
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local r = p.CFrame
			local h = p.Size / 2
			local ext = Vector3.new(
				math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
				math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
				math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z)
			lo = lo:Min(p.Position - ext)
			hi = hi:Max(p.Position + ext)
		end
	end
	if lo.X == math.huge then
		local cf0, size0 = m:GetBoundingBox()
		lo, hi = cf0.Position - size0 / 2, cf0.Position + size0 / 2
	end
	local size = hi - lo
	local mid = (lo + hi) / 2
	m:PivotTo(CFrame.new(-mid.X, -lo.Y, -mid.Z) * m:GetPivot())
	m.Parent = stage
	-- the turntable: a chunky jungle-green disc with a glowing yellow band and a lighter top
	local rh = math.sqrt((size.X / 2) ^ 2 + (size.Z / 2) ^ 2)
	local pr = math.max(math.max(size.X, size.Z) * 0.42, size.Y * 0.35)
	local pt = math.max(0.35, pr * 0.16)
	cylinder(stage, pr * 2, pt, -pt / 2 - 0.02, C.JungleLo, Enum.Material.SmoothPlastic)
	cylinder(stage, pr * 2 * 1.025, pt * 0.32, -pt * 0.55, C.Yellow, Enum.Material.Neon)
	cylinder(stage, pr * 2 * 0.9, 0.06 * pt + 0.04, -0.01, C.JungleHi, Enum.Material.SmoothPlastic)
	stage.Parent = s.World
	if silhouette then s.Reveal = shadow(m) end

	-- the camera: everything fits at any turn (the dino's longest reach, the disc), a little from above
	local vp = s.Vp :: ViewportFrame
	local abs = vp.AbsoluteSize
	local aspect = (abs.X > 10 and abs.Y > 10) and abs.X / abs.Y or 1
	local fov = 30
	local vHalf = math.rad(fov / 2)
	local hHalf = math.atan(math.tan(vHalf) * aspect)
	local R = math.max(rh, pr * 1.03)
	local H = size.Y + pt
	local pitch = math.rad(11)
	local dist = math.max(R / math.tan(hHalf), (H / 2 + R * math.sin(pitch)) / math.tan(vHalf)) * 1.06 + R * 0.3
	s.Target = Vector3.new(0, (size.Y - pt) / 2, 0)
	s.Offset = Vector3.new(0, math.sin(pitch), -math.cos(pitch)) * dist
	s.Cam.FieldOfView = fov

	-- idle life (the animator only steps dinos in Workspace by itself: this one is stepped below)
	if m.PrimaryPart then
		local ok, anim = pcall(DinosaurAnimations.get, m)
		if ok and anim then s.Anim = anim end
	end
	s.Stage = stage
	s.Angle = 2.2
	s.Boost = 9 -- (a quick whoosh of a spin that settles into the slow turn)
	s.Cam.CFrame = CFrame.lookAt(s.Target + CFrame.Angles(0, -s.Angle, 0):VectorToWorldSpace(s.Offset), s.Target)
end

--------------------------------------------------------------------------------
-- rounds
--------------------------------------------------------------------------------
local pick: (number) -> ()

local function setStreak(s, n: number, best: number)
	s.Streak = n
	Kit.SetText(s.StreakText, "STREAK " .. tostring(n))
	s.Best = math.max(s.Best or 0, best, n)
	Kit.SetText(s.BestText, tostring(s.Best))
end

local function showRound(s, q)
	s.Q = q
	s.Locked = false
	s.ReadyAt = os.clock() + READY
	local tag = TIER_TAG[math.clamp(tonumber(q.Tier) or 1, 1, #TIER_TAG)]
	setTag(s.Tag, tag[1], tag[2])
	Kit.Pop(s.Tag, 0.6)
	s.Name.Visible = false
	setStreak(s, tonumber(q.Streak) or 0, tonumber(q.Best) or 0)
	for i, b in ipairs(s.Buttons) do
		local id = q.Options and q.Options[i]
		local sp = id and Config.Species[id]
		Kit.SetText(b.Label, sp and sp.Name or "???")
		paint(b.Outer, OPTION_COLORS[i])
		b.Ring.Visible = false
		if b.Mark then b.Mark:Destroy() b.Mark = nil end
	end
	local list = {}
	for _, b in ipairs(s.Buttons) do table.insert(list, b.Outer) end
	Kit.Stagger(list, 0.05, 0.6)
	-- the dino swaps in behind a quick fade and a whoosh of a spin
	local vp = s.Vp :: ViewportFrame
	vp.ImageTransparency = 1
	stageDino(s, tostring(q.Species), q.Silhouette == true)
	Kit.Tween(vp, 0.25, { ImageTransparency = 0 })
	Audio.Play("Dodge", { Volume = 0.45, Pitch = 1.25 })
end

local function powerPop(s, gain: number)
	local text = "+" .. Config.FormatNumber(gain)
	local w = 78 + #text * 30
	local holder = Kit.New("Frame", { Name = "PowerPop", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, 74), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 44 }, s.StageHost)
	Kit.Icon(holder, "Power", { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 46, Rotation = -10 })
	Kit.Text(holder, text, { Size = UDim2.new(1, -70, 0, 50), Position = UDim2.fromOffset(68, 2), Align = Enum.TextXAlignment.Left, Color = C.LimeHi, Color2 = C.Lime, Stroke = 4.5, Shadow = 4, MaxSize = 54, ZIndex = 46 })
	Kit.Text(holder, "POWER", { Pixel = true, Size = UDim2.new(1, -70, 0, 14), Position = UDim2.fromOffset(72, 54), Align = Enum.TextXAlignment.Left, Color = C.Cream, Stroke = 2.5, Shadow = 2, MaxSize = 14, ZIndex = 46 })
	Kit.Pop(holder, 0.3)
	Kit.Tween(holder, 1.2, { Position = UDim2.fromScale(0.5, 0.3) }, Enum.EasingStyle.Quad)
	task.delay(1.0, function() if holder.Parent then Kit.PopOut(holder, true) end end)
end

local function flash(s, color: Color3)
	local f = s.Flash :: Frame
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0.25
	Kit.Tween(f, 0.55, { BackgroundTransparency = 1 })
end

local function feedback(s, chosen: number, res)
	local q = s.Q
	local correct = res.Correct == true
	local ans = table.find(q.Options or {}, res.Answer)
	-- the answer lights up, a wrong pick goes red, the rest step back (a tick / cross badge on the corner)
	for j, b in ipairs(s.Buttons) do
		b.Ring.Visible = false
		local face = b.Outer:FindFirstChild("Body")
		local content = face and face:FindFirstChild("Content")
		if j == ans then
			paint(b.Outer, "Lime")
			Kit.Punch(b.Outer, 0.12)
			if content then b.Mark = Kit.Glyph(content, "Check", { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -4, 0, 2), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 36 }) end
		elseif j == chosen and not correct then
			paint(b.Outer, "Red")
			Kit.Shake(b.Outer)
			if content then b.Mark = Kit.Glyph(content, "X", { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -4, 0, 2), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 36 }) end
		else
			paint(b.Outer, "Grey")
		end
	end
	-- the shadow lifts and the name comes up
	if s.Reveal then s.Reveal(0.45) end
	local sp = Config.Species[res.Answer]
	local name = sp and sp.Name or tostring(res.Answer)
	local article = name:match("^[AEIOU]") and "AN " or "A "
	Kit.SetText(s.Name, correct and (name .. "!") or ("IT'S " .. article .. name .. "!"))
	Kit.SetTextColor(s.Name, correct and C.LimeHi or C.YellowHi, correct and C.Lime or C.Orange)
	Kit.Pop(s.Name, 0.5)
	local streak = tonumber(res.Streak) or 0
	if correct then
		flash(s, C.Lime)
		confetti(s.StageHost, UDim2.fromScale(0.5, 0.5), 22)
		Audio.Play("Perfect", { Pitch = 1 + math.min(streak, 12) * 0.025, Exact = true })
		local gain = tonumber(res.Gain) or 0
		if gain > 0 then
			powerPop(s, gain)
			Audio.Play("ItemGet", { Volume = 0.7 })
		elseif res.Capped then
			setTag(s.Tag, "POWER RECHARGING...", C.Grey)
			Kit.Pop(s.Tag, 0.7)
		end
		local was = s.Streak or 0
		local oldBest = s.Best or 0
		setStreak(s, streak, tonumber(res.Best) or 0)
		Kit.Count(s.StreakText, was, streak, function(v) return "STREAK " .. tostring(math.floor(v + 0.5)) end, 0.3)
		Kit.Punch(s.StreakBrick, 0.2)
		if streak > 0 and streak % 5 == 0 then
			-- every 5 in a row: a fanfare and the brick flashes gold
			Audio.Play("LevelUp")
			paint(s.StreakBrick, "Yellow")
			Kit.Punch(s.StreakBrick, 0.35)
			setTag(s.Tag, `{streak} IN A ROW!`, C.Yellow)
			Kit.Pop(s.Tag, 0.5)
			task.delay(1.2, function() if s.StreakBrick.Parent then paint(s.StreakBrick, "Orange") end end)
		end
		if streak > oldBest and oldBest > 0 and not s.BestCheered then
			-- (once a session: beating your record is the moment, not every step after it)
			s.BestCheered = true
			Kit.Pop(s.BestNew, 0.4)
			Kit.Punch(s.BestText, 0.3)
			task.delay(2.4, function() if s.BestNew.Parent then Kit.PopOut(s.BestNew) end end)
		end
		task.wait(1.35)
	else
		flash(s, C.Red)
		Kit.Shake(s.Win)
		Audio.Play("Error", { Volume = 1.2 })
		if (s.Streak or 0) > 0 then
			paint(s.StreakBrick, "Red")
			Kit.Shake(s.StreakBrick)
			task.delay(0.9, function() if s.StreakBrick.Parent then paint(s.StreakBrick, "Orange") end end)
		end
		setStreak(s, 0, tonumber(res.Best) or 0)
		task.wait(2.3)
	end
	if S ~= s then return end
	if typeof(res.Next) == "table" then
		showRound(s, res.Next)
	else
		DinoQuiz.Close()
	end
end

pick = function(i: number)
	local s = S
	if not s or s.Locked or not s.Q then return end
	local q = s.Q
	local species = q.Options and q.Options[i]
	if typeof(species) ~= "string" then return end
	s.Locked = true
	local b = s.Buttons[i]
	b.Ring.Visible = true
	Kit.Punch(b.Outer, 0.1)
	task.spawn(function()
		-- (a fast pick is locked in and sent the moment the question may be answered)
		local wait = s.ReadyAt - os.clock()
		if wait > 0 then task.wait(wait) end
		if S ~= s then return end
		local res = Net.Ask("QuizAnswer", { Id = q.Id, Pick = species })
		if S ~= s then return end
		if res and not res.Ok and (res.Err == "TOO FAST" or res.Err == "slow down") then
			task.wait(0.4)
			if S ~= s then return end
			res = Net.Ask("QuizAnswer", { Id = q.Id, Pick = species })
			if S ~= s then return end
		end
		if res and res.Ok then
			local ok, err = pcall(feedback, s, i, res)
			if not ok then
				warn("[DinoQuiz] feedback failed:", err)
				if S == s and typeof(res.Next) == "table" then pcall(showRound, s, res.Next) end
			end
			return
		end
		if res and res.Err == "OFFPAD" then
			DinoQuiz.Close()
			Kit.Toast("STAY ON YOUR PAD TO PLAY!", "Orange", "Power")
			return
		end
		if res and res.Err == "OLD QUESTION" then
			-- (out of step with the server: pick up whatever question it has for us)
			local again = Net.Ask("QuizStart")
			if S ~= s then return end
			if again and again.Ok and typeof(again.Q) == "table" then showRound(s, again.Q) return end
			DinoQuiz.Close()
			return
		end
		-- anything else (the connection): let them try again
		b.Ring.Visible = false
		s.Locked = false
		Kit.Toast(string.upper(tostring(res and res.Err or "TRY AGAIN")), "Red")
	end)
end

--------------------------------------------------------------------------------
-- the window
--------------------------------------------------------------------------------
local function build(q)
	local s: any = { Conns = {}, Buttons = {}, Streak = 0, Best = 0 }
	local gui, canvas = Kit.Screen("DinoQuiz", 23, false)
	s.Gui = gui
	local win, inner, header = Kit.Window(canvas, {
		Name = "DinoQuiz", Title = "GUESS THE DINO!", Color = "Purple", Icon = "Dino", Size = UDim2.fromOffset(740, 440),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Fit = true, ZIndex = 20,
		OnClose = function() DinoQuiz.Close() end,
	})
	s.Win = win
	-- (the close tile stays out of the gamepad's loop: B closes)
	local closeTile = header:FindFirstChild("Close")
	local closeHit = closeTile and closeTile:FindFirstChild("Hit")
	if closeHit and closeHit:IsA("GuiObject") then closeHit.Selectable = false end

	-- left: the stage card (sky, sun rays, the turning dino)
	local _, cc = Kit.Card(inner, { Name = "StageCard", Size = UDim2.fromOffset(340, 342), Position = UDim2.fromOffset(0, 0), Color = "Forest", Border = C.YellowHi, ZIndex = 23 })
	s.StageHost = cc
	local sky = Kit.New("Frame", { Name = "Sky", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), ZIndex = 24 }, cc)
	Kit.Corner(sky, 9)
	Kit.Gradient(sky, Color3.fromHex("9EE0FF"), Color3.fromHex("3A86E8"))
	local rayClip = Kit.New("CanvasGroup", { Name = "Rays", BackgroundTransparency = 1, Size = sky.Size, Position = sky.Position, ZIndex = 25, GroupTransparency = 0.25 }, cc)
	Kit.Corner(rayClip, 9)
	local rays = Kit.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(560, 560), ZIndex = 25 }, rayClip)
	for i = 1, 12 do
		local ray = Kit.New("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.1, 0.5), Rotation = i * 30, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = (i % 2 == 0) and 0.55 or 0.75, ZIndex = 25 }, rays)
		Kit.New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, ray)
	end
	local vp = Kit.New("ViewportFrame", {
		Name = "Dino", BackgroundTransparency = 1, Size = sky.Size, Position = sky.Position, ZIndex = 26,
		Ambient = Color3.fromRGB(165, 165, 178), LightColor = Color3.fromRGB(255, 244, 226), LightDirection = Vector3.new(-0.4, -1, 0.6),
	}, cc) :: ViewportFrame
	Kit.Corner(vp, 9)
	s.Vp = vp
	s.World = Kit.New("WorldModel", {}, vp) -- (a WorldModel: so the rig's joints pose like they do in the world)
	s.Cam = Kit.New("Camera", {}, vp) :: Camera
	vp.CurrentCamera = s.Cam
	s.Flash = Kit.New("Frame", { Name = "Flash", BackgroundColor3 = C.Lime, BackgroundTransparency = 1, Size = sky.Size, Position = sky.Position, ZIndex = 27 }, cc)
	Kit.Corner(s.Flash, 9)
	s.Tag = Kit.TierBar(cc, "WHO'S THAT DINO?", { Size = UDim2.fromOffset(236, 34), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), Color = C.Blue, ZIndex = 32, TextPx = 13 })
	s.Name = Kit.Text(cc, "", { Name = "Answer", Size = UDim2.new(1, -24, 0, 42), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), Color = C.YellowHi, Color2 = C.Orange, Stroke = 4.5, Shadow = 4, MaxSize = 38, ZIndex = 34 })
	s.Name.Visible = false

	-- right, top: the streak and your best
	local streakBrick, sc = Kit.Brick(inner, { Name = "Streak", Size = UDim2.fromOffset(212, 48), Position = UDim2.fromOffset(360, 2), Color = "Orange", ZIndex = 23, Radius = 14, Lip = 5, Studs = 3 })
	s.StreakBrick = streakBrick
	Kit.Icon(sc, "Star", { Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0, -16, 0.5, -2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 28, Rotation = -10 })
	s.StreakText = Kit.Text(sc, "STREAK 0", { Size = UDim2.new(1, -58, 0, 30), Position = UDim2.new(0, 46, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 27, Stroke = 3.5, Shadow = 3, MaxSize = 30 })
	Kit.Icon(inner, "Trophy", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(584, 0), ZIndex = 25, Rotation = 8 })
	Kit.Text(inner, "BEST", { Pixel = true, Size = UDim2.fromOffset(80, 11), Position = UDim2.fromOffset(632, 6), Align = Enum.TextXAlignment.Left, Color = C.Muted, Stroke = 2.5, Shadow = 2, MaxSize = 11, ZIndex = 25 })
	s.BestText = Kit.Text(inner, "0", { Size = UDim2.fromOffset(70, 28), Position = UDim2.fromOffset(630, 20), Align = Enum.TextXAlignment.Left, Color = C.YellowHi, Stroke = 3.5, Shadow = 3, MaxSize = 28, ZIndex = 25 })
	s.BestNew = Kit.Text(inner, "NEW BEST!", { Pixel = true, Size = UDim2.fromOffset(110, 12), Position = UDim2.new(1, 4, 0, -14), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Color = C.LimeHi, Stroke = 2.5, Shadow = 2, MaxSize = 12, ZIndex = 26, Rotation = 4 })
	s.BestNew.Visible = false

	-- right: the four answers (keys 1-4 on a keyboard; the gamepad cycles them up / down)
	local desktop = Kit.Platform() == "Desktop"
	local hits = {}
	for i = 1, 4 do
		local outer, hit, label = Kit.Button(inner, {
			Name = "Option" .. i, Text = "???", Color = OPTION_COLORS[i], Size = UDim2.fromOffset(340, 62),
			Position = UDim2.fromOffset(360, 60 + (i - 1) * 71), ZIndex = 24, Radius = 14, Lip = 5, MaxText = 30, TextSize = 0.52,
			OnClick = function() pick(i) end,
		})
		-- "locked in": a thick yellow ring round your pick until the answer comes back
		local ring = Kit.New("Frame", { Name = "Ring", BackgroundTransparency = 1, Size = UDim2.new(1, 10, 1, 10), Position = UDim2.fromOffset(-5, -5), ZIndex = 34, Visible = false }, outer)
		Kit.Corner(ring, 18)
		Kit.Stroke(ring, C.YellowHi, 5)
		if desktop then
			local key = Kit.New("Frame", { Name = "Key", BackgroundColor3 = C.Ink, Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(-8, -9), ZIndex = 35 }, outer)
			Kit.Corner(key, 8)
			Kit.Stroke(key, C.Cream, 2).Transparency = 0.4
			Kit.Text(key, tostring(i), { Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 36, Stroke = 0, Shadow = 0, MaxSize = 18, Color = C.Cream })
		end
		s.Buttons[i] = { Outer = outer, Hit = hit, Label = label, Ring = ring }
		hits[i] = hit
	end
	for i, hit in ipairs(hits) do
		hit.NextSelectionUp = hits[i == 1 and 4 or i - 1]
		hit.NextSelectionDown = hits[i == 4 and 1 or i + 1]
		hit.NextSelectionLeft = hit
		hit.NextSelectionRight = hit
	end
	S = s

	-- keys: 1-4 answer, X / B close (only while the quiz is on screen; Esc goes to Roblox's menu too, like Panels)
	local KEYS = {
		[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3, [Enum.KeyCode.KeypadFour] = 4,
	}
	ContextActionService:BindActionAtPriority("DinoQuizKeys", function(_, state, input)
		if S ~= s or not gui.Enabled then return Enum.ContextActionResult.Pass end
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		local n = KEYS[input.KeyCode]
		if n then pick(n) else DinoQuiz.Close() end
		return Enum.ContextActionResult.Sink
	end, false, 2200, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
		Enum.KeyCode.KeypadOne, Enum.KeyCode.KeypadTwo, Enum.KeyCode.KeypadThree, Enum.KeyCode.KeypadFour,
		Enum.KeyCode.X, Enum.KeyCode.ButtonB)
	table.insert(s.Conns, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and S == s then DinoQuiz.Close() end
	end))
	-- a gamepad lands on the answers (now, or the moment one is picked up)
	if Kit.Gamepad() then GuiService.SelectedObject = hits[1] end
	table.insert(s.Conns, UserInputService.LastInputTypeChanged:Connect(function(t)
		if S == s and t.Name:find("Gamepad") and not (GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui)) then
			GuiService.SelectedObject = hits[1]
		end
	end))

	-- every frame: the sun rays and the turntable turn, the dino idles. (The "turntable" is the camera and the light
	-- orbiting together round a still dino: it looks the same and moves no parts - a rig is ~250 of them)
	local LIGHT = Vector3.new(-0.4, -1, 0.6)
	table.insert(s.Conns, RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 10
		local stage = s.Stage
		if stage and stage.Parent and s.Target then
			s.Boost = (s.Boost or 0) * math.exp(-dt * 3.2)
			s.Angle = (s.Angle or 0) + dt * (0.45 + s.Boost)
			local spin = CFrame.Angles(0, -s.Angle, 0)
			s.Cam.CFrame = CFrame.lookAt(s.Target + spin:VectorToWorldSpace(s.Offset), s.Target)
			vp.LightDirection = spin:VectorToWorldSpace(LIGHT)
			local anim = s.Anim
			if anim then
				local ok = pcall(anim.Step, anim, math.min(dt, 0.1))
				if not ok then s.Anim = nil end -- (the turntable carries on without it)
			end
		end
	end))

	-- it closes itself: off the pad (a moment's grace for a wobble), a cutscene / warp / ride, hidden by Cinema
	task.spawn(function()
		local offSince = nil
		while S == s do
			if not gui.Parent or not gui.Enabled or busy() then
				DinoQuiz.Close(true)
				return
			end
			if onPad() then
				offSince = nil
			else
				offSince = offSince or os.clock()
				if os.clock() - offSince > 0.5 then
					DinoQuiz.Close()
					Kit.Toast("STAY ON YOUR PAD TO PLAY!", "Orange", "Power")
					return
				end
			end
			task.wait(0.15)
		end
	end)

	Kit.Enter(win)
	-- (the viewport has its real size after a frame: frame the first dino then)
	task.defer(function() if S == s then showRound(s, q) end end)
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------
function DinoQuiz.IsOpen(): boolean
	return S ~= nil
end

function DinoQuiz.Open()
	if S then
		Kit.Punch(S.Win, 0.05)
		return
	end
	if opening or busy() then return end
	if not onPad() then
		Kit.Toast("STAND ON YOUR TRAINER PAD", "Orange", "Power")
		return
	end
	opening = true
	task.spawn(function()
		local res = Net.Ask("QuizStart")
		opening = false
		if S then return end
		if not (res and res.Ok and typeof(res.Q) == "table") then
			Kit.Toast(string.upper(tostring(res and res.Err or "TRY AGAIN")), "Red")
			return
		end
		if busy() or not onPad() then return end
		local ok, err = pcall(build, res.Q)
		if not ok then
			-- (never leave a half-built window or a key binding behind)
			warn("[DinoQuiz] couldn't open:", err)
			DinoQuiz.Close(true)
			local pg = player:FindFirstChildOfClass("PlayerGui")
			local g = pg and pg:FindFirstChild("DinoQuiz")
			if g then g:Destroy() end
		end
	end)
end

-- instant: no exit animation (a cutscene took the screen)
function DinoQuiz.Close(instant: boolean?)
	ContextActionService:UnbindAction("DinoQuizKeys")
	local s = S
	if not s then return end
	S = nil
	for _, c in ipairs(s.Conns) do c:Disconnect() end
	local gui = s.Gui :: ScreenGui
	local sel = GuiService.SelectedObject
	if sel and sel:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
	-- (the dino and its animator go with the gui)
	if instant or not gui.Enabled or not s.Win then
		gui:Destroy()
		return
	end
	Kit.Exit(s.Win, true)
	task.delay(0.3, function() gui:Destroy() end)
end

return DinoQuiz
