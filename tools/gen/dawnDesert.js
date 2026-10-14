// DAWN DESERT — the fifth-oldest stop on the clock (215,000,000 BC): the Late Triassic, when the first dinosaurs were
// still small. A red desert at sunrise: rolling red dunes, banded "painted" clay hills (purple, white, red strata that
// run unbroken from hill to hill), the Stone Forest of giant petrified logs with rainbow-quartz ends, braided-river
// oases of horsetails, tree ferns and early conifers under the Blue Mesa, and the Bone Wash, a dry riverbed where the
// Postosuchus waits in the mud.
//   Sunrise Road → fork: Red Dunes (over the dune crests) | Painted Wash (between the banded hills) → Stone Forest
//   (under the Quartz Bridge; Tall Cycads / Plateosaurus, the Bone Wash den, the Stump Circle, Crest Rocks /
//   Dilophosaurus) → fork: Oasis Run (braided channels, Oasis Pack / Coelophysis) | Mesa Rim (along the top of the
//   Blue Mesa, jump the slot canyon) → Homestretch past the Teepees → Return Portal.
//   Zone-local space: origin = DD_ORIGIN, north = -Z.
const { Inst, Ctx, CF, shade, mix, rng } = require('./builder.js');
const E = require('./env.js');
const RT = require('./route.js');
const NPC = require('./npcs.js');
const { buildEgg } = require('./eggs.js');
const B = require('./builder.js');

const DD_ORIGIN = [-2100, 0, -900];
const GROUND = 0.5, ROAD = 0.62;
const BX = 440, BZ0 = -340, BZ1 = 400;
const CELL = 12, STEP = 1.2, BAND = 2.4;
const P = {
  sand: ['#d9683a', '#e0753f', '#cf5e34', '#e5824a'], sandHi: '#efa062', sandLo: '#b84f2e', sandSide: '#c25a34',
  flat: ['#e6a07e', '#dc8e6a', '#eab08e'], alkali: '#f1dcc8',
  road: '#e2b58a', roadLo: '#c99a70', roadHi: '#ecc59e',
  petri: ['#a8786a', '#b48a74', '#9a6a5e', '#c0907a', '#8e7080', '#b06a52'],
  quartz: ['#ff6a4a', '#ffa33a', '#ffd84a', '#ff7ab4', '#58c8ff', '#b07aff'], core: ['#c86bff', '#4fd2ff', '#ff4fa0', '#6affc8', '#ffe24f'],
  bone: '#f2e6cc', boneLo: '#e2d2b0', mud: '#8a5a44', mudLo: '#6e4434', mudWet: '#4e3026', crack: '#4a2c22',
  rock: ['#b8452e', '#9e3a2a', '#cc5a3a', '#87302a'], redRock: ['#c0412e', '#d5573a', '#a33424', '#e06a44'],
  horsetail: ['#5aa83a', '#4c9632', '#68b844'], fern: ['#4fb043', '#3f9a3a', '#5bbd4a'], conifer: ['#2f6a44', '#3a7a4c', '#285c3c'],
  cycad: ['#6a9a3a', '#7aa842', '#5a8a34'], scrub: ['#8a9a5a', '#9aa86a', '#7a8a4a', '#a88a5a'],
  water: '#3fb6bc', waterHi: '#62d0cc', bank: '#efd2b0', bark: ['#7a5236', '#6a4630', '#8a5e3c'],
};
// the strata of the painted hills, bottom to top; a hill's colour at any height comes from here, so the bands run
// unbroken across every hill, mound, mesa and cut bank in the era (that's what makes it read as the Painted Desert)
const BANDS = ['#9a3f3a', '#c75a46', '#e89a86', '#f3e8dc', '#b993c4', '#8c6aa6', '#efe2d6', '#7f8cb0', '#d4744a', '#f6dcbc', '#c75a46', '#b993c4'];
const bandAt = (y) => BANDS[((Math.floor(y / BAND) % BANDS.length) + BANDS.length) % BANDS.length];

function marker(ctx, name, p, yaw = 0, o = {}) {
  const m = ctx.box({ name, s: o.s || [1, 1, 1], p, r: [0, yaw, 0], t: 1, shadow: false, c: '#ffffff' });
  m.set('CanQuery', 'bool', false);
  m.set('CanCollide', 'bool', false);
  return m;
}

const DEF = {
  start: 'Arrival',
  nodes: { Arrival: { tangent: [0, 0, -1] }, ForkA: {}, MergeA: {}, ForkB: {}, MergeB: {}, Exit: {} },
  segments: {
    SunriseRoad: { from: 'Arrival', to: 'ForkA', width: 28, name: 'SUNRISE ROAD', pts: [[-330, 0, 350], [-334, 1, 280], [-322, 2, 210], [-306, 1, 160], [-306, 0, 110]] },
    RedDunes: { from: 'ForkA', to: 'MergeA', width: 24, name: 'RED DUNES', pts: [[-306, 0, 110], [-350, 3, 64], [-378, 7, 0], [-376, 4, -60], [-356, 8, -112], [-318, 2, -150], [-290, 0, -176]] },
    PaintedWash: { from: 'ForkA', to: 'MergeA', width: 24, name: 'PAINTED WASH', pts: [[-306, 0, 110], [-262, 0, 70], [-236, 0, 10], [-236, 0, -62], [-258, 0, -126], [-290, 0, -176]] },
    StoneForest: {
      from: 'MergeA', to: 'ForkB', width: 28, name: 'STONE FOREST',
      pts: [[-290, 0, -176], [-262, 0, -236], [-196, 0, -264], [-110, 0, -262], [-30, 0, -244], [50, 0, -252], [140, 0, -262], [226, 0, -236], [292, 0, -186], [326, 0, -120], [334, 0, -50]],
    },
    OasisRun: { from: 'ForkB', to: 'MergeB', width: 24, name: 'OASIS RUN', pts: [[334, 0, -50], [376, 0, 4], [396, 0, 80], [384, 0, 160], [340, 0, 222], [282, 0, 256]] },
    MesaRim: { from: 'ForkB', to: 'MergeB', width: 22, name: 'MESA RIM', pts: [[334, 0, -50], [298, 5, -6], [266, 13.8, 56], [252, 13.8, 126], [258, 13.8, 186], [270, 6, 230], [282, 0, 256]] },
    Homestretch: { from: 'MergeB', to: 'Exit', width: 28, name: 'HOMESTRETCH', pts: [[282, 0, 256], [236, 0, 300], [176, 0, 334], [110, 0, 352], [50, 0, 360]] },
  },
};

const SECTIONS = [
  ['SunriseRoad', 0, 'SUNRISE ROAD'], ['RedDunes', 0, 'RED DUNES'], ['PaintedWash', 0, 'PAINTED WASH'],
  ['StoneForest', 0, 'STONE FOREST'], ['StoneForest', 330, 'BONE WASH'], ['StoneForest', 590, 'CREST ROCKS'],
  ['OasisRun', 0, 'OASIS RUN'], ['MesaRim', 0, 'MESA RIM'], ['Homestretch', 0, 'HOMESTRETCH'],
];
const NESTS = [
  { id: 1, species: 'Coelophysis', seg: 'OasisRun', s: 150, x: 48, guard: 'Pack', label: 'OASIS PACK' },
  { id: 2, species: 'Plateosaurus', seg: 'StoneForest', s: 118, x: 40, guard: 'Herd', label: 'TALL CYCADS' },
  { id: 3, species: 'Dilophosaurus', seg: 'StoneForest', s: 690, x: -40, guard: 'Brute', label: 'CREST ROCKS' },
];
const FEATURES = [
  ['Darts', 'SunriseRoad', 200, 6], ['Darts', 'StoneForest', 105, -7], ['Darts', 'StoneForest', 430, 0], ['Darts', 'OasisRun', 40, 0], ['Darts', 'MesaRim', 70, 0], ['Darts', 'Homestretch', 85, 6],
  // sunrise road: the long run in teaches boost
  ['Boost', 'SunriseRoad', 50, 0], ['Coin', 'SunriseRoad', 75, 6], ['Coin', 'SunriseRoad', 81, 6], ['Coin', 'SunriseRoad', 87, 6],
  ['Boost', 'SunriseRoad', 150, -7], ['Coin', 'SunriseRoad', 175, -7], ['Coin', 'SunriseRoad', 181, -7], ['Repair', 'SunriseRoad', 225, -8],
  // red dunes: coins on the crests
  ['Coin', 'RedDunes', 40, 0], ['Coin', 'RedDunes', 46, 0], ['Boost', 'RedDunes', 100, 0], ['Coin', 'RedDunes', 150, 0], ['Coin', 'RedDunes', 156, 0], ['Coin', 'RedDunes', 162, 0],
  ['Darts', 'RedDunes', 205, 0], ['Repair', 'RedDunes', 255, 0], ['Coin', 'RedDunes', 300, 6],
  // painted wash: flat and fast between the banded hills
  ['Coin', 'PaintedWash', 50, 7], ['Coin', 'PaintedWash', 56, 7], ['Boost', 'PaintedWash', 110, 0], ['Coin', 'PaintedWash', 170, -6], ['Coin', 'PaintedWash', 176, -6],
  ['Darts', 'PaintedWash', 210, 0], ['Repair', 'PaintedWash', 240, 0],
  // the stone forest, the bone wash and the crest rocks
  ['Coin', 'StoneForest', 60, 8], ['Coin', 'StoneForest', 66, 8], ['Boost', 'StoneForest', 140, 0], ['Coin', 'StoneForest', 200, 0], ['Coin', 'StoneForest', 206, 0],
  ['Repair', 'StoneForest', 290, 8], ['Boost', 'StoneForest', 330, 0], ['Coin', 'StoneForest', 470, -8], ['Boost', 'StoneForest', 520, -6],
  ['Coin', 'StoneForest', 600, 8], ['Coin', 'StoneForest', 606, 8], ['Charge', 'StoneForest', 650, 0, { len: 60 }], ['Repair', 'StoneForest', 745, 6],
  // oasis run: through the braided channels
  ['Coin', 'OasisRun', 70, 0], ['Coin', 'OasisRun', 76, 0], ['Boost', 'OasisRun', 110, 0], ['Repair', 'OasisRun', 200, 0], ['Coin', 'OasisRun', 262, 8], ['Coin', 'OasisRun', 268, 8],
  // mesa rim: along the top, then jump the slot canyon
  ['Boost', 'MesaRim', 128, 0], ['Jump', 'MesaRim', 180, 0, { len: 30 }], ['Coin', 'MesaRim', 204, 0], ['Coin', 'MesaRim', 210, 0], ['Coin', 'MesaRim', 216, 0],
  ['Stampede', 'Homestretch', 110, 0, { len: 50 }], ['Boost', 'Homestretch', 150, 0], ['Coin', 'Homestretch', 180, -6], ['Coin', 'Homestretch', 186, -6],
];
// the ruler's den off the right of the Stone Forest, the final stand among petrified stumps further on
const DEN = { seg: 'StoneForest', s: 380, x: 80, r: 44 };
const FINAL = { seg: 'StoneForest', s: 560, x: 62 };
const BRIDGE = { seg: 'StoneForest', s: 232 };
const TEEPEES = [30, 0, 120];
const MESA_HALF = 42, MESA_TOP = 13.2;
const WASH_HW = 12;
// the braided river of the oasis: channels at the foot of the Blue Mesa (local x, z)
const BRAIDS = [
  { w: 9, pts: [[300, -64], [318, -14], [326, 46], [318, 108], [320, 168], [300, 222], [262, 290], [236, 330]] },
  { w: 7, pts: [[318, -14], [352, 12], [386, 30], [414, 70], [420, 128], [402, 178], [362, 200], [330, 214], [304, 220]] },
];
const POOLS = [[300, -64, 26], [342, 150, 16], [416, 112, 18]];

// ------------------------------------------------------------------ helpers
function noise2(seed) {
  const hash = (i, j) => { let h = (i * 374761393 + j * 668265263 + seed * 2246822519) | 0; h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967295 * 2 - 1; };
  return (x, y) => {
    const i = Math.floor(x), j = Math.floor(y), fx = x - i, fy = y - j;
    const u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy);
    const a = hash(i, j), b = hash(i + 1, j), c = hash(i, j + 1), d = hash(i + 1, j + 1);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  };
}
const smooth = (e0, e1, v) => { const t = Math.max(0, Math.min(1, (v - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };
const distSeg = (x, z, a, b) => {
  const dx = b[0] - a[0], dz = b[1] - a[1];
  const t = Math.max(0, Math.min(1, ((x - a[0]) * dx + (z - a[1]) * dz) / (dx * dx + dz * dz || 1)));
  return Math.hypot(x - a[0] - dx * t, z - a[1] - dz * t);
};
const distPoly = (x, z, pts) => { let d = Infinity; for (let i = 0; i < pts.length - 1; i++) d = Math.min(d, distSeg(x, z, pts[i], pts[i + 1])); return d; };
const yawOf = (f) => E.deg(Math.atan2(-f.f[0], -f.f[2]));
const braidDist = (x, z) => { let d = Infinity; for (const b of BRAIDS) d = Math.min(d, distPoly(x, z, b.pts) - b.w / 2); for (const [px, pz, r] of POOLS) d = Math.min(d, Math.hypot(x - px, z - pz) - r / 2); return d; };

// greedy-merged columns: every cell carries a stack of slabs; slabs with the same height range and colour merge
// across neighbouring cells into one part (so a striped hillside costs a handful of parts per band)
function emitSlabs(G, cols) {
  const groups = new Map();
  for (const c of cols) for (const s of c.slabs) {
    const sig = [s.y0.toFixed(2), s.y1.toFixed(2), s.c, s.name, s.m || ''].join('|');
    if (!groups.has(sig)) groups.set(sig, { s, cells: new Map() });
    groups.get(sig).cells.set(c.i + ',' + c.j, c);
  }
  let parts = 0;
  for (const { s, cells } of groups.values()) {
    const left = new Map(cells);
    const keys = [...left.keys()].sort((a, b) => { const [ai, aj] = a.split(',').map(Number), [bi, bj] = b.split(',').map(Number); return aj - bj || ai - bi; });
    for (const k of keys) {
      if (!left.has(k)) continue;
      const c = left.get(k);
      let w = 1;
      while (left.has((c.i + w) + ',' + c.j) && w < 18) w++;
      let d = 1;
      grow: while (d < 18) {
        for (let u = 0; u < w; u++) if (!left.has((c.i + u) + ',' + (c.j + d))) break grow;
        d++;
      }
      for (let u = 0; u < w; u++) for (let v = 0; v < d; v++) left.delete((c.i + u) + ',' + (c.j + v));
      const cx = c.x + ((w - 1) / 2) * CELL, cz = c.z + ((d - 1) / 2) * CELL;
      G.box({ name: s.name, s: [w * CELL, s.y1 - s.y0, d * CELL], p: [cx, (s.y0 + s.y1) / 2, cz], c: s.c, m: s.m, studs: s.studs, collide: true });
      parts++;
    }
  }
  return parts;
}

// ------------------------------------------------------------------ plants of the Triassic
// horsetails: clumps of tall jointed green stalks with dark rings and a little cone on top (they grow in the water)
function horsetails(ctx, p, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group('Horsetails');
  const n = o.n || 5;
  for (let k = 0; k < n; k++) {
    const h = (o.h || 5) * (0.6 + R() * 0.6);
    const x = p[0] + (R() - 0.5) * (o.spread || 3.4), z = p[2] + (R() - 0.5) * (o.spread || 3.4);
    const c = g.at([x, p[1], z], [(R() - 0.5) * 8, R() * 90, (R() - 0.5) * 8]);
    c.box({ name: 'HorsetailStalk', s: [0.5, h, 0.5], p: [0, h / 2, 0], c: P.horsetail[k % 3], studs: 'sides' });
    for (let j = 1; j <= Math.floor(h / 2.2); j++) c.box({ name: 'HorsetailRing', s: [0.62, 0.22, 0.62], p: [0, j * 2.2, 0], c: '#2f4a22', shadow: false });
    if (h > 3.5) c.box({ name: 'HorsetailWhorl', s: [1.8, 0.12, 0.14], p: [0, h * 0.62, 0], r: [0, k * 40, -12], c: P.horsetail[(k + 1) % 3], shadow: false });
    c.box({ name: 'HorsetailCone', s: [0.6, 0.9, 0.6], p: [0, h + 0.4, 0], c: '#8a7a3a' });
  }
  return g;
}
function treeFern(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('TreeFern');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = Math.max(2, Math.round(h / 2.4));
  for (let i = 0; i < n; i++) t.box({ name: 'FernTrunk', s: [1.1, 2.5, 1.1], p: [0, 1.2 + i * 2.4, 0], r: [0, i * 30, (R() - 0.5) * 6], c: i % 2 ? '#5e4a2e' : '#6e5636', studs: 'sides', collide: i === 0 });
  const top = t.at([0, n * 2.4 + 0.3, 0]);
  top.box({ name: 'FernCrown', s: [1.6, 0.8, 1.6], c: '#3f7a2e' });
  for (let i = 0; i < 7; i++) {
    const f = top.at([0, 0, 0], [0, i * 51 + R() * 12, 0]);
    f.box({ name: 'Frond', s: [1.2, 0.2, 3.6], p: [0, 0.5, -1.8], r: [18, 0, 0], c: P.fern[i % 3], studs: 'top' });
    f.box({ name: 'FrondTip', s: [0.7, 0.16, 2.4], p: [0, -0.2, -4.6], r: [-30, 0, 0], c: P.fern[(i + 1) % 3] });
  }
  return g;
}
// an early conifer: a straight trunk carrying short drooping tiers all the way up (a dark narrow spire)
function conifer(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('Conifer');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = Math.max(3, Math.round(h / 3.4));
  for (let i = 0; i < n; i++) t.box({ name: 'ConiferTrunk', s: [1.1 - i * 0.04, 3.5, 1.1 - i * 0.04], p: [0, 1.7 + i * 3.4, 0], r: [0, i * 21, 0], c: P.bark[i % 3], studs: 'sides', collide: i === 0 });
  const tiers = Math.max(4, Math.round(h / 3));
  for (let k = 0; k < tiers; k++) {
    const u = k / (tiers - 1);
    const y = h * 0.3 + u * h * 0.68;
    const r = (1 - u * 0.8) * (h * 0.13 + 1.4);
    t.box({ name: 'ConiferTier', s: [r * 2, 2, r * 2], p: [0, y, 0], r: [0, k * 45 + R() * 10, 0], c: P.conifer[k % 3], studs: 'top' });
    if (r > 1.6) t.box({ name: 'ConiferDroop', s: [r * 1.5, 1, r * 1.5], p: [0, y - 1.3, 0], r: [0, k * 45 + 22, 0], c: P.conifer[(k + 1) % 3] });
  }
  t.box({ name: 'ConiferTip', s: [0.9, 2.4, 0.9], p: [0, h + 0.9, 0], c: P.conifer[0] });
  return g;
}
// cycad: a scaly trunk with a crown of stiff fronds; tall ones are what the Plateosaurus rears up for
function cycad(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('Cycad');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = Math.max(1, Math.round(h / 1.6));
  for (let i = 0; i < n; i++) t.box({ name: 'CycadTrunk', s: [1.5, 1.7, 1.5], p: [0, 0.85 + i * 1.6, 0], r: [0, i * 45, (R() - 0.5) * 3], c: i % 2 ? '#7a5a36' : '#8a6a3e', studs: 'sides', collide: i === 0 });
  const top = t.at([0, n * 1.6 + 0.2, 0]);
  for (let i = 0; i < 7; i++) {
    const f = top.at([0, 0, 0], [0, i * 51 + R() * 10, 0]);
    f.box({ name: 'CycadFrond', s: [0.9, 0.2, 4], p: [0, 0.8, -1.8], r: [34, 0, 0], c: P.cycad[i % 3], studs: 'top' });
    f.box({ name: 'CycadFrondTip', s: [0.7, 0.18, 2.4], p: [0, 1.6, -4.4], r: [8, 0, 0], c: P.cycad[(i + 1) % 3] });
  }
  top.box({ name: 'CycadCone', s: [1, 1.4, 1], p: [0, 0.7, 0], c: '#e0a43a' });
  return g;
}
function snag(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('Snag');
  const c = g.at(p, [0, R() * 360, 0]);
  c.box({ name: 'SnagTrunk', s: [0.9, h, 0.9], p: [0, h / 2, 0], r: [R() * 8, 0, R() * 8], c: '#b8aa98' });
  c.box({ name: 'SnagArm', s: [0.45, h * 0.35, 0.45], p: [0.7, h * 0.72, 0], r: [0, 0, -42], c: '#a89a88' });
  if (R() > 0.4) c.box({ name: 'SnagArm', s: [0.4, h * 0.25, 0.4], p: [-0.6, h * 0.5, 0.2], r: [0, 0, 38], c: '#a89a88' });
  return g;
}
function quartzChips(ctx, p, seed, n = 5, spread = 4) {
  const R = rng(seed);
  const g = ctx.group('QuartzChips');
  for (let k = 0; k < n; k++) {
    const s = 0.35 + R() * 0.5;
    g.box({ name: 'QuartzChip', s: [s, s * 0.8, s], p: [p[0] + (R() - 0.5) * spread, p[1] + s * 0.3, p[2] + (R() - 0.5) * spread], r: [R() * 40, R() * 90, R() * 40], c: P.quartz[Math.floor(R() * P.quartz.length)], m: 'Glass', shadow: false });
  }
  return g;
}

// ------------------------------------------------------------------ rock of the painted desert
// a petrified log lying in the sand: broken into rounds, every break showing rings of rainbow quartz
function petrifiedLog(ctx, p, yaw, L, d, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group(o.name || 'PetrifiedLog');
  const c = g.at(p, [0, yaw, 0]);
  const n = Math.max(2, Math.round(L / (d * 1.6 + 2)));
  const step = L / n;
  const bark = P.petri[Math.floor(R() * P.petri.length)];
  const ring = P.quartz[Math.floor(R() * P.quartz.length)], ring2 = P.quartz[Math.floor(R() * P.quartz.length)];
  const core = P.core[Math.floor(R() * P.core.length)];
  const y0 = o.y !== undefined ? o.y : d * 0.4;
  let drift = 0;
  for (let k = 0; k < n; k++) {
    const x = -L / 2 + (k + 0.5) * step;
    // the rounds have settled: a little out of line, some rolled aside
    if (R() > 0.7) drift += (R() - 0.5) * d * 0.5;
    const seg = c.at([x, y0 - R() * 0.25, drift], [0, (R() - 0.5) * 7, (R() - 0.5) * 3]);
    const sl = step - 0.6 - R() * 0.6;
    seg.cyl({ name: 'LogRound', axis: 'x', len: sl, d, c: k % 2 ? bark : shade(bark, 0.92), m: 'Slate', collide: d > 2.4 });
    seg.box({ name: 'BarkRidge', s: [sl * 0.8, d * 0.18, d * 0.3], p: [0, d * 0.47, (R() - 0.5) * d * 0.3], c: shade(bark, 1.08), m: 'Slate' });
    // both cut faces of the round: an outer ring of colour and a glassy core
    for (const sd of [-1, 1]) {
      if (k > 0 && k < n - 1 && R() > 0.75) continue;
      seg.cyl({ name: 'QuartzRing', axis: 'x', len: 0.24, d: d * 0.82, p: [sd * (sl / 2 + 0.02), 0, 0], c: (k + (sd > 0 ? 1 : 0)) % 2 ? ring : ring2, m: 'Glass', shadow: false });
      seg.cyl({ name: 'QuartzCore', axis: 'x', len: 0.3, d: d * 0.42, p: [sd * (sl / 2 + 0.05), 0, 0], c: core, m: 'Glass', shadow: false });
    }
  }
  return g;
}
// a petrified stump still standing, glittering on top
function stump(ctx, p, h, d, seed) {
  const R = rng(seed);
  const g = ctx.group('PetrifiedStump');
  const c = g.at(p, [0, R() * 360, (R() - 0.5) * 6]);
  const bark = P.petri[Math.floor(R() * P.petri.length)];
  c.cyl({ name: 'StumpWood', axis: 'y', len: h, d, p: [0, h / 2, 0], c: bark, m: 'Slate', collide: true });
  c.cyl({ name: 'StumpFlare', axis: 'y', len: h * 0.3, d: d * 1.25, p: [0, h * 0.15, 0], c: shade(bark, 0.9), m: 'Slate', collide: true });
  // bark ridges up the sides and jagged splinters round the broken top
  for (let k = 0; k < 4; k++) {
    const a = (k / 4) * Math.PI * 2 + R();
    c.at([0, 0, 0], [0, -E.deg(a), 0]).box({ name: 'StumpRidge', s: [d * 0.22, h * (0.7 + R() * 0.3), d * 0.3], p: [d * 0.48, h * 0.4, 0], c: shade(bark, k % 2 ? 1.1 : 0.88), m: 'Slate' });
    if (R() > 0.35) c.at([0, 0, 0], [0, -E.deg(a) + 40, 0]).box({ name: 'StumpSplinter', s: [d * 0.2, 0.8 + R() * 1.6, d * 0.3], p: [d * 0.4, h + 0.4, 0], r: [0, 0, (R() - 0.5) * 16], c: shade(bark, 1.05), m: 'Slate' });
  }
  c.cyl({ name: 'QuartzRing', axis: 'y', len: 0.3, d: d * 0.84, p: [0, h + 0.05, 0], c: P.quartz[Math.floor(R() * P.quartz.length)], m: 'Glass', shadow: false });
  c.cyl({ name: 'QuartzCore', axis: 'y', len: 0.4, d: d * 0.44, p: [0, h + 0.12, 0], c: P.core[Math.floor(R() * P.core.length)], m: 'Glass', shadow: false });
  for (let k = 0; k < 3; k++) c.box({ name: 'QuartzSpike', s: [0.5, 1 + R() * 1.2, 0.5], p: [(R() - 0.5) * d * 0.4, h + 0.6, (R() - 0.5) * d * 0.4], r: [(R() - 0.5) * 30, R() * 90, (R() - 0.5) * 30], c: P.core[(k + seed) % P.core.length], m: 'Glass', shadow: false });
  return g;
}
// a "teepee": a banded clay cone, its stripes the same strata as the hills around it (colour by world height)
function teepee(ctx, p, r, h, seed, o = {}) {
  const R = rng(seed);
  // landmarks (o.fixed) build straight into their set piece so the decor QC never prunes them
  const g = o.fixed ? ctx : ctx.group(o.name || 'Teepee');
  const yaw = R() * 90;
  const c = g.at(p, [0, yaw, 0]);
  const n = Math.max(3, Math.round(h / BAND));
  const lh = h / n;
  const squash = o.squash || 1;
  for (let k = 0; k < n; k++) {
    const u = k / n;
    const rk = r * Math.pow(1 - u, o.round ? 0.5 : 0.85) + 0.8;
    const col = bandAt(p[1] + k * lh + 0.01);
    for (const a of [0, 45]) c.box({ name: 'TeepeeBand', s: [rk * 2, lh + 0.02, rk * 2 * squash], p: [(R() - 0.5) * 0.4, k * lh + lh / 2, 0], r: [0, a, 0], c: col, m: 'Sand', studs: 'top', collide: k < n - 1 });
  }
  c.box({ name: 'TeepeeCap', s: [1.8, 1.4, 1.8], p: [0, h + 0.5, 0], r: [0, 20, 6], c: '#6e5a5e', m: 'Slate', studs: 'top' });
  return g;
}
// red crest rocks: tall thin fins with a wavy top, standing in pairs like the Dilophosaurus's double crest
function crestRock(ctx, p, yaw, h, seed) {
  const R = rng(seed);
  const g = ctx.group('CrestRock');
  const c = g.at(p, [0, yaw, 0]);
  for (const sd of [-1, 1]) {
    const f = c.at([sd * 2.6, 0, 0], [0, 0, sd * 5]);
    const L = 9 + R() * 4;
    const nb = 6;
    for (let k = 0; k < nb; k++) {
      const u = (k + 0.5) / nb;
      const hk = h * (0.45 + 0.55 * Math.sin(u * Math.PI)) * (0.85 + R() * 0.3) * (sd > 0 ? 0.88 : 1);
      f.box({ name: 'CrestFin', s: [1.6 + R() * 0.6, hk, L / nb + 0.3], p: [0, hk / 2, -L / 2 + u * L], c: P.redRock[(k + (sd > 0 ? 1 : 0)) % 4], m: 'Slate', studs: 'top', collide: true });
      if (hk > h * 0.5) f.box({ name: 'CrestBand', s: [1.75 + R() * 0.6, 0.7, L / nb + 0.34], p: [0, hk * 0.55, -L / 2 + u * L], c: '#f3e2cc', m: 'Slate' });
    }
  }
  c.box({ name: 'CrestFoot', s: [9, 1.6, 12], p: [0, 0.8, 0], c: P.redRock[2], m: 'Slate', studs: 'top', collide: true });
  return g;
}
// a sandstone stack: banded blocks (bridge piers, den ledges)
function stack(ctx, p, w, h, seed, name = 'StackRock') {
  const R = rng(seed);
  const n = Math.max(2, Math.round(h / BAND));
  for (let k = 0; k < n; k++) {
    const s = w * (1 - (k / n) * 0.16) + (R() - 0.5) * 0.8;
    ctx.box({ name, s: [s, h / n + 0.05, s * (0.9 + R() * 0.2)], p: [p[0] + (R() - 0.5) * 0.6, p[1] + (k + 0.5) * (h / n), p[2] + (R() - 0.5) * 0.6], r: [0, (R() - 0.5) * 10, 0], c: bandAt(p[1] + k * (h / n) + 0.01), m: 'Sand', studs: 'top', collide: true });
  }
}

// a barchan: a crescent dune, gentle windward back, steep slip face, two horns trailing downwind (+X local)
function barchan(ctx, p, yaw, W, H, seed) {
  const R = rng(seed);
  const g = ctx.group('Barchan');
  const c = g.at(p, [0, yaw, 0]);
  const Lw = H * 3, Ls = H * 1.2;
  const tone = ['#ec9a5e', '#e88e52', '#f0a468'][Math.floor(R() * 3)];
  c.wedgeF({ name: 'DuneBack', s: [W, H, Lw], p: [-Lw / 2, H / 2, 0], face: 'left', c: tone, m: 'Sand', collide: true });
  c.wedgeF({ name: 'DuneFace', s: [W * 0.84, H, Ls], p: [Ls / 2, H / 2, 0], face: 'right', c: '#cf6a40', m: 'Sand', collide: true });
  c.box({ name: 'DuneCrest', s: [1.2, 0.36, W * 0.7], p: [-0.3, H - 0.05, 0], c: P.sandHi, m: 'Sand', shadow: false });
  for (const sd of [-1, 1]) {
    const hh = H * 0.5;
    const hz = c.at([H * 0.9, 0, sd * W * 0.5], [0, -sd * 16, 0]);
    hz.wedgeF({ name: 'DuneHorn', s: [W * 0.28, hh, hh * 3], p: [-hh * 1.5, hh / 2, 0], face: 'left', c: shade(tone, 1.04), m: 'Sand', collide: true });
    hz.wedgeF({ name: 'DuneHorn', s: [W * 0.24, hh, hh * 1.2], p: [hh * 0.6, hh / 2, 0], face: 'right', c: '#cf6a40', m: 'Sand', collide: true });
  }
  return g;
}

// ------------------------------------------------------------------ build
function buildDawnDesert() {
  const route = RT.buildRoute(DEF);
  const root = new Inst('Model', 'DawnDesert');
  root.attr('Zone', 'DawnDesert');
  const Z = new Ctx({ parent: root, frame: new CF(...DD_ORIGIN), defaults: { anchored: true } });
  const R = rng(215215);
  const segs = route.segs;
  for (const s of Object.values(segs)) s.cum = RT.cumOf(s.samples);
  const at = (segId, s, x = 0, y = 0) => { const sg = segs[segId]; return RT.at(sg.samples, sg.cum, s, x, y); };
  const roadPts = [];
  for (const s of Object.values(segs)) for (const p of s.samples) roadPts.push([p[0], p[2], s.width / 2]);
  const nearRoad = (x, z, pad) => roadPts.some(([px, pz, hw]) => Math.hypot(x - px, z - pz) < hw + pad);
  const jumpRanges = {};
  for (const f of FEATURES) if (f[0] === 'Jump') (jumpRanges[f[1]] = jumpRanges[f[1]] || []).push([f[2] - f[4].len / 2, f[2] + f[4].len / 2]);
  for (const sg of Object.values(segs)) for (const p of sg.samples) p[1] = Math.max(0, p[1]);
  for (const [segId, ranges] of Object.entries(jumpRanges)) {
    const sg = segs[segId];
    sg.samples.forEach((p, i) => { for (const [a, b] of ranges) if (sg.cum[i] > a && sg.cum[i] < b) { const t = (sg.cum[i] - a) / (b - a); p[1] += Math.sin(t * Math.PI) * 7; } });
  }
  // the den and its wash: the dry riverbed winds from the foot of the Blue Mesa through the den into the Painted Wash
  const den = at(DEN.seg, DEN.s, DEN.x);
  const dc = [den.p[0], den.p[2]];
  const WASH = [[dc[0] + 150, dc[1] + 200], [dc[0] + 100, dc[1] + 110], [dc[0] + 46, dc[1] + 40], [dc[0], dc[1]], [dc[0] - 70, dc[1] + 12], [dc[0] - 140, dc[1] + 52], [dc[0] - 210, dc[1] + 122], [dc[0] - 262, dc[1] + 182]];
  const S = { segs, at, den, dc, WASH, jumpRanges, nearRoad };

  // ------------------------------------------------ ground: red sand
  const G = Z.group('Ground', 'Folder');
  G.box({ name: 'DesertFloor', s: [BX * 2 + 60, 4, BZ1 - BZ0 + 60], p: [0, GROUND - 2, (BZ0 + BZ1) / 2], c: P.sand[0], studs: 'top', collide: true });

  // ------------------------------------------------ terrain: dunes, painted hills, the Blue Mesa, cut banks
  const T = terrain(Z, S);
  const hAt = T.hAt;
  S.hAt = hAt;
  S.hills = T.hills;
  S.gy = (x, z) => Math.max(GROUND, hAt(x, z));

  // ------------------------------------------------ roads (pale caliche: it reads against the red sand)
  const roads = Z.group('Roads', 'Folder');
  for (const sg of Object.values(segs)) {
    const gaps = jumpRanges[sg.id] || [];
    const inGap = (s) => gaps.some(([a, b]) => s > a + 1 && s < b - 1);
    const W = sg.width;
    const n = sg.samples.length;
    const head = (u, v) => Math.atan2(sg.samples[v][0] - sg.samples[u][0], sg.samples[v][2] - sg.samples[u][2]);
    const angDiff = (x, y) => Math.abs(Math.atan2(Math.sin(x - y), Math.cos(x - y)));
    let tile = 0;
    for (let i = 0; i < n - 1;) {
      let j = Math.min(n - 1, i + 3);
      const h0 = head(i, Math.min(n - 1, i + 1));
      while (j < n - 1 && sg.cum[j + 1] - sg.cum[i] <= 30 && angDiff(head(i, j + 1), h0) < 0.02 && Math.abs(sg.samples[j + 1][1] - sg.samples[i][1]) < 0.02 && !inGap(sg.cum[j + 1])) j++;
      const a = sg.samples[i], b = sg.samples[j];
      const sMid = (sg.cum[i] + sg.cum[j]) / 2;
      const i0 = i;
      i = j;
      if (inGap(sMid)) continue;
      const tone = tile++ % 2 ? P.road : shade(P.road, 0.96);
      const ya = ROAD + a[1], yb = ROAD + b[1];
      roads.beam([a[0], ya - 0.3, a[2]], [b[0], yb - 0.3, b[2]], W, 0.6, { name: 'Road', c: tone, m: 'Sand', collide: true, extend: 0.2 });
      const flatHere = Math.abs(yb - ya) < 0.02 && Math.abs(ROAD + sg.samples[Math.max(0, i0 - 3)][1] - ya) < 0.02;
      if (flatHere && i0 > 0) roads.cyl({ name: 'RoadJoint', axis: 'y', len: 0.6, d: W, p: [a[0], ya - 0.33, a[2]], c: P.road, m: 'Sand', collide: true });
      const fa = RT.frameAt(sg.samples, i0), fb = RT.frameAt(sg.samples, j);
      if (tile % 2 === 0) for (const rx of [-W * 0.18, W * 0.18]) roads.beam([a[0] + fa.r[0] * rx, ya + 0.02, a[2] + fa.r[2] * rx], [b[0] + fb.r[0] * rx, yb + 0.02, b[2] + fb.r[2] * rx], 1.2, 0.04, { name: 'Rut', c: P.roadLo, m: 'Sand', shadow: false });
    }
    // edges: banded cobbles, quartz chips, the odd bleached bone
    for (let s = 4; s < sg.cum[n - 1] - 4; s += 9) {
      if (inGap(s)) continue;
      if ((sg.id === 'SunriseRoad' && s < 16) || (sg.id === 'Homestretch' && s > sg.cum[n - 1] - 22)) continue;
      for (const side of [-1, 1]) {
        const f = at(sg.id, s, side * (W / 2 + 3.2)); // (verge props past the rover's reach: it drove through them at +0.7)
        const k = Math.floor(s / 9) % 4;
        const y = ROAD + f.base[1];
        if (k === 0) roads.at([f.p[0], y, f.p[2]], [0, yawOf(f), 0]).box({ name: 'EdgeStone', s: [1.6, 0.9, 2.4], p: [0, 0.2, 0], r: [0, 0, R() * 8], c: BANDS[Math.floor(R() * BANDS.length)], m: 'Sand' });
        else if (k === 2 && R() > 0.55) roads.at([f.p[0], y, f.p[2]], [0, yawOf(f) + 30, 0]).box({ name: 'EdgeBone', s: [0.5, 0.5, 3], p: [0, 0.2, 0], c: P.bone });
        else if (k === 1 && R() > 0.6) roads.at([f.p[0], y, f.p[2]], [0, R() * 90, 0]).box({ name: 'EdgeQuartz', s: [0.7, 0.6, 0.7], p: [side * 0.6, 0.25, 0], r: [20, 0, 20], c: P.quartz[Math.floor(R() * 6)], m: 'Glass', shadow: false });
      }
    }
  }

  // ------------------------------------------------ boundary: banded painted cliffs + a skyline of red mesas
  E.cliffWall(Z, [[-BX, BZ0], [BX, BZ0], [BX, BZ1], [-BX, BZ1], [-BX, BZ0]], {
    h: 38, d: 26, seed: 2151, slope: 6, name: 'PaintedCliffs', chunk: 16, trees: false, vines: false, moss: false,
    colors: ['#b8503a', '#e8b8a0', '#9a4a40', '#b993c4', '#d88a6a', '#f3e8dc', '#8c6aa6'], top: P.sand[1], overhang: [P.sand[0], P.sand[3], P.sandHi],
  });
  buildSkyline(Z, R);

  // ------------------------------------------------ set pieces
  buildArrival(Z, at);
  buildSunriseRoad(Z, S, R);
  buildRedDunes(Z, S, R);
  buildPaintedWash(Z, S, R);
  buildStoneForest(Z, S, R);
  buildQuartzBridge(Z, S, R);
  buildOasis(Z, S, R);
  buildMesaRim(Z, S, R);
  buildTeepees(Z, S, R);
  buildDunes(Z, S, R);
  for (const n of NESTS) buildNestSite(Z, n, S, R);
  buildBoneWash(Z, S, R, route);
  buildStumpCircle(Z, S, R);
  buildReturnPortal(Z, at);
  buildWeather(Z, S, R);
  buildCinematics(Z, S);
  { const f = at('SunriseRoad', 0); const c = Z.at([f.p[0] - 20, GROUND, f.p[2] - 12], [0, 60, 0]); NPC.buildNpc(c.parent, c.world(new CF(0, 0, 0)), 'Ranger'); }

  // ------------------------------------------------ vegetation + desert scatter
  buildScatter(Z, S, R);

  // keep the rover's lane clear: decor in the way is removed, anything else is reported for a fix
  {
    const lanes = [];
    for (const sg of Object.values(segs)) for (const p of sg.samples) lanes.push({ x: p[0] + DD_ORIGIN[0], z: p[2] + DD_ORIGIN[2], y: ROAD + p[1], hw: sg.width / 2 });
    const rc = require('./mapqc.js').clearRoad(root, lanes, QC);
    console.log(`                   road clearance: removed ${rc.removed}, blocking ${rc.report.length}`);
    const byName = {};
    for (const r of rc.report) { const k = r.split(' @ ')[0]; (byName[k] = byName[k] || []).push(r.split(' @ ')[1]); }
    for (const [k, v] of Object.entries(byName)) console.log(`                     ! ${k} x${v.length}  e.g. ${v[0]}`);
  }
  const data = routeData(route, at);
  root.attr('Length', +route.variants[0].length.toFixed(1));
  return { model: root, route, data };
}

// ------------------------------------------------------------------ terrain
function terrain(Z, S) {
  const { segs, at, dc, WASH, jumpRanges } = S;
  const N = noise2(2150), N2 = noise2(9191), N3 = noise2(4747);
  const fbm = (x, z) => 0.6 * N(x / 90, z / 90) + 0.3 * N(x / 40 + 11, z / 40 - 23) + 0.1 * N(x / 17 - 5, z / 17 + 3);
  // road samples (outside jump gaps): [x, z, hw, y]
  const road = [];
  for (const sg of Object.values(segs)) {
    const gaps = jumpRanges[sg.id] || [];
    sg.samples.forEach((p, i) => { if (i % 2 === 0 && !gaps.some(([a, b]) => sg.cum[i] > a - 1 && sg.cum[i] < b + 1)) road.push([p[0], p[2], sg.width / 2, p[1]]); });
  }
  const nearestRoad = (x, z) => {
    let best = Infinity, y = 0;
    for (const [px, pz, hw, py] of road) { const d = Math.hypot(x - px, z - pz) - hw; if (d < best) { best = d; y = py; } }
    return [best, y];
  };
  // flat ground for every set piece
  const circles = [];
  const addAt = (seg, s, x, r) => { const f = at(seg, s, x); circles.push([f.p[0], f.p[2], r]); };
  addAt('SunriseRoad', 0, 0, 54); addAt('SunriseRoad', 0, -26, 30);
  addAt('SunriseRoad', 130, -46, 26); addAt('SunriseRoad', 130, 44, 24);
  addAt('Homestretch', 1e9, 0, 42);
  for (const n of NESTS) addAt(n.seg, n.s, n.x, n.id === 1 ? 30 : 34);
  addAt(FINAL.seg, FINAL.s, FINAL.x, 46);
  circles.push([TEEPEES[0], TEEPEES[2], 64]);
  // the stone forest floor is a gravel flat; the oasis lies low along its channels
  const corridor = [['StoneForest', 0, 360, 46], ['StoneForest', 360, 820, 36], ['PaintedWash', 0, 1e9, 16], ['RedDunes', 0, 1e9, 44], ['OasisRun', 0, 1e9, 30], ['Homestretch', 0, 1e9, 22], ['SunriseRoad', 0, 120, 34]];
  const corridorPts = corridor.map(([seg, s0, s1, lat]) => {
    const sg = segs[seg]; const L = sg.cum[sg.cum.length - 1];
    const pts = [];
    for (let s = s0; s <= Math.min(s1, L); s += 6) { const f = at(seg, s); pts.push([f.p[0], f.p[2], lat]); }
    return pts;
  });
  const openness = (x, z) => {
    let k = 1;
    for (const [cx, cz, r] of circles) k = Math.min(k, smooth(r, r + 24, Math.hypot(x - cx, z - cz)));
    for (const pts of corridorPts) for (const [px, pz, lat] of pts) k = Math.min(k, smooth(lat, lat + 26, Math.hypot(x - px, z - pz)));
    k = Math.min(k, smooth(22, 48, braidDist(x, z)));
    return k;
  };
  // where the ground is painted clay (banded) instead of dune sand
  const PAINT = [[-300, -40, 80], [-170, -50, 62], [-120, 80, 50], [-60, 220, 50], [140, 140, 52], [-410, 236, 56], [200, 340, 40], [-30, -70, 40], [120, -120, 34]];
  const paintAt = (x, z, dw) => {
    let k = 0;
    for (const [px, pz, r] of PAINT) k = Math.max(k, 1 - smooth(r * 0.6, r * 1.15, Math.hypot(x - px, z - pz)));
    k = Math.max(k, smooth(-286, -316, z)); // the north belt behind the stone forest
    k = Math.max(k, smooth(392, 420, x) * smooth(150, 90, z)); // east rise behind the oasis
    k = Math.max(k, 1 - smooth(WASH_HW + 18, WASH_HW + 34, dw)); // cut banks of the bone wash
    return k + N3(x / 40, z / 40) * 0.12;
  };
  // the Blue Mesa: a flat-topped table under the Mesa Rim road
  const mesaSg = segs.MesaRim;
  const mesaPts = [];
  for (let s = 0; s <= mesaSg.cum[mesaSg.cum.length - 1]; s += 6) { const f = at('MesaRim', s); if (f.base[1] >= 11.5) mesaPts.push([f.p[0], f.p[2], s]); }
  const mesaD = (x, z) => { let d = Infinity, ss = 0; for (const [px, pz, s] of mesaPts) { const dd = Math.hypot(x - px, z - pz); if (dd < d) { d = dd; ss = s; } } return [d, ss]; };
  const [ja, jb] = (jumpRanges.MesaRim || [[0, 0]])[0];
  const heights = new Map();
  const key = (i, j) => i + ',' + j;
  const Gh = Z.group('Hills', 'Folder');
  const cols = [];
  const denMouth = Math.atan2(at(DEN.seg, DEN.s, 0).p[0] - dc[0], at(DEN.seg, DEN.s, 0).p[2] - dc[1]);
  for (let x0 = -BX + CELL / 2; x0 < BX; x0 += CELL) {
    for (let z0 = BZ0 + CELL / 2; z0 < BZ1; z0 += CELL) {
      const i = Math.round(x0 / CELL), j = Math.round(z0 / CELL);
      const [d, ry] = nearestRoad(x0, z0);
      const edge = Math.min(x0 + BX, BX - x0, z0 - BZ0, BZ1 - z0);
      const dw = distPoly(x0, z0, WASH);
      const paint = paintAt(x0, z0, dw);
      // dunes: asymmetric ridges (gentle windward, steep lee) running north-south, wind from the west
      const warp = 34 * N2(x0 / 140, z0 / 140) + 20 * N2(z0 / 60 + 7, x0 / 60);
      const ph = ((x0 + warp) / 120) % 1, phase = ph < 0 ? ph + 1 : ph;
      const prof = phase < 0.72 ? phase / 0.72 : (1 - phase) / 0.28;
      const amp = 0.55 + 0.45 * N2(x0 / 110 - 3, z0 / 110 + 9);
      const dunes = 7 * Math.pow(prof, 1.6) * Math.max(0, amp) * (1 - paint);
      const paintK = Math.max(0, Math.min(1, paint * 1.6 - 0.3));
      const hills = (7 + 30 * Math.max(0, fbm(x0, z0) + 0.25)) * paintK;
      let H = Math.max(dunes, hills) + 22 * (1 - smooth(10, 90, edge));
      const [b0, b1] = paintK > 0.5 ? [8, 30] : [10, 50];
      const t = smooth(b0, b1, d) * openness(x0, z0);
      let h = ry * (1 - smooth(b0, b1, d)) + H * t;
      // the Blue Mesa (its rim falls away in a steep banded cliff)
      const [md, ms] = mesaD(x0, z0);
      const rim = MESA_HALF + 6 * N3(x0 / 30 + 4, z0 / 30);
      let mesa = false;
      if (md < rim) { h = Math.max(h, MESA_TOP); mesa = true; } else if (md < rim + 10) h = Math.max(h, MESA_TOP * (1 - smooth(rim, rim + 10, md)) * 0.6);
      // the slot canyon the Mesa Rim jumps
      if (ja && md < rim + 4 && ms > ja + 3 && ms < jb - 3) { h = 0; mesa = false; }
      // the bone wash: a dry bed between low painted cut banks
      const bank = 7.2 * smooth(WASH_HW, WASH_HW + 3, dw) * (1 - smooth(WASH_HW + 14, WASH_HW + 30, dw)) * smooth(8, 22, d);
      if (!mesa) h = Math.max(h, bank);
      // the den: a bowl ringed by banded walls, its mouth open toward the road
      const dd = Math.hypot(x0 - dc[0], z0 - dc[1]);
      const ang = Math.atan2(x0 - dc[0], z0 - dc[1]);
      const mouth = Math.abs(Math.atan2(Math.sin(ang - denMouth), Math.cos(ang - denMouth))) < 0.42;
      if (dd < DEN.r + 2) h = 0;
      else if (dd < DEN.r + 30 && !mouth) h = Math.max(h, 12 * (1 - smooth(DEN.r + 18, DEN.r + 30, dd)));
      else if (dd < DEN.r + 30 && mouth) h = Math.min(h, 1);
      if (dw < WASH_HW && d > 6 && !mesa) h = 0;
      h = Math.floor(h / STEP) * STEP;
      // under (and right beside) a road the ground meets the road deck exactly
      if (d < CELL * 0.75 + 1) h = ry > 0.8 ? Math.min(Math.max(h, ry + 0.02), ry + 0.02) : Math.min(h, 0);
      if (h < STEP) { heights.set(key(i, j), 0); continue; }
      heights.set(key(i, j), h);
      const painted = paint > 0.5 || mesa || (dd < DEN.r + 32 && dd > DEN.r);
      const slabs = [];
      if (painted) {
        for (let y = 0; y < h - 0.01; y += BAND) {
          const y1 = Math.min(h, y + BAND);
          const top = y1 >= h - 0.01;
          // the Blue Mesa wears a pale caprock
          const col = top && mesa && h >= MESA_TOP - 0.1 ? '#cfc6e0' : bandAt(y + 0.01);
          slabs.push({ y0: +y.toFixed(2), y1: +y1.toFixed(2), c: col, name: top ? 'HillTop' : 'HillSide', m: top ? undefined : 'Sand', studs: top ? 'top' : undefined });
        }
      } else {
        // dune sand: lighter toward the crests
        const tone = Math.floor((N(x0 / 70 + 9, z0 / 70 - 4) + 1) * 2) % 4;
        const topC = dunes > 3 && prof > 0.78 ? P.sandHi : dunes > 2 && phase > 0.72 ? P.sandLo : P.sand[tone];
        if (h > STEP + 0.01) slabs.push({ y0: 0, y1: +(h - STEP).toFixed(2), c: P.sandSide, name: 'HillSide', m: 'Sand' });
        slabs.push({ y0: +Math.max(0, h - STEP).toFixed(2), y1: +h.toFixed(2), c: topC, name: 'HillTop', studs: 'top' });
      }
      cols.push({ i, j, x: x0, z: z0, slabs });
    }
  }
  const parts = emitSlabs(Gh, cols);
  const cellOf = (v, lo) => Math.round((lo + CELL / 2 + Math.floor((v - lo) / CELL) * CELL) / CELL);
  const hAt = (x, z) => heights.get(key(cellOf(x, -BX), cellOf(z, BZ0))) || 0;
  console.log('                   hills: ' + cols.length + ' columns -> ' + parts + ' parts');
  return { hAt, hills: Gh };
}

// ------------------------------------------------------------------ skyline
function buildSkyline(Z, R) {
  const M = Z.group('Skyline');
  const red = ['#b8402e', '#a03628', '#c8573a', '#8e2e26', '#d26a44'];
  const farMesa = (x, z, w, d, h, seed, banded) => {
    const r = rng(seed);
    const c = M.at([x, 0, z], [0, r() * 40 - 20, 0]);
    const n = Math.max(3, Math.round(h / 10));
    for (let k = 0; k < n; k++) {
      const shrink = 1 - (k / n) * 0.14;
      const col = banded && k >= n - 3 ? ['#f3e8dc', '#b993c4', '#e89a86'][k % 3] : red[(k + seed) % 5];
      c.box({ name: 'SkyMesa', s: [w * shrink + (r() - 0.5) * 6, h / n + 0.4, d * shrink + (r() - 0.5) * 6], p: [(r() - 0.5) * 3, (k + 0.5) * (h / n), (r() - 0.5) * 3], r: [0, (r() - 0.5) * 5, 0], c: col, m: 'Slate' });
    }
    c.box({ name: 'SkyMesa', s: [w * 0.84, 1.6, d * 0.84], p: [0, h + 0.6, 0], c: '#d98a5a', m: 'Slate' });
    // scree skirts
    for (const sd of [-1, 1]) c.wedgeF({ name: 'SkyMesa', s: [w * 0.9, h * 0.3, h * 0.35], p: [0, h * 0.15, sd * (d / 2 + h * 0.17)], face: sd > 0 ? 'back' : 'front', c: red[(seed + 2) % 5], m: 'Slate' });
  };
  const butte = (x, z, h, seed) => {
    const r = rng(seed);
    const c = M.at([x, 0, z], [0, r() * 90, 0]);
    const w = h * 0.42;
    for (let k = 0; k < 7; k++) c.box({ name: 'SkyMesa', s: [w * (1 - k * 0.03) + r() * 6, h / 7 + 0.5, w * 0.86 + r() * 6], p: [0, (k + 0.5) * (h / 7), 0], r: [0, k * 5, 0], c: k > 4 ? ['#f3e8dc', '#b993c4'][k % 2] : red[(k + seed) % 5], m: 'Slate' });
    for (const sd of [-1, 1]) c.wedgeF({ name: 'SkyMesa', s: [w * 1.3, h * 0.3, w * 0.7], p: [0, h * 0.15, sd * w * 0.78], face: sd > 0 ? 'back' : 'front', c: red[1], m: 'Slate' });
  };
  // north: a long wall of red mesas behind the painted cliffs, one with a white-and-lavender cap
  for (let k = 0; k < 9; k++) {
    const x = -560 + k * 140 + (R() - 0.5) * 30, z = -430 - (k % 2) * 60 - R() * 30;
    if (k % 3 === 1) butte(x, z, 120 + R() * 40, 300 + k);
    else farMesa(x, z, 120 + R() * 50, 64 + R() * 20, 84 + R() * 40, 300 + k, k % 2 === 0);
  }
  // east and west
  for (let k = 0; k < 5; k++) {
    farMesa(-540 - R() * 40, -240 + k * 140, 70 + R() * 30, 110 + R() * 40, 76 + R() * 40, 320 + k, k % 2 === 1);
    if (k % 2) butte(560 + R() * 30, -250 + k * 140, 110 + R() * 40, 330 + k); else farMesa(550 + R() * 40, -250 + k * 140, 70 + R() * 30, 110 + R() * 40, 80 + R() * 36, 330 + k, true);
  }
  // south: low red dune ridges and two buttes
  for (let k = 0; k < 6; k++) farMesa(-450 + k * 180 + (R() - 0.5) * 40, 500 + R() * 50, 120 + R() * 40, 50, 50 + R() * 30, 350 + k, k % 2 === 0);
  butte(-150, 560, 110, 361); butte(260, 590, 130, 362);
  // furthest: a hazy violet range so the sunrise has something to rise over
  for (let k = 0; k < 6; k++) {
    const x = -600 + k * 240 + (R() - 0.5) * 50, z = -600 - R() * 30;
    const h = 170 + R() * 80;
    for (let t = 0; t < 4; t++) M.box({ name: 'Peak', s: [200 - t * 40 + R() * 20, h / 4 + 1, 120 - t * 24], p: [x + (R() - 0.5) * 10 * t, (t + 0.5) * (h / 4), z], r: [0, (R() - 0.5) * 20, 0], c: mix('#a98bb4', '#d8c2d6', t / 4), m: 'Slate' });
  }
}

// ------------------------------------------------------------------ set pieces
function hexPortal(ctx, p, yaw, Rr, name, o = {}) {
  const g = ctx.group(name);
  const c = g.at(p, [0, yaw, 0]);
  const cy = Rr * Math.sin(Math.PI / 3) - 1.8;
  const F = c.at([0, cy, 0]);
  const pts = Array.from({ length: 6 }, (_, k) => { const a = (k * 60 * Math.PI) / 180; return [Math.cos(a) * Rr, Math.sin(a) * Rr]; });
  for (let k = 0; k < 6; k++) {
    const [ax, ay] = pts[k], [bx, by] = pts[(k + 1) % 6];
    F.beam([ax, ay, 0], [bx, by, 0], 3.6, 3, { name: 'PortalBeam', c: '#7a5a52', m: 'Slate', studs: 'top', extend: 1, up: [0, 0, 1] });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNode', s: [4.4, 4.4, 4.8], c: '#2b2d31', m: 'Metal', studs: 'all' });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNodeCore', s: [2, 2, 5], c: o.color || '#ff9a5a', m: 'Neon' }).tag('GateNode');
  }
  const rm = Rr - 2.2, apo = rm * Math.sin(Math.PI / 3);
  for (let k = 0; k < 3; k++) F.box({ name: 'Membrane', s: [rm, 2 * apo, 0.3], r: [0, 0, k * 60], c: o.color || '#ff8a5a', m: 'Neon', t: 0.5, shadow: false }).tag('PortalSurface');
  for (let k = 0; k < 3; k++) F.box({ name: 'Core', s: [rm * 0.5, 2 * apo * 0.5, 0.35], r: [0, 0, k * 60], c: '#ffe8d8', m: 'Neon', t: 0.45, shadow: false }).tag('PortalCore');
  const host = F.box({ name: 'PortalLightHost', s: [1, 1, 1], t: 1, shadow: false });
  E.pointLight(host, [1, 0.7, 0.55], 40, 1.4);
  E.particles(host, 'Swirl', { rate: 22, life: [0.8, 1.6], speed: [5, 12], spread: [80, 80], dir: 5, size: [[0, 0.55], [1, 0]], color: [[0, [1, 0.9, 0.8]], [1, [1, 0.55, 0.45]]], emission: 0.7 });
  for (const side of [-1, 1]) c.box({ name: 'Plinth', s: [6, 3, 7], p: [side * (Rr + 1), 1.5, 0], c: '#9a5a4a', m: 'Slate', studs: 'top', collide: true });
  return g;
}

function buildArrival(Z, at) {
  const f = at('SunriseRoad', 0);
  hexPortal(Z, [f.p[0], GROUND, f.p[2] + 6], yawOf(f), 14, 'ArrivalPortal', { color: '#3fe0c8' });
  const c = Z.at([f.p[0] - 32, GROUND, f.p[2] - 20], [0, -20, 0]);
  c.box({ name: 'TentFloor', s: [10, 0.3, 8], p: [0, 0.15, 0], c: '#8a4a3a' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, -2], face: 'front', c: '#f0d8b8' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, 2], face: 'back', c: '#e2c6a2' });
  c.box({ name: 'TentStripe', s: [10.1, 0.5, 0.2], p: [0, 3.2, -2.2], r: [-51, 0, 0], c: '#c75a46' });
  E.crate(c, [-6.5, 0.3, 1], 1, { yaw: -14, stencil: '#8c6aa6' });
  E.barrel(c, [-6.5, 0.3, -2.5], { color: '#8c6aa6' });
  E.signBoard(c, [7, 4, -3], 7, 2, 'DAWN DESERT', { r: [0, 30, 0], color: '#fff0e6', color2: '#ff8a5a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [7, 2, -2.7], c: E.PAL.woodLo });
  E.lampPost(c, [4, 0.3, 4], { h: 6 });
  // a fossil-hunter's dig beside the camp: a half-cleared skeleton pegged out with string
  const dig = Z.at([f.p[0] + 30, GROUND, f.p[2] - 30], [0, 25, 0]);
  dig.box({ name: 'DigPit', s: [12, 0.1, 8], p: [0, 0.05, 0], c: '#c99a76', shadow: false });
  for (let k = 0; k < 7; k++) dig.box({ name: 'DigBone', s: [0.6, 0.5, 1.6], p: [-4 + k * 1.3, 0.25, Math.sin(k) * 0.6], r: [0, k * 9, 0], c: P.bone });
  dig.box({ name: 'DigSkull', s: [1.6, 1, 2.4], p: [5, 0.5, 0.6], r: [0, 30, 0], c: P.bone });
  for (const [x, z] of [[-6, -4], [6, -4], [6, 4], [-6, 4]]) dig.box({ name: 'DigPeg', s: [0.3, 1.2, 0.3], p: [x, 0.6, z], c: E.PAL.woodLo });
  for (const [a, b] of [[[-6, 1, -4], [6, 1, -4]], [[6, 1, -4], [6, 1, 4]], [[6, 1, 4], [-6, 1, 4]], [[-6, 1, 4], [-6, 1, -4]]]) dig.beam(a, b, 0.08, 0.08, { name: 'DigString', c: '#ff5a3a', shadow: false });
  E.crate(dig, [-8, 0, 2], 0.8, { yaw: 20, stencil: '#c75a46' });
}

function buildReturnPortal(Z, at) {
  const f = at('Homestretch', 1e9);
  hexPortal(Z, [f.p[0] - f.f[0] * 14, GROUND, f.p[2] - f.f[2] * 14] /* 14 back from the end: you drive through it before the warp (extract at L-8) */, yawOf(f), 15, 'ReturnPortal', { color: '#ffb02e' });
}

// the road in: a gate of two great banded teepees, red dunes on the left, the painted hills ahead
function buildSunriseRoad(Z, S, R) {
  const { at, gy } = S;
  const g = Z.group('SunriseRoad');
  const f = at('SunriseRoad', 130);
  const c = g.at([f.base[0], GROUND, f.base[2]], [0, yawOf(f), 0]);
  teepee(c, [-44, 0, 0], 14, 34, 1101, { fixed: true });
  teepee(c, [42, 0, 8], 12, 28, 1102, { fixed: true });
  teepee(c, [58, 0, -18], 7, 15, 1103);
  teepee(c, [-60, 0, 20], 6, 12, 1104);
  const sc = c.at([-20, 0, 26]);
  E.signBoard(sc, [0, 4.4, 0], 8, 2.2, 'SUNRISE ROAD', { color: '#fff0e6', color2: '#ff8a5a', twoSided: true, pps: 30, trim: '#ff8a5a' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: E.PAL.woodLo });
  // dune ripples on the flats either side
  for (let k = 0; k < 26; k++) {
    const fr = at('SunriseRoad', 20 + R() * 200, (R() > 0.5 ? 1 : -1) * (20 + R() * 40));
    if (S.hAt(fr.p[0], fr.p[2]) > 0) continue;
    const rc = g.at([fr.p[0], GROUND, fr.p[2]], [0, 8 + (R() - 0.5) * 10, 0]);
    for (let j = 0; j < 4; j++) rc.box({ name: 'DuneRipple', s: [0.5, 0.1, 8 + R() * 6], p: [j * 1.8, 0.05, (R() - 0.5) * 2], c: P.sandHi, shadow: false });
  }
}

// red dunes: the road climbs over the crests; big dune faces either side, ripples, a half-buried skeleton
function buildRedDunes(Z, S, R) {
  const { at, segs } = S;
  const g = Z.group('RedDunes');
  const sg = segs.RedDunes;
  const L = sg.cum[sg.cum.length - 1];
  // barchans right beside the road, so the drive feels like threading between dunes
  for (let s = 14; s < L - 14; s += 16) for (const side of [-1, 1]) {
    const W = 14 + R() * 12, H = 4 + R() * 4;
    const rad = Math.max(W / 2 + 2, H * 3 + 2);
    const f = at('RedDunes', s, side * (sg.width / 2 + rad + 6 + R() * 10));
    const x = f.p[0], z = f.p[2];
    if (S.nearRoad(x, z, rad + 3) || (S.dunes || []).some(([px, pz, pr]) => Math.hypot(px - x, pz - z) < pr + rad)) continue;
    const hs = [[0, 0], [rad, 0], [-rad, 0], [0, rad], [0, -rad]].map(([dx, dz]) => S.hAt(x + dx, z + dz));
    const lo = Math.min(...hs), hi = Math.max(...hs);
    if (hi - lo > 3.7) continue;
    barchan(S.hills, [x, (lo > 0 ? lo : GROUND) - 0.1, z], (R() - 0.5) * 40, W, H + (hi - lo) * 0.6, 1600 + Math.floor(s) * 2 + side);
    (S.dunes = S.dunes || []).push([x, z, rad]);
  }
  for (let k = 0; k < 40; k++) {
    const fr = at('RedDunes', R() * L, (R() > 0.5 ? 1 : -1) * (16 + R() * 40));
    const rc = g.at([fr.p[0], S.gy(fr.p[0], fr.p[2]), fr.p[2]], [0, 10 + (R() - 0.5) * 12, 0]);
    for (let j = 0; j < 3; j++) rc.box({ name: 'DuneRipple', s: [0.5, 0.1, 7 + R() * 6], p: [j * 1.8, 0.05, (R() - 0.5) * 2], c: j % 2 ? P.sandHi : P.sand[3], shadow: false });
  }
  // a little theropod's skeleton the dunes are uncovering
  const f = at('RedDunes', 120, -24);
  const c = g.at([f.p[0], S.gy(f.p[0], f.p[2]), f.p[2]], [0, 40, 0]);
  for (let i = 0; i < 14; i++) c.box({ name: 'DuneBone', s: [0.6, 0.5, 1], p: [Math.sin(i * 0.35) * 2, 0.25, -6 + i * 0.9], r: [0, i * 6, 0], c: i % 2 ? P.bone : P.boneLo });
  c.box({ name: 'DuneSkull', s: [1.2, 1, 2.2], p: [Math.sin(-0.35) * 2, 0.5, -7.4], r: [0, -10, 8], c: P.bone });
  for (let i = 0; i < 4; i++) c.box({ name: 'DuneRib', s: [0.3, 1.4, 0.3], p: [-0.6 + (i % 2) * 1.2, 0.6, -2 + i * 0.8], r: [0, 0, (i % 2 ? -1 : 1) * 30], c: P.bone });
  const sc = g.at([at('RedDunes', 26, 18).p[0], GROUND, at('RedDunes', 26, 18).p[2]], [0, yawOf(at('RedDunes', 26)), 0]);
  E.signBoard(sc, [0, 4.2, 0], 7, 2, 'RED DUNES', { color: '#fff0e6', color2: '#ff6a3a', twoSided: true, pps: 30 });
  sc.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
}

// the painted wash: a pale clay floor between banded hills, teepees standing along it like a crowd
function buildPaintedWash(Z, S, R) {
  const { at, segs } = S;
  const g = Z.group('PaintedWash');
  const sg = segs.PaintedWash;
  const L = sg.cum[sg.cum.length - 1];
  const crust = ['#f1e2d6', '#e8d0c8', '#d9c0d0', '#f4e8dc'];
  for (let s = 8; s < L - 8; s += 10) for (const side of [-1, 1]) for (let x = sg.width / 2 + 1; x < sg.width / 2 + 16; x += 9) {
    const f = at('PaintedWash', s + (R() - 0.5) * 3, side * (x + R() * 3));
    if (S.hAt(f.p[0], f.p[2]) > 0) continue;
    g.at([f.p[0], GROUND, f.p[2]], [0, yawOf(f) + (R() - 0.5) * 16, 0]).box({ name: 'WashCrust', s: [8 + R() * 3, 0.1, 8 + R() * 3], p: [0, 0.05, 0], c: crust[Math.floor(R() * 4)], m: 'Sand', shadow: false });
  }
  // teepees along the wash, a mix of big cones and squat domes
  for (let s = 24; s < L - 20; s += 34 + R() * 14) for (const side of [-1, 1]) {
    if (R() < 0.3) continue;
    const big = R() > 0.6;
    const f = at('PaintedWash', s, side * (sg.width / 2 + (big ? 22 : 13) + R() * 10));
    if (S.hAt(f.p[0], f.p[2]) > 0) continue;
    teepee(g, [f.p[0], GROUND, f.p[2]], big ? 9 + R() * 4 : 4 + R() * 2.5, big ? 16 + R() * 12 : 6 + R() * 5, 1200 + Math.floor(s) * 2 + side, { round: R() > 0.5 });
  }
  const f = at('PaintedWash', 30, -18);
  const sc = g.at([f.p[0], GROUND, f.p[2]], [0, yawOf(at('PaintedWash', 30)), 0]);
  E.signBoard(sc, [0, 4.2, 0], 8, 2, 'PAINTED WASH', { color: '#fff0e6', color2: '#b993c4', twoSided: true, pps: 30 });
  sc.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
}

// the stone forest: dozens of giant petrified logs on a gravel flat, all fallen the same way (an old flood laid them)
function buildStoneForest(Z, S, R) {
  const { at, segs, WASH } = S;
  const g = Z.group('StoneForest');
  const sg = segs.StoneForest;
  const nest2 = at(NESTS[1].seg, NESTS[1].s, NESTS[1].x);
  const bridge = at(BRIDGE.seg, BRIDGE.s);
  const placed = [];
  // gravel flat: pinkish-grey stones scattered (cheap thin plates + chips)
  for (let k = 0; k < 90; k++) {
    const f = at('StoneForest', R() * 360, (R() > 0.5 ? 1 : -1) * (sg.width / 2 + 2 + R() * 64));
    if (S.hAt(f.p[0], f.p[2]) > 0) continue;
    E.groundPatch(g, [f.p[0], GROUND, f.p[2]], 5 + R() * 5, 3100 + k, { colors: ['#d8a08a', '#c8908a', '#e0b49a', '#b88a84'], m: 'Pebble', n: 2 });
  }
  // the Old Log: the biggest trunk in the forest, lying alongside the road, every crack full of crystal
  {
    const f = at('StoneForest', 78, -30);
    petrifiedLog(g, [f.p[0], GROUND, f.p[2]], yawOf(f) + 90 + 8, 64, 8.4, 3999, { name: 'OldLog' });
    quartzChips(g, [f.p[0], GROUND, f.p[2] + 6], 3998, 10, 20);
    placed.push([f.p[0], f.p[2], 32]);
  }
  for (let k = 0; k < 320 && placed.length < 64; k++) {
    const s = R() * 360;
    const side = R() > 0.5 ? 1 : -1;
    const x = side * (sg.width / 2 + 8 + R() * 62);
    const f = at('StoneForest', s, x);
    if (S.hAt(f.p[0], f.p[2]) > 0) continue;
    if (Math.hypot(f.p[0] - nest2.p[0], f.p[2] - nest2.p[2]) < 30) continue;
    if (Math.hypot(f.p[0] - bridge.p[0], f.p[2] - bridge.p[2]) < 40) continue;
    if (distPoly(f.p[0], f.p[2], WASH) < WASH_HW + 18) continue;
    const big = R() > 0.72;
    const Lg = big ? 30 + R() * 22 : 12 + R() * 16, d = big ? 4.2 + R() * 1.6 : 2.4 + R() * 1.6;
    if (placed.some(([px, pz, pr]) => Math.hypot(px - f.p[0], pz - f.p[2]) < pr + Lg / 2 + 3)) continue;
    // they lie roughly along the old flow (north-east to south-west), and never across the road's verge
    const yaw = 35 + (R() - 0.5) * 40;
    placed.push([f.p[0], f.p[2], Lg / 2]);
    petrifiedLog(g, [f.p[0], GROUND, f.p[2]], yaw, Lg, d, 3000 + k);
    if (R() > 0.4) quartzChips(g, [f.p[0] + (R() - 0.5) * 8, GROUND, f.p[2] + (R() - 0.5) * 8], 3200 + k, 4 + Math.floor(R() * 4), 6);
  }
  // a few standing stumps and loose rounds
  for (let k = 0; k < 14; k++) {
    const f = at('StoneForest', 10 + R() * 340, (R() > 0.5 ? 1 : -1) * (sg.width / 2 + 6 + R() * 50));
    if (S.hAt(f.p[0], f.p[2]) > 0 || placed.some(([px, pz, pr]) => Math.hypot(px - f.p[0], pz - f.p[2]) < pr + 4)) continue;
    if (Math.hypot(f.p[0] - nest2.p[0], f.p[2] - nest2.p[2]) < 28) continue;
    stump(g, [f.p[0], GROUND, f.p[2]], 2 + R() * 4, 2.6 + R() * 2, 3400 + k);
    placed.push([f.p[0], f.p[2], 3]);
  }
  const sf = at('StoneForest', 20, -20);
  const sc = g.at([sf.p[0], GROUND, sf.p[2]], [0, yawOf(at('StoneForest', 20)), 0]);
  E.signBoard(sc, [0, 4.4, 0], 8, 2.2, 'STONE FOREST', { color: '#fff0e6', color2: '#c86bff', twoSided: true, pps: 30, trim: '#b07aff' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: E.PAL.woodLo });
  S.logs = placed;
}

// the quartz bridge: one colossal petrified trunk spans the road between two banded piers (you drive under it)
function buildQuartzBridge(Z, S, R) {
  const { at } = S;
  const f = at(BRIDGE.seg, BRIDGE.s);
  const g = Z.group('QuartzBridge');
  const c = g.at([f.base[0], GROUND, f.base[2]], [0, yawOf(f), 0]);
  const Y = 17, D = 7.4;
  for (const sd of [-1, 1]) {
    stack(c, [sd * 27, 0, 0], 11, Y - D / 2 + 0.6, 1300 + sd, 'BridgePier');
    // the bank it rests on spills down in a scree
    c.wedgeF({ name: 'BridgeScree', s: [12, 4, 6], p: [sd * 27, 2, -8], face: 'front', c: bandAt(1), m: 'Sand', collide: true });
    c.wedgeF({ name: 'BridgeScree', s: [12, 4, 6], p: [sd * 27, 2, 8], face: 'back', c: bandAt(1), m: 'Sand', collide: true });
  }
  // the trunk: three long rounds, broken but still touching, with quartz showing at every crack
  const logC = c.at([0, Y, 0], [0, 6, 0]);
  const ring = ['#ff6a4a', '#ffa33a', '#ffd84a'];
  const parts = [[-22, 22], [-1, 18], [19, 22]];
  parts.forEach(([x, len], k) => {
    const sc = logC.at([x, (k === 1 ? -0.3 : 0), 0], [0, 0, (k - 1) * 2]);
    sc.cyl({ name: 'BridgeLog', axis: 'x', len: len - 0.8, d: D, c: P.petri[k + 1], m: 'Slate', collide: true });
    sc.box({ name: 'BarkRidge', s: [len * 0.8, D * 0.16, D * 0.3], p: [0, D * 0.47, 0.6], c: shade(P.petri[k + 1], 1.1), m: 'Slate' });
    sc.box({ name: 'BarkRidge', s: [len * 0.7, D * 0.3, D * 0.16], p: [0, 0.4, D * 0.47], c: shade(P.petri[k + 1], 0.9), m: 'Slate' });
    for (const sd of [-1, 1]) {
      sc.cyl({ name: 'QuartzRing', axis: 'x', len: 0.3, d: D * 0.84, p: [sd * ((len - 0.8) / 2 + 0.02), 0, 0], c: ring[(k + (sd > 0 ? 1 : 0)) % 3], m: 'Glass', shadow: false });
      sc.cyl({ name: 'QuartzCore', axis: 'x', len: 0.36, d: D * 0.44, p: [sd * ((len - 0.8) / 2 + 0.05), 0, 0], c: P.core[k % P.core.length], m: 'Glass', shadow: false });
    }
  });
  // roots splayed at the base end, a broken crown stub at the other
  for (let k = 0; k < 5; k++) logC.at([-33, 0, 0], [0, 0, k * 72]).box({ name: 'BridgeRoot', s: [3, 1.6, 1.6], p: [-1, D * 0.45, 0], r: [0, 25, 0], c: P.petri[0], m: 'Slate' });
  // a glint of the quartz catching the low sun
  const host = logC.box({ name: 'BridgeGlint', s: [44, 1, 6], p: [0, 0, 0], t: 1, shadow: false });
  host.set('CanQuery', 'bool', false);
  E.particles(host, 'Glint', { rate: 3, life: [0.6, 1.2], speed: [0, 0.2], size: [[0, 0.6], [0.5, 0.9], [1, 0]], color: [1, 0.9, 1], emission: 0.8 });
  const sc = c.at([-20, 0, 12], [0, 0, 0]);
  E.signBoard(sc, [0, 4.4, 0], 8, 2.2, 'QUARTZ BRIDGE', { color: '#fff0e6', color2: '#ffa33a', twoSided: true, pps: 30 });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: E.PAL.woodLo });
}

// the oasis: braided river channels at the foot of the Blue Mesa, horsetail thickets, tree ferns and early conifers
function buildOasis(Z, S, R) {
  const g = Z.group('Oasis');
  for (const br of BRAIDS) {
    for (let i = 0; i < br.pts.length - 1; i++) {
      const [ax, az] = br.pts[i], [bx, bz] = br.pts[i + 1];
      g.beam([ax, GROUND - 0.02, az], [bx, GROUND - 0.02, bz], br.w + 6, 0.1, { name: 'ChannelBank', c: P.bank, m: 'Sand', shadow: false, extend: br.w });
      g.beam([ax, GROUND + 0.02, az], [bx, GROUND + 0.02, bz], br.w, 0.1, { name: 'OasisWater', c: i % 2 ? P.water : shade(P.water, 1.05), m: 'Glass', t: 0.12, shadow: false, extend: br.w * 0.8 }).tag('DinoWater');
      // a pale ripple line down the middle
      g.beam([ax, GROUND + 0.08, az], [bx, GROUND + 0.08, bz], 0.5, 0.04, { name: 'WaterGlint', c: P.waterHi, shadow: false });
    }
  }
  for (const [x, z, d] of POOLS) {
    g.cyl({ name: 'PoolShore', axis: 'y', len: 0.1, d: d + 8, p: [x, GROUND - 0.02, z], c: P.bank, m: 'Sand', shadow: false });
    g.cyl({ name: 'PoolWater', axis: 'y', len: 0.12, d, p: [x, GROUND + 0.04, z], c: P.water, m: 'Glass', t: 0.12, shadow: false }).tag('DinoWater');
    for (let k = 0; k < 4; k++) g.cyl({ name: 'LilyPad', axis: 'y', len: 0.08, d: 1.4 + R(), p: [x + (R() - 0.5) * d * 0.6, GROUND + 0.14, z + (R() - 0.5) * d * 0.6], c: '#4fb043', shadow: false });
  }
  // the spring: water seeping out of the Blue Mesa's foot into the first pool, over a lip of banded stones
  {
    const [x, z] = POOLS[0];
    for (let k = 0; k < 9; k++) {
      const a = Math.PI * 0.9 + (k / 8) * Math.PI * 0.8;
      g.box({ name: 'SpringStone', s: [3 + R() * 2, 1.4 + R(), 2.4], p: [x + Math.cos(a) * 15, GROUND + 0.5, z + Math.sin(a) * 15], r: [0, -E.deg(a), R() * 8], c: bandAt(R() * 10), m: 'Sand', studs: 'top' });
    }
  }
  // horsetail thickets along every channel, ferns and reeds on the bars
  for (const br of BRAIDS) for (let i = 0; i < br.pts.length - 1; i++) {
    const [ax, az] = br.pts[i], [bx, bz] = br.pts[i + 1];
    const L = Math.hypot(bx - ax, bz - az);
    const nx = -(bz - az) / L, nz = (bx - ax) / L;
    for (let u = 4; u < L; u += 9 + R() * 7) for (const side of [-1, 1]) {
      if (R() < 0.25) continue;
      const off = br.w / 2 + 0.5 + R() * 3;
      const x = ax + (bx - ax) * (u / L) + nx * side * off, z = az + (bz - az) * (u / L) + nz * side * off;
      if (S.nearRoad(x, z, 2) || S.hAt(x, z) > 0) continue;
      if (R() < 0.6) horsetails(g, [x, GROUND, z], 4000 + i * 131 + Math.floor(u) * 3 + side, { n: 3 + Math.floor(R() * 4), h: 4 + R() * 4 });
      else E.fern(g, [x, GROUND, z], 1.2 + R() * 0.6, 4100 + i * 131 + Math.floor(u) + side);
    }
  }
  // the banks: tree ferns, early conifers and cycads crowd the water (the greenest place in the era)
  const n1 = S.at(NESTS[0].seg, NESTS[0].s, NESTS[0].x);
  const green = S.oasisPlaced = [];
  for (const br of BRAIDS) for (let i = 0; i < br.pts.length - 1; i++) {
    const [ax, az] = br.pts[i], [bx, bz] = br.pts[i + 1];
    const L = Math.hypot(bx - ax, bz - az);
    const nx = -(bz - az) / L, nz = (bx - ax) / L;
    for (let u = 6; u < L; u += 11 + R() * 6) for (const side of [-1, 1]) {
      const off = br.w / 2 + 7 + R() * 12;
      const x = ax + (bx - ax) * (u / L) + nx * side * off, z = az + (bz - az) * (u / L) + nz * side * off;
      if (S.nearRoad(x, z, 6) || S.hAt(x, z) > 0 || braidDist(x, z) < 3) continue;
      if (Math.hypot(x - n1.p[0], z - n1.p[2]) < 26 || green.some(([px, pz]) => Math.hypot(px - x, pz - z) < 8)) continue;
      green.push([x, z]);
      const k = R();
      if (k < 0.4) treeFern(g, [x, GROUND, z], 6 + R() * 5, 4200 + green.length);
      else if (k < 0.62) conifer(g, [x, GROUND, z], 16 + R() * 14, 4200 + green.length);
      else if (k < 0.82) cycad(g, [x, GROUND, z], 2 + R() * 4, 4200 + green.length);
      else E.bush(g, [x, GROUND, z], 0.9 + R() * 0.5, 4200 + green.length, { colors: ['#6a8a3a', '#7a9a44', '#5a7a34'], n: 5 });
    }
  }
  // springs: two ribbon falls pour off the Blue Mesa's rim into the channel at its foot
  for (const z of [70, 150]) {
    let edge = null;
    for (let x = 250; x < 330; x += 1) if (S.hAt(x, z) >= MESA_TOP - 0.1 && S.hAt(x + 1, z) < MESA_TOP - 0.1) edge = x + 0.5;
    if (edge === null) continue;
    const low = Math.max(GROUND, S.hAt(edge + 2, z));
    E.waterfall(g, [edge + 0.4, MESA_TOP + 0.3, z], 5, MESA_TOP + 0.3 - low, { yaw: -90, seed: 4300 + z, name: 'Waterfall', mist: 4 });
  }
  const f = S.at('OasisRun', 24, 20);
  const sc = g.at([f.p[0], GROUND, f.p[2]], [0, yawOf(S.at('OasisRun', 24)), 0]);
  E.signBoard(sc, [0, 4.2, 0], 7, 2, 'OASIS RUN', { color: '#e8fff6', color2: '#3fc8b0', twoSided: true, pps: 30 });
  sc.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
}

// mesa rim: the road runs along the top of the Blue Mesa; rim stones on the drop, a lookout, the slot canyon jump
function buildMesaRim(Z, S, R) {
  const { at, segs, jumpRanges } = S;
  const g = Z.group('MesaRim');
  const sg = segs.MesaRim;
  const gaps = jumpRanges.MesaRim || [];
  const inGap = (s) => gaps.some(([a, b]) => s > a - 3 && s < b + 3);
  for (let s = 70; s < 250; s += 12) {
    if (inGap(s)) continue;
    for (const side of [-1, 1]) {
      if (R() < 0.35) continue;
      const f = at('MesaRim', s, side * (sg.width / 2 + 5 + R() * 6));
      const y = S.hAt(f.p[0], f.p[2]);
      if (y < MESA_TOP - 0.1) continue;
      E.rock(g, [f.p[0], y, f.p[2]], 1 + R() * 0.8, 5000 + s * 2 + side, { colors: ['#7f8cb0', '#b993c4', '#efe2d6', '#8c6aa6'], moss: false });
    }
  }
  for (const [a, b] of gaps) {
    for (const [s, dir] of [[a, 1], [b, -1]]) {
      const fr = at('MesaRim', s);
      g.at([fr.base[0], ROAD + fr.base[1], fr.base[2]], [0, yawOf(fr), 0]).box({ name: 'JumpLip', s: [sg.width, 0.8, 1.6], p: [0, 0.1, -dir * 0.4], c: '#f2c230', studs: 'top' });
    }
    // the slot canyon below: a sliver of sky-blue water in the bottom, a fallen log wedged across
    const fm = at('MesaRim', (a + b) / 2);
    const c = g.at([fm.base[0], GROUND, fm.base[2]], [0, yawOf(fm), 0]);
    c.box({ name: 'CanyonSand', s: [110, 0.1, b - a - 8], p: [0, 0.05, 0], c: '#e8c0a0', m: 'Sand', shadow: false });
    c.box({ name: 'CanyonWater', s: [90, 0.12, 4], p: [0, 0.1, 0], c: P.water, m: 'Glass', t: 0.15, shadow: false }).tag('DinoWater');
    petrifiedLog(c, [-sg.width / 2 - 16, 6, 0], 90, b - a - 4, 3, 5101, { name: 'WedgedLog', y: 0 });
    const sc = c.at([sg.width / 2 + 4, MESA_TOP, -(b - a) / 2 - 8]);
    E.signBoard(sc, [0, 4, 0], 6, 1.8, 'SLOT CANYON', { r: [0, 180, 0], color: '#fff0e6', color2: '#f2c230', twoSided: true, pps: 30 });
    sc.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, -0.3], c: E.PAL.woodLo });
  }
  // a lookout on the east rim over the oasis
  const f = at('MesaRim', 110, -(sg.width / 2 + 12));
  const c = g.at([f.p[0], MESA_TOP, f.p[2]], [0, yawOf(at('MesaRim', 110)) + 90, 0]);
  c.box({ name: 'LookoutDeck', s: [8, 0.5, 6], p: [0, 0.25, 0], c: E.PAL.plank, m: 'WoodPlanks', collide: true });
  E.logFence(c, [-4, 0.5, -3], [4, 0.5, -3], { h: 1.8, spacing: 4 });
  E.flag(c, [3.5, 0.5, 2.5], '#b993c4', { h: 6 });
  const sf = at('MesaRim', 70, 15);
  const sc = g.at([sf.p[0], S.gy(sf.p[0], sf.p[2]), sf.p[2]], [0, yawOf(at('MesaRim', 70)), 0]);
  E.signBoard(sc, [0, 4, 0], 7, 2, 'MESA RIM', { color: '#fff0e6', color2: '#8c9ad8', twoSided: true, pps: 30 });
  sc.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
}

// the dune sea: barchans marching east across every open stretch of sand (wind from the west)
function buildDunes(Z, S, R) {
  const { at, nearRoad, WASH, den } = S;
  const keep = [[den.p[0], den.p[2], DEN.r + 34], [TEEPEES[0] + 6, TEEPEES[2] + 16, 74]];
  { const f = at(FINAL.seg, FINAL.s, FINAL.x); keep.push([f.p[0], f.p[2], 46]); }
  for (const n of NESTS) { const f = at(n.seg, n.s, n.x); keep.push([f.p[0], f.p[2], 40]); }
  { const f = at(BRIDGE.seg, BRIDGE.s); keep.push([f.p[0], f.p[2], 44]); }
  { const f = at('SunriseRoad', 0); keep.push([f.p[0], f.p[2], 50]); keep.push([f.p[0] + 30, f.p[2] - 30, 16]); keep.push([f.p[0] - 26, f.p[2] - 20, 16]); }
  { const f = at('SunriseRoad', 130); keep.push([f.p[0], f.p[2], 66]); }
  for (let s = 0; s < 380; s += 20) { const f = at('StoneForest', s); keep.push([f.p[0], f.p[2], 84]); }
  for (const [x, z, r] of S.logs || []) keep.push([x, z, r + 4]);
  const placed = S.dunes = S.dunes || [];
  const Rd = rng(16161);
  for (let k = 0; k < 3000 && placed.length < 120; k++) {
    const x = (Rd() - 0.5) * 2 * (BX - 40), z = BZ0 + 40 + Rd() * (BZ1 - BZ0 - 80);
    const W = 18 + Rd() * 26, H = 4 + Rd() * 5;
    const rad = Math.max(W / 2 + 2, H * 3.4 + 2);
    if (keep.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr + rad * 0.6)) continue;
    if (placed.some(([px, pz, pr]) => Math.hypot(x - px, z - pz) < pr + rad + 2)) continue;
    if (nearRoad(x, z, rad + 10) || distPoly(x, z, WASH) < WASH_HW + rad + 4 || braidDist(x, z) < rad + 26) continue;
    const hs = [[0, 0], [rad, 0], [-rad, 0], [0, rad], [0, -rad], [rad * 0.7, rad * 0.7], [-rad * 0.7, -rad * 0.7], [rad * 0.7, -rad * 0.7], [-rad * 0.7, rad * 0.7]].map(([dx, dz]) => S.hAt(x + dx, z + dz));
    const lo = Math.min(...hs), hi = Math.max(...hs);
    if (hi - lo > 2.5 || hi > 10) continue;
    // sits on the lowest ground under it (the dune's skirt buries any higher step)
    barchan(S.hills, [x, (lo > 0 ? lo : GROUND) - 0.1, z], (Rd() - 0.5) * 40, W, H + (hi - lo) * 0.6, 17000 + k);
    placed.push([x, z, rad]);
  }
}

// THE TEEPEES: three giant banded cones in the middle of the dune sea, the era's landmark from every road
function buildTeepees(Z, S, R) {
  const g = Z.group('TheTeepees');
  const [x, , z] = TEEPEES;
  teepee(g, [x, GROUND, z], 34, 84, 1501, { fixed: true });
  teepee(g, [x + 46, GROUND, z + 24], 22, 54, 1502, { fixed: true });
  teepee(g, [x - 34, GROUND, z + 38], 17, 36, 1503, { fixed: true, round: true });
  for (let k = 0; k < 7; k++) {
    const a = (k / 7) * Math.PI * 2 + 0.3, r = 52 + R() * 10;
    teepee(g, [x + Math.cos(a) * r, GROUND, z + Math.sin(a) * r], 4 + R() * 4, 6 + R() * 10, 1510 + k, { round: R() > 0.5 });
  }
}

// THE BONE WASH — the Postosuchus's den: a dry riverbed pools out into a bowl of cracked mud between painted cut banks.
// Bones of everything it caught: a phytosaur's long-snouted skull, a tusked dicynodont, ribs and vertebrae strewn down
// the bed. Mud wallows it lies in with only its eyes showing. Its dais is a raised cracked-mud bank under the biggest
// skull, against the south bank (named Throne so every ruler camera finds it). Markers drive the fight.
function buildBoneWash(Z, S, R, route) {
  const { at, den, WASH } = S;
  const g = Z.group('BoneWash');
  const toRoad = Math.atan2(-(at(DEN.seg, DEN.s, 0).p[0] - den.p[0]), -(at(DEN.seg, DEN.s, 0).p[2] - den.p[2]));
  const c = g.at([den.p[0], GROUND, den.p[2]], [0, E.deg(toRoad), 0]); // local -Z points at the road
  const RAD = DEN.r;
  c.cyl({ name: 'WashFloor', axis: 'y', len: 0.12, d: RAD * 2 + 2, p: [0, 0.03, 0], c: '#b98a6a', m: 'Sand', shadow: false });
  // cracked mud: polygon plates with dark seams between them (a jittered grid)
  const mudCols = ['#9a6a52', '#a8785e', '#8e604a', '#b08266'];
  for (let gx = -RAD; gx <= RAD; gx += 5.2) for (let gz = -RAD; gz <= RAD; gz += 5.2) {
    const x = gx + (R() - 0.5) * 1.4, z = gz + (R() - 0.5) * 1.4;
    if (Math.hypot(x, z) > RAD - 2) continue;
    c.box({ name: 'MudPlate', s: [4.4 + R() * 0.6, 0.1, 4.4 + R() * 0.6], p: [x, 0.13 + R() * 0.04, z], r: [0, (R() - 0.5) * 24, 0], c: mudCols[Math.floor(R() * 4)], m: 'Sand', shadow: false });
  }
  // the bed continues out both sides (down the wash, cracked and bone-strewn)
  for (let i = 0; i < WASH.length - 1; i++) {
    const [ax, az] = WASH[i], [bx, bz] = WASH[i + 1];
    const L = Math.hypot(bx - ax, bz - az);
    for (let u = 0; u < L; u += 7) {
      const x = ax + (bx - ax) * (u / L), z = az + (bz - az) * (u / L);
      if (Math.hypot(x - den.p[0], z - den.p[2]) < RAD) continue;
      if (S.nearRoad(x, z, 4)) continue;
      Z.at([x, GROUND, z], [0, E.deg(Math.atan2(bx - ax, bz - az)) + (R() - 0.5) * 30, 0]).box({ name: 'MudPlate', s: [WASH_HW * 1.4 + R() * 3, 0.1, 6 + R() * 2], p: [0, 0.08, 0], c: mudCols[Math.floor(R() * 4)], m: 'Sand', shadow: false });
      if (R() > 0.72) Z.at([x + (R() - 0.5) * WASH_HW, GROUND, z + (R() - 0.5) * WASH_HW], [0, R() * 180, 0]).box({ name: 'LooseBone', s: [0.8, 0.7, 2.5 + R() * 3], p: [0, 0.4, 0], r: [0, 0, R() * 20], c: R() > 0.5 ? P.bone : P.boneLo });
    }
  }
  // mud wallows: dark, wet, glossy - it lies in these with only its eyes above the mud
  const wallows = [[-20, -6, 11], [16, 12, 9], [-6, 18, 7]];
  for (const [x, z, d] of wallows) {
    c.cyl({ name: 'MudWallowRim', axis: 'y', len: 0.3, d: d + 3, p: [x, 0.15, z], c: P.mud, m: 'Sand', shadow: false });
    c.cyl({ name: 'MudWallow', axis: 'y', len: 0.2, d, p: [x, 0.24, z], c: P.mudWet, m: 'SmoothPlastic', refl: 0.12, shadow: false });
    for (let k = 0; k < 3; k++) c.cyl({ name: 'MudBubble', axis: 'y', len: 0.2, d: 0.6 + R() * 0.5, p: [x + (R() - 0.5) * d * 0.5, 0.38, z + (R() - 0.5) * d * 0.5], c: '#6a4434', shadow: false });
  }
  // ledges against the banks: banded rock stacks with flat tops
  const ledgeAt = [[-31, 20, 7.2], [30, 18, 6], [-37, -4, 9.6], [37, -2, 8.4], [-18, 34, 4.8], [20, 34, 7.2]];
  ledgeAt.forEach(([x, z, h], i) => {
    const lc = c.at([x, 0, z]);
    stack(lc, [0, 0, 0], 7.5, h, 6000 + i, 'LedgeRock');
    lc.box({ name: 'LedgeTop', s: [6, 0.5, 6], p: [0, h + 0.25, 0], c: bandAt(h + 0.01), m: 'Sand', studs: 'top', collide: true });
    lc.box({ name: 'LedgeBone', s: [2.4, 0.4, 0.4], p: [(R() - 0.5) * 3, h + 0.7, (R() - 0.5) * 3], r: [0, R() * 180, 0], c: P.bone });
    marker(lc, 'DenLedge' + (i + 1), [0, h + 0.6, 0], 0, { s: [2, 0.4, 2] });
  });
  // the dais: a raised bank of cracked mud against the south bank, under the great skull
  const th = c.at([0, 0, 25]);
  th.box({ name: 'Throne', s: [16, 3.4, 11], p: [0, 1.7, 0], c: '#9a6a52', m: 'Sand', studs: 'top', collide: true });
  th.box({ name: 'ThroneStep', s: [21, 1.4, 15], p: [0, 0.7, 0.8], c: '#8a5c46', m: 'Sand', studs: 'top', collide: true });
  for (let k = 0; k < 6; k++) th.box({ name: 'ThroneCrack', s: [0.3, 0.06, 4 + R() * 4], p: [(R() - 0.5) * 12, 3.42, (R() - 0.5) * 6], r: [0, R() * 180, 0], c: P.crack, shadow: false });
  // the phytosaur: a giant long-snouted skull weathering out of the cut bank, jutting out over the dais like a canopy
  const ph = c.at([-4, 10.6, 52], [-4, 32, 0]).scaled(1.8);
  ph.box({ name: 'PhytoSkull', s: [7, 4.4, 9], p: [0, 2.2, 3], c: P.bone, collide: true });
  ph.box({ name: 'PhytoCrest', s: [3, 1.6, 4], p: [0, 4.8, -0.4], c: P.boneLo });
  for (const sd of [-1, 1]) ph.box({ name: 'EyeSocket', s: [0.4, 1.8, 2.2], p: [sd * 3.5, 3, 2], c: '#4a3a2a' });
  for (let i = 0; i < 6; i++) {
    const w = 3.6 - i * 0.32;
    ph.box({ name: 'PhytoSnout', s: [w, 2 - i * 0.12, 3.4], p: [0, 1.3 - i * 0.05, -2.6 - i * 3.2], c: i % 2 ? P.bone : P.boneLo, collide: i < 2 });
    for (const sd of [-1, 1]) ph.box({ name: 'Tooth', s: [0.35, 1.1, 0.35], p: [sd * (w / 2 - 0.1), 0.1, -2.6 - i * 3.2 + (i % 2) * 0.8], c: '#fff6e0' });
  }
  ph.box({ name: 'PhytoNose', s: [2.2, 1.8, 2], p: [0, 1.3, -22.4], c: P.bone });
  // ...and its armour plates scattered down the bank
  for (let k = 0; k < 8; k++) c.box({ name: 'Osteoderm', s: [1.4, 0.4, 1.8], p: [-12 + k * 3.4 + (R() - 0.5), 0.3 + (k % 3) * 0.1, 36 - Math.abs(k - 4) * 0.8], r: [R() * 20, R() * 60, R() * 20], c: k % 2 ? P.bone : P.boneLo });
  // a tusked dicynodont skull (Placerias), upside down in the mud
  const dc = c.at([-24, 0, 10], [0, 50, 170]);
  dc.box({ name: 'DicyoSkull', s: [4.4, 3, 5], p: [0, -1.4, 0], c: P.bone, collide: true });
  dc.box({ name: 'DicyoBeak', s: [2.4, 1.6, 2], p: [0, -0.6, -3.2], r: [20, 0, 0], c: P.boneLo });
  for (const sd of [-1, 1]) dc.box({ name: 'Tusk', s: [0.7, 0.7, 3], p: [sd * 1.5, -0.2, -2.4], r: [-30, sd * 10, 0], c: '#fff4dc' });
  // a ribcage arching out of the bed on the north side, vertebrae in a curve
  const rc = c.at([20, 0, -14], [0, -30, 0]);
  for (let i = 0; i < 6; i++) for (const sd of [-1, 1]) {
    const z = (i - 2.5) * 1.8;
    rc.beam([sd * 0.6, 0.4, z], [sd * 3.2, 3.6 - Math.abs(i - 2.5) * 0.4, z], 0.5, 0.5, { name: 'Rib', c: P.bone, extend: 0.3 });
    rc.beam([sd * 3.2, 3.6 - Math.abs(i - 2.5) * 0.4, z], [sd * 4.4, 0.2, z + 0.3], 0.45, 0.45, { name: 'Rib', c: P.boneLo, extend: 0.3 });
  }
  for (let i = 0; i < 14; i++) rc.box({ name: 'Vertebra', s: [1.2, 1, 1.4], p: [Math.sin(i * 0.3) * 1.5, 0.5, -7 + i * 1.2], r: [0, i * 8, 0], c: i % 2 ? P.bone : P.boneLo });
  for (let k = 0; k < 16; k++) {
    const a = R() * Math.PI * 2, r = 8 + R() * (RAD - 12);
    c.box({ name: 'LooseBone', s: [0.8, 0.8, 2.5 + R() * 3.5], p: [Math.cos(a) * r, 0.45, Math.sin(a) * r], r: [0, R() * 180, R() * 20], c: k % 2 ? P.bone : P.boneLo });
  }
  // its tracks: a sprawling-gait trail (four feet, tail drag between) from the mouth to the dais
  for (let k = 0; k < 8; k++) {
    for (const sd of [-1, 1]) {
      const pc = c.at([sd * 2.6, 0.2, -36 + k * 6 + (sd > 0 ? 3 : 0)], [0, sd * 8, 0]);
      pc.box({ name: 'TrackHeel', s: [1.4, 0.06, 1.2], p: [0, 0, 0.5], c: '#8a5c48', shadow: false });
      for (const a of [-30, -10, 10, 30]) pc.at([0, 0, -0.2], [0, a, 0]).box({ name: 'TrackToe', s: [0.4, 0.06, 1.4], p: [0, 0, -0.7], c: '#8a5c48', shadow: false });
    }
  }
  c.box({ name: 'TrackTailDrag', s: [0.8, 0.06, 46], p: [0, 0.2, -12], c: '#8a5c48', shadow: false });
  // dead snags on the bank tops
  for (let k = 0; k < 6; k++) {
    const a = 0.8 + (k / 5) * (Math.PI * 2 - 1.6), r = RAD + 10 + R() * 6;
    const wp = c.wpt([Math.sin(a) * r, 0, -Math.cos(a) * r]);
    const lx = wp[0] - DD_ORIGIN[0], lz = wp[2] - DD_ORIGIN[2];
    snag(Z, [lx, S.gy(lx, lz), lz], 7 + R() * 5, 6100 + k);
  }
  // warm low light under the dais, dust drifting across the bed
  const glow = th.box({ name: 'DaisGlow', s: [1, 1, 1], p: [0, 12, -6], t: 1, shadow: false });
  E.pointLight(glow, [1, 0.6, 0.4], 30, 1.1);
  const dust = c.box({ name: 'WashDust', s: [60, 1, 60], p: [0, 1, 0], t: 1, shadow: false });
  dust.set('CanQuery', 'bool', false);
  E.particles(dust, 'Dust', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 3, life: [6, 9], speed: [1, 3], spread: [60, 60], size: [[0, 4], [1, 10]], transp: [[0, 0.78], [1, 1]], color: [0.9, 0.62, 0.5], emission: 0, accel: [1.5, 0.4, 0] });
  // a sign at the mouth, between two horn-like bones
  const mouth = at(DEN.seg, DEN.s, 24);
  const sc = Z.at([mouth.p[0], GROUND, mouth.p[2]], [0, E.deg(toRoad) + 180, 0]);
  E.signBoard(sc, [-7, 4.6, 0], 9, 2.2, 'BONE WASH', { color: '#fff0e6', color2: '#ff6a3a', twoSided: true, pps: 30, trim: '#ff6a3a' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [-7, 2.2, 0.3], c: E.PAL.woodLo });
  for (const sd of [-1, 1]) sc.box({ name: 'TuskPost', s: [1.2, 9, 1.2], p: [-7 + sd * 6.4, 4.2, 0], r: [0, 0, -sd * 12], c: P.bone });
  // markers for the fight + the chase that follows
  const v0 = route.variants[0];
  const segS = (segId, s) => { const k = v0.segs.indexOf(segId); return k < 0 ? 0 : v0.segStart[k] + s; };
  const dm = marker(c, 'DenCenter', [0, 0.5, -8], 0, { s: [2, 1, 2] });
  dm.attr('RouteS', +segS(DEN.seg, DEN.s).toFixed(1)).attr('RouteX', DEN.x).attr('Variant', 1);
  const ff = at(FINAL.seg, FINAL.s, FINAL.x);
  const fm = marker(Z, 'FinalArena', [ff.p[0], GROUND + 0.5, ff.p[2]], 0, { s: [2, 1, 2] });
  fm.attr('RouteS', +segS(FINAL.seg, FINAL.s).toFixed(1)).attr('RouteX', -8).attr('Variant', 1);
}

// THE STUMP CIRCLE: the final stand, a ring of petrified stumps (a grove that turned to stone where it stood)
function buildStumpCircle(Z, S, R) {
  const { at } = S;
  const g = Z.group('StumpCircle');
  const f = at(FINAL.seg, FINAL.s, FINAL.x);
  const road = at(FINAL.seg, FINAL.s, 0);
  const toRoad = Math.atan2(-(road.p[0] - f.p[0]), -(road.p[2] - f.p[2]));
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, E.deg(toRoad), 0]);
  c.cyl({ name: 'CircleFloor', axis: 'y', len: 0.1, d: 74, p: [0, 0.03, 0], c: '#d8a08a', m: 'Pebble', shadow: false });
  for (let k = 0; k < 13; k++) {
    const a = (k / 13) * Math.PI * 2;
    if (Math.abs(Math.atan2(Math.sin(a - Math.PI), Math.cos(a - Math.PI))) < 0.36) continue; // open toward the road (local -Z)
    stump(c, [Math.sin(a) * 33, 0, Math.cos(a) * 33], 5 + R() * 8, 4.4 + R() * 2.6, 7000 + k);
  }
  for (const [k, a] of [[0, 0.9], [1, 2.7], [2, 4.6]]) petrifiedLog(c, [Math.sin(a) * 18, 0, Math.cos(a) * 18], E.deg(a) + 90 + (R() - 0.5) * 20, 9 + R() * 5, 2.3, 7100 + k);
  quartzChips(c, [0, 0, 6], 7200, 10, 14);
  const sc = c.at([7, 0, -38], [0, 180, 0]);
  E.signBoard(sc, [0, 4.4, 0], 8, 2.2, 'STUMP CIRCLE', { color: '#fff0e6', color2: '#ff6a2a', twoSided: true, pps: 30, trim: '#ff6a2a' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: E.PAL.woodLo });
  const glow = c.box({ name: 'CircleGlow', s: [1, 1, 1], p: [0, 10, 0], t: 1, shadow: false });
  E.pointLight(glow, [1, 0.7, 0.85], 34, 0.7);
}

function buildNestSite(Z, n, S, R) {
  const { at } = S;
  const f = at(n.seg, n.s, n.x);
  const g = Z.group('Nest_' + n.species);
  g.parent.attr('NestId', n.id).attr('Species', n.species).tag('ExpeditionNest');
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, R() * 360, 0]);
  const big = n.species === 'Plateosaurus';
  const pal = n.id === 1 ? { clear: '#e8c8a8', mound: '#d8b08a', trim: '#3fc8b0' } : n.id === 2 ? { clear: '#c8a08a', mound: '#8a6a40', trim: '#7aa842' } : { clear: '#c07a5a', mound: '#a8583e', trim: '#ff5a2a' };
  c.cyl({ name: 'Clearing', axis: 'y', len: 0.1, d: big ? 30 : 24, p: [0, 0.05, 0], c: pal.clear, m: 'Sand', shadow: false });
  c.cyl({ name: 'NestMound', axis: 'y', len: 1.1, d: big ? 12 : 9, p: [0, 0.55, 0], c: pal.mound, m: 'Sand' });
  for (let k = 0; k < 15; k++) {
    const a = (k / 15) * Math.PI * 2;
    const r = big ? 5.8 : 4.3;
    if (n.id === 3) c.box({ name: 'NestStone', s: [1.6, 0.9, 1.3], p: [Math.cos(a) * r, 1, Math.sin(a) * r], r: [R() * 20, -E.deg(a), R() * 15], c: P.redRock[k % 4], m: 'Slate' });
    else c.box({ name: 'NestFrond', s: [3, 0.5, 1.2], p: [Math.cos(a) * r, 1.15 + (k % 2) * 0.3, Math.sin(a) * r], r: [R() * 20, -E.deg(a) + 90, R() * 15], c: n.id === 1 ? P.horsetail[k % 3] : P.cycad[k % 3] });
  }
  for (let k = 0; k < 3; k++) {
    const egg = buildEgg(n.species);
    B.scaleTree(egg, big ? 0.72 : 0.6);
    const a = (k / 3) * Math.PI * 2;
    B.transformTree(egg, c.frame.mul(new CF(Math.cos(a) * 1.3, 1.35, Math.sin(a) * 1.3)).mul(CF.deg(0, k * 40, (k - 1) * 8)));
    egg.tags = [];
    egg.name = 'NestEgg';
    g.parent.add(egg);
  }
  // (2026-10-13: the flag stood right on GuardSpot1 - the first guard (a raptor) was impaled on its pole in every
  // scene. Now midway between two guard spots, outside the guard ring and the clearing)
  E.flag(c, [0.37, 0, 16], pal.trim, { h: 7 });
  const sgn = Z.at([f.base[0] - f.r[0] * (n.x > 0 ? -21 : 21), GROUND, f.base[2] - f.r[2] * (n.x > 0 ? -21 : 21)], [0, yawOf(f) + 180, 0]);
  E.signBoard(sgn, [0, 4.2, 0], 7, 2.2, n.label, { color: '#fff0e6', color2: pal.trim, twoSided: true, pps: 30, trim: pal.trim });
  sgn.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
  for (let k = 0; k < 3; k++) {
    const a = (k / 3) * Math.PI * 2 + 0.5;
    const m = c.box({ name: 'GuardSpot' + (k + 1), s: [1.5, 1, 1.5], p: [Math.cos(a) * (big ? 11 : 9), 0.5, Math.sin(a) * (big ? 11 : 9)], r: [0, -E.deg(a) - 90, 0], t: 1, shadow: false });
    m.set('CanQuery', 'bool', false);
  }
  const host = c.box({ name: 'NestCore', s: [2, 2, 2], p: [0, 1.8, 0], t: 1, shadow: false });
  host.set('CanQuery', 'bool', false);
  const pr = new Inst('ProximityPrompt', 'GrabPrompt');
  pr.set('ActionText', 'string', 'Grab Egg').set('ObjectText', 'string', n.label).set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 10).set('HoldDuration', 'float', 1.6).set('RequiresLineOfSight', 'bool', false).set('Exclusivity', 'token', 1);
  pr.attr('NestId', n.id);
  host.add(pr);
  E.particles(host, 'NestGlint', { rate: 3, life: [0.8, 1.4], speed: [0.5, 1], size: [[0, 0.5], [1, 0]], color: [1, 0.9, 0.7], emission: 0.8 });
  E.pointLight(host, [1, 0.78, 0.6], 18, 0.7);
  // each site dressed for its dino
  const toRoadA = Math.atan2(at(n.seg, n.s, 0).p[2] - f.p[2], at(n.seg, n.s, 0).p[0] - f.p[0]);
  const ring = (k, total, r0, r1) => { const a = (k / total) * Math.PI * 2 + 0.4; const r = r0 + R() * (r1 - r0); return [f.p[0] + Math.cos(a) * r, f.p[2] + Math.sin(a) * r, a]; };
  const facingRoad = (a) => Math.abs(Math.atan2(Math.sin(a - toRoadA), Math.cos(a - toRoadA))) < 0.55;
  if (n.id === 1) {
    // OASIS PACK: a sandbar between two channels, horsetail walls, a few tree ferns and conifers for the pack to slip between
    for (let k = 0; k < 12; k++) { const [x, z, a] = ring(k, 12, 15, 21); if (facingRoad(a)) continue; horsetails(Z, [x, GROUND, z], 8000 + k, { n: 5, h: 6 + R() * 3, spread: 4 }); }
    for (let k = 0; k < 5; k++) { const [x, z, a] = ring(k + 0.5, 5, 24, 30); if (facingRoad(a)) continue; if (R() > 0.5) treeFern(Z, [x, GROUND, z], 7 + R() * 4, 8100 + k); else conifer(Z, [x, GROUND, z], 18 + R() * 8, 8100 + k); }
  } else if (n.id === 2) {
    // TALL CYCADS: a grove of towering cycads and conifers among the petrified logs; it rears up to strip them
    for (let k = 0; k < 9; k++) { const [x, z, a] = ring(k, 9, 16, 24); if (facingRoad(a)) continue; cycad(Z, [x, GROUND, z], 6 + R() * 5, 8200 + k); }
    for (let k = 0; k < 6; k++) { const [x, z, a] = ring(k + 0.5, 6, 27, 34); if (facingRoad(a)) continue; conifer(Z, [x, GROUND, z], 26 + R() * 12, 8300 + k); }
    for (let k = 0; k < 4; k++) { const a = R() * Math.PI * 2; c.box({ name: 'StrippedFrond', s: [0.8, 0.15, 3.4], p: [Math.cos(a) * 7, 0.15, Math.sin(a) * 7], r: [0, R() * 180, 0], c: '#9aa24a', shadow: false }); }
  } else {
    // CREST ROCKS: red fins in pairs around a gravel scrape
    for (let k = 0; k < 7; k++) { const [x, z, a] = ring(k, 7, 17, 22); if (facingRoad(a)) continue; crestRock(Z, [x, GROUND, z], -E.deg(a) + 90, 9 + R() * 5, 8400 + k); }
    for (let k = 0; k < 5; k++) { const [x, z] = ring(k + 0.5, 5, 9, 13); E.rock(Z, [x, GROUND, z], 0.9 + R() * 0.6, 8500 + k, { colors: P.redRock, moss: false }); }
  }
}

// weather: dust devils over the dunes, a faint heat shimmer on the flats, glints off the quartz
function buildWeather(Z, S, R) {
  const g = Z.group('Weather', 'Folder');
  const spots = [[-200, 250], [-100, 300], [120, 220], [-390, 140], [80, -60], [-30, 200]];
  spots.forEach(([x, z], k) => {
    const h = g.box({ name: 'DustDevil', s: [2, 1, 2], p: [x, GROUND + 0.5, z], t: 1, shadow: false });
    h.set('CanQuery', 'bool', false);
    E.particles(h, 'Column', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 14, life: [2.5, 4], speed: [7, 11], dir: 1, spread: [7, 7], size: [[0, 1.5], [0.5, 5], [1, 10]], transp: [[0, 0.55], [0.7, 0.75], [1, 1]], color: [0.9, 0.6, 0.46], emission: 0, accel: [0, 2, 0], drag: 0.6 });
    E.particles(h, 'Grit', { rate: 10, life: [1, 2], speed: [4, 8], dir: 1, spread: [30, 30], size: [[0, 0.3], [1, 0.1]], color: [0.72, 0.4, 0.28], emission: 0, accel: [0, -4, 0] });
    h.attr('Wander', 18 + k * 3);
  });
  // heat shimmer: big faint warm haze sheets hugging the ground over the dunes and the stone forest
  for (const [x, z, w, d] of [[-60, 240, 220, 120], [-120, -250, 220, 90], [-360, 60, 90, 180], [160, -230, 200, 80]]) {
    const hz = g.box({ name: 'HeatShimmer', s: [w, 1, d], p: [x, GROUND + 1.5, z], t: 1, shadow: false });
    hz.set('CanQuery', 'bool', false);
    E.particles(hz, 'Shimmer', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 4, life: [6, 10], speed: [0.5, 1.5], dir: 1, spread: [80, 80], size: [[0, 12], [1, 26]], transp: [[0, 0.9], [0.5, 0.84], [1, 1]], color: [1, 0.82, 0.7], emission: 0.05 });
  }
  // where the ambience may drift fern fronds (the oases); a plain marker with a Radius the client can test against
  const n1 = S.at(NESTS[0].seg, NESTS[0].s, NESTS[0].x);
  for (const [x, z, r] of [[n1.p[0], n1.p[2], 70], [POOLS[0][0], POOLS[0][1], 50], [POOLS[2][0], POOLS[2][1], 50], [300, 230, 50]]) marker(g, 'FrondZone', [x, GROUND + 2, z], 0, { s: [2, 2, 2] }).attr('Radius', r);
  // the low sun catching the quartz across the stone forest
  for (let k = 0; k < 4; k++) {
    const f = S.at('StoneForest', 30 + k * 85, (k % 2 ? 1 : -1) * 40);
    const gl = g.box({ name: 'QuartzGlints', s: [60, 2, 60], p: [f.p[0], GROUND + 1.5, f.p[2]], t: 1, shadow: false });
    gl.set('CanQuery', 'bool', false);
    E.particles(gl, 'Glint', { rate: 4, life: [0.4, 0.9], speed: [0, 0.1], size: [[0, 0.5], [0.5, 0.8], [1, 0]], color: [1, 0.92, 1], emission: 0.7 });
  }
}

function buildCinematics(Z, S) {
  const { at } = S;
  const g = Z.group('Cinematics', 'Folder');
  const shot = (name, pos, look) => {
    const l = Z.wpt(look);
    const m = marker(g, name, pos, 0, { s: [1, 1, 1] });
    m.attr('LookX', +l[0].toFixed(2)).attr('LookY', +l[1].toFixed(2)).attr('LookZ', +l[2].toFixed(2));
    return m;
  };
  const n1 = at(NESTS[0].seg, NESTS[0].s, NESTS[0].x);
  const n2 = at(NESTS[1].seg, NESTS[1].s, NESTS[1].x);
  const den = at(DEN.seg, DEN.s, DEN.x);
  const denRoad = at(DEN.seg, DEN.s, -16);
  // 1. sunrise over the painted hills: from high over the red dunes by the arrival, across the teepees to the stone forest
  shot('EstShot1', [-430, 92, 380], [-60, 16, 10]);
  // 2. the stone forest: low among the petrified logs, the Plateosaurus grove beyond
  shot('EstShot2', [n2.p[0] + 64, 12, n2.p[2] - 34], [n2.p[0] + 6, 3, n2.p[2] - 4]);
  // 3. the oasis: from the Blue Mesa's rim down across the channels to the sandbar nest
  shot('EstShot3', [n1.p[0] - 40, 20, n1.p[2] + 38], [n1.p[0] + 2, 2, n1.p[2] + 2]);
  // 4. the bone wash from above the road
  shot('EstShot4', [denRoad.p[0], 44, denRoad.p[2]], [den.p[0], 6, den.p[2]]);
}

// ------------------------------------------------------------------ vegetation + scatter
function buildScatter(Z, S, R) {
  const { at, segs, nearRoad, WASH, den } = S;
  const VG = Z.group('Vegetation');
  const placed = [];
  const keepOut = [];
  keepOut.push([den.p[0], den.p[2], DEN.r + 16]);
  { const f = at(FINAL.seg, FINAL.s, FINAL.x); keepOut.push([f.p[0], f.p[2], 40]); }
  for (const n of NESTS) { const f = at(n.seg, n.s, n.x); keepOut.push([f.p[0], f.p[2], n.id === 2 ? 38 : 32]); }
  keepOut.push([TEEPEES[0] + 6, TEEPEES[2] + 16, 66]);
  { const f = at(BRIDGE.seg, BRIDGE.s); keepOut.push([f.p[0], f.p[2], 36]); }
  { const f = at('SunriseRoad', 130); keepOut.push([f.p[0], f.p[2], 52]); }
  { const f = at('SunriseRoad', 0); keepOut.push([f.p[0], f.p[2] + 10, 44]); keepOut.push([f.p[0] + 30, f.p[2] - 30, 14]); }
  for (const [x, z, r] of S.logs || []) keepOut.push([x, z, r + 2]);
  for (const [x, z, r] of S.dunes || []) keepOut.push([x, z, r]);
  for (const [x, z] of S.oasisPlaced || []) keepOut.push([x, z, 5]);
  const tryPlace = (x, z, pad, gap) => {
    if (Math.abs(x) > BX - 24 || z < BZ0 + 24 || z > BZ1 - 24) return false;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr + pad * 0.3)) return false;
    if (nearRoad(x, z, pad)) return false;
    if (placed.some(([px, pz]) => Math.hypot(px - x, pz - z) < gap)) return false;
    placed.push([x, z]);
    return true;
  };
  const wet = (x, z) => braidDist(x, z) < 26;
  // road verges: green by the water, scrub and stones in the desert
  for (const sg of Object.values(segs)) {
    for (let s = 6; s < sg.cum[sg.cum.length - 1]; s += 14 + R() * 10) {
      for (const side of [-1, 1]) {
        if (R() < 0.35) continue;
        const f = at(sg.id, s, side * (sg.width / 2 + 5 + R() * 9));
        if (!tryPlace(f.p[0], f.p[2], 3, 7)) continue;
        const gy = S.gy(f.p[0], f.p[2]);
        if (wet(f.p[0], f.p[2])) {
          const k = R();
          if (k < 0.4) horsetails(VG, [f.p[0], gy, f.p[2]], 50000 + placed.length, { n: 4, h: 4 + R() * 3 });
          else if (k < 0.7) treeFern(VG, [f.p[0], gy, f.p[2]], 6 + R() * 4, 50000 + placed.length);
          else cycad(VG, [f.p[0], gy, f.p[2]], 2 + R() * 3, 50000 + placed.length);
        } else {
          const k = R();
          if (k < 0.45) E.bush(VG, [f.p[0], gy, f.p[2]], 0.8 + R() * 0.5, 50000 + placed.length, { colors: P.scrub, n: 4 });
          else if (k < 0.7) E.rock(VG, [f.p[0], gy, f.p[2]], 0.8 + R() * 0.9, 50000 + placed.length, { colors: P.rock, moss: false });
          else if (k < 0.85) quartzChips(VG, [f.p[0], gy, f.p[2]], 50000 + placed.length, 4, 3);
          else snag(VG, [f.p[0], gy, f.p[2]], 4 + R() * 4, 50000 + placed.length);
        }
      }
    }
  }
  // the open desert: oases green, the rest sparse - teepees, scrub, rocks, dead snags, the odd lone conifer
  for (let k = 0; k < 7000 && placed.length < 900; k++) {
    const x = (R() - 0.5) * 2 * (BX - 26), z = BZ0 + 26 + R() * (BZ1 - BZ0 - 52);
    if (distPoly(x, z, WASH) < WASH_HW + 3) continue;
    const gy = S.gy(x, z);
    const pick = R();
    if (wet(x, z)) {
      if (pick < 0.3) { if (tryPlace(x, z, 6, 9)) treeFern(VG, [x, gy, z], 6 + R() * 6, 54000 + k); }
      else if (pick < 0.5) { if (tryPlace(x, z, 8, 14)) conifer(VG, [x, gy, z], 16 + R() * 14, 54000 + k); }
      else if (pick < 0.75) { if (tryPlace(x, z, 4, 6)) horsetails(VG, [x, gy, z], 54000 + k, { n: 4 + Math.floor(R() * 3), h: 4 + R() * 4 }); }
      else if (pick < 0.88) { if (tryPlace(x, z, 4, 7)) cycad(VG, [x, gy, z], 2 + R() * 4, 54000 + k); }
      else if (tryPlace(x, z, 3, 5)) E.fern(VG, [x, gy, z], 1.2 + R() * 0.8, 54000 + k);
      continue;
    }
    if (pick < 0.1) { if (gy <= GROUND && tryPlace(x, z, 12, 26)) teepee(VG, [x, GROUND, z], 4 + R() * 7, 6 + R() * 16, 54000 + k, { round: R() > 0.5 }); }
    else if (pick < 0.32) { if (tryPlace(x, z, 4, 9)) E.bush(VG, [x, gy, z], 0.8 + R() * 0.6, 54000 + k, { colors: P.scrub, n: 4 }); }
    else if (pick < 0.5) { if (tryPlace(x, z, 5, 10)) E.rock(VG, [x, gy, z], 1 + R() * 1.8, 54000 + k, { colors: R() > 0.5 ? P.rock : [bandAt(gy + 2), bandAt(gy + 4), bandAt(gy)], moss: false }); }
    else if (pick < 0.58) { if (tryPlace(x, z, 4, 12)) snag(VG, [x, gy, z], 5 + R() * 5, 54000 + k); }
    else if (pick < 0.62) { if (tryPlace(x, z, 8, 30)) conifer(VG, [x, gy, z], 14 + R() * 10, 54000 + k); }
    else if (pick < 0.7) { if (tryPlace(x, z, 3, 8)) quartzChips(VG, [x, gy, z], 54000 + k, 3 + Math.floor(R() * 3), 3); }
    else if (pick < 0.76) { if (gy <= GROUND && tryPlace(x, z, 6, 16)) petrifiedLog(VG, [x, GROUND, z], R() * 180, 8 + R() * 10, 2 + R() * 1.4, 54000 + k); }
    else if (tryPlace(x, z, 3, 7)) E.grassTufts(VG, [x, gy, z], 54000 + k, { n: 4, spread: 3, colors: ['#c8a060', '#b89050', '#d8b070'], scale: 1.4 });
  }
  // the desert floor: pink flats, white alkali, darker red sand, so the open ground never reads as one flat sheet
  const floorR = rng(81234);
  for (let k = 0, made = 0; k < 2400 && made < 260; k++) {
    const x = (floorR() - 0.5) * 2 * (BX - 25), z = BZ0 + 25 + floorR() * (BZ1 - BZ0 - 50);
    if (nearRoad(x, z, 4) || S.hAt(x, z) > 0) continue;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr)) continue;
    if (braidDist(x, z) < 6) continue;
    const pick = floorR();
    E.groundPatch(VG, [x, GROUND, z], 6 + floorR() * 8, 82000 + k, { colors: pick < 0.5 ? P.flat : pick < 0.75 ? ['#c25a34', '#b84f2e', '#cf6a3e'] : [P.alkali, '#ead0c0', '#f4e4d4'], m: 'Sand' });
    made++;
  }
}

// ------------------------------------------------------------------ Luau data
function routeData(route, at) {
  const O = DD_ORIGIN;
  const V = route.variants;
  const segS = (v, segId, s) => { const k = v.segs.indexOf(segId); return k < 0 ? null : v.segStart[k] + s; };
  const variants = V.map((v) => {
    const flat = [];
    for (const p of v.pts) flat.push(+(p[0] + O[0]).toFixed(2), +(p[1] + ROAD).toFixed(2), +(p[2] + O[2]).toFixed(2));
    const widths = v.segs.map((id, k) => [+v.segStart[k].toFixed(1), route.segs[id].width / 2]);
    return { Choices: v.choices.map((c) => c + 1), Length: +v.length.toFixed(1), Step: RT.STEP, Points: flat, HalfWidths: widths };
  });
  const forks = ['ForkA', 'ForkB'].map((node, j) => {
    const k = V[0].segs.findIndex((id) => route.segs[id].from === node);
    const pick = (c) => route.segs[V.find((v) => v.choices[j] === c).segs[k]].name;
    return { Index: j + 1, S: V.map((v) => +v.segStart[k].toFixed(1)), Labels: [pick(0), pick(1)] };
  });
  const perVariant = (segId, s) => V.map((v) => { const r = segS(v, segId, s); return r === null ? -1 : +r.toFixed(1); });
  const features = FEATURES.map(([type, seg, s, x, o = {}], i) => ({ Id: i + 1, Type: type, S: perVariant(seg, s), X: x, W: o.w || 0, Len: o.len || 0 }));
  const sections = SECTIONS.map(([seg, s, name]) => ({ Name: name, S: perVariant(seg, s) }));
  const nests = NESTS.map((n) => {
    const f = at(n.seg, n.s, n.x);
    return { Id: n.id, Species: n.species, Guard: n.guard, Label: n.label, S: perVariant(n.seg, n.s), X: n.x, Pos: [+(f.p[0] + O[0]).toFixed(2), GROUND + O[1], +(f.p[2] + O[2]).toFixed(2)] };
  });
  const arrival = at('SunriseRoad', 4);
  return {
    Zone: 'DawnDesert', Name: 'DAWN DESERT', Era: '215,000,000 BC', Year: -215000000,
    Variants: variants, Forks: forks, Features: features, Sections: sections, Nests: nests,
    Arrival: [arrival.p[0] + O[0], ROAD, arrival.p[2] + O[2], arrival.f[0], arrival.f[2]],
  };
}

// mapqc: what in this era is a self-contained prop (prunable) and what is walkable ground
const QC = {
  decor: ['OldLog', 'Horsetails', 'Conifer', 'Snag', 'QuartzChips', 'PetrifiedLog', 'PetrifiedStump', 'Teepee', 'GreatTeepee', 'Sentinel', 'CrestRock'],
  ground: /^(GroundPatch|DesertFloor|WashCrust|DuneRipple|DuneFace|DuneBack|DuneHorn|DuneCrest|ChannelBank|OasisWater|WaterGlint|PoolShore|PoolWater|CanyonSand|CanyonWater|WashFloor|MudWallow|MudWallowRim|MudBubble|CircleFloor|DigPit|SkyMesa|TrackTailDrag|LookoutDeck)$/,
};

module.exports = { buildDawnDesert, DD_ORIGIN, QC };
