--[[
	EraView — the cinematic half of an expedition:
	  Arrive      establishing shots over the era (title card in Press Start 2P, a glimpse of its ruler on her throne)
	  Map         live encounter sites shared by the whole server + the ruler's den (event timer / boss keys / tiers)
	  Travel      the rover rolls up to the chosen site, then you step out
	  SiteIntro   the dino's signature cutscene (full the first time you meet a species, a short sting after)
	  Boss        event call-outs, the ruler's intro, the flee, the final stand, the knockout and the loot
	Every cutscene hides the HUD (Cinema) and can be skipped with a tap / Space / A.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local DinosaurAnimations = require(DinoShared:WaitForChild("DinosaurAnimations"))
local DinosaurCinematics = require(DinoShared:WaitForChild("DinosaurCinematics"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)
local Kit = require(script.Parent.UI.Kit)
local CineKit = require(script.Parent.UI.CineKit)
local Audio = require(script.Parent.Audio)
local Cinema = require(script.Parent.UI.Cinema)
local Zone = require(script.Parent.Zone)
local PlayerAnim = require(script.Parent.PlayerAnim)
local Floor = require(script.Parent.Floor)
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local C = Kit.Colors
local Runtime = DinoShared:WaitForChild("Runtime")
local SitesFolder = Runtime:WaitForChild("Sites")
local RunsFolder = Runtime:WaitForChild("Runs")
local Templates = DinoShared:WaitForChild("Dinosaurs")

local View = {}
local Exp -- ExpeditionView (creature models)
local hud -- HUD module

local state = {
	Zone = nil :: string?,
	JustFound = nil :: string?, -- a site whose reveal just played (its scope-out skips the dino shot)
	Phase = "None", -- None | Arriving | Map | Travel | Site
	SiteKey = nil :: string?,
	Arriving = false, -- the whole of View.Arrive (the roam heal keeps out of it)
}
-- the ruler asleep on her throne between fights (section 9)
local sleeper = { Model = nil :: Model?, Zone = nil :: string?, Species = nil :: string?, Tag = nil :: BillboardGui?, Tick = 0 }

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------
local function new(class: string, props, parent: Instance?)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do (i :: any)[k] = v end
	if parent then i.Parent = parent end
	return i
end

local function flags()
	return (Net.Profile and Net.Profile.Flags) or {}
end
local function seen(key: string): boolean
	local tips = flags().Tips
	return tips ~= nil and tips[key] == true
end
local function markSeen(key: string)
	local f = flags()
	f.Tips = f.Tips or {}
	f.Tips[key] = true
	task.spawn(function()
		-- saved server-side; requests of one kind are rate limited, so a second flag in the same instant retries
		for _ = 1, 4 do
			local res = Net.Ask("Tip", { Key = key })
			if not (res and res.Err == "slow down") then return end
			task.wait(0.3)
		end
	end)
end

local function siteFolder(key: string?): Configuration?
	if not key then return nil end
	for _, f in ipairs(SitesFolder:GetChildren()) do
		if f:GetAttribute("Key") == key then return f :: Configuration end
	end
	return nil
end

local function zoneModel(zone: string?): Instance?
	return zone and Workspace:FindFirstChild(zone) or nil
end

local function marker(zone: string?, name: string): BasePart?
	local zm = zoneModel(zone)
	local m = zm and zm:FindFirstChild(name, true)
	return (m and m:IsA("BasePart")) and m or nil
end

local function hrp(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function fmtTime(t: number): string
	t = math.max(0, math.floor(t))
	return string.format("%d:%02d", t // 60, t % 60)
end

local function eraBoss(zone: string?)
	local era = zone and Config.Era(zone)
	return era and era.Boss and Config.Bosses[era.Boss], era and era.Boss
end

--------------------------------------------------------------------------------
-- the cutscene layer: letterbox, fades, pixel title cards, skip
--------------------------------------------------------------------------------
-- a SPOTTED intro is on its way or playing: only ITS end may tell the server "intro done" (a scope-out finishing
-- first used to release the site while you were still frozen in the spotted cutscene)
local introOwed = false

-- the boss theme plays from the intro to the knockout (or the loss, or leaving): never left in the music stack
local bossMusic = false
local function bossMusicOff()
	if bossMusic then bossMusic = false Audio.Remove("Boss") end
end

local cine = {} :: any
local function buildCine()
	local gui = new("ScreenGui", { Name = "DinoEraCine", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	gui.ScreenInsets = Enum.ScreenInsets.None
	cine.Gui = gui
	cine.Bars = {}
	for i, a in ipairs({ 0, 1 }) do
		cine.Bars[i] = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, a), Position = UDim2.fromScale(0, a), Size = UDim2.fromScale(1, 0), ZIndex = 5 }, gui)
	end
	cine.Fade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, gui)
	cine.Flash = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 19 }, gui)
	-- title card (pixel font, arcade style)
	local card = new("Frame", { Name = "Card", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.06, 0, 0.84, 0), Size = UDim2.new(0.7, 0, 0.22, 0), ZIndex = 8, Visible = false }, gui)
	cine.Kicker = Kit.Text(card, "", { Name = "Kicker", Pixel = true, Size = UDim2.fromScale(0.7, 0.16), Position = UDim2.fromScale(0, 0), Align = Enum.TextXAlignment.Left, Color = C.YellowHi, Stroke = 2.5, Shadow = 3, ZIndex = 9, MaxSize = 22 })
	cine.Title = Kit.Text(card, "", { Name = "Title", Pixel = true, Size = UDim2.fromScale(1, 0.44), Position = UDim2.fromScale(0, 0.2), Align = Enum.TextXAlignment.Left, Color = Color3.fromRGB(255, 244, 214), Color2 = Color3.fromRGB(255, 176, 46), Stroke = 4, Shadow = 6, ZIndex = 9, MaxSize = 60 })
	cine.Accent = new("Frame", { BackgroundColor3 = C.Yellow, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.69), Size = UDim2.new(0, 0, 0.035, 0), ZIndex = 9 }, card)
	cine.Sub = Kit.Text(card, "", { Name = "Sub", Pixel = true, Size = UDim2.fromScale(0.9, 0.13), Position = UDim2.fromScale(0, 0.78), Align = Enum.TextXAlignment.Left, Color = Color3.fromRGB(230, 236, 245), Stroke = 2, Shadow = 3, ZIndex = 9, MaxSize = 18 })
	cine.Card = card
	-- centre stamp (big moments: FIGHT!, KNOCKED OUT!)
	cine.Stamp = Kit.Text(gui, "", { Name = "Stamp", Pixel = true, Size = UDim2.fromScale(0.8, 0.12), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.YellowHi, Color2 = C.Orange, Stroke = 5, Shadow = 7, ZIndex = 12, MaxSize = 80 })
	cine.Stamp.Visible = false
	cine.Skip = Kit.Text(gui, "TAP TO SKIP", { Name = "Skip", Pixel = true, Size = UDim2.new(0.3, 0, 0.026, 0), Position = UDim2.new(0.5, 0, 0.97, 0), AnchorPoint = Vector2.new(0.5, 1), Color = Color3.fromRGB(255, 226, 120), Stroke = 2, Shadow = 2, ZIndex = 14, MaxSize = 16 })
	local tap = new("TextButton", { Name = "Tap", BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 15 }, gui)
	tap.Activated:Connect(function() if cine.OnSkip then cine.OnSkip() end end)
	cine.Tap = tap
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function setAlpha(box: Instance, a: number, t: number?)
	for _, l in ipairs(box:GetDescendants()) do
		if l:IsA("TextLabel") then
			if t and t > 0 then TweenService:Create(l, TweenInfo.new(t), { TextTransparency = 1 - a }):Play() else l.TextTransparency = 1 - a end
		elseif l:IsA("UIStroke") then
			if t and t > 0 then TweenService:Create(l, TweenInfo.new(t), { Transparency = 1 - a }):Play() else l.Transparency = 1 - a end
		elseif l == cine.Accent then
			-- (the card's underline goes with its words: it used to stay on screen after the title faded - 2026-10-14)
			if t and t > 0 then TweenService:Create(l, TweenInfo.new(t), { BackgroundTransparency = 1 - a }):Play() else (l :: Frame).BackgroundTransparency = 1 - a end
		end
	end
end

local function letterbox(on: boolean)
	for _, b in ipairs(cine.Bars) do
		TweenService:Create(b, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, on and 0.11 or 0) }):Play()
	end
end

-- the bars punch in on a big hit, then settle back
local function slamBars()
	for _, b in ipairs(cine.Bars) do
		b.Size = UDim2.fromScale(1, 0.16)
		TweenService:Create(b, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0.11) }):Play()
	end
end

local function fade(to: number, t: number)
	TweenService:Create(cine.Fade, TweenInfo.new(t, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 - to }):Play()
	if t > 0 then task.wait(t) end
end

local function flash(strength: number?)
	cine.Flash.BackgroundTransparency = 1 - (strength or 0.6)
	TweenService:Create(cine.Flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

local function card(kicker: string, title: string, sub: string?, color: Color3?)
	Kit.SetText(cine.Kicker, kicker)
	Kit.SetText(cine.Title, title)
	Kit.SetText(cine.Sub, sub or "")
	Kit.SetTextColor(cine.Kicker, color or C.YellowHi)
	cine.Accent.BackgroundColor3 = color or C.Yellow
	cine.Accent.Visible = title ~= "" -- (no title, no underline)
	cine.Card.Visible = true
	setAlpha(cine.Card, 0)
	setAlpha(cine.Card, 1, 0.35)
	cine.Accent.Size = UDim2.new(0, 0, 0.035, 0)
	TweenService:Create(cine.Accent, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { Size = UDim2.new(0.55, 0, 0.035, 0) }):Play()
end
local function hideCard()
	setAlpha(cine.Card, 0, 0.3)
end

local function stamp(text: string, color: Color3?, hold: number?)
	Kit.SetText(cine.Stamp, text)
	Kit.SetTextColor(cine.Stamp, color or C.YellowHi, C.Orange)
	cine.Stamp.Visible = true
	setAlpha(cine.Stamp, 1)
	Kit.Pop(cine.Stamp, 1.8)
	task.delay(hold or 1.2, function() setAlpha(cine.Stamp, 0, 0.3) end)
end

--------------------------------------------------------------------------------
-- the big-moment kit: sun-ray titles, block + leaf bursts, camera punches
--------------------------------------------------------------------------------
-- (the kit itself lives in UI/CineKit so hatches, signatures and rewards share it)
local function rayTitle(title: string, sub: string?, color: Color3?, hold: number?)
	return CineKit.RayTitle(cine.Gui, title, sub, color, hold)
end
local LEAF = CineKit.Leaf
local burst = CineKit.Burst
View.Burst = burst
local punch = CineKit.Punch

-- run a scene: own the camera, hide the HUD, allow skipping. body(skipped) yields; returns when done
local busy = false
-- what the current shot is looking at (creatures in the way step aside; see ExpeditionView.SetCineFocus)
local cineSubject: Vector3? = nil
local cineKeep: { [Model]: boolean } = {}
local handBack: (toward: Vector3?) -> () -- (below, next to safeCam)
-- (2026-10-14: these two were called above their `local function` lines, so the calls hit a nil global - every
-- bush a shot faded stayed invisible for good, and View.Travel / View.Reset threw on their first line)
local restoreLens: () -> ()
local roamStop: () -> ()
-- the lens guard (2026-10-14): a shot that films its subject from a raw camera (the reveal beats, a dolly that
-- isn't a move()) names it here; every frame, small scenery between that subject and the lens fades for the rest
-- of the scene - the camera itself never moves for it, so nothing jumps
local lensGuard: (() -> Vector3?)? = nil
local guardLens: (subject: Vector3) -> () -- (below, next to safeCam)
-- a roar still ringing when its dino is cleaned up plays out instead of dying with the model (user: "the T. rex roar
-- gets cut off"). flat: as a plain 2D sound, for a cut where the lens is about to jump far away from it
local function keepSounds(root: Instance?, flat: boolean?)
	if not root then return end
	for _, s in ipairs(root:GetDescendants()) do
		if s:IsA("Sound") and s.IsPlaying and s.TimeLength > 0 then
			local left = (s.TimeLength - s.TimePosition) / math.max(s.PlaybackSpeed, 0.05)
			if left > 0.15 then
				local c = s:Clone()
				if flat then
					c.Parent = game:GetService("SoundService")
				else
					local host = Instance.new("Part")
					host.Name = "DinoSfxKeep"
					host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.Transparency = true, false, false, false, 1
					host.Size = Vector3.new(0.2, 0.2, 0.2)
					local at = s.Parent and s.Parent:IsA("BasePart") and (s.Parent :: BasePart).Position or Workspace.CurrentCamera.CFrame.Position
					host.Position = at
					host.Parent = Workspace
					c.Parent = host
					task.delay(left + 0.3, function() host:Destroy() end)
				end
				c.TimePosition = s.TimePosition
				c:Play()
				c.Ended:Connect(function() c:Destroy() end)
				task.delay(left + 0.3, function() if c.Parent then c:Destroy() end end)
				s:Stop()
			end
		end
	end
end
-- a model leaves the scene: its sounds play out, then it goes
local function drop(m: Instance?, flat: boolean?)
	if not m then return end
	pcall(keepSounds, m, flat)
	m:Destroy()
end
local function scene(body: (() -> boolean) -> (), opts): boolean
	opts = opts or {}
	if busy then return false end
	-- (a species' signature cinematic doesn't use this layer: never start on top of one)
	local tw = os.clock()
	while DinosaurCinematics.IsPlaying() and os.clock() - tw < 6 do task.wait(0.1) end
	if busy then return false end
	busy = true
	local token = Cinema.Begin("DinoEraCine", "DinoCinematicUI")
	-- film look while the scene runs: soft background focus, a touch more contrast and warmth
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "DinoSceneDOF"
	dof.FarIntensity = 0.45
	dof.NearIntensity = 0.2
	dof.FocusDistance = 28
	dof.InFocusRadius = 26
	dof.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DinoSceneGrade"
	grade.Parent = Lighting
	TweenService:Create(grade, TweenInfo.new(0.5), { Contrast = 0.16, Saturation = 0.22, TintColor = Color3.fromRGB(255, 244, 228) }):Play()
	local bloom = (Lighting:FindFirstChild("DinoBloom") or Lighting:FindFirstChildOfClass("BloomEffect")) :: BloomEffect?
	local bloomWas = bloom and { bloom.Intensity, bloom.Threshold, bloom.Size }
	if bloom then TweenService:Create(bloom, TweenInfo.new(0.5), { Intensity = 1.0, Threshold = 1.1, Size = 36 }):Play() end
	local cam = Workspace.CurrentCamera
	local savedFov = cam.FieldOfView
	Drive.HoldCamera(opts.Hold ~= false)
	Drive.SetCameraOverride(true)
	cam.CameraType = Enum.CameraType.Scriptable
	cine.Gui.Enabled = true
	cine.Card.Visible = false
	cine.Stamp.Visible = false
	cine.Skip.Visible = opts.Skippable ~= false
	cine.Tap.Visible = opts.Skippable ~= false
	letterbox(true)
	local skipped = false
	local cutStart = os.clock()
	cine.OnSkip = opts.Skippable ~= false and function() if os.clock() - cutStart > 1 then skipped = true end end or nil
	ContextActionService:BindAction("DinoEraSkip", function(_, st)
		if st == Enum.UserInputState.Begin and cine.OnSkip then cine.OnSkip() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
	cineSubject = nil
	if Exp and Exp.SetCineFocus then Exp.SetCineFocus(function() return cineSubject end, cineKeep) end
	-- the focus puller: depth of field follows whatever the shot is on, every frame (rack focus between subjects)
	local focusConn = RunService.RenderStepped:Connect(function(dt)
		local c = Workspace.CurrentCamera
		local subj = cineSubject or (c.CFrame.Position + c.CFrame.LookVector * 25)
		local d = (subj - c.CFrame.Position).Magnitude
		dof.FocusDistance += (d - dof.FocusDistance) * math.min(1, dt * 6)
		dof.InFocusRadius = math.max(5, d * 0.32)
		local g = lensGuard
		if g then
			local okG, at = pcall(g)
			if okG and at then pcall(guardLens, at) end
		end
	end)
	local ok, err = pcall(body, function() return skipped end)
	focusConn:Disconnect()
	lensGuard = nil
	if not ok then warn("[EraView] scene:", err) end
	-- (2026-10-14: every step of the wrap-up is protected on its own - one throw here used to skip Cinema.End and
	-- `busy = false`, and every later scene was refused: a black screen with nothing happening)
	local function step(name: string, fn: () -> ())
		local okS, errS = pcall(fn)
		if not okS then warn("[EraView] scene end (" .. name .. "):", errS) end
	end
	step("lens", restoreLens)
	step("time", CineKit.ResetTime)
	step("focus", function()
		if Exp and Exp.SetCineFocus then Exp.SetCineFocus(nil) end
		cineSubject = nil
		table.clear(cineKeep)
	end)
	step("ui", function()
		ContextActionService:UnbindAction("DinoEraSkip")
		cine.OnSkip = nil
		cine.Skip.Visible = false
		cine.Tap.Visible = false
		letterbox(false)
		hideCard()
	end)
	if not opts.KeepCamera then
		cam.FieldOfView = savedFov
		local okH, errH = pcall(handBack, opts.HandTo)
		if not okH then
			warn("[EraView] hand back:", errH)
			cam.CameraType = Enum.CameraType.Custom
		end
	end
	Drive.HoldCamera(false)
	Drive.SetCameraOverride(false)
	step("post", function()
		dof:Destroy()
		grade:Destroy()
		-- (back to the era's own bloom: a snapshot taken while the arrival's zone tween was still running used to stick
		-- for the whole run)
		local look = Zone.Look()
		if bloom and look and look.Bloom and bloom.Name == "DinoBloom" then
			TweenService:Create(bloom, TweenInfo.new(0.4), look.Bloom):Play()
		elseif bloom and bloomWas then
			TweenService:Create(bloom, TweenInfo.new(0.4), { Intensity = bloomWas[1], Threshold = bloomWas[2], Size = bloomWas[3] }):Play()
		end
	end)
	Cinema.End(token)
	busy = false
	-- (a scene that keeps the camera and ended on black - a reveal, a preview - stays black for whoever takes over
	-- next, instead of fading up on its own frozen last frame and then jumping: freeCam lifts it, or 3 s on it lifts)
	if opts.HoldBlack or (opts.KeepCamera and cine.Fade.BackgroundTransparency < 0.5) then
		-- (the caller hands the camera over itself and fades in after: stay black until then, instead of fading
		-- up on the half-way frame - the empty parked rover - first. Never left black: 3 s on, it lifts anyway)
		task.delay(3, function()
			if busy then return end
			if cine.Fade.BackgroundTransparency < 0.99 then fade(0, 0.3) end
			if not busy then cine.Gui.Enabled = false end
		end)
	else
		task.delay(0.45, function() if not busy then cine.Gui.Enabled = false end end)
		-- (no wait here: the caller's next beat starts on time, and a scene queued behind this one never sees `busy`
		-- still set for the length of a fade)
		TweenService:Create(cine.Fade, TweenInfo.new(0.25, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
	end
	return true
end
-- wait (a while) for whatever scene is on to finish: the beats that must never be dropped queue behind it
local function waitFree(max: number)
	local t0 = os.clock()
	while (busy or DinosaurCinematics.IsPlaying()) and os.clock() - t0 < max do task.wait(0.1) end
end

-- a camera move: from -> to (CFrames) over dur, eased; returns early if skipped
-- every camera checks where it is: never under the ground, never behind something that hides the subject
local camRay = RaycastParams.new()
camRay.FilterType = Enum.RaycastFilterType.Exclude
camRay.RespectCanCollide = false

-- the lens never jumps in front of a bush (2026-10-13, "the triceratops shot gets clipped zooming in from a
-- bush"): small scenery between the camera and its subject - a bush, fern, rock, palm, a lens that starts inside
-- one - fades out for the rest of the scene instead of shoving the camera forward. Whole decor models, never half
-- a tree; the scene puts them back when it ends (restoreLens)
local isScenery: (string) -> boolean
local lensHidden = {} :: { [BasePart]: boolean }
local softCache = setmetatable({}, { __mode = "k" }) :: { [Instance]: boolean }
local lensSoftInner
local function lensSoft(part: BasePart): (boolean, Instance)
	-- (never the terrain, never something loose in the world: and never an error - this runs inside every camera
	-- move AND the scene's hand-back, where a throw left the screen black with nothing happening. 2026-10-14)
	if part:IsA("Terrain") or part.Parent == Workspace then return false, part end
	local ok, soft, key = pcall(lensSoftInner, part)
	if ok then return soft, key end
	return false, part
end
lensSoftInner = function(part: BasePart): (boolean, Instance)
	local deco = part:FindFirstAncestorWhichIsA("Model")
	if deco == Workspace then deco = nil end
	local key = deco or part
	local soft = softCache[key]
	if soft == nil then
		local name = deco and deco.Name or part.Name
		local size = deco and deco:GetExtentsSize().Magnitude or part.Size.Magnitude
		soft = (isScenery ~= nil and isScenery(name) and size < 80) or false
		softCache[key] = soft
	end
	-- (a bush that's one part of a big scenery group: the part on its own, if it's small foliage or not solid)
	if not soft and key ~= part then
		local ps = softCache[part]
		if ps == nil then
			ps = part.Size.Magnitude < 30 and ((isScenery ~= nil and isScenery(part.Name)) or not part.CanCollide)
			softCache[part] = ps
		end
		if ps then return true, part end
	end
	return soft, key
end
local function fadeForLens(key: Instance)
	for _, d in ipairs(key:IsA("BasePart") and { key } or key:GetDescendants()) do
		if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then
			d.LocalTransparencyModifier = 1
			lensHidden[d] = true
		end
	end
end
restoreLens = function()
	for d in pairs(lensHidden) do if d.Parent then d.LocalTransparencyModifier = 0 end end
	table.clear(lensHidden)
end
local guardRay = RaycastParams.new()
guardRay.FilterType = Enum.RaycastFilterType.Exclude
guardRay.RespectCanCollide = false
guardLens = function(subject: Vector3)
	local cam = Workspace.CurrentCamera
	local d = cam.CFrame.Position - subject
	if d.Magnitude < 2 then return end
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(list, plr.Character) end end
	for _, n in ipairs({ "ActiveVehicles", "DinoExpeditionLocal", "DinoCutsceneActors", "DinoRevealSet", "DinoWaterSet" }) do
		local f = Workspace:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	guardRay.FilterDescendantsInstances = list
	for _ = 1, 4 do
		local hit = Workspace:Raycast(subject, d, guardRay)
		if not (hit and hit.Instance:IsA("BasePart")) then return end
		local part = hit.Instance :: BasePart
		local soft, key = false, part :: Instance
		if part.Transparency < 0.9 then soft, key = lensSoft(part) end
		if part.Transparency < 0.9 and not soft then return end -- (something solid: the shot owns that)
		if soft then fadeForLens(key) end
		table.insert(list, key)
		guardRay.FilterDescendantsInstances = list
	end
end

local function safeCam(cf: CFrame, subject: Vector3?): CFrame
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(list, plr.Character) end end
	local av = Workspace:FindFirstChild("ActiveVehicles")
	if av then table.insert(list, av) end
	local local_ = Workspace:FindFirstChild("DinoExpeditionLocal")
	if local_ then table.insert(list, local_) end
	camRay.FilterDescendantsInstances = list
	local pos = cf.Position
	local look = subject or (pos + cf.LookVector * 30)
	-- pull in front of anything between the subject and the lens (small scenery fades instead, see lensSoft)
	local d = pos - look
	if d.Magnitude > 2 then
		local hit = nil
		for _ = 1, 6 do
			hit = Workspace:Raycast(look, d, camRay)
			if not hit then break end
			local part = hit.Instance
			-- (an invisible wall or marker isn't in the way - but whatever stands behind it still might be)
			local clear = part.Transparency >= 0.9
			local soft, key = false, part :: Instance
			if not clear and part:IsA("BasePart") then soft, key = lensSoft(part) end
			if not (clear or soft) then break end
			if soft then fadeForLens(key) end
			table.insert(list, key)
			camRay.FilterDescendantsInstances = list
			hit = nil
		end
		if hit then
			pos = hit.Position - d.Unit * 1.4
			-- pulled in so close the lens is in the subject's head (a wall right behind you): rise up and over
			-- the shoulder instead, as far back as the ceiling of space allows
			if (pos - look).Magnitude < 5 and Vector3.new(d.X, 0, d.Z).Magnitude > 0.5 then
				local up = Vector3.new(d.X, 0, d.Z).Unit * math.min(d.Magnitude, 8) + Vector3.new(0, 7, 0)
				local hit2 = Workspace:Raycast(look, up, camRay)
				local alt = hit2 and (hit2.Position - up.Unit * 1.4) or (look + up)
				if (alt - look).Magnitude > (pos - look).Magnitude + 1 then pos = alt end
			end
		end
	end
	-- stay above the ground under the camera. the probe starts at the subject's height, not high above:
	-- from up high it landed on roofs, arches and overhangs and parked the lens on top of them (tester videos)
	local top = math.max(pos.Y, look.Y) + 2
	local down = nil
	for _ = 1, 4 do
		down = Workspace:Raycast(Vector3.new(pos.X, top, pos.Z), Vector3.new(0, -(top - pos.Y) - 30, 0), camRay)
		-- (a bush or fern under the lens isn't ground: it fades rather than lifting the camera over it)
		local soft, key = false, nil :: Instance?
		if down and down.Instance:IsA("BasePart") and not down.Instance:IsA("Terrain") then soft, key = lensSoft(down.Instance :: BasePart) end
		if not (soft and key) then break end
		if down.Position.Y > pos.Y - 0.5 then fadeForLens(key) end
		table.insert(list, key)
		camRay.FilterDescendantsInstances = list
		down = nil
	end
	if down and pos.Y < down.Position.Y + 1.2 then pos = Vector3.new(pos.X, down.Position.Y + 1.2, pos.Z) end
	-- never inside a rover (the rays ignore vehicles so they don't block the shot, so check its box by hand)
	local av2 = Workspace:FindFirstChild("ActiveVehicles")
	for _, v in ipairs(av2 and av2:GetChildren() or {}) do
		if v:IsA("Model") then
			local bcf, bsz = v:GetBoundingBox()
			local half = bsz / 2 + Vector3.new(1.5, 1.5, 1.5)
			local lp = bcf:PointToObjectSpace(pos)
			if math.abs(lp.X) < half.X and math.abs(lp.Y) < half.Y and math.abs(lp.Z) < half.Z then
				-- out through the nearest side (never down through the floor)
				local ox, oy, oz = half.X - math.abs(lp.X), half.Y - lp.Y, half.Z - math.abs(lp.Z)
				if ox <= oy and ox <= oz then lp = Vector3.new(math.sign(lp.X ~= 0 and lp.X or 1) * half.X, lp.Y, lp.Z)
				elseif oz <= oy then lp = Vector3.new(lp.X, lp.Y, math.sign(lp.Z ~= 0 and lp.Z or 1) * half.Z)
				else lp = Vector3.new(lp.X, half.Y, lp.Z) end
				pos = bcf:PointToWorldSpace(lp)
			end
		end
	end
	-- never inside a person (the rays skip characters so they don't block shots): out to arm's length, sideways
	-- (2026-10-14, "camera clipping into characters")
	for _, plr in ipairs(Players:GetPlayers()) do
		local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			local off = pos - r.Position
			local flat = Vector3.new(off.X, 0, off.Z)
			if math.abs(off.Y) < 3.4 and flat.Magnitude < 2.2 then
				local out = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(-(look - r.Position).Z, 0, (look - r.Position).X).Unit
				if out ~= out then out = Vector3.xAxis end
				pos = Vector3.new(r.Position.X, pos.Y, r.Position.Z) + out * 2.2
			end
		end
	end
	if pos == cf.Position then return cf end
	return CFrame.lookAt(pos, look)
end
View.SafeCam = safeCam

-- is any rover (yours or a teammate's) between the lens and what it's looking at? (rovers are mostly
-- non-collide, so the default camera looks straight through them - the inside-the-jeep frames)
local function roverInWay(from: Vector3, to: Vector3): boolean
	local av = Workspace:FindFirstChild("ActiveVehicles")
	for _, v in ipairs(av and av:GetChildren() or {}) do
		if v:IsA("Model") then
			local bcf, bsz = v:GetBoundingBox()
			local half = bsz / 2 + Vector3.new(0.8, 0.8, 0.8)
			for k = 0, 8 do
				local lp = bcf:PointToObjectSpace(from:Lerp(to, k / 8))
				if math.abs(lp.X) < half.X and math.abs(lp.Y) < half.Y and math.abs(lp.Z) < half.Z then return true end
			end
		end
	end
	return false
end

-- leaving a cut scene on foot: put the lens behind you (looking where you face, or at `toward`) before the
-- normal camera takes over, swinging round so no rover or wall sits between it and you
handBack = function(toward: Vector3?)
	local cam = Workspace.CurrentCamera
	local root = hrp()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and not hum.SeatPart then
		local f = root.CFrame.LookVector
		if toward then f = toward - root.Position end
		f = Vector3.new(f.X, 0, f.Z)
		f = f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1)
		local focus = root.Position + Vector3.new(0, 1.5, 0)
		local pick = nil
		for _, deg in ipairs({ 0, 40, -40, 80, -80, 130, -130, 180 }) do
			local d = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(f)
			local at = focus - d * 11 + Vector3.new(0, 3.5, 0)
			if not roverInWay(at, focus) then pick = CFrame.lookAt(at, focus + d * 8) break end
		end
		if pick then cam.CFrame = safeCam(pick, focus) end
	end
	cam.CameraType = Enum.CameraType.Custom
	-- (the follow camera does its own occlusion from here: whatever the last placement faded comes back)
	restoreLens()
end

-- pick the first camera spot that sees every subject cleanly (no trunk, rock or leaf wall in the way, not
-- buried in a bank). candidates are tried in order; if none is perfect, the one with the fewest blockers wins.
-- ignore: models allowed in the way (the subjects themselves)
local function clearSpot(candidates: { Vector3 }, subjects: { Vector3 }, ignore: { Instance }?): Vector3
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(list, plr.Character) end end
	local av = Workspace:FindFirstChild("ActiveVehicles")
	if av then table.insert(list, av) end
	local local_ = Workspace:FindFirstChild("DinoExpeditionLocal")
	if local_ then table.insert(list, local_) end
	for _, m in ipairs(ignore or {}) do table.insert(list, m) end
	camRay.FilterDescendantsInstances = list
	local olap = OverlapParams.new()
	olap.FilterType = Enum.RaycastFilterType.Exclude
	olap.FilterDescendantsInstances = list
	local best, bestN = candidates[1], math.huge
	for _, c in ipairs(candidates) do
		local n = 0
		-- a lens inside a rock or pillar sees nothing (rays that start inside a part never hit it)
		for _, part in ipairs(Workspace:GetPartBoundsInRadius(c, 1, olap)) do
			if part.Transparency < 0.6 and part.Size.Magnitude > 3 then n += 3 break end
		end
		-- not underground / inside a bank
		-- (a surface far overhead is an arch or roof, not ground: only one just above means buried)
		local down = Workspace:Raycast(c + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), camRay)
		if down and c.Y < down.Position.Y + 1 and down.Position.Y - c.Y < 8 then n += 2 end
		for _, sub in ipairs(subjects) do
			local hit = Workspace:Raycast(c, sub - c, camRay)
			if hit and hit.Instance.Transparency < 0.9 and (hit.Position - sub).Magnitude > 1.5 then n += 1 end
		end
		if n == 0 then return c end
		if n < bestN then best, bestN = c, n end
	end
	return best
end

-- shots that play often rotate through variants, so the tenth arrival doesn't look like the first
local rotation = {} :: { [string]: number }
local function nextVariant(kind: string, n: number): number
	rotation[kind] = ((rotation[kind] or math.random(0, n - 1)) % n) + 1
	return rotation[kind]
end

-- the player's own rover (to frame it in shots)
local function myRover(): BasePart?
	local vf = Workspace:FindFirstChild("ActiveVehicles")
	for _, v in ipairs(vf and vf:GetChildren() or {}) do
		if v:IsA("Model") and v:GetAttribute("Owner") == player.UserId and v.PrimaryPart then return v.PrimaryPart end
	end
	return nil
end

local lastMoveEnd = 0
local function move(from: CFrame, to: CFrame, dur: number, skipped: () -> boolean, fovA: number?, fovB: number?, subject: Vector3?)
	local cam = Workspace.CurrentCamera
	local t0 = os.clock()
	-- a shot that follows straight on from another whips in (a fast pan settling into place, a blink of blur) - only
	-- on a real cut: a move that carries on from where the last one stopped never jerks sideways (2026-10-14, jitter)
	local whip = os.clock() - lastMoveEnd < 0.12 and (from.Position - cam.CFrame.Position).Magnitude > 4
	local whipDir = math.random() < 0.5 and -1 or 1
	if whip then CineKit.Punch(3) end
	while true do
		local u = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = u < 0.5 and 2 * u * u or 1 - (-2 * u + 2) ^ 2 / 2
		local n = os.clock() - t0
		-- handheld: a living operator, not a tripod (a touch of roll too)
		local shake = CFrame.Angles(math.noise(n * 0.9, 1.3) * 0.009, math.noise(n * 0.8, 7.1) * 0.012, math.noise(n * 0.5, 3.3) * 0.006)
		cam.CFrame = safeCam(from:Lerp(to, e), subject) * shake
		if whip and n < 0.22 then
			local w = 1 - n / 0.22
			cam.CFrame *= CFrame.Angles(0, whipDir * 0.32 * w * w, whipDir * 0.05 * w)
		end
		cineSubject = subject or (cam.CFrame.Position + cam.CFrame.LookVector * 25)
		cam.FieldOfView = (fovA or 50) + ((fovB or fovA or 50) - (fovA or 50)) * e
		if u >= 1 or skipped() then lastMoveEnd = os.clock() return end
		RunService.RenderStepped:Wait()
	end
end

-- wait that ends early on skip
local function hold(t: number, skipped: () -> boolean)
	local t0 = os.clock()
	while os.clock() - t0 < t and not skipped() do RunService.RenderStepped:Wait() end
end

--------------------------------------------------------------------------------
-- a local "stand-in" dino for shots where the server has none (the ruler glimpse, the gallery)
--------------------------------------------------------------------------------
local function standIn(species: string, scale: number, cf: CFrame): (Model?, any)
	local t = Templates:FindFirstChild(species)
	if not t then return nil, nil end
	local m = t:Clone() :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = d == m.PrimaryPart d.Massless = d ~= m.PrimaryPart d.CanCollide = false d.CanQuery = false d.CanTouch = false end
	end
	if scale ~= 1 then m:ScaleTo(scale) end
	m:SetAttribute("AnimScale", scale)
	local bb, size = m:GetBoundingBox()
	local root = m.PrimaryPart :: BasePart
	local lift = root.Position.Y - (bb.Position.Y - size.Y / 2)
	root.CFrame = cf * CFrame.new(0, lift, 0)
	-- its own folder, never loose in Workspace: anything that searches "around" a dino (its herd, props) must
	-- never find the old showcase mock-ups on the baseplate
	local f = Workspace:FindFirstChild("DinoCutsceneActors")
	if not f then
		f = Instance.new("Folder")
		f.Name = "DinoCutsceneActors"
		f.Parent = Workspace
	end
	m.Parent = f
	-- one of each in the shot: any other dino of the same species nearby (a site's real one, the ambient herd)
	-- hides for as long as this stand-in exists
	local here = cf.Position
	local hidden = {}
	local function hideLike(model: Model)
		if model == m or model:GetAttribute("CineHidden") then return end
		local ok, pos = pcall(function() return model:GetPivot().Position end)
		if not ok or (pos - here).Magnitude > 260 then return end
		model:SetAttribute("CineHidden", true)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then (d :: any).LocalTransparencyModifier = 1 end
		end
		table.insert(hidden, model)
	end
	if Exp then
		for cfg, c in pairs(Exp.Creatures()) do
			if c.Model and cfg:GetAttribute("Species") == species then hideLike(c.Model) end
		end
	end
	for _, a in ipairs(game:GetService("CollectionService"):GetTagged("AmbientDino")) do
		if a:IsA("Model") and a:GetAttribute("Species") == species then hideLike(a) end
	end
	-- the boss asleep on its throne too (any distance: a ruler glimpse or boss scene stands its double right there)
	local sm = sleeper.Model
	if sm and sm ~= m and sleeper.Species == species and not sm:GetAttribute("CineHidden") then
		sm:SetAttribute("CineHidden", true)
		for _, d in ipairs(sm:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then (d :: any).LocalTransparencyModifier = 1
			elseif d:IsA("BillboardGui") then d.Enabled = false end
		end
		table.insert(hidden, sm)
	end
	if #hidden > 0 then
		m.AncestryChanged:Connect(function(_, parent)
			if parent then return end
			for _, h in ipairs(hidden) do
				h:SetAttribute("CineHidden", nil)
				for _, d in ipairs(h:GetDescendants()) do
					if d:IsA("BasePart") or d:IsA("Decal") then (d :: any).LocalTransparencyModifier = 0
					elseif d:IsA("BillboardGui") then d.Enabled = true end
				end
			end
		end)
	end
	local anim = DinosaurAnimations.get(m)
	return m, anim
end
View.StandIn = standIn

-- a dino's big moment never ploughs through a bush: small scenery in its path (and close around it) disappears
-- for the length of its cutscene, then comes back. whole decor models go, never half a tree.
local SCENERY = { "Bush", "Fern", "Flower", "Grass", "Rock", "Tree", "Palm", "Cycad", "Plant", "Shrub", "Log", "Stump", "Crate", "Barrel", "Reed", "Hoodoo", "Boulder", "Pebble", "Lily", "Mushroom",
	"Araucaria", "Sequoia", "Mangrove", "Snag", "Jungle", "Conifer", "Pine", "Cactus", "Kelp", "Tuft" }
isScenery = function(name: string): boolean
	for _, w in ipairs(SCENERY) do if string.find(name, w, 1, true) then return true end end
	return false
end
local function clearPath(m: Model, extra: number?): { BasePart }
	local hidden = {}
	if not m.Parent then return hidden end
	local _, size = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local fwd = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
	local width = math.max(size.X, size.Z)
	local reach = width * 3 + 30 + (extra or 0) -- charges and walk-ins go a long way
	local mid = pivot.Position + fwd * (reach / 2 - width * 0.6) + Vector3.new(0, size.Y / 2, 0)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = { m :: Instance }
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(skip, plr.Character) end end
	for _, n in ipairs({ "ActiveVehicles", "DinoExpeditionLocal", "DinoAmbience" }) do
		local f = Workspace:FindFirstChild(n)
		if f then table.insert(skip, f) end
	end
	params.FilterDescendantsInstances = skip
	local done = {}
	for _, p in ipairs(Workspace:GetPartBoundsInBox(CFrame.lookAt(mid, mid + fwd), Vector3.new(width * 2 + 10, size.Y + 10, reach), params)) do
		local deco = p:FindFirstAncestorWhichIsA("Model")
		local key = deco or p
		if done[key] then continue end
		done[key] = true
		local name = deco and deco.Name or p.Name
		if not isScenery(name) then continue end
		if deco and deco:GetExtentsSize().Magnitude > 150 then continue end -- big trees go too; never whole groves or cliffs
		for _, d in ipairs(deco and deco:GetDescendants() or { p }) do
			if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then
				d.LocalTransparencyModifier = 1
				table.insert(hidden, d)
			end
		end
	end
	return hidden
end
local function restorePath(hidden: { BasePart })
	for _, d in ipairs(hidden) do if d.Parent then d.LocalTransparencyModifier = 0 end end
end

-- a species' signature intro as a proper cutscene: HUD hidden, you held still, combat input off
local function playSignature(m: Model)
	local token = Cinema.Begin("DinoCinematicUI", "DinoEraCine")
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local ws = hum and hum.WalkSpeed
	if hum then hum.WalkSpeed = 0 end
	-- nothing else stands in its shots: other dinos step out of the line between the lens and this one
	-- (protected: a throw before the End below left the HUD hidden and you rooted to the spot. 2026-10-14)
	if Exp and Exp.SetCineFocus then pcall(Exp.SetCineFocus, function() return m.Parent and m:GetPivot().Position or nil end, { [m] = true }) end
	local okC, cleared = pcall(clearPath, m)
	if not okC then cleared = {} end
	local played = false
	-- (the rover's chase cam stands down for it - a signature that plays while you're seated would fight it - and
	-- the HUD is Cinema's job: the signature's own hide/show pass used to turn Roblox's backpack and chat back on
	-- half-way through the boss intro)
	Drive.SetCameraOverride(true)
	local ok, err = pcall(function()
		local handle = DinosaurCinematics.PlayIntro(m, { Skippable = true, HideGui = false })
		if handle then
			played = true
			handle.Finished:Wait()
		end
	end)
	if not ok then warn("[EraView] signature:", err) end
	Drive.SetCameraOverride(false)
	pcall(restorePath, cleared)
	if Exp and Exp.SetCineFocus then pcall(Exp.SetCineFocus, nil) end
	if hum and ws and hum.WalkSpeed == 0 then hum.WalkSpeed = ws end
	Cinema.End(token)
	return played
end
View.PlaySignature = playSignature

--------------------------------------------------------------------------------
-- 1. arrival: establishing shots
--------------------------------------------------------------------------------
local function shotCF(m: BasePart): (CFrame, Vector3)
	local look = Vector3.new(m:GetAttribute("LookX") or 0, m:GetAttribute("LookY") or 0, m:GetAttribute("LookZ") or 0)
	return CFrame.lookAt(m.Position, look), look
end

-- the walkable floor under p (Floor.luau): never the top of a bush, rock, nest or tree. Every cutscene dino stands
-- and walks on this, so nothing climbs over the scenery
local function ground(p: Vector3): Vector3
	return Floor.At(p, 120)
end

-- the legs keep up with the body: a stand-in moving at `speed` gets its gait sped up or slowed to match (no skating)
local function pace(anim, speed: number, dt: number)
	if not anim then return end
	local prof = anim.Profile
	local gait = prof and prof.Gait
	if not gait then return end
	local w = anim.LocoWeights or {}
	local running = (w.Run or 0) > (w.Walk or 0)
	local g = running and gait.Run or gait.Walk
	local scale = anim.AnimScale or 1
	local own = (g.Speed or (running and 16 or 6)) * scale
	if own <= 0 or (w.Run or 0) + (w.Walk or 0) < 0.3 then return end
	local k = math.clamp(speed / own, 0.4, 2.8)
	anim.GaitPhase += dt * (g.Freq or 1) * (k - 1)
end

-- a clear line for a walk: tries `dir` first, then turned a little either way, then shorter. Returns the start
-- point (the walk ends at `to`) and the direction it walks in.
local function clearApproach(to: Vector3, dir: Vector3, dist: number, height: number, width: number): (Vector3, Vector3)
	local d0 = Vector3.new(dir.X, 0, dir.Z)
	d0 = d0.Magnitude > 0.01 and d0.Unit or Vector3.new(0, 0, -1)
	for _, k in ipairs({ 1, 0.75, 0.5 }) do
		for _, ang in ipairs({ 0, 22, -22, 45, -45, 70, -70 }) do
			local d = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(ang)):VectorToWorldSpace(d0)
			local from = ground(to - d * dist * k)
			-- no cliffs on the way (a big step up or down means it's walking off a ledge or up a wall)
			if math.abs(from.Y - to.Y) < math.max(4, height * 0.45) and Floor.PathClear(from, to, height, width) then
				return from, d
			end
		end
	end
	return to, d0 -- (no clear line: it's already there - better than walking it through a rock or up a wall)
end

-- a clear line ACROSS a point (a dino crossing the frame): centred on `mid`, tried along `dir`, then turned a
-- little, then shorter. Returns start, end and the direction it walks.
local function clearCrossing(mid: Vector3, dir: Vector3, len: number, height: number, width: number): (Vector3, Vector3, Vector3)
	local d0 = Vector3.new(dir.X, 0, dir.Z)
	d0 = d0.Magnitude > 0.01 and d0.Unit or Vector3.new(1, 0, 0)
	for _, k in ipairs({ 1, 0.8, 0.6 }) do
		for _, ang in ipairs({ 0, 15, -15, 30, -30 }) do
			local d = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(ang)):VectorToWorldSpace(d0)
			local a = ground(mid - d * (len * k / 2))
			local b = ground(mid + d * (len * k / 2))
			local step = math.max(4, height * 0.45)
			if math.abs(a.Y - mid.Y) < step and math.abs(b.Y - mid.Y) < step and Floor.PathClear(a, b, height, width) then
				return a, b, d
			end
		end
	end
	-- (no line it can really walk: it stands its ground instead of walking through whatever is in the way)
	local g0 = ground(mid)
	return g0, g0, d0
end
View.Pace = pace

-- the era's site whose nest is nearest a point (its species stars in that shot)
-- the nearest site's species (and whether you've found that site yet: an undiscovered dino can be SEEN in the
-- era's establishing shots - the world is alive - but never NAMED before its reveal)
local function speciesNear(zone: string, at: Vector3, used: { [string]: boolean }): (string?, boolean)
	local best, bd, bestKey = nil, math.huge, nil
	for _, f in ipairs(SitesFolder:GetChildren()) do
		if f:GetAttribute("Era") == zone and not f:GetAttribute("Boss") then
			local sp = f:GetAttribute("Species")
			local c = f:GetAttribute("Center")
			if typeof(c) == "Vector3" and sp and not used[sp] then
				local d = (c - at).Magnitude
				if d < bd then best, bd, bestKey = sp, d, f:GetAttribute("Key") or f.Name:gsub("_", "/") end
			end
		end
	end
	local known = bestKey ~= nil and seen("Found_" .. tostring(bestKey))
	return best, known
end

local function scaleOf(species: string): number
	local c = Config.Combat[species]
	return (c and c.Scale) or 1
end

-- the size it really is at its site (a herd's lead stands taller than the rest), so a reveal never shows a
-- smaller dino than the one you then meet
local function siteScale(species: string): number
	for _, era in ipairs(Config.Eras) do
		for _, def in ipairs((era :: any).Sites or {}) do
			if def.Species == species and def.Kind == "Herd" then return 1.15 end
		end
	end
	return scaleOf(species)
end

-- the little scenery a standing dino overlaps (a bush round its legs, a fern through its belly) tucks away while it
-- stands there, and comes back when it goes
local function clearBody(m: Model)
	local cf, size = m:GetBoundingBox()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = { m :: Instance }
	for _, n in ipairs({ "ActiveVehicles", "DinoExpeditionLocal", "DinoAmbience", "DinoCutsceneActors" }) do
		local f = Workspace:FindFirstChild(n)
		if f then table.insert(skip, f) end
	end
	params.FilterDescendantsInstances = skip
	local hidden, done = {}, {}
	for _, p in ipairs(Workspace:GetPartBoundsInBox(cf, size + Vector3.new(1, 0, 1), params)) do
		local deco = p:FindFirstAncestorWhichIsA("Model")
		if deco == Workspace then deco = nil end
		local key = deco or p
		if done[key] then continue end
		done[key] = true
		if not isScenery(deco and deco.Name or p.Name) then continue end
		if deco and deco:GetExtentsSize().Magnitude > 80 then continue end
		for _, d in ipairs(deco and deco:GetDescendants() or { p }) do
			if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then
				d.LocalTransparencyModifier = 1
				table.insert(hidden, d)
			end
		end
	end
	if #hidden > 0 then
		m.AncestryChanged:Connect(function(_, parent)
			if parent then return end
			for _, d in ipairs(hidden) do if d.Parent then d.LocalTransparencyModifier = 0 end end
		end)
	end
end

-- a few of a species grazing / looking around near a point. Each one stands where there's room for it - never in a
-- post, a boulder or a trunk (2026-10-14) - and the little foliage round its legs steps aside
local function herdAt(species: string, at: Vector3, n: number, spread: number, faceTo: Vector3): { any }
	local list = {}
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + 0.7
		local r = spread * (0.4 + (i % 2) * 0.6)
		local p = ground(at + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		local face = Vector3.new(faceTo.X, p.Y, faceTo.Z)
		local yawJitter = CFrame.Angles(0, (i - 2) * 0.7, 0)
		local m, anim = standIn(species, scaleOf(species) * (0.8 + (i % 3) * 0.12), CFrame.lookAt(p, face) * yawJitter)
		if m then
			local root = m.PrimaryPart :: BasePart
			local lift = root.Position.Y - p.Y
			local _, sz = m:GetBoundingBox()
			local function roomAt(q: Vector3, f: Vector3): boolean
				local cf = CFrame.lookAt(q, Vector3.new(f.X, q.Y, f.Z)) * yawJitter
				-- (the box starts a stud off the floor: a slope under the feet isn't a wall)
				return Floor.Free(cf + Vector3.new(0, sz.Y / 2 + 0.6, 0), Vector3.new(sz.X * 0.85, math.max(1, sz.Y - 1.2), sz.Z * 0.85), { m })
			end
			if not roomAt(p, face) then
				local placed = false
				for _, k in ipairs({ 0.35, -0.35, 0.7, -0.7, 1.2, -1.2, 2.0, -2.0 }) do
					for _, rr in ipairs({ r, r + sz.Z * 0.6, math.max(1, r - sz.Z * 0.5) }) do
						local q = ground(at + Vector3.new(math.cos(a + k) * rr, 0, math.sin(a + k) * rr))
						local f = Vector3.new(faceTo.X, q.Y, faceTo.Z)
						if math.abs(q.Y - at.Y) < math.max(4, sz.Y * 0.4) and roomAt(q, f) then
							root.CFrame = CFrame.lookAt(q, f) * yawJitter * CFrame.new(0, lift, 0)
							placed = true
							break
						end
					end
					if placed then break end
				end
				-- (nowhere with room: this one stays out of the shot rather than standing in a rock)
				if not placed then m:Destroy() m = nil end
			end
		end
		if m then
			clearBody(m)
			if anim then
				local idle = anim:HasAction("Graze") and "Graze" or (anim:HasAction("Browse") and "Browse" or (anim:HasAction("Sniff") and "Sniff" or "LookAround"))
				task.delay(i * 0.4, function()
					if m.Parent and anim:HasAction(idle) then
						local tr = anim:Play(idle, { Loop = true })
						if tr then tr.Loop = true end
					end
				end)
			end
			table.insert(list, { Model = m, Anim = anim })
		end
	end
	return list
end

-- the boss of the era, in its den (2026-10-13 redo, user: "why is he coming out of the wall? make it actually
-- intimidating and don't just show a black silhouette"). He comes DOWN off his mound toward a lens low on the den
-- floor - out in the open, never backed into the rock face behind it - every footfall a thud; stops, lowers his head
-- to look right into the camera, eyes lit; then roars into it and the camera is shoved back. Lit by a warm key light
-- so you see him properly, under a harder, darker grade.
local function rulerGlimpse(zone: string, skipped: () -> boolean)
	local boss = eraBoss(zone)
	local throne = marker(zone, "Throne")
	local center = marker(zone, "DenCenter")
	if not (boss and throne and center) then return end
	local out = Vector3.new(center.Position.X - throne.Position.X, 0, center.Position.Z - throne.Position.Z)
	if out.Magnitude < 1 then out = Vector3.new(0, 0, -1) end
	out = out.Unit
	local side = out:Cross(Vector3.yAxis)
	local stopAt = ground(center.Position)
	-- how big he is, then a walk down to the floor he can really make (no rock, stump or ledge in the way)
	local probe = standIn(boss.Species, boss.Scale, CFrame.lookAt(stopAt, stopAt + out))
	local ext = probe and select(2, probe:GetBoundingBox()) or Vector3.new(8, 16, 30)
	if probe then probe:Destroy() end
	local from, dir = clearApproach(stopAt, out, 10, ext.Y, math.max(ext.X, 4))
	local m, anim = standIn(boss.Species, boss.Scale, CFrame.lookAt(from, from + dir))
	if not m then return end
	m:SetAttribute("DisplayName", boss.Name)
	cineKeep[m] = true
	local root = m.PrimaryPart :: BasePart
	local lift = root.Position.Y - from.Y
	local walkLen = Vector3.new(stopAt.X - from.X, 0, stopAt.Z - from.Z).Magnitude
	local cleared = clearPath(m, 12)
	-- a warm key light in front of him (dens are dark: he must read as HIM, not a shape) + a harder grade
	local key = Instance.new("Part")
	key.Name = "DinoRulerKey"
	key.Anchored, key.CanCollide, key.CanQuery, key.CanTouch, key.Transparency = true, false, false, false, 1
	key.Size = Vector3.new(1, 1, 1)
	key.CFrame = CFrame.new(stopAt + dir * 14 + side * 6 + Vector3.new(0, ext.Y * 0.8, 0))
	key.Parent = m.Parent
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 176, 120)
	light.Brightness = 2.4
	light.Range = 48
	light.Shadows = true
	light.Parent = key
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DinoRulerGrade"
	grade.Parent = Lighting
	TweenService:Create(grade, TweenInfo.new(0.4), { Contrast = 0.3, Saturation = -0.18, TintColor = Color3.fromRGB(255, 226, 210) }):Play()
	local function headPos(): Vector3
		local hd = DinosaurVFX.findAttachment(m, "VFX_Head")
		return hd and hd.WorldPosition or (root.Position + dir * ext.Z * 0.4 + Vector3.new(0, ext.Y * 0.3, 0))
	end
	-- (no fixed delay for the big hit: it lands on the roar itself - the animation's own "Roar" beat - so the title,
	-- the punch and the sound all hit together. 2026-10-14: the hit used to fire 0.7 s before he opened his jaws)
	local roarAt: number? = nil
	local evConn = anim and anim.Event and anim.Event:Connect(function(name)
		if name == "Roar" and not roarAt then roarAt = os.clock() end
	end)
	local cam = Workspace.CurrentCamera
	-- everything that can go wrong goes wrong inside here: the light, the grade and the double are always cleaned up
	local ok, err = pcall(function()
		-- 1. low on the den floor: the feet come down toward the lens
		local front = stopAt + dir * (ext.Z * 0.55 + 7)
		local lowPos = clearSpot({ front + side * 4 + Vector3.new(0, 1.1, 0), front - side * 4 + Vector3.new(0, 1.1, 0), front + Vector3.new(0, 2.2, 0),
			front + dir * 6 + Vector3.new(0, 2, 0) }, { stopAt + Vector3.new(0, ext.Y * 0.45, 0) }, { m })
		if anim then anim:SetLocomotion(walkLen > 1 and "Walk" or "Idle", 0.1) end
		fade(0, 0.2)
		local dur = 2.4
		local t0, last, nextStep = os.clock(), os.clock(), 0.3
		while os.clock() - t0 < dur and not skipped() do
			local now = os.clock()
			local u = (now - t0) / dur
			local p = ground(from:Lerp(stopAt, math.min(1, u * 1.12)))
			root.CFrame = CFrame.lookAt(p, p + dir) * CFrame.new(0, lift, 0)
			pace(anim, walkLen / dur, now - last)
			last = now
			if now - t0 >= nextStep and u < 0.92 then
				nextStep += 0.62
				DinosaurVFX.Shake(0.3 + u * 0.45, 0.28)
				DinosaurVFX.DustWave(p + dir * ext.Z * 0.2, dir, math.max(0.6, ext.Y / 16))
				Audio.Play("StompBig", { At = p, Volume = 1.2, Pitch = 0.55 })
			end
			local look = p + Vector3.new(0, ext.Y * (0.42 + u * 0.22), 0)
			cam.CFrame = safeCam(CFrame.lookAt(lowPos + dir * (u * 1.6), look), look)
			cam.FieldOfView = 56 - u * 8
			cineSubject = look
			RunService.RenderStepped:Wait()
		end
		if anim then anim:SetLocomotion("Idle", 0.2) end
		root.CFrame = CFrame.lookAt(stopAt, stopAt + dir) * CFrame.new(0, lift, 0)
		if skipped() then return end
		-- 2. under the jaw: the head comes down to look at you, eyes burning, a growl you feel in your chest
		if anim and anim:HasAction("Sniff") then anim:Play("Sniff") end
		DinosaurVFX.EyeGlow(m, 6)
		local h = headPos()
		Audio.Play("Growl", { At = h, Volume = 1.4, Pitch = 0.62, Exact = true })
		local under = clearSpot({ h + dir * 11 - side * 3 - Vector3.new(0, ext.Y * 0.28, 0), h + dir * 11 + side * 3 - Vector3.new(0, ext.Y * 0.28, 0),
			h + dir * 14 - Vector3.new(0, 2, 0), h + dir * 16 + Vector3.new(0, 1, 0) }, { h }, { m })
		local toHead = (h - under).Unit
		move(CFrame.lookAt(under, h), CFrame.lookAt(under + toHead * 2.5, h), 1.3, skipped, 44, 38, h)
		if skipped() then return end
		-- 3. the roar, straight into the lens: a held breath while the jaws open, then the camera is shoved back by
		-- it and holds on him while it rings out (the whole roar, never cut on the scream)
		roarAt = nil
		local roarStart = os.clock()
		if anim and anim:HasAction("Roar") then anim:Play("Roar") end
		local near = under + toHead * 2.5
		local hit = false
		local hitAt = 0
		local t3 = os.clock()
		while not skipped() do
			local now = os.clock()
			-- (no roar beat from the animation: hit on its usual mark)
			if not hit and (roarAt or now - roarStart > 1.0) then
				hit, hitAt = true, now
				punch(10)
				CineKit.ImpactFrame(0.5)
				DinosaurVFX.Shake(1.5, 1.3)
				DinosaurVFX.DustWave(stopAt + dir * ext.Z * 0.3, dir, math.max(1, ext.Y / 9))
				Audio.Sting("Reveal")
				rayTitle(boss.Name, boss.Title or ("THE BOSS OF " .. (Config.Era(zone) :: any).Name), boss.Color, 2.6)
			end
			local hd = headPos()
			local pos, fov
			if not hit then
				-- the breath before: creeping in, the lens tightening
				local u = math.clamp((now - t3) / 1.0, 0, 1)
				pos, fov = near + toHead * (0.6 * u), 38 - u * 2
			else
				-- the blast: shoved back hard, then hanging there while he screams
				local k = math.clamp((now - hitAt) / 0.45, 0, 1)
				k = 1 - (1 - k) ^ 3
				pos = near + toHead * 0.6 - toHead * (6.6 * k) + Vector3.new(0, -0.6 * k, 0) - toHead * ((now - hitAt) * 0.4)
				fov = 36 + 18 * k
			end
			cam.CFrame = safeCam(CFrame.lookAt(pos, hd), hd)
			cam.FieldOfView = fov
			cineSubject = hd
			if hit and now - hitAt > 1.7 then break end
			if now - t3 > 4 then break end
			RunService.RenderStepped:Wait()
		end
		fade(1, 0.3)
	end)
	if not ok then warn("[EraView] boss glimpse:", err) end
	if evConn then evConn:Disconnect() end
	-- (the roar plays out behind the black and over the cut instead of dying with the model)
	pcall(keepSounds, m, true)
	pcall(restorePath, cleared)
	TweenService:Create(grade, TweenInfo.new(0.3), { Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	task.delay(0.35, function() grade:Destroy() end)
	key:Destroy()
	m:Destroy()
end

function View.Establish(zone: string, full: boolean)
	local era = Config.Era(zone)
	local folder = zoneModel(zone) and (zoneModel(zone) :: Instance):FindFirstChild("Cinematics", true)
	local shots = {}
	for i = 1, 4 do
		local m = folder and folder:FindFirstChild("EstShot" .. i)
		if m and m:IsA("BasePart") then table.insert(shots, m) end
	end
	if #shots == 0 or not era then return end
	local props = {} :: { Model }
	scene(function(skipped)
		-- A: a crane up from the grass to the whole era (title card)
		local cf1, look1 = shotCF(shots[1])
		local dir1 = Vector3.new(look1.X - cf1.X, 0, look1.Z - cf1.Z).Unit
		local base = ground(cf1.Position + dir1 * 70)
		local low = CFrame.lookAt(base + Vector3.new(0, 3, 0), base + dir1 * 60 + Vector3.new(0, 6, 0))
		fade(0, 0.6)
		-- the sun-ray title is for a NEW era (first visit); a return just gets the name card
		if full then rayTitle(era.Name, era.Year, era.Color, 3.2) else card(era.Year, era.Name, nil, era.Color) end
		if full then
			-- end tilted down into the valley: looking level from up there is mostly haze
			local endLook = look1 - Vector3.new(0, math.max(0, (cf1.Position - look1).Magnitude * 0.18), 0)
			move(low, CFrame.lookAt(cf1.Position, endLook), 3.8, skipped, 62, 50)
		else
			-- been here before: a short beat, different each time: out of the portal / down from above / a site you know
			local v = nextVariant("Arrive", 3)
			local known = {}
			for _, f in ipairs(SitesFolder:GetChildren()) do
				local key = f:GetAttribute("Key") or (zone .. "/" .. tostring(f:GetAttribute("Id") or f.Name))
				if f:GetAttribute("Era") == zone and not f:GetAttribute("Boss") and seen("Found_" .. key) and typeof(f:GetAttribute("Center")) == "Vector3" then table.insert(known, f) end
			end
			local rv = myRover()
			if v == 3 and #known > 0 then
				-- a site you've found, its dino going about its day
				local f = known[math.random(1, #known)]
				local sp = f:GetAttribute("Species")
				local c = ground(f:GetAttribute("Center"))
				local herd = herdAt(sp, c, 1, 4, c + Vector3.new(30, 0, 0))
				for _, h in ipairs(herd) do table.insert(props, h.Model) end
				local dir = Vector3.new(1, 0, 0.4).Unit
				local spot = clearSpot({ c + dir * 34 + Vector3.new(0, 8, 0), c - dir * 34 + Vector3.new(0, 8, 0), c + Vector3.new(0, 26, 24) }, { c + Vector3.new(0, 4, 0) })
				move(CFrame.lookAt(spot, c + Vector3.new(0, 4, 0)), CFrame.lookAt(spot:Lerp(c, 0.18), c + Vector3.new(0, 4, 0)), 2.6, skipped, 46, 40, c + Vector3.new(0, 4, 0))
			elseif v == 2 and rv then
				-- down from above the portal onto the rover
				local rc = rv.CFrame
				local fwd = Vector3.new(rc.LookVector.X, 0, rc.LookVector.Z).Unit
				local subj = rc.Position + Vector3.new(0, 2, 0)
				local hi = subj - fwd * 6 + Vector3.new(0, 34, 0)
				local lo = subj + fwd * 14 + fwd:Cross(Vector3.yAxis) * 7 + Vector3.new(0, 5, 0)
				move(CFrame.lookAt(hi, subj + fwd * 20), CFrame.lookAt(clearSpot({ lo }, { subj }), subj), 2.8, skipped, 56, 48, subj)
			elseif rv then
				local rc = rv.CFrame
				local fwd = Vector3.new(rc.LookVector.X, 0, rc.LookVector.Z).Unit
				local side = fwd:Cross(Vector3.yAxis)
				local subj = rc.Position + Vector3.new(0, 2, 0)
				local spot = clearSpot({ subj + fwd * 20 + side * 9 + Vector3.new(0, 2.5, 0), subj + fwd * 20 - side * 9 + Vector3.new(0, 2.5, 0), subj + fwd * 16 + Vector3.new(0, 6, 0) }, { subj })
				local push = (subj - spot).Unit * 5
				move(CFrame.lookAt(spot, subj), CFrame.lookAt(spot + push + Vector3.new(0, 0.6, 0), subj), 2.6, skipped, 50, 46, subj)
			else
				move(low, CFrame.lookAt(low.Position + Vector3.new(0, 4, 0), base + dir1 * 60), 2.4, skipped, 56, 52)
			end
			fade(1, 0.25)
			return
		end
		if skipped() then return end
		hideCard()
		fade(1, 0.2)
		local used = {}
		-- B: a sideways truck past a herd grazing (the first site's dinos)
		if shots[2] then
			local cf, look = shotCF(shots[2])
			local sp, known = speciesNear(zone, look, used)
			if sp then
				used[sp] = true
				local g = ground(look)
				for _, h in ipairs(herdAt(sp, g, 3, 10, cf.Position)) do table.insert(props, h.Model) end
				local toCam = Vector3.new(cf.X - g.X, 0, cf.Z - g.Z).Unit
				local side = toCam:Cross(Vector3.yAxis)
				local camP = g + toCam * 30 + Vector3.new(0, 7, 0)
				fade(0, 0.2)
				if known then card("", Config.Species[sp] and (Config.Species[sp] :: any).Name or "", nil, Config.Species[sp] and (Config.Species[sp] :: any).Color or C.Yellow) end
				move(CFrame.lookAt(camP - side * 14, g + Vector3.new(0, 4, 0)), CFrame.lookAt(camP + side * 14, g + Vector3.new(0, 4, 0)), 2.8, skipped, 46, 44, g + Vector3.new(0, 4, 0))
				hideCard()
				fade(1, 0.2)
			end
		end
		if skipped() then return end
		-- C: down in the grass as another dino walks across the frame
		if shots[3] then
			local cf, look = shotCF(shots[3])
			local sp, known = speciesNear(zone, look, used)
			if sp then
				used[sp] = true
				local g = ground(look)
				local toCam = Vector3.new(cf.X - g.X, 0, cf.Z - g.Z).Unit
				local side = toCam:Cross(Vector3.yAxis)
				-- how big it is, then a line across the frame it can really walk (no rocks, trunks or ledges in the way)
				local probe = standIn(sp, scaleOf(sp), CFrame.new(g))
				local ext = probe and select(2, probe:GetBoundingBox()) or Vector3.new(4, 6, 10)
				if probe then probe:Destroy() end
				local len = math.clamp(ext.Z * 2.4 + 14, 20, 34)
				local startP, endP, dirW = clearCrossing(g, side, len, ext.Y, math.max(ext.X, 3))
				len = (Vector3.new(endP.X - startP.X, 0, endP.Z - startP.Z)).Magnitude
				local m, anim = standIn(sp, scaleOf(sp), CFrame.lookAt(startP, startP + dirW))
				if m then
					table.insert(props, m)
					local root = m.PrimaryPart :: BasePart
					local lift = root.Position.Y - startP.Y
					-- bushes and ferns it would plough through step aside for the shot (they come back after)
					local cleared = clearPath(m, len)
					table.insert(props, { Destroy = function() restorePath(cleared) end, Parent = true } :: any)
					if anim then
						if len > 1 then anim:SetLocomotion("Walk", 0.1)
						else
							anim:SetLocomotion("Idle", 0.1)
							if anim:HasAction("LookAround") then anim:Play("LookAround") end
						end
					end
					local mid = startP:Lerp(endP, 0.5)
					-- the lens: square-on to the walk, on the side the shot marker faces from, standing on its own
					-- ground (not hung at the walk's height), with the whole walk in clear view - the start, the
					-- middle and the end (2026-10-14: a fixed spot sat behind trunks and banks on some maps)
					local perp = dirW:Cross(Vector3.yAxis)
					if perp:Dot(toCam) < 0 then perp = -perp end
					local up = Vector3.new(0, lift * 0.8, 0)
					local cands = {}
					for _, k in ipairs({ 1, 0.8, 1.25 }) do
						for _, ang in ipairs({ 0, 15, -15, 30, -30 }) do
							local d = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(ang)):VectorToWorldSpace(perp)
							table.insert(cands, ground(mid + d * (22 + ext.Z * 0.6) * k) + Vector3.new(0, 1.6, 0))
						end
					end
					local camP = clearSpot(cands, { mid + up, startP + up, endP + up }, { m })
					-- (2026-10-14: a bush between this lens and the walk kept cutting in) every bit of foliage between the
					-- camera's path and the dino's is gone for the shot
					for _, u in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
						local a = camP + dirW * (u * 6 - 3)
						local b = startP:Lerp(endP, u) + Vector3.new(0, lift * 0.8, 0)
						local d = b - a
						local box = CFrame.lookAt(a + d / 2, b)
						local olap = OverlapParams.new()
						olap.FilterType = Enum.RaycastFilterType.Exclude
						olap.FilterDescendantsInstances = { m }
						for _, part in ipairs(Workspace:GetPartBoundsInBox(box, Vector3.new(4, 5, d.Magnitude), olap)) do
							local soft, key = lensSoft(part)
							if soft then fadeForLens(key) end
						end
					end
					fade(0, 0.2)
					if known then card("", Config.Species[sp] and (Config.Species[sp] :: any).Name or "", nil, Config.Species[sp] and (Config.Species[sp] :: any).Color or C.Yellow) end
					local t0 = os.clock()
					local cam = Workspace.CurrentCamera
					local dur = 3.2
					local last = os.clock()
					while os.clock() - t0 < dur and not skipped() do
						local now = os.clock()
						local u = (now - t0) / dur
						local p = ground(startP:Lerp(endP, u))
						root.CFrame = CFrame.lookAt(p, p + dirW) * CFrame.new(0, lift, 0)
						pace(anim, len / dur, now - last)
						last = now
						cam.CFrame = safeCam(CFrame.lookAt(camP + dirW * (u * 6 - 3), p + Vector3.new(0, lift * 0.8, 0)), p + Vector3.new(0, lift * 0.8, 0))
						cam.FieldOfView = 40
						RunService.RenderStepped:Wait()
					end
					if anim then anim:SetLocomotion("Idle", 0.25) end
					-- it stops and roars - and the shot stays on it for the roar (2026-10-14: it used to cut away the
					-- instant the roar began), the lens easing in a touch
					if anim and anim:HasAction("Roar") and not skipped() then
						local roared: number? = nil
						local conn = anim.Event and anim.Event:Connect(function(name) if name == "Roar" and not roared then roared = os.clock() end end)
						anim:Play("Roar")
						local p = root.Position - Vector3.new(0, lift, 0)
						local subj = p + Vector3.new(0, lift * 0.8, 0)
						local from = cam.CFrame.Position
						local t1 = os.clock()
						while not skipped() do
							local el = os.clock() - t1
							local e = math.clamp(el / 2.0, 0, 1)
							e = e * e * (3 - 2 * e)
							cam.CFrame = safeCam(CFrame.lookAt(from:Lerp(subj, 0.12 * e), subj), subj)
							cam.FieldOfView = 40 - e * 5
							if (roared and os.clock() - roared > 1.1) or el > 2.4 then break end
							RunService.RenderStepped:Wait()
						end
						if conn then conn:Disconnect() end
						pcall(keepSounds, m, true)
					end
					hideCard()
					fade(1, 0.2)
				end
			end
		end
		if skipped() then return end
		-- D: the ruler on her throne
		rulerGlimpse(zone, skipped)
		fade(1, 0.2)
	end)
	for _, m in ipairs(props) do if m.Parent then pcall(drop, m, true) end end
end

--------------------------------------------------------------------------------
-- 2. the era map
--------------------------------------------------------------------------------
local map = {} :: any
-- the camera goes back to the player - unless something else is filming right now (a scene, a signature, a TikTok
-- take, the era map): a beat that finished or was refused must never yank the camera out from under one that's on
-- something is filming right now: a scene, a signature, a TikTok take (a reveal)
local function filming(): boolean
	if busy or DinosaurCinematics.IsPlaying() then return true end
	local okT, playing = pcall(function() return (require(script.Parent.TikTok) :: any).Playing == true end)
	return okT and playing == true
end
-- Drive's roam / on-foot switches hand the lens to Roblox's follow camera (releaseCamera): never under a scene that's
-- still filming - SiteLeft / SiteArrive can land mid-cutscene, and two cameras fighting is the jitter (2026-10-14)
local function keepLens(fn: () -> ())
	local cam = Workspace.CurrentCamera
	local was, fov = cam.CameraType, cam.FieldOfView
	fn()
	if filming() then cam.CameraType, cam.FieldOfView = was, fov end
end
local function freeCam(): boolean
	if map.Gui ~= nil or filming() then return false end
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	-- (a scene that kept the camera ended on its own lens - a long-lens 20 or so: the follow cam doesn't reset it,
	-- so you walked off zoomed in. 2026-10-14)
	Workspace.CurrentCamera.FieldOfView = 70
	-- (a scene that ended on black left it for us: up it comes, on the player)
	if cine.Fade and cine.Fade.BackgroundTransparency < 0.99 then task.spawn(fade, 0, 0.3) end
	return true
end
local KIND = { Pack = "PACK", Brute = "BRUTE", Herd = "HERD", Boss = "BOSS" }
local STATUS = {
	Idle = { "QUIET - START IT", C.LimeHi },
	Active = { "FIGHT ON - JOIN IN", C.YellowHi },
	Scramble = { "KNOCKED OUT - EGGS UP FOR GRABS", C.LimeHi },
	Chase = { "ESCAPING - WAIT", C.RedHi },
	Cooldown = { "REARMING", C.Muted },
}

local function bossTierChoice(id: string): number
	local rec = Net.Profile and Net.Profile.Bosses and Net.Profile.Bosses[id]
	local best = rec and rec.Best or 0
	map.Tier = map.Tier or {}
	map.Tier[id] = math.clamp(map.Tier[id] or (best + 1), 1, best + 1)
	return map.Tier[id]
end

local discover -- forward: plays a site's reveal on location and marks it found
local function choose(key: string)
	if map.Busy then return end
	map.Busy = true
	if discover and not seen("Found_" .. key) and key:sub(-4) ~= "/Den" then
		View.HideMap()
		discover(key)
	end
	local f = siteFolder(key)
	local wasIdle = f and (f:GetAttribute("State") == "Idle" or f:GetAttribute("State") == "Cooldown") or false
	local res = Net.Ask("ChooseSite", { Site = key })
	if not (res and res.Ok) then
		Kit.Toast(res and res.Err or "CAN'T GO THERE RIGHT NOW", "Red", "Alert")
		map.Busy = false
		state.JustFound = nil
		-- (the reveal hid the map: if the site went away meanwhile - knocked out, chased - put the map back, or
		-- you're left frozen with no way to pick anywhere)
		if not map.Gui and state.Phase == "Map" then View.ShowMap() end
		return
	end
	View.HideMap()
	View.Travel(res, wasIdle)
	map.Busy = false
end

local function setPower(rec, need: number?)
	if not need or need <= 0 then
		rec.Power.Visible, rec.PowerLabel.Visible = false, false
		return
	end
	rec.Power.Visible, rec.PowerLabel.Visible = true, true
	local mine = Net.Profile and Net.Profile.Power or 0
	local col = mine >= need and C.LimeHi or (mine >= need * 0.7 and C.YellowHi or C.RedHi)
	Kit.SetText(rec.Power, Config.FormatNumber(math.floor(need)))
	Kit.SetTextColor(rec.Power, col)
end

-- sites start undiscovered: a black silhouette and "???" until you go and find out what lives there
local function discovered(key: string): boolean
	if key:sub(-4) == "/Den" then return true end -- rulers are known to everyone
	return seen("Found_" .. key)
end

local function setButtons(rec, mode: string)
	if rec.Mode == mode then return end
	rec.Mode = mode
	for _, c in ipairs(rec.Buttons:GetChildren()) do c:Destroy() end
	local z = rec.Outer.ZIndex + 6
	local function btn(text: string, color: string, onClick, disabled: boolean?, size: UDim2?, pos: UDim2?, anchor: Vector2?)
		return Kit.Button(rec.Buttons, { Text = text, Color = disabled and "Grey" or color, Size = size or UDim2.fromScale(1, 1), Position = pos, AnchorPoint = anchor, ZIndex = z, Radius = 12, MaxText = 26, Disabled = disabled, OnClick = onClick })
	end
	if mode == "Explore" then
		local b = btn("EXPLORE!", "Lime", function() choose(rec.Key) end)
		if not map.FirstGo or not map.FirstGo.Parent then map.FirstGo = b end
	elseif mode == "Go" then
		local b = btn("GO!", "Lime", function() choose(rec.Key) end)
		if not map.FirstGo or not map.FirstGo.Parent then map.FirstGo = b end
	elseif mode == "Join" then
		local b = btn("JOIN!", "Yellow", function() choose(rec.Key) end)
		if not map.FirstGo or not map.FirstGo.Parent then map.FirstGo = b end
	elseif mode == "Wait" then btn("WAIT", "Grey", nil, true)
	elseif mode == "BossJoin" then btn("JOIN FIGHT!", "Orange", function() choose(rec.Key) end)
	elseif mode == "BossBusy" then btn("FIGHT OVER", "Grey", nil, true)
	elseif mode:sub(1, 7) == "Summon:" then
		local id = rec.BossId
		local tier = bossTierChoice(id)
		local keys = (Net.Profile and Net.Profile.Keys and Net.Profile.Keys[id]) or 0
		local rec2 = Net.Profile and Net.Profile.Bosses and Net.Profile.Bosses[id]
		local best = rec2 and rec2.Best or 0
		btn("<", "Slate", function()
			map.Tier[id] = math.max(1, tier - 1)
			rec.Mode = nil
		end, tier <= 1, UDim2.fromOffset(38, 46), UDim2.fromScale(0, 0))
		btn(">", "Slate", function()
			map.Tier[id] = math.min(best + 1, tier + 1)
			rec.Mode = nil
		end, tier >= best + 1, UDim2.fromOffset(38, 46), UDim2.fromScale(1, 0), Vector2.new(1, 0))
		btn("SUMMON  KEY x" .. keys, "Purple", function()
			local res = Net.Ask("SummonBoss", { Boss = id, Tier = tier })
			if res and res.Ok then
				Kit.Toast("YOU WOKE THE " .. (Config.Bosses[id] :: any).Name .. "!", "Orange", "Trophy")
			else
				Kit.Toast(res and res.Err or "CAN'T SUMMON", "Red", "Lock")
			end
		end, keys <= 0, UDim2.new(1, -86, 1, 0), UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0))
	end
end

-- the overhead map: the camera rises above the era, every site and the ruler's den gets a live waypoint;
-- tap one and the camera flies over it while a card shows what's happening there and the GO! button
local function siteKeys(era): { any }
	local list = {}
	for _, def in ipairs(era.Sites or {}) do table.insert(list, { Key = era.Id .. "/" .. def.Id, Def = def, Boss = false }) end
	if era.Boss then
		local boss = Config.Bosses[era.Boss] :: any
		table.insert(list, { Key = era.Id .. "/Den", Def = { Name = boss.Name, Species = boss.Species, Kind = "Boss" }, Boss = true, BossId = era.Boss })
	end
	return list
end

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

local function pinPos(key: string): Vector3?
	local f = siteFolder(key)
	local c = f and f:GetAttribute("Center")
	return (typeof(c) == "Vector3" and finite(c)) and c or nil
end

-- the era's own footprint (its zone model's box): the overview never frames anything outside it
-- (playtest 2026-10-12: the bird's-eye view once framed the showcase mock-ups on the baseplate)
local zoneBoxes = {} :: { [string]: { CF: CFrame, Size: Vector3 } }
local function zoneBox(zone: string?)
	local zm = zoneModel(zone)
	if not (zone and zm and zm:IsA("Model")) then return nil end
	local box = zoneBoxes[zone]
	if not box then
		local cf, size = (zm :: Model):GetBoundingBox()
		box = { CF = cf, Size = size }
		zoneBoxes[zone] = box
	end
	return box
end
local function inZone(box, p: Vector3, margin: number): boolean
	if not box then return true end
	local lp = box.CF:PointToObjectSpace(p)
	return math.abs(lp.X) <= box.Size.X / 2 + margin and math.abs(lp.Z) <= box.Size.Z / 2 + margin
end

local function overview(): CFrame
	local box = zoneBox(state.Zone)
	local pts = {}
	for _, s in ipairs(map.Sites or {}) do
		local p = pinPos(s.Key)
		if p and inZone(box, p, 40) then table.insert(pts, p) end
	end
	-- you only count when you're really in the era (never a character left at camp / on the baseplate)
	local r = hrp()
	if r and finite(r.Position) and inZone(box, r.Position, 40) then table.insert(pts, r.Position) end
	local c, spread
	if #pts > 0 then
		c = Vector3.zero
		for _, p in ipairs(pts) do c += p end
		c /= #pts
		spread = 60
		for _, p in ipairs(pts) do spread = math.max(spread, (Vector3.new(p.X, 0, p.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude) end
	elseif box then
		-- nothing usable: frame the whole era from its own bounds
		warn("[EraView] map overview: no site pins in", state.Zone, "- framing the era's bounds")
		c = ground(box.CF.Position)
		spread = math.max(box.Size.X, box.Size.Z) / 2
	else
		return Workspace.CurrentCamera.CFrame
	end
	-- stay inside what every device draws: low graphics settings cut the view distance, and from 600+ studs up
	-- the era vanished into fog. closer camera, wider lens to still fit every site
	local dist = math.clamp(spread * 1.8, 120, 260)
	map.Fov = math.clamp(math.deg(2 * math.atan((spread * 1.15) / dist)), 50, 80)
	local dir = Vector3.new(0, 1.55, 0.95).Unit
	return CFrame.lookAt(c + dir * dist, c)
end

local function focusOn(key: string?)
	if not key then map.CamGoal = overview() return end
	local p = pinPos(key)
	if not p then return end
	map.Fov = 50
	map.CamGoal = CFrame.lookAt(p + Vector3.new(0, 95, 80), p + Vector3.new(0, 0, 10))
end

local function buildCard(canvas: Frame)
	local outer, content = Kit.Card(canvas, { Size = UDim2.fromOffset(640, 170), Position = UDim2.new(0.5, 0, 1, -18), AnchorPoint = Vector2.new(0.5, 1), Color = "Forest", Border = C.LimeHi, ZIndex = 10, Radius = 18 })
	local card = { Outer = outer, Content = content }
	card.Icon = Instance.new("Frame")
	card.Icon.BackgroundTransparency = 1
	card.Icon.Size = UDim2.fromOffset(150, 150)
	card.Icon.Position = UDim2.new(0, -8, 0.5, -6)
	card.Icon.AnchorPoint = Vector2.new(0, 0.5)
	card.Icon.ZIndex = 16
	card.Icon.Parent = content
	card.Name = Kit.Text(content, "", { Size = UDim2.new(0, 280, 0, 32), Position = UDim2.fromOffset(150, 16), Align = Enum.TextXAlignment.Left, ZIndex = 16, Stroke = 4, Shadow = 3, MaxSize = 34 })
	card.Tag = Kit.Text(content, "", { Pixel = true, Size = UDim2.new(0, 280, 0, 11), Position = UDim2.fromOffset(152, 54), Align = Enum.TextXAlignment.Left, ZIndex = 16, Stroke = 2, Shadow = 1, MaxSize = 11, Color = C.Cream })
	card.Status = Kit.Text(content, "", { Pixel = true, Size = UDim2.new(0, 280, 0, 13), Position = UDim2.fromOffset(152, 76), Align = Enum.TextXAlignment.Left, ZIndex = 16, Stroke = 2, Shadow = 1, MaxSize = 13 })
	card.Sub = Kit.Text(content, "", { Pixel = true, Size = UDim2.new(0, 280, 0, 10), Position = UDim2.fromOffset(152, 98), Align = Enum.TextXAlignment.Left, ZIndex = 16, Stroke = 1.5, Shadow = 1, MaxSize = 10, Color = C.Muted })
	card.SetBar, card.Bar = Kit.Segments(content, 10, { Size = UDim2.fromOffset(240, 10), Position = UDim2.fromOffset(152, 118), ZIndex = 16 })
	-- recommended power, big and coloured against yours (green: ready, yellow: close, red: too strong for you)
	card.PowerLabel = Kit.Text(content, "RECOMMENDED POWER", { Pixel = true, Size = UDim2.fromOffset(200, 11), Position = UDim2.new(1, -16, 0, 36), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 16, Stroke = 2, Shadow = 1, MaxSize = 11, Color = C.Cream })
	card.Power = Kit.Text(content, "", { Size = UDim2.fromOffset(200, 34), Position = UDim2.new(1, -16, 0, 49), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 16, Stroke = 4, Shadow = 3, MaxSize = 34, Color = C.LimeHi })
	card.Stars = Kit.Text(content, "", { Pixel = true, Size = UDim2.fromOffset(120, 14), Position = UDim2.new(1, -16, 0, 14), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 16, Stroke = 2, Shadow = 1, MaxSize = 14, Color = C.YellowHi })
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(190, 60)
	holder.Position = UDim2.new(1, -16, 1, -16)
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.ZIndex = 16
	holder.Parent = content
	card.Buttons = holder
	return card
end

local function selectSite(key: string)
	local card = map.Card
	if not card then return end
	local s = nil
	for _, x in ipairs(map.Sites) do if x.Key == key then s = x end end
	if not s then return end
	map.Sel = key
	card.Key, card.Def, card.Boss, card.BossId, card.Mode = s.Key, s.Def, s.Boss, s.BossId, nil
	for _, c in ipairs(card.Icon:GetChildren()) do c:Destroy() end
	local known = discovered(key)
	Kit.Icon(card.Icon, s.Boss and "Crown" or "Dino", { Species = (not s.Boss) and s.Def.Species or nil, Silhouette = not known, Size = UDim2.fromScale(1, 1), ZIndex = 17, Rotation = -6 })
	if s.Boss then Kit.Icon(card.Icon, "Dino", { Species = s.Def.Species, Size = UDim2.fromScale(0.95, 0.95), Position = UDim2.fromScale(0.5, 0.56), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 18 }) end
	Kit.SetText(card.Name, known and s.Def.Name or "???")
	Kit.SetTextColor(card.Name, s.Boss and C.OrangeHi or (known and C.White or C.Muted))
	local tag = s.Boss and "BOSS OF " .. ((Config.Era(state.Zone or "") :: any).Name) or (known and ((KIND[s.Def.Kind] or "") .. ((s.Def.Count and s.Def.Count > 1) and (" x" .. s.Def.Count) or "") .. "  -  " .. (s.Def.Blurb or "")) or "UNDISCOVERED")
	Kit.SetText(card.Tag, tag)
	if map.HomeBtn then map.HomeBtn.Visible = false end
	if map.DriveBtn then map.DriveBtn.Visible = false end
	if map.BackBtn then map.BackBtn.Visible = true end
	card.Outer.Visible = true
	Kit.Pop(card.Outer, 0.85)
	for k, pin in pairs(map.Pins) do pin.Sel = k == key end
	focusOn(key)
	map.Refresh()
	Kit.Sound("Click", 0.4, 1.2)
end

local function refreshPins()
	local now = Workspace:GetServerTimeNow()
	for key, pin in pairs(map.Pins or {}) do
		local f = siteFolder(key)
		if not f then continue end
		local st = f:GetAttribute("State") or "Idle"
		local n = f:GetAttribute("Players") or 0
		local col, line = C.LimeHi, "QUIET"
		if pin.Boss then
			local phase = f:GetAttribute("Phase") or 0
			if phase == 0 then
				local at = Runtime:GetAttribute("NextBossAt") or 0
				col, line = C.Muted, at > now and ("WAKES " .. fmtTime(at - now)) or "ASLEEP"
			-- every live phase is joinable (the den, the chase, the final stand)
			elseif phase == 1 then col, line = C.OrangeHi, "AWAKE! JOIN"
			elseif phase == 2 then col, line = C.OrangeHi, "CHASE! JOIN"
			elseif phase == 3 then col, line = C.RedHi, "FINAL! JOIN"
			else col, line = C.Muted, "FIGHT OVER" end
		else
			local s = STATUS[st] or STATUS.Idle
			col = s[2]
			line = st == "Active" and (n .. (n == 1 and " HUNTER" or " HUNTERS")) or ({ Idle = "QUIET", Scramble = "EGGS UP FOR GRABS", Chase = "ESCAPING", Cooldown = "REARMING" })[st] or ""
			local mood = f:GetAttribute("Mood")
			if st == "Idle" and mood == "Drowsy" then line, col = "DROWSY", C.TealHi
			elseif st == "Idle" and mood == "Restless" then line, col = "RESTLESS +1 EGG", C.OrangeHi end
		end
		pin.Stroke.Color = pin.Sel and C.YellowHi or col
		pin.Stroke.Thickness = pin.Sel and 6 or 4
		Kit.SetText(pin.Status, line)
		Kit.SetTextColor(pin.Status, col)
		local pulse = 1 + math.sin(os.clock() * 4) * (pin.Sel and 0.06 or 0.02)
		pin.Scale.Scale = (pin.Sel and 1.18 or 1) * pulse
	end
end

local function refreshMap()
	if not map.Gui then return end
	refreshPins()
	local card = map.Card
	Kit.SetText(map.Power, "YOUR POWER  " .. Config.FormatNumber(Net.Profile and Net.Profile.Power or 0))
	if not card or not card.Key then return end
	local f = siteFolder(card.Key)
	if not f then return end
	local now = Workspace:GetServerTimeNow()
	local st = f:GetAttribute("State") or "Idle"
	local n = f:GetAttribute("Players") or 0
	local calm, cmax = f:GetAttribute("Calm") or 0, math.max(1, f:GetAttribute("CalmMax") or 1)
	local rec = card
	if card.Boss then
		local phase = f:GetAttribute("Phase") or 0
		local boss = Config.Bosses[card.BossId] :: any
		local tierName = Config.BossTier(f:GetAttribute("Tier") or 1).Name
		if phase == 0 then
			local at = Runtime:GetAttribute("NextBossAt") or 0
			Kit.SetText(rec.Status, "ASLEEP ON ITS THRONE")
			Kit.SetTextColor(rec.Status, C.Cream)
			Kit.SetText(rec.Sub, at > now and ("IT WAKES FOR EVERYONE IN " .. fmtTime(at - now)) or "IT WAKES SOON")
			rec.Bar.Visible = false
			setButtons(rec, "Summon:" .. bossTierChoice(card.BossId))
			local t = Config.BossTier(bossTierChoice(card.BossId))
			Kit.SetText(rec.Sub, (at > now and ("IT WAKES FOR EVERYONE IN " .. fmtTime(at - now)) or "IT WAKES SOON") .. "  -  TIER " .. t.Name)
			setPower(rec, boss.Power * t.Power)
		elseif phase >= 1 and phase <= 3 then
			-- a fight in progress: join it wherever it's got to (the den, the chase, the final stand)
			local hunting = f:GetAttribute("Hunters") or n
			local started = f:GetAttribute("Started") == true
			local col = phase == 3 and C.RedHi or C.OrangeHi
			local line = phase == 1 and (started and "FIGHT ON!" or "AWAKE!") or (phase == 2 and "IT'S RUNNING!" or "LAST STAND!")
			Kit.SetText(rec.Status, hunting > 0 and (line .. "  " .. hunting .. (hunting == 1 and " HUNTER" or " HUNTERS") .. " - " .. tierName) or (line .. " " .. tierName))
			Kit.SetTextColor(rec.Status, col)
			Kit.SetText(rec.Sub, phase == 1 and (started and "JUMP IN - EVERY HIT COUNTS" or "THE FIGHT STARTS AS HUNTERS ARRIVE")
				or (phase == 2 and "JOIN THE CHASE - DART IT FROM YOUR ROVER" or "JOIN THE FINAL STAND - FINISH IT TOGETHER"))
			rec.Bar.Visible = cmax > 1
			rec.SetBar(calm / cmax, col)
			setButtons(rec, "BossJoin")
			setPower(rec, boss.Power * Config.BossTier(f:GetAttribute("Tier") or 1).Power)
		else
			Kit.SetText(rec.Status, "FIGHT OVER")
			Kit.SetTextColor(rec.Status, C.Muted)
			Kit.SetText(rec.Sub, "CATCH THE NEXT ONE")
			setPower(rec, nil)
			rec.Bar.Visible = true
			rec.SetBar(calm / cmax, C.RedHi)
			setButtons(rec, "BossBusy")
		end
		local stars = Net.Profile and Net.Profile.Bosses and Net.Profile.Bosses[card.BossId]
		Kit.SetText(rec.Stars, string.rep("*", stars and stars.Best or 0))
	else
		local s = STATUS[st] or STATUS.Idle
		local known = discovered(card.Key)
		Kit.SetText(rec.Status, st == "Active" and (n .. (n == 1 and " HUNTER" or " HUNTERS") .. " FIGHTING") or s[1])
		Kit.SetTextColor(rec.Status, s[2])
		-- the site's mood this round (rolled on every reset): a reason to pick one site over another
		local moodId = f:GetAttribute("Mood")
		local mood = nil
		for _, m in ipairs(Config.Encounter.Moods) do if m.Id == moodId then mood = m end end
		local moodLine = (mood and mood.Id ~= "Calm") and (mood.Name .. ": " .. mood.Desc .. "  -  ") or ""
		Kit.SetText(rec.Sub, (not known) and "NOBODY KNOWS WHAT LIVES HERE - GO AND FIND OUT" or (st == "Cooldown" and "BACK IN A MOMENT" or (moodLine .. string.format("EGGS = HUNTERS + %d", Config.Encounter.EggsBonus + ((mood and mood.Eggs) or 0)))))
		rec.Bar.Visible = st == "Active" and cmax > 1
		if st == "Active" then rec.SetBar(calm / cmax, C.TealHi) end
		setPower(rec, card.Def and card.Def.Power)
		Kit.SetText(rec.Stars, "")
		local mode = (st == "Chase" or st == "Cooldown") and "Wait" or ((st == "Active" or st == "Scramble") and n > 0 and "Join" or "Go")
		if mode == "Go" and not known then mode = "Explore" end
		setButtons(rec, mode)
	end
end
map.Refresh = function() refreshMap() end

local function buildPin(site, folder: Folder)
	local p = pinPos(site.Key)
	if not p then return nil end
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Transparency = true, false, false, false, 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = p + Vector3.new(0, site.Boss and 26 or 16, 0)
	anchor.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Name = "Pin_" .. site.Key
	bb.Adornee = anchor
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Active = true
	bb.Size = UDim2.fromOffset(site.Boss and 170 or 150, site.Boss and 190 or 170)
	bb.ResetOnSpawn = false
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Parent = root
	-- the badge: a round portrait, a coloured status ring, a stalk pointing down at the site
	local d = site.Boss and 104 or 88
	local ring = Instance.new("Frame")
	ring.BackgroundColor3 = C.Forest
	ring.Size = UDim2.fromOffset(d, d)
	ring.Position = UDim2.new(0.5, 0, 0, site.Boss and 26 or 8)
	ring.AnchorPoint = Vector2.new(0.5, 0)
	ring.Parent = root
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0.5, 0)
	cr.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = C.LimeHi
	stroke.Parent = ring
	local known = discovered(site.Key)
	if not known then ring.BackgroundColor3 = Color3.fromRGB(18, 22, 20) end
	Kit.Icon(ring, "Dino", { Species = site.Def.Species, Silhouette = not known, Size = UDim2.fromScale(1.12, 1.12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
	if not known then Kit.Text(ring, "?", { Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Stroke = 4, Shadow = 3, MaxSize = 48, Color = C.YellowHi }) end
	if site.Boss then Kit.Icon(root, "Crown", { Size = UDim2.fromOffset(62, 62), Position = UDim2.new(0.5, 0, 0, -6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 6, Rotation = -8 }) end
	local stalk = Instance.new("Frame")
	stalk.BackgroundColor3 = C.Cream
	stalk.BorderSizePixel = 0
	stalk.Size = UDim2.fromOffset(4, 16)
	stalk.Position = UDim2.new(0.5, 0, 0, (site.Boss and 26 or 8) + d)
	stalk.AnchorPoint = Vector2.new(0.5, 0)
	stalk.Parent = root
	Kit.Text(root, known and site.Def.Name or "???", { Size = UDim2.new(1, 20, 0, 20), Position = UDim2.new(0.5, 0, 1, -42), AnchorPoint = Vector2.new(0.5, 0), Stroke = 3, Shadow = 2, MaxSize = 20, ZIndex = 5, Color = site.Boss and C.OrangeHi or C.White })
	local status = Kit.Text(root, "", { Pixel = true, Size = UDim2.new(1, 20, 0, 11), Position = UDim2.new(0.5, 0, 1, -18), AnchorPoint = Vector2.new(0.5, 0), Stroke = 2, Shadow = 1, MaxSize = 11, ZIndex = 5 })
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 20
	hit.Parent = root
	hit.Activated:Connect(function() selectSite(site.Key) end)
	bb.Parent = player:WaitForChild("PlayerGui")
	return { Bill = bb, Anchor = anchor, Stroke = stroke, Status = status, Scale = sc, Boss = site.Boss, Hit = hit }
end

function View.ShowMap()
	local zone = state.Zone
	local era = zone and Config.Era(zone)
	if not era then return end
	state.Phase = "Map"
	View.HideMap()
	Drive.Freeze(true) -- (the rover waits while you look)
	map.Token = Cinema.Begin("DinoEraMap", "DinoToasts", "DinoCoach", "DinoBossEvent")
	map.Token.Long = true -- (the map stays up as long as you like: Cinema's 40 s safety would hand the HUD back over it)
	bossMusicOff() -- (back on the map: whatever fight you were in is behind you)
	if not map.Music then map.Music = true Audio.Push("Map") end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm and not map.Atmo then
		map.Atmo = { atm, atm.Density, atm.Haze }
		TweenService:Create(atm, TweenInfo.new(0.6), { Density = 0.08, Haze = 0 }):Play()
	end
	Drive.HoldCamera(true)
	local cam = Workspace.CurrentCamera
	map.SavedFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 50
	local gui, canvas = Kit.Screen("DinoEraMap", 22)
	map.Gui = gui
	map.Sites = siteKeys(era)
	-- a soft vignette over the 3D view (full screen, top bar included)
	local dimGui = Kit.Screen("DinoEraMapDim", 21, true)
	map.Dim = dimGui
	local vg = Instance.new("Frame")
	vg.BackgroundColor3 = C.Night
	vg.Size = UDim2.fromScale(1, 1)
	vg.Parent = dimGui:FindFirstChild("Root")
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.25) })
	grad.Parent = vg
	-- title + power + go home
	Kit.Text(canvas, era.Name, { Pixel = true, Size = UDim2.fromOffset(640, 44), Position = UDim2.new(0.5, 0, 0, 16), AnchorPoint = Vector2.new(0.5, 0), Color = era.Color:Lerp(Color3.new(1, 1, 1), 0.4), Color2 = era.Color, Stroke = 4, Shadow = 5, MaxSize = 40 }) -- the era name in the pixel font
	Kit.Text(canvas, era.Year .. "  -  TAP A SITE", { Pixel = true, Size = UDim2.fromOffset(500, 13), Position = UDim2.new(0.5, 0, 0, 70), AnchorPoint = Vector2.new(0.5, 0), Color = C.YellowHi, Stroke = 2, Shadow = 2, MaxSize = 13 })
	map.Power = Kit.Text(canvas, "", { Pixel = true, Size = UDim2.fromOffset(300, 13), Position = UDim2.new(1, -20, 0, 24), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Color = C.LimeHi, Stroke = 2, Shadow = 2, MaxSize = 13 })
	-- top left: GO HOME on the overview; BACK once a site is picked (returns to the whole era)
	map.HomeBtn = Kit.Button(canvas, { Text = "GO HOME", Icon = "Home", Color = "Red", Size = UDim2.fromOffset(180, 52), Position = UDim2.new(0, 20, 0, 20), ZIndex = 14, OnClick = function()
		View.HideMap()
		local res = Net.Ask("GoHome")
		if not (res and res.Ok) then View.ShowMap() end
	end })
	-- free roam: close the map and drive on
	map.DriveBtn = Kit.Button(canvas, { Text = "EXPLORE", Icon = "Jeep", Color = "Lime", Size = UDim2.fromOffset(190, 52), Position = UDim2.new(0, 210, 0, 20), ZIndex = 14, OnClick = function() View.StartRoam() end })
	map.BackBtn = Kit.Button(canvas, { Text = "BACK", Icon = "Map", Color = "Slate", Size = UDim2.fromOffset(160, 52), Position = UDim2.new(0, 20, 0, 20), ZIndex = 14, OnClick = function() map.Deselect() end })
	map.BackBtn.Visible = false
	map.Card = buildCard(canvas)
	map.Card.Outer.Visible = false
	map.Deselect = function()
		if not map.Card then return end
		map.Sel = nil
		map.Card.Key, map.Card.Mode = nil, nil
		map.Card.Outer.Visible = false
		for _, pin in pairs(map.Pins or {}) do pin.Sel = false end
		map.HomeBtn.Visible, map.BackBtn.Visible = true, false
		if map.DriveBtn then map.DriveBtn.Visible = true end
		focusOn(nil)
	end
	-- waypoints over the real map
	local folder = Instance.new("Folder")
	folder.Name = "DinoMapPins"
	folder.Parent = Workspace
	map.Folder = folder
	map.Pins = {}
	for _, s in ipairs(map.Sites) do
		local pin = buildPin(s, folder)
		if pin then map.Pins[s.Key] = pin end
	end
	-- the camera rises over the era
	map.CamGoal = overview()
	-- a camera left far away (or broken) by whatever played before must not crawl across the world, or never arrive
	local here = cam.CFrame.Position
	if not finite(here) or (here - map.CamGoal.Position).Magnitude > 600 then cam.CFrame = map.CamGoal end
	map.CamConn = RunService.RenderStepped:Connect(function(dt)
		if not map.CamGoal then return end
		local t = os.clock()
		local drift = CFrame.new(math.sin(t * 0.25) * 2, math.sin(t * 0.33) * 1.2, 0)
		local cur = cam.CFrame
		if not finite(cur.Position) then cur = map.CamGoal end
		cam.CFrame = cur:Lerp(map.CamGoal * drift, math.min(1, dt * 2.6))
		cam.FieldOfView += ((map.Fov or 50) - cam.FieldOfView) * math.min(1, dt * 3)
	end)
	-- gamepad / keyboard: cycle the sites, A / Enter goes
	ContextActionService:BindAction("DinoMapCycle", function(_, st, input)
		if st ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		local dir = (input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.Left) and -1 or 1
		local i = 1
		for k, s in ipairs(map.Sites) do if s.Key == map.Sel then i = k end end
		if map.Sel then i = (i - 1 + dir) % #map.Sites + 1 end
		selectSite(map.Sites[i].Key)
		if Kit.Gamepad() and map.Card.Buttons then
			local b = map.Card.Buttons:FindFirstChild("Hit", true)
			if b then game:GetService("GuiService").SelectedObject = b end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.Left, Enum.KeyCode.Right)
	ContextActionService:BindAction("DinoMapBack", function(_, st)
		if st ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if map.Sel then map.Deselect() else task.defer(View.StartRoam) end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace, Enum.KeyCode.M)
	refreshMap()
	if Kit.Gamepad() then task.delay(0.6, function() if map.Gui and map.Sites[1] then selectSite(map.Sites[1].Key) end end) end
end

function View.CoachTarget(): GuiObject?
	if not map.Gui then return nil end
	-- first the coach points at a waypoint, then at the card's GO! button
	if map.Card and map.Card.Outer.Visible then
		local b = map.FirstGo
		return (b and b.Parent) and b or nil
	end
	return nil
end

function View.MapOpen(): boolean
	return map.Gui ~= nil
end

-- before a site is picked the coach points at the first waypoint (a spot in the world, on screen)
function View.CoachPoint(): Vector2?
	if not map.Gui or (map.Card and map.Card.Outer.Visible) then return nil end
	local first = map.Sites and map.Sites[1] and map.Pins[map.Sites[1].Key]
	if not first then return nil end
	local sp, on = Workspace.CurrentCamera:WorldToViewportPoint(first.Anchor.Position)
	if not on then return nil end
	return Vector2.new(sp.X, sp.Y)
end

function View.HideMap()
	if map.CamConn then map.CamConn:Disconnect() map.CamConn = nil end
	ContextActionService:UnbindAction("DinoMapCycle")
	ContextActionService:UnbindAction("DinoMapBack")
	if map.Folder then map.Folder:Destroy() map.Folder = nil end
	for _, pin in pairs(map.Pins or {}) do pin.Bill:Destroy() end
	map.Pins = {}
	if map.Gui then map.Gui:Destroy() map.Gui = nil end
	if map.Dim then map.Dim:Destroy() map.Dim = nil end
	map.Card, map.Sel, map.FirstGo, map.CamGoal = nil, nil, nil, nil
	if map.Music then map.Music = nil Audio.Pop() end
	if map.Atmo then
		local a = map.Atmo
		map.Atmo = nil
		if a[1].Parent then TweenService:Create(a[1], TweenInfo.new(0.6), { Density = a[2], Haze = a[3] }):Play() end
	end
	if map.Token then
		Cinema.End(map.Token)
		map.Token = nil
		local cam = Workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = map.SavedFov or 70
		Drive.HoldCamera(false)
	end
end

local scopeOut -- forward

--------------------------------------------------------------------------------
-- 3. travel: the rover just DRIVES there (autopilot, real road, real physics) and the camera films it like a car ad,
-- cutting between shots. Time is cut two ways: the drive runs a bit faster than cruise, and a long trip skips its
-- middle once, under a quick blink to black (2026-10-11 rewrite: the old cut-and-teleport-every-shot version broke)
--------------------------------------------------------------------------------
function View.Travel(res, wasIdle: boolean)
	roamStop()
	Drive.SetRoam(false)
	state.Phase = "Travel"
	state.SiteKey = res.Site
	local St = Drive.State
	local stopS = res.S
	local cruiseWas = St.Cruise
	local done = nil -- TravelDone's answer, asked while the screen is still black (no pop at the end)
	scene(function(skipped)
		local cam = Workspace.CurrentCamera
		-- straight from camp (joining a boss fight), the warp lands before your rover has followed you into the
		-- era: hold black until there's a road and a rover on it, or the opening shots film the camp garage
		fade(1, 0)
		local tw = os.clock()
		while os.clock() - tw < 4 do
			local rv = St.Root or myRover()
			if St.Route and rv and rv.Parent then
				local onRoad = St.Route:Position(res.Variant, St.Route:Project(res.Variant, rv.Position), 0)
				if ((rv.Position - onRoad) * Vector3.new(1, 0, 1)).Magnitude < 60 or os.clock() - tw > 1.5 then break end
			end
			task.wait(0.1)
		end
		local era = Config.Era(state.Zone or "") :: any
		local sf0 = siteFolder(res.Site)
		local center = sf0 and sf0:GetAttribute("Center")
		local variant = res.Variant
		local route = St.Route
		Drive.Freeze(false)
		St.NoBoost = true -- (the trip drives itself at its own pace: no boosting through it)
		St.Autopilot = true
		St.LockVariant = variant
		St.StopAt = nil
		-- the road only runs one way: if the site is behind you (or right on top of you), start further back
		local s0 = St.S or 4
		local moved = false
		-- a chase may have left the rover on the other branch of a fork: put it on this site's road
		local startX = St.X or 0
		local function root(): BasePart? return St.Root or myRover() end
		if route and St.Variant ~= variant then
			local r0 = root()
			if r0 then s0 = route:Project(variant, r0.Position) end
			moved = true
		end
		if stopS - s0 < 120 then s0 = math.max(4, stopS - 200) moved = true startX = 0 end
		-- not on this road at all (still parked at camp, or at the far end of the map): start it on the road
		do
			local r1 = root()
			if route and (not r1 or (r1.Position - route:Position(variant, math.clamp(s0, 2, route:Length(variant) - 2), startX)).Magnitude > 40) then
				moved = true
			end
		end
		local function frame(): (CFrame, Vector3, Vector3)
			local r = root()
			local rc = r and r.CFrame or CFrame.new()
			local fwd = Vector3.new(rc.LookVector.X, 0, rc.LookVector.Z)
			fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
			return rc, fwd, fwd:Cross(Vector3.yAxis)
		end
		-- a point on the road itself (s along this variant, x across it) - camera spots always come from the road
		local function roadAt(s: number, x: number): Vector3
			if route then return route:Position(variant, math.clamp(s, 2, route:Length(variant) - 2), x) end
			local rc, fwd, side = frame()
			return rc.Position + fwd * (s - St.S) + side * x
		end
		local sideSign = (res.X or 0) >= 0 and -1 or 1
		-- how long the rover is (a Titan Transport is twice a Rookie Ranger): chase cams sit behind its bumper
		local rlen = 12
		do
			local r0 = root()
			local mdl = r0 and r0:FindFirstAncestorOfClass("Model")
			if mdl then local _, sz = mdl:GetBoundingBox() rlen = math.clamp(math.max(sz.X, sz.Z), 8, 30) end
		end
		-- start: under black if the rover has to be put somewhere else first, then let it settle on the road
		fade(1, 0.15)
		if moved then
			Drive.SetRoutePos(s0, startX, variant, 0)
			task.wait(0.35)
		end
		-- however the scene ends (arrived or skipped): under black, stop the rover and hand over to the site
		local function finish()
			fade(1, 0.2)
			task.wait(0.2)
			St.LockVariant = nil
			St.StopAt = stopS
			-- onto the server's park spot first: this client drives the rover, so if its road position were
			-- still back where a skip left it, the drive targets would drag the parked rover back there
			Drive.SetRoutePos(stopS, res.X or 0, variant, 0)
			done = Net.Ask("TravelDone")
			if done and done.Ok and not done.Chase then Audio.Play("CarDoor", { Volume = 0.9 }) end -- (out you get, under the black)
			task.wait(0.35) -- the server parks the rover and gets you out
		end
		St.Cruise = math.max(cruiseWas or 42, 52) -- a touch quicker than a normal drive
		local function dust()
			local rc, fwd = frame()
			DinosaurVFX.FootstepDust(rc.Position - fwd * 4 - Vector3.new(0, 1.5, 0), 0.9)
		end
		-- one shot: the rover keeps driving the whole time; place() frames it from wherever it is now
		local lastS, stuckFor = St.S, 0
		local function shot(dur: number, untilS: number, place: (u: number, rc: CFrame, fwd: Vector3, side: Vector3) -> (Vector3, Vector3, number))
			local t0 = os.clock()
			local nextDust = 0
			while os.clock() - t0 < dur and St.S < untilS and not skipped() do
				local dt = RunService.RenderStepped:Wait()
				local u = math.clamp((os.clock() - t0) / dur, 0, 1)
				local rc, fwd, side = frame()
				local pos, look, fov = place(u, rc, fwd, side)
				cam.CFrame = safeCam(CFrame.lookAt(pos, look), rc.Position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(math.noise(os.clock() * 4, 1) * 0.005, math.noise(os.clock() * 4, 5) * 0.007, 0)
				cam.FieldOfView = fov
				cineSubject = rc.Position
				if os.clock() > nextDust and St.Speed > 8 then nextDust = os.clock() + 0.18 dust() end
				-- never let it sit stuck on something: nudge it along the road
				if St.S - lastS < 0.05 then stuckFor += dt else stuckFor = 0 end
				lastS = St.S
				if stuckFor > 1.2 then stuckFor = 0 Drive.SetRoutePos(St.S + 10, 0, variant, St.Cruise * 0.6) end
			end
		end
		local arriveAt = stopS - 70 -- the arrival shot takes over here
		-- (joining from the Time Gate: if the rover still isn't on the road, don't film the world origin - skip the
		-- drive under black and go straight in. Tester report: "joining from the gate the cutscene goes crazy")
		if not root() or not route then finish() return end
		-- 1. PEEL OUT: low behind the back wheel as it pulls away
		fade(0, 0.25)
		-- (where you're going, nothing about what to do there: the picture shows it. 2026-10-14 show-don't-tell)
		card(era and era.Name or "", res.Name or "", nil, era and era.Color or C.Yellow)
		DinosaurVFX.DustWave((frame()).Position, -(select(2, frame())), 0.8)
		Audio.Play("Boost", { Volume = 0.8 })
		shot(2.2, arriveAt, function(u, rc, fwd, side)
			return rc.Position - fwd * (rlen * 0.5 + 3 + u * 5) + side * 4 * sideSign + Vector3.new(0, 1.2 + u * 0.8, 0), rc.Position + fwd * 16 + Vector3.new(0, 1.4, 0), 56 + u * 8
		end)
		hideCard()
		-- the middle of a long trip is skipped once, in a blink
		local function timeCut()
			local remain = arriveAt - St.S
			if remain < 260 or skipped() then return end
			fade(1, 0.1)
			task.wait(0.1)
			Drive.SetRoutePos(arriveAt - 190, 0, variant, St.Cruise)
			task.wait(0.3)
			fade(0, 0.15)
		end
		-- the middle: cycle tracking / drone / roadside / chase until the arrival
		local shots = {
			-- TRACKING: alongside at wheel height, matching its speed
			function()
				shot(2.4, arriveAt, function(u, rc, fwd, side)
					return rc.Position + side * 13 * sideSign - fwd * (3 - u * 6) + Vector3.new(0, 2.2, 0), rc.Position + fwd * 6 + Vector3.new(0, 1.6, 0), 52
				end)
			end,
			-- DRONE: high behind, the road winding away ahead
			function()
				shot(2.6, arriveAt, function(u, rc, fwd, side)
					return rc.Position - fwd * (30 - u * 8) + side * 7 + Vector3.new(0, 22 - u * 5, 0), rc.Position + fwd * 36, 62
				end)
			end,
			-- ROADSIDE: a camera planted at the verge ahead; it drives up and tears past
			function()
				local at = St.S + 52
				if at > arriveAt then return end
				local stand = roadAt(at, (route and route:HalfWidth(variant, at) or 12) * -sideSign + 3 * -sideSign) + Vector3.new(0, 2.4, 0)
				shot(2.4, arriveAt, function(u, rc)
					return stand, rc.Position + Vector3.new(0, 1.4, 0), 46
				end)
			end,
			-- CHASE: low and close behind, a little sway
			function()
				shot(2.2, arriveAt, function(u, rc, fwd, side)
					return rc.Position - fwd * (rlen * 0.5 + 9) + side * math.sin(u * 3) * 2 + Vector3.new(0, 3.6, 0), rc.Position + fwd * 20 + Vector3.new(0, 2, 0), 64
				end)
			end,
		}
		local k = 0
		local cutDone = false
		local t0 = os.clock()
		local progress, progressAt = St.S, os.clock()
		while St.S < arriveAt and not skipped() and os.clock() - t0 < 30 do
			k = k % #shots + 1
			shots[k]()
			if not cutDone and k == 2 then cutDone = true timeCut() end
			-- a rover that isn't getting anywhere (gone, stuck, not driven): stop filming it and arrive
			if St.S > progress + 5 then progress, progressAt = St.S, os.clock() end
			if os.clock() - progressAt > 4 or not root() then finish() return end
		end
		if skipped() then finish() return end
		-- ARRIVAL: it brakes to a stop in its own dust; the camera eases round to look past it at the site
		St.StopAt = stopS
		local park = roadAt(stopS, 0)
		local hwA = route and route:HalfWidth(variant, stopS) or 12
		-- (the rover parks at res.X across the road: the lens stands well clear of that spot, ahead of it)
		local parkAt = roadAt(stopS, res.X or 0)
		local all = { roadAt(stopS + 16, (hwA + 6) * sideSign) + Vector3.new(0, 2.4, 0), roadAt(stopS + 16, -(hwA + 6) * sideSign) + Vector3.new(0, 2.4, 0),
			roadAt(stopS + 22, 0) + Vector3.new(0, 5, 0), roadAt(stopS + 10, (hwA + 10) * sideSign) + Vector3.new(0, 6, 0), park + Vector3.new(0, 12, 0) }
		local cands = {}
		for _, c in ipairs(all) do
			if ((c - parkAt) * Vector3.new(1, 0, 1)).Magnitude > rlen * 0.5 + 6 then table.insert(cands, c) end
		end
		if #cands == 0 then cands = all end
		local spotA = clearSpot(cands, { roadAt(stopS - 20, 0) + Vector3.new(0, 2, 0) })
		local stoppedAt = nil
		local t1 = os.clock()
		while os.clock() - t1 < 7 and not skipped() do
			local rc = (root() or { CFrame = CFrame.new() } :: any).CFrame
			if not stoppedAt and St.Speed < 0.6 and St.S >= stopS - 1.5 then
				stoppedAt = os.clock()
				DinosaurVFX.FootstepDust(rc.Position - Vector3.new(0, 1.5, 0), 1.4)
			end
			local kk = stoppedAt and math.clamp((os.clock() - stoppedAt) / 1.2, 0, 1) or 0
			kk = kk * kk * (3 - 2 * kk)
			local look = rc.Position + Vector3.new(0, 1.6, 0)
			if typeof(center) == "Vector3" then look = look:Lerp(Vector3.new(center.X, rc.Position.Y + 2, center.Z), kk * 0.75) end
			cam.CFrame = safeCam(CFrame.lookAt(spotA + Vector3.new(0, kk * 2, 0), look), rc.Position)
			cam.FieldOfView = 50 - kk * 6
			cineSubject = look
			if stoppedAt and os.clock() - stoppedAt > 1.4 then break end
			RunService.RenderStepped:Wait()
		end
		hideCard()
		finish()
	end, { Hold = false, KeepCamera = true, HoldBlack = true })
	St.Cruise = cruiseWas -- back to normal driving speed
	St.LockVariant = nil
	St.NoBoost = nil
	if not done then -- (the scene didn't run: another was playing)
		St.StopAt = stopS
		Drive.SetRoutePos(stopS, res.X or 0, res.Variant, 0)
		done = Net.Ask("TravelDone")
	end
	if not (done and done.Ok) then
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		task.spawn(fade, 0, 0.3)
		Kit.Toast(done and done.Err or "COULDN'T REACH THE SITE", "Red", "Alert")
		View.StartRoam()
		return
	end
	if done.Chase then
		-- the boss is already on the run: you stay at the wheel and the chase picks up from here (ChaseStart)
		state.Phase = "Site"
		fade(0, 0.3)
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		return
	end
	state.Phase = "Site"
	Drive.SetOnFoot(true)
	local sf = siteFolder(res.Site)
	if sf and sf:GetAttribute("Boss") then
		fade(0, 0.3)
		local c0 = sf:GetAttribute("Center")
		handBack(typeof(c0) == "Vector3" and c0 or nil)
		return -- the ruler's den has its own scenes (BossArrive / BossIntro)
	end
	scopeOut(res.Site, res.Species, wasIdle)
end

--------------------------------------------------------------------------------
-- 4. at a site: scope it out (you, then the dino grazing, unbothered); when it SPOTS you, its signature intro
--------------------------------------------------------------------------------
local function leadCreature(key: string): (Model?, Configuration?)
	if not Exp then return nil, nil end
	local center = siteFolder(key) and (siteFolder(key) :: Configuration):GetAttribute("Center") or Vector3.zero
	local best, bestCfg, bd = nil, nil, math.huge
	for cfg, c in pairs(Exp.Creatures()) do
		if cfg:GetAttribute("Site") == key and not cfg:GetAttribute("Buddy") and not cfg:GetAttribute("Minion") and c.Model then
			local d = (c.Root.Position - center).Magnitude - (cfg:GetAttribute("Lead") and 1000 or 0)
			if d < bd then best, bestCfg, bd = c.Model, cfg, d end
		end
	end
	return best, bestCfg
end

-- the hero shot: the camera swings round in front of you as you raise the launcher; FIGHT!
local function heroShot(lookAt: Vector3?)
	scene(function(skipped)
		local root = hrp()
		if not root then return end
		local char = player.Character
		PlayerAnim.SetCombat(char, true)
		PlayerAnim.SetAim(char, 0.05, true)
		local face = root.CFrame.LookVector
		if lookAt then
			local d = Vector3.new(lookAt.X - root.Position.X, 0, lookAt.Z - root.Position.Z)
			if d.Magnitude > 1 then
				face = d.Unit
				root.CFrame = CFrame.lookAt(root.Position, root.Position + face)
			end
		end
		local right = face:Cross(Vector3.yAxis)
		local p = root.Position
		fade(0, 0.12)
		-- the face-off: low behind your shoulder, you on one side of frame, the dino filling the other
		local foe = lookAt and Vector3.new(lookAt.X, p.Y + 3, lookAt.Z) or (p + face * 20 + Vector3.new(0, 3, 0))
		local me = p + Vector3.new(0, 1.4, 0)
		local subject = me:Lerp(foe, 0.55)
		local spot = clearSpot({ me - face * 7 + right * 3.2 + Vector3.new(0, 0.8, 0), me - face * 7 - right * 3.2 + Vector3.new(0, 0.8, 0), me - face * 9 + Vector3.new(0, 3, 0) }, { me, foe })
		if nextVariant("Hero", 2) == 2 then
			-- the arena from above and behind: both of you, squared up
			spot = clearSpot({ me - face * 12 + right * 6 + Vector3.new(0, 9, 0), me - face * 12 - right * 6 + Vector3.new(0, 9, 0) }, { me, foe })
		end
		local a = CFrame.lookAt(spot - face * 1.5, subject)
		local b = CFrame.lookAt(spot + face * 1.2 + Vector3.new(0, -0.3, 0), subject)
		task.delay(0.35, function() PlayerAnim.Act(char, "Fire") end)
		task.delay(0.55, function()
			CineKit.Slam(cine.Gui, "FIGHT!", nil, C.YellowHi, 0.9)
			CineKit.ImpactFrame(0.6)
			Audio.Sting("Fight")
			flash(0.35)
			punch(6)
			DinosaurVFX.Shake(0.5, 0.25)
		end)
		move(a, b, 1.3, skipped, 52, 46, me)
	end)
end

scopeOut = function(key: string, species: string, fresh: boolean)
	local cam = Workspace.CurrentCamera
	-- (walking up to a nest you've never found plays its reveal first: the scope-out waits its turn instead of
	-- grabbing the camera back half-way through it)
	waitFree(10)
	local model = nil
	for _ = 1, 30 do
		model = leadCreature(key)
		if model then break end
		task.wait(0.05)
	end
	local sf = siteFolder(key)
	local center = sf and sf:GetAttribute("Center") or (model and model:GetPivot().Position) or Vector3.zero
	local spName = Config.Species[species] and (Config.Species[species] :: any).Name or species
	if not fresh or not model or (sf and sf:GetAttribute("Alarm")) then
		-- dropping into a fight that's already on: straight in
		if freeCam() then fade(0, 0.3) end
		local _ = spName
		state.JustFound = nil
		if not introOwed then task.spawn(function() Net.Ask("IntroDone") end) end
		return
	end
	scene(function(skipped)
		local root = hrp()
		if not root then return end
		local toSite = Vector3.new(center.X - root.Position.X, 0, center.Z - root.Position.Z)
		toSite = toSite.Magnitude > 1 and toSite.Unit or root.CFrame.LookVector
		root.CFrame = CFrame.lookAt(root.Position, root.Position + toSite)
		local right = toSite:Cross(Vector3.yAxis)
		-- A: you, crouched by the rover, looking out toward the nest
		local me = root.Position + Vector3.new(0, 1.2, 0)
		fade(0, 0.3)
		-- (no title here: the shot speaks for itself - you, hidden, the nest out ahead)
		-- wide and behind: you small in the corner of frame, the clearing and the nest out ahead
		local nestPt = center + Vector3.new(0, 3, 0)
		local midPt = me:Lerp(nestPt, 0.45)
		local spotA = clearSpot({
			me - toSite * 12 + right * 5 + Vector3.new(0, 4, 0), me - toSite * 12 - right * 5 + Vector3.new(0, 4, 0),
			me - toSite * 9 + Vector3.new(0, 8, 0), me - toSite * 6 + right * 8 + Vector3.new(0, 5, 0), me + Vector3.new(0, 12, 0) - toSite * 4,
		}, { me, nestPt })
		local a1 = CFrame.lookAt(spotA, midPt)
		local a2 = CFrame.lookAt(spotA + toSite * 2.5 - Vector3.new(0, 0.5, 0), midPt)
		move(a1, a2, 2.2, skipped, 54, 50, me)
		if skipped() then return end
		if state.JustFound == key then state.JustFound = nil hideCard() fade(1, 0.2) return end
		-- full the first time at a nest, short after: the long lens on the dino only on your first scope-out here
		if seen("Scope_" .. key) then hideCard() fade(1, 0.2) return end
		markSeen("Scope_" .. key)
		-- B: the long lens on the dino, grazing, no idea you're there
		local head = model and DinosaurVFX.findAttachment(model, "VFX_Head")
		local subj = head and head.WorldPosition or (center + Vector3.new(0, 3, 0))
		-- the long lens from where you're hiding: the dino a fair way off, framed whole, doing its own thing
		local body = model and model:GetPivot().Position or center
		local ext = model and select(2, model:GetBoundingBox()) -- (`and` would drop the second return)
		local size = ext and math.max(ext.X, ext.Y, ext.Z) or 10
		local lensSpots = {
			me + right * 2.5 + Vector3.new(0, 1.2, 0), me - right * 2.5 + Vector3.new(0, 1.2, 0),
			me + Vector3.new(0, 4, 0), me + right * 5 + Vector3.new(0, 3, 0), me - right * 5 + Vector3.new(0, 3, 0),
		}
		local lens = clearSpot(lensSpots, { subj, body + Vector3.new(0, 1, 0) }, model and { model } or nil)
		local dist = (subj - lens).Magnitude
		-- frame the whole animal: about 1.8x its size across the shot, never a tight face shot
		local fov = math.clamp(math.deg(2 * math.atan((size * 0.9) / math.max(dist, 1))), 18, 50)
		-- (no caption: the long lens, the stillness and the quiet say it hasn't seen you. 2026-10-14)
		hideCard()
		local t0 = os.clock()
		local aim = body:Lerp(subj, 0.5)
		while os.clock() - t0 < 2.8 and not skipped() do
			local u = (os.clock() - t0) / 2.8
			local h2 = model and model.Parent and DinosaurVFX.findAttachment(model, "VFX_Head")
			subj = h2 and h2.WorldPosition or subj
			body = model and model.Parent and model:GetPivot().Position or body
			aim = aim:Lerp(body:Lerp(subj, 0.5), 0.08)
			if model then cineKeep[model] = true end
			cineSubject = aim
			cam.CFrame = safeCam(CFrame.lookAt(lens + right * (0.8 - u * 1.6), aim), aim)
			cam.FieldOfView = fov * (1 - u * 0.08)
			RunService.RenderStepped:Wait()
		end
		hideCard()
		fade(1, 0.2)
	end, { KeepCamera = true, HoldBlack = true })
	if freeCam() then fade(0, 0.25) end
	if not introOwed then task.spawn(function() Net.Ask("IntroDone") end) end
end

-- SPOTTED: the first time a species catches you, its full signature intro; after that, a roar sting. Then FIGHT!
-- the site is frozen on the server until IntroDone, so this always ends by sending it, whatever happens
local spottedBusy = false
local function playSpotted(info)
	local key = state.SiteKey
	if not key then return end
	-- another scene still running (the SNEAK IN wrap-up, a hatch): let it finish first
	local t0 = os.clock()
	while (busy or DinosaurCinematics.IsPlaying()) and os.clock() - t0 < 8 do task.wait(0.1) end
	local live = nil
	if Exp then
		for cfg, c in pairs(Exp.Creatures()) do if cfg:GetAttribute("Id") == info.Actor then live = c.Model end end
	end
	live = live or leadCreature(key)
	if not live or not live.Parent then return end
	local species = info.Species or (live:GetAttribute("Species")) or ""
	local spName = Config.Species[species] and (Config.Species[species] :: any).Name or species
	local first = not seen("Intro_" .. species)
	local at = live:GetPivot()
	local played = false
	if first then
		-- the signature plays on a stand-in in the live one's spot: the server keeps updating the real
		-- model every frame, which would drag it (and the camera) around mid-move
		local feet = ground(at.Position)
		local yaw = Vector3.new(at.LookVector.X, 0, at.LookVector.Z)
		yaw = yaw.Magnitude > 0.01 and yaw.Unit or Vector3.new(0, 0, -1)
		local double = standIn(species, live:GetAttribute("AnimScale") or 1, CFrame.lookAt(feet, feet + yaw))
		if double then
			double:SetAttribute("DisplayName", spName)
			double:SetAttribute("Rarity", "")
			local parent = live.Parent
			live.Parent = nil
			played = playSignature(double)
			drop(double, true)
			if parent then live.Parent = parent end
		end
		-- (seen only once it really played: no template or no intro used to burn the first viewing on nothing)
		if played then markSeen("Intro_" .. species) end
	end
	if not played then
		scene(function(skipped)
			local root = hrp()
			cineKeep[live] = true
			local anim = DinosaurAnimations.get(live)
			local head = DinosaurVFX.findAttachment(live, "VFX_Head")
			local target = head and head.WorldPosition or (at.Position + Vector3.new(0, 4, 0))
			local from = root and root.Position or (target + Vector3.new(0, 4, 20))
			local dir = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
			dir = dir.Magnitude > 0.5 and dir.Unit or Vector3.new(0, 0, -1)
			local right = dir:Cross(Vector3.yAxis)
			fade(0, 0.1)
			if anim and anim:HasAction("Roar") then anim:Play("Roar") end
			stamp("SPOTTED!", C.RedHi, 1)
			Audio.Sting("Spotted")
			task.delay(0.35, function()
				burst(ground(at.Position) + Vector3.new(0, 1.5, 0), 0.9, nil)
				punch(7)
				CineKit.ImpactFrame(0.7)
				CineKit.HitStop(0.08)
			end)
			local _, ext = live:GetBoundingBox()
			local size = math.max(ext.X, ext.Y, ext.Z)
			local me = from + Vector3.new(0, 1.4, 0)
			local mid = me:Lerp(target, 0.6)
			local back = math.max((target - me).Magnitude * 0.9, size * 1.2) + 6
			local spot = clearSpot({
				mid + right * back + Vector3.new(0, 2, 0), mid - right * back + Vector3.new(0, 2, 0),
				me - dir * 8 + right * 4 + Vector3.new(0, 3, 0), mid + right * back * 0.7 + Vector3.new(0, 6, 0),
			}, { me, target }, { live })
			local v = nextVariant("Sting", 3)
			if v == 2 then
				-- over its shoulder: you, small, in front of something very big
				local behind = target + dir * (size * 0.5 + 4) + right * (size * 0.35) + Vector3.new(0, 2, 0)
				local s2 = clearSpot({ behind, target + dir * (size * 0.5 + 4) - right * (size * 0.35) + Vector3.new(0, 2, 0) }, { me }, { live })
				move(CFrame.lookAt(s2, me), CFrame.lookAt(s2 + (me - s2).Unit * 2, me), 1.4, skipped, 46, 40, me)
			elseif v == 3 then
				-- a whip pan: from your face to its roar
				-- (a clear lens: crouched behind a rock or a bush, the first pick put the camera inside it)
				local onMe = clearSpot({ me + dir * 5 + right * 1.5, me + dir * 5 - right * 1.5, me + dir * 3 + Vector3.new(0, 3, 0), me + Vector3.new(0, 5, 0) }, { me, target }, { live })
				local t0 = os.clock()
				local cam = Workspace.CurrentCamera
				while os.clock() - t0 < 1.4 and not skipped() do
					local u = math.clamp((os.clock() - t0 - 0.4) / 0.35, 0, 1)
					local e = u * u * (3 - 2 * u)
					cam.CFrame = safeCam(CFrame.lookAt(onMe, me:Lerp(target, e)), me)
					cam.FieldOfView = 44 + e * 10
					RunService.RenderStepped:Wait()
				end
			else
				local push = (mid - spot).Unit * 3
				move(CFrame.lookAt(spot, mid), CFrame.lookAt(spot + push, mid:Lerp(target, 0.3)), 1.4, skipped, 50, 44, mid)
			end
		end)
	end
	heroShot(live.Parent and live:GetPivot().Position or at.Position)
end

local function spotted(info)
	if spottedBusy then return end
	spottedBusy = true
	local ok, err = pcall(playSpotted, info)
	if not ok then warn("[EraView] spotted:", err) end
	freeCam()
	spottedBusy = false
	introOwed = false
	task.spawn(function() Net.Ask("IntroDone") end)
end

-- DRIVE OFF: a 1.4 second beat as the chase begins (the rover keeps driving underneath it)
function View.EscapeBeat(withEggs: number?)
	Audio.Push("Chase")
	if busy then return end
	task.spawn(function()
		scene(function(skipped)
			local St = Drive.State
			local root = St.Root or myRover()
			if not root then return end
			local cam = Workspace.CurrentCamera
			local rc = root.CFrame
			local fwd = Vector3.new(rc.LookVector.X, 0, rc.LookVector.Z).Unit
			local side = fwd:Cross(Vector3.yAxis)
			local v = nextVariant("Escape", 2)
			-- 1: low at the roadside as the rover tears past; 2: behind the chasers, the rover ahead of them
			local spot = v == 1 and (rc.Position + fwd * 26 + side * 7 + Vector3.new(0, 1.4, 0)) or (rc.Position - fwd * 30 + side * 3 + Vector3.new(0, 5, 0))
			spot = clearSpot({ spot, rc.Position + fwd * 26 - side * 7 + Vector3.new(0, 1.4, 0) }, { rc.Position })
			fade(0, 0.08)
			DinosaurVFX.DustWave(rc.Position, -fwd, 1)
			task.delay(0.25, function()
				Audio.Sting("Escape")
				CineKit.SpeedLines(cine.Gui, 1.3)
				-- (what you've got, not what to do: the road and the portal marker show the way. 2026-10-14)
				CineKit.Slam(cine.Gui, "ESCAPE!", (withEggs and withEggs > 0) and (withEggs .. (withEggs == 1 and " EGG ON BOARD" or " EGGS ON BOARD")) or nil, C.YellowHi, 1.3, 0.24)
				CineKit.Punch(7)
			end)
			local t0 = os.clock()
			while os.clock() - t0 < 1.4 and not skipped() do
				local r = St.Root or root
				local look = r.Position + Vector3.new(0, 1.5, 0)
				cam.CFrame = safeCam(CFrame.lookAt(spot, look), look) * CFrame.Angles(math.noise(os.clock() * 5, 1) * 0.01, math.noise(os.clock() * 5, 4) * 0.01, 0)
				cam.FieldOfView = v == 1 and 52 or 60
				RunService.RenderStepped:Wait()
			end
		end, { Hold = false })
	end)
end

-- MADE IT: the rover hits the time portal; a low chase shot into the light, ESCAPED! over the rays
function View.ExtractBeat(eggs: number)
	Audio.Pop()
	if busy then return end
	task.spawn(function()
		scene(function(skipped)
			local root = Drive.State.Root or myRover()
			if not root then return end
			local cam = Workspace.CurrentCamera
			local rc = root.CFrame
			local fwd = Vector3.new(rc.LookVector.X, 0, rc.LookVector.Z).Unit
			local spot = rc.Position - fwd * 9 + Vector3.new(0, 1.2, 0) + fwd:Cross(Vector3.yAxis) * 2
			fade(0, 0.05)
			flash(0.5)
			Audio.Sting("Escaped")
			CineKit.SpeedLines(cine.Gui, 1.4, Color3.fromRGB(255, 236, 170))
			CineKit.SunBurst(1)
			CineKit.Stamp(cine.Gui, "ESCAPED!", eggs > 0 and (eggs .. (eggs == 1 and " EGG" or " EGGS") .. " SAFE") or "MADE IT HOME", C.YellowHi, 1.6, 0.26)
			CineKit.Sparkle(rc.Position + Vector3.new(0, 4, 0), C.YellowHi, 1.6)
			CineKit.Punch(10)
			local t0 = os.clock()
			while os.clock() - t0 < 1.7 and not skipped() do
				local r = Drive.State.Root or root
				local u = (os.clock() - t0) / 1.7
				cam.CFrame = safeCam(CFrame.lookAt(spot + fwd * (u * 6), r.Position + fwd * 12 + Vector3.new(0, 2, 0)), r.Position + Vector3.new(0, 2, 0))
				cam.FieldOfView = 60 + u * 25
				RunService.RenderStepped:Wait()
			end
			fade(1, 0.15)
		end, { Hold = false })
	end)
end

-- LOST THEM! (2026-10-14, user: "allow for driving with an egg and not going to the exit gate so you can get more
-- eggs"): the pack gave up (server Expedition.loseTick). The wheel's yours again first - free driving from right
-- where the road had the rover, still rolling - then a 1.8 s beat over it: a tracking shot from up ahead, the rover
-- (eggs on the rack) coming at the lens and the pack peeling off small behind it. No words but the stamp: the pins,
-- the portal marker and the rack say what's next. info: { Eggs, Slots, Rider }
function View.LostBeat(info)
	info = typeof(info) == "table" and info or {}
	Audio.Remove("Chase")
	local eggs, slots = tonumber(info.Eggs) or 0, tonumber(info.Slots) or 0
	if info.Rider then
		-- riding along: no wheel to hand over, just the moment
		if hud and hud.Banner then hud.Banner("LOST THEM!", nil, "Jeep", C.LimeHi) end
		return
	end
	local okR, errR = pcall(View.StartRoam)
	if not okR then warn("[EraView] lost them - roam:", errR) end
	if busy then return end
	task.spawn(function()
		scene(function(skipped)
			local root = Drive.State.Root or myRover()
			if not root then return end
			local cam = Workspace.CurrentCamera
			local me = player.UserId
			-- where your pack is (they jog off for a few seconds, then go)
			local function pack(): Vector3?
				local sum, n = Vector3.zero, 0
				for _, cfg in ipairs(Runtime.Chasers:GetChildren()) do
					local p = cfg:GetAttribute("P")
					if cfg:GetAttribute("Owner") == me and typeof(p) == "Vector3" then sum += p n += 1 end
				end
				return n > 0 and sum / n or nil
			end
			local rc0 = root.CFrame
			local side0 = Vector3.new(rc0.LookVector.X, 0, rc0.LookVector.Z).Unit:Cross(Vector3.yAxis)
			local sideSign = (nextVariant("Lost", 2) == 1) and 1 or -1
			fade(0, 0.08)
			task.delay(0.15, function()
				Audio.Sting("Escaped", 0.5)
				-- (what you've got, never what to do next)
				local sub = eggs > 0 and (slots > 0 and string.format("%d/%d EGGS ON BOARD", eggs, slots) or (eggs .. (eggs == 1 and " EGG ON BOARD" or " EGGS ON BOARD"))) or nil
				CineKit.Stamp(cine.Gui, "LOST THEM!", sub, C.LimeHi, 1.4, 0.26)
				CineKit.Punch(6)
			end)
			local t0 = os.clock()
			while os.clock() - t0 < 1.8 and not skipped() do
				local r = Drive.State.Root or root
				local rc = r.CFrame
				local fl = Vector3.new(rc.LookVector.X, 0, rc.LookVector.Z)
				local fwd = fl.Magnitude > 0.01 and fl.Unit or Vector3.new(0, 0, -1)
				local u = (os.clock() - t0) / 1.8
				-- (high and behind, rising - you're still at the wheel, so left stays left on screen; the pack drops away
				-- under the lens as the rover pulls clear. It faced the rover before, and steering read backwards)
				local eye = rc.Position - fwd * (12 + u * 6) + side0 * sideSign * 4 + Vector3.new(0, 8 + u * 6, 0)
				local look = rc.Position + fwd * (10 + u * 6) + Vector3.new(0, 1, 0)
				local _ = pack
				cineSubject = rc.Position
				cam.CFrame = safeCam(CFrame.lookAt(eye, look), rc.Position + Vector3.new(0, 1.5, 0))
				cam.FieldOfView = 56 - u * 4
				RunService.RenderStepped:Wait()
			end
		end, { Hold = false })
	end)
end

--------------------------------------------------------------------------------
-- 5. arrival entry point (ExpeditionView calls this when the warp lands)
--------------------------------------------------------------------------------
local function arriveInner(info, pendingSite: string?)
	state.Zone = info.Zone
	state.Phase = "Arriving"
	Drive.Freeze(true)
	if pendingSite then
		-- joined a ruler event from camp: straight to the den
		local res = Net.Ask("ChooseSite", { Site = pendingSite })
		if res and res.Ok then
			View.Travel(res, false)
			return
		end
	end
	local key = "Est_" .. info.Zone
	local okE, errE = pcall(View.Establish, info.Zone, not seen(key))
	if not okE then warn("[EraView] establishing shots:", errE) end
	markSeen(key)
	-- the very first expedition is picked for you: one Triceratops at Horn Meadow, easy to read
	local p = Net.Profile
	-- (once: Runs only counts extractions, so a faint or wreck on the first hunt used to replay it on every trip)
	if p and p.Stats and (p.Stats.Runs or 0) == 0 and not seen("FirstHunt") and info.Zone == "FernValley" then
		-- (no banner: it flashed up for a second and the reveal hid it again. The reveal, the drive and the nest
		-- show what this is. 2026-10-14 show-don't-tell)
		task.wait(0.4)
		if not seen("Found_FernValley/HornNest") and discover then discover("FernValley/HornNest") end
		local res = Net.Ask("ChooseSite", { Site = "FernValley/HornNest" })
		if res and res.Ok then
			markSeen("FirstHunt")
			local okT, errT = pcall(View.Travel, res, true)
			if not okT then warn("[EraView] first hunt travel:", errT) end
			return
		end
		warn("[EraView] first hunt: ChooseSite refused", res and res.Err)
	end
	if View.BeforeMap then pcall(View.BeforeMap, info.Zone) end -- Foreshadow: the boss's roar on your 2nd trip
	-- (free roam: out of the portal and driving; the map is a button now. If starting it fails for any reason, the
	-- era map instead - never a frozen camera in the last shot's spot)
	local ok, err = pcall(View.StartRoam)
	if not ok then
		warn("[EraView] free roam failed to start:", err)
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		fade(0, 0.3)
		View.ShowMap()
	end
end

function View.Arrive(info, pendingSite: string?)
	state.Arriving = true
	local ok, err = pcall(arriveInner, info, pendingSite)
	state.Arriving = false
	if not ok then error(err, 0) end
end

-- back from a site (or after a chase that didn't end the run)
function View.BackToMap()
	local res = Net.Ask("BackToMap")
	if res and res.Ok then
		state.Phase = "Map"
		state.SiteKey = nil
		View.StartRoam() -- (back at the wheel, exploring)
	elseif res and res.Err then
		Kit.Toast(res.Err, "Orange", "Egg")
	end
end

function View.Reset()
	bossMusicOff()
	introOwed = false
	state.JustFound = nil
	if View.RideEnd then View.RideEnd() end
	roamStop()
	state.Zone, state.Phase, state.SiteKey = nil, "None", nil
	if sleeper.Model then sleeper.Model:Destroy() sleeper.Model = nil end
	View.HideMap()
end

function View.Phase(): string
	return state.Phase
end

--------------------------------------------------------------------------------
-- 6. rulers
--------------------------------------------------------------------------------
local eventPop = nil
local function bossEventPopup(info)
	if eventPop then eventPop:Destroy() eventPop = nil end
	local profile = Net.Profile
	local unlocked = profile and profile.Unlocked and profile.Unlocked[info.Era]
	local gui, canvas = Kit.Screen("DinoBossEvent", 24, false, 0.85)
	eventPop = gui
	local boss = Config.Bosses[info.Boss] :: any
	if not unlocked then gui:Destroy() eventPop = nil return end -- an era you can't reach yet isn't news
	local outer, content = Kit.Card(canvas, { Size = UDim2.fromOffset(470, 132), Position = UDim2.new(0.5, 0, 0, 96), AnchorPoint = Vector2.new(0.5, 0), Color = "Forest", Border = C.OrangeHi, ZIndex = 10 })
	Kit.Icon(content, "Dino", { Species = boss.Species, Size = UDim2.fromOffset(118, 118), Position = UDim2.new(0, -12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 16, Rotation = -6 })
	Kit.Text(content, info.By and (string.upper(info.By) .. " SUMMONED") or "BOSS EVENT", { Pixel = true, Size = UDim2.new(1, -130, 0, 12), Position = UDim2.fromOffset(112, 12), Align = Enum.TextXAlignment.Left, Color = C.YellowHi, Stroke = 2, Shadow = 2, ZIndex = 16, MaxSize = 12 })
	Kit.Text(content, boss.Name .. " AWAKES!", { Size = UDim2.new(1, -130, 0, 34), Position = UDim2.fromOffset(112, 28), Align = Enum.TextXAlignment.Left, Color = C.OrangeHi, Stroke = 4, Shadow = 4, ZIndex = 16, MaxSize = 34 })
	local timer = Kit.Text(content, "", { Pixel = true, Size = UDim2.new(1, -130, 0, 11), Position = UDim2.fromOffset(112, 66), Align = Enum.TextXAlignment.Left, Color = C.Cream, Stroke = 2, Shadow = 2, ZIndex = 16, MaxSize = 11 })
	local canJoin = unlocked and not (Net.Profile and (Drive.State.Mode == "Route" or Drive.State.Mode == "Roam"))
	local joining = false
	local function joinNow()
		if joining or not gui.Parent then return end
		joining = true
		local res = Net.Ask("JoinBoss", { Boss = info.Boss })
		joining = false
		if res and res.Ok then
			if eventPop then eventPop:Destroy() eventPop = nil end
		else
			Kit.Toast(res and res.Err or "CAN'T JOIN", "Red", "Alert")
		end
	end
	Kit.Button(content, { Text = canJoin and "JOIN!" or (unlocked and "FROM THE ERA MAP" or "ERA LOCKED"), Color = canJoin and "Orange" or "Grey", Disabled = not canJoin, Size = UDim2.fromOffset(canJoin and 140 or 220, 40), Position = UDim2.new(0, 112, 1, -48), ZIndex = 17, MaxText = 22, OnClick = joinNow })
	-- gamepad: D-pad left joins while the card is up (it pops up by itself: grabbing GUI focus would take the stick)
	if canJoin and Kit.Gamepad() then
		Kit.Text(content, "D-PAD LEFT", { Pixel = true, Size = UDim2.fromOffset(140, 10), Position = UDim2.new(0, 112, 1, -6), Color = C.YellowHi, Stroke = 2, Shadow = 1, ZIndex = 17, MaxSize = 10 })
		ContextActionService:BindActionAtPriority("DinoBossEventJoin", function(_, st)
			if st == Enum.UserInputState.Begin then task.spawn(joinNow) end
			return Enum.ContextActionResult.Sink
		end, false, 2160, Enum.KeyCode.DPadLeft)
		gui.Destroying:Connect(function() ContextActionService:UnbindAction("DinoBossEventJoin") end)
	end
	Kit.Button(content, { Glyph = "X", Color = "Red", Size = UDim2.fromOffset(40, 38), Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), ZIndex = 18, OnClick = function()
		if eventPop then eventPop:Destroy() eventPop = nil end
	end })
	Kit.Pop(outer, 0.4)
	DinosaurVFX.Shake(0.5, 0.4)
	local untilT = os.clock() + (info.Until or 120)
	task.spawn(function()
		while gui.Parent and os.clock() < untilT do
			Kit.SetText(timer, "JOIN IN " .. fmtTime(untilT - os.clock()) .. "  -  TIER " .. (info.Tier or "NORMAL"))
			task.wait(0.5)
		end
		if gui.Parent then gui:Destroy() end
		if eventPop == gui then eventPop = nil end
	end)
end

local function bossModel(actorId: number?): (Model?, any)
	if not Exp then return nil, nil end
	-- (the den's own boss first: a teammate still driving the chase has a "boss" chaser of their own out on the road)
	local fallback, fallbackCfg = nil, nil
	for cfg, c in pairs(Exp.Creatures()) do
		if actorId and cfg:GetAttribute("Id") == actorId then return c.Model, cfg end
		if not actorId and cfg:GetAttribute("Boss") then
			if cfg:GetAttribute("Site") then return c.Model, cfg end
			fallback, fallbackCfg = fallback or c.Model, fallbackCfg or cfg
		end
	end
	return fallback, fallbackCfg
end

local function bossIntroWith(bossId: string, tierName: string, model: Model?, zone: string?)
	local boss = Config.Bosses[bossId] :: any
	-- 1. MYSTERY: the den goes dark; something on the throne, only its eyes and its pack's eyes showing
	local hidden = {}
	local function silhouette(m: Model)
		local h = Instance.new("Highlight")
		h.Name = "DinoSilhouette"
		h.FillColor = Color3.new(0, 0, 0)
		h.FillTransparency = 0
		h.OutlineColor = Color3.fromRGB(40, 10, 10)
		h.OutlineTransparency = 0.6
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = m
		table.insert(hidden, h)
		DinosaurVFX.EyeGlow(m, 6)
	end
	if model then silhouette(model) end
	if Exp then
		for cfg, c in pairs(Exp.Creatures()) do
			if c.Model and c.Model ~= model and cfg:GetAttribute("Site") == state.SiteKey then silhouette(c.Model) end
		end
	end
	local dark = Instance.new("ColorCorrectionEffect")
	dark.Name = "DinoBossDark"
	dark.Parent = Lighting
	TweenService:Create(dark, TweenInfo.new(0.8), { Brightness = -0.16, Saturation = -0.55, Contrast = 0.25, TintColor = Color3.fromRGB(190, 200, 255) }):Play()
	local center = marker(zone, "DenCenter")
	local subject = model and model.Parent and model:GetPivot().Position or (center and center.Position) or Vector3.zero
	local headAtt = model and DinosaurVFX.findAttachment(model, "VFX_Head")
	local head = headAtt and headAtt.WorldPosition or (subject + Vector3.new(0, 5, 0))
	scene(function(skipped)
		local root = hrp()
		local from = root and root.Position or (subject + Vector3.new(0, 4, 40))
		local dir = Vector3.new(subject.X - from.X, 0, subject.Z - from.Z)
		dir = dir.Magnitude > 1 and dir.Unit or Vector3.new(0, 0, -1)
		local right = dir:Cross(Vector3.yAxis)
		local d = (subject - from).Magnitude
		fade(0, 0.6)
		-- a slow creep toward the throne, low, with a heartbeat
		local a1 = CFrame.lookAt(subject - dir * math.max(26, d * 0.8) + right * 4 + Vector3.new(0, 2, 0), head)
		local a2 = CFrame.lookAt(subject - dir * math.max(18, d * 0.55) + right * 2 + Vector3.new(0, 2.5, 0), head)
		task.delay(0.6, function() DinosaurVFX.Shake(0.35, 0.2) end)
		task.delay(1.5, function() DinosaurVFX.Shake(0.5, 0.25) end)
		move(a1, a2, 2.6, skipped, 48, 40, head)
		hideCard()
		if skipped() then return end
		-- tight on the eyes in the dark
		local e1 = CFrame.lookAt(head - dir * 9 + Vector3.new(0, 0.4, 0), head)
		local e2 = CFrame.lookAt(head - dir * 6.5 + Vector3.new(0, 0.2, 0), head)
		move(e1, e2, 1, skipped, 34, 28, head)
	end, { KeepCamera = true })
	-- 2. REVEAL: light floods back with a storm of blocks, her name over the rays... then she shows you who rules here
	for _, h in ipairs(hidden) do h:Destroy() end
	TweenService:Create(dark, TweenInfo.new(0.25), { Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	task.delay(0.4, function() dark:Destroy() end)
	if model and model.Parent then
		scene(function(skipped)
			local p = model:GetPivot().Position
			local _, e = model:GetBoundingBox()
			local size = math.max(e.X, e.Y, e.Z)
			local root = hrp()
			local from = root and root.Position or (p + Vector3.new(0, 0, 40))
			local d = Vector3.new(p.X - from.X, 0, p.Z - from.Z)
			d = d.Magnitude > 1 and d.Unit or Vector3.new(0, 0, -1)
			local r = d:Cross(Vector3.yAxis)
			local subj = p + Vector3.new(0, e.Y * 0.45, 0)
			local spot = clearSpot({ p - d * (size * 1.3 + 8) + r * (size * 0.5) + Vector3.new(0, 1.5, 0), p - d * (size * 1.3 + 8) - r * (size * 0.5) + Vector3.new(0, 1.5, 0) }, { subj }, { model })
			flash(0.9)
			CineKit.BigHit(cine.Gui, 1.4)
			slamBars()
			burst(p + Vector3.new(0, e.Y * 0.3, 0) - d * (size * 0.3), math.clamp(size / 10, 1.2, 3), { boss.Color or C.OrangeHi, LEAF[1], LEAF[2], LEAF[3] })
			local era = Config.Era(zone or state.Zone or "") :: any
			rayTitle(boss.Name, era and ("BOSS OF " .. era.Name) or "THE BOSS", boss.Color or C.OrangeHi, 2.0)
			local cam = Workspace.CurrentCamera
			local t0 = os.clock()
			cam.FieldOfView = 58
			punch(10)
			while os.clock() - t0 < 2.0 and not skipped() do
				local u = (os.clock() - t0) / 2
				cam.CFrame = CFrame.lookAt(spot:Lerp(subj, u * 0.12), subj) * CFrame.Angles(math.noise(u * 6, 2) * 0.01, math.noise(u * 6, 5) * 0.012, 0)
				RunService.RenderStepped:Wait()
			end
		end, { KeepCamera = true })
	end
	if model and model.Parent then
		model:SetAttribute("DisplayName", boss.Name)
		model:SetAttribute("Rarity", "")
		model:SetAttribute("SignatureMove", tierName)
		fade(0, 0.05)
		playSignature(model)
	end
	-- 3. you, launcher up: FIGHT!
	local r = hrp()
	if r and model and model.Parent and (r.Position - model:GetPivot().Position).Magnitude < 160 then
		heroShot(model:GetPivot().Position)
	else
		scene(function(skipped)
			local cam = Workspace.CurrentCamera
			local look = model and model.Parent and model:GetPivot().Position or subject
			fade(0, 0.1)
			stamp("FIGHT!", C.YellowHi, 0.9)
			Audio.Sting("Fight")
			flash(0.5)
			cam.CFrame = safeCam(CFrame.lookAt(look + Vector3.new(22, 6, 22), look + Vector3.new(0, 6, 0)), look + Vector3.new(0, 6, 0))
			hold(0.9, skipped)
		end)
	end
	freeCam()
end

--------------------------------------------------------------------------------
-- the sea ruler's scenes (Config.Bosses[id].Water): the Tidebreaker in the Sea Mouth. No captions while it's a
-- mystery: a shadow under the docks, a fin, the water boiling, then it breaches clean out of the bay.
--------------------------------------------------------------------------------
local function seaWaterY(zone: string?): number
	local z = zone and Workspace:FindFirstChild(zone)
	return z and z:GetAttribute("WaterY") or 0
end

local function boil(at: Vector3, dur: number, r: number)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(r * 1.6, 0.4, r * 1.6)
	p.Position = at + Vector3.new(0, 0.2, 0)
	p.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 120
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(3, 7)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Top
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.2) })
	e.Color = ColorSequence.new(Color3.fromRGB(225, 248, 255))
	e.Parent = p
	task.delay(dur, function() e.Enabled = false task.delay(1.2, function() p:Destroy() end) end)
end

local function hideModel(m: Model?, hidden: boolean)
	if not m then return end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then (d :: any).LocalTransparencyModifier = hidden and 1 or 0 end
	end
end

local function seaIntroWith(bossId: string, tierName: string, model: Model?, zone: string?)
	local boss = Config.Bosses[bossId] :: any
	local wy = seaWaterY(zone)
	local bay = marker(zone, "BayCenter")
	local c = bay and Vector3.new(bay.Position.X, wy, bay.Position.Z) or (model and model:GetPivot().Position or Vector3.zero)
	local s, anim = standIn(boss.Species, boss.Scale or 1, CFrame.new(c + Vector3.new(18, -14, 0)))
	if not s then return end
	hideModel(model, true)
	local _, ext = s:GetBoundingBox()
	local H = ext.Y
	local sroot = s.PrimaryPart :: BasePart
	local function place(p: Vector3, yaw: number, pitch: number?)
		local bb, size = s:GetBoundingBox()
		local lift = sroot.Position.Y - (bb.Position.Y - size.Y / 2)
		sroot.CFrame = CFrame.new(p + Vector3.new(0, lift, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch or 0, 0, 0)
	end
	if anim then anim:SetLocomotion("Run", 0.1) end
	-- the shadow: pure black, only its eyes
	local sil = Instance.new("Highlight")
	sil.FillColor = Color3.new(0, 0, 0)
	sil.FillTransparency = 0.05
	sil.OutlineTransparency = 1
	sil.DepthMode = Enum.HighlightDepthMode.Occluded
	sil.Parent = s
	DinosaurVFX.EyeGlow(s, 7)
	local dark = Instance.new("ColorCorrectionEffect")
	dark.Name = "DinoBossDark"
	dark.Parent = Lighting
	TweenService:Create(dark, TweenInfo.new(0.8), { Brightness = -0.12, Saturation = -0.45, Contrast = 0.22, TintColor = Color3.fromRGB(170, 210, 255) }):Play()
	local root = hrp()
	local from = root and root.Position or (c + Vector3.new(0, 4, 50))
	local toward = Vector3.new(c.X - from.X, 0, c.Z - from.Z)
	toward = toward.Magnitude > 1 and toward.Unit or Vector3.new(0, 0, -1)
	local right = toward:Cross(Vector3.yAxis)
	local circleR = 20
	scene(function(skipped)
		fade(0, 0.6)
		-- 1. high over the bay: a long dark shape slides under the docks
		local t0 = os.clock()
		local a1 = CFrame.lookAt(c - toward * 40 + right * 10 + Vector3.new(0, 46, 0), c)
		local a2 = CFrame.lookAt(c - toward * 30 + right * 4 + Vector3.new(0, 34, 0), c)
		task.spawn(function()
			while os.clock() - t0 < 2.8 and not skipped() do
				local a = (os.clock() - t0) * 0.9
				local p = c + Vector3.new(math.cos(a) * circleR, -H * 0.85, math.sin(a) * circleR)
				place(p, math.atan2(math.sin(a), -math.cos(a)) + math.pi)
				RunService.RenderStepped:Wait()
			end
		end)
		move(a1, a2, 2.8, skipped, 52, 46, c)
		if skipped() then return end
		-- 2. down on the pier: the fin cuts past, the planks shudder, the middle of the bay starts to boil
		local eye = c - toward * 30 + Vector3.new(0, 4.2, 0)
		local t1 = os.clock()
		boil(c, 2.2, 7)
		task.delay(0.4, function() DinosaurVFX.Shake(0.4, 0.25) end)
		task.delay(1.3, function() DinosaurVFX.Shake(0.6, 0.3) end)
		task.spawn(function()
			while os.clock() - t1 < 2.0 and not skipped() do
				local a = 1.4 + (os.clock() - t1) * 1.3
				local p = c + Vector3.new(math.cos(a) * 14, -H * 0.62, math.sin(a) * 14)
				place(p, math.atan2(math.sin(a), -math.cos(a)) + math.pi)
				RunService.RenderStepped:Wait()
			end
		end)
		move(CFrame.lookAt(eye, c + Vector3.new(0, 1, 0)), CFrame.lookAt(eye + toward * 4, c + Vector3.new(0, 0.5, 0)), 2.0, skipped, 44, 38, c)
	end, { KeepCamera = true })
	-- 3. it breaches: light floods back, the name over the rays
	sil:Destroy()
	TweenService:Create(dark, TweenInfo.new(0.25), { Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	task.delay(0.4, function() dark:Destroy() end)
	scene(function(skipped)
		local cam = Workspace.CurrentCamera
		local low = c - toward * 26 + right * 6 + Vector3.new(0, 3.4, 0)
		fade(0, 0.05)
		flash(0.9)
		CineKit.BigHit(cine.Gui, 1.4)
		slamBars()
		DinosaurVFX.WaterSplash(c, 3)
		burst(c + Vector3.new(0, 4, 0) - toward * 6, 2.6, { boss.Color or C.TealHi, Color3.fromRGB(235, 250, 255), Color3.fromRGB(120, 200, 240), LEAF[1] })
		local era = Config.Era(zone or state.Zone or "") :: any
		rayTitle(boss.Name, era and ("BOSS OF " .. era.Name) or "THE BOSS", boss.Color or C.TealHi, 2.2)
		punch(12)
		if anim then anim:Play("Roar") end
		local t0 = os.clock()
		local D = 2.3
		local yaw = math.atan2(-(-toward).X, -(-toward).Z)
		local slowed = false
		while os.clock() - t0 < D and not skipped() do
			local u = (os.clock() - t0) / D
			-- up out of the water, hang at the top (slow motion), then the crash
			local arc = math.sin(math.clamp(u / 0.8, 0, 1) * math.pi)
			local p = c + Vector3.new(0, -H * 0.9 + arc * (H * 1.7 + 8), 0)
			place(p, yaw, 1.15 - u * 1.9)
			if not slowed and u > 0.32 then slowed = true CineKit.HitStop(0.5, 0.25, 0.6) end
			local subj = p + Vector3.new(0, H * 0.6, 0)
			cam.CFrame = CFrame.lookAt(low + Vector3.new(0, u * 2, 0), subj) * CFrame.Angles(math.noise(u * 5, 1) * 0.012, math.noise(u * 5, 4) * 0.014, 0)
			cam.FieldOfView = 62 - u * 10
			cineSubject = subj
			RunService.RenderStepped:Wait()
		end
		DinosaurVFX.WaterSplash(c, 3.4)
		DinosaurVFX.Shake(0.9, 0.5)
		CineKit.Punch(8)
		hold(0.5, skipped)
	end, { KeepCamera = true })
	drop(s, true)
	hideModel(model, false)
	-- 4. you, launcher up: FIGHT!
	local r = hrp()
	if r and model and model.Parent then heroShot(model:GetPivot().Position) else heroShot(c) end
	freeCam()
	local _ = tierName
end

local function seaFlee(boss)
	-- phase 2: it dives and tears out of the bay for the open sea; everyone to the boats
	local zone = state.Zone
	local wy = seaWaterY(zone)
	local bay = marker(zone, "BayCenter")
	local fm = marker(zone, "FinalArena")
	if not bay then return end
	local c = Vector3.new(bay.Position.X, wy, bay.Position.Z)
	local out = fm and Vector3.new(fm.Position.X, wy, fm.Position.Z) or (c + Vector3.new(0, 0, -200))
	local dir = Vector3.new(out.X - c.X, 0, out.Z - c.Z).Unit
	local s, anim = standIn(boss.Species, boss.Scale or 1, CFrame.new(c))
	if not s then return end
	local _, ext = s:GetBoundingBox()
	local H = ext.Y
	local sroot = s.PrimaryPart :: BasePart
	if anim then anim:SetLocomotion("Run", 0.1) end
	scene(function(skipped)
		fade(0, 0.15)
		local cam = Workspace.CurrentCamera
		local t0 = os.clock()
		local D = 3.2
		local lastSplash = 0
		while os.clock() - t0 < D and not skipped() do
			local u = (os.clock() - t0) / D
			local p = c + dir * (u * 120) + Vector3.new(0, -H * 0.62 + math.sin(u * 14) * 0.4, 0)
			local bb, size = s:GetBoundingBox()
			local lift = sroot.Position.Y - (bb.Position.Y - size.Y / 2)
			sroot.CFrame = CFrame.lookAt(p + Vector3.new(0, lift, 0), p + Vector3.new(0, lift, 0) + dir)
			if os.clock() - lastSplash > 0.25 then lastSplash = os.clock() DinosaurVFX.WaterSplash(Vector3.new(p.X, wy, p.Z) - dir * (size.Z * 0.45), 0.9) end
			local subj = Vector3.new(p.X, wy + 2, p.Z)
			cam.CFrame = safeCam(CFrame.lookAt(subj - dir * (26 + u * 10) + Vector3.new(0, 10 + u * 6, 0) + dir:Cross(Vector3.yAxis) * 8, subj + dir * 10), subj)
			cam.FieldOfView = 58
			cineSubject = subj
			RunService.RenderStepped:Wait()
		end
		hold(0.8, skipped)
	end)
	drop(s, true)
end

local function seaFinal()
	scene(function(skipped)
		local fm = marker(state.Zone, "FinalArena")
		if not fm then return end
		local c = fm.Position
		fade(0, 0.2)
		-- (no instructions mid-fight: the waves and the whirlpool show themselves. 2026-10-14)
		task.delay(0.4, function()
			if cine.Gui then CineKit.Slam(cine.Gui, "LAST STAND!", nil, C.RedHi, 1.3) end
			Audio.Sting("Fight")
		end)
		local a = clearSpot({ c + Vector3.new(44, 34, 44), c + Vector3.new(-44, 34, 44), c + Vector3.new(0, 50, -44) }, { c })
		local b = a:Lerp(c, 0.4) + Vector3.new(0, -8, 0)
		move(CFrame.lookAt(a, c), CFrame.lookAt(b, c + Vector3.new(0, 2, 0)), 2.6, skipped, 58, 46, c + Vector3.new(0, 2, 0))
	end)
	freeCam()
end

-- the boss's own reveal (2026-10-12): authored + baked like the TikTok shots (tools/gen/anim/reveals.js), played
-- with a letterbox and hold-to-skip, then you, launcher up: FIGHT!
local function revealWith(bossId: string, tierName: string, model: Model?, zone: string?, unhide: (() -> ())?): boolean
	local TikTok = require(script.Parent.TikTok)
	local seqId = TikTok.RevealFor(bossId)
	if not seqId then return false end
	-- (a hunter arriving just as the fight starts: let the travel scene finish handing the camera back first)
	local t0 = os.clock()
	while (busy or DinosaurCinematics.IsPlaying()) and os.clock() - t0 < 6 do task.wait(0.1) end
	local boss = Config.Bosses[bossId] :: any
	-- (a take that never got going says so: the caller plays its own intro instead of skipping straight to FIGHT!
	-- with no reveal at all. 2026-10-14)
	if not TikTok.PlayCutscene(seqId, { Hide = model and { model } or nil }) then return false end
	if unhide then unhide() end -- (the real one back, exactly where the reveal left it)
	if model and model.Parent then
		model:SetAttribute("DisplayName", boss.Name)
		model:SetAttribute("Rarity", "")
		model:SetAttribute("SignatureMove", tierName)
	end
	local r = hrp()
	local look = model and model.Parent and model:GetPivot().Position or nil
	if r and look and (r.Position - look).Magnitude < 160 then heroShot(look) end
	freeCam()
	local _ = zone
	return true
end

local function bossIntro(info)
	-- (the boss music starts with the fight, not over the reveal's own sound design)
	local model = nil
	for _ = 1, 30 do
		model = bossModel(info.Actor)
		if model then break end
		task.wait(0.05)
	end
	-- (never seen before its reveal - not even for the frames while the reveal gets going: it's off the screen from
	-- the moment the intro is announced, and back only when the reveal hands over)
	local home = model and model.Parent
	if model and home then model.Parent = nil end
	local function unhide()
		if model and home and not model.Parent and home.Parent then model.Parent = home end
	end
	local water = (Config.Bosses[info.Boss] :: any) and (Config.Bosses[info.Boss] :: any).Water
	local played = false
	local okR, errR = pcall(function() played = revealWith(info.Boss, info.Tier or "NORMAL", model, state.Zone, unhide) end)
	if not okR then warn("[EraView] boss reveal:", errR) end
	local ok, err = true, nil
	if not played then
		unhide()
		ok, err = pcall(water and seaIntroWith or bossIntroWith, info.Boss, info.Tier or "NORMAL", model, state.Zone)
	end
	unhide()
	if not ok then warn("[EraView] boss intro:", err) freeCam() end
	if not bossMusic then bossMusic = true Audio.Push("Boss") end
	task.spawn(function() Net.Ask("IntroDone") end) -- always: the den is frozen until this arrives
end

local function bossFlee(info)
	-- phase 2: it bolts out of the den and down toward its last stand; everyone runs for their rover. The real boss
	-- is already off the map (the server hides it for the chase), so a double does the running for the camera
	local ruler = eraBoss(state.Zone) :: any
	if ruler and ruler.Water then seaFlee(ruler) return end
	-- (the double always goes, even if the scene breaks part-way: it used to stay standing in the era)
	local fleeDouble: Model? = nil
	scene(function(skipped)
		local root = hrp()
		local cam = Workspace.CurrentCamera
		local m = bossModel(nil)
		local p0 = m and m:GetPivot().Position or (root and root.Position or Vector3.zero)
		local start = ground(p0)
		-- which way it runs: toward the final arena (else away from you)
		local fm = marker(state.Zone, "FinalArena")
		local away = fm and Vector3.new(fm.Position.X - start.X, 0, fm.Position.Z - start.Z) or (root and Vector3.new(start.X - root.Position.X, 0, start.Z - root.Position.Z) or Vector3.new(0, 0, -1))
		away = away.Magnitude > 1 and away.Unit or Vector3.new(0, 0, -1)
		local me = root and root.Position or (start - away * 20)
		local toMe = Vector3.new(me.X - start.X, 0, me.Z - start.Z)
		toMe = toMe.Magnitude > 1 and toMe.Unit or -away
		local d, anim = nil, nil
		if ruler then d, anim = standIn(ruler.Species, ruler.Scale or 1, CFrame.lookAt(start, start + toMe)) end
		if not d then return end
		fleeDouble = d
		cineKeep[d] = true
		local droot = d.PrimaryPart :: BasePart
		local lift = droot.Position.Y - start.Y
		local _, ext = d:GetBoundingBox()
		local size = math.max(ext.X, ext.Y, ext.Z)
		local side = away:Cross(Vector3.yAxis)
		fade(0, 0.12)
		-- 1. it rounds on you and roars (one last threat)...
		if anim and anim:HasAction("Roar") then anim:Play("Roar", { Speed = 1.3 }) end
		local subj = start + Vector3.new(0, ext.Y * 0.55, 0)
		local fan = {}
		for _, h in ipairs({ 3, 7, 12 }) do
			for _, deg in ipairs({ 25, -25, 50, -50, 0, 75, -75 }) do
				table.insert(fan, start + CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(toMe) * (size * 1.3 + 8) + Vector3.new(0, h, 0))
			end
		end
		local spot = clearSpot(fan, { subj, start + Vector3.new(0, ext.Y * 0.2, 0) }, { d })
		task.delay(0.45, function()
			punch(6)
			DinosaurVFX.DustWave(start, toMe, size / 10)
			DinosaurVFX.Shake(0.8, 0.4)
		end)
		move(CFrame.lookAt(spot, subj), CFrame.lookAt(spot + (subj - spot).Unit * 2, subj), 1.0, skipped, 48, 44, subj)
		if skipped() then drop(d, true) return end
		-- 2. ...then wheels round and tears off out of the den, the dust hanging behind it (no words: you see it go)
		if anim then anim:StopActions(0.15) anim:SetLocomotion("Run", 0.15) end
		local runV = (anim and anim.Profile and anim.Profile.Gait and anim.Profile.Gait.Run and anim.Profile.Gait.Run.Speed or 16) * (ruler.Scale or 1) * 1.6
		-- its way out: onto the road and down it toward the final arena (a straight line "toward the arena" ran
		-- it face-first into the canyon wall - tester report). waypoints: the road beside the den, then along it
		local pts = { start }
		local St = Drive.State
		local route, vi = St.Route, St.Variant or 1
		if route then
			local s0 = route:Project(vi, start)
			local fs = fm and fm:GetAttribute("RouteS")
			local dir = (typeof(fs) == "number" and fs < s0) and -1 or 1
			for k = 0, 12 do
				local sk = math.clamp(s0 + dir * k * 10, 2, route:Length(vi) - 2)
				table.insert(pts, ground(route:Position(vi, sk, 0)))
			end
		else
			table.insert(pts, ground(start + away * 120))
		end
		local leg, pos = 2, start
		local t0 = os.clock()
		local last = t0
		local camP = cam.CFrame.Position
		while os.clock() - t0 < 2.0 and not skipped() do
			local now = os.clock()
			local dt = now - last
			last = now
			local u = (now - t0) / 2.0
			local turn = math.clamp(u / 0.18, 0, 1)
			local runDir = away
			if pts[leg] then
				local to = (pts[leg] - pos) * Vector3.new(1, 0, 1)
				if to.Magnitude > 0.5 then runDir = to.Unit end
			end
			local face = toMe:Lerp(runDir, turn)
			if face.Magnitude < 0.05 then face = side end
			if turn >= 1 then
				local step = runV * dt
				while step > 0 and pts[leg] do
					local to = (pts[leg] - pos) * Vector3.new(1, 0, 1)
					if to.Magnitude <= step then
						pos = pts[leg]
						step -= to.Magnitude
						leg += 1
					else
						pos = ground(pos + to.Unit * step)
						step = 0
					end
				end
			end
			droot.CFrame = CFrame.lookAt(pos, pos + face) * CFrame.new(0, lift, 0)
			pace(anim, turn >= 1 and runV or 0, dt)
			Floor.Trample(droot.CFrame, Vector3.new(ext.X, ext.Y, ext.Z))
			if math.random() < 0.35 then DinosaurVFX.FootstepDust(pos, size / 8) end
			-- the lens stays put and turns to watch it go
			cam.CFrame = safeCam(CFrame.lookAt(camP, pos + Vector3.new(0, ext.Y * 0.45, 0)), pos + Vector3.new(0, ext.Y * 0.45, 0))
			cam.FieldOfView = 44 - u * 6
			RunService.RenderStepped:Wait()
		end
		drop(d, true)
		local _ = info
	end)
	if fleeDouble and fleeDouble.Parent then pcall(drop, fleeDouble, true) end
end

local function bossFinal(info)
	waitFree(6) -- (the flee scene or a spotted intro still finishing)
	local ruler = eraBoss(state.Zone) :: any
	if ruler and ruler.Water then seaFinal() return end
	local ran = scene(function(skipped)
		local fm = marker(state.Zone, "FinalArena")
		if not fm then return end
		local c = ground(fm.Position)
		-- it's waiting for you in the stones (the server has put it back on the map, in the arena). frame the spot
		-- the server says, and give the model a moment to catch up there (it could still be back at the den)
		local at = typeof(info and info.At) == "Vector3" and info.At or nil
		local m = nil
		for _ = 1, 30 do
			m = bossModel(nil)
			if m and m.Parent and (not at or ((m:GetPivot().Position - at) * Vector3.new(1, 0, 1)).Magnitude < 25) then break end
			task.wait(0.05)
		end
		local p = at and ground(at) or ((m and m.Parent) and ground(m:GetPivot().Position) or c)
		local size, extY = 12, 10
		if m then local _, e = m:GetBoundingBox() size, extY = math.max(e.X, e.Y, e.Z), e.Y end
		if m then cineKeep[m] = true end
		local root = hrp()
		local me = root and root.Position or (c + Vector3.new(0, 0, 30))
		local toMe = Vector3.new(me.X - p.X, 0, me.Z - p.Z)
		toMe = toMe.Magnitude > 1 and toMe.Unit or Vector3.new(0, 0, 1)
		local side = toMe:Cross(Vector3.yAxis)
		fade(0, 0.2)
		-- 1. over your shoulder: it's there, between the stones, waiting
		local head = p + Vector3.new(0, extY * 0.7, 0)
		local body = p + Vector3.new(0, extY * 0.35, 0)
		local a = clearSpot({ me - toMe * 6 + side * 3 + Vector3.new(0, 4, 0), me - toMe * 6 - side * 3 + Vector3.new(0, 4, 0), me + Vector3.new(0, 9, 0),
			me - toMe * 10 + Vector3.new(0, 12, 0), me + side * 8 + Vector3.new(0, 6, 0), me - side * 8 + Vector3.new(0, 6, 0) }, { head, body }, m and { m } or nil)
		move(CFrame.lookAt(a, head:Lerp(me, 0.25)), CFrame.lookAt(a + (head - a).Unit * 4, head), 1.4, skipped, 50, 42, head)
		if skipped() then return end
		-- 2. low at its feet as it roars: last stand
		local anim = m and DinosaurAnimations.get(m)
		if anim and anim:HasAction("Roar") then anim:Play("Roar") end
		-- low at its feet: a fan of spots round the front (stones and palms stand all over the arena), low first
		local lows = {}
		for _, h in ipairs({ 1.2, 4, 9 }) do
			for _, deg in ipairs({ 20, -20, 45, -45, 70, -70, 0 }) do
				local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(toMe)
				table.insert(lows, p + dir * (size * 0.9 + 6) + Vector3.new(0, h, 0))
			end
		end
		local low = clearSpot(lows, { head, body }, m and { m } or nil)
		task.delay(0.5, function()
			CineKit.Slam(cine.Gui, "LAST STAND!", nil, C.RedHi, 1.1)
			punch(8)
			CineKit.ImpactFrame(0.6)
			DinosaurVFX.DustWave(p, toMe, size / 10)
			DinosaurVFX.Shake(1.0, 0.5)
			Audio.Sting("Fight")
		end)
		move(CFrame.lookAt(low, head), CFrame.lookAt(low + (head - low).Unit * 2.5, head + Vector3.new(0, 1, 0)), 1.6, skipped, 54, 46, head)
		local _ = info
	end)
	if ran then Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end
end

local function bossDown(info, given: Model?)
	-- (a teammate's knockout can land during your last-stand intro: DEFEATED! waits its turn instead of being lost)
	waitFree(8)
	local ran = scene(function(skipped)
		local m = given or bossModel(nil)
		local cam = Workspace.CurrentCamera
		local p = m and m:GetPivot().Position or (hrp() and (hrp() :: BasePart).Position or Vector3.zero)
		fade(0, 0.1)
		flash(0.8)
		-- she goes down in a storm of blocks and leaves; DEFEATED! over the rays
		local bsize = 12
		if m then local _, e = m:GetBoundingBox() bsize = math.max(e.X, e.Y, e.Z) end
		burst(p + Vector3.new(0, bsize * 0.3, 0), math.clamp(bsize / 10, 1.2, 3), nil)
		task.delay(0.5, function() DinosaurVFX.Cubes(p + Vector3.new(0, bsize * 0.5, 0), 40, { C.YellowHi, C.OrangeHi, C.LimeHi, C.TealHi, Color3.new(1, 1, 1) }, 0.5, 30, 1.6) end)
		punch(10)
		rayTitle("DEFEATED!", string.upper(info.Name or "THE BOSS") .. " HAS FALLEN", C.YellowHi, 2.8)
		CineKit.ImpactFrame(1.2)
		CineKit.HitStop(0.7, 0.2, 0.8) -- the knockout in slow motion
		CineKit.SunBurst(1.2)
		slamBars()
		Audio.Sting("Defeated")
		-- a slow orbit, wide enough for whatever size she is, never through a wall
		local size = 12
		if m then local _, ext = m:GetBoundingBox() size = math.max(ext.X, ext.Y, ext.Z) end
		local r = math.max(16, size * 1.25 + 6)
		local subj = p + Vector3.new(0, size * 0.2, 0)
		local t0 = os.clock()
		while os.clock() - t0 < 3 and not skipped() do
			local a = (os.clock() - t0) * 0.5
			cam.CFrame = safeCam(CFrame.lookAt(p + Vector3.new(math.cos(a) * r, size * 0.35 + 3, math.sin(a) * r), subj), subj)
			cam.FieldOfView = 46
			RunService.RenderStepped:Wait()
		end
		card(info.Tier or "", info.Name or "", "TIME " .. fmtTime(info.Time or 0), C.LimeHi)
		hold(0.8, skipped)
	end)
	-- (only if it ran: a refused scene must never yank the camera out from under the one that's playing)
	if ran then Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end
end

local function bossLoot(info)
	-- after the knockout scene (however long it runs, skipped or not), never over it
	task.wait(1.5)
	local t0 = os.clock()
	while Cinema.Playing() and os.clock() - t0 < 12 do task.wait(0.1) end
	task.wait(0.3)
	local gui, canvas = Kit.Screen("DinoBossLoot", 26)
	local boss = Config.Bosses[info.Boss] :: any
	local win, body = Kit.Window(canvas, { Fit = true, Title = "BOSS DEFEATED!", Icon = "Trophy", Color = "Orange", Size = UDim2.fromOffset(620, 380), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 10 })
	Kit.Pop(win, 0.5)
	Kit.Text(body, boss.Name .. "  -  " .. (info.Tier or ""), { Pixel = true, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 4), Color = C.YellowHi, Stroke = 2, Shadow = 2, ZIndex = 14, MaxSize = 14 })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 190), Position = UDim2.fromOffset(0, 34), ZIndex = 12 }, body)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, row)
	-- (won together: a 4th TEAM tile, so every tile gets a little narrower - Boosts.Coop, 2026-10-14)
	local coop = typeof(info.Coop) == "table" and info.Coop or nil
	local tileW, iconS = coop and 132 or 170, coop and 92 or 104
	local function tile(order: number, icon: string, label: string, sub: string, color: Color3, species: string?, sub2: string?): Frame
		local o, c = Kit.Card(row, { Size = UDim2.fromOffset(tileW, 180), Border = color })
		o.LayoutOrder = order
		Kit.Icon(c, icon, { Species = species, Size = UDim2.fromOffset(iconS, iconS), Position = UDim2.new(0.5, 0, 0, 8 + (104 - iconS) // 2), AnchorPoint = Vector2.new(0.5, 0), ZIndex = o.ZIndex + 4 })
		Kit.Text(c, label, { Size = UDim2.new(1, -14, 0, 26), Position = UDim2.new(0.5, 0, 0, 114), AnchorPoint = Vector2.new(0.5, 0), ZIndex = o.ZIndex + 5, Color = color, Stroke = 3.5, Shadow = 3, MaxSize = 28 })
		Kit.Text(c, sub, { Pixel = true, Size = UDim2.new(1, -14, 0, 10), Position = UDim2.new(0.5, 0, 0, 146), AnchorPoint = Vector2.new(0.5, 0), ZIndex = o.ZIndex + 5, Color = C.Cream, Stroke = 1.5, Shadow = 1, MaxSize = 11 })
		if sub2 then Kit.Text(c, sub2, { Pixel = true, Size = UDim2.new(1, -14, 0, 10), Position = UDim2.new(0.5, 0, 0, 160), AnchorPoint = Vector2.new(0.5, 0), ZIndex = o.ZIndex + 5, Color = C.TealHi, Stroke = 1.5, Shadow = 1, MaxSize = 11 }) end
		Kit.Pop(o, 0.3, order * 0.12)
		return o
	end
	if info.Nest then
		-- the boss nest: the eggs are out there for the team to grab (first come, first served, one each)
		tile(1, "Egg", "x" .. tostring(info.Nest), "IN THE NEST - GRAB ONE!", C.YellowHi, info.Species)
	else
		local egg = info.Egg or {}
		local r = Config.Rarity[egg.Rarity or "Common"] :: any
		tile(1, "Egg", r.Name, (Config.Species[egg.Species] and (Config.Species[egg.Species] :: any).Name or "") .. " " .. Config.FormatKG(egg.KG or 0), r.Color, egg.Species)
	end
	local matName = Config.Materials[boss.Material or ""] and (Config.Materials[boss.Material] :: any).Name or ""
	tile(2, "Mat_" .. (boss.Material or ""), "x" .. (info.Mats or 0), matName, C.OrangeHi)
	tile(3, "Coin", "+" .. Config.FormatNumber(info.Coins or 0), "COINS", C.YellowHi)
	if coop then
		-- the team bonus (its coins are already in the coin tile above; the POWER burst popped on the trainer counter)
		local power = tonumber(coop.Power) or 0
		local t4 = tile(4, "Buddy", "TEAM x" .. tostring((tonumber(coop.Mates) or 1) + 1), "+" .. tostring(tonumber(coop.Pct) or 0) .. "% COINS", C.PurpleHi, nil, power > 0 and ("+" .. Config.FormatNumber(power) .. " POWER") or nil)
		task.delay(0.9, function() if t4.Parent then Kit.Punch(t4, 0.12) end end)
	end
	Kit.Text(body, (info.FirstClear and "NEW TIER CLEARED!  " or "") .. "MASTERY STARS: " .. (info.Stars or 0), { Pixel = true, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -66), Color = info.FirstClear and C.LimeHi or C.Cream, Stroke = 2, Shadow = 2, ZIndex = 14, MaxSize = 14 })
	Kit.Text(body, info.Nest and "GRAB A BOSS EGG FROM THE NEST!" or "NOW GET THE EGG HOME!", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -40), Color = C.YellowHi, Stroke = 3.5, Shadow = 3, ZIndex = 14, MaxSize = 28 })
	task.delay(5, function() if gui.Parent then Kit.PopOut(win, false) task.wait(0.3) gui:Destroy() end end)
end

--------------------------------------------------------------------------------
-- 7. a little MAP button while you're on foot at a (non-boss) site
--------------------------------------------------------------------------------
local siteGui, siteBtn
local function buildSiteButton()
	local gui, canvas = Kit.Screen("DinoSiteBar", 9, false, 0.8)
	siteGui = gui
	-- (on touch it sits up out of the thumbstick's half of the screen: a thumb landing on it opened the map)
	local touch = Kit.Platform() == "Touch"
	siteBtn = Kit.Tile(canvas, { Icon = "Map", Label = "MAP", Color = "Blue", Size = touch and UDim2.fromOffset(66, 66) or UDim2.fromOffset(84, 84),
		Position = touch and UDim2.new(0, 16, 0.17, 0) or UDim2.new(0, 16, 0.5, -40), AnchorPoint = touch and Vector2.new(0, 0) or Vector2.new(0, 0.5), OnClick = function()
		local sf = siteFolder(state.SiteKey)
		-- (mid-scramble you go back to the map only with nothing taken from here: eggs on your rack or in your arms
		-- mean DRIVE OFF and the chase. With nothing - every egg already taken in a busy server - the map is the
		-- way out; it used to refuse, and there was none)
		local loaded = #((Net.Profile and Net.Profile.RoverEggs) or {}) > 0 or player:GetAttribute("Holding") ~= nil
		if sf and loaded and (sf:GetAttribute("State") == "Scramble" or sf:GetAttribute("State") == "Chase") then
			Kit.Toast("YOU HAVE EGGS - GET TO YOUR ROVER AND DRIVE OFF!", "Orange", "Egg")
			return
		end
		View.BackToMap()
	end })
	gui.Enabled = false
end

--------------------------------------------------------------------------------
-- 8. the cutscene gallery (Settings > CUTSCENES): every scene, playable any time
--------------------------------------------------------------------------------
local function groundAhead(dist: number): CFrame?
	local root = hrp()
	if not root then return nil end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local p = root.Position + look * dist
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = Workspace:Raycast(p + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	local y = hit and hit.Position.Y or (root.Position.Y - 3)
	local at = Vector3.new(p.X, y, p.Z)
	return CFrame.lookAt(at, Vector3.new(root.Position.X, y, root.Position.Z))
end

local function withEra(zone: string, fn: () -> ())
	local was = Zone.Current
	Zone.Apply(zone, true)
	local ok, err = pcall(fn)
	if not ok then warn("[EraView] preview:", err) end
	Zone.Apply(was, true)
end

--------------------------------------------------------------------------------
-- gallery stages: every dino's cutscenes play out on location, never wherever you happen to be standing.
-- a species with a nest site plays at its own site; one whose era isn't built yet borrows the built era
-- that suits it best (big walkers on the open plains, forest hunters in the valley)
--------------------------------------------------------------------------------
local BIG = { Brachiosaurus = true, Giganotosaurus = true, PrimalRex = true, Mosasaurus = true, Spinosaurus = true, TyrannosaurusRex = true, Stegosaurus = true, Ankylosaurus = true, Carnotaurus = true, Sarcosuchus = true, Plateosaurus = true, Postosuchus = true, Yutyrannus = true, Therizinosaurus = true, Gallimimus = true }
local function stageFor(species: string): (string?, Vector3?)
	local own, any = {}, {}
	for _, f in ipairs(SitesFolder:GetChildren()) do
		local c = f:GetAttribute("Center")
		local era = f:GetAttribute("Era")
		if typeof(c) == "Vector3" and era and zoneModel(era) and not f:GetAttribute("Boss") then
			if f:GetAttribute("Species") == species then table.insert(own, { era, c }) end
			any[era] = any[era] or {}
			table.insert(any[era], c)
		end
	end
	if #own > 0 then return own[1][1], own[1][2] end
	local want = BIG[species] and "GiantPlains" or "FernValley"
	if not any[want] then want = next(any) end
	if not want then return nil, nil end
	-- a different clearing per species, so the gallery doesn't repeat one spot
	local list = any[want]
	local idx = (table.find(Config.SpeciesOrder, species) or 1) % #list + 1
	return want, list[idx]
end

-- the open side of a stage: which way the camera can see the dino from with nothing in the way
local function openSide(at: Vector3, height: number, dist: number): Vector3
	local best, bestN = Vector3.new(0, 0, -1), math.huge
	for i = 0, 7 do
		local ang = i * math.pi / 4
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local spot = ground(at + dir * dist) + Vector3.new(0, 3, 0)
		local n = 0
		camRay.FilterDescendantsInstances = {}
		local hit = Workspace:Raycast(spot, (at + Vector3.new(0, height, 0)) - spot, camRay)
		if hit and hit.Instance.Transparency < 0.9 then n += 1 end
		n += math.clamp((spot.Y - at.Y) / 12, 0, 2) -- a camera way up a bank or way below is worse
		if n < bestN then best, bestN = dir, n end
		if n == 0 then break end
	end
	return best
end

--------------------------------------------------------------------------------
-- water sets: the swimmers get real water. built from Terrain water far off the map for the length of the
-- cutscene (local to you), with a DinoWater-tagged plane so the signature cinematics find the surface too
--------------------------------------------------------------------------------
local WATER = { Mosasaurus = "Ocean", Spinosaurus = "River", Sarcosuchus = "River" }
local OCEAN_O = Vector3.new(6000, 0, 6000)
local RIVER_O = Vector3.new(6000, 0, 7400)

local function clonePlants(folder: Instance, near: Vector3, spots: { Vector3 })
	local src = Workspace:FindFirstChild("FernValley")
	if not src then return end
	local trees = {}
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("Model") and (d.Name:find("Palm") or d.Name:find("Tree") or d.Name:find("Fern")) and #trees < 24 then table.insert(trees, d) end
	end
	if #trees == 0 then return end
	for i, p in ipairs(spots) do
		local t = trees[(i - 1) % #trees + 1]:Clone()
		local cf, size = t:GetBoundingBox()
		local pivot = t:GetPivot()
		local bottom = cf.Position.Y - size.Y / 2
		t:PivotTo(CFrame.new(p + Vector3.new(0, pivot.Position.Y - bottom, 0)) * CFrame.Angles(0, i * 1.7, 0))
		t.Parent = folder
	end
	local _ = near
end

-- returns the set folder, the mark (where the dino ends up), the camera side, the water height, and a cleanup
local function buildWaterSet(kind: string): (Folder, Vector3, Vector3, number, () -> ())
	local T = Workspace.Terrain
	local folder = Instance.new("Folder")
	folder.Name = "DinoWaterSet"
	folder.Parent = Workspace
	local saved = { T.WaterColor, T.WaterReflectance, T.WaterTransparency, T.WaterWaveSize, T.WaterWaveSpeed }
	local regions = {}
	local function fill(cf: CFrame, size: Vector3, mat: Enum.Material)
		T:FillBlock(cf, size, mat)
		table.insert(regions, { cf, size })
	end
	local mark, face, waterY
	if kind == "Ocean" then
		local O = OCEAN_O
		fill(CFrame.new(O + Vector3.new(0, -30, 0)), Vector3.new(700, 60, 700), Enum.Material.Water)
		fill(CFrame.new(O + Vector3.new(0, -64, 0)), Vector3.new(700, 8, 700), Enum.Material.Sand)
		-- sea stacks and a far island to give the horizon a shape
		for i, p in ipairs({ Vector3.new(-90, 0, -140), Vector3.new(120, 0, -190), Vector3.new(-200, 0, 60), Vector3.new(40, 0, -320) }) do
			local r = 14 + i * 4
			T:FillBall(O + p + Vector3.new(0, r * 0.35, 0), r, Enum.Material.Rock)
			table.insert(regions, { CFrame.new(O + p), Vector3.new(r * 2.4, r * 3, r * 2.4) })
		end
		T:FillBall(O + Vector3.new(260, -40, -380), 90, Enum.Material.Grass)
		table.insert(regions, { CFrame.new(O + Vector3.new(260, -40, -380)), Vector3.new(190, 190, 190) })
		T.WaterColor = Color3.fromRGB(22, 96, 140)
		T.WaterReflectance = 0.5
		T.WaterTransparency = 0.55
		T.WaterWaveSize = 0.35
		T.WaterWaveSpeed = 14
		mark, face, waterY = O, Vector3.new(0, 0, 1), 0
	else
		local O = RIVER_O
		-- banks of grass with a river running along X, trees from the valley on both banks
		fill(CFrame.new(O + Vector3.new(0, -14, 0)), Vector3.new(520, 28, 360), Enum.Material.Grass)
		T:FillBlock(CFrame.new(O + Vector3.new(0, -5, 0)), Vector3.new(520, 10, 64), Enum.Material.Air)
		fill(CFrame.new(O + Vector3.new(0, -11, 0)), Vector3.new(520, 2, 64), Enum.Material.Mud)
		fill(CFrame.new(O + Vector3.new(0, -5.5, 0)), Vector3.new(520, 9, 64), Enum.Material.Water)
		T.WaterColor = Color3.fromRGB(46, 120, 104)
		T.WaterReflectance = 0.35
		T.WaterTransparency = 0.7
		T.WaterWaveSize = 0.15
		T.WaterWaveSpeed = 8
		local spots = {}
		for i = 0, 15 do
			local x = -150 + i * 20 + (i % 3) * 4
			table.insert(spots, O + Vector3.new(x, 0, (i % 2 == 0 and 1 or -1) * (44 + (i % 4) * 9)))
		end
		clonePlants(folder, O, spots)
		mark, face, waterY = O + Vector3.new(0, 0, 4), Vector3.new(0, 0, 1), -1
	end
	-- the surface the cinematics read (invisible)
	local surf = Instance.new("Part")
	surf.Name = "WaterSurface"
	surf.Anchored, surf.CanCollide, surf.CanQuery, surf.CanTouch = true, false, false, false
	surf.Transparency = 1
	surf.Size = Vector3.new(400, 0.2, 400)
	surf.Position = Vector3.new(mark.X, waterY - 0.1, mark.Z)
	surf.Parent = folder
	game:GetService("CollectionService"):AddTag(surf, "DinoWater")
	local function cleanup()
		for _, r in ipairs(regions) do T:FillBlock(r[1], r[2] + Vector3.new(4, 4, 4), Enum.Material.Air) end
		T.WaterColor, T.WaterReflectance, T.WaterTransparency, T.WaterWaveSize, T.WaterWaveSpeed = saved[1], saved[2], saved[3], saved[4], saved[5]
		folder:Destroy()
	end
	return folder, mark, face, waterY, cleanup
end

-- run a gallery piece on location: era lighting on, the real residents there tucked away, you frozen at camp.
-- body(mark, face, set, waterY): set is the folder to parent props / the dino to (water sets need it)
local function onStage(species: string, body: (Vector3, Vector3, Instance?, number?) -> (), opts: any?)
	if busy or DinosaurCinematics.IsPlaying() then return end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local ws = hum and hum.WalkSpeed
	if hum then hum.WalkSpeed = 0 end
	if WATER[species] then
		local set, mark, face, waterY, cleanup = buildWaterSet(WATER[species])
		withEra("FernValley", function() body(mark, face, set, waterY) end)
		cleanup()
	else
		local zone, at = stageFor(species)
		-- discovering a real site: the reveal plays right there, where you're about to go
		local sf = opts and opts.Site and siteFolder(opts.Site)
		if sf and typeof(sf:GetAttribute("Center")) == "Vector3" then zone, at = sf:GetAttribute("Era"), sf:GetAttribute("Center") end
		if not (zone and at) then
			Kit.Toast("NO STAGE FOR THIS DINO YET", "Orange", "Film")
			if hum and ws then hum.WalkSpeed = ws end
			return
		end
		local g = ground(at)
		local hidden = {}
		if Exp then
			for _, c in pairs(Exp.Creatures()) do
				if c.Model and c.Model.Parent and (c.Root.Position - g).Magnitude < 110 then
					table.insert(hidden, { c.Model, c.Model.Parent })
					c.Model.Parent = nil
				end
			end
		end
		-- (the set is made and destroyed out here: a beat that errors mid-scene used to leave its props standing)
		local set = Instance.new("Folder")
		set.Name = "DinoRevealSet"
		set.Parent = Workspace
		withEra(zone, function()
			local size = BIG[species] and 30 or 16
			local face = openSide(g, size * 0.3, 20 + size * 1.2)
			body(g, face, set, nil)
		end)
		set:Destroy()
		for _, h in ipairs(hidden) do if h[1] then h[1].Parent = h[2] end end
	end
	if hum and ws then hum.WalkSpeed = ws end
	freeCam()
end

local function speciesCard(species: string): (string, string, Color3)
	local info = Config.Species[species] :: any
	local era = Config.Era(info.Era) :: any
	return info.Name, era and ("FOUND IN " .. era.Name) or "", info.Color or C.Yellow
end

-- a swimmer sits low in the water: its back at the surface, the rest below
local function sinkTo(m: Model, waterY: number, depth: number)
	local cf, size = m:GetBoundingBox()
	local root = m.PrimaryPart :: BasePart
	local bottom = cf.Position.Y - size.Y / 2
	local want = waterY - size.Y * depth
	root.CFrame += Vector3.new(0, want - bottom, 0)
end

-- the signature intro, on location: a wide of the setting first, then its own cinematic
function View.PreviewIntro(species: string)
	onStage(species, function(g: Vector3, face: Vector3, set: Instance?, waterY: number?)
		local m = standIn(species, siteScale(species), CFrame.lookAt(g, g + face))
		if not m then return end
		if set then m.Parent = set end
		if waterY then sinkTo(m, waterY, 0.6) end
		local name, sub, color = speciesCard(species)
		m:SetAttribute("DisplayName", name)
		m:SetAttribute("Rarity", "")
		local _, ext = m:GetBoundingBox()
		local size = math.max(ext.X, ext.Y, ext.Z)
		local side = face:Cross(Vector3.yAxis)
		local subj = m:GetPivot().Position
		scene(function(skipped)
			-- the setting: a high wide that drifts down toward it, the dino small in its world
			local far = clearSpot({ g + face * size * 3.2 + side * size + Vector3.new(0, size * 0.9, 0), g + face * size * 3.2 - side * size + Vector3.new(0, size * 0.9, 0), g + face * size * 2.4 + Vector3.new(0, size * 1.4, 0) }, { subj }, { m })
			fade(0, 0.4)
			card("", name, sub, color)
			move(CFrame.lookAt(far, subj), CFrame.lookAt(far:Lerp(subj, 0.25) - Vector3.new(0, size * 0.15, 0), subj), 2.4, skipped, 50, 44, subj)
			hideCard()
			fade(1, 0.2)
		end, { KeepCamera = true })
		fade(0, 0.1)
		playSignature(m)
		drop(m, true)
	end)
end

--------------------------------------------------------------------------------
-- MYSTERY -> REVEAL: every dino is found its own way. No captions while the mystery plays - only the picture,
-- the light and the sound; the name card lands on the reveal. The dino is a black silhouette (eyes lit) until
-- the reveal floods the light back in. Kick = its epithet on the name card, Act = what it does on the reveal,
-- Hero = how the reveal frames it (Low: three-quarter hero angle, Up: way down looking up at a giant).
--------------------------------------------------------------------------------
local REVEAL = {
	Velociraptor = { Kick = "THE PACK HUNTER", Beat = "pack", Act = { "RaptorScreech", "Roar" }, Hero = "Low" },
	Triceratops = { Kick = "THREE HORNS, ONE TEMPER", Beat = "ferns", Act = { "Roar" }, Hero = "Low", AtMark = true },
	Parasaurolophus = { Kick = "THE SINGER OF THE HERD", Beat = "call", Act = { "HerdCall", "Roar" }, Hero = "Low", Warm = true },
	Stegosaurus = { Kick = "ARMOURED ALL THE WAY DOWN", Beat = "plates", Act = { "Roar" }, Hero = "Low", AtMark = true },
	Ankylosaurus = { Kick = "THE LIVING TANK", Beat = "club", Act = { "Roar" }, Hero = "Low" },
	Brachiosaurus = { Kick = "TALLER THAN THE TREES", Beat = "tremor", Act = { "Roar" }, Hero = "Up", Warm = true, AtMark = true },
	Carnotaurus = { Kick = "THE BULL OF THE ASH", Beat = "ember", Act = { "Roar" }, Hero = "Low", Ember = true, AtMark = true },
	Spinosaurus = { Kick = "KING OF THE RIVER", Beat = "fin", Act = { "Roar" }, Hero = "Low" },
	TyrannosaurusRex = { Kick = "THE TYRANT KING", Beat = "ripple", Act = { "Roar" }, Hero = "Up" },
	Giganotosaurus = { Kick = "BIGGER THAN A REX", Beat = "shadow", Act = { "Roar" }, Hero = "Up", AtMark = true },
	Mosasaurus = { Kick = "TERROR OF THE DEEP", Beat = "deep", Act = { "Roar" }, Hero = "Low" },
	PrimalRex = { Kick = "THE PERFECT PREDATOR", Beat = "breach", Act = { "ClawSlash", "Roar" }, Hero = "Up", Alarm = true },
}

local function prop(set: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do (p :: any)[k] = v end
	p.Parent = set
	return p
end

local function silhouette(m: Model, eyes: boolean?): Highlight
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(0, 0, 0)
	h.FillTransparency = 0
	h.OutlineColor = Color3.fromRGB(30, 10, 10)
	h.OutlineTransparency = 0.7
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = m
	if eyes ~= false then DinosaurVFX.EyeGlow(m, 12) end
	return h
end

-- shatter a part into chunks that fly off and fade
local function shatter(set: Instance, part: BasePart, from: Vector3, power: number)
	local s = part.Size
	for _ = 1, 10 do
		local chunk = prop(set, { Size = s * (0.18 + math.random() * 0.14), Color = part.Color, Material = part.Material, Transparency = part.Transparency, CFrame = part.CFrame * CFrame.new((math.random() - 0.5) * s.X * 0.6, (math.random() - 0.5) * s.Y * 0.6, (math.random() - 0.5) * s.Z * 0.6) })
		chunk.Anchored = false
		chunk.CanCollide = true
		local away = (chunk.Position - from)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.yAxis
		chunk.AssemblyLinearVelocity = away * power * (0.6 + math.random() * 0.6) + Vector3.new(0, power * 0.5, 0)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8)
		TweenService:Create(chunk, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6), { Transparency = 1 }):Play()
	end
	part:Destroy()
end

-- a flock bursting up out of the trees / grass and away
local function birdsUp(set: Instance, at: Vector3, n: number, spread: number?)
	for _ = 1, n do
		local s = spread or 8
		local b = prop(set, { Size = Vector3.new(1, 0.14, 0.45), Color = Color3.fromRGB(40, 36, 44), CastShadow = false, CFrame = CFrame.new(at + Vector3.new((math.random() - 0.5) * s, math.random() * 2, (math.random() - 0.5) * s)) })
		local dir = Vector3.new((math.random() - 0.5) * 2, 1.1 + math.random(), (math.random() - 0.5) * 2).Unit
		local to = b.Position + dir * (50 + math.random() * 30)
		TweenService:Create(b, TweenInfo.new(2.4 + math.random(), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.lookAt(to, to + dir) * CFrame.Angles(0, 0, math.random() * 0.6), Transparency = 1 }):Play()
	end
end

-- a simple blocky tree (trunk + canopy) and a way to knock it over about its base
local function tree(set: Instance, at: Vector3, h: number): { BasePart }
	local parts = {} :: { BasePart }
	table.insert(parts, prop(set, { Size = Vector3.new(1.8, h, 1.8), Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood, CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)) }))
	for k = 1, 3 do
		table.insert(parts, prop(set, { Size = Vector3.new(9 - k * 1.6, 2.6, 9 - k * 1.6), Color = Color3.fromRGB(60 + k * 14, 140 + k * 12, 55), Material = Enum.Material.Grass, CFrame = CFrame.new(at + Vector3.new(0, h - 1 + k * 1.8, 0)) * CFrame.Angles(0, k * 0.4, 0) }))
	end
	return parts
end
local function topple(parts: { BasePart }, pivot: Vector3, dir: Vector3, dur: number)
	local axis = dir:Cross(Vector3.yAxis).Unit
	local base = {}
	for _, p in ipairs(parts) do base[p] = p.CFrame end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			local u = (os.clock() - t0) / dur
			local rot = CFrame.fromAxisAngle(axis, -(u ^ 2) * math.rad(84))
			for p, cf in pairs(base) do
				if p.Parent then p.CFrame = CFrame.new(pivot + rot:VectorToWorldSpace(cf.Position - pivot)) * rot * cf.Rotation end
			end
			RunService.Heartbeat:Wait()
		end
		DinosaurVFX.GroundImpact(pivot + dir * 10, 1.4)
		DinosaurVFX.Shake(0.9, 0.35)
		CineKit.ImpactFrame(0.6)
	end)
end

local function playAny(anim, names: { string }): boolean
	if not anim then return false end
	for _, n in ipairs(names) do
		if anim:HasAction(n) then anim:Play(n) return true end
	end
	return false
end

-- each beat: (ctx, skipped) plays the mystery half. ctx helpers: Walk(to, dur, skipped, camFn?, dir?), Teleport(p, dir),
-- Turn(dir, t), Head(), EyesShot(skipped); fields Model, Anim, Root, Lift, Set, Mark, Start, Face, Side, Size, Ext, WaterY, Dark
local BEATS = {}

-- RAPTOR PACK: birds explode out of the long grass; something tears through it toward you; a black shape
-- leaps across the lens; then three of them rise up around you
BEATS.pack = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local extras = {}
	for _, k in ipairs({ -1, 1 }) do
		local p = ground(ctx.Mark + ctx.Side * k * (ctx.Size * 1.3) + ctx.Face * (ctx.Size * 0.3))
		local e, ea = standIn(ctx.Species, scaleOf(ctx.Species) * 0.95, CFrame.lookAt(p, p + ctx.Face - ctx.Side * k * 0.4))
		if e then
			e.Parent = ctx.Set
			silhouette(e)
			-- crouched down in the grass until the reveal
			local r = e.PrimaryPart :: BasePart
			r.CFrame -= Vector3.new(0, ctx.Ext.Y * 0.7, 0)
			table.insert(extras, { Model = e, Anim = ea, Root = r, Rise = ctx.Ext.Y * 0.7 })
		end
	end
	ctx.Extras = {}
	for _, x in ipairs(extras) do table.insert(ctx.Extras, x.Model) end
	ctx.Pack = extras
	-- 1. low in the grass at the nest, still... then the birds go
	local eye = ctx.Mark + ctx.Face * (ctx.Size * 3 + 10) + Vector3.new(0, 1, 0)
	local look = ctx.Mark + Vector3.new(0, 2, 0)
	move(CFrame.lookAt(eye, look), CFrame.lookAt(eye + ctx.Face * -1.5, look), 1.4, skipped, 48, 46, look)
	if skipped() then return end
	birdsUp(ctx.Set, ctx.Mark + Vector3.new(0, 3, 0), 9, 14)
	DinosaurVFX.FoliageBurst(ctx.Mark + Vector3.new(0, 1, 0), 1)
	move(CFrame.lookAt(eye + ctx.Face * -1.5, look), CFrame.lookAt(eye + ctx.Face * -2, look + Vector3.new(0, 10, 0)), 0.9, skipped, 46, 52, nil)
	if skipped() then return end
	-- 2. the grass tears open in a line, racing at the camera (handheld, backing away)
	local from = ctx.Mark - ctx.Face * ctx.Size
	local t0 = os.clock()
	local lastPuff = 0
	while os.clock() - t0 < 1.4 and not skipped() do
		local u = (os.clock() - t0) / 1.4
		local p = ground(from:Lerp(eye - ctx.Face * 6, u))
		if os.clock() - lastPuff > 0.09 then lastPuff = os.clock() DinosaurVFX.FoliageBurst(p + Vector3.new(0, 0.8, 0), 0.7) end
		cam.CFrame = CFrame.lookAt(eye + ctx.Face * (u * 3) + Vector3.new(0, 0.3, 0), p + Vector3.new(0, 1, 0)) * CFrame.Angles(math.noise(u * 9, 1) * 0.03, math.noise(u * 9, 4) * 0.03, 0)
		cam.FieldOfView = 50 + u * 10
		RunService.RenderStepped:Wait()
	end
	if skipped() then return end
	-- 3. a black shape leaps right across the lens (the lead, mid-pounce)
	local cross0 = eye - ctx.Face * 7 - ctx.Side * 9
	local cross1 = eye - ctx.Face * 7 + ctx.Side * 9
	ctx.Teleport(cross0, ctx.Side)
	playAny(ctx.Anim, { "Jump", "Pounce" })
	local t1 = os.clock()
	while os.clock() - t1 < 0.55 and not skipped() do
		local u = (os.clock() - t1) / 0.55
		local p = cross0:Lerp(cross1, u) + Vector3.new(0, math.sin(u * math.pi) * 3, 0)
		ctx.Root.CFrame = CFrame.lookAt(p, p + ctx.Side) * CFrame.new(0, ctx.Lift, 0)
		cam.CFrame = CFrame.lookAt(eye + Vector3.new(0, 0.6, 0), eye - ctx.Face * 7 + Vector3.new(0, 1.2, 0))
		cam.FieldOfView = 58
		RunService.RenderStepped:Wait()
	end
	punch(5)
	CineKit.ImpactFrame(0.5)
	-- back to its mark for the reveal (we cut away first)
	ctx.Teleport(ctx.Start, ctx.Face)
end

-- TRICERATOPS: a wall of ferns at the meadow's edge shudders with each heavy footfall; the horn tips push
-- through; then it smashes out and charges, skidding to a stop right in front of you
BEATS.ferns = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local wall = {}
	local wallAt = ctx.Start + ctx.Face * (ctx.Size * 0.75)
	for i = -4, 4 do
		local p = ground(wallAt + ctx.Side * (i * ctx.Size * 0.22))
		local h = ctx.Ext.Y * (0.95 + math.random() * 0.4)
		local f = prop(ctx.Set, { Size = Vector3.new(ctx.Size * 0.32, h, 1.4), Color = Color3.fromRGB(70 + math.random(0, 30), 150 + math.random(0, 40), 60), Material = Enum.Material.Grass, CFrame = CFrame.lookAt(p + Vector3.new(0, h / 2, 0), p + Vector3.new(0, h / 2, 0) + ctx.Face) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.3) })
		table.insert(wall, { Part = f, Base = f.CFrame })
	end
	local eye = wallAt + ctx.Face * (ctx.Size * 1.7 + 8) + Vector3.new(0, 1.4, 0)
	-- 1. the quiet meadow, the fern wall, and the ground jumping with each step behind it
	local t0 = os.clock()
	local steps = 0
	while os.clock() - t0 < 2.2 and not skipped() do
		local u = (os.clock() - t0) / 2.2
		local k = math.floor(u * 3)
		if k > steps then
			steps = k
			DinosaurVFX.Shake(0.25 + k * 0.12, 0.15)
			DinosaurVFX.FootstepDust(wallAt + ctx.Face * 2, 0.6 + k * 0.2)
			for _, w in ipairs(wall) do w.Part.CFrame = w.Base * CFrame.Angles(0.06 * k, 0, 0) end
		end
		for _, w in ipairs(wall) do w.Part.CFrame = w.Part.CFrame:Lerp(w.Base, 0.15) end
		cam.CFrame = CFrame.lookAt(eye - ctx.Face * (u * 3), wallAt + Vector3.new(0, ctx.Ext.Y * 0.45, 0))
		cam.FieldOfView = 44 - u * 4
		RunService.RenderStepped:Wait()
	end
	if skipped() then return end
	-- 2. tight on the ferns: the horns push through
	ctx.Walk(ctx.Start + ctx.Face * (ctx.Size * 0.42), 1.4, skipped, function(u)
		for _, w in ipairs(wall) do
			local wob = math.sin(os.clock() * 16 + w.Base.Position.X) * 0.08 * u
			w.Part.CFrame = w.Base * CFrame.Angles(wob, 0, wob * 0.5)
		end
		local hp = ctx.Head()
		cam.CFrame = CFrame.lookAt(wallAt + ctx.Face * (ctx.Size * 0.6 + 4) + ctx.Side * 2 + Vector3.new(0, ctx.Ext.Y * 0.35, 0), hp)
		cam.FieldOfView = 34
	end)
	if skipped() then return end
	-- 3. it smashes out of the ferns and charges at the camera, skids to a stop in its own dust
	for _, w in ipairs(wall) do shatter(ctx.Set, w.Part, ctx.Root.Position, 22) end
	CineKit.ImpactFrame(0.6)
	CineKit.SpeedLines(cine.Gui, 1.0)
	DinosaurVFX.FoliageBurst(wallAt + Vector3.new(0, ctx.Ext.Y * 0.5, 0), 1.6)
	playAny(ctx.Anim, { "TheCharge", "Charge" })
	local low = ctx.Mark + ctx.Face * (ctx.Size * 1.1 + 7) + ctx.Side * (ctx.Size * 0.45) + Vector3.new(0, 1, 0)
	ctx.Walk(ctx.Mark, 0.9, skipped, function(u)
		cam.CFrame = CFrame.lookAt(low, ctx.Root.Position + Vector3.new(0, ctx.Ext.Y * 0.2, 0))
		cam.FieldOfView = 52 + u * 8
	end)
	DinosaurVFX.DustWave(ground(ctx.Mark), ctx.Face, 1.2)
	DinosaurVFX.Shake(1.1, 0.35)
end

-- PARASAUROLOPHUS: golden hour by the water; crests standing out black against a low sun over the brush;
-- the lead lifts its head and calls; the others answer from the reeds
BEATS.call = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local herd = {}
	for _, k in ipairs({ -1, 1 }) do
		local p = ground(ctx.Start - ctx.Face * (ctx.Size * 0.5) + ctx.Side * k * (ctx.Size * 0.9))
		local e, ea = standIn(ctx.Species, 0.85, CFrame.lookAt(p, p + ctx.Face + ctx.Side * k * 0.3))
		if e then e.Parent = ctx.Set silhouette(e, false) table.insert(herd, { Model = e, Anim = ea }) end
	end
	ctx.Extras = {}
	for _, h in ipairs(herd) do table.insert(ctx.Extras, h.Model) end
	-- a line of reeds/brush between you and them
	for i = -6, 6 do
		local p = ground(ctx.Start + ctx.Face * (ctx.Size * 0.9) + ctx.Side * (i * ctx.Size * 0.18))
		local h = ctx.Ext.Y * (0.5 + math.random() * 0.2)
		prop(ctx.Set, { Size = Vector3.new(0.7, h, 0.7), Color = Color3.fromRGB(110, 140, 60), Material = Enum.Material.Grass, CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.25) })
	end
	local eye = ctx.Start + ctx.Face * (ctx.Size * 3.2 + 10) - Vector3.new(0, 0.6, 0)
	-- 1. low behind the reeds, the sun behind the herd: only the crests above the brush
	move(CFrame.lookAt(eye + ctx.Side * 6, ctx.Head() + Vector3.new(0, 1, 0)), CFrame.lookAt(eye + ctx.Side * 2, ctx.Head() + Vector3.new(0, 1, 0)), 2.4, skipped, 38, 34, nil)
	if skipped() then return end
	-- 2. the lead lifts its head and calls; rings roll out across the water
	playAny(ctx.Anim, { "HerdCall", "Roar" })
	task.delay(0.5, function() DinosaurVFX.SoundRings(ctx.Model, "VFX_Head", 1.6) end)
	local hp = ctx.Head()
	move(CFrame.lookAt(hp + ctx.Face * (ctx.Size * 0.6 + 6) - Vector3.new(0, 3, 0), hp), CFrame.lookAt(hp + ctx.Face * (ctx.Size * 0.5 + 5) - Vector3.new(0, 2, 0), hp + Vector3.new(0, 1, 0)), 1.8, skipped, 32, 28, nil)
	if skipped() then return end
	-- 3. the herd answers, one after the other
	for i, h in ipairs(herd) do
		task.delay(0.25 * i, function() playAny(h.Anim, { "HerdResponse", "Roar" }) end)
	end
	move(CFrame.lookAt(eye + Vector3.new(0, 4, 0), ctx.Start + Vector3.new(0, ctx.Ext.Y * 0.6, 0)), CFrame.lookAt(eye + Vector3.new(0, 6, 0) - ctx.Face * 4, ctx.Start + Vector3.new(0, ctx.Ext.Y * 0.6, 0)), 1.4, skipped, 50, 46, nil)
end

-- STEGOSAURUS: over a hedge of brush only the plates show, sliding along like a fin; it stops, the plates
-- flush red; then the tail comes round and blows the hedge apart
BEATS.plates = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local hedge = {}
	local hedgeAt = ctx.Mark + ctx.Face * (ctx.Size * 0.9)
	for i = -6, 6 do
		local p = ground(hedgeAt + ctx.Side * (i * ctx.Size * 0.2))
		local h = ctx.Ext.Y * 0.62
		table.insert(hedge, prop(ctx.Set, { Size = Vector3.new(ctx.Size * 0.28, h, ctx.Size * 0.25), Color = Color3.fromRGB(60, 120 + (i % 3) * 14, 50), Material = Enum.Material.Grass, CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, i, 0) }))
	end
	local from = ground(ctx.Mark - ctx.Side * ctx.Size * 1.8)
	ctx.Teleport(from, ctx.Side)
	local eye = hedgeAt + ctx.Face * (ctx.Size * 1.4 + 6) + Vector3.new(0, ctx.Ext.Y * 0.45, 0)
	-- 1. the plates gliding along above the hedge, the camera panning with them
	ctx.Walk(ground(ctx.Mark), 2.6, skipped, function()
		cam.CFrame = CFrame.lookAt(eye, ctx.Root.Position + Vector3.new(0, ctx.Ext.Y * 0.25, 0))
		cam.FieldOfView = 40
	end, ctx.Side)
	if skipped() then return end
	-- 2. it stops. tight on the plates as they flush blood-red
	DinosaurVFX.PlateFlush(ctx.Model, 4)
	local top = ctx.Root.Position + Vector3.new(0, ctx.Ext.Y * 0.4, 0)
	move(CFrame.lookAt(top + ctx.Face * (ctx.Size * 0.6 + 4) + Vector3.new(0, 1, 0), top), CFrame.lookAt(top + ctx.Face * (ctx.Size * 0.5 + 3) + Vector3.new(0, 0.6, 0), top), 1.3, skipped, 34, 30, nil)
	if skipped() then return end
	-- 3. the tail swings round: the hedge explodes
	ctx.Turn(ctx.Face, 0.35)
	playAny(ctx.Anim, { "TailSweep", "Attack" })
	task.delay(0.35, function()
		for _, h in ipairs(hedge) do if h.Parent then shatter(ctx.Set, h, ctx.Root.Position, 26) end end
		CineKit.ImpactFrame(0.6)
		DinosaurVFX.FoliageBurst(hedgeAt + Vector3.new(0, 2, 0), 1.6)
		DinosaurVFX.Shake(0.9, 0.3)
	end)
	move(CFrame.lookAt(eye, hedgeAt), CFrame.lookAt(eye + ctx.Face * 2, hedgeAt + Vector3.new(0, 1, 0)), 0.9, skipped, 46, 52, nil)
end

-- ANKYLOSAURUS: a boulder, close; a dull thud; the club comes round and splits it; through the dust the
-- armoured back, spikes catching the light
BEATS.club = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local rockAt = ground(ctx.Start + ctx.Face * (ctx.Size * 0.55) + ctx.Side * (ctx.Size * 0.45))
	local r = ctx.Size * 0.34
	local rock = prop(ctx.Set, { Size = Vector3.new(r, r * 0.8, r), Color = Color3.fromRGB(120, 116, 110), Material = Enum.Material.Slate, CFrame = CFrame.new(rockAt + Vector3.new(0, r * 0.4, 0)) * CFrame.Angles(0.2, 0.7, 0.1) })
	local eye = rockAt + ctx.Face * (r * 3 + 4) - ctx.Side * (r * 1.2) + Vector3.new(0, r * 0.4, 0)
	-- 1. the boulder, still. a thud from behind it shakes the frame
	move(CFrame.lookAt(eye, rockAt + Vector3.new(0, r * 0.4, 0)), CFrame.lookAt(eye - ctx.Face * 1.2, rockAt + Vector3.new(0, r * 0.4, 0)), 1.2, skipped, 40, 38, nil)
	DinosaurVFX.Shake(0.35, 0.15)
	DinosaurVFX.FootstepDust(rockAt, 0.8)
	hold(0.5, skipped)
	if skipped() then return end
	-- 2. the club smashes it apart
	playAny(ctx.Anim, { "ClubSmash", "Attack" })
	DinosaurVFX.TailSwing(ctx.Model, 0.8)
	hold(0.4, skipped)
	DinosaurVFX.Debris(rock.Position, 1.8, rock.Color)
	DinosaurVFX.GroundImpact(rockAt, 1.2)
	DinosaurVFX.Shake(1.0, 0.35)
	shatter(ctx.Set, rock, ctx.Root.Position, 42)
	punch(6)
	CineKit.ImpactFrame(0.9)
	CineKit.HitStop(0.12)
	-- 3. through the settling dust: the spiked back, low and slow
	local back = ctx.Root.Position + Vector3.new(0, ctx.Ext.Y * 0.35, 0)
	move(CFrame.lookAt(back + ctx.Side * (ctx.Size * 0.7) + ctx.Face * (ctx.Size * 0.4) + Vector3.new(0, 0.5, 0), back), CFrame.lookAt(back + ctx.Side * (ctx.Size * 0.55) + ctx.Face * (ctx.Size * 0.6) + Vector3.new(0, 1.2, 0), back), 1.6, skipped, 40, 46, nil)
end

-- BRACHIOSAURUS: pebbles jump with every step; birds explode out of the canopy; the long tilt from its feet,
-- up the neck, to a head against the sun... which comes down to look at you
BEATS.tremor = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local base = ctx.Mark + ctx.Face * (ctx.Size * 0.5 + 6)
	local stones = {}
	for i = 1, 8 do
		local p = ground(base + ctx.Side * ((i - 4.5) * 0.9) + ctx.Face * (math.random() * 2))
		table.insert(stones, prop(ctx.Set, { Size = Vector3.new(0.5, 0.4, 0.5), Color = Color3.fromRGB(130, 120, 100), Material = Enum.Material.Slate, CFrame = CFrame.new(p + Vector3.new(0, 0.2, 0)) }))
	end
	-- 1. ground level: the pebbles jump at each step, harder each time
	for k = 1, 3 do
		if skipped() then return end
		DinosaurVFX.Shake(0.3 + k * 0.18, 0.25)
		for _, s in ipairs(stones) do
			local c0 = s.CFrame
			TweenService:Create(s, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { CFrame = c0 + Vector3.new(0, 0.4 + k * 0.25, 0) }):Play()
		end
		cam.CFrame = CFrame.lookAt(base + ctx.Face * 5 + Vector3.new(0, 0.6, 0), base)
		cam.FieldOfView = 38
		hold(0.65, skipped)
	end
	if skipped() then return end
	-- 2. the treetops: a flock bursts out and away
	local canopy = ctx.Start + Vector3.new(0, ctx.Ext.Y * 0.9, 0)
	birdsUp(ctx.Set, canopy, 12, 20)
	DinosaurVFX.FallingLeaves(canopy, 16, 22, 10)
	move(CFrame.lookAt(base + ctx.Face * 12 + Vector3.new(0, 3, 0), canopy), CFrame.lookAt(base + ctx.Face * 10 + Vector3.new(0, 2, 0), canopy + Vector3.new(0, 8, 0)), 1.2, skipped, 50, 54, nil)
	if skipped() then return end
	-- 3. the tilt: feet... legs... neck... a head up in the sun
	ctx.Teleport(ctx.Mark, ctx.Face)
	local eye = ctx.Mark + ctx.Face * (ctx.Size * 0.9 + 6) + Vector3.new(0, 2, 0)
	local t0 = os.clock()
	while os.clock() - t0 < 2.8 and not skipped() do
		local u = (os.clock() - t0) / 2.8
		local e = u * u * (3 - 2 * u)
		cam.CFrame = CFrame.lookAt(eye, ctx.Mark + Vector3.new(0, 2, 0):Lerp(ctx.Head() - ctx.Mark, e))
		cam.FieldOfView = 60
		RunService.RenderStepped:Wait()
	end
end

-- CARNOTAURUS: ash drifting through a fire glow; the horns' black outline behind a rock; it steps out, stalking,
-- head low... and snaps round toward you
BEATS.ember = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local glow = prop(ctx.Set, { Size = Vector3.new(ctx.Size * 2.6, ctx.Ext.Y * 1.6, 1), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Transparency = 0.35, CastShadow = false, CFrame = CFrame.lookAt(ctx.Start - ctx.Face * (ctx.Size * 1.2) + Vector3.new(0, ctx.Ext.Y * 0.6, 0), ctx.Start + Vector3.new(0, ctx.Ext.Y * 0.6, 0)) })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 70, 20))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.25, 0)
	emitter.Lifetime = NumberRange.new(2, 3.5)
	emitter.Rate = 70
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, 2, 0)
	emitter.Parent = glow
	local rockAt = ground(ctx.Start + ctx.Face * (ctx.Size * 0.6) - ctx.Side * (ctx.Size * 0.3))
	local rh = ctx.Ext.Y * 0.8
	prop(ctx.Set, { Size = Vector3.new(ctx.Size * 0.8, rh, ctx.Size * 0.5), Color = Color3.fromRGB(70, 60, 58), Material = Enum.Material.Slate, CFrame = CFrame.new(rockAt + Vector3.new(0, rh / 2, 0)) * CFrame.Angles(0, 0.4, 0.06) })
	local eye = ctx.Start + ctx.Face * (ctx.Size * 2 + 8) + ctx.Side * (ctx.Size * 0.6) + Vector3.new(0, 1.2, 0)
	-- 1. the glow, the drifting embers, the rock... and horns rising above it
	move(CFrame.lookAt(eye, rockAt + Vector3.new(0, rh, 0)), CFrame.lookAt(eye - ctx.Face * 2, ctx.Head()), 2.2, skipped, 40, 36, nil)
	if skipped() then return end
	-- 2. it slides out from behind the rock, head low, stalking along the frame
	ctx.Walk(ctx.Start + ctx.Face * (ctx.Size * 0.4) + ctx.Side * (ctx.Size * 0.6), 1.8, skipped, function(u)
		cam.CFrame = CFrame.lookAt(eye - ctx.Face * (2 + u), ctx.Root.Position + Vector3.new(0, ctx.Ext.Y * 0.3, 0))
		cam.FieldOfView = 36
	end, (ctx.Face + ctx.Side).Unit)
	if skipped() then return end
	-- 3. it snaps round to face you and charges
	ctx.Turn(ctx.Face, 0.2)
	playAny(ctx.Anim, { "Ambush", "HornShove", "Attack" })
	DinosaurVFX.ChargeDust(ctx.Model, 1)
	CineKit.SpeedLines(cine.Gui, 0.9, Color3.fromRGB(255, 200, 150))
	ctx.Walk(ctx.Mark, 0.8, skipped, function(u)
		cam.CFrame = CFrame.lookAt(eye - ctx.Face * 3, ctx.Head())
		cam.FieldOfView = 36 + u * 14
	end)
end

-- SPINOSAURUS (river set): only the sail, cutting up the river toward you; it sinks out of sight; the water
-- goes still; then it bursts up right in front of the lens
BEATS.fin = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local along = Vector3.new(1, 0, 0)
	local from = Vector3.new(ctx.Mark.X - ctx.Size * 4, 0, ctx.Mark.Z)
	ctx.Teleport(from, along)
	sinkTo(ctx.Model, ctx.WaterY, 0.88)
	local lift = ctx.Root.Position.Y - ctx.WaterY
	local eye = ctx.Mark + Vector3.new(ctx.Size * 1.2, 0, 26) + Vector3.new(0, ctx.WaterY + 1.4, 0)
	-- 1. the sail gliding up the river, wake splashing
	local t0 = os.clock()
	local lastSplash = 0
	while os.clock() - t0 < 2.8 and not skipped() do
		local u = (os.clock() - t0) / 2.8
		local p = from:Lerp(Vector3.new(ctx.Mark.X - ctx.Size * 0.6, 0, ctx.Mark.Z), u)
		ctx.Root.CFrame = CFrame.lookAt(Vector3.new(p.X, ctx.WaterY + lift, p.Z), Vector3.new(p.X, ctx.WaterY + lift, p.Z) + along)
		if os.clock() - lastSplash > 0.3 then lastSplash = os.clock() DinosaurVFX.WaterSplash(Vector3.new(p.X, ctx.WaterY, p.Z) + along * ctx.Size * 0.4, 0.5) end
		cam.CFrame = CFrame.lookAt(eye, Vector3.new(p.X, ctx.WaterY + ctx.Ext.Y * 0.25, p.Z))
		cam.FieldOfView = 44
		RunService.RenderStepped:Wait()
	end
	if skipped() then return end
	-- 2. the sail slides under. the water settles. nothing.
	local start = ctx.Root.CFrame
	local t1 = os.clock()
	while os.clock() - t1 < 0.6 do
		local u = (os.clock() - t1) / 0.6
		ctx.Root.CFrame = start - Vector3.new(0, ctx.Ext.Y * 0.6 * u, 0)
		RunService.RenderStepped:Wait()
	end
	DinosaurVFX.WaterSplash(Vector3.new(ctx.Root.Position.X, ctx.WaterY, ctx.Root.Position.Z), 0.4)
	cam.CFrame = CFrame.lookAt(ctx.Mark + ctx.Face * 14 + Vector3.new(0, ctx.WaterY + 1.2, 0), Vector3.new(ctx.Mark.X, ctx.WaterY + 1, ctx.Mark.Z))
	cam.FieldOfView = 46
	hold(1.3, skipped)
	ctx.Teleport(Vector3.new(ctx.Mark.X, 0, ctx.Mark.Z), ctx.Face)
	ctx.Rise = 0.55 -- the reveal lifts it out of the water
	ctx.Breach = true
end

-- T. REX: a puddle on the path; rings jump out of it at every footfall; a tree at the clearing's edge shakes...
-- and falls; it walks out over the trunk
BEATS.ripple = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local at = ground(ctx.Mark + ctx.Face * (ctx.Size * 0.9 + 5))
	local puddle = prop(ctx.Set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 5, 5), Color = Color3.fromRGB(70, 110, 130), Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.3, CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	local treeAt = ground(ctx.Start + ctx.Face * (ctx.Size * 0.45) + ctx.Side * (ctx.Size * 0.25))
	local t = tree(ctx.Set, treeAt, ctx.Ext.Y * 1.1)
	-- 1. the puddle; rings at each thud, louder each time
	cam.CFrame = CFrame.lookAt(at + ctx.Face * 3.4 + Vector3.new(0, 1.6, 0), at)
	cam.FieldOfView = 34
	for k = 1, 4 do
		if skipped() then return end
		hold(0.62, skipped)
		DinosaurVFX.Shake(0.22 + k * 0.12, 0.2)
		for j = 1, 2 do
			local ring = prop(ctx.Set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.6, 0.6), Color = Color3.fromRGB(200, 230, 240), Material = Enum.Material.Neon, Transparency = 0.4, CastShadow = false, CFrame = puddle.CFrame + Vector3.new(0, 0.06, 0) })
			TweenService:Create(ring, TweenInfo.new(0.7 + j * 0.25), { Size = Vector3.new(0.05, 4.4, 4.4), Transparency = 1 }):Play()
		end
	end
	if skipped() then return end
	-- 2. the tree at the edge of the clearing shudders... and goes over
	local eye = ctx.Mark + ctx.Face * (ctx.Size * 1.6 + 10) + Vector3.new(0, 2, 0)
	local treeTop = treeAt + Vector3.new(0, ctx.Ext.Y * 0.9, 0)
	for _, p in ipairs(t) do
		local c0 = p.CFrame
		TweenService:Create(p, TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 6, true), { CFrame = c0 * CFrame.new(0.25, 0, 0) }):Play()
	end
	move(CFrame.lookAt(eye, treeTop), CFrame.lookAt(eye - ctx.Face * 1.5, treeTop), 1.0, skipped, 44, 42, nil)
	birdsUp(ctx.Set, treeTop, 7, 6)
	topple(t, treeAt, ctx.Face + ctx.Side * 0.4, 1.1)
	move(CFrame.lookAt(eye - ctx.Face * 1.5, treeTop), CFrame.lookAt(eye - ctx.Face * 2, treeAt + ctx.Face * 6), 1.2, skipped, 42, 46, nil)
	if skipped() then return end
	-- 3. eyes, low, through the gap where the tree stood
	ctx.EyesShot(skipped)
end

-- GIGANOTOSAURUS: bright day; a shadow slides over the ground and the light drops; a foot slams down right
-- beside the camera; we look up the leg as the head lowers into the frame
BEATS.shadow = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local spot = ctx.Mark + ctx.Face * (ctx.Size * 0.55)
	local shade = prop(ctx.Set, { Size = Vector3.new(ctx.Size * 1.4, 0.1, ctx.Size * 0.8), Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic, Transparency = 1, CastShadow = false, CFrame = CFrame.new(ground(spot - ctx.Side * ctx.Size * 2) + Vector3.new(0, 0.15, 0)) })
	-- 1. the ground, the light... a shadow slides across
	TweenService:Create(shade, TweenInfo.new(2.2, Enum.EasingStyle.Sine), { CFrame = CFrame.new(ground(spot) + Vector3.new(0, 0.15, 0)), Transparency = 0.45 }):Play()
	TweenService:Create(ctx.Dark, TweenInfo.new(2.2), { Brightness = -0.2 }):Play()
	local eye = spot + ctx.Face * 6 + Vector3.new(0, 1.2, 0)
	move(CFrame.lookAt(eye, spot - ctx.Face * 6), CFrame.lookAt(eye + Vector3.new(0, -0.4, 0), spot), 2.2, skipped, 50, 48, nil)
	if skipped() then return end
	-- 2. the foot comes down beside the lens
	ctx.Teleport(ctx.Mark, ctx.Face)
	DinosaurVFX.GroundImpact(spot, 1.6)
	DinosaurVFX.GroundCracks(spot, 1.4)
	DinosaurVFX.Shake(1.2, 0.4)
	punch(6)
	CineKit.ImpactFrame(1)
	CineKit.HitStop(0.14)
	hold(0.5, skipped)
	-- 3. tilt up into its jaw, right overhead
	local t0 = os.clock()
	while os.clock() - t0 < 1.8 and not skipped() do
		local u = (os.clock() - t0) / 1.8
		local e = u * u * (3 - 2 * u)
		cam.CFrame = CFrame.lookAt(eye, spot:Lerp(ctx.Head(), e))
		cam.FieldOfView = 50 + e * 12
		RunService.RenderStepped:Wait()
	end
end

-- MOSASAURUS (open sea): beneath the surface something enormous slides past in the blue, one eye lit; up top
-- the sea is flat calm, a few bubbles... and it breaches
BEATS.deep = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local across = ctx.Side
	local depth = ctx.WaterY - ctx.Ext.Y * 1.1 - 3
	local from = ctx.Mark - across * ctx.Size * 2.2 + ctx.Face * (ctx.Size * 0.4)
	local to = ctx.Mark + across * ctx.Size * 1.2 + ctx.Face * (ctx.Size * 0.4)
	ctx.Teleport(Vector3.new(from.X, 0, from.Z), across)
	local eye = ctx.Mark + ctx.Face * (ctx.Size * 1.9 + 8) + Vector3.new(0, ctx.WaterY - 3, 0)
	if ctx.Anim then ctx.Anim:SetLocomotion("Walk", 0.2) end
	-- 1. under the water: the shape glides past
	local t0 = os.clock()
	while os.clock() - t0 < 3.4 and not skipped() do
		local u = (os.clock() - t0) / 3.4
		local p = from:Lerp(to, u)
		ctx.Root.CFrame = CFrame.lookAt(Vector3.new(p.X, depth + ctx.Lift, p.Z), Vector3.new(p.X, depth + ctx.Lift, p.Z) + across)
		cam.CFrame = CFrame.lookAt(eye, Vector3.new(p.X, depth + ctx.Lift * 0.6, p.Z))
		cam.FieldOfView = 56
		RunService.RenderStepped:Wait()
	end
	if skipped() then return end
	-- 2. up top: flat calm. bubbles. closer bubbles.
	ctx.Teleport(Vector3.new(ctx.Mark.X, 0, ctx.Mark.Z), ctx.Face)
	ctx.Root.CFrame += Vector3.new(0, depth + ctx.Lift - ctx.Root.Position.Y, 0)
	local top = ctx.Mark + ctx.Face * (ctx.Size * 2 + 10) + Vector3.new(0, ctx.WaterY + 3, 0)
	cam.CFrame = CFrame.lookAt(top, Vector3.new(ctx.Mark.X, ctx.WaterY + 2, ctx.Mark.Z))
	cam.FieldOfView = 48
	for k = 1, 4 do
		DinosaurVFX.WaterSplash(Vector3.new(ctx.Mark.X, ctx.WaterY, ctx.Mark.Z) + ctx.Side * (k - 2.5) * 2.5, 0.2 + k * 0.08)
		hold(0.32, skipped)
	end
	ctx.Rise = 0.45
	ctx.Breach = true
end

-- PRIMAL REX: the lab - red alarm light pulsing; something huge behind the containment glass; it hits the glass,
-- the glass cracks; it hits it again; the glass goes
BEATS.breach = function(ctx, skipped)
	local cam = Workspace.CurrentCamera
	local glassAt = ctx.Start + ctx.Face * (ctx.Size * 0.8)
	local glass = prop(ctx.Set, { Size = Vector3.new(ctx.Size * 2.2, ctx.Ext.Y * 1.3, 0.6), Color = Color3.fromRGB(170, 220, 255), Material = Enum.Material.Glass, Transparency = 0.55, Reflectance = 0.2, CFrame = CFrame.lookAt(glassAt + Vector3.new(0, ctx.Ext.Y * 0.65, 0), glassAt + Vector3.new(0, ctx.Ext.Y * 0.65, 0) + ctx.Face) })
	-- frame posts either side
	for _, k in ipairs({ -1, 1 }) do
		prop(ctx.Set, { Size = Vector3.new(1.4, ctx.Ext.Y * 1.4, 1.4), Color = Color3.fromRGB(70, 74, 82), Material = Enum.Material.Metal, CFrame = CFrame.new(glassAt + ctx.Side * k * (ctx.Size * 1.1) + Vector3.new(0, ctx.Ext.Y * 0.7, 0)) })
	end
	DinosaurVFX.Alarm(ctx.Model, 8)
	local eye = glassAt + ctx.Face * (ctx.Size * 1.3 + 6) + Vector3.new(0, ctx.Ext.Y * 0.4, 0)
	local function pulse(dur: number)
		local t0 = os.clock()
		while os.clock() - t0 < dur and not skipped() do
			local p = (math.sin((os.clock() - t0) * 7) + 1) / 2
			ctx.Dark.TintColor = Color3.fromRGB(255, 90 + p * 60, 90 + p * 60)
			RunService.RenderStepped:Wait()
		end
	end
	-- 1. the red light, the glass, a shape behind it
	cam.CFrame = CFrame.lookAt(eye, glassAt + Vector3.new(0, ctx.Ext.Y * 0.5, 0))
	cam.FieldOfView = 46
	pulse(1.8)
	if skipped() then return end
	-- 2. it hits the glass: a crack. again: more cracks
	for hit = 1, 2 do
		playAny(ctx.Anim, { "Attack" })
		hold(0.35, skipped)
		DinosaurVFX.Shake(0.6 + hit * 0.3, 0.3)
		for _ = 1, 4 + hit * 3 do
			local a = math.random() * math.pi * 2
			local len = 2 + math.random() * (2 + hit * 2)
			local c = glassAt + Vector3.new(0, ctx.Ext.Y * 0.65, 0) + ctx.Side * (math.random() - 0.5) * 3 + Vector3.new(0, (math.random() - 0.5) * 3, 0)
			prop(ctx.Set, { Size = Vector3.new(0.12, len, 0.65), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.2, CastShadow = false, CFrame = CFrame.lookAt(c, c + ctx.Face) * CFrame.Angles(0, 0, a) })
		end
		local close = glassAt + ctx.Face * (ctx.Size * 0.5 + 3) + Vector3.new(0, ctx.Ext.Y * 0.55, 0)
		cam.CFrame = CFrame.lookAt(hit == 1 and close or eye, glassAt + Vector3.new(0, ctx.Ext.Y * 0.6, 0))
		cam.FieldOfView = hit == 1 and 40 or 50
		pulse(0.9)
		if skipped() then return end
	end
	-- 3. it goes through
	shatter(ctx.Set, glass, ctx.Root.Position, 55)
	DinosaurVFX.Shake(1.3, 0.4)
	punch(8)
	CineKit.ImpactFrame(1.1)
	CineKit.HitStop(0.14)
end

-- 2026-10-12 roster expansion: each new era's reveal beats live in Game/Reveals/<Era>.luau, which returns
-- function(BEATS, REVEAL, H) and adds BEATS.<beat> plus REVEAL.<Species> (so parallel work never edits this file)
do
	local folder = script.Parent:FindFirstChild("Reveals")
	if folder then
		local H = {
			move = move, hold = hold, ground = ground, standIn = standIn, scaleOf = scaleOf, siteScale = siteScale, herdAt = herdAt,
			clearSpot = clearSpot, safeCam = safeCam, fade = fade, flash = flash, prop = prop, silhouette = silhouette,
			shatter = shatter, birdsUp = birdsUp, tree = tree, topple = topple, playAny = playAny, sinkTo = sinkTo,
			burst = burst, punch = punch, LEAF = LEAF, CineKit = CineKit, DinosaurVFX = DinosaurVFX, Audio = Audio, Config = Config,
		}
		-- (two eras naming a beat the same silently replaced one era's reveal with the other's - Plateosaurus played
		-- Microraptor's canopy scene: a clash now says so)
		local function guard(t, what: string, owner: string)
			return setmetatable({}, {
				__index = t,
				__newindex = function(_, k, v)
					if rawget(t, k) ~= nil then warn("[EraView] reveals " .. owner .. " overwrites " .. what .. "." .. tostring(k)) end
					rawset(t, k, v)
				end,
			})
		end
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("ModuleScript") then
				local ok, fn = pcall(require, m)
				if ok and type(fn) == "function" then
					local ok2, err = pcall(fn, guard(BEATS, "BEATS", m.Name), guard(REVEAL, "REVEAL", m.Name), H)
					if not ok2 then warn("[EraView] reveals " .. m.Name .. ": " .. tostring(err)) end
				else
					warn("[EraView] reveals " .. m.Name .. " failed to load: " .. tostring(fn))
				end
			end
		end
	end
end

-- mystery -> reveal, on location
function View.PreviewReveal(species: string, opts: any?)
	local R = REVEAL[species] or { Kick = "", Beat = "pack", Act = { "Roar" }, Hero = "Low" }
	onStage(species, function(g: Vector3, face: Vector3, set: Instance?, waterY: number?)
		local name, sub, color = speciesCard(species)
		local side = face:Cross(Vector3.yAxis)
		local probe = standIn(species, siteScale(species), CFrame.lookAt(g, g + face))
		if not probe then return end
		local _, ext = probe:GetBoundingBox()
		probe:Destroy()
		local size = math.max(ext.X, ext.Y, ext.Z)
		local big = size > 22
		-- its mark is just in front of its nest (on the camera side), never on top of the eggs
		if not waterY then
			g = ground(g + face * 3.5)
			-- and somewhere it fits: never through a post, a rock, a trunk or the nest itself (2026-10-14) - stepped
			-- out sideways or forward to the nearest spot with room
			local function room(q: Vector3): boolean
				return Floor.Free(CFrame.lookAt(q, q + face) + Vector3.new(0, ext.Y / 2 + 0.6, 0), Vector3.new(ext.X * 0.85, math.max(1, ext.Y - 1.2), ext.Z * 0.85))
			end
			if not room(g) then
				for _, o in ipairs({ side * 3, -side * 3, face * 3, side * 6, -side * 6, face * 6 + side * 3, face * 6 - side * 3, face * 9 }) do
					local q = ground(g + o)
					if math.abs(q.Y - g.Y) < math.max(3, ext.Y * 0.3) and room(q) then g = q break end
				end
			end
		end
		local back = waterY and 0 or (size * 0.9 + 6)
		-- it walks in on a line it can really walk: nothing solid in the way, no ledge to step off
		local approach = face
		local start = g
		if not waterY then start, approach = clearApproach(g, face, back, ext.Y, math.max(ext.X, 3)) end
		local m, anim = standIn(species, siteScale(species), CFrame.lookAt(start, start + approach))
		if not m then return end
		if set then m.Parent = set end
		m:SetAttribute("DisplayName", name)
		local root = m.PrimaryPart :: BasePart
		local lift = root.Position.Y - start.Y
		local sil = silhouette(m, R.Beat ~= "call")
		local cleared = clearPath(m, back)
		local dark = Instance.new("ColorCorrectionEffect")
		dark.Name = "DinoRevealDark"
		dark.Parent = Lighting
		local mood = R.Warm and { Brightness = -0.06, Saturation = -0.2, Contrast = 0.2, TintColor = Color3.fromRGB(255, 200, 150) }
			or R.Ember and { Brightness = -0.12, Saturation = -0.3, Contrast = 0.25, TintColor = Color3.fromRGB(255, 160, 120) }
			or R.Alarm and { Brightness = -0.16, Saturation = -0.6, Contrast = 0.3, TintColor = Color3.fromRGB(255, 120, 120) }
			or R.Beat == "shadow" and { Brightness = 0.02, Saturation = 0, Contrast = 0.05, TintColor = Color3.new(1, 1, 1) }
			or { Brightness = -0.14, Saturation = -0.5, Contrast = 0.22, TintColor = Color3.fromRGB(190, 200, 255) }
		TweenService:Create(dark, TweenInfo.new(0.6), mood):Play()
		local ctx = {
			Species = species, Model = m, Anim = anim, Root = root, Lift = lift, Set = set or Workspace, Mark = g, Start = start,
			Face = face, Side = side, Size = size, Ext = ext, Big = big, WaterY = waterY, Dark = dark,
		} :: any
		function ctx.Head(): Vector3
			local h = DinosaurVFX.findAttachment(m, "VFX_Head")
			return h and h.WorldPosition or (root.Position + Vector3.new(0, ext.Y * 0.35, 0))
		end
		function ctx.Teleport(p: Vector3, dir: Vector3)
			local gp = waterY and Vector3.new(p.X, root.Position.Y - lift, p.Z) or ground(p)
			root.CFrame = CFrame.lookAt(gp, gp + dir) * CFrame.new(0, lift, 0)
		end
		function ctx.Turn(dir: Vector3, t: number)
			local from = root.CFrame
			local to = CFrame.lookAt(root.Position, root.Position + dir)
			local t0 = os.clock()
			while os.clock() - t0 < t do
				root.CFrame = from:Lerp(to, (os.clock() - t0) / t)
				RunService.RenderStepped:Wait()
			end
			root.CFrame = to
		end
		-- walk the dino from where it is to `to` over dur, calling camFn(u) each frame. It faces the way it walks and
		-- turns to `dir` (default: the camera side) as it arrives; its legs match its real speed
		function ctx.Walk(to: Vector3, dur: number, skipped, camFn, dir: Vector3?)
			local from = root.Position - Vector3.new(0, lift, 0)
			local d = dir or face
			local travel = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			local heading = travel.Magnitude > 0.5 and travel.Unit or d
			local speed = travel.Magnitude / math.max(dur, 0.05)
			if anim then anim:SetLocomotion(speed > 14 and "Run" or "Walk", 0.2) end
			local t0 = os.clock()
			local last = t0
			while os.clock() - t0 < dur and not skipped() do
				local now = os.clock()
				local u = (now - t0) / dur
				local p = waterY and from:Lerp(to, u) or ground(from:Lerp(to, u))
				local turn = math.clamp((u - 0.7) / 0.3, 0, 1)
				local look = heading:Lerp(d, turn * turn * (3 - 2 * turn))
				if look.Magnitude < 0.05 then look = d end
				root.CFrame = CFrame.lookAt(p, p + look) * CFrame.new(0, lift, 0)
				pace(anim, speed, now - last)
				last = now
				if camFn then camFn(u) end
				RunService.RenderStepped:Wait()
			end
			if anim then anim:SetLocomotion("Idle", 0.3) end
		end
		function ctx.EyesShot(skipped)
			local hp = ctx.Head()
			local e1 = CFrame.lookAt(hp + face * (size * 0.35 + 4) + side * 1.5 + Vector3.new(0, 0.3, 0), hp)
			local e2 = CFrame.lookAt(hp + face * (size * 0.28 + 3) + side * 0.6, hp)
			move(e1, e2, 1.1, skipped, 34, 28, hp)
		end
		local revealed = false
		scene(function(skipped)
			-- the beats film it from raw cameras: the real map's bushes and ferns between the lens and the dino fade as
			-- it goes (the set's own props never do - they're the shot)
			lensGuard = function() return m.Parent and ctx.Head() or nil end
			-- no captions while the mystery plays: the picture, the light and the sound tell it
			fade(0, 0.6)
			local beat = BEATS[R.Beat]
			if beat then beat(ctx, skipped) end
			if skipped() then return end
			-- REVEAL: light floods in, it steps out (or rises out of the water) and lets you have it
			revealed = true
			flash(0.45)
			CineKit.BigHit(cine.Gui, math.clamp(size / 14, 0.8, 1.6))
			slamBars()
			sil:Destroy()
			for _, e in ipairs(ctx.Extras or {}) do for _, h in ipairs(e:GetChildren()) do if h:IsA("Highlight") then h:Destroy() end end end
			TweenService:Create(dark, TweenInfo.new(0.3), { Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
			if waterY and ctx.Rise then
				-- out of the water: a fast rise with the spray
				local y0 = root.Position.Y
				sinkTo(m, waterY, ctx.Rise)
				local y1 = root.Position.Y
				root.CFrame += Vector3.new(0, y0 - y1, 0)
				DinosaurVFX.WaterSplash(Vector3.new(root.Position.X, waterY, root.Position.Z), ctx.Breach and 2.2 or 1.4)
				local t0 = os.clock()
				while os.clock() - t0 < 0.5 do
					local u = (os.clock() - t0) / 0.5
					local cf = root.CFrame
					root.CFrame = CFrame.new(cf.Position.X, y0 + (y1 - y0) * (1 - (1 - u) ^ 2), cf.Position.Z) * cf.Rotation
					RunService.RenderStepped:Wait()
				end
			elseif not waterY and not R.AtMark then
				ctx.Walk(ground(g), 0.9, skipped, nil)
			end
			-- a pack rises out of the grass around its leader
			for i, x in ipairs(ctx.Pack or {}) do
				task.delay(0.08 * i, function()
					if not x.Root.Parent then return end
					TweenService:Create(x.Root, TweenInfo.new(0.35, Enum.EasingStyle.Back), { CFrame = x.Root.CFrame + Vector3.new(0, x.Rise, 0) }):Play()
					DinosaurVFX.FoliageBurst(x.Root.Position, 0.8)
					playAny(x.Anim, { "RaptorScreech", "Roar" })
				end)
			end
			playAny(anim, R.Act or { "Roar" })
			-- the hit: blocks and leaves (or spray) blown at the lens, a punch, the name over sun rays
			local palette = waterY and { Color3.fromRGB(200, 240, 255), Color3.fromRGB(90, 170, 220), Color3.new(1, 1, 1) } or { color, LEAF[1], LEAF[2], LEAF[3] }
			burst(root.Position + face * (size * 0.4) + Vector3.new(0, ext.Y * 0.2, 0), math.clamp(size / 14, 0.8, 2.2), palette)
			punch(10)
			Audio.Sting("Reveal")
			CineKit.SlashCard(cine.Gui, R.Kick, name, sub, color, 2.6)
			local _ = card
			local from = root.Position - Vector3.new(0, lift, 0)
			local up = R.Hero == "Up"
			-- Low: the three-quarter hero angle pushing in. Up: right down at its feet looking up at a giant
			local hero = up
				and clearSpot({ from + face * (size * 0.85 + 5) + side * (size * 0.3) + Vector3.new(0, 0.6, 0), from + face * (size * 0.85 + 5) - side * (size * 0.3) + Vector3.new(0, 0.6, 0), from + face * (size * 1.2 + 6) + Vector3.new(0, 1, 0) }, { ctx.Head() }, { m })
				or clearSpot({ from + face * (size * 1.3 + 6) + side * (size * 0.6) + Vector3.new(0, 1.2, 0), from + face * (size * 1.3 + 6) - side * (size * 0.6) + Vector3.new(0, 1.2, 0), from + face * (size * 1.6 + 8) + Vector3.new(0, size * 0.3, 0) }, { ctx.Head() }, { m })
			if waterY then hero = Vector3.new(hero.X, math.max(hero.Y, waterY + 1.5), hero.Z) end
			local cam = Workspace.CurrentCamera
			local t1 = os.clock()
			while os.clock() - t1 < 3.0 and not skipped() do
				local u = (os.clock() - t1) / 3.0
				local e = 1 - (1 - u) ^ 3
				local hpp = ctx.Head()
				local mid = up and root.Position:Lerp(hpp, 0.75) or root.Position:Lerp(hpp, 0.5)
				local drift = up and (side * (e * 2) - face * (e * 1.5)) or (face * (e * size * 0.5) - Vector3.new(0, e * 0.4, 0))
				cam.CFrame = CFrame.lookAt(hero + drift, mid) * CFrame.Angles(math.noise(u * 6, 2) * 0.01, math.noise(u * 6, 7) * 0.012, 0)
				cam.FieldOfView = up and (58 + e * 8) or (46 + e * 8)
				RunService.RenderStepped:Wait()
			end
			hideCard()
			fade(1, 0.3)
		end, { KeepCamera = true })
		if not revealed and sil.Parent then sil:Destroy() end
		pcall(restorePath, cleared)
		for _, e in ipairs(ctx.Extras or {}) do if e.Parent then drop(e, true) end end
		dark:Destroy()
		drop(m, true)
	end, opts)
end

-- discovering a site: its dino's reveal, shot right there, then it's on your map for good
discover = function(key: string)
	local f = siteFolder(key)
	local species = f and f:GetAttribute("Species")
	if species then
		-- (another scene still finishing: wait for it. A reveal that can't play stays unseen and plays next time -
		-- it used to be marked found anyway and was lost for good)
		local t0 = os.clock()
		while (busy or DinosaurCinematics.IsPlaying()) and os.clock() - t0 < 8 do task.wait(0.1) end
		if busy or DinosaurCinematics.IsPlaying() then return end
		-- (the sting with the reveal it belongs to, not seconds ahead of it while another scene finished)
		Audio.Sting("Discover", 0.5)
		local ok, err = pcall(View.PreviewReveal, species, { Site = key })
		if not ok then warn("[EraView] discover:", err) end
	end
	markSeen("Found_" .. key)
	state.JustFound = key -- the scope-out right after skips its own look at the dino (you just saw it)
end

function View.PreviewBoss(bossId: string)
	local boss = Config.Bosses[bossId] :: any
	local center = boss and marker(boss.Era, "DenCenter")
	if not center then return end
	withEra(boss.Era, function()
		local c = center.Position - Vector3.new(0, center.Size.Y / 2, 0)
		local throne = marker(boss.Era, "Throne")
		local face = throne and Vector3.new(throne.Position.X, c.Y, throne.Position.Z) or (c + Vector3.new(0, 0, 10))
		local TikTok = require(script.Parent.TikTok)
		local seqId = TikTok.RevealFor(bossId)
		if seqId then
			-- the gallery plays the real reveal (it brings its own stand-ins); one that can't play falls back below
			if TikTok.PlayCutscene(seqId) then return end
		end
		local m = standIn(boss.Species, boss.Scale, CFrame.lookAt(c, c + (c - face)))
		bossIntroWith(bossId, "NORMAL", m, boss.Era)
		if m then m:Destroy() end
	end)
end

function View.PreviewBossDown(bossId: string)
	local boss = Config.Bosses[bossId] :: any
	local center = boss and marker(boss.Era, "FinalArena")
	if not center then return end
	withEra(boss.Era, function()
		local c = center.Position - Vector3.new(0, center.Size.Y / 2, 0)
		local m, anim = standIn(boss.Species, boss.Scale, CFrame.new(c))
		if anim then
			local tr = anim:Play("Stunned", { Loop = true })
			if tr then tr.Loop = true end
		end
		if m then DinosaurVFX.Stunned(m, 6) end
		bossDown({ Name = boss.Name, Tier = "NORMAL", Time = 154 }, m)
		if m then m:Destroy() end
	end)
end

--------------------------------------------------------------------------------
-- 9. the ruler sleeps on her throne whenever she isn't fighting, so the den is never empty
--------------------------------------------------------------------------------
local SHOW_SLEEPER = false
local function stepSleeper()
	local zone = state.Zone
	local boss = zone and eraBoss(zone)
	local want = false
	-- (2026-10-14, user: "you shouldn't be able to see the bosses before they show up". The sleeping boss on its
	-- throne is gone: the den stands empty until its reveal. SHOW_SLEEPER brings it back)
	if zone and boss and SHOW_SLEEPER then
		want = true
		local key = zone .. "/Den"
		for _, cfg in ipairs(Runtime.Chasers:GetChildren()) do
			if cfg:GetAttribute("Site") == key and cfg:GetAttribute("Boss") then want = false break end
		end
	end
	-- never pops in mid-cutscene: a scene that shows the boss (a glimpse, the Foreshadow roar, a TikTok take) would
	-- end up with two of it on the throne. it lies down once the screen is the player's again
	local cine = Cinema.Playing() or DinosaurCinematics.IsPlaying() or busy
	if want and not cine and (not sleeper.Model or not sleeper.Model.Parent or sleeper.Zone ~= zone) then
		if sleeper.Model then sleeper.Model:Destroy() end
		local throne = marker(zone, "Throne")
		local center = marker(zone, "DenCenter")
		if not (throne and center and boss) then return end
		local top = throne.Position + Vector3.new(0, throne.Size.Y / 2, 0)
		local face = Vector3.new(center.Position.X, top.Y, center.Position.Z)
		local m, anim = standIn((boss :: any).Species, (boss :: any).Scale * 0.9, CFrame.lookAt(top, face))
		if not m then return end
		m.Name = "SleepingRuler"
		if anim then
			local act = anim:HasAction("Sleep") and "Sleep" or (anim:HasAction("Browse") and "Browse" or "LookAround")
			local tr = anim:Play(act, { Loop = true })
			if tr then tr.Loop = true end
		end
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(160, 70)
		bb.StudsOffset = Vector3.new(0, 6, 0)
		bb.MaxDistance = 160
		bb.LightInfluence = 0
		bb.Adornee = m.PrimaryPart
		Kit.Text(bb, "Zzz", { Pixel = true, Size = UDim2.new(1, 0, 0.45, 0), Color = C.Cream, Stroke = 3, Shadow = 2, MaxSize = 26 })
		Kit.Text(bb, (boss :: any).Name, { Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.fromScale(0, 0.52), Color = (boss :: any).Color, Stroke = 3, Shadow = 2, MaxSize = 24 })
		bb.Parent = m
		sleeper.Model, sleeper.Zone, sleeper.Species = m, zone, (boss :: any).Species
	elseif not want and sleeper.Model then
		local m = sleeper.Model
		sleeper.Model = nil
		DinosaurVFX.FootstepDust(m:GetPivot().Position, 2)
		m:Destroy()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 9. riding along (carpool): someone else drives and picks the nests; you fight at every stop and your eggs go
-- straight to your bag. No map, no MAP / DRIVE OFF, no darts - the driver's run says where you are
--------------------------------------------------------------------------------
local ride = { Gen = 0 } :: any
local function riderName(uid: number?): string
	local p = uid and Players:GetPlayerByUserId(uid)
	return p and string.upper(p.DisplayName) or "YOUR DRIVER"
end
local function rideBlack(on: boolean)
	if on then
		if not ride.Black then
			local gui = Instance.new("ScreenGui")
			gui.Name = "DinoRideFade"
			gui.IgnoreGuiInset = true
			gui.ResetOnSpawn = false
			gui.DisplayOrder = 58
			local f = Instance.new("Frame")
			f.BackgroundColor3 = Color3.new(0, 0, 0)
			f.BackgroundTransparency = 1
			f.Size = UDim2.fromScale(1, 1)
			f.Parent = gui
			gui.Parent = player:WaitForChild("PlayerGui")
			ride.Black = { Gui = gui, Frame = f }
			TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
		end
		-- (never black for good: whatever happens on the server, the picture comes back)
		ride.Gen += 1
		local gen = ride.Gen
		task.delay(10, function() if ride.Gen == gen then rideBlack(false) end end)
	elseif ride.Black then
		local b = ride.Black
		ride.Black = nil
		ride.Gen += 1
		TweenService:Create(b.Frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(b.Frame:GetDescendants()) do if d:IsA("TextLabel") then d.Visible = false end end
		task.delay(0.55, function() b.Gui:Destroy() end)
	end
end
local function rideWatch(uid: number?)
	if ride.Conn then ride.Conn:Disconnect() ride.Conn = nil end
	ride.Driver = uid
	if not uid then return end
	local f = Runtime:FindFirstChild("Runs") and Runtime.Runs:FindFirstChild(tostring(uid))
	if not f then return end
	local last = f:GetAttribute("Phase")
	ride.Conn = f:GetAttributeChangedSignal("Phase"):Connect(function()
		local ph = f:GetAttribute("Phase")
		if ph == last then return end
		last = ph
		if not player:GetAttribute("RidingWith") then return end
		if ph == "Travel" then
			rideBlack(true) -- (the driver's travel scene: the rover jumps to the nest under black)
		elseif ph == "Map" or ph == "Driving" then
			rideBlack(false)
		end
	end)
end

-- the warp's landed: you're in the era, in your seat
function View.RideArrive(info)
	state.Zone = info.Zone
	state.Phase = "Riding"
	state.SiteKey = nil
	rideWatch(tonumber(info.Driver) or player:GetAttribute("RidingWith"))
	-- a new era for you: its establishing shot, the same as a driver's first trip there
	local key = "Est_" .. info.Zone
	if not seen(key) then
		markSeen(key)
		View.Establish(info.Zone, true)
	end
	local _ = riderName
end

function View.RideEnd()
	rideBlack(false)
	rideWatch(nil)
end

-- stepping out at a nest (the server joins you to it) / back in your seat
local function rideSite()
	if not player:GetAttribute("RidingWith") then return end
	local key = player:GetAttribute("Site")
	if typeof(key) == "string" then
		rideBlack(false)
		state.SiteKey = key
		state.Phase = "Site"
	elseif state.Phase == "Site" then
		state.SiteKey = nil
		state.Phase = "Riding"
	end
end

--------------------------------------------------------------------------------
-- 9c. FREE ROAM (2026-10-13, user: "there should be freeroam on the maps - the graphics look good, let players
-- explore"). Out of the portal you drive the era yourself and can hop out anywhere (V / D-pad right / the button).
-- Walk or roll slowly up to a nest and you're in it (server Expedition.roamTick -> SiteArrive); walk away with nothing
-- taken and you're exploring again (SiteLeft). A pin floats over every site ("???" until you've found it), and getting
-- close to one you haven't found plays its reveal. MAP (M / Select): the era map - pick a site and the rover drives
-- you there, or GO HOME. The return portal at the end of the road takes you home too.
--------------------------------------------------------------------------------
local roam = { On = false } :: any

local function roamRover(): BasePart?
	return Drive.State.Root or myRover()
end

local function roamPins()
	if roam.Folder then roam.Folder:Destroy() end
	roam.Pins = {}
	local era = Config.Era(state.Zone or "")
	if not era then return end
	local folder = Instance.new("Folder")
	folder.Name = "DinoRoamPins"
	folder.Parent = Workspace
	roam.Folder = folder
	for _, site in ipairs(siteKeys(era)) do
		local c = pinPos(site.Key)
		if not c then continue end
		local a = Instance.new("Part")
		a.Name = "Pin"
		a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
		a.Size = Vector3.new(1, 1, 1)
		a.CFrame = CFrame.new(c + Vector3.new(0, site.Boss and 30 or 18, 0))
		a.Parent = folder
		local bill = Instance.new("BillboardGui")
		bill.Size = UDim2.fromOffset(170, 46)
		bill.AlwaysOnTop = true
		bill.MaxDistance = 2400
		bill.LightInfluence = 0
		bill.Adornee = a
		bill.Parent = a
		local name = Kit.Text(bill, "", { Pixel = true, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 2), Color = site.Boss and C.OrangeHi or C.YellowHi, Stroke = 2, Shadow = 2, MaxSize = 14 })
		local dist = Kit.Text(bill, "", { Pixel = true, Size = UDim2.new(1, 0, 0, 11), Position = UDim2.fromOffset(0, 24), Color = C.Cream, Stroke = 2, Shadow = 1, MaxSize = 10 })
		roam.Pins[site.Key] = { Part = a, Bill = bill, Name = name, Dist = dist, Center = c, Site = site }
	end
end

roamStop = function()
	roam.On = false
	ContextActionService:UnbindAction("DinoRoamVehicle")
	ContextActionService:UnbindAction("DinoRoamMap")
	if roam.Gui then roam.Gui.Enabled = false end
	if roam.Folder then roam.Folder:Destroy() roam.Folder = nil end
	roam.Pins = {}
end

local function roamToggleVehicle()
	if not roam.On or roam.Asking or Cinema.Playing() then return end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	roam.Asking = true
	if hum and hum.SeatPart then
		Net.Ask("RoamOut", {})
	else
		local rv, me = roamRover(), hrp()
		if rv and me and (rv.Position - me.Position).Magnitude < 22 then Net.Ask("RoamIn", {}) end
	end
	roam.Asking = false
end

local function roamBar()
	if roam.Gui then return end
	local gui, canvas = Kit.Screen("DinoRoamBar", 9, false, 0.8)
	roam.Gui = gui
	local touch = Kit.Platform() == "Touch"
	roam.MapBtn = Kit.Tile(canvas, { Icon = "Map", Label = "MAP", Color = "Blue", Size = touch and UDim2.fromOffset(66, 66) or UDim2.fromOffset(84, 84),
		Position = touch and UDim2.new(0, 16, 0.17, 0) or UDim2.new(0, 16, 0.5, -40), AnchorPoint = touch and Vector2.new(0, 0) or Vector2.new(0, 0.5), OnClick = function()
		if roam.On and not Cinema.Playing() then View.ShowMap() end
	end })
	-- the goal line: what to do next, always (the free-roam walkthrough - user 2026-10-14: "the onboarding needs to
	-- walk the player perfectly through the free roam")
	roam.Obj = Kit.Text(canvas, "", { Size = UDim2.fromOffset(760, 40), Position = UDim2.new(0.5, 0, 0, 86), AnchorPoint = Vector2.new(0.5, 0), Color = Color3.new(1, 1, 1), Stroke = 4, Shadow = 4, MaxSize = 34, ZIndex = 6 })
	roam.CarBtn = Kit.Tile(canvas, { Icon = "Jeep", Label = "GET OUT", Color = "Orange", Size = touch and UDim2.fromOffset(84, 84) or UDim2.fromOffset(96, 96),
		Position = UDim2.new(1, -24, 1, touch and -150 or -24), AnchorPoint = Vector2.new(1, 1), OnClick = function() task.spawn(roamToggleVehicle) end })
	gui.Enabled = false
end

function View.StartRoam()
	if not state.Zone then return end
	state.Phase = "Map"
	state.SiteKey = nil
	View.HideMap()
	-- (still in the chase on this screen - the pack was lost and ChaseLost never got here, the roam heal's way in: the
	-- chase's music and road pickups end with it. 2026-10-14)
	local St = Drive.State
	if St.Mode == "Route" and not St.OnFoot then
		Audio.Remove("Chase")
		if Exp and Exp.ChaseOver then Exp.ChaseOver() end
	end
	keepLens(function() Drive.SetRoam(true) end)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	-- (HideMap above already handed the map's camera back; a scene still playing - a reveal you drove into - keeps
	-- its camera and its black, and hands both back itself)
	if not (hum and hum.SeatPart) and freeCam() and hum then Workspace.CurrentCamera.CameraSubject = hum end
	roamBar()
	roamPins()
	roam.On = true
	if not busy then task.spawn(fade, 0, 0.3) end -- (whatever the last shot left on screen lifts)
	task.spawn(function() Net.Ask("RoamReady", {}) end)
	ContextActionService:BindAction("DinoRoamVehicle", function(_, st)
		if st == Enum.UserInputState.Begin then task.spawn(roamToggleVehicle) end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.V, Enum.KeyCode.DPadRight)
	ContextActionService:BindAction("DinoRoamMap", function(_, st)
		if st == Enum.UserInputState.Begin and roam.On and not Cinema.Playing() then View.ShowMap() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)
end
View.StopRoam = roamStop

-- the roam bar, the pins and finding sites (Heartbeat, while roaming)
-- the next place to go: while you're new the easiest site you can do, after that the nearest (never one being chased)
local function roamTarget(me: Vector3): any?
	local p = Net.Profile
	local newbie = ((p and p.Stats and p.Stats.Runs) or 0) < 3
	local best, bestScore = nil, math.huge
	for key, pin in pairs(roam.Pins or {}) do
		if pin.Site.Boss then continue end
		local sf = siteFolder(key)
		local st = sf and sf:GetAttribute("State")
		if st == "Chase" then continue end
		local d = Vector3.new(me.X - pin.Center.X, 0, me.Z - pin.Center.Z).Magnitude
		local score = newbie and ((pin.Site.Def.Power or 0) * 10 + d * 0.01) or d
		if score < bestScore then best, bestScore = pin, score end
	end
	return best
end

local function keyName(): string
	if Kit.Gamepad() then return "D-PAD RIGHT" end
	if Kit.Platform() == "Touch" then return "GET OUT" end
	return "V"
end

local healSince = nil :: number?
local onSiteArriveRef: (any) -> () = function() end -- (set below, once onSiteArrive exists)
local function stepRoam()
	-- (self-healing: whenever the server has you out roaming and nothing's playing, roam mode is on - every way back to
	-- roaming, the server's own included, ends up here. Without it you could be left driving with nothing on screen)
	if not roam.On then
		local rf = RunsFolder:FindFirstChild(tostring(player.UserId))
		local phase = rf and rf:GetAttribute("Phase")
		-- (nothing actually playing - no scene, no cinematic, no warp, no map - is all that counts: a flow that died
		-- part-way could leave the client's own state saying "arriving" / "travelling" for good)
		local idle = rf ~= nil and state.Zone ~= nil and map.Gui == nil and not filming() -- (a TikTok boss reveal too)
			and not state.Arriving
			and not require(script.Parent.Warp).Playing and not player:GetAttribute("RidingWith")
		local siteAttr = player:GetAttribute("Site")
		if idle and phase == "Site" and state.Phase ~= "Site" and typeof(siteAttr) == "string" and siteAttr ~= "" then
			-- (the server has you at a site the client never heard about: join it on screen too)
			healSince = healSince or os.clock()
			if os.clock() - healSince > 2 then
				healSince = nil
				onSiteArriveRef({ Site = siteAttr, WasIdle = false })
			end
		elseif idle and (phase == "Map" or phase == "Travel") then
			healSince = healSince or os.clock()
			local wait = phase == "Travel" and 5 or 2
			if os.clock() - healSince > wait then
				healSince = nil
				if phase == "Travel" then
					-- a trip that stalled: finish it - you're at the site
					task.spawn(function()
						local res = Net.Ask("TravelDone")
						if res and res.Ok and not res.Chase then
							Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
							fade(0, 0.3)
							onSiteArriveRef({ Site = rf:GetAttribute("Site"), WasIdle = false })
						elseif not (res and res.Ok) and rf:GetAttribute("Phase") == "Map" then
							-- (only once the server really has you roaming: a refusal mid-join retries next tick)
							pcall(View.StartRoam)
						end
					end)
				else
					local ok, err = pcall(View.StartRoam)
					if not ok then warn("[EraView] roam heal:", err) end
				end
			end
		else
			healSince = nil
		end
		return
	end
	if state.Phase ~= "Map" then roamStop() return end
	-- (a missed SiteArrive: the server has you at a site, so don't roam with the bar up in the middle of a fight)
	local siteNow = player:GetAttribute("Site")
	if typeof(siteNow) == "string" and siteNow ~= "" and not player:GetAttribute("RidingWith") and not busy then
		local rfNow = RunsFolder:FindFirstChild(tostring(player.UserId))
		if rfNow and rfNow:GetAttribute("Phase") == "Site" then
			-- (a grace second: the attribute can replicate a beat before the SiteArrive event itself)
			roam.SiteSince = roam.SiteSince or os.clock()
			if os.clock() - roam.SiteSince > 1.5 then
				roam.SiteSince = nil
				onSiteArriveRef({ Site = siteNow, WasIdle = false })
				return
			end
		else
			roam.SiteSince = nil
		end
	else
		roam.SiteSince = nil
	end
	local busyNow = Cinema.Playing() or map.Gui ~= nil
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seated = hum ~= nil and hum.SeatPart ~= nil
	local me = hrp()
	local rv = roamRover()
	local near = not seated and rv ~= nil and me ~= nil and (rv.Position - me.Position).Magnitude < 22
	if roam.Gui then
		roam.Gui.Enabled = not busyNow
		if roam.CarBtn then
			roam.CarBtn.Visible = seated or near
			local want = seated and "GET OUT" or "GET IN"
			if roam.CarText ~= want then
				roam.CarText = want
				local lbl = roam.CarBtn:FindFirstChild("Label", true)
				if lbl then Kit.SetText(lbl :: any, want) end
			end
		end
	end
	if not me then return end
	-- the goal line + the target pin
	local rf = RunsFolder:FindFirstChild(tostring(player.UserId))
	local eggs = rf and rf:GetAttribute("Eggs")
	local haveEggs = typeof(eggs) == "string" and eggs ~= "[]" and eggs ~= ""
	-- (2026-10-14: a chase you shake off leaves you roaming with eggs on the rack - room left means the next nest's
	-- still on: the line says what's aboard and the pin still points on. Only a full rack is the portal's)
	local onBoard, slots = 0, tonumber(rf and rf:GetAttribute("Slots")) or 0
	if haveEggs then
		if roam.EggsRaw ~= eggs then
			local okD, list = pcall(function() return game:GetService("HttpService"):JSONDecode(eggs :: string) end)
			roam.EggsRaw, roam.EggsN = eggs, (okD and typeof(list) == "table") and #list or 1
		end
		onBoard = roam.EggsN or 1
	end
	local full = haveEggs and (slots <= 0 or onBoard >= slots)
	local target = roamTarget(me.Position)
	local text = ""
	if full then
		text = seated and "RACK FULL - DRIVE INTO THE PORTAL" or "GET BACK IN YOUR ROVER (" .. keyName() .. ")"
	elseif target then
		local known = discovered(target.Site.Key or "")
		local nm = known and string.upper(target.Site.Def.Name or "") or "THE NEST"
		local d = Vector3.new(me.Position.X - target.Center.X, 0, me.Position.Z - target.Center.Z).Magnitude
		if seated and haveEggs and d > 70 then
			text = string.format("%d/%d EGGS ON BOARD", onBoard, slots)
		elseif seated then
			text = d > 70 and ("DRIVE TO " .. nm) or ((Kit.Platform() == "Touch" and "TAP GET OUT" or ("PRESS " .. keyName())) .. " TO HOP OUT AND SNEAK IN")
		else
			local rvD = rv and (rv.Position - me.Position).Magnitude or 0
			text = (d > 160 and rvD < 40) and ("HOP BACK IN YOUR ROVER (" .. keyName() .. ")") or ("SNEAK UP ON " .. nm)
		end
	end
	if roam.Obj and roam.ObjText ~= text then
		roam.ObjText = text
		Kit.SetText(roam.Obj, text)
		if text ~= "" then Kit.Pop(roam.Obj, 1.4) end
	end
	roam.Target = target
	for key, pin in pairs(roam.Pins or {}) do
		local d = Vector3.new(me.Position.X - pin.Center.X, 0, me.Position.Z - pin.Center.Z).Magnitude
		local known = discovered(key)
		local sf = siteFolder(key)
		-- (a den shows only while its boss is awake; a site you're standing in needs no pin)
		local show = not busyNow and d > 50 and (not pin.Site.Boss or (sf ~= nil and (sf:GetAttribute("Phase") or 0) > 0))
		pin.Bill.Enabled = show
		if show then
			-- (the one you're headed for: gold, bigger, pulsing)
			local isT = roam.Target == pin
			pin.Bill.Size = isT and UDim2.fromOffset(220 + math.sin(os.clock() * 5) * 14, 58) or UDim2.fromOffset(170, 46)
			if pin.WasT ~= isT then
				pin.WasT = isT
				Kit.SetTextColor(pin.Name, isT and C.YellowHi or (pin.Site.Boss and C.OrangeHi or C.Cream))
			end
			local nm = known and string.upper(pin.Site.Def.Name or "") or "???"
			if pin.LastName ~= nm then pin.LastName = nm Kit.SetText(pin.Name, nm) end
			local dm = math.floor(d / 5) * 5
			if pin.LastDist ~= dm then pin.LastDist = dm Kit.SetText(pin.Dist, dm .. "M") end
		end
		-- finding it: close enough to see the nest, its dino's reveal plays (once)
		if not known and not pin.Site.Boss and d < 110 and not busyNow and not roam.Finding then
			roam.Finding = true
			task.spawn(function()
				-- (the rover waits while the reveal plays: it used to roll on blind under the cutscene, steered by
				-- whatever keys were still held)
				Drive.Freeze(true)
				if discover then pcall(discover, key) end
				if roam.On or Drive.State.Mode == "Roam" then Drive.Freeze(false) end
				roam.Finding = false
			end)
		end
	end
end

local function onSiteArrive(info)
	if typeof(info) ~= "table" or typeof(info.Site) ~= "string" then return end
	roamStop()
	View.HideMap()
	state.Phase = "Site"
	state.SiteKey = info.Site
	Drive.SetRoam(false)
	keepLens(function() Drive.SetOnFoot(true) end)
	-- (the den has its own scenes: BossArrive / BossIntro)
	local sf = siteFolder(info.Site)
	if info.Boss or (sf and sf:GetAttribute("Boss")) then return end
	-- a wild one out in the open: no scope-out walk-through - it just looks up (its spotted intro when it sees you)
	if sf and sf:GetAttribute("Wild") then
		Audio.Sting("Discover", 0.4)
		return
	end
	if scopeOut then task.spawn(scopeOut, info.Site, tostring(info.Species or ""), info.WasIdle == true) end
end

onSiteArriveRef = onSiteArrive

-- a hidden egg stash taken (WildLife.luau): the egg pops into your bag
local function onStashFound(info)
	if typeof(info) ~= "table" then return end
	local r = Config.Rarity[tostring(info.Rarity or "")]
	local at = typeof(info.At) == "Vector3" and info.At or nil
	if at then
		DinosaurVFX.BlockRing(CFrame.new(at + Vector3.new(0, 1, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 16, R0 = 0.5, R1 = 6, Color = r and r.Color or C.YellowHi, Duration = 0.5 })
		DinosaurVFX.Cubes(at + Vector3.new(0, 1.5, 0), 12, { r and r.Color or C.YellowHi, Color3.new(1, 1, 1) }, 0.25, 10, 0.8)
	end
	Audio.Sting("Discover", 0.6)
	local sp = Config.Species[tostring(info.Species or "")]
	Kit.Toast("FOUND " .. (r and (r.Name .. " ") or "") .. (sp and sp.Name or "") .. " EGG - IN YOUR BAG", r and "Gold" or "Green", "Egg")
end

function View.Start(expView, hudModule)
	player:GetAttributeChangedSignal("Site"):Connect(rideSite)
	player:GetAttributeChangedSignal("RidingWith"):Connect(function()
		if not player:GetAttribute("RidingWith") then View.RideEnd() end
	end)
	-- signature intros hit like the rest: their heavy beats (big shakes, impacts, smashes, roars) get an impact
	-- frame, a beat of hit-stop and speed lines. only while a cutscene is playing, and never twice in 0.35 s
	local lastHit = 0
	-- (only the dino the scene is about: a grazer's roar off to the side used to fire hit-stops and speed lines)
	local function inShot(model: Instance?): boolean
		if not (model and model:IsA("Model")) then return false end
		if DinosaurCinematics.IsPlaying() then return model == DinosaurCinematics.CurrentModel() end
		if cineKeep[model] then return true end
		local actors = Workspace:FindFirstChild("DinoCutsceneActors")
		local set = Workspace:FindFirstChild("DinoRevealSet")
		if (actors and model:IsDescendantOf(actors)) or (set and model:IsDescendantOf(set)) then return true end
		return cineSubject ~= nil and (model:GetPivot().Position - cineSubject).Magnitude < 40
	end
	DinosaurAnimations.onEvent(function(_model, name: string, arg)
		if not (DinosaurCinematics.IsPlaying() or busy) then return end
		if not inShot(_model) then return end
		if os.clock() - lastHit < 0.35 then return end
		local pg = player:FindFirstChildOfClass("PlayerGui")
		local gui = pg and (pg:FindFirstChild("DinoCinematicUI") or pg:FindFirstChild("DinoEraCine"))
		if name == "CameraShake" and typeof(arg) == "number" and arg >= 0.8 then
			lastHit = os.clock()
			CineKit.ImpactFrame(math.min(1, arg * 0.6))
			CineKit.HitStop(0.05 + arg * 0.04)
		elseif name == "Impact" or name == "Smash" or name == "Breach" then
			lastHit = os.clock()
			CineKit.ImpactFrame(0.85)
			CineKit.HitStop(0.1)
			CineKit.SunBurst(0.6)
		elseif name == "Roar" and gui then
			lastHit = os.clock()
			CineKit.SpeedLines(gui, 0.9)
		end
	end)
	-- every signature intro names its dino the big way: blocks blown at the lens, a punch, the name over sun rays
	DinosaurCinematics.OnTitle = function(model: Model, gui: Instance): boolean
		local species = model:GetAttribute("Species") or model.Name
		local sp = Config.Species[species] :: any
		local name = string.upper(model:GetAttribute("DisplayName") or (sp and sp.Name) or model.Name)
		local move = model:GetAttribute("SignatureMove")
		local era = sp and Config.Era(sp.Era) :: any
		local sub = era and ("OF " .. era.Name) or ""
		if move and move ~= "" and move ~= "NORMAL" then
			local up = string.upper(move)
			local tier = up == "HARD" or up == "NIGHTMARE" or up:sub(1, 4) == "APEX"
			sub = tier and (up .. " TIER") or ("SIGNATURE: " .. up)
		end
		local _, ext = model:GetBoundingBox()
		local size = math.max(ext.X, ext.Y, ext.Z)
		local color = (sp and sp.Color) or C.OrangeHi
		CineKit.Burst(model:GetPivot().Position + Vector3.new(0, ext.Y * 0.25, 0), math.clamp(size / 12, 0.8, 2.6), { color, LEAF[1], LEAF[2], LEAF[3] })
		CineKit.Punch(8)
		CineKit.SunBurst(0.8)
		-- sun rays are for rulers and new eras; a dino's signature keeps its own name card
		local _ = { gui, name, sub }
		return false
	end
	Exp, hud = expView, hudModule
	buildCine()
	buildSiteButton()
	-- (a boss waking up is BossHype's one card now; this pop-up used to stack on top of it)
	local _ = bossEventPopup
	Net.On("Spotted", function(info)
		if not spottedBusy then introOwed = true end -- (set now, before any scope-out ending can ack instead)
		task.spawn(spotted, info)
	end)
	Net.On("BossIntro", function(info) task.spawn(bossIntro, info) end)
	Net.On("BossPhase", function(info)
		if info.Phase == 2 then task.spawn(bossFlee, info)
		elseif info.Phase == 3 then
			state.Phase = "Site"
			keepLens(function() Drive.SetOnFoot(true) end)
			if info.Late then
				-- the last stand is already on: straight in (a scene now would freeze you in the middle of it)
				freeCam()
			else
				task.spawn(bossFinal, info)
			end
		end
	end)
	-- (2026-10-13: nothing that reads like a tutorial or another boss's news while you fight - the fight shows its
	-- own moves: BossArrive / BossPerch / BossWave banners are gone, the red circle and the pack say it)
	Net.On("BossDown", function(info) bossMusicOff() task.spawn(bossDown, info) end)
	Net.On("BossLoot", function(info) task.spawn(bossLoot, info) end)
	Net.On("BossFail", function(info)
		bossMusicOff()
		if hud and hud.Banner then hud.Banner((info.Name or "THE BOSS") .. " WON THIS ONE", "GEAR UP AND TRY AGAIN", "Alert") end
	end)
	Net.On("SiteArrive", onSiteArrive)
	Net.On("StashFound", onStashFound)
	Net.On("SiteLeft", function() if state.Zone then View.StartRoam() end end)
	RunService.Heartbeat:Connect(function()
		pcall(stepRoam)
		sleeper.Tick = (sleeper.Tick or 0) + 1
		if sleeper.Tick % 20 == 0 then pcall(stepSleeper) end
		if map.Gui then
			refreshPins()
			map.T = (map.T or 0) + 1
			if map.T % 15 == 0 then refreshMap() end
		end
		local key = player:GetAttribute("Site")
		local sf = siteFolder(typeof(key) == "string" and key or nil)
		-- (a carpool rider has no MAP of their own: the driver decides when to leave)
		if siteGui then siteGui.Enabled = sf ~= nil and not sf:GetAttribute("Boss") and not Cinema.Playing() and not player:GetAttribute("RidingWith") end
		local _ = siteBtn
	end)
	-- (one server update sets ~10 attributes on a site: coalesce them into one rebuild, not ten)
	local pending = false
	local function soon()
		if pending or not map.Gui then return end
		pending = true
		task.delay(0.15, function()
			pending = false
			if map.Gui then refreshMap() end
		end)
	end
	for _, f in ipairs(SitesFolder:GetChildren()) do f.AttributeChanged:Connect(soon) end
	SitesFolder.ChildAdded:Connect(function(f) f.AttributeChanged:Connect(soon) end)
	Net.On("Profile", function() if map.Gui then if map.Card then map.Card.Mode = nil end refreshMap() end end)
end

return View
