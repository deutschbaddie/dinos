// GIANT PLAINS — the second era (150,000,000 BC). Golden Jurassic grassland under huge skies: mesas, giant
// sequoias, a salt flat, and the Bone Yard where the Plains Titan (Giganotosaurus) rules.
//   Golden Road (long straight through a sauropod ribcage) → fork: Salt Flats (Tall Grove oasis, Brachiosaurus)
//   | Mesa Pass → Plate Ridge (Stegosaurus) → climb the ridge → descend Bone Gulch (the Bone Yard opens off the
//   right) → the Great Herds (Sunset Stones, Club Hollow / Ankylosaurus) → fork: Spine Ridge (jump) | Grove Trail
//   → Homestretch → Return Portal. The Old Giant sequoia stands in the middle of it all.
//   Zone-local space: origin = GP_ORIGIN, north = -Z. (2026-10-11: new layout; it used to be Fern Valley mirrored.)
const { Inst, Ctx, CF, shade, rng } = require('./builder.js');
const E = require('./env.js');
const RT = require('./route.js');
const NPC = require('./npcs.js');
const { buildEgg } = require('./eggs.js');
const B = require('./builder.js');

const GP_ORIGIN = [-700, 0, -900];
const GROUND = 0.5, ROAD = 0.62;
const P = {
  grass: ['#cdb55a', '#d6bf63', '#c2a94f', '#dcc76e'], grassDk: '#b39b45',
  dirt: '#b97a4a', dirtLo: '#9a6038', dirtHi: '#cf9563', mud: '#7a5232', crack: '#5e3c24',
  mesa: ['#c8693a', '#b85a30', '#d97c45', '#a64e2a', '#e0915a'], mesaTop: '#d9a25a',
  sand: '#e2c48a', bone: '#efe2c4', boneLo: '#e3d4b0',
  conifer: ['#3f6a34', '#4a7a3a', '#365e2e'], cycad: ['#5a8a3a', '#6a9a42', '#4e7e34'],
  bark: ['#8a4a2a', '#7a3e22', '#9a5634'], water: '#4fb0c8',
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
    GoldenRoad: { from: 'Arrival', to: 'ForkA', width: 28, name: 'GOLDEN ROAD', pts: [[0, 0, 340], [0, 1, 260], [4, 3, 180], [-6, 2, 110], [-40, 0, 60]] },
    SaltFlats: { from: 'ForkA', to: 'MergeA', width: 30, name: 'SALT FLATS', pts: [[-40, 0, 60], [-100, 0, 76], [-175, 0, 58], [-228, 0, 4], [-246, 0, -66]] },
    MesaPass: { from: 'ForkA', to: 'MergeA', width: 20, name: 'MESA PASS', pts: [[-40, 0, 60], [-62, 4, 4], [-112, 10, -36], [-182, 6, -66], [-246, 0, -66]] },
    Plains: {
      from: 'MergeA', to: 'ForkB', width: 28, name: 'PLATE RIDGE',
      pts: [[-246, 0, -66], [-276, 2, -128], [-246, 8, -188], [-170, 14, -214], [-92, 6, -214], [-20, 1, -196], [60, 0, -172], [140, 0, -152], [214, 0, -112], [262, 0, -44]],
    },
    SpineRidge: { from: 'ForkB', to: 'MergeB', width: 22, name: 'SPINE RIDGE', pts: [[262, 0, -44], [302, 4, 12], [318, 14, 80], [300, 17, 140], [250, 6, 176], [196, 0, 196]] },
    GroveTrail: { from: 'ForkB', to: 'MergeB', width: 22, name: 'GROVE TRAIL', pts: [[262, 0, -44], [226, 0, 24], [196, 0, 86], [176, 0, 146], [196, 0, 196]] },
    Homestretch: { from: 'MergeB', to: 'Exit', width: 28, name: 'HOMESTRETCH', pts: [[196, 0, 196], [226, 0, 244], [270, 2, 278], [318, 1, 300], [352, 0, 330]] },
  },
};

const SECTIONS = [
  ['GoldenRoad', 0, 'GOLDEN ROAD'], ['SaltFlats', 0, 'SALT FLATS'], ['MesaPass', 0, 'MESA PASS'],
  ['Plains', 0, 'PLATE RIDGE'], ['Plains', 250, 'BONE GULCH'], ['Plains', 470, 'THE GREAT HERDS'],
  ['SpineRidge', 0, 'SPINE RIDGE'], ['GroveTrail', 0, 'GROVE TRAIL'], ['Homestretch', 0, 'HOMESTRETCH'],
];
const NESTS = [
  { id: 1, species: 'Stegosaurus', seg: 'Plains', s: 70, x: 26, guard: 'Brute', label: 'PLATE RIDGE' },
  { id: 2, species: 'Ankylosaurus', seg: 'Plains', s: 560, x: -30, guard: 'Brute', label: 'CLUB HOLLOW' },
  { id: 3, species: 'Brachiosaurus', seg: 'SaltFlats', s: 150, x: -34, guard: 'Brute', label: 'TALL GROVE' },
];
const FEATURES = [
  ['Darts', 'GoldenRoad', 215, 6], ['Darts', 'Plains', 105, -7], ['Darts', 'Plains', 430, 0], ['Darts', 'SpineRidge', 70, 0], ['Darts', 'GroveTrail', 30, 0], ['Darts', 'Homestretch', 85, 6],
  // golden road: the long straight teaches boost
  ['Boost', 'GoldenRoad', 60, 0], ['Coin', 'GoldenRoad', 85, 6], ['Coin', 'GoldenRoad', 91, 6], ['Coin', 'GoldenRoad', 97, 6],
  ['Log', 'GoldenRoad', 150, -5, { w: 12 }], ['Boost', 'GoldenRoad', 175, 7], ['Coin', 'GoldenRoad', 195, -7], ['Coin', 'GoldenRoad', 201, -7], ['Repair', 'GoldenRoad', 250, -8],
  // salt flats: wide and fast, a few stranded boulders
  ['Coin', 'SaltFlats', 50, 7], ['Coin', 'SaltFlats', 56, 7], ['Boulder', 'SaltFlats', 100, 5, { w: 7 }], ['Coin', 'SaltFlats', 118, 0], ['Boulder', 'SaltFlats', 190, -6, { w: 7 }],
  ['Boost', 'SaltFlats', 215, 0], ['Coin', 'SaltFlats', 240, 6], ['Repair', 'SaltFlats', 262, 0],
  // mesa pass: hoodoo slalom on the high road
  ['Pillar', 'MesaPass', 64, 4, { w: 6 }], ['Pillar', 'MesaPass', 109, -4, { w: 6 }], ['Pillar', 'MesaPass', 154, 4, { w: 6 }],
  ['Boost', 'MesaPass', 125, 5], ['Coin', 'MesaPass', 80, -5], ['Coin', 'MesaPass', 86, -5], ['Coin', 'MesaPass', 200, 0],
  // the ridge climb and the gulch descent: rockfall while the pack is on you
  ['Coin', 'Plains', 180, 0], ['Coin', 'Plains', 186, 0], ['Boulder', 'Plains', 270, -5, { w: 7 }], ['Coin', 'Plains', 290, 8], ['Boulder', 'Plains', 305, 6, { w: 7 }],
  ['Boost', 'Plains', 325, 0], ['Boulder', 'Plains', 360, -4, { w: 8 }], ['Coin', 'Plains', 372, -8], ['Repair', 'Plains', 390, 8], ['Boulder', 'Plains', 412, 4, { w: 7 }],
  // the great herds
  ['Boost', 'Plains', 520, -6], ['Coin', 'Plains', 540, 8], ['Coin', 'Plains', 546, 8], ['Charge', 'Plains', 610, 0, { len: 60 }], ['Repair', 'Plains', 675, 6],
  // spine ridge: the jump over the gorge
  ['Boost', 'SpineRidge', 120, 0], ['Jump', 'SpineRidge', 172, 0, { len: 34 }], ['Coin', 'SpineRidge', 186, 0], ['Coin', 'SpineRidge', 192, 0], ['Coin', 'SpineRidge', 198, 0],
  // grove trail: fallen conifers between the sequoias
  ['Log', 'GroveTrail', 50, 5, { w: 10 }], ['Log', 'GroveTrail', 95, -5, { w: 10 }], ['Pillar', 'GroveTrail', 140, 5, { w: 6 }],
  ['Repair', 'GroveTrail', 118, 0], ['Coin', 'GroveTrail', 70, 0], ['Coin', 'GroveTrail', 76, 0], ['Coin', 'GroveTrail', 160, 8],
  ['Stampede', 'Homestretch', 110, 0, { len: 50 }], ['Boost', 'Homestretch', 150, 0], ['Coin', 'Homestretch', 180, -6], ['Coin', 'Homestretch', 186, -6],
];
const OBSTACLE_TYPES = new Set(['Log', 'Branch', 'Boulder', 'Pillar']);
// 2026-10-11: no more logs / boulders / pillars on the road (they blocked the rover on travel drives); the
// entries above stay for reference but are dropped here, so neither the map nor the route data has them
for (let i = FEATURES.length - 1; i >= 0; i--) if (OBSTACLE_TYPES.has(FEATURES[i][0])) FEATURES.splice(i, 1);
// the Titan's Bone Yard (off the right of Bone Gulch), the final stand among the Sunset Stones, the Old Giant sequoia,
// the sauropod ribcage over the Golden Road, the salt flat and the oasis pool by the Tall Grove
const DEN = { seg: 'Plains', s: 340, x: 62 };
const FINAL = { seg: 'Plains', s: 500, x: 64 };
const OLD_GIANT = [118, 0, 70];
const RIBCAGE = { seg: 'GoldenRoad', s: 120 };
const FLATS = { seg: 'SaltFlats', s0: 18, s1: 136, half: 52 };
const OASIS = { seg: 'SaltFlats', s: 170, x: -70 };
// the herd's loop: a worn game trail that circles the Old Giant (Brachiosaurus walk it; client CampView.startMigration)
const MIGRATION = Array.from({ length: 18 }, (_, k) => { const a = (k / 18) * Math.PI * 2; return [110 + Math.cos(a) * 52, 0, 60 + Math.sin(a) * 72]; });
const BX = 420, BZ0 = -300, BZ1 = 400;
const ARID = { top: '#c9ae58', overhang: ['#5a8a3a', '#6a9a42', '#c2a94f'], vines: false, moss: false };

// ------------------------------------------------------------------ plants of the Jurassic
// monkey-puzzle conifer: tall bare trunk, tiers of stiff horizontal branches near the top
function araucaria(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('Araucaria');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = Math.max(4, Math.round(h / 3));
  for (let i = 0; i < n; i++) t.box({ name: 'ConiferTrunk', s: [1.4 - i * 0.04, 3.1, 1.4 - i * 0.04], p: [0, 1.5 + i * 3, 0], r: [0, i * 23, 0], c: P.bark[i % 3], studs: 'sides', collide: i === 0 });
  const tiers = 4;
  for (let k = 0; k < tiers; k++) {
    const y = h * 0.62 + k * (h * 0.38 / tiers);
    const L = 7 - k * 1.4;
    for (let j = 0; j < 5; j++) {
      const a = (j / 5) * 360 + k * 36;
      const b = t.at([0, y, 0], [0, a, 0]);
      b.box({ name: 'ConiferArm', s: [0.6, 0.6, L], p: [0, 0, -L / 2], r: [-6, 0, 0], c: P.bark[1] });
      b.box({ name: 'ConiferNeedles', s: [2.6, 1.3, L * 0.8], p: [0, 0.4, -L * 0.55], r: [-6, 0, 0], c: P.conifer[(j + k) % 3], studs: 'top' });
    }
  }
  t.box({ name: 'ConiferTop', s: [2.2, 2.4, 2.2], p: [0, h + 1, 0], c: P.conifer[0], studs: 'top' });
  return g;
}
// giant sequoia: a huge red trunk with buttress roots, a high blocky crown
function sequoia(ctx, p, h, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group('Sequoia');
  const t = g.at(p, [0, R() * 360, 0]);
  const w = o.w || 4.2;
  const n = Math.max(5, Math.round(h / 4));
  for (let i = 0; i < n; i++) t.box({ name: 'SequoiaTrunk', s: [w - i * 0.12, 4.1, w - i * 0.12], p: [0, 2 + i * 4, 0], r: [0, i * 11, 0], c: P.bark[i % 3], m: 'WoodPlanks', studs: 'sides', collide: i < 3 });
  for (let k = 0; k < 4; k++) t.at([0, 0, 0], [0, k * 90 + 20, 0]).wedgeF({ name: 'Buttress', s: [1.4, 3.6, 3], p: [0, 1.8, -w / 2 - 1.2], face: 'front', c: P.bark[0], collide: true });
  for (let k = 0; k < 7; k++) {
    const y = h * 0.66 + k * (h * 0.36 / 7);
    const r = (1 - k / 8) * (w * 1.6);
    t.box({ name: 'SequoiaCrown', s: [r * 2 + 3, 3.2, r * 2 + 3], p: [(R() - 0.5) * 2, y, (R() - 0.5) * 2], r: [0, k * 27, 0], c: P.conifer[k % 3], studs: 'top' });
  }
  return g;
}
// cycad: a stubby scaly trunk with a crown of stiff fronds (dino-era palm)
function cycad(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('Cycad');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = Math.max(1, Math.round(h / 1.6));
  for (let i = 0; i < n; i++) t.box({ name: 'CycadTrunk', s: [1.5, 1.7, 1.5], p: [0, 0.85 + i * 1.6, 0], r: [0, i * 45, 0], c: i % 2 ? '#7a5a36' : '#8a6a3e', studs: 'sides', collide: i === 0 });
  const top = t.at([0, n * 1.6 + 0.2, 0]);
  for (let i = 0; i < 6; i++) {
    const f = top.at([0, 0, 0], [0, i * 60 + R() * 10, 0]);
    f.box({ name: 'CycadFrond', s: [0.9, 0.2, 4], p: [0, 0.8, -1.8], r: [34, 0, 0], c: P.cycad[i % 3], studs: 'top' });
    f.box({ name: 'CycadFrondTip', s: [0.7, 0.18, 2.4], p: [0, 1.6, -4.4], r: [8, 0, 0], c: P.cycad[(i + 1) % 3] });
  }
  top.box({ name: 'CycadCone', s: [1, 1.4, 1], p: [0, 0.7, 0], c: '#d9a23a' });
  return g;
}
// a layered sandstone mesa (or a smaller butte / hoodoo)
function mesa(ctx, p, w, d, h, seed, name = 'Mesa') {
  const R = rng(seed);
  const g = ctx.group(name);
  const t = g.at(p, [0, R() * 360, 0]);
  const layers = Math.max(3, Math.round(h / 6));
  for (let k = 0; k < layers; k++) {
    const shrink = 1 - (k / layers) * 0.18;
    t.box({ name: 'MesaLayer', s: [w * shrink + (R() - 0.5) * 3, h / layers + 0.2, d * shrink + (R() - 0.5) * 3], p: [(R() - 0.5) * 1.5, (k + 0.5) * (h / layers), (R() - 0.5) * 1.5], r: [0, (R() - 0.5) * 6, 0], c: P.mesa[k % 5], m: 'Slate', collide: true });
  }
  t.box({ name: 'MesaTop', s: [w * 0.8, 0.8, d * 0.8], p: [0, h + 0.4, 0], c: P.mesaTop, m: 'Slate', studs: 'top', collide: true });
  for (let k = 0; k < 3; k++) t.box({ name: 'MesaScrub', s: [2.5, 1.2, 2.5], p: [(R() - 0.5) * w * 0.6, h + 1.2, (R() - 0.5) * d * 0.6], c: P.cycad[k % 3], studs: 'top' });
  return g;
}
function hoodoo(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('Hoodoo');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = Math.max(3, Math.round(h / 3));
  for (let k = 0; k < n; k++) {
    const s = 3.2 - Math.sin((k / n) * Math.PI) * 0.9 + (R() - 0.5) * 0.4;
    t.box({ name: 'HoodooRock', s: [s, h / n + 0.15, s], p: [0, (k + 0.5) * (h / n), 0], r: [0, k * 19, (R() - 0.5) * 4], c: P.mesa[k % 5], m: 'Slate', studs: 'top', collide: k < 2 });
  }
  t.box({ name: 'HoodooCap', s: [4.4, 1.6, 4.4], p: [0, h + 0.8, 0], r: [0, 20, 4], c: '#8a5a3a', m: 'Slate', studs: 'top' });
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

function buildGiantPlains() {
  const route = RT.buildRoute(DEF);
  const root = new Inst('Model', 'GiantPlains');
  root.attr('Zone', 'GiantPlains');
  const Z = new Ctx({ parent: root, frame: new CF(...GP_ORIGIN), defaults: { anchored: true } });
  const R = rng(15015);
  const segs = route.segs;
  for (const s of Object.values(segs)) s.cum = RT.cumOf(s.samples);
  const at = (segId, s, x = 0, y = 0) => { const sg = segs[segId]; return RT.at(sg.samples, sg.cum, s, x, y); };
  const roadPts = [];
  for (const s of Object.values(segs)) for (const p of s.samples) roadPts.push([p[0], p[2], s.width / 2]);
  const nearRoad = (x, z, pad) => roadPts.some(([px, pz, hw]) => Math.hypot(x - px, z - pz) < hw + pad);
  const jumpRanges = {};
  for (const f of FEATURES) if (f[0] === 'Jump') (jumpRanges[f[1]] = jumpRanges[f[1]] || []).push([f[2] - f[4].len / 2, f[2] + f[4].len / 2]);
  for (const sg of Object.values(segs)) for (const p of sg.samples) p[1] = Math.max(0, p[1]);
  // (2026-10-14) at a fork or merge two roads lie over each other for a few dozen studs, and the one still climbing stood
  // up to 1.5 out of the other (Mesa Pass into the Salt Flats merge, Spine Ridge at both ends): every road stays at its
  // node's height through the ~34 studs the two overlap, then eases back to its own profile by 84. Heights only -
  // distances along the route don't move
  {
    const uses = {};
    for (const d of Object.values(DEF.segments)) for (const n of [d.from, d.to]) uses[n] = (uses[n] || 0) + 1;
    const ease = (v) => { const t = Math.max(0, Math.min(1, (v - 28) / 56)); return t * t * (3 - 2 * t); }; // ~level through the overlap, back by 84
    for (const sg of Object.values(segs)) {
      const d = DEF.segments[sg.id], n = sg.samples.length, L = sg.cum[n - 1];
      const y0 = sg.samples[0][1], y1 = sg.samples[n - 1][1];
      sg.samples.forEach((p, i) => {
        if (uses[d.from] > 1) p[1] = y0 + (p[1] - y0) * ease(sg.cum[i]);
        if (uses[d.to] > 1) p[1] = y1 + (p[1] - y1) * ease(L - sg.cum[i]);
      });
    }
  }
  for (const [segId, ranges] of Object.entries(jumpRanges)) {
    const sg = segs[segId];
    sg.samples.forEach((p, i) => {
      for (const [a, b] of ranges) if (sg.cum[i] > a && sg.cum[i] < b) { const t = (sg.cum[i] - a) / (b - a); p[1] += Math.sin(t * Math.PI) * 7; }
    });
  }

  // ------------------------------------------------ ground: golden grass
  const G = Z.group('Ground', 'Folder');
  G.box({ name: 'Grass', s: [900, 4, 820], p: [0, GROUND - 2, 10], c: P.grass[0], studs: 'top', collide: true });
  // (2026-10-14: overlapping patches of two tones sat in one plane and flickered - by the Sunset Stones too. A patch
  // that would overlap a differently toned one is left out; R() is still drawn so the rest of the map doesn't move)
  const patches = [];
  const rectHit = (A, B) => {
    const ax = (q) => { const a = (q.yaw * Math.PI) / 180; return [[Math.cos(a), Math.sin(a)], [-Math.sin(a), Math.cos(a)]]; };
    const ua = ax(A), ub = ax(B), T = [B.x - A.x, B.z - A.z];
    for (const L of [...ua, ...ub]) {
      const ra = A.w / 2 * Math.abs(ua[0][0] * L[0] + ua[0][1] * L[1]) + A.d / 2 * Math.abs(ua[1][0] * L[0] + ua[1][1] * L[1]);
      const rb = B.w / 2 * Math.abs(ub[0][0] * L[0] + ub[0][1] * L[1]) + B.d / 2 * Math.abs(ub[1][0] * L[0] + ub[1][1] * L[1]);
      if (Math.abs(T[0] * L[0] + T[1] * L[1]) > ra + rb) return false;
    }
    return true;
  };
  for (let k = 0; k < 46; k++) {
    const x = (R() - 0.5) * 760, z = (R() - 0.5) * 700;
    const q = { x, z, w: 30 + R() * 60, d: 30 + R() * 60, yaw: R() * 90, c: P.grass[1 + (k % 3)] };
    if (patches.some((o) => o.c !== q.c && rectHit(o, q))) continue;
    patches.push(q);
    G.box({ name: 'GrassPatch', s: [q.w, 0.06, q.d], p: [x, GROUND + 0.03, z], r: [0, q.yaw, 0], c: q.c, shadow: false });
  }

  // ------------------------------------------------ terrain: low rolling swells, flattened for every set piece
  const T = terrain(Z, segs, at);
  // height of the walkable top above GROUND (2026-10-14: swell columns stand on y = 0, so GROUND + the column height
  // floated every plant, rock and patch on a swell half a stud above its top)
  const hAt = (x, z) => Math.max(0, T.hAt(x, z) - GROUND);

  // ------------------------------------------------ roads (red dirt)
  const roads = Z.group('Roads', 'Folder');
  for (const sg of Object.values(segs)) {
    const gaps = jumpRanges[sg.id] || [];
    const inGap = (s) => gaps.some(([a, b]) => s > a + 1 && s < b - 1);
    const W = sg.width;
    const n = sg.samples.length;
    // tiles: at least 6 studs, grown up to 30 while the road stays straight and level (fewer parts on the long runs)
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
      const tone = tile++ % 2 ? P.dirt : shade(P.dirt, 0.96);
      const ya = ROAD + a[1], yb = ROAD + b[1];
      roads.beam([a[0], ya - 0.3, a[2]], [b[0], yb - 0.3, b[2]], W, 0.6, { name: 'Road', c: tone, m: 'Sand', collide: true, extend: 0.2 });
      // (2026-10-14) a raised stretch gets an earth bank under it, down into the grass: the slab used to hang over the
      // swell steps with a gap beneath (worst past the Bone Yard's mouth). Its top stays hidden inside the slab, its
      // sides tucked 0.2 in, a little longer than the slab so it fills the gaps on the outside of bends; Spine Ridge has its own Shelf
      if (sg.id !== 'SpineRidge' && Math.max(a[1], b[1]) > 0.6) { // (lower than that the gap under the slab is < 0.1)
        const top = (y) => y - 0.3; // 0.3 under the road surface
        const H = Math.max(top(ya), top(yb)) - (GROUND - 0.4); // deep enough that the lower end is still buried
        roads.beam([a[0], top(ya) - H / 2, a[2]], [b[0], top(yb) - H / 2, b[2]], W - 0.4, H, { name: 'RoadBed', c: P.dirtLo, m: 'Sand', collide: true, shadow: false, extend: i0 === 0 || i === n - 1 ? 0 : 1.2 });
      }
      const flatHere = Math.abs(yb - ya) < 0.02 && Math.abs(ROAD + sg.samples[Math.max(0, i0 - 3)][1] - ya) < 0.02;
      // (2026-10-14: the joint disk's top sat 0.03 under the road's and flickered through it; now 0.08 under, 0.04 over the
      // grass where it peeks out at a bend - it only has to fill the bend gaps)
      if (flatHere && i0 > 0) roads.cyl({ name: 'RoadJoint', axis: 'y', len: 0.6, d: W, p: [a[0], ya - 0.38, a[2]], c: P.dirt, m: 'Sand', collide: true });
      // tyre ruts
      const fa = RT.frameAt(sg.samples, i0), fb = RT.frameAt(sg.samples, j);
      if (tile % 2 === 0) for (const rx of [-W * 0.18, W * 0.18]) roads.beam([a[0] + fa.r[0] * rx, ya + 0.02, a[2] + fa.r[2] * rx], [b[0] + fb.r[0] * rx, yb + 0.02, b[2] + fb.r[2] * rx], 1.2, 0.04, { name: 'Rut', c: P.dirtLo, m: 'Sand', shadow: false });
    }
    // edges: sandstone blocks and bleached bones
    for (let s = 4; s < sg.cum[n - 1] - 4; s += 9) {
      if (inGap(s)) continue;
      if ((sg.id === 'GoldenRoad' && s < 16) || (sg.id === 'Homestretch' && s > sg.cum[n - 1] - 22)) continue;
      if (sg.id === FLATS.seg && s > FLATS.s0 - 4 && s < FLATS.s1 + 4) continue; // bare salt crust
      for (const side of [-1, 1]) {
        // (2026-10-12: verge props sit past the rover's reach - it steers to hw - 2.6 and is ~4 wide, so at +0.6 it drove through them)
        const f = at(sg.id, s, side * (W / 2 + 3.2));
        const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
        const k = Math.floor(s / 9) % 4;
        if (k === 0) roads.at([f.p[0], ROAD + f.base[1], f.p[2]], [0, yaw, 0]).box({ name: 'EdgeStone', s: [1.6, 0.9, 2.6], p: [0, 0.2, 0], r: [0, 0, R() * 8], c: P.mesa[Math.floor(R() * 5)], m: 'Slate' });
        else if (k === 2 && R() > 0.5) roads.at([f.p[0], ROAD + f.base[1], f.p[2]], [0, yaw + 30, 0]).box({ name: 'EdgeBone', s: [0.5, 0.5, 3.2], p: [0, 0.2, 0], c: P.bone });
      }
    }
  }

  // ------------------------------------------------ boundary: sandstone cliffs + a skyline of mesas and blue peaks
  E.cliffWall(Z, [[-BX, BZ0], [BX, BZ0], [BX, BZ1], [-BX, BZ1], [-BX, BZ0]], { ...ARID, h: 52, d: 26, seed: 909, slope: 6, name: 'PlainsCliffs', chunk: 16, colors: P.mesa, trees: false });
  const M = Z.group('Skyline');
  // a varied skyline: tables, tiered mesas, buttes, leaning spires and a stone arch, in two depth rows, on three sides
  const KINDS = ['Table', 'Butte', 'Tiered', 'Spire', 'Table', 'Arch', 'Butte', 'Spire', 'Tiered', 'Table', 'Butte', 'Spire'];
  for (let k = 0; k < 12; k++) {
    const x = -560 + k * 102 + (R() - 0.5) * 30, z = -400 - (k % 2) * 70 - R() * 30;
    landform(M, [x, 0, z], KINDS[k], 0.75 + R() * 0.45 + (k % 2) * 0.2, 60 + k);
  }
  for (let k = 0; k < 5; k++) {
    landform(M, [-520 - R() * 40, 0, -260 + k * 140], ['Butte', 'Table', 'Spire', 'Tiered', 'Table'][k], 0.7 + R() * 0.4, 80 + k);
    landform(M, [520 + R() * 40, 0, -300 + k * 120], ['Tiered', 'Spire', 'Table', 'Butte', 'Arch'][k], 0.7 + R() * 0.4, 90 + k);
  }
  for (let k = 0; k < 6; k++) landform(M, [-420 + k * 170 + (R() - 0.5) * 40, 0, 500 + R() * 50], ['Table', 'Spire', 'Butte', 'Table', 'Tiered', 'Butte'][k], 0.7 + R() * 0.3, 100 + k);
  for (let k = 0; k < 6; k++) {
    const x = -600 + k * 230 + (R() - 0.5) * 60, z = -600 - R() * 60;
    const h = 150 + R() * 110;
    for (let t = 0; t < 5; t++) M.box({ name: 'Peak', s: [190 - t * 32 + R() * 20, h / 5 + 1, 140 - t * 22 + R() * 16], p: [x + (R() - 0.5) * 10 * t, (t + 0.5) * (h / 5), z], r: [0, (R() - 0.5) * 24, 0], c: t >= 3 ? '#f0f2f4' : shade('#7f8fa0', 0.9 + t * 0.05), m: 'Slate' });
  }
  // a smoking peak far behind the east cliff (hint of what's next)
  const V = Z.at([560, 0, 60]);
  for (let t = 0; t < 6; t++) V.box({ name: 'Volcano', s: [200 - t * 30, 30, 200 - t * 30], p: [0, 15 + t * 28, 0], r: [0, t * 11, 0], c: t > 3 ? '#4a3a36' : '#5d4a42', m: 'Slate' });
  const crater = V.box({ name: 'Crater', s: [26, 4, 26], p: [0, 170, 0], c: '#ff5a1a', m: 'Neon' });
  E.particles(crater, 'Smoke', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 5, life: [8, 12], speed: [8, 14], dir: 1, spread: [15, 15], size: [[0, 20], [1, 60]], transp: [[0, 0.3], [1, 1]], color: [0.35, 0.32, 0.32], emission: 0 });

  // ------------------------------------------------ set pieces
  buildArrival(Z, at);
  buildSaltFlats(Z, segs, at, R);
  buildRibcage(Z, at, R);
  buildOldGiant(Z, R);
  buildMigration(Z);
  buildMesaPass(Z, segs, at, R);
  buildGulch(Z, segs, at, R);
  buildHerdPlains(Z, segs, at, R);
  buildSpineRidge(Z, segs, at, R, jumpRanges.SpineRidge || []);
  buildGrove(Z, segs, at, R);
  for (const n of NESTS) buildNestSite(Z, n, at, R);
  buildReturnPortal(Z, at);
  buildBoneYard(Z, at, R, route);
  buildWeather(Z, at, R);
  buildCinematics(Z, at);
  { const f = at('GoldenRoad', 0); const c = Z.at([f.p[0] - 20, GROUND, f.p[2] - 12], [0, 60, 0]); NPC.buildNpc(c.parent, c.world(new CF(0, 0, 0)), 'Ranger'); }

  // ------------------------------------------------ obstacles
  const OB = Z.group('Obstacles', 'Folder');
  FEATURES.forEach((f, idx) => {
    const [type, seg, s, x, o = {}] = f;
    if (!OBSTACLE_TYPES.has(type)) return;
    const fr = at(seg, s, x);
    const yaw = E.deg(Math.atan2(-fr.f[0], -fr.f[2]));
    const c = OB.at([fr.p[0], ROAD + fr.base[1], fr.p[2]], [0, yaw, 0]);
    const g = c.group(type + idx);
    if (type === 'Log') {
      // a fallen conifer, bark side up, broken branches
      g.cyl({ name: 'Log', axis: 'x', len: o.w || 10, d: 2.4, p: [0, 1.2, 0], r: [0, (R() - 0.5) * 16, 0], c: P.bark[0] });
      g.cyl({ name: 'LogEnd', axis: 'x', len: (o.w || 10) + 0.1, d: 1.7, p: [0, 1.2, 0], c: '#d9a86a' });
      for (let k = 0; k < 3; k++) g.box({ name: 'BrokenBranch', s: [0.4, 2.2, 0.4], p: [-(o.w || 10) / 2 + 2 + k * 3, 2.6, (R() - 0.5)], r: [(R() - 0.5) * 30, 0, (R() - 0.5) * 30], c: P.bark[1] });
    } else if (type === 'Boulder') {
      E.rock(g, [0, 0, 0], (o.w || 7) / 3, 7000 + idx, { colors: P.mesa, moss: false });
    } else if (type === 'Pillar') {
      hoodoo(g, [0, 0, 0], 12 + R() * 4, 7100 + idx);
    }
  });

  // ------------------------------------------------ vegetation: cycads by the road, conifers and sequoias behind
  const VG = Z.group('Vegetation');
  const placed = [];
  const keepOut = [];
  { const d = at(DEN.seg, DEN.s, DEN.x); keepOut.push([d.p[0], d.p[2], 52]); }
  { const f = at(FINAL.seg, FINAL.s, FINAL.x); keepOut.push([f.p[0], f.p[2], 38]); }
  for (const n of NESTS) { const f = at(n.seg, n.s, n.x); keepOut.push([f.p[0], f.p[2], 28]); }
  keepOut.push([OLD_GIANT[0], OLD_GIANT[2], 30]);
  { const f = at(RIBCAGE.seg, RIBCAGE.s); keepOut.push([f.p[0], f.p[2], 30]); }
  { const f = at(OASIS.seg, OASIS.s, OASIS.x); keepOut.push([f.p[0], f.p[2], 20]); }
  for (const [x, , z] of MIGRATION) keepOut.push([x, z, 16]);
  { const f = at(FLATS.seg, (FLATS.s0 + FLATS.s1) / 2); keepOut.push([f.p[0], f.p[2], 62]); }
  const tryPlace = (x, z, pad, gap) => {
    if (Math.abs(x) > BX - 20 || z < BZ0 + 20 || z > BZ1 - 20) return false;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr + pad * 0.3)) return false;
    if (nearRoad(x, z, pad)) return false;
    if (placed.some(([px, pz]) => Math.hypot(px - x, pz - z) < gap)) return false;
    placed.push([x, z]);
    return true;
  };
  for (const sg of Object.values(segs)) {
    for (let s = 6; s < sg.cum[sg.cum.length - 1]; s += 14 + R() * 10) {
      for (const side of [-1, 1]) {
        if (R() < 0.3) continue;
        const f = at(sg.id, s, side * (sg.width / 2 + 5 + R() * 9));
        if (!tryPlace(f.p[0], f.p[2], 3, 7)) continue;
        const gy = GROUND + hAt(f.p[0], f.p[2]);
        if (R() < 0.65) cycad(VG, [f.p[0], gy, f.p[2]], 2 + R() * 3, 50000 + placed.length);
        else E.bush(VG, [f.p[0], gy, f.p[2]], 1.1 + R() * 0.6, 50000 + placed.length, { colors: P.cycad });
      }
    }
  }
  for (const sg of Object.values(segs)) {
    for (let s = 3; s < sg.cum[sg.cum.length - 1]; s += 7 + R() * 5) {
      for (const side of [-1, 1]) {
        const f = at(sg.id, s, side * (sg.width / 2 + 1.8 + R() * 3));
        if (nearRoad(f.p[0], f.p[2], 0.6) || f.base[1] > 0.5 || hAt(f.p[0], f.p[2]) > 0.1) continue;
        if (R() < 0.8) E.grassTufts(VG, [f.p[0], GROUND, f.p[2]], 52000 + Math.floor(s * 7) + side, { n: 4, spread: 2.6, colors: P.grass });
        else E.flowers(VG, [f.p[0], GROUND, f.p[2]], 53000 + Math.floor(s * 7) + side, { n: 3, spread: 2, colors: ['#ffffff', '#ff9a3a', '#ffd23a'] });
      }
    }
  }
  // the open plains: scattered lone conifers, mesas and hoodoos (big is the point here: wide views)
  for (let k = 0; k < 6000 && placed.length < 980; k++) {
    const x = (R() - 0.5) * 2 * (BX - 25), z = BZ0 + 25 + R() * (BZ1 - BZ0 - 50);
    const gy = GROUND + hAt(x, z);
    const pick = R();
    if (pick < 0.2) { if (tryPlace(x, z, 12, 20)) araucaria(VG, [x, gy, z], 22 + R() * 16, 54000 + k); }
    else if (pick < 0.25) { if (tryPlace(x, z, 26, 60)) mesa(VG, [x, gy - 1, z], 30 + R() * 30, 24 + R() * 20, 18 + R() * 22, 54000 + k, 'Butte'); }
    else if (pick < 0.3) { if (tryPlace(x, z, 8, 22)) hoodoo(VG, [x, gy, z], 10 + R() * 10, 54000 + k); }
    else if (pick < 0.5) { if (tryPlace(x, z, 5, 9)) cycad(VG, [x, gy, z], 2 + R() * 4, 54000 + k); }
    else if (pick < 0.6) { if (tryPlace(x, z, 5, 9)) E.rock(VG, [x, gy, z], 1.2 + R() * 1.8, 54000 + k, { colors: P.mesa, moss: false }); }
    else if (pick < 0.66) { if (tryPlace(x, z, 4, 8)) E.bush(VG, [x, gy, z], 1 + R() * 0.7, 54000 + k, { colors: P.cycad }); }
    else if (tryPlace(x, z, 3, 7)) E.grassTufts(VG, [x, gy, z], 54000 + k, { n: 6, spread: 5, colors: P.grass, scale: 2.2 + R() * 0.8 });
  }
  // the plains floor: sun-bleached and green-gold patches, so the open grass reads as rolling and alive
  const floorR = rng(81234);
  for (let k = 0, made = 0; k < 2400 && made < 280; k++) {
    const x = (floorR() - 0.5) * 2 * (BX - 25), z = BZ0 + 25 + floorR() * (BZ1 - BZ0 - 50);
    if (nearRoad(x, z, 4)) continue;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr)) continue;
    const gy = GROUND + hAt(x, z);
    // (2026-10-14: 0.02 up and 0.05 per stacked piece, so they clear the grass patches, game trails and each other by >= 0.04)
    // (and none reaching under a road: on the flat they stood out of its surface, on a raised one ran into the bank)
    if (floorR() < 0.7) { const r = 5 + floorR() * 6; if (!nearRoad(x, z, r * 1.25)) E.groundPatch(VG, [x, gy + 0.02, z], r, 82000 + k, { colors: ['#c9b46a', '#b5c46a', '#d8c27a', '#9fb85e', '#e0cf8a'], step: 0.05 }); }
    else E.flowers(VG, [x, gy, z], 83000 + k, { n: 4, spread: 3, colors: ['#ffd23a', '#ffffff', '#ff8a2a', '#c86bff'] });
    made++;
  }

  // keep the rover's lane clear: decor in the way is removed, anything else is reported for a fix
  {
    const lanes = [];
    for (const sg of Object.values(segs)) for (const p of sg.samples) lanes.push({ x: p[0] + GP_ORIGIN[0], z: p[2] + GP_ORIGIN[2], y: ROAD + p[1], hw: sg.width / 2 });
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

// ------------------------------------------------------------------ terrain
function terrain(Z, segs, at) {
  const CELL = 14, STEP = 1.2;
  const N = noise2(4242);
  const fbm = (x, z) => 0.65 * N(x / 140, z / 140) + 0.35 * N(x / 60 + 11, z / 60 - 23);
  const road = [];
  for (const sg of Object.values(segs)) sg.samples.forEach((p, i) => { if (i % 2 === 0) road.push([p[0], p[2], sg.width / 2, p[1]]); });
  const nearestRoad = (x, z) => {
    let best = Infinity, y = 0;
    for (const [px, pz, hw, py] of road) { const d = Math.hypot(x - px, z - pz) - hw; if (d < best) { best = d; y = py; } }
    return [best, y];
  };
  const circles = [];
  const addAt = (seg, s, x, r) => { const f = at(seg, s, x); circles.push([f.p[0], f.p[2], r]); };
  addAt('GoldenRoad', 0, 0, 52); addAt('GoldenRoad', 0, -26, 30);
  addAt('Homestretch', 1e9, 0, 40);
  for (const n of NESTS) addAt(n.seg, n.s, n.x, 34);
  addAt(DEN.seg, DEN.s, DEN.x, 54);
  addAt(DEN.seg, DEN.s, 30, 20);
  addAt(FINAL.seg, FINAL.s, FINAL.x, 44);
  const jump = FEATURES.find((f) => f[0] === 'Jump');
  addAt(jump[1], jump[2], 0, 48);
  addAt(OASIS.seg, OASIS.s, OASIS.x, 30);
  addAt(RIBCAGE.seg, RIBCAGE.s, 0, 34);
  circles.push([OLD_GIANT[0], OLD_GIANT[2], 34]);
  for (let k = 0; k < MIGRATION.length; k++) {
    const [ax, , az] = MIGRATION[k], [bx, , bz] = MIGRATION[(k + 1) % MIGRATION.length];
    for (let t = 0; t < 1; t += 0.34) circles.push([ax + (bx - ax) * t, az + (bz - az) * t, 12]);
  }
  const yard = at(DEN.seg, DEN.s, DEN.x);
  const corridor = [['Plains', 240, 460, 44], ['Plains', 460, 720, 100], ['GroveTrail', 0, 1e9, 34], ['MesaPass', 0, 1e9, 24], ['SaltFlats', 0, 1e9, 58]];
  const corridorPts = corridor.map(([seg, s0, s1, lat]) => {
    const sg = segs[seg]; const L = sg.cum[sg.cum.length - 1];
    const pts = [];
    for (let s = s0; s <= Math.min(s1, L); s += 6) { const f = at(seg, s); pts.push([f.p[0], f.p[2], lat]); }
    return pts;
  });
  const smooth = (e0, e1, v) => { const t = Math.max(0, Math.min(1, (v - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };
  const openness = (x, z) => {
    let k = 1;
    for (const [cx, cz, r] of circles) k = Math.min(k, smooth(r, r + 26, Math.hypot(x - cx, z - cz)));
    for (const pts of corridorPts) for (const [px, pz, lat] of pts) k = Math.min(k, smooth(lat, lat + 24, Math.hypot(x - px, z - pz)));
    return k;
  };
  const heights = new Map();
  const key = (i, j) => i + ',' + j;
  const G = Z.group('Swells', 'Folder');
  const cells = [];
  let built = 0;
  for (let x0 = -BX + CELL / 2; x0 < BX; x0 += CELL) {
    for (let z0 = BZ0 + CELL / 2; z0 < BZ1; z0 += CELL) {
      const i = Math.round(x0 / CELL), j = Math.round(z0 / CELL);
      const [d, ry] = nearestRoad(x0, z0);
      const edge = Math.min(x0 + BX, BX - x0, z0 - BZ0, BZ1 - z0);
      // plains: gentle swells, rising toward the cliffs
      let H = 3 + 16 * Math.max(0, fbm(x0, z0) + 0.15) + 22 * (1 - smooth(10, 80, edge));
      const t = smooth(10, 56, d) * openness(x0, z0);
      let h = ry * (1 - smooth(10, 56, d)) + H * t;
      h = Math.floor(h / STEP) * STEP;
      if (d < CELL * 0.75 + 1) {
        // (2026-10-14: capped by the lowest road the column reaches under, not the height at its middle - on the steep
        // ridges a 14-stud column's downhill side stood up to 0.6 through the road surface)
        let lo = ry;
        for (const [px, pz, hw, py] of road) if (py < lo && Math.hypot(x0 - px, z0 - pz) < hw + CELL * 0.71 + 1) lo = py;
        h = Math.min(h, Math.floor((lo - 0.5) / STEP) * STEP);
      }
      // (2026-10-14) nothing stands in the Bone Yard: the road-side terraces ran on into the bowl and their square
      // grass tops cut through the round sand floor where the Titan fights (see buildBoneYard: floor d 86)
      if (Math.hypot(Math.max(0, Math.abs(x0 - yard.p[0]) - CELL / 2), Math.max(0, Math.abs(z0 - yard.p[2]) - CELL / 2)) < 43.5) h = 0;
      if (h < STEP) { heights.set(key(i, j), 0); continue; }
      heights.set(key(i, j), h);
      const top = Math.min(1.2, h);
      // grass tone by broad patches (neighbours share a tone, so the cells merge into bigger blocks)
      const tone = Math.floor((N(x0 / 80 + 9, z0 / 80 - 4) + 1) * 2) % 4;
      cells.push({ i, j, x: x0, z: z0, h, top, topC: P.grass[tone], sideC: h > 14 ? P.mesa[Math.floor(h / 4.8) % 5] : P.dirt, sideM: h > 14 ? 'Slate' : 'Sand' });
      built++;
    }
  }
  const parts = E.heightfield(G, cells, CELL, { sideName: 'SwellSide', topName: 'SwellTop' });
  const cellOf = (v, lo) => Math.round((lo + CELL / 2 + Math.floor((v - lo) / CELL) * CELL) / CELL);
  const hAt = (x, z) => heights.get(key(cellOf(x, -BX), cellOf(z, BZ0))) || 0;
  console.log('                   swells: ' + built + ' columns -> ' + parts + ' parts');
  return { hAt, open: (x, z) => openness(x, z) < 0.5 };
}

// ------------------------------------------------------------------ set pieces
function hexPortal(ctx, p, yaw, R, name, o = {}) {
  const g = ctx.group(name);
  const c = g.at(p, [0, yaw, 0]);
  const cy = R * Math.sin(Math.PI / 3) - 1.8;
  const F = c.at([0, cy, 0]);
  const pts = Array.from({ length: 6 }, (_, k) => { const a = (k * 60 * Math.PI) / 180; return [Math.cos(a) * R, Math.sin(a) * R]; });
  for (let k = 0; k < 6; k++) {
    const [ax, ay] = pts[k], [bx, by] = pts[(k + 1) % 6];
    F.beam([ax, ay, 0], [bx, by, 0], 3.6, 3, { name: 'PortalBeam', c: '#6a5a4a', m: 'Slate', studs: 'top', extend: 1, up: [0, 0, 1] });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNode', s: [4.4, 4.4, 4.8], c: '#2b2d31', m: 'Metal', studs: 'all' });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNodeCore', s: [2, 2, 5], c: o.color || '#ffcf5a', m: 'Neon' }).tag('GateNode');
  }
  const rm = R - 2.2, apo = rm * Math.sin(Math.PI / 3);
  for (let k = 0; k < 3; k++) F.box({ name: 'Membrane', s: [rm, 2 * apo, 0.3], r: [0, 0, k * 60], c: o.color || '#ffbf3a', m: 'Neon', t: 0.42, shadow: false }).tag('PortalSurface');
  for (let k = 0; k < 3; k++) F.box({ name: 'Core', s: [rm * 0.5, 2 * apo * 0.5, 0.35], r: [0, 0, k * 60], c: '#fff2c4', m: 'Neon', t: 0.35, shadow: false }).tag('PortalCore');
  const host = F.box({ name: 'PortalLightHost', s: [1, 1, 1], t: 1, shadow: false });
  E.pointLight(host, [1, 0.85, 0.5], 46, 2);
  E.particles(host, 'Swirl', { rate: 30, life: [0.8, 1.6], speed: [5, 12], spread: [80, 80], dir: 5, size: [[0, 0.6], [1, 0]], color: [[0, [1, 0.95, 0.7]], [1, [1, 0.7, 0.3]]], emission: 1 });
  for (const side of [-1, 1]) c.box({ name: 'Plinth', s: [6, 3, 7], p: [side * (R + 6), 1.5, 0], c: '#9a7a5a', m: 'Slate', studs: 'top', collide: true });
  return g;
}

function buildArrival(Z, at) {
  const f = at('GoldenRoad', 0);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  hexPortal(Z, [f.p[0], GROUND, f.p[2] + 6], yaw, 14, 'ArrivalPortal', { color: '#3fe0c8' });
  const c = Z.at([f.p[0] - 26, GROUND, f.p[2] - 20], [0, -20, 0]);
  c.box({ name: 'TentFloor', s: [10, 0.3, 8], p: [0, 0.15, 0], c: '#8a5a33' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, -2], face: 'front', c: '#e8d29a' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, 2], face: 'back', c: '#dcc489' });
  E.crate(c, [-6.5, 0.3, 1], 1, { yaw: -14, stencil: '#b85a30' });
  E.barrel(c, [-6.5, 0.3, -2.5], { color: '#b85a30' });
  E.signBoard(c, [7, 4, -3], 7, 2, 'GIANT PLAINS', { r: [0, 30, 0], color: '#fff2c4', color2: '#ffb02e', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [7, 2, -2.7], c: E.PAL.woodLo });
  E.lampPost(c, [4, 0.3, 4], { h: 6 });
}

function buildReturnPortal(Z, at) {
  const f = at('Homestretch', 1e9);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  hexPortal(Z, [f.p[0] - f.f[0] * 14, GROUND, f.p[2] - f.f[2] * 14] /* 14 back from the end: you drive through it before the warp (extract at L-8) */, yaw, 15, 'ReturnPortal', { color: '#ffb02e' });
}

// one rib (or any bone arc) in the local X-Y plane at depth z: from (side*r, 0) curving up to (0, h)
function boneArc(ctx, z, r, h, w, o = {}) {
  const n = o.n || 6;
  const pts = [];
  for (let k = 0; k <= n; k++) { const a = (k / n) * (Math.PI / 2); pts.push([(o.side || 1) * r * Math.cos(a), h * Math.sin(a), z]); }
  for (let k = 0; k < n; k++) ctx.beam(pts[k], pts[k + 1], w * (1 - k * 0.06), w * 0.8, { name: o.name || 'Rib', c: k % 2 ? P.bone : P.boneLo, up: [0, 0, 1], extend: 0.8, collide: !!o.collide && k === 0 });
}
// a sauropod skeleton lying on its side (ribs up, long neck and tail along the ground), facing local -Z
function fallenSauropod(ctx, p, yaw, k, seed) {
  const R = rng(seed);
  const c = ctx.group('FallenSauropod').at(p, [0, yaw, 0]);
  for (let i = 0; i < 9; i++) c.box({ name: 'Vertebra', s: [1.8 * k, 1.6 * k, 2 * k], p: [0, 0.8 * k, (i - 4) * 2.1 * k], r: [0, R() * 10, R() * 8], c: i % 2 ? P.bone : P.boneLo });
  for (let i = 0; i < 6; i++) boneArc(c, (i - 2.5) * 2.4 * k, (3.4 - Math.abs(i - 2.5) * 0.4) * k, (6 - Math.abs(i - 2.5) * 0.8) * k, 0.7 * k, { n: 4 });
  for (let i = 0; i < 10; i++) c.box({ name: 'NeckBone', s: [1.1 * k, 1 * k, 1.8 * k], p: [Math.sin(i * 0.25) * 3 * k, 0.5 * k, -10 * k - i * 1.7 * k], r: [0, i * 8, 0], c: i % 2 ? P.bone : P.boneLo });
  c.box({ name: 'Skull', s: [2 * k, 1.6 * k, 3 * k], p: [Math.sin(2.5) * 3 * k, 0.8 * k, -29 * k], r: [0, 30, 10], c: P.bone });
  for (let i = 0; i < 9; i++) c.box({ name: 'TailBone', s: [(1 - i * 0.08) * k, (0.9 - i * 0.06) * k, 1.6 * k], p: [-Math.sin(i * 0.3) * 4 * k, 0.45 * k, 10 * k + i * 1.6 * k], r: [0, -i * 9, 0], c: i % 2 ? P.bone : P.boneLo });
  for (const sd of [-1, 1]) c.box({ name: 'Femur', s: [1 * k, 1 * k, 6 * k], p: [sd * 5 * k, 0.5 * k, 3 * k], r: [0, sd * 50, 0], c: P.boneLo });
  return c;
}

function buildSaltFlats(Z, segs, at, R) {
  // a dried salt lake the road runs straight across: white crust plates with dark crack seams, a stranded skeleton,
  // dead snags; the Tall Grove oasis waits at the far shore
  const g = Z.group('SaltFlats');
  const { seg, s0, s1, half } = FLATS;
  const sg = segs[seg];
  const nest = at(NESTS[2].seg, NESTS[2].s, NESTS[2].x);
  const crust = ['#efe8d6', '#e6dcc4', '#f4efe2', '#ddd2b8'];
  const bones = at(seg, 70, 44);
  const lowRoad = [];
  for (const id of [seg, 'MesaPass', 'GoldenRoad']) for (const p of segs[id].samples) if (p[1] < 0.5) lowRoad.push([p[0], p[2], segs[id].width / 2]);
  for (let s = s0; s < s1; s += 10) {
    const fat = Math.sin(((s - s0) / (s1 - s0)) * Math.PI);
    for (let x = -half; x <= half; x += 10) {
      if (Math.abs(x) > half * (0.4 + 0.6 * fat) + (R() - 0.5) * 10) continue;
      if (Math.abs(x) < sg.width / 2 - 4) continue; // the road runs over the middle
      const f = at(seg, s + (R() - 0.5) * 2, x + (R() - 0.5) * 2);
      if (Math.hypot(f.p[0] - nest.p[0], f.p[2] - nest.p[2]) < 24) continue;
      if (Math.hypot(f.p[0] - bones.p[0], f.p[2] - bones.p[2]) < 20) continue;
      const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
      const c = g.at([f.p[0], GROUND, f.p[2]], [0, yaw + (R() - 0.5) * 14, 0]);
      const w = 9.4 + R() * 2.4, d = 9.4 + R() * 2.4;
      // (2026-10-14: a plate reaching under a road stood 0.02 out of its surface, its seams 0.1 - by the Salt Flats road's
      // edges, and where Mesa Pass now leaves the fork level. Those lie 0.06 under the road, without seams; R() is drawn
      // the same either way)
      const under = lowRoad.some(([px, pz, hw]) => Math.hypot(f.p[0] - px, f.p[2] - pz) < hw + 8.5);
      c.box({ name: 'SaltCrust', s: [w, under ? 0.06 : 0.14, d], p: [0, under ? 0.03 : 0.07, 0], c: crust[Math.floor(R() * 4)], m: 'Sand', shadow: false });
      // seams: the crust curls up a little at the cracks
      if (R() > 0.35) { const r = [0, (R() - 0.5) * 18, 0]; if (!under) c.box({ name: 'SaltSeam', s: [w, 0.24, 0.4], p: [0, 0.1, d / 2], r, c: '#c8b894', shadow: false }); }
      if (R() > 0.55) { const r = [0, (R() - 0.5) * 18, 0]; if (!under) c.box({ name: 'SaltSeam', s: [0.4, 0.24, d], p: [w / 2, 0.1, 0], r, c: '#c8b894', shadow: false }); }
    }
  }
  // a sauropod that never made it across, and dead snags sticking out of the crust
  { const f = at(seg, 70, 44); fallenSauropod(g, [f.p[0], GROUND, f.p[2]], E.deg(Math.atan2(-f.f[0], -f.f[2])) - 110, 1.15, 4401); }
  for (let k = 0; k < 6; k++) {
    const f = at(seg, s0 + 10 + k * 20, (k % 2 ? 1 : -1) * (sg.width / 2 + 10 + R() * 22));
    const c = g.at([f.p[0], GROUND, f.p[2]], [0, R() * 360, 0]);
    const h = 5 + R() * 5;
    c.box({ name: 'Snag', s: [0.9, h, 0.9], p: [0, h / 2, 0], r: [R() * 10, 0, R() * 10], c: '#9a8a74' });
    c.box({ name: 'SnagArm', s: [0.5, 3, 0.5], p: [0.8, h * 0.7, 0], r: [0, 0, -40], c: '#9a8a74' });
  }
  // the oasis: a round spring-fed pool in the Tall Grove, cycads leaning over the water
  const o = at(OASIS.seg, OASIS.s, OASIS.x);
  const pc = g.at([o.p[0], GROUND, o.p[2]]);
  pc.cyl({ name: 'OasisShore', axis: 'y', len: 0.3, d: 34, p: [0, 0.15, 0], c: P.sand, m: 'Sand', shadow: false });
  pc.cyl({ name: 'OasisWater', axis: 'y', len: 0.3, d: 28, p: [0, 0.32, 0], c: P.water, m: 'Glass', t: 0.2, shadow: false }).tag('DinoWater');
  for (let k = 0; k < 16; k++) {
    const a = (k / 16) * Math.PI * 2;
    pc.box({ name: 'PoolStone', s: [2 + R() * 2, 0.9, 1.6 + R()], p: [Math.cos(a) * 15, 0.35, Math.sin(a) * 15], r: [0, -E.deg(a), R() * 8], c: P.mesa[k % 5], m: 'Slate' });
  }
  for (let k = 0; k < 6; k++) pc.cyl({ name: 'LilyPad', axis: 'y', len: 0.1, d: 1.6 + R(), p: [(R() - 0.5) * 18, 0.5, (R() - 0.5) * 18], c: '#4fb043', shadow: false });
  for (let k = 0; k < 6; k++) { const a = (k / 6) * Math.PI * 2 + 0.4; cycad(pc, [Math.cos(a) * 19, 0, Math.sin(a) * 19], 3 + R() * 3, 4500 + k); }
}

function buildRibcage(Z, at, R) {
  // the first thing you see: a sauropod skeleton so big the Golden Road runs through its ribs
  const f = at(RIBCAGE.seg, RIBCAGE.s);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  const g = Z.group('GiantRibcage');
  const c = g.at([f.base[0], GROUND, f.base[2]], [0, yaw, 0]);
  const H = 26, RX = 19;
  for (let i = 0; i < 8; i++) {
    const z = (i - 3.5) * 5.2;
    const t = 1 - Math.abs(i - 3.5) / 5;
    for (const side of [-1, 1]) boneArc(c, z, RX * (0.85 + 0.15 * t), H * (0.7 + 0.3 * t), 1.6, { side, n: 7, collide: true });
  }
  // the spine across the top, then the neck sweeping down to the skull resting ahead-left of the road, tail behind
  for (let i = 0; i < 12; i++) {
    const z = (i - 5.5) * 3.4;
    const t = 1 - Math.abs(i - 5.5) / 8;
    c.box({ name: 'Vertebra', s: [3.4, 3, 3], p: [0, H * (0.7 + 0.3 * Math.max(0, Math.min(1, t + 0.25))) + 0.6, z], r: [0, R() * 8, 0], c: i % 2 ? P.bone : P.boneLo });
    c.box({ name: 'DorsalSpine', s: [0.9, 3.2, 1.4], p: [0, H * (0.7 + 0.3 * Math.max(0, Math.min(1, t + 0.25))) + 3.6, z], r: [(R() - 0.5) * 16, 0, 0], c: P.bone });
  }
  const neck = [];
  for (let i = 0; i <= 14; i++) { const u = i / 14; neck.push([-34 * Math.min(1, u * 2.5), H * 0.85 * (1 - u) * (1 - u) + 2.2 * u, -22 - u * 34]); }
  for (let i = 0; i < 14; i++) c.beam(neck[i], neck[i + 1], 2.4 - i * 0.07, 2.2 - i * 0.07, { name: 'NeckVertebra', c: i % 2 ? P.bone : P.boneLo, extend: 0.4 });
  const sk = c.at([-35, 0, -58], [0, 40, 0]);
  sk.box({ name: 'Skull', s: [5, 4, 8], p: [0, 2, 0], r: [0, 0, 6], c: P.bone, collide: true });
  sk.box({ name: 'Jaw', s: [4.4, 1.2, 7], p: [0, 0.6, -0.6], c: P.boneLo });
  for (const sd of [-1, 1]) sk.box({ name: 'EyeSocket', s: [0.4, 1.4, 1.6], p: [sd * 2.5, 2.8, -1], c: '#4a3a2a' });
  const tail = [];
  for (let i = 0; i <= 12; i++) { const u = i / 12; tail.push([26 * Math.min(1, u * 3), H * 0.75 * (1 - u) * (1 - u) + 1, 22 + u * 40]); }
  for (let i = 0; i < 12; i++) c.beam(tail[i], tail[i + 1], 2.2 - i * 0.12, 2 - i * 0.12, { name: 'TailVertebra', c: i % 2 ? P.bone : P.boneLo, extend: 0.4 });
  // leg bones planted beside the road like pillars
  for (const [x, z] of [[-24, -10], [24, -12], [-23, 14], [25, 12]]) {
    c.box({ name: 'LegBone', s: [2.4, 14, 2.4], p: [x, 7, z], r: [(R() - 0.5) * 10, 0, (x > 0 ? 1 : -1) * 6], c: P.boneLo, collide: true });
    c.box({ name: 'Knuckle', s: [3.4, 2.6, 3.4], p: [x, 14, z], c: P.bone });
  }
  for (let k = 0; k < 10; k++) E.grassTufts(c, [(R() > 0.5 ? 1 : -1) * (18 + R() * 8), 0, (R() - 0.5) * 40], 4600 + k, { n: 5, spread: 3, colors: P.grass, scale: 1.6 });
}

function buildOldGiant(Z, R) {
  // THE OLD GIANT: a sequoia older than the herds, visible from every road in the era
  const g = Z.group('OldGiant');
  const t = g.at(OLD_GIANT, [0, 20, 0]);
  const W = 15, H = 132;
  for (let i = 0; i * 8 < H; i++) {
    const w = W * (1 - (i * 8) / H * 0.45);
    t.box({ name: 'GiantTrunk', s: [w, 8.2, w], p: [0, 4 + i * 8, 0], r: [0, i * 9, 0], c: P.bark[i % 3], m: 'WoodPlanks', studs: 'sides', collide: true });
    if (i % 3 === 1) t.box({ name: 'BarkRidge', s: [w + 0.8, 6, 1.6], p: [0, 4 + i * 8, 0], r: [0, i * 9 + 45, 0], c: shade(P.bark[0], 0.85), m: 'WoodPlanks' });
  }
  for (let k = 0; k < 6; k++) {
    const a = k * 60 + R() * 20;
    t.at([0, 0, 0], [0, a, 0]).wedgeF({ name: 'GiantRoot', s: [4.2, 12, 9], p: [0, 6, -W / 2 - 4.2], face: 'front', c: P.bark[k % 3], m: 'WoodPlanks', collide: true });
  }
  // crown: overlapping tiers so it reads as one mass from far away, with branch arms poking out
  // a tall narrow cone, not a ball: sequoias keep their crown high and tight around the trunk
  for (let k = 0; k < 15; k++) {
    const u = k / 14;
    const y = H * 0.42 + u * H * 0.62;
    const r = (1 - u * 0.86) * 19 * (k % 2 ? 0.86 : 1);
    t.box({ name: 'GiantCrown', s: [r * 2, 6.6, r * 2 * (0.8 + R() * 0.2)], p: [(R() - 0.5) * 3, y, (R() - 0.5) * 3], r: [0, k * 29, 0], c: P.conifer[k % 3], studs: 'top' });
    if (k < 11 && k % 2 === 0) for (let j = 0; j < 3; j++) {
      const b = t.at([0, y - 3, 0], [0, k * 41 + j * 120, -0]);
      b.box({ name: 'GiantBranch', s: [1.8, 1.8, r + 5], p: [0, 0, -(r + 5) / 2], r: [-8, 0, 0], c: P.bark[1] });
      b.box({ name: 'GiantNeedles', s: [8, 4.4, 8], p: [0, 0.6, -(r + 6)], c: P.conifer[(k + j) % 3], studs: 'top' });
    }
  }
  t.box({ name: 'GiantTip', s: [4, 9, 4], p: [0, H * 1.08, 0], c: P.conifer[0], studs: 'top' });
  // fallen cones and young sequoias in its shade
  for (let k = 0; k < 8; k++) { const a = R() * Math.PI * 2, r = 14 + R() * 12; t.box({ name: 'Cone', s: [1.6, 2.2, 1.6], p: [Math.cos(a) * r, 1.1, Math.sin(a) * r], r: [R() * 60, 0, R() * 60], c: '#8a5a2a' }); }
  for (let k = 0; k < 3; k++) { const a = k * 2.1 + 0.5; sequoia(g, [OLD_GIANT[0] + Math.cos(a) * 30, GROUND, OLD_GIANT[2] + Math.sin(a) * 30], 30 + R() * 10, 4700 + k, { w: 3 }); }
}

function buildMigration(Z) {
  // waypoint markers for the herd walking the game trail around the Old Giant (a closed loop)
  const g = Z.group('Migration', 'Folder');
  MIGRATION.forEach((p, k) => marker(g, 'HerdWaypoint' + (k + 1), [p[0], GROUND + 0.5, p[2]], 0).attr('Loop', true));
  // the trail itself: trampled dirt
  for (let k = 0; k < MIGRATION.length; k++) {
    const [ax, , az] = MIGRATION[k], [bx, , bz] = MIGRATION[(k + 1) % MIGRATION.length];
    // (2026-10-14: one tone, top 0.10 - two tones overlapped in one plane at every joint, and it sat 0.02 over the grass patches)
    g.beam([ax, GROUND + 0.06, az], [bx, GROUND + 0.06, bz], 9, 0.08, { name: 'GameTrail', c: P.dirtLo, m: 'Sand', shadow: false, extend: 3 });
  }
}

// far landforms: each kind has its own silhouette so the skyline never reads as one copied slab
function landform(ctx, p, kind, k, seed) {
  const R = rng(seed);
  const g = ctx.group('Far' + kind);
  const t = g.at(p, [0, R() * 360, 0]);
  const col = (i) => P.mesa[(i + seed) % 5];
  if (kind === 'Table') {
    mesa(t, [0, 0, 0], 120 * k, 70 * k, 60 * k, seed, 'FarMesa');
  } else if (kind === 'Tiered') {
    for (let i = 0; i < 4; i++) t.box({ name: 'Tier', s: [(110 - i * 24) * k, 22 * k, (80 - i * 16) * k], p: [(R() - 0.5) * 8, (11 + i * 22) * k, (R() - 0.5) * 8], r: [0, (R() - 0.5) * 10, 0], c: col(i), m: 'Slate' });
    t.box({ name: 'TierTop', s: [36 * k, 2, 28 * k], p: [0, 89 * k, 0], c: P.mesaTop, m: 'Slate' });
  } else if (kind === 'Butte') {
    const h = 110 * k;
    for (let i = 0; i < 7; i++) t.box({ name: 'ButteLayer', s: [(34 + R() * 6) * k, h / 7 + 0.5, (30 + R() * 6) * k], p: [0, (i + 0.5) * (h / 7), 0], r: [0, i * 4, 0], c: col(i), m: 'Slate' });
    t.wedgeF({ name: 'Scree', s: [50 * k, 26 * k, 26 * k], p: [0, 13 * k, -28 * k], face: 'front', c: col(2), m: 'Slate' });
    t.box({ name: 'ButteTop', s: [30 * k, 2, 26 * k], p: [0, h + 1, 0], c: P.mesaTop, m: 'Slate' });
  } else if (kind === 'Spire') {
    let x = 0;
    for (let i = 0; i < 9; i++) { x += (R() - 0.3) * 2.4 * k; t.box({ name: 'SpireRock', s: [(22 - i * 1.6) * k, 15 * k, (20 - i * 1.4) * k], p: [x, (7.5 + i * 14.5) * k, 0], r: [0, i * 13, 0], c: col(i), m: 'Slate' }); }
  } else if (kind === 'Arch') {
    // a natural stone arch: two legs and a span with a hole you can see the sky through
    for (const sd of [-1, 1]) for (let i = 0; i < 5; i++) t.box({ name: 'ArchLeg', s: [22 * k, 14 * k, 26 * k], p: [sd * (34 + i * 1.5) * k, (7 + i * 13.5) * k, 0], r: [0, 0, -sd * 4], c: col(i + (sd > 0 ? 1 : 0)), m: 'Slate' });
    t.box({ name: 'ArchSpan', s: [100 * k, 18 * k, 24 * k], p: [0, 75 * k, 0], c: col(3), m: 'Slate' });
    t.box({ name: 'ArchCrown', s: [70 * k, 10 * k, 20 * k], p: [0, 88 * k, 0], c: col(4), m: 'Slate' });
  }
  return g;
}


function buildMesaPass(Z, segs, at, R) {
  // the high road between two mesas
  const g = Z.group('MesaPass');
  const sg = segs.MesaPass;
  const L = sg.cum[sg.cum.length - 1];
  for (const side of [-1, 1]) {
    const pts = [];
    for (let s = 30; s < L - 45; s += 14) { const f = at('MesaPass', s, side * (sg.width / 2 + 7)); pts.push([f.p[0], f.p[2]]); } // clear of both forks
    E.cliffWall(g, side > 0 ? pts.reverse() : pts, { ...ARID, h: 26, d: 16, seed: 700 + side, slope: 2, colors: P.mesa, chunk: 12, name: 'PassWall' });
  }
  const f = at('MesaPass', 40);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  const c = g.at([f.base[0], f.base[1] + GROUND, f.base[2]], [0, yaw, 0]);
  E.signBoard(c, [17, 4, 2], 6, 1.6, 'MESA PASS', { color: '#fff2c4', color2: '#ff9a3a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [17, 2, 2.3], c: E.PAL.woodLo });
}

function buildGulch(Z, segs, at, R) {
  // Bone Gulch: layered sandstone walls, a giant skeleton half out of the cliff; the watering hole opens off the right
  const g = Z.group('BoneGulch');
  const left = [], right = [], rightB = [];
  for (let s = 250; s <= 462; s += 14) {
    const hw = segs.Plains.width / 2 + 5;
    const lf = at('Plains', s, -hw), rf = at('Plains', s, hw);
    left.push([lf.p[0], lf.p[2]]);
    if (s < DEN.s - 30) right.push([rf.p[0], rf.p[2]]);
    else if (s > DEN.s + 30) rightB.push([rf.p[0], rf.p[2]]);
  }
  E.cliffWall(g, left, { ...ARID, h: 34, d: 18, seed: 801, slope: 3, colors: P.mesa, chunk: 13, name: 'GulchWallL' });
  E.cliffWall(g, right.reverse(), { ...ARID, h: 36, d: 18, seed: 802, slope: 3, colors: P.mesa, chunk: 13, name: 'GulchWallR' });
  E.cliffWall(g, rightB.reverse(), { ...ARID, h: 36, d: 18, seed: 803, slope: 3, colors: P.mesa, chunk: 13, name: 'GulchWallR2' });
  // the gulch gate: two hoodoos and a fossil spine arching between them
  const f = at('Plains', 256);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  const c = g.at([f.base[0], f.base[1] + GROUND, f.base[2]], [0, yaw, 0]);
  for (const side of [-1, 1]) hoodoo(c, [side * 21, 0, 0], 22, 810 + side);
  for (let k = 0; k < 11; k++) {
    const a = (k / 10) * Math.PI;
    c.box({ name: 'ArchVertebra', s: [2.2, 2.2, 2.6], p: [-Math.cos(a) * 21, 22 + Math.sin(a) * 8, 0], r: [0, 0, E.deg(a) - 90], c: k % 2 ? P.bone : P.boneLo });
  }
  E.signBoard(c, [-26, 4, 3], 6, 1.6, 'BONE GULCH', { r: [0, 0, -4], color: '#fff2c4', color2: '#ff9a3a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [-26, 2, 3.3], c: E.PAL.woodLo });
  // the giant in the wall: ribs and a skull the size of a bus
  const fb = at('Plains', 300, -24);
  const sk = g.at([fb.p[0], GROUND, fb.p[2]], [0, yaw + 90, 0]);
  for (let k = 0; k < 9; k++) sk.box({ name: 'GiantRib', s: [0.9, 9 - Math.abs(k - 4) * 0.9, 0.9], p: [k * 2 - 8, 4.5, 0], r: [0, 0, 18], c: P.bone });
  sk.box({ name: 'GiantSpine', s: [20, 1.4, 1.4], p: [0, 8.6, 2.4], c: P.boneLo });
  sk.box({ name: 'GiantSkull', s: [6, 4.4, 9], p: [-13, 2.2, 1], r: [0, 18, 8], c: P.bone });
  sk.box({ name: 'GiantJaw', s: [5, 1.4, 7.6], p: [-13, 0.6, 0], r: [0, 18, 0], c: P.boneLo });
  for (let s = 270; s < 450; s += 22) for (const side of [-1, 1]) {
    const fr = at('Plains', s + R() * 8, side * (segs.Plains.width / 2 + 2.5));
    E.rock(g, [fr.p[0], GROUND, fr.p[2]], 0.9 + R() * 0.8, 81000 + s + side, { colors: P.mesa, moss: false });
  }
}

function buildHerdPlains(Z, segs, at, R) {
  // the Great Herds: wide open grass, lone conifers, game trails; the Sunset Stones ring the final stand
  const g = Z.group('GreatHerds');
  const fin = at(FINAL.seg, FINAL.s, FINAL.x);
  for (let k = 0; k < 8; k++) {
    const f = at('Plains', 470 + k * 28, (k % 2 ? 1 : -1) * (46 + R() * 34));
    if (Math.hypot(f.p[0] - fin.p[0], f.p[2] - fin.p[2]) < 44) continue;
    araucaria(g, [f.p[0], GROUND, f.p[2]], 26 + R() * 10, 82000 + k);
  }
  for (let k = 0; k < 10; k++) {
    const f = at('Plains', 480 + R() * 200, (R() > 0.5 ? 1 : -1) * (18 + R() * 50));
    // (top 0.10 over the grass: 0.04 over the grass patches it used to flicker against, 2026-10-14)
    for (let j = 0; j < 4; j++) g.box({ name: 'GameTrail', s: [2.6, 0.06, 5], p: [f.p[0] + j * 3.2, GROUND + 0.07, f.p[2] + j * 1.4], r: [0, 70, 0], c: P.dirtLo, shadow: false });
  }
  for (let k = 0; k < 11; k++) {
    const a = (k / 11) * Math.PI * 2;
    const p = [fin.p[0] + Math.cos(a) * 32, GROUND, fin.p[2] + Math.sin(a) * 32];
    if (Math.abs(Math.cos(a) * 32) < 9 && Math.sin(a) < 0) continue;
    hoodoo(Z, p, 9 + R() * 5, 83000 + k);
  }
  const sc = Z.at([fin.p[0], GROUND, fin.p[2] - 36], [0, 180, 0]);
  E.signBoard(sc, [0, 4.4, 0], 7, 2, 'SUNSET STONES', { color: '#fff2c4', color2: '#ff6a2a', twoSided: true, pps: 30, trim: '#ff6a2a' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: E.PAL.woodLo });
}

function buildSpineRidge(Z, segs, at, R, gaps) {
  const g = Z.group('SpineRidge');
  const sg = segs.SpineRidge;
  const L = sg.cum[sg.cum.length - 1];
  const inGap = (s) => gaps.some(([a, b]) => s > a - 2 && s < b + 2);
  for (let s = 0; s < L; s += 6) {
    const f = at('SpineRidge', s);
    if (f.base[1] < 1 || inGap(s)) continue;
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    // (2026-10-14: pitched with the road - level 7-stud blocks on the 1-in-7 descent stood 0.8 out of the road surface;
    // a stud deeper so the tilt never lifts an end off the grass)
    const pitch = E.deg(Math.atan2(at('SpineRidge', s + 3).base[1] - at('SpineRidge', s - 3).base[1], 6));
    g.at([f.base[0], GROUND, f.base[2]], [0, yaw, 0]).box({ name: 'Shelf', s: [sg.width + 6, f.base[1] + ROAD - GROUND - 0.4 + 1, 7], p: [0, (f.base[1] + ROAD - GROUND - 0.4) / 2 - 0.5, 0], r: [pitch, 0, 0], c: P.mesa[Math.floor(s / 6) % 5], m: 'Slate', collide: true });
  }
  for (const [a, b] of gaps) {
    const fa = at('SpineRidge', a), fb = at('SpineRidge', b), fm = at('SpineRidge', (a + b) / 2);
    const yaw = E.deg(Math.atan2(-fm.f[0], -fm.f[2]));
    for (const [fr, dir] of [[fa, 1], [fb, -1]]) {
      const yw = E.deg(Math.atan2(-fr.f[0], -fr.f[2]));
      g.at([fr.base[0], ROAD + fr.base[1], fr.base[2]], [0, yw, 0]).box({ name: 'JumpLip', s: [sg.width, 0.8, 1.6], p: [0, 0.1, -dir * 0.4], c: '#f2c230', studs: 'top' });
      g.at([fr.base[0], ROAD + fr.base[1], fr.base[2]], [0, yw, 0]).wedgeF({ name: 'Kicker', s: [sg.width - 4, 1.2, 4], p: [0, 0.6, -dir * -2], face: dir > 0 ? 'back' : 'front', c: '#9a7a5a', m: 'Slate' });
    }
    // a dry gorge with a giant's spine lying across the bottom
    const c = g.at([fm.base[0], GROUND, fm.base[2]], [0, yaw, 0]);
    c.box({ name: 'GorgeSand', s: [90, 0.3, b - a + 10], p: [0, 0.2, 0], c: P.sand, m: 'Sand', shadow: false });
    for (let k = 0; k < 12; k++) c.box({ name: 'GorgeVertebra', s: [2.6, 2, 2.6], p: [-30 + k * 5.4, 1.2, (R() - 0.5) * 3], r: [0, R() * 30, (R() - 0.5) * 20], c: k % 2 ? P.bone : P.boneLo });
    E.cliffWall(c, [[sg.width / 2 + 40, 22], [sg.width / 2 + 40, -22]], { ...ARID, h: 40, d: 22, seed: 833, slope: 3, chunk: 11, name: 'GorgeCliff', colors: P.mesa });
    for (let k = 0; k < 6; k++) E.rock(c, [(R() - 0.5) * 70, 0, (R() - 0.5) * (b - a)], 1.5 + R() * 1.5, 83300 + k, { colors: P.mesa, moss: false });
  }
}

function buildGrove(Z, segs, at, R) {
  // giant sequoias line the Grove Trail and stand around the Tall Grove nest (brachiosaurus browse here)
  const g = Z.group('TallGrove');
  const sg = segs.GroveTrail;
  const L = sg.cum[sg.cum.length - 1];
  for (let s = 14; s < L - 8; s += 22) {
    for (const side of [-1, 1]) {
      const f = at('GroveTrail', s + R() * 6, side * (sg.width / 2 + 7 + R() * 5));
      sequoia(g, [f.p[0], GROUND, f.p[2]], 46 + R() * 16, 84000 + Math.floor(s) * 2 + side, { w: 4 + R() * 1.4 });
    }
  }
  const n3 = NESTS[2];
  const nf = at(n3.seg, n3.s, n3.x);
  for (let k = 0; k < 7; k++) {
    const a = (k / 7) * Math.PI * 2 + 0.3;
    const r = 30 + R() * 8;
    const x = nf.p[0] + Math.cos(a) * r, z = nf.p[2] + Math.sin(a) * r;
    // keep the side facing the road open
    const toRoad = at(n3.seg, n3.s, 0);
    if (Math.hypot(x - toRoad.p[0], z - toRoad.p[2]) < 30) continue;
    sequoia(g, [x, GROUND, z], 58 + R() * 18, 84500 + k, { w: 5 + R() * 1.4 });
  }
}

// THE BONE YARD — the Plains Titan's (Giganotosaurus) lair: a sandstone bowl where the giants came to die. A colossal
// sauropod skeleton arches over the Titan's dais (named Throne so every ruler camera finds it), ledges against the wall,
// a rival's skull, three-toed tracks from the mouth to the dais, claw gashes in the rock. Markers drive the fight.
function buildBoneYard(Z, at, R, route) {
  const g = Z.group('BoneYard');
  const f = at(DEN.seg, DEN.s, DEN.x);
  const toRoad = Math.atan2(-(at(DEN.seg, DEN.s, 0).p[0] - f.p[0]), -(at(DEN.seg, DEN.s, 0).p[2] - f.p[2]));
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, E.deg(toRoad), 0]); // local -Z points at the road
  const rock = ['#b0683a', '#9a5832', '#c27a48', '#8a4a2a'];
  c.cyl({ name: 'YardFloor', axis: 'y', len: 0.2, d: 86, p: [0, 0.1, 0], c: '#b8946a', m: 'Sand', shadow: false });
  // floor decals in steps of >= 0.04 so none flickers against another (2026-10-14: floor 0.20, scuffs 0.25, cracks and
  // tracks 0.29 - the cracks sat 0.015 over the scuffs, the scuffs 0.035 over the floor)
  for (let k = 0; k < 22; k++) c.box({ name: 'DryCrack', s: [0.35, 0.06, 5 + R() * 7], p: [(R() - 0.5) * 66, 0.26, (R() - 0.5) * 66], r: [0, R() * 180, 0], c: '#7a5a3a', shadow: false });
  for (let k = 0; k < 10; k++) c.box({ name: 'Scuff', s: [7 + R() * 6, 0.05, 2.4 + R() * 2], p: [(R() - 0.5) * 50, 0.225, (R() - 0.5) * 50], r: [0, R() * 180, 0], c: '#a07e56', shadow: false });
  // the bowl: a sandstone ring with its mouth open toward the road
  const ring = [];
  for (let a = 46; a <= 314; a += 18) { const rad = (a * Math.PI) / 180; ring.push(c.wpt([Math.sin(rad) * 43, 0, -Math.cos(rad) * 43])); }
  E.cliffWall(Z, ring.map((p) => [p[0] - GP_ORIGIN[0], p[2] - GP_ORIGIN[2]]), { ...ARID, h: 30, d: 16, seed: 931, slope: 3, colors: rock, chunk: 10, name: 'YardWall' });
  // claw gashes raked across the inner wall
  for (let k = 0; k < 7; k++) {
    const a = 1.1 + (k / 6) * (Math.PI * 2 - 2.2);
    const wc = c.at([Math.sin(a) * 41.2, 6 + R() * 10, -Math.cos(a) * 41.2], [0, -E.deg(a) + 180, 0]);
    for (let j = 0; j < 3; j++) wc.box({ name: 'ClawGash', s: [0.5, 7, 0.4], p: [-1.4 + j * 1.4, 0, 0], r: [0, 0, 18], c: '#5a3220' });
  }
  // ledges against the wall (sandstone stacks with flat tops)
  const ledgeAt = [[-27, 18, 11], [27, 16, 13], [-33, -8, 9], [33, -6, 10]];
  ledgeAt.forEach(([x, z, h], i) => {
    const lc = c.at([x, 0, z]);
    for (let t = 0; t < 4; t++) lc.box({ name: 'LedgeRock', s: [8 - t * 0.6, h / 4 + 0.2, 8 - t * 0.6], p: [0, (t + 0.5) * (h / 4), 0], r: [0, t * 15 + R() * 10, 0], c: rock[t % 4], m: 'Slate', studs: 'top', collide: true });
    lc.box({ name: 'LedgeTop', s: [6, 0.6, 6], p: [0, h + 0.3, 0], c: P.mesaTop, m: 'Slate', studs: 'top', collide: true });
    lc.box({ name: 'LedgeBone', s: [2.4, 0.4, 0.4], p: [(R() - 0.5) * 3, h + 0.8, (R() - 0.5) * 3], r: [0, R() * 180, 0], c: P.bone });
    marker(lc, 'DenLedge' + (i + 1), [0, h + 0.6, 0], 0, { s: [2, 0.4, 2] });
  });
  // the dais: a broad flat sandstone slab the Titan stands on
  const th = c.at([0, 0, 22]);
  th.box({ name: 'Throne', s: [16, 4, 12], p: [0, 2, 0], c: '#a8683e', m: 'Slate', studs: 'top', collide: true });
  th.box({ name: 'ThroneStep', s: [20, 1.6, 15], p: [0, 0.8, 0.6], c: '#9a5832', m: 'Slate', studs: 'top', collide: true });
  // ...under the ribs of the biggest thing that ever died here
  const rc = c.at([0, 0, 23]);
  for (let i = 0; i < 7; i++) {
    const z = (i - 3) * 4.6;
    const t = 1 - Math.abs(i - 3) / 4.5;
    for (const side of [-1, 1]) boneArc(rc, z, 17 * (0.86 + 0.14 * t), 27 * (0.72 + 0.28 * t), 1.5, { side, n: 7 });
  }
  for (let i = 0; i < 10; i++) {
    const z = (i - 4.5) * 3.3;
    const y = 27 * (0.72 + 0.28 * Math.max(0, 1 - Math.abs(i - 4.5) / 6)) + 0.4;
    rc.box({ name: 'Vertebra', s: [3.2, 2.8, 2.8], p: [0, y, z], r: [0, R() * 8, 0], c: i % 2 ? P.bone : P.boneLo });
    rc.box({ name: 'DorsalSpine', s: [0.8, 3, 1.2], p: [0, y + 2.6, z], r: [(R() - 0.5) * 14, 0, 0], c: P.bone });
  }
  // its skull, fallen against the wall to the left of the dais
  const sk = c.at([-22, 0, 30], [0, 140, 0]);
  sk.box({ name: 'TitanSkull', s: [7, 5.6, 11], p: [0, 2.8, 0], r: [0, 0, 8], c: P.bone, collide: true });
  sk.box({ name: 'TitanJaw', s: [6, 1.6, 9.6], p: [0, 0.8, -1], c: P.boneLo, collide: true });
  for (const sd of [-1, 1]) sk.box({ name: 'EyeSocket', s: [0.4, 1.8, 2], p: [sd * 3.5, 3.8, -1.4], c: '#4a3a2a' });
  // a rival theropod's skull, teeth up, half sunk in the floor
  const rv = c.at([20, 0, 6], [0, -35, 0]);
  rv.box({ name: 'RivalSkull', s: [4, 3.6, 8], p: [0, 1.4, 0], r: [-14, 0, 22], c: P.bone, collide: true });
  for (let k = 0; k < 6; k++) rv.box({ name: 'Tooth', s: [0.5, 1.4, 0.5], p: [1.4, 3.2 - k * 0.15, -3 + k * 1.1], r: [0, 0, 22], c: '#fff6e0' });
  for (let k = 0; k < 9; k++) c.box({ name: 'LooseBone', s: [0.9, 0.9, 3 + R() * 4], p: [(R() - 0.5) * 60, 0.5, (R() - 0.5) * 50], r: [0, R() * 180, R() * 20], c: k % 2 ? P.bone : P.boneLo });
  // the Titan's tracks: three-toed prints from the mouth to the dais
  for (let k = 0; k < 9; k++) {
    const pc = c.at([(k % 2 ? 2.8 : -2.8), 0.26, -34 + k * 6], [0, (k % 2 ? 8 : -8), 0]);
    pc.box({ name: 'TrackHeel', s: [2.4, 0.06, 2.2], p: [0, 0, 0.8], c: '#7a5a3a', shadow: false });
    for (const a of [-26, 0, 26]) pc.at([0, 0, -0.2], [0, a, 0]).box({ name: 'TrackToe', s: [0.9, 0.06, 3.2], p: [0, 0, -1.6], c: '#7a5a3a', shadow: false });
  }
  // warm light pooled under the ribs, dust always drifting through
  const glow = th.box({ name: 'DaisGlow', s: [1, 1, 1], p: [0, 14, -4], t: 1, shadow: false });
  E.pointLight(glow, [1, 0.62, 0.32], 34, 1.3);
  const dust = c.box({ name: 'YardDust', s: [60, 1, 60], p: [0, 1, 0], t: 1, shadow: false });
  dust.set('CanQuery', 'bool', false);
  E.particles(dust, 'Dust', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 3, life: [6, 9], speed: [1, 3], spread: [60, 60], size: [[0, 4], [1, 10]], transp: [[0, 0.75], [1, 1]], color: [0.86, 0.72, 0.52], emission: 0, accel: [1.5, 0.4, 0] });
  // a sign at the mouth
  const mouth = at(DEN.seg, DEN.s, 24);
  const sc = Z.at([mouth.p[0], GROUND, mouth.p[2]], [0, E.deg(toRoad) + 180, 0]);
  E.signBoard(sc, [-7, 4.6, 0], 9, 2.2, 'THE BONE YARD', { color: '#fff2c4', color2: '#ff6a2a', twoSided: true, pps: 30, trim: '#ff6a2a' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [-7, 2.2, 0.3], c: E.PAL.woodLo });
  for (const sd of [-1, 1]) sc.box({ name: 'TuskPost', s: [1.2, 9, 1.2], p: [-7 + sd * 6.4, 4.2, 0], r: [0, 0, -sd * 12], c: P.bone });
  // (2026-10-14) the way in: a broad sandstone apron from the road's edge down into the mouth, the tusks planted in its
  // foot. The road runs past the mouth on a bank 1-5 studs up; the old way down was the swell terraces that cut into the
  // floor. Its high edge tucks 0.3 under the road, rolled to the road's grade so it meets the surface along its width.
  // It also holds the Titan reveal's low "herd bolts past" lens (GT_Stampede, ~4 left of the axis) above the road.
  // Filed under Roads: it's part of the drive (road clearance leaves it be)
  {
    const segs = route.segs, GX = 1.5, HW = 10.5, EDGE = -(DEN.x - segs.Plains.width / 2); // centre/half-width (local x), road edge (local z)
    const roadY = (lx) => { const w = c.wpt([lx, 0, EDGE]); const sg = segs.Plains; const pr = RT.project(sg.samples, sg.cum, [w[0] - GP_ORIGIN[0], 0, w[2] - GP_ORIGIN[2]]); return ROAD + at(DEN.seg, pr.s).base[1]; };
    const yL = roadY(GX - HW), yR = roadY(GX + HW);
    const top = (yL + yR) / 2 - 0.08 - GROUND, bot = -0.6; // local (c sits at GROUND), 0.08 under the road (no flicker where it tucks in); the low end stays buried
    const run = Math.max(9, (top - 0.2) / 0.25); // meets the floor (0.2) at least 9 studs in, no steeper than ~14 deg
    const slope = (top - 0.2) / run, len = (top - bot) / slope;
    const rc = c.at([GX, 0, EDGE - 0.3], [0, 0, E.deg(Math.atan2(yR - yL, 2 * HW))]);
    const roadsF = Z.parent.children.find((i) => i.name === 'Roads');
    rc.into(roadsF).wedgeF({ name: 'YardRamp', s: [2 * HW, top - bot, len], p: [0, (top + bot) / 2, len / 2], face: 'back', c: '#b8946a', m: 'Sand', collide: true });
    // verge stones / bones / gulch rocks standing where the ramp now runs go (they'd poke out of its slope)
    const inv = rc.frame.inv();
    const onRamp = (cf) => { const q = inv.mul(cf); return Math.abs(q.x) < HW + 1.5 && q.z > -1 && q.z < len + 1; };
    for (const host of [roadsF, Z.parent.children.find((i) => i.name === 'BoneGulch')]) {
      if (!host) continue;
      host.children = host.children.filter((ch) => {
        const cf = ch._cf || (ch.children.find((k) => k._cf) || {})._cf;
        return !(cf && /^(EdgeStone|EdgeBone|Rock)$/.test(ch.name) && onRamp(cf));
      });
    }
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

// weather: dust devils wandering the open grass and a low dust haze rolling over the salt flats
function buildWeather(Z, at, R) {
  const g = Z.group('Weather', 'Folder');
  const spots = [[60, 200], [-120, -120], [180, -40], [-60, 140], [240, 120], [40, -60]];
  spots.forEach(([x, z], k) => {
    const h = g.box({ name: 'DustDevil', s: [2, 1, 2], p: [x, GROUND + 0.5, z], t: 1, shadow: false });
    h.set('CanQuery', 'bool', false);
    E.particles(h, 'Column', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 14, life: [2.5, 4], speed: [7, 11], dir: 1, spread: [7, 7], size: [[0, 1.5], [0.5, 5], [1, 10]], transp: [[0, 0.55], [0.7, 0.75], [1, 1]], color: [0.84, 0.7, 0.5], emission: 0, accel: [0, 2, 0], drag: 0.6 });
    E.particles(h, 'Grit', { rate: 10, life: [1, 2], speed: [4, 8], dir: 1, spread: [30, 30], size: [[0, 0.3], [1, 0.1]], color: [0.7, 0.55, 0.36], emission: 0, accel: [0, -4, 0] });
    h.attr('Wander', 18 + k * 3);
  });
  const fl = at(FLATS.seg, (FLATS.s0 + FLATS.s1) / 2);
  const haze = g.box({ name: 'FlatsHaze', s: [150, 1, 90], p: [fl.p[0], GROUND + 1, fl.p[2]], t: 1, shadow: false });
  haze.set('CanQuery', 'bool', false);
  E.particles(haze, 'Haze', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 4, life: [8, 12], speed: [1, 2], dir: 1, spread: [80, 80], size: [[0, 10], [1, 22]], transp: [[0, 0.82], [1, 1]], color: [1, 0.95, 0.86], emission: 0.1 });
}


function buildCinematics(Z, at) {
  const g = Z.group('Cinematics', 'Folder');
  const shot = (name, pos, look) => {
    const l = Z.wpt(look);
    const m = marker(g, name, pos, 0, { s: [1, 1, 1] });
    m.attr('LookX', +l[0].toFixed(2)).attr('LookY', +l[1].toFixed(2)).attr('LookZ', +l[2].toFixed(2));
    return m;
  };
  const den = at(DEN.seg, DEN.s, DEN.x);
  const denRoad = at(DEN.seg, DEN.s, -12);
  const grove = at(NESTS[2].seg, NESTS[2].s, NESTS[2].x);
  const flats = at(FLATS.seg, 60);
  shot('EstShot1', [-60, 70, 420], [40, 30, 40]);
  shot('EstShot2', [flats.p[0] + 30, 18, flats.p[2] - 40], [grove.p[0], 24, grove.p[2]]);
  shot('EstShot3', [OLD_GIANT[0] - 110, 26, OLD_GIANT[2] + 90], [OLD_GIANT[0], 60, OLD_GIANT[2]]);
  shot('EstShot4', [denRoad.p[0], 46, denRoad.p[2]], [den.p[0], 10, den.p[2]]);
}

function buildNestSite(Z, n, at, R) {
  const f = at(n.seg, n.s, n.x);
  const g = Z.group('Nest_' + n.species);
  g.parent.attr('NestId', n.id).attr('Species', n.species).tag('ExpeditionNest');
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, R() * 360, 0]);
  const big = n.species === 'Brachiosaurus';
  c.cyl({ name: 'Clearing', axis: 'y', len: 0.1, d: big ? 30 : 24, p: [0, 0.05, 0], c: '#a8845a', m: 'Sand', shadow: false });
  // a mound nest of earth and ferns (plant-eaters build mounds)
  c.cyl({ name: 'NestMound', axis: 'y', len: 1.2, d: big ? 12 : 9, p: [0, 0.6, 0], c: '#8a6a40', m: 'Sand' });
  for (let k = 0; k < 16; k++) {
    const a = (k / 16) * Math.PI * 2;
    const r = big ? 5.8 : 4.4;
    c.box({ name: 'NestFrond', s: [3, 0.5, 1.2], p: [Math.cos(a) * r, 1.2 + (k % 2) * 0.3, Math.sin(a) * r], r: [R() * 20, -E.deg(a) + 90, R() * 15], c: P.cycad[k % 3] });
  }
  for (let k = 0; k < 3; k++) {
    const egg = buildEgg(n.species);
    B.scaleTree(egg, big ? 0.8 : 0.6);
    const a = (k / 3) * Math.PI * 2;
    B.transformTree(egg, c.frame.mul(new CF(Math.cos(a) * 1.3, 1.4, Math.sin(a) * 1.3)).mul(CF.deg(0, k * 40, (k - 1) * 8)));
    egg.tags = [];
    egg.name = 'NestEgg';
    g.parent.add(egg);
  }
  // (2026-10-13: the flag stood right on GuardSpot1 - the first guard (a raptor) was impaled on its pole in every
  // scene. Now midway between two guard spots, outside the guard ring and the clearing)
  E.flag(c, [0.37, 0, 16], '#ff9a3a', { h: 7 });
  const sgn = Z.at([f.base[0] - f.r[0] * (n.x > 0 ? -21 : 21), GROUND, f.base[2] - f.r[2] * (n.x > 0 ? -21 : 21)], [0, E.deg(Math.atan2(-f.f[0], -f.f[2])) + 180, 0]);
  E.signBoard(sgn, [0, 4.2, 0], 7, 2.2, n.label, { color: '#fff2c4', color2: '#ff6a2a', twoSided: true, pps: 30, trim: '#ff6a2a' });
  sgn.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
  for (let k = 0; k < 3; k++) {
    const a = (k / 3) * Math.PI * 2 + 0.5;
    const m = c.box({ name: 'GuardSpot' + (k + 1), s: [1.5, 1, 1.5], p: [Math.cos(a) * (big ? 12 : 9), 0.5, Math.sin(a) * (big ? 12 : 9)], r: [0, -E.deg(a) - 90, 0], t: 1, shadow: false });
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
  E.pointLight(host, [1, 0.82, 0.5], 18, 0.8); // a warm glow so every nest reads as a landmark (and lights cutscenes)
  // a few boulders and cycads for cover around the clearing
  for (let k = 0; k < 5; k++) {
    const a = (k / 5) * Math.PI * 2 + 0.9;
    const r = big ? 20 : 15;
    const x = Math.cos(a) * r, z = Math.sin(a) * r;
    if (k % 2) E.rock(c, [x, 0, z], 1.6 + R(), 85000 + n.id * 10 + k, { colors: P.mesa, moss: false });
    else cycad(c, [x, 0, z], 2.5 + R() * 2, 85100 + n.id * 10 + k);
  }
}

// ------------------------------------------------------------------ Luau data
function routeData(route, at) {
  const O = GP_ORIGIN;
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
  const arrival = at('GoldenRoad', 4);
  return {
    Zone: 'GiantPlains', Name: 'GIANT PLAINS', Era: '150,000,000 BC', Year: -150000000,
    Variants: variants, Forks: forks, Features: features, Sections: sections, Nests: nests,
    Arrival: [arrival.p[0] + O[0], ROAD, arrival.p[2] + O[2], arrival.f[0], arrival.f[2]],
  };
}

module.exports = { buildGiantPlains, GP_ORIGIN };
