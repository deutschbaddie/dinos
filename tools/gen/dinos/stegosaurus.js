// DINOSAUR 03 — STEGOSAURUS (Uncommon). Calm until threatened. ~15 studs long, ~7.5 tall.
const { makeDino, seg, boneAt, eye, band, highlight, segBox, quadLeg, tailChain } = require('./common.js');

const C = {
  body: '#5f8a3a', bodyHi: '#729f48', bodyLo: '#4a6d2d', legs: '#3f5f2a', plate: '#d2662a', plateHi: '#ec8a45', plateLo: '#a84a1c',
  spike: '#f1e6c8', belly: '#e1d3a6', beak: '#3a3326', eye: '#ffcf3a', mouth: '#6e1a22', stripe: '#3d5a24',
};

// Diamond plate (box rotated 45 deg in the side plane) with a lighter inset on each face
function plate(ctx, p, h, o = {}) {
  const c = ctx.at(p, [45 + (o.tilt || 0), 0, 0]);
  const part = c.box({ name: 'Plate', s: [0.2, h, h], c: o.c || C.plate });
  c.box({ name: 'PlateInset', s: [0.24, h * 0.55, h * 0.55], c: C.plateHi, shadow: false });
  c.box({ name: 'PlateRim', s: [0.16, h * 1.08, h * 1.08], c: C.plateLo, shadow: false });
  part.tag('StegoPlate');
  return part;
}

function build() {
  const { model, rig } = makeDino('Stegosaurus', {
    DisplayName: 'Stegosaurus', Rarity: 'Uncommon', Classification: 'Armored Herbivore', Personality: 'Calm until threatened',
    Locomotion: 'Quadruped', SignatureMove: 'Tail Sweep',
  }, [3.2, 3.4, 7.5], [0, 3.9, 0]);
  const S = { c: C.body };

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 4.4, 1.5], S);
  P.box({ name: 'HipHump', s: [3.2, 2.9, 3.0], p: [0, 4.3, 1.6], studs: 'top' });
  P.box({ name: 'HipTop', s: [2.4, 0.5, 2.6], p: [0, 5.95, 1.6], c: C.bodyHi });
  P.box({ name: 'HipBelly', s: [2.6, 0.3, 2.6], p: [0, 2.75, 1.6], c: C.belly });
  P.sym((s) => { for (let i = 0; i < 3; i++) s.box({ name: 'FlankStripe', s: [0.08, 1.6, 0.35], p: [1.62, 4.4, 0.6 + i * 1.0], r: [12, 0, 0], c: C.stripe, shadow: false }); });

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 4.1, -0.1], S);
  const Tt = T.at([0, 4.0, -1.5], [-12, 0, 0]);
  Tt.box({ name: 'Torso', s: [3.0, 2.5, 3.4], p: [0, -0.1, 0], studs: 'top' });
  Tt.box({ name: 'Belly', s: [2.5, 0.3, 3.2], p: [0, -1.42, 0], c: C.belly });
  T.box({ name: 'Shoulder', s: [2.7, 2.0, 1.2], p: [0, 3.2, -3.2], c: C.bodyLo });
  T.sym((s) => { for (let i = 0; i < 3; i++) s.box({ name: 'FlankStripe', s: [0.08, 1.4, 0.32], p: [1.52, 3.8, -2.6 + i * 0.9], r: [8, 0, 0], c: C.stripe, shadow: false }); });
  T.attach('VFX_Chest', [0, 2.6, -3.6]);

  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 3.2, -3.6], S);
  segBox(N, [0, 3.2, -3.6], [0, 2.5, -4.9], 1.6, 1.5, { name: 'Neck', c: C.bodyLo });
  N.box({ name: 'Throat', s: [1.2, 0.2, 1.2], p: [0, 2.0, -4.3], c: C.belly });

  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 2.45, -4.95], S);
  H.box({ name: 'Skull', s: [1.0, 0.85, 1.2], p: [0, 2.45, -5.4], studs: 'top' });
  H.box({ name: 'Snout', s: [0.75, 0.6, 1.1], p: [0, 2.3, -6.4] });
  H.wedgeF({ name: 'SnoutSlope', s: [0.75, 0.25, 0.7], p: [0, 2.725, -6.35], face: 'front', c: C.bodyHi });
  H.box({ name: 'Beak', s: [0.6, 0.4, 0.3], p: [0, 2.18, -7.02], c: C.beak });
  H.box({ name: 'MouthInterior', s: [0.55, 0.15, 1.0], p: [0, 2.03, -6.2], c: C.mouth });
  H.sym((s, side, n) => {
    eye(s, [0.52, 2.6, -5.5], { h: 0.2, d: 0.28, c: C.eye, lid: C.body });
    s.box({ name: 'Brow', s: [0.18, 0.12, 0.4], p: [0.48, 2.8, -5.5], c: C.bodyLo });
    s.attach(`VFX_${n}Eye`, [0.55, 2.6, -5.5]);
  });
  H.attach('VFX_Mouth', [0, 2.1, -7.2]);
  H.attach('VFX_Head', [0, 2.55, -5.8]);
  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 2.05, -5.3], S);
  J.box({ name: 'LowerJaw', s: [0.65, 0.3, 1.6], p: [0, 1.88, -6.2] });
  J.box({ name: 'LowerBeak', s: [0.5, 0.25, 0.25], p: [0, 1.9, -7.0], c: C.beak });

  // Plates: two staggered rows, tallest over the hips, attached to the bone underneath
  plate(N, [0.22, 3.35, -4.0], 0.6, { tilt: -10 });
  plate(N, [-0.22, 3.2, -4.4], 0.5, { tilt: -10 });
  [[-3.0, 0.9], [-2.3, 1.15], [-1.5, 1.4], [-0.7, 1.6]].forEach(([z, h], i) => plate(T, [i % 2 ? -0.24 : 0.24, 4.95 + h * 0.15 + (z + 3) * 0.25, z], h));
  [[0.2, 1.9], [1.0, 2.05], [1.8, 2.0], [2.6, 1.8]].forEach(([z, h], i) => plate(P, [i % 2 ? 0.24 : -0.24, 6.1 + h * 0.18, z], h));

  P.sym((s, side, n) => quadLeg(rig, s, pelvis, n, 'Hind', { hip: [1.5, 4.2, 1.8], knee: [1.65, 2.4, 1.3], ankle: [1.65, 0.85, 1.9] }, {
    upper: [1.1, 1.3], lower: [0.85, 0.85], foot: [1.15, 0.45, 1.25], muscle: { s: [0.95, 1.9, 1.9], p: [1.7, 3.7, 1.7] }, toes: 3, c: C.legs, cLo: C.legs, claw: C.spike,
  }));
  T.sym((s, side, n) => quadLeg(rig, s, torso, n, 'Front', { hip: [1.4, 3.0, -2.6], knee: [1.6, 1.8, -2.4], ankle: [1.6, 0.7, -2.7] }, {
    upper: [0.85, 0.9], lower: [0.7, 0.7], foot: [0.95, 0.4, 1.0], toes: 3, c: C.legs, cLo: C.legs, claw: C.spike,
  }));

  const tail = tailChain(rig, P, pelvis, [
    { p: [0, 4.6, 3.0], s: [2.2, 1.9, 1.7], c: [0, 4.55, 3.75] },
    { p: [0, 4.2, 4.6], s: [1.6, 1.45, 1.6], c: [0, 4.15, 5.3] },
    { p: [0, 3.7, 6.1], s: [1.1, 1.0, 1.5], c: [0, 3.65, 6.8] },
    { p: [0, 3.2, 7.4], s: [0.7, 0.65, 1.4], c: [0, 3.15, 8.05] },
  ], { c: C.body, under: C.belly, band: C.stripe });
  plate(tail.ctxs[0], [0.24, 5.85, 3.5], 1.5);
  plate(tail.ctxs[0], [-0.24, 5.7, 4.2], 1.25);
  plate(tail.ctxs[1], [0.22, 5.05, 5.1], 1.0);
  plate(tail.ctxs[2], [-0.2, 4.35, 6.5], 0.7);
  // Thagomizer: four long spikes splayed out-back-up
  const T4 = tail.ctxs[3];
  T4.sym((s) => {
    for (const [base, tip] of [[[0.25, 3.4, 7.9], [1.25, 4.2, 9.0]], [[0.25, 3.4, 8.4], [1.05, 4.5, 9.7]]]) {
      segBox(s, base, tip, 0.26, 0.26, { name: 'ThagomizerSpike', c: C.spike, extend: 0.05 });
      s.box({ name: 'SpikeBase', s: [0.38, 0.38, 0.38], p: base, c: C.plateLo });
    }
  });

  highlight(model);
  return model;
}

module.exports = { build };
