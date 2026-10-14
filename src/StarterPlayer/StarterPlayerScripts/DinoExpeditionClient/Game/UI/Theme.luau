--[[
	Theme — DINO EXPEDITION UI style guide: dark jungle green foundation, Expedition Yellow as the accent,
	thick dark-green outlines, strong drop shadows, Press Start 2P for every piece of text (white, yellow, lime).
]]

local Theme = {}

-- big chunky rounded display type for titles, buttons and numbers; the pixel font is our signature for small tags
Theme.Display = Font.new("rbxasset://fonts/families/FredokaOne.json")
Theme.Font = Font.new("rbxasset://fonts/families/PressStart2P.json")
Theme.Pixel = Theme.Font

local rgb = Color3.fromRGB
local hex = Color3.fromHex
Theme.C = {
	-- foundation
	Ink = hex("101A13"), -- outline
	Shadow = hex("101B13"),
	Night = hex("101B13"),
	Forest = hex("142E20"), -- dark forest: window bodies
	ForestHi = hex("1D3F2B"),
	Jungle = hex("245C38"), JungleHi = hex("3A8250"), JungleLo = hex("17402A"),
	Panel = hex("245C38"), PanelHi = hex("3A8250"), PanelLo = hex("142E20"),
	InkSoft = hex("0E2216"), -- recessed slots / tracks
	-- text
	Cream = hex("FFF8E7"),
	White = rgb(255, 255, 255),
	Muted = hex("A9D3A0"), -- secondary text on green
	-- accents
	Yellow = hex("FFD447"), YellowHi = hex("FFE98A"), YellowLo = hex("D9A21F"),
	Orange = hex("FF9633"), OrangeHi = hex("FFBE73"), OrangeLo = hex("D96A12"),
	Lime = hex("A8ED48"), LimeHi = hex("D2FF8C"), LimeLo = hex("6FB322"),
	Red = hex("FF5252"), RedHi = hex("FF8C8C"), RedLo = hex("C42E2E"),
	Blue = hex("48A8FF"), BlueHi = hex("8CCBFF"), BlueLo = hex("2272C9"),
	Teal = rgb(47, 205, 180), TealHi = rgb(130, 240, 222), TealLo = rgb(22, 140, 122),
	Purple = hex("AD66FF"), PurpleHi = hex("CFA1FF"), PurpleLo = hex("7A38CC"),
	Gold = hex("FFD447"),
	Grey = hex("A7ADB5"), GreyHi = hex("CDD2D8"), GreyLo = hex("737A84"),
	Slate = hex("2E6B45"), SlateHi = hex("45905E"), SlateLo = hex("17402A"),
	-- legacy names (light surfaces are gone: these now resolve to the green panel family)
	Paper = hex("142E20"), PaperLo = hex("0B1C12"), Card = hex("2A6B41"), CardLo = hex("17402A"),
}

-- rarity colors (Secret animates a rainbow on top of its base)
Theme.Rarity = {
	Common = hex("A7ADB5"), Uncommon = hex("66D86B"), Rare = hex("48A8FF"), Epic = hex("AD66FF"),
	Legendary = hex("FFD447"), Mythic = hex("FF5252"), Secret = hex("FFFFFF"),
}

-- named swatches: { base, hi, lo }
local C = Theme.C
Theme.Swatch = {
	Yellow = { C.Yellow, C.YellowHi, C.YellowLo },
	Jungle = { C.Jungle, C.JungleHi, C.JungleLo },
	Lime = { C.Lime, C.LimeHi, C.LimeLo },
	Green = { C.Lime, C.LimeHi, C.LimeLo },
	Orange = { C.Orange, C.OrangeHi, C.OrangeLo },
	Red = { C.Red, C.RedHi, C.RedLo },
	Blue = { C.Blue, C.BlueHi, C.BlueLo },
	Teal = { C.Teal, C.TealHi, C.TealLo },
	Purple = { C.Purple, C.PurpleHi, C.PurpleLo },
	Grey = { C.Grey, C.GreyHi, C.GreyLo },
	Panel = { C.Panel, C.PanelHi, C.PanelLo },
	Slate = { C.Slate, C.SlateHi, C.SlateLo },
	Paper = { C.Forest, C.ForestHi, C.Shadow },
	Forest = { C.Forest, C.ForestHi, C.Shadow },
	Card = { C.Card, C.JungleHi, C.CardLo },
	Ink = { C.Forest, C.ForestHi, C.Shadow },
}

function Theme.Swatchify(color: Color3)
	return { color, color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.32) }
end

return Theme
