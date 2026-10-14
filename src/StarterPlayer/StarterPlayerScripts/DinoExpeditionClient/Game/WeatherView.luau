--[[
	WeatherView — the server's weather, drawn round you (2026-10-14; server: Weather.luau, numbers: WorldEvents).

	  The sky        Zone blends each weather into every zone's light (overcast, fog, wet shine), so cutscenes that put
	                 the light back put the weather back too. A new weather fades in over WorldEvents.Fade seconds.
	  Rain / storm   dense streaks slanting with the wind, splashes at your feet, the dark heavy downpour in a storm;
	                 in the snowy Frost Forest it falls as snow (no lightning in a blizzard)
	  Hail           white pellets that bounce where they land
	  Wind           streaks racing past, leaves blown sideways (dust in the deserts), grass leaning (GlobalWind)
	  Fog            thick haze and a low mist drifting along the ground
	  Lightning      "Lightning" from the server: a bolt somewhere in your sky, a flash, thunder a beat later
	Nothing falls indoors (something solid and anchored over your head) and nothing is drawn while a cutscene or a
	boss's own storm owns the screen. Lower graphics settings get less of everything.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local WorldEvents = require(Shared:WaitForChild("Game"):WaitForChild("WorldEvents"))
local Net = require(script.Parent.Net)
local Zone = require(script.Parent.Zone)
local Audio = require(script.Parent.Audio)
local Ambience = require(script.Parent.Ambience)
local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)

local player = Players.LocalPlayer
local WeatherView = {}

-- what each weather does: the light (Dark / Fog / Wet, for Zone) and what falls (0..1 each)
local LOOK = {
	Clear = { Dark = 0, Fog = 0, Wet = 0, Rain = 0, Hail = 0, Wind = 0.05, Mist = 0 },
	Rain = { Dark = 0.55, Fog = 0.22, Wet = 1, Rain = 0.55, Hail = 0, Wind = 0.2, Mist = 0.15 },
	Storm = { Dark = 1, Fog = 0.32, Wet = 1, Rain = 1, Hail = 0, Wind = 0.6, Mist = 0.25 },
	Fog = { Dark = 0.25, Fog = 1, Wet = 0.3, Rain = 0, Hail = 0, Wind = 0, Mist = 1 },
	Wind = { Dark = 0.12, Fog = 0.08, Wet = 0, Rain = 0, Hail = 0, Wind = 1, Mist = 0 },
	Hail = { Dark = 0.7, Fog = 0.2, Wet = 0.6, Rain = 0.12, Hail = 1, Wind = 0.35, Mist = 0.1 },
}
local KEYS = { "Dark", "Fog", "Wet", "Rain", "Hail", "Wind", "Mist" }
local SNOW_ZONES = { FrostForest = true } -- rain falls as snow here

local folder: Folder
local sky: Part -- over your head: rain, hail, snow come from here
local near: Part -- a tighter box right over you (the downpour's density is all close up)
local ground: Part -- at your feet: splashes, bounces, mist
local fx = {} :: { [string]: ParticleEmitter }
local streaks = {} :: { any }
local sounds = {} :: { [string]: Sound | false }
local flash: ColorCorrectionEffect
local mix = table.clone(LOOK.Clear)
local indoors = false
local held = false
local windDir = Vector3.new(1, 0, 0.3).Unit
local baseWind = Vector3.zero

local function quality(): number
	local q = UserGameSettings.SavedQualityLevel.Value
	if q == 0 then return 0.6 end
	return math.clamp(q / 10, 0.25, 1)
end

local function hostPart(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size
	p.Parent = folder
	return p
end

local function emitter(name: string, host: Part, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0
	e.Enabled = true
	for k, v in pairs(props) do (e :: any)[k] = v end
	e.Parent = host
	fx[name] = e
	return e
end

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function build()
	folder = Instance.new("Folder")
	folder.Name = "DinoWeather"
	folder.Parent = Workspace
	sky = hostPart("Sky", Vector3.new(110, 1, 110))
	near = hostPart("Near", Vector3.new(36, 1, 36))
	ground = hostPart("Ground", Vector3.new(70, 0.2, 70))
	local streak = {
		Texture = SPARK, EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Speed = NumberRange.new(105, 125), SpreadAngle = Vector2.new(2, 2), Lifetime = NumberRange.new(0.55, 0.7),
		Size = NumberSequence.new(0.13), Squash = NumberSequence.new(3), LightEmission = 0.15, LightInfluence = 0.6,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.85, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(196, 210, 228)),
	}
	emitter("Rain", sky, streak)
	local close = table.clone(streak)
	close.Lifetime = NumberRange.new(0.32, 0.4)
	close.Size = NumberSequence.new(0.1)
	emitter("RainNear", near, close)
	emitter("Hail", sky, {
		Texture = SPARK, EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Speed = NumberRange.new(80, 95), SpreadAngle = Vector2.new(3, 3), Lifetime = NumberRange.new(0.6, 0.8),
		Size = NumberSequence.new(0.2), Squash = NumberSequence.new(0.7), LightEmission = 0.1, LightInfluence = 0.8,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.9, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(238, 244, 252)),
	})
	emitter("Snow", sky, {
		Texture = SPARK, EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(9, 14), SpreadAngle = Vector2.new(20, 20), Lifetime = NumberRange.new(4.5, 5.5),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.24) }), LightEmission = 0, LightInfluence = 1,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.9, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(250, 252, 255)), RotSpeed = NumberRange.new(-90, 90),
	})
	emitter("Splash", ground, {
		Texture = SPARK, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(55, 55),
		Lifetime = NumberRange.new(0.18, 0.28), Acceleration = Vector3.new(0, -30, 0), LightEmission = 0.1, LightInfluence = 0.7,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.04) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(205, 218, 235)),
	})
	emitter("Bounce", ground, {
		Texture = SPARK, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(7, 11), SpreadAngle = Vector2.new(35, 35),
		Lifetime = NumberRange.new(0.35, 0.5), Acceleration = Vector3.new(0, -60, 0), LightEmission = 0.1, LightInfluence = 0.8,
		Size = NumberSequence.new(0.17), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.8) }),
		Color = ColorSequence.new(Color3.fromRGB(240, 246, 255)),
	})
	emitter("Mist", ground, {
		Texture = SMOKE, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(80, 80),
		Lifetime = NumberRange.new(8, 11), LightEmission = 0, LightInfluence = 1, RotSpeed = NumberRange.new(-6, 6), Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 9), NumberSequenceKeypoint.new(1, 16) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.84), NumberSequenceKeypoint.new(0.7, 0.86), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(226, 230, 236)),
	})
	-- wind: long faint streaks racing past (recycled)
	for _ = 1, 16 do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(240, 244, 250)
		p.Size = Vector3.new(0.06, 0.06, 8)
		p.Transparency = 1
		p.Parent = folder
		table.insert(streaks, { Part = p, Life = math.random(), Pos = Vector3.zero, Len = 8 })
	end
	flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "DinoWeatherFlash"
	flash.Parent = Lighting
end

--------------------------------------------------------------------------------
-- the weather right now (from the folder's attributes: late joiners included)
--------------------------------------------------------------------------------
local function now(): number
	return Net.ServerTime()
end

local function current(): any
	local id = Shared:GetAttribute("Weather")
	local prev = Shared:GetAttribute("WeatherPrev")
	local at = tonumber(Shared:GetAttribute("WeatherAt")) or 0
	local a = LOOK[prev] or LOOK.Clear
	local b = LOOK[id] or LOOK.Clear
	local f = math.clamp((now() - at) / WorldEvents.Fade, 0, 1)
	f = f * f * (3 - 2 * f)
	local out = {}
	for _, k in ipairs(KEYS) do out[k] = a[k] + (b[k] - a[k]) * f end
	-- (each weather blows from its own side: the same for everyone)
	local ang = math.rad((at * 37) % 360)
	windDir = Vector3.new(math.cos(ang), 0, math.sin(ang))
	return out
end

-- a cutscene, or a boss's own storm / whiteout, owns the screen
local function owned(): boolean
	return Cinema.Playing() or Lighting:FindFirstChild("DinoStorm") ~= nil or Lighting:FindFirstChild("DinoWhiteout") ~= nil
end

local function focus(): Vector3?
	local cam = Workspace.CurrentCamera
	if not cam then return nil end
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if head and (head.Position - cam.CFrame.Position).Magnitude < 60 then return head.Position end
	return cam.CFrame.Position
end

-- something solid and anchored over your head (rovers are unanchored, so a jeep's roof doesn't stop the rain)
local function checkIndoors(at: Vector3): boolean
	local skip = { folder } :: { Instance }
	if player.Character then table.insert(skip, player.Character) end
	local amb = Workspace:FindFirstChild("DinoAmbience")
	if amb then table.insert(skip, amb) end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = skip
	local from = at
	for _ = 1, 4 do
		local hit = Workspace:Raycast(from, Vector3.new(0, 160, 0), rp)
		if not hit then return false end
		local p = hit.Instance
		if p:IsA("BasePart") and p.Anchored and p.Transparency < 0.4 and p.Material ~= Enum.Material.Grass and p.Material ~= Enum.Material.LeafyGrass then
			return true
		end
		rp:AddToFilter(p)
		from = hit.Position
	end
	return false
end

local function groundY(at: Vector3): number
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { folder, player.Character :: any }
	rp.IgnoreWater = false
	local hit = Workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), rp)
	return hit and hit.Position.Y or (at.Y - 4)
end

--------------------------------------------------------------------------------
-- sound
--------------------------------------------------------------------------------
local function setLoop(slot: string, level: number)
	local s = sounds[slot]
	if s == nil then
		if level <= 0.01 then return end
		s = Audio.Loop(slot) or false
		if s then (s :: Sound).Volume = 0 end
		sounds[slot] = s
	end
	if not s then return end
	local snd = s :: Sound
	local target = (Audio.Level[slot] or 0.5) * level
	snd.Volume += (target - snd.Volume) * 0.25
	if slot == "HailLoop" then snd.PlaybackSpeed = 1.18 end
end

--------------------------------------------------------------------------------
-- lightning
--------------------------------------------------------------------------------
local function boltPart(a: Vector3, b: Vector3, w: number): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(214, 228, 255)
	p.Size = Vector3.new(w, w, (b - a).Magnitude)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = folder
	return p
end

local function strike(seed: number)
	if owned() or mix.Dark < 0.6 or SNOW_ZONES[Zone.Current] then return end
	local cam = Workspace.CurrentCamera
	local at = focus()
	if not (cam and at) then return end
	local r = Random.new(seed)
	local ang = r:NextNumber() * math.pi * 2
	local dist = r:NextNumber(150, 430)
	local gx, gz = at.X + math.cos(ang) * dist, at.Z + math.sin(ang) * dist
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { folder }
	local hit = Workspace:Raycast(Vector3.new(gx, at.Y + 300, gz), Vector3.new(0, -600, 0), rp)
	local base = Vector3.new(gx, hit and hit.Position.Y or (at.Y - 10), gz)
	local top = base + Vector3.new(0, 320, 0)
	-- the bolt: a jagged trunk and a couple of forks, flickering twice
	local parts = {}
	local prev = top
	local n = 11
	for k = 1, n do
		local u = k / n
		local p = top:Lerp(base, u) + (k < n and Vector3.new(r:NextNumber(-16, 16), 0, r:NextNumber(-16, 16)) or Vector3.zero)
		table.insert(parts, boltPart(prev, p, 2.2))
		if k == 3 or k == 6 then
			local fork = p
			for _ = 1, 3 do
				local q = fork + Vector3.new(r:NextNumber(-22, 22), -r:NextNumber(18, 30), r:NextNumber(-22, 22))
				table.insert(parts, boltPart(fork, q, 1.2))
				fork = q
			end
		end
		prev = p
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(200, 220, 255)
	glow.Range = 60
	glow.Brightness = 8
	glow.Parent = parts[#parts]
	local function show(on: boolean)
		for _, p in ipairs(parts) do p.Transparency = on and 0 or 1 end
	end
	task.spawn(function()
		task.wait(0.07)
		show(false)
		task.wait(0.06)
		show(true)
		task.wait(0.13)
		for _, p in ipairs(parts) do p:Destroy() end
	end)
	-- the flash (softer the further off, softer still indoors)
	local k = math.clamp(1.25 - dist / 430, 0.35, 1) * (indoors and 0.5 or 1)
	flash.Brightness = 0.32 * k
	TweenService:Create(flash, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	-- the thunder, a beat later (further = later and lower)
	task.delay(0.15 + dist / 650, function()
		local slot = dist < 240 and "ThunderNear" or "ThunderFar"
		if Audio.Has(slot) then
			Audio.Play(slot, { Volume = indoors and 0.6 or 1 })
		else
			Audio.Play("StompBig", { Volume = (indoors and 0.5 or 0.9) * k, Pitch = 0.32, Exact = true })
		end
	end)
end

--------------------------------------------------------------------------------
-- every frame: follow the camera, set the rates
--------------------------------------------------------------------------------
local appliedKey = ""
local wasHeld = true
local first = true
local zoneWas = nil
local function tick()
	mix = current()
	held = owned()
	local at = focus()
	if at then indoors = checkIndoors(at) end
	-- the light (held while a cutscene owns it: the scene puts Zone.Look() back, weather and all)
	local key = string.format("%.2f/%.2f/%.2f/%s", mix.Dark, mix.Fog, mix.Wet, tostring(Zone.Current))
	if held then
		Zone.SetWeather(mix, false)
		wasHeld = true
	elseif key ~= appliedKey or wasHeld then
		-- (a new zone has its own tween running to the same blended look; the first one is instant)
		local t = first and 0 or (wasHeld and 1.5 or (Zone.Current ~= zoneWas and 1.2 or 0.6))
		Zone.SetWeather(mix, true, t)
		appliedKey, wasHeld, first, zoneWas = key, false, false, Zone.Current
	end
	-- what falls
	local q = quality()
	local out = (held or indoors) and 0 or 1
	local snow = SNOW_ZONES[Zone.Current] == true
	local dry = (Zone.BaseLook() or {}).Dry == true
	local rain = mix.Rain * out
	local wind = windDir * mix.Wind
	fx.Rain.Rate = snow and 0 or rain * 1100 * q
	fx.RainNear.Rate = snow and 0 or rain * 520 * q
	fx.Splash.Rate = snow and 0 or rain * 260 * q
	fx.Snow.Rate = snow and (rain * 700 * q) or 0
	fx.Hail.Rate = mix.Hail * out * 420 * q
	fx.Bounce.Rate = mix.Hail * out * 220 * q
	fx.Mist.Rate = mix.Mist * (held and 0 or 1) * 6 * q
	fx.Mist.Color = ColorSequence.new(dry and Color3.fromRGB(226, 196, 160) or Color3.fromRGB(226, 230, 236))
	local slant = wind * 32
	fx.Rain.Acceleration, fx.RainNear.Acceleration, fx.Hail.Acceleration = slant, slant, slant * 0.6
	fx.Snow.Acceleration = wind * 14 + Vector3.new(0, -0.5, 0)
	-- the grass leans, the leaves blow
	Workspace.GlobalWind = baseWind + wind * 40
	Ambience.Wind = held and Vector3.zero or wind * 12
	-- sound (muffled indoors, gone in a cutscene)
	local lvl = held and 0 or (indoors and 0.4 or 1)
	local storm = math.clamp((mix.Rain - 0.55) / 0.45, 0, 1)
	setLoop("RainLoop", snow and 0 or mix.Rain * (1 - storm * 0.5) * lvl)
	setLoop("StormLoop", snow and 0 or storm * lvl)
	setLoop("HailLoop", mix.Hail * lvl)
	setLoop("WindLoop", math.max(mix.Wind, snow and mix.Rain * 0.8 or 0) * lvl)
end

local function stepFrame(dt: number)
	local cam = Workspace.CurrentCamera
	local at = focus()
	if not (cam and at) then return end
	local lead = windDir * mix.Wind * -18 -- (the rain comes in from upwind)
	sky.CFrame = CFrame.new(at + Vector3.new(0, 38, 0) + lead)
	near.CFrame = CFrame.new(at + Vector3.new(0, 22, 0) + lead * 0.5)
	-- wind streaks: only in a real wind
	local w = held and 0 or math.clamp((mix.Wind - 0.3) / 0.7, 0, 1)
	local dry = (Zone.BaseLook() or {}).Dry == true
	local col = dry and Color3.fromRGB(226, 196, 156) or Color3.fromRGB(240, 244, 250)
	local active = math.floor(#streaks * w * quality() + 0.5)
	for i, s in ipairs(streaks) do
		if i > active then
			s.Part.Transparency = 1
			continue
		end
		s.Life += dt / 0.75
		if s.Life >= 1 then
			s.Life = 0
			local a = math.random() * math.pi * 2
			local r = 8 + math.random() * 38
			s.Pos = at + Vector3.new(math.cos(a) * r, -2 + math.random() * 14, math.sin(a) * r) - windDir * 30
			s.Len = 6 + math.random() * 6
			s.Part.Size = Vector3.new(0.06, 0.06, s.Len)
			s.Part.Color = col
		end
		s.Pos += windDir * 85 * dt
		s.Part.CFrame = CFrame.lookAt(s.Pos, s.Pos + windDir)
		-- (faint in, faint out)
		s.Part.Transparency = 1 - math.sin(s.Life * math.pi) * 0.32
	end
end

function WeatherView.Start()
	build()
	baseWind = Workspace.GlobalWind
	local gy = 0
	local acc, gAcc = 1, 1
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		gAcc += dt
		if acc >= 0.25 then
			acc = 0
			local ok, err = pcall(tick)
			if not ok then warn("[WeatherView] " .. tostring(err)) end
		end
		local at = focus()
		if at and gAcc >= 0.4 then
			gAcc = 0
			gy = groundY(at)
		end
		if at then ground.CFrame = CFrame.new(at.X, gy + 0.2, at.Z) end
		stepFrame(dt)
	end)
	Net.On("Lightning", function(info)
		if typeof(info) == "table" then strike(tonumber(info.Seed) or math.random(1, 1e6)) end
	end)
	-- a new weather rolling in: a word about it (the sky says the rest)
	Net.On("Weather", function(info)
		if typeof(info) ~= "table" then return end
		local w = WorldEvents.Weathers[info.Id]
		-- (never over a cutscene or a fight: the sky changing says it anyway)
		if not w or Cinema.Playing() or player:GetAttribute("Site") then return end
		local line = w.Line
		if SNOW_ZONES[Zone.Current] and (info.Id == "Rain" or info.Id == "Storm") then line = info.Id == "Storm" and "A BLIZZARD BLOWS IN" or "IT'S STARTING TO SNOW" end
		if w.Luck then line ..= "  -  STORM LUCK +" .. math.floor((w.Luck - 1) * 100 + 0.5) .. "%!" end
		Kit.Toast(line, w.Color, w.Icon)
	end)
end

return WeatherView
