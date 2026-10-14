--[[
	EggTip — hover an egg, see what it is: species, weight and rarity (in its colour).
	  * world eggs (incubating in your nests, on a rover's rack, in a nest at a site): tagged with EggTip.Tag;
	    the egg nearest the mouse on screen (close enough to it) gets the tip next to the cursor
	  * UI egg slots (hotbar, Bag): EggTip.Bind(button, getInfo) - hover on desktop; on touch a tap shows it for
	    a moment above the button
	Eggs at a site whose rarity is still a secret ("") just say "???".
]]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)

local C = Theme.C
local EggTip = {}
local TAG = "EggTip"

local gui: ScreenGui? = nil
local canvas: Frame? = nil
local card: CanvasGroup? = nil
local glass: Frame? = nil
local nameT, rarT, kgT, pill, accent, iconHolder
local uiOwner: any = nil -- the UI slot showing the tip right now (it wins over world eggs)
local shown = false
local iconKey = ""
local W, H = 250, 84

-- a see-through glass card: the world shows through it, a rarity-coloured edge + accent, the egg itself
-- (tinted to its species), the name big, a rarity chip, the weight. it fades + slides in, follows the cursor softly
local function build()
	if card then return end
	local g, cv = Kit.Screen("DinoEggTip", 45, true, 0.8)
	gui, canvas = g, cv
	local f = Instance.new("CanvasGroup")
	f.Name = "Tip"
	f.Size = UDim2.fromOffset(W, H)
	f.BackgroundTransparency = 1
	f.GroupTransparency = 1
	f.Visible = false
	f.ZIndex = 50
	f.Parent = cv
	local gl = Instance.new("Frame")
	gl.Name = "Glass"
	gl.Size = UDim2.fromScale(1, 1)
	gl.BackgroundColor3 = Color3.fromRGB(12, 26, 18)
	gl.BackgroundTransparency = 0.2
	gl.ZIndex = 50
	gl.Parent = f
	Kit.Corner(gl, 16)
	local edge = Kit.Stroke(gl, C.Cream, 2)
	edge.Name = "Edge"
	edge.Transparency = 0.1
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.45) })
	grad.Parent = gl
	-- a soft highlight across the top, like light on glass
	local sh = Instance.new("Frame")
	sh.Name = "Shine"
	sh.BackgroundColor3 = Color3.new(1, 1, 1)
	sh.BackgroundTransparency = 0.88
	sh.BorderSizePixel = 0
	sh.Size = UDim2.new(1, -16, 0.42, 0)
	sh.Position = UDim2.fromOffset(8, 4)
	sh.ZIndex = 51
	sh.Parent = f
	Kit.Corner(sh, 12)
	local shg = Instance.new("UIGradient")
	shg.Rotation = 90
	shg.Transparency = NumberSequence.new(0, 1)
	shg.Parent = sh
	-- the rarity accent down the left edge
	local ac = Instance.new("Frame")
	ac.Name = "Accent"
	ac.BorderSizePixel = 0
	ac.Size = UDim2.new(0, 5, 1, -22)
	ac.Position = UDim2.new(0, 7, 0.5, 0)
	ac.AnchorPoint = Vector2.new(0, 0.5)
	ac.ZIndex = 52
	ac.Parent = f
	Kit.Corner(ac, 3)
	-- the egg
	local ih = Instance.new("Frame")
	ih.Name = "Egg"
	ih.BackgroundTransparency = 1
	ih.Size = UDim2.fromOffset(62, 62)
	ih.Position = UDim2.new(0, 16, 0.5, 0)
	ih.AnchorPoint = Vector2.new(0, 0.5)
	ih.ZIndex = 53
	ih.Parent = f
	nameT = Kit.Text(f, "", { Size = UDim2.new(1, -96, 0, 26), Position = UDim2.fromOffset(86, 9), Align = Enum.TextXAlignment.Left, Color = Color3.new(1, 1, 1), Stroke = 2.5, Shadow = 2, MaxSize = 24, ZIndex = 54 })
	local pl = Instance.new("Frame")
	pl.Name = "Pill"
	pl.Size = UDim2.fromOffset(96, 20)
	pl.Position = UDim2.fromOffset(86, 40)
	pl.ZIndex = 54
	pl.Parent = f
	Kit.Corner(pl, 10)
	Kit.Stroke(pl, C.Ink, 2)
	rarT = Kit.Text(pl, "", { Pixel = true, Size = UDim2.new(1, -12, 0, 9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.new(1, 1, 1), Stroke = 2, Shadow = 1, MaxSize = 9, ZIndex = 55 })
	kgT = Kit.Text(f, "", { Pixel = true, Size = UDim2.new(1, -96, 0, 9), Position = UDim2.fromOffset(86, 66), Align = Enum.TextXAlignment.Left, Color = C.Cream, Stroke = 1.5, Shadow = 1, MaxSize = 9, ZIndex = 54 })
	card, glass, pill, accent, iconHolder = f, gl, pl, ac, ih
end

local function fill(info)
	build()
	local sp = Config.Species[info.Species or ""]
	Kit.SetText(nameT, ((sp and sp.Name) or tostring(info.Species or "MYSTERY")) .. (info.Dino and "" or " EGG"))
	local r = Config.Rarity[info.Rarity or ""]
	local col = r and r.Color or Color3.fromRGB(150, 156, 164)
	Kit.SetText(rarT, r and r.Name or "???")
	pill.BackgroundColor3 = col:Lerp(Color3.new(0, 0, 0), 0.12)
	pill.Size = UDim2.fromOffset(math.max(56, #(r and r.Name or "???") * 9 + 22), 20)
	accent.BackgroundColor3 = col
	local edge = (glass :: Frame):FindFirstChild("Edge") :: UIStroke
	edge.Color = col:Lerp(Color3.new(1, 1, 1), 0.25)
	local gl = glass :: Frame
	gl.BackgroundColor3 = Color3.fromRGB(12, 26, 18):Lerp(col, 0.12)
	Kit.SetText(kgT, info.KG and ("WEIGHT  " .. Config.FormatKG(info.KG)) or (r and "" or "RARITY UNKNOWN"))
	-- the egg (or the dino) itself, tinted to its species: only rebuilt when it changes
	local key = tostring(info.Species) .. (info.Dino and ":D" or ":E")
	if key ~= iconKey then
		iconKey = key
		for _, ch in ipairs(iconHolder:GetChildren()) do ch:Destroy() end
		Kit.Icon(iconHolder, info.Dino and "Dino" or "Egg", { Species = info.Species, Size = UDim2.fromScale(1, 1), ZIndex = 53 })
	end
end

local function show()
	local f = card :: CanvasGroup
	if shown then return end
	shown = true
	f.Visible = true
	f.GroupTransparency = 1
	local sc = Kit.UIScale(f)
	sc.Scale = 0.92
	game:GetService("TweenService"):Create(f, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
	game:GetService("TweenService"):Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function hide()
	if not shown or not card then return end
	shown = false
	local f = card :: CanvasGroup
	local tw = game:GetService("TweenService"):Create(f, TweenInfo.new(0.1), { GroupTransparency = 1 })
	tw.Completed:Connect(function() if not shown then f.Visible = false end end)
	tw:Play()
end

-- place the card at a screen point (canvas space), nudged so it stays on screen; soft = glide there (world hover)
local function placeAt(screen: Vector2, soft: boolean?)
	local cv, f = canvas :: Frame, card :: CanvasGroup
	local sc = cv:FindFirstChildOfClass("UIScale")
	local k = sc and sc.Scale or 1
	local p = (screen - cv.AbsolutePosition) / k
	local x = math.clamp(p.X + 18, 4, cv.AbsoluteSize.X / k - W - 4)
	local y = math.clamp(p.Y - H - 10, 4, cv.AbsoluteSize.Y / k - H - 4)
	local want = UDim2.fromOffset(x, y)
	if soft and shown then
		local cur = f.Position
		f.Position = UDim2.fromOffset(cur.X.Offset + (x - cur.X.Offset) * 0.35, cur.Y.Offset + (y - cur.Y.Offset) * 0.35)
	else
		f.Position = want
	end
end

-- a world egg: its info rides on the model
function EggTip.Tag(model: Model, species: string?, rarity: string?, kg: number?)
	model:SetAttribute("TipSpecies", species)
	model:SetAttribute("TipRarity", rarity or "")
	model:SetAttribute("TipKG", kg)
	CollectionService:AddTag(model, TAG)
end

-- a UI slot: hover (mouse) or tap (touch) shows the tip by it; getInfo returns { Species, Rarity, KG, Dino? } or nil
function EggTip.Bind(button: GuiButton, getInfo: () -> any)
	button.MouseEnter:Connect(function()
		local info = getInfo()
		if not info then return end
		uiOwner = button
		fill(info)
		local a = button.AbsolutePosition + GuiService:GetGuiInset() -- (UI slots sit below the top bar; the tip layer doesn't)
		placeAt(Vector2.new(a.X + button.AbsoluteSize.X * 0.5 - 30, a.Y + 6))
		show()
	end)
	button.MouseLeave:Connect(function()
		if uiOwner == button then uiOwner = nil hide() end
	end)
	button.Activated:Connect(function()
		if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then return end
		local info = getInfo()
		if not info then return end
		uiOwner = button
		fill(info)
		local a = button.AbsolutePosition + GuiService:GetGuiInset()
		placeAt(Vector2.new(a.X + button.AbsoluteSize.X * 0.5 - 30, a.Y + 6))
		show()
		task.delay(2, function() if uiOwner == button then uiOwner = nil hide() end end)
	end)
end

local pickAt, tipShown = 0, false
local sizes = setmetatable({}, { __mode = "k" }) :: { [Model]: Vector3 }
function EggTip.Start()
	build()
	RunService.RenderStepped:Connect(function()
		if uiOwner then
			-- the slot went away (the Bag refreshed / closed, a cutscene hid the HUD): drop the tip
			local sg = uiOwner:FindFirstAncestorWhichIsA("ScreenGui")
			if not uiOwner:IsDescendantOf(game) or not uiOwner.Visible or (sg and not sg.Enabled) then
				uiOwner = nil
				hide()
			end
			return
		end
		if Cinema.Playing() or not UserInputService.MouseEnabled then hide() return end
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local mouse = UserInputService:GetMouseLocation()
		-- (the hover pick ~15 times a second, not every frame: it walks every tagged egg on every plot; the tip
		-- itself still follows the mouse every frame)
		if os.clock() < pickAt then
			if tipShown then placeAt(mouse, true) end
			return
		end
		pickAt = os.clock() + 0.066
		local best, bestD, bestM = nil, math.huge, nil
		for _, m in ipairs(CollectionService:GetTagged(TAG)) do
			if not (m:IsA("Model") and m.Parent) then continue end
			local ok, pivot = pcall(function() return m:GetPivot().Position end)
			if not ok then continue end
			local dist = (pivot - cam.CFrame.Position).Magnitude
			if dist > 140 then continue end
			local sp, on = cam:WorldToViewportPoint(pivot)
			if not on then continue end
			-- close enough to the cursor: about the egg's size on screen (never less than a fingertip)
			local size = sizes[m]
			if not size then
				size = select(2, m:GetBoundingBox())
				sizes[m] = size
			end
			local px = math.max(26, (size.Y * 0.6) / math.max(1, dist) * cam.ViewportSize.Y / (2 * math.tan(math.rad(cam.FieldOfView / 2))))
			local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
			if d < px and d < bestD then best, bestD, bestM = m, d, sp end
		end
		if best then
			fill({ Species = best:GetAttribute("TipSpecies"), Rarity = best:GetAttribute("TipRarity"), KG = best:GetAttribute("TipKG") })
			placeAt(mouse, true)
			show()
			tipShown = true
		else
			hide()
			tipShown = false
		end
		local _ = bestM
	end)
	local _ = Players
end

return EggTip
