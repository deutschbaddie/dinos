// Psittacosaurus — shy, curious herd starter. Signature: HIDE AND SQUEAK (tucked down in the undergrowth, a twig
// snaps, the head pops up, a curious head-tilt, the tail quills flare and rattle, a squeal - and the herd peeks out).
const { W } = require('./util.js');

const TUCK = { Pelvis: [0, 0, 0, 0, -0.68, 0.1], '~Thigh': [0.85], '~Shin': [-1.55], '~Foot': [0.7], Torso: [-0.1], Neck: [-0.75], Head: [-0.25], '~Arm': [0.5], '~Forearm': [-0.6], Tail1: [0.12], Tail2: [0.06] };
const TUCK_B = W(TUCK, { Pelvis: [0, 0, 0, 0, -0.65, 0.1], Neck: [-0.72] });
const PEEK = W(TUCK, { Pelvis: [0, 0, 0, 0, -0.4, 0.05], '~Thigh': [0.55], '~Shin': [-1.0], '~Foot': [0.45], Torso: [0.1], Neck: [0.35], Head: [0.05, 0, 0.12] });
const FLARE = { Quills1: [-0.42], Quills2: [-0.38], Tail1: [-0.35], Tail2: [-0.18], Tail3: [-0.08] };
const SQUEAL = W(FLARE, { Neck: [0.45], Head: [0.38], Jaw: [-0.62], Torso: [0.12], '~Arm': [-0.3, 0, 0.25], '~Forearm': [-0.4] });
const CROUCH = { Pelvis: [0, 0, 0, 0, -0.16, 0], '~Thigh': [0.28], '~Shin': [-0.5], '~Foot': [0.22] };

module.exports = {
  Signature: 'HideAndSqueak', Intro: 'HideAndSqueak', IntroShots: 'PsittaHideSqueak', Chase: 'Chase', Special: 'Graze',
  CycleOrder: ['Walk', 'Run', 'Graze', 'Hide', 'LookAround', 'BeakNip', 'HerdRush', 'QuillRattle', 'Stunned', 'Roar'],
  CameraScale: 0.9,
  Gait: {
    Type: 'Biped', Scale: 0.8, Neck: ['Neck'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5'],
    Idle: { Breath: 0.6, BreathAmp: 1.15, Sway: 0.1, Look: 0.5, Twitch: true, JawIdle: 0.02 },
    Walk: { Freq: 1.5, Stride: 0.42, Knee: 0.55, Bob: 0.13, Roll: 0.07, Yaw: 0.07, Lean: 0.04, TailSway: 0.15, HeadBob: 0.08, Speed: 4.5 },
    Run: { Freq: 2.6, Stride: 0.5, Knee: 0.62, Bob: 0.22, Roll: 0.04, Yaw: 0.05, Lean: 0.16, TailSway: 0.09, HeadBob: 0.1, ThighBias: 0, Speed: 12 },
  },
  Actions: {
    // a squeaky honk with the quills up
    Roar: {
      Duration: 2.0, Suppress: 0.9,
      Keys: [
        [0.3, W(CROUCH, { Neck: [-0.2], Head: [-0.15], Torso: [-0.06] }), 'Sine'],
        [0.55, SQUEAL, 'Back'],
        [1.4, W(SQUEAL, { Head: [0.4, 0, 0.1], Jaw: [-0.58] }), 'Linear'],
      ],
      Shake: [['Head', 0.55, 1.4, 0.06, 16, 2], ['Jaw', 0.55, 1.4, 0.05, 24, 1], ['Quills1', 0.55, 1.4, 0.12, 18, 2], ['Quills2', 0.55, 1.4, 0.12, 18, 2]],
      Events: [[0.55, 'Roar', { Scale: 0.4, Screech: true }], [0.57, 'Call', { At: 'VFX_Crest', Scale: 0.5, Color: [255, 230, 190], Count: 3 }], [0.6, 'CameraShake', 0.15]],
    },
    // the parrot-beak bite
    Attack: {
      Duration: 1.1, Suppress: 0.9,
      Keys: [
        [0.25, { Neck: [0.2], Head: [0.25], Jaw: [-0.6], Pelvis: [0, 0, 0, 0, -0.06, 0.2], Tail1: [-0.1] }, 'Out'],
        [0.42, { Neck: [-0.3], Head: [-0.25], Jaw: [-0.5], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.1, -0.55] }, 'Snap'],
        [0.5, { Neck: [-0.35], Head: [-0.32], Jaw: [0.03], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.1, -0.6] }, 'Snap'],
        [0.8, { Neck: [0], Head: [0.05], Pelvis: [0, 0, 0, 0, 0, -0.2] }, 'Sine'],
      ],
      Events: [[0.5, 'Bite', { Scale: 0.4 }]],
    },
    // TAKEDOWN: two quick nips with a head-shake
    BeakNip: {
      Duration: 1.4, Suppress: 0.92,
      Keys: [
        [0.22, { Neck: [0.25], Head: [0.3], Jaw: [-0.6], Pelvis: [0, 0, 0, 0, -0.05, 0.25] }, 'Out'],
        [0.38, { Neck: [-0.35], Head: [-0.3], Jaw: [0.03], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.1, -0.6] }, 'Snap'],
        [0.6, { Neck: [0.1], Head: [0.15, 0.25, 0.2], Jaw: [-0.5], Pelvis: [0, 0, 0, 0, -0.05, -0.35] }, 'Out'],
        [0.76, { Neck: [-0.35], Head: [-0.3, -0.2, -0.2], Jaw: [0.03], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.1, -0.7] }, 'Snap'],
        [1.1, { Neck: [0], Head: [0.05, 0, 0.1], Pelvis: [0, 0, 0, 0, 0, -0.25] }, 'Sine'],
      ],
      Shake: [['Head', 0.78, 1.0, 0.18, 9, 2]],
      Events: [[0.38, 'Bite', { Scale: 0.35 }], [0.76, 'Bite', { Scale: 0.4 }]],
    },
    // TAKEDOWN: head down, the whole herd crowds in along a line
    HerdRush: {
      Duration: 2.0, Suppress: 1,
      Gait: [[0.45, 1.5, 'Run', 1, 1.1]],
      Keys: [
        [0.4, W(CROUCH, { Neck: [-0.35], Head: [-0.25], Torso: [-0.12], Pelvis: [0, 0, 0, 0, -0.16, 0.3], Tail1: [-0.15] }), 'Sine'],
        [1.5, { Neck: [-0.3], Head: [-0.2], Torso: [-0.15], Pelvis: [0, 0, 0, 0, 0, -5.5], Jaw: [-0.4] }, 'In'],
        [1.62, { Neck: [-0.4], Head: [-0.35], Jaw: [0.03], Pelvis: [0, 0, 0, 0, -0.08, -5.9] }, 'Snap'],
        [1.85, { Pelvis: [0, 0, 0, 0, 0, -5.9] }, 'Sine'],
      ],
      Events: [[0.5, 'HerdCall', { At: 'VFX_Crest', Scale: 0.6 }], [1.62, 'Bite', { Scale: 0.45 }], [1.63, 'CameraShake', 0.2]],
    },
    // TAKEDOWN: the tail rattle - a buzzing ring that calls the herd in
    QuillRattle: {
      Duration: 1.8, Suppress: 1,
      Keys: [
        [0.3, W(CROUCH, { Neck: [-0.15], Head: [-0.1], Pelvis: [0, 0.35, 0, 0, -0.16, 0] }), 'Sine'],
        [0.5, W(FLARE, { Pelvis: [0, 0.4, 0, 0, -0.05, 0], Neck: [0.2], Head: [0.15, -0.3], Jaw: [-0.3] }), 'Back'],
        [1.35, W(FLARE, { Pelvis: [0, 0.4, 0, 0, -0.05, 0], Neck: [0.2], Head: [0.15, -0.3], Jaw: [-0.3] }), 'Linear'],
      ],
      Shake: [['Quills1', 0.5, 1.35, 0.16, 20, 2], ['Quills2', 0.5, 1.35, 0.16, 20, 2], ['Tail1', 0.5, 1.35, 0.08, 14, 2], ['Tail2', 0.5, 1.35, 0.1, 14, 2]],
      Events: [[0.5, 'HerdCall', { At: 'VFX_Crest', Scale: 0.7 }], [0.52, 'CameraShake', 0.12]],
    },
    // a herd-mate answering the call (DinosaurVFX.HerdCall plays this on the rest of the herd)
    HerdResponse: {
      Duration: 1.6, Suppress: 0.9,
      Keys: [[0.3, W(FLARE, { Neck: [0.3], Head: [0.2, 0.15, 0.15], Jaw: [-0.45] }), 'Back'], [1.1, W(FLARE, { Neck: [0.3], Head: [0.2, -0.1, -0.1], Jaw: [-0.4] }), 'Linear']],
      Shake: [['Quills1', 0.3, 1.1, 0.14, 18, 2], ['Quills2', 0.3, 1.1, 0.14, 18, 2]],
      Events: [[0.3, 'Call', { At: 'VFX_Crest', Scale: 0.35, Color: [255, 230, 190], Count: 2 }]],
    },
    Stunned: {
      Duration: 2.4, Suppress: 0.9,
      Keys: [
        [0.25, { Pelvis: [0, 0, 0.14, 0, -0.08, 0.35], Torso: [0.15], Neck: [0.3], Head: [0.3, 0, 0.3], Jaw: [-0.35], Quills1: [0.3], Quills2: [0.3] }, 'Out'],
        [0.65, W(CROUCH, { Pelvis: [0, 0, -0.1, 0, -0.25, 0.3], Neck: [-0.25], Head: [-0.2, 0, -0.3], Jaw: [-0.3], Quills1: [0.3], Quills2: [0.3] }), 'Sine'],
        [1.9, W(CROUCH, { Pelvis: [0, 0, 0.05, 0, -0.2, 0.25], Neck: [-0.15], Head: [-0.1, 0, 0.2], Jaw: [-0.2], Quills1: [0.2], Quills2: [0.2] }), 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.5, T1: 2.15, Rate: 6, Head: [0.25, 0.22], Neck: 0.1, Roll: 0.05 },
      Events: [[0.05, 'Stunned', { Scale: 0.5 }], [0.1, 'CameraShake', 0.15]],
    },
    // curious head tilts
    LookAround: {
      Duration: 3.2, Suppress: 0.6,
      Keys: [
        [0.4, { Neck: [0.35, 0.22], Head: [0.1, 0.22, 0.3] }, 'Sine'],
        [1.0, { Neck: [0.35, 0.23], Head: [0.12, 0.23, -0.25] }, 'Sine'],
        [1.6, { Neck: [0.35, -0.22], Head: [0.1, -0.22, -0.3] }, 'Snap'],
        [2.4, { Neck: [0.35, -0.23], Head: [0.12, -0.23, 0.2] }, 'Sine'],
      ],
    },
    Sniff: {
      Duration: 1.6, Suppress: 0.8,
      Keys: [[0.4, W(CROUCH, { Neck: [-0.55], Head: [-0.3], Torso: [-0.15] }), 'Sine'], [1.2, W(CROUCH, { Neck: [-0.55], Head: [-0.32], Torso: [-0.15] }), 'Linear']],
      Shake: [['Head', 0.4, 1.2, 0.05, 8, 1]],
      Events: [[0.5, 'Sniff']],
    },
    // nibbling ferns
    Graze: {
      Duration: 3.0, Suppress: 0.8,
      Keys: [
        [0.5, W(CROUCH, { Neck: [-0.7], Head: [-0.35], Torso: [-0.18], Jaw: [-0.3] }), 'Sine'],
        [0.75, W(CROUCH, { Neck: [-0.7], Head: [-0.3, 0.15], Torso: [-0.18], Jaw: [0.02] }), 'Snap'],
        [1.0, W(CROUCH, { Neck: [-0.7], Head: [-0.35], Torso: [-0.18], Jaw: [-0.3] }), 'Sine'],
        [1.25, W(CROUCH, { Neck: [-0.7], Head: [-0.3, -0.15], Torso: [-0.18], Jaw: [0.02] }), 'Snap'],
        [1.9, { Neck: [0.1], Head: [0.1, 0, 0.15], Jaw: [-0.05] }, 'Sine'],
        [2.4, { Neck: [0.1], Head: [0.1, 0, 0.15], Jaw: [0.02] }, 'Sine'],
      ],
      Shake: [['Jaw', 1.9, 2.5, 0.1, 6, 1]],
    },
    // hidden in the undergrowth (loops; the camo buddy role)
    Hide: {
      Duration: 3.2, Suppress: 1, Loop: true, FadeIn: 0.4,
      Keys: [[0, TUCK, 'Sine'], [1.6, TUCK_B, 'Sine'], [3.2, TUCK, 'Sine']],
    },
    // chase: the herd scatters onto the road, squeaking, and one darts in to nip
    Chase: {
      Duration: 3.0, Suppress: 1,
      Gait: [[0, 2.3, 'Run', 1]],
      Keys: [
        [2.1, { Pelvis: [0, 0, 0, 0, 0, -5.0], Torso: [-0.1], Quills1: [-0.4], Quills2: [-0.3] }, 'Linear'],
        [2.4, { Pelvis: [0, 0, 0, 0, 0.25, -5.6], Neck: [0.25], Head: [0.2], Jaw: [-0.6] }, 'Out'],
        [2.52, { Pelvis: [0, 0, 0, 0, 0, -5.9], Neck: [-0.3], Head: [-0.3], Jaw: [0.03] }, 'Snap'],
        [2.8, { Pelvis: [0, 0, 0, 0, 0, -5.9] }, 'Sine'],
      ],
      Events: [[0.3, 'Roar', { Scale: 0.3, Screech: true }], [2.52, 'Bite', { Scale: 0.4 }]],
    },
    // SIGNATURE
    HideAndSqueak: {
      Duration: 6.2, Suppress: 1, FadeIn: 0.01,
      Keys: [
        [0.0, TUCK, 'Linear'],
        [0.7, TUCK_B, 'Sine'],
        [1.4, TUCK, 'Sine'],
        [1.62, W(PEEK, { Neck: [0.45], Head: [0.12, 0, 0] }), 'Back'],
        [1.95, W(PEEK, { Head: [0.1, 0.1, 0.32] }), 'Snap'],
        [2.15, W(PEEK, { Head: [0.1, 0.1, 0.34] }), 'Linear'],
        [2.3, W(PEEK, { Head: [0.1, -0.1, -0.3] }), 'Snap'],
        [2.5, W(W(PEEK, FLARE), { Head: [0.05, -0.08, -0.3], Neck: [0.3] }), 'Back'],
        [2.95, W(SQUEAL, { Pelvis: [0, 0, 0, 0, -0.1, 0], '~Thigh': [0.15], '~Shin': [-0.3], '~Foot': [0.12] }), 'Back'],
        [3.7, W(SQUEAL, { Pelvis: [0, 0, 0, 0, -0.08, 0], Head: [0.42, 0, 0.1], Jaw: [-0.6] }), 'Linear'],
        [4.05, W(FLARE, { Neck: [0.25, 0.2], Head: [0.1, 0.25, 0.15], Jaw: [-0.1] }), 'Sine'],
        [4.5, W(FLARE, { Neck: [0.26, 0.21], Head: [0.12, 0.26, 0.2], Jaw: [-0.12] }), 'Linear'],
        [4.75, W(CROUCH, { Neck: [0.1, 0], Head: [0.1, 0, 0.2], Quills1: [-0.3], Quills2: [-0.25], Tail1: [-0.2] }), 'Sine'],
        [5.0, { Pelvis: [0, 0, 0, 0, 0.7, -0.1], '~Thigh': [0.2], '~Shin': [-0.35], Neck: [0.25], Head: [0.2, 0, 0.25], Jaw: [-0.45], Quills1: [-0.45], Quills2: [-0.35], Tail1: [-0.3], '~Arm': [-0.3, 0, 0.2] }, 'Out'],
        [5.22, W(CROUCH, { Neck: [0.05], Head: [0.05, 0, 0.25], Jaw: [-0.1], Quills1: [-0.2], Quills2: [-0.15] }), 'In'],
        [5.6, { Neck: [0.1], Head: [0.1, 0, 0.3], Jaw: [-0.05] }, 'Sine'],
      ],
      Shake: [['Head', 1.62, 1.85, 0.06, 16, 1], ['Quills1', 2.5, 3.7, 0.16, 20, 2], ['Quills2', 2.5, 3.7, 0.16, 20, 2], ['Tail1', 2.5, 3.7, 0.06, 14, 2], ['Jaw', 2.95, 3.7, 0.05, 24, 1]],
      Events: [
        [0.0, 'PropFallback', { Prop: 'Undergrowth', Kind: 'Ferns', At: [0, -1.5, -1.9], Dur: 6 }], [0.01, 'PropFallback', { Prop: 'Twig', Kind: 'Twig', At: [0.4, -1.5, -4.0], Dur: 4, SnapIn: 1.45 }], [0.2, 'RustleProp', { Prop: 'Undergrowth' }], [0.9, 'RustleProp', { Prop: 'Undergrowth' }],
        [1.46, 'BreakProp', { Prop: 'Twig', Power: 0.3 }], [1.47, 'SnowPuff', { At: 'VFX_Mouth', Scale: 0.3, Fall: true }], [1.6, 'RustleProp', { Prop: 'Undergrowth' }],
        [2.5, 'Call', { At: 'VFX_Crest', Scale: 0.45, Color: [255, 230, 190], Count: 3 }], [2.95, 'Roar', { Scale: 0.45, Screech: true }],
        [2.97, 'HerdCall', { At: 'VFX_Crest', Scale: 0.7 }], [3.0, 'CameraShake', 0.15], [5.22, 'Land', { Scale: 0.35 }],
      ],
    },
  },
};
