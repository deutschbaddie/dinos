// Red Cliffs signature shot lists (Studs: true -> positions in studs in the creature's ground frame:
// origin on the ground under its RootPart at rest, -Z = the way it faces, +X = its right). Verified in tools/preview/cine.html.
const V = (x, y, z) => ({ __v3: [x, y, z] });
const F = (target, x = 0, y = 0, z = 0) => ({ Follow: target, Offset: V(x, y, z) });
const shot = (Name, T0, T1, From, To, o = {}) => Object.assign({ Name, T0, T1, From, To, Ease: 'Sine' }, o);
const S = (Pos, Look, Fov, Roll) => ({ Pos, Look, Fov, Roll });

module.exports = {
  // OVIRAPTOR — EGG HEIST: a whip-pan on the dash in, tight on the nest, a dolly-zoom "caught!" freeze, the flare, the honk
  OviHeist: {
    Studs: true, Title: 4.1, Hold: 8, DOF: true, Prop: 'Nest', Handheld: 0.3, TimeRamps: [[1.7, 1.95, 0.4], [2.38, 2.95, 0.3]],
    Shots: [
      shot('Dash', 0, 0.95, S(V(2.4, 0.45, -3.6), 'Head', 52, 4), S(V(2.3, 0.45, -3.4), 'Head', 56, -2), { Ease: 'Linear' }),
      shot('Snatch', 0.95, 2.05, S(V(-2.6, 1.15, -4.6), V(0, 0.8, -1.8), 40, -3), S(V(-2.2, 1.05, -4.1), V(0, 0.75, -1.8), 35, -2)),
      shot('Caught', 2.05, 3.05, S(V(-2.7, 2.75, -7.8), F('Head', 0, -0.35, 0), 24), S(V(-1.75, 2.7, -4.7), F('Head', 0, -0.35, 0), 42), { Ease: 'Out' }),
      shot('Flare', 3.05, 3.6, S(V(3.4, 0.7, -3.9), F('Head', 0, -1.0, 0), 52, -4), S(V(3.2, 0.7, -3.6), F('Head', 0, -1.0, 0), 57, 2)),
      shot('Honk', 3.6, 4.8, S(V(-2.1, 2.8, -4.5), F('Head', 0, -0.25, -0.2), 44, 3), S(V(-1.9, 2.75, -4.1), F('Head', 0, -0.25, -0.2), 50, -2)),
      shot('Hero', 4.8, 5.6, S(V(-3.4, 0.6, -5.4), V(0, 2.2, -0.6), 48), S(V(-3.7, 0.62, -5.9), V(0, 2.2, -0.6), 50), { Blend: 0.4 }),
    ],
  },
  // PROTOCERATOPS — SAND BURST: skimming a breathing dune, the eruption in slow motion, the wet-dog shake, the frill
  // flash pushed in head-on, the head-butt that splits the rock
  ProtoBurst: {
    Studs: true, Title: 4.7, Hold: 8, DOF: true, Prop: 'Rock', TimeRamps: [[1.2, 1.62, 0.3], [4.1, 4.36, 0.35]],
    Shots: [
      shot('Dunes', 0, 1.2, S(V(-2.6, 0.32, -7.2), V(0, 1.0, -2.3), 38), S(V(-2.1, 0.32, -6.2), V(0, 1.0, -2.3), 33), { Ease: 'Linear' }),
      shot('Burst', 1.2, 1.78, S(V(-3.3, 0.42, -5.4), F('Head', 0, -0.2, 0), 58, -4), S(V(-3.6, 0.42, -5.8), F('Head', 0, -0.2, 0), 68, 2), { Ease: 'Out' }),
      shot('Shake', 1.78, 2.88, S(V(-6.6, 2.0, -2.4), V(0, 1.6, -0.9), 44), S(V(-6.2, 2.0, -2.1), V(0, 1.6, -0.9), 41)),
      shot('Flash', 2.88, 3.88, S(V(-2.7, 1.2, -7.6), F('Crest', 0, -1.25, 0), 44), S(V(-2.15, 1.25, -6.6), F('Crest', 0, -1.25, 0), 38)),
      shot('Butt', 3.88, 4.62, S(V(4.2, 0.55, -7.4), V(0, 0.9, -5.6), 50, 3), S(V(4.4, 0.55, -7.8), V(0, 0.9, -5.6), 56, -2), { Ease: 'Linear' }),
      shot('Hero', 4.62, 5.6, S(V(-4.0, 0.7, -9.0), V(0, 1.5, -2.4), 46), S(V(-4.4, 0.75, -9.6), V(0, 1.5, -2.4), 48), { Blend: 0.4 }),
    ],
  },
  // GALLIMIMUS — FLOCK SPRINT: a flock streaks across a low lens, the lead skids in slow motion, wheels, a long-lens
  // stare, then the shriek up the long neck
  GalliStampede: {
    Studs: true, Title: 4.2, Hold: 8, DOF: true, Handheld: 0.28, TimeRamps: [[1.25, 1.75, 0.35], [3.0, 3.12, 0.5]],
    Shots: [
      shot('Streak', 0, 1.25, S(V(2.4, 0.5, -6.5), F('Head', 0, -2.5, 0), 62, 3), S(V(2.4, 0.5, -6.5), F('Head', 0, -2.5, 0), 66, -4), { Ease: 'Linear' }),
      shot('Skid', 1.25, 1.95, S(V(8.0, 0.4, -5.6), F('RightFoot', 0, 2.6, 0), 52, -3), S(V(7.7, 0.4, -5.1), F('RightFoot', 0, 2.6, 0), 48, 2)),
      shot('Wheel', 1.95, 2.45, S(V(-10.5, 3.4, -11.5), F('Head', 0, -2.2, 0), 50), S(V(-9.8, 3.4, -10.8), F('Head', 0, -2.2, 0), 47), { Ease: 'Out' }),
      shot('Stare', 2.45, 3.3, S(V(-1.4, 7.4, -12.5), F('Head', 0, -0.05, 0), 26), S(V(-1.1, 7.45, -11.0), F('Head', 0, -0.05, 0), 21)),
      shot('Shriek', 3.3, 4.85, S(V(-6.6, 2.0, -10.4), F('Head', 0, -1.9, 0), 50, 3), S(V(-6.0, 2.0, -9.6), F('Head', 0, -1.9, 0), 57, -2)),
      shot('Hero', 4.85, 5.8, S(V(-8.5, 1.1, -13.5), V(0, 4.6, -1.5), 46), S(V(-9.2, 1.15, -14.4), V(0, 4.6, -1.5), 48), { Blend: 0.4 }),
    ],
  },
  // THERIZINOSAURUS — SCYTHE HARVEST: claws rising into the canopy, the branches raining down in slow motion, the turn,
  // the crossed-claw X pushed in, a worm's-eye rear-up hiss, and a claw rake that slashes straight at the lens
  TheriHarvest: {
    Studs: true, Title: 5.0, Hold: 8, DOF: true, Prop: 'Canopy', TimeRamps: [[1.3, 1.75, 0.35], [6.12, 6.5, 0.25]],
    Shots: [
      shot('Canopy', 0, 1.3, S(V(-6.0, 1.2, -24.0), V(5.0, 15.0, -4.0), 50), S(V(-5.2, 1.2, -22.5), V(5.5, 16.5, -4.0), 46), { Ease: 'Linear' }),
      shot('Rake', 1.3, 2.45, S(V(20.0, 3.0, -19.0), V(4.5, 11.5, -3.5), 58, 3), S(V(19.0, 3.0, -18.0), V(4.5, 11.0, -3.5), 63, -2)),
      shot('Turn', 2.45, 3.5, S(V(-17.0, 6.0, -16.0), F('Head', 0, -2.0, 0), 46), S(V(-16.0, 6.0, -15.0), F('Head', 0, -2.0, 0), 44), { Ease: 'Out' }),
      shot('Cross', 3.5, 4.65, S(V(-3.4, 8.0, -24.0), F('Chest', 0, 3.6, 0), 42), S(V(-2.8, 8.2, -21.0), F('Chest', 0, 3.6, 0), 37)),
      shot('Rear', 4.65, 6.05, S(V(-4.0, 0.6, -16.5), F('Head', 0, -2.5, 0), 56, -3), S(V(-3.6, 0.6, -15.6), F('Head', 0, -2.5, 0), 63, 2)),
      shot('Slash', 6.05, 6.75, S(V(2.6, 8.5, -21.0), V(-0.5, 11.2, -8.5), 58, -5), S(V(2.4, 8.3, -20.4), V(-0.5, 10.8, -8.5), 66, 4), { Ease: 'Out' }),
      shot('Hero', 6.75, 7.8, S(V(-15.0, 1.4, -25.0), V(0, 9.0, -3.0), 48), S(V(-16.0, 1.5, -26.5), V(0, 9.0, -3.0), 50), { Blend: 0.5 }),
    ],
  },
};
