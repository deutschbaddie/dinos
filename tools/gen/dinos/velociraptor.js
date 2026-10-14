// DINOSAUR 01 — VELOCIRAPTOR (Common). Lean, mischievous, oversized angular head, sickle claws.
// ~6.5 studs long, ~3.5 tall. Forward = -Z.
const { makeDino, seg, boneAt, teeth, claw, dorsal, eye, band, highlight, shade } = require('./common.js');

const C = {
  olive: '#7b8a3a', oliveHi: '#93a347', oliveLo: '#5f6d2b', stripe: '#3e5226', stripeLo: '#2f4020',
  cream: '#e9dfbf', creamLo: '#cdbf98', eye: '#ffb21a', claw: '#26221e', mouth: '#7a2026', tongue: '#c25560', tooth: '#f6efd9',
};

function build() {
  const { model, rig } = makeDino('Velociraptor', {
    DisplayName: 'Velociraptor', Rarity: 'Common', Classification: 'Small Predator', Personality: 'Fast, aggressive, mischievous',
    Locomotion: 'Biped', SignatureMove: 'Raptor Screech',
  }, [1.2, 1.2, 2.6], [0, 1.9, 0]);
  const S = { c: C.olive };

  // ---------------- Spine ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 1.95, 0.3], S);
  P.box({ name: 'Hip', s: [1.0, 0.85, 1.0], p: [0, 2.0, 0.35], studs: 'top' });
  P.box({ name: 'HipRidge', s: [0.82, 0.2, 0.92], p: [0, 2.5, 0.35], c: C.oliveLo });
  P.box({ name: 'HipBelly', s: [0.8, 0.12, 0.9], p: [0, 1.55, 0.3], c: C.cream });
  band(P, [0, 2.3, 0.12], [1.04, 0.36, 0.16], { c: C.stripe });
  band(P, [0, 2.3, 0.58], [1.04, 0.36, 0.16], { c: C.stripe });
  dorsal(P, [[2.6, 0.1, 0.9], [2.6, 0.45, 1], [2.6, 0.8, 0.9]], { h: 0.18, d: 0.25, w: 0.14, c: C.stripe });

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 1.98, -0.25], S);
  T.box({ name: 'Chest', s: [1.05, 0.95, 1.05], p: [0, 1.98, -0.45], studs: 'top' });
  T.box({ name: 'ChestFront', s: [0.85, 0.8, 0.4], p: [0, 1.98, -1.1] });
  T.box({ name: 'BackRidge', s: [0.75, 0.18, 1.25], p: [0, 2.53, -0.5], c: C.oliveLo });
  T.box({ name: 'Belly', s: [0.86, 0.15, 1.2], p: [0, 1.47, -0.55], c: C.cream });
  T.box({ name: 'ChestPlate', s: [0.7, 0.5, 0.06], p: [0, 1.82, -1.32], c: C.cream });
  band(T, [0, 2.3, -0.2], [1.09, 0.4, 0.15], { c: C.stripe });
  band(T, [0, 2.3, -0.7], [1.09, 0.4, 0.15], { c: C.stripe });
  T.sym((s) => s.box({ name: 'Shoulder', s: [0.16, 0.35, 0.4], p: [0.5, 1.88, -0.95], c: C.oliveLo }));
  dorsal(T, [[2.62, -0.15, 1], [2.62, -0.5, 1.05], [2.6, -0.85, 0.95]], { h: 0.2, d: 0.26, w: 0.14, c: C.stripe });

  // ---------------- Neck / head / jaw ----------------
  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 2.15, -1.05], S);
  const Nf = N.at([0, 2.15, -1.05], [-28, 0, 0]);
  Nf.box({ name: 'NeckLower', s: [0.6, 0.85, 0.6], p: [0, 0.35, 0] });
  Nf.box({ name: 'NeckUpper', s: [0.5, 0.7, 0.5], p: [0, 0.95, -0.04] });
  Nf.box({ name: 'Throat', s: [0.44, 1.1, 0.06], p: [0, 0.6, -0.32], c: C.cream });
  band(Nf, [0, 0.45, 0.06], [0.66, 0.24, 0.56], { c: C.stripe });
  dorsal(Nf, [[0.66, 0.24, 0.9], [1.0, 0.2, 0.8]], { h: 0.16, d: 0.22, w: 0.12, c: C.stripe, face: 'back' });

  const HO = [0, 0.15, -0.1];
  const [head, H0] = boneAt(rig, N, 'Head', neck, [0, 3.05, -1.55], S);
  const H = H0.at(HO);
  H.box({ name: 'Cranium', s: [0.8, 0.62, 0.75], p: [0, 3.05, -1.75], studs: 'top' });
  H.box({ name: 'Snout', s: [0.6, 0.42, 1.0], p: [0, 2.98, -2.58] });
  H.wedgeF({ name: 'SnoutSlope', s: [0.6, 0.17, 0.8], p: [0, 3.275, -2.6], face: 'front', c: C.oliveHi });
  H.box({ name: 'NoseTip', s: [0.52, 0.34, 0.2], p: [0, 2.95, -3.17] });
  H.box({ name: 'HeadStripe', s: [0.84, 0.3, 0.12], p: [0, 3.24, -1.5], c: C.stripe });
  H.box({ name: 'SnoutStripe', s: [0.66, 0.14, 0.1], p: [0, 3.14, -2.3], c: C.stripe });
  H.box({ name: 'MouthInterior', s: [0.48, 0.16, 1.15], p: [0, 2.72, -2.4], c: C.mouth });
  H.sym((s) => {
    s.box({ name: 'BrowRidge', s: [0.22, 0.14, 0.56], p: [0.33, 3.34, -1.86], r: [0, -8, -14], c: C.stripeLo });
    eye(s, [0.41, 3.13, -1.86], { h: 0.14, d: 0.28, r: [0, -8, 0], c: C.eye, lid: C.oliveLo });
    s.box({ name: 'Cheek', s: [0.12, 0.3, 0.48], p: [0.4, 2.86, -1.68], c: C.oliveLo });
    s.box({ name: 'Nostril', s: [0.1, 0.07, 0.12], p: [0.17, 3.13, -3.1], c: '#1e1e1e' });
    s.box({ name: 'UpperLip', s: [0.06, 0.12, 1.1], p: [0.31, 2.83, -2.55], c: C.oliveLo });
    teeth(s, { n: 6, x: 0.25, y: 2.78, z0: -1.95, z1: -3.02, h: 0.15, d: 0.12, w: 0.08, dir: 'down', sizes: [0.8, 1, 1.2, 0.9, 1.1, 0.8], c: C.tooth });
    // little feather crest at the back of the head
    s.wedgeF({ name: 'CrestFeather', s: [0.06, 0.26, 0.32], p: [0.14, 3.48, -1.42], face: 'back', r: [0, 0, -12], c: C.stripe });
  });
  teeth(H, { n: 2, x: 0.09, y: 2.78, z0: -3.13, z1: -3.13, h: 0.13, d: 0.1, w: 0.08, dir: 'down', c: C.tooth });
  dorsal(H, [[3.36, -1.55, 1], [3.36, -1.85, 0.8], [3.36, -2.1, 0.6]], { h: 0.16, d: 0.22, w: 0.1, c: C.stripe });
  H.attach('VFX_Mouth', [0, 2.75, -3.25]);
  H.attach('VFX_Head', [0, 3.1, -1.9]);
  H.sym((s, side, n) => s.attach(`VFX_${n}Eye`, [0.45, 3.13, -1.86]));

  const [jaw, J0] = boneAt(rig, H, 'Jaw', head, [0, 2.78, -1.62], S);
  const J = J0.at(HO);
  J.box({ name: 'LowerJaw', s: [0.54, 0.2, 1.35], p: [0, 2.66, -2.35] });
  J.box({ name: 'JawUnderside', s: [0.48, 0.06, 1.3], p: [0, 2.54, -2.35], c: C.cream });
  J.box({ name: 'Chin', s: [0.46, 0.2, 0.18], p: [0, 2.66, -3.07] });
  J.box({ name: 'Tongue', s: [0.3, 0.06, 0.8], p: [0, 2.77, -2.2], c: C.tongue });
  J.sym((s) => {
    s.box({ name: 'JawMuscle', s: [0.12, 0.28, 0.4], p: [0.3, 2.74, -1.76], c: C.oliveLo });
    teeth(s, { n: 5, x: 0.21, y: 2.76, z0: -1.98, z1: -2.96, h: 0.13, d: 0.11, w: 0.07, dir: 'up', sizes: [0.8, 1.1, 0.9, 1.2, 0.8], c: C.tooth });
  });

  // ---------------- Arms ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [0.42, 1.78, -0.95], S);
    A.box({ name: 'UpperArm', s: [0.2, 0.5, 0.22], p: [0.47, 1.58, -1.0], r: [15, 0, 0] });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [0.48, 1.36, -1.08], S);
    F.box({ name: 'Forearm', s: [0.18, 0.42, 0.18], p: [0.48, 1.2, -1.22], r: [-40, 0, 0] });
    F.box({ name: 'Hand', s: [0.16, 0.12, 0.2], p: [0.48, 1.05, -1.38] });
    F.wedgeF({ name: 'ArmFeather', s: [0.04, 0.24, 0.3], p: [0.55, 1.18, -1.05], face: 'back', flip: true, c: C.stripe });
    for (const dx of [-0.05, 0.05]) claw(F, [0.48 + dx, 0.98, -1.44], { s: 0.15, c: C.claw });
  });

  // ---------------- Legs ----------------
  P.sym((s, side, n) => {
    const [thigh, Th] = boneAt(rig, s, `${n}Thigh`, pelvis, [0.50, 1.95, 0.3], S);
    Th.box({ name: 'Thigh', s: [0.50, 0.85, 0.65], p: [0.60, 1.62, 0.15], r: [-15, 0, 0], studs: 'top' });
    band(Th, [0.61, 1.75, 0.2], [0.54, 0.18, 0.6], { c: C.stripe, r: [-15, 0, 0] });
    Th.box({ name: 'Knee', s: [0.36, 0.3, 0.3], p: [0.61, 1.27, -0.04], c: C.oliveLo });
    const [shin, Sh] = boneAt(rig, Th, `${n}Shin`, thigh, [0.58, 1.25, -0.05], S);
    Sh.box({ name: 'Shin', s: [0.26, 0.75, 0.3], p: [0.60, 0.95, 0.18], r: [30, 0, 0] });
    const [foot, Fo] = boneAt(rig, Sh, `${n}Foot`, shin, [0.60, 0.62, 0.42], S);
    Fo.box({ name: 'Metatarsus', s: [0.2, 0.55, 0.2], p: [0.60, 0.38, 0.28], r: [-25, 0, 0], c: C.oliveLo });
    Fo.box({ name: 'FootPad', s: [0.36, 0.14, 0.42], p: [0.60, 0.07, 0.04], c: C.oliveLo });
    for (const dx of [-0.07, 0.08]) {
      Fo.box({ name: 'Toe', s: [0.1, 0.1, 0.3], p: [0.61 + dx, 0.06, -0.3] });
      Fo.wedgeF({ name: 'ToeClaw', s: [0.08, 0.08, 0.12], p: [0.61 + dx, 0.05, -0.5], face: 'front', c: C.claw });
    }
    Fo.attach(`VFX_${n}Foot`, [0.60, 0.02, -0.1]);
    const [sick, Sk] = boneAt(rig, Fo, `${n}SickleClaw`, foot, [0.50, 0.18, 0.0], S);
    Sk.box({ name: 'SickleToe', s: [0.1, 0.14, 0.16], p: [0.50, 0.18, -0.02], c: C.oliveLo });
    Sk.wedgeF({ name: 'SickleClaw', s: [0.07, 0.3, 0.2], p: [0.50, 0.37, -0.1], face: 'front', r: [-20, 0, 0], c: C.claw });
    Sk.wedgeF({ name: 'SickleClawTip', s: [0.06, 0.16, 0.16], p: [0.50, 0.5, -0.24], face: 'front', flip: true, r: [-35, 0, 0], c: C.claw });
  });

  // ---------------- Tail ----------------
  const tailDefs = [
    { p: [0, 2.02, 0.85], s: [0.78, 0.7, 0.8], c: [0, 2.05, 1.2] },
    { p: [0, 2.08, 1.5], s: [0.6, 0.55, 0.78], c: [0, 2.1, 1.85] },
    { p: [0, 2.14, 2.15], s: [0.44, 0.42, 0.76], c: [0, 2.15, 2.5] },
    { p: [0, 2.2, 2.8], s: [0.3, 0.3, 0.62], c: [0, 2.2, 3.08] },
  ];
  let parent = pelvis, pc = P;
  tailDefs.forEach((d, i) => {
    const [tb, Tc] = boneAt(rig, pc, `Tail${i + 1}`, parent, d.p, S);
    Tc.box({ name: 'TailSegment', s: d.s, p: d.c, studs: i < 2 ? 'top' : undefined });
    band(Tc, [0, d.c[1] + d.s[1] * 0.18, d.c[2] + d.s[2] * 0.12], [d.s[0] + 0.04, d.s[1] * 0.68, d.s[2] * 0.3], { c: C.stripe });
    if (i < 2) Tc.box({ name: 'TailUnderside', s: [d.s[0] * 0.8, 0.08, d.s[2] * 0.9], p: [0, d.c[1] - d.s[1] / 2 - 0.02, d.c[2]], c: C.cream });
    dorsal(Tc, [[d.c[1] + d.s[1] / 2, d.c[2], 0.9 - i * 0.15]], { h: 0.18, d: 0.26, w: 0.12, c: C.stripe });
    if (i === 3) {
      // feather fan at the tail tip — a distinctive silhouette
      for (const [ry, k] of [[-22, 0.85], [0, 1], [22, 0.85]]) Tc.wedgeF({ name: 'TailFeather', s: [0.08, 0.3 * k, 0.55 * k], p: [Math.sin(ry * Math.PI / 180) * 0.15, 2.24, 3.55], r: [0, ry, 0], face: 'back', c: C.stripe });
      Tc.attach('VFX_TailTip', [0, 2.2, 3.6]);
    }
    parent = tb; pc = Tc;
  });
  T.attach('VFX_Chest', [0, 1.9, -1.3]);

  highlight(model);
  return model;
}

module.exports = { build };
