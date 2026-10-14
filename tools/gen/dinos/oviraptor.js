// RED CLIFFS 01 — OVIRAPTOR (Uncommon). The "egg thief" (who was really guarding its own eggs).
// ~6 studs long, ~4.4 tall to the top of its casque. Teal/indigo body, cream belly, banded arm fans + tail fan,
// a toothless parrot beak under a tall rounded orange-red casque. Forward = -Z.
const { makeDino, seg, boneAt, claw, eye, band, highlight, segBox, bipedLeg, tailChain } = require('./common.js');

const C = {
  teal: '#2a8fa3', tealHi: '#3cabbd', tealLo: '#1f6c7d', indigo: '#3c3f99', indigoLo: '#2b2d70', indigoHi: '#5054b8',
  cream: '#f2e4c2', creamLo: '#dccaa0', casque: '#ff5a24', casqueHi: '#ff8c3a', casqueLo: '#d23e18',
  beak: '#625a78', beakLo: '#4a4360', beakHi: '#8a82a0', eye: '#ffd23a', band: '#ffb02e', leg: '#4f5a80', legLo: '#3d4668', claw: '#231f2c',
  mouth: '#7a2a3a', tongue: '#d0607a',
};

// one long banded feather: a thin vane hanging from p (local), pointing along -Y, with an orange band near the tip
function feather(ctx, p, len, o = {}) {
  const f = ctx.at(p, o.r || [0, 0, 0]);
  const w = o.w || 0.2;
  f.box({ name: 'FanFeather', s: [0.07, len, w], p: [0, -len / 2, 0], c: o.c || C.indigo });
  f.box({ name: 'FeatherBand', s: [0.11, len * 0.16, w + 0.02], p: [0, -len * 0.72, 0], c: o.band || C.band, shadow: false });
  f.box({ name: 'FeatherTip', s: [0.1, len * 0.14, w * 0.8], p: [0, -len * 0.93, 0], c: o.tip || C.indigoLo, shadow: false });
}

function build() {
  const { model, rig } = makeDino('Oviraptor', {
    DisplayName: 'Oviraptor', Rarity: 'Uncommon', Classification: 'Small Omnivore', Personality: 'Sneaky, nosy, a fierce parent',
    Locomotion: 'Biped', SignatureMove: 'Egg Heist',
  }, [1.2, 1.3, 2.4], [0, 2.0, 0]);
  const S = { c: C.teal };

  // ---------------- Pelvis ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 2.0, 0.3], S);
  P.box({ name: 'Hip', s: [1.1, 0.9, 1.1], p: [0, 2.05, 0.35], studs: 'top' });
  P.box({ name: 'HipTop', s: [0.92, 0.2, 0.96], p: [0, 2.58, 0.35], c: C.indigo, studs: 'top' });
  P.box({ name: 'HipBelly', s: [0.9, 0.14, 0.95], p: [0, 1.56, 0.3], c: C.cream });
  band(P, [0, 2.35, 0.12], [1.14, 0.36, 0.16], { c: C.indigo });
  band(P, [0, 2.35, 0.58], [1.14, 0.36, 0.16], { c: C.indigo });
  P.sym((s) => s.wedgeF({ name: 'HipTuft', s: [0.1, 0.36, 0.5], p: [0.57, 1.86, 0.62], face: 'back', flip: true, c: C.tealLo }));

  // ---------------- Torso ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 2.05, -0.2], S);
  T.box({ name: 'Chest', s: [1.2, 1.1, 1.2], p: [0, 2.08, -0.5], studs: 'top' });
  T.box({ name: 'ChestFront', s: [1.0, 0.95, 0.4], p: [0, 2.02, -1.2] });
  T.box({ name: 'BackRidge', s: [0.94, 0.2, 1.3], p: [0, 2.72, -0.5], c: C.indigo, studs: 'top' });
  T.box({ name: 'Belly', s: [1.0, 0.15, 1.25], p: [0, 1.46, -0.55], c: C.cream });
  // fluffy cream bib: a pale chest with a fringe of little feather tufts
  T.box({ name: 'ChestPlume', s: [0.84, 0.7, 0.1], p: [0, 1.92, -1.44], c: C.cream });
  for (const x of [-0.26, 0, 0.26]) T.wedgeF({ name: 'ChestTuft', s: [0.24, 0.26, 0.14], p: [x, 1.46, -1.38], face: 'front', flip: true, c: x ? C.creamLo : C.cream });
  band(T, [0, 2.38, -0.25], [1.24, 0.42, 0.16], { c: C.indigo });
  band(T, [0, 2.38, -0.75], [1.24, 0.42, 0.16], { c: C.indigo });
  T.sym((s) => s.box({ name: 'Shoulder', s: [0.14, 0.36, 0.42], p: [0.6, 1.95, -1.0], c: C.tealLo }));
  T.attach('VFX_Chest', [0, 1.85, -1.5]);

  // ---------------- Neck (short, S-curved, with a feather ruff) ----------------
  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 2.3, -1.15], S);
  segBox(N1, [0, 2.3, -1.15], [0, 2.98, -1.42], 0.64, 0.62, { name: 'NeckLower' });
  N1.box({ name: 'Throat', s: [0.46, 0.7, 0.08], p: [0, 2.55, -1.62], r: [-20, 0, 0], c: C.cream });
  for (const [y, z, k] of [[2.62, -0.98, 1], [2.9, -1.12, 0.85]]) N1.wedgeF({ name: 'NeckRuff', s: [0.56 * k, 0.34 * k, 0.4 * k], p: [0, y, z], face: 'back', c: C.indigo });
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 2.95, -1.42], S);
  segBox(N2, [0, 2.95, -1.42], [0, 3.36, -1.6], 0.56, 0.54, { name: 'NeckUpper' });
  N2.box({ name: 'Throat', s: [0.4, 0.42, 0.08], p: [0, 3.1, -1.72], c: C.cream });
  N2.wedgeF({ name: 'NeckRuff', s: [0.48, 0.3, 0.36], p: [0, 3.22, -1.3], face: 'back', c: C.indigo });

  // ---------------- Head: deep, short, parrot beak, tall casque ----------------
  const [head, H] = boneAt(rig, N2, 'Head', neck2, [0, 3.35, -1.6], S);
  H.box({ name: 'Cranium', s: [0.78, 0.66, 0.82], p: [0, 3.48, -1.86], studs: 'top' });
  H.box({ name: 'Face', s: [0.64, 0.62, 0.55], p: [0, 3.4, -2.48] });
  H.box({ name: 'CheekPatch', s: [0.82, 0.3, 0.5], p: [0, 3.3, -1.9], c: C.indigo });
  H.box({ name: 'UpperBeak', s: [0.48, 0.34, 0.3], p: [0, 3.25, -2.86], c: C.beak });
  H.wedgeF({ name: 'BeakHook', s: [0.42, 0.26, 0.22], p: [0, 2.95, -2.9], face: 'back', flip: true, c: C.beakLo });
  H.wedgeF({ name: 'BeakTop', s: [0.46, 0.18, 0.3], p: [0, 3.51, -2.86], face: 'front', c: C.beakHi });
  H.box({ name: 'MouthInterior', s: [0.42, 0.12, 0.62], p: [0, 3.06, -2.42], c: C.mouth });
  // the casque: a tall rounded crest rising straight off the snout, leaning back, with a pale blaze
  H.box({ name: 'Casque', s: [0.32, 0.78, 0.66], p: [0, 4.02, -2.36], c: C.casque });
  H.box({ name: 'Casque', s: [0.3, 0.3, 0.5], p: [0, 4.56, -2.26], c: C.casque });
  H.wedgeF({ name: 'Casque', s: [0.32, 0.78, 0.3], p: [0, 4.02, -2.84], face: 'front', c: C.casque });
  H.wedgeF({ name: 'Casque', s: [0.3, 0.3, 0.22], p: [0, 4.56, -2.62], face: 'front', c: C.casque });
  H.wedgeF({ name: 'Casque', s: [0.3, 0.3, 0.26], p: [0, 4.56, -1.88], face: 'back', c: C.casqueLo });
  H.wedgeF({ name: 'Casque', s: [0.32, 0.5, 0.36], p: [0, 3.88, -1.85], face: 'back', c: C.casqueLo });
  H.box({ name: 'CasqueBlaze', s: [0.36, 0.5, 0.12], p: [0, 4.08, -2.56], c: C.casqueHi, shadow: false });
  H.box({ name: 'CasqueBlaze', s: [0.34, 0.16, 0.36], p: [0, 4.73, -2.26], c: C.casqueHi, shadow: false });
  H.sym((s, side, n) => {
    eye(s, [0.4, 3.56, -2.0], { h: 0.2, d: 0.28, r: [0, -6, 0], c: C.eye, lid: C.tealLo });
    s.box({ name: 'BrowRidge', s: [0.14, 0.1, 0.38], p: [0.37, 3.72, -2.0], r: [0, -6, -12], c: C.indigoLo });
    s.box({ name: 'Nostril', s: [0.06, 0.06, 0.1], p: [0.26, 3.36, -2.98], c: '#14111c' });
    s.box({ name: 'Cheek', s: [0.1, 0.24, 0.34], p: [0.36, 3.2, -2.25], c: C.tealLo });
    s.wedgeF({ name: 'HeadFeather', s: [0.08, 0.26, 0.34], p: [0.24, 3.84, -1.5], face: 'back', r: [0, 0, -10], c: C.indigo });
    s.attach(`VFX_${n}Eye`, [0.44, 3.56, -2.0]);
  });
  H.attach('VFX_Mouth', [0, 3.0, -3.08]);
  H.attach('VFX_Head', [0, 3.5, -2.15]);
  H.attach('VFX_Crest', [0, 4.45, -2.25]);

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 3.1, -1.85], S);
  J.box({ name: 'LowerJaw', s: [0.5, 0.18, 0.7], p: [0, 2.98, -2.28], c: C.tealLo });
  J.box({ name: 'LowerBeak', s: [0.44, 0.2, 0.36], p: [0, 2.98, -2.72], c: C.beak });
  J.wedgeF({ name: 'LowerBeakTip', s: [0.4, 0.16, 0.18], p: [0, 3.0, -2.98], face: 'front', c: C.beakLo });
  J.box({ name: 'JawUnderside', s: [0.42, 0.06, 0.8], p: [0, 2.87, -2.3], c: C.cream });
  J.box({ name: 'Tongue', s: [0.24, 0.05, 0.44], p: [0, 3.07, -2.3], c: C.tongue });

  // ---------------- Arms with banded feather fans ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [0.58, 1.98, -0.98], S);
    segBox(A, [0.58, 1.98, -0.98], [0.68, 1.45, -0.86], 0.24, 0.26, { name: 'UpperArm' });
    A.box({ name: 'ArmFeathers', s: [0.1, 0.42, 0.34], p: [0.74, 1.66, -0.84], c: C.indigo });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [0.68, 1.45, -0.86], S);
    segBox(F, [0.68, 1.45, -0.86], [0.68, 1.28, -1.62], 0.2, 0.2, { name: 'Forearm' });
    F.box({ name: 'Hand', s: [0.17, 0.14, 0.26], p: [0.68, 1.24, -1.76], c: C.tealLo });
    for (const dx of [-0.06, 0.06]) claw(F, [0.68 + dx, 1.18, -1.92], { s: 0.14, c: C.claw });
    claw(F, [0.62, 1.22, -1.64], { s: 0.11, c: C.claw, r: [0, 30, 0] });
    // the fan: long banded feathers off the trailing edge of the forearm + hand, longest at the wrist
    [[-0.88, 0.62], [-1.05, 0.78], [-1.22, 0.92], [-1.39, 1.02], [-1.56, 1.04], [-1.72, 0.94]].forEach(([z, len], i) => feather(F, [0.76 + (i % 2) * 0.05, 1.42 + (z + 0.88) * 0.2, z], len, { w: 0.24, r: [-20 - i * 5, 0, 0], c: i % 2 ? C.indigo : C.indigoHi }));
    F.attach(`VFX_${n}Claw`, [0.68, 1.14, -1.96]);
  });

  // ---------------- Legs ----------------
  P.sym((s, side, n) => {
    const L = bipedLeg(rig, s, pelvis, n, { hip: [0.55, 2.0, 0.3], knee: [0.64, 1.25, -0.12], ankle: [0.64, 0.62, 0.42], ball: [0.64, 0.12, 0.08] }, {
      thigh: [0.5, 0.66], shin: [0.26, 0.3], meta: [0.2, 0.2], toeLen: 0.42, toeW: 0.13, toeH: 0.13,
      muscle: { s: [0.46, 0.62, 0.7], p: [0.62, 1.78, 0.22] }, c: C.teal, cLo: C.leg, claw: C.claw,
    });
    band(L.ctx[0], [0.62, 1.86, 0.22], [0.5, 0.16, 0.74], { c: C.indigo });
    L.ctx[0].wedgeF({ name: 'ThighTuft', s: [0.36, 0.26, 0.3], p: [0.66, 1.36, 0.38], face: 'back', flip: true, c: C.tealLo });
  });

  // ---------------- Tail with a banded display fan ----------------
  const tail = tailChain(rig, P, pelvis, [
    { p: [0, 2.12, 0.86], s: [0.8, 0.68, 0.76], c: [0, 2.14, 1.2] },
    { p: [0, 2.18, 1.55], s: [0.6, 0.54, 0.72], c: [0, 2.2, 1.88] },
    { p: [0, 2.24, 2.2], s: [0.44, 0.42, 0.66], c: [0, 2.27, 2.5] },
    { p: [0, 2.32, 2.78], s: [0.3, 0.3, 0.5], c: [0, 2.34, 3.0] },
  ], { c: C.teal, under: C.cream, band: C.indigo, studs: false });
  const T4 = tail.ctxs[3];
  const fan = T4.at([0, 2.4, 3.14], [24, 0, 0]);
  [-56, -28, 0, 28, 56].forEach((a, i) => {
    const len = i === 2 ? 1.25 : (i === 1 || i === 3) ? 1.15 : 0.98;
    feather(fan.at([0, 0, (i - 2) * 0.045], [0, 0, 180 + a]), [0, 0, 0], len, { w: 0.24, c: i % 2 ? C.indigoHi : C.indigo, r: [0, 90, 0] });
  });
  T4.box({ name: 'FanBase', s: [0.4, 0.3, 0.3], p: [0, 2.38, 3.18], c: C.indigoLo });

  highlight(model, '#121226', 0.45);
  return model;
}

module.exports = { build };
