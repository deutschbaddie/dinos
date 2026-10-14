// Dawn Desert signature shot lists (Coelophysis, Plateosaurus, Dilophosaurus, Postosuchus).
// Studs: true = positions in studs in the creature's ground frame (origin under its RootPart at rest, -Z = facing,
// +X = its right). Checked frame by frame in tools/preview/cine.html?file=out/cine_<Species>_<Key>.json
const V = (x, y, z) => ({ __v3: [x, y, z] });
const F = (target, x = 0, y = 0, z = 0) => ({ Follow: target, Offset: V(x, y, z) });
const shot = (Name, T0, T1, From, To, o = {}) => Object.assign({ Name, T0, T1, From, To, Ease: 'Sine' }, o);
const S = (Pos, Look, Fov, Roll) => ({ Pos, Look, Fov, Roll });

module.exports = {
  // COELOPHYSIS — OASIS STRIKE: low over the water while it drinks with its back to you; tight as the head comes up;
  // a whip-pan as it spins round; slow-mo under the leap; the chorus from the rocks; the pack across the water.
  CoeloOasis: {
    Studs: true, Title: 3.5, Hold: 8, DOF: true, TimeRamps: [[2.66, 3.08, 0.35]],
    Shots: [
      shot('Waterline', 0, 1.38, S(V(0.7, 0.3, 9.3), F('Head', 0, -0.2, 0), 40), S(V(0.55, 0.28, 8.5), F('Head', 0, -0.2, 0), 34), { Ease: 'Linear' }),
      shot('HeadsUp', 1.38, 1.92, S(V(2.4, 2.9, 5.6), F('Head', 0, 0.1, 0), 30, -3), S(V(2.2, 3.0, 5.3), F('Head', 0, 0.1, 0), 28, -2)),
      shot('WhipRound', 1.92, 2.6, S(V(-2.2, 1.9, -7.2), V(3.8, 2.4, 1.0), 36, -6), S(V(-1.9, 1.8, -6.8), F('Head', 0, -0.2, 0), 46, 0), { Ease: 'Snap' }),
      shot('Leap', 2.6, 3.3, S(V(2.6, 0.3, -7.4), F('Chest', 0, 0.4, 0), 56, 3), S(V(2.4, 0.3, -7.8), F('Chest', 0, 0.4, 0), 62, 4), { Ease: 'Out' }),
      shot('Chorus', 3.3, 4.95, S(V(-3.0, 1.9, -8.4), F('Head', 0, -0.6, 0), 44, -2), S(V(-2.6, 1.85, -7.8), F('Head', 0, -0.6, 0), 50, 2)),
      shot('Pack', 4.95, 5.7, S(V(2.4, 4.2, -6.2), V(0, 1.6, 6.0), 46), S(V(2.0, 4.3, -5.8), V(0, 1.6, 6.0), 44)),
      shot('Hero', 5.7, 6.4, S(V(-5.8, 0.9, -10.2), V(0, 2.4, -1.6), 46), S(V(-6.4, 1.0, -11.0), V(0, 2.4, -1.6), 48), { Blend: 0.4 }),
    ],
  },
  // PLATEOSAURUS — TREE REACH: up past its head into the cycad crown; a ground-level tilt as it rears to full
  // height; high in the canopy as it strips it bare; slow-mo as it drops onto its hands; the bellow.
  PlateoReach: {
    Studs: true, Title: 5.95, Hold: 8, DOF: true, TimeRamps: [[3.08, 3.34, 0.4], [4.62, 4.98, 0.3]],
    Shots: [
      shot('Canopy', 0, 1.25, S(V(-4.6, 7.4, 2.4), V(3.0, 13.6, -3.4), 50), S(V(-4.2, 7.6, 1.8), V(3.0, 14.0, -3.4), 46), { Ease: 'Linear' }),
      shot('Rise', 1.25, 2.45, S(V(-1.2, 0.5, -16.2), F('Chest', 0, 1.0, 0), 48), S(V(-1.4, 0.5, -16.9), 'Head', 56, -2)),
      shot('Strip', 2.45, 3.6, S(V(-6.6, 12.6, -7.2), F('Head', 0.6, 0.2, -0.8), 40, -3), S(V(-6.1, 13.1, -6.6), F('Head', 0.6, 0.2, -0.8), 36, 2)),
      shot('Drop', 3.6, 5.0, S(V(-4.6, 0.7, -11.6), F('Chest', 0, 1.2, 0), 54), S(V(-4.4, 0.7, -12.4), F('Chest', 0, 0.8, 0), 62, 3), { Ease: 'Out' }),
      shot('Bellow', 5.0, 6.8, S(V(-4.6, 4.2, -15.6), F('Head', 0, -0.6, 0), 44, -2), S(V(-4.2, 4.1, -14.9), F('Head', 0, -0.6, 0), 48, 2)),
      shot('Hero', 6.8, 7.4, S(V(-16.0, 2.0, -15.5), V(0, 6.5, -2.0), 48), S(V(-17.0, 2.1, -16.4), V(0, 6.5, -2.0), 50), { Blend: 0.5 }),
    ],
  },
  // DILOPHOSAURUS — CREST FLARE: a long lens through the heat; a crash zoom as the crests flush; circling the
  // bobbing display; the tail cracks a dead snag; tight on the inhale... and the spit comes straight down the lens.
  DiloSpit: {
    Studs: true, Title: 4.75, Hold: 8, DOF: true, TimeRamps: [[3.28, 3.42, 0.4], [3.93, 4.1, 0.35]],
    Shots: [
      shot('Haze', 0, 1.4, S(V(-6.2, 1.3, -23.0), F('Head', 0, -0.4, 0), 22), S(V(-5.9, 1.3, -22.2), F('Head', 0, -0.4, 0), 20), { Ease: 'Linear' }),
      shot('Notice', 1.4, 1.95, S(V(-2.4, 6.4, -12.5), F('Crest', 0, -0.7, 0), 36), S(V(-2.3, 6.4, -12.3), F('Crest', 0, -0.7, 0), 20, -2), { Ease: 'Snap' }),
      shot('Display', 1.95, 3.2, S(V(-6.8, 5.4, -7.0), F('Crest', 0, -0.5, 0), 40, -3), S(V(-4.4, 5.8, -9.8), F('Crest', 0, -0.5, 0), 36, 3)),
      shot('Lash', 3.2, 3.6, S(V(9.6, 2.6, -1.8), V(5.4, 4.8, 4.6), 44, 2), S(V(9.3, 2.6, -2.1), V(5.4, 4.8, 4.6), 48, 4), { Ease: 'Out' }),
      shot('Inhale', 3.6, 3.93, S(V(-2.0, 7.8, -10.6), F('Head', 0, 0, 0), 38), S(V(-1.7, 7.7, -10.0), F('Head', 0, 0, 0), 32)),
      shot('Spit', 3.93, 4.5, S(V(-0.1, 5.2, -12.2), F('Mouth', 0, 0.1, 0), 44), S(V(-0.1, 5.2, -11.9), F('Mouth', 0, 0.1, 0), 56, 2), { Ease: 'Out' }),
      shot('Hiss', 4.5, 5.8, S(V(-3.8, 2.4, -11.4), F('Head', 0, -0.4, 0), 44, -2), S(V(-3.4, 2.3, -10.8), F('Head', 0, -0.4, 0), 48, 2)),
      shot('Hero', 5.8, 6.4, S(V(-9.6, 1.5, -14.8), V(-1.6, 4.0, 0), 48), S(V(-10.3, 1.6, -15.6), V(-1.6, 4.0, 0), 50), { Blend: 0.4 }),
    ],
  },
  // POSTOSUCHUS — BEFORE THE DINOSAURS: flat on the cracked riverbed; two eyes open in the mud; it erupts in slow-mo;
  // shakes the mud off; a worm's-eye tilt as it rises onto its hind legs; the roar; it slams down onto all fours.
  PostoRise: {
    Studs: true, Title: 5.0, Hold: 8, DOF: true, TimeRamps: [[1.62, 2.02, 0.3], [6.82, 7.04, 0.35]],
    Shots: [
      shot('Riverbed', 0, 1.0, S(V(2.0, 0.45, -15.6), V(-0.4, 0.5, -4.0), 46), S(V(1.8, 0.43, -14.6), V(-0.4, 0.5, -4.0), 44), { Ease: 'Linear' }),
      shot('Eyes', 1.0, 1.62, S(V(-4.2, 0.95, -10.4), F('Head', -0.9, 0.1, 1.0), 22), S(V(-3.8, 0.9, -9.8), F('Head', -0.9, 0.1, 1.0), 17)),
      shot('Erupt', 1.62, 2.5, S(V(-7.6, 0.6, -19.5), F('Head', 0, -1.2, 0), 50, -4), S(V(-8.3, 0.6, -20.3), F('Head', 0, -1.2, 0), 62, 2), { Ease: 'Out' }),
      shot('ShakeOff', 2.5, 3.4, S(V(-12.5, 3.2, -4.5), F('Chest', 0, 1.2, 0), 46), S(V(-11.8, 3.2, -5.1), F('Chest', 0, 1.2, 0), 44)),
      shot('Rise', 3.4, 4.75, S(V(-3.4, 0.5, -14.0), F('Chest', 0, 1.0, 0), 54), S(V(-3.8, 0.5, -14.9), 'Head', 62, -2)),
      shot('Roar', 4.75, 6.4, S(V(-2.8, 4.0, -17.0), F('Head', 0, -0.4, 0), 46, -2), S(V(-2.5, 4.0, -16.3), F('Head', 0, -0.4, 0), 52, 2)),
      shot('Drop', 6.4, 7.4, S(V(-10.4, 2.2, -16.5), F('Head', 0, -1.5, 0), 50), S(V(-11.0, 2.2, -17.2), F('Head', 0, -1.5, 0), 56, -3), { Ease: 'Out' }),
      shot('Hero', 7.4, 8.2, S(V(5.6, 1.2, -21.5), V(0, 4.0, -4.0), 46), S(V(6.2, 1.3, -22.4), V(0, 4.0, -4.0), 48), { Blend: 0.4 }),
    ],
  },
};
