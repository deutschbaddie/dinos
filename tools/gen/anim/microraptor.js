// Microraptor — twitchy little four-winged glider. Signature: SHADOW GLIDE (drops off a branch, swoops past the
// lens, pirouettes onto a stump and flashes all four wings in an iridescent display, then hops down).
// Pelvis carries the flight path (offset in studs) + yaw/roll; Torso / Tail carry body-relative pitch.
const { W } = require('./util.js');

const SPREAD = { '~Arm': [0, 1.4, -1.57], '~Forearm': [0, 0.12, 0] }; // wings flat out
const HALF = { '~Arm': [0, 0.8, -1.1] };
const FOLD = { '~Arm': [0, 0, 0], '~Forearm': [0, 0, 0] };
const TRAIL = { '~Thigh': [-1.15, 0, 0.45], '~Shin': [-0.15], '~Foot': [-0.45] }; // legs trail back: the hind wings
const CROUCH = { '~Thigh': [0.3], '~Shin': [-0.55], '~Foot': [0.25] };
const GLIDE = W(W(SPREAD, TRAIL), { Neck: [-0.35], Head: [0.3], Jaw: [-0.08], Tail1: [-0.08], Tail2: [-0.04] });
const DISPLAY = {
  '~Arm': [0, 1.45, 0.05], '~Forearm': [-0.5, 0, 0], '~Thigh': [0.35, 0, 0.4], '~Shin': [-0.65], '~Foot': [0.3],
  Torso: [0.0], Neck: [-0.05], Head: [-0.12, 0, 0.12], Jaw: [-0.7], Tail1: [-0.55], Tail2: [-0.45], Tail3: [-0.35], Tail4: [-0.25],
};
const P = (x, y, z, rx = 0, ry = 0, rz = 0) => ({ Pelvis: [rx, ry, rz, x, y, z] });
const PERCH = W(CROUCH, { Pelvis: [0, 0, 0, -1.5, 5.52, 5.5], Torso: [-0.12], Neck: [0.15], Head: [-0.1], Tail1: [0.35], Tail2: [0.2], Tail3: [0.1] });

module.exports = {
  Signature: 'ShadowGlide', Intro: 'ShadowGlide', IntroShots: 'MicroShadowGlide', Chase: 'Chase', Special: 'Glide',
  CycleOrder: ['Walk', 'Run', 'Glide', 'WingDisplay', 'LookAround', 'Peck', 'DiveStrike', 'WingBuffet', 'Climb', 'Stunned', 'Roar'],
  CameraScale: 0.6,
  Gait: {
    Type: 'Biped', Scale: 0.5, Neck: ['Neck'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4'],
    Idle: { Breath: 0.95, BreathAmp: 1.2, Sway: 0.12, Look: 0.9, Twitch: true, JawIdle: 0.03 },
    Walk: { Freq: 2.1, Stride: 0.48, Knee: 0.75, Bob: 0.14, Roll: 0.05, Yaw: 0.08, Lean: 0.08, TailSway: 0.16, HeadBob: 0.09, Speed: 4 },
    Run: { Freq: 3.7, Stride: 0.62, Knee: 0.9, Bob: 0.22, Roll: 0.03, Yaw: 0.05, Lean: 0.24, TailSway: 0.08, HeadBob: 0.1, ThighBias: 0, Speed: 12 },
  },
  Actions: {
    // a shrill chirp-screech with the wings half flared and the crest up
    Roar: {
      Duration: 1.8, Suppress: 0.9,
      Keys: [
        [0.25, W(CROUCH, { Neck: [-0.2], Head: [-0.2], Torso: [-0.1], Pelvis: [0, 0, 0, 0, -0.08, 0] }), 'Sine'],
        [0.45, W(HALF, { Neck: [0.25], Head: [0.25], Jaw: [-0.85], Torso: [0.12], Tail1: [-0.3], Tail2: [-0.2] }), 'Back'],
        [1.3, W(HALF, { Neck: [0.28], Head: [0.28, 0, 0.1], Jaw: [-0.8], Torso: [0.12], Tail1: [-0.32], Tail2: [-0.22] }), 'Linear'],
      ],
      Shake: [['Head', 0.45, 1.3, 0.1, 24, 2], ['Jaw', 0.45, 1.3, 0.08, 30, 1], ['~Arm', 0.5, 1.2, 0.08, 14, 3]],
      Events: [[0.42, 'EyeGlow', 1.0], [0.45, 'Roar', { Scale: 0.3, Screech: true }], [0.47, 'Iridesce', 0.8], [0.5, 'CameraShake', 0.12]],
    },
    // quick snapping peck
    Attack: {
      Duration: 0.95, Suppress: 0.9,
      Keys: [
        [0.2, { Neck: [0.25], Head: [0.3], Jaw: [-0.8], Pelvis: [0, 0, 0, 0, -0.05, 0.15], Tail1: [-0.2] }, 'Out'],
        [0.36, { Neck: [-0.35], Head: [-0.2], Jaw: [-0.7], Torso: [-0.2], Pelvis: [0, 0, 0, 0, -0.08, -0.45] }, 'Snap'],
        [0.42, { Neck: [-0.4], Head: [-0.3], Jaw: [0.02], Torso: [-0.2], Pelvis: [0, 0, 0, 0, -0.08, -0.5] }, 'Snap'],
        [0.7, { Neck: [-0.05], Head: [0.05], Pelvis: [0, 0, 0, 0, 0, -0.15] }, 'Sine'],
      ],
      Events: [[0.42, 'Bite', { Scale: 0.3 }]],
    },
    Peck: {
      Duration: 1.1, Suppress: 0.9,
      Keys: [
        [0.18, { Neck: [0.3], Head: [0.3], Jaw: [-0.7], Tail1: [-0.25], ...HALF }, 'Out'],
        [0.32, { Neck: [-0.4], Head: [-0.3], Jaw: [0.02], Torso: [-0.2], Pelvis: [0, 0, 0, 0, -0.08, -0.5] }, 'Snap'],
        [0.5, { Neck: [0.2], Head: [0.25], Jaw: [-0.6], Pelvis: [0, 0, 0, 0, 0, -0.3] }, 'Out'],
        [0.62, { Neck: [-0.4], Head: [-0.3], Jaw: [0.02], Torso: [-0.2], Pelvis: [0, 0, 0, 0, -0.08, -0.6] }, 'Snap'],
        [0.85, { Neck: [0], Head: [0.05], Pelvis: [0, 0, 0, 0, 0, -0.2] }, 'Sine'],
      ],
      Events: [[0.32, 'Bite', { Scale: 0.25 }], [0.62, 'Bite', { Scale: 0.3 }]],
    },
    // TAKEDOWN: from a crouch, it springs up and dives along a line, wings swept, claws first
    DiveStrike: {
      Duration: 1.6, Suppress: 1,
      Keys: [
        [0.3, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.12, 0.2], Torso: [-0.2], Neck: [-0.2], Head: [0.1], Jaw: [-0.4], ...HALF, Tail1: [-0.2] }), 'Sine'],
        [0.55, W(GLIDE, { Pelvis: [0, 0, 0, 0, 1.6, -1.6], Torso: [0.15] }), 'Out'],
        [0.85, W(GLIDE, { Pelvis: [0, 0, 0, 0, 0.4, -5.0], Torso: [-0.25], '~Thigh': [0.6, 0, 0.2], '~Shin': [-0.3], Jaw: [-0.9] }), 'In'],
        [0.95, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.1, -5.4], Torso: [-0.2], Neck: [-0.35], Head: [-0.2], Jaw: [0.02], ...HALF }), 'Snap'],
        [1.3, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.05, -5.4], ...FOLD }), 'Sine'],
      ],
      Events: [[0.32, 'SnowPuff', { At: 'VFX_RightFoot', Scale: 0.5 }], [0.95, 'Bite', { Scale: 0.4 }], [0.96, 'Land', { Scale: 0.3 }], [0.97, 'CameraShake', 0.2]],
    },
    // TAKEDOWN: hovers on the spot in a flurry of wingbeats (everything around gets buffeted)
    WingBuffet: {
      Duration: 1.7, Suppress: 1,
      Keys: [
        [0.25, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.1, 0], ...HALF, Tail1: [-0.2] }), 'Sine'],
        [0.45, W(SPREAD, { Pelvis: [0, 0, 0, 0, 0.9, 0], Torso: [0.35], Neck: [0.1], Head: [-0.1], Jaw: [-0.7], '~Thigh': [0.5, 0, 0.3], '~Shin': [-0.4], Tail1: [0.2], Tail2: [0.1] }), 'Out'],
        [1.2, W(SPREAD, { Pelvis: [0, 0, 0, 0, 1.0, 0], Torso: [0.35], Neck: [0.1], Head: [-0.1], Jaw: [-0.7], '~Thigh': [0.5, 0, 0.3], '~Shin': [-0.4], Tail1: [0.2], Tail2: [0.1] }), 'Linear'],
        [1.45, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.1, 0] }), 'In'],
      ],
      Shake: [['~Arm', 0.45, 1.25, 0.55, 9, 3], ['Pelvis', 0.45, 1.25, 0.06, 4.5, 1]],
      Events: [[0.45, 'SnowPuff', { At: 'VFX_Chest', Scale: 0.9 }], [0.8, 'SnowPuff', { At: 'VFX_RightFoot', Scale: 0.8 }], [1.1, 'Roar', { Scale: 0.25, Screech: true }], [1.45, 'Land', { Scale: 0.25 }]],
    },
    Stunned: {
      Duration: 2.4, Suppress: 0.9,
      Keys: [
        [0.2, { Pelvis: [0, 0, 0.15, 0, -0.05, 0.3], Torso: [0.2], Neck: [0.3], Head: [0.35, 0, 0.35], Jaw: [-0.4], '~Arm': [0, 0.3, -0.4] }, 'Out'],
        [0.55, W(CROUCH, { Pelvis: [0, 0, -0.1, 0, -0.12, 0.25], Torso: [-0.1], Neck: [-0.25], Head: [-0.2, 0, -0.3], Jaw: [-0.3], '~Arm': [0, 0.3, -0.5], Tail1: [0.2] }), 'Sine'],
        [1.9, W(CROUCH, { Pelvis: [0, 0, 0.05, 0, -0.1, 0.2], Neck: [-0.15], Head: [-0.1, 0, 0.2], Jaw: [-0.25], '~Arm': [0, 0.2, -0.3] }), 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.45, T1: 2.15, Rate: 7, Head: [0.3, 0.25], Neck: 0.14, Roll: 0.06 },
      Events: [[0.05, 'Stunned', { Scale: 0.35 }], [0.1, 'CameraShake', 0.15]],
    },
    // bird-like head snaps: look, freeze, look
    LookAround: {
      Duration: 2.8, Suppress: 0.6,
      Keys: [
        [0.15, { Neck: [0.15, 0.4], Head: [0.05, 0.55, 0.2] }, 'Snap'],
        [0.7, { Neck: [0.15, 0.42], Head: [0.05, 0.57, 0.2] }, 'Linear'],
        [0.85, { Neck: [0.2, -0.1], Head: [0.25, -0.1, -0.35] }, 'Snap'],
        [1.4, { Neck: [0.2, -0.1], Head: [0.25, -0.12, -0.38] }, 'Linear'],
        [1.55, { Neck: [0.1, -0.45], Head: [0.05, -0.55, -0.15], Tail2: [0, 0.2] }, 'Snap'],
        [2.2, { Neck: [0.1, -0.46], Head: [0.05, -0.56, -0.15], Tail2: [0, 0.2] }, 'Linear'],
      ],
    },
    Sniff: {
      Duration: 1.5, Suppress: 0.8,
      Keys: [
        [0.3, { Neck: [-0.45], Head: [-0.3], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.06, 0] }, 'Sine'],
        [1.1, { Neck: [-0.45], Head: [-0.3], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.06, 0] }, 'Linear'],
      ],
      Shake: [['Head', 0.3, 1.1, 0.06, 9, 1]],
      Events: [[0.4, 'Sniff']],
    },
    // the reveal flourish: all four wings snap open in an iridescent flash, a chirp, a cocked head
    WingDisplay: {
      Duration: 2.4, Suppress: 1, FadeIn: 0.1,
      Keys: [
        [0.2, W(CROUCH, { Torso: [-0.05], Neck: [-0.1], Head: [-0.05], '~Arm': [0, 0.35, -0.4], Tail1: [-0.1] }), 'Sine'],
        [0.45, DISPLAY, 'Back'],
        [1.3, W(DISPLAY, { Head: [-0.1, 0.15, 0.3], Jaw: [-0.5] }), 'Sine'],
        [1.8, W(DISPLAY, { Head: [-0.1, -0.1, -0.2], Jaw: [-0.1] }), 'Sine'],
      ],
      Shake: [['Jaw', 0.5, 1.1, 0.25, 11, 1], ['~Arm', 0.45, 1.8, 0.05, 7, 2], ['Tail4', 0.45, 1.8, 0.12, 5, 2]],
      Events: [[0.45, 'Iridesce', 1.4], [0.5, 'Roar', { Scale: 0.3, Screech: true }], [0.52, 'Call', { At: 'VFX_Mouth', Scale: 0.35, Color: [70, 225, 240], Count: 3 }]],
    },
    // BUDDY GLIDE: held glide pose (the engine moves the root); wings ripple
    Glide: {
      Duration: 2.4, Suppress: 1, FadeIn: 0.15,
      Keys: [
        [0.25, W(GLIDE, { Pelvis: [0, 0, 0, 0, 0.6, 0] }), 'Out'],
        [1.2, W(GLIDE, { Pelvis: [0, 0, -0.08, 0, 0.7, 0], Head: [0.3, 0.1] }), 'Sine'],
        [2.1, W(GLIDE, { Pelvis: [0, 0, 0.08, 0, 0.6, 0], Head: [0.3, -0.1] }), 'Sine'],
      ],
      Shake: [['~Forearm', 0.3, 2.2, 0.05, 3, 1], ['Tail3', 0.3, 2.2, 0.08, 2, 2]],
    },
    // climbing a trunk: body pitched nose-up, limbs alternating (the engine moves the root up the tree)
    Climb: {
      Duration: 1.2, Suppress: 1, Loop: true, FadeIn: 0.2,
      Keys: [
        [0.0, { Pelvis: [1.35, 0, 0, 0, 0.9, 0.4], Neck: [-0.5], Head: [-0.3], RightArm: [0.4, 0.3, -0.5], LeftArm: [-0.1, -0.3, 0.5], RightThigh: [0.9], RightShin: [-0.9], LeftThigh: [0.4], LeftShin: [-0.5], Tail1: [-0.3] }, 'Sine'],
        [0.6, { Pelvis: [1.35, 0, 0, 0, 0.9, 0.4], Neck: [-0.5], Head: [-0.3], RightArm: [-0.1, 0.3, -0.5], LeftArm: [0.4, -0.3, 0.5], LeftThigh: [0.9], LeftShin: [-0.9], RightThigh: [0.4], RightShin: [-0.5], Tail1: [-0.3] }, 'Sine'],
        [1.2, { Pelvis: [1.35, 0, 0, 0, 0.9, 0.4], Neck: [-0.5], Head: [-0.3], RightArm: [0.4, 0.3, -0.5], LeftArm: [-0.1, -0.3, 0.5], RightThigh: [0.9], RightShin: [-0.9], LeftThigh: [0.4], LeftShin: [-0.5], Tail1: [-0.3] }, 'Sine'],
      ],
    },
    // chase: sprints, springs and glides in to drop onto the rover
    Chase: {
      Duration: 3.4, Suppress: 1,
      Gait: [[0, 2.3, 'Run', 1]],
      Keys: [
        [2.2, { Pelvis: [0, 0, 0, 0, 0, -4.6], Torso: [-0.1] }, 'Linear'],
        [2.45, W(GLIDE, { Pelvis: [0, 0, 0, 0, 1.4, -5.6], Torso: [0.15] }), 'Out'],
        [2.85, W(GLIDE, { Pelvis: [0, 0, 0, 0, 0.8, -7.4], Torso: [-0.2], '~Thigh': [0.7, 0, 0.2], '~Shin': [-0.4], Jaw: [-0.9] }), 'Sine'],
        [3.0, W(CROUCH, { Pelvis: [0, 0, 0, 0, 0.1, -7.8], Neck: [-0.3], Head: [-0.2], Jaw: [0.02], ...HALF }), 'Snap'],
        [3.3, W(CROUCH, { Pelvis: [0, 0, 0, 0, 0, -7.8] }), 'Sine'],
      ],
      Events: [[2.3, 'SnowPuff', { At: 'VFX_RightFoot', Scale: 0.5 }], [3.0, 'Bite', { Scale: 0.4 }], [3.01, 'CameraShake', 0.2]],
    },
    // SIGNATURE: perched up a frosted branch it twitches, spots you, drops, swoops past the lens, pirouettes
    // onto a stump, and flashes all four wings in an iridescent shimmer with a chirp - then hops down
    ShadowGlide: {
      Duration: 6.4, Suppress: 1, FadeIn: 0.01,
      Keys: [
        [0.0, PERCH, 'Linear'],
        [0.3, W(PERCH, { Neck: [0.25, 0.35], Head: [0.05, 0.5, 0.2] }), 'Snap'],
        [0.6, W(PERCH, { Neck: [0.25, 0.35], Head: [0.05, 0.52, 0.2] }), 'Linear'],
        [0.72, W(PERCH, { Neck: [0.2, -0.3], Head: [0.1, -0.45, -0.25] }), 'Snap'],
        [0.95, W(PERCH, { Neck: [0.2, -0.3], Head: [0.1, -0.46, -0.25] }), 'Linear'],
        [1.05, W(PERCH, { Neck: [-0.15], Head: [-0.45, 0, 0.3], Torso: [-0.25] }), 'Snap'],
        [1.25, W(W(PERCH, CROUCH), { Pelvis: [0, 0, 0, -1.5, 5.44, 5.5], '~Thigh': [0.45], '~Shin': [-0.8], '~Foot': [0.35], Neck: [-0.3], Head: [-0.35], Torso: [-0.12], '~Arm': [0, 0.5, -0.6] }), 'Sine'],
        [1.42, W(GLIDE, { ...P(-1.4, 5.8, 4.8, -0.15, 0, 0), Torso: [0.1] }), 'Out'],
        [1.68, W(GLIDE, { ...P(-0.6, 4.6, 3.1, -0.4, -0.35, -0.25), Torso: [-0.15] }), 'Linear'],
        [1.98, W(GLIDE, { ...P(1.5, 3.1, 0.4, -0.25, -0.5, -0.4) }), 'Linear'],
        [2.28, W(GLIDE, { ...P(2.9, 2.1, -2.5, -0.1, 0.3, 0.45) }), 'Linear'],
        [2.58, W(GLIDE, { ...P(1.2, 1.55, -4.4, 0, 1.4, 0.6) }), 'Linear'],
        [2.88, W(GLIDE, { ...P(-2.1, 1.7, -3.5, 0, 2.3, 0.55) }), 'Linear'],
        [3.12, W(GLIDE, { ...P(-2.3, 1.9, -0.9, 0, 2.9, 0.3), Torso: [0.2] }), 'Sine'],
        [3.3, W(SPREAD, { ...P(-0.9, 1.7, 0.9, 0, 3.14, 0), Torso: [0.55], Neck: [0.1], Head: [-0.2], '~Thigh': [0.9, 0, 0.2], '~Shin': [-0.6], '~Foot': [0.2], Tail1: [0.3], Tail2: [0.2] }), 'Sine'],
        [3.46, W(CROUCH, { ...P(0, 0.74, 1.4, 0, 0, 0), '~Thigh': [0.45], '~Shin': [-0.85], '~Foot': [0.4], Torso: [0.0], Neck: [-0.3], Head: [-0.1], ...HALF, Tail1: [-0.2] }), 'Out'],
        [3.7, W(CROUCH, { ...P(0, 0.76, 1.4), Torso: [-0.05], Neck: [0.1], Head: [0.05], '~Arm': [0, 0.35, -0.45] }), 'Sine'],
        [3.95, W(DISPLAY, P(0, 0.72, 1.4)), 'Back'],
        [4.55, W(DISPLAY, { ...P(0, 0.72, 1.4, 0, 0.12, 0), Head: [0.15, 0.2, 0.25], Jaw: [-0.75] }), 'Sine'],
        [4.95, W(DISPLAY, { ...P(0, 0.72, 1.4, 0, -0.08, 0), Head: [0.1, -0.15, -0.2], Jaw: [-0.2] }), 'Sine'],
        [5.2, W(CROUCH, { ...P(0, 0.64, 1.4), '~Thigh': [0.4], '~Shin': [-0.75], '~Foot': [0.32], Torso: [0.05], Neck: [-0.1], '~Arm': [0, 0.5, -0.6], Tail1: [-0.15] }), 'Sine'],
        [5.45, W(SPREAD, { ...P(0, 1.35, 0.7), '~Thigh': [0.2], '~Shin': [-0.3], Torso: [0.1], Tail1: [0.1] }), 'Out'],
        [5.68, W(CROUCH, { ...P(0, -0.06, 0), '~Thigh': [0.35], '~Shin': [-0.65], '~Foot': [0.3], '~Arm': [0, 0.5, -0.6], Torso: [0.06] }), 'In'],
        [5.95, { Neck: [0.1, 0, 0], Head: [0.1, 0.1, 0.42], Tail1: [-0.15], Tail3: [0, 0.3], Tail4: [0, 0.4] }, 'Sine'],
        [6.4, { Neck: [0.08], Head: [0.08, 0.08, 0.35] }, 'Sine'],
      ],
      Shake: [['Jaw', 4.0, 4.6, 0.25, 11, 1], ['Head', 4.0, 4.6, 0.06, 22, 2], ['~Arm', 3.95, 4.9, 0.05, 7, 2], ['Tail4', 3.95, 4.9, 0.12, 5, 2], ['~Forearm', 1.45, 3.1, 0.06, 6, 1]],
      Events: [
        [0.0, 'PropFallback', { Prop: 'Perch', Kind: 'Branch', At: [-1.5, 4.6, 5.5], Dur: 2.2 }], [0.02, 'PropFallback', { Prop: 'Stump', At: [0, -0.2, 1.4], Dur: 5.2, Kind: 'Stump' }],
        [0.3, 'SnowPuff', { At: 'VFX_RightFoot', Scale: 0.35, Fall: true }], [1.05, 'EyeGlow', 0.8], [1.3, 'SnowPuff', { At: 'VFX_RightFoot', Scale: 0.7, Fall: true }],
        [1.45, 'Iridesce', 0.6], [2.55, 'Iridesce', 0.5], [3.46, 'SnowPuff', { At: 'VFX_RightFoot', Scale: 0.5 }], [3.47, 'Land', { Scale: 0.25 }],
        [3.95, 'Iridesce', 1.3], [4.0, 'Roar', { Scale: 0.3, Screech: true }], [4.02, 'Call', { At: 'VFX_Mouth', Scale: 0.35, Color: [70, 225, 240], Count: 3 }],
        [4.05, 'CameraShake', 0.15], [5.68, 'SnowPuff', { At: 'VFX_RightFoot', Scale: 0.45 }], [5.69, 'Land', { Scale: 0.2 }],
      ],
    },
  },
};
