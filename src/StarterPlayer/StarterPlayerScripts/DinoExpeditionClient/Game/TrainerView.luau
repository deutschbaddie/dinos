--[[
	TrainerView — the POWER TRAINER on every island (2026-10-14; server: Trainer.luau, models: islandKit.js Trainer1..7).

	  the board     every island's TrainerBoard shows its level and POWER / SEC; yours shows the next upgrade
	                (LV N > N+1, the price, +X POWER / SEC) and has the UPGRADE prompt
	  the window    TRAINER: upgrade the machine, and craft / equip boss launchers (they moved here from the Armorer)
	  training      while you stand on your pad: a "+N" pops over your head every second, darts fly from you down the
	                range into the dummy, the pad pulses, sparks rise round you. Everyone sees anyone training.
	  rewards       fights pay POWER too (Trainer.Reward): a bigger gold "+N POWER" pops when one lands
	  GUESS THE DINO  a round button while you're on your pad: DinoQuiz.Open() (the quiz shows its own rewards)

	API: TrainerView.Pad(), TrainerView.Board(), TrainerView.OnPad() (the HUD's goal chain, onboarding and the quiz).
	Nothing here explains itself in words: the machine, the numbers and the effects do (show, don't tell).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)

local player = Players.LocalPlayer
local C = Theme.C
local T = Config.Trainer

local TrainerView = {}
local Panels: any = nil

-- the machine's accent per tier (matches islandKit.js TR.ACCENT)
local ACCENT = {
	Color3.fromHex("8fd14f"), Color3.fromHex("ff9a2e"), Color3.fromHex("38d6c4"), Color3.fromHex("ff4a3d"),
	Color3.fromHex("ffb02e"), Color3.fromHex("b06cff"), Color3.fromHex("40e8ff"),
}
local function accentOf(level: number): Color3
	return ACCENT[Config.TrainerTier(level)] or ACCENT[1]
end

--------------------------------------------------------------------------------
-- finding things on the islands
--------------------------------------------------------------------------------
local function campPlots(): Instance?
	local camp = Workspace:FindFirstChild("BaseCamp")
	return camp and camp:FindFirstChild("Plots")
end
local function plotByIndex(idx: any): Model?
	local plots = campPlots()
	if not plots or idx == nil then return nil end
	for _, p in ipairs(plots:GetChildren()) do
		if p:IsA("Model") and p:GetAttribute("PlotIndex") == idx then return p end
	end
	return nil
end
local function myPlot(): Model?
	return plotByIndex(player:GetAttribute("Plot"))
end
local function machineOf(plot: Model?): Model?
	local kit = plot and plot:FindFirstChild("IslandKit")
	if not kit then return nil end
	for _, m in ipairs(kit:GetChildren()) do
		if m:IsA("Model") and m.Name:match("^Trainer%d+$") then return m end
	end
	return nil
end
local function partIn(m: Model?, name: string): BasePart?
	local p = m and m:FindFirstChild(name, true)
	return (p and p:IsA("BasePart")) and p or nil
end
local function levelOfPlot(plot: Model): number
	return math.clamp(math.floor(tonumber(plot:GetAttribute("TrainerLevel")) or 1), 1, #T.Levels)
end
local function myLevel(): number
	return Config.TrainerLevel(Net.Profile)
end

-- your own trainer's pad / board (nil until your island's machine has been placed)
function TrainerView.Pad(): BasePart?
	return partIn(machineOf(myPlot()), "TrainerPad")
end
function TrainerView.Board(): BasePart?
	return partIn(machineOf(myPlot()), "TrainerBoard")
end
local function hrpOf(plr: Player): BasePart?
	local ch = plr.Character
	local h = ch and ch:FindFirstChild("HumanoidRootPart")
	return (h and h:IsA("BasePart")) and h or nil
end
-- standing on your own pad (the same check the server makes, so the button shows the moment you step on)
function TrainerView.OnPad(): boolean
	local pad, hrp = TrainerView.Pad(), hrpOf(player)
	if not pad or not hrp then return false end
	local d = hrp.Position - pad.Position
	return Vector3.new(d.X, 0, d.Z).Magnitude <= T.PadRadius and d.Y > -1 and d.Y < T.PadHeight
end

--------------------------------------------------------------------------------
-- the boards (a SurfaceGui on every island's TrainerBoard)
--------------------------------------------------------------------------------
local boards = {} :: { [BasePart]: { Gui: SurfaceGui, Plot: Model, Sig: string } }
local function boardGui(board: BasePart, plot: Model)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "TrainerBoardGui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0
	sg.MaxDistance = 140
	sg.Adornee = board
	sg.Parent = board
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = sg
	boards[board] = { Gui = sg, Plot = plot, Sig = "" }
	return boards[board]
end
local function refreshBoard(board: BasePart, b)
	local plot = b.Plot
	local lvl = levelOfPlot(plot)
	local mine = plot:GetAttribute("Owner") == player.UserId
	if mine then lvl = myLevel() end
	local nxt = T.Levels[lvl + 1]
	local profile = Net.Profile
	local gate = nxt and Config.TrainerGate(lvl + 1)
	local locked = gate ~= nil and not (profile and profile.Bosses and profile.Bosses[gate] and (profile.Bosses[gate].Best or 0) >= 1)
	local free = mine and T.FirstFree and profile and not (profile.Flags and profile.Flags.FreeUpgradeUsed) and ((profile.Stats and profile.Stats.Runs) or 0) >= 1
	local sig = string.format("%d|%s|%s|%s|%s", lvl, tostring(mine), tostring(locked), tostring(free), tostring(profile and profile.Coins and nxt and profile.Coins >= nxt.Cost))
	if sig == b.Sig then return end
	b.Sig = sig
	local root = b.Gui:FindFirstChild("Root") :: Frame
	root:ClearAllChildren()
	local acc = accentOf(lvl)
	local top = T.TierNames[Config.TrainerTier(lvl)] or "POWER TRAINER"
	Kit.Text(root, top, { Size = UDim2.new(0.94, 0, 0.2, 0), Position = UDim2.fromScale(0.5, 0.04), AnchorPoint = Vector2.new(0.5, 0), Color = acc, Stroke = 4, Shadow = 3, MaxSize = 40 })
	if mine and nxt then
		Kit.Text(root, string.format("TRAINING LV %d > %d", lvl, lvl + 1), { Size = UDim2.new(0.94, 0, 0.22, 0), Position = UDim2.fromScale(0.5, 0.26), AnchorPoint = Vector2.new(0.5, 0), Stroke = 4, Shadow = 3, MaxSize = 44 })
		Kit.Text(root, string.format("+%s POWER/SEC", Config.FormatNumber(nxt.PerSec)), { Size = UDim2.new(0.94, 0, 0.2, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0), Color = C.LimeHi, Color2 = C.Lime, Stroke = 4, Shadow = 3, MaxSize = 40 })
		local price = locked and ("BEAT THE " .. ((Config.Bosses[gate :: string] or {}).Name or "BOSS")) or (free and "FREE!" or ("$" .. Config.FormatNumber(nxt.Cost)))
		local col = locked and C.Grey or ((free or (profile and profile.Coins >= nxt.Cost)) and C.YellowHi or C.RedHi)
		Kit.Text(root, price, { Size = UDim2.new(0.94, 0, 0.22, 0), Position = UDim2.fromScale(0.5, 0.74), AnchorPoint = Vector2.new(0.5, 0), Color = col, Stroke = 4, Shadow = 3, MaxSize = 44 })
	else
		Kit.Text(root, "TRAINING LV " .. lvl, { Size = UDim2.new(0.94, 0, 0.26, 0), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0), Stroke = 4, Shadow = 3, MaxSize = 48 })
		Kit.Text(root, string.format("+%s POWER/SEC", Config.FormatNumber(Config.TrainerPerSec(lvl))), { Size = UDim2.new(0.94, 0, 0.22, 0), Position = UDim2.fromScale(0.5, 0.62), AnchorPoint = Vector2.new(0.5, 0), Color = C.LimeHi, Color2 = C.Lime, Stroke = 4, Shadow = 3, MaxSize = 40 })
	end
end

--------------------------------------------------------------------------------
-- the TRAINER window
--------------------------------------------------------------------------------
local screen: ScreenGui? = nil
local canvas: Frame? = nil
local dim: Frame? = nil
local win: Frame? = nil
local busy = false
local openWindow: () -> ()
local windowSig: () -> string
local lastSig = ""

local function closeWindow()
	local w = win
	win = nil
	if w then Kit.Exit(w, true) end
	if dim then TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play() end
	task.delay(0.22, function() if not win and dim then dim.Visible = false end end)
end
TrainerView.Close = closeWindow

local function ensureScreen()
	if screen then return end
	local gui, cv = Kit.Screen("DinoTrainer", 21)
	screen = gui
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
	d.Activated:Connect(closeWindow)
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

local function costText(cost): string
	local parts = {}
	if (cost.Coins or 0) > 0 then table.insert(parts, "$" .. Config.FormatNumber(cost.Coins)) end
	for mat, n in pairs(cost.Mats or {}) do
		local m = Config.Materials[mat]
		table.insert(parts, n .. "x " .. (m and m.Name or mat))
	end
	return table.concat(parts, " + ")
end
local function canPay(profile, cost): boolean
	if (cost.Coins or 0) > (profile.Coins or 0) then return false end
	for mat, n in pairs(cost.Mats or {}) do
		if ((profile.Materials or {})[mat] or 0) < n then return false end
	end
	return true
end

-- a burst of sparks on your pad (an upgrade landing)
local function padBurst(big: boolean)
	local pad = TrainerView.Pad()
	if not pad then return end
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 0.5, 0)
	a.Parent = pad
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(accentOf(myLevel()), Color3.new(1, 1, 1))
	e.LightEmission = 0.7
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, big and 1.4 or 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(10, big and 26 or 16)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Acceleration = Vector3.new(0, -18, 0)
	e.Rate = 0
	e.Parent = a
	e:Emit(big and 90 or 40)
	task.delay(2, function() a:Destroy() end)
end

local function doUpgrade()
	if busy then return end
	busy = true
	local before = myLevel()
	local res = Net.Ask("TrainerUpgrade")
	busy = false
	if not (res and res.Ok) then
		Kit.Sound("Error")
		Kit.Toast(string.upper(tostring(res and res.Err or "CAN'T UPGRADE")), "Red")
		if win then Kit.Shake(win) end
		return
	end
	Kit.Sound("Confirm")
	padBurst(res.NewTier == true)
	if res.NewTier then
		-- a brand-new machine stands on your island: close the window and let them see it
		closeWindow()
		local name = T.TierNames[res.Tier or 1] or "NEW TRAINER"
		Kit.Toast("NEW MACHINE: " .. name .. "!", "Orange", "Power")
	else
		Kit.Toast(string.format("TRAINING LV %d!  +%s POWER/SEC", res.Level or before + 1, Config.FormatNumber(res.PerSec or 0)), "Lime", "Power")
	end
end

local function launcherCard(list: ScrollingFrame, id: string, order: number)
	local profile = Net.Profile or {}
	local gear = profile.Gear or {}
	local def = Config.Launchers[id]
	local owned = gear.Launchers and gear.Launchers[id]
	local equipped = gear.Launcher == id
	local prev = Config.PrevTier(Config.LauncherOrder, id)
	local reachable = owned or prev == nil or (gear.Launchers and gear.Launchers[prev])
	local card, cc = Kit.Card(list, { Size = UDim2.fromOffset(330, 86), ZIndex = 24, Border = equipped and C.YellowHi or nil })
	card.LayoutOrder = order
	Kit.Icon(cc, "Launcher", { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 27, Silhouette = not reachable })
	Kit.Text(cc, def.Name, { Size = UDim2.new(1, -190, 0, 22), Position = UDim2.fromOffset(76, 10), Align = Enum.TextXAlignment.Left, ZIndex = 27, Color = reachable and def.Color or C.Grey, Stroke = 3, Shadow = 2, MaxSize = 22 })
	pixel(cc, def.Perk or "THE STARTER LAUNCHER", { Size = UDim2.new(1, -190, 0, 9), Position = UDim2.fromOffset(76, 40), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 9, Color = C.Muted })
	pixel(cc, string.format("POWER +%s", Config.FormatNumber((Config.GearPower.Launchers :: any)[id] or 0)), { Size = UDim2.new(1, -190, 0, 9), Position = UDim2.fromOffset(76, 58), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 9, Color = C.LimeHi })
	local bsize, bpos, banchor = UDim2.fromOffset(104, 48), UDim2.new(1, -8, 0.5, 0), Vector2.new(1, 0.5)
	if equipped then
		Kit.Button(cc, { Text = "EQUIPPED", Color = "Grey", Size = bsize, Position = bpos, AnchorPoint = banchor, ZIndex = 28, Disabled = true, MaxText = 16 })
	elseif owned then
		Kit.Button(cc, { Text = "EQUIP", Color = "Blue", Size = bsize, Position = bpos, AnchorPoint = banchor, ZIndex = 28, MaxText = 18, OnClick = function()
			local res = Net.Ask("TrainerEquip", { Id = id })
			if res and res.Ok then Kit.Sound("Confirm") else Kit.Toast(string.upper(tostring(res and res.Err or "CAN'T EQUIP")), "Red") end
		end })
	elseif def.Craft and reachable then
		local afford = canPay(profile, def.Craft)
		pixel(cc, costText(def.Craft), { Size = UDim2.new(0, 160, 0, 9), Position = UDim2.new(1, -118, 1, -10), AnchorPoint = Vector2.new(1, 1), Align = Enum.TextXAlignment.Right, ZIndex = 27, MaxSize = 8, Color = afford and C.YellowHi or C.RedHi })
		Kit.Button(cc, { Text = "CRAFT", Icon = "Hammer", Color = afford and "Orange" or "Grey", Size = bsize, Position = bpos, AnchorPoint = banchor, ZIndex = 28, MaxText = 18, Shine = afford, OnClick = function()
			local res = Net.Ask("TrainerCraft", { Id = id })
			if res and res.Ok then
				Kit.Sound("Confirm")
				Kit.Toast((res.Name or def.Name) .. " BUILT!", "Orange", "Launcher")
				padBurst(true)
			else
				Kit.Toast(string.upper(tostring(res and res.Err or "CAN'T CRAFT")), "Red")
			end
		end })
	else
		Kit.Icon(cc, "Lock", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -40, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28 })
	end
end

local function buildWindow()
	if not canvas then return end
	local profile = Net.Profile or {}
	local lvl = myLevel()
	local nxt = T.Levels[lvl + 1]
	local tier = Config.TrainerTier(lvl)
	local acc = accentOf(lvl)
	local root, content = Kit.Window(canvas, { Fit = true, Title = "POWER TRAINER", Color = "Lime", Icon = "Power", Size = UDim2.fromOffset(780, 470), Position = UDim2.fromScale(0.5, 0.53), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20, OnClose = closeWindow })
	win = root
	-- left: the machine
	local _, lc = Kit.Card(content, { Size = UDim2.new(0, 372, 1, -8), ZIndex = 22, Border = acc })
	Kit.Text(lc, T.TierNames[tier] or "POWER TRAINER", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 12), Align = Enum.TextXAlignment.Left, ZIndex = 25, Color = acc, Stroke = 3.5, Shadow = 3, MaxSize = 30 })
	pixel(lc, string.format("TIER %d / %d", tier, #T.TierNames), { Size = UDim2.new(0, 120, 0, 10), Position = UDim2.new(1, -12, 0, 22), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 25, MaxSize = 10, Color = C.Muted })
	-- the four levels of this tier
	local set = Kit.Segments(lc, T.PerTier, { Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 52), ZIndex = 25 })
	set(((lvl - 1) % T.PerTier + 1) / T.PerTier, acc)
	-- LV N > N+1 and POWER / SEC
	if nxt then
		Kit.Text(lc, string.format("LV %d", lvl), { Size = UDim2.new(0, 120, 0, 40), Position = UDim2.fromOffset(16, 84), Align = Enum.TextXAlignment.Left, ZIndex = 25, Stroke = 4, Shadow = 3, MaxSize = 40 })
		Kit.Glyph(lc, "Chevron", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(150, 89), ZIndex = 25, Color = C.YellowHi })
		Kit.Text(lc, string.format("LV %d", lvl + 1), { Size = UDim2.new(0, 150, 0, 40), Position = UDim2.fromOffset(196, 84), Align = Enum.TextXAlignment.Left, ZIndex = 25, Color = C.YellowHi, Color2 = C.Yellow, Stroke = 4, Shadow = 3, MaxSize = 40 })
		pixel(lc, "POWER / SEC", { Size = UDim2.new(1, -24, 0, 10), Position = UDim2.fromOffset(16, 140), Align = Enum.TextXAlignment.Left, ZIndex = 25, MaxSize = 10, Color = C.Muted })
		Kit.Text(lc, string.format("+%s", Config.FormatNumber(Config.TrainerPerSec(lvl))), { Size = UDim2.new(0, 120, 0, 34), Position = UDim2.fromOffset(16, 156), Align = Enum.TextXAlignment.Left, ZIndex = 25, Color = C.LimeHi, Stroke = 3.5, Shadow = 3, MaxSize = 34 })
		Kit.Glyph(lc, "Chevron", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(152, 161), ZIndex = 25, Color = C.LimeHi })
		Kit.Text(lc, string.format("+%s", Config.FormatNumber(nxt.PerSec)), { Size = UDim2.new(0, 160, 0, 34), Position = UDim2.fromOffset(196, 156), Align = Enum.TextXAlignment.Left, ZIndex = 25, Color = C.LimeHi, Color2 = C.Lime, Stroke = 3.5, Shadow = 3, MaxSize = 34 })
		local nextTier = Config.TrainerTier(lvl + 1) ~= tier
		if nextTier then
			pixel(lc, "NEW MACHINE: " .. (T.TierNames[Config.TrainerTier(lvl + 1)] or ""), { Size = UDim2.new(1, -24, 0, 11), Position = UDim2.fromOffset(16, 204), Align = Enum.TextXAlignment.Left, ZIndex = 25, MaxSize = 11, Color = accentOf(lvl + 1) })
		end
		-- the button: price / FREE / the boss that gates the next machine
		local gate = Config.TrainerGate(lvl + 1)
		local locked = gate ~= nil and not (profile.Bosses and profile.Bosses[gate] and (profile.Bosses[gate].Best or 0) >= 1)
		local free = T.FirstFree and not (profile.Flags and profile.Flags.FreeUpgradeUsed) and ((profile.Stats and profile.Stats.Runs) or 0) >= 1
		local afford = free or (profile.Coins or 0) >= nxt.Cost
		if locked then
			local b = Config.Bosses[gate :: string]
			Kit.Button(lc, { Text = "BEAT THE " .. (b and b.Name or "BOSS"), Icon = "Lock", Color = "Grey", Size = UDim2.new(1, -24, 0, 70), Position = UDim2.new(0, 12, 1, -14), AnchorPoint = Vector2.new(0, 1), ZIndex = 26, MaxText = 24, Disabled = true })
		else
			local label = free and "UPGRADE - FREE!" or ("UPGRADE  $" .. Config.FormatNumber(nxt.Cost))
			Kit.Button(lc, { Text = label, Icon = "Power", Color = afford and "Yellow" or "Grey", Size = UDim2.new(1, -24, 0, 70), Position = UDim2.new(0, 12, 1, -14), AnchorPoint = Vector2.new(0, 1), ZIndex = 26, MaxText = 28, Shine = afford, OnClick = doUpgrade })
		end
	else
		Kit.Text(lc, "MAX LEVEL!", { Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 96), ZIndex = 25, Color = C.YellowHi, Color2 = C.Yellow, Stroke = 4, Shadow = 3, MaxSize = 44 })
		Kit.Text(lc, string.format("+%s POWER/SEC", Config.FormatNumber(Config.TrainerPerSec(lvl))), { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 150), ZIndex = 25, Color = C.LimeHi, Stroke = 3.5, Shadow = 3, MaxSize = 30 })
	end
	-- your POWER and how much of it you trained
	pixel(lc, "YOUR POWER", { Size = UDim2.new(0.5, -16, 0, 10), Position = UDim2.new(0, 16, 1, -126), Align = Enum.TextXAlignment.Left, ZIndex = 25, MaxSize = 10, Color = C.Muted })
	Kit.Text(lc, Config.FormatNumber(profile.Power or 0), { Size = UDim2.new(0.5, -16, 0, 24), Position = UDim2.new(0, 16, 1, -112), Align = Enum.TextXAlignment.Left, ZIndex = 25, Color = C.TealHi, Stroke = 3, Shadow = 2, MaxSize = 24 })
	pixel(lc, "TRAINED", { Size = UDim2.new(0.5, -16, 0, 10), Position = UDim2.new(0.5, 0, 1, -126), Align = Enum.TextXAlignment.Left, ZIndex = 25, MaxSize = 10, Color = C.Muted })
	Kit.Text(lc, Config.FormatNumber(profile.TrainPower or 0), { Size = UDim2.new(0.5, -16, 0, 24), Position = UDim2.new(0.5, 0, 1, -112), Align = Enum.TextXAlignment.Left, ZIndex = 25, Color = C.LimeHi, Stroke = 3, Shadow = 2, MaxSize = 24 })
	-- right: launchers
	Kit.TierBar(content, "LAUNCHERS", { Size = UDim2.new(0, 360, 0, 30), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 23, Color = C.Orange, Color2 = C.OrangeLo })
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(0, 360, 1, -42)
	list.Position = UDim2.new(1, 0, 0, 38)
	list.AnchorPoint = Vector2.new(1, 0)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = C.LimeHi
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 23
	list.Parent = content
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 10)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = list
	for i, id in ipairs(Config.LauncherOrder) do launcherCard(list, id, i) end
	-- scroll so the next craft is in view
	local gear = profile.Gear or {}
	local cur = table.find(Config.LauncherOrder, gear.Launcher or "Rookie") or 1
	task.defer(function() list.CanvasPosition = Vector2.new(0, math.max(0, (cur - 2) * 96)) end)
end

openWindow = function()
	if Cinema.Playing() then return end
	ensureScreen()
	if Panels and Panels.IsOpen and Panels.IsOpen() then Panels.Close() end
	if win then win:Destroy() win = nil end
	if dim then
		dim.Visible = true
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.4 }):Play()
	end
	buildWindow()
	lastSig = windowSig()
	if win then Kit.Enter(win) end
end
TrainerView.Open = function() openWindow() end

-- what the window shows (it's rebuilt only when one of these changes: the profile is pushed every ~10 s on the pad)
windowSig = function(): string
	local p = Net.Profile or {}
	local g = p.Gear or {}
	local lvl = myLevel()
	local nxt = T.Levels[lvl + 1]
	local parts = { tostring(lvl), tostring(g.Launcher), tostring(p.Flags and p.Flags.FreeUpgradeUsed), tostring(nxt and (p.Coins or 0) >= nxt.Cost) }
	for _, id in ipairs(Config.LauncherOrder) do
		local d = Config.Launchers[id]
		table.insert(parts, (g.Launchers and g.Launchers[id]) and "o" or (d.Craft and canPay(p, d.Craft) and "c" or "-"))
	end
	for id, b in pairs(p.Bosses or {}) do if typeof(b) == "table" and (b.Best or 0) >= 1 then table.insert(parts, id) end end
	return table.concat(parts, "|")
end

local function refreshWindow()
	if not win then return end
	local sig = windowSig()
	if sig == lastSig then return end
	lastSig = sig
	win:Destroy()
	win = nil
	buildWindow()
end

--------------------------------------------------------------------------------
-- the prompt on your board
--------------------------------------------------------------------------------
local promptBoard: BasePart? = nil
local prompt: ProximityPrompt? = nil
local function ensurePrompt()
	local board = TrainerView.Board()
	if board == promptBoard and prompt and prompt.Parent then return end
	if prompt then prompt:Destroy() prompt = nil end
	promptBoard = board
	if not board then return end
	local at = Instance.new("Attachment")
	at.Name = "TrainerPromptAt"
	at.Position = Vector3.new(0, -1.2, -0.6)
	at.Parent = board
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "TrainerPrompt"
	pr.ActionText = "Upgrade"
	pr.ObjectText = "Power Trainer"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr:SetAttribute("CampAction", "Trainer")
	pr:SetAttribute("PromptColor", "Lime")
	pr.Parent = at
	prompt = pr
end

--------------------------------------------------------------------------------
-- training effects (anyone with the Training attribute, on their own island)
--------------------------------------------------------------------------------
local fx = {} :: { [Player]: { Aura: ParticleEmitter?, NextDart: number } }
local function auraFor(plr: Player, color: Color3): ParticleEmitter?
	local hrp = hrpOf(plr)
	if not hrp then return nil end
	local e = hrp:FindFirstChild("TrainAura") :: ParticleEmitter?
	if not e then
		local ne = Instance.new("ParticleEmitter")
		ne.Name = "TrainAura"
		ne.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		ne.LightEmission = 0.6
		ne.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		ne.Speed = NumberRange.new(3, 6)
		ne.SpreadAngle = Vector2.new(25, 25)
		ne.EmissionDirection = Enum.NormalId.Top
		ne.Lifetime = NumberRange.new(0.8, 1.4)
		ne.Rate = 10
		ne.Parent = hrp
		e = ne
	end
	(e :: ParticleEmitter).Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	return e
end

local function dartBurst(at: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = at
	p.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.25, 0.5)
	e.Rate = 0
	e.Parent = p
	e:Emit(14)
	task.delay(0.8, function() p:Destroy() end)
end

local function fireDart(plr: Player, target: BasePart, color: Color3)
	local hrp = hrpOf(plr)
	if not hrp then return end
	local from = hrp.Position + hrp.CFrame.RightVector * 0.9 + Vector3.new(0, 1.2, 0)
	local to = target.Position + Vector3.new((math.random() - 0.5) * 2.4, (math.random() - 0.5) * 2, 0)
	local dart = Instance.new("Part")
	dart.Name = "TrainDart"
	dart.Anchored = true
	dart.CanCollide = false
	dart.CanQuery = false
	dart.CanTouch = false
	dart.CastShadow = false
	dart.Material = Enum.Material.Neon
	dart.Color = color
	dart.Size = Vector3.new(0.3, 0.3, 1.6)
	dart.CFrame = CFrame.lookAt(from, to)
	dart.Parent = Workspace
	local dist = (to - from).Magnitude
	local tw = TweenService:Create(dart, TweenInfo.new(math.clamp(dist / 90, 0.15, 0.4), Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from).Unit) })
	tw.Completed:Connect(function()
		dart:Destroy()
		dartBurst(to, color)
	end)
	tw:Play()
end

-- the dummies wobble when hit: a small rock of the whole dummy model (client only)
local function wobble(machine: Model)
	for _, m in ipairs(machine:GetChildren()) do
		if m:IsA("Model") and m.Name:match("^Dummy_") and not m:GetAttribute("Wobbling") then
			m:SetAttribute("Wobbling", true)
			local base = m:GetPivot()
			task.spawn(function()
				for k = 1, 6 do
					if not m.Parent then return end
					m:PivotTo(base * CFrame.Angles(0, 0, math.rad((k % 2 == 0 and 1 or -1) * (7 - k) * 0.9)))
					task.wait(0.04)
				end
				if m.Parent then m:PivotTo(base) end
				m:SetAttribute("Wobbling", nil)
			end)
		end
	end
end

local function stepTraining(now: number)
	local cam = Workspace.CurrentCamera
	for _, plr in ipairs(Players:GetPlayers()) do
		local training = plr:GetAttribute("Training") == true
		local st = fx[plr]
		if not training then
			if st then
				if st.Aura then st.Aura:Destroy() end
				fx[plr] = nil
			end
			continue
		end
		local plot = plotByIndex(plr:GetAttribute("Plot"))
		local machine = machineOf(plot)
		local hrp = hrpOf(plr)
		if not plot or not machine or not hrp then continue end
		if cam and (cam.CFrame.Position - hrp.Position).Magnitude > 260 then continue end
		local color = accentOf(levelOfPlot(plot :: Model))
		if not st then
			st = { Aura = nil, NextDart = now }
			fx[plr] = st
		end
		local s = st :: { Aura: ParticleEmitter?, NextDart: number }
		if not s.Aura or not s.Aura.Parent then s.Aura = auraFor(plr, color) end
		local target = partIn(machine, "TargetPoint")
		if target and now >= s.NextDart and not Cinema.Playing() then
			s.NextDart = now + 0.55 + math.random() * 0.25
			fireDart(plr, target :: BasePart, color)
			task.delay(0.3, function() if machine.Parent then wobble(machine) end end)
		end
	end
end

local animated: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any
-- the machines' slow life: the pad breathes (faster while someone trains), T7's rings turn, cores pulse
local function stepMachines(now: number, dt: number)
	local plots = campPlots()
	if not plots then return end
	for _, plot in ipairs(plots:GetChildren()) do
		if not plot:IsA("Model") then continue end
		local m = machineOf(plot)
		if not m then continue end
		local owner = plot:GetAttribute("Owner")
		local busyPad = false
		if owner and owner ~= 0 then
			local plr = Players:GetPlayerByUserId(owner)
			busyPad = plr ~= nil and plr:GetAttribute("Training") == true
		end
		local pad = partIn(m, "TrainerPad")
		if pad then
			local speed = busyPad and 4 or 1.4
			pad.Transparency = 0.05 + 0.25 * (0.5 + 0.5 * math.sin(now * speed))
		end
		local anim = animated[m]
		if not anim then
			-- (found once per machine: walking every part of eight machines 20 times a second was the cost)
			local rings, glows = {}, {}
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("Model") and d.Name == "FloatRing" then table.insert(rings, d)
				elseif d:IsA("BasePart") and (d.Name == "TankCore" or d.Name == "EngineCore" or d.Name == "SkullEye") then table.insert(glows, d) end
			end
			anim = { Rings = rings, Glows = glows }
			animated[m] = anim
		end
		local a = anim :: { Rings: { Model }, Glows: { BasePart } }
		for _, r in ipairs(a.Rings) do r:PivotTo(r:GetPivot() * CFrame.Angles(0, dt * (busyPad and 1.6 or 0.5), 0)) end
		local glow = 0.1 + 0.3 * (0.5 + 0.5 * math.sin(now * (busyPad and 3 or 1.2)))
		for _, g in ipairs(a.Glows) do g.Transparency = glow end
	end
end

--------------------------------------------------------------------------------
-- "+N" popups
--------------------------------------------------------------------------------
local popGui: BillboardGui? = nil
local function popup(gain: number, reason: string?)
	if Cinema.Playing() then return end
	local hrp = hrpOf(player)
	if not hrp then return end
	local big = reason ~= nil
	local bb = Instance.new("BillboardGui")
	bb.Name = "TrainPop"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(big and 260 or 170, big and 70 or 52)
	bb.StudsOffset = Vector3.new((math.random() - 0.5) * 2.4, 3.2, 0)
	bb.Adornee = hrp
	bb.MaxDistance = 120
	bb.Parent = player:FindFirstChildOfClass("PlayerGui")
	local col = big and C.YellowHi or accentOf(myLevel()):Lerp(Color3.new(1, 1, 1), 0.25)
	local txt = "+" .. Config.FormatNumber(gain) .. (big and " POWER" or "")
	local t = Kit.Text(bb, txt, { Size = UDim2.fromScale(1, 1), Color = col, Color2 = big and C.Yellow or nil, Stroke = big and 4 or 3, Shadow = 3, MaxSize = big and 46 or 36 })
	Kit.Pop(t :: Frame, 0.3)
	local t0 = os.clock()
	local life = big and 1.6 or 1.0
	local start = bb.StudsOffset
	task.spawn(function()
		while bb.Parent do
			local a = (os.clock() - t0) / life
			if a >= 1 then break end
			bb.StudsOffset = start + Vector3.new(0, a * 3, 0)
			if a > 0.6 then
				for _, l in ipairs(t:GetDescendants()) do
					if l:IsA("TextLabel") then l.TextTransparency = (a - 0.6) / 0.4 end
					if l:IsA("UIStroke") then l.Transparency = (a - 0.6) / 0.4 end
				end
			end
			RunService.Heartbeat:Wait()
		end
		bb:Destroy()
	end)
	popGui = bb
end

--------------------------------------------------------------------------------
-- GUESS THE DINO (while you're on your pad)
--------------------------------------------------------------------------------
local quizBtn: Frame? = nil
local function quizModule(): any
	local mod = script.Parent:FindFirstChild("DinoQuiz")
	if not mod then return nil end
	local ok, m = pcall(require, mod :: ModuleScript)
	return ok and m or nil
end
local function ensureQuizButton()
	if quizBtn then return end
	local _, cv = Kit.Screen("DinoTrainerHUD", 6)
	local holder = Instance.new("Frame")
	holder.Name = "QuizHolder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(150, 150)
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, -18, 0.6, 0)
	holder.Visible = false
	holder.Parent = cv
	Kit.Button(holder, { Name = "GuessTheDino", Icon = "Dino", Species = "TyrannosaurusRex", IconSize = 0.86, Color = "Purple", Round = true, Size = UDim2.fromOffset(104, 104), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Shine = true, OnClick = function()
		local q = quizModule()
		if q and q.Open then pcall(q.Open) end
	end })
	Kit.Bob(holder, 3, 2.2)
	Kit.Text(holder, "GUESS THE DINO", { Size = UDim2.new(1, 10, 0, 22), Position = UDim2.new(0.5, 0, 1, -14), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 9, Color = C.PurpleHi, Color2 = C.Purple, Stroke = 3.5, Shadow = 3, MaxSize = 22 })
	quizBtn = holder
end
local quizShown = false
local function stepQuiz()
	ensureQuizButton()
	local q = quizModule()
	local want = TrainerView.OnPad() and not Cinema.Playing() and not (q and q.IsOpen and q.IsOpen()) and win == nil
	if want ~= quizShown then
		quizShown = want
		local h = quizBtn :: Frame
		if want then
			Kit.Pop(h, 0.3)
		else
			h.Visible = false
		end
	end
end

--------------------------------------------------------------------------------
function TrainerView.Start(panels: any?)
	Panels = panels
	game:GetService("UserInputService").InputBegan:Connect(function(input)
		if win and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then closeWindow() end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(pr)
		if pr:GetAttribute("CampAction") == "Trainer" and pr == prompt then openWindow() end
	end)
	Net.On("TrainTick", function(info)
		if typeof(info) ~= "table" then return end
		local p = Net.Profile
		-- (the snapshot is pushed every ~10 s while you train: keep the cached numbers live in between)
		if p then
			if typeof(info.TrainPower) == "number" then p.TrainPower = info.TrainPower end
			if typeof(info.Power) == "number" then p.Power = info.Power end
		end
		if info.Reason == "Quiz" then return end -- (the quiz window shows its own reward)
		if typeof(info.Gain) == "number" and info.Gain > 0 then popup(info.Gain, info.Reason) end
	end)
	Net.On("Profile", function()
		for board, b in pairs(boards) do
			if board.Parent then refreshBoard(board, b) end
		end
		if win and not busy then refreshWindow() end
	end)
	-- boards appear and change as machines are swapped in by the server
	local acc = 0
	local accFx = 0
	local last = os.clock()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now
		accFx += dt
		if accFx >= 0.05 then
			pcall(stepMachines, now, accFx)
			accFx = 0
		end
		pcall(stepTraining, now)
		acc += dt
		if acc < 0.3 then return end
		acc = 0
		pcall(ensurePrompt)
		pcall(stepQuiz)
		local plots = campPlots()
		if plots then
			for _, plot in ipairs(plots:GetChildren()) do
				if plot:IsA("Model") then
					local board = partIn(machineOf(plot), "TrainerBoard")
					if board and not boards[board] then
						local b = boardGui(board :: BasePart, plot)
						pcall(refreshBoard, board :: BasePart, b)
					elseif board then
						pcall(refreshBoard, board :: BasePart, boards[board])
					end
				end
			end
		end
		for board in pairs(boards) do
			if not board.Parent then boards[board] = nil end
		end
	end)
	Players.PlayerRemoving:Connect(function(plr) fx[plr] = nil end)
	local _ = popGui
end

return TrainerView
