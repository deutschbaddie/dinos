// SPINE RIVER — the third era (97,000,000 BC). A jungle river delta that runs out through a bay into the open sea.
// Real Terrain water (the server fills it from the WaterVolume markers), so you can swim, the rover can wade and,
// in the ruler's chase, run as a boat. Ruler: the MOSASAURUS, in the Sea Mouth bay among the wrecked research docks.
//   Jungle Road → fork: The Ford (wade the river) | Vine Bridge → Spine Bend (Fishing Bank, Spinosaurus) → the Sea
//   Mouth (the docks, ruler's den) → the Sea Lane (out on open water along the coast) → landfall → Carno Ridge
//   (Carnotaurus) → fork: Mangrove Run (Croc Creek, Sarcosuchus) | Cliff Falls (jump) → Homestretch → Return Portal
// Zone-local space: origin = SR_ORIGIN, north = -Z. Water surface y = 0; land is a heightfield standing up out of it.
const { Inst, Ctx, CF, shade, rng } = require('./builder.js');
const E = require('./env.js');
const RT = require('./route.js');
const NPC = require('./npcs.js');
const { buildEgg, EGG_SPECIES } = require('./eggs.js');
const B = require('./builder.js');

const SR_ORIGIN = [-50, 0, -2560];
const WATER_Y = 0, BED_Y = -9, LAND = 1.4, ROAD = 0.12;
const BX = 440, BZ0 = -330, BZ1 = 400;
const P = {
  grass: ['#4fa83c', '#58b244', '#469a36', '#62b84a'], grassHi: ['#7cc04e', '#86c858', '#72b646'],
  mud: '#6e5034', mudLo: '#5a4028', sand: '#d8c48a', sandLo: '#c4ae74', bed: '#5f6a4a',
  rock: ['#7d7a73', '#6c6962', '#8a857b', '#5f5c56'], cliff: ['#8a7a64', '#7a6c58', '#96866e', '#6e604e'],
  wood: '#8a6238', woodLo: '#6e4c2a', woodHi: '#a8743f', rope: '#c8a870', plank: ['#9a7046', '#8a6038', '#a87a4c'],
  leaf: ['#2f8a3a', '#3f9a3a', '#4fb043', '#2a7a34', '#5bbd4a'], mangrove: ['#3e7a34', '#4a8a3c', '#356a2e'],
  water: '#3fa0b8', bone: '#efe2c4', rust: '#b8642e', metal: '#7a8088', paint: '#e8d6a8', hazard: '#f2c230',
};
function marker(ctx, name, p, yaw = 0, o = {}) {
  const m = ctx.box({ name, s: o.s || [1, 1, 1], p, r: [0, yaw, 0], t: 1, shadow: false, c: '#ffffff' });
  m.set('CanQuery', 'bool', false);
  m.set('CanCollide', 'bool', false);
  return m;
}

// ------------------------------------------------------------------ the river, the bay and the sea (local x, z)
const RIVER = [[64, 440], [48, 330], [16, 232], [-14, 152], [-26, 84], [-20, 10], [-2, -70], [8, -150], [12, -190]];
const RIVER_HW = (z) => 20 + Math.max(0, (60 - z) / 260) * 14; // widens toward the bay
const BAY = { x: 14, z: -214, r: 70 };
// a slow mangrove creek beside Mangrove Run (Croc Creek's nest sits between it and the road)
const CREEK = [[236, -40], [214, 40], [190, 110], [196, 180], [222, 250]];
const CREEK_HW = 9; // the Sea Mouth: a round bay open to the sea in the north
const SHORE_Z = -262; // north of this (east of the cliffs) is open sea
const WEST_CLIFF_X = -120; // the west headland: cliffs run down into the sea

const DEF = {
  start: 'Arrival',
  nodes: { Arrival: { tangent: [0, 0, -1] }, ForkA: {}, MergeA: {}, ForkB: {}, MergeB: {}, Exit: {} },
  segments: {
    JungleRoad: { from: 'Arrival', to: 'ForkA', width: 26, name: 'JUNGLE ROAD', pts: [[-280, LAND, 340], [-282, 2, 260], [-262, 4, 190], [-214, 2.5, 132], [-150, LAND, 100]] },
    TheFord: { from: 'ForkA', to: 'MergeA', width: 26, name: 'THE FORD', pts: [[-150, LAND, 100], [-92, LAND, 96], [-24, -1.0, 92], [40, LAND, 82], [100, LAND, 50]] },
    VineBridge: { from: 'ForkA', to: 'MergeA', width: 22, name: 'VINE BRIDGE', pts: [[-150, LAND, 100], [-118, 1.6, 44], [-70, 3, 10], [-20, 7, 4], [30, 3, 14], [100, LAND, 50]] },
    SpineBend: {
      from: 'MergeA', to: 'ForkB', width: 28, name: 'SPINE BEND',
      pts: [[100, LAND, 50], [150, LAND, 0], [152, LAND, -80], [124, LAND, -150], [98, LAND, -212], [112, -1.2, -268], [182, -1.2, -298], [262, -1.2, -292], [330, -1.2, -250], [362, LAND, -186], [352, LAND, -100], [320, LAND, -20]],
    },
    MangroveRun: { from: 'ForkB', to: 'MergeB', width: 24, name: 'MANGROVE RUN', pts: [[320, LAND, -20], [276, LAND, 40], [246, LAND, 112], [258, LAND, 182], [282, LAND, 250]] },
    CliffFalls: { from: 'ForkB', to: 'MergeB', width: 22, name: 'CLIFF FALLS', pts: [[320, LAND, -20], [362, 4, 40], [372, 14, 116], [344, 16, 196], [282, LAND, 250]] },
    Homestretch: { from: 'MergeB', to: 'Exit', width: 28, name: 'HOMESTRETCH', pts: [[282, LAND, 250], [236, LAND, 298], [186, LAND, 336], [140, LAND, 360]] },
  },
};
const SECTIONS = [
  ['JungleRoad', 0, 'JUNGLE ROAD'], ['TheFord', 0, 'THE FORD'], ['VineBridge', 0, 'VINE BRIDGE'],
  ['SpineBend', 0, 'SPINE BEND'], ['SpineBend', 250, 'THE SEA MOUTH'], ['SpineBend', 330, 'THE SEA LANE'], ['SpineBend', 600, 'CARNO RIDGE'],
  ['MangroveRun', 0, 'MANGROVE RUN'], ['CliffFalls', 0, 'CLIFF FALLS'], ['Homestretch', 0, 'HOMESTRETCH'],
];
const NESTS = [
  { id: 1, species: 'Spinosaurus', seg: 'SpineBend', s: 140, x: -32, guard: 'Brute', label: 'FISHING BANK' },
  { id: 2, species: 'Carnotaurus', seg: 'SpineBend', s: 700, x: 30, guard: 'Pack', label: 'CARNO RIDGE' },
  { id: 3, species: 'Sarcosuchus', seg: 'MangroveRun', s: 140, x: -32, guard: 'Brute', label: 'CROC CREEK' },
];
const FEATURES = [
  ['Darts', 'JungleRoad', 200, 6], ['Darts', 'SpineBend', 100, -7], ['Darts', 'SpineBend', 520, 0], ['Darts', 'CliffFalls', 70, 0], ['Darts', 'MangroveRun', 40, 0], ['Darts', 'Homestretch', 90, 6],
  ['Boost', 'JungleRoad', 70, 0], ['Coin', 'JungleRoad', 95, 6], ['Coin', 'JungleRoad', 101, 6], ['Coin', 'JungleRoad', 107, 6], ['Boost', 'JungleRoad', 170, -7], ['Repair', 'JungleRoad', 250, -8],
  ['Splash', 'TheFord', 130, 0, { len: 50 }], ['Coin', 'TheFord', 60, 6], ['Coin', 'TheFord', 66, 6], ['Coin', 'TheFord', 130, 0], ['Repair', 'TheFord', 220, 0],
  ['Boost', 'VineBridge', 90, 0], ['Coin', 'VineBridge', 140, 0], ['Coin', 'VineBridge', 146, 0], ['Coin', 'VineBridge', 152, 0], ['Repair', 'VineBridge', 250, 0],
  ['Coin', 'SpineBend', 200, 8], ['Coin', 'SpineBend', 206, 8], ['Boost', 'SpineBend', 240, 0],
  ['Splash', 'SpineBend', 330, 0, { len: 30 }], ['Coin', 'SpineBend', 380, -6], ['Coin', 'SpineBend', 386, -6], ['Boost', 'SpineBend', 450, 0], ['Coin', 'SpineBend', 480, 6], ['Splash', 'SpineBend', 560, 0, { len: 26 }],
  ['Repair', 'SpineBend', 640, 8], ['Charge', 'SpineBend', 760, 0, { len: 50 }], ['Coin', 'SpineBend', 790, -8], ['Coin', 'SpineBend', 796, -8],
  ['Boost', 'MangroveRun', 110, 0], ['Coin', 'MangroveRun', 70, 0], ['Coin', 'MangroveRun', 76, 0], ['Repair', 'MangroveRun', 200, 0], ['Coin', 'MangroveRun', 240, 8],
  ['Boost', 'CliffFalls', 100, 0], ['Jump', 'CliffFalls', 165, 0, { len: 34 }], ['Coin', 'CliffFalls', 178, 0], ['Coin', 'CliffFalls', 184, 0], ['Coin', 'CliffFalls', 190, 0],
  ['Stampede', 'Homestretch', 90, 0, { len: 40 }], ['Boost', 'Homestretch', 130, 0], ['Coin', 'Homestretch', 160, -6], ['Coin', 'Homestretch', 166, -6],
];
// the ruler's den is the bay itself (docks around open water); the final stand is out on the Sea Lane
const DEN = { seg: 'SpineBend', s: 300, x: -84 };
const FINAL = { seg: 'SpineBend', s: 560, x: -62 }; // THE MAW: a rock ring out at sea beside the Sea Lane (moved out 12 when the pool grew)
// (2026-10-12: the pool was 28 across and the Tidebreaker is ~32 long: it clipped through the ring every time it
// went to the middle. Now 48 across, so it fits, with the same 16-wide ring to stand on)
const MAW = { inner: 24, outer: 40, top: 2.2 };

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
  return [Math.hypot(x - a[0] - dx * t, z - a[1] - dz * t), a[1] + dz * t];
};
// how far inside the water a point is (>0 = water, <0 = land; ~distance to the shore)
function waterDepth(x, z) {
  let best = -Infinity;
  for (let i = 0; i < RIVER.length - 1; i++) {
    const [d, zz] = distSeg(x, z, RIVER[i], RIVER[i + 1]);
    best = Math.max(best, RIVER_HW(zz) - d);
  }
  best = Math.max(best, BAY.r - Math.hypot(x - BAY.x, z - BAY.z));
  for (let i = 0; i < CREEK.length - 1; i++) best = Math.max(best, CREEK_HW - distSeg(x, z, CREEK[i], CREEK[i + 1])[0]);
  // the sea: everything north of the shore line, except under the west headland
  if (x > WEST_CLIFF_X) best = Math.max(best, (SHORE_Z - z) + (Math.hypot(x - BAY.x, z - BAY.z) < BAY.r + 40 ? 30 : 0));
  return best;
}

// mangrove: a crown on a cage of arching stilt roots, standing in the shallows
function mangrove(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('Mangrove');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = 6;
  for (let k = 0; k < n; k++) {
    const a = (k / n) * Math.PI * 2 + R() * 0.4;
    const r = 3.4 + R() * 1.2;
    t.beam([Math.cos(a) * r, -1.5, Math.sin(a) * r], [Math.cos(a) * r * 0.45, h * 0.3, Math.sin(a) * r * 0.45], 0.5, 0.5, { name: 'StiltRoot', c: P.woodLo, extend: 0.4 });
    t.beam([Math.cos(a) * r * 0.45, h * 0.3, Math.sin(a) * r * 0.45], [0, h * 0.45, 0], 0.55, 0.55, { name: 'StiltRoot', c: P.woodLo, extend: 0.3 });
  }
  for (let i = 0; i < 3; i++) t.box({ name: 'MangroveTrunk', s: [1.2, h * 0.2, 1.2], p: [0, h * 0.45 + i * h * 0.18, 0], r: [0, i * 30, (R() - 0.5) * 8], c: P.woodLo, studs: 'sides', collide: i === 0 });
  for (let k = 0; k < 6; k++) t.box({ name: 'MangroveCanopy', s: [5 + R() * 3, 2.2, 5 + R() * 3], p: [(R() - 0.5) * 5, h * 0.95 + (R() - 0.5) * 1.6, (R() - 0.5) * 5], r: [0, R() * 90, 0], c: P.mangrove[k % 3], studs: 'top' });
  return g;
}
// reeds / cattails at the waterline
function reeds(ctx, p, seed, n = 6) {
  const R = rng(seed);
  const g = ctx.group('Reeds');
  for (let k = 0; k < n; k++) {
    const h = 1.6 + R() * 1.8;
    const x = p[0] + (R() - 0.5) * 4, z = p[2] + (R() - 0.5) * 4;
    g.box({ name: 'Reed', s: [0.16, h, 0.16], p: [x, p[1] + h / 2 - 0.3, z], r: [(R() - 0.5) * 12, 0, (R() - 0.5) * 12], c: k % 2 ? '#4f8a35' : '#5f9a3e', shadow: false });
    if (R() > 0.5) g.box({ name: 'Cattail', s: [0.3, 0.7, 0.3], p: [x, p[1] + h - 0.1, z], c: '#6b4a2b', shadow: false });
  }
  return g;
}
function lily(ctx, p, seed) {
  const R = rng(seed);
  for (let k = 0; k < 3; k++) {
    const d = 1.2 + R() * 1.4;
    ctx.cyl({ name: 'LilyPad', axis: 'y', len: 0.1, d, p: [p[0] + (R() - 0.5) * 6, WATER_Y + 0.06, p[2] + (R() - 0.5) * 6], c: R() > 0.5 ? '#4fb043' : '#5fbd4a', shadow: false });
    if (R() > 0.7) ctx.box({ name: 'LilyFlower', s: [0.4, 0.35, 0.4], p: [p[0] + (R() - 0.5) * 4, WATER_Y + 0.25, p[2] + (R() - 0.5) * 4], c: '#ff8ab0', shadow: false });
  }
}
function treeFern(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('TreeFern');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = Math.max(2, Math.round(h / 2.4));
  for (let i = 0; i < n; i++) t.box({ name: 'FernTrunk', s: [1.1, 2.5, 1.1], p: [0, 1.2 + i * 2.4, 0], r: [0, i * 30, (R() - 0.5) * 6], c: i % 2 ? '#5e4a2e' : '#6e5636', studs: 'sides', collide: i === 0 });
  const top = t.at([0, n * 2.4 + 0.3, 0]);
  top.box({ name: 'FernCrown', s: [1.6, 0.8, 1.6], c: '#3f7a2e' });
  for (let i = 0; i < 8; i++) {
    const f = top.at([0, 0, 0], [0, i * 45 + R() * 12, 0]);
    f.box({ name: 'Frond', s: [1.2, 0.2, 3.6], p: [0, 0.5, -1.8], r: [18, 0, 0], c: i % 2 ? '#4fb043' : '#5bbd4a', studs: 'top' });
    f.box({ name: 'FrondTip', s: [0.7, 0.16, 2.4], p: [0, -0.2, -4.6], r: [-30, 0, 0], c: '#3f9a3a' });
  }
  return g;
}

function buildSpineRiver() {
  const route = RT.buildRoute(DEF);
  const root = new Inst('Model', 'SpineRiver');
  root.attr('Zone', 'SpineRiver').attr('WaterY', WATER_Y + SR_ORIGIN[1]);
  const Z = new Ctx({ parent: root, frame: new CF(...SR_ORIGIN), defaults: { anchored: true } });
  const R = rng(97097);
  const segs = route.segs;
  for (const s of Object.values(segs)) s.cum = RT.cumOf(s.samples);
  const at = (segId, s, x = 0, y = 0) => { const sg = segs[segId]; return RT.at(sg.samples, sg.cum, s, x, y); };
  const roadPts = [];
  for (const s of Object.values(segs)) for (const p of s.samples) roadPts.push([p[0], p[2], s.width / 2]);
  const nearRoad = (x, z, pad) => roadPts.some(([px, pz, hw]) => Math.hypot(x - px, z - pz) < hw + pad);
  const jumpRanges = {};
  for (const f of FEATURES) if (f[0] === 'Jump') (jumpRanges[f[1]] = jumpRanges[f[1]] || []).push([f[2] - f[4].len / 2, f[2] + f[4].len / 2]);
  for (const [segId, ranges] of Object.entries(jumpRanges)) {
    const sg = segs[segId];
    sg.samples.forEach((p, i) => { for (const [a, b] of ranges) if (sg.cum[i] > a && sg.cum[i] < b) { const t = (sg.cum[i] - a) / (b - a); p[1] += Math.sin(t * Math.PI) * 7; } });
  }
  // a road sample is "wet" when its surface is under the waterline: no road tiles, the rover wades / floats
  const wet = (p) => p[1] < WATER_Y + 0.2;

  // ------------------------------------------------ the river bed + water volumes (server fills Terrain water)
  const G = Z.group('Ground', 'Folder');
  G.box({ name: 'RiverBed', s: [BX * 2 + 40, 2, BZ1 - BZ0 + 40], p: [0, BED_Y - 1, (BZ0 + BZ1) / 2], c: P.bed, m: 'Sand', collide: true });
  G.box({ name: 'SeaBed', s: [1800, 2, 900], p: [0, BED_Y - 6, BZ0 - 450], c: '#4f6a6a', m: 'Sand', collide: true });
  const W = Z.group('Water', 'Folder');
  const wv = (name, p, s, yaw = 0) => {
    if (!(s[0] > 1 && s[1] > 1 && s[2] > 1)) throw new Error(`SpineRiver: water volume ${JSON.stringify(s)} is empty or inside out`);
    const m = marker(W, name, p, yaw, { s }); m.tag('TerrainWater'); return m;
  };
  // river: one box per span; the bay; the sea out to the horizon
  for (let i = 0; i < RIVER.length - 1; i++) {
    const [ax, az] = RIVER[i], [bx, bz] = RIVER[i + 1];
    const L = Math.hypot(bx - ax, bz - az);
    const yaw = E.deg(Math.atan2(-(bx - ax), -(bz - az)));
    wv('WaterVolume', [(ax + bx) / 2, (BED_Y + WATER_Y) / 2, (az + bz) / 2], [RIVER_HW((az + bz) / 2) * 2 + 8, WATER_Y - BED_Y, L + 30], yaw);
  }
  wv('WaterVolume', [BAY.x, (BED_Y + WATER_Y) / 2, BAY.z], [BAY.r * 2 + 30, WATER_Y - BED_Y, BAY.r * 2 + 30]);
  for (let i = 0; i < CREEK.length - 1; i++) {
    const [ax, az] = CREEK[i], [bx, bz] = CREEK[i + 1];
    const L = Math.hypot(bx - ax, bz - az);
    wv('WaterVolume', [(ax + bx) / 2, (BED_Y + WATER_Y) / 2, (az + bz) / 2], [CREEK_HW * 2 + 6, WATER_Y - BED_Y, L + 16], E.deg(Math.atan2(-(bx - ax), -(bz - az))));
  }
  wv('WaterVolume', [140, (BED_Y - 6 + WATER_Y) / 2, BZ0 - 420], [1800, WATER_Y - BED_Y + 6, 900]);
  // the coastal strip between the shore line and the open-sea box (the Sea Lane + the Maw's south half). (2026-10-14:
  // its depth was BZ0 - SHORE_Z + 40 = -28, i.e. a 0.05-thick sliver: the whole Sea Lane and half the Maw had no water
  // at all, so the boat chase rover drove on air.) Overlaps the sea box by 30 and runs under the beach (hidden inside the land columns).
  const STRIP_N = BZ0, STRIP_S = SHORE_Z + 42; // (the sea box's south edge is BZ0 + 30; 42 covers the lane's shallow ramps)
  wv('WaterVolume', [(WEST_CLIFF_X + BX) / 2 + 10, (BED_Y + WATER_Y) / 2, (STRIP_N + STRIP_S) / 2], [BX - WEST_CLIFF_X + 20, WATER_Y - BED_Y, STRIP_S - STRIP_N]);
  // a surface the cinematics + DinoWater code can find (invisible, non-solid)
  const surf = Z.box({ name: 'WaterSurface', s: [2000, 0.2, 1400], p: [0, WATER_Y - 0.1, BZ0 - 300], t: 1, shadow: false });
  surf.set('CanQuery', 'bool', false).set('CanCollide', 'bool', false);
  surf.tag('DinoWater');
  // the edge of the world at sea: an invisible wall a little way out (and sea stacks so it reads as a coast)
  const wall = Z.box({ name: 'SeaWall', s: [BX * 2 + 400, 60, 2], p: [0, 20, BZ0 - 70], t: 1, shadow: false, collide: true });
  wall.set('CanQuery', 'bool', false);

  // ------------------------------------------------ land: a heightfield standing up out of the water
  const T = land(Z, segs, at, wet);
  const hAt = T.hAt;

  // ------------------------------------------------ roads (dirt on land, gravel under the ford, planks on the bridge)
  const roads = Z.group('Roads', 'Folder');
  const bridge = (sg, s) => sg.id === 'VineBridge' && s > 100 && s < 210;
  for (const sg of Object.values(segs)) {
    const gaps = jumpRanges[sg.id] || [];
    const inGap = (s) => gaps.some(([a, b]) => s > a + 1 && s < b - 1);
    const Wd = sg.width;
    const n = sg.samples.length;
    const head = (u, v) => Math.atan2(sg.samples[v][0] - sg.samples[u][0], sg.samples[v][2] - sg.samples[u][2]);
    const angDiff = (x, y) => Math.abs(Math.atan2(Math.sin(x - y), Math.cos(x - y)));
    let tile = 0;
    for (let i = 0; i < n - 1;) {
      let j = Math.min(n - 1, i + 3);
      const h0 = head(i, Math.min(n - 1, i + 1));
      while (j < n - 1 && sg.cum[j + 1] - sg.cum[i] <= 24 && angDiff(head(i, j + 1), h0) < 0.02 && Math.abs(sg.samples[j + 1][1] - sg.samples[i][1]) < 0.02 && !inGap(sg.cum[j + 1])) j++;
      const a = sg.samples[i], b = sg.samples[j];
      const sMid = (sg.cum[i] + sg.cum[j]) / 2;
      const i0 = i;
      i = j;
      if (inGap(sMid)) continue;
      const ya = ROAD + a[1], yb = ROAD + b[1];
      if (wet(a) && wet(b) && a[1] < -1.1) continue; // open water: the sea lane has no road at all
      if (bridge(sg, sMid)) {
        // the vine bridge deck: planks across, rope rails (posts built below)
        roads.beam([a[0], ya - 0.3, a[2]], [b[0], yb - 0.3, b[2]], Wd, 0.6, { name: 'Road', c: P.plank[tile++ % 3], m: 'WoodPlanks', collide: true, extend: 0.3 });
        continue;
      }
      const ford = wet(a) || wet(b);
      roads.beam([a[0], ya - 0.3, a[2]], [b[0], yb - 0.3, b[2]], Wd, 0.6, { name: 'Road', c: ford ? '#8a8270' : (tile % 2 ? P.mud : shade(P.mud, 1.08)), m: ford ? 'Pebble' : 'Sand', collide: true, extend: 0.2 });
      const fa = RT.frameAt(sg.samples, i0), fb = RT.frameAt(sg.samples, j);
      if (!ford && tile % 2 === 0) for (const rx of [-Wd * 0.18, Wd * 0.18]) roads.beam([a[0] + fa.r[0] * rx, ya + 0.02, a[2] + fa.r[2] * rx], [b[0] + fb.r[0] * rx, yb + 0.02, b[2] + fb.r[2] * rx], 1.2, 0.04, { name: 'Rut', c: P.mudLo, m: 'Sand', shadow: false });
      tile++;
    }
  }

  // ------------------------------------------------ boundary: cliffs W/S/E, the west headland into the sea, peaks behind
  E.cliffWall(Z, [[-BX, BZ1], [-BX, SHORE_Z + 10], [WEST_CLIFF_X, SHORE_Z + 10], [WEST_CLIFF_X, BZ0 - 40]].reverse(), { h: 60, d: 26, seed: 911, slope: 6, name: 'HeadlandCliffs', chunk: 16, trees: true, colors: P.cliff });
  E.cliffWall(Z, [[BX, BZ0 - 30], [BX, BZ1], [-BX, BZ1]], { h: 58, d: 26, seed: 912, slope: 6, name: 'ValleyCliffs', chunk: 16, trees: true, colors: P.cliff });
  const M = Z.group('Skyline');
  for (let k = 0; k < 8; k++) {
    const x = -520 + k * 150 + (R() - 0.5) * 40, z = 520 + R() * 60;
    const h = 120 + R() * 90;
    for (let t = 0; t < 5; t++) M.box({ name: 'Peak', s: [160 - t * 26 + R() * 14, h / 5 + 1, 120 - t * 18], p: [x + (R() - 0.5) * 8 * t, (t + 0.5) * (h / 5), z], r: [0, (R() - 0.5) * 22, 0], c: t >= 4 ? '#e8eef2' : shade('#5e7a5a', 0.9 + t * 0.05), m: 'Slate' });
  }
  for (const side of [-1, 1]) for (let k = 0; k < 3; k++) {
    const x = side * (560 + R() * 40), z = 300 - k * 220;
    const h = 100 + R() * 70;
    for (let t = 0; t < 4; t++) M.box({ name: 'Peak', s: [130 - t * 26, h / 4 + 1, 150 - t * 26], p: [x, (t + 0.5) * (h / 4), z], r: [0, R() * 30, 0], c: shade('#5e7a5a', 0.9 + t * 0.05), m: 'Slate' });
  }
  // sea stacks off the coast + a far island on the horizon (2026-10-12: the one at 360,-330 stood inside the Maw; moved clear)
  const SS = Z.group('SeaStacks');
  for (const [x, z, h] of [[-60, -360, 34], [80, -400, 46], [230, -370, 28], [430, -372, 38], [-200, -330, 52], [470, -420, 30]]) {
    const c = SS.at([x, BED_Y, z], [0, R() * 360, 0]);
    const H = h - BED_Y;
    for (let t = 0; t < 5; t++) c.box({ name: 'StackRock', s: [16 - t * 2 + R() * 3, H / 5 + 0.4, 14 - t * 2 + R() * 3], p: [(R() - 0.5) * 2, (t + 0.5) * (H / 5), (R() - 0.5) * 2], r: [0, t * 17, (R() - 0.5) * 4], c: P.cliff[t % 4], m: 'Slate', studs: 'top', collide: true });
    c.box({ name: 'StackTop', s: [7, 1.2, 6], p: [0, H + 0.6, 0], c: P.grass[1], studs: 'top' });
    if (h > 40) E.palm(c, [0, H + 1.2, 0], 8, 9800 + x);
  }
  {
    const isle = Z.at([120, BED_Y, -900]);
    for (let t = 0; t < 4; t++) isle.box({ name: 'FarIsland', s: [260 - t * 50, 14, 120 - t * 22], p: [0, 7 + t * 12, 0], c: t > 1 ? P.leaf[3] : P.cliff[1], m: 'Slate' });
  }

  // ------------------------------------------------ set pieces
  buildArrival(Z, at);
  buildFord(Z, segs, at, R);
  buildVineBridge(Z, segs, at, R);
  buildSeaMouth(Z, at, R, route);
  buildSeaLane(Z, segs, at, R);
  buildMaw(Z, at, R);
  buildCliffFalls(Z, segs, at, R, jumpRanges.CliffFalls || []);
  for (const n of NESTS) buildNestSite(Z, n, at, R, hAt);
  buildReturnPortal(Z, at);
  buildCinematics(Z, at);
  { const f = at('JungleRoad', 0); const c = Z.at([f.p[0] + 20, LAND, f.p[2] - 12], [0, -60, 0]); NPC.buildNpc(c.parent, c.world(new CF(0, 0, 0)), 'Ranger'); }

  // ------------------------------------------------ vegetation: jungle on land, mangroves + reeds at the water's edge
  const V = Z.group('Jungle');
  const placed = [];
  const keepOut = [];
  { const d = at(DEN.seg, DEN.s, DEN.x); keepOut.push([d.p[0], d.p[2], BAY.r + 26]); }
  for (const n of NESTS) { const f = at(n.seg, n.s, n.x); keepOut.push([f.p[0], f.p[2], 26]); }
  const tryPlace = (x, z, pad, gap) => {
    if (Math.abs(x) > BX - 22 || z < BZ0 + 10 || z > BZ1 - 22) return false;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr + pad * 0.3)) return false;
    if (nearRoad(x, z, pad)) return false;
    if (placed.some(([px, pz]) => Math.hypot(px - x, pz - z) < gap)) return false;
    placed.push([x, z]);
    return true;
  };
  // the waterline: reeds, lilies, mangroves in the shallows along every bank
  const banks = [];
  for (let i = 0; i < RIVER.length - 1; i++) banks.push([RIVER[i], RIVER[i + 1], (z) => RIVER_HW(z), 0.62]);
  for (let i = 0; i < CREEK.length - 1; i++) banks.push([CREEK[i], CREEK[i + 1], () => CREEK_HW, 0.8]); // (the creek is mostly mangroves)
  for (let i = 0; i < banks.length; i++) {
    const [[ax, az], [bx, bz], HW, mangroveOdds] = banks[i];
    const L = Math.hypot(bx - ax, bz - az);
    const nx = -(bz - az) / L, nz = (bx - ax) / L;
    for (let u = 0; u < L; u += 9 + R() * 6) {
      const cx = ax + (bx - ax) * (u / L), cz = az + (bz - az) * (u / L);
      const hw = HW(cz);
      for (const side of [-1, 1]) {
        const x = cx + nx * side * (hw - 2 + R() * 3), z = cz + nz * side * (hw - 2 + R() * 3);
        if (nearRoad(x, z, 4)) continue;
        const pick = R();
        if (pick < 0.45) reeds(V, [x, WATER_Y, z], 60000 + i * 100 + Math.floor(u));
        else if (pick < mangroveOdds && tryPlace(x, z, 6, 12)) mangrove(V, [x, WATER_Y, z], 11 + R() * 5, 61000 + i * 100 + Math.floor(u));
        else if (pick < 0.85) lily(V, [cx + nx * side * (hw * 0.55), 0, cz + nz * side * (hw * 0.55)], 62000 + i * 100 + Math.floor(u));
      }
    }
  }
  // road verges: tree ferns and ferns
  for (const sg of Object.values(segs)) {
    for (let s = 6; s < sg.cum[sg.cum.length - 1]; s += 13 + R() * 9) {
      for (const side of [-1, 1]) {
        if (R() < 0.3) continue;
        const f = at(sg.id, s, side * (sg.width / 2 + 5 + R() * 9));
        if (waterDepth(f.p[0], f.p[2]) > -3) continue;
        if (!tryPlace(f.p[0], f.p[2], 3, 7)) continue;
        const gy = hAt(f.p[0], f.p[2]);
        if (R() < 0.6) treeFern(V, [f.p[0], gy, f.p[2]], 6 + R() * 5, 20000 + placed.length);
        else E.fern(V, [f.p[0], gy, f.p[2]], 1.4 + R() * 0.8, 20000 + placed.length);
      }
    }
  }
  // deep jungle on the land
  for (let k = 0; k < 5000 && placed.length < 760; k++) {
    const x = (R() - 0.5) * 2 * (BX - 25), z = BZ0 + 25 + R() * (BZ1 - BZ0 - 50);
    if (waterDepth(x, z) > -4) continue;
    const gy = hAt(x, z);
    if (gy < LAND - 0.1) continue;
    const big = R();
    if (big < 0.36) { if (tryPlace(x, z, 14, 15)) E.jungleTree(V, [x, gy, z], 18 + R() * 12, 21000 + k); }
    else if (big < 0.52) { if (tryPlace(x, z, 10, 12)) E.palm(V, [x, gy, z], 12 + R() * 7, 21000 + k); }
    else if (big < 0.68) { if (tryPlace(x, z, 6, 9)) treeFern(V, [x, gy, z], 7 + R() * 5, 21000 + k); }
    else if (big < 0.8) { if (tryPlace(x, z, 5, 7)) E.bush(V, [x, gy, z], 1 + R() * 0.8, 21000 + k, { berries: R() > 0.7 ? '#ff5a7a' : undefined }); }
    else if (big < 0.88) { if (tryPlace(x, z, 5, 8)) E.rock(V, [x, gy, z], 1.2 + R() * 1.6, 21000 + k); }
    else if (tryPlace(x, z, 3, 6)) E.flowers(V, [x, gy, z], 21000 + k, { n: 6, spread: 4 });
  }

  // keep the rover's lane clear: decor in the way is removed, anything else is reported for a fix
  {
    const lanes = [];
    for (const sg of Object.values(segs)) for (const p of sg.samples) lanes.push({ x: p[0] + SR_ORIGIN[0], z: p[2] + SR_ORIGIN[2], y: ROAD + p[1], hw: sg.width / 2 });
    const rc = require('./mapqc.js').clearRoad(root, lanes);
    console.log(`                   road clearance: removed ${rc.removed}, blocking ${rc.report.length}`);
    const byName = {};
    for (const r of rc.report) { const k = r.split(' @ ')[0]; (byName[k] = byName[k] || []).push(r.split(' @ ')[1]); }
    for (const [k, v] of Object.entries(byName)) console.log(`                     ! ${k} x${v.length}  e.g. ${v[0]}`);
  }
  const data = routeData(route, at);
  root.attr('Length', +route.variants[0].length.toFixed(1));
  return { model: root, route, data };
}

// ------------------------------------------------------------------ land heightfield
function land(Z, segs, at, wet) {
  const CELL = 12, STEP = 1.2;
  const N = noise2(7171);
  const fbm = (x, z) => 0.6 * N(x / 120, z / 120) + 0.3 * N(x / 50 + 31, z / 50 - 17) + 0.1 * N(x / 21 - 7, z / 21 + 5);
  const road = [];
  for (const sg of Object.values(segs)) sg.samples.forEach((p, i) => { if (i % 2 === 0) road.push([p[0], p[2], sg.width / 2, Math.max(p[1], LAND), wet(p)]); });
  const nearestRoad = (x, z) => {
    let best = Infinity, y = LAND, w = false;
    for (const [px, pz, hw, py, pw] of road) { const d = Math.hypot(x - px, z - pz) - hw; if (d < best) { best = d; y = py; w = pw; } }
    return [best, y, w];
  };
  const circles = [];
  const addAt = (seg, s, x, r) => { const f = at(seg, s, x); circles.push([f.p[0], f.p[2], r]); };
  addAt('JungleRoad', 0, 0, 50); addAt('JungleRoad', 0, 24, 26);
  addAt('Homestretch', 1e9, 0, 40);
  for (const n of NESTS) addAt(n.seg, n.s, n.x, 32);
  addAt('CliffFalls', 165, 0, 46);
  const openness = (x, z) => {
    let k = 1;
    for (const [cx, cz, r] of circles) k = Math.min(k, smooth(r, r + 24, Math.hypot(x - cx, z - cz)));
    return k;
  };
  // big jungle hills inland: shapes you can name from the road
  const BUMPS = [[-330, 40, 34, 60], [-120, 250, 26, 64], [60, 330, 22, 50], [380, 60, 20, 46], [-280, -170, 30, 52]];
  const bump = (x, z) => BUMPS.reduce((acc, [bx, bz, A, r]) => acc + A * Math.exp(-((x - bx) ** 2 + (z - bz) ** 2) / (r * r)), 0);
  const heights = new Map();
  const key = (i, j) => i + ',' + j;
  const G = Z.group('Hills', 'Folder');
  const cells = [];
  for (let x0 = -BX + CELL / 2; x0 < BX; x0 += CELL) {
    for (let z0 = BZ0 + CELL / 2; z0 < BZ1; z0 += CELL) {
      const i = Math.round(x0 / CELL), j = Math.round(z0 / CELL);
      const wd = waterDepth(x0, z0);
      const [d, ry, rw] = nearestRoad(x0, z0);
      // the ford and the sea lane keep their water; everywhere else the road raises a bank under it
      const underRoad = d < CELL * 0.75 + 1 && !rw;
      if (wd > 0 && !underRoad) { heights.set(key(i, j), -99); continue; }
      const edge = Math.min(x0 + BX, BX - x0, BZ1 - z0);
      // land: low muddy banks near water, jungle hills behind, rising to the cliffs
      let H = LAND + 4 * smooth(-2, -30, wd) + (26 * Math.max(0, fbm(x0, z0) + 0.1) + bump(x0, z0)) * smooth(-14, -60, wd) + 20 * (1 - smooth(10, 90, edge));
      const t = smooth(8, 46, d) * openness(x0, z0);
      let h = ry * (1 - smooth(8, 46, d)) + H * t;
      h = Math.max(LAND, h);
      h = h < 16 ? Math.floor(h / STEP) * STEP : 16 + Math.floor((h - 16) / 3.6) * 3.6;
      if (h < LAND) h = LAND;
      if (d < CELL * 0.75 + 1) h = Math.min(h, Math.max(LAND - 0.2, Math.floor((ry - 0.5) / STEP) * STEP));
      heights.set(key(i, j), h);
      const top = 1.2;
      const tone = Math.floor((N(x0 / 80 - 13, z0 / 80 + 7) + 1) * 2) % 4;
      const shoreline = wd > -7;
      cells.push({ i, j, x: x0, z: z0, h: h - BED_Y, top, topC: shoreline ? (tone % 2 ? P.sand : P.sandLo) : (h > 20 ? P.grassHi[tone % 3] : P.grass[tone]), sideC: h > 20 ? P.cliff[Math.floor(h / 7.2) % 4] : P.mud, sideM: h > 20 ? 'Slate' : 'Sand' });
    }
  }
  const parts = E.heightfield(G, cells, CELL, { ground: BED_Y });
  const OR = rng(6262);
  const tors = Z.group('Outcrops');
  for (const c of cells) {
    if (c.h + BED_Y < 22 || OR() > 0.06) continue;
    E.rock(tors, [c.x + (OR() - 0.5) * 6, c.h + BED_Y, c.z + (OR() - 0.5) * 6], 2 + OR() * 1.6, 6300 + c.i * 97 + c.j, { colors: P.cliff });
  }
  const cellOf = (v, lo) => Math.round((lo + CELL / 2 + Math.floor((v - lo) / CELL) * CELL) / CELL);
  const hAt = (x, z) => { const h = heights.get(key(cellOf(x, -BX), cellOf(z, BZ0))); return h === undefined || h < -50 ? WATER_Y : h; };
  console.log('                   land: ' + cells.length + ' columns -> ' + parts + ' parts');
  return { hAt };
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
    F.beam([ax, ay, 0], [bx, by, 0], 3.6, 3, { name: 'PortalBeam', c: '#4e5a5a', m: 'Slate', studs: 'top', extend: 1, up: [0, 0, 1] });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNode', s: [4.4, 4.4, 4.8], c: '#2b2d31', m: 'Metal', studs: 'all' });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNodeCore', s: [2, 2, 5], c: o.color || '#3fe0c8', m: 'Neon' }).tag('GateNode');
  }
  const rm = Rr - 2.2, apo = rm * Math.sin(Math.PI / 3);
  for (let k = 0; k < 3; k++) F.box({ name: 'Membrane', s: [rm, 2 * apo, 0.3], r: [0, 0, k * 60], c: o.color || '#2fb8b0', m: 'Neon', t: 0.55, shadow: false }).tag('PortalSurface');
  for (let k = 0; k < 3; k++) F.box({ name: 'Core', s: [rm * 0.5, 2 * apo * 0.5, 0.35], r: [0, 0, k * 60], c: '#d8f4ff', m: 'Neon', t: 0.55, shadow: false }).tag('PortalCore');
  const host = F.box({ name: 'PortalLightHost', s: [1, 1, 1], t: 1, shadow: false });
  E.pointLight(host, [0.5, 0.9, 1], 40, 1.2);
  E.particles(host, 'Swirl', { rate: 18, life: [0.8, 1.6], speed: [5, 12], spread: [80, 80], dir: 5, size: [[0, 0.5], [1, 0]], color: [[0, [0.8, 1, 1]], [1, [0.3, 0.8, 0.8]]], emission: 0.6 });
  for (const side of [-1, 1]) c.box({ name: 'Plinth', s: [6, 3, 7], p: [side * (Rr + 6), 1.5, 0], c: '#6a6a5e', m: 'Slate', studs: 'top', collide: true });
  return g;
}

function buildArrival(Z, at) {
  const f = at('JungleRoad', 0);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  hexPortal(Z, [f.p[0], LAND, f.p[2] + 6], yaw, 14, 'ArrivalPortal');
  const c = Z.at([f.p[0] - 26, LAND, f.p[2] - 20], [0, -20, 0]);
  c.box({ name: 'TentFloor', s: [10, 0.3, 8], p: [0, 0.15, 0], c: '#6e5034' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, -2], face: 'front', c: '#5fb0b8' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, 2], face: 'back', c: '#4f9aa2' });
  E.crate(c, [-6.5, 0.3, 1], 1, { yaw: -14, stencil: '#2f6b8a' });
  E.barrel(c, [-6.5, 0.3, -2.5], { color: '#2f6b8a' });
  E.signBoard(c, [7, 4, -3], 7, 2, 'SPINE RIVER', { r: [0, 30, 0], color: '#e0fbff', color2: '#3fc8d8', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [7, 2, -2.7], c: E.PAL.woodLo });
  E.lampPost(c, [4, 0.3, 4], { h: 6 });
}

function buildReturnPortal(Z, at) {
  const f = at('Homestretch', 1e9);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  hexPortal(Z, [f.p[0] - f.f[0] * 14, LAND, f.p[2] - f.f[2] * 14] /* 14 back from the end: you drive through it before the warp (extract at L-8) */, yaw, 15, 'ReturnPortal', { color: '#ffb02e' });
}

function buildFord(Z, segs, at, R) {
  // THE FORD: stepping stones and a marker post either side, spray as the rover ploughs through
  const g = Z.group('TheFord');
  for (const s of [70, 190]) {
    const f = at('TheFord', s, 15);
    const c = g.at([f.p[0], LAND, f.p[2]]);
    c.box({ name: 'FordPost', s: [0.8, 7, 0.8], p: [0, 2.5, 0], c: P.wood });
    for (let k = 0; k < 4; k++) c.box({ name: 'FordStripe', s: [0.85, 0.6, 0.85], p: [0, 1 + k * 1.4, 0], c: k % 2 ? '#e8473a' : '#ffffff' });
  }
  for (let k = 0; k < 9; k++) {
    const f = at('TheFord', 96 + k * 7, -23 - (k % 2) * 2);
    g.box({ name: 'SteppingStone', s: [3 + R(), 1.2, 3 + R()], p: [f.p[0], WATER_Y + 0.3, f.p[2]], r: [0, R() * 90, 0], c: P.rock[k % 4], m: 'Slate', studs: 'top', collide: true });
  }
  const mid = at('TheFord', 130);
  const sp = g.box({ name: 'SplashHost', s: [24, 1, 18], p: [mid.p[0], WATER_Y + 0.4, mid.p[2]], t: 1, shadow: false });
  sp.set('CanQuery', 'bool', false);
  E.signBoard(g.at([at('TheFord', 40, 21).p[0], LAND, at('TheFord', 40, 21).p[2]], [0, E.deg(Math.atan2(-at('TheFord', 40).f[0], -at('TheFord', 40).f[2])), 0]), [0, 4, 0], 6, 1.6, 'THE FORD', { color: '#e0fbff', color2: '#3fc8d8', twoSided: true, pps: 30 });
}

function buildVineBridge(Z, segs, at, R) {
  // VINE BRIDGE: a plank deck on log pylons over the river, rope rails hung with vines
  const g = Z.group('VineBridge');
  const sg = segs.VineBridge;
  for (let s = 100; s <= 210; s += 11) {
    const f = at('VineBridge', s);
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    const c = g.at([f.base[0], 0, f.base[2]], [0, yaw, 0]);
    const top = f.base[1] + ROAD - 0.6;
    for (const side of [-1, 1]) {
      c.cyl({ name: 'BridgePile', axis: 'y', len: top - BED_Y, d: 1.6, p: [side * (sg.width / 2 + 1.2), (top + BED_Y) / 2, 0], c: P.woodLo, collide: true });
      c.box({ name: 'RailPost', s: [0.6, 3.4, 0.6], p: [side * (sg.width / 2 + 1.2), top + 2.1, 0], c: P.wood });
      c.box({ name: 'Vine', s: [0.3, 2 + R() * 3, 0.3], p: [side * (sg.width / 2 + 1.4), top - 1, (R() - 0.5) * 2], c: '#3a7a2a', shadow: false });
    }
    c.box({ name: 'CrossBeam', s: [sg.width + 3.4, 1, 1], p: [0, top - 0.6, 0], c: P.woodLo });
  }
  for (const side of [-1, 1]) {
    const pts = [];
    for (let s = 100; s <= 210; s += 11) { const f = at('VineBridge', s, side * (sg.width / 2 + 1.2)); pts.push([f.p[0], f.base[1] + ROAD + 3.2, f.p[2]]); }
    for (let k = 0; k < pts.length - 1; k++) g.beam(pts[k], pts[k + 1], 0.35, 0.35, { name: 'RopeRail', c: P.rope });
  }
}

function buildSeaLane(Z, segs, at, R) {
  // the Sea Lane: buoys mark the boat route along the coast; the bank ramps where the rover goes in and comes out
  const g = Z.group('SeaLane');
  for (let s = 340; s < 640; s += 26) {
    for (const side of [-1, 1]) {
      const f = at('SpineBend', s, side * 17);
      const c = g.at([f.p[0], WATER_Y, f.p[2]]);
      c.cyl({ name: 'Buoy', axis: 'y', len: 2.2, d: 1.8, p: [0, 0.6, 0], c: side > 0 ? '#e8473a' : '#f2c230' });
      c.box({ name: 'BuoyCap', s: [0.6, 1.4, 0.6], p: [0, 2.2, 0], c: '#ffffff' });
    }
  }
  for (const s of [318, 650]) {
    const f = at('SpineBend', s);
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    const c = g.at([f.base[0], 0, f.base[2]], [0, yaw, 0]);
    c.box({ name: 'Slipway', s: [30, 0.8, 26], p: [0, -0.9, 0], r: [s < 400 ? 6 : -6, 0, 0], c: '#8a8270', m: 'Pebble', collide: true });
  }
}

function buildCliffFalls(Z, segs, at, R, gaps) {
  const g = Z.group('CliffFalls');
  const sg = segs.CliffFalls;
  const L = sg.cum[sg.cum.length - 1];
  const inGap = (s) => gaps.some(([a, b]) => s > a - 2 && s < b + 2);
  for (let s = 0; s < L; s += 6) {
    const f = at('CliffFalls', s);
    if (f.base[1] < LAND + 1 || inGap(s)) continue;
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    g.at([f.base[0], BED_Y, f.base[2]], [0, yaw, 0]).box({ name: 'Shelf', s: [sg.width + 6, f.base[1] + ROAD - BED_Y - 0.4, 7], p: [0, (f.base[1] + ROAD - BED_Y - 0.4) / 2, 0], c: P.cliff[Math.floor(s / 6) % 4], m: 'Slate', collide: true });
  }
  for (const [a, b] of gaps) {
    const fa = at('CliffFalls', a), fb = at('CliffFalls', b), fm = at('CliffFalls', (a + b) / 2);
    for (const [fr, dir] of [[fa, 1], [fb, -1]]) {
      const yw = E.deg(Math.atan2(-fr.f[0], -fr.f[2]));
      g.at([fr.base[0], ROAD + fr.base[1], fr.base[2]], [0, yw, 0]).box({ name: 'JumpLip', s: [sg.width, 0.8, 1.6], p: [0, 0.1, -dir * 0.4], c: '#f2c230', studs: 'top' });
    }
    // the falls: a curtain pouring down the gorge you jump over
    const yaw = E.deg(Math.atan2(-fm.f[0], -fm.f[2]));
    const c = g.at([fm.base[0], 0, fm.base[2]], [0, yaw, 0]);
    E.waterfall(c, [sg.width / 2 + 38, 34, 0], 16, 34, { yaw: -90, seed: 71001, name: 'GorgeFalls' });
    E.cliffWall(c, [[sg.width / 2 + 42, 22], [sg.width / 2 + 42, -22]], { h: 40, d: 22, seed: 71002, slope: 3, chunk: 11, name: 'FallsCliff', trees: true, colors: P.cliff });
  }
}

// ------------------------------------------------------------------ THE SEA MOUTH (the ruler's den)
// A round bay where the river meets the sea. The research team built a ring of docks here; the Mosasaurus wrecked
// most of it. Eight dock platforms on pilings ring open water; walkways join them (some broken, so you jump);
// a long pier runs in from the road. The Mosasaurus fights from the water in the middle: every DockSection can be
// smashed (server sets Broken; the client splinters it). "Throne" is a flat rock just under the surface in the
// middle so ruler cameras find the spot it rises from.
function buildSeaMouth(Z, at, R, route) {
  const g = Z.group('SeaMouth');
  const f = at(DEN.seg, DEN.s, DEN.x);
  const cx = BAY.x, cz = BAY.z;
  const toRoad = Math.atan2(-(at(DEN.seg, DEN.s, 0).p[0] - cx), -(at(DEN.seg, DEN.s, 0).p[2] - cz));
  const c = g.at([cx, 0, cz], [0, E.deg(toRoad), 0]); // local -Z points back at the road
  const DECK = 1.6; // dock deck height above the water
  const RING = 34; // dock ring radius
  const docks = g.group('Docks', 'Folder');
  const deck = (ctx, name, idx, s, p, yaw) => {
    const d = ctx.group(name);
    d.parent.tag('DockSection').attr('Index', idx);
    const dc = d.at(p, [0, yaw, 0]);
    for (let k = 0; k < Math.round(s[0] / 1.6); k++) {
      dc.box({ name: 'Plank', s: [1.5, 0.4, s[1]], p: [-s[0] / 2 + 0.8 + k * 1.6, DECK - 0.2, 0], r: [0, 0, (R() - 0.5) * 2], c: P.plank[(k + idx) % 3], m: 'WoodPlanks', collide: true });
    }
    for (const [x, z] of [[-s[0] / 2 + 0.6, -s[1] / 2 + 0.6], [s[0] / 2 - 0.6, -s[1] / 2 + 0.6], [-s[0] / 2 + 0.6, s[1] / 2 - 0.6], [s[0] / 2 - 0.6, s[1] / 2 - 0.6]]) {
      dc.cyl({ name: 'Piling', axis: 'y', len: DECK + 1.4 - BED_Y, d: 1.1, p: [x, (DECK + 1.4 + BED_Y) / 2, z], c: P.woodLo, collide: true });
    }
    dc.box({ name: 'DeckBeam', s: [s[0], 0.6, 0.8], p: [0, DECK - 0.7, -s[1] / 2 + 0.6], c: P.woodLo });
    dc.box({ name: 'DeckBeam', s: [s[0], 0.6, 0.8], p: [0, DECK - 0.7, s[1] / 2 - 0.6], c: P.woodLo });
    return dc;
  };
  // the ring: 8 square platforms, walkways between them (two are already gone)
  const N8 = 8;
  for (let k = 0; k < N8; k++) {
    const a = (k / N8) * Math.PI * 2;
    const px = Math.sin(a) * RING, pz = -Math.cos(a) * RING;
    const pc = deck(docks.at([cx, 0, cz], [0, E.deg(toRoad), 0]), 'DockPlatform' + (k + 1), k + 1, [11, 11], [px, 0, pz], -E.deg(a));
    // each platform carries something: crates, a winch, a lamp, a rope coil, a lookout
    const kind = k % 4;
    if (kind === 0) { E.crate(pc, [2.5, DECK, 2], 1, { yaw: 20, stencil: '#2f6b8a' }); E.crate(pc, [2.5, DECK + 2.2, 2], 0.8, { yaw: -10 }); }
    else if (kind === 1) { pc.cyl({ name: 'RopeCoil', axis: 'y', len: 0.8, d: 2.6, p: [-2, DECK + 0.4, 2], c: P.rope }); pc.box({ name: 'Bollard', s: [1, 1.4, 1], p: [3.6, DECK + 0.7, -3.6], c: '#3a3d42', m: 'Metal', collide: true }); }
    else if (kind === 2) { E.lampPost(pc, [3.8, DECK, 3.8], { h: 6 }); E.barrel(pc, [-3, DECK, 2.8], { color: '#2f6b8a' }); }
    else {
      // the harpoon station: where you'll want to stand
      pc.box({ name: 'WinchBase', s: [3, 1.6, 3], p: [0, DECK + 0.8, 2.6], c: '#3a3d42', m: 'Metal', collide: true });
      pc.cyl({ name: 'WinchDrum', axis: 'x', len: 2.6, d: 1.6, p: [0, DECK + 2.2, 2.6], c: P.rust, m: 'Metal' });
    }
    // walkway to the next platform (skip two: they're smashed - jump the gap or swim)
    if (k === 2 || k === 5) {
      const b = (k + 0.5) / N8 * Math.PI * 2;
      for (let j = 0; j < 4; j++) docks.box({ name: 'BrokenPlank', s: [1.4, 0.3, 3 + R() * 2], p: [cx + Math.sin(b) * (RING + (R() - 0.5) * 6), WATER_Y + 0.15, cz - Math.cos(b) * (RING + (R() - 0.5) * 6)], r: [0, R() * 180, (R() - 0.5) * 20], c: P.plank[j % 3], m: 'WoodPlanks' });
      continue;
    }
    const a2 = ((k + 1) / N8) * Math.PI * 2;
    const ax = Math.sin(a) * RING, az = -Math.cos(a) * RING, bx = Math.sin(a2) * RING, bz = -Math.cos(a2) * RING;
    const mx = (ax + bx) / 2, mz = (az + bz) / 2;
    const len = Math.hypot(bx - ax, bz - az) - 11;
    deck(docks.at([cx, 0, cz], [0, E.deg(toRoad), 0]), 'DockWalk' + (k + 1), 100 + k + 1, [len, 4.4], [mx, 0, mz], -E.deg(Math.atan2(bz - az, bx - ax)));
  }
  // the pier in from the road (platform 1 sits nearest the road at local -Z)
  {
    const pierLen = 84 - RING - 6 - 17; // ends a short hop from the bank (and clear of the road)
    deck(docks.at([cx, 0, cz], [0, E.deg(toRoad), 0]), 'Pier', 200, [5.5, pierLen], [0, 0, -RING - 5.5 - pierLen / 2], 0);
    const sc = c.at([7, DECK, -RING - 6 - pierLen + 2], [0, 180, 0]);
    E.signBoard(sc, [0, 4.4, 0], 9, 2.2, 'THE SEA MOUTH', { color: '#e0fbff', color2: '#2f8fc8', twoSided: true, pps: 30, trim: '#2f8fc8' });
    sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: P.woodLo });
    sc.box({ name: 'WarningPlate', s: [3.4, 1.4, 0.2], p: [0, 1.8, -0.2], c: P.hazard });
  }
  // the wreck of the research boat, half sunk against the far side of the ring
  {
    const w = c.at([-50, 0, 26], [0, 34, 0]);
    w.box({ name: 'Hull', s: [7, 4, 18], p: [0, -0.6, 0], r: [0, 0, 22], c: P.paint, m: 'WoodPlanks' });
    w.box({ name: 'HullStripe', s: [7.2, 0.8, 18.2], p: [0, 0.6, 0], r: [0, 0, 22], c: '#2f6b8a' });
    w.box({ name: 'Cabin', s: [5, 3.4, 6], p: [-1, 2.4, 3], r: [0, 0, 22], c: '#e8e2d4' });
    w.box({ name: 'CabinWindow', s: [5.2, 1, 3], p: [-1, 3.2, 3], r: [0, 0, 22], c: '#9cd8f0', m: 'Glass', t: 0.3 });
    w.beam([-3, 0, -6], [-8, 8, -9], 0.5, 0.5, { name: 'Mast', c: P.woodLo });
    for (let k = 0; k < 5; k++) w.box({ name: 'BiteMark', s: [0.6, 2.4, 0.3], p: [3.6, -0.6, -4 + k * 1.4], r: [0, 0, 22], c: '#3a2a1e' });
  }
  // the rise point: a flat rock just under the surface in the middle (named Throne: ruler cameras use it)
  c.box({ name: 'Throne', s: [12, 1, 12], p: [0, WATER_Y - 3.2, 0], c: '#3e5a5a', m: 'Slate', collide: false });
  // sea stacks around the bay mouth (north), kelp, a glow under the water
  for (const [x, z, h] of [[-48, 46, 22], [46, 52, 30], [0, 70, 18]]) {
    const st = c.at([x, BED_Y, z]);
    const H = h - BED_Y;
    for (let t = 0; t < 4; t++) st.box({ name: 'StackRock', s: [9 - t * 1.4, H / 4 + 0.3, 8 - t * 1.2], p: [0, (t + 0.5) * (H / 4), 0], r: [0, t * 19, 0], c: P.cliff[t % 4], m: 'Slate', studs: 'top', collide: true });
  }
  for (let k = 0; k < 14; k++) {
    const a = R() * Math.PI * 2, r = 8 + R() * 18;
    const kh = 4 + R() * 5;
    c.box({ name: 'Kelp', s: [0.5, kh, 0.5], p: [Math.cos(a) * r, BED_Y + kh / 2, Math.sin(a) * r], r: [(R() - 0.5) * 10, 0, (R() - 0.5) * 10], c: '#3f7a4a', shadow: false });
  }
  const glow = c.box({ name: 'DeepGlow', s: [1, 1, 1], p: [0, -4, 0], t: 1, shadow: false });
  E.pointLight(glow, [0.4, 0.75, 1], 34, 0.8);
  // markers for the fight + the boat chase that follows
  const v0 = route.variants[0];
  const segS = (segId, s) => { const k = v0.segs.indexOf(segId); return k < 0 ? 0 : v0.segStart[k] + s; };
  const dc = marker(c, 'DenCenter', [0, DECK + 0.5, -RING], 0, { s: [2, 1, 2] });
  dc.attr('RouteS', +segS(DEN.seg, DEN.s).toFixed(1)).attr('RouteX', DEN.x).attr('Variant', 1).attr('Water', true);
  marker(c, 'BayCenter', [0, WATER_Y, 0], 0, { s: [2, 1, 2] }).attr('Radius', RING - 6);
  for (let k = 0; k < N8; k++) {
    const a = (k / N8) * Math.PI * 2;
    marker(c, 'DockSpot' + (k + 1), [Math.sin(a) * RING, DECK + 0.5, -Math.cos(a) * RING], 0, { s: [2, 1, 2] });
  }
  const ff = at(FINAL.seg, FINAL.s, FINAL.x);
  const fm = marker(Z, 'FinalArena', [ff.p[0], WATER_Y + 0.5, ff.p[2]], 0, { s: [2, 1, 2] });
  fm.attr('RouteS', +segS(FINAL.seg, FINAL.s).toFixed(1)).attr('RouteX', -6).attr('Variant', 1).attr('Water', true).attr('Inner', MAW.inner).attr('Outer', MAW.outer).attr('Top', MAW.top);
}


// THE MAW: the final stand. A ring of black rock out at sea, open water inside and out: the Mosasaurus circles it,
// breaches onto it, slams waves across it, and at the end spins a whirlpool in the middle and lunges out of it.
function buildMaw(Z, at, R) {
  const g = Z.group('TheMaw');
  const f = at(FINAL.seg, FINAL.s, FINAL.x);
  const road = at(FINAL.seg, FINAL.s, 0);
  const toRoad = Math.atan2(-(road.p[0] - f.p[0]), -(road.p[2] - f.p[2]));
  const c = g.at([f.p[0], 0, f.p[2]], [0, E.deg(toRoad), 0]); // local -Z points at the lane
  const N = 28;
  const rock = ['#3e4446', '#4a5052', '#35393b', '#565c5e'];
  for (let k = 0; k < N; k++) {
    const a = (k / N) * Math.PI * 2;
    const r = (MAW.inner + MAW.outer) / 2;
    const w = (2 * Math.PI * MAW.outer) / N + 1.2;
    const seg = c.at([Math.sin(a) * r, 0, -Math.cos(a) * r], [0, -E.deg(a), 0]);
    seg.box({ name: 'MawRock', s: [w, MAW.top - BED_Y, MAW.outer - MAW.inner], p: [0, (MAW.top + BED_Y) / 2 - 0.6, 0], c: rock[k % 4], m: 'Slate', collide: true });
    seg.box({ name: 'MawTop', s: [w * 0.98, 1.2, MAW.outer - MAW.inner - 0.6], p: [0, MAW.top - 0.6, 0], c: k % 3 ? '#5a6062' : '#4e6a5a', m: 'Slate', studs: 'top', collide: true });
    // teeth: jagged spires on the outer lip, a gap every few so you can see out (and the lane side stays open)
    if (k % 3 === 0 && Math.abs(Math.sin(a / 2)) > 0.3) {
      const h = 7 + R() * 9;
      seg.box({ name: 'MawTooth', s: [2.6, h, 3], p: [0, MAW.top + h / 2 - 0.6, (MAW.outer - MAW.inner) / 2 - 2], r: [-14, 0, (R() - 0.5) * 12], c: rock[(k + 1) % 4], m: 'Slate', studs: 'top', collide: true });
    }
    if (R() > 0.6) seg.box({ name: 'Barnacles', s: [w * 0.6, 0.5, 1.4], p: [0, MAW.top - 0.1, -(MAW.outer - MAW.inner) / 2 + 1.2], c: '#d8d0b8', shadow: false });
  }
  // where people are put down on the ring (the rover pulls up right alongside it on the lane)
  for (let k = 0; k < 6; k++) {
    const a = (k / 6) * Math.PI * 2 + Math.PI / 6;
    const r = (MAW.inner + MAW.outer) / 2;
    marker(c, 'MawSpot' + (k + 1), [Math.sin(a) * r, MAW.top + 0.5, -Math.cos(a) * r], 0, { s: [2, 1, 2] });
  }
  // the pool in the middle: kelp, a glow far down
  for (let k = 0; k < 8; k++) { const a = R() * 6.28, r = R() * 10; const kh = 5 + R() * 4; c.box({ name: 'Kelp', s: [0.5, kh, 0.5], p: [Math.cos(a) * r, BED_Y + kh / 2, Math.sin(a) * r], c: '#3f7a4a', shadow: false }); }
  const glow = c.box({ name: 'MawGlow', s: [1, 1, 1], p: [0, -5, 0], t: 1, shadow: false });
  E.pointLight(glow, [0.35, 0.7, 1], 30, 0.7);
  const sc = c.at([4, MAW.top, -MAW.outer - 3], [0, 180, 0]);
  E.signBoard(sc, [0, 4, 0], 7, 2, 'THE MAW', { color: '#e0fbff', color2: '#2f8fc8', twoSided: true, pps: 30, trim: '#2f8fc8' });
  sc.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: P.woodLo });
}

function buildCinematics(Z, at) {
  const g = Z.group('Cinematics', 'Folder');
  const shot = (name, pos, look) => {
    const l = Z.wpt(look);
    const m = marker(g, name, pos, 0, { s: [1, 1, 1] });
    m.attr('LookX', +l[0].toFixed(2)).attr('LookY', +l[1].toFixed(2)).attr('LookZ', +l[2].toFixed(2));
    return m;
  };
  const bank = at(NESTS[0].seg, NESTS[0].s, NESTS[0].x);
  const ford = at('TheFord', 130);
  shot('EstShot1', [-200, 90, 420], [40, 10, -60]); // the whole delta from above the arrival, out to the sea
  shot('EstShot2', [ford.p[0] - 50, 10, ford.p[2] + 40], [ford.p[0], 2, ford.p[2]]); // the ford
  shot('EstShot3', [bank.p[0] - 40, 14, bank.p[2] - 40], [bank.p[0], 4, bank.p[2]]); // the fishing bank
  shot('EstShot4', [BAY.x + 90, 30, BAY.z + 60], [BAY.x, 2, BAY.z]); // the Sea Mouth docks
}

function buildNestSite(Z, n, at, R, hAt) {
  const f = at(n.seg, n.s, n.x);
  const gy = Math.max(LAND, hAt(f.p[0], f.p[2]));
  const g = Z.group('Nest_' + n.species);
  g.parent.attr('NestId', n.id).attr('Species', n.species).tag('ExpeditionNest');
  const c = g.at([f.p[0], gy, f.p[2]], [0, R() * 360, 0]);
  c.cyl({ name: 'Clearing', axis: 'y', len: 0.1, d: 24, p: [0, 0.05, 0], c: P.sandLo, m: 'Sand', shadow: false });
  // a river nest: a ring of driftwood and reeds on a sand bank
  c.cyl({ name: 'NestMound', axis: 'y', len: 1, d: 9, p: [0, 0.5, 0], c: P.sand, m: 'Sand' });
  for (let k = 0; k < 14; k++) {
    const a = (k / 14) * Math.PI * 2;
    c.box({ name: 'NestTwig', s: [2.8, 0.6, 0.8], p: [Math.cos(a) * 4.2, 0.9 + (k % 2) * 0.3, Math.sin(a) * 4.2], r: [R() * 20, -E.deg(a) + 90, R() * 15], c: k % 3 ? '#9a8a74' : '#8a7a64' });
  }
  for (let k = 0; k < 3; k++) {
    let egg;
    egg = buildEgg(EGG_SPECIES[n.species] ? n.species : 'Spinosaurus'); // (until that species exists)
    B.scaleTree(egg, 0.62);
    const a = (k / 3) * Math.PI * 2;
    B.transformTree(egg, c.frame.mul(new CF(Math.cos(a) * 1.3, 1.2, Math.sin(a) * 1.3)).mul(CF.deg(0, k * 40, (k - 1) * 8)));
    egg.tags = [];
    egg.name = 'NestEgg';
    g.parent.add(egg);
  }
  // (2026-10-13: the flag stood right on GuardSpot1 - the first guard (a raptor) was impaled on its pole in every
  // scene. Now midway between two guard spots, outside the guard ring and the clearing)
  E.flag(c, [0.37, 0, 16], '#3fc8d8', { h: 7 });
  const sgn = Z.at([f.base[0] - f.r[0] * (n.x > 0 ? -21 : 21), Math.max(LAND, f.base[1]), f.base[2] - f.r[2] * (n.x > 0 ? -21 : 21)], [0, E.deg(Math.atan2(-f.f[0], -f.f[2])) + 180, 0]);
  E.signBoard(sgn, [0, 4.2, 0], 7, 2.2, n.label, { color: '#e0fbff', color2: '#2f8fc8', twoSided: true, pps: 30, trim: '#2f8fc8' });
  sgn.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
  for (let k = 0; k < 3; k++) {
    const a = (k / 3) * Math.PI * 2 + 0.5;
    const m = c.box({ name: 'GuardSpot' + (k + 1), s: [1.5, 1, 1.5], p: [Math.cos(a) * 10, 0.5, Math.sin(a) * 10], r: [0, -E.deg(a) - 90, 0], t: 1, shadow: false });
    m.set('CanQuery', 'bool', false);
  }
  const host = c.box({ name: 'NestCore', s: [2, 2, 2], p: [0, 1.8, 0], t: 1, shadow: false });
  host.set('CanQuery', 'bool', false);
  const pr = new Inst('ProximityPrompt', 'GrabPrompt');
  pr.set('ActionText', 'string', 'Grab Egg').set('ObjectText', 'string', n.label).set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 10).set('HoldDuration', 'float', 1.6).set('RequiresLineOfSight', 'bool', false).set('Exclusivity', 'token', 1);
  pr.attr('NestId', n.id);
  host.add(pr);
  E.particles(host, 'NestGlint', { rate: 3, life: [0.8, 1.4], speed: [0.5, 1], size: [[0, 0.5], [1, 0]], color: [1, 0.95, 0.6], emission: 1 });
  E.pointLight(host, [1, 0.82, 0.5], 18, 0.8);
  for (let k = 0; k < 5; k++) {
    const a = (k / 5) * Math.PI * 2 + 0.9;
    const x = Math.cos(a) * 15, z = Math.sin(a) * 15;
    if (k % 2) E.rock(c, [x, 0, z], 1.6 + R(), 85000 + n.id * 10 + k);
    else reeds(c, [x, 0, z], 85100 + n.id * 10 + k, 8);
  }
}

// ------------------------------------------------------------------ Luau data
function routeData(route, at) {
  const O = SR_ORIGIN;
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
    return { Id: n.id, Species: n.species, Guard: n.guard, Label: n.label, S: perVariant(n.seg, n.s), X: n.x, Pos: [+(f.p[0] + O[0]).toFixed(2), LAND + O[1], +(f.p[2] + O[2]).toFixed(2)] };
  });
  // water stretches of every variant: [s0, s1] where the rover floats (the client dresses it as a boat there)
  const water = V.map((v) => {
    const out = [];
    let start = null;
    for (let i = 0; i < v.pts.length; i++) {
      const w = v.pts[i][1] < WATER_Y - 0.6;
      if (w && start === null) start = i * RT.STEP;
      if (!w && start !== null) { out.push([+start.toFixed(1), +(i * RT.STEP).toFixed(1)]); start = null; }
    }
    if (start !== null) out.push([+start.toFixed(1), +v.length.toFixed(1)]);
    return out;
  });
  const arrival = at('JungleRoad', 4);
  return {
    Zone: 'SpineRiver', Name: 'SPINE RIVER', Era: '97,000,000 BC', Year: -97000000,
    Variants: variants, Forks: forks, Features: features, Sections: sections, Nests: nests, Water: water, WaterY: WATER_Y + O[1],
    Arrival: [arrival.p[0] + O[0], arrival.p[1] + ROAD, arrival.p[2] + O[2], arrival.f[0], arrival.f[2]],
  };
}

module.exports = { buildSpineRiver, SR_ORIGIN, WATER_Y };
