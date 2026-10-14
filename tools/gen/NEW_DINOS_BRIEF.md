# New dinos brief (2026-10-12)

Design source: Claude Doc "Dino Expedition — New Dinos and Eras"
(https://claude.ai/code/artifact/033e535e-9fd7-4601-9488-0254ee3e79ea). Style bar: chunky studded toy-like Roblox
bricks (Ghost Catchers look), bold saturated colour, low 3/4 hero angles, cinematics must be perfect.
Sizes are in studs and follow the existing roster (Velociraptor ~6 long, Triceratops ~13, Stegosaurus ~15,
Spinosaurus ~23, Giganotosaurus ~27, Brachiosaurus ~32 long / 29 tall).

Every species gets: geometry rig (tools/gen/dinos/<file>.js), animation profile with its OWN signature action
(tools/gen/anim/<file>.js), its own signature shot list, a reveal beat (mystery -> reveal) that no other dino uses,
an egg look, a baby, takedown attacks, a chase line and a buddy role.

## Red Cliffs (Gobi, 75M BC) — red sandstone, ochre dunes, dusk light

| Id | Size | Look | Signature cutscene | Reveal beat (mystery -> reveal) |
| --- | --- | --- | --- | --- |
| Oviraptor | ~6 long, 4 tall, biped | Teal/indigo body, cream belly, feathered arm fans with bands, tail fan, toothless parrot beak, tall rounded orange-red head casque | EGG HEIST: darts in, scoops an egg prop under its arm, freezes as if caught, flares arm fans + casque, honks | Eggs vanish from a nest one by one between cuts; a shadow darts behind rocks; caught red-handed holding the egg |
| Protoceratops | ~7 long, 3.2 tall, quadruped | Sandy tan with brown stripes, broad frill with rose-pink rim + eye-spots, beak, nasal bump, no horns | SAND BURST: buried in a dune, bursts up, shakes sand off, frill flash, head-butt shove | Dune mounds breathe; a frill edge pokes up; four burst up around the camera |
| Gallimimus | ~16 long, 8 tall, long-legged biped | Grey-blue, white underside, rusty neck stripes, small beaked head, short feather fans | FLOCK SPRINT: a flock streaks across the lens at full speed, the lead skids, wheels, stares, shrieks | Dust plume on the horizon racing closer; a stampede of shadows blurs past; the lead stops dead |
| Therizinosaurus (ruler) | ~30 long, 16 tall, pot-bellied biped | Dark olive + rust shaggy feather tufts on arms/neck, small beaked head, long neck, three 4-5 stud scythe claws per hand (cream) | SCYTHE HARVEST: rakes a tree's branches down, turns, raises claws in an X, rears tall and hisses; a claw rake slices toward the lens | (ruler — boss intro, not a site reveal) |

## Frost Forest (Early Cretaceous, 125M BC) — snow, ice blue, dark pines, ash grey

| Id | Size | Look | Signature cutscene | Reveal beat |
| --- | --- | --- | --- | --- |
| Microraptor | ~4 long, 2 tall | Glossy black with blue-teal iridescent highlights, four wings (arm + leg feather panels), long tail with a feather fan tip | SHADOW GLIDE: drops from a branch, swoops across, lands on a stump, spreads all four wings in a shimmer display, chirps | Snow drifts down off branches overhead; a dark shape glides over the camera; it lands right in front |
| Psittacosaurus | ~6 long, 3 tall, biped | Countershaded: dark brown back, pale cream belly, dark chin + cheek horns, parrot beak, a row of quill bristles on top of the tail | HIDE AND SQUEAK: hidden in undergrowth, a twig snaps, head pops up, tail quills fan, squeal; the herd peeks out | The undergrowth rustles in several places; nothing is there; then a dozen eyes blink open in the ferns |
| Compy (species id `Compy`, display COMPY, real name Sinosauropteryx) | ~3 long, 1.4 tall | Ginger-brown fuzz, very long tail with white/ginger rings, dark bandit mask over the eyes | SWARM: one pops out of a hollow log, then a dozen pour out around the camera, all chirp | Tiny tracks appear in the snow from every side, closing in on the camera; the swarm pours out |
| Yutyrannus (ruler) | ~28 long, 13 tall, feathered tyrannosauroid | Shaggy white-grey feathers, dark grey-blue back stripes, snout crest ridge, longer three-fingered arms | BLIZZARD KING: emerges out of a whiteout, shakes snow off its feathers (cloud burst), breath plumes, roars and the pines dump their snow | (ruler) |

## Dawn Desert (Late Triassic, 215M BC) — red dunes, orange rock, sunrise purple, oasis teal

| Id | Size | Look | Signature cutscene | Reveal beat |
| --- | --- | --- | --- | --- |
| Coelophysis | ~8 long, 3 tall, slim biped (pack of 5) | Sandy orange, dark back stripes, long neck, narrow toothy head | OASIS STRIKE: the pack drinks; one lifts its head; all snap round in unison and leap onto rocks to screech in chorus | Ripples in the oasis water; many reflections; heads rise out of the reeds in a line |
| Plateosaurus | ~20 long, 9 tall (14 reared), long-necked biped | Olive-green back, yellow-cream underside, faint bands, small head, big thumb claws | TREE REACH: rears up on its hind legs to strip a tall cycad, then drops with a dust-ring slam and bellows | A tall tree shakes and loses fronds with no one near; the camera tilts up to a head in the canopy |
| Dilophosaurus | ~16 long, 7 tall, biped | Yellow-green with dark spots, twin thin arched crests (red/orange with white stripes), notched upper jaw | CREST FLARE: crests flush bright, head-bob display, then a green spit glob at the lens (screen splat; movie nod, no neck frill) | Two crests glow through heat haze like flames; a pair circles; one steps out bobbing |
| Postosuchus (ruler) | ~22 long, 8 tall, croc-line archosaur | Dark brick/maroon, bone-white teeth, yellow eyes, a row of back scutes, deep skull; stands up on its hind legs | BEFORE THE DINOSAURS: rises out of dry riverbed mud, stands on its hind legs, jaws wide, dust roar | (ruler) |

## Spine River (for the Spine River session's CROC CREEK site)

| Id | Size | Look | Signature cutscene | Reveal beat |
| --- | --- | --- | --- | --- |
| Sarcosuchus | ~30 long, 5 tall, giant croc, sprawling quadruped + swimmer | Dark olive/brown, lighter belly, heavy back scute rows, long narrow snout with a bulbous tip (bulla), yellow eyes on top of the head | LOG THAT ISN'T: floats still like a log (eyes only), eyes open, jaws burst up with a snap, death-roll splash, hiss | Four logs drift; the camera checks each; the last one blinks |
