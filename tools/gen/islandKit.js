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
// the glowing pad (TrainerPad) + its rim; size and trim grow with the tier
function trainerPad(c, tier, accent) {
  const z = TR.PAD_Z;
  const R = 3.2 + tier * 0.12; // (Config.Trainer.PadRadius 4.6 covers the biggest)
  const rimC = ['#87592f', '#7a746a', '#5d6168', '#3a3d42', '#c87533', '#e6dccb', '#2b2d31'][tier - 1];
  c.cyl({ name: 'PadBase', axis: 'y', len: 0.5, d: R * 2 + 2, p: [0, 0.25, z], c: rimC, m: tier === 1 ? 'WoodPlanks' : tier === 2 ? 'Slate' : 'Metal', collide: true });
  const pad = c.cyl({ name: 'TrainerPad', axis: 'y', len: 0.3, d: R * 2, p: [0, 0.6, z], c: accent, m: 'Neon', t: 0.05, collide: true });
  c.cyl({ name: 'PadInner', axis: 'y', len: 0.32, d: R * 1.1, p: [0, 0.62, z], c: shade(accent, 1.25), m: 'Neon', shadow: false });
  // chevrons pointing down the range
  for (const dz of [-0.6, 0.6]) c.at([0, 0.8, z + R - 1.1 + dz * 0.6], [0, 45, 0]).box({ name: 'PadArrow', s: [0.5, 0.06, 1.6], c: '#ffffff', shadow: false });
  // studs round the rim (the toy look)
  const n = 10 + tier * 2;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    c.cyl({ name: 'PadStud', axis: 'y', len: 0.24, d: 0.62, p: [Math.cos(a) * (R + 0.5), 0.58, z + Math.sin(a) * (R + 0.5)], c: i % 2 ? shade(rimC, 1.3) : accent, m: i % 2 ? 'SmoothPlastic' : 'Neon', shadow: false });
  }
  const fx = c.box({ name: 'PadFx', s: [1, 1, 1], p: [0, 1, z], t: 1, shadow: false });
  fx.set('CanQuery', 'bool', false);
  E.pointLight(pad, [1, 1, 1].map((v, i) => parseInt(accent.slice(1 + i * 2, 3 + i * 2), 16) / 255), 10 + tier * 1.5, 0.5);
  return pad;
}
// the upgrade board (TrainerBoard) on two posts + the 4 level pips along its top; faces -Z
function trainerBoard(c, tier, accent, o = {}) {
  const [bx, bz] = TR.BOARD;
  const g = c.at([bx, 0, bz], [0, o.yaw || -38, 0]);
  const postC = o.post || ['#87592f', '#7a746a', '#5d6168', '#3a3d42', '#8a4a1e', '#d6cbb2', '#2b2d31'][tier - 1];
  for (const x of [-1.9, 1.9]) g.box({ name: 'BoardPost', s: [0.6, 6.4, 0.6], p: [x, 3.2, 0.25], c: postC, studs: 'top', collide: true });
  const board = g.box({ name: 'TrainerBoard', s: [4.6, 3, 0.4], p: [0, 4.7, 0], c: '#1f2329', collide: true });
  g.box({ name: 'BoardFrame', s: [5.2, 3.6, 0.3], p: [0, 4.7, 0.2], c: accent, studs: 'sides' });
  for (let k = 1; k <= 4; k++) g.box({ name: 'LevelPip' + k, s: [0.7, 0.5, 0.5], p: [-1.65 + (k - 1) * 1.1, 6.75, 0], c: accent, m: 'Neon', shadow: false });
  g.box({ name: 'PipBar', s: [5.2, 0.4, 0.7], p: [0, 6.35, 0.05], c: postC, studs: 'top' });
  void board;
  return g;
}
// lane floor from the pad to the back
function lane(c, tier, o) {
  const z0 = -9, z1 = 17.5;
  c.box({ name: 'LaneFloor', s: [o.w || 11, 0.16, z1 - z0], p: [0, 0.08, (z0 + z1) / 2], c: o.floor, m: o.floorM || 'SmoothPlastic', collide: true, shadow: false });
  // lane stripes
  for (const x of [-(o.w || 11) / 2 + 0.4, (o.w || 11) / 2 - 0.4]) c.box({ name: 'LaneEdge', s: [0.5, 0.18, z1 - z0], p: [x, 0.1, (z0 + z1) / 2], c: o.edge, m: o.edgeM || 'SmoothPlastic', shadow: false });
  for (let k = 0; k < 5; k++) c.box({ name: 'LaneMark', s: [3, 0.18, 0.4], p: [0, 0.1, -4 + k * 5], c: o.mark || '#ffffff', shadow: false, t: 0.2 });
}
function targetPoint(c, p) {
  const t = c.box({ name: 'TargetPoint', s: [1, 1, 1], p, t: 1, shadow: false });
  t.set('CanQuery', 'bool', false);
}
function sign(c, p, w, h, text, accent, o = {}) {
  const b = c.box({ name: 'TrainerSign', s: [w, h, 0.4], p, c: o.bg || '#2a2c31', r: o.r });
  c.box({ name: 'TrainerSignFrame', s: [w + 0.6, h + 0.6, 0.3], p: [p[0], p[1], p[2] + 0.2], c: o.frame || accent, studs: 'sides', r: o.r });
  label(b, 'Front', text, { pps: o.pps || 30, color: '#ffffff', color2: accent });
  return b;
}

// T1 DART RANGE: a backyard wooden range, one wooden raptor dummy, hay bales, a dart rack
function trainer1(root) {
  const c = kitModel(root, 'Trainer1');
  const A = TR.ACCENT[0];
  trainerPad(c, 1, A);
  trainerBoard(c, 1, A);
  lane(c, 1, { floor: '#9c7046', floorM: 'Mud', edge: '#c08a52', mark: '#e9dfc4' });
  // low log rails both sides
  for (const sx of [-1, 1]) {
    for (let k = 0; k < 6; k++) c.box({ name: 'RailPost', s: [0.7, 2.2, 0.7], p: [sx * 6.2, 1.1, -8 + k * 5], c: PAL.woodLo, studs: 'top', collide: true });
    c.beam([sx * 6.2, 1.6, -8], [sx * 6.2, 1.6, 17], 0.5, 0.5, { name: 'RailLog', c: PAL.wood, collide: true });
  }
  // hay bales
  for (const [x, z, r] of [[-4.6, 2, 8], [4.4, 5, -6], [-4.2, 8.5, 20]]) {
    c.at([x, 0, z], [0, r, 0]).box({ name: 'HayBale', s: [2.4, 1.6, 1.6], p: [0, 0.8, 0], c: '#e8c45a', studs: 'top', collide: true });
    c.at([x, 0, z], [0, r, 0]).box({ name: 'HayBand', s: [2.45, 1.65, 0.2], p: [0, 0.8, 0], c: '#a8743f' });
  }
  // the backstop: a plank wall with a painted bullseye, and the raptor dummy in front of it
  for (let k = 0; k < 6; k++) c.box({ name: 'Backstop', s: [12, 0.9, 1], p: [0, 0.45 + k * 0.92, 17], c: k % 2 ? PAL.wood : PAL.woodHi, m: 'WoodPlanks', collide: true });
  for (const x of [-6.3, 6.3]) c.box({ name: 'BackstopPost', s: [1, 6.6, 1.2], p: [x, 3.3, 17], c: PAL.woodLo, studs: 'top', collide: true });
  bullseye(c, [0, 3, 16.4], 4);
  c.box({ name: 'DummyStand', s: [4, 0.5, 6], p: [0, 0.25, 12], c: PAL.woodLo, m: 'WoodPlanks', collide: true });
  dummy(c, 'Velociraptor', [0, 0.5, 12], 30, 1.7, 'wood');
  bullseye(c, [-1.2, 4.3, 9.6], 1.8, { cols: ['#ffffff', '#e8473a', '#ffffff'] });
  targetPoint(c, [0, 3.2, 12]);
  // a dart rack by the pad + a lantern
  const rk = c.at([-5.2, 0, -14.5], [0, 20, 0]);
  rk.box({ name: 'DartRack', s: [2.2, 2.4, 0.8], p: [0, 1.2, 0], c: PAL.wood, m: 'WoodPlanks', collide: true });
  for (let k = 0; k < 4; k++) rk.box({ name: 'Dart', s: [0.18, 1.6, 0.18], p: [-0.7 + k * 0.45, 2.9, 0], c: '#f2c230', shadow: false });
  E.lampPost(c, [-6.4, 0, 15], { yaw: 180, h: 6 });
  sign(c, [0, 7.8, 17.2], 7, 1.6, 'DART RANGE', A, { pps: 34 });
  return c;
}

// T2 TRAINING YARD: stone lane, an arch over the pad with a banner, two dummies, sandbag backstop, a scoreboard
function trainer2(root) {
  const c = kitModel(root, 'Trainer2');
  const A = TR.ACCENT[1];
  trainerPad(c, 2, A);
  trainerBoard(c, 2, A);
  lane(c, 2, { floor: '#b5a98e', floorM: 'Pebble', edge: A, mark: '#fff4d6' });
  for (const sx of [-1, 1]) {
    for (let k = 0; k < 9; k++) c.box({ name: 'LaneWall', s: [1.4, 1.6 + (k % 2) * 0.3, 2.9], p: [sx * 6.6, 0.8, -8 + k * 3], c: k % 2 ? '#8a8478' : '#7a746a', m: 'Slate', studs: 'top', collide: true });
  }
  // the arch over the pad
  for (const sx of [-1, 1]) {
    for (let k = 0; k < 4; k++) c.box({ name: 'ArchPillar', s: [1.8 - k * 0.08, 2.4, 1.8 - k * 0.08], p: [sx * 6.2, 1.2 + k * 2.4, TR.PAD_Z], r: [0, k * 8, 0], c: k % 2 ? '#8a8478' : '#9a948a', m: 'Slate', studs: 'top', collide: true });
    c.box({ name: 'ArchCap', s: [2.4, 0.7, 2.4], p: [sx * 6.2, 10, TR.PAD_Z], c: A, studs: 'top' });
    E.flag(c, [sx * 6.2, 10.3, TR.PAD_Z], A, { h: 3.5 });
  }
  c.box({ name: 'ArchBeam', s: [14.2, 1.3, 1.6], p: [0, 9.6, TR.PAD_Z], c: PAL.woodLo, studs: 'top' });
  const banner = c.box({ name: 'ArchBanner', s: [8, 2, 0.2], p: [0, 7.9, TR.PAD_Z - 0.3], c: '#2a2c31' });
  label(banner, 'Front', 'TRAINING YARD', { pps: 30, color: '#ffffff', color2: A });
  label(banner, 'Back', 'GO!', { pps: 30, color: '#ffffff', color2: A });
  // two dummies: a raptor and a little triceratops
  c.box({ name: 'DummyStand', s: [3, 0.5, 3], p: [-2.8, 0.25, 11], c: '#7a746a', m: 'Slate', collide: true });
  dummy(c, 'Velociraptor', [-2.8, 0.5, 11], 25, 1.6, 'paint');
  c.box({ name: 'DummyStand', s: [4, 0.5, 5], p: [3, 0.25, 13.5], c: '#7a746a', m: 'Slate', collide: true });
  dummy(c, 'Triceratops', [3, 0.5, 13.5], -28, 0.62, 'wood');
  bullseye(c, [-3.8, 3.6, 9.6], 1.6);
  bullseye(c, [2.2, 2.8, 10.9], 1.8);
  targetPoint(c, [0, 3, 12]);
  // sandbags + crates at the back, a scoreboard over them
  for (let row = 0; row < 3; row++) for (let k = 0; k < 6 - row; k++) c.box({ name: 'Sandbag', s: [2, 0.9, 1.2], p: [-5 + row + k * 2.05, 0.45 + row * 0.9, 17.4], r: [0, (k % 2) * 6 - 3, 0], c: '#cdb27a', m: 'Fabric', collide: true });
  E.crate(c, [-5, 0, 15.2], 1, { yaw: 12 });
  E.crate(c, [5.4, 0, 15.6], 0.9, { yaw: -18 });
  const sb = c.at([0, 0, 18.6]);
  for (const x of [-4.6, 4.6]) sb.box({ name: 'ScorePost', s: [0.7, 9, 0.7], p: [x, 4.5, 0], c: '#3a3d42', m: 'Metal', collide: true });
  sb.box({ name: 'Scoreboard', s: [10, 3.4, 0.6], p: [0, 7.2, 0], c: '#1f2329' });
  sb.box({ name: 'ScoreFrame', s: [10.6, 4, 0.4], p: [0, 7.2, 0.3], c: A, studs: 'sides' });
  for (let k = 0; k < 8; k++) sb.box({ name: 'ScoreLight', s: [0.6, 0.6, 0.2], p: [-3.9 + k * 1.1, 8.4, -0.35], c: k % 2 ? '#ffd23a' : A, m: 'Neon', shadow: false });
  const st = sb.box({ name: 'ScoreText', s: [8, 1.6, 0.1], p: [0, 6.8, -0.35], c: '#1f2329' });
  label(st, 'Front', 'BULLSEYE!', { pps: 30, color: '#ffffff', color2: TR.ACCENT2[1] });
  E.lampPost(c, [6.6, 0, 3], { yaw: -90, h: 6.5 });
  E.lampPost(c, [-6.6, 0, 9], { yaw: 90, h: 6.5 });
  return c;
}

// T3 TARGET RAIL: a steel gantry, a rail with three swinging targets, a metal stegosaurus dummy, floodlights, a console
function trainer3(root) {
  const c = kitModel(root, 'Trainer3');
  const A = TR.ACCENT[2];
  trainerPad(c, 3, A);
  trainerBoard(c, 3, A);
  lane(c, 3, { floor: '#6c7178', floorM: 'DiamondPlate', edge: '#f2b632', mark: '#f2b632' });
  for (const sx of [-1, 1]) {
    // hazard-striped lane walls
    for (let k = 0; k < 13; k++) c.box({ name: 'HazardWall', s: [0.8, 1.4, 2], p: [sx * 6.6, 0.7, -8 + k * 2], c: k % 2 ? '#1d1e21' : '#f2b632', collide: true });
    // gantry legs (three pairs along the lane)
    for (const z of [-12.5, 2, 16]) {
      c.box({ name: 'GantryLeg', s: [1, 13, 1], p: [sx * 6.8, 6.5, z], c: '#5d6168', m: 'Metal', studs: 'top', collide: true });
      c.box({ name: 'GantryFoot', s: [2, 0.6, 2], p: [sx * 6.8, 0.3, z], c: '#3a3d42', m: 'Metal', collide: true });
    }
    c.beam([sx * 6.8, 12.6, -12.5], [sx * 6.8, 12.6, 16], 1, 1, { name: 'GantryRail', c: A, m: 'Metal', extend: 1 });
  }
  for (const z of [-12.5, 2, 16]) c.box({ name: 'GantryBeam', s: [14.6, 1, 1], p: [0, 13, z], c: '#5d6168', m: 'Metal', studs: 'top' });
  // the target rail across the back with three hanging targets
  c.box({ name: 'TargetRail', s: [12.6, 0.5, 0.5], p: [0, 12.2, 8], c: '#f2b632', m: 'Metal' });
  c.beam([-6.8, 12.6, 8], [6.8, 12.6, 8], 0.5, 0.5, { name: 'TargetRailTop', c: '#3a3d42', m: 'Metal' });
  for (const [x, y] of [[-4, 7.5], [0, 6.2], [4, 8]]) {
    c.box({ name: 'TargetChain', s: [0.15, 12.2 - y - 1.2, 0.15], p: [x, (12.2 + y + 1.2) / 2, 8], c: '#2b2d31', m: 'Metal', shadow: false });
    bullseye(c, [x, y, 8], 2.2, { cols: ['#ffffff', A, '#ffffff', '#e8473a'] });
  }
  c.box({ name: 'DummyStand', s: [5, 0.6, 7], p: [0, 0.3, 13.5], c: '#3a3d42', m: 'Metal', studs: 'top', collide: true });
  dummy(c, 'Stegosaurus', [0, 0.6, 13.5], 32, 0.62, 'metal');
  targetPoint(c, [0, 4, 12]);
  // armoured backstop
  for (let k = 0; k < 4; k++) c.box({ name: 'Backstop', s: [13, 2, 1.2], p: [0, 1 + k * 2, 18], c: k % 2 ? '#5d6168' : '#4a4f57', m: 'DiamondPlate', collide: true });
  for (let k = 0; k < 5; k++) c.at([-4.8 + k * 2.4, 4.2, 17.3], [0, 0, 45]).box({ name: 'Chevron', s: [1.2, 1.2, 0.2], c: k % 2 ? '#1d1e21' : '#f2b632', shadow: false });
  // floodlights on the gantry
  for (const sx of [-1, 1]) {
    const fl = c.at([sx * 5.6, 12.2, -12.5], [-35, sx * -20, 0]).box({ name: 'Floodlight', s: [1.6, 1.1, 1.1], c: '#fff1d0', m: 'Neon' });
    E.pointLight(fl, [0.85, 1, 0.95], 22, 0.6);
  }
  // the console by the pad: a lever and two dials
  const con = c.at([-5.4, 0, -15], [0, 25, 0]);
  con.box({ name: 'Console', s: [2.6, 2.6, 1.8], p: [0, 1.3, 0], c: '#3a3d42', m: 'Metal', studs: 'top', collide: true });
  con.box({ name: 'ConsoleScreen', s: [1.8, 1, 0.1], p: [0, 2, -0.95], c: A, m: 'Neon', shadow: false });
  con.beam([0.6, 2.6, 0], [0.9, 4, -0.3], 0.25, 0.25, { name: 'Lever', c: '#d9d9d9', m: 'Metal' });
  con.ball({ name: 'LeverKnob', d: 0.6, p: [0.9, 4.1, -0.3], c: '#e8473a' });
  sign(c, [0, 14.9, -12.5], 8.6, 1.8, 'TARGET RAIL', A, { pps: 32 });
  return c;
}

// T4 MECHA RANGE: a hydraulic mech T. rex dummy on a turntable, two spotlight towers, an armoured arch
function trainer4(root) {
  const c = kitModel(root, 'Trainer4');
  const A = TR.ACCENT[3];
  trainerPad(c, 4, A);
  trainerBoard(c, 4, A);
  lane(c, 4, { floor: '#2b2d31', floorM: 'DiamondPlate', edge: A, edgeM: 'Neon', mark: '#f2b632' });
  for (const sx of [-1, 1]) {
    for (let k = 0; k < 9; k++) c.box({ name: 'ArmourWall', s: [1.2, 2.2, 2.8], p: [sx * 6.7, 1.1, -8 + k * 3], c: k % 2 ? '#4a4f57' : '#3a3d42', m: 'Metal', studs: 'top', collide: true });
    // spotlight towers at the back corners
    const t = c.at([sx * 6.4, 0, 16.5]);
    for (let k = 0; k < 5; k++) t.box({ name: 'TowerBlock', s: [2.6 - k * 0.15, 3.4, 2.6 - k * 0.15], p: [0, 1.7 + k * 3.4, 0], c: k % 2 ? '#3a3d42' : '#e8473a', m: 'Metal', studs: 'top', collide: true });
    const sp = t.at([0, 18, 0], [-25, sx * 25 + 180, 0]).box({ name: 'Spotlight', s: [2, 1.4, 1.6], c: '#fff1d0', m: 'Neon' });
    E.pointLight(sp, [1, 0.6, 0.5], 24, 0.6);
    t.box({ name: 'TowerBeacon', s: [1, 1, 1], p: [0, 17.6, 0], c: A, m: 'Neon' });
  }
  // armoured arch over the pad with speakers
  for (const sx of [-1, 1]) c.box({ name: 'ArchLeg', s: [1.6, 11, 1.6], p: [sx * 6.6, 5.5, TR.PAD_Z], c: '#3a3d42', m: 'Metal', studs: 'top', collide: true });
  c.box({ name: 'ArchTop', s: [15, 1.8, 2.2], p: [0, 11.4, TR.PAD_Z], c: A, m: 'Metal', studs: 'top' });
  for (let k = 0; k < 7; k++) c.box({ name: 'ArchLight', s: [0.9, 0.5, 0.3], p: [-5.4 + k * 1.8, 10.4, TR.PAD_Z - 1.15], c: '#ffd23a', m: 'Neon', shadow: false });
  for (const sx of [-1, 1]) {
    c.box({ name: 'Speaker', s: [1.8, 2.4, 1.4], p: [sx * 4.8, 13.6, TR.PAD_Z], c: '#1d1e21', studs: 'top' });
    c.cyl({ name: 'SpeakerCone', axis: 'z', len: 0.2, d: 1.3, p: [sx * 4.8, 13.6, TR.PAD_Z - 0.75], c: '#5d6168', m: 'Metal' });
  }
  sign(c, [0, 12.9, TR.PAD_Z - 1.3], 7, 1.4, 'MECHA RANGE', A, { pps: 30 });
  // the mech rex: a turntable, pistons, the dummy
  c.cyl({ name: 'Turntable', axis: 'y', len: 0.8, d: 9, p: [0, 0.4, 11.5], c: '#4a4f57', m: 'Metal', collide: true });
  c.cyl({ name: 'TurntableRing', axis: 'y', len: 0.85, d: 9.4, p: [0, 0.4, 11.5], c: A, m: 'Neon', t: 0.3, shadow: false });
  for (const sx of [-1, 1]) {
    c.beam([sx * 3.2, 0.8, 9], [sx * 1.2, 7, 11], 0.7, 0.7, { name: 'Piston', c: '#b8bec4', m: 'Metal' });
    c.beam([sx * 3.2, 0.8, 9], [sx * 2.6, 3, 9.6], 1.1, 1.1, { name: 'PistonSleeve', c: '#f2b632', m: 'Metal' });
  }
  dummy(c, 'TyrannosaurusRex', [0, 0.8, 12], 28, 0.62, 'metal');
  bullseye(c, [-1.2, 5.6, 7.6], 2.2, { cols: ['#ffffff', A, '#ffffff', A] });
  targetPoint(c, [0, 6, 11]);
  for (let k = 0; k < 3; k++) c.box({ name: 'Backstop', s: [13, 2.6, 1.2], p: [0, 1.3 + k * 2.6, 18.2], c: k % 2 ? '#e8473a' : '#3a3d42', m: 'Metal', studs: 'top', collide: true });
  return c;
}

// T5 AMBER LAB: amber resin tanks with glowing cores piped to the pad, a giganotosaurus set in amber, a copper dome
function trainer5(root) {
  const c = kitModel(root, 'Trainer5');
  const A = TR.ACCENT[4];
  trainerPad(c, 5, A);
  trainerBoard(c, 5, A);
  lane(c, 5, { floor: '#5a3a22', floorM: 'Marble', edge: '#ffb02e', edgeM: 'Neon', mark: '#ffd27a' });
  for (const sx of [-1, 1]) {
    // three amber tanks a side
    for (const [z, h] of [[-6, 7], [2, 9], [10, 7.5]]) {
      const t = c.at([sx * 6.8, 0, z]);
      t.cyl({ name: 'TankBase', axis: 'y', len: 1, d: 3.6, p: [0, 0.5, 0], c: '#8a4a1e', m: 'Metal', collide: true });
      t.cyl({ name: 'TankGlass', axis: 'y', len: h, d: 3, p: [0, 1 + h / 2, 0], c: '#ffcf7a', m: 'Glass', t: 0.45, collide: true });
      const core = t.cyl({ name: 'TankCore', axis: 'y', len: h - 1, d: 1.6, p: [0, 1 + h / 2, 0], c: '#ff9a1a', m: 'Neon', t: 0.15 });
      core.tag('AmberCore');
      t.cyl({ name: 'TankCap', axis: 'y', len: 0.8, d: 3.6, p: [0, 1.4 + h, 0], c: '#c87533', m: 'Metal' });
      t.ball({ name: 'TankDome', d: 2.4, p: [0, 1.9 + h, 0], c: '#d98a44', m: 'Metal' });
      // a fossil mosquito in the biggest ones (the amber joke)
      if (h === 9) t.box({ name: 'Mosquito', s: [0.3, 0.3, 1.2], p: [0, 1 + h / 2, 0], c: '#2b2d31', shadow: false });
    }
    // a copper manifold along the tank tops, and a drop pipe into the coils by the pad
    c.beam([sx * 6.8, 9.2, -6], [sx * 6.8, 9.2, 10], 0.6, 0.6, { name: 'AmberPipe', c: '#c87533', m: 'Metal', extend: 0.6 });
    c.beam([sx * 6.8, 9.2, -6], [sx * 4.6, 3.9, TR.PAD_Z + 3.2], 0.5, 0.5, { name: 'AmberPipe', c: '#c87533', m: 'Metal', extend: 0.4 });
    for (const z of [-10, 6, 14]) c.box({ name: 'LabWall', s: [1, 3, 3.6], p: [sx * 8.6 - sx * 1.8, 1.5, z], c: '#e9dfc4', studs: 'sides', collide: true });
  }
  // a big amber block at the back with the giganotosaurus "inside" it (glassy amber dummy + glowing base)
  c.box({ name: 'AmberPlinth', s: [10, 1.2, 9], p: [0, 0.6, 13], c: '#8a4a1e', m: 'Metal', studs: 'top', collide: true });
  const glow = c.box({ name: 'AmberGlow', s: [9, 0.3, 8], p: [0, 1.3, 13], c: A, m: 'Neon', t: 0.2, shadow: false });
  E.pointLight(glow, [1, 0.62, 0.2], 26, 0.7);
  dummy(c, 'Giganotosaurus', [0, 1.4, 13], 30, 0.5, 'amber');
  targetPoint(c, [0, 6, 12]);
  // copper dome frame over the back
  const R = 9, cz = 13;
  for (let k = 0; k <= 4; k++) {
    const a = (k / 4) * Math.PI;
    const x = Math.cos(a) * R * 0.78;
    c.beam([x, 0, cz - 5], [x * 0.3, 15, cz], 0.6, 0.6, { name: 'DomeRib', c: '#c87533', m: 'Metal' });
    c.beam([x, 0, cz + 5], [x * 0.3, 15, cz], 0.6, 0.6, { name: 'DomeRib', c: '#c87533', m: 'Metal' });
  }
  c.ball({ name: 'DomeTop', d: 2.4, p: [0, 15.4, cz], c: A, m: 'Neon' });
  c.cyl({ name: 'DomeRing', axis: 'y', len: 0.5, d: 6, p: [0, 14, cz], c: '#c87533', m: 'Metal' });
  // the pad ring: four copper coils round the pad
  for (const [x, z] of [[-4.6, -1], [4.6, -1], [-4.6, 1], [4.6, 1]]) {
    const cl = c.at([x, 0, TR.PAD_Z + z * 3.2]);
    cl.cyl({ name: 'Coil', axis: 'y', len: 3.4, d: 1, p: [0, 1.7, 0], c: '#c87533', m: 'Metal', collide: true });
    for (let k = 0; k < 4; k++) cl.cyl({ name: 'CoilWind', axis: 'y', len: 0.25, d: 1.3, p: [0, 0.8 + k * 0.7, 0], c: '#ffb02e', m: 'Neon', shadow: false });
    cl.ball({ name: 'CoilTop', d: 1.2, p: [0, 3.6, 0], c: '#ffd27a', m: 'Neon' });
  }
  sign(c, [0, 4.4, 18.6], 8, 1.8, 'AMBER LAB', A, { pps: 32 });
  return c;
}

// T6 FOSSIL ENGINE: a giant fossil T. rex skull at the back (glowing eyes, a core in its jaws) and ribs arching over
// the whole range, a spine along the top, pistons
function trainer6(root) {
  const c = kitModel(root, 'Trainer6');
  const A = TR.ACCENT[5];
  const BONE = ['#e6dccb', '#d6cbb2', '#f2ece0'];
  trainerPad(c, 6, A);
  trainerBoard(c, 6, A);
  lane(c, 6, { floor: '#3d3550', floorM: 'Slate', edge: A, edgeM: 'Neon', mark: '#e6dccb' });
  // ribcage: arching bone ribs over the lane, a spine on top
  const ribs = [-12.5, -7.5, -2.5, 2.5, 7.5];
  for (const [i, z] of ribs.entries()) {
    const h = 12 + i * 0.8;
    for (const sx of [-1, 1]) {
      c.beam([sx * 7, 0, z], [sx * 7.4, h * 0.45, z], 1.4, 1.4, { name: 'Rib', c: BONE[i % 3], collide: true, extend: 0.4 });
      c.beam([sx * 7.4, h * 0.45, z], [sx * 5.4, h * 0.85, z + 0.5], 1.2, 1.2, { name: 'Rib', c: BONE[(i + 1) % 3], extend: 0.4 });
      c.beam([sx * 5.4, h * 0.85, z + 0.5], [sx * 1, h, z + 0.8], 1.1, 1.1, { name: 'Rib', c: BONE[(i + 2) % 3], extend: 0.4 });
    }
    c.box({ name: 'Vertebra', s: [2.2, 1.6, 2.2], p: [0, h + 0.4, z + 0.8], c: BONE[i % 3], studs: 'top' });
    c.wedgeF({ name: 'VertebraSpike', s: [1, 1.6, 1.8], p: [0, h + 2, z + 0.8], face: 'front', c: BONE[2] });
    c.box({ name: 'RibGlow', s: [0.4, 0.4, 0.4], p: [0, h - 0.5, z + 0.8], c: A, m: 'Neon', shadow: false });
  }
  c.beam([0, 12.6, -12], [0, 16.5, 9], 1, 1, { name: 'Spine', c: BONE[1] });
  // the skull: cranium, snout, eye sockets with glowing eyes, jaw with teeth, a purple core between the jaws
  c.box({ name: 'SkullBase', s: [13, 2, 9], p: [0, 1, 15], c: '#4a4f57', m: 'Metal', studs: 'top', collide: true });
  // (turned so you see its profile from the pad: a skull face-on reads as a box)
  const s = c.at([1, 0, 14.5], [0, -38, 0]);
  s.box({ name: 'Cranium', s: [9, 7, 7], p: [0, 9, 2], c: BONE[0], studs: 'top', collide: true });
  s.box({ name: 'Snout', s: [7, 4.4, 6], p: [0, 8.6, -3.6], c: BONE[1], studs: 'top', collide: true });
  s.wedgeF({ name: 'SnoutTip', s: [7, 2.4, 3], p: [0, 9.8, -7.8], face: 'front', c: BONE[2] });
  for (const sx of [-1, 1]) {
    s.box({ name: 'EyeSocket', s: [2.6, 2.4, 0.4], p: [sx * 2.4, 10.6, -1.35], c: '#2b2d31' });
    const eye = s.box({ name: 'SkullEye', s: [1.4, 1.2, 0.3], p: [sx * 2.4, 10.6, -1.6], c: A, m: 'Neon' });
    eye.tag('FossilEye');
    s.box({ name: 'Cheek', s: [1.6, 4, 5], p: [sx * 4.6, 7.5, 0], c: BONE[2], studs: 'sides' });
  }
  s.box({ name: 'UpperTeethRow', s: [6.4, 0.3, 5], p: [0, 6.3, -3.8], c: BONE[2] });
  for (let k = 0; k < 6; k++) for (const sx of [-1, 1]) s.wedgeF({ name: 'Tooth', s: [0.6, 1.3, 0.6], p: [sx * 3, 5.6, -6 + k * 0.9], face: 'front', flip: true, c: '#ffffff' });
  s.at([0, 4.2, 0], [20, 0, 0]).box({ name: 'Jaw', s: [7.4, 1.6, 9], p: [0, 0, -3], c: BONE[1], studs: 'top', collide: true });
  const core = s.ball({ name: 'EngineCore', d: 3.4, p: [0, 5.4, -3.2], c: A, m: 'Neon', t: 0.1 });
  core.tag('EngineCore');
  E.pointLight(core, [0.7, 0.45, 1], 26, 0.8);
  // pistons driving the jaw
  for (const sx of [-1, 1]) {
    s.beam([sx * 5.4, 2, -2], [sx * 4.2, 6.8, -4], 0.8, 0.8, { name: 'JawPiston', c: '#b8bec4', m: 'Metal' });
    s.beam([sx * 5.4, 2, -2], [sx * 5, 4, -2.6], 1.3, 1.3, { name: 'PistonSleeve', c: A, m: 'Metal' });
  }
  targetPoint(c, [0, 7, 11]);
  sign(c, [0, 17.6, 19.6], 9, 1.8, 'FOSSIL ENGINE', A, { pps: 30, bg: '#241d33' });
  return c;
}

// T7 TITAN RIG: twin pylons with floating rings, neon arches the length of the range, a holographic T. rex target on a
// projector, turbines, a beacon - the biggest thing on any island
function trainer7(root) {
  const c = kitModel(root, 'Trainer7');
  const A = TR.ACCENT[6], A2 = TR.ACCENT2[6];
  trainerPad(c, 7, A);
  trainerBoard(c, 7, A, { post: '#2b2d31' });
  lane(c, 7, { floor: '#14161c', floorM: 'Glass', edge: A, edgeM: 'Neon', mark: A2 });
  // neon arches along the lane, alternating colours, rising toward the back
  for (const [i, z] of [-12.5, -6, 0.5, 7].entries()) {
    const h = 13 + i * 1.2, col = i % 2 ? A2 : A;
    for (const sx of [-1, 1]) {
      c.box({ name: 'ArchLeg', s: [1.2, h, 1.2], p: [sx * 6.9, h / 2, z], c: '#3a3f55', m: 'Metal', studs: 'top', collide: true });
      c.box({ name: 'ArchLegGlow', s: [0.3, h - 2, 0.3], p: [sx * 6.3, h / 2, z - 0.5], c: col, m: 'Neon', shadow: false });
    }
    c.box({ name: 'ArchTop', s: [15, 1, 1], p: [0, h, z], c: '#3a3f55', m: 'Metal', studs: 'top' });
    for (const sx of [-1, 1]) c.box({ name: 'ArchCap', s: [1.6, 0.6, 1.6], p: [sx * 6.9, h + 0.8, z], c: '#ffcf3a', m: 'Metal' });
    c.box({ name: 'ArchGlow', s: [13.4, 0.35, 0.35], p: [0, h - 0.8, z - 0.5], c: col, m: 'Neon', shadow: false });
  }
  // twin pylons at the back with floating rings (TrainerView turns them) and gold caps
  for (const sx of [-1, 1]) {
    const py = c.at([sx * 6, 0, 16.4]);
    for (let k = 0; k < 7; k++) py.box({ name: 'PylonBlock', s: [3 - k * 0.22, 3.6, 3 - k * 0.22], p: [0, 1.8 + k * 3.6, 0], r: [0, k * 10, 0], c: k % 2 ? '#2b2d31' : '#3a3d42', m: 'Metal', studs: 'top', collide: true });
    py.cyl({ name: 'PylonCap', axis: 'y', len: 1, d: 3.2, p: [0, 26, 0], c: '#ffcf3a', m: 'Metal' });
    const orb = py.ball({ name: 'PylonOrb', d: 2.4, p: [0, 27.8, 0], c: sx > 0 ? A : A2, m: 'Neon' });
    E.pointLight(orb, sx > 0 ? [0.3, 0.9, 1] : [1, 0.35, 0.85], 30, 0.7);
    for (const [y, d] of [[9, 6.4], [17, 5.4]]) {
      const ring = py.group('FloatRing').at([0, y, 0]);
      for (let k = 0; k < 12; k++) {
        const a = (k / 12) * Math.PI * 2;
        ring.at([Math.cos(a) * d / 2, 0, Math.sin(a) * d / 2], [0, -a * 180 / Math.PI, 0]).box({ name: 'RingSeg', s: [0.5, 0.5, d * 0.27], c: k % 2 ? A : '#ffffff', m: 'Neon', shadow: false });
      }
    }
  }
  c.beam([-6, 22, 16.4], [6, 22, 16.4], 1.2, 1.2, { name: 'PylonBridge', c: '#ffcf3a', m: 'Metal' });
  const sgn = c.box({ name: 'TitanSign', s: [9, 2.4, 0.5], p: [0, 24, 16.2], c: '#14161c' });
  label(sgn, 'Front', 'TITAN RIG', { pps: 30, color: '#ffffff', color2: A });
  c.box({ name: 'TitanSignGlow', s: [9.6, 3, 0.3], p: [0, 24, 16.5], c: A2, m: 'Neon', shadow: false });
  // the holo projector + holographic T. rex
  c.cyl({ name: 'Projector', axis: 'y', len: 1.2, d: 9.6, p: [0, 0.6, 11.5], c: '#2b2d31', m: 'Metal', collide: true });
  c.cyl({ name: 'ProjectorRing', axis: 'y', len: 1.25, d: 10, p: [0, 0.6, 11.5], c: A, m: 'Neon', t: 0.2, shadow: false });
  c.cyl({ name: 'ProjectorLens', axis: 'y', len: 1.3, d: 4, p: [0, 0.6, 11.5], c: '#ffffff', m: 'Neon', shadow: false });
  dummy(c, 'TyrannosaurusRex', [0, 1.2, 12], 26, 0.78, 'holo');
  bullseye(c, [-1.4, 6.8, 6.8], 2.6, { cols: [A2, '#ffffff', A2, '#ffffff'], m: 'Neon' });
  targetPoint(c, [0, 7, 11]);
  // turbines on the side walls
  for (const sx of [-1, 1]) for (const z of [-3, 4]) {
    const tb = c.at([sx * 8, 3.4, z]);
    tb.cyl({ name: 'Turbine', axis: 'x', len: 2, d: 4.2, c: '#3a3d42', m: 'Metal', collide: true });
    tb.cyl({ name: 'TurbineFace', axis: 'x', len: 0.2, d: 3.4, p: [-sx * 1.05, 0, 0], c: A, m: 'Neon', t: 0.3, shadow: false });
    for (let k = 0; k < 4; k++) tb.at([-sx * 1.2, 0, 0], [k * 45, 0, 0]).box({ name: 'TurbineBlade', s: [0.2, 3.2, 0.5], c: '#d9d9d9', m: 'Metal', shadow: false });
  }
  // gold trim on the pad end + a beacon
  for (const sx of [-1, 1]) c.box({ name: 'GoldPost', s: [1, 3, 1], p: [sx * 5.4, 1.5, -17], c: '#ffcf3a', m: 'Metal', studs: 'top', collide: true });
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
