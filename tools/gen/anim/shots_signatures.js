// Signature cutscene shot lists for the 10 new species. Studs: true = positions are in studs in the
// creature's ground frame (origin under its RootPart at rest, -Z = facing). Verified in tools/preview/cine.html.
const V = (x, y, z) => ({ __v3: [x, y, z] });
const F = (target, x = 0, y = 0, z = 0) => ({ Follow: target, Offset: V(x, y, z) });
const shot = (Name, T0, T1, From, To, o = {}) => Object.assign({ Name, T0, T1, From, To, Ease: 'Sine' }, o);
const S = (Pos, Look, Fov, Roll) => ({ Pos, Look, Fov, Roll });

module.exports = {
  Charge: {
    Studs: true, Title: 4.3, Hold: 8, DOF: true, Prop: 'Crates', TimeRamps: [[2.45, 2.78, 0.35]],
    Shots: [
      shot('Scrape', 0, 1.3, S(V(-5.8, 0.8, -11.5), F('Head', 0, -1.0, 0), 40), S(V(-5.3, 0.75, -10.8), F('Head', 0, -1.0, 0), 38)),
      shot('Glare', 1.3, 1.9, S(V(-3.6, 2.4, -9.4), 'Head', 36, -2), S(V(-3.4, 2.3, -9.0), 'Head', 34, -1)),
      shot('Charge', 1.9, 2.78, S(V(4.6, 0.8, -17.5), F('Head', 0, -0.5, 0), 48), S(V(4.9, 0.8, -17.0), F('Head', 0, -0.5, 0), 54, 3), { Ease: 'Linear' }),
      shot('Toss', 2.78, 3.9, S(V(-10.5, 2.4, -12.5), F('Head', 0, 0.5, 0), 44), S(V(-10.0, 2.4, -12.9), F('Head', 0, 0.5, 0), 42)),
      shot('Bellow', 3.9, 6.4, S(V(-7.0, 1.0, -20.5), F('Head', 0, -0.4, 0), 44), S(V(-7.6, 1.1, -21.4), F('Head', 0, -0.4, 0), 46), { Blend: 0.5 }),
    ],
  },
  Sweep: {
    Studs: true, Title: 4.0, Hold: 8, DOF: true, Prop: 'Log', TimeRamps: [[2.22, 2.62, 0.35]],
    Shots: [
      shot('Senses', 0, 1.2, S(V(-7.0, 2.8, -12.0), 'Head', 40), S(V(-6.5, 2.8, -11.4), 'Head', 38)),
      shot('Flush', 1.2, 2.0, S(V(-6.8, 7.6, 1.2), V(0, 6.2, 0.8), 44), S(V(-6.4, 7.4, 1.7), V(0, 6.2, 0.8), 42)),
      shot('Sweep', 2.0, 3.0, S(V(10.5, 0.9, 11.5), F('Prop', 0, 0.6, 0), 52), S(V(10.1, 0.9, 11.0), F('Prop', 0, 0.6, 0), 56, 3), { Ease: 'Linear' }),
      shot('Aftermath', 3.0, 3.8, S(V(-13, 3.0, 3.0), V(1, 3.0, 2.5), 48), S(V(-12.4, 3.0, 2.6), V(1, 3.0, 2.5), 47)),
      shot('Bellow', 3.8, 5.6, S(V(-6.0, 1.2, -13.0), F('Head', 0, 0.3, 0), 46), S(V(-6.5, 1.2, -13.8), F('Head', 0, 0.3, 0), 48), { Blend: 0.4 }),
    ],
  },
  Herd: {
    Studs: true, Title: 4.6, Hold: 8, DOF: true, TimeRamps: [[2.2, 2.45, 0.5]],
    Shots: [
      shot('Alert', 0, 1.3, S(V(-7.0, 1.4, -11.5), V(0, 4.5, 0), 46), S(V(-6.4, 1.4, -10.8), V(0, 4.5, 0), 45)),
      shot('Listen', 1.3, 2.2, S(V(-4.4, 6.6, -5.8), 'Head', 38), S(V(-4.1, 6.7, -5.4), 'Head', 36)),
      shot('Call', 2.2, 3.4, S(V(-4.6, 3.4, -10.6), F('Head', 0, 0.6, 1.2), 46, -3), S(V(-4.3, 3.3, -10.1), F('Head', 0, 0.6, 1.2), 50, 2)),
      shot('Answer', 3.4, 4.3, S(F('Herd', -2.8, 0.3, -3.4), 'Herd', 40), S(F('Herd', -2.5, 0.3, -3.1), 'Herd', 38)),
      shot('Chorus', 4.3, 6.4, S(V(-9.5, 2.5, -13.5), V(0, 4.8, 0), 46), S(V(-10.2, 2.6, -14.3), V(0, 4.8, 0), 48), { Blend: 0.5 }),
    ],
  },
  Smash: {
    Studs: true, Title: 4.6, Hold: 8, DOF: true, Prop: 'Boulder', TimeRamps: [[1.6, 1.95, 0.3], [3.28, 3.45, 0.4]],
    Shots: [
      shot('Brace', 0, 1.1, S(V(-2.6, 1.0, -9.8), 'Head', 42), S(V(-2.4, 1.0, -9.3), 'Head', 40)),
      shot('Smash', 1.1, 2.4, S(V(9.2, 1.8, 0.4), F('Prop', 0, 0.9, 0), 50), S(V(8.8, 1.7, 0.9), F('Prop', 0, 0.9, 0), 55, -3), { Ease: 'Linear' }),
      shot('Second', 2.4, 3.6, S(V(-6.5, 8.5, 10.5), V(2, 1.5, 5), 50), S(V(-6.0, 8.0, 10.0), V(2, 1.5, 5), 49)),
      shot('Grunt', 3.6, 6.0, S(V(-5.8, 0.7, -11.0), F('Head', 0, 0.2, 0), 46), S(V(-6.3, 0.7, -11.8), F('Head', 0, 0.2, 0), 48), { Blend: 0.4 }),
    ],
  },
  Ambush: {
    Studs: true, Title: 4.1, Hold: 8, DOF: true, TimeRamps: [[1.84, 2.12, 0.35]],
    Shots: [
      shot('Stillness', 0, 1.8, S(V(-1.4, 2.0, -22.0), V(0, 3.6, -8.0), 38), S(V(-1.2, 2.0, -21.2), V(0, 3.6, -8.0), 37), { Ease: 'Linear' }),
      shot('Burst', 1.8, 2.5, S(V(0.3, 5.4, -12.4), F('Head', 0, -0.4, 0), 58, -6), S(V(0.2, 5.2, -12.8), F('Head', 0, -0.4, 0), 64, -3), { Ease: 'Out' }),
      shot('Roar', 2.5, 4.1, S(V(-3.6, 2.5, -12.4), F('Head', 0, -0.3, 0), 46), S(V(-3.3, 2.4, -12.0), F('Head', 0, -0.3, 0), 50, 2)),
      shot('Hero', 4.1, 5.0, S(V(-4.2, 1.2, -19.0), V(0, 5.5, -3.0), 46), S(V(-4.6, 1.2, -19.8), V(0, 5.5, -3.0), 48), { Blend: 0.4 }),
    ],
  },
  Giant: {
    Studs: true, Title: 6.6, Hold: 8, DOF: true,
    Shots: [
      shot('Footfall', 0, 2.2, S(V(5.4, 0.4, -11.0), F('RightFrontFoot', 0, 1.5, 0), 50), S(V(5.2, 0.4, -10.4), F('RightFrontFoot', 0, 1.5, 0), 48), { Ease: 'Linear' }),
      shot('TiltUp', 2.2, 5.0, S(V(-9, 1.5, -17), V(0, 10, -3), 52), S(V(-10, 3.0, -19), 'Head', 56), { Ease: 'Sine' }),
      shot('Call', 5.0, 7.4, S(V(-13, 2.0, -27), F('Head', 0, -2, 0), 42, -2), S(V(-12.4, 2.0, -26.2), F('Head', 0, -2, 0), 44, 2)),
      shot('Majesty', 7.4, 8.4, S(V(-25, 4, -28), V(0, 14, -3), 50), S(V(-26, 4.2, -29.5), V(0, 14, -3), 51), { Blend: 0.6 }),
    ],
  },
  River: {
    Studs: true, Title: 5.7, Hold: 8, DOF: true, TimeRamps: [[1.76, 2.16, 0.35]],
    Shots: [
      shot('Fin', 0, 1.75, S(V(-2.2, 0.7, -15.4), V(0, 1.0, 0), 44), S(V(-2.0, 0.7, -14.8), V(0, 1.0, 0), 42), { Ease: 'Linear' }),
      shot('Erupt', 1.75, 2.6, S(V(-6.5, 1.6, -15.0), F('Head', 0, -1, 0), 54), S(V(-6.8, 1.6, -15.5), F('Head', 0, -1, 0), 58, 3), { Ease: 'Out' }),
      shot('Shake', 2.6, 3.5, S(V(-9.5, 5.0, -9.5), 'Head', 42), S(V(-9.0, 5.0, -9.2), 'Head', 41)),
      shot('Roar', 3.5, 5.7, S(V(-4.2, 2.4, -14.8), F('Head', 0, -0.4, 0), 48), S(V(-3.9, 2.3, -14.3), F('Head', 0, -0.4, 0), 52, 2)),
      shot('Hero', 5.7, 6.6, S(V(-10.0, 3.0, -15.6), V(0, 5.5, -3), 50), S(V(-10.6, 3.1, -16.2), V(0, 5.5, -3), 52), { Blend: 0.5 }),
    ],
  },
  Predator: {
    Studs: true, Title: 6.2, Hold: 8, DOF: true, TimeRamps: [[1.44, 1.82, 0.4]],
    Shots: [
      shot('Tremor', 0, 1.4, S(V(-3.0, 1.2, -18.5), V(0, 6, 9), 44), S(V(-2.7, 1.2, -17.8), V(0, 6, 9), 43), { Ease: 'Linear' }),
      shot('Breakthrough', 1.4, 2.4, S(V(10.5, 2.4, -9.5), 'Head', 48, 3), S(V(10.0, 2.5, -10.2), 'Head', 52, 1), { Ease: 'Out' }),
      shot('Approach', 2.4, 3.6, S(V(-2.6, 3.0, -23), F('Head', 0, -0.5, 0), 40), S(V(-2.4, 2.8, -22), F('Head', 0, -0.5, 0), 42)),
      shot('Lower', 3.6, 4.5, S(V(-1.8, 7.0, -17.2), F('Head', 0, -0.6, 0), 40), S(V(-1.6, 6.8, -16.8), F('Head', 0, -0.6, 0), 38)),
      shot('Roar', 4.5, 6.2, S(V(-4.4, 3.0, -20.2), F('Head', 0, -0.6, 0), 50), S(V(-4.1, 2.9, -19.6), F('Head', 0, -0.6, 0), 54, 2)),
      shot('Hero', 6.2, 7.0, S(V(-12.5, 2.0, -27), V(0, 8, -4), 48), S(V(-13.2, 2.1, -28), V(0, 8, -4), 50), { Blend: 0.5 }),
    ],
  },
  Breach: {
    Studs: true, Title: 5.3, Hold: 8, DOF: true, TimeRamps: [[2.35, 2.95, 0.3]],
    Shots: [
      shot('Shadow', 0, 1.9, S(V(-3.6, 2.2, -25), V(0, -1, -8), 46), S(V(-3.3, 2.1, -24), V(0, -1, -8), 45), { Ease: 'Linear' }),
      shot('Breach', 1.9, 3.4, S(V(-16.5, 1.4, -9), F('Head', 0, -3, 0), 60), S(V(-16.8, 1.4, -10), F('Head', 0, -3, 0), 64, 3), { Ease: 'Out' }),
      shot('Crash', 3.4, 4.6, S(V(-16.5, 4.0, -7), V(0, 1, -7), 52), S(V(-16.0, 4.0, -7.4), V(0, 1, -7), 51)),
      shot('Hero', 4.6, 6.6, S(V(-7.0, 1.2, -25), F('Head', 0, 0.3, 0), 44), S(V(-7.6, 1.2, -26), F('Head', 0, 0.3, 0), 46), { Blend: 0.6 }),
    ],
  },
  Containment: {
    Studs: true, Title: 8.0, Hold: 8, DOF: true, Prop: 'Gate', TimeRamps: [[4.45, 4.88, 0.3]],
    Shots: [
      shot('Alarm', 0, 1.6, S(V(-6.0, 2.0, -40), V(0, 8, -16), 46), S(V(-5.6, 2.0, -39), V(0, 8, -16), 45), { Ease: 'Linear' }),
      shot('Cracks', 1.6, 2.8, S(V(3.8, 9.0, -25), V(0, 11, -16), 42), S(V(3.4, 9.0, -24.4), V(0, 11, -16), 40)),
      shot('Claw', 2.8, 4.3, S(V(-6.5, 7.0, -25), F('RightClaw', 0, 0, 0), 44), S(V(-6.0, 7.0, -24.5), F('RightClaw', 0, 0, 0), 42)),
      shot('Breach', 4.3, 5.0, S(V(-3.0, 2.5, -34), F('Head', 0, -1, 0), 52), S(V(-3.3, 2.5, -34.6), F('Head', 0, -1, 0), 58, 3), { Ease: 'Out' }),
      shot('Advance', 5.0, 7.2, S(V(-9.5, 1.5, -41), F('Head', 0, -2, 0), 46), S(V(-8.5, 1.5, -39), F('Head', 0, -2, 0), 48)),
      shot('Roar', 7.2, 8.9, S(V(-6.5, 6.6, -35.5), F('Head', 0, -0.8, 0), 46), S(V(-6.1, 6.4, -35.0), F('Head', 0, -0.8, 0), 50, 2)),
      shot('Hero', 8.9, 9.4, S(V(-14.5, 2.5, -45), V(0, 10, -24), 48), S(V(-15, 2.6, -46), V(0, 10, -24), 49), { Blend: 0.4 }),
    ],
  },
};
