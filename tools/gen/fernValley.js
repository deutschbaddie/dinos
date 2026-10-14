// FERN VALLEY — the first era (68,000,000 BC). One looping guided route, two forks, three nests.
//   Fern Road (tutorial, under the Fallen Giant) → fork: River Bend (Crest Lagoon, Parasaurolophus) | Fern Tunnel
//   → Raptor Nest → Rock Canyon (the King's Lair, T. rex ruler) → Horn Meadow → fork: Waterfall Ridge (behind the
//   falls, then the jump) | Old Ruins (Temple Gate) → Sprint → Return Portal
// Free roam (2026-10-14): Sky Falls + grotto, the Elder Tree, Arch Rock + the Highland Loop, the river trail + hollow log,
// the game trail across the middle, marked stash / wild spots, ambient-life paths, cliff-top safety rails (see ROAM).
// Zone-local space: origin = FV_ORIGIN, north = -Z, ground top y = 0.5.
const { Inst, Ctx, CF, shade, rng, styledText } = require('./builder.js');
const E = require('./env.js');
const { PAL } = E;
const RT = require('./route.js');
const NPC = require('./npcs.js');
const { buildEgg } = require('./eggs.js');
const B = require('./builder.js');

const FV_ORIGIN = [600, 0, -900];
const DEBUG = {}; // (analysis hooks for tools: heights, route sampling)
function marker(ctx, name, p, yaw = 0, o = {}) {
  const m = ctx.box({ name, s: o.s || [1, 1, 1], p, r: [0, yaw, 0], t: 1, shadow: false, c: '#ffffff' });
  m.set('CanQuery', 'bool', false);
  m.set('CanCollide', 'bool', false);
  return m;
}
const GROUND = 0.5, ROAD = 0.62;

const DEF = {
  start: 'Arrival',
  nodes: { Arrival: { tangent: [0, 0, -1] }, ForkA: {}, MergeA: {}, ForkB: {}, MergeB: {}, Exit: {} },
  segments: {
    FernRoad: { from: 'Arrival', to: 'ForkA', width: 26, name: 'FERN ROAD', pts: [[-300, 0, 330], [-300, 1.5, 250], [-288, 8, 180], [-245, 3, 120], [-178, 0, 86]] },
    RiverBend: { from: 'ForkA', to: 'MergeA', width: 24, name: 'RIVER BEND', pts: [[-178, 0, 86], [-218, 0, 40], [-232, 0, -20], [-198, 0, -82], [-120, 0, -114]] },
    FernTunnel: { from: 'ForkA', to: 'MergeA', width: 20, name: 'FERN TUNNEL', pts: [[-178, 0, 86], [-122, 0, 58], [-94, 0, 2], [-112, 0, -62], [-120, 0, -114]] },
    Wilds: {
      from: 'MergeA', to: 'ForkB', width: 26, name: 'RAPTOR NEST',
      pts: [[-120, 0, -114], [-62, 0, -142], [0, 0, -152], [62, 0, -180], [132, 0, -200], [192, 0, -172], [230, 0, -112], [252, 0, -40], [242, 0, 30], [206, 0, 84]],
    },
    WaterfallRidge: { from: 'ForkB', to: 'MergeB', width: 22, name: 'WATERFALL RIDGE', pts: [[206, 0, 84], [240, 4, 140], [244, 14, 196], [212, 17, 236], [168, 6, 258], [118, 0, 266]] },
    OldRuins: { from: 'ForkB', to: 'MergeB', width: 22, name: 'OLD RUINS', pts: [[206, 0, 84], [160, 0, 122], [126, 0, 172], [110, 0, 222], [118, 0, 266]] },
    Sprint: { from: 'MergeB', to: 'Exit', width: 26, name: 'SPRINT', pts: [[118, 0, 266], [60, 0, 290], [0, 2, 300], [-70, 7, 298], [-140, 0, 284]] },
  },
};

// Where things are, by segment + metres along it (+ lateral x: +right of travel)
const SECTIONS = [
  ['FernRoad', 0, 'FERN ROAD'], ['RiverBend', 0, 'RIVER BEND'], ['FernTunnel', 0, 'FERN TUNNEL'],
  ['Wilds', 0, 'RAPTOR WILDS'], ['Wilds', 125, 'ROCK CANYON'], ['Wilds', 395, 'HORN MEADOW'],
  ['WaterfallRidge', 0, 'WATERFALL RIDGE'], ['OldRuins', 0, 'OLD RUINS'], ['Sprint', 0, 'SPRINT'],
];
const NESTS = [
  { id: 1, species: 'Velociraptor', seg: 'Wilds', s: 70, x: -24, guard: 'Pack', label: 'RAPTOR NEST' },
  { id: 2, species: 'Triceratops', seg: 'Wilds', s: 470, x: 27, guard: 'Charge', label: 'HORN NEST' },
  { id: 3, species: 'Parasaurolophus', seg: 'RiverBend', s: 150, x: 25, guard: 'Stampede', label: 'CREST LAGOON' },
];
// gameplay features (all per player): pickups, obstacles, hazards
const FEATURES = [
  // tranq darts refills, placed ahead of every danger
  ['Darts', 'FernRoad', 215, -6], ['Darts', 'Wilds', 105, 7], ['Darts', 'Wilds', 345, 0], ['Darts', 'WaterfallRidge', 70, 0], ['Darts', 'OldRuins', 30, 0], ['Darts', 'Sprint', 85, -6],
  // fern road: teach boost + repairs + coins
  ['Boost', 'FernRoad', 70, 0], ['Coin', 'FernRoad', 95, -6], ['Coin', 'FernRoad', 101, -6], ['Coin', 'FernRoad', 107, -6],
  ['Log', 'FernRoad', 150, 5, { w: 12 }], ['Boost', 'FernRoad', 175, -7], ['Coin', 'FernRoad', 200, 7], ['Coin', 'FernRoad', 206, 7], ['Repair', 'FernRoad', 240, 8],
  // river bend: splash crossing with floating logs, coins on the wet line
  ['Splash', 'RiverBend', 110, 0, { len: 24 }], ['Log', 'RiverBend', 104, -4, { w: 10 }], ['Log', 'RiverBend', 124, 5, { w: 9 }],
  ['Coin', 'RiverBend', 60, 7], ['Coin', 'RiverBend', 66, 7], ['Coin', 'RiverBend', 114, 0], ['Coin', 'RiverBend', 172, -6], ['Repair', 'RiverBend', 200, 0],
  // fern tunnel: low branches from alternating sides, boost reward
  ['Branch', 'FernTunnel', 64, -4, { w: 11 }], ['Branch', 'FernTunnel', 109, 4, { w: 11 }], ['Branch', 'FernTunnel', 154, -4, { w: 11 }],
  ['Boost', 'FernTunnel', 125, -5], ['Coin', 'FernTunnel', 80, 5], ['Coin', 'FernTunnel', 86, 5], ['Coin', 'FernTunnel', 175, 0],
  // canyon: boulders while the pack is on you
  ['Boulder', 'Wilds', 170, 5, { w: 7 }], ['Boulder', 'Wilds', 215, -6, { w: 7 }], ['Boost', 'Wilds', 240, 0], ['Boulder', 'Wilds', 270, 3, { w: 8 }],
  ['Repair', 'Wilds', 300, -8], ['Boulder', 'Wilds', 330, -4, { w: 7 }], ['Coin', 'Wilds', 190, -8], ['Coin', 'Wilds', 285, 9],
  // meadow
  ['Charge', 'Wilds', 520, 0, { len: 60 }], ['Boost', 'Wilds', 430, 6], ['Coin', 'Wilds', 455, -8], ['Coin', 'Wilds', 461, -8], ['Repair', 'Wilds', 560, -6],
  // waterfall ridge: the jump
  ['Jump', 'WaterfallRidge', 152, 0, { len: 34 }], ['Boost', 'WaterfallRidge', 110, 0], ['Coin', 'WaterfallRidge', 166, 0], ['Coin', 'WaterfallRidge', 172, 0], ['Coin', 'WaterfallRidge', 178, 0],
  // old ruins: pillars make narrow gaps
  ['Pillar', 'OldRuins', 50, -6, { w: 6 }], ['Pillar', 'OldRuins', 50, 6, { w: 6 }], ['Pillar', 'OldRuins', 95, 0, { w: 7 }], ['Pillar', 'OldRuins', 140, -5, { w: 6 }],
  ['Pillar', 'OldRuins', 140, 6, { w: 5 }], ['Repair', 'OldRuins', 118, 0], ['Coin', 'OldRuins', 70, 0], ['Coin', 'OldRuins', 76, 0], ['Coin', 'OldRuins', 160, -8],
  // sprint
  ['Stampede', 'Sprint', 110, 0, { len: 50 }], ['Boost', 'Sprint', 140, 0], ['Coin', 'Sprint', 180, 6], ['Coin', 'Sprint', 186, 6],
];
// ambient life paths (EraLife.luau): [x, z] waypoints, snapped to the ground at build time (filled in below)
const LIFE = {
  paths: [
    // the migration: a Parasaurolophus family walks the game trail from Crest Lagoon to Horn Meadow and back
    { species: 'Parasaurolophus', count: 4, speed: 5.5, pts: [[-146, 26], [-104, 40], [-56, 66], [0, 80], [60, 84], [116, 74], [168, 60], [222, 56], [262, 62]] },
    // a Triceratops mother and calf grazing a slow loop round Horn Meadow's flats (clear of the nest and the arena)
    { species: 'Triceratops', count: 2, speed: 4, loop: true, pts: [[278, 12], [306, 0], [330, -24], [316, -52], [284, -48], [272, -20]] },
    // three Parasaurolophus wading up and down the river below Sky Falls (just off the river trail's side)
    { species: 'Parasaurolophus', count: 3, speed: 4.5, pts: [[-403, -199], [-379, -169], [-353, -138], [-334, -112], [-312, -85]] },
  ],
};
// is (x, z) within r of any herd walk? (zone-local)
function nearLife(x, z, r) {
  for (const path of LIFE.paths) {
    const pts = path.loop ? [...path.pts, path.pts[0]] : path.pts;
    for (let i = 0; i + 1 < pts.length; i++) {
      const [ax, az] = pts[i], [bx, bz] = pts[i + 1];
      const dx = bx - ax, dz = bz - az;
      const t = Math.max(0, Math.min(1, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)));
      if (Math.hypot(x - ax - dx * t, z - az - dz * t) < r) return true;
    }
  }
  return false;
}
const OBSTACLE_TYPES = new Set(['Log', 'Branch', 'Boulder', 'Pillar']);
// 2026-10-11: no more logs / boulders / pillars on the road (they blocked the rover on travel drives); the
// entries above stay for reference but are dropped here, so neither the map nor the route data has them
for (let i = FEATURES.length - 1; i >= 0; i--) if (OBSTACLE_TYPES.has(FEATURES[i][0])) FEATURES.splice(i, 1);
// the Tyrant King's lair (off Rock Canyon) and the final-stand arena in Horn Meadow
const DEN = { seg: 'Wilds', s: 260, x: -54 };
const FINAL = { seg: 'Wilds', s: 430, x: -62 };

// ------------------------------------------------------------------ FREE ROAM (2026-10-14)
// The valley used to be a road with scenery; now you can drive anywhere and hop out anywhere, so the off-road has to
// be worth it. Landmarks you can steer by, hidden spots worth the climb (egg stashes + wild dinos, WildLife.luau),
// off-road trails up onto the high ground, and ambient life (EraLife.luau walks the LifePath markers).
//   SKY FALLS      the river's source: a tall fall off the west cliffs, a hidden grotto behind the curtain
//   ELDER TREE     a colossal tree on the south hill; a switchback trail up from the Sprint, fungus steps to a lookout
//   ARCH ROCK      a stone arch over the Highland Loop, a trail up from Horn Meadow's south flats into the east hills
//   HOLLOW LOG     a giant hollow trunk on the river trail you can drive straight through
// Trails are road-like (smooth tilted slabs, slopes <= ~15 deg) and the hills are shaped around them like roads.
// Trail points are [x, y, z] with y = the hill height under the surface (surface = ROAD + y, like the road).
const ROAM = {
  trails: [
    // Sprint -> round the south hill, climbing anticlockwise -> the Elder Tree's plateau
    { id: 'ElderTrail', w: 14, pts: [[23, 1.3, 287], [36, 7, 252], [32, 14, 220], [14, 21, 190], [-14, 28, 174], [-44, 33.5, 184], [-46, 37.9, 206]] },
    // Horn Meadow's south flats -> up the east side under Arch Rock -> the lookout -> down the west side
    // (the climb hugs the foot of the east wall, the way down keeps 35+ clear of Waterfall Ridge's road)
    { id: 'HighlandLoop', w: 14, pts: [[318, 0, 30], [348, 2.5, 54], [362, 8, 86], [362, 15, 118], [354, 22, 146], [342, 27, 170], [330, 29.9, 188], [318, 29.9, 200], [302, 29.9, 204], [288, 25, 186], [282, 18, 160], [286, 10.5, 132], [294, 3.5, 106], [300, 0, 84]] },
  ],
  // flat tops (x, z, r, h): the Elder Tree's plateau, the Arch Rock lookout
  plateaus: [[-30, 208, 19, 37.9], [314, 196, 16, 29.9]],
  // extra flattened ground (x, z, r): Sky Falls' plunge pool flats
  clearings: [[-392, -214, 30], [-358, -110, 24]], // (+ the hollow log's bank)
  // THE GAME TRAIL: the herds' old way between Crest Lagoon and Horn Meadow, worn into a shallow valley right
  // across the middle (flat: the Parasaurolophus herd walks it, and it's the flat-out shortcut for a rover)
  gameTrail: [[-146, 26], [-104, 40], [-56, 66], [0, 80], [60, 84], [116, 74], [168, 60], [222, 56], [262, 62]],
  elder: [-24, 210],
  falls: { z0: -243, z1: -195, z: -219 }, // the gap in the west cliffs for the grotto (z range) + the falls' centre
};

function buildFernValley() {
  const route = RT.buildRoute(DEF);
  const root = new Inst('Model', 'FernValley');
  root.attr('Zone', 'FernValley');
  const Z = new Ctx({ parent: root, frame: new CF(...FV_ORIGIN), defaults: { anchored: true } });
  const R = rng(31337);
  const segs = route.segs;
  for (const s of Object.values(segs)) s.cum = RT.cumOf(s.samples);
  const at = (segId, s, x = 0, y = 0) => { const sg = segs[segId]; return RT.at(sg.samples, sg.cum, s, x, y); };

  // ------------------------------------------------ off-road trails (sampled like roads; the hills shape around them)
  for (const t of ROAM.trails) {
    t.samples = RT.buildRoute({ start: 'A', nodes: { A: {}, B: {} }, segments: { T: { from: 'A', to: 'B', width: t.w, pts: t.pts } } }).segs.T.samples;
    t.cum = RT.cumOf(t.samples);
    for (const p of t.samples) p[1] = Math.max(0, p[1]);
    // an end that meets a road meets it flush (a hair under, so the two never z-fight), faded in over 20 studs
    for (const end of [0, t.samples.length - 1]) {
      const q = t.samples[end];
      let best = null;
      for (const sg of Object.values(segs)) for (const p of sg.samples) { const d = Math.hypot(p[0] - q[0], p[2] - q[2]) - sg.width / 2; if (d < 3 && (!best || d < best.d)) best = { d, y: p[1] }; }
      if (!best) continue;
      const off = best.y - 0.04 - q[1], L = t.cum[t.cum.length - 1];
      t.samples.forEach((p, i) => { const s = end === 0 ? t.cum[i] : L - t.cum[i]; if (s < 20) p[1] += off * (1 - s / 20); });
    }
  }

  // keep-out grid of every road sample (trees/rocks never land on a road)
  const roadPts = [];
  for (const s of Object.values(segs)) for (const p of s.samples) roadPts.push([p[0], p[2], s.width / 2]);
  for (const t of ROAM.trails) for (const p of t.samples) roadPts.push([p[0], p[2], t.w / 2]); // (trees stay off the trails)
  const nearRoad = (x, z, pad) => roadPts.some(([px, pz, hw]) => Math.hypot(x - px, z - pz) < hw + pad);
  const jumpRanges = {};
  for (const f of FEATURES) if (f[0] === 'Jump') (jumpRanges[f[1]] = jumpRanges[f[1]] || []).push([f[2] - f[4].len / 2, f[2] + f[4].len / 2]);
  // the road never dips under the valley floor (spline overshoot)
  for (const sg of Object.values(segs)) for (const p of sg.samples) p[1] = Math.max(0, p[1]);
  // jump arcs: lift the samples inside a gap into a parabola so the vehicle flies across
  for (const [segId, ranges] of Object.entries(jumpRanges)) {
    const sg = segs[segId];
    sg.samples.forEach((p, i) => {
      for (const [a, b] of ranges) if (sg.cum[i] > a && sg.cum[i] < b) { const t = (sg.cum[i] - a) / (b - a); p[1] += Math.sin(t * Math.PI) * 7; }
    });
  }

  // ------------------------------------------------ ground
  const G = Z.group('Ground', 'Folder');
  G.box({ name: 'Grass', s: [900, 4, 820], p: [0, GROUND - 2, 10], c: '#62a83f', studs: 'top', collide: true });
  // soft colour variation patches (meadow lighter, wilds darker)
  for (let k = 0; k < 40; k++) {
    const x = (R() - 0.5) * 760, z = (R() - 0.5) * 700;
    G.box({ name: 'GrassPatch', s: [30 + R() * 50, 0.06, 30 + R() * 50], p: [x, GROUND + 0.03, z], r: [0, R() * 90, 0], c: R() > 0.5 ? '#66ae43' : '#5ea23d', shadow: false });
  }

  // ------------------------------------------------ hills: the valley rises on both sides of the road
  const T = buildHills(Z, segs, at, R);
  const hAt = T.hAt;
  Object.assign(DEBUG, { hAt, segs, at, T });

  // ------------------------------------------------ roads
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
      const tone = tile++ % 2 ? PAL.dirt : shade(PAL.dirt, 0.96);
      const ya = ROAD + a[1], yb = ROAD + b[1];
      roads.beam([a[0], ya - 0.3, a[2]], [b[0], yb - 0.3, b[2]], W, 0.6, { name: 'Road', c: tone, m: 'Sand', collide: true, extend: 0.2 });
      const flatHere = Math.abs(yb - ya) < 0.02 && Math.abs(ROAD + sg.samples[Math.max(0, i0 - 3)][1] - ya) < 0.02;
      if (flatHere && i0 > 0) roads.cyl({ name: 'RoadJoint', axis: 'y', len: 0.6, d: W, p: [a[0], ya - 0.33, a[2]], c: PAL.dirt, m: 'Sand', collide: true });
      // tyre ruts
      const fa = RT.frameAt(sg.samples, i0), fb = RT.frameAt(sg.samples, j);
      if (tile % 2 === 0) for (const rx of [-W * 0.18, W * 0.18]) roads.beam([a[0] + fa.r[0] * rx, ya + 0.02, a[2] + fa.r[2] * rx], [b[0] + fb.r[0] * rx, yb + 0.02, b[2] + fb.r[2] * rx], 1.2, 0.04, { name: 'Rut', c: PAL.dirtLo, m: 'Sand', shadow: false });
    }
    // edges: stones and logs alternating, ferns behind
    for (let s = 4; s < sg.cum[n - 1] - 4; s += 9) {
      if (inGap(s)) continue;
      if ((sg.id === 'FernRoad' && s < 16) || (sg.id === 'Sprint' && s > sg.cum[n - 1] - 22) || sg.id === 'OldRuins') continue; // portals + ruin columns own these edges
      if (sg.id === 'WaterfallRidge' && s > 76 && s < 116) continue; // the falls curtain owns these
      for (const side of [-1, 1]) {
        // (2026-10-12: verge props sit past the rover's reach - it steers to hw - 2.6 and is ~4 wide, so at +0.6 it drove through them)
        const f = at(sg.id, s, side * (W / 2 + 3.2));
        const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
        const k = Math.floor(s / 9) % 3;
        // (a trail leaves the road here: no verge prop across its mouth - the stone's two draws still happen, so
        // everything built after keeps its randomness)
        if (ROAM.trails.some((t) => t.samples.some((p) => Math.hypot(p[0] - f.p[0], p[2] - f.p[2]) < t.w / 2 + 2))) { if (k === 0) { R(); R(); } continue; }
        if (k === 0) roads.at([f.p[0], ROAD + f.base[1], f.p[2]], [0, yaw, 0]).box({ name: 'EdgeStone', s: [1.6, 0.9, 2.6], p: [0, 0.2, 0], r: [0, 0, R() * 8], c: PAL.rock[Math.floor(R() * 4)], m: 'Slate' });
        else if (k === 1) roads.at([f.p[0], ROAD + f.base[1], f.p[2]], [0, yaw, 0]).box({ name: 'EdgeLog', s: [1.0, 0.9, 5.5], p: [0, 0.25, 0], c: PAL.woodLo, studs: 'top' });
      }
    }
  }

  // ------------------------------------------------ boundary cliffs + backdrop mountains
  const BX = 420, BZ0 = -300, BZ1 = 400;
  // (2026-10-14: the west wall breaks for Sky Falls' grotto; buildSkyFalls closes the gap with its own rock)
  E.cliffWall(Z, [[-BX, BZ0], [BX, BZ0], [BX, BZ1], [-BX, BZ1], [-BX, ROAM.falls.z1]], { h: 58, d: 26, seed: 404, slope: 6, name: 'ValleyCliffs', chunk: 16, trees: true });
  E.cliffWall(Z, [[-BX, ROAM.falls.z0], [-BX, BZ0]], { h: 58, d: 26, seed: 406, slope: 6, name: 'ValleyCliffs', chunk: 16, trees: true });
  const M = Z.group('Mountains');
  for (let k = 0; k < 9; k++) {
    const x = -480 + k * 120 + (R() - 0.5) * 40, z = -420 - R() * 60;
    const h = 120 + R() * 90;
    for (let t = 0; t < 5; t++) M.box({ name: 'MountainTier', s: [150 - t * 26, h / 5 + 1, 110 - t * 18], p: [x, (t + 0.5) * (h / 5), z], r: [0, (R() - 0.5) * 20, 0], c: t >= 3 ? '#e8eef2' : shade('#6f7f86', 0.9 + t * 0.05), m: 'Slate' });
  }
  // a smoking volcano far behind the east cliffs (hint of Ash Canyon)
  const V = Z.at([560, 0, 120]);
  for (let t = 0; t < 6; t++) V.box({ name: 'Volcano', s: [220 - t * 34, 32, 220 - t * 34], p: [0, 16 + t * 30, 0], r: [0, t * 11, 0], c: t > 3 ? '#4a3a36' : '#5d4a42', m: 'Slate' });
  const crater = V.box({ name: 'Crater', s: [30, 4, 30], p: [0, 182, 0], c: '#ff5a1a', m: 'Neon' });
  E.particles(crater, 'Smoke', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 6, life: [8, 12], speed: [8, 14], dir: 1, spread: [15, 15], size: [[0, 20], [1, 60]], transp: [[0, 0.3], [1, 1]], color: [0.35, 0.32, 0.32], emission: 0 });

  // ------------------------------------------------ set pieces
  buildArrival(Z, at);
  buildRiver(Z, segs, at, R);
  buildTunnel(Z, segs, at, R);
  buildCanyon(Z, segs, at, R);
  buildMeadow(Z, segs, at, R);
  buildRidge(Z, segs, at, R, jumpRanges.WaterfallRidge || []);
  buildRuins(Z, segs, at, R);
  for (const n of NESTS) buildNestSite(Z, n, at, R);
  buildReturnPortal(Z, at);
  buildRexLair(Z, at, R, route);
  buildLandmarks(Z, segs, at, R);
  buildCinematics(Z, at);
  buildRangerCamp(Z, at);
  // free roam (2026-10-14): trails, landmarks, hidden spots, ambient-life paths, the safety rails
  const roamKeep = buildRoam(Z, roads, segs, at, R, T, route);

  // ------------------------------------------------ obstacles (shared visuals)
  const OB = Z.group('Obstacles', 'Folder');
  FEATURES.forEach((f, idx) => {
    const [type, seg, s, x, o = {}] = f;
    if (!OBSTACLE_TYPES.has(type)) return;
    const fr = at(seg, s, x);
    const yaw = E.deg(Math.atan2(-fr.f[0], -fr.f[2]));
    const c = OB.at([fr.p[0], ROAD + fr.base[1], fr.p[2]], [0, yaw, 0]);
    const g = c.group(type + idx);
    if (type === 'Log') {
      g.cyl({ name: 'Log', axis: 'x', len: o.w || 10, d: 2.2, p: [0, 1.1, 0], r: [0, (R() - 0.5) * 16, 0], c: PAL.wood });
      g.cyl({ name: 'LogEnd', axis: 'x', len: (o.w || 10) + 0.1, d: 1.6, p: [0, 1.1, 0], r: [0, 0, 0], c: '#d9a86a' });
      g.box({ name: 'Moss', s: [(o.w || 10) * 0.6, 0.3, 1.2], p: [0.5, 2.2, 0], c: PAL.moss, studs: 'top' });
    } else if (type === 'Boulder') {
      E.rock(g, [0, 0, 0], (o.w || 7) / 3, 7000 + idx, { colors: ['#8a7a68', '#7a6a58', '#9a8a76', '#6e6050'] });
    } else if (type === 'Branch') {
      // a low bough hanging from a roadside tree; duck it by steering away
      const side = Math.sign(x) || 1;
      g.beam([side * 9, 7.5, 0], [side * 9 - side * (o.w || 11), 2.6, 0], 1.4, 1.4, { name: 'LowBranch', c: PAL.trunk[0] });
      for (let k = 0; k < 4; k++) g.box({ name: 'BranchLeaves', s: [3, 1.8, 3], p: [side * 9 - side * (o.w || 11) * (0.3 + k * 0.22), 3.2 - k * 0.3, (R() - 0.5) * 2], r: [0, R() * 90, 0], c: PAL.leaf[k % 4], studs: 'top' });
    } else if (type === 'Pillar') {
      const w = o.w || 6;
      for (let k = 0; k < 4; k++) g.box({ name: 'RuinPillar', s: [w * (0.62 - k * 0.04), 3.2, w * (0.62 - k * 0.04)], p: [0, 1.6 + k * 3.2, 0], r: [0, k * 7 + R() * 6, R() * 3], c: k % 2 ? '#b8ad94' : '#a89c82', m: 'Slate', studs: 'top' });
      g.box({ name: 'PillarCap', s: [w * 0.85, 1.2, w * 0.85], p: [0, 13.4, 0], c: '#c8bea6', m: 'Slate', studs: 'top' });
      g.box({ name: 'Vines', s: [0.3, 8, 0.3], p: [w * 0.32, 8, 0], c: '#3a7a2a', shadow: false });
    }
  });

  // ------------------------------------------------ vegetation everywhere off-road
  const V2 = Z.group('Jungle');
  const placed = [];
  // fight areas stay clear: the den, the final arena, every nest clearing
  const keepOut = [];
  { const d = at(DEN.seg, DEN.s, DEN.x); keepOut.push([d.p[0], d.p[2], 44]); }
  { const f = at(FINAL.seg, FINAL.s, FINAL.x); keepOut.push([f.p[0], f.p[2], 36]); }
  for (const n of NESTS) { const f = at(n.seg, n.s, n.x); keepOut.push([f.p[0], f.p[2], 26]); }
  for (const k of roamKeep) keepOut.push(k);
  // the herds' walks (EraLife): nothing planted on them, so the Triceratops loop doesn't wade through trunks (2026-10-14)
  for (const path of LIFE.paths) {
    const pts = path.loop ? [...path.pts, path.pts[0]] : path.pts;
    for (let i = 0; i + 1 < pts.length; i++) {
      const [ax, az] = pts[i], [bx, bz] = pts[i + 1];
      const n = Math.max(1, Math.ceil(Math.hypot(bx - ax, bz - az) / 6));
      for (let k = 0; k <= n; k++) keepOut.push([ax + (bx - ax) * k / n, az + (bz - az) * k / n, 9]);
    }
  }
  const tryPlace = (x, z, pad, gap) => {
    if (Math.abs(x) > BX - 20 || z < BZ0 + 20 || z > BZ1 - 20) return false;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr + pad * 0.3)) return false;
    if (nearRoad(x, z, pad)) return false;
    if (placed.some(([px, pz]) => Math.hypot(px - x, pz - z) < gap)) return false;
    placed.push([x, z]);
    return true;
  };
  const plant = makePlanter(root, Z, hAt, (x, z, pad) => !(Math.abs(x) > BX - 20 || z < BZ0 + 20 || z > BZ1 - 20)
    && !keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr + pad * 0.3) && !nearRoad(x, z, pad));
  // tree ferns: the zone's signature plant, lining the road
  for (const sg of Object.values(segs)) {
    for (let s = 6; s < sg.cum[sg.cum.length - 1]; s += 13 + R() * 9) {
      for (const side of [-1, 1]) {
        if (R() < 0.25) continue;
        const f = at(sg.id, s, side * (sg.width / 2 + 5 + R() * 9));
        if (!tryPlace(f.p[0], f.p[2], 3, 7)) continue;
        const gy = GROUND + hAt(f.p[0], f.p[2]);
        if (R() < 0.6) { const h = 6 + R() * 5, seed = 20000 + placed.length; plant('TreeFern', f.p[0], f.p[2], 3, (p) => treeFern(V2, p, h, seed)); }
        else E.fern(V2, [f.p[0], gy, f.p[2]], 1.4 + R() * 0.8, 20000 + placed.length);
      }
    }
  }
  // grass tufts + flowers dressing both road edges (breaks up the open lawn right where the camera looks)
  for (const sg of Object.values(segs)) {
    for (let s = 3; s < sg.cum[sg.cum.length - 1]; s += 7 + R() * 5) {
      for (const side of [-1, 1]) {
        const f = at(sg.id, s, side * (sg.width / 2 + 1.8 + R() * 3));
        if (nearRoad(f.p[0], f.p[2], 0.6) || f.base[1] > 0.5 || hAt(f.p[0], f.p[2]) > 0.1) continue;
        if (R() < 0.75) E.grassTufts(V2, [f.p[0], GROUND, f.p[2]], 40000 + Math.floor(s * 7) + side, { n: 3, spread: 2.4 });
        else E.flowers(V2, [f.p[0], GROUND, f.p[2]], 41000 + Math.floor(s * 7) + side, { n: 3, spread: 2 });
      }
    }
  }
  // the jungle wall: big trees framing the road just behind the verge, so the drive feels enclosed
  for (const sg of Object.values(segs)) {
    if (sg.id === 'OldRuins') continue;
    for (let s = 10; s < sg.cum[sg.cum.length - 1]; s += 15 + R() * 10) {
      for (const side of [-1, 1]) {
        const lat = sg.width / 2 + 16 + R() * 14;
        const f = at(sg.id, s, side * lat);
        if (T.open(f.p[0], f.p[2])) continue;
        if (!tryPlace(f.p[0], f.p[2], 12, 13)) continue;
        if (R() < 0.7) { const h = 20 + R() * 12, seed = 22000 + placed.length, canopy = 7 + R() * 3; plant('JungleTree', f.p[0], f.p[2], 12, (p) => E.jungleTree(V2, p, h, seed, { canopy })); }
        else { const h = 14 + R() * 8, seed = 22000 + placed.length; plant('PalmTree', f.p[0], f.p[2], 12, (p) => E.palm(V2, p, h, seed)); }
      }
    }
  }
  // deeper jungle on the hills
  for (let k = 0; k < 3400 && placed.length < 700; k++) {
    const x = (R() - 0.5) * 2 * (BX - 25), z = BZ0 + 25 + R() * (BZ1 - BZ0 - 50);
    const gy = GROUND + hAt(x, z);
    const big = R();
    if (big < 0.34) { if (tryPlace(x, z, 14, 15)) { const h = 16 + R() * 12; plant('JungleTree', x, z, 14, (p) => E.jungleTree(V2, p, h, 21000 + k)); } }
    else if (big < 0.47) { if (tryPlace(x, z, 10, 12)) { const h = 12 + R() * 7; plant('PalmTree', x, z, 10, (p) => E.palm(V2, p, h, 21000 + k)); } }
    else if (big < 0.64) { if (tryPlace(x, z, 6, 9)) { const h = 7 + R() * 5; plant('TreeFern', x, z, 6, (p) => treeFern(V2, p, h, 21000 + k)); } }
    else if (big < 0.77) { if (tryPlace(x, z, 5, 7)) { const sz = 1 + R() * 0.8, berries = R() > 0.7 ? '#ff5a7a' : undefined; plant('Bush', x, z, 5, (p) => E.bush(V2, p, sz, 21000 + k, { berries }), sz); } }
    else if (big < 0.87) { if (tryPlace(x, z, 5, 8)) E.rock(V2, [x, gy, z], 1.2 + R() * 1.6, 21000 + k); }
    else if (tryPlace(x, z, 3, 6)) E.flowers(V2, [x, gy, z], 21000 + k, { n: 6, spread: 4 });
  }
  { const st = plant.stats; console.log(`                   trees: planted ${st.planted} (nudged ${st.nudged}), dropped ${st.dropped} [clip ${st.clip}, step ${st.step}, footing/water ${st.foot}], cliff-top trees dropped ${st.preDropped || 0}`); }
  // the jungle floor: patches of moss and clover, clumps of tall grass and flowers between the trees
  // (kept off the road; they don't count toward the big-prop cap)
  const floorR = rng(91234);
  for (let k = 0, made = 0; k < 2400 && made < 320; k++) {
    const x = (floorR() - 0.5) * 2 * (BX - 25), z = BZ0 + 25 + floorR() * (BZ1 - BZ0 - 50);
    if (nearRoad(x, z, 4)) continue;
    if (keepOut.some(([kx, kz, kr]) => Math.hypot(x - kx, z - kz) < kr)) continue;
    const gy = GROUND + hAt(x, z);
    const pick = floorR();
    if (pick < 0.55) { const r = 4 + floorR() * 4; if (!plant.nearTrunk(x, z, r * 1.3)) E.groundPatch(V2, [x, gy, z], r, 52000 + k, { colors: ['#4fb043', '#6ccb4c', '#3f9a38', '#8fd65a', '#a7e06a'] }); }
    else if (pick < 0.85) E.grassTufts(V2, [x, gy, z], 53000 + k, { n: 5, spread: 3, scale: 1.4 });
    else E.flowers(V2, [x, gy, z], 54000 + k, { n: 5, spread: 3, colors: ['#ff5a7a', '#ffd23a', '#ffffff', '#7ad0ff', '#ff8a2a'] });
    made++;
  }

  // ------------------------------------------------ route data for Luau
  // keep the rover's lane clear: decor in the way is removed, anything else is reported for a fix
  {
    const lanes = [];
    for (const sg of Object.values(segs)) for (const p of sg.samples) lanes.push({ x: p[0] + FV_ORIGIN[0], z: p[2] + FV_ORIGIN[2], y: ROAD + p[1], hw: sg.width / 2 });
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

// ------------------------------------------------------------------ clip-free planting
// Every scattered tree is built, then checked against what already stands: other trees (scatter, cliff tops,
// set pieces), the Fern Tunnel arches, and any hill column higher than its footing (a canopy or trunk cutting
// into a terrace step). Its footprint (trunk + buttresses) must sit on one terrace level and off the river bank
// and the lake shore. A tree that fails is nudged - toward the middle of its terrace cell first, then a ring of
// short hops - and only dropped when no nudge works. Exact part-vs-part tests (each tree's real geometry, so
// big canopies get big spacing and bushes small), deterministic: the same seeds and order every build.
const QC = require('./qc.js');
const PLANT_UNITS = new Set(['JungleTree', 'PalmTree', 'TreeFern', 'Bush', 'TunnelArch']);
const FOOT = { JungleTree: 2.4, PalmTree: 1.2, TreeFern: 1.2, Bush: 2.2 }; // footprint radius (bush: x its size)
// (2026-10-14 free roam: the river now springs from Sky Falls at the foot of the west cliffs, not from inside them)
const RIVER_PTS = [[-416, -222], [-350, -140], [-282, -52], [-228, -12], [-196, -10]];
const LAKE = [-160, -12, 33]; // shore sand radius
function makePlanter(root, Z, hAt, spotOk) {
  const [OX, , OZ] = FV_ORIGIN;
  const CELL = 12, BX = 420, BZ0 = -300, HC = 16;
  const hash = new Map();
  const stats = { planted: 0, nudged: 0, dropped: 0, clip: 0, step: 0, foot: 0 };
  const boxesOf = (inst) => {
    const out = [];
    inst.walk((i) => {
      if (!i._preview || i._preview.t >= 1) return;
      const k = i._preview.kind;
      const O = QC.obb({ s: i._preview.size, cf: [i._cf.x, i._cf.y, i._cf.z, ...i._cf.r] });
      if (k === 'cyl' || k === 'ball' || k === 'ellipsoid') { O.h = O.h.map((v, a) => (k === 'cyl' && a === 0) ? v : v * 0.78); O.r = Math.hypot(...O.h); }
      const ext = [0, 1, 2].map((a) => O.h[0] * Math.abs(O.ax[0][a]) + O.h[1] * Math.abs(O.ax[1][a]) + O.h[2] * Math.abs(O.ax[2][a]));
      out.push({ O, min: O.c.map((v, a) => v - ext[a]), max: O.c.map((v, a) => v + ext[a]) });
    });
    return out;
  };
  const cells = (b, fn) => {
    for (let x = Math.floor(b.min[0] / HC); x <= Math.floor(b.max[0] / HC); x++)
      for (let z = Math.floor(b.min[2] / HC); z <= Math.floor(b.max[2] / HC); z++) fn(x + ',' + z);
  };
  const register = (boxes, owner) => { for (const b of boxes) cells(b, (key) => { if (!hash.has(key)) hash.set(key, []); hash.get(key).push({ b, owner }); }); };
  const overlap = (a, b) => { for (let k = 0; k < 3; k++) if (a.max[k] < b.min[k] || b.max[k] < a.min[k]) return false; return true; };
  const hitsPlant = (boxes, owner) => {
    for (const b of boxes) {
      let hit = false;
      cells(b, (key) => { if (hit) return; for (const e of hash.get(key) || []) if (e.owner !== owner && overlap(b, e.b) && QC.penetration(b.O, e.b.O) > 0.05) { hit = true; return; } });
      if (hit) return true;
    }
    return false;
  };
  // hill columns (zone-local grid, solid from the valley floor to GROUND + h) higher than the tree's footing
  const hitsStep = (boxes, footH) => {
    for (const b of boxes) {
      const x0 = b.min[0] - OX, x1 = b.max[0] - OX, z0 = b.min[2] - OZ, z1 = b.max[2] - OZ;
      for (let i = Math.floor((x0 + BX) / CELL); i <= Math.floor((x1 + BX) / CELL); i++)
        for (let j = Math.floor((z0 - BZ0) / CELL); j <= Math.floor((z1 - BZ0) / CELL); j++) {
          const cx = -BX + CELL / 2 + i * CELL, cz = BZ0 + CELL / 2 + j * CELL;
          const h = hAt(cx, cz);
          if (h <= footH + 0.25 || b.min[1] > GROUND + h) continue;
          const col = QC.obb({ s: [CELL, h, CELL], cf: [cx + OX, GROUND + h / 2, cz + OZ, 1, 0, 0, 0, 1, 0, 0, 0, 1] });
          if (QC.penetration(b.O, col) > 0.05) return true;
        }
    }
    return false;
  };
  const distSeg = (x, z, a, b) => {
    const dx = b[0] - a[0], dz = b[1] - a[1];
    const t = Math.max(0, Math.min(1, ((x - a[0]) * dx + (z - a[1]) * dz) / (dx * dx + dz * dz)));
    return Math.hypot(x - a[0] - dx * t, z - a[1] - dz * t);
  };
  const footingOk = (x, z, h, r) => {
    for (let a = 0; a < 8; a++) for (const f of [0.5, 1]) if (hAt(x + Math.cos(a * Math.PI / 4) * r * f, z + Math.sin(a * Math.PI / 4) * r * f) !== h) return false;
    if (Math.hypot(x - LAKE[0], z - LAKE[1]) < LAKE[2] + r) return false;
    for (let i = 0; i < RIVER_PTS.length - 1; i++) if (distSeg(x, z, RIVER_PTS[i], RIVER_PTS[i + 1]) < 11 + r) return false;
    return true;
  };
  const tries = (x, z) => {
    const out = [[x, z]];
    const cx = -BX + CELL / 2 + Math.floor((x + BX) / CELL) * CELL, cz = BZ0 + CELL / 2 + Math.floor((z - BZ0) / CELL) * CELL;
    const d = Math.hypot(cx - x, cz - z);
    if (d > 0.5) for (const t of [3, 6]) { const k = Math.min(1, t / d); out.push([x + (cx - x) * k, z + (cz - z) * k]); }
    for (const r of [2.5, 5]) for (let a = 0; a < 8; a++) out.push([x + Math.cos(a * Math.PI / 4 + r) * r, z + Math.sin(a * Math.PI / 4 + r) * r]);
    return out;
  };
  // what already stands: cliff-top trees, set-piece trees and tunnel arches (a cliff-top tree cutting into one
  // registered before it is dropped), then every solid set-piece part (cliff strata, ruins, the Fallen Giant...)
  // so a tree is nudged off them rather than pruned by the map QC afterwards
  const SKIP = /^(Jungle|Ground|Hills|Roads|Mountains|Cinematics|Volcano|Crater)$/;
  const units = [], solids = [];
  const scan = (i) => {
    if (i.cls === 'Model' && PLANT_UNITS.has(i.name)) { units.push(i); return; }
    if (i._preview && i._preview.t < 1 && Math.min(...i._preview.size) >= 0.35) solids.push(i);
    for (const c of i.children) scan(c);
  };
  for (const top of root.children) if (!SKIP.test(top.name)) scan(top);
  for (const u of units) {
    const boxes = boxesOf(u);
    if (u.name !== 'TunnelArch' && hitsPlant(boxes, u)) { u.parent.children.splice(u.parent.children.indexOf(u), 1); stats.preDropped = (stats.preDropped || 0) + 1; continue; }
    register(boxes, u);
  }
  for (const s of solids) register(boxesOf(s), 'set');
  const trunks = [];
  const plant = (kind, x, z, pad, make, k = 1) => {
    const r = FOOT[kind] * k;
    let why = 'foot';
    const cand = tries(x, z);
    for (let t = 0; t < cand.length; t++) {
      const [nx, nz] = cand[t];
      if (t > 0 && !spotOk(nx, nz, pad)) continue;
      const fh = hAt(nx, nz);
      if (!footingOk(nx, nz, fh, r)) continue;
      const inst = make([nx, GROUND + fh, nz]).parent;
      const boxes = boxesOf(inst);
      const clip = hitsPlant(boxes, inst), step = !clip && hitsStep(boxes, fh);
      if (clip || step) {
        why = clip ? 'clip' : 'step';
        inst.parent.children.splice(inst.parent.children.indexOf(inst), 1);
        continue;
      }
      register(boxes, inst);
      trunks.push([nx, nz, r]);
      stats.planted++;
      if (t > 0) stats.nudged++;
      return true;
    }
    stats.dropped++;
    stats[why]++;
    return false;
  };
  plant.stats = stats;
  // floor decals laid later stay off the trunks (the map QC would otherwise prune the tree under them)
  plant.nearTrunk = (x, z, r) => trunks.some(([tx, tz, tr]) => Math.hypot(x - tx, z - tz) < r + tr);
  return plant;
}

// ------------------------------------------------------------------ hills
// A studded block heightfield: smooth noise hills that fall to road height near the road (so it runs through
// a valley of its own), flattened clearings for every set piece, and a rise toward the boundary cliffs.
// Columns that sit under the road are capped just below it (blocky embankments on the crests).
function buildHills(Z, segs, at, R) {
  const CELL = 12, STEP = 1.2;
  const BX = 420, BZ0 = -300, BZ1 = 400;
  const N = noise2(9001);
  const fbm = (x, z) => 0.6 * N(x / 110, z / 110) + 0.3 * N(x / 47 + 31, z / 47 - 17) + 0.1 * N(x / 19 - 7, z / 19 + 5);
  // road samples [x, z, halfWidth, y, blend]: the hills fall to the road's height over `blend` studs beside it.
  // (2026-10-14) the free-roam trails count as roads here too, with a tighter blend so their hillsides stay steep
  const road = [];
  for (const sg of Object.values(segs)) sg.samples.forEach((p, i) => { if (i % 2 === 0) road.push([p[0], p[2], sg.width / 2, p[1], 50]); });
  for (const t of ROAM.trails) t.samples.forEach((p, i) => { if (i % 2 === 0) road.push([p[0], p[2], t.w / 2, p[1], 30, true]); });
  const nearestRoad = (x, z) => {
    let best = Infinity, y = 0, bl = 50, tr = false;
    for (const [px, pz, hw, py, b, trail] of road) { const d = Math.hypot(x - px, z - pz) - hw; if (d < best) { best = d; y = py; bl = b; tr = !!trail; } }
    return [best, y, bl, tr];
  };
  // clearings: [x, z, radius] circles + corridors along road stretches [seg, s0, s1, lateral]
  const circles = [];
  const corridor = [];
  const addAt = (seg, s, x, r) => { const f = at(seg, s, x); circles.push([f.p[0], f.p[2], r]); };
  addAt('FernRoad', 0, 0, 52); addAt('FernRoad', 0, 26, 30); // arrival portal + forward camp
  addAt('Sprint', 1e9, 0, 40); // return portal
  for (const n of NESTS) addAt(n.seg, n.s, n.x, 32);
  addAt('OldRuins', 182, 22, 16);
  addAt(DEN.seg, DEN.s, DEN.x, 40); // the King's lair
  addAt(DEN.seg, DEN.s, -24, 18); // its mouth to the road
  addAt(FINAL.seg, FINAL.s, FINAL.x, 42); // the final stand
  circles.push([-160, -12, 56]); // lake
  for (const c of ROAM.clearings) circles.push(c);
  const river = RIVER_PTS;
  corridor.push(['Wilds', 105, 410, 44]); // rock canyon (its own walls)
  corridor.push(['Wilds', 395, 640, 96]); // horn meadow: open grazing land
  corridor.push(['OldRuins', 0, 1e9, 30]);
  corridor.push(['FernTunnel', 0, 1e9, 22]);
  corridor.push(['@game', 0, 0, 12]); // (2026-10-14) the game trail's valley
  const jump = [];
  // the ridge gorge (jump gap) stays open below
  const segRidge = segs.WaterfallRidge;
  if (segRidge) addAt('WaterfallRidge', 152, 0, 48);
  const corridorPts = corridor.map(([seg, s0, s1, lat]) => {
    if (seg === '@game') {
      const out = [], P = ROAM.gameTrail;
      // (a wide, gentle blend: the valley's sides stay climbable, so the hills either side are still reachable)
      for (let i = 0; i < P.length - 1; i++) { const L = Math.hypot(P[i + 1][0] - P[i][0], P[i + 1][1] - P[i][1]); for (let u = 0; u < L; u += 6) out.push([P[i][0] + (P[i + 1][0] - P[i][0]) * u / L, P[i][1] + (P[i + 1][1] - P[i][1]) * u / L, lat, GAME_BLEND]); }
      out.push([...P[P.length - 1], lat, GAME_BLEND]);
      return out;
    }
    const sg = segs[seg]; const L = sg.cum[sg.cum.length - 1];
    const pts = [];
    for (let s = s0; s <= Math.min(s1, L); s += 6) { const f = at(seg, s); pts.push([f.p[0], f.p[2], lat]); }
    return pts;
  });
  const distSeg = (x, z, a, b) => {
    const dx = b[0] - a[0], dz = b[1] - a[1];
    const t = Math.max(0, Math.min(1, ((x - a[0]) * dx + (z - a[1]) * dz) / (dx * dx + dz * dz || 1)));
    return Math.hypot(x - a[0] - dx * t, z - a[1] - dz * t);
  };
  const smooth = (e0, e1, v) => { const t = Math.max(0, Math.min(1, (v - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };
  // 0 = fully flattened, 1 = free to rise
  const openness = (x, z) => {
    let k = 1;
    for (const [cx, cz, r] of circles) k = Math.min(k, smooth(r, r + 26, Math.hypot(x - cx, z - cz)));
    for (const pts of corridorPts) for (const [px, pz, lat, bl] of pts) k = Math.min(k, smooth(lat, lat + (bl || 24), Math.hypot(x - px, z - pz)));
    let dr = Infinity;
    for (let i = 0; i < river.length - 1; i++) dr = Math.min(dr, distSeg(x, z, river[i], river[i + 1]));
    k = Math.min(k, smooth(22, 44, dr));
    return k;
  };
  // landmark hills: a few big authored rises so the valley has shapes you can name, not one even stair everywhere
  const BUMPS = [[-30, 205, 34, 56], [-330, 70, 24, 70], [320, 150, 26, 64], [10, -40, 14, 46], [-150, 330, 18, 56]];
  const bump = (x, z) => BUMPS.reduce((acc, [bx, bz, A, r]) => acc + A * Math.exp(-((x - bx) ** 2 + (z - bz) ** 2) / (r * r)), 0);
  // gullies: thin winding valleys cut into the high ground (ridged noise)
  const gully = (x, z) => { const v = Math.abs(N(x / 64 + 50, z / 64 - 40)); return v < 0.11 ? 1 - v / 0.11 : 0; };
  const tones = {
    low: ['#5fa63d', '#67b043', '#579c38', '#6cb548'],
    mid: ['#6aa83e', '#76b046', '#5e9c39', '#82b84c'],
    high: ['#86ae4e', '#7aa448', '#93b85a', '#8aa84c'],
  };
  const heights = new Map();
  const key = (i, j) => i + ',' + j;
  const G = Z.group('Hills', 'Folder');
  const cells = [];
  let built = 0;
  const col = []; // every column: { i, j, x, z, h, cap (road cap or Infinity), road (a road / trail runs over it) }
  for (let x0 = -BX + CELL / 2; x0 < BX; x0 += CELL) {
    for (let z0 = BZ0 + CELL / 2; z0 < BZ1; z0 += CELL) {
      const i = Math.round(x0 / CELL), j = Math.round(z0 / CELL);
      const [d, ry, bl, nearTrail] = nearestRoad(x0, z0);
      const edge = Math.min(x0 + BX, BX - x0, z0 - BZ0, BZ1 - z0);
      let H = 7 + 40 * Math.max(0, fbm(x0, z0) + 0.22) + 18 * (1 - smooth(10, 90, edge)) + bump(x0, z0);
      if (H > 16) H -= Math.min(H - 10, 16) * gully(x0, z0);
      const t = smooth(8, bl, d) * openness(x0, z0);
      let h = ry * (1 - smooth(8, bl, d)) + H * t;
      // fine steps down low (walkable banks), chunky strata up high (cliff ledges you can read from the road)
      h = h < 16 ? Math.floor(h / STEP) * STEP : 16 + Math.floor((h - 16) / 3.6) * 3.6;
      // never poke through the road: columns near it stay just under the road surface
      let cap = Infinity;
      if (d < CELL * 0.75 + 1 && !nearTrail) cap = Math.floor((ry - 0.5) / STEP) * STEP;
      // (2026-10-14) a trail sloping across a 12-stud column: under the lowest bit of it that actually crosses the
      // column, not just the nearest sample's height (the column otherwise stuck up through the trail's downhill end)
      for (const [px, pz, hw, py, , trail] of road) {
        if (!trail) continue;
        const ex = Math.max(0, Math.abs(px - x0) - CELL / 2), ez = Math.max(0, Math.abs(pz - z0) - CELL / 2);
        if (Math.hypot(ex, ez) < hw + 0.5) cap = Math.min(cap, Math.floor((py - 0.5) / STEP) * STEP);
      }
      h = Math.min(h, cap);
      // (2026-10-14) flat tops for the free-roam set pieces (the Elder Tree, the Arch Rock lookout)
      for (const [px, pz, pr, ph] of ROAM.plateaus) if (Math.hypot(x0 - px, z0 - pz) < pr) h = Math.min(ph, cap);
      col.push({ i, j, x: x0, z: z0, h: h < STEP ? 0 : h, cap, road: d < 0 || (nearTrail && cap < Infinity) });
    }
  }
  fixTraps(col, CELL);
  for (const c of col) {
    const { i, j, x: x0, z: z0, h } = c;
    {
      if (h < STEP) { heights.set(key(i, j), 0); continue; }
      heights.set(key(i, j), h);
      const top = Math.min(1.2, h);
      const band = h > 22 ? 'high' : h > 9 ? 'mid' : 'low';
      const tone = Math.floor((N(x0 / 90 - 13, z0 / 90 + 7) + 1) * 2) % 4;
      const sideC = h > 22 ? (Math.floor(h / 7.2) % 2 ? '#8a7a68' : '#7c6e5e') : h > 9 ? '#6e5034' : '#7a5a3a';
      cells.push({ i, j, x: x0, z: z0, h, top, topC: tones[band][tone], sideC, sideM: h > 22 ? 'Slate' : 'Plastic' });
      built++;
    }
  }
  const parts = E.heightfield(G, cells, CELL);
  // tors: rock outcrops crowning the high ground
  const OR = rng(5150);
  const tors = Z.group('Outcrops');
  for (const c of cells) {
    if (c.h < 24 || OR() > 0.07) continue;
    const ex = c.x + (OR() - 0.5) * CELL * 0.5, ez = c.z + (OR() - 0.5) * CELL * 0.5;
    E.rock(tors, [ex, GROUND + c.h, ez], 2.2 + OR() * 1.8, 5200 + c.i * 97 + c.j, { colors: ['#9a8e7c', '#8a7e6c', '#a89a86', '#7a6e60'] });
  }
  const cellOf = (v, lo) => Math.round((lo + CELL / 2 + Math.floor((v - lo) / CELL) * CELL) / CELL);
  const hAt = (x, z) => heights.get(key(cellOf(x, -BX), cellOf(z, BZ0))) || 0;
  console.log('                   hills: ' + built + ' columns -> ' + parts + ' parts');
  return { hAt, open: (x, z) => openness(x, z) < 0.5 };
}

// No pits (2026-10-14, free roam): a rover climbs ~4.2 per step (Drive.luau ROAM_STEP) and drops off anything, so a
// column it can fall into but never climb out of would strand it. Flood from every road / trail column: down any
// drop, up at most CLIMB. A column reached that way that can't get back the same way is raised until its lowest
// escape is one climb above it (heights only go up, so this settles); road-capped columns never rise past the road.
const CLIMB = 3.61;
const GAME_BLEND = 64; // the game trail valley's side blend (studs): gentle enough that the hills beside it stay driveable
function fixTraps(col, CELL) {
  const at = new Map();
  for (const c of col) at.set(c.i + ',' + c.j, c);
  const nb = (c) => [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([a, b]) => at.get((c.i + a) + ',' + (c.j + b))).filter(Boolean);
  const flood = (up) => {
    const seen = new Set(), q = [];
    for (const c of col) if (c.road) { seen.add(c); q.push(c); }
    while (q.length) {
      const c = q.pop();
      // forward (leaving the road): c -> n when n is at most a climb above; backward (getting home): n -> c
      for (const n of nb(c)) if (!seen.has(n) && (up ? n.h - c.h : c.h - n.h) <= CLIMB) { seen.add(n); q.push(n); }
    }
    return seen;
  };
  let raised = 0, left = 0;
  for (let it = 0; it < 60; it++) {
    const out = flood(true), home = flood(false);
    const traps = col.filter((c) => out.has(c) && !home.has(c));
    left = traps.length;
    if (!traps.length) break;
    let moved = false;
    for (const c of traps) {
      const exits = nb(c).filter((n) => home.has(n)).map((n) => n.h);
      if (!exits.length) continue;
      const want = Math.min(c.cap, Math.min(...exits) - CLIMB + 0.01);
      if (want > c.h + 0.01) { c.h = Math.ceil(want / 1.2) * 1.2; raised++; moved = true; }
    }
    if (!moved) break;
  }
  console.log(`                   pits: raised ${raised} columns, ${left} trapped left`);
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

// Giant tree fern: short shaggy trunk, a crown of long arching fronds
function treeFern(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('TreeFern');
  const t = g.at(p, [0, R() * 360, 0]);
  const n = Math.max(2, Math.round(h / 2.4));
  for (let i = 0; i < n; i++) t.box({ name: 'FernTrunk', s: [1.1, 2.5, 1.1], p: [0, 1.2 + i * 2.4, 0], r: [0, i * 30, (R() - 0.5) * 6], c: i % 2 ? '#5e4a2e' : '#6e5636', studs: 'sides', collide: i === 0 });
  const top = t.at([0, n * 2.4, 0]);
  top.box({ name: 'FernCrown', s: [1.6, 0.8, 1.6], c: '#3f7a2e' });
  const fr = 6;
  for (let i = 0; i < fr; i++) {
    const f = top.at([0, 0.2, 0], [0, (i / fr) * 360 + R() * 20, 0]);
    f.box({ name: 'Frond', s: [1.2, 0.2, 3.6], p: [0, 0.5, -1.8], r: [18, 0, 0], c: i % 2 ? '#4fb043' : '#5bbd4a', studs: 'top' });
    f.box({ name: 'FrondMid', s: [1.0, 0.18, 3.0], p: [0, 0.5, -4.8], r: [-12, 0, 0], c: '#47a63e' });
    f.box({ name: 'FrondTip', s: [0.7, 0.16, 2.4], p: [0, -0.5, -7.2], r: [-38, 0, 0], c: '#3f9a3a' });
  }
  return g;
}

// ------------------------------------------------------------------ set pieces
function hexPortal(ctx, p, yaw, R, name, o = {}) {
  const g = ctx.group(name);
  const c = g.at(p, [0, yaw, 0]);
  const cy = R * Math.sin(Math.PI / 3) - 1.8; // bottom beam flush with the ground: drive straight through
  const F = c.at([0, cy, 0]);
  const pts = Array.from({ length: 6 }, (_, k) => { const a = (k * 60 * Math.PI) / 180; return [Math.cos(a) * R, Math.sin(a) * R]; });
  for (let k = 0; k < 6; k++) {
    const [ax, ay] = pts[k], [bx, by] = pts[(k + 1) % 6];
    F.beam([ax, ay, 0], [bx, by, 0], 3.6, 3, { name: 'PortalBeam', c: '#5d5a55', m: 'Slate', studs: 'top', extend: 1, up: [0, 0, 1] });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNode', s: [4.4, 4.4, 4.8], c: '#2b2d31', m: 'Metal', studs: 'all' });
    F.at([ax, ay, 0], [0, 0, k * 60]).box({ name: 'PortalNodeCore', s: [2, 2, 5], c: o.color || '#3fe0c8', m: 'Neon' }).tag('GateNode');
  }
  const rm = R - 2.2, apo = rm * Math.sin(Math.PI / 3);
  for (let k = 0; k < 3; k++) F.box({ name: 'Membrane', s: [rm, 2 * apo, 0.3], r: [0, 0, k * 60], c: o.color || '#2fb8b0', m: 'Neon', t: 0.42, shadow: false }).tag('PortalSurface');
  for (let k = 0; k < 3; k++) F.box({ name: 'Core', s: [rm * 0.5, 2 * apo * 0.5, 0.35], r: [0, 0, k * 60], c: '#ffd27a', m: 'Neon', t: 0.35, shadow: false }).tag('PortalCore');
  const host = F.box({ name: 'PortalLightHost', s: [1, 1, 1], t: 1, shadow: false });
  E.pointLight(host, [0.35, 0.95, 0.85], 46, 2);
  E.particles(host, 'Swirl', { rate: 30, life: [0.8, 1.6], speed: [5, 12], spread: [80, 80], dir: 5, size: [[0, 0.6], [1, 0]], color: [[0, [1, 0.85, 0.45]], [1, [0.25, 0.9, 0.8]]], emission: 1 });
  // base plinths either side
  for (const side of [-1, 1]) c.box({ name: 'Plinth', s: [6, 3, 7], p: [side * (R + 6), 1.5, 0], c: '#7a746a', m: 'Slate', studs: 'top', collide: true });
  return g;
}

function buildArrival(Z, at) {
  const f = at('FernRoad', 0);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  hexPortal(Z, [f.p[0], GROUND, f.p[2] + 6], yaw, 14, 'ArrivalPortal');
  // research team's forward camp beside the arrival
  const c = Z.at([f.p[0] + 26, GROUND, f.p[2] - 20], [0, 20, 0]);
  c.box({ name: 'TentFloor', s: [10, 0.3, 8], p: [0, 0.15, 0], c: '#8a5a33' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, -2], face: 'front', c: '#d9b95a' });
  c.wedgeF({ name: 'Tent', s: [10, 5, 4], p: [0, 2.8, 2], face: 'back', c: '#cfae4f' });
  E.crate(c, [6.5, 0.3, 1], 1, { yaw: 14, stencil: '#2f6b3a' });
  E.barrel(c, [6.5, 0.3, -2.5], { color: '#2f6b3a' });
  E.signBoard(c, [-7, 4, -3], 7, 2, 'FERN VALLEY', { r: [0, -30, 0], color: '#eaffd8', color2: '#5fd35a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [-7, 2, -2.7], c: PAL.woodLo });
  E.lampPost(c, [-4, 0.3, 4], { h: 6 });
}

// THE KING'S LAIR — the Tyrant King's (T. rex) den: a dark mud bowl carved into the canyon wall under a giant fallen
// tree, snapped trunks all around, a bone pit of Triceratops skulls, a claw-scarred rock face behind his mound
// (named Throne so every ruler camera finds it), mist on the floor and footprints from the mouth. Markers drive the fight.
function buildRexLair(Z, at, R, route) {
  const g = Z.group('KingsLair');
  const f = at(DEN.seg, DEN.s, DEN.x);
  const toRoad = Math.atan2(-(at(DEN.seg, DEN.s, 0).p[0] - f.p[0]), -(at(DEN.seg, DEN.s, 0).p[2] - f.p[2]));
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, E.deg(toRoad), 0]); // local -Z points at the road
  const cols = ['#6e5a44', '#5e4c3a', '#7a6650', '#544434'];
  const bone = '#efe2c4', boneLo = '#e3d4b0';
  c.cyl({ name: 'LairFloor', axis: 'y', len: 0.2, d: 76, p: [0, 0.1, 0], c: '#5e4a36', m: 'Sand' });
  for (let k = 0; k < 14; k++) c.box({ name: 'Trample', s: [6 + R() * 7, 0.05, 2 + R() * 2], p: [(R() - 0.5) * 52, 0.22, (R() - 0.5) * 52], r: [0, R() * 180, 0], c: '#4e3c2c', shadow: false });
  for (let k = 0; k < 4; k++) c.cyl({ name: 'MudPuddle', axis: 'y', len: 0.08, d: 4 + R() * 4, p: [(R() - 0.5) * 40, 0.24, (R() - 0.5) * 30 - 6], c: '#3e3226', m: 'Glass', t: 0.1, shadow: false });
  // the bowl wall: a dark mossy cliff ring with the mouth open toward the road
  const ring = [];
  for (let a = 40; a <= 320; a += 20) { const rad = (a * Math.PI) / 180; ring.push(c.wpt([Math.sin(rad) * 40, 0, -Math.cos(rad) * 40])); }
  E.cliffWall(Z, ring.map((p) => [p[0] - FV_ORIGIN[0], p[2] - FV_ORIGIN[2]]), { h: 32, d: 14, seed: 611, slope: 3, colors: cols, chunk: 10, name: 'LairWall', trees: true });
  // ledges against the wall (rock stacks)
  const ledgeAt = [[-25, 16, 11], [25, 16, 9], [-31, -6, 13], [31, -4, 10]];
  ledgeAt.forEach(([x, z, h], i) => {
    const lc = c.at([x, 0, z]);
    for (let t = 0; t < 4; t++) lc.box({ name: 'LedgeRock', s: [7 - t * 0.6, h / 4 + 0.2, 7 - t * 0.6], p: [0, (t + 0.5) * (h / 4), 0], r: [0, t * 17 + R() * 10, 0], c: cols[t % 4], m: 'Slate', studs: 'top', collide: true });
    lc.box({ name: 'LedgeTop', s: [5, 0.6, 5], p: [0, h + 0.3, 0], c: PAL.moss, m: 'Slate', studs: 'top', collide: true });
    marker(lc, 'DenLedge' + (i + 1), [0, h + 0.6, 0], 0, { s: [2, 0.4, 2] });
  });
  // his mound: packed earth and roots, flat on top, against a claw-scarred rock face
  const th = c.at([0, 0, 24]);
  th.box({ name: 'Throne', s: [16, 4.4, 12], p: [0, 2.2, 0], c: '#5a4632', m: 'Slate', studs: 'top', collide: true });
  th.box({ name: 'ThroneStep', s: [20, 1.6, 15], p: [0, 0.8, 0.8], c: '#4e3c2c', m: 'Slate', collide: true });
  for (let k = 0; k < 6; k++) th.beam([-9 + k * 3.6, 0.6, -6.4], [-8 + k * 3.4 + (R() - 0.5) * 3, 3.6, -3], 0.9, 0.9, { name: 'Root', c: PAL.root, extend: 0.6 });
  const face = c.at([0, 0, 33]);
  face.box({ name: 'ScarFace', s: [22, 20, 5], p: [0, 10, 0], r: [-6, 0, 0], c: '#6a5a48', m: 'Slate', studs: 'top', collide: true });
  face.box({ name: 'ScarFaceTop', s: [18, 6, 6], p: [-1, 22, 1], r: [-4, 8, 0], c: '#5e4c3a', m: 'Slate', studs: 'top' });
  for (const [x, y] of [[-5, 12], [4, 9]]) for (let j = 0; j < 4; j++) face.box({ name: 'ClawGash', s: [0.7, 9, 0.5], p: [x - 2.4 + j * 1.6, y, -2.8], r: [-6, 0, 24], c: '#2e2218' });
  // the giant fallen tree that roofs the lair: a huge trunk from one rim to the other, roots torn up on the left
  const ft = c.at([0, 0, 6]);
  ft.beam([-46, 30, 14], [44, 24, -6], 6.4, 6.4, { name: 'FallenGiantTrunk', c: PAL.trunk[0], studs: 'sides' });
  ft.beam([-46, 30.6, 14], [44, 24.6, -6], 5.6, 7, { name: 'FallenGiantBark', c: PAL.trunk[1] });
  for (let k = 0; k < 7; k++) { const a = (k / 7) * Math.PI * 2; ft.beam([-48, 30, 14], [-50 + Math.cos(a) * 2, 30 + Math.sin(a) * 9, 14 + Math.cos(a) * 9], 1.6, 1.6, { name: 'TornRoot', c: PAL.root, extend: 1 }); }
  for (let k = 0; k < 6; k++) { const u = 0.15 + k * 0.13; ft.box({ name: 'MossClump', s: [3.4, 1.2, 3], p: [-46 + 90 * u, 30 - 6 * u + 3.4, 14 - 20 * u], c: PAL.moss, studs: 'top' }); }
  for (let k = 0; k < 8; k++) { const u = 0.1 + k * 0.11; const vl = 4 + R() * 9; ft.box({ name: 'Vine', s: [0.3, vl, 0.3], p: [-46 + 90 * u, 30 - 6 * u - 3 - vl / 2, 14 - 20 * u], c: '#3a7a2a', shadow: false }); }
  // snapped trunks: jagged stumps around the bowl
  for (let k = 0; k < 6; k++) {
    const a = 0.9 + (k / 5) * (Math.PI * 2 - 1.8);
    const r = 30 + R() * 4;
    const st = c.at([Math.sin(a) * r, 0, -Math.cos(a) * r], [0, R() * 360, 0]);
    const h = 5 + R() * 6;
    st.box({ name: 'SnappedTrunk', s: [3, h, 3], p: [0, h / 2, 0], c: PAL.trunk[k % 2], studs: 'sides', collide: true });
    for (let j = 0; j < 3; j++) st.wedgeF({ name: 'Splinter', s: [1, 2.4 + R() * 2, 1.2], p: [-1 + j, h + 1, (R() - 0.5)], face: j % 2 ? 'front' : 'back', c: '#c8a070' });
    st.beam([0, h - 1, 0], [6 + R() * 4, 0.8, (R() - 0.5) * 6], 2.2, 2.2, { name: 'FallenTop', c: PAL.trunk[(k + 1) % 2] });
  }
  // the bone pit: Triceratops skulls (frill, horns, beak) and ribs piled beside the mound
  const pit = c.at([-17, 0, 16]);
  pit.cyl({ name: 'BonePit', axis: 'y', len: 0.3, d: 14, p: [0, 0.15, 0], c: '#4a3a2a', shadow: false });
  const trike = (p, yaw, k) => {
    const sk = pit.at(p, [0, yaw, 12]);
    sk.box({ name: 'TrikeSkull', s: [3 * k, 2.4 * k, 4.4 * k], p: [0, 1.2 * k, 0], c: bone });
    sk.box({ name: 'TrikeFrill', s: [6 * k, 4.6 * k, 0.8 * k], p: [0, 2.6 * k, 2.2 * k], r: [-24, 0, 0], c: boneLo });
    sk.box({ name: 'TrikeBeak', s: [1.6 * k, 1.4 * k, 1.8 * k], p: [0, 0.8 * k, -2.8 * k], r: [20, 0, 0], c: '#d8c8a0' });
    for (const sd of [-1, 1]) sk.box({ name: 'TrikeHorn', s: [0.6 * k, 0.6 * k, 3.6 * k], p: [sd * 0.9 * k, 3 * k, -1.6 * k], r: [34, sd * 6, 0], c: '#fff6e0' });
    sk.box({ name: 'TrikeNoseHorn', s: [0.6 * k, 1.4 * k, 0.6 * k], p: [0, 2.2 * k, -2.4 * k], c: '#fff6e0' });
  };
  trike([0, 0, 0], 20, 1.1); trike([4, 0, -3], -40, 0.9); trike([-3, 0, 4], 160, 1);
  for (let k = 0; k < 8; k++) pit.box({ name: 'Rib', s: [0.6, 4 - Math.abs(k - 3.5) * 0.5, 0.6], p: [5 + k * 1.2, 1.8, 3], r: [0, 20, 24], c: bone });
  for (let k = 0; k < 7; k++) c.box({ name: 'LooseBone', s: [0.7, 0.7, 2.4 + R() * 3], p: [(R() - 0.5) * 50, 0.45, (R() - 0.5) * 44], r: [0, R() * 180, R() * 20], c: k % 2 ? bone : boneLo });
  // his tracks from the mouth to the mound
  for (let k = 0; k < 8; k++) {
    const pc = c.at([(k % 2 ? 3 : -3), 0.24, -34 + k * 6.6], [0, (k % 2 ? 8 : -8), 0]);
    pc.box({ name: 'TrackHeel', s: [2.6, 0.06, 2.4], p: [0, 0, 0.9], c: '#3a2c20', shadow: false });
    for (const a of [-28, 0, 28]) pc.at([0, 0, -0.2], [0, a, 0]).box({ name: 'TrackToe', s: [1, 0.06, 3.4], p: [0, 0, -1.7], c: '#3a2c20', shadow: false });
  }
  // mist on the floor, glowing fungus on the walls, a low ember light under the trunk
  const mist = c.box({ name: 'LairMist', s: [56, 1, 56], p: [0, 0.8, 0], t: 1, shadow: false });
  mist.set('CanQuery', 'bool', false);
  E.particles(mist, 'Mist', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 4, life: [6, 10], speed: [0.5, 1.5], spread: [70, 70], size: [[0, 6], [1, 14]], transp: [[0, 0.8], [1, 1]], color: [0.82, 0.9, 0.84], emission: 0.05 });
  for (let k = 0; k < 10; k++) {
    const a = 0.8 + (k / 9) * (Math.PI * 2 - 1.6);
    c.box({ name: 'GlowCap', s: [1.4, 0.4, 1.4], p: [Math.sin(a) * 34, 3 + R() * 10, -Math.cos(a) * 34], c: '#9cff7a', m: 'Neon', t: 0.15 });
  }
  const glow = th.box({ name: 'LairGlow', s: [1, 1, 1], p: [0, 8, -4], t: 1, shadow: false });
  E.pointLight(glow, [1, 0.55, 0.3], 30, 1.2);
  const glow2 = c.box({ name: 'FungusGlow', s: [1, 1, 1], p: [0, 6, 4], t: 1, shadow: false });
  E.pointLight(glow2, [0.55, 1, 0.5], 40, 0.6);
  // sign at the mouth
  const mouth = at(DEN.seg, DEN.s, -18);
  const sc = Z.at([mouth.p[0], GROUND, mouth.p[2]], [0, E.deg(toRoad) + 180, 0]);
  E.signBoard(sc, [6, 4.6, 0], 8, 2.2, "KING'S LAIR", { color: '#ffe0b8', color2: '#ff5a2a', twoSided: true, pps: 30, trim: '#ff5a2a' });
  sc.box({ name: 'SignPost', s: [0.5, 4.4, 0.5], p: [6, 2.2, 0.3], c: PAL.woodLo });
  sc.box({ name: 'SignSkull', s: [2.4, 1.8, 3], p: [6, 7, 0], c: bone });
  // markers for the fight (route positions for the chase that follows)
  const v0 = route.variants[0];
  const segS = (segId, s) => { const k = v0.segs.indexOf(segId); return k < 0 ? 0 : v0.segStart[k] + s; };
  const dc = marker(c, 'DenCenter', [0, 0.5, -4], 0, { s: [2, 1, 2] });
  dc.attr('RouteS', +segS(DEN.seg, DEN.s).toFixed(1)).attr('RouteX', DEN.x).attr('Variant', 1);
  const ff = at(FINAL.seg, FINAL.s, FINAL.x);
  const fm = marker(Z, 'FinalArena', [ff.p[0], GROUND + 0.5, ff.p[2]], 0, { s: [2, 1, 2] });
  fm.attr('RouteS', +segS(FINAL.seg, FINAL.s).toFixed(1)).attr('RouteX', 9).attr('Variant', 1);
  // a ring of standing stones marks the final stand in the meadow
  for (let k = 0; k < 9; k++) {
    const a = (k / 9) * Math.PI * 2;
    const p = [ff.p[0] + Math.cos(a) * 30, GROUND, ff.p[2] + Math.sin(a) * 30];
    if (Math.abs(Math.cos(a) * 30) < 8 && Math.sin(a) < 0) continue;
    const st = Z.at(p, [0, R() * 40, 0]);
    st.box({ name: 'StandingStone', s: [2.6, 7 + R() * 3, 2], p: [0, 4, 0], r: [0, 0, (R() - 0.5) * 8], c: '#9a948a', m: 'Slate', studs: 'top', collide: true });
  }
}

// ------------------------------------------------------------------ route landmarks: one memorable moment per stretch
function buildLandmarks(Z, segs, at, R) {
  const g = Z.group('Landmarks');
  // FERN ROAD: the Fallen Giant, a colossal tree that came down across the road; you drive under it
  {
    const f = at('FernRoad', 96);
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    const c = g.group('FallenGiant').at([f.base[0], GROUND, f.base[2]], [0, yaw + 18, 0]);
    const y0 = f.base[1] + ROAD - GROUND;
    const A = [-40, y0 + 12, 0], B = [40, y0 + 25, 0];
    c.beam(A, B, 7, 7, { name: 'GiantTrunk', c: PAL.trunk[0], studs: 'sides', collide: true });
    c.beam([A[0], A[1] + 0.6, 0], [B[0], B[1] + 0.6, 0], 6, 7.6, { name: 'GiantBark', c: PAL.trunk[1] });
    // root plate on the left bank: a wall of roots and earth torn out of the ground
    const rp = c.at([A[0] - 4, f.base[1] + ROAD - GROUND, 0], [0, 0, 0]);
    rp.box({ name: 'RootPlate', s: [4, 24, 22], p: [0, 11, 0], c: '#5e4a36', m: 'Slate', collide: true });
    rp.box({ name: 'RootSoil', s: [5, 6, 16], p: [1, 2, 0], c: '#6e5034', m: 'Slate', studs: 'top' });
    for (let k = 0; k < 10; k++) { const a = (k / 10) * Math.PI * 2; rp.beam([0, 12, 0], [-2 - R() * 3, 12 + Math.sin(a) * 13, Math.cos(a) * 13], 1.2, 1.2, { name: 'TornRoot', c: PAL.root, extend: 1 }); }
    // the crown lies on the right bank, still green, propping the trunk up
    const cr = c.at([B[0] + 6, f.base[1] + 1, 0]);
    for (let k = 0; k < 7; k++) cr.box({ name: 'FallenCanopy', s: [9 + R() * 5, 6 + R() * 3, 9 + R() * 5], p: [(R() - 0.3) * 12, 3 + R() * 6, (R() - 0.5) * 16], r: [R() * 20, R() * 90, R() * 20], c: PAL.leaf[k % 5], studs: 'top', collide: k < 2 });
    for (let k = 0; k < 7; k++) { const u = 0.12 + k * 0.11; c.box({ name: 'MossClump', s: [3.6, 1.2, 3.2], p: [A[0] + (B[0] - A[0]) * u, A[1] + (B[1] - A[1]) * u + 3.8, (R() - 0.5) * 2], c: PAL.moss, studs: 'top' }); }
    for (let k = 0; k < 9; k++) { const u = 0.3 + k * 0.06; const vl = 2 + R() * 2.5; c.box({ name: 'Vine', s: [0.3, vl, 0.3], p: [A[0] + (B[0] - A[0]) * u, A[1] + (B[1] - A[1]) * u - 3.4 - vl / 2, (R() - 0.5) * 4], c: '#3a7a2a', shadow: false }); }
    // bark rings so the underside reads as a tree from the road
    for (let k = 0; k < 9; k++) { const u = 0.08 + k * 0.105; c.at([A[0] + (B[0] - A[0]) * u, A[1] + (B[1] - A[1]) * u, 0], [0, 0, E.deg(Math.atan2(B[1] - A[1], B[0] - A[0]))]).box({ name: 'BarkRing', s: [1.4, 7.8, 7.8], c: k % 2 ? PAL.trunk[1] : PAL.root }); }
  }
  // WATERFALL RIDGE: the road runs under a rock overhang behind a falling curtain of water
  {
    const sg = segs.WaterfallRidge;
    const f = at('WaterfallRidge', 96);
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    const c = g.group('FallsCurtain').at([f.base[0], GROUND, f.base[2]], [0, yaw, 0]);
    const ry = f.base[1] + ROAD - GROUND;
    const hw = sg.width / 2;
    const top = ry + 17;
    // the inside wall (left) and the overhang roof reaching out over the road
    E.cliffWall(c, [[-hw - 4, 18], [-hw - 4, -18]], { h: top + 6, d: 12, seed: 34002, slope: 1, chunk: 9, name: 'FallsWall', y: 0 });
    c.box({ name: 'FallsWallCore', s: [8, top + 2, 34], p: [-hw - 7, (top + 2) / 2, 0], c: PAL.cliff[3], m: 'Slate', collide: true });
    c.box({ name: 'Overhang', s: [sg.width + 12, 5, 30], p: [0, top + 2.5, 0], c: PAL.cliff[0], m: 'Slate', collide: true });
    c.box({ name: 'OverhangTop', s: [sg.width + 12, 1.2, 30], p: [0, top + 5.6, 0], c: PAL.grassLo, studs: 'top' });
    for (let k = 0; k < 5; k++) c.box({ name: 'Drip', s: [1.4, 2 + R() * 2, 1.4], p: [-hw + R() * sg.width, top - 1, (R() - 0.5) * 24], c: PAL.cliff[2], m: 'Slate' });
    c.box({ name: 'OverhangMoss', s: [2.4, 1.6, 30], p: [hw + 5, top + 0.4, 0], c: PAL.moss, studs: 'top' });
    for (let k = 0; k < 10; k++) { const vl = 2 + R() * 4; c.box({ name: 'Vine', s: [0.3, vl, 0.3], p: [-hw + 2 + R() * (sg.width - 4), top - vl / 2, (R() - 0.5) * 26], c: '#3a7a2a', shadow: false }); }
    // the curtain: water pouring off the outer lip, falling past the right edge of the road into a pool below
    E.waterfall(c, [hw + 4, top + 5, 0], 28, top + 5, { yaw: -90, seed: 34001, name: 'Curtain', mist: 16 });
    c.box({ name: 'CurtainPool', s: [12, 0.3, 34], p: [hw + 9, 0.3, 0], c: PAL.waterDeep, m: 'Glass', t: 0.2, shadow: false }).tag('DinoWater');
    const light = c.box({ name: 'CurtainGlow', s: [1, 1, 1], p: [0, ry + 6, 0], t: 1, shadow: false });
    E.pointLight(light, [0.6, 0.85, 1], 30, 0.9);
  }
  // OLD RUINS: the Temple Gate, a stepped stone portal crowned with a carved Tyrant head
  {
    const sg = segs.OldRuins;
    const f = at('OldRuins', 34);
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    const c = g.group('TempleGate').at([f.base[0], GROUND, f.base[2]], [0, yaw, 0]);
    const hw = sg.width / 2 + 8.5;
    for (const side of [-1, 1]) {
      for (let k = 0; k < 6; k++) c.box({ name: 'GatePillar', s: [8 - k * 0.3, 4.2, 8 - k * 0.3], p: [side * hw, 2.1 + k * 4.2, 0], r: [0, k % 2 ? 4 : -3, 0], c: k % 2 ? '#b8ad94' : '#c8bea6', m: 'Slate', studs: 'top', collide: k === 0 });
      c.box({ name: 'GateBase', s: [11, 2, 11], p: [side * hw, 1, 0], c: '#a89c82', m: 'Slate', studs: 'top', collide: true });
      c.box({ name: 'Vines', s: [0.4, 14, 0.4], p: [side * hw - side * 4.2, 15, -2], c: '#3a7a2a', shadow: false });
      c.box({ name: 'Brazier', s: [3, 1.6, 3], p: [side * hw, 26.4, -4.4], c: '#5a5148', m: 'Slate' });
      const fl = c.box({ name: 'BrazierFire', s: [1.6, 1.6, 1.6], p: [side * hw, 27.8, -4.4], c: '#ffb04a', m: 'Neon', t: 0.2 });
      E.particles(fl, 'Fire', { rate: 18, life: [0.5, 1], speed: [2, 4], dir: 1, spread: [12, 12], size: [[0, 1.4], [1, 0]], color: [[0, [1, 0.8, 0.3]], [1, [1, 0.3, 0.1]]], emission: 1 });
      E.pointLight(fl, [1, 0.62, 0.3], 26, 1.4);
    }
    // stepped lintel
    for (let k = 0; k < 3; k++) c.box({ name: 'GateLintel', s: [hw * 2 + 12 - k * 8, 3, 9 - k], p: [0, 26.5 + k * 3, 0], c: k % 2 ? '#b8ad94' : '#a89c82', m: 'Slate', studs: 'top' });
    // the carved head: a blocky T. rex looking down the road, glowing eyes
    const hd = c.at([0, 35, -1.5]);
    hd.box({ name: 'CarvedHead', s: [8, 6, 9], p: [0, 3, 0], c: '#a89c82', m: 'Slate', studs: 'top' });
    hd.box({ name: 'CarvedSnout', s: [6, 3.4, 6], p: [0, 2, -6.6], c: '#b8ad94', m: 'Slate' });
    hd.box({ name: 'CarvedJaw', s: [5.6, 1.6, 8], p: [0, -0.4, -4.4], r: [10, 0, 0], c: '#9a8e76', m: 'Slate' });
    for (let k = 0; k < 4; k++) hd.box({ name: 'CarvedTooth', s: [0.6, 1.2, 0.6], p: [-2.1 + k * 1.4, 0.4, -9.2], c: '#efe2c4' });
    hd.sym((s) => s.box({ name: 'CarvedEye', s: [0.3, 1.1, 1.6], p: [4.05, 4.2, -2.4], c: '#ff7a3a', m: 'Neon' }));
    E.signBoard(c, [hw + 8, 4, -4], 7, 1.8, 'OLD RUINS', { r: [0, -10, 0], color: '#f4ecd8', color2: '#4fd1a5', twoSided: true, pps: 30 });
    c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [hw + 8, 2, -3.7], c: PAL.woodLo });
  }
}

// camera markers for the era's establishing shots (each part looks along its -Z)
function buildCinematics(Z, at) {
  const g = Z.group('Cinematics', 'Folder');
  const shot = (name, pos, look) => {
    const l = Z.wpt(look);
    const m = marker(g, name, pos, 0, { s: [1, 1, 1] });
    m.attr('LookX', +l[0].toFixed(2)).attr('LookY', +l[1].toFixed(2)).attr('LookZ', +l[2].toFixed(2));
    return m;
  };
  const den = at(DEN.seg, DEN.s, DEN.x);
  const lake = at('RiverBend', 150, 40);
  const meadow = at('Wilds', 500, 30);
  shot('EstShot1', [-260, 120, 360], [0, 0, -40]); // the whole valley from above the arrival
  shot('EstShot2', [lake.p[0] - 50, 14, lake.p[2] + 40], [lake.p[0], 4, lake.p[2]]); // the lagoon
  shot('EstShot3', [meadow.p[0] + 70, 22, meadow.p[2] - 30], [meadow.p[0], 6, meadow.p[2]]); // the meadow
  shot('EstShot4', [den.p[0] + 20, 40, den.p[2] - 40], [den.p[0], 10, den.p[2] + 20]); // the King's lair
}

function buildRangerCamp(Z, at) {
  const f = at('FernRoad', 0);
  const c = Z.at([f.p[0] + 20, GROUND, f.p[2] - 12], [0, -60, 0]);
  NPC.buildNpc(c.parent, c.world(new CF(0, 0, 0)), 'Ranger');
}

function buildReturnPortal(Z, at) {
  const sg = 'Sprint';
  const f = at(sg, 1e9);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  hexPortal(Z, [f.p[0] - f.f[0] * 14, GROUND, f.p[2] - f.f[2] * 14] /* 14 back from the end: you drive through it before the warp (extract at L-8) */, yaw, 15, 'ReturnPortal', { color: '#ffb02e' });
}

function buildRiver(Z, segs, at, R) {
  // a river runs down the west side, crossing River Bend at the splash
  const g = Z.group('River');
  const pts = RIVER_PTS;
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i], b = pts[i + 1];
    g.beam([a[0], GROUND + 0.05, a[1]], [b[0], GROUND + 0.05, b[1]], 22, 0.2, { name: 'RiverBank', c: '#b9a77a', m: 'Sand', extend: 10 });
    g.beam([a[0], GROUND + 0.18, a[1]], [b[0], GROUND + 0.18, b[1]], 16, 0.2, { name: 'RiverWater', c: '#4fb8e0', m: 'Glass', t: 0.2, extend: 8, shadow: false }).tag('DinoWater');
    for (let k = 0; k < 3; k++) {
      const t = R();
      const x = a[0] + (b[0] - a[0]) * t + (R() - 0.5) * 18, z = a[1] + (b[1] - a[1]) * t + (R() - 0.5) * 18;
      E.rock(g, [x, GROUND, z], 0.8 + R(), 30000 + i * 7 + k, { colors: ['#8a857b', '#7d7a73', '#6c6962'] });
    }
  }
  // the river ends in a lake inside the fork loop, seen from both branches
  const lake = g.at([-160, GROUND, -12]);
  lake.cyl({ name: 'LakeShore', axis: 'y', len: 0.3, d: 66, p: [0, 0.05, 0], c: '#b9a77a', m: 'Sand' });
  lake.cyl({ name: 'LakeWater', axis: 'y', len: 0.3, d: 58, p: [0, 0.2, 0], c: '#4fb8e0', m: 'Glass', t: 0.2, shadow: false }).tag('DinoWater');
  for (let k = 0; k < 16; k++) {
    const a = (k / 16) * Math.PI * 2;
    lake.box({ name: 'ShoreStone', s: [2 + R() * 2, 0.9, 1.6 + R()], p: [Math.cos(a) * 30.5, 0.3, Math.sin(a) * 30.5], r: [0, -E.deg(a), R() * 8], c: PAL.rock[k % 4], m: 'Slate' });
  }
  for (let k = 0; k < 9; k++) lake.cyl({ name: 'LilyPad', axis: 'y', len: 0.1, d: 1.6 + R(), p: [(R() - 0.5) * 40, 0.38, (R() - 0.5) * 40], c: '#4fb043', shadow: false });
  lake.box({ name: 'Islet', s: [8, 1.6, 6], p: [6, 0.6, -4], r: [0, 20, 0], c: PAL.rock[0], m: 'Slate', studs: 'top' });
  E.palm(lake, [6, 1.4, -4], 13, 30500);
  // splash crossing on River Bend: shallow water across the road
  const f = at('RiverBend', 110);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  const c = g.at([f.p[0], ROAD, f.p[2]], [0, yaw, 0]);
  c.box({ name: 'Ford', s: [28, 0.12, 22], p: [0, 0.06, 0], c: '#5fc8f0', m: 'Glass', t: 0.25, shadow: false }).tag('DinoWater');
  for (let k = 0; k < 8; k++) c.box({ name: 'FordStone', s: [1.2 + R(), 0.4, 1.2 + R()], p: [(R() - 0.5) * 22, 0.1, (R() - 0.5) * 18], r: [0, R() * 90, 0], c: '#9a958a', m: 'Slate' });
  const sp = c.box({ name: 'SplashHost', s: [24, 1, 18], p: [0, 0.4, 0], t: 1, shadow: false });
  E.particles(sp, 'Spray', { rate: 4, life: [0.6, 1.2], speed: [3, 6], dir: 1, spread: [40, 40], size: [[0, 0.6], [1, 1.6]], transp: [[0, 0.3], [1, 1]], color: [0.9, 0.97, 1], emission: 0.3 });
}

function buildTunnel(Z, segs, at, R) {
  // living arches of trees closing over the Fern Tunnel road
  const g = Z.group('FernTunnelCanopy');
  const sg = segs.FernTunnel;
  const L = sg.cum[sg.cum.length - 1];
  const leaves = [];
  for (let s = 34; s < L - 22; s += 15) { // clear of both fork mouths
    const f = at('FernTunnel', s);
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    // each arch is its own unit (QC + the tree spacing pass treat it like a tree)
    const c = g.group('TunnelArch').at([f.base[0], GROUND, f.base[2]], [0, yaw, 0]);
    const hw = sg.width / 2 + 5; // trunks stand clear of the rover's lane (and of the road's edge stones)
    for (const side of [-1, 1]) {
      for (let k = 0; k < 4; k++) c.box({ name: 'ArchTrunk', s: [1.6, 3.2, 1.6], p: [side * hw, 1.6 + k * 3.1, 0], r: [0, k * 20, -side * k * 4], c: PAL.trunk[k % 2], studs: 'sides', collide: k === 0 });
    }
    c.beam([-hw, 12.5, 0], [0, 15, 0], 1.4, 1.4, { name: 'ArchBough', c: PAL.trunk[1], extend: 0.6 });
    c.beam([hw, 12.5, 0], [0, 15, 0], 1.4, 1.4, { name: 'ArchBough', c: PAL.trunk[1], extend: 0.6 });
    // leaf clumps stacked, not interpenetrating: each clump takes the lowest layer where it cuts into no clump
    // already placed (this arch's or the last one's), so overlapping clumps sit one on top of the other like a
    // layered roof. A clump with no free layer shrinks and tries again, and is left out as a last resort.
    // Same R() draws as before so everything built after keeps its randomness.
    for (let k = 0; k < 6; k++) {
      const sx = 6 + R() * 3, sz = 6 + R() * 3, jz = (R() - 0.5) * 4, ry = R() * 90;
      const x = -hw + (k / 5) * 2 * hw, y0 = 14.2 + Math.sin((k / 5) * Math.PI) * 1.2;
      let ok = false;
      for (const kk of [1, 0.82, 0.66]) {
        for (let tier = 0; tier < 3 && !ok; tier++) {
          const leaf = c.box({ name: 'ArchLeaves', s: [sx * kk, 2.6, sz * kk], p: [x, y0 + tier * 2.7, jz], r: [0, ry, 0], c: PAL.leaf[k % 5], studs: 'top' });
          const O = QC.obb({ s: leaf._preview.size, cf: [leaf._cf.x, leaf._cf.y, leaf._cf.z, ...leaf._cf.r] });
          if (leaves.some((P) => QC.penetration(O, P) > 0.02)) { leaf.parent.children.splice(leaf.parent.children.indexOf(leaf), 1); continue; }
          leaves.push(O);
          ok = true;
        }
        if (ok) break;
      }
    }
    for (let k = 0; k < 3; k++) c.box({ name: 'HangingVine', s: [0.25, 2 + R() * 1.4, 0.25], p: [(R() - 0.5) * hw * 1.6, 13.4, (R() - 0.5) * 3], c: '#3a7a2a', shadow: false });
    if (Math.round(s / 15) % 2 === 0) {
      const glow = c.box({ name: 'Glowshroom', s: [0.9, 0.6, 0.9], p: [hw + 1.6, 0.8, 1.5], c: '#9ff3e8', m: 'Neon' });
      c.box({ name: 'ShroomStem', s: [0.3, 0.6, 0.3], p: [hw + 1.6, 0.3, 1.5], c: '#e8e2d4' });
      E.pointLight(glow, [0.6, 1, 0.9], 10, 0.7);
    }
  }
}

function buildCanyon(Z, segs, at, R) {
  // Rock Canyon: walls on both sides of the Wilds from s=125 to s=395
  const g = Z.group('RockCanyon');
  const left = [], right = [];
  const leftB = [];
  for (let s = 115; s <= 400; s += 14) {
    const sg = segs.Wilds;
    const hw = sg.width / 2 + 5;
    const lf = at('Wilds', s, -hw), rf = at('Wilds', s, hw);
    // the King's lair opens off the left wall (s ~238..282)
    if (s < DEN.s - 24) left.push([lf.p[0], lf.p[2]]);
    else if (s > DEN.s + 22) leftB.push([lf.p[0], lf.p[2]]);
    right.push([rf.p[0], rf.p[2]]);
  }
  const cols = ['#a8845a', '#9a7650', '#b8946a', '#8a6a48', '#c09a6a'];
  E.cliffWall(g, left, { h: 34, d: 18, seed: 501, slope: 3, colors: cols, chunk: 13, name: 'CanyonWallL' });
  E.cliffWall(g, leftB, { h: 34, d: 18, seed: 503, slope: 3, colors: cols, chunk: 13, name: 'CanyonWallL2' });
  E.cliffWall(g, right.reverse(), { h: 38, d: 18, seed: 502, slope: 3, colors: cols, chunk: 13, name: 'CanyonWallR' });
  // canyon entrance arch of stacked boulders
  const f = at('Wilds', 120);
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  const c = g.at([f.base[0], GROUND, f.base[2]], [0, yaw, 0]);
  c.beam([-17, 30, 0], [17, 33, 0], 6, 5, { name: 'NaturalArch', c: '#9a7650', m: 'Slate', studs: 'top', extend: 3 });
  for (let k = 0; k < 4; k++) c.box({ name: 'ArchRubble', s: [3 + R() * 2, 2.5, 3 + R() * 2], p: [-14 + k * 9, 35 + R() * 2, (R() - 0.5) * 3], r: [0, R() * 90, 0], c: PAL.cliff[k % 5], m: 'Slate' });
  E.signBoard(c, [-19, 4, 2], 6, 1.6, 'ROCK CANYON', { r: [0, 0, 4], color: '#ffe0b8', color2: '#ff9a3a', twoSided: true, pps: 30 });
  c.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [-19, 2, 2.3], c: PAL.woodLo });
  // scattered rubble at the wall feet + bones of something big
  for (let s = 140; s < 390; s += 22) for (const side of [-1, 1]) {
    const fr = at('Wilds', s + R() * 8, side * (segs.Wilds.width / 2 + 4.5)); // (clear of the road: was +2.5, rocks poked onto it)
    E.rock(g, [fr.p[0], GROUND, fr.p[2]], 0.9 + R() * 0.8, 31000 + s + side, { colors: cols, moss: false });
  }
  const fb = at('Wilds', 255, -22);
  const sk = g.at([fb.p[0], GROUND, fb.p[2]], [0, R() * 360, 0]);
  for (let k = 0; k < 6; k++) sk.box({ name: 'Rib', s: [0.6, 5 - Math.abs(k - 2.5) * 0.6, 0.6], p: [k * 1.4 - 3.5, 2, 0], r: [0, 0, 20], c: '#efe2c4' });
  sk.box({ name: 'Spine', s: [9, 0.8, 0.8], p: [0, 4.3, 1.2], c: '#e3d4b0' });
  sk.box({ name: 'Skull', s: [2.6, 2, 3.4], p: [-6, 1, 0.4], r: [0, 20, 10], c: '#efe2c4' });
}

function buildMeadow(Z, segs, at, R) {
  const g = Z.group('HornMeadow');
  // flowers everywhere, a few lone giant trees, the herd's grazing ground (herd is spawned on clients)
  for (let k = 0; k < 40; k++) {
    const s = 400 + R() * 210, side = R() > 0.5 ? 1 : -1;
    const f = at('Wilds', s, side * (20 + R() * 60));
    E.flowers(g, [f.p[0], GROUND, f.p[2]], 32000 + k, { n: 7, spread: 6, colors: ['#ffd23a', '#ffffff', '#ff8ab0', '#c86bff'] });
  }
  const fin = at(FINAL.seg, FINAL.s, FINAL.x);
  for (let k = 0; k < 6; k++) {
    const f = at('Wilds', 410 + k * 35, (k % 2 ? 1 : -1) * (42 + R() * 30));
    if (Math.hypot(f.p[0] - fin.p[0], f.p[2] - fin.p[2]) < 42) continue; // the final arena stays open
    const h = 22 + R() * 6; // (drawn first, so the random sequence after it is unchanged)
    if (nearLife(f.p[0], f.p[2], 12)) continue; // the herds' walks stay clear (2026-10-14: the Triceratops loop went through one)
    E.jungleTree(g, [f.p[0], GROUND, f.p[2]], h, 32100 + k, { canopy: 8 });
  }
  // one lone grazer, well down the meadow from Horn Nest so it never walks into the nest's shots
  // (2026-10-11: was a herd of four right beside the nest, blocking the establishing shot)
  {
    const f = at('Wilds', 565, 76);
    const m = g.box({ name: 'HerdSpot1', s: [2, 1, 2], p: [f.p[0], GROUND + 0.5, f.p[2]], r: [0, E.deg(Math.atan2(-f.f[0], -f.f[2])) + 120, 0], t: 1, shadow: false });
    m.set('CanQuery', 'bool', false).tag('MeadowHerdSpot');
  }
  // charge lane markers (scuffed earth where the trike will cross)
  const cf = at('Wilds', 520);
  const yaw = E.deg(Math.atan2(-cf.f[0], -cf.f[2]));
  const c = g.at([cf.base[0], GROUND, cf.base[2]], [0, yaw, 0]);
  for (let k = 0; k < 8; k++) c.box({ name: 'Scuff', s: [6, 0.08, 2.4], p: [-40 + k * 11 + (R() - 0.5) * 4, 0.04, (R() - 0.5) * 6], r: [0, R() * 30, 0], c: PAL.dirtLo, shadow: false });
}

function buildRidge(Z, segs, at, R, gaps) {
  // Waterfall Ridge rides a rock shelf up to the gorge; a waterfall drops into it beside the jump
  const g = Z.group('WaterfallRidge');
  const sg = segs.WaterfallRidge;
  const L = sg.cum[sg.cum.length - 1];
  const inGap = (s) => gaps.some(([a, b]) => s > a - 2 && s < b + 2);
  for (let s = 0; s < L; s += 6) {
    const f = at('WaterfallRidge', s);
    if (f.base[1] < 1 || inGap(s)) continue;
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    // the shelf under the road: a stepped rock column down to the ground
    g.at([f.base[0], GROUND, f.base[2]], [0, yaw, 0]).box({ name: 'Shelf', s: [sg.width + 6, f.base[1] + ROAD - GROUND - 0.4, 7], p: [0, (f.base[1] + ROAD - GROUND - 0.4) / 2, 0], c: PAL.cliff[Math.floor(s / 6) % 5], m: 'Slate', collide: true });
  }
  for (const [a, b] of gaps) {
    const fa = at('WaterfallRidge', a), fb = at('WaterfallRidge', b), fm = at('WaterfallRidge', (a + b) / 2);
    const yaw = E.deg(Math.atan2(-fm.f[0], -fm.f[2]));
    // lips at both ends of the gap
    for (const [fr, dir] of [[fa, 1], [fb, -1]]) {
      const yw = E.deg(Math.atan2(-fr.f[0], -fr.f[2]));
      g.at([fr.base[0], ROAD + fr.base[1], fr.base[2]], [0, yw, 0]).box({ name: 'JumpLip', s: [sg.width, 0.8, 1.6], p: [0, 0.1, -dir * 0.4], c: '#f2c230', studs: 'top' });
      g.at([fr.base[0], ROAD + fr.base[1], fr.base[2]], [0, yw, 0]).wedgeF({ name: 'Kicker', s: [sg.width - 4, 1.2, 4], p: [0, 0.6, -dir * -2], face: dir > 0 ? 'back' : 'front', c: '#7a746a', m: 'Slate' });
    }
    // gorge below + falls pouring past the gap
    const c = g.at([fm.base[0], GROUND, fm.base[2]], [0, yaw, 0]);
    c.box({ name: 'GorgeWater', s: [90, 0.3, b - a + 10], p: [0, 0.2, 0], c: '#3fa8d8', m: 'Glass', t: 0.15, shadow: false }).tag('DinoWater');
    E.waterfall(c, [-sg.width / 2 - 26, 40, 0], 14, 40, { yaw: -90, seed: 33001, name: 'RidgeFalls' });
    E.cliffWall(c, [[-sg.width / 2 - 30, 22], [-sg.width / 2 - 30, -22]], { h: 44, d: 22, seed: 33002, slope: 3, chunk: 11, name: 'FallsCliff', trees: true });
    for (let k = 0; k < 6; k++) E.rock(c, [(R() - 0.5) * 70, 0, (R() - 0.5) * (b - a)], 1.5 + R() * 1.5, 33100 + k);
  }
}

function buildRuins(Z, segs, at, R) {
  const g = Z.group('OldRuins');
  const sg = segs.OldRuins;
  const L = sg.cum[sg.cum.length - 1];
  for (let s = 60; s < L - 10; s += 26) {
    const f = at('OldRuins', s);
    const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
    const c = g.at([f.base[0], GROUND, f.base[2]], [0, yaw, 0]);
    const hw = sg.width / 2 + 5;
    const broken = R() > 0.5;
    for (const side of [-1, 1]) {
      const hgt = broken && side > 0 ? 2 : 5;
      for (let k = 0; k < hgt; k++) c.box({ name: 'Column', s: [2.6, 3, 2.6], p: [side * hw, 1.5 + k * 3, 0], r: [0, k * 6, 0], c: k % 2 ? '#b8ad94' : '#c8bea6', m: 'Slate', studs: 'top', collide: k === 0 });
    }
    if (!broken) {
      c.box({ name: 'Lintel', s: [hw * 2 + 3, 2.4, 3], p: [0, 16.2, 0], c: '#a89c82', m: 'Slate', studs: 'top' });
      c.box({ name: 'Glyph', s: [2, 1.4, 0.1], p: [0, 16.2, -1.55], c: '#4fd1a5', m: 'Neon' });
    } else {
      c.box({ name: 'FallenLintel', s: [hw * 1.4, 2.4, 3], p: [hw + 9, 1.2, 5], r: [0, 30, 8], c: '#a89c82', m: 'Slate', studs: 'top' });
    }
    for (let k = 0; k < 3; k++) c.box({ name: 'Rubble', s: [1.4 + R() * 1.4, 1 + R(), 1.4 + R() * 1.4], p: [(R() > 0.5 ? 1 : -1) * (hw + 2 + R() * 5), 0.5, (R() - 0.5) * 8], r: [R() * 20, R() * 90, 0], c: '#b8ad94', m: 'Slate' });
  }
  // a half-buried statue head of a crested dino, staring at the road
  const f = at('OldRuins', 182, 22);
  const st = g.at([f.p[0], GROUND, f.p[2]], [0, E.deg(Math.atan2(f.r[0], f.r[2])), 0]);
  st.box({ name: 'StatueHead', s: [7, 6, 10], p: [0, 3, 0], c: '#a89c82', m: 'Slate', studs: 'top' });
  st.box({ name: 'StatueSnout', s: [5, 3.4, 5], p: [0, 2, -7], c: '#b8ad94', m: 'Slate' });
  st.box({ name: 'StatueCrest', s: [2, 3, 9], p: [0, 7, 4], r: [-25, 0, 0], c: '#a89c82', m: 'Slate' });
  st.sym((s) => s.box({ name: 'StatueEye', s: [0.3, 1, 1.4], p: [3.55, 4, -2], c: '#4fd1a5', m: 'Neon' }));
}

function buildNestSite(Z, n, at, R) {
  const f = at(n.seg, n.s, n.x);
  const g = Z.group('Nest_' + n.species);
  g.parent.attr('NestId', n.id).attr('Species', n.species).tag('ExpeditionNest');
  const c = g.at([f.p[0], GROUND, f.p[2]], [0, R() * 360, 0]);
  // cleared earth
  c.cyl({ name: 'Clearing', axis: 'y', len: 0.1, d: 22, p: [0, 0.05, 0], c: '#8a6a48', m: 'Sand', shadow: false });
  // twig + bone ring
  for (let k = 0; k < 14; k++) {
    const a = (k / 14) * Math.PI * 2;
    c.box({ name: 'NestTwig', s: [2.6, 0.7, 0.8], p: [Math.cos(a) * 3.6, 0.5 + (k % 2) * 0.35, Math.sin(a) * 3.6], r: [R() * 20, -E.deg(a) + 90, R() * 15], c: k % 3 ? '#7a5a36' : '#8a6a42' });
  }
  for (let k = 0; k < 5; k++) c.box({ name: 'NestBone', s: [2, 0.4, 0.4], p: [(R() - 0.5) * 12, 0.25, (R() - 0.5) * 12], r: [0, R() * 180, 0], c: '#efe2c4' });
  c.cyl({ name: 'NestBed', axis: 'y', len: 0.4, d: 6, p: [0, 0.4, 0], c: '#5f8f3e' });
  // 3 eggs in the nest (cosmetic — every player gets their own steal)
  for (let k = 0; k < 3; k++) {
    const egg = buildEgg(n.species);
    B.scaleTree(egg, 0.55);
    const a = (k / 3) * Math.PI * 2;
    B.transformTree(egg, c.frame.mul(new CF(Math.cos(a) * 1.1, 0.6, Math.sin(a) * 1.1)).mul(CF.deg(0, k * 40, (k - 1) * 8)));
    egg.tags = [];
    egg.name = 'NestEgg';
    g.parent.add(egg);
  }
  // research flag + danger sign on the road side
  // (2026-10-13: the flag stood right on GuardSpot1 - the first guard (a raptor) was impaled on its pole in every
  // scene. Now midway between two guard spots, outside the guard ring and the clearing)
  E.flag(c, [0.37, 0, 16], '#e8473a', { h: 7 });
  const sgn = Z.at([f.base[0] - f.r[0] * (n.x > 0 ? -21 : 21), GROUND, f.base[2] - f.r[2] * (n.x > 0 ? -21 : 21)], [0, E.deg(Math.atan2(-f.f[0], -f.f[2])) + 180, 0]);
  E.signBoard(sgn, [0, 4.2, 0], 7, 2.2, n.label, { color: '#ffe0b8', color2: '#ff5a2a', twoSided: true, pps: 30, trim: '#ff5a2a' });
  sgn.box({ name: 'SignPost', s: [0.5, 4, 0.5], p: [0, 2, 0.3], c: PAL.woodLo });
  // guard spots (clients spawn the sleepers / herd here)
  for (let k = 0; k < 3; k++) {
    const a = (k / 3) * Math.PI * 2 + 0.5;
    const m = c.box({ name: 'GuardSpot' + (k + 1), s: [1.5, 1, 1.5], p: [Math.cos(a) * 8, 0.5, Math.sin(a) * 8], r: [0, -E.deg(a) - 90, 0], t: 1, shadow: false });
    m.set('CanQuery', 'bool', false);
  }
  const host = c.box({ name: 'NestCore', s: [2, 2, 2], p: [0, 1.4, 0], t: 1, shadow: false });
  host.set('CanQuery', 'bool', false);
  const pr = new Inst('ProximityPrompt', 'GrabPrompt');
  pr.set('ActionText', 'string', 'Grab Egg').set('ObjectText', 'string', n.label).set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 9).set('HoldDuration', 'float', 1.6).set('RequiresLineOfSight', 'bool', false).set('Exclusivity', 'token', 1);
  pr.attr('NestId', n.id);
  host.add(pr);
  E.particles(host, 'NestGlint', { rate: 3, life: [0.8, 1.4], speed: [0.5, 1], size: [[0, 0.5], [1, 0]], color: [1, 0.95, 0.6], emission: 1 });
  E.pointLight(host, [1, 0.82, 0.5], 18, 0.8); // a warm glow so every nest reads as a landmark (and lights cutscenes)
  // fern cover clumps: crouch in one while a parent is watching and its cone can't see you.
  // Two flank the path from the road, the rest ring the clearing so you can circle around.
  const roadDir = [-(Math.sign(n.x) || 1) * f.r[0], -(Math.sign(n.x) || 1) * f.r[2]];
  const baseA = Math.atan2(roadDir[1], roadDir[0]);
  const spots = [[40, 11], [-40, 11], [95, 14], [-95, 14], [150, 13.5], [-150, 13.5]];
  spots.forEach(([deg, r], k) => {
    const a = baseA + (deg * Math.PI) / 180;
    const x = f.p[0] + Math.cos(a) * r, z = f.p[2] + Math.sin(a) * r;
    const cc = g.group('CoverClump');
    const cz = cc.at([x, GROUND, z], [0, R() * 360, 0]);
    for (let j = 0; j < 4; j++) {
      const aa = (j / 4) * Math.PI * 2 + R();
      E.fern(cz, [Math.cos(aa) * 2.9, 0, Math.sin(aa) * 2.9], 1.9 + R() * 0.5, 34100 + n.id * 40 + k * 4 + j);
    }
    cz.box({ name: 'CoverLeaves', s: [3.4, 2.6, 3.4], p: [0, 1.3, 0], r: [0, 45, 0], c: '#3f8a34', studs: 'top' });
    cz.box({ name: 'CoverLeavesTop', s: [2.4, 1.2, 2.4], p: [0, 3.1, 0], c: '#4fa83e', studs: 'top' });
    const m = cz.box({ name: 'CoverSpot', s: [9, 1, 9], p: [0, 0.5, 0], t: 1, shadow: false });
    m.set('CanQuery', 'bool', false);
  });
}

// ------------------------------------------------------------------ FREE ROAM set pieces (2026-10-14)
const loc = (p) => [p[0] - FV_ORIGIN[0], p[1] - FV_ORIGIN[1], p[2] - FV_ORIGIN[2]]; // world -> zone-local
// Returns vegetation keep-out circles [x, z, r] so the jungle scatter leaves them clear.
function buildRoam(Z, roads, segs, at, R, T, route) {
  const hAt = T.hAt;
  const keep = [];
  for (const t of ROAM.trails) trailSurface(roads, t, hAt);
  buildSkyFalls(Z, R, keep);
  buildElderTree(Z, R, hAt, keep);
  buildArchRock(Z, R, hAt, keep);
  buildRiverTrail(Z, R, hAt, keep);
  buildGameTrail(Z, R, keep);
  buildKickers(Z, hAt, keep);
  buildRoamSpots(Z, hAt);
  buildLifePaths(Z, hAt, segs);
  buildBarrier(Z);
  return keep;
}

// a trail's surface: tilted dirt slabs between its samples (merged while straight and evenly sloped), on the Roads
// folder so the rover, the fight dinos (Encounter's floors) and the map QC all treat it like the road
const TRAIL_C = ['#a07a4c', '#987247'];
function trailSurface(roads, t, hAt) {
  const S = t.samples, C = t.cum, n = S.length, W = t.w;
  const head = (u, v) => Math.atan2(S[v][0] - S[u][0], S[v][2] - S[u][2]);
  const grade = (u, v) => (S[v][1] - S[u][1]) / Math.max(1e-3, C[v] - C[u]);
  const angDiff = (x, y) => Math.abs(Math.atan2(Math.sin(x - y), Math.cos(x - y)));
  let tile = 0;
  for (let i = 0; i < n - 1;) {
    let j = Math.min(n - 1, i + 2);
    const h0 = head(i, j), g0 = grade(i, j);
    while (j < n - 1 && C[j + 1] - C[i] <= 14 && angDiff(head(i, j + 1), h0) < 0.03 && Math.abs(grade(i, j + 1) - g0) < 0.008) j++;
    const a = S[i], b = S[j];
    roads.beam([a[0], ROAD + a[1] - 0.3, a[2]], [b[0], ROAD + b[1] - 0.3, b[2]], W, 0.6, { name: 'Road', c: TRAIL_C[tile % 2], m: 'Ground', collide: true, extend: 0.5 });
    // worn tyre tracks + grassy shoulders, so it reads as a trail and not a second road
    if (tile % 2 === 0) for (const rx of [-W * 0.2, W * 0.2]) {
      const f = RT.frameAt(S, i), g = RT.frameAt(S, j);
      roads.beam([a[0] + f.r[0] * rx, ROAD + a[1] + 0.02, a[2] + f.r[2] * rx], [b[0] + g.r[0] * rx, ROAD + b[1] + 0.02, b[2] + g.r[2] * rx], 1.1, 0.04, { name: 'Rut', c: '#7e5d38', m: 'Ground', shadow: false });
    }
    for (const side of [-1, 1]) {
      const f = RT.frameAt(S, i), g = RT.frameAt(S, j);
      const o = side * (W / 2 - 0.9);
      roads.beam([a[0] + f.r[0] * o, ROAD + a[1] + 0.03, a[2] + f.r[2] * o], [b[0] + g.r[0] * o, ROAD + b[1] + 0.03, b[2] + g.r[2] * o], 1.8, 0.05, { name: 'Rut', c: '#6f9a3e', m: 'Grass', shadow: false });
    }
    tile++;
    i = j;
  }
  // trail-head posts where it leaves the road / the meadow: a little wooden marker with a painted arrow
  const p0 = S[0], f0 = RT.frameAt(S, Math.min(6, n - 1));
  const yaw = E.deg(Math.atan2(-f0.f[0], -f0.f[2]));
  const px = p0[0] + f0.r[0] * (W / 2 + 2.5) + f0.f[0] * 6, pz = p0[2] + f0.r[2] * (W / 2 + 2.5) + f0.f[2] * 6;
  const c = roads.at([px, GROUND + hAt(px, pz), pz], [0, yaw, 0]);
  c.box({ name: 'TrailPost', s: [0.8, 4.2, 0.8], p: [0, 2.1, 0], c: PAL.woodLo, studs: 'top', collide: true });
  c.box({ name: 'TrailArrow', s: [0.3, 1, 3], p: [0, 3.6, -0.9], c: '#f2c230', shadow: false });
  c.wedgeF({ name: 'TrailArrowTip', s: [0.3, 1, 1.2], p: [0, 3.6, -3], face: 'front', c: '#f2c230', shadow: false });
}

// SKY FALLS: the river's source. A tall fall off the west cliffs into a plunge pool, a rainbow in the spray, and
// behind the curtain a grotto in the cliff (glowing crystals, an old explorer's camp) wide enough to drive into
function buildSkyFalls(Z, R, keep) {
  const g = Z.group('SkyFalls');
  const { z0, z1, z } = ROAM.falls;
  const X = -420; // the cliff line
  const D = 38, H = 16; // grotto depth (into the cliff) and height
  const rockC = ['#8a7a68', '#7c6e5e', '#958571', '#6e6254'];
  // the roof: cliff strata from the grotto's ceiling up, closing the gap in the ring
  E.cliffWall(g, [[X, z1], [X, z0]], { h: 44, d: D + 6, seed: 407, slope: 5, chunk: 16, name: 'GrottoCliff', y: H, trees: true });
  g.box({ name: 'GrottoCeiling', s: [D + 2, 3, z1 - z0 + 8], p: [X - D / 2 - 1, H + 1.5, z], c: '#5e5448', m: 'Slate', collide: true });
  // walls: two flanks and the back, rough stacked rock
  for (const [zc, w] of [[z0 - 3, 6], [z1 + 3, 6]]) {
    for (let k = 0; k < 3; k++) g.box({ name: 'GrottoWall', s: [D + 4 - k * 2, H / 3 + 0.1, w + 1 - k * 0.4], p: [X - D / 2 - 1 - k, (k + 0.5) * (H / 3), zc + (R() - 0.5)], r: [0, (R() - 0.5) * 4, 0], c: rockC[k % 4], m: 'Slate', collide: true });
  }
  for (let k = 0; k < 3; k++) g.box({ name: 'GrottoWall', s: [6, H / 3 + 0.1, z1 - z0 + 12], p: [X - D - 3, (k + 0.5) * (H / 3), z], c: rockC[(k + 2) % 4], m: 'Slate', collide: true });
  // inside: dark floor, puddles, stalactites, crystal clusters, glow caps
  g.box({ name: 'CaveFloor', s: [D, 0.1, z1 - z0], p: [X - D / 2, GROUND + 0.05, z], c: '#6a5e50', m: 'Slate', shadow: false });
  for (let k = 0; k < 3; k++) g.cyl({ name: 'CavePuddle', axis: 'y', len: 0.06, d: 2 + R() * 2, p: [X - 8 - R() * 24, GROUND + 0.12, z0 + 6 + R() * (z1 - z0 - 12)], c: '#5fd8e8', m: 'Glass', t: 0.25, shadow: false });
  for (let k = 0; k < 16; k++) {
    const l = 1.5 + R() * 3;
    g.wedgeF({ name: 'Stalactite', s: [1 + R(), l, 1 + R()], p: [X - 4 - R() * (D - 8), H - l / 2, z0 + 3 + R() * (z1 - z0 - 6)], r: [180, R() * 90, 0], face: 'front', c: '#6e6254', m: 'Slate' });
  }
  const crystal = (p, k, col) => {
    const c = g.at(p, [0, R() * 360, 0]);
    for (let i = 0; i < 4; i++) c.box({ name: 'Crystal', s: [0.8 * k, (2.4 + R() * 2) * k, 0.8 * k], p: [(R() - 0.5) * 1.6 * k, 1.2 * k, (R() - 0.5) * 1.6 * k], r: [(R() - 0.5) * 40, R() * 90, (R() - 0.5) * 40], c: col, m: 'Neon', t: 0.1, shadow: false });
  };
  const cols = ['#6ff3ff', '#b98cff', '#6ff3ff', '#7affc8'];
  // (against the walls and the back: the middle stays clear to drive in)
  [[X - D + 3, z0 + 6, 2], [X - D + 3, z1 - 7, 1.7], [X - D + 4, z - 2, 2.3], [X - 12, z0 + 2.5, 1.3], [X - 24, z1 - 2.5, 1.5], [X - 30, z0 + 2.5, 1.8], [X - 6, z1 - 2.5, 1.2], [X - 18, z0 + 2.5, 1]].forEach(([x, zz, k], i) => crystal([x, GROUND, zz], k + R() * 0.4, cols[i % 4]));
  // (a few hanging from the ceiling too)
  for (let k = 0; k < 5; k++) g.box({ name: 'Crystal', s: [0.9, 2.4 + R() * 2, 0.9], p: [X - 6 - R() * (D - 10), H - 1.6, z0 + 4 + R() * (z1 - z0 - 8)], r: [180 + (R() - 0.5) * 30, R() * 90, (R() - 0.5) * 30], c: cols[k % 4], m: 'Neon', t: 0.1, shadow: false });
  for (let k = 0; k < 8; k++) {
    const x = X - 3 - R() * (D - 6), zz = R() > 0.5 ? z0 + 0.7 : z1 - 0.7; // (half sunk in the wall)
    g.box({ name: 'GlowCap', s: [1.2, 0.35, 1.2], p: [x, 2 + R() * 9, zz], c: '#9cff7a', m: 'Neon', t: 0.1, shadow: false });
  }
  const glow = g.box({ name: 'GrottoGlow', s: [1, 1, 1], p: [X - D / 2, 8, z], t: 1, shadow: false });
  E.pointLight(glow, [0.45, 0.95, 1], 34, 1.1);
  // an old explorer got here first: a cold camp at the back (bedroll, crate, lantern, a journal)
  const camp = g.at([X - D + 7, GROUND, z1 - 9], [0, 70, 0]);
  E.crate(camp, [0, 0, 0], 1, { yaw: 12, stencil: '#2f6b3a' });
  camp.box({ name: 'Bedroll', s: [2.6, 0.5, 5.5], p: [-4, 0.25, 1], c: '#4f7a8a' });
  camp.box({ name: 'BedrollPillow', s: [2.2, 0.6, 1.2], p: [-4, 0.5, -1.6], c: '#d9c7a0' });
  camp.box({ name: 'Journal', s: [0.9, 0.2, 1.2], p: [0.2, 2.1, 0.1], r: [0, 25, 0], c: '#8a3a2a' });
  const lan = camp.box({ name: 'LanternGlow', s: [0.6, 0.8, 0.6], p: [1.6, 0.4, -1.4], c: PAL.lamp, m: 'Neon' });
  camp.box({ name: 'LanternCap', s: [0.8, 0.2, 0.8], p: [1.6, 0.9, -1.4], c: PAL.char });
  E.pointLight(lan, [1, 0.8, 0.5], 14, 0.8);
  for (let k = 0; k < 4; k++) camp.box({ name: 'LooseBone', s: [0.5, 0.5, 1.8 + R()], p: [-1 + R() * 6, 0.25, 4 + R() * 3], r: [0, R() * 180, 0], c: '#efe2c4' });
  // the falls: off a spout high on the cliff, in front of the grotto mouth
  const top = 52;
  const spout = g.at([X, 0, z]);
  spout.box({ name: 'Spout', s: [10, 4, 22], p: [-2, top - 2, 0], c: '#7a6c5c', m: 'Slate', studs: 'top', collide: true });
  spout.box({ name: 'SpoutMoss', s: [6, 0.6, 22.4], p: [0, top + 0.2, 0], c: PAL.moss, studs: 'top', shadow: false });
  spout.box({ name: 'SpoutWater', s: [10.4, 0.5, 16], p: [-2, top + 0.4, 0], c: PAL.water, m: 'SmoothPlastic', t: 0.2, shadow: false });
  E.waterfall(g, [X + 4.5, top + 0.5, z], 16, top, { yaw: -90, seed: 34101, name: 'SkyFallsWater', mist: 22 });
  // the plunge pool the river runs out of
  const pc = [X + 16, z];
  g.cyl({ name: 'PoolShore', axis: 'y', len: 0.2, d: 36, p: [pc[0], GROUND + 0.04, pc[1]], c: '#b9a77a', m: 'Sand', shadow: false });
  g.cyl({ name: 'PoolWater', axis: 'y', len: 0.3, d: 31, p: [pc[0], GROUND + 0.2, pc[1]], c: '#4fb8e0', m: 'Glass', t: 0.2, shadow: false }).tag('DinoWater');
  for (let k = 0; k < 14; k++) {
    const a = -1.3 + (k / 13) * 2.6; // (the cliff side has no rim: the falls land there)
    g.box({ name: 'ShoreStone', s: [2 + R() * 2, 0.9, 1.6 + R()], p: [pc[0] + Math.cos(a) * 17, GROUND + 0.3, pc[1] + Math.sin(a) * 17], r: [0, -E.deg(a), R() * 8], c: PAL.rock[k % 4], m: 'Slate' });
  }
  for (let k = 0; k < 6; k++) g.cyl({ name: 'LilyPad', axis: 'y', len: 0.1, d: 1.4 + R(), p: [pc[0] + 4 + R() * 8, GROUND + 0.38, pc[1] + (R() - 0.5) * 20], c: '#4fb043', shadow: false });
  // big wet boulders flanking the mouth (solid) - the curtain gaps either side stay wide enough for the biggest rover
  for (const [zz, k] of [[z0 - 3, 2.2], [z1 + 3, 2.6]]) E.rock(g, [X + 7, GROUND, zz], k, 34200 + Math.round(zz), { colors: rockC, name: 'MouthRock' });
  // a rainbow in the spray: six bands of a half ring standing in front of the falls (the landmark from afar)
  const bands = ['#ff4a4a', '#ff9a2a', '#ffe14a', '#5fe05a', '#4ab0ff', '#9a6bff'];
  bands.forEach((col, b) => {
    const r = 40 - b * 1.3;
    const N = 12;
    for (let k = 0; k < N; k++) {
      const a0 = 0.2 + (k / N) * (Math.PI - 0.4), a1 = 0.2 + ((k + 1) / N) * (Math.PI - 0.4);
      const P = (a) => [X + 30, GROUND + Math.sin(a) * r - 2, z - Math.cos(a) * r];
      const fade = Math.abs((k + 0.5) / N - 0.5) * 2; // (thinner toward the ends, like spray)
      g.beam(P(a0), P(a1), 1.3, 0.4, { name: 'Rainbow', c: col, m: 'Neon', t: 0.6 + fade * fade * 0.3, shadow: false, extend: 0.3, up: [1, 0, 0] });
    }
  });
  keep.push([X + 18, z, 34], [X - 10, z, 28]);
}

// vegetation keep-out circles every few studs along a polyline of [x, z]
function keepAlong(keep, P, r) {
  for (let i = 0; i < P.length - 1; i++) {
    const L = Math.hypot(P[i + 1][0] - P[i][0], P[i + 1][1] - P[i][1]);
    for (let u = 0; u <= L; u += r * 0.8) keep.push([P[i][0] + (P[i + 1][0] - P[i][0]) * u / L, P[i][1] + (P[i + 1][1] - P[i][1]) * u / L, r]);
  }
}

// a spiral of flat stepping slabs round a column (centre c, rising from y0 by `rise` per step, `turn` radians apart):
// how you climb the Elder Tree and Arch Rock on foot. Returns the angle and height of the last step.
function spiralSteps(g, c, radius, y0, n, rise, turn, a0, make) {
  let a = a0, y = y0;
  for (let k = 0; k < n; k++) {
    const r = typeof radius === 'function' ? radius(y) : radius;
    make(g.at([c[0] + Math.cos(a) * r, y, c[1] + Math.sin(a) * r], [0, -E.deg(a), 0]), k);
    if (k < n - 1) { a += turn; y += rise; }
  }
  return { a, y };
}

// THE ELDER TREE: the biggest tree in the valley, on the south hill's flat top (seen from everywhere). Shelf fungus
// spirals up its trunk to a ranger's lookout deck under the crown: the stash up there is worth the climb.
function buildElderTree(Z, R, hAt, keep) {
  const [cx, cz] = ROAM.elder;
  const base = GROUND + hAt(cx, cz);
  const g = Z.group('ElderTree');
  const t = g.at([cx, base, cz]);
  const W0 = 13, TAPER = 0.07, SEG = 6, HT = 72;
  const wAt = (y) => W0 - y * TAPER;
  for (let k = 0; k * SEG < HT; k++) {
    const y = k * SEG, w = wAt(y + SEG / 2);
    t.box({ name: 'ElderTrunk', s: [w, SEG + 0.1, w], p: [0, y + SEG / 2, 0], r: [0, k * 7, 0], c: k % 2 ? '#6b4a2b' : '#5e4026', studs: 'sides', collide: true });
    if (k % 2 === 0) t.box({ name: 'BarkRidge', s: [w + 0.6, 1, w * 0.4], p: [0, y + 1.5, 0], r: [0, k * 7 + 45, 0], c: '#4e3620' });
  }
  // buttress roots
  for (let k = 0; k < 7; k++) {
    const a = (k / 7) * Math.PI * 2 + 0.3;
    t.at([Math.cos(a) * (W0 / 2 + 2.4), 0, Math.sin(a) * (W0 / 2 + 2.4)], [0, -E.deg(a) - 90, 0]).wedgeF({ name: 'ElderRoot', s: [2.2, 6 + R() * 2, 6], p: [0, 3.2, 0], face: 'back', c: PAL.root, collide: true });
  }
  // the climb: fungus shelves round the trunk, ~2.7 up per step, close enough to hop (no step needs more than a jump)
  const DECK = 48, RISE = 2.7, TURN = 0.6;
  const n = Math.round((DECK - 2.7 - 2.7) / RISE) + 1;
  const last = spiralSteps(t, [0, 0], (y) => wAt(y) / 2 + 2.2, 2.7, n, RISE, TURN, Math.PI * 0.75, (c, k) => {
    c.box({ name: 'FungusStep', s: [5, 0.9, 4.8], p: [0, 0, 0], c: k % 2 ? '#e8d4a8' : '#f0dcb0', studs: 'top', collide: true });
    c.box({ name: 'FungusRim', s: [5.2, 0.5, 5], p: [0.2, -0.6, 0], c: '#e0883a', shadow: false });
  });
  // the deck: an octagon ring of planks under the crown, with rails; the bay over the top steps is left open
  const RIN = wAt(DECK) / 2, ROUT = RIN + 8;
  const near = (a, b, w) => Math.abs(Math.atan2(Math.sin(a - b), Math.cos(a - b))) < w;
  for (let k = 0; k < 8; k++) {
    const a = (k / 8) * Math.PI * 2;
    // the stairwell: no plank over the last two steps (head room), you hop up onto the next one along
    if (near(a, last.a, Math.PI / 8 + 0.35) || near(a, last.a - TURN, Math.PI / 8 + 0.35)) continue;
    const c = t.at([Math.cos(a) * (RIN + ROUT) / 2, DECK + (k % 2) * 0.04, Math.sin(a) * (RIN + ROUT) / 2], [0, -E.deg(a), 0]);
    c.box({ name: 'DeckPlank', s: [ROUT - RIN + 0.4, 0.8, 2 * ROUT * Math.tan(Math.PI / 8) + 0.6], p: [0, -0.4, 0], c: PAL.plank, m: 'WoodPlanks', collide: true });
    c.box({ name: 'DeckBeam', s: [ROUT - RIN, 0.9, 1], p: [0, -1.2, 0], c: PAL.woodLo });
    c.box({ name: 'DeckRail', s: [0.5, 0.5, 2 * ROUT * Math.tan(Math.PI / 8)], p: [(ROUT - RIN) / 2 - 0.3, 3, 0], c: PAL.woodLo, collide: true });
    c.box({ name: 'DeckPost', s: [0.6, 3.2, 0.6], p: [(ROUT - RIN) / 2 - 0.3, 1.6, 0], c: PAL.woodLo, studs: 'top', collide: true });
    c.box({ name: 'DeckRail', s: [0.4, 0.4, 2 * ROUT * Math.tan(Math.PI / 8)], p: [(ROUT - RIN) / 2 - 0.3, 1.6, 0], c: PAL.wood, collide: true });
  }
  // the lookout's kit: a brass telescope on the far side, a flag, a lantern, the map crate
  const opp = last.a + Math.PI;
  const lk = t.at([Math.cos(opp) * (RIN + 5), DECK, Math.sin(opp) * (RIN + 5)], [0, -E.deg(opp) - 90, 0]);
  lk.box({ name: 'ScopeLeg', s: [0.4, 3, 0.4], p: [0, 1.5, 0], c: PAL.woodLo });
  lk.cyl({ name: 'Telescope', axis: 'z', len: 4, d: 0.9, p: [0, 3.4, -1], r: [12, 0, 0], c: '#c99a3a', m: 'Metal' });
  lk.cyl({ name: 'TelescopeLens', axis: 'z', len: 0.3, d: 1.2, p: [0, 3.8, -3], r: [12, 0, 0], c: '#2b2d31', m: 'Metal' });
  E.flag(t, [Math.cos(opp + 1.2) * (ROUT - 1), DECK, Math.sin(opp + 1.2) * (ROUT - 1)], '#2f8a6a', { h: 8 });
  E.crate(t, [Math.cos(opp - 1.0) * (RIN + 4), DECK, Math.sin(opp - 1.0) * (RIN + 4)], 0.9, { yaw: 30, stencil: '#2f6b3a' });
  const lan = t.box({ name: 'LanternGlow', s: [0.6, 0.8, 0.6], p: [Math.cos(opp + 0.5) * (RIN + 1.2), DECK + 2.4, Math.sin(opp + 0.5) * (RIN + 1.2)], c: PAL.lamp, m: 'Neon' });
  E.pointLight(lan, [1, 0.82, 0.55], 18, 0.9);
  t.marker = [cx + Math.cos(opp + 0.6) * (RIN + 4.5), base + DECK, cz + Math.sin(opp + 0.6) * (RIN + 4.5)];
  // the crown: huge branches and stacked leaf banks well above the deck
  for (let k = 0; k < 6; k++) {
    const a = (k / 6) * Math.PI * 2 + R() * 0.4;
    const y0 = 56 + R() * 8, L = 16 + R() * 6;
    t.beam([0, y0, 0], [Math.cos(a) * L, y0 + 6 + R() * 4, Math.sin(a) * L], 2.4, 2.4, { name: 'ElderBranch', c: PAL.trunk[k % 2], extend: 1 });
  }
  const bank = (r0, y, n, s) => {
    for (let k = 0; k < n; k++) {
      const a = (k / n) * Math.PI * 2 + R() * 0.5;
      const sz = s * (0.8 + R() * 0.4);
      t.box({ name: 'ElderCanopy', s: [sz, sz * 0.55, sz], p: [Math.cos(a) * r0, y + (R() - 0.5) * 3, Math.sin(a) * r0], r: [0, R() * 90, 0], c: PAL.leaf[k % 5], studs: 'top' });
    }
  };
  bank(20, 64, 8, 15); bank(12, 72, 7, 16); bank(4, 80, 4, 15);
  t.box({ name: 'ElderCanopyTop', s: [12, 6, 12], p: [0, 86, 0], r: [0, 20, 0], c: PAL.leaf[4], studs: 'top' });
  for (let k = 0; k < 14; k++) { const a = R() * Math.PI * 2, r = 10 + R() * 14, vl = 4 + R() * 8; t.box({ name: 'Vine', s: [0.35, vl, 0.35], p: [Math.cos(a) * r, 60 - vl / 2, Math.sin(a) * r], c: '#3a7a2a', shadow: false }); }
  // glowing seed pods hanging under the crown: the tree lights up the hill at a distance
  for (let k = 0; k < 6; k++) {
    const a = (k / 6) * Math.PI * 2 + 0.4;
    t.box({ name: 'SeedPod', s: [1.2, 1.6, 1.2], p: [Math.cos(a) * 14, 57.5, Math.sin(a) * 14], c: '#ffd86a', m: 'Neon', t: 0.1, shadow: false });
    t.box({ name: 'PodStem', s: [0.3, 4, 0.3], p: [Math.cos(a) * 14, 60.2, Math.sin(a) * 14], c: '#3a7a2a', shadow: false }); // (up into the leaves)
  }
  // the plateau: moss, flowers, a few fallen leaves the size of tables
  for (let k = 0; k < 7; k++) { const a = R() * Math.PI * 2, r = 11 + R() * 6; E.flowers(g, [cx + Math.cos(a) * r, base, cz + Math.sin(a) * r], 35100 + k, { n: 5, spread: 3, colors: ['#ffd23a', '#ffffff', '#ff8ab0'] }); }
  keep.push([cx, cz, 26]);
  ROAM.elderDeck = t.marker;
  ROAM.elderPerch = [cx, base + 89.5, cz]; // (marker bottom = the crown's top)
}

// ARCH ROCK: a stone arch striding over the Highland Loop's climb, seen from all of Horn Meadow. A stair of
// boulders winds up its west leg; the top of the arch is a mossy ledge with a stash on it.
function buildArchRock(Z, R, hAt, keep) {
  const t = ROAM.trails.find((x) => x.id === 'HighlandLoop');
  // the arch stands where the climb is ~19 studs up
  let i = t.samples.findIndex((p) => p[1] >= 18.5);
  const f = RT.frameAt(t.samples, i);
  const p = t.samples[i];
  const yaw = E.deg(Math.atan2(-f.f[0], -f.f[2]));
  const g = Z.group('ArchRock');
  const c = g.at([p[0], 0, p[2]], [0, yaw, 0]); // local X = across the trail (local y = zone y)
  const ty = ROAD + p[1]; // trail surface
  const SPAN = 20, DEPTH = 10, THICK = 7;
  const cy = ty + 20; // the arc's centre: apex at cy + SPAN (it clears the east wall's skyline from the meadow)
  const cols = ['#d08a52', '#c07844', '#dc9c62', '#b46a3c']; // warm sandstone: nothing else in the valley is this colour
  // legs: stacked blocks from the valley floor to where the arc springs (buried in the hillside where it rises)
  for (const side of [-1, 1]) {
    const lx = side * (SPAN + 0.5);
    let y = 0, k = 0;
    while (y < cy + 6) { // (up past the arc's springing: a flat shoulder on each side)
      const h = Math.min(5 + R() * 2, cy + 6 - y);
      const w = THICK + 3 - (y / cy) * 2 + R();
      c.box({ name: 'ArchLeg', s: [w, h + 0.1, DEPTH + 2 - (y / cy) * 2], p: [lx + side * 1.2 + (R() - 0.5), y + h / 2, (R() - 0.5)], r: [0, (R() - 0.5) * 6, 0], c: cols[k % 4], m: 'Slate', studs: 'top', collide: true });
      y += h; k++;
    }
    c.box({ name: 'ArchShoulder', s: [THICK + 3.4, 1.2, DEPTH + 2.4], p: [lx + side * 1.2, cy + 6 + 0.1, 0], c: '#7a9a48', m: 'Slate', studs: 'top', collide: true });
  }
  // the arc: chunky segments round a half circle
  const N = 9;
  const P = (a) => [-Math.cos(a) * SPAN, cy + Math.sin(a) * SPAN, 0];
  for (let k = 0; k < N; k++) {
    const a0 = (k / N) * Math.PI, a1 = ((k + 1) / N) * Math.PI;
    c.beam(P(a0), P(a1), THICK, DEPTH, { name: 'ArchSpan', c: cols[k % 4], m: 'Slate', studs: 'top', collide: true, extend: 2.2, up: [0, 0, 1] });
  }
  // the ledge on top: flat, grassy, a fern or two and the stash
  const top = cy + SPAN + THICK / 2;
  c.box({ name: 'ArchLedge', s: [9, 1.2, DEPTH + 1], p: [0, top + 0.2, 0], c: '#7a9a48', m: 'Slate', studs: 'top', collide: true });
  E.fern(c, [-2.5, top + 0.8, 2.5], 1.3, 35301);
  E.fern(c, [3, top + 0.8, -2.8], 1.1, 35302);
  for (let k = 0; k < 6; k++) c.box({ name: 'Vine', s: [0.35, 3 + R() * 6, 0.35], p: [(R() - 0.5) * 14, top - 6 - R() * 3, (R() > 0.5 ? 1 : -1) * (DEPTH / 2 + 0.3)], c: '#3a7a2a', shadow: false });
  ROAM.archPerch = loc(c.wpt([0, top + 1.3, 0])); // (marker bottom = the ledge's top)
  // the boulder stair: half way round the free-standing leg (local +X: the other one grows out of the east wall),
  // never on the trail side, from the hillside up beside the shoulder; the stash waits on the shoulder's mossy top
  const lx = SPAN + 1.7;
  ROAM.archTop = loc(c.wpt([lx, cy + 6.7, 0]));
  const legW = c.wpt([lx, 0, 0]);
  const footY = GROUND + hAt(legW[0] - FV_ORIGIN[0], legW[2] - FV_ORIGIN[2]);
  const want = cy + 6.7 - 2.4; // the last boulder's top: one hop below the shoulder
  const n = Math.max(2, Math.ceil((want - footY) / 2.7));
  const rise = (want - footY) / n;
  const steps = c.at([lx, 0, 0]);
  spiralSteps(steps, [0, 0], 8.2, footY + rise - 0.6, n, rise, -3 / Math.max(1, n - 1), Math.PI * 0.5 - 0.2, (s, k) => {
    s.box({ name: 'StairBoulder', s: [6, rise + 1.4, 4.4], p: [0, -(rise + 1.4) / 2 + 0.6, 0], r: [0, (k % 3) * 9, 0], c: cols[(k + 1) % 4], m: 'Slate', studs: 'top', collide: true });
  });
  keep.push([p[0], p[2], 30]);
}

// THE RIVER TRAIL: a worn track up the river's north bank from River Bend to Sky Falls, through the HOLLOW LOG -
// a giant fallen trunk, hollow end to end, half full of earth so you drive straight through it
function buildRiverTrail(Z, R, hAt, keep) {
  const g = Z.group('RiverTrail');
  const pts = [];
  // the north bank, ~25 off the river's centre line (the log clears the water), from the road down to the falls pool
  const seg = (a, b, n) => {
    const d = [b[0] - a[0], b[1] - a[1]], L = Math.hypot(d[0], d[1]);
    const nn = [d[1] / L, -d[0] / L]; // the river's right-hand (north-east) bank, looking downstream
    for (let k = 0; k <= n; k++) pts.push([a[0] + d[0] * k / n + nn[0] * 25, a[1] + d[1] * k / n + nn[1] * 25]);
  };
  seg(RIVER_PTS[2], RIVER_PTS[1], 6);
  seg(RIVER_PTS[1], RIVER_PTS[0], 6);
  // (from the road's edge, not its middle: RiverBend runs ~60 east of here)
  pts.unshift([-224, -66], [-246, -62]);
  pts.splice(pts.length - 2); // stop at the pool's shore
  // the track: flat worn dirt decals (the river corridor is flat; nothing to climb)
  for (let k = 0; k < pts.length - 1; k++) {
    const [ax, az] = pts[k], [bx, bz] = pts[k + 1];
    if (Math.hypot(bx - ax, bz - az) < 1) continue;
    g.beam([ax, GROUND + 0.06, az], [bx, GROUND + 0.06, bz], 9, 0.08, { name: 'GameTrail', c: k % 2 ? '#a88a5a' : '#9e8052', m: 'Ground', shadow: false, extend: 4 });
  }
  // the hollow log, lying along the track halfway up
  const mid = Math.floor(pts.length / 2);
  const [ax, az] = pts[mid - 1], [bx, bz] = pts[mid + 1];
  const yaw = E.deg(Math.atan2(-(bx - ax), -(bz - az)));
  const lc = g.group('HollowLog').at([(ax + bx) / 2, GROUND, (az + bz) / 2], [0, yaw, 0]); // local Z along the log
  const RAD = 12.5, LEN = 38, CY = 11, T = 2.2;
  const staveW = 2 * (RAD + T / 2) * Math.tan(Math.PI / 8) + 0.5;
  for (let k = 0; k < 8; k++) {
    const a = (k / 8) * Math.PI * 2 + Math.PI / 8; // (no stave dead centre on the bottom: the floor fill is there)
    const x = Math.cos(a) * (RAD + T / 2), y = CY + Math.sin(a) * (RAD + T / 2);
    if (y < 1) continue;
    const sc = lc.at([x, y, 0], [0, 0, E.deg(a) - 90]);
    sc.box({ name: 'LogStave', s: [staveW, T, LEN - (k % 2) * 1.5], c: k % 2 ? PAL.trunk[0] : PAL.trunk[1], studs: 'sides', collide: true });
    // bark: raised dark ridges running the length, broken in places
    for (const [bx, b0, b1] of [[-staveW * 0.28, -LEN / 2 + 2, LEN / 2 - 9], [staveW * 0.18, -LEN / 2 + 7, LEN / 2 - 3]]) sc.box({ name: 'BarkRidge', s: [0.9, T + 0.5, b1 - b0], p: [bx + (R() - 0.5), 0, (b0 + b1) / 2], c: '#4e3620', shadow: false });
  }
  // the earth floor inside (flat, driveable), ramps at both mouths, rings of pale wood at the ends
  lc.box({ name: 'LogFloor', s: [2 * RAD * 0.92, 1.6, LEN], p: [0, 0.8, 0], c: '#6e5034', m: 'Ground', collide: true });
  for (const e of [-1, 1]) {
    lc.wedgeF({ name: 'LogRamp', s: [2 * RAD * 0.8, 1.6, 4], p: [0, 0.8, e * (LEN / 2 + 2)], face: e > 0 ? 'back' : 'front', c: '#6e5034', m: 'Ground', collide: true });
    for (let k = 0; k < 8; k++) {
      const a = (k / 8) * Math.PI * 2 + Math.PI / 8;
      const y = CY + Math.sin(a) * (RAD + T / 2);
      if (y < 1) continue;
      lc.at([Math.cos(a) * (RAD + T / 2), y, e * (LEN / 2 - 0.2)], [0, 0, E.deg(a) - 90]).box({ name: 'LogRing', s: [staveW + 0.2, T + 0.3, 0.6], c: '#d9a86a' });
    }
  }
  // moss, mushrooms, a sapling growing out of it, ferns at the mouths
  for (let k = 0; k < 6; k++) lc.box({ name: 'MossClump', s: [5 + R() * 3, 1.2, 4 + R() * 3], p: [(R() - 0.5) * 8, CY + RAD + T + 0.3, -LEN / 2 + 4 + k * (LEN - 8) / 5], c: PAL.moss, studs: 'top', shadow: false });
  for (let k = 0; k < 7; k++) lc.box({ name: 'Mushroom', s: [1.4, 0.5, 1.4], p: [(R() > 0.5 ? 1 : -1) * 16.1, CY + (R() - 0.5) * 6, (R() - 0.5) * (LEN - 6)], c: k % 2 ? '#ff7a4a' : '#ffd0a0', shadow: false });
  { // a sapling growing out of its back (part of the log, not a scatter tree: it sits on a round surface)
    const sp = lc.at([3, CY + RAD + T - 0.8, 6]);
    for (let k = 0; k < 3; k++) sp.box({ name: 'SaplingTrunk', s: [0.9, 2.6, 0.9], p: [k * 0.25, 1.3 + k * 2.4, 0], r: [0, k * 20, -k * 3], c: PAL.trunk[k % 2] });
    sp.box({ name: 'SaplingLeaves', s: [5, 2.6, 5], p: [0.8, 8.4, 0], r: [0, 20, 0], c: PAL.leaf[2], studs: 'top' });
    sp.box({ name: 'SaplingLeaves', s: [3.2, 1.8, 3.2], p: [0.4, 10.2, 0.4], r: [0, 50, 0], c: PAL.leaf[4], studs: 'top' });
  }
  // a mossy nook on top, in the sapling's shade: the stash (climb the root end)
  ROAM.logTop = loc(lc.wpt([-4, CY + RAD + T + 1.6, -8]));
  lc.box({ name: 'LogNook', s: [5, 2, 5], p: [-4, CY + RAD + T + 0.6, -8], c: '#5f8f3e', studs: 'top', collide: true });
  // the torn root end: roots splayed round the rim (the mouth itself stays open to drive through)
  for (let k = 0; k < 7; k++) {
    const a = 0.3 + (k / 6) * (Math.PI - 0.6);
    const r0 = RAD + T, ca = Math.cos(a), sa = Math.sin(a);
    lc.beam([ca * r0, CY + sa * r0, -LEN / 2 + 1], [ca * (r0 + 5 + R() * 3), CY + sa * (r0 + 4 + R() * 3), -LEN / 2 - 4 - R() * 3], 1.6, 1.6, { name: 'TornRoot', c: PAL.root, extend: 1 });
  }
  // (a climb of root ledges up its flank on the hill side (local -X, away from the river): ~3.1 up and ~3.5
  // along each, from the grass to where you can walk up onto its back)
  for (let k = 0; k < 7; k++) lc.box({ name: 'RootStep', s: [4, 1, 4], p: [-17.2 + k * 0.3, 2.6 + k * 3.15, 12 - k * 3.5], c: '#5e4a36', studs: 'top', collide: true });
  keep.push([(ax + bx) / 2, (az + bz) / 2, 34]);
  keepAlong(keep, pts, 6);
  ROAM.logCentre = loc(lc.wpt([0, 0, 0]));
}

// THE GAME TRAIL's look: a worn earth track with the herds' footprints along it, a salt lick and bones at the
// Horn Meadow end, a muddy wallow halfway (decals only: it's flat, the rover drives it and the herds walk it)
function buildGameTrail(Z, R, keep) {
  const g = Z.group('GameTrail');
  const P = ROAM.gameTrail;
  for (let i = 0; i < P.length - 1; i++) {
    const [ax, az] = P[i], [bx, bz] = P[i + 1];
    g.beam([ax, GROUND + 0.05, az], [bx, GROUND + 0.05, bz], 12, 0.08, { name: 'GameTrail', c: i % 2 ? '#a68a5c' : '#9c8054', m: 'Ground', shadow: false, extend: 6 });
    // footprints: three-toed, in pairs, every ~9 studs
    const L = Math.hypot(bx - ax, bz - az), yaw = E.deg(Math.atan2(-(bx - ax), -(bz - az)));
    for (let u = 4; u < L - 4; u += 9) {
      const side = Math.floor(u / 9) % 2 ? 1 : -1;
      const nx = -(bz - az) / L, nz = (bx - ax) / L;
      const c = g.at([ax + (bx - ax) * u / L + nx * side * 2.2, GROUND + 0.1, az + (bz - az) * u / L + nz * side * 2.2], [0, yaw + (R() - 0.5) * 16, 0]);
      c.box({ name: 'TrackHeel', s: [1.6, 0.04, 1.5], p: [0, 0, 0.6], c: '#7a5e3c', shadow: false });
      for (const a of [-28, 0, 28]) c.at([0, 0, -0.1], [0, a, 0]).box({ name: 'TrackToe', s: [0.6, 0.04, 2], p: [0, 0, -1], c: '#7a5e3c', shadow: false });
    }
  }
  // a mud wallow beside the trail in the middle of the valley
  const w = g.at([-56, GROUND + 0.08, 84]);
  w.cyl({ name: 'MudPuddle', axis: 'y', len: 0.08, d: 13, c: '#6e5034', m: 'Mud', shadow: false });
  w.cyl({ name: 'MudPuddle', axis: 'y', len: 0.1, d: 8, p: [1.5, 0.02, -1], c: '#5a4128', m: 'Glass', t: 0.15, shadow: false });
  // the salt lick at the meadow end: a pale lumpy rock the herds come to (and the bones of one that didn't leave)
  E.rock(g, [252, GROUND, 78], 1.6, 35501, { colors: ['#e8e0d0', '#d8ccb8', '#f0e8dc', '#c8bca8'], moss: false, name: 'SaltLick' });
  for (let k = 0; k < 5; k++) g.box({ name: 'Rib', s: [0.5, 3.6 - Math.abs(k - 2) * 0.5, 0.5], p: [236 + k * 1.2, GROUND + 1.4, 80], r: [0, 25, 22], c: '#efe2c4' });
  g.box({ name: 'Skull', s: [2, 1.6, 2.8], p: [231, GROUND + 0.8, 78], r: [0, 40, 12], c: '#efe2c4' });
  keepAlong(keep, P, 9);
  keep.push([-56, 84, 10], [250, 78, 8]);
}

// KICKERS: dirt jump ramps in the game trail's valley
function buildKickers(Z, hAt, keep) {
  const g = Z.group('Kickers');
  const ramp = (x, z, yawDeg, w, len, h) => {
    const c = g.at([x, GROUND + hAt(x, z), z], [0, yawDeg, 0]);
    c.wedgeF({ name: 'KickerRamp', s: [w, h, len], p: [0, h / 2, 0], face: 'front', c: '#9c7046', m: 'Ground', collide: true });
    c.box({ name: 'KickerLip', s: [w, 0.4, 1.2], p: [0, h + 0.05, len / 2 - 0.6], c: '#f2c230', studs: 'top', collide: true });
    c.box({ name: 'KickerBack', s: [w, h, 1.2], p: [0, h / 2, len / 2 - 0.6], c: '#7a5a3a', m: 'Ground', collide: true });
    for (const s of [-1, 1]) c.box({ name: 'KickerFlag', s: [0.3, 3, 0.3], p: [s * (w / 2 + 1), 1.5, len / 2 - 1], c: '#e8473a', shadow: false });
    keep.push([x, z, len]);
  };
  // (beside the game trail's flat valley, one each way, so a rover flat out along it can take them; the herds pass by)
  ramp(20, 98, 90, 12, 11, 3.4);
  ramp(108, 58, -90, 12, 11, 3.4);
}

// markers WildLife.luau reads: where a stash may be tucked (StashSpot) and where a wild dino may roam (WildSpot).
// Each part's bottom is the ground. Kept off nests, the den, the arena, the portals and the road.
function buildRoamSpots(Z, hAt) {
  const g = Z.group('RoamSpots', 'Folder');
  const spot = (name, label, x, y, z) => {
    const m = marker(g, name, [x, y + 0.5, z], 0, { s: [1, 1, 1] });
    m.set('CanTouch', 'bool', false);
    m.attr('Label', label);
    ROAM.spots = ROAM.spots || [];
    ROAM.spots.push({ name, label, p: [x, y, z] });
  };
  const gy = (x, z) => GROUND + hAt(x, z);
  const { z } = ROAM.falls;
  // stashes: tucked away, each one a climb or a find
  spot('StashSpot', 'SkyFallsGrotto', -420 - 33, GROUND, z + 9);
  spot('StashSpot', 'ElderLookout', ...ROAM.elderDeck);
  spot('StashSpot', 'ArchRockTop', ...ROAM.archTop);
  spot('StashSpot', 'HollowLogTop', ...ROAM.logTop);
  spot('StashSpot', 'LakeIslet', -151.6, GROUND + 1.4, -15.2); // (beside the islet's palm, not on its trunk)
  // wild dinos: open ground with room for a fight (34 studs), near something worth finding
  // (each one flat across ~34 studs, 95+ from the nests / den / arena, 85+ from the portals, 40+ off the road, clear
  // of the herds' paths: the search for these is in the 2026-10-14 notes)
  for (const [label, x, zz] of [['SkyFallsFlats', -366, -204], ['CanyonGlade', 152, -130], ['HighlandLookout', 316, 196], ['MeadowSouth', 308, 46]]) spot('WildSpot', label, x, gy(x, zz), zz);
}
// ambient life (EraLife.luau): herd paths [species, count, points...] and where the pterosaurs perch / wheel
function buildLifePaths(Z, hAt, segs) {
  const g = Z.group('LifePaths', 'Folder');
  for (const path of LIFE.paths) {
    const pts = path.pts.map(([x, z]) => [x + FV_ORIGIN[0], +(GROUND + hAt(x, z) + FV_ORIGIN[1]).toFixed(2), z + FV_ORIGIN[2]]);
    const m = marker(g, 'LifePath', [path.pts[0][0], GROUND + hAt(path.pts[0][0], path.pts[0][1]) + 0.5, path.pts[0][1]]);
    m.set('CanTouch', 'bool', false);
    m.attr('Species', path.species).attr('Count', path.count).attr('Loop', !!path.loop).attr('Speed', path.speed || 4);
    m.attr('Points', pts.map((p) => p.map((v) => +v.toFixed(1)).join(',')).join(';'));
  }
  const perch = (name, p, o = {}) => {
    const m = marker(g, name, p);
    m.set('CanTouch', 'bool', false);
    for (const [k, v] of Object.entries(o)) m.attr(k, v);
  };
  perch('LifePerch', ROAM.elderPerch, { Count: 5, Spook: 60, Radius: 30 }); // (climbing to the deck sends them up)
  perch('LifePerch', ROAM.archPerch, { Count: 3, Spook: 46 }); // (driving under the arch does too)
  perch('LifeSky', [-392, 78, ROAM.falls.z], { Count: 4, Radius: 46 });
  perch('LifeSky', [120, 96, -220], { Count: 3, Radius: 60 }); // over Rock Canyon
  perch('LifeSky', [10, 120, 90], { Count: 3, Radius: 90 }); // high over the middle of the valley
}

// safety rails for free roam: invisible walls along the cliff tops. Climb a cliff or drive up a hill onto one and
// you're stopped before the far side (beyond it there's only a drop into nothing). They start well above the valley
// floor, so nothing down in the valley ever touches them.
function buildBarrier(Z) {
  E.roamBarrier(Z, -420, 420, -300, 400, { out: 18, y0: 26, h: 300 });
}

// ------------------------------------------------------------------ Luau data
function routeData(route, at) {
  const O = FV_ORIGIN;
  const V = route.variants;
  const segS = (v, segId, s) => { const k = v.segs.indexOf(segId); return k < 0 ? null : v.segStart[k] + s; };
  const variants = V.map((v) => {
    const flat = [];
    for (const p of v.pts) flat.push(+(p[0] + O[0]).toFixed(2), +(p[1] + ROAD).toFixed(2), +(p[2] + O[2]).toFixed(2));
    const widths = v.segs.map((id, k) => [+v.segStart[k].toFixed(1), route.segs[id].width / 2]);
    return { Choices: v.choices.map((c) => c + 1), Length: +v.length.toFixed(1), Step: RT.STEP, Points: flat, HalfWidths: widths };
  });
  // fork S (same on every variant that reaches it) + labels left/right
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
  const arrival = at('FernRoad', 4);
  return {
    Zone: 'FernValley', Name: 'FERN VALLEY', Era: '68,000,000 BC', Year: -68000000,
    Variants: variants, Forks: forks, Features: features, Sections: sections, Nests: nests,
    Arrival: [arrival.p[0] + O[0], ROAD, arrival.p[2] + O[2], arrival.f[0], arrival.f[2]],
    Lighting: { ClockTime: 9.2, Ambient: [0.55, 0.62, 0.5], FogColor: [0.72, 0.84, 0.74], Haze: 1.6, Density: 0.36, Tint: [0.98, 1.0, 0.94] },
  };
}

module.exports = { buildFernValley, FV_ORIGIN, DEBUG, ROAM, LIFE };
