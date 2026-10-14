--[[
	Warp — the trip through time. Your real vehicle (and you in it) rides a tunnel of studded hex
	frames that spin and shift from present-day amber through teal and jungle green to the era's colour,
	with light streaks, drifting dinosaur silhouettes and fossils, glitch scanlines and RGB split, and a
	year counter spinning down to the era's date before it slams onto the screen.

	Full the first time (≈7 s), short after that (≈3 s, and any tap skips), reverse on the way home.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)
local Drive = require(script.Parent.Drive)
local Net = require(script.Parent.Net)
local Zone = require(script.Parent.Zone)

local player = Players.LocalPlayer
local Warp = {}
Warp.Playing = false

local ORIGIN = Vector3.new(6000, 2600, 6000)
local FRAMES, SPACING, RADIUS = 46, 13, 17
local LENGTH = FRAMES * SPACING

local PALETTE = {
	Color3.fromRGB(255, 176, 46), Color3.fromRGB(255, 120, 40), Color3.fromRGB(63, 224, 200),
	Color3.fromRGB(47, 160, 255), Color3.fromRGB(255, 79, 139), Color3.fromRGB(95, 211, 90), Color3.fromRGB(180, 255, 120),
}

local function colorAt(u: number, reverse: boolean?): Color3
	if reverse then u = 1 - u end
	local n = #PALETTE
	local f = math.clamp(u, 0, 0.9999) * (n - 1)
	local i = math.floor(f)
	return PALETTE[i + 1]:Lerp(PALETTE[i + 2], f - i)
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do (p :: any)[k] = v end
	return p
end

--------------------------------------------------------------------------------
-- tunnel construction
--------------------------------------------------------------------------------
local function buildTunnel(reverse: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "DinoWarpTunnel"
	local frames = {}
	for i = 1, FRAMES do
		local u = (i - 1) / (FRAMES - 1)
		local col = colorAt(u, reverse)
		local model = Instance.new("Model")
		model.Name = "Frame" .. i
		local center = CFrame.new(ORIGIN + Vector3.new(0, 0, -(i - 1) * SPACING))
		local r = RADIUS * (1 + 0.12 * math.sin(i * 0.7))
		local pieces = {}
		for k = 0, 5 do
			local a0, a1 = math.rad(k * 60), math.rad((k + 1) * 60)
			local p0 = Vector3.new(math.cos(a0) * r, math.sin(a0) * r, 0)
			local p1 = Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
			local mid, len = (p0 + p1) / 2, (p1 - p0).Magnitude
			local beam = part({ Size = Vector3.new(len + 1.2, 1.3, 1.3), Material = Enum.Material.Neon, Color = col, Transparency = 0.05 })
			beam.CFrame = center * CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(p1.Y - p0.Y, p1.X - p0.X))
			beam.Parent = model
			table.insert(pieces, { Part = beam, Offset = center:ToObjectSpace(beam.CFrame) })
			local node = part({ Size = Vector3.new(2.4, 2.4, 2.4), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(28, 30, 36) })
			node.TopSurface = Enum.SurfaceType.Studs
			node.CFrame = center * CFrame.new(p0) * CFrame.Angles(0, 0, a0 + math.pi / 4)
			node.Parent = model
			table.insert(pieces, { Part = node, Offset = center:ToObjectSpace(node.CFrame) })
		end
		model.Parent = folder
		frames[i] = { Model = model, Center = center, Pieces = pieces, Spin = (i % 2 == 0 and 1 or -1) * (0.4 + (i % 5) * 0.15), Angle = i * 0.35, Color = col }
	end
	-- light streaks
	local streaks = {}
	for i = 1, 70 do
		local a, rr = math.random() * math.pi * 2, 6 + math.random() * 10
		local s = part({ Size = Vector3.new(0.18, 0.18, 6 + math.random() * 12), Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1), Transparency = 0.2 })
		s.Parent = folder
		streaks[i] = { Part = s, A = a, R = rr, Z = math.random() * LENGTH, Speed = 80 + math.random() * 140 }
	end
	-- drifting silhouettes of the creatures waiting on the other side, and fossils
	local ghosts = {}
	local dinos = DinoShared:FindFirstChild("Dinosaurs")
	local names = reverse and { "Velociraptor", "Triceratops", "Parasaurolophus" } or { "Velociraptor", "TyrannosaurusRex", "Triceratops", "Brachiosaurus", "Parasaurolophus", "Spinosaurus" }
	for i, name in ipairs(names) do
		local tmpl = dinos and dinos:FindFirstChild(name)
		if tmpl then
			local m = tmpl:Clone() :: Model
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CastShadow = false
					if d.Transparency < 1 then
						d.Color = Color3.fromRGB(8, 8, 14)
						d.Material = Enum.Material.SmoothPlastic
					end
				elseif d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
					d:Destroy()
				end
			end
			local _, size = m:GetBoundingBox()
			m:ScaleTo(math.clamp(14 / math.max(size.Y, size.Z * 0.6), 0.4, 2.2))
			local side = (i % 2 == 0) and 1 or -1
			local z = -(0.12 + (i - 1) / #names * 0.78) * LENGTH
			local cf = CFrame.new(ORIGIN + Vector3.new(side * (RADIUS + 9), (i % 3 - 1) * 6, z)) * CFrame.Angles(0, side * math.pi / 2 + 0.4, 0)
			m:PivotTo(cf)
			m.Parent = folder
			table.insert(ghosts, { Model = m, Base = cf, Phase = i })
		end
	end
	for i = 1, 8 do
		local fossil = Instance.new("Model")
		local side = (i % 2 == 0) and 1 or -1
		local base = CFrame.new(ORIGIN + Vector3.new(side * (RADIUS + 5 + math.random() * 5), math.random(-10, 10), -math.random() * LENGTH)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
		local spine = part({ Size = Vector3.new(7, 0.8, 0.8), Color = Color3.fromRGB(239, 226, 196), Material = Enum.Material.SmoothPlastic })
		spine.CFrame = base
		spine.Parent = fossil
		for k = -2, 2 do
			local rib = part({ Size = Vector3.new(0.5, 3.4 - math.abs(k) * 0.4, 0.5), Color = Color3.fromRGB(227, 212, 176), Material = Enum.Material.SmoothPlastic })
			rib.CFrame = base * CFrame.new(k * 1.3, -1.6, 0) * CFrame.Angles(0, 0, 0.25)
			rib.Parent = fossil
		end
		fossil.Parent = folder
		table.insert(ghosts, { Model = fossil, Base = base, Phase = i + 10, Fossil = true })
	end
	-- THE GALAXY (2026-10-13): a dark shell round the whole tunnel so the warp happens in deep space, not over the
	-- blurred map far below - unlit walls, a field of stars (some twinkle), and big soft nebula sheets drifting
	local GW, z0, z1 = 150, 70, -(LENGTH + 140)
	local zl, zm = z0 - z1, (z0 + z1) / 2
	local space = Color3.fromRGB(5, 5, 14)
	for _, w in ipairs({
		{ Vector3.new(4, GW * 2, zl), Vector3.new(GW, 0, zm) }, { Vector3.new(4, GW * 2, zl), Vector3.new(-GW, 0, zm) },
		{ Vector3.new(GW * 2, 4, zl), Vector3.new(0, GW, zm) }, { Vector3.new(GW * 2, 4, zl), Vector3.new(0, -GW, zm) },
		{ Vector3.new(GW * 2, GW * 2, 4), Vector3.new(0, 0, z0) }, { Vector3.new(GW * 2, GW * 2, 4), Vector3.new(0, 0, z1) },
	}) do
		local wall = part({ Size = w[1], Material = Enum.Material.Neon, Color = space })
		wall.CFrame = CFrame.new(ORIGIN + w[2])
		wall.Parent = folder
	end
	local stars = {}
	local starCols = { Color3.new(1, 1, 1), Color3.fromRGB(190, 220, 255), Color3.fromRGB(255, 236, 190), Color3.fromRGB(200, 180, 255) }
	for i = 1, 320 do
		-- on the inside of a side wall, the ceiling or the floor, anywhere along the tunnel
		local face = math.random(1, 4)
		local a, b = (math.random() * 2 - 1) * (GW - 3), z1 + math.random() * zl
		local pos = face == 1 and Vector3.new(GW - 2.2, a, b) or face == 2 and Vector3.new(-GW + 2.2, a, b)
			or face == 3 and Vector3.new(a, GW - 2.2, b) or Vector3.new(a, -GW + 2.2, b)
		local sz = (math.random() < 0.08) and (1.6 + math.random() * 1.2) or (0.45 + math.random() * 0.7)
		local st = part({ Size = Vector3.new(sz, sz, sz), Material = Enum.Material.Neon, Color = starCols[math.random(1, #starCols)] })
		st.CFrame = CFrame.new(ORIGIN + pos) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
		st.Parent = folder
		stars[i] = { Part = st, Phase = math.random() * 6.28, Twinkle = math.random() < 0.3 }
	end
	local nebula = {}
	local nebCols = { Color3.fromRGB(120, 60, 210), Color3.fromRGB(40, 170, 190), Color3.fromRGB(220, 80, 160), Color3.fromRGB(70, 90, 230), Color3.fromRGB(255, 150, 80) }
	for i = 1, 14 do
		local ang = math.random() * math.pi * 2
		local rr = 55 + math.random() * 70
		local z = z1 + math.random() * zl
		local sz = 70 + math.random() * 90
		local cloud = part({ Size = Vector3.new(sz, sz * (0.5 + math.random() * 0.5), 0.4), Material = Enum.Material.Neon, Color = nebCols[math.random(1, #nebCols)], Transparency = 0.86 + math.random() * 0.08 })
		local at = ORIGIN + Vector3.new(math.cos(ang) * rr, math.sin(ang) * rr, z)
		local base = CFrame.lookAt(at, ORIGIN + Vector3.new(0, 0, z)) * CFrame.Angles(0, 0, math.random() * 3)
		cloud.CFrame = base
		cloud.Parent = folder
		nebula[i] = { Part = cloud, Base = base, Spin = (math.random() - 0.5) * 0.12 }
	end
	local light = part({ Size = Vector3.new(1, 1, 1), Transparency = 1 })
	local pl = Instance.new("PointLight")
	pl.Range = 60
	pl.Brightness = 3
	pl.Shadows = false
	pl.Parent = light
	light.Parent = folder
	folder.Parent = Workspace
	return { Folder = folder, Frames = frames, Streaks = streaks, Ghosts = ghosts, Light = light, PL = pl, Stars = stars, Nebula = nebula }
end

-- YOUR COMPANION comes through time with you: a copy of your lead companion floats along behind the rover
local function buildCompanion(folder: Instance): Model?
	local profile = Net.Profile
	local id = profile and profile.Buddies and profile.Buddies[1]
	if not id then return nil end
	local dino = nil
	for _, d in ipairs(profile.Dinos or {}) do if d.Id == id then dino = d break end end
	local tmpl = dino and DinoShared:FindFirstChild("Dinosaurs") and DinoShared.Dinosaurs:FindFirstChild(dino.Species)
	if not tmpl then return nil end
	local m = tmpl:Clone() :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
		elseif d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	if not m.PrimaryPart then m:Destroy() return nil end
	local _, size = m:GetBoundingBox()
	m:ScaleTo(math.clamp(5.5 / math.max(size.Y, size.Z * 0.5, 0.5), 0.15, 3))
	m.Parent = folder
	pcall(function() require(script.Parent.RarityFx).Apply(m, dino.Rarity or "Common", 3) end)
	local anim = nil
	pcall(function()
		anim = require(DinoShared:WaitForChild("DinosaurAnimations")).get(m)
		if anim then anim:SetLocomotion("Run", 0.1) end
	end)
	return m
end

--------------------------------------------------------------------------------
-- screen overlay: bars, year counter, era title, scanlines, glitch bars, flash
--------------------------------------------------------------------------------
local function buildOverlay(reverse: boolean)
	local gui, canvas = Kit.Screen("DinoWarpUI", 60, true)
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
		TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0.1) }):Play()
	end
	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 30
	flash.Parent = root
	-- scanlines
	local scan = Instance.new("Frame")
	scan.BackgroundTransparency = 1
	scan.Size = UDim2.fromScale(1, 1)
	scan.ZIndex = 18
	scan.Parent = root
	for i = 0, 59 do
		local l = Instance.new("Frame")
		l.BackgroundColor3 = Color3.new(0, 0, 0)
		l.BackgroundTransparency = 0.82
		l.BorderSizePixel = 0
		l.Size = UDim2.new(1, 0, 0, 2)
		l.Position = UDim2.fromScale(0, i / 60)
		l.ZIndex = 18
		l.Parent = scan
	end
	-- glitch bars (shown in bursts)
	local glitch = {}
	for i = 1, 7 do
		local g = Instance.new("Frame")
		g.BorderSizePixel = 0
		g.BackgroundTransparency = 1
		g.ZIndex = 19
		g.Parent = root
		glitch[i] = g
	end
	-- year counter with RGB split copies
	local yearBox = Instance.new("Frame")
	yearBox.BackgroundTransparency = 1
	yearBox.AnchorPoint = Vector2.new(0.5, 0.5)
	yearBox.Position = UDim2.fromScale(0.5, 0.2)
	yearBox.Size = UDim2.fromOffset(760, 70)
	yearBox.Parent = canvas
	local splitR = Kit.Text(yearBox, "", { Pixel = true, Size = UDim2.fromScale(1, 1), Color = Color3.fromRGB(255, 60, 90), Shadow = 0, Stroke = 0, ZIndex = 21 })
	local splitC = Kit.Text(yearBox, "", { Pixel = true, Size = UDim2.fromScale(1, 1), Color = Color3.fromRGB(60, 240, 255), Shadow = 0, Stroke = 0, ZIndex = 21 })
	local year = Kit.Text(yearBox, "", { Pixel = true, Size = UDim2.fromScale(1, 1), Color = Color3.fromRGB(255, 244, 214), Color2 = Color3.fromRGB(255, 176, 46), Shadow = 5, Stroke = 4, ZIndex = 23 })
	for _, t in ipairs({ splitR, splitC }) do
		for _, l in ipairs(t:GetChildren()) do if l:IsA("TextLabel") then l.TextTransparency = 0.45 end end
	end
	local caption = Kit.Text(canvas, reverse and "RETURNING TO BASE CAMP" or "TRAVELLING BACK IN TIME", { Pixel = true, Size = UDim2.fromOffset(520, 18), Position = UDim2.new(0.5, 0, 0.2, 52), AnchorPoint = Vector2.new(0.5, 0), Color = Color3.fromRGB(200, 255, 245), Shadow = 2, Stroke = 2, ZIndex = 23 })
	local title = Instance.new("Frame")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.5)
	title.Size = UDim2.fromOffset(820, 150)
	title.Visible = false
	title.Parent = canvas
	local eraName = Kit.Text(title, "", { Pixel = true, Size = UDim2.new(1, 0, 0.56, 0), Color = Color3.fromRGB(234, 255, 216), Color2 = Color3.fromRGB(95, 211, 90), Shadow = 7, Stroke = 5, ZIndex = 24 })
	local eraYear = Kit.Text(title, "", { Pixel = true, Size = UDim2.new(0.7, 0, 0.2, 0), Position = UDim2.fromScale(0.15, 0.68), Color = Color3.fromRGB(255, 226, 120), Shadow = 3, Stroke = 3, ZIndex = 24 })
	local skip = Kit.Text(root, "TAP TO SKIP", { Pixel = true, Size = UDim2.new(0.3, 0, 0.03, 0), Position = UDim2.new(0.5, 0, 0.965, 0), AnchorPoint = Vector2.new(0.5, 1), Color = Color3.fromRGB(255, 226, 120), Shadow = 2, Stroke = 2, ZIndex = 25 })
	skip.Visible = false
	local tap = Instance.new("TextButton")
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 40
	tap.Parent = root
	return {
		Gui = gui, Bars = bars, Flash = flash, Scan = scan, Glitch = glitch, Year = year, SplitR = splitR, SplitC = splitC,
		YearBox = yearBox, Caption = caption, Title = title, EraName = eraName, EraYear = eraYear, Skip = skip, Tap = tap,
	}
end

local function flash(ui, strength: number, color: Color3?, dur: number?)
	ui.Flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	ui.Flash.BackgroundTransparency = 1 - strength
	TweenService:Create(ui.Flash, TweenInfo.new(dur or 0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

local function glitchBurst(ui, amount: number)
	for _, g in ipairs(ui.Glitch) do
		if math.random() < amount then
			g.BackgroundColor3 = ({ Color3.fromRGB(255, 60, 90), Color3.fromRGB(60, 240, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(95, 211, 90) })[math.random(1, 4)]
			g.BackgroundTransparency = 0.35 + math.random() * 0.4
			g.Size = UDim2.new(0.3 + math.random() * 0.7, 0, 0, math.random(3, 16))
			g.Position = UDim2.fromScale(math.random() * 0.5, math.random())
		else
			g.BackgroundTransparency = 1
		end
	end
end

local function formatYear(y: number): string
	-- y < 0 = BC
	if y >= 0 then return string.format("%d AD", y) end
	local n = math.floor(-y)
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if s:sub(1, 1) == "," then s = s:sub(2) end
	return s .. " BC"
end

--------------------------------------------------------------------------------
-- post fx
--------------------------------------------------------------------------------
local function makePost()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DinoWarpGrade"
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "DinoWarpBlur"
	blur.Size = 0
	blur.Parent = Lighting
	return { CC = cc, Blur = blur }
end

--------------------------------------------------------------------------------
-- the sequence
--------------------------------------------------------------------------------
-- opts: { Reverse, Full, Skippable, Name, Era, YearTo, Arrival (root CFrame at destination), OnArrive }
local live = {} :: any -- what the running warp has made (so a failure can always clean up)
-- the air after the trip: the look of wherever you've arrived (OnArrive has just applied its zone)
local function restoreAir()
	local atm = live.Atm
	local look = Zone.Look and Zone.Look()
	if atm and atm.Parent and look and look.Atmosphere then
		for k, v in pairs(look.Atmosphere) do pcall(function() (atm :: any)[k] = v end) end
	end
	live.Atm = nil
end
local function play(opts)
	-- the warp is a clean cinematic: every other screen hides until it ends
	local cine = Cinema.Begin("DinoWarpUI")
	live.Cine = cine
	require(script.Parent.Audio).Sting("Warp")
	local reverse = opts.Reverse == true
	local full = opts.Full == true
	local dur = full and 6.2 or (reverse and 2.6 or 2.9)
	-- after your first trip there and back the gate is quick (user 2026-10-13): the long version is a first-time thing
	local tips = Net.Profile and Net.Profile.Flags and Net.Profile.Flags.Tips
	local runs = Net.Profile and Net.Profile.Stats and Net.Profile.Stats.Runs or 0
	local veteran = (tips ~= nil and tips.WarpRoundTrip == true) or runs >= 2 -- (older saves: well past their first)
	if veteran then
		full = false
		dur = reverse and 1.5 or 1.7
	end
	if opts.Quick then dur = 1.2 end
	-- (the first warp home completes the round trip)
	if reverse and not veteran then
		task.delay(dur + 0.5, function()
			if tips then tips.WarpRoundTrip = true end
			pcall(function() Net.Ask("Tip", { Key = "WarpRoundTrip" }) end)
		end)
	end
	local vehicle = Drive.State.Vehicle
	local root = vehicle and vehicle.PrimaryPart
	local cam = Workspace.CurrentCamera
	Drive.HoldCamera(true)
	cam.CameraType = Enum.CameraType.Scriptable
	-- (each piece goes into `live` the moment it exists: a failure part-way still takes all of it down)
	local post = makePost()
	live.Post = post
	local ui = buildOverlay(reverse)
	live.Ui = ui
	local tunnel = buildTunnel(reverse)
	live.Tunnel = tunnel
	-- deep space: the era's haze would grey the stars out - thinned for the trip, the destination's look on arrival
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	live.Atm = atm
	if atm then atm.Density, atm.Haze, atm.Glare = 0.02, 0, 0 end
	local buddy = (not opts.Quick) and buildCompanion(tunnel.Folder) or nil
	local skipped = false
	local conns = {}
	live.Post, live.Ui, live.Tunnel, live.Conns = post, ui, tunnel, conns
	if opts.Skippable then
		ui.Skip.Visible = true
		local cutStart = os.clock()
		table.insert(conns, ui.Tap.Activated:Connect(function() if os.clock() - cutStart > 1 then skipped = true end end))
		table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
			if (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA) and os.clock() - cutStart > 1 then skipped = true end
		end))
	end
	-- portal punch-in
	flash(ui, 0.9, reverse and Color3.fromRGB(255, 210, 120) or Color3.fromRGB(180, 255, 240), 0.5)
	DinosaurVFX.Shake(0.8, 0.5)
	post.Blur.Size = 18
	TweenService:Create(post.Blur, TweenInfo.new(0.5), { Size = 2 }):Play()
	TweenService:Create(post.CC, TweenInfo.new(0.4), { Saturation = 0.5, Contrast = 0.25 }):Play()
	local yearFrom = reverse and (opts.YearTo or -68000000) or 2026
	local yearTo = reverse and 2026 or (opts.YearTo or -68000000)
	local t0 = os.clock()
	local rollPhase = math.random() * 6
	local lastGlitch = 0
	local done = false
	local function vehicleAt(z: number): CFrame
		return CFrame.new(ORIGIN + Vector3.new(0, -2 + math.sin(z * 0.05) * 1.2, -z)) * CFrame.Angles(0, 0, math.sin(z * 0.02) * 0.25)
	end
	local rh = (vehicle and vehicle:GetAttribute("RootHeight")) or 2.6
	local conn
	local frame -- (one frame of the trip; run protected below)
	conn = RunService.RenderStepped:Connect(function(dt)
		if not live.Ui then conn:Disconnect() return end
		-- (2026-10-14: a frame that threw used to throw again every frame, never reaching the end of the trip - the
		-- player was stuck in the tunnel for good. A broken frame ends the ride: you land)
		local okF, errF = pcall(frame, dt)
		if not okF then
			warn("[Warp] frame:", errF)
			done = true
		end
	end)
	frame = function(dt: number)
		local t = os.clock() - t0
		local u = math.clamp(t / dur, 0, 1)
		if skipped then u = 1 end
		-- distance travelled: accelerating rush
		local z = LENGTH * 0.05 + (LENGTH * 0.88) * (u ^ 1.35)
		local vcf = vehicleAt(z)
		if root and root.Parent then
			vehicle:PivotTo(vcf * CFrame.new(0, rh, 0))
			Drive.Place(vcf * CFrame.new(0, rh, 0))
		end
		-- your companion, floating along behind you (a little bob and tumble)
		local bcf = vcf * CFrame.new(math.sin(t * 1.7) * 1.5, 4.5 + math.sin(t * 2.3) * 0.8, 13)
		if buddy and buddy.Parent then
			buddy:PivotTo(bcf * CFrame.Angles(math.sin(t * 1.1) * 0.15, math.sin(t * 0.6) * 0.3, math.sin(t * 0.9) * 0.12))
		end
		-- camera: chase from behind and below, spiralling roll, FOV punch. Mid-trip it swings back past your
		-- companion (you, then it), then settles behind you again for the arrival
		local roll = math.sin(t * 1.3 + rollPhase) * 0.35 + t * (reverse and -0.4 or 0.4)
		local camPos = vcf.Position + Vector3.new(math.sin(t * 0.9) * 4, 3.5 + math.cos(t * 0.7) * 2, 15 - math.sin(u * math.pi) * 5)
		local look = vcf.Position + Vector3.new(0, 1.5, -18)
		local k = 0
		if buddy and buddy.Parent then
			k = math.clamp((u - 0.36) / 0.1, 0, 1) * math.clamp((0.8 - u) / 0.1, 0, 1)
			k = k * k * (3 - 2 * k)
		end
		if k > 0 then
			local bp = bcf.Position
			local shotPos = bp + Vector3.new(6 + math.sin(t) * 1.5, 1.5, 9)
			camPos = camPos:Lerp(shotPos, k)
			look = look:Lerp(bp:Lerp(vcf.Position, 0.25), k)
			roll *= (1 - k * 0.8)
		end
		cam.CFrame = CFrame.lookAt(camPos, look) * CFrame.Angles(0, 0, roll)
		cam.FieldOfView = 78 + math.sin(u * math.pi) * 32 * (1 - k * 0.6)
		-- the stars twinkle, the nebulae turn
		for i = 1 + (math.floor(t * 60) % 6), #tunnel.Stars, 6 do
			local st = tunnel.Stars[i]
			if st.Twinkle then st.Part.Transparency = 0.15 + 0.6 * (0.5 + 0.5 * math.sin(t * 5 + st.Phase)) end
		end
		for _, nb in ipairs(tunnel.Nebula) do nb.Part.CFrame = nb.Base * CFrame.Angles(0, 0, t * nb.Spin) end
		-- frames spin + pulse
		for i, fr in ipairs(tunnel.Frames) do
			fr.Angle += fr.Spin * dt * (1 + u * 2)
			local spinCF = fr.Center * CFrame.Angles(0, 0, fr.Angle)
			local pulse = 1 + 0.18 * math.sin(t * 9 - i * 0.6)
			for _, pc in ipairs(fr.Pieces) do
				local off = pc.Offset
				pc.Part.CFrame = spinCF * CFrame.new(off.Position * pulse) * off.Rotation
			end
		end
		-- streaks rush past the camera
		for _, s in ipairs(tunnel.Streaks) do
			s.Z = (s.Z + s.Speed * dt * (1 + u * 2)) % LENGTH
			local zz = z + 30 - s.Z
			s.Part.CFrame = CFrame.new(ORIGIN + Vector3.new(math.cos(s.A) * s.R, math.sin(s.A) * s.R, -zz))
			s.Part.Color = colorAt(math.clamp(zz / LENGTH, 0, 1), reverse):Lerp(Color3.new(1, 1, 1), 0.5)
		end
		-- silhouettes drift and turn
		for _, g in ipairs(tunnel.Ghosts) do
			local wob = CFrame.new(0, math.sin(t * 1.6 + g.Phase) * 1.5, 0) * CFrame.Angles(0, (g.Fossil and t * 0.8 or math.sin(t + g.Phase) * 0.15), 0)
			g.Model:PivotTo(g.Base * wob)
		end
		tunnel.Light.CFrame = vcf * CFrame.new(0, 4, -10)
		tunnel.PL.Color = colorAt(u, reverse)
		-- grade follows the tunnel colour
		post.CC.TintColor = Color3.new(1, 1, 1):Lerp(colorAt(u, reverse), 0.22)
		-- year counter: exponential spin
		if not done then
			local e = u ^ 0.6
			local y
			if reverse then
				local lf = math.log10(-yearFrom) * (1 - e) + math.log10(10) * e
				y = (u > 0.92) and 2026 or -math.floor(10 ^ lf)
			else
				local lt = math.log10(-yearTo)
				local lf = 3.3
				y = (u < 0.06) and 2026 or -math.floor(10 ^ (lf + (lt - lf) * e))
				if u >= 0.98 then y = yearTo end
			end
			local text = formatYear(y)
			Kit.SetText(ui.Year, text)
			Kit.SetText(ui.SplitR, text)
			Kit.SetText(ui.SplitC, text)
			local split = 2 + math.sin(t * 40) * 2 + (u > 0.55 and u < 0.75 and 6 or 0)
			for _, l in ipairs(ui.SplitR:GetChildren()) do if l:IsA("TextLabel") then l.Position = UDim2.fromOffset(-split, 0) end end
			for _, l in ipairs(ui.SplitC:GetChildren()) do if l:IsA("TextLabel") then l.Position = UDim2.fromOffset(split, 1) end end
		end
		-- glitch bursts at a few beats + random flicker
		if t - lastGlitch > 0.09 then
			lastGlitch = t
			local burst = (u > 0.55 and u < 0.72) and 0.85 or ((math.random() < 0.15) and 0.4 or 0)
			glitchBurst(ui, burst)
			if burst > 0.8 then
				DinosaurVFX.Shake(0.25, 0.15)
				post.Blur.Size = 6 + math.random() * 6
			end
		end
		if u >= 1 then done = true end
	end
	-- (never longer than the trip and a bit: the tunnel always lets go)
	while not done and os.clock() - t0 < dur + 4 do task.wait() end
	done = true
	conn:Disconnect()
	for _, c in ipairs(conns) do c:Disconnect() end
	ui.Skip.Visible = false
	-- slam: the date and the era name
	Kit.SetText(ui.Year, formatYear(yearTo))
	Kit.SetText(ui.SplitR, "")
	Kit.SetText(ui.SplitC, "")
	Kit.Punch(ui.YearBox, 0.5)
	glitchBurst(ui, 0)
	flash(ui, 1, reverse and Color3.fromRGB(255, 240, 200) or Color3.fromRGB(200, 255, 190), 0.7)
	local CK = require(script.Parent.UI.CineKit)
	CK.ImpactFrame(0.9)
	CK.SunBurst(1)
	DinosaurVFX.Shake(1.1, 0.5)
	post.Blur.Size = 24
	TweenService:Create(post.Blur, TweenInfo.new(0.7), { Size = 0 }):Play()
	-- arrive
	if root and root.Parent and opts.Arrival then
		vehicle:PivotTo(opts.Arrival)
		Drive.Place(opts.Arrival)
	end
	tunnel.Folder:Destroy()
	cam.FieldOfView = 70
	local a = opts.Arrival
	if a then
		cam.CFrame = CFrame.lookAt(a.Position - a.LookVector * 22 + Vector3.new(0, 8, 0), a.Position + a.LookVector * 10)
	end
	ui.Caption.Visible = false
	-- going back in time the era's own arrival card says where you are (no double title); coming home, this does
	if opts.Name and reverse then
		Kit.PopOut(ui.YearBox) -- the date is in the title now; don't show it twice
		Kit.SetText(ui.EraName, opts.Name)
		Kit.SetText(ui.EraYear, opts.Era or "")
		ui.Title.Visible = true
		Kit.Pop(ui.Title, 1.6)
	end
	TweenService:Create(post.CC, TweenInfo.new(0.8), { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	Drive.HoldCamera(false)
	live.Arrived = true
	if opts.OnArrive then task.spawn(opts.OnArrive) end
	restoreAir()
	task.wait(full and 1.6 or 0.9)
	for _, f in ipairs(ui.Bars) do TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0) }):Play() end
	if ui.Title.Visible then Kit.PopOut(ui.Title) else Kit.PopOut(ui.YearBox) end
	task.wait(0.4)
	ui.Gui:Destroy()
	post.CC:Destroy()
	post.Blur:Destroy()
	Cinema.End(cine)
end

-- never stuck: a warp waits for one still running, and if anything in it fails the player still lands
-- where they were going (a failed warp used to leave Warp.Playing set, so the trip home never started)
function Warp.Play(opts)
	local t0 = os.clock()
	while Warp.Playing and os.clock() - t0 < 12 do task.wait(0.1) end
	Warp.Playing = true
	table.clear(live)
	local ok, err = pcall(play, opts)
	if not ok then
		warn("[Warp] failed:", err)
		for _, c in ipairs(live.Conns or {}) do pcall(function() c:Disconnect() end) end
		if live.Ui and live.Ui.Gui then live.Ui.Gui:Destroy() end
		if live.Post then
			if live.Post.CC then live.Post.CC:Destroy() end
			if live.Post.Blur then live.Post.Blur:Destroy() end
		end
		if live.Tunnel and live.Tunnel.Folder then live.Tunnel.Folder:Destroy() end
		restoreAir()
		Drive.HoldCamera(false)
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		Workspace.CurrentCamera.FieldOfView = 70
		if not live.Arrived then
			local v = Drive.State.Vehicle
			if v and opts.Arrival then
				v:PivotTo(opts.Arrival)
				Drive.Place(opts.Arrival)
			end
			if opts.OnArrive then task.spawn(opts.OnArrive) end
		end
		if live.Cine then Cinema.End(live.Cine) end
	end
	table.clear(live)
	Warp.Playing = false
end

return Warp
