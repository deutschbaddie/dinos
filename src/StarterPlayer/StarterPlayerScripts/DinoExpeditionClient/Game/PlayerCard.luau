--[[
	PlayerCard — walk up to anyone and hold [G] / tap VIEW PROFILE to see everything about them in this game.
	The headline is the hardest boss they've knocked out (boss power x tier); then every boss trophy, their
	power + gear, their dinos (rarest, heaviest, companions), and run stats. The server builds the card
	(Access.luau "PlayerCard") from their live profile.

	Also draws the PRE-BETA TESTER tag over every approved tester's head (player attr Tester, kept after launch).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local Testing = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Testing"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)
local TradeView = require(script.Parent.TradeView) -- the TRADE button + the trade screens (2026-10-14)

local player = Players.LocalPlayer
local C = Kit.Colors
local PlayerCard = {}

local function new(class: string, props, parent: Instance?)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do (i :: any)[k] = v end
	if parent then i.Parent = parent end
	return i
end

local function speciesName(id: string?): string
	local s = id and Config.Species[id]
	return s and s.Name or (id and string.upper(id) or "")
end

local function clock(sec: number?): string
	if not sec then return "" end
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

--------------------------------------------------------------------------------
-- the card
--------------------------------------------------------------------------------
local canvas = nil :: Frame?
local openWin: Instance? = nil
local openFor: Player? = nil

local function close()
	if openWin and openWin.Parent then Kit.Exit(openWin :: any, true) end -- (its fit holder goes with it)
	openWin, openFor = nil, nil
end

local function stat(parent: Instance, x: number, y: number, label: string, value: string, color: Color3?)
	local box = Kit.Card(parent, { Size = UDim2.fromOffset(106, 54), Position = UDim2.fromOffset(x, y), ZIndex = 64, Lip = 3 })
	local body = box:FindFirstChild("Body") :: Frame
	Kit.Text(body, value, { Size = UDim2.new(1, -12, 0, 24), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 68, Stroke = 3, Shadow = 2, MaxSize = 24, Color = color })
	Kit.Text(body, label, { Pixel = true, Size = UDim2.new(1, -10, 0, 8), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 68, Stroke = 1.5, Shadow = 1, MaxSize = 8, Color = C.Muted })
	return box
end

local function show(target: Player, c)
	close()
	if not canvas then
		local _, cv = Kit.Screen("DinoPlayerCard", 30)
		canvas = cv
	end
	local win, inner
	local header
	win, inner, header = Kit.Window(canvas :: Frame, { Name = "PlayerCard", Title = string.upper(c.DisplayName), Color = "Blue", Icon = "Trophy", Size = UDim2.fromOffset(800, 540), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Fit = true, ZIndex = 60, OnClose = close })
	openWin, openFor = win, target
	-- TRADE (2026-10-14): dinos + eggs, in the title strip beside the close tile (it greys out with the reason when
	-- you can't: playtime, busy, already trading). The name makes room for it.
	local titleBox = header:FindFirstChild("Title") :: Frame?
	if titleBox then titleBox.Size = UDim2.new(1, -100 - 90 - 196, 0, 44) end
	TradeView.CardButton(header, target, { Size = UDim2.fromOffset(186, 54), Position = UDim2.new(1, -78, 0.5, -2), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 69 })
	Kit.Enter(win) -- (animate the window; its fit holder keeps the scale that fits it on screen)
	Kit.Sound("Pop", 0.5)

	-- left column: who
	local _, avContent = Kit.Brick(inner, { Size = UDim2.fromOffset(170, 170), Position = UDim2.fromOffset(0, 6), Color = c.Tester and "Yellow" or "Slate", Radius = 16, Lip = 6, ZIndex = 62 })
	local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), ZIndex = 66, ScaleType = Enum.ScaleType.Crop }, avContent) :: ImageLabel
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, img)
	task.spawn(function()
		local ok, url = pcall(function() return Players:GetUserThumbnailAsync(c.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420) end)
		if ok and img.Parent then img.Image = url end
	end)
	Kit.Text(inner, "@" .. c.Name, { Pixel = true, Size = UDim2.fromOffset(170, 10), Position = UDim2.fromOffset(0, 188), ZIndex = 64, Stroke = 2, Shadow = 2, MaxSize = 10, Color = C.Muted })
	local tagY = 204
	if c.Tester then
		local t = new("Frame", { BackgroundColor3 = C.Yellow, Size = UDim2.fromOffset(170, 26), Position = UDim2.fromOffset(0, tagY), ZIndex = 64 }, inner)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, t)
		new("UIStroke", { Color = C.Ink, Thickness = 2.5 }, t)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.YellowHi, C.Yellow) }, t)
		Kit.Text(t, Testing.Phase .. " TESTER", { Pixel = true, Size = UDim2.new(1, -14, 0, 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 66, Stroke = 2, Shadow = 2, MaxSize = 10 })
		tagY += 34
	end
	-- power
	local _, pwContent = Kit.Brick(inner, { Size = UDim2.fromOffset(170, 60), Position = UDim2.fromOffset(0, tagY), Color = "Lime", Radius = 14, Lip = 5, ZIndex = 62, Stripes = 0.85 })
	Kit.Icon(pwContent, "Power", { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, -8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 66 })
	Kit.Text(pwContent, Config.FormatNumber(c.Power or 0), { Size = UDim2.new(1, -60, 0, 30), Position = UDim2.fromOffset(50, 6), Align = Enum.TextXAlignment.Left, ZIndex = 66, Stroke = 3.5, Shadow = 3, MaxSize = 30 })
	Kit.Text(pwContent, "POWER", { Pixel = true, Size = UDim2.new(1, -60, 0, 9), Position = UDim2.fromOffset(52, 40), Align = Enum.TextXAlignment.Left, ZIndex = 66, Stroke = 2, Shadow = 1, MaxSize = 9 })
	-- gear
	local gearY = tagY + 74
	for i, g in ipairs({ { "Launcher", c.Launcher, c.LauncherLvl }, { "Armor", c.Armor, c.ArmorLvl }, { "Jeep", c.Rover, c.RoverLvl } }) do
		if g[2] ~= "" then
			local y = gearY + (i - 1) * 30
			Kit.Icon(inner, g[1], { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(0, y), ZIndex = 64 })
			Kit.Text(inner, g[2] .. "  LV " .. tostring(g[3]), { Pixel = true, Size = UDim2.fromOffset(136, 9), Position = UDim2.fromOffset(34, y + 10), Align = Enum.TextXAlignment.Left, ZIndex = 64, Stroke = 1.5, Shadow = 1, MaxSize = 9 })
		end
	end

	-- right: the headline — best boss knocked out
	local rx = 190
	local best = c.BestBoss
	local heroColor = best and best.Color or C.Grey
	local _, heroContent = Kit.Brick(inner, { Size = UDim2.fromOffset(570, 132), Position = UDim2.fromOffset(rx, 6), Color = Kit.Theme.Swatchify(heroColor), Radius = 16, Lip = 6, ZIndex = 62, Stripes = 0.86 })
	Kit.Text(heroContent, "BEST BOSS KNOCKED OUT", { Pixel = true, Size = UDim2.fromOffset(330, 11), Position = UDim2.fromOffset(150, 14), Align = Enum.TextXAlignment.Left, ZIndex = 66, Stroke = 2, Shadow = 2, MaxSize = 11 })
	if best then
		Kit.Icon(heroContent, "Dino", { Species = best.Species, Size = UDim2.fromOffset(150, 150), Position = UDim2.new(0, -6, 0.5, -10), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 67, Rotation = -6 })
		Kit.Text(heroContent, best.Name, { Size = UDim2.fromOffset(400, 46), Position = UDim2.fromOffset(148, 30), Align = Enum.TextXAlignment.Left, ZIndex = 66, Stroke = 4.5, Shadow = 4, MaxSize = 46, Color = Color3.new(1, 1, 1) })
		local sub = "BOSS OF " .. best.Era .. "  -  " .. best.Tier
		Kit.Text(heroContent, sub, { Pixel = true, Size = UDim2.fromOffset(400, 11), Position = UDim2.fromOffset(150, 84), Align = Enum.TextXAlignment.Left, ZIndex = 66, Stroke = 2, Shadow = 2, MaxSize = 11 })
		local detail = "KNOCKED OUT " .. tostring(best.Clears) .. "X" .. (best.BestTime and ("  -  BEST " .. clock(best.BestTime)) or "")
		Kit.Text(heroContent, detail, { Pixel = true, Size = UDim2.fromOffset(400, 9), Position = UDim2.fromOffset(150, 104), Align = Enum.TextXAlignment.Left, ZIndex = 66, Stroke = 1.5, Shadow = 1, MaxSize = 9, Color = C.Cream })
	else
		Kit.Icon(heroContent, "Lock", { Size = UDim2.fromOffset(90, 90), Position = UDim2.new(0, 28, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 67 })
		Kit.Text(heroContent, "NO BOSS YET", { Size = UDim2.fromOffset(400, 46), Position = UDim2.fromOffset(148, 34), Align = Enum.TextXAlignment.Left, ZIndex = 66, Stroke = 4.5, Shadow = 4, MaxSize = 46 })
		Kit.Text(heroContent, "THE " .. Config.Bosses.TyrantKing.Name .. " IS WAITING IN FERN VALLEY", { Pixel = true, Size = UDim2.fromOffset(400, 10), Position = UDim2.fromOffset(150, 88), Align = Enum.TextXAlignment.Left, ZIndex = 66, Stroke = 2, Shadow = 2, MaxSize = 10 })
	end

	-- every boss, in era order: beaten ones lit with their best tier
	local beaten = {}
	for _, b in ipairs(c.Bosses or {}) do beaten[b.Id] = b end
	local trophies = new("Frame", { Name = "Trophies", BackgroundTransparency = 1, Size = UDim2.fromOffset(570, 66), Position = UDim2.fromOffset(rx, 152), ZIndex = 62 }, inner)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, trophies)
	local n = 0
	for _, era in ipairs(Config.Eras) do
		local id = era.Boss
		local boss = id and Config.Bosses[id]
		if boss and era.Built then
			n += 1
			local rec = beaten[id]
			local cell = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(88, 66), LayoutOrder = n, ZIndex = 62 }, trophies)
			local t, tc = Kit.Brick(cell, { Size = UDim2.fromOffset(88, 60), Color = rec and Kit.Theme.Swatchify(boss.Color) or "Slate", Radius = 12, Lip = 4, ZIndex = 63 })
			Kit.Icon(tc, "Dino", { Species = boss.Species, Silhouette = rec == nil, Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0.5, 0, 0, -8), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 66 })
			Kit.Text(tc, rec and rec.Tier or "???", { Pixel = true, Size = UDim2.new(1, -8, 0, 8), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 67, Stroke = 1.5, Shadow = 1, MaxSize = 8, Color = rec and Color3.new(1, 1, 1) or C.Grey })
			if not rec then (t :: Frame).BackgroundTransparency = 1 end
		end
	end

	-- the numbers
	local st = c.Stats or {}
	local sy = 232
	local cells = {
		{ "DINOS", tostring(c.DinoCount or 0) },
		{ "INDEX", tostring(c.Index or 0) },
		{ "EARNED", Config.FormatNumber(c.Earned or 0), C.YellowHi },
		{ "INCOME / S", Config.FormatNumber(math.floor(c.Rate or 0)), C.LimeHi },
		{ "ERAS", tostring(c.Eras or 0) .. "/" .. tostring(c.ErasBuilt or 0) },
		{ "EXPEDITIONS", tostring(st.Runs or 0) },
		{ "EGGS FOUND", tostring(st.Eggs or 0) },
		{ "HATCHED", tostring(st.Hatched or 0) },
		{ "TAKEDOWNS", tostring(st.Takedowns or 0) },
		{ "ESCAPES", tostring(st.Escapes or 0) },
	}
	for i, s in ipairs(cells) do
		local col = (i - 1) % 5
		local rowI = math.floor((i - 1) / 5)
		stat(inner, rx + col * 116, sy + rowI * 62, s[1], s[2], s[3])
	end
	-- dinos: rarest, heaviest, companions
	local dy = sy + 130
	local function dinoChip(x: number, label: string, d, w: number)
		if not d then return end
		local rar = Config.Rarity[d.Rarity or ""]
		local chip, cc = Kit.Brick(inner, { Size = UDim2.fromOffset(w, 44), Position = UDim2.fromOffset(x, dy), Color = Kit.Theme.Swatchify(rar and rar.Color or C.Grey), Radius = 12, Lip = 4, ZIndex = 63 })
		Kit.Icon(cc, "Dino", { Species = d.Species, Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0, -4, 0.5, -2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 67 })
		Kit.Text(cc, label, { Pixel = true, Size = UDim2.new(1, -56, 0, 8), Position = UDim2.fromOffset(48, 7), Align = Enum.TextXAlignment.Left, ZIndex = 67, Stroke = 1.5, Shadow = 1, MaxSize = 8 })
		local line = (rar and rar.Name .. " " or "") .. speciesName(d.Species) .. (d.KG and ("  " .. Config.FormatNumber(math.floor(d.KG)) .. "KG") or "")
		Kit.Text(cc, line, { Size = UDim2.new(1, -56, 0, 18), Position = UDim2.fromOffset(48, 18), Align = Enum.TextXAlignment.Left, ZIndex = 67, Stroke = 2.5, Shadow = 2, MaxSize = 18 })
		return chip
	end
	dinoChip(rx, "RAREST DINO", c.Rarest, 280)
	dinoChip(rx + 290, "HEAVIEST DINO", c.Heaviest, 280)
	if c.Buddies and #c.Buddies > 0 then
		local names = {}
		for _, b in ipairs(c.Buddies) do table.insert(names, speciesName(b.Species)) end
		Kit.Text(inner, "COMPANIONS: " .. table.concat(names, ", "), { Pixel = true, Size = UDim2.fromOffset(570, 9), Position = UDim2.fromOffset(rx, dy + 54), Align = Enum.TextXAlignment.Left, ZIndex = 64, Stroke = 1.5, Shadow = 1, MaxSize = 9, Color = C.Cream })
	end
end

function PlayerCard.Open(target: Player)
	local res = Net.Ask("PlayerCard", { UserId = target.UserId })
	if not res.Ok or not res.Card then
		Kit.Toast(res.Err or "COULDN'T LOAD THEIR PROFILE", "Red")
		return
	end
	show(target, res.Card)
end

--------------------------------------------------------------------------------
-- prompts on other players + the tester tag over heads
--------------------------------------------------------------------------------
local function busy(): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("Site") ~= nil or (hum ~= nil and hum.SeatPart ~= nil) or Cinema.Playing()
end

-- tags show on live servers (and after launch); Studio keeps clean frames for recording unless previewing the test
local SHOW_TAGS = not RunService:IsStudio() or Testing.PreviewInStudio
local function testerTag(head: BasePart)
	if not SHOW_TAGS or head:FindFirstChild("DinoTesterTag") then return end
	local bb = new("BillboardGui", {
		Name = "DinoTesterTag", Adornee = head, Size = UDim2.fromOffset(150, 26), StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0),
		AlwaysOnTop = false, MaxDistance = 90, LightInfluence = 0, ResetOnSpawn = false,
	}, head) :: BillboardGui
	local pill = new("Frame", { BackgroundColor3 = C.Yellow, Size = UDim2.fromScale(1, 1) }, bb)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pill)
	new("UIStroke", { Color = C.Ink, Thickness = 2.5 }, pill)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.YellowHi, C.Yellow) }, pill)
	Kit.Text(pill, Testing.Phase .. " TESTER", { Pixel = true, Size = UDim2.new(1, -16, 0, 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Stroke = 2, Shadow = 2, MaxSize = 10 })
end

local prompts = {} :: { [Player]: ProximityPrompt }

local function bindCharacter(p: Player, char: Model)
	local head = char:WaitForChild("Head", 10) :: BasePart?
	if head and p:GetAttribute("Tester") then testerTag(head) end
	if p == player then return end
	local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hrp or not char.Parent then return end
	local old = prompts[p]
	if old then old:Destroy() end
	local pr = new("ProximityPrompt", {
		Name = "DinoProfilePrompt", ActionText = "VIEW PROFILE", ObjectText = string.upper(p.DisplayName),
		KeyboardKeyCode = Enum.KeyCode.G, GamepadKeyCode = Enum.KeyCode.ButtonX, HoldDuration = 0.2,
		MaxActivationDistance = 9, RequiresLineOfSight = false, Style = Enum.ProximityPromptStyle.Custom,
		UIOffset = Vector2.new(0, -40),
	}, hrp) :: ProximityPrompt
	pr:SetAttribute("PromptColor", "Blue")
	pr.Triggered:Connect(function() PlayerCard.Open(p) end)
	prompts[p] = pr
end

local function bindPlayer(p: Player)
	p.CharacterAdded:Connect(function(c) bindCharacter(p, c) end)
	if p.Character then task.spawn(bindCharacter, p, p.Character) end
	p:GetAttributeChangedSignal("Tester"):Connect(function()
		local head = p.Character and p.Character:FindFirstChild("Head")
		if head and head:IsA("BasePart") and p:GetAttribute("Tester") then testerTag(head) end
	end)
end

function PlayerCard.Start()
	-- trading starts here: the card closes when a trade window opens
	TradeView.OnOpen = close
	TradeView.Start()
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(bindPlayer, p) end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(p)
		prompts[p] = nil
		if openFor == p then close() end
	end)
	-- prompts sleep while you drive / raid / watch a cutscene, or while they do; tags hide in cutscenes;
	-- the card closes when you walk away from them
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then return end
		acc = 0
		local me = busy()
		for p, pr in pairs(prompts) do
			if pr.Parent then
				local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				pr.Enabled = not me and not (hum and hum.SeatPart) and p:GetAttribute("Site") == nil
			end
		end
		local cine = Cinema.Playing()
		for _, p in ipairs(Players:GetPlayers()) do
			local head = p.Character and p.Character:FindFirstChild("Head")
			local tagGui = head and head:FindFirstChild("DinoTesterTag")
			if tagGui then (tagGui :: BillboardGui).Enabled = not cine end
		end
		if openFor then
			local a = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local b = openFor.Character and openFor.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not a or not b or (a.Position - b.Position).Magnitude > 30 or me then close() end
		end
	end)
end

return PlayerCard
