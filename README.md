# Dino Expedition — vehicles & dinosaurs

Rojo project (`rojo serve` on port **34900**). All geometry is generated, not hand-placed:

```
node tools/gen/build.js        # regenerate every model, profile and shot list into src/
```

| Path | What |
| --- | --- |
| `tools/gen/vehicles/*.js` | Rookie Ranger, Raptor Runner, Titan Transport (part-by-part) |
| `tools/gen/dinos/*.js` | Velociraptor, T. rex: rigs (Motor6D bones) + geometry |
| `tools/gen/anim/*.js` | **Source of truth** for animation profiles and cinematic shot lists → generated `Profiles/*.luau`, `Shots.luau` |
| `tools/gen/showcase.js` | Display platforms, pedestals/prompts, cinematic stage, decor, 12-slot layout |
| `tools/preview/` | three.js QC viewer: `index.html?focus=TyrannosaurusRex`, cinematic contact sheets `cine.html?file=out/cine_TyrannosaurusRex_Emerge.json` |
| `src/ReplicatedStorage/DinoExpedition/` | Templates + DinosaurAnimations / DinosaurVFX / DinosaurCinematics |

Animations are procedural (client-side `Motor6D.Transform`), so they play in **Play mode**, not edit mode.
`tools/gen/anim/runtime.js` mirrors the Luau evaluation so cinematics can be framed in the preview — keep them in sync.

## The game (vertical slice)

**Core loop:** Base Camp → take your jeep from the GARAGE → drive into the TIME GATE (warp cutscene) →
Fern Valley route (steer the full road width, pick forks, boost, dodge) → slow down at a nest and hold the
prompt to grab an egg → the parent chases (raptor pack lunges, Triceratops charge, Parasaurolophus stampede) →
reach the RETURN PORTAL → eggs go into your incubators → HATCH (reveal cutscene) → babies earn coins into your
CASH PAD → buy the Raptor Runner / Titan / incubator slots at the MOTOR POOL.

| Where | What |
|---|---|
| `tools/gen/hub.js` | Base Camp map (8 plots, plaza, Time Gate, cliffs, ridge) → `src/Workspace/BaseCamp.rbxmx` |
| `tools/gen/fernValley.js`, `route.js` | Fern Valley map + route data → `FernValley.rbxmx`, `Routes/FernValley.luau` |
| `tools/gen/eggs.js`, `babies.js`, `vehicleTemplate.js` | egg models, baby dinos, drivable vehicle templates |
| `src/ServerScriptService/Game` | Data (DataStore), Plots, Vehicles, Expedition, Chase AI, Hatchery, Shop |
| `src/StarterPlayer/.../Game` | Drive, Warp, ExpeditionView, CampView, Hatch, Zone, UI (Kit, HUD, Panels) |
| `src/ReplicatedStorage/DinoExpedition/Game/Config.luau` | every balance number (mirrors the GDD) |

Rebuild generated content: `node tools/gen/build.js`. Type-check:
`~/.aftman/tool-storage/JohnnyMorganz/luau-lsp/1.69.0/luau-lsp analyze --definitions=tools/types/roblox-globals.d.luau --sourcemap=sourcemap.json src`.
Saving needs *Game Settings → Security → Enable Studio Access to API Services* in Studio; without it the game
runs on a temporary profile.
