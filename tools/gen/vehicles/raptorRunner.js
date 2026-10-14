// VEHICLE 2 — THE RAPTOR RUNNER: the premium pursuit jeep (mid-tier).
// Same expedition-jeep family as the Rookie Ranger, but lifted, armored and kitted out.
// Local frame: forward = -Z, up = +Y, origin = ground center. ~15 x 8.5 x 7.5 studs.
// Clearances are laid out so no body part intersects the wheels (verified by tools/gen/qc.js).
const { Inst, Ctx, CF, shade, rng, surfaceText } = require('../builder.js');
const { wheel, lamp, stripes, egg, mud, clawMarks } = require('./common.js');

const C = {
  orange: '#ff7a1a', orangeHi: '#ff9d4d', orangeLo: '#d65c0b',
  black: '#1b1c1f', blackHi: '#2a2c31', graph: '#3a3d44', graphHi: '#50545d',
  cyan: '#2ee6ff', cyanGlass: '#61ecff', chrome: '#c3c8cf', bone: '#f1e6c8', red: '#ff3b30', white: '#f5fbff',
  glass: '#22343c', tan: '#c9a66b',
};

const WX = 3.35, WY = 1.8, WD = 3.6, WW = 1.7; // wheel centre x, y, diameter, width
const ZF = -4.7, ZR = 4.5; // axle positions

function toothBadge(ctx, d) {
  ctx.cyl({ name: 'InsigniaBadge', axis: 'z', len: 0.08, d, c: C.black });
  ctx.cyl({ name: 'InsigniaRing', axis: 'z', len: 0.06, d: d * 1.15, p: [0, 0, 0.02], c: C.orangeHi });
  const h = d * 0.62, w = d * 0.36;
  ctx.sym((s) => s.wedgeF({ name: 'InsigniaFang', s: [0.06, h, w / 2], p: [w / 4, -d * 0.04, -0.07], face: 'left', flip: true, c: C.bone }));
}

function coilover(ctx, a, b, o = {}) {
  ctx.tube(a, b, o.d || 0.22, { name: 'ShockBody', c: C.chrome, m: 'Metal' });
  const n = o.rings || 6;
  for (let i = 0; i < n; i++) {
    const t0 = 0.12 + (i / n) * 0.76, t1 = t0 + 0.05;
    const p0 = a.map((v, k) => v + (b[k] - v) * t0), p1 = a.map((v, k) => v + (b[k] - v) * t1);
    ctx.tube(p0, p1, (o.d || 0.22) * 2.4, { name: 'Spring', c: o.c || C.cyan, m: 'Metal', shadow: false });
  }
}

function build() {
  const model = new Inst('Model', 'RaptorRunner');
  model.attr('DisplayName', 'Raptor Runner').attr('Tier', 'Pursuit').attr('VehicleClass', 'Pursuit Jeep');
  model.tag('DinoExpeditionVehicle');
  const root = new Ctx({ parent: model, frame: new CF(), defaults: { anchored: true } });
  const vroot = root.box({ name: 'VehicleRoot', s: [1, 1, 1], p: [0, 2.8, 0], t: 1, shadow: false, c: '#ffffff' });
  model.set('PrimaryPart', 'Ref', vroot);
  const body = root.group('Body');
  const wheels = root.group('Wheels');
  const interior = root.group('Interior');
  const equip = root.group('Equipment');
  const eggs = root.group('EggStorage');
  const det = root.group('Details');
  const R = rng(2202);

  // ---------------- Chassis + suspension (inboard of the wheels: x < 2.5) ----------------
  body.box({ name: 'FrameRail', s: [3.2, 0.6, 12.6], p: [0, 2.1, 0], c: C.graph, m: 'Metal' });
  body.box({ name: 'SkidPlate', s: [2.8, 0.18, 3.0], p: [0, 1.72, -5.0], c: C.graphHi, m: 'DiamondPlate' });
  for (const z of [ZF, ZR]) {
    body.cyl({ name: 'Axle', len: 4.9, d: 0.55, p: [0, WY, z], c: C.black, m: 'Metal' });
    body.cyl({ name: 'Differential', axis: 'z', len: 0.8, d: 1.0, p: [0, WY, z], c: C.graphHi, m: 'Metal' });
    body.sym((s) => coilover(s, [1.95, WY + 0.15, z + 0.6], [1.75, 3.6, z + 0.35], { d: 0.24, rings: 6 }));
  }

  // ---------------- Body tub ----------------
  // lower nose between the front wheels + engine bay above them
  body.box({ name: 'NoseLower', s: [4.8, 1.4, 3.9], p: [0, 3.1, -4.85], c: C.orangeLo });
  body.box({ name: 'Nose', s: [6.0, 1.2, 4.2], p: [0, 4.4, -4.7], c: C.orange, studs: 'top' });
  body.box({ name: 'Hood', s: [5.7, 0.32, 4.0], p: [0, 5.16, -4.7], c: C.orange, studs: 'top' });
  body.box({ name: 'PowerBulge', s: [2.4, 0.2, 3.6], p: [0, 5.42, -4.7], c: C.orangeHi });
  body.wedgeF({ name: 'PowerBulgeNose', s: [2.4, 0.2, 0.35], p: [0, 5.42, -6.67], face: 'front', c: C.orangeHi });
  for (let i = 0; i < 4; i++) body.box({ name: 'HoodVent', s: [1.6, 0.06, 0.16], p: [0, 5.55, -5.6 + i * 0.4], c: C.black });
  body.wedgeF({ name: 'HoodChamfer', s: [5.7, 0.32, 0.4], p: [0, 5.16, -6.9], face: 'front', c: C.orange });
  body.sym((s) => {
    s.wedgeF({ name: 'HoodSideChamfer', s: [4.0, 0.32, 0.25], p: [2.97, 5.16, -4.7], face: 'right', c: C.orangeLo });
    s.box({ name: 'HoodPin', s: [0.16, 0.12, 0.16], p: [2.4, 5.36, -6.3], c: C.chrome, m: 'Metal' });
    s.box({ name: 'HoodStripe', s: [0.3, 0.04, 4.0], p: [1.65, 5.34, -4.7], c: C.black });
  });
  toothBadge(body.at([0, 5.56, -4.2], [90, 0, 0]), 1.0);
  // floor (between the wheels' inner faces), side walls, wheel-well liners & lids
  body.box({ name: 'Floor', s: [4.8, 0.3, 8.8], p: [0, 3.05, 1.8], c: C.graph, m: 'DiamondPlate' });
  body.sym((s) => {
    s.box({ name: 'SideMid', s: [0.4, 2.6, 5.1], p: [2.8, 3.7, -0.15], c: C.orange, studs: 'sides' });
    s.box({ name: 'SideRear', s: [0.4, 1.2, 4.1], p: [2.8, 4.4, 4.6], c: C.orange, studs: 'sides' });
    s.box({ name: 'SideCap', s: [0.5, 0.14, 9.3], p: [2.8, 5.07, 2.0], c: C.black });
    s.box({ name: 'WheelWellLiner', s: [0.1, 0.7, 3.7], p: [2.42, 3.55, ZR], c: C.black });
    s.box({ name: 'WheelTubLid', s: [0.45, 0.2, 3.7], p: [2.62, 3.9, ZR], c: C.black });
    // armored half door + insignia + handle + number
    s.box({ name: 'DoorArmor', s: [0.14, 1.6, 2.6], p: [3.07, 3.85, -1.3], c: C.graphHi, m: 'Metal' });
    for (const [dy, dz] of [[0.6, 1.1], [-0.6, 1.1], [0.6, -1.1], [-0.6, -1.1]]) s.cyl({ name: 'Bolt', len: 0.08, d: 0.13, p: [3.16, 3.85 + dy, -1.3 + dz], c: C.chrome, m: 'Metal' });
    toothBadge(s.at([3.16, 3.85, -1.3], [0, -90, 0]), 0.8);
    s.box({ name: 'DoorHandle', s: [0.14, 0.15, 0.5], p: [3.08, 4.65, 0.6], c: C.black });
    s.box({ name: 'DoorSeam', s: [0.04, 2.4, 0.07], p: [3.01, 3.7, 0.95], c: C.orangeLo });
    // rock slider (tube step) between the wheels
    s.tube([3.15, 2.45, -2.6], [3.15, 2.45, 2.3], 0.3, { name: 'RockSlider', c: C.black, m: 'Metal' });
    for (const z of [-2.0, 0, 2.0]) s.tube([2.6, 2.45, z], [3.15, 2.45, z], 0.2, { name: 'SliderMount', c: C.black, m: 'Metal' });
    // steel tube fender flares (clear of the 3.6 stud tyres)
    for (const z of [ZF, ZR]) {
      s.box({ name: 'FenderFlare', s: [1.35, 0.26, 2.6], p: [3.66, 3.92, z], c: C.black, m: 'Metal', studs: 'top' });
      s.beam([3.66, 3.9, z - 1.3], [3.66, 2.95, z - 2.0], 1.35, 0.26, { name: 'FenderFlare', c: C.black, m: 'Metal', extend: 0.2 });
      s.beam([3.66, 3.9, z + 1.3], [3.66, 2.95, z + 2.0], 1.35, 0.26, { name: 'FenderFlare', c: C.black, m: 'Metal', extend: 0.2 });
      s.box({ name: 'FlareLED', s: [0.06, 0.08, 2.4], p: [4.34, 3.8, z], c: C.cyan, m: 'Neon' });
    }
    s.box({ name: 'BeltStripe', s: [0.04, 0.24, 12.0], p: [3.02, 4.75, 0.0], c: C.black });
  });
  // Tailgate + rear bumper
  body.box({ name: 'Tailgate', s: [6.0, 2.0, 0.4], p: [0, 4.0, 6.85], c: C.orange, studs: 'sides' });
  body.box({ name: 'TailgateCap', s: [6.1, 0.14, 0.5], p: [0, 5.07, 6.85], c: C.black });
  body.box({ name: 'RearBumper', s: [6.4, 0.7, 0.8], p: [0, 2.75, 7.25], c: C.black, studs: 'top' });
  body.sym((s) => {
    s.box({ name: 'TailLight', s: [0.5, 0.9, 0.1], p: [2.55, 4.1, 7.08], c: C.red, m: 'Neon' });
    s.box({ name: 'TailLightBezel', s: [0.66, 1.06, 0.06], p: [2.55, 4.1, 7.05], c: C.black });
    s.box({ name: 'TowShackle', s: [0.18, 0.35, 0.35], p: [1.9, 2.75, 7.7], c: C.orange });
  });

  // Front fascia: armored grille, LED headlights with cyan halos, winch bumper with bash teeth
  body.box({ name: 'GrillePanel', s: [4.6, 1.5, 0.3], p: [0, 4.35, -6.95], c: C.black });
  for (let i = -4; i <= 4; i++) body.box({ name: 'GrilleBar', s: [0.2, 1.2, 0.14], p: [i * 0.42, 4.35, -7.15], c: C.graphHi, m: 'Metal' });
  body.box({ name: 'GrilleFrame', s: [4.7, 0.16, 0.18], p: [0, 5.08, -7.08], c: C.orangeHi });
  body.sym((s) => {
    s.box({ name: 'HeadlightHousing', s: [1.0, 0.75, 0.3], p: [2.45, 4.4, -6.98], c: C.black });
    s.box({ name: 'Headlight', s: [0.72, 0.48, 0.1], p: [2.45, 4.4, -7.15], c: C.white, m: 'Neon' });
    s.box({ name: 'HaloTop', s: [0.86, 0.06, 0.08], p: [2.45, 4.7, -7.16], c: C.cyan, m: 'Neon' });
    s.box({ name: 'HaloBottom', s: [0.86, 0.06, 0.08], p: [2.45, 4.1, -7.16], c: C.cyan, m: 'Neon' });
    s.box({ name: 'TurnSignal', s: [0.5, 0.2, 0.1], p: [2.45, 3.6, -7.0], c: '#ffa21f', m: 'Neon' });
  });
  body.box({ name: 'FrontBumper', s: [6.8, 0.85, 0.9], p: [0, 2.85, -7.3], c: C.black, studs: 'top' });
  for (const x of [-2.3, 2.3]) stripes(body, [x, 2.85, -7.76], { len: 1.6, h: 0.3, n: 4, c1: C.orange, c2: C.black });
  for (const x of [-2.8, -2.25, 2.25, 2.8]) body.wedgeF({ name: 'BashTooth', s: [0.32, 0.45, 0.5], p: [x, 2.62, -8.0], face: 'front', flip: true, c: C.bone });
  body.cyl({ name: 'Winch', len: 1.6, d: 0.55, p: [0, 3.45, -7.45], c: C.graphHi, m: 'Metal' });
  body.box({ name: 'WinchHook', s: [0.22, 0.32, 0.14], p: [0, 3.45, -7.8], c: C.orange });
  body.sym((s) => {
    s.tube([1.4, 3.3, -7.55], [1.4, 4.9, -7.55], 0.22, { name: 'BullBar', c: C.black, m: 'Metal' });
    s.box({ name: 'TowShackle', s: [0.18, 0.35, 0.35], p: [2.0, 2.4, -7.75], c: C.orange });
    lamp(s, [1.4, 5.15, -7.5], { d: 0.5, depth: 0.35, name: 'AuxLight', housing: C.black, ring: C.cyan, lens: C.white });
  });
  body.tube([-1.4, 4.9, -7.55], [1.4, 4.9, -7.55], 0.22, { name: 'BullBarTop', c: C.black, m: 'Metal', extend: 0.1 });

  // Snorkel (left)
  const L = body.clone({ mirrored: true });
  L.tube([3.15, 4.3, -3.3], [3.15, 6.7, -3.05], 0.38, { name: 'Snorkel', c: C.black });
  L.box({ name: 'SnorkelHead', s: [0.6, 0.6, 0.85], p: [3.15, 6.85, -3.15], c: C.black });
  L.wedgeF({ name: 'SnorkelScoop', s: [0.6, 0.42, 0.38], p: [3.15, 6.93, -3.75], face: 'front', c: C.black });

  // Windshield (upright), glass, glints, wipers
  const ws = body.at([0, 5.35, -2.65], [6, 0, 0]);
  ws.sym((s) => s.box({ name: 'APillar', s: [0.32, 1.85, 0.32], p: [2.75, 0.92, 0], c: C.black }));
  ws.box({ name: 'WindshieldTop', s: [5.82, 0.3, 0.34], p: [0, 1.8, 0], c: C.black });
  ws.box({ name: 'WindshieldBase', s: [5.82, 0.26, 0.36], p: [0, 0.13, 0], c: C.black });
  ws.box({ name: 'Windshield', s: [5.2, 1.42, 0.1], p: [0, 0.97, 0], c: C.glass, m: 'Glass', t: 0.38, refl: 0.18 });
  ws.box({ name: 'Glint', s: [0.16, 1.1, 0.02], p: [-1.3, 0.97, -0.07], r: [0, 0, -28], c: '#ffffff', t: 0.55, shadow: false });
  ws.box({ name: 'Wiper', s: [1.6, 0.06, 0.05], p: [-0.5, 0.33, -0.2], r: [0, 0, 8], c: '#141518' });
  ws.box({ name: 'Wiper', s: [1.6, 0.06, 0.05], p: [1.9, 0.33, -0.2], r: [0, 0, 8], c: '#141518' });
  ws.sym((s) => lamp(s, [2.75, 1.95, -0.25], { d: 0.38, depth: 0.3, name: 'DitchLight', housing: C.black, ring: C.cyan, lens: C.white }));
  body.sym((s) => {
    s.box({ name: 'MirrorArm', s: [0.6, 0.12, 0.12], p: [3.2, 5.7, -2.55], c: C.black });
    s.box({ name: 'Mirror', s: [0.18, 0.5, 0.62], p: [3.55, 5.8, -2.55], c: C.black });
    s.box({ name: 'MirrorGlass', s: [0.04, 0.4, 0.5], p: [3.66, 5.8, -2.55], c: '#a9d6e5', m: 'Glass', refl: 0.3 });
  });

  // Safari cage + roof platform
  const rackY = 7.15;
  body.sym((s) => {
    s.tube([2.7, 5.07, 0.7], [2.7, rackY, 0.7], 0.32, { name: 'RollBar', c: C.black, m: 'Metal' });
    s.tube([2.7, 5.07, 6.3], [2.7, rackY, 6.3], 0.26, { name: 'RackPost', c: C.black, m: 'Metal' });
    s.tube([2.75, rackY, -2.4], [2.75, rackY, 6.4], 0.28, { name: 'RackRail', c: C.black, m: 'Metal', extend: 0.2 });
    s.tube([2.7, 5.3, 0.7], [2.7, 6.6, 2.4], 0.2, { name: 'CageBrace', c: C.graphHi, m: 'Metal' });
  });
  body.tube([-2.7, rackY, 0.7], [2.7, rackY, 0.7], 0.32, { name: 'RollBarTop', c: C.black, m: 'Metal', extend: 0.3 });
  for (const z of [-2.2, -0.8, 2.2, 3.8, 5.4]) body.tube([-2.75, rackY + 0.05, z], [2.75, rackY + 0.05, z], 0.16, { name: 'RackCrossbar', c: C.graphHi, m: 'Metal' });
  // LED light bar over the windshield
  equip.box({ name: 'LightBarHousing', s: [5.0, 0.4, 0.45], p: [0, rackY + 0.3, -2.25], c: C.black });
  for (let i = 0; i < 8; i++) equip.box({ name: 'LightBarLED', s: [0.5, 0.24, 0.06], p: [-2.1 + i * 0.6, rackY + 0.3, -2.5], c: C.white, m: 'Neon' });
  equip.box({ name: 'LightBarCyan', s: [5.0, 0.05, 0.06], p: [0, rackY + 0.1, -2.5], c: C.cyan, m: 'Neon' });
  // orange recovery boards + jerry cans + beacon on the roof platform
  for (const x of [-1.3, 1.3]) {
    equip.box({ name: 'RecoveryBoard', s: [1.0, 0.14, 3.4], p: [x, rackY + 0.2, 3.9], c: C.orange });
    for (let i = 0; i < 5; i++) equip.box({ name: 'BoardNub', s: [0.7, 0.08, 0.12], p: [x, rackY + 0.3, 2.6 + i * 0.6], c: C.orangeLo });
  }
  equip.box({ name: 'JerryCan', s: [0.9, 0.95, 0.5], p: [0, rackY + 0.55, 6.0], c: C.black });
  equip.box({ name: 'JerryCanHandle', s: [0.6, 0.12, 0.12], p: [0, rackY + 1.08, 6.0], c: C.orange });
  equip.box({ name: 'BeaconBase', s: [0.6, 0.2, 0.6], p: [1.9, rackY + 0.2, 0.7], c: C.black });
  const beacon = equip.cyl({ name: 'WarningBeacon', axis: 'y', len: 0.45, d: 0.48, p: [1.9, rackY + 0.52, 0.7], c: C.cyan, m: 'Neon' });
  beacon.tag('BlinkLight');
  equip.tube([2.6, 5.15, 6.4], [2.4, 8.3, 6.8], 0.06, { name: 'Antenna', c: C.black });
  equip.ball({ name: 'AntennaTip', d: 0.16, p: [2.4, 8.33, 6.8], c: C.cyan, m: 'Neon' });

  // ---------------- Wheels (+ spare on a swing-out carrier, clear of the bumper) ----------------
  const wo = { d: WD, w: WW, tire: '#202124', rim: C.black, rimAccent: C.cyan, hub: C.orange, lugs: 14, style: 'chevron', spokes: 6 };
  const wl = wheels.clone({ mirrored: true });
  wheel(wheels, [WX, WY, ZF], Object.assign({ name: 'WheelFR' }, wo));
  wheel(wl, [WX, WY, ZF], Object.assign({ name: 'WheelFL' }, wo));
  wheel(wheels, [WX, WY, ZR], Object.assign({ name: 'WheelRR' }, wo));
  wheel(wl, [WX, WY, ZR], Object.assign({ name: 'WheelRL' }, wo));
  det.box({ name: 'SpareCarrier', s: [0.5, 0.5, 0.75], p: [0, 4.5, 7.4], c: C.black });
  det.box({ name: 'SpareCarrierArm', s: [0.3, 1.5, 0.3], p: [0, 3.8, 7.35], c: C.black });
  wheel(wheels.at([0, 4.5, 8.05], [0, -90, 0]), [0, 0, 0], Object.assign({}, wo, { name: 'SpareTire', d: 2.7, w: 0.85, lugs: 12 }));

  // ---------------- Interior ----------------
  interior.box({ name: 'Dashboard', s: [5.0, 0.6, 0.75], p: [0, 4.7, -2.15], c: C.black });
  interior.box({ name: 'DigitalDash', s: [1.6, 0.42, 0.06], p: [-1.25, 4.85, -1.76], r: [-12, 0, 0], c: '#0b1a22' });
  interior.box({ name: 'DashScreen', s: [1.4, 0.3, 0.04], p: [-1.25, 4.85, -1.72], r: [-12, 0, 0], c: C.cyan, m: 'Neon' });
  for (let i = 0; i < 4; i++) interior.box({ name: 'DashIndicator', s: [0.12, 0.12, 0.05], p: [0.4 + i * 0.3, 4.75, -1.76], c: i === 3 ? C.red : C.cyan, m: 'Neon' });
  interior.tube([-1.25, 4.55, -1.9], [-1.25, 5.1, -1.35], 0.14, { name: 'SteeringColumn', c: C.black });
  const sw = interior.at([-1.25, 5.15, -1.3], [-35, 0, 0]);
  sw.cyl({ name: 'SteeringWheel', axis: 'z', len: 0.1, d: 0.95, c: C.black });
  sw.cyl({ name: 'SteeringHub', axis: 'z', len: 0.16, d: 0.3, c: C.cyan, m: 'Neon' });
  interior.box({ name: 'CenterConsole', s: [0.8, 0.5, 1.7], p: [0, 3.45, -0.9], c: C.black });
  interior.sym((s, side) => {
    s.box({ cls: side > 0 ? 'Seat' : 'VehicleSeat', name: side > 0 ? 'PassengerSeat' : 'DriverSeat', s: [1.5, 0.36, 1.5], p: [1.3, 3.4, -0.7], c: C.black, m: 'Fabric', collide: true });
    const bk = s.at([1.3, 4.45, 0.15], [10, 0, 0]);
    bk.box({ name: 'SeatBack', s: [1.5, 1.9, 0.34], c: C.black, m: 'Fabric' });
    bk.box({ name: 'SeatStripe', s: [0.4, 1.8, 0.05], p: [0, 0, -0.2], c: C.orange, m: 'Fabric' });
    bk.sym((b) => b.box({ name: 'SeatBolster', s: [0.22, 1.5, 0.5], p: [0.76, -0.1, -0.14], r: [0, -15, 0], c: C.blackHi, m: 'Fabric' }));
    for (const x of [-0.3, 0.3]) s.beam([1.3 + x, 5.2, 0.05], [1.3 + x * 0.6, 3.65, -0.9], 0.14, 0.04, { name: 'Harness', c: C.orange });
  });

  // ---------------- Egg containment pod in the bed (between the wheel-well liners) ----------------
  const pod = eggs.at([0, 3.2, 3.9]);
  pod.box({ name: 'PodBase', s: [3.6, 0.3, 2.6], p: [0, 0.15, 0], c: C.graph, m: 'Metal' });
  pod.box({ name: 'PodBaseTrim', s: [3.7, 0.12, 2.7], p: [0, 0.36, 0], c: C.orange });
  const eggCols = [['#ffb347', '#c2410c'], ['#9ff3ff', '#0e7490'], ['#c7f08a', '#4d7c0f']];
  [-1.05, 0, 1.05].forEach((x, i) => {
    pod.cyl({ name: 'EggCradle', axis: 'y', len: 0.22, d: 0.95, p: [x, 0.53, 0], c: C.black });
    pod.cyl({ name: 'CradleRing', axis: 'y', len: 0.06, d: 1.0, p: [x, 0.66, 0], c: C.cyan, m: 'Neon' });
    egg(pod, [x, 1.2, 0], { w: 0.82, h: 1.12, c: eggCols[i][0], spot: eggCols[i][1], seed: 20 + i });
    pod.box({ name: 'ClampArm', s: [0.2, 0.16, 1.3], p: [x, 1.9, 0.15], c: C.black });
    pod.box({ name: 'ClampJaw', s: [0.2, 0.4, 0.14], p: [x, 1.71, -0.45], c: C.black });
  });
  for (const [x, z] of [[-1.7, -1.15], [1.7, -1.15], [-1.7, 1.15], [1.7, 1.15]]) pod.box({ name: 'PodPost', s: [0.26, 1.9, 0.26], p: [x, 1.3, z], c: C.graphHi, m: 'Metal' });
  for (const z of [-1.15, 1.15]) pod.box({ name: 'PodRail', s: [3.66, 0.24, 0.26], p: [0, 2.2, z], c: C.graphHi, m: 'Metal' });
  for (const x of [-1.7, 1.7]) pod.box({ name: 'PodRail', s: [0.26, 0.24, 2.56], p: [x, 2.2, 0], c: C.graphHi, m: 'Metal' });
  const glass = { c: C.cyanGlass, m: 'Glass', t: 0.55, refl: 0.1, shadow: false };
  pod.box(Object.assign({ name: 'PodGlassFront', s: [3.14, 1.6, 0.08], p: [0, 1.35, -1.08] }, glass));
  pod.box(Object.assign({ name: 'PodGlassBack', s: [3.14, 1.6, 0.08], p: [0, 1.35, 1.08] }, glass));
  pod.box(Object.assign({ name: 'PodGlassTop', s: [3.14, 0.08, 2.04], p: [0, 2.26, 0] }, glass));
  for (const x of [-1.0, 0, 1.0]) pod.cyl({ name: 'LidHinge', len: 0.55, d: 0.26, p: [x, 2.36, 1.2], c: C.black, m: 'Metal' });
  [C.cyan, C.cyan, '#5dff7a'].forEach((c, i) => pod.box({ name: 'StatusLight', s: [0.16, 0.16, 0.06], p: [-0.4 + i * 0.4, 0.15, -1.33], c, m: 'Neon' }));

  // ---------------- Details ----------------
  det.sym((s) => mud(s, R, { n: 6, x: 3.03, z0: -2.4, z1: 2.2, y0: 2.6, y1: 3.4, colors: ['#6b4a2e', '#5a3d25'] }));
  clawMarks(det, [3.03, 4.3, 4.6], { len: 1.2, ang: -32, gap: 0.24 });
  const numPlate = det.box({ name: 'NumberPlate', s: [0.05, 0.6, 0.75], p: [3.04, 4.4, -0.1], c: C.white });
  surfaceText(numPlate, 'Right', '02', { color: '#1b1c1f', pps: 80, shadow: 0, strokeT: 0 });
  const plate = body.box({ name: 'LicensePlate', s: [1.6, 0.45, 0.06], p: [0, 2.85, -7.78], c: C.white });
  surfaceText(plate, 'Front', 'RAPTR-02', { color: '#1b1c1f', pps: 90, shadow: 0, strokeT: 0 });
  return model;
}

module.exports = { build };
