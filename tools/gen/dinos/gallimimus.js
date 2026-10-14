// RED CLIFFS 03 — GALLIMIMUS (Rare). The "chicken mimic": a jumpy, ostrich-fast flock runner.
// ~16 studs long, ~8.6 tall. Grey-blue with a white underside, rusty neck stripes, a small beaked head with a big
// eye, short feather fans on the arms and a feather crest down the back. Long, long legs. Forward = -Z.
const { makeDino, seg, boneAt, claw, eye, band, highlight, segBox, bipedLeg, tailChain } = require('./common.js');

const C = {
  blue: '#7092c4', blueHi: '#8eaedb', blueLo: '#5574a6', blueDk: '#3e5585', white: '#f4efe4', whiteLo: '#dcd6c8',
  rust: '#d2602a', rustLo: '#a8441c', beak: '#57536a', beakHi: '#77738a', eye: '#ffb21a', leg: '#5a6882', legLo: '#46536b',
  claw: '#22222a', mouth: '#6e2a34', feather: '#4c5d7a', featherTip: '#f4efe4',
};

function build() {
  const { model, rig } = makeDino('Gallimimus', {
    DisplayName: 'Gallimimus', Rarity: 'Rare', Classification: 'Fast Runner', Personality: 'Jumpy, flighty, fastest in the flock',
    Locomotion: 'Biped', SignatureMove: 'Flock Sprint',
  }, [2.0, 2.2, 4.0], [0, 5.3, -0.2]);
  const S = { c: C.blue };

  // ---------------- Pelvis ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 5.45, 0.8], S);
  P.box({ name: 'Hip', s: [1.7, 1.6, 1.9], p: [0, 5.5, 0.9], studs: 'top' });
  P.box({ name: 'HipTop', s: [1.3, 0.24, 1.7], p: [0, 6.42, 0.9], c: C.blueDk, studs: 'top' });
  P.box({ name: 'HipBelly', s: [1.3, 0.2, 1.6], p: [0, 4.62, 0.8], c: C.white });
  for (let i = 0; i < 3; i++) P.wedgeF({ name: 'BackFeather', s: [0.5, 0.3, 0.6], p: [0, 6.68 + i * 0.03, 0.4 + i * 0.55], face: 'back', c: i % 2 ? C.feather : C.blueDk });

  // ---------------- Torso: compact, deep-chested ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 5.5, -0.1], S);
  const Tt = T.at([0, 5.45, -1.2], [8, 0, 0]);
  Tt.box({ name: 'Body', s: [1.9, 1.8, 2.5], p: [0, 0, 0], studs: 'top' });
  Tt.box({ name: 'Belly', s: [1.5, 0.22, 2.3], p: [0, -0.98, 0], c: C.white });
  Tt.box({ name: 'BodyBand', s: [1.94, 0.5, 0.36], p: [0, 0.55, 0.3], c: C.blueLo });
  Tt.box({ name: 'BodyBand', s: [1.94, 0.5, 0.36], p: [0, 0.55, -0.6], c: C.blueLo });
  T.box({ name: 'Chest', s: [1.5, 1.5, 0.7], p: [0, 5.3, -2.6] });
  T.box({ name: 'ChestWhite', s: [1.2, 1.2, 0.1], p: [0, 5.1, -2.96], c: C.white });
  for (let i = 0; i < 3; i++) T.wedgeF({ name: 'BackFeather', s: [0.46, 0.28, 0.55], p: [0, 6.55 + i * 0.05, -0.4 - i * 0.6], face: 'back', c: i % 2 ? C.feather : C.blueDk });
  T.attach('VFX_Chest', [0, 5.0, -3.0]);

  // ---------------- Long S-neck with rusty stripes ----------------
  const neckSeg = (ctx, a, b, w, d, i) => {
    segBox(ctx, a, b, w, d, { name: 'Neck' });
    const m = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2];
    for (const k of [0.3, 0.72]) {
      const q = [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];
      segBox(ctx, [q[0], q[1] + 0.1, q[2] + 0.05], [q[0], q[1] - 0.1, q[2] - 0.05], w + 0.06, d + 0.06, { name: 'NeckStripe', c: k < 0.5 ? C.rust : C.rustLo, extend: 0 });
    }
    segBox(ctx, [a[0], a[1], a[2] - d * 0.42], [b[0], b[1], b[2] - d * 0.42], w * 0.7, 0.08, { name: 'Throat', c: C.white });
  };
  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 5.85, -2.6], S);
  neckSeg(N1, [0, 5.85, -2.6], [0, 6.75, -3.35], 0.85, 0.85, 0);
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 6.75, -3.35], S);
  neckSeg(N2, [0, 6.75, -3.35], [0, 7.55, -3.85], 0.72, 0.72, 1);
  const [neck3, N3] = boneAt(rig, N2, 'Neck3', neck2, [0, 7.55, -3.85], S);
  neckSeg(N3, [0, 7.55, -3.85], [0, 8.1, -4.15], 0.62, 0.62, 2);
  N3.wedgeF({ name: 'NapeFeather', s: [0.3, 0.28, 0.4], p: [0, 8.0, -3.8], face: 'back', c: C.rust });

  // ---------------- Head: small, flat beak, huge eye ----------------
  const [head, H] = boneAt(rig, N3, 'Head', neck3, [0, 8.1, -4.15], S);
  H.box({ name: 'Cranium', s: [0.82, 0.72, 0.8], p: [0, 8.25, -4.45], studs: 'top' });
  H.box({ name: 'Snout', s: [0.62, 0.48, 0.85], p: [0, 8.12, -5.25] });
  H.wedgeF({ name: 'SnoutSlope', s: [0.6, 0.2, 0.7], p: [0, 8.46, -5.2], face: 'front', c: C.blueHi });
  H.box({ name: 'Beak', s: [0.56, 0.24, 0.6], p: [0, 8.08, -5.95], c: C.beak });
  H.wedgeF({ name: 'BeakTip', s: [0.5, 0.16, 0.3], p: [0, 8.18, -6.38], face: 'front', c: C.beakHi });
  H.box({ name: 'HeadCap', s: [0.6, 0.12, 0.7], p: [0, 8.65, -4.45], c: C.blueDk });
  H.box({ name: 'MouthInterior', s: [0.4, 0.1, 0.9], p: [0, 7.97, -5.4], c: C.mouth });
  H.sym((s, side, n) => {
    eye(s, [0.42, 8.33, -4.62], { h: 0.3, d: 0.36, r: [0, -4, 0], c: C.eye, lid: C.blueLo });
    s.box({ name: 'EyeRing', s: [0.06, 0.44, 0.5], p: [0.4, 8.33, -4.62], c: C.white, shadow: false });
    s.box({ name: 'Nostril', s: [0.06, 0.06, 0.12], p: [0.22, 8.3, -5.75], c: '#1a1a22' });
    s.box({ name: 'Cheek', s: [0.08, 0.26, 0.4], p: [0.38, 8.0, -4.95], c: C.white });
    s.attach(`VFX_${n}Eye`, [0.46, 8.33, -4.62]);
  });
  H.attach('VFX_Mouth', [0, 7.95, -6.4]);
  H.attach('VFX_Head', [0, 8.3, -5.0]);
  H.attach('VFX_Crest', [0, 8.75, -4.4]);

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 7.95, -4.55], S);
  J.box({ name: 'LowerJaw', s: [0.5, 0.18, 1.0], p: [0, 7.86, -5.15] });
  J.box({ name: 'LowerBeak', s: [0.48, 0.16, 0.6], p: [0, 7.86, -5.92], c: C.beak });
  J.box({ name: 'JawUnderside', s: [0.42, 0.05, 1.4], p: [0, 7.745, -5.4], c: C.white });

  // ---------------- Slender arms with short feather fans ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [0.82, 5.15, -2.4], S);
    segBox(A, [0.82, 5.15, -2.4], [0.92, 4.25, -2.3], 0.3, 0.3, { name: 'UpperArm' });
    A.box({ name: 'ArmFeather', s: [0.08, 0.6, 0.3], p: [0.98, 4.7, -2.16], c: C.feather });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [0.92, 4.25, -2.3], S);
    segBox(F, [0.92, 4.25, -2.3], [0.92, 3.7, -2.95], 0.24, 0.24, { name: 'Forearm' });
    F.box({ name: 'Hand', s: [0.2, 0.18, 0.32], p: [0.92, 3.62, -3.1], c: C.blueLo });
    for (const dx of [-0.07, 0, 0.07]) claw(F, [0.92 + dx, 3.52, -3.28], { s: 0.16, c: C.claw });
    for (let i = 0; i < 3; i++) {
      const fz = -2.45 - i * 0.22;
      F.box({ name: 'FanFeather', s: [0.06, 0.5 - i * 0.04, 0.2], p: [0.98, 3.85 - i * 0.1, fz], r: [-25, 0, 0], c: C.feather });
      F.box({ name: 'FeatherTip', s: [0.07, 0.12, 0.2], p: [0.98, 3.58 - i * 0.1, fz + 0.12], r: [-25, 0, 0], c: C.featherTip, shadow: false });
    }
    F.attach(`VFX_${n}Claw`, [0.92, 3.45, -3.32]);
  });

  // ---------------- Very long legs ----------------
  P.sym((s, side, n) => {
    const L = bipedLeg(rig, s, pelvis, n, { hip: [0.95, 5.3, 0.9], knee: [1.12, 3.5, -0.25], ankle: [1.12, 1.75, 0.95], ball: [1.12, 0.32, -0.12] }, {
      thigh: [0.78, 1.0], shin: [0.42, 0.48], meta: [0.3, 0.32], toeLen: 0.85, toeW: 0.24, toeH: 0.24,
      muscle: { s: [0.72, 1.45, 1.3], p: [1.08, 4.95, 0.7] }, c: C.blue, cLo: C.leg, claw: C.claw,
    });
    band(L.ctx[0], [1.08, 5.25, 0.7], [0.78, 0.3, 1.34], { c: C.blueLo });
    L.ctx[1].box({ name: 'Ankle', s: [0.46, 0.36, 0.46], p: [1.12, 1.75, 0.95], c: C.legLo });
  });

  // ---------------- Long straight tail ----------------
  tailChain(rig, P, pelvis, [
    { p: [0, 5.65, 1.85], s: [1.3, 1.2, 1.5], c: [0, 5.65, 2.55] },
    { p: [0, 5.6, 3.3], s: [1.0, 0.95, 1.5], c: [0, 5.58, 4.0] },
    { p: [0, 5.5, 4.75], s: [0.76, 0.74, 1.5], c: [0, 5.46, 5.45] },
    { p: [0, 5.38, 6.2], s: [0.56, 0.56, 1.45], c: [0, 5.33, 6.88] },
    { p: [0, 5.24, 7.6], s: [0.38, 0.38, 1.35], c: [0, 5.2, 8.22] },
  ], { c: C.blue, under: C.white, band: C.blueLo, studs: false, each: (Tc, d, i) => {
    if (i < 3) Tc.wedgeF({ name: 'TailFeather', s: [d.s[0] * 0.36, 0.22, d.s[2] * 0.7], p: [0, d.c[1] + d.s[1] / 2 + 0.11, d.c[2]], face: 'back', c: C.blueDk });
    if (i === 4) Tc.wedgeF({ name: 'TailTuft', s: [0.36, 0.36, 0.6], p: [0, 5.24, 9.05], face: 'back', c: C.feather });
  } });

  highlight(model, '#141a26', 0.45);
  return model;
}

module.exports = { build };
