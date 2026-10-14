# Dino Expedition: icon + thumbnail master prompt (GPT image model, built from the REAL game models)

You are the art director and production artist for the Roblox game **Dino Expedition**. Make **1 game icon
(+1 alternate) and 5 thumbnails** that win clicks on the Roblox front page, look exactly like the real game, and
do **not** look AI-generated.

You are given **reference renders of the actual in-game 3D models** (folder `art/refs/`, overview in
`art/refs/_contact_sheet.jpg`). They are the ground truth. Every rover, dinosaur, egg and place in your images
must be **that model** (same shapes, same colours, same blocky parts), re-posed and re-lit for the shot.
Never invent a different-looking dinosaur or vehicle. The renders are plain model renders: you add the
environment, motion, lighting drama, particles and the players.

---------------------------------------------------------------------------------------------------------------

## 0. The game in one breath

Drive a safari rover through a time portal into dinosaur eras, sneak up to nests, **steal dino eggs**, calm the
guards with a dart launcher (non-lethal, kid friendly), then **escape a chase** with the dinos running you
down while the eggs bounce on your roof rack. Back home you **hatch** them (COMMON → UNCOMMON → RARE → EPIC →
LEGENDARY → SECRET), keep them on **your own island**, beat each era's **boss**, and bring **friends along in
your rover**. Players are 8–14. Exciting, funny, a little scary, never gory.

## 1. What wins on the Roblox front page right now

- The #1 game is **Steal An Egg** (1.4M players): a blocky T. rex roaring at a noob stealing eggs. Break and Steal
  an Egg and Prehistoric Farm are close by. Egg-stealing + dinos is THE trend. Ride it **without looking like a
  copy**: always show what only we have: **our yellow rover, the chase, eggs strapped on the roof, the Time
  Gate, our island.**
- Winning tiles: **one giant subject cropped tight, mid-action** · **a huge readable face reaction** · **a
  huge threat vs a small player** · **one flat loud background** (often sky blue), thick dark outlines, max
  contrast · **vehicles tilted, dirt flying, speed lines** (WRONG WAY!) · thumbnails **name a mechanic or reward**
  in big chunky text.
- Roblox ranks thumbnails by people who click AND keep playing. Everything shown must really be in the game.

## 2. The reference files and what's true about them

| File(s) | What it is | Facts to keep |
|---|---|---|
| `rover_rookie_34`, `_front`, `_side`, `_back_rack` | **Rookie Ranger**, the starter rover (the hero vehicle) | Yellow body, **green** fenders/hood stripe/door trim/roll bars, black tubular roof frame with a rolled tan bedroll, front grille with vertical bars, round headlights on a black bull bar, chunky black tyres with gold hubs, spare wheel on the back, a little yellow beacon on top. Carried eggs sit in a rack on top (see eggs). |
| `rover_raptorrunner_34` | **Raptor Runner**, rover #2 | **Orange** jeep with black roll cage, teal accents, big off-road tyres. |
| `rover_titan_34`, `_back` | **Titan Transport**, rover #3 | **Dark green armoured six-wheel truck**, orange lights, roof hatch + gear. Seats 4. |
| `dino_TyrannosaurusRex` (+ `_front`, `_side_still`) | the **T. rex** | Bright green blocky body, darker green patches, tan belly/jaw, **yellow eye**, a jaw full of white block teeth, dark-red mouth, tiny arms, long segmented tail with spikes. `_front`/main = roaring. |
| `dino_Velociraptor` | raptor | Olive/lime green, dark stripes, yellow eye, open jaw. |
| `dino_Triceratops` | Triceratops | Orange-brown body, dark-brown back plates with studs, big cream frill with orange marks, three cream horns, dark beak. |
| `dino_Parasaurolophus`, `dino_Spinosaurus` (teal + red sail), `dino_Giganotosaurus` (black + red), `dino_Mosasaurus` (blue sea reptile), `dino_Carnotaurus` (red, horns), `dino_Stegosaurus`, `dino_Ankylosaurus`, `dino_Brachiosaurus`, `dino_Therizinosaurus`, `dino_Yutyrannus` (white/grey), `dino_Postosuchus`, `dino_Dilophosaurus` | the other species | Use only when a prompt asks for that species. |
| `baby_*`, `babies_row` | hatchlings | Small versions of the adults (cute, same colours). |
| `egg_*`, `eggs_grid` | eggs | **Blocky stepped eggs** made of stacked layers (pixel-art egg shape), coloured and patterned per species, each with a little diamond gem on the front. |
| `gear_launchers`, `gear_armor_*` | the dart launchers + outfits | Players carry a chunky launcher; outfits are explorer vests/hats. |
| `place_timegate` | the **Time Gate** | Hexagonal ring of dark studded stone blocks with gold trim, **glowing light-blue nodes**, a swirling blue membrane, floating gold cubes, on a stone deck with blue guide lights. |
| `place_camp_overview`, `place_island_aerial`, `place_hub_plaza` | **Base Camp** | 8 wedge-shaped islands round a central plaza, stone bridges, turquoise lagoon, red-roofed hatcheries, log-fenced paddocks, palm trees, crater cliffs with waterfalls, a stepped volcano. |

**Truths the renders can't show (add these):**
- **Rarity glow** (in game it's a coloured sparkle + light around the egg or dino): UNCOMMON green sparkles ·
  RARE blue sparkles + glow · EPIC purple tint + rising sparks · LEGENDARY gold tint + big sparkles · **SECRET =
  rainbow** (the money shot). Colours: grey #A7ADB5, green #66D86B, blue #48A8FF, purple #AD66FF, gold #FFD447.
- **Players** are classic blocky **Roblox avatars** in explorer gear (vest, hat, launcher). Faces are big, simple
  Roblox cartoon faces with huge expressions. If the user gives you `ref_player.png`, match it.
- **The Tyrant King (boss)** is **the same T. rex model, bigger, angrier**, with a boss nameplate/health bar in
  the UI. It does **not** wear a crown in the game, so **don't paint a crown on it**.
- No blood, no wounds. Darts are bright orange with a feather tail.

## 3. Deliverables + specs

| ID | What | Generate at | Final |
|---|---|---|---|
| ICON | game icon | 1024×1024 | 512×512 PNG, opaque |
| ICON_ALT | alternate icon | 1024×1024 | 512×512 PNG |
| T1 | "OUTRUN THE T. REX!" chase | 1536×1024 | 1920×1080 |
| T2 | "STEAL THE EGGS!" nest grab | 1536×1024 | 1920×1080 |
| T3 | "HATCH A SECRET DINO" reward | 1536×1024 | 1920×1080 |
| T4 | "BEAT THE BOSS" | 1536×1024 | 1920×1080 |
| T5 | "BUILD YOUR DINO ISLAND" (+ friends) | 1536×1024 | 1920×1080 |

- Thumbnails: Roblox shows **16:9**. Compose inside the middle 1536×864 band of the 3:2 frame, then crop to 16:9
  and resize to 1920×1080. Keep the bottom-left a little clear (Roblox overlays).
- Icon: subject inside the centre 85% (corners are rounded); must read at **150 px**.
- **Text in a separate pass**: generate the art without text first; add text by editing the chosen image (or
  overlay it yourself). Check every letter; any wrong letter = redo.

## 4. Style block (start EVERY prompt with this)

> Roblox game key art made from the attached reference renders of the real in-game 3D models: keep their exact
> blocky shapes, part layout, colours and proportions, only change the pose, camera and lighting. Toy-like
> blocky 3D look built from chunky rectangular parts with studs, flat saturated plastic colours, clean bright
> lighting with a warm key light and a cool rim light, crisp thin dark outlines on the parts, high contrast,
> everything sharp. Players are classic blocky Roblox avatars with big expressive cartoon faces.
> Kid-friendly, exciting, no gore. Looks like a polished in-engine Roblox render.

## 5. "Don't look AI" list (end EVERY prompt with this)

> Do not: redesign the models, add realistic scales/skin/feathers, smooth or melt the blocky parts, add extra
> teeth/limbs/wheels/eggs, change the rover's colours, put a crown on the T. rex, add text or letters (text comes
> later), add watermarks or other games' logos, use painterly brush strokes, depth-of-field blur, film grain,
> HDR halos, or a purple-pink AI colour grade, or give realistic five-finger hands (Roblox hands are simple).

## 6. Prompts (round 1: 4 variants each)

Attach the listed references every time. Describe the scene; let the references carry the look.

### ICON: "THE GETAWAY"
Refs: `dino_TyrannosaurusRex_front`, `rover_rookie_34`, `egg_TyrannosaurusRex`, (`ref_player` if given)
> Square game icon. The T. rex from the reference lunges in from the top-right, its huge open jaw and white block
> teeth filling about 45% of the frame, yellow eye glaring, dark-red mouth glowing. In the lower-left foreground
> the yellow-and-green Rookie Ranger rover from the reference skids toward the camera tilted up on two wheels,
> chunks of dirt and white speed lines flying off its tyres. A blocky Roblox explorer leans out of the driver's
> side looking back at the T. rex with a huge terrified-but-excited screaming face, one arm hugging a glowing
> golden LEGENDARY egg (the blocky stepped egg from the reference, gold-tinted with sparkles): the single
> brightest thing in the frame. Flat bright sky-blue background, two chunky white cartoon clouds. Strong
> diagonal composition, big simple shapes, readable at a tiny size.
Variants: (a) as above · (b) lower camera, the jaw directly above the rover, about to bite · (c) the explorer
standing on the rover's seat holding the egg high, rex behind · (d) as (a), leave the bottom 22% for a title banner.

### ICON_ALT: "EGG HEIST"
Refs: `dino_TyrannosaurusRex_front`, `eggs_grid`, (`ref_player`)
> Square icon. Close-up: a blocky Roblox explorer bear-hugs a big blocky stepped egg glowing with RAINBOW
> sparkles (SECRET rarity), sneaky shocked face, sweat drop. Behind and above them the T. rex's huge head fills
> the background, eye narrowed, teeth showing, about to notice. Warm sunset-orange background.

### T1: "OUTRUN THE T. REX!"
Refs: `rover_rookie_34`, `rover_rookie_back_rack`, `dino_TyrannosaurusRex`, `dino_Velociraptor`, `eggs_grid`
> 16:9 wide action shot, low camera at road level. The Rookie Ranger speeds toward the camera down a jungle dirt
> road, three glowing eggs (blue, purple, gold) bouncing in its roof rack, dust and dirt clods flying. Right
> behind, the T. rex charges with its jaw wide open, filling the right half and towering over the rover. A
> velociraptor clings to the rover's hood. The driver looks back screaming; a second player in the passenger
> seat fires the roof dart launcher back at the T. rex (bright orange dart streaks). Bright jungle of blocky
> trees and ferns, blue sky. Clear space top-left for the title.
Text pass: **OUTRUN THE T. REX!** top-left, huge chunky cream letters, thick dark outline, orange hard shadow, slight tilt.

### T2: "STEAL THE EGGS!"
Refs: `dino_Triceratops`, `eggs_grid`, `rover_rookie_side`, (`ref_player`)
> 16:9. A blocky Roblox explorer tiptoes away from a straw nest holding a big glowing blue RARE egg over their
> head, sneaky grin. Behind them the Triceratops from the reference has just turned round, furious, steam
> puffing from its nostrils. More eggs in the nest glow green, purple and gold. A flower meadow with blocky
> ferns; the yellow rover waits in the background.
Text pass: **STEAL THE EGGS!** plus a small "!?" over the Triceratops.

### T3: "HATCH A SECRET DINO"
Refs: `egg_TyrannosaurusRex`, `eggs_grid`, `baby_TyrannosaurusRex`, `babies_row`, (`ref_player`)
> 16:9, centred. A blocky stepped egg cracks open in the middle with a huge burst of RAINBOW light, confetti cubes
> and sparkles; the baby T. rex from the reference pops out with a big happy face. Along the bottom, smaller eggs
> glow in rarity order left to right: grey, green, blue, purple, gold, rainbow. A Roblox player at the side,
> hands on cheeks, mouth wide open in amazement. Deep violet background so the rainbow pops.
Text pass: **HATCH A SECRET DINO!** with "SECRET" in rainbow letters.

### T4: "BEAT THE BOSS"
Refs: `dino_TyrannosaurusRex_front`, `gear_launchers`, (`ref_player`)
> 16:9, low camera looking up. The T. rex from the reference, much bigger than usual (the Tyrant King boss), roars
> down at two small Roblox players. One rolls out from under its stomping foot (a dust ring), the other aims a
> glowing launcher, orange darts flying. Dramatic orange sunset sky, blocky jungle silhouettes. A simple game-UI
> boss bar floats at the top (dark bar, red fill) with room for a name. NO crown on the dinosaur.
Text pass: **BEAT THE BOSS!** (make a second with **TYRANT KING** on the boss bar).

### T5: "BUILD YOUR DINO ISLAND"
Refs: `place_island_aerial`, `place_camp_overview`, `rover_titan_34` or `rover_rookie_34`, `dino_TyrannosaurusRex`
> 16:9, high three-quarter aerial at golden hour, matching the reference camp: a wedge-shaped green island in the
> turquoise lagoon with its red-roofed hatchery glowing, a log-fenced paddock with small dinos, a star pen with the
> T. rex, palm trees, the stone bridge to the round central plaza and the glowing blue Time Gate beyond. On the
> bridge the rover drives across with two friends waving from it. Crater cliffs with waterfalls behind.
Text pass: **BUILD YOUR DINO ISLAND** + a small pill **PLAY WITH FRIENDS**.

## 7. Process

1. **Round 1:** 4 variants per ID (28 images) → `art/round1/r1_<ID>_<a-d>.png`; log prompt + refs in `art/log.md`.
2. **Review** each with the rubric below (score 1–5 per line, total /40, one-line verdict). Make a contact sheet
   on a dark #121212 background (icons ~150 px, thumbnails ~300 px wide) and judge at that size.
3. **Round 2:** keep the top 2 per ID; list concrete fixes (pose, crop, face, contrast, any detail that drifted from
   the reference) and re-run with image edit on the chosen image + the same references. 2–4 tries each.
4. **Final:** best per ID; do the text pass; crop to spec; light sharpen; export to `art/final/`
   (`icon.png`, `icon_alt.png`, `thumb_1_chase.png` … `thumb_5_island.png`).
5. **Report:** finals + scores + 2 runner-ups per ID + anything that drifted from the models.

## 8. Rubric (1–5 each)

1. **Tiny-size read:** at 150 px, do you get it in under a second? (squint test)
2. **One focal point:** the eye lands on the face / egg / jaw first.
3. **Face:** a big, instantly readable emotion.
4. **Contrast:** pops on a dark page and next to bright blue tiles.
5. **Model accuracy:** rover / dinos / eggs / gate / island match the reference renders (shape, colour, parts).
6. **Not-AI:** no warped parts, extra teeth/limbs, melted geometry, fake text, mush, blur, AI grading.
7. **Unique to us:** shows the rover / chase / roof eggs / gate / island, not just "dino + egg".
8. **Promise:** a kid thinks "I want to do THAT", and it's really in the game.

**Hard fails** (discard whatever the score): garbled text · gore · a model that isn't ours (redesigned rover,
realistic or wrong dino) · a crown on the T. rex · two competing focal points · anything copying another game's art.

## 9. Optional extra references the user can add

`ref_player.png` (your avatar in expedition gear, front 3/4) · `ref_chase.png` (any in-game chase moment) ·
`ref_hatch.png` (a hatch reveal frame) · `ref_ui.png` (a screen with the game's buttons/titles, for text style).
