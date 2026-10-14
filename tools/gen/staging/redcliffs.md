# RED CLIFFS species: what the lead needs to merge

Species: **Oviraptor** (site 1, Pack), **Protoceratops** (site 2, Herd), **Gallimimus** (site 3, Herd), and
**Therizinosaurus** (the ruler of SCYTHE GROVE). The zone itself is covered in `redcliffs_zone.md`.

These files are mine and already load:
- Rigs are in `tools/gen/dinos/{oviraptor,protoceratops,gallimimus,therizinosaurus}.js`.
- Profiles are in `tools/gen/anim/{same}.js`.
- Shot lists are in `tools/gen/anim/shots_redcliffs.js`.
- QC stages are in `tools/gen/showcase_redcliffs.js`.
- VFX events are in `src/ReplicatedStorage/DinoExpedition/DinosaurVFX/Extra_RedCliffs.luau`.
- Reveal beats are in `src/StarterPlayer/StarterPlayerScripts/DinoExpeditionClient/Game/Reveals/RedCliffs.luau`.

A full build (not `--preview-only`) then writes the `Profiles/*.luau`, `Shots.luau` and the rbxmx files.

| Species | Parts | Joints | Size L x W x H | Signature action | Shot key | Reveal beat |
| --- | --- | --- | --- | --- | --- | --- |
| Oviraptor | 180 | 22 | 6.8 x 1.8 x 4.9 | `EggHeist` | `OviHeist` | `heist` |
| Protoceratops | 129 | 21 | 9.0 x 2.8 x 3.7 | `SandBurst` | `ProtoBurst` | `dunes` |
| Gallimimus | 137 | 24 | 15.9 x 3.3 x 8.8 | `FlockSprint` | `GalliStampede` | `stampede` |
| Therizinosaurus | 207 | 27 | 25.3 x 8.2 x 19.2 | `ScytheHarvest` | `TheriHarvest` | `grove` (gallery only) |

## 1. Config.Species (Era = "RedCliffs")

The Income values assume Red Cliffs sits after Spine River in the progression. Rescale them if the era lands
elsewhere.

```lua
	Oviraptor = { Name = "OVIRAPTOR", Era = "RedCliffs", Income = 60, KG = { 15, 70 }, Color = Color3.fromRGB(42, 143, 163) },
	Protoceratops = { Name = "PROTOCERATOPS", Era = "RedCliffs", Income = 55, KG = { 90, 420 }, Color = Color3.fromRGB(217, 173, 114) },
	Gallimimus = { Name = "GALLIMIMUS", Era = "RedCliffs", Income = 75, KG = { 120, 480 }, Color = Color3.fromRGB(112, 146, 196) },
	Therizinosaurus = { Name = "THERIZINOSAURUS", Era = "RedCliffs", Income = 260, KG = { 600, 3200 }, Color = Color3.fromRGB(180, 90, 40) },
```

Add the four ids to `Config.SpeciesOrder` after the Spine River entries, in this order: Oviraptor, Protoceratops,
Gallimimus, Therizinosaurus.

## 2. Config.Combat

Dmg and Tele are relative proposals; the lead sets Calm and Power. Each attack Id has an action with the same name
in its profile.

```lua
	-- steals eggs, kicks in a flurry, screeches for its gang
	Oviraptor = { Calm = 120, Speed = 22, Scale = 1.5, Gap = { 1.4, 2.6 }, Attacks = {
		{ Id = "BeakSnatch", Shape = "Line", Len = 16, Width = 5, Tele = 0.7, Dmg = 14, Dash = true },
		{ Id = "KickFlurry", Shape = "Cone", Len = 9, Angle = 70, Tele = 0.6, Dmg = 20 },
		{ Id = "Screech", Shape = "Ring", Radius = 16, Inner = 6, Tele = 1.0, Dmg = 10, Self = true },
	} },
	-- a herd of four circles you; frill bash, beak bite; pairs ram
	Protoceratops = { Calm = 260, Speed = 15, Scale = 1.3, Gap = { 1.6, 2.8 }, Attacks = {
		{ Id = "FrillBash", Shape = "Cone", Len = 11, Angle = 110, Tele = 0.8, Dmg = 24 },
		{ Id = "BeakBite", Shape = "Cone", Len = 8, Angle = 50, Tele = 0.55, Dmg = 18 },
		{ Id = "HerdCharge", Shape = "Line", Len = 30, Width = 7, Tele = 1.0, Dmg = 26, Dash = true },
	} },
	-- jumpy flock: wheels round you and kicks, or just runs you over
	Gallimimus = { Calm = 220, Speed = 26, Scale = 1.0, Gap = { 1.4, 2.4 }, Attacks = {
		{ Id = "Peck", Shape = "Cone", Len = 12, Angle = 45, Tele = 0.6, Dmg = 20 },
		{ Id = "FlockKick", Shape = "Circle", Radius = 11, Tele = 0.85, Dmg = 28, Self = true },
		{ Id = "Stampede", Shape = "Line", Len = 40, Width = 6, Tele = 0.9, Dmg = 30, Dash = true },
	} },
	-- the ruler: claw slashes cut down cover; the crossed-claw X-slash; hooks into the cliff and climbs
	Therizinosaurus = { Calm = 5200, Speed = 13, Scale = 1.0, Gap = { 1.6, 2.8 }, Attacks = {
		{ Id = "ScytheSweep", Shape = "Cone", Len = 22, Angle = 140, Tele = 1.0, Dmg = 44 },
		{ Id = "XSlash", Shape = "Line", Len = 26, Width = 9, Tele = 1.3, Dmg = 52, Dash = true },
		{ Id = "ClawHook", Shape = "Line", Len = 30, Width = 8, Tele = 1.1, Dmg = 40, Dash = true },
	} },
```

### Engine hooks these attacks want (none exist yet)

All of these are optional. Without them each attack simply works as a plain damage shape.

- **Oviraptor `BeakSnatch`.** On a hit, take the egg the player is carrying back to the nest. The animation fires a
  `EggSnatch { Hand = "LeftForearm", Hold = 3 }` event, which welds a client-side egg into its arm.
- **Oviraptor `Screech`.** Wakes or pulls in the rest of the pack, like `HerdCall`.
- **Gallimimus `Sidestep`.** This is a dodge action (a 3.4-stud hop to its right). The design says it "sidesteps
  darts unless you lead". The dart code would play `Sidestep` and move the root, unless the shot was aimed ahead of
  it.
- **Therizinosaurus `CrossGuard`.** This is a looping guard pose. Per the design, the guard (damage-immune) opens
  when the player perfect-dodges through the X-slash. `XSlash` also ends in the guard pose.
- **Therizinosaurus `ScytheSweep`.** This should break cover props in its cone.
- **Therizinosaurus `ClawHook`.** Hooks into the cliff and climbs: the animation lifts the root 3.4 studs and 3 studs
  forward. The real climb needs arena markers in the den (for example `DenLedge1..6`).

## 3. Config.Bosses (ruler)

```lua
	Harvester = { Name = "THE HARVESTER", Era = "RedCliffs", Species = "Therizinosaurus", Power = 1400, Calm = 5200, Scale = 1.0,
		Material = "ScytheClaw", Title = "RULER OF RED CLIFFS", Color = Color3.fromRGB(240, 200, 120) },
```

At about 25 x 19 studs it is the size of PrimalRex, so `Scale = 1.0` already reads as a giant. Its profile has
`Signature = "ScytheHarvest"`, which plays when it is glimpsed on its throne. That action needs no props: the
`ClawRake` and `ScytheSlash` effects stand in.

## 4. Config.BuddyRole

```lua
	Oviraptor = { Name = "EGG GUARD", Desc = "CATCHES A FALLING EGG + EGG LUCK", Every = 2.0, Mult = 0.7 },
	Protoceratops = { Name = "DIGGER", Desc = "DIGS UP COINS - SOMETIMES AN EGG", Every = 2.4, Mult = 0.8 },
	Gallimimus = { Name = "SPRINT", Desc = "TEAM +20% SPEED, STAMINA + ROVER BOOST", Every = 1.6, Mult = 0.6 },
	Therizinosaurus = { Name = "SHRED", Desc = "TARGET TAKES +40% DAMAGE FOR 5 S", Every = 6, Mult = 1.3 },
```

All four roles need new engine code. The `Every` and `Mult` values above only cover their bites.

- **EGG GUARD.** Once per run, when an egg would fall off the rack (`EggDropChance` or `LatchDropChance`), the buddy
  catches it. It also adds a small egg-luck bonus (for example +5% to the egg rarity roll). The animation for the
  catch exists: `EggSnatch` (or play `Chase`).
- **DIGGER.** Every so often it plays `Dig` (its Special) and spawns coins; it has a small chance of spawning a bonus
  egg. `Dig` fires `Scrape` events at its front feet.
- **SPRINT.** This is a passive aura: +20% team move speed, faster stamina regen, and a rover boost-refill bonus while
  this buddy rides along.
- **SHRED.** Its hit applies a "shredded" debuff to the target: the target takes +40% damage for 5 s. Show it with
  `ScytheSlash` / `ClawRake` on the target.

## 5. Chase.luau `PURSUE`

```lua
	Oviraptor = { Scale = 1.5, Run = 56, Catchup = 66, Lunge = 0.34, Telegraph = 0.75, Recover = 1.0 },
	Protoceratops = { Scale = 1.3, Run = 50, Catchup = 58, Lunge = 0.45, Telegraph = 1.0, Recover = 1.3 },
	Gallimimus = { Scale = 1.0, Run = 62, Catchup = 74, Lunge = 0.4, Telegraph = 0.8, Recover = 1.0 },
	Therizinosaurus = { Scale = 0.95, Run = 50, Catchup = 60, Lunge = 0.55, Telegraph = 1.2, Recover = 1.6 },
```

The design wants each chase to play differently. The `Chase` actions already act it out.

- **Oviraptor.** It "plucks eggs off the rack": its `Chase` leaps up at 2.6 s and fires `EggSnatch`. Hook a successful
  lunge to remove one rack egg.
- **Protoceratops.** "Pairs ram the rover wheels": its `Chase` ends in a sideways head-butt with an `Impact` at
  `VFX_Crest`. Spawn them in pairs and treat a lunge as a wheel ram (rover damage plus a small swerve).
- **Gallimimus.** It "outruns the rover": it runs past, cuts across the nose and kicks (`Chase`). A higher `Run` /
  `Catchup` gives the overtaking feel.

## 6. PaddockLife `REACT`

```lua
	Oviraptor = { Bow = 0.6, Nuzzle = 0.35, Butt = 0, Wag = 1.3 },
	Protoceratops = { Bow = 0.5, Nuzzle = 0.12, Butt = 1.0, Wag = 0.9 },
	Gallimimus = { Bow = 0.85, Nuzzle = 0.2, Butt = 0, Wag = 0.6 },
	Therizinosaurus = { Bow = 1.0, Nuzzle = 0.2, Butt = 0, Wag = 0.6 },
```

PaddockLife idles look for `LookAround`, `Sniff`, `Graze`, `Browse` and `Hop`.
- Oviraptor and Gallimimus have `LookAround` and `Sniff`.
- Protoceratops has `LookAround`, `Sniff` and `Graze`.
- Therizinosaurus has `LookAround`, `Sniff` and `Browse`.

## 7. Swimmer / BIG

- None of the four are swimmers.
- Add **Therizinosaurus** and **Gallimimus** to EraView's `BIG` gallery set. Gallimimus is 8.8 studs tall, taller
  than Stegosaurus.

## 8. Reveal beats (already loaded by EraView from `Game/Reveals/RedCliffs.luau`)

| Species | REVEAL entry |
| --- | --- |
| Oviraptor | `Kick = "THE EGG THIEF?"`, Beat `heist`, AtMark |
| Protoceratops | `Kick = "THE DUNE DIGGERS"`, Beat `dunes`, AtMark. The lead and three herd stand-ins rise through `ctx.Pack` |
| Gallimimus | `Kick = "THE FASTEST IN THE FLOCK"`, Beat `stampede`, AtMark |
| Therizinosaurus | `Kick = "THE SCYTHE OF THE CLIFFS"`, Beat `grove`, Hero `Up`. Gallery only |

All four entries use `Warm` (the golden-dusk grade), and each beat lasts about 4 to 4.7 s.

- The Oviraptor's question-mark kicker is deliberate: it sets up the fun-fact twist that it was guarding its own eggs.
- The beats use `DinosaurVFX.HandleEvent(model, "SandBurst" / "ClawRake" / "Scrape", ...)`. For the Extra events,
  `Extra_RedCliffs` must be present.

## 9. VFX events (in `Extra_RedCliffs.luau`, no change to `init.luau`)

| Event | Argument | What it does |
| --- | --- | --- |
| `EggSnatch` | `{ Prop?, Hand, Hold }` | Welds an egg into the hand bone for `Hold` seconds. It takes the stage `Nest` prop's egg when one is present, otherwise it makes a fresh egg. |
| `CasqueFlash` | `(dur)` | The Oviraptor's casque glows orange. |
| `FrillFlash` | `(dur)` | The Protoceratops' frill rim and spots flush neon pink. |
| `SandBreath` | `{ Scale }` | The dune heaves and sighs. |
| `SandBurst` | `{ Scale }` | A sand eruption. With no `Dune` prop present, a stand-in mound blows apart. |
| `SandShake` | `{ Scale }` | Sand sprays off the body in pulses (a wet-dog shake). |
| `FlockRush` | `{ Count, From, To, Time }` | Client-side clone runners streak across the creature's local X lanes and are destroyed afterwards. Clones lose every CollectionService tag and get attribute `FlockRunner = true`. |
| `ClawRake` | `{ Scale, Arm, Hook }` | Leaves and twigs fall from the claw tips. With `Hook`, rock debris falls instead. |
| `ScytheSlash` | `{ Arm, Scale, Wide, Cross, AtCamera }` | Glowing cream slash streaks. With `AtCamera`, a set cuts across the lens. |
| `ClawRattle` | `{ Scale }` | Claw-tip sparks. |

All of these effects work out in the era. They never need the showcase props.

## 10. Showcase QC stages (`showcase_redcliffs.js`, row z = -215)

| Species | Position (x, z) | Radius | Props |
| --- | --- | --- | --- |
| Oviraptor | (-62, -215) | 6 | `Nest` (4 eggs) |
| Protoceratops | (-36, -215) | 7 | `Dune` (it starts buried) and the `Rock` it head-butts |
| Gallimimus | (-6, -215) | 12 | It sprints in from 13 studs to its left |
| Therizinosaurus | (40, -215) | 20 | A grove tree whose `Canopy` is the prop |

## 11. Icon prompts (ICON_PROMPTS.md, dino table)

| Key | Prompt |
| --- | --- |
| Dino_Oviraptor | a teal-and-indigo oviraptor with a tall rounded orange-red head crest and a parrot beak, clutching a striped teal egg under one feathered arm, guilty wide eyes |
| Dino_Protoceratops | a sandy tan protoceratops head with brown stripes, a broad frill with a rose-pink scalloped rim and two eye-spots, a hooked beak |
| Dino_Gallimimus | a grey-blue gallimimus head and long neck with rusty stripes, a small flat beak and a huge yellow eye, mid-sprint |
| Dino_Therizinosaurus | a dark olive therizinosaurus with shaggy rust feathers raising two hands of huge cream scythe claws crossed in an X |

## Notes

- **Babies.** Babies come from the adult automatically. No species has hidden parts; the stolen egg is a runtime weld.
- **QC** (`--qc`):
  - Oviraptor: zfight 0, animClips 14. All are small (≤ 0.28): the clutching arm against the chest, and the thigh
    against the metatarsus in a deep run crouch.
  - Protoceratops: zfight 0, animClips 23. These are mostly the frill brushing the shoulders in head-tossing attacks
    (≤ 0.45).
  - Gallimimus: zfight 0, animClips 10. Thigh against body in the sprint (≤ 0.32).
  - Therizinosaurus: zfight 0, animClips 95. These come from its huge limbs: the arms brush the pot
    belly in the guard and slashes, the claws cross on purpose in the X guard, and the thighs touch the belly in the
    run.
