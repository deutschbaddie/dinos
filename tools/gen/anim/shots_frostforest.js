// Frost Forest signature shot lists (Studs: true = studs in the creature's ground frame: origin on the ground under
// its RootPart at rest, -Z = the way it faces, +X = its right). Verified in tools/preview/cine.html.
const V = (x, y, z) => ({ __v3: [x, y, z] });
const F = (target, x = 0, y = 0, z = 0) => ({ Follow: target, Offset: V(x, y, z) });
const shot = (Name, T0, T1, From, To, o = {}) => Object.assign({ Name, T0, T1, From, To, Ease: 'Sine' }, o);
const S = (Pos, Look, Fov, Roll) => ({ Pos, Look, Fov, Roll });

module.exports = {
  // MICRORAPTOR — SHADOW GLIDE: up at the branch, its eyes find you, it drops at the lens, whips past, banks round,
  // lands in slow motion and the wings flash open
  MicroShadowGlide: {
    Studs: true, Title: 4.0, Hold: 8, DOF: true, Prop: 'Perch', TimeRamps: [[3.32, 3.56, 0.3], [3.92, 4.12, 0.45]],
    Shots: [
      shot('Branch', 0, 1.0, S(V(-3.4, 1.3, -3.0), 'Head', 36), S(V(-3.1, 1.5, -2.5), 'Head', 33), { Ease: 'Linear' }),
      shot('Eyes', 1.0, 1.42, S(F('Head', 1.3, -1.0, -2.6), 'Head', 32, -4), S(F('Head', 1.2, -0.95, -2.4), 'Head', 30, -3)),
      shot('Drop', 1.42, 1.95, S(V(-1.6, 1.2, -1.4), 'Head', 54), S(V(-1.7, 1.15, -1.6), 'Head', 58, 4), { Ease: 'Linear' }),
      shot('Swoop', 1.95, 2.62, S(V(3.8, 0.9, -6.2), 'Head', 60, -5), S(V(3.6, 0.85, -6.4), 'Head', 64, 6), { Ease: 'Linear' }),
      shot('Bank', 2.62, 3.25, S(V(-7.6, 2.4, -7.2), 'Head', 40, 3), S(V(-7.4, 2.2, -6.8), 'Head', 38, 0), { Ease: 'Linear' }),
      shot('Landing', 3.25, 3.85, S(V(-1.6, 0.4, -1.4), F('Head', 0, -0.25, 0), 46, 3), S(V(-1.5, 0.4, -1.3), F('Head', 0, -0.25, 0), 44, 1), { Ease: 'Out' }),
      shot('Shimmer', 3.85, 4.48, S(V(-0.9, 0.6, -3.0), F('Chest', 0, 0.3, 0), 56), S(V(-0.8, 0.6, -2.7), F('Chest', 0, 0.3, 0), 50, -2), { Ease: 'Out' }),
      shot('Chirp', 4.48, 5.05, S(F('Head', 1.5, 0.0, -2.4), 'Head', 38, 3), S(F('Head', 1.4, -0.05, -2.2), 'Head', 35, -2)),
      shot('Hop', 5.05, 6.4, S(V(-2.4, 0.5, -3.5), V(0, 1.0, 0.6), 44), S(V(-2.7, 0.55, -3.9), V(0, 1.0, 0.6), 46), { Blend: 0.4 }),
    ],
  },
  // PSITTACOSAURUS — HIDE AND SQUEAK: down in the frosty ferns, nothing; a twig snaps at the lens; a head pops up
  // and tilts; the quills flare and rattle; a squeal to the sky; the herd peeks out
  PsittaHideSqueak: {
    Studs: true, Title: 3.1, Hold: 8, DOF: true, Prop: 'Twig', TimeRamps: [[1.42, 1.56, 0.35], [2.95, 3.15, 0.5]],
    Shots: [
      shot('Undergrowth', 0, 1.3, S(V(-1.0, 0.95, -6.6), V(0, 0.8, -1.2), 38), S(V(-0.8, 0.9, -5.9), V(0, 0.8, -1.2), 35), { Ease: 'Linear' }),
      shot('Snap', 1.3, 1.6, S(V(1.5, 0.9, -5.3), V(0.4, 0.1, -4.0), 36, 4), S(V(1.4, 0.85, -5.15), V(0.4, 0.1, -4.0), 33, 3), { Ease: 'Out' }),
      shot('PopUp', 1.6, 2.4, S(V(-2.2, 1.9, -6.0), 'Head', 30), S(V(-2.0, 1.9, -5.6), 'Head', 27, -2)),
      shot('Quills', 2.4, 2.92, S(V(3.0, 1.0, 2.0), F('Crest', 0, -0.3, 0), 42, 4), S(V(2.8, 1.05, 2.2), F('Crest', 0, -0.3, 0), 40, 2), { Ease: 'Out' }),
      shot('Squeak', 2.92, 3.85, S(V(-2.8, 0.9, -3.6), F('Head', 0, -0.4, 0), 44, -3), S(V(-2.55, 0.9, -3.3), F('Head', 0, -0.4, 0), 49, 2), { Ease: 'Out' }),
      shot('Herd', 3.85, 4.75, S(F('Herd', -2.2, 0.1, -2.8), 'Herd', 38), S(F('Herd', -2.0, 0.1, -2.5), 'Herd', 36)),
      shot('Hop', 4.75, 6.2, S(V(-3.6, 1.5, -5.6), V(0, 1.5, -0.6), 44), S(V(-4.0, 1.55, -6.2), V(0, 1.5, -0.6), 46), { Blend: 0.4 }),
    ],
  },
  // COMPY — SWARM: a hollow log in the snow; two eyes glint inside; a head pops out, a hop... then the log empties
  // around the lens, and the whole swarm chirps at once
  CompySwarm: {
    Studs: true, Title: 3.75, Hold: 8, DOF: true, Prop: 'HollowLog', TimeRamps: [[1.92, 2.18, 0.4], [3.68, 3.86, 0.5]],
    Shots: [
      shot('Log', 0, 1.0, S(V(-3.6, 0.8, -0.6), V(0, 0.9, 2.6), 40), S(V(-3.3, 0.75, -0.3), V(0, 0.9, 2.6), 38), { Ease: 'Linear' }),
      shot('Glint', 1.0, 1.28, S(V(0.15, 0.85, -0.6), F('Head', 0, 0, 0), 30), S(V(0.12, 0.85, -0.45), F('Head', 0, 0, 0), 27)),
      shot('Peek', 1.28, 1.86, S(V(-1.1, 0.75, -1.8), 'Head', 36, -3), S(V(-0.95, 0.72, -1.6), 'Head', 33, -1)),
      shot('HopOut', 1.86, 2.45, S(V(-2.5, 0.35, -1.2), F('Head', 0, -0.3, 0), 46, 3), S(V(-2.4, 0.35, -1.4), F('Head', 0, -0.3, 0), 48, 1), { Ease: 'Out' }),
      shot('Pour', 2.45, 3.6, S(V(0.5, 0.5, -3.2), V(0, 0.7, 1.2), 64, -3), S(V(0.4, 0.45, -3.5), V(0, 0.7, 1.2), 70, 3), { Ease: 'Linear' }),
      shot('Chorus', 3.6, 4.55, S(F('Head', -1.1, -0.1, -2.0), F('Head', 0, -0.1, 0), 38, 3), S(F('Head', -1.0, -0.1, -1.8), F('Head', 0, -0.1, 0), 35, -2), { Ease: 'Out' }),
      shot('Hero', 4.55, 5.6, S(V(-1.7, 0.4, -2.8), V(0, 0.8, 0.6), 50), S(V(-1.9, 0.42, -3.2), V(0, 0.8, 0.6), 52), { Blend: 0.35 }),
    ],
  },
  // YUTYRANNUS — BLIZZARD KING: a shape in the whiteout, eyes first; a foot comes down out of the snow; it shakes off a
  // cloud of snow in slow motion; breath steaming in profile; it stamps the ice into cracks; the roar; the pines let go
  YutyBlizzardKing: {
    Studs: true, Title: 6.2, Hold: 8, DOF: true, Prop: 'SnowPines', TimeRamps: [[3.2, 3.75, 0.45], [5.22, 5.42, 0.4], [5.95, 6.25, 0.5]],
    Shots: [
      shot('Whiteout', 0, 2.2, S(V(-4.5, 1.6, -27), V(0, 8, 4), 40), S(V(-3.9, 1.6, -24.5), V(0, 8.5, 1), 38), { Ease: 'Linear' }),
      shot('Footfall', 2.2, 2.95, S(V(6.0, 0.45, -7.0), F('LeftFoot', 0, 1.4, 0), 46, -3), S(V(5.7, 0.45, -6.6), F('LeftFoot', 0, 1.6, 0), 44, -2), { Ease: 'Linear' }),
      shot('Shake', 2.95, 4.35, S(V(-14.5, 5.5, -17), V(0, 8.5, -1.5), 46), S(V(-13.6, 5.3, -16), V(0, 8.5, -1.5), 44, 2), { Ease: 'Sine' }),
      shot('Breath', 4.35, 5.05, S(V(-11.5, 10.8, -19.5), F('Head', 0, -0.4, -1.5), 34, -2), S(V(-11.0, 10.7, -18.8), F('Head', 0, -0.4, -1.5), 32, -1)),
      shot('Stamp', 5.05, 5.75, S(V(3.8, 0.55, -11.5), F('RightFoot', 0, 0.8, 0), 50, 3), S(V(3.6, 0.55, -11.2), F('RightFoot', 0, 0.8, 0), 54, 1), { Ease: 'Out' }),
      shot('Roar', 5.75, 6.75, S(V(-5.5, 2.4, -21), F('Head', 0, -1.2, 0), 48, -2), S(V(-5.0, 2.3, -19.8), F('Head', 0, -1.2, 0), 55, 3), { Ease: 'Out' }),
      shot('Pines', 6.75, 7.45, S(V(-13, 2.2, -33), V(0, 9, 4), 56), S(V(-13.6, 2.3, -34.5), V(0, 9, 4), 57)),
      shot('Hero', 7.45, 8.0, S(V(-8.5, 1.6, -25), V(0, 8.5, -3), 46), S(V(-9.0, 1.65, -26), V(0, 8.5, -3), 48), { Blend: 0.4 }),
    ],
  },
};
