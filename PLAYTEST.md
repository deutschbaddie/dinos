# Dino Expedition: playtest guide

## 1. Get the latest build into Studio

1. In a terminal: `cd ~/dino && rojo serve --port 34900 default.project.json` (skip if it's already running).
2. In Studio, open the **Rojo** plugin and click **Connect** (localhost, port 34900). If it says connected but things look old, disconnect and connect again.
3. Accept the sync. It's large (scripts, all three maps, Lighting set to Future).
4. Optional: **Game Settings → Security → Enable Studio Access to API Services** so your progress saves between tests. Without it you play on a fresh temporary profile each time, which is actually ideal for testing the first-time experience.
5. Press **Play** (F5). For multiplayer (reviving, joining fights), use **Test → Clients and Servers → 2 players**.

## 1b. NEW: progression + onboarding rework (2026-10-12, untested in Studio)

Play this on a **fresh profile** (no API access = fresh every time). Expect roughly 25-35 minutes to Giant Plains.
1. **Cold open**: you spawn straight into a black screen, then you're driving a Raptor Runner through Fern Valley with two eggs on the rack. Steer A/D, boost SHIFT. The ground shakes, the camera whips back, and a T. rex bursts out of the trees. It lunges (red screen edges): swerve. After the first lunge, F / click darts it, and the darts just ping off. Near the portal it hits you broadside: slow motion, the rover flips, the eggs burst, white. You wake at camp, startled, and a wheel rolls past and falls over. SKIP shows after 4 s.
2. **HUD drip-feed**: at first only DRIVE (+ settings) is on screen. Coins appear after run 1, the hotbar with your first egg, INDEX after your first hatch, HUNTER POWER after the free upgrade, HOME after run 1, SHOP after run 3, ERAS after the first boss, MY ROVERS after Giant Plains. Each pops in with a sparkle the first time.
3. **Teases**: run 1 has giant footprints across the road near the arrival portal. Run 2: on arrival, before the map, the camera whips to the throne and the T. rex roars across the valley. Run 3: mid-escape, it crosses the road ahead of you. Your first takedown from run 3 on always drops a **boss key**.
4. **Summon**: with the key, the objective says SUMMON THE TYRANT KING. At the Time Gate console there's a SUMMON prompt (hold F). Everyone at camp who can fight it gets **one boss card** under the objective line: the boss's portrait and name, SUMMONED BY <you> and a 10 s countdown while the ground pulses. Then you warp straight into the fight. The first boss you ever beat always lays an **EPIC** egg.
4b. **Boss events (every 10 min)**: the same single card shows 15 s before the event, for the boss of the era your gate is set to ("BOSS EVENT / WAKES UP IN FERN VALLEY / 15"). It then turns into "AWAKE NOW!" with a JOIN button and the time left to join. X hides it for that event. The Time Gate stays blue. New players (under 3 runs, no boss beaten) don't get the card.
5. **After the boss**: you get 3 Rex Claws, enough for the Tyrant Fang (6,000 coins). Then OPEN GIANT PLAINS. The ERAS tab wiggles with a "!" badge once you can afford it. At the console, Giant Plains shows a big gold OPEN! button with an arrow (or a coin bar while you're saving). Opening it points the gate there automatically.
6. **Soft goals**: the Quartermaster visit, crafting the Fang and the summon only show the objective line at first. The waypoint and ground trail appear if you wander off or stand still for ~14 s. The Time Gate console steps always show them.
7. **Road pickups** (coins, boosts, repairs, darts) only show during the escape: not on the drive in, not on foot, not in cutscenes.
8. **Economy**: eggs are rarer (EPIC or better about 1 in 20 from a knockout nest, 1 in 33 without), nests hold 3 eggs solo (so the 3rd roof-rack slot matters), each level is +10%, and every new launcher/armour tier at L1 beats the old one at L10. Boss eggs are good but no longer break the game (T. rex earns ~2x a Fern Valley dino, not 30x).
8b. **Pets die for real**: a downed pet has 20 s (hold E on it). If it bleeds out it sinks, fades in a puff of dust and is gone from your collection, even if you win or escape. Your first 3 expeditions are the exception: there it's only knocked out and rides home in the back.
9. Say "boss", never "ruler": shout if you see "ruler" anywhere on screen.

## 2. What to play, in order

**A. A brand-new player (fresh profile)**
1. Spawn at your plot. The objective should say **PRESS DRIVE TO GET YOUR ROVER**, with an arrow on the DRIVE button. **V** also gets the rover out (and hops you out again).
2. Garage roll-out cutscene, then the controls card (WASD + SHIFT / stick + RT / drag + BOOST). Drive into the **Time Gate**.
3. Time warp, then Fern Valley's establishing shots (crane-up, grazing herd, walking dino, the Queen asleep on her throne).
4. Your first hunt is picked for you: **Horn Meadow**. It plays its discovery reveal first. Watch the drive-up, then **SCOPE IT OUT** (you, then the long lens on the Triceratops).
5. **Sneak**: walk slowly (don't sprint). The "?" over the dino fills when it sees or hears you. Either steal an egg from the nest (E to pick up), or ambush it with a dart for x3.
6. If it spots you: signature intro, FIGHT!, then dodge (Q), fire (click / hold to charge), perfect dodges, rodeo at the end. Nothing should attack, and you shouldn't be able to move or shoot, until the cutscene is over.
7. Carry each egg to your rover (**Load egg**), then **DRIVE OFF!** The chase starts: "ESCAPE TO THE TIME PORTAL" with a distance counter and a marker over the portal.
8. Back at camp, hop out (**V** or EXIT). The rover poofs and the eggs go straight into your bag. Pick one from the hotbar, carry it to a nest, press E. Watch the hatch reveal.
9. After that the objective should switch to **GO ON ANOTHER EXPEDITION**. No more "collect" step. On the era map, sites you haven't been to are black **???** pins; **EXPLORE!** plays that dino's reveal there, then drives you over. Picking a site swaps GO HOME for **BACK** (or press B / Backspace).

**B. The rulers**
- Settings → **TEST TOOLS** → **WAKE RULER** (or wait for the 10-minute event). Join from the era map's crowned waypoint.
- Check: mystery → reveal intro, the queen perching on ledges, standing on a rock (she should knock you off within ~2 s), phase 2 chase, final stand, knockout, then carrying **your** prize egg to the rover.

**C. Quick checks**
- Getting downed and nobody revives you (15 s): the screen fades to black and you wake up **on foot** at your plot (no rover), then the summary.
- Sprinting in the hub (Shift / L3 / RUN button on mobile).
- The rover camera (right-drag / right stick) feels right.
- Settings → **CUTSCENES** plays every scene. Every REVEAL is different (raptor pack in the grass, horns through ferns, plates over a hedge, a puddle rippling for the Rex, a sail in a river for the Spinosaurus, the open sea for the Mosasaurus, and so on). Each of the 12 dinos has a **REVEAL** (mystery → reveal) and a **SIGNATURE**, both filmed on location in its era. It also covers every hatch rarity.
- Settings → **TEST TOOLS**: +coins, eggs of any rarity, hatch now, all gear, all eras, teleports.

**C2. New this round (check these)**
- Fights: the launcher has a magazine (pips under the crosshair). Empty it and it reloads; a perfect dodge reloads instantly.
- Attacks land with weight: slams crack the ground and throw blocks, charges plough dust, sweeps throw dirt.
- Buddies: your first hatch becomes your buddy. It stays at your heels while you sneak and only fights once you're spotted. Each species does something different (Bag shows "BUDDY: ...").
- Unaware dinos now walk, graze and look around; when suspicious they stop and stare.
- Map cards show each site's mood (CALM / DROWSY: easier to sneak / RESTLESS: sharper senses, +1 egg).
- Chase: dart only when a chaser flashes red ("NOW!"). Spamming barely works. Your first escape is gentler.
- Big moments: ESCAPE! when you drive off, ESCAPED! at the portal, hatch rarity over sun rays, signature intros name the dino the big way, rodeo KNOCKOUT!.
- The Index pays: coins for every new entry, permanent income at 5 / 10 / 20 / 36 / 72 found.
- Economy: prices are higher (incubator 1,100, rack 1,700, Raptor Runner 23k, Giant Plains 115k). The objective line suggests the next upgrade.
- World: motes, falling leaves, butterflies and birds everywhere; Fern Valley and Giant Plains floors have colour patches.
- Audio: every slot in Game/Audio.luau is empty until you paste ids (see AUDIO.md). Settings has a MUSIC switch.

**C3. This round**
- Drive to a site: a real drive with cuts (peel-out by the wheel, drone over the road, roadside whip, braking arrival). It should always follow the road and the right branch.
- The garage roll-out pitches and bounces like a real vehicle.
- During cutscenes, other dinos step out of the camera's line; bushes in a charging dino's path vanish for the shot.
- The Professor stands on the floor; eggs sit in their nests, not half under them.
- Hovering an egg's (or the rover's / a nest's) prompt outlines it.
- Sun-ray titles only for rulers, new eras and DEFEATED!; FIGHT!/ESCAPE!/KNOCKOUT! slam in, ESCAPED! and hatch rarities stamp in, reveals use a slash name card.
- Hatching has three styles (rock, hop, spin), picked at random; Settings > CUTSCENES hatch entries show them.

**D. Devices**
- In Studio: **Test → Device** (top-right of the viewport) to emulate a phone and a tablet. Also play once with a gamepad if you have one.

## 3. How to send me what you want changed

Fastest to slowest:

1. **Output errors.** Copy any red text from the Output window and paste it. Errors are the quickest wins.
2. **Screenshot + one line.** "This X looks wrong / should be Y". Circle it if you can.
3. **Short screen recording** (QuickTime: File → New Screen Recording) for anything about feel: cameras, animation, combat timing, cutscenes. Say what felt off and when.
4. **A list tagged by area**, for example:
   - `[ONBOARDING]` the arrow covered the button on my phone
   - `[COMBAT]` raptors hit too often while I'm reloading
   - `[CUTSCENE: queen reveal]` too long, cut the eyes shot
   - `[MAP: Giant Plains]` trees in the road near Club Hollow
5. **Numbers you want tuned**: name the thing and "more / less" (e.g. "raptor sight range less", "rodeo easier"). Almost everything is a single value in `Config.luau`, so these are quick.
6. **Big ideas / redesigns**: describe the moment you want the player to have ("I want the escape to feel like…") and I'll propose options before building.

Useful extras when reporting: which device, first-time or returning profile, and roughly what you did right before it went wrong.

## 3. Spine River + the Tidebreaker (new, 2026-10-12, built overnight, untested)

Setup: Rojo picks up the new `SpineRiver` model by itself; if Studio doesn't show it, disconnect and reconnect the plugin. Then Settings → **TEST TOOLS** → **UNLOCK ERAS** (and **ADD COINS** if you want gear), set the Time Gate to **SPINE RIVER**, drive in.

**The era**
- Real water: the river, the bay and the sea are Terrain water (filled when the server starts; Output says `[WaterSetup] filled N water volumes`). Walk in and you swim. **C / Left Ctrl / L1 / the DIVE tile** dives; an AIR bar appears under water; run out and you're pushed back up.
- Route: Jungle Road → fork **The Ford** (the rover wades) or **Vine Bridge** → Spine Bend → the Sea Mouth bay → **the Sea Lane** (out on the open sea: the rover gets a boat hull, bow spray and a wake) → Carno Ridge → fork Mangrove Run / Cliff Falls (jump) → home.
- Sites: **Fishing Bank** (Spinosaurus), **Carno Ridge** (2 Carnotaurus). **Croc Creek** (Sarcosuchus) arrives when the other session finishes the species.

**The ruler: TIDEBREAKER (Mosasaurus)**: WAKE RULER while the gate is set to Spine River (it now wakes the ruler of your selected era).
1. Intro: a dark shape under the docks → a fin + the water boiling → it breaches out of the bay over the sun rays → FIGHT!
2. Phase 1, the docks: dart it while it circles. Watch for
   - **bubble ring** under you → move off it; it erupts through the dock (the planks splinter, they float back ~25 s later) and lands **stunned (weak spot)**,
   - **tail slam** in the middle → two rolling waves cross the ring: **JUMP** as each one hits,
   - **grab** (it prefers anyone in the water) → you're dragged in its jaws: **mash JUMP**; teammates **dart it 3 times** to free you.
3. At 40%: it bolts out to sea, **TO THE BOATS!** Boat chase down the Sea Lane, dart it from the rover.
4. Phase 3, **THE MAW** (rock ring at sea): same moves + the **whirlpool** (it pulls you toward the middle while lunging out of it: run outward). At the rodeo point it beaches itself on the ring: jump on.
5. DEFEATED → Tide Scales, a Mosasaurus egg, the trophy on your base's 3rd plinth. Tide Scales craft the **TIDE HARPOON** and **TIDE SHELL** at the Quartermaster.

Please send me the Output if anything errors (lines starting `[Bosses]`, `[EraView]`, `[WaterSetup]`, or red errors from SeaKing / SeaFight / BoatFx / Swim).

## 4. Bag + hotbar + hatch outcome (new, 2026-10-12)
- Open the Bag and go to the Dinos tab. Dinos in your yard have a green **IN YARD** badge and your companion has an orange **COMPANION** badge. Dinos that are just stored are dimmed with **IN BAG**.
- **HOTBAR strip** (above the detail row): drag a dino card onto a slot. With a mouse, click and move; on mobile, press and hold for a moment, then drag. You can also drop it on the real hotbar. Tap a pinned slot in the strip to take the dino off. A pinned dino shows its slot number on its card, and you tap that hotbar slot to hold it.
- **Hatch:**
  - With a free companion slot, the new dino becomes your companion.
  - Otherwise, if the yard has room, it walks off the nest, down the centre aisle *under* the hatchery roof, through the paddock door (it opens for the dino) and into the yard. It grows to full size when it gets there. You keep control the whole time.
  - If the yard is full, it's pinned to the hotbar (with a toast that says which slot).

## 5. PRE-BETA tester gate + main menu (new, 2026-10-12)
Live servers only. Studio is untouched: no gate, no menu, normal saves, no tester tags.
- Settings live in `src/ReplicatedStorage/DinoExpedition/Game/Testing.luau`: tester list (by UserId), group 902411651, Discord text, build name.
- To see it in Studio: set `Testing.PreviewInStudio = true`. Add `Testing.PreviewResult = "Denied"` or `"NeedGroup"` to see those screens (Studio never kicks). Turn the preview off again before publishing.
- Live flow: CHECKING ACCESS (tester list, group, save) over Base Camp shots, then ACCESS GRANTED, then the menu (PLAY / TESTER WALL / REPORT A BUG), then a swoop down to your plot.
- Not on the list: ACCESS DENIED, then a kick about 10 s later. On the list but not in the group: a JOIN button (Roblox join prompt) and a live re-check.
- Test saves go to `DinoExpedition_PreBeta_v1`. At launch, set `Testing.Enabled = false`: the gate and menu turn off, saves go back to the normal store, and testers keep their PRE-BETA TESTER tag.
- In game, walk up to any player and press G (gamepad X, or tap) to VIEW PROFILE. The headline is their best boss knocked out, then boss trophies, power, gear, dinos and stats.

## 6. Boss teases for every era (new, 2026-10-12, untested in Studio)
Fern Valley's three teases (footprints, the throne roar, the road crossing) now have a version in every other era, each with its own idea. They're all wordless, each plays once, and they stop once you've beaten that era's boss. Code: `Game/Omens/<Era>.luau`.
- **Fastest way to check them all:** Settings > CUTSCENES has 15 new tiles, 3 per boss: SIGN (drive past it), GLIMPSE and CLOSE CALL. They play on location with a stand-in rover, so nothing of yours moves.
- **In real play, per era:** the SIGN is always beside the road near the portal. The GLIMPSE plays on your **second** trip to that era, on arrival, before the map. The CLOSE CALL plays during the first escape after that.
- **Plains Titan:** a huge tooth stuck in a furrow by the road. Through the Giant Ribcage, a black shape walks across the road, stops, turns to stare at you, snorts and walks on (no roar). On the escape it runs alongside you and snaps at your door.
- **Tidebreaker:** a tide line across the road, far from any water: puddles, kelp, planks, a flung canoe, flapping fish. You hear a boom first, then the camera turns: a column of water over the jungle with its shape hanging at the top, then it rains fish (one lands on your bonnet). On the escape it jumps over the road in front of you where there's water on both sides. If the escape never passes water, it waits for the next one.
- **Scythe King:** stumps cut clean at a slant, and claw gouges on the canyon wall. On the canyon-gate rim it rakes a tree, freezes at a pebble click, turns to stare and slowly crosses its claws, then a hard cut to black. On the escape it stands in the road, steps aside at the last moment and cuts down the tree beside you.
- **Frostfang:** an ice fan across the road and a compy frozen in a block. Trees dump their snow one after another, coming at you, and the last one whites out the lens. A feather spins down, then a far growl. You never see it. On the escape it breathes across the road ahead and the road ices over.
- **Dawn King:** a bubbling mud wallow with a drag trench across the road. Its shadow slides over your rover, then the camera whips into the sun: it rears up on the rise behind you and leaves over the crest. On the escape the sand humps up beside the road and it bursts out snapping at your bumper.
- Close calls never slow you down or hurt you; they only jolt the camera.
- Things to report: a boss hidden behind scenery in a GLIMPSE, props floating or buried, a CLOSE CALL that clips through the rover, any `[Omens]` lines in Output.

## 7. Fight + cutscene overhaul (new, 2026-10-12, untested in Studio) - please screen-record this one
**The glitch you reported:** in every era's arrival cutscene, the second dino (the one that walks across the frame in the grass) used to climb over bushes, rocks and trees, and so did the EXPLORE reveal walk-in. Cutscene dinos now stand only on the era's real ground (`Game/Floor.luau`). They pick a walk line with nothing solid in it, small plants step aside for the shot, and their legs move at their real speed.
- **Movement everywhere:** fight and chase dinos glide between server updates instead of stop-start. Legs walk or run at the speed the body really moves (no skating). Bodies tilt with slopes, big dinos turn slower, and a pack spreads out instead of stacking. Chasers off the road run on the real ground, and bushes they run through burst and step aside. A raptor latched onto your rover stays glued to the side it bit.
- **Hits land when the body does:** a lunge or charge now hurts you when it reaches you, not the moment it sets off. Rolling out of the lane mid-dash dodges it. Every wind-up animation is stretched so the jaws or claws close on the exact frame the hit lands.
- **Telegraphs:** a bright outline that follows the ground (no more sheets sinking into hills), chevrons down charge lanes, a hot pulsing edge when YOU are standing in it, and a white flash on the strike frame.
- **Feel:** a short hit-stop and camera kick when a heavy or weak-spot dart lands, and when a big hit lands on you ("big" is now relative to your HP, so every era feels the same). Dinos face what they attack. Tail whips hit people standing BEHIND the dino; before, they swung the wrong way and never hit anyone. Attacks suit the distance and rarely repeat twice in a row.
- **Boss signature moves** (`ServerScriptService/Game/LandKings.luau`): each land boss has its own, with a name callout and a hint.
  - Tyrant King: KING'S ROAR (roll through 3 shockwave rings). At the last stand, RAMPAGE: 3 charges, then it slams the wall, dazed.
  - Plains Titan: STAMPEDE (a herd charges across in lanes; one lane is always empty). BONE BREAKER: dodge the big charge and it crashes into the rocks, dazed.
  - Scythe King: CROSSGUARD (darts glance off with "BLOCKED!"; each blocked dart triggers a counter-slash; roll through it for GUARD BROKEN). HARVEST (a spinning sweep; safe hugging its legs).
  - Frostfang: WHITEOUT (snow fills the screen, it fades to a ghost with glowing eyes and circles you, then pounces).
  - Dawn King: MUD DIVE (it sinks and a sand trail hunts you, then the ground goes red and it erupts). TERROR ROAR once angry (slows anyone in front).
- **Boss scenes:** IT'S RUNNING! now shows the boss roaring, wheeling round and charging out of the den (it used to film an empty den). The last stand shows it waiting in the stones and roaring, with LAST STAND! (no more "PHASE 3" card).
- **Balance:** the sea boss, the anti-camping slam and the leap-slam now scale with the era like every other attack (the sea boss was hitting about half as hard as it should).
- **The roll** (tester feedback: it barely moved you and you could spam it): DODGE is now a real roll of about 22 studs in half a second. It used to travel about 10, because the character's walk controller cancelled the push. Sideways it's a cartwheel, backwards a back-roll. You're untouchable for the first ~0.4 s. The cooldown is 1.6 s and a dark shade drains off the button while it recharges (pressing early shakes the button). A perfect dodge cuts the wait to 0.5 s; it used to reset it to zero, which let you chain dodges forever. All the numbers are in `Config.Player`.
- **What to record:** the arrival cutscene in 2-3 eras (watch the walking dino), one EXPLORE reveal, a pack fight (raptors), a big brute fight (a charge), a chase with a latch, and as many boss fights as you can reach (DevTools WAKE RULER). Send any `[LandKings]`, `[Omens]`, `[EncounterView]` or `[EraView]` lines from Output.

## 8. Base Camp Islands + smaller UI (new, 2026-10-12, untested in Studio)
**Why:** pre-beta testers said the plots and the hub felt cramped and mashed together, and the UI was too big on their screens.
- **Your island:** every player gets their own island in a lagoon, with a drivable bridge to the hub. It has about 2.7 times the space of the old plot plus paddock. Everything on the old plot is still there, with more room:
  - The garage door faces the drive, so the rover rolls out and you drive straight onto your bridge.
  - The hatchery is bigger, with more space between the 12 nests.
  - A new lodge.
  - A trophy hall with a plinth for all 6 bosses (the old hall only had 3).
  - The paddock is the same size, behind the hatchery. The hatchling still walks down the covered aisle into it.
  - Three dirt lots with orange survey flags are reserved for star pens (coming next), plus a ring of buoys in the water for the sea pen.
- **The hub** keeps the plaza, HQ, Quartermaster, Hatch Stage, leaderboards and the Time Gate. The gate now stands on a stone pier off the hub's north tip. The cliffs, the two waterfalls and the ridge Brachiosaurus stay behind it. A ring of crater cliffs (the volcano on the north-east corner) surrounds the whole lagoon.
- **Water:** the lagoon is real Terrain water, so you can walk off any beach and swim. The rover stops at the shoreline instead of driving onto the water, and the bridges have invisible side walls so nobody drives or falls off. If you're swimming and press V, the rover rolls out of your garage. Companions wait on the shore while you swim.
- **Moved:** the old anim showcase (the 12 dinos and 3 rovers on the baseplate) now stands south-west of camp. DevTools > Teleport > Showcase still takes you there. If your place still has the template Baseplate, the game shrinks it to a pad under the showcase when it runs, so it doesn't cover the lagoon (Studio edit mode is untouched).
- **UI size:** on a computer the UI is about 19% smaller at 1080p (24% at 1440p), and windows leave the world visible around them. Settings > UI SIZE has XS, S, M and L, and your choice is saved now. Phones and consoles are unchanged.
- **Please check:**
  - Spawning on your island.
  - Rolling the rover out of the garage and driving over the bridge to the Time Gate, then coming home.
  - Swimming off a beach.
  - The onboarding arrow trail: it should now go over your bridge.
  - The main menu's YOUR ISLAND and THE LAGOON shots.
  - Hatching and the hatchling walking to the paddock.
  - Companions following you over the bridge.
  - Your cash pad, and statues in the trophy hall.
- **Send:** any `[WaterSetup]`, `[Drive]` or `[Vehicles]` lines from Output, plus a screenshot of anything floating, buried or blocking a path.

## 9. Island upgrades + star pens (new, 2026-10-12, untested in Studio)
**How it works:** every building you can upgrade has a blueprint board next to it (a blue easel with a hammer). Walk up and press E. Upgrades cost coins plus boss materials, and you'll see each one appear on your island with a short dust-cloud moment. The boards only work on your own island.
- **Hatchery II / III:** eggs hatch 25% / 45% faster, with room for 15 / 18 nests. The third row of nests (13-18) runs down the middle under tarps until you build them. II adds copper heat boilers and eave lights; III adds a glass lantern on the roof and a brass incubator engine by the door. Costs: II is 40k + 3 Rex Claw, III is 1.2M + 3 Tide Scale + 2 Titan Scale.
- **Workshop / Hangar:** rover repairs (when it flips in a chase) cost 30% / 60% less and fix 80% / 100% of the damage (the plain garage fixes 60%). The Workshop is a lean-to with a welding bench and an engine hoist; the Hangar is a big arched shell over the garage. Costs: Workshop is 25k + 2 Rex Claw, Hangar is 3M + 3 Scythe Claw + 2 Tide Scale.
- **Star pens:** the three flagged dirt lots and the buoy ring in the water. Each boss species gets its own pen:
  - REX PIT (T. rex), GIGA RUN (Giganotosaurus), SCYTHE GROVE (Therizinosaurus), FROST DEN (Yutyrannus) and MUD WALLOW (Postosuchus) go on the land lots.
  - The SEA PEN (Mosasaurus) sits out in the lagoon.
  - Building one moves your best dino of that species in. It wanders inside the pen and earns without taking a paddock slot.
  - Every pen with a star in it adds +10% to your whole island's income.
  - A species you don't own yet shows locked, with the boss it comes from.
  - If you later get a better one, the board offers MOVE IN.
- **Quartermaster > BASE** has an ISLAND UPGRADES row with SHOW ME, which puts a waypoint on the next board.
- **Testing shortcuts:** in Settings > Test Tools, use BOSS EGGS (one egg of every boss species), MATERIALS and COINS, then FINISH EGGS. MAX BASE also maxes both buildings.
- **Please check:**
  - Every board's prompt only shows on your own island.
  - Each upgrade appears in the right place: the hatchery add-ons around the hatchery, the workshop behind the garage, the hangar over it.
  - The garage door, roll-out and Ride Shop still work under the hangar.
  - A star walks around inside its pen; the Mosasaurus swims in the sea pen.
  - The +10% shows up in your income.
  - Selling a pen star leaves the pen empty, and MOVE IN fills it again.
- **Send:** any `[IslandView]` lines from Output.

## 10. Full review pass + carpool riders (new, 2026-10-13, untested in Studio)
**Cutscenes that were broken or wrong:**
- **Plateosaurus reveal:** it was playing Microraptor's canopy scene, because two eras used the same beat name. It now has its own scene, and a name clash now prints a warning in Output.
- **Protoceratops reveal:** the lead rises out of its own mound. Before, it came up out of bare sand next to it.
- **Gallimimus reveal:** the stampede runs on the real ground instead of sinking into or floating over slopes.
- **Every era arrival:** the era's glow (bloom) used to stay at a half-faded value for the whole run. It's correct now.
- **Establishing shots:** dinos you haven't found yet can appear, but are never named before their reveal.
- **Sea boss:** the last "PHASE 3" card is gone; it's LAST STAND! like the land bosses.
- **Boss loot card:** it waits until the DEFEATED! scene ends and stays up 5 s. It used to pop up over the knockout.
- **DEFEATED! scene:** if a teammate lands the knockout during your last-stand intro, it now waits its turn instead of being lost.
- **Boss music:** the boss theme stops when the fight ends. It used to stay stuck under every later track.
- **Fern Valley:** the run-2 roar can be skipped. The run-3 crossing T. rex runs on the ground and knocks ferns aside, and it isn't marked "seen" unless it actually played.
- **Omens:** Dawn King, Scythe King and Frostfang stand and walk on the real floor (no boulder tops, no sinking). A close call never plays over another cutscene or the warp home.
- **Skipping:** the cold open's wake-up, the first warp and the hatch build-up are all skippable after 1 s. A fresh press is needed, so holding fire or resting a thumb on the stick no longer skips by accident.
- **Hatching:** the baby stands on the nest floor instead of hovering, and the egg keeps its rarity glow. An error part-way can't freeze you any more. HATCH previews refuse to run while you're seated in the rover.
- **Small fixes:**
  - SPOTTED can't be released early by another scene ending.
  - A reveal is only marked seen once it really played.
  - The scope-out is full the first time at a nest and short after.
  - The map comes back if a site vanished during its reveal.
  - The whip-pan camera no longer ends up inside rocks.
  - Glimpse titles don't appear after a skip.
  - Cutscene hit effects only react to the dino in the shot.
  - The trip-home year counter starts from the era you're leaving.

**Fights and chases:**
- **Inputs during cutscenes:** fire, gadgets, put down and ball throws are ignored while a cutscene plays.
- **Darts:** never target your own companion or site dinos. A boss chaser never shows "CALM 9998/9999".
- **Pickups:** a pickup you took can't pay out again in a second chase.
- **Rack eggs:** eggs with no slot, or on a wrecked rover, hide instead of floating.
- **On-foot bites:** the "N MORE AND YOU'RE DOWN" count is right.
- **Revives:** leaving and rejoining a boss fight no longer adds a revive each time.
- **Gamepad:** boss cards join with D-pad right, and the FLIPPED card takes gamepad focus.
- **Touch:** PUT DOWN moved above the gadgets and MAP moved to the top left, out of the thumbstick's area.
- **Rodeo hint:** names the right button on every device.

**Carpool riders:** riders built with the other chat.
- Sit in someone's rover at camp (RIDE ALONG). You warp with them and step out at every nest they pick to fight. Eggs you grab go straight to your bag.
- In a boss chase you ride along, then step out at the last stand. Boss coins and the boss egg are yours. If you go down you wake up in the back seat.
- You have no MAP, DRIVE OFF or darts; the driver decides. Banners tell you what's happening, with a short fade while they travel.

**Please check:**
- The Plateosaurus, Protoceratops and Gallimimus reveals.
- An era arrival: does the glow look like the era's normal look after the first cutscene?
- Win a boss fight: DEFEATED!, then the loot card, then the music goes back to normal.
- Skip the first warp and a hatch at 1-2 s.
- A two-player carpool: warp in, both fight at a nest, the rider's egg lands in their bag, drive home together.
- **Send:** any `[EraView]`, `[Hatch]`, `[Omens]`, `[Foreshadow]` or `[Warp]` lines from Output.

## 11. Build 0.25 features (new, 2026-10-13, untested in Studio)
**Eggs**
- **Rarity shows on nest eggs from the start** (glow and hover tip). A takedown, or your companion sniffing an egg out, can lift an egg's rarity: it flashes and comes back brighter. Pity only counts when you actually pick an egg up.
- **New pickup card:** in the rarity's colour, with the egg, rarity name, species and weight. Rare and up get a shine sweep; Epic and up land with a punch; Secret cycles the rainbow.
- **Boss eggs are shared:** one per winner is laid in the nest, first come first served, one each while a teammate still has none. Your first-clear EPIC/RARE promise applies to whichever egg you grab. Leave without one and the plainest one left goes on your rack.
- **Mid-run rack swap:** at a nest, by your rover, T (or D-pad left on a controller) on a rack egg takes it off. Holding an egg already, it swaps. Set it down (G) and grab a better one. Rack eggs you took off go back on if there's room when you leave.

**Fights**
- **Smarter Fern Valley dinos:** they sidestep some darts (never mid-swing, an ambush, a weak spot or a charged shot), flank you with one coming from behind, and roar for help when half calmed. Horn Meadow has a baby Triceratops guard.
- **First fight:** your very first fight (Horn Meadow) hits harder so you learn to dodge, but you can't be knocked out in it.
- **Anti-cheese:**
  - Standing on a rock, log or rover roof: after a moment your darts only do 30%, and the dino rams the rock and knocks you off.
  - A dino that can't reach you leaps over whatever is in the way.
  - Darts at a dino behind a wall hit the wall.
  - No messages, you just see it.
- **Caught up close:** if a dino catches you right in its face during a spotted or boss intro, it really hits you when the scene ends: thrown back, 15% health, never a knockout.
- **Rodeo:** jump on with E (X on a controller). While the RODEO! prompt is up, the egg prompts hide, so E can't grab an egg by mistake. The server watches the ride and ends it if you lose the green too long.

**Era mechanics**
- **Gliding:**
  - Microraptor companion (GLIDE): hold jump while falling to glide, and your dodge in the air becomes a longer air dash.
  - Glider Pines Microraptors start up in the trees, dive down on you, and sometimes climb back up to dive again.
- **Speed:** a Gallimimus companion (SPRINT) makes everyone at the nest run 20% faster and refills your rover boost faster. Enemy Gallimimus sidestep darts.
- **Egg thieves:**
  - Oviraptor companion (EGG GUARD): catches one egg a run that would have fallen off the rack.
  - In a chase, an Oviraptor lunge plucks an egg and drops back with it; dart it and the egg lands back on your rack.
  - In a fight, its beak snatch knocks the egg out of your arms.
- **New nest types:**
  - **Thief's Ledge is a Rival nest:** Oviraptors sneak in egg by egg and run off with them; dart a carrier and it drops the egg.
  - **Log Warren is a Swarm:** 10 tiny Compys, each down in a couple of darts.
- **Frost Forest Frozen Lake:** the ice road is slippery, so you slide wide through turns.
- **Spine River ford:** a Sarcosuchus may lie in wait where the road enters the river and lunge across as you splash through. Brake, swerve or dart it.

**Warp**
- You travel through deep space (stars and nebulae) instead of over the blurred map.
- Your companion floats behind you, and the camera swings round to show it mid-trip.

- **Riders and boss eggs:** a carpool rider takes one egg per nest, plus their share of a boss nest.
- **Gamepad:** on a boss card, D-pad left joins and B closes it.

**Please check:**
- **Glider Pines:** the Microraptors on their perches, the dives, the climbs back up.
- **Thief's Ledge:** the thieves take eggs; a dart makes one drop it.
- **Log Warren:** 10 Compys.
- **Anti-cheese:** stand on a big rock and fire.
- **Ford:** a Spine River escape through the ford.
- **Boss nest:** a boss win with 2 players.
- **Rack swap:** a swap at a nest with a full rack.
- **Send:** any `[Encounter]`, `[Hatch]`, `[Warp]` lines from Output.

## 12. Tester fixes + new boss reveals (2026-10-14, untested in Studio)
- **T. rex out of the arena:**
  - Bosses never leap after you any more.
  - Every dash or ram ends inside the arena.
  - Being knocked back near the arena edge throws you inward.
- **Mosasaurus EXHAUSTED:** it hauls itself onto the intact dock (or Maw ring) spot nearest the hunters, head on the deck, so you can reach it for the rodeo. It no longer floats over the water or ends up on the bank.
- **"Dino teleports":** a long ram or leap now takes real time instead of a third of a second.
- **No boss is visible before its reveal:**
  - The sleeping boss on its throne is gone.
  - The first-arrival glimpse shows only a dark shape with burning eyes.
- **New T. rex reveal:**
  1. At the lair mouth, two thuds and the light dies.
  2. In the black, two eyes open high up right ahead.
  3. It breathes, and its head comes down to the lens.
  4. Light floods back on the roar: TYRANT KING.
- **New Tidebreaker reveal:**
  1. On the dock ring, the bay goes dead calm and dark, and a ring of bubbles boils up.
  2. From high above, a huge dark shape circles under the docks, eyes burning.
  3. It breaches: TIDEBREAKER.
- **Please check:** both reveals in game (DevTools WAKE BOSS in Fern Valley and Spine River), and the exhausted Mosasaurus landing on a dock.

## 13. Boss chase rework, reveal polish, admin roles (2026-10-14, untested in Studio)
- **First boss reveal:**
  - The real T. rex is off the screen from the moment its intro starts, so there's no one-frame flash before the dark.
  - The roar plays out in full; the hero shot after it is a quiet head-lower with a growl, not a second half-roar.
- **IT'S RUNNING is gone:**
  - No stamp, no banner, no "TO THE BOATS". You just see it bolt.
- **You chase IT:**
  - After the flee scene you're already rolling, with the boss out ahead on the road.
  - Pacing:
    - It holds a lead. Close in and it surges; fall behind and it eases off, so it's always in front of you.
    - It weaves between lanes.
    - Sit right on its tail in its lane and it winds up and kicks back at you, so swerve.
    - Every dart makes it stumble and calms the real boss.
  - Just before its arena it peels off the road into it, then the LAST STAND scene.
- **Quiet passengers:** your companion's footsteps are silent while it rides in the rover or floats through the time warp.
- **Admins:**
  - SickleEdge has MAKE ADMIN / REMOVE ADMIN on any player. Made admins are saved and work on every server right away.
  - Only SickleEdge and NotTufferson can ban, unban or ban by username; every other admin can kick.
- **Please check:**
  - The Fern Valley boss from start to finish: reveal, flee, chase him to the arena, last stand.
  - Making an admin, rejoining, and checking they still have the tab.

## 14. PRE-BETA 0.3: finished features (2026-10-14, untested in Studio)

`git pull` in your dino folder first; Rojo picks the changes up. Settings → **TEST TOOLS** gives eggs of any rarity, which makes these quick to check.

**A. Egg Fusion** (the Fusion Nest beside the Egg Keeper)
1. With no matching eggs, the nest just glows softly. Press E on it: the EGG FUSION window lists what you hold, each row showing how many of 3 you have and "NEED N MORE".
2. Get 3 eggs of the same dino and rarity. The nest should pulse brighter and show **1 READY!** over the pod.
3. FUSE on that row: the window closes and the cutscene plays. The three eggs sit in the cradles, glow, spiral into the pod, it flares, and the new egg drops into the middle cradle with its rarity glow and a big rarity title. Tap after 1 s skips to the reveal; tap again ends it.
4. You end up back in control with the camera behind you. The bag has 1 egg one rarity up, and the 3 are gone.
5. FUSE ALL with several trios: one cutscene (the rarest result) with "+N MORE", then a "FUSED N EGGS" toast.
6. Try fusing while trading, on an expedition, or far from the nest: each refuses with a clear message.

**B. Dino names + the Showcase pedestal** (the turning pedestal by your bridge)
1. Bag → DINOS → tap a dino → **NAME**. Type a name (16 letters max, counter shown), SAVE. The card, the yard tag over its head and the Companions window show the name in yellow.
2. Try a rude word: it should refuse ("THAT NAME ISN'T ALLOWED"). RENAME → SPECIES NAME clears it.
3. In the same detail bar, **SHOWCASE**: the dino appears on your pedestal, turning slowly with the platform, its lights tinted to its rarity, a name card over it with "<YOU>'S STAR". The button now reads ON SHOW (tap to take it down).
4. At the pedestal, **Pick a star** opens the SHOWCASE picker. Star pen dinos say IN STAR PEN and can't be picked.
5. Showcase a Mosasaurus: it should swim in a glass tank on the platform.
6. Sell or trade away the showcased dino: the pedestal empties and you get a toast.
7. With 2 players, check the other island's pedestal shows their star.

**C. Index rewards, titles, secrets** (INDEX button, top right)
1. The INDEX button gets a red number when a reward is ready. Three tabs: DINOS (as before), REWARDS, SECRETS.
2. REWARDS: species-track nodes and era pages. A ready one glows with CLAIM. Claiming shows toasts for coins, permanent +% LUCK / POWER, and a title.
3. Claiming a title puts it over your head (pixel text, coloured; DINO MASTER is rainbow) and on your profile card. Swap or remove it in the TITLE row.
4. Completing an era page turns that boss's trophy statue at your island polished gold, with sparkles and a gold outline.
5. SECRETS: pick an era on the left; the right lists its landmarks, nests, the stash, wild, shiny and boss. Unfound ones are "???" with a hint ("A WATERFALL").
6. In an era, drive to a landmark: a **SECRET FOUND!** banner with "3 / 14". Finding all of an era's secrets plays **ALL SECRETS!** and unlocks its rover paint.

**D. Luck events + boosts** (top-left chips)
1. Settings → ADMIN → start 2x LUCK (or wait 15-35 min): everyone gets a "2x LUCK EVENT!" banner and a chime, and a chip with a countdown appears top-left.
2. Start it again while it runs: "+15 MIN OF 2x LUCK!". When it ends: "THE 2x LUCK EVENT IS OVER".
3. Two Roblox friends in one server: a "FRIENDS HERE" chip (+10% luck and power each). Tap any chip to see what it does.
4. Index bonuses now really apply: claim a +% POWER node, stand on your trainer pad and the "+N" pops should grow by that much.

**E. Trainer + Guess the Dino fixes**
1. Upgrade the trainer: the window updates straight away to the next level and price (it used to keep the old one).
2. While the quiz is open on your pad, the trainer's Upgrade prompt doesn't open a window underneath it.
3. The quiz now pays about 4-10 seconds of training per right answer, so quizzing on the pad earns up to ~3x standing there (it was ~7x).

## 15. Weather + meteor showers (2026-10-14, untested in Studio)

Settings → ADMIN has two new buttons: **WEATHER** (rolls in the next weather now) and **METEORS** (starts a meteor shower). They're quicker than waiting 10-15 minutes. The weather sounds are silent until the 8 files in AUDIO.md ("Weather + meteors") are uploaded. Until then thunder and meteor impacts use the stomp and earthshaker sounds.

**A. Weather** (press WEATHER to step through: clear → rain → thunderstorm → fog → wind → hail)
1. Each change shows a toast ("IT'S STARTING TO RAIN"). The sky fades into it over about 25 s: no snapping.
2. **Rain**: grey and darker, streaks falling and slanting a little, splashes at your feet. Walk under a roof (HQ, a shop awning, the garage): the rain stops around you. Step out: it comes back. Driving a rover keeps the rain on.
3. **Thunderstorm**: much darker, heavy rain, strong slant. Every 5-13 s a bolt hits somewhere in the distance, the screen flashes, and thunder comes a beat later. A **STORM LUCK +20%** chip appears top-left once it has fully rolled in.
4. **Fog**: thick haze, and a low mist drifting along the ground.
5. **Strong winds**: faint streaks racing past, leaves blowing sideways. In Dawn Desert / Red Cliffs the streaks and haze are dusty orange.
6. **Hail**: white pellets falling and bouncing off the ground.
7. Go to Frost Forest during rain or a storm: it snows hard instead, with no lightning and the toast says snow/blizzard.
8. Hatch an egg or warp during a storm: no rain or bolts inside the cutscene, and the storm is back when it ends. Fight the Frost Forest or Spine River boss: its own whiteout/storm takes over, then the weather comes back afterwards.
9. Leave it alone: a new weather every 10-15 minutes, never the same twice in a row. Two players should see the same weather.

**B. Meteor showers** (at camp: press METEORS, or wait 12-25 min into a server)
1. A **METEOR SHOWER!** banner. 20 s later fireballs streak in from the sky (all from the same side) for about 90 s and slam into the hub ring and onto the islands of players at camp: a flash, a shockwave ring, dirt and cracks, a shake if you're close.
2. Each one leaves a glowing **METEORITE** with a star marker over it you can see from across camp. Hold E: "+N COINS - METEORITE" and that rock goes dark for you (still glowing for others, who can collect it too). The ones on an island are only its owner's (no prompt or marker for anyone else). Rejoin mid-shower: the rocks you already had stay dark.
3. One per shower is a bigger cyan **STAR METEORITE** at the hub: it gives an egg from your eras (coins instead if your egg bag is full).
4. Rocks never land on roofs, in water, in your paddock or jammed against walls / trees.
5. About 75 s after the last one lands they all disappear and a "THE METEOR SHOWER IS OVER" toast shows. Someone on an expedition gets a toast instead of the banner and sees no fireballs.

## 16. Net gun + the carpool rover fix (2026-10-14, untested in Studio)

**A. Your own rover after riding along**
1. Ride in a friend's rover on their expedition and hop out to fight at a nest. Ride home with them (or get sent home on foot).
2. Get in your own rover at camp: it drives normally (before, it sat still with the drive buttons up).

**B. Net gun** (Quartermaster → GADGETS: NET GUN, 15,000 coins, BUY)
1. It goes into an empty gadget slot. In a fight, aim at a dino and press its slot key (1 / 2, or tap the tile).
2. A net flies out, spinning open, and wraps the dino. "NETTED!" pops over it, it stands stunned for 3 s, and every dart on it calms 35% more while it's caught.
3. Now and then a normal dino slips it (about 1 in 10): "DODGED!" and the net drops in the dirt. Bosses dodge it a lot more (almost half the time), only stay caught for about 2 s, and always slip it during a leap, a dive or their reveal.
4. With nothing under your crosshair: "AIM AT A DINO FIRST", and no recharge is used up.
5. Recharge is 20 s.

**C. Trainer pad pose** (your island's trainer)
1. Step onto the glowing pad: your launcher appears in your hand, you turn to face the target and raise it, and every shot kicks back as the beam leaves the barrel (+N POWER pops as before).
2. Walk around on the pad: you can still move and turn freely. Stand still: you turn back to the target.
3. Step off: the launcher disappears and your arms come down. Other players see you training the same way.

**D. The Sightseer** (one in every era, optional: no quest list, no goal line, no onboarding)
1. Out exploring an era on foot, look around its landmarks: a tourist in a sun hat and flowery teal shirt, with a camera and a map, stands a few steps off one of them under a THE SIGHTSEER tag (never near a nest).
2. Talk: they ask you to spot a few sights. SURE! gives up to 3 leads you haven't found yet, each with a hint, a direction and a distance ("a waterfall (north-east, about 300 steps)").
3. Find one: SECRET FOUND! as usual, plus a "SIGHTSEER: 1 / 3 SPOTTED" toast. All of them: "ALL SPOTTED! GO TELL THEM".
4. Talk again: CLAIM REWARD pays coins (a few minutes of your yard's income) and some trainer POWER, then they offer another hunt. With every landmark found: "You've shown me every sight".
5. The Rangers at each era's start can be talked to while you're on foot now too (before, Talk did nothing out in an era).

**E. DRIVE away from your island**
1. Anywhere that isn't your own island (the hub, the ring road, a bridge, someone else's island), press DRIVE: the rover appears right where you stand (the poof), facing your way.
2. On a bridge, or squeezed against a wall / rail, it turns to fit (along the bridge) or shifts just far enough to fit. It never sends you back to your garage for that.
3. On your own island, DRIVE still rolls it out of your garage. Swimming in the lagoon also uses the garage (no rover on water).
