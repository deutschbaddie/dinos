--[[
	DinosaurCinematics — reusable, skippable creature cinematics (client only).

	Supported API (each returns a handle { Finished: RBXScriptSignal, Stop: () -> () } or nil):
		DinosaurCinematics.PlayIntro(model, opts?)   -- species signature intro (profile.Intro + profile.IntroShots)
		DinosaurCinematics.PlayRoar(model, opts?)    -- roar, shot as a low close-up
		DinosaurCinematics.PlayAttack(model, opts?)  -- bite/attack from a side angle with a hard cut on the snap
		DinosaurCinematics.PlayChase(model, opts?)   -- creature charges a retreating handheld camera and snaps
		DinosaurCinematics.Play(model, actionName, shotListName, opts?)
		DinosaurCinematics.Stop()                    -- skip / interrupt (also: Skip button, Q, gamepad B)
		DinosaurCinematics.IsPlaying(): boolean

	opts: { Camera = true, Letterbox = true, Title = true, Skippable = true, HideGui = true }
	Camera = false makes the creature perform without touching the camera (what other players see).

	Director features: shot lists with hard cuts or blended transitions, dolly moves, dutch roll,
	depth of field that tracks the subject, slow-motion ramps synced to the animation clock, FOV punches,
	colour/brightness flashes and blur pulses on impacts, handheld micro-motion, letterbox and title card.
	Shot data lives in Shots.luau (generated from tools/gen/anim/shots.js and verified in the preview).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local DinosaurAnimations = require(script.Parent:WaitForChild("DinosaurAnimations"))
local DinosaurVFX = require(script.Parent:WaitForChild("DinosaurVFX"))
local Shots = require(script:WaitForChild("Shots"))
local Ease = DinosaurAnimations.Gaits.Ease

local DinosaurCinematics = {}
-- optional: a game stages the name card its own way (return true to replace the default card)
DinosaurCinematics.OnTitle = nil :: ((model: Model, gui: Instance) -> boolean)?
DinosaurCinematics.Shots = Shots

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local RARITY_COLORS = {
	Common = Color3.fromRGB(159, 211, 107), Uncommon = Color3.fromRGB(79, 209, 165), Rare = Color3.fromRGB(74, 168, 255),
	Epic = Color3.fromRGB(180, 107, 255), Legendary = Color3.fromRGB(255, 176, 46), Mythic = Color3.fromRGB(255, 79, 139), Secret = Color3.fromRGB(255, 48, 48),
}
local TARGETS = {
	Head = "VFX_Head", Mouth = "VFX_Mouth", Chest = "VFX_Chest", RightFoot = "VFX_RightFoot", LeftFoot = "VFX_LeftFoot",
	TailTip = "VFX_TailTip", RightFrontFoot = "VFX_RightFrontFoot", RightClaw = "VFX_RightClaw", Crest = "VFX_Crest", Club = "VFX_Club",
}

local current = nil
-- foliage between the lens and the dino fades for the cinematic instead of the camera jumping in front of it
-- (2026-10-14, user: "the middle small bush kinda blocks view" in the Triceratops charge at Horn Meadow)
local lensFaded = {} :: { [BasePart]: boolean }
local SOFT = { "Bush", "Fern", "Leaves", "Cover", "Grass", "Plant", "Shrub", "Flower", "Reed", "Sapling", "Tuft", "Palm", "Cycad", "Rock", "Pebble" }
local function softPart(p: Instance): boolean
	if not p:IsA("BasePart") or p:IsA("Terrain") then return false end
	if (p :: BasePart).Size.Magnitude > 30 then return false end
	local m = p:FindFirstAncestorWhichIsA("Model")
	local names = p.Name .. " " .. ((m and m ~= workspace) and m.Name or "")
	for _, w in ipairs(SOFT) do if string.find(names, w, 1, true) then return true end end
	return not (p :: BasePart).CanCollide
end
local occl = RaycastParams.new()
occl.FilterType = Enum.RaycastFilterType.Exclude
occl.RespectCanCollide = false

--------------------------------------------------------------------------------
-- UI: letterbox, arcade title card, "TAP TO CONTINUE"
--------------------------------------------------------------------------------
local PIXEL = Font.new("rbxasset://fonts/families/PressStart2P.json")

-- Styled arcade text: Press Start 2P, thick outline, vertical gradient, hard drop shadow
local function styled(parent: Instance, text: string, props)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = props.Size
	box.Position = props.Position or UDim2.new()
	box.AnchorPoint = props.AnchorPoint or Vector2.zero
	box.ZIndex = props.ZIndex or 3
	local function label(name: string, offset: number, z: number)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Position = UDim2.fromOffset(offset, offset)
		l.FontFace = PIXEL
		l.TextScaled = true
		l.Text = text
		l.TextXAlignment = props.Align or Enum.TextXAlignment.Left
		l.ZIndex = z
		l.Parent = box
		return l
	end
	local shadow = label("Shadow", props.Shadow or 5, (props.ZIndex or 3))
	shadow.TextColor3 = Color3.new(0, 0, 0)
	shadow.TextTransparency = 0.3
	local main = label("Main", 0, (props.ZIndex or 3) + 1)
	main.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = props.Stroke or 3
	stroke.Color = Color3.fromRGB(16, 16, 20)
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = main
	local top = props.Color or Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.55, top),
		ColorSequenceKeypoint.new(1, props.Color2 or top:Lerp(Color3.new(0, 0, 0), 0.3)),
	})
	g.Parent = main
	box.Parent = parent
	return box
end
DinosaurCinematics.StyledText = styled

local function setTextAlpha(root: Instance, alpha: number, tween: boolean)
	for _, l in ipairs(root:GetDescendants()) do
		if l:IsA("TextLabel") then
			local goal = l.Name == "Shadow" and 0.3 + 0.7 * (1 - alpha) or 1 - alpha
			if tween then TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = goal }):Play() else l.TextTransparency = goal end
		elseif l:IsA("UIStroke") then
			if tween then TweenService:Create(l, TweenInfo.new(0.35), { Transparency = 1 - alpha }):Play() else l.Transparency = 1 - alpha end
		end
	end
end

local function makeGui(model: Model, opts)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoCinematicUI"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None -- letterbox reaches the physical screen edges (notches included)
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	local ui = { Gui = gui, Bars = {} }
	if opts.Letterbox ~= false then
		for i, anchor in ipairs({ 0, 1 }) do
			local f = Instance.new("Frame")
			f.BackgroundColor3 = Color3.new(0, 0, 0)
			f.BorderSizePixel = 0
			f.AnchorPoint = Vector2.new(0, anchor)
			f.Position = UDim2.fromScale(0, anchor)
			f.Size = UDim2.fromScale(1, 0)
			f.ZIndex = 2
			f.Parent = gui
			ui.Bars[i] = f
			TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0.11) }):Play()
		end
	end
	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 1
	flash.Parent = gui
	ui.Flash = flash

	if opts.Title ~= false then
		local rarity = model:GetAttribute("Rarity") or ""
		local rc = RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
		local title = Instance.new("Frame")
		title.BackgroundTransparency = 1
		title.AnchorPoint = Vector2.new(0, 1)
		title.Position = UDim2.new(0.05, 0, 0.84, 0)
		title.Size = UDim2.new(0.62, 0, 0.2, 0)
		title.Visible = false
		title.ZIndex = 3
		title.Parent = gui
		local move = model:GetAttribute("SignatureMove")
		styled(title, string.upper(rarity), { Size = UDim2.fromScale(0.5, 0.16), Position = UDim2.fromScale(0, 0), Color = rc, Shadow = 3, Stroke = 2 })
		styled(title, string.upper(model:GetAttribute("DisplayName") or model.Name), { Size = UDim2.fromScale(1, 0.42), Position = UDim2.fromScale(0, 0.2), Color = Color3.fromRGB(255, 244, 214), Color2 = Color3.fromRGB(255, 176, 46), Shadow = 6, Stroke = 4 })
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = rc
		bar.Size = UDim2.new(0, 0, 0.035, 0)
		bar.Position = UDim2.fromScale(0, 0.67)
		bar.ZIndex = 3
		bar.Parent = title
		if move then
			styled(title, "SIGNATURE: " .. string.upper(move), { Size = UDim2.fromScale(0.8, 0.13), Position = UDim2.fromScale(0, 0.76), Color = Color3.fromRGB(230, 236, 245), Shadow = 3, Stroke = 2 })
		end
		setTextAlpha(title, 0, false)
		ui.Title, ui.Accent = title, bar
		ui.Model, ui.Gui = model, gui
	end

	-- "TAP TO CONTINUE" (bottom centre, blinking) + a full-screen tap catcher
	local tap = Instance.new("TextButton")
	tap.Name = "TapCatcher"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 10
	tap.Parent = gui
	tap.Activated:Connect(function() DinosaurCinematics.Continue() end)
	ui.Prompt = styled(gui, "TAP TO CONTINUE", {
		Size = UDim2.new(0.34, 0, 0.032, 0), Position = UDim2.new(0.5, 0, 0.965, 0), AnchorPoint = Vector2.new(0.5, 1),
		Align = Enum.TextXAlignment.Center, Color = Color3.fromRGB(255, 226, 120), Shadow = 3, Stroke = 2, ZIndex = 6,
	})
	setTextAlpha(ui.Prompt, 0, false)
	task.spawn(function()
		task.wait(1.0)
		while gui.Parent do
			setTextAlpha(ui.Prompt, 1, true)
			task.wait(0.75)
			if not gui.Parent then break end
			setTextAlpha(ui.Prompt, 0.25, true)
			task.wait(0.55)
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	return ui
end

local function showTitle(ui)
	if not ui or not ui.Title or ui.TitleShown then return end
	ui.TitleShown = true
	-- a game can stage the name its own way (the big sun-ray title): return true to replace the default card
	if DinosaurCinematics.OnTitle and ui.Model then
		local ok, handled = pcall(DinosaurCinematics.OnTitle, ui.Model, ui.Gui)
		if ok and handled then return end
	end
	ui.Title.Visible = true
	ui.Title.Position = UDim2.new(0.02, 0, 0.84, 0)
	TweenService:Create(ui.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { Position = UDim2.new(0.05, 0, 0.84, 0) }):Play()
	TweenService:Create(ui.Accent, TweenInfo.new(0.8, Enum.EasingStyle.Quint), { Size = UDim2.new(0.45, 0, 0.035, 0) }):Play()
	setTextAlpha(ui.Title, 1, true)
end

local function flashScreen(ui, strength: number, color: Color3?)
	if not ui or not ui.Flash then return end
	ui.Flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	ui.Flash.BackgroundTransparency = 1 - strength
	TweenService:Create(ui.Flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

local function closeGui(ui)
	if not ui then return end
	for _, f in ipairs(ui.Bars) do
		TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0) }):Play()
	end
	if ui.Title then setTextAlpha(ui.Title, 0, true) end
	if ui.Prompt then ui.Prompt:Destroy() end
	local tap = ui.Gui:FindFirstChild("TapCatcher")
	if tap then tap:Destroy() end
	task.delay(0.4, function() ui.Gui:Destroy() end)
end

--------------------------------------------------------------------------------
-- Post-processing (created on demand inside Lighting, removed afterwards)
--------------------------------------------------------------------------------
local function makePost(useDof: boolean)
	local post = {}
	post.Grade = Instance.new("ColorCorrectionEffect")
	post.Grade.Name = "DinoCinematicGrade"
	post.Grade.Parent = Lighting
	TweenService:Create(post.Grade, TweenInfo.new(0.5), { Contrast = 0.12, Saturation = 0.12 }):Play()
	post.Blur = Instance.new("BlurEffect")
	post.Blur.Name = "DinoCinematicBlur"
	post.Blur.Size = 0
	post.Blur.Parent = Lighting
	if useDof then
		post.Dof = Instance.new("DepthOfFieldEffect")
		post.Dof.Name = "DinoCinematicDOF"
		post.Dof.NearIntensity = 0.25
		post.Dof.FarIntensity = 0.35
		post.Dof.InFocusRadius = 10
		post.Dof.FocusDistance = 20
		post.Dof.Parent = Lighting
	end
	return post
end

local function removePost(post)
	if not post then return end
	for _, e in pairs(post) do
		if typeof(e) == "Instance" then
			if e:IsA("ColorCorrectionEffect") then
				local tw = TweenService:Create(e, TweenInfo.new(0.4), { Contrast = 0, Saturation = 0, Brightness = 0 })
				tw.Completed:Connect(function() e:Destroy() end)
				tw:Play()
			else
				e:Destroy()
			end
		end
	end
end

local function pulse(post, blur: number, brightness: number)
	if not post then return end
	if blur > 0 then
		post.Blur.Size = blur
		TweenService:Create(post.Blur, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = 0 }):Play()
	end
	if brightness ~= 0 then
		post.Grade.Brightness = brightness
		post.Grade.TintColor = Color3.fromRGB(255, 236, 214)
		TweenService:Create(post.Grade, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	end
end

--------------------------------------------------------------------------------
-- Shot evaluation (mirrors tools/gen/anim/runtime.js — previewed and framed there)
--------------------------------------------------------------------------------
local function groundFrame(model: Model): CFrame
	local root = model.PrimaryPart
	local cf = root and root.CFrame or model:GetPivot()
	local foot = DinosaurVFX.findAttachment(model, "VFX_RightFoot")
	local _, size = model:GetBoundingBox()
	local groundY = foot and foot.WorldPosition.Y or (cf.Y - size.Y / 2)
	-- swimmers: the ground frame sits on the water surface of their pool
	local water = DinosaurVFX.waterSurface(model)
	if water then groundY = math.max(groundY, water) end
	return CFrame.new(cf.X, groundY, cf.Z) * cf.Rotation
end

local function targetPos(t)
	if typeof(t) == "Vector3" then return t end
	if typeof(t) == "Instance" then
		if t:IsA("Attachment") then return t.WorldPosition end
		if t:IsA("Model") then return t:GetPivot().Position end
		if t:IsA("BasePart") then return t.Position end
	end
	return nil
end

local function resolve(spec, G: CFrame, u: number, targets)
	if typeof(spec) == "Vector3" then
		return G:PointToWorldSpace(spec * u)
	elseif type(spec) == "string" then
		return targetPos(targets[spec]) or G.Position
	elseif type(spec) == "table" and spec.Follow then
		local base = targetPos(targets[spec.Follow]) or G.Position
		return base + G:VectorToWorldSpace(spec.Offset * u)
	end
	return G.Position
end

local function shotState(shot, alpha, G, u, targets)
	local f, to = shot.From, shot.To
	return {
		Pos = resolve(f.Pos, G, u, targets):Lerp(resolve(to.Pos, G, u, targets), alpha),
		Look = resolve(f.Look, G, u, targets):Lerp(resolve(to.Look, G, u, targets), alpha),
		Fov = f.Fov + (to.Fov - f.Fov) * alpha,
		Roll = (f.Roll or 0) + ((to.Roll or 0) - (f.Roll or 0)) * alpha,
	}
end

local function sampleShots(list, t: number, D: number, G, u, targets)
	local k = list.Normalized and D or 1
	local shots = list.Shots
	local index = #shots
	if t < shots[1].T0 * k then index = 1 end
	for i, s in ipairs(shots) do
		if t >= s.T0 * k and t < s.T1 * k then index = i break end
	end
	local s = shots[index]
	local alpha = (Ease[s.Ease] or Ease.Sine)(math.clamp((t - s.T0 * k) / ((s.T1 - s.T0) * k), 0, 1))
	local st = shotState(s, alpha, G, u, targets)
	local blend = (s.Blend or 0) * k
	if blend > 0 and index > 1 and t - s.T0 * k < blend then
		local prev = shotState(shots[index - 1], 1, G, u, targets)
		local b = Ease.Sine((t - s.T0 * k) / blend)
		st = { Pos = prev.Pos:Lerp(st.Pos, b), Look = prev.Look:Lerp(st.Look, b), Fov = prev.Fov + (st.Fov - prev.Fov) * b, Roll = prev.Roll + (st.Roll - prev.Roll) * b }
	end
	return st, index, s
end

local function rampSpeed(list, t: number, D: number): number
	local k = list.Normalized and D or 1
	for _, r in ipairs(list.TimeRamps or {}) do
		local t0, t1, speed = r[1] * k, r[2] * k, r[3]
		if t >= t0 and t <= t1 then
			local edge = math.min(1, (t - t0) / 0.08, (t1 - t) / 0.12)
			return 1 + (speed - 1) * edge
		end
	end
	return 1
end

--------------------------------------------------------------------------------
-- Core
--------------------------------------------------------------------------------
local function finish(state, completed: boolean)
	if state.Done then return end
	state.Done = true
	if current == state then current = nil end
	RunService:UnbindFromRenderStep("DinoCinematicCamera")
	-- (the foliage that stepped out of the lens comes back)
	for p in pairs(lensFaded) do if p.Parent then p.LocalTransparencyModifier = 0 end end
	table.clear(lensFaded)
	ContextActionService:UnbindAction("DinoSkipCinematic")
	if state.EventConn then state.EventConn:Disconnect() end
	if state.Track then state.Track.Speed = 1 end
	local cam = Workspace.CurrentCamera
	if state.CameraTaken and cam then
		cam.CameraType = state.SavedType
		cam.FieldOfView = state.SavedFov
	end
	for gui in pairs(state.HiddenGuis or {}) do
		if gui.Parent then gui.Enabled = true end
	end
	if state.CoreHidden then pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true) end
	closeGui(state.UI)
	removePost(state.Post)
	task.delay(1.5, function() DinosaurVFX.ResetEnvironment(state.Model) end)
	if not completed then
		if state.Track then state.Track:Stop(0.25) end
		DinosaurVFX.ResetEnvironment(state.Model)
	end
	state.Event:Fire(completed)
	state.Event:Destroy()
end

function DinosaurCinematics.Play(model: Model, actionName: string, shotListName: string?, opts)
	opts = opts or {}
	local anim = DinosaurAnimations.get(model)
	if not anim or not anim:HasAction(actionName) then return nil end
	if current then finish(current, false) end

	anim:StopActions(0.1)
	anim:SetLocomotion("Idle", 0.2)
	local list = shotListName and Shots[shotListName]
	local G = groundFrame(model)
	local u = (list and list.Studs) and 1 or (anim.Profile.CameraScale or 1)
	local targets = {}
	for key, attName in pairs(TARGETS) do targets[key] = DinosaurVFX.findAttachment(model, attName) end
	targets.HeadStart = targets.Head and targets.Head.WorldPosition
	if list and list.Prop then
		local prop = DinosaurVFX.findProp(model, list.Prop)
		targets.Prop = prop and prop:GetPivot().Position
	end
	-- its herd: only real herd-mates right here (never the old showcase mock-ups on the baseplate)
	local showcase = Workspace:FindFirstChild("DinoExpeditionShowcase")
	local here = model:GetPivot().Position
	for _, d in ipairs(model.Parent and model.Parent:GetDescendants() or {}) do
		if d:IsA("Model") and d:GetAttribute("HerdLeader") == model.Name and not (showcase and d:IsDescendantOf(showcase))
			and (d:GetPivot().Position - here).Magnitude < 120 then
			targets.Herd = DinosaurVFX.findAttachment(d, "VFX_Head")
			break
		end
	end

	local track = anim:Play(actionName)
	if not track then return nil end
	local D = track.Action.Duration
	local event = Instance.new("BindableEvent")
	local state = { Model = model, Track = track, Done = false, Event = event, StartedAt = os.clock() } :: any
	current = state

	local cam = Workspace.CurrentCamera
	if opts.Camera ~= false and list and cam and Players.LocalPlayer then
		state.CameraTaken = true
		state.SavedType = cam.CameraType
		state.SavedFov = cam.FieldOfView
		cam.CameraType = Enum.CameraType.Scriptable
		-- hide other UI for a clean frame
		if opts.HideGui ~= false then
			state.HiddenGuis = {}
			for _, g in ipairs(Players.LocalPlayer.PlayerGui:GetChildren()) do
				if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "DinoCinematicUI" then
					g.Enabled = false
					state.HiddenGuis[g] = true
				end
			end
			state.CoreHidden = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
		end
		state.UI = makeGui(model, opts)
		state.Post = makePost(list.DOF)
		local titleAt = type(list.Title) == "number" and list.Title or nil
		local titled = opts.Title == false or titleAt == nil
		local fovPunch, lastShot = 0, nil
		local sLook
		local handheld = list.Handheld or 0.18
		local start = os.clock()

		-- impact beats drive the camera: punches, flashes, blur
		state.EventConn = anim.Event:Connect(function(name)
			if state.Done then return end
			if name == "Roar" then
				fovPunch -= 7
				pulse(state.Post, 8, 0.07)
			elseif name == "Bite" then
				fovPunch -= 4
				pulse(state.Post, 6, 0.04)
				flashScreen(state.UI, 0.18)
			elseif name == "Land" then
				fovPunch -= 4
				pulse(state.Post, 5, 0)
			elseif name == "Footstep" and u > 1.5 then
				fovPunch -= 1.5
			elseif name == "CurtainOpen" or name == "FoliageBurst" then
				pulse(state.Post, 4, 0)
			end
		end)

		RunService:BindToRenderStep("DinoCinematicCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
			local t = state.Holding and D or track.T
			if not state.Holding then track.Speed = rampSpeed(list, t, D) end
			local st, index, shot = sampleShots(list, t, D, G, u, targets)
			-- smooth only within a shot so cuts stay crisp
			if index ~= lastShot and not ((shot.Blend or 0) > 0) then sLook = nil end
			lastShot = index
			local k = 1 - math.exp(-dt * 14)
			sLook = sLook and sLook:Lerp(st.Look, k) or st.Look
			local n = os.clock() - start
			local camPos = Vector3.new(st.Pos.X, math.max(st.Pos.Y, G.Y + 0.4), st.Pos.Z) -- never below the ground/water
			-- never behind a bush or a rock: if something sits between the subject and the lens, pull in front of it
			do
				-- (people never count: a teammate between the lens and the dino used to yank the camera into their back)
				local skip = { model :: Instance }
				for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(skip, plr.Character) end end
				local actors = Workspace:FindFirstChild("DinoCutsceneActors")
				if actors then table.insert(skip, actors) end
				occl.FilterDescendantsInstances = skip
				local d = camPos - sLook
				local reach = d.Magnitude
				if d.Magnitude > 2 then
					for _ = 1, 6 do
						local hit = Workspace:Raycast(sLook, d, occl)
						if not hit then break end
						local ok, soft = pcall(softPart, hit.Instance)
						if hit.Instance.Transparency >= 0.9 or hit.Instance.LocalTransparencyModifier >= 0.99 then
							-- (an invisible wall, a marker or something a cutscene already tucked away: look past it)
							table.insert(skip, hit.Instance)
							occl.FilterDescendantsInstances = skip
						elseif ok and soft then
							-- the whole little plant goes, not one leaf
							local m = hit.Instance:FindFirstAncestorWhichIsA("Model")
							local group = (m and m ~= Workspace and m:GetExtentsSize().Magnitude < 30) and m or hit.Instance
							for _, q in ipairs(group:IsA("BasePart") and { group } or group:GetDescendants()) do
								if q:IsA("BasePart") and q.LocalTransparencyModifier < 1 then q.LocalTransparencyModifier = 1 lensFaded[q] = true end
							end
							table.insert(skip, group)
							occl.FilterDescendantsInstances = skip
						else
							reach = math.max(0.5, (hit.Position - sLook).Magnitude - 1.2)
							break
						end
					end
				end
				-- (no popping in and out as an edge flickers across the line: the lens snaps in front of whatever blocks
				-- it, but eases back out once it's clear; a cut starts fresh. 2026-10-14 jitter pass)
				if index ~= state.PullShot then state.PullShot, state.Pull = index, nil end
				if reach < d.Magnitude - 0.01 and (not state.Pull or reach < state.Pull) then
					state.Pull = reach
				elseif state.Pull then
					state.Pull += (reach - state.Pull) * (1 - math.exp(-dt * 3))
					if state.Pull >= d.Magnitude - 0.05 then state.Pull = nil end
				end
				if state.Pull and d.Magnitude > 0.01 then camPos = sLook + d.Unit * math.min(state.Pull, d.Magnitude) end
			end
			local cf = CFrame.lookAt(camPos, sLook)
				* CFrame.Angles(
					math.noise(n * 0.9, 0.5) * 0.012 * handheld,
					math.noise(n * 0.8, 8.5) * 0.016 * handheld,
					math.rad(st.Roll) + math.noise(n * 0.6, 3.3) * 0.01 * handheld
				)
			fovPunch *= math.exp(-dt * 6)
			local holdPush = 0
			if state.Holding then
				local h = os.clock() - state.HoldStart
				holdPush = math.min(h, state.HoldTime) * 0.5 -- slow push-in on the held hero frame
			end
			cam.CFrame = cf
			cam.FieldOfView = math.clamp(st.Fov + fovPunch - holdPush, 10, 100)
			if state.Post and state.Post.Dof then
				local dist = (camPos - sLook).Magnitude
				state.Post.Dof.FocusDistance = math.clamp(dist, 1, 200)
				state.Post.Dof.InFocusRadius = math.clamp(dist * 0.35, 2, 50)
			end
			if not titled and t >= titleAt then
				titled = true
				showTitle(state.UI)
			end
		end)
		if opts.Skippable ~= false then
			ContextActionService:BindAction("DinoSkipCinematic", function(_, inputState)
				if inputState == Enum.UserInputState.Begin then DinosaurCinematics.Continue() end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
		end
	end

	state.HoldTime = (state.CameraTaken and list and list.Hold) or 0
	task.spawn(function()
		local completed = track.Finished:Wait()
		if state.Done then return end
		if state.HoldTime > 0 then
			DinosaurCinematics._enterHold(state)
		else
			finish(state, completed ~= false)
		end
	end)
	-- watchdog (2026-10-14): the animator only steps a model that's in the Workspace, and a model destroyed / pulled
	-- out mid-intro (or an action that errors and is cleared) never fires Finished - the camera stayed bound here for
	-- good and every later scene waited on IsPlaying(). Whatever happens to the model, the intro lets go
	task.spawn(function()
		local gone = 0
		local cap = D * 3 + state.HoldTime + 10
		while not state.Done do
			task.wait(0.25)
			if state.Done then break end
			local lost = not model:IsDescendantOf(Workspace)
				or (not state.Holding and not table.find(anim.Actions, track))
			gone = lost and gone + 0.25 or 0
			if gone >= 0.75 or os.clock() - state.StartedAt > cap then
				finish(state, false)
				break
			end
		end
	end)
	return { Finished = event.Event, Stop = function() finish(state, false) end }
end

function DinosaurCinematics.PlayIntro(model: Model, opts)
	local anim = DinosaurAnimations.get(model)
	if not anim then return nil end
	local p = anim.Profile
	return DinosaurCinematics.Play(model, p.Intro or p.Signature, p.IntroShots or "Roar", opts)
end

function DinosaurCinematics.PlayRoar(model: Model, opts)
	return DinosaurCinematics.Play(model, "Roar", "Roar", opts)
end

function DinosaurCinematics.PlayAttack(model: Model, opts)
	return DinosaurCinematics.Play(model, "Attack", "Attack", opts)
end

function DinosaurCinematics.PlayChase(model: Model, opts)
	local anim = DinosaurAnimations.get(model)
	if not anim then return nil end
	return DinosaurCinematics.Play(model, anim.Profile.Chase or "Chase", "Chase", opts)
end

-- Hold on the hero frame with the title card up until the player taps (or HoldTime passes)
function DinosaurCinematics._enterHold(state)
	if state.Holding or state.Done then return end
	state.Holding = true
	state.HoldStart = os.clock()
	showTitle(state.UI)
	task.delay(state.HoldTime, function()
		if not state.Done then finish(state, true) end
	end)
end

-- Tap: during the action, skip to the held ending; during the hold, exit
function DinosaurCinematics.Continue()
	local state = current
	if not state then return end
	-- the first second can't be skipped (spam-tapping into a cutscene shouldn't skip it)
	if os.clock() - (state.StartedAt or 0) < 1 then return end
	if state.HoldTime > 0 and not state.Holding then
		if state.Track then state.Track:Stop(0.3) end
		DinosaurVFX.ResetEnvironment(state.Model)
		DinosaurCinematics._enterHold(state)
	else
		finish(state, true)
	end
end

function DinosaurCinematics.Stop()
	if current then finish(current, false) end
end

function DinosaurCinematics.IsPlaying(): boolean
	return current ~= nil
end

function DinosaurCinematics.CurrentModel(): Model?
	return current and current.Model
end

return DinosaurCinematics
