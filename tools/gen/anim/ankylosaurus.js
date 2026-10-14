// Ankylosaurus — defensive, slow, unstoppable. Signature: CLUB SMASH (shatters a boulder).
const { W } = require('./util.js');
const BRACE = { Pelvis: [0, 0, 0, 0, -0.25, 0], '~HindShin': [-0.25], '~HindThigh': [0.12], '~FrontLower': [-0.2], Neck: [-0.15], Head: [-0.1] };
module.exports = {
  Signature: 'ClubSmash', Intro: 'ClubSmash', IntroShots: 'Smash', Chase: 'Chase', Special: 'Hunker',
  CycleOrder: ['Walk', 'Run', 'Hunker', 'LookAround', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 1.7,
  Gait: {
    Type: 'Quadruped', Scale: 1.2, Neck: ['Neck'], Tail: ['Tail1', 'Tail2', 'Tail3'],
    Idle: { Breath: 0.25, BreathAmp: 0.9, Sway: 0.05, Look: 0.12, JawIdle: 0.015 },
    Walk: { Freq: 0.75, Stride: 0.26, Knee: 0.4, Bob: 0.08, Roll: 0.07, Yaw: 0.05, Lean: 0, TailSway: 0.1, HeadBob: 0.04 },
    Run: { Freq: 1.3, Stride: 0.38, Knee: 0.6, Bob: 0.14, Roll: 0.06, Yaw: 0.04, Lean: 0.03, TailSway: 0.08, HeadBob: 0.06 },
  },
  Actions: {
    // gruff huffing grunt
    Roar: {
      Duration: 2.2, Suppress: 0.85,
      Keys: [[0.5, { Neck: [0.25], Head: [0.25], Jaw: [-0.5], Torso: [0.04], Tail1: [0, 0.15] }, 'Back'], [1.5, { Neck: [0.27], Head: [0.27], Jaw: [-0.52], Tail1: [0, -0.15] }, 'Linear']],
      Shake: [['Head', 0.5, 1.5, 0.05, 7, 3], ['Torso', 0.5, 1.5, 0.015, 12, 3]],
      Events: [[0.5, 'Roar', { Scale: 0.8 }], [0.52, 'CameraShake', 0.3]],
    },
    Attack: {
      Duration: 1.8, Suppress: 0.95,
      Keys: [
        [0.5, W(BRACE, { Pelvis: [0, -0.35, 0, 0, -0.25, 0], Tail1: [0, -0.4], Tail2: [0, -0.45], Tail3: [0, -0.4] }), 'Sine'],
        [0.78, W(BRACE, { Pelvis: [0, 0.4, 0, 0, -0.2, 0], Tail1: [0, 0.5], Tail2: [0, 0.6], Tail3: [0, 0.55] }), 'Snap'],
        [1.2, { Pelvis: [0, 0.1, 0], Tail1: [0, 0.15] }, 'Sine'],
      ],
      Events: [[0.6, 'TailSwing', 0.6], [0.8, 'Impact', { At: 'VFX_Club', Scale: 0.9 }]],
    },
    Stunned: {
      Duration: 2.6, Suppress: 0.9,
      Keys: [
        [0.3, { Pelvis: [0, 0, 0.18, 0, 0.1, 0.5], Neck: [0.2], Head: [0.2, 0, 0.3] }, 'Out'],
        [0.8, { Pelvis: [0, 0, -0.1, 0, -0.2, 0.3], Neck: [-0.2], Head: [-0.15, 0, -0.25] }, 'Sine'],
        [2.1, { Pelvis: [0, 0, 0.04, 0, -0.15, 0.2], Neck: [-0.15], Head: [-0.1, 0, 0.15] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.6, T1: 2.2, Rate: 4.5, Head: [0.2, 0.15], Neck: 0.1, Roll: 0.05 },
      Events: [[0.05, 'Stunned', { Scale: 0.8 }], [0.1, 'CameraShake', 0.3]],
    },
    LookAround: {
      Duration: 3.4, Suppress: 0.6,
      Keys: [[0.8, { Neck: [0.08, 0.35], Head: [0.05, 0.3, 0.1] }, 'Sine'], [1.5, { Neck: [0.1, 0.3], Head: [0.12, 0.2] }, 'Linear'], [2.3, { Neck: [0.08, -0.28], Head: [0.06, -0.2, -0.1] }, 'Sine'], [2.9, { Neck: [0.1, -0.3], Head: [0.12, -0.2] }, 'Linear']],
      Events: [[1.6, 'Sniff']],
    },
    // hunkers down flat behind its armour
    Hunker: {
      Duration: 3.0, Suppress: 0.95,
      Keys: [
        [0.5, { Pelvis: [0, 0, 0, 0, -0.55, 0], '~HindThigh': [0.3], '~HindShin': [-0.5], '~HindFoot': [0.22], '~FrontUpper': [0.28], '~FrontLower': [-0.5], '~FrontFoot': [0.22], Neck: [-0.25], Head: [-0.2], Tail1: [0.1] }, 'Out'],
        [2.4, { Pelvis: [0, 0, 0, 0, -0.55, 0], '~HindThigh': [0.3], '~HindShin': [-0.5], '~HindFoot': [0.22], '~FrontUpper': [0.28], '~FrontLower': [-0.5], '~FrontFoot': [0.22], Neck: [-0.25], Head: [-0.2], Tail1: [0.1, 0.3], Tail2: [0, 0.3] }, 'Linear'],
      ],
      Events: [[0.5, 'Land', { Scale: 0.6 }]],
    },
    Chase: {
      Duration: 3.0, Suppress: 1, Gait: [[0, 2.4, 'Run', 1]],
      Keys: [[2.2, { Pelvis: [0, 0, 0, 0, 0, -4.2] }, 'Linear'], [2.7, { Pelvis: [0, 0.45, 0, 0, 0, -4.4], Tail1: [0, 0.5], Tail2: [0, 0.6], Tail3: [0, 0.5] }, 'Snap']],
      Events: [[0.1, 'Charge', 2.2], [2.7, 'Impact', { At: 'VFX_Club', Scale: 0.9 }]],
    },
    // SIGNATURE: braces, wheels its body round and slams the club through a boulder, twice
    ClubSmash: {
      Duration: 6.0, Suppress: 1, FadeIn: 0.25,
      Keys: [
        [0.6, W(BRACE, { Neck: [0.05, -0.35], Head: [0, -0.3] }), 'Sine'],
        [1.3, W(BRACE, { Pelvis: [0, -0.4, 0.05, 0, -0.3, 0], Torso: [0, -0.15], Tail1: [-0.15, -0.45], Tail2: [-0.15, -0.5], Tail3: [-0.15, -0.5] }), 'Back'],
        [1.75, W(BRACE, { Pelvis: [0, 0.5, -0.05, 0, -0.25, 0], Torso: [0, 0.15], Tail1: [0.05, 0.55], Tail2: [0.1, 0.65], Tail3: [0.15, 0.6] }), 'Snap'],
        [2.4, W(BRACE, { Pelvis: [0, 0.3, 0, 0, -0.25, 0], Tail1: [0, 0.35], Tail2: [0, 0.4], Tail3: [0.05, 0.35] }), 'Out'],
        [3.0, W(BRACE, { Pelvis: [0, -0.2, 0, 0, -0.3, 0], Tail1: [-0.25, 0.2], Tail2: [-0.3, 0.25], Tail3: [-0.3, 0.25] }), 'Sine'],
        [3.35, W(BRACE, { Pelvis: [0, 0.35, 0, 0, -0.35, 0], Tail1: [0.15, 0.45], Tail2: [0.2, 0.5], Tail3: [0.3, 0.45] }), 'Snap'],
        [4.0, { Pelvis: [0, 0.15, 0, 0, -0.1, 0], Tail1: [0, 0.2] }, 'Sine'],
        [4.6, { Neck: [0.25], Head: [0.25], Jaw: [-0.5] }, 'Back'],
        [5.4, { Neck: [0.27], Head: [0.27], Jaw: [-0.5] }, 'Linear'],
      ],
      Shake: [['Head', 4.6, 5.4, 0.05, 7, 3]],
      Events: [
        [0.6, 'Sniff'], [1.4, 'TailSwing', 1.0], [1.72, 'BreakProp', { Prop: 'Boulder', Power: 1.2, At: 'VFX_Club' }], [1.73, 'Impact', { At: 'VFX_Club', Scale: 1.3 }],
        [1.74, 'CameraShake', 0.9], [3.1, 'TailSwing', 0.6], [3.35, 'Impact', { At: 'VFX_Club', Scale: 1.6 }], [3.36, 'CameraShake', 1.0], [4.6, 'Roar', { Scale: 0.9 }],
      ],
    },
  },
};
