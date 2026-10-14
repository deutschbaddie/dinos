--[[
	AdminPanel — the Settings > ADMIN tab (owner + admins from Admins.luau; the server checks every request).
	Left: everyone in this server. Right: what you can do to the one you picked (go to, bring, send home, freeze,
	respawn, spectate, kick, bans; the owner can also gift coins / eggs), then the server tools (announce, wake
	the boss, and for the owner: every-server announce, ban / unban by name, shutdown) and the recent admin log.
	Kicks, bans and shutdown need a second tap. Also shows admin announcements to every player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local AdminLink = require(script.Parent.Parent.AdminLink)

local player = Players.LocalPlayer
local C = Theme.C
local AdminPanel = {}

local state = { Selected = nil :: number?, Confirm = nil :: string?, Reason = "", Message = "", Name = "" }

local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	for k, v in pairs(props or {}) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end

local function label(parent: Instance, s: string, props)
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2.5
	props.Shadow = props.Shadow or 2
	return Kit.Text(parent, s, props)
end

local function pixel(parent: Instance, s: string, props)
	props.Pixel = true
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2
	props.Shadow = props.Shadow or 1
	props.MaxSize = props.MaxSize or 11
	return Kit.Text(parent, s, props)
end

local function corner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function input(parent: Instance, placeholder: string, value: string, onChange: (string) -> (), order: number)
	local box = frame(parent, { Size = UDim2.new(1, -8, 0, 40), BackgroundTransparency = 0.1, BackgroundColor3 = C.InkSoft, LayoutOrder = order, ZIndex = 25 })
	corner(box, 10)
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = C.Ink
	st.Parent = box
	local tb = Instance.new("TextBox")
	tb.BackgroundTransparency = 1
	tb.Size = UDim2.new(1, -20, 1, -10)
	tb.Position = UDim2.fromOffset(10, 5)
	tb.FontFace = Kit.Font
	tb.TextScaled = true
	tb.TextColor3 = C.Cream
	tb.PlaceholderText = placeholder
	tb.PlaceholderColor3 = C.Muted
	tb.Text = value
	tb.ClearTextOnFocus = false
	tb.TextXAlignment = Enum.TextXAlignment.Left
	tb.ZIndex = 27
	tb.Parent = box
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 20
	cap.Parent = tb
	tb:GetPropertyChangedSignal("Text"):Connect(function() onChange(tb.Text) end)
	return box
end

local function heading(parent: Instance, s: string, order: number)
	local h = frame(parent, { Size = UDim2.new(1, -8, 0, 26), LayoutOrder = order, ZIndex = 25 })
	label(h, s, { Size = UDim2.fromScale(1, 1), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 22, Color = C.YellowHi })
	return h
end

local function grid(parent: Instance, order: number): Frame
	local g = frame(parent, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, ZIndex = 25 })
	local lay = Instance.new("UIGridLayout")
	lay.CellSize = UDim2.new(1 / 3, -8, 0, 48)
	lay.CellPadding = UDim2.fromOffset(8, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = g
	return g
end

--------------------------------------------------------------------------------
-- spectating (client camera only)
--------------------------------------------------------------------------------
local spectating: Player? = nil
local stopGui: ScreenGui? = nil

local function stopSpectate()
	spectating = nil
	local cam = Workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if cam and hum then cam.CameraSubject = hum end
	if stopGui then stopGui:Destroy() stopGui = nil end
end

local function spectate(target: Player)
	local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	local cam = Workspace.CurrentCamera
	if not (hum and cam) then Kit.Toast("THEY HAVE NO CHARACTER", "Red", "Alert") return end
	spectating = target
	cam.CameraSubject = hum
	if stopGui then stopGui:Destroy() end
	local gui, canvas = Kit.Screen("DinoSpectate", 28)
	stopGui = gui
	label(canvas, "WATCHING " .. string.upper(target.Name), { Size = UDim2.fromOffset(420, 30), Position = UDim2.new(0.5, 0, 1, -150), AnchorPoint = Vector2.new(0.5, 1), MaxSize = 28, ZIndex = 5 })
	Kit.Button(canvas, { Text = "STOP WATCHING", Icon = "Eye", IconSize = 0.85, TextLeft = 0.24, Color = "Red", Size = UDim2.fromOffset(260, 56), Position = UDim2.new(0.5, 0, 1, -84), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 6, OnClick = stopSpectate })
end

Players.PlayerRemoving:Connect(function(p) if p == spectating then stopSpectate() end end)

--------------------------------------------------------------------------------
-- announcements (every player)
--------------------------------------------------------------------------------
local annGui, annCanvas
Net.On("AdminAnnounce", function(d)
	if typeof(d) ~= "table" or typeof(d.Text) ~= "string" then return end
	if not annGui then annGui, annCanvas = Kit.Screen("DinoAnnounce", 34, false, 0.8) end
	for _, c in ipairs(annCanvas:GetChildren()) do c:Destroy() end
	Kit.Sound("Toast")
	local card, cc = Kit.Card(annCanvas, { Size = UDim2.fromOffset(760, 132), Position = UDim2.new(0.5, 0, 0, 96), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 40, Border = C.YellowHi })
	Kit.Icon(cc, "Alert", { Size = UDim2.fromOffset(72, 72), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 43, Rotation = -8 })
	pixel(cc, "ANNOUNCEMENT" .. ((d.From and d.From ~= "") and ("  -  " .. string.upper(d.From)) or ""), { Size = UDim2.new(1, -110, 0, 12), Position = UDim2.fromOffset(94, 14), Align = Enum.TextXAlignment.Left, ZIndex = 43, MaxSize = 12, Color = C.YellowHi })
	local msg = label(cc, d.Text, { Size = UDim2.new(1, -110, 1, -46), Position = UDim2.fromOffset(94, 34), Align = Enum.TextXAlignment.Left, ZIndex = 43, MaxSize = 30 })
	for _, l in ipairs(msg:GetChildren()) do if l:IsA("TextLabel") then l.TextWrapped = true end end
	Kit.Pop(card, 0.6)
	task.delay(8, function() if card.Parent then Kit.Exit(card, true) end end)
end)

--------------------------------------------------------------------------------
-- the tab
--------------------------------------------------------------------------------
local function fmtTime(secs: number): string
	if secs < 3600 then return math.floor(secs / 60) .. "M" end
	return string.format("%dH %02dM", secs // 3600, (secs % 3600) // 60)
end

-- ui: { Refresh = fn }. Returns the first button (gamepad selection).
function AdminPanel.Build(body: Frame, ui)
	local res = Net.Ask("Admin", { Action = "List" })
	if not (res and res.Ok) then
		label(body, (res and res.Err) or "CAN'T REACH THE SERVER", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 26, MaxSize = 26 })
		return nil
	end
	local owner = res.Role == "Owner"
	local canBan = res.CanBan == true -- (SickleEdge and NotTufferson only; every other admin kicks)
	local first = nil
	local function act(action: string, args, confirmKey: string?)
		if confirmKey and state.Confirm ~= confirmKey then
			state.Confirm = confirmKey
			ui.Refresh()
			return
		end
		state.Confirm = nil
		args = args or {}
		args.Action = action
		local r = Net.Ask("Admin", args)
		Kit.Toast((r and r.Ok) and (r.Message or "DONE") or ((r and r.Err) or "FAILED"), (r and r.Ok) and "Teal" or "Red", (r and r.Ok) and "Crown" or "Alert")
		ui.Refresh()
	end
	local function button(parent: Instance, order: number, text: string, icon: string, color: string, fn, confirmKey: string?)
		local holder = frame(parent, { LayoutOrder = order })
		local armed = confirmKey ~= nil and state.Confirm == confirmKey
		local _, hit = Kit.Button(holder, { Text = armed and "TAP AGAIN" or text, Icon = icon, IconSize = 0.85, TextLeft = 0.3, TextSize = 0.34, MaxText = 15, Color = armed and "Red" or color, Size = UDim2.fromScale(1, 0.92), ZIndex = 26, Lip = 4, Radius = 12, OnClick = fn })
		first = first or hit
	end

	-- left: everyone in the server
	local selected = nil
	for _, row in ipairs(res.Players) do if row.UserId == state.Selected then selected = row end end
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(0.36, -6, 1, 0)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = C.LimeHi
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 22
	list.Parent = body
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 6)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = list
	local lp = Instance.new("UIPadding")
	lp.PaddingTop, lp.PaddingLeft, lp.PaddingRight = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 10)
	lp.Parent = list
	pixel(frame(list, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 0 }), `{res.Server.Players}/{res.Server.Max} PLAYERS  -  UP {fmtTime(res.Server.Uptime)}`, { Size = UDim2.fromScale(1, 1), Align = Enum.TextXAlignment.Left, ZIndex = 26, Color = C.Muted, MaxSize = 10 })
	for i, row in ipairs(res.Players) do
		local on = row.UserId == state.Selected
		local card, cc = Kit.Card(list, { Size = UDim2.new(1, 0, 0, 62), ZIndex = 24, LayoutOrder = i, Border = on and C.YellowHi or nil })
		local head = Instance.new("ImageLabel")
		head.BackgroundColor3 = C.InkSoft
		head.Image = `rbxthumb://type=AvatarHeadShot&id={row.UserId}&w=150&h=150`
		head.Size = UDim2.fromOffset(44, 44)
		head.Position = UDim2.new(0, 6, 0.5, 0)
		head.AnchorPoint = Vector2.new(0, 0.5)
		head.ZIndex = 27
		head.Parent = cc
		corner(head, 22)
		label(cc, row.DisplayName, { Size = UDim2.new(1, -64, 0, 20), Position = UDim2.fromOffset(58, 8), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 18 })
		local tags = { "@" .. row.Name }
		if row.Role then table.insert(tags, string.upper(row.Role) .. (row.Granted and " (MADE)" or "")) elseif row.Tester then table.insert(tags, "TESTER") end
		if row.Frozen then table.insert(tags, "FROZEN") end
		if row.Run then table.insert(tags, string.upper(row.Run)) end
		pixel(cc, table.concat(tags, "  "), { Size = UDim2.new(1, -64, 0, 9), Position = UDim2.fromOffset(58, 36), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 9, Color = row.Role and C.OrangeHi or C.Muted })
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 40
		hit.Parent = card
		hit.Activated:Connect(function()
			Kit.Sound("Click", 0.4)
			state.Selected = row.UserId
			state.Confirm = nil
			ui.Refresh()
		end)
	end

	-- right: actions
	local right = Instance.new("ScrollingFrame")
	right.BackgroundTransparency = 1
	right.BorderSizePixel = 0
	right.Size = UDim2.new(0.64, -6, 1, 0)
	right.Position = UDim2.new(0.36, 6, 0, 0)
	right.ScrollBarThickness = 8
	right.ScrollBarImageColor3 = C.LimeHi
	right.AutomaticCanvasSize = Enum.AutomaticSize.Y
	right.CanvasSize = UDim2.new()
	right.ZIndex = 22
	right.Parent = body
	local rl = Instance.new("UIListLayout")
	rl.Padding = UDim.new(0, 8)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = right
	local rp = Instance.new("UIPadding")
	rp.PaddingTop, rp.PaddingLeft, rp.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 12)
	rp.Parent = right
	local o = 0
	local function nexto() o += 1 return o end

	if selected then
		local id = selected.UserId
		local me = id == player.UserId
		heading(right, string.upper(selected.DisplayName) .. (me and "  (YOU)" or ""), nexto())
		local info = frame(right, { Size = UDim2.new(1, -8, 0, 12), LayoutOrder = nexto() })
		pixel(info, `POWER {Config.FormatNumber(selected.Power)}  -  COINS {Config.FormatNumber(selected.Coins)}{selected.Run and ("  -  ON A RUN IN " .. string.upper(selected.Run)) or ""}`, { Size = UDim2.fromScale(1, 1), Align = Enum.TextXAlignment.Left, ZIndex = 26, Color = C.Muted })
		if not selected.CanTarget and not me then
			local note = frame(right, { Size = UDim2.new(1, -8, 0, 12), LayoutOrder = nexto() })
			pixel(note, "STAFF: YOU CAN ONLY GO TO THEM OR WATCH THEM", { Size = UDim2.fromScale(1, 1), Align = Enum.TextXAlignment.Left, ZIndex = 26, Color = C.OrangeHi })
		end
		local g = grid(right, nexto())
		local n = 0
		local function b(...) n += 1 button(g, n, ...) end
		if not me then
			b("GO TO", "Map", "Blue", function() act("GoTo", { UserId = id }) end)
			b(spectating and spectating.UserId == id and "STOP WATCH" or "SPECTATE", "Eye", "Purple", function()
				local t = Players:GetPlayerByUserId(id)
				if AdminLink.Watching() then AdminLink.Unwatch() end
				if spectating and spectating.UserId == id then stopSpectate() elseif t then spectate(t) end
				ui.Refresh()
			end)
			-- the owner: their exact camera, in their world's light - they're never told
			if owner then
				local w = AdminLink.Watching()
				b(w and w.UserId == id and "STOP WATCH" or "WATCH (SILENT)", "Eye", "Purple", function()
					local t = Players:GetPlayerByUserId(id)
					if w and w.UserId == id then
						AdminLink.Unwatch()
					elseif t then
						if spectating then stopSpectate() end
						local ok, err = AdminLink.Watch(t)
						if not ok then Kit.Toast(err or "FAILED", "Red", "Alert") end
					end
					ui.Refresh()
				end)
			end
		end
		if selected.CanTarget then
			b("BRING", "Hand", "Blue", function() act("Bring", { UserId = id }) end)
			b("SEND HOME", "Home", "Teal", function() act("SendHome", { UserId = id }) end)
			b(selected.Frozen and "UNFREEZE" or "FREEZE", "Lock", "Teal", function() act(selected.Frozen and "Unfreeze" or "Freeze", { UserId = id }) end)
			b("RESPAWN", "Star", "Teal", function() act("Respawn", { UserId = id }) end)
		end
		-- making admins: the owner only (they can kick, never ban). Only admins made here can be removed here
		if owner and not me then
			if not selected.Role then
				b("MAKE ADMIN", "Crown", "Orange", function() act("MakeAdmin", { UserId = id }, "Make" .. id) end, "Make" .. id)
			elseif selected.Granted then
				b("REMOVE ADMIN", "Crown", "Red", function() act("RemoveAdmin", { UserId = id }, "Remove" .. id) end, "Remove" .. id)
			end
		end
		if owner then
			b("+10K COINS", "Coin", "Yellow", function() act("GiveCoins", { UserId = id, Amount = 10000 }) end)
			b("+1M COINS", "Coin", "Yellow", function() act("GiveCoins", { UserId = id, Amount = 1000000 }) end)
			b("LEGENDARY EGG", "Egg", "Lime", function() act("GiveEgg", { UserId = id, Rarity = "Legendary" }) end)
		end
		if selected.CanTarget then
			input(right, "REASON (OPTIONAL, SHOWN TO THEM)", state.Reason, function(t) state.Reason = t end, nexto())
			local g2 = grid(right, nexto())
			local m = 0
			local function d(...) m += 1 button(g2, m, ...) end
			d("KICK", "Door", "Orange", function() act("Kick", { UserId = id, Reason = state.Reason }, "Kick" .. id) end, "Kick" .. id)
			if canBan then
				d("BAN 1 HOUR", "Clock", "Red", function() act("Ban", { UserId = id, Length = "1h", Reason = state.Reason }, "Ban1h" .. id) end, "Ban1h" .. id)
				d("BAN 1 DAY", "Clock", "Red", function() act("Ban", { UserId = id, Length = "1d", Reason = state.Reason }, "Ban1d" .. id) end, "Ban1d" .. id)
				d("BAN 7 DAYS", "Clock", "Red", function() act("Ban", { UserId = id, Length = "7d", Reason = state.Reason }, "Ban7d" .. id) end, "Ban7d" .. id)
				d("BAN FOREVER", "Alert", "Red", function() act("Ban", { UserId = id, Length = "Forever", Reason = state.Reason }, "BanF" .. id) end, "BanF" .. id)
			end
		end
	else
		heading(right, "PICK A PLAYER ON THE LEFT", nexto())
	end

	-- server tools
	heading(right, "THIS SERVER", nexto())
	input(right, "ANNOUNCEMENT", state.Message, function(t) state.Message = t end, nexto())
	local sg = grid(right, nexto())
	local k = 0
	local function s(...) k += 1 button(sg, k, ...) end
	local function send(everywhere: boolean)
		local text = state.Message
		state.Message = ""
		act("Announce", { Text = text, Everywhere = everywhere })
	end
	s("ANNOUNCE", "Alert", "Yellow", function() send(false) end)
	if owner then s("ALL SERVERS", "Alert", "Orange", function() send(true) end) end
	s("WAKE BOSS", "Trophy", "Teal", function() act("WakeBoss") end)
	s("2X LUCK", "Star", "Yellow", function() act("LuckEvent") end) -- (15 min for this server; again = +15 min)
	s("WEATHER", "Bolt", "Purple", function() act("Weather") end) -- (the next weather in line, rolling in now)
	s("METEORS", "Star", "Orange", function() act("Meteors") end) -- (a meteor shower over Base Camp)
	if owner then s("SHUTDOWN", "Door", "Red", function() act("Shutdown", {}, "Shutdown") end, "Shutdown") end

	if canBan then
		heading(right, "BANS (ANY PLAYER, BY USERNAME)", nexto())
		input(right, "USERNAME", state.Name, function(t) state.Name = t end, nexto())
		local bg = grid(right, nexto())
		local j = 0
		local function bb(...) j += 1 button(bg, j, ...) end
		bb("BAN FOREVER", "Alert", "Red", function() act("BanName", { Name = state.Name, Reason = state.Reason }, "BanName") end, "BanName")
		bb("UNBAN", "Key", "Lime", function() act("Unban", { Name = state.Name }) end)
	end

	heading(right, "ADMIN LOG", nexto())
	if #res.Log == 0 then
		pixel(frame(right, { Size = UDim2.new(1, -8, 0, 12), LayoutOrder = nexto() }), "NOTHING YET ON THIS SERVER", { Size = UDim2.fromScale(1, 1), Align = Enum.TextXAlignment.Left, ZIndex = 26, Color = C.Muted })
	end
	for _, e in ipairs(res.Log) do
		local ago = math.max(0, (res.ServerTime or e.T) - e.T)
		local line = frame(right, { Size = UDim2.new(1, -8, 0, 12), LayoutOrder = nexto() })
		pixel(line, string.upper(`{fmtTime(ago)} AGO  {e.Text}`), { Size = UDim2.fromScale(1, 1), Align = Enum.TextXAlignment.Left, ZIndex = 26, Color = C.Cream, MaxSize = 9 })
	end
	return first
end

return AdminPanel
