// DINOSAUR 06 — CARNOTAURUS (Rare). Aggressive, unpredictable. ~15 studs long, ~9 tall.
const { makeDino, seg, boneAt, teeth, claw, dorsal, eye, band, highlight, segBox, bipedLeg, tailChain } = require('./common.js');

const C = {
  body: '#a8242a', bodyHi: '#c43a3a', bodyLo: '#7e1a1f', dark: '#6e161a', black: '#1e1414',
  horn: '#efe2c4', hornLo: '#cdbb92', belly: '#d7b08c', eye: '#ffe43a', mouth: '#4a0d10', tongue: '#b84050', tooth: '#f4ecd6',
};

function build() {
  const { model, rig } = makeDino('Carnotaurus', {
    DisplayName: 'Carnotaurus', Rarity: 'Rare', Classification: 'Large Predator', Personality: 'Aggressive, unpredictable',
    Locomotion: 'Biped', SignatureMove: 'Ambush Attack',
  }, [2.6, 2.8, 6], [0, 5.4, 0.2]);
  const S = { c: C.body };

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 5.5, 1.0], S);
  P.box({ name: 'Hip', s: [2.4, 2.4, 2.3], p: [0, 5.55, 1.1], studs: 'top' });
  P.box({ name: 'HipBelly', s: [1.9, 0.25, 2.1], p: [0, 4.25, 1.0], c: C.belly });
  for (const z of [0.5, 1.6]) band(P, [0, 6.2, z], [2.46, 1.0, 0.35], { c: C.black });
  dorsal(P, [[6.75, 0.4, 1], [6.75, 1.4, 1]], { h: 0.32, d: 0.5, w: 0.3, c: C.dark });

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 5.5, -0.5], S);
  T.box({ name: 'Ribcage', s: [2.4, 2.5, 2.8], p: [0, 5.55, -1.4], studs: 'top' });
  T.box({ name: 'Chest', s: [2.0, 2.2, 0.8], p: [0, 5.5, -3.0], c: C.bodyLo });
  T.box({ name: 'Belly', s: [1.9, 0.25, 3.2], p: [0, 4.2, -1.5], c: C.belly });
  for (const z of [-0.6, -1.7, -2.7]) band(T, [0, 6.2, z], [2.46, 1.0, 0.35], { c: C.black });
  // rows of bumpy osteoderms along the flanks (signature Carnotaurus texture)
  T.sym((s) => { for (let i = 0; i < 4; i++) s.box({ name: 'Osteoderm', s: [0.25, 0.35, 0.35], p: [1.23, 6.0, 0.2 - i * 0.85], c: C.dark }); });
  P.sym((s) => { for (let i = 0; i < 2; i++) s.box({ name: 'Osteoderm', s: [0.25, 0.35, 0.35], p: [1.23, 6.0, 0.7 + i * 0.85], c: C.dark }); });
  dorsal(T, [[6.82, -0.6, 1], [6.82, -1.5, 1.05], [6.82, -2.4, 0.95]], { h: 0.32, d: 0.5, w: 0.3, c: C.dark });
  T.attach('VFX_Chest', [0, 5.2, -3.4]);

  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 5.9, -3.0], S);
  segBox(N, [0, 5.9, -3.0], [0, 6.9, -3.7], 1.7, 1.8, { name: 'Neck', studs: 'top' });
  N.box({ name: 'Throat', s: [1.3, 1.3, 0.2], p: [0, 5.95, -3.75], r: [-35, 0, 0], c: C.belly });

  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 6.95, -3.75], S);
  H.box({ name: 'Skull', s: [1.8, 1.9, 2.0], p: [0, 7.35, -4.4], studs: 'top' });
  H.box({ name: 'Snout', s: [1.5, 1.3, 1.3], p: [0, 7.15, -5.95] });
  H.wedgeF({ name: 'SnoutSlope', s: [1.5, 0.45, 0.9], p: [0, 8.02, -5.7], face: 'front', c: C.bodyHi });
  H.box({ name: 'SkullCap', s: [1.6, 0.25, 1.6], p: [0, 8.42, -4.3], c: C.bodyLo });
  H.box({ name: 'Palate', s: [1.2, 0.2, 2.0], p: [0, 6.45, -5.4], c: C.mouth });
  H.box({ name: 'Throat', s: [1.1, 0.8, 0.5], p: [0, 6.6, -4.0], c: C.mouth });
  H.sym((s, side, n) => {
    // thick bull horns over the eyes, sweeping out and up
    segBox(s, [0.7, 8.25, -3.9], [1.2, 8.75, -3.75], 0.6, 0.6, { name: 'HornBase', c: C.hornLo });
    segBox(s, [1.2, 8.75, -3.75], [1.55, 9.3, -3.6], 0.42, 0.42, { name: 'Horn', c: C.horn, extend: 0.1 });
    s.box({ name: 'BrowRidge', s: [0.35, 0.45, 1.0], p: [0.8, 7.95, -4.6], r: [0, 0, -12], c: C.dark });
    eye(s, [0.92, 7.6, -4.6], { h: 0.24, d: 0.36, c: C.eye, neon: true, lid: C.body });
    s.box({ name: 'FaceBump', s: [0.15, 0.3, 0.3], p: [0.78, 7.15, -5.4], c: C.dark });
    s.box({ name: 'FaceBump', s: [0.15, 0.25, 0.25], p: [0.78, 7.45, -5.9], c: C.dark });
    s.box({ name: 'UpperLip', s: [0.12, 0.25, 2.4], p: [0.74, 6.6, -5.4], c: C.dark });
    s.box({ name: 'Nostril', s: [0.15, 0.15, 0.2], p: [0.45, 7.55, -6.55], c: '#1a0a0a' });
    teeth(s, { n: 7, x: 0.58, y: 6.5, z0: -4.4, z1: -6.4, h: 0.32, d: 0.24, w: 0.16, dir: 'down', sizes: [0.8, 1.1, 1, 1.25, 0.95, 1.1, 0.85], c: C.tooth });
    s.attach(`VFX_${n}Eye`, [0.98, 7.6, -4.6]);
  });
  H.box({ name: 'BlackMask', s: [1.84, 0.4, 0.5], p: [0, 7.8, -5.0], c: C.black });
  H.attach('VFX_Mouth', [0, 6.6, -6.7]);
  H.attach('VFX_Head', [0, 7.5, -4.8]);
  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 6.5, -4.0], S);
  J.box({ name: 'LowerJaw', s: [1.35, 0.55, 2.6], p: [0, 6.15, -5.3] });
  J.box({ name: 'JawUnderside', s: [1.1, 0.15, 2.4], p: [0, 5.83, -5.3], c: C.belly });
  J.box({ name: 'Tongue', s: [0.7, 0.12, 1.6], p: [0, 6.45, -5.0], c: C.tongue });
  J.sym((s) => teeth(s, { n: 6, x: 0.52, y: 6.42, z0: -4.6, z1: -6.4, h: 0.28, d: 0.22, w: 0.14, dir: 'up', sizes: [0.9, 1.2, 1, 1.1, 0.9, 1], c: C.tooth }));

  // comically tiny arms
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [1.05, 5.0, -2.7], S);
    A.box({ name: 'Stub', s: [0.3, 0.4, 0.3], p: [1.15, 4.8, -2.8], c: C.bodyLo });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [1.15, 4.6, -2.85], S);
    F.box({ name: 'TinyHand', s: [0.25, 0.25, 0.25], p: [1.15, 4.48, -2.95], c: C.bodyLo });
    claw(F, [1.15, 4.4, -3.1], { s: 0.13, c: C.black });
  });
  P.sym((s, side, n) => bipedLeg(rig, s, pelvis, n, { hip: [1.3, 5.3, 1.0], knee: [1.5, 3.3, 0.0], ankle: [1.5, 1.45, 1.2], ball: [1.5, 0.3, 0.45] }, {
    thigh: [1.1, 1.5], shin: [0.75, 0.8], meta: [0.55, 0.55], toeLen: 0.95, toeW: 0.32, toeH: 0.32, muscle: { s: [0.95, 2.0, 1.6], p: [1.55, 4.5, 0.6] }, c: C.body, cLo: C.bodyLo, claw: C.black,
  }));

  tailChain(rig, P, pelvis, [
    { p: [0, 5.8, 2.2], s: [2.0, 2.0, 1.7], c: [0, 5.8, 2.95] },
    { p: [0, 5.75, 3.7], s: [1.5, 1.55, 1.6], c: [0, 5.75, 4.45] },
    { p: [0, 5.65, 5.2], s: [1.1, 1.15, 1.6], c: [0, 5.65, 5.95] },
    { p: [0, 5.5, 6.7], s: [0.75, 0.8, 1.5], c: [0, 5.5, 7.4] },
    { p: [0, 5.35, 8.1], s: [0.45, 0.5, 1.3], c: [0, 5.35, 8.7] },
  ], { c: C.body, under: C.belly, band: C.black });

  highlight(model);
  return model;
}

module.exports = { build };
