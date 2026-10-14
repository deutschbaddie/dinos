// Tyrannosaurus Rex animation profile (source of truth; generates Profiles/TyrannosaurusRex.luau).
const W = (base, extra) => Object.assign({}, base, extra);

const ROAR_POSE = {
  Neck1: [-0.06], Neck2: [-0.02], Head: [0.1], Jaw: [-0.82], Torso: [-0.04],
  Chest: [0, 0, 0, 0, -0.25, -0.3], Pelvis: [0, 0, 0, 0, -0.1, -0.9],
  '~Arm': [-0.35, 0, 0.3], '~Forearm': [-0.6],
  Tail1: [-0.15], Tail2: [-0.1], Tail3: [-0.06],
};
const CREEP = { Neck1: [-0.16], Neck2: [-0.12], Head: [-0.08], Torso: [-0.05] };

module.exports = {
  Signature: 'TheKingsRoar',
  Intro: 'TheKingsRoar',
  IntroShots: 'Emerge',
  Chase: 'Chase',
  CycleOrder: ['Walk', 'Run', 'LookAround', 'Sniff', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 3.2,
  Gait: {
    Type: 'Biped', Scale: 3.2,
    Neck: ['Neck1', 'Neck2'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5'],
    Idle: { Breath: 0.22, BreathAmp: 1.0, Sway: 0.06, Look: 0.22, Twitch: false, JawIdle: 0.045 },
    Walk: { Freq: 0.55, Stride: 0.38, Knee: 0.65, Bob: 0.12, Roll: 0.035, Yaw: 0.05, Lean: 0.04, TailSway: 0.08, HeadBob: 0.04, Speed: 6 },
    Run: { Freq: 0.95, Stride: 0.5, Knee: 0.9, Bob: 0.2, Roll: 0.025, Yaw: 0.04, Lean: 0.14, TailSway: 0.05, HeadBob: 0.06, ThighBias: 0, Speed: 16 },
  },
  Actions: {
    Roar: {
      Duration: 3.2, Suppress: 0.92,
      Keys: [
        [0.5, { Neck1: [-0.12], Neck2: [-0.1], Head: [-0.12], Jaw: [-0.08], Torso: [-0.04], Chest: [0, 0, 0, 0, 0.1, 0.2], Pelvis: [0, 0, 0, 0, -0.2, 0.2], Tail1: [0.05] }, 'Sine'],
        [0.95, { Neck1: [0.12], Neck2: [0.08], Head: [0.05], Jaw: [-0.95], Torso: [0.06], Chest: [0, 0, 0, 0, -0.25, -0.45], Pelvis: [0, 0, 0, 0, 0.1, -0.25], '~Arm': [-0.3, 0, 0.25], '~Forearm': [-0.5], Tail1: [-0.12], Tail2: [-0.08], Tail3: [-0.05] }, 'Back'],
        [2.4, { Neck1: [0.16], Neck2: [0.1], Head: [0.08], Jaw: [-1.0], Torso: [0.07], Chest: [0, 0, 0, 0, -0.3, -0.5], Pelvis: [0, 0, 0, 0, 0.1, -0.3], '~Arm': [-0.35, 0, 0.3], '~Forearm': [-0.6], Tail1: [-0.14], Tail2: [-0.1], Tail3: [-0.07] }, 'Linear'],
      ],
      Shake: [['Head', 0.95, 2.4, 0.04, 14, 3], ['Jaw', 0.95, 2.4, 0.03, 20, 1], ['Neck2', 0.95, 2.4, 0.02, 9, 2], ['~Forearm', 1.0, 2.3, 0.15, 7, 1]],
      Events: [[0.9, 'EyeGlow', 1.8], [0.95, 'Roar', { Scale: 1.6 }], [0.95, 'CameraShake', 0.9]],
    },
    Attack: {
      Duration: 1.9, Suppress: 0.95,
      Keys: [
        [0.45, { Neck1: [0.2], Neck2: [0.12], Head: [0.2], Jaw: [-0.85], Torso: [0.08], Pelvis: [0, 0, 0, 0, -0.15, 0.8], Tail1: [0.08] }, 'Out'],
        [0.75, { Neck1: [-0.12], Neck2: [-0.08], Head: [0], Jaw: [-0.78], Torso: [-0.14], Pelvis: [0, 0, 0, 0, -0.35, -2.6], RightThigh: [0.35], RightShin: [-0.3], LeftThigh: [-0.15], Tail1: [-0.15], Tail2: [-0.1] }, 'Snap'],
        [0.86, { Neck1: [-0.2], Neck2: [-0.16], Head: [-0.18], Jaw: [0.03], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.38, -2.8], RightThigh: [0.35], RightShin: [-0.3], LeftThigh: [-0.15], Tail1: [-0.15], Tail2: [-0.1] }, 'Snap'],
        [1.3, { Neck1: [-0.05], Head: [0.05, 0.15, 0.1], Jaw: [-0.05], Pelvis: [0, 0, 0, 0, -0.1, -1.2] }, 'Sine'],
      ],
      Shake: [['Head', 0.9, 1.4, 0.12, 5, 2]],
      Events: [[0.75, 'Footstep', { Side: 'Right' }], [0.86, 'Bite', { Scale: 1.5 }], [0.88, 'CameraShake', 0.6]],
    },
    Stunned: {
      Duration: 3.0, Suppress: 0.92,
      Keys: [
        [0.3, { Pelvis: [0, 0.08, 0.1, 0, -0.2, 1.4], Torso: [0.12], Neck1: [0.08, 0.15], Neck2: [0.04], Head: [0.03, 0.12, 0.18], Jaw: [-0.3], Tail1: [0.12], Tail2: [0.08] }, 'Out'],
        [0.8, { Pelvis: [0, -0.05, -0.08, 0, -0.55, 1.2], Torso: [-0.08], Neck1: [-0.12], Neck2: [-0.08], Head: [0, -0.1, -0.16], '~Thigh': [0.22], '~Shin': [-0.38], '~Foot': [0.12], Jaw: [-0.35] }, 'Sine'],
        [2.2, { Pelvis: [0, 0, 0.04, 0, -0.4, 0.9], Neck1: [-0.1], Head: [-0.08, 0, 0.15], '~Thigh': [0.18], '~Shin': [-0.32], '~Foot': [0.1], Jaw: [-0.25] }, 'Linear'],
        [2.6, { Neck1: [0.05], Head: [0.05], Jaw: [-0.1] }, 'Sine'],
      ],
      Shake: [['Head', 2.35, 2.85, 0.12, 6.4, 3]],
      Procedural: { Type: 'Dizzy', T0: 0.7, T1: 2.4, Rate: 4, Head: [0.12, 0.12], Neck: 0.08, Roll: 0.04 },
      Events: [[0.05, 'Stunned', { Scale: 1.5 }], [0.1, 'CameraShake', 0.6], [0.32, 'Footstep', { Side: 'Left' }]],
    },
    LookAround: {
      Duration: 4.2, Suppress: 0.65,
      Keys: [
        [0.8, { Neck1: [0.08, 0.2], Neck2: [0.06, 0.18], Head: [0.06, 0.12, 0.1] }, 'Sine'],
        [1.6, { Neck1: [0.08, 0.21], Neck2: [0.06, 0.19], Head: [0.12, 0.13, 0.06] }, 'Linear'],
        [2.6, { Neck1: [0.06, -0.2], Neck2: [0.05, -0.18], Head: [0.05, -0.12, -0.1], Tail2: [0, 0.1], Tail3: [0, 0.12] }, 'Sine'],
        [3.4, { Neck1: [0.06, -0.21], Neck2: [0.05, -0.19], Head: [0.12, -0.13, -0.06], Tail2: [0, 0.1], Tail3: [0, 0.12] }, 'Linear'],
      ],
      Shake: [['Head', 1.6, 2.0, 0.03, 4, 1], ['Head', 3.4, 3.8, 0.03, 4, 1]],
      Events: [[1.7, 'Sniff']],
    },
    Sniff: {
      Duration: 2.4, Suppress: 0.85,
      Keys: [
        [0.7, { Neck1: [-0.25], Neck2: [-0.2], Head: [-0.2], Torso: [-0.08], Pelvis: [0, 0, 0, 0, -0.3, 0], Tail1: [-0.06] }, 'Sine'],
        [1.7, { Neck1: [-0.25], Neck2: [-0.2], Head: [-0.22], Torso: [-0.08], Pelvis: [0, 0, 0, 0, -0.3, 0], Tail1: [-0.06] }, 'Linear'],
      ],
      Shake: [['Head', 0.7, 1.7, 0.03, 5, 1]],
      Events: [[0.8, 'Sniff']],
    },
    Chase: {
      Duration: 4.2, Suppress: 1,
      Gait: [[0, 3.2, 'Run', 1]],
      Keys: [
        [3.0, { Pelvis: [0, 0, 0, 0, 0, -7.5], Torso: [-0.08], Neck1: [0.05] }, 'Linear'],
        [3.35, { Pelvis: [0, 0, 0, 0, -0.2, -8.4], Neck1: [0.2], Neck2: [0.12], Head: [0.18], Jaw: [-1.0] }, 'Out'],
        [3.5, { Pelvis: [0, 0, 0, 0, -0.35, -9.0], Neck1: [-0.2], Neck2: [-0.15], Head: [-0.15], Jaw: [0.03] }, 'Snap'],
        [3.9, { Pelvis: [0, 0, 0, 0, -0.1, -9.0] }, 'Sine'],
      ],
      Events: [[3.5, 'Bite', { Scale: 1.5 }], [3.52, 'CameraShake', 0.8]],
    },
    // SIGNATURE / INTRO: emerges from the jungle, notices the player, tilts its head, roars into the camera
    TheKingsRoar: {
      Duration: 7.2, Suppress: 1, FadeIn: 0.01,
      Gait: [[0.0, 2.45, 'Walk', 1]],
      Keys: [
        [0.0, W(CREEP, { Pelvis: [0, 0, 0, 0, -0.3, 14.0], Neck1: [-0.18], Neck2: [-0.12], Head: [-0.1], Torso: [-0.06] }), 'Linear'],
        [2.4, W(CREEP, { Pelvis: [0, 0, 0, 0, -0.2, 0] }), 'Sine'],
        [3.0, { Neck1: [0.05, -0.1], Neck2: [0.05, -0.08], Head: [-0.05, -0.08], Pelvis: [0, 0, 0, 0, -0.1, 0] }, 'Sine'],
        [3.7, { Neck1: [0.05], Neck2: [0.06], Head: [0, 0.05, 0.28], Jaw: [-0.06] }, 'Sine'],
        [4.3, { Neck1: [0.14], Neck2: [0.08], Head: [0.15, 0, 0.05], Jaw: [-0.12], Torso: [0.04], Chest: [0, 0, 0, 0, 0.12, 0.22], Pelvis: [0, 0, 0, 0, -0.15, 0.35] }, 'Sine'],
        [4.7, ROAR_POSE, 'Back'],
        [6.3, W(ROAR_POSE, { Jaw: [-0.78], Head: [0.12] }), 'Linear'],
      ],
      Shake: [['Head', 4.7, 6.3, 0.045, 13, 3], ['Jaw', 4.7, 6.3, 0.035, 20, 1], ['Neck2', 4.7, 6.3, 0.025, 8, 2], ['~Forearm', 4.8, 6.2, 0.18, 7, 1]],
      Events: [
        [0.0, 'CurtainClose'], [0.85, 'CurtainOpen'], [0.9, 'FoliageBurst', { Scale: 1.4 }],
        [3.65, 'Growl'], [4.6, 'EyeGlow', 2.2], [4.7, 'Roar', { Scale: 1.9 }], [4.7, 'CameraShake', 1.0],
      ],
    },
  },
};
