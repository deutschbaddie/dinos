// ISLAND KIT — the buildings an island grows into (Config.Island), built once into
// ReplicatedStorage.DinoExpedition.IslandKit; the server's IslandView clones the owner's set onto each island.
//   HatcheryT2 / HatcheryT3   add-ons around the hatchery (origin = hatchery floor centre, the front faces -Z)
//   GarageT2 (WORKSHOP)       a lean-to workshop + engine hoist (origin = garage bay centre, the door faces -Z)
//   GarageT3 (HANGAR)         an arched hangar shell over the garage (room for planes later)
//   Trainer1..Trainer7        the POWER TRAINER's machine per tier (origin = range centre, the pad end faces -Z)
//   Pen_<Species>_<Lot>       a star pen per boss species, sized for each star lot (origin = lot centre on the
//                             grass; the gate faces -Z, toward the island's front). Pen_Mosasaurus_StarD floats
//                             in the lagoon (origin at the water line).
// Every kit model's PrimaryPart is KitOrigin at its local origin, so Model:PivotTo(anchor.CFrame) places it.
const { Inst, Ctx, CF, shade, rng, styledText } = require('./builder.js');
const E = require('./env.js');
const IL = require('./islandLayout.js');
const { PAL } = E;

const P = IL.PLAN;
const HW = P.hatchery[2] - P.hatchery[0] - 2, HD = P.hatchery[3] - P.hatchery[1] - 4, HH = 12; // as hub.js buildHatchery
const GW = 24, GD = 26, GH = 15, GDH = 13; // as hub.js buildGarage

function kitModel(root, name) {
  const m = new Inst('Model', name);
  root.add(m);
  const c = new Ctx({ parent: m, frame: new CF(0, 0, 0), defaults: { anchored: true } });
  const o = c.box({ name: 'KitOrigin', s: [1, 1, 1], t: 1, shadow: false });
  o.set('CanQuery', 'bool', false);
  m.set('PrimaryPart', 'Ref', o);
  return c;
}
function label(part, face, text, o = {}) {
  const FACES = { Right: 0, Top: 1, Back: 2, Left: 3, Bottom: 4, Front: 5 };
  const sg = new Inst('SurfaceGui', o.name || 'Label');
  sg.set('Face', 'token', FACES[face]).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', o.pps || 40).set('LightInfluence', 'float', 0);
  sg.add(styledText(text, Object.assign({ name: 'Text', size: [0.92, 0, 0.7, 0], pos: [0.04, 0, 0.15, 0], strokeT: 3, shadow: 4, align: 'Center' }, o)));
  part.add(sg);
  return sg;
}
function plate(c, p, w, h, text, o = {}) {
  const b = c.box({ name: o.name || 'TierPlate', s: [w, h, 0.3], p, c: o.bg || '#2a2c31' });
  c.box({ name: 'TierPlateFrame', s: [w + 0.5, h + 0.5, 0.2], p: [p[0], p[1], p[2] + 0.18], c: o.frame || '#ffcf3a', m: 'Metal' });
  label(b, 'Front', text, { pps: 40, color: o.color || '#fff4d6', color2: o.color2 || '#ffb02e' });
  return b;
}

// ============================================================== HATCHERY
function hatcheryT2(root) {
  const c = kitModel(root, 'HatcheryT2');
  // four copper booster boilers at the outer corners, piping heat up into the eaves
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const b = c.at([sx * (HW / 2 + 2.8), 0, sz * (HD / 2 - 5)]);
    b.box({ name: 'BoosterBase', s: [3.8, 0.4, 3.8], p: [0, 0.2, 0], c: '#5d5a55', m: 'Slate', collide: true });
    b.cyl({ name: 'BoosterTank', axis: 'y', len: 5.4, d: 3.2, p: [0, 3.1, 0], c: '#c87533', m: 'Metal', collide: true });
    for (const y of [1.3, 4.9]) b.cyl({ name: 'BoosterBand', axis: 'y', len: 0.3, d: 3.45, p: [0, y, 0], c: '#8a4a1e', m: 'Metal' });
    b.ball({ name: 'BoosterDome', d: 3.2, p: [0, 5.8, 0], c: '#d98a44', m: 'Metal' });
    b.box({ name: 'BoosterGlow', s: [0.2, 1.3, 1.3], p: [sx * 1.62, 3.2, 0], c: '#ff8a2a', m: 'Neon' }).tag('HeatLamp');
    b.beam([0, 6.8, 0], [-sx * 2.6, 9.3, 0], 0.5, 0.5, { name: 'BoosterPipe', c: '#8a4a1e', m: 'Metal' });
    b.cyl({ name: 'Gauge', axis: 'x', len: 0.2, d: 1, p: [sx * 1.65, 4.3, 0.9], c: '#f2e6c4' });
  }
  // warm string lights under both long eaves
  const cols = ['#ffd27a', '#ff8a5a', '#fff1c4'];
  for (const sx of [-1, 1]) for (let k = 0; k <= Math.floor(HD / 3); k++) {
    c.box({ name: 'EaveLight', s: [0.5, 0.5, 0.5], p: [sx * (HW / 2 + 0.7), 9.2 - (k % 2) * 0.35, -HD / 2 + k * 3], c: cols[k % 3], m: 'Neon', shadow: false });
  }
  plate(c, [0, HH - 4.0, -HD / 2 - 0.5], 4, 1.8, 'II');
  return c;
}
function hatcheryT3(root) {
  const c = kitModel(root, 'HatcheryT3');
  // a glass lantern along the ridge: more light, more heat, and it looks the part
  const y0 = HH + 1.2 + (HW / 4) * Math.tan((9 * Math.PI) / 180) + 1.1;
  const L = HD - 6, X = 4.2, LH = 4;
  for (const sx of [-1, 1]) {
    c.box({ name: 'LanternSill', s: [0.8, 0.6, L], p: [sx * X, y0 + 0.3, 0], c: '#8a4a1e', m: 'Metal' });
    c.box({ name: 'LanternTop', s: [0.8, 0.6, L], p: [sx * X, y0 + LH, 0], c: '#8a4a1e', m: 'Metal' });
    for (let k = 0; k <= 4; k++) c.box({ name: 'LanternPost', s: [0.6, LH, 0.6], p: [sx * X, y0 + LH / 2 + 0.3, -L / 2 + (k * L) / 4], c: '#c87533', m: 'Metal' });
    for (let k = 0; k < 4; k++) c.box({ name: 'LanternGlass', s: [0.2, LH - 0.6, L / 4 - 0.7], p: [sx * X, y0 + LH / 2 + 0.3, -L / 2 + ((k + 0.5) * L) / 4], c: '#bfefff', m: 'Glass', t: 0.45, shadow: false });
    c.at([sx * X / 2, y0 + LH + 1.0, 0], [0, 0, -sx * 26]).box({ name: 'LanternRoof', s: [X + 1.6, 0.4, L + 1], c: '#c87533', m: 'Metal' });
  }
  for (const sz of [-1, 1]) {
    c.box({ name: 'LanternEnd', s: [X * 2 - 0.4, LH - 0.6, 0.2], p: [0, y0 + LH / 2 + 0.3, sz * L / 2], c: '#bfefff', m: 'Glass', t: 0.45, shadow: false });
    c.ball({ name: 'Finial', d: 1.1, p: [0, y0 + LH + 2.6, sz * (L / 2 + 0.4)], c: '#ffcf3a', m: 'Metal' });
  }
  c.box({ name: 'LanternRidge', s: [0.8, 0.6, L + 1.4], p: [0, y0 + LH + 2.0, 0], c: '#ffcf3a', m: 'Metal' });
  const glow = c.box({ name: 'LanternGlow', s: [1, 0.4, L - 4], p: [0, y0 + 0.8, 0], c: '#ffb070', m: 'Neon', t: 0.2, shadow: false });
  E.pointLight(glow, [1, 0.72, 0.42], 28, 0.8);
  // the incubator engine by the entrance: brass, two glowing tubes, a pressure dial
  const en = c.at([-HW / 2 + 6, 0, -HD / 2 - 5], [0, 12, 0]);
  en.box({ name: 'EngineBase', s: [6, 3, 4], p: [0, 1.5, 0], c: '#b8862e', m: 'Metal', studs: 'top', collide: true });
  for (const x of [-1.6, 1.6]) {
    en.cyl({ name: 'EngineTube', axis: 'y', len: 4, d: 1.1, p: [x, 5, 0.6], c: '#7cf2ff', m: 'Neon', t: 0.2 });
    en.cyl({ name: 'TubeCap', axis: 'y', len: 0.5, d: 1.5, p: [x, 7.2, 0.6], c: '#8a4a1e', m: 'Metal' });
  }
  en.cyl({ name: 'EngineDial', axis: 'z', len: 0.4, d: 2.2, p: [0, 2, -2.1], c: '#f2e6c4' });
  en.box({ name: 'DialNeedle', s: [0.15, 0.9, 0.1], p: [0.2, 2.3, -2.35], r: [0, 0, -30], c: '#e8473a', shadow: false });
  en.beam([2.6, 3, 1], [HW / 2 - 6.4 - 2.6, 9, 3], 0.6, 0.6, { name: 'EnginePipe', c: '#8a4a1e', m: 'Metal' });
  plate(c, [0, HH - 4.0, -HD / 2 - 0.7], 4.4, 1.9, 'III', { frame: '#7cf2ff', color2: '#7cf2ff' });
  return c;
}

// ============================================================== GARAGE
function garageT2(root) {
  const c = kitModel(root, 'GarageT2');
  // a lean-to workshop on the back wall (open on its -X side)
  const z0 = GD / 2, z1 = GD / 2 + 10;
  c.box({ name: 'ShopFloor', s: [GW - 2, 0.24, z1 - z0], p: [0, 0.12, (z0 + z1) / 2], c: '#9a9ea6', m: 'Concrete', collide: true });
  c.box({ name: 'ShopBack', s: [GW - 2, 9, 1], p: [0, 4.5, z1 - 0.5], c: '#ddd0b0', studs: 'sides', collide: true });
  c.box({ name: 'ShopSide', s: [1, 9, z1 - z0], p: [GW / 2 - 1.5, 4.5, (z0 + z1) / 2], c: '#e9dfc4', studs: 'sides', collide: true });
  c.at([0, 9.8, (z0 + z1) / 2], [-11, 0, 0]).box({ name: 'ShopRoof', s: [GW, 0.6, z1 - z0 + 2], c: '#3a3d42', studs: 'top', collide: true });
  c.box({ name: 'ShopBench', s: [8, 0.6, 2.4], p: [-3, 3.2, z1 - 2], c: '#8a5a33', m: 'WoodPlanks', collide: true });
  for (const x of [-6.5, 0.5]) c.box({ name: 'BenchLeg', s: [0.5, 2.9, 2], p: [x, 1.6, z1 - 2], c: '#2b2d31' });
  const torch = c.box({ name: 'WeldTorch', s: [0.3, 0.3, 1.2], p: [-1, 3.8, z1 - 2.2], r: [0, 30, 0], c: '#d6402b', m: 'Metal' });
  E.particles(torch, 'Sparks', { rate: 10, life: [0.2, 0.5], speed: [6, 12], spread: [60, 60], dir: 1, size: [[0, 0.25], [1, 0]], color: [[0, [1, 0.95, 0.7]], [1, [1, 0.5, 0.1]]], emission: 1, accel: [0, -30, 0] });
  E.pointLight(torch, [1, 0.8, 0.5], 10, 0.6);
  c.box({ name: 'ToolCabinet', s: [3, 5, 1.8], p: [6.4, 2.5, z1 - 1.6], c: '#d6402b', studs: 'top', collide: true });
  for (let k = 0; k < 4; k++) c.cyl({ name: 'TyreStack', axis: 'y', len: 1.1, d: 3, p: [-8.6, 0.8 + k * 1.12, z0 + 3], c: '#26272b' });
  // an engine hoist out on the +X side, an engine block swinging from it
  const h = c.at([GW / 2 + 4.5, 0, -2]);
  h.beam([-2.2, 0, -1.8], [0, 8, 0], 0.6, 0.6, { name: 'HoistLeg', c: '#f2b632', m: 'Metal' });
  h.beam([2.2, 0, -1.8], [0, 8, 0], 0.6, 0.6, { name: 'HoistLeg', c: '#f2b632', m: 'Metal' });
  h.beam([0, 0, 2.2], [0, 8, 0], 0.6, 0.6, { name: 'HoistLeg', c: '#f2b632', m: 'Metal' });
  h.box({ name: 'HoistChain', s: [0.2, 3, 0.2], p: [0, 6.5, 0], c: '#3a3d42', m: 'Metal' });
  h.box({ name: 'EngineBlock', s: [2.4, 1.8, 2], p: [0, 4.1, 0], c: '#5d6168', m: 'Metal' });
  h.box({ name: 'EngineHead', s: [2.6, 0.5, 2.2], p: [0, 5.2, 0], c: '#d6402b', m: 'Metal' });
  plate(c, [0, GDH + 1.1, -GD / 2 - 0.1], 8, 1.3, 'WORKSHOP', { pps: 30 });
  return c;
}
function garageT3(root) {
  const c = kitModel(root, 'GarageT3');
  // an arched hangar shell over the garage + workshop: ribs, corrugated skin, an open front
  const R = 19, BASE = 3, SEGS = 12;
  const ribs = [-15, -7, 1, 9, 17, 25];
  const arc = (k) => { const a = Math.PI - (k / SEGS) * Math.PI; return [Math.cos(a) * R, BASE + Math.sin(a) * R]; };
  for (const z of ribs) {
    for (const sx of [-1, 1]) c.box({ name: 'HangarPost', s: [1.4, BASE, 1.4], p: [sx * R, BASE / 2, z], c: '#f2b632', studs: 'top', collide: true });
    for (let k = 0; k < SEGS; k++) {
      const [ax, ay] = arc(k), [bx, by] = arc(k + 1);
      c.beam([ax, ay, z], [bx, by, z], 1.2, 1.2, { name: 'HangarRib', c: z === ribs[0] ? '#f2b632' : '#5d6168', m: 'Metal', extend: 0.4, up: [0, 0, 1] });
    }
  }
  for (let b = 0; b < ribs.length - 1; b++) {
    const za = ribs[b], zb = ribs[b + 1];
    for (let k = 0; k < SEGS; k++) {
      const [ax, ay] = arc(k), [bx, by] = arc(k + 1);
      const mx = (ax + bx) / 2, my = (ay + by) / 2;
      const len = Math.hypot(bx - ax, by - ay);
      const tilt = Math.atan2(by - ay, bx - ax) * 180 / Math.PI;
      c.at([mx * 1.01, my * 1.0 + 0.2, (za + zb) / 2], [0, 0, tilt]).box({ name: 'HangarSkin', s: [len + 0.3, 0.3, zb - za], c: (k + b) % 2 ? '#9aa0a8' : '#8f949b', m: 'Metal' });
    }
  }
  // back wall: slats under the arch, with a round window
  const zb = ribs[ribs.length - 1];
  for (let k = 0; k < 10; k++) {
    const x = -R + (k + 0.5) * (2 * R / 10);
    const h = BASE + Math.sqrt(Math.max(0, R * R - x * x)) - 0.4;
    c.box({ name: 'HangarBack', s: [2 * R / 10 + 0.05, h, 0.6], p: [x, h / 2, zb + 0.3], c: k % 2 ? '#ddd0b0' : '#e9dfc4', studs: 'sides', collide: true });
  }
  c.cyl({ name: 'HangarWindow', axis: 'z', len: 0.3, d: 7, p: [0, BASE + R * 0.62, zb - 0.1], c: '#9cf0ff', m: 'Glass', t: 0.35, shadow: false });
  // the front arch: hazard stripes, the HANGAR sign, a beacon on top, a windsock behind
  for (let k = 0; k < SEGS; k++) {
    const [ax, ay] = arc(k), [bx, by] = arc(k + 1);
    c.beam([ax, ay, ribs[0] - 0.8], [bx, by, ribs[0] - 0.8], 0.6, 0.6, { name: 'HazardArch', c: k % 2 ? '#1d1e21' : '#f2b632', up: [0, 0, 1] });
  }
  const sign = c.box({ name: 'HangarSign', s: [15, 3.2, 0.6], p: [0, BASE + R + 2.6, ribs[0] - 0.6], c: '#2a2c31' });
  c.box({ name: 'HangarSignFrame', s: [15.8, 4, 0.4], p: [0, BASE + R + 2.6, ribs[0] - 0.2], c: '#f2b632', studs: 'top' });
  label(sign, 'Front', 'HANGAR', { pps: 30, color: '#ffffff', color2: '#f2b632' });
  const beacon = c.box({ name: 'Beacon', s: [1.2, 1.2, 1.2], p: [0, BASE + R + 5, ribs[0] - 0.6], c: '#ff3b2a', m: 'Neon' });
  beacon.tag('BlinkLight');
  const ws = c.at([R - 4, BASE + Math.sqrt(R * R - (R - 4) ** 2), zb - 2]);
  ws.cyl({ name: 'WindsockPole', axis: 'y', len: 7, d: 0.35, p: [0, 3.5, 0], c: '#d9d9d9', m: 'Metal' });
  for (let k = 0; k < 4; k++) ws.box({ name: 'Windsock', s: [1.6 - k * 0.25, 1.6 - k * 0.25, 1.3], p: [0, 6.2 - k * 0.15, -0.8 - k * 1.3], c: k % 2 ? '#ffffff' : '#ff7a1a', shadow: false });
  for (const sx of [-1, 1]) {
    const lamp = c.box({ name: 'HangarLamp', s: [2.2, 0.5, 2.2], p: [sx * 7, BASE + R - 4, 6], c: '#fff1d0', m: 'SmoothPlastic' });
    E.pointLight(lamp, [1, 0.95, 0.85], 26, 0.7);
  }
  return c;
}

// ============================================================== STAR PENS
// lot-local: origin = lot centre on the grass, the gate on the -Z side
const STYLES = {
  TyrannosaurusRex: { floor: ['#7a5636', 'Mud'], gate: '#3a3d42', trim: '#f2b632', sign: ['#ffe9a0', '#ff6a3a'], wallH: 7 },
  Giganotosaurus: { floor: ['#d9b77a', 'Sand'], gate: '#a8845a', trim: '#f2ece0', sign: ['#ffffff', '#6ee0c8'], wallH: 6 },
  Therizinosaurus: { floor: ['#6aa84a', 'Grass'], gate: '#7d5733', trim: '#c9d86a', sign: ['#f6f0dc', '#c9d86a'], wallH: 6 },
  Yutyrannus: { floor: ['#eef4f8', 'Snow'], gate: '#9fc8e8', trim: '#ffffff', sign: ['#ffffff', '#9fd8ff'], wallH: 5 },
  Postosuchus: { floor: ['#8a5a3a', 'Mud'], gate: '#9a4a32', trim: '#ffb070', sign: ['#ffe2c8', '#ff7a46'], wallH: 4.5 },
};
const PEN_NAMES = { TyrannosaurusRex: 'REX PIT', Giganotosaurus: 'GIGA RUN', Therizinosaurus: 'SCYTHE GROVE', Yutyrannus: 'FROST DEN', Postosuchus: 'MUD WALLOW', Mosasaurus: 'SEA PEN' };

// walk the perimeter (gate gap in the middle of the -Z side), calling seg(a, b) per straight piece
function perimeter(w, d, gateW, seg) {
  const x0 = -w / 2, x1 = w / 2, z0 = -d / 2, z1 = d / 2;
  seg([x0, z0], [-gateW / 2, z0]);
  seg([gateW / 2, z0], [x1, z0]);
  seg([x1, z0], [x1, z1]);
  seg([x1, z1], [x0, z1]);
  seg([x0, z1], [x0, z0]);
}
function along(a, b, step, fn) {
  const L = Math.hypot(b[0] - a[0], b[1] - a[1]);
  const n = Math.max(1, Math.round(L / step));
  const yaw = Math.atan2(-(b[0] - a[0]), -(b[1] - a[1])) * 180 / Math.PI;
  for (let k = 0; k < n; k++) {
    const t = (k + 0.5) / n;
    fn(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, L / n, yaw, k);
  }
}

const WALLS = {
  TyrannosaurusRex(c, a, b, H, R) {
    // log palisade between steel posts with hazard caps
    along(a, b, 2.5, (x, z, len, yaw, k) => {
      const h = H + (R() - 0.5) * 0.8;
      c.cyl({ name: 'PenLog', axis: 'y', len: h, d: 2.4, p: [x, h / 2, z], c: k % 2 ? '#7d5733' : '#8a6238', collide: true });
      if (k % 4 === 0) {
        c.at([x, 0, z], [0, yaw, 0]).box({ name: 'PenPost', s: [1.2, H + 1.4, 1.2], p: [0, (H + 1.4) / 2, 0], c: '#3a3d42', m: 'Metal', collide: true });
        c.at([x, 0, z], [0, yaw, 0]).box({ name: 'PenPostCap', s: [1.5, 0.6, 1.5], p: [0, H + 1.7, 0], c: k % 8 === 0 ? '#f2b632' : '#1d1e21' });
      }
    });
    c.beam([a[0], H * 0.6, a[1]], [b[0], H * 0.6, b[1]], 0.6, 0.6, { name: 'PenRail', c: '#3a3d42', m: 'Metal', collide: true });
  },
  Giganotosaurus(c, a, b, H, R) {
    // sandstone blocks with bone spikes
    along(a, b, 6, (x, z, len, yaw, k) => {
      const w = c.at([x, 0, z], [0, yaw, 0]);
      w.box({ name: 'PenBlock', s: [2.6, H, len + 0.05], p: [0, H / 2, 0], c: k % 2 ? '#c8a26a' : '#b8925a', m: 'Sandstone', studs: 'top', collide: true });
      if (k % 2 === 0) w.wedgeF({ name: 'BoneSpike', s: [0.8, 2.2, 1.2], p: [0, H + 1.1, 0], face: 'front', c: '#f2ece0' });
    });
  },
  Therizinosaurus(c, a, b, H, R) {
    // bamboo lattice panels between green poles
    along(a, b, 4, (x, z, len, yaw, k) => {
      const w = c.at([x, 0, z], [0, yaw, 0]);
      w.box({ name: 'PenLattice', s: [0.4, H - 1, len - 0.6], p: [0, (H - 1) / 2 + 0.5, 0], c: k % 2 ? '#c9b46a' : '#d8c47a', m: 'WoodPlanks', collide: true });
      w.cyl({ name: 'BambooPole', axis: 'y', len: H + 0.6, d: 0.9, p: [0, (H + 0.6) / 2, len / 2], c: '#7fae4a' });
    });
  },
  Yutyrannus(c, a, b, H, R) {
    // ice blocks with snow caps
    along(a, b, 6, (x, z, len, yaw, k) => {
      const w = c.at([x, 0, z], [0, yaw + (R() - 0.5) * 4, 0]);
      w.box({ name: 'PenIce', s: [2.6, H, len + 0.1], p: [0, H / 2, 0], c: k % 2 ? '#bfe4f8' : '#a8d8f2', m: 'Ice', t: 0.12, collide: true });
      w.box({ name: 'SnowCap', s: [3, 0.7, len + 0.3], p: [0, H + 0.3, 0], c: '#ffffff', m: 'Snow' });
    });
  },
  Postosuchus(c, a, b, H, R) {
    // stacked red rocks
    along(a, b, 5, (x, z, len, yaw, k) => {
      const w = c.at([x, 0, z], [0, yaw + (R() - 0.5) * 14, 0]);
      w.box({ name: 'PenRock', s: [3 + R(), H * 0.7, len + 0.8], p: [0, H * 0.35, 0], c: k % 2 ? '#9a4a32' : '#b05a3a', m: 'Slate', studs: 'top', collide: true });
      w.box({ name: 'PenRock', s: [2.2 + R(), H * 0.45, len * 0.7], p: [(R() - 0.5) * 0.6, H * 0.7 + H * 0.2, 0], r: [0, (R() - 0.5) * 20, 0], c: '#8a3e2a', m: 'Slate', studs: 'top', collide: true });
    });
  },
};

const PROPS = {
  TyrannosaurusRex(c, w, d, R) {
    // a meat crane at the back, a fallen log, ferns, a boulder, floodlights at the back corners
    const k = c.at([w / 2 - 5, 0, d / 2 - 6]);
    k.box({ name: 'CranePost', s: [1, 12, 1], p: [0, 6, 0], c: '#3a3d42', m: 'Metal', collide: true });
    k.beam([0, 11.5, 0], [-6, 11.5, -3], 0.6, 0.6, { name: 'CraneArm', c: '#f2b632', m: 'Metal' });
    k.box({ name: 'CraneRope', s: [0.15, 4, 0.15], p: [-6, 9.4, -3], c: '#3a2a1a' });
    k.box({ name: 'Meat', s: [2.6, 1.8, 1.6], p: [-6, 6.6, -3], c: '#c8452a' });
    k.box({ name: 'MeatBone', s: [3.6, 0.5, 0.5], p: [-6, 6.6, -3], c: '#f2ece0' });
    c.at([-w / 2 + 6, 0, 2], [0, 70, 0]).cyl({ name: 'FallenLog', axis: 'x', len: Math.min(14, d * 0.4), d: 2.6, p: [0, 1.3, 0], c: '#6b4a2b', collide: true });
    for (let i = 0; i < 3; i++) E.fern(c, [(R() - 0.5) * (w - 10), 0.1, (R() - 0.3) * (d - 14)], 1.3, 30000 + i);
    E.rock(c, [-w / 2 + 6, 0.1, -d / 2 + 8], 2.4, 30100);
    for (const sx of [-1, 1]) {
      const t = c.at([sx * (w / 2 - 1.8), 0, d / 2 - 1.8]);
      t.box({ name: 'FloodPost', s: [0.8, 10, 0.8], p: [0, 5, 0], c: '#3a3d42', m: 'Metal' });
      const lamp = t.at([0, 10.2, 0], [-30, sx > 0 ? 220 : 140, 0]).box({ name: 'FloodLamp', s: [1.8, 1.2, 1.2], c: '#fff1d0', m: 'SmoothPlastic' });
      E.pointLight(lamp, [1, 0.95, 0.85], 22, 0.6);
    }
  },
  Giganotosaurus(c, w, d, R) {
    // a bleached ribcage arch, boulders, a dead tree
    const rc = c.at([0, 0, d * 0.12]);
    for (let i = 0; i < 4; i++) for (const sx of [-1, 1]) {
      const z = -4.5 + i * 3;
      rc.beam([sx * 5, 0, z], [sx * 4.6, 5, z], 0.9, 0.9, { name: 'RibBone', c: '#f2ece0', extend: 0.3 });
      rc.beam([sx * 4.6, 5, z], [sx * 1.2, 7.4 - i * 0.3, z], 0.9, 0.9, { name: 'RibBone', c: '#f2ece0', extend: 0.3 });
    }
    rc.beam([0, 7.6, -6], [0, 6.6, 6], 1.1, 1.1, { name: 'SpineBone', c: '#e6dccb' });
    E.rock(c, [w / 2 - 6, 0.1, -d / 2 + 8], 2.6, 30200);
    E.rock(c, [-w / 2 + 5, 0.1, d / 2 - 8], 2, 30201);
    const t = c.at([-w / 2 + 6, 0, -d * 0.2]);
    t.box({ name: 'DeadTrunk', s: [1.2, 9, 1.2], p: [0, 4.5, 0], r: [0, 0, 6], c: '#8a7a64' });
    t.beam([0.4, 6.5, 0], [3, 9, 0.5], 0.5, 0.5, { name: 'DeadBranch', c: '#8a7a64' });
    t.beam([0.2, 5, 0], [-2.6, 7.4, -0.4], 0.5, 0.5, { name: 'DeadBranch', c: '#8a7a64' });
  },
  Therizinosaurus(c, w, d, R) {
    // leafy trees to pull at, berry bushes, a fruit pile
    E.jungleTree(c, [-w / 2 + 6, 0.1, d * 0.18], 13, 30300, { canopy: 7 });
    E.jungleTree(c, [w / 2 - 6, 0.1, -d * 0.15], 15, 30301, { canopy: 7 });
    for (let i = 0; i < 3; i++) E.bush(c, [(R() - 0.5) * (w - 10), 0.1, (R() - 0.5) * (d - 14)], 1.2, 30310 + i, { berries: '#ff5a7a' });
    for (let i = 0; i < 5; i++) c.ball({ name: 'Fruit', d: 1, p: [2 + (i % 3) * 0.9, 0.6 + Math.floor(i / 3) * 0.7, -d / 2 + 6 + (i % 2) * 0.6], c: i % 2 ? '#ff8a2a' : '#ffd23a' });
  },
  Yutyrannus(c, w, d, R) {
    // snowy pines, drifts, ice boulders
    const pine = (x, z, h) => {
      const t = c.at([x, 0, z]);
      t.box({ name: 'PineTrunk', s: [1, 3, 1], p: [0, 1.5, 0], c: '#6b4a2b' });
      for (let i = 0; i < 4; i++) {
        const s = (4.6 - i) * (h / 12);
        t.box({ name: 'PineTier', s: [s * 1.6, 2.2, s * 1.6], p: [0, 3 + i * 2.2, 0], r: [0, i * 20, 0], c: '#2f6a4a', studs: 'top' });
        t.box({ name: 'PineSnow', s: [s * 1.2, 0.4, s * 1.2], p: [0, 4.2 + i * 2.2, 0], r: [0, i * 20 + 10, 0], c: '#ffffff', m: 'Snow' });
      }
    };
    pine(-w / 2 + 6, d * 0.2, 12);
    pine(w / 2 - 6, -d * 0.1, 10);
    for (let i = 0; i < 3; i++) c.box({ name: 'SnowDrift', s: [6 + R() * 4, 1.2, 4 + R() * 3], p: [(R() - 0.5) * (w - 12), 0.6, (R() - 0.5) * (d - 14)], r: [0, R() * 90, 0], c: '#f6fbff', m: 'Snow' });
    for (let i = 0; i < 2; i++) c.box({ name: 'IceRock', s: [3, 2.4, 2.6], p: [(R() - 0.5) * (w - 12), 1.2, -d / 2 + 6 + i * 4], r: [0, R() * 90, 10], c: '#a8d8f2', m: 'Ice', t: 0.1 });
  },
  Postosuchus(c, w, d, R) {
    // a mud wallow, reeds, a flat basking rock
    c.box({ name: 'MudPool', s: [Math.min(16, w - 10), 0.14, Math.min(12, d * 0.3)], p: [0, 0.16, d * 0.1], c: '#4f321e', m: 'SmoothPlastic', refl: 0.2 });
    c.box({ name: 'MudRim', s: [Math.min(18, w - 8), 0.1, Math.min(14, d * 0.3 + 2)], p: [0, 0.12, d * 0.1], c: '#6b4528', m: 'Mud' });
    for (let i = 0; i < 8; i++) c.box({ name: 'Reed', s: [0.25, 2 + R() * 1.5, 0.25], p: [-w / 2 + 3 + R() * 4, 1.2, (R() - 0.5) * (d - 10)], r: [(R() - 0.5) * 14, 0, (R() - 0.5) * 14], c: '#7a8a3a', shadow: false });
    c.box({ name: 'BaskRock', s: [7, 1.4, 5], p: [w / 2 - 6, 0.7, -d / 2 + 8], r: [0, 18, 0], c: '#b05a3a', m: 'Slate', studs: 'top', collide: true });
    E.rock(c, [-w / 2 + 5, 0.1, d / 2 - 6], 2, 30500);
  },
};

function landPen(root, species, lot) {
  const s = P.star.find((x) => x.id === lot);
  const [x0, z0, x1, z1] = s.rect;
  const w = x1 - x0, d = z1 - z0;
  const st = STYLES[species];
  const c = kitModel(root, `Pen_${species}_${lot}`);
  const R = rng(4000 + w + d + species.length * 7);
  const gateW = 10;
  c.box({ name: 'PenFloor', s: [w - 1.5, 0.1, d - 1.5], p: [0, 0.07, 0], c: st.floor[0], m: st.floor[1], collide: false, shadow: false });
  perimeter(w - 1, d - 1, gateW, (a, b) => WALLS[species](c, a, b, st.wallH, R));
  // gate: two pillars, a lintel with the pen's sign, closed doors
  const gz = -d / 2 + 0.5;
  for (const sx of [-1, 1]) {
    c.box({ name: 'GatePillar', s: [2.6, st.wallH + 4, 2.6], p: [sx * (gateW / 2 + 1.3), (st.wallH + 4) / 2, gz], c: st.gate, studs: 'top', collide: true });
    c.box({ name: 'GatePillarCap', s: [3.2, 0.7, 3.2], p: [sx * (gateW / 2 + 1.3), st.wallH + 4.35, gz], c: st.trim, studs: 'top' });
    c.box({ name: 'PenDoor', s: [gateW / 2 - 0.2, st.wallH, 0.6], p: [sx * (gateW / 4), st.wallH / 2, gz], c: shade(st.gate, 0.85), m: 'WoodPlanks', collide: true });
  }
  c.box({ name: 'GateLintel', s: [gateW + 5.4, 1.2, 1.6], p: [0, st.wallH + 3.2, gz], c: st.gate, studs: 'top' });
  const sign = c.box({ name: 'PenSign', s: [gateW + 2, 2.4, 0.4], p: [0, st.wallH + 1.6, gz - 1], c: '#2a2c31' });
  c.box({ name: 'PenSignFrame', s: [gateW + 2.6, 3, 0.3], p: [0, st.wallH + 1.6, gz - 0.75], c: st.trim });
  label(sign, 'Front', PEN_NAMES[species], { pps: 30, color: st.sign[0], color2: st.sign[1] });
  for (const sx of [-1, 1]) E.lampPost(c, [sx * (gateW / 2 + 4.6), 0, gz - 1.5], { yaw: 0, h: 6 });
  PROPS[species](c, w, d, R);
  // where the star wanders (CampView), and a good spot to watch from
  const b = c.box({ name: 'PenBounds', s: [w - 10, 0.4, d - 12], p: [0, 0.3, 1.5], t: 1, shadow: false });
  b.set('CanQuery', 'bool', false);
  return c;
}

function seaPen(root) {
  const s = P.star.find((x) => x.kind === 'sea');
  const [x0, z0, x1, z1] = s.rect;
  const w = x1 - x0, d = z1 - z0;
  const c = kitModel(root, `Pen_Mosasaurus_${s.id}`);
  const BED = IL.SEABED_Y - IL.WATER_Y; // seabed, relative to the water line
  const deckY = 0.9;
  // a floating dock round the pen
  const ring = [[-w / 2, -d / 2], [w / 2, -d / 2], [w / 2, d / 2], [-w / 2, d / 2]];
  for (let k = 0; k < 4; k++) {
    const a = ring[k], b = ring[(k + 1) % 4];
    c.beam([a[0], deckY - 0.3, a[1]], [b[0], deckY - 0.3, b[1]], 4, 0.6, { name: 'DockDeck', c: k % 2 ? '#a8743f' : '#b98450', m: 'WoodPlanks', collide: true, extend: 4 });
    along(a, b, 8, (x, z) => c.cyl({ name: 'DockPile', axis: 'y', len: deckY - BED, d: 1.1, p: [x, (deckY + BED) / 2, z], c: '#6b4a2b' }));
    // the net fence under the inner edge of the dock (the star stays in, the fish come and go)
    along(a, b, 3, (x, z, len, yaw) => {
      const nx = Math.abs(x) >= w / 2 - 0.01 ? x - Math.sign(x) * 1.6 : x;
      const nz = Math.abs(z) >= d / 2 - 0.01 ? z - Math.sign(z) * 1.6 : z;
      c.at([nx, 0, nz], [0, yaw, 0]).box({ name: 'NetPanel', s: [0.12, 5, len - 0.3], p: [0, -1.6, 0], c: '#2b2d31', t: 0.35, shadow: false });
    });
  }
  for (const [x, z] of ring) {
    c.cyl({ name: 'Buoy', axis: 'y', len: 1.8, d: 2, p: [x, 0.4, z], c: '#e8473a', shadow: false });
    c.cyl({ name: 'BuoyStripe', axis: 'y', len: 0.5, d: 2.05, p: [x, 0.6, z], c: '#ffffff', shadow: false });
    const l = c.box({ name: 'BuoyLight', s: [0.6, 0.6, 0.6], p: [x, 1.7, z], c: '#ffd27a', m: 'Neon' });
    l.tag('BlinkLight');
  }
  // the feeding platform at the far side with a little crane and a bucket of fish
  const fp = c.at([0, 0, d / 2 + 4]);
  fp.box({ name: 'FeedDeck', s: [12, 0.6, 6], p: [0, deckY, 0], c: '#b98450', m: 'WoodPlanks', collide: true });
  fp.box({ name: 'CranePost', s: [0.9, 8, 0.9], p: [4, deckY + 4, 1], c: '#3a3d42', m: 'Metal' });
  fp.beam([4, deckY + 7.6, 1], [4, deckY + 7.6, -6], 0.5, 0.5, { name: 'CraneArm', c: '#f2b632', m: 'Metal' });
  fp.box({ name: 'CraneRope', s: [0.12, 3, 0.12], p: [4, deckY + 6, -6], c: '#3a2a1a' });
  fp.cyl({ name: 'FishBucket', axis: 'y', len: 1.4, d: 1.6, p: [4, deckY + 3.9, -6], c: '#5d6168', m: 'Metal' });
  for (let i = 0; i < 3; i++) fp.box({ name: 'Fish', s: [0.4, 0.3, 1.2], p: [3.6 + i * 0.4, deckY + 4.7, -6], r: [0, i * 40, 20], c: '#9ab8c8' });
  for (let i = 0; i < 4; i++) fp.cyl({ name: 'Lifebuoy', axis: 'z', len: 0.4, d: 1.6, p: [-4 + i * 0.1, deckY + 1.2, 2.8], c: i % 2 ? '#ffffff' : '#e8473a', shadow: false });
  // a gangway back to the island's beach (its back shore is ~10-16 studs in front of the pen)
  c.beam([0, deckY - 0.3, -d / 2 - 2], [0, 0.55 - IL.WATER_Y - 0.2, -d / 2 - 11], 4, 0.5, { name: 'Gangway', c: '#a8743f', m: 'WoodPlanks', collide: true });
  const sign = c.box({ name: 'PenSign', s: [11, 2.2, 0.4], p: [0, deckY + 4.2, -d / 2 - 1.2], c: '#2a2c31' });
  for (const sx of [-1, 1]) c.box({ name: 'SignPost', s: [0.6, 4.6, 0.6], p: [sx * 5.2, deckY + 2.3, -d / 2 - 1.2], c: '#6b4a2b' });
  label(sign, 'Front', PEN_NAMES.Mosasaurus, { pps: 30, color: '#e8fbff', color2: '#46aff0' });
  const b = c.box({ name: 'PenBounds', s: [w - 12, 0.4, d - 12], p: [0, -2.4, 0], t: 1, shadow: false });
  b.set('CanQuery', 'bool', false);
  b.attr('Swim', true);
  return c;
}

// ============================================================== POWER TRAINER (2026-10-14)
// Trainer1..Trainer7: one machine per trainer tier (Config.Trainer.TierNames), each clearly grander than the last.
// A training RANGE: you stand on the glowing TrainerPad at the front (-Z) and fire darts down the lane at the dino
// target dummies at the back (+Z). Kit-local footprint x -7.5..7.5, z -18..18 (islandLayout PLAN.trainer), as tall
// as it likes. Named parts the game uses: TrainerPad (the pad you stand on, Trainer.luau checks it), TrainerBoard
// (the upgrade board; TrainerView puts the level / price / +POWER per second on it and the prompt by it),
// LevelPip1..4 (IslandView lights one per level in the tier), TargetPoint (where the darts fly), PadFx (pad glow
// host). Accent neon is allowed here (calm.js leaves Trainer models alone: they're the island's showpiece).
const TR = {
  PAD_Z: -12.5, // pad centre
  BOARD: [7.4, -16.6], // board legs (x, z): the front corner on the lodge side, turned toward the drive
  ACCENT: ['#8fd14f', '#ff9a2e', '#38d6c4', '#ff4a3d', '#ffb02e', '#b06cff', '#40e8ff'],
  ACCENT2: ['#f2c230', '#ffd23a', '#ffffff', '#ffd23a', '#ff6a2a', '#7cf2ff', '#ff4fd8'],
};
const DINO_SRC = { Velociraptor: 'velociraptor', Triceratops: 'triceratops', Stegosaurus: 'stegosaurus', TyrannosaurusRex: 'trex', Giganotosaurus: 'giganotosaurus' };
const dinoCache = {};
// a dino target dummy: the real species model recoloured into a material (wood / metal / amber / bone / holo),
// origin at its feet, facing -Z (at the pad) turned by yaw
function dummy(c, species, p, yaw, k, style) {
  const B = require('./builder.js');
  if (!dinoCache[species]) dinoCache[species] = B.previewParts(require(`./dinos/${DINO_SRC[species]}.js`).build(), {}).filter((pp) => pp.t < 1);
  const d = c.group('Dummy_' + species).at(p, [0, yaw, 0]);
  const PAL2 = {
    wood: { tones: ['#7d5733', '#8a6238', '#a8743f', '#c08a52'], m: 'WoodPlanks', eye: '#2b2d31', eyeM: 'SmoothPlastic' },
    paint: { tones: ['#b8452a', '#d65a32', '#e8823a', '#f2b062'], m: 'SmoothPlastic', eye: '#ffffff', eyeM: 'SmoothPlastic' },
    metal: { tones: ['#4a4f57', '#5d6168', '#8c9399', '#b8bec4'], m: 'Metal', eye: '#ff3b2a', eyeM: 'Neon' },
    amber: { tones: ['#b0581a', '#d9781f', '#f29a2e', '#ffc25a'], m: 'Glass', t: 0.25, eye: '#fff1c4', eyeM: 'Neon' },
    bone: { tones: ['#bfb39a', '#d6cbb2', '#e6dccb', '#f2ece0'], m: 'SmoothPlastic', eye: '#b06cff', eyeM: 'Neon' },
    holo: { tones: ['#1c8fb0', '#2fbfe0', '#40e8ff', '#9ff6ff'], m: 'Neon', t: 0.45, eye: '#ff4fd8', eyeM: 'Neon' },
  }[style];
  for (const pp of dinoCache[species]) {
    const [x, y, z, ...r] = pp.cf;
    const hex = pp.c.replace('#', '');
    const lum = (parseInt(hex.slice(0, 2), 16) * 0.3 + parseInt(hex.slice(2, 4), 16) * 0.59 + parseInt(hex.slice(4, 6), 16) * 0.11) / 255;
    const eye = /Eye|Pupil/.test(pp.n) && !/Lid|Brow|Socket/.test(pp.n);
    const o = { name: 'Dummy' + pp.n, s: pp.s.map((v) => v * k), c: eye ? PAL2.eye : PAL2.tones[Math.min(3, Math.floor(lum * 4.4))], m: eye ? PAL2.eyeM : PAL2.m, shadow: style !== 'holo' };
    if (PAL2.t && !eye) o.t = PAL2.t;
    if (pp.k === 'wedge') o.cls = 'WedgePart';
    else if (pp.k === 'cyl') o.shape = 'Cylinder';
    else if (pp.k === 'ball') o.shape = 'Ball';
    else if (pp.k === 'ellipsoid') o.mesh = 'sphere';
    d._add(new CF(x * k, y * k, z * k, r), o);
  }
  return d;
}
// a bullseye disc facing -Z (the pad)
function bullseye(c, p, dia, o = {}) {
  const cols = o.cols || ['#ffffff', '#e8473a', '#ffffff', '#e8473a'];
  for (let i = 0; i < cols.length; i++) {
    c.cyl({ name: 'Bullseye', axis: 'z', len: 0.2 + i * 0.06, d: dia * (1 - i / cols.length), p: [p[0], p[1], p[2] - i * 0.03], c: cols[i], m: o.m || 'SmoothPlastic', shadow: false });
  }
  c.cyl({ name: 'BullseyeRim', axis: 'z', len: 0.16, d: dia + 0.5, p: [p[0], p[1], p[2] + 0.12], c: o.rim || '#2b2d31' });
}
// ---------------------------------------------------------------- the range every tier is built on (2026-10-14 v2)
// (user, with a reference: "make the models nice") A compact TRAINING MAT like the genre's best: a chunky studded
// border with corner blocks round a clean floor, an inset square round the big glowing pad, two slots running down to
// ONE bold target at the back framed by a gate, a few themed props, and a big angled UPGRADE board beside the pad.
// Kit-local: the mat is x -MAT.X..MAT.X, z MAT.Z0..MAT.Z1; behind it (z > MAT.Z1) each tier stands its showpiece.
const MAT = { X: 5.8, Z0: -17.4, Z1: 7.8, H: 0.9, T: 1.1, FLOOR: 0.3 };
const TGT_Z = 3.6; // where the target stands

// one stretch of border from a to b (along x or z), chunky alternating blocks with studded tops
function borderRun(c, a, b, th, gap) {
  const dx = b[0] - a[0], dz = b[1] - a[1];
  const L = Math.hypot(dx, dz);
  const n = Math.max(1, Math.round(L / 2.4));
  const seg = L / n;
  for (let i = 0; i < n; i++) {
    const t0 = i / n, t1 = (i + 1) / n;
    const mx = a[0] + dx * (t0 + t1) / 2, mz = a[1] + dz * (t0 + t1) / 2;
    if (gap && Math.abs(mx) < gap && Math.abs(dz) < 0.01) continue; // the entrance in the front run
    const along = Math.abs(dx) > Math.abs(dz);
    const s = along ? [seg - 0.08, MAT.H, MAT.T] : [MAT.T, MAT.H, seg - 0.08];
    c.box({ name: 'MatBorder', s, p: [mx, MAT.FLOOR + MAT.H / 2, mz], c: i % 2 ? th.border : th.borderHi, m: th.borderM || 'SmoothPlastic', studs: 'top', collide: true });
    if (th.trim) c.box({ name: 'MatTrim', s: along ? [seg - 0.08, 0.16, 0.18] : [0.18, 0.16, seg - 0.08], p: [mx - (along ? 0 : Math.sign(mx) * (MAT.T / 2 - 0.05)), MAT.FLOOR + MAT.H + 0.02, mz - (along ? Math.sign(mz) * (MAT.T / 2 - 0.05) : 0)], c: th.trim, m: 'Neon', shadow: false });
  }
}
// the mat: floor, border, corner blocks, the inset square round the pad, the two slots down to the target
function rangeMat(c, th) {
  const X = MAT.X, Z0 = MAT.Z0, Z1 = MAT.Z1;
  c.box({ name: 'MatBase', s: [X * 2, MAT.FLOOR, Z1 - Z0], p: [0, MAT.FLOOR / 2, (Z0 + Z1) / 2], c: th.base || shade(th.border, 0.8), m: th.borderM || 'SmoothPlastic', collide: true });
  c.box({ name: 'MatFloor', s: [X * 2 - MAT.T * 2, 0.06, Z1 - Z0 - MAT.T * 2], p: [0, MAT.FLOOR + 0.03, (Z0 + Z1) / 2], c: th.floor, m: th.floorM || 'SmoothPlastic', shadow: false });
  const xi = X - MAT.T / 2, z0 = Z0 + MAT.T / 2, z1 = Z1 - MAT.T / 2;
  borderRun(c, [-xi, z0], [-xi, z1], th);
  borderRun(c, [xi, z0], [xi, z1], th);
  borderRun(c, [-xi, z1], [xi, z1], th);
  borderRun(c, [-xi, z0], [xi, z0], th, 2.2); // (a step-in gap at the front, by the drive)
  for (const [x, z] of [[-xi, z0], [xi, z0], [-xi, z1], [xi, z1], [-2.6, z0], [2.6, z0]]) {
    const big = Math.abs(x) > 3;
    const s = big ? 1.9 : 1.4, h = big ? 1.9 : 1.5;
    c.box({ name: 'MatCorner', s: [s, h, s], p: [x, MAT.FLOOR + h / 2, z], c: th.corner, m: th.cornerM || 'SmoothPlastic', studs: 'top', collide: true });
    c.box({ name: 'MatCornerCap', s: [s + 0.3, 0.35, s + 0.3], p: [x, MAT.FLOOR + h + 0.17, z], c: th.cap, m: th.capM || 'SmoothPlastic', studs: 'top' });
  }
  // the inset square round the pad, and the two slots running from it to the target (the reference's lines)
  const L = th.line, y = MAT.FLOOR + 0.08, sq = 9.4, cz = TR.PAD_Z + 0.4;
  for (const [s, p] of [[[sq, 0.1, 0.32], [0, y, cz - sq / 2]], [[sq, 0.1, 0.32], [0, y, cz + sq / 2]], [[0.32, 0.1, sq], [-sq / 2, y, cz]], [[0.32, 0.1, sq], [sq / 2, y, cz]]]) {
    c.box({ name: 'MatLine', s, p, c: L, shadow: false });
  }
  for (const x of [-1.8, 1.8]) c.box({ name: 'MatSlot', s: [0.32, 0.1, TGT_Z - 2 - (cz + sq / 2)], p: [x, y, (TGT_Z - 2 + cz + sq / 2) / 2], c: L, shadow: false });
}
// the glowing pad (TrainerPad): a bright disc in a studded ring - the first thing you see on the mat
function trainerPad(c, tier, accent, th) {
  const z = TR.PAD_Z;
  const R = 3.2 + tier * 0.12; // (Config.Trainer.PadRadius 4.6 covers the biggest)
  const y0 = MAT.FLOOR;
  c.cyl({ name: 'PadRing', axis: 'y', len: 0.36, d: R * 2 + 1.6, p: [0, y0 + 0.18, z], c: th.padRing || th.border, m: th.borderM || 'SmoothPlastic', collide: true });
  const pad = c.cyl({ name: 'TrainerPad', axis: 'y', len: 0.3, d: R * 2, p: [0, y0 + 0.3, z], c: shade(accent, 1.35), m: 'Neon', t: 0.05, collide: true });
  c.cyl({ name: 'PadInner', axis: 'y', len: 0.32, d: R * 1.15, p: [0, y0 + 0.32, z], c: '#ffffff', m: 'Neon', t: 0.15, shadow: false });
  const n = 14 + tier * 2;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    c.cyl({ name: 'PadStud', axis: 'y', len: 0.22, d: 0.55, p: [Math.cos(a) * (R + 0.42), y0 + 0.44, z + Math.sin(a) * (R + 0.42)], c: i % 2 ? (th.cap || '#ffffff') : accent, m: i % 2 ? 'SmoothPlastic' : 'Neon', shadow: false });
  }
  const fx = c.box({ name: 'PadFx', s: [1, 1, 1], p: [0, 1, z], t: 1, shadow: false });
  fx.set('CanQuery', 'bool', false);
  E.pointLight(pad, [1, 1, 1].map((v, i) => Math.min(1, parseInt(accent.slice(1 + i * 2, 3 + i * 2), 16) / 255 + 0.35)), 12 + tier * 1.5, 1.1);
  E.particles(pad, 'PadMotes', { rate: 6, life: [1, 1.8], speed: [1.2, 2.4], size: [[0, 0.3], [1, 0]], color: [1, 1, 1], emission: 0.9, spread: [12, 12], dir: 1 });
  return pad;
}
// the UPGRADE board (TrainerBoard): big, on two chunky posts beside the pad, leaning back a little and turned to face
// you as you stand on the pad (TrainerView writes LEVEL N > N+1, the price, +POWER/SEC on it); LevelPip1..4 on top
function trainerBoard(c, tier, accent, th) {
  const g = c.at([-MAT.X - 0.4, 0, -7.6], [0, -32, 0]);
  const W = 6.6, H = 4, y = 4.6;
  for (const x of [-W / 2 + 0.6, W / 2 - 0.6]) {
    g.box({ name: 'BoardPost', s: [1.1, y + H / 2 + 0.4, 1.1], p: [x, (y + H / 2 + 0.4) / 2, 0.7], c: th.post, m: th.postM || 'SmoothPlastic', studs: 'top', collide: true });
    g.box({ name: 'BoardFoot', s: [1.7, 0.6, 1.7], p: [x, 0.3, 0.7], c: th.corner, m: th.cornerM || 'SmoothPlastic', studs: 'top', collide: true });
  }
  const b = g.at([0, y, 0], [8, 0, 0]);
  b.box({ name: 'TrainerBoard', s: [W, H, 0.4], c: '#20242b', collide: true });
  b.box({ name: 'BoardFrame', s: [W + 0.8, H + 0.8, 0.36], p: [0, 0, 0.22], c: th.frame || th.post, m: th.postM || 'SmoothPlastic', studs: 'sides' });
  b.box({ name: 'BoardTrim', s: [W + 0.9, 0.22, 0.5], p: [0, H / 2 + 0.42, 0.1], c: accent, m: 'Neon', shadow: false });
  for (let k = 1; k <= 4; k++) b.box({ name: 'LevelPip' + k, s: [0.8, 0.55, 0.55], p: [-1.8 + (k - 1) * 1.2, H / 2 + 0.85, 0.15], c: accent, m: 'Neon', shadow: false });
  b.box({ name: 'PipBar', s: [W * 0.85, 0.4, 0.8], p: [0, H / 2 + 0.55, 0.2], c: th.post, m: th.postM || 'SmoothPlastic', studs: 'top' });
  return g;
}
function targetPoint(c, p) {
  const t = c.box({ name: 'TargetPoint', s: [1, 1, 1], p, t: 1, shadow: false });
  t.set('CanQuery', 'bool', false);
}
// a round plinth the target stands on
function plinth(c, p, d, th, o = {}) {
  c.cyl({ name: 'TargetPlinth', axis: 'y', len: o.h || 0.7, d, p: [p[0], MAT.FLOOR + (o.h || 0.7) / 2, p[2]], c: o.c || th.border, m: o.m || th.borderM || 'SmoothPlastic', collide: true });
  c.cyl({ name: 'TargetPlinthTop', axis: 'y', len: 0.12, d: d - 0.6, p: [p[0], MAT.FLOOR + (o.h || 0.7) + 0.06, p[2]], c: o.top || th.cap, m: o.topM || 'SmoothPlastic', shadow: false });
  return MAT.FLOOR + (o.h || 0.7) + 0.12;
}
// a raised pond (the island floor is solid: a sunk one would vanish into it)
function raisedPond(c, p, w, d, o = {}) {
  const g = c.at(p, [0, o.yaw || 0, 0]);
  const rimC = o.rim || ['#9a948a', '#8a8478', '#b0aa9e'];
  const n = Math.round((w + d) / 1.1);
  for (let i = 0; i < n * 2; i++) {
    const u = (i / (n * 2)) * 2 * (w + d);
    let x, z;
    if (u < w) { x = -w / 2 + u; z = -d / 2; } else if (u < w + d) { x = w / 2; z = -d / 2 + (u - w); } else if (u < 2 * w + d) { x = w / 2 - (u - w - d); z = d / 2; } else { x = -w / 2; z = d / 2 - (u - 2 * w - d); }
    g.box({ name: 'PondRim', s: [1.1, 0.7, 1.1], p: [x, MAT.FLOOR + 0.35, z], r: [0, (i * 37) % 40, 0], c: rimC[i % rimC.length], m: 'Slate', studs: 'top', collide: true });
  }
  g.box({ name: 'PondWater', s: [w - 0.4, 0.5, d - 0.4], p: [0, MAT.FLOOR + 0.3, 0], c: o.water || '#4fb3d9', m: 'Glass', t: 0.25, shadow: false }).tag('DinoWater');
  for (const [x, z, col] of (o.koi || [])) {
    g.box({ name: 'Koi', s: [0.35, 0.2, 0.9], p: [x, MAT.FLOOR + 0.48, z], r: [0, (x * 97) % 180, 0], c: col, shadow: false });
  }
  for (const [x, z] of (o.lilies || [])) g.cyl({ name: 'LilyPad', axis: 'y', len: 0.08, d: 0.9, p: [x, MAT.FLOOR + 0.58, z], c: '#4fb043', shadow: false });
  return g;
}
// a clump of bamboo (segmented green poles with nodes and a few leaves)
function bamboo(c, p, n, h, seed) {
  const R = rng(seed);
  const g = c.group('Bamboo');
  for (let i = 0; i < n; i++) {
    const x = p[0] + (R() - 0.5) * 1.8, z = p[2] + (R() - 0.5) * 1.8, hh = h * (0.7 + R() * 0.4);
    const segs = Math.round(hh / 1.6);
    for (let k = 0; k < segs; k++) {
      g.cyl({ name: 'BambooCane', axis: 'y', len: 1.5, d: 0.45, p: [x, p[1] + 0.75 + k * 1.6, z], c: k % 2 ? '#7fbf3f' : '#8fd14f', shadow: k === 0 });
      g.cyl({ name: 'BambooNode', axis: 'y', len: 0.14, d: 0.55, p: [x, p[1] + 1.55 + k * 1.6, z], c: '#5f9a2f', shadow: false });
    }
    for (let k = 0; k < 3; k++) {
      const a = R() * 360;
      g.at([x, p[1] + segs * 1.6 - k * 0.9, z], [0, a, 0]).box({ name: 'BambooLeaf', s: [0.35, 0.08, 1.6], p: [0, 0, -0.8], r: [-20, 0, 0], c: k % 2 ? '#4fb043' : '#6ccf4f', shadow: false });
    }
  }
  return g;
}
// a blossom tree: a crooked studded trunk and puffy cube canopy clusters
function blossomTree(c, p, h, seed, cols) {
  const R = rng(seed);
  const g = c.group('BlossomTree');
  const t = g.at(p, [0, R() * 360, 0]);
  let x = 0, y = 0;
  for (let i = 0; i < 4; i++) {
    const lean = (i % 2 ? 1 : -1) * (6 + R() * 6);
    t.box({ name: 'Trunk', s: [1.3 - i * 0.12, h / 4 + 0.1, 1.3 - i * 0.12], p: [x, y + h / 8, 0], r: [0, 0, lean], c: i % 2 ? '#5a3a22' : '#6b4a2b', studs: 'sides', collide: i < 2 });
    x -= Math.sin((lean * Math.PI) / 180) * (h / 4); y += h / 4;
  }
  for (let k = 0; k < 7; k++) {
    const s = 2.2 + R() * 1.4;
    t.box({ name: 'Blossom', s: [s, s * 0.8, s], p: [x + (R() - 0.5) * 3.6, y + (R() - 0.2) * 1.8, (R() - 0.5) * 3.6], r: [0, R() * 90, 0], c: cols[k % cols.length], studs: 'top' });
  }
  return g;
}
// a stone lantern (toro)
function stoneLantern(c, p, accent) {
  const g = c.at(p);
  g.box({ name: 'LanternFoot', s: [1.4, 0.4, 1.4], p: [0, 0.2, 0], c: '#9a948a', m: 'Slate', studs: 'top', collide: true });
  g.cyl({ name: 'LanternPost', axis: 'y', len: 1.6, d: 0.7, p: [0, 1.2, 0], c: '#b0aa9e', m: 'Slate', collide: true });
  g.box({ name: 'LanternBox', s: [1.2, 1.1, 1.2], p: [0, 2.55, 0], c: '#9a948a', m: 'Slate' });
  const glow = g.box({ name: 'LanternGlow', s: [0.8, 0.7, 1.25], p: [0, 2.55, 0], c: accent || '#ffd27a', m: 'Neon', shadow: false });
  g.wedgeF({ name: 'LanternRoof', s: [1.9, 0.7, 1.9], p: [0, 3.45, 0], face: 'front', c: '#7a746a' });
  g.box({ name: 'LanternTop', s: [0.4, 0.4, 0.4], p: [0, 3.95, 0], c: '#7a746a', studs: 'top' });
  E.pointLight(glow, [1, 0.85, 0.55], 10, 0.6);
  return g;
}
// a tiki torch at the entrance
function torch(c, p, col) {
  const g = c.at(p);
  g.cyl({ name: 'TorchPole', axis: 'y', len: 3.6, d: 0.4, p: [0, 1.8, 0], c: '#6b4a2b', collide: true });
  g.cyl({ name: 'TorchBowl', axis: 'y', len: 0.7, d: 0.95, p: [0, 3.8, 0], c: '#3a2a1e' });
  const f = g.box({ name: 'TorchFlame', s: [0.6, 0.8, 0.6], p: [0, 4.4, 0], r: [0, 45, 0], c: col || '#ff9a2e', m: 'Neon', shadow: false });
  E.particles(f, 'Flame', { rate: 10, life: [0.4, 0.8], speed: [1.5, 2.5], size: [[0, 0.5], [1, 0]], color: [1, 0.6, 0.2], emission: 1, spread: [10, 10], dir: 1 });
  E.pointLight(f, [1, 0.62, 0.3], 9, 0.7);
}
// the four parts every tier has
function range(c, tier, th) {
  const A = TR.ACCENT[tier - 1];
  rangeMat(c, th);
  trainerPad(c, tier, A, th);
  trainerBoard(c, tier, A, th);
  return A;
}

// T1 DART RANGE: a jungle camp - log border, sand floor, a bamboo frame with a painted bullseye behind a wooden raptor
// on a stump, tiki torches at the step-in, palms and ferns round it
function trainer1(root) {
  const c = kitModel(root, 'Trainer1');
  const th = { border: '#8a5a33', borderHi: '#9c6a3d', corner: '#6b4a2b', cap: '#e8c45a', floor: '#ead6a4', floorM: 'Sand', line: '#c9a46a', post: '#6b4a2b', frame: '#8a5a33', padRing: '#7a4f2c' };
  const A = range(c, 1, th);
  // the bamboo frame + the bullseye
  for (const sx of [-1, 1]) {
    for (let k = 0; k < 4; k++) {
      c.cyl({ name: 'FrameCane', axis: 'y', len: 1.7, d: 0.7, p: [sx * 3.7, MAT.FLOOR + 0.85 + k * 1.75, TGT_Z + 1.8], c: k % 2 ? '#7fbf3f' : '#8fd14f' });
      c.cyl({ name: 'FrameNode', axis: 'y', len: 0.16, d: 0.85, p: [sx * 3.7, MAT.FLOOR + 1.72 + k * 1.75, TGT_Z + 1.8], c: '#5f9a2f', shadow: false });
    }
    c.box({ name: 'FrameLash', s: [0.9, 0.5, 0.9], p: [sx * 3.7, 7.1, TGT_Z + 1.8], c: '#c9a46a', m: 'Fabric' });
  }
  c.tube([-4.4, 7.3, TGT_Z + 1.8], [4.4, 7.3, TGT_Z + 1.8], 0.75, { name: 'FrameBeam', c: '#8fd14f' });
  for (const x of [-1.5, 1.5]) c.box({ name: 'TargetRope', s: [0.12, 1.4, 0.12], p: [x, 6.4, TGT_Z + 1.9], c: '#c9a46a', shadow: false });
  c.box({ name: 'TargetBoard', s: [4.2, 4.2, 0.4], p: [0, 3.9, TGT_Z + 2], c: '#c08a52', m: 'WoodPlanks' });
  bullseye(c, [0, 3.9, TGT_Z + 1.75], 3.6, { cols: ['#ffffff', '#e8473a', '#ffffff', '#e8473a'], rim: '#6b4a2b' });
  // the raptor on its stump
  const top = plinth(c, [0, 0, TGT_Z], 3.4, th, { c: '#7a4f2c', top: '#c08a52', h: 0.9 });
  dummy(c, 'Velociraptor', [0, top, TGT_Z], 18, 1.55, 'wood');
  targetPoint(c, [0, 3.4, TGT_Z]);
  // hay bales in the back corners, a dart barrel by the pad
  for (const [x, z, r] of [[-3.9, 6.2, 8], [4, 6.1, -10]]) {
    c.at([x, MAT.FLOOR, z], [0, r, 0]).box({ name: 'HayBale', s: [2.2, 1.4, 1.4], p: [0, 0.7, 0], c: '#e8c45a', studs: 'top', collide: true });
    c.at([x, MAT.FLOOR, z], [0, r, 0]).box({ name: 'HayBand', s: [2.25, 1.45, 0.2], p: [0, 0.7, 0], c: '#a8743f' });
  }
  const br = c.at([3.9, MAT.FLOOR, -14.6]);
  br.cyl({ name: 'DartBarrel', axis: 'y', len: 1.6, d: 1.3, p: [0, 0.8, 0], c: '#8a5a33', m: 'WoodPlanks', collide: true });
  br.cyl({ name: 'BarrelHoop', axis: 'y', len: 0.15, d: 1.36, p: [0, 1.2, 0], c: '#3a2a1e' });
  for (let k = 0; k < 5; k++) br.at([0, 1.6, 0], [0, k * 72, 0]).box({ name: 'Dart', s: [0.16, 1.3, 0.16], p: [0.35, 0.55, 0], r: [0, 0, 12], c: k % 2 ? A : '#f2c230', shadow: false });
  // the step-in: two tiki torches
  for (const sx of [-1, 1]) torch(c, [sx * 2.6, MAT.FLOOR + 1.5, MAT.Z0 + 0.55]);
  // round it: palms behind, ferns and bushes along the sides
  E.palm(c, [-4.6, 0, 11.5], 11, 41);
  E.palm(c, [3.4, 0, 13], 12.5, 77);
  E.bush(c, [0, 0, 11], 0.9, 12);
  // (the +X side is the lodge's: keep inside the lot there)
  for (const [x, z, k, s] of [[-7.2, -12, 1.2, 3], [-7.2, 2, 1.2, 9], [5.6, 10, 0.8, 11], [-6.8, 12, 1, 5]]) E.fern(c, [x, 0, z], k, s);
  return c;
}

// T2 TRAINING YARD: a dojo yard (the reference): dark wood border with pale stone corners, a red TORII framing the
// target, a cherry tree, a stone lantern, a koi pond, bamboo
function trainer2(root) {
  const c = kitModel(root, 'Trainer2');
  const th = { border: '#4a2f1e', borderHi: '#5a3a22', corner: '#b9b3c9', cornerM: 'Slate', cap: '#d6d0e2', capM: 'Slate', floor: '#efe0b4', floorM: 'Fabric', line: '#c9b17e', post: '#5a3a22', frame: '#4a2f1e', padRing: '#3d2718', base: '#3d2718' };
  const A = range(c, 2, th);
  // the torii
  const RED = '#d8332a', RED2 = '#b8261f';
  for (const sx of [-1, 1]) {
    c.box({ name: 'ToriiFoot', s: [1.5, 0.8, 1.5], p: [sx * 3.9, MAT.FLOOR + 0.4, TGT_Z + 1.6], c: '#2b2d31', collide: true });
    c.cyl({ name: 'ToriiPillar', axis: 'y', len: 8.2, d: 1.05, p: [sx * 3.9, MAT.FLOOR + 4.9, TGT_Z + 1.6], c: RED, collide: true });
  }
  c.box({ name: 'ToriiNuki', s: [9.8, 0.7, 0.7], p: [0, 7.1, TGT_Z + 1.6], c: RED2, studs: 'top' });
  c.box({ name: 'ToriiKasagi', s: [11.4, 0.8, 1.3], p: [0, 8.95, TGT_Z + 1.6], c: '#2b2d31', studs: 'top' });
  c.box({ name: 'ToriiShimaki', s: [10.6, 0.6, 1.1], p: [0, 8.35, TGT_Z + 1.6], c: RED, studs: 'top' });
  for (const sx of [-1, 1]) c.wedgeF({ name: 'ToriiTip', s: [1.3, 0.8, 1.3], p: [sx * 6.3, 9.25, TGT_Z + 1.6], face: sx > 0 ? 'right' : 'left', c: '#2b2d31' });
  c.box({ name: 'ToriiPlaque', s: [1.4, 1.6, 0.3], p: [0, 7.8, TGT_Z + 1.25], c: '#2b2d31' });
  // the gong-bullseye hanging from the nuki, and the painted raptor in front of it
  for (const x of [-1.3, 1.3]) c.box({ name: 'GongCord', s: [0.12, 1.2, 0.12], p: [x, 6.2, TGT_Z + 1.7], c: '#f2c230', shadow: false });
  bullseye(c, [0, 4.1, TGT_Z + 1.75], 3.8, { cols: ['#ffffff', RED, '#ffffff', RED], rim: '#2b2d31' });
  const top = plinth(c, [0, 0, TGT_Z - 0.3], 3.4, th, { c: '#b9b3c9', m: 'Slate', top: '#d6d0e2', h: 0.8 });
  dummy(c, 'Velociraptor', [0, top, TGT_Z - 0.3], 14, 1.6, 'paint');
  targetPoint(c, [0, 3.4, TGT_Z - 0.3]);
  // the garden: a koi pond and a stone lantern on the mat, bamboo and a cherry tree round it
  raisedPond(c, [3.3, 0, -2.6], 2.6, 4.4, { koi: [[-0.4, -0.8, '#ff8a3a'], [0.3, 0.9, '#ffffff'], [0.2, -0.1, '#ff5a3a']], lilies: [[0.4, -1.4], [-0.3, 1.5]] });
  stoneLantern(c, [-3.8, MAT.FLOOR, -3.4], '#ffd27a');
  bamboo(c, [-7, 0, 6], 6, 8, 5);
  bamboo(c, [-7.2, 0, -1], 4, 6, 9);
  blossomTree(c, [5, 0, 11], 7.5, 21, ['#ffb7d5', '#ff9ec4', '#ffc9de', '#f7a8c8']);
  blossomTree(c, [-5.2, 0, 13], 6, 33, ['#ffb7d5', '#ffc9de', '#ff9ec4']);
  for (const [x, z] of [[-1.4, 10], [1.8, 12.4], [-0.2, 14]]) E.rock(c, [x, 0, z], 0.8, Math.round(x * 10 + z));
  for (const sx of [-1, 1]) E.flag(c, [sx * 6.6, 0, MAT.Z0 + 1.4], A, { h: 5 });
  return c;
}

// T3 TARGET RAIL: a steel test range - hazard-striped border on diamond plate, a gantry with three hanging targets
// over a metal stegosaurus, floodlight towers, a control console
function trainer3(root) {
  const c = kitModel(root, 'Trainer3');
  const th = { border: '#1d1e21', borderHi: '#f2b632', corner: '#5d6168', cornerM: 'Metal', cap: '#8c9399', capM: 'Metal', floor: '#9aa1a8', floorM: 'DiamondPlate', line: '#f2b632', post: '#4a4f57', postM: 'Metal', frame: '#3a3d42', padRing: '#3a3d42', base: '#3a3d42' };
  const A = range(c, 3, th);
  // the gantry
  for (const sx of [-1, 1]) {
    c.box({ name: 'GantryFoot', s: [1.8, 0.6, 1.8], p: [sx * 4.3, MAT.FLOOR + 0.3, TGT_Z + 1.8], c: '#3a3d42', m: 'Metal', studs: 'top', collide: true });
    c.box({ name: 'GantryLeg', s: [0.9, 9, 0.9], p: [sx * 4.3, MAT.FLOOR + 4.8, TGT_Z + 1.8], c: '#5d6168', m: 'Metal', studs: 'top', collide: true });
    for (let k = 0; k < 4; k++) c.box({ name: 'LegStripe', s: [0.95, 0.5, 0.95], p: [sx * 4.3, MAT.FLOOR + 1.2 + k * 2, TGT_Z + 1.8], c: '#f2b632', m: 'Metal', shadow: false });
  }
  c.box({ name: 'GantryBeam', s: [10, 1, 1.2], p: [0, 9.6, TGT_Z + 1.8], c: A, m: 'Metal', studs: 'top' });
  c.box({ name: 'GantryRail', s: [8.6, 0.35, 0.35], p: [0, 8.9, TGT_Z + 1.8], c: '#2b2d31', m: 'Metal' });
  for (const [x, y] of [[-2.6, 6.2], [0, 5], [2.6, 6.6]]) {
    c.box({ name: 'TargetChain', s: [0.14, 8.9 - y - 1, 0.14], p: [x, (8.9 + y + 1) / 2, TGT_Z + 1.8], c: '#2b2d31', m: 'Metal', shadow: false });
    bullseye(c, [x, y, TGT_Z + 1.8], 1.9, { cols: ['#ffffff', A, '#ffffff', '#e8473a'] });
  }
  const top = plinth(c, [0, 0, TGT_Z - 0.4], 4.2, th, { c: '#3a3d42', m: 'Metal', top: '#f2b632', h: 0.7 });
  dummy(c, 'Stegosaurus', [0, top, TGT_Z - 0.4], 24, 0.5, 'metal');
  targetPoint(c, [0, 3.2, TGT_Z - 0.4]);
  // floodlight towers behind, an armoured backstop between them
  for (const sx of [-1, 1]) {
    const t = c.at([sx * 5, 0, 10.5]);
    for (let k = 0; k < 4; k++) t.box({ name: 'TowerBlock', s: [1.8 - k * 0.1, 3, 1.8 - k * 0.1], p: [0, 1.5 + k * 3, 0], c: k % 2 ? '#3a3d42' : '#5d6168', m: 'Metal', studs: 'top', collide: true });
    const fl = t.at([0, 12.6, -0.4], [-30, sx * 18, 0]).box({ name: 'Floodlight', s: [2.2, 1.4, 1.2], c: '#fff6dc', m: 'Neon' });
    t.box({ name: 'FloodHousing', s: [2.5, 1.7, 1], p: [0, 12.7, 0.2], c: '#2b2d31', m: 'Metal' });
    E.pointLight(fl, [0.85, 1, 0.95], 26, 0.7);
  }
  for (let k = 0; k < 3; k++) c.box({ name: 'Backstop', s: [9.6, 2, 1.2], p: [0, 1 + k * 2, 11], c: k % 2 ? '#5d6168' : '#4a4f57', m: 'DiamondPlate', studs: 'top', collide: true });
  for (let k = 0; k < 5; k++) c.at([-3.6 + k * 1.8, 4.1, 10.35], [0, 0, 45]).box({ name: 'Chevron', s: [1, 1, 0.2], c: k % 2 ? '#1d1e21' : '#f2b632', shadow: false });
  // the console by the step-in
  const con = c.at([4.2, MAT.FLOOR, -15], [0, -20, 0]);
  con.box({ name: 'Console', s: [2.2, 2.2, 1.4], p: [0, 1.1, 0], c: '#3a3d42', m: 'Metal', studs: 'top', collide: true });
  con.box({ name: 'ConsoleScreen', s: [1.6, 0.9, 0.1], p: [0, 1.7, -0.75], c: A, m: 'Neon', shadow: false });
  con.beam([0.5, 2.2, 0], [0.8, 3.4, -0.3], 0.22, 0.22, { name: 'Lever', c: '#d9d9d9', m: 'Metal' });
  con.ball({ name: 'LeverKnob', d: 0.5, p: [0.8, 3.5, -0.3], c: '#e8473a' });
  for (const [x, z] of [[6.8, -2], [-6.9, 4]]) E.crate(c, [x, 0, z], 1, { yaw: x * 9 });
  E.barrel(c, [6.7, 0, 3.4], {});
  return c;
}

// T4 MECHA RANGE: dark armour plate with red neon, an armoured arch with a light bar and speakers, a hydraulic mech
// T. rex on a turntable, red spotlight towers
function trainer4(root) {
  const c = kitModel(root, 'Trainer4');
  const th = { border: '#2b2d31', borderHi: '#3a3d42', borderM: 'Metal', trim: '#ff4a3d', corner: '#e8473a', cornerM: 'Metal', cap: '#3a3d42', capM: 'Metal', floor: '#4a4f57', floorM: 'DiamondPlate', line: '#ff4a3d', post: '#3a3d42', postM: 'Metal', frame: '#2b2d31', padRing: '#1d1e21', base: '#1d1e21' };
  const A = range(c, 4, th);
  // the arch
  for (const sx of [-1, 1]) {
    c.box({ name: 'ArchLeg', s: [1.6, 9.5, 1.6], p: [sx * 4.3, MAT.FLOOR + 4.75, TGT_Z + 1.9], c: '#3a3d42', m: 'Metal', studs: 'top', collide: true });
    c.box({ name: 'ArchLegGlow', s: [0.3, 8, 0.3], p: [sx * 3.45, MAT.FLOOR + 4.6, TGT_Z + 1.2], c: A, m: 'Neon', shadow: false });
    c.box({ name: 'Speaker', s: [1.7, 2.2, 1.3], p: [sx * 3.4, 11.4, TGT_Z + 1.9], c: '#1d1e21', studs: 'top' });
    c.cyl({ name: 'SpeakerCone', axis: 'z', len: 0.2, d: 1.2, p: [sx * 3.4, 11.4, TGT_Z + 1.2], c: '#5d6168', m: 'Metal' });
  }
  c.box({ name: 'ArchTop', s: [10.4, 1.6, 2], p: [0, 10, TGT_Z + 1.9], c: '#e8473a', m: 'Metal', studs: 'top' });
  for (let k = 0; k < 7; k++) c.box({ name: 'ArchLight', s: [0.85, 0.45, 0.3], p: [-3.6 + k * 1.2, 9.1, TGT_Z + 0.85], c: '#ffd23a', m: 'Neon', shadow: false });
  // the mech rex on its turntable
  c.cyl({ name: 'Turntable', axis: 'y', len: 0.8, d: 7.4, p: [0, MAT.FLOOR + 0.4, TGT_Z], c: '#4a4f57', m: 'Metal', collide: true });
  c.cyl({ name: 'TurntableRing', axis: 'y', len: 0.85, d: 7.8, p: [0, MAT.FLOOR + 0.4, TGT_Z], c: A, m: 'Neon', t: 0.3, shadow: false });
  for (const sx of [-1, 1]) {
    c.beam([sx * 2.8, MAT.FLOOR + 0.8, TGT_Z - 2], [sx * 1.1, 6.2, TGT_Z], 0.6, 0.6, { name: 'Piston', c: '#b8bec4', m: 'Metal' });
    c.beam([sx * 2.8, MAT.FLOOR + 0.8, TGT_Z - 2], [sx * 2.3, 2.8, TGT_Z - 1.4], 1, 1, { name: 'PistonSleeve', c: '#f2b632', m: 'Metal' });
  }
  dummy(c, 'TyrannosaurusRex', [0, MAT.FLOOR + 0.8, TGT_Z + 0.3], 20, 0.5, 'metal');
  targetPoint(c, [0, 4.6, TGT_Z]);
  // red spotlight towers behind, a backstop wall
  for (const sx of [-1, 1]) {
    const t = c.at([sx * 5.2, 0, 11]);
    for (let k = 0; k < 5; k++) t.box({ name: 'TowerBlock', s: [2.2 - k * 0.12, 3, 2.2 - k * 0.12], p: [0, 1.5 + k * 3, 0], c: k % 2 ? '#3a3d42' : '#e8473a', m: 'Metal', studs: 'top', collide: true });
    const sp = t.at([0, 15.8, -0.4], [-25, sx * 22, 0]).box({ name: 'Spotlight', s: [2, 1.4, 1.4], c: '#fff1d0', m: 'Neon' });
    E.pointLight(sp, [1, 0.55, 0.5], 26, 0.7);
    t.box({ name: 'TowerBeacon', s: [0.9, 0.9, 0.9], p: [0, 17.2, 0], c: A, m: 'Neon' });
  }
  for (let k = 0; k < 3; k++) c.box({ name: 'Backstop', s: [8, 2.4, 1.2], p: [0, 1.2 + k * 2.4, 11.6], c: k % 2 ? '#e8473a' : '#3a3d42', m: 'Metal', studs: 'top', collide: true });
  // hazard bollards at the step-in
  for (const sx of [-1, 1]) {
    c.cyl({ name: 'Bollard', axis: 'y', len: 2, d: 0.8, p: [sx * 2.6, MAT.FLOOR + 1, MAT.Z0 - 0.9], c: '#f2b632', collide: true });
    c.cyl({ name: 'BollardBand', axis: 'y', len: 0.4, d: 0.85, p: [sx * 2.6, MAT.FLOOR + 1.3, MAT.Z0 - 0.9], c: '#1d1e21' });
    c.cyl({ name: 'BollardLight', axis: 'y', len: 0.3, d: 0.6, p: [sx * 2.6, MAT.FLOOR + 2.15, MAT.Z0 - 0.9], c: A, m: 'Neon', shadow: false });
  }
  return c;
}

// T5 AMBER LAB: copper and amber - a giganotosaurus set in an amber block under a copper dome, resin tanks with glowing
// cores behind, copper coils round the pad
function trainer5(root) {
  const c = kitModel(root, 'Trainer5');
  const th = { border: '#a8602a', borderHi: '#c87533', borderM: 'Metal', trim: '#ffb02e', corner: '#e9dfc4', cap: '#c87533', capM: 'Metal', floor: '#6b4428', floorM: 'Marble', line: '#ffb02e', post: '#8a4a1e', postM: 'Metal', frame: '#c87533', padRing: '#8a4a1e', base: '#5a3a22' };
  const A = range(c, 5, th);
  // the amber block + the giganotosaurus inside it, a glow under it
  const top = plinth(c, [0, 0, TGT_Z + 0.2], 6.4, th, { c: '#8a4a1e', m: 'Metal', top: A, topM: 'Neon', h: 0.8 });
  dummy(c, 'Giganotosaurus', [0, top, TGT_Z + 0.4], 22, 0.42, 'amber');
  E.pointLight(c.box({ name: 'AmberGlow', s: [0.5, 0.5, 0.5], p: [0, 2.2, TGT_Z], t: 1, shadow: false }), [1, 0.62, 0.2], 18, 0.8);
  targetPoint(c, [0, 4.2, TGT_Z]);
  // the copper dome ribs over it
  const R = 4.6;
  for (let k = 0; k < 6; k++) {
    const a = (k / 6) * Math.PI * 2;
    const x = Math.cos(a) * R, z = TGT_Z + 0.2 + Math.sin(a) * R * 0.75;
    c.beam([x, MAT.FLOOR, z], [x * 0.55, 6.5, TGT_Z + 0.2 + (z - TGT_Z - 0.2) * 0.55], 0.5, 0.5, { name: 'DomeRib', c: '#c87533', m: 'Metal', collide: k > 1 && k < 5 });
    c.beam([x * 0.55, 6.5, TGT_Z + 0.2 + (z - TGT_Z - 0.2) * 0.55], [0, 9, TGT_Z + 0.2], 0.45, 0.45, { name: 'DomeRib', c: '#d98a44', m: 'Metal' });
  }
  c.cyl({ name: 'DomeRing', axis: 'y', len: 0.45, d: 5.4, p: [0, 6.5, TGT_Z + 0.2], c: '#c87533', m: 'Metal' });
  c.ball({ name: 'DomeTop', d: 1.6, p: [0, 9.3, TGT_Z + 0.2], c: A, m: 'Neon' });
  // resin tanks behind, piped together
  for (const [x, h] of [[-4.2, 7], [0, 9], [4.2, 7.5]]) {
    const t = c.at([x, 0, 11.5]);
    t.cyl({ name: 'TankBase', axis: 'y', len: 1, d: 3.4, p: [0, 0.5, 0], c: '#8a4a1e', m: 'Metal', collide: true });
    t.cyl({ name: 'TankGlass', axis: 'y', len: h, d: 2.9, p: [0, 1 + h / 2, 0], c: '#ffcf7a', m: 'Glass', t: 0.45, collide: true });
    const core = t.cyl({ name: 'TankCore', axis: 'y', len: h - 1, d: 1.5, p: [0, 1 + h / 2, 0], c: '#ff9a1a', m: 'Neon', t: 0.15 });
    core.tag('AmberCore');
    t.cyl({ name: 'TankCap', axis: 'y', len: 0.8, d: 3.4, p: [0, 1.4 + h, 0], c: '#c87533', m: 'Metal' });
    t.ball({ name: 'TankDome', d: 2.2, p: [0, 1.9 + h, 0], c: '#d98a44', m: 'Metal' });
    if (h === 9) t.box({ name: 'Mosquito', s: [0.3, 0.3, 1.1], p: [0, 1 + h / 2, -0.2], c: '#2b2d31', shadow: false });
  }
  c.beam([-4.2, 9.2, 11.5], [4.2, 9.2, 11.5], 0.5, 0.5, { name: 'AmberPipe', c: '#c87533', m: 'Metal', extend: 0.5 });
  // four copper coils round the pad
  for (const [x, z] of [[-4.3, -1], [4.3, -1], [-4.3, 1], [4.3, 1]]) {
    const cl = c.at([x, MAT.FLOOR, TR.PAD_Z + z * 3]);
    cl.cyl({ name: 'Coil', axis: 'y', len: 3, d: 0.9, p: [0, 1.5, 0], c: '#c87533', m: 'Metal', collide: true });
    for (let k = 0; k < 4; k++) cl.cyl({ name: 'CoilWind', axis: 'y', len: 0.22, d: 1.2, p: [0, 0.7 + k * 0.62, 0], c: A, m: 'Neon', shadow: false });
    cl.ball({ name: 'CoilTop', d: 1.1, p: [0, 3.2, 0], c: '#ffd27a', m: 'Neon' });
  }
  return c;
}

// T6 FOSSIL ENGINE: bone border on dark slate, fossil ribs arching over the mat, a giant T. rex skull at the back with
// glowing eyes and a core in its jaws (the target)
function trainer6(root) {
  const c = kitModel(root, 'Trainer6');
  const BONE = ['#e6dccb', '#d6cbb2', '#f2ece0'];
  const th = { border: '#d6cbb2', borderHi: '#e6dccb', trim: '#b06cff', corner: '#f2ece0', cap: '#b06cff', capM: 'Neon', floor: '#3d3550', floorM: 'Slate', line: '#b06cff', post: '#d6cbb2', frame: '#e6dccb', padRing: '#2a2438', base: '#2a2438' };
  const A = range(c, 6, th);
  // ribs over the mat
  // (behind the mat, round the skull: framing it, never in front of it)
  for (const [i, z] of [8.6, 13.2].entries()) {
    const h = 13 + i * 0.8;
    for (const sx of [-1, 1]) {
      c.beam([sx * 6.4, 0, z], [sx * 6.6, h * 0.5, z], 1.1, 1.1, { name: 'Rib', c: BONE[i % 3], collide: true, extend: 0.3 });
      c.beam([sx * 6.6, h * 0.5, z], [sx * 4.6, h * 0.88, z + 0.4], 1, 1, { name: 'Rib', c: BONE[(i + 1) % 3], extend: 0.3 });
      c.beam([sx * 4.6, h * 0.88, z + 0.4], [sx * 0.8, h, z + 0.6], 0.9, 0.9, { name: 'Rib', c: BONE[(i + 2) % 3], extend: 0.3 });
    }
    c.box({ name: 'Vertebra', s: [1.8, 1.4, 1.8], p: [0, h + 0.3, z + 0.6], c: BONE[i % 3], studs: 'top' });
    c.box({ name: 'RibGlow', s: [0.35, 0.35, 0.35], p: [0, h - 0.5, z + 0.6], c: A, m: 'Neon', shadow: false });
  }
  c.beam([0, 13.4, 7], [0, 14.4, 16], 0.8, 0.8, { name: 'Spine', c: BONE[1] });
  // the skull, facing the pad
  c.box({ name: 'SkullBase', s: [11, 1.4, 7], p: [0, 0.7, 11.5], c: '#4a4f57', m: 'Metal', studs: 'top', collide: true });
  // (turned three-quarters: face-on, a skull reads as a box)
  const s = c.at([0.8, 1.4, 11.2], [0, -32, 0]);
  s.box({ name: 'Cranium', s: [8, 6, 6], p: [0, 6.4, 1.6], c: BONE[0], studs: 'top', collide: true });
  s.box({ name: 'Snout', s: [6, 3.8, 5], p: [0, 6, -3.2], c: BONE[1], studs: 'top', collide: true });
  s.wedgeF({ name: 'SnoutTip', s: [6, 2, 2.4], p: [0, 7, -6.8], face: 'front', c: BONE[2] });
  for (const sx of [-1, 1]) {
    s.box({ name: 'EyeSocket', s: [2.2, 2, 0.4], p: [sx * 2.2, 7.8, -1.25], c: '#2b2d31' });
    const eye = s.box({ name: 'SkullEye', s: [1.2, 1, 0.3], p: [sx * 2.2, 7.8, -1.5], c: A, m: 'Neon' });
    eye.tag('FossilEye');
    s.box({ name: 'Cheek', s: [1.4, 3.4, 4.4], p: [sx * 4, 5, 0], c: BONE[2], studs: 'sides' });
  }
  for (let k = 0; k < 5; k++) for (const sx of [-1, 1]) s.wedgeF({ name: 'Tooth', s: [0.5, 1.1, 0.5], p: [sx * 2.6, 3.6, -5.4 + k * 0.85], face: 'front', flip: true, c: '#ffffff' });
  s.at([0, 2, 0], [16, 0, 0]).box({ name: 'Jaw', s: [6.4, 1.4, 7.6], p: [0, 0, -2.6], c: BONE[1], studs: 'top', collide: true });
  const core = s.ball({ name: 'EngineCore', d: 2.8, p: [0, 3.4, -3.4], c: A, m: 'Neon', t: 0.1 });
  core.tag('EngineCore');
  E.pointLight(core, [0.7, 0.45, 1], 22, 0.9);
  targetPoint(c, [0, 4.8, 8]);
  // purple crystals at the corners
  for (const [x, z] of [[-6.8, 8], [6.8, 9], [-6.9, -16], [6.9, -15]]) {
    const g = c.at([x, 0, z], [0, x * 13, 0]);
    for (const [dx, h, r] of [[0, 2.6, 0], [0.6, 1.6, 18], [-0.5, 1.3, -20]]) g.at([dx, 0, 0], [0, 0, r]).box({ name: 'Crystal', s: [0.7, h, 0.7], p: [0, h / 2, 0], r: [0, 45, 0], c: A, m: 'Glass', t: 0.2 });
  }
  return c;
}

// T7 TITAN RIG: black glass and neon - neon arches over the mat, a holographic T. rex on a projector, twin pylons with
// floating rings and a sign bridge behind, the biggest thing on any island
function trainer7(root) {
  const c = kitModel(root, 'Trainer7');
  const A2 = TR.ACCENT2[6];
  const th = { border: '#14161c', borderHi: '#22252e', borderM: 'Glass', trim: TR.ACCENT[6], corner: '#2b2d31', cornerM: 'Metal', cap: '#ffcf3a', capM: 'Metal', floor: '#1b1e27', floorM: 'Glass', line: TR.ACCENT[6], post: '#2b2d31', postM: 'Metal', frame: '#3a3f55', padRing: '#0e1016', base: '#0e1016' };
  const A = range(c, 7, th);
  for (const [i, z] of [-2.5, 6.4].entries()) {
    const h = 10.5 + i * 1.2, col = i % 2 ? A2 : A;
    for (const sx of [-1, 1]) {
      c.box({ name: 'ArchLeg', s: [1, h, 1], p: [sx * 6.4, h / 2, z], c: '#5b6380', m: 'Metal', studs: 'top', collide: true });
      c.box({ name: 'ArchLegGlow', s: [0.25, h - 2, 0.25], p: [sx * 5.85, h / 2, z - 0.4], c: col, m: 'Neon', shadow: false });
    }
    c.box({ name: 'ArchTop', s: [13.8, 0.9, 0.9], p: [0, h, z], c: '#5b6380', m: 'Metal', studs: 'top' });
    for (const sx of [-1, 1]) c.box({ name: 'ArchCap', s: [1.5, 0.5, 1.5], p: [sx * 6.4, h + 0.7, z], c: '#ffcf3a', m: 'Metal' });
    c.box({ name: 'ArchGlow', s: [12.2, 0.3, 0.3], p: [0, h - 0.7, z - 0.4], c: col, m: 'Neon', shadow: false });
  }
  // the projector + holo rex
  c.cyl({ name: 'Projector', axis: 'y', len: 1, d: 7.4, p: [0, MAT.FLOOR + 0.5, TGT_Z], c: '#2b2d31', m: 'Metal', collide: true });
  c.cyl({ name: 'ProjectorRing', axis: 'y', len: 1.05, d: 7.8, p: [0, MAT.FLOOR + 0.5, TGT_Z], c: A, m: 'Neon', t: 0.2, shadow: false });
  c.cyl({ name: 'ProjectorLens', axis: 'y', len: 1.1, d: 3, p: [0, MAT.FLOOR + 0.5, TGT_Z], c: '#ffffff', m: 'Neon', shadow: false });
  dummy(c, 'TyrannosaurusRex', [0, MAT.FLOOR + 1, TGT_Z + 0.4], 20, 0.6, 'holo');
  targetPoint(c, [0, 5.2, TGT_Z]);
  // twin pylons with floating rings, a sign bridge between them
  for (const sx of [-1, 1]) {
    const py = c.at([sx * 5.2, 0, 12.5]);
    for (let k = 0; k < 6; k++) py.box({ name: 'PylonBlock', s: [2.6 - k * 0.2, 3.4, 2.6 - k * 0.2], p: [0, 1.7 + k * 3.4, 0], r: [0, k * 10, 0], c: k % 2 ? '#2b2d31' : '#3a3d42', m: 'Metal', studs: 'top', collide: true });
    py.cyl({ name: 'PylonCap', axis: 'y', len: 1, d: 2.8, p: [0, 21, 0], c: '#ffcf3a', m: 'Metal' });
    const orb = py.ball({ name: 'PylonOrb', d: 2.2, p: [0, 22.6, 0], c: sx > 0 ? A : A2, m: 'Neon' });
    E.pointLight(orb, sx > 0 ? [0.3, 0.9, 1] : [1, 0.35, 0.85], 28, 0.7);
    for (const [y, d] of [[7.5, 5.6], [14.5, 4.6]]) {
      const ring = py.group('FloatRing').at([0, y, 0]);
      for (let k = 0; k < 12; k++) {
        const a = (k / 12) * Math.PI * 2;
        ring.at([Math.cos(a) * d / 2, 0, Math.sin(a) * d / 2], [0, -a * 180 / Math.PI, 0]).box({ name: 'RingSeg', s: [0.45, 0.45, d * 0.27], c: k % 2 ? A : '#ffffff', m: 'Neon', shadow: false });
      }
    }
  }
  c.beam([-5.2, 18, 12.5], [5.2, 18, 12.5], 1.1, 1.1, { name: 'PylonBridge', c: '#ffcf3a', m: 'Metal' });
  const sgn = c.box({ name: 'TitanSign', s: [7.6, 2.2, 0.5], p: [0, 19.8, 12.3], c: '#14161c' });
  label(sgn, 'Front', 'TITAN RIG', { pps: 30, color: '#ffffff', color2: A });
  c.box({ name: 'TitanSignGlow', s: [8.2, 2.8, 0.3], p: [0, 19.8, 12.6], c: A2, m: 'Neon', shadow: false });
  return c;
}

// ============================================================== SHOWCASE PEDESTAL
// (2026-10-14) every island's SHOWCASE by the bridge landing: a faceted stone plinth with amber bands, a turning
// platform, four spotlight posts aimed at the star and amber crystal clusters. The owner picks the dino (server
// Showcase.luau); every client draws it on the platform (ShowcaseView.luau). Origin = plinth centre on the grass,
// the front (the plaque) faces -Z. Kit-local footprint: radius 9.5 (islandLayout PLAN.showcase).
// Named parts the game uses: ShowcaseTurntable (a Model ShowcaseView spins; PrimaryPart TurntableCore),
// ShowcaseSpot (where the dino's feet go, on the platform's top), ShowcaseGlow (neon ShowcaseView tints to the
// dino's rarity), SpotLens (the lamp lenses, tinted too), ShowcasePlaque (the front sign).
const SCASE = { R: 9.5, TOP: 3.5, AMBER: '#ffb02e', AMBER2: '#ffd23a', WARM: '#fff1c4' };
function showcase(root) {
  const c = kitModel(root, 'Showcase');
  const T1 = 7.5, T2 = 6.2; // tier radii
  // paved apron: a ring of chunky pavers round the plinth
  c.cyl({ name: 'ShowcaseApron', axis: 'y', len: 0.2, d: SCASE.R * 2, p: [0, 0.1, 0], c: '#cfc3a4', m: 'Slate', collide: true, shadow: false });
  for (let i = 0; i < 22; i++) {
    c.at([0, 0, 0], [0, (i / 22) * 360, 0]).box({ name: 'Paver', s: [2.3, 0.26, 1.5], p: [0, 0.14, -(SCASE.R - 0.85)], c: i % 2 ? '#d9cdb0' : '#bfb39a', m: 'Slate', shadow: false });
  }
  // tier 1: a stone core faced with 16 studded blocks (the faceted toy look), an amber band on top
  c.cyl({ name: 'PlinthCore', axis: 'y', len: 1.1, d: T1 * 2 - 0.6, p: [0, 0.75, 0], c: '#6c6962', m: 'Slate', collide: true });
  for (let i = 0; i < 16; i++) {
    c.at([0, 0, 0], [0, (i / 16) * 360, 0]).box({ name: 'PlinthBlock', s: [3.05, 1.1, 1.3], p: [0, 0.75, -(T1 - 0.65)], c: i % 2 ? '#7a746a' : '#8a8478', studs: 'top', collide: true });
  }
  c.cyl({ name: 'PlinthBand', axis: 'y', len: 0.26, d: T1 * 2 + 0.3, p: [0, 1.43, 0], c: SCASE.AMBER, m: 'Metal' });
  // tier 2: darker, 12 blocks, a glowing band (tinted to the rarity)
  c.cyl({ name: 'PlinthCore2', axis: 'y', len: 1.1, d: T2 * 2 - 0.6, p: [0, 2.1, 0], c: '#4a4d52', m: 'Slate', collide: true });
  for (let i = 0; i < 12; i++) {
    c.at([0, 0, 0], [0, (i / 12) * 360 + 15, 0]).box({ name: 'PlinthBlock2', s: [3.2, 1.1, 1.2], p: [0, 2.1, -(T2 - 0.6)], c: i % 2 ? '#5d5a55' : '#6c6962', studs: 'top', collide: true });
  }
  const glow = c.cyl({ name: 'ShowcaseGlow', axis: 'y', len: 0.24, d: T2 * 2 + 0.3, p: [0, 2.77, 0], c: SCASE.AMBER2, m: 'Neon', shadow: false });
  E.pointLight(glow, [1, 0.8, 0.45], 16, 0.8);
  // the turning platform (ShowcaseView spins this model; the dino rides on its top)
  {
    const tt = c.group('ShowcaseTurntable');
    const core = tt.cyl({ name: 'TurntableCore', axis: 'y', len: 0.6, d: 10.6, p: [0, 3.2, 0], c: '#2b2d31', m: 'Metal', collide: true });
    tt.parent.set('PrimaryPart', 'Ref', core);
    tt.cyl({ name: 'TurntableTop', axis: 'y', len: 0.64, d: 9.2, p: [0, 3.2, 0], c: '#3a3d42', m: 'Slate', collide: true });
    tt.cyl({ name: 'ShowcaseGlow', axis: 'y', len: 0.18, d: 10.9, p: [0, 3.0, 0], c: SCASE.AMBER, m: 'Neon', shadow: false });
    // a gold compass star on the top: the turning reads at a glance
    for (const a of [0, 45, 90, 135]) {
      tt.at([0, 3.53, 0], [0, a, 0]).box({ name: 'TurntableStripe', s: [a % 90 ? 6.2 : 8.4, 0.06, a % 90 ? 0.32 : 0.55], c: a % 90 ? '#c87533' : SCASE.AMBER, m: 'Metal', shadow: false });
    }
    tt.cyl({ name: 'TurntableHub', axis: 'y', len: 0.1, d: 1.8, p: [0, 3.55, 0], c: SCASE.AMBER2, m: 'Metal', shadow: false });
    // rim studs, alternating glow and gold
    for (let i = 0; i < 18; i++) {
      const a = (i / 18) * Math.PI * 2;
      tt.cyl({ name: i % 2 ? 'RimStud' : 'ShowcaseGlow', axis: 'y', len: 0.26, d: 0.62, p: [Math.cos(a) * 4.85, 3.6, Math.sin(a) * 4.85], c: i % 2 ? '#ffcf3a' : SCASE.WARM, m: i % 2 ? 'Metal' : 'Neon', shadow: false });
    }
    const spot = tt.box({ name: 'ShowcaseSpot', s: [1, 1, 1], p: [0, SCASE.TOP, 0], t: 1, shadow: false });
    spot.set('CanQuery', 'bool', false);
  }
  // the plaque at the front: a stone lectern, its slanted board says SHOWCASE (ShowcaseView floats the dino's name
  // card over the platform)
  {
    const pq = c.at([0, 0, -8.35]);
    pq.box({ name: 'PlaqueBase', s: [6.6, 1.5, 1.3], p: [0, 0.95, 0], c: '#7a746a', m: 'Slate', studs: 'top', collide: true });
    const board = pq.at([0, 2.35, 0.1], [-24, 0, 0]);
    const b = board.box({ name: 'ShowcasePlaque', s: [6.2, 1.9, 0.35], c: '#24262b', collide: true });
    board.box({ name: 'PlaqueFrame', s: [6.7, 2.4, 0.25], p: [0, 0, 0.2], c: SCASE.AMBER, m: 'Metal' });
    for (const x of [-2.6, 2.6]) board.box({ name: 'PlaqueRivet', s: [0.3, 0.3, 0.1], p: [x, 0.72, -0.2], c: SCASE.AMBER2, m: 'Metal', shadow: false });
    label(b, 'Front', 'SHOWCASE', { pps: 40, color: '#fff4d6', color2: SCASE.AMBER });
  }
  // four spotlight posts aimed at the star (warm white; ShowcaseView tints the lenses): two short ones at the front
  // corners (so nothing stands between a visitor and the dino) and two tall ones behind, stone like the name gate
  for (const [deg, tall] of [[52, false], [-52, false], [140, true], [-140, true]]) {
    const a = (deg * Math.PI) / 180;
    const x = Math.sin(a) * 8.6, z = -Math.cos(a) * 8.6;
    const n = tall ? 4 : 2, top = 0.7 + n * 1.9;
    const post = c.at([x, 0, z], [0, -deg, 0]);
    post.box({ name: 'PostFoot', s: [2.3, 0.7, 2.3], p: [0, 0.35, 0], c: '#6c6962', m: 'Slate', studs: 'top', collide: true });
    for (let k = 0; k < n; k++) post.box({ name: 'PostBlock', s: [1.6 - k * 0.07, 1.9, 1.6 - k * 0.07], p: [0, 0.7 + 0.95 + k * 1.9, 0], r: [0, k * 11, 0], c: k % 2 ? '#7a746a' : '#8a8478', studs: 'top', collide: true });
    post.box({ name: 'PostCap', s: [1.95, 0.5, 1.95], p: [0, top + 0.25, 0], c: SCASE.AMBER, m: 'Metal', studs: 'top' });
    post.box({ name: 'PostGlow', s: [0.28, top - 1.6, 0.28], p: [0, 0.7 + (top - 1.6) / 2 + 0.3, -0.82], c: SCASE.AMBER2, m: 'Neon', shadow: false });
    // the lamp: yaw toward the platform, then pitch at the star (the front ones shine up at it)
    const lp = [x, top + 1.25, z];
    const aim = tall ? [0, 4.6, 0] : [0, 6.4, 0];
    const dx = aim[0] - lp[0], dy = aim[1] - lp[1], dz = aim[2] - lp[2];
    const h = Math.hypot(dx, dz);
    const yaw = (Math.atan2(-dx, -dz) * 180) / Math.PI, pitch = (Math.atan2(dy, h) * 180) / Math.PI;
    c.box({ name: 'LampYoke', s: [0.5, 0.9, 0.5], p: [x, top + 0.75, z], c: '#2b2d31', m: 'Metal' });
    const lamp = c.at(lp, [0, yaw, 0]).at([0, 0, 0], [pitch, 0, 0]);
    lamp.box({ name: 'LampHousing', s: [1.5, 1.5, 2.1], c: '#2b2d31', m: 'Metal' });
    lamp.box({ name: 'LampFin', s: [1.7, 0.2, 1.2], p: [0, 0.6, 0.6], c: '#4a4d52', m: 'Metal' });
    lamp.cyl({ name: 'LampRim', axis: 'z', len: 0.3, d: 1.6, p: [0, 0, -1.1], c: SCASE.AMBER, m: 'Metal' });
    const lens = lamp.cyl({ name: 'SpotLens', axis: 'z', len: 0.32, d: 1.25, p: [0, 0, -1.14], c: SCASE.WARM, m: 'Neon', shadow: false });
    const sl = new Inst('SpotLight', 'Spot');
    sl.set('Color', 'Color3', [1, 0.93, 0.78]).set('Range', 'float', 20).set('Brightness', 'float', tall ? 2.2 : 1.6).set('Angle', 'float', 44).set('Face', 'token', 5).set('Shadows', 'bool', false);
    lens.add(sl);
  }
  // amber crystal clusters on the apron between the posts (glass shells round a glowing core)
  const R = rng(4242);
  for (const deg of [90, 180, 270]) {
    const a = (deg * Math.PI) / 180;
    const cc = c.at([Math.sin(a) * 8.55, 0.2, -Math.cos(a) * 8.55], [0, R() * 360, 0]);
    const n = deg === 180 ? 5 : 4;
    for (let k = 0; k < n; k++) {
      const hgt = 1.3 + R() * 1.6 + (k === 0 ? 0.8 : 0);
      const tilt = [(R() - 0.5) * 44, R() * 360, (R() - 0.5) * 44];
      const off = k === 0 ? [0, 0, 0] : [(R() - 0.5) * 1.5, 0, (R() - 0.5) * 1.5];
      const crystal = cc.at(off, [0, tilt[1], 0]).at([0, 0, 0], [tilt[0], 0, tilt[2]]);
      crystal.box({ name: 'AmberCrystal', s: [0.75, hgt, 0.75], p: [0, hgt / 2, 0], r: [0, 45, 0], c: '#f29a2e', m: 'Glass', t: 0.2 });
      crystal.box({ name: 'AmberCore', s: [0.38, hgt * 0.8, 0.38], p: [0, hgt * 0.42, 0], r: [0, 45, 0], c: '#ffcf6a', m: 'Neon', shadow: false });
      crystal.box({ name: 'AmberTip', s: [0.5, 0.5, 0.5], p: [0, hgt, 0], r: [45, 45, 0], c: '#ffc25a', m: 'Glass', t: 0.15 });
    }
    cc.box({ name: 'CrystalRock', s: [1.6, 0.6, 1.4], p: [0, 0.3, 0], r: [0, 20, 0], c: '#6c6962', m: 'Slate' });
  }
  return c;
}

function buildIslandKit() {
  const root = new Inst('Folder', 'IslandKit');
  showcase(root);
  hatcheryT2(root);
  hatcheryT3(root);
  garageT2(root);
  garageT3(root);
  for (const species of Object.keys(STYLES)) for (const s of P.star) if (s.kind === 'pen') landPen(root, species, s.id);
  seaPen(root);
  for (const fn of [trainer1, trainer2, trainer3, trainer4, trainer5, trainer6, trainer7]) fn(root);
  return root;
}

module.exports = { buildIslandKit, PEN_NAMES };
