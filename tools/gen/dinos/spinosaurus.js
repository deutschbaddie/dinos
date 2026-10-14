// DINOSAUR 08 — SPINOSAURUS (Epic). Territorial, aquatic, intimidating. ~23 studs long, ~13.5 tall.
const { makeDino, seg, boneAt, teeth, claw, dorsal, eye, band, highlight, segBox, bipedLeg, tailChain } = require('./common.js');

const C = {
  body: '#1f6f73', bodyHi: '#2b878b', bodyLo: '#185a5d', navy: '#1c2f4f', navyLo: '#142339', sail: '#e0532a', sailHi: '#f07a45', sailBand: '#9c2a17',
  spine: '#efe2c4', belly: '#e8dcc0', eye: '#ffd21a', mouth: '#5a1418', tongue: '#b84858', tooth: '#f6f0dc', claw: '#1a1a1a',
};

function build() {
  const { model, rig } = makeDino('Spinosaurus', {
    DisplayName: 'Spinosaurus', Rarity: 'Epic', Classification: 'Apex Predator', Personality: 'Territorial, aquatic, intimidating',
    Locomotion: 'Biped', SignatureMove: 'River Ambush',
  }, [3.6, 3.6, 8], [0, 6.8, 0.4]);
  const S = { c: C.body };

  // Sail: tall spines with membrane panels between them, banded
  const sail = (ctx, zs, base, heights) => {
    for (let i = 0; i < zs.length; i++) {
      const z = zs[i], h = heights[i];
      segBox(ctx, [0, base(z) + h, z], [0, base(z) - 0.2, z], 0.22, 0.22, { name: 'SailSpine', c: C.spine, extend: 0 });
      if (i < zs.length - 1) {
        const z2 = zs[i + 1], h2 = heights[i + 1];
        const hm = (h + h2) / 2, zm = (z + z2) / 2, yb = (base(z) + base(z2)) / 2;
        ctx.box({ name: 'SailMembrane', s: [0.12, hm, Math.abs(z2 - z) + 0.02], p: [0, yb + hm / 2 - 0.1, zm], c: C.sail });
        ctx.box({ name: 'SailBand', s: [0.16, hm * 0.14, Math.abs(z2 - z) + 0.02], p: [0, yb + hm * 0.62, zm], c: C.sailBand, shadow: false });
        ctx.box({ name: 'SailTop', s: [0.16, 0.25, Math.abs(z2 - z) + 0.02], p: [0, yb + hm - 0.2, zm], c: C.sailHi, shadow: false });
      }
    }
  };

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 6.8, 1.6], S);
  P.box({ name: 'Hip', s: [3.0, 3.0, 2.8], p: [0, 6.8, 1.8], studs: 'top' });
  P.box({ name: 'HipBelly', s: [2.4, 0.3, 2.6], p: [0, 5.2, 1.6], c: C.belly });
  band(P, [0, 7.6, 1.3], [3.06, 1.2, 0.5], { c: C.navy });
  sail(P, [0.6, 1.6, 2.6, 3.4], () => 8.2, [4.2, 3.3, 2.3, 1.2]);

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 6.9, 0.2], S);
  T.box({ name: 'Body', s: [3.2, 3.2, 3.6], p: [0, 7.0, -1.4], studs: 'top' });
  T.box({ name: 'ChestFront', s: [2.6, 2.6, 0.9], p: [0, 6.9, -3.5], c: C.bodyLo });
  T.box({ name: 'Belly', s: [2.6, 0.3, 4.2], p: [0, 5.3, -1.6], c: C.belly });
  band(T, [0, 7.9, -0.6], [3.26, 1.2, 0.5], { c: C.navy });
  band(T, [0, 7.9, -2.2], [3.26, 1.2, 0.5], { c: C.navy });
  sail(T, [-3.3, -2.4, -1.4, -0.4, 0.6], (z) => 8.5 - (z < -2.5 ? 0.3 : 0), [2.2, 4.0, 5.3, 5.8, 5.2]);
  T.attach('VFX_Chest', [0, 6.4, -3.9]);

  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 7.4, -3.6], S);
  segBox(N1, [0, 7.4, -3.6], [0, 8.2, -4.9], 2.1, 2.0, { name: 'NeckBase', studs: 'top' });
  N1.box({ name: 'Throat', s: [1.6, 1.4, 0.2], p: [0, 7.2, -4.6], r: [-30, 0, 0], c: C.belly });
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 8.1, -4.85], S);
  segBox(N2, [0, 8.1, -4.85], [0, 8.6, -5.9], 1.7, 1.7, { name: 'NeckUpper' });
  dorsal(N2, [[9.2, -5.1, 0.8]], { h: 0.35, d: 0.5, w: 0.25, c: C.navy });

  const [head, H] = boneAt(rig, N2, 'Head', neck2, [0, 8.65, -5.9], S);
  H.box({ name: 'Cranium', s: [1.9, 1.6, 1.8], p: [0, 8.9, -6.6], studs: 'top' });
  H.box({ name: 'EyeCrest', s: [1.0, 0.45, 1.0], p: [0, 9.9, -6.7], c: C.navy });
  H.box({ name: 'Snout', s: [1.25, 0.95, 4.3], p: [0, 8.55, -9.5] });
  H.box({ name: 'SnoutTop', s: [0.9, 0.18, 4.0], p: [0, 9.1, -9.5], c: C.bodyHi });
  H.box({ name: 'Rosette', s: [1.6, 1.1, 0.9], p: [0, 8.55, -12.0], c: C.bodyLo, studs: 'top' });
  H.box({ name: 'Palate', s: [1.0, 0.2, 5.2], p: [0, 7.98, -9.6], c: C.mouth });
  H.sym((s, side, n) => {
    eye(s, [0.97, 9.15, -6.8], { h: 0.3, d: 0.42, c: C.eye, lid: C.body });
    s.box({ name: 'Brow', s: [0.3, 0.3, 0.8], p: [0.88, 9.5, -6.8], r: [0, 0, -12], c: C.navy });
    s.box({ name: 'Nostril', s: [0.12, 0.15, 0.4], p: [0.35, 9.0, -8.6], c: '#0c1414' });
    s.box({ name: 'UpperLip', s: [0.1, 0.2, 5.3], p: [0.65, 8.15, -9.6], c: C.navyLo });
    teeth(s, { n: 10, x: 0.55, y: 8.08, z0: -7.2, z1: -11.9, h: 0.38, d: 0.18, w: 0.16, dir: 'down', sizes: [0.7, 0.9, 1.1, 0.8, 1, 0.8, 1.1, 0.9, 1.3, 1.4], c: C.tooth });
    s.attach(`VFX_${n}Eye`, [1.0, 9.15, -6.8]);
  });
  H.attach('VFX_Mouth', [0, 8.1, -12.5]);
  H.attach('VFX_Head', [0, 9.0, -7.6]);
  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 8.0, -6.6], S);
  J.box({ name: 'LowerJaw', s: [1.1, 0.55, 5.5], p: [0, 7.68, -9.4] });
  J.box({ name: 'JawTip', s: [1.4, 0.6, 0.7], p: [0, 7.68, -12.0], c: C.bodyLo });
  J.box({ name: 'JawUnderside', s: [0.9, 0.15, 5.4], p: [0, 7.36, -9.4], c: C.belly });
  J.box({ name: 'Tongue', s: [0.6, 0.12, 3.0], p: [0, 7.98, -8.6], c: C.tongue });
  J.sym((s) => teeth(s, { n: 9, x: 0.48, y: 7.96, z0: -7.4, z1: -12.1, h: 0.34, d: 0.17, w: 0.15, dir: 'up', sizes: [0.8, 1, 0.9, 1.1, 0.8, 1, 1.2, 1.3, 1.4], c: C.tooth }));

  // Powerful arms with a big thumb claw
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [1.45, 6.6, -2.8], S);
    segBox(A, [1.45, 6.6, -2.8], [1.7, 5.3, -3.5], 0.7, 0.75, { name: 'UpperArm', c: C.bodyLo });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [1.7, 5.3, -3.5], S);
    segBox(F, [1.7, 5.3, -3.5], [1.7, 4.6, -4.6], 0.6, 0.6, { name: 'Forearm', c: C.bodyLo });
    F.box({ name: 'Hand', s: [0.65, 0.45, 0.55], p: [1.7, 4.45, -4.85], c: C.bodyLo });
    claw(F, [1.55, 4.25, -5.15], { s: 0.42, c: C.claw });
    claw(F, [1.85, 4.3, -5.1], { s: 0.3, c: C.claw });
  });
  P.sym((s, side, n) => bipedLeg(rig, s, pelvis, n, { hip: [2.05, 6.5, 1.7], knee: [2.3, 4.1, 0.8], ankle: [2.3, 1.6, 1.8], ball: [2.3, 0.35, 0.95] }, {
    thigh: [1.2, 1.8], shin: [0.9, 1.0], meta: [0.75, 0.75], toeLen: 1.2, toeW: 0.42, toeH: 0.3, muscle: { s: [1.1, 2.3, 2.1], p: [2.4, 5.6, 1.4] }, c: C.body, cLo: C.bodyLo, claw: C.claw,
  }));

  // Paddle tail: tall, laterally flat, finned on top and bottom
  tailChain(rig, P, pelvis, [
    { p: [0, 7.0, 3.2], s: [2.4, 2.4, 2.0], c: [0, 7.0, 4.0] },
    { p: [0, 6.9, 5.0], s: [1.6, 2.0, 2.0], c: [0, 6.9, 5.8] },
    { p: [0, 6.7, 6.8], s: [1.1, 1.8, 2.0], c: [0, 6.7, 7.6] },
    { p: [0, 6.5, 8.6], s: [0.8, 1.6, 1.9], c: [0, 6.5, 9.4] },
    { p: [0, 6.3, 10.3], s: [0.55, 1.3, 1.8], c: [0, 6.3, 11.1] },
  ], { c: C.body, under: C.belly, band: C.navy, studs: false, each: (Tc, d, i) => {
    const fin = 0.6 + i * 0.25;
    Tc.box({ name: 'TailFinTop', s: [0.14, fin, d.s[2] * 0.9], p: [0, d.c[1] + d.s[1] / 2 + fin / 2 - 0.05, d.c[2]], c: C.sail });
    Tc.box({ name: 'TailFinBottom', s: [0.14, fin * 0.6, d.s[2] * 0.8], p: [0, d.c[1] - d.s[1] / 2 - fin * 0.3 + 0.05, d.c[2]], c: C.sailBand });
  } });

  highlight(model);
  return model;
}

module.exports = { build };
