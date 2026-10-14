// Dilophosaurus — showy, sly, hunts in pairs. Signature: CREST FLARE (it notices you, the crests flush bright,
// a head-bobbing display... then a green spit glob straight at the lens).
const { W } = require('./util.js');

// legs bent by k with the hips dropped to match (keeps the feet planted: k = 1 drops the hips 0.4)
const L = (k, extra = {}) => W({ '~Thigh': [0.22 * k], '~Shin': [-0.4 * k], '~Foot': [0.18 * k] }, extra);
const CROUCH = L(1, { Pelvis: [0, 0, 0, 0, -0.4, 0] });
const SNIFF_LOW = W(CROUCH, { Pelvis: [0, 0.35, 0, 0, -0.4, 0], Torso: [-0.1, 0.05], Neck1: [-0.45, 0.1], Neck2: [-0.25], Head: [-0.05, 0.1], Jaw: [-0.05], Tail1: [-0.08, -0.15], Tail2: [0, -0.1] });
const NOTICE = L(0, { Pelvis: [0, 0.35, 0, 0, 0, 0], Torso: [0.05, -0.05], Neck1: [0.2, -0.22], Neck2: [0.1, -0.1], Head: [0.04, -0.1, 0.16], Jaw: [-0.06], '~Arm': [-0.15, 0, 0.2], Tail1: [-0.12, -0.1] });
const DISPLAY = L(0.25, { Pelvis: [0, 0.6, 0, -0.6, -0.1, 0], Torso: [0.08, -0.12], Neck1: [0.28, -0.42], Neck2: [0.15, -0.2], Head: [0.12, -0.18, 0.22], Jaw: [-0.32], '~Arm': [-0.45, 0, 0.5], '~Forearm': [-0.6], Tail1: [-0.2, 0.25], Tail2: [-0.1, 0.3], Tail3: [0, 0.32], Tail4: [0, 0.3] });
const DISPLAY_B = W(DISPLAY, L(0.38, { Pelvis: [0, 0.45, 0, -0.9, -0.15, -0.2], Head: [0.1, -0.12, -0.2], Jaw: [-0.4], Tail1: [-0.2, -0.2], Tail2: [-0.1, -0.25], Tail3: [0, -0.3], Tail4: [0, -0.3] }));
const INHALE = L(0, { Pelvis: [0, 0.1, 0, -0.4, 0, 0.5], Torso: [0.1], Neck1: [0.32], Neck2: [0.22], Head: [0.3], Jaw: [-0.38], '~Arm': [-0.3, 0, 0.3], Tail1: [0.06] });
const SPIT = W(CROUCH, { Pelvis: [0, 0, 0, -0.3, -0.4, -0.8], Torso: [-0.12], Neck1: [-0.02], Neck2: [0.02], Head: [0.32], Jaw: [-0.95], '~Arm': [0.4, 0, 0.3], Tail1: [-0.25], Tail2: [-0.12] });
const HISS = L(0.25, { Pelvis: [0, 0, 0, -0.2, -0.1, -0.5], Torso: [0.04], Neck1: [0.1], Neck2: [0.05], Head: [0.16, 0, 0.14], Jaw: [-0.6], '~Arm': [-0.3, 0, 0.45], '~Forearm': [-0.5], Tail1: [-0.15, 0.15], Tail2: [-0.08, 0.2] });
const BITE_OPEN = L(0.38, { Neck1: [0.15], Neck2: [0.1], Head: [0.2], Jaw: [-0.85], Pelvis: [0, 0, 0, 0, -0.15, 0.4] });
const BITE_SHUT = L(0.38, { Neck1: [-0.2], Neck2: [-0.1], Head: [-0.12], Jaw: [0.03], Torso: [-0.15], Pelvis: [0, 0, 0, 0, -0.15, -1.1] });

module.exports = {
  Signature: 'CrestFlare', Intro: 'CrestFlare', IntroShots: 'DiloSpit', Chase: 'Chase', Special: 'CrestDisplay',
  CycleOrder: ['Walk', 'Run', 'CrestDisplay', 'LookAround', 'BlindingSpit', 'DoubleBite', 'Attack', 'Stunned', 'Roar'],
  CameraScale: 1.8,
  Gait: {
    Type: 'Biped', Scale: 1.6, Neck: ['Neck1', 'Neck2'], Tail: ['Tail1', 'Tail2', 'Tail3', 'Tail4', 'Tail5'],
    Idle: { Breath: 0.4, BreathAmp: 1.1, Sway: 0.1, Look: 0.4, Twitch: true, JawIdle: 0.05 },
    Walk: { Freq: 1.0, Stride: 0.42, Knee: 0.66, Bob: 0.12, Roll: 0.05, Yaw: 0.07, Lean: 0.05, TailSway: 0.14, HeadBob: 0.08, Speed: 6 },
    Run: { Freq: 1.8, Stride: 0.48, Knee: 0.9, Bob: 0.22, Roll: 0.03, Yaw: 0.05, Lean: 0.2, TailSway: 0.08, HeadBob: 0.09, ThighBias: 0, Speed: 18 },
  },
  Actions: {
    // a rattling hiss-screech, crests flushing
    Roar: {
      Duration: 2.3, Suppress: 0.9,
      Keys: [
        [0.35, W(CROUCH, { Neck1: [-0.2], Head: [-0.15], Jaw: [-0.15] }), 'Sine'],
        [0.7, HISS, 'Back'],
        [1.7, W(HISS, { Head: [0.12, 0, -0.14], Jaw: [-0.66] }), 'Sine'],
      ],
      Shake: [['Head', 0.7, 1.7, 0.08, 4, 1], ['Jaw', 0.7, 1.7, 0.05, 24, 1]],
      Events: [[0.6, 'CrestFlush', 2.0], [0.68, 'EyeGlow', 1.4], [0.7, 'Roar', { Scale: 0.9, Screech: true }], [0.72, 'CameraShake', 0.35]],
    },
    Attack: {
      Duration: 1.3, Suppress: 0.95,
      Keys: [[0.3, BITE_OPEN, 'Out'], [0.5, W(BITE_SHUT, { Jaw: [-0.7] }), 'Snap'], [0.56, BITE_SHUT, 'Snap'], [0.9, { Head: [0.1, 0.2, 0.15], Pelvis: [0, 0, 0, 0, 0, -0.4] }, 'Sine']],
      Events: [[0.56, 'Bite', { Scale: 0.9 }], [0.58, 'CameraShake', 0.35]],
    },
    // takedown: the pair's double-team — two snaps, left then right
    DoubleBite: {
      Duration: 1.7, Suppress: 0.95,
      Keys: [
        [0.25, W(BITE_OPEN, { Neck1: [0.15, 0.25], Head: [0.2, 0.15] }), 'Out'],
        [0.42, W(BITE_SHUT, { Neck1: [-0.2, 0.3], Head: [-0.12, 0.2], Pelvis: [0, 0.15, 0, 0, -0.15, -0.9] }), 'Snap'],
        [0.7, W(BITE_OPEN, { Neck1: [0.15, -0.25], Head: [0.2, -0.15], Pelvis: [0, 0, 0, 0, -0.15, -0.5] }), 'Out'],
        [0.88, W(BITE_SHUT, { Neck1: [-0.2, -0.3], Head: [-0.12, -0.2], Pelvis: [0, -0.15, 0, 0, -0.15, -1.3] }), 'Snap'],
        [1.25, { Head: [0.1, 0, 0.15], Pelvis: [0, 0, 0, 0, 0, -0.6] }, 'Sine'],
      ],
      Events: [[0.42, 'Bite', { Scale: 0.8 }], [0.88, 'Bite', { Scale: 0.9 }], [0.9, 'CameraShake', 0.35]],
    },
    // takedown: inhale... and a blinding spit (the target's next attacks miss)
    BlindingSpit: {
      Duration: 1.9, Suppress: 0.95,
      Keys: [[0.55, INHALE, 'Back'], [0.72, SPIT, 'Snap'], [0.95, SPIT, 'Linear'], [1.4, W(HISS, { Pelvis: [0, 0, 0, 0, -0.1, -0.4] }), 'Sine']],
      Shake: [['Head', 0.95, 1.4, 0.06, 5, 1]],
      Events: [[0.2, 'CrestFlush', 1.6], [0.45, 'Growl'], [0.74, 'SpitGlob', { Splat: true, Range: 34, Scale: 0.9 }]],
    },
    // takedown / special: CREST DISPLAY — a mesmerising bob-and-flare that freezes you in place
    CrestDisplay: {
      Duration: 2.8, Suppress: 0.9,
      Keys: [[0.4, W(DISPLAY, { Pelvis: [0, 0.6, 0, 0, -0.1, 0] }), 'Back'], [1.4, W(DISPLAY_B, { Pelvis: [0, 0.45, 0, 0, -0.15, -0.2] }), 'Sine'], [2.2, W(DISPLAY, { Pelvis: [0, 0.6, 0, 0, -0.1, 0] }), 'Sine']],
      Shake: [['Head', 0.4, 2.3, 0.16, 3.4, 1], ['Neck1', 0.4, 2.3, 0.06, 3.4, 1]],
      Events: [[0.3, 'CrestFlush', 2.6], [0.45, 'Roar', { Scale: 0.5, Screech: true }], [1.2, 'TailSwing', 0.6]],
    },
    Stunned: {
      Duration: 2.6, Suppress: 0.9,
      Keys: [
        [0.25, { Pelvis: [0, 0, 0.14, 0, -0.1, 0.6], Torso: [0.15], Neck1: [0.3], Head: [0.3, 0, 0.3], Jaw: [-0.4] }, 'Out'],
        [0.7, { Pelvis: [0, 0, -0.1, 0, -0.35, 0.5], Neck1: [-0.2], Head: [-0.2, 0, -0.3], '~Thigh': [0.22], '~Shin': [-0.4], Jaw: [-0.3] }, 'Sine'],
        [2.0, { Pelvis: [0, 0, 0.05, 0, -0.25, 0.4], Neck1: [-0.15], Head: [-0.1, 0, 0.2], '~Thigh': [0.16], '~Shin': [-0.3] }, 'Linear'],
      ],
      Procedural: { Type: 'Dizzy', T0: 0.5, T1: 2.3, Rate: 5.5, Head: [0.25, 0.2], Neck: 0.12, Roll: 0.05 },
      Events: [[0.05, 'Stunned', { Scale: 0.9 }], [0.1, 'CameraShake', 0.3]],
    },
    LookAround: {
      Duration: 3.4, Suppress: 0.6,
      Keys: [
        [0.5, { Neck1: [0.12, 0.42], Neck2: [0.06, 0.2], Head: [0.05, 0.35, 0.15] }, 'Sine'],
        [1.2, { Neck1: [0.12, 0.45], Neck2: [0.06, 0.2], Head: [0.1, 0.38, 0.08] }, 'Linear'],
        [1.6, { Neck1: [0.1, -0.42], Neck2: [0.06, -0.2], Head: [0.05, -0.35, -0.15], Tail3: [0, 0.18] }, 'Snap'],
        [2.6, { Neck1: [0.1, -0.45], Neck2: [0.06, -0.2], Head: [0.1, -0.38, -0.08], Tail3: [0, 0.18] }, 'Linear'],
      ],
      Shake: [['Head', 1.2, 1.5, 0.05, 6, 1]],
      Events: [[1.3, 'Sniff']],
    },
    Sniff: {
      Duration: 1.8, Suppress: 0.8,
      Keys: [[0.5, W(SNIFF_LOW, { Pelvis: [0, 0, 0, 0, -0.4, 0] }), 'Sine'], [1.3, W(SNIFF_LOW, { Pelvis: [0, 0, 0, 0, -0.4, 0], Head: [-0.08, 0.1] }), 'Linear']],
      Shake: [['Head', 0.5, 1.3, 0.04, 7, 1]],
      Events: [[0.6, 'Sniff']],
    },
    // the chase: it runs alongside, rears its head back and spits on the windscreen
    Chase: {
      Duration: 3.6, Suppress: 1,
      Gait: [[0, 2.6, 'Run', 1]],
      Keys: [
        [2.4, { Pelvis: [0, 0, 0, 0, 0, -5.6], Torso: [-0.1] }, 'Linear'],
        [2.75, W(INHALE, { Pelvis: [0, 0, 0, 0, 0, -6.0] }), 'Back'],
        [2.92, W(SPIT, { Pelvis: [0, 0, 0, 0, -0.4, -6.8] }), 'Snap'],
        [3.3, W(HISS, { Pelvis: [0, 0, 0, 0, -0.1, -6.8] }), 'Sine'],
      ],
      Events: [[2.5, 'CrestFlush', 1.5], [2.93, 'SpitGlob', { Splat: true, Range: 40, Scale: 1.0 }]],
    },
    // SIGNATURE: nose to the ground... it notices you; the crests flush bright; the bobbing display (its tail
    // snaps a dead branch); it rears its head back... and spits right at the lens
    CrestFlare: {
      Duration: 6.4, Suppress: 1, FadeIn: 0.15,
      Keys: [
        [0.3, SNIFF_LOW, 'Sine'],
        [1.2, W(SNIFF_LOW, { Head: [-0.1, 0.18], Neck1: [-0.48, 0.16] }), 'Linear'],
        [1.42, NOTICE, 'Snap'],
        [1.9, W(NOTICE, { Head: [0.08, -0.12, 0.24] }), 'Linear'],
        [2.25, DISPLAY, 'Back'],
        [2.85, DISPLAY_B, 'Sine'],
        [3.35, W(DISPLAY, { Pelvis: [0, 0.4, 0, -0.5, -0.1, 0] }), 'Sine'],
        [3.82, INHALE, 'Back'],
        [3.95, SPIT, 'Snap'],
        [4.35, SPIT, 'Linear'],
        [4.75, HISS, 'Sine'],
        [5.7, W(HISS, { Head: [0.12, 0, -0.12], Jaw: [-0.55] }), 'Sine'],
        [6.4, W(HISS, { Head: [0.14, 0, 0.1], Jaw: [-0.4] }), 'Linear'],
      ],
      Shake: [['Head', 0.35, 1.2, 0.04, 7, 1], ['Head', 2.0, 3.45, 0.16, 3.4, 1], ['Neck1', 2.0, 3.45, 0.06, 3.4, 1], ['Jaw', 4.75, 5.7, 0.05, 24, 1], ['Head', 4.75, 6.3, 0.07, 3, 1]],
      Events: [
        [0.4, 'Sniff'], [0.95, 'Sniff'], [1.42, 'CrestFlush', 4.8], [1.43, 'EyeGlow', 4.5], [1.44, 'CameraShake', 0.15],
        [1.6, 'PackCue', { Action: 'CrestDisplay', Stagger: 0 }], [2.25, 'Roar', { Scale: 0.55, Screech: true }],
        [3.15, 'TailSwing', 0.8], [3.32, 'BreakProp', { Prop: 'Snag', Power: 0.9, At: 'VFX_TailTip' }],
        [3.6, 'Growl'], [3.96, 'SpitGlob', { Splat: true, Range: 40, Scale: 1.1 }], [3.97, 'CameraShake', 0.2],
        [4.75, 'Roar', { Scale: 0.8, Screech: true }], [4.77, 'CameraShake', 0.3],
      ],
    },
  },
};
