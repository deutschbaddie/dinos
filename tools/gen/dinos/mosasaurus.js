// DINOSAUR 11 — MOSASAURUS (Mythic). Enormous, mysterious, dangerous. ~33 studs long, ~9 tall. Swimmer.
const { makeDino, seg, boneAt, teeth, eye, band, dorsal, highlight, segBox, tailChain } = require('./common.js');

const C = {
  body: '#2a5aa8', bodyHi: '#3a6fc0', bodyLo: '#214a8c', navy: '#18284f', navyLo: '#111d3a', belly: '#a8c8e8', bellyLo: '#8fb3d8',
  cyan: '#3fe0ff', tooth: '#f2f4f6', eye: '#c8f4ff', mouth: '#3a0c18', tongue: '#9a3a5a', flipper: '#1f4486',
};

function flipper(rig, s, parentBone, name, p, len, wid, sweep) {
  const [fb, F] = boneAt(rig, s, name, parentBone, p, { c: C.flipper });
  const f = F.at(p, [0, sweep, -12]);
  f.box({ name: 'FlipperBase', s: [len * 0.5, 0.4, wid], p: [len * 0.25, 0, 0], c: C.bodyLo });
  f.box({ name: 'Flipper', s: [len * 0.55, 0.28, wid * 0.85], p: [len * 0.7, -0.02, wid * 0.15], c: C.flipper });
  f.wedgeF({ name: 'FlipperTip', s: [len * 0.3, 0.26, wid * 0.7], p: [len * 1.08, -0.02, wid * 0.25], face: 'left', r: [0, 0, 90], c: C.flipper });
  f.box({ name: 'FlipperEdge', s: [len * 0.9, 0.3, 0.12], p: [len * 0.55, -0.02, -wid * 0.45], c: C.cyan, shadow: false });
  return fb;
}

function build() {
  const { model, rig } = makeDino('Mosasaurus', {
    DisplayName: 'Mosasaurus', Rarity: 'Mythic', Classification: 'Aquatic Reptile', Personality: 'Enormous, mysterious, dangerous',
    Locomotion: 'Swim', SignatureMove: 'Ocean Breach',
  }, [5, 4.5, 14], [0, 4.6, -1]);
  const S = { c: C.body };
  const back = (ctx, y, z, w, l) => {
    ctx.box({ name: 'Back', s: [w * 0.7, 0.4, l], p: [0, y, z], c: C.navy, studs: 'top' });
    ctx.sym((s) => s.box({ name: 'LateralLine', s: [0.08, 0.14, l], p: [w / 2 + 0.02, y - 1.0, z], c: C.cyan, shadow: false }));
  };

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 4.5, 2.0], S);
  P.box({ name: 'Hips', s: [4.2, 3.8, 4.4], p: [0, 4.5, 2.6], studs: 'top' });
  P.box({ name: 'HipBelly', s: [3.6, 0.4, 4.2], p: [0, 2.45, 2.6], c: C.belly });
  back(P, 6.55, 2.6, 4.2, 4.2);

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 4.6, 0.2], S);
  T.box({ name: 'Body', s: [5.0, 4.4, 7.4], p: [0, 4.6, -3.2], studs: 'top' });
  T.box({ name: 'Belly', s: [4.2, 0.45, 7.2], p: [0, 2.2, -3.2], c: C.belly });
  T.box({ name: 'Shoulders', s: [4.4, 3.6, 1.6], p: [0, 4.7, -7.4], c: C.bodyLo });
  back(T, 6.95, -3.2, 5.0, 7.0);
  for (const z of [-1.2, -3.4, -5.6]) band(T, [0, 6.0, z], [5.06, 1.4, 0.5], { c: C.navy });
  dorsal(T, [[7.15, -2.0, 1.2], [7.15, -4.2, 1.0]], { h: 0.6, d: 1.4, w: 0.25, c: C.navyLo });
  T.attach('VFX_Chest', [0, 3.0, -7.6]);

  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 4.8, -8.0], S);
  N.box({ name: 'Neck', s: [3.8, 3.2, 1.8], p: [0, 4.8, -8.7], c: C.bodyLo });
  N.box({ name: 'Throat', s: [3.0, 0.35, 1.6], p: [0, 3.1, -8.7], c: C.belly });

  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 5.0, -9.5], S);
  H.box({ name: 'Skull', s: [3.4, 2.0, 3.2], p: [0, 5.5, -11.0], studs: 'top' });
  H.box({ name: 'Snout', s: [2.6, 1.5, 3.4], p: [0, 5.25, -14.2] });
  H.wedgeF({ name: 'SnoutSlope', s: [2.6, 0.55, 1.4], p: [0, 6.27, -14.6], face: 'front', c: C.bodyHi });
  H.box({ name: 'NoseTip', s: [2.0, 1.2, 0.6], p: [0, 5.15, -16.2], c: C.bodyLo });
  H.box({ name: 'HeadTop', s: [2.4, 0.3, 3.0], p: [0, 6.62, -11.0], c: C.navy });
  H.box({ name: 'Palate', s: [2.4, 0.2, 6.0], p: [0, 4.38, -13.0], c: C.mouth });
  H.box({ name: 'Throat', s: [2.6, 1.2, 0.8], p: [0, 4.5, -10.0], c: C.mouth });
  // pterygoid teeth: an extra row on the palate
  for (const x of [-0.45, 0.45]) teeth(H, { n: 5, x, y: 4.3, z0: -11.0, z1: -13.0, h: 0.3, d: 0.2, w: 0.14, dir: 'down', c: C.tooth });
  H.sym((s, side, n) => {
    eye(s, [1.72, 5.9, -11.4], { h: 0.36, d: 0.55, c: C.eye, neon: true, lid: C.body });
    s.box({ name: 'Brow', s: [0.4, 0.35, 1.2], p: [1.55, 6.35, -11.4], r: [0, 0, -15], c: C.navy });
    s.box({ name: 'UpperLip', s: [0.12, 0.3, 6.4], p: [1.3, 4.5, -13.2], c: C.navyLo });
    s.box({ name: 'Nostril', s: [0.25, 0.15, 0.45], p: [0.6, 5.85, -15.6], c: '#0a1020' });
    teeth(s, { n: 11, x: 1.12, y: 4.42, z0: -10.6, z1: -16.2, h: 0.55, d: 0.28, w: 0.2, dir: 'down', sizes: [0.8, 1, 1.2, 1, 1.3, 1, 1.25, 1, 1.15, 0.9, 1.1], c: C.tooth });
    s.attach(`VFX_${n}Eye`, [1.78, 5.9, -11.4]);
  });
  H.attach('VFX_Mouth', [0, 4.4, -16.6]);
  H.attach('VFX_Head', [0, 5.6, -12.4]);
  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 4.35, -10.2], S);
  J.box({ name: 'LowerJaw', s: [2.4, 0.9, 6.4], p: [0, 3.9, -13.4] });
  J.box({ name: 'JawUnderside', s: [2.0, 0.2, 6.2], p: [0, 3.4, -13.4], c: C.belly });
  J.box({ name: 'Chin', s: [1.8, 0.85, 0.5], p: [0, 3.9, -16.6], c: C.bodyLo });
  J.box({ name: 'Tongue', s: [1.4, 0.15, 3.4], p: [0, 4.38, -12.6], c: C.tongue });
  J.sym((s) => teeth(s, { n: 10, x: 1.0, y: 4.33, z0: -10.9, z1: -16.4, h: 0.48, d: 0.26, w: 0.18, dir: 'up', sizes: [0.9, 1.2, 1, 1.3, 1, 1.2, 1.05, 1.25, 1, 1.1], c: C.tooth }));

  T.sym((s, side, n) => flipper(rig, s, torso, `${n}FrontFlipper`, [2.4, 3.4, -5.8], 4.6, 1.8, -25));
  P.sym((s, side, n) => flipper(rig, s, pelvis, `${n}HindFlipper`, [2.0, 3.4, 3.6], 3.4, 1.4, -35));

  const tail = tailChain(rig, P, pelvis, [
    { p: [0, 4.5, 4.8], s: [3.6, 3.4, 2.8], c: [0, 4.5, 6.0] },
    { p: [0, 4.4, 7.4], s: [2.8, 2.8, 2.7], c: [0, 4.4, 8.6] },
    { p: [0, 4.3, 9.9], s: [2.1, 2.2, 2.6], c: [0, 4.3, 11.1] },
    { p: [0, 4.2, 12.4], s: [1.5, 1.7, 2.5], c: [0, 4.2, 13.6] },
    { p: [0, 4.1, 14.8], s: [1.0, 1.3, 2.3], c: [0, 4.05, 15.9] },
  ], { c: C.body, under: C.belly, band: C.navy, each: (Tc, d) => Tc.box({ name: 'TailRidge', s: [0.2, 0.35, d.s[2] * 0.9], p: [0, d.c[1] + d.s[1] / 2 + 0.15, d.c[2]], c: C.navyLo }) });
  // downturned tail fluke (mosasaur hypocercal fin)
  const tf = tail.ctxs[4];
  tf.wedgeF({ name: 'FlukeLower', s: [0.3, 2.6, 2.4], p: [0, 2.9, 17.6], face: 'back', flip: true, c: C.flipper });
  tf.wedgeF({ name: 'FlukeUpper', s: [0.3, 1.2, 1.6], p: [0, 4.9, 17.3], face: 'back', c: C.flipper });
  tf.box({ name: 'FlukeEdge', s: [0.34, 0.14, 2.4], p: [0, 1.65, 17.6], c: C.cyan, shadow: false });

  highlight(model, '#0a1020', 0.5);
  return model;
}

module.exports = { build };
