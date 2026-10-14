// RED CLIFFS — the fourth era (75,000,000 BC). The Gobi at golden dusk, "where the first dinosaur nests were dug up".
// A great plateau of layered red sandstone (red / orange / cream strata, aligned across every cliff, butte, hoodoo
// and the arch) stands in the middle of a sand sea; the roads run round it.
//   Dune Road (under the Great Arch) → fork: Dune Sea (rolling sand waves, a jump over a blowout) | Egg Ledges (a
//   shelf road up the plateau's west face; Thief's Ledge / Oviraptor) → Dry Wash (saxaul scrub, Dune Burrows /
//   Protoceratops, the Fighting Dinosaurs fossil wall, the hidden Scythe Grove opens off the right) → fork: Runner
//   Flats (open clay pan, Gallimimus) | Hoodoo Maze → Homestretch (the Claw Ring, final stand) → Return Portal.
//   A sandstorm wall stands on the east horizon; dust devils wander the flats.
// Zone-local space: origin = RC_ORIGIN, north = -Z.
const { Inst, Ctx, CF, shade, rng } = require('./builder.js');
const E = require('./env.js');
const RT = require('./route.js');
const NPC = require('./npcs.js');
const { buildEgg } = require('./eggs.js');
const B = require('./builder.js');

const RC_ORIGIN = [2100, 0, -900];
const GROUND = 0.5, ROAD = 0.62;
const BX = 400, BZ0 = -390, BZ1 = 412;
const CELL = 12;
const P = {
  sand: ['#e8b576', '#eebf82', '#e2aa6a', '#f2c98e'], duneTone: ['#dc9f62', '#e6b073', '#eebf84', '#f4cd96'], crest: '#f4d29a', sandSide: '#d99c5e', sandLo: '#cf9256',
  rockTop: ['#d4884a', '#dc9654', '#c97c42'], ledgeTop: '#dfa062', plateauTop: ['#cf7f45', '#d88b4e', '#c47440'],
  road: '#9c563a', roadHi: '#a8603f', rut: '#7c4330',
  mud: ['#d2a47a', '#c99a70', '#dab088', '#c4946a'], crack: '#8a5a3c', clay: ['#ecc9a2', '#e6bf96', '#f0d2ae'], clayCrack: '#c9a07a',
  bone: '#f2e6c8', boneLo: '#e2d2ae', boneDk: '#c9b48a',
  saxTrunk: ['#8a7862', '#74624c', '#9a8870'], saxLeaf: ['#8f9c4c', '#a3ac5a', '#7d8c40', '#b4b46a'],
  grass: ['#4f9a3c', '#5aa844', '#468e36', '#62b04a'], leaf: ['#3f8f3a', '#4fa043', '#2f7a34', '#5cb04a'],
  conifer: ['#2e5e30', '#376a36', '#285430', '#41763a'], bark: ['#6e4a2e', '#5e3e26', '#7a5434'],
  water: '#4fb8c8', matrix: '#8a4630', matrixLo: '#76392a', cap: '#7a3626', capHi: '#8e4430',
  canvas: '#e8d6aa', canvasLo: '#d4bf8e', wood: '#8a5a33', woodLo: '#6e4628', rope: '#c8a870',
  tuft: ['#d8b866', '#c9a756', '#e4c97c', '#b9a058'],
};
// the strata: one band table for the whole era, in absolute height, so every cliff, butte, hoodoo and the arch line
// up like real layered sandstone. Thin cream bands read as bright stripes across the red.
const BANDS = [
  [5, '#b4472e'], [10, '#d2663a'], [13, '#f0d6a6'], [20, '#c4502e'], [26, '#e3863f'], [29, '#f3deb2'],
  [36, '#a63f2a'], [42, '#d06a3a'], [45, '#efd3a2'], [52, '#c8542f'], [58, '#e7974f'], [61, '#f4e2bc'],
  [68, '#b84a2e'], [74, '#d2663a'], [77, '#efd3a2'], [84, '#a63f2a'], [90, '#cf6234'], [93, '#f0d6a6'],
  [104, '#bf4c2e'], [114, '#dc7a3e'], [118, '#f0d6a6'], [1e9, '#b4472e'],
];
const bandIdx = (y) => { for (let k = 0; k < BANDS.length; k++) if (y < BANDS[k][0]) return k; return BANDS.length - 1; };
const bandColor = (y) => BANDS[bandIdx(y)][1];
const isCream = (k) => BANDS[k][0] - (k ? BANDS[k - 1][0] : 0) <= 4;
const bandMat = (k) => (isCream(k) ? 'Concrete' : 'Slate');
// split [y0, y1] (absolute) at band edges: fn(a, b, color, material, bandIndex)
function bands(y0, y1, fn, maxH = 1e9) {
  let y = y0;
  while (y < y1 - 0.05) {
    const k = bandIdx(y + 0.01);
    const top = Math.min(y1, BANDS[k][0], y + maxH);
    fn(y, top, BANDS[k][1], bandMat(k), k);
    y = top;
  }
}
function marker(ctx, name, p, yaw = 0, o = {}) {
  const m = ctx.box({ name, s: o.s || [1, 1, 1], p, r: [0, yaw, 0], t: 1, shadow: false, c: '#ffffff' });
  m.set('CanQuery', 'bool', false);
  m.set('CanCollide', 'bool', false);
  return m;
}
const smooth = (e0, e1, v) => { const t = Math.max(0, Math.min(1, (v - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };
const yawOf = (f) => E.deg(Math.atan2(-f.f[0], -f.f[2]));

const DEF = {
  start: 'Arrival',
  nodes: { Arrival: { tangent: [0, 0, -1] }, ForkA: {}, MergeA: {}, ForkB: {}, MergeB: {}, Exit: {} },
  segments: {
    DuneRoad: { from: 'Arrival', to: 'ForkA', width: 28, name: 'DUNE ROAD', pts: [[-160, 0, 340], [-158, 0, 272], [-150, 0, 200], [-154, 0, 128], [-162, 0, 60]] },
    EggLedges: { from: 'ForkA', to: 'MergeA', width: 22, name: 'EGG LEDGES', pts: [[-162, 0, 60], [-134, 3, 16], [-116, 9, -36], [-112, 15, -96], [-128, 12, -148], [-166, 4, -186], [-200, 0, -208]] },
    DuneSea: { from: 'ForkA', to: 'MergeA', width: 24, name: 'DUNE SEA', pts: [[-162, 0, 60], [-214, 2, 8], [-254, 5, -58], [-262, 5, -124], [-236, 2, -178], [-200, 0, -208]] },
    DryWash: { from: 'MergeA', to: 'ForkB', width: 28, name: 'DRY WASH', pts: [[-200, 0, -208], [-188, 0, -258], [-130, 0, -286], [-40, 0, -294], [50, 0, -286], [130, 0, -262], [200, 0, -212], [240, 0, -140], [252, 0, -64]] },
    HoodooMaze: { from: 'ForkB', to: 'MergeB', width: 22, name: 'HOODOO MAZE', pts: [[252, 0, -64], [212, 0, -14], [224, 0, 46], [192, 0, 104], [214, 0, 166], [270, 0, 226]] },
    RunnerFlats: { from: 'ForkB', to: 'MergeB', width: 28, name: 'RUNNER FLATS', pts: [[252, 0, -64], [300, 0, -4], [326, 0, 76], [322, 0, 156], [270, 0, 226]] },
    Homestretch: { from: 'MergeB', to: 'Exit', width: 28, name: 'HOMESTRETCH', pts: [[270, 0, 226], [236, 0, 282], [160, 0, 316], [70, 0, 334]] },
  },
};

const SECTIONS = [
  ['DuneRoad', 0, 'DUNE ROAD'], ['DuneRoad', 70, 'THE GREAT ARCH'], ['DuneSea', 0, 'DUNE SEA'], ['EggLedges', 0, 'EGG LEDGES'],
  ['DryWash', 0, 'DRY WASH'], ['DryWash', 190, 'FOSSIL WALL'], ['HoodooMaze', 0, 'HOODOO MAZE'], ['RunnerFlats', 0, 'RUNNER FLATS'],
  ['Homestretch', 0, 'HOMESTRETCH'],
];
const NESTS = [
  { id: 1, species: 'Oviraptor', seg: 'EggLedges', s: 178, x: 27, guard: 'Pack', label: "THIEF'S LEDGE" },
  { id: 2, species: 'Protoceratops', seg: 'DryWash', s: 112, x: -38, guard: 'Herd', label: 'DUNE BURROWS' },
  { id: 3, species: 'Gallimimus', seg: 'RunnerFlats', s: 150, x: -36, guard: 'Herd', label: 'RUNNER FLATS' },
];
const FEATURES = [
  ['Darts', 'DuneRoad', 200, -6], ['Darts', 'EggLedges', 120, 0], ['Darts', 'DuneSea', 90, 0], ['Darts', 'DryWash', 40, 6], ['Darts', 'DryWash', 590, 0],
  ['Darts', 'HoodooMaze', 300, 0], ['Darts', 'RunnerFlats', 300, 6], ['Darts', 'Homestretch', 160, 6],
  // dune road: under the arch
  ['Boost', 'DuneRoad', 40, 0], ['Coin', 'DuneRoad', 92, 0], ['Coin', 'DuneRoad', 98, 0], ['Coin', 'DuneRoad', 104, 0], ['Repair', 'DuneRoad', 250, 7],
  // dune sea: over the sand waves and the blowout jump
  ['Coin', 'DuneSea', 50, -5], ['Coin', 'DuneSea', 56, -5], ['Boost', 'DuneSea', 125, 0], ['Jump', 'DuneSea', 168, 0, { len: 34 }],
  ['Coin', 'DuneSea', 176, 0], ['Coin', 'DuneSea', 182, 0], ['Coin', 'DuneSea', 188, 0], ['Repair', 'DuneSea', 262, 0],
  // egg ledges: the shelf road
  ['Coin', 'EggLedges', 60, 4], ['Coin', 'EggLedges', 66, 4], ['Boost', 'EggLedges', 225, 0], ['Coin', 'EggLedges', 262, -3], ['Coin', 'EggLedges', 268, -3], ['Repair', 'EggLedges', 292, -4],
  // the wash
  ['Coin', 'DryWash', 76, -6], ['Coin', 'DryWash', 82, -6], ['Charge', 'DryWash', 150, 0, { len: 40 }], ['Boost', 'DryWash', 230, 0],
  ['Repair', 'DryWash', 330, 8], ['Coin', 'DryWash', 400, 0], ['Coin', 'DryWash', 406, 0], ['Boost', 'DryWash', 470, 0], ['Coin', 'DryWash', 540, -7], ['Coin', 'DryWash', 546, -7],
  // hoodoo maze
  ['Coin', 'HoodooMaze', 40, 0], ['Coin', 'HoodooMaze', 46, 0], ['Repair', 'HoodooMaze', 120, 0], ['Boost', 'HoodooMaze', 170, 0], ['Coin', 'HoodooMaze', 230, 4], ['Coin', 'HoodooMaze', 236, 4], ['Coin', 'HoodooMaze', 242, 4],
  // runner flats: the herd runs with you
  ['Boost', 'RunnerFlats', 40, 0], ['Coin', 'RunnerFlats', 80, 7], ['Coin', 'RunnerFlats', 86, 7], ['Repair', 'RunnerFlats', 115, 6], ['Stampede', 'RunnerFlats', 230, 0, { len: 50 }],
  ['Boost', 'Homestretch', 40, 0], ['Coin', 'Homestretch', 120, -6], ['Coin', 'Homestretch', 126, -6], ['Coin', 'Homestretch', 200, 0], ['Coin', 'Homestretch', 206, 0],
];
// SCYTHE GROVE: the Therizinosaurus den, a green spring grove in a box canyon cut into the plateau's north face
const GROVE = { x: 98, z: -188, r: 46 };
const FINAL = { seg: 'Homestretch', s: 82, x: 50 }; // the Claw Ring
const ARCH = { seg: 'DuneRoad', s: 96 };
const RELIEF = { x: -20, z: -341 }; // front face of the Fighting Dinosaurs wall (faces south, over the wash)
// the plateau: a rough outline (x, z), the cliffs rise inside it
const PLATEAU = [
  [-112, 196], [-114, 120], [-116, 62], [-112, 22], [-97, -36], [-92, -96], [-106, -146], [-128, -186], [-92, -226], [-30, -238],
  [40, -236], [150, -214], [184, -168], [170, -110], [162, -40], [164, 30], [152, 90], [140, 150], [108, 198], [48, 222], [-20, 226], [-80, 216],
];
const BUTTES = [[-218, 262, 22, 46], [-300, 128, 26, 54], [-334, -110, 20, 40], [-46, 300, 22, 34], [334, -262, 26, 50], [-300, -300, 24, 44], [118, 270, 16, 28], [358, 300, 18, 32]];

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
// signed distance to a polygon outline (>0 inside)
function polySD(x, z, poly) {
  let inside = false, best = Infinity;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, zi] = poly[i], [xj, zj] = poly[j];
    if ((zi > z) !== (zj > z) && x < ((xj - xi) * (z - zi)) / (zj - zi) + xi) inside = !inside;
    const dx = xj - xi, dz = zj - zi;
    const t = Math.max(0, Math.min(1, ((x - xi) * dx + (z - zi) * dz) / (dx * dx + dz * dz)));
    best = Math.min(best, Math.hypot(x - xi - dx * t, z - zi - dz * t));
  }
  return inside ? best : -best;
}

// ------------------------------------------------------------------ props of the Gobi
// saxaul: the gnarled desert scrub tree (grey crooked limbs, olive tufts)
function saxaul(ctx, p, k, seed) {
  const R = rng(seed);
  const g = ctx.group('Saxaul');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = 2 + Math.floor(R() * 2);
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + R();
    const h1 = (1.5 + R() * 1.2) * k;
    const lean = (0.35 + R() * 0.4) * h1;
    const top = [Math.cos(a) * lean, h1, Math.sin(a) * lean];
    t.beam([0, 0, 0], top, 0.5 * k, 0.5 * k, { name: 'SaxaulTrunk', c: P.saxTrunk[i % 3], extend: 0.3 });
    const top2 = [top[0] * 1.6 + (R() - 0.5) * k, h1 + (0.8 + R() * 0.8) * k, top[2] * 1.6 + (R() - 0.5) * k];
    t.beam(top, top2, 0.34 * k, 0.34 * k, { name: 'SaxaulBranch', c: P.saxTrunk[(i + 1) % 3], extend: 0.2 });
    t.box({ name: 'SaxaulLeaves', s: [(1.7 + R()) * k, (0.8 + R() * 0.4) * k, (1.7 + R()) * k], p: top2, r: [0, R() * 90, 0], c: P.saxLeaf[Math.floor(R() * 4)], studs: 'top' });
  }
  return g;
}
// a sandstone hoodoo: banded column with a pinched waist and a dark hard cap (or a balanced boulder)
function hoodoo(ctx, p, h, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group('Hoodoo');
  const t = g.at(p, [0, R() * 360, 0]);
  const w0 = o.w || (3.2 + h * 0.07);
  const waist = o.balanced ? 0.55 : 0.32;
  let i = 0;
  bands(p[1], p[1] + h, (a, b, col, mat) => {
    const u = ((a + b) / 2 - p[1]) / h;
    const w = w0 * (1 - waist * Math.sin(u * Math.PI * 0.95)) * (0.92 + R() * 0.16);
    t.box({ name: 'HoodooRock', s: [w, b - a + 0.05, w * (0.85 + R() * 0.2)], p: [(R() - 0.5) * 0.4, (a + b) / 2 - p[1], (R() - 0.5) * 0.4], r: [0, i * 17, 0], c: col, m: mat, studs: 'top', collide: i < 2 });
    i++;
  }, 4.5);
  if (o.balanced) {
    t.box({ name: 'HoodooCap', s: [w0 * 1.5, w0 * 0.9, w0 * 1.3], p: [0.4, h + w0 * 0.42, 0], r: [6, 20, 10], c: P.cap, m: 'Slate', studs: 'top' });
  } else {
    t.box({ name: 'HoodooCap', s: [w0 * 1.35, 1.4, w0 * 1.3], p: [0, h + 0.7, 0], r: [0, 25, 4], c: P.cap, m: 'Slate', studs: 'top' });
    if (R() > 0.4) t.box({ name: 'HoodooCap', s: [w0 * 0.7, 1.1, w0 * 0.7], p: [0.3, h + 1.9, 0.2], r: [0, 50, -3], c: P.capHi, m: 'Slate', studs: 'top' });
  }
  return g;
}
// a sandstone fin: a thin tall banded wall with a ragged top
function fin(ctx, p, yaw, len, h, seed) {
  const R = rng(seed);
  const g = ctx.group('SandFin');
  const t = g.at(p, [0, yaw, 0]);
  const n = Math.max(2, Math.round(len / 5));
  for (let k = 0; k < n; k++) {
    const hh = h * (0.55 + 0.45 * Math.sin(((k + 0.5) / n) * Math.PI)) * (0.85 + R() * 0.3);
    bands(p[1], p[1] + hh, (a, b, col, mat) => t.box({ name: 'HoodooRock', s: [len / n + 0.4, b - a + 0.05, 3.2 + R() * 0.8], p: [-len / 2 + (k + 0.5) * (len / n), (a + b) / 2 - p[1], (R() - 0.5) * 0.5], c: col, m: mat, studs: 'top', collide: a - p[1] < 6 }), 6);
  }
  return g;
}
function bones(ctx, p, seed, k = 1) {
  const R = rng(seed);
  const g = ctx.group('Bones');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = 2 + Math.floor(R() * 3);
  for (let i = 0; i < n; i++) {
    const L = (2 + R() * 2.4) * k;
    const c = t.at([(R() - 0.5) * 3 * k, 0.25 * k, (R() - 0.5) * 3 * k], [0, R() * 180, (R() - 0.5) * 10]);
    c.box({ name: 'Bone', s: [0.45 * k, 0.45 * k, L], c: i % 2 ? P.bone : P.boneLo });
    for (const e of [-1, 1]) c.box({ name: 'BoneKnob', s: [0.75 * k, 0.6 * k, 0.6 * k], p: [0, 0.05 * k, e * L / 2], c: P.bone });
  }
  if (R() > 0.5) for (let i = 0; i < 4; i++) t.box({ name: 'Vertebra', s: [0.8 * k, 0.6 * k, 0.6 * k], p: [2 * k + i * 0.75 * k, 0.3 * k, -1.4 * k + i * 0.2], r: [0, R() * 30, 0], c: i % 2 ? P.bone : P.boneLo });
  return g;
}
// a Protoceratops skull: beak, a big frill tilted back, cheek horns (facing local -Z)
function protoSkull(ctx, p, yaw, k, seed) {
  const R = rng(seed);
  const g = ctx.group('ProtoSkull');
  const t = g.at(p, [0, yaw, (R() - 0.5) * 16]);
  t.box({ name: 'Skull', s: [1.6 * k, 1.4 * k, 2.4 * k], p: [0, 0.7 * k, 0], c: P.bone });
  t.wedgeF({ name: 'Beak', s: [1.2 * k, 1.2 * k, 1.2 * k], p: [0, 0.6 * k, -1.7 * k], face: 'front', c: P.boneLo });
  t.box({ name: 'Frill', s: [3 * k, 2.4 * k, 0.4 * k], p: [0, 1.7 * k, 1.4 * k], r: [-35, 0, 0], c: P.bone });
  t.box({ name: 'FrillRim', s: [3.2 * k, 0.4 * k, 0.5 * k], p: [0, 2.7 * k, 2.1 * k], r: [-35, 0, 0], c: P.boneLo });
  for (const sd of [-1, 1]) {
    t.box({ name: 'EyeSocket', s: [0.1, 0.5 * k, 0.6 * k], p: [sd * 0.82 * k, 1 * k, -0.4 * k], c: '#5a3a26' });
    t.box({ name: 'Cheek', s: [0.4 * k, 0.7 * k, 0.4 * k], p: [sd * 0.95 * k, 0.4 * k, 0.4 * k], r: [0, 0, sd * 20], c: P.boneLo });
  }
  return g;
}
// a big theropod skeleton half sunk in the sand (facing local -Z): skull, a curve of spine, ribs up, a leg, the tail
function bigSkeleton(ctx, p, yaw, k, seed) {
  const R = rng(seed);
  const c = ctx.group('BigSkeleton').at(p, [0, yaw, 0]);
  const spine = [];
  for (let i = 0; i <= 16; i++) { const u = i / 16; spine.push([Math.sin(u * 3) * 3 * k, (0.6 + Math.sin(u * Math.PI) * 2.2) * k, (-9 + u * 26) * k]); }
  for (let i = 0; i < 16; i++) c.beam(spine[i], spine[i + 1], (1.5 - i * 0.06) * k, (1.3 - i * 0.05) * k, { name: 'Vertebra', c: i % 2 ? P.bone : P.boneLo, extend: 0.3 });
  for (let i = 0; i < 6; i++) {
    const s = spine[3 + i];
    for (const sd of [-1, 1]) c.beam(s, [s[0] + sd * 2.6 * k, s[1] + (2.6 - Math.abs(i - 2.5) * 0.4) * k, s[2] + 0.6 * k], 0.45 * k, 0.45 * k, { name: 'Rib', c: P.bone, extend: 0.2 });
  }
  const sk = c.at([-1 * k, 0.2 * k, -13 * k], [0, 14, 8]);
  sk.box({ name: 'Skull', s: [2.6 * k, 2.6 * k, 5.4 * k], p: [0, 1.3 * k, 0], c: P.bone });
  sk.box({ name: 'Jaw', s: [2.2 * k, 0.8 * k, 4.8 * k], p: [0, 0.2 * k, -0.3 * k], r: [8, 0, 0], c: P.boneLo });
  for (const sd of [-1, 1]) sk.box({ name: 'EyeSocket', s: [0.15, 0.9 * k, 1 * k], p: [sd * 1.32 * k, 1.8 * k, -0.6 * k], c: '#5a3a26' });
  for (let i = 0; i < 5; i++) sk.box({ name: 'Tooth', s: [0.25 * k, 0.6 * k, 0.25 * k], p: [1.05 * k, 0.6 * k, -2.3 * k + i * 0.8 * k], c: '#fff6e0' });
  c.beam([2 * k, 0.4 * k, 6 * k], [5 * k, 3.4 * k, 4 * k], 1.1 * k, 1.1 * k, { name: 'Femur', c: P.boneLo });
  c.beam([5 * k, 3.4 * k, 4 * k], [6.5 * k, 0.4 * k, 1 * k], 0.9 * k, 0.9 * k, { name: 'Shin', c: P.bone });
  return c;
}
// a tall Cretaceous conifer for the grove (the ruler rakes these)
function groveConifer(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('GroveConifer');
  g.parent.tag('ScytheTree');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = Math.max(4, Math.round(h / 4));
  for (let i = 0; i < n; i++) t.box({ name: 'ConiferTrunk', s: [1.7 - i * 0.06, 4.1, 1.7 - i * 0.06], p: [0, 2 + i * 4, 0], r: [0, i * 21, 0], c: P.bark[i % 3], studs: 'sides', collide: i === 0 });
  const tiers = 7;
  for (let k = 0; k < tiers; k++) {
    const u = k / (tiers - 1);
    const y = h * 0.34 + u * h * 0.62;
    const r = (1 - u * 0.82) * (2.2 + h * 0.13);
    t.box({ name: 'ConiferCrown', s: [r * 2, 2.6, r * 2 * (0.85 + R() * 0.15)], p: [(R() - 0.5) * 0.8, y, (R() - 0.5) * 0.8], r: [0, k * 33, 0], c: P.conifer[k % 4], studs: 'top' });
  }
  t.box({ name: 'ConiferTop', s: [1.6, 3, 1.6], p: [0, h + 0.6, 0], c: P.conifer[1], studs: 'top' });
  return g;
}
function horsetail(ctx, p, seed) {
  const R = rng(seed);
  const g = ctx.group('Horsetail');
  for (let k = 0; k < 5; k++) {
    const h = 2 + R() * 2.4;
    const x = p[0] + (R() - 0.5) * 3, z = p[2] + (R() - 0.5) * 3;
    g.box({ name: 'HorsetailStem', s: [0.28, h, 0.28], p: [x, p[1] + h / 2, z], r: [(R() - 0.5) * 10, 0, (R() - 0.5) * 10], c: k % 2 ? '#5f9a3e' : '#6eaa48', shadow: false });
    g.box({ name: 'HorsetailNode', s: [0.5, 0.18, 0.5], p: [x, p[1] + h * 0.55, z], c: '#3f6a2a', shadow: false });
  }
  return g;
}

function buildRedCliffs() {
  const route = RT.buildRoute(DEF);
  const root = new Inst('Model', 'RedCliffs');
  root.attr('Zone', 'RedCliffs');
  const Z = new Ctx({ parent: root, frame: new CF(...RC_ORIGIN), defaults: { anchored: true } });
  const R = rng(75075);
  const segs = route.segs;
  for (const s of Object.values(segs)) s.cum = RT.cumOf(s.samples);
  const at = (segId, s, x = 0, y = 0) => { const sg = segs[segId]; return RT.at(sg.samples, sg.cum, s, x, y); };
  const roadPts = [];
  for (const s of Object.values(segs)) for (const p of s.samples) roadPts.push([p[0], p[2], s.width / 2]);
  const nearRoad = (x, z, pad) => roadPts.some(([px, pz, hw]) => Math.hypot(x - px, z - pz) < hw + pad);
  const jumpRanges = {};
  for (const f of FEATURES) if (f[0] === 'Jump') (jumpRanges[f[1]] = jumpRanges[f[1]] || []).push([f[2] - f[4].len / 2, f[2] + f[4].len / 2]);
  for (const sg of Object.values(segs)) {
    const ranges = jumpRanges[sg.id] || [];
    sg.gap = sg.samples.map((p, i) => ranges.some(([a, b]) => sg.cum[i] > a + 1 && sg.cum[i] < b - 1));
    sg.samples.forEach((p, i) => { for (const [a, b] of ranges) if (sg.cum[i] > a && sg.cum[i] < b) { const t = (sg.cum[i] - a) / (b - a); p[1] += Math.sin(t * Math.PI) * 7; } });
  }
  const nestAt = NESTS.map((n) => { const f = at(n.seg, n.s, n.x); return { n, f, y: n.seg === 'EggLedges' ? Math.floor((at(n.seg, n.s).base[1] - 0.3) / 0.3) * 0.3 : 0 }; });

  // ------------------------------------------------ ground: the sand sea
  const G = Z.group('Ground', 'Folder');
  G.box({ name: 'Sand', s: [BX * 2 + 60, 4, BZ1 - BZ0 + 60], p: [0, GROUND - 2, (BZ0 + BZ1) / 2], c: P.sand[0], m: 'Sand', studs: 'top', collide: true });
  // the plain beyond the walls (seen from up high): plain sand out to the skyline
  G.box({ name: 'FarSand', s: [1160, 2, 1240], p: [0, GROUND - 3.2, 0], c: shade(P.sand[0], 0.94), m: 'Sand', collide: false, shadow: false });

  // ------------------------------------------------ terrain: plateau, buttes, dunes, walls (strata-banded heightfield)
  const T = terrain(Z, segs, at, nestAt);
  const hAt = T.hAt;
  const gyAt = (x, z) => Math.max(GROUND, hAt(x, z));

  // ------------------------------------------------ roads (packed red clay)
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
      const tone = tile++ % 2 ? P.road : P.roadHi;
      const ya = ROAD + a[1], yb = ROAD + b[1];
      roads.beam([a[0], ya - 0.3, a[2]], [b[0], yb - 0.3, b[2]], W, 0.6, { name: 'Road', c: tone, m: 'Sand', collide: true, extend: 0.2 });
      const flatHere = Math.abs(yb - ya) < 0.02 && Math.abs(ROAD + sg.samples[Math.max(0, i0 - 3)][1] - ya) < 0.02;
      if (flatHere && i0 > 0) roads.cyl({ name: 'RoadJoint', axis: 'y', len: 0.6, d: W, p: [a[0], ya - 0.33, a[2]], c: P.road, m: 'Sand', collide: true });
      const fa = RT.frameAt(sg.samples, i0), fb = RT.frameAt(sg.samples, j);
      if (tile % 2 === 0) for (const rx of [-W * 0.18, W * 0.18]) roads.beam([a[0] + fa.r[0] * rx, ya + 0.02, a[2] + fa.r[2] * rx], [b[0] + fb.r[0] * rx, yb + 0.02, b[2] + fb.r[2] * rx], 1.2, 0.04, { name: 'Rut', c: P.rut, m: 'Sand', shadow: false });
    }
    // verges: strata blocks, bleached bones; on the shelf road a low stone curb along the drop
    for (let s = 4; s < sg.cum[n - 1] - 4; s += 9) {
      if (inGap(s)) continue;
      if ((sg.id === 'DuneRoad' && (s < 16 || Math.abs(s - ARCH.s) < 22)) || (sg.id === 'Homestretch' && s > sg.cum[n - 1] - 22)) continue;
      for (const side of [-1, 1]) {
        // verge props sit past the rover's reach (it drove through them at +0.8); the shelf curb stays on the edge but is a low lip
        const ledge = sg.id === 'EggLedges' && side < 0;
        const f = at(sg.id, s, side * (W / 2 + (ledge ? 0.8 : 3.2)));
        const yaw = yawOf(f);
        const k = Math.floor(s / 9) % 4;
        const y = ROAD + f.base[1];
        if (ledge && f.base[1] > 3) { roads.at([f.p[0], y, f.p[2]], [0, yaw, 0]).box({ name: 'CurbStone', s: [1.4, 0.4, 7.6], p: [0, 0.1, 0], c: bandColor(f.base[1] + (k % 2) * 3), m: 'Slate', studs: 'top' }); continue; }
        if (ledge) continue;
        if (k === 0) roads.at([f.p[0], y, f.p[2]], [0, yaw, 0]).box({ name: 'EdgeStone', s: [1.6, 0.9, 2.6], p: [0, 0.2, 0], r: [0, 0, R() * 8], c: bandColor(R() * 30), m: 'Slate' });
        else if (k === 2 && R() > 0.55) roads.at([f.p[0], y, f.p[2]], [0, yaw + 30, 0]).box({ name: 'EdgeBone', s: [0.5, 0.5, 3.2], p: [0, 0.2, 0], c: P.bone });
      }
    }
  }

  // ------------------------------------------------ skyline: far red mesas and buttes, the Gobi Altai to the north,
  // and a sandstorm wall rolling in from the east
  buildSkyline(Z, R);

  // ------------------------------------------------ set pieces
  buildArrival(Z, at);
  buildArch(Z, at, R);
  buildDuneSea(Z, segs, at, R, jumpRanges.DuneSea || [], hAt);
  buildEggLedges(Z, segs, at, R, nestAt[0]);
  buildRelief(Z, R);
  buildWash(Z, segs, at, R, hAt);
  buildHoodoos(Z, segs, at, R, hAt, nearRoad);
  buildFlats(Z, segs, at, R);
  buildClawRing(Z, at, R, nearRoad);
  for (const na of nestAt) buildNestSite(Z, na, at, R);
  buildReturnPortal(Z, at);
  buildGrove(Z, at, R, route);
  buildWeather(Z, at, R);
  buildCinematics(Z, at);
  { const f = at('DuneRoad', 0); const c = Z.at([f.p[0] + 20, GROUND, f.p[2] - 10], [0, 70, 0]); NPC.buildNpc(c.parent, c.world(new CF(0, 0, 0)), 'Ranger'); }

  // ------------------------------------------------ vegetation: saxaul scrub, tufts, rocks and bones
  const VG = Z.group('Scrub');
  const placed = [];
  const keepOut = [];
  keepOut.push([GROVE.x, GROVE.z, GROVE.r + 10]);
  { const f = at(FINAL.seg, FINAL.s, FINAL.x); keepOut.push([f.p[0], f.p[2], 40]); }
  for (const na of nestAt) keepOut.push([na.f.p[0], na.f.p[2], 26]);
  { const f = at(ARCH.seg, ARCH.s); keepOut.push([f.p[0], f.p[2], 52]); }
  { const f = at('DuneRoad', 0); keepOut.push([f.p[0], f.p[2], 40]); }
  { const f = at('Homestretch', 1e9); keepOut.push([f.p[0], f.p[2], 30]); }
  keepOut.push([RELIEF.x, RELIEF.z + 10, 44]);
  for (const [a, b] of jumpRanges.DuneSea || []) { const f = at('DuneSea', (a + b) / 2); keepOut.push([f.p[0], f.p[2], 30]); }
  const slope = T.slope;
  const tryPlace = (x, z, pad, gap) => {
    if (Math.abs(x) > BX - 24 || z < BZ0 + 24 || z > BZ1 - 24) return false;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr + pad * 0.3)) return false;
    if (nearRoad(x, z, pad)) return false;
    if (slope(x, z, pad) > 1.3) return false;
    if (placed.some(([px, pz]) => Math.hypot(px - x, pz - z) < gap)) return false;
    placed.push([x, z]);
    return true;
  };
  // verges: saxaul and rocks right by the road (what the travel camera sees)
  for (const sg of Object.values(segs)) {
    for (let s = 6; s < sg.cum[sg.cum.length - 1]; s += 13 + R() * 10) {
      for (const side of [-1, 1]) {
        if (R() < 0.35) continue;
        const f = at(sg.id, s, side * (sg.width / 2 + 5 + R() * 9));
        if (!tryPlace(f.p[0], f.p[2], 3, 7)) continue;
        const gy = gyAt(f.p[0], f.p[2]);
        const pick = R();
        if (pick < 0.6) saxaul(VG, [f.p[0], gy, f.p[2]], 1 + R() * 0.6, 50000 + placed.length);
        else if (pick < 0.85) E.rock(VG, [f.p[0], gy, f.p[2]], 0.9 + R() * 0.9, 50000 + placed.length, { colors: [bandColor(R() * 40), bandColor(R() * 40), bandColor(R() * 40)], moss: false });
        else bones(VG, [f.p[0], gy, f.p[2]], 50000 + placed.length, 1 + R() * 0.4);
      }
    }
  }
  for (const sg of Object.values(segs)) {
    for (let s = 3; s < sg.cum[sg.cum.length - 1]; s += 7 + R() * 6) {
      for (const side of [-1, 1]) {
        const f = at(sg.id, s, side * (sg.width / 2 + 1.8 + R() * 3));
        if (nearRoad(f.p[0], f.p[2], 0.6) || Math.abs(hAt(f.p[0], f.p[2]) - f.base[1]) > 1.5 || slope(f.p[0], f.p[2], 2) > 1) continue;
        if (R() < 0.6) E.grassTufts(VG, [f.p[0], gyAt(f.p[0], f.p[2]), f.p[2]], 52000 + Math.floor(s * 7) + side, { n: 4, spread: 2.6, colors: P.tuft });
      }
    }
  }
  // the open country: saxaul thickets in the low ground, rocks and bones; scrub on the plateau top
  for (let k = 0; k < 7000 && placed.length < 900; k++) {
    const x = (R() - 0.5) * 2 * (BX - 26), z = BZ0 + 26 + R() * (BZ1 - BZ0 - 52);
    const h = hAt(x, z);
    const gy = Math.max(GROUND, h);
    const pick = R();
    if (h > 40) {
      // up on the plateau / butte tops
      if (pick < 0.5) { if (tryPlace(x, z, 4, 10)) E.bush(VG, [x, gy, z], 0.9 + R() * 0.6, 54000 + k, { colors: P.saxLeaf, n: 4 }); }
      else if (pick < 0.75) { if (tryPlace(x, z, 4, 12)) E.rock(VG, [x, gy, z], 1.2 + R() * 1.4, 54000 + k, { colors: [bandColor(h + 2), bandColor(h + 6), P.capHi], moss: false }); }
      else if (tryPlace(x, z, 3, 8)) E.grassTufts(VG, [x, gy, z], 54000 + k, { n: 5, spread: 4, colors: P.tuft, scale: 1.6 });
      continue;
    }
    if (pick < 0.42) { if (tryPlace(x, z, 4, 9)) saxaul(VG, [x, gy, z], 1 + R() * 0.8, 54000 + k); }
    else if (pick < 0.54) { if (tryPlace(x, z, 5, 12)) E.rock(VG, [x, gy, z], 1 + R() * 1.6, 54000 + k, { colors: [bandColor(R() * 40), bandColor(R() * 40), bandColor(R() * 40)], moss: false }); }
    else if (pick < 0.6) { if (tryPlace(x, z, 4, 16)) bones(VG, [x, gy, z], 54000 + k, 1 + R() * 0.6); }
    else if (pick < 0.62) { if (tryPlace(x, z, 6, 40)) protoSkull(VG, [x, gy, z], R() * 360, 1.1 + R() * 0.4, 54000 + k); }
    else if (tryPlace(x, z, 3, 8)) E.grassTufts(VG, [x, gy, z], 54000 + k, { n: 5, spread: 4, colors: P.tuft, scale: 1.5 + R() * 0.8 });
  }

  // keep the rover's lane clear: decor in the way is removed, anything else is reported for a fix
  {
    const lanes = [];
    for (const sg of Object.values(segs)) for (const p of sg.samples) lanes.push({ x: p[0] + RC_ORIGIN[0], z: p[2] + RC_ORIGIN[2], y: ROAD + p[1], hw: sg.width / 2 });
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
// One heightfield for the whole era. Each column is either SAND (dune swells, sand sides) or ROCK (sandstone: its
// exposed sides are cut into the era's strata bands, so the plateau, buttes and walls all share the same stripes).
function terrain(Z, segs, at, nestAt) {
  const STEP = 1.2;
  const N = noise2(7575), N2 = noise2(1313), N3 = noise2(4646);
  const road = [], wash = [];
  for (const sg of Object.values(segs)) sg.samples.forEach((p, i) => {
    road.push([p[0], p[2], sg.width / 2, sg.gap[i] ? 0 : p[1]]);
    if (sg.id === 'DryWash' && i % 3 === 0) wash.push([p[0], p[2]]);
  });
  // nearest road (distance past its edge, its height) + the lowest road surface within the clamp reach
  const REACH = CELL * 0.71 + 3;
  const nearestRoad = (x, z) => {
    let best = Infinity, y = 0, cap = Infinity;
    for (const [px, pz, hw, py] of road) {
      const dx = x - px, dz = z - pz;
      if (Math.abs(dx) > best + hw + REACH && Math.abs(dz) > best + hw + REACH) continue;
      const d = Math.hypot(dx, dz) - hw;
      if (d < best) { best = d; y = py; }
      if (d < REACH && py < cap) cap = py;
    }
    return [best, y, cap];
  };
  const washDist = (x, z) => { let b = Infinity; for (const [px, pz] of wash) b = Math.min(b, Math.hypot(x - px, z - pz)); return b; };
  // flat spots (target height): arrival, exit, nests, the final ring, the arch
  const flats = [];
  const addAt = (seg, s, x, r, y = 0, blend = 18) => { const f = at(seg, s, x); flats.push([f.p[0], f.p[2], r, y, blend]); };
  addAt('DuneRoad', 0, 0, 42); addAt('DuneRoad', 0, 22, 22);
  addAt('Homestretch', 1e9, 0, 34);
  for (const na of nestAt) flats.push([na.f.p[0], na.f.p[2], na.n.seg === 'EggLedges' ? 15 : 24, na.y, na.n.seg === 'EggLedges' ? 6 : 16]);
  addAt(FINAL.seg, FINAL.s, FINAL.x, 40);
  addAt(ARCH.seg, ARCH.s, 0, 50, 0, 14);
  // the jump: a blowout trench across the dune road
  const trenches = [];
  for (const f of FEATURES) if (f[0] === 'Jump') { const c = at(f[1], f[2]); trenches.push({ p: c.p, f: c.f, r: c.r, half: f[4].len / 2 - 5 }); }
  const groveCut = (x, z) => {
    if (Math.hypot(x - GROVE.x, z - GROVE.z) < GROVE.r) return true;
    // the mouth: a corridor north to the wash
    return Math.abs(x - GROVE.x + (z - GROVE.z) * 0.12) < 19 && z < GROVE.z && z > GROVE.z - 80;
  };
  const natural = (x, z) => {
    // dunes: asymmetric sand waves (gentle windward side, steep lee) driven from the west-southwest
    const wd = washDist(x, z);
    const west = 1 - smooth(-200, -138, x);
    const strip = 0.4 * (1 - smooth(-124, -104, x)) * smooth(-150, -135, x);
    const south = 0.6 * smooth(236, 290, z) * (1 - smooth(150, 220, x));
    const m = Math.max(west, strip, south) * smooth(20, 70, wd);
    const u = (x * 0.83 + z * 0.56) / 80 + 0.55 * N(x / 120, z / 120);
    const fr = u - Math.floor(u);
    const prof = fr < 0.72 ? fr / 0.72 : (1 - fr) / 0.28;
    const amp = 13 + 6 * N2(x / 140 + 3, z / 140);
    let H = amp * prof * m, kind = 'sand', crest = prof > 0.82 && m > 0.6;
    const take = (h, k) => { if (h > H) { H = h; kind = k; crest = false; } };
    // the plateau (a talus ledge in places, then the cliff; a few high tables on top)
    const sd = polySD(x, z, PLATEAU) + 7 * N(x / 34, z / 34);
    if (sd > 0 && !groveCut(x, z)) {
      const ledge = 6 + 9 * N2(x / 46, z / 46);
      take(sd < ledge ? 21 + 6 * N3(x / 20, z / 20) : 57 + (N3(x / 70, z / 70) > 0.3 ? 9 : 0) + (N(x / 30 + 9, z / 30) > 0.55 ? 9 : 0), 'rock');
    }
    // buttes
    for (const [bx, bz, r, hb] of BUTTES) {
      const dd = Math.hypot(x - bx, z - bz) + 5 * N(x / 16 + bx, z / 16);
      if (dd < r) take(dd < r * 0.62 ? hb : hb * 0.38, 'rock');
    }
    // the east: a low dune ridge (keeps the sandstorm on the horizon in view)
    const eE = BX - x;
    if (eE < 40) take(15 * (1 - smooth(4, 40, eE)) * (0.8 + 0.3 * N(x / 40, z / 40)), 'sand');
    return [H, kind, crest];
  };
  // the walls of the world: red cliffs W / N / S with a low bench in front
  const wallH = (x, z) => {
    const e = Math.min(x + BX, z - BZ0, BZ1 - z);
    const n = N(x / 60 + 3, z / 60 - 7);
    if (e < 16) return 66 + 14 * n;
    if (e < 30) return 33 + 8 * n;
    if (e < 44) return 9;
    return 0;
  };
  const heights = new Map(), kinds = new Map();
  const key = (i, j) => i + ',' + j;
  const cells = [];
  const NI = Math.round((2 * BX) / CELL), NJ = Math.round((BZ1 - BZ0) / CELL);
  for (let i = 0; i < NI; i++) {
    for (let j = 0; j < NJ; j++) {
      const x = -BX + CELL / 2 + i * CELL, z = BZ0 + CELL / 2 + j * CELL;
      const [d, ry, cap] = nearestRoad(x, z);
      let [H, kind, crest] = natural(x, z);
      let t;
      if (H > ry) t = kind === 'rock' ? smooth(3, 10, d) : smooth(4, 30, d);
      else { t = smooth(4, 24, d); if (ry > 7 && d < 26) kind = 'rock'; }
      let h = ry * (1 - t) + H * t;
      h = kind === 'rock' && h > 6 ? Math.round(h / 3) * 3 : Math.floor(h / STEP) * STEP;
      for (const [fx, fz, fr, fy, fb] of flats) {
        const dd = Math.hypot(x - fx, z - fz);
        if (dd < fr + fb) { const k = smooth(fr, fr + fb, dd); h = fy + (h - fy) * k; if (k < 0.02) { h = fy; crest = false; } }
      }
      for (const tr of trenches) {
        const dx = x - tr.p[0], dz = z - tr.p[2];
        const u = Math.abs(dx * tr.f[0] + dz * tr.f[2]), v = Math.abs(dx * tr.r[0] + dz * tr.r[2]);
        if (u < tr.half + 8 && v < 60) h *= Math.max(smooth(tr.half, tr.half + 8, u), smooth(44, 60, v));
      }
      if (!(Math.abs(h - Math.round(h / 0.3) * 0.3) < 1e-6)) h = Math.floor(h / STEP) * STEP;
      const wh = wallH(x, z);
      if (wh > 0 && wh >= h) { h = wh; kind = 'rock'; }
      // under the road (and its 2.5-stud lane margin): never above the lowest road surface there
      if (cap < Infinity) h = Math.min(h, Math.floor((cap - 0.3) / 0.3) * 0.3);
      h = +h.toFixed(2);
      if (h < STEP) { heights.set(key(i, j), 0); continue; }
      heights.set(key(i, j), h);
      kinds.set(key(i, j), kind);
      let topC;
      if (kind === 'rock') {
        const tone = Math.floor((N(x / 70 - 13, z / 70 + 7) + 1) * 1.5) % 3;
        topC = h >= 50 ? P.plateauTop[tone] : h >= 18 ? P.rockTop[tone] : P.ledgeTop;
      } else {
        // sand: lighter the higher it lies, so the dune waves read as contour bands; crests brightest
        topC = crest && h > 5 ? P.crest : P.duneTone[Math.min(3, Math.floor(h / 4))];
      }
      cells.push({ i, j, x, z, h, kind, topC });
    }
  }
  const H = Z.group('Hills', 'Folder');
  const hOf = (i, j) => (i < 0 || j < 0 || i >= NI || j >= NJ) ? null : (heights.get(key(i, j)) || 0);
  // greedy-merge equal columns into rectangles; draw only the exposed sides (above the lowest neighbour)
  const groups = new Map();
  for (const c of cells) {
    const sig = [c.h, c.kind, c.topC].join('|');
    if (!groups.has(sig)) groups.set(sig, new Map());
    groups.get(sig).set(key(c.i, c.j), c);
  }
  let parts = 0;
  const LR = rng(5151);
  for (const cellsOf of groups.values()) {
    const left = new Map(cellsOf);
    const keys = [...left.keys()].sort((a, b) => { const [ai, aj] = a.split(',').map(Number), [bi, bj] = b.split(',').map(Number); return aj - bj || ai - bi; });
    for (const k of keys) {
      if (!left.has(k)) continue;
      const c = left.get(k);
      let w = 1;
      while (left.has((c.i + w) + ',' + c.j) && w < 14) w++;
      let dd = 1;
      grow: while (dd < 14) { for (let u = 0; u < w; u++) if (!left.has((c.i + u) + ',' + (c.j + dd))) break grow; dd++; }
      for (let u = 0; u < w; u++) for (let v = 0; v < dd; v++) left.delete((c.i + u) + ',' + (c.j + v));
      let minN = c.h;
      const nb = (i, j) => { const h = hOf(i, j); if (h !== null) minN = Math.min(minN, h); };
      for (let u = 0; u < w; u++) { nb(c.i + u, c.j - 1); nb(c.i + u, c.j + dd); }
      for (let v = 0; v < dd; v++) { nb(c.i - 1, c.j + v); nb(c.i + w, c.j + v); }
      const cx = c.x + ((w - 1) / 2) * CELL, cz = c.z + ((dd - 1) / 2) * CELL;
      const sx = w * CELL, sz = dd * CELL;
      const top = Math.min(1.2, c.h);
      if (c.kind === 'rock') {
        bands(minN, c.h - top, (a, b, col, mat) => { H.box({ name: 'Strata', s: [sx, b - a, sz], p: [cx, (a + b) / 2, cz], c: col, m: mat, collide: true }); parts++; });
        H.box({ name: 'CliffTop', s: [sx, top, sz], p: [cx, c.h - top / 2, cz], c: c.topC, studs: 'top', collide: true });
        // hard caprock ledges jutting from tall faces (breaks up the big walls, catches the low sun)
        if (c.h > 16) {
          const sideMin = (cellsOfSide) => { let m = Infinity; for (const [i, j] of cellsOfSide) { const h = hOf(i, j); if (h !== null) m = Math.min(m, h); } return m; };
          const sides = [
            [sideMin(Array.from({ length: w }, (_, u) => [c.i + u, c.j - 1])), 0, -1], [sideMin(Array.from({ length: w }, (_, u) => [c.i + u, c.j + dd])), 0, 1],
            [sideMin(Array.from({ length: dd }, (_, v) => [c.i - 1, c.j + v])), -1, 0], [sideMin(Array.from({ length: dd }, (_, v) => [c.i + w, c.j + v])), 1, 0],
          ];
          for (const [m, ox, oz] of sides) {
            if (!(m < c.h - 14) || LR() > 0.35) continue;
            const tops = BANDS.map((b) => b[0]).filter((y) => y > m + 5 && y < c.h - 4);
            if (!tops.length) continue;
            const y = tops[Math.floor(LR() * tops.length)];
            const along = (ox ? sz : sx) * (0.35 + LR() * 0.45);
            const lx = cx + ox * (sx / 2 + 0.9) + (ox ? 0 : (LR() - 0.5) * sx * 0.3), lz = cz + oz * (sz / 2 + 0.9) + (oz ? 0 : (LR() - 0.5) * sz * 0.3);
            const [rd, rry] = nearestRoad(lx, lz);
            if (rd < 14 && y < rry + 14) continue;
            H.box({ name: 'Ledge', s: ox ? [2.2, 1.1 + LR() * 0.6, along] : [along, 1.1 + LR() * 0.6, 2.2], p: [lx, y, lz], c: shade(bandColor(y - 0.5), 0.8), m: 'Slate', studs: 'top' });
            parts++;
          }
        }
      } else {
        if (c.h - top > minN + 0.05) { H.box({ name: 'DuneSide', s: [sx, c.h - top - minN, sz], p: [cx, (minN + c.h - top) / 2, cz], c: P.sandSide, m: 'Sand', collide: true }); parts++; }
        H.box({ name: 'DuneTop', s: [sx, top, sz], p: [cx, c.h - top / 2, cz], c: c.topC, studs: 'top', collide: true });
      }
      parts++;
    }
  }
  const cellIJ = (x, z) => [Math.floor((x + BX) / CELL), Math.floor((z - BZ0) / CELL)];
  const hAt = (x, z) => { const [i, j] = cellIJ(x, z); return heights.get(key(i, j)) || 0; };
  // the steepest step within r of a point (keeps scrub off cliff edges)
  const slope = (x, z, r = 3) => {
    const h0 = hAt(x, z);
    let m = 0;
    for (const [dx, dz] of [[r, 0], [-r, 0], [0, r], [0, -r], [r, r], [-r, -r], [r, -r], [-r, r]]) m = Math.max(m, Math.abs(hAt(x + dx, z + dz) - h0));
    return m;
  };
  console.log('                   terrain: ' + cells.length + ' columns -> ' + parts + ' parts');
  return { hAt, slope };
}

// ------------------------------------------------------------------ skyline
function landform(ctx, p, kind, k, seed) {
  const R = rng(seed);
  const g = ctx.group('Far' + kind);
  const t = g.at(p, [0, R() * 360, 0]);
  if (kind === 'Table') {
    const h = 70 * k;
    let i = 0;
    bands(0, h, (a, b, col, mat) => { const s = 1 - (a / h) * 0.12; t.box({ name: 'FarMesa', s: [130 * k * s + (R() - 0.5) * 6, b - a + 0.2, 80 * k * s + (R() - 0.5) * 6], p: [(R() - 0.5) * 2, (a + b) / 2, (R() - 0.5) * 2], c: col, m: mat }); i++; }, 12);
    t.box({ name: 'FarMesa', s: [110 * k, 2, 66 * k], p: [0, h + 1, 0], c: P.plateauTop[0], m: 'Slate' });
  } else if (kind === 'Butte') {
    const h = 100 * k;
    bands(0, h, (a, b, col, mat) => t.box({ name: 'FarMesa', s: [(34 + R() * 6) * k, b - a + 0.2, (30 + R() * 6) * k], p: [0, (a + b) / 2, 0], r: [0, R() * 6, 0], c: col, m: mat }), 14);
    bands(0, 34 * k, (a, b, col, mat) => t.box({ name: 'FarMesa', s: [(64 - a / k * 0.8) * k, b - a + 0.2, (56 - a / k * 0.8) * k], p: [0, (a + b) / 2, 0], c: col, m: mat }), 12);
    t.box({ name: 'FarMesa', s: [30 * k, 2, 26 * k], p: [0, h + 1, 0], c: P.plateauTop[1], m: 'Slate' });
  } else if (kind === 'Tiered') {
    for (let i = 0; i < 4; i++) {
      const y0 = i * 22 * k;
      bands(y0, y0 + 22 * k, (a, b, col, mat) => t.box({ name: 'FarMesa', s: [(110 - i * 24) * k, b - a + 0.2, (80 - i * 16) * k], p: [0, (a + b) / 2, 0], c: col, m: mat }), 12);
    }
  } else if (kind === 'Spire') {
    let x = 0;
    for (let i = 0; i < 7; i++) { x += (R() - 0.3) * 2.4 * k; const y0 = i * 15 * k; bands(y0, y0 + 15 * k, (a, b, col, mat) => t.box({ name: 'FarMesa', s: [(22 - i * 2) * k, b - a + 0.2, (20 - i * 1.8) * k], p: [x, (a + b) / 2, 0], c: col, m: mat }), 15); }
    t.box({ name: 'FarMesa', s: [12 * k, 5 * k, 12 * k], p: [x, 107 * k, 0], c: P.cap, m: 'Slate' });
  }
  return g;
}
function buildSkyline(Z, R) {
  const M = Z.group('Skyline');
  // red tables and buttes around three sides, two rows deep
  const W = ['Table', 'Butte', 'Spire', 'Tiered', 'Table', 'Butte'];
  for (let k = 0; k < 6; k++) landform(M, [-452 - (k % 2) * 46 - R() * 10, 0, -330 + k * 128 + (R() - 0.5) * 20], W[k], 0.7 + R() * 0.35, 300 + k);
  const S = ['Butte', 'Table', 'Spire', 'Table', 'Tiered', 'Butte', 'Table'];
  for (let k = 0; k < 7; k++) landform(M, [-420 + k * 140 + (R() - 0.5) * 30, 0, 470 + (k % 2) * 60 + R() * 30], S[k], 0.65 + R() * 0.35, 320 + k);
  const Nn = ['Table', 'Spire', 'Butte', 'Tiered', 'Table', 'Butte', 'Spire'];
  for (let k = 0; k < 7; k++) landform(M, [-440 + k * 150 + (R() - 0.5) * 30, 0, -460 - (k % 2) * 40], Nn[k], 0.7 + R() * 0.3, 340 + k);
  // the Gobi Altai: long dusky violet ranges behind the north mesas (no snow: this is the desert)
  for (let k = 0; k < 6; k++) {
    const x = -470 + k * 188 + (R() - 0.5) * 30, z = -575 - R() * 30;
    const h = 120 + R() * 90;
    for (let t = 0; t < 5; t++) M.box({ name: 'Peak', s: [196 - t * 34 + R() * 12, h / 5 + 1, 70 - t * 10], p: [x + (R() - 0.5) * 12 * t, (t + 0.5) * (h / 5), z], r: [0, (R() - 0.5) * 20, 0], c: shade(['#8e6f7a', '#9a7884', '#a7848a', '#b4908e', '#c09c94'][t], 1), m: 'Slate' });
  }
  // the sandstorm wall on the east horizon: billowing ochre dust, denser at the back
  const SW = Z.group('SandstormWall');
  // columns of stacked tiers: dense and dark at the foot, thinning and paler as the dust boils up
  // (2026-10-12 lead pass: the solid tiers read as giant brown boxes up close, so they stay low and see-through and the
  //  particle dust above them carries the height)
  const TIERS = [[0.45, '#c68454'], [0.7, '#d8a070']];
  for (let z = -580, k = 0; z <= 580; z += 64, k++) {
    let y = -2;
    const H = 46 + 26 * Math.abs(Math.sin(k * 1.3)) + R() * 12;
    TIERS.forEach(([tr, col], ti) => {
      const th = H * [0.3, 0.22][ti];
      const w = 70 - ti * 12;
      SW.box({ name: 'StormDust', s: [w, th, 64 - ti * 6], p: [556 - ti * 4, y + th / 2, z], c: col, m: 'SmoothPlastic', t: tr, shadow: false });
      y += th;
    });
  }
  for (let z = -490; z <= 490; z += 140) {
    const host = SW.box({ name: 'StormEmitter', s: [24, 90, 150], p: [530, 70, z], t: 1, shadow: false });
    host.set('CanQuery', 'bool', false);
    E.particles(host, 'Dust', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 4, life: [12, 18], speed: [3, 7], dir: 3, spread: [30, 30], size: [[0, 40], [1, 95]], transp: [[0, 0.55], [1, 1]], color: [0.82, 0.58, 0.38], emission: 0, accel: [-1.5, 0.4, 0] });
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
    F.beam([ax, ay, 0], [bx, by, 0], 3.6, 3, { name: 'PortalBeam', c: '#7a4a32', m: 'Slate', studs: 'top', extend: 1, up: [0, 0, 1] });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNode', s: [4.4, 4.4, 4.8], c: '#2b2d31', m: 'Metal', studs: 'all' });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNodeCore', s: [2, 2, 5], c: o.color || '#3fe0c8', m: 'Neon' }).tag('GateNode');
  }
  const rm = Rr - 2.2, apo = rm * Math.sin(Math.PI / 3);
  for (let k = 0; k < 3; k++) F.box({ name: 'Membrane', s: [rm, 2 * apo, 0.3], r: [0, 0, k * 60], c: o.color || '#2fb8b0', m: 'Neon', t: 0.5, shadow: false }).tag('PortalSurface');
  for (let k = 0; k < 3; k++) F.box({ name: 'Core', s: [rm * 0.5, 2 * apo * 0.5, 0.35], r: [0, 0, k * 60], c: '#fff2c4', m: 'Neon', t: 0.5, shadow: false }).tag('PortalCore');
  const host = F.box({ name: 'PortalLightHost', s: [1, 1, 1], t: 1, shadow: false });
  E.pointLight(host, o.light || [0.6, 0.95, 0.9], 40, 1.1);
  E.particles(host, 'Swirl', { rate: 22, life: [0.8, 1.6], speed: [5, 12], spread: [80, 80], dir: 5, size: [[0, 0.55], [1, 0]], color: [[0, [1, 0.95, 0.75]], [1, [1, 0.7, 0.35]]], emission: 0.7 });
  for (const side of [-1, 1]) c.box({ name: 'Plinth', s: [6, 3, 7], p: [side * (Rr + 1), 1.5, 0], c: '#a85a3a', m: 'Slate', studs: 'top', collide: true });
  return g;
}

function buildArrival(Z, at) {
  const f = at('DuneRoad', 0);
  const yaw = yawOf(f);
  hexPortal(Z, [f.p[0], GROUND, f.p[2] + 6], yaw, 14, 'ArrivalPortal');
  // the old expedition camp: canvas tents, crates, and the dig where the first nest was found
  const c = Z.at([f.p[0] - 28, GROUND, f.p[2] - 16], [0, -18, 0]);
  const g = c.group('ExpeditionCamp');
  g.box({ name: 'TentFloor', s: [10, 0.3, 8], p: [0, 0.15, 0], c: '#8a5a33' });
  g.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, -2], face: 'front', c: P.canvas });
  g.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, 2], face: 'back', c: P.canvasLo });
  g.box({ name: 'TentPole', s: [0.4, 6, 0.4], p: [5.2, 3, 0], c: P.woodLo });
  const t2 = g.at([-12, 0, 6], [0, 34, 0]);
  t2.box({ name: 'TentFloor', s: [8, 0.3, 7], p: [0, 0.15, 0], c: '#8a5a33' });
  t2.wedgeF({ name: 'Tent', s: [8, 4.4, 3.5], p: [0, 2.5, -1.75], face: 'front', c: '#cf6a3a' });
  t2.wedgeF({ name: 'Tent', s: [8, 4.4, 3.5], p: [0, 2.5, 1.75], face: 'back', c: '#b85a30' });
  E.crate(g, [-6.5, 0.3, 1], 1, { yaw: -14, stencil: '#b85a30' });
  E.crate(g, [-6.5, 2.3, 1], 0.8, { yaw: 8 });
  E.barrel(g, [-6.5, 0.3, -2.5], { color: '#2f6b8a' });
  E.signBoard(g, [7, 4, -3], 7, 2, 'RED CLIFFS', { r: [0, 30, 0], color: '#fff2c4', color2: '#ff6a2a', twoSided: true, pps: 30 });
  g.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [7, 2, -2.7], c: E.PAL.woodLo });
  E.lampPost(g, [4, 0.3, 4], { h: 6 });
  E.flag(g, [-3, 0, -6], '#ff6a2a', { h: 8 });
  // the dig: a roped grid over a clutch of fossil eggs
  const d = g.at([-4, 0, -14], [0, 10, 0]);
  d.box({ name: 'DigFloor', s: [9, 0.2, 7], p: [0, 0.05, 0], c: '#c98a5a', m: 'Sand' });
  for (const [x, z, w, dd] of [[0, -3.7, 9.6, 0.6], [0, 3.7, 9.6, 0.6], [-4.7, 0, 0.6, 7], [4.7, 0, 0.6, 7]]) d.box({ name: 'DigSpoil', s: [w, 0.8, dd], p: [x, 0.4, z], c: '#d99c62', m: 'Sand' });
  for (let k = 0; k < 5; k++) d.box({ name: 'DigStake', s: [0.3, 1.4, 0.3], p: [-4.6 + k * 2.3, 0.7, -3.6], c: P.wood });
  for (let k = 0; k < 4; k++) d.box({ name: 'DigString', s: [0.08, 0.08, 7.2], p: [-3.45 + k * 2.3, 1.1, 0], c: '#f4ead2', shadow: false });
  for (let k = 0; k < 7; k++) { const a = (k / 7) * Math.PI * 2; d.box({ name: 'FossilEgg', s: [0.9, 0.8, 1.6], p: [Math.cos(a) * 1.8, 0.4, Math.sin(a) * 1.8], r: [0, -E.deg(a), 0], c: k % 2 ? '#b8a48a' : '#a8947a', m: 'Slate' }); }
  d.box({ name: 'Brush', s: [0.3, 0.2, 1.4], p: [3, 0.3, 2], r: [0, 30, 0], c: P.woodLo });
}

function buildReturnPortal(Z, at) {
  const f = at('Homestretch', 1e9);
  hexPortal(Z, [f.p[0] - f.f[0] * 14, GROUND, f.p[2] - f.f[2] * 14] /* 14 back from the end: you drive through it before the warp (extract at L-8) */, yawOf(f), 15, 'ReturnPortal', { color: '#ffb02e', light: [1, 0.85, 0.5] });
}

// THE GREAT ARCH: a natural sandstone arch the Dune Road drives straight under, its strata matching every cliff
function buildArch(Z, at, R) {
  const f = at(ARCH.seg, ARCH.s);
  const g = Z.group('GreatArch');
  const c = g.at([f.base[0], 0, f.base[2]], [0, yawOf(f) + 8, 0]);
  const IN = 23, OUT = 46, SPR = 40, CROWN = 58, TOP = 76;
  const open = (y) => (y < SPR ? IN : y >= CROWN ? 0 : IN * Math.sqrt(Math.max(0, 1 - ((y - SPR) / (CROWN - SPR)) ** 2)));
  const outer = (y) => OUT - Math.max(0, y - 52) * 0.75;
  // legs + span in horizontal slices, cut by the opening (stepped underside, like real blocky erosion)
  let y = 0;
  while (y < TOP - 0.05) {
    const k = bandIdx(y + 0.01);
    const slice = y >= SPR - 0.1 && y < CROWN ? 2.4 : 6;
    const y1 = Math.min(TOP, BANDS[k][0], y + slice);
    const ym = (y + y1) / 2;
    const w = open(y), o = outer(ym);
    const dep = (ym < SPR ? 26 : 20) + (R() - 0.5) * 1.5;
    const col = BANDS[k][1], mat = bandMat(k);
    if (w > 0.1) {
      for (const sd of [-1, 1]) { const a = w, b = o + (R() - 0.5) * 1.2; c.box({ name: 'Strata', s: [b - a, y1 - y, dep], p: [sd * (a + b) / 2, ym, (R() - 0.5) * 0.8], c: col, m: mat, collide: true }); }
    } else {
      c.box({ name: 'Strata', s: [o * 2 + (R() - 0.5) * 2, y1 - y, dep], p: [(R() - 0.5) * 1.2, ym, (R() - 0.5) * 0.8], c: col, m: mat, collide: true });
    }
    y = y1;
  }
  c.box({ name: 'CliffTop', s: [outer(TOP) * 2 - 4, 1.2, 18], p: [0, TOP + 0.6, 0], c: P.plateauTop[0], studs: 'top', collide: true });
  for (let k = 0; k < 4; k++) E.bush(c, [-14 + k * 9 + R() * 3, TOP + 1.2, (R() - 0.5) * 8], 0.9 + R() * 0.5, 3100 + k, { colors: P.saxLeaf, n: 4 });
  // talus wedges and fallen blocks at the leg feet (outside the lane)
  for (const sd of [-1, 1]) {
    for (const dz of [-1, 1]) c.wedgeF({ name: 'Talus', s: [OUT - IN - 2, 7, 8], p: [sd * (IN + OUT) / 2, 3.5, dz * 17], face: dz < 0 ? 'front' : 'back', c: bandColor(2), m: 'Slate', collide: true });
    for (let k = 0; k < 3; k++) E.rock(c, [sd * (IN + 4 + R() * 14), 0.5, (R() - 0.5) * 50], 1.4 + R() * 1.2, 3200 + k + (sd > 0 ? 10 : 0), { colors: [bandColor(8), bandColor(20), bandColor(40)], moss: false });
  }
  // a soft warm light under the span (dusk glow on the underside, subtle)
  const glow = c.box({ name: 'ArchGlow', s: [1, 1, 1], p: [0, 30, 0], t: 1, shadow: false });
  E.pointLight(glow, [1, 0.62, 0.36], 36, 0.55);
}

// THE DUNE SEA: sand waves (from the terrain), a blowout trench the road jumps, a tyrant's skeleton in the hollow
function buildDuneSea(Z, segs, at, R, gaps, hAt) {
  const g = Z.group('DuneSea');
  const sg = segs.DuneSea;
  for (const [a, b] of gaps) {
    const fa = at('DuneSea', a), fb = at('DuneSea', b), fm = at('DuneSea', (a + b) / 2);
    for (const [fr, dir] of [[fa, 1], [fb, -1]]) {
      const yw = yawOf(fr);
      const c = g.at([fr.base[0], ROAD + fr.base[1], fr.base[2]], [0, yw, 0]);
      c.box({ name: 'JumpLip', s: [sg.width, 0.8, 1.6], p: [0, 0.1, -dir * 0.4], c: '#f2c230', studs: 'top' });
      c.wedgeF({ name: 'Kicker', s: [sg.width - 4, 1.2, 4], p: [0, 0.6, dir * 2], face: dir > 0 ? 'back' : 'front', c: P.ledgeTop, m: 'Sand' });
      // the lip stands on a packed-sand bank down into the hollow
      const hb = fr.base[1] + ROAD - 0.6;
      if (hb > 0.6) c.box({ name: 'Shelf', s: [sg.width + 4, hb, 6], p: [0, -hb / 2 - 0.6, dir * 2.4], c: P.sandSide, m: 'Sand', collide: true });
    }
    const c = g.at([fm.base[0], GROUND, fm.base[2]], [0, yawOf(fm), 0]);
    c.box({ name: 'BlowoutFloor', s: [70, 0.12, b - a - 6], p: [0, 0.06, 0], c: P.sandLo, m: 'Sand', shadow: false });
    bigSkeleton(c, [-6, 0, 0], 82, 1.25, 4411);
    for (let k = 0; k < 4; k++) protoSkull(c, [(R() - 0.5) * 50, 0, (R() - 0.5) * 12], R() * 360, 1.2, 4420 + k);
    const sc = c.at([sg.width / 2 + 6, 0, -(b - a) / 2 - 4]);
    E.signBoard(sc, [0, 4, 0], 6, 1.6, 'JUMP!', { color: '#fff2c4', color2: '#ff9a3a', twoSided: true, pps: 30 });
    sc.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
  }
  const f = at('DuneSea', 22);
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, yawOf(f), 0]);
  E.signBoard(c, [-(sg.width / 2 + 5), 4, 0], 6, 1.6, 'DUNE SEA', { color: '#fff2c4', color2: '#ff9a3a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [-(sg.width / 2 + 5), 2, 0.3], c: E.PAL.woodLo });
  // a half-sunk sauropod spine arcing out of a dune crest west of the road (a landmark for the drive)
  const fs = at('DuneSea', 80, -46);
  const sp = g.at([fs.p[0], Math.max(GROUND, hAt(fs.p[0], fs.p[2])) - 1, fs.p[2]], [0, yawOf(fs) + 70, 0]);
  for (let k = 0; k < 13; k++) { const a = (k / 12) * Math.PI; sp.box({ name: 'SpineArc', s: [2.2, 2.2, 2.6], p: [-Math.cos(a) * 16, Math.sin(a) * 9, 0], r: [0, 0, E.deg(a) - 90], c: k % 2 ? P.bone : P.boneLo }); }
}

// EGG LEDGES: the shelf road up the plateau's west face; Thief's Ledge is a notch in the cliff with stolen clutches
// tucked on the shelves above it
function buildEggLedges(Z, segs, at, R, na) {
  const g = Z.group('EggLedges');
  const sg = segs.EggLedges;
  const f0 = at('EggLedges', 26);
  const c0 = g.at([f0.p[0], GROUND, f0.p[2]], [0, yawOf(f0), 0]);
  E.signBoard(c0, [-(sg.width / 2 + 5), 4, 0], 6, 1.6, 'EGG LEDGES', { color: '#fff2c4', color2: '#ff9a3a', twoSided: true, pps: 30 });
  c0.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [-(sg.width / 2 + 5), 2, 0.3], c: E.PAL.woodLo });
  // shelves on the cliff around the nest notch, each with a clutch of long blue-grey eggs (the thief's stash)
  const n = na.n;
  const f = at(n.seg, n.s);
  const yaw = yawOf(f);
  const nc = g.at([na.f.p[0], na.y, na.f.p[2]], [0, yaw, 0]);
  const shelves = [[13, 9, -6, 0.9], [13, 18, 7, 1], [4, 14, -14, 0.8], [6, 24, 14, 1.1], [12, 30, -1, 0.9]];
  shelves.forEach(([x, y, z, k], i) => {
    const s = nc.at([x, y, z], [0, R() * 40 - 20, 0]);
    s.box({ name: 'EggShelf', s: [9 * k, 1.6, 6 * k], p: [0, -0.8, 0], c: bandColor(na.y + y - 1), m: 'Slate', studs: 'top', collide: true });
    s.box({ name: 'EggShelfLip', s: [9 * k, 0.6, 1], p: [0, -1.9, -3 * k], c: P.cap, m: 'Slate' });
    for (let e = 0; e < 6; e++) { const a = (e / 6) * Math.PI * 2; s.box({ name: 'StolenEgg', s: [0.7, 0.7, 1.4], p: [Math.cos(a) * 1.3, 0.35, Math.sin(a) * 1.3], r: [20, -E.deg(a), 0], c: e % 2 ? '#5f7f8a' : '#6e8e96' }); }
    s.box({ name: 'NestTwigs', s: [3.4, 0.3, 3.4], p: [0, 0.1, 0], r: [0, 20, 0], c: '#9a7a54' });
  });
  // a lookout cairn on the drop side, two-thirds up
  const fc = at('EggLedges', 230, -(sg.width / 2 + 4));
  const cc = g.at([fc.p[0], ROAD + fc.base[1] - 0.6, fc.p[2]]);
  for (let k = 0; k < 4; k++) cc.box({ name: 'Cairn', s: [2.4 - k * 0.4, 1, 2.4 - k * 0.4], p: [0, 0.5 + k, 0], r: [0, k * 30, 0], c: bandColor(k * 4), m: 'Slate', studs: 'top' });
}

// THE FIGHTING DINOSAURS: a buttress of the north cliffs with a fossil relief: a raptor locked with a Protoceratops,
// bone-white blocks on dark matrix rock, a paleontologists' scaffold below
function buildRelief(Z, R) {
  const g = Z.group('FightingDinosaurs');
  const c = g.at([RELIEF.x, 0, RELIEF.z], [0, 180, 0]); // local -Z faces south, over the wash
  // the buttress (banded like the cliffs behind it)
  bands(0, 66, (a, b, col, mat) => c.box({ name: 'Strata', s: [86 + (R() - 0.5) * 3, b - a, 24], p: [(R() - 0.5) * 1.5, (a + b) / 2, 12 + (R() - 0.5)], c: col, m: mat, collide: true }));
  c.box({ name: 'CliffTop', s: [80, 1.2, 22], p: [0, 66.6, 12], c: P.plateauTop[1], studs: 'top', collide: true });
  const Y0 = 13;
  // the matrix panel and a cream frame of dressed stone
  c.box({ name: 'Matrix', s: [80, 40, 0.8], p: [0, Y0 + 18, -0.3], c: P.matrix, m: 'Slate' });
  c.box({ name: 'MatrixShade', s: [74, 34, 0.3], p: [0, Y0 + 18, -0.8], c: P.matrixLo, m: 'Slate' });
  for (const [x, y, w, h] of [[0, Y0 - 2.6, 84, 2.4], [0, Y0 + 38.6, 84, 2.4], [-41, Y0 + 18, 2.4, 43.6], [41, Y0 + 18, 2.4, 43.6]]) c.box({ name: 'ReliefFrame', s: [w, h, 2], p: [x, y, -0.6], c: '#efd3a2', m: 'Concrete', studs: 'top' });
  const D = -1.6;
  const bone = (a, b, w, col) => c.beam([a[0], Y0 + a[1], D], [b[0], Y0 + b[1], D], w, 1.3, { name: 'FossilBone', c: col || P.bone, up: [0, 0, 1], extend: Math.min(1, w * 0.6) });
  const chain = (pts, w0, w1) => { for (let i = 0; i < pts.length - 1; i++) bone(pts[i], pts[i + 1], w0 + (w1 - w0) * (i / Math.max(1, pts.length - 2)), i % 2 ? P.boneLo : P.bone); };
  const blk = (x, y, w, h, rot, col) => c.box({ name: 'FossilBone', s: [w, h, 1.4], p: [x, Y0 + y, D], r: [0, 0, rot || 0], c: col || P.bone });
  const dark = (x, y, w, h) => c.box({ name: 'FossilSocket', s: [w, h, 0.4], p: [x, Y0 + y, D - 0.62], c: '#4a2a1e' });
  // VELOCIRAPTOR (left, facing right): stiff tail, S-neck, long low skull, its arm in the Protoceratops' beak and
  // the sickle claw of its kicking foot driven up into the Protoceratops' throat
  chain([[-37, 9], [-30, 10], [-23, 11.5], [-15, 13.5], [-8, 15]], 1.1, 1.8);
  blk(-8, 15.5, 4.4, 3, -10);
  bone([-8, 15], [-6, 11], 1.2, P.boneLo);
  chain([[-8, 15], [-12, 18], [-16, 20], [-20, 21]], 1.9, 1.7);
  for (let i = 0; i < 4; i++) { const x = -10 - i * 2.6, y = 17 + i * 1.1; bone([x, y], [x + 1.4, y - 5.2 + i * 0.3], 0.7, P.boneLo); }
  chain([[-20, 21], [-23.5, 24], [-23.5, 28], [-20.5, 30.5]], 1.5, 1.3);
  bone([-21, 31.2], [-11, 30.2], 2.8);
  bone([-20, 29.3], [-11.5, 29], 1, P.boneLo);
  dark(-17.6, 31.4, 1.1, 1.1);
  for (let i = 0; i < 4; i++) blk(-18 + i * 1.8, 29.9, 0.35, 0.8, 0, '#fff6e0');
  chain([[-19, 19.5], [-14, 23.5], [-7, 25.5], [-3.5, 25]], 1.3, 0.9);
  chain([[-19.5, 19], [-17, 15], [-13.5, 14.5]], 1, 0.9);
  bone([-8, 15], [-1, 10], 2.1); bone([-1, 10], [5, 15], 1.6, P.boneLo); bone([5, 15], [7.5, 18.5], 1.2);
  bone([7.5, 18.5], [9.4, 21.4], 0.9, '#fff6e0'); bone([9.4, 21.4], [8.8, 23.2], 0.6, '#fff6e0');
  bone([-8, 15], [-12, 8], 2.1); bone([-12, 8], [-8, 3], 1.6, P.boneLo); bone([-8, 3], [-6, 1], 1.2); bone([-6, 1], [-1.6, 0.8], 0.9, P.boneLo);
  // PROTOCERATOPS (right, facing left): beak clamped, frill up, back arched, legs braced
  bone([1.5, 24.2], [9.5, 25.4], 6);
  bone([0.5, 26], [-2, 23.4], 1.7, P.boneLo);
  blk(-0.2, 24.6, 2.6, 3, 18);
  bone([1.5, 21.4], [8.5, 22], 2.2, P.boneLo);
  dark(5.4, 26.4, 1.3, 1.3);
  bone([8, 26], [14.6, 33.2], 7.4);
  bone([10.2, 33.4], [16.4, 28.6], 1, P.boneLo);
  dark(11.4, 30.4, 1.6, 2.2);
  bone([9, 23], [14, 21.6], 2.5, P.boneLo);
  chain([[14, 21.6], [19, 23], [24, 23], [28, 21.6], [31, 18], [34, 14], [37, 10]], 2.1, 1.1);
  for (let i = 0; i < 5; i++) { const x = 16 + i * 2.5, y = 22.4 + (i < 3 ? i * 0.3 : (4 - i) * 0.3); bone([x, y], [x - 1, y - 7], 0.8, P.boneLo); }
  blk(27, 20, 5, 3, 8);
  bone([15, 20], [13.5, 12], 2.1); bone([13.5, 12], [14.5, 4], 1.6, P.boneLo); bone([14.5, 4], [11, 1.2], 1.4);
  bone([27, 20], [30, 11], 2.5); bone([30, 11], [27.5, 4], 1.8, P.boneLo); bone([27.5, 4], [24, 1.2], 1.4);
  // the dig: a plank scaffold, ladder, lanterns and a sign on the wash floor
  const s = c.at([-30, 0, -5]);
  for (const x of [-4, 4]) for (const z of [-2, 2]) s.box({ name: 'ScaffoldPost', s: [0.5, 10, 0.5], p: [x, 5, z], c: P.woodLo });
  s.box({ name: 'ScaffoldDeck', s: [9.6, 0.4, 5], p: [0, 10, 0], c: P.wood, m: 'WoodPlanks', studs: 'top' });
  for (let k = 0; k < 6; k++) s.box({ name: 'LadderRung', s: [2, 0.25, 0.25], p: [5.6, 1.4 + k * 1.6, -2.6], c: P.wood });
  for (const x of [4.6, 6.6]) s.box({ name: 'LadderRail', s: [0.3, 10.4, 0.3], p: [x, 5.2, -2.6], c: P.woodLo });
  E.crate(s, [-2, 10.2, 0], 0.7, { yaw: 12 });
  E.lampPost(c, [-18, 0, -8], { h: 7, yaw: 180 });
  E.lampPost(c, [22, 0, -8], { h: 7, yaw: 180 });
  const sc = c.at([4, 0, -12]);
  E.signBoard(sc, [0, 4.4, 0], 10, 2.2, 'FIGHTING DINOSAURS', { r: [0, 180, 0], color: '#fff2c4', color2: '#ff6a2a', twoSided: true, pps: 30, trim: '#ff6a2a' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: E.PAL.woodLo });
  for (let k = 0; k < 6; k++) E.rock(c, [-40 + k * 16 + R() * 6, 0, -3 - R() * 4], 1 + R() * 0.8, 3600 + k, { colors: [bandColor(4), bandColor(15), bandColor(22)], moss: false });
}

// DRY WASH: cracked mud along the old riverbed, saxaul thickets on the banks, dune burrows on the north side
function buildWash(Z, segs, at, R, hAt) {
  const g = Z.group('DryWash');
  const sg = segs.DryWash;
  const L = sg.cum[sg.cum.length - 1];
  for (let s = 10; s < L - 10; s += 12) {
    for (let x = 20; x <= 46; x += 11) for (const side of [-1, 1]) {
      if (R() < 0.25) continue;
      const f = at('DryWash', s + (R() - 0.5) * 4, side * (x + (R() - 0.5) * 3));
      if (hAt(f.p[0], f.p[2]) > 0.1) continue;
      if (Math.hypot(f.p[0] - GROVE.x, f.p[2] - GROVE.z) < GROVE.r + 26) continue;
      const c = g.at([f.p[0], GROUND, f.p[2]], [0, yawOf(f) + (R() - 0.5) * 30, 0]);
      const w = 8 + R() * 3, d = 8 + R() * 3;
      c.box({ name: 'MudPlate', s: [w, 0.12, d], p: [0, 0.06, 0], c: P.mud[Math.floor(R() * 4)], m: 'Sand', shadow: false });
      if (R() > 0.4) c.box({ name: 'MudCrack', s: [w, 0.2, 0.35], p: [0, 0.08, d / 2], r: [0, (R() - 0.5) * 20, 0], c: P.crack, shadow: false });
      if (R() > 0.55) c.box({ name: 'MudCrack', s: [0.35, 0.2, d], p: [w / 2, 0.08, 0], r: [0, (R() - 0.5) * 20, 0], c: P.crack, shadow: false });
    }
  }
  // the old channel: pebble bars snaking along beside the road
  for (let s = 20; s < L - 20; s += 7) {
    const x = Math.sin(s / 40) * 6 + (s % 2 ? 17 : -17);
    const f = at('DryWash', s, x);
    if (hAt(f.p[0], f.p[2]) > 0.1) continue;
    g.box({ name: 'Pebbles', s: [2 + R() * 2, 0.5, 1.4 + R()], p: [f.p[0], GROUND + 0.2, f.p[2]], r: [0, R() * 180, 0], c: R() > 0.5 ? '#b8a088' : '#a89078', m: 'Pebble' });
  }
  const f = at('DryWash', 18);
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, yawOf(f), 0]);
  E.signBoard(c, [sg.width / 2 + 5, 4, 0], 6, 1.6, 'DRY WASH', { color: '#fff2c4', color2: '#ff9a3a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [sg.width / 2 + 5, 2, 0.3], c: E.PAL.woodLo });
  // DUNE BURROWS: a sand bank behind the Protoceratops nest, holes dug into it, skulls of the old herd
  const n2 = NESTS[1];
  const nf = at(n2.seg, n2.s, n2.x);
  const away = [nf.p[0] - at(n2.seg, n2.s).p[0], nf.p[2] - at(n2.seg, n2.s).p[2]];
  const al = Math.hypot(...away);
  const bk = g.at([nf.p[0] + (away[0] / al) * 19, GROUND, nf.p[2] + (away[1] / al) * 19], [0, E.deg(Math.atan2(away[0], away[1])) + 180, 0]); // local -Z faces the nest
  for (let k = 0; k < 4; k++) bk.box({ name: 'DuneSide', s: [40 - k * 7, 2.4, 9 - k * 1.2], p: [(R() - 0.5) * 3, 1.2 + k * 2.4, k * 1.6], c: k % 2 ? P.sandSide : P.sandLo, m: 'Sand', collide: true });
  bk.box({ name: 'DuneTop', s: [18, 1, 4], p: [0, 10, 5], c: P.crest, studs: 'top', collide: true });
  for (let k = 0; k < 5; k++) {
    const x = -14 + k * 7 + (R() - 0.5) * 2, y = 1.6 + (k % 2) * 2.6;
    bk.box({ name: 'Burrow', s: [3.2, 2.2, 0.6], p: [x, y, -4.3 + (y > 3 ? 1.6 : 0)], c: '#4a2e1e' });
    bk.box({ name: 'BurrowLip', s: [4, 0.6, 1.2], p: [x, y - 1.3, -4.8 + (y > 3 ? 1.6 : 0)], c: P.sandLo, m: 'Sand' });
  }
  for (let k = 0; k < 3; k++) protoSkull(bk, [-12 + k * 12, 0, -8 - R() * 4], R() * 360, 1.4, 4700 + k);
}

// HOODOO MAZE: the plateau's eroded east fringe, the road weaving through hoodoos, fins and balanced rocks
function buildHoodoos(Z, segs, at, R, hAt, nearRoad) {
  const g = Z.group('HoodooMaze');
  const sg = segs.HoodooMaze;
  const L = sg.cum[sg.cum.length - 1];
  const fin0 = at(FINAL.seg, FINAL.s, FINAL.x);
  const spots = [];
  const ok = (x, z, r) => !nearRoad(x, z, r + 3) && hAt(x, z) < 0.1 && !spots.some(([px, pz, pr]) => Math.hypot(px - x, pz - z) < pr + r + 1.5) && Math.hypot(x - fin0.p[0], z - fin0.p[2]) > 44;
  // walls of hoodoos lining the road (so it reads as a maze from the driver's seat)
  for (let s = 18; s < L - 14; s += 8 + R() * 5) {
    for (const side of [-1, 1]) {
      const f = at('HoodooMaze', s, side * (sg.width / 2 + 5 + R() * 7));
      const h = 12 + R() * 16;
      const r = 3 + h * 0.05;
      if (!ok(f.p[0], f.p[2], r)) continue;
      spots.push([f.p[0], f.p[2], r]);
      hoodoo(g, [f.p[0], GROUND, f.p[2]], h, 5000 + spots.length, { balanced: R() > 0.85 });
    }
  }
  // the field around: more hoodoos, fins and balanced rocks between the road, the plateau and the flats
  for (let k = 0; k < 900 && spots.length < 120; k++) {
    const s = R() * L;
    const side = R() > 0.5 ? 1 : -1;
    const f = at('HoodooMaze', s, side * (sg.width / 2 + 14 + R() * 46));
    if (f.p[0] > 290) continue;
    const pick = R();
    if (pick < 0.16) {
      const len = 12 + R() * 14, h = 14 + R() * 12;
      if (!ok(f.p[0], f.p[2], len / 2)) continue;
      spots.push([f.p[0], f.p[2], len / 2]);
      fin(g, [f.p[0], GROUND, f.p[2]], yawOf(f) + 90 + (R() - 0.5) * 40, len, h, 5300 + k);
    } else {
      const h = 9 + R() * 20, r = 3 + h * 0.05;
      if (!ok(f.p[0], f.p[2], r)) continue;
      spots.push([f.p[0], f.p[2], r]);
      hoodoo(g, [f.p[0], GROUND, f.p[2]], h, 5400 + k, { balanced: pick > 0.88 });
    }
  }
  const f = at('HoodooMaze', 44);
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, yawOf(f), 0]);
  E.signBoard(c, [sg.width / 2 + 4, 4, 0], 7, 1.6, 'HOODOO MAZE', { color: '#fff2c4', color2: '#ff9a3a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [sg.width / 2 + 4, 2, 0.3], c: E.PAL.woodLo });
}

// RUNNER FLATS: a wide pale clay pan where the Gallimimus herds run; three-toed tracks everywhere
function buildFlats(Z, segs, at, R) {
  const g = Z.group('RunnerFlats');
  const sg = segs.RunnerFlats;
  const L = sg.cum[sg.cum.length - 1];
  for (let s = 16; s < L - 16; s += 15) {
    for (let x = 22; x <= 70; x += 15) for (const side of [-1, 1]) {
      if (R() < 0.3) continue;
      const f = at('RunnerFlats', s + (R() - 0.5) * 5, side * (x + (R() - 0.5) * 4));
      if (f.p[0] < 236 || f.p[0] > BX - 30) continue;
      const c = g.at([f.p[0], GROUND, f.p[2]], [0, R() * 90, 0]);
      const w = 11 + R() * 4, d = 11 + R() * 4;
      c.box({ name: 'ClayPan', s: [w, 0.1, d], p: [0, 0.05, 0], c: P.clay[Math.floor(R() * 3)], m: 'Sand', shadow: false });
      if (R() > 0.5) c.box({ name: 'ClayCrack', s: [w * 0.8, 0.16, 0.3], p: [0, 0.06, (R() - 0.5) * d * 0.6], r: [0, (R() - 0.5) * 40, 0], c: P.clayCrack, shadow: false });
    }
  }
  // runner tracks: trails of three-toed prints crossing the flats
  for (let k = 0; k < 9; k++) {
    const f = at('RunnerFlats', 30 + R() * (L - 60), (R() > 0.5 ? 1 : -1) * (20 + R() * 40));
    if (f.p[0] < 236) continue;
    const yaw = R() * 360;
    const c = g.at([f.p[0], GROUND + 0.02, f.p[2]], [0, yaw, 0]);
    for (let j = 0; j < 8; j++) {
      const pc = c.at([(j % 2 ? 1.2 : -1.2), 0, -j * 4], [0, (j % 2 ? 6 : -6), 0]);
      pc.box({ name: 'TrackHeel', s: [1, 0.06, 1], p: [0, 0, 0.4], c: P.clayCrack, shadow: false });
      for (const a of [-24, 0, 24]) pc.at([0, 0, 0], [0, a, 0]).box({ name: 'TrackToe', s: [0.4, 0.06, 1.6], p: [0, 0, -0.8], c: P.clayCrack, shadow: false });
    }
  }
  const f = at('RunnerFlats', 44);
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, yawOf(f), 0]);
  E.signBoard(c, [-(sg.width / 2 + 5), 4, 0], 7, 1.6, 'RUNNER FLATS', { color: '#fff2c4', color2: '#ff9a3a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [-(sg.width / 2 + 5), 2, 0.3], c: E.PAL.woodLo });
}

// THE CLAW RING: the final stand, a pan ringed by sandstone fins scored with huge claw gashes
function buildClawRing(Z, at, R, nearRoad) {
  const f = at(FINAL.seg, FINAL.s, FINAL.x);
  const road = at(FINAL.seg, FINAL.s, 0);
  const toRoad = Math.atan2(-(road.p[0] - f.p[0]), -(road.p[2] - f.p[2]));
  const g = Z.group('ClawRing');
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, E.deg(toRoad), 0]); // local -Z faces the road
  c.cyl({ name: 'ClayPan', axis: 'y', len: 0.12, d: 70, p: [0, 0.06, 0], c: P.clay[1], m: 'Sand', shadow: false });
  for (let k = 0; k < 14; k++) c.box({ name: 'ClayCrack', s: [0.35, 0.16, 6 + R() * 8], p: [(R() - 0.5) * 50, 0.08, (R() - 0.5) * 50], r: [0, R() * 180, 0], c: P.clayCrack, shadow: false });
  const N = 10;
  for (let k = 0; k < N; k++) {
    const a = (k / N) * Math.PI * 2 + 0.2;
    if (Math.cos(a) < -0.75) continue; // the side facing the road stays open
    const r = 34 + R() * 4;
    const x = Math.sin(a) * r, z = Math.cos(a) * r;
    const h = 16 + R() * 12;
    { const w = c.wpt([x, 0, z]); if (nearRoad(w[0] - RC_ORIGIN[0], w[2] - RC_ORIGIN[2], 12)) continue; }
    const fc = c.at([x, 0, z], [0, E.deg(a) + 90, 0]);
    fin(fc, [0, GROUND, 0], 0, 10 + R() * 6, h, 6100 + k);
    // three claw gashes raked across the inner face
    const gc = c.at([Math.sin(a) * (r - 2.1), 0, Math.cos(a) * (r - 2.1)], [0, E.deg(a) + 180, 0]);
    for (let j = 0; j < 3; j++) gc.box({ name: 'ClawGash', s: [0.6, 8, 0.4], p: [-1.6 + j * 1.6, 7 + R() * 3, 0], r: [0, 0, 24], c: '#4a2a1e' });
  }
  const sc = c.at([10, 0, -29], [0, 180, 0]);
  E.signBoard(sc, [0, 4.4, 0], 7, 2, 'THE CLAW RING', { color: '#fff2c4', color2: '#ff6a2a', twoSided: true, pps: 30, trim: '#ff6a2a' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: E.PAL.woodLo });
}

// SCYTHE GROVE — the Therizinosaurus' den: a spring-fed grove in a box canyon under the plateau. Tall conifers it
// rakes (tagged ScytheTree), a waterfall into a pool, a stream out to the wash, an overhang of cliff above the
// Throne (a mossy slab), ledges round the walls. Markers drive the fight + the chase.
function buildGrove(Z, at, R, route) {
  const g = Z.group('ScytheGrove');
  const segs = route.segs;
  const sg = segs.DryWash;
  const pr = RT.project(sg.samples, sg.cum, [GROVE.x, 0, GROVE.z]);
  const roadF = at('DryWash', pr.s);
  const toRoad = Math.atan2(-(roadF.p[0] - GROVE.x), -(roadF.p[2] - GROVE.z));
  const c = g.at([GROVE.x, GROUND, GROVE.z], [0, E.deg(toRoad), 0]); // local -Z points at the road (the mouth)
  c.cyl({ name: 'GroveGrass', axis: 'y', len: 0.14, d: GROVE.r * 2 + 6, p: [0, 0.07, 0], c: P.grass[0], m: 'Grass', shadow: false });
  for (let k = 0; k < 16; k++) { const a = R() * Math.PI * 2, r = R() * (GROVE.r - 6); E.groundPatch(c, [Math.cos(a) * r, 0.1, Math.sin(a) * r], 6 + R() * 5, 3900 + k, { colors: P.grass, n: 2 }); }
  // the mouth: grass spilling out into the wash
  for (let k = 0; k < 6; k++) c.box({ name: 'GroveGrass', s: [10 + R() * 8, 0.12, 8 + R() * 4], p: [(R() - 0.5) * 22, 0.08, -GROVE.r - 2 - k * 6], r: [0, R() * 40, 0], c: P.grass[k % 4], m: 'Grass', shadow: false });
  // the spring: a waterfall down the back wall into a pool; a stream winding out of the mouth
  E.waterfall(c, [8, 30, GROVE.r - 4.5], 7, 30, { seed: 3901, name: 'GroveFalls', mist: 6 });
  const pool = c.at([8, 0, GROVE.r - 20]);
  pool.cyl({ name: 'PoolShore', axis: 'y', len: 0.3, d: 18, p: [0, 0.15, 0], c: '#c9b08a', m: 'Sand', shadow: false });
  pool.cyl({ name: 'PoolWater', axis: 'y', len: 0.3, d: 15, p: [0, 0.3, 0], c: P.water, m: 'Glass', t: 0.2, shadow: false }).tag('DinoWater');
  for (let k = 0; k < 12; k++) { const a = (k / 12) * Math.PI * 2; pool.box({ name: 'PoolStone', s: [1.6 + R(), 0.8, 1.4 + R()], p: [Math.cos(a) * 8.4, 0.3, Math.sin(a) * 8.4], r: [0, -E.deg(a), R() * 8], c: '#8a7a6a', m: 'Slate' }); }
  const stream = [];
  for (let k = 0; k <= 9; k++) { const u = k / 9; stream.push([8 - u * 14 + Math.sin(u * 7) * 6, 0, GROVE.r - 25 - u * (2 * GROVE.r - 1)]); }
  for (let k = 0; k < 9; k++) {
    c.beam([stream[k][0], 0.24, stream[k][2]], [stream[k + 1][0], 0.24, stream[k + 1][2]], 3.6 - k * 0.22, 0.12, { name: 'GroveStream', c: P.water, m: 'Glass', t: 0.15, shadow: false, extend: 1.2 }).tag('DinoWater');
    c.beam([stream[k][0], 0.1, stream[k][2]], [stream[k + 1][0], 0.1, stream[k + 1][2]], 5.4 - k * 0.3, 0.1, { name: 'StreamPebble', c: '#a8987e', m: 'Pebble', shadow: false, extend: 1.4 });
  }
  // the overhang: the cliff juts out over the back of the grove ("under the cliffs")
  const OY = 42;
  bands(OY, OY + 12, (a, b, col, mat) => {
    for (let k = 0; k < 5; k++) {
      const x = -24 + k * 12;
      const reach = 14 + Math.sin(k * 1.7) * 4 + (b - OY) * 0.4;
      c.box({ name: 'Strata', s: [12.4, b - a, reach], p: [x, (a + b) / 2 - GROUND, GROVE.r - reach / 2 + 2], c: col, m: mat, collide: true });
    }
  });
  for (let k = 0; k < 7; k++) c.box({ name: 'HangingRoots', s: [0.3, 3 + R() * 5, 0.3], p: [-24 + R() * 48, OY - 2 - R() * 2 - GROUND, GROVE.r - 14 - R() * 6], c: '#5a7a34', shadow: false });
  // THE THRONE: a mossy slab under the overhang
  const th = c.at([-6, 0, GROVE.r - 16]);
  th.box({ name: 'Throne', s: [16, 3, 12], p: [0, 1.5, 0], c: '#9a6a46', m: 'Slate', studs: 'top', collide: true });
  th.box({ name: 'ThroneMoss', s: [12, 0.4, 8], p: [0.6, 3.1, 0.4], c: P.grass[2], studs: 'top' });
  th.box({ name: 'ThroneStep', s: [20, 1.4, 15], p: [0, 0.7, 0.6], c: '#8a5a3a', m: 'Slate', studs: 'top', collide: true });
  const glow = th.box({ name: 'ThroneGlow', s: [1, 1, 1], p: [0, 14, -6], t: 1, shadow: false });
  E.pointLight(glow, [1, 0.78, 0.5], 32, 0.6);
  // tall conifers round the walls (rakeable), two already torn down; tree ferns, horsetails and ferns by the water
  const trees = [];
  const ledgeAt = [[-36, 6, 8], [36, 4, 9], [-31, -22, 7], [32, -24, 8], [-28, 30, 11], [26, 30, 10]];
  for (let k = 0, made = 0; k < 600 && made < 11; k++) {
    const a = R() * Math.PI * 2, r = 22 + R() * 11;
    const x = Math.sin(a) * r, z = Math.cos(a) * r;
    if (z < -GROVE.r * 0.45 && Math.abs(x) < 16) continue; // the mouth stays open
    if (Math.abs(x + 3) < 11) continue; // a clear lane from the mouth to the throne
    if (!((z > 8 && Math.abs(x + 3) > 15) || (z < -24 && Math.abs(x) > 18))) continue; // the fight floor in the middle stays open
    if (Math.hypot(Math.abs(x) - 22, z + 18) < 8) continue; // where the ruler cameras stand
    if (Math.abs(x + 6) < 15 && z > GROVE.r - 30) continue; // the throne
    if (Math.hypot(x - 8, z - (GROVE.r - 20)) < 13) continue; // the pool
    if (ledgeAt.some(([lx, lz]) => Math.hypot(x - lx, z - lz) < 9)) continue;
    if (trees.some(([tx, tz]) => Math.hypot(x - tx, z - tz) < 11)) continue;
    trees.push([x, z]);
    made++;
    const back = z > GROVE.r - 34;
    groveConifer(c, [x, 0, z], back ? 26 + R() * 8 : 34 + R() * 14, 3920 + k);
    // claw rakes on the trunk
    const tc = c.at([x, 0, z], [0, E.deg(Math.atan2(-x, -z)), 0]);
    if (made % 3 === 0) for (let j = 0; j < 3; j++) tc.box({ name: 'ClawRake', s: [0.25, 2.6, 0.2], p: [-0.5 + j * 0.5, 5 + R(), -0.95], r: [0, 0, 22], c: '#e8c89a' });
  }
  for (const [x, z, yaw] of [[-20, 4, 40], [22, -10, -25]]) {
    const fc = c.at([x, 0, z], [0, yaw, 0]);
    fc.cyl({ name: 'FallenTrunk', axis: 'z', len: 24, d: 1.8, p: [0, 0.9, 0], c: P.bark[0] });
    fc.cyl({ name: 'FallenTrunkEnd', axis: 'z', len: 24.1, d: 1.2, p: [0, 0.9, 0], c: '#d9a86a' });
    for (let j = 0; j < 4; j++) fc.box({ name: 'FallenCrown', s: [4 - j * 0.6, 1.8, 3], p: [(R() - 0.5), 1.2, 13 + j * 2.6], r: [0, R() * 40, 70], c: P.conifer[j % 4], studs: 'top' });
    fc.box({ name: 'Stump', s: [1.9, 2.4, 1.9], p: [0, 1.2, -13], c: P.bark[1], studs: 'top' });
  }
  for (let k = 0; k < 10; k++) { const st = stream[1 + Math.floor(R() * 8)]; horsetail(c, [st[0] + (R() > 0.5 ? 4 : -4), 0, st[2] + (R() - 0.5) * 6], 3950 + k); }
  for (let k = 0; k < 18; k++) {
    const a = R() * Math.PI * 2, r = 8 + R() * (GROVE.r - 14);
    const x = Math.sin(a) * r, z = Math.cos(a) * r;
    if (Math.abs(x + 6) < 12 && z > GROVE.r - 26) continue;
    E.fern(c, [x, 0, z], 1.4 + R() * 0.8, 3970 + k);
  }
  for (let k = 0; k < 6; k++) { const a = R() * Math.PI * 2, r = 10 + R() * 20; E.flowers(c, [Math.sin(a) * r, 0, Math.cos(a) * r], 3990 + k, { n: 4, spread: 3, colors: ['#ffd23a', '#ffffff', '#ff8ab0'] }); }
  // ledges round the walls (sandstone stacks you can climb out of reach on)
  ledgeAt.forEach(([x, z, h], i) => {
    const lc = c.at([x, 0, z]);
    bands(GROUND, GROUND + h, (a, b, col, mat) => lc.box({ name: 'LedgeRock', s: [7 - (a - GROUND) * 0.12, b - a + 0.05, 7 - (a - GROUND) * 0.12], p: [0, (a + b) / 2 - GROUND, 0], r: [0, a * 9, 0], c: col, m: mat, studs: 'top', collide: true }), 4);
    lc.box({ name: 'LedgeTop', s: [5.6, 0.6, 5.6], p: [0, h + 0.3, 0], c: P.grass[1], studs: 'top', collide: true });
    marker(lc, 'DenLedge' + (i + 1), [0, h + 0.6, 0], 0, { s: [2, 0.4, 2] });
  });
  // the mouth: two sentinel pillars; the sign
  for (const sd of [-1, 1]) hoodoo(c, [sd * 22, GROUND, -GROVE.r - 6], 26 + R() * 6, 3999 + sd, {});
  const sc = c.at([-14, 0, -GROVE.r - 14], [0, 180, 0]);
  E.signBoard(sc, [0, 4.6, 0], 9, 2.2, 'SCYTHE GROVE', { color: '#fff2c4', color2: '#ff6a2a', twoSided: true, pps: 30, trim: '#ff6a2a' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [0, 2.2, 0.3], c: E.PAL.woodLo });
  // fireflies drifting in the shade (subtle)
  const ff = c.box({ name: 'GroveFireflies', s: [60, 8, 60], p: [0, 6, 0], t: 1, shadow: false });
  ff.set('CanQuery', 'bool', false);
  E.particles(ff, 'Fireflies', { rate: 6, life: [3, 5], speed: [0.3, 1], size: [[0, 0.25], [0.5, 0.35], [1, 0]], transp: [[0, 1], [0.3, 0.2], [0.7, 0.2], [1, 1]], color: [1, 0.9, 0.5], emission: 0.6 });
  // markers for the fight + the chase that follows
  const v0 = route.variants[0];
  const segS = (segId, s) => { const k = v0.segs.indexOf(segId); return k < 0 ? 0 : v0.segStart[k] + s; };
  const dc = marker(c, 'DenCenter', [0, 0.5, -8], 0, { s: [2, 1, 2] });
  dc.attr('RouteS', +segS('DryWash', pr.s).toFixed(1)).attr('RouteX', +pr.x.toFixed(1)).attr('Variant', 1);
  const ff2 = at(FINAL.seg, FINAL.s, FINAL.x);
  const fm = marker(Z, 'FinalArena', [ff2.p[0], GROUND + 0.5, ff2.p[2]], 0, { s: [2, 1, 2] });
  fm.attr('RouteS', +segS(FINAL.seg, FINAL.s).toFixed(1)).attr('RouteX', 8).attr('Variant', 1);
}

// weather: dust devils wandering the flats and the dune sea; low sand drifting off the dune crests
function buildWeather(Z, at, R) {
  const g = Z.group('Weather', 'Folder');
  const spots = [[340, 10], [352, 170], [-300, -30], [-330, 190], [30, -330], [-250, 280], [300, -200]];
  spots.forEach(([x, z], k) => {
    const h = g.box({ name: 'DustDevil', s: [2, 1, 2], p: [x, GROUND + 0.5, z], t: 1, shadow: false });
    h.set('CanQuery', 'bool', false);
    E.particles(h, 'Column', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 14, life: [2.5, 4], speed: [7, 11], dir: 1, spread: [7, 7], size: [[0, 1.5], [0.5, 5], [1, 10]], transp: [[0, 0.55], [0.7, 0.75], [1, 1]], color: [0.86, 0.6, 0.4], emission: 0, accel: [0, 2, 0], drag: 0.6 });
    E.particles(h, 'Grit', { rate: 10, life: [1, 2], speed: [4, 8], dir: 1, spread: [30, 30], size: [[0, 0.3], [1, 0.1]], color: [0.72, 0.46, 0.3], emission: 0, accel: [0, -4, 0] });
    h.attr('Wander', 18 + k * 3);
  });
  for (const [x, z] of [[-300, 60], [-280, -160], [40, 330]]) {
    const d = g.box({ name: 'SandDrift', s: [120, 1, 90], p: [x, GROUND + 3, z], t: 1, shadow: false });
    d.set('CanQuery', 'bool', false);
    E.particles(d, 'Drift', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 3, life: [5, 8], speed: [4, 7], dir: 0, spread: [10, 10], size: [[0, 4], [1, 12]], transp: [[0, 0.8], [1, 1]], color: [0.95, 0.76, 0.52], emission: 0, accel: [2, 0.3, 0] });
  }
}

function buildCinematics(Z, at) {
  const g = Z.group('Cinematics', 'Folder');
  const shot = (name, pos, look) => {
    const l = Z.wpt(look);
    const m = marker(g, name, pos, 0, { s: [1, 1, 1] });
    m.attr('LookX', +l[0].toFixed(2)).attr('LookY', +l[1].toFixed(2)).attr('LookZ', +l[2].toFixed(2));
    return m;
  };
  const arch = at(ARCH.seg, ARCH.s);
  const flats = at(NESTS[2].seg, NESTS[2].s, NESTS[2].x);
  const burrows = at(NESTS[1].seg, NESTS[1].s, NESTS[1].x);
  // 1: over the arrival, through the Great Arch to the plateau cliffs at dusk
  shot('EstShot1', [arch.p[0] - 30, 64, arch.p[2] + 150], [arch.p[0] + 50, 40, arch.p[2] - 160]);
  // 2: the Gallimimus on the Runner Flats, the sandstorm wall behind them
  shot('EstShot2', [flats.p[0] - 70, 14, flats.p[2] + 30], [flats.p[0], 3, flats.p[2]]);
  // 3: a Protoceratops crossing by the burrows, the wash and the Fighting Dinosaurs wall behind it
  shot('EstShot3', [burrows.p[0] - 60, 8, burrows.p[2] + 14], [burrows.p[0], 3, burrows.p[2]]);
  // 4: into the Scythe Grove from the wash
  shot('EstShot4', [GROVE.x - 10, 34, GROVE.z - 100], [GROVE.x, 14, GROVE.z + 10]);
}

function buildNestSite(Z, na, at, R) {
  const { n, f } = na;
  const gy = na.y > 0 ? na.y : GROUND;
  const g = Z.group('Nest_' + n.species);
  g.parent.attr('NestId', n.id).attr('Species', n.species).tag('ExpeditionNest');
  const c = g.at([f.p[0], gy, f.p[2]], [0, R() * 360, 0]);
  const cl = { Oviraptor: '#d9a066', Protoceratops: '#e2b27a', Gallimimus: '#e6c09a' }[n.species];
  c.cyl({ name: 'Clearing', axis: 'y', len: 0.1, d: 24, p: [0, 0.05, 0], c: cl, m: 'Sand', shadow: false });
  if (n.species === 'Oviraptor') {
    // a ring-clutch in a low sand mound: long eggs laid in pairs round the middle
    c.cyl({ name: 'NestMound', axis: 'y', len: 1.1, d: 9, p: [0, 0.55, 0], c: '#c98a56', m: 'Sand' });
    for (let k = 0; k < 10; k++) { const a = (k / 10) * Math.PI * 2; c.box({ name: 'ClutchEgg', s: [0.7, 0.7, 1.5], p: [Math.cos(a) * 3.4, 1.2, Math.sin(a) * 3.4], r: [26, -E.deg(a) + 90, 0], c: k % 2 ? '#5f7f8a' : '#6e8e96' }); }
  } else if (n.species === 'Protoceratops') {
    c.cyl({ name: 'NestMound', axis: 'y', len: 1.3, d: 10, p: [0, 0.65, 0], c: '#d99c62', m: 'Sand' });
    for (let k = 0; k < 14; k++) { const a = (k / 14) * Math.PI * 2; c.box({ name: 'NestScrub', s: [2.6, 0.5, 1], p: [Math.cos(a) * 4.6, 1.2 + (k % 2) * 0.3, Math.sin(a) * 4.6], r: [R() * 20, -E.deg(a) + 90, R() * 15], c: P.saxLeaf[k % 4] }); }
  } else {
    // a scrape lined with pebbles and dry grass
    c.cyl({ name: 'NestMound', axis: 'y', len: 0.8, d: 9, p: [0, 0.4, 0], c: '#cfa47a', m: 'Sand' });
    for (let k = 0; k < 16; k++) { const a = (k / 16) * Math.PI * 2; c.box({ name: 'NestPebble', s: [1, 0.7, 1], p: [Math.cos(a) * 4.4, 0.9, Math.sin(a) * 4.4], r: [0, R() * 90, 0], c: k % 3 ? '#b8a088' : '#9a8670', m: 'Pebble' }); }
    for (let k = 0; k < 8; k++) { const a = (k / 8) * Math.PI * 2 + 0.2; c.box({ name: 'NestGrass', s: [2.4, 0.3, 0.6], p: [Math.cos(a) * 3.2, 0.95, Math.sin(a) * 3.2], r: [0, -E.deg(a) + 90, 10], c: P.tuft[k % 4] }); }
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
  E.flag(c, [0.37, 0, 16], '#ff6a2a', { h: 7 });
  const sy = na.y > 0 ? na.y : GROUND;
  const sgn = g.at([f.base[0] - f.r[0] * (n.x > 0 ? -19 : 19), sy, f.base[2] - f.r[2] * (n.x > 0 ? -19 : 19)], [0, yawOf(f) + 180, 0]);
  E.signBoard(sgn, [0, 4.2, 0], 7, 2.2, n.label, { color: '#fff2c4', color2: '#ff6a2a', twoSided: true, pps: 30, trim: '#ff6a2a' });
  sgn.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: E.PAL.woodLo });
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
  E.particles(host, 'NestGlint', { rate: 3, life: [0.8, 1.4], speed: [0.5, 1], size: [[0, 0.5], [1, 0]], color: [1, 0.95, 0.6], emission: 1 });
  E.pointLight(host, [1, 0.8, 0.5], 18, 0.8);
  // cover round the clearing: saxaul and rocks
  for (let k = 0; k < 5; k++) {
    const a = (k / 5) * Math.PI * 2 + 0.9;
    const x = Math.cos(a) * 15, z = Math.sin(a) * 15;
    if (k % 2) E.rock(c, [x, 0, z], 1.5 + R(), 85000 + n.id * 10 + k, { colors: [bandColor(gy + 2), bandColor(gy + 8), bandColor(gy + 14)], moss: false });
    else saxaul(c, [x, 0, z], 1.1 + R() * 0.5, 85100 + n.id * 10 + k);
  }
}

// ------------------------------------------------------------------ Luau data
function routeData(route, at) {
  const O = RC_ORIGIN;
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
    const y = n.seg === 'EggLedges' ? Math.floor((at(n.seg, n.s).base[1] - 0.3) / 0.3) * 0.3 : GROUND;
    return { Id: n.id, Species: n.species, Guard: n.guard, Label: n.label, S: perVariant(n.seg, n.s), X: n.x, Pos: [+(f.p[0] + O[0]).toFixed(2), +(y + O[1]).toFixed(2), +(f.p[2] + O[2]).toFixed(2)] };
  });
  const arrival = at('DuneRoad', 4);
  return {
    Zone: 'RedCliffs', Name: 'RED CLIFFS', Era: '75,000,000 BC', Year: -75000000,
    Variants: variants, Forks: forks, Features: features, Sections: sections, Nests: nests,
    Arrival: [arrival.p[0] + O[0], arrival.p[1] + ROAD, arrival.p[2] + O[2], arrival.f[0], arrival.f[2]],
  };
}

const QC = {
  decor: ['Saxaul', 'GroveConifer', 'Bones', 'ProtoSkull', 'Horsetail'],
  ground: /^(Strata|CliffTop|DuneTop|DuneSide|MudPlate|MudCrack|Pebbles|ClayPan|ClayCrack|TrackHeel|TrackToe|GroveGrass|GroveStream|StreamPebble|PoolShore|PoolWater|BlowoutFloor|Matrix|MatrixShade|ReliefFrame|FossilBone|FossilSocket|EggShelf|EggShelfLip|LedgeRock|LedgeTop|Talus|Sand|FarSand|DigFloor|DigSpoil|CurbStone)$/,
};

module.exports = { buildRedCliffs, RC_ORIGIN, QC };
