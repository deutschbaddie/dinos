--[[
	Kit — the Dino Expedition UI toolkit.

	Look (the DINO EXPEDITION UI style guide): chunky raised pieces with thick dark-green outlines, a darker
	bottom lip and a thin white highlight on the top edge; dark jungle-green windows and cards with lighter
	green inner borders; Expedition Yellow as the accent; 3D icons built from the game's own models, often
	breaking out of their frames; Press Start 2P everywhere — white / yellow / lime with outline + drop shadow.

	Motion: windows pop + tilt in, cards stagger, buttons lift on hover and press into their lip,
	the main call to action gets a shine sweep, numbers roll, coins fly into the counter.

	Everything is authored at a 960 x 560 reference size and scaled per device by one UIScale.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local Kit = {}
Kit.Font = Theme.Display
Kit.Pixel = Theme.Pixel
Kit.Theme = Theme
local C = Theme.C

-- every theme colour (YellowHi, Muted, LimeHi, ...) plus a couple of friendly aliases
Kit.Colors = table.clone(C) :: any
Kit.Colors.Green = C.Lime
Kit.Colors.GreenHi = C.LimeHi

local function shade(c: Color3, f: number): Color3
	if f >= 1 then return c:Lerp(Color3.new(1, 1, 1), f - 1) end
	return c:Lerp(Color3.new(0, 0, 0), 1 - f)
end
Kit.Shade = shade

local function tween(inst: Instance, t: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
Kit.Tween = tween

local function new(class: string, props, parent: Instance?)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do (i :: any)[k] = v end
	if parent then i.Parent = parent end
	return i
end
Kit.New = new

local function corner(p: Instance, r: number)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end
local function stroke(p: Instance, color: Color3, t: number, mode: Enum.ApplyStrokeMode?)
	return new("UIStroke", { Color = color, Thickness = t, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border }, p)
end
local function gradient(p: Instance, top: Color3, bottom: Color3, rot: number?)
	return new("UIGradient", { Rotation = rot or 90, Color = ColorSequence.new(top, bottom) }, p)
end
Kit.Corner, Kit.Stroke, Kit.Gradient = corner, stroke, gradient

local function swatch(color: any)
	if typeof(color) == "string" then return Theme.Swatch[color] or Theme.Swatch.Lime end
	if typeof(color) == "table" then return color end
	if typeof(color) == "Color3" then return Theme.Swatchify(color) end
	return Theme.Swatch.Lime
end
Kit.Swatch = swatch

--------------------------------------------------------------------------------
-- platform + scaling
--------------------------------------------------------------------------------
function Kit.Platform(): string
	if GuiService:IsTenFootInterface() then return "Console" end
	-- (some tablets / Android phones report a keyboard: a touch device whose last input was touch is still touch)
	if UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or not UserInputService.MouseEnabled
		or UserInputService:GetLastInputType() == Enum.UserInputType.Touch) then return "Touch" end
	return "Desktop"
end

function Kit.Gamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return GuiService:IsTenFootInterface() or (last.Name:find("Gamepad") ~= nil)
end

Kit.UserScale = 1
-- scale from the screen the gui really covers (the camera's viewport can read 1x1 for a moment at startup,
-- which used to lock every screen at the minimum scale)
function Kit.ScaleFactor(size: Vector2?): number
	local vp = size
	if not vp or vp.X < 50 or vp.Y < 50 then
		local cam = Workspace.CurrentCamera
		vp = cam and cam.ViewportSize or Vector2.new(960, 560)
	end
	local v = vp :: Vector2
	if v.X < 50 or v.Y < 50 then v = Vector2.new(960, 560) end
	local s = math.min(v.X / 960, v.Y / 560)
	local p = Kit.Platform()
	if p == "Touch" then s *= 1.15 end
	if p == "Console" then s *= 1.1 end
	-- (2026-10-12, tester: "the ui gets too big on my screen") a desktop monitor is big and close, so the UI grows
	-- slower than the screen: about -14% on a 1366 laptop, -19% at 1080p, -24% at 1440p
	if p == "Desktop" then s = (s ^ 0.8) * 0.92 end
	return math.clamp(s * Kit.UserScale, 0.62, 2.2)
end

local screens = {} :: { [ScreenGui]: () -> () }
local viewportHooked = false
-- mult: extra scale for this screen (the HUD sits smaller, like the reference games; touch keeps more of it)
function Kit.Screen(name: string, order: number, fullBleed: boolean?, mult: number?)
	local gui = new("ScreenGui", { Name = name, ResetOnSpawn = false, DisplayOrder = order, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	if fullBleed then
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
	else
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	local canvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }, root)
	local scale = new("UIScale", {}, canvas)
	local function fit()
		local abs = root.AbsoluteSize
		local m = mult or 1
		if Kit.Platform() == "Touch" then m += (1 - m) * 0.45 end
		local k = Kit.ScaleFactor(abs) * m
		scale.Scale = k
		canvas.Size = UDim2.fromOffset(math.max(abs.X, 1) / k, math.max(abs.Y, 1) / k)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
	task.delay(1, fit)
	-- (one shared ViewportSize hook refits every live screen; a screen leaves the list when its gui goes - every warp,
	-- hatch and map open used to add a camera connection and a list entry for good)
	screens[gui] = fit
	gui.Destroying:Connect(function() screens[gui] = nil end)
	if not viewportHooked then
		viewportHooked = true
		local cam = Workspace.CurrentCamera
		if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() Kit.Refit() end) end
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, canvas, scale
end

function Kit.Refit()
	for _, fit in pairs(screens) do fit() end
end

--------------------------------------------------------------------------------
-- text
--------------------------------------------------------------------------------
-- props: Size, Position, AnchorPoint, Color, Color2 (gradient for big titles), Stroke (0 = none),
--        StrokeColor, Shadow (px), Align, ZIndex, Name, MaxSize, Rotation
function Kit.Text(parent: Instance, text: string, props)
	props = props or {}
	local z = props.ZIndex or 5
	local box = new("Frame", {
		Name = props.Name or "Text", BackgroundTransparency = 1, Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = z, Rotation = props.Rotation or 0,
	})
	local function label(name: string, offset: number, zi: number)
		local l = new("TextLabel", {
			Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(offset, offset),
			FontFace = props.Pixel and Theme.Pixel or Theme.Display, TextScaled = true, Text = text, TextXAlignment = props.Align or Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center, ZIndex = zi,
		}, box)
		new("UITextSizeConstraint", { MaxTextSize = props.MaxSize or 64, MinTextSize = 6 }, l)
		return l
	end
	local sh = props.Shadow == nil and 2 or props.Shadow
	if sh > 0 then
		local s = label("Shadow", sh, z)
		s.TextColor3 = C.Shadow
		s.TextTransparency = 0
		new("UIStroke", { Thickness = (props.Stroke == nil and 3 or props.Stroke), Color = C.Shadow, LineJoinMode = props.Pixel and Enum.LineJoinMode.Miter or Enum.LineJoinMode.Round }, s)
	end
	local main = label("Main", 0, z + 1)
	local top = props.Color or Color3.new(1, 1, 1)
	local strokeT = props.Stroke == nil and 3 or props.Stroke
	if strokeT > 0 then new("UIStroke", { Thickness = strokeT, Color = props.StrokeColor or C.Ink, LineJoinMode = props.Pixel and Enum.LineJoinMode.Miter or Enum.LineJoinMode.Round }, main) end
	if props.Color2 then
		main.TextColor3 = Color3.new(1, 1, 1)
		new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.55, top), ColorSequenceKeypoint.new(1, props.Color2),
		}) }, main)
	else
		main.TextColor3 = top
	end
	box.Parent = parent
	return box
end

function Kit.SetText(box: Instance, text: string)
	for _, l in ipairs(box:GetChildren()) do
		if l:IsA("TextLabel") then l.Text = text end
	end
end

function Kit.SetTextColor(box: Instance, top: Color3, bottom: Color3?)
	local main = box:FindFirstChild("Main") :: TextLabel?
	if not main then return end
	local g = main:FindFirstChild("Fill") :: UIGradient?
	if g then
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.55, top), ColorSequenceKeypoint.new(1, bottom or shade(top, 0.78)),
		})
	else
		main.TextColor3 = top
	end
end

--------------------------------------------------------------------------------
-- decoration: studs, stud pattern, stripes, shine
--------------------------------------------------------------------------------
function Kit.Studs(host: GuiObject, color: Color3, opts)
	opts = opts or {}
	local row = new("Frame", { Name = "Studs", BackgroundTransparency = 1, Size = UDim2.new(1, -(opts.Inset or 24), 0, 9), Position = UDim2.new(0.5, 0, 0, -6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = host.ZIndex }, host)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, opts.Gap or 12) }, row)
	for k = 1, (opts.Count or 4) do
		local st = new("Frame", { Name = "Stud", BackgroundColor3 = shade(color, 1.18), Size = UDim2.fromOffset(opts.W or 20, 9), LayoutOrder = k, ZIndex = host.ZIndex }, row)
		corner(st, 4)
		stroke(st, C.Ink, 2.5)
		gradient(st, shade(color, 1.3), shade(color, 0.95))
	end
	return row
end

function Kit.StudPattern(host: GuiObject, color: Color3, rows: number?)
	local layer = new("Frame", { Name = "StudPattern", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, -10), Position = UDim2.fromOffset(12, 5), ClipsDescendants = true, ZIndex = host.ZIndex }, host)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(16, 16), CellPadding = UDim2.fromOffset(14, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }, layer)
	for _ = 1, (rows or 2) * 30 do
		local st = new("Frame", { BackgroundColor3 = shade(color, 1.1), Size = UDim2.fromOffset(16, 16), ZIndex = host.ZIndex }, layer)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, st)
		stroke(st, shade(color, 0.86), 2)
	end
	return layer
end

function Kit.Stripes(host: GuiObject, opts)
	-- two diagonal sheen bands on the right third (the reference buttons' highlight). A CanvasGroup is the only
	-- container that clips ROTATED children, so the bands stay inside the button's rounded shape.
	opts = opts or {}
	local layer = new("CanvasGroup", { Name = "Stripes", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = host.ZIndex, GroupTransparency = 0 }, host)
	corner(layer, opts.Radius or 10)
	local t = opts.T or 0.82
	for _, b in ipairs({ { 0.66, 18, t }, { 0.8, 7, math.min(1, t + 0.06) } }) do
		new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = b[3], BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, b[2], 3, 0), Position = UDim2.fromScale(b[1], 0.5), Rotation = 24, ZIndex = host.ZIndex,
		}, layer)
	end
	return layer
end

function Kit.Shine(host: GuiObject, every: number?)
	local clip = new("CanvasGroup", { Name = "Shine", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = host.ZIndex + 1 }, host)
	corner(clip, 14)
	local bar = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0.3, 0, 2.5, 0), Position = UDim2.new(-0.6, 0, -0.75, 0), Rotation = 22, ZIndex = host.ZIndex + 1 }, clip)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) }) }, bar)
	task.spawn(function()
		task.wait(math.random() * 2)
		while clip.Parent do
			bar.Position = UDim2.new(-0.6, 0, -0.75, 0)
			tween(bar, 0.6, { Position = UDim2.new(1.3, 0, -0.75, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			task.wait(every or 3.6)
		end
	end)
	return clip
end

--------------------------------------------------------------------------------
-- bricks
--------------------------------------------------------------------------------
-- props: Size, Position, AnchorPoint, Color (swatch name / Color3 / table), ZIndex, Lip, Radius, Round,
--        StrokeT, Studs (n), Stripes, Gloss, ShadowT, Name.   returns outer, content
function Kit.Brick(parent: Instance, props)
	props = props or {}
	local sw = swatch(props.Color or "Panel")
	local z = props.ZIndex or 2
	local lip = props.Lip or 4
	local r = props.Radius or 12
	local st = props.StrokeT or 3.5
	local function round(f: Instance)
		if props.Round then new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f) else corner(f, r) end
	end
	local outer = new("Frame", {
		Name = props.Name or "Brick", BackgroundTransparency = 1, Size = props.Size or UDim2.fromOffset(200, 80),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = z,
	})
	local shadow = new("Frame", { Name = "Shadow", BackgroundColor3 = C.Shadow, BackgroundTransparency = props.ShadowT or 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, lip + 3), ZIndex = z }, outer)
	round(shadow)
	local side = new("Frame", { Name = "Lip", BackgroundColor3 = sw[3], Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, lip), ZIndex = z }, outer)
	round(side)
	stroke(side, C.Ink, st)
	local face = new("Frame", { Name = "Body", BackgroundColor3 = sw[1], Size = UDim2.fromScale(1, 1), ZIndex = z }, outer)
	round(face)
	stroke(face, C.Ink, st)
	-- two-tone fill: lighter top half, a crisp step to the base colour (toy-tile gloss, no airbrushing)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, shade(sw[1], 1.16)), ColorSequenceKeypoint.new(0.48, shade(sw[1], 1.1)),
		ColorSequenceKeypoint.new(0.52, sw[1]), ColorSequenceKeypoint.new(1, shade(sw[1], 0.94)),
	}) }, face)
	if props.Gloss == true then
		local gloss = new("Frame", { Name = "Bevel", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5, Size = UDim2.new(1, -2 * math.max(r, 12), 0, 4), Position = UDim2.new(0, math.max(r, 12), 0, 4), ZIndex = z }, face)
		corner(gloss, 2)
	end
	if props.Inner ~= false then
		-- the white inner border that makes every piece look like a glossy toy tile
		local inner = new("Frame", { Name = "InnerBorder", BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = z }, face)
		if props.Round then new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, inner) else corner(inner, math.max(3, r - 3)) end
		local ist = stroke(inner, Color3.new(1, 1, 1), 2)
		ist.Transparency = props.InnerT or 0.35
	end
	if props.Stripes then Kit.Stripes(face, { Radius = r, T = typeof(props.Stripes) == "number" and props.Stripes or 0.88, W = 14 }) end
	if props.Studs and props.Studs > 0 then Kit.Studs(face, sw[1], { Count = props.Studs }) end
	local content = new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 1 }, face)
	outer.Parent = parent
	return outer, content
end
Kit.Panel = Kit.Brick

function Kit.SetPanelColor(outer: Instance, color: any)
	local sw = swatch(color)
	local lip = outer:FindFirstChild("Lip") :: Frame?
	local body = outer:FindFirstChild("Body") :: Frame?
	if lip then lip.BackgroundColor3 = sw[3] end
	if body then
		body.BackgroundColor3 = sw[1]
		local g = body:FindFirstChildOfClass("UIGradient")
		if g then g.Color = ColorSequence.new(shade(sw[1], 1.08), shade(sw[1], 0.95)) end
	end
end

-- a raised green card (sits on dark windows): lighter inner border, optional rarity-colored border
function Kit.Card(parent: Instance, props)
	props = props or {}
	props.Color = props.Color or "Card"
	props.Inner = false
	props.Lip = props.Lip or 5
	props.Radius = props.Radius or 12
	props.StrokeT = props.StrokeT or 3
	props.Gloss = false
	props.ShadowT = props.ShadowT or 0.5
	local outer, content = Kit.Brick(parent, props)
	local body = outer:FindFirstChild("Body") :: Frame
	local inner = new("Frame", { Name = "InnerBorder", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), ZIndex = body.ZIndex }, body)
	corner(inner, math.max(4, (props.Radius or 12) - 4))
	stroke(inner, props.Border or C.JungleHi, props.Border and 3 or 2, Enum.ApplyStrokeMode.Border).Transparency = props.Border and 0 or 0.3
	return outer, content
end

-- a window: a jungle-green panel tiled with rounded squares, a thick outline and a lighter inner border; a title
-- strip across the top (gradient + square pattern) with a huge outlined title; a red close tile.
-- props.Color picks the title strip's gradient. returns root, content (the area under the strip), header
local STRIP = {
	Yellow = { Color3.fromHex("FFE36B"), Color3.fromHex("FF9F2E") }, Lime = { Color3.fromHex("C8F55A"), Color3.fromHex("38B24A") },
	Green = { Color3.fromHex("C8F55A"), Color3.fromHex("38B24A") }, Teal = { Color3.fromHex("7DF2D9"), Color3.fromHex("1F9FC4") },
	Blue = { Color3.fromHex("8CD3FF"), Color3.fromHex("2E6BE6") }, Orange = { Color3.fromHex("FFC266"), Color3.fromHex("F2551F") },
	Red = { Color3.fromHex("FF8C7A"), Color3.fromHex("D62B3A") }, Purple = { Color3.fromHex("D9A6FF"), Color3.fromHex("7A3DE0") },
	Slate = { Color3.fromHex("9FE07A"), Color3.fromHex("2E8A57") },
}
function Kit.Pattern(host: GuiObject, color: Color3, cell: number?, alpha: number?, hint: Vector2?)
	local layer = new("Frame", { Name = "Pattern", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), ClipsDescendants = true, ZIndex = host.ZIndex }, host)
	local c = cell or 30
	new("UIGridLayout", { CellSize = UDim2.fromOffset(c - 8, c - 8), CellPadding = UDim2.fromOffset(8, 8), StartCorner = Enum.StartCorner.TopLeft }, layer)
	local size = hint or (host.AbsoluteSize.X > 0 and host.AbsoluteSize) or Vector2.new(800, 520)
	local n = math.ceil(size.X / c + 1) * math.ceil(size.Y / c + 1)
	for _ = 1, math.min(n, 520) do
		local sq = new("Frame", { BackgroundColor3 = color, BackgroundTransparency = alpha or 0.82, BorderSizePixel = 0, ZIndex = host.ZIndex }, layer)
		corner(sq, 5)
	end
	return layer
end

-- a holder that scales its window down so it always fits on screen (parent = a Kit.Screen canvas)
local function fitHolder(parent: Instance, size: UDim2, pos: UDim2?, anchor: Vector2?): Frame
	local w, h = size.X.Offset, size.Y.Offset + 30 -- the title strip pokes above the window
	local holder = new("Frame", { Name = "FitHolder", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), Position = pos or UDim2.fromScale(0.5, 0.5), AnchorPoint = anchor or Vector2.new(0.5, 0.5) }, parent)
	local sc = new("UIScale", { Name = "FitScale" }, holder)
	local function fit()
		local p = parent :: any
		local avail = p:IsA("GuiObject") and Vector2.new(p.Size.X.Offset, p.Size.Y.Offset) or Vector2.new(960, 560)
		if avail.X < 10 or avail.Y < 10 then avail = Vector2.new(960, 560) end
		-- desktop windows leave the world visible around them (touch screens are small, they keep the room)
		local hMax = Kit.Platform() == "Touch" and 0.9 or 0.84
		sc.Scale = math.min(1, avail.X * 0.96 / w, avail.Y * hMax / h)
	end
	-- (dropped with the window: the canvas outlives every panel, and each open used to leave a live closure on it)
	if parent:IsA("GuiObject") then
		local conn = (parent :: GuiObject):GetPropertyChangedSignal("Size"):Connect(fit)
		holder.Destroying:Connect(function() conn:Disconnect() end)
	end
	fit()
	task.defer(fit)
	return holder
end

function Kit.Window(parent: Instance, props)
	local z = props.ZIndex or 20
	local holder = nil
	if props.Fit and props.Size then
		holder = fitHolder(parent, props.Size, props.Position, props.AnchorPoint)
		parent = holder
		props.Position = UDim2.new(0.5, 0, 1, 0)
		props.AnchorPoint = Vector2.new(0.5, 1)
	end
	local stripCol = STRIP[props.Color or "Yellow"] or STRIP.Yellow
	local root, body = Kit.Brick(parent, { Name = props.Name or "Window", Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, Color = "Jungle", ZIndex = z, Radius = 18, Lip = 8, Gloss = false, StrokeT = 4, ShadowT = 0.35, InnerT = 0.6 })
	local face = root:FindFirstChild("Body") :: Frame
	gradient(face, C.JungleHi, C.Jungle)
	local sz = props.Size and Vector2.new(props.Size.X.Offset, props.Size.Y.Offset) or Vector2.new(800, 520)
	Kit.Pattern(face, C.LimeHi, 40, 0.86, sz)
	-- title strip: full width, sits on the top edge
	local header = new("Frame", { Name = "Header", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 24, 0, 70), Position = UDim2.new(0, -12, 0, -18), ZIndex = z + 4 }, body)
	corner(header, 14)
	stroke(header, C.Ink, 4)
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(stripCol[1], stripCol[2]) }, header)
	Kit.Pattern(header, Color3.new(1, 1, 1), 30, 0.78, Vector2.new(sz.X + 24, 70))
	local shine = new("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, BorderSizePixel = 0, Size = UDim2.new(1, -24, 0, 5), Position = UDim2.fromOffset(12, 6), ZIndex = z + 5 }, header)
	corner(shine, 3)
	local left = 26
	if props.Icon then
		Icons.Make(props.Icon, { Size = UDim2.fromOffset(92, 92), Position = UDim2.new(0, 4, 0.5, -4), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 7, Parent = header, Rotation = -6 })
		left = 100
	end
	Kit.Text(header, props.Title or "", { Name = "Title", Size = UDim2.new(1, -left - 90, 0, 44), Position = UDim2.new(0, left, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = z + 7, Stroke = 4.5, Shadow = 4, MaxSize = 48 })
	if props.OnClose then
		Kit.Button(header, { Name = "Close", Glyph = "X", Color = "Red", Size = UDim2.fromOffset(56, 54), Position = UDim2.new(1, -12, 0.5, -2), AnchorPoint = Vector2.new(1, 0.5), ZIndex = z + 9, Radius = 14, Lip = 5, OnClick = props.OnClose })
	end
	local content = new("Frame", { Name = "Inner", BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, -90), Position = UDim2.fromOffset(20, 74), ZIndex = z + 1 }, body)
	if holder then
		local hh = holder :: Frame
		root.AncestryChanged:Connect(function() if not root.Parent then hh:Destroy() end end)
	end
	return root, content, header
end

-- slanted ribbon title (a few cinematic cards)
function Kit.Ribbon(parent: Instance, text: string, props)
	props = props or {}
	local sw = swatch(props.Color or "Yellow")
	local w = props.Width or (#text * 22 + 90)
	local z = props.ZIndex or 10
	local holder = new("Frame", { Name = "Ribbon", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, 52), Position = props.Position or UDim2.fromOffset(-14, -30), ZIndex = z }, parent)
	local face, content = Kit.Brick(holder, { Size = UDim2.new(1, 0, 0, 46), Color = sw, ZIndex = z + 1, Lip = 5, Radius = 12, Studs = props.Studs or math.max(2, math.floor(w / 60)) })
	face.Rotation = props.Tilt or -2
	if props.Icon then
		Icons.Make(props.Icon, { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 2, 0.5, -2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 4, Parent = content })
	end
	Kit.Text(content, text, { Size = UDim2.new(1, props.Icon and -66 or -30, 0, 22), Position = UDim2.new(0, props.Icon and 56 or 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = z + 4, Stroke = 3 })
	return holder
end

--------------------------------------------------------------------------------
-- icons + glyphs
--------------------------------------------------------------------------------
function Kit.Icon(parent: Instance, name: string, props)
	props = props or {}
	if name:sub(1, 6) == "Glyph:" then return Kit.Glyph(parent, name:sub(7), props) end
	if name == "Close" then return Kit.Glyph(parent, "X", props) end
	if name == "Arrow" then return Kit.Glyph(parent, "Chevron", props) end
	return Icons.Make(name, {
		Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex, Rotation = props.Rotation,
		Species = props.Species, Vehicle = props.Vehicle, Silhouette = props.Silhouette, Parent = parent,
	})
end

function Kit.Glyph(parent: Instance, kind: string, props)
	props = props or {}
	local holder = new("Frame", { Name = "Glyph_" .. kind, BackgroundTransparency = 1, Size = props.Size or UDim2.fromOffset(28, 28), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 7 }, parent)
	new("UIAspectRatioConstraint", {}, holder)
	local col = props.Color or Color3.new(1, 1, 1)
	local bars = {}
	if kind == "X" then bars = { { 0.95, 45, 0.5, 0.5 }, { 0.95, -45, 0.5, 0.5 } }
	elseif kind == "Chevron" then bars = { { 0.62, 45, 0.5, 0.32 }, { 0.62, -45, 0.5, 0.68 } }
	elseif kind == "Check" then bars = { { 0.42, 45, 0.3, 0.62 }, { 0.8, -50, 0.62, 0.48 } }
	elseif kind == "Plus" then bars = { { 0.86, 0, 0.5, 0.5 }, { 0.86, 90, 0.5, 0.5 } }
	elseif kind == "Minus" then bars = { { 0.86, 0, 0.5, 0.5 } } end
	-- pass 1: a slightly bigger ink silhouette; pass 2: the colour on top (no per-bar strokes crossing)
	for pass = 1, 2 do
		local thick = pass == 1 and 0.34 or 0.2
		for _, b in ipairs(bars) do
			local f = new("Frame", {
				Name = pass == 1 and "Ink" or "Fill", BackgroundColor3 = pass == 1 and C.Ink or col, BorderSizePixel = 0,
				Size = UDim2.new(b[1] + (pass == 1 and 0.14 or 0), 0, thick, 0), Position = UDim2.fromScale(b[3], b[4]),
				AnchorPoint = Vector2.new(0.5, 0.5), Rotation = b[2], ZIndex = holder.ZIndex + (pass - 1),
			}, holder)
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		end
	end
	return holder
end

--------------------------------------------------------------------------------
-- motion
--------------------------------------------------------------------------------
local function uiScale(inst: GuiObject): UIScale
	local s = inst:FindFirstChild("PopScale") :: UIScale?
	if not s then s = new("UIScale", { Name = "PopScale" }, inst) :: UIScale end
	return s :: UIScale
end
Kit.UIScale = uiScale

function Kit.Pop(inst: GuiObject, from: number?, delay: number?)
	local s = uiScale(inst)
	s.Scale = from or 0.4
	inst.Visible = true
	TweenService:Create(s, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay or 0), { Scale = 1 }):Play()
end

function Kit.Enter(inst: GuiObject)
	Kit.Sound("Open")
	local s = uiScale(inst)
	-- no tilt: Roblox turns ClipsDescendants off on anything rotated, so the window's clipped square pattern
	-- would spill out past its edges for the length of the tween
	local basePos = inst.Position
	s.Scale = 0.6
	inst.Position = basePos + UDim2.fromOffset(0, 40)
	inst.Visible = true
	TweenService:Create(s, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(inst, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = basePos }):Play()
end

function Kit.Exit(inst: GuiObject, destroy: boolean?)
	Kit.Sound("Close")
	local s = uiScale(inst)
	local tw = TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.5 })
	tw.Completed:Connect(function() if destroy then inst:Destroy() else inst.Visible = false s.Scale = 1 end end)
	tw:Play()
end

function Kit.PopOut(inst: GuiObject, destroy: boolean?)
	local s = uiScale(inst)
	local tw = TweenService:Create(s, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.2 })
	tw.Completed:Connect(function() if destroy then inst:Destroy() else inst.Visible = false s.Scale = 1 end end)
	tw:Play()
end

function Kit.Stagger(list: { GuiObject }, gap: number?, from: number?)
	for i, g in ipairs(list) do Kit.Pop(g, from or 0.3, (i - 1) * (gap or 0.045)) end
end

function Kit.Punch(inst: GuiObject, amount: number?)
	local s = uiScale(inst)
	s.Scale = 1 + (amount or 0.18)
	TweenService:Create(s, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function Kit.Shake(inst: GuiObject)
	local base = inst.Position
	task.spawn(function()
		for i = 1, 7 do
			inst.Position = base + UDim2.fromOffset((i % 2 == 0 and 1 or -1) * (9 - i), 0)
			task.wait(0.03)
		end
		inst.Position = base
	end)
end

function Kit.Bob(inst: GuiObject, amp: number?, speed: number?)
	local base = inst.Position
	task.spawn(function()
		local t0 = os.clock() + math.random()
		while inst.Parent do
			inst.Position = base + UDim2.fromOffset(0, math.sin((os.clock() - t0) * (speed or 2.2)) * (amp or 3))
			task.wait()
		end
	end)
end

function Kit.Count(box: Instance, from: number, to: number, fmt, duration: number?)
	local key = tostring({})
	box:SetAttribute("CountToken", key)
	local d = duration or 0.5
	task.spawn(function()
		local t0 = os.clock()
		while true do
			if box:GetAttribute("CountToken") ~= key then return end
			local a = math.clamp((os.clock() - t0) / d, 0, 1)
			local e = 1 - (1 - a) ^ 3
			Kit.SetText(box, fmt(from + (to - from) * e))
			if a >= 1 then break end
			task.wait()
		end
	end)
end

--------------------------------------------------------------------------------
-- sounds: the UI's clicks, pops and windows. SoundFx plugs the game's real sounds in (Audio slots: Click, Talk,
-- Toast, Open, Close, Error, Confirm); nothing plays until it has
--------------------------------------------------------------------------------
Kit.SoundHook = nil :: ((string, number?, number?) -> boolean)?
function Kit.Sound(name: string, volume: number?, pitch: number?)
	if Kit.SoundHook then Kit.SoundHook(name, volume, pitch) end
end

--------------------------------------------------------------------------------
-- buttons
--------------------------------------------------------------------------------
-- props: Text, Icon, IconSize, Glyph, Color, Size, Position, AnchorPoint, OnClick, Stack, Studs, Shine,
--        TextSize (0..1 of height), TextLeft, TextColor, MaxText, LabelPx, Round, Radius, Lip, Name,
--        ZIndex, Badge, Disabled, Species, Vehicle
function Kit.Button(parent: Instance, props)
	local z = props.ZIndex or 3
	local lip = props.Lip or 4
	local outer, content = Kit.Brick(parent, { Name = props.Name or "Button", Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, Color = props.Color or "Lime", ZIndex = z, Lip = lip, Radius = props.Radius or 14, Studs = props.Studs, Round = props.Round, Stripes = props.Stripes == nil and 0.8 or props.Stripes })
	local face = outer:FindFirstChild("Body") :: Frame
	local hit = new("TextButton", { Name = "Hit", BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, lip), ZIndex = z + 8, AutoButtonColor = false, Selectable = true }, outer)
	local sel = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromOffset(-4, -4) })
	stroke(sel, C.YellowHi, 4)
	corner(sel, 16)
	hit.SelectionImageObject = sel
	if props.Shine then Kit.Shine(face) end
	local iconInst
	local hasText = props.Text and props.Text ~= ""
	if props.Icon then
		local isz = props.IconSize or 0.78
		if props.IconOut then
			iconInst = Kit.Icon(content, props.Icon, { Size = UDim2.fromScale(isz, isz), Position = UDim2.new(0, -14, 0.5, -2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 6, Rotation = -8, Species = props.Species, Vehicle = props.Vehicle })
		elseif hasText and not props.Stack then
			iconInst = Kit.Icon(content, props.Icon, { Size = UDim2.fromScale(isz, isz), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 3, Species = props.Species, Vehicle = props.Vehicle })
		else
			iconInst = Kit.Icon(content, props.Icon, { Size = UDim2.fromScale(isz, isz), Position = UDim2.fromScale(0.5, props.Stack and 0.4 or 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 3, Species = props.Species, Vehicle = props.Vehicle })
		end
	elseif props.Glyph then
		iconInst = Kit.Glyph(content, props.Glyph, { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 3 })
	end
	local label
	if hasText then
		if props.Stack then
			label = Kit.Text(content, props.Text, { Size = UDim2.new(0.92, 0, 0, props.LabelPx or 10), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 3, Stroke = 2.5, MaxSize = 14, Color = props.TextColor, Pixel = true })
		else
			local left = props.Icon and (props.TextLeft or 0.34) or 0.06
			label = Kit.Text(content, props.Text, { Size = UDim2.new(1 - left - 0.06, 0, props.TextSize or 0.56, 0), Position = UDim2.new(left, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 3, Stroke = 3.5, Shadow = 3, Color = props.TextColor, Align = props.Icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, MaxSize = props.MaxText or 40 })
		end
	end
	if props.Badge then Kit.Badge(outer, props.Badge) end
	local s = uiScale(outer)
	local basePos = face.Position
	local down = false
	local function setPressed(p: boolean)
		tween(face, p and 0.05 or 0.25, { Position = p and UDim2.fromOffset(0, lip - 1) or basePos }, p and Enum.EasingStyle.Quad or Enum.EasingStyle.Back)
	end
	hit.MouseEnter:Connect(function()
		if down then return end
		tween(s, 0.14, { Scale = 1.05 }, Enum.EasingStyle.Back)
		tween(face, 0.14, { Position = basePos - UDim2.fromOffset(0, 2) })
	end)
	hit.MouseLeave:Connect(function()
		down = false
		tween(s, 0.16, { Scale = 1 })
		setPressed(false)
	end)
	hit.MouseButton1Down:Connect(function() down = true setPressed(true) tween(s, 0.06, { Scale = 0.95 }) end)
	hit.MouseButton1Up:Connect(function() down = false setPressed(false) tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) end)
	hit.SelectionGained:Connect(function() tween(s, 0.14, { Scale = 1.05 }, Enum.EasingStyle.Back) end)
	hit.SelectionLost:Connect(function() tween(s, 0.14, { Scale = 1 }) end)
	hit.Activated:Connect(function()
		if props.Disabled then Kit.Shake(outer) Kit.Sound("Click", 0.3, 0.7) return end
		Kit.Sound("Click", 0.45)
		Kit.Punch(outer, 0.07)
		if props.OnClick then task.spawn(props.OnClick) end
	end)
	return outer, hit, label
end

function Kit.Pill(parent: Instance, amount: string, props)
	props = props or {}
	local z = props.ZIndex or 6
	local color = props.Color or C.Lime
	local pill = new("Frame", { Name = "Pill", BackgroundColor3 = color, Size = props.Size or UDim2.fromOffset(130, 34), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = z }, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pill)
	stroke(pill, C.Ink, 3)
	gradient(pill, shade(color, 1.12), shade(color, 0.9))
	Kit.Icon(pill, props.Icon or "Coin", { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, -10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 2 })
	Kit.Text(pill, amount, { Name = "Amount", Size = UDim2.new(1, -44, 0.5, 0), Position = UDim2.new(0, 34, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 2, Stroke = 2.5 })
	return pill
end

function Kit.Badge(host: GuiObject, n: any)
	local b = host:FindFirstChild("Badge") :: Frame?
	if not b then
		local nb = new("Frame", { Name = "Badge", BackgroundColor3 = C.Red, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -8, 0, -8), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = host.ZIndex + 12 }, host) :: Frame
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, nb)
		stroke(nb, C.Ink, 3)
		Kit.Text(nb, "", { Name = "Count", Size = UDim2.fromScale(0.62, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = host.ZIndex + 13, Stroke = 1.5 })
		task.spawn(function()
			while nb.Parent do
				if nb.Visible then Kit.Punch(nb, 0.2) end
				task.wait(1.6)
			end
		end)
		b = nb
	end
	local bb = b :: Frame
	local count = bb:FindFirstChild("Count")
	if count then Kit.SetText(count, tostring(n or "")) end
	bb.Visible = n ~= nil and n ~= 0 and n ~= ""
	return bb
end

function Kit.Segments(parent: Instance, n: number, props)
	props = props or {}
	local z = props.ZIndex or 6
	local track = new("Frame", { Name = "Segments", BackgroundColor3 = C.Ink, Size = props.Size or UDim2.fromOffset(200, 16), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = z }, parent)
	corner(track, 6)
	stroke(track, C.Ink, 2)
	local segs = {}
	for i = 1, n do
		local f = new("Frame", { BackgroundColor3 = C.InkSoft, Size = UDim2.new(1 / n, -3, 1, -4), Position = UDim2.new((i - 1) / n, 2, 0, 2), ZIndex = z + 1 }, track)
		corner(f, 3)
		segs[i] = f
	end
	return function(v: number, color: Color3?)
		local lit = math.clamp(math.ceil(v * n - 0.001), 0, n)
		for i, f in ipairs(segs) do
			local on = i <= lit
			local c = on and (color or C.Lime) or C.InkSoft
			f.BackgroundColor3 = c
			local g = f:FindFirstChildOfClass("UIGradient")
			if on then
				if not g then g = new("UIGradient", { Rotation = 90 }, f) end
				g.Color = ColorSequence.new(shade(c, 1.25), shade(c, 0.88))
			elseif g then g:Destroy() end
		end
	end, track
end

--------------------------------------------------------------------------------
-- coins flying into the counter
--------------------------------------------------------------------------------
local flyGui
function Kit.FlyCoins(fromScreen: Vector2, toGui: GuiObject, n: number?)
	if not flyGui then flyGui = Kit.Screen("DinoFly", 45, true) end
	local root = flyGui:FindFirstChild("Root") :: Frame
	local target = toGui.AbsolutePosition + toGui.AbsoluteSize / 2
	for i = 1, (n or 8) do
		task.delay(i * 0.04, function()
			local coin = new("Frame", { BackgroundColor3 = C.Gold, Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(fromScreen.X, fromScreen.Y), ZIndex = 50 }, root)
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, coin)
			stroke(coin, C.Ink, 3)
			local inner = new("Frame", { BackgroundColor3 = C.YellowHi, Size = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 51 }, coin)
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, inner)
			local mid = fromScreen + Vector2.new((math.random() - 0.5) * 220, -80 - math.random() * 120)
			local t0 = os.clock()
			local dur = 0.55 + math.random() * 0.2
			task.spawn(function()
				while true do
					local u = math.clamp((os.clock() - t0) / dur, 0, 1)
					local a = fromScreen:Lerp(mid, u)
					local b = mid:Lerp(target, u * u)
					local p = a:Lerp(b, u)
					coin.Position = UDim2.fromOffset(p.X, p.Y)
					coin.Size = UDim2.fromOffset(26 - u * 8, 26 - u * 8)
					if u >= 1 then break end
					task.wait()
				end
				coin:Destroy()
				Kit.Punch(toGui, 0.08)
			end)
		end)
	end
end

--------------------------------------------------------------------------------
-- toasts: white cards with a colored icon bubble, sliding in from the top
--------------------------------------------------------------------------------
local toastGui, toastCanvas
local toasts = {}
local TOAST = { Green = "Lime", Red = "Red", Orange = "Orange", Blue = "Blue", Gold = "Yellow", Purple = "Purple", Teal = "Teal", Grey = "Grey" }

local function layoutToasts()
	for i, t in ipairs(toasts) do
		tween(t, 0.3, { Position = UDim2.new(0.5, 0, 0.66, -(i - 1) * 50) }, Enum.EasingStyle.Back)
	end
end

function Kit.Toast(text: string, color: any?, icon: string?)
	if not toastGui then toastGui, toastCanvas = Kit.Screen("DinoToasts", 30, false, 0.72) end
	Kit.Sound(color == "Red" and "Error" or "Toast")
	local sw = swatch((typeof(color) == "string" and TOAST[color]) or color or "Lime")
	-- a big outlined line of text with its icon, floating over the world like the reference HUD's callouts
	local w = math.clamp(#text * 15 + 90, 220, 760)
	local outer = new("Frame", { Name = "Toast", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, 46), Position = UDim2.new(0.5, 0, 0.66, 30), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 40 }, toastCanvas)
	if icon then Kit.Icon(outer, icon, { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 43, Rotation = -6 }) end
	Kit.Text(outer, text, { Size = UDim2.new(1, icon and -58 or 0, 0, 30), Position = UDim2.new(0, icon and 58 or 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, ZIndex = 44, Color = Color3.new(1, 1, 1):Lerp(sw[2], 0.25), Stroke = 3.5, Shadow = 3, MaxSize = 30 })
	table.insert(toasts, 1, outer)
	if #toasts > 4 then local old = table.remove(toasts) Kit.PopOut(old, true) end
	Kit.Pop(outer, 0.5)
	layoutToasts()
	task.delay(2.8, function()
		local i = table.find(toasts, outer)
		if i then table.remove(toasts, i) end
		if outer.Parent then Kit.Exit(outer, true) end
		layoutToasts()
	end)
end

--------------------------------------------------------------------------------
-- HUD pieces in the reference style
--------------------------------------------------------------------------------
-- square tile: big image filling it, label strip along the bottom (DRIVE / GHOSTS style). returns outer, hit
function Kit.Tile(parent: Instance, props)
	local z = props.ZIndex or 4
	local size = props.Size or UDim2.fromOffset(96, 96)
	local outer, hit = Kit.Button(parent, { Name = props.Name or "Tile", Color = props.Color or "Orange", Size = size, Position = props.Position, AnchorPoint = props.AnchorPoint, ZIndex = z, Radius = props.Radius or 16, Lip = 5, OnClick = props.OnClick })
	local face = outer:FindFirstChild("Body") :: Frame
	local content = face:FindFirstChild("Content") :: Frame
	Kit.Icon(content, props.Icon or "Star", { Size = UDim2.fromScale(props.IconSize or 0.86, props.IconSize or 0.86), Position = UDim2.fromScale(0.5, props.Label and 0.4 or 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 4, Species = props.Species, Vehicle = props.Vehicle })
	if props.Label then
		Kit.Text(content, props.Label, { Name = "Label", Size = UDim2.new(0.94, 0, 0, props.LabelPx or 15), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 6, Stroke = 3, Shadow = 2, MaxSize = 20 })
	end
	if props.Badge then Kit.Badge(outer, props.Badge) end
	return outer, hit
end

-- a tilted nav tab with diagonal sheen stripes (top-centre GEAR / BASE / SELL style). returns outer, hit
function Kit.NavTab(parent: Instance, props)
	local outer, hit = Kit.Button(parent, { Name = props.Name or props.Text, Text = props.Text, Color = props.Color or "Blue", Size = props.Size or UDim2.fromOffset(170, 52), Position = props.Position, AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex or 4, Radius = 8, Lip = 4, Stripes = 0.78, MaxText = 36, TextSize = 0.7, OnClick = props.OnClick })
	outer.Rotation = props.Tilt or -3
	return outer, hit
end

-- a floating currency counter: big image, huge outlined number, green + tile, optional sub line
-- returns holder, amountText, subText
function Kit.Money(parent: Instance, props)
	local z = props.ZIndex or 4
	local holder = new("Frame", { Name = props.Name or "Money", BackgroundTransparency = 1, Size = props.Size or UDim2.fromOffset(360, 74), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = z }, parent)
	Kit.Icon(holder, props.Icon or "Coin", { Size = UDim2.fromOffset(86, 86), Position = UDim2.new(0, -6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 2, Rotation = -10 })
	local amount = Kit.Text(holder, props.Text or "0", { Name = "Amount", Size = UDim2.new(1, -150, 0, 46), Position = UDim2.new(0, 86, 0, props.Sub and 0 or 14), Align = Enum.TextXAlignment.Left, ZIndex = z + 2, Color = props.Color or C.Lime, Stroke = 4, Shadow = 4, MaxSize = 50 })
	local plus = nil
	if props.OnPlus then
		plus = Kit.Button(holder, { Name = "Plus", Glyph = "Plus", Color = "Lime", Size = UDim2.fromOffset(46, 44), Position = UDim2.new(1, -4, 0, props.Sub and 2 or 16), AnchorPoint = Vector2.new(1, 0), ZIndex = z + 3, Radius = 10, Lip = 4, OnClick = props.OnPlus })
	end
	if plus then
		local TextService = game:GetService("TextService")
		local main = amount:FindFirstChild("Main") :: TextLabel
		local lastLen = -1
		local function place()
			local t = main.Text
			if #t == lastLen then return end
			lastLen = #t
			task.spawn(function()
				local params = Instance.new("GetTextBoundsParams")
				params.Text = t
				params.Font = Theme.Display
				params.Size = 46
				params.Width = 2000
				local ok, b = pcall(function() return TextService:GetTextBoundsAsync(params) end)
				if ok and plus.Parent then
					plus.AnchorPoint = Vector2.new(0, 0)
					plus.Position = UDim2.new(0, 86 + math.min(b.X, 260) + 12, 0, props.Sub and 2 or 16)
				end
			end)
		end
		main:GetPropertyChangedSignal("Text"):Connect(place)
		place()
	end
	local sub = nil
	if props.Sub then
		sub = Kit.Text(holder, props.Sub, { Name = "Sub", Size = UDim2.new(1, -96, 0, 20), Position = UDim2.new(0, 90, 0, 48), Align = Enum.TextXAlignment.Left, ZIndex = z + 2, Color = C.Cream, Stroke = 3, Shadow = 2, MaxSize = 22 })
	end
	return holder, amount, sub, plus
end

-- a big centre callout: icon + huge outlined title + subtitle (event / section / objective moments)
function Kit.Banner(parent: Instance, props)
	local z = props.ZIndex or 30
	local holder = new("Frame", { Name = "Banner", BackgroundTransparency = 1, Size = props.Size or UDim2.fromOffset(720, 110), Position = props.Position or UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), ZIndex = z }, parent)
	local icon = new("Frame", { Name = "IconHolder", BackgroundTransparency = 1, Size = UDim2.fromOffset(96, 96), Position = UDim2.new(0, 0, 0, 0), ZIndex = z + 1 }, holder)
	local title = Kit.Text(holder, "", { Name = "Title", Size = UDim2.new(1, -110, 0, 64), Position = UDim2.new(0, 104, 0, 4), Align = Enum.TextXAlignment.Left, ZIndex = z + 2, Stroke = 5, Shadow = 5, MaxSize = 70 })
	local sub = Kit.Text(holder, "", { Name = "Sub", Size = UDim2.new(1, -110, 0, 22), Position = UDim2.new(0, 108, 0, 72), Align = Enum.TextXAlignment.Left, ZIndex = z + 2, Stroke = 3, Shadow = 2, MaxSize = 24 })
	holder.Visible = false
	local api = {}
	local token = nil
	function api.Show(t: string, subText: string?, iconName: string?, color: Color3?, hold: number?)
		Kit.SetText(title, t)
		Kit.SetTextColor(title, color or Color3.new(1, 1, 1))
		Kit.SetText(sub, subText or "")
		for _, c in ipairs(icon:GetChildren()) do c:Destroy() end
		local hasIcon = iconName ~= nil
		if hasIcon then Kit.Icon(icon, iconName :: string, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Rotation = -8 }) end
		-- centre the line: measure roughly from the text length
		local w = math.clamp(#t * 34 + (hasIcon and 110 or 0), 300, 900)
		holder.Size = UDim2.fromOffset(w, 110)
		title.Position = UDim2.new(0, hasIcon and 104 or 0, 0, 4)
		title.Size = UDim2.new(1, hasIcon and -110 or 0, 0, 64)
		sub.Position = UDim2.new(0, hasIcon and 108 or 0, 0, 72)
		holder.Visible = true
		Kit.Pop(holder, 1.6)
		local my = {}
		token = my
		task.delay(hold or 2.4, function() if token == my then Kit.PopOut(holder) end end)
	end
	function api.Hide() token = nil holder.Visible = false end
	api.Holder = holder
	return api
end

-- a full-width gradient bar with a pixel-font label (tiers, options, progress steps)
function Kit.TierBar(parent: Instance, text: string, props)
	props = props or {}
	local z = props.ZIndex or 6
	local c1, c2 = props.Color or C.Yellow, props.Color2 or shade(props.Color or C.Yellow, 0.7)
	local bar = new("Frame", { Name = props.Name or "TierBar", BackgroundColor3 = Color3.new(1, 1, 1), Size = props.Size or UDim2.new(1, 0, 0, 34), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0, ZIndex = z }, parent)
	corner(bar, 10)
	stroke(bar, C.Ink, 3)
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(c1, c2) }, bar)
	local hi = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 3), Position = UDim2.fromOffset(8, 4), ZIndex = z }, bar)
	corner(hi, 2)
	Kit.Text(bar, text, { Name = "Label", Size = UDim2.new(1, -24, 0, props.TextPx or 12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 2, Pixel = true, Stroke = 2.5, Shadow = 2, MaxSize = 16, Align = props.Align })
	return bar
end

return Kit
