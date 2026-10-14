// Sarcosuchus — patient, ancient, lurking. Sprawling quadruped that swims. Signature: LOG THAT ISN'T (floats like a
// drifting log with only its eyes up... the eyes open, the jaws burst up and SNAP, a death roll, then the hiss).
const { W } = require('./util.js');

// every joint the signature touches, at rest: wrapping each key in K() keeps joints from drifting between far keys
const BASE = { Pelvis: [0], Torso: [0], Neck: [0], Head: [0], Jaw: [0], Tail1: [0], Tail2: [0], Tail3: [0], Tail4: [0], Tail5: [0], Tail6: [0],
  '~HindThigh': [0], '~HindShin': [0], '~HindFoot': [0], '~FrontUpper': [0], '~FrontLower': [0], '~FrontFoot': [0] };
const K = (...p) => W(BASE, ...p);
// floating low like a log: body awash, legs trailing back and splayed, head level so eyes + bulla sit at the surface
const LEGS_FLOAT = { '~HindThigh': [-0.6, 0, 0.8], '~HindShin': [0.45], '~HindFoot': [0.5], '~FrontUpper': [-0.7, 0, 0.8], '~FrontLower': [0.45], '~FrontFoot': [0.5] };
const FLOAT = K(LEGS_FLOAT, { Pelvis: [0, 0, 0, 0, -0.85, 0], Neck: [0.04], Head: [0.06], Jaw: [0.02], Tail1: [0.03], Tail2: [0.02] });
const fl = (px, pz, o = {}) => W(FLOAT, { Pelvis: [o.rx || 0, o.ry || 0, o.rz || 0, px, -0.85 + (o.py || 0), pz] }, o.extra || {});
// a pose with the pelvis rolled about its long axis by rz (the death roll), jaws clamped, tail curled
const ROLLP = (rz, pz, py = -0.55) => K(LEGS_FLOAT, { Pelvis: [0, 0, rz, 0, py, pz], Neck: [0, 0.12], Head: [-0.05, 0.1], Jaw: [0.03], Tail1: [0, -0.35], Tail2: [0, -0.4], Tail3: [0, -0.35], Tail4: [0, -0.2] });
// two full rolls from t0 over dur: each half-roll lands on +-pi (the same orientation), so the joint never unwinds
function rolls(t0, dur, pz0, pz1, n = 2) {
  const keys = [];
  const h = dur / (n * 2);
  const zAt = (k) => pz0 + (pz1 - pz0) * (k / (n * 2));
  for (let i = 0; i < n; i++) {
    const a = t0 + i * 2 * h;
    keys.push([a + h, ROLLP(Math.PI, zAt(i * 2 + 1)), 'Linear']);
    keys.push([a + h + 0.001, ROLLP(-Math.PI, zAt(i * 2 + 1)), 'Linear']);
    keys.push([a + 2 * h, ROLLP(0, zAt(i * 2 + 2)), 'Linear']);
  }
  return keys;
}
const HISS = K({ Pelvis: [0.08, 0, 0, 0, -0.3, -0.4], Torso: [0.05], Neck: [0.18], Head: [0.12], Jaw: [-0.78], Tail1: [0.05, 0.15], Tail2: [0, 0.2] });
const BELLOW = { Pelvis: [0, 0, 0, 0, -0.15, 0], Torso: [0.05], Neck: [0.3], Head: [0.26], Jaw: [-0.32], Tail1: [-0.2], Tail2: [-0.18], Tail3: [-0.1], '~FrontUpper': [0.06], '~HindThigh': [-0.04] };

module.exports = {
  Signature: 'LogAmbush', Intro: 'LogAmbush', IntroShots: 'SarcoLog', Chase: 'Chase', Special: 'DeathRoll',
  CycleOrder: ['Walk', 'Run', 'DeathRoll', 'LookAround', 'JawTrap', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 2.2,
  Gait: {
    Type: 'Quadruped', Scale: 1.2, Neck: ['Neck'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5', 'Tail6'],
    Idle: { Breath: 0.18, BreathAmp: 0.6, Sway: 0.04, Look: 0.08, JawIdle: 0.02 },
    // the high walk: belly up off the mud, body and tail snaking side to side
    Walk: { Freq: 0.55, Stride: 0.3, Knee: 0.34, Bob: 0.05, Roll: 0.05, Yaw: 0.12, Lean: 0, TailSway: 0.2, HeadBob: 0.02 },
    Run: { Freq: 1.0, Stride: 0.4, Knee: 0.36, Bob: 0.09, Roll: 0.04, Yaw: 0.1, Lean: 0.02, TailSway: 0.16, HeadBob: 0.03 },
  },
  Actions: {
    // the bellow: head and tail lift into an arch, the back trembles and the water dances on its scutes
    Roar: {
      Duration: 3.0, Suppress: 0.9,
      Keys: [[0.6, W(BELLOW, { Jaw: [-0.1] }), 'Sine'], [0.95, BELLOW, 'Back'], [2.3, W(BELLOW, { Neck: [0.32], Head: [0.28], Jaw: [-0.36] }), 'Linear']],
      Shake: [['Torso', 0.95, 2.3, 0.025, 16, 3], ['Head', 0.95, 2.3, 0.03, 12, 1], ['Jaw', 0.95, 2.3, 0.03, 18, 1]],
      Events: [[0.9, 'EyeGlow', 1.6], [0.95, 'Roar', { Scale: 1.1 }], [1.0, 'WaterDance', { Dur: 1.3 }], [0.97, 'CameraShake', 0.5]],
    },
    // sideways jaw slash
    Attack: {
      Duration: 1.5, Suppress: 0.95,
      Keys: [
        [0.4, { Neck: [0.2, -0.28], Head: [0.25, -0.2], Jaw: [-0.7], Pelvis: [0, 0.12, 0], Torso: [0, -0.1] }, 'Sine'],
        [0.6, { Neck: [0, 0.3], Head: [-0.05, 0.25], Jaw: [0.03], Pelvis: [0, -0.15, 0, 0, 0, -0.8], Torso: [0, 0.12] }, 'Snap'],
        [1.0, { Neck: [0, 0.1], Head: [0, 0.05], Pelvis: [0, -0.05, 0, 0, 0, -0.4] }, 'Sine'],
      ],
      Events: [[0.6, 'Bite', { Scale: 1.2 }], [0.62, 'CameraShake', 0.4]],
    },
    // TAKEDOWN: bubbles, the eyes sink... then it explodes off the bank
    BankLunge: {
      Duration: 2.4, Suppress: 1,
      Keys: [
        [0.8, K({ Pelvis: [-0.02, 0, 0, 0, -0.35, 0.4], Neck: [-0.05], Head: [-0.03], '~FrontUpper': [-0.2, 0, 0.55], '~HindThigh': [-0.15, 0, 0.5] }), 'Sine'],
        [1.0, K({ Pelvis: [-0.02, 0, 0, 0, -0.4, 0.6], Neck: [-0.06], Head: [-0.04], '~FrontUpper': [-0.25, 0, 0.6], '~HindThigh': [-0.2, 0, 0.55] }), 'Linear'],
        [1.28, K({ Pelvis: [0.12, 0, 0, 0, 0.45, -8.5], Torso: [0.08], Neck: [0.25], Head: [0.25], Jaw: [-0.95], Tail1: [-0.14], Tail2: [-0.06], '~FrontUpper': [0.7, 0, 0.3], '~HindThigh': [-0.5] }), 'Out'],
        [1.4, K({ Pelvis: [0.08, 0, 0, 0, 0, -9.2], Head: [-0.08], Jaw: [0.03], '~FrontUpper': [0.3] }), 'Snap'],
        [1.9, K({ Pelvis: [0, 0, 0, 0, 0, -8.6] }), 'Sine'],
      ],
      Events: [[0.1, 'Bubbles', { Dur: 0.9 }], [1.05, 'Splash', { At: 'VFX_Chest', Scale: 1.6 }], [1.4, 'Bite', { Scale: 1.6 }], [1.41, 'CameraShake', 0.7], [1.42, 'Splash', { At: 'VFX_Mouth', Scale: 1.2 }]],
    },
    // TAKEDOWN: the whole tail swings round in a wave that knocks you off your feet (into the water)
    TailWave: {
      Duration: 2.0, Suppress: 0.95,
      Keys: [
        [0.7, { Pelvis: [0, -0.35, 0.04], Torso: [0, 0.15], Neck: [0, 0.2], Tail1: [0, -0.35], Tail2: [0, -0.45], Tail3: [0, -0.45], Tail4: [0, -0.35], Tail5: [0, -0.25] }, 'Sine'],
        [1.0, { Pelvis: [0, 0.45, -0.04], Torso: [0, -0.15], Neck: [0, -0.1], Tail1: [0, 0.45], Tail2: [0, 0.6], Tail3: [0, 0.65], Tail4: [0, 0.55], Tail5: [0, 0.45], Tail6: [0, 0.3] }, 'Snap'],
        [1.5, { Pelvis: [0, 0.15, 0], Tail1: [0, 0.15], Tail2: [0, 0.2], Tail3: [0, 0.2], Tail4: [0, 0.1] }, 'Sine'],
      ],
      Events: [[0.75, 'TailSwing', 0.5], [0.98, 'TailWave', { Scale: 1.3 }], [1.0, 'CameraShake', 0.6]],
    },
    // TAKEDOWN: lies dead still with its jaws gaping... and snaps them shut when you pass
    JawTrap: {
      Duration: 3.2, Suppress: 1,
      Keys: [
        [0.5, K({ Pelvis: [0, 0, 0, 0, -0.3, 0], Neck: [0.06], Head: [0.5], Jaw: [-0.62], '~FrontUpper': [0, 0, 0.2], '~HindThigh': [0, 0, 0.15] }), 'Out'],
        [2.3, K({ Pelvis: [0, 0, 0, 0, -0.32, 0], Neck: [0.06], Head: [0.53], Jaw: [-0.66], '~FrontUpper': [0, 0, 0.2], '~HindThigh': [0, 0, 0.15] }), 'Linear'],
        [2.45, K({ Pelvis: [0.04, 0, 0, 0, -0.1, -1.6], Neck: [-0.02], Head: [-0.06], Jaw: [0.03] }), 'Snap'],
        [2.9, K({ Pelvis: [0, 0, 0, 0, 0, -1.2] }), 'Sine'],
      ],
      Shake: [['Jaw', 1.6, 2.3, 0.015, 9, 1]],
      Events: [[0.4, 'EyeGlow', 2.2], [2.45, 'Bite', { Scale: 1.5 }], [2.46, 'CameraShake', 0.6]],
    },
    // BUDDY / special: clamps on and death-rolls
    DeathRoll: {
      Duration: 3.4, Suppress: 1,
      Keys: [
        [0.35, K({ Pelvis: [0.1, 0, 0, 0, 0.1, 0.3], Neck: [0.2], Head: [0.25], Jaw: [-0.85] }), 'Sine'],
        [0.55, W(ROLLP(0, -2.4, -0.1), {}), 'Snap'],
        ...rolls(0.7, 1.7, -2.4, -2.0, 2).map(([t, p, e]) => [t, W(p, { Pelvis: [0, 0, p.Pelvis[2], 0, -0.1, p.Pelvis[5]] }), e]),
        [2.9, K({ Pelvis: [0, 0, 0, 0, 0, -1.6], Neck: [0.1], Head: [0.14], Jaw: [-0.35] }), 'Out'],
      ],
      Events: [[0.55, 'Bite', { Scale: 1.4 }], [0.56, 'CameraShake', 0.5], [0.8, 'RollSpray', { Dur: 1.6 }], [2.9, 'Hiss', { Scale: 0.8 }]],
    },
    // jaws gape up at you and it hisses (the reveal's beat; also a threat display)
    Hiss: {
      Duration: 2.6, Suppress: 0.95,
      Keys: [[0.35, K({ Pelvis: [0.05, 0, 0, 0, 0, 0], Neck: [0.14], Head: [0.14], Jaw: [-0.4] }), 'Out'], [0.6, W(HISS, { Pelvis: [0.08, 0, 0, 0, 0.05, -0.2] }), 'Back'], [1.9, W(HISS, { Pelvis: [0.08, 0, 0, 0, 0.05, -0.2], Jaw: [-0.82], Neck: [0.2] }), 'Linear']],
      Shake: [['Head', 0.6, 1.9, 0.025, 14, 1], ['Jaw', 0.6, 1.9, 0.035, 22, 1], ['Torso', 0.6, 1.9, 0.012, 16, 3]],
      Events: [[0.55, 'EyeGlow', 1.4], [0.6, 'Hiss', { Scale: 1.2 }], [0.62, 'CameraShake', 0.35]],
    },
    // waiting in the water: a log with eyes (loop this while it lurks)
    Lurk: {
      Duration: 4.0, Suppress: 0.9, FadeIn: 0.6,
      Keys: [[0, fl(0, 0), 'Linear'], [2.0, fl(0, 0, { rz: 0.025, py: 0.04 }), 'Sine'], [4.0, fl(0, 0), 'Sine']],
    },
    Stunned: {
      Duration: 2.8, Suppress: 0.9,
      Keys: [
        [0.3, { Pelvis: [0, 0.1, 0.16, 0, 0.25, 0.4], Neck: [0.2, 0.2], Head: [0.25, 0.2, 0.3], Jaw: [-0.45] }, 'Out'],
        [0.9, { Pelvis: [0, -0.05, 0.1, 0, -0.05, 0.3], Neck: [-0.1], Head: [-0.06, -0.15, -0.2], Jaw: [-0.12], '~FrontLower': [0.2] }, 'Sine'],
        [2.2, { Pelvis: [0, 0, 0.05, 0, -0.08, 0.2], Neck: [-0.06], Head: [-0.02, 0, 0.1], Jaw: [-0.08] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.7, T1: 2.4, Rate: 4.0, Head: [0.18, 0.14], Neck: 0.08, Roll: 0.05 },
      Events: [[0.05, 'Stunned', { Scale: 1.2 }], [0.1, 'CameraShake', 0.4]],
    },
    LookAround: {
      Duration: 4.0, Suppress: 0.6,
      Keys: [[0.9, { Neck: [0.05, 0.3], Head: [0.04, 0.22] }, 'Sine'], [1.7, { Neck: [0.05, 0.32], Head: [0.06, 0.24] }, 'Linear'], [2.6, { Neck: [0.04, -0.28], Head: [0.03, -0.22] }, 'Sine'], [3.4, { Neck: [0.05, -0.3], Head: [0.06, -0.24] }, 'Linear']],
      Events: [[1.8, 'Sniff'], [3.5, 'Sniff']],
    },
    // waits at the ford, then lunges at the rover as it splashes through
    Chase: {
      Duration: 3.6, Suppress: 1, Gait: [[0, 2.5, 'Run', 1]],
      Keys: [
        [2.3, K({ Pelvis: [0, 0, 0, 0, 0, -5] }), 'Linear'],
        [2.65, K({ Pelvis: [0.12, 0, 0, 0, 0.4, -7.5], Torso: [0.05], Neck: [0.25], Head: [0.25], Jaw: [-0.95], Tail1: [-0.14], Tail2: [-0.06], '~FrontUpper': [0.6] }), 'Out'],
        [2.8, K({ Pelvis: [0.05, 0, 0, 0, 0, -8.2], Neck: [-0.05], Head: [-0.06], Jaw: [0.03] }), 'Snap'],
        [3.2, K({ Pelvis: [0, 0, 0, 0, 0, -8.2] }), 'Sine'],
      ],
      Events: [[2.6, 'Splash', { At: 'VFX_Chest', Scale: 1.4 }], [2.8, 'Bite', { Scale: 1.5 }], [2.81, 'CameraShake', 0.6]],
    },
    // SIGNATURE: LOG THAT ISN'T. A log drifting with the others... its eyes open. Bubbles. The jaws burst up and
    // SNAP (slow-mo), it crashes down into a double death roll, then rears its head and hisses at the lens.
    LogAmbush: {
      Duration: 7.4, Suppress: 1, FadeIn: 0.01,
      Keys: [
        [0.0, fl(0, 3.2), 'Linear'],
        [1.0, fl(0, 2.9, { rz: 0.02, py: 0.03 }), 'Sine'],
        [1.95, fl(0, 2.6, { rz: -0.01 }), 'Sine'],
        // the eyes are open: it settles a hair lower, gathering
        [2.55, fl(0, 2.5, { py: -0.12, extra: { Neck: [0.01], Head: [0.0], '~FrontUpper': [-0.55, 0, 0.3] } }), 'Sine'],
        // BURST: the front half rears out of the water, jaws flung wide
        [2.85, K(LEGS_FLOAT, { Pelvis: [0.16, 0, 0, 0, 0.2, -0.6], Torso: [0.08], Neck: [0.18], Head: [0.14], Jaw: [-1.05], '~FrontUpper': [0.5, 0, 0.5], '~FrontLower': [-0.2] }), 'Out'],
        // SNAP
        [3.0, K(LEGS_FLOAT, { Pelvis: [0.18, 0, 0, 0, 0.3, -0.9], Torso: [0.08], Neck: [0.14], Head: [0.04], Jaw: [0.03], '~FrontUpper': [0.4, 0, 0.5] }), 'Snap'],
        // crash down, already twisting into the roll
        [3.4, ROLLP(-0.6, -0.9, -0.5), 'In'],
        [3.5, ROLLP(0, -0.9, -0.55), 'Sine'],
        ...rolls(3.5, 1.6, -0.9, -0.6, 2),
        // surfaces, shakes the water off its snout
        [5.45, W(FLOAT, { Pelvis: [0.05, 0, 0, 0, -0.55, -0.5], Neck: [0.12, 0.12], Head: [0.08, 0.12, 0.08] }), 'Out'],
        [5.75, W(FLOAT, { Pelvis: [0.06, 0, 0, 0, -0.5, -0.45], Neck: [0.14, -0.1], Head: [0.1, -0.12, -0.08] }), 'Sine'],
        // HISS
        [6.05, HISS, 'Back'],
        [6.95, W(HISS, { Jaw: [-0.82], Neck: [0.2] }), 'Linear'],
      ],
      Shake: [['Head', 6.05, 6.95, 0.025, 14, 1], ['Jaw', 6.05, 6.95, 0.035, 22, 1], ['Torso', 6.05, 6.95, 0.012, 16, 3]],
      Events: [
        [0.0, 'LidsShut', { Dur: 2.2 }], [0.05, 'LogDrift', { Dur: 7.4 }],
        [2.2, 'EyeRipple', { Scale: 1 }], [2.2, 'EyeGlow', 1.2], [2.32, 'Bubbles', { Dur: 0.4 }],
        [2.62, 'Splash', { At: 'VFX_Chest', Scale: 2.2 }], [2.65, 'Splash', { At: 'VFX_Head', Scale: 1.8 }], [2.68, 'LensSpray', { Scale: 1.4 }], [2.7, 'CameraShake', 0.7],
        [3.0, 'Bite', { Scale: 1.8 }], [3.01, 'CameraShake', 0.9],
        [3.38, 'Splash', { At: 'VFX_Chest', Scale: 2.6 }], [3.4, 'CameraShake', 0.8], [3.5, 'RollSpray', { Dur: 1.6 }],
        [3.9, 'Splash', { At: 'VFX_TailTip', Scale: 1.4 }], [4.3, 'Splash', { At: 'VFX_Chest', Scale: 1.6 }], [4.7, 'Splash', { At: 'VFX_TailTip', Scale: 1.4 }],
        [5.1, 'Splash', { At: 'VFX_Head', Scale: 1.6 }], [5.5, 'Splash', { At: 'VFX_Mouth', Scale: 0.8 }],
        [6.0, 'EyeGlow', 1.4], [6.05, 'Hiss', { Scale: 1.2 }], [6.07, 'CameraShake', 0.35],
      ],
    },
  },
};
