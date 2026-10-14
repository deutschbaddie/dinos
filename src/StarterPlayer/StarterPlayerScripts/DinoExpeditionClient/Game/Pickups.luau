--[[
	Pickups — things that drop in the world for you to walk over and pick up. First user: BOSS KEYS.

	A takedown can knock a ruler's key out of a dino (the server rolls it per hunter; only you see yours):
	it flies out of the dino, bounces, and floats over the grass, turning, with a soft glint and a "BOSS KEY!" tag.
	Walk up and press the prompt: you crouch, grab it, stand and hold it high (PlayerAnim "Pickup", which
	everyone around sees), then it zips away into your bag. Drive off without it and the server stops you.

	Pickups.Grab(model, opts) is the reusable part: any held-up item runs through it.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Kit = require(script.Parent.UI.Kit)
local Prompt = require(script.Parent.UI.Prompt)
local CineKit = require(script.Parent.UI.CineKit)
local Net = require(script.Parent.Net)
local Audio = require(script.Parent.Audio)
local PlayerAnim = require(script.Parent.PlayerAnim)

local player = Players.LocalPlayer
local C = Kit.Colors
local Pickups = {}

local SCALE = 1.6
local live = {} :: { [number]: any } -- key id -> state
local busy = false

local GEM = { TyrantKing = Color3.fromRGB(255, 106, 31), Titan = Color3.fromRGB(46, 230, 200), Tidebreaker = Color3.fromRGB(70, 175, 235) }

local function folder(): Folder
	local f = Workspace:FindFirstChild("DinoPickups")
	if not f then
		f = Instance.new("Folder")
		f.Name = "DinoPickups"
		f.Parent = Workspace
	end
	return f :: Folder
end

local function prep(m: Model)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		end
	end
end

-- the hand that holds things up (R15 RightHand, R6 the bottom of the Right Arm)
local function handCFrame(char: Model): CFrame?
	local hand = char:FindFirstChild("RightHand") :: BasePart?
	if hand then return hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.05, 0) end
	local arm = char:FindFirstChild("Right Arm") :: BasePart?
	if arm then return arm.CFrame * CFrame.new(0, -arm.Size.Y / 2 - 0.05, 0) end
	return nil
end

-- the reusable bit: crouch, grab, stand and hold it high, then it zips off. opts: { Title, Sub, Color, OnDone }
function Pickups.Grab(m: Model, opts)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hrp) then m:Destroy() return end
	PlayerAnim.Act(char, "Pickup")
	local root = m.PrimaryPart :: BasePart
	local grip = root and root:FindFirstChild("Grip") :: Attachment?
	local gripLocal = grip and grip.CFrame or CFrame.identity
	-- held upright by its grip, shaft to the sky (the raised hand's -Y points up)
	local holdRot = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
	local from = m:GetPivot()
	local t0 = os.clock()
	local shown = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local hand = handCFrame(char)
		if not hand or not m.Parent then conn:Disconnect() return end
		local inHand = hand * holdRot * gripLocal:Inverse()
		if t < 0.3 then
			-- the hand reaches down: the item eases into it
			local u = t / 0.3
			m:PivotTo(from:Lerp(inHand, u * u * (3 - 2 * u)))
		elseif t < 1.45 then
			-- up it goes, held high, a little wobble and a glint
			m:PivotTo(inHand * CFrame.Angles(0, math.sin(t * 6) * 0.25, 0))
			if not shown and t > 0.75 then
				shown = true
				local top = inHand.Position + Vector3.new(0, 1.5, 0)
				CineKit.Sparkle(top, opts.Color or C.YellowHi, 1.3)
				DinosaurVFX.Cubes(top, 16, { opts.Color or C.YellowHi, Color3.new(1, 1, 1) }, 0.25, 14, 0.8)
				Audio.Sting("ItemGet", 0.8)
				Pickups.Callout(opts.Title or "GOT IT!", opts.Sub, opts.Color)
			end
		else
			-- then it zips up and away into your bag
			local u = math.clamp((t - 1.45) / 0.35, 0, 1)
			local s = 1 - u
			m:PivotTo(inHand * CFrame.new(0, 0, 0) + Vector3.new(0, u * u * 8, 0))
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.Transparency < 1 then p.LocalTransparencyModifier = 1 - s end
			end
			if u >= 1 then
				conn:Disconnect()
				m:Destroy()
				if opts.OnDone then opts.OnDone() end
			end
		end
	end)
end

-- a big friendly call-out in the middle of the screen ("BOSS KEY!")
local calloutGui, calloutCanvas
function Pickups.Callout(title: string, sub: string?, color: Color3?)
	if not calloutGui then calloutGui, calloutCanvas = Kit.Screen("DinoPickupCallout", 32, false) end
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(620, 110)
	holder.Position = UDim2.new(0.5, 0, 0.32, 0)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Parent = calloutCanvas
	local col = color or C.YellowHi
	Kit.Text(holder, title, { Size = UDim2.new(1, 0, 0, 62), Color = col:Lerp(Color3.new(1, 1, 1), 0.35), Color2 = col, Stroke = 5, Shadow = 5, MaxSize = 64, Rotation = -3 })
	if sub then Kit.Text(holder, sub, { Pixel = true, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 74), Color = C.Cream, Stroke = 2.5, Shadow = 2, MaxSize = 14 }) end
	Kit.Pop(holder, 0.3)
	task.delay(2.2, function() if holder.Parent then Kit.Exit(holder, true) end end)
end

--------------------------------------------------------------------------------
-- boss keys
--------------------------------------------------------------------------------
local function removeKey(id: number)
	local k = live[id]
	if not k then return end
	live[id] = nil
	if k.Conn then k.Conn:Disconnect() end
	if k.Model and k.Model.Parent then k.Model:Destroy() end
	if k.Extras then for _, x in ipairs(k.Extras) do x:Destroy() end end
end

local function spawnKey(info)
	local tpl = DinoShared:FindFirstChild("Pickups") and DinoShared.Pickups:FindFirstChild("BossKey_" .. tostring(info.Boss))
	if not tpl then return end
	removeKey(info.Id)
	local m = tpl:Clone() :: Model
	prep(m)
	m:ScaleTo(SCALE)
	m.Parent = folder()
	local root = m.PrimaryPart :: BasePart
	local gem = GEM[info.Boss] or C.YellowHi
	local k = { Id = info.Id, Model = m, Extras = {}, Pos = info.Pos, Boss = info.Boss, Landed = false } :: any
	live[info.Id] = k
	-- a soft glint: a small light, sparkles, and a faint pillar so you spot it across the clearing
	local light = Instance.new("PointLight")
	light.Color = gem
	light.Brightness = 1.2
	light.Range = 9
	light.Parent = root
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Rate = 8
	sp.Lifetime = NumberRange.new(0.6, 1.1)
	sp.Speed = NumberRange.new(0.5, 1.5)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sp.LightEmission = 0.6
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 236, 160), gem)
	sp.Parent = root
	local pillar = Instance.new("Part")
	pillar.Name = "KeyPillar"
	pillar.Anchored, pillar.CanCollide, pillar.CanQuery, pillar.CanTouch, pillar.CastShadow = true, false, false, false, false
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(16, 1.2, 1.2)
	pillar.Material = Enum.Material.SmoothPlastic
	pillar.Color = Color3.fromRGB(255, 226, 122)
	pillar.Transparency = 0.82
	pillar.CFrame = CFrame.new(info.Pos + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	pillar.Parent = folder()
	table.insert(k.Extras, pillar)
	-- the tag over it
	local bb = Instance.new("BillboardGui")
	bb.Name = "KeyTag"
	bb.Size = UDim2.fromOffset(180, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	bb.Adornee = root
	Kit.Text(bb, "BOSS KEY!", { Size = UDim2.fromScale(1, 1), Color = C.YellowHi, Color2 = C.Orange, Stroke = 3.5, Shadow = 3, MaxSize = 30 })
	bb.Parent = root
	-- the prompt (local: only you see your key; the server checks the pickup)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Pick Up"
	pr.ObjectText = "Boss Key"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Enabled = false -- on once it has landed (Landed below)
	pr:SetAttribute("PickupKey", info.Id)
	pr:SetAttribute("PromptColor", "Yellow")
	pr:SetAttribute("Outline", true)
	pr.Parent = root
	Prompt.OutlineTargets[pr] = m
	k.Prompt = pr
	-- out of the dino: a high arc, two bounces, then it floats and turns
	local from = (info.From or info.Pos) + Vector3.new(0, 4, 0)
	local rest = info.Pos + Vector3.new(0, 1.9, 0)
	local t0 = os.clock()
	local spinA = math.random() * math.pi * 2
	DinosaurVFX.Cubes(from, 14, { Color3.fromRGB(255, 220, 110), Color3.new(1, 1, 1) }, 0.25, 16, 0.7)
	Audio.Sting("ItemDrop", 0.6)
	k.Conn = RunService.RenderStepped:Connect(function(dt)
		if not m.Parent then return end
		local t = os.clock() - t0
		local pos
		if t < 0.7 then
			local u = t / 0.7
			pos = from:Lerp(rest, u) + Vector3.new(0, math.sin(u * math.pi) * 7, 0)
			spinA += dt * 14
		elseif t < 1.15 then
			local u = (t - 0.7) / 0.45
			pos = rest + Vector3.new(0, math.abs(math.sin(u * math.pi * 2)) * (1 - u) * 1.6, 0)
			spinA += dt * 6
			if not k.Landed then
				k.Landed = true
				DinosaurVFX.FootstepDust(info.Pos, 0.5)
				if k.Prompt and not busy then k.Prompt.Enabled = true end
			end
		else
			pos = rest + Vector3.new(0, math.sin(t * 2.2) * 0.25, 0)
			spinA += dt * 1.6
		end
		m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, spinA, 0) * CFrame.Angles(0, 0, math.rad(12)))
	end)
	local boss = Config.Bosses[info.Boss] :: any
	Kit.Toast("A BOSS KEY DROPPED! GRAB IT", "Purple", "Key")
	local _ = boss
end

local function pick(id: number)
	local k = live[id]
	if not k or busy then return end
	busy = true
	if k.Prompt then k.Prompt.Enabled = false end
	-- the key stops floating and goes to your hand; the server confirms in the meantime
	if k.Conn then k.Conn:Disconnect() k.Conn = nil end
	for _, x in ipairs(k.Extras) do x:Destroy() end
	k.Extras = {}
	local tag = k.Model.PrimaryPart and k.Model.PrimaryPart:FindFirstChild("KeyTag")
	if tag then tag:Destroy() end
	local boss = Config.Bosses[k.Boss] :: any
	local model = k.Model
	live[id] = nil
	local info = { Id = id, Pos = k.Pos, Boss = k.Boss }
	task.spawn(function()
		local res = Net.Ask("PickKey", { Id = id })
		if not (res and res.Ok) then
			-- the server still has it on the ground: put it back where it was
			Kit.Toast((res and res.Err) == "TOO FAR" and "GET CLOSER TO THE KEY" or ((res and res.Err) or "COULDN'T GRAB IT"), "Red", "Key")
			task.delay(1.2, function() if not live[id] then spawnKey(info) end end)
		end
	end)
	Pickups.Grab(model, {
		Title = "BOSS KEY!",
		Sub = "WAKE THE " .. (boss and boss.Name or "BOSS") .. " FROM THE ERA MAP",
		Color = GEM[k.Boss] or C.YellowHi,
		OnDone = function() busy = false end,
	})
	task.delay(2.5, function() busy = false end)
end

function Pickups.Start()
	Net.On("KeySpawn", function(info) task.spawn(spawnKey, info) end)
	-- you drove off with the key still down: it came with you
	Net.On("KeyAuto", function(info)
		if live[info.Id] then removeKey(info.Id) end
		Kit.Toast("BOSS KEY PACKED IN THE ROVER!", "Purple", "Key")
	end)
	Net.On("KeyLost", function(info)
		if live[info.Id] then
			removeKey(info.Id)
			Kit.Toast("YOU LEFT A BOSS KEY BEHIND!", "Red", "Key")
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local id = prompt:GetAttribute("PickupKey")
		if typeof(id) == "number" then pick(id) end
	end)
	local _ = TweenService
end

return Pickups
