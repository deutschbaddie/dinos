// Gallimimus — jumpy, flighty, the fastest thing on two legs. Signature: FLOCK SPRINT (the flock streaks across the
// lens; the lead skids, wheels round, stares... and shrieks). Pose entries: Joint: [rx, ry, rz, px, py, pz].
const { W } = require('./util.js');

const R90 = -Math.PI / 2; // facing +X (running across, left to right)
const SKID = {
  Pelvis: [0, R90 + 0.15, 0, 2.6, -0.75, 0], Torso: [0.2], '~Thigh': [0.75], '~Shin': [-0.55], '~Foot': [-0.1],
  Neck1: [0.05], Neck2: [0.15], Neck3: [0.1], Head: [-0.1], '~Arm': [-0.3, 0, 0.55], '~Forearm': [0.2], Tail1: [-0.25], Tail2: [-0.2], Tail3: [-0.1],
};
// locked on: neck low and forward, head dead level, one eye on you
const STARE = {
  Pelvis: [0, 0, 0, 0, -0.25, 0], '~Thigh': [0.25], '~Shin': [-0.45], '~Foot': [0.2], Torso: [-0.06],
  Neck1: [-0.35], Neck2: [0.05], Neck3: [0.25], Head: [0.1, 0, 0.3], Tail1: [-0.08],
};
const SHRIEK = {
  Pelvis: [0, 0, 0, 0, -0.1, 0.1], '~Thigh': [0.12], '~Shin': [-0.25], '~Foot': [0.1], Torso: [0.08],
  Neck1: [0.28], Neck2: [0.12], Neck3: [-0.1], Head: [0.35], Jaw: [-0.75], '~Arm': [0.35, -0.6, 0.6], '~Forearm': [0.3], Tail1: [-0.3], Tail2: [-0.2], Tail3: [-0.12],
};
const READY = {
  Pelvis: [0, 0, 0, 0, -0.45, 0.2], '~Thigh': [0.45], '~Shin': [-0.8], '~Foot': [0.35], Torso: [-0.2], Neck1: [-0.25], Neck2: [0.05], Neck3: [0.15], Head: [0.05], Jaw: [-0.2], '~Arm': [0.4, 0, 0.1], '~Forearm': [-0.4], Tail1: [-0.15], Tail2: [-0.1],
};

module.exports = {
  Signature: 'FlockSprint', Intro: 'FlockSprint', IntroShots: 'GalliStampede', Chase: 'Chase', Special: 'Sidestep',
  CycleOrder: ['Walk', 'Run', 'LookAround', 'Sidestep', 'Peck', 'FlockKick', 'Stampede', 'Stunned', 'Roar'],
  CameraScale: 2.2,
  Gait: {
    Type: 'Biped', Scale: 2.2, Neck: ['Neck1', 'Neck2', 'Neck3'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5'],
    Idle: { Breath: 0.5, BreathAmp: 1.0, Sway: 0.08, Look: 0.7, Twitch: true, JawIdle: 0.015 },
    Walk: { Freq: 1.0, Stride: 0.38, Knee: 0.75, Bob: 0.14, Roll: 0.03, Yaw: 0.05, Lean: 0.03, TailSway: 0.07, HeadBob: 0.14, Speed: 8 },
    Run: { Freq: 1.9, Stride: 0.62, Knee: 1.05, Bob: 0.28, Roll: 0.02, Yaw: 0.03, Lean: 0.24, TailSway: 0.04, HeadBob: 0.07, ThighBias: 0, Speed: 22 },
  },
  Actions: {
    // a shrill, rattling shriek
    Roar: {
      Duration: 2.2, Suppress: 0.9,
      Keys: [
        [0.35, W(STARE, { Head: [0.05] }), 'Sine'],
        [0.65, SHRIEK, 'Back'],
        [1.6, W(SHRIEK, { Jaw: [-0.72], Head: [0.38] }), 'Linear'],
      ],
      Shake: [['Head', 0.65, 1.6, 0.05, 20, 3], ['Jaw', 0.65, 1.6, 0.05, 26, 1], ['~Forearm', 0.65, 1.6, 0.12, 14, 1]],
      Events: [[0.62, 'Roar', { Scale: 0.8, Screech: true }], [0.64, 'Call', { At: 'VFX_Mouth', Scale: 0.8, Color: [230, 240, 255], Count: 3 }], [0.66, 'CameraShake', 0.3]],
    },
    Attack: {
      Duration: 1.3, Suppress: 0.9,
      Keys: [
        [0.3, { Neck1: [0.2], Neck2: [0.2], Neck3: [0.1], Head: [0.15], Jaw: [-0.4], Pelvis: [0, 0, 0, 0, -0.1, 0.4] }, 'Out'],
        [0.5, { Neck1: [-0.4], Neck2: [-0.2], Neck3: [-0.1], Head: [-0.15], Jaw: [-0.3], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.2, -0.8] }, 'Snap'],
        [0.58, { Neck1: [-0.45], Neck2: [-0.22], Head: [-0.2], Jaw: [0.02], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.2, -0.85] }, 'Snap'],
        [0.95, { Pelvis: [0, 0, 0, 0, 0, -0.3] }, 'Sine'],
      ],
      Events: [[0.58, 'Bite', { Scale: 0.6 }], [0.6, 'CameraShake', 0.2]],
    },
    // TAKEDOWN: a darting beak jab
    Peck: {
      Duration: 1.2, Suppress: 0.92,
      Keys: [
        [0.25, W(STARE, { Neck3: [0.35], Head: [0.2], Jaw: [-0.3] }), 'Out'],
        [0.42, { Neck1: [-0.55], Neck2: [-0.25], Neck3: [-0.1], Head: [-0.2], Jaw: [-0.4], Torso: [-0.2], Pelvis: [0, 0, 0, 0, -0.3, -1.0] }, 'Snap'],
        [0.5, { Neck1: [-0.58], Neck2: [-0.25], Head: [-0.25], Jaw: [0.02], Torso: [-0.2], Pelvis: [0, 0, 0, 0, -0.3, -1.05] }, 'Snap'],
        [0.85, { Neck1: [0.1], Head: [0.15, 0.3, 0.2], Pelvis: [0, 0, 0, 0, 0, -0.3] }, 'Sine'],
      ],
      Events: [[0.5, 'Bite', { Scale: 0.65 }], [0.52, 'CameraShake', 0.2]],
    },
    // TAKEDOWN: the flock wheels round you - a spinning, raking kick
    FlockKick: {
      Duration: 1.8, Suppress: 0.95,
      Keys: [
        [0.3, W(READY, { Pelvis: [0, 0.5, 0, 0, -0.45, 0.2] }), 'Sine'],
        [0.6, { Pelvis: [0, -1.2, 0, 0, 0.6, -0.6], Torso: [0.15], Neck1: [0.1, 0.5], Head: [0.1, 0.4], RightThigh: [1.15], RightShin: [-0.1], RightFoot: [-0.3], LeftThigh: [0.2], LeftShin: [-0.6], Tail1: [0, 0.6], Tail2: [0, 0.5], '~Arm': [0.3, -0.5, 0.6] }, 'Snap'],
        [0.95, { Pelvis: [0, -2.4, 0, 0, 0.2, -0.9], Torso: [0.05], Neck1: [0, 0.4], Head: [0, 0.3], RightThigh: [0.4], RightShin: [-0.8], Tail1: [0, 0.4] }, 'Sine'],
        [1.3, { Pelvis: [0, -3.1, 0, 0, -0.2, -0.8], Neck1: [-0.1] }, 'In'],
      ],
      Events: [[0.6, 'Footstep', { Side: 'Left' }], [0.62, 'Bite', { Scale: 0.6 }], [0.64, 'CameraShake', 0.35], [0.62, 'TailSwing', 0.6], [1.3, 'Land', { Scale: 0.8 }]],
    },
    // TAKEDOWN / chase: an all-out sprint straight through you
    Stampede: {
      Duration: 2.2, Suppress: 1, Gait: [[0.35, 1.8, 'Run', 1]],
      Keys: [[0.35, READY, 'Sine'], [1.75, { Pelvis: [0, 0, 0, 0, -0.1, -12], Torso: [-0.1] }, 'In'], [2.0, { Pelvis: [0, 0, 0, 0, 0, -12.5] }, 'Out']],
      Events: [[0.35, 'Charge', 1.4], [0.4, 'Roar', { Scale: 0.5, Screech: true }]],
    },
    // DODGE: a startled sidestep hop (it sidesteps darts unless you lead the shot)
    Sidestep: {
      Duration: 1.1, Suppress: 0.95,
      Keys: [
        [0.15, W(READY, { Pelvis: [0, 0, 0, 0, -0.5, 0] }), 'Out'],
        [0.4, { Pelvis: [0, 0.3, -0.18, 2.6, 0.8, 0], '~Thigh': [0.6], '~Shin': [-1.0], '~Foot': [0.5], Torso: [0, 0, 0.1], Neck1: [0.1, -0.3], Head: [0, -0.3], Tail1: [0, -0.4], Tail2: [0, -0.3], '~Arm': [0.3, -0.5, 0.6] }, 'Out'],
        [0.65, W(READY, { Pelvis: [0, 0.15, 0, 3.4, -0.4, 0] }), 'In'],
        [1.0, { Pelvis: [0, 0, 0, 3.4, 0, 0] }, 'Sine'],
      ],
      Events: [[0.15, 'JumpDust', { Scale: 0.9 }], [0.65, 'Land', { Scale: 0.7 }]],
    },
    Stunned: {
      Duration: 2.6, Suppress: 0.9,
      Keys: [
        [0.25, { Pelvis: [0, 0, 0.12, 0, -0.1, 0.5], Torso: [0.2], Neck1: [0.3], Neck2: [0.2], Head: [0.3, 0, 0.3], Jaw: [-0.4], '~Arm': [0, 0, 0.6] }, 'Out'],
        [0.6, { Pelvis: [0, 0, -0.1, 0, -0.35, 0.4], Torso: [-0.05], Neck1: [-0.3], Neck2: [-0.1], Head: [-0.2, 0, -0.3], '~Thigh': [0.25], '~Shin': [-0.45], Jaw: [-0.3] }, 'Sine'],
        [2.0, { Pelvis: [0, 0, 0.05, 0, -0.25, 0.3], Neck1: [-0.2], Head: [-0.1, 0, 0.2], '~Thigh': [0.2], '~Shin': [-0.38], Jaw: [-0.25] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.5, T1: 2.3, Rate: 6, Head: [0.3, 0.24], Neck: 0.16, Roll: 0.04 },
      Events: [[0.05, 'Stunned', { Scale: 0.9 }], [0.1, 'CameraShake', 0.3]],
    },
    // twitchy: snaps from point to point, a startled flinch in the middle
    LookAround: {
      Duration: 3.4, Suppress: 0.6,
      Keys: [
        [0.2, { Neck1: [0.1, 0.3], Neck2: [0.05, 0.2], Neck3: [0, 0.1], Head: [0.05, 0.3, 0.25] }, 'Snap'],
        [0.9, { Neck1: [0.1, 0.32], Neck2: [0.05, 0.2], Neck3: [0, 0.1], Head: [0.05, 0.32, 0.27] }, 'Linear'],
        [1.05, { Pelvis: [0, 0, 0, 0, 0.25, 0], Neck1: [0.3], Neck2: [0.15], Head: [0.2], '~Arm': [0.2, 0, 0.4], Tail1: [-0.2] }, 'Snap'],
        [1.5, { Neck1: [0.25], Neck2: [0.1], Head: [0.15] }, 'Sine'],
        [1.7, { Neck1: [0.1, -0.35], Neck2: [0.05, -0.2], Neck3: [0, -0.1], Head: [0.05, -0.3, -0.25], Tail2: [0, 0.15] }, 'Snap'],
        [2.7, { Neck1: [0.1, -0.36], Neck2: [0.05, -0.2], Neck3: [0, -0.1], Head: [0.05, -0.32, -0.27], Tail2: [0, 0.15] }, 'Linear'],
      ],
    },
    Sniff: {
      Duration: 2.0, Suppress: 0.8,
      Keys: [[0.6, { Neck1: [-0.7], Neck2: [-0.3], Neck3: [-0.1], Head: [-0.3], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.2, 0] }, 'Sine'], [1.4, { Neck1: [-0.7], Neck2: [-0.3], Head: [-0.32], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.2, 0] }, 'Linear']],
      Shake: [['Head', 0.6, 1.4, 0.05, 9, 1]],
      Events: [[0.7, 'Sniff']],
    },
    HerdResponse: {
      Duration: 1.6, Suppress: 0.85,
      Keys: [[0.35, SHRIEK, 'Back'], [1.0, W(SHRIEK, { Jaw: [-0.6] }), 'Linear']],
      Events: [[0.35, 'Roar', { Scale: 0.5, Screech: true }]],
    },
    // the chase: it simply outruns the rover, cuts across its nose and kicks
    Chase: {
      Duration: 3.4, Suppress: 1, Gait: [[0, 2.6, 'Run', 1]],
      Keys: [
        [2.2, { Pelvis: [0, 0, 0, 0, 0, -8.5], Torso: [-0.12] }, 'Linear'],
        [2.55, { Pelvis: [0, 0.6, 0, -1.6, 0.4, -9.6], Neck1: [0.1, 0.4], Head: [0.1, 0.4], RightThigh: [1.0], RightShin: [-0.1], '~Arm': [0.3, -0.5, 0.6] }, 'Out'],
        [2.75, { Pelvis: [0, 0.9, 0, -2.4, 0.3, -9.9], RightThigh: [0.2], RightShin: [-0.8], Neck1: [0, 0.3] }, 'Snap'],
        [3.1, { Pelvis: [0, 0.9, 0, -2.6, 0, -10] }, 'Sine'],
      ],
      Events: [[0.2, 'Charge', 2.2], [2.75, 'Bite', { Scale: 0.6 }], [2.76, 'CameraShake', 0.3]],
    },
    // SIGNATURE: FLOCK SPRINT
    FlockSprint: {
      Duration: 5.8, Suppress: 1, FadeIn: 0.01, HoldEnd: true,
      Gait: [[0, 1.42, 'Run', 1]],
      Keys: [
        [0.0, { Pelvis: [0, R90, 0, -13, 0, 0], Torso: [-0.05] }, 'Linear'],
        [1.2, { Pelvis: [0, R90, 0, 1.6, 0, 0], Torso: [-0.05] }, 'Linear'],
        [1.55, SKID, 'Out'],
        [1.75, W(SKID, { Pelvis: [0, R90 + 0.2, 0, 2.7, -0.7, 0] }), 'Sine'],
        [2.05, { Pelvis: [0, -0.75, 0, 1.4, 0.55, -0.3], '~Thigh': [0.55], '~Shin': [-0.95], '~Foot': [0.45], Torso: [0.05], Neck1: [0.1, 0.3], Neck2: [0, 0.2], Head: [0, 0.3], Tail1: [0, -0.5], Tail2: [0, -0.4], Tail3: [0, -0.3], '~Arm': [0.2, -0.4, 0.5] }, 'Out'],
        [2.3, W(STARE, { Pelvis: [0, 0, 0, 0, -0.4, 0], '~Thigh': [0.35], '~Shin': [-0.65], '~Foot': [0.3], Tail1: [0, 0.2], Tail2: [0, 0.15] }), 'In'],
        [2.85, W(STARE, { Head: [0.1, 0, 0.32] }), 'Sine'],
        [3.05, W(STARE, { Head: [0.12, 0, -0.18] }), 'Snap'],
        [3.4, W(STARE, { Head: [0.12, 0, -0.2], Neck3: [0.3] }), 'Linear'],
        [3.68, SHRIEK, 'Back'],
        [4.8, W(SHRIEK, { Jaw: [-0.72], Head: [0.38] }), 'Linear'],
        [5.3, READY, 'Sine'],
        [5.8, READY, 'Linear'],
      ],
      Shake: [['Pelvis', 1.3, 1.75, 0.04, 16, 3], ['Head', 3.68, 4.8, 0.05, 20, 3], ['Jaw', 3.68, 4.8, 0.05, 26, 1], ['~Forearm', 3.68, 4.8, 0.12, 14, 1]],
      Events: [
        [0.0, 'FlockRush', { Count: 6, From: -30, To: 34, Time: 2.2 }],
        [1.22, 'Scrape', { At: 'VFX_RightFoot' }], [1.3, 'Scrape', { At: 'VFX_LeftFoot' }], [1.4, 'Scrape', { At: 'VFX_RightFoot' }], [1.36, 'CameraShake', 0.25],
        [2.05, 'JumpDust', { Scale: 0.8 }], [2.3, 'Land', { Scale: 0.7 }], [2.86, 'EyeGlow', 0.8],
        [3.66, 'Roar', { Scale: 0.9, Screech: true }], [3.68, 'Call', { At: 'VFX_Mouth', Scale: 0.9, Color: [235, 244, 255], Count: 4 }], [3.7, 'CameraShake', 0.4],
      ],
    },
  },
};
