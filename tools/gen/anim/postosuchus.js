// Postosuchus — the Dawn Desert's ruler: a croc-line archosaur that ruled before the dinosaurs. Patient, brutal.
// Signature: BEFORE THE DINOSAURS (rises out of the dry riverbed mud, shakes it off, stands up on its hind legs,
// jaws wide, a dust roar... and drops back onto all fours).
const { W } = require('./util.js');

// hips dropped by `d` studs with all four legs bent to keep the feet planted (tables measured on the rig)
const lerpTable = (tab, d) => {
  if (d <= tab[0][0]) return tab[0][1] * d / tab[0][0];
  for (let i = 1; i < tab.length; i++) if (d <= tab[i][0]) { const [a, ka] = tab[i - 1], [b, kb] = tab[i]; return ka + (kb - ka) * (d - a) / (b - a); }
  return tab[tab.length - 1][1];
};
const HIND = [[0.08, 0.25], [0.165, 0.5], [0.26, 0.75], [0.36, 1], [0.58, 1.5], [0.83, 2]];
const FRONT = [[0.04, 0.25], [0.08, 0.5], [0.13, 0.75], [0.19, 1], [0.32, 1.5], [0.48, 2]];
const Q = (d, extra = {}) => {
  const h = lerpTable(HIND, d), f = lerpTable(FRONT, d);
  return W({
    Pelvis: [0, 0, 0, 0, -d, 0],
    '~HindThigh': [0.2 * h], '~HindShin': [-0.35 * h], '~HindFoot': [0.15 * h],
    '~FrontUpper': [-0.2 * f], '~FrontLower': [0.35 * f], '~FrontFoot': [-0.15 * f],
  }, extra);
};
const P = (pelvis, pose) => W(pose, { Pelvis: pelvis });

// sunk in the dry riverbed: only the eyes and the back scutes above the mud
const BURIED = { Pelvis: [0, 0, 0, 0, -6.55, 0], '~HindThigh': [0.35], '~HindShin': [-0.5], '~HindFoot': [0.2], '~FrontUpper': [0.4], '~FrontLower': [-0.2], Neck: [-0.06], Head: [0.08], Jaw: [0.02], Tail1: [0.02], Tail2: [0.02] };
const ERUPT = Q(0, { Pelvis: [0.22, 0, 0, 0, 0.45, -0.6], Torso: [0.06], Neck: [0.32], Head: [0.12], Jaw: [-0.7], '~FrontUpper': [0.7], '~FrontLower': [-0.6], '~FrontFoot': [0.4], '~HindThigh': [-0.1], Tail1: [-0.2], Tail2: [-0.1] });
const LOW = Q(0.36, { Torso: [-0.04], Neck: [-0.12], Head: [0.06], Jaw: [-0.2], Tail1: [-0.06] });
// up on its hind legs: hips tip back, hind legs counter-rotate, the tail props it, arms claw the air
const STAND = {
  Pelvis: [0.9, 0, 0, 0, -0.35, 1.4], '~HindThigh': [-0.72], '~HindShin': [-0.32], '~HindFoot': [0.14], Torso: [0.12],
  Neck: [-0.55], Head: [-0.45], Jaw: [-0.25], '~FrontUpper': [0.75, 0, 0.1], '~FrontLower': [-0.5], '~FrontFoot': [0.7],
  Tail1: [-0.78], Tail2: [-0.06], Tail3: [0.08], Tail4: [0.1], Tail5: [0.08],
};
const ROAR_UP = W(STAND, { Neck: [-0.3], Head: [-0.12], Jaw: [-1.05], Torso: [0.16], '~FrontUpper': [0.95, 0, 0.25], '~FrontLower': [-0.7], '~FrontFoot': [0.9] });
const SLAMMED = Q(0.58, { Pelvis: [0, 0, 0, 0, -0.58, -1.0], Torso: [-0.02], Neck: [-0.2], Head: [0.14], Jaw: [-0.55], Tail1: [-0.12], Tail2: [-0.05] });
const ROAR = Q(0.2, { Torso: [-0.02], Neck: [0.08], Head: [0.12], Jaw: [-1.0], Tail1: [-0.12], Tail2: [-0.08] });
const SLEEP = { Pelvis: [0, 0.12, 0.03, 0, -2.8, 0], '~HindThigh': [0.85, 0, 0.35], '~HindShin': [-1.55], '~HindFoot': [0.75], '~FrontUpper': [1.3], '~FrontLower': [-0.1], '~FrontFoot': [-1.0], Torso: [0.02, 0.06], Neck: [-0.4, 0.18], Head: [0.22, 0.18], Jaw: [0.02], Tail1: [0.02, 0.2], Tail2: [0.04, 0.25], Tail3: [0.04, 0.3], Tail4: [0.03, 0.3] };

module.exports = {
  Signature: 'BeforeTheDinosaurs', Intro: 'BeforeTheDinosaurs', IntroShots: 'PostoRise', Chase: 'Chase', Special: 'UprightCharge',
  CycleOrder: ['Walk', 'Run', 'UprightCharge', 'BiteShake', 'MudAmbush', 'TailLash', 'TerrorRoar', 'LookAround', 'Stunned', 'Roar'],
  CameraScale: 2.6, PatrolDistance: 22,
  Gait: {
    Type: 'Quadruped', Scale: 2.0, Neck: ['Neck'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5'],
    Idle: { Breath: 0.2, BreathAmp: 1.0, Sway: 0.05, Look: 0.18, Twitch: false, JawIdle: 0.04 },
    Walk: { Freq: 0.7, Stride: 0.3, Knee: 0.5, Bob: 0.1, Roll: 0.05, Yaw: 0.05, Lean: 0, TailSway: 0.18, HeadBob: 0.05, Speed: 7 },
    Run: { Freq: 1.3, Stride: 0.4, Knee: 0.7, Bob: 0.22, Roll: 0.04, Yaw: 0.05, Lean: 0.04, TailSway: 0.12, HeadBob: 0.08, Speed: 17 },
  },
  Actions: {
    // a low, rattling roar from deep in the throat
    Roar: {
      Duration: 3.0, Suppress: 0.92,
      Keys: [
        [0.5, Q(0.12, { Neck: [-0.2], Head: [-0.12], Jaw: [-0.1], Pelvis: [0, 0, 0, 0, -0.12, 0.3] }), 'Sine'],
        [0.95, ROAR, 'Back'],
        [2.3, W(ROAR, { Jaw: [-0.92], Head: [0.1, 0, 0.05] }), 'Linear'],
      ],
      Shake: [['Head', 0.95, 2.3, 0.04, 14, 3], ['Jaw', 0.95, 2.3, 0.03, 20, 1], ['Neck', 0.95, 2.3, 0.02, 8, 2]],
      Events: [[0.9, 'EyeGlow', 1.8], [0.95, 'Roar', { Scale: 1.6 }], [0.97, 'CameraShake', 0.8]],
    },
    Attack: {
      Duration: 1.7, Suppress: 0.95,
      Keys: [
        [0.4, Q(0.2, { Neck: [0.15], Head: [0.12], Jaw: [-0.9], Pelvis: [0, 0, 0, 0, -0.2, 0.6] }), 'Out'],
        [0.62, Q(0.2, { Neck: [-0.15], Head: [-0.05], Jaw: [-0.8], Torso: [-0.08], Pelvis: [0, 0, 0, 0, -0.2, -2.2] }), 'Snap'],
        [0.7, Q(0.2, { Neck: [-0.22], Head: [-0.15], Jaw: [0.03], Torso: [-0.08], Pelvis: [0, 0, 0, 0, -0.2, -2.3] }), 'Snap'],
        [1.15, { Head: [0.05, 0.15, 0.1], Pelvis: [0, 0, 0, 0, 0, -1.0] }, 'Sine'],
      ],
      Events: [[0.7, 'Bite', { Scale: 1.4 }], [0.72, 'CameraShake', 0.6]],
    },
    // takedown: a crushing bite, then it shakes its head hard side to side like a croc
    BiteShake: {
      Duration: 2.3, Suppress: 0.95,
      Keys: [
        [0.4, Q(0.2, { Neck: [0.18], Head: [0.14], Jaw: [-1.0], Pelvis: [0, 0, 0, 0, -0.2, 0.6] }), 'Out'],
        [0.6, Q(0.36, { Neck: [-0.18], Head: [-0.1], Jaw: [0.03], Torso: [-0.1], Pelvis: [0, 0, 0, 0, -0.36, -2.4] }), 'Snap'],
        [0.8, Q(0.36, { Neck: [-0.1, 0.4], Head: [-0.05, 0.3, 0.3], Jaw: [0.03], Pelvis: [0, 0.12, 0, 0, -0.36, -2.4] }), 'Snap'],
        [1.0, Q(0.36, { Neck: [-0.1, -0.4], Head: [-0.05, -0.3, -0.3], Jaw: [0.03], Pelvis: [0, -0.12, 0, 0, -0.36, -2.4] }), 'Snap'],
        [1.2, Q(0.36, { Neck: [-0.1, 0.35], Head: [-0.05, 0.28, 0.28], Jaw: [0.03], Pelvis: [0, 0.1, 0, 0, -0.36, -2.4] }), 'Snap'],
        [1.4, Q(0.36, { Neck: [-0.1, -0.3], Head: [-0.05, -0.25, -0.25], Jaw: [0.03], Pelvis: [0, -0.1, 0, 0, -0.36, -2.4] }), 'Snap'],
        [1.75, Q(0.1, { Neck: [0.1], Head: [0.1], Jaw: [-0.4], Pelvis: [0, 0, 0, 0, -0.1, -1.4] }), 'Sine'],
      ],
      Events: [[0.6, 'Bite', { Scale: 1.6 }], [0.62, 'CameraShake', 0.7], [0.8, 'Impact', { At: 'VFX_Mouth', Scale: 0.8 }], [1.2, 'Impact', { At: 'VFX_Mouth', Scale: 0.8 }]],
    },
    // takedown: the upright charge — it rises onto its hind legs and runs you down
    UprightCharge: {
      Duration: 2.6, Suppress: 1,
      Keys: [
        [0.5, W(STAND, { Pelvis: [0.75, 0, 0, 0, -0.35, 1.0], Neck: [-0.35], Head: [-0.3], Jaw: [-0.6] }), 'Sine'],
        [0.75, W(STAND, { Pelvis: [0.7, 0, 0, 0, -0.3, -0.8], '~HindThigh': [-0.2], '~HindShin': [-0.6], LeftHindThigh: [-1.0], LeftHindShin: [-0.1], Neck: [-0.3], Head: [-0.28], Jaw: [-0.9] }), 'Sine'],
        [1.0, W(STAND, { Pelvis: [0.65, 0, 0, 0, -0.25, -2.6], RightHindThigh: [-1.0], RightHindShin: [-0.1], LeftHindThigh: [-0.2], LeftHindShin: [-0.6], Neck: [-0.3], Head: [-0.28], Jaw: [-0.9] }), 'Sine'],
        [1.25, W(STAND, { Pelvis: [0.6, 0, 0, 0, -0.25, -4.6], '~HindThigh': [-0.2], '~HindShin': [-0.6], LeftHindThigh: [-1.0], LeftHindShin: [-0.1], Neck: [-0.3], Head: [-0.28], Jaw: [-0.9] }), 'Sine'],
        [1.55, W(SLAMMED, { Pelvis: [0, 0, 0, 0, -0.58, -6.4], Jaw: [0.02] }), 'In'],
        [2.1, Q(0.2, { Pelvis: [0, 0, 0, 0, -0.2, -6.4], Jaw: [-0.3] }), 'Sine'],
      ],
      Events: [[0.3, 'Growl'], [0.75, 'Footstep', { Side: 'Right' }], [1.0, 'Footstep', { Side: 'Left' }], [1.25, 'Footstep', { Side: 'Right' }], [1.52, 'Bite', { Scale: 1.6 }], [1.55, 'Impact', { At: 'VFX_RightFrontFoot', Scale: 1.6 }], [1.56, 'CameraShake', 0.9]],
    },
    // takedown: sinks into the mud... and bursts up under you
    MudAmbush: {
      Duration: 3.0, Suppress: 1,
      Keys: [
        [0.6, Q(0.58, { Neck: [-0.2], Head: [0.1] }), 'Sine'],
        [1.0, BURIED, 'In'],
        [1.7, BURIED, 'Linear'],
        [1.95, ERUPT, 'Out'],
        [2.5, LOW, 'Sine'],
      ],
      Events: [[0.95, 'MudBurst', { Scale: 1.4 }], [1.3, 'MudBubble', { Scale: 1.2 }], [1.72, 'MudBurst', { Scale: 2.2 }], [1.74, 'Bite', { Scale: 1.6 }], [1.75, 'CameraShake', 1.0]],
    },
    // takedown: the heavy tail lashes round behind it
    TailLash: {
      Duration: 1.8, Suppress: 0.95,
      Keys: [
        [0.5, Q(0.2, { Pelvis: [0, -0.3, 0, 0, -0.2, 0], Torso: [0, 0.15], Neck: [0, 0.35], Head: [0, 0.25], Tail1: [0, -0.35], Tail2: [0, -0.4], Tail3: [0, -0.4], Tail4: [0, -0.35], Tail5: [0, -0.3] }), 'Sine'],
        [0.78, Q(0.2, { Pelvis: [0, 0.38, 0, 0, -0.2, 0], Torso: [0, -0.15], Neck: [0, -0.25], Tail1: [0.05, 0.5], Tail2: [0.05, 0.55], Tail3: [0.05, 0.6], Tail4: [0, 0.55], Tail5: [0, 0.5] }), 'Snap'],
        [1.25, { Pelvis: [0, 0.12, 0, 0, 0, 0], Tail1: [0, 0.12], Tail2: [0, 0.14] }, 'Sine'],
      ],
      Events: [[0.6, 'TailSwing', 0.8], [0.8, 'Impact', { At: 'VFX_TailTip', Scale: 1.4 }]],
    },
    // buddy TERROR: a roar from the old world — small dinos scatter
    TerrorRoar: {
      Duration: 2.6, Suppress: 0.95,
      Keys: [[0.4, Q(0.2, { Neck: [-0.25], Head: [-0.15], Pelvis: [0.1, 0, 0, 0, -0.2, 0.4] }), 'Sine'], [0.75, W(ROAR, { Pelvis: [0.18, 0, 0, 0, -0.2, -0.4], Neck: [0.2], Jaw: [-1.05] }), 'Back'], [1.9, W(ROAR, { Pelvis: [0.18, 0, 0, 0, -0.2, -0.4], Neck: [0.22], Jaw: [-1.0] }), 'Linear']],
      Shake: [['Head', 0.75, 1.9, 0.05, 14, 3], ['Jaw', 0.75, 1.9, 0.03, 20, 1]],
      Events: [[0.72, 'EyeGlow', 1.6], [0.75, 'Roar', { Scale: 1.8 }], [0.76, 'TerrorWave', { Scale: 1.6 }], [0.78, 'CameraShake', 0.6]],
    },
    Stunned: {
      Duration: 3.0, Suppress: 0.92,
      Keys: [
        [0.3, Q(0.2, { Pelvis: [0, 0.08, 0.12, 0, -0.2, 0.9], Torso: [0.08], Neck: [0.2, 0.2], Head: [0.1, 0.2, 0.3], Jaw: [-0.4] }), 'Out'],
        [0.9, Q(0.58, { Pelvis: [0, -0.05, -0.1, 0, -0.58, 0.7], Neck: [-0.35, -0.15], Head: [-0.1, -0.15, -0.25], Jaw: [-0.35] }), 'Sine'],
        [2.3, Q(0.4, { Pelvis: [0, 0, 0.05, 0, -0.4, 0.5], Neck: [-0.25], Head: [-0.05, 0, 0.2], Jaw: [-0.25] }), 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.8, T1: 2.6, Rate: 4, Head: [0.2, 0.18], Neck: 0.1, Roll: 0.04 },
      Events: [[0.05, 'Stunned', { Scale: 1.6 }], [0.1, 'CameraShake', 0.6]],
    },
    LookAround: {
      Duration: 4.0, Suppress: 0.6,
      Keys: [
        [0.8, { Neck: [0.1, 0.42], Head: [0.05, 0.3, 0.1] }, 'Sine'],
        [1.6, { Neck: [0.1, 0.44], Head: [0.1, 0.32, 0.05] }, 'Linear'],
        [2.5, { Neck: [0.08, -0.42], Head: [0.05, -0.3, -0.1], Tail3: [0, 0.2], Tail4: [0, 0.25] }, 'Sine'],
        [3.3, { Neck: [0.08, -0.44], Head: [0.1, -0.32, -0.05], Tail3: [0, 0.2], Tail4: [0, 0.25] }, 'Linear'],
      ],
      Events: [[1.7, 'Sniff']],
    },
    Sniff: {
      Duration: 2.2, Suppress: 0.85,
      Keys: [[0.6, Q(0.2, { Neck: [-0.35], Head: [-0.15], Torso: [-0.04] }), 'Sine'], [1.6, Q(0.2, { Neck: [-0.35], Head: [-0.18], Torso: [-0.04] }), 'Linear']],
      Shake: [['Head', 0.6, 1.6, 0.03, 6, 1]],
      Events: [[0.7, 'Sniff']],
    },
    // asleep on its throne: belly down in the mud, slow breaths
    Sleep: {
      Duration: 4.4, Suppress: 1, Loop: true, FadeIn: 0.5,
      Keys: [[0.0, SLEEP, 'Sine'], [2.2, W(SLEEP, { Pelvis: [0, 0.12, 0.03, 0, -2.74, 0], Torso: [0.04, 0.06], Neck: [-0.38, 0.18] }), 'Sine'], [4.4, SLEEP, 'Sine']],
    },
    // the chase through the oasis canyons: it runs you down, rises up and lunges
    Chase: {
      Duration: 4.2, Suppress: 1,
      Gait: [[0, 3.1, 'Run', 1]],
      Keys: [
        [2.9, { Pelvis: [0, 0, 0, 0, 0, -7.5], Torso: [-0.06] }, 'Linear'],
        [3.3, W(STAND, { Pelvis: [0.55, 0, 0, 0, -0.3, -8.6], Neck: [-0.25], Head: [-0.25], Jaw: [-1.0] }), 'Out'],
        [3.55, W(SLAMMED, { Pelvis: [0, 0, 0, 0, -0.58, -9.6], Jaw: [0.02] }), 'In'],
        [3.95, Q(0.2, { Pelvis: [0, 0, 0, 0, -0.2, -9.6] }), 'Sine'],
      ],
      Events: [[3.0, 'Growl'], [3.55, 'Bite', { Scale: 1.7 }], [3.56, 'Impact', { At: 'VFX_RightFrontFoot', Scale: 1.4 }], [3.57, 'CameraShake', 0.9]],
    },
    // SIGNATURE: eyes open in the cracked mud of the dry riverbed... it erupts, shakes the mud off, rises onto its
    // hind legs with its jaws wide and roars the dust off the ground — then drops back down onto all fours
    BeforeTheDinosaurs: {
      Duration: 8.2, Suppress: 1, FadeIn: 0.01,
      Keys: [
        [0.0, BURIED, 'Linear'],
        [1.6, W(BURIED, { Head: [0.12, 0.08] }), 'Linear'],
        [2.05, ERUPT, 'Out'],
        [2.45, LOW, 'Sine'],
        [3.35, W(LOW, { Head: [0.1, 0.12], Jaw: [-0.3] }), 'Linear'],
        [4.4, STAND, 'Sine'],
        [4.72, W(STAND, { Neck: [-0.6], Head: [-0.55], Jaw: [-0.4], Torso: [0.08] }), 'Sine'],
        [5.0, ROAR_UP, 'Back'],
        [6.35, W(ROAR_UP, { Jaw: [-0.98], Head: [-0.08, 0, 0.06] }), 'Linear'],
        [6.95, SLAMMED, 'In'],
        [7.4, W(SLAMMED, { Jaw: [-0.45], Head: [0.18, 0, 0.08] }), 'Sine'],
        [8.2, W(SLAMMED, { Jaw: [-0.35], Head: [0.2, 0, -0.06] }), 'Linear'],
      ],
      Shake: [['Torso', 2.55, 3.3, 0.09, 6, 3], ['Neck', 2.55, 3.3, 0.18, 6, 2], ['Head', 2.55, 3.3, 0.14, 6, 3], ['Tail3', 2.55, 3.3, 0.2, 6, 2], ['Head', 5.0, 6.35, 0.04, 14, 3], ['Jaw', 5.0, 6.35, 0.03, 20, 1], ['~FrontLower', 5.0, 6.3, 0.15, 7, 1], ['Head', 7.4, 8.1, 0.03, 2, 1]],
      Events: [
        [0.3, 'MudBubble', { Scale: 1.0 }], [0.85, 'EyeGlow', 6.0], [1.05, 'MudBubble', { Scale: 1.4 }], [1.45, 'CameraShake', 0.25],
        [1.62, 'BreakProp', { Prop: 'MudCrust', Power: 1.4, At: 'VFX_Head' }], [1.64, 'MudBurst', { Scale: 2.4 }], [1.66, 'CameraShake', 1.0], [1.7, 'Growl'],
        [2.6, 'MudBurst', { Scale: 1.2, Spray: true }], [3.0, 'MudBurst', { Scale: 1.0, Spray: true }],
        [3.7, 'Footstep', { Side: 'Right' }], [4.3, 'Growl'],
        [5.0, 'Roar', { Scale: 2.3 }], [5.02, 'CameraShake', 1.1], [5.05, 'DustRing', { Scale: 2.4 }],
        [6.93, 'Impact', { At: 'VFX_RightFrontFoot', Scale: 2.2 }], [6.94, 'Impact', { At: 'VFX_LeftFrontFoot', Scale: 1.8 }], [6.95, 'BreakProp', { Prop: 'Bones', Power: 1.1, At: 'VFX_Chest' }], [6.96, 'CameraShake', 1.1],
      ],
    },
  },
};
