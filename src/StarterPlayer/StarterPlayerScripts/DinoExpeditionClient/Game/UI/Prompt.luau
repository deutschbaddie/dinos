--[[
	Prompt — custom ProximityPrompt look for every prompt in the game.
	A transparent card with a soft glow gradient in the prompt's theme colour, a chunky key cap that
	fills up while you hold, Press Start 2P text, a breathing pulse while idle, and a burst on trigger.
	Works with keyboard, gamepad and touch (tap or hold the card itself).
	The card only takes clicks while the cursor is free: in shift lock / first person / the fight cam the mouse
	is pinned to the centre, and an Active card under it would swallow mouse movement (the camera stops turning).

	Theme per prompt: attribute PromptColor (swatch name) or by role — garage yellow, shop orange,
	time gate teal, hatch lime, nest red.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local C = Theme.C
local Prompt = {}
-- a prompt can outline something other than its own model (a nest prompt outlines the egg in it)
Prompt.OutlineTargets = (setmetatable({}, { __mode = "k" }) :: any) :: { [ProximityPrompt]: Instance }
local active = {} :: { [ProximityPrompt]: any }

local function themeFor(prompt: ProximityPrompt)
	local named = prompt:GetAttribute("PromptColor")
	if named and Theme.Swatch[named] then return Theme.Swatch[named] end
	local a = prompt:GetAttribute("CampAction")
	if a == "Garage" then return Theme.Swatch.Yellow end
	if a == "Shop" or a == "Build" then return Theme.Swatch.Orange end -- (Build: the island UPGRADE boards)
	if a == "Era" then return Theme.Swatch.Teal end
	if a == "Hatch" or a == "Grow" then return Theme.Swatch.Lime end
	if prompt:GetAttribute("NestId") then return Theme.Swatch.Red end
	if prompt:GetAttribute("DinoAction") then return Theme.Swatch.Purple end
	return Theme.Swatch.Yellow
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then return "TAP" end
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local n = prompt.GamepadKeyCode.Name:gsub("^Button", "")
		return n
	end
	local n = prompt.KeyboardKeyCode.Name
	return #n <= 3 and n or n:sub(1, 3)
end

local function build(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local sw = themeFor(prompt)
	local k = Kit.ScaleFactor()
	local bb = Instance.new("BillboardGui")
	bb.Name = "DinoPrompt"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Size = UDim2.fromOffset(330 * k, 96 * k)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.Adornee = prompt.Parent :: any
	bb.Active = true
	bb.ClipsDescendants = false
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = bb
	local wrap = Instance.new("Frame")
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.fromOffset(330, 96)
	wrap.Parent = holder
	local scale = Instance.new("UIScale")
	scale.Scale = k
	scale.Parent = wrap
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = wrap
	local pop = Instance.new("UIScale")
	pop.Scale = 0.3
	pop.Parent = canvas

	-- glow: transparent card, colour fading out to the right
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.BackgroundColor3 = sw[1]
	glow.BorderSizePixel = 0
	glow.Size = UDim2.new(1, 0, 0, 70)
	glow.Position = UDim2.fromOffset(0, 13)
	glow.Parent = canvas
	Kit.Corner(glow, 35)
	local gg = Instance.new("UIGradient")
	gg.Color = ColorSequence.new(sw[2], sw[1])
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.45, 0.6), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = glow
	local glowStroke = Kit.Stroke(glow, sw[2], 2)
	glowStroke.Transparency = 0.4
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) })
	sg.Parent = glowStroke
	-- dark core behind the text so it reads on bright scenes
	local core = Instance.new("Frame")
	core.BackgroundColor3 = C.Ink
	core.BackgroundTransparency = 0.45
	core.BorderSizePixel = 0
	core.Size = UDim2.new(1, -40, 0, 56)
	core.Position = UDim2.fromOffset(34, 20)
	core.Parent = canvas
	Kit.Corner(core, 28)
	local cg = Instance.new("UIGradient")
	cg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) })
	cg.Parent = core

	-- the key cap (a mini toy brick) with the hold fill
	local key = Instance.new("Frame")
	key.Name = "Key"
	key.BackgroundColor3 = sw[3]
	key.Size = UDim2.fromOffset(66, 66)
	key.Position = UDim2.fromOffset(10, 15)
	key.ZIndex = 3
	key.Parent = canvas
	Kit.Corner(key, 14)
	Kit.Stroke(key, C.Ink, 3)
	local keyFace = Instance.new("Frame")
	keyFace.BackgroundColor3 = sw[1]
	keyFace.Size = UDim2.new(1, 0, 1, -6)
	keyFace.ZIndex = 3
	keyFace.ClipsDescendants = true
	keyFace.Parent = key
	Kit.Corner(keyFace, 14)
	Kit.Gradient(keyFace, sw[2], sw[1])
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BackgroundTransparency = 0.35
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.ZIndex = 4
	fill.Parent = keyFace
	local kt = keyText(prompt, inputType)
	Kit.Text(keyFace, kt, { Size = UDim2.new(0.8, 0, #kt > 1 and 0.32 or 0.5, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Stroke = 3, Shadow = 2 })
	Kit.Studs(keyFace, sw[1], { Count = 2, W = 14, Gap = 10, Inset = 10 })
	-- pulse ring around the key
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1, 1)
	ring.ZIndex = 2
	ring.Parent = key
	Kit.Corner(ring, 16)
	local ringStroke = Kit.Stroke(ring, sw[2], 3)

	-- text
	local object = Kit.Text(canvas, string.upper(prompt.ObjectText), { Size = UDim2.new(1, -110, 0, 11), Position = UDim2.fromOffset(90, 28), Align = Enum.TextXAlignment.Left, Color = sw[2], ZIndex = 5, Shadow = 2, Stroke = 2 })
	local action = Kit.Text(canvas, string.upper(prompt.ActionText), { Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(90, 46), Align = Enum.TextXAlignment.Left, ZIndex = 5, Shadow = 3, Stroke = 3 })
	local underline = Instance.new("Frame")
	underline.BackgroundColor3 = sw[2]
	underline.BorderSizePixel = 0
	underline.Size = UDim2.fromOffset(0, 3)
	underline.Position = UDim2.fromOffset(90, 70)
	underline.ZIndex = 5
	underline.Parent = canvas
	local ug = Instance.new("UIGradient")
	ug.Transparency = NumberSequence.new(0, 1)
	ug.Parent = underline

	-- touch / click on the card itself
	local btn = Instance.new("TextButton")
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Size = UDim2.fromScale(1, 1)
	btn.ZIndex = 10
	btn.Parent = canvas
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			btn:SetAttribute("Held", true)
			prompt:InputHoldBegin()
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			btn:SetAttribute("Held", nil)
			prompt:InputHoldEnd()
		end
	end)

	bb.Parent = player:WaitForChild("PlayerGui")
	-- entrance
	TweenService:Create(pop, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(underline, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.1), { Size = UDim2.fromOffset(200, 3) }):Play()
	local state = { Btn = btn, Clickable = true, BB = bb, Pop = pop, Fill = fill, Key = key, KeyFace = keyFace, Ring = ring, RingStroke = ringStroke, Glow = glow, Sw = sw, Alive = true, Holding = false }
	-- idle breathing pulse
	task.spawn(function()
		while state.Alive do
			if not state.Holding then
				ring.Size = UDim2.fromScale(1, 1)
				ringStroke.Transparency = 0.1
				TweenService:Create(ring, TweenInfo.new(1.0, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1.45, 1.45) }):Play()
				TweenService:Create(ringStroke, TweenInfo.new(1.0, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
			end
			task.wait(1.3)
		end
	end)
	return state
end

local function hide(prompt: ProximityPrompt)
	local st = active[prompt]
	if not st then return end
	active[prompt] = nil
	st.Alive = false
	local tw = TweenService:Create(st.Pop, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.2 })
	tw.Completed:Connect(function() st.BB:Destroy() end)
	tw:Play()
end

-- clicks on the card are only for a free cursor (or touch); a locked mouse must keep turning the camera
local function cursorFree(): boolean
	return UserInputService.MouseBehavior == Enum.MouseBehavior.Default
end
local function setClickable(st, on: boolean)
	if st.Clickable == on then return end
	st.Clickable = on
	st.BB.Active = on
	st.Btn.Visible = on
	-- a hold that started as a click on the card would never see its release once the card is hidden
	if not on and st.Btn:GetAttribute("Held") and st.Prompt then
		st.Btn:SetAttribute("Held", nil)
		st.Prompt:InputHoldEnd()
	end
end

local function customize(p: Instance)
	if p:IsA("ProximityPrompt") then
		p.Style = Enum.ProximityPromptStyle.Custom
		-- a prompt only its owner may use (a parked rover's DRIVE): switched off on everyone else's screen
		local owner = p:GetAttribute("OwnerOnly")
		if owner and owner ~= player.UserId then p.Enabled = false end
		-- ...and one for everyone BUT its owner (a rover's RIDE ALONG seats: Carpool)
		if p:GetAttribute("NotOwner") == player.UserId then p.Enabled = false end
	end
end

-- RIDE ALONG (Carpool) only while it means something (2026-10-13, user: "when driving with a friend get rid of the
-- ride with friend prompt"): never once you're sat in a seat yourself, and never on a rover that's on the move
local ridePrompts = {} :: { [ProximityPrompt]: boolean }
local function stepRidePrompts()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seated = hum ~= nil and hum.SeatPart ~= nil
	for pr in pairs(ridePrompts) do
		if not pr.Parent then ridePrompts[pr] = nil continue end
		if pr:GetAttribute("NotOwner") == player.UserId then continue end
		local v = pr:FindFirstAncestorWhichIsA("Model")
		while v and v.Parent and not v:GetAttribute("Owner") do v = v.Parent:FindFirstAncestorWhichIsA("Model") end
		local root = v and v.PrimaryPart
		local moving = root ~= nil and root.AssemblyLinearVelocity.Magnitude > 3
		local seat = pr.Parent
		local taken = seat ~= nil and (seat:GetAttribute("Taken") ~= nil or (seat:IsA("Seat") and seat.Occupant ~= nil))
		local want = not seated and not moving and not taken
		if pr.Enabled ~= want then pr.Enabled = want end
	end
end

function Prompt.Start()
	for _, d in ipairs(Workspace:GetDescendants()) do customize(d) end
	Workspace.DescendantAdded:Connect(customize)
	local function trackRide(d: Instance)
		if d:IsA("ProximityPrompt") and d.Name == "RidePrompt" then ridePrompts[d] = true end
	end
	for _, d in ipairs(Workspace:GetDescendants()) do trackRide(d) end
	Workspace.DescendantAdded:Connect(trackRide)
	local acc = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then return end
		acc = 0
		stepRidePrompts()
	end)
	-- prompts marked Outline light up the thing they act on (which egg you're about to pick up, which nest)
	local outlines = {} :: { [ProximityPrompt]: Highlight }
	local targets = Prompt.OutlineTargets
	local function outline(prompt: ProximityPrompt, on: boolean)
		local h = outlines[prompt]
		if not on then
			if h then h:Destroy() outlines[prompt] = nil end
			return
		end
		local explicit = targets[prompt]
		if h or not (prompt:GetAttribute("Outline") or explicit) then return end
		local target = (explicit and explicit.Parent and explicit) or prompt:FindFirstAncestorWhichIsA("Model") or prompt.Parent
		if not target then return end
		local hl = Instance.new("Highlight")
		hl.Name = "DinoPromptOutline"
		hl.FillTransparency = 0.82
		hl.FillColor = Color3.fromRGB(255, 236, 160)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Adornee = target
		hl.Parent = target
		outlines[prompt] = hl
	end
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if active[prompt] then hide(prompt) end
		local st = build(prompt, inputType)
		st.Prompt = prompt
		active[prompt] = st
		setClickable(st, cursorFree())
		outline(prompt, true)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		outline(prompt, false)
		hide(prompt)
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local st = active[prompt]
		if not st then return end
		st.Holding = true
		st.Fill.Size = UDim2.fromScale(1, 0)
		TweenService:Create(st.Fill, TweenInfo.new(math.max(prompt.HoldDuration, 0.05), Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
		TweenService:Create(st.KeyFace, TweenInfo.new(0.08), { Position = UDim2.fromOffset(0, 4) }):Play()
		TweenService:Create(st.Pop, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.06 }):Play()
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		local st = active[prompt]
		if not st then return end
		st.Holding = false
		TweenService:Create(st.Fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(1, 0) }):Play()
		TweenService:Create(st.KeyFace, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(0, 0) }):Play()
		TweenService:Create(st.Pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	-- the camera scripts set MouseBehavior every frame, so follow it per frame (only a few cards are ever live)
	game:GetService("RunService").RenderStepped:Connect(function()
		if next(active) == nil then return end
		local free = cursorFree()
		for _, st in pairs(active) do setClickable(st, free) end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local st = active[prompt]
		if not st then return end
		-- burst: flash the key, blow the ring out, punch the card
		st.Fill.Size = UDim2.fromScale(1, 1)
		st.Fill.BackgroundTransparency = 0
		TweenService:Create(st.Fill, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		st.Ring.Size = UDim2.fromScale(1, 1)
		st.RingStroke.Transparency = 0
		st.RingStroke.Thickness = 5
		TweenService:Create(st.Ring, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(2.2, 2.2) }):Play()
		TweenService:Create(st.RingStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		st.Pop.Scale = 1.15
		TweenService:Create(st.Pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
end

return Prompt
