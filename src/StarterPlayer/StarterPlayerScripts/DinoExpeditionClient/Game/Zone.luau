--[[
	Zone — per-era lighting, applied on the client when you arrive (each era looks like its own world).
	BaseCamp: warm late-afternoon outpost. FernValley: misty green morning. GiantPlains: dusty golden hour. SpineRiver: bright humid delta. FrostForest: snowy blue dawn. DawnDesert: Triassic sunrise. RedCliffs: Gobi golden dusk.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Zone = {}
Zone.Current = "BaseCamp"

-- every zone's full lighting rig is authored here, so nothing depends on whatever the place file had
-- (a stock baseplate's Bloom made every neon part glow hard). Lighting.Technology must be Future (set in Studio).
local LOOKS = {
	BaseCamp = {
		Lighting = {
			ClockTime = 16.1, GeographicLatitude = 30, Brightness = 2.1, ExposureCompensation = -0.05,
			OutdoorAmbient = Color3.fromRGB(122, 116, 118), Ambient = Color3.fromRGB(58, 56, 62),
			EnvironmentDiffuseScale = 0.55, EnvironmentSpecularScale = 0.35, ShadowSoftness = 0.16, GlobalShadows = true,
			ColorShift_Top = Color3.fromRGB(255, 236, 214), ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		},
		Atmosphere = { Density = 0.24, Offset = 0.2, Color = Color3.fromRGB(196, 214, 236), Decay = Color3.fromRGB(150, 140, 170), Glare = 0.1, Haze = 0.45 },
		Grade = { Saturation = 0.12, Contrast = 0.1, Brightness = 0.01, TintColor = Color3.fromRGB(255, 247, 236) },
		Bloom = { Intensity = 0.15, Size = 18, Threshold = 2.4 }, -- calm camp (tester: overstimulating): next to no glow
		SunRays = { Intensity = 0.04, Spread = 0.7 },
	},
	FernValley = {
		Lighting = {
			ClockTime = 9.4, GeographicLatitude = 18, Brightness = 2.2, ExposureCompensation = -0.05,
			OutdoorAmbient = Color3.fromRGB(116, 132, 112), Ambient = Color3.fromRGB(54, 62, 52),
			EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.3, ShadowSoftness = 0.2, GlobalShadows = true,
			ColorShift_Top = Color3.fromRGB(246, 255, 236), ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		},
		Atmosphere = { Density = 0.27, Offset = 0.12, Color = Color3.fromRGB(176, 214, 230), Decay = Color3.fromRGB(110, 150, 120), Glare = 0.25, Haze = 0.55 },
		Grade = { Saturation = 0.34, Contrast = 0.15, Brightness = 0.01, TintColor = Color3.fromRGB(250, 255, 240) },
		Bloom = { Intensity = 0.45, Size = 28, Threshold = 1.65 }, -- gentle: neon reads as lit, not blown out
		SunRays = { Intensity = 0.11, Spread = 0.8 },
	},
	-- golden hour on the plains: low warm sun, long shadows, dusty haze (2026-10-11 map pass)
	GiantPlains = {
		Lighting = {
			ClockTime = 16.9, GeographicLatitude = 24, Brightness = 2.5, ExposureCompensation = -0.05,
			OutdoorAmbient = Color3.fromRGB(150, 122, 104), Ambient = Color3.fromRGB(70, 56, 50),
			EnvironmentDiffuseScale = 0.55, EnvironmentSpecularScale = 0.3, ShadowSoftness = 0.16, GlobalShadows = true,
			ColorShift_Top = Color3.fromRGB(255, 214, 168), ColorShift_Bottom = Color3.fromRGB(40, 16, 0),
		},
		Atmosphere = { Density = 0.27, Offset = 0.16, Color = Color3.fromRGB(236, 206, 170), Decay = Color3.fromRGB(206, 120, 78), Glare = 0.55, Haze = 0.85 },
		Grade = { Saturation = 0.32, Contrast = 0.16, Brightness = 0.015, TintColor = Color3.fromRGB(255, 236, 212) },
		Bloom = { Intensity = 0.5, Size = 30, Threshold = 1.6 }, -- gentle: neon reads as lit, not blown out
		SunRays = { Intensity = 0.16, Spread = 0.85 },
	},
	-- bright late morning on the delta: humid, saturated greens, sea haze toward the river mouth
	SpineRiver = {
		Lighting = {
			ClockTime = 10.8, GeographicLatitude = 12, Brightness = 2.4, ExposureCompensation = -0.05,
			OutdoorAmbient = Color3.fromRGB(112, 136, 132), Ambient = Color3.fromRGB(52, 64, 64),
			EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.45, ShadowSoftness = 0.18, GlobalShadows = true,
			ColorShift_Top = Color3.fromRGB(240, 255, 250), ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		},
		Atmosphere = { Density = 0.28, Offset = 0.14, Color = Color3.fromRGB(190, 225, 232), Decay = Color3.fromRGB(110, 160, 170), Glare = 0.3, Haze = 0.6 },
		Grade = { Saturation = 0.34, Contrast = 0.14, Brightness = 0.01, TintColor = Color3.fromRGB(244, 255, 252) },
		Bloom = { Intensity = 0.45, Size = 28, Threshold = 1.65 },
		SunRays = { Intensity = 0.1, Spread = 0.8 },
	},
	-- snowy blue dawn in the frost forest: a low cool sun, soft shadows, pale haze, crisp air
	FrostForest = {
		Lighting = {
			ClockTime = 7.3, GeographicLatitude = 38, Brightness = 2.15, ExposureCompensation = -0.1,
			OutdoorAmbient = Color3.fromRGB(128, 140, 162), Ambient = Color3.fromRGB(56, 62, 78),
			EnvironmentDiffuseScale = 0.55, EnvironmentSpecularScale = 0.4, ShadowSoftness = 0.3, GlobalShadows = true,
			ColorShift_Top = Color3.fromRGB(226, 236, 255), ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		},
		Atmosphere = { Density = 0.3, Offset = 0.12, Color = Color3.fromRGB(214, 228, 244), Decay = Color3.fromRGB(150, 170, 206), Glare = 0.12, Haze = 0.7 },
		Grade = { Saturation = 0.22, Contrast = 0.13, Brightness = 0.0, TintColor = Color3.fromRGB(240, 246, 255) },
		Bloom = { Intensity = 0.4, Size = 26, Threshold = 1.7 }, -- snow is bright already: keep bloom under it
		SunRays = { Intensity = 0.06, Spread = 0.6 },
	},
	-- Triassic sunrise: a low orange sun, pink-violet haze over red dunes and painted hills, gentle bloom
	DawnDesert = {
		Dry = true, -- (weather: dust, not grey cloud)
		Lighting = {
			ClockTime = 6.75, GeographicLatitude = 22, Brightness = 2.3, ExposureCompensation = -0.02,
			OutdoorAmbient = Color3.fromRGB(150, 116, 132), Ambient = Color3.fromRGB(66, 50, 64),
			EnvironmentDiffuseScale = 0.55, EnvironmentSpecularScale = 0.3, ShadowSoftness = 0.2, GlobalShadows = true,
			ColorShift_Top = Color3.fromRGB(255, 190, 150), ColorShift_Bottom = Color3.fromRGB(60, 22, 52),
		},
		Atmosphere = { Density = 0.3, Offset = 0.12, Color = Color3.fromRGB(240, 176, 176), Decay = Color3.fromRGB(150, 92, 156), Glare = 0.4, Haze = 1.1 },
		Grade = { Saturation = 0.3, Contrast = 0.15, Brightness = 0.01, TintColor = Color3.fromRGB(255, 234, 228) },
		Bloom = { Intensity = 0.4, Size = 26, Threshold = 1.75 },
		SunRays = { Intensity = 0.12, Spread = 0.8 },
	},
	-- the Gobi at golden dusk: a warm low sun, long shadows on striped red cliffs, red-ochre haze
	RedCliffs = {
		Dry = true, -- (weather: dust, not grey cloud)
		Lighting = {
			ClockTime = 17.45, GeographicLatitude = 28, Brightness = 2.35, ExposureCompensation = -0.08,
			OutdoorAmbient = Color3.fromRGB(150, 112, 100), Ambient = Color3.fromRGB(72, 50, 46),
			EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.25, ShadowSoftness = 0.12, GlobalShadows = true,
			ColorShift_Top = Color3.fromRGB(255, 198, 142), ColorShift_Bottom = Color3.fromRGB(56, 18, 8),
		},
		Atmosphere = { Density = 0.28, Offset = 0.12, Color = Color3.fromRGB(232, 178, 132), Decay = Color3.fromRGB(196, 98, 62), Glare = 0.35, Haze = 1.0 },
		Grade = { Saturation = 0.3, Contrast = 0.18, Brightness = 0, TintColor = Color3.fromRGB(255, 232, 212) },
		Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.8 },
		SunRays = { Intensity = 0.1, Spread = 0.7 },
	},
}

local function effect(class: string, name: string): Instance
	local e = Lighting:FindFirstChild(name)
	if not e then
		-- retire the place's stock effect of this kind so ours is the only one (never one of the game's own: the
		-- weather's grade sits on top of the zone's)
		for _, other in ipairs(Lighting:GetChildren()) do
			if other.ClassName == class and other.Name ~= name and other.Name:sub(1, 4) ~= "Dino" then (other :: any).Enabled = false end
		end
		e = Instance.new(class)
		e.Name = name
		e.Parent = Lighting
	end
	return e :: Instance
end

--------------------------------------------------------------------------------
-- the weather on top (WeatherView sets it): Dark (overcast 0..1), Fog (0..1), Wet (0..1), Dry (a desert zone's dust
-- instead of grey). Every zone's look is blended with it, so whatever puts the light back puts the weather back too.
--------------------------------------------------------------------------------
local weather = { Dark = 0, Fog = 0, Wet = 0 }
local GREY = Color3.fromRGB(150, 158, 170)
local DUST = Color3.fromRGB(214, 176, 132)

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function blend(look: any): any
	local d, f, w = weather.Dark, weather.Fog, weather.Wet
	if d < 0.001 and f < 0.001 and w < 0.001 then return look end
	local dry = look.Dry == true
	local out = table.clone(look)
	local L = table.clone(look.Lighting)
	L.Brightness = look.Lighting.Brightness * (1 - 0.42 * d)
	L.OutdoorAmbient = look.Lighting.OutdoorAmbient:Lerp(Color3.fromRGB(104, 110, 122), 0.55 * d)
	L.ShadowSoftness = lerp(look.Lighting.ShadowSoftness, 0.85, d)
	L.EnvironmentSpecularScale = lerp(look.Lighting.EnvironmentSpecularScale, 0.85, 0.6 * w) -- (wet things shine)
	L.ColorShift_Top = look.Lighting.ColorShift_Top:Lerp(Color3.fromRGB(176, 186, 204), d)
	out.Lighting = L
	local A = table.clone(look.Atmosphere)
	local haze = dry and DUST or GREY
	A.Density = math.max(lerp(look.Atmosphere.Density, 0.42, d), lerp(look.Atmosphere.Density, 0.6, f))
	A.Haze = math.max(lerp(look.Atmosphere.Haze, 2.2, d), lerp(look.Atmosphere.Haze, 2.6, f))
	A.Color = look.Atmosphere.Color:Lerp(haze, math.max(d, f) * 0.75)
	A.Decay = look.Atmosphere.Decay:Lerp(haze:Lerp(Color3.new(), 0.35), math.max(d, f) * 0.7)
	A.Glare = look.Atmosphere.Glare * (1 - math.max(d, f))
	out.Atmosphere = A
	out.SunRays = { Intensity = look.SunRays.Intensity * (1 - d), Spread = look.SunRays.Spread }
	return out
end

-- the overcast grade, on its own effect over the zone's
local function weatherGrade(): any
	local d = weather.Dark
	return { Brightness = -0.05 * d, Saturation = -0.28 * d, Contrast = 0.07 * d, TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(206, 216, 236), d) }
end

-- the look the current zone is heading to, weather and all (a cutscene that dressed the light up puts it back to
-- THIS, never to a snapshot taken mid-tween)
function Zone.Look(): any
	local look = Zone.Current and LOOKS[Zone.Current] or nil
	return look and blend(look) or nil
end

-- the zone's own look, no weather (is it a desert, what does a clear day look like)
function Zone.BaseLook(zone: string?): any
	return LOOKS[zone or Zone.Current]
end

local stockCleared = false
function Zone.Apply(zone: string, instant: boolean?)
	local look = LOOKS[zone]
	if not look then return end
	look = blend(look)
	Zone.Current = zone
	local info = TweenInfo.new(instant and 0 or 1.2, Enum.EasingStyle.Sine)
	local lp = table.clone(look.Lighting)
	-- booleans don't tween
	Lighting.GlobalShadows = lp.GlobalShadows
	lp.GlobalShadows = nil
	TweenService:Create(Lighting, info, lp):Play()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then
		atm = Instance.new("Atmosphere")
		atm.Parent = Lighting
	end
	TweenService:Create(atm :: Atmosphere, info, look.Atmosphere):Play()
	TweenService:Create(effect("ColorCorrectionEffect", "DinoColorGrade"), info, look.Grade):Play()
	TweenService:Create(effect("BloomEffect", "DinoBloom"), info, look.Bloom):Play()
	TweenService:Create(effect("SunRaysEffect", "DinoSunRays"), info, look.SunRays):Play()
	TweenService:Create(effect("ColorCorrectionEffect", "DinoWeatherGrade"), info, weatherGrade()):Play()
	-- the place's stock depth-of-field blurs normal play; cinematics add their own when they want it
	if not stockCleared then
		stockCleared = true
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("DepthOfFieldEffect") then d.Enabled = false end
		end
	end
end

-- WeatherView: the weather now. apply: put it on the light now, over `time` seconds (WeatherView holds off while a
-- cutscene owns the light; the scene puts Zone.Look() back when it's done, weather included)
function Zone.SetWeather(mix: { Dark: number, Fog: number, Wet: number }, apply: boolean, time: number?)
	weather.Dark = math.clamp(tonumber(mix.Dark) or 0, 0, 1)
	weather.Fog = math.clamp(tonumber(mix.Fog) or 0, 0, 1)
	weather.Wet = math.clamp(tonumber(mix.Wet) or 0, 0, 1)
	if not apply then return end
	local base = Zone.Current and LOOKS[Zone.Current]
	if not base then return end
	local look = blend(base)
	local info = TweenInfo.new(time or 1, Enum.EasingStyle.Sine)
	local lp = table.clone(look.Lighting)
	lp.GlobalShadows = nil
	TweenService:Create(Lighting, info, lp):Play()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then TweenService:Create(atm, info, look.Atmosphere):Play() end
	TweenService:Create(effect("SunRaysEffect", "DinoSunRays"), info, look.SunRays):Play()
	TweenService:Create(effect("ColorCorrectionEffect", "DinoWeatherGrade"), info, weatherGrade()):Play()
end

return Zone
