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
		-- retire the place's stock effect of this kind so ours is the only one
		for _, other in ipairs(Lighting:GetChildren()) do
			if other.ClassName == class and other.Name ~= name then (other :: any).Enabled = false end
		end
		e = Instance.new(class)
		e.Name = name
		e.Parent = Lighting
	end
	return e :: Instance
end

-- the look the current zone is heading to (a cutscene that dressed the light up puts it back to THIS, never to a
-- snapshot taken mid-tween)
function Zone.Look(): any
	return Zone.Current and LOOKS[Zone.Current] or nil
end

local stockCleared = false
function Zone.Apply(zone: string, instant: boolean?)
	local look = LOOKS[zone]
	if not look then return end
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
	-- the place's stock depth-of-field blurs normal play; cinematics add their own when they want it
	if not stockCleared then
		stockCleared = true
		for _, d in ipairs(Lighting:GetChildren()) do
			if d:IsA("DepthOfFieldEffect") then d.Enabled = false end
		end
	end
end

return Zone
