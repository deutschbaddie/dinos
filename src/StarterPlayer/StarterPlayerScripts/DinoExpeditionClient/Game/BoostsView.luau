--[[
	BoostsView — every boost you have running, and the server-wide 2x LUCK event (server: Boosts.luau).

	  the strip    top-left: one chip per active boost (2x LUCK EVENT, FRIENDS HERE, LUCK BOOST, TEAM LUCK...) - its
	               icon, its biggest number and, for a timed one, a countdown. Tap a chip: what it does. Quiet sources
	               (the Index's permanent bonus) count but never show.
	  the event    when a 2x LUCK starts: a big banner for everyone (who started it, if someone did), a chime; when it
	               grows: "+N MIN"; when it ends: a toast. A late joiner sees the chip from the start.
	Messages: "Boosts" { List, Totals, T } (just yours), "LuckEvent" { Ends, Mult, By?, Extended?, Minutes, Ended? }.
]]

local RunService = game:GetService("RunService")

local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local Audio = require(script.Parent.Audio)

local C = Theme.C
local BoostsView = {}

local canvas: Frame? = nil
local strip: Frame? = nil
local banner: any = nil
local list = {} :: { any }
local offset = 0 -- server os.time() - local os.time(), from the last message
local chips = {} :: { [string]: { Frame: Frame, Timer: Instance?, Ends: number? } }
local sig = ""

local function now(): number
	return os.time() + offset
end

local function clock(sec: number): string
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then return string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60) end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function ensure()
	if canvas then return end
	local _, cv = Kit.Screen("DinoBoosts", 11, false, 0.6)
	canvas = cv
	local s = Instance.new("Frame")
	s.Name = "Strip"
	s.BackgroundTransparency = 1
	s.Size = UDim2.fromOffset(560, 84)
	s.Position = UDim2.fromOffset(22, 14)
	s.Parent = cv
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.Padding = UDim.new(0, 10)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = s
	strip = s
	banner = Kit.Banner(cv, { Position = UDim2.new(0.5, 0, 0, 150), ZIndex = 30 })
end

local function chip(e, order: number)
	local holder = Instance.new("Frame")
	holder.Name = "Chip_" .. tostring(e.Id)
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(92, 84)
	holder.LayoutOrder = order
	holder.Parent = strip
	local _, content = Kit.Brick(holder, { Size = UDim2.fromOffset(92, 62), Color = e.Color or "Lime", Radius = 14, Lip = 4, ZIndex = 4, Stripes = 0.85 })
	Kit.Icon(content, e.Icon or "Star", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, -8, 0.5, -2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 8, Rotation = -8 })
	Kit.Text(content, tostring(e.Short or ""), { Size = UDim2.new(1, -38, 0, 26), Position = UDim2.new(1, -4, 0.5, -2), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 8, Stroke = 3.5, Shadow = 3, MaxSize = 26 })
	local timer = nil
	if typeof(e.Ends) == "number" then
		timer = Kit.Text(holder, "", { Pixel = true, Size = UDim2.new(1, 0, 0, 11), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 8, Stroke = 2.5, Shadow = 2, MaxSize = 11, Color = C.Cream })
	end
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 20
	hit.Parent = holder
	hit.Activated:Connect(function()
		Kit.Sound("Click", 0.4)
		local fx = typeof(e.Effects) == "table" and table.concat(e.Effects, "  ") or ""
		local left = typeof(e.Ends) == "number" and ("  -  " .. clock(e.Ends - now()) .. " LEFT") or ""
		Kit.Toast(tostring(e.Name or "BOOST") .. ":  " .. fx .. left, e.Color or "Lime", e.Icon or "Star")
	end)
	Kit.Pop(holder, 0.4)
	chips[e.Id] = { Frame = holder, Timer = timer, Ends = e.Ends }
end

local function rebuild()
	ensure()
	local shown = {}
	for _, e in ipairs(list) do
		if typeof(e) == "table" and not e.Quiet and typeof(e.Id) == "string" then table.insert(shown, e) end
	end
	local parts = {}
	for _, e in ipairs(shown) do table.insert(parts, e.Id .. "=" .. tostring(e.Short) .. "@" .. tostring(e.Ends)) end
	local s = table.concat(parts, "|")
	if s == sig then return end
	sig = s
	for _, c in pairs(chips) do c.Frame:Destroy() end
	table.clear(chips)
	for i, e in ipairs(shown) do
		if i > 5 then break end -- (room for five; the rest still count)
		chip(e, i)
	end
end

-- a 2x LUCK started / grew / ended
local function onEvent(info)
	if typeof(info) ~= "table" then return end
	if typeof(info.T) == "number" then offset = info.T - os.time() end
	ensure()
	if info.Ended then
		Kit.Toast("THE 2x LUCK EVENT IS OVER", "Grey", "Star")
		return
	end
	local mult = tonumber(info.Mult) or 2
	local mins = tonumber(info.Minutes) or 0
	local by = typeof(info.By) == "string" and info.By ~= "" and info.By or nil
	if info.Extended then
		Kit.Toast(string.format("+%d MIN OF %sx LUCK!%s", mins, tostring(mult), by and ("  THANKS " .. by .. "!") or ""), "Gold", "Star")
		return
	end
	-- (a cutscene keeps it to a toast; the chip says the rest)
	if Cinema.Playing() then
		Kit.Toast(string.format("%sx LUCK FOR %d MIN!", tostring(mult), mins), "Gold", "Star")
		return
	end
	Audio.Sting("Perfect", 0.7)
	local sub = by and (by .. " STARTED IT!  RARE EGGS ARE " .. tostring(mult) .. "x AS LIKELY") or ("RARE EGGS ARE " .. tostring(mult) .. "x AS LIKELY FOR " .. mins .. " MIN")
	banner.Show(tostring(mult) .. "x LUCK EVENT!", sub, "Star", C.YellowHi, 3.4)
end

function BoostsView.Start()
	ensure()
	Net.On("Boosts", function(info)
		if typeof(info) ~= "table" then return end
		if typeof(info.T) == "number" then offset = info.T - os.time() end
		list = typeof(info.List) == "table" and info.List or {}
		rebuild()
	end)
	Net.On("LuckEvent", onEvent)
	-- what's running as you join (the server only pushes changes)
	task.spawn(function()
		local res = Net.Ask("Boosts")
		if res and res.Ok then
			if typeof(res.T) == "number" then offset = res.T - os.time() end
			list = typeof(res.List) == "table" and res.List or {}
			rebuild()
		end
	end)
	-- countdowns (a chip whose time is up waits for the server's next list, which drops it within ~2 s)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then return end
		acc = 0
		local t = now()
		for _, c in pairs(chips) do
			if c.Timer and c.Ends then Kit.SetText(c.Timer, clock(c.Ends - t)) end
		end
	end)
end

return BoostsView
