// THE PROLOGUE — a new player's cold open, authored as baked shots. Played by Game/Prologue.luau through
// TikTok.PlayCutscene('PROLOGUE'); the director solves every camera against the real Fern Valley map and the QC report
// flags blocked / off-frame subjects and bodies passing through each other.
//
// 2026-10-14 remake (playtest: "you walk through a weird circle... the T. rex spawns on top of a triceratops, it should
// be more climactic than him spawning out of thin air. use the first starter car. better sound design and
// cinematography"):
//   - the nest is a real nest (a twig ring round a straw bed) and you walk away from its rim, never through it
//   - the king is never on screen before his entrance: a print in the mud and a puddle shivering on each thud, the
//     jungle on the ridge goes quiet, birds burst out of it, a roar from behind the ridge, a palm goes over - then
//     his head rises over the rim (a black shape, burning eyes), he roars down at you as the light hits him, and he
//     LEAPS off the cliff into the meadow
//   - the rover is the ROOKIE RANGER, the starter every new player owns
//   - sound: the dinos' own animation events already voice their roars / bites / footsteps in 3D (SoundFx); the cues
//     here add the flat, loud layer a trailer has (thuds before anything is seen, the reveal hit on the roar, the
//     landing, the crunch), never a second roar on top of an animated one
//
// The story in ~30 s (then ~6 s waking up at camp, in Prologue.luau):
//   black, the radio -> you carry the last egg away from the nest -> a giant print, a puddle ripples on each thud ->
//   birds burst off the ridge, a roar behind it, a palm goes down -> the king rises over the rim and roars -> he leaps
//   into the meadow -> DRIVE: the rover peels out, the king charging in behind -> it snaps at the bumper -> an egg
//   goes, slow motion -> the portal ahead -> it hits you broadside, the rover flips (slow) -> it roars after you -> white
// The T. rex is never named here: its name card is saved for the real fight. Player-facing text says BOSS, never ruler.

const rover = (id, name, Move, extra = {}) => Object.assign({ Id: id, Rover: name, Move }, extra);
const dino = (id, sp, Move, extra = {}) => Object.assign({ Id: id, Dino: sp, Move }, extra);
const crew = (id, n, extra = {}) => Object.assign({ Id: id, Crew: n }, extra);
const prop = (id, Prop, Move) => ({ Id: id, Prop, Move });
const egg = (id, sp, rarity, Move, extra = {}) => Object.assign({ Id: id, Egg: sp, Rarity: rarity, Move }, extra);
const rackEgg = (id, sp, rarity, rv, slot) => ({ Id: id, Egg: sp, Rarity: rarity, Move: { Pin: { Of: rv, Slot: slot } } });
const of = (Of, At) => ({ Of, At });
const part = (Of, Part, Off) => ({ Of, Part, Off });
const score = (Stop, Wow, Motion, Read, Novel, Phone) => ({ Stop, Wow, Motion, Read, Novel, Phone });

// the starter rover: the one every new player owns (Config.Vehicles.RookieRanger)
const ROVER = 'RookieRanger';
// the nest stop: a straight stretch of road through Horn Meadow. Frame: x = right of the road (the meadow, then the
// ridge: a 23-stud cliff at x ~108, the plateau behind it), z = back along the road. The ambient Triceratops herd grazes
// at (76, -5): TikTok hides it for the take, and nothing here is staged near it.
const NEST = { Road: [1130] };
const MUD = '#4f3a26';
const RACK = (rv) => [rackEgg('e1', 'Triceratops', 'Rare', rv, 1), rackEgg('e2', 'Parasaurolophus', 'Epic', rv, 2)];
const PARKED = { Road: { S: -22, Speed: 0, X: 7 } };

// the nest: a mud mound, a straw bed and a ring of twigs (like the map's own nests), two eggs still in it
const NC = [30, 33];
const NEST_SET = (() => {
  const out = [
    prop('mound', { Shape: 'Cylinder', Size: [10.4, 0.5, 10.4], Color: MUD, Material: 'Ground', Lift: -0.2 }, { Spot: NC }),
    prop('bed', { Shape: 'Cylinder', Size: [7.2, 0.4, 7.2], Color: '#c8a654', Material: 'Fabric', Lift: 0.1 }, { Spot: NC }),
  ];
  for (let k = 0; k < 12; k++) {
    const a = (k / 12) * Math.PI * 2;
    const at = [NC[0] + Math.cos(a) * 4.3, NC[1] + Math.sin(a) * 4.3];
    out.push(prop('twig' + k, { Shape: 'Block', Size: [3.0, 0.7, 0.8], Color: k % 3 ? '#7a5a36' : '#8f6c42', Material: 'Wood', Lift: 0.15 + (k % 2) * 0.35 }, { Spot: at, Face: [NC[0] + Math.cos(a) * 9, NC[1] + Math.sin(a) * 9] }));
  }
  out.push(egg('n1', 'TyrannosaurusRex', 'Legendary', { Spot: [NC[0] - 1.2, NC[1] - 0.7], Lift: 0.5 }, { Scale: 0.85 }));
  out.push(egg('n2', 'TyrannosaurusRex', 'Legendary', { Spot: [NC[0] + 1.1, NC[1] + 1.0], Lift: 0.5 }, { Scale: 0.85 }));
  return out;
})();

// the print, between the nest and the ridge, its toes pointing at the cliff; a puddle of rain sits in the heel
// (sitting a hair ABOVE the meadow, not sunk into it: sunk, the grass poked up through it - 2026-10-14)
const PR = [40, 21];
const PRINT_SET = [
  prop('heel', { Shape: 'Block', Size: [4.2, 0.3, 3.8], Color: MUD, Material: 'Mud', Lift: 0.08 }, { Spot: PR, Face: [PR[0] + 30, PR[1]] }),
  prop('toeL', { Shape: 'Block', Size: [1.6, 0.3, 5.8], Color: MUD, Material: 'Mud', Lift: 0.08 }, { Spot: [PR[0] + 3.7, PR[1] - 2.4], Face: [PR[0] + 25, PR[1] - 14] }),
  prop('toeM', { Shape: 'Block', Size: [1.6, 0.3, 5.8], Color: MUD, Material: 'Mud', Lift: 0.08 }, { Spot: [PR[0] + 4.4, PR[1]], Face: [PR[0] + 25, PR[1]] }),
  prop('toeR', { Shape: 'Block', Size: [1.6, 0.3, 5.8], Color: MUD, Material: 'Mud', Lift: 0.08 }, { Spot: [PR[0] + 3.7, PR[1] + 2.4], Face: [PR[0] + 25, PR[1] + 14] }),
  prop('puddle', { Shape: 'Cylinder', Size: [2.7, 0.05, 2.7], Color: '#3d5f6b', Material: 'Glass', Transparency: 0.18, Reflectance: 0.45, Lift: 0.26 }, { Spot: [PR[0] + 0.1, PR[1]] }),
];

// the rim: where the king stands over the meadow (the plateau is 23 studs up; its edge runs along x ~108)
const RIM = [114, 7];
const RIM_Y = 22.4; // (Air is measured from the road's ground)
const LAND = [90, 24];

const Shots = {
  // 1. black, the radio; then low behind the nest: you carry the last egg away from it to the rover
  PRO_Nest: {
    Zone: 'FernValley', At: NEST, Beats: 7, Subject: ['p1', 'rv'], Grade: 'Dark',
    Note: 'On black (the radio), then low behind the nest, its last two eggs in the foreground: you walk the egg you took to the starter rover.',
    Actors: [
      ...NEST_SET,
      rover('rv', ROVER, PARKED),
      ...RACK('rv'),
      crew('p1', 1, { Move: { Path: [[24.2, 31.8], [15.8, 30.4]], Beats: 5.4, Start: 1.2, Ease: 'out' }, Carry: 0 }),
      egg('held', 'TyrannosaurusRex', 'Legendary', { Spot: [24.2, 31.8] }, { HeldBy: 'p1', HeldFrom: 0, Scale: 0.8 }),
    ],
    Cam: { Keys: [
      { B: 0, P: [24, 2.2, 45], L: [22, 2.4, 31], F: 42 },
      { B: 2, P: [24, 2.2, 45], L: of('p1', [1.5, 2.4, 0]), F: 42 },
      { B: 7, P: [22.4, 2.5, 44], L: of('p1', [-1, 2.6, 0]), F: 36, E: 'inout' },
    ], Hand: 0.35, Smooth: 0.5 },
    Cues: [[0, 'Black'], [2.0, 'Unblack'], [2.0, 'Grade', 'Dark', 0]],
    Score: score(7, 6, 5, 9, 7, 8),
  },
  // 2. the print: three toes pressed into the mud, pointing at the ridge; the puddle in the heel shivers on each thud
  PRO_Print: {
    Zone: 'FernValley', At: NEST, Beats: 5, Subject: ['puddle'], Grade: 'Dark',
    Note: 'Low over a giant three-toed print: a thud and the puddle in it ripples; a bigger one, leaves fall; pull back and up to the ridge it points at.',
    Actors: PRINT_SET,
    Cam: { Keys: [
      { B: 0, P: [36.6, 1.8, 24.4], L: [40.4, 0.4, 21], F: 40 },
      { B: 2.6, P: [36.2, 2.0, 24.8], L: [40.6, 0.5, 21], F: 40, E: 'inout' },
      { B: 5, P: [30.5, 3.6, 25.5], L: [76, 2, 15], F: 46, E: 'inout' },
    ], Hand: 0.35, Smooth: 0.4 },
    Cues: [
      [1.0, 'Sfx', 'StompBig', 0.7, 0.5], [1.0, 'Shake', 0.4], [1.02, 'Ripple', [40.2, 0.4, 21], 0.55],
      [3.0, 'Sfx', 'StompBig', 1.0, 0.44], [3.0, 'Sfx', 'Earthshaker', 0.3, 0.6], [3.0, 'Shake', 0.85], [3.02, 'Ripple', [40.2, 0.4, 21], 0.85],
      [3.1, 'Leaves', [40, 12, 20], 12, 18],
    ],
    Score: score(8, 6, 4, 9, 8, 8),
  },
  // 3. over your shoulder at the rover: the ridge goes quiet, birds burst out of it, a roar behind it, a palm goes down
  PRO_Ridge: {
    Zone: 'FernValley', At: NEST, Beats: 6, Subject: ['ridge'], Grade: 'Dark',
    Note: 'Over your shoulder, pushing in on the ridge: a thud, a flock bursts out of the trees, you flinch; a roar from behind the ridge; a palm on top goes over.',
    Actors: [
      ...NEST_SET,
      ...PRINT_SET,
      // (an invisible marker on the rim: the QC keeps the ridge itself in frame and unblocked)
      prop('ridge', { Shape: 'Block', Size: [1, 1, 1], Transparency: 1 }, { Spot: [117, 19], Lift: 7 }),
      rover('rv', ROVER, PARKED),
      ...RACK('rv'),
      crew('p1', 1, { Move: { Spot: [15.8, 30.4], Face: [112, 6] }, Carry: 0, Acts: [[1.5, 'Startle']] }),
      egg('held', 'TyrannosaurusRex', 'Legendary', { Spot: [15.8, 30.4] }, { HeldBy: 'p1', HeldFrom: 0, Scale: 0.8 }),
    ],
    Cam: { Keys: [
      { B: 0, P: [11.4, 5.6, 33.5], L: [114, 24, 10], F: 46 },
      { B: 6, P: [12.2, 5.8, 33.0], L: [114, 26, 10], F: 36, E: 'inout' },
    ], Hand: 0.45, Smooth: 0.4 },
    Cues: [
      [0.3, 'Sfx', 'StompBig', 0.85, 0.47], [0.3, 'Shake', 0.5], [0.35, 'Leaves', [126, 32, -10], 12, 16],
      [1.0, 'Birds', [126, 32, -18], 16, [40, 60, 50]], [1.08, 'Birds', [138, 46, 6], 10, [50, 66, 70]], [1.0, 'Sfx', 'Screech2', 0.6, 1.15],
      [2.3, 'Sfx', 'RoarBoss', 0.75, 0.78], [2.3, 'Shake', 0.9], [2.4, 'Leaves', [132, 36, 2], 16, 30],
      [3.7, 'TreeFall', [139.8, 28, 6.6], [100, 28, 6.6], 1.5], [3.7, 'Sfx', 'StompBig', 1.0, 0.45], [3.7, 'Shake', 0.8],
      [5.0, 'Sfx', 'StompBig', 1.1, 0.42], [5.0, 'Shake', 1.0], [5.05, 'Leaves', [124, 32, 8], 14, 24],
    ],
    Score: score(8, 7, 6, 9, 8, 8),
  },
  // 4. THE KING: low under the cliff, looking up. His head rises over the rim - a black shape, burning eyes - he
  //    walks to the edge and roars down at you as the light hits him; the lens pushes in on the roar
  PRO_King: {
    Zone: 'FernValley', At: NEST, Beats: 8, Subject: ['rex'], Grade: 'Dark',
    Note: 'Low under the cliff, looking up: a black shape with burning eyes rises over the rim, steps to the edge and roars down at the lens; the light hits him on the roar.',
    Actors: [
      dino('rex', 'TyrannosaurusRex', { Path: [[130, -2], RIM], Beats: 3.6, Ease: 'out', Air: RIM_Y }, { Scale: 1.3, Hidden: [0.4], Loco: 'Walk', LocoKeys: [[3.4, 'Idle']], Silhouette: [0, 5.75], Acts: [[3.8, 'Roar', 1.0]] }),
    ],
    Cam: { Keys: [
      { B: 0, P: [80, 2.2, 26], L: [112, 30, 8], F: 50 },
      { B: 3.8, P: [81.5, 2.4, 25], L: part('rex', 'Head', [0, -1, 0]), F: 44, E: 'inout' },
      { B: 5.75, P: [83.5, 2.6, 23.6], L: part('rex', 'Head', [0, -2, 0]), F: 36, E: 'in' },
      { B: 8, P: [85, 2.8, 22.4], L: part('rex', 'Head', [0, -2.5, 0]), F: 30, E: 'out' },
    ], Hand: 0.4, Smooth: 0.45 },
    Cues: [
      [1.2, 'Sfx', 'StompBig', 0.9, 0.46], [1.2, 'Shake', 0.45], [2.4, 'Sfx', 'StompBig', 1.0, 0.44], [2.4, 'Shake', 0.6],
      [3.0, 'Sfx', 'Growl', 0.8, 0.6],
      [5.75, 'Flash', 0.55], [5.75, 'Grade', 'Hero', 0.25], [5.75, 'Sting', 'Reveal', 0.9], [5.75, 'Sfx', 'RoarBoss', 1.0, 0.95],
      [5.75, 'Shake', 1.6], [5.75, 'Punch', 6], [5.8, 'RoarWave', 'rex', 1.8], [5.9, 'Leaves', [112, 30, 8], 18, 36],
    ],
    Score: score(10, 10, 7, 9, 10, 10),
  },
  // 5. it LEAPS: wide from the meadow, slow motion at the top, and it slams down into the grass
  PRO_Leap: {
    Zone: 'FernValley', At: NEST, Beats: 5, Subject: ['rex'], Grade: 'Hero',
    Note: 'Wide and low from the meadow: the king launches off the rim (slow at the top of the jump) and slams down into the grass; dust, a shock ring; its head comes up toward you.',
    Actors: [
      dino('rex', 'TyrannosaurusRex', { Path: [RIM, LAND], Start: 0.5, Beats: 2.0, Ease: 'linear', Air: [[0, RIM_Y], [0.5, RIM_Y], [1.4, RIM_Y + 3.5, 'out'], [2.5, 0.4, 'in']] }, { Scale: 1.3, Loco: 'Idle', Acts: [[0, 'Attack', 1.0], [3.1, 'Roar', 1.3]] }),
    ],
    Cam: { Keys: [
      { B: 0, P: [64, 2.0, 48], L: part('rex', 'Center', [0, 2, 0]), F: 52 },
      { B: 2.5, P: [64.5, 2.0, 47], L: part('rex', 'Center', [0, 2, 0]), F: 50, E: 'linear' },
      { B: 5, P: [66, 2.2, 45], L: part('rex', 'Head', [0, -2, 0]), F: 40, E: 'out' },
    ], Hand: 0.55, Smooth: 0.3 },
    Cues: [
      [0.4, 'Sfx', 'Snap', 0.8, 0.6], [0.9, 'TimeScale', 0.45], [0.9, 'Sfx', 'Boost', 0.5, 0.5], [2.1, 'TimeScale', 1],
      [2.5, 'ImpactFrame', 0.7], [2.5, 'Shake', 2.4], [2.5, 'Punch', 10], [2.5, 'Sfx', 'Earthshaker', 1.0, 0.85], [2.5, 'Sfx', 'StompBig', 1.2, 0.4],
      [2.52, 'Impact', [LAND[0], 0.6, LAND[1]], 3.2], [2.52, 'Dust', [LAND[0], 0.6, LAND[1]], 3.4], [2.6, 'Leaves', [LAND[0], 14, LAND[1]], 22, 40],
    ],
    Score: score(10, 10, 10, 9, 10, 10),
  },
  // 6. DRIVE: low behind the rover on the verge: it tears off the shoulder; the king charges in across the meadow
  PRO_PeelOut: {
    Zone: 'FernValley', At: NEST, Beats: 5, Subject: ['rv', 'rex'],
    Note: 'Low behind the starter rover: the wheels spin, dust in the lens, it tears off down the road; the king thunders in across the meadow behind it.',
    Actors: [
      ...NEST_SET,
      ...PRINT_SET,
      rover('rv', ROVER, { Road: { S: [[0, -22], [5, 14, 'in']], Speed: 0, X: [[0, 7], [2.4, 3], [5, 1.5]] } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }),
      ...RACK('rv'),
      dino('rex', 'TyrannosaurusRex', { Path: [[60, 20], [22, 10]], Start: 0, Speed: 16 }, { Scale: 1.3, Loco: 'Run' }),
    ],
    Cam: { Keys: [
      { B: 0, P: [-9, 1.6, 46], L: [15, 3.5, 14], F: 50 },
      { B: 5, P: [-8, 1.8, 43], L: [14, 3.5, -2], F: 54, E: 'in' },
    ], Hand: 0.55, Smooth: 0.3 },
    Cues: [
      [0, 'Sting', 'Escape', 0.8], [0.15, 'Sfx', 'EngineLoop', 1.6, 1.35], [0.2, 'Dust', of('rv', [0, 0, 6]), 2.4], [0.2, 'Shake', 0.4],
      [1.0, 'Dust', of('rv', [0, 0, 6]), 2.0], [1.6, 'Sfx', 'Boost', 0.8, 0.9],
    ],
    Score: score(9, 8, 9, 9, 8, 9),
  },
  // 7. it snaps at the bumper: low ahead of the rover looking back, the jaws land on the beat just behind it
  PRO_Bite: {
    Zone: 'FernValley', At: { Road: [760] }, Beats: 6, Subject: ['rex', 'rv'],
    Note: 'Racing low ahead of the rover, looking back: the king looms over it and snaps at the rear bumper.',
    Actors: [
      rover('rv', ROVER, { Road: { S: 0, Speed: 34, X: [[0, -1], [3, 1.5], [6, 0]] } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }),
      ...RACK('rv'),
      dino('rex', 'TyrannosaurusRex', { Road: { S: [[0, -28], [2.4, -22.5], [3.2, -22.5], [6, -25.5]], Speed: 34, X: [[0, -6], [2.4, -2.5], [6, -5]] } }, { Scale: 1.3, Loco: 'Run', Acts: [[2.2, 'Attack', 1.15]] }),
    ],
    Cam: { From: of('rv', [4.5, 1.6, -17]), To: of('rv', [4, 1.8, -13]), Look: of('rv', [-1.5, 6.5, 7]), Fov: [56, 50], Ease: 'out', Hand: 0.8 },
    Cues: [
      [2.7, 'Shake', 1.5], [2.7, 'Punch', 7], [2.72, 'Burst', of('rv', [-1.5, 3, 8]), 1.1], [2.7, 'ImpactFrame', 0.5], [2.7, 'Sfx', 'RoverHit', 0.6, 1.2],
      [2.8, 'Dust', of('rv', [0, 0, 6]), 2],
    ],
    Score: score(10, 9, 10, 9, 8, 9),
  },
  // 8. slow motion: an egg tumbles off the rack toward the lens and bursts on the road; the feet thunder past
  PRO_EggLoss: {
    Zone: 'FernValley', At: { Road: [820] }, Beats: 6, Subject: ['lost'],
    Note: 'Slow motion, on the road: an egg spins through the air toward a low lens and bursts; huge feet stomp by behind it.',
    Actors: [
      egg('lost', 'Parasaurolophus', 'Epic', { Path: [[1, -16], [0.5, -6]], Beats: 3.2, Ease: 'out', Air: [[0, 5], [1.2, 6.5], [3.2, 0.4, 'in']] }, { Until: 3.25 }),
      dino('rex', 'TyrannosaurusRex', { Road: { S: [[0, -44], [6, -2]], Speed: 0, X: -4 } }, { Scale: 1.3, Loco: 'Run' }),
    ],
    Cam: { Keys: [
      { B: 0, P: [3.5, 0.9, 2], L: [0.8, 3.5, -10], F: 44 },
      { B: 3.2, P: [3.2, 0.9, 1.6], L: [0.5, 1, -6], F: 40, E: 'inout' },
      { B: 6, P: [3, 1.1, 1.2], L: part('rex', 'Chest'), F: 50, E: 'inout' },
    ], Hand: 0.3, Smooth: 0.5 },
    Cues: [
      [0, 'TimeScale', 0.3], [0.2, 'Sting', 'Spotted', 0.55], [3.2, 'Crack', 'lost'], [3.2, 'Sparkle', [0.5, 0.6, -6], 'Epic'], [3.25, 'Shake', 0.6],
      [3.2, 'Sfx', 'EggCrack', 1.0, 0.7], [4.5, 'Shake', 0.9], [4.5, 'Sfx', 'StompBig', 1.1, 0.45],
    ],
    Score: score(9, 8, 7, 9, 9, 9),
  },
  // 9. the portal ahead: high behind the rover, the gate glowing at the end of the road, the king closing
  PRO_Portal: {
    Zone: 'FernValley', At: { Road: [1610] }, Beats: 6, Subject: ['rv', 'rex'],
    Note: 'A high three-quarter chase from behind: the road runs to the glowing portal; the king is right on the rover.',
    Actors: [
      rover('rv', ROVER, { Road: { S: 0, Speed: 36, X: 0 } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }),
      rackEgg('e1', 'Triceratops', 'Rare', 'rv', 1),
      dino('rex', 'TyrannosaurusRex', { Road: { S: [[0, -28], [6, -17]], Speed: 36, X: [[0, -3.4], [2, -4.4], [6, -4.6]] } }, { Scale: 1.3, Loco: 'Run' }),
    ],
    Cam: { From: of('rv', [9, 16, 30]), To: of('rv', [7, 13, 24]), Look: of('rv', [0, 1, -40]), Fov: [52, 50], Ease: 'linear', Hand: 0.6 },
    Cues: [[2.0, 'Shake', 0.4], [4.0, 'Shake', 0.6]],
    Score: score(8, 9, 9, 9, 7, 8),
  },
  // 10. THE SLAM: it hits you broadside; the rover flips end over end in slow motion; the last egg goes
  PRO_Slam: {
    Zone: 'FernValley', At: { Road: [1660] }, Beats: 8, Subject: ['rv'],
    Note: 'Low and wide from the far verge: the king rams the rover; slow motion, it cartwheels toward the portal.',
    Actors: [
      rover('rv', ROVER, { Road: { S: [[0, -30], [1.4, -10], [3, 4, 'out'], [8, 22, 'out']], Speed: 0, X: [[0, 0], [1.4, 0], [3, 2.5], [8, 4]] }, Air: [[0, 0], [1.4, 0], [3, 6, 'out'], [5.6, 3], [8, 0.4, 'in']], Pitch: [[0, 0], [1.4, 0], [8, -6.6, 'out']] }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }),
      rackEgg('e1', 'Triceratops', 'Rare', 'rv', 1),
      dino('rex', 'TyrannosaurusRex', { Road: { S: [[0, -40], [1.4, -14], [3, -12, 'out'], [8, -9]], Speed: 0, X: [[0, -10], [1.4, -9], [3, -6], [8, -3]] } }, { Scale: 1.3, Loco: 'Run', LocoKeys: [[3, 'Idle']], Acts: [[1.2, 'Attack', 1.4]] }),
    ],
    Cam: { Keys: [
      { B: 0, P: [19, 2.4, -6], L: of('rv', [0, 2, 0]), F: 50 },
      { B: 1.4, P: [19, 2.4, -6], L: of('rv', [0, 2.5, 0]), F: 46, E: 'inout' },
      { B: 8, P: [18.5, 2.8, -8], L: of('rv', [0, 1, 0]), F: 42, E: 'out' },
    ], Hand: 0.5, Smooth: 0.45 },
    Cues: [
      [1.4, 'ImpactFrame', 0.8], [1.4, 'Shake', 2.2], [1.4, 'Punch', 10], [1.42, 'Burst', of('rv', [0, 2, 0]), 1.8], [1.4, 'Sfx', 'RoverHit', 1.2, 0.8],
      [1.45, 'TimeScale', 0.3], [1.5, 'Dust', of('rv', [0, 0, 0]), 2.6], [6.2, 'TimeScale', 1], [7.6, 'Dust', of('rv', [0, 0, 0]), 2.4], [7.6, 'Shake', 1.0],
    ],
    Score: score(10, 9, 10, 9, 9, 9),
  },
  // 11. it plants itself in the road and roars after you; the screen burns to white
  PRO_Roar: {
    Zone: 'FernValley', At: { Road: [1660] }, Beats: 5, Subject: ['rex'],
    Note: 'Low in front of the king standing in the road: it roars after you, dust and leaves hanging; white.',
    Actors: [dino('rex', 'TyrannosaurusRex', { Road: { S: -9, Speed: 0, X: -1 } }, { Scale: 1.3, Acts: [[0.3, 'Roar', 1.0]] })],
    Cam: { Keys: [
      { B: 0, P: [6, 1.6, -26], L: part('rex', 'Head', [0, -1, 0]), F: 44 },
      { B: 5, P: [5, 1.8, -23], L: part('rex', 'Head', [0, -0.5, 0]), F: 38, E: 'out' },
    ], Hand: 0.4, Smooth: 0.4 },
    Cues: [[0.7, 'Shake', 1.6], [0.7, 'Leaves', [0, 14, -4], 26, 40], [3.6, 'White', 1, 0.8]],
    Score: score(9, 9, 7, 9, 8, 9),
  },
};

const Sequences = [
  {
    Id: 'PROLOGUE', Name: 'THE PROLOGUE', Category: 'STORY',
    Hook: 'they stole the king\'s eggs 🦖🥚 #roblox #dinosaur #robloxgames',
    Shots: [['PRO_Nest', 7], ['PRO_Print', 5], ['PRO_Ridge', 6], ['PRO_King', 8], ['PRO_Leap', 5], ['PRO_PeelOut', 5], ['PRO_Bite', 5], ['PRO_EggLoss', 5], ['PRO_Portal', 4], ['PRO_Slam', 8], ['PRO_Roar', 5]],
  },
];

const Categories = ['STORY'];

module.exports = { Shots, Sequences, Categories };
