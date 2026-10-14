// DAWN DESERT RULER — POSTOSUCHUS (Legendary). Not a dinosaur: a croc-line archosaur that ruled before them.
// Walks semi-upright on four pillar legs, can stand up on its hind legs. Deep toothy skull, armoured back.
// ~22 studs long, ~8 tall. Forward = -Z.
const { makeDino, seg, boneAt, teeth, dorsal, eye, band, highlight, segBox, quadLeg, tailChain } = require('./common.js');

const C = {
  body: '#a33d2c', bodyHi: '#bd5038', bodyLo: '#82301f', scute: '#55201a', scuteHi: '#6e2b20', belly: '#d6a882', bellyLo: '#bf8e68',
  eye: '#ffd21a', tooth: '#f6efdc', toothLo: '#e4d8bc', mouth: '#4a1012', tongue: '#a8404a', nail: '#2a1a16', mask: '#3a1612',
};

function build() {
  const { model, rig } = makeDino('Postosuchus', {
    DisplayName: 'Postosuchus', Rarity: 'Legendary', Classification: 'Ancient Apex', Personality: 'Patient, brutal, older than the dinosaurs',
    Locomotion: 'Quadruped', SignatureMove: 'Before The Dinosaurs',
  }, [3, 2.8, 6], [0, 5.0, 0.8]);
  const S = { c: C.body };
  // paired armour scutes along the back: two rows, a keel on each
  const scutes = (ctx, y, z0, z1, n, w = 1) => {
    for (let i = 0; i < n; i++) {
      const z = n === 1 ? z0 : z0 + (z1 - z0) * (i / (n - 1));
      ctx.sym((s) => {
        s.box({ name: 'Scute', s: [0.62 * w, 0.24, 0.72], p: [0.38 * w, y + 0.1, z], c: i % 2 ? C.scute : C.scuteHi, studs: 'top' });
        s.wedgeF({ name: 'ScuteKeel', s: [0.16, 0.2, 0.5], p: [0.38 * w, y + 0.32, z + 0.05], face: 'front', c: C.scute });
      });
    }
  };

  // ---------------- Hips ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 5.4, 3.2], S);
  P.box({ name: 'Hip', s: [2.8, 2.6, 3.0], p: [0, 5.5, 3.3], studs: 'top' });
  P.box({ name: 'HipBelly', s: [2.2, 0.3, 2.6], p: [0, 4.12, 3.2], c: C.belly });
  scutes(P, 6.8, 2.2, 4.4, 3);

  // ---------------- Body ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 5.3, 1.6], S);
  T.box({ name: 'Body', s: [3.1, 2.8, 4.6], p: [0, 5.1, -0.6], studs: 'top' });
  T.box({ name: 'Shoulders', s: [2.8, 2.5, 1.3], p: [0, 4.85, -3.4], c: C.bodyLo });
  T.box({ name: 'Belly', s: [2.5, 0.3, 4.4], p: [0, 3.62, -0.7], c: C.belly });
  T.box({ name: 'Chest', s: [2.2, 1.4, 0.2], p: [0, 4.2, -4.1], c: C.belly });
  for (let i = 0; i < 4; i++) T.box({ name: 'BellyScale', s: [2.2, 0.1, 0.12], p: [0, 3.46, 0.6 - i * 0.9], c: C.bellyLo, shadow: false });
  T.sym((s) => {
    s.box({ name: 'FlankScale', s: [0.1, 0.5, 3.6], p: [1.57, 5.6, -0.6], c: C.bodyHi, shadow: false });
    s.box({ name: 'FlankScale', s: [0.1, 0.3, 3.0], p: [1.57, 4.7, -0.4], c: C.bodyLo, shadow: false });
  });
  scutes(T, 6.5, 1.2, -3.4, 6);
  T.attach('VFX_Chest', [0, 4.3, -4.2]);

  // ---------------- Thick neck ----------------
  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 5.3, -3.9], S);
  segBox(N, [0, 5.3, -3.9], [0, 5.9, -5.0], 2.0, 2.0, { name: 'Neck', studs: 'top', extend: 0.8 });
  scutes(N, 6.25, -4.15, -4.75, 2, 0.85);

  // ---------------- Deep, toothy skull ----------------
  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 5.95, -5.1], S);
  H.box({ name: 'Cranium', s: [2.0, 2.1, 2.0], p: [0, 6.35, -6.0], studs: 'top' });
  H.box({ name: 'SkullCap', s: [1.6, 0.25, 1.7], p: [0, 7.5, -5.95], c: C.bodyLo, studs: 'top' });
  H.box({ name: 'Snout', s: [1.7, 1.6, 2.1], p: [0, 6.1, -7.95] });
  H.wedgeF({ name: 'SnoutSlope', s: [1.7, 0.5, 1.2], p: [0, 7.15, -7.6], face: 'front', c: C.bodyHi });
  H.box({ name: 'SnoutFront', s: [1.45, 1.4, 1.3], p: [0, 6.0, -9.6] });
  H.wedgeF({ name: 'NoseSlope', s: [1.45, 0.4, 0.8], p: [0, 6.9, -9.5], face: 'front', c: C.bodyHi });
  H.box({ name: 'NoseTip', s: [1.3, 1.1, 0.3], p: [0, 6.0, -10.38], c: C.bodyLo });
  H.box({ name: 'Palate', s: [1.4, 0.2, 4.1], p: [0, 5.22, -8.0], c: C.mouth });
  H.box({ name: 'Throat', s: [1.4, 0.8, 0.5], p: [0, 5.45, -5.6], c: C.mouth });
  H.box({ name: 'HeadMask', s: [2.04, 0.5, 0.6], p: [0, 6.95, -6.55], c: C.mask });
  H.sym((s, side, n) => {
    s.box({ name: 'BrowRidge', s: [0.5, 0.42, 1.2], p: [0.82, 7.32, -6.3], r: [0, -6, -12], c: C.scute, studs: 'top' });
    eye(s, [1.02, 6.88, -6.25], { h: 0.32, d: 0.42, c: C.eye, lid: C.bodyLo });
    s.box({ name: 'Fenestra', s: [0.1, 0.55, 0.9], p: [0.86, 6.45, -7.6], c: C.mask });
    s.box({ name: 'JawMuscle', s: [0.24, 1.1, 1.3], p: [1.0, 5.85, -5.7], c: C.bodyLo });
    s.box({ name: 'UpperLip', s: [0.1, 0.3, 4.3], p: [0.74, 5.42, -8.1], c: C.bodyLo });
    s.box({ name: 'Nostril', s: [0.14, 0.14, 0.24], p: [0.42, 6.62, -10.3], c: '#140808' });
    s.box({ name: 'SnoutScale', s: [0.08, 0.36, 0.5], p: [0.86, 6.3, -8.5], c: C.bodyLo, shadow: false });
    s.box({ name: 'SnoutScale', s: [0.08, 0.3, 0.4], p: [0.74, 6.25, -9.6], c: C.bodyLo, shadow: false });
    teeth(s, { n: 9, x: 0.72, y: 5.3, z0: -6.4, z1: -10.1, h: 0.42, d: 0.3, w: 0.2, dir: 'down', sizes: [0.75, 1.0, 1.3, 1.1, 1.45, 1.0, 1.25, 1.05, 0.9], c: C.tooth });
    teeth(s, { n: 6, x: 0.32, y: 5.3, z0: -6.8, z1: -9.6, h: 0.26, d: 0.2, w: 0.14, dir: 'down', sizes: [0.9, 1.1, 1, 1.15, 1, 0.9], c: C.toothLo });
    s.attach(`VFX_${n}Eye`, [1.08, 6.88, -6.25]);
  });
  for (const x of [-0.35, 0.35]) H.wedgeF({ name: 'Tooth', s: [0.2, 0.5, 0.26], p: [x, 5.07, -10.3], face: 'front', flip: true, c: C.tooth, shadow: false });
  H.attach('VFX_Mouth', [0, 5.2, -10.5]);
  H.attach('VFX_Head', [0, 6.5, -7.2]);

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 5.3, -5.6], S);
  J.box({ name: 'LowerJaw', s: [1.3, 0.8, 4.3], p: [0, 4.92, -7.95] });
  J.box({ name: 'Chin', s: [1.2, 0.7, 0.4], p: [0, 4.95, -10.2], c: C.bodyLo });
  J.box({ name: 'JawUnderside', s: [1.1, 0.16, 4.2], p: [0, 4.46, -8.0], c: C.belly });
  J.box({ name: 'JawHinge', s: [1.9, 0.9, 0.9], p: [0, 5.0, -5.8], c: C.bodyLo });
  J.box({ name: 'Tongue', s: [0.8, 0.14, 2.6], p: [0, 5.36, -7.7], c: C.tongue });
  J.sym((s) => {
    s.box({ name: 'LowerLip', s: [0.1, 0.24, 4.2], p: [0.6, 4.95, -8.0], c: C.bodyLo });
    teeth(s, { n: 8, x: 0.46, y: 5.32, z0: -6.6, z1: -9.9, h: 0.36, d: 0.26, w: 0.18, dir: 'up', sizes: [0.8, 1.15, 1.0, 1.35, 1.05, 1.2, 0.95, 0.85], c: C.tooth });
  });
  for (const x of [-0.3, 0.3]) J.wedgeF({ name: 'Tooth', s: [0.18, 0.42, 0.22], p: [x, 5.5, -10.2], face: 'front', c: C.tooth, shadow: false });

  // ---------------- Pillar legs (semi-upright, hind longer) ----------------
  const legStyle = { toes: 4, c: C.body, cLo: C.bodyLo, claw: C.nail };
  P.sym((s, side, n) => {
    const L = quadLeg(rig, s, pelvis, n, 'Hind', { hip: [1.45, 5.0, 3.4], knee: [1.65, 3.0, 2.5], ankle: [1.65, 1.0, 3.3] }, Object.assign({
      upper: [1.35, 1.6], lower: [1.0, 1.05], foot: [1.4, 0.55, 2.1], footZ: -0.55, muscle: { s: [1.1, 2.2, 2.0], p: [1.62, 4.55, 3.2] },
    }, legStyle));
    L.ctx[0].box({ name: 'ThighScute', s: [0.14, 0.5, 0.9], p: [2.19, 4.7, 3.2], c: C.scute });
  });
  T.sym((s, side, n) => {
    const L = quadLeg(rig, s, torso, n, 'Front', { hip: [1.4, 4.3, -3.2], knee: [1.6, 2.55, -2.85], ankle: [1.6, 0.85, -3.3] }, Object.assign({
      upper: [1.1, 1.15], lower: [0.85, 0.88], foot: [1.15, 0.5, 1.5], footZ: -0.4, muscle: { s: [0.9, 1.5, 1.2], p: [1.55, 3.85, -3.15] },
    }, legStyle));
    L.ctx[2].attach(`VFX_${n}Claw`, [1.6, 0.2, -4.2]);
  });

  // ---------------- Tail (scuted) ----------------
  tailChain(rig, P, pelvis, [
    { p: [0, 5.6, 4.7], s: [2.2, 2.0, 1.9], c: [0, 5.5, 5.6] },
    { p: [0, 5.3, 6.5], s: [1.7, 1.55, 1.8], c: [0, 5.15, 7.35] },
    { p: [0, 4.9, 8.2], s: [1.25, 1.15, 1.7], c: [0, 4.72, 9.0] },
    { p: [0, 4.45, 9.8], s: [0.85, 0.8, 1.5], c: [0, 4.28, 10.5] },
    { p: [0, 4.0, 11.2], s: [0.52, 0.5, 1.3], c: [0, 3.85, 11.8] },
  ], {
    c: C.body, under: C.belly, studs: false,
    each: (Tc, d, i) => {
      if (i < 4) {
        const w = d.s[0] / 2.4;
        Tc.sym((s) => s.box({ name: 'Scute', s: [0.5 * w + 0.1, 0.2, d.s[2] * 0.7], p: [0.3 * w + 0.05, d.c[1] + d.s[1] / 2 + 0.08, d.c[2]], c: i % 2 ? C.scute : C.scuteHi, studs: 'top' }));
      } else dorsal(Tc, [[d.c[1] + d.s[1] / 2, d.c[2], 0.8]], { h: 0.22, d: 0.4, w: 0.2, c: C.scute });
      Tc.sym((s) => s.box({ name: 'TailBand', s: [0.08, d.s[1] * 0.5, d.s[2] * 0.3], p: [d.s[0] / 2 + 0.02, d.c[1] + d.s[1] * 0.1, d.c[2] + d.s[2] * 0.2], c: C.mask, shadow: false }));
    },
  });

  highlight(model);
  return model;
}

module.exports = { build };
