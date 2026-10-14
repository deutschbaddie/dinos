# Frost Forest — map staging for the lead (2026-10-12)

Generator: `tools/gen/frostForest.js` → `buildFrostForest()`, `FF_ORIGIN = [2100, 0, -2600]`, `QC = { decor, ground }`.
build.js already builds it (writes `src/Workspace/FrostForest.rbxmx` + `src/ReplicatedStorage/DinoExpedition/Routes/FrostForest.luau`
on a full build, `tools/preview/out/frost.json` on `--preview-only`).
Zone id `FrostForest`, Name `FROST FOREST`, Era `125,000,000 BC`, Year `-125000000`. ~20.1k parts. World footprint
(skyline included) x 1507..2744, z -3252..-2019, y up to ~291 (volcano plume host).

Route: Pine Road → fork: **Frozen Lake** (ice road straight across the lake; left, variant choice 1) | **Ash Ridge**
(black ash ridge, up to +14) → Ginkgo Hollow → fork: **Hot Springs** (left) | **Fallen Giants** (you drive under a log
bridge) → Homestretch (Frost Stones final stand) → Return Portal. Variant lengths 1687 / 1681 / 1666 / 1660.

Sites: 1 Microraptor GLIDER PINES (Pine Road, Pack) · 2 Psittacosaurus FERN HOLLOW (Ginkgo Hollow, Herd) ·
3 Compy LOG WARREN (Fallen Giants, Pack). Ruler den: WHITE LAKE (Yutyrannus) off the right of Ginkgo Hollow
(DenCenter RouteS 890, RouteX 84), DenLedge1..6, Throne (black basalt dais under a frozen waterfall), FinalArena on the
Homestretch (FROST STONES: a ring of basalt columns round a cracked ice pool).

## Wiring
1. `default.project.json` → Workspace:
   ```json
   "FrostForest": { "$path": "src/Workspace/FrostForest.rbxmx" },
   ```
2. `Npcs.luau` zone list already includes `Workspace:FindFirstChild("FrostForest")` (Ranger: `NpcSpot_Ranger` beside
   the arrival camp).
3. Zone.luau `LOOKS.FrostForest` + Ambience.luau `LOOK.FrostForest` (below).
4. Optional runtime hooks for markers the map carries (all static and harmless if ignored):
   - `PerchSpot1..4` (BaseParts at the tips of the long boughs over the Glider Pines nest; attrs `Perch = true`,
     `NestId = 1`) — where the Microraptor pack can sit / dive-strike from (species staging asks for "perched in
     trees").
   - `Weather` folder: `Snowfall` (7 hosts, static falling-snow emitters over the open stretches), `AshFall` (3 over the
     ash ridge), `LakeMist` (low dawn mist over the frozen lake). Particle emitters: work with no code.
   - Steam: `SteamHost` emitters at the hot springs, `Fumarole` vents on the ash ridge, `Crater` smoke + ash plume on
     the volcano, `LakeSnowfall` over the White Lake. All plain ParticleEmitters, no code needed.
   - Spring water parts are tagged `DinoWater` (like GP's oasis) so drink/splash code finds them.
   - Walkable ice: `IceSheet` (Frozen Lake), `LakeIce` (White Lake floor, Frost Stones pool), Material Ice: if the
     lead wants slippery driving on the ice road, the road tiles there are Material Ice too (`Road` parts) — a Drive
     grip multiplier keyed off `Enum.Material.Ice` under the wheels would make the lake crossing feel distinct.
5. Bosses: the den is a plain ground arena (no water), works with the stock Bosses.Start lookup. `Throne` top is
   y ≈ 4.5 above the ice; the dais faces DenCenter.

## Zone.luau — LOOKS.FrostForest
Snowy blue dawn: a low cool sun just up, soft shadows, pale blue-white haze, crisp (not glowy: same gentle bloom as
the others, lower sun-rays, no extra exposure).
```lua
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
```
Also extend the header comment: `FrostForest: snowy blue dawn.`

## Ambience.luau — LOOK.FrostForest
Snow as the motes, a few golden ginkgo leaves + grey ash flakes + white snow clumps as the tumbling "leaves", no
butterflies (it's winter), a couple of birds.
```lua
	FrostForest = { Motes = Color3.fromRGB(248, 252, 255), MoteRate = 22, MoteFall = true, Leaves = { Color3.fromRGB(255, 196, 40), Color3.fromRGB(240, 168, 30), Color3.fromRGB(70, 68, 76), Color3.fromRGB(245, 248, 255) }, LeafRate = 2.5,
		Butterflies = 0, Wings = { Color3.fromRGB(255, 255, 255) }, Birds = 3 },
```
`MoteFall` is a new optional flag: the stock motes are glowing sparkles drifting UP (LightEmission 1, accel +0.15) —
right for pollen, wrong for snow. Suggested 6-line change in `setZone` (after `motes.Rate = ...`):
```lua
	-- snow: falling, matte, a touch bigger; everything else keeps the glowing drift
	local fall = (look :: any).MoteFall == true
	motes.Acceleration = fall and Vector3.new(0.6, -1.4, 0.3) or Vector3.new(0, 0.15, 0)
	motes.LightEmission = fall and 0 or 1
	motes.Speed = fall and NumberRange.new(1, 2) or NumberRange.new(0.3, 1)
	motes.Size = fall and NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.1, 0.32), NumberSequenceKeypoint.new(0.9, 0.28), NumberSequenceKeypoint.new(1, 0) })
		or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 0) })
```
(The anchor box sits 6 studs above the camera and is 34 tall, so falling flakes pass through view.) Leaves already
tumble down; the gold/ash/white mix reads as ginkgo leaves, ash flakes and snow clumps.

## Cinematics (Cinematics folder)
- EstShot1: high over the Pine Road looking north: frozen lake, black ash ridge, the snow-capped smoking volcano.
- EstShot2: Ginkgo Hollow, gold-on-white, looking at FERN HOLLOW (Psittacosaurus herd shot picks it).
- EstShot3: down among the GLIDER PINES (Microraptor walk-across shot picks it).
- EstShot4: the WHITE LAKE from above its mouth: cracked ice, dais, frozen falls (used by any 4th-shot code).

## Look summary (unique vs the other eras)
White studded snowfields, dark snow-laden pines (tiers with white snow rings), golden ginkgo groves on snow with gold
leaf litter (the hollow, the lake's west shore, scattered accents), the Elder Ginkgo landmark, a cracked blue frozen
lake (white crack web, deep-blue windows, pressure ridges, breathing holes, a red ice-fishing hut, a pine islet),
black ash ridge with basalt columns, steaming vents, dull ember cracks and charred snags, travertine hot-spring
terraces (cream/orange/turquoise, moss ring), giant fallen trunks + a log bridge over the road, gabled white peaks and
a broad black volcano with a white cap and smoke on the skyline. Roads: packed gravel with snow-pole markers and
ploughed berms, black ash on the ridge, a pale ice lane with orange flag poles across the lake.
