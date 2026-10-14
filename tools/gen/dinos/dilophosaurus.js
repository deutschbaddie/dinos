// DAWN DESERT 03 — DILOPHOSAURUS (Rare). Twin arched display crests that flush bright, a notched upper jaw.
// ~16 studs long, ~7 tall. Forward = -Z. (No neck frill: that was only ever the movies.)
const { makeDino, seg, boneAt, teeth, claw, dorsal, eye, band, highlight, segBox, bipedLeg } = require('./common.js');
const { rng } = require('../builder.js');

const C = {
  body: '#b8c43a', bodyHi: '#ccd84e', bodyLo: '#939d2a', spot: '#3e4a1e', spotLo: '#2f3a16', belly: '#f0e6b0', bellyLo: '#d8cc8e',
  crest: '#e8402a', crestHi: '#ff8f2a', crestStripe: '#fff2dc', eye: '#ffd31a', claw: '#24201a', mouth: '#6a1a20', tongue: '#b84050', tooth: '#f6efd9',
};

function build() {
  const { model, rig } = makeDino('Dilophosaurus', {
    DisplayName: 'Dilophosaurus', Rarity: 'Rare', Classification: 'Crested Predator', Personality: 'Showy, sly, hunts in pairs',
    Locomotion: 'Biped', SignatureMove: 'Crest Flare',
  }, [1.8, 2.0, 4.4], [0, 4.4, 0.2]);
  const S = { c: C.body };
  const R = rng(1904);
  // dark spots scattered over a flank (both sides)
  const spots = (ctx, x, y0, y1, z0, z1, n) => {
    for (let i = 0; i < n; i++) {
      const k = 0.7 + R() * 0.6, y = y0 + R() * (y1 - y0), z = z0 + R() * (z1 - z0);
      ctx.sym((s) => s.box({ name: 'Spot', s: [0.06, 0.28 * k, 0.36 * k], p: [x + 0.02, y, z], c: i % 3 ? C.spot : C.spotLo, shadow: false }));
    }
  };

  // ---------------- Hips ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 4.6, 1.0], S);
  P.box({ name: 'Hip', s: [1.7, 1.8, 1.9], p: [0, 4.65, 1.1], studs: 'top' });
  P.box({ name: 'HipBelly', s: [1.3, 0.22, 1.6], p: [0, 3.7, 1.0], c: C.belly });
  P.box({ name: 'HipRidge', s: [1.3, 0.25, 1.7], p: [0, 5.66, 1.1], c: C.bodyLo });
  spots(P, 0.85, 4.3, 5.3, 0.4, 1.8, 4);
  dorsal(P, [[5.79, 0.6, 1], [5.79, 1.4, 1]], { h: 0.22, d: 0.38, w: 0.2, c: C.spot });

  // ---------------- Body ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 4.6, 0.0], S);
  T.box({ name: 'Chest', s: [1.8, 1.9, 2.6], p: [0, 4.5, -1.2], studs: 'top' });
  T.box({ name: 'ChestFront', s: [1.5, 1.6, 0.6], p: [0, 4.42, -2.75], c: C.bodyLo });
  T.box({ name: 'Belly', s: [1.4, 0.22, 2.5], p: [0, 3.5, -1.25], c: C.belly });
  T.box({ name: 'ChestPlate', s: [1.1, 1.0, 0.1], p: [0, 4.2, -3.08], c: C.belly });
  T.box({ name: 'BackRidge', s: [1.3, 0.25, 2.5], p: [0, 5.57, -1.2], c: C.bodyLo });
  spots(T, 0.9, 4.0, 5.2, -2.4, 0.0, 6);
  dorsal(T, [[5.7, -0.4, 1], [5.7, -1.2, 1], [5.7, -2.0, 0.9]], { h: 0.22, d: 0.38, w: 0.2, c: C.spot });
  T.attach('VFX_Chest', [0, 4.2, -3.2]);

  // ---------------- S-curved neck ----------------
  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 4.85, -2.6], S);
  segBox(N1, [0, 4.85, -2.6], [0, 5.65, -3.3], 1.0, 1.0, { name: 'NeckLower', studs: 'top', extend: 0.45 });
  segBox(N1, [0, 4.5, -2.95], [0, 5.25, -3.6], 0.72, 0.1, { name: 'Throat', c: C.belly, extend: 0.15 });
  N1.sym((s) => s.box({ name: 'Spot', s: [0.06, 0.24, 0.3], p: [0.52, 5.25, -2.9], r: [-45, 0, 0], c: C.spot, shadow: false }));
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 5.65, -3.3], S);
  segBox(N2, [0, 5.65, -3.3], [0, 6.15, -3.82], 0.84, 0.84, { name: 'NeckUpper', extend: 0.4 });
  segBox(N2, [0, 5.32, -3.58], [0, 5.82, -4.08], 0.6, 0.1, { name: 'Throat', c: C.belly, extend: 0.12 });

  // ---------------- Head: notched snout, twin crests ----------------
  const [head, H] = boneAt(rig, N2, 'Head', neck2, [0, 6.15, -3.85], S);
  H.box({ name: 'Cranium', s: [1.0, 0.95, 1.2], p: [0, 6.3, -4.35], studs: 'top' });
  H.box({ name: 'Snout', s: [0.74, 0.6, 1.25], p: [0, 6.12, -5.55] });
  H.wedgeF({ name: 'SnoutSlope', s: [0.74, 0.18, 0.5], p: [0, 6.51, -5.0], face: 'front', c: C.bodyHi });
  // the premaxilla sits a touch lower than the rest of the snout: the famous notch
  H.box({ name: 'SnoutTip', s: [0.62, 0.52, 0.55], p: [0, 6.02, -6.42] });
  H.box({ name: 'Nose', s: [0.52, 0.34, 0.12], p: [0, 6.08, -6.74], c: C.bodyLo });
  H.box({ name: 'MouthInterior', s: [0.56, 0.12, 1.9], p: [0, 5.82, -5.5], c: C.mouth });
  H.box({ name: 'HeadSpot', s: [0.5, 0.06, 0.3], p: [0, 6.78, -4.1], c: C.spot });
  H.sym((s, side, n) => {
    eye(s, [0.52, 6.42, -4.45], { h: 0.22, d: 0.3, c: C.eye, lid: C.bodyLo });
    s.box({ name: 'BrowRidge', s: [0.14, 0.14, 0.46], p: [0.46, 6.64, -4.5], r: [0, 0, -14], c: C.spot });
    s.box({ name: 'Cheek', s: [0.1, 0.36, 0.5], p: [0.5, 6.0, -4.55], c: C.bodyLo });
    s.box({ name: 'UpperLip', s: [0.06, 0.12, 1.3], p: [0.36, 5.87, -5.4], c: C.bodyLo });
    s.box({ name: 'Notch', s: [0.08, 0.2, 0.12], p: [0.3, 5.86, -6.13], c: C.mouth });
    s.box({ name: 'Nostril', s: [0.08, 0.08, 0.16], p: [0.2, 6.2, -6.6], c: '#1a1a10' });
    teeth(s, { n: 6, x: 0.3, y: 5.82, z0: -4.75, z1: -5.95, h: 0.17, d: 0.13, w: 0.08, dir: 'down', sizes: [0.8, 1, 1.15, 0.95, 1.1, 0.85], c: C.tooth });
    teeth(s, { n: 3, x: 0.24, y: 5.78, z0: -6.25, z1: -6.62, h: 0.22, d: 0.13, w: 0.08, dir: 'down', sizes: [1.2, 1, 0.85], c: C.tooth });
    s.attach(`VFX_${n}Eye`, [0.55, 6.42, -4.45]);
  });
  // twin thin arched crests: red plates banded with white, rising off the snout and skull
  const crest = [[-6.05, 0.22, 6.38], [-5.65, 0.52, 6.42], [-5.2, 0.82, 6.5], [-4.75, 0.98, 6.62], [-4.3, 0.82, 6.76], [-3.92, 0.46, 6.76]];
  H.sym((s) => {
    crest.forEach(([z, h, y0], i) => {
      s.box({ name: 'CrestPlate', s: [0.12, h, 0.46], p: [0.2, y0 + h / 2, z], c: i % 2 ? C.crest : C.crestHi });
      s.box({ name: 'CrestStripe', s: [0.14, 0.07, 0.47], p: [0.2, y0 + h * 0.62, z], c: C.crestStripe, shadow: false });
    });
    s.box({ name: 'CrestEdge', s: [0.14, 0.1, 0.8], p: [0.2, 7.58, -4.6], c: C.crestHi });
    s.wedgeF({ name: 'CrestFront', s: [0.12, 0.36, 0.4], p: [0.2, 6.48, -6.4], face: 'front', c: C.crestHi });
    s.wedgeF({ name: 'CrestBack', s: [0.12, 0.5, 0.4], p: [0.2, 7.0, -3.5], face: 'back', c: C.crest });
  });
  H.attach('VFX_Crest', [0, 7.6, -4.9]);
  H.attach('VFX_Mouth', [0, 5.82, -6.8]);
  H.attach('VFX_Head', [0, 6.35, -4.8]);

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 5.8, -4.45], S);
  J.box({ name: 'LowerJaw', s: [0.66, 0.28, 2.25], p: [0, 5.64, -5.6] });
  J.box({ name: 'JawUnderside', s: [0.56, 0.08, 2.1], p: [0, 5.47, -5.55], c: C.belly });
  J.box({ name: 'Tongue', s: [0.34, 0.08, 1.4], p: [0, 5.81, -5.3], c: C.tongue });
  J.sym((s) => teeth(s, { n: 7, x: 0.26, y: 5.78, z0: -4.8, z1: -6.55, h: 0.14, d: 0.11, w: 0.07, dir: 'up', sizes: [0.8, 1.05, 0.95, 1.15, 0.9, 1.05, 0.8], c: C.tooth }));

  // ---------------- Arms (four-fingered, clawed) ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [0.82, 4.05, -2.5], S);
    segBox(A, [0.88, 4.05, -2.5], [1.0, 3.35, -2.7], 0.3, 0.34, { name: 'UpperArm', extend: 0.2 });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [1.0, 3.35, -2.7], S);
    segBox(F, [1.0, 3.35, -2.7], [1.0, 3.0, -3.25], 0.26, 0.26, { name: 'Forearm', extend: 0.15 });
    F.box({ name: 'Hand', s: [0.26, 0.2, 0.26], p: [1.0, 2.95, -3.38], c: C.bodyLo });
    for (const dx of [-0.08, 0, 0.08]) claw(F, [1.0 + dx, 2.88, -3.55], { s: 0.15, c: C.claw });
  });

  // ---------------- Legs ----------------
  P.sym((s, side, n) => {
    const L = bipedLeg(rig, s, pelvis, n, { hip: [0.9, 4.4, 1.1], knee: [1.05, 2.7, 0.28], ankle: [1.05, 1.15, 1.15], ball: [1.05, 0.3, 0.5] }, {
      thigh: [0.85, 1.15], shin: [0.56, 0.6], meta: [0.42, 0.45], toeLen: 0.75, toeW: 0.26, toeH: 0.28,
      muscle: { s: [0.72, 1.3, 1.15], p: [1.12, 3.75, 0.85], studs: 'top' }, c: C.body, cLo: C.bodyLo, claw: C.claw,
    });
    L.ctx[0].box({ name: 'Spot', s: [0.06, 0.3, 0.36], p: [1.5, 3.8, 0.7], c: C.spot, shadow: false });
  });

  // ---------------- Tail ----------------
  const tailDefs = [
    { p: [0, 4.85, 2.0], s: [1.36, 1.36, 1.5], c: [0, 4.85, 2.7] },
    { p: [0, 4.8, 3.4], s: [1.06, 1.06, 1.5], c: [0, 4.75, 4.1] },
    { p: [0, 4.7, 4.8], s: [0.8, 0.8, 1.5], c: [0, 4.62, 5.5] },
    { p: [0, 4.55, 6.2], s: [0.55, 0.55, 1.45], c: [0, 4.47, 6.88] },
    { p: [0, 4.4, 7.55], s: [0.36, 0.36, 1.3], c: [0, 4.33, 8.15] },
  ];
  let parent = pelvis, pc = P;
  tailDefs.forEach((d, i) => {
    const [tb, Tc] = boneAt(rig, pc, `Tail${i + 1}`, parent, d.p, S);
    Tc.box({ name: 'TailSegment', s: d.s, p: d.c, studs: 'top' });
    Tc.box({ name: 'TailUnderside', s: [d.s[0] * 0.72, 0.08, d.s[2] * 0.9], p: [0, d.c[1] - d.s[1] / 2 - 0.03, d.c[2]], c: C.belly });
    if (i < 4) Tc.sym((s) => s.box({ name: 'Spot', s: [0.05, d.s[1] * 0.3, d.s[2] * 0.25], p: [d.s[0] / 2 + 0.02, d.c[1] + d.s[1] * 0.12, d.c[2] + (i % 2 ? 0.25 : -0.2)], c: C.spot, shadow: false }));
    dorsal(Tc, [[d.c[1] + d.s[1] / 2, d.c[2] - d.s[2] * 0.15, 0.9 - i * 0.12]], { h: 0.22, d: 0.36, w: 0.2, c: C.spot });
    if (i === 4) Tc.attach('VFX_TailTip', [0, 4.3, 8.8]);
    parent = tb; pc = Tc;
  });

  highlight(model);
  return model;
}

module.exports = { build };
