// DAWN DESERT 01 — COELOPHYSIS (Common). One of the very first dinosaurs: a slim, quick, bird-like hunter
// that lives in packs at the oases. ~8 studs long, ~3 tall. Forward = -Z.
const { makeDino, seg, boneAt, teeth, claw, dorsal, eye, band, highlight, segBox, bipedLeg } = require('./common.js');

const C = {
  body: '#e8963c', bodyHi: '#f4ae58', bodyLo: '#c87a2e', stripe: '#5b3520', stripeLo: '#43271a',
  belly: '#f6e0b4', bellyLo: '#e2c48e', eye: '#ffd23a', claw: '#2a201a', mouth: '#7a2a2a', tongue: '#c45a5a', tooth: '#f6efd9',
};

function build() {
  const { model, rig } = makeDino('Coelophysis', {
    DisplayName: 'Coelophysis', Rarity: 'Common', Classification: 'Pack Hunter', Personality: 'Quick, twitchy, moves as one',
    Locomotion: 'Biped', SignatureMove: 'Oasis Strike',
  }, [0.9, 1.0, 2.2], [0, 1.9, 0.1]);
  const S = { c: C.body };

  // ---------------- Hips ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 2.0, 0.5], S);
  P.box({ name: 'Hip', s: [0.74, 0.72, 1.1], p: [0, 2.05, 0.5], studs: 'top' });
  P.box({ name: 'HipBelly', s: [0.58, 0.1, 0.92], p: [0, 1.65, 0.45], c: C.belly });
  P.box({ name: 'BackStripe', s: [0.34, 0.08, 1.1], p: [0, 2.45, 0.5], c: C.stripe });
  for (const z of [0.2, 0.78]) band(P, [0, 2.24, z], [0.78, 0.3, 0.16], { c: C.stripe });
  dorsal(P, [[2.49, 0.3, 0.9], [2.49, 0.75, 1]], { h: 0.12, d: 0.2, w: 0.1, c: C.stripeLo });

  // ---------------- Body ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 2.0, -0.05], S);
  T.box({ name: 'Chest', s: [0.78, 0.76, 1.3], p: [0, 1.98, -0.68], studs: 'top' });
  T.box({ name: 'ChestFront', s: [0.62, 0.6, 0.36], p: [0, 1.94, -1.48], c: C.bodyLo });
  T.box({ name: 'Belly', s: [0.6, 0.1, 1.24], p: [0, 1.57, -0.7], c: C.belly });
  T.box({ name: 'ChestPlate', s: [0.46, 0.4, 0.06], p: [0, 1.86, -1.69], c: C.belly });
  T.box({ name: 'BackStripe', s: [0.34, 0.08, 1.3], p: [0, 2.4, -0.68], c: C.stripe });
  for (const z of [-0.25, -0.72, -1.15]) band(T, [0, 2.2, z], [0.82, 0.34, 0.15], { c: C.stripe });
  dorsal(T, [[2.44, -0.3, 1], [2.44, -0.75, 1], [2.43, -1.18, 0.9]], { h: 0.12, d: 0.2, w: 0.1, c: C.stripeLo });
  T.attach('VFX_Chest', [0, 1.85, -1.65]);

  // ---------------- Long S-curved neck ----------------
  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 2.12, -1.45], S);
  segBox(N1, [0, 2.12, -1.45], [0, 2.7, -1.82], 0.42, 0.42, { name: 'NeckLower', extend: 0.2 });
  segBox(N1, [0, 1.98, -1.62], [0, 2.54, -1.98], 0.3, 0.08, { name: 'Throat', c: C.belly, extend: 0.05 });
  segBox(N1, [0, 2.33, -1.3], [0, 2.9, -1.66], 0.18, 0.12, { name: 'NeckStripe', c: C.stripe, extend: 0 });
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 2.7, -1.82], S);
  segBox(N2, [0, 2.7, -1.82], [0, 3.12, -2.12], 0.36, 0.36, { name: 'NeckUpper', extend: 0.18 });
  segBox(N2, [0, 2.57, -1.96], [0, 2.97, -2.26], 0.26, 0.07, { name: 'Throat', c: C.belly, extend: 0.04 });
  segBox(N2, [0, 2.88, -1.68], [0, 3.27, -1.96], 0.16, 0.1, { name: 'NeckStripe', c: C.stripe, extend: 0 });

  // ---------------- Narrow toothy head ----------------
  const HO = [0, 0.17, 0.04];
  const [head, H0] = boneAt(rig, N2, 'Head', neck2, [0, 3.12, -2.12], S);
  const H = H0.at(HO);
  H.box({ name: 'Cranium', s: [0.48, 0.44, 0.6], p: [0, 3.06, -2.4], studs: 'top' });
  H.box({ name: 'Snout', s: [0.32, 0.28, 0.98], p: [0, 2.97, -3.16] });
  H.wedgeF({ name: 'SnoutSlope', s: [0.32, 0.1, 0.42], p: [0, 3.16, -2.92], face: 'front', c: C.bodyHi });
  H.box({ name: 'NoseTip', s: [0.28, 0.24, 0.14], p: [0, 2.95, -3.71], c: C.bodyLo });
  H.box({ name: 'HeadStripe', s: [0.3, 0.06, 0.5], p: [0, 3.31, -2.36], c: C.stripe });
  H.box({ name: 'SnoutStripe', s: [0.2, 0.05, 0.6], p: [0, 3.135, -3.2], c: C.stripe });
  H.box({ name: 'MouthInterior', s: [0.24, 0.08, 0.95], p: [0, 2.86, -3.12], c: C.mouth });
  H.sym((s, side, n) => {
    eye(s, [0.25, 3.1, -2.44], { h: 0.18, d: 0.24, c: C.eye, lid: C.bodyLo });
    s.box({ name: 'BrowRidge', s: [0.1, 0.08, 0.32], p: [0.21, 3.27, -2.46], r: [0, 0, -18], c: C.stripeLo });
    s.box({ name: 'EyeStripe', s: [0.05, 0.08, 0.36], p: [0.24, 3.09, -2.18], c: C.stripe });
    s.box({ name: 'Cheek', s: [0.06, 0.16, 0.3], p: [0.23, 2.92, -2.62], c: C.bodyLo });
    s.box({ name: 'Nostril', s: [0.05, 0.05, 0.08], p: [0.1, 3.07, -3.68], c: '#1e1410' });
    s.box({ name: 'UpperLip', s: [0.04, 0.06, 0.95], p: [0.16, 2.85, -3.15], c: C.bodyLo });
    teeth(s, { n: 7, x: 0.13, y: 2.82, z0: -2.72, z1: -3.66, h: 0.09, d: 0.07, w: 0.05, dir: 'down', sizes: [0.8, 1, 1.15, 0.9, 1.1, 0.95, 0.8], c: C.tooth });
    s.attach(`VFX_${n}Eye`, [0.28, 3.1, -2.44]);
  });
  H.attach('VFX_Mouth', [0, 2.84, -3.8]);
  H.attach('VFX_Head', [0, 3.05, -2.6]);
  const [jaw, J0] = boneAt(rig, H, 'Jaw', head, [0, 2.83, -2.5], S);
  const J = J0.at(HO);
  J.box({ name: 'LowerJaw', s: [0.28, 0.12, 1.2], p: [0, 2.77, -3.12] });
  J.box({ name: 'JawUnderside', s: [0.24, 0.04, 1.12], p: [0, 2.69, -3.1], c: C.belly });
  J.box({ name: 'Tongue', s: [0.14, 0.04, 0.7], p: [0, 2.835, -3.0], c: C.tongue });
  J.sym((s) => teeth(s, { n: 6, x: 0.1, y: 2.83, z0: -2.78, z1: -3.62, h: 0.08, d: 0.06, w: 0.045, dir: 'up', sizes: [0.8, 1.05, 0.95, 1.1, 0.9, 0.8], c: C.tooth }));

  // ---------------- Grasping arms ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [0.32, 1.78, -1.3], S);
    segBox(A, [0.36, 1.78, -1.3], [0.4, 1.46, -1.38], 0.13, 0.15, { name: 'UpperArm', extend: 0.1 });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [0.4, 1.46, -1.38], S);
    segBox(F, [0.4, 1.46, -1.38], [0.4, 1.34, -1.66], 0.11, 0.11, { name: 'Forearm', extend: 0.08 });
    F.box({ name: 'Hand', s: [0.1, 0.1, 0.12], p: [0.4, 1.33, -1.72], c: C.bodyLo });
    for (const dx of [-0.035, 0.035]) claw(F, [0.4 + dx, 1.3, -1.79], { s: 0.09, c: C.claw });
  });

  // ---------------- Long bird-like legs ----------------
  P.sym((s, side, n) => {
    const L = bipedLeg(rig, s, pelvis, n, { hip: [0.36, 1.95, 0.5], knee: [0.43, 1.25, 0.06], ankle: [0.43, 0.56, 0.55], ball: [0.43, 0.15, 0.14] }, {
      thigh: [0.36, 0.5], shin: [0.22, 0.24], meta: [0.15, 0.17], toeLen: 0.42, toeW: 0.12, toeH: 0.14, c: C.body, cLo: C.bodyLo, claw: C.claw,
    });
    band(L.ctx[0], [0.4, 1.66, 0.33], [0.4, 0.13, 0.48], { c: C.stripe, r: [32, 0, 0] });
  });

  // ---------------- Long whip tail with stripe rings ----------------
  const tailDefs = [
    { p: [0, 2.08, 1.05], s: [0.6, 0.54, 0.8], c: [0, 2.08, 1.42] },
    { p: [0, 2.12, 1.8], s: [0.46, 0.42, 0.8], c: [0, 2.12, 2.17] },
    { p: [0, 2.15, 2.55], s: [0.34, 0.32, 0.8], c: [0, 2.15, 2.92] },
    { p: [0, 2.16, 3.3], s: [0.25, 0.24, 0.78], c: [0, 2.16, 3.66] },
    { p: [0, 2.16, 4.03], s: [0.17, 0.17, 0.66], c: [0, 2.16, 4.33] },
  ];
  let parent = pelvis, pc = P;
  tailDefs.forEach((d, i) => {
    const [tb, Tc] = boneAt(rig, pc, `Tail${i + 1}`, parent, d.p, S);
    Tc.box({ name: 'TailSegment', s: d.s, p: d.c, studs: i < 3 ? 'top' : undefined });
    band(Tc, [0, d.c[1] + d.s[1] * 0.12, d.c[2] + d.s[2] * 0.2], [d.s[0] + 0.04, d.s[1] * 0.8, d.s[2] * 0.26], { c: C.stripe });
    if (i < 3) Tc.box({ name: 'TailUnderside', s: [d.s[0] * 0.75, 0.05, d.s[2] * 0.9], p: [0, d.c[1] - d.s[1] / 2 - 0.02, d.c[2]], c: C.belly });
    if (i === 4) {
      Tc.wedgeF({ name: 'TailTip', s: [0.12, 0.12, 0.3], p: [0, 2.16, 4.8], face: 'back', c: C.stripe });
      Tc.attach('VFX_TailTip', [0, 2.16, 4.95]);
    }
    parent = tb; pc = Tc;
  });

  highlight(model);
  return model;
}

module.exports = { build };
