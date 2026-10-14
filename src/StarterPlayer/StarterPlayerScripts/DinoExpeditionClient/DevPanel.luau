--[[
	DevPanel — developer showcase controls (shown in Studio; press P to toggle anywhere).
	Click a dinosaur in the world or in the list to select it, then trigger animations / cinematics.
	Runs locally (instant iteration); the ProximityPrompts on the pedestals broadcast to everyone.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DevPanel = {}

local FONT = Font.new("rbxasset://fonts/families/PressStart2P.json")
local ACTIONS = {
	{ "Idle", "IDLE" }, { "Walk", "WALK" }, { "Run", "RUN" }, { "Roar", "ROAR*" },
	{ "Attack", "ATTACK*" }, { "Chase", "CHASE*" }, { "LookAround", "LOOK" }, { "Sniff", "SNIFF" },
	{ "Stunned", "STUNNED" }, { "Special", "SPECIAL" }, { "Signature", "SIGNATURE*" }, { "Reset", "RESET" },
}

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end

local function button(parent, text, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = color or Color3.fromRGB(46, 50, 60)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.FontFace = FONT
	b.TextSize = 9
	b.Text = text
	b.AutoButtonColor = true
	corner(b, 7)
	b.Parent = parent
	return b
end

function DevPanel.mount(Showcase)
	local player = Players.LocalPlayer
	local selected: Model? = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoShowcasePanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	local frame = Instance.new("Frame")
	frame.Position = UDim2.new(0, 14, 0.5, -230)
	frame.Size = UDim2.fromOffset(250, 460)
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	frame.BackgroundTransparency = 0.08
	corner(frame, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 176, 46)
	stroke.Thickness = 2
	stroke.Parent = frame
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 26)
	title.FontFace = FONT
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 196, 64)
	title.Text = "DINO SHOWCASE  ·  P"
	title.Parent = frame

	local sel = Instance.new("TextLabel")
	sel.BackgroundTransparency = 1
	sel.Position = UDim2.fromOffset(12, 34)
	sel.Size = UDim2.new(1, -24, 0, 20)
	sel.FontFace = FONT
	sel.TextSize = 8
	sel.TextXAlignment = Enum.TextXAlignment.Left
	sel.TextColor3 = Color3.fromRGB(200, 205, 215)
	sel.Text = "Click a dinosaur to select"
	sel.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(10, 58)
	list.Size = UDim2.new(1, -20, 0, 104)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = frame
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 4)
	ll.Parent = list

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(10, 170)
	grid.Size = UDim2.new(1, -20, 1, -180)
	grid.Parent = frame
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(0.5, -4, 0, 30)
	gl.CellPadding = UDim2.fromOffset(8, 6)
	gl.Parent = grid

	local function highlight(model: Model?, on: boolean)
		if not model then return end
		local h = model:FindFirstChild("Outline")
		if h and h:IsA("Highlight") then
			h.OutlineColor = on and Color3.fromRGB(255, 196, 64) or Color3.fromRGB(20, 20, 20)
			h.OutlineTransparency = on and 0 or 0.45
		end
	end

	local function select(model: Model)
		highlight(selected, false)
		selected = model
		highlight(model, true)
		sel.Text = "Selected: " .. (model:GetAttribute("DisplayName") or model.Name)
	end

	local listed = {}
	local function addToList(model: Model)
		if listed[model] or not model:IsDescendantOf(Workspace) then return end
		listed[model] = true
		local b = button(list, model:GetAttribute("DisplayName") or model.Name, Color3.fromRGB(36, 40, 48))
		b.Activated:Connect(function() select(model) end)
		model.Destroying:Connect(function() b:Destroy() listed[model] = nil end)
	end
	for _, m in ipairs(CollectionService:GetTagged("DinoExpeditionDinosaur")) do addToList(m) end
	CollectionService:GetInstanceAddedSignal("DinoExpeditionDinosaur"):Connect(function(m) task.defer(addToList, m) end)

	for _, a in ipairs(ACTIONS) do
		local action, label = a[1], a[2]
		local color = action == "Signature" and Color3.fromRGB(196, 120, 24) or nil
		local b = button(grid, label, color)
		b.Activated:Connect(function()
			if selected then Showcase.Perform(selected, action, true) end
		end)
	end

	-- click a creature in the world to select it
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local cam = Workspace.CurrentCamera
			local ray = cam:ViewportPointToRay(input.Position.X, input.Position.Y)
			local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000)
			if hit then
				local inst = hit.Instance
				while inst and inst ~= Workspace do
					if inst:IsA("Model") and CollectionService:HasTag(inst, "DinoExpeditionDinosaur") then
						select(inst)
						break
					end
					inst = inst.Parent
				end
			end
		elseif input.KeyCode == Enum.KeyCode.P then
			gui.Enabled = not gui.Enabled
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

return DevPanel
