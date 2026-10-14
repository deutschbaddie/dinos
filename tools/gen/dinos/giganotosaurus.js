// DINOSAUR 10 — GIGANOTOSAURUS (Legendary). Brutal, relentless. ~27 studs long, ~14 tall.
// Deliberately different from the T. rex: long narrow skull, jagged crest, longer body, bigger arms.
const { makeDino, seg, boneAt, teeth, claw, dorsal, eye, band, highlight, segBox, bipedLeg, tailChain } = require('./common.js');

const C = {
  body: '#3a3a44', bodyHi: '#4a4a56', bodyLo: '#2c2c34', purple: '#4a3a5a', purpleLo: '#3a2c48', crimson: '#a8242a', crimsonLo: '#7e1a1f',
  belly: '#8a8090', tooth: '#efe8d8', eye: '#ff5a1a', mouth: '#4a0d14', tongue: '#a8384a', claw: '#141414', spike: '#26262c',
};

function build() {
  const { model, rig } = makeDino('Giganotosaurus', {
    DisplayName: 'Giganotosaurus', Rarity: 'Legendary', Classification: 'Giant Apex Predator', Personality: 'Brutal, relentless',
    Locomotion: 'Biped', SignatureMove: 'The Predator Arrives',
  }, [4, 4.5, 10], [0, 8.2, 0]);
  const S = { c: C.body };
  const saw = (ctx, pts) => dorsal(ctx, pts, { h: 0.75, d: 0.9, w: 0.42, c: C.spike, face: 'back' });

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 8.2, 1.6], S);
  P.box({ name: 'Hip', s: [3.4, 3.4, 3.2], p: [0, 8.2, 1.8], studs: 'top' });
  P.box({ name: 'HipRidge', s: [2.6, 0.5, 2.8], p: [0, 10.1, 1.8], c: C.purple });
  P.box({ name: 'HipBelly', s: [2.7, 0.3, 3.0], p: [0, 6.4, 1.7], c: C.belly });
  for (const z of [1.0, 2.5]) band(P, [0, 9.3, z], [3.46, 1.0, 0.45], { c: C.crimson });
  saw(P, [[10.35, 0.8, 1], [10.35, 2.0, 1.1], [10.35, 3.1, 0.9]]);

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 8.3, -0.4], S);
  T.box({ name: 'Body', s: [3.7, 3.7, 4.8], p: [0, 8.3, -2.1], studs: 'top' });
  T.box({ name: 'BackRidge', s: [2.8, 0.5, 4.4], p: [0, 10.4, -2.0], c: C.purple });
  T.box({ name: 'ChestFront', s: [3.1, 3.0, 1.0], p: [0, 8.1, -4.9], c: C.bodyLo });
  for (const z of [-0.8, -2.2, -3.6]) band(T, [0, 9.45, z], [3.76, 1.0, 0.45], { c: C.crimson });
  T.sym((s) => { for (let i = 0; i < 5; i++) s.box({ name: 'FlankRidge', s: [0.12, 0.25, 0.9], p: [1.88, 8.9 - i * 0.55, -1.0 - i * 0.6], r: [-30, 0, 0], c: C.purpleLo }); });
  saw(T, [[10.65, -0.4, 1.1], [10.65, -1.6, 1.25], [10.65, -2.8, 1.2], [10.6, -4.0, 1.0]]);
  const [chest, Ch] = boneAt(rig, T, 'Chest', torso, [0, 6.8, -2.6], S);
  for (let i = 0; i < 6; i++) Ch.box({ name: 'BellyScute', s: [2.9 - i * 0.08, 0.38, 0.8], p: [0, 6.25 + i * 0.12, -0.2 - i * 0.78], c: i % 2 ? C.belly : '#9a90a0' });
  T.attach('VFX_Chest', [0, 7.4, -5.5]);

  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 8.9, -5.2], S);
  segBox(N1, [0, 8.9, -5.2], [0, 9.9, -6.4], 2.7, 2.6, { name: 'NeckBase', studs: 'top' });
  N1.box({ name: 'Throat', s: [2.1, 1.8, 0.25], p: [0, 8.6, -6.3], r: [-35, 0, 0], c: C.belly });
  saw(N1, [[10.6, -5.6, 0.9]]);
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 9.8, -6.35], S);
  segBox(N2, [0, 9.8, -6.35], [0, 10.5, -7.3], 2.3, 2.3, { name: 'NeckUpper' });
  saw(N2, [[11.15, -6.6, 0.8]]);

  const [head, H] = boneAt(rig, N2, 'Head', neck2, [0, 10.55, -7.3], S);
  H.box({ name: 'Cranium', s: [2.3, 2.2, 2.1], p: [0, 11.1, -8.1], studs: 'top' });
  H.box({ name: 'Snout', s: [1.8, 1.55, 4.8], p: [0, 10.75, -11.4] });
  H.box({ name: 'SnoutTop', s: [1.4, 0.25, 4.5], p: [0, 11.65, -11.2], c: C.bodyHi });
  H.box({ name: 'NoseTip', s: [1.6, 1.3, 0.6], p: [0, 10.65, -14.05], c: C.bodyLo });
  H.box({ name: 'Palate', s: [1.5, 0.2, 5.6], p: [0, 9.92, -11.2], c: C.mouth });
  H.box({ name: 'Throat', s: [1.5, 1.0, 0.6], p: [0, 10.1, -8.2], c: C.mouth });
  // jagged crest of small wedges down the skull
  for (let i = 0; i < 7; i++) H.wedgeF({ name: 'CrestSpike', s: [0.3, 0.35 + (i % 2) * 0.15, 0.45], p: [0, 11.95 + (i < 2 ? 0.25 : 0), -7.6 - i * 0.85], face: 'back', c: C.crimsonLo });
  H.sym((s, side, n) => {
    s.box({ name: 'BrowRidge', s: [0.5, 0.45, 1.3], p: [0.95, 12.0, -8.4], r: [0, -8, -14], c: C.purple });
    eye(s, [1.17, 11.4, -8.5], { h: 0.32, d: 0.5, c: C.eye, neon: true, lid: C.body });
    for (let i = 0; i < 3; i++) s.box({ name: 'FacialRidge', s: [0.1, 0.18, 1.1], p: [0.92, 11.2 - i * 0.32, -10.0 - i * 0.6], r: [-6, 0, 0], c: C.crimson });
    s.box({ name: 'JawMuscle', s: [0.35, 1.4, 1.5], p: [1.05, 10.6, -7.9], c: C.bodyLo });
    s.box({ name: 'UpperLip', s: [0.1, 0.25, 6.0], p: [0.92, 10.05, -11.2], c: C.purpleLo });
    s.box({ name: 'Nostril', s: [0.2, 0.18, 0.4], p: [0.5, 11.35, -13.6], c: '#0a0a0a' });
    teeth(s, { n: 12, x: 0.78, y: 9.97, z0: -8.6, z1: -14.0, h: 0.42, d: 0.26, w: 0.14, dir: 'down', sizes: [0.8, 1.1, 1, 1.3, 0.9, 1.2, 1, 1.3, 0.9, 1.1, 1, 0.8], c: C.tooth });
    s.attach(`VFX_${n}Eye`, [1.22, 11.4, -8.5]);
  });
  H.attach('VFX_Mouth', [0, 10.0, -14.4]);
  H.attach('VFX_Head', [0, 11.2, -9.2]);
  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 9.95, -8.0], S);
  J.box({ name: 'LowerJaw', s: [1.6, 0.7, 6.2], p: [0, 9.55, -11.1] });
  J.box({ name: 'JawUnderside', s: [1.3, 0.18, 6.0], p: [0, 9.15, -11.1], c: C.belly });
  J.box({ name: 'Tongue', s: [0.9, 0.15, 3.6], p: [0, 9.92, -10.4], c: C.tongue });
  J.sym((s) => teeth(s, { n: 11, x: 0.7, y: 9.88, z0: -8.8, z1: -14.0, h: 0.36, d: 0.24, w: 0.13, dir: 'up', sizes: [0.9, 1.2, 1, 1.1, 0.9, 1.25, 1, 1.1, 0.9, 1.15, 0.8], c: C.tooth }));

  // Bigger arms than the T. rex, three claws
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [1.75, 7.8, -4.3], S);
    segBox(A, [1.75, 7.8, -4.3], [1.95, 6.6, -4.9], 0.75, 0.8, { name: 'UpperArm', c: C.bodyLo });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [1.95, 6.6, -4.9], S);
    segBox(F, [1.95, 6.6, -4.9], [1.95, 6.0, -5.9], 0.6, 0.65, { name: 'Forearm', c: C.bodyLo });
    F.box({ name: 'Hand', s: [0.6, 0.45, 0.5], p: [1.95, 5.85, -6.1], c: C.bodyLo });
    for (const dx of [-0.18, 0, 0.18]) claw(F, [1.95 + dx, 5.7, -6.35], { s: 0.34, c: C.claw });
  });
  P.sym((s, side, n) => bipedLeg(rig, s, pelvis, n, { hip: [2.25, 7.9, 1.6], knee: [2.6, 4.8, 0.3], ankle: [2.6, 1.95, 1.7], ball: [2.6, 0.45, 0.6] }, {
    thigh: [1.6, 2.4], shin: [1.15, 1.3], meta: [0.95, 0.95], toeLen: 1.35, toeW: 0.45, toeH: 0.45, muscle: { s: [1.5, 3.0, 2.6], p: [2.65, 6.6, 1.2] }, c: C.body, cLo: C.bodyLo, claw: C.claw,
  }));

  tailChain(rig, P, pelvis, [
    { p: [0, 8.5, 3.4], s: [3.0, 2.8, 2.4], c: [0, 8.5, 4.3] },
    { p: [0, 8.4, 5.5], s: [2.4, 2.3, 2.3], c: [0, 8.35, 6.4] },
    { p: [0, 8.2, 7.6], s: [1.8, 1.8, 2.2], c: [0, 8.15, 8.5] },
    { p: [0, 7.9, 9.6], s: [1.3, 1.3, 2.1], c: [0, 7.85, 10.5] },
    { p: [0, 7.6, 11.6], s: [0.9, 0.9, 1.9], c: [0, 7.55, 12.45] },
    { p: [0, 7.3, 13.4], s: [0.55, 0.55, 1.6], c: [0, 7.25, 14.1] },
  ], { c: C.body, under: C.belly, band: C.crimson, each: (Tc, d, i) => { if (i < 5) saw(Tc, [[d.c[1] + d.s[1] / 2, d.c[2], 0.95 - i * 0.14]]); } });

  highlight(model);
  return model;
}

module.exports = { build };
