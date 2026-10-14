// DINOSAUR 04 — PARASAUROLOPHUS (Uncommon). Curious, social, energetic. ~13 studs long, ~8.5 tall.
const { makeDino, seg, boneAt, eye, band, dorsal, highlight, segBox, bipedLeg, tailChain, claw } = require('./common.js');

const C = {
  body: '#e3b83a', bodyHi: '#f0cb55', bodyLo: '#c49a28', stripe: '#d27a2a', stripeLo: '#b5611c',
  belly: '#f3e6c0', crest: '#d8452a', crestHi: '#ef6a3e', crestLo: '#a8301c', bill: '#5a4630', eye: '#5a2a10', mouth: '#7a2a2a',
};

function build() {
  const { model, rig } = makeDino('Parasaurolophus', {
    DisplayName: 'Parasaurolophus', Rarity: 'Uncommon', Classification: 'Herd Dinosaur', Personality: 'Curious, social, energetic',
    Locomotion: 'Biped', SignatureMove: 'Herd Call',
  }, [2.6, 2.8, 5], [0, 4.2, 0.2]);
  const S = { c: C.body };

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 4.3, 1.0], S);
  P.box({ name: 'Hip', s: [2.5, 2.4, 2.4], p: [0, 4.3, 1.1], studs: 'top' });
  P.box({ name: 'HipBelly', s: [2.0, 0.25, 2.2], p: [0, 3.0, 1.0], c: C.belly });
  for (const z of [0.4, 1.4]) band(P, [0, 4.95, z], [2.56, 1.1, 0.4], { c: C.stripe });
  dorsal(P, [[5.5, 0.3, 1], [5.5, 1.2, 1]], { h: 0.3, d: 0.5, w: 0.3, c: C.stripeLo });

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 4.25, -0.4], S);
  const Tt = T.at([0, 4.2, -1.1], [-10, 0, 0]);
  Tt.box({ name: 'Torso', s: [2.6, 2.4, 2.6], studs: 'top' });
  Tt.box({ name: 'Belly', s: [2.1, 0.25, 2.4], p: [0, -1.3, 0], c: C.belly });
  band(Tt, [0, 0.65, 0.3], [2.66, 1.1, 0.4], { c: C.stripe });
  band(Tt, [0, 0.65, -0.7], [2.66, 1.1, 0.4], { c: C.stripe });
  T.attach('VFX_Chest', [0, 3.6, -2.4]);

  // Long neck in two segments rising to the head
  const [neck1, N1] = boneAt(rig, T, 'Neck1', torso, [0, 4.6, -2.2], S);
  segBox(N1, [0, 4.6, -2.2], [0, 5.7, -2.95], 1.5, 1.6, { name: 'NeckBase' });
  N1.box({ name: 'Throat', s: [1.0, 1.4, 0.2], p: [0, 4.9, -2.95], r: [-35, 0, 0], c: C.belly });
  const [neck2, N2] = boneAt(rig, N1, 'Neck2', neck1, [0, 5.6, -2.85], S);
  segBox(N2, [0, 5.6, -2.85], [0, 6.5, -3.35], 1.2, 1.3, { name: 'NeckUpper' });
  N2.box({ name: 'Throat', s: [0.8, 1.0, 0.2], p: [0, 5.85, -3.55], r: [-30, 0, 0], c: C.belly });
  band(N2, [0, 6.1, -2.9], [1.26, 0.35, 1.0], { c: C.stripe });

  const [head, H] = boneAt(rig, N2, 'Head', neck2, [0, 6.5, -3.35], S);
  H.box({ name: 'Skull', s: [1.2, 1.1, 1.3], p: [0, 6.7, -3.75], studs: 'top' });
  H.box({ name: 'Snout', s: [0.95, 0.75, 1.6], p: [0, 6.45, -5.0] });
  H.box({ name: 'Bill', s: [1.15, 0.35, 0.7], p: [0, 6.18, -5.95], c: C.bill });
  H.box({ name: 'MouthInterior', s: [0.8, 0.15, 1.4], p: [0, 6.05, -4.9], c: C.mouth });
  // Crest: swept-back tube in tapering segments, two-tone
  const crest = [[0, 7.05, -3.9], [0, 7.55, -3.1], [0, 7.95, -2.15], [0, 8.2, -1.2]];
  segBox(H, crest[0], crest[1], 0.62, 0.62, { name: 'Crest', c: C.crest });
  segBox(H, crest[1], crest[2], 0.55, 0.55, { name: 'Crest', c: C.crestHi });
  segBox(H, crest[2], crest[3], 0.45, 0.45, { name: 'CrestTip', c: C.crest, extend: 0.15 });
  H.box({ name: 'CrestStripe', s: [0.66, 0.12, 1.2], p: [0, 7.45, -3.2], r: [-38, 0, 0], c: C.crestLo });
  H.sym((s, side, n) => {
    eye(s, [0.62, 6.85, -3.9], { h: 0.24, d: 0.3, c: C.eye, lid: C.body });
    s.box({ name: 'Cheek', s: [0.14, 0.45, 0.8], p: [0.55, 6.35, -4.2], c: C.bodyLo });
    s.box({ name: 'Nostril', s: [0.08, 0.1, 0.2], p: [0.45, 6.6, -5.6], c: '#2a2015' });
    s.attach(`VFX_${n}Eye`, [0.66, 6.85, -3.9]);
  });
  H.attach('VFX_Crest', [0, 8.25, -1.0]);
  H.attach('VFX_Mouth', [0, 6.2, -6.3]);
  H.attach('VFX_Head', [0, 6.8, -4.2]);
  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 6.15, -3.8], S);
  J.box({ name: 'LowerJaw', s: [0.85, 0.3, 1.8], p: [0, 5.95, -4.8] });
  J.box({ name: 'LowerBill', s: [1.0, 0.22, 0.6], p: [0, 5.96, -5.9], c: C.bill });

  // Arms long enough to touch the ground (hadrosaurs walk on all fours at times)
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [0.95, 3.8, -1.8], S);
    segBox(A, [0.95, 3.8, -1.8], [1.05, 2.6, -2.1], 0.42, 0.45, { name: 'UpperArm', c: C.bodyLo });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [1.05, 2.6, -2.1], S);
    segBox(F, [1.05, 2.6, -2.1], [1.05, 1.5, -2.5], 0.36, 0.38, { name: 'Forearm', c: C.bodyLo });
    F.box({ name: 'Hand', s: [0.42, 0.3, 0.45], p: [1.05, 1.36, -2.6], c: C.bodyLo });
    claw(F, [1.05, 1.22, -2.85], { s: 0.2, c: '#3a2a1a' });
  });
  P.sym((s, side, n) => bipedLeg(rig, s, pelvis, n, { hip: [1.25, 4.1, 1.0], knee: [1.4, 2.6, 0.3], ankle: [1.4, 1.1, 1.15], ball: [1.4, 0.25, 0.55] }, {
    thigh: [1.0, 1.4], shin: [0.7, 0.75], meta: [0.55, 0.55], toeLen: 0.75, toeW: 0.3, toeH: 0.3, muscle: { s: [0.9, 1.7, 1.5], p: [1.4, 3.6, 0.8] }, c: C.body, cLo: C.bodyLo, claw: '#3a2a1a',
  }));

  tailChain(rig, P, pelvis, [
    { p: [0, 4.6, 2.3], s: [1.9, 1.9, 1.6], c: [0, 4.6, 3.0] },
    { p: [0, 4.7, 3.7], s: [1.4, 1.5, 1.5], c: [0, 4.7, 4.4] },
    { p: [0, 4.75, 5.0], s: [1.0, 1.15, 1.5], c: [0, 4.75, 5.7] },
    { p: [0, 4.8, 6.3], s: [0.7, 0.85, 1.4], c: [0, 4.8, 6.95] },
    { p: [0, 4.8, 7.5], s: [0.45, 0.55, 1.2], c: [0, 4.8, 8.05] },
  ], { c: C.body, under: C.belly, band: C.stripe });

  highlight(model);
  return model;
}

module.exports = { build };
