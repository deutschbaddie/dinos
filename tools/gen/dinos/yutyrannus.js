// FROST FOREST RULER — YUTYRANNUS (Legendary). "Feathered tyrant" (Xu et al. 2012): the biggest feathered animal
// known, ~9 m. A shaggy white-and-frost-grey tyrannosauroid with dark grey-blue stripes down its back, an ice-blue
// crest ridge along the snout, a feather mane, feathered "trousers" and longer three-fingered arms.
// ~28 studs long, ~13 tall. Forward = -Z.
const { makeDino, seg, boneAt, teeth, claw, eye, band, highlight } = require('./common.js');
const { rng } = require('../builder.js');

const C = {
  white: '#dfe6ef', whiteHi: '#f6f9fc', whiteLo: '#c7d1de', grey: '#9fb1c9', greyLo: '#8597b2', back: '#a9b9cf', backHi: '#bccadc',
  stripe: '#3f5470', stripeLo: '#2f405a', skin: '#8e9cb4', skinHi: '#a3b0c5', skinLo: '#66738d',
  ice: '#8fd2f5', iceLo: '#5fb0e0', claw: '#25282e', eye: '#ffb21a',
  mouth: '#6e1a22', mouthLo: '#4a1016', tongue: '#c4505a', tooth: '#f4ecd6', toothLo: '#e2d6b8',
};

// a shaggy feather tuft: a wedge whose slope runs back (layered shingles), slightly yawed
function tuft(ctx, p, s, c, r = [0, 0, 0], face = 'back') {
  return ctx.wedgeF({ name: 'FeatherTuft', s, p, r, face, c });
}
// hanging fringe tuft (points down): a wedge flipped so its point hangs
function fringe(ctx, p, s, c, r = [0, 0, 0]) {
  return ctx.wedgeF({ name: 'FeatherFringe', s, p, r, face: 'front', flip: true, c });
}

function build() {
  const { model, rig } = makeDino('Yutyrannus', {
    DisplayName: 'Yutyrannus', Rarity: 'Legendary', Classification: 'Feathered Tyrant', Personality: 'Patient, cold, relentless',
    Locomotion: 'Biped', SignatureMove: 'Blizzard King',
  }, [4, 4.5, 10], [0, 7.4, -0.5]);
  const S = { c: C.white };
  const R = rng(4242);

  // ---------------- Pelvis ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 7.6, 1.2], S);
  P.box({ name: 'Hip', s: [3.4, 3.2, 3.4], p: [0, 7.7, 1.3], studs: 'top' });
  P.box({ name: 'BackSaddle', s: [3.0, 0.5, 3.1], p: [0, 9.42, 1.3], c: C.back, studs: 'top' });
  P.box({ name: 'HipBelly', s: [2.4, 0.4, 2.2], p: [0, 6.0, 1.5], c: C.whiteLo });
  band(P, [0, 9.45, 0.45], [3.1, 0.56, 0.55], { c: C.stripe });
  band(P, [0, 9.45, 2.15], [3.1, 0.56, 0.55], { c: C.stripe });
  for (const [z, k] of [[0.0, 1], [1.3, 1.1], [2.6, 0.95]]) tuft(P, [0, 9.55, z], [1.5 * k, 0.6 * k, 1.1 * k], k > 1 ? C.stripeLo : C.whiteHi);
  P.sym((s) => fringe(s, [1.55, 6.2, 1.9], [0.5, 0.8, 1.0], C.whiteLo, [0, 0, 8]));

  // ---------------- Torso ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 7.6, -0.6], S);
  T.box({ name: 'Body', s: [3.9, 3.6, 4.0], p: [0, 7.75, -2.2], studs: 'top' });
  T.box({ name: 'BackHump', s: [3.2, 0.6, 3.6], p: [0, 9.85, -2.0], c: C.back, studs: 'top' });
  T.box({ name: 'ChestFront', s: [3.3, 3.0, 1.0], p: [0, 7.6, -4.4] });
  band(T, [0, 9.55, -0.9], [3.96, 0.5, 0.55], { c: C.stripe });
  band(T, [0, 9.55, -2.3], [3.96, 0.5, 0.55], { c: C.stripe });
  band(T, [0, 9.55, -3.7], [3.96, 0.5, 0.5], { c: C.stripe });
  T.box({ name: 'BackFlank', s: [3.96, 0.9, 3.6], p: [0, 8.95, -2.2], c: C.back });
  for (const [z, k] of [[-0.6, 1.1], [-1.9, 1.2], [-3.2, 1.05]]) tuft(T, [0, 10.45, z], [1.6 * k, 0.6 * k, 1.2 * k], z === -1.9 ? C.stripeLo : C.whiteHi);
  T.sym((s) => {
    s.box({ name: 'Shoulder', s: [0.5, 1.4, 1.6], p: [1.85, 7.2, -3.3], c: C.whiteLo });
    fringe(s, [1.5, 5.85, -2.6], [0.55, 0.85, 1.4], C.whiteHi, [0, 0, 8]);
  });
  // feather bib hanging from the chest
  fringe(T, [0, 6.0, -4.8], [2.6, 1.6, 0.8], C.whiteHi);
  fringe(T, [0, 5.3, -4.5], [1.8, 1.2, 0.6], C.white);

  const [chest, Ch] = boneAt(rig, T, 'Chest', torso, [0, 6.2, -2.3], S);
  Ch.box({ name: 'BellyMass', s: [3.3, 0.7, 3.4], p: [0, 5.6, -1.9], c: C.whiteLo });
  for (const z of [-0.8, -2.0, -3.2]) fringe(Ch, [0, 5.0, z], [2.6, 0.9, 1.0], z === -2.0 ? C.grey : C.white);
  T.attach('VFX_Chest', [0, 7.0, -5.0]);

  // ---------------- Neck with a feather mane ----------------
  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 8.5, -4.3], S);
  const n1 = N1.at([0, 8.5, -4.3], [-35, 0, 0]);
  n1.box({ name: 'NeckBase', s: [3.0, 2.4, 2.8], p: [0, 0.5, 0], studs: 'top' });
  n1.box({ name: 'NeckBack', s: [2.6, 1.9, 0.5], p: [0, 0.6, 1.3], c: C.back });
  n1.box({ name: 'Throat', s: [2.4, 2.1, 0.3], p: [0, 0.35, -1.45], c: C.whiteHi });
  band(n1, [0, 1.2, 0.9], [3.1, 0.6, 1.0], { c: C.stripe });
  tuft(n1, [0, 1.95, 0.4], [1.6, 0.7, 1.4], C.whiteHi);
  n1.sym((s) => { tuft(s, [1.5, 0.9, 0.2], [0.35, 1.2, 1.4], C.white, [0, 0, -14]); fringe(s, [1.2, -0.7, -1.0], [0.6, 1.1, 0.9], C.whiteHi, [0, 0, 10]); });
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 9.45, -5.45], S);
  const n2 = N2.at([0, 9.45, -5.45], [-30, 0, 0]);
  n2.box({ name: 'NeckUpper', s: [2.6, 2.0, 2.4], p: [0, 0.4, -0.1], studs: 'top' });
  n2.box({ name: 'Throat', s: [2.1, 1.7, 0.3], p: [0, 0.3, -1.3], c: C.whiteHi });
  band(n2, [0, 1.05, 0.8], [2.7, 0.55, 0.75], { c: C.stripe });
  n2.box({ name: 'NeckBack', s: [2.2, 1.5, 0.4], p: [0, 0.4, 1.12], c: C.back });
  tuft(n2, [0, 1.6, 0.3], [1.4, 0.6, 1.3], C.white);
  n2.sym((s) => tuft(s, [1.32, 0.8, 0.0], [0.3, 1.1, 1.3], C.whiteHi, [0, 0, -14]));

  // ---------------- Head ----------------
  const HP = [0, 10.15, -6.3], HK = 1.28;
  const [head, H0] = boneAt(rig, N2, 'Head', neck2, HP, S);
  const H = H0.scaled(HK, HP);
  H.box({ name: 'Cranium', s: [2.7, 2.0, 2.1], p: [0, 10.85, -6.9], c: C.back, studs: 'top' });
  H.box({ name: 'FaceLower', s: [2.2, 0.55, 3.8], p: [0, 10.05, -9.3], c: C.whiteHi });
  H.box({ name: 'Snout', s: [2.1, 0.95, 3.6], p: [0, 10.8, -9.4], c: C.skin });
  H.box({ name: 'SnoutTop', s: [1.8, 0.2, 3.2], p: [0, 11.27, -9.6], c: C.skinHi, studs: 'top' });
  H.wedgeF({ name: 'ForeheadSlope', s: [2.2, 0.5, 0.9], p: [0, 11.48, -8.15], face: 'front', c: C.skin });
  H.box({ name: 'Nose', s: [1.8, 1.15, 0.6], p: [0, 10.45, -11.5], c: C.skin });
  H.wedgeF({ name: 'NoseSlope', s: [1.8, 0.4, 0.6], p: [0, 11.22, -11.5], face: 'front', c: C.skinHi });
  H.box({ name: 'HeadStripe', s: [2.76, 0.6, 0.4], p: [0, 11.55, -6.4], c: C.stripe });
  // the crest ridge: a run of ice-blue bumps along the top of the snout
  H.box({ name: 'CrestBase', s: [0.56, 0.2, 3.4], p: [0, 11.38, -9.65], c: C.stripe });
  [[-8.3, 0.4], [-9.0, 0.55], [-9.7, 0.62], [-10.4, 0.5], [-11.05, 0.32]].forEach(([z, h], i) => {
    H.wedgeF({ name: 'CrestRidge', s: [0.38, h, 0.6], p: [0, 11.48 + h / 2, z], face: i < 2 ? 'back' : 'front', c: i % 2 ? C.iceLo : C.ice });
  });
  // feather cap sweeping back off the skull + cheek tufts
  tuft(H, [0, 12.05, -6.5], [1.9, 0.55, 1.4], C.whiteHi);
  tuft(H, [0, 11.95, -5.7], [1.5, 0.5, 1.0], C.white);
  H.box({ name: 'Palate', s: [1.75, 0.25, 4.2], p: [0, 9.75, -9.0], c: C.mouth });
  H.box({ name: 'Throat', s: [1.7, 1.1, 0.7], p: [0, 9.8, -6.9], c: C.mouthLo });
  H.sym((s) => {
    s.box({ name: 'UpperLip', s: [0.14, 0.3, 4.4], p: [1.05, 9.98, -9.3], c: C.stripe });
    s.box({ name: 'BrowRidge', s: [0.7, 0.45, 1.25], p: [1.0, 11.75, -7.35], r: [0, -10, -15], c: C.stripe, studs: 'top' });
    s.box({ name: 'EyeMask', s: [0.12, 0.42, 1.5], p: [1.37, 11.05, -6.75], c: C.stripe });
    eye(s, [1.39, 11.22, -7.45], { h: 0.5, d: 0.6, c: C.eye, lid: C.back });
    s.box({ name: 'JawMuscle', s: [0.4, 1.3, 1.3], p: [1.25, 10.4, -6.85], c: C.whiteLo });
    tuft(s, [1.42, 10.9, -6.0], [0.3, 1.0, 1.3], C.whiteHi, [0, 0, -18]);
    s.box({ name: 'SnoutScale', s: [0.1, 0.4, 0.7], p: [1.07, 10.7, -8.6], c: C.skinLo });
    s.box({ name: 'SnoutScale', s: [0.1, 0.3, 0.6], p: [1.07, 10.85, -10.0], c: C.skinLo });
    s.box({ name: 'Nostril', s: [0.3, 0.2, 0.34], p: [0.55, 11.05, -11.55], c: '#151515' });
    teeth(s, { n: 7, x: 0.9, y: 9.85, z0: -7.8, z1: -11.3, h: 0.42, d: 0.3, w: 0.22, dir: 'down', sizes: [0.85, 1.15, 1.0, 1.3, 1.05, 1.15, 0.9], c: C.tooth });
  });
  for (const x of [-0.5, -0.17, 0.17, 0.5]) H.wedgeF({ name: 'Tooth', s: [0.18, 0.36, 0.22], p: [x, 9.68, -11.65], face: 'front', flip: true, c: C.tooth, shadow: false });
  H.attach('VFX_Mouth', [0, 9.75, -11.7]);
  H.attach('VFX_Roar', [0, 9.75, -10.0]);
  H.attach('VFX_Head', [0, 11.0, -8.0]);
  H.attach('VFX_Crest', [0, 12.0, -9.7]);
  H.sym((s, side, n) => s.attach(`VFX_${n}Eye`, [1.46, 11.22, -7.45]));

  // ---------------- Jaw ----------------
  const [jaw, J0] = boneAt(rig, H, 'Jaw', head, [0, 9.75, -7.1], S);
  const J = J0.scaled(HK, HP);
  J.box({ name: 'LowerJaw', s: [1.95, 0.7, 4.0], p: [0, 9.4, -9.4], c: C.skin });
  J.box({ name: 'Chin', s: [1.75, 0.7, 0.5], p: [0, 9.4, -11.5], c: C.skin });
  J.box({ name: 'JawUnderside', s: [1.7, 0.2, 4.0], p: [0, 9.0, -9.5], c: C.whiteLo });
  J.box({ name: 'JawHinge', s: [1.9, 0.7, 0.7], p: [0, 9.55, -7.7], c: C.whiteLo });
  J.box({ name: 'Tongue', s: [1.1, 0.2, 2.8], p: [0, 9.8, -8.8], c: C.tongue });
  J.box({ name: 'JawMouth', s: [1.6, 0.1, 4.0], p: [0, 9.75, -9.3], c: C.mouth });
  fringe(J, [0, 8.8, -8.7], [1.4, 0.6, 1.0], C.whiteHi);
  J.sym((s) => {
    s.box({ name: 'LowerLip', s: [0.12, 0.26, 4.4], p: [0.98, 9.58, -9.3], c: C.stripe });
    teeth(s, { n: 6, x: 0.8, y: 9.77, z0: -8.1, z1: -11.1, h: 0.36, d: 0.28, w: 0.2, dir: 'up', sizes: [0.85, 1.15, 1.25, 1.0, 1.1, 0.9], c: C.tooth });
  });

  // ---------------- Longer three-fingered arms with feather fringe ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [1.75, 6.9, -3.9], S);
    A.box({ name: 'UpperArm', s: [0.65, 1.7, 0.65], p: [1.85, 6.1, -4.1], r: [14, 0, 0], c: C.whiteLo });
    tuft(A, [2.05, 6.0, -3.6], [0.25, 1.3, 0.9], C.white, [14, 0, 0]);
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [1.9, 5.3, -4.35], S);
    F.box({ name: 'Forearm', s: [0.55, 1.5, 0.55], p: [1.92, 4.85, -5.0], r: [-48, 0, 0], c: C.skin });
    F.box({ name: 'ForearmFeathers', s: [0.2, 0.9, 1.3], p: [2.12, 4.95, -4.75], r: [-48, 0, 0], c: C.white });
    F.box({ name: 'Hand', s: [0.55, 0.42, 0.55], p: [1.92, 4.35, -5.65], c: C.skin });
    for (const [dx, k] of [[-0.18, 0.9], [0, 1.05], [0.18, 0.85]]) claw(F, [1.92 + dx, 4.15, -5.95], { s: 0.42 * k, c: C.claw });
    if (n === 'Right') F.attach('VFX_RightClaw', [1.92, 4.0, -6.1]);
  });

  // ---------------- Massive legs in feathered trousers ----------------
  P.sym((s, side, n) => {
    const [thigh, Th] = boneAt(rig, s, `${n}Thigh`, pelvis, [2.0, 7.4, 1.2], S);
    Th.box({ name: 'Thigh', s: [1.6, 3.4, 2.9], p: [2.7, 6.2, 0.7], r: [-12, 0, 0], studs: 'top' });
    band(Th, [2.72, 6.9, 0.8], [1.66, 0.55, 2.96], { c: C.stripe, r: [-12, 0, 0] });
    for (const z of [-0.2, 1.1]) fringe(Th, [2.85, 4.8, z], [1.5, 0.7, 1.3], z > 0 ? C.whiteHi : C.whiteLo, [-12, 0, 0]);
    Th.box({ name: 'Knee', s: [1.2, 1.0, 1.15], p: [2.62, 4.6, -0.2], c: C.whiteLo });
    const [shin, Sh] = boneAt(rig, Th, `${n}Shin`, thigh, [2.6, 4.45, -0.3], S);
    Sh.box({ name: 'Shin', s: [1.3, 2.9, 1.45], p: [2.62, 3.25, 0.35], r: [28, 0, 0], c: C.skin });
    Sh.box({ name: 'ShinScale', s: [1.0, 1.8, 0.14], p: [2.62, 3.35, -0.36], r: [28, 0, 0], c: C.skinLo });
    const [foot, Fo] = boneAt(rig, Sh, `${n}Foot`, shin, [2.6, 1.95, 1.05], S);
    Fo.box({ name: 'Metatarsus', s: [1.05, 1.8, 1.05], p: [2.6, 1.25, 0.5], r: [-35, 0, 0], c: C.skinLo });
    Fo.wedgeF({ name: 'HeelSpur', s: [0.5, 0.5, 0.6], p: [2.6, 1.65, 1.45], face: 'back', c: C.stripe });
    const [toes, To] = boneAt(rig, Fo, `${n}Toes`, foot, [2.6, 0.5, -0.2], S);
    To.box({ name: 'ToePad', s: [1.3, 0.5, 1.0], p: [2.6, 0.25, -0.4], c: C.skinLo });
    for (const [dx, ry, k] of [[-0.45, 10, 0.9], [0, 0, 1.05], [0.45, -10, 0.9]]) {
      To.box({ name: 'Toe', s: [0.42, 0.45, 1.2 * k], p: [2.6 + dx, 0.24, -1.05 * k], r: [0, ry, 0], c: C.skin });
      claw(To, [2.6 + dx * 1.15, 0.3, -1.7 * k], { s: 0.42, c: C.claw, r: [0, ry, 0] });
    }
    To.wedgeF({ name: 'Dewclaw', s: [0.3, 0.3, 0.4], p: [2.25, 0.35, 0.25], face: 'back', c: C.claw });
    To.attach(`VFX_${n}Foot`, [2.6, 0.05, -0.6]);
  });

  // ---------------- Long shaggy tail ----------------
  const tail = [
    { p: [0, 7.9, 3.0], s: [3.0, 2.7, 2.4], c: [0, 7.95, 3.95] },
    { p: [0, 7.8, 5.1], s: [2.4, 2.2, 2.3], c: [0, 7.85, 6.05] },
    { p: [0, 7.6, 7.2], s: [1.9, 1.75, 2.2], c: [0, 7.65, 8.1] },
    { p: [0, 7.35, 9.2], s: [1.45, 1.35, 2.1], c: [0, 7.4, 10.05] },
    { p: [0, 7.1, 11.1], s: [1.05, 1.0, 2.0], c: [0, 7.12, 11.9] },
    { p: [0, 6.85, 12.9], s: [0.7, 0.65, 1.9], c: [0, 6.87, 13.65] },
  ];
  let parent = pelvis, pc = P;
  tail.forEach((d, i) => {
    const [tb, Tc] = boneAt(rig, pc, `Tail${i + 1}`, parent, d.p, S);
    Tc.box({ name: 'TailSegment', s: d.s, p: d.c, studs: 'top' });
    Tc.box({ name: 'TailSaddle', s: [d.s[0] * 0.86, 0.3 * (1 - i * 0.1), d.s[2] * 0.96], p: [0, d.c[1] + d.s[1] / 2 + 0.1, d.c[2]], c: C.back });
    if (i % 2 === 0) band(Tc, [0, d.c[1] + d.s[1] * 0.36, d.c[2] + d.s[2] * 0.1], [d.s[0] + 0.08, d.s[1] * 0.34, d.s[2] * 0.36], { c: C.stripe });
    tuft(Tc, [0, d.c[1] + d.s[1] / 2 + 0.25 * (1 - i * 0.12), d.c[2] - d.s[2] * 0.25], [d.s[0] * 0.55, 0.5 * (1 - i * 0.1), d.s[2] * 0.55], i % 2 ? C.whiteLo : C.whiteHi);
    if (i < 4) fringe(Tc, [0, d.c[1] - d.s[1] / 2 - 0.3 * (1 - i * 0.15), d.c[2]], [d.s[0] * 0.7, 0.7 * (1 - i * 0.15), d.s[2] * 0.7], C.whiteLo);
    if (i === tail.length - 1) {
      tuft(Tc, [0, 6.95, 14.9], [0.9, 0.55, 1.1], C.whiteHi);
      Tc.wedgeF({ name: 'TailTip', s: [0.55, 0.5, 0.7], p: [0, 6.82, 14.95], face: 'back', c: C.white });
      Tc.attach('VFX_TailTip', [0, 6.85, 15.3]);
    }
    parent = tb; pc = Tc;
  });

  highlight(model);
  return model;
}

module.exports = { build };
