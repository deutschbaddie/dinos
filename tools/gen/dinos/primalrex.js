// DINOSAUR 12 — PRIMAL REX (Secret). Original fictional hybrid: intelligent, monstrous, unpredictable.
// ~30 studs long, ~17 tall. Bone-white body under charcoal armour, crimson scars, glowing red eyes.
const { makeDino, seg, boneAt, teeth, claw, dorsal, eye, band, highlight, segBox, bipedLeg, tailChain } = require('./common.js');
const { rng } = require('../builder.js');

const C = {
  bone: '#e8e2d4', boneLo: '#cfc7b4', boneHi: '#f4efe4', armor: '#2e2e33', armorHi: '#3c3c43', armorLo: '#222226',
  crimson: '#b0202a', crimsonLo: '#7e141c', eye: '#ff2a2a', tooth: '#fbf7ec', mouth: '#3a080c', tongue: '#9a2a3a', claw: '#141416',
};

function build() {
  const { model, rig } = makeDino('PrimalRex', {
    DisplayName: 'Primal Rex', Rarity: 'Secret', Classification: 'Hybrid Predator', Personality: 'Intelligent, monstrous, unpredictable',
    Locomotion: 'Biped', SignatureMove: 'The Primal Awakening',
  }, [5, 5.5, 11], [0, 9.6, 0]);
  const S = { c: C.bone };
  const R = rng(1212);
  const spikes = (ctx, pts) => dorsal(ctx, pts, { h: 1.3, d: 1.0, w: 0.5, c: C.armor, face: 'back' });
  const armorPlate = (ctx, p, s, r) => ctx.box({ name: 'ArmorPlate', s, p, r: r || [0, 0, 0], c: C.armor, studs: 'top' });

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 9.7, 1.7], S);
  P.box({ name: 'Hip', s: [4.2, 4.0, 3.6], p: [0, 9.7, 1.9], studs: 'top' });
  armorPlate(P, [0, 11.9, 1.9], [3.4, 0.6, 3.2]);
  P.box({ name: 'HipBelly', s: [3.4, 0.35, 3.4], p: [0, 7.55, 1.8], c: C.boneLo });
  for (const z of [1.0, 2.8]) band(P, [0, 10.9, z], [4.26, 1.2, 0.5], { c: C.armorLo });
  spikes(P, [[12.2, 0.8, 1], [12.2, 2.1, 1.1], [12.2, 3.3, 0.9]]);

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 9.8, -0.4], S);
  T.box({ name: 'Body', s: [4.6, 4.6, 4.8], p: [0, 9.8, -2.2], studs: 'top' });
  armorPlate(T, [0, 12.35, -2.0], [3.8, 0.6, 4.4]);
  T.box({ name: 'ChestFront', s: [3.8, 3.8, 1.2], p: [0, 9.6, -5.0], c: C.boneLo });
  for (const z of [-0.8, -2.2, -3.6]) band(T, [0, 11.2, z], [4.66, 1.2, 0.5], { c: C.armorLo });
  T.sym((s, side) => {
    for (let i = 0; i < 3; i++) armorPlate(s, [2.34, 10.3 - i * 0.9, -1.0 - i * 1.1], [0.2, 0.8, 1.4], [0, 0, 8]);
  });
  // asymmetric scars: three crimson slashes on the LEFT flank only
  const L = T.clone({ mirrored: true });
  for (let i = -1; i <= 1; i++) L.box({ name: 'Scar', s: [0.06, 0.18, 2.2 - Math.abs(i) * 0.4], p: [2.33, 10.6 + i * 0.4, -3.4 + i * 0.15], r: [32, 0, 0], c: C.crimson, shadow: false });
  spikes(T, [[12.65, -0.4, 1.15], [12.65, -1.7, 1.3], [12.65, -3.0, 1.25], [12.6, -4.2, 1.05]]);
  const [chest, Ch] = boneAt(rig, T, 'Chest', torso, [0, 8.0, -2.8], S);
  for (let i = 0; i < 5; i++) Ch.box({ name: 'BellyScute', s: [3.6 - i * 0.1, 0.42, 0.95], p: [0, 7.45 + i * 0.13, -0.3 - i * 0.9], c: i % 2 ? C.boneLo : C.bone });
  T.attach('VFX_Chest', [0, 8.8, -5.7]);

  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 10.6, -5.2], S);
  segBox(N1, [0, 10.6, -5.2], [0, 11.8, -6.5], 3.4, 3.2, { name: 'NeckBase', studs: 'top' });
  N1.box({ name: 'NeckArmor', s: [2.8, 0.5, 1.8], p: [0, 12.9, -5.8], r: [-35, 0, 0], c: C.armor });
  N1.box({ name: 'Throat', s: [2.6, 2.2, 0.3], p: [0, 10.3, -6.6], r: [-35, 0, 0], c: C.boneLo });
  spikes(N1, [[13.0, -5.6, 0.95]]);
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 11.7, -6.45], S);
  segBox(N2, [0, 11.7, -6.45], [0, 12.6, -7.5], 3.0, 2.9, { name: 'NeckUpper' });
  N2.box({ name: 'NeckArmor', s: [2.4, 0.45, 1.4], p: [0, 13.65, -6.9], r: [-30, 0, 0], c: C.armor });
  spikes(N2, [[13.85, -6.6, 0.8]]);

  const [head, H] = boneAt(rig, N2, 'Head', neck2, [0, 12.65, -7.5], S);
  H.box({ name: 'Cranium', s: [3.6, 3.0, 2.6], p: [0, 13.3, -8.5], studs: 'top' });
  H.box({ name: 'Snout', s: [3.0, 2.0, 4.0], p: [0, 12.85, -11.7] });
  H.box({ name: 'NoseTip', s: [2.6, 1.7, 0.7], p: [0, 12.75, -14.0], c: C.boneLo });
  H.wedgeF({ name: 'ForeheadSlope', s: [3.0, 0.8, 1.4], p: [0, 14.25, -10.3], face: 'front', c: C.bone });
  // layered facial armour
  H.box({ name: 'SkullArmor', s: [3.2, 0.5, 2.4], p: [0, 15.05, -8.5], c: C.armor, studs: 'top' });
  H.box({ name: 'SnoutArmor', s: [2.2, 0.35, 3.0], p: [0, 14.0, -11.8], c: C.armor });
  for (let i = 0; i < 3; i++) H.box({ name: 'SnoutPlate', s: [1.4 - i * 0.2, 0.2, 0.7], p: [0, 14.25, -10.9 - i * 0.95], c: C.armorHi });
  H.box({ name: 'Palate', s: [2.6, 0.25, 4.8], p: [0, 11.75, -11.4], c: C.mouth });
  H.box({ name: 'Throat', s: [2.4, 1.4, 0.8], p: [0, 11.9, -8.6], c: C.mouth });
  H.sym((s, side, n) => {
    s.box({ name: 'BrowPlate', s: [0.9, 0.7, 1.7], p: [1.35, 14.7, -9.0], r: [0, -10, -18], c: C.armor, studs: 'top' });
    s.wedgeF({ name: 'BrowHorn', s: [0.6, 0.9, 0.8], p: [1.5, 15.4, -8.2], face: 'back', r: [0, -20, -15], c: C.armorLo });
    eye(s, [1.82, 13.85, -9.4], { h: 0.45, d: 0.62, c: C.eye, neon: true, lid: C.bone });
    s.box({ name: 'CheekArmor', s: [0.3, 1.6, 2.0], p: [1.75, 12.6, -8.6], c: C.armor });
    s.box({ name: 'JawMuscle', s: [0.5, 2.0, 1.8], p: [1.6, 12.8, -8.3], c: C.boneLo });
    s.box({ name: 'UpperLip', s: [0.14, 0.35, 5.6], p: [1.5, 12.0, -11.5], c: C.armorLo });
    s.box({ name: 'Nostril', s: [0.35, 0.25, 0.5], p: [0.75, 13.55, -13.7], c: '#0a0a0a' });
    // three rows of jagged teeth
    teeth(s, { n: 10, x: 1.3, y: 11.85, z0: -9.0, z1: -14.0, h: 0.6, d: 0.42, w: 0.3, dir: 'down', sizes: [0.8, 1.2, 1, 1.45, 1, 1.3, 1.1, 1.4, 0.9, 1.1], c: C.tooth });
    teeth(s, { n: 8, x: 0.95, y: 11.85, z0: -9.4, z1: -13.6, h: 0.42, d: 0.32, w: 0.22, dir: 'down', sizes: [1, 1.2, 0.9, 1.1], c: C.boneHi });
    teeth(s, { n: 6, x: 0.6, y: 11.85, z0: -9.8, z1: -13.2, h: 0.3, d: 0.25, w: 0.18, dir: 'down', c: C.boneHi });
    s.attach(`VFX_${n}Eye`, [1.9, 13.85, -9.4]);
  });
  // asymmetric face scars (left side)
  const HL = H.clone({ mirrored: true });
  for (let i = 0; i < 3; i++) HL.box({ name: 'FaceScar', s: [0.06, 0.16, 2.2], p: [1.52 + i * 0.01, 13.4 - i * 0.4, -11.0 - i * 0.2], r: [-28, 0, 0], c: C.crimson, shadow: false });
  HL.box({ name: 'ScarredEyeMark', s: [0.07, 1.2, 0.18], p: [1.92, 13.9, -9.4], r: [0, 0, 15], c: C.crimsonLo, shadow: false });
  H.attach('VFX_Mouth', [0, 11.9, -14.4]);
  H.attach('VFX_Roar', [0, 11.9, -12.5]);
  H.attach('VFX_Head', [0, 13.5, -10.0]);
  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 11.7, -8.5], S);
  J.box({ name: 'LowerJaw', s: [2.7, 1.0, 5.4], p: [0, 11.2, -11.4] });
  J.box({ name: 'Chin', s: [2.4, 1.0, 0.7], p: [0, 11.2, -14.1], c: C.boneLo });
  J.box({ name: 'JawArmor', s: [2.2, 0.3, 5.0], p: [0, 10.62, -11.4], c: C.armor });
  J.box({ name: 'Tongue', s: [1.6, 0.25, 3.4], p: [0, 11.75, -10.8], c: C.tongue });
  J.sym((s) => {
    teeth(s, { n: 9, x: 1.18, y: 11.7, z0: -9.3, z1: -14.0, h: 0.52, d: 0.38, w: 0.28, dir: 'up', sizes: [0.9, 1.25, 1, 1.35, 0.95, 1.3, 1.05, 1.2, 0.9], c: C.tooth });
    teeth(s, { n: 6, x: 0.8, y: 11.7, z0: -9.8, z1: -13.4, h: 0.36, d: 0.28, w: 0.2, dir: 'up', c: C.boneHi });
  });

  // Large forearms with oversized curved claws
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [2.3, 9.2, -4.2], S);
    segBox(A, [2.3, 9.2, -4.2], [2.6, 7.4, -5.2], 1.1, 1.2, { name: 'UpperArm', c: C.bone });
    A.box({ name: 'ShoulderArmor', s: [1.0, 0.9, 1.4], p: [2.55, 9.0, -4.3], c: C.armor, studs: 'top' });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [2.6, 7.4, -5.2], S);
    segBox(F, [2.6, 7.4, -5.2], [2.6, 6.6, -6.7], 0.95, 1.0, { name: 'Forearm', c: C.boneLo });
    F.box({ name: 'ForearmArmor', s: [1.0, 0.35, 1.3], p: [2.6, 7.4, -6.0], r: [-28, 0, 0], c: C.armor });
    F.box({ name: 'Hand', s: [1.0, 0.7, 0.8], p: [2.6, 6.4, -7.0], c: C.boneLo });
    for (const dx of [-0.3, 0, 0.3]) claw(F, [2.6 + dx, 6.15, -7.45], { s: 0.75, c: C.claw });
    F.attach(`VFX_${n}Claw`, [2.6, 6.0, -7.9]);
  });
  P.sym((s, side, n) => bipedLeg(rig, s, pelvis, n, { hip: [2.7, 9.4, 1.7], knee: [3.1, 5.7, 0.2], ankle: [3.1, 2.35, 1.9], ball: [3.1, 0.55, 0.6] }, {
    thigh: [2.0, 2.9], shin: [1.4, 1.55], meta: [1.15, 1.15], toeLen: 1.6, toeW: 0.55, toeH: 0.55, muscle: { s: [1.9, 3.6, 3.1], p: [3.15, 7.9, 1.3] }, c: C.bone, cLo: C.boneLo, claw: C.claw,
  }));

  tailChain(rig, P, pelvis, [
    { p: [0, 10.0, 3.7], s: [3.6, 3.4, 2.6], c: [0, 10.0, 4.7] },
    { p: [0, 9.9, 6.0], s: [2.9, 2.8, 2.5], c: [0, 9.85, 7.0] },
    { p: [0, 9.6, 8.3], s: [2.2, 2.2, 2.4], c: [0, 9.55, 9.3] },
    { p: [0, 9.25, 10.5], s: [1.6, 1.6, 2.3], c: [0, 9.2, 11.4] },
    { p: [0, 8.9, 12.6], s: [1.1, 1.1, 2.1], c: [0, 8.85, 13.5] },
    { p: [0, 8.55, 14.6], s: [0.7, 0.7, 1.8], c: [0, 8.5, 15.4] },
  ], { c: C.bone, under: C.boneLo, band: C.armorLo, each: (Tc, d, i) => {
    if (i < 5) spikes(Tc, [[d.c[1] + d.s[1] / 2, d.c[2], 0.95 - i * 0.14]]);
    Tc.box({ name: 'TailArmor', s: [d.s[0] * 0.8, 0.3, d.s[2] * 0.6], p: [0, d.c[1] + d.s[1] / 2 + 0.05, d.c[2] - d.s[2] * 0.2], c: C.armor });
  } });

  highlight(model, '#1a0a0a', 0.35);
  return model;
}

module.exports = { build };
