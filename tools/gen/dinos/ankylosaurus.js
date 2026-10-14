// DINOSAUR 05 — ANKYLOSAURUS (Rare). Defensive, slow, unstoppable. ~12 studs long, ~5 tall.
const { makeDino, seg, boneAt, eye, band, highlight, segBox, quadLeg, tailChain } = require('./common.js');
const { rng } = require('../builder.js');

const C = {
  body: '#6f7378', bodyLo: '#5a5e63', olive: '#4f5a33', oliveLo: '#3e4728', rust: '#a4552c', rustLo: '#83411f',
  bone: '#efe2c4', boneLo: '#d4c49d', belly: '#b8b2a0', eye: '#ffb21a', beak: '#2e2a24', mouth: '#5a1a1e',
};

function build() {
  const { model, rig } = makeDino('Ankylosaurus', {
    DisplayName: 'Ankylosaurus', Rarity: 'Rare', Classification: 'Armored Dinosaur', Personality: 'Defensive, slow, unstoppable',
    Locomotion: 'Quadruped', SignatureMove: 'Club Smash',
  }, [4.4, 2.4, 6], [0, 2.7, 0.3]);
  const S = { c: C.body };
  const R = rng(505);

  // armour grid: rows of osteoderm plates across the dome
  const armour = (ctx, z0, z1, y, halfW) => {
    for (let z = z0; z <= z1 + 1e-6; z += 0.75) {
      for (let x = -halfW; x <= halfW + 1e-6; x += 0.85) {
        const big = Math.abs(x) > halfW - 0.5;
        ctx.box({ name: 'Osteoderm', s: [0.7, 0.28, 0.6], p: [x, y + (big ? -0.2 : 0) - Math.abs(x) * 0.12, z], r: [0, R() * 10 - 5, -x * 6], c: (Math.round((x + z) * 2) % 3) ? C.olive : C.rust });
        if (!big && R() > 0.55) ctx.wedgeF({ name: 'Scute', s: [0.32, 0.28, 0.3], p: [x, y + 0.27 - Math.abs(x) * 0.12, z], face: 'back', c: C.boneLo });
      }
    }
  };

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 2.9, 1.3], S);
  P.box({ name: 'HipDome', s: [4.4, 1.9, 2.8], p: [0, 2.95, 1.6], studs: 'top' });
  P.box({ name: 'HipBelly', s: [3.6, 0.25, 2.6], p: [0, 1.95, 1.5], c: C.belly });
  armour(P, 0.6, 2.85, 4.05, 1.75);
  P.sym((s) => { for (const z of [0.6, 1.6, 2.6]) segBox(s, [2.15, 2.6, z], [2.95, 2.75, z + 0.3], 0.42, 0.42, { name: 'FlankSpike', c: C.bone, extend: 0.05 }); });

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 2.85, 0.0], S);
  T.box({ name: 'Dome', s: [4.6, 1.9, 3.2], p: [0, 2.9, -1.2], studs: 'top' });
  T.box({ name: 'Belly', s: [3.8, 0.25, 3.0], p: [0, 1.9, -1.2], c: C.belly });
  armour(T, -2.6, -0.1, 4.0, 1.75);
  T.sym((s) => {
    for (const z of [-2.4, -1.4, -0.4]) segBox(s, [2.2, 2.55, z], [3.05, 2.65, z - 0.15], 0.45, 0.45, { name: 'FlankSpike', c: C.bone, extend: 0.05 });
    s.box({ name: 'SkirtArmor', s: [0.3, 0.5, 3.4], p: [2.25, 2.15, -1.2], c: C.rust });
  });
  T.attach('VFX_Chest', [0, 2.2, -2.8]);

  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 2.6, -2.8], S);
  N.box({ name: 'Neck', s: [2.2, 1.4, 1.2], p: [0, 2.5, -3.2], c: C.bodyLo });
  N.box({ name: 'NeckRing', s: [2.4, 0.5, 0.5], p: [0, 3.25, -3.1], c: C.rust, studs: 'top' });
  N.sym((s) => s.wedgeF({ name: 'NeckSpike', s: [0.4, 0.5, 0.5], p: [1.1, 3.25, -3.1], face: 'right', c: C.bone }));

  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 2.5, -3.6], S);
  H.box({ name: 'Skull', s: [2.0, 1.15, 1.6], p: [0, 2.45, -4.4], studs: 'top' });
  H.box({ name: 'SkullArmor', s: [1.8, 0.25, 1.4], p: [0, 3.12, -4.4], c: C.olive });
  for (const [x, z] of [[-0.5, -4.0], [0.5, -4.0], [0, -4.7]]) H.box({ name: 'HeadScute', s: [0.5, 0.15, 0.45], p: [x, 3.3, z], c: C.rust });
  H.box({ name: 'Snout', s: [1.4, 0.85, 0.8], p: [0, 2.3, -5.55] });
  H.box({ name: 'Beak', s: [1.1, 0.4, 0.3], p: [0, 2.05, -6.0], c: C.beak });
  H.box({ name: 'MouthInterior', s: [1.1, 0.15, 1.2], p: [0, 1.95, -4.9], c: C.mouth });
  H.sym((s, side, n) => {
    s.wedgeF({ name: 'HeadHorn', s: [0.45, 0.55, 0.6], p: [1.05, 3.0, -3.75], face: 'back', r: [0, -30, 0], c: C.bone });
    s.wedgeF({ name: 'CheekHorn', s: [0.45, 0.5, 0.5], p: [1.08, 2.15, -3.9], face: 'right', c: C.bone });
    eye(s, [1.02, 2.6, -4.65], { h: 0.18, d: 0.28, c: C.eye, lid: C.body });
    s.box({ name: 'BrowPlate', s: [0.3, 0.2, 0.6], p: [0.9, 2.86, -4.65], c: C.rust });
    s.attach(`VFX_${n}Eye`, [1.05, 2.6, -4.65]);
  });
  H.attach('VFX_Mouth', [0, 2.05, -6.2]);
  H.attach('VFX_Head', [0, 2.6, -4.9]);
  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 1.95, -3.9], S);
  J.box({ name: 'LowerJaw', s: [1.3, 0.35, 1.9], p: [0, 1.78, -5.0] });
  J.box({ name: 'LowerBeak', s: [1.0, 0.3, 0.3], p: [0, 1.8, -5.95], c: C.beak });

  P.sym((s, side, n) => quadLeg(rig, s, pelvis, n, 'Hind', { hip: [1.75, 2.6, 1.6], knee: [1.95, 1.45, 1.3], ankle: [1.95, 0.6, 1.65] }, {
    upper: [1.05, 1.15], lower: [0.85, 0.85], foot: [1.1, 0.4, 1.1], toes: 3, c: C.bodyLo, cLo: C.bodyLo, claw: C.bone,
  }));
  T.sym((s, side, n) => quadLeg(rig, s, torso, n, 'Front', { hip: [1.65, 2.4, -1.9], knee: [2.0, 1.4, -1.8], ankle: [2.0, 0.55, -2.0] }, {
    upper: [0.95, 1.0], lower: [0.8, 0.8], foot: [1.0, 0.38, 1.0], toes: 3, c: C.bodyLo, cLo: C.bodyLo, claw: C.bone,
  }));

  const tail = tailChain(rig, P, pelvis, [
    { p: [0, 2.9, 3.0], s: [2.0, 1.3, 1.5], c: [0, 2.9, 3.65] },
    { p: [0, 2.75, 4.3], s: [1.3, 0.95, 1.5], c: [0, 2.72, 5.0] },
    { p: [0, 2.6, 5.6], s: [0.75, 0.65, 1.3], c: [0, 2.58, 6.15] },
  ], { c: C.body, under: C.belly, band: C.rust, each: (Tc, d) => Tc.sym((s) => s.wedgeF({ name: 'TailSpike', s: [d.s[2] * 0.4, d.s[1] * 0.45, 0.45], p: [d.s[0] / 2 + 0.18, d.c[1], d.c[2]], face: 'right', c: C.bone })) });
  // Massive tail club
  const club = tail.ctxs[2];
  club.box({ name: 'Club', s: [1.7, 1.0, 1.3], p: [0, 2.58, 7.25], c: C.boneLo, studs: 'top' });
  club.sym((s) => s.box({ name: 'ClubKnob', s: [0.7, 0.85, 1.0], p: [0.95, 2.55, 7.25], r: [0, 0, 20], c: C.bone }));
  club.box({ name: 'ClubTip', s: [1.1, 0.75, 0.5], p: [0, 2.55, 7.95], c: C.bone });
  club.box({ name: 'ClubBand', s: [1.75, 1.04, 0.25], p: [0, 2.58, 6.65], c: C.rust });
  club.attach('VFX_Club', [0, 2.55, 7.4]);

  highlight(model);
  return model;
}

module.exports = { build };
