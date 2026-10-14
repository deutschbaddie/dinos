# Dino Expedition: sound design

Every sound plays through a named slot in `src/StarterPlayer/StarterPlayerScripts/DinoExpeditionClient/Game/Audio.luau`. An empty slot is silent.

## How to do it

1. Click a **Download** link. Each one is Mixkit's direct `.wav` download.
2. Upload it to Roblox in Creator Hub → Development Items → Audio, and name the asset after its slot.
3. Send me the ids as `Slot = 123456789`.

Uploading isn't free-form: Roblox limits audio uploads per month (verified-ID accounts get much more room), so go in tier order. Every file here is under Roblox's 20 MB limit. The largest is Whirlpool at 19.1 MB; if Roblox rejects it, export it as .ogg or .mp3 first.

**Music doesn't come from Mixkit.** Mixkit's free music license bans use in video games (its sound-effects license allows it). Take music from the Roblox Creator Store instead (see the bottom of this file).

## How the sounds will be mixed

I picked these by comparing their waveforms as well as their names: how fast each one hits, how long its tail rings, how loud it is, and whether a loop holds a steady level. Sounds that took too long to hit or were nearly silent were swapped out. When they're wired in:

- **No repeats.** Roars and screeches have two variations each, played at random, and every repeated sound gets a small random pitch shift (about ±8%).
- **3D sound.** Dino voices, stomps, horns, splashes and the engine play from the dino or rover in the world, so they're louder close up and fade with distance.
- **Music ducks.** The music dips under big stingers (reveals, FIGHT!, hatches).
- **Even levels.** Each slot gets its own volume. The quiet ambience files are turned up and the loud stingers are kept from clipping.

---

## Tier 1: the big moments (upload first, 24 sounds)

| Slot | Download | Vibe | When it plays |
| --- | --- | --- | --- |
| RoarBig | [Dinosaur monster roar #1976](https://assets.mixkit.co/active_storage/sfx/1976/1976.wav) | deep, rumbling T. rex roar | big carnivores: reveals, signatures, attacks (randomly alternates with RoarBig2) |
| RoarBig2 | [Giant monster roar #1972](https://assets.mixkit.co/active_storage/sfx/1972/1972.wav) | hits instantly, dense and loud | the second big-carnivore roar, so roars don't repeat |
| RoarBoss | [Big wild beast roar #1726](https://assets.mixkit.co/active_storage/sfx/1726/1726.wav) | huge roar with a long echo tail | boss intros, phase changes, enrage |
| Screech | [Creature long screech #307](https://assets.mixkit.co/active_storage/sfx/307/307.wav) | shrill raptor shriek | raptors and small hunters spotting you or pouncing |
| Screech2 | [Bird screeching in the jungle #2436](https://assets.mixkit.co/active_storage/sfx/2436/2436.wav) | bird-based screech (how the movie raptors were made) | alternates with Screech; pack calls |
| Bellow | [Fantasy monster grunt #1977](https://assets.mixkit.co/active_storage/sfx/1977/1977.wav) | big, low, not-evil honk | herbivores spooked or charging |
| SeaRoar | [Aquatic Creature Scream #2203](https://assets.mixkit.co/active_storage/sfx/2203/2203.wav) | wet, gurgling sea scream | Tidebreaker surfacing, dock slams |
| Reveal | [Blast hit with echo #2186](https://assets.mixkit.co/active_storage/sfx/2186/2186.wav) | instant BOOM with a long trailer echo | the sun-ray title slam on a dino reveal |
| Fight | [Drums of war #2784](https://assets.mixkit.co/active_storage/sfx/2784/2784.wav) | tribal war drums | the FIGHT! card |
| Spotted | [Cinematic glass hit suspense #677](https://assets.mixkit.co/active_storage/sfx/677/677.wav) | sharp "uh-oh" hit | a dino spots you while sneaking |
| Escape | [Movie whoosh impact presentation #2903](https://assets.mixkit.co/active_storage/sfx/2903/2903.wav) | whoosh plus a punch, "GO!" | DRIVE OFF: the chase begins |
| Escaped | [Game level completed #2059](https://assets.mixkit.co/active_storage/sfx/2059/2059.wav) | bright victory jingle | you reach the time portal |
| Defeated | [Grand brass fanfare #631](https://assets.mixkit.co/active_storage/sfx/631/631.wav) | big triumphant brass | a boss knocked out (DEFEATED!) |
| KnockedOut | [Cartoon dazzle hit and birds #746](https://assets.mixkit.co/active_storage/sfx/746/746.wav) | bonk plus dizzy tweeting birds | a site dino is knocked out (sleepy tranq KO, kid-friendly) |
| EggCrack | [Gen egg hatch #1740](https://assets.mixkit.co/active_storage/sfx/1740/1740.wav) | shell crack | each tap on the egg in the hatch cutscene |
| Hatch | [Magic sparkle poof hit #3082](https://assets.mixkit.co/active_storage/sfx/3082/3082.wav) | cute poof and sparkle | common / uncommon hatch |
| HatchRare | [Choir magic shine #658](https://assets.mixkit.co/active_storage/sfx/658/658.wav) | shimmering choir | rare / epic hatch |
| HatchLegendary | [Orchestra triumphant trumpets #2285](https://assets.mixkit.co/active_storage/sfx/2285/2285.wav) | heroic trumpets | legendary / secret hatch |
| Warp | [Sci fi warp slide #3113](https://assets.mixkit.co/active_storage/sfx/3113/3113.wav) | time-warp zip | going through the Time Gate |
| DartFire | [Arrow shot through air #2771](https://assets.mixkit.co/active_storage/sfx/2771/2771.wav) | quick "fwip" | every dart you fire |
| DartHit | [Small hit in a game #2072](https://assets.mixkit.co/active_storage/sfx/2072/2072.wav) | punchy thwack | a dart hits a dino |
| PlayerHurt | [Hard and quick punch #2143](https://assets.mixkit.co/active_storage/sfx/2143/2143.wav) | meaty instant thud | a dino bites or hits you |
| Click | [Plastic bubble click #1124](https://assets.mixkit.co/active_storage/sfx/1124/1124.wav) | bubbly toy-plastic click (matches the brick UI) | every button press |
| Coins | [Game coin touch #3217](https://assets.mixkit.co/active_storage/sfx/3217/3217.wav) | game-y coin pickup | cash pad collect, selling |

## Tier 2: makes it feel alive (30 sounds)

| Slot | Download | Vibe | When it plays |
| --- | --- | --- | --- |
| Growl | [Monster growl #1966](https://assets.mixkit.co/active_storage/sfx/1966/1966.wav) | close, loud warning growl | a dino getting suspicious (Stir), bosses idling |
| Snap | [Hellhound monster attack #3015](https://assets.mixkit.co/active_storage/sfx/3015/3015.wav) | snarl-and-snap | a dino lunging or biting |
| DinoHurt | [Creature cry of hurt #2208](https://assets.mixkit.co/active_storage/sfx/2208/2208.wav) | yelp | a dino takes a big or perfect hit |
| BabyChirp | [Cartoon creature calling #9](https://assets.mixkit.co/active_storage/sfx/9/9.wav) | tiny squeaky chirp | hatchlings popping out, petted babies |
| StompBig | [Quest game heavy stomp v #3049](https://assets.mixkit.co/active_storage/sfx/3049/3049.wav) | short, heavy thud (fits per-step) | big dinos and bosses walking near the camera |
| Stomp | [Game hatchling stomp #3059](https://assets.mixkit.co/active_storage/sfx/3059/3059.wav) | light thump | small dinos hopping and landing |
| Perfect | [Winning a coin, video game #2069](https://assets.mixkit.co/active_storage/sfx/2069/2069.wav) | crisp ding | a perfect dart or perfect dodge |
| Dodge | [Quick air woosh #2605](https://assets.mixkit.co/active_storage/sfx/2605/2605.wav) | fast woosh | your dodge roll |
| Reload | [Gear metallic lock sound #2858](https://assets.mixkit.co/active_storage/sfx/2858/2858.wav) | click-clack | launcher reload |
| ChargeReady | [Sci fi plasma gun power up #1679](https://assets.mixkit.co/active_storage/sfx/1679/1679.wav) | power-up whine | a charged shot is ready |
| Calmed | [Ethereal fairy win sound #2019](https://assets.mixkit.co/active_storage/sfx/2019/2019.wav) | soft sparkle | a dino is calmed / the rodeo succeeds |
| EngineLoop | [Truck driving steady #1621](https://assets.mixkit.co/active_storage/sfx/1621/1621.wav) | steady motor (loops cleanly) | your rover's engine, pitched up with speed |
| Boost | [Speeding swoosh #1484](https://assets.mixkit.co/active_storage/sfx/1484/1484.wav) | rocket whoosh | rover boost |
| RoverHit | [Falling on metal roof #752](https://assets.mixkit.co/active_storage/sfx/752/752.wav) | metal crunch | a dino slams your rover |
| CarDoor | [Car door slam #1564](https://assets.mixkit.co/active_storage/sfx/1564/1564.wav) | door slam | getting in or out of the rover |
| Splash | [Jumping into water #1304](https://assets.mixkit.co/active_storage/sfx/1304/1304.wav) | instant splash | you or a rover hitting deep water |
| ItemDrop | [Unlock new item game notification #254](https://assets.mixkit.co/active_storage/sfx/254/254.wav) | "something dropped!" chime | a boss key pops out of a knocked-out dino |
| ItemGet | [Video game treasure #2066](https://assets.mixkit.co/active_storage/sfx/2066/2066.wav) | treasure jingle | picking it up and holding it high |
| LevelUp | [Game experience level increased #2062](https://assets.mixkit.co/active_storage/sfx/2062/2062.wav) | level-up sweep | upgrades and level ups |
| Discover | [Magic sweep game trophy #257](https://assets.mixkit.co/active_storage/sfx/257/257.wav) | discovery sparkle | a new site is discovered |
| QuestDone | [Fantasy game success notification #270](https://assets.mixkit.co/active_storage/sfx/270/270.wav) | magical success | a quest is completed |
| BossRising | [Warfare horn #2289](https://assets.mixkit.co/active_storage/sfx/2289/2289.wav) | distant war horn | the server-wide warning 15 s before a boss event |
| Open | [Opening software interface #2578](https://assets.mixkit.co/active_storage/sfx/2578/2578.wav) | quick open blip | a window opens (Bag, Index, Shop...) |
| Close | [Software interface back #2575](https://assets.mixkit.co/active_storage/sfx/2575/2575.wav) | quick close blip | a window closes |
| Error | [Negative tone interface tap #2569](https://assets.mixkit.co/active_storage/sfx/2569/2569.wav) | soft "nope" | can't afford / can't do that |
| Toast | [Bubble pop up alert notification #2357](https://assets.mixkit.co/active_storage/sfx/2357/2357.wav) | little bubble pop | pop-up messages |
| Payout | [Payout award #1934](https://assets.mixkit.co/active_storage/sfx/1934/1934.wav) | big coin shower | daily chest, boss rewards, big sales |
| EggPickup | [Long pop #2358](https://assets.mixkit.co/active_storage/sfx/2358/2358.wav) | satisfying pop | picking up an egg |
| EggPlace | [Light impact on the ground #2070](https://assets.mixkit.co/active_storage/sfx/2070/2070.wav) | soft set-down | putting an egg in a nest or on the rover |
| Pet | [Fairy arcade sparkle #866](https://assets.mixkit.co/active_storage/sfx/866/866.wav) | gentle sparkle | petting a dino (hearts) |

## Replacing the stock Roblox clicks and dings (4 sounds)

The game no longer uses any built-in Roblox sounds; these four cover the last moments that did.

| Slot | Download | Vibe | When it plays |
| --- | --- | --- | --- |
| Talk | [Dry pop up notification alert #2356](https://assets.mixkit.co/active_storage/sfx/2356/2356.wav) | tiny pop, pitched up and down into a "voice" | the typewriter blips when NPCs and the radio talk |
| DryFire | [Gear fast lock tap #2857](https://assets.mixkit.co/active_storage/sfx/2857/2857.wav) | crisp empty trigger tick | firing with no target in reach |
| Glance | [Glass hitting a metal #2183](https://assets.mixkit.co/active_storage/sfx/2183/2183.wav) | a "tink" off armour | a weak dart that glances off |
| Confirm | [Interface option select #2573](https://assets.mixkit.co/active_storage/sfx/2573/2573.wav) | crisp positive select | main-menu checks passing, confirmations |

## Boss reveals (3 sounds)

| Slot | Download | Vibe | When it plays |
| --- | --- | --- | --- |
| TreeCrack | [Breaking apart #3208](https://assets.mixkit.co/active_storage/sfx/3208/3208.wav) | wood cracking and splitting | the Scythe King's trees coming down |
| Slash | [Samurai Sword Impact #2789](https://assets.mixkit.co/active_storage/sfx/2789/2789.wav) | a sharp blade "shing" | the Scythe King's slash across the screen |
| IceCrack | [Glass break with hammer thud #759](https://assets.mixkit.co/active_storage/sfx/759/759.wav) | ice snapping | Frostfang's roar and stomp cracking the lake |

## Tier 3: atmosphere and specials (14 sounds)

| Slot | Download | Vibe | When it plays |
| --- | --- | --- | --- |
| AmbCamp | [Birds in forest loop #1239](https://assets.mixkit.co/active_storage/sfx/1239/1239.wav) | calm forest birds | Base Camp |
| AmbFernValley | [Birds in the jungle #2434](https://assets.mixkit.co/active_storage/sfx/2434/2434.wav) | jungle bird calls | Fern Valley |
| AmbGiantPlains | [Breeze through the trees #2427](https://assets.mixkit.co/active_storage/sfx/2427/2427.wav) | open wind and leaves | Giant Plains |
| AmbSpineRiver | [River surroundings in the jungle #2451](https://assets.mixkit.co/active_storage/sfx/2451/2451.wav) | steady river bed (loops cleanly) | Spine River |
| AmbRedCliffs | [Wind in the top of the mountain #1267](https://assets.mixkit.co/active_storage/sfx/1267/1267.wav) | steady canyon wind | Red Cliffs |
| AmbFrostForest | [Arctic winds #1154](https://assets.mixkit.co/active_storage/sfx/1154/1154.wav) | cold howling wind | Frost Forest |
| AmbDawnDesert | [Wind in a desolate world #2490](https://assets.mixkit.co/active_storage/sfx/2490/2490.wav) | eerie empty wind | Dawn Desert |
| SwimLoop | [Sea swimming loop #1181](https://assets.mixkit.co/active_storage/sfx/1181/1181.wav) | swim strokes | while you swim |
| Underwater | [Underwater white noise #1209](https://assets.mixkit.co/active_storage/sfx/1209/1209.wav) | steady muffled hush | head under water |
| Whirlpool | [Strong flowing waters noise #2461](https://assets.mixkit.co/active_storage/sfx/2461/2461.wav) | roaring rushing water (very steady) | the Tidebreaker's whirlpool |
| Breach | [Bomb drop cold water explosion #2806](https://assets.mixkit.co/active_storage/sfx/2806/2806.wav) | huge water blast | the Mosasaurus erupting out of the water |
| Flare | [Short fire whoosh #1345](https://assets.mixkit.co/active_storage/sfx/1345/1345.wav) | fizzing flare | FLASH FLARE gadget |
| Earthshaker | [Apocalyptic stomp impact #3057](https://assets.mixkit.co/active_storage/sfx/3057/3057.wav) | ground slam | EARTHSHAKER gadget |
| Bait | [Human bites a juicy sausage #117](https://assets.mixkit.co/active_storage/sfx/117/117.wav) | juicy chomp | a dino eating MEAT BAIT |

## Rover horns (6 uploads; heard by everyone near the rover)

| Slot | Download | Vibe |
| --- | --- | --- |
| HornBeep | [Car double horn #719](https://assets.mixkit.co/active_storage/sfx/719/719.wav) | beep beep |
| HornTruck | [Truck horn #720](https://assets.mixkit.co/active_storage/sfx/720/720.wav) | big rig |
| HornDuck | [Rubber duck squeak #1014](https://assets.mixkit.co/active_storage/sfx/1014/1014.wav) | squeak |
| HornClown | [Funny clown horn sounds #2886](https://assets.mixkit.co/active_storage/sfx/2886/2886.wav) | honk honk |
| HornTrain | [Toy train whistle #1631](https://assets.mixkit.co/active_storage/sfx/1631/1631.wav) | choo choo |
| HornFanfare | [Successful horns fanfare #722](https://assets.mixkit.co/active_storage/sfx/722/722.wav) | ta-da |
| HornRaptor | reuses **Screech** (same id) | raptor shriek |
| HornRex | reuses **RoarBig** (same id) | rex roar |

## Garage studio (3 sounds)

| Slot | Download | When it plays |
| --- | --- | --- |
| Spray | [Air freshener spray #1890](https://assets.mixkit.co/active_storage/sfx/1890/1890.wav) | trying a new paint colour |
| Clunk | [Factory metal hard hit #2980](https://assets.mixkit.co/active_storage/sfx/2980/2980.wav) | fitting a part |
| Purchase | [Gold coin prize #1999](https://assets.mixkit.co/active_storage/sfx/1999/1999.wav) | buying a part |

---

## Music (Roblox Creator Store, not Mixkit)

These are APM tracks from the Creator Store: licensed for Roblox games and already uploaded, so they need no upload. The first pick is wired in; click a title to preview it, and tell me to swap any slot to its alternative (or to any other track).

| Slot | When it plays | In the game now | Vibe | Alternative |
| --- | --- | --- | --- | --- |
| Camp | Base Camp | [Dreams Of Adventure (Light Vs)](https://create.roblox.com/store/asset/1838609493) | warm, light film-score adventure | [Eco Adventure Camp](https://create.roblox.com/store/asset/1843603167) |
| FernValley | Fern Valley | [Jurassic Island (extended)](https://create.roblox.com/store/asset/1837299746) | sweeping "lost island" adventure | [The Lost World](https://create.roblox.com/store/asset/1843309804) |
| GiantPlains | Giant Plains | [Life on the Savannah a](https://create.roblox.com/store/asset/1839924446) | big wildlife-documentary orchestra | [Jurassic Lands](https://create.roblox.com/store/asset/1845358604) |
| SpineRiver | Spine River | [High Sea Adventure (B)](https://create.roblox.com/store/asset/1846751102) | playful orchestral sea adventure | [Open Seas](https://create.roblox.com/store/asset/1845459243) |
| RedCliffs | Red Cliffs | [Hideout Canyon](https://create.roblox.com/store/asset/9042768313) | spaghetti-western canyon | [Last Prairie: Main Theme](https://create.roblox.com/store/asset/1843044145) |
| FrostForest | Frost Forest | [Celestial Aurora](https://create.roblox.com/store/asset/1841460294) | icy, glittering wonder | [Arctic Journey](https://create.roblox.com/store/asset/1838120529) |
| DawnDesert | Dawn Desert | [Desert Mysteries A](https://create.roblox.com/store/asset/1847792600) | ancient, mysterious documentary | [Ancient Myths](https://create.roblox.com/store/asset/1837779548) |
| Map | the era map | [Curious Mind (a)](https://create.roblox.com/store/asset/1841928563) | curious, light exploration | [Explorer](https://create.roblox.com/store/asset/1835893953) |
| Chase | every escape chase | [Jurassic Run](https://create.roblox.com/store/asset/1837322700) | tense orchestral running | [Running Faster A](https://create.roblox.com/store/asset/1847683499) |
| Boss | boss fights | [Last Man Standing (No Choir Version)](https://create.roblox.com/store/asset/9045953477) | huge apocalyptic battle | [Attack The Monsters A](https://create.roblox.com/store/asset/9040414188) |
