// Oviraptor — nosy, quick, a fierce parent. Signature: EGG HEIST (darts in, scoops an egg, freezes as if caught,
// flares its arm fan + casque and honks). Pose entries: Joint: [rx, ry, rz, px, py, pz]; "~Joint" = mirrored pair.
const { W } = require('./util.js');

const CROUCH = { Pelvis: [0, 0, 0, 0, -0.24, 0], '~Thigh': [0.34], '~Shin': [-0.62], '~Foot': [0.28] };
const SNEAK = W(CROUCH, { Torso: [-0.12], Neck1: [-0.38], Neck2: [0.12], Head: [0.18], '~Arm': [0.25, 0, 0.12], '~Forearm': [-0.35], Tail1: [-0.12], Tail2: [0.04] });
const PEER = W(SNEAK, { Pelvis: [0, 0, 0, 0, -0.42, 0.05], '~Thigh': [0.52], '~Shin': [-0.92], '~Foot': [0.4], Torso: [-0.32], Neck1: [-0.6], Neck2: [-0.2], Head: [-0.05], '~Arm': [0.9, 0, 0.12], '~Forearm': [-0.25], Tail1: [0.12], Tail2: [0.08] });
// the egg tucked under the left arm, hugged to the chest
const CLUTCH = { LeftArm: [0.55, 0, 0.26], LeftForearm: [0.6, -0.38, 0] };
// caught red-handed: frozen mid-tiptoe on one leg, head snapped round to the lens, eyes wide
const FREEZE = W(CLUTCH, {
  Pelvis: [0, 0, 0.04, 0, 0.06, 0], RightThigh: [0.75], RightShin: [-1.15], RightFoot: [0.55], LeftThigh: [-0.04], LeftShin: [-0.06],
  Torso: [0.05], Neck1: [0.12], Neck2: [0.18], Head: [0.08, 0, 0.1], RightArm: [0.4, 0, 0.35], RightForearm: [-0.2], Tail1: [-0.06], Tail2: [-0.04],
});
// the display: right arm fan swept up and out, tail fan raised, casque high
const FLARE = W(CLUTCH, {
  Pelvis: [0, 0, 0, 0, 0.08, 0.05], Torso: [0.06], Neck1: [0.25], Neck2: [0.18], Head: [0.22], Jaw: [-0.2],
  RightArm: [1.35, -0.4, 0.45], RightForearm: [0.35, 0, 0], Tail1: [-0.42], Tail2: [-0.32], Tail3: [-0.22], Tail4: [-0.35],
});
const HONK = W(FLARE, { Neck1: [0.32], Neck2: [0.06], Head: [0.42], Jaw: [-0.78] });
const BOTH_FANS = { '~Arm': [1.35, -0.4, 0.45], '~Forearm': [0.35, 0, 0], Tail1: [-0.42], Tail2: [-0.32], Tail3: [-0.22], Tail4: [-0.35] };

module.exports = {
  Signature: 'EggHeist', Intro: 'EggHeist', IntroShots: 'OviHeist', Chase: 'Chase', Special: 'Screech',
  CycleOrder: ['Walk', 'Run', 'LookAround', 'Sniff', 'BeakSnatch', 'KickFlurry', 'Screech', 'Stunned', 'Roar'],
  CameraScale: 1.05,
  Gait: {
    Type: 'Biped', Scale: 1, Neck: ['Neck1', 'Neck2'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4'],
    Idle: { Breath: 0.6, BreathAmp: 1.1, Sway: 0.1, Look: 0.6, Twitch: true, JawIdle: 0.02 },
    Walk: { Freq: 1.45, Stride: 0.42, Knee: 0.7, Bob: 0.1, Roll: 0.05, Yaw: 0.07, Lean: 0.05, TailSway: 0.16, HeadBob: 0.12, Speed: 4.5 },
    Run: { Freq: 2.8, Stride: 0.58, Knee: 0.9, Bob: 0.2, Roll: 0.03, Yaw: 0.05, Lean: 0.22, TailSway: 0.1, HeadBob: 0.08, ThighBias: 0, Speed: 13 },
  },
  Actions: {
    // a goose-like honk with both fans half open
    Roar: {
      Duration: 2.0, Suppress: 0.9,
      Keys: [
        [0.3, W(CROUCH, { Neck1: [-0.3], Neck2: [0.1], Head: [-0.1], '~Arm': [0.2, 0, 0.3] }), 'Sine'],
        [0.55, { Neck1: [0.3], Neck2: [0.05], Head: [0.42], Jaw: [-0.78], '~Arm': [0.95, -0.3, 0.35], '~Forearm': [0.3], Tail1: [-0.3], Tail2: [-0.2], Tail4: [-0.25] }, 'Back'],
        [1.4, { Neck1: [0.32], Neck2: [0.06], Head: [0.45], Jaw: [-0.74], '~Arm': [1.0, -0.3, 0.38], '~Forearm': [0.32], Tail1: [-0.32], Tail2: [-0.2], Tail4: [-0.28] }, 'Linear'],
      ],
      Shake: [['Head', 0.55, 1.4, 0.06, 16, 3], ['Jaw', 0.55, 1.4, 0.05, 22, 1]],
      Events: [[0.5, 'CasqueFlash', 1.6], [0.55, 'Roar', { Scale: 0.4, Screech: true }], [0.56, 'Call', { At: 'VFX_Mouth', Scale: 0.5, Color: [255, 170, 80], Count: 3 }], [0.6, 'CameraShake', 0.2]],
    },
    // quick peck
    Attack: {
      Duration: 1.1, Suppress: 0.9,
      Keys: [
        [0.28, { Neck1: [0.25], Neck2: [0.1], Head: [0.2], Jaw: [-0.5], Pelvis: [0, 0, 0, 0, -0.05, 0.15] }, 'Out'],
        [0.45, { Neck1: [-0.45], Neck2: [-0.1], Head: [-0.2], Jaw: [-0.4], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.1, -0.45] }, 'Snap'],
        [0.52, { Neck1: [-0.5], Neck2: [-0.12], Head: [-0.25], Jaw: [0.02], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.1, -0.5] }, 'Snap'],
        [0.8, { Neck1: [-0.05], Head: [0.1, 0.2, 0.1], Pelvis: [0, 0, 0, 0, 0, -0.2] }, 'Sine'],
      ],
      Events: [[0.52, 'Bite', { Scale: 0.4 }], [0.54, 'CameraShake', 0.15]],
    },
    // TAKEDOWN: darts in, the beak snatches the egg out of your arms, and it whips away with it
    BeakSnatch: {
      Duration: 1.5, Suppress: 0.95,
      Keys: [
        [0.25, W(SNEAK, { Pelvis: [0, 0, 0, 0, -0.3, 0.25], Neck1: [-0.2], Neck2: [0.2], Head: [0.25], Jaw: [-0.15] }), 'Out'],
        [0.5, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.15, -1.3], Torso: [-0.18], Neck1: [-0.25], Neck2: [-0.05], Head: [-0.05], Jaw: [-0.7], '~Arm': [0.7, 0, 0.2], Tail1: [-0.2], Tail2: [-0.15] }), 'Snap'],
        [0.58, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.15, -1.4], Torso: [-0.18], Neck1: [-0.28], Neck2: [-0.08], Head: [-0.1], Jaw: [0.02], '~Arm': [0.7, 0, 0.2], Tail1: [-0.2] }), 'Snap'],
        [0.85, W(CLUTCH, { Pelvis: [0, 0.5, 0, 0, 0.05, -0.9], Neck1: [0.2, 0.3], Neck2: [0.1, 0.2], Head: [0.25, 0.2], Tail1: [-0.25, -0.3], Tail2: [-0.1, -0.3] }), 'Back'],
        [1.15, W(CLUTCH, { Pelvis: [0, 0.3, 0, 0, 0, -0.6], Neck1: [0.1], Head: [0.15], Tail1: [-0.1] }), 'Sine'],
      ],
      Events: [[0.58, 'Bite', { Scale: 0.45 }], [0.6, 'EggSnatch', { Hand: 'LeftForearm', Hold: 3 }], [0.62, 'CameraShake', 0.2]],
    },
    // TAKEDOWN: a hopping flurry of raking kicks
    KickFlurry: {
      Duration: 1.8, Suppress: 0.95,
      Keys: [
        [0.25, W(CROUCH, { Torso: [0.15], Neck1: [0.2], Head: [0.1], Jaw: [-0.3], '~Arm': [1.1, -0.35, 0.4] }), 'Out'],
        [0.45, { Pelvis: [0, 0, 0, 0, 0.55, -0.3], Torso: [0.25], Neck1: [0.25], RightThigh: [1.05], RightShin: [-0.15], RightFoot: [-0.3], LeftThigh: [0.3], LeftShin: [-0.8], LeftFoot: [0.4], '~Arm': [1.1, -0.35, 0.4], Tail1: [0.2], Tail2: [0.15] }, 'Snap'],
        [0.7, { Pelvis: [0, 0, 0, 0, 0.5, -0.5], Torso: [0.25], Neck1: [0.25], LeftThigh: [1.05], LeftShin: [-0.15], LeftFoot: [-0.3], RightThigh: [0.3], RightShin: [-0.8], RightFoot: [0.4], '~Arm': [1.1, -0.35, 0.4], Tail1: [0.2], Tail2: [0.15] }, 'Snap'],
        [0.95, { Pelvis: [0, 0, 0, 0, 0.55, -0.7], Torso: [0.25], Neck1: [0.25], RightThigh: [1.05], RightShin: [-0.15], RightFoot: [-0.3], LeftThigh: [0.3], LeftShin: [-0.8], LeftFoot: [0.4], '~Arm': [1.1, -0.35, 0.4], Tail1: [0.2], Tail2: [0.15] }, 'Snap'],
        [1.25, W(CROUCH, { Pelvis: [0, 0, 0, 0, -0.24, -0.6], Torso: [0.05], Jaw: [-0.4], Head: [0.2] }), 'In'],
      ],
      Events: [[0.45, 'Footstep', { Side: 'Right' }], [0.46, 'Bite', { Scale: 0.3 }], [0.7, 'Footstep', { Side: 'Left' }], [0.71, 'Bite', { Scale: 0.3 }], [0.95, 'Footstep', { Side: 'Right' }], [0.96, 'Bite', { Scale: 0.3 }], [1.25, 'Land', { Scale: 0.4 }], [0.98, 'CameraShake', 0.2]],
    },
    // TAKEDOWN / special: a rattling screech that calls the rest of the gang
    Screech: {
      Duration: 2.4, Suppress: 0.95,
      Keys: [
        [0.3, W(CROUCH, { Neck1: [-0.4], Head: [-0.2], '~Arm': [0.3, 0, 0.2] }), 'Sine'],
        [0.6, W(BOTH_FANS, { Pelvis: [0, 0, 0, 0, 0.1, 0], Neck1: [0.4], Neck2: [0.15], Head: [0.5], Jaw: [-0.8] }), 'Back'],
        [1.0, W(BOTH_FANS, { Pelvis: [0, 0, 0, 0, 0.08, 0], Neck1: [0.38, 0.3], Neck2: [0.15, 0.2], Head: [0.48, 0.2], Jaw: [-0.3] }), 'Snap'],
        [1.2, W(BOTH_FANS, { Pelvis: [0, 0, 0, 0, 0.1, 0], Neck1: [0.4, -0.3], Neck2: [0.15, -0.2], Head: [0.5, -0.2], Jaw: [-0.82] }), 'Snap'],
        [1.9, W(BOTH_FANS, { Neck1: [0.4], Neck2: [0.12], Head: [0.5], Jaw: [-0.8] }), 'Linear'],
      ],
      Shake: [['Head', 0.6, 1.9, 0.06, 18, 3], ['~Forearm', 0.6, 1.9, 0.12, 12, 1]],
      Events: [[0.55, 'CasqueFlash', 1.8], [0.6, 'Roar', { Scale: 0.45, Screech: true }], [0.6, 'Call', { At: 'VFX_Crest', Scale: 0.6, Color: [255, 140, 60], Count: 5 }], [0.62, 'CameraShake', 0.25], [1.2, 'Call', { At: 'VFX_Mouth', Scale: 0.5, Color: [255, 200, 120], Count: 3 }]],
    },
    Stunned: {
      Duration: 2.6, Suppress: 0.9,
      Keys: [
        [0.25, { Pelvis: [0, 0, 0.14, 0, -0.05, 0.4], Torso: [0.2], Neck1: [0.3], Head: [0.3, 0, 0.3], Jaw: [-0.4], '~Arm': [0.1, 0, 0.6], Tail1: [0.15] }, 'Out'],
        [0.6, { Pelvis: [0, 0, -0.1, 0, -0.14, 0.35], Torso: [-0.05], Neck1: [-0.25], Head: [-0.2, 0, -0.3], '~Thigh': [0.22], '~Shin': [-0.38], Jaw: [-0.3], '~Arm': [0.2, 0, 0.3] }, 'Sine'],
        [2.0, { Pelvis: [0, 0, 0.05, 0, -0.1, 0.3], Neck1: [-0.18], Head: [-0.1, 0, 0.2], '~Thigh': [0.16], '~Shin': [-0.3], Jaw: [-0.25] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.5, T1: 2.3, Rate: 6.5, Head: [0.3, 0.24], Neck: 0.14, Roll: 0.05 },
      Events: [[0.05, 'Stunned', { Scale: 0.45 }], [0.1, 'CameraShake', 0.25]],
    },
    // bird-like: the head jerks from point to point and holds
    LookAround: {
      Duration: 3.2, Suppress: 0.6,
      Keys: [
        [0.25, { Neck1: [0.1, 0.35], Neck2: [0.05, 0.2], Head: [0.05, 0.35, 0.2] }, 'Snap'],
        [0.9, { Neck1: [0.1, 0.36], Neck2: [0.05, 0.2], Head: [0.05, 0.36, 0.22] }, 'Linear'],
        [1.1, { Neck1: [0.15, -0.1], Neck2: [0.1], Head: [0.1, -0.1, -0.3] }, 'Snap'],
        [1.6, { Neck1: [0.15, -0.1], Neck2: [0.1], Head: [0.1, -0.1, -0.32] }, 'Linear'],
        [1.8, { Neck1: [0.1, -0.4], Neck2: [0.05, -0.2], Head: [0.05, -0.38, -0.1], Tail2: [0, 0.2] }, 'Snap'],
        [2.6, { Neck1: [0.1, -0.4], Neck2: [0.05, -0.2], Head: [0.05, -0.4, -0.1], Tail2: [0, 0.2] }, 'Linear'],
      ],
    },
    Sniff: {
      Duration: 1.8, Suppress: 0.8,
      Keys: [
        [0.5, W(CROUCH, { Neck1: [-0.55], Neck2: [-0.1], Head: [-0.2], Torso: [-0.15] }), 'Sine'],
        [1.3, W(CROUCH, { Neck1: [-0.55], Neck2: [-0.1], Head: [-0.25], Torso: [-0.15] }), 'Linear'],
      ],
      Shake: [['Head', 0.5, 1.3, 0.05, 8, 1]],
      Events: [[0.6, 'Sniff']],
    },
    // the chase: it sprints up the rover's flank and plucks an egg off the rack
    Chase: {
      Duration: 3.4, Suppress: 1,
      Gait: [[0, 2.5, 'Run', 1]],
      Keys: [
        [2.3, { Pelvis: [0, 0, 0, 0, 0, -5.4], Torso: [-0.12] }, 'Linear'],
        [2.62, { Pelvis: [0, 0, 0, 0, 1.0, -6.2], '~Thigh': [0.6], '~Shin': [-1.0], '~Foot': [0.5], Torso: [0.15], Neck1: [0.55], Neck2: [0.25], Head: [0.3], Jaw: [-0.7], '~Arm': [0.6, 0, 0.4], Tail1: [0.2] }, 'Out'],
        [2.76, { Pelvis: [0, 0, 0, 0, 1.05, -6.5], Torso: [0.15], Neck1: [0.6], Neck2: [0.25], Head: [0.2], Jaw: [0.02], LeftArm: [0.55, 0, 0.32], LeftForearm: [0.55, -0.55, 0] }, 'Snap'],
        [3.1, W(CLUTCH, { Pelvis: [0, 0.4, 0, 0, 0, -6.6], Neck1: [0.1, 0.3], Head: [0.1, 0.3] }), 'In'],
      ],
      Events: [[2.76, 'Bite', { Scale: 0.4 }], [2.78, 'EggSnatch', { Hand: 'LeftForearm', Hold: 2.5 }], [2.8, 'CameraShake', 0.25], [3.1, 'Land', { Scale: 0.4 }]],
    },
    // SIGNATURE: EGG HEIST
    EggHeist: {
      Duration: 5.6, Suppress: 1, FadeIn: 0.01, HoldEnd: true,
      Gait: [[0, 0.95, 'Run', 1]],
      Keys: [
        [0.0, W(SNEAK, { Pelvis: [0, -0.95, 0, -3.6, -0.2, 2.7] }), 'Linear'],
        [0.92, W(SNEAK, { Pelvis: [0, 0.08, 0, 0, -0.26, 0.05] }), 'Out'],
        [1.2, W(SNEAK, { Neck1: [-0.3, 0.45], Neck2: [0, 0.3], Head: [0.12, 0.38, 0.15] }), 'Snap'],
        [1.42, W(SNEAK, { Neck1: [-0.3, -0.45], Neck2: [0, -0.3], Head: [0.12, -0.38, -0.15] }), 'Snap'],
        [1.8, PEER, 'Sine'],
        [2.15, W(CROUCH, CLUTCH, { Torso: [-0.05], Neck1: [-0.25], Neck2: [0.1], Head: [0.1, 0.2], RightArm: [0.4, 0, 0.3], RightForearm: [-0.3], Tail1: [-0.1] }), 'Back'],
        [2.38, FREEZE, 'Snap'],
        [3.0, W(FREEZE, { Head: [0.1, 0, 0.12], Neck2: [0.2] }), 'Linear'],
        [3.32, FLARE, 'Back'],
        [3.58, HONK, 'Snap'],
        [4.7, W(HONK, { Jaw: [-0.74], Head: [0.45] }), 'Linear'],
        [5.2, W(CLUTCH, { Pelvis: [0, 0, 0, 0, 0.04, 0], Neck1: [0.15], Neck2: [0.1], Head: [0.15, -0.15, 0.08], RightArm: [0.1, 0, 0.25], Tail1: [-0.25], Tail2: [-0.15], Tail4: [-0.2] }), 'Sine'],
        [5.6, W(CLUTCH, { Pelvis: [0, 0, 0, 0, 0.04, 0], Neck1: [0.15], Neck2: [0.1], Head: [0.15, -0.15, 0.08], RightArm: [0.1, 0, 0.25], Tail1: [-0.25], Tail2: [-0.15], Tail4: [-0.2] }), 'Linear'],
      ],
      Shake: [['Head', 2.4, 3.0, 0.025, 14, 3], ['Tail4', 2.4, 3.0, 0.05, 12, 2], ['Head', 3.58, 4.7, 0.06, 16, 3], ['Jaw', 3.58, 4.7, 0.05, 22, 1], ['RightForearm', 3.32, 4.7, 0.1, 11, 1]],
      Events: [
        [0.05, 'JumpDust', { Scale: 0.4 }], [0.92, 'Scrape', { At: 'VFX_RightFoot' }], [0.94, 'Footstep', { Side: 'Left' }],
        [1.82, 'EggSnatch', { Prop: 'Nest', Hand: 'LeftForearm', Hold: 12 }], [1.84, 'Sniff'],
        [2.38, 'EyeGlow', 0.7], [2.4, 'Land', { Scale: 0.15 }],
        [3.25, 'CasqueFlash', 2.2], [3.3, 'TailSwing', 0.6], [3.58, 'Roar', { Scale: 0.45, Screech: true }],
        [3.6, 'Call', { At: 'VFX_Mouth', Scale: 0.55, Color: [255, 160, 70], Count: 4 }], [3.62, 'CameraShake', 0.3],
      ],
    },
  },
};
