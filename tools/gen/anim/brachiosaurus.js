// Brachiosaurus — gentle, enormous. Signature: THE GIANT AWAKENS (steps out, rears its neck, deep call).
const NECK = ['Neck1', 'Neck2', 'Neck3', 'Neck4', 'Neck5'];
const neckPose = (rx, ry = 0) => Object.fromEntries(NECK.map((n, i) => [n, [rx * (0.6 + i * 0.1), ry * (0.5 + i * 0.12)]]));
module.exports = {
  Signature: 'GiantAwakens', Intro: 'GiantAwakens', IntroShots: 'Giant', Chase: 'Chase', Special: 'Browse',
  CycleOrder: ['Walk', 'Run', 'Browse', 'LookAround', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 3.0, PatrolDistance: 26,
  Gait: {
    Type: 'Quadruped', Scale: 3.2, Neck: NECK, Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5'],
    Idle: { Breath: 0.14, BreathAmp: 1.0, Sway: 0.05, Look: 0.12, JawIdle: 0.01 },
    Walk: { Freq: 0.35, Stride: 0.2, Knee: 0.35, Bob: 0.12, Roll: 0.03, Yaw: 0.02, Lean: 0, TailSway: 0.1, HeadBob: 0.03 },
    Run: { Freq: 0.55, Stride: 0.24, Knee: 0.5, Bob: 0.18, Roll: 0.03, Yaw: 0.02, Lean: 0.02, TailSway: 0.08, HeadBob: 0.04 },
  },
  Actions: {
    // deep foghorn call, head raised
    Roar: {
      Duration: 3.6, Suppress: 0.85,
      Keys: [[0.8, Object.assign(neckPose(0.08), { Head: [0.3], Jaw: [-0.45] }), 'Sine'], [2.8, Object.assign(neckPose(0.09), { Head: [0.32], Jaw: [-0.48] }), 'Linear']],
      Shake: [['Head', 0.8, 2.8, 0.02, 6, 3]],
      Events: [[0.8, 'Call', { At: 'VFX_Mouth', Scale: 2.4, Color: [255, 230, 190], Count: 5 }], [0.85, 'CameraShake', 0.6]],
    },
    // defensive rear and front-foot stomp
    Attack: {
      Duration: 3.2, Suppress: 0.95,
      Keys: [
        [1.0, Object.assign(neckPose(0.06), { Pelvis: [0, 0, 0, 0, -0.6, 1.2], Torso: [0.35], '~FrontUpper': [0.6], '~FrontLower': [-0.9], '~FrontFoot': [0.4], '~HindThigh': [-0.2], '~HindShin': [-0.3], Tail1: [0.2], Tail2: [0.15] }), 'Sine'],
        [1.45, Object.assign(neckPose(-0.03), { Pelvis: [0, 0, 0, 0, -0.3, 0.2], Torso: [-0.05], '~FrontUpper': [-0.1], Tail1: [0.05] }), 'In'],
        [2.2, neckPose(0), 'Sine'],
      ],
      Events: [[1.45, 'Impact', { At: 'VFX_RightFrontFoot', Scale: 2.8 }], [1.46, 'CameraShake', 1.2]],
    },
    Stunned: {
      Duration: 3.4, Suppress: 0.9,
      Keys: [
        [0.4, Object.assign(neckPose(0.12, 0.2), { Pelvis: [0, 0, 0.06, 0, -0.2, 0.6], Head: [0.2, 0.2, 0.2] }), 'Out'],
        [1.2, Object.assign(neckPose(-0.06, -0.15), { Pelvis: [0, 0, -0.05, 0, -0.5, 0.4], Head: [-0.1, -0.2, -0.2] }), 'Sine'],
        [2.8, Object.assign(neckPose(-0.03), { Pelvis: [0, 0, 0.02, 0, -0.3, 0.2] }), 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.8, T1: 3.0, Rate: 2.6, Head: [0.25, 0.2], Neck: 0.12, Roll: 0.03 },
      Events: [[0.05, 'Stunned', { Scale: 2.0 }], [0.1, 'CameraShake', 0.6]],
    },
    LookAround: {
      Duration: 5.0, Suppress: 0.6,
      Keys: [[1.2, Object.assign(neckPose(0.02, 0.35), { Head: [0, 0.2, 0.1] }), 'Sine'], [2.2, Object.assign(neckPose(0.02, 0.38), { Head: [0.05, 0.2] }), 'Linear'], [3.4, Object.assign(neckPose(0.02, -0.35), { Head: [0, -0.2, -0.1] }), 'Sine'], [4.2, Object.assign(neckPose(0.02, -0.38), { Head: [0.05, -0.2] }), 'Linear']],
    },
    // reaching up to browse the treetops
    Browse: {
      Duration: 5.0, Suppress: 0.85,
      Keys: [[1.2, Object.assign(neckPose(0.12), { Head: [-0.3], '~HindShin': [0.05] }), 'Sine'], [4.0, Object.assign(neckPose(0.12, 0.1), { Head: [-0.32] }), 'Linear']],
      Shake: [['Jaw', 1.5, 3.8, 0.12, 1.8, 1], ['Head', 1.5, 3.8, 0.05, 0.9, 2]],
    },
    Chase: {
      Duration: 4.5, Suppress: 1, Gait: [[0, 3.8, 'Run', 1]],
      Keys: [[3.6, { Pelvis: [0, 0, 0, 0, 0, -7] }, 'Linear'], [4.2, { Pelvis: [0, 0, 0, 0, 0, -7.2] }, 'Sine']],
      Events: [[3.7, 'Call', { At: 'VFX_Mouth', Scale: 2.0 }]],
    },
    // SIGNATURE: the ground trembles with each step; it rears its neck to full height and calls
    GiantAwakens: {
      Duration: 8.4, Suppress: 1, FadeIn: 0.01,
      Gait: [[0.0, 4.4, 'Walk', 1]],
      Keys: [
        [0.0, Object.assign(neckPose(-0.12), { Head: [-0.15], Pelvis: [0, 0, 0, 0, 0, 8] }), 'Linear'],
        [4.3, Object.assign(neckPose(-0.06), { Head: [-0.1], Pelvis: [0, 0, 0, 0, 0, 0] }), 'Sine'],
        [5.4, Object.assign(neckPose(0.14), { Head: [0.15], Torso: [0.06], Jaw: [-0.1], '~FrontUpper': [-0.05] }), 'Sine'],
        [6.0, Object.assign(neckPose(0.16), { Head: [0.35], Jaw: [-0.5], Torso: [0.08] }), 'Back'],
        [7.6, Object.assign(neckPose(0.16), { Head: [0.33], Jaw: [-0.48], Torso: [0.08] }), 'Linear'],
      ],
      Shake: [['Head', 6.0, 7.6, 0.02, 5, 3]],
      Events: [[6.0, 'Call', { At: 'VFX_Mouth', Scale: 3.0, Color: [255, 230, 190], Count: 6 }], [6.05, 'CameraShake', 0.9]],
    },
  },
};
