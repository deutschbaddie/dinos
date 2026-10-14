// Plateosaurus — a gentle giant that walks on two legs and rears up to feed. Signature: TREE REACH
// (rears up on its hind legs to strip a tall cycad, then drops with a dust-ring slam and bellows).
const { W } = require('./util.js');

// up on its hind legs: hips tip back, legs counter-rotate to stay planted, tail props it like a tripod
const REAR = {
  Pelvis: [0.6, 0, 0, 0, -0.24, 0.5], '~Thigh': [-0.48], '~Shin': [-0.18], '~Foot': [0.06], Torso: [0.1],
  Neck1: [0.1], Neck2: [0.02], Neck3: [-0.12], Head: [-0.42], Jaw: [-0.1],
  '~Arm': [1.1, 0, 0.18], '~Forearm': [0.5], '~Hand': [0.35],
  Tail1: [-0.26], Tail2: [0.04], Tail3: [0.06], Tail4: [0.06], Tail5: [0.04],
};
const LOOK_UP = { Neck1: [0.22], Neck2: [0.16], Neck3: [0.08], Head: [0.32, -0.18, 0.08] };
const BELLOW = { Pelvis: [0, 0, 0, 0, 0, 0], '~Thigh': [0], '~Shin': [0], '~Foot': [0], Neck1: [0.3], Neck2: [0.22], Neck3: [0.12], Head: [0.32], Jaw: [-0.7], Torso: [0.08], '~Arm': [-0.25, 0, 0.25], '~Forearm': [-0.3], Tail1: [-0.12], Tail2: [-0.06] };
const SLAMMED = { Pelvis: [-0.22, 0, 0, 0, -1.22, -0.6], '~Thigh': [0.62], '~Shin': [-0.9], '~Foot': [0.36], Torso: [-0.22], Neck1: [0.0], Neck2: [0.12], Neck3: [0.16], Head: [0.2], Jaw: [-0.3], '~Arm': [0.5, 0, 0.12], '~Forearm': [-0.1], '~Hand': [0.62], Tail1: [0.12], Tail2: [0.05] };
const GRAZE = { Pelvis: [-0.05, 0, 0, 0, -0.2, 0], '~Thigh': [0.18], '~Shin': [-0.3], '~Foot': [0.1], Torso: [-0.12], Neck1: [-0.4], Neck2: [-0.3], Neck3: [-0.15], Head: [-0.1], '~Arm': [0.3, 0, 0.1] };

module.exports = {
  Signature: 'TreeReach', Intro: 'TreeReach', IntroShots: 'PlateoReach', Chase: 'Chase', Special: 'Browse',
  CycleOrder: ['Walk', 'Run', 'Browse', 'Graze', 'LookAround', 'ThumbSwipe', 'RearSlam', 'TailSwipe', 'Forage', 'Stunned', 'Roar'],
  CameraScale: 2.6, PatrolDistance: 18,
  Gait: {
    Type: 'Biped', Scale: 2.4, Neck: ['Neck1', 'Neck2', 'Neck3'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5'],
    Idle: { Breath: 0.24, BreathAmp: 1.0, Sway: 0.06, Look: 0.22, Twitch: false, JawIdle: 0.03 },
    Walk: { Freq: 0.62, Stride: 0.3, Knee: 0.55, Bob: 0.14, Roll: 0.05, Yaw: 0.05, Lean: 0.03, TailSway: 0.1, HeadBob: 0.05, Speed: 6 },
    Run: { Freq: 1.05, Stride: 0.37, Knee: 0.75, Bob: 0.24, Roll: 0.035, Yaw: 0.04, Lean: 0.12, TailSway: 0.07, HeadBob: 0.07, ThighBias: 0, Speed: 14 },
  },
  Actions: {
    // a deep, honking bellow
    Roar: {
      Duration: 2.8, Suppress: 0.9,
      Keys: [
        [0.45, { Neck1: [-0.12], Neck2: [-0.08], Head: [-0.1], Jaw: [-0.1], Torso: [-0.04], Pelvis: [0, 0, 0, 0, -0.15, 0.2] }, 'Sine'],
        [0.9, BELLOW, 'Back'],
        [2.1, W(BELLOW, { Jaw: [-0.66], Head: [0.3, 0, 0.06] }), 'Linear'],
      ],
      Shake: [['Head', 0.9, 2.1, 0.03, 9, 3], ['Neck3', 0.9, 2.1, 0.02, 6, 2]],
      Events: [[0.88, 'Call', { At: 'VFX_Mouth', Scale: 1.3, Color: [255, 225, 160], Count: 4 }], [0.9, 'Roar', { Scale: 0.9 }], [0.92, 'CameraShake', 0.4]],
    },
    // swipes the big thumb claw across in front of it
    Attack: {
      Duration: 1.6, Suppress: 0.95,
      Keys: [
        [0.45, { Pelvis: [0, 0.25, 0, 0, -0.2, 0.3], Torso: [0.06, 0.2], Neck1: [0.1, 0.15], RightArm: [0.9, 0, 0.7], RightForearm: [0.4], RightHand: [0.3], LeftArm: [0.3] }, 'Sine'],
        [0.68, { Pelvis: [0, -0.25, 0, 0, -0.25, -0.5], Torso: [-0.1, -0.2], Neck1: [-0.05, -0.15], RightArm: [0.9, 0, -0.5], RightForearm: [0.1], RightHand: [0.1] }, 'Snap'],
        [1.05, { Pelvis: [0, -0.1, 0, 0, -0.1, -0.2], RightArm: [0.3, 0, -0.2] }, 'Sine'],
      ],
      Events: [[0.6, 'TailSwing', 0.4], [0.68, 'Bite', { Scale: 0.9 }], [0.7, 'CameraShake', 0.35]],
    },
    ThumbSwipe: {
      Duration: 1.6, Suppress: 0.95,
      Keys: [
        [0.45, { Pelvis: [0, 0.25, 0, 0, -0.2, 0.3], Torso: [0.06, 0.2], Neck1: [0.1, 0.15], RightArm: [0.9, 0, 0.7], RightForearm: [0.4], RightHand: [0.3], LeftArm: [0.3] }, 'Sine'],
        [0.68, { Pelvis: [0, -0.25, 0, 0, -0.25, -0.5], Torso: [-0.1, -0.2], Neck1: [-0.05, -0.15], RightArm: [0.9, 0, -0.5], RightForearm: [0.1], RightHand: [0.1] }, 'Snap'],
        [1.05, { Pelvis: [0, -0.1, 0, 0, -0.1, -0.2], RightArm: [0.3, 0, -0.2] }, 'Sine'],
      ],
      Events: [[0.6, 'TailSwing', 0.4], [0.68, 'Bite', { Scale: 0.9 }], [0.7, 'CameraShake', 0.35]],
    },
    // takedown: rears up tall... and slams its forefeet down in a dust ring
    RearSlam: {
      Duration: 2.6, Suppress: 1,
      Keys: [
        [0.25, { Pelvis: [0.05, 0, 0, 0, -0.2, 0.2], '~Thigh': [0.12], '~Shin': [-0.25], Neck1: [0.1] }, 'Sine'],
        [0.95, REAR, 'Sine'],
        [1.25, W(REAR, { Pelvis: [0.64, 0, 0, 0, -0.3, 0.55], Head: [-0.3], Jaw: [-0.4] }), 'Sine'],
        [1.55, SLAMMED, 'In'],
        [2.0, W(SLAMMED, { Pelvis: [-0.08, 0, 0, 0, -0.36, -0.2], '~Thigh': [0.2], '~Shin': [-0.32], '~Foot': [0.12], Torso: [-0.1], '~Arm': [0.2, 0, 0.1], Jaw: [-0.15] }), 'Sine'],
      ],
      Events: [[1.0, 'Growl'], [1.53, 'Impact', { At: 'VFX_RightClaw', Scale: 1.8 }], [1.54, 'Impact', { At: 'VFX_LeftClaw', Scale: 1.4 }], [1.55, 'CameraShake', 0.8]],
    },
    // takedown: a low sweep of the heavy tail behind it
    TailSwipe: {
      Duration: 1.8, Suppress: 0.95,
      Keys: [
        [0.5, { Pelvis: [0, -0.3, 0, 0, -0.15, 0], Torso: [0, 0.15], Neck1: [0, 0.3], Neck2: [0, 0.2], Head: [0, 0.2], Tail1: [0.05, -0.3], Tail2: [0.05, -0.35], Tail3: [0, -0.35], Tail4: [0, -0.3], Tail5: [0, -0.25] }, 'Sine'],
        [0.8, { Pelvis: [0, 0.35, 0, 0, -0.2, 0], Torso: [0, -0.15], Neck1: [0, -0.25], Neck2: [0, -0.15], Tail1: [0.08, 0.45], Tail2: [0.08, 0.5], Tail3: [0.05, 0.55], Tail4: [0, 0.5], Tail5: [0, 0.45] }, 'Snap'],
        [1.25, { Pelvis: [0, 0.12, 0, 0, -0.05, 0], Tail1: [0, 0.12], Tail2: [0, 0.14] }, 'Sine'],
      ],
      Events: [[0.62, 'TailSwing', 0.8], [0.82, 'Impact', { At: 'VFX_TailTip', Scale: 1.2 }]],
    },
    Stunned: {
      Duration: 3.0, Suppress: 0.9,
      Keys: [
        [0.3, { Pelvis: [0, 0.08, 0.1, 0, -0.2, 0.8], Torso: [0.1], Neck1: [0.2, 0.2], Neck2: [0.1], Head: [0.2, 0.2, 0.25], Jaw: [-0.35] }, 'Out'],
        [0.8, { Pelvis: [0, -0.05, -0.08, 0, -0.6, 0.6], Torso: [-0.08], Neck1: [-0.25], Neck2: [-0.15], Head: [-0.2, -0.15, -0.2], '~Thigh': [0.25], '~Shin': [-0.42], '~Foot': [0.14], Jaw: [-0.3] }, 'Sine'],
        [2.3, { Pelvis: [0, 0, 0.04, 0, -0.45, 0.4], Neck1: [-0.18], Head: [-0.1, 0, 0.15], '~Thigh': [0.2], '~Shin': [-0.36], '~Foot': [0.12], Jaw: [-0.25] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.7, T1: 2.6, Rate: 3.6, Head: [0.22, 0.18], Neck: 0.1, Roll: 0.04 },
      Events: [[0.05, 'Stunned', { Scale: 1.4 }], [0.1, 'CameraShake', 0.5]],
    },
    LookAround: {
      Duration: 4.4, Suppress: 0.6,
      Keys: [
        [0.9, { Neck1: [0.12, 0.3], Neck2: [0.08, 0.25], Neck3: [0.04, 0.15], Head: [0.08, 0.2, 0.1] }, 'Sine'],
        [1.8, { Neck1: [0.12, 0.32], Neck2: [0.08, 0.26], Neck3: [0.04, 0.16], Head: [0.12, 0.22, 0.05] }, 'Linear'],
        [2.8, { Neck1: [0.1, -0.3], Neck2: [0.06, -0.25], Neck3: [0.04, -0.15], Head: [0.08, -0.2, -0.1], Tail3: [0, 0.12] }, 'Sine'],
        [3.6, { Neck1: [0.1, -0.32], Neck2: [0.06, -0.26], Neck3: [0.04, -0.16], Head: [0.12, -0.22, -0.05], Tail3: [0, 0.12] }, 'Linear'],
      ],
      Events: [[1.9, 'Sniff']],
    },
    Sniff: {
      Duration: 2.2, Suppress: 0.85,
      Keys: [[0.6, GRAZE, 'Sine'], [1.6, W(GRAZE, { Head: [-0.12] }), 'Linear']],
      Shake: [['Head', 0.6, 1.6, 0.03, 5, 1]],
      Events: [[0.7, 'Sniff']],
    },
    Graze: {
      Duration: 4.2, Suppress: 0.85,
      Keys: [[0.8, GRAZE, 'Sine'], [3.4, W(GRAZE, { Head: [-0.14] }), 'Linear']],
      Shake: [['Jaw', 1.0, 3.3, 0.12, 2.2, 1]],
    },
    // half-rears to browse the high fronds (when it's up there it can see a long way)
    Browse: {
      Duration: 5.0, Suppress: 0.85,
      Keys: [
        [1.2, W(REAR, { Pelvis: [0.42, 0, 0, 0, -0.16, 0.35], '~Thigh': [-0.32], Head: [-0.2], '~Arm': [0.7, 0, 0.15] }), 'Sine'],
        [3.9, W(REAR, { Pelvis: [0.44, 0, 0, 0, -0.17, 0.35], '~Thigh': [-0.34], Head: [-0.24, 0.12], '~Arm': [0.75, 0, 0.15] }), 'Linear'],
      ],
      Shake: [['Jaw', 1.4, 3.8, 0.12, 2, 1], ['Head', 1.4, 3.8, 0.04, 1, 2]],
    },
    // buddy FORAGER: noses through the scrub, chews... and a soft green pulse heals its friend
    Forage: {
      Duration: 3.4, Suppress: 0.85,
      Keys: [[0.7, GRAZE, 'Sine'], [1.9, W(GRAZE, { Head: [-0.16] }), 'Linear'], [2.5, W(LOOK_UP, { Jaw: [-0.2] }), 'Sine']],
      Shake: [['Jaw', 0.8, 1.9, 0.12, 2.4, 1]],
      Events: [[0.9, 'Sniff'], [2.4, 'HealPulse', { Scale: 1.2 }]],
    },
    // a herd answering the lead's bellow
    HerdResponse: {
      Duration: 2.4, Suppress: 0.9,
      Keys: [[0.5, BELLOW, 'Back'], [1.6, BELLOW, 'Linear']],
      Shake: [['Head', 0.5, 1.6, 0.03, 9, 3]],
      Events: [[0.5, 'Call', { At: 'VFX_Mouth', Scale: 0.8, Color: [255, 225, 160], Count: 3 }]],
    },
    // the chase: a lumbering run that ends in a hip-check and thumb swipe at the rover
    Chase: {
      Duration: 3.8, Suppress: 1,
      Gait: [[0, 3.0, 'Run', 1]],
      Keys: [
        [2.8, { Pelvis: [0, 0, 0, 0, 0, -6.5], Torso: [-0.06] }, 'Linear'],
        [3.15, { Pelvis: [0, 0.3, 0, 0, -0.1, -7.2], Torso: [0, 0.2], RightArm: [1.0, 0, 0.7], RightForearm: [0.4], Neck1: [0.1, 0.2] }, 'Out'],
        [3.35, { Pelvis: [0, -0.3, 0, 0, -0.25, -7.6], Torso: [-0.1, -0.2], RightArm: [0.9, 0, -0.5], RightForearm: [0.1] }, 'Snap'],
        [3.6, { Pelvis: [0, 0, 0, 0, 0, -7.6] }, 'Sine'],
      ],
      Events: [[3.35, 'Bite', { Scale: 1.0 }], [3.36, 'CameraShake', 0.5]],
    },
    // SIGNATURE: it looks up at the cycad... rears up on its hind legs to the crown, strips it bare, then drops
    // onto its hands in a ring of dust and bellows
    TreeReach: {
      Duration: 7.4, Suppress: 1, FadeIn: 0.2,
      Keys: [
        [0.7, LOOK_UP, 'Sine'],
        [1.2, W(LOOK_UP, { Pelvis: [0.06, 0, 0, 0, -0.2, 0.25], '~Thigh': [0.08], '~Shin': [-0.3], '~Foot': [0.12], Tail1: [0.06], Jaw: [-0.12] }), 'Sine'],
        [2.35, REAR, 'Sine'],
        [2.7, W(REAR, { Neck3: [0.0, -0.12], Head: [-0.28, -0.12], Jaw: [-0.55] }), 'Sine'],
        [2.95, W(REAR, { Neck3: [0.04, -0.14], Head: [-0.22, -0.14], Jaw: [0.02] }), 'Snap'],
        [3.2, W(REAR, { Neck2: [-0.18], Neck3: [-0.32, 0.1], Head: [-0.6, 0.22], Jaw: [0.02], '~Arm': [0.85, 0, 0.18] }), 'Snap'],
        [4.1, W(REAR, { Neck2: [-0.05], Neck3: [-0.12, 0.05], Head: [-0.4, 0.1], Jaw: [-0.1] }), 'Sine'],
        [4.35, W(REAR, { Pelvis: [0.66, 0, 0, 0, -0.33, 0.55], Head: [-0.3], Jaw: [-0.2] }), 'Sine'],
        [4.85, SLAMMED, 'In'],
        [5.35, W(SLAMMED, { Pelvis: [-0.06, 0, 0, 0, -0.34, -0.25], '~Thigh': [0.2], '~Shin': [-0.32], '~Foot': [0.12], Torso: [-0.1], '~Arm': [0.2, 0, 0.1], Head: [0.05], Jaw: [-0.2] }), 'Sine'],
        [5.85, BELLOW, 'Back'],
        [7.0, W(BELLOW, { Jaw: [-0.66], Head: [0.3, 0, 0.06] }), 'Linear'],
      ],
      Shake: [['Jaw', 3.3, 4.1, 0.14, 3, 1], ['Neck3', 3.2, 3.55, 0.06, 8, 2], ['Head', 5.85, 7.0, 0.03, 9, 3]],
      Events: [
        [0.4, 'Sniff'], [1.3, 'Footstep', { Side: 'Right' }], [2.2, 'Growl'], [2.94, 'Bite', { Scale: 0.7 }],
        [3.18, 'BreakProp', { Prop: 'CycadCrown', Power: 0.7, At: 'VFX_Head' }], [3.2, 'FoliageBurst', { Scale: 1.5 }], [3.22, 'CameraShake', 0.3],
        [4.83, 'Impact', { At: 'VFX_RightClaw', Scale: 2.2 }], [4.84, 'Impact', { At: 'VFX_LeftClaw', Scale: 1.6 }], [4.85, 'DustRing', { Scale: 2.0 }], [4.86, 'CameraShake', 1.0],
        [5.85, 'Call', { At: 'VFX_Mouth', Scale: 1.6, Color: [255, 225, 160], Count: 5 }], [5.86, 'Roar', { Scale: 1.0 }], [5.88, 'CameraShake', 0.5],
      ],
    },
  },
};
