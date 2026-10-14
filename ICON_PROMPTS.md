# Dino Expedition: icon prompts

Generate each icon as its own image, upload it to Roblox (Creator Hub → Development Items → Decals/Images), then paste the `rbxassetid://` id into `IDS` in `src/StarterPlayer/StarterPlayerScripts/DinoExpeditionClient/Game/UI/Icons.luau`. Until an id is filled in, a placeholder badge shows in its place.

**Export:** 512×512 PNG with a transparent background, the object centred and filling about 85% of the frame.

## Style block (put this in front of every prompt)

> Roblox game UI icon, chunky stylized 3D cartoon render, toy-like blocky shapes made of rounded bricks, bold saturated colors, soft top-left key light with a bright specular highlight, thick dark navy-black outline around the whole silhouette (6–8 px at 512 px), slight 3/4 angle, no text, no background, transparent PNG, centred, matches the icon style of Roblox simulator games like Ghost Catchers and Pet Simulator.

Keep the palette jungle-adventure: lime green, expedition yellow, adventure orange, sky blue, and warm brown wood, with cream whites.

## HUD and menu icons

| Key | Prompt (after the style block) |
| --- | --- |
| Coin | a thick gold coin tilted toward the viewer, a dinosaur footprint embossed on its face, a small sparkle on the rim |
| Gem | a faceted cyan crystal gem with a lime inner glow |
| Gear | a chunky silver settings cog with a lime-green centre bolt |
| Shop | a small wooden jungle market stall with a striped orange-and-cream awning and a coin sign |
| Index | a thick leather field journal with a dinosaur skull emblem on the cover and a yellow bookmark ribbon |
| Gate | a glowing teal hexagonal time portal ring made of stone blocks, swirling energy in the middle |
| Home | a small jungle research hut with a green roof and a yellow door |
| Garage | a corrugated-metal garage with a half-open roll-up door and a yellow hazard stripe |
| Shield | a sturdy steel-and-orange armour shield with rivets, for vehicle armour |
| Bolt | a fat yellow lightning bolt with a blue glow, for boost |
| Dart | a tranquilizer dart with an orange feather tail and a glass vial of green liquid |
| Star | a plump yellow five-point star with a white shine |
| Lock | a chunky steel padlock with a yellow keyhole |
| Eye | a big cartoon dinosaur eye with a yellow iris and a slit pupil, for "awareness" |
| Alert | a red warning triangle with a white exclamation mark |
| Trophy | a gold trophy cup with a small dinosaur figure on top |
| Egg | a plain cream-white speckled dinosaur egg (keep it pale: the game tints it to each species' colour) |
| Dino | a cute baby green raptor head poking out of a cracked egg shell |
| Jeep | an orange-and-yellow safari jeep with big off-road tyres and a roof light bar, side 3/4 view |
| Hand | a gloved explorer's hand grabbing, for "grab" |
| Door | an open vehicle door with an arrow pointing out, for "get out" |
| Footprints | a trail of three green dinosaur footprints |
| Clock | an explorer's brass pocket watch |
| Map | a rolled-out treasure-style jungle map with a red X |
| Gift | a wrapped present with a lime ribbon and a dinosaur tag, for daily rewards |
| Wrench | a crossed wrench and screwdriver with orange grips, for upgrades |
| Paddock | a wooden log palisade gate with a dinosaur footprint sign |
| Incubator | a glass incubator dome on a metal base, with a glowing egg inside |

## Dinosaur portraits (key `Dino_<Species>`)

Use the same style block. Each is a cute but heroic head-and-shoulders portrait in 3/4 view, blocky Roblox-style dinosaur, the same look as the in-game models.

| Key | Prompt |
| --- | --- |
| Dino_Velociraptor | an olive-green velociraptor with dark stripes, sharp grin, feather tuft on its head |
| Dino_Triceratops | an orange-brown triceratops with a cream frill and three ivory horns |
| Dino_Parasaurolophus | a golden-yellow parasaurolophus with a long backward head crest |
| Dino_Stegosaurus | a green stegosaurus with orange back plates |
| Dino_Ankylosaurus | a grey armoured ankylosaurus with studded plates and a club tail visible |
| Dino_Carnotaurus | a crimson carnotaurus with two horns above its eyes |
| Dino_Brachiosaurus | a tan brachiosaurus with a long neck curving up, a gentle face |
| Dino_Spinosaurus | a teal spinosaurus with a tall sail on its back and a crocodile-like snout |
| Dino_TyrannosaurusRex | a green T. rex mid-roar, big teeth |
| Dino_Giganotosaurus | a dark charcoal giganotosaurus with red eyes, mid-roar |
| Dino_Mosasaurus | a deep-blue mosasaurus bursting out of a splash of water |
| Dino_PrimalRex | a pale bone-white cybernetic T. rex with glowing cyan lab tubes and a metal jaw plate |

## Vehicles (key `Vehicle_<Name>`)

| Key | Prompt |
| --- | --- |
| Vehicle_RookieRanger | a small yellow safari jeep with green trim, a roof rack and a dart launcher on top |
| Vehicle_RaptorRunner | a fast lime-green dune buggy with an orange roll cage and raptor-claw decals |
| Vehicle_TitanTransport | a huge armoured orange expedition truck with six wheels and a cargo crate full of eggs |

## More icons (round 2: bag, workshop, rulers)

Same style block. Until you paste an id, each of these shows the existing icon in brackets, so nothing looks broken in the meantime.

| Key | Prompt (after the style block) | Used for |
| --- | --- | --- |
| Bag | a chunky canvas expedition backpack in khaki and orange with a dinosaur egg peeking out of the top flap (Egg) | the BAG tile at the right of the hotbar, the bag window |
| Sell | a bulging brown coin sack with a yellow price tag on a string and gold coins spilling out (Coin) | SELL in the bag |
| Quest | a rolled parchment scroll with a red wax seal and a small green dinosaur footprint on it (Star) | quest tracker, quests window, quest waypoints |
| Power | an orange explorer's fist gripping a tranquilizer dart, with a small lightning spark (Shield) | HUNTER POWER |
| Key | an ornate bone-white key with an amber gem in the bow and a tiny raptor skull handle (Lock) | boss keys, summoning a ruler |
| Hammer | a heavy blacksmith hammer crossed over a small dark anvil with three orange sparks (Wrench) | CRAFT buttons, the crafting scene |
| Crown | a jagged golden crown made of dinosaur teeth and claws with a red gem (Trophy) | rulers and boss events |
| Film | a black-and-white film clapperboard with a small dinosaur footprint on the slate (Eye) | Settings > CUTSCENES |
| Chest | a chunky wooden treasure chest with gold bands, lid slightly open, golden glow and coins inside (Gift) | the daily chest |
| Launcher | a stubby orange-and-steel tranquilizer dart launcher pistol with a glass dart chamber glowing green (Dart) | Workshop > LAUNCHER |
| Armor | a padded khaki explorer vest with orange shoulder plates and a dinosaur-tooth badge (Shield) | Workshop > ARMOR |
| Rack | a metal roof rack carrying three dinosaur eggs strapped down with orange straps (Egg) | roof rack upgrade |
| Buddy | a small green baby dinosaur wearing an orange explorer bandana, happy, with a little heart (Dino) | buddy slots, buddy dinos |
| Gadget_Bait | a big cartoon steak on a bone tied to a rope (Bolt) | MEAT BAIT gadget |
| Gadget_Flare | a red emergency flare stick burning with a bright white-pink spark at the tip (Bolt) | FLASH FLARE gadget |
| Gadget_Earthshaker | a stubby yellow-and-black thumper device with a spring piston and a shockwave ring under it (Bolt) | EARTHSHAKER gadget |
| Mat_QueenClaw | a single curved orange raptor claw with a gold band, glowing faintly (Trophy) | QUEEN'S CLAW material |
| Mat_MatriarchScale | a big teal-green shield-shaped dinosaur scale with a pearly shine (Trophy) | MATRIARCH SCALE material |
| Era_FernValley | a round badge: green ferns and a volcano behind a teal portal, a raptor silhouette (Gate) | Time Gate list |
| Era_GiantPlains | a round badge: golden grass, a red mesa and a long-necked brachiosaurus silhouette under a big sun (Gate) | Time Gate list |
| Dino_Sarcosuchus | a giant dark olive crocodile with rows of back scutes and a long narrow snout ending in a brown bulb, yellow eyes on top of its head, half in green river water (Dino) | Sarcosuchus (Spine River) |
| Dino_Oviraptor | a teal-and-indigo feathered dinosaur with a tall orange-red head crest and a parrot beak, clutching a speckled egg under one feathered arm (Dino) | Oviraptor (Red Cliffs) |
| Dino_Protoceratops | a small sandy-tan frilled dinosaur with brown stripes and a rose-pink frill rim with eye spots, bursting out of sand (Dino) | Protoceratops (Red Cliffs) |
| Dino_Gallimimus | a grey-blue ostrich-like dinosaur with a white belly and rusty neck stripes, mid-sprint on long legs (Dino) | Gallimimus (Red Cliffs) |
| Dino_Therizinosaurus | a huge pot-bellied olive-and-rust shaggy feathered dinosaur raising giant cream scythe claws in an X (Dino) | Therizinosaurus (Red Cliffs ruler) |
| Dino_Microraptor | a tiny glossy black four-winged dinosaur with a teal-blue sheen, all four wings spread, gold eyes (Dino) | Microraptor (Frost Forest) |
| Dino_Psittacosaurus | a cute brown-and-cream parrot-beaked dinosaur with dark cheek horns and a crest of quills on its tail, peeking out of frosty ferns (Dino) | Psittacosaurus (Frost Forest) |
| Dino_Compy | a tiny ginger fuzzball dinosaur with a dark bandit mask and a long ginger-and-white ringed tail, popping out of a snowy log (Dino) | Compy (Frost Forest) |
| Dino_Yutyrannus | a huge shaggy white-and-frost-grey feathered tyrant with dark blue back stripes, roaring with frosty breath (Dino) | Yutyrannus (Frost Forest ruler) |
| Dino_Coelophysis | a slim sandy-orange dinosaur with dark back stripes, a long S-neck and a narrow toothy head, screeching mid-leap (Dino) | Coelophysis (Dawn Desert) |
| Dino_Plateosaurus | an olive-green long-necked dinosaur with a cream belly reared on its hind legs reaching for a tall cycad (Dino) | Plateosaurus (Dawn Desert) |
| Dino_Dilophosaurus | a yellow-green spotted dinosaur with twin arched red-orange crests, spitting a green glob (Dino) | Dilophosaurus (Dawn Desert) |
| Dino_Postosuchus | a dark brick-red croc-like reptile with armoured back scutes standing up on its hind legs, jaws wide (Dino) | Postosuchus (Dawn Desert ruler) |
| Mat_ScytheClaw | a single huge curved cream scythe claw with a rust-red band (Trophy) | SCYTHE CLAW material |
| Mat_FrostPlume | a frosty white-and-blue feather with ice crystals on it (Trophy) | FROST PLUME material |
| Mat_DawnScute | a red-orange armoured bony back plate with a ridge, glowing warm (Trophy) | DAWN SCUTE material |
| Era_RedCliffs | a round badge: towering red sandstone cliffs with a rock arch at dusk, a feathered egg-thief silhouette (Gate) | Time Gate list |
| Era_FrostForest | a round badge: snowy pines and a golden ginkgo tree by a frozen lake, a smoking volcano far off (Gate) | Time Gate list |
| Era_DawnDesert | a round badge: purple-pink sunrise over red dunes and striped painted hills, a crested dinosaur silhouette (Gate) | Time Gate list |
| Era_SpineRiver | a round badge: a wide blue river between spiny green cliffs with a wooden dock, a huge mosasaurus fin cutting the water (Gate) | Time Gate list |
| Mat_TideScale | a big glossy deep-blue sea-reptile scale edged in white sea foam, with a pearly shine (Trophy) | TIDE SCALE material (Tidebreaker drop) |

## Tips

- Generate all of them in one session with the same tool and settings so the lighting and outline weight stay consistent.
- If the outline comes out thin, add "extra thick black cartoon outline, sticker style" to the prompt.
- Upload, then copy the asset id from the image's page (not the decal's), so it starts with `rbxassetid://`.
