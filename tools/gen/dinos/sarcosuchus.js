// SARCOSUCHUS (Epic) — the "SuperCroc". Patient, ancient, lurking. ~31 studs long, ~4.5 tall. Sprawling quadruped
// that swims: low and wide, heavy rows of back osteoderms, a long narrow snout ending in the bulbous bulla, and
// yellow slit eyes raised on top of the skull so it can float with only eyes, nostrils and back ridge awash.
// Real animal: ~9-9.5 m (older estimates 11-12 m), Early Cretaceous ~112 Ma, Niger (Elrhaz Formation).
const { makeDino, seg, boneAt, teeth, eye, band, highlight, segBox, quadLeg, tailChain } = require('./common.js');

const C = {
  body: '#5e6f2e', bodyHi: '#71833b', bodyLo: '#4a5722', dark: '#2a3018', scute: '#3f4321', scuteHi: '#66633a',
  keel: '#2f3419', belly: '#d8cf98', bellyLo: '#c4b981', bulla: '#5f5130', bullaHi: '#77653a',
  eye: '#ffd21a', mouth: '#c8735f', mouthDark: '#8a3a32', tongue: '#e09a82', tooth: '#f4ecd6', claw: '#2a2418',
};

function build() {
  const { model, rig } = makeDino('Sarcosuchus', {
    DisplayName: 'Sarcosuchus', Rarity: 'Epic', Classification: 'Giant Crocodyliform', Personality: 'Patient, ancient, lurking',
    Locomotion: 'Quadruped', SignatureMove: 'Log That Isn\'t',
  }, [3.6, 2.2, 9], [0, 2.5, -2.4]);
  const S = { c: C.body };

  // osteoderm armour: paired keeled plates down the spine, a lower lateral row on each flank
  const scutes = (ctx, z0, z1, yTop, o = {}) => {
    const step = o.step || 0.95;
    let row = 0;
    for (let z = z0; z >= z1 - 1e-6; z -= step, row++) {
      const k = o.k ? o.k(z) : 1;
      ctx.sym((s) => {
        s.box({ name: 'Osteoderm', s: [0.88 * k, 0.24, 0.78], p: [0.5 * k, yTop + 0.12, z], c: row % 2 ? C.scute : C.scuteHi, studs: 'top' });
        s.wedgeF({ name: 'ScuteKeel', s: [0.2, 0.3 * k, 0.66], p: [0.5 * k, yTop + 0.39, z], face: 'back', c: C.keel });
        if (o.lateral !== false && row % 2 === 0) s.box({ name: 'FlankScute', s: [0.7 * k, 0.22, 0.7], p: [(o.latX || 1.38) * k, yTop + 0.02, z], r: [0, 0, -10], c: C.scute });
      });
    }
  };

  // ------------------------------------------------ pelvis (hips) — the root of the body roll
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 2.5, 0.4], S);
  P.box({ name: 'Hips', s: [3.9, 2.2, 4.2], p: [0, 2.5, 0.5], studs: 'top' });
  P.box({ name: 'HipBelly', s: [3.3, 0.25, 4.0], p: [0, 1.39, 0.5], c: C.belly });
  P.sym((s) => s.box({ name: 'FlankLine', s: [0.08, 0.5, 4.0], p: [1.96, 2.0, 0.5], c: C.bodyLo, shadow: false }));
  scutes(P, 2.2, -1.3, 3.6, { latX: 1.5 });

  // ------------------------------------------------ torso (barrel)
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 2.55, -1.6], S);
  T.box({ name: 'Body', s: [4.2, 2.3, 6.0], p: [0, 2.55, -4.5], studs: 'top' });
  T.box({ name: 'Belly', s: [3.6, 0.25, 5.8], p: [0, 1.39, -4.5], c: C.belly });
  T.box({ name: 'Chest', s: [3.6, 1.8, 0.7], p: [0, 2.35, -7.7], c: C.bodyLo });
  T.sym((s) => {
    s.box({ name: 'FlankLine', s: [0.08, 0.5, 5.8], p: [2.11, 2.0, -4.5], c: C.bodyLo, shadow: false });
    for (const z of [-2.6, -4.4, -6.2]) s.box({ name: 'FlankKnob', s: [0.22, 0.34, 0.6], p: [2.15, 2.75, z], c: C.dark });
  });
  scutes(T, -2.25, -7.0, 3.7, { latX: 1.62 });
  T.attach('VFX_Chest', [0, 1.6, -7.9]);

  // ------------------------------------------------ neck (short, thick, nuchal shield)
  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 2.5, -7.9], S);
  N.box({ name: 'Neck', s: [3.2, 1.95, 1.9], p: [0, 2.45, -8.75], studs: 'top' });
  N.box({ name: 'Throat', s: [2.4, 0.25, 1.8], p: [0, 1.4, -8.75], c: C.belly });
  N.sym((s) => {
    s.box({ name: 'NuchalPlate', s: [0.9, 0.3, 0.85], p: [0.55, 3.55, -8.7], c: C.scuteHi, studs: 'top' });
    s.wedgeF({ name: 'ScuteKeel', s: [0.22, 0.36, 0.7], p: [0.55, 3.86, -8.7], face: 'back', c: C.keel });
  });

  // ------------------------------------------------ head: broad skull, raised eye turrets, long narrow snout, bulla
  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 2.4, -9.6], S);
  H.box({ name: 'Cranium', s: [2.7, 1.3, 2.3], p: [0, 2.6, -10.75], studs: 'top' });
  H.box({ name: 'SkullTable', s: [2.1, 0.2, 1.3], p: [0, 3.35, -10.3], c: C.bodyLo });
  H.wedgeF({ name: 'SnoutSlope', s: [2.1, 0.55, 1.2], p: [0, 2.98, -12.45], face: 'front', c: C.body });
  H.box({ name: 'SnoutBase', s: [1.9, 0.95, 1.2], p: [0, 2.28, -12.45] });
  H.box({ name: 'Snout', s: [1.2, 0.85, 3.4], p: [0, 2.3, -14.7] });
  H.box({ name: 'SnoutRidge', s: [0.7, 0.16, 3.6], p: [0, 2.8, -14.5], c: C.bodyHi });
  // the bulla: Sarcosuchus' bulbous snout tip
  H.box({ name: 'SnoutTip', s: [1.42, 0.85, 1.25], p: [0, 2.3, -17.0], c: C.bodyLo });
  H.box({ name: 'Bulla', s: [1.15, 0.42, 1.05], p: [0, 2.92, -17.0], c: C.bulla, studs: 'top' });
  H.box({ name: 'BullaCap', s: [0.8, 0.12, 0.7], p: [0, 3.18, -17.0], c: C.bullaHi });
  H.box({ name: 'Palate', s: [1.0, 0.15, 6.0], p: [0, 1.95, -14.3], c: C.mouth });
  H.box({ name: 'MouthBack', s: [1.8, 0.7, 0.4], p: [0, 2.25, -11.6], c: C.mouthDark });
  H.sym((s, side, n) => {
    // eye turret on top of the head, eye looking out and up
    s.box({ name: 'EyeTurret', s: [0.75, 0.5, 1.0], p: [0.62, 3.5, -11.0], c: C.bodyHi, studs: 'top' });
    eye(s, [1.0, 3.5, -11.0], { h: 0.42, d: 0.6, c: C.eye, lid: C.bodyLo, r: [0, 0, 28] });
    s.box({ name: 'Brow', s: [0.5, 0.16, 1.1], p: [0.72, 3.82, -11.0], r: [0, 0, -14], c: C.dark });
    s.box({ name: 'Nostril', s: [0.22, 0.08, 0.32], p: [0.22, 3.27, -17.05], c: '#141810' });
    s.box({ name: 'CheekScale', s: [0.14, 0.4, 0.9], p: [1.36, 2.55, -10.9], c: C.dark });
    // upper teeth hang outside the lower jaw (interlocking with the lower row, staggered)
    teeth(s, { n: 8, x: 0.64, y: 1.9, z0: -11.5, z1: -16.0, h: 0.4, d: 0.2, w: 0.14, dir: 'down', sizes: [0.8, 1, 0.9, 1.1, 0.9, 1, 1.15, 1.05], c: C.tooth });
    teeth(s, { n: 2, x: 0.74, y: 1.9, z0: -16.6, z1: -17.4, h: 0.55, d: 0.24, w: 0.16, dir: 'down', c: C.tooth });
    s.attach(`VFX_${n}Eye`, [1.05, 3.5, -11.0]);
  });
  H.attach('VFX_Mouth', [0, 2.0, -17.8]);
  H.attach('VFX_Head', [0, 3.1, -11.9]);
  H.attach('VFX_Crest', [0, 3.6, -11.0]); // between the eyes: the "eyes at the waterline" target

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 1.95, -10.2], S);
  J.box({ name: 'JawBack', s: [2.1, 0.65, 1.55], p: [0, 1.6, -11.2] });
  J.box({ name: 'LowerJaw', s: [1.1, 0.5, 5.4], p: [0, 1.62, -14.55] });
  J.box({ name: 'JawTip', s: [1.3, 0.55, 1.15], p: [0, 1.6, -17.0], c: C.bodyLo });
  J.box({ name: 'JawUnderside', s: [0.9, 0.12, 6.8], p: [0, 1.32, -14.4], c: C.belly });
  J.box({ name: 'Tongue', s: [0.75, 0.1, 3.4], p: [0, 1.9, -13.3], c: C.tongue });
  J.box({ name: 'GularPouch', s: [1.7, 0.12, 1.4], p: [0, 1.26, -11.25], c: C.bellyLo });
  J.sym((s) => {
    teeth(s, { n: 8, x: 0.6, y: 1.86, z0: -11.8, z1: -16.3, h: 0.38, d: 0.2, w: 0.14, dir: 'up', sizes: [0.9, 1.1, 0.85, 1, 1.15, 0.9, 1.05, 1.2], c: C.tooth });
    teeth(s, { n: 1, x: 0.68, y: 1.86, z0: -17.25, z1: -17.25, h: 0.55, d: 0.24, w: 0.16, dir: 'up', c: C.tooth });
  });

  // ------------------------------------------------ legs: semi-sprawled (the "high walk"), webbed hind feet
  P.sym((s, side, n) => quadLeg(rig, s, pelvis, n, 'Hind', { hip: [1.55, 2.15, 1.0], knee: [2.4, 1.2, 0.45], ankle: [2.5, 0.38, 0.7] }, {
    upper: [1.0, 1.1], lower: [0.72, 0.78], foot: [1.3, 0.36, 1.5], footZ: -0.35, toes: 4, c: C.bodyLo, cLo: C.bodyLo, claw: C.claw,
    muscle: { s: [1.3, 1.25, 1.7], p: [1.95, 2.1, 0.9] },
  }));
  T.sym((s, side, n) => quadLeg(rig, s, torso, n, 'Front', { hip: [1.6, 2.0, -6.6], knee: [2.35, 1.2, -6.15], ankle: [2.45, 0.36, -6.55] }, {
    upper: [0.85, 0.9], lower: [0.68, 0.72], foot: [1.15, 0.34, 1.2], footZ: -0.2, toes: 4, c: C.bodyLo, cLo: C.bodyLo, claw: C.claw,
    muscle: { s: [1.0, 1.0, 1.2], p: [1.85, 1.95, -6.5] },
  }));

  // ------------------------------------------------ tail: thick at the base, flattened side to side, double crest
  tailChain(rig, P, pelvis, [
    { p: [0, 2.5, 2.6], s: [2.9, 2.0, 2.15], c: [0, 2.45, 3.68] },
    { p: [0, 2.4, 4.75], s: [2.25, 1.75, 2.1], c: [0, 2.35, 5.8] },
    { p: [0, 2.3, 6.85], s: [1.65, 1.5, 2.05], c: [0, 2.25, 7.88] },
    { p: [0, 2.2, 8.9], s: [1.15, 1.3, 2.0], c: [0, 2.15, 9.9] },
    { p: [0, 2.1, 10.9], s: [0.8, 1.1, 1.9], c: [0, 2.05, 11.85] },
    { p: [0, 2.0, 12.8], s: [0.55, 0.9, 1.8], c: [0, 1.95, 13.7] },
  ], { c: C.body, under: C.belly, band: C.dark, each: (Tc, d, i) => {
    const top = d.c[1] + d.s[1] / 2;
    const h = 0.42 + i * 0.05;
    if (i < 3) Tc.sym((s) => s.wedgeF({ name: 'TailCrest', s: [0.2, h, d.s[2] * 0.75], p: [d.s[0] * 0.28, top + h / 2, d.c[2]], face: 'back', c: C.keel }));
    else Tc.wedgeF({ name: 'TailCrest', s: [0.22, h, d.s[2] * 0.8], p: [0, top + h / 2, d.c[2]], face: 'back', c: C.keel });
  } });

  highlight(model, '#12160a', 0.45);
  return model;
}

module.exports = { build };
