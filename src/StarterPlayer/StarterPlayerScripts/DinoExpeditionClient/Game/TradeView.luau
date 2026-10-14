--[[
	TradeView — the trading screens (2026-10-14; server: ServerScriptService Game/Trade.luau, which decides everything).

	  TRADE button      on another player's VIEW PROFILE card (PlayerCard calls TradeView.CardButton). It's greyed out with
	                    the reason when you can't trade them (playtime, busy, already trading).
	  request card      "<NAME> WANTS TO TRADE": ACCEPT / DECLINE, a bar running down. Keys Y / N, D-pad up / down on a
	                    gamepad. During a cutscene it answers "busy" by itself.
	  the window        YOU GIVE / <NAME> GIVES boards (8 slots each: species icon, KG, rarity band; tap or hover one for
	                    the full line), your dinos + eggs underneath to pick from (a companion, a star in its pen, an egg
	                    in a nest or on the rack show why they can't go), and the READY -> countdown -> CONFIRM panel.
	                    Any change to either side clears both READYs and the board that changed shakes.
	  TRADE COMPLETE    what you got, with confetti.
	Gamepad: Y = the big button (READY / CONFIRM), B twice = cancel.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)

local C = Kit.Colors
local T = Config.Trade
local TradeView = {}
-- set by PlayerCard: the profile card closes when a trade window opens
TradeView.OnOpen = nil :: (() -> ())?

local function new(class: string, props, parent: Instance?)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do (i :: any)[k] = v end
	if parent then i.Parent = parent end
	return i
end

local function frame(parent: Instance, props): Frame
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	return new("Frame", props, parent) :: Frame
end

local function pixel(parent: Instance, s: string, props)
	props.Pixel = true
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2
	props.Shadow = props.Shadow or 1
	props.MaxSize = props.MaxSize or 10
	return Kit.Text(parent, s, props)
end

local function rarityOf(r: string?)
	return Config.Rarity[r or ""] or Config.Rarity.Common
end

local function speciesName(id: string?): string
	local s = id and Config.Species[id]
	return s and s.Name or string.upper(tostring(id or "?"))
end

local function kg(n: number?): string
	return Config.FormatKG(math.floor(tonumber(n) or 0))
end

-- "LEGENDARY T-REX EGG  2,340 KG  BOND 2"
local function itemLine(it): string
	local s = rarityOf(it.Rarity).Name .. " " .. speciesName(it.Species) .. (it.Kind == "Egg" and " EGG" or "") .. "  " .. kg(it.KG)
	if typeof(it.Name) == "string" and it.Name ~= "" then s = string.upper(it.Name) .. " - " .. s end
	if it.Bond and it.Bond > 0 then s ..= "  BOND " .. it.Bond end
	return s
end

local function clear(host: Instance)
	for _, c in ipairs(host:GetChildren()) do c:Destroy() end
end

local function sameSet(x, y): boolean
	if #x ~= #y then return false end
	local ids = {}
	for _, it in ipairs(x) do ids[it.Id] = true end
	for _, it in ipairs(y) do if not ids[it.Id] then return false end end
	return true
end

local function upper(s: string?): string
	return string.upper(tostring(s or ""))
end

--------------------------------------------------------------------------------
-- the request card (someone wants to trade with you)
--------------------------------------------------------------------------------
local reqGui, reqCanvas
local reqOpen: { Holder: Frame, Id: number }? = nil
local win: any = nil -- the open trade window

local function hideRequest()
	local r = reqOpen
	if not r then return end
	reqOpen = nil
	ContextActionService:UnbindAction("DinoTradeYes")
	ContextActionService:UnbindAction("DinoTradeNo")
	if r.Holder.Parent then Kit.Exit(r.Holder, true) end
end

local function answer(id: number, yes: boolean)
	if not (reqOpen and reqOpen.Id == id) then return end
	hideRequest()
	task.spawn(function()
		local res = Net.Ask("TradeAnswer", { Id = id, Yes = yes })
		if yes and not (res and res.Ok) then Kit.Toast((res and res.Err) or "THE TRADE COULDN'T START", "Red", "Alert") end
	end)
end

local function showRequest(info)
	if typeof(info) ~= "table" or typeof(info.Id) ~= "number" then return end
	-- mid-cutscene (or somehow already trading): tell them you're busy rather than hide a card behind the scene
	if Cinema.Playing() or win then
		task.spawn(Net.Ask, "TradeAnswer", { Id = info.Id, Yes = false, Busy = true })
		return
	end
	if reqOpen then hideRequest() end
	if not reqGui then reqGui, reqCanvas = Kit.Screen("DinoTradeRequest", 44, false) end
	local id = info.Id
	local holder = frame(reqCanvas, { Size = UDim2.fromOffset(470, 160), Position = UDim2.new(0.5, 0, 0, 96), AnchorPoint = Vector2.new(0.5, 0) })
	local _, cc = Kit.Card(holder, { Size = UDim2.fromScale(1, 1), Color = "Forest", Border = C.YellowHi, ZIndex = 50 })
	Kit.Icon(cc, "Gift", { Size = UDim2.fromOffset(74, 74), Position = UDim2.fromOffset(4, 2), ZIndex = 53, Rotation = -8 })
	Kit.Text(cc, upper(info.Name or "SOMEONE"), { Size = UDim2.new(1, -96, 0, 30), Position = UDim2.fromOffset(84, 10), Align = Enum.TextXAlignment.Left, ZIndex = 53, MaxSize = 28, Color = C.YellowHi, Stroke = 3.5, Shadow = 3 })
	pixel(cc, "WANTS TO TRADE DINOS + EGGS", { Size = UDim2.new(1, -96, 0, 10), Position = UDim2.fromOffset(86, 48), Align = Enum.TextXAlignment.Left, ZIndex = 53 })
	local pad = Kit.Gamepad()
	Kit.Button(cc, { Text = pad and "ACCEPT [UP]" or "ACCEPT [Y]", Color = "Lime", Size = UDim2.new(0.5, -14, 0, 50), Position = UDim2.fromOffset(8, 80), ZIndex = 53, MaxText = 20, Lip = 4, Shine = true, OnClick = function() answer(id, true) end })
	Kit.Button(cc, { Text = pad and "NO [DOWN]" or "NO [N]", Color = "Red", Size = UDim2.new(0.5, -14, 0, 50), Position = UDim2.new(0.5, 6, 0, 80), ZIndex = 53, MaxText = 20, Lip = 4, OnClick = function() answer(id, false) end })
	local bar = frame(cc, { BackgroundTransparency = 0, BackgroundColor3 = C.YellowHi, Size = UDim2.new(1, -16, 0, 5), Position = UDim2.new(0, 8, 1, -12), ZIndex = 53 })
	local t = tonumber(info.Time) or T.RequestTime
	TweenService:Create(bar, TweenInfo.new(t, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 5) }):Play()
	Kit.Pop(holder, 0.3)
	Kit.Sound("Pop", 0.6)
	reqOpen = { Holder = holder, Id = id }
	ContextActionService:BindActionAtPriority("DinoTradeYes", function(_, state)
		if state == Enum.UserInputState.Begin then answer(id, true) return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end, false, 2200, Enum.KeyCode.Y, Enum.KeyCode.DPadUp)
	ContextActionService:BindActionAtPriority("DinoTradeNo", function(_, state)
		if state == Enum.UserInputState.Begin then answer(id, false) return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end, false, 2200, Enum.KeyCode.N, Enum.KeyCode.DPadDown)
	-- (the server expires it and says so; this just tidies the card if that message is late)
	task.delay(t + 1, function() if reqOpen and reqOpen.Id == id then hideRequest() end end)
end

--------------------------------------------------------------------------------
-- the trade window
--------------------------------------------------------------------------------
local gui, canvas
local state: any = nil
local stateAt = 0
local desired: { any }? = nil -- your side as you've picked it, until the server's state catches up
local tab = "Dino"
local sending, resend = false, false
local warnUntil = 0
local cancelArmed = 0
local finished = {} :: { [string]: boolean } -- trade ids that closed: a late state message never reopens one
local renderPicker, renderBoards, renderStatus -- (forward)

local function serverMine(): { any }
	local out = {}
	for _, it in ipairs(state and state.Me and state.Me.Items or {}) do table.insert(out, { Kind = it.Kind, Id = it.Id }) end
	return out
end
local function picked(): { any }
	return desired or serverMine()
end
local function synced(): boolean
	return not sending and (desired == nil or sameSet(desired, serverMine()))
end

-- send your side (the whole list); the rate limit's "slow down" just retries
local function push()
	if sending then resend = true return end
	sending = true
	task.spawn(function()
		while true do
			resend = false
			local sent = desired
			if not sent or not win then break end
			local res = Net.Ask("TradeSetOffer", { Items = sent })
			if res and res.Err == "slow down" then
				task.wait(0.2)
				resend = true
			elseif not (res and res.Ok) then
				Kit.Toast((res and res.Err) or "CAN'T TRADE THAT", "Red", "Alert")
				if desired == sent then desired = nil end
			end
			if not resend then break end
		end
		sending = false
		if desired and sameSet(desired, serverMine()) then desired = nil end
		if win then renderPicker() renderStatus() end
	end)
end

local function toggle(kind: string, id: string)
	if not state then return end
	local list = table.clone(picked())
	local at = nil
	for i, it in ipairs(list) do if it.Id == id then at = i end end
	if at then
		table.remove(list, at)
	else
		if #list >= (state.Max or T.MaxItems) then Kit.Toast(`UP TO {state.Max or T.MaxItems} ITEMS A TRADE`, "Orange", "Alert") return end
		table.insert(list, { Kind = kind, Id = id })
	end
	desired = list
	renderPicker()
	push()
end

local function closeWindow()
	local w = win
	if not w then return end
	win = nil
	finished[w.Id] = true
	state, desired = nil, nil
	if w.Conn then w.Conn:Disconnect() end
	ContextActionService:UnbindAction("DinoTradeMain")
	ContextActionService:UnbindAction("DinoTradeCancel")
	if w.Root.Parent then Kit.Exit(w.Root, true) end
	GuiService.SelectedObject = nil
end

local function cancel()
	if not win then return end
	local res = Net.Ask("TradeCancel", {})
	-- (the server's TradeClosed closes the window; if it can't be reached, close it here)
	if not (res and res.Ok) then closeWindow() end
end

-- one board: YOU GIVE / <NAME> GIVES
local SLOT_W, SLOT_H, GAP = 94, 66, 8
local function board(host: Frame, side, isMe: boolean, otherCount: number)
	clear(host)
	local items = side.Items or {}
	local border = side.Confirm and C.YellowHi or (side.Ready and C.LimeHi or nil)
	local outer, cc = Kit.Card(host, { Size = UDim2.fromScale(1, 1), Color = "Card", Border = border, ZIndex = 64 })
	local title = isMe and "YOU GIVE" or (upper(side.Name) .. " GIVES")
	local info = pixel(cc, title, { Size = UDim2.new(1, -170, 0, 11), Position = UDim2.fromOffset(14, 13), Align = Enum.TextXAlignment.Left, ZIndex = 68, MaxSize = 11, Color = isMe and C.Cream or C.YellowHi })
	local function showInfo(s: string?, color: Color3?)
		Kit.SetText(info, s or title)
		Kit.SetTextColor(info, color or (isMe and C.Cream or C.YellowHi))
	end
	-- the state chip + count
	local chipText = side.Confirm and "CONFIRMED" or (side.Ready and "READY" or "NOT READY")
	local chipColor = side.Confirm and C.Yellow or (side.Ready and C.Lime or C.Grey)
	local chip = frame(cc, { BackgroundTransparency = 0, BackgroundColor3 = chipColor, Size = UDim2.fromOffset(108, 22), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0), ZIndex = 68 })
	Kit.Corner(chip, 11)
	Kit.Stroke(chip, C.Ink, 2.5)
	Kit.Gradient(chip, Kit.Shade(chipColor, 1.2), Kit.Shade(chipColor, 0.85))
	pixel(chip, chipText, { Size = UDim2.new(1, -10, 0, 9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 69, MaxSize = 9 })
	pixel(cc, #items .. "/" .. tostring(state and state.Max or T.MaxItems), { Size = UDim2.fromOffset(40, 10), Position = UDim2.new(1, -126, 0, 14), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 68, Color = C.Muted })
	for i = 1, (state and state.Max or T.MaxItems) do
		local it = items[i]
		local x = 12 + ((i - 1) % 4) * (SLOT_W + GAP)
		local y = 36 + math.floor((i - 1) / 4) * (SLOT_H + GAP)
		local r = it and rarityOf(it.Rarity)
		local slot = frame(cc, {
			Size = UDim2.fromOffset(SLOT_W, SLOT_H), Position = UDim2.fromOffset(x, y), ZIndex = 66,
			BackgroundTransparency = it and 0 or 0.55, BackgroundColor3 = r and r.Color:Lerp(C.Forest, 0.6) or C.Forest,
		})
		Kit.Corner(slot, 10)
		Kit.Stroke(slot, r and r.Color or C.Ink, it and 3 or 2)
		if it and r then
			Kit.Icon(slot, it.Kind == "Egg" and "Egg" or "Dino", { Species = it.Species, Size = UDim2.fromOffset(it.Kind == "Egg" and 34 or 46, it.Kind == "Egg" and 40 or 46), Position = UDim2.new(0.5, 0, 0, it.Kind == "Egg" and 3 or -2), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 68 })
			pixel(slot, kg(it.KG), { Size = UDim2.new(1, -6, 0, 8), Position = UDim2.new(0.5, 0, 0, 42), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 69, MaxSize = 8, Color = C.YellowHi })
			local band = frame(slot, { BackgroundTransparency = 0, BackgroundColor3 = r.Color, Size = UDim2.new(1, -6, 0, 12), Position = UDim2.new(0.5, 0, 1, -3), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 68 })
			Kit.Corner(band, 6)
			Kit.Gradient(band, Kit.Shade(r.Color, 1.2), Kit.Shade(r.Color, 0.8))
			pixel(band, r.Name, { Size = UDim2.new(1, -4, 0, 7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 69, MaxSize = 7, Stroke = 1.5 })
			if it.Kind == "Egg" then pixel(slot, "EGG", { Size = UDim2.fromOffset(26, 7), Position = UDim2.fromOffset(4, 4), Align = Enum.TextXAlignment.Left, ZIndex = 69, MaxSize = 7, Color = C.Cream }) end
			local hit = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 72, AutoButtonColor = false }, slot) :: TextButton
			local line = itemLine(it)
			hit.MouseEnter:Connect(function() showInfo(line, r.Color:Lerp(Color3.new(1, 1, 1), 0.35)) end)
			hit.MouseLeave:Connect(function() showInfo(nil) end)
			hit.SelectionGained:Connect(function() showInfo(line, r.Color:Lerp(Color3.new(1, 1, 1), 0.35)) end)
			hit.SelectionLost:Connect(function() showInfo(nil) end)
			hit.Activated:Connect(function()
				showInfo(line, r.Color:Lerp(Color3.new(1, 1, 1), 0.35))
				if isMe then toggle(it.Kind, it.Id) end -- (tap your own to take it back out)
			end)
		end
	end
	-- the one thing a scam needs you not to notice: you're getting nothing
	if not isMe and #items == 0 and otherCount > 0 then
		local warnBox = frame(cc, { BackgroundTransparency = 0.15, BackgroundColor3 = C.RedLo, Size = UDim2.fromOffset(300, 40), Position = UDim2.new(0.5, 0, 0.5, 14), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 74 })
		Kit.Corner(warnBox, 12)
		Kit.Stroke(warnBox, C.Ink, 3)
		Kit.Text(warnBox, "THEY GIVE NOTHING!", { Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 75, MaxSize = 20, Color = C.RedHi })
	end
	return outer
end

function renderBoards()
	local w = win
	if not (w and state) then return end
	board(w.Mine, state.Me, true, #state.Them.Items)
	w.TheirBoard = board(w.Theirs, state.Them, false, #state.Me.Items)
end

-- where an item lives decides whether it can go (the server checks again: Dinos.TradeBlock)
local function pickerItems(p)
	local out = {}
	if tab == "Dino" then
		local pens = {}
		for _, pen in pairs(p.Island and p.Island.Pens or {}) do
			if typeof(pen) == "table" and (pen.Dino or "") ~= "" then pens[pen.Dino] = true end
		end
		for _, d in ipairs(p.Dinos or {}) do
			local lock, unequip = nil, false
			if table.find(p.Buddies or {}, d.Id) then lock, unequip = "COMPANION", true
			elseif pens[d.Id] then lock = "STAR PEN" end
			table.insert(out, { Kind = "Dino", Id = d.Id, Species = d.Species, Rarity = d.Rarity, KG = d.KG, Lock = lock, Unequip = unequip, Yard = table.find(p.Placed or {}, d.Id) ~= nil })
		end
	else
		for _, e in ipairs(p.Eggs or {}) do table.insert(out, { Kind = "Egg", Id = e.Id, Species = e.Species, Rarity = e.Rarity, KG = e.KG }) end
		for _, inc in ipairs(p.Incubators or {}) do table.insert(out, { Kind = "Egg", Id = "nest" .. tostring(inc.Slot), Species = inc.Species, Rarity = inc.Rarity, KG = inc.KG, Lock = "IN A NEST" }) end
		for i, e in ipairs(p.RoverEggs or {}) do table.insert(out, { Kind = "Egg", Id = "rack" .. i, Species = e.Species, Rarity = e.Rarity, KG = e.KG, Lock = "ON YOUR RACK" }) end
	end
	table.sort(out, function(a, b)
		if (a.Lock ~= nil) ~= (b.Lock ~= nil) then return a.Lock == nil end
		local ra, rb = rarityOf(a.Rarity).Order, rarityOf(b.Rarity).Order
		if ra ~= rb then return ra > rb end
		if (a.KG or 0) ~= (b.KG or 0) then return (a.KG or 0) > (b.KG or 0) end
		return a.Id < b.Id
	end)
	return out
end

function renderPicker()
	local w = win
	if not (w and state) then return end
	local host = w.Picker :: Frame
	local old = host:FindFirstChild("Grid") :: ScrollingFrame?
	local keep = old and old.CanvasPosition or Vector2.zero
	local sel = GuiService.SelectedObject
	local selId = sel and sel:IsDescendantOf(host) and sel:GetAttribute("TradeItem") or nil
	clear(host)
	local p = Net.Profile or {}
	local nD, nE = #(p.Dinos or {}), #(p.Eggs or {})
	Kit.Button(host, { Name = "TabDinos", Text = "DINOS " .. nD, Icon = "Dino", IconSize = 0.95, TextLeft = 0.34, Color = tab == "Dino" and "Yellow" or "Slate", Size = UDim2.fromOffset(160, 40), Position = UDim2.fromOffset(0, 0), ZIndex = 66, Lip = 4, Radius = 12, MaxText = 20, OnClick = function() tab = "Dino" renderPicker() end })
	Kit.Button(host, { Name = "TabEggs", Text = "EGGS " .. nE, Icon = "Egg", IconSize = 0.95, TextLeft = 0.34, Color = tab == "Egg" and "Yellow" or "Slate", Size = UDim2.fromOffset(160, 40), Position = UDim2.fromOffset(168, 0), ZIndex = 66, Lip = 4, Radius = 12, MaxText = 20, OnClick = function() tab = "Egg" renderPicker() end })
	pixel(host, "TAP TO ADD / REMOVE", { Size = UDim2.fromOffset(220, 9), Position = UDim2.new(1, -4, 0, 16), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 66, MaxSize = 9, Color = C.Muted })
	local sf = new("ScrollingFrame", {
		Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50),
		ScrollBarThickness = 8, ScrollBarImageColor3 = C.LimeHi, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 66,
		SelectionGroup = true,
	}, host) :: ScrollingFrame
	new("UIGridLayout", { CellSize = UDim2.fromOffset(100, 118), CellPadding = UDim2.fromOffset(8, 10), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10) }, sf)
	local chosen = {}
	for _, it in ipairs(picked()) do chosen[it.Id] = true end
	local first, reselect = nil, nil
	local list = pickerItems(p)
	for i, it in ipairs(list) do
		local r = rarityOf(it.Rarity)
		local on = chosen[it.Id] == true
		local cell = frame(sf, { Size = UDim2.fromOffset(100, 118), LayoutOrder = i, ZIndex = 67 })
		local _, cc = Kit.Card(cell, { Size = UDim2.fromScale(1, 1), Color = "Card", Border = on and C.YellowHi or r.Color, ZIndex = 67, Lip = 4 })
		if it.Kind == "Egg" then
			Kit.Icon(cc, "Egg", { Species = it.Species, Size = UDim2.fromOffset(46, 54), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 70 })
		else
			Kit.Icon(cc, "Dino", { Species = it.Species, Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, -4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 70 })
		end
		Kit.Text(cc, speciesName(it.Species), { Size = UDim2.new(1, -8, 0, 12), Position = UDim2.new(0.5, 0, 0, 62), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 71, MaxSize = 12, Stroke = 2.5, Shadow = 2, Color = C.Cream })
		pixel(cc, kg(it.KG), { Size = UDim2.new(1, -8, 0, 8), Position = UDim2.new(0.5, 0, 0, 78), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 71, MaxSize = 8, Color = C.YellowHi })
		local band = frame(cc, { BackgroundTransparency = 0, BackgroundColor3 = r.Color, Size = UDim2.new(1, -10, 0, 16), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 70 })
		Kit.Corner(band, 7)
		Kit.Gradient(band, Kit.Shade(r.Color, 1.2), Kit.Shade(r.Color, 0.8))
		pixel(band, r.Name, { Size = UDim2.new(1, -6, 0, 8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 71, MaxSize = 8, Stroke = 1.5 })
		if it.Yard and not it.Lock then
			local y = frame(cc, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(70, 190, 80), Size = UDim2.fromOffset(40, 14), Position = UDim2.fromOffset(5, 5), ZIndex = 72 })
			Kit.Corner(y, 7)
			Kit.Stroke(y, C.Ink, 2)
			pixel(y, "YARD", { Size = UDim2.new(1, -4, 0, 7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 73, MaxSize = 7, Stroke = 1.5 })
		end
		if on then Kit.Glyph(cc, "Check", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -4, 0, 2), AnchorPoint = Vector2.new(1, 0), ZIndex = 74, Color = C.LimeHi }) end
		if it.Lock then
			local dim = frame(cc, { BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromRGB(16, 20, 24), Size = UDim2.fromScale(1, 1), ZIndex = 75 })
			Kit.Corner(dim, 10)
			Kit.Icon(dim, "Lock", { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 76 })
			pixel(dim, it.Lock, { Size = UDim2.new(1, -8, 0, 8), Position = UDim2.new(0.5, 0, 0, 56), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 76, MaxSize = 8 })
			pixel(dim, it.Unequip and "TAP TO UNEQUIP" or "CAN'T TRADE", { Size = UDim2.new(1, -8, 0, 7), Position = UDim2.new(0.5, 0, 0, 72), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 76, MaxSize = 7, Color = it.Unequip and C.YellowHi or C.Muted })
		end
		local hit = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 80, AutoButtonColor = false, Selectable = true }, cell) :: TextButton
		hit:SetAttribute("TradeItem", it.Id)
		local selBox = frame(nil :: any, { Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromOffset(-4, -4) })
		Kit.Stroke(selBox, C.YellowHi, 4)
		Kit.Corner(selBox, 14)
		hit.SelectionImageObject = selBox
		hit.Activated:Connect(function()
			if it.Unequip then
				local res = Net.Ask("UnequipCompanion", { Id = it.Id })
				if res and res.Ok then Kit.Toast("UNEQUIPPED - NOW YOU CAN TRADE IT", "Teal", "Dino") else Kit.Toast((res and res.Err) or "CAN'T", "Red", "Alert") end
				return
			end
			if it.Lock then
				Kit.Shake(cell)
				Kit.Toast(it.Lock == "STAR PEN" and "IT LIVES IN ITS STAR PEN - MOVE IT OUT FIRST" or (it.Lock == "IN A NEST" and "IT'S IN A NEST - ONLY BAG EGGS CAN BE TRADED" or "UNLOAD IT INTO YOUR BAG FIRST"), "Orange", "Lock")
				return
			end
			toggle(it.Kind, it.Id)
		end)
		first = first or hit
		if selId and selId == it.Id then reselect = hit end
	end
	if #list == 0 then
		pixel(sf, tab == "Dino" and "NO DINOS YET" or "NO EGGS IN YOUR BAG", { Size = UDim2.new(1, 0, 0, 12), ZIndex = 70, MaxSize = 12, Color = C.Muted })
	end
	w.FirstItem = first
	task.defer(function()
		if sf.Parent then sf.CanvasPosition = keep end
		if reselect and reselect.Parent then GuiService.SelectedObject = reselect end
	end)
end

local function mainAction()
	local s = state
	if not s or not win then return end
	if not synced() then Kit.Toast("ONE MOMENT...", "Grey") return end
	local res
	if s.Phase == "Confirm" then
		if s.Me.Confirm then return end
		res = Net.Ask("TradeConfirm", { Version = s.Version })
	elseif s.Me.Ready then
		res = Net.Ask("TradeReady", { On = false })
	else
		res = Net.Ask("TradeReady", { On = true, Version = s.Version })
	end
	if res and not res.Ok and res.Err and res.Err ~= "slow down" then Kit.Toast(res.Err, "Orange", "Alert") end
end

function renderStatus()
	local w = win
	local s = state
	if not (w and s) then return end
	local host = w.Status :: Frame
	clear(host)
	local _, cc = Kit.Card(host, { Size = UDim2.fromScale(1, 1), Color = "Card", ZIndex = 64 })
	local function row(y: number, name: string, side)
		local col = side.Confirm and C.YellowHi or (side.Ready and C.LimeHi or C.Muted)
		Kit.Text(cc, name, { Size = UDim2.new(1, -130, 0, 16), Position = UDim2.fromOffset(14, y), Align = Enum.TextXAlignment.Left, ZIndex = 68, MaxSize = 16, Stroke = 2.5, Shadow = 2, Color = C.Cream })
		pixel(cc, side.Confirm and "CONFIRMED" or (side.Ready and "READY" or "NOT READY"), { Size = UDim2.fromOffset(110, 9), Position = UDim2.new(1, -14, 0, y + 4), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 68, MaxSize = 9, Color = col })
	end
	row(12, "YOU", s.Me)
	row(38, upper(s.Them.Name), s.Them)
	-- the middle: what happens next
	local them = upper(s.Them.Name)
	local big, small = "", ""
	if s.Phase == "Countdown" then
		small = "CHECK BOTH SIDES!"
	elseif s.Phase == "Confirm" then
		big = s.Me.Confirm and "" or "LAST CHECK!"
		small = s.Me.Confirm and ("WAITING FOR " .. them .. " TO CONFIRM") or "PRESS CONFIRM TO TRADE"
	elseif s.Me.Ready then
		small = "WAITING FOR " .. them .. "..."
	else
		small = (#s.Me.Items + #s.Them.Items == 0) and "PICK DINOS OR EGGS BELOW" or "HAPPY? PRESS READY"
	end
	local count = Kit.Text(cc, big, { Name = "Count", Size = UDim2.new(1, -20, 0, s.Phase == "Countdown" and 50 or 28), Position = UDim2.new(0.5, 0, 0, s.Phase == "Countdown" and 66 or 74), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 68, MaxSize = s.Phase == "Countdown" and 50 or 28, Stroke = 4, Shadow = 3, Color = s.Phase == "Confirm" and C.YellowHi or C.LimeHi })
	w.Count = s.Phase == "Countdown" and count or nil
	w.CountShown = -1
	pixel(cc, small, { Size = UDim2.new(1, -20, 0, 9), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 68, MaxSize = 9, Color = C.Cream })
	-- red line: they just changed their offer, or you're getting nothing back
	local warnText = nil
	if os.clock() < warnUntil then warnText = them .. " CHANGED THEIR OFFER!"
	elseif #s.Them.Items == 0 and #s.Me.Items > 0 then warnText = "YOU GET NOTHING BACK!" end
	if warnText then
		local wl = pixel(cc, warnText, { Size = UDim2.new(1, -20, 0, 9), Position = UDim2.new(0.5, 0, 0, 136), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 68, MaxSize = 9, Color = C.RedHi })
		Kit.Pop(wl :: any, 0.6)
	end
	-- the big button
	local pad = Kit.Gamepad()
	local text, color, disabled, shine = "READY", "Lime", false, true
	if s.Phase == "Confirm" then
		if s.Me.Confirm then text, color, disabled, shine = "WAITING...", "Grey", true, false
		else text, color = "CONFIRM TRADE", "Yellow" end
	elseif s.Me.Ready then
		text, color, shine = "NOT READY", "Grey", false
	elseif #s.Me.Items + #s.Them.Items == 0 then
		disabled, color, shine = true, "Grey", false
	end
	if pad and not disabled then text ..= " [Y]" end
	local mainBtn, mainHit = Kit.Button(cc, { Name = "Main", Text = text, Color = color, Size = UDim2.new(1, -24, 0, 56), Position = UDim2.new(0.5, 0, 0, 154), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 70, MaxText = 26, Lip = 5, Shine = shine, Disabled = disabled, OnClick = mainAction })
	w.MainHit = mainHit
	if s.Phase == "Confirm" and not s.Me.Confirm then Kit.Punch(mainBtn, 0.12) end
	Kit.Button(cc, { Name = "Cancel", Text = pad and "CANCEL [B]" or "CANCEL TRADE", Color = "Red", Size = UDim2.new(1, -24, 0, 34), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 70, MaxText = 16, Lip = 4, OnClick = cancel })
end

local function openWindow(st)
	closeWindow()
	hideRequest()
	if TradeView.OnOpen then pcall(TradeView.OnOpen :: any) end
	-- (the Bag / shop drawer would sit under the window: close it)
	pcall(function() require(script.Parent.UI.Panels).Close() end)
	if not gui then gui, canvas = Kit.Screen("DinoTrade", 34) end
	desired, tab, sending, resend, warnUntil = nil, "Dino", false, false, 0
	local root, inner = Kit.Window(canvas, { Name = "Trade", Title = "TRADE WITH " .. upper(st.Them.Name), Color = "Teal", Icon = "Gift", Size = UDim2.fromOffset(900, 540), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Fit = true, ZIndex = 60, OnClose = cancel })
	Kit.Enter(root)
	local w = {
		Id = st.Id, Root = root,
		Mine = frame(inner, { Name = "Mine", Size = UDim2.fromOffset(424, 186), Position = UDim2.fromOffset(0, 0), ZIndex = 62 }),
		Theirs = frame(inner, { Name = "Theirs", Size = UDim2.fromOffset(424, 186), Position = UDim2.fromOffset(436, 0), ZIndex = 62 }),
		Picker = frame(inner, { Name = "Picker", Size = UDim2.fromOffset(560, 254), Position = UDim2.fromOffset(0, 198), ZIndex = 62 }),
		Status = frame(inner, { Name = "Status", Size = UDim2.fromOffset(288, 248), Position = UDim2.fromOffset(572, 200), ZIndex = 62 }),
	} :: any
	-- the arrow between the boards: a swap
	local mid = frame(inner, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(430, 93), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = C.Yellow, ZIndex = 80 })
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, mid)
	Kit.Stroke(mid, C.Ink, 3)
	Kit.Text(mid, "<>", { Size = UDim2.fromScale(0.7, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 81, MaxSize = 16, Stroke = 2.5, Shadow = 0 })
	win = w
	-- the countdown ticks on the client between the server's messages (the server keeps the real clock)
	w.Conn = RunService.Heartbeat:Connect(function()
		local s = state
		if not (win == w and s and w.Count and s.CountLeft) then return end
		local left = math.max(0, math.ceil(s.CountLeft - (os.clock() - stateAt)))
		if left ~= w.CountShown then
			w.CountShown = left
			Kit.SetText(w.Count, left > 0 and tostring(left) or "...")
			Kit.Punch(w.Count, 0.25)
			if left > 0 then Kit.Sound("Click", 0.5, 1 + (T.Countdown - left) * 0.06) end
		end
	end)
	ContextActionService:BindActionAtPriority("DinoTradeMain", function(_, st2)
		if st2 == Enum.UserInputState.Begin then task.spawn(mainAction) end
		return Enum.ContextActionResult.Sink
	end, false, 2300, Enum.KeyCode.ButtonY)
	ContextActionService:BindActionAtPriority("DinoTradeCancel", function(_, st2)
		if st2 ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		if os.clock() < cancelArmed then cancelArmed = 0 task.spawn(cancel)
		else cancelArmed = os.clock() + 2 Kit.Toast("PRESS B AGAIN TO CANCEL THE TRADE", "Orange", "Alert") end
		return Enum.ContextActionResult.Sink
	end, false, 2300, Enum.KeyCode.ButtonB)
	Kit.Sound("Pop", 0.6)
end

local function onState(st)
	if typeof(st) ~= "table" or typeof(st.Me) ~= "table" or typeof(st.Them) ~= "table" then return end
	if finished[st.Id] then return end
	local fresh = not win or win.Id ~= st.Id
	if fresh then openWindow(st) end
	local prev = state
	state, stateAt = st, os.clock()
	if desired and not sending and sameSet(desired, serverMine()) then desired = nil end
	renderBoards()
	renderStatus()
	renderPicker()
	if fresh and Kit.Gamepad() and win and win.FirstItem then GuiService.SelectedObject = win.FirstItem end
	if st.Changed == "Them" then
		warnUntil = os.clock() + 4
		renderStatus()
		if win and win.TheirBoard then Kit.Shake(win.TheirBoard) end
		Kit.Toast(upper(st.Them.Name) .. " CHANGED THEIR OFFER - CHECK IT!", "Orange", "Alert")
	end
	if prev and prev.Phase ~= "Confirm" and st.Phase == "Confirm" then Kit.Sound("Confirm") end
	if prev and prev.Phase ~= "Countdown" and st.Phase == "Countdown" then Kit.Sound("Pop", 0.7) end
end

local function onClosed(info)
	if not win then return end
	if typeof(info) == "table" and info.Id and win.Id ~= info.Id then return end
	closeWindow()
	Kit.Toast(typeof(info) == "table" and info.Text or "TRADE CANCELLED", "Orange", "Alert")
end

--------------------------------------------------------------------------------
-- TRADE COMPLETE
--------------------------------------------------------------------------------
local doneGui, doneCanvas
local CONFETTI = { Color3.fromHex("FFD447"), Color3.fromHex("66D86B"), Color3.fromHex("48A8FF"), Color3.fromHex("AD66FF"), Color3.fromHex("FF5252"), Color3.fromHex("FFFFFF") }
local function confetti(parent: Frame)
	local size = parent.AbsoluteSize
	local scale = parent:FindFirstChildOfClass("UIScale")
	local k = scale and scale.Scale or 1
	local w, h = math.max(size.X / k, 400), math.max(size.Y / k, 300)
	for i = 1, 80 do
		task.delay(i * 0.012, function()
			local c = CONFETTI[math.random(#CONFETTI)]
			local bit = frame(parent, { BackgroundTransparency = 0, BackgroundColor3 = c, Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)), Position = UDim2.fromOffset(w * math.random(), -30), Rotation = math.random(0, 360), ZIndex = 200 })
			Kit.Stroke(bit, C.Ink, 1.5)
			local t = 1.6 + math.random() * 1.4
			TweenService:Create(bit, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(bit.Position.X.Offset + (math.random() - 0.5) * 260, h + 40), Rotation = bit.Rotation + math.random(-540, 540),
			}):Play()
			task.delay(t, function() bit:Destroy() end)
		end)
	end
end

local function itemCard(parent: Instance, it, x: number, y: number, w: number, h: number, best: boolean)
	local r = rarityOf(it.Rarity)
	local holder = frame(parent, { Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, y), ZIndex = 84 })
	local outer, cc = Kit.Card(holder, { Size = UDim2.fromScale(1, 1), Color = "Card", Border = r.Color, ZIndex = 84 })
	if best then Kit.Shine(outer:FindFirstChild("Body") :: Frame, 2.4) end
	local isz = math.min(w - 20, h - 50)
	Kit.Icon(cc, it.Kind == "Egg" and "Egg" or "Dino", { Species = it.Species, Size = UDim2.fromOffset(it.Kind == "Egg" and isz * 0.7 or isz, isz), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 88 })
	Kit.Text(cc, speciesName(it.Species) .. (it.Kind == "Egg" and " EGG" or ""), { Size = UDim2.new(1, -10, 0, 13), Position = UDim2.new(0.5, 0, 1, -44), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 89, MaxSize = 13, Stroke = 2.5, Shadow = 2, Color = C.Cream })
	pixel(cc, kg(it.KG), { Size = UDim2.new(1, -10, 0, 8), Position = UDim2.new(0.5, 0, 1, -29), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 89, MaxSize = 8, Color = C.YellowHi })
	local band = frame(cc, { BackgroundTransparency = 0, BackgroundColor3 = r.Color, Size = UDim2.new(1, -10, 0, 14), Position = UDim2.new(0.5, 0, 1, -5), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 88 })
	Kit.Corner(band, 7)
	Kit.Gradient(band, Kit.Shade(r.Color, 1.2), Kit.Shade(r.Color, 0.8))
	pixel(band, r.Name, { Size = UDim2.new(1, -6, 0, 8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 89, MaxSize = 8, Stroke = 1.5 })
	return holder
end

local function celebrate(info)
	closeWindow()
	if typeof(info) ~= "table" then return end
	if info.Id then finished[info.Id] = true end
	if not doneGui then doneGui, doneCanvas = Kit.Screen("DinoTradeDone", 46) end
	local got, gave = table.clone(info.Got or {}), info.Gave or {}
	table.sort(got, function(a, b)
		local ra, rb = rarityOf(a.Rarity).Order, rarityOf(b.Rarity).Order
		if ra ~= rb then return ra > rb end
		return (a.KG or 0) > (b.KG or 0)
	end)
	local root: Frame
	local function done()
		if root and root.Parent then Kit.Exit(root, true) end
		GuiService.SelectedObject = nil
	end
	local title = #got > 0 and "TRADE COMPLETE!" or "GIFT SENT!"
	local r0, inner = Kit.Window(doneCanvas, { Name = "TradeDone", Title = title, Color = "Yellow", Icon = "Gift", Size = UDim2.fromOffset(700, 440), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Fit = true, ZIndex = 80, OnClose = done })
	root = r0
	Kit.Enter(root)
	local who = upper(info.Name)
	pixel(inner, #got > 0 and ("YOU GOT FROM " .. who) or ("YOU GAVE " .. who .. " A GIFT"), { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 2), ZIndex = 84, MaxSize = 12, Color = C.YellowHi })
	local cards = {}
	local shown = #got > 0 and got or gave
	local n = #shown
	local perRow = n <= 4 and math.max(n, 1) or 4
	local cw, ch = n <= 4 and 150 or 146, n <= 4 and 190 or 118
	local rows = math.ceil(n / perRow)
	local top = rows == 1 and 34 or 24
	for i, it in ipairs(shown) do
		local row = math.floor((i - 1) / perRow)
		local col = (i - 1) % perRow
		local inRow = math.min(perRow, n - row * perRow)
		local x = (660 - inRow * cw - (inRow - 1) * 10) / 2 + col * (cw + 10)
		table.insert(cards, itemCard(inner, it, x, top + row * (ch + 10), cw, ch, i == 1 and #got > 0))
	end
	if #got > 0 and #gave > 0 then
		local d, e = 0, 0
		for _, it in ipairs(gave) do if it.Kind == "Egg" then e += 1 else d += 1 end end
		local parts = {}
		if d > 0 then table.insert(parts, d .. (d == 1 and " DINO" or " DINOS")) end
		if e > 0 then table.insert(parts, e .. (e == 1 and " EGG" or " EGGS")) end
		pixel(inner, "YOU GAVE " .. table.concat(parts, " + "), { Size = UDim2.new(1, 0, 0, 9), Position = UDim2.new(0, 0, 1, -62), ZIndex = 84, MaxSize = 9, Color = C.Muted })
	end
	local _, okHit = Kit.Button(inner, { Text = "AWESOME!", Color = "Lime", Size = UDim2.fromOffset(240, 48), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 86, MaxText = 24, Shine = true, OnClick = done })
	Kit.Stagger(cards, 0.09, 0.2)
	confetti(doneCanvas)
	Kit.Sound("Confirm")
	pcall(function() require(script.Parent.Audio).Sting("Payout", 0.7) end)
	if Kit.Gamepad() then GuiService.SelectedObject = okHit end
end

--------------------------------------------------------------------------------
-- the profile card's TRADE button
--------------------------------------------------------------------------------
function TradeView.Request(target: Player)
	local res = Net.Ask("TradeRequest", { UserId = target.UserId })
	if res and res.Ok then
		if res.Time then Kit.Toast("TRADE REQUEST SENT TO " .. upper(target.DisplayName), "Teal", "Gift") end
	else
		Kit.Toast((res and res.Err) or "CAN'T TRADE RIGHT NOW", "Red", "Alert")
	end
end

-- props: Size, Position, AnchorPoint, ZIndex. Greys itself out (with a lock) when the server says you can't.
function TradeView.CardButton(parent: Instance, target: Player, props)
	local why: string? = nil
	local outer = Kit.Button(parent, {
		Name = "Trade", Text = "TRADE", Icon = "Gift", IconSize = 0.92, TextLeft = 0.4, Color = "Lime", Shine = true,
		Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex, MaxText = 26, Lip = 5,
		OnClick = function()
			if why then Kit.Toast(why, "Orange", "Lock") return end
			TradeView.Request(target)
		end,
	})
	task.spawn(function()
		local res = Net.Ask("TradeCheck", { UserId = target.UserId })
		if not outer.Parent or not (res and res.Ok) or res.Can then return end
		why = res.Err or "CAN'T TRADE RIGHT NOW"
		Kit.SetPanelColor(outer, "Grey")
		local body = outer:FindFirstChild("Body")
		if body then Kit.Icon(body, "Lock", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -4, 0, -8), AnchorPoint = Vector2.new(1, 0), ZIndex = (props.ZIndex or 3) + 7 }) end
	end)
	return outer
end

function TradeView.IsOpen(): boolean
	return win ~= nil
end

function TradeView.Start()
	Net.On("TradeRequest", showRequest)
	Net.On("TradeRequestGone", function(info)
		if reqOpen and typeof(info) == "table" and reqOpen.Id == info.Id then hideRequest() end
	end)
	Net.On("TradeState", onState)
	Net.On("TradeClosed", onClosed)
	Net.On("TradeDone", celebrate)
	-- your bag changed (a companion unequipped, a run's eggs landed): the picker redraws
	local queued = false
	Net.On("Profile", function()
		if not win or queued then return end
		queued = true
		task.defer(function()
			queued = false
			if win then renderPicker() end
		end)
	end)
	-- joined (or the client restarted) mid-trade: pick it back up
	task.spawn(function()
		local res = Net.Ask("TradeSync", {})
		if res and res.Ok and res.State and not win then onState(res.State) end
	end)
end

return TradeView
