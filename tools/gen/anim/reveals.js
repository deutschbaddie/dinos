// BOSS REVEALS — each boss's intro, authored as TikTok shots so the same baked footage plays as the in-game
// reveal (TikTok.PlayCutscene from EraView) and cuts straight into TikToks. Baked by tools/gen/tiktok.js.
//
// 2026-10-14 remake (user: "boss reveals on tiktok show the CRAZIEST boss reveals... this needs to be a highlight of
// this game too. genuinely strike fear, or show off a cool dino with personality and cinematography - the main
// audience is kids so coolness factor is best"). Every reveal is now a 15-25 s short film:
//   - BUILD-UP first: sound before picture (thuds, breath, a creak), the world reacting (a puddle shivers, pebbles
//     hop, birds burst out, the herd bolts, the bay goes still). The boss is NEVER seen before its moment - at most a
//     black shape with burning eyes (Silhouette / EyesOnly), or nothing at all (Hidden)
//   - ONE signature moment per boss, and no two share it: the Tyrant King is behind you in the dark; the Titan's
//     footsteps make the ground jump and the lens cranes up a body that won't end; the Tidebreaker passes over the
//     lens underwater, then explodes out of the bay; the Scythe King cuts the grove down and shows its blades; Frostfang
//     walks out of a blizzard and roars it away; the Dawn King's eyes rise out of the mud before it does
//   - one climax: the light, the roar, the shake and the name card (the only text) land on the same frame
//   - strong angles: low hero shots, over-the-shoulder with YOU in frame (Crew 1 is the player's own avatar), push-ins
//     on the roar, whip pans, a crane up the body; a closing beat after the name (a step, a snap, a pose)
//   - ends near the den centre (the real boss takes over there; EraView's FIGHT! face-off follows)
//   - every reveal shot is Strict: tools/gen/tiktok.js QCs every 3rd frame (lens inside a rock or a body, subject
//     off frame or blocked, a dino through a wall), not just three frames per shot
//
// Cue kinds the reveals add (played by Game/TikTok/Fx.luau + init.luau):
//   Sfx slot vol pitch | Sting slot vol | Fx actorId event arg | Ripple pt scale | Leaves pt radius count
//   RoarWave actorId scale | Splash pt scale | LensDrops a color | Snow density | White a dur color | Grade preset dur
//   TreeFall basePt towardPt dur | Title text sub color | Slash color | Splinter pt scale | Bubbles pt scale
//   Birds pt count towardPt | DustWave pt towardPt scale | Cracks pt scale | Glint pt scale | Black | Unblack
// Points: [x, y, z] in the anchor frame, of(actor, at), part(actor, 'Head' | any VFX_ name), gnd(x, h, z) (h above
// the ground there). Actor extras: Silhouette [b0, b1, ...] (black + glowing eyes), EyesOnly, Rim (a Fx.Colors name),
// Hidden [b] (appears at beat b), ClipOK (allowed inside the ground: rising out of the mud), Prop { Shape, Size, ... }.

const dino = (id, sp, Move, extra = {}) => Object.assign({ Id: id, Dino: sp, Move }, extra);
const crew = (id, n, extra = {}) => Object.assign({ Id: id, Crew: n }, extra);
const prop = (id, Prop, Move) => ({ Id: id, Prop, Move });
const of = (Of, At) => ({ Of, At });
const part = (Of, Part, Off) => ({ Of, Part, Off });
const gnd = (x, h, z) => ({ Gnd: [x, h, z] });
const score = (Stop, Wow, Motion, Read, Novel, Phone) => ({ Stop, Wow, Motion, Read, Novel, Phone });
const DEN = () => ({ Marker: 'DenCenter', Away: 'Throne' });
// the Sea Mouth: centred on the bay, forward = toward the east dock (DenCenter), where you stand. (The Throne slab sits
// under BayCenter, so "Away: Throne" there had no direction at all: every Tidebreaker camera collapsed onto one point.)
const BAY = { Marker: 'BayCenter', Toward: 'DenCenter', Air: true };
// an invisible marker for the QC to frame (an empty throne, a stretch of water)
const mark = (id, at, lift = 0) => prop(id, { Shape: 'Block', Size: [1, 1, 1], Transparency: 1, Lift: lift }, { Spot: at });

// ==================================================================================== TYRANT KING: BEHIND YOU
// Fern Valley, the King's lair at dusk. (User: "you shouldn't be able to see the bosses before they show up... make it
// all dark and then he shows up".) The hunter: you walk in; a puddle shivers on each thud; birds burst off the walls
// and the light dies. In the black, two eyes open BEHIND you and come closer; its head lowers over your shoulder,
// sniffing. You turn round. It roars down at you and the light floods back on the roar: TYRANT KING.
const TK_PUD = [4.5, -4.4]; // one of the lair's own mud puddles (fernValley.js), between its giant footprints
const TK_ME = [1, -10]; // where you stop
const TK_REX = [-7, -25]; // where it stops, right behind you (off your left shoulder, so its head clears yours)
const TK_FACE = [-7, 0];
const puddle = () => mark('pud', TK_PUD, 0.1);
const rexAt = (extra) => dino('rex', 'TyrannosaurusRex', { Spot: TK_REX, Face: TK_FACE }, Object.assign({ Scale: 1.15 }, extra));

// ==================================================================================== PLAINS TITAN: EARTHQUAKE
// Giant Plains, golden hour, on the approach to its bowl. Pebbles hop on a rock with each far-off thud and the herd
// looks up; then they bolt past the lens. Whip round to where they ran from: a golden wall of dust, and in it a black
// shape too big to be real. It walks right over the lens - a crane from its foot up, and up, to the head - and the sun
// catches it. It roars; a dust wave rolls at the camera: PLAINS TITAN. Then it snaps at you.
const GT_SPOT = [18, -50]; // where it stands (on the approach, outside the bowl)
const PEB = [8, -50];
const pebble = (k, dx, dz, size, col, delay) => prop('peb' + k, { Shape: 'Block', Size: [size, size * 0.8, size * 1.1], Color: col, Material: 'Slate' },
  { Spot: [PEB[0] + dx, PEB[1] + dz], Lift: [[0, 0], [1.2 + delay, 0], [1.32 + delay, 0.3 + size * 0.3, 'out'], [1.55 + delay, 0, 'in'], [3.0 + delay, 0], [3.16 + delay, 0.7 + size * 0.5, 'out'], [3.52 + delay, 0, 'in']] });
const PEBBLES = [
  pebble(1, 0, 0, 0.6, '#8a7a64', 0), pebble(2, 0.8, 0.7, 0.42, '#a39377', 0.02), pebble(3, -0.7, 0.5, 0.5, '#6e6252', 0.04),
  pebble(4, 1.1, -0.6, 0.35, '#b3a282', 0.01), pebble(5, -0.3, -0.9, 0.45, '#7d6e58', 0.03), pebble(6, -1.2, -0.3, 0.3, '#9a8a6c', 0.05),
];
const giga = (Move, extra) => dino('giga', 'Giganotosaurus', Move, Object.assign({ Scale: 1.05 }, extra));

// ==================================================================================== TIDEBREAKER: DEAD CALM
// Spine River, the Sea Mouth at dusk. (User: "the mosasaurus needs a lot of work".) You on the east dock; gulls lift
// off, the bay goes glass-flat and a line of bubbles comes in at the dock. Under the water, looking up at you: a shape
// the size of a whale glides over the lens. From high above, it circles under the ring of docks, eyes burning. Its
// back cuts a wake straight at you - it dives - silence. Then it EXPLODES out of the water beside the dock, hangs in
// slow motion with its name, and crashes down; it surfaces and roars at you.
const TB_ME = [0, -31.5]; // on the east dock, looking west across the bay
const SEA = (extra) => Object.assign({ Scale: 0.9 }, extra);

// ==================================================================================== SCYTHE KING: THE HARVEST
// Red Cliffs, the Scythe Grove at dusk. Leaves drift round an empty mossy throne; far off, a blade sings. The trees
// start coming down, cut clean through. Out of the dust: a black shape, and three claws as long as you are, catching
// the light; they tap together. It steps into the light; it slashes at the lens and the frame splits along the cut:
// SCYTHE KING. It roars, then crosses its claws in an X.
const SK_SPOT = [0.5, 10];

// ==================================================================================== FROSTFANG: WHITEOUT
// Frost Forest, the White Lake. Snow, quiet; the ice groans under you. A storm rolls over the lake until there is
// nothing but white - and in it, two eyes, walking closer. It stops and tilts its head, listening for you; its snout
// pushes out of the white an arm's length from the lens, breath steaming. Then the frost roar blasts the whole
// blizzard away in a ring: FROSTFANG. It stomps and the ice cracks out to the camera.
const FF_SPOT = [0, 15];

// ==================================================================================== DAWN KING: BEFORE THE DINOSAURS
// Dawn Desert, the Bone Wash at sunrise. A little Coelophysis drinks at a mud wallow. Behind it, two burning eyes rise
// out of the mud, like a crocodile's. The mud explodes; the little one gets away (nothing gets eaten). The Dawn King
// rears up on its hind legs against the rising sun and roars: DAWN KING. It shakes the mud off - onto the lens.
const DK_SPOT = [17, 21]; // in the wallow
const DK_CO = [12.5, 16.5];

const Shots = {
  // ------------------------------------------------------------------ TYRANT KING
  TK_Creep: {
    Zone: 'FernValley', At: DEN(), Beats: 6, Subject: ['me'], Grade: 'Dark',
    Note: 'Low behind you as you creep into the lair at dusk; a breath somewhere, two far thuds; you stop.',
    Actors: [crew('me', 1, { Move: { Path: [[-1.2, -28], TK_ME], Start: 0.3, Beats: 5, Ease: 'out' } })],
    Cam: { Keys: [
      { B: 0, P: of('me', [-3.4, 4.2, 10]), L: of('me', [1.2, 3.2, -18]), F: 48 },
      { B: 6, P: of('me', [-2.8, 3.6, 8]), L: of('me', [1, 3.4, -18]), F: 42, E: 'inout' },
    ], Hand: 0.35, Smooth: 0.5 },
    Cues: [
      [0, 'Grade', 'Dark', 0], [0.8, 'Sfx', 'Growl', 0.3, 0.36],
      [3.0, 'Sfx', 'StompBig', 0.45, 0.52], [3.0, 'Shake', 0.25], [3.02, 'Ripple', [TK_PUD[0], 0.25, TK_PUD[1]], 0.5],
      [4.9, 'Sfx', 'StompBig', 0.7, 0.5], [4.9, 'Shake', 0.4], [4.95, 'Leaves', [0, 30, -4], 22, 14],
    ],
    Score: score(8, 6, 6, 9, 8, 8),
  },
  TK_Puddle: {
    Zone: 'FernValley', At: DEN(), Beats: 4, Subject: ['pud'], Grade: 'Dark',
    Note: 'At puddle level, your feet beyond it: three thuds, each bigger, the water rings; you flinch.',
    Actors: [puddle(), crew('me', 1, { Move: { Spot: TK_ME, Face: [1, 20] }, Acts: [[2.8, 'Startle']] })],
    Cam: { From: [6.6, 1.6, -0.4], To: [6.4, 1.5, -0.9], Look: [1.8, 0.4, -10], LookTo: [1.6, 0.7, -10], Fov: [40, 35], Ease: 'linear', Hand: 0.2 },
    Cues: [
      [0.3, 'Ripple', [TK_PUD[0], 0.25, TK_PUD[1]], 0.55], [0.3, 'Sfx', 'StompBig', 0.55, 0.52], [0.3, 'Shake', 0.25],
      [1.5, 'Ripple', [TK_PUD[0], 0.25, TK_PUD[1]], 0.8], [1.5, 'Sfx', 'StompBig', 0.8, 0.5], [1.5, 'Shake', 0.4],
      [2.7, 'Ripple', [TK_PUD[0], 0.25, TK_PUD[1]], 1.1], [2.7, 'Sfx', 'StompBig', 1.05, 0.48], [2.7, 'Shake', 0.65], [2.75, 'Leaves', [2, 22, -4], 14, 18],
    ],
    Score: score(9, 7, 5, 9, 9, 9),
  },
  TK_LightsOut: {
    Zone: 'FernValley', At: DEN(), Beats: 5, Subject: ['me'], Grade: 'Dark',
    Note: 'High from the throne: you small in the lair. A thud - birds burst off both walls; another - the light dies.',
    Actors: [puddle(), crew('me', 1, { Move: { Spot: TK_ME, Face: [1, 20] }, Acts: [[0.8, 'Startle']] })],
    Cam: { From: [12, 15, 24], To: [10.5, 13, 20.5], Look: [0, 2, -18], LookTo: [0.5, 2.6, -15], Fov: [50, 44], Ease: 'inout', Hand: 0.3 },
    Cues: [
      [0.6, 'Sfx', 'StompBig', 1.0, 0.46], [0.6, 'Shake', 0.6], [0.62, 'Ripple', [TK_PUD[0], 0.25, TK_PUD[1]], 1.0],
      [0.7, 'Birds', [-32, 36, -20], 16, [-70, 70, -70]], [0.78, 'Birds', [30, 36, -28], 12, [70, 66, -80]], [0.75, 'Sfx', 'Screech2', 0.6, 1.2],
      [0.7, 'Leaves', [0, 32, -12], 30, 30],
      [2.6, 'Sfx', 'StompBig', 1.2, 0.43], [2.6, 'Shake', 0.9], [2.6, 'Sfx', 'Earthshaker', 0.35, 0.6], [2.6, 'Grade', 'Night', 1.0],
    ],
    Score: score(9, 8, 6, 9, 9, 9),
  },
  TK_Behind: {
    Zone: 'FernValley', At: DEN(), Beats: 8, Subject: ['me', 'rex'], Focus: 'Head', Grade: 'Night',
    Note: 'In the dark, facing you: high up behind you two eyes open. They come closer; its head lowers over your shoulder, sniffing. You flinch.',
    Actors: [
      puddle(),
      crew('me', 1, { Move: { Spot: TK_ME, Face: [1, 20] }, Acts: [[6.4, 'Startle']] }),
      dino('rex', 'TyrannosaurusRex', { Path: [[-7, -38], TK_REX], Start: 1.4, Beats: 3.6, Ease: 'out', Face: TK_FACE },
        { Scale: 1.15, Loco: 'Walk', LocoKeys: [[5.0, 'Idle']], Acts: [[5.4, 'Sniff', 0.8]], Hidden: [1.2], Silhouette: [1.2, 8], EyesOnly: true }),
    ],
    Cam: { Keys: [
      { B: 0, P: [5, 2.3, 3.5], L: [-2.5, 6.2, -14], F: 46 },
      { B: 8, P: [4.6, 2.3, 2.2], L: [-2.8, 6.6, -14], F: 42, E: 'inout' },
    ], Hand: 0.3, Smooth: 0.5 },
    Cues: [
      [1.2, 'Sfx', 'Growl', 0.7, 0.4],
      [2.2, 'Sfx', 'StompBig', 0.4, 0.5], [2.2, 'Shake', 0.2], [2.22, 'Ripple', [TK_PUD[0], 0.25, TK_PUD[1]], 0.45],
      [3.4, 'Sfx', 'StompBig', 0.5, 0.5], [3.4, 'Shake', 0.25], [3.42, 'Ripple', [TK_PUD[0], 0.25, TK_PUD[1]], 0.55],
      [4.6, 'Sfx', 'StompBig', 0.6, 0.49], [4.6, 'Shake', 0.3], [4.62, 'Ripple', [TK_PUD[0], 0.25, TK_PUD[1]], 0.65],
      [5.6, 'Sfx', 'Growl', 1.0, 0.48],
    ],
    Score: score(10, 9, 5, 9, 10, 10),
  },
  TK_Eye: {
    Zone: 'FernValley', At: DEN(), Beats: 3, Subject: ['rex'], Focus: 'Head', Grade: 'Night',
    Note: 'Over your shoulder as you turn round: the black head an arm\'s length away, two burning eyes. A long growl.',
    Actors: [
      crew('me', 1, { Move: { Spot: TK_ME, Face: [-7, -16] } }),
      rexAt({ Acts: [[-2.6, 'Sniff', 0.8]], Silhouette: [0, 3.2], EyesOnly: true }),
    ],
    Cam: { From: [4.2, 5.6, -6.6], To: [3.4, 5.5, -7.8], Look: part('rex', 'Head', [0, -0.5, 0]), Fov: [38, 32], Ease: 'linear', Hand: 0.25, Smooth: 0.5 },
    Cues: [[0.2, 'Sfx', 'Growl', 1.2, 0.38], [0.2, 'Shake', 0.35]],
    Score: score(10, 9, 4, 8, 10, 9),
  },
  TK_Roar: {
    Zone: 'FernValley', At: DEN(), Beats: 9, Subject: ['rex'], Focus: 'Head', Grade: 'Night',
    Note: 'CLIMAX. Low behind you: the black king rears back - and roars down at you as the light floods back on; TYRANT KING.',
    Actors: [
      crew('me', 1, { Move: { Spot: TK_ME, Face: [-7, -16] }, Acts: [[2.6, 'Startle']] }),
      rexAt({ Acts: [[0, 'Roar', 0.8]], Silhouette: [0, 2.45], EyesOnly: true }),
    ],
    Cam: { Keys: [
      { B: 0, P: [6.2, 1.8, 1.5], L: part('rex', 'Head', [0, -3, 0]), F: 48 },
      { B: 2.4, P: [6.0, 1.8, 0.8], L: part('rex', 'Head', [0, -3, 0]), F: 46, E: 'inout' },
      { B: 9, P: [5.2, 1.7, -1.6], L: part('rex', 'Head', [0, -3, 0]), F: 38, E: 'out' },
    ], Hand: 0.4, Smooth: 0.3 },
    Cues: [
      [0.3, 'Sfx', 'Growl', 0.9, 0.55],
      [2.45, 'Grade', 'Hero', 0.2], [2.45, 'Flash', 0.7], [2.45, 'Sting', 'Reveal', 1.0], [2.45, 'Sfx', 'RoarBoss', 1.0, 0.9],
      [2.45, 'Shake', 1.8], [2.45, 'Punch', 8], [2.5, 'RoarWave', 'rex', 2.0], [2.5, 'Leaves', [0, 24, -18], 26, 60],
      [2.6, 'Title', 'TYRANT KING', 'BOSS OF FERN VALLEY', 'Orange'], [2.6, 'SunBurst', 0.7], [5.0, 'Leaves', [0, 26, -10], 30, 40],
    ],
    Score: score(10, 10, 8, 9, 10, 10),
  },
  TK_Hero: {
    Zone: 'FernValley', At: DEN(), Beats: 5, Subject: ['rex'], Focus: 'Head',
    Note: 'Low and wide from the side: under a rain of leaves the king takes one heavy step at you and lowers its head, growling. You raise your launcher.',
    Actors: [
      crew('me', 1, { Move: { Spot: TK_ME, Face: [-7, -16] }, Combat: true }),
      dino('rex', 'TyrannosaurusRex', { Path: [TK_REX, [-6.5, -21.5]], Start: 0.8, Beats: 1.4, Ease: 'out', Face: TK_FACE }, { Scale: 1.15, Loco: 'Walk', LocoKeys: [[2.2, 'Idle']], Acts: [[2.4, 'Sniff', 0.9]] }),
    ],
    Cam: { From: [-21, 2.0, -2], To: [-19.5, 2.1, -4], Look: [-4, 7.5, -15], LookTo: [-4, 7, -14], Fov: [48, 44], Ease: 'out', Hand: 0.45 },
    Cues: [
      [0.1, 'Leaves', [0, 24, -16], 30, 50], [2.0, 'Sfx', 'StompBig', 1.1, 0.45], [2.0, 'Shake', 0.9], [2.02, 'Dust', part('rex', 'LeftFoot'), 2.2],
      [3.0, 'Sfx', 'Growl', 1.0, 0.5],
    ],
    Score: score(8, 9, 6, 9, 8, 9),
  },

  // ------------------------------------------------------------------ PLAINS TITAN
  GT_Pebbles: {
    Zone: 'GiantPlains', At: DEN(), Beats: 5, Subject: ['peb1'], Grade: 'Golden',
    Note: 'HOOK. Macro on a rock on the approach, the herd grazing beyond: a far-off thud and the pebbles hop; a bigger one - they jump; a Parasaurolophus throws its head up.',
    Actors: [
      ...PEBBLES,
      dino('p1', 'Parasaurolophus', { Spot: [34, -62], Face: [20, -72] }, { Acts: [[3.3, 'Roar', 1.1]] }),
      dino('t1', 'Triceratops', { Spot: [46, -58], Face: [60, -70] }, { Acts: [[0, 'Graze', 1]] }),
      dino('p2', 'Parasaurolophus', { Spot: [52, -68], Face: [40, -60] }, { Acts: [[0.6, 'LookAround', 1]] }),
    ],
    Cam: { From: gnd(2.5, 0.75, -45), To: gnd(2.9, 0.7, -45.5), Look: gnd(14, 1.0, -56), LookTo: gnd(14, 1.4, -56), Fov: [40, 36], Ease: 'linear', Hand: 0.2, Smooth: 0.4 },
    Cues: [
      [1.2, 'Sfx', 'StompBig', 0.5, 0.42], [1.2, 'Shake', 0.25], [1.2, 'Sfx', 'Earthshaker', 0.25, 0.55],
      [3.0, 'Sfx', 'StompBig', 0.85, 0.4], [3.0, 'Shake', 0.5], [3.0, 'Sfx', 'Earthshaker', 0.45, 0.5], [3.02, 'Dust', gnd(PEB[0], 0, PEB[1]), 0.6],
      [3.6, 'Sfx', 'Bellow', 0.6, 1.1],
    ],
    Score: score(9, 7, 5, 9, 9, 9),
  },
  GT_Stampede: {
    Zone: 'GiantPlains', At: DEN(), Beats: 5, Subject: ['t1'], Grade: 'Golden',
    Note: 'Low on the approach: the herd bolts right to left past the lens in a panic, dust everywhere.',
    Actors: [
      dino('p1', 'Parasaurolophus', { Path: [[34, -62], [-70, -50]], Speed: 30 }, { Loco: 'Run' }),
      dino('t1', 'Triceratops', { Path: [[46, -58], [-70, -56]], Speed: 24, Start: 0.3 }, { Loco: 'Run' }),
      dino('p2', 'Parasaurolophus', { Path: [[52, -68], [-70, -60]], Speed: 31, Start: 0.5 }, { Loco: 'Run' }),
      dino('t2', 'Triceratops', { Path: [[66, -52], [-70, -54]], Speed: 27, Start: 0.9 }, { Loco: 'Run' }),
      dino('p3', 'Parasaurolophus', { Path: [[74, -60], [-70, -48]], Speed: 33, Start: 1.3 }, { Loco: 'Run' }),
    ],
    // (lens kept 10+ studs in front of the nearest lane: it used to sit IN the herd and they ran through it)
    Cam: { From: gnd(-4, 1.8, -37), To: gnd(-5, 1.9, -37.5), Look: [36, 4, -56], LookTo: [-14, 4, -54], Fov: [54, 60], Ease: 'inout', Hand: 1.2 },
    Cues: [
      [0.1, 'Sfx', 'StompBig', 0.8, 0.9], [0.5, 'Sfx', 'Bellow', 0.8, 1.15], [0.6, 'Shake', 0.6], [1.1, 'Sfx', 'StompBig', 1.0, 0.85], [1.2, 'Shake', 0.9],
      [1.7, 'Sfx', 'StompBig', 1.0, 0.95], [2.0, 'Shake', 1.0], [2.3, 'Sfx', 'StompBig', 1.1, 0.8], [2.8, 'Sfx', 'Bellow', 0.6, 1.3],
      [0.4, 'Dust', gnd(20, 0, -56), 2.4], [1.2, 'Dust', gnd(4, 0, -54), 2.6], [2.0, 'Dust', gnd(-12, 0, -52), 2.6], [2.8, 'Dust', gnd(-24, 0, -54), 2.8], [3.6, 'Dust', gnd(-6, 0, -56), 2.6],
    ],
    Score: score(9, 8, 10, 8, 9, 8),
  },
  GT_Dust: {
    Zone: 'GiantPlains', At: DEN(), Beats: 5, Subject: ['giga'], Focus: 'Head', Grade: 'Golden',
    Note: 'Whip right to where they ran from: a golden wall of dust, and walking out of it a black shape too big to be real.',
    Actors: [
      giga({ Path: [[48, -56], [34, -54]], Beats: 5 }, { Loco: 'Walk', Hidden: [0.8], Silhouette: [0, 5], Rim: 'Gold' }),
    ],
    Cam: { Keys: [
      { B: 0, P: gnd(-6, 1.3, -40), L: [-40, 4, -52], F: 54 },
      { B: 0.9, P: gnd(-6, 1.3, -40.4), L: [42, 7, -55], F: 40, E: 'snap' },
      { B: 5, P: gnd(-5.4, 1.3, -40.8), L: [36, 8, -54], F: 34, E: 'linear' },
    ], Hand: 0.6, Smooth: 0.15 },
    Cues: [
      [0.5, 'Sfx', 'Dodge', 0.8, 0.8], [0.9, 'White', 0.32, 0.5, 'Dust'], [0.9, 'Dust', gnd(44, 0, -54), 3.4], [3.0, 'White', 0.2, 1.4, 'Dust'],
      [1.6, 'Sfx', 'StompBig', 1.1, 0.45], [1.6, 'Shake', 0.6], [1.6, 'Sfx', 'Earthshaker', 0.5, 0.5], [1.62, 'Dust', part('giga', 'LeftFoot'), 2.6],
      [3.3, 'Sfx', 'StompBig', 1.2, 0.43], [3.3, 'Shake', 0.75], [3.32, 'Dust', part('giga', 'RightFoot'), 2.8],
      [4.2, 'Sfx', 'Growl', 0.8, 0.45],
    ],
    Score: score(9, 10, 8, 8, 10, 9),
  },
  GT_Tilt: {
    Zone: 'GiantPlains', At: DEN(), Beats: 7, Subject: ['giga'], Focus: [[0, 'LeftFoot'], [1.6, 'Center'], [5.5, 'Head']], Grade: 'Golden',
    Note: 'It walks right over the lens: a crane from the foot that lands beside you, up the body, up, to the head against the sun - and the light catches it.',
    Actors: [
      giga({ Path: [[34, -54], GT_SPOT], Beats: 4.4, Ease: 'out' }, { Loco: 'Walk', LocoKeys: [[4.4, 'Idle']], Silhouette: [0, 4.6], Rim: 'Gold' }),
    ],
    Cam: { Keys: [
      { B: 0, P: gnd(12, 0.8, -42), L: part('giga', 'LeftFoot', [0, 1, 0]), F: 52 },
      { B: 4.4, P: gnd(11.5, 1.4, -41.5), L: part('giga', 'Chest'), F: 52, E: 'inout' },
      { B: 7, P: gnd(11, 1.6, -41), L: part('giga', 'Head', [0, -1, 0]), F: 50, E: 'inout' },
    ], Hand: 0.35, Smooth: 0.45 },
    Cues: [
      [0.2, 'White', 0, 1.2, 'Dust'],
      [1.0, 'Sfx', 'StompBig', 1.2, 0.42], [1.0, 'Shake', 0.8], [1.02, 'Dust', part('giga', 'LeftFoot'), 2.4],
      [2.7, 'Sfx', 'StompBig', 1.25, 0.41], [2.7, 'Shake', 0.9], [2.72, 'Dust', part('giga', 'RightFoot'), 2.4],
      [4.3, 'Sfx', 'StompBig', 1.3, 0.4], [4.3, 'Shake', 1.0], [4.32, 'Dust', part('giga', 'LeftFoot'), 2.6],
      [4.6, 'SunBurst', 0.4], [4.8, 'Sfx', 'Growl', 1.1, 0.5],
    ],
    Score: score(10, 10, 7, 9, 10, 10),
  },
  GT_Roar: {
    Zone: 'GiantPlains', At: DEN(), Beats: 8, Subject: ['giga'], Focus: 'Head', Grade: 'Golden',
    Note: 'CLIMAX. Low in front: it lowers its head and roars down the lens; a dust wave rolls at the camera; PLAINS TITAN.',
    Actors: [giga({ Spot: GT_SPOT, Face: [-14, -54] }, { Acts: [[0, 'Roar', 0.85]] })],
    Cam: { Keys: [
      { B: 0, P: gnd(-4, 1.2, -62), L: part('giga', 'Head', [0, -1.5, 0]), F: 48 },
      { B: 2.3, P: gnd(-3.5, 1.2, -61.5), L: part('giga', 'Head', [0, -1.5, 0]), F: 46, E: 'inout' },
      { B: 8, P: gnd(-2, 1.3, -59), L: part('giga', 'Head', [0, -2, 0]), F: 38, E: 'out' },
    ], Hand: 0.45, Smooth: 0.3 },
    Cues: [
      [0.4, 'Sfx', 'Growl', 0.8, 0.6],
      [2.3, 'Sting', 'Reveal', 0.9], [2.3, 'Sfx', 'RoarBoss', 1.0, 0.78], [2.3, 'Flash', 0.45], [2.3, 'Shake', 1.8], [2.3, 'Punch', 7],
      [2.35, 'RoarWave', 'giga', 2.2], [2.4, 'DustWave', gnd(10, 0, -54), gnd(-4, 0, -62), 2.4], [2.6, 'Dust', gnd(4, 0, -58), 3], [2.8, 'Dust', gnd(16, 0, -56), 3],
      [2.45, 'Title', 'PLAINS TITAN', 'BOSS OF GIANT PLAINS', 'Teal'], [2.45, 'SunBurst', 0.6],
    ],
    Score: score(10, 10, 8, 9, 9, 10),
  },
  GT_Lunge: {
    Zone: 'GiantPlains', At: DEN(), Beats: 3, Subject: ['giga'], Focus: 'Head',
    Note: 'Locked close-up: the Titan snaps at the camera; its jaws fill the frame on the downbeat.',
    Actors: [giga({ Spot: GT_SPOT, Face: [-4, -62] }, { Acts: [[0.1, 'Attack', 1.0]] })],
    // (backed off: the snap carried its head right through the lens - testers saw the inside of its skull)
    Cam: { From: of('giga', [1.2, 8.6, -23]), To: of('giga', [0.8, 8.3, -20]), Look: part('giga', 'Head', [0, -0.5, 0]), Fov: [50, 60], Ease: 'in', Hand: 0.8, Smooth: 0.15 },
    Cues: [[1.2, 'Sfx', 'Snap', 1.1, 0.7], [1.25, 'Shake', 1.6], [1.25, 'Punch', 10], [1.3, 'Flash', 0.5], [1.3, 'Dust', gnd(8, 0, -55), 2.4]],
    Score: score(9, 9, 9, 8, 8, 9),
  },

  // ------------------------------------------------------------------ TIDEBREAKER
  TB_Dock: {
    Zone: 'SpineRiver', At: BAY, Beats: 6, Subject: ['me'], Grade: 'Dusk',
    Note: 'HOOK. Behind you on the dock at dusk: gulls lift off the water, the bay goes glass-flat and dark, and a line of bubbles comes in at the dock.',
    Actors: [crew('me', 1, { Move: { Spot: TB_ME, Face: [0, 10] } })],
    Cam: { From: [1.5, 11, -52], To: [1, 9.5, -47], Look: [0, 0, 2], LookTo: [0, 0, -2], Fov: [46, 40], Ease: 'inout', Hand: 0.3 },
    Cues: [
      [0.8, 'Sfx', 'SeaRoar', 0.25, 0.38],
      [2.4, 'Birds', [-6, 2.5, 22], 10, [-50, 40, 70]], [2.45, 'Sfx', 'Screech2', 0.35, 1.6], [2.6, 'Grade', 'Deep', 2.2],
      [3.4, 'Bubbles', [2, 0.3, 10], 1.2], [3.9, 'Bubbles', [0, 0.3, 0], 1.4], [4.4, 'Bubbles', [1, 0.3, -12], 1.6], [4.9, 'Bubbles', [0, 0.3, -22], 1.8],
      [5.0, 'Ripple', [0, 0.3, -23], 1.4], [5.0, 'Sfx', 'Splash', 0.35, 0.5], [5.0, 'Shake', 0.3],
    ],
    Score: score(8, 7, 5, 9, 8, 8),
  },
  TB_Under: {
    Zone: 'SpineRiver', At: BAY, Beats: 6, Subject: ['me'], Grade: 'Underwater',
    Note: 'Under the water by the dock, looking up at you against the light: a shape the size of a whale glides over the lens, one eye burning.',
    Actors: [
      crew('me', 1, { Move: { Spot: TB_ME, Face: [0, 10] } }),
      dino('mosa', 'Mosasaurus', { Path: [[-24, 2], [-10, -14], [8, -17], [24, -4]], Beats: 6, Air: -5.6 }, SEA({ Loco: 'Run', Silhouette: [0, 6], Rim: 'Teal' })),
    ],
    Cam: { From: [2.4, -7.6, -14], To: [2.8, -7.6, -14.8], Look: [0, 4.5, -31.5], LookTo: [-0.4, 4, -31], Fov: [66, 70], Ease: 'linear', Hand: 0.4 },
    Cues: [
      [0, 'Bubbles', [3, -7, -18], 1.0], [1.6, 'Sfx', 'SeaRoar', 0.6, 0.5], [2.6, 'Bubbles', [0, -5, -24], 2.0], [2.8, 'Shake', 0.5],
      [4.0, 'Bubbles', [8, -5, -23], 1.6],
    ],
    Score: score(10, 9, 7, 8, 10, 9),
  },
  TB_Circle: {
    Zone: 'SpineRiver', At: BAY, Beats: 5, Subject: ['mosa'], Focus: 'Center', Grade: 'Night',
    Note: 'High over the ring of docks, you tiny on the east dock: a huge dark shape circles under the water, eyes burning.',
    Actors: [
      crew('me', 1, { Move: { Spot: TB_ME, Face: [0, 10] } }),
      dino('mosa', 'Mosasaurus', { Path: [[18, 0], [12.7, 12.7], [0, 18], [-12.7, 12.7], [-18, 0], [-12.7, -12.7], [0, -18]], Beats: 5, Air: -6.6 }, SEA({ Loco: 'Run', Silhouette: [0, 5], EyesOnly: true })),
    ],
    Cam: { From: [16, 40, -56], To: [12, 35, -50], Look: [0, -3, -4], LookTo: [-3, -3, -2], Fov: [44, 40], Ease: 'linear', Hand: 0.4 },
    Cues: [
      [0.5, 'Sfx', 'SeaRoar', 0.7, 0.48], [1.5, 'Bubbles', [16, 0.3, 6], 1.4], [2.0, 'Ripple', [-12, 0.3, 12], 1.2], [3.0, 'Bubbles', [-16, 0.3, 4], 1.6],
      [3.6, 'Shake', 0.4], [3.6, 'Sfx', 'Growl', 0.5, 0.4],
    ],
    Score: score(10, 9, 7, 8, 10, 8),
  },
  TB_Wake: {
    Zone: 'SpineRiver', At: BAY, Beats: 4, Subject: ['mosa'], Focus: 'Chest', Grade: 'Deep',
    Note: 'Low on the dock at the waterline: a black back cuts a wake straight at you, faster and faster - and dives. Silence.',
    Actors: [
      mark('water', [0, -8], 0.3),
      dino('mosa', 'Mosasaurus', { Path: [[2, 34], [1, -18]], Beats: 3.4, Air: [[0, -4.4], [2.5, -4.4], [3.1, -8.6, 'in']] }, SEA({ Loco: 'Run', Silhouette: [0, 4.2], EyesOnly: true, ClipOK: true, Until: 3.0 })),
    ],
    Cam: { Keys: [
      { B: 0, P: [2.6, 2.8, -28.5], L: [0, 0.5, 10], F: 44 },
      { B: 2.2, P: [2.5, 2.8, -28.7], L: [0.5, -1.5, 0], F: 50, E: 'inout' },
      { B: 4, P: [2.4, 2.7, -29], L: [0.8, -4.5, -12], F: 56, E: 'inout' },
    ], Hand: 0.35, Smooth: 0.2 },
    Cues: [
      [0.5, 'Sfx', 'SeaRoar', 0.6, 0.6],
      [0.4, 'Splash', [2, 0.3, 18], 0.7], [1.0, 'Splash', [2, 0.3, 9], 0.8], [1.6, 'Splash', [1.5, 0.3, 0], 0.9], [2.2, 'Splash', [1.5, 0.3, -9], 1.0], [2.7, 'Splash', [1, 0.3, -16], 1.1],
      [1.6, 'Sfx', 'Splash', 0.4, 0.7], [2.6, 'Sfx', 'Splash', 0.6, 0.6], [2.6, 'Shake', 0.3],
      [2.95, 'Splash', [1, 0.3, -12], 1.8], [2.95, 'Sfx', 'Splash', 0.8, 0.5], [2.95, 'Shake', 0.5],
    ],
    Score: score(9, 8, 9, 9, 9, 9),
  },
  TB_Breach: {
    Zone: 'SpineRiver', At: BAY, Beats: 9, Subject: ['mosa'], Focus: 'Head', Grade: 'Deep',
    Note: 'CLIMAX. It EXPLODES out of the bay beside the dock, hangs in slow motion (TIDEBREAKER), and crashes down; spray hits the lens.',
    Actors: [
      crew('me', 1, { Move: { Spot: TB_ME, Face: [0, 10] }, Acts: [[1.4, 'Startle']] }),
      dino('mosa', 'Mosasaurus', { Spot: [4, -14], Face: [4, 30], Air: -0.5 }, SEA({ Sig: { From: 1.3 }, Hidden: [1.2], ClipOK: true })),
    ],
    Cam: { Keys: [
      { B: 0, P: [-12, 1.4, -21], L: [4, 3, -14], F: 54 },
      { B: 1.3, P: [-12, 1.4, -21.4], L: part('mosa', 'Head', [0, -2, 0]), F: 60, E: 'out' },
      { B: 9, P: [-12.8, 1.6, -22], L: part('mosa', 'Head', [0, -1, 0]), F: 54, E: 'inout' },
    ], Hand: 0.6, Smooth: 0.25 },
    Cues: [
      [1.37, 'Grade', 'Hero', 0.2], [1.37, 'Sfx', 'Breach', 1.0, 0.9], [1.37, 'Flash', 0.6], [1.37, 'Splinter', [4, 2, -18], 1.2], [1.4, 'LensDrops', 0.6], [1.37, 'Shake', 1.4],
      [1.37, 'Splash', [4, 0.4, -14], 2.8], [1.4, 'Sting', 'Reveal', 1.0],
      // (the signature's own clock: out of the water at 1.37 beats, the roar at the top of the arc 2.94, the crash 6.83)
      [2.94, 'Sfx', 'SeaRoar', 1.4, 0.8], [2.94, 'Title', 'TIDEBREAKER', 'BOSS OF SPINE RIVER', 'Teal'], [2.94, 'SunBurst', 0.5], [2.94, 'Punch', 6],
      [6.83, 'LensDrops', 1.0], [6.83, 'Sfx', 'Splash', 1.2, 0.7], [6.83, 'Sfx', 'Breach', 0.8, 0.6], [6.83, 'Shake', 1.6], [6.83, 'White', 0.5, 0.05], [7.0, 'White', 0, 0.6],
    ],
    Score: score(10, 10, 9, 9, 9, 10),
  },
  TB_Roar: {
    Zone: 'SpineRiver', At: BAY, Beats: 5, Subject: ['mosa'], Focus: 'Head', Grade: 'Deep',
    Note: 'Low on the dock: it surfaces in front of you, water pouring off its head, and roars at the lens.',
    Actors: [dino('mosa', 'Mosasaurus', { Spot: [0, -6], Face: [0, -40], Air: -3.4 }, SEA({ Acts: [[0.3, 'Roar', 0.9]] }))],
    Cam: { From: [3, 3.0, -29], To: [2.5, 2.9, -27.8], Look: part('mosa', 'Head', [0, -0.5, 0]), Fov: [48, 40], Ease: 'out', Hand: 0.45 },
    Cues: [
      [0.1, 'Splash', [0, 0.4, -16], 1.6], [2.55, 'Sfx', 'SeaRoar', 1.3, 0.75], [2.55, 'Shake', 1.2], [2.6, 'RoarWave', 'mosa', 1.8], [2.6, 'LensDrops', 0.7],
    ],
    Score: score(9, 9, 7, 9, 8, 9),
  },

  // ------------------------------------------------------------------ SCYTHE KING
  SK_Grove: {
    Zone: 'RedCliffs', At: DEN(), Beats: 6, Subject: ['throne'], Grade: 'Dusk',
    Note: 'HOOK. A slow dolly through the quiet grove toward an empty mossy throne, red leaves drifting; far off, a blade sings.',
    Actors: [mark('throne', [0, 36], 4)],
    Cam: { From: [4, 6, -30], To: [3, 5.5, -18], Look: [0, 6, 36], Fov: [46, 40], Ease: 'inout', Hand: 0.35 },
    Cues: [
      [0.2, 'Leaves', [0, 20, 0], 26, 30], [2.4, 'Leaves', [-10, 22, 14], 16, 20],
      [3.6, 'Sfx', 'Slash', 0.35, 1.5], [4.6, 'Sfx', 'Dodge', 0.4, 0.6], [5.2, 'Sfx', 'TreeCrack', 0.6, 0.9],
    ],
    Score: score(7, 7, 5, 9, 8, 8),
  },
  SK_Fall: {
    Zone: 'RedCliffs', At: DEN(), Beats: 5, Subject: [], Grade: 'Dusk',
    Note: 'Low in the grove: a 40-stud conifer tips and crashes down, cut clean through; then a second falls toward the lens.',
    Actors: [],
    Cam: { From: [6, 2.2, -12], To: [7.5, 2.4, -16], Look: [-18, 20, 22], LookTo: [8, 12, 16], Fov: [54, 60], Ease: 'inout', Hand: 0.6 },
    Cues: [
      [0.0, 'Sfx', 'Slash', 0.7, 1.3], [0.3, 'Sfx', 'TreeCrack', 1.0, 0.8], [0.35, 'TreeFall', [-21.3, 0, 23.4], [-8, 0, -2], 1.3],
      [2.9, 'Dust', [-12, 0, 8], 3], [2.9, 'Shake', 0.9], [2.9, 'Sfx', 'StompBig', 1.2, 0.6],
      [1.3, 'Sfx', 'Slash', 0.8, 1.2], [1.6, 'Sfx', 'TreeCrack', 1.0, 0.9], [1.65, 'TreeFall', [31.4, 0, 18.3], [14, 0, -4], 1.2],
      [3.95, 'Dust', [18, 0, 4], 3], [3.95, 'Shake', 1.0], [3.95, 'Sfx', 'StompBig', 1.1, 0.55],
    ],
    Score: score(9, 6, 9, 8, 10, 8),
  },
  SK_Claws: {
    Zone: 'RedCliffs', At: DEN(), Beats: 6, Subject: ['sk'], Focus: 'RightClaw', Grade: 'Dusk',
    Note: 'Out of the dust: a black shape, and three claws as long as you are, catching the light. They tap together.',
    Actors: [
      dino('sk', 'Therizinosaurus', { Path: [[2, 30], [1, 14]], Beats: 3.4, Ease: 'out' }, { Scale: 1.0, Loco: 'Walk', LocoKeys: [[3.4, 'Idle']], Acts: [[3.0, 'CrossGuard', 1]], Silhouette: [0, 6.2], Rim: 'Cream' }),
    ],
    Cam: { Keys: [
      { B: 0, P: [6.5, 4.5, 2], L: part('sk', 'RightClaw'), F: 32 },
      { B: 6, P: [6, 5, 0], L: part('sk', 'RightClaw'), F: 28, E: 'inout' },
    ], Hand: 0.3, Smooth: 0.6 },
    Cues: [
      [0.4, 'Dust', [1, 0, 24], 2.4], [1.0, 'Sfx', 'StompBig', 0.6, 0.6], [1.0, 'Shake', 0.3], [2.6, 'Sfx', 'StompBig', 0.7, 0.6], [2.6, 'Shake', 0.35],
      [2.0, 'Glint', part('sk', 'RightClaw'), 1.0], [2.0, 'Sfx', 'Slash', 0.3, 2.0],
      [4.05, 'Glint', part('sk', 'RightClaw'), 1.2], [4.05, 'Glint', part('sk', 'LeftClaw'), 1.2], [4.0, 'Sfx', 'Slash', 0.5, 1.7], [5.2, 'Sfx', 'Growl', 0.8, 0.85],
    ],
    Score: score(10, 9, 6, 9, 10, 9),
  },
  SK_Reveal: {
    Zone: 'RedCliffs', At: DEN(), Beats: 6, Subject: ['sk'], Focus: 'Head', Grade: 'Dusk',
    Note: 'Low and wide: it steps out of the dust into the last of the light and sweeps its claws wide.',
    Actors: [
      dino('sk', 'Therizinosaurus', { Path: [[1, 14], SK_SPOT], Beats: 2, Ease: 'out' }, { Scale: 1.0, Loco: 'Walk', LocoKeys: [[2, 'Idle']], Acts: [[2.2, 'ScytheSweep', 0.8]], Silhouette: [0, 2], Rim: 'Cream' }),
    ],
    Cam: { From: [-10, 1.3, -6], To: [-9, 1.4, -8], Look: part('sk', 'Head', [0, -4, 0]), Fov: [50, 46], Ease: 'out', Hand: 0.45 },
    Cues: [
      [1.0, 'Sfx', 'StompBig', 0.9, 0.55], [1.0, 'Shake', 0.5], [2.0, 'SunBurst', 0.35], [2.0, 'Sfx', 'Growl', 0.9, 0.8],
      [4.6, 'Sfx', 'Slash', 0.9, 1.0], [4.6, 'Shake', 0.6], [4.65, 'Leaves', [0, 20, 6], 20, 30],
    ],
    Score: score(9, 9, 7, 9, 8, 9),
  },
  SK_Slash: {
    Zone: 'RedCliffs', At: DEN(), Beats: 7, Subject: ['sk'], Focus: 'Chest',
    Note: 'CLIMAX. It slashes at the lens; the screen splits along the cut; SCYTHE KING in the gap; then the roar.',
    Actors: [dino('sk', 'Therizinosaurus', { Spot: SK_SPOT, Face: [0, -30] }, { Scale: 1.0, Acts: [[0, 'XSlash', 1.0], [3.4, 'Roar', 1.0]] })],
    Cam: { From: [1.5, 7.5, -8.5], To: [1, 8, -5.5], Look: part('sk', 'Chest', [0, 2, 0]), Fov: [52, 58], Ease: 'in', Hand: 0.6 },
    Cues: [
      [0.0, 'Grade', 'Dusk', 0.1], [1.4, 'Sfx', 'Dodge', 0.9, 0.8],
      [3.0, 'Sfx', 'Slash', 1.2, 0.9], [3.0, 'Slash', 'Cream'], [3.0, 'Shake', 1.2], [3.0, 'Punch', 8], [3.0, 'Flash', 0.4], [3.0, 'Sting', 'Reveal', 0.9],
      [3.05, 'Title', 'SCYTHE KING', 'BOSS OF RED CLIFFS', 'Cream'],
      [5.55, 'Sfx', 'RoarBoss', 1.0, 0.85], [5.55, 'Shake', 1.2], [5.6, 'RoarWave', 'sk', 1.8], [5.6, 'Leaves', [0, 22, 4], 26, 40],
    ],
    Score: score(10, 10, 9, 9, 10, 10),
  },
  SK_Pose: {
    Zone: 'RedCliffs', At: DEN(), Beats: 4, Subject: ['sk'], Focus: 'Head',
    Note: 'Low hero: cut leaves float down as it crosses its claws in an X; they glint.',
    Actors: [dino('sk', 'Therizinosaurus', { Spot: SK_SPOT, Face: [0, -30] }, { Scale: 1.0, Acts: [[0, 'CrossGuard', 1]] })],
    Cam: { From: [5, 1.2, -6], To: [4.4, 1.3, -7.5], Look: part('sk', 'Head', [0, -3, 0]), Fov: [44, 40], Ease: 'out', Hand: 0.4 },
    Cues: [[0, 'Leaves', [0, 22, 6], 26, 40], [1.0, 'Glint', part('sk', 'RightClaw'), 1.0], [1.0, 'Glint', part('sk', 'LeftClaw'), 1.0], [1.0, 'Sfx', 'Slash', 0.4, 1.8], [1.4, 'Sfx', 'Growl', 0.8, 0.8]],
    Score: score(8, 9, 5, 9, 8, 9),
  },

  // ------------------------------------------------------------------ FROSTFANG
  FF_Lake: {
    Zone: 'FrostForest', At: DEN(), Beats: 6, Subject: ['me'], Grade: 'Frost',
    Note: 'HOOK. Low behind you walking out onto the frozen lake: snow drifting, quiet; the ice groans under your feet and the wind picks up.',
    Actors: [crew('me', 1, { Move: { Path: [[-2, -38], [1, -20]], Start: 0.3, Beats: 5, Ease: 'out' } })],
    Cam: { Keys: [
      { B: 0, P: of('me', [-3.6, 4.4, 12]), L: of('me', [1.2, 3, -20]), F: 50 },
      { B: 6, P: of('me', [-3.0, 3.8, 10]), L: of('me', [1, 3.2, -20]), F: 44, E: 'inout' },
    ], Hand: 0.35, Smooth: 0.5 },
    Cues: [
      [0, 'Snow', 0.15], [2.2, 'Sfx', 'IceCrack', 0.35, 0.5], [3.0, 'Snow', 0.4], [4.0, 'White', 0.15, 1.5],
      [4.4, 'Sfx', 'IceCrack', 0.5, 0.4], [4.4, 'Shake', 0.2],
    ],
    Score: score(7, 7, 5, 9, 8, 8),
  },
  FF_Storm: {
    Zone: 'FrostForest', At: DEN(), Beats: 4, Subject: ['me'], Grade: 'Storm',
    Note: 'Beside you looking across the lake: a storm rolls over the ice at you until there is nothing but white.',
    Actors: [crew('me', 1, { Move: { Spot: [1, -20], Face: [0, 20] }, Acts: [[1.2, 'Startle']] })],
    Cam: { From: [7.5, 3.6, -31.5], To: [6.8, 3.4, -29.5], Look: [-1, 4, 10], LookTo: [-0.5, 3.8, 4], Fov: [50, 44], Ease: 'inout', Hand: 0.6 },
    Cues: [[0, 'White', 0.15, 0.01], [0, 'Snow', 0.6], [0.4, 'Sfx', 'Dodge', 0.6, 0.45], [0.6, 'White', 0.62, 2.6], [1.2, 'Snow', 1.0], [2.4, 'Sfx', 'Dodge', 0.5, 0.4]],
    Score: score(8, 7, 6, 8, 8, 8),
  },
  FF_Whiteout: {
    Zone: 'FrostForest', At: DEN(), Beats: 7, Subject: ['ff'], Focus: 'Head', Grade: 'Whiteout',
    Note: 'White blizzard; only a dark shape and two glowing eyes walk closer, then stop and tilt its head to listen.',
    Actors: [dino('ff', 'Yutyrannus', { Path: [[0, 36], FF_SPOT], Start: 0.5, Beats: 4, Ease: 'out', Face: [0, -20] }, { Scale: 1.05, Loco: 'Walk', LocoKeys: [[4.5, 'Idle']], Acts: [[4.6, 'Listen', 1.0]], Silhouette: [0, 7], Rim: 'Ice' })],
    Cam: { From: [2.5, 2.4, -16], To: [2, 2.6, -12.5], Look: part('ff', 'Head', [0, -1, 0]), Fov: [46, 38], Ease: 'linear', Hand: 0.5, Smooth: 0.6 },
    Cues: [
      [0.0, 'White', 0.62, 0.01], [0.0, 'Snow', 1.0], [0.0, 'Grade', 'Whiteout', 0.01],
      [1.1, 'Sfx', 'StompBig', 0.6, 0.55], [2.4, 'Sfx', 'StompBig', 0.75, 0.55], [2.4, 'Shake', 0.2], [3.7, 'Sfx', 'StompBig', 0.9, 0.55], [3.7, 'Shake', 0.3],
      [5.3, 'Sfx', 'Growl', 1.0, 0.6],
    ],
    Score: score(10, 8, 6, 8, 10, 9),
  },
  FF_Breath: {
    Zone: 'FrostForest', At: DEN(), Beats: 3, Subject: ['ff'], Focus: 'Head', Grade: 'Whiteout',
    Note: 'Its snout pushes out of the white an arm\'s length from the lens; it sniffs, breath steaming.',
    Actors: [dino('ff', 'Yutyrannus', { Path: [FF_SPOT, [0, 12.5]], Beats: 2, Ease: 'out', Face: [0, -20] }, { Scale: 1.05, Loco: 'Walk', LocoKeys: [[2, 'Idle']], Acts: [[0.4, 'Sniff', 1]], Silhouette: [0, 3.2], Rim: 'Ice' })],
    Cam: { From: [3, 7.8, -12], To: [2.6, 7.6, -10.5], Look: part('ff', 'Head', [0, -0.5, 0]), Fov: [34, 28], Ease: 'out', Hand: 0.3, Smooth: 0.5 },
    Cues: [[0, 'White', 0.62, 0.01], [0, 'Snow', 1.0], [0, 'Grade', 'Whiteout', 0.01], [0.8, 'Sfx', 'Growl', 1.2, 0.5], [2.0, 'Shake', 0.25]],
    Score: score(9, 9, 5, 8, 10, 9),
  },
  FF_Roar: {
    Zone: 'FrostForest', At: DEN(), Beats: 8, Subject: ['ff'], Focus: 'Head',
    Note: 'CLIMAX. The frost roar blasts the blizzard away from the lens in a ring; FROSTFANG lands; ice cracks run at the camera.',
    Actors: [dino('ff', 'Yutyrannus', { Spot: [0, 12.5], Face: [0, -20] }, { Scale: 1.05, Acts: [[0, 'FrostRoar', 1.0]], Silhouette: [0, 1.95], Rim: 'Ice' })],
    Cam: { Keys: [
      { B: 0, P: [3, 4.2, -6], L: part('ff', 'Head', [0, -1.5, 0]), F: 50 },
      { B: 1.95, P: [2.6, 4.1, -4.5], L: part('ff', 'Head', [0, -1.5, 0]), F: 54, E: 'out' },
      { B: 8, P: [2.2, 3.8, -3], L: part('ff', 'Head', [0, -1.5, 0]), F: 44, E: 'inout' },
    ], Hand: 0.6, Smooth: 0.3 },
    Cues: [
      [0.0, 'White', 0.62, 0.01], [0.0, 'Snow', 1.0], [0.0, 'Grade', 'Whiteout', 0.01],
      [1.95, 'White', 0, 0.35], [1.95, 'Snow', 0], [1.95, 'Grade', 'Frost', 0.3], [1.95, 'Sfx', 'RoarBoss', 1.0, 1.08], [1.95, 'Sting', 'Reveal', 0.9],
      [1.95, 'RoarWave', 'ff', 2.2], [1.95, 'Flash', 0.4], [1.95, 'Punch', 7], [2.0, 'Shake', 1.4],
      [2.05, 'Title', 'FROSTFANG', 'BOSS OF FROST FOREST', 'Ice'], [2.05, 'SunBurst', 0.5],
      [2.1, 'Fx', 'ff', 'IceCrack', { Scale: 2.2 }], [2.1, 'Sfx', 'IceCrack', 1.0, 0.8],
    ],
    Score: score(10, 10, 8, 9, 10, 10),
  },
  FF_Stomp: {
    Zone: 'FrostForest', At: DEN(), Beats: 4, Subject: ['ff'], Focus: 'Chest', Grade: 'Frost',
    Note: 'Down at the ice: one stomp, the ice cracks out to the lens and the snow jumps.',
    Actors: [dino('ff', 'Yutyrannus', { Spot: [0, 12.5], Face: [0, -20] }, { Scale: 1.05, Acts: [[0.1, 'IceStomp', 1.0]] })],
    Cam: { From: [5, 1.0, -2], To: [4.5, 1.1, -1], Look: part('ff', 'Chest', [0, -2.5, 0]), Fov: [54, 50], Ease: 'linear', Hand: 0.6 },
    Cues: [[1.75, 'Sfx', 'StompBig', 1.3, 0.55], [1.75, 'Sfx', 'IceCrack', 1.0, 0.7], [1.75, 'Cracks', [0, 0.2, 6], 2.4], [1.8, 'Shake', 1.0], [2.6, 'Sfx', 'Growl', 0.9, 0.6]],
    Score: score(8, 8, 7, 9, 8, 8),
  },

  // ------------------------------------------------------------------ DAWN KING
  DK_Drink: {
    Zone: 'DawnDesert', At: DEN(), Beats: 6, Subject: ['co'], Focus: 'Head', Grade: 'Dawn',
    Note: 'HOOK. Sunrise dolly over the bones of the wash to a little Coelophysis drinking at a mud wallow; it chirps.',
    Actors: [dino('co', 'Coelophysis', { Spot: DK_CO, Face: [16, 20] }, { Scale: 1.3, Acts: [[0, 'Drink', 1.0]] })],
    Cam: { From: [25, 1.5, 6], To: [19.5, 1.5, 10.5], Look: [13.8, 1.6, 17.8], Fov: [44, 38], Ease: 'out', Hand: 0.35 },
    Cues: [[0.2, 'SunBurst', 0.35], [1.6, 'Ripple', [14.4, 0.15, 18], 0.4], [3.6, 'Ripple', [14.4, 0.15, 18], 0.4], [2.6, 'Sfx', 'BabyChirp', 0.5, 1.15]],
    Score: score(8, 6, 6, 9, 9, 8),
  },
  DK_Eyes: {
    Zone: 'DawnDesert', At: DEN(), Beats: 6, Subject: ['co'], Focus: 'Head', Grade: 'Dawn',
    Note: 'At mud level: bubbles behind the drinking Coelophysis - then two burning eyes rise out of the mud, like a crocodile\'s.',
    Actors: [
      dino('co', 'Coelophysis', { Spot: DK_CO, Face: [16, 20] }, { Scale: 1.3, Acts: [[0, 'Drink', 1.0], [4.6, 'LookAround', 1.2]] }),
      dino('dk', 'Postosuchus', { Spot: [18.5, 22.5], Face: [10, 14], Air: [[0, -9.6], [1.6, -9.6], [4.4, -7.4, 'out']] }, { Scale: 1.1, Hidden: [1.6], Silhouette: [1.6, 6], Rim: 'Orange', ClipOK: true }),
    ],
    Cam: { From: [5.5, 1.5, 7.5], To: [6.5, 1.4, 8.9], Look: [15, 2.6, 19.5], Fov: [42, 36], Ease: 'linear', Hand: 0.2, Smooth: 0.4 },
    Cues: [
      [0.6, 'Fx', 'dk', 'MudBubble', { Scale: 1 }], [1.6, 'Fx', 'dk', 'MudBubble', { Scale: 1.3 }], [1.6, 'Ripple', [18, 0.15, 22], 0.6],
      [2.4, 'Sfx', 'Growl', 0.5, 0.55], [3.4, 'Ripple', [18, 0.15, 22], 0.8], [4.4, 'Sfx', 'Growl', 0.8, 0.6],
    ],
    Score: score(10, 9, 5, 8, 10, 9),
  },
  DK_Ambush: {
    Zone: 'DawnDesert', At: DEN(), Beats: 5, Subject: ['dk'], Focus: 'Head', Grade: 'Dawn',
    Note: 'The wallow erupts: the Dawn King bursts out of the mud as the Coelophysis bolts, screeching (it gets away).',
    Actors: [
      dino('co', 'Coelophysis', { Path: [DK_CO, [4, -2], [-26, -34]], Speed: 26, Start: 1.6 }, { Scale: 1.3, Loco: 'Idle', LocoKeys: [[1.6, 'Run']], Acts: [[0, 'Drink', 1.0], [1.7, 'Roar', 1.3]] }),
      dino('dk', 'Postosuchus', { Spot: DK_SPOT, Face: [6, 4], Air: [[0, -9], [1.7, -9], [2.3, 0, 'out']] }, { Scale: 1.1, Hidden: [1.65], Acts: [[1.65, 'MudAmbush', 1.0]], Silhouette: [1.65, 5.2], Rim: 'Orange', ClipOK: true }),
    ],
    Cam: { From: [4, 1.8, 6], To: [1, 2.6, 1], Look: [13, 2.5, 17], LookTo: part('dk', 'Head', [0, -1, 0]), Fov: [44, 34], Ease: 'inout', Hand: 0.8 },
    Cues: [
      [1.0, 'Fx', 'dk', 'MudBubble', { Scale: 1.6 }], [1.7, 'Fx', 'dk', 'MudBurst', { Scale: 2.2 }], [1.7, 'Shake', 1.2], [1.7, 'Sfx', 'Breach', 0.8, 1.3],
      [1.75, 'Sfx', 'Screech', 0.9, 1.5], [2.3, 'Sfx', 'Snap', 1.1, 0.75], [2.3, 'Punch', 6], [2.35, 'LensDrops', 0.5, 'Mud'],
    ],
    Score: score(10, 9, 10, 8, 10, 9),
  },
  DK_Rise: {
    Zone: 'DawnDesert', At: DEN(), Beats: 9, Subject: ['dk'], Focus: 'Head', Grade: 'Backlit',
    Note: 'CLIMAX. Low under it against the rising sun: black and rim-lit, it rears up on its hind legs and roars; DAWN KING over the rays.',
    Actors: [dino('dk', 'Postosuchus', { Spot: DK_SPOT, Face: [6, 4] }, { Scale: 1.1, Acts: [[0.3, 'UprightCharge', 0.6], [3.4, 'TerrorRoar', 1.0]], Silhouette: [0, 4.95], Rim: 'Orange' })],
    Cam: { Keys: [
      { B: 0, P: [13, 1.1, 5], L: part('dk', 'Head', [0, -1.5, 0]), F: 50 },
      { B: 4.95, P: [13.2, 1.05, 4.4], L: part('dk', 'Head', [0, -1.5, 0]), F: 52, E: 'inout' },
      { B: 9, P: [13.6, 1.0, 3.4], L: part('dk', 'Head', [0, -1, 0]), F: 44, E: 'out' },
    ], Hand: 0.5, Smooth: 0.3 },
    Cues: [
      [0.0, 'SunBurst', 0.7], [1.5, 'Sfx', 'Growl', 1.0, 0.7], [2.4, 'Sfx', 'StompBig', 0.9, 0.6], [2.4, 'Shake', 0.6],
      [4.95, 'Sfx', 'RoarBoss', 1.0, 0.95], [4.95, 'Sting', 'Reveal', 0.9], [4.95, 'Grade', 'Ember', 0.25], [4.95, 'Flash', 0.45], [4.95, 'Shake', 1.4], [4.95, 'Punch', 7],
      [5.0, 'Title', 'DAWN KING', 'BOSS OF DAWN DESERT', 'Orange'], [5.0, 'SunBurst', 0.7], [5.05, 'DustWave', [17, 0, 15], [6, 0, 4], 1.8],
    ],
    Score: score(10, 10, 8, 8, 10, 9),
  },
  DK_Shake: {
    Zone: 'DawnDesert', At: DEN(), Beats: 5, Subject: ['dk'], Focus: 'Head', Grade: 'Ember',
    Note: 'Low and close: it shakes the mud off like a wet dog - and it splatters across the lens.',
    Actors: [dino('dk', 'Postosuchus', { Spot: DK_SPOT, Face: [6, 4] }, { Scale: 1.1, Acts: [[0.4, 'BiteShake', 0.9]] })],
    Cam: { From: [6.5, 2.2, 4.5], To: [7.2, 2.3, 5.3], Look: part('dk', 'Head', [0, -1, 0]), Fov: [48, 42], Ease: 'out', Hand: 0.5 },
    Cues: [
      [1.2, 'Fx', 'dk', 'MudBurst', { Scale: 1.2, Spray: true }], [1.6, 'Fx', 'dk', 'MudBurst', { Scale: 1, Spray: true }], [1.5, 'LensDrops', 0.9, 'Mud'],
      [1.3, 'Sfx', 'Splash', 0.6, 0.6], [1.3, 'Shake', 0.5], [3.2, 'Sfx', 'Growl', 1.0, 0.7],
    ],
    Score: score(9, 9, 8, 9, 9, 9),
  },

  // ==================================================================================== TikTok-only extras
  // the egg you shouldn't have taken: in the king's lair, you lift a glowing legendary egg off the floor
  TT_EggGrab: {
    Zone: 'FernValley', At: DEN(), Beats: 4, Subject: ['p1'], Grade: 'Dark',
    Note: 'Over the shoulder in the lair: a player walks up and lifts a glowing legendary T. rex egg.',
    Actors: [
      crew('p1', 1, { Move: { Path: [[-3, -22], [0.6, -12.8]], Beats: 1.6, Ease: 'out', Face: [1.5, -9] }, Acts: [[1.6, 'Grab']], Carry: 1.9 }),
      { Id: 'egg', Egg: 'TyrannosaurusRex', Rarity: 'Legendary', Scale: 1.3, HeldBy: 'p1', HeldFrom: 1.9, Move: { Spot: [1.5, -10] } },
    ],
    Cam: { Keys: [
      { B: 0, P: [-11, 3.6, -19], L: [-2.5, 1.2, -18], F: 50 },
      { B: 1.8, P: [-9, 2.8, -15], L: [1.2, 1.4, -11], F: 42, E: 'inout' },
      { B: 4, P: [-8.5, 3, -14], L: of('p1', [0, 2.2, 0]), F: 38, E: 'out' },
    ], Hand: 0.6 },
    Cues: [[1.9, 'Sparkle', [1.5, 1.5, -10], 'Legendary'], [1.9, 'Sfx', 'ItemGet', 0.8, 1.0], [3.2, 'Sfx', 'StompBig', 0.7, 0.6], [3.2, 'Shake', 0.4]],
    Score: score(8, 6, 6, 9, 8, 8),
  },
  // the sea boss lunges at the dock: jaws fill the frame, black
  TB_Lunge: {
    Zone: 'SpineRiver', At: BAY, Beats: 3, Subject: ['mosa'], Focus: 'Head',
    Note: 'On the dock: the Tidebreaker erupts at the lens, jaws wide; spray; cut to black on the bite.',
    Actors: [dino('mosa', 'Mosasaurus', { Spot: [0, -8], Face: [0, -40], Air: [[0, -9], [0.5, -9], [1.3, -1.5, 'out']] }, SEA({ Acts: [[0.6, 'Roar', 1.2]], ClipOK: true }))],
    Cam: { From: [2, 4.4, -31], To: [1.5, 4.2, -29.5], Look: part('mosa', 'Head', [0, 0.5, 0]), Fov: [52, 60], Ease: 'in', Hand: 0.9, Smooth: 0.2 },
    Cues: [[0.6, 'Splash', [0, 1, -18], 2.6], [0.6, 'Sfx', 'Breach', 1.0, 1.1], [0.65, 'LensDrops', 1.0], [0.7, 'Sfx', 'SeaRoar', 1.3, 0.9], [1.9, 'Sfx', 'Snap', 1.2, 0.6], [1.9, 'Shake', 1.6], [1.9, 'Punch', 10], [2.0, 'Flash', 0.5], [2.15, 'Black', 0.6]],
    Score: score(10, 9, 9, 8, 9, 9),
  },
  // the blizzard closes back in over Frostfang (the loop point: the TikTok ends where it began)
  FF_Whiteback: {
    Zone: 'FrostForest', At: DEN(), Beats: 2, Subject: ['ff'], Focus: 'Head', Grade: 'Frost',
    Note: 'Loop: the blizzard rolls back in over Frostfang until there is nothing but white and two eyes.',
    Actors: [dino('ff', 'Yutyrannus', { Spot: [0, 12.5], Face: [0, -20] }, { Scale: 1.05, Acts: [[0, 'Listen', 1.0]], Silhouette: [1.2, 2], Rim: 'Ice' })],
    Cam: { From: [2.5, 2.6, -11], To: [2.5, 2.4, -14], Look: part('ff', 'Head', [0, -1, 0]), Fov: [40, 46], Ease: 'linear', Hand: 0.5 },
    Cues: [[0.0, 'Snow', 1.0], [0.0, 'White', 0.62, 0.9], [0.0, 'Grade', 'Whiteout', 0.9]],
    Score: score(7, 7, 4, 7, 9, 8),
  },

  // (debug: top-down plans of each den for authoring; not used by any sequence)
  DBG_FernValley_Top: { Zone: 'FernValley', At: DEN(), Beats: 1, Debug: true, Actors: [prop('o', { Shape: 'Box', Size: [2, 6, 2], Color: '#ff00ff' }, { Spot: [0, 0] }), prop('f', { Shape: 'Box', Size: [2, 6, 2], Color: '#00ffff' }, { Spot: [0, -20] }), prop('x', { Shape: 'Box', Size: [2, 6, 2], Color: '#ffff00' }, { Spot: [20, 0] })], Cam: { From: [0, 150, -10], To: [0, 150, -10.01], Look: [0, 0, -9], Fov: 70 } },
  DBG_GiantPlains_Top: { Zone: 'GiantPlains', At: DEN(), Beats: 1, Debug: true, Actors: [prop('o', { Shape: 'Box', Size: [2, 6, 2], Color: '#ff00ff' }, { Spot: [0, 0] }), prop('f', { Shape: 'Box', Size: [2, 6, 2], Color: '#00ffff' }, { Spot: [0, -20] }), prop('x', { Shape: 'Box', Size: [2, 6, 2], Color: '#ffff00' }, { Spot: [20, 0] })], Cam: { From: [0, 150, -10], To: [0, 150, -10.01], Look: [0, 0, -9], Fov: 70 } },
  DBG_Maw_Top: { Zone: 'SpineRiver', At: { Marker: 'FinalArena' }, Beats: 1, Debug: true, Actors: [dino('m', 'Mosasaurus', { Spot: [0, 0], Air: 0 }, { Scale: 0.9 })], Cam: { From: [0, 130, -5], To: [0, 130, -5.01], Look: [0, 0, -4], Fov: 70 } },
  DBG_SpineRiver_Top: { Zone: 'SpineRiver', At: BAY, Beats: 1, Debug: true, Subject: [], Actors: [prop('o', { Shape: 'Box', Size: [2, 6, 2], Color: '#ff00ff' }, { Spot: [0, 0] }), prop('f', { Shape: 'Box', Size: [2, 6, 2], Color: '#00ffff' }, { Spot: [0, -20] }), prop('x', { Shape: 'Box', Size: [2, 6, 2], Color: '#ffff00' }, { Spot: [20, 0] })], Cam: { From: [0, 150, -10], To: [0, 150, -10.01], Look: [0, 0, -9], Fov: 70 } },
  DBG_RedCliffs_Top: { Zone: 'RedCliffs', At: DEN(), Beats: 1, Debug: true, Actors: [prop('o', { Shape: 'Box', Size: [2, 6, 2], Color: '#ff00ff' }, { Spot: [0, 0] }), prop('f', { Shape: 'Box', Size: [2, 6, 2], Color: '#00ffff' }, { Spot: [0, -20] }), prop('x', { Shape: 'Box', Size: [2, 6, 2], Color: '#ffff00' }, { Spot: [20, 0] })], Cam: { From: [0, 150, -10], To: [0, 150, -10.01], Look: [0, 0, -9], Fov: 70 } },
  DBG_FrostForest_Top: { Zone: 'FrostForest', At: DEN(), Beats: 1, Debug: true, Actors: [prop('o', { Shape: 'Box', Size: [2, 6, 2], Color: '#ff00ff' }, { Spot: [0, 0] }), prop('f', { Shape: 'Box', Size: [2, 6, 2], Color: '#00ffff' }, { Spot: [0, -20] }), prop('x', { Shape: 'Box', Size: [2, 6, 2], Color: '#ffff00' }, { Spot: [20, 0] })], Cam: { From: [0, 150, -10], To: [0, 150, -10.01], Look: [0, 0, -9], Fov: 70 } },
  DBG_DawnDesert_Top: { Zone: 'DawnDesert', At: DEN(), Beats: 1, Debug: true, Actors: [prop('o', { Shape: 'Box', Size: [2, 6, 2], Color: '#ff00ff' }, { Spot: [0, 0] }), prop('f', { Shape: 'Box', Size: [2, 6, 2], Color: '#00ffff' }, { Spot: [0, -20] }), prop('x', { Shape: 'Box', Size: [2, 6, 2], Color: '#ffff00' }, { Spot: [20, 0] })], Cam: { From: [0, 150, -10], To: [0, 150, -10.01], Look: [0, 0, -9], Fov: 70 } },
};

// the six in-game reveals (TikTok.RevealFor(bossId) picks them by Boss), 15-25 s each at 123 BPM
const Sequences = [
  {
    Id: 'REVEAL_TyrantKing', Name: 'REVEAL: TYRANT KING', Category: 'BOSS REVEALS', Boss: 'TyrantKing',
    Shots: [['TK_Creep', 6], ['TK_Puddle', 4], ['TK_LightsOut', 5], ['TK_Behind', 8], ['TK_Eye', 3], ['TK_Roar', 9], ['TK_Hero', 5]],
  },
  {
    Id: 'REVEAL_Titan', Name: 'REVEAL: PLAINS TITAN', Category: 'BOSS REVEALS', Boss: 'Titan',
    Shots: [['GT_Pebbles', 5], ['GT_Stampede', 5], ['GT_Dust', 5], ['GT_Tilt', 7], ['GT_Roar', 8], ['GT_Lunge', 3]],
  },
  {
    Id: 'REVEAL_Tidebreaker', Name: 'REVEAL: TIDEBREAKER', Category: 'BOSS REVEALS', Boss: 'Tidebreaker',
    Shots: [['TB_Dock', 6], ['TB_Under', 6], ['TB_Circle', 5], ['TB_Wake', 4], ['TB_Breach', 9], ['TB_Roar', 5]],
  },
  {
    Id: 'REVEAL_Scythe', Name: 'REVEAL: SCYTHE KING', Category: 'BOSS REVEALS', Boss: 'Scythe',
    Shots: [['SK_Grove', 6], ['SK_Fall', 5], ['SK_Claws', 6], ['SK_Reveal', 6], ['SK_Slash', 7], ['SK_Pose', 4]],
  },
  {
    Id: 'REVEAL_Frostfang', Name: 'REVEAL: FROSTFANG', Category: 'BOSS REVEALS', Boss: 'Frostfang',
    Shots: [['FF_Lake', 6], ['FF_Storm', 4], ['FF_Whiteout', 7], ['FF_Breath', 3], ['FF_Roar', 8], ['FF_Stomp', 4]],
  },
  {
    Id: 'REVEAL_DawnKing', Name: 'REVEAL: DAWN KING', Category: 'BOSS REVEALS', Boss: 'DawnKing',
    Shots: [['DK_Drink', 6], ['DK_Eyes', 6], ['DK_Ambush', 5], ['DK_Rise', 9], ['DK_Shake', 5]],
  },
  // ---------------------------------------------------------------- the 7 TikToks (no on-screen text except the bosses' own names)
  {
    Id: 'TT_RATE_BOSS_INTROS', Name: 'RATE THE BOSS INTROS', Category: 'BOSS TIKTOKS',
    Hook: 'rate each boss intro 1-10 🦖 which one goes hardest? #roblox #dinosaur #robloxgames #fyp',
    Shots: [['TK_Behind', 3, 5], ['TK_Roar', 5, 2], ['GT_Tilt', 3, 4], ['GT_Roar', 4, 2], ['TB_Breach', 5, 1], ['SK_Slash', 4, 1], ['FF_Whiteout', 2, 5], ['FF_Roar', 4, 1], ['DK_Ambush', 2, 1], ['DK_Rise', 4, 4]],
  },
  {
    Id: 'TT_SEA_BOSS', Name: 'THE SEA BOSS', Category: 'BOSS TIKTOKS',
    Hook: 'they put a SEA BOSS in a roblox dinosaur game 🌊 #roblox #mosasaurus #robloxgames',
    Shots: [['TB_Under', 4, 1], ['TB_Wake', 4], ['TB_Breach', 9], ['TB_Lunge', 3]],
  },
  {
    Id: 'TT_HARVEST', Name: 'THE HARVEST', Category: 'BOSS TIKTOKS',
    Hook: 'this dinosaur has SWORDS for hands 😳 #roblox #therizinosaurus #dinosaur',
    Shots: [['SK_Fall', 5], ['SK_Claws', 6], ['SK_Slash', 7], ['SK_Pose', 4]],
  },
  {
    Id: 'TT_WHITEOUT_LOOP', Name: 'WHITEOUT (LOOP)', Category: 'BOSS TIKTOKS',
    Hook: 'wait for it… 🥶 #roblox #dinosaur #robloxgames',
    Shots: [['FF_Whiteout', 7], ['FF_Breath', 3], ['FF_Roar', 8], ['FF_Stomp', 4], ['FF_Whiteback', 2]],
  },
  {
    Id: 'TT_BEFORE_DINOSAURS', Name: 'BEFORE THE DINOSAURS', Category: 'BOSS TIKTOKS',
    Hook: 'the boss that\'s older than dinosaurs 🌅 #roblox #prehistoric #robloxgames',
    Shots: [['DK_Eyes', 6], ['DK_Ambush', 5], ['DK_Rise', 9], ['DK_Shake', 5]],
  },
  {
    Id: 'TT_STAMPEDE', Name: 'THE STAMPEDE', Category: 'BOSS TIKTOKS',
    Hook: 'when the whole herd runs the same direction… 💀 #roblox #giganotosaurus',
    Shots: [['GT_Pebbles', 5], ['GT_Stampede', 5], ['GT_Dust', 5], ['GT_Tilt', 7], ['GT_Roar', 8], ['GT_Lunge', 3]],
  },
  {
    Id: 'TT_STOLE_THE_EGG', Name: 'POV: YOU STOLE ITS EGG', Category: 'BOSS TIKTOKS',
    Hook: 'POV: you took the wrong egg 🥚🦖 #roblox #trex #robloxgames',
    Shots: [['TT_EggGrab', 4], ['TK_Puddle', 3, 1], ['TK_Behind', 8], ['TK_Roar', 9], ['RexBumperBite', 4]],
  },
];

// every shot a reveal plays is QC'd strictly (tools/gen/tiktok.js strictQc)
for (const seq of Sequences) if (seq.Boss) for (const [nm] of seq.Shots) if (Shots[nm]) Shots[nm].Strict = true;

const Categories = ['BOSS TIKTOKS', 'BOSS REVEALS'];

module.exports = { Shots, Sequences, Categories };
