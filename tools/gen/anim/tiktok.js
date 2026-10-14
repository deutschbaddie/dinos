// TikTok shot library + sequences. Baked by tools/gen/tiktok.js (run by build.js) into
// src/.../Game/TikTok/Data.luau and QC frames for tools/preview/tiktok.html.
//
// Coordinates: every shot has an anchor frame At (a flat frame on the ground): x = right, y = up, -z = forward.
//   At: { Road: [s, x?, variant?] }       a point on the era's road, forward = direction of travel
//       { Nest: id }                      a nest site, forward = toward its road
//       { Marker: name, Away|Toward: n }  a named map marker (DenCenter, GateArrival...)
//       { Point: [x,y,z], Face: [x,y,z] } world point
// Actors: { Id, Dino|Baby|Rover|Crew|Egg, Move, Loco, LocoKeys, Acts: [[beat, action, speed?]], Sig: { From } }
//   Move: { Road: { S, Speed, X } }  S/X numbers or [[beat, value], ...] keys; S relative to a Road anchor
//         { Path: [[x,z], ...], Speed? | Beats?, Start?, Ease?, Face? }   { Spot: [x,z], Face: [x,z] | Yaw }
//         { Pin: { Of, Part|Slot, Off } }   ride another actor (rodeo rider, egg on a roof rack)
// Cam: { Keys: [{ B, P, L, F, R, E }] } or { From, To, Look | LookFrom/LookTo, Fov: [a,b], Roll, Ease } or { Sig: id }
//   P/L: [x,y,z] in the anchor frame | { Of: id, At: [x,y,z] } in the actor's frame | { Of: id, Part: 'Head'|'Mouth'|'Chest'|'Center', Off }
// Cues: [beat, kind, ...args]; Shake s | Punch fov | Flash a | Burst pt scale | Dust pt scale | Impact pt scale |
//   Sparkle pt rarity | Dart from to dur | Crack egg | Stun id dur | ImpactFrame a | SunBurst a | Speed dur | Black dur |
//   Stamp text color | RayTitle text sub
// Score (1-10): Stop = stop-scroll, Wow = dinosaur wow, Motion, Read = readability, Novel = novelty, Phone = phone readability

const B4 = 4, B2 = 2, B1 = 1;
const rover = (id, name, Move, extra = {}) => Object.assign({ Id: id, Rover: name, Move }, extra);
const dino = (id, sp, Move, extra = {}) => Object.assign({ Id: id, Dino: sp, Move }, extra);
const crew = (id, n, extra = {}) => Object.assign({ Id: id, Crew: n }, extra);
const rackEgg = (id, sp, rarity, rv, slot) => ({ Id: id, Egg: sp, Rarity: rarity, Move: { Pin: { Of: rv, Slot: slot } } });
const of = (Of, At) => ({ Of, At });
const part = (Of, Part, Off) => ({ Of, Part, Off });
const score = (Stop, Wow, Motion, Read, Novel, Phone) => ({ Stop, Wow, Motion, Read, Novel, Phone });

const Shots = {
  // ============================================================== CHASES (the rover autopilots, you're the gunner)
  // Rock Canyon, Fern Valley: the Tyrant King runs the rover down and snaps at the rear bumper
  RexBumperBite: {
    Zone: 'FernValley', At: { Road: [760] }, Beats: B4, Subject: ['rex', 'rv'],
    Note: 'HOOK. Low camera racing ahead of the rover, looking back: rover big in the lower frame, the T. rex looming over it, the bite lands on the beat.',
    Actors: [
      rover('rv', 'RookieRanger', { Road: { S: 0, Speed: 30, X: [[0, -1], [2, 1.5], [4, 0]] } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2, Aim: 0.2 }),
      rackEgg('e1', 'TyrannosaurusRex', 'Legendary', 'rv', 1), rackEgg('e2', 'Triceratops', 'Epic', 'rv', 2),
      dino('rex', 'TyrannosaurusRex', { Road: { S: [[0, -24], [1.6, -15], [2.4, -14], [4, -19]], Speed: 30, X: [[0, -7], [1.6, -3], [4, -6]] } }, { Loco: 'Run', Acts: [[1.45, 'Attack', 1.15]] }),
    ],
    Cam: { From: of('rv', [4, 1.4, -17]), To: of('rv', [3.5, 1.6, -13.5]), Look: of('rv', [-1.5, 6.5, 6]), Fov: [54, 48], Ease: 'out', Hand: 0.8 },
    Cues: [[1.9, 'Shake', 1.4], [1.9, 'Punch', 7], [1.92, 'Burst', of('rv', [-2, 3, 7.5]), 1.1], [1.9, 'ImpactFrame', 0.5], [2.0, 'Dust', of('rv', [0, 0, 6]), 2]],
    Score: score(10, 9, 10, 9, 9, 9),
  },
  // the same chase from the side at wheel height: scale of rex vs rover, canyon wall streaking
  RexSideRun: {
    Zone: 'FernValley', At: { Road: [800] }, Beats: B2, Subject: ['rex'],
    Note: 'Wheel-height side tracking: the rex keeps pace at the rear wheel, legs pumping, canyon wall streaking behind.',
    Actors: [
      rover('rv', 'RookieRanger', { Road: { S: 0, Speed: 30, X: 1.5 } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2 }),
      rackEgg('e1', 'TyrannosaurusRex', 'Legendary', 'rv', 1),
      dino('rex', 'TyrannosaurusRex', { Road: { S: -13, Speed: 30, X: -5 } }, { Loco: 'Run' }),
    ],
    Cam: { From: of('rv', [-17, 2.5, 7]), To: of('rv', [-16, 2.5, 3]), Look: of('rv', [-3, 5.5, 7]), Fov: [52, 48], Ease: 'linear', Hand: 0.7 },
    Cues: [[1.0, 'Shake', 0.5]],
    Score: score(8, 9, 10, 9, 7, 8),
  },
  // Raptor Wilds: a pack sprints alongside, one cutting across right in front of the lens
  RaptorPackFlank: {
    Zone: 'FernValley', At: { Road: [600] }, Beats: B2, Subject: ['r1', 'rv'],
    Note: 'Pass-by: three raptors running with the rover, the nearest one crosses the foreground.',
    Actors: [
      rover('rv', 'RaptorRunner', { Road: { S: 0, Speed: 34, X: 2 } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2 }),
      rackEgg('e1', 'Velociraptor', 'Rare', 'rv', 1), rackEgg('e2', 'Velociraptor', 'Epic', 'rv', 2),
      dino('r1', 'Velociraptor', { Road: { S: [[0, -9], [2, 3]], Speed: 34, X: [[0, -7], [2, -4]] } }, { Loco: 'Run' }),
      dino('r2', 'Velociraptor', { Road: { S: -5, Speed: 34, X: -11 } }, { Loco: 'Run' }),
      dino('r3', 'Velociraptor', { Road: { S: -14, Speed: 34, X: 9 } }, { Loco: 'Run', Acts: [[0.8, 'RaptorScreech', 1.4]] }),
    ],
    Cam: { From: of('rv', [-20, 2, 4]), To: of('rv', [-20, 2.2, -1]), Look: of('rv', [-3, 3, 2]), Fov: [50, 46], Ease: 'linear', Hand: 0.9 },
    Cues: [[0.5, 'Shake', 0.4]],
    Score: score(9, 8, 10, 8, 8, 8),
  },
  // a raptor launches itself at the roof rack
  RaptorPounceRack: {
    Zone: 'FernValley', At: { Road: [640] }, Beats: B2, Subject: ['r1', 'rv'],
    Note: 'Chase cam behind the rover: a raptor leaps at the glowing eggs on the rack.',
    Actors: [
      rover('rv', 'RaptorRunner', { Road: { S: 0, Speed: 30, X: [[0, 0], [1.4, -2.5], [2, -1]] } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2 }),
      rackEgg('e1', 'Velociraptor', 'Legendary', 'rv', 1), rackEgg('e2', 'Velociraptor', 'Rare', 'rv', 2), rackEgg('e3', 'Velociraptor', 'Epic', 'rv', 3),
      dino('r1', 'Velociraptor', { Road: { S: [[0, -16], [1.1, -13.8], [2, -14.5]], Speed: 30, X: [[0, 4], [1, 2], [2, 3]] } }, { Loco: 'Run', Acts: [[0.55, 'Pounce', 1.2]], Glow: [[0, 0.9]] }),
      dino('r2', 'Velociraptor', { Road: { S: -16, Speed: 30, X: -6 } }, { Loco: 'Run' }),
    ],
    Cam: { From: of('rv', [2, 8.5, 27]), To: of('rv', [1.5, 8, 22]), Look: of('rv', [0, 3, 3]), Fov: [48, 46], Ease: 'out', Hand: 0.9 },
    Cues: [[1.15, 'Shake', 0.9], [1.15, 'Punch', 5], [1.2, 'Burst', of('rv', [1.5, 5, 4]), 0.8]],
    Score: score(9, 8, 10, 8, 8, 8),
  },
  // the gunner's view: a raptor flashes red, a dart hits it on the telegraph, it tumbles
  DartPerfect: {
    Zone: 'FernValley', At: { Road: [690] }, Beats: B2, Subject: ['r1'],
    Note: 'Over the gunner: chaser flashes red, a dart lands on the beat, the raptor stumbles out of frame.',
    Actors: [
      rover('rv', 'RaptorRunner', { Road: { S: 0, Speed: 30, X: 0 } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2, Aim: -0.15 }),
      rackEgg('e1', 'Velociraptor', 'Epic', 'rv', 1),
      dino('r1', 'Velociraptor', { Road: { S: [[0, -14.5], [1, -13.6], [2, -21]], Speed: 30, X: [[0, 2.5], [2, 5]] } }, { Loco: 'Run', Acts: [[1.05, 'Stumble', 1.2]], Glow: [[0, 1]] }),
    ],
    Cam: { From: of('rv', [2.6, 8.6, 2.5]), To: of('rv', [2.4, 8.4, 2]), Look: of('rv', [2.5, 2, 14]), Fov: [44, 40], Ease: 'out', Hand: 1.1 },
    Cues: [[0.75, 'Dart', of('rv', [1.5, 5.5, 1.5]), part('r1', 'Chest'), 0.25], [1.0, 'Burst', part('r1', 'Chest'), 0.7], [1.0, 'Punch', 4], [1.0, 'Shake', 0.6]],
    Score: score(8, 7, 9, 8, 8, 8),
  },
  // Horn Meadow: a triceratops charges across the road right in front of the hood
  TriCrossHood: {
    Zone: 'FernValley', At: { Road: [1000] }, Beats: B2, Subject: ['tri'],
    Note: 'Hood cam: the rover slams on the brakes as a triceratops charges across the road a few studs ahead.',
    Actors: [
      rover('rv', 'RookieRanger', { Road: { S: 0, Speed: 30, X: [[0, 0], [1, -1.5], [2, -2]], Brake: [0.45, 9] }, Pitch: [[0, 0], [0.55, -0.07], [1.3, -0.03], [2, 0]] }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2 }),
      dino('tri', 'Triceratops', { Path: [[25, -36], [-30, -31]], Speed: 28 }, { Loco: 'Run' }),
    ],
    Cam: { From: of('rv', [-1.2, 6.2, -1]), To: of('rv', [-1.2, 6.0, -1.5]), Look: of('rv', [1, 3, -40]), Fov: [68, 64], Ease: 'linear', Hand: 1.2 },
    Cues: [[0.5, 'Dust', of('rv', [0, 0, -6]), 2.2], [0.5, 'Shake', 0.6], [0.9, 'Shake', 0.8], [1.0, 'Dust', [0, 0, -34], 3]],
    Score: score(9, 8, 10, 8, 9, 8),
  },
  // Salt Flats, golden hour: the Plains Titan chasing the Titan Transport, low and wide
  GigaFlatsChase: {
    Zone: 'GiantPlains', At: { Road: [380] }, Beats: B4, Subject: ['giga', 'rv'],
    Note: 'Locked low camera at the roadside: the truck screams past, then the Giganotosaurus fills the frame.',
    Actors: [
      rover('rv', 'TitanTransport', { Road: { S: 14, Speed: 30, X: 2 } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2 }),
      rackEgg('e1', 'Brachiosaurus', 'Legendary', 'rv', 1), rackEgg('e2', 'Stegosaurus', 'Epic', 'rv', 2), rackEgg('e3', 'Ankylosaurus', 'Rare', 'rv', 3),
      dino('giga', 'Giganotosaurus', { Road: { S: -27, Speed: 30, X: [[0, -2], [4, -4]] } }, { Loco: 'Run', Acts: [[2.6, 'Attack', 1.1]] }),
    ],
    Cam: { Keys: [
      { B: 0, P: [-10, 1.2, -60], L: of('rv', [0, 3, 0]), F: 40 },
      { B: 2.2, P: [-10, 1.2, -60], L: part('giga', 'Head'), F: 46, E: 'inout' },
      { B: 4, P: [-10, 1.0, -60], L: part('giga', 'Head', [0, -2, 0]), F: 56, E: 'out' },
    ], Hand: 0.6, Smooth: 0.5 },
    Cues: [[3.1, 'Shake', 1.2], [3.1, 'Punch', 6], [3.2, 'Dust', [-4, 0, -58], 3]],
    Score: score(9, 10, 9, 8, 9, 8),
  },
  // Great Herds: a Brachiosaurus steps across the road and the rover slams on the brakes in front of it
  BrachioCrossing: {
    Zone: 'GiantPlains', At: { Road: [1110] }, Beats: B4, Subject: ['br', 'rv'],
    Note: 'Ground camera on the road: a Brachiosaurus walks across in front of the lens, the rover skids to a stop just short of its legs.',
    Actors: [
      rover('rv', 'RookieRanger', { Road: { S: -40, Speed: 26, X: 0, Brake: [1.6, 16] }, Pitch: [[0, 0], [1.7, -0.08], [3, -0.02], [4, 0]] }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2 }),
      dino('br', 'Brachiosaurus', { Path: [[-9, -12], [-2, -12]], Beats: 4, Face: [40, -12] }, { Loco: 'Walk' }),
    ],
    Cam: { From: [2.5, 0.8, -38], To: [2.2, 0.8, -36], Look: [0, 10, -12], Fov: [62, 60], Ease: 'linear', Hand: 0.5 },
    Cues: [[1.7, 'Dust', of('rv', [0, 0, -5]), 2.5], [1.7, 'Shake', 0.5], [2.6, 'Shake', 0.5]],
    Score: score(9, 10, 8, 9, 9, 9),
  },
  // Crest Lagoon: a parasaurolophus herd stampedes past the lens
  ParaStampede: {
    Zone: 'FernValley', At: { Road: [480] }, Beats: B2, Subject: ['a'],
    Note: 'Low camera in the herd\'s path; four bodies thunder past, the nearest within a few studs.',
    Actors: [
      dino('a', 'Parasaurolophus', { Path: [[-12, -6], [22, 22]], Speed: 26 }, { Loco: 'Run' }),
      dino('b', 'Parasaurolophus', { Path: [[-24, -6], [10, 22]], Speed: 26 }, { Loco: 'Run' }),
      dino('c', 'Parasaurolophus', { Path: [[-16, -18], [18, 10]], Speed: 26 }, { Loco: 'Run' }),
      dino('d', 'Parasaurolophus', { Path: [[-30, -14], [4, 14]], Speed: 26 }, { Loco: 'Run', Acts: [[0.6, 'HerdResponse']] }),
    ],
    Cam: { From: [11, 1.6, 19], To: [11, 1.8, 18], Look: [-4, 4, 2], Fov: [54, 52], Ease: 'linear', Hand: 1.0 },
    Cues: [[0.8, 'Shake', 0.6]],
    Score: score(8, 8, 10, 8, 8, 8),
  },

  // ============================================================== RULERS
  // the King's Lair: the T. rex's signature, foot-stomp at ground level
  RexStomp: {
    Zone: 'FernValley', At: { Marker: 'DenCenter', Away: 'Throne' }, Beats: B2, Subject: ['rex'], Focus: 'Center',
    Note: 'Signature camera, ground level: the Tyrant King\'s foot slams down beside the lens.',
    Actors: [dino('rex', 'TyrannosaurusRex', { Spot: [0, 0] }, { Sig: { From: 1.5 }, Scale: 1.15 })],
    Cam: { Sig: 'rex' },
    Score: score(9, 9, 8, 9, 9, 9),
  },
  // the slow-motion King's Roar
  RexKingsRoar: {
    Zone: 'FernValley', At: { Marker: 'DenCenter', Away: 'Throne' }, Beats: B4, Subject: ['rex'],
    Note: 'Signature camera: inhale, then the slow-motion roar straight down the lens.',
    Actors: [dino('rex', 'TyrannosaurusRex', { Spot: [0, 0] }, { Sig: { From: 4.3 }, Scale: 1.15 })],
    Cam: { Sig: 'rex' },
    Cues: [[1.2, 'SunBurst', 0.6]],
    Score: score(10, 10, 8, 9, 8, 9),
  },
  // low angle under the ruler as it roars (paired with the baby roar for the contrast cut)
  RexRoarLow: {
    Zone: 'FernValley', At: { Marker: 'DenCenter', Away: 'Throne' }, Beats: B2, Subject: ['rex'],
    Note: 'Low angle at its feet: the parent roars. Cut on the beat to the baby doing the same.',
    Actors: [dino('rex', 'TyrannosaurusRex', { Spot: [0, 0] }, { Acts: [[0, 'Roar', 1.2]], Scale: 1.15 })],
    Cam: { From: [-6, 1.2, -20], To: [-5.6, 1.1, -19], Look: part('rex', 'Head', [0, -1.5, 0]), Fov: [50, 48], Ease: 'linear', Hand: 0.6 },
    Cues: [[1.1, 'Shake', 1.1]],
    Score: score(8, 10, 7, 9, 7, 9),
  },
  // the rodeo finisher on the Tyrant King
  RexRodeo: {
    Zone: 'FernValley', At: { Marker: 'FinalArena' }, Beats: B2, Subject: ['rex', 'p1'],
    Note: 'Orbit: a player rides the bucking T. rex in the final stand.',
    Actors: [
      dino('rex', 'TyrannosaurusRex', { Spot: [0, 0], YawOff: [[0, -10], [1, 12], [2, -8]] }, { Acts: [[0, 'Stunned', 1.3]], Scale: 1.15 }),
      crew('p1', 1, { Move: { Pin: { Of: 'rex', Part: 'Center', Off: [0, 2.4, 1.5] } }, Loop: 'Rodeo' }),
    ],
    Cam: { From: of('rex', [-16, 4, -10]), To: of('rex', [-12, 5, -15]), Look: part('rex', 'Chest', [0, 2, 0]), Fov: [50, 46], Ease: 'inout', Hand: 1.1 },
    Cues: [[0.5, 'Shake', 0.6], [1.5, 'Shake', 0.6]],
    Score: score(9, 9, 9, 8, 10, 8),
  },
  // knocked out: DEFEATED (the game's own title)
  RexDefeated: {
    Zone: 'FernValley', At: { Marker: 'FinalArena' }, Beats: B4, Subject: ['rex'],
    Note: 'The boss goes down, stars spin, the game\'s DEFEATED title slams over sun rays.',
    Actors: [
      dino('rex', 'TyrannosaurusRex', { Spot: [0, 0] }, { Acts: [[0, 'Stunned']], Scale: 1.15 }),
      crew('p1', 1, { Move: { Spot: [-8, -16], Face: [0, 0] }, Acts: [[1.5, 'Victory']] }),
      crew('p2', 2, { Move: { Spot: [7, -18], Face: [0, 0] }, Acts: [[1.7, 'Victory']] }),
    ],
    Cam: { From: [-2, 3, -30], To: [-1, 2.2, -24], Look: part('rex', 'Head', [0, -1, 0]), Fov: [48, 44], Ease: 'out', Hand: 0.5 },
    Cues: [[0.3, 'Stun', 'rex', 4], [0.5, 'RayTitle', 'DEFEATED!', 'TYRANT KING'], [0.5, 'Shake', 0.8]],
    Score: score(8, 8, 7, 9, 8, 9),
  },
  // the Plains Titan breaks into the Bone Yard
  GigaBreakthrough: {
    Zone: 'GiantPlains', At: { Marker: 'DenCenter', Away: 'Throne' }, Beats: B4, Subject: ['giga'],
    Note: 'Signature camera: the Giganotosaurus bursts in, then lowers its head to the lens.',
    Actors: [dino('giga', 'Giganotosaurus', { Spot: [0, 0] }, { Sig: { From: 1.4 }, Scale: 1.05 })],
    Cam: { Sig: 'giga' },
    Score: score(10, 10, 9, 9, 9, 9),
  },
  GigaRoar: {
    Zone: 'GiantPlains', At: { Marker: 'DenCenter', Away: 'Throne' }, Beats: B4, Subject: ['giga'],
    Note: 'Signature camera: the Plains Titan\'s roar.',
    Actors: [dino('giga', 'Giganotosaurus', { Spot: [0, 0] }, { Sig: { From: 4.55 }, Scale: 1.05 })],
    Cam: { Sig: 'giga' },
    Cues: [[1, 'SunBurst', 0.5]],
    Score: score(9, 10, 8, 9, 7, 9),
  },
  // final payoff: the Titan lunges straight into the lens, mouth fills the frame, black
  GigaLensBite: {
    Zone: 'GiantPlains', At: { Marker: 'DenCenter', Away: 'Throne' }, Beats: B2, Subject: ['giga'],
    Note: 'Ending: locked close-up, the Titan bites at the camera; mouth fills the frame on the downbeat, cut to black.',
    Actors: [dino('giga', 'Giganotosaurus', { Spot: [0, 0] }, { Acts: [[0.1, 'Attack', 1.0]], Scale: 1.05 })],
    Cam: { From: [0.8, 9, -20], To: [0.5, 8.5, -15], Look: part('giga', 'Head', [0, -0.5, 0]), Fov: [50, 62], Ease: 'in', Hand: 0.8, Smooth: 0.15 },
    Cues: [[1.25, 'Shake', 1.6], [1.25, 'Punch', 10], [1.3, 'Flash', 0.6], [1.45, 'Black', 0.6]],
    Score: score(10, 10, 9, 8, 9, 9),
  },

  // ============================================================== SIGNATURES (every dino has one)
  TriCharge: {
    Zone: 'FernValley', At: { Nest: 2 }, Beats: B4, Subject: ['tri'],
    Note: 'Signature camera: the glare, then the charge in slow motion.',
    Actors: [dino('tri', 'Triceratops', { Spot: [0, -6] }, { Sig: { From: 1.3 } })],
    Cam: { Sig: 'tri' },
    Score: score(8, 8, 9, 9, 7, 8),
  },
  RaptorLeap: {
    Zone: 'FernValley', At: { Nest: 1 }, Beats: B4, Subject: ['r'],
    Note: 'Signature camera: the raptor\'s leap and screech.',
    Actors: [dino('r', 'Velociraptor', { Spot: [0, -6] }, { Sig: { From: 0.7 }, Scale: 1 })],
    Cam: { Sig: 'r' },
    Score: score(8, 8, 9, 8, 7, 8),
  },
  BrachioFootfall: {
    Zone: 'GiantPlains', At: { Nest: 3 }, Beats: B4, Subject: ['br'],
    Note: 'Signature camera: a foot the size of the rover lands beside the lens, tilt up the neck.',
    Actors: [dino('br', 'Brachiosaurus', { Spot: [0, -32] }, { Sig: { From: 0.9 } })],
    Cam: { Sig: 'br' },
    Score: score(9, 10, 7, 9, 8, 9),
  },
  CarnoAmbush: {
    Zone: 'FernValley', At: { Road: [260, -16] }, Beats: B2, Subject: ['c'],
    Note: 'Signature camera: the Carnotaurus explodes out of cover (a later era: the "what is THAT" beat).',
    Actors: [dino('c', 'Carnotaurus', { Spot: [0, 0], Yaw: 90 }, { Sig: { From: 2.45 }, Scale: 1.1 })],
    Cam: { Sig: 'c' },
    Score: score(9, 9, 9, 8, 10, 8),
  },
  StegoTail: {
    Zone: 'GiantPlains', At: { Nest: 1 }, Beats: B2, Subject: ['s'],
    Note: 'Low behind the plates as the tail spikes sweep past the lens.',
    Actors: [dino('s', 'Stegosaurus', { Spot: [0, -8], Yaw: 90 }, { Acts: [[0.2, 'Attack', 1.1]] })],
    Cam: { From: of('s', [7, 1.2, 14]), To: of('s', [6, 1.4, 12]), Look: of('s', [0, 4, 2]), Fov: [56, 52], Ease: 'linear', Hand: 0.8 },
    Cues: [[1.2, 'Shake', 0.6]],
    Score: score(7, 8, 8, 8, 7, 8),
  },
  AnkyClub: {
    Zone: 'GiantPlains', At: { Road: [1000, -30] }, Beats: B2, Subject: ['a'],
    Note: 'The club smashes the ground next to the camera.',
    Actors: [dino('a', 'Ankylosaurus', { Spot: [0, 0], Yaw: -90 }, { Acts: [[0, 'ClubSmash', 1.3]] })],
    Cam: { From: of('a', [10, 2.6, -4]), To: of('a', [9, 2.4, -2]), Look: of('a', [0, 2, 3]), Fov: [52, 48], Ease: 'linear', Hand: 0.8 },
    Cues: [[1.3, 'Shake', 1.0], [1.3, 'Impact', of('a', [0, 0, 8]), 1.5]],
    Score: score(8, 8, 8, 8, 8, 8),
  },
  RaptorScreechCU: {
    Zone: 'FernValley', At: { Nest: 1 }, Beats: B1, Subject: ['r'],
    Note: 'One-beat insert: a raptor screeches into the lens.',
    Actors: [dino('r', 'Velociraptor', { Spot: [0, -4] }, { Acts: [[0, 'RaptorScreech', 1.6]] })],
    Cam: { From: of('r', [-2, 2.6, -9]), To: of('r', [-1.8, 2.5, -7.5]), Look: part('r', 'Head'), Fov: [40, 44], Ease: 'out', Hand: 1.2, Smooth: 0.1 },
    Cues: [[0.3, 'Shake', 0.6]],
    Score: score(8, 7, 8, 9, 6, 9),
  },

  // ============================================================== EGGS
  // grab the egg; the pack wakes up behind you
  EggGrabWake: {
    Zone: 'FernValley', At: { Nest: 1 }, Beats: B4, Subject: ['p1', 'r1'],
    Note: 'Over the shoulder: a player scoops a glowing egg; behind the nest a raptor wakes and screeches.',
    Actors: [
      crew('p1', 1, { Move: { Path: [[-4, 8], [-1.2, 1.6]], Beats: 1.4, Ease: 'out', Face: [0, 0] }, Acts: [[1.4, 'Grab']] }),
      { Id: 'egg', Egg: 'Velociraptor', Rarity: 'Legendary', Move: { Spot: [0, 0] } },
      dino('r1', 'Velociraptor', { Spot: [3, -9], Face: [-1, 2] }, { Acts: [[0, 'Sleep'], [1.9, 'Wake', 1.3], [2.6, 'RaptorScreech', 1.3]] }),
      dino('r2', 'Velociraptor', { Spot: [-7, -12], Face: [0, 4] }, { Acts: [[0, 'Sleep'], [2.2, 'Wake', 1.3]] }),
    ],
    Cam: { Keys: [
      { B: 0, P: [10, 6, 13], L: [-1, 1, -3], F: 50 },
      { B: 2.0, P: [8, 5.2, 10], L: [-0.5, 1.2, -4], F: 46, E: 'inout' },
      { B: 2.6, P: [7.5, 5, 9], L: part('r1', 'Head'), F: 36, E: 'snap' },
      { B: 4, P: [7, 4.8, 8], L: part('r1', 'Head'), F: 30, E: 'linear' },
    ], Hand: 0.7 },
    Cues: [[1.5, 'Sparkle', [0, 1.5, 0], 'Legendary'], [2.65, 'Punch', 5], [2.65, 'Shake', 0.6]],
    Score: score(9, 8, 8, 9, 9, 8),
  },
  // the haul glowing on the roof rack as the rover tears away
  RackHaul: {
    Zone: 'FernValley', At: { Road: [1520] }, Beats: B2, Subject: ['rv'],
    Note: 'Orbit over the roof rack: SECRET, LEGENDARY and EPIC eggs glowing their rarity colours.',
    Actors: [
      rover('rv', 'RaptorRunner', { Road: { S: 0, Speed: 26, X: 0 } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2 }),
      rackEgg('e1', 'TyrannosaurusRex', 'Secret', 'rv', 1), rackEgg('e2', 'Velociraptor', 'Legendary', 'rv', 2), rackEgg('e3', 'Triceratops', 'Epic', 'rv', 3),
    ],
    Cam: { From: of('rv', [6, 10, 8]), To: of('rv', [-5, 10.5, 7]), Look: of('rv', [0, 4.5, 3]), Fov: [40, 38], Ease: 'inout', Hand: 0.5 },
    Score: score(8, 6, 8, 9, 8, 9),
  },
  // home: a SECRET egg hatches into a baby T. rex
  HatchSecret: {
    Zone: 'BaseCamp', At: { Point: [564, 0, 9], Face: [1, 0, -0.25] }, Beats: B4, Subject: ['egg'],
    Note: 'The egg rocks, cracks in a rainbow burst, a baby T. rex pops out and tries its first roar.',
    Actors: [
      { Id: 'egg', Egg: 'TyrannosaurusRex', Rarity: 'Secret', Scale: 1.6, Move: { Spot: [0, 0], YawOff: [[0, 0], [0.5, 14], [1, -14], [1.5, 16], [2, -18], [2.4, 0]] }, Until: 2.4 },
      { Id: 'baby', Baby: 'TyrannosaurusRex', Rarity: 'Secret', Move: { Spot: [0, 0], Face: [-10, -3] }, Hidden: [2.4], Acts: [[2.9, 'Roar', 1.2]] },
    ],
    Cam: { Keys: [
      { B: 0, P: [-7, 3.4, -6], L: [0, 2.2, 0], F: 36 },
      { B: 2.35, P: [-5.2, 3, -4.4], L: [0, 2.2, 0], F: 32, E: 'inout' },
      { B: 2.45, P: [-8.5, 4.6, -8.5], L: [0, 3.2, 0], F: 46, E: 'snap' },
      { B: 4, P: [-8, 4.4, -8], L: [0, 3.2, 0], F: 44, E: 'linear' },
    ], Hand: 0.4 },
    Cues: [[2.4, 'Crack', 'egg'], [2.4, 'Flash', 0.7], [2.4, 'Sparkle', [0, 2, 0], 'Secret'], [2.4, 'Shake', 0.6], [3.0, 'Stamp', 'SECRET!', 'Red']],
    Score: score(9, 8, 8, 9, 9, 9),
  },
  // the contrast cut: the same low angle, the baby's tiny roar
  BabyRexRoar: {
    Zone: 'BaseCamp', At: { Point: [564, 0, 9], Face: [1, 0, -0.25] }, Beats: B2, Subject: ['baby'],
    Note: 'Match cut to RexRoarLow: same angle, same roar, a baby with a rainbow aura.',
    Actors: [{ Id: 'baby', Baby: 'TyrannosaurusRex', Rarity: 'Secret', Move: { Spot: [0, 0], Face: [-10, -3] }, Acts: [[0, 'Roar', 1.2]] }],
    Cam: { From: [-6.4, 1, -6], To: [-6.1, 0.95, -5.7], Look: part('baby', 'Head', [0, -0.6, 0]), Fov: [50, 48], Ease: 'linear', Hand: 0.6 },
    Score: score(9, 8, 7, 9, 9, 9),
  },

  // ============================================================== GAMEPLAY CLIPS (player cameras + the real HUD)
  // the escape run from the driver's seat: run HUD, the game's own banner, raptors running at the back wheels
  PV_ChaseRun: {
    Zone: 'FernValley', At: { Road: [600] }, Beats: B4, Subject: ['rv'],
    Note: 'Gameplay: the real drive camera and run HUD, ESCAPE TO THE TIME PORTAL banner, raptors alongside, one flashes red.',
    UI: { HUD: 'Run', Vehicle: 'RaptorRunner', HP: 0.8, Darts: 6, MaxDarts: 8, Coins: 240, Slots: 3,
      Eggs: [{ Species: 'Velociraptor', Rarity: 'Legendary', KG: 184 }, { Species: 'Velociraptor', Rarity: 'Rare', KG: 96 }], S: 600, Speed: 32, Length: 1753 },
    Actors: [
      rover('rv', 'RaptorRunner', { Road: { S: 0, Speed: 32, X: [[0, 0], [2, 1.5], [4, -1]] } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }),
      rackEgg('e1', 'Velociraptor', 'Legendary', 'rv', 1), rackEgg('e2', 'Velociraptor', 'Rare', 'rv', 2),
      dino('r1', 'Velociraptor', { Road: { S: [[0, -18], [2, -13], [4, -14]], Speed: 32, X: -6.5 } }, { Loco: 'Run', Glow: [[2.6, 3.6]] }),
      dino('r2', 'Velociraptor', { Road: { S: [[0, -22], [4, -15]], Speed: 32, X: 6.5 } }, { Loco: 'Run' }),
    ],
    Cam: { Player: 'rv' },
    Cues: [[0.15, 'Banner', 'ESCAPE TO THE TIME PORTAL!', 'DART THEM WHEN THEY FLASH RED - HOLD C TO LOOK BACK', 'Gate'], [2.6, 'Warn', -1]],
    Score: score(8, 7, 9, 9, 8, 8),
  },
  // look back, dart the one that flashes red: PERFECT
  PV_LookBackPerfect: {
    Zone: 'FernValley', At: { Road: [700] }, Beats: B2, Subject: ['r1'],
    Note: 'Gameplay: hold LOOK BACK, the raptor flashes red, a dart lands on the telegraph: the game\'s PERFECT! pops.',
    UI: { HUD: 'Run', Vehicle: 'RaptorRunner', HP: 0.7, Darts: 5, MaxDarts: 8, Coins: 270, Slots: 3,
      Eggs: [{ Species: 'Velociraptor', Rarity: 'Legendary', KG: 184 }, { Species: 'Velociraptor', Rarity: 'Rare', KG: 96 }], S: 700, Speed: 30, Length: 1753 },
    Actors: [
      rover('rv', 'RaptorRunner', { Road: { S: 0, Speed: 30, X: 0 } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }),
      rackEgg('e1', 'Velociraptor', 'Legendary', 'rv', 1), rackEgg('e2', 'Velociraptor', 'Rare', 'rv', 2),
      dino('r1', 'Velociraptor', { Road: { S: [[0, -13], [1, -11.5], [1.3, -12], [2, -22]], Speed: 30, X: 6.5 } }, { Loco: 'Run', Acts: [[1.25, 'Stumble', 1.2]], Glow: [[0.2, 1.25]] }),
    ],
    Cam: { Player: 'rv', LookBack: [[0, 0.2], [0.45, 1, 'out']] },
    Cues: [[0.95, 'Dart', of('rv', [0.8, 6, 2]), part('r1', 'Chest'), 0.28], [1.25, 'Perfect', part('r1', 'Chest', [0, 2, 0])]],
    Score: score(8, 7, 9, 9, 8, 8),
  },
  // sneak up and lift a glowing egg from the raptor nest: the game's own prompt card, hold-fill and toast
  PV_EggPickup: {
    Zone: 'FernValley', At: { Nest: 1 }, Beats: B4, Subject: ['p1'],
    Note: 'Gameplay: third-person walk-up, the real "Pick up" prompt fills, the player lifts a LEGENDARY egg while the raptors sleep.',
    UI: { HUD: 'None' },
    Actors: [
      crew('p1', 1, { Move: { Path: [[-1.5, -14], [-0.6, -2.4]], Beats: 1.8, Ease: 'out', Face: [0, 0] }, Acts: [[2.3, 'Grab']], Carry: 2.6 }),
      { Id: 'egg', Egg: 'Velociraptor', Rarity: 'Legendary', Move: { Spot: [0, 0] }, HeldBy: 'p1', HeldFrom: 2.6 },
      dino('r1', 'Velociraptor', { Spot: [4, 8], Face: [-1, -2] }, { Acts: [[0, 'Sleep']] }),
      dino('r2', 'Velociraptor', { Spot: [-6, 10], Face: [1, 0] }, { Acts: [[0, 'Sleep']] }),
    ],
    Cam: { Player: 'p1', Yaw: 180, Pitch: -18, Dist: 12 },
    Cues: [[1.4, 'Prompt', 'egg', 'Pick up', 'Velociraptor', 0.45], [1.9, 'PromptHold', 'egg'], [2.6, 'PromptHide', 'egg'],
      [2.7, 'Toast', 'GOT A LEGENDARY EGG! LOAD IT ON YOUR ROVER', 'Green', 'Egg'], [2.6, 'Sparkle', [0, 2, 0], 'Legendary']],
    Score: score(7, 6, 7, 9, 8, 8),
  },
  // the ruler is calm: the real RODEO prompt, then cut to the ride
  PV_RodeoPrompt: {
    Zone: 'FernValley', At: { Marker: 'FinalArena' }, Beats: B2, Subject: ['rex'],
    Note: 'Gameplay: over the shoulder, the Tyrant King is down and dizzy, the game\'s RODEO! prompt pops on it.',
    UI: { HUD: 'None' },
    Actors: [
      dino('rex', 'TyrannosaurusRex', { Spot: [0, 0] }, { Acts: [[0, 'Stunned']], Scale: 1.15 }),
      crew('p1', 1, { Move: { Path: [[-6, -22], [-3, -11]], Beats: 1.4, Ease: 'out', Face: [0, 0] }, Combat: true }),
    ],
    Cam: { Player: 'p1', Yaw: 170, Pitch: -10, Dist: 11, Shoulder: true },
    Cues: [[0.1, 'Stun', 'rex', 3], [0.5, 'Prompt', 'rex', 'RODEO!', 'Jump on', 0], [1.5, 'PromptHold', 'rex']],
    Score: score(7, 8, 6, 9, 9, 8),
  },
  // home: the hatch stage, the camp HUD and the "Hatch" prompt on your egg
  PV_HatchPrompt: {
    Zone: 'BaseCamp', At: { Point: [564, 0, 9], Face: [1, 0, -0.25] }, Beats: B2, Subject: ['egg'],
    Note: 'Gameplay: back at camp with the real hotbar and coins, the "Hatch" prompt fills on the SECRET egg.',
    UI: { HUD: 'Camp' },
    Actors: [
      crew('p1', 1, { Move: { Path: [[0, -13], [0, -6]], Beats: 1.2, Ease: 'out', Face: [0, 0] } }),
      { Id: 'egg', Egg: 'TyrannosaurusRex', Rarity: 'Secret', Scale: 1.6, Move: { Spot: [0, 0] } },
    ],
    Cam: { Player: 'p1', Yaw: 180, Pitch: -14, Dist: 12 },
    Cues: [[0.4, 'Prompt', 'egg', 'Hatch', 'T. Rex Egg', 0.6], [1.0, 'PromptHold', 'egg']],
    Score: score(7, 6, 6, 9, 8, 8),
  },

  // ============================================================== PLACES
  ValleyCrane: {
    Zone: 'FernValley', At: { Marker: 'EstShot1', LookAttr: true, Air: true }, Beats: B2, Subject: [],
    Note: 'Wide establisher: crane over Fern Valley (used for one or two beats only).',
    Actors: [],
    Cam: { From: [0, 6, 20], To: [0, 0, 0], Look: [-40, -90, -320], Fov: [50, 46], Ease: 'out', Hand: 0.3 },
    Score: score(6, 3, 7, 8, 7, 6),
  },
  PlainsRibcage: {
    Zone: 'GiantPlains', At: { Road: [140] }, Beats: B2, Subject: ['rv'],
    Note: 'Golden hour: the rover drives at the lens under the giant fossil spine arch.',
    Actors: [
      rover('rv', 'TitanTransport', { Road: { S: [[0, -34], [2, 2]], Speed: 0, X: 0 } }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2 }),
    ],
    Cam: { From: [4, 1.2, -26], To: [3.6, 1.3, -24], Look: of('rv', [0, 9, 0]), Fov: [56, 54], Ease: 'linear', Hand: 0.5 },
    Score: score(7, 5, 8, 8, 9, 8),
  },
  GateDriveIn: {
    Zone: 'BaseCamp', At: { Marker: 'GateArrival', Toward: 'GateTrigger' }, Beats: B2, Subject: ['rv'],
    Note: 'Behind the rover as it floors it into the Time Gate; flash on the downbeat.',
    Actors: [
      rover('rv', 'RookieRanger', { Path: [[0, 28], [0, -10]], Beats: 2, Ease: 'in' }),
      crew('p1', 1, { Ride: 'rv', Seat: 1 }), crew('p2', 2, { Ride: 'rv', Seat: 2 }),
    ],
    Cam: { From: [-3, 3, 40], To: [-2, 3.5, 24], Look: [0, 7, -10], Fov: [50, 60], Ease: 'in', Hand: 0.5 },
    Cues: [[1.75, 'Flash', 0.9], [1.6, 'Speed', 0.5]],
    Score: score(7, 3, 9, 8, 8, 8),
  },
};

// ---------------------------------------------------------------- sequences (shot, beats)
const Sequences = [
  {
    Id: 'TIKTOK_00_DINO_EXPEDITION_MASTER', Name: 'DINO EXPEDITION MASTER', Category: 'MASTER',
    Hook: 'this roblox game is actually insane',
    Shots: [
      ['RexBumperBite', 4],         // HOLY CRAP
      ['PV_ChaseRun', 4],           // gameplay: this is what driving it looks like
      ['TriCrossHood', 2],          // close call
      ['RaptorScreechCU', 1],
      ['PV_EggPickup', 4],          // gameplay: you steal the egg
      ['EggGrabWake', 2, 2],        // ...and they wake up
      ['RaptorPounceRack', 2],
      ['PV_LookBackPerfect', 2],    // gameplay: PERFECT!
      ['RexStomp', 2],              // the ruler
      ['RexKingsRoar', 4],
      ['PV_RodeoPrompt', 2],        // gameplay: RODEO!
      ['RexRodeo', 2],
      ['RexDefeated', 2],
      ['PlainsRibcage', 2],         // a second world
      ['BrachioCrossing', 4],
      ['StegoTail', 1],
      ['AnkyClub', 1],
      ['CarnoAmbush', 2],           // what is THAT
      ['PV_HatchPrompt', 2],        // gameplay: home, hatch
      ['HatchSecret', 4],
      ['RexRoarLow', 2],
      ['BabyRexRoar', 2],
      ['GigaBreakthrough', 4],      // the next ruler
      ['GigaFlatsChase', 4],
      ['GigaLensBite', 2],          // black
    ],
  },
  {
    Id: 'TIKTOK_01_BOSSES', Name: 'THE BOSSES', Category: 'BOSSES', Hook: 'every era has a boss',
    Shots: [['RexStomp', 2], ['RexKingsRoar', 4], ['RexRoarLow', 2], ['RexRodeo', 2], ['RexDefeated', 4], ['GigaBreakthrough', 4], ['GigaRoar', 4], ['GigaFlatsChase', 4], ['GigaLensBite', 2]],
  },
  {
    Id: 'TIKTOK_02_JEEP_CHAOS', Name: 'ROVER CHAOS', Category: 'CHASES', Hook: 'POV you picked the wrong expedition',
    Shots: [['RexBumperBite', 4], ['RaptorPackFlank', 2], ['RaptorPounceRack', 2], ['DartPerfect', 2], ['TriCrossHood', 2], ['RexSideRun', 2], ['BrachioCrossing', 4], ['GigaFlatsChase', 4], ['RackHaul', 2]],
  },
  {
    Id: 'TIKTOK_03_DINOSAURS_YOU_CAN_FIND', Name: 'DINOS YOU CAN FIND', Category: 'DINOSAURS', Hook: 'every dinosaur in this game has its own entrance',
    Shots: [['RaptorLeap', 4], ['TriCharge', 4], ['ParaStampede', 2], ['StegoTail', 2], ['AnkyClub', 2], ['BrachioFootfall', 4], ['CarnoAmbush', 2], ['RexKingsRoar', 4], ['GigaBreakthrough', 4]],
  },
  {
    Id: 'TIKTOK_04_EGG_EXTRACTION', Name: 'EGG EXTRACTION', Category: 'EGGS', Hook: 'this is why you don\'t steal the egg',
    Shots: [['EggGrabWake', 4], ['RaptorScreechCU', 1], ['RaptorPackFlank', 2], ['RaptorPounceRack', 2], ['DartPerfect', 2], ['RackHaul', 2], ['GateDriveIn', 2], ['HatchSecret', 4], ['BabyRexRoar', 2]],
  },
  {
    Id: 'TIKTOK_05_GAME_IS_BIGGER', Name: 'BIGGER THAN YOU THINK', Category: 'MASTER', Hook: 'wait this game has THAT too?',
    Shots: [['GateDriveIn', 2], ['ValleyCrane', 2], ['RaptorPackFlank', 2], ['TriCrossHood', 2], ['EggGrabWake', 4], ['RexKingsRoar', 4], ['RexRodeo', 2], ['PlainsRibcage', 2], ['BrachioCrossing', 4], ['GigaBreakthrough', 4], ['HatchSecret', 4], ['GigaLensBite', 2]],
  },
  {
    Id: 'TIKTOK_06_RAREST', Name: 'THE RAREST HATCH', Category: 'EGGS', Hook: '0.1% chance',
    Shots: [['RackHaul', 2], ['HatchSecret', 4], ['BabyRexRoar', 2], ['RexRoarLow', 2], ['BabyRexRoar', 2]],
  },
  {
    Id: 'TIKTOK_08_EXPEDITIONS', Name: 'TWO ERAS', Category: 'EXPEDITIONS', Hook: 'we may have made the dinosaurs a little too big',
    Shots: [['GateDriveIn', 2], ['ValleyCrane', 2], ['ParaStampede', 2], ['TriCrossHood', 2], ['RexSideRun', 2], ['PlainsRibcage', 2], ['BrachioCrossing', 4], ['StegoTail', 2], ['AnkyClub', 2], ['GigaFlatsChase', 4]],
  },
  {
    Id: 'TIKTOK_09_GAMEPLAY', Name: 'GAMEPLAY CLIPS', Category: 'GAMEPLAY', Hook: 'the gameplay is even better',
    Shots: [['PV_ChaseRun', 4], ['PV_LookBackPerfect', 2], ['PV_EggPickup', 4], ['PV_RodeoPrompt', 2], ['RexRodeo', 2], ['PV_HatchPrompt', 2], ['HatchSecret', 4]],
  },
  { Id: 'HOOK_3S_REX_BITE', Name: '3s: REX BITES THE BUMPER', Category: 'SHORT HOOKS', Shots: [['RexBumperBite', 4], ['GigaLensBite', 2]] },
  { Id: 'HOOK_3S_BRACHIO_CROSSING', Name: '3s: BRACHIOSAURUS CROSSING', Category: 'SHORT HOOKS', Shots: [['BrachioCrossing', 4], ['BrachioFootfall', 2]] },
  { Id: 'HOOK_5S_DONT_STEAL', Name: '5s: DON\'T STEAL THE EGG', Category: 'SHORT HOOKS', Shots: [['EggGrabWake', 4], ['RaptorScreechCU', 1], ['RaptorPounceRack', 2], ['DartPerfect', 2]] },
  { Id: 'HOOK_5S_PARENT_BABY', Name: '5s: PARENT VS BABY', Category: 'SHORT HOOKS', Shots: [['RexRoarLow', 2], ['BabyRexRoar', 2], ['RexKingsRoar', 4], ['BabyRexRoar', 2]] },
  { Id: 'HOOK_8S_BOSS_TO_BITE', Name: '8s: BOSS INTRO TO ATTACK', Category: 'SHORT HOOKS', Shots: [['GigaBreakthrough', 4], ['GigaFlatsChase', 4], ['RexBumperBite', 4], ['GigaLensBite', 2]] },
];

const Categories = ['MASTER', 'GAMEPLAY', 'BOSSES', 'CHASES', 'DINOSAURS', 'EGGS', 'EXPEDITIONS', 'SHORT HOOKS', 'SHOTS'];

// the boss reveals (played in game as each boss's intro, and cut into TikToks) live in reveals.js
const R = require('./reveals.js');
Object.assign(Shots, R.Shots);
Sequences.push(...R.Sequences);
for (const c of R.Categories) if (!Categories.includes(c)) Categories.splice(Categories.indexOf('SHOTS'), 0, c);

// the new player's cold open (Game/Prologue.luau plays it) lives in prologue.js
const PR = require('./prologue.js');
Object.assign(Shots, PR.Shots);
Sequences.push(...PR.Sequences);
for (const c of PR.Categories) if (!Categories.includes(c)) Categories.splice(Categories.indexOf('SHOTS'), 0, c);

module.exports = { Music: { BPM: 123, MusicOffset: 0 }, Shots, Sequences, Categories };
