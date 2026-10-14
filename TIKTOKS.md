# TikTok recordings

Dino Expedition plays its own TikTok footage. Open **Settings → TIKTOKS** (Studio, or Dev players), pick a sequence or a single shot, and it plays a music-timed, frame-exact cinematic you screen-record in **16:9**. Every take is identical: nothing is random, and nothing in it is the live game.

## Record a take

1. Stand anywhere at Base Camp; no expedition running. The sequence teleports the camera itself.
2. Settings → TIKTOKS → click a sequence. You get 4 beats of black with a count-in, then beat 0 cuts in.
3. Press **H** to hide the help bar for a clean frame. Record the window at 16:9.
4. In the edit, put the music's first kick on the first frame after the black. Everything is cut at **123 BPM** (1 beat = 0.488 s).

| Key | While a take plays |
| --- | --- |
| SPACE | pause / resume (dinos and camera freeze) |
| ← / → | previous / next shot (re-record one shot) |
| [ / ] | back / forward one beat |
| R | restart from the count-in |
| H | hide / show the help bar |
| G | 16:9 safe box + caption band |
| C | caption preview (the sequence's hook line) |
| X | stop |

**SHOTS** at the bottom of the list plays any single shot on its own, so you can record one clip and cut it into any edit.

To change the music speed, edit `Music.BPM` (and `MusicOffset`) in `tools/gen/anim/tiktok.js` and rebuild. Every shot keeps its length in beats.

## How it's built

| Piece | File | What it does |
| --- | --- | --- |
| Shot library + sequences | `tools/gen/anim/tiktok.js` | Authored data: anchors on real roads, nests, dens and markers; actors (dinos, rovers, crew, eggs); camera keys; beat cues; scores |
| Director (bake) | `tools/gen/tiktok.js` | Solves every shot against the generated maps (ground snapping, rover pitch/roll, gait phase from real speed so feet don't skate, signature cameras with their slow-mo ramps) and writes `Game/TikTok/Data.luau`. Runs at the end of `node tools/gen/build.js` |
| QC frames | `tools/preview/tiktok.html?file=out/tt_<SEQ>.json` | Renders the baked frames at 16:9 with the safe box and caption band. `node tools/gen/tiktok.js --qc-only --shots=A,B` writes `out/tt_shots.json` for one shot at a time; `out/tt_report.md` lists automatic framing / occlusion / camera-in-rock checks |
| Player | `Game/TikTok/init.luau`, `Timeline.luau`, `Cam.luau`, `Stage.luau` | Plays the bake back frame-exact: local clones only, live players/rovers/site dinos/sleeping ruler hidden for the take, film grade + focus pull, transport keys |
| Menu | `Game/UI/Panels.luau` (TIKTOKS tab) | Sequences grouped by category, plus every shot |

## The master: TIKTOK_00_DINO_EXPEDITION_MASTER (30.7 s, 25 shots)

It cuts between cinematic shots and **gameplay clips**, so it reads like a run of videos you recorded. Gameplay clips use the game's real cameras (the drive chase cam, Roblox's follow camera, the encounter shoulder offset) and the real UI: the run HUD (staged with chosen numbers through `HUD.Puppet`), the camp hotbar, the game's prompt cards with their hold-fill, banners, toasts and the PERFECT! floater. They have no film grade.

| # | Time (s) | Beats | Shot | Kind | What you see |
| --- | --- | --- | --- | --- | --- |
| 1 | 0.00–1.95 | 1–4 | RexBumperBite | cinematic | HOOK. Low camera racing ahead of the rover, looking back: rover big in the lower frame, the T. rex looming over it, the bite lands on the beat. |
| 2 | 1.95–3.90 | 5–8 | PV_ChaseRun | gameplay | Gameplay: the real drive camera and run HUD, ESCAPE TO THE TIME PORTAL banner, raptors alongside, one flashes red. |
| 3 | 3.90–4.88 | 9–10 | TriCrossHood | cinematic | Hood cam: the rover slams on the brakes as a triceratops charges across the road a few studs ahead. |
| 4 | 4.88–5.37 | 11–11 | RaptorScreechCU | cinematic | One-beat insert: a raptor screeches into the lens. |
| 5 | 5.37–7.32 | 12–15 | PV_EggPickup | gameplay | Gameplay: third-person walk-up, the real "Pick up" prompt fills, the player lifts a LEGENDARY egg while the raptors sleep. |
| 6 | 7.32–8.29 | 16–17 | EggGrabWake (from beat 2) | cinematic | Over the shoulder: a player scoops a glowing egg; behind the nest a raptor wakes and screeches. |
| 7 | 8.29–9.27 | 18–19 | RaptorPounceRack | cinematic | Chase cam behind the rover: a raptor leaps at the glowing eggs on the rack. |
| 8 | 9.27–10.24 | 20–21 | PV_LookBackPerfect | gameplay | Gameplay: hold LOOK BACK, the raptor flashes red, a dart lands on the telegraph: the game's PERFECT! pops. |
| 9 | 10.24–11.22 | 22–23 | RexStomp | cinematic | Signature camera, ground level: the Tyrant King's foot slams down beside the lens. |
| 10 | 11.22–13.17 | 24–27 | RexKingsRoar | cinematic | Signature camera: inhale, then the slow-motion roar straight down the lens. |
| 11 | 13.17–14.15 | 28–29 | PV_RodeoPrompt | gameplay | Gameplay: over the shoulder, the Tyrant King is down and dizzy, the game's RODEO! prompt pops on it. |
| 12 | 14.15–15.12 | 30–31 | RexRodeo | cinematic | Orbit: a player rides the bucking T. rex in the final stand. |
| 13 | 15.12–16.10 | 32–33 | RexDefeated | cinematic | The ruler goes down, stars spin, the game's DEFEATED title slams over sun rays. |
| 14 | 16.10–17.07 | 34–35 | PlainsRibcage | cinematic | Golden hour: the rover drives at the lens under the giant fossil spine arch. |
| 15 | 17.07–19.02 | 36–39 | BrachioCrossing | cinematic | Ground camera on the road: a Brachiosaurus walks across in front of the lens, the rover skids to a stop just short of its legs. |
| 16 | 19.02–19.51 | 40–40 | StegoTail | cinematic | Low behind the plates as the tail spikes sweep past the lens. |
| 17 | 19.51–20.00 | 41–41 | AnkyClub | cinematic | The club smashes the ground next to the camera. |
| 18 | 20.00–20.98 | 42–43 | CarnoAmbush | cinematic | Signature camera: the Carnotaurus explodes out of cover (a later era: the "what is THAT" beat). |
| 19 | 20.98–21.95 | 44–45 | PV_HatchPrompt | gameplay | Gameplay: back at camp with the real hotbar and coins, the "Hatch" prompt fills on the SECRET egg. |
| 20 | 21.95–23.90 | 46–49 | HatchSecret | cinematic | The egg rocks, cracks in a rainbow burst, a baby T. rex pops out and tries its first roar. |
| 21 | 23.90–24.88 | 50–51 | RexRoarLow | cinematic | Low angle at its feet: the parent roars. Cut on the beat to the baby doing the same. |
| 22 | 24.88–25.85 | 52–53 | BabyRexRoar | cinematic | Match cut to RexRoarLow: same angle, same roar, a baby with a rainbow aura. |
| 23 | 25.85–27.80 | 54–57 | GigaBreakthrough | cinematic | Signature camera: the Giganotosaurus bursts in, then lowers its head to the lens. |
| 24 | 27.80–29.76 | 58–61 | GigaFlatsChase | cinematic | Locked low camera at the roadside: the truck screams past, then the Giganotosaurus fills the frame. |
| 25 | 29.76–30.73 | 62–63 | GigaLensBite | cinematic | Ending: locked close-up, the Titan bites at the camera; mouth fills the frame on the downbeat, cut to black. |

Every cut is a hard cut on the beat, except two motivated ones: the hatch flash, and the final bite that cuts to black.

## Boss reveals (2026-10-12)

Each boss's intro is now authored the same way as the TikTok shots (`tools/gen/anim/reveals.js`). The same baked footage plays as the **in-game boss reveal** (EraView → `TikTok.PlayCutscene`, with a letterbox and hold-to-skip after 1 s) and as clips for the TikToks. Settings → CUTSCENES boss previews play it too. The only on-screen text in any of them is the boss's own name, on the climax.

| Boss | Reveal | Shots |
| --- | --- | --- |
| Tyrant King | **The Puddle**: ripples on a puddle from unseen footsteps → its foot slams into the puddle (spray on the lens) → its head lowers to sniff the camera → the slow-motion roar, leaves blasting off the canopy | TK_Puddle, TK_Step, TK_Roar, TK_Hero |
| Plains Titan | **The Stampede**: a herd thunders down the canyon road at the lens → whip to the den: a black, rim-lit shape walks out of the dust → the roar, dust rolling at the lens → it snaps at the camera | GT_Stampede, GT_Emerge, GT_Roar, GT_Lunge |
| Tidebreaker | **Below the Pier**: on the sea bed looking up at the dock, the Mosasaurus glides over the lens against the light → it breaches beside the pier, name at the top of the leap, spray on the lens | TB_Below, TB_Breach |
| Scythe King | **The Harvest**: a 40-stud conifer comes down, then another toward the lens → the last falls away: it sits on its throne, claws crossed → it slashes at the lens and the screen splits along the cut | SK_Fall, SK_Throne, SK_Slash |
| Frostfang | **Whiteout**: white blizzard, a dark shape and two glowing eyes walk closer and listen → the frost roar blows the blizzard away, ice cracks race at the lens → one stomp | FF_Whiteout, FF_Roar, FF_Stomp |
| Dawn King | **Before the Dinosaurs**: a sunrise dolly to a Coelophysis drinking at a mud wallow → the wallow erupts, it bolts (it gets away) → the Dawn King rears up black against the sun and roars | DK_Drink, DK_Ambush, DK_Rise |

New cue kinds for these (played by `Game/TikTok/Fx.luau`): Sfx, Sting, Fx (an animation-event effect on an actor), Ripple, Leaves, RoarWave, Splash, LensDrops, Snow, White, TreeFall (topples a real map tree; it stands back up after), Title, Slash, Grade, Splinter, Bubbles. Actors can have a Silhouette window (black body, warm rim, glowing eyes), and there are simple Prop actors (the puddle). Shots have colour grades: Hero, Dark, Golden, Underwater, Dusk, Whiteout, Frost, Dawn, Backlit.

**The game has sound now.** The reveals carry their own sound design (footsteps, roars, splashes, falling trees), so record these takes with game audio on, and lay the music under it in the edit.

## The 7 boss TikToks (Settings → TIKTOKS → BOSS TIKTOKS)

No text on screen except the bosses' own names (already in the footage). The caption is what you paste into the post (press **C** while it plays to preview it).

| Sequence | Length | What happens | Post caption |
| --- | --- | --- | --- |
| TT_RATE_BOSS_INTROS | 15.6 s | all six climaxes back to back, one cut per beat | rate each boss intro 1-10 🦖 which one goes hardest? #roblox #dinosaur #robloxgames #fyp |
| TT_SEA_BOSS | 6.3 s | under the pier → the breach → it lunges at the lens, black | they put a SEA BOSS in a roblox dinosaur game 🌊 #roblox #mosasaurus #robloxgames |
| TT_HARVEST | 5.9 s | trees falling → claws crossed → the slash split | this dinosaur has SWORDS for hands 😳 #roblox #therizinosaurus #dinosaur |
| TT_WHITEOUT_LOOP | 6.8 s | eyes in the blizzard → the roar clears it → the blizzard closes back in (loops) | wait for it… 🥶 #roblox #dinosaur #robloxgames |
| TT_BEFORE_DINOSAURS | 6.3 s | the drink → the ambush → upright in the sunrise | the boss that's older than dinosaurs 🌅 #roblox #prehistoric #robloxgames |
| TT_STAMPEDE | 6.3 s | the stampede → out of the dust → the roar → the snap | when the whole herd runs the same direction… 💀 #roblox #giganotosaurus |
| TT_STOLE_THE_EGG | 8.8 s | you lift a glowing legendary egg in the lair → ripples → the king → the roar → it bites your rover | POV: you took the wrong egg 🥚🦖 #roblox #trex #robloxgames |

## Shot library, ranked

Scores out of 10, in order: stop-scroll / dinosaur wow / motion / readability / novelty / phone readability.

| Rank | Shot | Beats | Scores | Avg |
| --- | --- | --- | --- | --- |
| 1 | RexBumperBite | 4 | 10 / 9 / 10 / 9 / 9 / 9 | 9.3 |
| 2 | GigaBreakthrough | 4 | 10 / 10 / 9 / 9 / 9 / 9 | 9.3 |
| 3 | GigaLensBite | 2 | 10 / 10 / 9 / 8 / 9 / 9 | 9.2 |
| 4 | BrachioCrossing | 4 | 9 / 10 / 8 / 9 / 9 / 9 | 9.0 |
| 5 | RexKingsRoar | 4 | 10 / 10 / 8 / 9 / 8 / 9 | 9.0 |
| 6 | GigaFlatsChase | 4 | 9 / 10 / 9 / 8 / 9 / 8 | 8.8 |
| 7 | RexStomp | 2 | 9 / 9 / 8 / 9 / 9 / 9 | 8.8 |
| 8 | RexRodeo | 2 | 9 / 9 / 9 / 8 / 10 / 8 | 8.8 |
| 9 | CarnoAmbush | 2 | 9 / 9 / 9 / 8 / 10 / 8 | 8.8 |
| 10 | TriCrossHood | 2 | 9 / 8 / 10 / 8 / 9 / 8 | 8.7 |
| 11 | GigaRoar | 4 | 9 / 10 / 8 / 9 / 7 / 9 | 8.7 |
| 12 | BrachioFootfall | 4 | 9 / 10 / 7 / 9 / 8 / 9 | 8.7 |
| 13 | HatchSecret | 4 | 9 / 8 / 8 / 9 / 9 / 9 | 8.7 |
| 14 | RexSideRun | 2 | 8 / 9 / 10 / 9 / 7 / 8 | 8.5 |
| 15 | RaptorPackFlank | 2 | 9 / 8 / 10 / 8 / 8 / 8 | 8.5 |
| 16 | RaptorPounceRack | 2 | 9 / 8 / 10 / 8 / 8 / 8 | 8.5 |
| 17 | EggGrabWake | 4 | 9 / 8 / 8 / 9 / 9 / 8 | 8.5 |
| 18 | BabyRexRoar | 2 | 9 / 8 / 7 / 9 / 9 / 9 | 8.5 |
| 19 | ParaStampede | 2 | 8 / 8 / 10 / 8 / 8 / 8 | 8.3 |
| 20 | RexRoarLow | 2 | 8 / 10 / 7 / 9 / 7 / 9 | 8.3 |
| 21 | RexDefeated | 4 | 8 / 8 / 7 / 9 / 8 / 9 | 8.2 |
| 22 | TriCharge | 4 | 8 / 8 / 9 / 9 / 7 / 8 | 8.2 |
| 23 | PV_ChaseRun | 4 | 8 / 7 / 9 / 9 / 8 / 8 | 8.2 |
| 24 | PV_LookBackPerfect | 2 | 8 / 7 / 9 / 9 / 8 / 8 | 8.2 |
| 25 | DartPerfect | 2 | 8 / 7 / 9 / 8 / 8 / 8 | 8.0 |
| 26 | RaptorLeap | 4 | 8 / 8 / 9 / 8 / 7 / 8 | 8.0 |
| 27 | AnkyClub | 2 | 8 / 8 / 8 / 8 / 8 / 8 | 8.0 |
| 28 | RackHaul | 2 | 8 / 6 / 8 / 9 / 8 / 9 | 8.0 |
| 29 | RaptorScreechCU | 1 | 8 / 7 / 8 / 9 / 6 / 9 | 7.8 |
| 30 | PV_RodeoPrompt | 2 | 7 / 8 / 6 / 9 / 9 / 8 | 7.8 |
| 31 | StegoTail | 2 | 7 / 8 / 8 / 8 / 7 / 8 | 7.7 |
| 32 | PV_EggPickup | 4 | 7 / 6 / 7 / 9 / 8 / 8 | 7.5 |
| 33 | PlainsRibcage | 2 | 7 / 5 / 8 / 8 / 9 / 8 | 7.5 |
| 34 | PV_HatchPrompt | 2 | 7 / 6 / 6 / 9 / 8 / 8 | 7.3 |
| 35 | GateDriveIn | 2 | 7 / 3 / 9 / 8 / 8 / 8 | 7.2 |
| 36 | ValleyCrane | 2 | 6 / 3 / 7 / 8 / 7 / 6 | 6.2 |

The strongest openers are **RexBumperBite**, **GigaBreakthrough**, **RexKingsRoar**, **GigaLensBite** and **BrachioCrossing**.

## Sequences

| Id | Category | Length | Hook line (for the editor) |
| --- | --- | --- | --- |
| TIKTOK_00_DINO_EXPEDITION_MASTER | MASTER | 30.7 s | this roblox game is actually insane |
| TIKTOK_09_GAMEPLAY | GAMEPLAY | 9.8 s | the gameplay is even better |
| TIKTOK_01_BOSSES | BOSSES | 13.7 s | every era has a ruler |
| TIKTOK_02_JEEP_CHAOS | CHASES | 11.7 s | POV you picked the wrong expedition |
| TIKTOK_03_DINOSAURS_YOU_CAN_FIND | DINOSAURS | 13.7 s | every dinosaur in this game has its own entrance |
| TIKTOK_04_EGG_EXTRACTION | EGGS | 10.2 s | this is why you don't steal the egg |
| TIKTOK_05_GAME_IS_BIGGER | MASTER | 16.6 s | wait this game has THAT too? |
| TIKTOK_06_RAREST | EGGS | 5.9 s | 0.1% chance |
| TIKTOK_08_EXPEDITIONS | EXPEDITIONS | 11.7 s | we may have made the dinosaurs a little too big |
| HOOK_3S_REX_BITE | SHORT HOOKS | 2.9 s | |
| HOOK_3S_BRACHIO_CROSSING | SHORT HOOKS | 2.9 s | |
| HOOK_5S_DONT_STEAL | SHORT HOOKS | 4.4 s | |
| HOOK_5S_PARENT_BABY | SHORT HOOKS | 4.9 s | |
| HOOK_8S_BOSS_TO_BITE | SHORT HOOKS | 6.8 s | |

## What isn't in the footage yet

These features don't exist in the game, or don't exist as visuals yet, so no shot fakes them:

- **Companions / buddy dinos (TIKTOK_07)**: buddies have no fight visuals of their own yet, so the sequence was skipped. The baby T. rex hatch and parent-vs-baby beats stand in for "the thing you hatch".
- **Progression**: there's no visual upgrade moment (the rover tiers appear across shots: Rookie Ranger, Raptor Runner, Titan Transport).
- **Encounter fight HUD** (reticle, magazine, calm bar): it is built live by EncounterView from a real fight, so gameplay clips use the run HUD, camp HUD, prompts, banners and toasts instead.
- **Menus / era map proof shots**: the map and panels are interactive UI, not deterministic; add a static proof shot if you want one.
- **Weather and night**: no weather or day/night system exists. The two eras already contrast misty morning (Fern Valley) with golden hour (Giant Plains).
- **Water dinos** (Spinosaurus, Mosasaurus) and **Primal Rex**: their signatures need a water set or the containment-gate prop that the eras don't have.
- **Audio**: the game has full SFX and era music now; record with game audio on and add any trending sound under it in the edit.

## Not yet verified in Studio

Every shot was framed and checked in the offline renderer against the real generated maps and models. The in-game player has passed the Luau type check but **has not been run in Studio**. What to look for on the first take:

- **Crew stand-ins:** QC draws the crew as simple blocks. In game they're clones of your avatar, posed by PlayerAnim (drivers sit, the rodeo rider straddles).
- **Rarity auras:** egg and baby rarity auras (RarityFx), the red telegraph glow and the VFX cues only show in game.
- **Live world hiding:** check that site dinos, other players, camp NPCs, the sleeping ruler and the hatch stage's screen stay hidden for the take, and come back when it stops.
- **Gameplay clips:** the staged prompt cards need ProximityPromptService on during those shots (the player turns it on and every other prompt off); check the card appears and fills, and that the run HUD shows the staged numbers.

## Automatic checks in the bake

`tools/preview/out/tt_report.md` flags: subject off frame or in the caption band, the camera inside rock, a subject blocked by scenery, and **a rover driving through a dinosaur** (any posed dino part inside the rover's box). Small props (eggs, babies) stand on non-colliding beds and pads too, so eggs don't sink into nests.
