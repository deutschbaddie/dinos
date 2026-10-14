--[[
	RareHatch — server-wide rare hatch news (2026-10-14). When anyone hatches an EPIC or better, every screen gets a
	short banner sliding in at the top: who, the rarity in its colour, the species portrait, and the KG when it's a
	heavy one. The server sends "RareHatch" from Dinos.Hatch (announceHatch).

	  EPIC       a slim card: portrait, an EPIC HATCH! tag, sparkles, a chime                        ~2.6 s
	  LEGENDARY  a big card: gold sun rays spinning behind the portrait, a sparkle shower, a fanfare  ~3.6 s
	  SECRET     a SECRET HATCH! slam first, then the big card with a rainbow rim, rays and text,
	             a sun burst and a deeper fanfare                                                    ~4.6 s

	Rules: never over a cutscene, a fight or a chase - it waits in a queue until the screen is clear and is dropped
	once it's stale; one banner at a time; your own LEGENDARY / SECRET waits for your hatch scene to finish (your own
	EPIC is skipped - you just watched it). LEGENDARY+ also print a line in the chat (a local system message only).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)
local CineKit = require(script.Parent.UI.CineKit)
local RarityFx = require(script.Parent.RarityFx)
local Audio = require(script.Parent.Audio)

local RareHatch = {}

local player = Players.LocalPlayer
local C = Kit.Colors

-- per tier: Big (the large card), Hold (seconds on screen), Stale (seconds after the hatch it's still worth showing)
local TIER = {
	Epic = { Big = false, Hold = 2.6, Stale = 12, Sparkle = 0.22 },
	Legendary = { Big = true, Hold = 3.6, Stale = 35, Sparkle = 0.09 },
	Secret = { Big = true, Hold = 4.6, Stale = 60, Sparkle = 0.05 },
}
local OWN_STALE = 120 -- your own: your hatch scene runs first (it can be long, and a companion card may follow)
local MAX_QUEUE = 4
local CLEAR_GAP = 0.8 -- the screen has to be clear this long first (no banner the instant a cutscene hands back)

local canvas
local queue = {} :: { any }

--------------------------------------------------------------------------------
-- is the screen busy (a cutscene, a fight, a chase)?
--------------------------------------------------------------------------------
-- (required lazily and pcalled: these modules are big, and a busy-check must never be what breaks the banner)
local mods = {} :: { [string]: any }
local function mod(name: string): any
	if mods[name] == nil then
		local ok, m = pcall(function()
			if name == "DinosaurCinematics" then return require(Shared:WaitForChild("DinosaurCinematics") :: ModuleScript) end
			return require(script.Parent:WaitForChild(name) :: ModuleScript)
		end)
		mods[name] = ok and m or false
	end
	return mods[name] or nil
end

local function busy(): boolean
	if Cinema.Playing() then return true end
	-- a fight at a site, or driving a route mid-chase (the same rule as the HUD's server news)
	if player:GetAttribute("Site") then return true end
	local Drive = mod("Drive")
	if Drive and Drive.State and Drive.State.Mode == "Route" and not Drive.State.Frozen and not Drive.State.OnFoot then return true end
	local Hatch = mod("Hatch")
	if Hatch and Hatch.Playing then return true end
	local Warp = mod("Warp")
	if Warp and Warp.Playing then return true end
	local Cine = mod("DinosaurCinematics")
	if Cine and Cine.IsPlaying and Cine.IsPlaying() then return true end
	return false
end

local function age(info): number
	return Workspace:GetServerTimeNow() - (tonumber(info.T) or Workspace:GetServerTimeNow())
end

local function stale(item): boolean
	local tier = TIER[item.Info.Rarity]
	return age(item.Info) > (item.Own and OWN_STALE or tier.Stale)
end

--------------------------------------------------------------------------------
-- pieces
--------------------------------------------------------------------------------
local function new(class: string, props, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in pairs(props) do (i :: any)[k] = v end
	if parent then i.Parent = parent end
	return i
end

-- a spinning burst of sun rays (CineKit.RayTitle's look, small enough to sit behind a portrait)
local function rays(host: GuiObject, at: UDim2, size: number, col: Color3, rainbow: boolean): (Frame, () -> ())
	local r = new("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(0, 0), ZIndex = 40 }, host)
	local n = 14
	for i = 1, n do
		local c = rainbow and Color3.fromHSV(i / n, 0.65, 1) or ((i % 2 == 0) and col or col:Lerp(Color3.new(1, 1, 1), 0.45))
		local ray = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.09, 0.5), Rotation = i * (360 / n), BackgroundColor3 = c, BackgroundTransparency = 0.2, ZIndex = 40 }, r)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }) }, ray)
	end
	TweenService:Create(r, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(size, size) }):Play()
	local spin
	spin = RunService.RenderStepped:Connect(function(dt)
		if not r.Parent then spin:Disconnect() return end -- (a banner torn down early never leaves a spinner behind)
		r.Rotation += dt * 30
	end)
	return r, function() spin:Disconnect() end
end

-- one blocky sparkle: a little diamond pops, twinkles and goes (the game's pixel-cube language, in 2D)
local function sparkle(host: GuiObject, col: Color3, rainbow: boolean)
	local s = math.random(7, 15)
	local c = rainbow and Color3.fromHSV(math.random(), 0.6, 1) or ((math.random() < 0.4) and Color3.new(1, 1, 1) or col:Lerp(Color3.new(1, 1, 1), math.random() * 0.4))
	local d = new("Frame", {
		Name = "Sparkle", BorderSizePixel = 0, BackgroundColor3 = c, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, ZIndex = 49,
		Position = UDim2.new(math.random() * 1.04 - 0.02, 0, math.random() * 1.5 - 0.25, 0), Size = UDim2.fromOffset(s, s),
	}, host)
	new("UIStroke", { Thickness = 2, Color = C.Ink, Transparency = 0.35 }, d)
	local sc = new("UIScale", { Scale = 0 }, d)
	TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(d, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Rotation = 45 + math.random(-90, 90), Position = d.Position + UDim2.fromOffset(0, -8 - math.random() * 10) }):Play()
	task.delay(0.35, function()
		if not d.Parent then return end
		TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
		task.delay(0.32, function() d:Destroy() end)
	end)
end

local function rainbowText(box: Instance)
	local main = box:FindFirstChild("Main")
	if main then RarityFx.Rainbow(main) end
end

local function escape(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- LEGENDARY+ also go in the chat as a local system line (nothing is sent; skipped if the new chat isn't on)
local function chatLine(info)
	if (Config.Rarity[info.Rarity] and Config.Rarity[info.Rarity].Order or 0) < 5 then return end
	pcall(function()
		if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if not (general and general:IsA("TextChannel")) then return end
		local r = Config.Rarity[info.Rarity]
		local hex = info.Rarity == "Secret" and "FF5CF0" or r.Color:ToHex()
		local sp = Config.Species[info.Species]
		local kg = info.Heavy and (" (" .. Config.FormatNumber(tonumber(info.KG) or 0) .. " KG)") or ""
		general:DisplaySystemMessage(string.format('<font color="#%s"><b>[%s HATCH]</b></font> %s hatched a <font color="#%s"><b>%s %s</b></font>%s!',
			hex, r.Name, escape(tostring(info.Name or "SOMEONE")), hex, r.Name, sp and sp.Name or "DINO", kg))
	end)
end

--------------------------------------------------------------------------------
-- the banner
--------------------------------------------------------------------------------
local function show(item)
	local info = item.Info
	local r = Config.Rarity[info.Rarity]
	local sp = Config.Species[info.Species]
	local tier = TIER[info.Rarity]
	if not (r and sp and tier) then return end
	local big = tier.Big
	local secret = info.Rarity == "Secret"
	local col = r.Color
	local H = big and 96 or 60
	local X = big and 126 or 80 -- where the text starts (right of the portrait)
	local kgW = info.Heavy and (big and 122 or 92) or 0

	-- SECRET: a slam in the middle of the screen first (short: it's someone else's moment)
	if secret then
		pcall(function()
			CineKit.Slam(canvas, "SECRET HATCH!", nil, col, 1.0, 0.36)
			CineKit.SunBurst(0.6)
		end)
		Audio.Sting("Reveal", 0.55)
		local t0 = os.clock()
		while os.clock() - t0 < 1.25 do
			if busy() then return end
			task.wait(0.05)
		end
	end

	local holder = new("Frame", { Name = "RareHatch", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -(H + 70)), Size = UDim2.new(0.94, 0, 0, H), ZIndex = 40 }, canvas)
	-- (phones: the card is 94% of the safe width up to its full size; every line is TextScaled)
	new("UISizeConstraint", { MaxSize = Vector2.new(big and 640 or 470, H) }, holder)
	local stopRays = nil
	if big then
		local _, stop = rays(holder, UDim2.new(0, 60, 0.5, -4), secret and 300 or 250, col, secret)
		stopRays = stop
	end
	local card = Kit.Card(holder, { Color = "Forest", Border = col, Size = UDim2.fromScale(1, 1), ZIndex = 41, Lip = big and 6 or 4, Radius = big and 16 or 12 })
	local body = card:FindFirstChild("Body") :: Frame
	-- a glow of the rarity colour from behind the portrait, fading to the right
	local glow = new("Frame", { Name = "Glow", BorderSizePixel = 0, BackgroundColor3 = col, Size = UDim2.new(0.7, 0, 1, -8), Position = UDim2.fromOffset(4, 4), ZIndex = 41 }, body)
	new("UICorner", { CornerRadius = UDim.new(0, big and 12 or 9) }, glow)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }) }, glow)
	Kit.Shine(body, 1.6)
	if secret then
		local inner = body:FindFirstChild("InnerBorder")
		local st = inner and inner:FindFirstChildOfClass("UIStroke")
		if st then RarityFx.Rainbow(st) end
		local outerStroke = body:FindFirstChildOfClass("UIStroke")
		if outerStroke then outerStroke.Thickness = 4.5 end
	end

	-- the species portrait, breaking out of the card
	local pS = big and 122 or 74
	local portrait = Kit.Icon(holder, "Dino", { Species = info.Species, Size = UDim2.fromOffset(pS, pS), Position = UDim2.new(0, big and 0 or 2, 0.5, big and -8 or -4), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 46, Rotation = -8 })

	-- the rarity tag sitting on the card's top edge
	local tagText = r.Name .. " HATCH!"
	local tagW = math.clamp(#tagText * (big and 13 or 10) + 34, 120, 260)
	local tagSw = secret and { Color3.fromRGB(40, 22, 58), Color3.fromRGB(90, 60, 120), Color3.fromRGB(20, 10, 30) } or Kit.Theme.Swatchify(col)
	local tag, tagContent = Kit.Brick(holder, { Name = "Tag", Color = tagSw, Round = true, Size = UDim2.fromOffset(tagW, big and 30 or 22), Position = UDim2.new(0, X - 6, 0, big and -16 or -12), ZIndex = 47, Lip = 3, StrokeT = 3 })
	tag.Rotation = -3
	local tagLabel = Kit.Text(tagContent, tagText, { Pixel = true, Size = UDim2.new(1, -16, 0, big and 14 or 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.new(1, 1, 1), Stroke = 2.5, Shadow = 2, ZIndex = 48, MaxSize = big and 14 or 10 })
	if secret then rainbowText(tagLabel) end

	-- who, and what
	local textW = -X - kgW - 14
	Kit.Text(holder, string.upper(tostring(info.Name or "SOMEONE")) .. " HATCHED", { Name = "Who", Size = UDim2.new(1, textW, 0, big and 28 or 20), Position = UDim2.new(0, X, 0, big and 18 or 11), Align = Enum.TextXAlignment.Left, Color = C.Cream, Stroke = 3, Shadow = 2, ZIndex = 46, MaxSize = big and 28 or 20 })
	local what = Kit.Text(holder, sp.Name .. "!", { Name = "What", Size = UDim2.new(1, textW, 0, big and 38 or 24), Position = UDim2.new(0, X, 0, big and 48 or 32), Align = Enum.TextXAlignment.Left,
		Color = secret and Color3.new(1, 1, 1) or col:Lerp(Color3.new(1, 1, 1), 0.4), Color2 = (not secret) and col or nil, Stroke = big and 4 or 3, Shadow = big and 4 or 3, ZIndex = 46, MaxSize = big and 40 or 26 })
	if secret then rainbowText(what) end

	-- a heavy one: its weight on an orange tile at the right end
	if info.Heavy then
		local kg, kgc = Kit.Brick(holder, { Name = "KG", Color = "Orange", Size = UDim2.fromOffset(kgW - 12, big and 54 or 38), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 47, Lip = 3, StrokeT = 3, Radius = 10 })
		kg.Rotation = 4
		Kit.Text(kgc, "HEAVY!", { Pixel = true, Size = UDim2.new(1, -10, 0, big and 11 or 8), Position = UDim2.new(0.5, 0, 0, big and 7 or 5), AnchorPoint = Vector2.new(0.5, 0), Color = C.YellowHi, Stroke = 2, Shadow = 1, ZIndex = 48, MaxSize = 11 })
		Kit.Text(kgc, Config.FormatNumber(tonumber(info.KG) or 0) .. " KG", { Size = UDim2.new(1, -10, 0, big and 26 or 18), Position = UDim2.new(0.5, 0, 1, big and -7 or -4), AnchorPoint = Vector2.new(0.5, 1), Color = Color3.new(1, 1, 1), Stroke = 3, Shadow = 2, ZIndex = 48, MaxSize = big and 26 or 18 })
	end

	-- slide in
	TweenService:Create(holder, TweenInfo.new(big and 0.5 or 0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, big and 18 or 14) }):Play()
	Kit.Pop(portrait, 0.3, 0.18)
	Kit.Pop(tag, 0.4, 0.26)
	if info.Rarity == "Epic" then
		Audio.Play("Perfect", { Pitch = 1.2, Exact = true, Volume = 0.9 })
	elseif secret then
		Audio.Play("HatchLegendary", { Pitch = 0.82, Exact = true, Volume = 1.1 })
	else
		Audio.Sting("HatchLegendary", 0.5)
	end
	task.delay(0.5, function() if holder.Parent then Kit.Punch(what, big and 0.22 or 0.14) end end)

	-- hold, sparkling; a cutscene starting cuts it short (the screen is theirs now)
	local t0 = os.clock()
	local nextSpark = 0
	local cut = false
	while os.clock() - t0 < tier.Hold do
		if busy() then cut = true break end
		if os.clock() >= nextSpark then
			nextSpark = os.clock() + tier.Sparkle
			sparkle(holder, col, secret)
			if big and math.random() < 0.5 then sparkle(holder, col, secret) end
		end
		task.wait(0.03)
	end
	if stopRays then stopRays() end
	if cut then holder:Destroy() return end
	local out = TweenService:Create(holder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -(H + 70)) })
	out:Play()
	out.Completed:Wait()
	holder:Destroy()
end

--------------------------------------------------------------------------------
-- the queue
--------------------------------------------------------------------------------
local function enqueue(info)
	if typeof(info) ~= "table" or typeof(info.Rarity) ~= "string" or typeof(info.Species) ~= "string" then return end
	if not (TIER[info.Rarity] and Config.Rarity[info.Rarity] and Config.Species[info.Species]) then return end
	local own = info.UserId == player.UserId
	chatLine(info)
	-- (you just watched it hatch; Studio still shows it, so the EPIC card can be checked solo)
	if own and info.Rarity == "Epic" and not RunService:IsStudio() then return end
	-- full: the oldest EPIC makes room, else the oldest non-SECRET; a SECRET always gets in
	if #queue >= MAX_QUEUE then
		local drop = nil
		for i, it in ipairs(queue) do if it.Info.Rarity == "Epic" then drop = i break end end
		if not drop then for i, it in ipairs(queue) do if it.Info.Rarity ~= "Secret" then drop = i break end end end
		if drop then table.remove(queue, drop) elseif info.Rarity ~= "Secret" then return end
	end
	-- (your own waits a beat, so your hatch scene has started before the queue looks at the screen)
	table.insert(queue, { Info = info, Own = own, NotBefore = os.clock() + (own and 2.5 or 0) })
end

local function pump()
	local clearSince = os.clock()
	while true do
		task.wait(0.2)
		-- stale ones go first (a long cutscene or a fight means you missed it - old news isn't news)
		for i = #queue, 1, -1 do
			if stale(queue[i]) then table.remove(queue, i) end
		end
		if busy() then clearSince = os.clock() continue end
		local item = queue[1]
		if not item then continue end
		local gap = item.Own and CLEAR_GAP + 0.6 or CLEAR_GAP
		if os.clock() < item.NotBefore or os.clock() - clearSince < gap then continue end
		table.remove(queue, 1)
		local ok, err = pcall(show, item)
		if not ok then
			warn("[RareHatch] " .. tostring(err))
			-- (never leave a half-built banner behind)
			for _, c in ipairs(canvas:GetChildren()) do if c.Name == "RareHatch" then c:Destroy() end end
		end
		task.wait(0.35)
	end
end

function RareHatch.Start()
	local _
	_, canvas = Kit.Screen("DinoRareHatch", 33, false, 0.8)
	Net.On("RareHatch", enqueue)
	task.spawn(pump)
end

return RareHatch
