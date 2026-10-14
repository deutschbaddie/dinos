# Frost Forest — staging for the lead (2026-10-12)

Group `frostforest`, zone `FrostForest` (125,000,000 BC). Everything below is ready to paste; nothing here is wired yet.

## Files (all new, owned by this group)
- tools/gen/dinos/{microraptor,psittacosaurus,compy,yutyrannus}.js — rigs
- tools/gen/anim/{microraptor,psittacosaurus,compy,yutyrannus}.js — animation profiles
- tools/gen/anim/shots_frostforest.js — signature shot lists: MicroShadowGlide, PsittaHideSqueak, CompySwarm, YutyBlizzardKing
- tools/gen/showcase_frostforest.js — QC stages on row z = -275 (x -62 / -38 / -14 / 36) with snowy props:
  Perch + Stump (Microraptor), Undergrowth + Twig (Psittacosaurus), HollowLog (Compy), SnowPines + ThinIce (Yutyrannus)
- src/ReplicatedStorage/DinoExpedition/DinosaurVFX/Extra_FrostForest.luau — new VFX events (below)
- src/StarterPlayer/StarterPlayerScripts/DinoExpeditionClient/Game/Reveals/FrostForest.luau — reveal beats canopy / eyes / tracks / whiteout

| Species | parts | joints | L x W x H (studs) | Signature (Intro) | Shot key | Reveal beat |
| --- | --- | --- | --- | --- | --- | --- |
| Microraptor | 140 | 21 | 5.1 x 1.0 x 2.3 | ShadowGlide | MicroShadowGlide | canopy (Act WingDisplay) |
| Psittacosaurus | 132 | 24 | 6.8 x 2.0 x 3.2 | HideAndSqueak | PsittaHideSqueak | eyes |
| Compy | 99 | 23 | 3.7 x 0.6 x 1.5 | Swarm | CompySwarm | tracks |
| Yutyrannus (ruler) | 218 | 25 | 28.8 x 7.2 x 13.0 | BlizzardKing | YutyBlizzardKing | whiteout (gallery) |

## New VFX events (DinosaurVFX.Extra, Extra_FrostForest.luau)
Positions given as `{ x, y, z }` are studs in the creature's RootPart frame (scaled with the model).
- `SnowPuff { At, Scale, Fall }` powder snow at an attachment; Fall = it drops off a branch.
- `Iridesce (dur)` the Microraptor sheen: teal->blue->violet shimmer sweeps across parts named Sheen / Wing* / TailFan / LegFeather.
- `PropFallback { Prop, Kind, At, Dur }` if the stage prop is missing (era site, reveal), builds a temporary Branch /
  Stump / Ferns / HollowLog for Dur s. This is what makes the signatures work away from the showcase stage.
- `RustleProp { Prop }` a prop shivers and sheds snow (falls back to snow off the dino).
- `CompySwarm { Count, From, Radius, ChirpIn }` client-side stand-in compies (clones with the dinosaur tag removed,
  no Highlight) pour out of `From`, fan out on an arc toward the camera, chirp together after ChirpIn s, then scatter
  and fade (self-destroy <= ChirpIn + 5 s).
- `Snatch { At }` a grab flash at the mouth (stolen dart / scavenged pickup).
- `BreathPlume { Scale, Roar }` frosty breath; Roar = a freezing ice-blue cone with crystals + ring.
- `SnowShake { Scale, At }` a snow cloud shaken off the whole body (or one attachment).
- `Whiteout { Dur, At }` a wall of driving snow around the creature for Dur s.
- `IceCrack { At, Scale, Ring }` glowing jagged ice cracks racing out from a foot, shards, cold ring.
- `PineDump { Prop }` each pine in the prop shivers and drops its SnowCap parts as falling snow (caps restore after
  6.5 s); with no prop, snow falls all round the creature.

## Notes for wiring (engine work)
- **Compy swarm count**: the site wants ~12 compies. Suggest a new site Kind `"Swarm"` (or `"Pack"` with Count = 12)
  with very low Calm each (they are 1.5 studs tall; Combat Scale 1.3). The signature/reveal swarm is VFX-only
  (CompySwarm), so the site itself can spawn fewer real ones (e.g. 6) if 12 server dinos is too heavy.
- **Microraptor** Kind `"Pack"` Count 3 ("flyer pack"). Extra actions for gameplay: `Glide` (held glide pose, the engine
  moves the root), `Climb` (loop, body pitched up a trunk), `DiveStrike` (glide strike from a perch: a Dash line),
  `WingDisplay` (2.4 s flourish). Perched-in-trees idle needs the site to place them up in trees and play Glide/DiveStrike
  down at the player; the chase action glides in and drops onto the rover (latch like the raptor).
- **Psittacosaurus** Kind `"Herd"` (lead + 3-4). `HerdResponse` exists (DinosaurVFX.HerdCall plays it on herd-mates);
  the signature's HerdCall rings come off the tail quills (`VFX_Crest` sits on the quill bone). `Hide` is a looping
  tucked-in-the-ferns pose for the sneak phase / camo buddy. The tail-quill bones are `Quills1`, `Quills2`.
- **Yutyrannus**: `Listen` (whiteout phase: head cocked, listening, then snaps toward a sound — pair with the
  `Whiteout` event and drive awareness by noise only), `IceStomp` (IceCrack ring: thin-ice hazard), `FrostRoar`
  (frost cone; also the buddy move), `BreathPlume` is cheap enough to fire on idle every few seconds in the cold.
- **Buddy roles needing engine code**: Microraptor GLIDE (player glide off ledges + dodge becomes an air dash),
  Psittacosaurus CAMO (multiply Sneak sight/hear fill rates by 0.6 while it's your buddy), Compy SCAVENGER (instant
  reload every 10 s + auto-grab coins/pickups in range, plays `Scavenge` / `Snatch`), Yutyrannus FROST ROAR (slow every
  dino within Area for 4 s; plays `FrostRoar`). Fields below use new keys (`Glide`, `Camo`, `Reload`, `Grab`, `Slow`).
- Compy `DartSnatch` attack: the engine should take one dart from the player's magazine on hit (the action fires
  `Snatch` at the mouth at 0.84 s).
- Psittacosaurus is the cute starter of the era: low Calm, low damage, forgiving telegraphs.
- BIG (EraView gallery): Yutyrannus. No swimmers.

## Config.Species
```lua
	Psittacosaurus = { Name = "PSITTACOSAURUS", Era = "FrostForest", Income = 30, KG = { 10, 45 }, Color = Color3.fromRGB(168, 100, 46) },
	Compy = { Name = "COMPY", Era = "FrostForest", Income = 38, KG = { 2, 9 }, Color = Color3.fromRGB(216, 118, 44) },
	Microraptor = { Name = "MICRORAPTOR", Era = "FrostForest", Income = 60, KG = { 1, 6 }, Color = Color3.fromRGB(46, 197, 214) },
	Yutyrannus = { Name = "YUTYRANNUS", Era = "FrostForest", Income = 160, KG = { 300, 1400 }, Color = Color3.fromRGB(143, 210, 245) },
```

## Config.Eras sites (suggested, for the FrostForest era entry)
```lua
		Sites = {
			{ Id = "GliderPines", Name = "GLIDER PINES", Species = "Microraptor", Kind = "Pack", Nest = 1, Count = 3, Blurb = "MICRORAPTORS GLIDE BETWEEN THE PINES" },
			{ Id = "FernHollow", Name = "FERN HOLLOW", Species = "Psittacosaurus", Kind = "Herd", Nest = 2, Count = 4, Blurb = "A PSITTACOSAURUS HERD HIDES IN THE FERNS" },
			{ Id = "LogWarren", Name = "LOG WARREN", Species = "Compy", Kind = "Swarm", Nest = 3, Count = 12, Blurb = "A COMPY SWARM NESTS IN THE FALLEN LOGS" },
		},
```
Ruler (den "WHITE LAKE"):
```lua
	BlizzardKing = { Name = "BLIZZARD KING", Era = "FrostForest", Species = "Yutyrannus", Power = 1400, Calm = 12000, Scale = 1.1,
		Material = "FrostPlume", Title = "RULER OF FROST FOREST", Color = Color3.fromRGB(143, 210, 245) },
```

## Config.Combat (relative Dmg / Tele proposed; lead sets Calm / Power)
```lua
	Psittacosaurus = { Calm = 600, Speed = 17, Scale = 1.2, Gap = { 1.8, 3 }, Attacks = {
		{ Id = "BeakNip", Shape = "Cone", Len = 8, Angle = 60, Tele = 0.55, Dmg = 10 },
		{ Id = "HerdRush", Shape = "Line", Len = 24, Width = 6, Tele = 0.9, Dmg = 14, Dash = true },
		{ Id = "QuillRattle", Shape = "Ring", Radius = 12, Inner = 4, Tele = 1.0, Dmg = 8, Self = true },
	} },
	Compy = { Calm = 90, Speed = 23, Scale = 1.3, Gap = { 1.0, 1.8 }, Attacks = {
		{ Id = "Nip", Shape = "Cone", Len = 5, Angle = 70, Tele = 0.4, Dmg = 4 },
		{ Id = "DartSnatch", Shape = "Line", Len = 14, Width = 3, Tele = 0.6, Dmg = 3, Dash = true },
		{ Id = "SwarmLeap", Shape = "Circle", Radius = 4, Tele = 0.7, Dmg = 6, AtTarget = true },
	} },
	Microraptor = { Calm = 700, Speed = 24, Scale = 1.5, Gap = { 1.4, 2.4 }, Attacks = {
		{ Id = "DiveStrike", Shape = "Line", Len = 22, Width = 4, Tele = 0.8, Dmg = 16, Dash = true },
		{ Id = "Peck", Shape = "Cone", Len = 7, Angle = 60, Tele = 0.45, Dmg = 9 },
		{ Id = "WingBuffet", Shape = "Circle", Radius = 7, Tele = 0.7, Dmg = 11, Self = true },
	} },
	Yutyrannus = { Calm = 12000, Speed = 15, Scale = 1.1, Gap = { 1.4, 2.5 }, Attacks = {
		{ Id = "FrostBite", Shape = "Cone", Len = 17, Angle = 70, Tele = 0.85, Dmg = 32 },
		{ Id = "IceStomp", Shape = "Circle", Radius = 15, Tele = 1.1, Dmg = 30, Self = true },
		{ Id = "FrostRoar", Shape = "Cone", Len = 26, Angle = 60, Tele = 1.2, Dmg = 18, Stun = true },
		{ Id = "TailSweep", Shape = "Cone", Len = 16, Angle = 120, Tele = 0.9, Dmg = 24, Back = true },
	} },
```
Every attack Id above has an action of the same name in its profile (plus Attack / Roar / Stunned / Chase).

## Config.BuddyRole
```lua
	Microraptor = { Name = "GLIDE", Desc = "GLIDE OFF LEDGES - DODGE BECOMES AN AIR DASH", Every = 1.6, Mult = 0.6, Glide = true },
	Psittacosaurus = { Name = "CAMO", Desc = "DINOS NOTICE YOU 40% SLOWER", Every = 2.2, Mult = 0.7, Camo = 0.6 },
	Compy = { Name = "SCAVENGER", Desc = "INSTANT RELOAD EVERY 10S - GRABS COINS AND PICKUPS", Every = 1.2, Mult = 0.45, Reload = 10, Grab = 26 },
	Yutyrannus = { Name = "FROST ROAR", Desc = "SLOWS EVERY DINO NEARBY FOR 4S", Every = 9, Mult = 1.4, Area = 18, Slow = 4 },
```
(Glide / Camo / Reload / Grab / Slow are new fields: see "Buddy roles needing engine code" above.)

## Chase.luau PURSUE
```lua
	Microraptor = { Scale = 1.5, Run = 58, Catchup = 70, Lunge = 0.32, Telegraph = 0.7, Recover = 0.9 }, -- glides in from the trees onto the rover
	Psittacosaurus = { Scale = 1.15, Run = 50, Catchup = 58, Lunge = 0.45, Telegraph = 0.9, Recover = 1.2 }, -- the herd scatters onto the road
	Compy = { Scale = 1.3, Run = 56, Catchup = 68, Lunge = 0.3, Telegraph = 0.6, Recover = 0.8 }, -- swarms over the rover (latch + Gnaw)
	Yutyrannus = { Scale = 1.0, Run = 53, Catchup = 63, Lunge = 0.5, Telegraph = 1.0, Recover = 1.4 }, -- across the ice: its Chase lunge cracks the ice
```

## PaddockLife REACT
```lua
	Microraptor = { Bow = 0.5, Nuzzle = 0.35, Butt = 0, Wag = 1.4 },
	Psittacosaurus = { Bow = 0.6, Nuzzle = 0.3, Butt = 0.2, Wag = 1.1 },
	Compy = { Bow = 0.5, Nuzzle = 0.4, Butt = 0, Wag = 1.6 },
	Yutyrannus = { Bow = 0.75, Nuzzle = 0.2, Butt = 0.3, Wag = 0.7 },
```

## Reveal entries (already registered by Reveals/FrostForest.luau)
- Microraptor `canopy` — Kick "THE FOUR-WINGED SHADOW", Act WingDisplay, Hero Low, AtMark: snow sifts off branches over
  the lens, one bounces, a dark four-winged shape glides right over the camera and lands in front.
- Psittacosaurus `eyes` — Kick "HIDE AND SQUEAK", Act Roar, Hero Low, AtMark: ferns rustle in three places (nothing),
  then pairs of eyes blink open along the fern line (animator EyesClosed lids) and the herd pops up (ctx.Pack).
- Compy `tracks` — Kick "NEVER JUST ONE", Act Roar, Hero Low: three-toed tracks print into the snow along six paths
  converging on the lens; silence; the swarm bursts up out of the snow around you (ctx.Pack) + CompySwarm.
- Yutyrannus `whiteout` (gallery) — Kick "THE BLIZZARD KING", Act Roar, Hero Up, AtMark: white-out light + driving
  snow, amber eyes approach, a foot cracks the ice by the lens, the white thins to it looming overhead; pines dump snow.

## ICON_PROMPTS.md lines
- Microraptor: chunky toy-brick Microraptor, glossy black feathers with teal-blue iridescent sheen, four wings spread wide (arm and leg wing panels), long tail ending in a diamond feather fan, big gold eyes, small crest tuft, snowy pine branch, cool blue dawn light.
- Psittacosaurus: chunky toy-brick Psittacosaurus, big boxy head with a hooked amber parrot beak, dark cheek horns and chin, countershaded brown back fading to cream belly, a crest of cream quill bristles with dark tips on the tail, peeking out of frosty ferns, cute.
- Compy: chunky toy-brick Compy (Sinosauropteryx), tiny ginger fuzzball with a dark bandit mask over bright yellow eyes, very long tail ringed ginger and white, popping out of a snowy hollow log, cheeky.
- Yutyrannus: chunky toy-brick Yutyrannus, huge feathered tyrant with shaggy white and frost-grey feathers, dark grey-blue stripes down its back, an ice-blue crest ridge on the snout, amber eyes, roaring with frosty breath in falling snow, pines behind.
