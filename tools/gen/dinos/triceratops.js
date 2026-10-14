// DINOSAUR 02 — TRICERATOPS (Common). Stubborn, territorial, powerful. ~13 studs long, ~6.5 tall.
const { makeDino, seg, boneAt, eye, band, highlight, segBox, quadLeg, tailChain } = require('./common.js');

const C = {
  body: '#c0763a', bodyHi: '#d68a4a', bodyLo: '#9c5c2c', armor: '#6b3f22', armorLo: '#54301a',
  horn: '#f1e3c2', hornLo: '#d9c7a0', belly: '#d9b98a', beak: '#3a2a20', eye: '#ffb21a',
  frill: '#e0955a', frillMark: '#7a3f1e', mouth: '#6e1a22',
};

function build() {
  const { model, rig } = makeDino('Triceratops', {
    DisplayName: 'Triceratops', Rarity: 'Common', Classification: 'Armored Herbivore', Personality: 'Stubborn, territorial, powerful',
    Locomotion: 'Quadruped', SignatureMove: 'The Charge',
  }, [3.6, 3.0, 7], [0, 3.4, 0.4]);
  const S = { c: C.body };

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 3.7, 2.2], S);
  P.box({ name: 'Hip', s: [3.6, 2.7, 2.6], p: [0, 3.6, 2.4], studs: 'top' });
  P.box({ name: 'RumpArmor', s: [3.0, 0.4, 2.2], p: [0, 5.12, 2.4], c: C.armor, studs: 'top' });
  P.box({ name: 'HipBelly', s: [3.0, 0.3, 2.2], p: [0, 2.15, 2.3], c: C.belly });
  for (const z of [1.6, 3.2]) band(P, [0, 4.55, z], [3.66, 0.9, 0.5], { c: C.armor });

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 3.6, 0.6], S);
  T.box({ name: 'Barrel', s: [4.0, 3.0, 3.4], p: [0, 3.5, -0.9], studs: 'top' });
  T.box({ name: 'BackArmor', s: [3.4, 0.4, 3.2], p: [0, 5.15, -0.9], c: C.armor, studs: 'top' });
  T.box({ name: 'Belly', s: [3.3, 0.3, 3.2], p: [0, 1.9, -0.9], c: C.belly });
  T.box({ name: 'ShoulderHump', s: [3.6, 2.1, 1.0], p: [0, 3.45, -2.6], c: C.bodyLo });
  for (const z of [0.3, -0.9, -2.1]) band(T, [0, 4.5, z], [4.06, 1.0, 0.5], { c: C.armor });
  T.sym((s) => { for (let i = 0; i < 4; i++) s.box({ name: 'SkinFold', s: [0.12, 1.1, 0.28], p: [2.02, 2.9, -2.0 + i * 0.75], c: C.bodyLo }); });
  T.attach('VFX_Chest', [0, 2.8, -3.2]);

  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 3.6, -3.0], S);
  N.box({ name: 'Neck', s: [2.6, 2.2, 1.4], p: [0, 3.4, -3.4], c: C.bodyLo });
  N.box({ name: 'ThroatFold', s: [2.0, 0.3, 1.2], p: [0, 2.35, -3.4], c: C.belly });

  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 3.4, -3.8], S);
  H.box({ name: 'Skull', s: [2.1, 1.7, 2.0], p: [0, 3.3, -4.6], studs: 'top' });
  H.box({ name: 'Snout', s: [1.5, 1.2, 1.3], p: [0, 3.0, -6.1] });
  H.box({ name: 'SnoutRidge', s: [0.9, 0.2, 1.3], p: [0, 3.68, -6.0], c: C.bodyHi });
  H.box({ name: 'UpperBeak', s: [1.2, 0.9, 0.6], p: [0, 2.9, -6.95], c: C.beak });
  H.wedgeF({ name: 'BeakHook', s: [1.1, 0.55, 0.5], p: [0, 2.17, -6.98], face: 'back', flip: true, c: C.beak });
  H.box({ name: 'MouthInterior', s: [1.0, 0.3, 1.6], p: [0, 2.55, -5.8], c: C.mouth });
  H.box({ name: 'NoseHornBase', s: [0.5, 0.5, 0.6], p: [0, 3.85, -6.2], c: C.hornLo });
  H.wedgeF({ name: 'NoseHorn', s: [0.36, 0.75, 0.5], p: [0, 4.47, -6.2], face: 'front', c: C.horn });
  H.sym((s, side, n) => {
    // long brow horns built from tapering segments
    const B = [0.62, 4.05, -4.9], Tp = [0.85, 5.05, -7.05];
    const L = (k) => B.map((v, i) => v + (Tp[i] - v) * k);
    s.box({ name: 'HornRing', s: [0.7, 0.3, 0.7], p: [0.62, 4.0, -4.85], c: C.armor });
    segBox(s, B, L(0.38), 0.56, 0.56, { name: 'BrowHorn', c: C.hornLo });
    segBox(s, L(0.38), L(0.72), 0.42, 0.42, { name: 'BrowHorn', c: C.horn });
    segBox(s, L(0.72), Tp, 0.28, 0.28, { name: 'BrowHornTip', c: C.horn, extend: 0.05 });
    eye(s, [1.06, 3.55, -4.85], { h: 0.3, d: 0.42, r: [0, -6, 0], c: C.eye, lid: C.body });
    s.box({ name: 'BrowRidge', s: [0.35, 0.3, 0.75], p: [0.98, 3.85, -4.85], c: C.armor });
    s.wedgeF({ name: 'CheekHorn', s: [0.5, 0.6, 0.55], p: [1.28, 2.75, -4.3], face: 'right', c: C.horn });
    s.box({ name: 'CheekPlate', s: [0.2, 0.9, 1.2], p: [1.1, 2.95, -4.5], c: C.bodyLo });
    s.attach(`VFX_${n}Eye`, [1.1, 3.55, -4.85]);
  });
  // The frill: tilted shield with an inner pattern and bony edge studs
  const F = H.at([0, 4.4, -3.95], [18, 0, 0]);
  F.box({ name: 'Frill', s: [4.8, 3.6, 0.35], p: [0, 1.0, 0], c: C.body });
  F.box({ name: 'FrillBack', s: [4.6, 3.4, 0.12], p: [0, 1.0, 0.23], c: C.armor });
  F.box({ name: 'FrillInner', s: [4.0, 2.8, 0.06], p: [0, 1.05, -0.2], c: C.frill });
  for (const x of [-1.25, 0, 1.25]) F.box({ name: 'FrillMark', s: [0.45, 1.9, 0.04], p: [x, 1.3, -0.24], r: [0, 0, x * 8], c: C.frillMark, shadow: false });
  F.cyl({ name: 'FrillEye', axis: 'z', len: 0.05, d: 0.7, p: [-1.6, 1.9, -0.25], c: C.frillMark, shadow: false });
  F.cyl({ name: 'FrillEye', axis: 'z', len: 0.05, d: 0.7, p: [1.6, 1.9, -0.25], c: C.frillMark, shadow: false });
  for (let i = 0; i < 7; i++) F.box({ name: 'Epoccipital', s: [0.42, 0.42, 0.3], p: [-2.1 + i * 0.7, 2.85, 0], r: [0, 0, 45], c: C.horn });
  F.sym((s) => { for (let i = 0; i < 4; i++) s.box({ name: 'Epoccipital', s: [0.4, 0.4, 0.3], p: [2.45, -0.35 + i * 0.8, 0], r: [0, 0, 45], c: C.horn }); });
  H.attach('VFX_Mouth', [0, 2.6, -7.25]);
  H.attach('VFX_Head', [0, 3.6, -5.2]);
  H.attach('VFX_Horn', [0.85, 5.05, -7.05]);

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 2.55, -4.9], S);
  J.box({ name: 'LowerJaw', s: [1.4, 0.5, 1.8], p: [0, 2.28, -5.9] });
  J.box({ name: 'LowerBeak', s: [1.0, 0.45, 0.5], p: [0, 2.26, -7.0], c: C.beak });
  J.box({ name: 'JawUnderside', s: [1.2, 0.12, 1.6], p: [0, 2.0, -5.9], c: C.belly });

  // Legs: thick pillars, outside the barrel so strides don't sink into the body
  P.sym((s, side, n) => quadLeg(rig, s, pelvis, n, 'Hind', { hip: [1.6, 3.4, 2.4], knee: [1.8, 1.95, 1.85], ankle: [1.8, 0.75, 2.45] }, {
    upper: [1.15, 1.25], lower: [0.9, 0.9], foot: [1.25, 0.45, 1.35], muscle: { s: [1.05, 1.7, 1.9], p: [1.85, 3.0, 2.4] }, toes: 3, c: C.body, cLo: C.bodyLo, claw: C.horn,
  }));
  T.sym((s, side, n) => quadLeg(rig, s, torso, n, 'Front', { hip: [1.65, 3.0, -2.2], knee: [2.0, 1.9, -2.0], ankle: [2.0, 0.7, -2.35] }, {
    upper: [0.95, 1.0], lower: [0.8, 0.8], foot: [1.05, 0.4, 1.1], muscle: { s: [0.95, 1.3, 1.3], p: [1.85, 2.6, -2.2] }, toes: 3, c: C.body, cLo: C.bodyLo, claw: C.horn,
  }));

  tailChain(rig, P, pelvis, [
    { p: [0, 3.9, 3.6], s: [2.4, 2.0, 1.7], c: [0, 3.9, 4.3] },
    { p: [0, 3.7, 5.0], s: [1.6, 1.4, 1.6], c: [0, 3.65, 5.7] },
    { p: [0, 3.4, 6.3], s: [0.9, 0.85, 1.5], c: [0, 3.35, 6.95] },
  ], { c: C.body, under: C.belly, band: C.armor });

  highlight(model);
  return model;
}

module.exports = { build };
