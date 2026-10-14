# Dawn Desert map (zone `DawnDesert`): staging for the lead

Generator: `tools/gen/dawnDesert.js` exports `{ buildDawnDesert, DD_ORIGIN, QC }`. Origin is (-2100, 0, -900).
The play area is local x ±440 and z -340..400. With the skyline it covers world x -2750..-1450 and z -1550..-250.
build.js already builds it. A full (non-preview) build writes `src/Workspace/DawnDesert.rbxmx` and
`src/ReplicatedStorage/DinoExpedition/Routes/DawnDesert.luau`.

Route: SUNRISE ROAD → fork: RED DUNES | PAINTED WASH → STONE FOREST (sections BONE WASH, CREST ROCKS) →
fork: OASIS RUN | MESA RIM (jumps the slot canyon) → HOMESTRETCH → Return Portal. The four variants are about
1970 to 2026 studs long.

Nests:
- 1 Coelophysis OASIS PACK (Pack) is on Oasis Run, so the Mesa Rim branch doesn't pass it. Giant Plains' Tall Grove works the same way.
- 2 Plateosaurus TALL CYCADS (Herd) is on the Stone Forest stretch.
- 3 Dilophosaurus CREST ROCKS (Brute pair) is on the Stone Forest stretch.

Ruler den: Postosuchus BONE WASH, with DenCenter, DenLedge1..6, Throne and FinalArena (STUMP CIRCLE).

## 1. default.project.json (Workspace)
```json
"DawnDesert": {
  "$path": "src/Workspace/DawnDesert.rbxmx"
},
```
Npcs.luau already lists `Workspace:FindFirstChild("DawnDesert")`. The Ranger spot is `NpcSpot_Ranger` beside the arrival camp.

## 2. Zone.luau: LOOKS.DawnDesert
Triassic sunrise: low orange sun on the horizon, a purple-pink sky and a warm pink-violet haze. Bloom is kept
gentle on purpose (high threshold), because the user doesn't like too much glow.
```lua
	-- Triassic sunrise over the painted desert: low orange sun, purple-pink sky, warm hazy shimmer (2026-10-12)
	DawnDesert = {
		Lighting = {
			ClockTime = 6.75, GeographicLatitude = 22, Brightness = 2.3, ExposureCompensation = -0.02,
			OutdoorAmbient = Color3.fromRGB(150, 116, 132), Ambient = Color3.fromRGB(66, 50, 64),
			EnvironmentDiffuseScale = 0.55, EnvironmentSpecularScale = 0.3, ShadowSoftness = 0.2, GlobalShadows = true,
			ColorShift_Top = Color3.fromRGB(255, 190, 150), ColorShift_Bottom = Color3.fromRGB(60, 22, 52),
		},
		Atmosphere = { Density = 0.3, Offset = 0.12, Color = Color3.fromRGB(240, 176, 176), Decay = Color3.fromRGB(150, 92, 156), Glare = 0.4, Haze = 1.1 },
		Grade = { Saturation = 0.3, Contrast = 0.15, Brightness = 0.01, TintColor = Color3.fromRGB(255, 234, 228) },
		Bloom = { Intensity = 0.4, Size = 26, Threshold = 1.75 }, -- gentle: neon reads as lit, not blown out
		SunRays = { Intensity = 0.12, Spread = 0.8 },
	},
```
I didn't check the sun direction in Studio. EstShot1 looks north-east from above the arrival over the
Teepees. If the sun at ClockTime 6.75 ends up behind the camera, the shot still works. If you want the sun in
frame, nudge `GeographicLatitude`.

## 3. Ambience.luau: LOOK.DawnDesert
```lua
	DawnDesert = { Motes = Color3.fromRGB(255, 196, 150), MoteRate = 9, Leaves = { Color3.fromRGB(90, 176, 70), Color3.fromRGB(122, 196, 84) }, LeafRate = 0.8,
		Butterflies = 3, Wings = { Color3.fromRGB(70, 210, 200), Color3.fromRGB(120, 150, 255) }, Birds = 5 },
```
The motes are warm dust. The few "butterflies" are meant as teal/blue dragonflies, since butterflies and birds
didn't exist yet in the Triassic. The Birds read as early pterosaurs.

The leaves are fern fronds and should only drift near the oases. The map has `Weather/FrondZone` markers (Parts
with a `Radius` attribute) around the oasis and the springs. A cheap gate, if you want it:
```lua
-- in Ambience, when spawning leaves for DawnDesert:
local function inFrondZone(p: Vector3): boolean
	local zm = workspace:FindFirstChild("DawnDesert")
	local w = zm and zm:FindFirstChild("Weather", true)
	if not w then return true end
	for _, m in ipairs(w:GetChildren()) do
		if m.Name == "FrondZone" and (m.Position - p).Magnitude < (m:GetAttribute("Radius") or 50) then return true end
	end
	return false
end
```
Without the gate, the low LeafRate (0.8) keeps it to a few fronds everywhere, which is also fine.

## 4. Markers that need runtime code
- `Weather/DustDevil` (6 parts, attribute `Wander`): `CampView.startDevils()` only looks in GiantPlains.
  Loop it over `{ "GiantPlains", "DawnDesert" }` so these wander too. Each is a particle column on its own, so
  they still look fine standing still.
- `Weather/HeatShimmer` (4), `Weather/QuartzGlints` (4), `QuartzBridge/BridgeGlint`, `BoneWash/WashDust`: these
  are self-contained ParticleEmitters and need no code.
- `Weather/FrondZone`: optional, see above.
- Water is decorative and shallow, not Terrain water. `OasisWater`, `PoolWater` and `CanyonWater` are tagged
  `DinoWater` with surfaces at about y 0.55-0.6. The route has no water stretches, so the route data has no
  `Water`/`WaterY` and the boss has no `Water` flag.
- Two small ribbon waterfalls (`Oasis/Waterfall`, E.waterfall) have `WaterStreak` parts, if CampView animates those outside camp.
- Cinematics:
  - EstShot1: sunrise over the painted hills and the Teepees.
  - EstShot2: the Stone Forest. The look point is beside the TALL CYCADS nest, so the herd shot gets Plateosaurus.
  - EstShot3: the oasis. It looks from the Blue Mesa's side to the OASIS PACK sandbar, so the walk-across shot gets Coelophysis.
  - EstShot4: the Bone Wash from above the road.
- Den: `DenCenter` (RouteS/RouteX=80/Variant=1), `DenLedge1..6`, and `Throne` (a raised cracked-mud dais under
  a giant phytosaur skull that juts out of the bank). The den is a bowl of radius 44 with its mouth facing the
  road (north). The ruler glimpse camera has open floor between Throne and DenCenter. Three `MudWallow` discs
  (dark, glossy) are where the Postosuchus can lie in ambush, at den-local (-20,-6), (16,12) and (-6,18). There
  are no markers for them; add some if MudAmbush wants spots.
- `FinalArena` is the STUMP CIRCLE (RouteX -8, the road side away from the ring), 180 studs on from the den along the Stone Forest.

## 5. Look and landmarks
Every hill, teepee, cut bank and mesa uses one global strata table (bandAt(y)), so the purple, white and red
stripes run unbroken from hill to hill.

Landmarks:
- The Great Teepees: three banded cones up to 84 tall in the middle of the dune sea.
- The Sentinels: a teepee gate on Sunrise Road.
- The Quartz Bridge: a petrified trunk the road drives under, 17 up.
- The Old Log.
- The Blue Mesa with two spring falls into the braided oasis.
- The slot canyon jump.
- Bone Wash.
- Stump Circle.
- Crest Rocks (paired red fins).

There are barchan dunes over the open sand, and red mesas and buttes plus a hazy violet range on the skyline.
