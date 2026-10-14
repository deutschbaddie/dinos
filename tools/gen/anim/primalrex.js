// Primal Rex — the secret hybrid. Signature: THE PRIMAL AWAKENING (tears out of its containment cell).
const { W } = require('./util.js');
const ROAR = { Neck1: [-0.05], Neck2: [0], Head: [0.1], Jaw: [-0.82], Torso: [-0.02], Chest: [0, 0, 0, 0, -0.3, -0.3], '~Arm': [-0.5, 0, 0.45], '~Forearm': [-0.8], Tail1: [-0.15], Tail2: [-0.1], Tail3: [-0.06] };
const HIT = (pz) => ({ Neck1: [-0.15], Neck2: [-0.1], Head: [-0.12], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.4, pz], '~Shin': [-0.2], Tail1: [-0.1] });
module.exports = {
  Signature: 'PrimalAwakening', Intro: 'PrimalAwakening', IntroShots: 'Containment', Chase: 'Chase', Special: 'ClawSlash',
  CycleOrder: ['Walk', 'Run', 'ClawSlash', 'LookAround', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 3.8, PatrolDistance: 10,
  Gait: {
    Type: 'Biped', Scale: 3.6, Neck: ['Neck1', 'Neck2'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5', 'Tail6'],
    Idle: { Breath: 0.3, BreathAmp: 1.3, Sway: 0.07, Look: 0.3, Twitch: true, JawIdle: 0.07 },
    Walk: { Freq: 0.5, Stride: 0.36, Knee: 0.62, Bob: 0.12, Roll: 0.04, Yaw: 0.05, Lean: 0.05, TailSway: 0.09, HeadBob: 0.05 },
    Run: { Freq: 0.85, Stride: 0.48, Knee: 0.85, Bob: 0.2, Roll: 0.03, Yaw: 0.04, Lean: 0.16, TailSway: 0.06, HeadBob: 0.07 },
  },
  Actions: {
    Roar: {
      Duration: 3.4, Suppress: 0.95,
      Keys: [[0.55, { Neck1: [-0.18], Neck2: [-0.12], Head: [-0.15], Pelvis: [0, 0, 0, 0, -0.3, 0.4], '~Arm': [0.3, 0, 0.2] }, 'Sine'], [1.0, W(ROAR, { Pelvis: [0, 0, 0, 0, -0.1, -0.9] }), 'Back'], [2.6, W(ROAR, { Jaw: [-0.8], Pelvis: [0, 0, 0, 0, -0.1, -1.0] }), 'Linear']],
      Shake: [['Head', 1.0, 2.6, 0.05, 13, 3], ['Jaw', 1.0, 2.6, 0.04, 20, 1], ['~Forearm', 1.0, 2.5, 0.22, 8, 1], ['Neck2', 1.0, 2.6, 0.025, 8, 2]],
      Events: [[0.95, 'EyeGlow', 2.0], [1.0, 'Roar', { Scale: 2.4 }], [1.02, 'CameraShake', 1.1]],
    },
    Attack: {
      Duration: 1.9, Suppress: 0.95,
      Keys: [[0.45, { Neck1: [0.2], Neck2: [0.12], Head: [0.2], Jaw: [-0.8], Pelvis: [0, 0, 0, 0, -0.15, 0.9], '~Arm': [0.4, 0, 0.4] }, 'Out'], [0.75, { Neck1: [-0.15], Neck2: [-0.1], Head: [0], Jaw: [-0.82], Torso: [-0.14], Pelvis: [0, 0, 0, 0, -0.4, -3.0], '~Arm': [1.0, 0, -0.1] }, 'Snap'], [0.86, { Neck1: [-0.16], Neck2: [-0.1], Head: [0], Jaw: [0.03], Torso: [-0.14], Pelvis: [0, 0, 0, 0, -0.4, -3.1], '~Arm': [1.0, 0, -0.1] }, 'Snap'], [1.3, { Head: [0.05, 0.15, 0.1], Pelvis: [0, 0, 0, 0, -0.1, -1.2] }, 'Sine']],
      Events: [[0.86, 'Bite', { Scale: 2.0 }], [0.88, 'CameraShake', 0.9]],
    },
    // double claw slash
    ClawSlash: {
      Duration: 2.2, Suppress: 0.95,
      Keys: [
        [0.35, { RightArm: [-0.2, 0, 0.7], RightForearm: [-0.9], Torso: [0, -0.3], Pelvis: [0, -0.15, 0] }, 'Sine'],
        [0.55, { RightArm: [0.85, 0, 0.25], RightForearm: [-0.1], Torso: [0, 0.35], Pelvis: [0, 0.2, 0, 0, 0, -1.2] }, 'Snap'],
        [0.95, { LeftArm: [-0.2, 0, -0.7], LeftForearm: [-0.9], RightArm: [0.6], Torso: [0, 0.3], Pelvis: [0, 0.15, 0, 0, 0, -1.2] }, 'Sine'],
        [1.15, { LeftArm: [0.85, 0, -0.25], LeftForearm: [-0.1], Torso: [0, -0.35], Pelvis: [0, -0.2, 0, 0, 0, -2.2] }, 'Snap'],
        [1.6, { Pelvis: [0, 0, 0, 0, 0, -1.0] }, 'Sine'],
      ],
      Events: [[0.55, 'Bite', { Scale: 1.6 }], [0.56, 'CameraShake', 0.6], [1.15, 'Bite', { Scale: 1.6 }], [1.16, 'CameraShake', 0.6]],
    },
    Stunned: {
      Duration: 3.0, Suppress: 0.92,
      Keys: [[0.3, { Pelvis: [0, 0.08, 0.1, 0, -0.2, 1.6], Neck1: [0.08, 0.12], Head: [0.04, 0.12, 0.18], Jaw: [-0.35] }, 'Out'], [0.8, { Pelvis: [0, -0.05, -0.08, 0, -0.6, 1.3], Neck1: [-0.1], Head: [0, -0.1, -0.16], '~Thigh': [0.22], '~Shin': [-0.38] }, 'Sine'], [2.2, { Pelvis: [0, 0, 0.04, 0, -0.45, 1.0], Neck1: [-0.1], Head: [-0.08, 0, 0.15] }, 'Linear']],
      Shake: [['Head', 2.35, 2.85, 0.12, 6.4, 3]],
      Procedural: { Type: 'Dizzy', T0: 0.7, T1: 2.3, Rate: 4, Head: [0.1, 0.1], Neck: 0.06, Roll: 0.04 },
      Events: [[0.05, 'Stunned', { Scale: 2.0 }], [0.1, 'CameraShake', 0.7]],
    },
    LookAround: {
      Duration: 3.4, Suppress: 0.65,
      Keys: [[0.5, { Neck1: [0.14, 0.18], Neck2: [0.1, 0.14], Head: [0.08, 0.12, 0.12] }, 'Snap'], [1.3, { Neck1: [0.14, 0.19], Neck2: [0.1, 0.15], Head: [0.12, 0.13] }, 'Linear'], [1.8, { Neck1: [0.08, -0.2], Neck2: [0.06, -0.16], Head: [0.06, -0.12, -0.12] }, 'Snap'], [2.6, { Neck1: [0.08, -0.22], Neck2: [0.06, -0.17], Head: [0.12, -0.13] }, 'Linear']],
      Events: [[1.4, 'Sniff']],
    },
    Chase: {
      Duration: 4.2, Suppress: 1, Gait: [[0, 3.2, 'Run', 1]],
      Keys: [[3.0, { Pelvis: [0, 0, 0, 0, 0, -8] }, 'Linear'], [3.35, { Pelvis: [0, 0, 0, 0, -0.2, -9], Neck1: [0.2], Head: [0.2], Jaw: [-0.85], '~Arm': [0.6, 0, 0.3] }, 'Out'], [3.5, { Pelvis: [0, 0, 0, 0, -0.35, -9.5], Neck1: [-0.2], Head: [-0.15], Jaw: [0.03] }, 'Snap'], [3.9, { Pelvis: [0, 0, 0, 0, -0.1, -9.5] }, 'Sine']],
      Events: [[3.5, 'Bite', { Scale: 2.0 }], [3.52, 'CameraShake', 0.9]],
    },
    // SIGNATURE: impacts rock the gate; cracks spread; a claw tears through; the head forces out; it breaks free
    PrimalAwakening: {
      Duration: 9.4, Suppress: 1, FadeIn: 0.2,
      Gait: [[5.0, 6.7, 'Walk', 1, 1.2]],
      Keys: [
        [0.6, { Neck1: [-0.1], Head: [-0.05], Pelvis: [0, 0, 0, 0, -0.2, 1.2], Torso: [-0.05] }, 'Sine'],
        [0.9, HIT(-2.3), 'Snap'], [1.5, { Pelvis: [0, 0, 0, 0, -0.2, 1.4], Neck1: [0.1], Head: [0.1] }, 'Sine'],
        [1.8, HIT(-2.4), 'Snap'], [2.4, { Pelvis: [0, 0, 0, 0, -0.2, 0.8], Neck1: [0.1], Head: [0.15], Jaw: [-0.3] }, 'Sine'],
        [3.0, { Pelvis: [0, 0, 0, 0, -0.3, -1.2], RightArm: [1.2, 0, 0.5], RightForearm: [0.1], Torso: [-0.1, 0.15], Neck1: [-0.05, -0.25], Head: [0.05, -0.15] }, 'Snap'],
        [3.6, { Pelvis: [0, 0, 0, 0, -0.3, -1.4], RightArm: [1.15, 0, 0.55], RightForearm: [0.15], Torso: [-0.1, 0.25], Neck1: [-0.05, -0.3] }, 'Sine'],
        [4.1, { Pelvis: [0, 0, 0, 0, -0.6, -2.4], Neck1: [-0.3], Neck2: [-0.25], Head: [0.15], Jaw: [-0.5], Torso: [-0.2], '~Arm': [0.7, 0, 0.3] }, 'Out'],
        [4.6, { Pelvis: [0, 0, 0, 0, -0.5, -4.2], Neck1: [-0.1], Neck2: [-0.05], Head: [0.25], Jaw: [-0.7], Torso: [-0.12] }, 'Snap'],
        [6.6, { Pelvis: [0, 0, 0, 0, -0.2, -12.0], Neck1: [-0.12], Head: [0], Torso: [-0.06] }, 'Sine'],
        [7.0, { Neck1: [-0.2], Neck2: [-0.12], Head: [-0.15], Pelvis: [0, 0, 0, 0, -0.35, -11.6], '~Arm': [0.3, 0, 0.2] }, 'Sine'],
        [7.4, W(ROAR, { Pelvis: [0, 0, 0, 0, -0.1, -12.6] }), 'Back'],
        [8.9, W(ROAR, { Jaw: [-0.8], Pelvis: [0, 0, 0, 0, -0.1, -12.7] }), 'Linear'],
      ],
      Shake: [['Head', 7.4, 8.9, 0.05, 13, 3], ['Jaw', 7.4, 8.9, 0.04, 20, 1], ['~Forearm', 7.4, 8.8, 0.22, 8, 1]],
      Events: [
        [0.05, 'Alarm', 9.0], [0.9, 'GateHit', { Prop: 'Gate', Stage: 1 }], [1.8, 'GateHit', { Prop: 'Gate', Stage: 2 }],
        [3.0, 'GateHit', { Prop: 'Gate', Stage: 3 }], [3.02, 'EyeGlow', 6.0], [4.55, 'BreakProp', { Prop: 'Gate', Power: 1.6, At: 'VFX_Head' }],
        [4.56, 'Impact', { At: 'VFX_Head', Scale: 2.6 }], [4.57, 'CameraShake', 1.3], [7.4, 'Roar', { Scale: 2.6 }], [7.42, 'CameraShake', 1.2],
      ],
    },
  },
};
