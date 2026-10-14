// FROST FOREST — PSITTACOSAURUS (Common). The cute starter: a chunky little biped with a big boxy parrot head,
// a hooked amber beak, dark cheek horns and chin, countershaded camouflage (dark back fading to a cream belly,
// Vinther et al. 2016) and a crest of quill bristles on the tail that rattles to call the herd.
// ~6.4 studs long, ~3 tall. Forward = -Z.
const { makeDino, seg, boneAt, claw, eye, band, highlight, bipedLeg } = require('./common.js');

const C = {
  body: '#a8642e', bodyHi: '#bd7a3e', bodyLo: '#8a4f22', back: '#5a3519', backLo: '#47290f', flank: '#cf9a5c',
  belly: '#f4e4c0', bellyLo: '#e3cfa2', beak: '#f0a43a', beakLo: '#c97a1e', horn: '#33241a', chin: '#3a2a1e',
  eye: '#d98f2c', mouth: '#7a2a2a', tongue: '#d0606a', quill: '#f2e3c2', quillTip: '#3a2414', claw: '#3a2a1e',
};

function build() {
  const { model, rig } = makeDino('Psittacosaurus', {
    DisplayName: 'Psittacosaurus', Rarity: 'Common', Classification: 'Herd Dinosaur', Personality: 'Shy, curious, sociable',
    Locomotion: 'Biped', SignatureMove: 'Hide and Squeak',
  }, [1.0, 1.0, 2.2], [0, 1.5, 0.1]);
  const S = { c: C.body };

  // ---------------- Pelvis / torso (countershaded: dark saddle, warm flanks, cream belly) ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 1.55, 0.4], S);
  P.box({ name: 'Hip', s: [1.12, 1.0, 1.15], p: [0, 1.62, 0.45], studs: 'top' });
  P.box({ name: 'BackSaddle', s: [0.96, 0.2, 1.08], p: [0, 2.2, 0.45], c: C.back, studs: 'top' });
  P.box({ name: 'FlankLight', s: [1.16, 0.26, 1.0], p: [0, 1.24, 0.45], c: C.flank });
  P.box({ name: 'HipBelly', s: [0.86, 0.12, 0.98], p: [0, 1.07, 0.42], c: C.belly });
  P.sym((s) => {
    s.box({ name: 'CamoSpot', s: [0.06, 0.2, 0.3], p: [0.58, 1.86, 0.2], c: C.back });
    s.box({ name: 'CamoSpot', s: [0.06, 0.14, 0.2], p: [0.58, 1.72, 0.72], c: C.backLo });
  });

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 1.6, -0.1], S);
  T.box({ name: 'Body', s: [1.18, 1.06, 1.15], p: [0, 1.66, -0.6], studs: 'top' });
  T.box({ name: 'BackSaddle', s: [1.0, 0.2, 1.1], p: [0, 2.26, -0.58], c: C.back, studs: 'top' });
  T.box({ name: 'FlankLight', s: [1.22, 0.26, 1.0], p: [0, 1.26, -0.6], c: C.flank });
  T.box({ name: 'Belly', s: [0.92, 0.12, 1.04], p: [0, 1.09, -0.62], c: C.belly });
  T.box({ name: 'ChestPlate', s: [0.8, 0.62, 0.12], p: [0, 1.5, -1.2], c: C.belly });
  T.sym((s) => {
    s.box({ name: 'CamoSpot', s: [0.06, 0.24, 0.34], p: [0.6, 1.95, -0.42], c: C.back });
    s.box({ name: 'CamoSpot', s: [0.06, 0.16, 0.22], p: [0.6, 1.78, -0.92], c: C.backLo });
  });
  T.attach('VFX_Chest', [0, 1.45, -1.3]);

  // ---------------- Neck / head ----------------
  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 1.9, -1.05], S);
  const Nf = N.at([0, 1.9, -1.05], [-22, 0, 0]);
  Nf.box({ name: 'Neck', s: [0.78, 0.72, 0.66], p: [0, 0.22, -0.05], studs: 'top' });
  Nf.box({ name: 'NeckSaddle', s: [0.66, 0.14, 0.56], p: [0, 0.6, 0.02], c: C.back });
  Nf.box({ name: 'Throat', s: [0.56, 0.6, 0.08], p: [0, 0.12, -0.4], c: C.belly });

  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 2.3, -1.45], S);
  H.box({ name: 'Cranium', s: [0.98, 0.74, 0.86], p: [0, 2.55, -1.72], studs: 'top' });
  H.box({ name: 'HeadCap', s: [0.8, 0.12, 0.7], p: [0, 2.96, -1.7], c: C.back, studs: 'top' });
  H.box({ name: 'Face', s: [0.84, 0.6, 0.46], p: [0, 2.44, -2.3], c: C.bodyHi });
  H.wedgeF({ name: 'Brow', s: [0.84, 0.18, 0.4], p: [0, 2.82, -2.25], face: 'front', c: C.body });
  // the parrot beak: a deep upper bill with a hooked tip
  H.box({ name: 'Beak', s: [0.56, 0.36, 0.32], p: [0, 2.32, -2.66], c: C.beak });
  H.wedgeF({ name: 'BeakTop', s: [0.56, 0.2, 0.32], p: [0, 2.6, -2.62], face: 'front', c: C.beak });
  H.wedgeF({ name: 'BeakHook', s: [0.5, 0.3, 0.2], p: [0, 2.0, -2.74], face: 'front', flip: true, c: C.beakLo });
  H.box({ name: 'MouthInterior', s: [0.5, 0.08, 0.5], p: [0, 2.2, -2.3], c: C.mouth });
  H.sym((s, side, n) => {
    eye(s, [0.49, 2.58, -1.9], { h: 0.36, d: 0.38, c: C.eye, lid: C.body });
    s.box({ name: 'BrowRidge', s: [0.12, 0.1, 0.4], p: [0.46, 2.8, -1.88], r: [0, 0, -14], c: C.back });
    // dark jugal "cheek horns" flaring out and down
    s.box({ name: 'CheekHorn', s: [0.34, 0.24, 0.32], p: [0.6, 2.2, -1.86], r: [0, 0, -28], c: C.horn });
    s.wedgeF({ name: 'CheekHornTip', s: [0.2, 0.2, 0.22], p: [0.8, 2.07, -1.86], r: [0, 0, -28], face: 'right', c: C.horn });
    s.box({ name: 'Cheek', s: [0.08, 0.26, 0.4], p: [0.43, 2.26, -2.24], c: C.bodyLo });
    s.box({ name: 'Nostril', s: [0.06, 0.06, 0.1], p: [0.22, 2.58, -2.56], c: '#2a1a10' });
    s.attach(`VFX_${n}Eye`, [0.53, 2.6, -1.88]);
  });
  H.attach('VFX_Head', [0, 2.6, -1.95]);
  H.attach('VFX_Mouth', [0, 2.12, -2.9]);

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 2.16, -1.75], S);
  J.box({ name: 'LowerJaw', s: [0.7, 0.24, 0.62], p: [0, 2.04, -2.2], c: C.chin });
  J.box({ name: 'LowerBeak', s: [0.44, 0.2, 0.3], p: [0, 2.0, -2.62], c: C.chin });
  J.box({ name: 'Tongue', s: [0.3, 0.06, 0.36], p: [0, 2.17, -2.2], c: C.tongue });
  J.box({ name: 'ChinPatch', s: [0.6, 0.06, 0.5], p: [0, 1.9, -2.15], c: C.horn });

  // ---------------- Arms (short, four-fingered) ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [0.58, 1.48, -0.95], S);
    A.box({ name: 'UpperArm', s: [0.22, 0.46, 0.26], p: [0.64, 1.28, -1.0], r: [12, 0, 0], c: C.bodyLo });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [0.66, 1.07, -1.06], S);
    F.box({ name: 'Forearm', s: [0.2, 0.38, 0.2], p: [0.66, 0.92, -1.16], r: [-30, 0, 0], c: C.bodyLo });
    F.box({ name: 'Hand', s: [0.24, 0.12, 0.22], p: [0.66, 0.78, -1.28], c: C.bodyLo });
    for (const dx of [-0.07, 0.07]) claw(F, [0.66 + dx, 0.72, -1.4], { s: 0.11, c: C.claw });
  });

  // ---------------- Legs ----------------
  P.sym((s, side, n) => bipedLeg(rig, s, pelvis, n, { hip: [0.56, 1.52, 0.45], knee: [0.7, 0.88, 0.02], ankle: [0.7, 0.44, 0.52], ball: [0.7, 0.12, 0.16] }, {
    thigh: [0.5, 0.74], shin: [0.32, 0.36], meta: [0.25, 0.25], toeLen: 0.34, toeW: 0.13, toeH: 0.13,
    muscle: { s: [0.4, 0.46, 0.52], p: [0.7, 1.32, 0.4], c: C.bodyHi }, c: C.body, cLo: C.bodyLo, claw: C.claw,
  }));

  // ---------------- Tail (with the quill bristles on their own bones so they can flare and rattle) ----------------
  const tail = [
    { p: [0, 1.7, 1.0], s: [0.86, 0.8, 0.72], c: [0, 1.7, 1.34] },
    { p: [0, 1.66, 1.66], s: [0.66, 0.62, 0.7], c: [0, 1.66, 1.98] },
    { p: [0, 1.6, 2.3], s: [0.48, 0.46, 0.68], c: [0, 1.6, 2.62] },
    { p: [0, 1.52, 2.92], s: [0.34, 0.32, 0.62], c: [0, 1.52, 3.2] },
    { p: [0, 1.44, 3.48], s: [0.22, 0.22, 0.54], c: [0, 1.44, 3.72] },
  ];
  let parent = pelvis, pc = P;
  tail.forEach((d, i) => {
    const [tb, Tc] = boneAt(rig, pc, `Tail${i + 1}`, parent, d.p, S);
    Tc.box({ name: 'TailSegment', s: d.s, p: d.c, studs: 'top' });
    Tc.box({ name: 'TailSaddle', s: [d.s[0] * 0.8, Math.min(0.14, d.s[1] * 0.2), d.s[2] * 0.94], p: [0, d.c[1] + d.s[1] / 2 + 0.05, d.c[2]], c: C.back });
    Tc.box({ name: 'TailUnderside', s: [d.s[0] * 0.72, 0.08, d.s[2] * 0.9], p: [0, d.c[1] - d.s[1] / 2 - 0.03, d.c[2]], c: C.belly });
    if (i >= 2) band(Tc, [0, d.c[1] + d.s[1] * 0.12, d.c[2] + d.s[2] * 0.2], [d.s[0] + 0.05, d.s[1] * 0.7, d.s[2] * 0.26], { c: C.back });
    if (i < 2) {
      // quill bristles: cream shafts with dark tips, leaning back
      const top = d.c[1] + d.s[1] / 2 + 0.12;
      const [qb, Q] = boneAt(rig, Tc, `Quills${i + 1}`, tb, [0, top, d.c[2] - d.s[2] * 0.45], S);
      const n = 5;
      for (let k = 0; k < n; k++) {
        const z = d.c[2] - d.s[2] * 0.4 + (k / (n - 1)) * d.s[2] * 0.85;
        const h = (i === 0 ? 0.9 : 0.75) * (0.8 + 0.25 * Math.sin((k + i * n) * 0.9 + 1));
        const q = Q.at([0, top, z], [-34, 0, (k % 2 ? 6 : -6)]);
        q.box({ name: 'Quill', s: [0.09, h, 0.09], p: [0, h / 2, 0], c: C.quill });
        q.box({ name: 'QuillTip', s: [0.09, 0.16, 0.1], p: [0, h + 0.04, 0], c: C.quillTip });
      }
      if (i === 0) Q.attach('VFX_Crest', [0, top + 0.6, d.c[2] + 0.2]);
    }
    if (i === tail.length - 1) Tc.attach('VFX_TailTip', [0, d.c[1], d.c[2] + d.s[2] / 2]);
    parent = tb; pc = Tc;
  });

  highlight(model);
  return model;
}

module.exports = { build };
