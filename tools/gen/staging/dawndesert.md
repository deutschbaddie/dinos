# Dawn Desert (group `dawndesert`, zone `DawnDesert`) — staging for the lead

Files (all new, nothing shared edited):
- tools/gen/dinos/{coelophysis,plateosaurus,dilophosaurus,postosuchus}.js, tools/gen/anim/{same}.js
- tools/gen/anim/shots_dawndesert.js (CoeloOasis, PlateoReach, DiloSpit, PostoRise)
- tools/gen/showcase_dawndesert.js (row z = -335; x -62 / -4 / -36 / 40; yaw 180)
- src/ReplicatedStorage/DinoExpedition/DinosaurVFX/Extra_DawnDesert.luau
- src/StarterPlayer/StarterPlayerScripts/DinoExpeditionClient/Game/Reveals/DawnDesert.luau

| Species | parts | joints | size (L x H) | Signature action | Shot key | Reveal beat |
| --- | --- | --- | --- | --- | --- | --- |
| Coelophysis | 136 | 23 | 8.7 x 3.5 | OasisStrike | CoeloOasis | oasis |
| Plateosaurus | 134 | 26 | 21.2 x 9.7 (≈15 reared) | TreeReach | PlateoReach | canopy |
| Dilophosaurus | 202 | 23 | 15.6 x 7.7 | CrestFlare | DiloSpit | haze |
| Postosuchus (ruler) | 217 | 22 | 23.0 x 7.6 (≈16 standing) | BeforeTheDinosaurs | PostoRise | bonewash |

New VFX events (Extra_DawnDesert): Ripple, PackCue, CrestFlush, SpitGlob (screen splat), DustRing, MudBubble,
MudBurst, HealPulse, TerrorWave. PackCue plays an action on every model whose `HerdLeader` attribute equals the
dino's name (works in the showcase too — the Coelophysis pack-mates and the Dilophosaurus partner are clones with
HerdLeader set). If the engine spawns site packs / pairs, giving the followers `HerdLeader = <leader.Name>` makes
them join the signature (Coelophysis drink + chorus, Dilophosaurus partner displays).

## Config.Species
```lua
Coelophysis = { Name = "COELOPHYSIS", Era = "DawnDesert", Income = 60, KG = { 10, 30 }, Color = Color3.fromRGB(232, 150, 60) },
Plateosaurus = { Name = "PLATEOSAURUS", Era = "DawnDesert", Income = 75, KG = { 300, 1500 }, Color = Color3.fromRGB(111, 138, 50) },
Dilophosaurus = { Name = "DILOPHOSAURUS", Era = "DawnDesert", Income = 90, KG = { 120, 600 }, Color = Color3.fromRGB(184, 196, 58) },
Postosuchus = { Name = "POSTOSUCHUS", Era = "DawnDesert", Income = 220, KG = { 250, 1200 }, Color = Color3.fromRGB(163, 61, 44) },
```

## Config.Combat (lead sets Calm/Power; each Id has a matching action)
```lua
Coelophysis = { Calm = 90, Speed = 23, Scale = 1.3, Gap = { 1.4, 2.6 }, Attacks = {
	{ Id = "SnapBite", Shape = "Cone", Len = 8, Angle = 55, Tele = 0.5, Dmg = 12 },
	{ Id = "DartLunge", Shape = "Line", Len = 16, Width = 4, Tele = 0.65, Dmg = 15, Dash = true } } },
Plateosaurus = { Calm = 1600, Speed = 12, Scale = 1.0, Gap = { 2.0, 3.2 }, Attacks = {
	{ Id = "RearSlam", Shape = "Circle", Radius = 13, Tele = 1.2, Dmg = 32, Self = true, Stun = true },
	{ Id = "ThumbSwipe", Shape = "Cone", Len = 12, Angle = 80, Tele = 0.8, Dmg = 24 },
	{ Id = "TailSwipe", Shape = "Cone", Len = 17, Angle = 110, Tele = 0.9, Dmg = 24, Back = true } } },
Dilophosaurus = { Calm = 1700, Speed = 19, Scale = 1.0, Gap = { 1.5, 2.6 }, Attacks = {
	{ Id = "BlindingSpit", Shape = "Line", Len = 26, Width = 4, Tele = 0.9, Dmg = 10 },
	{ Id = "CrestDisplay", Shape = "Circle", Radius = 14, Tele = 1.0, Dmg = 6, Self = true, Stun = true },
	{ Id = "DoubleBite", Shape = "Cone", Len = 11, Angle = 60, Tele = 0.7, Dmg = 28 } } },
Postosuchus = { Calm = 12000, Speed = 16, Scale = 1.0, Gap = { 1.4, 2.4 }, Attacks = {
	{ Id = "MudAmbush", Shape = "Circle", Radius = 11, Tele = 1.3, Dmg = 40, AtTarget = true },
	{ Id = "UprightCharge", Shape = "Line", Len = 36, Width = 8, Tele = 1.0, Dmg = 42, Dash = true },
	{ Id = "BiteShake", Shape = "Cone", Len = 15, Angle = 70, Tele = 0.85, Dmg = 46 },
	{ Id = "TailLash", Shape = "Cone", Len = 17, Angle = 110, Tele = 0.9, Dmg = 32, Back = true } } },
```
Engine notes: BlindingSpit's hit should make the target's next 2 attacks miss (SpitGlob already splats the screen
of a player in front within 34 studs). CrestDisplay = "crest display freeze" (Stun on the player). Plateosaurus
herd: when reared (Browse action) its Sneak sight cone could be ~1.5x longer. Coelophysis pack: Count = 5,
surround-and-close AI is engine work; its Chase action ends in a lunge, so staggering pack members' Chase start
gives the snake-line "taking turns to lunge".

## Config.Bosses / Eras (suggested)
```lua
BoneWash = { Name = "BONE WASH TYRANT", Era = "DawnDesert", Species = "Postosuchus", Power = 1400, Calm = 12000, Scale = 1.0,
	Material = "AncientScute", Title = "RULER OF DAWN DESERT", Color = Color3.fromRGB(255, 150, 60) },
```
Sites: { Id = "OasisPack", Name = "OASIS PACK", Species = "Coelophysis", Kind = "Pack", Count = 5, Nest = 1 },
{ Id = "TallCycads", Name = "TALL CYCADS", Species = "Plateosaurus", Kind = "Herd", Count = 3, Nest = 2 },
{ Id = "CrestRocks", Name = "CREST ROCKS", Species = "Dilophosaurus", Kind = "Brute", Count = 2 (pair), Nest = 3 }.
Ruler intro line: "BEFORE THE DINOSAURS, THIS RULED." (also the Postosuchus REVEAL Kick). The ruler has a looping
`Sleep` action (belly-down in the mud) for the throne. Its signature starts buried (hips 6.5 studs under the
ground) — fine in the den (terrain hides it); MudCrust/Bones props are optional (MudBurst sells it without them).

## Config.BuddyRole
```lua
Coelophysis = { Name = "PACK CALL", Desc = "CALLS 2 WILD COELOPHYSIS TO FIGHT FOR 10 S", Every = 14, Mult = 0.5 },
Plateosaurus = { Name = "FORAGER", Desc = "HEALS YOU SLOWLY - REVIVES 2X FASTER", Every = 4, Mult = 0.4 },
Dilophosaurus = { Name = "BLINDING SPIT", Desc = "TARGET'S NEXT 2 ATTACKS MISS", Every = 7, Mult = 0.7 },
Postosuchus = { Name = "TERROR", Desc = "SMALL DINOS FLEE FOR 4 S", Every = 12, Mult = 1.6, Area = 16 },
```
All four need new engine code (none map to Stun/Area/Distract alone):
- PACK CALL: spawn 2 temporary wild Coelophysis allies for 10 s (play action `PackCall` on the buddy; allies can
  play `HerdResponse`).
- FORAGER (first healer): heal-over-time on the owner + revive speed x2; play `Forage` (fires `HealPulse`).
- BLINDING SPIT: `BlindingSpit` action (fires `SpitGlob`, no splat needed on enemies); flag target "misses next 2".
- TERROR: `TerrorRoar` action (fires `TerrorWave`); dinos with Combat Scale small / species list flee for 4 s.

## Chase PURSUE lines (Chase.luau)
```lua
Coelophysis = { Scale = 1.4, Run = 58, Catchup = 68, Lunge = 0.32, Telegraph = 0.65, Recover = 0.9 },
Plateosaurus = { Scale = 1.0, Run = 46, Catchup = 54, Lunge = 0.6, Telegraph = 1.2, Recover = 1.6 },
Dilophosaurus = { Scale = 1.05, Run = 54, Catchup = 64, Lunge = 0.42, Telegraph = 0.9, Recover = 1.2 },
Postosuchus = { Scale = 1.0, Run = 55, Catchup = 66, Lunge = 0.45, Telegraph = 1.0, Recover = 1.3 },
```
Dilophosaurus Chase action spits on the windscreen (SpitGlob Splat, Range 40) at 2.93 s.

## PaddockLife REACT
```lua
Coelophysis = { Bow = 0.55, Nuzzle = 0.3, Butt = 0, Wag = 1.4 },
Plateosaurus = { Bow = 0.9, Nuzzle = 0.2, Butt = 0, Wag = 0.6 },
Dilophosaurus = { Bow = 0.6, Nuzzle = 0.22, Butt = 0.2, Wag = 1.1 },
Postosuchus = { Bow = 0.5, Nuzzle = 0.12, Butt = 0.6, Wag = 1.3 },
```
Idles available: Coelophysis Drink/Sniff/Jump; Plateosaurus Graze/Browse/Sniff; Dilophosaurus Sniff/CrestDisplay;
Postosuchus Sniff.

## Swimmer / BIG
None are swimmers. BIG (EraView gallery / reveal stage size): Plateosaurus and Postosuchus.

## ICON_PROMPTS.md
- Coelophysis: chunky toy-brick slim sandy-orange theropod with dark back stripes, long S-neck, narrow toothy head, yellow eyes, screeching mid-leap, sunrise red desert backdrop.
- Plateosaurus: chunky toy-brick olive-green long-necked biped with yellow-cream belly and faint bands, reared on its hind legs stripping a tall cycad, big cream thumb claws.
- Dilophosaurus: chunky toy-brick yellow-green theropod with dark spots and twin arched red-orange crests with white stripes glowing hot, spitting a green glob at the viewer, no neck frill.
- Postosuchus: chunky toy-brick dark brick-red croc-line archosaur with armoured back scutes, deep toothy skull, yellow eyes, standing up on its hind legs roaring out of a dry mud riverbed.

## Reveal beats (Reveals/DawnDesert.luau)
- oasis (Coelophysis, Warm): rings on a still oasis from nothing; yellow eye-glints in the reflections; the camera
  lifts to the reeds and the heads rise out of them in a line; the pack (ctx.Pack) rises on the reveal.
- canopy (Plateosaurus, Up, AtMark): a tall cycad shakes and sheds fronds with nobody near; slow tilt up the trunk to
  a head in the crown (it holds a looping Browse half-rear); the head turns down to you.
- haze (Dilophosaurus, Warm): heat-shimmer sheets; two crests burn like flames far off (particles through the
  silhouette); the pair circles; one steps out bobbing (CrestDisplay); haze clears before the reveal.
- bonewash (Postosuchus, Up, AtMark): cracked mud, a skull, a dust devil; mud bubbles; a crack runs at the lens; two
  yellow eyes surface; it erupts (crust and skull shatter) onto its mark.
