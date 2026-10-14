// DAWN DESERT 02 — PLATEOSAURUS (Uncommon). An early long-necked giant that walks on two legs and rears up
// to strip the tall cycads; big thumb claws. ~20 studs long, ~9 tall (14 reared). Forward = -Z.
const { makeDino, seg, boneAt, claw, dorsal, eye, band, highlight, segBox, bipedLeg, tailChain } = require('./common.js');

const C = {
  body: '#6f8a32', bodyHi: '#88a63f', bodyLo: '#566c26', band: '#4a5f1e', belly: '#f0d98a', bellyLo: '#dcc06c',
  thumb: '#f3e7c6', thumbLo: '#d8c79c', nail: '#3a3020', eye: '#ffb21a', mouth: '#7a3a2a', tooth: '#f4ecd6', cheek: '#c9a548',
};

function build() {
  const { model, rig } = makeDino('Plateosaurus', {
    DisplayName: 'Plateosaurus', Rarity: 'Uncommon', Classification: 'Tall Browser', Personality: 'Gentle giant, stubborn when cornered',
    Locomotion: 'Biped', SignatureMove: 'Tree Reach',
  }, [2.4, 2.6, 5], [0, 6.0, 0.6]);
  const S = { c: C.body };

  // ---------------- Hips ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 6.2, 1.8], S);
  P.box({ name: 'Hip', s: [2.4, 2.5, 2.6], p: [0, 6.3, 1.9], studs: 'top' });
  P.box({ name: 'HipRidge', s: [1.9, 0.35, 2.3], p: [0, 7.72, 1.9], c: C.bodyLo, studs: 'top' });
  P.box({ name: 'HipBelly', s: [1.9, 0.3, 2.2], p: [0, 4.98, 1.8], c: C.belly });
  for (const z of [1.1, 2.6]) band(P, [0, 7.05, z], [2.46, 1.0, 0.45], { c: C.band });

  // ---------------- Deep barrel body ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 6.2, 0.4], S);
  T.box({ name: 'Ribcage', s: [2.6, 2.9, 3.3], p: [0, 6.05, -1.35], studs: 'top' });
  T.box({ name: 'BackRidge', s: [2.2, 0.35, 3.4], p: [0, 7.67, -1.2], c: C.bodyLo, studs: 'top' });
  T.box({ name: 'Belly', s: [2.1, 0.35, 3.2], p: [0, 4.5, -1.3], c: C.belly });
  T.box({ name: 'ChestFront', s: [2.3, 2.3, 0.9], p: [0, 5.9, -3.4], c: C.bodyLo });
  T.box({ name: 'ChestPlate', s: [1.7, 1.6, 0.14], p: [0, 5.6, -3.9], c: C.belly });
  for (const z of [-0.2, -1.4, -2.6]) band(T, [0, 6.95, z], [2.66, 1.1, 0.42], { c: C.band });
  T.sym((s) => s.box({ name: 'Shoulder', s: [0.3, 1.3, 1.4], p: [1.25, 5.75, -3.0], c: C.bodyHi }));
  T.attach('VFX_Chest', [0, 5.4, -4.0]);

  // ---------------- Long neck (3 bones) ----------------
  const neckPts = [[0, 6.7, -3.4], [0, 7.45, -4.85], [0, 8.2, -6.25], [0, 8.8, -7.55]];
  const widths = [1.6, 1.3, 1.05];
  let nb = torso, nc = T;
  neckPts.slice(0, 3).forEach((p, i) => {
    const [b, Nc] = boneAt(rig, nc, `Neck${i + 1}`, nb, p, S);
    const q = neckPts[i + 1];
    segBox(Nc, p, q, widths[i], widths[i] * 1.05, { name: 'NeckSegment', studs: 'top', extend: widths[i] * 0.5 });
    segBox(Nc, [0, p[1] - widths[i] * 0.42, p[2] - widths[i] * 0.2], [0, q[1] - widths[i] * 0.42, q[2] - widths[i] * 0.2], widths[i] * 0.72, 0.12, { name: 'Throat', c: C.belly, extend: widths[i] * 0.3 });
    if (i < 2) Nc.box({ name: 'NeckBand', s: [widths[i] + 0.08, 0.4, widths[i] * 0.6], p: [0, (p[1] + q[1]) / 2 + widths[i] * 0.2, (p[2] + q[2]) / 2 + widths[i] * 0.2], r: [-38, 0, 0], c: C.band });
    nb = b; nc = Nc;
  });

  // ---------------- Small head ----------------
  const HO = [0, -0.2, -0.7];
  const [head, H0] = boneAt(rig, nc, 'Head', nb, [0, 8.8, -7.55], S);
  const H = H0.at(HO);
  H.box({ name: 'Cranium', s: [1.1, 1.0, 1.2], p: [0, 9.25, -7.25], studs: 'top' });
  H.box({ name: 'Snout', s: [0.86, 0.66, 1.0], p: [0, 9.05, -8.25] });
  H.wedgeF({ name: 'SnoutSlope', s: [0.86, 0.24, 0.62], p: [0, 9.5, -8.05], face: 'front', c: C.bodyHi });
  H.box({ name: 'Nose', s: [0.74, 0.54, 0.24], p: [0, 9.0, -8.86], c: C.bodyLo });
  H.box({ name: 'HeadBand', s: [1.14, 0.3, 0.3], p: [0, 9.6, -7.0], c: C.band });
  H.box({ name: 'MouthInterior', s: [0.66, 0.12, 1.2], p: [0, 8.72, -8.2], c: C.mouth });
  H.sym((s, side, n) => {
    eye(s, [0.57, 9.4, -7.3], { h: 0.26, d: 0.34, c: C.eye, lid: C.bodyLo });
    s.box({ name: 'BrowRidge', s: [0.16, 0.12, 0.5], p: [0.5, 9.66, -7.3], r: [0, 0, -16], c: C.band });
    s.box({ name: 'Cheek', s: [0.1, 0.38, 0.6], p: [0.56, 8.95, -7.75], c: C.cheek });
    s.box({ name: 'Nostril', s: [0.1, 0.1, 0.16], p: [0.24, 9.22, -8.85], c: '#2a2010' });
    // leaf-shaped plant-eating teeth
    for (let i = 0; i < 5; i++) s.wedgeF({ name: 'LeafTooth', s: [0.07, 0.13, 0.14], p: [0.36, 8.67, -7.85 - i * 0.22], face: 'front', flip: true, c: C.tooth, shadow: false });
    s.attach(`VFX_${n}Eye`, [0.6, 9.4, -7.3]);
  });
  H.attach('VFX_Mouth', [0, 8.75, -9.0]);
  H.attach('VFX_Head', [0, 9.25, -7.6]);
  const [jaw, J0] = boneAt(rig, H, 'Jaw', head, [0, 8.75, -7.35], S);
  const J = J0.at(HO);
  J.box({ name: 'LowerJaw', s: [0.76, 0.3, 1.5], p: [0, 8.58, -8.1] });
  J.box({ name: 'JawUnderside', s: [0.64, 0.08, 1.4], p: [0, 8.41, -8.1], c: C.belly });
  J.box({ name: 'Chin', s: [0.62, 0.24, 0.16], p: [0, 8.6, -8.9], c: C.bodyLo });

  // ---------------- Strong arms with big thumb claws ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [1.25, 5.5, -3.0], S);
    segBox(A, [1.32, 5.5, -3.0], [1.5, 4.2, -3.35], 0.6, 0.66, { name: 'UpperArm', studs: 'top', extend: 0.4 });
    A.box({ name: 'ArmBand', s: [0.66, 0.3, 0.72], p: [1.4, 5.05, -3.12], r: [-15, 0, 0], c: C.band });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [1.5, 4.2, -3.35], S);
    segBox(F, [1.5, 4.2, -3.35], [1.5, 3.1, -3.9], 0.48, 0.5, { name: 'Forearm', extend: 0.3 });
    const [hand, Hd] = boneAt(rig, F, `${n}Hand`, fore, [1.5, 3.1, -3.9], S);
    Hd.box({ name: 'Palm', s: [0.56, 0.36, 0.56], p: [1.52, 2.92, -4.02], c: C.bodyLo });
    for (const dx of [0.08, 0.24]) {
      Hd.box({ name: 'Finger', s: [0.13, 0.13, 0.32], p: [1.52 + dx, 2.86, -4.42] });
      claw(Hd, [1.52 + dx, 2.84, -4.62], { s: 0.16, c: C.nail });
    }
    // the great thumb claw: a cream hook curving forward and in
    segBox(Hd, [1.3, 2.98, -4.2], [1.18, 2.98, -4.72], 0.2, 0.24, { name: 'ThumbBase', c: C.thumbLo, extend: 0.1 });
    Hd.wedgeF({ name: 'ThumbClaw', s: [0.18, 0.32, 0.5], p: [1.16, 3.04, -4.98], face: 'front', r: [0, 12, 0], c: C.thumb });
    Hd.wedgeF({ name: 'ThumbClawTip', s: [0.14, 0.34, 0.24], p: [1.14, 2.73, -5.17], face: 'front', flip: true, r: [0, 12, 0], c: C.thumb });
    Hd.attach(`VFX_${n}Claw`, [1.14, 2.75, -5.2]);
  });

  // ---------------- Pillar legs ----------------
  P.sym((s, side, n) => {
    const L = bipedLeg(rig, s, pelvis, n, { hip: [1.25, 5.9, 1.9], knee: [1.48, 3.6, 0.95], ankle: [1.48, 1.4, 2.0], ball: [1.48, 0.42, 1.15] }, {
      thigh: [1.2, 1.6], shin: [0.86, 0.9], meta: [0.64, 0.7], toeLen: 0.9, toeW: 0.36, toeH: 0.42,
      muscle: { s: [1.0, 2.0, 1.7], p: [1.55, 5.0, 1.55], studs: 'top' }, c: C.body, cLo: C.bodyLo, claw: C.nail,
    });
    band(L.ctx[0], [1.57, 5.25, 1.6], [1.06, 0.5, 1.76], { c: C.band });
  });

  // ---------------- Heavy tail ----------------
  tailChain(rig, P, pelvis, [
    { p: [0, 6.6, 3.2], s: [2.0, 2.0, 2.0], c: [0, 6.55, 4.1] },
    { p: [0, 6.45, 5.0], s: [1.6, 1.6, 1.9], c: [0, 6.35, 5.85] },
    { p: [0, 6.2, 6.75], s: [1.22, 1.22, 1.85], c: [0, 6.05, 7.6] },
    { p: [0, 5.85, 8.45], s: [0.88, 0.88, 1.75], c: [0, 5.7, 9.25] },
    { p: [0, 5.5, 10.05], s: [0.56, 0.56, 1.5], c: [0, 5.35, 10.75] },
  ], { c: C.body, under: C.belly, band: C.band });

  dorsal(P, [[7.9, 1.3, 1], [7.9, 2.4, 1]], { h: 0.28, d: 0.5, w: 0.3, c: C.band });
  dorsal(T, [[7.85, -0.4, 1], [7.85, -1.4, 1], [7.85, -2.4, 0.9]], { h: 0.28, d: 0.5, w: 0.3, c: C.band });

  highlight(model);
  return model;
}

module.exports = { build };
