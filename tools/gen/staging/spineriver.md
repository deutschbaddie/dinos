# Spine River staging — Sarcosuchus (CROC CREEK, nest 3)

Ready-to-paste pieces for the lead. Everything under tools/gen and the two Luau modules below is already live
(newSpecies.js loads the rig + profile, shots come from anim/shots_spineriver.js, the QC pool from
showcase_spineriver.js, the VFX events from DinosaurVFX/Extra_SpineRiver.luau, the reveal from
Game/Reveals/SpineRiver.luau).

## Files (owned by the Spine River species job)

- tools/gen/dinos/sarcosuchus.js — rig: 209 parts, 23 bones (Pelvis, Torso, Neck, Head, Jaw, Tail1..6, quad legs),
  ~32 x 4.3 studs. Attachments: VFX_Head, VFX_Mouth, VFX_Chest, VFX_Crest (between the eyes: the waterline
  target), VFX_RightEye/LeftEye, VFX_Right/LeftFoot, VFX_Right/LeftFrontFoot, VFX_TailTip. Eyes have blink lids.
- tools/gen/anim/sarcosuchus.js — profile. Gait Quadruped (semi-sprawled high walk; body + tail snake side to side).
  Actions: Roar (bellow + water dance), Attack, BankLunge, TailWave, JawTrap, DeathRoll, Hiss, Lurk (loopable
  float pose: a log with eyes), Stunned, LookAround, Chase, LogAmbush (signature).
- tools/gen/anim/shots_spineriver.js — shot list `SarcoLog`.
- tools/gen/showcase_spineriver.js — QC pool at [0, -400], yaw 90, pool [30, 50] (46 x 22 was too short for a
  32-stud croc lying lengthwise), depth 2.35 (water stands 2.6 over its feet = the same as a water set's
  sinkTo(.., 0.6), so the float pose sits at the waterline in both). One CinematicProp "DriftLogs" with three logs.
- src/ReplicatedStorage/DinoExpedition/DinosaurVFX/Extra_SpineRiver.luau — events LidsShut, LogDrift, EyeRipple,
  Bubbles, LensSpray, RollSpray, Hiss, WaterDance, TailWave.
- src/StarterPlayer/StarterPlayerScripts/DinoExpeditionClient/Game/Reveals/SpineRiver.luau — REVEAL.Sarcosuchus +
  BEATS.logs.

## Config.Species

```lua
	Sarcosuchus = { Name = "SARCOSUCHUS", Era = "SpineRiver", Income = 55, KG = { 180, 950 }, Color = Color3.fromRGB(94, 111, 46) },
```
Config.SpeciesOrder: after "Carnotaurus".

## Config.Eras -> SpineRiver.Sites (nest 3)

```lua
			{ Id = "CrocCreek", Power = 650, Name = "CROC CREEK", Species = "Sarcosuchus", Kind = "Brute", Nest = 3, Blurb = "A SARCOSUCHUS LURKS IN THE MANGROVES" },
```

## Config.Combat

Tele values line up with the hit frame of the action of the same name (BankLunge snaps at 1.4 s, TailWave
whips at 1.0 s, JawTrap snaps at 2.45 s). Scale 1.0 keeps the stand-in exactly the size the signature's
stud-based shot list was framed for.

```lua
	-- the SuperCroc: slow on land, every attack is an ambush. BankLunge telegraph = bubbles, then the eyes sink;
	-- JawTrap = it lies still with the jaws wide open (zone denial) and snaps if you walk into the cone
	Sarcosuchus = { Calm = 3000, Speed = 11, Scale = 1.0, Gap = { 1.8, 3.0 }, Attacks = {
		{ Id = "BankLunge", Shape = "Line", Len = 30, Width = 7, Tele = 1.3, Dmg = 46, Dash = true },
		{ Id = "TailWave", Shape = "Cone", Len = 18, Angle = 120, Tele = 0.95, Dmg = 36, Back = true, Knock = 24 },
		{ Id = "JawTrap", Shape = "Cone", Len = 14, Angle = 55, Tele = 2.2, Dmg = 54 },
	} },
```
NEW ENGINE (optional): `Knock = studs` on TailWave — shove the player that far away from the croc (into the
water when there is any). Without it, TailWave works as a normal back cone.
Gameplay idea for the site (needs engine code, optional): the croc idles with `Lurk` looping among drifting log
props (spineRiver.js already builds the creek); it only "wakes" (Calm countdown) when you come close.

## Config.BuddyRole

```lua
	Sarcosuchus = { Name = "DEATH ROLL", Desc = "GRABS A DINO AND ROLLS IT - DARTS HIT THE WEAK SPOT", Every = 8, Mult = 1.5, Stun = 2.5 },
```
Works today as a big stunning hit (Stun 2.5 = the hold). NEW ENGINE for the full role: while a dino is held
(the 2.5 s stun from this buddy), every dart that hits it counts as a weak-spot hit; the buddy plays its
`DeathRoll` action on the target. As a companion it swims: tow the player across water fast (swim speed x1.6).
Bond: not in NoRide (it can carry you, like a boat) and not a Shield.

## Chase.luau PURSUE

```lua
	-- the ford ambush: waits at the river ford, lunges as the rover splashes through; slow to catch up on land
	Sarcosuchus = { Scale = 0.85, Run = 46, Catchup = 54, Lunge = 0.6, Telegraph = 1.3, Recover = 1.8 },
```
NEW ENGINE (optional): ford ambush — spawn it ahead at the route's wet stretch (routeData Water spans), lurking
(`Lurk` action), and lunge (`Chase` action's last 1.3 s / `BankLunge`) when the rover enters the water.

## PaddockLife REACT

```lua
	Sarcosuchus = { Bow = 0.25, Nuzzle = 0.06, Butt = 0, Wag = 1.4 },
```

## Swimmer / size handling

- NOT water-only: it walks on land (Quadruped gait). Do not add it to the Mosasaurus-only water lists in
  Dinos.luau, CampView, PaddockLife, Panels — it lives in the paddock / camp like any land dino.
- EraView: add `Sarcosuchus = "River"` to `WATER` so its gallery signature + reveal play in the river water set
  (the beat also works on location: it finds a DinoWater surface at the site, or lies in the mud without one).
  Add `Sarcosuchus = true` to `BIG` (32 studs long; only matters for the gallery fallback stage).
- Reveal: `REVEAL.Sarcosuchus = { Kick = "THE LOG THAT ISN'T", Beat = "logs", Act = { "Hiss", "Roar" }, Hero = "Low" }`
  (registered by Reveals/SpineRiver.luau; nothing to paste).

## Signature

- Action `LogAmbush` (7.4 s), shot list `SarcoLog` (Title 6.2, Hold 8, slow-mo 2.7-3.12 at 0.28 on the snap).
- Shots: Logs (low on the water among the drifting logs; one has eyes) -> Eyes (ECU at the waterline, the lids
  open) -> Burst (the jaws come up at the lens, spray on the glass, FOV punch) -> Roll (double death roll from
  above) -> RollLow (at the waterline, spray) -> Hiss (it rears its head and hisses) -> Hero.
- VFX it uses: LidsShut, LogDrift (drifts the stage's DriftLogs prop; spawns temporary logs anywhere else),
  EyeRipple, Bubbles, LensSpray, RollSpray, Hiss + built-in Splash / Bite / EyeGlow / CameraShake.

## Icon prompt (ICON_PROMPTS.md)

```
Sarcosuchus: chunky studded toy-brick giant crocodile, dark olive green with a cream belly, rows of dark keeled back scutes, very long narrow snout ending in a bulbous brown bulla, interlocking white teeth along the jaw line, bright yellow slit-pupil eyes raised on top of its head; low 3/4 hero angle, half in murky green river water, jaws slightly open, bold readable silhouette, clean background
```

## Facts (Panels / dex)

Sarcosuchus imperator, "flesh crocodile emperor". Early Cretaceous, ~112 million years ago, Niger (Elrhaz
Formation, Gadoufaoua). About 9-9.5 m long (older estimates 11-12 m), ~3.5-4.3 t. Its snout ended in a bulbous
bulla of unknown purpose (perhaps sound or smell). Ate fish and large prey that came to the water's edge.
