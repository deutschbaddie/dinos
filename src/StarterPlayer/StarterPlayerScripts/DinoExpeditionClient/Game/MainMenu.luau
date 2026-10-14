--[[
	MainMenu — the PRE-BETA tester front door (live servers only: Testing.Active(); Studio skips it).

	MainMenu.Run() yields until the player presses PLAY (returns true), or returns false straight away when
	there's no test phase on this server. While it runs, Base Camp plays behind it in slow cinematic shots
	(Time Gate push-in, the guardian T. rex, the plaza from above, the ridge, your own camp).

	  1. CHECKING ACCESS  the server's verdict (player attr Access) ticks off three rows: TESTER LIST, GROUP, SAVE.
	                      Not in the group yet -> a JOIN GROUP button (GroupService prompt) and a live re-check.
	                      Not on the list -> ACCESS DENIED stamp + where to apply; the server kicks a few seconds later.
	  2. MENU             PLAY / TESTER WALL / REPORT A BUG, your tester chip, the build tag.
	  3. PLAY             fade, a swoop down behind your character, and the game boots (init.client).

	After PLAY a small build tag stays on screen so every clip and screenshot says it's a test build.
]]

local ContextActionService = game:GetService("ContextActionService")
local GroupService = game:GetService("GroupService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Testing = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Testing"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local CineKit = require(script.Parent.UI.CineKit)
local Cinema = require(script.Parent.UI.Cinema)

local player = Players.LocalPlayer
local C = Kit.Colors
local MainMenu = {}

local function new(class: string, props, parent: Instance?)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do (i :: any)[k] = v end
	if parent then i.Parent = parent end
	return i
end
local function tween(inst: Instance, t: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

--------------------------------------------------------------------------------
-- background: Base Camp shots (hub-local: origin = plaza centre, north = -Z; QC'd in tools/preview at 16:9)
--------------------------------------------------------------------------------
local function hubOrigin(): Vector3
	local camp = Workspace:FindFirstChild("BaseCamp")
	local floor = camp and camp:FindFirstChild("PlazaFloor", true)
	if floor and floor:IsA("BasePart") then return Vector3.new(floor.Position.X, 0, floor.Position.Z) end
	return Vector3.new(600, 0, 0)
end

-- your island (or island 1 until the server assigns one), seen from above its bridge: the plot model carries its
-- angle (tools/gen/islandLayout.js: islands at 52..308 deg, front shore 280 out, centre 400 out)
local function plotShot()
	local idx = tonumber(player:GetAttribute("Plot")) or 1
	local camp = Workspace:FindFirstChild("BaseCamp")
	local plots = camp and camp:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. idx)
	local deg = (plot and plot:GetAttribute("IslandAngle")) or (52 + (idx - 1) * (256 / 7))
	local a = math.rad(deg)
	local d = Vector3.new(math.sin(a), 0, -math.cos(a))
	local r = Vector3.new(math.cos(a), 0, math.sin(a))
	return {
		A = d * 215 - r * 45 + Vector3.new(0, 42, 0), B = d * 228 + r * 35 + Vector3.new(0, 34, 0),
		LA = d * 385 + Vector3.new(0, 4, 0), LB = d * 395 + r * 8 + Vector3.new(0, 5, 0), Fov = { 55, 52 },
	}
end

local SHOTS = {
	{ Name = "THE TIME GATE", T = 7.5, Get = function()
		return { A = Vector3.new(22, 8, -116), B = Vector3.new(12, 9, -129), LA = Vector3.new(0, 20, -162), LB = Vector3.new(0, 21, -162), Fov = { 56, 50 } }
	end },
	{ Name = "BASE CAMP", T = 8.5, Get = function()
		return { A = Vector3.new(64, 54, 16), B = Vector3.new(50, 52, 32), LA = Vector3.new(-4, 6, -40), LB = Vector3.new(-6, 6, -42), Fov = { 55, 55 } } -- clear of the HQ mast
	end },
	{ Name = "THE GUARDIANS", T = 6.5, Get = function()
		return { A = Vector3.new(43, 5.5, -125), B = Vector3.new(38, 6.5, -123), LA = Vector3.new(30.5, 14.5, -145), LB = Vector3.new(30.5, 16, -146), Fov = { 50, 46 } }
	end },
	{ Name = "YOUR ISLAND", T = 7.5, Get = plotShot },
	{ Name = "THE LAGOON", T = 8.5, Get = function()
		return { A = Vector3.new(-40, 150, 600), B = Vector3.new(50, 135, 560), LA = Vector3.new(-10, 0, -40), LB = Vector3.new(10, 0, -60), Fov = { 52, 50 } }
	end },
	{ Name = "THE RIDGE", T = 8, Get = function()
		return { A = Vector3.new(0, 62, 42), B = Vector3.new(0, 72, 20), LA = Vector3.new(0, 34, -260), LB = Vector3.new(0, 38, -260), Fov = { 55, 52 } }
	end },
}

--------------------------------------------------------------------------------
-- small pieces
--------------------------------------------------------------------------------
local function thumb(userId: number, kind: Enum.ThumbnailType?, img: ImageLabel)
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, kind or Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if ok and img.Parent then img.Image = url end
	end)
end

-- a rounded avatar tile: brick frame + the headshot inside
local function avatarTile(parent: Instance, userId: number, size: number, props)
	props = props or {}
	local outer, content = Kit.Brick(parent, { Name = "Avatar", Size = UDim2.fromOffset(size, size), Position = props.Position, AnchorPoint = props.AnchorPoint, Color = props.Color or "Slate", Radius = 14, Lip = 5, ZIndex = props.ZIndex or 30, Inner = true })
	local img = new("ImageLabel", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), ZIndex = (props.ZIndex or 30) + 2, ScaleType = Enum.ScaleType.Crop }, content) :: ImageLabel
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, img)
	thumb(userId, props.Kind, img)
	return outer, img
end

-- chunky pill tag ("PRE-BETA TESTER", "DEV", "HERE NOW")
local function tag(parent: Instance, text: string, color: any, props)
	props = props or {}
	local sw = Kit.Swatch(color)
	local w = props.W or (#text * 9 + 26)
	local pill = new("Frame", { Name = "Tag", BackgroundColor3 = sw[1], Size = UDim2.fromOffset(w, props.H or 24), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 32, Rotation = props.Rotation or 0 }, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pill)
	new("UIStroke", { Color = C.Ink, Thickness = 2.5 }, pill)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(sw[2], sw[1]) }, pill)
	Kit.Text(pill, text, { Pixel = true, Size = UDim2.new(1, -12, 0, 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = pill.ZIndex + 1, Stroke = 2, Shadow = 2, MaxSize = 11 })
	return pill
end

-- a blocky loading spinner (a studded tile tumbling end over end)
local function spinner(parent: Instance, z: number)
	local holder = new("Frame", { Name = "Spinner", BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z }, parent)
	local sq = new("Frame", { BackgroundColor3 = C.YellowHi, Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = z }, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, sq)
	new("UIStroke", { Color = C.Ink, Thickness = 2.5 }, sq)
	local stud = new("Frame", { BackgroundColor3 = C.Yellow, Size = UDim2.fromScale(0.42, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = z + 1 }, sq)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, stud)
	new("UIStroke", { Color = C.YellowLo, Thickness = 1.5 }, stud)
	task.spawn(function()
		local t0 = os.clock()
		while holder.Parent do
			local t = os.clock() - t0
			sq.Rotation = (t * 360) % 360
			local s = 0.82 + math.abs(math.sin(t * 6)) * 0.18
			sq.Size = UDim2.fromScale(s, s)
			RunService.RenderStepped:Wait()
		end
	end)
	return holder
end

--------------------------------------------------------------------------------
-- the build tag: stays on screen for the whole test (Cinema hides it in cutscenes like any other screen)
--------------------------------------------------------------------------------
local tagGui: ScreenGui? = nil
function MainMenu.ShowBuildTag()
	if tagGui or not Testing.Active() then return end
	local gui = new("ScreenGui", { Name = "DinoBuildTag", ResetOnSpawn = false, DisplayOrder = 1, IgnoreGuiInset = false }) :: ScreenGui
	local label = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -4), Size = UDim2.fromOffset(360, 12),
		FontFace = Kit.Pixel, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.35,
		Text = Testing.Build .. " TEST BUILD - NOT FINAL", Active = false,
	}, gui)
	new("UIStroke", { Color = C.Ink, Thickness = 1.5, Transparency = 0.35 }, label)
	gui.Parent = player:WaitForChild("PlayerGui")
	tagGui = gui
end

--------------------------------------------------------------------------------
-- the menu
--------------------------------------------------------------------------------
local FREEZE = "DinoMenuFreeze"
local function run(ctx): boolean
	Net.Hold() -- the game isn't listening yet: keep server messages for when it is (init.client releases)

	local cam = Workspace.CurrentCamera
	local origin = hubOrigin()
	local gui, canvas = Kit.Screen("DinoMainMenu", 120, true)
	ctx.gui = gui
	local root = gui:FindFirstChild("Root") :: Frame
	canvas.ZIndex = 5 -- above the vignette + shot-cut dip layers that share Root with it

	-- hold the world still: no core gui, no prompts, no walking; blur + depth of field for the check
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
	local promptsWere = ProximityPromptService.Enabled
	ctx.promptsWere = promptsWere
	ProximityPromptService.Enabled = false
	local controls = nil
	task.spawn(function()
		pcall(function()
			local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10) :: any)
			controls = pm:GetControls()
			ctx.controls = controls
			if ctx.gui and ctx.gui.Parent then controls:Disable() end
		end)
	end)
	-- the control module turns itself back on when the input type changes: sink movement + jump as well
	ContextActionService:BindActionAtPriority(FREEZE, function() return Enum.ContextActionResult.Sink end, false, 3000,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward, Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	local blur = new("BlurEffect", { Name = "DinoMenuBlur", Size = 18 }, Lighting) :: BlurEffect
	local dof = new("DepthOfFieldEffect", { Name = "DinoMenuDoF", FarIntensity = 0.28, FocusDistance = 60, InFocusRadius = 70, NearIntensity = 0 }, Lighting)
	ctx.blur, ctx.dof = blur, dof

	-- screen layers (full bleed, under the canvas): vignette for the menu column, the black dip between shots
	local vignette = new("Frame", { Name = "Vignette", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, BackgroundTransparency = 0 }, root)
	new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.42, 0.75), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.85),
	}) }, vignette)
	vignette.Visible = false
	local floorShade = new("Frame", { Name = "FloorShade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.7), ZIndex = 1 }, root)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.45) }, floorShade)
	local dip = new("Frame", { Name = "Dip", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, BackgroundTransparency = 0 }, root) :: Frame
	local black = new("Frame", { Name = "Black", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 200, BackgroundTransparency = 0 }, gui) :: Frame
	tween(black, 0.9, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)

	-- shot caption (top right): a yellow bar + the place's name, slides in on every cut
	local caption = new("Frame", { Name = "Caption", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 26), Size = UDim2.fromOffset(300, 26), ZIndex = 10 }, canvas)
	local capBar = new("Frame", { BackgroundColor3 = C.Yellow, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(6, 22), ZIndex = 10 }, caption)
	new("UIStroke", { Color = C.Ink, Thickness = 2 }, capBar)
	local capText = Kit.Text(caption, "", { Pixel = true, Size = UDim2.new(1, -18, 0, 12), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 11, Stroke = 2, Shadow = 2, MaxSize = 13 })

	-- the camera: one shot after another, eased pushes with a breath of handheld, a black dip on every cut
	cam.CameraType = Enum.CameraType.Scriptable
	local shotIdx, shotT0, shot, shotDef = 0, os.clock(), nil :: any, nil :: any
	local function nextShot()
		shotIdx = shotIdx % #SHOTS + 1
		shotDef = SHOTS[shotIdx]
		shot = shotDef.Get()
		shotT0 = os.clock()
		Kit.SetText(capText, shotDef.Name)
		caption.Position = UDim2.new(1, 10, 0, 26)
		tween(caption, 0.6, { Position = UDim2.new(1, -28, 0, 26) }, Enum.EasingStyle.Quint)
	end
	nextShot()
	local camOn = true
	RunService:BindToRenderStep("DinoMainMenuCam", Enum.RenderPriority.Camera.Value + 1, function()
		if not camOn then return end
		local el = os.clock() - shotT0
		if el >= shotDef.T then nextShot() el = 0 end
		local a = el / shotDef.T
		local e = a * 0.55 + (1 - math.cos(math.pi * a)) / 2 * 0.45 -- mostly steady drift, soft at the ends
		local t = os.clock()
		local shake = Vector3.new(math.noise(t * 0.35, 1.3) * 0.35, math.noise(t * 0.35, 7.1) * 0.22, math.noise(t * 0.35, 3.7) * 0.2)
		local pos = origin + shot.A:Lerp(shot.B, e) + shake
		local look = origin + shot.LA:Lerp(shot.LB, e)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(pos, look)
		cam.FieldOfView = shot.Fov[1] + (shot.Fov[2] - shot.Fov[1]) * e
		local edge = math.min(el, shotDef.T - el)
		dip.BackgroundTransparency = math.clamp(edge / 0.45, 0, 1)
	end)

	----------------------------------------------------------------------------
	-- 1. CHECKING ACCESS
	----------------------------------------------------------------------------
	local win, inner, header = Kit.Window(canvas, { Name = "AccessCheck", Title = "CHECKING ACCESS", Color = "Teal", Icon = "Lock", Size = UDim2.fromOffset(560, 360), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), Fit = true, ZIndex = 40 })
	local holder = win.Parent :: Frame
	holder.ZIndex = 40 -- (the fit holder sits among the canvas's siblings; its UIScale fits the window on screen,
	-- so every animation below runs on the window itself)
	win.Visible = false
	task.delay(0.35, function() Kit.Enter(win) Kit.Sound("Pop", 0.4) end)
	local titleBox = header:FindFirstChild("Title")
	local function setTitle(text: string, strip: { Color3 }?)
		if titleBox then Kit.SetText(titleBox, text) end
		local g = header:FindFirstChildOfClass("UIGradient")
		if g and strip then g.Color = ColorSequence.new(strip[1], strip[2]) end
	end
	-- the title's dots tick while it thinks
	local thinking = true
	task.spawn(function()
		local n = 0
		while thinking and win.Parent do
			n = n % 3 + 1
			setTitle("CHECKING ACCESS" .. string.rep(".", n))
			task.wait(0.35)
		end
	end)

	-- left: your portrait under a scanner sweep
	local portrait = avatarTile(inner, player.UserId, 150, { Position = UDim2.fromOffset(4, 12), ZIndex = 44, Color = "Teal" })
	local scanClip = new("Frame", { Name = "Scan", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), ZIndex = 48 }, portrait:FindFirstChild("Body") :: Frame)
	local scanBar = new("Frame", { BackgroundColor3 = C.TealHi, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, -26), ZIndex = 48 }, scanClip)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(0.88, 0), NumberSequenceKeypoint.new(1, 1) }) }, scanBar)
	task.spawn(function()
		while thinking and scanBar.Parent do
			scanBar.Position = UDim2.new(0, 0, 0, -26)
			tween(scanBar, 1.1, { Position = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.25)
		end
		scanBar.Visible = false
	end)
	Kit.Text(inner, "@" .. player.Name, { Pixel = true, Size = UDim2.fromOffset(160, 12), Position = UDim2.fromOffset(79, 186), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 44, Stroke = 2, Shadow = 2, MaxSize = 11, Color = C.Cream })

	-- right: the three checks
	local rowsHolder = new("Frame", { Name = "Rows", BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 200), Position = UDim2.fromOffset(184, 8), ZIndex = 42 }, inner)
	local function row(i: number, title: string)
		local r = new("Frame", { Name = "Row" .. i, BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 56), Position = UDim2.fromOffset(0, (i - 1) * 64), ZIndex = 42 }, rowsHolder)
		local tile, tileContent = Kit.Brick(r, { Name = "Tile", Size = UDim2.fromOffset(50, 50), Color = "Slate", Radius = 12, Lip = 4, ZIndex = 43 })
		local spin = spinner(tileContent, 46)
		Kit.Text(r, title, { Size = UDim2.new(1, -66, 0, 26), Position = UDim2.fromOffset(64, 2), Align = Enum.TextXAlignment.Left, ZIndex = 44, Stroke = 3, Shadow = 3, MaxSize = 26 })
		local status = Kit.Text(r, "WAITING", { Pixel = true, Size = UDim2.new(1, -66, 0, 11), Position = UDim2.fromOffset(64, 34), Align = Enum.TextXAlignment.Left, ZIndex = 44, Stroke = 2, Shadow = 2, MaxSize = 11, Color = C.Muted })
		r.Visible = false
		local api = {}
		function api.Show()
			r.Visible = true
			Kit.Pop(r, 0.6)
			Kit.SetText(status, "CHECKING...")
		end
		function api.Spin()
			if not spin.Parent then
				for _, ch in ipairs(tileContent:GetChildren()) do if ch.Name ~= "Spinner" then ch:Destroy() end end
				spin = spinner(tileContent, 46)
				Kit.SetPanelColor(tile, "Slate")
			end
		end
		function api.Done(kind: string, text: string)
			spin:Destroy()
			for _, ch in ipairs(tileContent:GetChildren()) do ch:Destroy() end
			if kind == "Ok" then
				Kit.SetPanelColor(tile, "Lime")
				Kit.Glyph(tileContent, "Check", { Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 46 })
				Kit.SetTextColor(status, C.LimeHi)
				Kit.Sound("Click", 0.5, 1.25)
			elseif kind == "Wait" then
				Kit.SetPanelColor(tile, "Yellow")
				Kit.Text(tileContent, "!", { Size = UDim2.fromScale(0.7, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 46, Stroke = 3, MaxSize = 34 })
				Kit.SetTextColor(status, C.YellowHi)
				Kit.Sound("Click", 0.5, 0.9)
			elseif kind == "No" then
				Kit.SetPanelColor(tile, "Red")
				Kit.Glyph(tileContent, "X", { Size = UDim2.fromScale(0.56, 0.56), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 46 })
				Kit.SetTextColor(status, C.RedHi)
				Kit.Sound("Click", 0.5, 0.6)
			else -- skipped
				Kit.SetPanelColor(tile, "Grey")
				Kit.SetTextColor(status, C.Grey)
			end
			Kit.SetText(status, text)
			Kit.Punch(tile, 0.25)
		end
		return api
	end
	local rowList = row(1, Testing.Open and "PRE-BETA ACCESS" or "TESTER LIST")
	local rowGroup = row(2, "GROUP MEMBER")
	local rowSave = row(3, "PRE-BETA SAVE")

	local function access(): string?
		return player:GetAttribute("Access") :: string?
	end
	local function waitAccess(not_: string?, maxT: number): string?
		local t0 = os.clock()
		while os.clock() - t0 < maxT do
			local a = access()
			if a and a ~= "Checking" and a ~= not_ then return a end
			task.wait(0.1)
		end
		return access()
	end

	task.wait(0.9)
	rowList.Show()
	local t0 = os.clock()
	local verdict = waitAccess(nil, 90)
	-- the server never decided (still Checking after 90 s): say so and keep waiting, never wave them through
	if verdict ~= "Granted" and verdict ~= "NeedGroup" and verdict ~= "Denied" then
		warn("[MainMenu] no access verdict from the server after 90 s (Access =", tostring(verdict), ")")
		rowList.Done("Wait", "SERVER IS SLOW - HANG ON (OR REJOIN)")
		repeat
			task.wait(0.5)
			verdict = access()
		until verdict == "Granted" or verdict == "NeedGroup" or verdict == "Denied"
		rowList.Spin()
	end
	print("[MainMenu] access verdict:", verdict)
	task.wait(math.max(0, 1.4 - (os.clock() - t0)))

	-- DENIED: not on the list
	if verdict == "Denied" then
		thinking = false
		rowList.Done("No", "YOU'RE NOT ON THE LIST")
		task.wait(0.5)
		setTitle("ACCESS DENIED", { Color3.fromHex("FF8C7A"), Color3.fromHex("D62B3A") })
		CineKit.Stamp(root, "ACCESS DENIED", Testing.Phase .. " TESTERS ONLY", C.Red, 3, 0.2)
		Kit.Shake(win)
		rowsHolder:Destroy()
		local msg = new("Frame", { Name = "Denied", BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 200), Position = UDim2.fromOffset(184, 6), ZIndex = 42 }, inner)
		Kit.Text(msg, "WANT TO HELP TEST?", { Size = UDim2.new(1, 0, 0, 30), Align = Enum.TextXAlignment.Left, ZIndex = 44, Stroke = 3, Shadow = 3, MaxSize = 30, Color = C.YellowHi })
		Kit.Text(msg, "APPLY IN OUR DISCORD", { Pixel = true, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 40), Align = Enum.TextXAlignment.Left, ZIndex = 44, Stroke = 2, Shadow = 2, MaxSize = 12 })
		local pill = Kit.Brick(msg, { Size = UDim2.fromOffset(250, 56), Position = UDim2.fromOffset(0, 66), Color = "Purple", Radius = 14, Lip = 5, Stripes = 0.85, ZIndex = 44 })
		Kit.Text(pill:FindFirstChild("Body") :: Frame, Testing.Discord, { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 48, Stroke = 3.5, Shadow = 3, MaxSize = 32 })
		Kit.Bob(pill, 2, 2)
		local leave = Kit.Text(msg, "SEE YOU AT LAUNCH!", { Pixel = true, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 150), Align = Enum.TextXAlignment.Left, ZIndex = 44, Stroke = 2, Shadow = 2, MaxSize = 12, Color = C.Muted })
		task.wait(2)
		for n = 6, 1, -1 do
			Kit.SetText(leave, "SEE YOU AT LAUNCH!  LEAVING IN " .. n)
			task.wait(1)
		end
		-- the server kicks; just in case it doesn't, the menu never lets go
		while true do task.wait(60) end
	end

	-- a listed tester gets their title; in an open test everyone else is simply welcome
	rowList.Done("Ok", (player:GetAttribute("Tester") or not Testing.Open) and ("YOU'RE A " .. Testing.Phase .. " TESTER!") or "OPEN TEST - EVERYONE'S WELCOME!")
	task.wait(0.35)
	rowGroup.Show()
	task.wait(0.9)

	-- NOT IN THE GROUP YET: offer the join prompt, then re-check live
	if verdict == "NeedGroup" then
		rowGroup.Done("Wait", "JOIN THE GROUP TO PLAY")
		local groupName = "THE GROUP"
		pcall(function()
			local info = GroupService:GetGroupInfoAsync(Testing.GroupId)
			if info and info.Name then groupName = string.upper(info.Name) .. "'S GROUP" end
		end)
		local joinBtn
		local busy = false
		local function tryJoin()
			if busy then return end
			busy = true
			local okJoin, status = pcall(function() return (GroupService :: any):PromptJoinAsync(Testing.GroupId) end)
			if okJoin and tostring(status):find("Pending") then
				rowGroup.Done("Wait", "REQUEST SENT - WAIT FOR APPROVAL")
				busy = false
				return
			end
			rowGroup.Spin()
			for _ = 1, 4 do
				task.wait(1.6)
				local res = Net.Ask("AccessRecheck")
				if res.Access == "Granted" or access() == "Granted" then break end
			end
			if access() ~= "Granted" then rowGroup.Done("Wait", "NOT IN YET - TAP JOIN AGAIN") end
			busy = false
		end
		joinBtn = Kit.Button(inner, { Name = "Join", Text = "JOIN " .. groupName, Icon = "Gift", Color = "Yellow", Size = UDim2.fromOffset(330, 58), Position = UDim2.fromOffset(184, 196), ZIndex = 46, Shine = true, MaxText = 26, OnClick = tryJoin })
		Kit.Pop(joinBtn, 0.4)
		if Kit.Gamepad() then GuiService.SelectedObject = joinBtn:FindFirstChild("Hit") :: GuiObject end
		while access() ~= "Granted" do task.wait(0.2) end
		GuiService.SelectedObject = nil
		Kit.PopOut(joinBtn, true)
	end
	rowGroup.Done("Ok", "WELCOME TO THE CREW")
	task.wait(0.35)
	rowSave.Show()
	local s0 = os.clock()
	while not Net.Profile and os.clock() - s0 < 20 do task.wait(0.1) end
	task.wait(math.max(0, 1.0 - (os.clock() - s0)))
	if Net.Profile then rowSave.Done("Ok", "FRESH TEST SAVE LOADED") else rowSave.Done("Skip", "STILL LOADING - IT'LL CATCH UP") end
	thinking = false
	task.wait(0.5)

	-- GRANTED
	setTitle("ACCESS GRANTED", { Color3.fromHex("C8F55A"), Color3.fromHex("38B24A") })
	Kit.Punch(win, 0.08)
	CineKit.Stamp(root, "ACCESS GRANTED", "WELCOME, " .. string.upper(player.DisplayName), C.Lime, 1.6, 0.2)
	Kit.Sound("Pop", 0.6, 1.1)
	task.wait(1.4)
	Kit.Exit(win, true)
	tween(blur, 0.9, { Size = 0 }, Enum.EasingStyle.Sine)

	----------------------------------------------------------------------------
	-- 2. MENU
	----------------------------------------------------------------------------
	vignette.Visible = true
	vignette.BackgroundTransparency = 1
	tween(vignette, 0.8, { BackgroundTransparency = 0 })
	local menu = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20 }, canvas)

	-- logo
	local logo = new("Frame", { Name = "Logo", BackgroundTransparency = 1, Size = UDim2.fromOffset(400, 170), Position = UDim2.new(0, 46, 0.06, 0), Rotation = -3, ZIndex = 22 }, menu)
	Kit.Text(logo, "DINO", { Size = UDim2.fromOffset(250, 84), Position = UDim2.fromOffset(0, 0), Align = Enum.TextXAlignment.Left, Color = C.YellowHi, Color2 = C.Orange, Stroke = 6, Shadow = 6, MaxSize = 92, ZIndex = 23 })
	Kit.Text(logo, "EXPEDITION", { Size = UDim2.fromOffset(380, 58), Position = UDim2.fromOffset(2, 70), Align = Enum.TextXAlignment.Left, Color = C.LimeHi, Color2 = C.LimeLo, Stroke = 5, Shadow = 5, MaxSize = 60, ZIndex = 23 })
	Kit.Ribbon(logo, "PRE-BETA TEST BUILD", { Color = "Red", Position = UDim2.fromOffset(6, 128), Width = 290, Tilt = 2, Icon = "Alert", ZIndex = 24 })
	Kit.Bob(logo, 2.5, 1.4)

	-- the three buttons
	local playing = false
	local opened: Instance? = nil
	local function closeOpened()
		if opened and opened.Parent then Kit.Exit(opened :: any, true) end
		opened = nil
	end
	local playBtn, playHit = Kit.Button(menu, { Name = "Play", Text = "PLAY", Icon = "Gate", Color = "Lime", Size = UDim2.fromOffset(310, 92), Position = UDim2.new(0, 52, 0.5, 30), AnchorPoint = Vector2.new(0, 0.5), Shine = true, MaxText = 56, TextSize = 0.62, ZIndex = 24, IconSize = 0.92, OnClick = function() playing = true end })
	local wallBtn = Kit.Button(menu, { Name = "TesterWall", Text = "TESTER WALL", Icon = "Star", Color = "Blue", Size = UDim2.fromOffset(310, 64), Position = UDim2.new(0, 52, 0.5, 120), AnchorPoint = Vector2.new(0, 0.5), MaxText = 30, ZIndex = 24, OnClick = function() MainMenu.TesterWall(canvas, function(w) closeOpened() opened = w end) end })
	local bugBtn = Kit.Button(menu, { Name = "ReportBug", Text = "REPORT A BUG", Icon = "Alert", Color = "Orange", Size = UDim2.fromOffset(310, 64), Position = UDim2.new(0, 52, 0.5, 196), AnchorPoint = Vector2.new(0, 0.5), MaxText = 30, ZIndex = 24, OnClick = function() MainMenu.ReportBug(canvas, function(w) closeOpened() opened = w end) end })
	for i, b in ipairs({ playBtn, wallBtn, bugBtn }) do
		b.Visible = false
		task.delay(0.25 + i * 0.09, function() Kit.Pop(b, 0.3) end)
	end
	if Kit.Gamepad() then task.delay(0.6, function() GuiService.SelectedObject = playHit end) end

	-- your tester chip (bottom right)
	local chip = Kit.Card(menu, { Name = "You", Size = UDim2.fromOffset(310, 86), Position = UDim2.new(1, -26, 1, -30), AnchorPoint = Vector2.new(1, 1), ZIndex = 24 })
	local chipBody = chip:FindFirstChild("Body") :: Frame
	avatarTile(chipBody, player.UserId, 66, { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 27, Color = "Yellow" })
	Kit.Text(chipBody, string.upper(player.DisplayName), { Size = UDim2.new(1, -96, 0, 26), Position = UDim2.fromOffset(86, 10), Align = Enum.TextXAlignment.Left, ZIndex = 28, Stroke = 3, Shadow = 3, MaxSize = 26 })
	Kit.Text(chipBody, "@" .. player.Name, { Pixel = true, Size = UDim2.new(1, -96, 0, 10), Position = UDim2.fromOffset(86, 38), Align = Enum.TextXAlignment.Left, ZIndex = 28, Stroke = 2, Shadow = 2, MaxSize = 10, Color = C.Muted })
	if player:GetAttribute("Tester") then
		tag(chipBody, Testing.Phase .. " TESTER", "Yellow", { Position = UDim2.fromOffset(86, 54), ZIndex = 29 })
	else
		tag(chipBody, "DEV", "Red", { Position = UDim2.fromOffset(86, 54), ZIndex = 29 })
	end
	chip.Visible = false
	task.delay(0.6, function() Kit.Pop(chip, 0.5) end)

	-- build + server code (bottom left): what to quote in a bug report
	local code = string.upper(string.sub(game.JobId ~= "" and game.JobId or "STUDIO", 1, 8))
	Kit.Text(menu, Testing.Build .. "  -  SERVER " .. code, { Pixel = true, Size = UDim2.fromOffset(360, 10), Position = UDim2.new(0, 54, 1, -24), AnchorPoint = Vector2.new(0, 1), Align = Enum.TextXAlignment.Left, ZIndex = 24, Stroke = 2, Shadow = 2, MaxSize = 10, Color = C.Cream })

	-- WHAT'S NEW (Testing.WhatsNew): what changed in this build, every time testers come in (top right)
	local news = Testing.WhatsNew or {}
	local newsCard: Instance? = nil
	if #news > 0 then
		local H = 58 + #news * 40 + (Testing.NextUp and 30 or 8)
		-- (below the shot caption, which sits top right at y 26)
		local card = Kit.Card(menu, { Name = "WhatsNew", Size = UDim2.fromOffset(400, H), Position = UDim2.new(1, -26, 0, 64), AnchorPoint = Vector2.new(1, 0), ZIndex = 24 })
		local body = card:FindFirstChild("Body") :: Frame
		Kit.Text(body, "WHAT'S NEW", { Size = UDim2.new(1, -150, 0, 30), Position = UDim2.fromOffset(14, 10), Align = Enum.TextXAlignment.Left, ZIndex = 28, Stroke = 3.5, Shadow = 3, MaxSize = 30, Color = C.YellowHi })
		tag(body, "IN " .. Testing.Version, "Lime", { Position = UDim2.new(1, -14, 0, 16), AnchorPoint = Vector2.new(1, 0), ZIndex = 29 })
		for i, item in ipairs(news) do
			local y = 52 + (i - 1) * 40
			Kit.Icon(body, item.Icon or "Star", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, y), ZIndex = 28 })
			Kit.Text(body, item.Title, { Size = UDim2.new(1, -76, 0, 20), Position = UDim2.fromOffset(60, y + 1), Align = Enum.TextXAlignment.Left, ZIndex = 28, Stroke = 2.5, Shadow = 2, MaxSize = 20 })
			Kit.Text(body, item.Line, { Pixel = true, Size = UDim2.new(1, -76, 0, 9), Position = UDim2.fromOffset(60, y + 23), Align = Enum.TextXAlignment.Left, ZIndex = 28, Stroke = 2, Shadow = 2, MaxSize = 9, Color = C.Muted })
		end
		if Testing.NextUp then
			Kit.Text(body, Testing.NextUp, { Pixel = true, Size = UDim2.new(1, -28, 0, 10), Position = UDim2.new(0, 14, 1, -22), Align = Enum.TextXAlignment.Left, ZIndex = 28, Stroke = 2, Shadow = 2, MaxSize = 10, Color = C.LimeHi })
		end
		card.Visible = false
		task.delay(0.75, function() if card.Parent then Kit.Pop(card, 0.5) end end)
		newsCard = card
	end

	while not playing do task.wait(0.05) end

	----------------------------------------------------------------------------
	-- 3. PLAY: fade, then swoop down behind your character
	----------------------------------------------------------------------------
	GuiService.SelectedObject = nil
	closeOpened()
	Kit.Sound("Pop", 0.6, 1.2)
	for _, b in ipairs({ playBtn, wallBtn, bugBtn, chip }) do Kit.PopOut(b) end
	if newsCard then Kit.PopOut(newsCard :: any) end
	tween(black, 0.45, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
	task.wait(0.5)
	camOn = false
	RunService:UnbindFromRenderStep("DinoMainMenuCam")
	menu:Destroy()
	caption:Destroy()
	vignette:Destroy()
	floorShade:Destroy()
	dip:Destroy()
	blur:Destroy()
	dof:Destroy()

	-- a brand-new player goes straight into the cold open (Prologue, started by Onboarding): stay black for it
	local prof = Net.Profile
	local coldOpen = prof ~= nil and prof.Flags ~= nil and prof.Flags.ColdOpenSeen ~= true -- (Onboarding plays it: same test)
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp and not coldOpen then
		local lookV = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		lookV = lookV.Magnitude > 0.01 and lookV.Unit or Vector3.new(0, 0, -1)
		local focus = hrp.Position + lookV * 6 + Vector3.new(0, 1.5, 0)
		local endCF = CFrame.lookAt(hrp.Position - lookV * 13 + Vector3.new(0, 6, 0), focus)
		local startCF = CFrame.lookAt(hrp.Position - lookV * 34 + Vector3.new(0, 26, 0), hrp.Position + Vector3.new(0, 1, 0))
		cam.CFrame = startCF
		cam.FieldOfView = 60
		tween(black, 0.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
		local d = 1.5
		local s0 = os.clock()
		while true do
			local a = math.clamp((os.clock() - s0) / d, 0, 1)
			local e = TweenService:GetValue(a, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
			cam.CFrame = startCF:Lerp(endCF, e)
			cam.FieldOfView = 60 + 10 * e
			if a >= 1 then break end
			RunService.RenderStepped:Wait()
		end
	elseif not coldOpen then
		tween(black, 0.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	end
	cam.FieldOfView = 70
	cam.CameraType = Enum.CameraType.Custom
	if hum then cam.CameraSubject = hum end

	-- hand the world back
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- the game has its own hotbar (as Cinema does)
	end)
	ProximityPromptService.Enabled = promptsWere
	ContextActionService:UnbindAction(FREEZE)
	if controls then pcall(function() (controls :: any):Enable() end) end
	-- (cold open: the black hangs on until the prologue holds the screen (Cinema), 8 s at most, then lifts)
	task.spawn(function()
		if coldOpen then
			local w0 = os.clock()
			while not Cinema.Playing() and os.clock() - w0 < 8 do task.wait(0.05) end
			task.wait(0.2)
			tween(black, 0.4, { BackgroundTransparency = 1 })
			task.wait(0.45)
		else
			task.wait(0.6)
		end
		gui:Destroy()
	end)
	MainMenu.ShowBuildTag()
	print("[MainMenu] PLAY - booting the game")
	return true
end

local function cleanup(ctx)
	pcall(function() RunService:UnbindFromRenderStep("DinoMainMenuCam") end)
	ContextActionService:UnbindAction(FREEZE)
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	if ctx.controls then pcall(function() ctx.controls:Enable() end) end
	if ctx.promptsWere ~= nil then ProximityPromptService.Enabled = ctx.promptsWere end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	for _, k in ipairs({ "gui", "blur", "dof" }) do
		if ctx[k] then ctx[k]:Destroy() end
	end
end

function MainMenu.Run(): boolean
	if not Testing.Active() then
		print("[MainMenu] no test phase on this server (Studio, or Testing.Enabled is off) - straight into the game")
		return false
	end
	print("[MainMenu] " .. Testing.Phase .. " menu starting")
	local ctx = {}
	local ok, res = pcall(run, ctx)
	if ok then return res end
	warn("[MainMenu] the menu broke, booting the game without it:", res)
	cleanup(ctx)
	return false
end

--------------------------------------------------------------------------------
-- TESTER WALL: every approved tester, with who's in this server right now
--------------------------------------------------------------------------------
function MainMenu.TesterWall(canvas: Instance, onOpen: (Instance) -> ())
	local win, inner
	win, inner = Kit.Window(canvas, { Name = "TesterWall", Title = "TESTER WALL", Color = "Blue", Icon = "Star", Size = UDim2.fromOffset(760, 450), Position = UDim2.fromScale(0.62, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Fit = true, ZIndex = 60,
		OnClose = function() Kit.Exit(win, true) end })
	onOpen(win)
	win.Parent.ZIndex = 60
	Kit.Enter(win)
	Kit.Text(inner, "THANK YOU FOR HELPING BUILD DINO EXPEDITION!", { Pixel = true, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 4), ZIndex = 64, Stroke = 2, Shadow = 2, MaxSize = 12, Color = C.YellowHi })
	-- scrolls once the list outgrows two rows (12+ testers)
	local grid = new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -30), Position = UDim2.fromOffset(0, 28), ZIndex = 62,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.YellowHi, ElasticBehavior = Enum.ElasticBehavior.Never }, inner)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, grid)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(132, 160), CellPadding = UDim2.fromOffset(12, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	-- the developer: the group's owner (or the place's creator)
	local devId = game.CreatorType == Enum.CreatorType.User and game.CreatorId or 0
	pcall(function()
		local info = GroupService:GetGroupInfoAsync(Testing.GroupId)
		if info and info.Owner then devId = info.Owner.Id end
	end)
	local cards = {}
	for i, t in ipairs(Testing.Testers) do
		local cell = new("Frame", { Name = t.Name, BackgroundTransparency = 1, LayoutOrder = (t.UserId == devId) and 0 or i, ZIndex = 62 }, grid)
		local here = Players:GetPlayerByUserId(t.UserId) ~= nil
		local card = Kit.Card(cell, { Size = UDim2.new(1, 0, 1, -6), ZIndex = 63, Border = here and C.Lime or nil })
		local body = card:FindFirstChild("Body") :: Frame
		avatarTile(body, t.UserId, 84, { Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 66, Color = t.UserId == devId and "Red" or "Yellow" })
		local nameBox = Kit.Text(body, string.upper(t.Name), { Size = UDim2.new(1, -12, 0, 18), Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 67, Stroke = 2.5, Shadow = 2, MaxSize = 18 })
		task.spawn(function()
			local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(t.UserId) end)
			if ok and name and nameBox.Parent then Kit.SetText(nameBox, string.upper(name)) end
		end)
		if t.UserId == devId then
			tag(body, "DEV", "Red", { Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 68, W = 60 })
		elseif here then
			tag(body, "HERE NOW", "Lime", { Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 68 })
		else
			tag(body, "TESTER", "Yellow", { Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 68 })
		end
		table.insert(cards, cell)
	end
	for i, c in ipairs(cards) do
		c.Visible = false
		task.delay(0.15 + i * 0.05, function() if c.Parent then Kit.Pop(c, 0.4) end end)
	end
end

--------------------------------------------------------------------------------
-- REPORT A BUG: how and where, plus the build + server code to quote
--------------------------------------------------------------------------------
function MainMenu.ReportBug(canvas: Instance, onOpen: (Instance) -> ())
	local win, inner
	win, inner = Kit.Window(canvas, { Name = "ReportBug", Title = "REPORT A BUG", Color = "Orange", Icon = "Alert", Size = UDim2.fromOffset(620, 420), Position = UDim2.fromScale(0.62, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Fit = true, ZIndex = 60,
		OnClose = function() Kit.Exit(win, true) end })
	onOpen(win)
	win.Parent.ZIndex = 60
	Kit.Enter(win)
	local steps = {
		{ "1", "WHAT WERE YOU DOING?", "WHERE YOU WERE + WHAT YOU PRESSED", "Blue" },
		{ "2", "WHAT WENT WRONG?", "WHAT YOU EXPECTED VS WHAT HAPPENED", "Red" },
		{ "3", "SHOW US!", "A CLIP OR SCREENSHOT HELPS A TON", "Lime" },
	}
	for i, s in ipairs(steps) do
		local y = (i - 1) * 60
		local num = Kit.Brick(inner, { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(6, y + 4), Color = s[4], Radius = 12, Lip = 4, ZIndex = 64 })
		Kit.Text(num:FindFirstChild("Body") :: Frame, s[1], { Size = UDim2.fromScale(0.6, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 68, Stroke = 3, MaxSize = 30 })
		Kit.Text(inner, s[2], { Size = UDim2.new(1, -80, 0, 24), Position = UDim2.fromOffset(66, y + 4), Align = Enum.TextXAlignment.Left, ZIndex = 65, Stroke = 3, Shadow = 3, MaxSize = 24 })
		Kit.Text(inner, s[3], { Pixel = true, Size = UDim2.new(1, -80, 0, 10), Position = UDim2.fromOffset(66, y + 34), Align = Enum.TextXAlignment.Left, ZIndex = 65, Stroke = 2, Shadow = 2, MaxSize = 10, Color = C.Muted })
	end
	-- where: the Discord
	Kit.Text(inner, "POST IT IN OUR DISCORD", { Size = UDim2.new(0.55, 0, 0, 22), Position = UDim2.fromOffset(6, 192), Align = Enum.TextXAlignment.Left, ZIndex = 65, Stroke = 3, Shadow = 3, MaxSize = 22, Color = C.YellowHi })
	local pill = Kit.Brick(inner, { Size = UDim2.fromOffset(220, 50), Position = UDim2.fromOffset(6, 222), Color = "Purple", Radius = 14, Lip = 5, Stripes = 0.85, ZIndex = 64 })
	Kit.Text(pill:FindFirstChild("Body") :: Frame, Testing.Discord, { Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 68, Stroke = 3.5, Shadow = 3, MaxSize = 28 })
	-- the code to quote (selectable, so PC players can copy it)
	local code = Testing.Build .. " / " .. string.upper(string.sub(game.JobId ~= "" and game.JobId or "STUDIO", 1, 8)) .. " / " .. player.UserId
	Kit.Text(inner, "ADD THIS CODE", { Pixel = true, Size = UDim2.fromOffset(240, 10), Position = UDim2.fromOffset(262, 196), Align = Enum.TextXAlignment.Left, ZIndex = 65, Stroke = 2, Shadow = 2, MaxSize = 10 })
	local codeBox = Kit.Brick(inner, { Size = UDim2.fromOffset(310, 50), Position = UDim2.fromOffset(262, 222), Color = "Forest", Radius = 12, Lip = 4, ZIndex = 64 })
	local tb = new("TextBox", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4), ZIndex = 68, FontFace = Kit.Pixel, TextScaled = true,
		TextColor3 = C.YellowHi, Text = code, ClearTextOnFocus = false, TextEditable = false, TextXAlignment = Enum.TextXAlignment.Left,
	}, codeBox:FindFirstChild("Body") :: Frame)
	new("UITextSizeConstraint", { MaxTextSize = 11 }, tb)
	Kit.Text(inner, "THANK YOU! EVERY REPORT MAKES THE GAME BETTER", { Pixel = true, Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10), ZIndex = 65, Stroke = 2, Shadow = 2, MaxSize = 10, Color = C.LimeHi })
end

return MainMenu
