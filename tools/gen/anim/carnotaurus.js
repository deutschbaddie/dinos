// Carnotaurus — aggressive, unpredictable. Signature: AMBUSH ATTACK (bursts out of the foliage at the camera).
const { W } = require('./util.js');
const CROUCH = { Pelvis: [0, 0, 0, 0, -1.3, 3.5], '~Thigh': [0.55], '~Shin': [-0.95], '~Foot': [0.4], Torso: [-0.12], Neck: [-0.2], Head: [0.14] };
const LUNGE = { Pelvis: [0, 0, 0, 0, 0.2, -2.8], '~Thigh': [0.25], '~Shin': [-0.2], Torso: [-0.2], Neck: [-0.05], Head: [0.12], Jaw: [-0.85], Tail1: [-0.2], Tail2: [-0.15] };
module.exports = {
  Signature: 'Ambush', Intro: 'Ambush', IntroShots: 'Ambush', Chase: 'Chase', Special: 'HornShove',
  CycleOrder: ['Walk', 'Run', 'HornShove', 'LookAround', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 1.9,
  Gait: {
    Type: 'Biped', Scale: 1.7, Neck: ['Neck'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5'],
    Idle: { Breath: 0.4, BreathAmp: 1.2, Sway: 0.1, Look: 0.4, Twitch: true, JawIdle: 0.05 },
    Walk: { Freq: 0.95, Stride: 0.42, Knee: 0.65, Bob: 0.12, Roll: 0.05, Yaw: 0.07, Lean: 0.06, TailSway: 0.13, HeadBob: 0.07 },
    Run: { Freq: 1.7, Stride: 0.54, Knee: 0.9, Bob: 0.22, Roll: 0.03, Yaw: 0.05, Lean: 0.22, TailSway: 0.07, HeadBob: 0.09 },
  },
  Actions: {
    Roar: {
      Duration: 2.4, Suppress: 0.92,
      Keys: [
        [0.35, { Neck: [-0.2], Head: [-0.2], Jaw: [-0.1], Pelvis: [0, 0, 0, 0, -0.2, 0.3] }, 'Sine'],
        [0.7, { Neck: [0.18], Head: [0.14], Jaw: [-0.75], Torso: [0.06], Pelvis: [0, 0, 0, 0, 0, -0.4], Tail1: [-0.15] }, 'Back'],
        [1.7, { Neck: [0.2], Head: [0.15], Jaw: [-0.76], Torso: [0.06], Pelvis: [0, 0, 0, 0, 0, -0.45], Tail1: [-0.15] }, 'Linear'],
      ],
      Shake: [['Head', 0.7, 1.7, 0.08, 16, 3], ['Jaw', 0.7, 1.7, 0.05, 22, 1]],
      Events: [[0.65, 'EyeGlow', 1.5], [0.7, 'Roar', { Scale: 1.0 }], [0.72, 'CameraShake', 0.5]],
    },
    Attack: {
      Duration: 1.4, Suppress: 0.95,
      Keys: [
        [0.3, { Neck: [0.15], Head: [0.2], Jaw: [-0.8], Pelvis: [0, 0, 0, 0, -0.2, 0.5] }, 'Out'],
        [0.5, { Neck: [-0.12], Head: [0.1], Jaw: [-0.7], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.1, -1.6] }, 'Snap'],
        [0.58, { Neck: [-0.14], Head: [0.08], Jaw: [0.02], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.1, -1.7] }, 'Snap'],
        [0.95, { Head: [0.1, 0.2, 0.15], Pelvis: [0, 0, 0, 0, 0, -0.6] }, 'Sine'],
      ],
      Shake: [['Head', 0.6, 1.0, 0.12, 6, 2]],
      Events: [[0.58, 'Bite', { Scale: 1.0 }], [0.6, 'CameraShake', 0.4]],
    },
    // head-down horn shove like a bull
    HornShove: {
      Duration: 1.8, Suppress: 0.95,
      Keys: [
        [0.45, { Neck: [-0.4], Head: [-0.35], Torso: [-0.1], Pelvis: [0, 0, 0, 0, -0.3, 0.6], '~Shin': [-0.3] }, 'Sine'],
        [0.7, { Neck: [-0.1], Head: [0.25], Torso: [-0.05], Pelvis: [0, 0, 0, 0, 0.1, -1.8] }, 'Snap'],
        [1.1, { Head: [0.1, 0.15], Pelvis: [0, 0, 0, 0, 0, -0.8] }, 'Sine'],
      ],
      Events: [[0.7, 'Impact', { At: 'VFX_Head', Scale: 0.9 }]],
    },
    Stunned: {
      Duration: 2.6, Suppress: 0.9,
      Keys: [
        [0.25, { Pelvis: [0, 0, 0.14, 0, -0.1, 0.8], Torso: [0.15], Neck: [0.3], Head: [0.3, 0, 0.3], Jaw: [-0.4] }, 'Out'],
        [0.7, { Pelvis: [0, 0, -0.1, 0, -0.4, 0.7], Neck: [-0.2], Head: [-0.2, 0, -0.3], '~Thigh': [0.25], '~Shin': [-0.45] }, 'Sine'],
        [2.0, { Pelvis: [0, 0, 0.05, 0, -0.3, 0.5], Neck: [-0.15], Head: [-0.1, 0, 0.2] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.5, T1: 2.3, Rate: 6, Head: [0.25, 0.2], Neck: 0.12, Roll: 0.05 },
      Events: [[0.05, 'Stunned', { Scale: 1.0 }], [0.1, 'CameraShake', 0.35]],
    },
    LookAround: {
      Duration: 3.0, Suppress: 0.6,
      Keys: [[0.4, { Neck: [0.1, 0.45], Head: [0.05, 0.4, 0.15] }, 'Snap'], [1.1, { Neck: [0.1, 0.48], Head: [0.1, 0.42] }, 'Linear'], [1.5, { Neck: [0.08, -0.45], Head: [0.05, -0.4, -0.15] }, 'Snap'], [2.3, { Neck: [0.08, -0.48], Head: [0.1, -0.42] }, 'Linear']],
      Events: [[1.2, 'Sniff']],
    },
    Chase: {
      Duration: 3.3, Suppress: 1, Gait: [[0, 2.5, 'Run', 1]],
      Keys: [[2.3, { Pelvis: [0, 0, 0, 0, 0, -6], Torso: [-0.1] }, 'Linear'], [2.6, { Pelvis: [0, 0, 0, 0, 0.3, -6.8], Neck: [0.2], Head: [0.2], Jaw: [-0.9] }, 'Out'], [2.75, { Pelvis: [0, 0, 0, 0, 0.1, -7.2], Neck: [-0.2], Head: [-0.1], Jaw: [0.02] }, 'Snap'], [3.1, { Pelvis: [0, 0, 0, 0, 0, -7.2] }, 'Sine']],
      Events: [[2.75, 'Bite', { Scale: 1.0 }], [2.76, 'CameraShake', 0.5]],
    },
    // SIGNATURE: hidden behind the foliage... silence... it bursts out and lunges straight at the lens
    Ambush: {
      Duration: 5.0, Suppress: 1, FadeIn: 0.01,
      Keys: [
        [0.0, CROUCH, 'Linear'],
        [1.2, W(CROUCH, { Head: [0.14, 0.12], Neck: [-0.2, 0.1] }), 'Sine'],
        [1.5, W(CROUCH, { Pelvis: [0, 0, 0, 0, -1.45, 3.7], Neck: [-0.22], Head: [0.14] }), 'Sine'],
        [1.85, LUNGE, 'Snap'],
        [2.15, W(LUNGE, { Jaw: [-0.9], Pelvis: [0, 0, 0, 0, 0.1, -3.1] }), 'Linear'],
        [2.5, { Neck: [-0.2], Head: [-0.2], Jaw: [-0.15], Pelvis: [0, 0, 0, 0, -0.25, -1.2] }, 'Sine'],
        [2.85, { Neck: [0.2], Head: [0.14], Jaw: [-0.92], Torso: [0.06], Pelvis: [0, 0, 0, 0, 0, -1.5], Tail1: [-0.15] }, 'Back'],
        [4.1, { Neck: [0.22], Head: [0.15], Jaw: [-0.9], Torso: [0.06], Pelvis: [0, 0, 0, 0, 0, -1.5], Tail1: [-0.15] }, 'Linear'],
      ],
      Shake: [['Head', 2.85, 4.1, 0.08, 16, 3], ['Jaw', 2.85, 4.1, 0.05, 22, 1]],
      Events: [
        [0.0, 'CurtainClose'], [0.6, 'Rustle'], [1.25, 'Rustle'], [1.8, 'CurtainOpen'], [1.82, 'FoliageBurst', { Scale: 1.6 }],
        [1.85, 'EyeGlow', 2.6], [1.86, 'CameraShake', 0.8], [2.12, 'Bite', { Scale: 1.1 }], [2.85, 'Roar', { Scale: 1.1 }], [2.87, 'CameraShake', 0.6],
      ],
    },
  },
};
