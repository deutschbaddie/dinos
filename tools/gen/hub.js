// BASE CAMP — the shared hub and the players' islands (2026-10-12: v2, "Base Camp Islands").
// Pre-beta testers said the ring of plots felt cramped and mashed up, so every player now gets their own ISLAND in a
// lagoon, joined to the hub by a drivable bridge. All positions come from islandLayout.js (the mockup draws from
// it too).
//
// Layout (hub-local, origin = plaza centre, north = -Z):
//   r   0..54   plaza: hologram egg (centre), HQ tower (south), Motor Pool (east), Hatch Stage (west), leaderboards (north)
//   r  54..85   lawn ring: walkways from the plaza out to each bridge, lamps, flowerbeds
//   r  85..103  ring road (dirt): every bridge starts on it
//   r 103..128  hub lawn + beach; the Time Gate stands on a stone pier off the north tip (deck z -128..-184)
//   r 280..520  eight player ISLANDS (wedges) on an arc that leaves the north open; bridges from r 98
//   north       the MAINLAND behind the gate: cliffs, two waterfalls, the ridge Brachiosaurus
//   rim         a ring of crater cliffs around the lagoon (the volcano on the north-east corner) hides where the
//               water ends and keeps Fern Valley / Giant Plains / Red Cliffs out of sight
const { Inst, Ctx, CF, shade, mix, rng, styledText } = require('./builder.js');
const E = require('./env.js');
const NPC = require('./npcs.js');
const IL = require('./islandLayout.js');
const { PAL } = E;

const HUB_ORIGIN = [600, 0, 0];
const PLOT_COUNT = IL.ISLANDS;
const PADDOCK_W = 120, PADDOCK_D = 110; // the paddock on each island (big dinos are rare, but they need room)
const ACCENTS = ['#e8473a', '#f08a24', '#f2c230', '#7cc242', '#2fbfa8', '#3d8be8', '#9a5ce6', '#e85aa8'];
const ACCENT_NAMES = ['RED', 'ORANGE', 'YELLOW', 'LIME', 'TEAL', 'BLUE', 'PURPLE', 'PINK'];
const plotAngle = IL.islandAngle; // degrees clockwise from north (the plaza spokes and lamps point down each bridge)
const dirOf = IL.dirOf;
const Y = { ground: 0.5, road: 0.72, lawn: 0.86, plaza: 1.25, plot: 1.0, deck: 6.2, water: IL.WATER_Y, bed: IL.SEABED_Y };
const GATE = { z: -162, deckZ0: -128, deckZ1: -184, R: 19, beam: 4 };

function marker(ctx, name, p, yaw = 0, o = {}) {
  const m = ctx.box({ name, s: o.s || [1, 1, 1], p, r: [0, yaw, 0], t: 1, shadow: false, c: '#ffffff' });
  m.set('CanQuery', 'bool', false);
  return m;
}
function surfaceLabel(part, face, text, o = {}) {
  const FACES = { Right: 0, Top: 1, Back: 2, Left: 3, Bottom: 4, Front: 5 };
  const sg = new Inst('SurfaceGui', o.name || 'Label');
  sg.set('Face', 'token', FACES[face]).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', o.pps || 40).set('LightInfluence', 'float', o.light || 0);
  sg.add(styledText(text, Object.assign({ name: 'Text', size: o.size || [0.92, 0, 0.7, 0], pos: o.pos || [0.04, 0, 0.15, 0], strokeT: 3, shadow: 4, align: 'Center' }, o)));
  part.add(sg);
  return sg;
}
function billboardText(host, name, text, o = {}) {
  const g = new Inst('BillboardGui', name);
  g.set('Size', 'UDim2', [o.w || 10, 0, o.h || 2.4, 0]);
  if (o.offset) g.set('StudsOffset', 'Vector3', o.offset);
  g.set('LightInfluence', 'float', 0).set('MaxDistance', 'float', o.maxDist || 120).set('AlwaysOnTop', 'bool', !!o.top);
  g.add(styledText(text, { name: 'Text', size: [1, 0, 1, 0], color: o.color || '#fff4d6', color2: o.color2, strokeT: o.strokeT || 3, shadow: 3, align: 'Center' }));
  host.add(g);
  return g;
}

// A stone statue of a real dino rig: every part of the (posed) model rebuilt as plain anchored stone, eyes glowing.
const STATUE_SRC = { TyrannosaurusRex: './dinos/trex.js', Velociraptor: './dinos/velociraptor.js' };
function dinoStatue(ctx, species, p, yaw, k, pose = {}) {
  const Bd = require('./builder.js');
  const rig = require(STATUE_SRC[species]).build();
  const D = (x, y, z) => CF.deg(x, y, z);
  const P = {};
  for (const [n, r] of Object.entries(pose)) P[n] = D(...r);
  const c = ctx.group('Statue_' + species).at(p, [0, yaw, 0]);
  const stone = ['#8a8274', '#a39a88', '#b8ae9a', '#cbc2ae'];
  for (const pp of Bd.previewParts(rig, P)) {
    if (pp.t >= 1) continue;
    const [x, y, z, ...r] = pp.cf;
    const hex = pp.c.replace('#', '');
    const lum = (parseInt(hex.slice(0, 2), 16) * 0.3 + parseInt(hex.slice(2, 4), 16) * 0.59 + parseInt(hex.slice(4, 6), 16) * 0.11) / 255;
    const eye = /Eye|Pupil/.test(pp.n) && !/Lid|Brow|Socket/.test(pp.n);
    const o = { name: 'Stone' + pp.n, s: pp.s.map((v) => v * k), c: eye ? '#4a9bff' : stone[Math.min(3, Math.floor(lum * 4.4))], m: eye ? 'Neon' : 'Slate' };
    if (pp.k === 'wedge') o.cls = 'WedgePart';
    else if (pp.k === 'cyl') o.shape = 'Cylinder';
    else if (pp.k === 'ball') o.shape = 'Ball';
    else if (pp.k === 'ellipsoid') o.mesh = 'sphere';
    const part = c._add(new CF(x * k, y * k, z * k, r), o);
    if (eye) part.tag('GateEraTint');
  }
  return c;
}

// ============================================================== PLAZA
function buildPlaza(H) {
  const P = H.group('Plaza');
  const ground = P.group('Ground', 'Folder');
  ground.cyl({ name: 'PlazaStep', axis: 'y', len: 0.5, d: 113, p: [0, Y.plaza - 0.35, 0], c: '#8a8478', m: 'Slate', collide: true });
  ground.cyl({ name: 'PlazaFloor', axis: 'y', len: 0.5, d: 108, p: [0, Y.plaza - 0.25, 0], c: '#d9c9a4', m: 'Slate', collide: true });
  ground.cyl({ name: 'PlazaCore', axis: 'y', len: 0.08, d: 30, p: [0, Y.plaza + 0.0, 0], c: '#b59a70', m: 'Slate' }); // top = plaza + 0.04
  // mosaic tile rings so the plaza reads as laid stone, not a flat disc
  {
    const T = rng(77);
    const tones = ['#d2c19a', '#c8b68e', '#dccfae', '#bfae86'];
    for (const [r, n, w] of [[41.5, 44, 5.4], [48.5, 52, 5.4], [22, 26, 4.6], [28, 32, 4.6]]) {
      for (let k = 0; k < n; k++) {
        const a = (k / n) * 360 + (r % 7);
        const [dx, dz] = dirOf(a);
        const len = (2 * Math.PI * r) / n - 0.35;
        // alternate tiles sit at two heights so their overlapping corners never share a plane (no flicker)
        P.at([dx * r, Y.plaza + (k % 2 ? 0.07 : 0.1), dz * r], [0, 180 - a, 0]).box({ name: 'Tile', s: [len, 0.06, w], c: tones[Math.floor(T() * 4)], m: 'Slate', shadow: false });
      }
    }
  }
  // compass spokes: one accent stripe pointing at each plot, a gold one at the Time Gate
  for (let i = 0; i < PLOT_COUNT; i++) {
    const a = plotAngle(i), [dx, dz] = dirOf(a);
    const r0 = 16, r1 = 53;
    P.beam([dx * r0, Y.plaza + 0.16, dz * r0], [dx * r1, Y.plaza + 0.16, dz * r1], 1.6, 0.06, { name: 'PlotSpoke', c: ACCENTS[i], shadow: false });
    P.at([dx * 47, Y.plaza + 0.2, dz * 47], [0, 180 - a, 0]).box({ name: 'SpokeArrow', s: [2.6, 0.06, 2.6], r: [0, 45, 0], c: ACCENTS[i], shadow: false });
  }
  P.beam([0, Y.plaza + 0.16, -16], [0, Y.plaza + 0.16, -53], 2.2, 0.06, { name: 'GateSpoke', c: PAL.amber, m: 'Neon', shadow: false });
  // edge stones + planters around the rim (gaps at every walkway)
  const R = rng(101);
  const gaps = [0, ...Array.from({ length: PLOT_COUNT }, (_, i) => plotAngle(i)), 180];
  for (let k = 0; k < 96; k++) {
    const a = (k / 96) * 360;
    if (gaps.some((g) => Math.abs(((a - g + 540) % 360) - 180) < 5.5)) continue;
    const [dx, dz] = dirOf(a);
    const s = 1.1 + R() * 0.5;
    P.at([dx * 55.2, Y.plaza - 0.2, dz * 55.2], [0, 180 - a, 0]).box({ name: 'RimStone', s: [3.4, s, 1.6], p: [0, s / 2, 0], c: k % 3 ? '#8a8478' : '#7a746a', m: 'Slate', studs: 'top', collide: true });
  }
  for (let i = 0; i < PLOT_COUNT; i++) {
    for (const off of [-16, 16]) {
      const a = plotAngle(i) + off;
      const [dx, dz] = dirOf(a);
      if (Math.abs(a - 180) < 20 || Math.abs(a - 103) < 12 || Math.abs(a - 257) < 12 || Math.abs(Math.abs(((a + 180) % 360) - 180) - 25.5) < 9) continue;
      planter(P, [dx * 49, Y.plaza, dz * 49], 180 - a, 700 + i * 7 + off);
    }
  }
  buildFountain(P);
  buildShadeTrees(P);
  buildHologram(P);
  buildHQ(P);
  buildCampCrew(P);
  buildMotorPool(P);
  buildHatchStage(P);
  buildLeaderboards(P);
  // benches + lamps around the hologram
  for (let k = 0; k < 6; k++) {
    const a = 30 + k * 60;
    const [dx, dz] = dirOf(a);
    if (Math.abs(a - 180) < 1) continue;
    bench(P, [dx * 22, Y.plaza, dz * 22], 180 - a);
    E.lampPost(P, [dx * 26, Y.plaza, dz * 26], { yaw: -a, h: 7 });
  }
  return P;
}

// the fountain around the hologram: a stone basin, six dino-head spouts arcing water at the projector
function buildFountain(P) {
  const g = P.group('Fountain');
  const c = g.at([0, Y.plaza, 0]);
  const R = rng(4040);
  c.cyl({ name: 'BasinFloor', axis: 'y', len: 0.3, d: 30, p: [0, 0.15, 0], c: '#6a7a80', m: 'Slate', collide: true });
  c.cyl({ name: 'BasinWater', axis: 'y', len: 0.2, d: 28.6, p: [0, 0.62, 0], c: '#5fc8f0', m: 'Glass', t: 0.25, shadow: false });
  for (let k = 0; k < 32; k++) {
    const a = (k / 32) * 360;
    const [dx, dz] = dirOf(a);
    c.at([dx * 14.8, 0, dz * 14.8], [0, 180 - a, 0]).box({ name: 'BasinRim', s: [3.1, 1.3, 1.6], p: [0, 0.65, 0], c: k % 2 ? '#c8bea6' : '#b8ad94', m: 'Slate', studs: 'top', collide: true });
  }
  for (let k = 0; k < 6; k++) {
    const a = k * 60 + 30;
    const [dx, dz] = dirOf(a);
    // spout: a little carved raptor head on a post, mouth toward the projector
    const sp = c.at([dx * 15.6, 0, dz * 15.6], [0, 180 - a, 0]);
    sp.box({ name: 'SpoutPost', s: [2, 3, 2], p: [0, 1.5, 0.4], c: '#a89c82', m: 'Slate', studs: 'top', collide: true });
    sp.box({ name: 'SpoutHead', s: [1.6, 1.4, 2.4], p: [0, 3.5, -0.4], c: '#b8ad94', m: 'Slate' });
    sp.box({ name: 'SpoutSnout', s: [1.1, 0.8, 1.4], p: [0, 3.2, -1.9], c: '#c8bea6', m: 'Slate' });
    sp.sym((q) => q.box({ name: 'SpoutEye', s: [0.2, 0.3, 0.3], p: [0.82, 3.8, -0.6], c: '#3fe0ff', m: 'Neon' }));
    const jet = sp.at([0, 3.2, -2.6], [40, 0, 0]).box({ name: 'Jet', s: [0.4, 0.4, 0.4], t: 1, shadow: false });
    jet.set('CanQuery', 'bool', false);
    E.particles(jet, 'Water', { rate: 40, life: [0.55, 0.7], speed: [13, 15], dir: 5, spread: [3, 3], size: [[0, 0.5], [1, 0.25]], transp: [[0, 0.2], [1, 0.7]], color: [0.75, 0.93, 1], emission: 0.3, accel: [0, -42, 0] });
  }
  for (let k = 0; k < 5; k++) c.cyl({ name: 'LilyPad', axis: 'y', len: 0.1, d: 1.2 + R() * 0.6, p: [(R() > 0.5 ? 1 : -1) * (10 + R() * 3), 0.74, (R() - 0.5) * 18], c: '#4fb043', shadow: false });
}

// four big shade trees in round stone planters, with seats around them
function buildShadeTrees(P) {
  const g = P.group('ShadeTrees');
  const R = rng(5050);
  // the plaza's outer paving ring between the tree planters
  const tones = ['#c4b38c', '#b8a780', '#cdbd96'];
  for (let k = 0; k < 40; k++) {
    const a = (k / 40) * 360 + 4;
    const [dx, dz] = dirOf(a);
    g.at([dx * 35, Y.plaza + (k % 2 ? 0.07 : 0.1), dz * 35], [0, 180 - a, 0]).box({ name: 'Tile', s: [(2 * Math.PI * 35) / 40 - 0.35, 0.06, 4.2], c: tones[Math.floor(R() * 3)], m: 'Slate', shadow: false });
    if (R() > 0.7) E.grassTufts(g, [dx * 37.4, Y.plaza + 0.1, dz * 37.4], 5100 + k, { n: 3, spread: 1, scale: 0.6 });
  }
  for (const a of [64, 128, 232, 296]) {
    const [dx, dz] = dirOf(a);
    const c = g.at([dx * 38, Y.plaza, dz * 38]);
    c.cyl({ name: 'TreePlanter', axis: 'y', len: 1.6, d: 9, p: [0, 0.8, 0], c: '#8a8478', m: 'Slate', collide: true });
    c.cyl({ name: 'TreePlanterRim', axis: 'y', len: 0.4, d: 9.6, p: [0, 1.7, 0], c: '#a89c82', m: 'Slate' });
    c.cyl({ name: 'TreeSoil', axis: 'y', len: 0.2, d: 8, p: [0, 1.75, 0], c: PAL.mud });
    E.jungleTree(c, [0, 1.8, 0], 17 + R() * 4, 5200 + a, { canopy: 8 });
    E.flowers(c, [0, 1.85, 0], 5300 + a, { n: 6, spread: 6 });
    for (let k = 0; k < 3; k++) {
      const b = (k / 3) * 360 + a + 60;
      const [bx, bz] = dirOf(b);
      const wx = dx * 38 + bx * 7, wz = dz * 38 + bz * 7;
      // keep clear of the daily chest, the Professor and the plaza buildings
      if ([[-15, 27, 9], [3, 29, 9], [0, 41, 12], [-36, 8.3, 16], [36, 8.3, 16]].some(([x, z, r]) => Math.hypot(wx - x, wz - z) < r)) continue;
      bench(c, [bx * 7, 0, bz * 7], 180 - b);
    }
  }
}

function planter(ctx, p, yaw, seed) {
  const c = ctx.at(p, [0, yaw, 0]);
  c.box({ name: 'Planter', s: [7, 1.4, 3], p: [0, 0.7, 0], c: '#8a8478', m: 'Slate', studs: 'top', collide: true });
  c.box({ name: 'PlanterSoil', s: [6.4, 0.2, 2.4], p: [0, 1.42, 0], c: PAL.mud });
  E.flowers(c, [0, 1.5, 0], seed, { n: 8, spread: 5 });
  E.fern(c, [2.2, 1.5, 0], 0.8, seed + 1);
  E.fern(c, [-2.2, 1.5, 0], 0.8, seed + 2);
}
function bench(ctx, p, yaw) {
  const c = ctx.at(p, [0, yaw, 0]);
  c.box({ name: 'BenchSeat', s: [5, 0.4, 1.6], p: [0, 1.5, 0], c: PAL.wood, m: 'WoodPlanks', collide: true });
  c.box({ name: 'BenchBack', s: [5, 1.4, 0.35], p: [0, 2.4, 0.75], r: [-8, 0, 0], c: PAL.wood, m: 'WoodPlanks' });
  for (const x of [-2, 2]) c.box({ name: 'BenchLeg', s: [0.5, 1.3, 1.4], p: [x, 0.65, 0], c: '#5d5a55', m: 'Slate', collide: true });
}

function buildHologram(P) {
  const g = P.group('HologramEgg');
  const c = g.at([0, Y.plaza, 0]);
  c.cyl({ name: 'HoloBase', axis: 'y', len: 1.0, d: 17, p: [0, 0.5, 0], c: '#3a3d42', m: 'Metal', collide: true });
  c.cyl({ name: 'HoloBaseTrim', axis: 'y', len: 0.25, d: 17.6, p: [0, 1.0, 0], c: PAL.amber, m: 'Metal' });
  c.cyl({ name: 'HoloStep', axis: 'y', len: 0.8, d: 12, p: [0, 1.4, 0], c: '#2b2d31', m: 'Metal', collide: true });
  c.cyl({ name: 'ProjectorRing', axis: 'y', len: 0.2, d: 10, p: [0, 1.9, 0], c: '#3fe0ff', m: 'Neon' });
  c.cyl({ name: 'ProjectorLens', axis: 'y', len: 0.25, d: 7, p: [0, 1.92, 0], c: '#1a3a48', m: 'Glass' });
  for (let k = 0; k < 6; k++) {
    const a = (k / 6) * Math.PI * 2;
    const pc = c.at([Math.cos(a) * 7.6, 0, Math.sin(a) * 7.6], [0, -E.deg(a), 0]);
    pc.box({ name: 'Emitter', s: [1.2, 3.2, 1.2], p: [0, 2.6, 0], c: '#2b2d31', studs: 'top' });
    pc.box({ name: 'EmitterLight', s: [0.4, 0.4, 1.3], p: [0, 3.9, 0], c: '#3fe0ff', m: 'Neon' });
  }
  const beamCol = c.cyl({ name: 'HoloBeam', axis: 'y', len: 16, d: 9, p: [0, 10, 0], c: '#3fe0ff', m: 'Neon', t: 0.9, shadow: false });
  beamCol.tag('HoloBeam');
  const anchor = marker(c, 'HologramAnchor', [0, 9.5, 0]);
  E.pointLight(anchor, [0.25, 0.88, 1], 26, 1.6);
  E.particles(anchor, 'HoloMotes', { rate: 8, life: [1.5, 2.5], speed: [0.6, 1.4], size: [[0, 0.3], [1, 0]], color: [0.3, 0.9, 1], dir: 1, spread: [25, 25] });
  billboardText(anchor, 'HoloTitle', 'NEXT DISCOVERY', { w: 18, h: 2.4, offset: [0, 7.5, 0], color: '#b9f6ff', color2: '#3fe0ff', maxDist: 200 });
  billboardText(anchor, 'HoloName', '???', { w: 16, h: 2.2, offset: [0, 5.5, 0], color: '#ffffff', maxDist: 200 });
}

function buildHQ(P) {
  // Research HQ on the south edge, door facing the hologram and the gate beyond it.
  // Narrow + tall so the walkways to the south plots stay clear on both sides.
  const g = P.group('HQTower');
  const c = g.at([0, Y.plaza, 41]);
  const W = 18, D = 14;
  const wall = '#e9dfc4', wallLo = '#cfc3a4', green = '#2f6b3a', greenHi = '#3d8249', yellow = '#f2b632', glass = '#9cf0ff';
  c.box({ name: 'Foundation', s: [W + 2, 1.2, D + 2], p: [0, 0.6, 0], c: '#7a746a', m: 'Slate', studs: 'top', collide: true });
  c.box({ name: 'Steps', s: [8, 0.6, 2.2], p: [0, 0.3, -D / 2 - 2], c: '#8a8478', m: 'Slate', collide: true });
  const F1 = 1.2, h1 = 9;
  c.box({ name: 'BackWall', s: [W, h1, 1], p: [0, F1 + h1 / 2, D / 2 - 0.5], c: wall, studs: 'sides', collide: true });
  c.sym((s) => {
    s.box({ name: 'SideWall', s: [1, h1, D], p: [W / 2 - 0.5, F1 + h1 / 2, 0], c: wall, studs: 'sides', collide: true });
    s.box({ name: 'FrontWall', s: [6, h1, 1], p: [6, F1 + h1 / 2, -D / 2 + 0.5], c: wall, studs: 'sides', collide: true });
    s.box({ name: 'Window', s: [3.4, 3.4, 0.2], p: [6, F1 + 5, -D / 2 - 0.02], c: glass, m: 'Glass', t: 0.3 });
    s.box({ name: 'WindowFrame', s: [4, 0.4, 0.5], p: [6, F1 + 3.1, -D / 2 - 0.1], c: green });
    s.box({ name: 'WindowFrame', s: [4, 0.4, 0.5], p: [6, F1 + 6.9, -D / 2 - 0.1], c: green });
    s.box({ name: 'SideWindow', s: [0.2, 3.4, 4], p: [W / 2 + 0.02, F1 + 5, 0], c: glass, m: 'Neon', t: 0.25 });
    for (const z of [-D / 2, D / 2]) s.box({ name: 'CornerPost', s: [1.6, h1 + 9.6, 1.6], p: [W / 2, F1 + (h1 + 9.6) / 2, z], c: green, studs: 'top', collide: true });
  });
  c.box({ name: 'DoorHeader', s: [6, 2.4, 1], p: [0, F1 + h1 - 1.2, -D / 2 + 0.5], c: wall, collide: true });
  c.box({ name: 'Doorway', s: [6, h1 - 2.4, 0.6], p: [0, F1 + (h1 - 2.4) / 2, -D / 2 + 1.4], c: '#20242a', collide: true }); // solid: nobody walks into the HQ
  c.box({ name: 'Awning', s: [9, 0.4, 3.4], p: [0, F1 + h1 - 0.4, -D / 2 - 1.4], r: [-10, 0, 0], c: yellow, studs: 'top' });
  for (let i = 0; i < 4; i++) c.box({ name: 'AwningStripe', s: [1, 0.42, 3.42], p: [-3 + i * 2, F1 + h1 - 0.38, -D / 2 - 1.4], r: [-10, 0, 0], c: '#ffffff', shadow: false });
  // second storey with a wraparound balcony
  const F2 = F1 + h1, h2 = 8;
  c.box({ name: 'FloorSlab', s: [W + 4, 0.8, D + 4], p: [0, F2 + 0.4, 0], c: '#5d5a55', m: 'Slate', studs: 'top', collide: true });
  c.box({ name: 'Upper', s: [W - 2, h2, D - 2], p: [0, F2 + 0.8 + h2 / 2, 0.5], c: wallLo, studs: 'sides', collide: true });
  for (const x of [-4.5, 4.5]) c.box({ name: 'UpperWindow', s: [5, 3, 0.2], p: [x, F2 + 4.6, -D / 2 + 1.4], c: glass, m: 'Neon', t: 0.25 });
  for (let i = 0; i <= 10; i++) c.box({ name: 'Baluster', s: [0.3, 1.6, 0.3], p: [-W / 2 - 1.5 + i * ((W + 3) / 10), F2 + 1.6, -D / 2 - 1.6], c: green });
  c.box({ name: 'Handrail', s: [W + 3.6, 0.4, 0.5], p: [0, F2 + 2.5, -D / 2 - 1.6], c: greenHi, studs: 'top' });
  // third storey: the lookout, carrying the BASE CAMP sign
  const F3 = F2 + 0.8 + h2;
  c.box({ name: 'Roof', s: [W, 1, D], p: [0, F3 + 0.5, 0.5], c: green, studs: 'top', collide: true });
  c.box({ name: 'RoofTrim', s: [W + 0.6, 0.4, D + 0.6], p: [0, F3 + 0.1, 0.5], c: yellow });
  c.box({ name: 'Lookout', s: [10, 6, 8], p: [0, F3 + 4, 2], c: wall, studs: 'sides', collide: true });
  c.box({ name: 'LookoutWindow', s: [8, 2.4, 0.2], p: [0, F3 + 4.6, -2.02], c: glass, m: 'Neon', t: 0.25 });
  c.box({ name: 'LookoutRoof', s: [12, 0.8, 10], p: [0, F3 + 7.4, 2], c: green, studs: 'top' });
  const sign = c.box({ name: 'HQSign', s: [17, 3.6, 0.6], p: [0, F2 + 6.2, -D / 2 + 1.05], c: '#2a2c31' });
  c.box({ name: 'HQSignFrame', s: [17.8, 4.4, 0.4], p: [0, F2 + 6.2, -D / 2 + 1.4], c: yellow });
  surfaceLabel(sign, 'Front', 'BASE CAMP', { pps: 30, color: '#fff4d6', color2: '#ffb02e', strokeT: 4, shadow: 5 });
  // radio mast, dish, beacon
  for (let i = 0; i < 8; i++) c.box({ name: 'MastSegment', s: [1.2 - i * 0.08, 2.1, 1.2 - i * 0.08], p: [-7.6, F3 + 2.05 + i * 2.1, 4.5], r: [0, i * 15, 0], c: i % 2 ? '#d9d9d9' : '#e8473a', m: 'Metal' });
  const beacon = c.box({ name: 'Beacon', s: [1, 1, 1], p: [-7.6, F3 + 19.3, 4.5], c: '#ff3b2a', m: 'Neon' });
  beacon.tag('BlinkLight');
  E.pointLight(beacon, [1, 0.25, 0.2], 18, 2);
  const dish = c.at([7.4, F3 + 11.2, 4.4], [-30, 25, 0]);
  dish.cyl({ name: 'Dish', axis: 'z', len: 0.5, d: 6, c: '#e9eef2', m: 'Metal' });
  dish.cyl({ name: 'DishRim', axis: 'z', len: 0.7, d: 6.4, p: [0, 0, 0.1], c: '#b8bec4', m: 'Metal' });
  dish.box({ name: 'DishHorn', s: [0.4, 0.4, 2.6], p: [0, 0, -1.4], c: '#2b2d31' });
  c.box({ name: 'DishPylon', s: [1.0, 9.2, 1.0], p: [7.4, F3 + 5.6, 5.4], c: '#5d5a55', m: 'Metal' });
  c.box({ name: 'DishMount', s: [1.6, 0.8, 1.6], p: [7.4, F3 + 10.4, 5.4], c: '#3a3d42', m: 'Metal' });
  E.flag(c, [-9.5, F1, -D / 2 - 3], '#3d8249', { h: 9 });
  E.flag(c, [9.5, F1, -D / 2 - 3], '#f2b632', { h: 9 });
  E.crate(c, [-6.5, F1, -D / 2 - 3.2], 1, { yaw: 12, stencil: '#2f6b3a' });
  E.crate(c, [-6.5, F1 + 2, -D / 2 - 3.2], 0.8, { yaw: -8 });
  E.barrel(c, [6.5, F1, -D / 2 - 3.2], { color: '#2f6b3a' });
  c.cyl({ name: 'SpawnPad', axis: 'y', len: 0.2, d: 10, p: [0, 0.12, -D / 2 - 9.5], c: '#f2b632', m: 'Neon', t: 0.4, shadow: false });
  const sp = new Inst('SpawnLocation', 'CampSpawn');
  sp.set('Anchored', 'bool', true).set('CanCollide', 'bool', false).set('CanQuery', 'bool', false).set('Transparency', 'float', 1);
  sp.set('size', 'Vector3', [8, 1, 8]).set('Duration', 'int', 0).set('Neutral', 'bool', true);
  sp._cf = c.world(new CF(0, 0.6, -D / 2 - 9.5));
  sp.set('CFrame', 'CFrame', sp._cf);
  g.parent.add(sp);
  marker(c, 'CampArrival', [0, 3, -D / 2 - 9.5], 0);
}

function buildCampCrew(P) {
  // the Professor waits on the HQ steps; the daily chest sits beside him
  const g = P.group('CampCrew');
  NPC.buildNpc(g.parent, g.world(new CF(3, Y.plaza, 29)), 'Professor');
  const ch = g.group('DailyChest');
  ch.parent.tag('DailyChest');
  const c = ch.at([-15, Y.plaza, 27], [0, 0, 0]);
  c.box({ name: 'ChestPlinth', s: [6, 0.6, 4.6], p: [0, 0.3, 0], c: '#8a8478', m: 'Slate', studs: 'top', collide: true });
  c.box({ name: 'ChestBase', s: [4.2, 2, 2.8], p: [0, 1.6, 0], c: '#8a5a33', m: 'WoodPlanks', collide: true });
  for (const x of [-1.7, 1.7]) c.box({ name: 'ChestBand', s: [0.4, 2.06, 2.86], p: [x, 1.6, 0], c: '#ffc21f', m: 'Metal' });
  c.box({ name: 'ChestLock', s: [0.8, 0.9, 0.2], p: [0, 2.2, -1.45], c: '#ffc21f', m: 'Metal' });
  // the lid is its own model so the client can swing it open (hinge at the back edge)
  const lid = ch.group('ChestLid');
  const lc = lid.at([-15, Y.plaza + 2.6, 28.4]);
  lc.box({ name: 'LidHinge', s: [0.2, 0.2, 0.2], p: [0, 0, 0], t: 1, shadow: false });
  lc.box({ name: 'LidTop', s: [4.2, 1, 2.8], p: [0, 0.5, -1.4], c: '#9a6a3c', m: 'WoodPlanks', studs: 'top' });
  for (const x of [-1.7, 1.7]) lc.box({ name: 'LidBand', s: [0.4, 1.06, 2.86], p: [x, 0.5, -1.4], c: '#ffc21f', m: 'Metal' });
  const glow = c.box({ name: 'ChestGlow', s: [3.6, 0.2, 2.2], p: [0, 2.55, 0], c: '#ffe9a0', m: 'Neon', t: 0.4, shadow: false });
  E.pointLight(glow, [1, 0.85, 0.5], 12, 0.7);
  const host = c.box({ name: 'ChestPromptHost', s: [0.4, 0.4, 0.4], p: [0, 2, -2], t: 1, shadow: false });
  const pr = new Inst('ProximityPrompt', 'ChestPrompt');
  pr.set('ActionText', 'string', 'Open').set('ObjectText', 'string', 'Daily Chest').set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 10).set('HoldDuration', 'float', 0.3).set('RequiresLineOfSight', 'bool', false);
  pr.attr('CampAction', 'Chest');
  host.add(pr);
  const bb = new Inst('BillboardGui', 'ChestTag');
  bb.set('Size', 'UDim2', [0, 240, 0, 60]).set('StudsOffset', 'Vector3', [0, 4.5, 0]).set('MaxDistance', 'float', 80).set('LightInfluence', 'float', 0);
  bb.add(styledText('DAILY CHEST', { name: 'Title', size: [1, 0, 0.55, 0], pos: [0, 0, 0, 0], color: '#ffe9a0', strokeT: 3, shadow: 2, align: 'Center', family: 'FredokaOne' }));
  bb.add(styledText('', { name: 'Timer', size: [1, 0, 0.4, 0], pos: [0, 0, 0.6, 0], color: '#ffffff', strokeT: 2, shadow: 2, align: 'Center', family: 'FredokaOne' }));
  host.add(bb);
}

function buildMotorPool(P) {
  // THE ARMORER's outfitters on the east rim (the Quartermaster until 2026-10-14): the turntable shows a mannequin in your next armor
  // (client Outfitter.luau dresses it); racks, a dart crate and an armor stand dress the kiosk
  const g = P.group('MotorPool');
  const [mx, mz] = dirOf(103);
  const c = g.at([mx * 37, Y.plaza, mz * 37], [0, 180 - 103, 0]); // between two plot walkways, facing the hologram
  c.cyl({ name: 'TurntableBase', axis: 'y', len: 0.8, d: 19, p: [0, 0.4, -2], c: '#3a3d42', m: 'Metal', collide: true });
  const top = c.cyl({ name: 'Turntable', axis: 'y', len: 0.3, d: 18, p: [0, 0.95, -2], c: '#2b2d31', m: 'DiamondPlate', collide: true });
  top.tag('Turntable');
  c.cyl({ name: 'TurntableGlow', axis: 'y', len: 0.12, d: 19.6, p: [0, 0.6, -2], c: '#ff7a1a', m: 'Neon', t: 0.55 });
  marker(c, 'TurntableAnchor', [0, 1.1, -2], 0);
  // kiosk behind (east)
  const k = c.at([0, 0, 9]);
  k.box({ name: 'KioskFloor', s: [16, 0.6, 7], p: [0, 0.3, 0], c: '#5d5a55', m: 'Slate', studs: 'top', collide: true });
  k.box({ name: 'Counter', s: [12, 3.4, 2], p: [0, 2.3, -2], c: '#f08a24', studs: 'top', collide: true });
  k.box({ name: 'CounterTop', s: [12.6, 0.4, 2.6], p: [0, 4.2, -2], c: '#2b2d31' });
  k.box({ name: 'BackWall', s: [16, 10, 1], p: [0, 5.6, 3], c: '#e9dfc4', studs: 'sides', collide: true });
  k.sym((s) => s.box({ name: 'Post', s: [1.2, 11, 1.2], p: [7.6, 6, -3.2], c: '#2b2d31', collide: true }));
  k.box({ name: 'Awning', s: [17, 0.5, 8], p: [0, 11.3, 0], r: [8, 0, 0], c: '#f08a24', studs: 'top' });
  for (let i = 0; i < 8; i++) k.box({ name: 'AwningStripe', s: [1, 0.52, 8.02], p: [-7 + i * 2, 11.32, 0], r: [8, 0, 0], c: '#ffffff', shadow: false });
  const sign = k.box({ name: 'ShopSign', s: [14, 2.6, 0.5], p: [0, 13.4, -2.8], c: '#2a2c31' });
  surfaceLabel(sign, 'Front', 'THE ARMORER', { pps: 34, color: '#ffe0b8', color2: '#ff7a1a' });
  k.box({ name: 'ShopSignFrame', s: [14.6, 3.2, 0.3], p: [0, 13.4, -2.55], c: '#f08a24' });
  // outfitter's wall: a launcher rack, a crate of tranq darts, an armor stand
  k.box({ name: 'RackBoard', s: [6.4, 4.2, 0.3], p: [0, 6.2, 2.4], c: '#8a5a33', m: 'WoodPlanks' });
  for (let i = 0; i < 3; i++) {
    const rx = -2 + i * 2;
    k.box({ name: 'RackPeg', s: [0.3, 0.3, 0.5], p: [rx, 7.4, 2.1], c: '#3a3d42', m: 'Metal' });
    k.box({ name: 'RackLauncher', s: [0.6, 3, 0.6], p: [rx, 6, 2.0], c: ['#f2b632', '#ff963c', '#6edcc8'][i] });
    k.box({ name: 'RackLauncherTip', s: [0.7, 0.4, 0.7], p: [rx, 4.4, 2.0], c: '#2b2d31', m: 'Metal' });
  }
  const dc = k.at([-5.4, 0.6, 1.2], [0, 12, 0]);
  dc.box({ name: 'DartCrate', s: [2.6, 1.6, 1.8], p: [0, 0.8, 0], c: '#8a5a33', m: 'WoodPlanks', collide: true });
  for (let i = 0; i < 6; i++) dc.box({ name: 'Dart', s: [0.2, 1.1, 0.2], p: [-0.9 + (i % 3) * 0.9, 1.9, -0.4 + Math.floor(i / 3) * 0.8], r: [(i % 2 ? 8 : -8), 0, 0], c: i % 2 ? '#7cff9a' : '#e8e2d4' });
  const ast = k.at([5.4, 0.6, 1.4]);
  ast.box({ name: 'StandPole', s: [0.4, 4.2, 0.4], p: [0, 2.1, 0], c: '#3a3d42', m: 'Metal' });
  ast.box({ name: 'StandBase', s: [2, 0.3, 2], p: [0, 0.15, 0], c: '#3a3d42', m: 'Metal' });
  ast.box({ name: 'VestOutline', s: [2.2, 2.4, 1.2], p: [0, 3.2, 0], c: '#5f8f3e' });
  ast.box({ name: 'VestStrap', s: [2.3, 0.4, 1.3], p: [0, 2.6, 0], c: '#2b2d31' });
  const host = marker(k, 'ShopPromptHost', [0, 3.2, -3.2]);
  const a = new Inst('Attachment', 'PromptAttachment');
  host.add(a);
  const pr = new Inst('ProximityPrompt', 'ShopPrompt');
  pr.set('ActionText', 'string', 'Gear up').set('ObjectText', 'string', 'Armorer').set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 14).set('HoldDuration', 'float', 0).set('RequiresLineOfSight', 'bool', false);
  pr.attr('CampAction', 'Shop');
  a.add(pr);
  // the crafting bench: you stand at it while the Mechanic builds your gear (the crafting cutscene)
  const bench = c.at([-9.5, 0, 6]);
  bench.box({ name: 'BenchTop', s: [6, 0.5, 3], p: [0, 3.1, 0], c: '#8a5a33', m: 'WoodPlanks', studs: 'top', collide: true });
  for (const x of [-2.6, 2.6]) for (const z of [-1.1, 1.1]) bench.box({ name: 'BenchLeg', s: [0.5, 2.9, 0.5], p: [x, 1.45, z], c: '#5e3f22' });
  bench.box({ name: 'BenchShelf', s: [5.6, 0.3, 2.6], p: [0, 1, 0], c: '#5e3f22' });
  bench.box({ name: 'Vise', s: [1, 0.8, 0.8], p: [-2, 3.75, 0.6], c: '#3a3d42', m: 'Metal' });
  bench.box({ name: 'Anvil', s: [1.6, 0.9, 0.9], p: [1.4, 3.8, -0.3], c: '#4a4d52', m: 'Metal' });
  bench.box({ name: 'Lamp', s: [0.4, 2.4, 0.4], p: [2.6, 4.5, 1], c: '#2b2d31' });
  const bl = bench.box({ name: 'LampHead', s: [1, 0.5, 0.8], p: [2.3, 5.7, 0.6], r: [0, 0, -30], c: '#ffd27a', m: 'Neon' });
  E.pointLight(bl, [1, 0.85, 0.6], 14, 0.9);
  marker(bench, 'CraftBench', [0, 3.4, 0], 0);
  marker(bench, 'CraftStand', [0, 0.2, -3.2], 0);
  NPC.buildNpc(g.parent, c.world(new CF(-9.5, 0, 9.6)), 'Mechanic');
}

function buildHatchStage(P) {
  // west rim: the latest hatch on the server is shown here, with its owner's name
  const g = P.group('HatchStage');
  const [hx, hz] = dirOf(257);
  const c = g.at([hx * 37, Y.plaza, hz * 37], [0, 180 - 257, 0]); // mirror of the Motor Pool, facing the hologram
  c.box({ name: 'Stage', s: [18, 1.6, 12], p: [0, 0.8, 0], c: '#5d5a55', m: 'Slate', studs: 'top', collide: true });
  c.box({ name: 'StageTrim', s: [18.4, 0.3, 12.4], p: [0, 1.5, 0], c: '#b46bff' });
  c.box({ name: 'StageFront', s: [18, 0.4, 0.3], p: [0, 1.0, -6.1], c: '#b46bff', m: 'Neon', shadow: false });
  c.cyl({ name: 'RevealPad', axis: 'y', len: 0.3, d: 7, p: [0, 1.75, -1], c: '#2b2d31', m: 'Metal' });
  c.cyl({ name: 'RevealPadGlow', axis: 'y', len: 0.32, d: 5, p: [0, 1.76, -1], c: '#e2c4ff', m: 'Neon', t: 0.3 });
  marker(c, 'StageAnchor', [0, 1.9, -1], 180);
  NPC.buildNpc(g.parent, c.world(new CF(-4.2, 1.6, -3.2)), 'EggKeeper');
  // the Egg Keeper's FUSION NEST beside the stage, on his left, turned toward the plaza (tools/gen/fusionNest.js; 2026-10-14)
  require('./fusionNest.js').buildFusionNest(c, [-14, 0, -3.2], -15);
  // big screen framed by egg-shell arches
  const scr = c.box({ name: 'Screen', s: [14, 7, 0.5], p: [0, 7.6, 4.5], c: '#14161a', m: 'SmoothPlastic' });
  c.box({ name: 'ScreenFrame', s: [15.2, 8.2, 0.4], p: [0, 7.6, 4.8], c: '#2b2d31', studs: 'top' });
  const sg = new Inst('SurfaceGui', 'HatchScreen');
  sg.set('Face', 'token', 5).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', 30).set('LightInfluence', 'float', 0);
  sg.add(styledText('LATEST HATCH', { name: 'Title', size: [0.9, 0, 0.2, 0], pos: [0.05, 0, 0.08, 0], color: '#e2c4ff', color2: '#b46bff', strokeT: 3, shadow: 3, align: 'Center' }));
  sg.add(styledText('NO HATCHES YET', { name: 'Species', size: [0.9, 0, 0.26, 0], pos: [0.05, 0, 0.38, 0], color: '#ffffff', strokeT: 3, shadow: 3, align: 'Center' }));
  sg.add(styledText('BRING AN EGG HOME!', { name: 'Owner', size: [0.8, 0, 0.14, 0], pos: [0.1, 0, 0.72, 0], color: '#fff4d6', strokeT: 2, shadow: 2, align: 'Center' }));
  scr.add(sg);
  c.sym((s) => {
    for (let i = 0; i < 6; i++) {
      const a = (i / 5) * 80;
      const r = 8.5;
      s.box({ name: 'ShellArch', s: [1.4, 2.6, 1.4], p: [Math.cos((a * Math.PI) / 180) * r * 0.25 + 7.8, 2 + Math.sin((a * Math.PI) / 180) * r, 3.2], r: [0, 0, -a * 0.6], c: i % 2 ? '#efe2c4' : '#d4c49d', studs: 'top' });
    }
    s.box({ name: 'Speaker', s: [2, 4, 2], p: [8.2, 3.6, -3.5], c: '#2b2d31' });
    s.cyl({ name: 'SpeakerCone', axis: 'z', len: 0.2, d: 1.5, p: [8.2, 4.2, -4.55], c: '#4a4d52' });
    s.box({ name: 'StageLight', s: [1, 1, 1.4], p: [7, 11.6, -3], r: [35, 0, 0], c: '#2b2d31' });
    s.box({ name: 'StageLightLens', s: [0.8, 0.8, 0.1], p: [7, 11.2, -3.7], r: [35, 0, 0], c: '#e2c4ff', m: 'Neon' });
  });
  c.box({ name: 'LightTruss', s: [16, 0.6, 0.6], p: [0, 12.2, -2.6], c: '#3a3d42', m: 'Metal' });
  c.sym((s) => s.box({ name: 'TrussPost', s: [0.6, 11, 0.6], p: [8.6, 6.6, -2.6], c: '#3a3d42', m: 'Metal' }));
}

function buildLeaderboards(P) {
  const mk = (x, title, attr, color) => {
    const g = P.group('Leaderboard');
    g.parent.attr('Stat', attr);
    const c = g.at([x, Y.plaza, -42], [0, x > 0 ? -24 : 24, 0]);
    // (2026-10-13) the legs stand OUTSIDE the board frame (x +-5.4, its colour border): at +-4.6 they covered the edges of every row
    c.box({ name: 'BoardBase', s: [12.4, 1.2, 3], p: [0, 0.6, 0], c: '#5d5a55', m: 'Slate', studs: 'top', collide: true });
    c.sym((s) => s.box({ name: 'BoardLeg', s: [1, 13.6, 1], p: [5.7, 7.3, -0.2], c: PAL.woodLo, studs: 'top', collide: true }));
    const b = c.box({ name: 'Board', s: [10, 11, 0.6], p: [0, 8.5, 0], c: '#1d1f24', collide: true });
    c.box({ name: 'BoardFrame', s: [10.8, 11.8, 0.4], p: [0, 8.5, -0.3], c: color, studs: 'top' });
    const roof = c.box({ name: 'BoardRoof', s: [13, 0.6, 3], p: [0, 14.4, 0], c: color, studs: 'top' });
    void roof;
    const sg = new Inst('SurfaceGui', 'BoardGui');
    sg.set('Face', 'token', 2).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', 30).set('LightInfluence', 'float', 0);
    sg.add(styledText(title, { name: 'Title', size: [0.9, 0, 0.1, 0], pos: [0.05, 0, 0.03, 0], color, strokeT: 3, shadow: 3, align: 'Center' }));
    for (let i = 0; i < 8; i++) {
      sg.add(styledText(i === 0 ? '---' : '', { name: 'Row' + (i + 1), size: [0.88, 0, 0.075, 0], pos: [0.06, 0, 0.17 + i * 0.1, 0], color: i === 0 ? '#ffd23a' : '#ffffff', strokeT: 2, shadow: 2, align: 'Left' }));
    }
    b.add(sg);
  };
  // boards face the plaza (their Back face points south toward the hologram)
  mk(-19, 'BOSS HUNTERS', 'Bosses', '#ff6a3a');
  mk(19, 'KING SPEEDRUN', 'Time_TyrantKing', '#ffb02e');
}

// ============================================================== POLYGONS (island-local [x, z] outlines -> rows of boxes)
// offset every vertex d studs inward (d < 0 grows the outline); works for the islands' gently curved outlines
function offsetPoly(poly, d) {
  const n = poly.length;
  let A = 0;
  for (let i = 0; i < n; i++) { const [x0, z0] = poly[i], [x1, z1] = poly[(i + 1) % n]; A += x0 * z1 - x1 * z0; }
  const sgn = A > 0 ? 1 : -1;
  const unit = (v) => { const l = Math.hypot(v[0], v[1]) || 1; return [v[0] / l, v[1] / l]; };
  return poly.map((p, i) => {
    const a = poly[(i - 1 + n) % n], b = poly[(i + 1) % n];
    const n1 = unit([-(p[1] - a[1]), p[0] - a[0]]), n2 = unit([-(b[1] - p[1]), b[0] - p[0]]);
    const m = unit([n1[0] + n2[0], n1[1] + n2[1]]);
    return [p[0] + m[0] * d * sgn, p[1] + m[1] * d * sgn];
  });
}
function polySpans(poly, z) {
  const xs = [];
  for (let i = 0; i < poly.length; i++) {
    const [x0, z0] = poly[i], [x1, z1] = poly[(i + 1) % poly.length];
    if ((z0 <= z && z1 > z) || (z1 <= z && z0 > z)) xs.push(x0 + ((z - z0) / (z1 - z0)) * (x1 - x0));
  }
  xs.sort((a, b) => a - b);
  const out = [];
  for (let k = 0; k + 1 < xs.length; k += 2) out.push([xs[k], xs[k + 1]]);
  return out;
}
function insidePoly(poly, x, z) {
  let c = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, zi] = poly[i], [xj, zj] = poly[j];
    if ((zi > z) !== (zj > z) && x < ((xj - xi) * (z - zi)) / (zj - zi) + xi) c = !c;
  }
  return c;
}
// fill a polygon with rows of boxes (step studs deep), tops at o.top, o.thick tall. Rows whose edges move less than
// o.merge studs join into one box (fewer parts, and fewer seams where the studs don't line up); o.inner keeps a
// merged box inside the outline (grass: the beach under it shows at the edge), otherwise it covers the outline.
function fillPoly(ctx, poly, step, o) {
  let zmin = Infinity, zmax = -Infinity;
  for (const [, z] of (o.zPoly || poly)) { zmin = Math.min(zmin, z); zmax = Math.max(zmax, z); }
  const n = Math.max(1, Math.ceil((zmax - zmin) / step));
  const h = (zmax - zmin) / n;
  const tol = o.merge || 0;
  const box = { ...o };
  delete box.top; delete box.thick; delete box.merge; delete box.inner; delete box.spans; delete box.zPoly;
  const emit = (xa, xb, z0, z1) => {
    if (xb - xa < 0.6) return;
    ctx.box({ ...box, s: [xb - xa, o.thick, z1 - z0], p: [(xa + xb) / 2, o.top - o.thick / 2, (z0 + z1) / 2] });
  };
  let cur = null;
  const flush = () => { if (cur) emit(cur.xa, cur.xb, cur.z0, cur.z1); cur = null; };
  for (let k = 0; k < n; k++) {
    const z0 = zmin + k * h, z1 = z0 + h;
    const sp = o.spans ? o.spans((z0 + z1) / 2, z0, z1) : polySpans(poly, (z0 + z1) / 2);
    if (sp.length !== 1) { flush(); for (const [xa, xb] of sp) emit(xa, xb, z0, z1); continue; }
    const [xa, xb] = sp[0];
    if (cur && Math.abs(xa - cur.fa) <= tol && Math.abs(xb - cur.fb) <= tol) {
      cur.z1 = z1;
      cur.xa = o.inner ? Math.max(cur.xa, xa) : Math.min(cur.xa, xa);
      cur.xb = o.inner ? Math.min(cur.xb, xb) : Math.max(cur.xb, xb);
      continue;
    }
    flush();
    cur = { z0, z1, xa, xb, fa: xa, fb: xb };
  }
  flush();
}
const inRect = (x, z, [x0, z0, x1, z1], m = 0) => x > x0 - m && x < x1 + m && z > z0 - m && z < z1 + m;

// ============================================================== HUB ISLAND + LAGOON
function buildGrounds(H) {
  const G = H.group('Ground', 'Folder');
  // the lagoon: a sandy seabed and one big block of Terrain water (the server fills it from this marker)
  G.box({ name: 'Seabed', s: [1450, 2, 1180], p: [0, Y.bed - 1, 150], c: '#c9b27a', m: 'Sand', collide: true, shadow: false });
  const wv = marker(G, 'WaterVolume', [0, (Y.water + Y.bed) / 2, 150], 0, { s: [1420, Y.water - Y.bed, 1170] });
  wv.tag('TerrainWater');
  // the hub island: an underwater shelf, wet sand, the beach, then grass (everything still sits on the old heights)
  const HR = IL.HUB_R;
  G.cyl({ name: 'HubShelf', axis: 'y', len: -3.6 - Y.bed, d: (HR + 14) * 2, p: [0, (Y.bed - 3.6) / 2, 0], c: '#d9c48c', m: 'Sand', collide: true, shadow: false });
  G.cyl({ name: 'HubWetSand', axis: 'y', len: 3, d: (HR + 6) * 2, p: [0, -0.75 - 1.5, 0], c: '#cdb27a', m: 'Sand', collide: true, shadow: false });
  G.cyl({ name: 'HubBeach', axis: 'y', len: 1.2, d: HR * 2, p: [0, 0.35 - 0.6, 0], c: '#ecd9a4', m: 'Sand', collide: true });
  G.cyl({ name: 'Grass', axis: 'y', len: 0.5, d: (HR - 9) * 2, p: [0, Y.ground - 0.25, 0], c: PAL.grass, collide: true });
  G.cyl({ name: 'RingRoad', axis: 'y', len: 0.4, d: 206, p: [0, Y.road - 0.2, 0], c: PAL.dirt, m: 'Sand', collide: true });
  G.cyl({ name: 'RingRoadEdge', axis: 'y', len: 0.3, d: 208.4, p: [0, Y.road - 0.27, 0], c: PAL.dirtLo, m: 'Sand', collide: true });
  G.cyl({ name: 'Lawn', axis: 'y', len: 0.4, d: 170, p: [0, Y.lawn - 0.2, 0], c: PAL.grassHi, collide: true });
  G.cyl({ name: 'LawnCurb', axis: 'y', len: 0.36, d: 171.6, p: [0, Y.lawn - 0.24, 0], c: '#8a8478', m: 'Slate', collide: true });
  // tyre ruts on the ring road
  for (const r of [91, 97]) {
    for (let k = 0; k < 72; k++) {
      const a = (k / 72) * 360;
      const [dx, dz] = dirOf(a);
      G.at([dx * r, Y.road + 0.02, dz * r], [0, 180 - a, 0]).box({ name: 'Rut', s: [8.2, 0.04, 1.1], c: PAL.dirtLo, m: 'Sand', shadow: false });
    }
  }
  // walkways from the plaza to the ring road: one toward every bridge, one south, the gate walk north
  const walk = (a, w, c, name) => {
    const [dx, dz] = dirOf(a);
    G.beam([dx * 53, Y.lawn + 0.05, dz * 53], [dx * 86, Y.lawn + 0.05, dz * 86], w, 0.12, { name, c, m: 'Slate', collide: true });
  };
  for (let i = 0; i < PLOT_COUNT; i++) walk(plotAngle(i), 8, '#d9c9a4', 'Walkway');
  walk(180, 10, '#d9c9a4', 'Walkway');
  walk(0, 12, '#d9c9a4', 'GateWalk');
  // gate road: ring road -> ramp foot
  G.box({ name: 'GateRoad', s: [20, 0.4, 28], p: [0, Y.road - 0.18, -116], c: PAL.dirt, m: 'Sand', collide: true });
  for (const x of [-4, 4]) G.box({ name: 'Rut', s: [1.1, 0.04, 28], p: [x, Y.road + 0.03, -116], c: PAL.dirtLo, m: 'Sand', shadow: false });
  // lawn dressing: lamps by every walkway, flowerbeds, a big tree between neighbouring bridges
  const R = rng(4242);
  const step = (IL.ARC1 - IL.ARC0) / (PLOT_COUNT - 1);
  for (let i = 0; i < PLOT_COUNT; i++) {
    const a = plotAngle(i);
    for (const side of [-1, 1]) {
      const [dx, dz] = dirOf(a + side * 4.2);
      E.lampPost(H, [dx * 80, Y.lawn, dz * 80], { yaw: -a, h: 7 });
    }
    for (const off of [-11, 11]) {
      const [dx, dz] = dirOf(a + off);
      E.bush(H, [dx * 70, Y.lawn, dz * 70], 0.9, 900 + i * 3 + off, { berries: R() > 0.5 ? '#ff5a7a' : undefined });
      E.flowers(H, [dx * 63, Y.lawn, dz * 63], 950 + i + off, { n: 6, spread: 4 });
    }
    if (i < PLOT_COUNT - 1) {
      const [dx, dz] = dirOf(a + step / 2);
      E.jungleTree(H, [dx * 72, Y.lawn + 0.15, dz * 72], 15 + R() * 5, 1300 + i); // (+0.15: the ring road disc runs under the lawn)
      E.fern(H, [dx * 66, Y.lawn, dz * 66 + 2], 1.1, 1400 + i);
      // the hub's outer lawn + beach between two bridges: palms, a boulder at the waterline
      const [ex, ez] = dirOf(a + step / 2);
      E.palm(H, [ex * 114, Y.ground, ez * 114], 12 + R() * 4, 1450 + i);
      E.rock(H, [ex * (HR + 2), 0.2, ez * (HR + 2)], 1.6 + R(), 1460 + i);
      const [fx, fz] = dirOf(a + step * 0.3);
      E.bush(H, [fx * 110, Y.ground, fz * 110], 1.1, 1470 + i);
    }
  }
  for (const side of [-1, 1]) {
    // gate approach: tall palms + torches
    for (let k = 0; k < 3; k++) E.palm(H, [side * 15, Y.lawn, -60 - k * 9], 12 + k * 2, 1500 + k + (side > 0 ? 10 : 0));
    E.lampPost(H, [side * 12, Y.road, -108], { yaw: side * 90, h: 8 });
    // the hub's north beach either side of the gate pier
    E.palm(H, [side * 52, Y.ground, -108], 13, 1520 + side);
    E.rock(H, [side * 46, 0.2, -122], 2.2, 1530 + side);
  }
  // the DAILY SPIN wheel (2026-10-14): on the north lawn, east of the gate walk, turned to face it (clear ground:
  // checked against the lawn's palms, lamps and flowerbeds)
  require('./spinWheel.js').buildSpinWheel(H, [31, Y.lawn, -63.5], 98);
  // south back lawn behind the HQ: picnic/crates corner
  E.crate(H, [-14, Y.lawn, 64], 1.2, { yaw: 20, stencil: '#2f6b3a' });
  E.crate(H, [-11, Y.lawn, 66], 1, { yaw: -10 });
  E.barrel(H, [14, Y.lawn, 63], { color: '#3d8249' });
  for (let k = 0; k < 4; k++) E.jungleTree(H, [-30 + k * 20, Y.lawn + 0.15, 76], 13 + R() * 4, 1600 + k);
  // the Time Gate stands on a stone pier off the north tip (its deck and light towers stand in the water)
  G.box({ name: 'GatePier', s: [74, -1.2 - Y.bed, 60], p: [0, (Y.bed - 1.2) / 2, (GATE.deckZ0 + GATE.deckZ1) / 2 - 1], c: '#6f6a62', m: 'Slate', collide: true });
  for (const side of [-1, 1]) {
    G.box({ name: 'GatePierButtress', s: [6, -1.0 - Y.bed, 64], p: [side * 37, (Y.bed - 1.0) / 2, (GATE.deckZ0 + GATE.deckZ1) / 2 - 1], c: '#625d56', m: 'Slate', studs: 'top', collide: true });
    G.box({ name: 'TowerFoot', s: [9, Y.deck - 6 - Y.bed, 9], p: [side * 42, (Y.deck - 6 + Y.bed) / 2, GATE.z + 10], c: '#6f6a62', m: 'Slate', studs: 'top', collide: true });
  }
  return G;
}

// ============================================================== ISLANDS
// keep-out rects for scattered decor (island-local), so nothing grows through a building or a path
const P = IL.PLAN;
const DRIVE = [-16, -12, 16, 34];
const APRON = [8, 28, 26, 58];
const KEEP = [DRIVE, APRON, P.aisle, P.garage, P.lodge, P.hatchery, P.trophy, P.paddock, P.trainer.rect, P.showcase.rect, ...P.star.filter((s) => s.kind !== 'sea').map((s) => s.rect), [-24, 22, -8, 38], [-31, 37, -7, 49], [-65, 57, -55, 71],
  [10, 56, 18, 64], [15, 21, 23, 29], [60, 61, 70, 69], [-86, 115, -76, 123], [76, 115, 86, 123], [-5, 228, 14, 240]]; // (+ the upgrade boards)

function buildIsland(plots, i) {
  const f = IL.islandFrame(i);
  const accent = ACCENTS[i];
  const g = plots.group('Plot' + (i + 1));
  const plotModel = g.parent;
  plotModel.attr('PlotIndex', i + 1).attr('Accent', accent).attr('AccentName', ACCENT_NAMES[i]).attr('Owner', 0).attr('OwnerName', '');
  plotModel.attr('IslandAngle', f.angle);
  plotModel.tag('CampPlot');
  // local frame: origin at the middle of the island's front shore (where the bridge lands), +Z away from the hub
  const c = g.at(f.front, [0, f.yaw, 0]);
  const R = rng(5000 + i * 97);
  const outline = IL.outline(i + 3, 0.035);
  const grassPoly = offsetPoly(outline, P.beach);
  const ground = c.group('Ground', 'Folder');
  fillPoly(ground, offsetPoly(outline, -14), 6, { name: 'IslandShelf', merge: 8, top: -3.6, thick: -3.6 - Y.bed, c: '#d9c48c', m: 'Sand', collide: true, shadow: false });
  fillPoly(ground, offsetPoly(outline, -6), 4, { name: 'WetSand', merge: 5, top: -0.75, thick: 3, c: '#cdb27a', m: 'Sand', collide: true, shadow: false });
  fillPoly(ground, outline, 3, { name: 'IslandBeach', merge: 3, top: 0.55, thick: 1.4, c: '#ecd9a4', m: 'Sand', collide: true });
  // the grass reaches under every building lot, even where this island's wobble pulls its shore in a little
  // (a pen's corner used to float over the sand); never past 1.5 studs inside the sand's own edge
  const LOTS = [P.paddock, P.hatchery, P.trophy, P.garage, P.lodge, P.trainer.rect, P.showcase.rect, ...P.star.filter((x) => x.kind !== 'sea').map((x) => x.rect)];
  const grassSpans = (zm, z0, z1) => {
    const outer = polySpans(outline, zm);
    if (outer.length === 0) return [];
    let [xa, xb] = polySpans(grassPoly, zm)[0] || [Infinity, -Infinity];
    for (const [rx0, rz0, rx1, rz1] of LOTS) if (z1 > rz0 - 1 && z0 < rz1 + 1) { xa = Math.min(xa, rx0 - 1); xb = Math.max(xb, rx1 + 1); }
    const [oa, ob] = [outer[0][0], outer[outer.length - 1][1]];
    xa = Math.max(xa, oa + 1.5); xb = Math.min(xb, ob - 1.5);
    return xb - xa > 0.6 ? [[xa, xb]] : [];
  };
  fillPoly(ground, grassPoly, 2, { name: 'IslandGrass', merge: 3.5, inner: true, spans: grassSpans, zPoly: outline, top: Y.plot, thick: 0.5, c: shade(PAL.grass, 1.06), studs: 'top', collide: true });
  // the front yard: a paved drive from the bridge through the name gate, and the garage apron
  ground.box({ name: 'Driveway', s: [DRIVE[2] - DRIVE[0], 0.14, 30], p: [0, Y.plot + 0.05, 19], c: '#c9bb98', m: 'Slate', collide: true });
  ground.box({ name: 'Driveway', s: [APRON[2] - APRON[0], 0.14, APRON[3] - APRON[1]], p: [(APRON[0] + APRON[2]) / 2, Y.plot + 0.06, (APRON[1] + APRON[3]) / 2], c: '#c9bb98', m: 'Slate', collide: true });
  // the centre aisle: name gate -> hatchery -> paddock gate (the hatchling walks it, under the hatchery roof)
  const aisleL = P.paddock[1] - 34;
  ground.box({ name: 'Walkway', s: [10, 0.14, aisleL], p: [0, Y.plot + 0.08, 34 + aisleL / 2], c: '#b5a98e', m: 'Pebble', collide: true });
  for (let k = 0; k < Math.floor(aisleL / 4.2); k++) c.box({ name: 'Stepstone', s: [2.6, 0.06, 1.6], p: [(k % 2 ? 1.6 : -1.6), Y.plot + 0.18, 36 + k * 4.2], r: [0, (R() - 0.5) * 20, 0], c: '#cfc3a4', m: 'Slate', shadow: false });
  // paths to the lodge and the trophy hall
  // (named Footpath: Hatch.walkToYard follows the plot's one 'Walkway', the centre aisle)
  ground.box({ name: 'Footpath', s: [22, 0.12, 6], p: [-19, Y.plot + 0.07, 43], c: '#b5a98e', m: 'Pebble', collide: true });
  ground.box({ name: 'Footpath', s: [6, 0.12, 8], p: [-60, Y.plot + 0.07, 64], c: '#b5a98e', m: 'Pebble', collide: true });

  // ---------- name gate (arch) ----------
  const arch = c.group('NameGate');
  const PX = 12.5, segs = 7, segH = 2.6;
  const gz = P.nameGate[1];
  for (const side of [-1, 1]) {
    const pc = arch.at([side * PX, Y.plot, gz]);
    for (let k = 0; k < segs; k++) pc.box({ name: 'GatePillar', s: [2.8 - k * 0.07, segH, 2.8 - k * 0.07], p: [0, segH / 2 + k * segH, 0], r: [0, k * 9, 0], c: k % 2 ? '#7a746a' : '#8a8478', m: 'Slate', studs: 'top', collide: true });
    pc.box({ name: 'PillarCap', s: [3.4, 0.9, 3.4], p: [0, segs * segH + 0.45, 0], c: accent, studs: 'top' });
    const torch = pc.box({ name: 'Torch', s: [0.9, 1.3, 0.9], p: [0, segs * segH + 1.55, 0], c: PAL.lamp, m: 'Neon' });
    torch.tag('CampLight');
    E.particles(torch, 'Flame', { rate: 14, life: [0.3, 0.6], speed: [2, 4], dir: 1, spread: [12, 12], size: [[0, 0.8], [1, 0]], color: [[0, [1, 0.85, 0.35]], [1, [1, 0.35, 0.1]]], emission: 1 });
    E.pointLight(torch, [1, 0.75, 0.4], 20, 1.2);
  }
  const topY = Y.plot + segs * segH;
  arch.box({ name: 'GateBeam', s: [PX * 2 + 4, 1.6, 1.8], p: [0, topY - 0.4, gz], c: PAL.woodLo, studs: 'top' });
  const board = arch.box({ name: 'OwnerSign', s: [21, 4.6, 0.5], p: [0, topY - 3.9, gz - 0.3], c: '#2a2c31' });
  arch.box({ name: 'OwnerSignFrame', s: [21.9, 5.5, 0.4], p: [0, topY - 3.9, gz + 0.05], c: accent, studs: 'top' });
  for (const side of [-1, 1]) arch.box({ name: 'SignChain', s: [0.2, 1.4, 0.2], p: [side * 8.5, topY - 1.3, gz - 0.3], c: '#3a3d42', m: 'Metal' });
  surfaceLabel(board, 'Front', 'FREE ISLAND', { name: 'OwnerText', pps: 30, color: '#fff4d6', color2: accent });
  surfaceLabel(board, 'Back', 'FREE ISLAND', { name: 'OwnerTextBack', pps: 30, color: '#fff4d6', color2: accent });

  // ---------- buildings ----------
  const mid = (r) => [(r[0] + r[2]) / 2, (r[1] + r[3]) / 2];
  // garage: door on its aisle side, so the rover rolls out onto the drive and straight to the bridge
  {
    const [, gzc] = mid(P.garage);
    buildGarage(c.at([P.garage[0] + 4 + 13, Y.plot, gzc], [0, 90, 0]), accent, i);
  }
  {
    const [lx, lz] = mid(P.lodge);
    buildLodge(c.at([lx, Y.plot, lz], [0, -90, 0]), accent, i);
  }
  {
    const [tx, tz] = mid(P.trophy);
    buildTrophyHall(c.at([tx, Y.plot, tz], [0, 90, 0]), accent, i);
  }
  {
    const [, hz] = mid(P.hatchery);
    buildHatchery(c.at([0, Y.plot, hz]), accent, i, P.hatchery[2] - P.hatchery[0] - 2, P.hatchery[3] - P.hatchery[1] - 4);
  }
  buildPaddock(c.at([0, 0.25, P.paddock[1] + PADDOCK_D / 2]), accent, i);
  for (const s of P.star) buildStarLot(c, s, accent, i);

  // ---------- upgrade boards (CampAction Build; the owner's client switches them on) ----------
  buildBoard(c, [14, Y.plot, 60], 0, 'Hatchery', 'Upgrade', 'Hatchery');
  buildBoard(c, [19, Y.plot, 25], 90, 'Garage', 'Upgrade', 'Garage');
  for (const s of P.star) {
    const [x0, z0, x1, z1] = s.rect;
    if (s.kind === 'sea') buildBoard(c, [9, 0.55, 233], 180, s.id, 'Star Pen', 'Sea Pen');
    else buildBoard(c, [(x0 + x1) / 2, Y.plot, z0 - 3], 0, s.id, 'Star Pen', 'Star Pen');
  }

  // ---------- cash pad (left of the drive, by the gate) ----------
  const cp = c.at([P.cashPad[0], Y.plot, P.cashPad[1]]);
  cp.cyl({ name: 'CashPadRim', axis: 'y', len: 0.5, d: 8, p: [0, 0.25, 0], c: '#ffcf3a', m: 'Metal', collide: true });
  const pad = cp.cyl({ name: 'CashPad', axis: 'y', len: 0.55, d: 6.6, p: [0, 0.3, 0], c: '#3fbf5a', collide: true, touch: true });
  pad.tag('CashPad');
  surfaceLabel(pad, 'Right', '$', { name: 'CashSymbol', pps: 30, color: '#eaffd8', color2: '#9fe870', size: [0.6, 0, 0.6, 0], pos: [0.2, 0, 0.2, 0] });
  const ring = cp.cyl({ name: 'CashGlow', axis: 'y', len: 0.1, d: 8.6, p: [0, 0.05, 0], c: '#9fe870', m: 'Neon', t: 0.5, shadow: false });
  ring.tag('CashGlow');
  const lbl = marker(cp, 'CashLabelAnchor', [0, 5, 0]);
  billboardText(lbl, 'CashLabel', '$0', { w: 9, h: 2.4, color: '#eaffd8', color2: '#5fd35a', maxDist: 90 });
  billboardText(lbl, 'CashHint', 'STEP TO COLLECT', { w: 9, h: 1.0, offset: [0, -1.7, 0], color: '#ffffff', maxDist: 60, strokeT: 2 });
  for (let k = 0; k < 4; k++) cp.box({ name: 'CoinStack', s: [0.9, 0.3 + k * 0.25, 0.9], p: [-4.6 + (k % 2) * 1.1, 0.25 + (0.3 + k * 0.25) / 2, -1 + Math.floor(k / 2) * 1.2], c: '#ffcf3a', m: 'Metal' });

  // ---------- markers for gameplay ----------
  marker(c, 'PlayerSpawn', [0, Y.plot + 3, 34], 0);
  marker(c, 'PlotCenter', [0, Y.plot + 1, IL.ISLAND_D / 2], 0, { s: [IL.halfWidth(IL.ISLAND_D / 2) * 2, 1, IL.ISLAND_D] });
  marker(c, 'IslandCam', [-58, 46, -40], 0); // MainMenu / establishing shots: high over the front-left shore
  marker(c, 'IslandLook', [0, 10, 120], 0);
  // the power trainer: IslandView pivots Trainer1..7 (islandKit.js) here; the lot is kept clear of decor (KEEP)
  marker(c, 'TrainerAnchor', [P.trainer.anchor[0], Y.plot, P.trainer.anchor[1]], P.trainer.yaw);
  // the showcase pedestal (2026-10-14): IslandView pivots the kit's Showcase here (every island, owned or free)
  marker(c, 'ShowcaseAnchor', [P.showcase.anchor[0], Y.plot, P.showcase.anchor[1]], P.showcase.yaw);

  // ---------- dressing: palms along the beach, trees in the free corners, rocks at the waterline ----------
  const shore = offsetPoly(outline, 4.5);
  const near = [];
  const okAt = (x, z, m) => insidePoly(grassPoly, x, z) && !KEEP.some((r) => inRect(x, z, r, m)) && near.every(([px, pz, pr]) => Math.hypot(px - x, pz - z) > pr);
  let along = 0;
  for (let k = 0; k < shore.length; k++) {
    const [x, z] = shore[k], [nx, nz] = shore[(k + 1) % shore.length];
    along += Math.hypot(nx - x, nz - z);
    if (along < 40) continue;
    along = 0;
    if (Math.abs(x) < 26 && z < 30) continue; // keep the bridge landing clear
    if (Math.abs(x) < 50 && z > 220) continue; // and the back shore by the sea pen
    if (R() < 0.45) { E.palm(c, [x, 0.55, z], 11 + R() * 5, 20000 + i * 100 + k); near.push([x, z, 9]); }
    else { E.rock(c, [x * 1.02, 0.1, z + (z > 120 ? 2 : 0)], 1.4 + R() * 1.2, 20500 + i * 100 + k); near.push([x, z, 5]); }
  }
  let trees = 0, tries = 0;
  while (trees < 9 && tries < 400) {
    tries++;
    const x = (R() - 0.5) * 250, z = R() * 236;
    if (!okAt(x, z, 7)) continue;
    E.jungleTree(c, [x, Y.plot, z], 13 + R() * 6, 21000 + i * 50 + trees);
    near.push([x, z, 16]);
    trees++;
  }
  let small = 0; tries = 0;
  while (small < 16 && tries < 500) {
    tries++;
    const x = (R() - 0.5) * 250, z = R() * 236;
    if (!okAt(x, z, 4.5)) continue;
    const t = small % 4;
    if (t === 0) E.bush(c, [x, Y.plot, z], 0.9 + R() * 0.5, 21500 + i * 50 + small);
    else if (t === 1) E.fern(c, [x, Y.plot, z], 1 + R() * 0.4, 21500 + i * 50 + small);
    else if (t === 2) E.flowers(c, [x, Y.plot, z], 21500 + i * 50 + small, { n: 5, spread: 3 });
    else E.rock(c, [x, Y.plot, z], 1 + R(), 21500 + i * 50 + small);
    near.push([x, z, 5]);
    small++;
  }
  E.flowers(c, [-21, Y.plot, 10], 6400 + i, { n: 5, spread: 2.5 });
  E.flowers(c, [21, Y.plot, 10], 6500 + i, { n: 5, spread: 2.5 });
  return g;
}

// the LODGE: your home on the island (v1: a log cabin; building upgrades swap in bigger ones later).
// Origin = cabin centre on the ground, the porch and door face local -Z.
function buildLodge(c, accent, idx) {
  const g = c.group('Lodge');
  g.parent.attr('Tier', 1);
  const W = 24, D = 20, H = 9;
  const logA = '#8a6238', logB = '#7d5733', roofA = '#5e7a3a', roofB = '#4f6a30';
  g.box({ name: 'LodgeFloor', s: [W + 1, 1, D + 1], p: [0, 0.5, 2], c: '#6b4a2b', m: 'WoodPlanks', collide: true });
  // log walls: stacked logs, a door gap at the front, windows either side of it
  const logs = 6, lh = H / logs;
  for (let k = 0; k < logs; k++) {
    const y = 1 + lh * (k + 0.5);
    const col = k % 2 ? logA : logB;
    g.cyl({ name: 'LogWall', axis: 'x', len: W + 1.4, d: lh + 0.1, p: [0, y, D / 2 + 2], c: col, collide: true });
    g.sym((sd) => sd.cyl({ name: 'LogWall', axis: 'z', len: D + 1.4, d: lh + 0.1, p: [W / 2, y, 2], c: col, collide: true }));
    // front wall: door gap (x -2.6..2.6, bottom 4 logs), windows at x +-7.5 (logs 2..3)
    for (const [x0, x1] of [[-W / 2 - 0.7, -2.6], [2.6, W / 2 + 0.7]]) {
      if (k >= 2 && k <= 3) {
        // around the window: short logs either side of it
        const parts = x0 < 0 ? [[x0, -9.6], [-5.4, x1]] : [[x0, 5.4], [9.6, x1]];
        for (const [a, b] of parts) g.cyl({ name: 'LogWall', axis: 'x', len: b - a, d: lh + 0.1, p: [(a + b) / 2, y, -D / 2 + 2], c: col, collide: true });
      } else if (k < 4) {
        g.cyl({ name: 'LogWall', axis: 'x', len: x1 - x0, d: lh + 0.1, p: [(x0 + x1) / 2, y, -D / 2 + 2], c: col, collide: true });
      }
    }
    if (k >= 4) g.cyl({ name: 'LogWall', axis: 'x', len: W + 1.4, d: lh + 0.1, p: [0, y, -D / 2 + 2], c: col, collide: true });
  }
  for (const x of [-7.5, 7.5]) {
    g.box({ name: 'Window', s: [4.2, 3, 0.2], p: [x, 1 + lh * 3, -D / 2 + 2], c: '#ffe9a8', m: 'Glass', t: 0.3 });
    g.box({ name: 'WindowFrame', s: [4.8, 0.4, 0.6], p: [x, 1 + lh * 4 + 0.1, -D / 2 + 1.8], c: '#5e3f22' });
    g.box({ name: 'WindowBox', s: [4.6, 0.8, 1], p: [x, 1 + lh * 2 - 0.3, -D / 2 + 1.2], c: '#6b4a2b', m: 'WoodPlanks' });
    for (let b = 0; b < 4; b++) g.box({ name: 'Bloom', s: [0.6, 0.6, 0.6], p: [x - 1.6 + b * 1.05, 1 + lh * 2 + 0.4, -D / 2 + 0.95], r: [0, b * 25, 0], c: ['#ff5a7a', '#ffd23a', '#ffffff', '#ff8a2a'][(b + idx) % 4], shadow: false });
  }
  const door = g.box({ name: 'LodgeDoor', s: [4.8, 6, 0.4], p: [0, 4, -D / 2 + 2.1], c: '#5e3f22', m: 'WoodPlanks' });
  void door;
  g.box({ name: 'DoorKnob', s: [0.4, 0.4, 0.4], p: [1.6, 4, -D / 2 + 1.75], c: '#ffcf3a', m: 'Metal' });
  // pitched roof with a big overhang over the porch, accent ridge
  for (const side of [-1, 1]) {
    const roof = g.at([side * W / 4, H + 4, 0.5], [0, 0, -side * 24]);
    for (let k = 0; k < 6; k++) roof.box({ name: 'RoofPanel', s: [W / 2 + 3.4, 0.6, (D + 7) / 6], p: [0, 0, -(D + 7) / 2 + (k + 0.5) * ((D + 7) / 6)], c: k % 2 ? roofA : roofB, studs: 'top' });
  }
  g.box({ name: 'RoofRidge', s: [1.6, 1.2, D + 8], p: [0, H + 7.3, 0.5], c: accent, studs: 'top' });
  for (const z of [-D / 2 + 2, D / 2 + 2]) g.sym((sd) => sd.wedgeF({ name: 'Gable', s: [1, 6, W / 2], p: [W / 4, H + 1 + 3, z], face: 'right', c: logA }));
  // chimney
  const ch = g.at([W / 2 - 4, 1, D / 2 - 1]);
  for (let k = 0; k < 7; k++) ch.box({ name: 'Chimney', s: [3.2, 2.2, 3.2], p: [0, 1.1 + k * 2.2, 0], r: [0, k * 6, 0], c: k % 2 ? '#8a8478' : '#7a746a', m: 'Slate', studs: 'top', collide: k < 2 });
  const smoke = ch.box({ name: 'ChimneyTop', s: [2.4, 0.4, 2.4], p: [0, 16, 0], c: '#2b2d31' });
  E.particles(smoke, 'Smoke', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 2, life: [3, 5], speed: [3, 5], dir: 1, spread: [8, 8], size: [[0, 2], [1, 6]], transp: [[0, 0.5], [1, 1]], color: [0.85, 0.85, 0.85], emission: 0 });
  // porch: deck, posts, steps, a lantern and two chairs
  g.box({ name: 'PorchDeck', s: [W - 2, 0.8, 6], p: [0, 0.4, -D / 2 - 1.2], c: '#a8743f', m: 'WoodPlanks', collide: true });
  for (const x of [-W / 2 + 1.6, W / 2 - 1.6]) g.box({ name: 'PorchPost', s: [0.9, H + 1.4, 0.9], p: [x, 0.8 + (H + 1.4) / 2, -D / 2 - 2.6], c: '#5e3f22', collide: true });
  g.box({ name: 'PorchStep', s: [6, 0.4, 2], p: [0, 0.2, -D / 2 - 5.2], c: '#a8743f', m: 'WoodPlanks', collide: true });
  const lantern = g.box({ name: 'Lantern', s: [0.9, 1.2, 0.9], p: [3.6, 7.4, -D / 2 + 1.4], c: PAL.lamp, m: 'Neon' });
  lantern.tag('CampLight');
  E.pointLight(lantern, [1, 0.8, 0.5], 16, 0.8);
  for (const x of [-7, 7]) {
    const chc = g.at([x, 0.8, -D / 2 - 1.6], [0, x > 0 ? -18 : 18, 0]);
    chc.box({ name: 'ChairSeat', s: [2.4, 0.4, 2.2], p: [0, 1.2, 0], c: '#c8452a', m: 'WoodPlanks' });
    chc.box({ name: 'ChairBack', s: [2.4, 2.2, 0.4], p: [0, 2.2, 1.0], r: [-12, 0, 0], c: '#c8452a', m: 'WoodPlanks' });
    for (const lx of [-0.9, 0.9]) chc.box({ name: 'ChairLeg', s: [0.3, 1.1, 1.8], p: [lx, 0.55, 0], c: '#5e3f22' });
  }
  const sign = g.box({ name: 'LodgeSign', s: [8, 1.8, 0.3], p: [0, H + 0.4, -D / 2 - 2.8], c: '#2a2c31' });
  surfaceLabel(sign, 'Front', 'LODGE', { pps: 30, color: '#fff4d6', color2: accent });
  marker(g, 'LodgeAnchor', [0, 1, -D / 2 - 6], 0);
  // firewood + an axe by the side wall
  for (let k = 0; k < 6; k++) g.cyl({ name: 'Firewood', axis: 'z', len: 2.6, d: 0.9, p: [-W / 2 - 1.4 - (k % 3) * 0.95, 0.5 + Math.floor(k / 3) * 0.85, -3 + (k % 2) * 0.3], c: k % 2 ? '#8a6238' : '#a8743f' });
}

// an UPGRADE board: a blueprint on an easel with a hammer on top. Its prompt (CampAction Build, attribute Build =
// what it upgrades) starts switched off; the island owner's client turns it on (CampView).
function buildBoard(c, p, yaw, id, action, object) {
  const g = c.group('BuildBoard');
  g.parent.attr('Build', id);
  const b = g.at(p, [0, yaw, 0]); // the blueprint faces local -Z
  for (const x of [-1.2, 1.2]) b.box({ name: 'BoardLeg', s: [0.5, 3.4, 0.5], p: [x, 1.7, 0.2], r: [8, 0, 0], c: PAL.woodLo, collide: true });
  b.box({ name: 'BoardLeg', s: [0.4, 3.2, 0.4], p: [0, 1.5, 1.2], r: [-20, 0, 0], c: PAL.woodLo });
  const bp = b.at([0, 3.4, -0.05], [-16, 0, 0]);
  bp.box({ name: 'Blueprint', s: [3.8, 2.6, 0.25], c: '#2f6fb0', collide: true });
  bp.box({ name: 'BlueprintFrame', s: [4.1, 2.9, 0.18], p: [0, 0, 0.1], c: PAL.wood });
  for (const y of [-0.6, 0.2]) bp.box({ name: 'BlueprintLine', s: [3.2, 0.08, 0.05], p: [0, y, -0.14], c: '#d8ecff', shadow: false });
  for (const x of [-0.8, 0.5]) bp.box({ name: 'BlueprintLine', s: [0.08, 2, 0.05], p: [x, 0, -0.14], c: '#d8ecff', shadow: false });
  bp.box({ name: 'BlueprintHouse', s: [1.2, 0.9, 0.05], p: [-0.2, -0.1, -0.15], c: '#ffffff', shadow: false });
  const hm = bp.at([0.9, 1.6, 0], [0, 0, -35]);
  hm.box({ name: 'HammerHandle', s: [0.3, 1.8, 0.3], c: '#a8743f' });
  hm.box({ name: 'HammerHead', s: [1.1, 0.5, 0.5], p: [0, 0.95, 0], c: '#5d6168', m: 'Metal' });
  const host = marker(b, 'BuildPromptHost', [0, 3.2, -0.8]);
  const at = new Inst('Attachment', 'PromptAttachment');
  host.add(at);
  const pr = new Inst('ProximityPrompt', 'BuildPrompt');
  pr.set('ActionText', 'string', action).set('ObjectText', 'string', object).set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 10).set('HoldDuration', 'float', 0).set('RequiresLineOfSight', 'bool', false).set('Enabled', 'bool', false);
  pr.attr('CampAction', 'Build').attr('Build', id);
  at.add(pr);
  return g;
}

// a reserved STAR PEN lot (the pens themselves come with the park update): a cleared dirt lot, surveyor stakes
// and string at the corners. The sea pen is a ring of buoys out in the water.
function buildStarLot(c, s, accent, idx) {
  const [x0, z0, x1, z1] = s.rect;
  const cx = (x0 + x1) / 2, cz = (z0 + z1) / 2, w = x1 - x0, d = z1 - z0;
  const g = c.group(s.id);
  const lot = g.parent;
  lot.attr('StarPen', s.id).attr('Kind', s.kind);
  marker(g, 'LotAnchor', [cx, s.kind === 'sea' ? Y.water : Y.plot, cz], 0); // IslandView pivots Pen_<Species>_<Lot> here
  if (s.kind === 'sea') {
    const m = marker(g, 'StarPad', [cx, Y.water, cz], 0, { s: [w, 1, d] });
    m.attr('Id', s.id).attr('Kind', s.kind);
    for (let k = 0; k < 8; k++) {
      const a = (k / 8) * Math.PI * 2;
      const bx = cx + Math.cos(a) * w * 0.48, bz = cz + Math.sin(a) * d * 0.48;
      g.cyl({ name: 'Buoy', axis: 'y', len: 1.6, d: 1.6, p: [bx, Y.water + 0.5, bz], c: k % 2 ? '#ffffff' : '#e8473a', shadow: false });
      g.box({ name: 'BuoyTop', s: [0.3, 1.2, 0.3], p: [bx, Y.water + 1.8, bz], c: '#3a3d42', shadow: false });
    }
    return;
  }
  g.box({ name: 'LotDirt', s: [w - 2, 0.08, d - 2], p: [cx, Y.plot + 0.04, cz], c: '#a8875a', m: 'Sand', shadow: false });
  for (const [sx, sz] of [[x0 + 1.5, z0 + 1.5], [x1 - 1.5, z0 + 1.5], [x1 - 1.5, z1 - 1.5], [x0 + 1.5, z1 - 1.5]]) {
    g.box({ name: 'SurveyStake', s: [0.5, 3, 0.5], p: [sx, Y.plot + 1.5, sz], c: '#c08a52', m: 'WoodPlanks' });
    g.box({ name: 'StakeFlag', s: [0.08, 0.9, 1.4], p: [sx, Y.plot + 2.6, sz + 0.7], c: '#ff7a1a', shadow: false });
  }
  const yS = Y.plot + 1.2;
  for (const [a, b] of [[[x0 + 1.5, z0 + 1.5], [x1 - 1.5, z0 + 1.5]], [[x1 - 1.5, z0 + 1.5], [x1 - 1.5, z1 - 1.5]], [[x1 - 1.5, z1 - 1.5], [x0 + 1.5, z1 - 1.5]], [[x0 + 1.5, z1 - 1.5], [x0 + 1.5, z0 + 1.5]]]) {
    g.beam([a[0], yS, a[1]], [b[0], yS, b[1]], 0.08, 0.08, { name: 'SurveyString', c: '#f2e6c4', shadow: false });
  }
  const m = marker(g, 'StarPad', [cx, Y.plot + 0.5, cz], 0, { s: [w, 1, d] });
  m.attr('Id', s.id).attr('Kind', s.kind);
  void accent; void idx;
}

// ============================================================== BRIDGES
// One per island, from the hub's ring road out to the island's front lawn. It arches gently over the water,
// stone deck with a dashed centre line, studded parapets with accent caps, lamps; invisible guard walls keep
// the rover (camp driving treats anything taller than 6.5 as a wall) and players from going over the side.
function buildBridge(BR, i) {
  const a = plotAngle(i);
  const accent = ACCENTS[i];
  const g = BR.group('Bridge' + (i + 1));
  g.parent.attr('PlotIndex', i + 1).attr('Accent', accent);
  const c = g.at([0, 0, 0], [0, 180 - a, 0]); // local +Z runs out from the hub centre along the bridge
  const W = IL.BRIDGE_W;
  const z0 = 98, zs0 = IL.HUB_R - 2, zs1 = IL.RF + 1, z1 = IL.RF + 4; // ends where the island's driveway starts (local z 4)
  const RISE = 7;
  const yAt = (z) => {
    if (z <= zs0) return 0.85 + 0.25 * Math.min(1, Math.max(0, (z - z0) / 6));
    if (z >= zs1) return 1.1;
    const t = (z - zs0) / (zs1 - zs0);
    return 1.1 + RISE * Math.sin(Math.PI * t);
  };
  const SEG = 8;
  const n = Math.round((z1 - z0) / SEG);
  const zs = Array.from({ length: n + 1 }, (_, k) => z0 + ((z1 - z0) * k) / n);
  for (let k = 0; k < n; k++) {
    const za = zs[k], zb = zs[k + 1];
    const ya = yAt(za), yb = yAt(zb);
    c.beam([0, ya - 0.6, za], [0, yb - 0.6, zb], W, 1.2, { name: 'BridgeDeck', c: '#b8ad94', m: 'Slate', collide: true, extend: 0.3 });
    if (k % 2 === 0) c.beam([0, ya + 0.02, za + 1.5], [0, yb + 0.02, zb - 1.5], 0.6, 0.05, { name: 'BridgeLine', c: '#f2e6c4', shadow: false });
    for (const side of [-1, 1]) {
      const x = side * (W / 2 + 0.6);
      c.beam([x, ya + 0.9, za], [x, yb + 0.9, zb], 1.4, 3, { name: 'BridgeRail', c: '#8a8478', m: 'Slate', studs: 'top', collide: true, extend: 0.2 });
      c.beam([side * (W / 2 - 0.6), ya + 0.25, za], [side * (W / 2 - 0.6), yb + 0.25, zb], 1.2, 0.5, { name: 'BridgeCurb', c: '#a8743f', m: 'WoodPlanks', collide: true });
      if (za >= zs0 - 4 && zb <= zs1 + 4) c.beam([x, ya + 4.4, za], [x, yb + 4.4, zb], 1.4, 10, { name: 'BridgeGuard', t: 1, collide: true, shadow: false, extend: 0.2 });
      if (k % 3 === 1) c.box({ name: 'RailCap', s: [2, 0.8, 2], p: [x, (ya + yb) / 2 + 2.8, (za + zb) / 2], c: accent, studs: 'top' });
      if (k % 6 === 3) E.lampPost(c, [x, (ya + yb) / 2 + 2.4, (za + zb) / 2], { yaw: side > 0 ? -90 : 90, h: 6 });
    }
  }
  // piers down to the seabed under the arch
  for (let z = zs0 + 20; z < zs1 - 10; z += 26) {
    const y = yAt(z) - 1.2;
    c.box({ name: 'BridgePier', s: [W + 4, y - Y.bed, 4], p: [0, (y + Y.bed) / 2, z], c: '#7a746a', m: 'Slate', collide: true });
    c.box({ name: 'PierCap', s: [W + 5, 0.8, 5], p: [0, y + 0.1, z], c: '#8a8478', m: 'Slate', studs: 'top' });
  }
  // bridge heads: stone posts at the hub end, accent banners at the island end
  for (const side of [-1, 1]) {
    const hx = side * (W / 2 + 1.8);
    const hc = c.at([hx, yAt(z0 + 4), z0 + 4]);
    for (let k = 0; k < 3; k++) hc.box({ name: 'BridgePost', s: [3.2 - k * 0.2, 2.6, 3.2 - k * 0.2], p: [0, 1.3 + k * 2.6, 0], r: [0, k * 9, 0], c: k % 2 ? '#7a746a' : '#8a8478', m: 'Slate', studs: 'top', collide: true });
    hc.box({ name: 'PostCap', s: [3.8, 0.8, 3.8], p: [0, 8.2, 0], c: accent, studs: 'top' });
    const lamp = hc.box({ name: 'PostLamp', s: [1.2, 1.4, 1.2], p: [0, 9.3, 0], c: PAL.lamp, m: 'Neon' });
    lamp.tag('CampLight');
    E.flag(c, [side * (W / 2 + 0.6), yAt(zs1 - 6) + 2.4, zs1 - 6], accent, { h: 9 });
  }
  marker(c, 'BridgeHubEnd', [0, yAt(z0 + 6) + 3, z0 + 6], 0);
  marker(c, 'BridgeIslandEnd', [0, yAt(z1) + 3, z1 + 6], 0);
  return g;
}

// A huge walled paddock behind the hatchery: the dinos you hatch roam here (heavy ones are big, and rare).
function buildPaddock(c, accent, idx) {
  const g = c.group('Paddock');
  const W = PADDOCK_W, D = PADDOCK_D, WALL = 11;
  const R = rng(8800 + idx);
  const ground = g.group('Ground', 'Folder');
  ground.box({ name: 'PaddockGround', s: [W, 0.6, D], p: [0, 0.5, 0], c: '#7aa84a', studs: 'top', collide: true });
  for (let k = 0; k < 10; k++) ground.box({ name: 'DirtPatch', s: [10 + R() * 12, 0.06, 8 + R() * 12], p: [(R() - 0.5) * (W - 24), 0.83, (R() - 0.5) * (D - 24)], r: [0, R() * 90, 0], c: '#a07a4a', m: 'Sand', shadow: false });
  const GAP = 9; // half-width of the gate opening
  const logWall = (x0, z0, x1, z1, gapFrom, gapTo) => {
    const L = Math.hypot(x1 - x0, z1 - z0);
    const n = Math.round(L / 3.1);
    for (let k = 0; k <= n; k++) {
      const t = k / n;
      const x = x0 + (x1 - x0) * t, z = z0 + (z1 - z0) * t;
      const along = (x1 - x0) !== 0 ? x : z;
      if (gapFrom !== undefined && along > gapFrom && along < gapTo) continue;
      const h = WALL + (R() - 0.5) * 1.8;
      g.cyl({ name: 'PalisadeLog', axis: 'y', len: h, d: 2.6, p: [x, 0.8 + h / 2, z], c: k % 2 ? '#7d5733' : '#8a6238', collide: true });
      g.box({ name: 'LogTip', s: [1.6, 1.4, 1.6], p: [x, 0.8 + h + 0.5, z], r: [45, 0, 45], c: '#6b4a2b' });
    }
    const lerp = (v) => { const t = ((x1 - x0) !== 0 ? (v - x0) / (x1 - x0) : (v - z0) / (z1 - z0)); return [x0 + (x1 - x0) * t, z0 + (z1 - z0) * t]; };
    const spans = gapFrom === undefined ? [[x0, z0, x1, z1]] : [[x0, z0, ...lerp(gapFrom - 2.1)], [...lerp(gapTo + 2.1), x1, z1]];
    for (const [ax, az, bx, bz] of spans) for (const y of [3, 8]) g.beam([ax, y, az], [bx, y, bz], 0.8, 0.8, { name: 'PalisadeRail', c: '#5e3f22', collide: true });
  };
  logWall(-W / 2, -D / 2, -W / 2, D / 2);
  logWall(W / 2, -D / 2, W / 2, D / 2);
  logWall(-W / 2, D / 2, W / 2, D / 2);
  logWall(-W / 2, -D / 2, W / 2, -D / 2, -GAP - 3, GAP + 3);
  // gate towers on the aisle
  for (const gx of [-GAP - 3, GAP + 3]) {
    for (let k = 0; k < 7; k++) g.box({ name: 'GateTower', s: [3.6 - k * 0.08, 2.5, 3.6 - k * 0.08], p: [gx, 0.8 + 1.25 + k * 2.5, -D / 2], r: [0, k * 8, 0], c: k % 2 ? '#7a746a' : '#8a8478', m: 'Slate', studs: 'top', collide: true });
    const beacon = g.box({ name: 'GateBeacon', s: [1.2, 1.2, 1.2], p: [gx, 19.1, -D / 2], c: '#ff3b2a', m: 'Neon' });
    beacon.tag('BlinkLight');
    g.box({ name: 'GateTowerCap', s: [4.2, 0.8, 4.2], p: [gx, 18.3, -D / 2], c: accent, studs: 'top' });
  }
  g.box({ name: 'GateBeam', s: [GAP * 2 + 9, 1.8, 2.2], p: [0, 17, -D / 2], c: '#5e3f22', studs: 'top' });
  const sign = g.box({ name: 'PaddockSign', s: [16, 3.4, 0.5], p: [0, 14.4, -D / 2 - 0.4], c: '#2a2c31' });
  g.box({ name: 'PaddockSignFrame', s: [16.8, 4.2, 0.4], p: [0, 14.4, -D / 2 - 0.1], c: accent, studs: 'top' });
  surfaceLabel(sign, 'Front', 'DINO PADDOCK', { pps: 30, color: '#fff4d6', color2: accent });
  surfaceLabel(sign, 'Back', 'DINO PADDOCK', { name: 'LabelBack', pps: 30, color: '#fff4d6', color2: accent });
  // two hinged log doors, built closed; the client swings them open when you walk up (CampView)
  for (const side of [-1, 1]) {
    const dg = g.group('PaddockDoor');
    dg.parent.attr('Side', side).tag('PaddockDoor');
    const hx = side * (GAP - 0.2);
    const W2 = GAP - 0.5;
    const dc = dg.at([hx, 0.8, -D / 2 + 0.6]);
    marker(dc, 'DoorHinge', [0, 4.5, 0], 0, { s: [0.4, 0.4, 0.4] });
    dc.box({ name: 'GateDoor', s: [W2, 9, 0.8], p: [-side * W2 / 2, 4.5, 0], c: '#8a6238', m: 'WoodPlanks', studs: 'sides', collide: true });
    for (const y of [2, 7]) dc.box({ name: 'DoorBrace', s: [W2 - 0.4, 0.8, 0.4], p: [-side * W2 / 2, y, -0.55], c: '#6b4a2b', m: 'WoodPlanks' });
    dc.beam([-side * 0.6, 2, -0.6], [-side * (W2 - 0.6), 7, -0.6], 0.6, 0.35, { name: 'DoorBrace', c: '#6b4a2b', m: 'WoodPlanks' });
    dc.box({ name: 'DoorBand', s: [1.2, 9.1, 0.9], p: [-side * 0.6, 4.5, 0], c: '#3a3d42', m: 'Metal' });
  }
  const board = g.box({ name: 'CapacityBoard', s: [7, 2.6, 0.4], p: [GAP + 9, 6, -D / 2 - 1.8], c: '#2a2c31' });
  surfaceLabel(board, 'Front', '0 / 6', { name: 'CapacityText', pps: 40, color: '#eaffd8', color2: '#5fd35a' });
  g.box({ name: 'BoardPost', s: [0.6, 5, 0.6], p: [GAP + 9, 2.5, -D / 2 - 1.6], c: PAL.woodLo });
  // interior: a lake, troughs, a rock hill to climb, shade trees, ferns
  E.pond(g, [-W / 2 + 26, 0.85, D / 2 - 22], 38, 26, { seed: 8900 + idx, depth: 2.4 });
  for (const [x, z] of [[W / 2 - 18, -8], [W / 2 - 18, 14]]) {
    const tr = g.at([x, 0.8, z]);
    tr.box({ name: 'FeedTrough', s: [12, 1.8, 3], p: [0, 0.9, 0], c: '#5e3f22', m: 'WoodPlanks', collide: true });
    tr.box({ name: 'Greens', s: [11, 0.6, 2.2], p: [0, 1.9, 0], c: '#4fb043', studs: 'top' });
    tr.box({ name: 'Meat', s: [2, 0.9, 1.4], p: [3.6, 2.3, 0], r: [0, 25, 0], c: '#c8452a' });
  }
  const hill = g.at([W / 2 - 22, 0.8, D / 2 - 18]);
  for (let t = 0; t < 4; t++) hill.box({ name: 'RockHill', s: [20 - t * 4.4, 2.2, 16 - t * 3.4], p: [0, 1.1 + t * 2.2, 0], r: [0, t * 9, 0], c: PAL.cliff[t % 5], m: 'Slate', studs: 'top', collide: true });
  for (let k = 0; k < 6; k++) E.rock(g, [(R() - 0.5) * (W - 30), 0.8, (R() - 0.5) * (D - 30)], 1.8 + R() * 1.6, 8950 + idx * 10 + k);
  for (const [x, z, h] of [[-W / 2 + 10, -D / 2 + 12, 22], [W / 2 - 10, -D / 2 + 10, 20], [-W / 2 + 12, 4, 24], [W / 2 - 8, D / 2 - 6, 18], [6, D / 2 - 8, 20]]) E.jungleTree(g, [x, 0.8, z], h, 8990 + idx + x, { canopy: 8 });
  for (let k = 0; k < 14; k++) E.grassTufts(g, [(R() - 0.5) * (W - 12), 0.8, (R() - 0.5) * (D - 12)], 8100 + idx * 20 + k, { n: 4, spread: 5 });
  // markers for the roaming dinos
  marker(g, 'PaddockBounds', [0, 1.1, 0], 0, { s: [W - 22, 0.4, D - 22] });
  marker(g, 'PaddockPondArea', [-W / 2 + 26, 0.4, D / 2 - 22], 0, { s: [28, 0.4, 18] });
  marker(g, 'PaddockGateIn', [0, 1.1, -D / 2 + 8], 0);
}

// THE HATCHERY: an open pavilion of 12 wide heated nests (two rows of six) along the centre aisle.
// Nests are big: a heavy egg can stand 6 studs tall. (v2: W x D grew from 60 x 40, with more room between nests.)
function buildHatchery(c, accent, idx, W = 74, D = 48) {
  const g = c.group('IncubatorShed');
  marker(g, 'HatcheryAnchor', [0, 0, 0], 0); // IslandView pivots the HatcheryT2/T3 kit here
  const H = 12;
  const post = '#7d5733', roofA = '#c8452a', roofB = '#a8361f';
  const rowZ = D * 0.35; // front + back rows; the third row (nests 13-18, the hatchery upgrade) runs down the middle
  const xs = [-W * 0.44, -W * 0.3, -W * 0.16, W * 0.16, W * 0.3, W * 0.44];
  g.box({ name: 'ShedFloor', s: [W, 0.4, D], p: [0, 0.2, 0], c: '#b98450', m: 'WoodPlanks', collide: true });
  g.box({ name: 'AisleRunner', s: [6, 0.06, D], p: [0, 0.44, 0], c: accent, shadow: false });
  const postX = (W * 0.16 + W * 0.3) / 2 - 0.2;
  for (const x of [-W / 2 + 0.6, -postX, postX, W / 2 - 0.6]) for (const z of [-D / 2 + 0.6, 0, D / 2 - 0.6]) {
    if (z === 0) continue; // (no middle posts: the third row's hatchlings walk straight out to the aisle there)
    g.box({ name: 'PavilionPost', s: [1.2, H, 1.2], p: [x, H / 2 + 0.4, z], c: post, studs: 'top', collide: true });
  }
  // roof: two pitched halves over the nest rows, a ridge over the aisle
  for (const side of [-1, 1]) {
    const roof = g.at([side * W / 4, H + 1.2, 0], [0, 0, -side * 9]);
    for (let k = 0; k < 10; k++) roof.box({ name: 'RoofPanel', s: [W / 2 + 2 - (k % 2) * 0.06, 0.5 - (k % 2) * 0.04, (D + 2) / 10], p: [0, 0, -(D + 2) / 2 + (k + 0.5) * ((D + 2) / 10)], c: k % 2 ? roofA : roofB, studs: 'top' });
  }
  g.box({ name: 'RoofRidge', s: [2.4, 1, D + 2.4], p: [0, H + 1.2 + (W / 4) * Math.tan((9 * Math.PI) / 180) + 0.6, 0], c: accent, studs: 'top' });
  const sign = g.box({ name: 'ShedEndSign', s: [16, 3, 0.4], p: [0, H - 1.5, -D / 2 - 0.4], c: '#2a2c31' });
  surfaceLabel(sign, 'Front', 'HATCHERY', { pps: 30, color: '#ffe8c8', color2: '#ffb02e' });
  g.box({ name: 'ShedEndSignFrame', s: [16.8, 3.8, 0.3], p: [0, H - 1.5, -D / 2 - 0.15], c: accent });
  // warm light strips under each roof half
  for (const side of [-1, 1]) {
    const strip = g.box({ name: 'HeatStrip', s: [0.4, 0.3, D - 4], p: [side * W * 0.3, H - 0.4, 0], c: '#ffb070', m: 'SmoothPlastic' });
    E.pointLight(strip, [1, 0.6, 0.3], 20, 0.45);
  }
  // lamp beams the heat lamps hang from (one per nest row)
  for (const z of [-rowZ, 0, rowZ]) g.box({ name: 'LampBeam', s: [W - 2, 0.4, 0.5], p: [0, 11.05, z], c: '#5e3f22' });
  // nests: front row slots 1-6, back row 7-12, the middle row 13-18 (left to right; tarped until the upgrade)
  const nests = g.group('Nests', 'Folder');
  let n = 1;
  for (const z of [-rowZ, rowZ, 0]) for (const x of xs) {
    buildNest(nests, [x, 0.4, z], n, accent, 7000 + idx * 31 + n);
    n++;
  }
  // supplies by the entrance
  for (let k = 0; k < 3; k++) g.box({ name: 'StrawBale', s: [2.6, 1.3, 1.6], p: [-W / 2 + 3, k * 1.3 + 0.65, -D / 2 - 1.8], r: [0, k * 8, 0], c: '#e3c56a', studs: 'top' });
  E.crate(g, [W / 2 - 3, 0, -D / 2 - 2.2], 0.9, { yaw: 10, stencil: '#c8452a' });
}

function buildNest(ctx, p, n, accent, seed) {
  const R = rng(seed);
  const g = ctx.group('Nest' + n);
  g.parent.attr('Slot', n);
  g.parent.tag('Nest');
  const c = g.at(p);
  c.cyl({ name: 'NestPad', axis: 'y', len: 0.5, d: 8, p: [0, 0.25, 0], c: '#8a5a33' });
  for (let k = 0; k < 11; k++) {
    const a = (k / 11) * Math.PI * 2;
    c.box({ name: 'Straw', s: [2.6, 0.9, 1], p: [Math.cos(a) * 3.5, 0.7, Math.sin(a) * 3.5], r: [0, -E.deg(a) + 90 + R() * 14, R() * 10], c: k % 2 ? '#e3c56a' : '#d1ad4c', studs: 'top' });
  }
  c.cyl({ name: 'NestInner', axis: 'y', len: 0.1, d: 6, p: [0, 0.55, 0], c: '#c49a50' });
  const host = marker(c, 'EggPoint', [0, 0.6, 0], 0, { s: [0.4, 0.4, 0.4] });
  host.attr('Slot', n);
  const pa = new Inst('Attachment', 'PromptAttachment');
  pa.set('CFrame', 'CFrame', new CF(0, 2.6, 0));
  host.add(pa);
  const pr = new Inst('ProximityPrompt', 'HatchPrompt');
  pr.set('ActionText', 'string', 'Hatch Egg').set('ObjectText', 'string', 'Nest ' + n).set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 10).set('HoldDuration', 'float', 0.6).set('RequiresLineOfSight', 'bool', false).set('Enabled', 'bool', false);
  pr.attr('CampAction', 'Hatch').attr('Slot', n);
  pa.add(pr);
  // heat lamp hanging from the roof
  c.box({ name: 'LampRod', s: [0.2, 1.4, 0.2], p: [0, 9.85, 0], c: '#3a3d42', m: 'Metal' });
  c.cyl({ name: 'LampHood', axis: 'y', len: 1, d: 2.6, p: [0, 8.8, 0], c: '#2b2d31', m: 'Metal' });
  const bulb = c.cyl({ name: 'LampBulb', axis: 'y', len: 0.3, d: 1.8, p: [0, 8.2, 0], c: '#ff7a2a', m: 'Neon' });
  bulb.tag('HeatLamp');
  c.box({ name: 'StatusPole', s: [0.25, 2.4, 0.25], p: [4.3, 1.2, -2.6], c: '#3a3d42' });
  const st = c.box({ name: 'StatusLight', s: [0.6, 0.6, 0.6], p: [4.3, 2.6, -2.6], c: '#6b6f75', m: 'Neon' });
  st.tag('NestStatus');
  // lock cover for nests you haven't built yet (shown by the client)
  const cover = c.group('LockCover');
  cover.box({ name: 'Tarp', s: [7.4, 2, 7.4], p: [0, 1.5, 0], c: '#4a5a3a', m: 'Fabric' });
  cover.box({ name: 'TarpTie', s: [7.5, 0.2, 0.3], p: [0, 2.05, 0], c: '#2b2d31' });
  cover.box({ name: 'TarpTie', s: [0.3, 0.2, 7.5], p: [0, 2.05, 0], c: '#2b2d31' });
  cover.box({ name: 'LockBody', s: [1.2, 1, 0.4], p: [0, 2.9, -3.75], c: '#ffcf3a', m: 'Metal' });
  cover.box({ name: 'LockShackle', s: [0.8, 0.8, 0.2], p: [0, 3.6, -3.75], c: '#b8bec4', m: 'Metal' });
}

// The TROPHY HALL: a stone pavilion with a statue plinth for every boss (the client raises bronze / silver / gold /
// glowing statues by tier at TrophySpot_<Boss>) and a stand for your crafted gear.
// Local frame (as v1): the back wall is at -X, the open colonnade faces +X.
const TROPHIES = [['TyrantKing', 'TYRANT KING'], ['Titan', 'PLAINS TITAN'], ['Tidebreaker', 'TIDEBREAKER'], ['Scythe', 'SCYTHE KING'], ['Frostfang', 'FROSTFANG'], ['DawnKing', 'DAWN KING']];
function buildTrophyHall(c, accent, idx) {
  const g = c.group('TrophyHall');
  const DX = 40, WZ = 36; // depth (x) x width (z)
  g.box({ name: 'HallFloor', s: [DX, 0.3, WZ], p: [0, 0.15, 0], c: '#cfc3a4', m: 'Slate', studs: 'top', collide: true });
  g.box({ name: 'HallSteps', s: [2.4, 0.18, WZ - 6], p: [DX / 2 + 1.1, 0.09, 0], c: '#bfb394', m: 'Slate', collide: true });
  g.box({ name: 'BackWall', s: [1, 9, WZ], p: [-DX / 2 + 0.5, 4.8, 0], c: '#e9dfc4', studs: 'sides', collide: true });
  g.box({ name: 'BackTrim', s: [1.2, 0.6, WZ + 0.4], p: [-DX / 2 + 0.5, 9.4, 0], c: accent });
  for (const side of [-1, 1]) {
    g.box({ name: 'SideWall', s: [DX - 6, 9, 1], p: [-3, 4.8, side * (WZ / 2 - 0.5)], c: '#e9dfc4', studs: 'sides', collide: true });
    g.box({ name: 'SideTrim', s: [DX - 6, 0.6, 1.2], p: [-3, 9.4, side * (WZ / 2 - 0.5)], c: accent });
  }
  for (const z of [-WZ / 2 + 1, -WZ / 6, WZ / 6, WZ / 2 - 1]) {
    g.box({ name: 'Column', s: [1.6, 11, 1.6], p: [DX / 2 - 1, 5.8, z], c: '#e9dfc4', studs: 'top', collide: true });
    g.box({ name: 'ColumnCap', s: [2.2, 0.6, 2.2], p: [DX / 2 - 1, 11.6, z], c: '#d4c49d' });
  }
  g.box({ name: 'Lintel', s: [1.8, 1.2, WZ], p: [DX / 2 - 1, 12.4, 0], c: '#e9dfc4', studs: 'top' });
  for (let k = 0; k < 7; k++) g.box({ name: 'Beam', s: [DX - 2, 0.6, 0.8], p: [0, 12.1, -WZ / 2 + 2 + k * ((WZ - 4) / 6)], c: PAL.woodLo });
  g.box({ name: 'Roof', s: [DX + 1.5, 0.8, WZ + 1.5], p: [0, 13.1, 0], c: '#c8452a', studs: 'top' });
  const sign = g.box({ name: 'HallSign', s: [0.4, 2.2, 13], p: [DX / 2 - 0.05, 14.7, 0], c: '#2a2c31' });
  g.box({ name: 'HallSignFrame', s: [0.3, 2.8, 13.6], p: [DX / 2 - 0.3, 14.7, 0], c: accent });
  surfaceLabel(sign, 'Right', 'TROPHY HALL', { pps: 30, color: '#ffe9a0', color2: '#ffb02e' });
  const plinth = (x, z, boss, label) => {
    const pc = g.at([x, 0.3, z]);
    pc.box({ name: 'Plinth', s: [6.4, 1.6, 6.4], p: [0, 0.8, 0], c: '#8a8478', m: 'Slate', studs: 'top', collide: true });
    pc.box({ name: 'PlinthTop', s: [5.6, 0.4, 5.6], p: [0, 1.8, 0], c: '#5d5a55', m: 'Slate' });
    pc.box({ name: 'PlinthTrim', s: [6.6, 0.3, 6.6], p: [0, 0.15, 0], c: accent });
    const plaque = pc.box({ name: 'Plaque', s: [0.2, 0.9, 4], p: [3.25, 0.85, 0], c: '#2a2c31' });
    surfaceLabel(plaque, 'Right', label, { pps: 40, color: '#ffe9a0', color2: '#ffb02e' });
    marker(pc, 'TrophySpot_' + boss, [0, 2.05, 0], 90);
  };
  // two rows of three, the first boss front-left; the back row stands a step higher so it reads over the front
  TROPHIES.forEach(([boss, label], k) => {
    const back = k >= 3;
    const z = [-11, 0, 11][k % 3];
    if (back) g.box({ name: 'Dais', s: [9, 0.6, WZ - 6], p: [-11, 0.6, 0], c: '#bfb394', m: 'Slate', collide: true });
    plinth(back ? -11 : 2, z, boss, label);
  });
  // the gear stand greets you at the door
  const rack = g.at([13, 0.3, 0]);
  rack.box({ name: 'RackBase', s: [2.2, 0.6, 3], p: [0, 0.3, 0], c: PAL.woodLo, studs: 'top', collide: true });
  marker(rack, 'GearStand', [0, 2.6, 0], 90);
  for (const z of [-7, 7]) {
    const lens = g.box({ name: 'SpotLens', s: [0.8, 0.1, 0.8], p: [-4, 11.7, z], c: '#ffe9a0', m: 'Neon' });
    E.pointLight(lens, [1, 0.9, 0.7], 18, 0.8);
  }
  void idx;
}

function buildGarage(c, accent, idx) {
  // A proper vehicle bay: big enough for the Titan Transport (10.7 x 10.9 x 22.4), a roll-up door that opens
  // for the roll-out cutscene, a lit workshop inside. Origin = bay centre on the plot pad; the door faces -Z.
  const g = c.group('Garage');
  const gm = g.parent;
  gm.attr('DoorOpen', false);
  marker(g, 'GarageAnchor', [0, 0, 0], 0); // IslandView pivots the GarageT2 (workshop) / T3 (hangar) kit here
  const W = 24, D = 26, H = 15, DW = 18, DH = 13;
  const wallA = '#e9dfc4', wallB = '#ddd0b0', trim = '#2b2d31', yellow = '#f2b632';
  // floor: concrete with a yellow bay box, tyre marks and a hazard lip at the door
  g.box({ name: 'GarageFloor', s: [W - 1, 0.24, D - 1], p: [0, 0.12, 0], c: '#9a9ea6', m: 'Concrete', collide: true });
  // (bay lines stop short of the tool chest; the hazard stripes sit just inside the door, never under it)
  for (const [x, z, w, d] of [[-6.2, -0.1, 0.35, 17.8], [6.2, -0.1, 0.35, 17.8], [0, 8.8, 12.75, 0.35]]) g.box({ name: 'ParkLine', s: [w, 0.04, d], p: [x, 0.26, z], c: yellow, shadow: false });
  for (let k = 0; k < 9; k++) g.box({ name: 'HazardStripe', s: [1.4, 0.04, 1.0], p: [-DW / 2 + 1.2 + k * 2.0, 0.26, -D / 2 + 2.5], r: [0, 35, 0], c: k % 2 ? '#1d1e21' : yellow, shadow: false });
  // walls: two-tone plank courses (studded sides) with an accent band
  const courses = 5;
  for (let k = 0; k < courses; k++) {
    const y = 0.24 + (k + 0.5) * ((H - 0.24) / courses), h = (H - 0.24) / courses;
    const col = k % 2 ? wallA : wallB;
    g.box({ name: 'BackWall', s: [W, h, 1], p: [0, y, D / 2 - 0.5], c: col, studs: 'sides', collide: true });
    g.sym((sd) => sd.box({ name: 'SideWall', s: [1, h, D - 2], p: [W / 2 - 0.5, y, 0], c: col, studs: 'sides', collide: true }));
  }
  g.sym((sd) => {
    // (the band ends at the corner posts: overlapping them it flickered)
    sd.box({ name: 'WallBand', s: [1.08, 1.0, D - 4.2], p: [W / 2 - 0.5, 3.4, 0], c: accent, shadow: false });
    for (const z of [-D / 2 + 0.9, D / 2 - 0.9]) sd.box({ name: 'CornerPost', s: [1.9, H + 0.62, 1.9], p: [W / 2 - 0.9, (H + 0.62) / 2, z], c: trim, studs: 'top', collide: true });
    // door jambs + side windows
    sd.box({ name: 'DoorJamb', s: [(W - DW) / 2 - 1.8, DH, 1.2], p: [DW / 2 + ((W - DW) / 2 - 1.8) / 2, DH / 2 + 0.24, -D / 2 + 0.6], c: wallA, studs: 'sides', collide: true });
    // (the stripe sits a hair proud of the jamb on every face: flush, it flickered)
    sd.box({ name: 'JambStripe', s: [0.56, DH, 1.34], p: [DW / 2 + 0.25, DH / 2 + 0.24, -D / 2 + 0.6], c: yellow });
    sd.box({ name: 'Window', s: [0.2, 3.2, 6], p: [W / 2 + 0.02, 9, 2], c: '#9cf0ff', m: 'Glass', t: 0.35 });
    sd.box({ name: 'WindowFrame', s: [0.4, 0.4, 6.6], p: [W / 2 + 0.05, 10.8, 2], c: trim });
    sd.box({ name: 'WindowFrame', s: [0.4, 0.4, 6.6], p: [W / 2 + 0.05, 7.2, 2], c: trim });
    // wall lamps either side of the door
    sd.box({ name: 'WallLampArm', s: [0.4, 0.4, 1.2], p: [DW / 2 + 1.4, 8.6, -D / 2 - 0.4], c: trim });
    const lamp = sd.box({ name: 'WallLamp', s: [1.0, 1.4, 1.0], p: [DW / 2 + 1.4, 7.8, -D / 2 - 1.0], c: '#ffe2a8', m: 'SmoothPlastic' });
    lamp.tag('CampLight');
    E.pointLight(lamp, [1, 0.82, 0.55], 16, 0.6);
  });
  // header over the door, rolled-door housing, roof
  g.box({ name: 'DoorHeader', s: [DW, H - DH - 0.24, 1.2], p: [0, DH + 0.24 + (H - DH - 0.24) / 2, -D / 2 + 0.6], c: wallA, studs: 'sides', collide: true });
  g.cyl({ name: 'DoorHousing', axis: 'x', len: DW + 0.6, d: 1.8, p: [0, DH + 0.9, -D / 2 + 2.0], c: '#5d5a55', m: 'Metal' });
  g.box({ name: 'Roof', s: [W + 2.4, 1.2, D + 2.4], p: [0, H + 0.6, 0], c: '#3a3d42', studs: 'top', collide: true });
  g.box({ name: 'RoofTrim', s: [W + 2.8, 0.6, D + 2.8], p: [0, H + 0.1, 0], c: yellow });
  for (let k = 0; k < 12; k++) g.box({ name: 'TrimStripe', s: [1.2, 0.62, 0.2], p: [-W / 2 + 0.6 + k * 2.08, H + 0.1, -D / 2 - 1.42], r: [0, 0, 35], c: '#1d1e21', shadow: false });
  // big rooftop sign
  const sign = g.box({ name: 'GarageSign', s: [16, 3.4, 0.6], p: [0, H + 3.2, -D / 2 + 0.4], c: '#2a2c31' });
  g.box({ name: 'GarageSignFrame', s: [16.8, 4.2, 0.4], p: [0, H + 3.2, -D / 2 + 0.75], c: accent, studs: 'top' });
  g.sym((sd) => sd.box({ name: 'SignLeg', s: [0.6, 2.4, 0.6], p: [6, H + 1.4, -D / 2 + 1.0], c: trim }));
  surfaceLabel(sign, 'Front', 'GARAGE', { pps: 30, color: '#ffffff', color2: accent });
  // roll-up door: slats (client animates them up into the housing when the plot's DoorOpen is true)
  const door = g.group('RollerDoor');
  const slats = 10, sh = DH / slats;
  for (let k = 0; k < slats; k++) {
    const sl = door.box({ name: 'Slat', s: [DW - (k % 2) * 0.05, sh, 0.35 - (k % 2) * 0.04], p: [0, 0.24 + sh * (k + 0.5), -D / 2 + 1.25], c: k % 2 ? '#a2a7ad' : '#8f949b', m: 'Metal', collide: true });
    sl.attr('Index', k + 1);
  }
  door.box({ name: 'DoorHandle', s: [2.4, 0.3, 0.3], p: [0, 0.95, -D / 2 + 1.0], c: trim }); // (mid-slat: on the slat's edge it flickered)
  door.parent.attr('Height', DH).attr('Slats', slats);
  // interior: strip lights, tool wall, tyre rack, red tool chest, workbench, lift posts, oil drum
  for (const x of [-5, 5]) {
    const strip = g.box({ name: 'GarageLight', s: [0.8, 0.3, 16], p: [x, H - 0.5, 1], c: '#fff1d0', m: 'SmoothPlastic' }); // lit, not glowing (the bloom blew the garage out)
    strip.tag('GarageLight');
    E.pointLight(strip, [1, 0.95, 0.85], 18, 0.45);
  }
  const tw = g.at([0, 0, D / 2 - 1.2]);
  tw.box({ name: 'Pegboard', s: [10, 5, 0.25], p: [-4, 7, 0], c: '#8a5a33' });
  for (let k = 0; k < 6; k++) tw.box({ name: 'Tool', s: [0.3, 1.6 + (k % 3) * 0.5, 0.15], p: [-7.6 + k * 1.45, 7, -0.2], r: [0, 0, (k % 2 ? 1 : -1) * 8], c: k % 2 ? '#b8bec4' : '#d6402b', m: 'Metal' });
  tw.box({ name: 'Workbench', s: [9, 0.6, 2.4], p: [-4, 3.2, -1.3], c: '#8a5a33', m: 'WoodPlanks', collide: true });
  for (const x of [-8, 0]) tw.box({ name: 'BenchLeg', s: [0.5, 2.9, 2], p: [x, 1.6, -1.3], c: trim });
  tw.box({ name: 'Vise', s: [0.9, 0.7, 0.8], p: [-1.6, 3.85, -1.5], c: '#2f6b3a', m: 'Metal' });
  const chest = tw.at([6.5, 0.24, -1.2]);
  chest.box({ name: 'ToolChest', s: [3.2, 4.2, 1.8], p: [0, 2.1, 0], c: '#d6402b', studs: 'top', collide: true });
  for (let k = 0; k < 4; k++) chest.box({ name: 'Drawer', s: [2.8, 0.12, 0.1], p: [0, 0.8 + k * 0.9, -0.92], c: '#b8bec4', m: 'Metal' });
  g.sym((sd) => {
    sd.box({ name: 'LiftPost', s: [0.9, 9, 0.9], p: [8.4, 4.74, -2], c: yellow, m: 'Metal' });
    sd.box({ name: 'LiftArm', s: [2.4, 0.4, 0.6], p: [7.4, 1.4, -2], c: trim, m: 'Metal' });
  });
  for (let k = 0; k < 3; k++) g.cyl({ name: 'TyreStack', axis: 'y', len: 1.1, d: 3, p: [-9.2, 0.84 + k * 1.12, -7], c: '#26272b' });
  E.barrel(g, [-9.4, 0.24, 3.4], { color: '#e8473a' }); // (clear of the lift post; it used to stand inside it)
  // outside: cones + jerrycans by the door
  for (const sx of [-1, 1]) {
    const cone = g.at([sx * 7.6, 0, -D / 2 - 2.2]);
    cone.box({ name: 'ConeBase', s: [1.3, 0.2, 1.3], p: [0, 0.1, 0], c: '#1d1e21' });
    cone.wedgeF({ name: 'Cone', s: [0.9, 1.6, 0.45], p: [0, 1.0, -0.22], face: 'front', c: '#f08a24' });
    cone.wedgeF({ name: 'Cone', s: [0.9, 1.6, 0.45], p: [0, 1.0, 0.22], face: 'back', c: '#f08a24' });
    cone.box({ name: 'ConeStripe', s: [0.8, 0.25, 0.95], p: [0, 1.1, 0], c: '#ffffff', shadow: false });
  }
  // cutscene + gameplay markers (door pivot faces out of the bay)
  marker(g, 'VehicleSpawn', [0, 0.3, 0.5], 0, { s: [6, 1, 12] });
  marker(g, 'GarageDoorPivot', [0, 0.3, -D / 2], 0);
  marker(g, 'RollOutPoint', [0, 0.3, -D / 2 - 12], 0);
  // the door button panel (prompt) on the right of the door, outside
  const host = marker(g, 'GaragePromptHost', [DW / 2 + 1.6, 4, -D / 2 - 0.9]);
  g.box({ name: 'DoorButtonPanel', s: [1.4, 2.0, 0.4], p: [DW / 2 + 1.6, 4, -D / 2 - 0.25], c: '#2b2d31' });
  g.box({ name: 'DoorButton', s: [0.7, 0.7, 0.25], p: [DW / 2 + 1.6, 4.3, -D / 2 - 0.5], c: '#5fd35a', m: 'Neon' });
  const a = new Inst('Attachment', 'PromptAttachment');
  host.add(a);
  const pr = new Inst('ProximityPrompt', 'GaragePrompt');
  pr.set('ActionText', 'string', 'Take Vehicle').set('ObjectText', 'string', 'Garage').set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 18).set('HoldDuration', 'float', 0).set('RequiresLineOfSight', 'bool', false);
  pr.attr('CampAction', 'Garage');
  a.add(pr);
  void gm;
}

// ============================================================== TIME GATE
function buildTimeGate(H) {
  const g = H.group('TimeGate');
  const gm = g.parent;
  const ground = g.group('Ground', 'Folder');
  const z0 = GATE.deckZ0, z1 = GATE.deckZ1;
  // launch ramp + deck
  const rampLen = 14;
  const rampY0 = Y.road, rampY1 = Y.deck;
  const rampH = rampY1 - rampY0;
  ground.wedgeF({ name: 'LaunchRamp', s: [26, rampH, rampLen], p: [0, rampY0 + rampH / 2, z0 + rampLen / 2], face: 'back', c: '#8a8478', m: 'Slate', collide: true });
  ground.box({ name: 'Deck', s: [70, rampH + 2, z0 - z1], p: [0, Y.deck - (rampH + 2) / 2, (z0 + z1) / 2], c: '#7a746a', m: 'Slate', studs: 'top', collide: true });
  ground.box({ name: 'DeckTop', s: [64, 0.2, z0 - z1 - 4], p: [0, Y.deck + 0.1, (z0 + z1) / 2 - 1], c: '#9a9488', m: 'Slate', collide: true });
  // drive lane into the portal with guide lights
  g.box({ name: 'DriveLane', s: [16, 0.08, z0 - GATE.z - 1], p: [0, Y.deck + 0.24, (z0 + GATE.z) / 2 - 0.5], c: '#3a3d42', m: 'DiamondPlate', shadow: false });
  for (let k = 0; k < 7; k++) for (const side of [-1, 1]) {
    const gl = g.box({ name: 'GuideLight', s: [0.8, 0.3, 1.4], p: [side * 8.6, Y.deck + 0.3, z0 - 2 - k * 4.4], c: '#4a9bff', m: 'Neon', shadow: false });
    gl.attr('Seq', k).tag('GuideLight');
  }
  for (let k = 0; k < 12; k++) g.box({ name: 'HazardEdge', s: [2.8, 0.1, 1], p: [-31 + k * 5.6, Y.deck + 0.25, z0 - 0.5], r: [0, 30, 0], c: k % 2 ? '#1d1e21' : '#f2c230', shadow: false });
  for (const side of [-1, 1]) for (let k = 0; k < 4; k++) g.box({ name: 'RampRail', s: [1, 1.2, 4], p: [side * 13.5, Y.road + 0.6 + k * 1.4, z0 + 7 - k * 3.4], c: '#f2c230', studs: 'top' });
  // the gate itself: hexagonal studded frame, pylons, inner spinning ring, membrane
  // the bottom beam sits flush in the deck so vehicles drive straight through the opening
  const cy = Y.deck + GATE.R * Math.sin(Math.PI / 3) - 2.5;
  const frame = g.group('Frame');
  const F = frame.at([0, cy, GATE.z]);
  const hexPts = (r, rot = 0) => Array.from({ length: 6 }, (_, k) => { const a = (k * 60 + rot) * Math.PI / 180; return [Math.cos(a) * r, Math.sin(a) * r]; });
  const P6 = hexPts(GATE.R);
  for (let k = 0; k < 6; k++) {
    const [ax, ay] = P6[k], [bx, by] = P6[(k + 1) % 6];
    F.beam([ax, ay, 0], [bx, by, 0], 5, GATE.beam, { name: 'GateBeam', c: '#3a3d42', m: 'Slate', studs: 'top', extend: 1.5, up: [0, 0, 1] });
    F.beam([ax * 0.86, ay * 0.86, -2.25], [bx * 0.86, by * 0.86, -2.25], 0.6, 0.8, { name: 'GateNeonTrim', c: '#f2b632', m: 'Metal', up: [0, 0, 1] });
    F.beam([ax * 0.86, ay * 0.86, 2.25], [bx * 0.86, by * 0.86, 2.25], 0.6, 0.8, { name: 'GateNeonTrim', c: '#f2b632', m: 'Metal', up: [0, 0, 1] });
    const node = F.at([ax, ay, 0], [0, 0, k * 60]);
    node.box({ name: 'GateNode', s: [6.2, 6.2, 6.6], c: '#2b2d31', m: 'Metal', studs: 'all' });
    node.box({ name: 'NodeCore', s: [3, 3, 6.8], c: '#4a9bff', m: 'Neon' }).tag('GateNode');
    node.box({ name: 'NodeClamp', s: [7, 1.2, 7], c: '#f2b632', m: 'Metal' });
  }
  // sign plate on top
  const top = F.at([0, GATE.R * Math.sin(Math.PI / 3) + 4.2, 0]);
  const plate = top.box({ name: 'GateSign', s: [20, 3.6, 1.2], c: '#2a2c31' });
  top.box({ name: 'GateSignFrame', s: [21, 4.4, 0.9], p: [0, 0, 0.3], c: '#f2b632', studs: 'top' });
  surfaceLabel(plate, 'Back', 'TIME GATE', { pps: 26, color: '#fff4d6', color2: '#ffb02e', strokeT: 4, shadow: 5 });
  surfaceLabel(plate, 'Front', 'TIME GATE', { pps: 26, color: '#fff4d6', color2: '#ffb02e', strokeT: 4, shadow: 5 });
  // inner ring (spins) + outer halo of cubes (orbits)
  const inner = g.group('InnerRing');
  inner.parent.attr('Spin', 0.35).tag('GateSpin');
  const I = inner.at([0, cy, GATE.z - 1.6]); // spins just in front of the membrane
  const pivotI = I.box({ name: 'RingPivot', s: [1, 1, 1], t: 1, shadow: false });
  inner.parent.set('PrimaryPart', 'Ref', pivotI);
  const P6i = hexPts(12.4, 30);
  for (let k = 0; k < 6; k++) {
    const [ax, ay] = P6i[k], [bx, by] = P6i[(k + 1) % 6];
    I.beam([ax, ay, 0], [bx, by, 0], 1.6, 1.6, { name: 'InnerBeam', c: '#f2b632', m: 'Metal', extend: 1.2, up: [0, 0, 1] });
    I.beam([ax * 0.94, ay * 0.94, 0], [bx * 0.94, by * 0.94, 0], 1.8, 0.4, { name: 'InnerGlow', c: '#4a9bff', m: 'Neon', up: [0, 0, 1] });
  }
  const halo = g.group('Halo');
  halo.parent.attr('Spin', -0.18).tag('GateSpin');
  const Hh = halo.at([0, cy, GATE.z]);
  const pivotH = Hh.box({ name: 'RingPivot', s: [1, 1, 1], t: 1, shadow: false });
  halo.parent.set('PrimaryPart', 'Ref', pivotH);
  for (let k = 0; k < 18; k++) {
    const a = (k / 18) * Math.PI * 2;
    Hh.box({ name: 'HaloCube', s: [1.6, 1.6, 1.6], p: [Math.cos(a) * 25, Math.sin(a) * 25, 0], r: [0, 0, E.deg(a) + 45], c: k % 3 ? '#f2b632' : '#4a9bff', m: k % 3 ? 'SmoothPlastic' : 'Neon' });
  }
  // membrane: regular hexagon filled with three rotated slabs
  const mem = g.group('Membrane');
  const M = mem.at([0, cy, GATE.z]);
  const rm = 14.2, apo = rm * Math.sin(Math.PI / 3);
  for (let k = 0; k < 3; k++) M.box({ name: 'Membrane', s: [rm, 2 * apo, 0.3], r: [0, 0, k * 60], c: '#2f7fe8', m: 'Neon', t: 0.6, shadow: false }).tag('PortalSurface');
  for (let k = 0; k < 3; k++) M.box({ name: 'Core', s: [rm * 0.5, 2 * apo * 0.5, 0.35], r: [0, 0, k * 60], c: '#bfe0ff', m: 'Neon', t: 0.6, shadow: false }).tag('PortalCore');
  const pc = M.box({ name: 'PortalLightHost', s: [1, 1, 1], t: 1, shadow: false });
  E.pointLight(pc, [0.35, 0.6, 1], 40, 1.1);
  E.particles(pc, 'Swirl', { rate: 18, life: [0.8, 1.6], speed: [6, 14], spread: [80, 80], dir: 5, size: [[0, 0.55], [1, 0]], color: [[0, [0.8, 0.9, 1]], [1, [0.3, 0.55, 1]]], emission: 0.6 });
  E.particles(pc, 'Streaks', { rate: 7, life: [0.4, 0.8], speed: [20, 30], spread: [50, 50], dir: 5, size: [[0, 0.25], [1, 0]], color: [1, 1, 1], emission: 1, texture: 'rbxasset://textures/particles/sparkles_main.dds' });
  // pylons either side with cables to the frame
  for (const side of [-1, 1]) {
    const py = g.at([side * 30, Y.deck, GATE.z + 2]);
    for (let k = 0; k < 6; k++) py.box({ name: 'Pylon', s: [6 - k * 0.4, 5, 6 - k * 0.4], p: [0, 2.5 + k * 5, 0], r: [0, k * 8, 0], c: k % 2 ? '#3a3d42' : '#4a4d52', m: 'Metal', studs: 'top', collide: k < 2 });
    py.box({ name: 'PylonCap', s: [5, 1.4, 5], p: [0, 31, 0], c: '#f2b632', m: 'Metal' });
    const coil = py.box({ name: 'PylonCoil', s: [3, 3, 3], p: [0, 33, 0], r: [45, 45, 0], c: '#4a9bff', m: 'Neon' });
    coil.tag('GateNode');
    for (const h of [10, 20]) py.beam([-side * 2.8, h, 0], [-side * (30 - GATE.R - 3.2), cy - Y.deck + (h - 15) * 0.25, -2], 0.7, 0.7, { name: 'PowerCable', c: '#1d1e21' }); // plugs into the side node
    py.box({ name: 'Vent', s: [6.2, 0.6, 6.2], p: [0, 15, 0], c: '#f2b632' });
  }
  // the stage: guardian T. rex statues on plinths at the deck's front corners, roaring at whoever drives up
  for (const side of [-1, 1]) {
    const pc = g.at([side * 30.5, Y.deck, z0 - 19]);
    pc.box({ name: 'StatuePlinth', s: [9, 3, 18], p: [0, 1.5, 0], c: '#7a746a', m: 'Slate', studs: 'top', collide: true });
    pc.box({ name: 'StatuePlinthTrim', s: [9.4, 0.5, 18.4], p: [0, 3.1, 0], c: '#f2b632', m: 'Metal' });
    pc.box({ name: 'PlinthGlow', s: [9.6, 0.3, 18.6], p: [0, 0.2, 0], c: '#4a9bff', m: 'Neon', t: 0.5, shadow: false }).tag('GateEraTint');
    dinoStatue(pc, 'TyrannosaurusRex', [0, 3.3, 2], 180 - side * 12, 0.72, { Jaw: [-30, 0, 0], Head: [-12, side * 12, 0], Neck1: [10, side * 6, 0], Neck2: [6, side * 6, 0] });
  }
  // light rigs: truss towers behind the pylons with spotlights raking across the gate (era-tinted)
  for (const side of [-1, 1]) {
    const tw = g.at([side * 42, Y.deck - 6, GATE.z + 10]);
    const TH = 46;
    for (const [x, z] of [[-1.6, -1.6], [1.6, -1.6], [-1.6, 1.6], [1.6, 1.6]]) tw.box({ name: 'TrussLeg', s: [0.6, TH, 0.6], p: [x, TH / 2, z], c: '#3a3d42', m: 'Metal', collide: x === -1.6 && z === -1.6 });
    for (let k = 0; k < 9; k++) {
      tw.box({ name: 'TrussRung', s: [3.8, 0.4, 0.4], p: [0, 3 + k * 5, -1.6], r: [0, 0, k % 2 ? 40 : -40], c: '#4a4d52', m: 'Metal' });
      tw.box({ name: 'TrussRung', s: [0.4, 0.4, 3.8], p: [-side * 1.6, 3 + k * 5, 0], r: [k % 2 ? 40 : -40, 0, 0], c: '#4a4d52', m: 'Metal' });
    }
    tw.box({ name: 'TrussCap', s: [5, 1, 5], p: [0, TH + 0.5, 0], c: '#f2b632', m: 'Metal' });
    for (const h of [TH - 2, TH - 14]) {
      const lamp = tw.at([0, h, -2.6], [-18, -side * 32, 0]);
      lamp.box({ name: 'SpotHousing', s: [2.4, 2.4, 3], c: '#1d1e21', m: 'Metal' });
      const lens = lamp.box({ name: 'SpotLens', s: [2, 2, 0.3], p: [0, 0, -1.6], c: '#4a9bff', m: 'Neon' });
      lens.tag('GateEraTint');
      const sl = new Inst('SpotLight', 'Spot');
      sl.set('Color', 'Color3', [0.4, 0.62, 1]).set('Range', 'float', 50).set('Brightness', 'float', 1.3).set('Angle', 'float', 38).set('Face', 'token', 5).set('Shadows', 'bool', false);
      lens.add(sl);
    }
  }
  // neon strips along the deck edges, and the floating destination banner under the gate sign
  for (const side of [-1, 1]) g.box({ name: 'DeckStrip', s: [0.6, 0.3, z0 - z1 - 6], p: [side * 34.4, Y.deck - 0.6, (z0 + z1) / 2], c: '#4a9bff', m: 'Neon', t: 0.45, shadow: false }).tag('GateEraTint');
  for (const side of [-1, 1]) g.box({ name: 'DeckStripFront', s: [20, 0.3, 0.6], p: [side * 24, Y.deck - 0.6, z0 + 0.4], c: '#4a9bff', m: 'Neon', t: 0.45, shadow: false }).tag('GateEraTint');
  {
    const bh = marker(g, 'EraBannerHost', [0, cy + GATE.R + 10, GATE.z - 3]);
    const bb = billboardText(bh, 'EraBanner', 'FERN VALLEY', { w: 26, h: 3.4, color: '#ffffff', color2: '#4a9bff', strokeT: 4, maxDist: 400 });
    bb.set('StudsOffsetWorldSpace', 'Vector3', [0, 0, 0]);
    billboardText(bh, 'EraYear', '68,000,000 BC', { w: 16, h: 1.6, offset: [0, -2.6, 0], color: '#ffd27a', maxDist: 400 });
  }
  // era console in front-left of the gate
  const cc = g.at([-19, Y.deck, z0 - 9], [0, -145, 0]);
  cc.box({ name: 'ConsoleBase', s: [6, 3.2, 3.4], p: [0, 1.6, 0], c: '#3a3d42', m: 'Metal', studs: 'top', collide: true });
  const scr = cc.at([0, 3.8, -0.2], [-35, 0, 0]).box({ name: 'ConsoleScreen', s: [5.6, 3.4, 0.3], c: '#0f1a1c' });
  const sg = new Inst('SurfaceGui', 'EraScreen');
  sg.set('Face', 'token', 5).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', 50).set('LightInfluence', 'float', 0);
  sg.add(styledText('DESTINATION', { name: 'Title', size: [0.9, 0, 0.2, 0], pos: [0.05, 0, 0.08, 0], color: '#9ff3e8', strokeT: 2, shadow: 2, align: 'Center' }));
  sg.add(styledText('FERN VALLEY', { name: 'Era', size: [0.9, 0, 0.28, 0], pos: [0.05, 0, 0.36, 0], color: '#ffffff', color2: '#4a9bff', strokeT: 3, shadow: 3, align: 'Center' }));
  sg.add(styledText('68,000,000 BC', { name: 'Year', size: [0.8, 0, 0.16, 0], pos: [0.1, 0, 0.72, 0], color: '#ffd27a', strokeT: 2, shadow: 2, align: 'Center' }));
  scr.add(sg);
  cc.box({ name: 'ConsoleTrim', s: [6.2, 0.3, 3.6], p: [0, 3.25, 0], c: '#4a9bff', m: 'Neon' });
  for (let k = 0; k < 4; k++) cc.box({ name: 'ConsoleKey', s: [0.8, 0.3, 0.6], p: [-2.1 + k * 1.4, 3.3, -1.3], c: ['#e8473a', '#f2c230', '#7cc242', '#3d8be8'][k] });
  const host = marker(cc, 'EraPromptHost', [0, 3, -2]);
  const at = new Inst('Attachment', 'PromptAttachment');
  host.add(at);
  const pr = new Inst('ProximityPrompt', 'EraPrompt');
  pr.set('ActionText', 'string', 'Choose Era').set('ObjectText', 'string', 'Time Gate').set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 14).set('HoldDuration', 'float', 0).set('RequiresLineOfSight', 'bool', false);
  pr.attr('CampAction', 'Era');
  at.add(pr);
  // trigger volume inside the membrane + where returning vehicles come out
  marker(g, 'GateTrigger', [0, Y.deck + 6, GATE.z + 1.5], 0, { s: [22, 12, 5] });
  marker(g, 'GateArrival', [0, Y.deck + 0.2, GATE.z + 10], 180, { s: [8, 1, 14] });
  gm.attr('CenterY', cy);
  // deck decor
  for (const side of [-1, 1]) {
    E.crate(g, [side * 27, Y.deck, z0 - 6], 1.1, { yaw: side * 14, stencil: '#4a9bff' });
    E.crate(g, [side * 27, Y.deck + 2.2, z0 - 6], 0.8, { yaw: -side * 6 });
    E.barrel(g, [side * 24, Y.deck, z0 - 3.5], { color: '#f2b632' });
    E.lampPost(g, [side * 31, Y.deck, z0 - 1.5], { yaw: side * 90, h: 8, color: '#9ff3e8' });
  }
  return g;
}

// ============================================================== BACKDROP
// Outer world: the mainland behind the gate (cliffs, two falls, the ridge Brachiosaurus), the skyline peaks and
// the volcano of the next eras, and a ring of crater cliffs all the way round the lagoon.
const RIM = [[236, -430], [380, -436], [520, -424], [640, -300], [705, -60], [690, 180], [600, 420], [430, 610], [200, 712], [-60, 730], [-310, 690], [-520, 560], [-660, 330], [-712, 80], [-690, -170], [-600, -360], [-470, -430], [-236, -430]];
function buildBackdrop(H) {
  const B = H.group('Backdrop');
  const R = rng(9090);
  const ring = (r, a0, a1, step) => { const pts = []; for (let a = a0; a <= a1 + 1e-6; a += step) { const [dx, dz] = dirOf(a); pts.push([dx * r, dz * r]); } return pts; };
  // the mainland: solid ground behind the gate pier, a beach and an underwater shelf along its lagoon shore
  const ML = B.group('Mainland');
  fillPoly(ML, offsetPoly(IL.MAINLAND, -12), 12, { name: 'MainlandShelf', top: -3.6, thick: -3.6 - Y.bed, c: '#d9c48c', m: 'Sand', collide: true, shadow: false });
  fillPoly(ML, offsetPoly(IL.MAINLAND, -5), 6, { name: 'MainlandBeach', top: 0.3, thick: 4, c: '#ecd9a4', m: 'Sand', collide: true });
  fillPoly(ML, offsetPoly(IL.MAINLAND, 4), 8, { name: 'MainlandGrass', top: Y.ground, thick: 4.4, c: PAL.grassLo, studs: 'top', collide: true });
  // the valley wall: tall cliffs behind the Time Gate, spurs back to the ridge
  E.cliffWall(B, ring(250, -24, 24, 8), { h: 64, d: 22, seed: 11, slope: 5, name: 'NorthCliffs', trees: true });
  for (const side of [-1, 1]) {
    const [ax, az] = dirOf(side * 24);
    const pts = [[ax * 250, az * 250], [ax * 290, az * 290], [ax * 330, az * 330]];
    E.cliffWall(B, side > 0 ? pts : pts.slice().reverse(), { h: 56, d: 20, seed: 13 + side, slope: 4, name: 'NorthSpur', trees: true });
  }
  // north ridge plateau: the Brachiosaurus walks along it, its head and neck above the cliff line
  B.box({ name: 'Ridge', s: [330, 54, 70], p: [0, 27, -305], c: PAL.cliff[3], m: 'Slate' });
  B.box({ name: 'RidgeTop', s: [330, 1.2, 80], p: [0, 54.6, -300], c: PAL.grassLo, studs: 'top' });
  E.cliffWall(B, [[160, -262], [105, -258], [52, -264], [0, -260], [-52, -264], [-105, -258], [-160, -262]], { h: 56, d: 20, seed: 19, slope: 6, name: 'RidgeFace', trees: true, chunk: 14 });
  // the far skyline over the ridge (only the peaks that stand clear of the islands) and the volcano
  const SK = B.group('Skyline');
  const islandPolys = Array.from({ length: PLOT_COUNT }, (_, i) => IL.outline(i + 3, 0.035).map(([x, z]) => IL.toHub(i, x, z)));
  const clearOfIslands = (x, z, r) => islandPolys.every((poly) => poly.every(([px, pz]) => Math.hypot(px - x, pz - z) > r));
  for (let k = 0; k < 9; k++) {
    const rx = R(), rz = R();
    const x = -520 + k * 130 + (rx - 0.5) * 40, z = -400 - (k % 2) * 22 - rz * 18;
    const h = 120 + R() * 110 + (k % 2) * 40;
    const keep = clearOfIslands(x, z, 120) && Math.abs(x) < 260;
    for (let t = 0; t < 6; t++) {
      const s = [170 - t * 26 + R() * 18, h / 6 + 1, 86 - t * 12 + R() * 8], p = [x + (R() - 0.5) * 8 * t, (t + 0.5) * (h / 6), z], r = [0, (R() - 0.5) * 24, 0];
      if (keep) SK.box({ name: 'Peak', s, p, r, c: t >= 4 ? '#eef2f4' : shade(k % 2 ? '#6a7a84' : '#76878e', 0.9 + t * 0.04), m: 'Slate' });
    }
  }
  {
    // the volcano of the next eras: it anchors the rim's north-east corner (clear of Fern Valley and Red Cliffs)
    const V = SK.at([600, 0, -400]);
    for (let t = 0; t < 7; t++) V.box({ name: 'Volcano', s: [230 - t * 30, 30, 230 - t * 30], p: [0, 15 + t * 28, 0], r: [0, t * 13, 0], c: t > 4 ? '#3e302c' : '#54443c', m: 'Slate' });
    V.box({ name: 'VolcanoFoot', s: [240, -Y.bed + 1, 240], p: [0, Y.bed / 2, 0], c: '#54443c', m: 'Slate' });
    for (let k = 0; k < 4; k++) V.at([0, 0, 0], [0, k * 90 + 20, 0]).box({ name: 'LavaStreak', s: [3, 70, 2], p: [0, 140, -46 + k * 3], r: [-28, 0, 0], c: '#e0501a', m: 'Neon', t: 0.4 });
    const crater = V.box({ name: 'Crater', s: [26, 4, 26], p: [0, 198, 0], c: '#ff5a1a', m: 'Neon' });
    E.particles(crater, 'Smoke', { texture: 'rbxasset://textures/particles/smoke_main.dds', rate: 5, life: [9, 13], speed: [8, 14], dir: 1, spread: [15, 15], size: [[0, 24], [1, 70]], transp: [[0, 0.3], [1, 1]], color: [0.35, 0.32, 0.32], emission: 0 });
  }
  for (let k = 0; k < 12; k++) E.jungleTree(B, [-150 + k * 27 + R() * 6, 55, -322 - R() * 14], 14 + R() * 8, 9100 + k);
  for (let k = 0; k < 7; k++) E.palm(B, [-140 + k * 46 + R() * 10, 55, -332], 13 + R() * 5, 9200 + k);
  const path = [];
  for (let k = 0; k <= 8; k++) path.push([-150 + k * 37.5, 55.2, -284 + Math.sin(k * 0.9) * 4]);
  path.forEach((p, k) => marker(B, 'RidgeWaypoint' + (k + 1), p, 0));
  // waterfalls flanking the gate, pouring straight into the lagoon
  for (const side of [-1, 1]) {
    const [dx, dz] = dirOf(side * 20);
    const wx = dx * 236, wz = dz * 236;
    E.waterfall(B, [wx, 60, wz], 16, 61, { yaw: 180 - side * 20, seed: 9300 + side, name: 'Waterfall' });
    B.at([dx * 244, 0, dz * 244], [0, 180 - side * 20, 0]).box({ name: 'FallsSpout', s: [24, 66, 16], p: [0, 33, 6], c: PAL.cliff[0], m: 'Slate', studs: 'top', collide: true });
    for (let k = 0; k < 4; k++) E.rock(B, [dx * 226 + (R() - 0.5) * 30, -0.6, dz * 226 + 6 + R() * 4], 1.6 + R(), 9500 + k + side * 10);
  }
  // the crater rim: one ring of cliffs from the mainland's east end, round the south, back to its west end
  E.cliffWall(B, RIM, { h: 66, d: 28, y: -6, seed: 31, slope: 6, name: 'RimCliffs', trees: false, chunk: 26 });
  // ...and a solid skirt under it down to the seabed (divers used to swim out under the rim into the void)
  for (let k = 0; k < RIM.length - 1; k++) {
    const [ax, az] = RIM[k], [bx, bz] = RIM[k + 1];
    const L = Math.hypot(bx - ax, bz - az), tx = (bx - ax) / L, tz = (bz - az) / L;
    const nx = tz, nz = -tx; // outward (the cliffs' body side)
    const yaw = Math.atan2(-tx, -tz) * 180 / Math.PI;
    const mx = (ax + bx) / 2, mz = (az + bz) / 2;
    if (Math.abs(mx - 600) < 130 && Math.abs(mz + 400) < 130) continue; // (the volcano's own foot seals it there)
    B.at([(ax + bx) / 2 + nx * 12, (Y.bed - 5.5) / 2, (az + bz) / 2 + nz * 12], [0, yaw, 0]).box({ name: 'RimSkirt', s: [32, -5.5 - Y.bed, L + 8], c: PAL.cliff[3], m: 'Slate', collide: true, shadow: false });
  }
  // falls off the rim (east, south, west) so every side of the lagoon has a moving landmark
  for (const [x, z] of [[703, -10], [-40, 726], [-708, 60]]) {
    const a = Math.atan2(x, -z) * 180 / Math.PI;
    const [dx, dz] = dirOf(a);
    E.waterfall(B, [x - dx * 4, 58, z - dz * 4], 14, 59, { yaw: 180 - a, seed: 9600 + Math.round(a), name: 'Waterfall' });
  }
  // palms along the rim top, sea stacks out in the lagoon past the islands
  for (let k = 1; k < RIM.length - 1; k++) {
    const [x, z] = RIM[k];
    const d = Math.hypot(x, z);
    E.palm(B, [x * (1 + 18 / d), 60, z * (1 + 18 / d)], 14 + R() * 5, 9700 + k);
  }
  const step = (IL.ARC1 - IL.ARC0) / (PLOT_COUNT - 1);
  for (let i = 0; i < PLOT_COUNT - 1; i++) {
    const a = plotAngle(i) + step / 2;
    const [dx, dz] = dirOf(a);
    const r = 585 + R() * 30;
    const sc = B.at([dx * r, Y.bed, dz * r], [0, R() * 90, 0]);
    let y = 0, w = 22 + R() * 6;
    for (let t = 0; t < 5; t++) {
      const h = t === 0 ? -Y.bed + 2 : 5 + R() * 4;
      sc.box({ name: 'SeaStack', s: [w, h, w * (0.8 + R() * 0.3)], p: [(R() - 0.5) * 2, y + h / 2, (R() - 0.5) * 2], r: [0, R() * 30, 0], c: PAL.cliff[t % 5], m: 'Slate', studs: 'top', collide: true });
      y += h;
      w *= 0.8;
    }
    sc.box({ name: 'StackTop', s: [w + 1, 1, w + 1], p: [0, y + 0.5, 0], c: PAL.grassLo, studs: 'top' });
    E.palm(sc, [0, y + 1, 0], 10 + R() * 4, 9800 + i);
  }
  return B;
}

// ============================================================== SHORE WALLS + OCEAN
// (2026-10-13) Invisible walls round every shore you can walk on - the hub (and the Time Gate deck), each island,
// both sides of each bridge - so nobody jumps into the lagoon. Tagged ShoreWall: the server (Shore.luau) puts them in a
// collision group only player characters bump into, so rovers, dinos, the camera and every raycast go straight through.
// They stand on the water's edge (just past the wet sand), 60+ studs tall: no roof or rail cap is high enough to hop them.
const WALL = { y0: -4, y1: 62, w: 1 };
function shoreWall(ctx, a, b) {
  const y = (WALL.y0 + WALL.y1) / 2;
  const p = ctx.beam([a[0], y, a[1]], [b[0], y, b[1]], WALL.w, WALL.y1 - WALL.y0, { name: 'ShoreWall', t: 1, collide: true, shadow: false, extend: 1.2 });
  p.set('CollisionGroup', 'string', 'ShoreWall');
  p.tag('ShoreWall');
  return p;
}
// Douglas-Peucker on an open polyline (the walls follow the shore to within tol studs, with far fewer parts)
function simplifyLine(pts, tol) {
  if (pts.length < 3) return pts.slice();
  const [ax, az] = pts[0], [bx, bz] = pts[pts.length - 1];
  const L = Math.hypot(bx - ax, bz - az) || 1;
  let worst = -1, at = 0;
  for (let k = 1; k < pts.length - 1; k++) {
    const d = Math.abs((bx - ax) * (az - pts[k][1]) - (ax - pts[k][0]) * (bz - az)) / L;
    if (d > worst) { worst = d; at = k; }
  }
  if (worst <= tol) return [pts[0], pts[pts.length - 1]];
  const left = simplifyLine(pts.slice(0, at + 1), tol);
  return left.slice(0, -1).concat(simplifyLine(pts.slice(at), tol));
}
// walls along a closed outline, leaving out every stretch where gap(x, z) is true (a bridge landing)
function wallOutline(ctx, poly, gap, tol = 0.5) {
  const dense = [];
  for (let k = 0; k < poly.length; k++) {
    const [x0, z0] = poly[k], [x1, z1] = poly[(k + 1) % poly.length];
    const n = Math.max(1, Math.ceil(Math.hypot(x1 - x0, z1 - z0)));
    for (let s = 0; s < n; s++) dense.push([x0 + ((x1 - x0) * s) / n, z0 + ((z1 - z0) * s) / n]);
  }
  // start the walk at a point outside every gap, so each run of wall is one unbroken polyline
  const start = Math.max(0, dense.findIndex(([x, z]) => !gap(x, z)));
  const ring = dense.slice(start).concat(dense.slice(0, start + 1));
  let run = [], walls = 0;
  const flush = () => {
    const pts = simplifyLine(run, tol);
    for (let k = 0; k + 1 < pts.length; k++) { shoreWall(ctx, pts[k], pts[k + 1]); walls++; }
    run = [];
  };
  for (const p of ring) {
    if (gap(p[0], p[1])) { if (run.length > 1) flush(); else run = []; continue; }
    run.push(p);
  }
  if (run.length > 1) flush();
  return walls;
}
const BRIDGE_WALL_X = IL.BRIDGE_W / 2 + 1.4; // just outside the bridge rails (the rails sit at W/2 + 0.6)
const BRIDGE_GAP_X = IL.BRIDGE_W / 2 + 0.6;  // a shore wall stops where it meets the rail line
// (2026-10-13, user: "get rid of the non-bridge invisible walls, it's cool to go swim over to someone else's base")
// Only the bridges keep their walls (a fall off a bridge is a mistake; a swim from a shore is a choice). The hub,
// Time Gate deck and island walls are switched off below - set SHORE_WALLS_EVERYWHERE to bring them back.
const SHORE_WALLS_EVERYWHERE = false;
function buildShoreWalls(H) {
  const W = H.group('ShoreWalls', 'Folder');
  let n = 0;
  if (!SHORE_WALLS_EVERYWHERE) {
    const R0 = IL.HUB_R + 6.5;
    for (let i = 0; i < PLOT_COUNT; i++) {
      const c = W.at([0, 0, 0], [0, 180 - plotAngle(i), 0]);
      for (const side of [-1, 1]) shoreWall(c, [side * BRIDGE_WALL_X, R0 - 1.5], [side * BRIDGE_WALL_X, IL.RF + 8]);
      n += 2;
    }
    return n;
  }
  // the hub: its wet sand ends at HUB_R + 6; open where each bridge and the gate deck leave the shore
  const R = IL.HUB_R + 6.5;
  const GATE_X = 35.5; // the gate deck is 70 wide (buildTimeGate)
  const gateZ = -Math.sqrt(R * R - GATE_X * GATE_X);
  const hub = [];
  for (let k = 0; k < 720; k++) { const [dx, dz] = dirOf(k / 2); hub.push([dx * R, dz * R]); }
  n += wallOutline(W, hub, (x, z) => {
    if (z < 0 && Math.abs(x) < GATE_X) return true;
    for (let i = 0; i < PLOT_COUNT; i++) {
      const [dx, dz] = dirOf(plotAngle(i));
      const along = x * dx + z * dz, side = x * dz - z * dx;
      if (along > 0 && Math.abs(side) < BRIDGE_GAP_X) return true;
    }
    return false;
  }, 0.4);
  // the gate deck's three open sides (the deck runs from the hub shore out to z = GATE.deckZ1)
  const zEnd = GATE.deckZ1 - 0.5;
  shoreWall(W, [-GATE_X, gateZ + 1.5], [-GATE_X, zEnd]);
  shoreWall(W, [-GATE_X, zEnd], [GATE_X, zEnd]);
  shoreWall(W, [GATE_X, zEnd], [GATE_X, gateZ + 1.5]);
  n += 3;
  // the bridges: one straight wall outside each rail, from the hub's wall line to the island's
  for (let i = 0; i < PLOT_COUNT; i++) {
    const c = W.at([0, 0, 0], [0, 180 - plotAngle(i), 0]);
    for (const side of [-1, 1]) shoreWall(c, [side * BRIDGE_WALL_X, R - 1.5], [side * BRIDGE_WALL_X, IL.RF + 8]);
    n += 2;
  }
  // each island: round its wet sand (the outline + 6), open where its bridge lands
  for (let i = 0; i < PLOT_COUNT; i++) {
    const f = IL.islandFrame(i);
    const c = W.at(f.front, [0, f.yaw, 0]);
    const poly = offsetPoly(IL.outline(i + 3, 0.035), -6.5);
    n += wallOutline(c, poly, (x, z) => z < 20 && Math.abs(x) < BRIDGE_GAP_X);
  }
  return n;
}
// The open sea outside the crater rim (it used to be a grey template Baseplate). The server fills these markers
// with Terrain water and a sand floor (WaterSetup), tiles no bigger than ~1100 studs. Stops short of the eras to
// the north (their south edges sit at world z -485).
function buildOcean(H) {
  const O = H.group('Ocean', 'Folder');
  const X0 = -2600, X1 = 2600, Z0 = -470, Z1 = 2800, TILE = 1040;
  let n = 0;
  for (let x = X0; x < X1; x += TILE) for (let z = Z0; z < Z1; z += TILE) {
    const w = Math.min(TILE, X1 - x), d = Math.min(TILE, Z1 - z);
    marker(O, 'OceanVolume', [x + w / 2, (Y.water + Y.bed) / 2, z + d / 2], 0, { s: [w, Y.water - Y.bed, d] }).tag('TerrainWater');
    marker(O, 'OceanFloor', [x + w / 2, Y.bed - 4, z + d / 2], 0, { s: [w, 8, d] }).tag('TerrainSand');
    n++;
  }
  return n;
}

// ============================================================== ROOT
function buildHub() {
  const root = new Inst('Model', 'BaseCamp');
  root.attr('Zone', 'BaseCamp');
  root.set('ModelStreamingMode', 'token', 0);
  const H = new Ctx({ parent: root, frame: new CF(...HUB_ORIGIN), defaults: { anchored: true } });
  buildGrounds(H);
  buildPlaza(H);
  const plots = H.group('Plots', 'Folder');
  for (let i = 0; i < PLOT_COUNT; i++) buildIsland(plots, i);
  const bridges = H.group('Bridges', 'Folder');
  for (let i = 0; i < PLOT_COUNT; i++) buildBridge(bridges, i);
  buildTimeGate(H);
  buildBackdrop(H);
  const walls = buildShoreWalls(H);
  const ocean = buildOcean(H);
  console.log(`hub: ${walls} shore walls, ${ocean} ocean tiles`);
  return root;
}

module.exports = { buildHub, HUB_ORIGIN, PLOT_COUNT, ACCENTS, plotAngle, Y: Y, GATE };
