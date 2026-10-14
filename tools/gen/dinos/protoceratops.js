// RED CLIFFS 02 — PROTOCERATOPS (Common). Sheep-sized, stubborn, lives in herds and digs its nests in the dunes.
// ~8 studs long, ~3.4 tall to the top of its frill. Sandy tan with brown stripes, a broad frill with a rose-pink rim
// and eye-spots, a parrot beak, a nasal bump (no horns) and a tall flattened tail crest. Forward = -Z.
const { makeDino, seg, boneAt, eye, band, highlight, segBox, quadLeg, tailChain } = require('./common.js');

const C = {
  sand: '#d9ad72', sandHi: '#e8c28a', sandLo: '#bb8f58', stripe: '#8a5a32', stripeLo: '#6e4426', belly: '#f1e3c2',
  rim: '#ec6f8e', rimLo: '#c94f70', rimHi: '#ff9ab0', spot: '#5a3420', spotRing: '#f6e6c4', frill: '#e2b07a',
  beak: '#5e4232', beakLo: '#47301f', beakHi: '#7a5a44', eye: '#ffcf3a', mouth: '#7a2a2a', claw: '#3a2a20', leg: '#c49660', legLo: '#a77c4c',
};

function build() {
  const { model, rig } = makeDino('Protoceratops', {
    DisplayName: 'Protoceratops', Rarity: 'Common', Classification: 'Frilled Herbivore', Personality: 'Stubborn, sociable, a born digger',
    Locomotion: 'Quadruped', SignatureMove: 'Sand Burst',
  }, [1.8, 1.5, 4.0], [0, 1.9, 0.2]);
  const S = { c: C.sand };

  // ---------------- Hips (the highest point of the back) ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 2.0, 1.3], S);
  P.box({ name: 'Hip', s: [1.9, 1.5, 1.7], p: [0, 1.95, 1.35], studs: 'top' });
  P.box({ name: 'HipTop', s: [1.5, 0.22, 1.5], p: [0, 2.8, 1.35], c: C.sandHi, studs: 'top' });
  P.box({ name: 'HipBelly', s: [1.5, 0.16, 1.5], p: [0, 1.18, 1.3], c: C.belly });
  for (const z of [0.85, 1.85]) band(P, [0, 2.38, z], [1.94, 0.7, 0.3], { c: C.stripe });
  for (const z of [0.7, 1.15, 1.6, 2.05]) P.box({ name: 'BackScute', s: [0.3, 0.14, 0.3], p: [0, 2.98, z], c: C.stripe });

  // ---------------- Barrel + shoulders ----------------
  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 1.85, 0.4], S);
  const Tt = T.at([0, 1.8, -0.45], [-6, 0, 0]);
  Tt.box({ name: 'Barrel', s: [2.0, 1.45, 1.9], p: [0, 0, 0], studs: 'top' });
  Tt.box({ name: 'Belly', s: [1.6, 0.16, 1.7], p: [0, -0.78, 0], c: C.belly });
  for (const z of [-0.5, 0.35]) band(Tt, [0, 0.38, z], [2.04, 0.7, 0.3], { c: C.stripe });
  T.box({ name: 'Shoulder', s: [1.75, 1.2, 0.8], p: [0, 1.6, -1.55], c: C.sandLo });
  T.box({ name: 'ShoulderTop', s: [1.4, 0.2, 0.8], p: [0, 2.26, -1.5], c: C.sand, studs: 'top' });
  for (const z of [-1.2, -0.7, -0.2, 0.3]) T.box({ name: 'BackScute', s: [0.28, 0.14, 0.28], p: [0, 2.5 + (z + 1.2) * 0.1, z], c: C.stripe });
  T.sym((s) => { for (let i = 0; i < 3; i++) s.box({ name: 'SkinFold', s: [0.08, 0.7, 0.22], p: [1.0, 1.55, -0.9 + i * 0.6], c: C.sandLo, shadow: false }); });
  T.attach('VFX_Chest', [0, 1.2, -1.9]);

  // ---------------- Neck (short and thick, tucked under the frill) ----------------
  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 1.7, -1.85], S);
  N.box({ name: 'Neck', s: [1.3, 1.1, 0.7], p: [0, 1.65, -2.05], c: C.sandLo });
  N.box({ name: 'Throat', s: [1.0, 0.2, 0.6], p: [0, 1.06, -2.05], c: C.belly });

  // ---------------- Head: big for the body, beak, nasal bump, jugal flares, the frill ----------------
  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 1.75, -2.3], S);
  H.box({ name: 'Skull', s: [1.1, 0.95, 1.0], p: [0, 1.85, -2.75], studs: 'top' });
  H.box({ name: 'Snout', s: [0.82, 0.86, 0.8], p: [0, 1.74, -3.6] });
  H.wedgeF({ name: 'SnoutSlope', s: [0.8, 0.28, 0.5], p: [0, 2.31, -3.42], face: 'front', c: C.sandHi });
  H.box({ name: 'NasalBump', s: [0.42, 0.26, 0.5], p: [0, 2.28, -3.75], c: C.sandHi });
  H.wedgeF({ name: 'NasalBumpFront', s: [0.42, 0.26, 0.2], p: [0, 2.28, -4.1], face: 'front', c: C.sandHi });
  H.box({ name: 'UpperBeak', s: [0.56, 0.42, 0.3], p: [0, 1.66, -4.12], c: C.beak });
  H.wedgeF({ name: 'BeakTop', s: [0.5, 0.18, 0.3], p: [0, 1.96, -4.12], face: 'front', c: C.beakHi });
  H.wedgeF({ name: 'BeakHook', s: [0.5, 0.28, 0.24], p: [0, 1.31, -4.15], face: 'back', flip: true, c: C.beakLo });
  H.box({ name: 'SnoutStripe', s: [0.86, 0.12, 0.24], p: [0, 2.12, -3.1], c: C.stripe });
  H.box({ name: 'MouthInterior', s: [0.6, 0.16, 1.1], p: [0, 1.38, -3.5], c: C.mouth });
  H.sym((s, side, n) => {
    eye(s, [0.56, 2.0, -2.85], { h: 0.2, d: 0.28, r: [0, -6, 0], c: C.eye, lid: C.sandLo });
    s.box({ name: 'Brow', s: [0.16, 0.12, 0.42], p: [0.52, 2.2, -2.85], r: [0, -6, -10], c: C.stripe });
    s.wedgeF({ name: 'JugalFlare', s: [0.44, 0.42, 0.5], p: [0.66, 1.5, -2.7], face: 'right', c: C.sandLo });
    s.box({ name: 'JugalTip', s: [0.2, 0.2, 0.2], p: [0.8, 1.32, -2.7], c: C.stripe });
    s.box({ name: 'Nostril', s: [0.06, 0.08, 0.12], p: [0.32, 2.0, -3.95], c: '#2a1a12' });
    s.box({ name: 'CheekStripe', s: [0.06, 0.14, 0.5], p: [0.42, 1.78, -3.4], c: C.stripe, shadow: false });
    s.attach(`VFX_${n}Eye`, [0.6, 2.0, -2.85]);
  });
  // the frill: a broad shield leaning back over the neck, rose-pink rim, a pair of eye-spots
  const F = H.at([0, 2.22, -2.35], [30, 0, 0]);
  F.box({ name: 'FrillRim', s: [2.3, 1.62, 0.12], p: [0, 0.74, 0.08], c: C.rim });
  F.box({ name: 'Frill', s: [2.06, 1.4, 0.2], p: [0, 0.64, -0.02], c: C.frill });
  F.box({ name: 'FrillBack', s: [1.9, 1.3, 0.1], p: [0, 0.64, 0.18], c: C.sandLo });
  F.box({ name: 'FrillRidge', s: [0.22, 1.2, 0.16], p: [0, 0.6, -0.14], c: C.sandHi });
  F.sym((s) => {
    s.cyl({ name: 'FrillSpotRing', axis: 'z', len: 0.05, d: 0.56, p: [0.56, 0.78, -0.14], c: C.spotRing, shadow: false });
    s.cyl({ name: 'FrillSpot', axis: 'z', len: 0.06, d: 0.32, p: [0.56, 0.78, -0.16], c: C.spot, shadow: false });
    s.box({ name: 'FrillStripe', s: [0.12, 0.7, 0.04], p: [0.92, 0.42, -0.13], r: [0, 0, 12], c: C.stripe, shadow: false });
  });
  for (let i = 0; i < 7; i++) F.box({ name: 'FrillScallop', s: [0.26, 0.26, 0.14], p: [-0.96 + i * 0.32, 1.56, 0.08], r: [0, 0, 45], c: i % 2 ? C.rimHi : C.rim });
  F.sym((s) => { for (let i = 0; i < 3; i++) s.box({ name: 'FrillScallop', s: [0.24, 0.24, 0.14], p: [1.16, 0.14 + i * 0.45, 0.08], r: [0, 0, 45], c: i % 2 ? C.rimHi : C.rim }); });
  F.attach('VFX_Crest', [0, 1.5, -0.2]);
  H.attach('VFX_Mouth', [0, 1.3, -4.4]);
  H.attach('VFX_Head', [0, 2.0, -3.2]);

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 1.4, -2.85], S);
  J.box({ name: 'LowerJaw', s: [0.7, 0.32, 1.0], p: [0, 1.22, -3.4] });
  J.box({ name: 'LowerBeak', s: [0.5, 0.3, 0.3], p: [0, 1.22, -4.02], c: C.beak });
  J.box({ name: 'JawUnderside', s: [0.6, 0.08, 0.95], p: [0, 1.05, -3.4], c: C.belly });

  // ---------------- Legs (hind longer than front: the back slopes down to the shoulders) ----------------
  P.sym((s, side, n) => quadLeg(rig, s, pelvis, n, 'Hind', { hip: [0.9, 1.75, 1.45], knee: [1.05, 1.02, 1.05], ankle: [1.05, 0.42, 1.45] }, {
    upper: [0.62, 0.7], lower: [0.46, 0.46], foot: [0.62, 0.26, 0.72], muscle: { s: [0.56, 0.9, 1.0], p: [1.02, 1.6, 1.4] }, toes: 3, c: C.sand, cLo: C.leg, claw: C.claw,
  }));
  T.sym((s, side, n) => quadLeg(rig, s, torso, n, 'Front', { hip: [0.85, 1.4, -1.5], knee: [0.98, 0.85, -1.4], ankle: [0.98, 0.36, -1.62] }, {
    upper: [0.5, 0.55], lower: [0.42, 0.42], foot: [0.56, 0.24, 0.6], toes: 3, c: C.sand, cLo: C.leg, claw: C.claw,
  }));

  // ---------------- Tail: deep and flattened, with a tall crest of spines ----------------
  tailChain(rig, P, pelvis, [
    { p: [0, 2.15, 2.15], s: [1.2, 1.15, 0.85], c: [0, 2.1, 2.52] },
    { p: [0, 2.0, 2.9], s: [0.86, 0.95, 0.78], c: [0, 1.95, 3.25] },
    { p: [0, 1.8, 3.6], s: [0.6, 0.72, 0.72], c: [0, 1.74, 3.92] },
    { p: [0, 1.55, 4.22], s: [0.38, 0.46, 0.6], c: [0, 1.5, 4.46] },
  ], { c: C.sand, under: C.belly, band: C.stripe, studs: false, each: (Tc, d, i) => {
    const h = [0.55, 0.5, 0.4, 0.26][i];
    Tc.box({ name: 'TailCrest', s: [0.16, h, d.s[2] * 0.9], p: [0, d.c[1] + d.s[1] / 2 + h / 2, d.c[2]], c: i % 2 ? C.stripeLo : C.stripe });
  } });

  highlight(model, '#2a1a10', 0.45);
  return model;
}

module.exports = { build };
