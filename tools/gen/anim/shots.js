// Cinematic shot lists (source of truth; generates DinosaurCinematics/Shots.luau).
// Units: positions are multiplied by the creature profile's CameraScale and expressed in the creature's
// ground frame (origin on the ground under its RootPart, -Z = the direction it faces, +X = its right).
// A shot: { Name, T0, T1, From, To, Ease, Blend }   Blend = seconds to glide in from the previous shot (0 = hard cut)
// From/To: { Pos, Look, Fov, Roll(deg) }  Pos/Look: V(x,y,z) | 'Head' | { Follow: 'Head'|'RightFoot'|..., Offset: V(...) }
// TimeRamps: [t0, t1, speed] slow-motion windows (seconds, or fractions when Normalized).
const V = (x, y, z) => ({ __v3: [x, y, z] });
const F = (target, x = 0, y = 0, z = 0) => ({ Follow: target, Offset: V(x, y, z) });

module.exports = {
  ...require('./shots_signatures.js'),
  ...require('../newSpecies.js').shots(), // new species' signature lists (anim/shots_<group>.js)
  // T. rex — The King's Roar
  Emerge: {
    Normalized: false, Title: 6.25, DOF: true, Hold: 8,
    TimeRamps: [[4.72, 5.4, 0.35]],
    Shots: [
      { Name: 'JungleWall', T0: 0.0, T1: 1.5, Ease: 'Linear',
        From: { Pos: V(-1.5, 0.3, -8.4), Look: V(0, 2.5, 3.0), Fov: 46 }, To: { Pos: V(-1.25, 0.34, -7.6), Look: V(0, 2.6, 2.2), Fov: 44 } },
      { Name: 'Stomp', T0: 1.5, T1: 2.5, Ease: 'Linear',
        From: { Pos: V(0.95, 0.06, -3.3), Look: F('RightFoot', 0, 0.9, 0), Fov: 48, Roll: -3 }, To: { Pos: V(0.9, 0.06, -3.1), Look: F('RightFoot', 0, 1.0, 0), Fov: 46, Roll: -2 } },
      { Name: 'HeadReveal', T0: 2.5, T1: 3.6, Ease: 'Sine',
        From: { Pos: V(-1.9, 3.2, -6.6), Look: 'Head', Fov: 44 }, To: { Pos: V(-1.5, 3.3, -6.2), Look: 'Head', Fov: 42, Roll: -3 } },
      { Name: 'Tilt', T0: 3.6, T1: 4.35, Ease: 'Sine',
        From: { Pos: V(-1.6, 3.0, -6.6), Look: F('Head', 0, 0.1, 0), Fov: 34, Roll: 3 }, To: { Pos: V(-1.45, 3.05, -6.4), Look: F('Head', 0, 0.1, 0), Fov: 32, Roll: 2 } },
      { Name: 'Inhale', T0: 4.35, T1: 4.7, Ease: 'Out',
        From: { Pos: V(-1.5, 1.7, -6.4), Look: 'Head', Fov: 42 }, To: { Pos: V(-1.4, 1.6, -6.7), Look: 'Head', Fov: 44 } },
      { Name: 'Roar', T0: 4.7, T1: 6.3, Ease: 'Out',
        From: { Pos: V(-1.0, 1.55, -6.3), Look: F('Head', 0, -0.15, -0.2), Fov: 50 }, To: { Pos: V(-0.85, 1.5, -6.1), Look: F('Head', 0, -0.15, -0.2), Fov: 54, Roll: 2 } },
      { Name: 'Hero', T0: 6.3, T1: 7.2, Ease: 'Sine', Blend: 0.6,
        From: { Pos: V(-2.6, 0.55, -6.8), Look: V(0, 2.4, -1.0), Fov: 48 }, To: { Pos: V(-3.0, 0.6, -7.6), Look: V(0, 2.4, -1.0), Fov: 50 } },
    ],
  },
  // Velociraptor — leap and screech
  Leap: {
    Normalized: false, Title: 3.65, DOF: true, Hold: 8,
    TimeRamps: [[0.8, 1.02, 0.45], [1.98, 2.3, 0.5]],
    Shots: [
      { Name: 'Wide', T0: 0.0, T1: 0.75, Ease: 'Linear',
        From: { Pos: V(-1.6, 0.35, -5.2), Look: V(0, 1.9, 2.2), Fov: 46 }, To: { Pos: V(-1.4, 0.38, -4.8), Look: V(0, 1.9, 2.0), Fov: 44 } },
      { Name: 'Leap', T0: 0.75, T1: 1.2, Ease: 'Sine',
        From: { Pos: V(-3.2, 1.0, -3.0), Look: 'Head', Fov: 52 }, To: { Pos: V(-3.0, 1.4, -3.4), Look: 'Head', Fov: 50, Roll: -3 } },
      { Name: 'Landing', T0: 1.2, T1: 1.9, Ease: 'Out',
        From: { Pos: V(1.1, 0.15, -4.4), Look: F('Head', 0, -0.5, 0), Fov: 46, Roll: 3 }, To: { Pos: V(0.9, 0.18, -4.2), Look: F('Head', 0, -0.4, 0), Fov: 44, Roll: 2 } },
      { Name: 'Screech', T0: 1.9, T1: 3.0, Ease: 'Out',
        From: { Pos: V(-1.1, 1.6, -4.9), Look: F('Head', 0, -0.1, -0.25), Fov: 46, Roll: -4 }, To: { Pos: V(-0.95, 1.55, -4.7), Look: F('Head', 0, -0.1, -0.25), Fov: 50, Roll: 3 } },
      { Name: 'TailWhip', T0: 3.0, T1: 3.6, Ease: 'Sine', Blend: 0.3,
        From: { Pos: V(3.4, 1.8, -2.9), Look: 'Head', Fov: 46 }, To: { Pos: V(3.2, 1.75, -2.6), Look: 'Head', Fov: 48 } },
      { Name: 'Hero', T0: 3.6, T1: 4.4, Ease: 'Sine', Blend: 0.4,
        From: { Pos: V(-1.9, 0.6, -5.0), Look: V(0, 2.4, -0.4), Fov: 50 }, To: { Pos: V(-2.2, 0.65, -5.6), Look: V(0, 2.4, -0.4), Fov: 52 } },
    ],
  },
  // Generic lists are relative to the head's starting position (HeadStart), in CameraScale units,
  // so they frame any body plan: theropod, quadruped, sauropod or swimmer.
  Roar: {
    Normalized: true, Title: false, DOF: true,
    TimeRamps: [[0.3, 0.42, 0.45]],
    Shots: [
      { Name: 'Approach', T0: 0.0, T1: 0.28, Ease: 'Sine',
        From: { Pos: F('HeadStart', -2.6, -1.3, -4.9), Look: 'Head', Fov: 48 }, To: { Pos: F('HeadStart', -2.0, -1.1, -4.3), Look: 'Head', Fov: 46 } },
      { Name: 'Roar', T0: 0.28, T1: 0.8, Ease: 'Out',
        From: { Pos: F('HeadStart', -1.0, -1.0, -3.6), Look: F('Head', 0, -0.15, 0), Fov: 48 }, To: { Pos: F('HeadStart', -0.85, -1.05, -3.35), Look: F('Head', 0, -0.15, 0), Fov: 52, Roll: 2 } },
      { Name: 'Release', T0: 0.8, T1: 1.0, Ease: 'Sine', Blend: 0.25,
        From: { Pos: F('HeadStart', -2.4, -1.5, -5.1), Look: 'Head', Fov: 50 }, To: { Pos: F('HeadStart', -2.8, -1.6, -5.7), Look: 'Head', Fov: 52 } },
    ],
  },
  Attack: {
    Normalized: true, Title: false, DOF: true,
    TimeRamps: [[0.44, 0.5, 0.4]],
    Shots: [
      { Name: 'Windup', T0: 0.0, T1: 0.4, Ease: 'Sine',
        From: { Pos: F('HeadStart', -5.5, -1.7, -1.0), Look: 'Head', Fov: 48 }, To: { Pos: F('HeadStart', -5.2, -1.7, -1.4), Look: 'Head', Fov: 46 } },
      { Name: 'Snap', T0: 0.4, T1: 0.75, Ease: 'Out',
        From: { Pos: F('HeadStart', -2.4, -2.1, -4.0), Look: 'Head', Fov: 52, Roll: -3 }, To: { Pos: F('HeadStart', -2.2, -2.1, -4.4), Look: 'Head', Fov: 54, Roll: -2 } },
      { Name: 'Recover', T0: 0.75, T1: 1.0, Ease: 'Sine', Blend: 0.3,
        From: { Pos: F('HeadStart', -4.6, -1.5, -2.4), Look: 'Head', Fov: 50 }, To: { Pos: F('HeadStart', -4.9, -1.5, -2.7), Look: 'Head', Fov: 50 } },
    ],
  },
  Chase: {
    Normalized: true, Title: false, DOF: false, Handheld: 0.7,
    TimeRamps: [[0.8, 0.86, 0.4]],
    Shots: [
      { Name: 'Pursuit', T0: 0.0, T1: 0.6, Ease: 'Linear',
        From: { Pos: F('Head', -1.5, -0.3, -5.5), Look: 'Head', Fov: 60 }, To: { Pos: F('Head', -1.2, -0.35, -4.8), Look: 'Head', Fov: 62 } },
      { Name: 'LowRunner', T0: 0.6, T1: 0.8, Ease: 'Linear',
        From: { Pos: F('Head', 0.9, -2.2, -4.2), Look: 'Head', Fov: 64, Roll: 4 }, To: { Pos: F('Head', 0.8, -2.1, -3.8), Look: 'Head', Fov: 64, Roll: 3 } },
      { Name: 'Bite', T0: 0.8, T1: 1.0, Ease: 'Out',
        From: { Pos: F('Head', -0.6, 0, -3.2), Look: 'Head', Fov: 56 }, To: { Pos: F('Head', -0.9, 0.1, -3.8), Look: 'Head', Fov: 56 } },
    ],
  },
};
