--[[
	NameDialog — NAME YOUR DINO (server: Showcase.luau "NameDino"). A small window over whatever is open: the dino,
	a text box (Config.Names.Max characters, counted as you type), SAVE, and SPECIES NAME to clear it.
	The server filters every name for Roblox's rules; a name it can't allow comes back as an error here and the box
	stays open so you can try another. NameDialog.Open(dino record).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)

local C = Theme.C
local MAX = Config.Names.Max

local NameDialog = {}
local canvas: Frame? = nil
local dim: TextButton? = nil
local win: Frame? = nil
local busy = false

local function close()
	local w = win
	win = nil
	if w then Kit.Exit(w, true) end
	if dim then
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		task.delay(0.22, function() if not win and dim then dim.Visible = false end end)
	end
end
NameDialog.Close = close
function NameDialog.IsOpen(): boolean
	return win ~= nil
end

local function ensure()
	if canvas then return end
	local _, cv = Kit.Screen("DinoNameDialog", 50)
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
	d.Activated:Connect(close)
	dim = d
	UserInputService.InputBegan:Connect(function(input)
		if win and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then close() end
	end)
end

local function pixel(parent: Instance, s: string, props)
	props.Pixel = true
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2
	props.Shadow = props.Shadow or 1
	props.MaxSize = props.MaxSize or 12
	return Kit.Text(parent, s, props)
end

-- what the box holds, cut to MAX characters (the server tidies it again)
local function clip(s: string): string
	if (utf8.len(s) or #s) <= MAX then return s end
	local cut = utf8.offset(s, MAX + 1)
	return cut and s:sub(1, cut - 1) or s:sub(1, MAX)
end

local function save(d, text: string)
	if busy then return end
	busy = true
	local res = Net.Ask("NameDino", { Id = d.Id, Name = text })
	busy = false
	if res and res.Ok then
		if res.Cleared then
			Kit.Toast("BACK TO " .. Config.DinoName({ Species = d.Species }), "Grey", "Dino")
		else
			Kit.Toast("MEET " .. tostring(res.Name or "YOUR DINO") .. "!", "Gold", "Dino")
		end
		close()
	else
		Kit.Toast(string.upper(tostring(res and res.Err or "THAT NAME WON'T WORK")), "Red", "Alert")
		if win then Kit.Shake(win) end
	end
end

function NameDialog.Open(d)
	if typeof(d) ~= "table" or not d.Id or not Config.Species[d.Species] then return end
	ensure()
	if win then win:Destroy() win = nil end
	local r = Config.Rarity[d.Rarity] or Config.Rarity.Common
	local sp = Config.Species[d.Species]
	local dd = dim :: TextButton
	dd.Visible = true
	TweenService:Create(dd, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	local root, content = Kit.Window(canvas :: Frame, { Fit = true, Title = "NAME YOUR DINO", Color = "Yellow", Icon = "Dino", Size = UDim2.fromOffset(560, 330), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20, OnClose = close })
	win = root
	-- the dino
	local _, cc = Kit.Card(content, { Size = UDim2.fromOffset(150, 150), Position = UDim2.fromOffset(0, 6), Border = r.Color, ZIndex = 22 })
	Kit.Icon(cc, "Dino", { Species = d.Species, Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 25 })
	pixel(cc, r.Name, { Size = UDim2.new(1, -10, 0, 9), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 25, MaxSize = 9, Color = r.Color:Lerp(Color3.new(1, 1, 1), 0.3) })
	Kit.Text(content, sp.Name, { Size = UDim2.new(1, -170, 0, 24), Position = UDim2.fromOffset(170, 8), Align = Enum.TextXAlignment.Left, ZIndex = 24, Stroke = 3, Shadow = 2, MaxSize = 24 })
	pixel(content, Config.FormatKG(d.KG or 0), { Size = UDim2.new(1, -170, 0, 10), Position = UDim2.fromOffset(170, 38), Align = Enum.TextXAlignment.Left, ZIndex = 24, MaxSize = 10, Color = C.Muted })
	-- the box
	local boxBg = Instance.new("Frame")
	boxBg.Name = "NameBox"
	boxBg.BackgroundColor3 = C.InkSoft
	boxBg.Size = UDim2.new(1, -170, 0, 54)
	boxBg.Position = UDim2.fromOffset(170, 60)
	boxBg.ZIndex = 24
	boxBg.Parent = content
	Kit.Corner(boxBg, 12)
	local stroke = Kit.Stroke(boxBg, C.YellowHi, 3)
	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.BackgroundTransparency = 1
	box.Size = UDim2.new(1, -24, 1, -8)
	box.Position = UDim2.fromOffset(12, 4)
	box.FontFace = Theme.Display
	box.TextScaled = true
	box.TextColor3 = C.Cream
	box.PlaceholderText = "TYPE A NAME"
	box.PlaceholderColor3 = C.Muted
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Text = (typeof(d.Name) == "string" and d.Name) or ""
	box.ZIndex = 26
	box.Parent = boxBg
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = 30
	lim.Parent = box
	local count = pixel(content, "", { Size = UDim2.fromOffset(120, 10), Position = UDim2.new(1, 0, 0, 122), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, ZIndex = 24, MaxSize = 10, Color = C.Muted })
	pixel(content, "EVERYONE CAN SEE IT", { Size = UDim2.new(1, -300, 0, 9), Position = UDim2.fromOffset(170, 123), Align = Enum.TextXAlignment.Left, ZIndex = 24, MaxSize = 9, Color = C.Muted })
	local function onText()
		local s = clip(box.Text)
		if s ~= box.Text then box.Text = s return end
		local n = utf8.len(s) or #s
		Kit.SetText(count, n .. " / " .. MAX)
		stroke.Color = n >= MAX and C.OrangeHi or C.YellowHi
	end
	box:GetPropertyChangedSignal("Text"):Connect(onText)
	onText()
	box.FocusLost:Connect(function(enter)
		if enter and win == root then save(d, box.Text) end
	end)
	-- the buttons
	Kit.Button(content, { Text = "SAVE", Icon = "Glyph:Check", IconSize = 0.6, TextLeft = 0.34, Color = "Lime", Size = UDim2.fromOffset(180, 52), Position = UDim2.new(1, 0, 1, -4), AnchorPoint = Vector2.new(1, 1), ZIndex = 26, MaxText = 22, Shine = true, OnClick = function() save(d, box.Text) end })
	if typeof(d.Name) == "string" and d.Name ~= "" then
		Kit.Button(content, { Text = "SPECIES NAME", Color = "Grey", Size = UDim2.fromOffset(200, 52), Position = UDim2.new(1, -192, 1, -4), AnchorPoint = Vector2.new(1, 1), ZIndex = 26, MaxText = 18, OnClick = function() save(d, "") end })
	end
	Kit.Enter(root)
	task.defer(function() if box.Parent and not Kit.Gamepad() then box:CaptureFocus() end end)
end

return NameDialog
