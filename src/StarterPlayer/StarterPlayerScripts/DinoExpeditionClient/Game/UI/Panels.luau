--[[
	Panels — the modal windows, in the reference style (jungle window, gradient title strip, green cards).
	One open at a time; B / Escape / tapping the backdrop closes.

	BAG        your eggs and dinos: carry / incubate / drop eggs; yard / buddy / sell dinos; EQUIP BEST
	INDEX      every species x every rarity you've hatched
	WORKSHOP   THE ARMORER (the Mechanic NPC): armor (level up, craft boss armor at the bench) and gadgets. Nothing
	           else lives here since 2026-10-14: launcher power is your power trainer's, rover upgrades + the roof rack
	           the RIDE SHOP's, nests the hatchery's (the next nest's own prompt + its UPGRADE board), yard space the
	           pen's bench, companion slots the COMPANIONS window, island upgrades their own boards
	SHOP       passes, boosts and premium eggs
	ERAS       destinations and how to open the next one
	QUESTS     what you've taken on (optional; NPCs give them)
	SETTINGS   options, the CUTSCENE GALLERY, TEST TOOLS for developers, and ADMIN for staff (UI/AdminPanel)
	PICKER     which rover rolls out of your garage
]]

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local DevHooks = require(script.Parent.Parent.DevHooks)
local AdminPanel = require(script.Parent.AdminPanel)

local player = Players.LocalPlayer
local C = Theme.C
local Panels = {}
local canvas
local dimGui, dim
local current = nil
Panels.OnPick = nil :: ((string) -> ())?
-- set by init (avoids require cycles): Scenes, Hatch, EraView, Warp
Panels.Hooks = {} :: any

local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	for k, v in pairs(props or {}) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end

local function text(parent, s: string, props)
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2.5
	props.Shadow = props.Shadow or 2
	return Kit.Text(parent, s, props)
end
local function pixel(parent, s: string, props)
	props.Pixel = true
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2
	props.Shadow = props.Shadow or 1
	props.MaxSize = props.MaxSize or 12
	return Kit.Text(parent, s, props)
end

local function close()
	if not current then return end
	local root = current.Root
	current = nil
	Kit.Exit(root, true)
	TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	task.delay(0.2, function() if not current then dimGui.Enabled = false end end)
	GuiService.SelectedObject = nil
end
Panels.Close = close

local function scroller(parent: Instance, cell: Vector2, pad: number?, size: UDim2?, pos: UDim2?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = size or UDim2.fromScale(1, 1)
	s.Position = pos or UDim2.new()
	s.ScrollBarThickness = 8
	s.ScrollBarImageColor3 = C.LimeHi
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ZIndex = 22
	s.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(pad or 10, pad or 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = s
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 6)
	p.PaddingLeft = UDim.new(0, 6)
	p.PaddingBottom = UDim.new(0, 10)
	p.Parent = s
	return s
end

local function hitArea(parent: Instance, fn: () -> ())
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Size = UDim2.fromScale(1, 1)
	b.ZIndex = 60
	b.Parent = parent
	b.Activated:Connect(function() Kit.Sound("Click", 0.4) fn() end)
	return b
end

local function tabs(parent: Instance, list: { { string } }, active: string, onPick: (string) -> (), y: number?)
	local row = frame(parent, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, y or 0), ZIndex = 24 })
	local w = #list >= 5 and 150 or 170 -- five tabs (an admin's Settings) still fit the 840 window
	for i, t in ipairs(list) do
		local on = t[1] == active
		Kit.Button(row, { Name = t[1], Text = t[2], Icon = t[3], IconSize = 0.95, TextLeft = t[3] and 0.34 or 0.06, Color = on and "Yellow" or "Slate", Size = UDim2.fromOffset(w, 42), Position = UDim2.fromOffset((i - 1) * (w + 8), 0), ZIndex = 26, Lip = 4, Radius = 12, MaxText = 22, OnClick = function() onPick(t[1]) end })
	end
	return row
end

local function ask(name: string, args, okText: string?, color: string?, icon: string?)
	local res = Net.Ask(name, args)
	if res and res.Ok then
		if okText then Kit.Toast(okText, color or "Green", icon) end
	else
		Kit.Toast((res and res.Err) or "CAN'T DO THAT", "Red", "Alert")
	end
	return res
end

local function costChips(parent: Instance, cost, x: number, y: number, z: number): number
	-- coin + material chips; returns the width used
	local p = Net.Profile or {}
	local cx = x
	local function chip(icon: string, label: string, ok: boolean)
		local w = #label * 9 + 46
		local f = frame(parent, { Size = UDim2.fromOffset(w, 26), Position = UDim2.fromOffset(cx, y), BackgroundTransparency = 0.2, BackgroundColor3 = ok and C.InkSoft or C.RedLo, ZIndex = z })
		Kit.Corner(f, 13)
		Kit.Stroke(f, C.Ink, 2)
		Kit.Icon(f, icon, { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, -4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 2 })
		pixel(f, label, { Size = UDim2.new(1, -32, 0, 10), Position = UDim2.new(0, 28, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = z + 2, MaxSize = 10, Color = ok and C.Cream or C.RedHi })
		cx += w + 6
	end
	if (cost.Coins or 0) > 0 then chip("Coin", Config.FormatNumber(cost.Coins), (p.Coins or 0) >= cost.Coins) end
	for mat, n in pairs(cost.Mats or {}) do
		local have = (p.Materials and p.Materials[mat]) or 0
		chip("Mat_" .. mat, have .. "/" .. n .. " " .. (Config.Materials[mat] and Config.Materials[mat].Name or mat), have >= n)
	end
	return cx - x
end

local function canAfford(cost): boolean
	local p = Net.Profile
	if not p then return false end
	if (cost.Coins or 0) > p.Coins then return false end
	for mat, n in pairs(cost.Mats or {}) do if ((p.Materials or {})[mat] or 0) < n then return false end end
	return true
end

--------------------------------------------------------------------------------
-- BAG
--------------------------------------------------------------------------------
local bag = { Tab = "Eggs", Sel = nil :: string?, Selling = false, Picked = {} :: { [string]: boolean }, ConfirmDrop = nil :: string?, DropSlots = {} :: { GuiObject }, DragEnd = 0 }

local function findIn(list, id: string?)
	if not id then return nil end
	for _, x in ipairs(list or {}) do if x.Id == id then return x end end
	return nil
end
local function idIn(list: { string }?, id: string): boolean
	return list ~= nil and table.find(list, id) ~= nil
end

local function rarityCard(parent: Instance, order: number, rarity: string, selected: boolean)
	local r = Config.Rarity[rarity] or Config.Rarity.Common
	local outer, content = Kit.Card(parent, { Size = UDim2.fromScale(1, 1), Border = selected and C.YellowHi or r.Color, Color = "Card", ZIndex = 24 })
	outer.LayoutOrder = order
	local band = frame(content, { Size = UDim2.new(1, -10, 0, 22), Position = UDim2.new(0.5, 0, 1, -28), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 0, BackgroundColor3 = r.Color, ZIndex = 26 })
	Kit.Corner(band, 8)
	Kit.Gradient(band, Kit.Shade(r.Color, 1.2), Kit.Shade(r.Color, 0.8))
	pixel(band, r.Name, { Size = UDim2.new(1, -8, 0, 9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28, MaxSize = 9 })
	return outer, content
end

-- dragging a dino onto a hotbar slot (the strip in the Bag, or the real hotbar if it's showing).
-- Mouse: press and move a few pixels. Touch: press and hold a moment (so the grid still scrolls), then drag.
local function pointer(input: InputObject?): Vector2
	if input and input.UserInputType == Enum.UserInputType.Touch then return Vector2.new(input.Position.X, input.Position.Y) end
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end
local function dropSlotAt(pos: Vector2): number?
	local targets = {}
	for i, f in ipairs(bag.DropSlots or {}) do table.insert(targets, { f, i }) end
	local pg = player:FindFirstChild("PlayerGui")
	local bar = pg and pg:FindFirstChild("Hotbar", true)
	if bar and bar:IsA("GuiObject") and bar.Visible then
		for i = 1, 6 do
			local s = bar:FindFirstChild("Slot" .. i)
			if s and s:IsA("GuiObject") then table.insert(targets, { s, i }) end
		end
	end
	for _, t in ipairs(targets) do
		local f = t[1] :: GuiObject
		local a, s = f.AbsolutePosition, f.AbsoluteSize
		if f.Visible and pos.X >= a.X and pos.X <= a.X + s.X and pos.Y >= a.Y and pos.Y <= a.Y + s.Y then return t[2] end
	end
	return nil
end
local function makeDraggable(hit: GuiButton, d)
	hit.InputBegan:Connect(function(input)
		local touch = input.UserInputType == Enum.UserInputType.Touch
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and not touch then return end
		local start = pointer(input)
		local t0 = os.clock()
		local ghost: Frame? = nil
		local done = false
		local conn: RBXScriptConnection
		local endConn: RBXScriptConnection
		local function finish()
			if done then return end
			done = true
			conn:Disconnect()
			endConn:Disconnect()
			local sf = hit:FindFirstAncestorWhichIsA("ScrollingFrame")
			if sf then sf.ScrollingEnabled = true end
			if ghost then
				local slot = dropSlotAt(pointer(input))
				ghost:Destroy()
				bag.DragEnd = os.clock() + 0.25 -- the release isn't also a click
				if slot then
					ask("PinHotbar", { Id = d.Id, Slot = slot }, "ON YOUR HOTBAR (SLOT " .. slot .. ") - TAP IT TO HOLD", "Yellow", "Dino")
				end
			end
		end
		conn = RunService.RenderStepped:Connect(function()
			local pos = pointer(input)
			if not ghost then
				local moved = (pos - start).Magnitude
				if touch then
					if moved > 14 then finish() return end -- a scroll, not a drag
					if os.clock() - t0 < 0.35 then return end
				elseif moved < 8 then
					return
				end
				local sg = hit:FindFirstAncestorWhichIsA("ScreenGui")
				if not sg then finish() return end
				local sf = hit:FindFirstAncestorWhichIsA("ScrollingFrame")
				if sf then sf.ScrollingEnabled = false end -- the grid holds still while you drag
				local g = Instance.new("Frame")
				g.Name = "DragGhost"
				g.Size = UDim2.fromOffset(84, 84)
				g.AnchorPoint = Vector2.new(0.5, 0.5)
				g.BackgroundColor3 = (Config.Rarity[d.Rarity] or Config.Rarity.Common).Color
				g.BackgroundTransparency = 0.15
				g.ZIndex = 200
				g.Parent = sg
				Kit.Corner(g, 14)
				Kit.Stroke(g, C.Ink, 3)
				Kit.Icon(g, "Dino", { Species = d.Species, Size = UDim2.fromScale(0.95, 0.95), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 201 })
				ghost = g
			end
			local g = ghost :: Frame
			g.Position = UDim2.fromOffset(pos.X, pos.Y)
			local over = dropSlotAt(pos)
			g.Rotation = over and 0 or -6
			g.Size = over and UDim2.fromOffset(96, 96) or UDim2.fromOffset(84, 84)
		end)
		endConn = UserInputService.InputEnded:Connect(function(e)
			if e == input or e.UserInputType == Enum.UserInputType.MouseButton1 or (touch and e.UserInputType == Enum.UserInputType.Touch) then finish() end
		end)
	end)
end

local function buildBag(content: Frame, header: Frame)
	local p = Net.Profile
	if not p then return end
	local first = nil
	tabs(content, { { "Eggs", "EGGS " .. #(p.Eggs or {}), "Egg" }, { "Dinos", "DINOS " .. #(p.Dinos or {}), "Dino" } }, bag.Tab, function(t)
		bag.Tab, bag.Sel, bag.Selling = t, nil, false
		table.clear(bag.Picked)
		Panels.Refresh()
	end)
	-- right side of the tab row: the big actions
	if bag.Tab == "Eggs" then
		Kit.Button(content, { Text = "FILL NESTS", Icon = "Incubator", IconSize = 0.95, TextLeft = 0.32, Color = "Teal", Size = UDim2.fromOffset(190, 44), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 26, MaxText = 20, OnClick = function()
			local res = ask("AutoIncubate", {}, nil)
			if res and res.Ok then Kit.Toast(res.Count .. " EGGS ARE INCUBATING!", "Teal", "Incubator") end
		end })
	else
		Kit.Button(content, { Text = "EQUIP BEST", Icon = "Star", IconSize = 0.95, TextLeft = 0.3, Color = "Lime", Size = UDim2.fromOffset(190, 44), Position = UDim2.new(1, -160, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 26, MaxText = 20, Shine = true, OnClick = function()
			ask("EquipBest", {}, "YOUR BEST DINOS ARE OUT!", "Green", "Star")
		end })
		Kit.Button(content, { Text = bag.Selling and "CANCEL" or "SELL", Icon = "Sell", IconSize = 0.95, TextLeft = 0.34, Color = bag.Selling and "Grey" or "Red", Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 26, MaxText = 20, OnClick = function()
			bag.Selling = not bag.Selling
			table.clear(bag.Picked)
			Panels.Refresh()
		end })
	end
	local dinosTab = bag.Tab == "Dinos"
	local grid = scroller(content, Vector2.new(128, 168), 10, UDim2.new(1, 0, 1, dinosTab and -204 or -128), UDim2.fromOffset(0, 54))
	local detail = frame(content, { Size = UDim2.new(1, 0, 0, 66), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), ZIndex = 24 })
	bag.DropSlots = {}
	if dinosTab then
		-- your hotbar, right here: drag a dino onto a slot to keep it there (tap a pinned slot to take it off)
		local strip = frame(content, { Name = "HotbarStrip", Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 1, -72), AnchorPoint = Vector2.new(0, 1), ZIndex = 24 })
		pixel(strip, "HOTBAR - DRAG A DINO ONTO A SLOT", { Size = UDim2.new(0, 220, 0, 10), Position = UDim2.new(0, 2, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 10, Color = C.Cream })
		local byId = {}
		for _, dd in ipairs(p.Dinos or {}) do byId[dd.Id] = dd end
		local eggs = table.clone(p.Eggs or {})
		table.sort(eggs, function(a, b) return (Config.Rarity[a.Rarity].Order * 1e6 + (a.KG or 0)) > (Config.Rarity[b.Rarity].Order * 1e6 + (b.KG or 0)) end)
		local pins = p.HotbarPins or {}
		local ei = 1
		for i = 1, 6 do
			local pinned = byId[pins[i] or ""]
			local egg = nil
			if not pinned then egg = eggs[ei] if egg then ei += 1 end end
			local item = pinned or egg
			local r = item and Config.Rarity[item.Rarity] or nil
			local sl = frame(strip, { Name = "Drop" .. i, Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0, 236 + (i - 1) * 68, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 0.1, BackgroundColor3 = r and r.Color:Lerp(C.Forest, 0.45) or C.Forest, ZIndex = 26 })
			Kit.Corner(sl, 12)
			Kit.Stroke(sl, pinned and C.YellowHi or C.Ink, pinned and 3.5 or 2.5)
			text(sl, tostring(i), { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(4, 2), ZIndex = 30, MaxSize = 14, Color = C.Cream })
			if item then Kit.Icon(sl, pinned and "Dino" or "Egg", { Species = item.Species, Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28 }) end
			if pinned then
				hitArea(sl, function() ask("PinHotbar", { Id = pinned.Id }, "TAKEN OFF YOUR HOTBAR", "Grey", "Dino") end)
			end
			bag.DropSlots[i] = sl
		end
	end
	local cards = {}
	if bag.Tab == "Eggs" then
		local list = table.clone(p.Eggs or {})
		table.sort(list, function(a, b)
			local ra, rb = Config.Rarity[a.Rarity].Order, Config.Rarity[b.Rarity].Order
			if ra ~= rb then return ra > rb end
			return (a.KG or 0) > (b.KG or 0)
		end)
		for i, e in ipairs(list) do
			local held = player:GetAttribute("HeldEgg") == e.Id
			local card, cc = rarityCard(grid, i, e.Rarity, bag.Sel == e.Id or held)
			local size = 0.55 + 0.35 * math.clamp((Config.EggScale(e.Species, e.KG) - 0.95) / 2.0, 0, 1)
			Kit.Icon(cc, "Egg", { Species = e.Species, Size = UDim2.fromScale(size, size * 0.62), Position = UDim2.new(0.5, 0, 0, 56), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27 })
			text(cc, Config.Species[e.Species].Name, { Size = UDim2.new(1, -10, 0, 14), Position = UDim2.new(0.5, 0, 0, 102), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 14 })
			pixel(cc, Config.FormatKG(e.KG or 0), { Size = UDim2.new(1, -10, 0, 10), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 10, Color = C.YellowHi })
			if held then pixel(cc, "IN HAND", { Size = UDim2.new(1, -10, 0, 9), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 28, MaxSize = 9, Color = C.LimeHi }) end
			local hit = hitArea(card, function() bag.Sel = e.Id Panels.Refresh() end)
			require(script.Parent.Parent.EggTip).Bind(hit :: any, function() return e end)
			first = first or hit
			table.insert(cards, card)
		end
		if #list == 0 then pixel(grid, "NO EGGS YET - GO ON AN EXPEDITION!", { Size = UDim2.new(1, 0, 0, 14), ZIndex = 26, MaxSize = 14, Color = C.Muted }) end
		local e = findIn(p.Eggs, bag.Sel)
		if e then
			local r = Config.Rarity[e.Rarity]
			text(detail, r.Name .. " " .. Config.Species[e.Species].Name .. "  " .. Config.FormatKG(e.KG or 0), { Size = UDim2.new(0.42, 0, 0, 22), Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 22, Color = r.Color:Lerp(Color3.new(1, 1, 1), 0.3) })
			pixel(detail, "HATCHES IN " .. Config.FormatTime(math.ceil(r.Hatch * Config.HatchSpeed(p))), { Size = UDim2.new(0.42, 0, 0, 9), Position = UDim2.new(0, 4, 1, -8), AnchorPoint = Vector2.new(0, 1), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 9, Color = C.Muted })
			local held = player:GetAttribute("HeldEgg") == e.Id
			Kit.Button(detail, { Text = held and "PUT AWAY" or "CARRY", Icon = "Hand", IconSize = 0.9, TextLeft = 0.34, Color = "Yellow", Size = UDim2.fromOffset(160, 50), Position = UDim2.new(1, -340, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 26, MaxText = 20, OnClick = function()
				ask("HoldEgg", { Id = (not held) and e.Id or nil })
				close()
			end })
			Kit.Button(detail, { Text = "INCUBATE", Icon = "Incubator", IconSize = 0.9, TextLeft = 0.32, Color = "Teal", Size = UDim2.fromOffset(170, 50), Position = UDim2.new(1, -172, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 26, MaxText = 20, OnClick = function()
				ask("Incubate", { Id = e.Id }, "INTO THE NEST IT GOES!", "Teal", "Incubator")
			end })
			Kit.Button(detail, { Glyph = "X", Color = "Red", Size = UDim2.fromOffset(52, 50), Position = UDim2.new(0.44, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 26, OnClick = function()
				if bag.ConfirmDrop ~= e.Id then
					bag.ConfirmDrop = e.Id
					Kit.Toast("TAP X AGAIN TO DROP THIS EGG FOR GOOD", "Orange", "Alert")
					return
				end
				bag.ConfirmDrop = nil
				bag.Sel = nil
				ask("DropEgg", { Id = e.Id }, "EGG DROPPED", "Grey", "Egg")
			end })
		else
			pixel(detail, "TAP AN EGG.  CARRY IT TO A NEST, OR INCUBATE IT FROM HERE.", { Size = UDim2.new(1, -8, 0, 11), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 26, MaxSize = 11, Color = C.Muted })
		end
		Kit.Badge(header, nil)
	else
		local list = table.clone(p.Dinos or {})
		table.sort(list, function(a, b) return Config.DinoIncome(a) > Config.DinoIncome(b) end)
		for i, d in ipairs(list) do
			local placed, buddy = idIn(p.Placed, d.Id), idIn(p.Buddies, d.Id)
			local picked = bag.Picked[d.Id] == true
			local card, cc = rarityCard(grid, i, d.Rarity, bag.Sel == d.Id or picked)
			Kit.Icon(cc, "Dino", { Species = d.Species, Size = UDim2.fromOffset(96, 96), Position = UDim2.new(0.5, 0, 0, 50), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27 })
			text(cc, Config.DinoName(d), { Size = UDim2.new(1, -10, 0, 14), Position = UDim2.new(0.5, 0, 0, 98), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 14, Color = (d.Name and d.Name ~= "") and C.YellowHi or nil })
			if p.Showcase == d.Id then Kit.Icon(cc, "Trophy", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 4, 0, 46), ZIndex = 33 }) end
			pixel(cc, Config.FormatKG(d.KG or 0) .. "  $" .. Config.FormatNumber(Config.DinoIncome(d)) .. "/S", { Size = UDim2.new(1, -10, 0, 9), Position = UDim2.new(0.5, 0, 0, 118), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 9, Color = C.LimeHi })
			-- equipped or not, at a glance: a big COMPANION / YARD badge; stored dinos are dimmed with IN BAG
			local function badge(label: string, color: Color3, y: number)
				local b = frame(cc, { Size = UDim2.new(1, -14, 0, 18), Position = UDim2.new(0.5, 0, 0, y), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 0, BackgroundColor3 = color, ZIndex = 29 })
				Kit.Corner(b, 9)
				Kit.Stroke(b, C.Ink, 2)
				pixel(b, label, { Size = UDim2.new(1, -6, 0, 9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 30, MaxSize = 9 })
			end
			local penned = false
			for _, pen in pairs(p.Island and p.Island.Pens or {}) do if type(pen) == "table" and pen.Dino == d.Id then penned = true end end
			if buddy then badge("COMPANION", Color3.fromRGB(255, 140, 40), 4) end
			if placed then badge("IN YARD", Color3.fromRGB(70, 190, 80), buddy and 24 or 4) end
			if penned then badge("STAR PEN", Color3.fromRGB(240, 180, 40), 4) placed = true end
			local hurt = Config.Hurt(d, math.floor(workspace:GetServerTimeNow()))
			if hurt > 0 then badge("HURT  " .. math.ceil(hurt / 60) .. "M", Color3.fromRGB(220, 70, 60), (buddy and 20 or 0) + (placed and 20 or 0) + 4) end
			if not placed and not buddy then
				local dim = frame(cc, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.45, BackgroundColor3 = Color3.fromRGB(20, 22, 28), ZIndex = 31 })
				Kit.Corner(dim, 10)
				pixel(dim, "IN BAG", { Size = UDim2.new(1, -10, 0, 10), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 32, MaxSize = 10, Color = C.Cream })
			end
			local pinSlot = table.find(p.HotbarPins or {}, d.Id)
			if pinSlot then
				local hb = frame(cc, { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -6, 0, 46), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 0, BackgroundColor3 = C.YellowHi or C.Yellow, ZIndex = 33 })
				Kit.Corner(hb, 13)
				Kit.Stroke(hb, C.Ink, 2)
				text(hb, tostring(pinSlot), { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 34, MaxSize = 16, Color = C.Ink, Stroke = 0, Shadow = 0 })
			end
			if picked then Kit.Glyph(cc, "Check", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -6, 0, 6), AnchorPoint = Vector2.new(1, 0), ZIndex = 30, Color = C.LimeHi }) end
			local hit = hitArea(card, function()
				if os.clock() < (bag.DragEnd or 0) then return end
				if bag.Selling then
					if bag.Picked[d.Id] then bag.Picked[d.Id] = nil else bag.Picked[d.Id] = true end
				else
					bag.Sel = d.Id
				end
				Panels.Refresh()
			end)
			if not bag.Selling then makeDraggable(hit, d) end
			first = first or hit
			table.insert(cards, card)
		end
		if #list == 0 then pixel(grid, "HATCH AN EGG TO GET YOUR FIRST DINO!", { Size = UDim2.new(1, 0, 0, 14), ZIndex = 26, MaxSize = 14, Color = C.Muted }) end
		pixel(header, "YARD " .. #(p.Placed or {}) .. "/" .. (p.PenSlots or 0) .. "   COMPANIONS " .. #(p.Buddies or {}) .. "/" .. ((p.Gear and p.Gear.BuddySlots) or 1), { Size = UDim2.fromOffset(300, 12), Position = UDim2.new(1, -90, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 40, MaxSize = 12, Color = C.Cream })
		if bag.Selling then
			local ids, total = {}, 0
			for id in pairs(bag.Picked) do
				local d = findIn(p.Dinos, id)
				if d then table.insert(ids, id) total += Config.SellValue(d) end
			end
			pixel(detail, #ids .. " PICKED", { Size = UDim2.new(0.4, 0, 0, 14), Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 14 })
			Kit.Button(detail, { Text = "SELL FOR " .. Config.FormatNumber(total), Icon = "Sell", IconSize = 0.95, TextLeft = 0.24, Color = #ids > 0 and "Red" or "Grey", Disabled = #ids == 0, Size = UDim2.fromOffset(300, 52), Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 26, MaxText = 24, OnClick = function()
				local res = ask("SellDinos", { Ids = ids })
				if res and res.Ok then
					Kit.Toast("SOLD " .. res.Count .. " FOR " .. Config.FormatNumber(res.Coins) .. "!", "Gold", "Coin")
					bag.Selling = false
					table.clear(bag.Picked)
				end
			end })
		else
			local d = findIn(p.Dinos, bag.Sel)
			if d then
				local r = Config.Rarity[d.Rarity]
				local placed, buddy = idIn(p.Placed, d.Id), idIn(p.Buddies, d.Id)
				local named = typeof(d.Name) == "string" and d.Name ~= ""
				text(detail, named and Config.DinoName(d) or (r.Name .. " " .. Config.Species[d.Species].Name), { Size = UDim2.new(0, 226, 0, 22), Position = UDim2.new(0, 4, 0.5, -8), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 22, Color = named and C.YellowHi or r.Color:Lerp(Color3.new(1, 1, 1), 0.3) })
				pixel(detail, (named and (r.Name .. " " .. Config.Species[d.Species].Name .. "  -  ") or "") .. Config.FormatKG(d.KG or 0) .. "  -  POWER " .. Config.BuddyPower(d) .. "  -  " .. Config.BuddyRoleOf(d.Species).Name, { Size = UDim2.new(0, 226, 0, 9), Position = UDim2.new(0, 4, 0.5, 14), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 9, Color = C.Muted })
				-- NAME it, and put it on your island's SHOWCASE pedestal (Showcase.luau)
				Kit.Button(detail, { Text = named and "RENAME" or "NAME", Color = "Yellow", Size = UDim2.fromOffset(118, 29), Position = UDim2.new(0, 236, 0, 1), ZIndex = 26, Lip = 3, Radius = 10, MaxText = 14, OnClick = function()
					require(script.Parent.Parent.NameDialog).Open(d)
				end })
				local shown = p.Showcase == d.Id
				Kit.Button(detail, { Text = shown and "ON SHOW" or "SHOWCASE", Color = shown and "Grey" or "Orange", Size = UDim2.fromOffset(118, 29), Position = UDim2.new(0, 236, 1, -30), ZIndex = 26, Lip = 3, Radius = 10, MaxText = 14, OnClick = function()
					if shown then
						ask("SetShowcase", { Id = "" }, "YOUR SHOWCASE IS EMPTY", "Grey", "Trophy")
					else
						ask("SetShowcase", { Id = d.Id }, Config.DinoName(d) .. " IS ON SHOW AT YOUR ISLAND!", "Gold", "Trophy")
					end
				end })
				-- hurt (it bled out on a run): resting, can't fight. heal it now for coins, or wait it out
				local hurt = Config.Hurt(d, math.floor(workspace:GetServerTimeNow()))
				if hurt > 0 then
					local price = Config.HealPrice(d, hurt)
					local can = (p.Coins or 0) >= price
					Kit.Button(detail, { Text = "HEAL " .. Config.FormatNumber(price), Icon = "Coin", IconSize = 0.85, TextLeft = 0.3, Color = can and "Red" or "Grey", Disabled = not can, Size = UDim2.fromOffset(124, 50), Position = UDim2.new(1, -500, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 26, MaxText = 16, OnClick = function()
						ask("HealDino", { Id = d.Id }, Config.DinoName(d) .. " IS ALL BETTER!", "Green", "Buddy")
					end })
				-- hold it in your arms (like an egg)
				elseif d.Species ~= "Mosasaurus" then
					local holding = player:GetAttribute("HeldDino") == d.Id
					Kit.Button(detail, { Text = holding and "PUT DOWN" or "HOLD", Icon = "Hand", IconSize = 0.85, TextLeft = 0.36, Color = holding and "Grey" or "Yellow", Size = UDim2.fromOffset(124, 50), Position = UDim2.new(1, -500, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 26, MaxText = 16, OnClick = function()
						if player:GetAttribute("Site") then return end
						ask("HoldDino", { Id = (not holding) and d.Id or nil })
						close()
					end })
				end
				Kit.Button(detail, { Text = placed and "TO STORAGE" or "TO YARD", Icon = "Paddock", IconSize = 0.9, TextLeft = 0.3, Color = placed and "Grey" or "Lime", Size = UDim2.fromOffset(176, 50), Position = UDim2.new(1, -368, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 26, MaxText = 20, OnClick = function()
					ask(placed and "StoreDino" or "PlaceDino", { Id = d.Id })
				end })
				Kit.Button(detail, { Text = buddy and "UNEQUIP" or "COMPANION", Icon = "Buddy", IconSize = 0.9, TextLeft = 0.3, Color = buddy and "Grey" or "Teal", Size = UDim2.fromOffset(176, 50), Position = UDim2.new(1, -184, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 26, MaxText = 20, OnClick = function()
					ask(buddy and "UnequipCompanion" or "EquipCompanion", { Id = d.Id }, (not buddy) and "IT'S COMING WITH YOU!" or nil, "Teal", "Buddy")
				end })
			else
				pixel(detail, "YARD DINOS EARN MONEY.  COMPANIONS FOLLOW AND FIGHT WITH YOU.  BIG KG = BIG MONEY.", { Size = UDim2.new(1, -8, 0, 11), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 26, MaxSize = 11, Color = C.Muted })
			end
		end
	end
	Kit.Stagger(cards, 0.015, 0.3)
	return first
end

--------------------------------------------------------------------------------
-- COMPANIONS (the companion station in your paddock): three slots across the top - who's following you, an
-- empty slot to fill, or a locked one with how to open it (craft it, or Robux) - and your dinos underneath: tap one
-- to put it in the picked slot (or the first free one). Unequip and it just stays in the pen.
--------------------------------------------------------------------------------
local comp = { Slot = nil :: number? }
local function buildCompanions(content: Frame, header: Frame)
	local p = Net.Profile
	if not p then return end
	local g = p.Gear or {}
	local slots = g.BuddySlots or 1
	local equipped = p.Buddies or {}
	local first = nil
	local dps = Config.LauncherDps(g)
	local W = 272
	for i = 1, Config.BuddySlots.Max do
		local id = equipped[i]
		local d = id and findIn(p.Dinos, id)
		local x = (i - 1) * (W + 12)
		local locked = i > slots
		local picked = comp.Slot == i
		if d then
			local r = Config.Rarity[d.Rarity] or Config.Rarity.Common
			local card, cc = Kit.Card(content, { Size = UDim2.fromOffset(W, 196), Position = UDim2.fromOffset(x, 0), Border = picked and C.YellowHi or r.Color, Color = "Card", ZIndex = 24 })
			local _ = card
			Kit.Icon(cc, "Dino", { Species = d.Species, Size = UDim2.fromOffset(104, 104), Position = UDim2.fromOffset(6, 4), ZIndex = 27 })
			text(cc, Config.DinoName(d), { Size = UDim2.new(1, -120, 0, 20), Position = UDim2.fromOffset(112, 10), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 20, Color = (d.Name and d.Name ~= "") and C.YellowHi or nil })
			pixel(cc, r.Name .. "  " .. Config.FormatKG(d.KG or 0), { Size = UDim2.new(1, -120, 0, 9), Position = UDim2.fromOffset(112, 36), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 9, Color = r.Color:Lerp(Color3.new(1, 1, 1), 0.3) })
			local role = Config.BuddyRoleOf(d.Species)
			pixel(cc, role.Name, { Size = UDim2.new(1, -120, 0, 9), Position = UDim2.fromOffset(112, 54), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 9, Color = C.OrangeHi })
			local share = Config.Buddy.Share[r.Order] or Config.Buddy.Share[1]
			pixel(cc, "HP " .. Config.BuddyHP(d) .. "   HITS " .. math.floor(dps * share + 0.5) .. "/S", { Size = UDim2.new(1, -120, 0, 9), Position = UDim2.fromOffset(112, 72), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 9, Color = C.Cream })
			if i == 1 then pixel(cc, "LEAD - RIDES SHOTGUN", { Size = UDim2.new(1, -120, 0, 9), Position = UDim2.fromOffset(112, 90), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 9, Color = C.YellowHi }) end
			-- bond: what it knows, and what it learns next (trips together grow it)
			local xp = (p.Bond or {})[d.Id] or 0
			local lv = Config.BondLevel(xp)
			local known = {}
			for l = 1, lv do
				local perk = Config.BondPerk(d.Species, l)
				if perk and Config.PerkText[perk] then table.insert(known, Config.PerkText[perk][1]) end
			end
			text(cc, "BOND " .. lv, { Size = UDim2.fromOffset(90, 16), Position = UDim2.fromOffset(10, 108), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 16, Color = C.TealHi })
			pixel(cc, table.concat(known, " - "), { Size = UDim2.new(1, -110, 0, 8), Position = UDim2.fromOffset(100, 112), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 8, Color = C.Cream })
			local nextPerk = Config.BondPerk(d.Species, lv + 1)
			local need = Config.Bond.Levels[lv + 1]
			if nextPerk and need then
				pixel(cc, "NEXT: " .. Config.PerkText[nextPerk][1] .. " - " .. Config.PerkText[nextPerk][2], { Size = UDim2.new(1, -20, 0, 8), Position = UDim2.fromOffset(10, 128), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 8, Color = C.Muted })
			end
			local b = Kit.Button(cc, { Text = "UNEQUIP", Color = "Grey", Size = UDim2.new(1, -16, 0, 46), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 27, MaxText = 20, OnClick = function()
				comp.Slot = nil
				ask("UnequipCompanion", { Id = d.Id }, "BACK TO THE PEN", "Grey", "Paddock")
			end })
			first = first or b
		elseif not locked then
			-- an open slot: tap to pick it, then tap a dino below
			local card, cc = Kit.Card(content, { Size = UDim2.fromOffset(W, 196), Position = UDim2.fromOffset(x, 0), Border = picked and C.YellowHi or C.TealHi, Color = "Forest", ZIndex = 24 })
			Kit.Glyph(cc, "Plus", { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, 0, 0, 52), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27, Color = picked and C.YellowHi or C.TealHi })
			text(cc, picked and "NOW TAP A DINO" or "OPEN SLOT", { Size = UDim2.new(1, -16, 0, 20), Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 20 })
			pixel(cc, "PICK A DINO BELOW", { Size = UDim2.new(1, -16, 0, 9), Position = UDim2.new(0.5, 0, 0, 132), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 9, Color = C.Muted })
			local hit = hitArea(card, function() comp.Slot = (comp.Slot ~= i) and i or nil Panels.Refresh() end)
			first = first or hit
		else
			-- locked: the next one can be crafted (boss materials) or bought; later ones wait their turn
			local card, cc = Kit.Card(content, { Size = UDim2.fromOffset(W, 196), Position = UDim2.fromOffset(x, 0), Border = C.InkSoft, Color = "Forest", ZIndex = 24 })
			local _ = card
			Kit.Icon(cc, "Lock", { Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0.5, 0, 0, 34), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27 })
			text(cc, "SLOT " .. i, { Size = UDim2.new(1, -16, 0, 18), Position = UDim2.new(0.5, 0, 0, 66), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 18 })
			if i == slots + 1 then
				local cost = Config.BuddySlots.Crafts[slots]
				if cost then
					costChips(cc, cost, 8, 92, 27)
					local can = canAfford(cost)
					Kit.Button(cc, { Text = "CRAFT", Icon = "Wrench", IconSize = 0.85, TextLeft = 0.36, Color = can and "Lime" or "Grey", Disabled = not can, Size = UDim2.fromOffset(124, 46), Position = UDim2.new(0, 8, 1, -8), AnchorPoint = Vector2.new(0, 1), ZIndex = 27, MaxText = 16, OnClick = function()
						ask("BuyBase", { What = "Buddy" }, "NEW COMPANION SLOT!", "Teal", "Buddy")
					end })
				end
				local prod = Config.Products.CompanionSlot
				Kit.Button(cc, { Text = "R$ " .. tostring(prod.Price or 149), Color = "Purple", Size = UDim2.fromOffset(124, 46), Position = UDim2.new(1, -8, 1, -8), AnchorPoint = Vector2.new(1, 1), ZIndex = 27, MaxText = 16, OnClick = function()
					if prod.Id == 0 then Kit.Toast("COMING SOON!", "Purple", "Gem") return end
					MarketplaceService:PromptProductPurchase(player, prod.Id)
				end })
			else
				pixel(cc, "OPEN SLOT " .. (i - 1) .. " FIRST", { Size = UDim2.new(1, -16, 0, 9), Position = UDim2.new(0.5, 0, 0, 100), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 9, Color = C.Muted })
			end
		end
	end
	-- your dinos: yard ones first, strongest first (Mosasaurus can't leave the water)
	pixel(content, "TAP A DINO TO BRING IT ALONG.  COMPANIONS FOLLOW YOU, RIDE ALONG AND HELP YOU FIGHT - KEEP THEM SAFE!", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 206), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 10, Color = C.Muted })
	local grid = scroller(content, Vector2.new(124, 150), 10, UDim2.new(1, 0, 1, -226), UDim2.fromOffset(0, 222))
	local list = {}
	for _, d in ipairs(p.Dinos or {}) do if d.Species ~= "Mosasaurus" and not idIn(equipped, d.Id) then table.insert(list, d) end end
	table.sort(list, function(a, b)
		local pa, pb = idIn(p.Placed, a.Id), idIn(p.Placed, b.Id)
		if pa ~= pb then return pa end
		return Config.BuddyPower(a) > Config.BuddyPower(b)
	end)
	local cards = {}
	for i, d in ipairs(list) do
		local card, cc = rarityCard(grid, i, d.Rarity, false)
		Kit.Icon(cc, "Dino", { Species = d.Species, Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0.5, 0, 0, 44), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27 })
		text(cc, Config.DinoName(d), { Size = UDim2.new(1, -10, 0, 13), Position = UDim2.new(0.5, 0, 0, 86), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 13, Color = (d.Name and d.Name ~= "") and C.YellowHi or nil })
		pixel(cc, "POWER " .. Config.BuddyPower(d), { Size = UDim2.new(1, -10, 0, 9), Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 9, Color = C.OrangeHi })
		if not idIn(p.Placed, d.Id) then pixel(cc, "STORED", { Size = UDim2.new(1, -10, 0, 9), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 28, MaxSize = 9, Color = C.Muted }) end
		local hit = hitArea(card, function()
			local slot = comp.Slot
			comp.Slot = nil
			ask("EquipCompanion", { Id = d.Id, Slot = slot }, Config.DinoName(d) .. " IS COMING WITH YOU!", "Teal", "Buddy")
		end)
		first = first or hit
		table.insert(cards, card)
	end
	if #list == 0 then pixel(grid, "HATCH MORE DINOS TO PICK FROM!", { Size = UDim2.new(1, 0, 0, 14), ZIndex = 26, MaxSize = 14, Color = C.Muted }) end
	pixel(header, "COMPANIONS " .. #equipped .. "/" .. slots, { Size = UDim2.fromOffset(240, 12), Position = UDim2.new(1, -90, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 40, MaxSize = 12, Color = C.Cream })
	Kit.Stagger(cards, 0.015, 0.3)
	return first
end

--------------------------------------------------------------------------------
-- INDEX
--------------------------------------------------------------------------------
local IndexDefs = require(DinoShared:WaitForChild("Game"):WaitForChild("IndexDefs"))
local indexTab = "Dinos"
local secretEra = nil :: string?

-- the DINOS page: every species x every rarity you've hatched (the old Index)
local function indexDinos(content: Frame, header: Frame)
	local p = Net.Profile
	local index = p.Index or {}
	local found = 0
	for _ in pairs(index) do found += 1 end
	local nextM = nil
	for _, m in ipairs(Config.IndexMilestones) do if found < m.Count then nextM = m break end end
	local bonus = math.floor(Config.IndexBonus(found) * 100 + 0.5)
	pixel(header, found .. " / " .. (#Config.SpeciesOrder * #Config.RarityOrder) .. " FOUND  -  +" .. bonus .. "% INCOME" .. (nextM and ("  -  NEXT AT " .. nextM.Count) or ""), { Size = UDim2.fromOffset(520, 13), Position = UDim2.new(1, -90, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 40, MaxSize = 13, Color = C.YellowHi })
	local grid = scroller(content, Vector2.new(172, 190), 10, UDim2.new(1, 0, 1, -54), UDim2.fromOffset(0, 54))
	local first, cards = nil, {}
	for i, sp in ipairs(Config.SpeciesOrder) do
		local info = Config.Species[sp]
		local any = false
		for _, r in ipairs(Config.RarityOrder) do if index[sp .. ":" .. r] then any = true end end
		local era = Config.Era(info.Era)
		local card, cc = Kit.Card(grid, { Size = UDim2.fromScale(1, 1), Border = any and info.Color or C.JungleLo, ZIndex = 24 })
		card.LayoutOrder = i
		Kit.Icon(cc, "Dino", { Species = sp, Size = UDim2.fromOffset(108, 108), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, Silhouette = not any })
		text(cc, any and info.Name or "???", { Size = UDim2.new(1, -10, 0, 15), Position = UDim2.new(0.5, 0, 0, 112), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 15 })
		pixel(cc, era and era.Name or "", { Size = UDim2.new(1, -10, 0, 8), Position = UDim2.new(0.5, 0, 0, 132), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 8, Color = C.Muted })
		-- six rarity pips
		for k, r in ipairs(Config.RarityOrder) do
			local got = index[sp .. ":" .. r] == true
			local rc = Config.Rarity[r].Color
			local pip = frame(cc, { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0.5, (k - 3.5) * 24, 1, -24), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = got and 0 or 0.4, BackgroundColor3 = got and rc or C.InkSoft, ZIndex = 28 })
			Kit.Corner(pip, 6)
			Kit.Stroke(pip, got and Color3.new(1, 1, 1) or C.Ink, 2)
		end
		local hit = hitArea(card, function()
			local have = {}
			for _, r in ipairs(Config.RarityOrder) do if index[sp .. ":" .. r] then table.insert(have, Config.Rarity[r].Name) end end
			Kit.Toast(any and (info.Name .. ": " .. table.concat(have, ", ")) or ("FOUND IN " .. (era and era.Name or "???")), any and "Blue" or "Grey", "Index")
		end)
		first = first or hit
		table.insert(cards, card)
	end
	Kit.Stagger(cards, 0.02, 0.3)
	return first
end

-- what a reward gives, in one short line ("+5% POWER  +$2.5K  TITLE")
local function payLine(pay): string
	local parts = {}
	if (pay.Luck or 0) > 0 then table.insert(parts, "+" .. math.floor(pay.Luck * 100 + 0.5) .. "% LUCK") end
	if (pay.Power or 0) > 0 then table.insert(parts, "+" .. math.floor(pay.Power * 100 + 0.5) .. "% POWER") end
	if (pay.Coins or 0) > 0 then table.insert(parts, "$" .. Config.FormatNumber(pay.Coins)) end
	return table.concat(parts, "  ")
end

local claiming = false
local function claimReward(key: string)
	if claiming then return end
	claiming = true
	local res = Net.Ask("IndexClaim", { Key = key })
	claiming = false
	if not (res and res.Ok) then
		Kit.Toast(string.upper(tostring(res and res.Err or "CAN'T CLAIM THAT")), "Red", "Alert")
		return
	end
	Kit.Sound("Confirm")
	local d = 0
	local function toast(t: string, c: string, icon: string)
		task.delay(d, function() Kit.Toast(t, c, icon) end)
		d += 0.5
	end
	if res.Gold then
		local b = Config.Bosses[res.Gold]
		toast("GOLD " .. (b and b.Name or "BOSS") .. " TROPHY - AT YOUR ISLAND!", "Gold", "Trophy")
	end
	if res.Title and IndexDefs.Titles[res.Title] then toast("NEW TITLE: " .. IndexDefs.Titles[res.Title].Name, "Blue", "Crown") end
	if (res.Power or 0) > 0 then toast("+" .. math.floor(res.Power * 100 + 0.5) .. "% POWER - FOR GOOD!", "Lime", "Power") end
	if (res.Luck or 0) > 0 then toast("+" .. math.floor(res.Luck * 100 + 0.5) .. "% LUCK - FOR GOOD!", "Orange", "Star") end
	if (res.Coins or 0) > 0 then toast("+" .. Config.FormatNumber(res.Coins) .. " COINS", "Gold", "Coin") end
end

-- one reward card: ready ones glow and CLAIM; claimed ones are ticked; the rest show how far along you are
local function rewardCard(parent: Instance, r, x: number, y: number, w: number, h: number, icon: string, species: string?, title: string, progress: string)
	local pay = IndexDefs.Payout(r)
	local ready = r.Ready and not r.Claimed
	local card, cc = Kit.Card(parent, { Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, y), ZIndex = 24, Border = ready and C.YellowHi or (r.Claimed and C.Lime or nil), Color = r.Claimed and "Card" or "Forest" })
	Kit.Icon(cc, icon, { Species = species, Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, Silhouette = not (r.Ready or r.Claimed) })
	text(cc, title, { Size = UDim2.new(1, -10, 0, 15), Position = UDim2.new(0.5, 0, 0, 58), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 15, Color = ready and C.YellowHi or nil })
	pixel(cc, payLine(pay), { Size = UDim2.new(1, -10, 0, 8), Position = UDim2.new(0.5, 0, 0, 78), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 8, Color = C.LimeHi })
	local extra = pay.Title and IndexDefs.Titles[pay.Title] and IndexDefs.Titles[pay.Title].Name or (pay.Gold and "GOLD TROPHY" or "")
	if extra ~= "" then pixel(cc, extra, { Size = UDim2.new(1, -10, 0, 7), Position = UDim2.new(0.5, 0, 0, 92), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 7, Color = C.OrangeHi }) end
	local first = nil
	if ready then
		local _, hit = Kit.Button(cc, { Text = "CLAIM", Color = "Yellow", Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 28, Lip = 3, Radius = 10, MaxText = 16, Shine = true, OnClick = function() claimReward(r.Key) end })
		first = hit
	elseif r.Claimed then
		Kit.Glyph(cc, "Check", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28, Color = C.LimeHi })
	else
		pixel(cc, progress, { Size = UDim2.new(1, -10, 0, 10), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27, MaxSize = 10, Color = C.Muted })
	end
	return card, first
end

-- the REWARDS page: the species track, the era pages, your titles
local function indexRewards(content: Frame, header: Frame)
	local p = Net.Profile
	local luck, power = IndexDefs.Bonus(p)
	pixel(header, "INDEX BONUS  +" .. math.floor(luck * 100 + 0.5) .. "% LUCK  +" .. math.floor(power * 100 + 0.5) .. "% POWER", { Size = UDim2.fromOffset(420, 13), Position = UDim2.new(1, -90, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 40, MaxSize = 13, Color = C.YellowHi })
	local rewards = IndexDefs.Rewards(p)
	local first, cards = nil, {}
	-- the species track
	local track = IndexDefs.Tracks[1]
	local count = IndexDefs.Count(p, track.Id)
	local total = IndexDefs.SpeciesTotal()
	Kit.TierBar(content, track.Name .. "   " .. count .. " / " .. total, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 52), ZIndex = 23, Color = C.Blue, Color2 = C.BlueLo, Align = Enum.TextXAlignment.Left })
	local nodes, eras = {}, {}
	for _, r in ipairs(rewards) do
		if r.Kind == "Node" then table.insert(nodes, r) elseif r.Kind == "Era" then table.insert(eras, r) end
	end
	local w = math.floor((860 - 8 * (math.max(#nodes, 1) - 1)) / math.max(#nodes, 1))
	for i, r in ipairs(nodes) do
		local at = r.At
		local card, hit = rewardCard(content, r, (i - 1) * (w + 8), 86, w, 150, "Index", nil, (r.Def.At == "All" and "ALL " or "") .. at .. " SPECIES", math.min(count, at) .. " / " .. at)
		table.insert(cards, card)
		first = first or hit
	end
	-- the era pages: every species of the era (its boss too)
	Kit.TierBar(content, "ERA PAGES - FIND EVERY DINO OF AN ERA", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 246), ZIndex = 23, Color = C.Orange, Color2 = C.OrangeLo, Align = Enum.TextXAlignment.Left })
	local we = math.floor((860 - 8 * (math.max(#eras, 1) - 1)) / math.max(#eras, 1))
	for i, r in ipairs(eras) do
		local boss = Config.Bosses[r.Era.Boss]
		local card, hit = rewardCard(content, r, (i - 1) * (we + 8), 280, we, 150, "Dino", boss and boss.Species or nil, r.Era.Name, r.Found .. " / " .. r.Total)
		table.insert(cards, card)
		first = first or hit
	end
	-- your titles: wear one (or none)
	local earned = IndexDefs.EarnedTitles(p)
	local wearing = (p.IndexRewards and p.IndexRewards.Title) or ""
	local row = frame(content, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -34), ZIndex = 24 })
	pixel(row, #earned > 0 and "TITLE:" or "CLAIM A REWARD WITH A TITLE TO WEAR IT OVER YOUR HEAD", { Size = UDim2.new(0, #earned > 0 and 64 or 600, 0, 11), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 11, Color = #earned > 0 and C.Cream or C.Muted })
	if #earned > 0 then
		local x = 70
		local list = { "" }
		for _, t in ipairs(earned) do table.insert(list, t) end
		for _, id in ipairs(list) do
			local def = IndexDefs.Titles[id]
			local label = def and def.Name or "NONE"
			local bw = #label * 9 + 30
			if x + bw > 860 then break end
			local on = id == wearing
			Kit.Button(row, { Text = label, Color = on and "Yellow" or "Slate", Size = UDim2.fromOffset(bw, 32), Position = UDim2.new(0, x, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 26, Lip = 3, Radius = 10, MaxText = 13, TextColor = (def and not on) and def.Color or nil, OnClick = function()
				if on then return end
				ask("IndexTitle", { Title = id }, id == "" and "TITLE OFF" or ("NOW WEARING: " .. label), "Blue", "Crown")
			end })
			x += bw + 6
		end
	end
	Kit.Stagger(cards, 0.02, 0.3)
	return first
end

-- a secret's icon
local SECRET_ICON = { Nest = "Egg", Boss = "Dino", Stash = "Gift", Wild = "Dino", Shiny = "Star" }
local KIND_WORD = {
	Falls = "A WATERFALL", Arch = "AN ARCH", Tree = "A GIANT TREE", Lookout = "A LOOKOUT", Ruins = "SOME RUINS", Fossil = "A FOSSIL",
	Cave = "A CAVE", Log = "A FALLEN LOG", Island = "AN ISLAND", Spring = "A SPRING", Wreck = "A WRECK", Rock = "A ROCK", Grove = "A GROVE",
	Pond = "A POND", Totem = "A TOTEM", Bridge = "A BRIDGE", Dune = "A DUNE", Nest = "A NEST", Boss = "THE RULER", Stash = "HIDDEN EGGS",
	Wild = "CALM A WILD DINO", Shiny = "CALM A SHINY ONE",
}

-- the SECRETS page: each era's landmarks, nests, stash, wilds and boss
local function indexSecrets(content: Frame, header: Frame)
	local p = Net.Profile
	local eras = IndexDefs.PageEras()
	if #eras == 0 then return nil end
	local unlocked = p.Unlocked or {}
	if not secretEra or not Config.Era(secretEra) then
		secretEra = (p.Era and Config.Era(p.Era) and p.Era) or eras[1].Id
	end
	local allFound, allTotal = 0, 0
	for _, e in ipairs(eras) do
		local n, t = IndexDefs.SecretProgress(p, e.Id)
		allFound += n
		allTotal += t
	end
	pixel(header, "SECRETS " .. allFound .. " / " .. allTotal, { Size = UDim2.fromOffset(300, 13), Position = UDim2.new(1, -90, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 40, MaxSize = 13, Color = C.YellowHi })
	-- left: the eras
	local first = nil
	for i, e in ipairs(eras) do
		local open = unlocked[e.Id] == true
		local n, t = IndexDefs.SecretProgress(p, e.Id)
		local on = e.Id == secretEra
		local done = t > 0 and n >= t
		local label = open and (e.Name .. "  " .. n .. "/" .. t) or e.Name
		local _, hit = Kit.Button(content, { Text = label, Icon = done and "Trophy" or (open and "Map" or "Lock"), IconSize = 0.8, TextLeft = 0.2, Color = on and "Yellow" or (done and "Lime" or "Slate"), Size = UDim2.fromOffset(220, 46), Position = UDim2.fromOffset(0, 54 + (i - 1) * 54), ZIndex = 26, Lip = 4, Radius = 12, MaxText = 15, OnClick = function()
			secretEra = e.Id
			Panels.Refresh()
		end })
		first = first or hit
	end
	-- right: the chosen era's secrets
	local eraId = secretEra :: string
	local era = Config.Era(eraId)
	local list = IndexDefs.Secrets(eraId)
	local n, t = IndexDefs.SecretProgress(p, eraId)
	local paint = IndexDefs.SecretPaint[eraId]
	local Rides = require(DinoShared:WaitForChild("Game"):WaitForChild("Rides"))
	local item = paint and Rides.Item("Paint", paint)
	local done = t > 0 and n >= t
	local reward = done and "ALL FOUND! " .. (item and (item.Name .. " PAINT IS YOURS") or "") or ("FIND THEM ALL:  " .. (item and (item.Name .. " ROVER PAINT  +  ") or "") .. "$" .. Config.FormatNumber(IndexDefs.SecretCoinsPerTier * Config.EraTier(eraId)))
	Kit.TierBar(content, (era and era.Name or eraId) .. "   " .. n .. " / " .. t, { Size = UDim2.new(1, -232, 0, 28), Position = UDim2.fromOffset(232, 52), ZIndex = 23, Color = done and C.Lime or C.Teal, Color2 = done and C.LimeLo or C.TealLo, Align = Enum.TextXAlignment.Left })
	pixel(content, reward, { Size = UDim2.new(1, -240, 0, 10), Position = UDim2.fromOffset(236, 88), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 10, Color = done and C.LimeHi or C.YellowHi })
	local grid = scroller(content, Vector2.new(146, 112), 8, UDim2.new(1, -232, 1, -108), UDim2.fromOffset(232, 104))
	local cards = {}
	local found = (typeof(p.Discover) == "table" and p.Discover[eraId]) or {}
	for i, s in ipairs(list) do
		local got = found[s.Id] == true
		local card, cc = Kit.Card(grid, { Size = UDim2.fromScale(1, 1), ZIndex = 24, Border = got and C.LimeHi or nil, Color = got and "Card" or "Forest" })
		card.LayoutOrder = i
		local icon = SECRET_ICON[s.Kind] or "Map"
		Kit.Icon(cc, icon, { Species = s.Species, Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, Silhouette = not got })
		text(cc, got and s.Name or "???", { Size = UDim2.new(1, -10, 0, 13), Position = UDim2.new(0.5, 0, 0, 58), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 13, Color = got and C.Cream or C.Muted })
		pixel(cc, got and "FOUND" or (KIND_WORD[s.Kind] or "SOMEWHERE"), { Size = UDim2.new(1, -10, 0, 8), Position = UDim2.new(0.5, 0, 0, 80), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 8, Color = got and C.LimeHi or C.Muted })
		if got then Kit.Glyph(cc, "Check", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -6, 0, 6), AnchorPoint = Vector2.new(1, 0), ZIndex = 28, Color = C.LimeHi }) end
		table.insert(cards, card)
	end
	if not unlocked[eraId] then
		pixel(grid, "OPEN THIS ERA AT THE TIME GATE TO START EXPLORING", { Size = UDim2.new(1, 0, 0, 12), ZIndex = 26, MaxSize = 12, Color = C.Muted })
	end
	Kit.Stagger(cards, 0.012, 0.3)
	return first
end

local function buildIndex(content: Frame, header: Frame)
	local p = Net.Profile
	if not p then return end
	local ready = IndexDefs.ClaimableCount(p)
	local row = tabs(content, { { "Dinos", "DINOS", "Dino" }, { "Rewards", "REWARDS", "Trophy" }, { "Secrets", "SECRETS", "Map" } }, indexTab, function(t)
		indexTab = t
		Panels.Refresh()
	end)
	-- (a red badge on REWARDS while something is ready to claim)
	local rewardsTab = row:FindFirstChild("Rewards")
	if rewardsTab and ready > 0 then Kit.Badge(rewardsTab :: GuiObject, ready) end
	if indexTab == "Rewards" then return indexRewards(content, header) end
	if indexTab == "Secrets" then return indexSecrets(content, header) end
	return indexDinos(content, header)
end

--------------------------------------------------------------------------------
-- WORKSHOP: THE ARMORER (armor + gadgets only since 2026-10-14, user: "quartermaster is just for armor so call him
-- the armorer")
-- (2026-10-13, mockup C) a drawer down the right side so the camp stays in view: icon tabs, your gear with one
-- big LEVEL UP, then the next gear and exactly what it still needs; SEE ALL opens the whole tier road.
--------------------------------------------------------------------------------
local shopTab = "Armor"
local qm = { Road = false }

local function craftThen(what: string, id: string)
	local res = Net.Ask("Craft", { What = what, Id = id })
	if res and res.Ok then
		close()
		if Panels.Hooks.Scenes then Panels.Hooks.Scenes.Craft(res) end
		-- (the scene over: back to the drawer, on the same tab)
		Panels.Open("Workshop")
	else
		Kit.Toast((res and res.Err) or "CAN'T CRAFT", "Red", "Wrench")
	end
end

-- everything one gear kind needs to draw itself
local function gearKind(what: string)
	if what == "Launcher" then
		return {
			Defs = Config.Launchers, Order = Config.LauncherOrder, Cur = "Launcher", Lvl = "LauncherLvl", Owned = "Launchers", Icon = "Launcher", Gain = "+10% CALM",
			Stat = function(d, lvl) return string.format("CALM %.1f   %.2fS   RANGE %d", d.Damage * (1 + Config.LevelBonus * (lvl - 1)), d.Rate, d.Range) end,
		}
	end
	return {
		Defs = Config.Armors, Order = Config.ArmorOrder, Cur = "Armor", Lvl = "ArmorLvl", Owned = "Armors", Icon = "Armor", Gain = "+10% HEALTH",
		Stat = function(d, lvl) return string.format("HEALTH %d", math.floor(d.HP * (1 + Config.LevelBonus * (lvl - 1)))) end,
	}
end

-- where a boss material comes from: "THE PLAINS TITAN IN GIANT PLAINS"
local function sourceOf(mat: string): string
	local m = Config.Materials[mat]
	local b = m and Config.Bosses[m.Boss]
	if not b then return "THE BOSSES" end
	for _, e in ipairs(Config.Eras) do
		if e.Id == b.Era then return "THE " .. b.Name .. " IN " .. e.Name end
	end
	return "THE " .. b.Name
end

local function levelUp(what: string)
	local res = Net.Ask("LevelUp", { What = what })
	if res and res.Ok then
		if Panels.Hooks.Scenes then Panels.Hooks.Scenes.LevelUp(what, res.Level) end
		if res.Free and Panels.Hooks.UpgradeTour then task.delay(1.2, Panels.Hooks.UpgradeTour) end
	else
		Kit.Toast((res and res.Err) or "CAN'T", "Red", "Coin")
	end
end

-- a requirement tile: COINS 15% / REX CLAW 2/2 (lime when you have it, red when you don't)
local function needTile(parent: Instance, x: UDim, w: UDim, label: string, value: string, ok: boolean)
	local f = frame(parent, { Size = UDim2.new(w.Scale, w.Offset, 0, 54), Position = UDim2.new(x.Scale, x.Offset, 0, 0), BackgroundTransparency = 0.1, BackgroundColor3 = C.InkSoft, ZIndex = 27 })
	Kit.Corner(f, 10)
	Kit.Stroke(f, ok and C.Lime or C.Red, 3)
	pixel(f, label, { Size = UDim2.new(1, -8, 0, 12), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 28, MaxSize = 12, Color = ok and C.LimeHi or C.RedHi })
	text(f, value, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0.5, 0, 0, 24), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 28, MaxSize = 20 })
end

-- your gear + LEVEL UP, the next gear + what it needs
local function gearDrawer(content: Frame, what: string)
	local p = Net.Profile
	local g = p.Gear
	local k = gearKind(what)
	local cur = k.Defs[g[k.Cur]]
	local lvl = g[k.Lvl] or 1
	local first
	-- YOUR GEAR
	local _, tc = Kit.Card(content, { Size = UDim2.new(1, 0, 0, 214), Position = UDim2.fromOffset(0, 76), Color = "Forest", Border = C.YellowHi, ZIndex = 23 })
	local box = frame(tc, { Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.ForestHi, ZIndex = 25 })
	Kit.Corner(box, 14)
	Kit.Stroke(box, C.Ink, 3)
	Kit.Icon(box, k.Icon, { Size = UDim2.fromOffset(76, 76), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27, Rotation = -6 })
	text(tc, cur.Name, { Size = UDim2.new(1, -110, 0, 28), Position = UDim2.fromOffset(102, 10), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 26, Color = C.YellowHi })
	pixel(tc, k.Stat(cur, lvl), { Size = UDim2.new(1, -110, 0, 14), Position = UDim2.fromOffset(102, 42), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 14 })
	pixel(tc, "LV " .. lvl .. " / " .. Config.MaxLevel, { Size = UDim2.new(1, -110, 0, 14), Position = UDim2.fromOffset(102, 66), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 14, Color = C.LimeHi })
	local set = Kit.Segments(tc, Config.MaxLevel, { Size = UDim2.new(1, -12, 0, 14), Position = UDim2.fromOffset(6, 100), ZIndex = 27 })
	set(lvl / Config.MaxLevel, C.Lime)
	if lvl < Config.MaxLevel then
		local price = Config.LevelPrice(cur.Order, lvl)
		local free = not (p.Flags and p.Flags.FreeUpgradeUsed) and ((p.Stats and p.Stats.Runs) or 0) >= 1
		local ok = free or (p.Coins or 0) >= price
		local _, hit = Kit.Button(tc, { Text = free and "LEVEL UP  FREE!" or ("LEVEL UP  " .. Config.FormatNumber(price)), Icon = "Coin", IconSize = 0.8, TextLeft = 0.2, Color = ok and "Lime" or "Grey", Disabled = not ok, Shine = ok, Size = UDim2.new(1, -12, 0, 60), Position = UDim2.fromOffset(6, 126), ZIndex = 27, MaxText = 26, OnClick = function() levelUp(what) end })
		first = hit
		pixel(tc, ok and (k.Gain .. " A LEVEL") or ("NEED " .. Config.FormatNumber(price - (p.Coins or 0)) .. " MORE"), { Size = UDim2.new(1, -12, 0, 14), Position = UDim2.new(0.5, 0, 0, 191), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 14, Color = ok and C.Muted or C.OrangeHi })
	else
		text(tc, "MAX LEVEL!", { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 132), ZIndex = 27, MaxSize = 28, Color = C.LimeHi })
		pixel(tc, "CRAFT THE NEXT ONE BELOW", { Size = UDim2.new(1, -12, 0, 14), Position = UDim2.fromOffset(6, 170), ZIndex = 27, MaxSize = 14, Color = C.Muted })
	end
	-- NEXT GEAR: the first one along the road you don't have yet
	local nextId
	for _, id in ipairs(k.Order) do
		if not (g[k.Owned] and g[k.Owned][id]) then nextId = id break end
	end
	local _, nc = Kit.Card(content, { Size = UDim2.new(1, 0, 0, 230), Position = UDim2.fromOffset(0, 302), Color = "Forest", Border = C.Orange, ZIndex = 23 })
	if not nextId then
		text(nc, "YOU HAVE THEM ALL!", { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0.5, 0, 0, 70), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 28, Color = C.YellowHi })
		pixel(nc, "NOW MAX THEIR LEVELS", { Size = UDim2.new(1, -16, 0, 14), Position = UDim2.new(0.5, 0, 0, 112), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 14, Color = C.Muted })
	else
		local d = k.Defs[nextId]
		local cost = d.Craft or { Coins = d.Price or 0, Mats = d.Mats }
		local needs = {}
		if (cost.Coins or 0) > 0 then
			local have = p.Coins or 0
			table.insert(needs, { "COINS", have >= cost.Coins and "READY" or (math.floor(math.min(0.99, have / cost.Coins) * 100) .. "%"), have >= cost.Coins })
		end
		local missing
		for _, mat in ipairs({ "QueenClaw", "MatriarchScale", "TideScale", "ScytheClaw", "FrostPlume", "DawnScute" }) do
			local n = cost.Mats and cost.Mats[mat]
			if n then
				local have = (p.Materials and p.Materials[mat]) or 0
				table.insert(needs, { Config.Materials[mat].Name, have .. "/" .. n, have >= n })
				if have < n and not missing then missing = mat end
			end
		end
		local ready = 0
		for _, n in ipairs(needs) do if n[3] then ready += 1 end end
		pixel(nc, "NEXT GEAR", { Size = UDim2.fromOffset(170, 13), Position = UDim2.fromOffset(10, 8), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 13, Color = C.OrangeHi })
		pixel(nc, ready .. "/" .. #needs .. " READY", { Size = UDim2.fromOffset(170, 13), Position = UDim2.new(1, -10, 0, 8), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 27, MaxSize = 13, Color = ready == #needs and C.LimeHi or C.YellowHi })
		text(nc, d.Name, { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 26), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 24, Color = C.YellowHi })
		pixel(nc, d.Perk or k.Stat(d, 1), { Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 56), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 14, Color = C.Cream })
		local row = frame(nc, { Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, 78), ZIndex = 26 })
		local n = math.max(1, #needs)
		for i, t in ipairs(needs) do
			needTile(row, UDim.new((i - 1) / n, i > 1 and 3 or 0), UDim.new(1 / n, -6), t[1], t[2], t[3])
		end
		local can = canAfford(cost)
		local _, hit = Kit.Button(nc, { Text = can and ((d.Craft and "CRAFT " or "BUY ") .. d.Name) or "WHERE DO I GET THESE?", Icon = can and "Hammer" or "Map", IconSize = 0.8, TextLeft = 0.18, Color = "Orange", Shine = can, Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, 150), ZIndex = 27, MaxText = 22, OnClick = function()
			if can then craftThen(what, nextId) return end
			if missing then
				Kit.Toast(Config.Materials[missing].Name .. ": BEAT " .. sourceOf(missing), "Orange", "Map")
				close()
				Panels.Open("Eras")
			else
				Kit.Toast("COINS: HUNT EGGS, HATCH EARNERS", "Yellow", "Coin")
			end
		end })
		first = first or hit
	end
	-- the whole road
	local _, link = Kit.Button(content, { Text = "SEE ALL " .. #k.Order .. " " .. (what == "Launcher" and "LAUNCHERS" or "ARMORS"), Color = "Slate", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40), ZIndex = 24, MaxText = 18, Lip = 3, OnClick = function()
		qm.Road = true
		Panels.Refresh()
	end })
	first = first or link
	return first
end

-- SEE ALL: every tier as a road down the drawer (owned ones lit, the next one orange, the rest locked)
local function gearRoad(content: Frame, what: string)
	local g = Net.Profile.Gear
	local k = gearKind(what)
	local first
	local _, back = Kit.Button(content, { Text = "BACK", Color = "Slate", Size = UDim2.fromOffset(110, 34), Position = UDim2.fromOffset(0, 74), ZIndex = 24, MaxText = 16, Lip = 3, OnClick = function()
		qm.Road = false
		Panels.Refresh()
	end })
	first = back
	pixel(content, "A BOSS UNLOCKS EACH", { Size = UDim2.new(1, -120, 0, 13), Position = UDim2.new(1, 0, 0, 85), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 24, MaxSize = 13, Color = C.Muted })
	local top, ROW = 118, 66
	local lit = 0
	for i, id in ipairs(k.Order) do if g[k.Owned] and g[k.Owned][id] then lit = i end end
	-- the road behind the badges
	local track = frame(content, { Size = UDim2.fromOffset(8, (#k.Order - 1) * ROW), Position = UDim2.fromOffset(27, top + 29), BackgroundColor3 = C.InkSoft, ZIndex = 23 })
	Kit.Corner(track, 4)
	local done = frame(track, { Size = UDim2.new(1, 0, math.clamp((lit - 1) / math.max(1, #k.Order - 1), 0, 1), 0), BackgroundColor3 = C.Lime, ZIndex = 24 })
	Kit.Corner(done, 4)
	local nextShown = false
	for i, id in ipairs(k.Order) do
		local d = k.Defs[id]
		local owned = g[k.Owned] and g[k.Owned][id]
		local equipped = g[k.Cur] == id
		local isNext = not owned and not nextShown
		if isNext then nextShown = true end
		local y = top + (i - 1) * ROW
		local badge = frame(content, { Size = UDim2.fromOffset(62, 58), Position = UDim2.fromOffset(0, y), BackgroundColor3 = owned and (d.Color or C.Yellow) or (isNext and C.OrangeLo or C.ForestHi), ZIndex = 25 })
		Kit.Corner(badge, 14)
		Kit.Stroke(badge, equipped and C.LimeHi or C.Ink, equipped and 4 or 3)
		if owned or isNext then
			text(badge, tostring(i), { Size = UDim2.fromScale(1, 0.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27, MaxSize = 26 })
		else
			Kit.Icon(badge, "Lock", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27 })
		end
		text(content, d.Name, { Size = UDim2.new(1, -190, 0, 22), Position = UDim2.fromOffset(74, y + 8), Align = Enum.TextXAlignment.Left, ZIndex = 25, MaxSize = 20, Color = owned and C.Cream or (isNext and C.YellowHi or C.Muted) })
		local sub = d.Perk or d.Tier or k.Stat(d, 1)
		if not owned and not isNext then
			-- a locked tier: the boss whose drop it's built round (its own material is the one it needs most of)
			local best, most = nil, 0
			for mat, cnt in pairs((d.Craft and d.Craft.Mats) or {}) do if cnt > most then best, most = mat, cnt end end
			local b = best and Config.Materials[best] and Config.Bosses[Config.Materials[best].Boss]
			if b then sub = "FROM THE " .. b.Name end
		end
		pixel(content, sub or "", { Size = UDim2.new(1, -190, 0, 12), Position = UDim2.fromOffset(74, y + 34), Align = Enum.TextXAlignment.Left, ZIndex = 25, MaxSize = 12, Color = C.Muted })
		if equipped then
			pixel(content, "EQUIPPED", { Size = UDim2.fromOffset(104, 10), Position = UDim2.new(1, 0, 0, y + 24), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 25, MaxSize = 10, Color = C.LimeHi })
		elseif owned then
			Kit.Button(content, { Text = "EQUIP", Color = "Blue", Size = UDim2.fromOffset(104, 44), Position = UDim2.new(1, 0, 0, y + 7), AnchorPoint = Vector2.new(1, 0), ZIndex = 25, MaxText = 18, Lip = 3, OnClick = function()
				ask("EquipGear", { What = what, Id = id }, d.Name .. " EQUIPPED", "Blue", k.Icon)
			end })
		elseif isNext then
			local cost = d.Craft or { Coins = d.Price or 0, Mats = d.Mats }
			local can = canAfford(cost)
			Kit.Button(content, { Text = can and "CRAFT" or "NEXT", Icon = can and "Hammer" or nil, IconSize = 0.8, Color = can and "Orange" or "Grey", Disabled = not can, Shine = can, Size = UDim2.fromOffset(104, 44), Position = UDim2.new(1, 0, 0, y + 7), AnchorPoint = Vector2.new(1, 0), ZIndex = 25, MaxText = 18, Lip = 3, OnClick = function()
				craftThen(what, id)
			end })
		end
	end
	return first
end

-- a compact list row for the drawer: icon, title, status; cost chips under it; the button top-right
local function drawerRow(list: Frame, icon: string, title: string, status: string, cost, button)
	local r, rc = Kit.Card(list, { Size = UDim2.new(1, 0, 0, 96), ZIndex = 24 })
	Kit.Icon(rc, icon, { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(4, 6), ZIndex = 27 })
	text(rc, title, { Size = UDim2.new(1, -196, 0, 20), Position = UDim2.fromOffset(68, 8), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 18 })
	pixel(rc, status, { Size = UDim2.new(1, -76, 0, 13), Position = UDim2.fromOffset(68, 33), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 13, Color = C.Muted })
	if cost then costChips(rc, cost, 68, 54, 27) end
	local hit
	if button then
		local _, h = Kit.Button(rc, { Text = button.Text, Icon = button.Icon, IconSize = 0.8, TextLeft = button.Icon and 0.32 or nil, Color = button.Color, Disabled = button.Disabled, Shine = button.Shine, Size = UDim2.fromOffset(button.W or 116, 38), Position = UDim2.new(1, -6, 0, 4), AnchorPoint = Vector2.new(1, 0), ZIndex = 27, MaxText = 16, Lip = 3, OnClick = button.OnClick })
		hit = h
	end
	return r, rc, hit
end

local function listIn(content: Frame): Frame
	local list = frame(content, { Size = UDim2.new(1, 0, 1, -78), Position = UDim2.fromOffset(0, 76), ZIndex = 23 })
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = list
	return list
end

local function gadgetsTab(content: Frame)
	local g = Net.Profile.Gear
	local list = listIn(content)
	local first
	pixel(list, "SLOTS: " .. ((g.Gadgets[1] or "") ~= "" and Config.Gadgets[g.Gadgets[1]].Name or "-") .. "  +  " .. ((g.Gadgets[2] or "") ~= "" and Config.Gadgets[g.Gadgets[2]].Name or "-"), { Size = UDim2.new(1, 0, 0, 12), ZIndex = 26, MaxSize = 11, Color = C.YellowHi })
	for i, id in ipairs(Config.GadgetOrder) do
		local d = Config.Gadgets[id]
		local owned = g.GadgetsOwned and g.GadgetsOwned[id]
		local cost = d.Craft or { Coins = d.Price or 0 }
		local can = canAfford(cost)
		local r, rc, hit = drawerRow(list, owned and ("Gadget_" .. id) or "Lock", d.Name, d.Desc .. "  (" .. d.Cooldown .. "S)", not owned and cost or nil, not owned and {
			Text = d.Craft and "CRAFT" or "BUY", Icon = "Wrench", Color = can and "Orange" or "Grey", Disabled = not can, Shine = can, OnClick = function()
				if d.Craft then craftThen("Gadget", id) else ask("BuyBase", { What = "GadgetBait" }, d.Name .. " READY!", "Orange", "Bolt") end
			end,
		} or nil)
		r.LayoutOrder = i
		first = first or hit
		if owned then
			for s = 1, Config.GadgetSlots do
				local on = g.Gadgets[s] == id
				local _, h = Kit.Button(rc, { Text = on and ("IN SLOT " .. s) or ("SLOT " .. s), Color = on and "Lime" or "Blue", Size = UDim2.fromOffset(110, 34), Position = UDim2.fromOffset(68 + (s - 1) * 118, 52), ZIndex = 27, MaxText = 14, Lip = 3, OnClick = function()
					ask("EquipGear", { What = "Gadget", Id = on and "" or id, Slot = s })
				end })
				first = first or h
			end
		end
	end
	return first
end

local QM_TABS = { { "Armor", "ARMOR", "Armor" }, { "Gadgets", "GADGETS", "Gadget_Flare" } }
local function buildWorkshop(content: Frame, _header: Frame)
	local p = Net.Profile
	if not p then return nil end
	if shopTab ~= "Armor" and shopTab ~= "Gadgets" then shopTab = "Armor" end
	-- two big tabs across the top of the drawer (icon + word: with only two there's room for both)
	local n = #QM_TABS
	local firstTab
	for i, t in ipairs(QM_TABS) do
		local on = t[1] == shopTab
		local _, hit = Kit.Button(content, { Text = t[2], Icon = t[3], IconSize = 0.85, TextLeft = 0.34, Color = on and "Yellow" or "Slate", Size = UDim2.new(1 / n, -4, 0, 64), Position = UDim2.new((i - 1) / n, i > 1 and 4 or 0, 0, 0), ZIndex = 26, Radius = 12, Lip = 4, MaxText = 22, OnClick = function()
			if shopTab ~= t[1] then qm.Road = false end
			shopTab = t[1]
			Panels.Refresh()
		end })
		if on then firstTab = hit end
	end
	local first
	if shopTab == "Gadgets" then first = gadgetsTab(content)
	elseif qm.Road then first = gearRoad(content, shopTab)
	else first = gearDrawer(content, shopTab) end
	return first or firstTab
end

--------------------------------------------------------------------------------
-- SHOP (Robux) — 2026-10-14 (mockups: "Dino Shop Mockups"). Built for a sideways phone first: a left rail of tabs
-- (DEALS / EGGS / BOOSTS / PASSES), big cards, one price button each. DEALS is the starter pack ladder, each pack shown
-- as icon + icon + icon with its honest value (Config.ProductValue). Every paid egg is one tap from SEE ODDS: all
-- outcomes and exact percentages before you buy (Roblox's paid random items rule; Config.EggOdds is what the server rolls).
--------------------------------------------------------------------------------
local shopState = { Tab = nil :: string?, Odds = nil :: { string }?, OddsTitle = "" }
local livePrice = {} :: { [number]: number } -- product / pass id -> its Robux price on Roblox (-1 while asking)
local function priceOf(kind: string, def): number?
	if def.Id and def.Id > 0 then
		local p = livePrice[def.Id]
		if p == nil then
			livePrice[def.Id] = -1
			task.spawn(function()
				local ok, info = pcall(function() return MarketplaceService:GetProductInfo(def.Id, kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product) end)
				if ok and info and info.PriceInRobux then
					livePrice[def.Id] = info.PriceInRobux
					if current and current.Name == "Shop" then Panels.Refresh() end
				end
			end)
		elseif p > 0 then
			return p
		end
	end
	return def.Price
end
local function buy(kind: string, def)
	if not def.Id or def.Id <= 0 then Kit.Toast("COMING SOON!", "Blue", "Star") return end
	if kind == "Pass" then MarketplaceService:PromptGamePassPurchase(player, def.Id) else MarketplaceService:PromptProductPurchase(player, def.Id) end
end
local function priceButton(parent: Instance, kind: string, def, owned: boolean, props)
	local p = priceOf(kind, def)
	local live = def.Id ~= nil and def.Id > 0
	local _, hit = Kit.Button(parent, {
		Text = owned and "OWNED" or (p and ("R$ " .. p) or "SOON"), Color = owned and "Grey" or (live and "Lime" or "Slate"),
		Disabled = owned, Shine = live and not owned, Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex or 27, MaxText = props.MaxText or 22, Lip = 4, OnClick = function() buy(kind, def) end,
	})
	return hit
end
local EGG_TINT = { Premium = "Teal", Rare = "Blue", Epic = "Purple", Legendary = "Yellow" }
local EGG_SHORT = { Premium = "EGG", Rare = "RARE+", Epic = "EPIC+", Legendary = "LEGEND" }
-- one product's contents as { icon, label, colour? }
local function contentsOf(id: string): { { any } }
	local out = {}
	for _, g in ipairs(Config.ProductGrants[id] or {}) do
		if g.Kind == "Egg" then
			local tint = Theme.Swatch[EGG_TINT[g.Egg] or "Teal"][2]
			table.insert(out, { "Egg", (g.Count or 1) > 1 and ("EGG x" .. g.Count) or EGG_SHORT[g.Egg], g.Egg ~= "Premium" and tint or nil })
		elseif g.Kind == "Coins" then table.insert(out, { "Coin", Config.FormatNumber(g.Amount or 0) })
		elseif g.Kind == "Luck" then table.insert(out, { "Star", (g.Minutes or 15) >= 60 and ((g.Minutes // 60) .. " HOUR") or ((g.Minutes or 15) .. " MIN") })
		elseif g.Kind == "Hatch" then table.insert(out, { "Clock", "HATCH x" .. (g.Count or 1) })
		elseif g.Kind == "Slot" then table.insert(out, { "Buddy", "+1 PAL" }) end
	end
	return out
end
local function eggKindsOf(id: string): { string }
	local kinds, seen = {}, {}
	for _, g in ipairs(Config.ProductGrants[id] or {}) do
		if g.Kind == "Egg" and not seen[g.Egg] then seen[g.Egg] = true table.insert(kinds, g.Egg) end
	end
	return kinds
end
local function seeOdds(parent: Instance, id: string, title: string, props)
	local kinds = eggKindsOf(id)
	if #kinds == 0 then return end
	Kit.Button(parent, { Text = "SEE ODDS", Color = "Slate", Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex or 27, MaxText = 14, Lip = 3, OnClick = function()
		shopState.Odds, shopState.OddsTitle = kinds, title
		Panels.Refresh()
	end })
end

local PACKS = { { "StarterPack1", "Blue", { "Egg", "Coin" } }, { "StarterPack2", "Purple", { "Egg", "Egg", "Clock" } }, { "StarterPack3", "Yellow", { "Crown", "Egg", "Buddy" } } }
local function dealsTab(area: Frame)
	local p = Net.Profile
	local packs = (p and p.Flags and p.Flags.Packs) or {}
	pixel(area, "ONE OF EACH - THE BEST VALUE IN THE GAME", { Size = UDim2.new(1, -8, 0, 11), Position = UDim2.fromOffset(4, 0), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 11, Color = C.Muted })
	local first
	local n = #PACKS
	for i, pk in ipairs(PACKS) do
		local id, color, icons = pk[1], pk[2], pk[3]
		local def = Config.Products[id]
		local owned = packs[id] == true
		local sw = Theme.Swatch[color]
		local card, cc = Kit.Card(area, { Size = UDim2.new(1 / n, -8, 1, -22), Position = UDim2.new((i - 1) / n, 4, 0, 18), Border = i == 2 and C.YellowHi or nil, ZIndex = 24 })
		local _ = card
		local band = frame(cc, { Size = UDim2.new(1, -8, 0, 92), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = sw[1], ZIndex = 25 })
		Kit.Corner(band, 10)
		Kit.Gradient(band, sw[2], sw[3])
		Kit.Pattern(band, Color3.new(1, 1, 1), 26, 0.85, Vector2.new(240, 92))
		pixel(band, "STEP " .. i, { Size = UDim2.fromOffset(60, 10), Position = UDim2.fromOffset(8, 8), Align = Enum.TextXAlignment.Left, ZIndex = 28, MaxSize = 10, Color = C.Cream })
		if i == 2 then pixel(band, "MOST POPULAR", { Size = UDim2.fromOffset(120, 10), Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 28, MaxSize = 10, Color = C.YellowHi }) end
		for k, ic in ipairs(icons) do
			local big = k == 1 or (#icons == 3 and k == 2)
			local s = big and 70 or 52
			local x = 0.5 + (k - (#icons + 1) / 2) * 0.26
			Kit.Icon(band, ic, { Size = UDim2.fromOffset(s, s), Position = UDim2.new(x, 0, 0.5, big and 4 or 14), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28 + (big and 1 or 0), Rotation = k == 1 and -8 or 6 })
		end
		text(cc, def.Name, { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(10, 102), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 22 })
		-- what's inside: icon + icon + icon
		local items = contentsOf(id)
		local row = frame(cc, { Size = UDim2.new(1, -12, 0, 58), Position = UDim2.fromOffset(6, 130), ZIndex = 26 })
		local m = #items
		for k, it in ipairs(items) do
			local cx = (k - 0.5) / m
			Kit.Icon(row, it[1], { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(cx, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 28 })
			pixel(row, it[2], { Size = UDim2.new(1 / m, -2, 0, 10), Position = UDim2.new(cx, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 28, MaxSize = 10, Color = it[3] or C.Cream })
			if k < m then text(row, "+", { Size = UDim2.fromOffset(16, 20), Position = UDim2.new(k / m, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 28, MaxSize = 20, Color = C.YellowHi }) end
		end
		local value = Config.ProductValue(id)
		local mult = def.Price and def.Price > 0 and math.floor(value / def.Price * 10) / 10 or 0
		if mult >= 1.5 and not owned then
			pixel(cc, math.floor(mult) .. "X VALUE", { Size = UDim2.fromOffset(90, 11), Position = UDim2.new(0, 10, 1, -78), ZIndex = 27, MaxSize = 11, Color = C.YellowHi, Align = Enum.TextXAlignment.Left })
		end
		seeOdds(cc, id, def.Name, { Size = UDim2.fromOffset(104, 30), Position = UDim2.new(1, -8, 1, -64), AnchorPoint = Vector2.new(1, 1) })
		local hit = priceButton(cc, "Product", def, owned, { Size = UDim2.new(1, -16, 0, 48), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1) })
		if not owned and not first then first = hit end
	end
	return first
end

local EGG_ROWS = {
	{ "PremiumEgg", "Premium" }, { "PremiumEgg3", "Premium" }, { "PremiumEgg10", "Premium" },
	{ "RareEgg", "Rare" }, { "EpicEgg", "Epic" }, { "LegendaryEgg", "Legendary" },
}
local function eggsTab(area: Frame)
	pixel(area, "STRAIGHT TO YOUR BAG - ANY DINO YOU'VE UNLOCKED", { Size = UDim2.new(1, -8, 0, 11), Position = UDim2.fromOffset(4, 0), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 11, Color = C.Muted })
	local w = (area.AbsoluteSize.X > 0 and area.AbsoluteSize.X or 728)
	local grid = scroller(area, Vector2.new(math.floor((w - 36) / 3), 132), 8, UDim2.new(1, 0, 1, -16), UDim2.fromOffset(0, 16))
	local first
	local single = Config.Products.PremiumEgg.Price or 49
	for i, row in ipairs(EGG_ROWS) do
		local id, kind = row[1], row[2]
		local def = Config.Products[id]
		local sw = Theme.Swatch[EGG_TINT[kind]]
		local count = (Config.ProductGrants[id][1] and Config.ProductGrants[id][1].Count) or 1
		local card, cc = Kit.Card(grid, { Size = UDim2.fromScale(1, 1), Border = (id == "PremiumEgg10" or kind == "Legendary") and C.YellowHi or sw[2], ZIndex = 24 })
		card.LayoutOrder = i
		local box = frame(cc, { Size = UDim2.fromOffset(76, 76), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = sw[3], ZIndex = 25 })
		Kit.Corner(box, 12)
		Kit.Gradient(box, sw[2], sw[3])
		if count >= 10 then
			Kit.Icon(box, "Chest", { Size = UDim2.fromOffset(68, 68), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27 })
		elseif count > 1 then
			Kit.Icon(box, "Egg", { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0.35, 0, 0.42, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27, Rotation = -8 })
			Kit.Icon(box, "Egg", { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0.66, 0, 0.6, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28, Rotation = 8 })
		else
			Kit.Icon(box, "Egg", { Size = UDim2.fromOffset(66, 66), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27 })
		end
		text(cc, def.Name, { Size = UDim2.new(1, -96, 0, 20), Position = UDim2.fromOffset(90, 8), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 18, Color = kind == "Premium" and C.Cream or sw[2] })
		-- an honest tag: what a bundle saves against single eggs, or the floor a guaranteed egg promises
		local tag = nil
		if count > 1 and def.Price then
			local save = math.floor((1 - def.Price / (single * count)) * 100 + 0.5)
			tag = (id == "PremiumEgg10" and "BEST VALUE - " or "") .. "SAVE " .. save .. "%"
		elseif kind ~= "Premium" then
			tag = (kind == "Legendary" and "LEGENDARY OR BETTER" or (string.upper(kind) .. " OR BETTER"))
		end
		if tag then pixel(cc, tag, { Size = UDim2.new(1, -96, 0, 10), Position = UDim2.fromOffset(90, 32), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 10, Color = C.YellowHi }) end
		seeOdds(cc, id, def.Name, { Size = UDim2.fromOffset(96, 28), Position = UDim2.new(0, 90, 0, 48) })
		local hit = priceButton(cc, "Product", def, false, { Size = UDim2.new(1, -98, 0, 40), Position = UDim2.new(1, -6, 1, -6), AnchorPoint = Vector2.new(1, 1), MaxText = 18 })
		first = first or hit
	end
	return first
end

-- a nest egg's rarity chance at a given luck (for the luck boost's honest numbers)
local function nestChance(luck: number, rarity: string): number
	local w = Config.RarityWeights(luck)
	local sum = 0
	for _, r in ipairs(Config.RarityOrder) do sum += w[r] end
	return w[rarity] / sum * 100
end
local BOOST_ROWS = {
	{ "LuckBoost", "Star" }, { "LuckBoost60", "Star" }, { "InstantHatch", "Clock" }, { "InstantHatch5", "Clock" }, { "CompanionSlot", "Buddy" },
}
local function boostsTab(area: Frame)
	local w = (area.AbsoluteSize.X > 0 and area.AbsoluteSize.X or 728)
	local grid = scroller(area, Vector2.new(math.floor((w - 28) / 2), 92), 8)
	local first
	local luckLine = string.format("NEST EGGS: LEGENDARY %.2f%% > %.2f%%", nestChance(0, "Legendary"), nestChance(1.5, "Legendary"))
	for i, row in ipairs(BOOST_ROWS) do
		local id, icon = row[1], row[2]
		local def = Config.Products[id]
		local card, cc = Kit.Card(grid, { Size = UDim2.fromScale(1, 1), Border = id == "LuckBoost60" and C.YellowHi or nil, ZIndex = 24 })
		card.LayoutOrder = i
		Kit.Icon(cc, icon, { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 27 })
		text(cc, def.Name, { Size = UDim2.new(1, -190, 0, 20), Position = UDim2.fromOffset(80, 14), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 18 })
		local sub
		if id == "LuckBoost" then sub = luckLine
		elseif id == "LuckBoost60" then sub = "SAVE " .. math.floor((1 - (def.Price or 149) / (4 * (Config.Products.LuckBoost.Price or 49))) * 100 + 0.5) .. "% - " .. luckLine
		elseif id == "InstantHatch" then sub = "YOUR NEXT EGG, RIGHT NOW"
		elseif id == "InstantHatch5" then sub = "SAVE " .. math.floor((1 - (def.Price or 99) / (5 * (Config.Products.InstantHatch.Price or 25))) * 100 + 0.5) .. "% - FIVE EGGS, RIGHT NOW"
		else sub = "ONE MORE DINO FOLLOWS AND FIGHTS WITH YOU" end
		pixel(cc, sub, { Size = UDim2.new(1, -190, 0, 10), Position = UDim2.fromOffset(80, 44), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 10, Color = C.Muted })
		local hit = priceButton(cc, "Product", def, false, { Size = UDim2.fromOffset(100, 46), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), MaxText = 18 })
		first = first or hit
	end
	return first
end

local PASS_ROWS = {
	{ "DoubleMoney", "Coin", "EVERY DINO EARNS DOUBLE, FOREVER" },
	{ "MoreIncubators", "Incubator", "TWO EXTRA NESTS AT YOUR BASE" },
	{ "VipRack", "Rack", "+2 EGGS ON YOUR ROOF RACK" },
	{ "AutoCollect", "Gift", "MONEY GOES STRAIGHT TO YOUR WALLET" },
}
local function passesTab(area: Frame)
	local w = (area.AbsoluteSize.X > 0 and area.AbsoluteSize.X or 728)
	local grid = scroller(area, Vector2.new(math.floor((w - 28) / 2), 92), 8)
	local first
	for i, row in ipairs(PASS_ROWS) do
		local def = Config.Passes[row[1]]
		local owned = player:GetAttribute("Pass_" .. row[1]) == true
		local card, cc = Kit.Card(grid, { Size = UDim2.fromScale(1, 1), ZIndex = 24 })
		card.LayoutOrder = i
		Kit.Icon(cc, row[2], { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 27 })
		text(cc, def.Name, { Size = UDim2.new(1, -190, 0, 20), Position = UDim2.fromOffset(80, 14), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 18 })
		pixel(cc, row[3], { Size = UDim2.new(1, -190, 0, 10), Position = UDim2.fromOffset(80, 44), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 10, Color = C.Muted })
		local hit = priceButton(cc, "Pass", def, owned, { Size = UDim2.fromOffset(100, 46), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), MaxText = 18 })
		if not owned then first = first or hit end
	end
	return first
end

-- SEE ODDS: every outcome and its exact chance, over the shop
local function oddsOverlay(content: Frame)
	local kinds = shopState.Odds
	if not kinds then return nil end
	local p = Net.Profile
	local dim = Instance.new("TextButton")
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.35
	dim.Size = UDim2.new(1, 20, 1, 20)
	dim.Position = UDim2.fromOffset(-10, -10)
	dim.ZIndex = 60
	dim.Parent = content
	local rows = #kinds
	local _, cc = Kit.Card(content, { Size = UDim2.new(0, 560, 0, 92 + rows * 66), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = "Forest", Border = C.YellowHi, ZIndex = 62 })
	text(cc, shopState.OddsTitle .. " ODDS", { Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(12, 10), Align = Enum.TextXAlignment.Left, ZIndex = 66, MaxSize = 22 })
	local _, closeHit = Kit.Button(cc, { Glyph = "X", Color = "Red", Size = UDim2.fromOffset(48, 42), Position = UDim2.new(1, -8, 0, 6), AnchorPoint = Vector2.new(1, 0), ZIndex = 66, Lip = 4, OnClick = function()
		shopState.Odds = nil
		Panels.Refresh()
	end })
	for k, kind in ipairs(kinds) do
		local y = 44 + (k - 1) * 66
		local def = Config.ShopEggs[kind]
		pixel(cc, rows > 1 and (def.Name .. ":") or "EACH EGG:", { Size = UDim2.new(1, -24, 0, 10), Position = UDim2.fromOffset(12, y), Align = Enum.TextXAlignment.Left, ZIndex = 66, MaxSize = 10, Color = C.YellowHi })
		local odds = Config.EggOdds(kind)
		local cols = #odds
		for i, o in ipairs(odds) do
			local r = Config.Rarity[o[1]]
			local span = (1 - 24 / 560) / cols
			local cell = frame(cc, { Size = UDim2.new(span, -6, 0, 40), Position = UDim2.new((i - 1) * span, 12, 0, y + 14), BackgroundColor3 = C.ForestHi, ZIndex = 64 })
			Kit.Corner(cell, 8)
			Kit.Stroke(cell, r.Color, 2)
			pixel(cell, r.Name, { Size = UDim2.new(1, -6, 0, 8), Position = UDim2.new(0.5, 0, 0, 5), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 66, MaxSize = 8, Color = r.Color })
			text(cell, string.format("%.2f%%", o[2]), { Size = UDim2.new(1, -6, 0, 18), Position = UDim2.new(0.5, 0, 0, 17), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 66, MaxSize = 18 })
		end
	end
	local pool = Config.ShopEggSpecies(p and p.Unlocked or {})
	pixel(cc, string.format("DINO: ONE OF YOUR %d UNLOCKED SPECIES - %.2f%% EACH. LUCK BOOSTS DON'T CHANGE SHOP EGGS", #pool, 100 / #pool), { Size = UDim2.new(1, -24, 0, 10), Position = UDim2.new(0, 12, 1, -22), Align = Enum.TextXAlignment.Left, ZIndex = 66, MaxSize = 10, Color = C.Muted })
	return closeHit
end

local SHOP_TABS = { { "Deals", "DEALS", "Chest" }, { "Eggs", "EGGS", "Egg" }, { "Boosts", "BOOSTS", "Star" }, { "Passes", "PASSES", "Gem" } }
local function buildShop(content: Frame)
	local p = Net.Profile
	-- open on DEALS while there's a starter pack left to buy, else EGGS
	if not shopState.Tab then
		local packs = (p and p.Flags and p.Flags.Packs) or {}
		shopState.Tab = (packs.StarterPack1 and packs.StarterPack2 and packs.StarterPack3) and "Eggs" or "Deals"
	end
	local rail = frame(content, { Size = UDim2.new(0, 84, 1, 0), ZIndex = 24 })
	local firstTab
	for i, t in ipairs(SHOP_TABS) do
		local on = shopState.Tab == t[1]
		local _, hit = Kit.Button(rail, { Text = t[2], Icon = t[3], IconSize = 0.62, Stack = true, LabelPx = 9, Color = on and "Yellow" or "Slate", Size = UDim2.new(1, -6, 0, 70), Position = UDim2.fromOffset(0, (i - 1) * 78), ZIndex = 26, Radius = 12, Lip = 4, OnClick = function()
			shopState.Tab = t[1]
			shopState.Odds = nil
			Panels.Refresh()
		end })
		if on then firstTab = hit end
	end
	local area = frame(content, { Size = UDim2.new(1, -92, 1, 0), Position = UDim2.fromOffset(92, 0), ZIndex = 23 })
	local first
	if shopState.Tab == "Eggs" then first = eggsTab(area)
	elseif shopState.Tab == "Boosts" then first = boostsTab(area)
	elseif shopState.Tab == "Passes" then first = passesTab(area)
	else first = dealsTab(area) end
	local closeOdds = oddsOverlay(content)
	return closeOdds or first or firstTab
end

--------------------------------------------------------------------------------
-- ERAS
--------------------------------------------------------------------------------
local function buildEras(content: Frame)
	local p = Net.Profile
	if not p then return end
	local grid = scroller(content, Vector2.new(820, 92), 8)
	local rows, first = {}, nil
	for i, era in ipairs(Config.Eras) do
		local unlocked = p.Unlocked and p.Unlocked[era.Id]
		local selected = p.Era == era.Id
		local row, rc = Kit.Card(grid, { Size = UDim2.fromScale(1, 1), Border = selected and C.LimeHi or (unlocked and era.Color or nil), Color = era.Built and "Card" or "Forest", ZIndex = 24 })
		row.LayoutOrder = i
		local bubble = frame(rc, { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 0, BackgroundColor3 = era.Built and era.Color or C.Grey, ZIndex = 26 })
		Kit.Corner(bubble, 35)
		Kit.Stroke(bubble, C.Ink, 3)
		local boss = era.Boss and Config.Bosses[era.Boss]
		Kit.Icon(bubble, unlocked and ("Era_" .. era.Id) or "Lock", { Size = UDim2.fromScale(1.2, 1.2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28 })
		text(rc, era.Name, { Size = UDim2.new(0.42, 0, 0, 26), Position = UDim2.fromOffset(92, 10), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 26 })
		pixel(rc, era.Year .. (boss and ("  -  BOSS: " .. boss.Name) or ""), { Size = UDim2.new(0.5, 0, 0, 10), Position = UDim2.fromOffset(92, 44), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 10, Color = C.Muted })
		if not era.Built then
			pixel(rc, "COMING SOON", { Size = UDim2.fromOffset(200, 12), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 27, MaxSize = 12, Color = C.Muted })
		elseif unlocked then
			if selected then
				pixel(rc, "TIME GATE SET", { Size = UDim2.fromOffset(200, 12), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 27, MaxSize = 12, Color = C.LimeHi })
			else
				local _, hit = Kit.Button(rc, { Text = "SET GATE", Icon = "Gate", IconSize = 0.9, TextLeft = 0.32, Color = "Lime", Size = UDim2.fromOffset(180, 52), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 27, MaxText = 20, OnClick = function()
					ask("SetEra", { Era = era.Id }, "TIME GATE SET: " .. era.Name, "Teal", "Gate")
				end })
				first = first or hit
			end
		else
			-- locked: three clear states (2026-10-12, "make it obvious when you can and can't"):
			--   boss not beaten  -> no button at all: the boss's crown and "BEAT THE <BOSS>" in red
			--   saving up        -> a coin bar filling toward the price, a grey locked button
			--   ready            -> a big gold OPEN! button that wiggles, an arrow at it, the row glows
			local u = era.Unlock or {}
			local needBoss = u.Boss and not (p.Bosses and p.Bosses[u.Boss] and (p.Bosses[u.Boss].Best or 0) >= 1)
			local cost = { Coins = u.Coins or 0 }
			local can = not needBoss and canAfford(cost)
			if needBoss then
				Kit.Icon(rc, "Crown", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -230, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 27, Rotation = -8 })
				text(rc, "BEAT THE " .. Config.Bosses[u.Boss].Name, { Size = UDim2.fromOffset(180, 22), Position = UDim2.new(1, -182, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 20, Color = C.RedHi })
			elseif not can then
				local have = math.min(p.Coins or 0, cost.Coins)
				local bar = frame(rc, { Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(92, 62), BackgroundTransparency = 0, BackgroundColor3 = C.InkSoft, ZIndex = 27 })
				Kit.Corner(bar, 11)
				Kit.Stroke(bar, C.Ink, 3)
				local fill = frame(bar, { Size = UDim2.fromScale(math.clamp(have / math.max(1, cost.Coins), 0.04, 1), 1), BackgroundTransparency = 0, BackgroundColor3 = C.Lime, ZIndex = 28 })
				Kit.Corner(fill, 11)
				Kit.Icon(bar, "Coin", { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(0, -8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 30 })
				pixel(bar, Config.FormatNumber(have) .. " / " .. Config.FormatNumber(cost.Coins), { Size = UDim2.new(1, -40, 0, 10), Position = UDim2.new(0.5, 10, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 30, MaxSize = 10 })
				Kit.Button(rc, { Text = "OPEN", Icon = "Lock", IconSize = 0.9, TextLeft = 0.34, Color = "Grey", Disabled = true, Size = UDim2.fromOffset(170, 52), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 27, MaxText = 20 })
			else
				costChips(rc, cost, 92, 60, 27)
				local btn, hit = Kit.Button(rc, { Text = "OPEN!", Icon = "Gate", IconSize = 1, TextLeft = 0.34, Color = "Yellow", Size = UDim2.fromOffset(200, 60), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 27, MaxText = 24, Shine = true, OnClick = function()
					ask("UnlockEra", { Era = era.Id }, era.Name .. " IS OPEN!", "Gold", "Gate")
				end })
				first = hit
				local arrow = Kit.Glyph(rc, "Chevron", { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -226, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.YellowHi })
				task.spawn(function()
					while btn.Parent do
						local t = os.clock()
						btn.Rotation = math.sin(t * 9) * 3 * (math.sin(t * 1.3) > 0 and 1 or 0)
						if arrow then arrow.Position = UDim2.new(1, -232 + math.abs(math.sin(t * 5)) * 10, 0.5, 0) end
						task.wait()
					end
				end)
				local st = row:FindFirstChildWhichIsA("UIStroke", true)
				if st then st.Color = C.YellowHi end
			end
		end
		table.insert(rows, row)
	end
	Kit.Stagger(rows, 0.04, 0.3)
	return first
end

--------------------------------------------------------------------------------
-- QUESTS
--------------------------------------------------------------------------------
local NPC = { Professor = "THE PROFESSOR", Mechanic = "THE ARMORER", EggKeeper = "THE EGG KEEPER", Ranger = "THE RANGER" }
local function buildQuests(content: Frame)
	local p = Net.Profile
	if not p then return end
	local active = (p.Quests and p.Quests.Active) or {}
	pixel(content, "QUESTS ARE OPTIONAL - TALK TO THE CAMP CREW FOR MORE.  UP TO " .. Config.MaxQuests .. " AT ONCE.", { Size = UDim2.new(1, 0, 0, 11), Position = UDim2.fromOffset(0, 2), ZIndex = 26, MaxSize = 11, Color = C.Muted })
	local list = frame(content, { Size = UDim2.new(1, 0, 1, -26), Position = UDim2.fromOffset(0, 24), ZIndex = 23 })
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 10)
	lay.Parent = list
	for _, q in ipairs(active) do
		local done = (q.Progress or 0) >= q.Goal.Count
		local row, rc = Kit.Card(list, { Size = UDim2.new(1, 0, 0, 92), Color = done and "Lime" or "Card", ZIndex = 24 })
		Kit.Icon(rc, done and "Trophy" or "Star", { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 27 })
		text(rc, q.Title, { Size = UDim2.new(0.5, 0, 0, 24), Position = UDim2.fromOffset(86, 10), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 24 })
		pixel(rc, "FROM " .. (NPC[q.Npc] or q.Npc) .. "  -  REWARD " .. Config.FormatNumber(q.Reward and q.Reward.Coins or 0) .. " COINS", { Size = UDim2.new(0.6, 0, 0, 9), Position = UDim2.fromOffset(86, 40), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 9, Color = done and C.Ink or C.Muted })
		local set = Kit.Segments(rc, math.min(q.Goal.Count, 10), { Size = UDim2.new(0.5, 0, 0, 14), Position = UDim2.fromOffset(86, 60), ZIndex = 27 })
		set((q.Progress or 0) / q.Goal.Count, C.Lime)
		if done then
			pixel(rc, "TALK TO " .. (NPC[q.Npc] or ""), { Size = UDim2.fromOffset(220, 12), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 27, MaxSize = 12, Color = C.Ink })
		elseif not q.Story then
			Kit.Button(rc, { Text = "DROP", Color = "Red", Size = UDim2.fromOffset(110, 44), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 27, MaxText = 18, OnClick = function()
				ask("AbandonQuest", { Id = q.Id }, "QUEST DROPPED", "Grey", "Star")
			end })
		end
		local _ = row
	end
	if #active == 0 then pixel(list, "NO QUESTS RIGHT NOW. THE PROFESSOR IS ON THE HQ STEPS!", { Size = UDim2.new(1, 0, 0, 14), ZIndex = 26, MaxSize = 14 }) end
end

--------------------------------------------------------------------------------
-- SETTINGS: options, cutscene gallery, test tools
--------------------------------------------------------------------------------
local settingsTab = "Options"
local confirmReset = false

local function switch(parent, label: string, icon: string, value: boolean, onChange)
	local row, rc = Kit.Card(parent, { Size = UDim2.new(1, -8, 0, 60), ZIndex = 24 })
	Kit.Icon(rc, icon, { Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 27 })
	text(rc, label, { Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.new(0, 64, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 20 })
	local track = frame(rc, { Size = UDim2.fromOffset(84, 40), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 0, BackgroundColor3 = value and C.Lime or C.GreyLo, ZIndex = 27 })
	Kit.Corner(track, 20)
	Kit.Stroke(track, C.Ink, 3)
	local knob = frame(track, { Size = UDim2.fromOffset(32, 32), Position = value and UDim2.new(1, -4, 0.5, 0) or UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(value and 1 or 0, 0.5), BackgroundTransparency = 0, BackgroundColor3 = C.Cream, ZIndex = 28 })
	Kit.Corner(knob, 16)
	Kit.Stroke(knob, C.Ink, 3)
	local state = value
	local hit = hitArea(row, function()
		state = not state
		TweenService:Create(track, TweenInfo.new(0.18), { BackgroundColor3 = state and C.Lime or C.GreyLo }):Play()
		knob.AnchorPoint = Vector2.new(state and 1 or 0, 0.5)
		knob.Position = state and UDim2.new(1, -40, 0.5, 0) or UDim2.new(0, 40, 0.5, 0)
		knob.Size = UDim2.fromOffset(42, 28)
		TweenService:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = state and UDim2.new(1, -4, 0.5, 0) or UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(32, 32) }):Play()
		onChange(state)
	end)
	return row, hit
end

local galleryBusy = false
local function gallery(body: Frame)
	local H = Panels.Hooks
	local grid = scroller(body, Vector2.new(188, 58), 10)
	local function play(fn)
		-- one scene at a time (a double-click on a closing panel ran it twice: a boss preview then recorded Fern
		-- Valley as the zone to come back to), and never from the driver's seat (the crafting scene teleported you
		-- AND the rover; previews fought the driving camera)
		if galleryBusy or require(script.Parent.Cinema).Playing() then return end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local Drive = require(script.Parent.Parent.Drive) -- (lazy: Drive's HUD needs Panels)
		if (Drive.State and Drive.State.Mode ~= "None") or (hum and hum.SeatPart) then
			Kit.Toast("GET OUT OF YOUR ROVER FIRST", "Orange", "Film")
			return
		end
		galleryBusy = true
		close()
		task.delay(0.25, function()
			local ok, err = pcall(fn)
			galleryBusy = false
			if not ok then warn("[Gallery]", err) end
		end)
	end
	local list = {
		{ "COLD OPEN", "Film", "Red", function() if H.ColdOpen then H.ColdOpen() end end }, -- the new player's first minute (Prologue)
		{ "TIME WARP", "Gate", "Teal", function() if H.Warp then H.Warp() end end },
		{ "BAD TIME WARP", "Gate", "Red", function() if H.FakeWarp then H.FakeWarp.Play() end end },
		{ "FERN VALLEY ARRIVAL", "Map", "Lime", function() if H.EraView then H.EraView.Establish("FernValley", true) end end },
		{ "BOSS: TYRANT KING", "Crown", "Orange", function() if H.EraView then H.EraView.PreviewBoss("TyrantKing") end end },
		{ "BOSS KNOCKOUT", "Trophy", "Orange", function() if H.EraView then H.EraView.PreviewBossDown("TyrantKing") end end },
		{ "CRAFTING", "Hammer", "Orange", function() if H.Scenes then H.Scenes.Craft({ Kind = "Craft", What = "Launcher", Id = "QueensFang", Name = Config.Launchers.QueensFang.Name, Perk = Config.Launchers.QueensFang.Perk }) end end },
		{ "DAILY CHEST", "Chest", "Yellow", function() if H.Scenes then H.Scenes.Chest({ Coins = 400, Streak = 3, Egg = { Species = "Triceratops", Rarity = "Rare" } }) end end },
		{ "NEW INCUBATOR", "Incubator", "Teal", function() if H.Scenes then H.Scenes.NewNest(1) end end },
	}
	-- every era's boss teases you before the fight (Game/Omens): its sign on the road, a glimpse, a close call
	for _, row in ipairs(H.Omens and H.Omens.Gallery() or {}) do table.insert(list, row) end
	for _, r in ipairs(Config.RarityOrder) do
		table.insert(list, { "HATCH: " .. Config.Rarity[r].Name, "Egg", "Purple", function() if H.Hatch then H.Hatch.Preview("Velociraptor", r) end end })
	end
	-- every dino gets two, both shot on location in its era: the mystery -> reveal, and its signature
	for _, sp in ipairs(Config.SpeciesOrder) do
		local name = Config.Species[sp].Name
		table.insert(list, { name .. ": REVEAL", "Dino", "Purple", function() if H.EraView then H.EraView.PreviewReveal(sp) end end, sp })
		table.insert(list, { name .. ": SIGNATURE", "Dino", "Slate", function() if H.EraView then H.EraView.PreviewIntro(sp) end end, sp })
	end
	local first = nil
	for i, t in ipairs(list) do
		local holder = frame(grid, { LayoutOrder = i })
		local _, hit = Kit.Button(holder, { Text = t[1], Icon = t[2], Species = t[5], IconSize = 1.0, TextLeft = 0.34, TextSize = 0.3, MaxText = 14, Color = t[3], Size = UDim2.fromScale(1, 0.92), ZIndex = 26, Lip = 4, Radius = 12, OnClick = function() play(t[4]) end })
		first = first or hit
	end
	return first
end

-- TIKTOKS: the recording sequences (Game/TikTok), grouped like the edit library: master, bosses, chases,
-- dinos, eggs, places, short hooks, then every single shot on its own for re-recording one clip
local TT_COLORS = { MASTER = "Orange", GAMEPLAY = "Jungle", BOSSES = "Red", CHASES = "Yellow", DINOSAURS = "Purple", EGGS = "Lime", EXPEDITIONS = "Teal", ["SHORT HOOKS"] = "Blue", SHOTS = "Slate" }
local function tiktoks(body: Frame)
	local TT = Panels.Hooks.TikTok
	if not TT then return nil end
	local grid = scroller(body, Vector2.new(250, 56), 10)
	local order = 0
	local first = nil
	for _, cat in ipairs(TT.Catalog()) do
		order += 1
		local head = frame(grid, { LayoutOrder = order })
		pixel(head, cat.Name, { Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.5), Align = Enum.TextXAlignment.Left, Color = C.YellowHi, MaxSize = 14, ZIndex = 27 })
		-- keep each category starting on its own row
		for _ = 1, 2 do order += 1 frame(grid, { LayoutOrder = order }) end
		for _, item in ipairs(cat.Items) do
			order += 1
			local holder = frame(grid, { LayoutOrder = order })
			local secs = item.Beats * 60 / (TT.Data.Music.BPM or 123)
			local label = string.format("%s  %.1fs", item.Name, secs)
			local _, hit = Kit.Button(holder, { Text = label, Icon = "Film", IconSize = 0.9, TextLeft = 0.24, TextSize = 0.28, MaxText = 13, Color = TT_COLORS[cat.Name] or "Slate", Size = UDim2.fromScale(1, 0.92), ZIndex = 26, Lip = 4, Radius = 12, OnClick = function()
				close()
				task.delay(0.25, function()
					local ok, err = pcall(function()
						if item.Kind == "Shot" then TT.PlayShot(item.Id) else TT.Play(item.Id) end
					end)
					if not ok then warn("[TikTok]", err) end
				end)
			end })
			first = first or hit
		end
		-- pad the row out so the next header starts at the left
		while order % 3 ~= 0 do order += 1 frame(grid, { LayoutOrder = order }) end
	end
	return first
end

local function tools(body: Frame)
	local grid = scroller(body, Vector2.new(180, 56), 10)
	local function dev(action: string, args)
		args = args or {}
		args.Action = action
		local res = Net.Ask("Dev", args)
		Kit.Toast((res and res.Ok) and (res.Message or "DONE") or ((res and res.Err) or "FAILED"), (res and res.Ok) and "Teal" or "Red", "Gear")
	end
	local list = {
		{ "+1K COINS", "Coin", "Yellow", function() dev("AddCoins", { Amount = 1000 }) end },
		{ "+1M COINS", "Coin", "Yellow", function() dev("AddCoins", { Amount = 1000000 }) end },
		{ "ALL GEAR", "Wrench", "Orange", function() dev("UnlockGear") end },
		{ "ALL RIDE PARTS", "Jeep", "Purple", function() dev("UnlockRideParts") end },
		{ "BOSS PARTS", "Mat_QueenClaw", "Orange", function() dev("GiveMaterials") end },
		{ "ALL ERAS", "Gate", "Orange", function() dev("UnlockEras") end },
		{ "5 EGGS", "Egg", "Lime", function() dev("GiveEggs") end },
		{ "LEGENDARY EGG", "Egg", "Lime", function() dev("GiveEgg", { Rarity = "Legendary" }) end },
		{ "SECRET EGG", "Egg", "Lime", function() dev("GiveEgg", { Rarity = "Secret" }) end },
		{ "BOSS EGGS", "Crown", "Lime", function() dev("GiveBossEggs") end },
		{ "HATCH NOW", "Clock", "Lime", function() dev("FinishIncubators") end },
		{ "MAX BASE", "Home", "Lime", function() dev("MaxBase") end },
		{ "START RUN", "Gate", "Teal", function() close() dev("StartRun") end },
		{ "WAKE BOSS", "Trophy", "Teal", function() dev("OpenBoss") end },
		{ "REFILL", "Shield", "Teal", function() dev("Refill") end },
		{ "END RUN", "Door", "Teal", function() dev("EndRun") end },
		{ "TP PLOT", "Home", "Blue", function() close() dev("Teleport", { Where = "Plot" }) end },
		{ "TP GATE", "Gate", "Blue", function() close() dev("Teleport", { Where = "Gate" }) end },
		{ "ANIM PANEL", "Dino", "Purple", function() if DevHooks.OpenShowcasePanel then DevHooks.OpenShowcasePanel() end end },
		{ "REPLAY INTRO", "Star", "Purple", function() close() dev("ReplayTutorial") end },
		{ confirmReset and "TAP TO CONFIRM" or "RESET SAVE", "Alert", "Red", function()
			if not confirmReset then confirmReset = true Panels.Refresh() return end
			confirmReset = false
			close()
			dev("Reset")
		end },
	}
	local first = nil
	for i, t in ipairs(list) do
		local holder = frame(grid, { LayoutOrder = i })
		local _, hit = Kit.Button(holder, { Text = t[1], Icon = t[2], IconSize = 1.0, TextLeft = 0.36, TextSize = 0.3, MaxText = 14, Color = t[3], Size = UDim2.fromScale(1, 0.92), ZIndex = 26, Lip = 4, Radius = 12, OnClick = t[4] })
		first = first or hit
	end
	return first
end

local function buildSettings(content: Frame)
	local p = Net.Profile
	local isDev = player:GetAttribute("Dev") == true
	local list = { { "Options", "OPTIONS", "Gear" }, { "Gallery", "CUTSCENES", "Film" } }
	-- the TikTok recording sequences are a dev tool (Studio, or players the server marks Dev)
	local recorder = isDev or RunService:IsStudio()
	if recorder then table.insert(list, { "TikToks", "TIKTOKS", "Film" }) end
	if isDev then table.insert(list, { "Tools", "TEST TOOLS", "Wrench" }) end
	local isAdmin = player:GetAttribute("AdminRole") ~= nil
	if isAdmin then table.insert(list, { "Admin", "ADMIN", "Crown" }) end
	if settingsTab == "Admin" and not isAdmin then settingsTab = "Options" end
	if settingsTab == "TikToks" and not recorder then settingsTab = "Options" end
	if settingsTab == "Tools" and not isDev then settingsTab = "Options" end
	tabs(content, list, settingsTab, function(t)
		settingsTab = t
		confirmReset = false
		Panels.Refresh()
	end)
	local body = frame(content, { Size = UDim2.new(1, 0, 1, -56), Position = UDim2.fromOffset(0, 56) })
	if settingsTab == "Gallery" then return gallery(body) end
	if settingsTab == "TikToks" then return tiktoks(body) end
	if settingsTab == "Tools" then return tools(body) end
	if settingsTab == "Admin" then return AdminPanel.Build(body, { Refresh = Panels.Refresh }) end
	local s = (p and p.Settings) or {}
	local function set(key: string, v: boolean)
		Net.Ask("SetSetting", { Key = key, Value = v })
		if p then p.Settings = p.Settings or {} p.Settings[key] = v end
	end
	local col = frame(body, { Size = UDim2.fromScale(1, 1) })
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.Parent = col
	local _, first = switch(col, "CAMERA SHAKE", "Alert", s.Shake ~= false, function(v) set("Shake", v) end)
	switch(col, "SHORT TIME WARP", "Gate", s.SkipWarp == true, function(v) set("SkipWarp", v) end)
	switch(col, "OBJECTIVE ARROW", "Star", s.Hints ~= false, function(v) set("Hints", v) end)
	switch(col, "MUSIC", "Film", s.Music ~= false, function(v) set("Music", v) end)
	local row, rc = Kit.Card(col, { Size = UDim2.new(1, -8, 0, 60), ZIndex = 24 })
	Kit.Icon(rc, "Home", { Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 27 })
	text(rc, "UI SIZE", { Size = UDim2.new(0.4, 0, 0, 20), Position = UDim2.new(0, 64, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 20 })
	local SIZES = { { "XS", 0.8 }, { "S", 0.9 }, { "M", 1 }, { "L", 1.12 } }
	for i, opt in ipairs(SIZES) do
		local on = math.abs(Kit.UserScale - opt[2]) < 0.01
		Kit.Button(rc, { Text = opt[1], Color = on and "Yellow" or "Slate", Size = UDim2.fromOffset(52, 44), Position = UDim2.new(1, -10 - (#SIZES - i) * 60, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 27, Lip = 4, Radius = 12, OnClick = function()
			Kit.UserScale = opt[2]
			Kit.Refit()
			Net.Ask("SetSetting", { Key = "UiSize", Value = opt[2] })
			if p then p.Settings = p.Settings or {} p.Settings.UiSize = opt[2] end
			Panels.Refresh()
		end })
	end
	local _ = row
	return first
end

--------------------------------------------------------------------------------
-- PICKER: which rover rolls out
--------------------------------------------------------------------------------
local function buildPicker(content: Frame)
	local p = Net.Profile
	if not p then return end
	local list = {}
	for _, n in ipairs(Config.VehicleOrder) do if p.Gear and p.Gear.Vehicles and p.Gear.Vehicles[n] then table.insert(list, n) end end
	local w = 1 / math.max(1, #list)
	local first = nil
	for i, n in ipairs(list) do
		local info = Config.Vehicles[n]
		local card, cc = Kit.Card(content, { Size = UDim2.new(w, -12, 1, -6), Position = UDim2.new((i - 1) * w, 6, 0, 0), Border = p.Gear.Vehicle == n and C.LimeHi or info.Color, ZIndex = 24 })
		local sky = frame(cc, { Size = UDim2.new(1, -10, 0, 170), Position = UDim2.fromOffset(5, 5), BackgroundTransparency = 0, BackgroundColor3 = info.Color, ZIndex = 25 })
		Kit.Corner(sky, 12)
		Kit.Gradient(sky, info.Color:Lerp(Color3.new(1, 1, 1), 0.45), info.Color)
		Kit.Icon(sky, "Jeep", { Vehicle = n, Size = UDim2.fromScale(0.95, 0.95), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28 })
		text(cc, info.Name, { Size = UDim2.new(1, -16, 0, 20), Position = UDim2.new(0.5, 0, 0, 182), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 20 })
		pixel(cc, info.HP .. " ARMOR  -  " .. info.Cruise .. " SPEED", { Size = UDim2.new(1, -16, 0, 9), Position = UDim2.new(0.5, 0, 0, 208), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 9, Color = C.Muted })
		Kit.Button(cc, { Text = "RIDE SHOP", Color = "Purple", Size = UDim2.new(1, -24, 0, 36), Position = UDim2.new(0.5, 0, 1, -70), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 27, MaxText = 16, OnClick = function()
			close()
			if Panels.Hooks.RideStudio then task.delay(0.25, Panels.Hooks.RideStudio.Open, n) end
		end })
		local _, hit = Kit.Button(cc, { Text = "DRIVE", Color = "Lime", Shine = true, Size = UDim2.new(1, -24, 0, 50), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 27, OnClick = function()
			close()
			if Panels.OnPick then Panels.OnPick(n) end
		end })
		if n == p.Gear.Vehicle then first = hit end
		first = first or hit
		local _ = card
	end
	return first
end

--------------------------------------------------------------------------------
-- BUILD: an island UPGRADE board (Config.Island) - the hatchery, the garage, or a star pen lot
--------------------------------------------------------------------------------
local buildTarget = "Hatchery"
local buildChange = false -- a built star pen lot's CHANGE PEN: show the other pens to build there instead
-- your best dino of a species that isn't living in a star pen yet
local function bestStar(p, species: string): any?
	local inPen = {}
	for _, pen in pairs(p.Island and p.Island.Pens or {}) do if type(pen) == "table" and pen.Dino then inPen[pen.Dino] = true end end
	local best, bv = nil, -1
	for _, d in ipairs(p.Dinos or {}) do
		if d.Species == species and not inPen[d.Id] then
			local v = Config.DinoIncome(d)
			if v > bv then best, bv = d, v end
		end
	end
	return best
end
local function bossOf(species: string)
	for _, b in pairs(Config.Bosses) do if b.Species == species then return b end end
	return nil
end
local function islandAsk(args)
	local res = Net.Ask("IslandBuild", args)
	if res and res.Ok then
		close()
		if Panels.Hooks.Scenes and Panels.Hooks.Scenes.IslandBuild then Panels.Hooks.Scenes.IslandBuild(res) else Kit.Toast((res.Name or "BUILT") .. "!", "Lime", "Hammer") end
		if res.OldTo then Kit.Toast(res.OldTo == "Yard" and "YOUR OLD STAR WENT BACK TO THE PADDOCK" or "YOUR OLD STAR IS WAITING IN YOUR BAG", "Teal", "Dino") end
	else
		Kit.Toast((res and res.Err) or "CAN'T DO THAT", "Red", "Alert")
	end
end
-- a cost for a narrow card: one small chip per line (icon + have/need), no names
local function compactCost(parent: Instance, cost, y: number, z: number)
	local p = Net.Profile or {}
	local rows = {}
	if (cost.Coins or 0) > 0 then table.insert(rows, { "Coin", Config.FormatNumber(cost.Coins), (p.Coins or 0) >= cost.Coins }) end
	for mat, n in pairs(cost.Mats or {}) do
		local have = (p.Materials and p.Materials[mat]) or 0
		table.insert(rows, { "Mat_" .. mat, have .. " / " .. n, have >= n })
	end
	for i, r in ipairs(rows) do
		local f = frame(parent, { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0.5, 0, 0, y + (i - 1) * 32), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 0.2, BackgroundColor3 = r[3] and C.InkSoft or C.RedLo, ZIndex = z })
		Kit.Corner(f, 13)
		Kit.Stroke(f, C.Ink, 2)
		Kit.Icon(f, r[1], { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, -4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 2 })
		pixel(f, r[2], { Size = UDim2.new(1, -34, 0, 10), Position = UDim2.new(0, 30, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = z + 2, MaxSize = 10, Color = r[3] and C.Cream or C.RedHi })
	end
end

-- a perk line can be long: one line per "+" part
local function perkLines(parent: Instance, perk: string, y: number, z: number)
	local i = 0
	for part in string.gmatch(perk, "[^+]+") do
		part = part:gsub("^%s+", ""):gsub("%s+$", "")
		pixel(parent, part, { Size = UDim2.new(1, -24, 0, 11), Position = UDim2.new(0.5, 0, 0, y + i * 18), AnchorPoint = Vector2.new(0.5, 0), ZIndex = z, MaxSize = 11, Color = C.LimeHi })
		i += 1
	end
	return i
end

local function buildBuild(content: Frame)
	local p = Net.Profile
	if not p then return nil end
	local target = buildTarget
	local isl = p.Island or { Hatchery = 1, Garage = 1, Pens = {} }
	if target == "Hatchery" or target == "Garage" then
		local tiers = Config.Island[target]
		local cur = Config.IslandTier(p, target)
		local now, nxt = tiers[cur], tiers[cur + 1]
		-- left: the building as it is
		local _, cc = Kit.Card(content, { Size = UDim2.new(0.42, -8, 1, -6), Position = UDim2.fromOffset(0, 0), ZIndex = 24 })
		Kit.Icon(cc, target == "Hatchery" and "Incubator" or "Garage", { Size = UDim2.fromOffset(150, 150), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27 })
		text(cc, now.Name, { Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0.5, 0, 0, 176), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 32 })
		for i = 1, #tiers do
			local pip = frame(cc, { Size = UDim2.fromOffset(40, 14), Position = UDim2.new(0.5, (i - (#tiers + 1) / 2) * 48, 0, 220), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 0, BackgroundColor3 = i <= cur and C.LimeHi or C.InkSoft, ZIndex = 27 })
			Kit.Corner(pip, 7)
			Kit.Stroke(pip, C.Ink, 2)
		end
		local now1 = target == "Hatchery" and (now.Nests .. " NESTS") or ("REPAIRS FIX " .. math.floor(now.RepairHP * 100) .. "%")
		local now2 = target == "Hatchery" and ("HATCH TIME " .. math.floor(now.Speed * 100) .. "%") or ("REPAIR PRICE " .. math.floor(now.Repair * 100) .. "%")
		pixel(cc, now1, { Size = UDim2.new(1, -20, 0, 10), Position = UDim2.new(0.5, 0, 0, 252), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 10, Color = C.Muted })
		pixel(cc, now2, { Size = UDim2.new(1, -20, 0, 10), Position = UDim2.new(0.5, 0, 0, 270), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 10, Color = C.Muted })
		-- the hatchery sells its own nests (2026-10-14: they left the Armorer's drawer): how many you've built of what
		-- this tier holds, and +1 NEST right here (the next empty nest also carries its own BUILD prompt)
		local nestBtn
		if target == "Hatchery" then
			local inc = p.IncubatorCount or Config.Incubator.Base
			local incMax = Config.IncubatorMax(p)
			pixel(cc, "NESTS BUILT  " .. inc .. " / " .. incMax, { Size = UDim2.new(1, -20, 0, 11), Position = UDim2.new(0.5, 0, 0, 292), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 11, Color = inc < incMax and C.YellowHi or C.LimeHi })
			if inc < incMax then
				local price = Config.IncubatorPrice(inc)
				local can = (p.Coins or 0) >= price
				local _, h = Kit.Button(cc, { Text = "+1 NEST  " .. Config.FormatNumber(price), Icon = "Coin", IconSize = 0.8, TextLeft = 0.24, Color = can and "Lime" or "Grey", Disabled = not can, Shine = can, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 27, MaxText = 22,
					OnClick = function()
						local res = Net.Ask("BuyBase", { What = "Incubator" })
						if res and res.Ok then
							close()
							if Panels.Hooks.Scenes then Panels.Hooks.Scenes.NewNest(inc + 1) else Kit.Toast("NEW INCUBATOR BUILT!", "Teal", "Incubator") end
						else
							Kit.Toast((res and res.Err) or "NOT ENOUGH COINS", "Red", "Coin")
						end
					end })
				nestBtn = h
			else
				pixel(cc, nxt and "UPGRADE FOR MORE NESTS" or "EVERY NEST BUILT!", { Size = UDim2.new(1, -20, 0, 11), Position = UDim2.new(0.5, 0, 1, -30), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 11, Color = nxt and C.OrangeHi or C.LimeHi })
			end
		end
		-- right: the next tier
		local _, nc = Kit.Card(content, { Size = UDim2.new(0.58, -8, 1, -6), Position = UDim2.new(0.42, 8, 0, 0), ZIndex = 24, Border = nxt and C.YellowHi or nil })
		if not nxt then
			Kit.Icon(nc, "Crown", { Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, 0, 0.4, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27 })
			text(nc, "FULLY UPGRADED", { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0.5, 0, 0.72, 0), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 30, Color = C.YellowHi })
			return nestBtn
		end
		pixel(nc, "NEXT", { Size = UDim2.new(1, -20, 0, 10), Position = UDim2.new(0.5, 0, 0, 16), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 10, Color = C.Muted })
		text(nc, nxt.Name, { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0.5, 0, 0, 32), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 40, Color = C.YellowHi })
		local lines = perkLines(nc, nxt.Perk or "", 90, 27)
		costChips(nc, { Coins = nxt.Cost.Coins }, 18, 100 + lines * 18 + 16, 27)
		costChips(nc, { Mats = nxt.Cost.Mats }, 18, 100 + lines * 18 + 48, 27)
		local can = canAfford(nxt.Cost)
		local _, hit = Kit.Button(nc, { Text = "UPGRADE", Icon = "Hammer", IconSize = 0.9, TextLeft = 0.3, Color = can and "Lime" or "Grey", Disabled = not can, Shine = can, Size = UDim2.fromOffset(240, 60), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 27, MaxText = 28,
			OnClick = function() islandAsk({ What = target }) end })
		return (can or not nestBtn) and hit or nestBtn
	end
	-- a star pen lot
	local kind = Config.Island.Lots[target]
	if not kind then return nil end
	local pen = isl.Pens and isl.Pens[target]
	local filled = Config.StarPensFilled(p)
	pixel(content, "EVERY STAR IN A PEN: +" .. math.floor(Config.Island.PenIncome * 100) .. "% ISLAND INCOME   (" .. filled .. " NOW)", { Size = UDim2.new(1, -10, 0, 11), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 26, MaxSize = 11, Color = C.LimeHi })
	if type(pen) == "table" and not buildChange then
		-- built: who lives here, and move a better one in
		local def = Config.Island.Pens[pen.Species] or { Name = "STAR PEN" }
		local resident
		for _, d in ipairs(p.Dinos or {}) do if d.Id == pen.Dino then resident = d end end
		local _, cc = Kit.Card(content, { Size = UDim2.new(1, -8, 1, -28), Position = UDim2.fromOffset(4, 0), ZIndex = 24, Border = C.YellowHi })
		text(cc, def.Name, { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 40, Color = C.YellowHi })
		Kit.Icon(cc, "Dino", { Species = pen.Species, Size = UDim2.fromOffset(170, 170), Position = UDim2.new(0.5, 0, 0, 66), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27 })
		if resident then
			local r = Config.Rarity[resident.Rarity]
			text(cc, Config.Species[resident.Species].Name, { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0.5, 0, 0, 244), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 24 })
			pixel(cc, (r and r.Name or "") .. "  " .. Config.FormatKG(resident.KG or 0) .. "  $" .. Config.FormatNumber(Config.DinoIncome(resident)) .. "/S", { Size = UDim2.new(1, -20, 0, 10), Position = UDim2.new(0.5, 0, 0, 274), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 10, Color = r and r.Color or C.Cream })
		else
			text(cc, "EMPTY", { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0.5, 0, 0, 244), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 24, Color = C.Muted })
		end
		-- a different pen here instead (5 land bosses, 3 land lots): small, out of the way
		if kind == "Land" then
			Kit.Button(cc, { Text = "CHANGE PEN", Icon = "Hammer", IconSize = 0.8, TextLeft = 0.3, Color = "Slate", Size = UDim2.fromOffset(170, 40), Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0), ZIndex = 28, MaxText = 18,
				OnClick = function() buildChange = true Panels.Refresh() end })
		end
		local best = bestStar(p, pen.Species)
		if best and (not resident or Config.DinoIncome(best) > Config.DinoIncome(resident)) then
			local _, hit = Kit.Button(cc, { Text = "MOVE IN", Icon = "Dino", IconSize = 0.9, TextLeft = 0.3, Color = "Lime", Shine = true, Size = UDim2.fromOffset(230, 56), Position = UDim2.new(0.5, 0, 1, -14), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 27, MaxText = 26,
				OnClick = function() islandAsk({ What = "Pen", Lot = target, Dino = best.Id }) end })
			return hit
		end
		return nil
	end
	-- an empty lot: a pen per boss species that fits here (the sea lot takes the sea boss)
	local list = {}
	for _, sp in ipairs(Config.Island.PenOrder) do if Config.PenLotKind(sp) == kind then table.insert(list, sp) end end
	local n = #list
	local cw = n == 1 and 300 or 144
	local penned = {}
	for _, op in pairs(isl.Pens or {}) do if type(op) == "table" and op.Species then penned[op.Species] = true end end
	if buildChange then
		pixel(content, "BUILDING A NEW PEN HERE TAKES THE OLD ONE DOWN (ITS STAR GOES BACK TO YOUR PADDOCK)", { Size = UDim2.new(1, -10, 0, 10), Position = UDim2.new(0.5, 0, 1, -22), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 26, MaxSize = 10, Color = C.Muted })
	end
	local first = nil
	for i, sp in ipairs(list) do
		local def = Config.Island.Pens[sp]
		local best = bestStar(p, sp)
		local x = (i - (n + 1) / 2) * (cw + 8)
		local _, cc = Kit.Card(content, { Size = UDim2.fromOffset(cw, 352), Position = UDim2.new(0.5, x, 0, 0), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 24, Border = (best and not penned[sp]) and C.YellowHi or nil })
		Kit.Icon(cc, "Dino", { Species = sp, Size = UDim2.fromOffset(110, 110), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27 })
		text(cc, def.Name, { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0.5, 0, 0, 126), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 20 })
		pixel(cc, Config.Species[sp] and Config.Species[sp].Name or sp, { Size = UDim2.new(1, -12, 0, 9), Position = UDim2.new(0.5, 0, 0, 152), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 9, Color = C.Muted })
		if penned[sp] then
			-- one pen per species: this one already has its home
			pixel(cc, "BUILT ON YOUR ISLAND", { Size = UDim2.new(1, -12, 0, 9), Position = UDim2.new(0.5, 0, 0, 200), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27, MaxSize = 9, Color = C.LimeHi })
			Kit.Icon(cc, "Star", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, 0, 0, 222), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 27 })
		elseif best then
			compactCost(cc, def.Cost, 178, 27)
			local can = canAfford(def.Cost)
			local _, hit = Kit.Button(cc, { Text = "BUILD", Icon = "Hammer", IconSize = 0.9, TextLeft = 0.32, Color = can and "Lime" or "Grey", Disabled = not can, Shine = can, Size = UDim2.new(1, -16, 0, 52), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 27, MaxText = 22,
				OnClick = function() islandAsk({ What = "Pen", Lot = target, Dino = best.Id, Rebuild = buildChange or nil }) end })
			first = first or hit
		else
			-- you don't have one yet: its boss is where it comes from
			local boss = bossOf(sp)
			local dim = frame(cc, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.5, BackgroundColor3 = Color3.fromRGB(20, 22, 28), ZIndex = 28 })
			Kit.Corner(dim, 10)
			Kit.Icon(dim, "Crown", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0.5, 0, 0, 196), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 30 })
			pixel(dim, boss and boss.Name or "A BOSS", { Size = UDim2.new(1, -12, 0, 10), Position = UDim2.new(0.5, 0, 0, 258), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 30, MaxSize = 10, Color = C.YellowHi })
			Kit.Icon(dim, "Lock", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 30 })
		end
	end
	return first
end

--------------------------------------------------------------------------------
local BUILDERS = {
	Bag = { "MY BAG", "Yellow", "Bag", 900, 560, buildBag },
	Companions = { "COMPANIONS", "Teal", "Buddy", 900, 600, buildCompanions },
	Index = { "DINO INDEX", "Blue", "Index", 900, 560, buildIndex },
	Workshop = { "THE ARMORER", "Orange", "Armor", 440, 680, buildWorkshop, "Drawer" },
	Shop = { "SHOP", "Purple", "Shop", 860, 430, buildShop },
	Eras = { "TIME GATE", "Teal", "Gate", 880, 560, buildEras },
	Quests = { "QUESTS", "Lime", "Quest", 760, 460, buildQuests },
	Settings = { "SETTINGS", "Slate", "Gear", 840, 560, buildSettings },
	Picker = { "PICK YOUR RIDE", "Yellow", "Jeep", 760, 470, buildPicker },
	Build = { "UPGRADE", "Orange", "Hammer", 800, 480, function(content) return buildBuild(content) end },
}

-- what an open panel last drew from (Panels.Start's Profile hook skips pushes that change none of it)
local HttpService = game:GetService("HttpService")
local lastSig = { Sig = "", Coins = -1, At = 0 }
local SIG_SKIP = { Pending = true, Earned = true, LastSeen = true, Stats = true, Coins = true }
local function profileSig(p): (string, number)
	if typeof(p) ~= "table" then return "", 0 end
	local copy = {}
	for k, v in pairs(p) do if not SIG_SKIP[k] then copy[k] = v end end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, copy)
	return ok and json or tostring(os.clock()), tonumber(p.Coins) or 0
end

local function openFresh(name: string)
	local def = BUILDERS[name]
	-- (a "Drawer" window sits down the right side so the game stays in view: the Armorer)
	local drawer = def[7] == "Drawer"
	local root, content, header = Kit.Window(canvas, { Fit = true, Title = def[1], Color = def[2], Icon = def[3], Size = UDim2.fromOffset(def[4], def[5]), Position = drawer and UDim2.new(1, -16, 0.5, 0) or UDim2.fromScale(0.5, 0.53), AnchorPoint = drawer and Vector2.new(1, 0.5) or Vector2.new(0.5, 0.5), ZIndex = 20, OnClose = close })
	local ok, first = pcall(def[6], content, header)
	if not ok then warn("[Panels]", name, first) first = nil end
	current = { Name = name, Root = root }
	return root, first
end

function Panels.Open(name: string)
	if not BUILDERS[name] then return end
	local P = Net.Profile
	if P then lastSig.Sig, lastSig.Coins, lastSig.At = profileSig(P), tonumber(P.Coins) or 0, os.clock() end
	if current and current.Name == name then close() return end
	if current then
		local old = current.Root
		current = nil
		old:Destroy()
	end
	dimGui.Enabled = true
	TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = (BUILDERS[name][7] == "Drawer") and 0.8 or 0.4 }):Play()
	local root, first = openFresh(name)
	Kit.Enter(root)
	if Kit.Gamepad() and first then GuiService.SelectedObject = first end
end

-- open the UPGRADE window for one board: "Hatchery" | "Garage" | "StarA".."StarD"
function Panels.OpenBuild(target: string)
	buildTarget = target
	buildChange = false
	if current and current.Name == "Build" then Panels.Refresh() else Panels.Open("Build") end
end

function Panels.Refresh()
	if not current then return end
	local name = current.Name
	local root = current.Root
	-- keep the scroll position of the first grid so refreshes don't jump
	local scroll = root:FindFirstChildWhichIsA("ScrollingFrame", true)
	local y = scroll and scroll.CanvasPosition.Y or 0
	current = nil
	root:Destroy()
	local newRoot, first = openFresh(name)
	local s2 = newRoot:FindFirstChildWhichIsA("ScrollingFrame", true)
	if s2 then task.defer(function() s2.CanvasPosition = Vector2.new(0, y) end) end
	if Kit.Gamepad() and first then GuiService.SelectedObject = first end
end

function Panels.IsOpen(): boolean
	return current ~= nil
end

function Panels.Current(): string?
	return current and current.Name
end

function Panels.Start()
	dimGui = Kit.Screen("DinoPanelDim", 19, true)
	dimGui.Enabled = false
	local droot = dimGui:FindFirstChild("Root") :: Frame
	dim = frame(droot, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(8, 16, 10) })
	local dimHit = Instance.new("TextButton")
	dimHit.BackgroundTransparency = 1
	dimHit.Text = ""
	dimHit.Size = UDim2.fromScale(1, 1)
	dimHit.Parent = dim
	dimHit.Activated:Connect(close)
	-- (2026-10-12) a cutscene ending can switch this layer back on after a panel closed (Cinema restores what it
	-- hid): an invisible full-screen button over the HUD that eats every tap (on touch there's no V key to fall
	-- back on). With no panel open and the dim faded out, it switches itself off.
	game:GetService("RunService").Heartbeat:Connect(function()
		if dimGui.Enabled and not current and dim.BackgroundTransparency > 0.97 then dimGui.Enabled = false end
	end)
	local _
	_, canvas = Kit.Screen("DinoPanels", 20)
	UserInputService.InputBegan:Connect(function(input)
		if not current then return end
		-- (the NAME YOUR DINO box over the Bag takes this press for itself)
		if require(script.Parent.Parent.NameDialog).HoldsBack() then return end
		if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then close() end
	end)
	Net.On("Profile", function(p)
		-- the saved UI SIZE (Settings) follows the player to every device
		local ui = p and p.Settings and p.Settings.UiSize
		if typeof(ui) == "number" and math.abs(ui - Kit.UserScale) > 0.001 then
			Kit.UserScale = ui
			Kit.Refit()
		end
		if current and current.Name ~= "Picker" and current.Name ~= "Settings" then
			-- (an open panel used to be rebuilt - ~3k instances, a visible hitch - on every push, and auto-collect pushes
			-- every ~5 s: now only when something it shows changed; a coins-only change refreshes at most every 10 s)
			local sig, coins = profileSig(p)
			local now = os.clock()
			if sig ~= lastSig.Sig or (coins ~= lastSig.Coins and now - lastSig.At >= 10) then
				lastSig.Sig, lastSig.Coins, lastSig.At = sig, coins, now
				Panels.Refresh()
			end
		end
	end)
	player:GetAttributeChangedSignal("HeldEgg"):Connect(function() if current and current.Name == "Bag" then Panels.Refresh() end end)
	-- a shop purchase landed: what came out, best egg first (Monetization.grant)
	local RARITY_TOAST = { Common = "Grey", Uncommon = "Green", Rare = "Blue", Epic = "Purple", Legendary = "Yellow", Secret = "Red" }
	Net.On("ShopGot", function(info)
		local got = typeof(info) == "table" and info.Got or {}
		local eggs = got.Eggs or {}
		local delay = 0
		local function toast(t: string, c: string, icon: string)
			task.delay(delay, function() Kit.Toast(t, c, icon) end)
			delay += 0.6
		end
		if eggs[1] then
			local e = eggs[1]
			local r = Config.Rarity[e.Rarity]
			local sp = Config.Species[e.Species]
			toast(string.format("%s %s EGG!", r and r.Name or "", sp and sp.Name or "DINO"), RARITY_TOAST[e.Rarity] or "Purple", "Egg")
			if #eggs > 1 then toast(string.format("+%d MORE EGGS IN YOUR BAG", #eggs - 1), "Teal", "Bag") end
		end
		if (got.Coins or 0) > 0 then toast("+" .. Config.FormatNumber(got.Coins) .. " COINS", "Yellow", "Coin") end
		if (got.Luck or 0) > 0 then toast("LUCK BOOST: " .. got.Luck .. " MIN", "Orange", "Star") end
		if typeof(got.Trainer) == "string" then toast("TRAINER " .. got.Trainer, "Lime", "Power") end
		if (got.Hatch or 0) > 0 then toast(got.Hatch .. (got.Hatch > 1 and " INSTANT HATCHES" or " INSTANT HATCH"), "Blue", "Clock") end
		if (got.Slot or 0) > 0 then toast("NEW COMPANION SLOT!", "Teal", "Buddy") end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local action = prompt:GetAttribute("CampAction")
		if action == "Shop" then Panels.Open("Workshop") elseif action == "Era" then Panels.Open("Eras")
		elseif action == "Build" then
			local plotIdx = player:GetAttribute("Plot")
			if plotIdx and prompt:FindFirstAncestor("Plot" .. plotIdx) then Panels.OpenBuild(prompt:GetAttribute("Build") or "Hatchery") end
		end
	end)
	local _w = Workspace
end

return Panels
