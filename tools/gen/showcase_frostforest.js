// Frost Forest showcase QC stages (row z = -275): snowy set pieces the signatures play against.
// Props (CinematicProp + PropId) are what the signatures target: Perch + Stump (Microraptor), Undergrowth + Twig
// (Psittacosaurus), HollowLog (Compy), SnowPines + ThinIce (Yutyrannus). Display-local: the dino faces -Z.
const { rng } = require('./builder.js');

const SNOW = '#f4f8ff', SNOW2 = '#dde8f6', ICE = '#9fd8f0', BARK = '#5b4232', BARK2 = '#6e5140', PINE = '#24563f', PINE2 = '#2f6a4c', ASH = '#8d8c92';

// a blocky snow-laden pine: stacked studded tiers, each with a snow cap (SnowCap parts drop in PineDump)
function pine(ctx, p, h, seed, name = 'Pine') {
  const R = rng(seed);
  const g = ctx.group(name);
  const t = g.at(p, [0, R() * 360, 0]);
  const base = t.box({ name: 'TreeBase', s: [0.5, 0.5, 0.5], p: [0, 0.25, 0], t: 1, shadow: false });
  g.parent.set('PrimaryPart', 'Ref', base);
  t.box({ name: 'Trunk', s: [0.9, h * 0.45, 0.9], p: [0, h * 0.225, 0], c: BARK, studs: 'sides' });
  const tiers = Math.max(3, Math.round(h / 2.6));
  for (let i = 0; i < tiers; i++) {
    const k = 1 - i / tiers;
    const w = 1.4 + k * h * 0.42;
    const y = h * 0.28 + i * (h * 0.68 / tiers);
    t.box({ name: 'PineTier', s: [w, 1.3, w], p: [0, y, 0], r: [0, i * 23 + R() * 10, 0], c: i % 2 ? PINE : PINE2, studs: 'top' });
    t.box({ name: 'SnowCap', s: [w * 0.82, 0.32, w * 0.82], p: [0, y + 0.8, 0], r: [0, i * 23 + R() * 10 + 8, 0], c: i % 2 ? SNOW : SNOW2 });
  }
  t.box({ name: 'SnowCap', s: [0.7, 0.9, 0.7], p: [0, h * 0.28 + h * 0.68 + 0.2, 0], c: SNOW });
  return g;
}
function drift(ctx, p, k, seed) {
  const R = rng(seed);
  const g = ctx.group('SnowDrift');
  const b = g.at(p, [0, R() * 360, 0]);
  b.box({ name: 'Drift', s: [2.6 * k, 0.5 * k, 1.8 * k], p: [0, 0.25 * k, 0], c: SNOW, studs: 'top' });
  b.box({ name: 'Drift', s: [1.6 * k, 0.4 * k, 1.2 * k], p: [0.5 * k, 0.6 * k, 0.2 * k], r: [0, 20, 0], c: SNOW2 });
  return g;
}
function snowRock(ctx, p, k, seed) {
  const R = rng(seed);
  const g = ctx.group('SnowRock');
  const b = g.at(p, [0, R() * 360, 0]);
  b.box({ name: 'Rock', s: [2.0 * k, 1.3 * k, 1.7 * k], p: [0, 0.6 * k, 0], r: [R() * 8, 0, R() * 10], c: ASH, m: 'Slate' });
  b.box({ name: 'Snow', s: [1.7 * k, 0.25 * k, 1.4 * k], p: [0, 1.3 * k, 0], c: SNOW, studs: 'top' });
  return g;
}
function snowFloor(c, top, r, seed) {
  const R = rng(seed);
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2 + R();
    const d = r * (0.45 + R() * 0.35);
    c.box({ name: 'SnowPatch', s: [1.6 + R() * 1.4, 0.12, 1.2 + R()], p: [Math.cos(a) * d, top + 0.06, Math.sin(a) * d], r: [0, R() * 90, 0], c: i % 2 ? SNOW : SNOW2 });
  }
}

const SLOTS = {
  Microraptor: {
    pos: [-62, -275], yaw: 195, radius: 6,
    build(c, top, H) {
      snowFloor(c, top, 6, 11);
      // the perch: a frost-dead tree with a long snowy branch over the platform (feet land at top + 5.6)
      const [pm, pc] = H.propModel(c, 'Perch');
      const t = pc.at([1.6, top, 5.5]);
      const pv = t.box({ name: 'TreeBase', s: [0.5, 0.5, 0.5], p: [0, 0.25, 0], t: 1, shadow: false });
      pm.set('PrimaryPart', 'Ref', pv);
      for (let i = 0; i < 6; i++) t.box({ name: 'Trunk', s: [1.0 - i * 0.06, 1.5, 1.0 - i * 0.06], p: [Math.sin(i) * 0.08, 0.75 + i * 1.5, 0], r: [0, i * 19, 0], c: i % 2 ? BARK : BARK2, studs: 'sides' });
      t.box({ name: 'Branch', s: [4.4, 0.34, 0.42], p: [-2.0, 5.43, 0], c: BARK2, studs: 'top' });
      t.box({ name: 'SnowCap', s: [3.6, 0.1, 0.46], p: [-2.2, 5.65, 0], c: SNOW });
      t.box({ name: 'Twig', s: [0.18, 0.9, 0.18], p: [-3.5, 5.9, 0.1], r: [0, 0, -30], c: BARK2 });
      t.box({ name: 'Branch', s: [2.2, 0.3, 0.34], p: [1.2, 7.2, 0.3], r: [0, 30, 18], c: BARK2 });
      t.box({ name: 'SnowCap', s: [1.6, 0.12, 0.38], p: [1.2, 7.42, 0.3], r: [0, 30, 18], c: SNOW });
      // the stump it lands on (top at + 0.8)
      const [, sc] = H.propModel(c, 'Stump');
      sc.cyl({ name: 'Stump', axis: 'y', len: 0.72, d: 1.2, p: [0, top + 0.36, 1.4], c: BARK, m: 'Wood' });
      sc.cyl({ name: 'StumpRing', axis: 'y', len: 0.04, d: 1.0, p: [0, top + 0.74, 1.4], c: '#b88a5c' });
      sc.box({ name: 'SnowCap', s: [0.6, 0.06, 0.5], p: [0.2, top + 0.77, 1.55], c: SNOW });
      pine(H.decor, [-8.5, 0, 3], 11, 21);
      drift(H.decor, [7.5, 0, -2], 1, 22);
    },
  },
  Psittacosaurus: {
    pos: [-38, -275], yaw: 180, radius: 7, juveniles: 2,
    build(c, top, H) {
      snowFloor(c, top, 7, 31);
      // undergrowth it hides in: frosty ferns and bushes in front and around the juveniles
      const [, uc] = H.propModel(c, 'Undergrowth');
      const R = rng(33);
      const clump = (x, z, k) => {
        for (let i = 0; i < 6; i++) {
          const a = i * 60 + R() * 20;
          uc.at([x, top, z], [0, a, 0]).box({ name: 'FernLeaf', s: [0.5 * k, 0.12, 1.9 * k], p: [0, 0.65 * k, -0.85 * k], r: [-32, 0, 0], c: i % 2 ? '#3f8a4a' : '#4f9c52' });
        }
        uc.box({ name: 'Frost', s: [0.9 * k, 0.1, 0.9 * k], p: [x, top + 1.05 * k, z], r: [0, R() * 90, 0], c: SNOW2 });
      };
      clump(-1.2, -1.7, 1.1); clump(1.25, -1.6, 1.05); clump(0.05, -2.3, 0.75); clump(-4.6, 2.2, 1.0); clump(4.8, 2.4, 1.0); clump(-2.8, 1.0, 0.9);
      // the twig that snaps
      const [, tc] = H.propModel(c, 'Twig');
      tc.box({ name: 'Twig', s: [1.6, 0.2, 0.2], p: [0.4, top + 0.1, -3.9], r: [0, 25, 0], c: '#8a6448' });
      tc.box({ name: 'Twig', s: [0.6, 0.14, 0.14], p: [0.75, top + 0.12, -3.55], r: [0, -25, 0], c: '#8a6448' });
      tc.box({ name: 'SnowCap', s: [0.7, 0.06, 0.22], p: [0.2, top + 0.23, -3.95], r: [0, 25, 0], c: SNOW });
      pine(H.decor, [-10, 0, 4], 12, 34);
      snowRock(H.decor, [9.5, 0, -1], 1.1, 35);
    },
  },
  Compy: {
    pos: [-14, -275], yaw: 170, radius: 6,
    build(c, top, H) {
      snowFloor(c, top, 6, 41);
      // a hollow log lying along Z, mouth toward the audience at z = 1.0 (the swarm pours out of it)
      const [, lc] = H.propModel(c, 'HollowLog');
      const L = lc.at([0, top + 0.85, 3.5]);
      const n = 10, r = 0.78;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2;
        L.at([Math.cos(a) * r, Math.sin(a) * r, 0], [0, 0, a * 180 / Math.PI]).box({ name: 'LogStave', s: [0.22, 0.52, 5.0], c: i % 2 ? BARK : BARK2, m: 'Wood' });
        L.at([Math.cos(a) * r, Math.sin(a) * r, -2.52], [0, 0, a * 180 / Math.PI]).box({ name: 'LogRim', s: [0.26, 0.56, 0.08], c: '#c99a62' });
      }
      L.box({ name: 'SnowCap', s: [1.1, 0.16, 4.6], p: [0, 0.98, 0.1], c: SNOW, studs: 'top' });
      L.box({ name: 'Moss', s: [0.6, 0.1, 1.4], p: [0.55, 0.8, 1.2], r: [0, 0, -40], c: '#5f8f3e' });
      L.box({ name: 'BranchStub', s: [0.3, 0.8, 0.3], p: [-0.7, 0.9, 1.6], r: [0, 0, 35], c: BARK2 });
      drift(H.decor, [-7.5, 0, -1.5], 0.9, 43);
      pine(H.decor, [8.5, 0, 3.5], 10, 44);
    },
  },
  Yutyrannus: {
    pos: [36, -275], yaw: 180, radius: 19,
    build(c, top, H) {
      snowFloor(c, top, 19, 51);
      // a stand of snow-laden pines behind it (they dump their snow on the roar)
      const [, pc] = H.propModel(c, 'SnowPines');
      for (const [x, z, h, s] of [[-11, 9, 16, 61], [11.5, 8, 17, 62], [-5.5, 15, 18, 63], [6, 15.5, 16, 64], [-14.5, 2, 13, 65], [15, 1, 14, 66]]) pine(pc, [x, top, z], h, s);
      // a frozen pond right in front of it: thin ice that cracks under the stomp
      const [, ic] = H.propModel(c, 'ThinIce');
      ic.cyl({ name: 'Ice', axis: 'y', len: 0.1, d: 12, p: [0, top + 0.05, -5], c: ICE, m: 'Glass', t: 0.15, refl: 0.2 });
      ic.cyl({ name: 'IceRim', axis: 'y', len: 0.08, d: 12.8, p: [0, top + 0.04, -5], c: SNOW2 });
      for (const [x, z, k, sd] of [[-15, -10, 1.2, 67], [15, -9, 1.4, 68]]) drift(H.decor, [x, 0, z], k, sd);
      snowRock(H.decor, [-22, 0, -4], 1.6, 69);
      pine(H.decor, [24, 0, 8], 18, 70);
    },
  },
};

module.exports = { SLOTS, pine, drift, snowRock };
