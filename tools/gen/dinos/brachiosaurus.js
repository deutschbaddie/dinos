// DINOSAUR 07 — BRACHIOSAURUS (Epic). Gentle, enormous, majestic. ~32 studs long, ~29 tall.
const { makeDino, seg, boneAt, eye, band, highlight, segBox, quadLeg, tailChain } = require('./common.js');
const { rng } = require('../builder.js');

const C = {
  body: '#c9a46a', bodyHi: '#d8b67e', bodyLo: '#a8844f', olive: '#7a8a45', oliveLo: '#626f36', patch: '#5e4630',
  belly: '#efe0bd', eye: '#3a2410', nail: '#4a3a2a', mouth: '#7a2a2a',
};

function build() {
  const { model, rig } = makeDino('Brachiosaurus', {
    DisplayName: 'Brachiosaurus', Rarity: 'Epic', Classification: 'Giant Herbivore', Personality: 'Gentle, enormous, majestic',
    Locomotion: 'Quadruped', SignatureMove: 'The Giant Awakens',
  }, [6, 7, 12], [0, 12, 1]);
  const S = { c: C.body };
  const R = rng(707);
  const patches = (ctx, cx, cy, cz, sx, sy, sz, n) => {
    for (let i = 0; i < n; i++) {
      const side = R() > 0.5 ? 1 : -1;
      ctx.box({ name: 'Patch', s: [0.1, 0.8 + R() * 1.4, 1.0 + R() * 1.8], p: [cx + side * (sx / 2 + 0.02), cy + (R() - 0.3) * sy * 0.5, cz + (R() - 0.5) * sz * 0.8], c: C.patch, shadow: false });
    }
  };

  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 11.5, 4.5], S);
  P.box({ name: 'Hip', s: [6.0, 5.6, 5.0], p: [0, 11.3, 4.8], studs: 'top' });
  P.box({ name: 'HipSaddle', s: [5.0, 0.8, 4.6], p: [0, 14.3, 4.6], c: C.olive, studs: 'top' });
  P.box({ name: 'HipBelly', s: [5.0, 0.4, 4.6], p: [0, 8.35, 4.6], c: C.belly });
  patches(P, 0, 11.5, 4.8, 6.0, 5.6, 5.0, 5);

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 12.0, 1.8], S);
  const Tt = T.at([0, 12.8, -1.0], [14, 0, 0]);
  Tt.box({ name: 'Torso', s: [6.6, 6.8, 7.0], studs: 'top' });
  Tt.box({ name: 'Saddle', s: [5.4, 0.8, 6.6], p: [0, 3.7, 0], c: C.olive, studs: 'top' });
  Tt.box({ name: 'Belly', s: [5.6, 0.4, 6.6], p: [0, -3.55, 0], c: C.belly });
  patches(Tt, 0, 0, 0, 6.6, 6.8, 7.0, 7);
  T.box({ name: 'Shoulders', s: [6.0, 5.0, 2.4], p: [0, 13.6, -4.4], c: C.bodyLo });
  T.attach('VFX_Chest', [0, 11.0, -5.6]);

  // Five-segment neck towering up and forward
  const neckPts = [[0, 15.2, -5.2], [0, 18.0, -6.6], [0, 20.7, -7.8], [0, 23.2, -8.8], [0, 25.4, -9.6], [0, 27.0, -10.2]];
  const widths = [3.4, 2.9, 2.5, 2.1, 1.8];
  let parentBone = torso, pc = T;
  neckPts.slice(0, 5).forEach((p, i) => {
    const [nb, Nc] = boneAt(rig, pc, `Neck${i + 1}`, parentBone, p, S);
    segBox(Nc, p, neckPts[i + 1], widths[i], widths[i] * 1.05, { name: 'NeckSegment', studs: 'top', extend: widths[i] * 0.45 });
    segBox(Nc, [0, p[1] - 0.3, p[2] - widths[i] * 0.5], [0, neckPts[i + 1][1] - 0.3, neckPts[i + 1][2] - widths[i] * 0.45], widths[i] * 0.7, 0.2, { name: 'Throat', c: C.belly });
    segBox(Nc, [0, p[1] + 0.2, p[2] + widths[i] * 0.5], [0, neckPts[i + 1][1] + 0.2, neckPts[i + 1][2] + widths[i] * 0.48], widths[i] * 0.6, 0.25, { name: 'NeckRidge', c: C.olive });
    if (i % 2 === 0) Nc.box({ name: 'NeckBand', s: [widths[i] + 0.08, 0.6, widths[i] * 0.7], p: [0, (p[1] + neckPts[i + 1][1]) / 2, (p[2] + neckPts[i + 1][2]) / 2], r: [-28, 0, 0], c: C.oliveLo });
    parentBone = nb; pc = Nc;
  });

  const [head, H] = boneAt(rig, pc, 'Head', parentBone, [0, 27.0, -10.2], S);
  H.box({ name: 'Skull', s: [1.8, 1.7, 1.9], p: [0, 27.4, -10.9], studs: 'top' });
  H.box({ name: 'NasalCrest', s: [1.3, 0.9, 1.1], p: [0, 28.55, -10.9], c: C.bodyHi, studs: 'top' });
  H.box({ name: 'Snout', s: [1.4, 1.1, 1.4], p: [0, 27.0, -12.4] });
  H.wedgeF({ name: 'SnoutSlope', s: [1.4, 0.4, 0.8], p: [0, 27.75, -12.5], face: 'front', c: C.bodyHi });
  H.box({ name: 'MouthInterior', s: [1.1, 0.2, 1.6], p: [0, 26.45, -12.0], c: C.mouth });
  H.sym((s, side, n) => {
    eye(s, [0.92, 27.7, -10.9], { h: 0.3, d: 0.4, c: C.eye, lid: C.body });
    s.box({ name: 'Nostril', s: [0.25, 0.2, 0.35], p: [0.45, 28.85, -10.7], c: '#2a1a10' });
    s.box({ name: 'Cheek', s: [0.14, 0.6, 1.0], p: [0.72, 26.9, -11.6], c: C.bodyLo });
    for (let i = 0; i < 4; i++) s.box({ name: 'PegTooth', s: [0.1, 0.22, 0.12], p: [0.55, 26.42, -11.5 - i * 0.38], c: '#f4ecd6', shadow: false });
    s.attach(`VFX_${n}Eye`, [0.95, 27.7, -10.9]);
  });
  H.attach('VFX_Mouth', [0, 26.6, -13.2]);
  H.attach('VFX_Head', [0, 27.6, -11.2]);
  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 26.45, -10.9], S);
  J.box({ name: 'LowerJaw', s: [1.2, 0.45, 2.1], p: [0, 26.2, -12.0] });
  J.box({ name: 'Chin', s: [1.0, 0.4, 0.3], p: [0, 26.25, -13.05], c: C.bodyLo });

  // Pillar legs; fronts are longer (the sloping brachiosaur back)
  const legStyle = { toes: 4, c: C.body, cLo: C.bodyLo, claw: C.nail };
  P.sym((s, side, n) => quadLeg(rig, s, pelvis, n, 'Hind', { hip: [2.9, 10.6, 4.9], knee: [3.15, 6.0, 4.4], ankle: [3.15, 1.8, 5.0] }, Object.assign({
    upper: [2.2, 2.6], lower: [1.8, 1.9], foot: [2.4, 0.9, 2.6], muscle: { s: [2.0, 3.6, 3.4], p: [3.0, 9.0, 4.8] },
  }, legStyle)));
  T.sym((s, side, n) => quadLeg(rig, s, torso, n, 'Front', { hip: [2.85, 12.6, -4.0], knee: [3.15, 7.6, -3.7], ankle: [3.15, 2.0, -4.1] }, Object.assign({
    upper: [2.0, 2.2], lower: [1.7, 1.8], foot: [2.2, 0.9, 2.3], muscle: { s: [1.8, 3.2, 2.6], p: [3.0, 11.4, -4.0] },
  }, legStyle)));

  tailChain(rig, P, pelvis, [
    { p: [0, 12.0, 7.2], s: [4.2, 3.8, 3.2], c: [0, 11.9, 8.6] },
    { p: [0, 11.4, 10.0], s: [3.0, 2.8, 3.0], c: [0, 11.2, 11.4] },
    { p: [0, 10.6, 12.8], s: [2.1, 2.0, 2.9], c: [0, 10.4, 14.2] },
    { p: [0, 9.7, 15.5], s: [1.4, 1.35, 2.7], c: [0, 9.5, 16.8] },
    { p: [0, 8.8, 18.0], s: [0.8, 0.8, 2.4], c: [0, 8.6, 19.1] },
  ], { c: C.body, under: C.belly, band: C.olive });

  highlight(model, '#141414', 0.5);
  return model;
}

module.exports = { build };
