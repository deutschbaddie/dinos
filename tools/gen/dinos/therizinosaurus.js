// RED CLIFFS RULER — THERIZINOSAURUS (Legendary). The scythe lizard: a pot-bellied, long-necked plant-eater with the
// longest claws of any land animal. ~27 studs long, ~17 tall. Dark olive with shaggy rust feather tufts on the arms and
// neck, a small beaked head, three huge cream scythe claws on each hand. Forward = -Z.
const { makeDino, seg, boneAt, claw, eye, band, highlight, segBox, bipedLeg, tailChain } = require('./common.js');
const { rng } = require('../builder.js');

const C = {
  olive: '#5d6236', oliveHi: '#737a44', oliveLo: '#474a28', oliveDk: '#363a1e',
  rust: '#b45a28', rustHi: '#d27434', rustLo: '#86421c', belly: '#c8b888', bellyLo: '#a99a6c',
  claw: '#f0e3c4', clawLo: '#d8c79e', clawTip: '#b9a274', beak: '#2e2a24', beakHi: '#4a443a', eye: '#ffc83a',
  leg: '#4c4f2c', legLo: '#3b3d22', toe: '#2a261e', mouth: '#6a2a24',
};

// a shaggy feather tuft hanging down/back from p (a wedge, slope underneath)
function tuft(ctx, p, s, c, r = [0, 0, 0]) {
  return ctx.wedgeF({ name: 'FeatherTuft', s, p, r, face: 'back', flip: true, c });
}

// one scythe claw: three tapering segments from the knuckle, sweeping down, then curling back at the tip
function scythe(ctx, base, k, name) {
  const p1 = [base[0], base[1] - 1.3 * k, base[2] - 1.4 * k];
  const p2 = [base[0], p1[1] - 1.7 * k, p1[2] - 0.3 * k];
  const p3 = [base[0], p2[1] - 1.2 * k, p2[2] + 0.95 * k];
  ctx.box({ name: 'ClawKnuckle', s: [0.66, 0.6, 0.66], p: base, c: C.oliveLo });
  segBox(ctx, base, p1, 0.62, 0.8, { name, c: C.claw, extend: 0.3 });
  segBox(ctx, p1, p2, 0.48, 0.62, { name, c: C.clawLo, extend: 0.24 });
  segBox(ctx, p2, p3, 0.3, 0.4, { name: name + 'Tip', c: C.clawTip, extend: 0.14 });
  return p3;
}

function build() {
  const { model, rig } = makeDino('Therizinosaurus', {
    DisplayName: 'Therizinosaurus', Rarity: 'Legendary', Classification: 'Giant Herbivore', Personality: 'Gentle until cornered, then terrifying',
    Locomotion: 'Biped', SignatureMove: 'Scythe Harvest',
  }, [4.5, 5, 9], [0, 8.5, 0]);
  const S = { c: C.olive };
  const R = rng(1414);

  // ---------------- Pelvis: wide hips ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 8.6, 2.2], S);
  P.box({ name: 'Hip', s: [4.6, 4.0, 4.4], p: [0, 8.8, 2.4], studs: 'top' });
  P.box({ name: 'HipTop', s: [3.8, 0.5, 3.8], p: [0, 11.05, 2.4], c: C.oliveLo, studs: 'top' });
  for (const z of [1.4, 3.4]) band(P, [0, 10.0, z], [4.66, 1.0, 0.5], { c: C.oliveDk });
  for (let i = 0; i < 4; i++) tuft(P, [0, 11.5, 0.9 + i * 1.0], [2.15 - i * 0.2, 0.72, 1.0], i % 2 ? C.rust : C.rustLo);
  P.sym((s) => { for (let i = 0; i < 3; i++) tuft(s, [2.4, 9.6 - i * 0.2, 1.2 + i * 1.1], [0.4, 1.1, 1.0], i % 2 ? C.rustLo : C.rust, [0, 0, -8]); });

  // ---------------- Torso: rising up to the shoulders ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 9.4, 0.4], S);
  const Tt = T.at([0, 10.4, -1.2], [40, 0, 0]);
  Tt.box({ name: 'Body', s: [4.8, 4.6, 5.4], p: [0, 0, 0], studs: 'top' });
  Tt.box({ name: 'BackTop', s: [3.8, 0.5, 4.8], p: [0, 2.5, 0.1], c: C.oliveLo, studs: 'top' });
  for (const z of [-1.6, 0, 1.6]) band(Tt, [0, 1.25, z], [4.86, 1.2, 0.5], { c: C.oliveDk });
  for (let i = 0; i < 4; i++) tuft(Tt, [0, 2.9 + (i % 2) * 0.05, -1.9 + i * 1.25], [2.5 - (i % 2) * 0.1, 0.55, 1.2], i % 2 ? C.rust : C.rustHi);
  T.box({ name: 'Shoulders', s: [4.4, 3.0, 2.4], p: [0, 12.5, -3.3], c: C.oliveLo, studs: 'top' });
  T.sym((s) => { for (let i = 0; i < 4; i++) s.box({ name: 'SideScale', s: [0.14, 0.5 + R() * 0.4, 0.8 + R() * 0.4], p: [2.42, 9.2 + R() * 2.0, -0.4 - R() * 2.6], c: C.oliveDk, shadow: false }); });
  T.attach('VFX_Chest', [0, 10.4, -4.8]);

  // the pot belly on its own bone, so breathing and roars can swell it
  const [chest, Ch] = boneAt(rig, T, 'Chest', torso, [0, 8.4, -1.0], S);
  Ch.box({ name: 'Belly', s: [4.9, 4.0, 5.2], p: [0, 7.4, -1.0], c: C.belly });
  Ch.box({ name: 'BellyFront', s: [4.1, 3.4, 1.2], p: [0, 8.7, -3.9], c: C.belly });
  for (let i = 0; i < 4; i++) Ch.box({ name: 'BellyFold', s: [4.5 - i * 0.2, 0.3, 1.0], p: [0, 5.45 + i * 0.12, 0.9 - i * 1.25], c: i % 2 ? C.bellyLo : C.belly });
  Ch.box({ name: 'Breast', s: [3.4, 1.6, 0.4], p: [0, 10.3, -4.62], c: C.bellyLo });

  // ---------------- Long shaggy neck ----------------
  const neck = (ctx, a, b, w, i) => {
    segBox(ctx, a, b, w, w, { name: 'Neck', studs: 'top' });
    const m = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2];
    segBox(ctx, [m[0], m[1] - 0.2, m[2] - w * 0.48], [m[0], m[1] + 0.4, m[2] - w * 0.48 - 0.3], w * 0.75, 0.12, { name: 'Throat', c: C.belly });
    tuft(ctx, [0, m[1] + w * 0.5, m[2] + w * 0.25], [w * 0.9, 0.7, 1.3], i % 2 ? C.rust : C.rustHi, [-30, 0, 0]);
    ctx.sym((s) => tuft(s, [w * 0.5, m[1] - 0.1, m[2] + 0.2], [0.35, w * 0.7, 1.0], i % 2 ? C.rustLo : C.rust, [-30, 0, -6]));
  };
  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 13.3, -3.9], S);
  neck(N1, [0, 13.3, -3.9], [0, 14.9, -4.9], 2.4, 0);
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 14.9, -4.9], S);
  neck(N2, [0, 14.9, -4.9], [0, 16.3, -5.9], 2.0, 1);
  const [neck3, N3] = boneAt(rig, N2, 'Neck3', neck2, [0, 16.3, -5.9], S);
  neck(N3, [0, 16.3, -5.9], [0, 17.2, -7.0], 1.7, 2);

  // ---------------- Head: small, beaked ----------------
  const [head, H0] = boneAt(rig, N3, 'Head', neck3, [0, 17.2, -7.0], S);
  const H = H0.at([0, 1.7, 1.6]); // head authored at its old spot, lifted onto the taller neck
  H.box({ name: 'Cranium', s: [1.7, 1.4, 1.8], p: [0, 15.95, -9.2], studs: 'top' });
  H.box({ name: 'Snout', s: [1.2, 1.0, 1.5], p: [0, 15.65, -10.6] });
  H.wedgeF({ name: 'SnoutSlope', s: [1.2, 0.45, 1.0], p: [0, 16.38, -10.35], face: 'front', c: C.oliveHi });
  H.box({ name: 'Beak', s: [1.0, 0.75, 0.8], p: [0, 15.55, -11.65], c: C.beak });
  H.wedgeF({ name: 'BeakTop', s: [0.9, 0.3, 0.8], p: [0, 16.07, -11.65], face: 'front', c: C.beakHi });
  H.wedgeF({ name: 'BeakHook', s: [0.9, 0.42, 0.4], p: [0, 15.0, -11.85], face: 'back', flip: true, c: C.beak });
  H.box({ name: 'HeadStripe', s: [1.76, 0.4, 0.4], p: [0, 16.3, -8.7], c: C.oliveDk });
  H.box({ name: 'MouthInterior', s: [0.86, 0.2, 1.8], p: [0, 15.27, -10.6], c: C.mouth });
  for (let i = 0; i < 3; i++) tuft(H, [0, 16.75 - i * 0.25, -8.6 + i * 0.45], [1.0 - i * 0.15, 0.6, 0.8], i % 2 ? C.rust : C.rustHi, [-20, 0, 0]);
  H.sym((s, side, n) => {
    eye(s, [0.86, 16.15, -9.45], { h: 0.36, d: 0.46, r: [0, -6, 0], c: C.eye, lid: C.oliveLo });
    s.box({ name: 'BrowRidge', s: [0.3, 0.26, 0.8], p: [0.78, 16.5, -9.45], r: [0, -6, -14], c: C.oliveDk });
    s.box({ name: 'Cheek', s: [0.2, 0.6, 0.9], p: [0.72, 15.55, -9.6], c: C.oliveLo });
    s.box({ name: 'Nostril', s: [0.1, 0.12, 0.2], p: [0.42, 16.0, -11.2], c: '#1a1812' });
    s.attach(`VFX_${n}Eye`, [0.92, 16.15, -9.45]);
  });
  H.attach('VFX_Mouth', [0, 15.25, -12.1]);
  H.attach('VFX_Head', [0, 16.0, -10.0]);
  H.attach('VFX_Crest', [0, 17.0, -8.8]);

  const [jaw, J0] = boneAt(rig, H, 'Jaw', head, [0, 15.3, -9.5], S);
  const J = J0.at([0, 1.7, 1.6]);
  J.box({ name: 'LowerJaw', s: [1.0, 0.42, 1.8], p: [0, 15.05, -10.5] });
  J.box({ name: 'LowerBeak', s: [0.85, 0.4, 0.6], p: [0, 15.05, -11.6], c: C.beak });
  J.box({ name: 'JawUnderside', s: [0.9, 0.12, 1.9], p: [0, 14.8, -10.6], c: C.belly });

  // ---------------- Long arms, three scythe claws per hand ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [2.5, 12.3, -3.4], S);
    segBox(A, [2.5, 12.3, -3.4], [3.0, 9.6, -4.4], 1.3, 1.4, { name: 'UpperArm' });
    A.box({ name: 'ShoulderPad', s: [1.4, 1.4, 1.8], p: [2.65, 12.1, -3.4], c: C.oliveLo, studs: 'top' });
    // a shaggy drape of rust feathers off the back of the arm
    for (let i = 0; i < 3; i++) {
      A.box({ name: 'ArmDrape', s: [0.26, 2.2 - i * 0.2, 0.9], p: [3.2, 10.6 - i * 0.55, -3.1 - i * 0.25], r: [-12, 0, -4], c: i % 2 ? C.rust : C.rustHi });
      A.box({ name: 'DrapeTip', s: [0.28, 0.4, 0.92], p: [3.2, 9.4 - i * 0.6, -2.85 - i * 0.25], r: [-12, 0, -4], c: C.oliveDk, shadow: false });
    }
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [3.0, 9.6, -4.4], S);
    segBox(F, [3.0, 9.6, -4.4], [3.0, 8.65, -6.8], 1.05, 1.1, { name: 'Forearm' });
    F.box({ name: 'Elbow', s: [1.1, 1.0, 1.0], p: [3.0, 9.6, -4.4], c: C.oliveLo });
    for (let i = 0; i < 4; i++) {
      const z = -4.6 - i * 0.6, y = 9.2 - i * 0.24;
      F.box({ name: 'ArmDrape', s: [0.24, 1.9 - i * 0.15, 0.62], p: [3.12, y - 0.95, z], r: [14, 0, -3], c: i % 2 ? C.rustLo : C.rust });
      F.box({ name: 'DrapeTip', s: [0.26, 0.36, 0.64], p: [3.12, y - 1.95 + i * 0.07, z + 0.24], r: [14, 0, -3], c: C.oliveDk, shadow: false });
    }
    const [hand, Hd] = boneAt(rig, F, `${n}Hand`, fore, [3.0, 8.65, -6.8], S);
    Hd.box({ name: 'Hand', s: [1.2, 1.1, 1.2], p: [3.0, 8.4, -7.1], c: C.oliveLo });
    let tip = null;
    for (const [dx, k] of [[-0.56, 1.0], [0, 1.15], [0.56, 1.04]]) {
      const t = scythe(Hd, [3.0 + dx, 7.95, -7.5], k, 'ScytheClaw');
      if (dx === 0) tip = t;
    }
    Hd.attach(`VFX_${n}Claw`, tip);
  });

  // ---------------- Legs: short, stout, four-toed ----------------
  P.sym((s, side, n) => {
    const L = bipedLeg(rig, s, pelvis, n, { hip: [2.4, 8.3, 2.6], knee: [2.85, 4.9, 1.0], ankle: [2.85, 2.0, 2.6], ball: [2.85, 0.62, 1.35] }, {
      thigh: [2.2, 2.8], shin: [1.45, 1.55], meta: [1.25, 1.25], toeLen: 1.35, toeW: 0.58, toeH: 0.58,
      muscle: { s: [2.0, 3.2, 3.0], p: [2.95, 7.2, 2.0] }, c: C.olive, cLo: C.leg, claw: C.toe,
    });
    for (let i = 0; i < 3; i++) tuft(L.ctx[0], [3.05, 6.6 - i * 0.2, 1.3 + i * 0.9], [2.0, 1.0, 1.0], i % 2 ? C.rust : C.rustLo);
    // the inner fourth toe
    L.ctx[3].box({ name: 'Toe', s: [0.5, 0.5, 0.9], p: [2.15, 0.25, 1.15], r: [0, 25, 0], c: C.leg });
    claw(L.ctx[3], [1.95, 0.3, 0.7], { s: 0.55, c: C.toe, r: [0, 25, 0] });
  });

  // ---------------- Tail: short and feathered ----------------
  tailChain(rig, P, pelvis, [
    { p: [0, 9.2, 4.4], s: [3.2, 3.0, 2.2], c: [0, 9.1, 5.4] },
    { p: [0, 8.9, 6.5], s: [2.5, 2.4, 2.1], c: [0, 8.75, 7.5] },
    { p: [0, 8.5, 8.5], s: [1.9, 1.8, 2.0], c: [0, 8.3, 9.45] },
    { p: [0, 8.05, 10.4], s: [1.3, 1.3, 1.9], c: [0, 7.85, 11.3] },
    { p: [0, 7.6, 12.2], s: [0.8, 0.8, 1.7], c: [0, 7.45, 13.0] },
  ], { c: C.olive, under: C.belly, band: C.oliveDk, each: (Tc, d, i) => {
    tuft(Tc, [0, d.c[1] + d.s[1] / 2 + 0.3, d.c[2]], [d.s[0] * 0.7, 0.6, d.s[2] * 0.8], i % 2 ? C.rust : C.rustLo);
    if (i === 4) tuft(Tc, [0, 7.5, 14.1], [1.0, 1.0, 1.2], C.rustHi, [-30, 0, 0]);
  } });

  highlight(model, '#16180a', 0.4);
  return model;
}

module.exports = { build };
