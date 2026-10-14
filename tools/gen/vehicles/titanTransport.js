// VEHICLE 3 — THE TITAN TRANSPORT: six-wheeled armored egg extraction truck (high tier).
// Local frame: forward = -Z, up = +Y, origin = ground center. ~21 x 10 x 10 studs.
const { Inst, Ctx, CF, shade, rng, surfaceText } = require('../builder.js');
const { wheel, flood, lamp, stripes, egg, clawMarks } = require('./common.js');

const C = {
  green: '#4a5d33', greenHi: '#5c7340', greenLo: '#38482a', greenDk: '#2c3a21',
  graph: '#33363b', graphHi: '#474b52', black: '#1a1b1e', metal: '#7f868e', chrome: '#b9bec4',
  orange: '#d9642b', orangeHi: '#ec7b3e', warm: '#ffd27a', amber: '#ffb02e', red: '#e0362c',
  glass: '#26343a', amberGlass: '#ffcf7a', pad: '#c8682f',
};

function piston(ctx, a, b, o = {}) {
  const mid = a.map((v, k) => v + (b[k] - v) * 0.55);
  ctx.tube(a, mid, o.d || 0.45, { name: 'HydraulicCylinder', c: C.graphHi, m: 'Metal' });
  ctx.tube(mid, b, (o.d || 0.45) * 0.5, { name: 'HydraulicRod', c: C.chrome, m: 'Metal', extend: 0.2 });
  ctx.at(a).box({ name: 'PistonMount', s: [0.3, 0.55, 0.55], c: C.black });
  ctx.at(b).box({ name: 'PistonMount', s: [0.3, 0.45, 0.45], c: C.black });
  ctx.at(a).cyl({ name: 'PistonPin', len: 0.4, d: 0.22, c: C.orange });
  ctx.at(b).cyl({ name: 'PistonPin', len: 0.4, d: 0.2, c: C.orange });
}

function bolts(ctx, x, y0, z0, w, h, n = 2) {
  for (let i = 0; i < n; i++) for (let j = 0; j < 2; j++) {
    ctx.cyl({ name: 'Bolt', len: 0.08, d: 0.14, p: [x, y0 + (j ? h / 2 : -h / 2), z0 + (n === 1 ? 0 : -w / 2 + (w * i) / (n - 1))], c: C.chrome, m: 'Metal' });
  }
}

function build() {
  const model = new Inst('Model', 'TitanTransport');
  model.attr('DisplayName', 'Titan Transport').attr('Tier', 'Elite').attr('VehicleClass', 'Armored Extraction Truck');
  model.tag('DinoExpeditionVehicle');
  const root = new Ctx({ parent: model, frame: new CF(), defaults: { anchored: true } });
  const vroot = root.box({ name: 'VehicleRoot', s: [1, 1, 1], p: [0, 3.5, 0], t: 1, shadow: false, c: '#ffffff' });
  model.set('PrimaryPart', 'Ref', vroot);
  const body = root.group('Body');
  const wheels = root.group('Wheels');
  const interior = root.group('Interior');
  const equip = root.group('Equipment');
  const eggs = root.group('EggStorage');
  const det = root.group('Details');
  const R = rng(3303);

  const UB = 4.3; // upper body underside
  const AX = [-6.4, 3.4, 6.9]; // axle z positions

  // ---------------- Chassis / lower hull ----------------
  body.box({ name: 'LowerHull', s: [5.8, 1.7, 19.4], p: [0, 3.45, -0.15], c: C.graph, m: 'Metal' });
  body.box({ name: 'FrameRail', s: [5.0, 0.5, 19.8], p: [0, 2.45, -0.15], c: C.black });
  for (const z of AX) {
    body.cyl({ name: 'Axle', len: 6.4, d: 0.6, p: [0, 1.9, z], c: C.black, m: 'Metal' });
    body.cyl({ name: 'Differential', axis: 'z', len: 0.9, d: 1.1, p: [0, 1.9, z], c: C.graphHi, m: 'Metal' });
    body.sym((s) => {
      for (let i = 0; i < 3; i++) s.box({ name: 'LeafSpring', s: [0.5, 0.14, 2.6 - i * 0.6], p: [2.6, 2.2 + i * 0.16, z], c: C.graphHi, m: 'Metal' });
      s.tube([2.7, 2.0, z + 0.7], [2.6, 3.4, z + 1.0], 0.3, { name: 'Shock', c: C.orange, m: 'Metal' });
    });
  }

  // ---------------- Front: bumper + ram ----------------
  body.box({ name: 'FrontBumper', s: [9.6, 1.3, 1.0], p: [0, 3.0, -10.0], c: C.graph, studs: 'top' });
  stripes(body, [0, 3.0, -10.52], { len: 8.0, h: 0.6, n: 12, c1: C.orange, c2: C.black });
  body.sym((s) => {
    s.wedgeF({ name: 'BumperCheek', s: [1.0, 1.3, 0.6], p: [5.05, 3.0, -10.0], face: 'right', c: C.graphHi });
    s.box({ name: 'TowHook', s: [0.3, 0.5, 0.5], p: [3.6, 2.2, -10.4], c: C.orange });
    // Front protective ram
    s.box({ name: 'RamPost', s: [0.55, 3.6, 0.55], p: [2.5, 4.0, -10.85], c: C.black, m: 'Metal' });
    s.box({ name: 'RamPostCap', s: [0.65, 0.3, 0.65], p: [2.5, 5.9, -10.85], c: C.orange });
    s.beam([2.5, 5.6, -10.85], [3.9, 4.4, -10.4], 0.4, 0.4, { name: 'RamWing', c: C.black, m: 'Metal' });
    s.wedgeF({ name: 'RamPlowSide', s: [2.6, 1.2, 0.8], p: [3.4, 2.0, -10.85], r: [0, -16, 0], face: 'front', c: C.graphHi, m: 'Metal' });
  });
  for (const y of [2.6, 3.9, 5.1]) body.box({ name: 'RamBar', s: [6.4, 0.45, 0.45], p: [0, y, -11.05], c: C.black, m: 'Metal' });
  body.wedgeF({ name: 'RamPlow', s: [4.6, 1.2, 0.8], p: [0, 2.0, -11.0], face: 'front', c: C.graphHi, m: 'Metal' });
  stripes(body, [0, 2.45, -11.31], { len: 4.4, h: 0.28, n: 8, c1: C.orange, c2: C.black });
  body.cyl({ name: 'Winch', len: 2.2, d: 0.8, p: [0, 3.0, -10.6], c: C.graphHi, m: 'Metal' });

  // ---------------- Nose ----------------
  body.box({ name: 'Nose', s: [8.0, 1.9, 2.5], p: [0, UB + 0.95, -8.25], c: C.green, studs: 'sides' });
  body.wedgeF({ name: 'NoseChamfer', s: [8.0, 0.6, 0.8], p: [0, UB + 2.2, -9.1], face: 'front', c: C.greenHi });
  body.box({ name: 'NoseTop', s: [8.0, 0.6, 1.7], p: [0, UB + 2.2, -7.85], c: C.green, studs: 'top' });
  body.box({ name: 'GrilleRecess', s: [5.4, 1.5, 0.2], p: [0, UB + 0.95, -9.55], c: C.black });
  for (let i = -3; i <= 3; i++) body.box({ name: 'GrilleBar', s: [0.3, 1.5, 0.32], p: [i * 0.75, UB + 0.95, -9.62], c: C.metal, m: 'Metal' });
  body.box({ name: 'GrilleCrossbar', s: [5.6, 0.25, 0.36], p: [0, UB + 0.95, -9.68], c: C.graphHi, m: 'Metal' });
  body.box({ name: 'GrilleFrame', s: [5.9, 0.25, 0.3], p: [0, UB + 1.78, -9.55], c: C.orange });
  body.sym((s) => {
    flood(s, [3.35, UB + 1.05, -9.6], { w: 1.0, h: 0.85, depth: 0.4, cage: true, lens: C.warm, name: 'Headlight' });
    s.box({ name: 'MarkerLight', s: [0.5, 0.25, 0.12], p: [3.35, UB + 0.25, -9.55], c: C.amber, m: 'Neon' });
    s.wedgeF({ name: 'NoseSideChamfer', s: [2.5, 0.6, 0.5], p: [3.75, UB + 2.2, -8.25], face: 'right', c: C.greenLo });
  });

  // ---------------- Cab (hollow shell) ----------------
  const cz0 = -7.0, cz1 = -3.4, cTop = 9.0;
  body.box({ name: 'CabFloor', s: [8.2, 0.3, 3.6], p: [0, UB + 0.15, -5.2], c: C.graph, m: 'DiamondPlate' });
  body.box({ name: 'CabFrontLower', s: [8.2, 2.25, 0.4], p: [0, UB + 2.5 + 1.125 - 1.6, cz0 + 0.2], c: C.green });
  body.box({ name: 'CabFrontTop', s: [8.2, 0.75, 0.4], p: [0, 8.25 + 0.0, cz0 + 0.2], c: C.green });
  body.box({ name: 'WindshieldPillar', s: [0.35, 1.5, 0.45], p: [0, 7.1, cz0 + 0.2], c: C.graph });
  body.sym((s) => {
    s.box({ name: 'WindshieldPillar', s: [0.9, 1.5, 0.4], p: [3.65, 7.1, cz0 + 0.2], c: C.green });
    s.box({ name: 'Windshield', s: [3.0, 1.5, 0.1], p: [1.7, 7.1, cz0 + 0.12], c: C.glass, m: 'Glass', t: 0.35, refl: 0.2 });
    s.box({ name: 'Glint', s: [0.2, 1.2, 0.02], p: [2.2, 7.1, cz0 + 0.05], r: [0, 0, -25], c: '#ffffff', t: 0.6, shadow: false });
    for (const x of [0.95, 2.45]) s.box({ name: 'WindshieldArmorBar', s: [0.18, 1.5, 0.16], p: [x, 7.1, cz0 - 0.02], c: C.graph, m: 'Metal' });
    // side walls with window opening
    s.box({ name: 'CabSideLower', s: [0.4, 2.3, 3.6], p: [3.9, UB + 0.3 + 1.15, -5.2], c: C.green, studs: 'sides' });
    s.box({ name: 'CabSideFront', s: [0.4, 1.2, 1.0], p: [3.9, 7.35, -6.5], c: C.green });
    s.box({ name: 'CabSideBack', s: [0.4, 1.2, 0.8], p: [3.9, 7.35, -3.8], c: C.green });
    s.box({ name: 'CabSideTop', s: [0.4, 0.65, 3.6], p: [3.9, 8.27, -5.2], c: C.green });
    s.box({ name: 'SideWindow', s: [0.1, 1.2, 1.8], p: [4.02, 7.35, -5.1], c: C.glass, m: 'Glass', t: 0.35, refl: 0.2 });
    s.box({ name: 'SideWindowBar', s: [0.14, 1.2, 0.14], p: [4.08, 7.35, -5.1], c: C.graph, m: 'Metal' });
    // corner chamfer armor
    s.box({ name: 'CornerArmor', s: [0.8, 4.5, 0.8], p: [3.95, UB + 2.35, cz0 + 0.15], r: [0, 45, 0], c: C.greenLo });
    // door armor plate, handle, hinges
    s.box({ name: 'DoorArmor', s: [0.16, 1.7, 2.6], p: [4.17, UB + 1.35, -5.2], c: C.graphHi, m: 'Metal' });
    bolts(s, 4.27, UB + 1.35, -5.2, 2.3, 1.4, 3);
    s.box({ name: 'DoorHandle', s: [0.16, 0.18, 0.6], p: [4.28, 6.1, -4.3], c: C.black });
    s.tube([4.35, 4.9, -3.7], [4.35, 7.4, -3.7], 0.16, { name: 'GrabHandle', c: C.chrome, m: 'Metal' });
    // reinforced metal steps
    for (const [y, x] of [[3.05, 4.25], [3.95, 4.15]]) {
      s.box({ name: 'Step', s: [0.9, 0.18, 1.5], p: [x, y, -3.7], c: C.metal, m: 'DiamondPlate' });
      s.box({ name: 'StepEdge', s: [0.08, 0.18, 1.5], p: [x + 0.47, y, -3.7], c: C.orange });
    }
    s.box({ name: 'StepHanger', s: [0.12, 1.4, 0.12], p: [4.6, 3.6, -3.0], c: C.black });
    s.box({ name: 'StepHanger', s: [0.12, 1.4, 0.12], p: [4.6, 3.6, -4.4], c: C.black });
    // big truck mirror
    s.beam([4.1, 7.9, -6.6], [4.9, 7.6, -6.9], 0.14, 0.14, { name: 'MirrorArm', c: C.black });
    s.box({ name: 'Mirror', s: [0.25, 1.1, 0.55], p: [5.05, 7.3, -6.95], c: C.black });
    s.box({ name: 'MirrorGlass', s: [0.05, 0.95, 0.42], p: [5.0, 7.3, -6.66], r: [0, 0, 0], c: '#a9d6e5', m: 'Glass', refl: 0.3 });
  });
  body.box({ name: 'CabBack', s: [8.2, 4.4, 0.4], p: [0, UB + 0.3 + 2.2, cz1 - 0.2], c: C.green });
  body.box({ name: 'CabRoof', s: [8.6, 0.4, 4.0], p: [0, cTop - 0.2, -5.2], c: C.green, studs: 'top' });
  body.box({ name: 'Visor', s: [8.6, 0.25, 0.9], p: [0, 8.65, cz0 - 0.35], r: [-10, 0, 0], c: C.graph });
  body.box({ name: 'VisorLip', s: [8.6, 0.15, 0.15], p: [0, 8.5, cz0 - 0.8], c: C.orange });

  // Cab interior
  interior.box({ name: 'Dashboard', s: [7.0, 0.9, 0.9], p: [0, 5.6, -6.3], c: C.graph });
  interior.box({ name: 'DashTop', s: [7.0, 0.12, 1.0], p: [0, 6.1, -6.25], c: C.black });
  interior.box({ name: 'RadarScreen', s: [1.2, 0.8, 0.06], p: [0.2, 6.55, -6.4], r: [-15, 0, 0], c: '#3bd16f', m: 'Neon' });
  interior.box({ name: 'RadarScreenFrame', s: [1.35, 0.95, 0.05], p: [0.2, 6.55, -6.36], r: [-15, 0, 0], c: C.black });
  for (let i = 0; i < 3; i++) interior.box({ name: 'StatusLamp', s: [0.16, 0.16, 0.05], p: [1.4 + i * 0.3, 5.75, -5.84], c: C.amber, m: 'Neon' });
  interior.tube([-2.0, 5.5, -6.0], [-2.0, 6.25, -5.4], 0.16, { name: 'SteeringColumn', c: C.black });
  const sw = interior.at([-2.0, 6.32, -5.35], [-40, 0, 0]);
  sw.cyl({ name: 'SteeringWheel', axis: 'z', len: 0.12, d: 1.3, c: C.black });
  sw.cyl({ name: 'SteeringHub', axis: 'z', len: 0.18, d: 0.4, c: C.orange });
  interior.sym((s, side) => {
    s.box({ cls: side > 0 ? 'Seat' : 'VehicleSeat', name: side > 0 ? 'PassengerSeat' : 'DriverSeat', s: [1.8, 0.45, 1.6], p: [2.0, 5.15, -4.6], c: C.graphHi, m: 'Fabric', collide: true });
    s.box({ name: 'SeatBase', s: [1.4, 0.5, 1.2], p: [2.0, 4.7, -4.6], c: C.black });
    s.box({ name: 'SeatBack', s: [1.8, 2.0, 0.4], p: [2.0, 6.3, -3.85], r: [8, 0, 0], c: C.graphHi, m: 'Fabric' });
    s.box({ name: 'Headrest', s: [1.0, 0.55, 0.35], p: [2.0, 7.5, -3.75], r: [8, 0, 0], c: C.black, m: 'Fabric' });
  });
  interior.box({ name: 'CenterConsole', s: [1.2, 0.8, 1.8], p: [0, 4.85, -4.8], c: C.graph });
  // (2026-10-13) two jump seats behind the cab for riders (Carpool: the Titan carries you + 3)
  for (const [n, x] of [['PassengerSeat2', 2.0], ['PassengerSeat3', -2.0]]) {
    interior.box({ cls: 'Seat', name: n, s: [1.8, 0.45, 1.6], p: [x, 5.15, -1.6], c: C.graphHi, m: 'Fabric', collide: true });
    interior.box({ name: 'SeatBase', s: [1.4, 0.5, 1.2], p: [x, 4.7, -1.6], c: C.black });
    interior.box({ name: 'SeatBack', s: [1.8, 1.6, 0.4], p: [x, 6.1, -0.85], r: [8, 0, 0], c: C.graphHi, m: 'Fabric' });
  }

  // ---------------- Roof equipment ----------------
  // roof rack + floodlights + beacons + radar + antennas
  body.sym((s) => {
    s.tube([3.9, cTop + 0.4, -6.8], [3.9, cTop + 0.4, -3.6], 0.22, { name: 'RoofRackRail', c: C.black, m: 'Metal', extend: 0.2 });
    for (const z of [-6.8, -3.6]) s.tube([3.9, cTop, z], [3.9, cTop + 0.4, z], 0.2, { name: 'RoofRackPost', c: C.black, m: 'Metal' });
  });
  body.tube([-3.9, cTop + 0.4, -6.8], [3.9, cTop + 0.4, -6.8], 0.22, { name: 'RoofRackFront', c: C.black, m: 'Metal', extend: 0.2 });
  body.tube([-3.9, cTop + 0.4, -3.6], [3.9, cTop + 0.4, -3.6], 0.22, { name: 'RoofRackBack', c: C.black, m: 'Metal', extend: 0.2 });
  for (const x of [-2.7, -0.9, 0.9, 2.7]) {
    flood(equip, [x, cTop + 0.85, -6.9], { w: 1.1, h: 0.75, depth: 0.55, lens: C.warm, cage: true, name: 'RoofFloodlight' });
    equip.box({ name: 'FloodBracket', s: [0.2, 0.35, 0.2], p: [x, cTop + 0.45, -6.8], c: C.black });
  }
  equip.sym((s) => {
    s.box({ name: 'BeaconBase', s: [0.6, 0.2, 0.6], p: [3.5, cTop + 0.1, -3.9], c: C.black });
    const b = s.cyl({ name: 'HazardBeacon', axis: 'y', len: 0.55, d: 0.5, p: [3.5, cTop + 0.47, -3.9], c: C.amber, m: 'Neon' });
    b.tag('BlinkLight');
    s.cyl({ name: 'BeaconCap', axis: 'y', len: 0.1, d: 0.55, p: [3.5, cTop + 0.78, -3.9], c: C.black });
    s.tube([3.9, cTop + 0.4, -3.6], [4.0, cTop + 1.6, -3.0], 0.06, { name: 'ResearchAntenna', c: C.black });
    s.ball({ name: 'AntennaTip', d: 0.14, p: [4.0, cTop + 1.62, -3.0], c: C.orange });
  });
  equip.tube([-2.6, cTop, -3.8], [-2.8, cTop + 1.35, -3.4], 0.08, { name: 'ResearchAntenna', c: C.black });
  equip.box({ name: 'AntennaPod', s: [0.4, 0.3, 0.4], p: [-2.6, cTop + 0.15, -3.8], c: C.graphHi });
  // Rotating radar dish (Model with pivot part; spun by the showcase client)
  const radar = new Inst('Model', 'RadarDish');
  radar.tag('SpinRadar');
  equip.parent.add(radar);
  const rd = equip.into(radar).at([0, cTop, -4.7]);
  rd.cyl({ name: 'RadarBase', axis: 'y', len: 0.3, d: 1.0, p: [0, 0.15, 0], c: C.graphHi, m: 'Metal' });
  const pivot = rd.box({ name: 'RadarPivot', s: [0.3, 0.3, 0.3], p: [0, 0.5, 0], t: 1, shadow: false, c: '#ffffff' });
  radar.set('PrimaryPart', 'Ref', pivot);
  rd.cyl({ name: 'RadarMast', axis: 'y', len: 0.6, d: 0.25, p: [0, 0.6, 0], c: C.black });
  const dish = rd.at([0, 1.1, 0], [-20, 0, 0]);
  dish.cyl({ name: 'RadarDishPlate', axis: 'z', len: 0.12, d: 1.6, c: '#d9dcdf', m: 'Metal' });
  dish.cyl({ name: 'RadarDishRim', axis: 'z', len: 0.08, d: 1.7, p: [0, 0, 0.06], c: C.orange });
  dish.tube([0, 0, -0.05], [0, 0, -0.6], 0.07, { name: 'RadarFeed', c: C.black });
  dish.ball({ name: 'RadarHorn', d: 0.2, p: [0, 0, -0.62], c: C.amber, m: 'Neon' });

  // Exhaust stacks behind the cab
  body.sym((s) => {
    s.cyl({ name: 'ExhaustStack', axis: 'y', len: 5.6, d: 0.55, p: [3.55, 7.1, -3.0], c: C.chrome, m: 'Metal' });
    s.box({ name: 'HeatShield', s: [0.7, 2.2, 0.7], p: [3.55, 6.6, -3.0], c: C.black, m: 'DiamondPlate' });
    s.box({ name: 'RainCap', s: [0.6, 0.08, 0.6], p: [3.55, 9.95, -2.95], r: [-25, 0, 0], c: C.black });
    s.box({ name: 'StackClamp', s: [0.75, 0.2, 0.75], p: [3.55, 8.2, -3.0], c: C.orange });
    s.box({ name: 'StackClamp', s: [0.75, 0.2, 0.75], p: [3.55, 5.4, -3.0], c: C.orange });
  });

  // ---------------- Containment chamber ----------------
  const z0 = -2.6, z1 = 9.6, L = z1 - z0, zc = (z0 + z1) / 2;
  const top = 8.0;
  const winY0 = 5.8, winY1 = 7.2;
  const wins = [0.4, 3.5, 6.6];
  body.box({ name: 'ChamberFloor', s: [8.6, 0.3, L], p: [0, UB + 0.15, zc], c: C.metal, m: 'DiamondPlate' });
  body.box({ name: 'ChamberFront', s: [8.6, top - UB, 0.4], p: [0, (UB + top) / 2, z0 + 0.2], c: C.green, studs: 'sides' });
  body.box({ name: 'ChamberRoof', s: [8.8, 0.45, L + 0.2], p: [0, top + 0.22, zc], c: C.green, studs: 'top' });
  body.sym((s) => {
    s.box({ name: 'ChamberWallLower', s: [0.4, winY0 - UB, L], p: [4.1, (UB + winY0) / 2, zc], c: C.green, studs: 'sides' });
    s.box({ name: 'ChamberWallUpper', s: [0.4, top - winY1, L], p: [4.1, (winY1 + top) / 2, zc], c: C.green, studs: 'sides' });
    const posts = [[z0, wins[0] - 1.0], [wins[0] + 1.0, wins[1] - 1.0], [wins[1] + 1.0, wins[2] - 1.0], [wins[2] + 1.0, z1]];
    for (const [a, b] of posts) s.box({ name: 'ChamberWallPost', s: [0.4, winY1 - winY0, b - a], p: [4.1, (winY0 + winY1) / 2, (a + b) / 2], c: C.green });
    for (const z of wins) {
      s.box({ name: 'ObservationWindow', s: [0.1, winY1 - winY0, 2.0], p: [4.15, (winY0 + winY1) / 2, z], c: C.amberGlass, m: 'Glass', t: 0.5, refl: 0.1, shadow: false });
      s.box({ name: 'WindowFrame', s: [0.25, 0.22, 2.4], p: [4.32, winY1 + 0.05, z], c: C.graph, m: 'Metal' });
      s.box({ name: 'WindowFrame', s: [0.25, 0.22, 2.4], p: [4.32, winY0 - 0.05, z], c: C.graph, m: 'Metal' });
      for (const dz of [-1.08, 1.08]) s.box({ name: 'WindowFrame', s: [0.25, 1.6, 0.22], p: [4.32, (winY0 + winY1) / 2, z + dz], c: C.graph, m: 'Metal' });
      s.box({ name: 'WindowBar', s: [0.14, 1.4, 0.14], p: [4.3, (winY0 + winY1) / 2, z], c: C.graph, m: 'Metal' });
      s.box({ name: 'StatusIndicator', s: [0.08, 0.22, 0.22], p: [4.33, winY1 + 0.4, z + 0.8], c: C.amber, m: 'Neon' });
    }
    // orange accent band + angular armor skirt + roof edge chamfer
    s.box({ name: 'AccentBand', s: [0.06, 0.28, L], p: [4.32, 7.62, zc], c: C.orange });
    s.wedgeF({ name: 'RoofChamfer', s: [L + 0.2, 0.5, 0.5], p: [4.15, top + 0.7, zc], face: 'right', c: C.greenLo });
    s.wedgeF({ name: 'CabRoofChamfer', s: [4.0, 0.4, 0.4], p: [4.1, cTop + 0.2, -5.2], face: 'right', c: C.greenLo });
    // Armor skirt over the tandem wheels (angular trapezoid fender)
    s.box({ name: 'TandemFender', s: [1.3, 0.35, 6.4], p: [4.4, UB + 0.1, 5.15], c: C.graphHi, studs: 'top' });
    s.beam([4.4, UB + 0.1, 1.95], [4.4, 3.0, 1.15], 1.3, 0.35, { name: 'TandemFenderRamp', c: C.graphHi, extend: 0.3 });
    s.beam([4.4, UB + 0.1, 8.35], [4.4, 3.0, 9.15], 1.3, 0.35, { name: 'TandemFenderRamp', c: C.graphHi, extend: 0.3 });
    for (let i = 0; i < 4; i++) s.box({ name: 'FenderHazard', s: [0.04, 0.3, 0.45], p: [5.06, UB + 0.1, 2.6 + i * 1.7], r: [40, 0, 0], c: C.orange, shadow: false });
    s.box({ name: 'FrontFender', s: [1.3, 0.35, 3.6], p: [4.4, UB + 0.1, -6.4], c: C.graphHi, studs: 'top' });
    s.beam([4.4, UB + 0.1, -8.2], [4.4, 3.2, -8.8], 1.3, 0.35, { name: 'FrontFenderRamp', c: C.graphHi, extend: 0.3 });
    s.beam([4.4, UB + 0.1, -4.6], [4.4, 3.2, -4.0], 1.3, 0.35, { name: 'FrontFenderRamp', c: C.graphHi, extend: 0.3 });
    // side marker (orange hazard lighting)
    for (const z of [-1.5, 2.0, 5.2, 8.9]) s.box({ name: 'SideMarker', s: [0.1, 0.22, 0.4], p: [4.33, UB + 0.5, z], c: C.amber, m: 'Neon' });
    // hydraulic pistons for the rear doors
    piston(s, [4.55, 4.9, 7.4], [4.55, 7.55, 9.45]);
    // storage boxes on the hull between front wheel and tandem
    for (const [z, w] of [[-2.9, 1.4], [-0.6, 2.4]]) {
      s.box({ name: 'StorageBox', s: [1.3, 1.5, w], p: [3.65, 3.35, z], c: C.graph, m: 'Metal' });
      s.box({ name: 'StorageLid', s: [1.36, 0.2, w + 0.06], p: [3.65, 4.15, z], c: C.green });
      s.box({ name: 'StorageLatch', s: [0.12, 0.3, 0.3], p: [4.33, 3.75, z], c: C.orange });
      s.box({ name: 'StorageRib', s: [0.08, 1.2, 0.12], p: [4.32, 3.3, z - w / 2 + 0.2], c: C.black });
      s.box({ name: 'StorageRib', s: [0.08, 1.2, 0.12], p: [4.32, 3.3, z + w / 2 - 0.2], c: C.black });
    }
    // external fuel canisters (jerry cans in a rack on the chamber front corner)
    for (let i = 0; i < 2; i++) {
      const jc = s.at([4.55, 5.6, -1.8 + i * 0.75]);
      jc.box({ name: 'FuelCanister', s: [0.55, 1.1, 0.65], c: i ? C.red : C.orange });
      jc.box({ name: 'CanisterHandle', s: [0.4, 0.14, 0.5], p: [0, 0.62, 0], c: C.black });
      jc.cyl({ name: 'CanisterCap', axis: 'y', len: 0.14, d: 0.2, p: [0, 0.62, 0.22], c: C.black });
      jc.box({ name: 'CanisterX', s: [0.04, 0.8, 0.08], p: [0.29, 0, 0], r: [35, 0, 0], c: shade(i ? C.red : C.orange, 0.75) });
    }
    s.box({ name: 'CanisterRack', s: [0.7, 0.15, 1.7], p: [4.55, 4.98, -1.43], c: C.black });
    s.box({ name: 'CanisterStrap', s: [0.62, 0.1, 1.7], p: [4.55, 5.8, -1.43], c: C.black });
  });

  // TITAN lettering plates
  body.sym((s, side) => {
    const plate = s.box({ name: 'TitanPlate', s: [0.12, 1.15, 5.4], p: [4.36, 5.05, 3.4], c: C.graph });
    surfaceText(plate, side > 0 ? 'Right' : 'Left', 'TITAN', { color: C.orangeHi, font: 'Bangers', weight: 400, pps: 60, stroke: '#1a1b1e', strokeT: 3 });
  });

  // ---------------- Rear doors ----------------
  const dz = z1 + 0.18;
  body.sym((s) => {
    s.box({ name: 'RearDoor', s: [4.15, top - UB, 0.36], p: [2.12, (UB + top) / 2, dz], c: C.green, studs: 'sides' });
    s.box({ name: 'DoorArmorPanel', s: [3.2, 1.7, 0.14], p: [2.12, 5.3, dz + 0.24], c: C.graphHi, m: 'Metal' });
    for (const bx of [0.82, 2.12, 3.42]) for (const by of [4.6, 6.0]) s.cyl({ name: 'Bolt', axis: 'z', len: 0.08, d: 0.14, p: [bx, by, dz + 0.33], c: C.chrome, m: 'Metal' });
    s.box({ name: 'DoorWindow', s: [1.4, 0.9, 0.08], p: [2.4, 6.9, dz + 0.2], c: C.amberGlass, m: 'Glass', t: 0.45, shadow: false });
    s.box({ name: 'DoorWindowFrame', s: [1.6, 1.1, 0.06], p: [2.4, 6.9, dz + 0.17], c: C.graph });
    for (const y of [5.0, 6.9]) s.cyl({ name: 'DoorHinge', axis: 'y', len: 0.7, d: 0.32, p: [4.25, y, dz + 0.2], c: C.black, m: 'Metal' });
    s.cyl({ name: 'DoorHinge', axis: 'y', len: 0.7, d: 0.32, p: [4.25, 7.6, dz + 0.2], c: C.black, m: 'Metal' });
    stripes(s, [2.12, UB + 0.25, dz + 0.2], { len: 4.0, h: 0.4, n: 7, c1: C.orange, c2: C.black, d: 0.04 });
  });
  body.box({ name: 'DoorSeam', s: [0.08, top - UB, 0.42], p: [0, (UB + top) / 2, dz], c: C.black });
  for (const y of [5.9, 7.45]) {
    body.box({ name: 'LockingBar', s: [8.2, 0.26, 0.26], p: [0, y, dz + 0.36], c: C.graph, m: 'Metal' });
    body.box({ name: 'IndustrialClamp', s: [0.9, 0.6, 0.45], p: [0, y, dz + 0.45], c: C.orange });
    body.box({ name: 'ClampLever', s: [0.18, 0.8, 0.18], p: [0.35, y - 0.35, dz + 0.68], r: [0, 0, 20], c: C.black });
    body.sym((s) => {
      s.box({ name: 'BarGuide', s: [0.4, 0.45, 0.35], p: [3.6, y, dz + 0.4], c: C.black });
      s.box({ name: 'LockIndicator', s: [0.2, 0.2, 0.06], p: [0.75, y + 0.05, dz + 0.68], c: C.amber, m: 'Neon' });
    });
  }
  // Rear bumper + heavy metal step deck + lights
  body.box({ name: 'RearBumper', s: [8.8, 0.7, 1.0], p: [0, 3.2, 10.25], c: C.graph, studs: 'top' });
  body.box({ name: 'RearStepDeck', s: [5.0, 0.12, 0.95], p: [0, 3.6, 10.25], c: C.metal, m: 'DiamondPlate' });
  stripes(body, [0, 3.2, 10.77], { len: 8.4, h: 0.4, n: 12, c1: C.orange, c2: C.black });
  body.sym((s) => {
    s.box({ name: 'TailLight', s: [0.6, 0.6, 0.12], p: [3.9, 4.75, dz + 0.24], c: C.red, m: 'Neon' });
    s.box({ name: 'TailAmber', s: [0.6, 0.35, 0.12], p: [3.9, 5.3, dz + 0.24], c: C.amber, m: 'Neon' });
    s.box({ name: 'TailLightCage', s: [0.75, 1.15, 0.08], p: [3.9, 5.0, dz + 0.33], c: C.black, t: 0 });
    s.box({ name: 'Mudflap', s: [1.6, 1.4, 0.12], p: [4.05, 1.7, 9.0], c: C.black });
  });
  // Rear roof floodlights
  for (const x of [-2.6, 2.6]) flood(equip.at([0, 0, 0], [0, 180, 0]), [-x, top + 0.75, -(z1 - 0.3)], { w: 0.9, h: 0.6, depth: 0.45, lens: C.warm, name: 'RearFloodlight' });

  // Heavy-duty roof rack on the chamber
  body.sym((s) => {
    s.tube([3.9, top + 0.95, z0 + 0.5], [3.9, top + 0.95, z1 - 1.2], 0.24, { name: 'ChamberRackRail', c: C.black, m: 'Metal', extend: 0.2 });
    for (const z of [z0 + 0.5, 3.2, z1 - 1.2]) s.tube([3.9, top + 0.45, z], [3.9, top + 0.95, z], 0.22, { name: 'ChamberRackPost', c: C.black, m: 'Metal' });
  });
  for (const z of [z0 + 0.5, 1.5, 4.8, z1 - 1.2]) body.tube([-3.9, top + 0.95, z], [3.9, top + 0.95, z], 0.18, { name: 'ChamberRackBar', c: C.graphHi, m: 'Metal' });
  // rack cargo: crates, cable reel, spare tire
  for (const [x, z, s2] of [[-2.2, 0.2, 1.3], [-0.6, 0.4, 1.0]]) {
    equip.box({ name: 'SupplyCrate', s: [s2, s2 * 0.8, s2], p: [x, top + 0.45 + s2 * 0.4, z], c: '#7a6a45', m: 'WoodPlanks' });
    equip.box({ name: 'CrateBand', s: [s2 + 0.04, 0.12, s2 + 0.04], p: [x, top + 0.45 + s2 * 0.4, z], c: C.black });
  }
  equip.cyl({ name: 'CableReel', len: 1.4, d: 1.2, p: [2.0, top + 1.05, 0.4], c: C.orange });
  equip.cyl({ name: 'CableWound', len: 1.2, d: 1.05, p: [2.0, top + 1.05, 0.4], c: C.black });
  wheel(equip.at([0, top + 0.85, 6.0], [0, 0, 90]), [0, 0, 0], { name: 'SpareTire', d: 3.0, w: 0.9, tire: '#202124', rim: C.graphHi, rimAccent: C.orange, lugs: 12 });

  // ---------------- Chamber interior: egg storage ----------------
  const ein = eggs;
  ein.box({ name: 'InteriorBackdrop', s: [0.1, top - UB - 0.4, L - 0.6], p: [0, (UB + top) / 2, zc], c: C.greenDk });
  ein.box({ name: 'InteriorLightStrip', s: [0.4, 0.1, L - 1.0], p: [0, top - 0.06, zc], c: C.amber, m: 'Neon' });
  const lightHost = ein.box({ name: 'InteriorLight', s: [0.3, 0.3, 0.3], p: [0, top - 0.5, 3.5], t: 1, shadow: false, c: '#ffffff' });
  const pl = new Inst('PointLight', 'AmberGlow');
  pl.set('Color', 'Color3', [1, 0.72, 0.35]).set('Range', 'float', 14).set('Brightness', 'float', 1.4).set('Shadows', 'bool', false);
  lightHost.add(pl);
  const eggC = [['#f3ead2', '#7c9a3a'], ['#ffd8a8', '#c2410c'], ['#cfe7f0', '#0e7490'], ['#e9d5ff', '#7e22ce'], ['#fde68a', '#a16207'], ['#d1fae5', '#047857']];
  ein.sym((s, side) => {
    wins.forEach((z, i) => {
      s.box({ name: 'EggShelf', s: [1.6, 0.3, 1.9], p: [3.0, 5.0, z], c: C.graph, m: 'Metal' });
      s.box({ name: 'EggPadding', s: [1.3, 0.35, 1.5], p: [3.0, 5.32, z], c: C.pad, m: 'Fabric' });
      egg(s, [3.1, 6.15, z], { w: 1.0, h: 1.35, c: eggC[i + (side > 0 ? 0 : 3)][0], spot: eggC[i + (side > 0 ? 0 : 3)][1], seed: 40 + i * 3 + side });
      s.box({ name: 'EggClampArm', s: [0.18, 1.6, 0.18], p: [3.65, 6.2, z], c: C.black });
      s.box({ name: 'EggClampJaw', s: [0.7, 0.18, 0.4], p: [3.35, 6.95, z], c: C.orange });
      s.box({ name: 'EggStatus', s: [0.08, 0.2, 0.2], p: [3.8, 5.3, z + 0.7], c: C.amber, m: 'Neon' });
    });
  });

  // ---------------- Wheels ----------------
  const wo = { d: 3.8, w: 1.9, tire: '#202124', rim: C.graphHi, rimAccent: C.orange, hub: C.black, lugs: 14, spokes: 6 };
  const wl = wheels.clone({ mirrored: true });
  const names = ['Front', 'Middle', 'Rear'];
  AX.forEach((z, i) => {
    wheel(wheels, [4.05, 1.9, z], Object.assign({ name: `Wheel${names[i]}R` }, wo));
    wheel(wl, [4.05, 1.9, z], Object.assign({ name: `Wheel${names[i]}L` }, wo));
  });

  // ---------------- Details: claw marks, grime ----------------
  clawMarks(det.clone({ mirrored: true }), [4.28, 5.6, -5.0], { len: 1.8, ang: 30, gap: 0.32 });
  clawMarks(det, [4.33, 5.15, -0.2], { len: 2.2, ang: -28, gap: 0.36 });
  clawMarks(det.at([0, 0, 0], [0, -90, 0]), [dz + 0.36, 6.4, -2.9], { len: 1.6, ang: 35, gap: 0.3 });
  det.sym((s) => {
    for (let i = 0; i < 8; i++) s.box({ name: 'Grime', s: [0.04, 0.15 + R() * 0.3, 0.3 + R() * 0.8], p: [4.33, UB + 0.35 + R() * 0.5, -1.8 + R() * 11], r: [R() * 40 - 20, 0, 0], c: ['#5a4630', '#4a3a28'][i % 2], shadow: false });
  });

  return model;
}

module.exports = { build };
