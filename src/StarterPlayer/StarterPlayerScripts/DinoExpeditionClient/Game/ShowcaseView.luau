--[[
	ShowcaseView — the SHOWCASE pedestal on every island (server: Showcase.luau; model: islandKit.js Showcase, placed
	at each plot's ShowcaseAnchor by IslandView).

	  every island   the owner's star stands on the turning platform (the plot attribute "Showcase": the dino's
	                 record as JSON, "" = empty), dressed in its rarity, idling, sized to fit the platform; the glow
	                 bands and spotlight lenses take its rarity's colour; its name card floats over it. A sea species
	                 swims in a glass tank on the platform (Config.ShowcaseTank).
	  your island    the pedestal has a prompt: PICK A STAR opens the picker - your dinos, tap one to put it on show
	                 (or take it down). The BAG's SHOWCASE button does the same for one dino.
	Everything here is drawn on each client; the server only keeps which dino it is.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))
local DinosaurAnimations = require(Shared:WaitForChild("DinosaurAnimations"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local CineKit = require(script.Parent.UI.CineKit)
local RarityFx = require(script.Parent.RarityFx)

local player = Players.LocalPlayer
local C = Theme.C
local DinoT = Shared:WaitForChild("Dinosaurs")

local ShowcaseView = {}
local Panels: any = nil

local AMBER = Color3.fromHex("ffb02e")
local WARM = Color3.fromHex("fff1c4")
local FIT_WIDE, FIT_TALL, MIN_WIDE = 8.2, 11, 4.2 -- studs: the platform's top is 9.2 across
local SPIN = 0.35 -- radians / s

--------------------------------------------------------------------------------
-- per island
--------------------------------------------------------------------------------
type Stage = {
	Plot: Model, Kit: Model?, Raw: string, Dino: any?, Model: Model?, Root: BasePart?, Lift: number, Tank: Model?,
	Card: BillboardGui?, Prompt: ProximityPrompt?, Glows: { BasePart }?, Lenses: { BasePart }?, Spin: number, Swim: boolean,
	Spot: BasePart?, Turn: Model?, Base: CFrame?,
}
local stages = {} :: { [Model]: Stage }

local function campPlots(): Instance?
	local camp = Workspace:FindFirstChild("BaseCamp")
	return camp and camp:FindFirstChild("Plots")
end
local function kitOf(plot: Model): Model?
	local folder = plot:FindFirstChild("IslandKit")
	local m = folder and folder:FindFirstChild("Showcase")
	return (m and m:IsA("Model")) and m or nil
end
local function decode(raw: any): any?
	if typeof(raw) ~= "string" or raw == "" then return nil end
	local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and typeof(d) == "table" and typeof(d.Species) == "string" and Config.Species[d.Species] then return d end
	return nil
end
local function own(plot: Model): boolean
	return plot:GetAttribute("Owner") == player.UserId
end

local function prep(m: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

-- the rarity's colour on the glow bands and the lamp lenses (amber when it's empty)
local function tint(st: Stage, color: Color3?)
	local kit = st.Kit
	if not kit then return end
	if not st.Glows then
		local glows, lenses = {}, {}
		for _, d in ipairs(kit:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Name == "ShowcaseGlow" then table.insert(glows, d) elseif d.Name == "SpotLens" then table.insert(lenses, d) end
			end
		end
		st.Glows, st.Lenses = glows, lenses
	end
	for _, g in ipairs(st.Glows or {}) do g.Color = color or AMBER end
	for _, l in ipairs(st.Lenses or {}) do
		l.Color = color and color:Lerp(WARM, 0.45) or WARM
		local spot = l:FindFirstChildOfClass("SpotLight")
		if spot then spot.Color = color and color:Lerp(WARM, 0.55) or Color3.fromRGB(255, 237, 199) end
	end
	for _, g in ipairs(st.Glows or {}) do
		local light = g:FindFirstChildOfClass("PointLight")
		if light then light.Color = color or Color3.fromRGB(255, 204, 115) end
	end
end

local function clearDino(st: Stage)
	if st.Model then st.Model:Destroy() end
	if st.Tank then st.Tank:Destroy() end
	if st.Card then st.Card:Destroy() end
	st.Model, st.Root, st.Tank, st.Card, st.Dino = nil, nil, nil, nil, nil
end

-- the glass tank a sea star swims in
local function tank(spot: BasePart): Model
	local m = Instance.new("Model")
	m.Name = "ShowcaseTank"
	local function cyl(name: string, d: number, h: number, y: number, color: Color3, mat: Enum.Material, t: number)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(h, d, d)
		p.CFrame = CFrame.new(spot.Position + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Color = color
		p.Material = mat
		p.Transparency = t
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = m
		return p
	end
	cyl("TankWater", 8.4, 7.4, 3.75, Color3.fromRGB(70, 170, 220), Enum.Material.Glass, 0.72)
	cyl("TankGlass", 8.8, 7.8, 3.9, Color3.fromRGB(200, 240, 255), Enum.Material.Glass, 0.86)
	cyl("TankRimTop", 9.0, 0.35, 7.9, Color3.fromHex("c87533"), Enum.Material.Metal, 0)
	cyl("TankRimBase", 9.0, 0.35, 0.18, Color3.fromHex("c87533"), Enum.Material.Metal, 0)
	local water = m:FindFirstChild("TankWater") :: BasePart
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 0, 0)
	a.Parent = water
	local e = Instance.new("ParticleEmitter")
	e.Name = "Bubbles"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.05) })
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Speed = NumberRange.new(1.5, 3)
	e.Lifetime = NumberRange.new(1.5, 2.4)
	e.Rate = 6
	e.SpreadAngle = Vector2.new(20, 20)
	e.EmissionDirection = Enum.NormalId.Right -- (the cylinder lies on its side: +X of the part is world up)
	e.Parent = a
	return m
end

-- the name card over the star
local function card(st: Stage, d, height: number)
	local r = Config.Rarity[d.Rarity] or Config.Rarity.Common
	local bb = Instance.new("BillboardGui")
	bb.Name = "ShowcaseCard"
	bb.Size = UDim2.fromOffset(260, 92)
	bb.StudsOffset = Vector3.new(0, height, 0)
	bb.MaxDistance = 110
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Adornee = st.Root
	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromScale(0.5, 0)
	badge.Size = UDim2.fromOffset(130, 22)
	badge.BackgroundColor3 = r.Color
	badge.Parent = bb
	Kit.Corner(badge, 11)
	Kit.Stroke(badge, C.Ink, 2.5)
	local rt = Kit.Text(badge, r.Name, { Size = UDim2.new(1, -10, 0, 12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Pixel = true, Stroke = 2, Shadow = 0, MaxSize = 12 })
	if d.Rarity == "Secret" then
		local main = rt:FindFirstChild("Main")
		if main then RarityFx.Rainbow(main) end
	end
	local named = typeof(d.Name) == "string" and d.Name ~= ""
	Kit.Text(bb, Config.DinoName(d), { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 24), Color = named and C.YellowHi or Color3.new(1, 1, 1), Color2 = named and C.Yellow or nil, Stroke = 3.5, Shadow = 3, MaxSize = 30 })
	local owner = st.Plot:GetAttribute("OwnerName")
	local sp = Config.Species[d.Species]
	local line = (named and sp) and (sp.Name .. "  -  " .. Config.FormatKG(d.KG or 0)) or Config.FormatKG(d.KG or 0)
	if typeof(owner) == "string" and owner ~= "" then line = string.upper(owner) .. "'S STAR  -  " .. line end
	Kit.Text(bb, line, { Pixel = true, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 60), Stroke = 2, Shadow = 1, MaxSize = 12, Color = C.Cream })
	bb.Parent = st.Root
	st.Card = bb
end

-- (found once per kit: the platform's parts are looked up every frame)
local function spotOf(st: Stage): BasePart?
	if st.Spot and st.Spot.Parent then return st.Spot end
	local kit = st.Kit
	local p = kit and kit:FindFirstChild("ShowcaseSpot", true)
	st.Spot = (p and p:IsA("BasePart")) and p or nil
	return st.Spot
end
local function turnOf(st: Stage): Model?
	if st.Turn and st.Turn.Parent then return st.Turn end
	local kit = st.Kit
	local tt = kit and kit:FindFirstChild("ShowcaseTurntable")
	if tt and tt:IsA("Model") and tt.PrimaryPart then
		st.Turn, st.Base = tt, tt:GetPivot()
	else
		st.Turn, st.Base = nil, nil
	end
	return st.Turn
end

-- the platform's turning angle right now (the same for every island; it just looks alive)
local function spinAngle(st: Stage): number
	return (os.clock() * SPIN + st.Spin) % (math.pi * 2)
end

local function placeDino(st: Stage)
	local d = st.Dino
	local spot = spotOf(st)
	if not d or not spot then return end
	local t = DinoT:FindFirstChild(d.Species)
	if not (t and t:IsA("Model")) then return end
	local m = t:Clone() :: Model
	prep(m)
	local root = m.PrimaryPart
	if not root then m:Destroy() return end
	root.Anchored = true
	-- its own size, then fitted to the platform: never spilling off it, never lost on it
	local scale = Config.DinoScale(d)
	m:ScaleTo(scale)
	local swim = Config.ShowcaseTank(d.Species)
	local _, size = m:GetBoundingBox()
	local wide, tall = math.max(size.X, size.Z), size.Y
	local maxWide = swim and 7.2 or FIT_WIDE
	local maxTall = swim and 5.6 or FIT_TALL
	local k = math.min(maxWide / math.max(wide, 0.01), maxTall / math.max(tall, 0.01))
	if wide * k < MIN_WIDE and not swim then k = math.min(MIN_WIDE / math.max(wide, 0.01), maxTall / math.max(tall, 0.01)) end
	k = math.min(k, swim and 99 or 3)
	scale *= k
	m:ScaleTo(scale)
	m:SetAttribute("AnimScale", scale)
	local box, size2 = m:GetBoundingBox()
	st.Lift = root.Position.Y - (box.Position.Y - size2.Y / 2)
	st.Swim = swim
	st.Model, st.Root = m, root
	if swim then
		st.Tank = tank(spot)
		;(st.Tank :: Model).Parent = st.Kit
	end
	root.CFrame = CFrame.new(spot.Position + Vector3.new(0, st.Lift, 0))
	m.Parent = st.Kit
	pcall(RarityFx.Apply, m, d.Rarity, math.max(size2.X, size2.Z))
	DinosaurAnimations.get(m)
	card(st, d, size2.Y * 0.55 + 2.6 + (swim and 2.5 or 0))
end

-- your own pedestal: PICK A STAR (the server only lets you set your own)
local openPicker: () -> ()
local function ensurePrompt(st: Stage)
	local mine = own(st.Plot)
	if not mine then
		if st.Prompt then st.Prompt:Destroy() st.Prompt = nil end
		return
	end
	if st.Prompt and st.Prompt.Parent then
		st.Prompt.ActionText = st.Dino and "Change star" or "Pick a star"
		return
	end
	local kit = st.Kit
	local host = kit and kit:FindFirstChild("ShowcasePlaque", true)
	if not (host and host:IsA("BasePart")) then return end
	local at = Instance.new("Attachment")
	at.Name = "ShowcasePromptAt"
	at.Position = Vector3.new(0, 0.6, -0.6)
	at.Parent = host
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "ShowcasePrompt"
	pr.ActionText = st.Dino and "Change star" or "Pick a star"
	pr.ObjectText = "Showcase"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr:SetAttribute("CampAction", "ShowcasePick")
	pr:SetAttribute("PromptColor", "Yellow")
	pr.Parent = at
	st.Prompt = pr
end

local function refresh(st: Stage)
	local kit = kitOf(st.Plot)
	if kit ~= st.Kit then
		clearDino(st)
		if st.Prompt then st.Prompt:Destroy() st.Prompt = nil end
		st.Kit, st.Glows, st.Lenses, st.Raw, st.Spot, st.Turn, st.Base = kit, nil, nil, "\0", nil, nil, nil
	end
	if not st.Kit then return end
	local raw = st.Plot:GetAttribute("Showcase")
	raw = typeof(raw) == "string" and raw or ""
	if raw ~= st.Raw then
		local before = st.Dino
		st.Raw = raw
		clearDino(st)
		st.Dino = decode(raw)
		if st.Dino then
			placeDino(st)
			-- a new star on YOUR pedestal: a little burst as it lands
			if own(st.Plot) and (not before or before.Id ~= st.Dino.Id) and st.Root then
				local spot = spotOf(st)
				if spot then pcall(CineKit.Sparkle, spot.Position + Vector3.new(0, 1, 0), (Config.Rarity[st.Dino.Rarity] or Config.Rarity.Common).Color, 1.2) end
			end
		end
		tint(st, st.Dino and (Config.Rarity[st.Dino.Rarity] or Config.Rarity.Common).Color or nil)
	end
	ensurePrompt(st)
end

local function stageOf(plot: Model): Stage
	local st = stages[plot]
	if not st then
		st = { Plot = plot, Kit = nil, Raw = "\0", Dino = nil, Model = nil, Root = nil, Lift = 0, Tank = nil, Card = nil, Prompt = nil, Glows = nil, Lenses = nil, Spin = (tonumber(plot:GetAttribute("PlotIndex")) or 0) * 0.9, Swim = false, Spot = nil, Turn = nil, Base = nil }
		stages[plot] = st
		plot:GetAttributeChangedSignal("Showcase"):Connect(function() pcall(refresh, st) end)
		plot:GetAttributeChangedSignal("Owner"):Connect(function() pcall(refresh, st) end)
	end
	return st
end

-- every frame: the platform turns, the star turns with it (or swims its slow circle in the tank)
local function stepStages(cam: Camera?)
	local camPos = cam and cam.CFrame.Position
	for _, st in pairs(stages) do
		local kit = st.Kit
		if not kit or not kit.Parent then continue end
		local spot = spotOf(st)
		if not spot then continue end
		if camPos and (spot.Position - camPos).Magnitude > 220 then continue end
		local a = spinAngle(st)
		local tt = turnOf(st)
		if tt and st.Base then tt:PivotTo((st.Base :: CFrame) * CFrame.Angles(0, a, 0)) end
		local root = st.Root
		if root and root.Parent then
			local cf
			if st.Swim then
				local r = 1.4
				local p = spot.Position + Vector3.new(math.cos(a * 1.6) * r, 3.4 + math.sin(os.clock() * 0.8) * 0.4, math.sin(a * 1.6) * r)
				cf = CFrame.lookAt(p, p + Vector3.new(-math.sin(a * 1.6), 0, math.cos(a * 1.6)))
			else
				cf = CFrame.new(spot.Position + Vector3.new(0, st.Lift, 0)) * CFrame.Angles(0, a, 0)
			end
			root.CFrame = cf
			local anim = DinosaurAnimations.find(st.Model :: Model)
			if anim then anim.HomeCFrame = cf end
		end
	end
end

--------------------------------------------------------------------------------
-- the picker (your pedestal's prompt)
--------------------------------------------------------------------------------
local canvas: Frame? = nil
local dim: TextButton? = nil
local win: Frame? = nil
local lastSig = ""

local function closePicker()
	local w = win
	win = nil
	if w then Kit.Exit(w, true) end
	if dim then TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play() end
	task.delay(0.22, function() if not win and dim then dim.Visible = false end end)
end
ShowcaseView.Close = closePicker

local function ensureScreen()
	if canvas then return end
	local _, cv = Kit.Screen("DinoShowcasePick", 21)
	canvas = cv
	local d = Instance.new("TextButton")
	d.Name = "Dim"
	d.Text = ""
	d.AutoButtonColor = false
	d.BackgroundColor3 = Color3.fromRGB(8, 16, 10)
	d.BackgroundTransparency = 1
	d.Size = UDim2.fromScale(4, 4)
	d.Position = UDim2.fromScale(-1.5, -1.5)
	d.Visible = false
	d.ZIndex = 1
	d.Parent = cv
	d.Activated:Connect(closePicker)
	dim = d
end

local function pixel(parent: Instance, s: string, props)
	props.Pixel = true
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2
	props.Shadow = props.Shadow or 1
	props.MaxSize = props.MaxSize or 12
	return Kit.Text(parent, s, props)
end

local function inLandPen(p, id: string): boolean
	for lot, pen in pairs(p.Island and p.Island.Pens or {}) do
		if typeof(pen) == "table" and pen.Dino == id and Config.Island.Lots[lot] ~= "Sea" then return true end
	end
	return false
end

local function setStar(id: string, label: string?)
	local res = Net.Ask("SetShowcase", { Id = id })
	if res and res.Ok then
		if id == "" then
			Kit.Toast("YOUR SHOWCASE IS EMPTY", "Grey", "Trophy")
		else
			Kit.Toast((res.Name or label or "YOUR DINO") .. " IS ON SHOW!", "Gold", "Trophy")
			closePicker()
		end
	else
		Kit.Toast(string.upper(tostring(res and res.Err or "CAN'T SHOW THAT ONE")), "Red", "Alert")
	end
end

local function sigOf(p): string
	if typeof(p) ~= "table" then return "" end
	local parts = { tostring(p.Showcase) }
	for _, d in ipairs(p.Dinos or {}) do table.insert(parts, d.Id .. tostring(d.Name)) end
	return table.concat(parts, "|")
end

local function buildPicker()
	if not canvas then return end
	local p = Net.Profile or {}
	local root, content = Kit.Window(canvas, { Fit = true, Title = "SHOWCASE", Color = "Yellow", Icon = "Trophy", Size = UDim2.fromOffset(860, 520), Position = UDim2.fromScale(0.5, 0.53), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20, OnClose = closePicker })
	win = root
	pixel(content, "PICK THE STAR OF YOUR ISLAND.  EVERYONE WHO VISITS SEES IT!", { Size = UDim2.new(1, -240, 0, 11), Position = UDim2.fromOffset(4, 16), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 11, Color = C.YellowHi })
	local current = typeof(p.Showcase) == "string" and p.Showcase or ""
	if current ~= "" then
		Kit.Button(content, { Text = "TAKE IT DOWN", Color = "Grey", Size = UDim2.fromOffset(210, 46), Position = UDim2.new(1, 0, 0, 2), AnchorPoint = Vector2.new(1, 0), ZIndex = 26, MaxText = 18, OnClick = function() setStar("") end })
	end
	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, 0, 1, -62)
	grid.Position = UDim2.fromOffset(0, 58)
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = C.LimeHi
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ZIndex = 22
	grid.Parent = content
	local lay = Instance.new("UIGridLayout")
	lay.CellSize = UDim2.fromOffset(150, 176)
	lay.CellPadding = UDim2.fromOffset(10, 10)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = grid
	local list = table.clone(p.Dinos or {})
	table.sort(list, function(a, b)
		local ra, rb = (Config.Rarity[a.Rarity] or Config.Rarity.Common).Order, (Config.Rarity[b.Rarity] or Config.Rarity.Common).Order
		if ra ~= rb then return ra > rb end
		return (a.KG or 0) > (b.KG or 0)
	end)
	local cards, first = {}, nil
	for i, d in ipairs(list) do
		local r = Config.Rarity[d.Rarity] or Config.Rarity.Common
		local on = d.Id == current
		local penned = inLandPen(p, d.Id)
		local cardF, cc = Kit.Card(grid, { Size = UDim2.fromScale(1, 1), Border = on and C.YellowHi or r.Color, ZIndex = 24 })
		cardF.LayoutOrder = i
		Kit.Icon(cc, "Dino", { Species = d.Species, Size = UDim2.fromOffset(100, 100), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, Silhouette = penned })
		local named = typeof(d.Name) == "string" and d.Name ~= ""
		Kit.Text(cc, Config.DinoName(d), { Size = UDim2.new(1, -10, 0, 15), Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 15, Stroke = 2.5, Shadow = 2, Color = named and C.YellowHi or Color3.new(1, 1, 1) })
		pixel(cc, r.Name .. "  " .. Config.FormatKG(d.KG or 0), { Size = UDim2.new(1, -10, 0, 8), Position = UDim2.new(0.5, 0, 0, 124), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 8, Color = r.Color:Lerp(Color3.new(1, 1, 1), 0.3) })
		local tag = on and "ON SHOW" or (penned and "IN STAR PEN" or nil)
		if tag then
			local b = Instance.new("Frame")
			b.BackgroundColor3 = on and C.Yellow or C.GreyLo
			b.Size = UDim2.new(1, -14, 0, 18)
			b.Position = UDim2.new(0.5, 0, 1, -26)
			b.AnchorPoint = Vector2.new(0.5, 0)
			b.ZIndex = 29
			b.Parent = cc
			Kit.Corner(b, 9)
			Kit.Stroke(b, C.Ink, 2)
			pixel(b, tag, { Size = UDim2.new(1, -6, 0, 9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 30, MaxSize = 9 })
		end
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 60
		hit.Parent = cardF
		hit.Activated:Connect(function()
			Kit.Sound("Click", 0.4)
			if on then return end
			if penned then Kit.Toast("IT LIVES IN ITS STAR PEN", "Orange", "Alert") Kit.Shake(cardF) return end
			setStar(d.Id, Config.DinoName(d))
		end)
		first = first or hit
		table.insert(cards, cardF)
	end
	if #list == 0 then
		pixel(grid, "HATCH A DINO TO PUT IT ON SHOW!", { Size = UDim2.new(1, 0, 0, 14), ZIndex = 26, MaxSize = 14, Color = C.Muted })
	end
	Kit.Stagger(cards, 0.015, 0.3)
	if first and Kit.Gamepad() then game:GetService("GuiService").SelectedObject = first end
end

openPicker = function()
	if Cinema.Playing() then return end
	ensureScreen()
	if Panels and Panels.IsOpen and Panels.IsOpen() then Panels.Close() end
	if win then win:Destroy() win = nil end
	if dim then
		dim.Visible = true
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.4 }):Play()
	end
	buildPicker()
	lastSig = sigOf(Net.Profile)
	if win then Kit.Enter(win) end
end
ShowcaseView.OpenPicker = function() openPicker() end

--------------------------------------------------------------------------------
function ShowcaseView.Start(panels: any?)
	Panels = panels
	ProximityPromptService.PromptTriggered:Connect(function(pr)
		if pr:GetAttribute("CampAction") == "ShowcasePick" then openPicker() end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if win and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then closePicker() end
	end)
	Net.On("Profile", function(p)
		if not win then return end
		local sig = sigOf(p)
		if sig == lastSig then return end
		lastSig = sig
		win:Destroy()
		win = nil
		buildPicker()
	end)
	-- the islands: the kits arrive when IslandView places them, so look again every so often
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			local plots = campPlots()
			if plots then
				for _, plot in ipairs(plots:GetChildren()) do
					if plot:IsA("Model") and plot:GetAttribute("PlotIndex") then
						local st = stageOf(plot)
						local ok, err = pcall(refresh, st)
						if not ok then warn("[ShowcaseView]", err) end
					end
				end
			end
		end
		pcall(stepStages, Workspace.CurrentCamera)
	end)
end

return ShowcaseView
