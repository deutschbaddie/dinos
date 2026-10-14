// Stegosaurus — calm until threatened. Signature: TAIL SWEEP (smashes a fallen log).
const { W } = require('./util.js');
module.exports = {
  Signature: 'TailSweep', Intro: 'TailSweep', IntroShots: 'Sweep', Chase: 'Chase', Special: 'Graze',
  CycleOrder: ['Walk', 'Run', 'Graze', 'LookAround', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 2.2,
  Gait: {
    Type: 'Quadruped', Scale: 1.7, Neck: ['Neck'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4'],
    Idle: { Breath: 0.22, BreathAmp: 1.0, Sway: 0.07, Look: 0.15, JawIdle: 0.015 },
    Walk: { Freq: 0.7, Stride: 0.28, Knee: 0.45, Bob: 0.1, Roll: 0.05, Yaw: 0.03, Lean: 0, TailSway: 0.16, HeadBob: 0.05 },
    Run: { Freq: 1.25, Stride: 0.32, Knee: 0.6, Bob: 0.2, Roll: 0.04, Yaw: 0.03, Lean: 0.03, TailSway: 0.1, HeadBob: 0.08 },
  },
  Actions: {
    // a low hooting bellow with the plates shivering
    Roar: {
      Duration: 2.4, Suppress: 0.85,
      Keys: [
        [0.5, { Neck: [0.3], Head: [0.25], Jaw: [-0.45], Tail1: [-0.1], Tail2: [-0.1] }, 'Back'],
        [1.7, { Neck: [0.32], Head: [0.28], Jaw: [-0.48], Tail1: [-0.12], Tail2: [-0.1] }, 'Linear'],
      ],
      Shake: [['Torso', 0.5, 1.7, 0.02, 14, 3], ['Head', 0.5, 1.7, 0.04, 8, 3]],
      Events: [[0.5, 'Call', { At: 'VFX_Mouth', Scale: 1.0, Color: [255, 210, 160] }], [0.52, 'CameraShake', 0.3]],
    },
    // quick sideways tail jab
    Attack: {
      Duration: 1.7, Suppress: 0.95,
      Keys: [
        [0.45, { Pelvis: [0, -0.25, 0], Tail1: [-0.15, -0.3], Tail2: [-0.1, -0.35], Tail3: [0, -0.3], Tail4: [0, -0.25], Neck: [0, 0.25] }, 'Sine'],
        [0.7, { Pelvis: [0, 0.3, 0], Tail1: [-0.1, 0.4], Tail2: [-0.05, 0.45], Tail3: [0, 0.5], Tail4: [0, 0.45], Neck: [0, -0.15] }, 'Snap'],
        [1.1, { Pelvis: [0, 0.1, 0], Tail1: [0, 0.1], Tail2: [0, 0.1] }, 'Sine'],
      ],
      Events: [[0.55, 'TailSwing', 0.6], [0.72, 'Impact', { At: 'VFX_TailTip', Scale: 0.8 }]],
    },
    Stunned: {
      Duration: 2.6, Suppress: 0.9,
      Keys: [
        [0.3, { Pelvis: [0, 0.1, 0.12, 0, -0.1, 0.6], Neck: [0.2], Head: [0.25, 0, 0.3] }, 'Out'],
        [0.8, { Pelvis: [0, 0, -0.08, 0, -0.3, 0.4], Neck: [-0.25], Head: [-0.2, 0, -0.25], '~FrontLower': [-0.3] }, 'Sine'],
        [2.1, { Pelvis: [0, 0, 0.04, 0, -0.2, 0.3], Neck: [-0.2], Head: [-0.1, 0, 0.15] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.6, T1: 2.2, Rate: 5, Head: [0.2, 0.16], Neck: 0.1, Roll: 0.04 },
      Events: [[0.05, 'Stunned', { Scale: 0.8 }], [0.1, 'CameraShake', 0.3]],
    },
    LookAround: {
      Duration: 3.6, Suppress: 0.6,
      Keys: [
        [0.8, { Neck: [0.15, 0.4], Head: [0.1, 0.35, 0.1] }, 'Sine'],
        [1.5, { Neck: [0.15, 0.42], Head: [0.12, 0.35, 0.05] }, 'Linear'],
        [2.3, { Neck: [0.12, -0.4], Head: [0.1, -0.35, -0.1], Tail3: [0, 0.2] }, 'Sine'],
        [3.0, { Neck: [0.12, -0.42], Head: [0.1, -0.35, -0.05], Tail3: [0, 0.2] }, 'Linear'],
      ],
    },
    Graze: {
      Duration: 4.0, Suppress: 0.85,
      Keys: [
        [0.7, { Neck: [-0.35], Head: [-0.3], '~FrontLower': [-0.1] }, 'Sine'],
        [3.3, { Neck: [-0.35], Head: [-0.28], '~FrontLower': [-0.1] }, 'Linear'],
      ],
      Shake: [['Jaw', 0.9, 3.2, 0.1, 2.4, 1]],
    },
    Chase: {
      Duration: 3.2, Suppress: 1, Gait: [[0, 2.6, 'Run', 1]],
      Keys: [[2.4, { Pelvis: [0, 0, 0, 0, 0, -5.5], Neck: [0.05] }, 'Linear'], [2.9, { Pelvis: [0, 0, 0, 0, 0, -5.8], Tail1: [0, 0.4], Tail2: [0, 0.5] }, 'Snap']],
      Events: [[0.1, 'Charge', 2.4], [2.8, 'TailSwing', 0.5]],
    },
    // SIGNATURE: senses danger, plates flush, swivels and sweeps the spiked tail through a log
    TailSweep: {
      Duration: 5.6, Suppress: 1, FadeIn: 0.25,
      Keys: [
        [0.7, { Neck: [0.15, 0.35], Head: [0.12, 0.4, 0.1] }, 'Sine'],
        [1.3, { Neck: [0.05, 0.25], Head: [0, 0.25], Pelvis: [0, -0.25, 0, -0.3, -0.15, 0], Torso: [0, 0.15], '~HindShin': [-0.15] }, 'Sine'],
        [2.0, { Neck: [-0.05, -0.2], Head: [-0.05, -0.15], Pelvis: [0, -0.45, 0, -0.5, -0.25, 0], Torso: [0, 0.25], Tail1: [-0.2, -0.35], Tail2: [-0.18, -0.4], Tail3: [-0.12, -0.45], Tail4: [-0.1, -0.4] }, 'Back'],
        [2.45, { Neck: [-0.05, -0.25], Pelvis: [0, 0.35, 0, 0.4, -0.2, 0], Torso: [0, -0.15], Tail1: [0, 0.5], Tail2: [0.05, 0.6], Tail3: [0.05, 0.65], Tail4: [0, 0.6] }, 'Snap'],
        [3.0, { Pelvis: [0, 0.3, 0, 0.3, -0.15, 0], Tail1: [0, 0.35], Tail2: [0, 0.45], Tail3: [0, 0.4], Tail4: [0, 0.35] }, 'Out'],
        [3.8, { Neck: [0.3], Head: [0.25], Jaw: [-0.45], Tail1: [-0.1], Tail2: [-0.08] }, 'Back'],
        [4.9, { Neck: [0.32], Head: [0.28], Jaw: [-0.48], Tail1: [-0.12], Tail2: [-0.1] }, 'Linear'],
      ],
      Shake: [['Torso', 0.9, 2.0, 0.02, 16, 3], ['Torso', 3.8, 4.9, 0.02, 14, 3]],
      Events: [
        [0.75, 'Sniff'], [1.2, 'Flush', 3.2], [1.95, 'TailSwing', 1.3], [2.38, 'BreakProp', { Prop: 'Log', Power: 1.3, At: 'VFX_TailTip' }],
        [2.4, 'Impact', { At: 'VFX_TailTip', Scale: 1.1 }], [2.41, 'CameraShake', 0.8], [3.8, 'Call', { At: 'VFX_Mouth', Scale: 1.0 }],
      ],
    },
  },
};
