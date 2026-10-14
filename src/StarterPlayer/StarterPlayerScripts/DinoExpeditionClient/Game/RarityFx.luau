--[[
	RarityFx — how a rarity looks on anything (a hatched dino, an egg, a buddy, a statue):
	  COMMON     plain
	  UNCOMMON   green glints
	  RARE       blue sparkles + a soft light
	  EPIC       a purple swirl, a light, a crystal tint on the skin
	  LEGENDARY  a gold skin, golden rays and sparkles, a gold outline
	  SECRET     a dark shimmering skin, a cycling rainbow outline, black-hole motes
	Plus Tag(): the floating name tag (name, rarity badge, KG, $/s) used at your base.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local Kit = require(script.Parent.UI.Kit)

local RarityFx = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD = Color3.fromRGB(255, 205, 70)

local rainbow = {} :: { [Instance]: boolean }
RunService.RenderStepped:Connect(function()
	local h = (os.clock() * 0.25) % 1
	for inst in pairs(rainbow) do
		if not inst.Parent then rainbow[inst] = nil continue end
		if inst:IsA("Highlight") then
			inst.OutlineColor = Color3.fromHSV(h, 0.8, 1)
		elseif inst:IsA("TextLabel") then
			inst.TextColor3 = Color3.fromHSV(h, 0.7, 1)
		elseif inst:IsA("UIStroke") then
			inst.Color = Color3.fromHSV((h + 0.5) % 1, 0.8, 1)
		end
	end
end)
function RarityFx.Rainbow(inst: Instance)
	rainbow[inst] = true
end

local function emitter(host: Instance, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.Texture or SPARK
	e.Rate = props.Rate or 6
	e.Lifetime = NumberRange.new(props.Life or 0.8, (props.Life or 0.8) * 1.6)
	e.Speed = NumberRange.new(props.Speed or 1, (props.Speed or 1) * 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, props.Size or 0.4), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(props.Color)
	e.LightEmission = props.Glow or 1
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	if props.Accel then e.Acceleration = props.Accel end
	if props.Emission then e.Shape = Enum.ParticleEmitterShape.Box e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end
	e.Name = "RarityFx"
	e.Parent = host
	return e
end

local function tint(model: Model, color: Color3, amount: number, material: Enum.Material?)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 and not d.Name:match("^VFX_") then
			d.Color = d.Color:Lerp(color, amount)
			if material and d.Material ~= Enum.Material.Neon then d.Material = material end
		end
	end
end

-- dress a model in its rarity. size: rough model size (studs) to scale the effects
function RarityFx.Apply(model: Model, rarity: string, size: number?)
	local r = Config.Rarity[rarity]
	if not r then return end
	local root = model.PrimaryPart
	if not root then return end
	local s = size or 4
	local order = r.Order
	if order >= 2 then
		local att = Instance.new("Attachment")
		att.Name = "RarityAtt"
		att.Position = Vector3.new(0, s * 0.3, 0)
		att.Parent = root
		local box = Instance.new("Part")
		box.Name = "RarityVolume"
		box.Transparency = 1
		box.CanCollide, box.CanQuery, box.CanTouch, box.Anchored = false, false, false, false
		box.Size = Vector3.new(s * 0.8, s * 0.7, s * 1.1)
		box.CFrame = root.CFrame * CFrame.new(0, s * 0.15, 0)
		box.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, box
		w.Parent = box
		box.Parent = model
		if order == 2 then
			emitter(box, { Color = r.Color, Rate = 3, Size = 0.35, Life = 0.7, Speed = 0.6, Emission = true })
		elseif order == 3 then
			emitter(box, { Color = r.Color, Rate = 7, Size = 0.45, Life = 0.9, Speed = 0.8, Emission = true })
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = r.Color, s * 1.6, 0.6
			l.Parent = box
		elseif order == 4 then
			tint(model, r.Color, 0.12)
			emitter(box, { Color = r.Color, Rate = 12, Size = 0.55, Life = 1.1, Speed = 1.2, Emission = true, Accel = Vector3.new(0, 1.5, 0) })
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = r.Color, s * 2, 0.9
			l.Parent = box
		elseif order == 5 then
			tint(model, GOLD, 0.42, Enum.Material.SmoothPlastic)
			emitter(box, { Color = GOLD, Rate = 16, Size = 0.6, Life = 1.2, Speed = 1.4, Emission = true, Accel = Vector3.new(0, 2, 0) })
			emitter(att, { Color = Color3.fromRGB(255, 240, 180), Rate = 2, Size = s * 0.6, Life = 0.8, Speed = 0, Texture = "rbxasset://textures/particles/sparkles_main.dds", Glow = 0.6 })
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = GOLD, s * 2.4, 1.2
			l.Parent = box
			local hl = Instance.new("Highlight")
			hl.FillTransparency = 1
			hl.OutlineColor = GOLD
			hl.OutlineTransparency = 0.2
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = model
		else
			tint(model, Color3.fromRGB(20, 18, 30), 0.55)
			emitter(box, { Color = Color3.fromRGB(180, 120, 255), Rate = 18, Size = 0.6, Life = 1.4, Speed = 1, Emission = true, Accel = Vector3.new(0, -1, 0) })
			emitter(box, { Color = Color3.fromRGB(255, 255, 255), Rate = 8, Size = 0.35, Life = 1, Speed = 2, Emission = true })
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = Color3.fromRGB(190, 120, 255), s * 2.6, 1.4
			l.Parent = box
			local hl = Instance.new("Highlight")
			hl.FillTransparency = 0.85
			hl.FillColor = Color3.fromRGB(40, 10, 70)
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = model
			RarityFx.Rainbow(hl)
		end
	end
end

-- the floating tag over a dino at your base
function RarityFx.Tag(host: BasePart, d, height: number): BillboardGui
	local r = Config.Rarity[d.Rarity]
	local sp = Config.Species[d.Species]
	local bb = Instance.new("BillboardGui")
	bb.Name = "DinoTag"
	bb.Size = UDim2.fromOffset(200, 74)
	bb.StudsOffset = Vector3.new(0, height, 0)
	bb.MaxDistance = 45
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromScale(0.5, 0)
	badge.Size = UDim2.fromOffset(120, 20)
	badge.BackgroundColor3 = r.Color
	badge.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = badge
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(16, 26, 19)
	st.Thickness = 2.5
	st.Parent = badge
	local rt = Kit.Text(badge, r.Name, { Size = UDim2.new(1, -10, 0, 12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Pixel = true, Stroke = 2, Shadow = 0, MaxSize = 12 })
	if d.Rarity == "Secret" then
		local main = rt:FindFirstChild("Main")
		if main then RarityFx.Rainbow(main) end
	end
	-- (a named dino goes by its name - DINO NAMES, Showcase.luau - and its species joins the small line)
	local named = typeof(d.Name) == "string" and d.Name ~= ""
	Kit.Text(bb, Config.DinoName(d), { Name = "DinoName", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 22), Stroke = 3, Shadow = 2, MaxSize = 22, Color = named and Color3.fromRGB(255, 233, 138) or nil })
	local stats = Config.FormatKG(d.KG or 0) .. "  •  $" .. Config.FormatNumber(Config.DinoIncome(d)) .. "/s"
	if named then stats = (sp and sp.Name or tostring(d.Species)) .. "  •  " .. stats end
	Kit.Text(bb, stats, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 48), Stroke = 2.5, Shadow = 1, MaxSize = 16, Color = Color3.fromRGB(200, 255, 140) })
	bb.Parent = host
	return bb
end

return RarityFx
