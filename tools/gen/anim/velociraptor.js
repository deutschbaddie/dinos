// Velociraptor animation profile (source of truth; generates Profiles/Velociraptor.luau).
// Pose entries: Joint: [rx, ry, rz, px, py, pz] (radians / studs). "~Joint" = mirrored Right/Left pair.
const W = (base, extra) => Object.assign({}, base, extra);

const CROUCH = { Pelvis: [0, 0, 0, 0, -0.18, 0], '~Thigh': [0.25], '~Shin': [-0.45], '~Foot': [0.2] };
const SCREECH_A = W(CROUCH, {
  Neck: [-0.1], Head: [0.18, 0, 0], Jaw: [-0.88], Torso: [-0.08],
  '~Arm': [-0.5, 0, 0.8], '~Forearm': [-0.7], '~SickleClaw': [-0.8],
  Tail1: [-0.1, 0.3], Tail2: [-0.05, 0.35], Tail3: [0, 0.4], Tail4: [0, 0.45],
});
const SCREECH_B = W(SCREECH_A, { Jaw: [-0.84], Head: [0.1, 0, 0.12], Tail1: [-0.1, -0.3], Tail2: [-0.05, -0.38], Tail3: [0, -0.42], Tail4: [0, -0.48] });
const SPRINT_READY = {
  Neck: [-0.25], Head: [-0.05], Jaw: [-0.25], Torso: [-0.2], Pelvis: [0, 0, 0, 0, -0.3, 0.15],
  '~Thigh': [0.45], '~Shin': [-0.8], '~Foot': [0.35], '~Arm': [0.4, 0, 0.1], '~Forearm': [-0.6],
  Tail1: [-0.2], Tail2: [-0.15], Tail3: [-0.1],
};
// asleep: belly on the ground, legs folded, neck curled round toward the tail
const SLEEP_A = {
  Pelvis: [0, 0.2, 0.05, 0, -1.25, 0.1], '~Thigh': [1.15], '~Shin': [-2.1], '~Foot': [1.0], Torso: [-0.12, 0.12],
  Neck: [-0.25, 0.55], Head: [-0.15, 0.5, 0.25], Jaw: [0.02], '~Arm': [0.7, 0, 0.2], '~Forearm': [-0.9],
  Tail1: [0.12, 0.35], Tail2: [0.05, 0.4], Tail3: [0, 0.45], Tail4: [0, 0.5],
};
const SLEEP_B = W(SLEEP_A, { Pelvis: [0, 0.2, 0.05, 0, -1.2, 0.1], Torso: [-0.08, 0.12], Neck: [-0.22, 0.55], Head: [-0.12, 0.52, 0.25] });
const HIDDEN = W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.6, 3.0], '~Thigh': [0.6], '~Shin': [-1.0], '~Foot': [0.45], Neck: [-0.4], Head: [-0.2], Torso: [-0.2] });

module.exports = {
  Signature: 'RaptorScreech',
  Intro: 'CinematicIntro',
  IntroShots: 'Leap',
  Chase: 'Chase',
  CycleOrder: ['Walk', 'Run', 'LookAround', 'Sniff', 'Attack', 'Jump', 'Stumble', 'Stunned', 'Roar'],
  CameraScale: 1,
  Gait: {
    Type: 'Biped', Scale: 1,
    Neck: ['Neck'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4'],
    Idle: { Breath: 0.55, BreathAmp: 1.2, Sway: 0.1, Look: 0.5, Twitch: true, JawIdle: 0.04 },
    Walk: { Freq: 1.3, Stride: 0.45, Knee: 0.7, Bob: 0.12, Roll: 0.05, Yaw: 0.07, Lean: 0.06, TailSway: 0.14, HeadBob: 0.06, Speed: 4.5 },
    Run: { Freq: 2.6, Stride: 0.6, Knee: 0.85, Bob: 0.22, Roll: 0.03, Yaw: 0.05, Lean: 0.2, TailSway: 0.08, HeadBob: 0.08, ThighBias: 0, Speed: 13 },
  },
  Actions: {
    Roar: {
      Duration: 2.2, Suppress: 0.9,
      Keys: [
        [0.3, { Neck: [-0.25], Head: [-0.15], Jaw: [-0.15], Torso: [-0.05], Pelvis: [0, 0, 0, 0, -0.08, 0] }, 'Sine'],
        [0.6, { Neck: [0.12], Head: [0.14], Jaw: [-0.88], Torso: [0.1], '~Arm': [-0.3, 0, 0.4], '~Forearm': [-0.6], Tail1: [-0.15], Tail2: [-0.1], Pelvis: [0, 0, 0, 0, 0.05, 0] }, 'Back'],
        [1.6, { Neck: [0.16], Head: [0.16], Jaw: [-0.9], Torso: [0.1], '~Arm': [-0.3, 0, 0.45], '~Forearm': [-0.65], Tail1: [-0.18], Tail2: [-0.12] }, 'Linear'],
      ],
      Shake: [['Head', 0.6, 1.6, 0.07, 18, 3], ['Jaw', 0.6, 1.6, 0.05, 24, 1]],
      Events: [[0.58, 'EyeGlow', 1.2], [0.62, 'Roar', { Scale: 0.6, Screech: true }], [0.65, 'CameraShake', 0.3]],
    },
    RaptorScreech: {
      Duration: 3.2, Suppress: 0.95,
      Keys: [
        [0.4, W(CROUCH, { Neck: [-0.35], Head: [-0.25, 0, 0.1], Jaw: [-0.2], Torso: [-0.12], '~Arm': [-0.2, 0, 0.6], '~Forearm': [-0.4], '~SickleClaw': [-0.6] }), 'Sine'],
        [0.75, SCREECH_A, 'Back'],
        [1.6, SCREECH_B, 'Sine'],
        [2.1, SPRINT_READY, 'Sine'],
        [2.7, SPRINT_READY, 'Linear'],
      ],
      Shake: [['Head', 0.75, 1.6, 0.09, 22, 2], ['Jaw', 0.75, 1.6, 0.06, 30, 1], ['~SickleClaw', 2.1, 2.7, 0.2, 9, 1]],
      Events: [[0.7, 'EyeGlow', 1.5], [0.75, 'Roar', { Scale: 0.5, Screech: true }], [0.78, 'CameraShake', 0.35], [0.8, 'TailSwing', 1.0]],
    },
    Attack: {
      Duration: 1.3, Suppress: 0.9,
      Keys: [
        [0.3, { Neck: [0.2], Head: [0.25], Jaw: [-0.9], Torso: [0.05], Pelvis: [0, 0, 0, 0, -0.1, 0.2] }, 'Out'],
        [0.5, { Neck: [-0.18], Head: [0], Jaw: [-0.8], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.05, -0.6], '~Arm': [0.6, 0, 0.2] }, 'Snap'],
        [0.58, { Neck: [-0.25], Head: [-0.18], Jaw: [0.02], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.05, -0.65], '~Arm': [0.6, 0, 0.2] }, 'Snap'],
        [0.9, { Neck: [-0.05], Head: [0.05], Jaw: [-0.1], Pelvis: [0, 0, 0, 0, 0, -0.2] }, 'Sine'],
      ],
      Events: [[0.58, 'Bite', { Scale: 0.5 }], [0.6, 'CameraShake', 0.2]],
    },
    Stunned: {
      Duration: 2.6, Suppress: 0.9,
      Keys: [
        [0.25, { Pelvis: [0, 0, 0.12, 0, -0.05, 0.4], Torso: [0.2], Neck: [0.3], Head: [0.3, 0, 0.3], Jaw: [-0.4], Tail1: [0.15] }, 'Out'],
        [0.6, { Pelvis: [0, 0, -0.1, 0, -0.12, 0.35], Torso: [-0.05], Neck: [-0.2], Head: [-0.2, 0, -0.3], '~Thigh': [0.2], '~Shin': [-0.35], Jaw: [-0.3] }, 'Sine'],
        [2.0, { Pelvis: [0, 0, 0.05, 0, -0.1, 0.3], Neck: [-0.15], Head: [-0.1, 0, 0.2], '~Thigh': [0.15], '~Shin': [-0.3], Jaw: [-0.25] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.5, T1: 2.3, Rate: 6, Head: [0.28, 0.22], Neck: 0.12, Roll: 0.05 },
      Events: [[0.05, 'Stunned', { Scale: 0.5 }], [0.1, 'CameraShake', 0.25]],
    },
    LookAround: {
      Duration: 3.4, Suppress: 0.6,
      Keys: [
        [0.5, { Neck: [0.15, 0.45], Head: [0.05, 0.4, 0.15] }, 'Sine'],
        [1.1, { Neck: [0.15, 0.5], Head: [0.1, 0.45, 0.1] }, 'Linear'],
        [1.7, { Neck: [0.1, -0.5], Head: [0.05, -0.45, -0.15], Tail2: [0, 0.15] }, 'Snap'],
        [2.4, { Neck: [0.12, -0.5], Head: [0.1, -0.5, -0.1], Tail2: [0, 0.15] }, 'Linear'],
      ],
      Shake: [['Head', 1.1, 1.6, 0.05, 6, 1]],
    },
    Sniff: {
      Duration: 1.8, Suppress: 0.8,
      Keys: [
        [0.5, { Neck: [-0.5], Head: [-0.35], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.1, 0] }, 'Sine'],
        [1.3, { Neck: [-0.5], Head: [-0.35], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.1, 0] }, 'Linear'],
      ],
      Shake: [['Head', 0.5, 1.3, 0.04, 7, 1]],
      Events: [[0.6, 'Sniff']],
    },
    Jump: {
      Duration: 1.6, Suppress: 1,
      Keys: [
        [0.3, { Pelvis: [0, 0, 0, 0, -0.35, 0], '~Thigh': [0.55], '~Shin': [-0.95], '~Foot': [0.4], Torso: [-0.15], Neck: [-0.1], Tail1: [0.1] }, 'Sine'],
        [0.62, { Pelvis: [0, 0, 0, 0, 1.6, 0], '~Thigh': [0.7], '~Shin': [-1.2], '~Foot': [0.6], Torso: [0.1], Neck: [0.15], Head: [0.1], '~Arm': [0.5, 0, 0.3], Tail1: [-0.2], Tail2: [-0.1] }, 'Out'],
        [0.85, { Pelvis: [0, 0, 0, 0, 1.4, 0], '~Thigh': [0.3], '~Shin': [-0.5], '~Foot': [0.2], Torso: [-0.05], '~Arm': [0.3, 0, 0.5], Tail1: [-0.1] }, 'Sine'],
        [1.05, { Pelvis: [0, 0, 0, 0, -0.3, 0], '~Thigh': [0.5], '~Shin': [-0.9], '~Foot': [0.4], Torso: [-0.15], Neck: [-0.15] }, 'In'],
      ],
      Events: [[0.55, 'JumpDust', { Scale: 0.5 }], [1.05, 'Land', { Scale: 0.5 }]],
    },
    Stumble: {
      Duration: 1.4, Suppress: 0.95,
      Keys: [
        [0.25, { Pelvis: [0, 0, -0.15, 0, -0.15, -0.3], Torso: [-0.3], Neck: [-0.3], Head: [-0.2], RightThigh: [0.6], RightShin: [-0.2], LeftThigh: [-0.3], LeftShin: [-0.6], '~Arm': [0.6, 0, 0.3], Tail1: [-0.3], Tail2: [-0.2] }, 'Out'],
        [0.6, { Pelvis: [0, 0, 0.1, 0, -0.2, -0.4], Torso: [-0.2], Neck: [0.1], Head: [0.2], LeftThigh: [0.5], LeftShin: [-0.5], RightThigh: [-0.2], Jaw: [-0.4], Tail1: [-0.2] }, 'Sine'],
      ],
      Events: [[0.3, 'Footstep', { Side: 'Right' }], [0.62, 'Footstep', { Side: 'Left' }]],
    },
    Chase: {
      Duration: 3.4, Suppress: 1,
      Gait: [[0, 2.6, 'Run', 1]],
      Keys: [
        [2.4, { Pelvis: [0, 0, 0, 0, 0, -5.5], Torso: [-0.1] }, 'Linear'],
        [2.7, { Pelvis: [0, 0, 0, 0, 0.4, -6.2], Neck: [0.2], Head: [0.2], Jaw: [-1.0], '~Arm': [0.7, 0, 0.4] }, 'Out'],
        [2.85, { Pelvis: [0, 0, 0, 0, 0.1, -6.6], Neck: [-0.2], Head: [-0.15], Jaw: [0.02] }, 'Snap'],
        [3.15, { Pelvis: [0, 0, 0, 0, 0, -6.6] }, 'Sine'],
      ],
      Events: [[2.85, 'Bite', { Scale: 0.5 }], [2.86, 'CameraShake', 0.3]],
    },
    // Nest guard: curled up asleep (loops), wakes with a screech, and the chase pounce
    Sleep: {
      Duration: 3.6, Suppress: 1, Loop: true, FadeIn: 0.4,
      Keys: [
        [0.0, SLEEP_A, 'Sine'],
        [1.8, SLEEP_B, 'Sine'],
        [3.6, SLEEP_A, 'Sine'],
      ],
    },
    Wake: {
      Duration: 2.0, Suppress: 1, FadeIn: 0.05,
      Keys: [
        [0.0, SLEEP_A, 'Linear'],
        [0.35, W(CROUCH, { Neck: [0.3, 0.3], Head: [0.25, 0.3], Jaw: [-0.3], Torso: [-0.05] }), 'Back'],
        [0.7, SCREECH_A, 'Back'],
        [1.4, SCREECH_B, 'Sine'],
        [1.8, SPRINT_READY, 'Sine'],
      ],
      Shake: [['Head', 0.7, 1.4, 0.09, 22, 2], ['Jaw', 0.7, 1.4, 0.06, 30, 1]],
      Events: [[0.65, 'EyeGlow', 1.4], [0.7, 'Roar', { Scale: 0.5, Screech: true }]],
    },
    Pounce: {
      Duration: 1.35, Suppress: 1, FadeIn: 0.08,
      Keys: [
        [0.15, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.45, 0.2], '~Thigh': [0.7], '~Shin': [-1.2], '~Foot': [0.55], Torso: [-0.25], Neck: [-0.3], Head: [0.1], Jaw: [-0.5], '~Arm': [0.2, 0, 0.5], '~SickleClaw': [-0.9] }), 'Out'],
        [0.75, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.5, 0.25], '~Thigh': [0.75], '~Shin': [-1.25], '~Foot': [0.55], Torso: [-0.28], Neck: [-0.32], Head: [0.12], Jaw: [-0.6], '~Arm': [0.25, 0, 0.55], '~SickleClaw': [-1.0] }), 'Linear'],
        [0.92, { Pelvis: [0, 0, 0, 0, 1.4, -0.6], '~Thigh': [0.8], '~Shin': [-1.3], '~Foot': [0.7], Torso: [0.1], Neck: [0.25], Head: [0.2], Jaw: [-1.0], '~Arm': [0.9, 0, 0.35], '~SickleClaw': [-1.1], Tail1: [-0.25], Tail2: [-0.15] }, 'Out'],
        [1.1, { Pelvis: [0, 0, 0, 0, 0.3, -0.4], Neck: [-0.15], Head: [-0.1], Jaw: [0.02], '~Arm': [0.6, 0, 0.3], Tail1: [-0.1] }, 'Snap'],
      ],
      Shake: [['Jaw', 0.15, 0.75, 0.04, 26, 1]],
      Events: [[0.2, 'Roar', { Scale: 0.35, Screech: true }], [0.78, 'JumpDust', { Scale: 0.5 }], [1.1, 'Bite', { Scale: 0.5 }]],
    },
    // On-stage signature cinematic: leaps in from the back of its platform, lands, screeches
    CinematicIntro: {
      Duration: 4.4, Suppress: 1, FadeIn: 0.01,
      Keys: [
        [0.0, HIDDEN, 'Linear'],
        [0.55, HIDDEN, 'Linear'],
        [0.9, { Pelvis: [0, 0, 0, 0, 1.8, 1.2], '~Thigh': [0.7], '~Shin': [-1.2], '~Foot': [0.6], Torso: [0.1], Neck: [0.2], Head: [0.1], '~Arm': [0.5, 0, 0.4], Tail1: [-0.25] }, 'Out'],
        [1.2, { Pelvis: [0, 0, 0, 0, -0.35, 0], '~Thigh': [0.5], '~Shin': [-0.9], '~Foot': [0.4], Torso: [-0.2], Neck: [-0.25], Head: [-0.1] }, 'In'],
        [1.6, W(CROUCH, { Neck: [-0.35], Head: [-0.25], Jaw: [-0.2], Torso: [-0.12], '~Arm': [-0.2, 0, 0.6], '~SickleClaw': [-0.6] }), 'Sine'],
        [1.95, SCREECH_A, 'Back'],
        [3.0, SCREECH_B, 'Sine'],
        [3.6, SPRINT_READY, 'Sine'],
      ],
      Shake: [['Head', 1.95, 3.0, 0.09, 22, 2], ['Jaw', 1.95, 3.0, 0.06, 30, 1]],
      Events: [[0.6, 'JumpDust', { Scale: 0.6 }], [1.2, 'Land', { Scale: 0.7 }], [1.22, 'CameraShake', 0.3], [1.9, 'EyeGlow', 1.6], [1.95, 'Roar', { Scale: 0.6, Screech: true }], [1.98, 'CameraShake', 0.45], [2.0, 'TailSwing', 1.2]],
    },
  },
};
