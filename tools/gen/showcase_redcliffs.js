// Red Cliffs QC stages (cinematic props for the signature cutscenes). Row z = -215 behind the original exhibition.
// slot.build(c, top, H): c = display ctx (local, the creature faces -Z), top = platform top height.
const { rng } = require('./builder.js');

const SAND = ['#d9a066', '#e3b07a', '#c98f55'];
const RED = ['#b4502e', '#c65f36', '#9c4126', '#d27a48'];

// red sandstone block stack (decor, not a prop)
function sandstone(ctx, p, k, seed) {
  const R = rng(seed);
  const g = ctx.group('Rock');
  const b = g.at(p, [0, R() * 360, 0]);
  let y = 0;
  for (let i = 0; i < 3; i++) {
    const w = (2.4 - i * 0.55) * k, h = (0.9 + R() * 0.3) * k;
    b.box({ name: 'Sandstone', s: [w, h, w * (0.8 + R() * 0.3)], p: [(R() - 0.5) * 0.4 * k, y + h / 2, (R() - 0.5) * 0.4 * k], r: [0, R() * 30, 0], c: RED[i % RED.length], studs: 'top', anchored: true });
    y += h;
  }
  return g;
}

// a ground nest of twigs with a ring of long eggs (Oviraptor eggs: teal, orange stripes)
function nest(H, c, p, eggs) {
  const [m, pc] = H.propModel(c, 'Nest');
  const n = pc.at(p);
  const base = n.cyl({ name: 'NestBase', axis: 'y', len: 0.22, d: 1.9, p: [0, 0.11, 0], c: '#9a7a4a', anchored: true });
  m.set('PrimaryPart', 'Ref', base);
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2;
    n.box({ name: 'NestTwig', s: [0.16, 0.18, 0.8], p: [Math.cos(a) * 0.9, 0.3, Math.sin(a) * 0.9], r: [0, -a * 180 / Math.PI, 14], c: i % 2 ? '#7a5a32' : '#8f6c3c', anchored: true });
  }
  for (let i = 0; i < eggs; i++) {
    const a = (i / eggs) * Math.PI * 2 + 0.4;
    const e = n.at([Math.cos(a) * 0.42, 0.42, Math.sin(a) * 0.42], [0, -a * 180 / Math.PI, 0]);
    e.ell({ name: 'NestEgg', s: [0.36, 0.5, 0.36], r: [0, 0, 35], c: '#2f6f8a', anchored: true });
    e.box({ name: 'EggStripe', s: [0.3, 0.06, 0.37], p: [0, 0.04, 0], r: [0, 0, 35], c: '#ff6a2a', anchored: true, shadow: false });
  }
  return m;
}

// a low dune mound that hides a buried Protoceratops (its frill's edge just breaks the top)
function dune(H, c, top) {
  const [m, pc] = H.propModel(c, 'Dune');
  const R = rng(77);
  const base = pc.box({ name: 'DuneSand', s: [3.9, 0.48, 8.8], p: [0, top + 0.24, 0.5], c: SAND[0], studs: 'top', anchored: true });
  m.set('PrimaryPart', 'Ref', base);
  pc.box({ name: 'DuneSand', s: [3.3, 0.36, 6.6], p: [0, top + 0.66, 1.1], c: SAND[1], studs: 'top', anchored: true });
  pc.box({ name: 'DuneSand', s: [2.5, 0.32, 4.2], p: [0, top + 1.0, 1.5], c: SAND[2], studs: 'top', anchored: true });
  pc.box({ name: 'DuneSand', s: [2.4, 0.3, 1.8], p: [0, top + 0.62, -2.0], c: SAND[1], studs: 'top', anchored: true });
  pc.box({ name: 'DuneSand', s: [1.9, 0.22, 1.2], p: [0, top + 0.86, -2.2], c: SAND[2], studs: 'top', anchored: true });
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    pc.box({ name: 'DuneLump', s: [0.9 + R() * 0.6, 0.3, 0.9 + R() * 0.6], p: [Math.cos(a) * 2.0, top + 0.15, 0.5 + Math.sin(a) * 4.4], r: [0, R() * 60, 0], c: SAND[i % 3], anchored: true });
  }
  return m;
}
// a sandstone boulder it head-butts apart
function boulderProp(H, c, p, id) {
  const [m, pc] = H.propModel(c, id);
  const b = pc.at(p);
  const core = b.box({ name: 'Sandstone', s: [1.5, 1.2, 1.3], p: [0, 0.6, 0], r: [0, 18, 4], c: RED[0], studs: 'top', anchored: true, collide: true });
  m.set('PrimaryPart', 'Ref', core);
  b.box({ name: 'Sandstone', s: [1.0, 0.8, 1.0], p: [0.3, 1.45, 0.1], r: [0, -14, 0], c: RED[1], studs: 'top', anchored: true });
  b.box({ name: 'Sandstone', s: [0.8, 0.6, 0.9], p: [-0.7, 0.3, -0.3], r: [0, 30, 0], c: RED[2], anchored: true });
  b.box({ name: 'SandstoneBand', s: [1.56, 0.14, 1.36], p: [0, 0.75, 0], r: [0, 18, 4], c: RED[3], anchored: true, shadow: false });
  return m;
}

const SLOTS = {
  Oviraptor: {
    pos: [-62, -215], yaw: 190, radius: 6,
    build(c, top, H) {
      nest(H, c, [0, top, -2.05], 4);
      sandstone(c, [-3.6, top, 2.8], 0.75, 31);
      sandstone(c, [3.2, top, 3.4], 0.6, 32);
    },
  },
  Protoceratops: {
    pos: [-36, -215], yaw: 180, radius: 7,
    build(c, top, H) {
      dune(H, c, top);
      boulderProp(H, c, [0, top, -6.0], 'Rock');
      sandstone(c, [-4.4, top, 3.4], 0.7, 41);
    },
  },
  Gallimimus: {
    pos: [-6, -215], yaw: 175, radius: 12,
    build(c, top, H) {
      sandstone(c, [-7.5, top, 6.5], 0.8, 51);
      sandstone(c, [8.0, top, 7.0], 0.9, 52);
      for (let i = 0; i < 5; i++) c.box({ name: 'DustStreak', s: [3 + i, 0.06, 0.5], p: [-6 + i * 3.2, top + 0.03, 0.9 + (i % 2) * 0.6], c: SAND[i % 3], anchored: true, shadow: false });
    },
  },
  Therizinosaurus: {
    pos: [40, -215], yaw: 170, radius: 20,
    build(c, top, H) {
      // the grove tree it rakes: the trunk stays, the canopy (the prop) comes down
      const tx = 8.8, tz = -4.0;
      for (let i = 0; i < 8; i++) c.box({ name: 'Trunk', s: [1.7 - i * 0.06, 1.7, 1.7 - i * 0.06], p: [tx + Math.sin(i * 0.6) * 0.15, top + 0.85 + i * 1.7, tz], r: [0, i * 15, 0], c: i % 2 ? '#6b4a2b' : '#7d5733', studs: 'sides', anchored: true });
      const [m, pc] = H.propModel(c, 'Canopy');
      const R = rng(91);
      const cols = ['#4f7a2e', '#5f8f36', '#3f6a28', '#6a9a3a'];
      let first = null;
      for (let k = 0; k < 9; k++) {
        const sz = 3.2 + R() * 2.4;
        const b = pc.box({ name: 'Canopy', s: [sz, sz * 0.6, sz], p: [tx - 1.0 + (R() - 0.5) * 6, top + 15 + R() * 5, tz + (R() - 0.5) * 6], r: [0, R() * 90, 0], c: cols[k % 4], studs: 'top', anchored: true });
        first = first || b;
      }
      for (let k = 0; k < 4; k++) pc.box({ name: 'Branch', s: [0.5, 0.5, 4.2], p: [tx + (k % 2 ? 1.6 : -1.6), top + 12.5 + k * 1.3, tz + (k < 2 ? 1.4 : -1.4)], r: [k * 20 - 30, k * 70, 0], c: '#5e3f22', anchored: true });
      m.set('PrimaryPart', 'Ref', first);
      for (const [x, z, k] of [[-12, 10, 1.2], [13, 11, 1.0], [-15, -4, 0.9]]) sandstone(c, [x, top, z], k, 60 + x);
    },
  },
};

module.exports = { SLOTS, sandstone };
