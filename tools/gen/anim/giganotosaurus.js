// Giganotosaurus — brutal, relentless. Signature: THE PREDATOR ARRIVES (smashes through the jungle wall).
const { W } = require('./util.js');
const ROAR = { Neck1: [-0.04], Neck2: [0.0], Head: [0.08], Jaw: [-0.8], Torso: [-0.02], Chest: [0, 0, 0, 0, -0.25, -0.3], Pelvis: [0, 0, 0, 0, -0.1, -0.8], '~Arm': [-0.45, 0, 0.35], '~Forearm': [-0.7], Tail1: [-0.15], Tail2: [-0.1] };
module.exports = {
  Signature: 'PredatorArrives', Intro: 'PredatorArrives', IntroShots: 'Predator', Chase: 'Chase', Special: 'Stalk',
  CycleOrder: ['Walk', 'Run', 'Stalk', 'LookAround', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 3.2,
  Gait: {
    Type: 'Biped', Scale: 3.0, Neck: ['Neck1', 'Neck2'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5', 'Tail6'],
    Idle: { Breath: 0.24, BreathAmp: 1.1, Sway: 0.08, Look: 0.28, Twitch: false, JawIdle: 0.06 },
    Walk: { Freq: 0.6, Stride: 0.38, Knee: 0.62, Bob: 0.12, Roll: 0.04, Yaw: 0.06, Lean: 0.06, TailSway: 0.1, HeadBob: 0.05 },
    Run: { Freq: 1.0, Stride: 0.5, Knee: 0.9, Bob: 0.2, Roll: 0.03, Yaw: 0.04, Lean: 0.18, TailSway: 0.06, HeadBob: 0.07 },
  },
  Actions: {
    Roar: {
      Duration: 3.2, Suppress: 0.92,
      Keys: [[0.5, { Neck1: [-0.12], Neck2: [-0.06], Head: [0], Pelvis: [0, 0, 0, 0, -0.25, 0.3] }, 'Sine'], [0.95, ROAR, 'Back'], [2.4, W(ROAR, { Jaw: [-0.78] }), 'Linear']],
      Shake: [['Head', 0.95, 2.4, 0.045, 12, 3], ['Jaw', 0.95, 2.4, 0.035, 18, 1], ['~Forearm', 1.0, 2.3, 0.18, 7, 1]],
      Events: [[0.9, 'EyeGlow', 1.8], [0.95, 'Roar', { Scale: 1.8 }], [0.97, 'CameraShake', 0.9]],
    },
    // side-swiping bite with a violent head-shake
    Attack: {
      Duration: 2.0, Suppress: 0.95,
      Keys: [
        [0.45, { Neck1: [0.15, 0.25], Neck2: [0.1, 0.2], Head: [0.15, 0.2], Jaw: [-0.75], Pelvis: [0, 0.1, 0, 0, -0.15, 0.6] }, 'Out'],
        [0.75, { Neck1: [-0.05, -0.2], Neck2: [-0.04, -0.2], Head: [0.08, -0.15], Jaw: [-0.6], Torso: [-0.12], Pelvis: [0, -0.1, 0, 0, -0.35, -2.4] }, 'Snap'],
        [0.86, { Neck1: [-0.12, -0.2], Neck2: [-0.1, -0.2], Head: [-0.05, -0.15], Jaw: [0.02], Torso: [-0.12], Pelvis: [0, -0.1, 0, 0, -0.35, -2.5] }, 'Snap'],
        [1.4, { Neck1: [0, 0.1], Head: [0.05, 0.15, 0.1], Pelvis: [0, 0, 0, 0, -0.1, -1.0] }, 'Sine'],
      ],
      Shake: [['Neck2', 0.9, 1.4, 0.14, 4.5, 2], ['Head', 0.9, 1.4, 0.1, 4.5, 3]],
      Events: [[0.86, 'Bite', { Scale: 1.7 }], [0.88, 'CameraShake', 0.7]],
    },
    // head-low predatory stalk
    Stalk: {
      Duration: 4.0, Suppress: 0.95, Gait: [[0.2, 3.6, 'Walk', 0.9, 0.6]],
      Keys: [[0.7, { Neck1: [-0.25], Neck2: [-0.15], Head: [0.1], Torso: [-0.04], Pelvis: [0, 0, 0, 0, -0.6, -1.0], '~Shin': [-0.2], Tail1: [-0.05] }, 'Sine'], [3.3, { Neck1: [-0.25, 0.1], Neck2: [-0.15, 0.1], Head: [0.1, 0.1], Torso: [-0.04], Pelvis: [0, 0, 0, 0, -0.6, -3.0], '~Shin': [-0.2] }, 'Linear']],
    },
    Stunned: {
      Duration: 3.0, Suppress: 0.92,
      Keys: [[0.3, { Pelvis: [0, 0.08, 0.1, 0, -0.2, 1.4], Torso: [0.1], Neck1: [0.15, 0.15], Head: [0.05, 0.12, 0.2], Jaw: [-0.35] }, 'Out'], [0.8, { Pelvis: [0, -0.05, -0.08, 0, -0.55, 1.2], Torso: [-0.08], Neck1: [-0.12], Head: [0, -0.1, -0.18], '~Thigh': [0.22], '~Shin': [-0.38], Jaw: [-0.35] }, 'Sine'], [2.2, { Pelvis: [0, 0, 0.04, 0, -0.4, 0.9], Neck1: [-0.1], Head: [-0.08, 0, 0.15] }, 'Linear']],
      Procedural: { Type: 'Dizzy', T0: 0.7, T1: 2.4, Rate: 4, Head: [0.18, 0.16], Neck: 0.08, Roll: 0.04 },
      Events: [[0.05, 'Stunned', { Scale: 1.6 }], [0.1, 'CameraShake', 0.6]],
    },
    LookAround: {
      Duration: 4.2, Suppress: 0.65,
      Keys: [[0.8, { Neck1: [0.08, 0.2], Neck2: [0.06, 0.16], Head: [0.05, 0.1, 0.1] }, 'Sine'], [1.6, { Neck1: [0.08, 0.22], Neck2: [0.06, 0.17], Head: [0.1, 0.11] }, 'Linear'], [2.6, { Neck1: [0.06, -0.22], Neck2: [0.05, -0.17], Head: [0.04, -0.1, -0.1] }, 'Sine'], [3.4, { Neck1: [0.06, -0.22], Neck2: [0.05, -0.17], Head: [0.1, -0.11] }, 'Linear']],
      Events: [[1.7, 'Sniff']],
    },
    Chase: {
      Duration: 4.2, Suppress: 1, Gait: [[0, 3.2, 'Run', 1]],
      Keys: [[3.0, { Pelvis: [0, 0, 0, 0, 0, -8] }, 'Linear'], [3.35, { Pelvis: [0, 0, 0, 0, -0.2, -8.8], Neck1: [0.2], Head: [0.2], Jaw: [-0.85] }, 'Out'], [3.5, { Pelvis: [0, 0, 0, 0, -0.35, -9.3], Neck1: [-0.2], Head: [-0.15], Jaw: [0.02] }, 'Snap'], [3.9, { Pelvis: [0, 0, 0, 0, -0.1, -9.3] }, 'Sine']],
      Events: [[3.5, 'Bite', { Scale: 1.7 }], [3.52, 'CameraShake', 0.8]],
    },
    // SIGNATURE: trees shudder, it bulldozes through the jungle wall, lowers its head... and roars
    PredatorArrives: {
      Duration: 7.0, Suppress: 1, FadeIn: 0.01,
      Gait: [[0.0, 2.9, 'Walk', 1, 1.1]],
      Keys: [
        [0.0, { Pelvis: [0, 0, 0, 0, -0.4, 14.0], Neck1: [-0.2], Neck2: [-0.1], Head: [-0.05], Torso: [-0.08] }, 'Linear'],
        [2.8, { Pelvis: [0, 0, 0, 0, -0.3, 0], Neck1: [-0.18], Neck2: [-0.1], Head: [0], Torso: [-0.06] }, 'Sine'],
        [3.6, { Neck1: [-0.32], Neck2: [-0.2], Head: [0.12], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.6, -0.4], Jaw: [-0.12] }, 'Sine'],
        [4.0, { Neck1: [-0.3], Neck2: [-0.2], Head: [0.18], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.6, -0.4], Jaw: [-0.2] }, 'Linear'],
        [4.5, ROAR, 'Back'],
        [6.1, W(ROAR, { Jaw: [-0.78] }), 'Linear'],
      ],
      Shake: [['Head', 4.5, 6.1, 0.05, 12, 3], ['Jaw', 4.5, 6.1, 0.035, 18, 1], ['~Forearm', 4.6, 6.0, 0.2, 7, 1]],
      Events: [
        [0.3, 'Rustle'], [0.9, 'Rustle'], [1.45, 'FellTrees', { Prop: 'JungleWall' }], [1.5, 'FoliageBurst', { Scale: 1.8 }], [1.52, 'CameraShake', 0.9],
        [3.9, 'Growl'], [4.4, 'EyeGlow', 2.2], [4.5, 'Roar', { Scale: 2.0 }], [4.52, 'CameraShake', 1.0],
      ],
    },
  },
};
