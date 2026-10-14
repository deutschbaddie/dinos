// FROST FOREST — MICRORAPTOR (Rare). A tiny four-winged glider: glossy black plumage with a blue-teal
// iridescent sheen (Li et al. 2012), big gold eyes, a crest tuft, wing panels on the arms AND the legs,
// a long tail ending in a feather fan. ~4.5 studs long, ~2 tall. Forward = -Z.
// Wings are built folded along the flanks; Arm [0, 1.4, -1.57] (Right; ~Arm mirrors) spreads them flat.
const { makeDino, seg, boneAt, teeth, claw, eye, highlight, bipedLeg } = require('./common.js');

const C = {
  black: '#222840', blackHi: '#2f3854', blackLo: '#14182a', belly: '#3b4460',
  teal: '#27c6d8', tealLo: '#1a8fa6', blue: '#3a6cf0', violet: '#5c4fd8',
  eye: '#ffcf2e', mouth: '#7a2030', tongue: '#c25566', tooth: '#f4ecd6', claw: '#e6dcc6',
};
const G = { refl: 0.08 }; // a touch of gloss on the feathers

function build() {
  const { model, rig } = makeDino('Microraptor', {
    DisplayName: 'Microraptor', Rarity: 'Rare', Classification: 'Four-Winged Glider', Personality: 'Twitchy, sly, show-off',
    Locomotion: 'Biped', SignatureMove: 'Shadow Glide',
  }, [0.6, 0.6, 1.4], [0, 1.0, 0]);
  const S = { c: C.black };

  // ---------------- Pelvis / torso ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 1.0, 0.15], S);
  P.box(Object.assign({ name: 'Hip', s: [0.48, 0.48, 0.55], p: [0, 1.02, 0.2], studs: 'top' }, G));
  P.box({ name: 'HipBelly', s: [0.38, 0.06, 0.48], p: [0, 0.75, 0.18], c: C.belly });
  P.box({ name: 'Sheen', s: [0.2, 0.06, 0.5], p: [0, 1.29, 0.2], c: C.teal });

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 1.02, -0.1], S);
  T.box(Object.assign({ name: 'Chest', s: [0.54, 0.54, 0.62], p: [0, 1.06, -0.4], studs: 'top' }, G));
  T.box({ name: 'ChestFluff', s: [0.42, 0.42, 0.14], p: [0, 1.0, -0.76], c: C.blackHi });
  T.box({ name: 'Belly', s: [0.42, 0.06, 0.56], p: [0, 0.77, -0.4], c: C.belly });
  T.box({ name: 'Sheen', s: [0.22, 0.06, 0.58], p: [0, 1.36, -0.38], c: C.teal });
  T.box({ name: 'Sheen', s: [0.1, 0.05, 0.4], p: [0, 1.4, -0.36], c: C.blue });
  T.attach('VFX_Chest', [0, 0.98, -0.84]);

  // ---------------- Neck / head ----------------
  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 1.2, -0.66], S);
  const Nf = N.at([0, 1.2, -0.66], [-30, 0, 0]);
  Nf.box(Object.assign({ name: 'Neck', s: [0.3, 0.56, 0.32], p: [0, 0.24, 0] }, G));
  Nf.box({ name: 'NeckRuff', s: [0.36, 0.22, 0.34], p: [0, 0.02, 0.02], c: C.blackHi });
  Nf.box({ name: 'Throat', s: [0.22, 0.42, 0.05], p: [0, 0.22, -0.17], c: C.belly });

  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 1.62, -0.9], S);
  H.box(Object.assign({ name: 'Cranium', s: [0.46, 0.4, 0.48], p: [0, 1.76, -1.04], studs: 'top' }, G));
  H.box({ name: 'Snout', s: [0.3, 0.2, 0.44], p: [0, 1.7, -1.48], c: C.blackHi });
  H.wedgeF({ name: 'SnoutSlope', s: [0.3, 0.12, 0.32], p: [0, 1.86, -1.4], face: 'front', c: C.blackHi });
  H.box({ name: 'NoseTip', s: [0.24, 0.16, 0.08], p: [0, 1.69, -1.72], c: C.blackHi });
  H.box({ name: 'MouthInterior', s: [0.22, 0.06, 0.42], p: [0, 1.6, -1.42], c: C.mouth });
  H.box({ name: 'Sheen', s: [0.2, 0.05, 0.3], p: [0, 1.98, -1.02], c: C.teal });
  H.sym((s, side, n) => {
    eye(s, [0.235, 1.8, -1.12], { h: 0.17, d: 0.2, c: C.eye, lid: C.blackHi });
    s.box({ name: 'BrowFeather', s: [0.1, 0.06, 0.24], p: [0.2, 1.93, -1.12], r: [0, -8, -18], c: C.blackLo });
    s.box({ name: 'Cheek', s: [0.06, 0.14, 0.24], p: [0.22, 1.66, -1.0], c: C.blackHi });
    s.box({ name: 'Nostril', s: [0.05, 0.04, 0.06], p: [0.08, 1.75, -1.7], c: '#05060a' });
    teeth(s, { n: 4, x: 0.11, y: 1.6, z0: -1.3, z1: -1.66, h: 0.06, d: 0.05, w: 0.04, dir: 'down', c: C.tooth });
    s.attach(`VFX_${n}Eye`, [0.27, 1.8, -1.12]);
  });
  // crest tuft: three swept-back feathers, the tallest tipped teal
  for (const [x, h, z, rz, c] of [[0, 0.34, -0.92, 0, C.blue], [0.08, 0.24, -0.9, -14, C.blackHi], [-0.08, 0.24, -0.9, 14, C.blackHi]]) {
    H.wedgeF({ name: 'CrestFeather', s: [0.06, h, 0.26], p: [x, 1.96 + h / 2, z], r: [-18, 0, rz], face: 'back', c });
  }
  H.attach('VFX_Head', [0, 1.78, -1.15]);
  H.attach('VFX_Mouth', [0, 1.62, -1.76]);
  H.attach('VFX_Crest', [0, 2.2, -0.88]);

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 1.62, -0.98], S);
  J.box({ name: 'LowerJaw', s: [0.26, 0.09, 0.56], p: [0, 1.56, -1.38], c: C.blackHi });
  J.box({ name: 'JawUnderside', s: [0.2, 0.04, 0.5], p: [0, 1.51, -1.36], c: C.belly });
  J.box({ name: 'Tongue', s: [0.12, 0.03, 0.3], p: [0, 1.61, -1.32], c: C.tongue });
  J.sym((s) => teeth(s, { n: 3, x: 0.1, y: 1.6, z0: -1.34, z1: -1.6, h: 0.05, d: 0.045, w: 0.035, dir: 'up', c: C.tooth }));

  // ---------------- Wings (arms), folded along the flanks ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [0.26, 1.15, -0.62], S);
    A.box(Object.assign({ name: 'UpperArm', s: [0.12, 0.16, 0.4], p: [0.32, 1.12, -0.46] }, G));
    A.box({ name: 'Shoulder', s: [0.13, 0.25, 0.27], p: [0.3, 1.19, -0.6], c: C.blackHi });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [0.34, 1.1, -0.3], S);
    // three stepped feather tiers, black coverts -> blue secondaries -> teal-tipped primaries (the iridescence)
    F.box(Object.assign({ name: 'WingCovert', s: [0.08, 0.2, 0.76], p: [0.37, 1.22, 0.02], studs: 'top' }, G));
    F.wedgeF(Object.assign({ name: 'WingCovert', s: [0.07, 0.2, 0.22], p: [0.37, 1.22, 0.51], face: 'back', flip: true, c: C.black }, G));
    F.box(Object.assign({ name: 'WingFeather', s: [0.07, 0.16, 0.9], p: [0.39, 1.05, 0.15], c: C.blackHi }, G));
    F.wedgeF(Object.assign({ name: 'Sheen', s: [0.06, 0.16, 0.26], p: [0.39, 1.05, 0.73], face: 'back', flip: true, c: C.blue }, G));
    F.box(Object.assign({ name: 'WingPrimary', s: [0.06, 0.15, 1.02], p: [0.41, 0.9, 0.3], c: C.blue }, G));
    F.wedgeF({ name: 'Sheen', s: [0.06, 0.15, 0.34], p: [0.41, 0.9, 0.98], face: 'back', flip: true, c: C.teal });
    F.box({ name: 'Wrist', s: [0.1, 0.12, 0.14], p: [0.33, 1.02, -0.38], c: C.blackHi });
    for (const dz of [-0.04, 0.05]) claw(F, [0.33, 0.96, -0.46 + dz], { s: 0.09, c: C.claw });
    if (n === 'Right') F.attach('VFX_RightClaw', [0.33, 0.95, -0.5]);
    F.attach(`VFX_${n}WingTip`, [0.41, 0.9, 1.12]);
  });

  // ---------------- Legs (with the hind-wing feather panels) ----------------
  P.sym((s, side, n) => {
    const L = bipedLeg(rig, s, pelvis, n, { hip: [0.2, 0.98, 0.15], knee: [0.24, 0.6, -0.06], ankle: [0.24, 0.3, 0.2], ball: [0.24, 0.05, 0.02] }, {
      thigh: [0.22, 0.28], shin: [0.13, 0.15], meta: [0.1, 0.1], toeLen: 0.2, toeW: 0.07, toeH: 0.07, c: C.black, cLo: C.blackHi, claw: C.claw,
    });
    const [, Sh, Fo] = L.ctx;
    Sh.box(Object.assign({ name: 'LegFeather', s: [0.05, 0.3, 0.36], p: [0.3, 0.46, 0.22], r: [-25, 0, 0], c: C.black }, G));
    Sh.wedgeF({ name: 'LegFeather', s: [0.05, 0.3, 0.2], p: [0.3, 0.38, 0.47], r: [-25, 0, 0], face: 'back', flip: true, c: C.blackHi });
    Sh.box({ name: 'Sheen', s: [0.06, 0.05, 0.3], p: [0.31, 0.6, 0.2], r: [-25, 0, 0], c: C.teal });
    Fo.box(Object.assign({ name: 'LegFeather', s: [0.05, 0.12, 0.34], p: [0.3, 0.2, 0.38], r: [-10, 0, 0], c: C.black }, G));
    Fo.wedgeF({ name: 'LegFeather', s: [0.05, 0.12, 0.16], p: [0.3, 0.19, 0.62], r: [-10, 0, 0], face: 'back', flip: true, c: C.blue });
  });

  // ---------------- Tail with the feather fan ----------------
  const tail = [
    { p: [0, 1.05, 0.45], s: [0.32, 0.28, 0.56], c: [0, 1.06, 0.72] },
    { p: [0, 1.07, 1.0], s: [0.24, 0.21, 0.56], c: [0, 1.07, 1.27] },
    { p: [0, 1.08, 1.55], s: [0.17, 0.15, 0.56], c: [0, 1.08, 1.82] },
    { p: [0, 1.09, 2.1], s: [0.12, 0.11, 0.5], c: [0, 1.09, 2.35] },
  ];
  let parent = pelvis, pc = P;
  tail.forEach((d, i) => {
    const [tb, Tc] = boneAt(rig, pc, `Tail${i + 1}`, parent, d.p, S);
    Tc.box(Object.assign({ name: 'TailSegment', s: d.s, p: d.c, studs: i < 2 ? 'top' : undefined }, G));
    if (i < 3) Tc.box({ name: 'Sheen', s: [d.s[0] * 0.4, 0.04, d.s[2] * 0.7], p: [0, d.c[1] + d.s[1] / 2 + 0.02, d.c[2]], c: C.blue });
    if (i >= 2) {
      // paired vane feathers along the distal tail
      Tc.sym((q) => q.box(Object.assign({ name: 'TailVane', s: [0.22, 0.03, 0.12], p: [d.s[0] / 2 + 0.1, d.c[1], d.c[2] + 0.12], r: [0, -30, 0], c: C.black }, G)));
    }
    if (i === 3) {
      // the frond: a broad diamond fan of seven feathers, teal at the tips
      [[-48, 0.62], [-32, 0.8], [-16, 0.94], [0, 1.0], [16, 0.94], [32, 0.8], [48, 0.62]].forEach(([ry, k], j) => {
        const f = Tc.at([0, 1.09 + (3 - Math.abs(j - 3)) * 0.022, 2.5], [0, ry, 0]);
        f.box(Object.assign({ name: 'TailFan', s: [0.13, 0.05, 0.62 * k], p: [0, 0, 0.31 * k], c: Math.abs(ry) > 20 ? C.blackHi : C.black }, G));
        f.wedgeF({ name: 'Sheen', s: [0.13, 0.05, 0.22], p: [0, 0, 0.62 * k + 0.11], face: 'back', flip: true, c: Math.abs(ry) > 20 ? C.blue : C.teal });
      });
      Tc.attach('VFX_TailTip', [0, 1.09, 3.3]);
    }
    parent = tb; pc = Tc;
  });

  highlight(model);
  return model;
}

module.exports = { build };
