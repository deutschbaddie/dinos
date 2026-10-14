// Parasaurolophus — curious, social. Signature: HERD CALL (juveniles answer).
const { W } = require('./util.js');
const CALL = { Neck1: [0.32], Neck2: [0.22], Head: [0.06], Jaw: [-0.35], Torso: [0.1], '~Arm': [-0.2, 0, 0.15], Tail1: [0.05] };
module.exports = {
  Signature: 'HerdCall', Intro: 'HerdCall', IntroShots: 'Herd', Chase: 'Chase', Special: 'Hop',
  CycleOrder: ['Walk', 'Run', 'Hop', 'LookAround', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 1.7,
  Gait: {
    Type: 'Biped', Scale: 1.3, Neck: ['Neck1', 'Neck2'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5'],
    Idle: { Breath: 0.45, BreathAmp: 1.1, Sway: 0.09, Look: 0.35, Twitch: true, JawIdle: 0.02 },
    Walk: { Freq: 1.0, Stride: 0.4, Knee: 0.6, Bob: 0.12, Roll: 0.05, Yaw: 0.06, Lean: 0.04, TailSway: 0.12, HeadBob: 0.07 },
    Run: { Freq: 1.8, Stride: 0.44, Knee: 0.6, Bob: 0.22, Roll: 0.03, Yaw: 0.04, Lean: 0.16, TailSway: 0.07, HeadBob: 0.09 },
  },
  Actions: {
    Roar: {
      Duration: 2.4, Suppress: 0.9,
      Keys: [[0.5, CALL, 'Back'], [1.7, W(CALL, { Jaw: [-0.38] }), 'Linear']],
      Shake: [['Head', 0.5, 1.7, 0.03, 10, 1]],
      Events: [[0.5, 'Call', { At: 'VFX_Crest', Scale: 1.0 }], [0.52, 'CameraShake', 0.2]],
    },
    // defensive tail-whip kick
    Attack: {
      Duration: 1.5, Suppress: 0.95,
      Keys: [
        [0.4, { Pelvis: [0, 0.3, 0, 0, -0.15, 0], Torso: [-0.1, 0.1], Neck1: [-0.1], Tail2: [0, -0.4], Tail3: [0, -0.5], Tail4: [0, -0.5] }, 'Sine'],
        [0.65, { Pelvis: [0, -0.35, 0, 0, -0.1, 0], Tail2: [0, 0.55], Tail3: [0, 0.65], Tail4: [0, 0.6], RightThigh: [-0.45], RightShin: [-0.2] }, 'Snap'],
      ],
      Events: [[0.5, 'TailSwing', 0.5], [0.66, 'Footstep', { Side: 'Right' }]],
    },
    Stunned: {
      Duration: 2.4, Suppress: 0.9,
      Keys: [
        [0.25, { Pelvis: [0, 0, 0.15, 0, -0.1, 0.5], Neck1: [0.3], Head: [0.3, 0, 0.3], Jaw: [-0.3] }, 'Out'],
        [0.7, { Pelvis: [0, 0, -0.1, 0, -0.25, 0.4], Neck1: [-0.2], Head: [-0.2, 0, -0.3], '~Thigh': [0.2], '~Shin': [-0.35] }, 'Sine'],
        [1.9, { Pelvis: [0, 0, 0.05, 0, -0.2, 0.3], Neck1: [-0.15], Head: [-0.1, 0, 0.2] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.5, T1: 2.1, Rate: 6, Head: [0.25, 0.2], Neck: 0.1, Roll: 0.05 },
      Events: [[0.05, 'Stunned', { Scale: 0.8 }]],
    },
    LookAround: {
      Duration: 3.2, Suppress: 0.6,
      Keys: [
        [0.5, { Neck1: [0.1, 0.35], Neck2: [0.05, 0.3], Head: [0.1, 0.3, 0.15] }, 'Snap'],
        [1.2, { Neck1: [0.1, 0.38], Neck2: [0.05, 0.32], Head: [0.15, 0.3, 0.1] }, 'Linear'],
        [1.7, { Neck1: [0.1, -0.38], Neck2: [0.05, -0.3], Head: [0.1, -0.3, -0.15] }, 'Snap'],
        [2.5, { Neck1: [0.1, -0.4], Neck2: [0.05, -0.32], Head: [0.15, -0.32, -0.1] }, 'Linear'],
      ],
    },
    // excited little hop
    Hop: {
      Duration: 1.4, Suppress: 1,
      Keys: [
        [0.25, { Pelvis: [0, 0, 0, 0, -0.35, 0], '~Thigh': [0.4], '~Shin': [-0.7], '~Foot': [0.3], Neck1: [-0.1] }, 'Sine'],
        [0.55, { Pelvis: [0, 0, 0, 0, 1.2, 0], '~Thigh': [0.3], '~Shin': [-0.5], Neck1: [0.25], Head: [0.2], Tail2: [-0.15] }, 'Out'],
        [0.85, { Pelvis: [0, 0, 0, 0, -0.25, 0], '~Thigh': [0.35], '~Shin': [-0.6], '~Foot': [0.25] }, 'In'],
      ],
      Events: [[0.86, 'Land', { Scale: 0.6 }]],
    },
    HerdResponse: {
      Duration: 2.2, Suppress: 0.9,
      Keys: [[0.4, CALL, 'Back'], [1.5, CALL, 'Linear']],
      Shake: [['Head', 0.4, 1.5, 0.04, 12, 1]],
      Events: [[0.4, 'Call', { At: 'VFX_Crest', Scale: 0.5, Count: 3 }]],
    },
    Chase: {
      Duration: 3.2, Suppress: 1, Gait: [[0, 2.8, 'Run', 1]],
      Keys: [[2.6, { Pelvis: [0, 0, 0, 0, 0, -6] }, 'Linear'], [3.0, { Pelvis: [0, 0, 0, 0, 0, -6.2], Neck1: [0.3], Head: [0.2] }, 'Sine']],
      Events: [[2.7, 'Call', { At: 'VFX_Crest', Scale: 0.9 }]],
    },
    // SIGNATURE: perks up, lifts its crest skyward and calls; the juveniles answer; a second, louder call
    HerdCall: {
      Duration: 6.4, Suppress: 1, FadeIn: 0.25,
      Keys: [
        [0.6, { Neck1: [0.1, 0.25], Neck2: [0.08, 0.2], Head: [0.15, 0.2, 0.15] }, 'Snap'],
        [1.2, { Neck1: [0.1, -0.15], Neck2: [0.08, -0.1], Head: [0.12, -0.15, -0.1] }, 'Snap'],
        [1.8, { Neck1: [-0.05], Neck2: [-0.05], Head: [-0.1], Pelvis: [0, 0, 0, 0, -0.15, 0], Jaw: [-0.05] }, 'Sine'],
        [2.2, CALL, 'Back'],
        [3.3, W(CALL, { Jaw: [-0.32] }), 'Linear'],
        [3.8, { Neck1: [0.05, 0.4], Neck2: [0.05, 0.3], Head: [0.05, 0.25, 0.1] }, 'Sine'],
        [4.4, { Neck1: [0.38], Neck2: [0.26], Head: [0.08], Jaw: [-0.42], Torso: [0.12], '~Arm': [-0.25, 0, 0.2], Pelvis: [0, 0, 0, 0, 0.1, 0] }, 'Back'],
        [5.5, { Neck1: [0.4], Neck2: [0.27], Head: [0.09], Jaw: [-0.44], Torso: [0.12] }, 'Linear'],
      ],
      Shake: [['Head', 2.2, 3.3, 0.03, 11, 1], ['Head', 4.4, 5.5, 0.035, 12, 1]],
      Events: [[0.6, 'Sniff'], [2.2, 'HerdCall', { At: 'VFX_Crest', Scale: 1.1 }], [2.25, 'CameraShake', 0.2], [4.4, 'HerdCall', { At: 'VFX_Crest', Scale: 1.5 }], [4.45, 'CameraShake', 0.35]],
    },
  },
};
