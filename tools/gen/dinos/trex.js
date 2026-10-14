// DINOSAUR 09 — TYRANNOSAURUS REX (Legendary). The flagship creature.
// ~21 studs long, ~12 tall. Forward = -Z.
const { makeDino, seg, boneAt, teeth, claw, dorsal, eye, band, highlight, shade } = require('./common.js');
const { rng } = require('../builder.js');

const C = {
  green: '#4a8a3c', greenHi: '#5ea14b', greenLo: '#3a7031', emerald: '#1f5a3f', emeraldLo: '#174630',
  tan: '#d8c08a', tanLo: '#bfa56f', tanHi: '#e6d3a3', claw: '#1b1b1b', eye: '#ffc21a',
  mouth: '#6e1a22', mouthLo: '#4a1016', tongue: '#c4505a', tooth: '#f4ecd6', toothLo: '#e2d6b8',
};

function build() {
  const { model, rig } = makeDino('TyrannosaurusRex', {
    DisplayName: 'Tyrannosaurus Rex', Rarity: 'Legendary', Classification: 'Apex Predator', Personality: 'Dominant, terrifying, iconic',
    Locomotion: 'Biped', SignatureMove: "The King's Roar",
  }, [4, 4.5, 9], [0, 7.0, -0.5]);
  const S = { c: C.green };
  const R = rng(909);

  // ---------------- Pelvis ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 7.2, 1.0], S);
  P.box({ name: 'Hip', s: [3.3, 3.0, 3.0], p: [0, 7.3, 1.1], studs: 'top' });
  P.box({ name: 'HipRidge', s: [2.7, 0.5, 2.6], p: [0, 9.0, 1.0], c: C.greenLo, studs: 'top' });
  P.box({ name: 'HipBelly', s: [2.6, 0.4, 2.4], p: [0, 5.75, 0.9], c: C.tan });
  band(P, [0, 8.42, 0.3], [3.36, 0.85, 0.5], { c: C.emerald });
  band(P, [0, 8.42, 1.8], [3.36, 0.85, 0.5], { c: C.emerald });
  dorsal(P, [[9.25, 0.2, 1.1], [9.25, 1.2, 1.2], [9.2, 2.2, 1.0]], { h: 0.5, d: 0.7, w: 0.42, c: C.emerald });

  // ---------------- Torso ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 7.2, -0.6], S);
  T.box({ name: 'Body', s: [3.7, 3.4, 3.4], p: [0, 7.25, -1.6], studs: 'top' });
  T.box({ name: 'BackHump', s: [3.1, 0.6, 3.2], p: [0, 9.2, -1.4], c: C.greenLo, studs: 'top' });
  T.box({ name: 'ChestFront', s: [3.2, 2.9, 1.0], p: [0, 7.3, -3.6] });
  band(T, [0, 8.6, -0.8], [3.76, 0.75, 0.5], { c: C.emerald });
  band(T, [0, 8.6, -2.3], [3.76, 0.75, 0.5], { c: C.emerald });
  T.sym((s) => {
    s.box({ name: 'Shoulder', s: [0.5, 1.3, 1.5], p: [1.75, 7.0, -3.0], c: C.greenLo });
    for (let i = 0; i < 4; i++) s.box({ name: 'SideScale', s: [0.12, 0.45 + R() * 0.3, 0.6 + R() * 0.4], p: [1.88, 6.9 + R() * 1.2, -1.0 - R() * 2.0], c: C.greenLo });
  });
  dorsal(T, [[9.5, -0.3, 1.2], [9.5, -1.3, 1.3], [9.5, -2.3, 1.2], [9.2, -3.2, 1.0]], { h: 0.5, d: 0.7, w: 0.42, c: C.emerald });

  // Chest: belly scutes on their own bone so breathing/roars can expand the chest
  const [chest, Ch] = boneAt(rig, T, 'Chest', torso, [0, 6.0, -2.2], S);
  Ch.box({ name: 'BellyMass', s: [3.3, 0.7, 3.4], p: [0, 5.3, -1.75], c: C.greenLo });
  for (let i = 0; i < 5; i++) Ch.box({ name: 'BellyScute', s: [2.9 - i * 0.08, 0.42, 0.86], p: [0, 4.98 + i * 0.12, -0.3 - i * 0.78], c: i % 2 ? C.tanLo : C.tan });
  Ch.box({ name: 'ChestPlate', s: [2.6, 2.0, 0.22], p: [0, 6.85, -4.12], c: C.tan });
  for (let i = 0; i < 3; i++) Ch.box({ name: 'ChestScute', s: [2.3, 0.12, 0.08], p: [0, 6.2 + i * 0.6, -4.25], c: C.tanLo });
  T.attach('VFX_Chest', [0, 6.8, -4.3]);

  // ---------------- Neck ----------------
  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 8.0, -3.9], S);
  const n1 = N1.at([0, 8.0, -3.9], [-35, 0, 0]);
  n1.box({ name: 'NeckBase', s: [2.8, 2.2, 2.6], p: [0, 0.5, 0], studs: 'top' });
  n1.box({ name: 'Throat', s: [2.3, 2.0, 0.25], p: [0, 0.35, -1.32], c: C.tan });
  band(n1, [0, 0.55, 0.9], [2.9, 1.9, 0.9], { c: C.emerald });
  dorsal(n1, [[1.6, 0.5, 1.0]], { h: 0.45, d: 0.65, w: 0.36, c: C.emerald });
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 8.9, -5.0], S);
  const n2 = N2.at([0, 8.9, -5.0], [-30, 0, 0]);
  n2.box({ name: 'NeckUpper', s: [2.5, 1.8, 2.2], p: [0, 0.4, -0.1], studs: 'top' });
  n2.box({ name: 'Throat', s: [2.0, 1.6, 0.25], p: [0, 0.3, -1.22], c: C.tan });
  band(n2, [0, 0.5, 0.75], [2.6, 1.5, 0.7], { c: C.emerald });
  n2.sym((s) => s.box({ name: 'NeckFold', s: [0.12, 1.2, 1.5], p: [1.28, 0.2, -0.3], c: C.greenLo }));
  dorsal(n2, [[1.3, 0.4, 0.9]], { h: 0.42, d: 0.6, w: 0.34, c: C.emerald });

  // ---------------- Head ----------------
  const [head, H0] = boneAt(rig, N2, 'Head', neck2, [0, 9.6, -5.8], S);
  const HK = 1.22, HP = [0, 9.6, -5.8];
  const H = H0.scaled(HK, HP);
  H.box({ name: 'Cranium', s: [2.8, 2.2, 2.0], p: [0, 10.4, -6.4], studs: 'top' });
  H.box({ name: 'SkullCap', s: [2.4, 0.4, 1.6], p: [0, 11.65, -6.3], c: C.greenLo, studs: 'top' });
  H.wedgeF({ name: 'ForeheadSlope', s: [2.4, 0.62, 1.05], p: [0, 11.2, -7.92], face: 'front', c: C.green });
  H.box({ name: 'Snout', s: [2.3, 1.45, 3.0], p: [0, 10.15, -8.6] });
  H.box({ name: 'SnoutTop', s: [2.0, 0.22, 2.6], p: [0, 10.98, -8.9], c: C.greenHi, studs: 'top' });
  H.box({ name: 'Nose', s: [2.0, 1.25, 0.6], p: [0, 10.05, -10.4] });
  H.wedgeF({ name: 'NoseSlope', s: [2.0, 0.42, 0.6], p: [0, 10.88, -10.4], face: 'front', c: C.greenHi });
  H.box({ name: 'HeadStripe', s: [2.9, 0.8, 0.35], p: [0, 11.0, -5.9], c: C.emerald });
  H.box({ name: 'SnoutStripe', s: [2.36, 0.5, 0.3], p: [0, 10.7, -9.3], c: C.emerald });
  // Mouth interior (seen when the jaw opens)
  H.box({ name: 'Palate', s: [1.95, 0.25, 3.5], p: [0, 9.3, -8.4], c: C.mouth });
  H.box({ name: 'Throat', s: [1.8, 1.1, 0.7], p: [0, 9.3, -6.6], c: C.mouthLo });
  H.sym((s) => {
    s.box({ name: 'UpperLip', s: [0.16, 0.32, 3.5], p: [1.15, 9.55, -8.6], c: C.emerald });
    s.box({ name: 'BrowRidge', s: [0.8, 0.55, 1.35], p: [1.0, 11.55, -6.95], r: [0, -10, -15], c: C.emerald, studs: 'top' });
    s.box({ name: 'BrowHorn', s: [0.45, 0.35, 0.55], p: [1.1, 11.85, -6.55], r: [0, -10, -25], c: C.emeraldLo });
    eye(s, [1.42, 10.95, -6.95], { h: 0.42, d: 0.52, c: C.eye, lid: C.greenLo });
    s.box({ name: 'JawMuscle', s: [0.4, 1.6, 1.6], p: [1.3, 10.0, -6.1], c: C.greenLo });
    s.box({ name: 'CheekScale', s: [0.1, 0.5, 0.7], p: [1.52, 10.1, -6.0], c: C.emerald });
    s.box({ name: 'CheekScale', s: [0.1, 0.35, 0.5], p: [1.52, 9.55, -6.5], c: C.emerald });
    s.box({ name: 'Nostril', s: [0.32, 0.2, 0.36], p: [0.6, 10.78, -10.42], c: '#151515' });
    s.box({ name: 'NostrilRim', s: [0.46, 0.12, 0.5], p: [0.6, 10.72, -10.4], c: C.greenLo });
    s.box({ name: 'SnoutScale', s: [0.1, 0.4, 0.6], p: [1.17, 10.25, -8.0], c: C.emerald });
    s.box({ name: 'SnoutScale', s: [0.1, 0.3, 0.5], p: [1.17, 10.45, -9.2], c: C.emerald });
    // Outer row of teeth (varied sizes) + inner row
    teeth(s, { n: 9, x: 1.0, y: 9.42, z0: -7.2, z1: -10.25, h: 0.45, d: 0.32, w: 0.24, dir: 'down', sizes: [0.8, 1.15, 1, 1.4, 1.05, 1.25, 0.95, 1.1, 0.85], c: C.tooth });
    teeth(s, { n: 7, x: 0.68, y: 9.42, z0: -7.6, z1: -10.0, h: 0.3, d: 0.24, w: 0.18, dir: 'down', sizes: [0.9, 1.1, 1, 1.2, 1, 1.1, 0.9], c: C.toothLo });
  });
  // front incisor-like teeth across the nose
  for (const x of [-0.6, -0.2, 0.2, 0.6]) H.wedgeF({ name: 'Tooth', s: [0.2, 0.42, 0.26], p: [x, 9.21, -10.5], face: 'front', flip: true, c: C.tooth, shadow: false });
  for (let i = 0; i < 5; i++) H.box({ name: 'FacialScale', s: [0.4 + R() * 0.2, 0.1, 0.35 + R() * 0.2], p: [-0.6 + R() * 1.2, 11.12, -7.9 - R() * 2.0], r: [0, R() * 30 - 15, 0], c: C.emerald });
  H.attach('VFX_Mouth', [0, 9.3, -10.5]);
  H.attach('VFX_Roar', [0, 9.3, -9.0]);
  H.attach('VFX_Head', [0, 10.6, -7.5]);
  H.sym((s, side, n) => s.attach(`VFX_${n}Eye`, [1.5, 10.95, -6.95]));

  // ---------------- Jaw ----------------
  const [jaw, J0] = boneAt(rig, H, 'Jaw', head, [0, 9.3, -6.6], S);
  const J = J0.scaled(HK, HP);
  J.box({ name: 'LowerJaw', s: [2.1, 0.75, 3.6], p: [0, 8.95, -8.4] });
  J.box({ name: 'Chin', s: [1.9, 0.75, 0.55], p: [0, 8.95, -10.45] });
  J.box({ name: 'JawUnderside', s: [1.8, 0.2, 3.9], p: [0, 8.53, -8.6], c: C.tan });
  J.box({ name: 'JawHinge', s: [2.2, 1.0, 1.0], p: [0, 9.0, -6.6], c: C.greenLo });
  J.box({ name: 'Tongue', s: [1.2, 0.2, 2.4], p: [0, 9.35, -8.0], c: C.tongue });
  J.box({ name: 'JawMouth', s: [1.7, 0.1, 3.4], p: [0, 9.3, -8.5], c: C.mouth });
  J.sym((s) => {
    s.box({ name: 'LowerLip', s: [0.12, 0.26, 3.9], p: [1.06, 9.12, -8.6], c: C.emerald });
    s.box({ name: 'JawScale', s: [0.1, 0.3, 0.8], p: [1.07, 8.8, -7.4], c: C.greenLo });
    teeth(s, { n: 8, x: 0.88, y: 9.32, z0: -7.4, z1: -10.1, h: 0.38, d: 0.28, w: 0.22, dir: 'up', sizes: [0.8, 1.1, 1.3, 1, 1.2, 0.95, 1.1, 0.85], c: C.tooth });
  });
  for (const x of [-0.5, 0, 0.5]) J.wedgeF({ name: 'Tooth', s: [0.2, 0.34, 0.22], p: [x, 9.47, -10.55], face: 'front', c: C.tooth, shadow: false });

  // ---------------- Tiny arms ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [1.55, 6.6, -3.5], S);
    A.box({ name: 'UpperArm', s: [0.55, 1.0, 0.55], p: [1.65, 6.15, -3.6], r: [20, 0, 0], c: C.greenLo });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [1.7, 5.75, -3.8], S);
    F.box({ name: 'Forearm', s: [0.45, 0.8, 0.45], p: [1.72, 5.45, -4.05], r: [-50, 0, 0] });
    F.box({ name: 'Hand', s: [0.4, 0.3, 0.35], p: [1.72, 5.2, -4.35] });
    for (const dx of [-0.1, 0.1]) claw(F, [1.72 + dx, 5.05, -4.55], { s: 0.32, c: C.claw });
  });

  // ---------------- Massive legs ----------------
  P.sym((s, side, n) => {
    const [thigh, Th] = boneAt(rig, s, `${n}Thigh`, pelvis, [1.9, 7.1, 1.0], S);
    Th.box({ name: 'Thigh', s: [1.5, 3.2, 2.7], p: [2.55, 6.0, 0.5], r: [-12, 0, 0], studs: 'top' });
    Th.box({ name: 'ThighMuscle', s: [0.22, 2.3, 2.0], p: [3.32, 6.15, 0.55], r: [-12, 0, 0], c: C.greenLo });
    band(Th, [2.56, 6.6, 0.6], [1.56, 0.5, 2.76], { c: C.emerald, r: [-12, 0, 0] });
    Th.box({ name: 'Knee', s: [1.2, 1.0, 1.15], p: [2.5, 4.5, -0.35], c: C.greenLo });
    const [shin, Sh] = boneAt(rig, Th, `${n}Shin`, thigh, [2.45, 4.3, -0.4], S);
    Sh.box({ name: 'Shin', s: [1.3, 2.7, 1.45], p: [2.47, 3.15, 0.3], r: [28, 0, 0] });
    Sh.box({ name: 'ShinScale', s: [1.0, 1.7, 0.14], p: [2.47, 3.25, -0.4], r: [28, 0, 0], c: C.greenLo });
    const [foot, Fo] = boneAt(rig, Sh, `${n}Foot`, shin, [2.45, 1.9, 1.0], S);
    Fo.box({ name: 'Metatarsus', s: [1.05, 1.7, 1.05], p: [2.45, 1.2, 0.45], r: [-35, 0, 0], c: C.greenLo });
    Fo.wedgeF({ name: 'HeelSpur', s: [0.5, 0.5, 0.6], p: [2.45, 1.6, 1.4], face: 'back', c: C.emerald });
    const [toes, To] = boneAt(rig, Fo, `${n}Toes`, foot, [2.45, 0.5, -0.2], S);
    To.box({ name: 'ToePad', s: [1.3, 0.5, 1.0], p: [2.45, 0.25, -0.4], c: C.greenLo });
    for (const [dx, ry, k] of [[-0.45, 10, 0.9], [0, 0, 1.05], [0.45, -10, 0.9]]) {
      To.box({ name: 'Toe', s: [0.42, 0.45, 1.2 * k], p: [2.45 + dx, 0.24, -1.05 * k], r: [0, ry, 0] });
      To.box({ name: 'ToeScale', s: [0.36, 0.08, 0.5], p: [2.45 + dx, 0.5, -0.9 * k], r: [0, ry, 0], c: C.emerald });
      claw(To, [2.45 + dx * 1.15, 0.3, -1.7 * k], { s: 0.42, c: C.claw, r: [0, ry, 0] });
    }
    To.wedgeF({ name: 'Dewclaw', s: [0.3, 0.3, 0.4], p: [2.1, 0.35, 0.25], face: 'back', c: C.claw });
    To.attach(`VFX_${n}Foot`, [2.45, 0.05, -0.6]);
  });

  // ---------------- Tail ----------------
  const tailDefs = [
    { p: [0, 7.5, 2.8], s: [2.9, 2.6, 2.3], c: [0, 7.55, 3.65] },
    { p: [0, 7.4, 4.7], s: [2.3, 2.1, 2.1], c: [0, 7.45, 5.6] },
    { p: [0, 7.2, 6.5], s: [1.75, 1.6, 2.0], c: [0, 7.25, 7.4] },
    { p: [0, 6.95, 8.2], s: [1.25, 1.15, 1.8], c: [0, 7.0, 9.0] },
    { p: [0, 6.7, 9.7], s: [0.8, 0.75, 1.5], c: [0, 6.72, 10.4] },
  ];
  let parent = pelvis, pc = P;
  tailDefs.forEach((d, i) => {
    const [tb, Tc] = boneAt(rig, pc, `Tail${i + 1}`, parent, d.p, S);
    Tc.box({ name: 'TailSegment', s: d.s, p: d.c, studs: 'top' });
    band(Tc, [0, d.c[1] + d.s[1] * 0.3, d.c[2] + d.s[2] * 0.15], [d.s[0] + 0.08, d.s[1] * 0.45, d.s[2] * 0.34], { c: C.emerald });
    Tc.box({ name: 'TailUnderside', s: [d.s[0] * 0.75, 0.2, d.s[2] * 0.92], p: [0, d.c[1] - d.s[1] / 2 - 0.05, d.c[2]], c: C.tan });
    dorsal(Tc, [[d.c[1] + d.s[1] / 2, d.c[2] - d.s[2] * 0.2, 1.0 - i * 0.13], [d.c[1] + d.s[1] / 2, d.c[2] + d.s[2] * 0.3, 0.85 - i * 0.12]], { h: 0.48, d: 0.66, w: 0.38, c: C.emerald });
    if (i === 4) {
      Tc.wedgeF({ name: 'TailTip', s: [0.6, 0.55, 0.7], p: [0, 6.68, 11.5], face: 'back', c: C.green });
      Tc.attach('VFX_TailTip', [0, 6.7, 11.6]);
    }
    parent = tb; pc = Tc;
  });

  highlight(model);
  return model;
}

module.exports = { build };
