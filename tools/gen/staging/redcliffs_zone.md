# RED CLIFFS: what the lead needs to merge

Generator: `tools/gen/redCliffs.js` (`buildRedCliffs`, `RC_ORIGIN = [2100, 0, -900]`, `QC`). build.js already picks it up.
`node tools/gen/build.js --preview-only` prints: terrain about 5.9k parts, road clearance `blocking 0`,
`RedCliffs QC: pruned ~43 clipping decor, 0 structure clips`, `RedCliffs parts=~16.7k`, variants about 1806 to 1830 studs.

## 1. default.project.json

```json
"RedCliffs": { "$path": "src/Workspace/RedCliffs.rbxmx" }
```
(The Routes file `src/ReplicatedStorage/DinoExpedition/Routes/RedCliffs.luau` is written by a full build, alongside the rbxmx.)

## 2. Zone.luau: `LOOKS.RedCliffs`

The Gobi at golden dusk: a low orange sun, long raking shadows across the strata, red-ochre haze. The colours stay
saturated but bloom is kept low so nothing glows. The ochre haze also softens the translucent sandstorm wall on the
east horizon.

```lua
	-- golden dusk in the Gobi: low orange sun, long shadows across the red strata, red-ochre haze (not glowy)
	RedCliffs = {
		Lighting = {
			ClockTime = 17.45, GeographicLatitude = 28, Brightness = 2.35, ExposureCompensation = -0.08,
			OutdoorAmbient = Color3.fromRGB(150, 112, 100), Ambient = Color3.fromRGB(72, 50, 46),
			EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.25, ShadowSoftness = 0.12, GlobalShadows = true,
			ColorShift_Top = Color3.fromRGB(255, 198, 142), ColorShift_Bottom = Color3.fromRGB(56, 18, 8),
		},
		Atmosphere = { Density = 0.28, Offset = 0.12, Color = Color3.fromRGB(232, 178, 132), Decay = Color3.fromRGB(196, 98, 62), Glare = 0.35, Haze = 1.0 },
		Grade = { Saturation = 0.3, Contrast = 0.18, Brightness = 0, TintColor = Color3.fromRGB(255, 232, 212) },
		Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.8 }, -- low: the warm light does the work, neon stays crisp
		SunRays = { Intensity = 0.1, Spread = 0.7 },
	},
```

## 3. Ambience.luau: `LOOK.RedCliffs`

Warm sand motes and a few dry saxaul and olive leaves. There are almost no butterflies (desert) and only a few birds.

```lua
	-- desert dusk: warm sand motes drifting, a few dry saxaul / olive leaves, hardly any butterflies
	RedCliffs = { Motes = Color3.fromRGB(255, 196, 136), MoteRate = 11, Leaves = { Color3.fromRGB(168, 172, 90), Color3.fromRGB(214, 168, 108), Color3.fromRGB(196, 120, 80) }, LeafRate = 1,
		Butterflies = 2, Wings = { Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 240, 210) }, Birds = 5 },
```

## 4. CampView.luau: dust devils (optional, one line)

The map carries `RedCliffs/Weather/DustDevil` parts (7 of them) with the same `Wander` attribute schema as Giant
Plains. `startDevils()` currently only reads `GiantPlains`. To make them wander in Red Cliffs too:

```lua
local function startDevils()
	for _, zoneName in ipairs({ "GiantPlains", "RedCliffs" }) do
		local zm = Workspace:FindFirstChild(zoneName)
		local wf = zm and zm:FindFirstChild("Weather", true)
		if wf then
			for _, p in ipairs(wf:GetChildren()) do
				if p:IsA("BasePart") and p.Name == "DustDevil" then
					table.insert(devils, { Part = p, Home = p.Position, R = p:GetAttribute("Wander") or 18, Phase = math.random() * 10 })
				end
			end
		end
	end
end
```
If this isn't merged, the devils still swirl in place, because the particles live on the parts.
`Weather/SandDrift` (low sand blowing off dune crests) and `SandstormWall/StormEmitter` are plain particle hosts. They
need no code.

## 5. Markers and data the runtime reads (all generated)

- Zone model `RedCliffs` (attr `Zone = "RedCliffs"`, `Length`). Walkable folders are `Ground`, `Hills` (the terrain:
  `Strata` / `CliffTop` / `Ledge` / `DuneTop` / `DuneSide`) and `Roads`.
- Route data: `Zone = "RedCliffs"`, `Name = "RED CLIFFS"`, `Era = "75,000,000 BC"`, `Year = -75000000`, 4 variants.
  - Fork A labels are `{ "DUNE SEA", "EGG LEDGES" }`.
  - Fork B labels are `{ "RUNNER FLATS", "HOODOO MAZE" }`.
  - Sections: DUNE ROAD, THE GREAT ARCH, DUNE SEA, EGG LEDGES, DRY WASH, FOSSIL WALL, HOODOO MAZE, RUNNER FLATS,
    HOMESTRETCH.
  - Features include one `Jump` (Dune Sea), one `Charge` (Dry Wash) and one `Stampede` (Runner Flats), plus coins,
    boosts, repairs and darts.
- Nests (`Nest_<Species>` models, tag `ExpeditionNest`, `NestCore` + `GrabPrompt`, `GuardSpot1..3`):

  | NestId | Species | Guard | Label | Where |
  | --- | --- | --- | --- | --- |
  | 1 | Oviraptor | Pack | THIEF'S LEDGE | Egg Ledges branch, in a notch in the plateau cliff at shelf height, about y 14.7 |
  | 2 | Protoceratops | Herd | DUNE BURROWS | Dry Wash trunk, in front of a burrowed sand bank |
  | 3 | Gallimimus | Herd | RUNNER FLATS | Runner Flats branch, on the open clay pan |

  Nest 1 sits on an elevated shelf (`Pos.Y` ≈ 14.7), not at ground level. Every variant passes at least Dune Burrows.
- Ruler den, **SCYTHE GROVE**. It is a green spring grove in a box canyon under the plateau, off the right of the Dry Wash.
  - `DenCenter`: `RouteS` ≈ 999, `RouteX` ≈ 78.7, `Variant` 1.
  - `Throne`: a mossy slab under a cliff overhang, with a waterfall and pool beside it.
  - `DenLedge1..6`: climbable sandstone stacks round the walls.
  - `FinalArena`: **THE CLAW RING** on the Homestretch (`RouteS` ≈ 1656, `RouteX` 8). It is an open clay pan ringed by
    sandstone fins with claw gashes.
- The grove's tall conifers are Models named `GroveConifer`, tagged **`ScytheTree`**. If the Therizinosaurus session
  wants a "rake the trees" beat (BreakProp / FellTrees on real trees), it can find them by that tag. Nothing requires it.
- `DinoWater` tag: the grove's `PoolWater` and the `GroveStream` segments.
  The `GroveFalls` waterfall uses `E.waterfall`, so it has the usual `Waterfall` / `WaterStreak` tags.
- `Cinematics/EstShot1..4`:
  1. Over the arrival, through the Great Arch to the plateau cliffs and the sandstorm (the title crane).
  2. A Gallimimus herd on the Runner Flats with the sandstorm wall behind (looks at nest 3).
  3. A Protoceratops by the Dune Burrows with the Fighting Dinosaurs wall behind (looks at nest 2).
  4. Into the Scythe Grove from the wash (unused by the current Establish, but framed).
- `NpcSpot_Ranger` at the arrival camp. Npcs.luau already lists `RedCliffs`.

## 6. Config (the lead's call)

The era entry needs the following:
- **Sites**: Nest 1 / Oviraptor / Pack, Nest 2 / Protoceratops / Herd, Nest 3 / Gallimimus / Herd.
- **Boss**: Therizinosaurus `SCYTHE GROVE`, Era `RedCliffs`.
- **Colour**: a warm red-orange, e.g. `Color3.fromRGB(226, 98, 52)`.
