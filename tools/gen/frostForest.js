// FROST FOREST — era (125,000,000 BC). Cold Cretaceous forest at a snowy blue dawn: snow-laden dark pines, golden
// ginkgo trees on white snow, frozen lakes of cracked blue ice, steaming hot springs, black volcanic ash ridges and a
// smoking volcano on the skyline. Ruler: the YUTYRANNUS, on the ice of the White Lake.
//   Pine Road (Glider Pines / Microraptor) → fork: Frozen Lake (an ice road straight across the lake) | Ash Ridge (a
//   black ash ridge with smoking vents) → Ginkgo Hollow (Fern Hollow / Psittacosaurus; the White Lake den opens off the
//   right) → fork: Hot Springs (steaming travertine terraces) | Fallen Giants (huge fallen trunks, Log Warren / Compy)
//   → Homestretch (the Frost Stones final stand) → Return Portal.
//   Zone-local space: origin = FF_ORIGIN, north = -Z.
const { Inst, Ctx, CF, shade, rng } = require('./builder.js');
const E = require('./env.js');
const RT = require('./route.js');
const NPC = require('./npcs.js');
const { buildEgg } = require('./eggs.js');
const B = require('./builder.js');

const FF_ORIGIN = [2100, 0, -2600];
const GROUND = 0.5, ROAD = 0.62, ICE_TOP = GROUND + 0.06;
const BX = 420, BZ0 = -330, BZ1 = 430;
const P = {
  snow: ['#f4f8fc', '#eaf1f8', '#e1eaf4', '#f9fbfe'], snowShade: '#d3e0ee', snowSide: '#c4d4e4', snowBlue: '#b6cce2',
  pine: ['#1d4a3b', '#245541', '#173f33', '#2a5e47'], bark: ['#4a3426', '#3e2c20', '#56402e'],
  gold: ['#ffc21f', '#f5ad12', '#ffd640', '#ec9a10'], goldLeaf: ['#ffcb2e', '#f2a91a', '#ffdc58', '#e8941a'],
  ginkgoBark: ['#8e7e70', '#7c6c60', '#9a8a7c'],
  ice: ['#a6dbf0', '#94cfea', '#b6e3f5', '#86c4e4'], iceDeep: '#4a92c4', iceDark: '#2f6f9e', crack: '#ffffff', icicle: '#d2f0fd',
  ash: ['#3a3a40', '#44444b', '#2f2f35', '#4e4d55'], basalt: ['#26272c', '#303137', '#1f2025', '#393a41'], ember: '#ff6a2a',
  rock: ['#6a7480', '#5a6470', '#7a8490', '#525c68'], cliff: ['#5a6470', '#4c5662', '#68727e', '#444e5a', '#727c88'],
  road: '#8a7f76', roadLo: '#5e554f', ashRoad: '#3c3a3e', iceRoad: '#d6edf8', iceRut: '#a8d0e4',
  wood: '#7a5a3e', woodLo: '#5a4230', woodHi: '#9a7450', dirt: '#5e4a3a',
  trav: ['#efe0bf', '#e6cfa2', '#f4e8cf'], travRim: ['#e3964a', '#d0743a', '#eab060'], spring: '#3cc8cf', springDeep: '#1f9aa8',
  moss: ['#5d9a4a', '#4f8a40', '#6aa852'], fern: ['#3f9a3a', '#4fb043'],
};
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
    PineRoad: { from: 'Arrival', to: 'ForkA', width: 26, name: 'PINE ROAD', pts: [[-40, 0, 380], [-34, 1, 312], [-52, 2, 252], [-46, 1, 200], [-40, 0, 150]] },
    FrozenLake: { from: 'ForkA', to: 'MergeA', width: 26, name: 'FROZEN LAKE', pts: [[-40, 0, 150], [-92, 0, 108], [-148, 0, 40], [-168, 0, -40], [-132, 0, -110], [-70, 0, -150]] },
    AshRidge: { from: 'ForkA', to: 'MergeA', width: 22, name: 'ASH RIDGE', pts: [[-40, 0, 150], [8, 3, 100], [40, 10, 30], [32, 14, -48], [-18, 8, -110], [-70, 0, -150]] },
    GinkgoHollow: {
      from: 'MergeA', to: 'ForkB', width: 28, name: 'GINKGO HOLLOW',
      pts: [[-70, 0, -150], [-64, 0, -208], [-8, 0, -248], [88, 0, -254], [170, 0, -216], [228, 0, -140]],
    },
    HotSprings: { from: 'ForkB', to: 'MergeB', width: 24, name: 'HOT SPRINGS', pts: [[228, 0, -140], [292, 0, -88], [340, 0, -8], [336, 0, 80], [296, 0, 150]] },
    FallenGiants: { from: 'ForkB', to: 'MergeB', width: 22, name: 'FALLEN GIANTS', pts: [[228, 0, -140], [214, 0, -60], [198, 0, 20], [218, 0, 96], [296, 0, 150]] },
    Homestretch: { from: 'MergeB', to: 'Exit', width: 28, name: 'HOMESTRETCH', pts: [[296, 0, 150], [302, 1, 220], [266, 0, 290], [206, 0, 338], [150, 0, 368]] },
  },
};

const SECTIONS = [
  ['PineRoad', 0, 'PINE ROAD'], ['FrozenLake', 0, 'FROZEN LAKE'], ['AshRidge', 0, 'ASH RIDGE'],
  ['GinkgoHollow', 0, 'GINKGO HOLLOW'], ['HotSprings', 0, 'HOT SPRINGS'], ['FallenGiants', 0, 'FALLEN GIANTS'], ['Homestretch', 0, 'HOMESTRETCH'],
];
const NESTS = [
  { id: 1, species: 'Microraptor', seg: 'PineRoad', s: 132, x: 36, guard: 'Pack', label: 'GLIDER PINES' },
  { id: 2, species: 'Psittacosaurus', seg: 'GinkgoHollow', s: 150, x: 34, guard: 'Herd', label: 'FERN HOLLOW' },
  { id: 3, species: 'Compy', seg: 'FallenGiants', s: 130, x: 36, guard: 'Pack', label: 'LOG WARREN' },
];
const FEATURES = [
  ['Darts', 'PineRoad', 200, 6], ['Darts', 'GinkgoHollow', 90, -7], ['Darts', 'GinkgoHollow', 380, 0], ['Darts', 'HotSprings', 60, 0], ['Darts', 'FallenGiants', 40, 0], ['Darts', 'Homestretch', 90, 6],
  // pine road: a straight run between the pines to wake the boost up
  ['Boost', 'PineRoad', 50, 0], ['Coin', 'PineRoad', 76, 6], ['Coin', 'PineRoad', 82, 6], ['Coin', 'PineRoad', 88, 6], ['Repair', 'PineRoad', 170, -7],
  // frozen lake: the long ice road, fast and open
  ['Boost', 'FrozenLake', 70, 0], ['Coin', 'FrozenLake', 110, -5], ['Coin', 'FrozenLake', 116, -5], ['Coin', 'FrozenLake', 122, -5], ['Boost', 'FrozenLake', 170, 5], ['Coin', 'FrozenLake', 210, 0], ['Repair', 'FrozenLake', 260, 0],
  // ash ridge: up the black ridge and down again
  ['Coin', 'AshRidge', 60, 0], ['Coin', 'AshRidge', 66, 0], ['Boost', 'AshRidge', 150, 0], ['Coin', 'AshRidge', 200, 5], ['Coin', 'AshRidge', 206, 5], ['Repair', 'AshRidge', 250, 0],
  // ginkgo hollow: the herd of the hollow crosses the road
  ['Boost', 'GinkgoHollow', 40, 0], ['Coin', 'GinkgoHollow', 120, 8], ['Coin', 'GinkgoHollow', 126, 8], ['Charge', 'GinkgoHollow', 230, 0, { len: 50 }], ['Repair', 'GinkgoHollow', 310, -6], ['Coin', 'GinkgoHollow', 350, 0], ['Coin', 'GinkgoHollow', 356, 0],
  // hot springs + fallen giants
  ['Boost', 'HotSprings', 110, 0], ['Coin', 'HotSprings', 150, 6], ['Coin', 'HotSprings', 156, 6], ['Repair', 'HotSprings', 230, 0],
  ['Coin', 'FallenGiants', 80, 0], ['Coin', 'FallenGiants', 86, 0], ['Boost', 'FallenGiants', 180, 0], ['Repair', 'FallenGiants', 230, -5],
  ['Stampede', 'Homestretch', 110, 0, { len: 50 }], ['Boost', 'Homestretch', 150, 0], ['Coin', 'Homestretch', 180, -6], ['Coin', 'Homestretch', 186, -6],
];
// the White Lake (the ruler's den, off the right of Ginkgo Hollow), the Frost Stones final stand on the homestretch,
// the big frozen lake the ice road crosses, the hot spring terraces, the Elder Ginkgo at the mouth of the hollow
const DEN = { seg: 'GinkgoHollow', s: 255, x: 84 };
const FINAL = { seg: 'Homestretch', s: 70, x: 64 };
const LAKE = { x: -122, z: 10, rx: 92, rz: 104 };
const SPRINGS = { x: 274, z: 34, r: 40 };
const ELDER = [-136, 0, -238];
const PINE_GATE = { seg: 'PineRoad', s: 44 };
const LOG_ARCH = { seg: 'FallenGiants', s: 60 };

// ------------------------------------------------------------------ the plants and rocks of the frost forest
// snow-laden pine: dark green tiers (alternately turned 45°, so they read as stars from above), each carrying a slab
// of snow that shows as a white ring under the next tier
function snowPine(ctx, p, h, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group(o.name || 'SnowPine');
  const t = g.at(p, [0, o.yaw !== undefined ? o.yaw : R() * 360, 0]);
  const w = Math.max(1, h * 0.055);
  const trunkH = Math.max(2.4, h * (o.trunk || 0.17));
  t.box({ name: 'PineTrunk', s: [w, trunkH + 0.8, w], p: [0, (trunkH + 0.8) / 2, 0], c: P.bark[Math.floor(R() * 3)], studs: 'sides', collide: true });
  const tiers = o.tiers || Math.max(3, Math.min(6, Math.round(h / 6.5)));
  const th = (h - trunkH) / (tiers + 0.4);
  const R0 = (o.spread || 0.27) * h + 1;
  const snowy = o.snow !== undefined ? o.snow : 0.85;
  for (let k = 0; k < tiers; k++) {
    const u = k / tiers;
    const r = Math.max(1.1, R0 * (1 - u * 0.8));
    const y = trunkH + k * th + th * 0.5;
    const yaw = (k % 2) * 45 + (R() - 0.5) * 8;
    t.box({ name: 'PineTier', s: [r * 2, th * 1.12, r * 2], p: [0, y, 0], r: [0, yaw, 0], c: P.pine[(k + seed) % 4], studs: 'top' });
    if (R() < snowy) t.box({ name: 'PineSnow', s: [r * 2 - 0.4, 0.8, r * 2 - 0.4], p: [0, y + th * 0.56 + 0.38, 0], r: [0, yaw, 0], c: P.snow[k % 4], studs: 'top' });
  }
  const ty = trunkH + tiers * th + th * 0.3;
  t.box({ name: 'PineTip', s: [1.3, th * 0.9, 1.3], p: [0, ty, 0], r: [0, 45, 0], c: P.pine[1], studs: 'top' });
  t.box({ name: 'PineTipSnow', s: [1.1, 0.45, 1.1], p: [0, ty + th * 0.45 + 0.2, 0], r: [0, 45, 0], c: P.snow[0] });
  // perches: long bare boughs reaching out over a nest, snow along the top (Glider Pines)
  for (const pr of o.perches || []) {
    const b = t.at([0, pr.y, 0], [0, pr.yaw - (o.yaw !== undefined ? o.yaw : 0), 0]);
    b.box({ name: 'PerchBough', s: [0.9, 0.9, pr.len], p: [0, 0, -pr.len / 2], r: [-6, 0, 0], c: P.bark[1] });
    b.box({ name: 'BoughSnow', s: [0.8, 0.3, pr.len * 0.8], p: [0, 0.62, -pr.len * 0.5], r: [-6, 0, 0], c: P.snow[1] });
    b.box({ name: 'BoughNeedles', s: [3, 1.2, 3], p: [0, 0.2 + Math.sin(6 * Math.PI / 180) * pr.len, -pr.len], c: P.pine[2], studs: 'top' });
    b.box({ name: 'BoughNeedleSnow', s: [2.6, 0.35, 2.6], p: [0, 0.95 + Math.sin(6 * Math.PI / 180) * pr.len, -pr.len], c: P.snow[0] });
  }
  return g;
}

// ginkgo: a pale grey trunk, branches swept up, clouds of golden fan-leaves with a dusting of snow, gold litter below
function ginkgo(ctx, p, h, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group(o.name || 'Ginkgo');
  const t = g.at(p, [0, R() * 360, 0]);
  const w = Math.max(0.9, h * 0.075);
  const n = Math.max(3, Math.round(h * 0.62 / 3));
  for (let i = 0; i < n; i++) t.box({ name: 'GinkgoTrunk', s: [w * (1 - i * 0.07), 3.1, w * (1 - i * 0.07)], p: [0, 1.5 + i * 3, 0], r: [0, i * 21, 0], c: P.ginkgoBark[i % 3], studs: 'sides', collide: i === 0 });
  const topY = n * 3;
  const clusters = [[0, topY + h * 0.08, 0, h * 0.3]];
  const arms = o.arms || 4;
  for (let k = 0; k < arms; k++) {
    const a = (k / arms) * Math.PI * 2 + R() * 0.6;
    const y0 = h * (0.38 + R() * 0.2);
    const L = h * (0.24 + R() * 0.08);
    const end = [Math.cos(a) * L, y0 + L * 0.75, Math.sin(a) * L];
    t.beam([0, y0, 0], end, w * 0.42, w * 0.42, { name: 'GinkgoBranch', c: P.ginkgoBark[1], extend: 0.4 });
    clusters.push([end[0], end[1] + h * 0.04, end[2], h * (0.2 + R() * 0.06)]);
  }
  clusters.forEach(([x, y, z, s], k) => {
    t.box({ name: 'GinkgoLeaves', s: [s * 1.3, s * 0.72, s * 1.2], p: [x, y, z], r: [0, R() * 90, 0], c: P.gold[k % 4], studs: 'top' });
    t.box({ name: 'GinkgoLeaves', s: [s * 0.95, s * 0.6, s * 1.05], p: [x + (R() - 0.5) * s * 0.5, y + s * 0.34, z + (R() - 0.5) * s * 0.5], r: [0, R() * 90, 0], c: P.gold[(k + 2) % 4], studs: 'top' });
    if (k === 0 || R() < 0.45) t.box({ name: 'GinkgoSnow', s: [s * 0.7, 0.36, s * 0.7], p: [x + (R() - 0.5) * s * 0.2, y + s * 0.66, z + (R() - 0.5) * s * 0.2], r: [0, R() * 90, 0], c: P.snow[0] });
  });
  // the gold carpet: fallen fans on the snow under the crown
  const lit = o.litter !== undefined ? o.litter : 3;
  for (let k = 0; k < lit; k++) {
    const a = R() * Math.PI * 2, r = R() * h * 0.22;
    t.box({ name: 'GoldLitter', s: [h * (0.16 + R() * 0.12), 0.08, h * (0.12 + R() * 0.1)], p: [Math.cos(a) * r, 0.04 + k * 0.012, Math.sin(a) * r], r: [0, R() * 180, 0], c: P.goldLeaf[k % 4], shadow: false });
  }
  return g;
}

// a charred dead tree on the ash ridge, snow on its stubs
function ashSnag(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('AshSnag');
  const t = g.at(p, [0, R() * 360, 0]);
  t.box({ name: 'SnagTrunk', s: [1.1, h, 1.1], p: [0, h / 2, 0], r: [(R() - 0.5) * 8, 0, (R() - 0.5) * 8], c: '#1f1e22', collide: true });
  t.box({ name: 'SnagCap', s: [1.2, 0.4, 1.2], p: [0, h + 0.15, 0], c: P.snow[1] });
  for (let k = 0; k < 2; k++) {
    const y = h * (0.45 + k * 0.22);
    const b = t.at([0, y, 0], [0, k * 150 + R() * 40, 0]);
    b.box({ name: 'SnagArm', s: [0.45, 0.45, 2.6 + R() * 1.6], p: [0, 0.7, -1.4], r: [-30, 0, 0], c: '#2a282c' });
  }
  return g;
}

// a blue-grey boulder with a studded snow cap and icicles hanging off its brow
function iceRock(ctx, p, k, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group('IceRock');
  const b = g.at(p, [0, R() * 360, 0]);
  const col = (i) => (o.colors || P.rock)[i % 4];
  b.box({ name: 'Rock', s: [2.3 * k, 1.6 * k, 2 * k], p: [0, 0.7 * k, 0], r: [0, 0, R() * 6], c: col(0), m: 'Slate', collide: k > 1.2 });
  b.box({ name: 'Rock', s: [1.4 * k, 1.1 * k, 1.3 * k], p: [1 * k, 0.45 * k, 0.6 * k], r: [0, 30, R() * 12], c: col(1), m: 'Slate', collide: k > 1.2 });
  b.box({ name: 'Rock', s: [1 * k, 0.8 * k, 1 * k], p: [-1.05 * k, 0.32 * k, -0.5 * k], r: [R() * 16, 15, 0], c: col(2), m: 'Slate' });
  b.box({ name: 'RockSnow', s: [2.1 * k, 0.32 * k, 1.8 * k], p: [0, 1.52 * k + 0.16 * k, 0], c: P.snow[Math.floor(R() * 4)], studs: 'top' });
  const n = o.icicles !== undefined ? o.icicles : 3 + Math.floor(R() * 3);
  for (let i = 0; i < n; i++) {
    const x = -0.9 * k + (i / Math.max(1, n - 1)) * 1.8 * k;
    const L = (0.5 + R() * 0.7) * k;
    b.box({ name: 'Icicle', s: [0.3 * k, L, 0.3 * k], p: [x, 1.5 * k - L / 2, -1.02 * k], c: P.icicle, m: 'Glass', t: 0.12, shadow: false });
    b.box({ name: 'IcicleTip', s: [0.15 * k, L * 0.5, 0.15 * k], p: [x, 1.5 * k - L - L * 0.2, -1.02 * k], c: P.icicle, m: 'Glass', t: 0.12, shadow: false });
  }
  return g;
}

// a wind-carved snow drift: stepped studded white blocks with a lee slope
function snowDrift(ctx, p, k, seed) {
  const R = rng(seed);
  const g = ctx.group('SnowDrift');
  const b = g.at(p, [0, R() * 360, 0]);
  b.box({ name: 'Drift', s: [5 * k, 0.9 * k, 3.4 * k], p: [0, 0.45 * k, 0], c: P.snow[1], studs: 'top' });
  b.box({ name: 'Drift', s: [3.4 * k, 0.8 * k, 2.4 * k], p: [-0.4 * k, 1.25 * k, 0.2 * k], c: P.snow[0], studs: 'top' });
  b.wedgeF({ name: 'DriftLee', s: [3.4 * k, 1.6 * k, 2 * k], p: [-0.4 * k, 0.8 * k, -2.4 * k], face: 'front', c: P.snow[2] });
  if (R() > 0.5) b.box({ name: 'Drift', s: [1.6 * k, 0.6 * k, 1.4 * k], p: [1.4 * k, 1.9 * k, 0.4 * k], c: P.snow[3], studs: 'top' });
  return g;
}

// a clump of hexagonal-ish basalt columns (two turned boxes per column), snow on the flat tops
function basalt(ctx, p, h, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group(o.name || 'BasaltCluster');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = o.n || 4 + Math.floor(R() * 3);
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + R() * 0.5, r = i === 0 ? 0 : 1.6 + R() * 1.2;
    const ch = h * (i === 0 ? 1 : 0.45 + R() * 0.45);
    const x = Math.cos(a) * r, z = Math.sin(a) * r, w = 1.7 + R() * 0.5;
    for (const yaw of [0, 60]) t.box({ name: 'BasaltColumn', s: [w, ch, w * 0.9], p: [x, ch / 2, z], r: [0, yaw + i * 17, 0], c: P.basalt[(i + (yaw ? 1 : 0)) % 4], m: 'Slate', collide: yaw === 0 && i < 3 });
    if (R() < 0.75) t.box({ name: 'ColumnSnow', s: [w * 0.9, 0.35, w * 0.9], p: [x, ch + 0.17, z], r: [0, i * 17 + 30, 0], c: P.snow[0], studs: 'top' });
  }
  return g;
}

// smooth 2D value noise in [-1, 1]
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
const lakeE = (x, z) => Math.hypot((x - LAKE.x) / LAKE.rx, (z - LAKE.z) / LAKE.rz); // < 1 = on the ice
const yawOf = (f) => E.deg(Math.atan2(-f.f[0], -f.f[2]));

function buildFrostForest() {
  const route = RT.buildRoute(DEF);
  const root = new Inst('Model', 'FrostForest');
  root.attr('Zone', 'FrostForest');
  const Z = new Ctx({ parent: root, frame: new CF(...FF_ORIGIN), defaults: { anchored: true } });
  const R = rng(125125);
  const segs = route.segs;
  for (const s of Object.values(segs)) s.cum = RT.cumOf(s.samples);
  const at = (segId, s, x = 0, y = 0) => { const sg = segs[segId]; return RT.at(sg.samples, sg.cum, s, x, y); };
  const roadPts = [];
  for (const s of Object.values(segs)) for (const p of s.samples) roadPts.push([p[0], p[2], s.width / 2]);
  const nearRoad = (x, z, pad) => roadPts.some(([px, pz, hw]) => Math.hypot(x - px, z - pz) < hw + pad);
  const ashPts = segs.AshRidge.samples.filter((_, i) => i % 3 === 0).map((p) => [p[0], p[2]]);
  const ashDist = (x, z) => ashPts.reduce((m, [px, pz]) => Math.min(m, Math.hypot(x - px, z - pz)), Infinity);
  const hollowPts = segs.GinkgoHollow.samples.filter((_, i) => i % 3 === 0).map((p) => [p[0], p[2]]);
  const hollowDist = (x, z) => Math.min(Math.hypot(x - ELDER[0], z - ELDER[2]) - 30, hollowPts.reduce((m, [px, pz]) => Math.min(m, Math.hypot(x - px, z - pz)), Infinity));
  for (const sg of Object.values(segs)) for (const p of sg.samples) p[1] = Math.max(0, p[1]);

  // ------------------------------------------------ ground: deep snow
  const G = Z.group('Ground', 'Folder');
  G.box({ name: 'Snow', s: [BX * 2 + 60, 4, BZ1 - BZ0 + 60], p: [0, GROUND - 2, (BZ0 + BZ1) / 2], c: P.snow[1], studs: 'top', collide: true });

  // ------------------------------------------------ terrain: snowy swells, black ash on the ridge, bowls for the set pieces
  const T = terrain(Z, segs, at, ashDist, hollowDist);
  const hAt = T.hAt;
  const gyAt = (x, z) => Math.max(GROUND, hAt(x, z));

  // ------------------------------------------------ roads: packed gravel through the snow, black ash on the ridge, a ploughed lane on the ice
  const roads = Z.group('Roads', 'Folder');
  const onIce = (x, z) => lakeE(x, z) < 1.02;
  for (const sg of Object.values(segs)) {
    const W = sg.width;
    const n = sg.samples.length;
    const head = (u, v) => Math.atan2(sg.samples[v][0] - sg.samples[u][0], sg.samples[v][2] - sg.samples[u][2]);
    const angDiff = (x, y) => Math.abs(Math.atan2(Math.sin(x - y), Math.cos(x - y)));
    let tile = 0;
    for (let i = 0; i < n - 1;) {
      let j = Math.min(n - 1, i + 3);
      const h0 = head(i, Math.min(n - 1, i + 1));
      const ice0 = onIce(sg.samples[i][0], sg.samples[i][2]);
      while (j < n - 1 && sg.cum[j + 1] - sg.cum[i] <= 28 && angDiff(head(i, j + 1), h0) < 0.02 && Math.abs(sg.samples[j + 1][1] - sg.samples[i][1]) < 0.02 && onIce(sg.samples[j + 1][0], sg.samples[j + 1][2]) === ice0) j++;
      const a = sg.samples[i], b = sg.samples[j];
      const i0 = i;
      i = j;
      const ice = ice0 && onIce(b[0], b[2]);
      const ash = sg.id === 'AshRidge' && sg.cum[i0] > 30 && sg.cum[j] < sg.cum[n - 1] - 30;
      const base = ice ? P.iceRoad : ash ? P.ashRoad : P.road;
      const tone = tile++ % 2 ? base : shade(base, 0.95);
      const ya = ROAD + a[1], yb = ROAD + b[1];
      roads.beam([a[0], ya - 0.3, a[2]], [b[0], yb - 0.3, b[2]], W, 0.6, { name: 'Road', c: tone, m: ice ? 'Ice' : ash ? 'Slate' : 'Pebble', collide: true, extend: 0.2 });
      const flatHere = Math.abs(yb - ya) < 0.02 && Math.abs(ROAD + sg.samples[Math.max(0, i0 - 3)][1] - ya) < 0.02;
      if (flatHere && i0 > 0) roads.cyl({ name: 'RoadJoint', axis: 'y', len: 0.6, d: W, p: [a[0], ya - 0.33, a[2]], c: base, m: ice ? 'Ice' : ash ? 'Slate' : 'Pebble', collide: true });
      // tyre tracks: snow packed white in the gravel, blue grooves in the ice
      const fa = RT.frameAt(sg.samples, i0), fb = RT.frameAt(sg.samples, j);
      for (const rx of [-W * 0.18, W * 0.18]) roads.beam([a[0] + fa.r[0] * rx, ya + 0.02, a[2] + fa.r[2] * rx], [b[0] + fb.r[0] * rx, yb + 0.02, b[2] + fb.r[2] * rx], 1.4, 0.04, { name: 'Rut', c: ice ? P.iceRut : ash ? '#29272b' : P.roadLo, m: ice ? 'Ice' : 'SmoothPlastic', shadow: false, extend: 0.3 });
    }
    // edges: snow-pole markers (red tops) on land, orange flag poles on the ice, ploughed snow berms on both
    for (let s = 6; s < sg.cum[n - 1] - 6; s += 9) {
      if ((sg.id === 'PineRoad' && s < 22) || (sg.id === 'Homestretch' && s > sg.cum[n - 1] - 26)) continue;
      const k = Math.floor(s / 9);
      for (const side of [-1, 1]) {
        const f = at(sg.id, s, side * (W / 2 + 3.6)); // (past the rover's reach: it ploughed through the berms at +1.6)
        const ice = onIce(f.p[0], f.p[2]);
        const c = roads.at([f.p[0], ROAD + f.base[1] - 0.1, f.p[2]], [0, yawOf(f), 0]);
        if (k % 2 === 0) c.box({ name: 'SnowBerm', s: [1.8, 0.7 + (k % 3) * 0.15, 8], p: [side * 0.4, 0.3, 0], c: P.snow[k % 4], studs: 'top', shadow: false });
        if (k % 3 === 0 && (k / 3 + (side > 0 ? 1 : 0)) % 2 === 0) {
          const h = 4.2;
          c.box({ name: 'SnowPole', s: [0.32, h, 0.32], p: [side * 1.1, h / 2, 0], c: ice ? '#2b2d31' : '#f4f4f4' });
          c.box({ name: 'SnowPoleTop', s: [0.36, 1.1, 0.36], p: [side * 1.1, h - 0.4, 0], c: ice ? '#ff7a1a' : '#e8402e' });
          if (ice) c.box({ name: 'PoleFlag', s: [0.06, 0.7, 1.1], p: [side * 1.1, h - 0.5, -0.6], c: '#ff7a1a', shadow: false });
        }
      }
    }
  }

  // ------------------------------------------------ boundary: snowy rock cliffs, black ash ridges, white peaks, the volcano
  const SNOWTOP = { top: P.snow[0], overhang: [P.snow[0], P.snow[2], P.pine[0]], vines: false, moss: false };
  E.cliffWall(Z, [[-BX, BZ0], [BX, BZ0], [BX, BZ1], [-BX, BZ1], [-BX, BZ0]], { ...SNOWTOP, h: 56, d: 26, seed: 1251, slope: 6, name: 'FrostCliffs', chunk: 16, colors: P.cliff, trees: false });
  buildSkyline(Z, R);

  // ------------------------------------------------ set pieces
  buildArrival(Z, at);
  buildPineGate(Z, at, R);
  buildFrozenLake(Z, segs, at, R);
  buildAshRidge(Z, segs, at, R, hAt);
  buildElderGinkgo(Z, R);
  buildHotSprings(Z, at, R);
  buildFallenGiants(Z, segs, at, R);
  for (const n of NESTS) buildNestSite(Z, n, at, R);
  buildWhiteLake(Z, at, R, route);
  buildFrostStones(Z, at, R);
  buildReturnPortal(Z, at);
  buildWeather(Z, at, R);
  buildCinematics(Z, at);
  { const f = at('PineRoad', 0); const c = Z.at([f.p[0] + 22, GROUND, f.p[2] - 14], [0, 60, 0]); NPC.buildNpc(c.parent, c.world(new CF(0, 0, 0)), 'Ranger'); }

  // ------------------------------------------------ vegetation: dark pines everywhere, gold ginkgos in the hollow, snags on the ash
  const VG = Z.group('Forest');
  const placed = [];
  const keepOut = [];
  { const d = at(DEN.seg, DEN.s, DEN.x); keepOut.push([d.p[0], d.p[2], 58]); }
  { const f = at(FINAL.seg, FINAL.s, FINAL.x); keepOut.push([f.p[0], f.p[2], 40]); const m = at(FINAL.seg, FINAL.s, FINAL.x / 2); keepOut.push([m.p[0], m.p[2], 22]); }
  for (const n of NESTS) { const f = at(n.seg, n.s, n.x); keepOut.push([f.p[0], f.p[2], 30]); }
  keepOut.push([SPRINGS.x, SPRINGS.z, SPRINGS.r + 12]);
  keepOut.push([ELDER[0], ELDER[2], 34]);
  { const f = at('PineRoad', 0); keepOut.push([f.p[0], f.p[2], 34]); }
  { const f = at('Homestretch', 1e9); keepOut.push([f.p[0], f.p[2], 30]); }
  { const f = at(PINE_GATE.seg, PINE_GATE.s); keepOut.push([f.p[0], f.p[2], 30]); }
  { const f = at(DEN.seg, DEN.s, 34); keepOut.push([f.p[0], f.p[2], 24]); }
  { const f = at(LOG_ARCH.seg, LOG_ARCH.s); keepOut.push([f.p[0], f.p[2], 36]); }
  const tryPlace = (x, z, pad, gap) => {
    if (Math.abs(x) > BX - 22 || z < BZ0 + 22 || z > BZ1 - 22) return false;
    if (lakeE(x, z) < 1.12) return false;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr + pad * 0.3)) return false;
    if (nearRoad(x, z, pad)) return false;
    if (placed.some(([px, pz]) => Math.hypot(px - x, pz - z) < gap)) return false;
    placed.push([x, z]);
    return true;
  };
  // the verges: small pines, drifts, icy boulders; gold ginkgos along the hollow, snags along the ridge
  for (const sg of Object.values(segs)) {
    for (let s = 8; s < sg.cum[sg.cum.length - 1]; s += 13 + R() * 9) {
      for (const side of [-1, 1]) {
        if (R() < 0.25) continue;
        const f = at(sg.id, s, side * (sg.width / 2 + 6 + R() * 8));
        const x = f.p[0], z = f.p[2];
        const gy = gyAt(x, z);
        const ash = ashDist(x, z) < 40, hollow = hollowDist(x, z) < 40;
        const pick = R();
        if (hollow && pick < 0.55) { if (tryPlace(x, z, 6, 10)) ginkgo(VG, [x, gy, z], 12 + R() * 7, 30000 + placed.length); }
        else if (ash && pick < 0.5) { if (tryPlace(x, z, 3, 8)) ashSnag(VG, [x, gy, z], 6 + R() * 6, 30000 + placed.length); }
        else if (pick < 0.62) { if (tryPlace(x, z, 5, 9)) snowPine(VG, [x, gy, z], 11 + R() * 7, 30000 + placed.length, { spread: 0.24 }); }
        else if (pick < 0.8) { if (tryPlace(x, z, 3, 7)) snowDrift(VG, [x, gy, z], 0.8 + R() * 0.6, 30000 + placed.length); }
        else if (tryPlace(x, z, 3, 7)) iceRock(VG, [x, gy, z], 1 + R() * 0.8, 30000 + placed.length, { colors: ash ? P.basalt : P.rock });
      }
    }
  }
  // the golden groves: the hollow floor and the frozen lake's west shore glow gold against the snow
  for (let k = 0, made = 0; k < 3000 && made < 70; k++) {
    const x = (R() - 0.5) * 2 * (BX - 24), z = BZ0 + 24 + R() * (BZ1 - BZ0 - 48);
    const le = lakeE(x, z);
    const grove = hollowDist(x, z) < 60 || (le > 1.14 && le < 1.5 && x < LAKE.x + 20);
    if (!grove) continue;
    if (tryPlace(x, z, 7, 11)) { ginkgo(VG, [x, gyAt(x, z), z], 13 + R() * 11, 35000 + k, { litter: 4 }); made++; }
  }
  // the deep forest
  for (let k = 0; k < 9000 && placed.length < 1050; k++) {
    const x = (R() - 0.5) * 2 * (BX - 24), z = BZ0 + 24 + R() * (BZ1 - BZ0 - 48);
    const gy = gyAt(x, z);
    const ash = ashDist(x, z) < 60, hollow = hollowDist(x, z) < 75;
    const pick = R();
    if (hollow) {
      if (pick < 0.5) { if (tryPlace(x, z, 9, 14)) ginkgo(VG, [x, gy, z], 14 + R() * 12, 40000 + k); }
      else if (pick < 0.62) { if (tryPlace(x, z, 10, 15)) snowPine(VG, [x, gy, z], 22 + R() * 14, 40000 + k); }
      else if (pick < 0.78) { if (tryPlace(x, z, 3, 6)) E.fern(VG, [x, gy, z], 1.3 + R() * 0.7, 40000 + k); }
      else if (pick < 0.9) { if (tryPlace(x, z, 3, 7)) snowDrift(VG, [x, gy, z], 0.8 + R() * 0.6, 40000 + k); }
      else if (tryPlace(x, z, 3, 7)) iceRock(VG, [x, gy, z], 1 + R(), 40000 + k);
    } else if (ash) {
      if (pick < 0.4) { if (tryPlace(x, z, 3, 8)) ashSnag(VG, [x, gy, z], 7 + R() * 8, 40000 + k); }
      else if (pick < 0.62) { if (tryPlace(x, z, 4, 10)) basalt(VG, [x, gy, z], 5 + R() * 7, 40000 + k); }
      else if (pick < 0.8) { if (tryPlace(x, z, 8, 14)) snowPine(VG, [x, gy, z], 16 + R() * 10, 40000 + k, { snow: 0.5 }); }
      else if (tryPlace(x, z, 3, 7)) iceRock(VG, [x, gy, z], 1.1 + R(), 40000 + k, { colors: P.basalt });
    } else {
      if (pick < 0.62) { if (tryPlace(x, z, 10, 11)) snowPine(VG, [x, gy, z], 22 + R() * 22, 40000 + k); }
      else if (pick < 0.7) { if (tryPlace(x, z, 9, 24)) ginkgo(VG, [x, gy, z], 16 + R() * 8, 40000 + k); }
      else if (pick < 0.8) { if (tryPlace(x, z, 3, 8)) snowDrift(VG, [x, gy, z], 0.9 + R() * 0.8, 40000 + k); }
      else if (pick < 0.9) { if (tryPlace(x, z, 4, 9)) iceRock(VG, [x, gy, z], 1.2 + R() * 1.4, 40000 + k); }
      else if (tryPlace(x, z, 4, 8)) E.bush(VG, [x, gy, z], 0.9 + R() * 0.6, 40000 + k, { n: 5, colors: [P.pine[0], P.pine[3], P.snow[0], P.pine[1], P.snow[1]] });
    }
  }
  // the forest floor: blue snow shadows, gold leaf fall in the hollow, grey ash fall on the ridge
  const floorR = rng(81251);
  for (let k = 0, made = 0; k < 3000 && made < 300; k++) {
    const x = (floorR() - 0.5) * 2 * (BX - 25), z = BZ0 + 25 + floorR() * (BZ1 - BZ0 - 50);
    if (nearRoad(x, z, 4) || lakeE(x, z) < 1.1) continue;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr)) continue;
    const gy = gyAt(x, z);
    const hollow = hollowDist(x, z) < 70, ash = ashDist(x, z) < 50;
    const cols = hollow ? P.goldLeaf : ash ? ['#55545c', '#6a6970', '#4a4950', P.snow[2]] : [P.snowShade, P.snowBlue, P.snow[3], '#dce8f4'];
    E.groundPatch(VG, [x, gy, z], (hollow ? 4 : 6) + floorR() * 6, 82000 + k, { colors: cols, m: 'SmoothPlastic', n: 2 });
    made++;
  }

  // keep the rover's lane clear: decor in the way is removed, anything else is reported for a fix
  {
    const lanes = [];
    for (const sg of Object.values(segs)) for (const p of sg.samples) lanes.push({ x: p[0] + FF_ORIGIN[0], z: p[2] + FF_ORIGIN[2], y: ROAD + p[1], hw: sg.width / 2 });
    const rc = require('./mapqc.js').clearRoad(root, lanes, { decor: QC.decor, ground: QC.ground });
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
function terrain(Z, segs, at, ashDist, hollowDist) {
  const CELL = 14, STEP = 1.2;
  const N = noise2(1251);
  const fbm = (x, z) => 0.62 * N(x / 130, z / 130) + 0.38 * N(x / 55 + 11, z / 55 - 23);
  const road = [];
  for (const sg of Object.values(segs)) sg.samples.forEach((p, i) => { if (i % 2 === 0) road.push([p[0], p[2], sg.width / 2, p[1]]); });
  const nearestRoad = (x, z) => {
    let best = Infinity, y = 0;
    for (const [px, pz, hw, py] of road) { const d = Math.hypot(x - px, z - pz) - hw; if (d < best) { best = d; y = py; } }
    return [best, y];
  };
  const circles = [];
  const addAt = (seg, s, x, r) => { const f = at(seg, s, x); circles.push([f.p[0], f.p[2], r]); };
  addAt('PineRoad', 0, 0, 52); addAt('PineRoad', 0, 24, 30);
  addAt('Homestretch', 1e9, 0, 42);
  for (const n of NESTS) addAt(n.seg, n.s, n.x, 32);
  addAt(DEN.seg, DEN.s, DEN.x, 50);
  addAt(DEN.seg, DEN.s, 40, 22);
  addAt(FINAL.seg, FINAL.s, FINAL.x, 40);
  addAt(PINE_GATE.seg, PINE_GATE.s, 0, 30);
  addAt(LOG_ARCH.seg, LOG_ARCH.s, 0, 40);
  circles.push([SPRINGS.x, SPRINGS.z, SPRINGS.r + 8]);
  circles.push([ELDER[0], ELDER[2], 30]);
  const corridor = [['GinkgoHollow', 0, 1e9, 34], ['HotSprings', 0, 1e9, 22], ['FallenGiants', 0, 1e9, 30], ['FrozenLake', 0, 1e9, 20]];
  const corridorPts = corridor.map(([seg, s0, s1, lat]) => {
    const sg = segs[seg]; const L = sg.cum[sg.cum.length - 1];
    const pts = [];
    for (let s = s0; s <= Math.min(s1, L); s += 6) { const f = at(seg, s); pts.push([f.p[0], f.p[2], lat]); }
    return pts;
  });
  const openness = (x, z) => {
    let k = smooth(1.04, 1.4, lakeE(x, z));
    for (const [cx, cz, r] of circles) k = Math.min(k, smooth(r, r + 24, Math.hypot(x - cx, z - cz)));
    for (const pts of corridorPts) for (const [px, pz, lat] of pts) k = Math.min(k, smooth(lat, lat + 22, Math.hypot(x - px, z - pz)));
    return k;
  };
  // named shapes: the ash ridge spine runs on north into a black shoulder; the hollow has high white rims
  const BUMPS = [[96, -60, 22, 46], [-250, -170, 26, 60], [140, 300, 18, 60], [-300, 230, 24, 64], [360, -250, 20, 50], [40, -320, 16, 60]];
  const bump = (x, z) => BUMPS.reduce((acc, [bx, bz, A, r]) => acc + A * Math.exp(-((x - bx) ** 2 + (z - bz) ** 2) / (r * r)), 0);
  const heights = new Map();
  const key = (i, j) => i + ',' + j;
  const G = Z.group('Hills', 'Folder');
  const cells = [];
  for (let x0 = -BX + CELL / 2; x0 < BX; x0 += CELL) {
    for (let z0 = BZ0 + CELL / 2; z0 < BZ1; z0 += CELL) {
      const i = Math.round(x0 / CELL), j = Math.round(z0 / CELL);
      const [d, ry] = nearestRoad(x0, z0);
      const edge = Math.min(x0 + BX, BX - x0, z0 - BZ0, BZ1 - z0);
      const ad = ashDist(x0, z0);
      // snowfields: soft swells, rising toward the cliffs; the ash ridge stands up as a black spine
      let H = 2 + 15 * Math.max(0, fbm(x0, z0) + 0.12) + 24 * (1 - smooth(10, 80, edge)) + bump(x0, z0) + 10 * (1 - smooth(20, 70, ad));
      const t = smooth(10, 54, d) * openness(x0, z0);
      let h = ry * (1 - smooth(10, 54, d)) + H * t;
      h = h < 14 ? Math.floor(h / STEP) * STEP : 14 + Math.floor((h - 14) / 3.6) * 3.6;
      if (d < CELL * 0.75 + 1) h = Math.min(h, Math.floor((ry - 0.5) / STEP) * STEP);
      if (h < STEP) { heights.set(key(i, j), 0); continue; }
      heights.set(key(i, j), h);
      const top = Math.min(1.2, h);
      const tone = Math.floor((N(x0 / 70 + 9, z0 / 70 - 4) + 1) * 2) % 4;
      const ash = ad < 46 + 18 * N(x0 / 40, z0 / 40);
      // ash: black slopes with the odd white streak; snow: white tops, blue-white sides, grey rock where it's high
      const topC = ash ? (tone === 3 ? P.snow[2] : P.ash[tone]) : P.snow[tone];
      const sideC = ash ? P.basalt[Math.floor(h / 4.8) % 4] : h > 24 ? P.cliff[Math.floor(h / 3.6) % 5] : h > 10 ? ['#a9bccf', '#9fb3c8', '#b3c5d6'][Math.floor(h / 3.6) % 3] : P.snowSide;
      cells.push({ i, j, x: x0, z: z0, h, top, topC, sideC, sideM: ash || h > 24 ? 'Slate' : 'SmoothPlastic' });
    }
  }
  const parts = E.heightfield(G, cells, CELL, {});
  const OR = rng(6363);
  const tors = Z.group('Outcrops');
  for (const c of cells) {
    if (c.h < 18 || OR() > 0.05) continue;
    iceRock(tors, [c.x + (OR() - 0.5) * 6, c.h + GROUND - 0.2, c.z + (OR() - 0.5) * 6], 2 + OR() * 1.6, 6300 + c.i * 97 + c.j, { colors: ashDist(c.x, c.z) < 50 ? P.basalt : P.rock });
  }
  const cellOf = (v, lo) => Math.round((lo + CELL / 2 + Math.floor((v - lo) / CELL) * CELL) / CELL);
  const hAt = (x, z) => heights.get(key(cellOf(x, -BX), cellOf(z, BZ0))) || 0;
  console.log('                   snowfields: ' + cells.length + ' columns -> ' + parts + ' parts');
  return { hAt };
}

// ------------------------------------------------------------------ skyline
function buildSkyline(Z, R) {
  const M = Z.group('Skyline');
  // white peaks behind the cliffs: three jostling massifs each, blue-grey rock under heavy snow, dark ribs showing through
  const peak = (x, z, w, d, h, seed) => {
    const r = rng(seed);
    const massifs = [[0, 0, 1], [(r() > 0.5 ? 1 : -1) * w * (0.32 + r() * 0.12), (r() - 0.5) * d * 0.3, 0.55 + r() * 0.2], [(r() > 0.5 ? 1 : -1) * w * (0.3 + r() * 0.14), (r() - 0.5) * d * 0.3, 0.38 + r() * 0.18]];
    for (const [ox, oz, k] of massifs) {
      const H = h * k, n = 5;
      let px = x + ox;
      const rockC = shade('#56616f', 0.9 + r() * 0.15);
      for (let t = 0; t < n; t++) {
        const u = t / n;
        const sw = w * (0.45 + k * 0.55) * (1 - u * 0.8), sd = d * (0.5 + k * 0.5) * (1 - u * 0.76);
        px += (r() - 0.5) * sw * 0.16;
        const snowT = t >= 2 || (t === 1 && r() < 0.4);
        const yaw = (r() - 0.5) * 36;
        if (t < n - 1) M.box({ name: 'Peak', s: [sw, H / n + 1, sd], p: [px, (t + 0.5) * (H / n), z + oz], r: [0, yaw, (r() - 0.5) * 5], c: snowT ? P.snow[t % 4] : rockC, m: snowT ? 'SmoothPlastic' : 'Slate' });
        else {
          // a gabled snow summit so the skyline reads as peaks, not stacked boxes
          const ridge = M.at([px, t * (H / n), z + oz], [0, yaw + 90, 0]);
          ridge.wedgeF({ name: 'Peak', s: [sw * 1.2, H / n * 2.2, sd * 0.62], p: [0, H / n * 1.1, -sd * 0.31], face: 'front', c: P.snow[0] });
          ridge.wedgeF({ name: 'Peak', s: [sw * 1.2, H / n * 2.2, sd * 0.62], p: [0, H / n * 1.1, sd * 0.31], face: 'back', c: P.snow[2] });
        }
      }
    }
  };
  for (let k = 0; k < 7; k++) { if (k === 3 || k === 4) continue; peak(-525 + k * 175 + (R() - 0.5) * 20, -480 - R() * 50, 150, 120, 140 + R() * 100, 700 + k); }
  for (let k = 0; k < 4; k++) { peak(-470 - R() * 15, -250 + k * 180, 110, 150, 110 + R() * 70, 720 + k); peak(470 + R() * 15, -240 + k * 180, 110, 150, 110 + R() * 70, 730 + k); }
  for (let k = 0; k < 6; k++) peak(-450 + k * 180 + (R() - 0.5) * 30, 500 + R() * 25, 130, 90, 90 + R() * 60, 740 + k);
  // black ash ridges in front of the white peaks to the north-east (the volcano's side)
  for (let k = 0; k < 5; k++) {
    const x = 120 + k * 100, z = -420 - (k % 2) * 30;
    for (let t = 0; t < 3; t++) M.box({ name: 'AshRidgeFar', s: [130 - t * 34, 22, 60 - t * 14], p: [x + (R() - 0.5) * 10, 11 + t * 20, z], r: [0, 18 + (R() - 0.5) * 10, 0], c: t === 2 ? P.snow[2] : P.ash[(k + t) % 4], m: 'Slate' });
  }
  // THE VOLCANO: a broad dark cone streaked with snow, a dull red throat, a slow plume of smoke and ash
  const V = Z.at([90, 0, -525]);
  const tiers = 11, TH = 19;
  for (let t = 0; t < tiers; t++) {
    const w = 330 - t * 27, d = w * 0.7;
    V.box({ name: 'Volcano', s: [w, TH + 1, d], p: [0, TH / 2 + t * TH, 0], r: [0, (t % 3 - 1) * 4, 0], c: P.basalt[t % 4], m: 'Slate' });
    // snow streaks down the upper flanks (white on black: readable from the whole map)
    // the cap: the top tiers wear snow; long white gullies run down the black flanks from it
    if (t >= 8) V.box({ name: 'VolcanoSnow', s: [w + 1, TH + 1.2, d + 1], p: [0, TH / 2 + t * TH, 0], r: [0, (t % 3 - 1) * 4, 0], c: P.snow[t % 4] });
    else for (const [fx, from] of [[-0.34, 3], [-0.1, 5], [0.16, 2], [0.37, 6]]) { if (t < from) continue; V.box({ name: 'VolcanoSnow', s: [w * 0.06 + 2, TH + 1.4, d + 1.2], p: [fx * (330 - 8 * 27), TH / 2 + t * TH, 0], r: [0, (t % 3 - 1) * 4, 0], c: P.snow[t % 4] }); }
  }
  V.box({ name: 'Volcano', s: [70, 8, 52], p: [0, tiers * TH + 2, 0], c: P.basalt[1], m: 'Slate' });
  const crater = V.box({ name: 'Crater', s: [40, 3, 30], p: [0, tiers * TH + 5.2, 0], c: '#b8441e', m: 'Neon' });
  E.particles(crater, 'Smoke', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 5, life: [10, 14], speed: [7, 12], dir: 1, spread: [12, 12], size: [[0, 22], [1, 70]], transp: [[0, 0.25], [1, 1]], color: [0.3, 0.29, 0.31], emission: 0, accel: [3, 0.5, 0] });
  E.particles(crater, 'Ash', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 3, life: [12, 16], speed: [5, 9], dir: 1, spread: [20, 20], size: [[0, 30], [1, 90]], transp: [[0, 0.55], [1, 1]], color: [0.16, 0.15, 0.17], emission: 0, accel: [5, -0.4, 0] });
}

// ------------------------------------------------------------------ portals + arrival
function hexPortal(ctx, p, yaw, Rr, name, o = {}) {
  const g = ctx.group(name);
  const c = g.at(p, [0, yaw, 0]);
  const cy = Rr * Math.sin(Math.PI / 3) - 1.8;
  const F = c.at([0, cy, 0]);
  const pts = Array.from({ length: 6 }, (_, k) => { const a = (k * 60 * Math.PI) / 180; return [Math.cos(a) * Rr, Math.sin(a) * Rr]; });
  for (let k = 0; k < 6; k++) {
    const [ax, ay] = pts[k], [bx, by] = pts[(k + 1) % 6];
    F.beam([ax, ay, 0], [bx, by, 0], 3.6, 3, { name: 'PortalBeam', c: '#5a6676', m: 'Slate', studs: 'top', extend: 1, up: [0, 0, 1] });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNode', s: [4.4, 4.4, 4.8], c: '#2b2d31', m: 'Metal', studs: 'all' });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNodeCore', s: [2, 2, 5], c: o.color || '#7fd8ff', m: 'Neon' }).tag('GateNode');
    // snow sitting on the upper beams
    if (ay > 0.1 && by > 0.1) F.beam([ax, ay + 1.7, 0], [bx, by + 1.7, 0], 3.4, 0.5, { name: 'PortalSnow', c: P.snow[0], studs: 'top', up: [0, 0, 1] });
  }
  const rm = Rr - 2.2, apo = rm * Math.sin(Math.PI / 3);
  for (let k = 0; k < 3; k++) F.box({ name: 'Membrane', s: [rm, 2 * apo, 0.3], r: [0, 0, k * 60], c: o.color || '#5ac8f0', m: 'Neon', t: 0.55, shadow: false }).tag('PortalSurface');
  for (let k = 0; k < 3; k++) F.box({ name: 'Core', s: [rm * 0.5, 2 * apo * 0.5, 0.35], r: [0, 0, k * 60], c: '#eef8ff', m: 'Neon', t: 0.55, shadow: false }).tag('PortalCore');
  const host = F.box({ name: 'PortalLightHost', s: [1, 1, 1], t: 1, shadow: false });
  E.pointLight(host, o.light || [0.6, 0.85, 1], 40, 1.1);
  E.particles(host, 'Swirl', { rate: 18, life: [0.8, 1.6], speed: [5, 12], spread: [80, 80], dir: 5, size: [[0, 0.5], [1, 0]], color: [[0, [0.9, 0.97, 1]], [1, o.swirl || [0.45, 0.75, 1]]], emission: 0.5 });
  for (const side of [-1, 1]) {
    c.box({ name: 'Plinth', s: [6, 3, 7], p: [side * (Rr + 1), 1.5, 0], c: '#6a7480', m: 'Slate', studs: 'top', collide: true });
    c.box({ name: 'PlinthSnow', s: [5.6, 0.5, 6.6], p: [side * (Rr + 1), 3.25, 0], c: P.snow[0], studs: 'top' });
  }
  return g;
}

function buildArrival(Z, at) {
  const f = at('PineRoad', 0);
  hexPortal(Z, [f.p[0], GROUND, f.p[2] + 6], yawOf(f), 14, 'ArrivalPortal', { color: '#7fd8ff' });
  // the ranger's camp: a blue expedition tent half buried in snow, a glowing heater, crates and a sled
  const c = Z.at([f.p[0] - 26, GROUND, f.p[2] - 20], [0, -20, 0]);
  c.box({ name: 'TentFloor', s: [10, 0.3, 8], p: [0, 0.15, 0], c: '#5a4636' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, -2], face: 'front', c: '#3f8fd8' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, 2], face: 'back', c: '#3478bc' });
  c.box({ name: 'TentSnow', s: [10.4, 0.5, 2.6], p: [0, 5.1, 0], c: P.snow[0], studs: 'top' });
  c.box({ name: 'TentDrift', s: [11, 1.1, 3], p: [0, 0.55, 4.6], c: P.snow[1], studs: 'top' });
  E.crate(c, [-6.5, 0.3, 1], 1, { yaw: -14, stencil: '#2f6b8a' });
  E.barrel(c, [-6.5, 0.3, -2.5], { color: '#2f6b8a' });
  c.box({ name: 'CrateSnow', s: [2.1, 0.4, 2.1], p: [-6.5, 2.5, 1], r: [0, -14, 0], c: P.snow[0], studs: 'top' });
  // the sled
  const s = c.at([5, 0, 5], [0, 30, 0]);
  for (const sd of [-1, 1]) s.box({ name: 'SledRunner', s: [0.3, 0.4, 6], p: [sd * 1.2, 0.2, 0], c: '#c8402e' });
  s.box({ name: 'SledDeck', s: [2.8, 0.3, 4.6], p: [0, 0.6, 0.3], c: P.woodHi, m: 'WoodPlanks' });
  E.crate(s, [0, 0.75, 0.6], 0.7, { yaw: 8, stencil: '#c8402e' });
  // a warm heater by the tent (the only warm light in the clearing)
  const hc = c.at([3.6, 0, -6]);
  hc.cyl({ name: 'Heater', axis: 'y', len: 1.6, d: 1.4, p: [0, 0.8, 0], c: '#3a3d42', m: 'Metal', collide: true });
  const glow = hc.box({ name: 'HeaterGlow', s: [0.9, 0.4, 0.9], p: [0, 1.7, 0], c: '#ff9a4a', m: 'Neon' });
  E.pointLight(glow, [1, 0.62, 0.32], 14, 0.9);
  E.particles(glow, 'Heat', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 2, life: [2, 3], speed: [1.5, 2.5], dir: 1, spread: [10, 10], size: [[0, 0.6], [1, 2]], transp: [[0, 0.75], [1, 1]], color: [0.9, 0.9, 0.95], emission: 0 });
  E.signBoard(c, [7, 4, -3], 7, 2, 'FROST FOREST', { r: [0, 30, 0], color: '#f2fbff', color2: '#5ab8ff', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [7, 2, -2.7], c: E.PAL.woodLo });
  c.box({ name: 'SignSnow', s: [7.6, 0.4, 0.8], p: [7, 5.2, -3], r: [0, 30, 0], c: P.snow[0] });
  E.lampPost(c, [4, 0.3, 4], { h: 6, color: '#cfeaff' });
}

function buildReturnPortal(Z, at) {
  const f = at('Homestretch', 1e9);
  hexPortal(Z, [f.p[0] - f.f[0] * 14, GROUND, f.p[2] - f.f[2] * 14] /* 14 back from the end: you drive through it before the warp (extract at L-8) */, yawOf(f), 15, 'ReturnPortal', { color: '#ffb02e', light: [1, 0.82, 0.5], swirl: [1, 0.7, 0.3] });
}

// ------------------------------------------------------------------ set pieces
function buildPineGate(Z, at, R) {
  // two ancient pines flank the road like gateposts, a snow-loaded bough across the top: the forest begins
  const f = at(PINE_GATE.seg, PINE_GATE.s);
  const yaw = yawOf(f);
  const g = Z.group('PineGate');
  const c = g.at([f.base[0], GROUND, f.base[2]], [0, yaw, 0]);
  const W = 13 + 2.5 + 6;
  for (const side of [-1, 1]) {
    const t = c.at([side * W, 0, 0], [0, side * 12, 0]);
    for (let i = 0; i < 7; i++) t.box({ name: 'GateTrunk', s: [4.2 - i * 0.24, 6.2, 4.2 - i * 0.24], p: [0, 3 + i * 6, 0], r: [0, i * 13, 0], c: P.bark[i % 3], m: 'WoodPlanks', studs: 'sides', collide: true });
    for (let k = 0; k < 4; k++) t.at([0, 0, 0], [0, k * 90 + 30, 0]).wedgeF({ name: 'GateRoot', s: [2, 3, 3.4], p: [0, 1.5, -3.4], face: 'front', c: P.bark[0], collide: true });
    for (let k = 0; k < 6; k++) {
      const y = 20 + k * 6.4, r = 11 - k * 1.5;
      t.box({ name: 'GateTier', s: [r * 2, 6.6, r * 2], p: [-side * 1.2, y, 0], r: [0, (k % 2) * 45, 0], c: P.pine[k % 4], studs: 'top' });
      t.box({ name: 'GateSnow', s: [r * 2 - 0.6, 0.6, r * 2 - 0.6], p: [-side * 1.2, y + 3.6, 0], r: [0, (k % 2) * 45, 0], c: P.snow[k % 4], studs: 'top' });
    }
    t.box({ name: 'GateTip', s: [2.4, 5, 2.4], p: [-side * 1.2, 20 + 6 * 6.4, 0], r: [0, 45, 0], c: P.pine[0], studs: 'top' });
    E.signBoard(t, [side * -0.4, 6, -2.4], 6, 1.6, 'PINE ROAD', { color: '#f2fbff', color2: '#5ab8ff', twoSided: true, pps: 30 });
  }
}

// THE FROZEN LAKE: a wide sheet of blue ice the ice road runs straight across. Ice plates in a dozen blues, white
// cracks branching across it, pressure ridges of heaved-up ice shards, dark breathing holes, a pine islet, the
// research team's ice-fishing hut, a snow shore all round.
function buildFrozenLake(Z, segs, at, R) {
  const g = Z.group('FrozenLake');
  const { x: cx, z: cz, rx, rz } = LAKE;
  const roadD = (x, z) => { let best = Infinity; for (const p of segs.FrozenLake.samples) best = Math.min(best, Math.hypot(x - p[0], z - p[2])); return best - segs.FrozenLake.width / 2; };
  // the sheet: strips of ice row by row (cheap), each row split in a few tones so the plates read
  const CELL = 12;
  for (let z = cz - rz; z < cz + rz; z += CELL) {
    const zc = z + CELL / 2;
    const half = rx * Math.sqrt(Math.max(0, 1 - ((zc - cz) / rz) ** 2)) + 3;
    if (half < 4) continue;
    let x = cx - half;
    while (x < cx + half) {
      const w = Math.min(cx + half - x, 18 + Math.floor(R() * 4) * 8);
      g.box({ name: 'IceSheet', s: [w, 0.4, CELL], p: [x + w / 2, ICE_TOP - 0.2, zc], c: P.ice[Math.floor(R() * 4)], m: 'Ice', collide: true });
      x += w;
    }
  }
  // deep blue windows in the ice (clear black ice where the snow blew off)
  for (let k = 0; k < 16; k++) {
    const a = R() * Math.PI * 2, r = Math.sqrt(R()) * 0.82;
    const x = cx + Math.cos(a) * rx * r, z = cz + Math.sin(a) * rz * r;
    if (roadD(x, z) < 2) continue;
    g.box({ name: 'IceDeep', s: [8 + R() * 14, 0.04, 6 + R() * 10], p: [x, ICE_TOP + 0.02, z], r: [0, R() * 180, 0], c: k % 3 ? P.iceDeep : P.iceDark, m: 'Glass', shadow: false });
  }
  // snow dusting blown into drifts on the ice
  for (let k = 0; k < 18; k++) {
    const a = R() * Math.PI * 2, r = 0.3 + R() * 0.6;
    const x = cx + Math.cos(a) * rx * r, z = cz + Math.sin(a) * rz * r;
    if (roadD(x, z) < 3) continue;
    g.box({ name: 'SnowDust', s: [6 + R() * 10, 0.06, 2.4 + R() * 3], p: [x, ICE_TOP + 0.03, z], r: [0, 30 + R() * 30, 0], c: P.snow[k % 4], shadow: false });
  }
  // the cracks: white zigzags branching out from a few strike points (some run right under the ice road)
  const crack = (x, z, a, len, depth) => {
    let px = x, pz = z;
    for (let i = 0; i < len; i++) {
      a += (R() - 0.5) * 0.9;
      const L = 4 + R() * 5;
      const nx = px + Math.cos(a) * L, nz = pz + Math.sin(a) * L;
      if (lakeE(nx, nz) > 0.97) return;
      g.beam([px, ICE_TOP + 0.05, pz], [nx, ICE_TOP + 0.05, nz], depth > 0 ? 0.4 : 0.26, 0.08, { name: 'IceCrack', c: P.crack, shadow: false, extend: 0.3 });
      if (depth > 0 && R() < 0.22) crack(nx, nz, a + (R() > 0.5 ? 1 : -1) * (0.7 + R() * 0.6), 3 + Math.floor(R() * 4), depth - 1);
      px = nx; pz = nz;
    }
  };
  const strikes = [[cx - 30, cz + 40], [cx + 20, cz - 30], [cx - 50, cz - 50], [cx + 40, cz + 50], [cx - 10, cz + 5]];
  for (const [x, z] of strikes) { const n = 4 + Math.floor(R() * 2); for (let k = 0; k < n; k++) crack(x, z, (k / n) * Math.PI * 2 + R() * 0.5, 6 + Math.floor(R() * 6), 2); }
  // pressure ridges: heaved, tilted ice shards (kept off the road)
  for (let k = 0; k < 9; k++) {
    const a = R() * Math.PI * 2, r = 0.35 + R() * 0.5;
    const x = cx + Math.cos(a) * rx * r, z = cz + Math.sin(a) * rz * r;
    if (roadD(x, z) < 12) continue;
    const c = g.at([x, ICE_TOP, z], [0, R() * 180, 0]);
    for (let j = 0; j < 5; j++) {
      const h = 1.4 + R() * 2.6;
      c.box({ name: 'IceShard', s: [2.4 + R() * 1.6, h, 0.9 + R() * 0.6], p: [-5 + j * 2.4, h * 0.35, (R() - 0.5) * 1.4], r: [(R() - 0.5) * 40, (R() - 0.5) * 30, (R() - 0.5) * 30], c: P.ice[(j + k) % 4], m: 'Glass', t: 0.1 });
    }
  }
  // breathing holes: open dark water ringed by broken plates and snow
  for (let k = 0; k < 4; k++) {
    const a = k * 1.7 + 0.6, r = 0.45 + (k % 2) * 0.25;
    const x = cx + Math.cos(a) * rx * r, z = cz + Math.sin(a) * rz * r;
    if (roadD(x, z) < 10) continue;
    const c = g.at([x, ICE_TOP, z]);
    c.cyl({ name: 'IceHole', axis: 'y', len: 0.06, d: 5 + R() * 2, p: [0, 0.03, 0], c: '#163a52', m: 'Glass', shadow: false });
    for (let j = 0; j < 7; j++) { const b = (j / 7) * Math.PI * 2; c.box({ name: 'IceFloe', s: [1.8 + R(), 0.4, 1.2 + R()], p: [Math.cos(b) * 3.8, 0.15, Math.sin(b) * 3.8], r: [(R() - 0.5) * 14, -E.deg(b), (R() - 0.5) * 14], c: P.ice[j % 4], m: 'Ice' }); }
  }
  // the research team's ice-fishing hut, abandoned (snowed in, door ajar, a red flag)
  {
    const x = cx + 32, z = cz + 52;
    const c = g.at([x, ICE_TOP, z], [0, 24, 0]);
    c.box({ name: 'Hut', s: [6, 4.4, 5], p: [0, 2.2, 0], c: '#c8402e', m: 'WoodPlanks', collide: true });
    c.wedgeF({ name: 'HutRoof', s: [6.8, 1.6, 2.9], p: [0, 5.2, -1.3], face: 'front', c: P.woodLo });
    c.wedgeF({ name: 'HutRoof', s: [6.8, 1.6, 2.9], p: [0, 5.2, 1.3], face: 'back', c: P.woodLo });
    c.box({ name: 'HutSnow', s: [7, 0.6, 2.2], p: [0, 6.1, 0], c: P.snow[0], studs: 'top' });
    c.box({ name: 'HutDoor', s: [1.8, 3, 0.2], p: [-1, 1.5, -2.6], r: [0, 30, 0], c: P.woodHi });
    c.box({ name: 'HutWindow', s: [1.4, 1, 0.1], p: [1.6, 2.8, -2.55], c: '#ffd27a', m: 'Neon' });
    c.box({ name: 'HutDrift', s: [7, 1.2, 2], p: [0, 0.6, 3.4], c: P.snow[1], studs: 'top' });
    E.flag(c, [4.2, 0, -2], '#ff7a1a', { h: 6 });
    c.cyl({ name: 'IceHole', axis: 'y', len: 0.06, d: 1.6, p: [-2, 0.03, -4.6], c: '#163a52', m: 'Glass', shadow: false });
  }
  // the islet: a rock knuckle with two dark pines, out on the ice
  {
    const x = cx + 50, z = cz - 26;
    const c = g.at([x, ICE_TOP, z]);
    for (let k = 0; k < 3; k++) c.box({ name: 'IsletRock', s: [14 - k * 3.6, 2.2, 11 - k * 2.8], p: [(R() - 0.5) * 2, 0.6 + k * 1.8, (R() - 0.5) * 2], r: [0, k * 25, 0], c: P.rock[k % 4], m: 'Slate', collide: true });
    c.box({ name: 'IsletSnow', s: [8, 0.6, 6], p: [0, 5, 0], r: [0, 50, 0], c: P.snow[0], studs: 'top', collide: true });
    snowPine(g, [x + 1, ICE_TOP + 5.2, z], 26, 9101);
    snowPine(g, [x - 3, ICE_TOP + 4.6, z + 3], 17, 9102);
  }
  // the shore: snow banks lapping over the ice edge, frozen reeds poking through
  const per = Math.PI * (3 * (rx + rz) - Math.sqrt((3 * rx + rz) * (rx + 3 * rz)));
  const n = Math.round(per / 9);
  for (let k = 0; k < n; k++) {
    const a = (k / n) * Math.PI * 2;
    const x = cx + Math.cos(a) * (rx + 1.5), z = cz + Math.sin(a) * (rz + 1.5);
    if (roadD(x, z) < 4) continue;
    const tang = Math.atan2(rx * Math.cos(a), -rz * Math.sin(a));
    g.at([x, GROUND, z], [0, E.deg(tang), 0]).box({ name: 'LakeShore', s: [5 + R() * 2, 0.5 + R() * 0.5, 11], p: [0, 0.15, 0], c: P.snow[k % 4], studs: 'top', shadow: false });
    if (R() < 0.35) {
      const rc = g.at([cx + Math.cos(a) * (rx - 3), ICE_TOP, cz + Math.sin(a) * (rz - 3)]);
      for (let j = 0; j < 4; j++) { const h = 1.4 + R() * 1.6; rc.box({ name: 'FrozenReed', s: [0.16, h, 0.16], p: [(R() - 0.5) * 3, h / 2, (R() - 0.5) * 3], r: [(R() - 0.5) * 16, 0, (R() - 0.5) * 16], c: j % 2 ? '#a08a5a' : '#8a7448', shadow: false }); }
    }
  }
  // the ice road's sign + gold ginkgos on the far shore so the crossing ends on a colour hit
  const f = at('FrozenLake', 20);
  const sc = g.at([f.p[0] - f.r[0] * 19, GROUND, f.p[2] - f.r[2] * 19], [0, yawOf(f) + 180, 0]);
  E.signBoard(sc, [0, 4.2, 0], 7, 2, 'FROZEN LAKE', { color: '#f2fbff', color2: '#5ab8ff', twoSided: true, pps: 30, trim: '#5ab8ff' });
  sc.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
  sc.box({ name: 'ThinIce', s: [3.4, 1.4, 0.2], p: [0, 1.8, -0.2], c: '#f2c230' });
}

// ASH RIDGE: the road climbs a black ash ridge thrown out by the volcano. Snow streaks on black, basalt columns, vents
// breathing steam and smoke, a few glowing cracks in the ash (dull, not neon-loud), charred snags.
function buildAshRidge(Z, segs, at, R, hAt) {
  const gyAt = (x, z) => Math.max(GROUND, hAt(x, z));
  const g = Z.group('AshRidgeSet');
  const sg = segs.AshRidge;
  const L = sg.cum[sg.cum.length - 1];
  // vents along both shoulders
  for (let s = 40; s < L - 30; s += 34) {
    const side = Math.floor(s / 34) % 2 ? 1 : -1;
    const f = at('AshRidge', s, side * (sg.width / 2 + 9 + R() * 6));
    const gy = gyAt(f.p[0], f.p[2]);
    const c = g.at([f.p[0], gy, f.p[2]], [0, R() * 360, 0]);
    for (let k = 0; k < 5; k++) { const a = (k / 5) * Math.PI * 2; c.box({ name: 'VentRim', s: [1.6, 0.9, 1.4], p: [Math.cos(a) * 1.6, 0.35, Math.sin(a) * 1.6], r: [0, -E.deg(a), 0], c: P.basalt[k % 4], m: 'Slate' }); }
    c.box({ name: 'VentCrust', s: [2.4, 0.12, 2.4], p: [0, 0.06, 0], c: '#c8a640', shadow: false }); // sulphur
    const host = c.box({ name: 'Fumarole', s: [1, 1, 1], p: [0, 0.8, 0], t: 1, shadow: false });
    host.set('CanQuery', 'bool', false);
    E.particles(host, 'Steam', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 4, life: [3, 5], speed: [3, 6], dir: 1, spread: [8, 8], size: [[0, 1.5], [1, 9]], transp: [[0, 0.5], [1, 1]], color: [0.82, 0.82, 0.86], emission: 0, accel: [1.2, 0.6, 0] });
  }
  // dull ember cracks in the ash (low, small, the volcano's warmth)
  for (let k = 0; k < 7; k++) {
    const s = 60 + k * 26;
    const f = at('AshRidge', s, (k % 2 ? 1 : -1) * (sg.width / 2 + 4 + R() * 5));
    const gy = gyAt(f.p[0], f.p[2]);
    const c = g.at([f.p[0], gy, f.p[2]], [0, R() * 180, 0]);
    let x = 0, z = 0, a = R() * 6;
    for (let j = 0; j < 3; j++) { const l = 2 + R() * 2.4; const nx = x + Math.cos(a) * l, nz = z + Math.sin(a) * l; c.beam([x, 0.04, z], [nx, 0.04, nz], 0.22, 0.06, { name: 'EmberCrack', c: '#e0552a', m: 'Neon', shadow: false }); x = nx; z = nz; a += (R() - 0.5) * 1.4; }
  }
  // basalt clumps standing guard at the top
  for (let k = 0; k < 6; k++) {
    const s = 90 + k * 22;
    const f = at('AshRidge', s, (k % 2 ? 1 : -1) * (sg.width / 2 + 14 + R() * 10));
    basalt(g, [f.p[0], gyAt(f.p[0], f.p[2]), f.p[2]], 7 + R() * 7, 9300 + k, { name: 'RidgeBasalt' });
  }
  const f = at('AshRidge', 26);
  const c = g.at([f.p[0] + f.r[0] * 17, GROUND, f.p[2] + f.r[2] * 17], [0, yawOf(f) + 180, 0]);
  E.signBoard(c, [0, 4.2, 0], 6.4, 1.8, 'ASH RIDGE', { color: '#f2fbff', color2: '#ff8a4a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
}

// THE ELDER GINKGO: a golden giant at the mouth of the hollow, seen from the lake, the ridge and the den
function buildElderGinkgo(Z, R) {
  const g = Z.group('ElderGinkgo');
  const t = g.at(ELDER, [0, 15, 0]);
  const W = 7, H = 64;
  for (let i = 0; i * 6 < H * 0.6; i++) {
    const w = W * (1 - (i * 6) / H * 0.5);
    t.box({ name: 'ElderTrunk', s: [w, 6.2, w], p: [0, 3 + i * 6, 0], r: [0, i * 11, 0], c: P.ginkgoBark[i % 3], m: 'WoodPlanks', studs: 'sides', collide: true });
  }
  for (let k = 0; k < 5; k++) t.at([0, 0, 0], [0, k * 72 + 10, 0]).wedgeF({ name: 'ElderRoot', s: [2.6, 7, 6], p: [0, 3.5, -W / 2 - 2.8], face: 'front', c: P.ginkgoBark[k % 3], m: 'WoodPlanks', collide: true });
  // big swept branches, each ending in a golden cloud; the crown on top
  const clouds = [[0, H * 0.86, 0, 22]];
  for (let k = 0; k < 7; k++) {
    const a = (k / 7) * Math.PI * 2 + R() * 0.3;
    const y0 = H * (0.32 + (k % 3) * 0.08);
    const L = 14 + R() * 6;
    const end = [Math.cos(a) * L, y0 + L * 0.8, Math.sin(a) * L];
    t.beam([0, y0, 0], end, 1.8, 1.8, { name: 'ElderBranch', c: P.ginkgoBark[1], extend: 1 });
    clouds.push([end[0], end[1] + 2, end[2], 12 + R() * 4]);
  }
  clouds.forEach(([x, y, z, s], k) => {
    t.box({ name: 'ElderLeaves', s: [s * 1.4, s * 0.62, s * 1.25], p: [x, y, z], r: [0, R() * 90, 0], c: P.gold[k % 4], studs: 'top' });
    t.box({ name: 'ElderLeaves', s: [s, s * 0.55, s * 1.05], p: [x + (R() - 0.5) * s * 0.4, y + s * 0.4, z + (R() - 0.5) * s * 0.4], r: [0, R() * 90, 0], c: P.gold[(k + 1) % 4], studs: 'top' });
    t.box({ name: 'ElderLeaves', s: [s * 0.8, s * 0.5, s * 0.7], p: [x + (R() - 0.5) * s * 0.6, y - s * 0.3, z + (R() - 0.5) * s * 0.6], r: [0, R() * 90, 0], c: P.gold[(k + 2) % 4], studs: 'top' });
    t.box({ name: 'ElderSnow', s: [s * 0.8, 0.5, s * 0.7], p: [x, y + s * 0.4 + s * 0.28 + 0.2, z], r: [0, R() * 90, 0], c: P.snow[0], studs: 'top' });
  });
  // the gold carpet round its feet
  for (let k = 0; k < 16; k++) {
    const a = R() * Math.PI * 2, r = 8 + R() * 20;
    t.box({ name: 'GoldLitter', s: [5 + R() * 6, 0.08, 4 + R() * 4], p: [Math.cos(a) * r, 0.04 + (k % 4) * 0.012, Math.sin(a) * r], r: [0, R() * 180, 0], c: P.goldLeaf[k % 4], shadow: false });
  }
}

// HOT SPRINGS: steaming travertine terraces (cream stone, orange mineral rims, turquoise pools), the snow melted back to
// green moss around them. One big stepped mound with a pool on every step, smaller pools beside the road.
function buildHotSprings(Z, at, R) {
  const g = Z.group('HotSprings');
  const c = g.at([SPRINGS.x, GROUND, SPRINGS.z]);
  // melted ground: a moss ring with ferns and the odd flower that only grows here
  for (let k = 0; k < 14; k++) {
    const a = (k / 14) * Math.PI * 2 + R() * 0.3, r = SPRINGS.r - 4 + R() * 8;
    c.cyl({ name: 'MossPatch', axis: 'y', len: 0.1, d: 8 + R() * 6, p: [Math.cos(a) * r, 0.05 + (k % 3) * 0.01, Math.sin(a) * r], c: P.moss[k % 3], shadow: false });
  }
  c.cyl({ name: 'MossRing', axis: 'y', len: 0.08, d: SPRINGS.r * 2 - 4, p: [0, 0.04, 0], c: '#6a9a50', shadow: false });
  const tiers = [[52, 2.2], [38, 2.2], [24, 2.2]];
  let y = 0;
  tiers.forEach(([d, h], k) => {
    c.cyl({ name: 'SpringTerrace', axis: 'y', len: h, d, p: [0, y + h / 2, 0], c: P.trav[k % 3], m: 'Sand', collide: true });
    // orange mineral lip with pools along the terrace edge (skip on the top: the top is one big pool)
    const n = k < 2 ? 7 : 0;
    for (let j = 0; j < n; j++) {
      const a = (j / n) * Math.PI * 2 + k * 0.4;
      const r = d / 2 - 3.6;
      const pc = c.at([Math.cos(a) * r, y + h, Math.sin(a) * r], [0, -E.deg(a), 0]);
      pc.cyl({ name: 'SpringWater', axis: 'y', len: 0.2, d: 6.4, p: [0, -0.02, 0], c: j % 2 ? P.spring : P.springDeep, m: 'Glass', t: 0.15, shadow: false }).tag('DinoWater');
      pc.box({ name: 'SpringRim', s: [2.2, 0.6, 7.4], p: [3.4, 0.1, 0], c: P.travRim[j % 3], m: 'Sand' });
      if (j % 2 === 0) {
        const st = pc.box({ name: 'SteamHost', s: [3, 1, 3], p: [0, 0.6, 0], t: 1, shadow: false });
        st.set('CanQuery', 'bool', false);
        E.particles(st, 'Steam', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 2.4, life: [3, 5], speed: [2, 4], dir: 1, spread: [10, 10], size: [[0, 2], [1, 8]], transp: [[0, 0.62], [1, 1]], color: [0.94, 0.96, 1], emission: 0, accel: [0.8, 0.4, 0] });
      }
    }
    // a band of orange stain down every step face
    c.cyl({ name: 'SpringStain', axis: 'y', len: 0.4, d: d + 0.1, p: [0, y + h - 0.3, 0], c: P.travRim[k % 3], m: 'Sand' });
    y += h;
  });
  // the crown pool on top, steaming hardest
  c.cyl({ name: 'SpringWater', axis: 'y', len: 0.2, d: 18, p: [0, y - 0.02, 0], c: P.spring, m: 'Glass', t: 0.12, shadow: false }).tag('DinoWater');
  c.cyl({ name: 'SpringDeep', axis: 'y', len: 0.22, d: 7, p: [0, y - 0.01, 0], c: P.springDeep, m: 'Glass', t: 0.1, shadow: false });
  const top = c.box({ name: 'SteamHost', s: [14, 1, 14], p: [0, y + 0.8, 0], t: 1, shadow: false });
  top.set('CanQuery', 'bool', false);
  E.particles(top, 'Steam', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 6, life: [4, 7], speed: [3, 5], dir: 1, spread: [12, 12], size: [[0, 4], [1, 16]], transp: [[0, 0.55], [1, 1]], color: [0.95, 0.97, 1], emission: 0, accel: [1, 0.3, 0] });
  E.particles(top, 'Bubbles', { rate: 6, life: [0.6, 1], speed: [1, 2], dir: 1, spread: [40, 40], size: [[0, 0.35], [1, 0]], color: [0.85, 1, 1], emission: 0.2 });
  // runoff channels down the snow toward the road, orange and turquoise
  for (let k = 0; k < 4; k++) {
    const a = k * 1.6 + 0.4;
    let x = Math.cos(a) * 26, z = Math.sin(a) * 26;
    for (let j = 0; j < 4; j++) {
      const nx = x + Math.cos(a + (R() - 0.5) * 0.6) * 5, nz = z + Math.sin(a + (R() - 0.5) * 0.6) * 5;
      c.beam([x, 0.1, z], [nx, 0.1, nz], 1.2, 0.08, { name: 'Runoff', c: j % 2 ? P.travRim[0] : P.spring, shadow: false, extend: 0.4 });
      x = nx; z = nz;
    }
  }
  // ferns and a few pink flowers in the warmth
  for (let k = 0; k < 10; k++) {
    const a = (k / 10) * Math.PI * 2 + 0.3, r = 28 + R() * 6;
    if (k % 3 === 2) E.flowers(c, [Math.cos(a) * r, 0, Math.sin(a) * r], 9500 + k, { n: 4, spread: 2.4, colors: ['#ff7ab0', '#ffffff', '#ffd23a'] });
    else E.fern(c, [Math.cos(a) * r, 0, Math.sin(a) * r], 1.4 + R() * 0.6, 9500 + k);
  }
  // a thermometer post the research team left (red bulb, snow on top)
  const tp = c.at([-SPRINGS.r + 6, 0, -6]);
  tp.box({ name: 'GaugePost', s: [0.5, 5, 0.5], p: [0, 2.5, 0], c: '#f4f4f4' });
  tp.box({ name: 'GaugeFace', s: [1.2, 3, 0.3], p: [0, 3.2, -0.4], c: '#ffffff' });
  tp.box({ name: 'GaugeRed', s: [0.3, 2.2, 0.32], p: [0, 2.9, -0.42], c: '#e8402e' });
  // the sign by the road
  const f = at('HotSprings', 22);
  const sc = Z.at([f.p[0] - f.r[0] * 18, GROUND, f.p[2] - f.r[2] * 18], [0, yawOf(f) + 180, 0]);
  E.signBoard(sc, [0, 4.2, 0], 7, 2, 'HOT SPRINGS', { color: '#f2fbff', color2: '#3cd0d8', twoSided: true, pps: 30 });
  sc.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
  // little roadside pools on the far shoulder, steaming into the road
  for (const s of [80, 150, 205]) {
    const fr = at('HotSprings', s, -(12 + 10));
    const pc = g.at([fr.p[0], GROUND, fr.p[2]], [0, R() * 180, 0]);
    pc.cyl({ name: 'SpringTerrace', axis: 'y', len: 0.8, d: 11, p: [0, 0.4, 0], c: P.trav[s % 3], m: 'Sand', collide: true });
    pc.cyl({ name: 'SpringWater', axis: 'y', len: 0.2, d: 7.6, p: [0, 0.78, 0], c: P.spring, m: 'Glass', t: 0.15, shadow: false }).tag('DinoWater');
    pc.cyl({ name: 'SpringStain', axis: 'y', len: 0.3, d: 11.2, p: [0, 0.62, 0], c: P.travRim[s % 3], m: 'Sand' });
    const st = pc.box({ name: 'SteamHost', s: [5, 1, 5], p: [0, 1.4, 0], t: 1, shadow: false });
    st.set('CanQuery', 'bool', false);
    E.particles(st, 'Steam', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 2.5, life: [3, 5], speed: [2, 4], dir: 1, spread: [10, 10], size: [[0, 2], [1, 9]], transp: [[0, 0.6], [1, 1]], color: [0.95, 0.97, 1], emission: 0, accel: [0.8, 0.4, 0] });
    for (let k = 0; k < 6; k++) { const a = (k / 6) * Math.PI * 2; pc.box({ name: 'MossPatch', s: [5, 0.08, 3], p: [Math.cos(a) * 8, 0.04, Math.sin(a) * 8], r: [0, -E.deg(a), 0], c: P.moss[k % 3], shadow: false }); }
  }
}

// a big fallen conifer trunk from a to b (local points, y = the trunk centre), snow along its back, a broken end
function giantLog(ctx, a, b, d, seed, o = {}) {
  const R = rng(seed);
  // an octagonal trunk: two square beams turned 45° about the log's axis (blocky, faceted, never a pipe)
  {
    const hx = b[0] - a[0], hz = b[2] - a[2], hl = Math.hypot(hx, hz) || 1;
    const px = -hz / hl, pz = hx / hl;
    const bc = Math.floor(R() * 3);
    ctx.beam(a, b, d * 0.9, d * 0.9, { name: 'GiantLog', c: P.bark[bc], m: 'WoodPlanks', collide: true, extend: 0.2 });
    ctx.beam(a, b, d * 0.74, d * 0.74, { name: 'GiantLog', c: shade(P.bark[bc], 1.15), m: 'WoodPlanks', collide: true, up: [px, 1, pz], extend: 0.1 });
  }
  ctx.beam([a[0], a[1] + d * 0.45 + 0.5, a[2]], [b[0], b[1] + d * 0.45 + 0.5, b[2]], d * 0.72, 1.4, { name: 'LogSnow', c: P.snow[Math.floor(R() * 4)], studs: 'top' });
  // snapped branch stubs along the sides, moss and snow clumps
  {
    const L0 = Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]);
    const n = Math.floor(L0 / 9);
    for (let k = 1; k < n; k++) {
      const u = k / n, sd = k % 2 ? 1 : -1;
      const px = a[0] + (b[0] - a[0]) * u, py = a[1] + (b[1] - a[1]) * u, pz = a[2] + (b[2] - a[2]) * u;
      const yaw = E.deg(Math.atan2(-(b[0] - a[0]), -(b[2] - a[2])));
      ctx.at([px, py, pz], [0, yaw, 0]).box({ name: 'BranchStub', s: [0.9, 0.9, 2.6 + R() * 1.6], p: [sd * (d / 2 + 0.6), d * 0.15, 0], r: [0, sd * 60, 25 * sd], c: P.bark[1] });
      if (R() < 0.5) ctx.at([px, py, pz], [0, yaw, 0]).box({ name: 'LogMoss', s: [d * 0.5, 0.4, 2.4], p: [-sd * d * 0.28, d * 0.38, 0], r: [0, 0, -sd * 40], c: P.moss[k % 3] });
    }
  }
  const L = Math.hypot(b[0] - a[0], b[2] - a[2]);
  const dir = [(b[0] - a[0]) / L, (b[1] - a[1]) / L, (b[2] - a[2]) / L];
  // pale broken end at b
  ctx.tube([b[0] - dir[0] * 0.3, b[1] - dir[1] * 0.3, b[2] - dir[2] * 0.3], [b[0] + dir[0] * 0.2, b[1] + dir[1] * 0.2, b[2] + dir[2] * 0.2], d * 0.86, { name: 'LogEnd', c: '#d8b88a' });
  // bark ridges: a few dark rings
  for (let k = 1; k < 4; k++) { const u = k / 4; const q = [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u]; ctx.beam(q, [q[0] + dir[0] * 1.2, q[1] + dir[1] * 1.2, q[2] + dir[2] * 1.2], d * 0.98, d * 0.98, { name: 'BarkRing', c: shade(P.bark[0], 0.8), m: 'WoodPlanks' }); }
  // the root plate torn up at a: a big disc of roots and frozen earth standing on edge
  if (o.roots !== false) {
    const yaw = E.deg(Math.atan2(-(b[0] - a[0]), -(b[2] - a[2])));
    const rc = ctx.at([a[0], a[1], a[2]], [0, yaw, 0]);
    rc.cyl({ name: 'RootPlate', axis: 'z', len: 2, d: d * 2.4, p: [0, d * 0.5, 1], c: P.dirt, m: 'Slate', collide: true });
    for (let k = 0; k < 7; k++) { const an = (k / 7) * Math.PI * 2; rc.box({ name: 'RootStub', s: [0.9, 0.9, 3 + R() * 2], p: [Math.cos(an) * d * 1.1, d * 0.5 + Math.sin(an) * d * 1.1, 2.4], r: [Math.sin(an) * 20, Math.cos(an) * 20, 0], c: P.bark[1] }); }
    rc.box({ name: 'RootSnow', s: [d * 1.6, 0.6, 2.2], p: [0, d * 0.5 + d * 1.18, 1], c: P.snow[0], studs: 'top' });
  }
}

// FALLEN GIANTS: an old forest blown down long ago: huge trunks lying along the road, root plates on end, broken
// stumps, and one giant that came to rest high across the road on two stumps (you drive under it)
function buildFallenGiants(Z, segs, at, R) {
  const g = Z.group('FallenGiants');
  const sg = segs.FallenGiants;
  const L = sg.cum[sg.cum.length - 1];
  const hw = sg.width / 2;
  // the log bridge
  {
    const f = at(LOG_ARCH.seg, LOG_ARCH.s);
    const c = g.at([f.base[0], GROUND, f.base[2]], [0, yawOf(f) + 8, 0]);
    const d = 8, y = ROAD + 11.6 + d / 2 + 1.2;
    const sx = hw + 2.5 + 7;
    for (const side of [-1, 1]) {
      // a broken giant stump on either side carries it
      for (let i = 0; i < 4; i++) c.box({ name: 'GiantStump', s: [10 - i * 0.4, y / 4 + 0.1, 10 - i * 0.4], p: [side * sx, (i + 0.5) * (y / 4), 0], r: [0, i * 17, 0], c: P.bark[i % 3], m: 'WoodPlanks', studs: 'sides', collide: true });
      c.box({ name: 'StumpTop', s: [9.4, 0.6, 9.4], p: [side * sx, y - d / 2 + 0.2, 0], c: '#d8b88a', m: 'WoodPlanks' });
      for (const th of [0, 180, side > 0 ? 270 : 90]) c.at([side * sx, 0, 0], [0, th + 12, 0]).wedgeF({ name: 'StumpRoot', s: [3, 4.4, 5], p: [0, 2.2, -7.2], face: 'front', c: P.bark[th % 3], collide: true });
    }
    giantLog(c, [-sx - 22, y, 0], [sx + 16, y, 0], d, 9401, { roots: false });
    E.signBoard(c, [sx - 2, 6, -5.4], 7, 2, 'FALLEN GIANTS', { color: '#f2fbff', color2: '#e8a03a', twoSided: true, pps: 30 });
  }
  // trunks lying beside the road, roughly along it
  for (let s = 100; s < L - 80; s += 46) {
    const side = Math.floor(s / 46) % 2 ? 1 : -1;
    const d = 6 + R() * 3;
    const f0 = at('FallenGiants', s, side * (hw + 13 + d / 2)), f1 = at('FallenGiants', s + 40, side * (hw + 14 + d / 2 + R() * 6));
    giantLog(g, [f0.p[0], GROUND + d * 0.42, f0.p[2]], [f1.p[0], GROUND + d * 0.42, f1.p[2]], d, 9410 + s, { roots: R() > 0.4 });
  }
  // broken stumps, shattered tops
  for (let k = 0; k < 6; k++) {
    const f = at('FallenGiants', 30 + k * 40, (k % 2 ? -1 : 1) * (hw + 18 + R() * 10));
    const c = g.at([f.p[0], GROUND, f.p[2]], [0, R() * 90, 0]);
    const h = 4 + R() * 6, w = 4.5 + R() * 2;
    c.box({ name: 'BrokenStump', s: [w, h, w], p: [0, h / 2, 0], c: P.bark[k % 3], m: 'WoodPlanks', studs: 'sides', collide: true });
    for (let j = 0; j < 3; j++) c.wedgeF({ name: 'Splinter', s: [w * 0.4, 2 + R() * 2.5, 1], p: [(j - 1) * w * 0.3, h + 1, (R() - 0.5) * w * 0.4], face: j % 2 ? 'front' : 'back', c: '#d8b88a' });
    c.box({ name: 'StumpSnow', s: [w * 0.9, 0.5, w * 0.9], p: [0, h + 0.25, 0], c: P.snow[k % 4], studs: 'top' });
  }
}

// THE WHITE LAKE — the Yutyrannus' den. A round frozen lake in a ring of snow banks and black pines, its ice crazed
// with white cracks spreading from where it stamps. A black basalt dais (Throne) under a frozen waterfall at the back,
// rock ledges round the bank, three-toed tracks across the ice, feathers in the snow, a sauropod frozen into the ice.
function buildWhiteLake(Z, at, R, route) {
  const g = Z.group('WhiteLake');
  const f = at(DEN.seg, DEN.s, DEN.x);
  const road = at(DEN.seg, DEN.s, 0);
  const toRoad = Math.atan2(-(road.p[0] - f.p[0]), -(road.p[2] - f.p[2]));
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, E.deg(toRoad), 0]); // local -Z points at the road
  const RAD = 38;
  // the ice
  c.cyl({ name: 'LakeIce', axis: 'y', len: 0.4, d: RAD * 2, p: [0, 0.06 - 0.2 + 0.06, 0], c: '#a2d8ef', m: 'Ice', collide: true });
  for (let k = 0; k < 7; k++) {
    const a = R() * Math.PI * 2, r = 8 + R() * 22;
    c.cyl({ name: 'IceDeep', axis: 'y', len: 0.04, d: 8 + R() * 8, p: [Math.cos(a) * r, 0.14, Math.sin(a) * r], c: k % 2 ? P.iceDeep : '#6fb4dc', m: 'Glass', shadow: false });
  }
  // the crack web: rays out from the stamping ground in front of the dais, rings crossing them
  const hub = [0, 6];
  for (let k = 0; k < 11; k++) {
    let a = (k / 11) * Math.PI * 2 + R() * 0.3, px = hub[0], pz = hub[1];
    for (let j = 0; j < 6; j++) {
      a += (R() - 0.5) * 0.5;
      const l = 4 + R() * 3;
      const nx = px + Math.cos(a) * l, nz = pz + Math.sin(a) * l;
      if (Math.hypot(nx, nz) > RAD - 2) break;
      c.beam([px, 0.2, pz], [nx, 0.2, nz], j < 2 ? 0.5 : 0.32, 0.08, { name: 'IceCrack', c: P.crack, shadow: false, extend: 0.3 });
      px = nx; pz = nz;
    }
  }
  for (const rr of [9, 17]) {
    for (let k = 0; k < 14; k++) {
      if (R() < 0.35) continue;
      const a0 = (k / 14) * Math.PI * 2, a1 = ((k + 1) / 14) * Math.PI * 2;
      c.beam([hub[0] + Math.cos(a0) * rr, 0.2, hub[1] + Math.sin(a0) * rr], [hub[0] + Math.cos(a1) * (rr + (R() - 0.5) * 2), 0.2, hub[1] + Math.sin(a1) * (rr + (R() - 0.5) * 2)], 0.26, 0.08, { name: 'IceCrack', c: P.crack, shadow: false });
    }
  }
  // the bank: a ring of snowy rock with its mouth open to the road
  const ring = [];
  for (let a = 44; a <= 316; a += 17) { const rad = (a * Math.PI) / 180; ring.push(c.wpt([Math.sin(rad) * (RAD + 4), 0, -Math.cos(rad) * (RAD + 4)])); }
  E.cliffWall(Z, ring.map((p) => [p[0] - FF_ORIGIN[0], p[2] - FF_ORIGIN[2]]), { top: P.snow[0], overhang: [P.snow[0], P.snow[1]], vines: false, moss: false, h: 22, d: 14, seed: 1261, slope: 3, colors: [P.snowSide, P.cliff[0], P.snowBlue, P.cliff[3]], chunk: 9, name: 'LakeBank' });
  // ledges round the bank: snow-capped rock stacks with icicles
  const ledgeAt = [[-26, 18, 9], [26, 18, 10], [-32, -6, 7], [32, -4, 8], [-17, 30, 12], [17, 30, 11]];
  ledgeAt.forEach(([x, z, h], i) => {
    const lc = c.at([x, 0, z]);
    for (let t = 0; t < 3; t++) lc.box({ name: 'LedgeRock', s: [7.4 - t * 0.7, h / 3 + 0.2, 7.4 - t * 0.7], p: [0, (t + 0.5) * (h / 3), 0], r: [0, t * 17 + R() * 10, 0], c: P.rock[(t + i) % 4], m: 'Slate', studs: 'top', collide: true });
    lc.box({ name: 'LedgeTop', s: [6, 0.6, 6], p: [0, h + 0.3, 0], c: P.snow[i % 4], studs: 'top', collide: true });
    for (let j = 0; j < 3; j++) lc.box({ name: 'Icicle', s: [0.4, 1.2 + R(), 0.4], p: [-1.5 + j * 1.5, h - 0.8, -3.2], c: P.icicle, m: 'Glass', t: 0.12, shadow: false });
    marker(lc, 'DenLedge' + (i + 1), [0, h + 0.6, 0], 0, { s: [2, 0.4, 2] });
  });
  // the dais: a black basalt slab, snow on it, under a frozen waterfall pouring off the bank
  const th = c.at([0, 0, 26]);
  th.box({ name: 'Throne', s: [16, 4, 12], p: [0, 2, 0], c: P.basalt[1], m: 'Slate', studs: 'top', collide: true });
  th.box({ name: 'ThroneStep', s: [20, 1.6, 15], p: [0, 0.8, 0.6], c: P.basalt[0], m: 'Slate', studs: 'top', collide: true });
  th.box({ name: 'ThroneSnow', s: [7, 0.3, 5], p: [-3.6, 4.15, 3], r: [0, 12, 0], c: P.snow[0], studs: 'top' });
  for (let k = 0; k < 6; k++) th.box({ name: 'Icicle', s: [0.5, 1.4 + R(), 0.5], p: [-6.5 + k * 2.6, 2.8, -6.1], c: P.icicle, m: 'Glass', t: 0.12, shadow: false });
  for (const sd of [-1, 1]) basalt(g, c.wpt([sd * 15.5, 0, 30]).map((v, k) => v - FF_ORIGIN[k]), 9 + R() * 3, 9601 + sd, { name: 'DaisColumns', n: 4 });
  // the frozen falls: columns of blue ice down the bank behind the dais
  const fc = c.at([0, 0, RAD + 1]);
  for (let k = 0; k < 9; k++) {
    const x = -11 + k * 2.75, h = 16 + R() * 6;
    fc.box({ name: 'FrozenFall', s: [2.6, h, 2.2], p: [x, h / 2, (R() - 0.5) * 1.2], c: P.ice[k % 4], m: 'Glass', t: 0.08 });
    fc.box({ name: 'FallIcicle', s: [1.4, 3 + R() * 2, 1.2], p: [x, 1.2, -1.4], c: P.icicle, m: 'Glass', t: 0.1, shadow: false });
  }
  fc.box({ name: 'FallLip', s: [27, 1.6, 4], p: [0, 21, 0.6], c: P.snow[0], studs: 'top' });
  // a sauropod frozen into the ice: ribs and a neck breaking the surface
  const sk = c.at([-14, 0.1, -8], [0, 40, 0]);
  for (let i = 0; i < 5; i++) for (const sd of [-1, 1]) sk.box({ name: 'IceRib', s: [0.7, 3.6 - Math.abs(i - 2) * 0.5, 0.7], p: [sd * 1.4, 1.2, (i - 2) * 1.8], r: [0, 0, sd * -24], c: '#efe6d0' });
  for (let i = 0; i < 6; i++) sk.box({ name: 'IceNeckBone', s: [0.9, 0.7, 1.4], p: [0, 0.3, -5 - i * 1.5], r: [0, i * 6, 0], c: i % 2 ? '#efe6d0' : '#e2d6bc' });
  sk.box({ name: 'IceSkull', s: [1.6, 1.2, 2.4], p: [0.8, 0.6, -14.4], r: [0, 20, 10], c: '#efe6d0' });
  // feathers in the snow (it's a feathered tyrant) and its tracks across the ice from the mouth to the dais
  for (let k = 0; k < 8; k++) { const a = R() * Math.PI * 2, r = RAD - 2 + R() * 3; c.box({ name: 'Feather', s: [0.5, 0.1, 2.2], p: [Math.cos(a) * r, 0.25 + R() * 0.3, Math.sin(a) * r], r: [0, R() * 180, (R() - 0.5) * 30], c: k % 2 ? '#f6f2ea' : '#9aaac0', shadow: false }); }
  for (let k = 0; k < 9; k++) {
    const pc = c.at([(k % 2 ? 2.8 : -2.8), 0.22, -36 + k * 6.4], [0, (k % 2 ? 8 : -8), 0]);
    pc.box({ name: 'TrackHeel', s: [2.4, 0.06, 2.2], p: [0, 0, 0.8], c: '#e8f4fb', shadow: false });
    for (const a of [-26, 0, 26]) pc.at([0, 0, -0.2], [0, a, 0]).box({ name: 'TrackToe', s: [0.9, 0.06, 3.2], p: [0, 0, -1.6], c: '#e8f4fb', shadow: false });
  }
  // cold light pooled on the dais, snow always drifting over the ice
  const glow = th.box({ name: 'DaisGlow', s: [1, 1, 1], p: [0, 13, -4], t: 1, shadow: false });
  E.pointLight(glow, [0.62, 0.82, 1], 34, 1.1);
  const drift = c.box({ name: 'LakeSnowfall', s: [70, 1, 70], p: [0, 28, 0], t: 1, shadow: false });
  drift.set('CanQuery', 'bool', false);
  E.particles(drift, 'Snow', { rate: 18, life: [7, 10], speed: [3, 5], dir: 4, spread: [20, 20], size: [[0, 0.3], [1, 0.25]], transp: [[0, 0.1], [0.8, 0.2], [1, 1]], color: [1, 1, 1], emission: 0, accel: [1.2, 0, 0.4] });
  // the ring of pines behind the bank
  for (let k = 0; k < 16; k++) {
    const a = (k / 16) * Math.PI * 2;
    if (Math.cos(a) > 0.72) continue; // the mouth stays open
    const r = RAD + 34 + R() * 6;
    const p = c.wpt([Math.sin(a) * r, 0, -Math.cos(a) * r]);
    snowPine(g, [p[0] - FF_ORIGIN[0], GROUND, p[2] - FF_ORIGIN[2]], 38 + R() * 16, 9700 + k, { spread: 0.2 });
  }
  // the sign at the mouth, between two ice-capped posts
  const mouth = at(DEN.seg, DEN.s, 22);
  const sc = Z.at([mouth.p[0], GROUND, mouth.p[2]], [0, E.deg(toRoad) + 180, 0]);
  E.signBoard(sc, [-8, 4.6, 0], 9, 2.2, 'WHITE LAKE', { color: '#f2fbff', color2: '#5ab8ff', twoSided: true, pps: 30, trim: '#5ab8ff' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [-8, 2.2, 0.3], c: E.PAL.woodLo });
  for (const sd of [-1, 1]) {
    sc.box({ name: 'GatePost', s: [1.6, 8, 1.6], p: [-8 + sd * 6.6, 4, 0], c: P.basalt[1], m: 'Slate', collide: true });
    sc.box({ name: 'GatePostSnow', s: [2, 0.8, 2], p: [-8 + sd * 6.6, 8.4, 0], c: P.snow[0], studs: 'top' });
  }
  // markers for the fight + the chase that follows
  const v0 = route.variants[0];
  const segS = (segId, s) => { const k = v0.segs.indexOf(segId); return k < 0 ? 0 : v0.segStart[k] + s; };
  const dc = marker(c, 'DenCenter', [0, 0.5, -8], 0, { s: [2, 1, 2] });
  dc.attr('RouteS', +segS(DEN.seg, DEN.s).toFixed(1)).attr('RouteX', DEN.x).attr('Variant', 1);
  const ff = at(FINAL.seg, FINAL.s, FINAL.x);
  const fm = marker(Z, 'FinalArena', [ff.p[0], GROUND + 0.5, ff.p[2]], 0, { s: [2, 1, 2] });
  fm.attr('RouteS', +segS(FINAL.seg, FINAL.s).toFixed(1)).attr('RouteX', -9).attr('Variant', 1);
}

// THE FROST STONES — the final stand: a ring of tall black basalt columns, snow-capped and hung with icicles
function buildFrostStones(Z, at, R) {
  const g = Z.group('FrostStones');
  const fin = at(FINAL.seg, FINAL.s, FINAL.x);
  const road = at(FINAL.seg, FINAL.s, 0);
  const toRoad = Math.atan2(road.p[0] - fin.p[0], road.p[2] - fin.p[2]);
  const c = g.at([fin.p[0], GROUND, fin.p[2]]);
  c.cyl({ name: 'Clearing', axis: 'y', len: 0.1, d: 58, p: [0, 0.05, 0], c: P.snowShade, shadow: false });
  // a frozen pool in the middle of the ring, cracked like the White Lake (it fights on ice again)
  c.cyl({ name: 'LakeIce', axis: 'y', len: 0.3, d: 30, p: [0, 0.15, 0], c: '#a2d8ef', m: 'Ice', collide: true });
  for (let k = 0; k < 8; k++) {
    let a = (k / 8) * Math.PI * 2 + R() * 0.3, px = 0, pz = 0;
    for (let j = 0; j < 3; j++) { a += (R() - 0.5) * 0.6; const l = 3.5 + R() * 2; const nx = px + Math.cos(a) * l, nz = pz + Math.sin(a) * l; if (Math.hypot(nx, nz) > 14) break; c.beam([px, 0.32, pz], [nx, 0.32, nz], 0.34, 0.06, { name: 'IceCrack', c: P.crack, shadow: false, extend: 0.3 }); px = nx; pz = nz; }
  }
  for (let k = 0; k < 11; k++) {
    const a = (k / 11) * Math.PI * 2;
    const da = Math.atan2(Math.sin(a - toRoad), Math.cos(a - toRoad));
    if (Math.abs(da) < 0.45) continue; // the side facing the road stays open
    const h = 15 + R() * 10;
    const sc = c.at([Math.sin(a) * 30, 0, Math.cos(a) * 30], [(R() - 0.5) * 6, R() * 60, (R() - 0.5) * 6]);
    for (const yaw of [0, 60]) sc.box({ name: 'StoneColumn', s: [3.6, h, 3.2], p: [0, h / 2, 0], r: [0, yaw, 0], c: P.basalt[(k + (yaw ? 1 : 0)) % 4], m: 'Slate', collide: yaw === 0 });
    // a squat second column beside the tall one, and frost crystals at the foot
    const h2 = h * (0.35 + R() * 0.2);
    sc.box({ name: 'StoneColumn', s: [2.6, h2, 2.6], p: [2.6, h2 / 2, 0.6], r: [0, 25, 0], c: P.basalt[(k + 2) % 4], m: 'Slate', collide: true });
    sc.box({ name: 'StoneSnow', s: [2.8, 0.6, 2.8], p: [2.6, h2 + 0.3, 0.6], r: [0, 25, 0], c: P.snow[(k + 1) % 4], studs: 'top' });
    for (let j = 0; j < 3; j++) sc.box({ name: 'FrostCrystal', s: [0.7, 1.6 + R() * 1.4, 0.7], p: [-2 + j * 0.9, 0.8, -2.2], r: [(R() - 0.5) * 40, R() * 90, (R() - 0.5) * 40], c: P.ice[j % 4], m: 'Glass', t: 0.1 });
    sc.box({ name: 'StoneSnow', s: [3.6, 0.8, 3.6], p: [0, h + 0.4, 0], r: [0, 30, 0], c: P.snow[k % 4], studs: 'top' });
    for (let j = 0; j < 2; j++) sc.box({ name: 'Icicle', s: [0.4, 1.4 + R(), 0.4], p: [-0.8 + j * 1.6, h - 0.6, -1.9], c: P.icicle, m: 'Glass', t: 0.12, shadow: false });
  }
  const sc = Z.at([fin.p[0] + Math.sin(toRoad) * 34, GROUND, fin.p[2] + Math.cos(toRoad) * 34], [0, E.deg(toRoad), 0]);
  E.signBoard(sc, [0, 4.4, 0], 8, 2, 'FROST STONES', { color: '#f2fbff', color2: '#5ab8ff', twoSided: true, pps: 30, trim: '#5ab8ff' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: E.PAL.woodLo });
}

// weather: static snowfall over the open stretches, ash flakes drifting off the ridge (the client adds camera-local
// snow on top of this via Ambience)
function buildWeather(Z, at, R) {
  const g = Z.group('Weather', 'Folder');
  const spots = [['PineRoad', 120], ['FrozenLake', 150], ['GinkgoHollow', 120], ['GinkgoHollow', 330], ['FallenGiants', 120], ['HotSprings', 150], ['Homestretch', 120]];
  for (const [seg, s] of spots) {
    const f = at(seg, s);
    const h = g.box({ name: 'Snowfall', s: [120, 1, 120], p: [f.p[0], 46, f.p[2]], t: 1, shadow: false });
    h.set('CanQuery', 'bool', false);
    E.particles(h, 'Snow', { rate: 26, life: [9, 12], speed: [3.5, 5], dir: 4, spread: [18, 18], size: [[0, 0.32], [1, 0.26]], transp: [[0, 0.05], [0.85, 0.15], [1, 1]], color: [1, 1, 1], emission: 0, accel: [1.4, 0, 0.5] });
  }
  for (const s of [60, 150, 230]) {
    const f = at('AshRidge', s);
    const h = g.box({ name: 'AshFall', s: [90, 1, 90], p: [f.p[0], 40, f.p[2]], t: 1, shadow: false });
    h.set('CanQuery', 'bool', false);
    E.particles(h, 'Ash', { rate: 10, life: [9, 13], speed: [2, 3.5], dir: 4, spread: [24, 24], size: [[0, 0.34], [1, 0.22]], transp: [[0, 0.1], [0.85, 0.2], [1, 1]], color: [0.22, 0.21, 0.24], emission: 0, accel: [1.6, 0, 0.6] });
  }
  // low ground mist over the frozen lake at dawn
  const mist = g.box({ name: 'LakeMist', s: [LAKE.rx * 1.6, 1, LAKE.rz * 1.6], p: [LAKE.x, GROUND + 1, LAKE.z], t: 1, shadow: false });
  mist.set('CanQuery', 'bool', false);
  E.particles(mist, 'Mist', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 4, life: [8, 12], speed: [0.5, 1.5], dir: 1, spread: [80, 80], size: [[0, 10], [1, 24]], transp: [[0, 0.84], [1, 1]], color: [0.92, 0.96, 1], emission: 0 });
}

function buildCinematics(Z, at) {
  const g = Z.group('Cinematics', 'Folder');
  const shot = (name, pos, look) => {
    const l = Z.wpt(look);
    const m = marker(g, name, pos.map((v, k) => v), 0, { s: [1, 1, 1] });
    m.attr('LookX', +l[0].toFixed(2)).attr('LookY', +l[1].toFixed(2)).attr('LookZ', +l[2].toFixed(2));
    return m;
  };
  const fern = at(NESTS[1].seg, NESTS[1].s, NESTS[1].x);
  const pines = at(NESTS[0].seg, NESTS[0].s, NESTS[0].x);
  const den = at(DEN.seg, DEN.s, DEN.x);
  const denRoad = at(DEN.seg, DEN.s, -6);
  // 1: high over the pine road: the frozen lake, the black ridge and the smoking volcano beyond
  shot('EstShot1', [-60, 78, 340], [-70, 24, -150]);
  // 2: the ginkgo hollow, gold on white, the fern hollow herd under the trees
  // (from above the road, which is always clear of trees, so no canopy sits in front of the lens)
  const fernRoad = at(NESTS[1].seg, Math.max(4, NESTS[1].s - 38), 0);
  shot('EstShot2', [fernRoad.p[0], 20, fernRoad.p[2]], [fern.p[0], 4, fern.p[2]]);
  // 3: down among the glider pines
  const pinesRoad = at(NESTS[0].seg, Math.max(4, NESTS[0].s - 34), 0);
  shot('EstShot3', [pinesRoad.p[0], 13, pinesRoad.p[2]], [pines.p[0], 9, pines.p[2]]);
  // 4: the White Lake from above its mouth: the cracked ice, the dais, the frozen falls
  shot('EstShot4', [denRoad.p[0], 34, denRoad.p[2]], [den.p[0], 6, den.p[2]]);
}

function buildNestSite(Z, n, at, R) {
  const f = at(n.seg, n.s, n.x);
  const g = Z.group('Nest_' + n.species);
  g.parent.attr('NestId', n.id).attr('Species', n.species).tag('ExpeditionNest');
  const roadP = at(n.seg, n.s, 0);
  const toRoad = Math.atan2(roadP.p[0] - f.p[0], roadP.p[2] - f.p[2]);
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, E.deg(toRoad), 0]); // local +Z points at the road
  const clearCol = { Microraptor: '#5e5446', Psittacosaurus: '#d8e2ea', Compy: '#cfdae6' }[n.species];
  c.cyl({ name: 'Clearing', axis: 'y', len: 0.1, d: 26, p: [0, 0.05, 0], c: clearCol, m: n.species === 'Microraptor' ? 'Sand' : 'SmoothPlastic', shadow: false });
  if (n.species === 'Psittacosaurus') {
    // a mound nest of earth and fronds
    c.cyl({ name: 'NestMound', axis: 'y', len: 1.2, d: 8, p: [0, 0.6, 0], c: '#7a5a3a', m: 'Sand' });
    for (let k = 0; k < 14; k++) { const a = (k / 14) * Math.PI * 2; c.box({ name: 'NestFrond', s: [2.8, 0.5, 1.1], p: [Math.cos(a) * 4, 1.2 + (k % 2) * 0.3, Math.sin(a) * 4], r: [R() * 20, -E.deg(a) + 90, R() * 15], c: P.fern[k % 2] }); }
  } else {
    // a cup of twigs, needles and down
    c.cyl({ name: 'NestMound', axis: 'y', len: 1, d: 7, p: [0, 0.5, 0], c: '#6e5a44', m: 'Sand' });
    for (let k = 0; k < 14; k++) { const a = (k / 14) * Math.PI * 2; c.box({ name: 'NestTwig', s: [2.6, 0.5, 0.7], p: [Math.cos(a) * 3.6, 1 + (k % 2) * 0.3, Math.sin(a) * 3.6], r: [R() * 20, -E.deg(a) + 90, R() * 15], c: k % 3 ? '#7a6048' : '#5e4a38' }); }
    c.cyl({ name: 'NestDown', axis: 'y', len: 0.2, d: 4.4, p: [0, 1.05, 0], c: '#f4f0e8', shadow: false });
  }
  for (let k = 0; k < 3; k++) {
    const egg = buildEgg(n.species);
    B.scaleTree(egg, 0.6);
    const a = (k / 3) * Math.PI * 2;
    B.transformTree(egg, c.frame.mul(new CF(Math.cos(a) * 1.3, 1.3, Math.sin(a) * 1.3)).mul(CF.deg(0, k * 40, (k - 1) * 8)));
    egg.tags = [];
    egg.name = 'NestEgg';
    g.parent.add(egg);
  }
  // (2026-10-13: the flag stood right on GuardSpot1 - the first guard (a raptor) was impaled on its pole in every
  // scene. Now midway between two guard spots, outside the guard ring and the clearing)
  E.flag(c, [0.37, 0, 16], '#5ab8ff', { h: 7 });
  const sgn = Z.at([f.base[0] - f.r[0] * (n.x > 0 ? -21 : 21), GROUND, f.base[2] - f.r[2] * (n.x > 0 ? -21 : 21)], [0, yawOf(f) + 180, 0]);
  E.signBoard(sgn, [0, 4.2, 0], 7, 2.2, n.label, { color: '#f2fbff', color2: '#5ab8ff', twoSided: true, pps: 30, trim: '#5ab8ff' });
  sgn.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
  sgn.box({ name: 'SignSnow', s: [7.6, 0.4, 0.8], p: [0, 5.55, 0], c: P.snow[0] });
  for (let k = 0; k < 3; k++) {
    const a = (k / 3) * Math.PI * 2 + 0.5;
    const m = c.box({ name: 'GuardSpot' + (k + 1), s: [1.5, 1, 1.5], p: [Math.cos(a) * 9, 0.5, Math.sin(a) * 9], r: [0, -E.deg(a) - 90, 0], t: 1, shadow: false });
    m.set('CanQuery', 'bool', false);
  }
  const host = c.box({ name: 'NestCore', s: [2, 2, 2], p: [0, 1.8, 0], t: 1, shadow: false });
  host.set('CanQuery', 'bool', false);
  const pr = new Inst('ProximityPrompt', 'GrabPrompt');
  pr.set('ActionText', 'string', 'Grab Egg').set('ObjectText', 'string', n.label).set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 10).set('HoldDuration', 'float', 1.6).set('RequiresLineOfSight', 'bool', false).set('Exclusivity', 'token', 1);
  pr.attr('NestId', n.id);
  host.add(pr);
  E.particles(host, 'NestGlint', { rate: 3, life: [0.8, 1.4], speed: [0.5, 1], size: [[0, 0.5], [1, 0]], color: [1, 0.95, 0.75], emission: 0.8 });
  E.pointLight(host, [1, 0.84, 0.6], 18, 0.7);
  const open = (a) => Math.cos(a - Math.PI / 2) < 0.6; // the road side (+Z) stays open
  if (n.species === 'Microraptor') {
    // GLIDER PINES: a ring of tall pines whose long bare boughs reach out over the nest: the pack glides between them
    let perch = 0;
    for (let k = 0; k < 6; k++) {
      const a = (k / 6) * Math.PI * 2 + 0.26;
      if (!open(a)) continue;
      const r = 16 + R() * 3;
      const p = c.wpt([Math.cos(a) * r, 0, Math.sin(a) * r]);
      // bough yaw in pine-local space: point back at the nest centre
      const wdir = [f.p[0] - (p[0] - FF_ORIGIN[0]), f.p[2] - (p[2] - FF_ORIGIN[2])];
      const yawW = E.deg(Math.atan2(-wdir[0], -wdir[1]));
      const y = 14 + (k % 2) * 5;
      const len = r - 6;
      snowPine(g, [p[0] - FF_ORIGIN[0], GROUND, p[2] - FF_ORIGIN[2]], 44 + R() * 10, 9800 + k, { name: 'GliderPine', yaw: 0, spread: 0.2, trunk: 0.42, perches: [{ y, yaw: yawW, len }] });
      const tip = [p[0] - FF_ORIGIN[0] + (wdir[0] / Math.hypot(...wdir)) * len, GROUND + y + 1.2 + Math.sin(6 * Math.PI / 180) * len, p[2] - FF_ORIGIN[2] + (wdir[1] / Math.hypot(...wdir)) * len];
      marker(Z, 'PerchSpot' + (++perch), tip, 0, { s: [1.5, 1, 1.5] }).attr('Perch', true).attr('NestId', n.id);
    }
    for (let k = 0; k < 4; k++) { const a = (k / 4) * Math.PI * 2 + 0.9; if (open(a)) iceRock(c, [Math.cos(a) * 12, 0, Math.sin(a) * 12], 1.3 + R() * 0.6, 9850 + k); }
  } else if (n.species === 'Psittacosaurus') {
    // FERN HOLLOW: thick undergrowth under gold ginkgos, green ferns punching up through the snow
    for (let k = 0; k < 5; k++) { const a = (k / 5) * Math.PI * 2 + 0.4; if (open(a)) ginkgo(c, [Math.cos(a) * 19, 0, Math.sin(a) * 19], 18 + R() * 6, 9900 + k, { litter: 4 }); }
    for (let k = 0; k < 22; k++) {
      const a = R() * Math.PI * 2, r = 6 + R() * 8;
      if (!open(a) && r < 11) continue;
      if (Math.hypot(Math.cos(a) * r - Math.cos(0.5) * 9, Math.sin(a) * r - Math.sin(0.5) * 9) < 2.5) continue;
      if (k % 4 === 3) E.bush(c, [Math.cos(a) * (r + 3), 0, Math.sin(a) * (r + 3)], 0.9 + R() * 0.4, 9920 + k, { n: 5, colors: ['#3f8a3a', '#4f9a3e', P.snow[0], '#5aa844'] });
      else E.fern(c, [Math.cos(a) * r, 0, Math.sin(a) * r], 1.6 + R() * 0.9, 9920 + k);
    }
  } else {
    // LOG WARREN: hollow logs lying round the nest, holes just compy-sized, snow along their backs
    for (let k = 0; k < 5; k++) {
      const a = (k / 5) * Math.PI * 2 + 0.2;
      if (!open(a)) continue;
      const r = 13 + R() * 2;
      const lc = c.at([Math.cos(a) * r, 0, Math.sin(a) * r], [0, -E.deg(a) + (R() - 0.5) * 30, 0]);
      const Lg = 12 + R() * 4, D = 4.6;
      for (let j = 0; j < 8; j++) {
        const b = (j / 8) * Math.PI * 2;
        lc.box({ name: 'HollowLog', s: [1.9, 0.8, Lg], p: [Math.cos(b) * (D / 2 - 0.4), D / 2 + Math.sin(b) * (D / 2 - 0.4), 0], r: [0, 0, E.deg(b) + 90], c: P.bark[j % 3], m: 'WoodPlanks', collide: true });
      }
      lc.box({ name: 'HollowDark', s: [D - 1.6, D - 1.6, Lg - 0.6], p: [0, D / 2, 0], c: '#1c140e', shadow: false });
      lc.box({ name: 'HollowLogSnow', s: [2.2, 0.4, Lg - 0.6], p: [0, D + 0.05, 0], c: P.snow[k % 4], studs: 'top' });
    }
    // and a hollow stump the pack bolts into
    const st = c.at([-6, 0, -9]);
    for (let j = 0; j < 6; j++) { const b = (j / 6) * Math.PI * 2; st.box({ name: 'HollowStump', s: [2.4, 4 + R() * 1.4, 0.9], p: [Math.cos(b) * 2, 2.2, Math.sin(b) * 2], r: [0, -E.deg(b) + 90, 0], c: P.bark[j % 3], m: 'WoodPlanks', collide: true }); }
    st.box({ name: 'StumpHole', s: [2.4, 0.1, 2.4], p: [0, 0.1, 0], c: '#1c140e', shadow: false });
  }
}

// ------------------------------------------------------------------ Luau data
function routeData(route, at) {
  const O = FF_ORIGIN;
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
  const arrival = at('PineRoad', 4);
  return {
    Zone: 'FrostForest', Name: 'FROST FOREST', Era: '125,000,000 BC', Year: -125000000,
    Variants: variants, Forks: forks, Features: features, Sections: sections, Nests: nests,
    Arrival: [arrival.p[0] + O[0], ROAD, arrival.p[2] + O[2], arrival.f[0], arrival.f[2]],
  };
}

const QC = {
  decor: ['SnowPine', 'GliderPine', 'Ginkgo', 'AshSnag', 'IceRock', 'SnowDrift', 'BasaltCluster', 'RidgeBasalt'],
  ground: /^(Snow|GroundPatch|IceSheet|IceDeep|SnowDust|IceCrack|IceHole|LakeIce|SnowBerm|SnowPole\w*|PoleFlag|GoldLitter|MossPatch|MossRing|SpringTerrace|SpringWater|SpringDeep|SpringRim|SpringStain|Runoff|VentCrust|EmberCrack|TrackHeel|TrackToe|Feather|AshRidgeFar|VolcanoSnow|Peak|PortalSnow|PlinthSnow|LedgeTop|LedgeRock|StoneSnow|FallLip)$/,
};

module.exports = { buildFrostForest, FF_ORIGIN, QC };
