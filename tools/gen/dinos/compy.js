// FROST FOREST — COMPY (Uncommon; real name Sinosauropteryx, the first feathered dinosaur found with its colours,
// Zhang et al. 2010). A tiny ginger fuzzball with a dark bandit mask over bright eyes and a very long tail ringed
// ginger and white. Comes in swarms. ~3.5 studs long, ~1.4 tall. Forward = -Z.
const { makeDino, seg, boneAt, teeth, claw, eye, highlight, bipedLeg } = require('./common.js');

const C = {
  ginger: '#d8762c', gingerHi: '#ec9444', gingerLo: '#a9561e', fuzz: '#b8621f', cream: '#f7f0e2', creamLo: '#e6dac2',
  mask: '#2b211c', eye: '#ffd23a', mouth: '#7a2a2a', tongue: '#d0606a', tooth: '#f4ecd6', claw: '#2b211c',
};

// a little blocky fuzz tuft (two offset wedges)
function tuft(ctx, p, k = 1, c = C.fuzz, ry = 0) {
  const t = ctx.at(p, [0, ry, 0]);
  t.wedgeF({ name: 'Fuzz', s: [0.1 * k, 0.1 * k, 0.14 * k], p: [0, 0.05 * k, 0], face: 'back', c });
}

function build() {
  const { model, rig } = makeDino('Compy', {
    DisplayName: 'Compy', Rarity: 'Uncommon', Classification: 'Swarm Scavenger', Personality: 'Nosy, cheeky, never alone',
    Locomotion: 'Biped', SignatureMove: 'Swarm',
  }, [0.4, 0.4, 0.9], [0, 0.72, 0]);
  const S = { c: C.ginger };

  // ---------------- Pelvis / torso ----------------
  const [pelvis, P] = boneAt(rig, seg(rig.root), 'Pelvis', rig.root, [0, 0.72, 0.15], S);
  P.box({ name: 'Hip', s: [0.34, 0.34, 0.4], p: [0, 0.75, 0.18], studs: 'top' });
  P.box({ name: 'HipBelly', s: [0.26, 0.05, 0.34], p: [0, 0.565, 0.16], c: C.cream });
  tuft(P, [0, 0.92, 0.08], 1.1); tuft(P, [0, 0.92, 0.3], 1.0, C.gingerLo);

  const [torso, T] = boneAt(rig, P, 'Torso', pelvis, [0, 0.75, -0.04], S);
  T.box({ name: 'Chest', s: [0.36, 0.36, 0.46], p: [0, 0.77, -0.28], studs: 'top' });
  T.box({ name: 'ChestFluff', s: [0.28, 0.28, 0.1], p: [0, 0.72, -0.53], c: C.cream });
  T.box({ name: 'Belly', s: [0.28, 0.05, 0.4], p: [0, 0.585, -0.28], c: C.cream });
  tuft(T, [0, 0.95, -0.14], 1.1, C.gingerLo); tuft(T, [0, 0.95, -0.38], 1.2);
  T.sym((q) => { tuft(q, [0.17, 0.86, -0.2], 0.8, C.gingerLo, 90); tuft(q, [0.17, 0.8, -0.4], 0.7, C.fuzz, 90); });
  P.sym((q) => tuft(q, [0.16, 0.84, 0.25], 0.8, C.fuzz, 90));
  T.attach('VFX_Chest', [0, 0.72, -0.56]);

  // ---------------- Neck / head (bandit mask) ----------------
  const [neck, N] = boneAt(rig, T, 'Neck', torso, [0, 0.86, -0.46], S);
  const Nf = N.at([0, 0.86, -0.46], [-32, 0, 0]);
  Nf.box({ name: 'Neck', s: [0.18, 0.4, 0.2], p: [0, 0.17, 0] });
  Nf.box({ name: 'Throat', s: [0.13, 0.34, 0.04], p: [0, 0.15, -0.11], c: C.cream });
  tuft(Nf, [0, 0.36, 0.08], 0.9, C.gingerLo);

  const [head, H] = boneAt(rig, N, 'Head', neck, [0, 1.17, -0.66], S);
  H.box({ name: 'Cranium', s: [0.28, 0.26, 0.32], p: [0, 1.27, -0.78], studs: 'top' });
  H.box({ name: 'Snout', s: [0.17, 0.14, 0.3], p: [0, 1.22, -1.06], c: C.gingerHi });
  H.wedgeF({ name: 'SnoutSlope', s: [0.17, 0.07, 0.2], p: [0, 1.325, -0.98], face: 'front', c: C.gingerHi });
  H.box({ name: 'NoseTip', s: [0.14, 0.11, 0.05], p: [0, 1.21, -1.23], c: C.gingerHi });
  H.box({ name: 'Mask', s: [0.3, 0.1, 0.24], p: [0, 1.3, -0.84], c: C.mask });
  H.box({ name: 'MaskStripe', s: [0.08, 0.05, 0.2], p: [0, 1.34, -1.0], c: C.mask });
  H.box({ name: 'MouthInterior', s: [0.12, 0.04, 0.28], p: [0, 1.15, -1.02], c: C.mouth });
  H.sym((s, side, n) => {
    eye(s, [0.155, 1.3, -0.86], { h: 0.1, d: 0.12, c: C.eye, lid: C.mask, socket: C.mask });
    s.box({ name: 'Cheek', s: [0.04, 0.08, 0.2], p: [0.14, 1.2, -0.85], c: C.cream });
    teeth(s, { n: 3, x: 0.06, y: 1.15, z0: -0.96, z1: -1.18, h: 0.04, d: 0.035, w: 0.025, dir: 'down', c: C.tooth });
    s.attach(`VFX_${n}Eye`, [0.18, 1.3, -0.86]);
  });
  tuft(H, [0, 1.4, -0.68], 1.0, C.gingerLo, 0); tuft(H, [0.06, 1.39, -0.62], 0.8, C.fuzz, -20); tuft(H, [-0.06, 1.39, -0.62], 0.8, C.fuzz, 20);
  H.attach('VFX_Head', [0, 1.28, -0.86]);
  H.attach('VFX_Mouth', [0, 1.17, -1.27]);

  const [jaw, J] = boneAt(rig, H, 'Jaw', head, [0, 1.16, -0.74], S);
  J.box({ name: 'LowerJaw', s: [0.15, 0.06, 0.4], p: [0, 1.12, -1.0], c: C.ginger });
  J.box({ name: 'JawUnderside', s: [0.12, 0.03, 0.36], p: [0, 1.085, -0.98], c: C.cream });
  J.box({ name: 'Tongue', s: [0.07, 0.02, 0.2], p: [0, 1.155, -0.95], c: C.tongue });

  // ---------------- Arms (tiny, with a big thumb claw) ----------------
  T.sym((s, side, n) => {
    const [arm, A] = boneAt(rig, s, `${n}Arm`, torso, [0.17, 0.7, -0.44], S);
    A.box({ name: 'UpperArm', s: [0.07, 0.17, 0.08], p: [0.2, 0.63, -0.47], r: [15, 0, 0], c: C.gingerLo });
    const [fore, F] = boneAt(rig, A, `${n}Forearm`, arm, [0.2, 0.55, -0.5], S);
    F.box({ name: 'Forearm', s: [0.06, 0.15, 0.06], p: [0.2, 0.5, -0.55], r: [-40, 0, 0], c: C.gingerLo });
    claw(F, [0.2, 0.44, -0.62], { s: 0.08, c: C.claw });
    if (n === 'Right') F.attach('VFX_RightClaw', [0.2, 0.44, -0.64]);
  });

  // ---------------- Legs ----------------
  P.sym((s, side, n) => bipedLeg(rig, s, pelvis, n, { hip: [0.13, 0.7, 0.18], knee: [0.17, 0.42, 0.02], ankle: [0.17, 0.21, 0.2], ball: [0.17, 0.04, 0.06] }, {
    thigh: [0.16, 0.2], shin: [0.09, 0.1], meta: [0.07, 0.07], toeLen: 0.14, toeW: 0.05, toeH: 0.05, c: C.ginger, cLo: C.gingerLo, claw: C.claw,
  }));

  // ---------------- The long ringed tail ----------------
  const n = 6;
  let parent = pelvis, pc = P;
  for (let i = 0; i < n; i++) {
    const z0 = 0.35 + i * 0.33, w = 0.25 - i * 0.032, h = 0.23 - i * 0.03;
    const d = { p: [0, 0.78 + i * 0.012, z0], s: [w, h, 0.34], c: [0, 0.78 + i * 0.012, z0 + 0.165] };
    const [tb, Tc] = boneAt(rig, pc, `Tail${i + 1}`, parent, d.p, S);
    Tc.box({ name: 'TailSegment', s: d.s, p: d.c, studs: i < 2 ? 'top' : undefined, c: C.ginger });
    Tc.box({ name: 'TailRing', s: [w + 0.03, h + 0.03, 0.14], p: [0, d.c[1], z0 + 0.26], c: C.cream });
    if (i < 3) tuft(Tc, [0, d.c[1] + h / 2, z0 + 0.08], 0.8 - i * 0.12, C.gingerLo);
    if (i === n - 1) {
      Tc.box({ name: 'TailTip', s: [w * 0.8, h * 0.8, 0.12], p: [0, d.c[1], z0 + 0.39], c: C.mask });
      Tc.attach('VFX_TailTip', [0, d.c[1], z0 + 0.45]);
    }
    parent = tb; pc = Tc;
  }

  highlight(model);
  return model;
}

module.exports = { build };
