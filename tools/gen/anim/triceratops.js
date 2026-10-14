// Triceratops — stubborn, territorial. Heavy quadruped; signature: THE CHARGE (smashes a crate stack).
const { W } = require('./util.js');
const HEAD_LOW = { Neck: [-0.28], Head: [-0.26], Torso: [-0.06] };
module.exports = {
  Signature: 'TheCharge', Intro: 'TheCharge', IntroShots: 'Charge', Chase: 'Chase', Special: 'Graze',
  CycleOrder: ['Walk', 'Run', 'Graze', 'LookAround', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 2.0,
  Gait: {
    Type: 'Quadruped', Scale: 1.6, Neck: ['Neck'], Tail: ['Tail1', 'Tail2', 'Tail3'],
    Idle: { Breath: 0.28, BreathAmp: 1.1, Sway: 0.08, Look: 0.1, JawIdle: 0.02 },
    Walk: { Freq: 0.8, Stride: 0.3, Knee: 0.45, Bob: 0.12, Roll: 0.05, Yaw: 0.04, Lean: 0, TailSway: 0.12, HeadBob: 0.06 },
    Run: { Freq: 1.6, Stride: 0.34, Knee: 0.55, Bob: 0.25, Roll: 0.04, Yaw: 0.03, Lean: 0.05, TailSway: 0.08, HeadBob: 0.1 },
  },
  Actions: {
    // a deep, head-tossing bellow
    Roar: {
      Duration: 2.6, Suppress: 0.9,
      Keys: [
        [0.4, W(HEAD_LOW, { Jaw: [-0.1], Pelvis: [0, 0, 0, 0, -0.1, 0.2] }), 'Sine'],
        [0.8, { Neck: [0.16], Head: [0.2], Jaw: [-0.55], Torso: [0.05], Pelvis: [0, 0, 0, 0, 0.05, -0.2], '~FrontUpper': [-0.1] }, 'Back'],
        [1.8, { Neck: [0.17], Head: [0.21], Jaw: [-0.6], Torso: [0.06] }, 'Linear'],
      ],
      Shake: [['Head', 0.8, 1.8, 0.05, 9, 3], ['Jaw', 0.8, 1.8, 0.04, 16, 1]],
      Events: [[0.8, 'Roar', { Scale: 0.9 }], [0.82, 'CameraShake', 0.45]],
    },
    // horn jab: lowers and stabs upward
    Attack: {
      Duration: 1.6, Suppress: 0.95,
      Keys: [
        [0.4, W(HEAD_LOW, { Neck: [-0.38], Head: [-0.32], Pelvis: [0, 0, 0, 0, -0.1, 0.6] }), 'Sine'],
        [0.62, { Neck: [0.05], Head: [0.28], Torso: [0.05], Pelvis: [0, 0, 0, 0, 0.15, -1.4], '~FrontUpper': [0.3] }, 'Snap'],
        [1.0, { Neck: [0.1], Head: [0.2, 0.15, 0.1], Pelvis: [0, 0, 0, 0, 0, -0.8] }, 'Sine'],
      ],
      Events: [[0.62, 'Bite', { Scale: 1.0 }], [0.62, 'Impact', { At: 'VFX_Horn', Scale: 0.8 }]],
    },
    Stunned: {
      Duration: 2.6, Suppress: 0.9,
      Keys: [
        [0.3, { Pelvis: [0, 0.1, 0.1, 0, -0.1, 0.8], Neck: [0.04], Head: [0.04, 0.08, 0.14], '~HindShin': [-0.2] }, 'Out'],
        [0.8, { Pelvis: [0, -0.06, -0.08, 0, -0.35, 0.6], Neck: [-0.2], Head: [-0.15, -0.1, -0.2], '~FrontLower': [-0.35], '~HindShin': [-0.35] }, 'Sine'],
        [2.1, { Pelvis: [0, 0, 0.03, 0, -0.25, 0.5], Neck: [-0.15], Head: [-0.1, 0, 0.12], '~FrontLower': [-0.25] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.6, T1: 2.2, Rate: 5, Head: [0.08, 0.1], Neck: 0.05, Roll: 0.04 },
      Events: [[0.05, 'Stunned', { Scale: 1.0 }], [0.1, 'CameraShake', 0.35]],
    },
    LookAround: {
      Duration: 3.6, Suppress: 0.6,
      Keys: [
        [0.7, { Neck: [0.12, 0.16], Head: [0.1, 0.12, 0.06], Torso: [0, 0.08] }, 'Sine'],
        [1.4, { Neck: [0.12, 0.18], Head: [0.14, 0.13, 0.04], Torso: [0, 0.09] }, 'Linear'],
        [2.2, { Neck: [0.1, -0.16], Head: [0.08, -0.12, -0.06], Torso: [0, -0.08], Tail2: [0, 0.15] }, 'Sine'],
        [2.9, { Neck: [0.1, -0.18], Head: [0.12, -0.13, -0.04], Torso: [0, -0.09], Tail2: [0, 0.15] }, 'Linear'],
      ],
      Events: [[1.5, 'Sniff']],
    },
    // munching ferns: head down, jaw chews
    Graze: {
      Duration: 4.0, Suppress: 0.85,
      Keys: [
        [0.7, { Neck: [-0.45], Head: [-0.35], Torso: [-0.06], '~FrontLower': [-0.12], Pelvis: [0, 0, 0, 0, -0.1, 0] }, 'Sine'],
        [3.3, { Neck: [-0.45], Head: [-0.32], Torso: [-0.06], '~FrontLower': [-0.12], Pelvis: [0, 0, 0, 0, -0.1, 0] }, 'Linear'],
      ],
      Shake: [['Jaw', 0.9, 3.2, 0.12, 2.2, 1], ['Head', 0.9, 3.2, 0.04, 1.1, 2]],
      Events: [[0.8, 'Sniff']],
    },
    Chase: {
      Duration: 3.4, Suppress: 1, Gait: [[0, 2.7, 'Run', 1]],
      Keys: [
        [0.3, HEAD_LOW, 'Sine'],
        [2.5, W(HEAD_LOW, { Pelvis: [0, 0, 0, 0, 0, -6.5] }), 'Linear'],
        [2.75, { Neck: [0.05], Head: [0.28], Pelvis: [0, 0, 0, 0, 0.1, -7.2] }, 'Snap'],
        [3.1, { Pelvis: [0, 0, 0, 0, 0, -7.2] }, 'Sine'],
      ],
      Events: [[0.1, 'Charge', 2.6], [2.75, 'Impact', { At: 'VFX_Horn', Scale: 1.0 }], [2.76, 'CameraShake', 0.6]],
    },
    // SIGNATURE: scrape, lower the horns, charge through the crate stack, toss the head and bellow
    TheCharge: {
      Duration: 6.4, Suppress: 1, FadeIn: 0.2, FadeOut: 0.01, HoldEnd: true, CommitRoot: true,
      Gait: [[1.9, 2.95, 'Run', 1, 1.15]],
      Keys: [
        [0.25, W(HEAD_LOW, { RightFrontUpper: [0.25], RightFrontLower: [-0.5], RightFrontFoot: [0.3] }), 'Sine'],
        [0.5, W(HEAD_LOW, { RightFrontUpper: [-0.35], RightFrontLower: [-0.1], RightFrontFoot: [-0.1] }), 'In'],
        [0.75, W(HEAD_LOW, { RightFrontUpper: [0.25], RightFrontLower: [-0.5], RightFrontFoot: [0.3] }), 'Sine'],
        [1.0, W(HEAD_LOW, { RightFrontUpper: [-0.35], RightFrontLower: [-0.1], RightFrontFoot: [-0.1] }), 'In'],
        [1.25, W(HEAD_LOW, { RightFrontUpper: [0.2], RightFrontLower: [-0.45] }), 'Sine'],
        [1.85, { Neck: [-0.42], Head: [-0.35], Torso: [-0.08], Pelvis: [0, 0, 0, 0, -0.25, 0.9], '~HindShin': [-0.3], '~HindThigh': [0.15] }, 'Sine'],
        [2.95, { Neck: [-0.4], Head: [-0.32], Torso: [-0.06], Pelvis: [0, 0, 0, 0, -0.05, -7.0] }, 'In'],
        [3.25, { Neck: [0.12], Head: [0.3], Torso: [0.08], Pelvis: [0, 0, 0, 0, 0.25, -7.6], '~FrontUpper': [0.35], '~FrontLower': [-0.3] }, 'Back'],
        [3.9, { Neck: [0.0], Head: [0.05], Pelvis: [0, 0, 0, 0, 0, -7.6] }, 'Sine'],
        [4.4, { Neck: [0.18], Head: [0.2], Jaw: [-0.6], Pelvis: [0, 0, 0, 0, 0.05, -7.6] }, 'Back'],
        [5.6, { Neck: [0.19], Head: [0.21], Jaw: [-0.62], Pelvis: [0, 0, 0, 0, 0.05, -7.6] }, 'Linear'],
        [6.4, { Pelvis: [0, 0, 0, 0, 0, -7.6] }, 'Sine'],
      ],
      Shake: [['Head', 4.4, 5.6, 0.05, 9, 3], ['Jaw', 4.4, 5.6, 0.04, 16, 1]],
      Events: [
        [0.5, 'Scrape', { At: 'VFX_RightFrontFoot' }], [1.0, 'Scrape', { At: 'VFX_RightFrontFoot' }], [1.3, 'Sniff'],
        [1.9, 'Charge', 1.3], [2.0, 'CameraShake', 0.3], [2.55, 'BreakProp', { Prop: 'Crates', Power: 1.4, At: 'VFX_Horn' }],
        [2.56, 'Impact', { At: 'VFX_Horn', Scale: 1.3 }], [2.57, 'CameraShake', 1.0], [4.4, 'Roar', { Scale: 1.0 }], [4.42, 'CameraShake', 0.5],
      ],
    },
  },
};
