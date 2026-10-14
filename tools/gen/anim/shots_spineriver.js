// Spine River signature shot lists (Croc Creek). Studs: true = positions in studs in the creature's ground frame
// (origin under its RootPart; for a swimmer the ground frame sits on the water surface; -Z = facing, +X = its right).
// Verified in tools/preview/cine.html?file=out/cine_Sarcosuchus_SarcoLog.json
const V = (x, y, z) => ({ __v3: [x, y, z] });
const F = (target, x = 0, y = 0, z = 0) => ({ Follow: target, Offset: V(x, y, z) });
const shot = (Name, T0, T1, From, To, o = {}) => Object.assign({ Name, T0, T1, From, To, Ease: 'Sine' }, o);
const S = (Pos, Look, Fov, Roll) => ({ Pos, Look, Fov, Roll });

module.exports = {
  // LOG THAT ISN'T: the camera lies on the water among drifting logs. One of them has eyes. They open.
  // The jaws come straight up at the lens (slow-mo on the snap, spray on the glass, FOV punch), a double death
  // roll seen from above, then it surfaces right in front of us and hisses.
  SarcoLog: {
    Studs: true, Title: 6.2, Hold: 8, DOF: true, TimeRamps: [[2.7, 3.12, 0.28]],
    Shots: [
      shot('Logs', 0, 1.85, S(V(-10.5, 0.45, -14.5), V(0, 0.35, -4), 32), S(V(-9.8, 0.45, -13.6), V(0, 0.35, -4.5), 29), { Ease: 'Linear' }),
      shot('Eyes', 1.85, 2.62, S(F('Crest', -3.6, 0.2, -2.2), F('Crest', -0.9, -0.1, 0), 26), S(F('Crest', -3.2, 0.2, -1.9), F('Crest', -0.9, -0.1, 0), 22)),
      shot('Burst', 2.62, 3.3, S(V(-3.8, 0.45, -18.2), F('Head', 0, 0.8, -1.5), 60, -3), S(V(-3.4, 0.45, -17.5), F('Head', 0, 0.5, -1.5), 72, -6), { Ease: 'Out' }),
      shot('Roll', 3.3, 4.3, S(V(-9.5, 6.5, -14), F('Chest', 0, -0.5, 0), 50), S(V(-9.0, 6.0, -13), F('Chest', 0, -0.5, 0), 48)),
      shot('RollLow', 4.3, 5.2, S(V(10.5, 0.45, -5.0), F('Chest', 0, 1.4, 0), 44, -3), S(V(10.0, 0.45, -4.3), F('Chest', 0, 1.4, 0), 47, -4), { Ease: 'Linear' }),
      shot('Hiss', 5.2, 6.95, S(V(-7.8, 0.55, -21.2), F('Head', 0, 0.2, -2.6), 46), S(V(-7.1, 0.5, -20.2), F('Head', 0, 0.2, -2.6), 51, 2)),
      shot('Hero', 6.95, 7.4, S(V(-6.0, 0.5, -16.8), F('Head', 0, -0.3, -2.2), 40), S(V(-6.5, 0.55, -17.5), F('Head', 0, -0.3, -2.2), 42), { Blend: 0.45 }),
    ],
  },
};
