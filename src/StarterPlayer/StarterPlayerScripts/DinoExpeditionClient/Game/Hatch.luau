--[[
	Hatch — the reveal cinematic. It escalates with rarity (all shots are relative to the incubator):

	  every tier   over-the-shoulder of you at the incubator → the egg rocks harder and harder, cracks spread,
	               BURST (shell cubes, rings, flash, FOV punch), the baby pops out, slow orbit, title card
	               (rarity, name, KG, money / second, NEW! on a first) → tap to continue
	  COMMON       quick: two cracks, a puff
	  UNCOMMON     green glints, a third crack
	  RARE         the tease: cracks glow white, then flip to blue; light beams; a high cut
	  EPIC         the lights dim, the egg lifts and spins in a purple vortex of cubes, slow-motion burst
	  LEGENDARY    the world darkens, a golden pillar drops from the sky, "LEGENDARY!" slams in, gold rain
	  SECRET       blackout; heartbeat pulses and glitches; the egg collapses into a black orb … then a
	               rainbow explosion

	Every hatch also picks a STYLE (HatchStyles: the classic wobble, a peek through a hole in the shell, a spin-and-pop
	lift-off, a sleepy one that wakes up under a shell hat, an eruption of light for Epic+) - never the same one twice
	in a row, so hatching doesn't play the same way every time (2026-10-14).

	Hatch.Preview(species, rarity, style?) plays it anywhere (the cutscene gallery; style forces one by name).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local DinosaurAnimations = require(DinoShared:WaitForChild("DinosaurAnimations"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Kit = require(script.Parent.UI.Kit)
local CineKit = require(script.Parent.UI.CineKit)
local Audio = require(script.Parent.Audio)
local Cinema = require(script.Parent.UI.Cinema)
local CampView = require(script.Parent.CampView)
local RarityFx = require(script.Parent.RarityFx)
local PlayerAnim = require(script.Parent.PlayerAnim)
local PaddockLife = require(script.Parent.PaddockLife)
local HatchStyles = require(script.Parent.HatchStyles)
local Net = require(script.Parent.Net)

local player = Players.LocalPlayer
local Hatch = {}
Hatch.Playing = false

local EggT = DinoShared:WaitForChild("Eggs")
local BabyT = DinoShared:WaitForChild("Babies")

-- per-rarity direction
local TIERS = {
	Common = { Build = 1.5, Cracks = { 0.55, 1.05 }, Tease = nil, Beams = false, Lift = 0, Dark = 0, Slow = false },
	Uncommon = { Build = 1.9, Cracks = { 0.55, 1.0, 1.45 }, Tease = nil, Beams = false, Lift = 0, Dark = 0, Slow = false },
	Rare = { Build = 2.5, Cracks = { 0.5, 0.95, 1.4, 1.85, 2.15 }, Tease = 1.6, Beams = true, Lift = 0, Dark = 0.15, Slow = false },
	Epic = { Build = 3.3, Cracks = { 0.5, 0.9, 1.3, 1.7, 2.1, 2.5, 2.8 }, Tease = 2.0, Beams = true, Lift = 1.6, Dark = 0.35, Slow = true },
	Legendary = { Build = 4.3, Cracks = { 0.6, 1.0, 1.4, 1.8, 2.2, 2.6, 3.0, 3.4, 3.7 }, Tease = 2.6, Beams = true, Lift = 2.4, Dark = 0.55, Slow = true, Pillar = true, Slam = true },
	Secret = { Build = 5.6, Cracks = { 1.6, 2.0, 2.4, 2.8, 3.2, 3.5, 3.8, 4.1, 4.4 }, Tease = 3.6, Beams = true, Lift = 1.8, Dark = 0.95, Slow = true, Blackout = true, Implode = 4.7 },
}

local function prep(m: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
		end
	end
	return m
end

-- a rigged dino: only the root is anchored, the rest hangs off its Motor6Ds (so moving the root moves the
-- whole body and the animator can pose it)
local function prepRig(m: Model)
	local root = m.PrimaryPart
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = d == root
			d.Massless = d ~= root
		end
	end
	return m
end

local function neon(size: Vector3, color: Color3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function overlay(info, dino)
	local gui, canvas = Kit.Screen("DinoHatchUI", 55, true)
	local root = gui:FindFirstChild("Root") :: Frame
	local bars = {}
	for i, anchor in ipairs({ 0, 1 }) do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchor)
		f.Position = UDim2.fromScale(0, anchor)
		f.Size = UDim2.fromScale(1, 0)
		f.ZIndex = 20
		f.Parent = root
		bars[i] = f
		TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0.11) }):Play()
	end
	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 30
	flash.Parent = root
	local black = Instance.new("Frame")
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.Size = UDim2.fromScale(1, 1)
	black.ZIndex = 1
	black.Parent = root
	local sp = Config.Species[dino.Species]
	local r = Config.Rarity[dino.Rarity]
	-- the words live on their own screen inside the phone's safe area (the bars and flash are full-bleed; on a
	-- notched phone the name sat under the notch - 2026-10-13)
	local textGui, textCanvas = Kit.Screen("DinoHatchText", 56, false)
	local title = Instance.new("Frame")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0, 1)
	title.Position = UDim2.new(0, 40, 1, -96)
	title.Size = UDim2.fromOffset(680, 170)
	title.Visible = false
	title.Parent = textCanvas
	local rt = Kit.Text(title, r.Name, { Pixel = true, Size = UDim2.fromOffset(340, 26), Position = UDim2.fromOffset(0, 0), Align = Enum.TextXAlignment.Left, Color = r.Color, Shadow = 3, Stroke = 3, ZIndex = 24 })
	if dino.Rarity == "Secret" then local m = rt:FindFirstChild("Main") if m then RarityFx.Rainbow(m) end end
	Kit.Text(title, sp.Name, { Pixel = true, Size = UDim2.fromOffset(680, 56), Position = UDim2.fromOffset(0, 34), Align = Enum.TextXAlignment.Left, Color = Color3.fromRGB(255, 244, 214), Color2 = r.Color:Lerp(Color3.fromRGB(255, 176, 46), 0.4), Shadow = 6, Stroke = 4, ZIndex = 24 })
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = r.Color
	bar.Size = UDim2.fromOffset(0, 6)
	bar.Position = UDim2.fromOffset(0, 100)
	bar.ZIndex = 24
	bar.Parent = title
	Kit.Text(title, Config.FormatKG(dino.KG or 0), { Pixel = true, Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(0, 116), Align = Enum.TextXAlignment.Left, Color = Color3.fromRGB(190, 230, 255), Shadow = 3, Stroke = 2, ZIndex = 24 })
	Kit.Text(title, "+$" .. Config.FormatNumber(Config.DinoIncome(dino)) .. " / SEC", { Pixel = true, Size = UDim2.fromOffset(420, 22), Position = UDim2.fromOffset(0, 144), Align = Enum.TextXAlignment.Left, Color = Color3.fromRGB(200, 255, 140), Shadow = 3, Stroke = 2, ZIndex = 24 })
	local stamp = nil
	if info.NewEntry then
		local s, content = Kit.Panel(textCanvas, { Size = UDim2.fromOffset(300, 64), Position = UDim2.new(1, -40, 0, 96), AnchorPoint = Vector2.new(1, 0), Color = r.Color, ZIndex = 24 })
		Kit.Icon(content, "Star", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 27 })
		Kit.Text(content, "NEW IN YOUR INDEX!", { Pixel = true, Size = UDim2.new(1, -66, 0, 16), Position = UDim2.new(0, 56, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Shadow = 3, Stroke = 3, ZIndex = 27 })
		s.Visible = false
		s.Rotation = -6
		stamp = s
	end
	local slam = Kit.Text(root, r.Name .. "!", { Pixel = true, Size = UDim2.new(0.8, 0, 0.13, 0), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Color = r.Color, Color2 = Color3.new(1, 1, 1), Shadow = 8, Stroke = 6, ZIndex = 26 })
	slam.Visible = false
	if dino.Rarity == "Secret" then local m = slam:FindFirstChild("Main") if m then RarityFx.Rainbow(m) end end
	local prompt = Kit.Text(root, "TAP TO CONTINUE", { Pixel = true, Size = UDim2.new(0.34, 0, 0.032, 0), Position = UDim2.new(0.5, 0, 0.965, 0), AnchorPoint = Vector2.new(0.5, 1), Color = Color3.fromRGB(255, 226, 120), Shadow = 3, Stroke = 2, ZIndex = 25 })
	prompt.Visible = false
	local tap = Instance.new("TextButton")
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 40
	tap.Parent = root
	gui.Destroying:Connect(function() textGui:Destroy() end)
	return { Gui = gui, TextGui = textGui, Bars = bars, Flash = flash, Black = black, Title = title, Bar = bar, Stamp = stamp, Prompt = prompt, Tap = tap, Slam = slam }
end

local function doFlash(ui, strength: number, color: Color3?)
	ui.Flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	ui.Flash.BackgroundTransparency = 1 - strength
	TweenService:Create(ui.Flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

-- base: the incubator's egg point (or any CFrame for a preview); slot: the incubator (nil for previews)
-- after the reveal: the newborn bounces over to you. A small one you scoop up and cuddle; a big one bows its head
-- down to you for a pat. (Both of you in a side-on two-shot.)
-- the solid, visible floor under a point (the nest bowl, the shed floor): never a hidden egg or an effect part
local function floorUnder(p: Vector3, ignore: { Instance }): number?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local skip = {}
	for _, v in pairs(ignore) do if typeof(v) == "Instance" then table.insert(skip, v) end end
	for _ = 1, 8 do
		rp.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(p + Vector3.new(0, 1.5, 0), Vector3.new(0, -14, 0), rp)
		if not hit then return nil end
		local part = hit.Instance
		if part:IsA("BasePart") and part.CanCollide and part.Transparency < 0.6 and part.LocalTransparencyModifier < 0.5 and hit.Normal.Y > 0.5 then
			return hit.Position.Y
		end
		table.insert(skip, part)
	end
	return nil
end

local function bond(baby: Model, anim, char: Model, hrp: BasePart)
	local cam = Workspace.CurrentCamera
	local root = baby.PrimaryPart :: BasePart
	if not root then return end
	local _, size = baby:GetBoundingBox()
	local small = size.Y <= 3.6 and math.max(size.X, size.Z) <= 4.4
	local head = (anim.Motors.Head and anim.Motors.Head.Part1) or root
	local headFwd = math.max(0, -root.CFrame:PointToObjectSpace(head.Position).Z)
	local me = hrp.Position
	local toMe = Vector3.new(me.X - root.Position.X, 0, me.Z - root.Position.Z)
	local dir = toMe.Magnitude > 0.1 and toMe.Unit or -hrp.CFrame.LookVector
	local from = root.CFrame
	local stand = me - dir * (headFwd + (small and 1.4 or 2.4))
	-- (on the floor where it lands, not at the height of the nest it hatched in)
	local cfB, szB = baby:GetBoundingBox()
	local liftB = root.Position.Y - (cfB.Position.Y - szB.Y / 2)
	local fy = floorUnder(Vector3.new(stand.X, me.Y, stand.Z), { baby, char, baby.Parent :: Instance })
	local gy = fy and (fy + liftB) or from.Position.Y
	local goal = CFrame.lookAt(Vector3.new(stand.X, gy, stand.Z), Vector3.new(me.X, gy, me.Z))
	local side = hrp.CFrame.RightVector
	local mid = (me + goal.Position) / 2
	local camPos = mid + side * (6.5 + math.max(size.X, size.Z) * 0.5) + Vector3.new(0, 1.2 + size.Y * 0.25, 0)
	local function shot(push: number)
		cam.CFrame = CFrame.lookAt(camPos:Lerp(mid + Vector3.new(0, 1.2, 0), push), mid + Vector3.new(0, 0.8 + size.Y * 0.2, 0))
	end
	-- it bounces over
	anim:SetLocomotion("Run", 0.15)
	local t0 = os.clock()
	while os.clock() - t0 < 0.6 do
		local a = math.clamp((os.clock() - t0) / 0.6, 0, 1)
		root.CFrame = from:Lerp(goal, a) + Vector3.new(0, math.abs(math.sin(a * math.pi * 3)) * 0.5, 0)
		shot(0)
		RunService.RenderStepped:Wait()
	end
	root.CFrame = goal
	anim:SetLocomotion("Idle", 0.2)
	local D = 1.9
	if small then
		-- scoop it up and give it a cuddle (it lies across your arms)
		PlayerAnim.Hold(char, baby, { Rot = CFrame.Angles(0, math.pi / 2, 0) })
		PlayerAnim.Act(char, "Lift")
	else
		-- it bows its head down to you and you give it a pat
		anim.Layer = function(a, _dt)
			local bow = -math.clamp((head.Position.Y - (hrp.Position.Y + 1)) / 6, 0, 1.2) * 0.9
			local neck = a.Profile.Gait.Neck or {}
			for _, j in ipairs(neck) do a:Add(j, bow / math.max(1, #neck), 0, 0) end
			a:Add("Head", 0, math.sin(os.clock() * 7) * 0.2, 0)
		end
		PlayerAnim.Act(char, "Pet", { Target = function() return head.Position + Vector3.new(0, head.Size.Y * 0.5, 0) end, Duration = D })
	end
	t0 = os.clock()
	local nextHeart = 0.3
	while os.clock() - t0 < D do
		local t = os.clock() - t0
		anim.EyesClosed = t > 0.4 and t < D - 0.3
		if t >= nextHeart then
			nextHeart += 0.28
			PaddockLife.Heart(head.Position + Vector3.new(0, head.Size.Y * 0.6 + 0.4, 0))
		end
		shot(math.min(t / D, 1) * 0.35)
		RunService.RenderStepped:Wait()
	end
	PaddockLife.Hearts(head.Position + Vector3.new(0, 1, 0), 4)
	anim.EyesClosed = false
	anim.Layer = nil
	task.wait(0.25)
	PlayerAnim.Hold(char, nil)
end

-- after the hatch, a dino headed for the yard really walks there: off the nest, down the centre aisle UNDER the
-- hatchery roof (it never climbs onto anything: the floor is found by short rays from just above its feet, and
-- anything more than a small step up is ignored), out the back, through the paddock door (which opens for it)
-- and into the yard, where it grows to its full size and joins the others. It doesn't hold the camera: you
-- can watch it go or walk off. The yard copy is hidden until it arrives.
local function walkToYard(baby: Model, anim, dino)
	local plot = CampView.OwnPlot()
	local root = baby.PrimaryPart :: BasePart
	local walkway = plot and plot:FindFirstChild("Walkway", true) :: BasePart?
	local gate = plot and plot:FindFirstChild("PaddockGateIn", true) :: BasePart?
	local yard = plot and plot:FindFirstChild("PaddockBounds", true) :: BasePart?
	local function arrive(at: Vector3?)
		CampView.HideDino(dino.Id, false)
		local rec = nil
		for _, pd in ipairs(CampView.Paddocks()) do
			if pd.Own and pd.Dinos[dino.Id] then rec = pd.Dinos[dino.Id] end
		end
		if rec and at then
			-- the yard copy takes over right where the walker stopped (now full size)
			local _, cy = root.CFrame:ToEulerAnglesYXZ()
			rec.Root.CFrame = CFrame.new(at.X, rec.FloorY + rec.Lift, at.Z) * CFrame.Angles(0, cy, 0)
			rec.Target, rec.Wait = nil, 1.5
			if rec.Anim and rec.Anim:HasAction("Hop") then rec.Anim:Play("Hop") end
			DinosaurVFX.FootstepDust(rec.Root.Position, 1.4)
			PaddockLife.Hearts(rec.Root.Position + Vector3.new(0, 2, 0), 3)
		end
		baby:Destroy()
	end
	if not (root and walkway and gate and yard) then arrive(nil) return end
	-- the route, in the aisle's own frame (x = across, z = along): out to the aisle, straight down it, through the gate
	local wf = walkway.CFrame
	local here = wf:PointToObjectSpace(root.Position)
	local g = wf:PointToObjectSpace(gate.Position)
	local y = yard.CFrame:PointToObjectSpace(gate.Position)
	local inside = yard.CFrame:PointToWorldSpace(Vector3.new((math.random() - 0.5) * yard.Size.X * 0.5, 0, y.Z * 0.45))
	local pts = {
		wf:PointToWorldSpace(Vector3.new(0, here.Y, here.Z)),
		wf:PointToWorldSpace(Vector3.new(0, here.Y, g.Z)),
		Vector3.new(inside.X, gate.Position.Y, inside.Z),
	}
	local cf0, size = baby:GetBoundingBox()
	local lift = root.Position.Y - (cf0.Position.Y - size.Y / 2)
	local footY = root.Position.Y - lift
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local function skip()
		local list = { baby }
		if player.Character then table.insert(list, player.Character) end
		for _, n in ipairs({ "DinoCampLocal", "DinoHatchCinematic", "ActiveVehicles", "DinoBoats" }) do
			local f = Workspace:FindFirstChild(n)
			if f then table.insert(list, f) end
		end
		return list
	end
	local function floorAt(p: Vector3): number
		-- from just above its feet, never from up high (a ray from above lands on the hatchery roof)
		rp.FilterDescendantsInstances = skip()
		local hit = Workspace:Raycast(Vector3.new(p.X, footY + 1.6, p.Z), Vector3.new(0, -6, 0), rp)
		if hit and hit.Normal.Y > 0.6 and hit.Instance.CanCollide then return hit.Position.Y end
		return footY
	end
	table.insert(CampView.Openers, root)
	local speed = math.clamp(math.max(size.X, size.Z) * 0.6, 7, 12)
	if anim then anim:SetLocomotion(speed > 9 and "Run" or "Walk", 0.25) end
	local t0 = os.clock()
	for _, target in ipairs(pts) do
		while baby.Parent and root.Parent do
			local pos = root.Position
			local to = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
			if to.Magnitude < 0.5 or os.clock() - t0 > 30 then break end
			local dt = RunService.Heartbeat:Wait()
			local dir = to.Unit
			local step = math.min(to.Magnitude, speed * dt)
			local nxt = pos + dir * step
			footY += (floorAt(nxt) - footY) * math.min(1, dt * 12)
			local yaw = math.atan2(-dir.X, -dir.Z)
			local _, cy = root.CFrame:ToEulerAnglesYXZ()
			local ny = cy + math.atan2(math.sin(yaw - cy), math.cos(yaw - cy)) * math.min(1, dt * 8)
			root.CFrame = CFrame.new(nxt.X, footY + lift, nxt.Z) * CFrame.Angles(0, ny, 0)
		end
	end
	local i = table.find(CampView.Openers, root)
	if i then table.remove(CampView.Openers, i) end
	if anim then anim:SetLocomotion("Idle", 0.3) end
	if not baby.Parent then CampView.HideDino(dino.Id, false) return end
	arrive(root.Position)
end

-- what the running hatch has put up, so an error part-way can always take it all down again
local live = nil :: any
local function playInner(info, base: CFrame, slot: number?)
	if Hatch.Playing then return end
	local dino = info.Dino
	local eggT = EggT:FindFirstChild(dino.Species .. "Egg")
	local babyT = BabyT:FindFirstChild(dino.Species)
	if not (eggT and babyT) then return end
	Hatch.Playing = true
	local tier = TIERS[dino.Rarity] or TIERS.Common
	local style = HatchStyles.Pick(dino.Rarity, info.Style)
	local cine = Cinema.Begin("DinoHatchUI", "DinoHatchText")
	live = { Cine = cine, Slot = slot, DinoId = dino.Id }
	if slot then CampView.HideEgg(slot, true) end
	-- headed for the yard (not your companion): keep the yard copy hidden; this one walks there after
	local walker = info.Placed and not info.Buddy and not info.Preview
	-- the new dino isn't anywhere else yet: not in the yard, not following you as your companion. It only exists
	-- in this scene until the scene lets it go
	local companion = info.Placed and info.Buddy and not info.Preview
	if walker or companion then CampView.HideDino(dino.Id, true) end
	local rc = Config.Rarity[dino.Rarity].Color
	local spc = Config.Species[dino.Species].Color
	local folder = Instance.new("Folder")
	folder.Name = "DinoHatchCinematic"
	folder.Parent = Workspace
	live.Folder = folder
	local egg = prep(eggT:Clone() :: Model)
	local eggScale = Config.EggScale(dino.Species, dino.KG)
	egg:ScaleTo(eggScale)
	base = CampView.SeatOn(egg, base * CFrame.new(0, 0.2, 0)) -- sit in the bowl, not half under it
	egg:PivotTo(base)
	egg.Parent = folder
	-- (the same rarity glow it wore in the nest: it used to vanish at the cut)
	pcall(RarityFx.Apply, egg, dino.Rarity, 2 * eggScale)
	local cam = Workspace.CurrentCamera
	local oldType, oldFov = cam.CameraType, cam.FieldOfView
	live.Fov = oldFov
	require(script.Parent.Drive).HoldCamera(true) -- (nothing else writes the camera while it hatches)
	live.Held = true
	cam.CameraType = Enum.CameraType.Scriptable
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DinoHatchGrade"
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(0.8), { Contrast = 0.14, Saturation = 0.18, Brightness = -tier.Dark * 0.25 }):Play()
	local blur = Instance.new("BlurEffect")
	blur.Name = "DinoHatchBlur"
	blur.Size = 0
	blur.Parent = Lighting
	live.Fx = { cc, blur }
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "DinoCineDOF"
	dof.FocusDistance = 6
	dof.InFocusRadius = 4
	dof.NearIntensity = 0.2
	dof.FarIntensity = 0.5 + tier.Dark * 0.4
	dof.Parent = Lighting
	table.insert(live.Fx, dof)
	local oldExposure = Lighting.ExposureCompensation
	live.Exposure = oldExposure
	local expTween = TweenService:Create(Lighting, TweenInfo.new(1), { ExposureCompensation = oldExposure - tier.Dark * 1.6 })
	live.ExpTween = expTween
	expTween:Play()
	local ui = overlay(info, dino)
	live.Gui = ui.Gui
	if tier.Blackout then TweenService:Create(ui.Black, TweenInfo.new(1.2), { BackgroundTransparency = 0.15 }):Play() end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.new(1, 1, 1)
	glow.Range = 12
	glow.Brightness = 0
	glow.Parent = egg.PrimaryPart
	local function at(x, y, z) return (base * CFrame.new(x, y, z)).Position end
	-- the egg's own measurements in its nest frame, from its visible shell (not the invisible rarity volume round it)
	local shell = {}
	for _, d in ipairs(egg:GetDescendants()) do
		if d:IsA("BasePart") and d ~= egg.PrimaryPart and d.Transparency < 0.9 then table.insert(shell, d) end
	end
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(shell) do
		local c = base:PointToObjectSpace(p.Position)
		local pcf, ps = p.CFrame, p.Size
		local function reach(ax: Vector3): number
			return math.abs(pcf.RightVector:Dot(ax)) * ps.X / 2 + math.abs(pcf.UpVector:Dot(ax)) * ps.Y / 2 + math.abs(pcf.LookVector:Dot(ax)) * ps.Z / 2
		end
		local e = Vector3.new(reach(base.XVector), reach(base.YVector), reach(base.ZVector))
		lo = lo:Min(c - e)
		hi = hi:Max(c + e)
	end
	if #shell == 0 then lo, hi = Vector3.new(-0.9, 0, -0.9) * eggScale, Vector3.new(0.9, 2.6, 0.9) * eggScale end
	local midL = (lo + hi) / 2
	local center = at(midL.X, midL.Y, midL.Z)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local char = player.Character
	local wasAnchored = hrp and hrp.Anchored or false
	live.Hrp, live.WasAnchored, live.Char = hrp, wasAnchored, char
	if hrp and char then
		-- kneel down at the nest, facing the egg, and watch it
		local _, eggBox = egg:GetBoundingBox()
		local toMe = Vector3.new(hrp.Position.X - base.Position.X, 0, hrp.Position.Z - base.Position.Z)
		local r = math.max(eggBox.X, eggBox.Z) * 0.5
		local dist = math.clamp(toMe.Magnitude, r + 2.2, r + 3.6)
		local dirMe = toMe.Magnitude > 0.3 and toMe.Unit or Vector3.new(-base.LookVector.X, 0, -base.LookVector.Z).Unit
		local spot = base.Position + dirMe * dist
		spot = Vector3.new(spot.X, hrp.Position.Y, spot.Z)
		hrp.Anchored = true
		hrp.CFrame = CFrame.lookAt(spot, Vector3.new(base.Position.X, spot.Y, base.Position.Z))
		PlayerAnim.SetLoop(char, "Kneel")
		PlayerAnim.Look(char, function() return egg.Parent and egg:GetPivot().Position or base.Position end)
	end
	-- the floor of the nest, and the roof over it (a beam stops there; a spinning egg stays under it)
	local function floorAt(p: Vector3): number?
		return floorUnder(p, { folder, char :: Instance })
	end
	local nestFloor = floorAt(base.Position) or (base.Position.Y - 0.6)
	local ceilY: number? = nil
	do
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local skip: { Instance } = { folder }
		if char then table.insert(skip, char) end
		for _ = 1, 6 do
			rp.FilterDescendantsInstances = skip
			local hit = Workspace:Raycast(center, Vector3.new(0, 80, 0), rp)
			if not hit then break end
			local p = hit.Instance
			-- (a heat lamp over the nest isn't the roof)
			if p:IsA("BasePart") and p.Transparency < 0.9 and (p.Size.Magnitude > 8 or hit.Position.Y > center.Y + 9) then
				ceilY = hit.Position.Y
				break
			end
			table.insert(skip, p)
		end
	end
	-- the scene a style plays with (HatchStyles explains them)
	local S = {
		Dino = dino, Rarity = dino.Rarity, Tier = tier, Order = Config.Rarity[dino.Rarity].Order, Rc = rc, Spc = spc,
		Egg = egg, EggScale = eggScale, Shell = shell, EggH = math.max(0.5, hi.Y - lo.Y), EggW = math.max(hi.X - lo.X, hi.Z - lo.Z),
		BottomL = lo.Y, MidY = midL.Y, Base = base, Center = center, K = 0.6 + 0.4 * eggScale,
		Folder = folder, Ui = ui, FloorY = nestFloor, CeilY = ceilY, FloorAt = floorAt,
		Build = 0, CrackTimes = {}, CrackDone = 0, Teased = false, Skipped = false, Alive = true, AimLift = 0,
	} :: any
	live.S = S
	function S.At(x: number, y: number, z: number): Vector3 return at(x, y, z) end
	function S.EggMid(): Vector3 return (egg:GetPivot() * CFrame.new(midL)).Position end
	function S.Flash(strength: number, color: Color3?) doFlash(ui, strength, color) end
	function S.Act(name: string, opts: any?) if char then PlayerAnim.Act(char, name, opts) end end
	function S.Knock()
		if char and egg.Parent then PlayerAnim.Act(char, "Tap", { Target = egg:GetPivot().Position + Vector3.new(0, 0.3, 0), Duration = 0.4 }) end
	end
	local build = style.Build(tier)
	S.Build = build
	-- (a style whose setup throws - an egg model it can't read - hatches the classic way instead of not at all)
	if style.Setup then
		local okSetup, errSetup = pcall(style.Setup, S)
		if not okSetup then
			warn("[Hatch]", style.Name, "setup:", errSetup)
			style = HatchStyles.Styles.Wobble
			build = style.Build(tier)
			S.Build = build
			style.Setup(S)
		end
	end
	-- the cracks (and the white-to-colour tease) on this style's clock
	local crackTimes = style.Cracks and style.Cracks(S) or {}
	if not style.Cracks then
		for _, c in ipairs(tier.Cracks) do table.insert(crackTimes, c * build / tier.Build) end
	end
	S.CrackTimes = crackTimes
	local teaseAt = tier.Tease and tier.Tease * build / tier.Build
	local shoulder = style.Shoulder or 0.9
	local tapDone = 0
	local shoulderFrom = hrp and (hrp.CFrame * CFrame.new(1.6, 2.2, 4.2)).Position or at(5, 2.4, -3)
	local cracks, beams = {}, {}
	local baby, babyAnim = nil, nil
	local pillar = nil
	local t0 = os.clock()
	local continued, canContinue = false, false
	local conns = {}
	live.Conns = conns
	local orbitDist, eyeH = 5.6, 1.5
	local crackDone = 0
	local burst = false
	local beat = 0
	-- skippable like every scene: after the first second a fresh press jumps straight to the burst (the build-up
	-- used to hold you 1.5-5.6 s with no way out); once it's out, the next press carries on
	local function press()
		if canContinue then continued = true return end
		local t = os.clock() - t0
		if not burst and t > 1 and t < build then
			S.Skipped = true -- (nothing the build-up still had coming fires: no pile of cracks in one frame)
			t0 = os.clock() - build
		end
	end
	table.insert(conns, ui.Tap.Activated:Connect(press))
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end -- (typing in chat never skips it)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then press() end
	end))
	local crackColor = function(t: number) return (teaseAt and t < teaseAt) and Color3.fromRGB(255, 250, 235) or rc end
	-- a style that throws is dropped for the rest of this hatch (the egg just sits, the camera holds a plain shot)
	-- rather than taking the scene down with it
	local styleOk = true
	local function styleCall(fn: any, ...): (any, any)
		if not styleOk or not fn then return nil, nil end
		local ok, a, b = pcall(fn, ...)
		if ok then return a, b end
		styleOk = false
		warn("[Hatch]", style.Name, a)
		return nil, nil
	end
	local function step(dt: number)
		local t = os.clock() - t0
		local u = math.clamp(t / build, 0, 1)
		local building = not burst and not S.Skipped
		-- the egg: whatever this style does with it
		if building then
			styleCall(style.Egg, S, t, u, dt)
			glow.Brightness = (u ^ 1.6) * (2 + tier.Dark * 4)
			glow.Color = crackColor(t)
			styleCall(style.Tick, S, t, dt)
		end
		-- the Secret heartbeat: pulses of the black, faster and faster
		if tier.Blackout and building then
			local rate = 1 + u * 3
			beat += dt * rate
			local pulse = math.abs(math.sin(beat * math.pi))
			ui.Black.BackgroundTransparency = 0.1 + pulse * 0.25
			if pulse > 0.97 and math.random() < 0.3 then
				DinosaurVFX.Shake(0.4 + u * 0.6, 0.12)
				cc.TintColor = Color3.fromHSV(math.random(), 0.6, 1)
				task.delay(0.06, function() if cc.Parent then cc.TintColor = Color3.new(1, 1, 1) end end)
			end
		end
		-- you knock on it just before each crack
		while char and tapDone < #crackTimes and t >= crackTimes[tapDone + 1] - 0.22 do
			tapDone += 1
			if building then S.Knock() end
		end
		-- cracks: zig-zags of light on the shell's surface that ride along with it
		while crackDone < #crackTimes and t >= crackTimes[crackDone + 1] do
			crackDone += 1
			S.CrackDone = crackDone
			if building then
				Audio.Play("EggCrack", { Pitch = 0.92 + crackDone * 0.03, Exact = true })
				local col = dino.Rarity == "Secret" and Color3.fromHSV((crackDone * 0.13) % 1, 0.8, 1) or crackColor(t)
				local pv = egg:GetPivot()
				local spot = HatchStyles.CrackSpot(S)
				if spot then
					local s = eggScale
					local len = math.min((0.5 + crackDone * 0.08) * s, S.EggH * 0.55)
					local w = 0.07 * (0.6 + 0.4 * s)
					local main = spot * CFrame.Angles(0, 0, (math.random() - 0.5) * 1.2) * CFrame.new(0, 0, -0.02 * s)
					local c1 = neon(Vector3.new(w, len, 0.05 * s), col, main, folder)
					local side = math.random() < 0.5 and -1 or 1
					local c2 = neon(Vector3.new(w * 0.85, len * 0.5, 0.05 * s), col, main * CFrame.new(0, len * 0.2, 0) * CFrame.Angles(0, 0, side * 0.85) * CFrame.new(0, len * 0.22, 0), folder)
					for _, c in ipairs({ c1, c2 }) do table.insert(cracks, { Part = c, Offset = pv:ToObjectSpace(c.CFrame) }) end
					DinosaurVFX.Burst(CFrame.new(c1.Position), 6, { Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(1, 3), Color = Color3.fromRGB(240, 228, 200), Size = NumberSequence.new(0.3, 0.9) })
				end
				DinosaurVFX.Shake(0.15 + crackDone * 0.06, 0.2)
				if tier.Beams and crackDone >= 3 then
					-- light spilling out through the cracks (it turns with the egg)
					local mid = S.EggMid()
					for _ = 1, 2 do
						local dir = Vector3.yAxis
						for _ = 1, 6 do
							local ba = math.random() * math.pi * 2
							dir = Vector3.new(math.cos(ba), 0.4 + math.random() * 0.6, math.sin(ba)).Unit
							if not (S.Avoid and dir:Dot(S.Avoid) > 0.3) then break end
						end
						local b = neon(Vector3.new(0.25, 0.25, 6), col, CFrame.lookAt(mid, mid + dir) * CFrame.new(0, 0, -3), folder)
						b.Transparency = 0.35
						table.insert(beams, { Part = b, Offset = pv:ToObjectSpace(b.CFrame) })
					end
				end
			end
		end
		-- the tease: the white cracks flip to the rarity colour
		if teaseAt and t >= teaseAt and not S.Teased and not burst then
			S.Teased = true
			for _, c in ipairs(cracks) do c.Part.Color = rc end
			for _, b in ipairs(beams) do b.Part.Color = rc end
			if building then
				doFlash(ui, 0.35, rc)
				DinosaurVFX.Shake(0.5, 0.25)
			end
		end
		if not burst then
			local pv = egg:GetPivot()
			for _, c in ipairs(cracks) do c.Part.CFrame = pv * c.Offset end
			for i, b in ipairs(beams) do
				b.Part.CFrame = pv * b.Offset
				b.Part.Transparency = 0.3 + math.sin(t * 20 + i) * 0.15
			end
		end
		-- the golden pillar from the sky (Legendary, unless the style brings its own light)
		if tier.Pillar and not style.NoPillar and not pillar and building and t >= build * 0.45 then
			pillar = neon(Vector3.new(80, 3.4, 3.4), Color3.fromRGB(255, 220, 110), CFrame.new(center + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2), folder)
			pillar.Shape = Enum.PartType.Cylinder
			pillar.Transparency = 0.4
			DinosaurVFX.Shake(0.8, 0.4)
			doFlash(ui, 0.4, Color3.fromRGB(255, 220, 110))
		end
		if pillar then pillar.Size = Vector3.new(80, 3.4 + math.sin(t * 8) * 0.4, 3.4 + math.sin(t * 8) * 0.4) end
		-- the slam text right before the burst (Legendary / Secret)
		if (tier.Slam or tier.Blackout) and not ui.Slammed and building and t >= build - 0.75 then
			ui.Slammed = true
			ui.Slam.Visible = true
			Kit.Pop(ui.Slam, 2.6)
			DinosaurVFX.Shake(1, 0.3)
		end
		-- camera
		if not burst and t < shoulder then
			-- over your shoulder at the incubator
			local pos = shoulderFrom
			cam.CFrame = CFrame.lookAt(pos, center + Vector3.new(0, 0.3, 0))
			cam.FieldOfView = 50 - t * 4
			dof.FocusDistance = (pos - center).Magnitude
		elseif not burst and t < build then
			local cf, fov = styleCall(style.Cam, S, t)
			if typeof(cf) ~= "CFrame" then cf, fov = CFrame.lookAt(shoulderFrom, center + Vector3.new(0, 0.3, 0)), 46 end
			cam.CFrame = cf
			cam.FieldOfView = fov
			dof.FocusDistance = (cf.Position - S.EggMid()).Magnitude
		else
			-- the reveal: a slow sway round it, level with its eyes (looking it in the face). A style can hold the
			-- aim up (a baby dropping in from above)
			local v = t - build
			local ang = -math.pi / 2 + math.sin(v * 0.4) * 0.55
			local dist = orbitDist - math.min(v, 1.5) * 0.5
			local eye = base.Position + Vector3.new(0, eyeH, 0)
			local pos = (base * CFrame.Angles(0, ang, 0) * CFrame.new(0, 1.3, -dist)).Position
			pos = Vector3.new(pos.X, eye.Y + 0.05 + S.AimLift * 0.4, pos.Z)
			local aim = eye + Vector3.new(0, S.AimLift, 0)
			cam.CFrame = CFrame.lookAt(pos, aim)
			cam.FieldOfView = 48
			dof.FocusDistance = (pos - aim).Magnitude
		end
		-- the burst
		if not burst and t >= build then
			burst = true
			if char then
				-- it bursts right in front of you: you jump up
				PlayerAnim.SetLoop(char, nil)
				PlayerAnim.Act(char, "Startle")
				PlayerAnim.Look(char, function() return baby and baby.Parent and baby:GetPivot().Position or center end)
			end
			if tier.Slow then
				-- a beat of slow motion on the burst
				DinosaurVFX.Shake(0.4, 0.2)
			end
			local ord = Config.Rarity[dino.Rarity].Order
			-- (a sleepy one pops softly: fewer bits, no impact frame - the rarity stamp and sting still land)
			local soft = style.Soft == true
			local shellCols = { spc, Color3.fromRGB(243, 234, 210), spc:Lerp(Color3.new(0, 0, 0), 0.3) }
			local burstC = S.EggMid()
			S.BurstAt = burstC -- (the egg is destroyed below: a style's Spawn reads where it popped from this)
			if dino.Rarity == "Secret" then shellCols = { Color3.fromHSV(0, 0.8, 1), Color3.fromHSV(0.33, 0.8, 1), Color3.fromHSV(0.66, 0.8, 1), Color3.new(0, 0, 0) } end
			-- (before the egg goes: a style may take a piece of it)
			if style.OnBurst then
				local ok, err = pcall(style.OnBurst, S, burstC)
				if not ok then warn("[Hatch]", style.Name, "burst:", err) end
			end
			local n = soft and 10 or (18 + ord * 6)
			DinosaurVFX.Cubes(burstC, n, shellCols, 0.42 * math.sqrt(eggScale), soft and 9 or 20, 1.6)
			DinosaurVFX.BlockRing(CFrame.new(burstC) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 20, R0 = 0.6, R1 = soft and 5 or (9 + tier.Dark * 10), Color = rc, Duration = 0.55, Block = 0.6 })
			DinosaurVFX.BlockRing(CFrame.lookAt(burstC, cam.CFrame.Position), { Count = 16, R0 = 0.4, R1 = soft and 4 or 6, Color = Color3.new(1, 1, 1), Duration = 0.45, Block = 0.4 })
			DinosaurVFX.Burst(CFrame.new(burstC), 26 + ord * 8, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Lifetime = NumberRange.new(0.6, 1.4), Speed = NumberRange.new(4, 10), Spread = Vector2.new(180, 180), Color = rc, LightEmission = 1, Size = NumberSequence.new(0.6, 0) })
			DinosaurVFX.Shake(soft and 0.4 or (1 + tier.Dark), soft and 0.3 or 0.5)
			doFlash(ui, soft and 0.5 or 0.9, rc:Lerp(Color3.new(1, 1, 1), 0.5))
			ui.Slam.Visible = false
			-- the rarity over sun rays in its own colour (the info card with KG and income follows below)
			CineKit.Stamp(ui.Gui, string.upper(Config.Rarity[dino.Rarity].Name) .. "!", Config.Species[dino.Species].Name, rc, 2.2, 0.22)
			CineKit.Punch(soft and 3 or (6 + ord))
			if not soft then CineKit.ImpactFrame(0.5 + ord * 0.12) end
			CineKit.SunBurst(0.6 + ord * 0.15)
			Audio.Sting(ord >= 5 and "HatchLegendary" or (ord >= 3 and "HatchRare" or "Hatch"))
			TweenService:Create(ui.Black, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(Lighting, TweenInfo.new(0.8), { ExposureCompensation = oldExposure }):Play()
			TweenService:Create(cc, TweenInfo.new(0.6), { Brightness = 0 }):Play()
			blur.Size = soft and 10 or 20
			TweenService:Create(blur, TweenInfo.new(0.6), { Size = 0 }):Play()
			cam.FieldOfView = 62
			egg:Destroy()
			if pillar then TweenService:Create(pillar, TweenInfo.new(0.8), { Transparency = 1 }):Play() end
			for _, c in ipairs(cracks) do c.Part:Destroy() end
			for _, b in ipairs(beams) do b.Part:Destroy() end
			-- the dino (the full model at its KG size, dressed in its rarity)
			baby = prepRig(DinoShared.Dinosaurs:FindFirstChild(dino.Species):Clone() :: Model)
			local scale = Config.DinoScale(dino)
			-- fits under the hatchery roof here; it's full size in your paddock
			local _, full = baby:GetBoundingBox()
			scale = math.min(scale, 9.5 / full.Y, 16 / math.max(full.X, full.Z))
			baby:ScaleTo(scale)
			baby:SetAttribute("AnimScale", scale)
			local root = baby.PrimaryPart :: BasePart
			local cf0, size = baby:GetBoundingBox()
			orbitDist = math.max(5.6, math.max(size.X, size.Z) * 1.05)
			eyeH = math.max(0.7, size.Y * 0.55)
			local lift = root.Position.Y - (cf0.Position.Y - size.Y / 2)
			-- where its head is, measured on the rig as built (before it's moved: out of the workspace only the root
			-- would move, and the head would still be wherever the template was - 2026-10-14)
			local hd = DinosaurVFX.findAttachment(baby, "VFX_Head")
			local headL = hd and root.CFrame:PointToObjectSpace(hd.WorldPosition)
			local face = CFrame.lookAt(base.Position, base.Position + base.RightVector)
			-- feet in the nest bowl (base is the egg's middle: standing there it hovered a stud or two up)
			local fy = floorUnder(base.Position, { folder, char :: Instance, baby })
			local feetY = fy or (base.Position.Y - 0.6)
			root.CFrame = CFrame.new(Vector3.new(base.Position.X, feetY + lift, base.Position.Z)) * face.Rotation
			local rest = root.CFrame
			-- the lens at its FACE (2026-10-13: "the camera is a little high for every dino" - half its box height is
			-- the frill / back on a four-legged one): its head attachment's height, when it has one
			if headL then eyeH = math.clamp(rest:PointToWorldSpace(headL).Y - base.Position.Y, 0.4, math.max(0.7, size.Y * 0.8)) end
			baby.Parent = folder
			RarityFx.Apply(baby, dino.Rarity, math.max(size.X, size.Z))
			babyAnim = DinosaurAnimations.get(baby)
			-- its first seconds are the style's (a roar, a sniff, a twirl down from the air, a yawn under a hat...)
			local R = {
				Root = root, Rest = rest, Size = size, Lift = lift, Scale = scale,
				Head = babyAnim and babyAnim.Motors.Head and babyAnim.Motors.Head.Part1 or nil,
				Chirp = math.clamp(1.4 - scale * 0.35, 0.8, 1.35),
			}
			S.AimLift = 0
			if style.Spawn and styleOk then
				local cfS = styleCall(style.Spawn, S, rest, R)
				if typeof(cfS) == "CFrame" then root.CFrame = cfS end
			end
			local reveal = style.Reveal
			if reveal then
				local b, a = baby, babyAnim
				task.spawn(function()
					local ok, err = pcall(reveal, S, b, a, R)
					if not ok then
						warn("[Hatch]", style.Name, "reveal:", err)
						S.AimLift = 0
						if S.Alive then
							if a then a.Layer = nil a.EyesClosed = false end
							if root.Parent then root.CFrame = rest end
						end
					end
				end)
			end
			-- confetti (gold rain for Legendary, rainbow for Secret)
			task.spawn(function()
				local cols = { rc, Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 255, 255), Color3.fromRGB(95, 211, 90) }
				if dino.Rarity == "Legendary" then cols = { Color3.fromRGB(255, 205, 70), Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 170, 40) } end
				if dino.Rarity == "Secret" then cols = { Color3.fromHSV(0, 0.8, 1), Color3.fromHSV(0.16, 0.8, 1), Color3.fromHSV(0.33, 0.8, 1), Color3.fromHSV(0.55, 0.8, 1), Color3.fromHSV(0.8, 0.8, 1) } end
				for _ = 1, 2 + ord do
					DinosaurVFX.Cubes(center + Vector3.new(0, 6, 0), 14, cols, 0.22, 8, 2.2)
					task.wait(0.3)
				end
			end)
			task.delay(0.55, function()
				ui.Title.Visible = true
				ui.Title.Position = UDim2.new(0, 10, 1, -96)
				TweenService:Create(ui.Title, TweenInfo.new(0.55, Enum.EasingStyle.Quint), { Position = UDim2.new(0, 40, 1, -96) }):Play()
				TweenService:Create(ui.Bar, TweenInfo.new(0.8, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(330, 6) }):Play()
				Kit.Pop(ui.Title, 0.85)
				if ui.Stamp then
					task.wait(0.45)
					Kit.Pop(ui.Stamp, 2.2)
					DinosaurVFX.Shake(0.5, 0.25)
				end
			end)
			-- you can tap on 1.6 s after the pop as always; a style with a gag after the pop (the sleepy yawn) only
			-- holds back the prompt for it, never the tap (its build-up was shortened to match)
			task.delay(1.6, function() canContinue = true end)
			task.delay(math.max(1.6, style.Hold or 1.6), function() ui.Prompt.Visible = true end)
		end
	end
	-- (an error in a frame never strands you in the scene: before the pop it jumps to the pop, after it you can
	-- tap on - a throw in here used to leave the camera frozen until the 18 s timeout)
	local reported = false
	local render = RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if ok then return end
		if not reported then
			reported = true
			warn("[Hatch]", err)
		end
		if burst then
			canContinue = true
			ui.Prompt.Visible = true
		else
			S.Skipped = true
			t0 = os.clock() - build
		end
	end)
	table.insert(conns, render) -- (so a failure later still stops it)
	local tWait = os.clock()
	while not continued and os.clock() - tWait < 18 do task.wait() end
	S.Alive = false -- (the style's reveal lets go of the baby: the bond below takes it)
	S.AimLift = 0
	render:Disconnect()
	for _, c in ipairs(conns) do c:Disconnect() end
	if babyAnim and baby then babyAnim:Play(babyAnim:HasAction("Hop") and "Hop" or "LookAround") end
	for _, f in ipairs(ui.Bars) do TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0) }):Play() end
	Kit.PopOut(ui.Title)
	if ui.Stamp then Kit.PopOut(ui.Stamp) end
	ui.Prompt.Visible = false
	TweenService:Create(cc, TweenInfo.new(0.4), { Contrast = 0, Saturation = 0 }):Play()
	if baby and babyAnim and char and hrp then pcall(bond, baby, babyAnim, char, hrp) end
	task.wait(0.35)
	if baby then DinosaurVFX.FootstepDust(baby:GetPivot().Position, 1) end
	local walking = false
	if walker and baby and baby.Parent and hrp then
		-- set it down on the floor in front of you (it may have been in your arms) and send it off
		local root = baby.PrimaryPart :: BasePart
		if char then PlayerAnim.Hold(char, nil) end
		local cf0, size = baby:GetBoundingBox()
		local lift = root.Position.Y - (cf0.Position.Y - size.Y / 2)
		local spot = hrp.Position + hrp.CFrame.LookVector * (2.2 + math.max(size.X, size.Z) * 0.5)
		local floorY = base.Position.Y - 0.6 -- the nest bowl sits on the shed floor
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { baby, folder, char :: Instance }
		local hit = Workspace:Raycast(Vector3.new(spot.X, hrp.Position.Y, spot.Z), Vector3.new(0, -8, 0), rp)
		if hit and hit.Normal.Y > 0.6 then floorY = hit.Position.Y end
		root.Anchored = true
		root.CFrame = CFrame.new(spot.X, floorY + lift, spot.Z) * root.CFrame.Rotation
		local live = Workspace:FindFirstChild("DinoCampLocal") or Workspace
		baby.Parent = live
		walking = true
		task.spawn(walkToYard, baby, babyAnim, dino)
	elseif walker then
		CampView.HideDino(dino.Id, false)
	end
	if companion then
		-- your new companion: it appears right where the hatchling stood (after the petting), then follows you
		local spot = baby and baby.Parent and baby:GetPivot().Position or (hrp and hrp.Position) or base.Position
		local yaw = 0
		if baby and baby.PrimaryPart then local _, y = baby.PrimaryPart.CFrame:ToEulerAnglesYXZ() yaw = y end
		local floorY = base.Position.Y - 0.6
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { folder, char :: Instance }
		local hit = Workspace:Raycast(Vector3.new(spot.X, (hrp and hrp.Position.Y or spot.Y) + 1, spot.Z), Vector3.new(0, -10, 0), rp)
		if hit and hit.Normal.Y > 0.6 then floorY = hit.Position.Y end
		CampView.HideDino(dino.Id, false)
		for _, pd in ipairs(CampView.Paddocks()) do
			local rec = pd.Own and pd.Dinos[dino.Id]
			if rec then
				rec.Root.CFrame = CFrame.new(spot.X, floorY + rec.Lift, spot.Z) * CFrame.Angles(0, yaw, 0)
				rec.Target, rec.Wait = nil, 0.5
				DinosaurVFX.FootstepDust(rec.Root.Position, 1)
			end
		end
	end
	folder:Destroy()
	ui.Gui:Destroy()
	cc:Destroy()
	blur:Destroy()
	dof:Destroy()
	Lighting.ExposureCompensation = oldExposure
	cam.CameraType = oldType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or oldType
	cam.FieldOfView = oldFov
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	if slot then CampView.HideEgg(slot, false) end
	if char then
		PlayerAnim.SetLoop(char, nil)
		PlayerAnim.Look(char, nil)
		PlayerAnim.Hold(char, nil)
	end
	if hrp then hrp.Anchored = wasAnchored end
	require(script.Parent.Drive).HoldCamera(false)
	Cinema.End(cine)
	live = nil
	Hatch.Playing = false
	if not info.Preview then
		if info.Buddy then
			-- (Hatch.Play explains companions)
		elseif info.SeaPen then
			Kit.Toast("IT SWAM OUT TO YOUR SEA PEN", "Blue", "Paddock")
		elseif info.Dino and info.Dino.Species == "Mosasaurus" then
			Kit.Toast("YOUR SEA PEN HAS ONE - THIS ONE'S IN YOUR BAG", "Orange", "Paddock")
		elseif walking then
			Kit.Toast("IT'S WALKING TO YOUR YARD!", "Green", "Paddock")
		elseif info.Placed then
			Kit.Toast("SENT TO YOUR YARD", "Green", "Paddock")
		elseif info.Pinned then
			Kit.Toast("YARD FULL - IT'S ON YOUR HOTBAR. BUILD MORE ROOM AT THE BENCH IN YOUR PEN", "Orange", "Paddock")
		else
			Kit.Toast("YARD FULL - IT'S IN YOUR BAG. BUILD MORE ROOM AT THE BENCH IN YOUR PEN", "Orange", "Paddock")
		end
	end
end

-- nothing between the lens and the hatch: a hatchery post or roof beam in the way fades out for the scene (the far
-- right incubator filmed straight through a pillar - 2026-10-14). Looks at the egg / baby and at you.
local function lensGuard(base: CFrame): () -> ()
	local faded = {} :: { [BasePart]: number }
	local name = "DinoHatchLens"
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local function clear(from: Vector3, to: Vector3, skip: { Instance })
		local ignore = table.clone(skip)
		for _ = 1, 6 do
			rp.FilterDescendantsInstances = ignore
			local hit = Workspace:Raycast(from, to - from, rp)
			if not hit then return end
			local part = hit.Instance
			table.insert(ignore, part)
			if part:IsA("BasePart") and part.Transparency < 0.95 and faded[part] == nil then
				faded[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 0.8
			end
		end
	end
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
		local cam = Workspace.CurrentCamera
		if cam.CameraType ~= Enum.CameraType.Scriptable then return end
		local from = cam.CFrame.Position
		local folder = Workspace:FindFirstChild("DinoHatchCinematic")
		local char = player.Character
		local skip = { folder or Workspace.Terrain, char or Workspace.Terrain }
		clear(from, base.Position + Vector3.new(0, 2, 0), skip)
		local head = char and char:FindFirstChild("Head") :: BasePart?
		if head then clear(from, head.Position, skip) end
		if folder then
			for _, m in ipairs(folder:GetChildren()) do
				if m:IsA("Model") then clear(from, m:GetPivot().Position + Vector3.new(0, 1, 0), skip) end
			end
		end
	end)
	return function()
		pcall(function() RunService:UnbindFromRenderStep(name) end)
		for part, was in pairs(faded) do
			if part.Parent then part.LocalTransparencyModifier = was end
		end
		table.clear(faded)
	end
end

-- never stuck: a hatch that fails part-way still hands you back (camera, controls, light, HUD) and frees the next one
local function play(info, base: CFrame, slot: number?)
	local unguard = lensGuard(base)
	local ok, err = pcall(playInner, info, base, slot)
	unguard()
	if ok or not live then return end
	warn("[Hatch]", err)
	local l = live
	live = nil
	if l.S then l.S.Alive = false end
	for _, c in ipairs(l.Conns or {}) do pcall(function() c:Disconnect() end) end
	if l.Folder then l.Folder:Destroy() end
	if l.Gui then l.Gui:Destroy() end
	for _, fx in ipairs(l.Fx or {}) do fx:Destroy() end
	if l.ExpTween then l.ExpTween:Cancel() end -- (or it keeps darkening the screen after the light is put back)
	if l.Exposure then Lighting.ExposureCompensation = l.Exposure end
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = l.Fov or 70
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	if l.Char then
		pcall(PlayerAnim.SetLoop, l.Char, nil)
		pcall(PlayerAnim.Look, l.Char, nil)
		pcall(PlayerAnim.Hold, l.Char, nil)
	end
	if l.Hrp then l.Hrp.Anchored = l.WasAnchored == true end
	if l.Slot then CampView.HideEgg(l.Slot, false) end
	if l.DinoId then CampView.HideDino(l.DinoId, false) end
	if l.Held then require(script.Parent.Drive).HoldCamera(false) end
	if l.Cine then Cinema.End(l.Cine) end
	Hatch.Playing = false
end

-- your first companion: what it is, once, in plain words
local function companionIntro(dino, role)
	local Theme = require(script.Parent.UI.Theme)
	local C = Theme.C
	local gui, canvas = Kit.Screen("DinoCompanionIntro", 40, false)
	local card, cc = Kit.Card(canvas, { Size = UDim2.fromOffset(600, 236), Position = UDim2.new(0.5, 0, 1, -36), AnchorPoint = Vector2.new(0.5, 1), Color = "Forest", Border = C.TealHi, ZIndex = 40 })
	Kit.Icon(cc, "Dino", { Species = dino.Species, Size = UDim2.fromOffset(132, 132), Position = UDim2.fromOffset(12, 18), ZIndex = 43, Rotation = -6 })
	local sp = Config.Species[dino.Species]
	Kit.Text(cc, "THIS IS YOUR COMPANION!", { Size = UDim2.new(1, -170, 0, 34), Position = UDim2.fromOffset(156, 14), Align = Enum.TextXAlignment.Left, Color = C.TealHi, Stroke = 4, Shadow = 3, MaxSize = 30, ZIndex = 43 })
	local lines = {
		{ string.upper(sp and sp.Name or dino.Species) .. " FOLLOWS YOU EVERYWHERE", C.Cream },
		{ "IT FIGHTS BESIDE YOU AND RIDES IN YOUR ROVER", C.Cream },
		{ string.upper(role.Name) .. ": " .. string.upper(role.Desc), C.YellowHi },
	}
	for i, l in ipairs(lines) do
		Kit.Text(cc, l[1], { Pixel = true, Size = UDim2.new(1, -176, 0, 12), Position = UDim2.fromOffset(158, 56 + (i - 1) * 22), Align = Enum.TextXAlignment.Left, Color = l[2], Stroke = 2, Shadow = 1, MaxSize = 12, ZIndex = 43 })
	end
	local done = false
	local function close()
		if done then return end
		done = true
		game:GetService("ContextActionService"):UnbindAction("DinoCompanionOk")
		if card.Parent then Kit.Exit(card, true) end
		task.delay(0.5, function() gui:Destroy() end)
	end
	Kit.Button(cc, { Text = "GOT IT!", Color = "Teal", Size = UDim2.fromOffset(200, 50), Position = UDim2.new(1, -14, 1, -12), AnchorPoint = Vector2.new(1, 1), ZIndex = 44, OnClick = close })
	game:GetService("ContextActionService"):BindAction("DinoCompanionOk", function(_, st)
		if st == Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
	Kit.Pop(card, 0.6)
	task.delay(20, close)
end

function Hatch.Play(info)
	local point = CampView.NestPoint(info.Slot)
	if not point or not info.Dino then return end
	play(info, point.CFrame * CFrame.new(0, -0.2, 0), info.Slot)
	if info.IndexCoins and info.IndexCoins > 0 then
		Kit.Toast("NEW INDEX ENTRY! +" .. Config.FormatNumber(info.IndexCoins) .. " COINS", "Blue", "Index")
	end
	if info.RewardReady then
		task.delay(0.6, function() Kit.Toast("INDEX REWARD READY - CLAIM IT IN THE INDEX!", "Gold", "Trophy") end)
	end
	if info.Buddy then
		-- a free companion slot: it stays with you. Say what that means, right when it matters - the first time a
		-- proper card (user 2026-10-13: "when you finish hatching your first egg explain companions"), then a toast
		local role = Config.BuddyRoleOf(info.Dino.Species)
		local tips = Net.Profile and Net.Profile.Flags and Net.Profile.Flags.Tips
		if tips and not tips.CompanionIntro then
			tips.CompanionIntro = true
			task.spawn(function() Net.Ask("Tip", { Key = "CompanionIntro" }) end)
			companionIntro(info.Dino, role)
		else
			Kit.Toast("IT'S YOUR COMPANION! IT FOLLOWS YOU AND FIGHTS BESIDE YOU - " .. role.Name .. ": " .. role.Desc, "Teal", "Buddy")
		end
	end
end

-- the cutscene gallery: hatch a dino of any species / rarity right in front of you
function Hatch.Preview(species: string, rarity: string, style: string?)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	-- (on foot only: seated, the egg landed in the rover's hood and anchoring you anchored the whole rover)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then Kit.Toast("GET OUT OF YOUR ROVER FIRST", "Orange", "Egg") return end
	local sp = Config.Species[species]
	local mid = sp and (sp.KG[1] + sp.KG[2]) / 2 or 50
	-- an open spot on the floor a few steps away (never inside a wall you happened to be facing)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { player.Character :: Instance }
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local spot, dir = nil, look
	for _, deg in ipairs({ 0, 90, -90, 180, 45, -45 }) do
		local d = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(deg)):VectorToWorldSpace(look)
		if not Workspace:Raycast(hrp.Position, d * 9, rp) then
			local p = hrp.Position + d * 7
			local fy = floorUnder(p, { player.Character :: Instance })
			if fy then spot, dir = Vector3.new(p.X, fy, p.Z), d break end
		end
	end
	if not spot then Kit.Toast("NO ROOM HERE - TRY SOMEWHERE MORE OPEN", "Orange", "Egg") return end
	-- (base is the egg's seat: SeatOn lifts it into place from the floor point)
	local base = CFrame.lookAt(spot, spot + dir) * CFrame.Angles(0, math.pi / 2, 0)
	task.spawn(play, { Dino = { Species = species, Rarity = rarity, KG = mid }, NewEntry = true, Preview = true, Style = style }, base, nil)
end

return Hatch
