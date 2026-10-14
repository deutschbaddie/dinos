// VEHICLE 1 — THE ROOKIE RANGER: battered safari research jeep (starter).
// Local frame: forward = -Z, up = +Y, origin = ground center. ~13 x 7 x 7.5 studs.
const { Inst, Ctx, CF, shade, rng, surfaceText } = require('../builder.js');
const { wheel, lamp, stripes, egg, mud, clawMarks } = require('./common.js');

const C = {
  yellow: '#f2b632', yellowHi: '#f7c95a', yellowLo: '#cf921f',
  green: '#2f6b3a', greenLo: '#234f2c', greenHi: '#3d8249',
  char: '#2b2d31', charHi: '#3c3f45', tan: '#c9a66b', tanLo: '#9e7e4c',
  metal: '#8c9399', glass: '#2f4750', light: '#fff2b8', amber: '#ffa21f', red: '#d6402b',
  wood: '#b07a45', woodLo: '#8a5a30', pad: '#e07b39', cream: '#f3ead2',
};

function build() {
  const model = new Inst('Model', 'RookieRanger');
  model.attr('DisplayName', 'Rookie Ranger').attr('Tier', 'Starter').attr('VehicleClass', 'Expedition Jeep');
  model.tag('DinoExpeditionVehicle');
  const root = new Ctx({ parent: model, frame: new CF(), defaults: { anchored: true } });
  const vroot = root.box({ name: 'VehicleRoot', s: [1, 1, 1], p: [0, 2.6, 0], t: 1, shadow: false, c: '#ffffff' });
  model.set('PrimaryPart', 'Ref', vroot);

  const body = root.group('Body');
  const wheels = root.group('Wheels');
  const interior = root.group('Interior');
  const equip = root.group('Equipment');
  const eggs = root.group('EggStorage');
  const det = root.group('Details');
  const R = rng(1201);

  // ---------------- Chassis ----------------
  body.box({ name: 'FrameRail', s: [3.4, 0.55, 11.6], p: [0, 1.85, 0.2], c: C.char });
  for (const z of [-4.0, 4.1]) body.cyl({ name: 'Axle', len: 5.2, d: 0.5, p: [0, 1.6, z], c: C.charHi, m: 'Metal' });
  body.sym((s) => {
    for (const z of [-4.0, 4.1]) {
      // Exaggerated lifted suspension: coil spring + shock
      for (let i = 0; i < 4; i++) s.cyl({ name: 'Spring', axis: 'y', len: 0.12, d: 0.62, p: [1.8, 1.95 + i * 0.22, z + 0.55], c: C.red, m: 'Metal' });
      s.cyl({ name: 'Shock', axis: 'y', len: 1.1, d: 0.3, p: [1.8, 2.3, z + 0.55], c: C.metal, m: 'Metal' });
    }
  });

  // ---------------- Body tub ----------------
  // Nose / engine bay (solid), sits above the front wheels
  body.box({ name: 'Nose', s: [6.0, 1.05, 3.4], p: [0, 4.075, -4.3], c: C.yellow, studs: 'top' });
  body.box({ name: 'NoseLower', s: [6.0, 0.95, 0.4], p: [0, 3.075, -5.8], c: C.yellow });
  // Hood: main panel, raised center bulge, front chamfer, trim
  body.box({ name: 'Hood', s: [5.8, 0.38, 3.0], p: [0, 4.79, -4.05], c: C.yellow, studs: 'top' });
  body.box({ name: 'HoodBulge', s: [2.2, 0.16, 2.8], p: [0, 5.06, -4.05], c: C.yellowHi });
  body.wedgeF({ name: 'HoodBulgeNose', s: [2.2, 0.16, 0.3], p: [0, 5.06, -5.6], face: 'front', c: C.yellowHi });
  body.wedgeF({ name: 'HoodChamfer', s: [5.8, 0.38, 0.45], p: [0, 4.79, -5.775], face: 'front', c: C.yellow });
  body.box({ name: 'HoodTrim', s: [6.04, 0.16, 0.16], p: [0, 4.62, -6.0], c: C.char });
  body.sym((s) => {
    s.wedgeF({ name: 'HoodSideChamfer', s: [3.0, 0.38, 0.3], p: [2.95, 4.79, -4.05], face: 'right', c: C.yellowLo });
    s.box({ name: 'HoodLatch', s: [0.12, 0.25, 0.3], p: [3.06, 4.55, -5.2], c: C.char });
    s.box({ name: 'HoodHinge', s: [0.5, 0.1, 0.2], p: [2.2, 5.0, -2.6], c: C.char });
  });

  // Cabin floor + side walls + tailgate (hollow open-top tub)
  body.box({ name: 'Floor', s: [4.0, 0.3, 8.5], p: [0, 2.85, 1.65], c: C.charHi, m: 'DiamondPlate' });
  body.sym((s) => s.box({ name: 'FloorSide', s: [0.6, 0.3, 4.4], p: [2.3, 2.85, 0.05], c: C.charHi, m: 'DiamondPlate' }));
  body.sym((s, side) => {
    s.box({ name: 'SideMid', s: [0.4, 2.3, 4.6], p: [2.8, 3.45, 0.05], c: C.yellow, studs: 'sides' });
    s.box({ name: 'SideRear', s: [0.4, 1.05, 3.55], p: [2.8, 4.075, 4.125], c: C.yellow, studs: 'sides' });
    s.box({ name: 'SideCap', s: [0.5, 0.14, 8.15], p: [2.8, 4.67, 1.82], c: C.greenLo });
    // inner wheel tubs over rear wheels
    s.box({ name: 'WheelTub', s: [0.6, 0.5, 3.4], p: [2.3, 3.55, 4.1], c: C.char });
    s.box({ name: 'WheelWellLiner', s: [0.1, 0.62, 3.4], p: [2.05, 3.31, 4.1], c: C.char });
    // door seams + handle + hinge
    s.box({ name: 'DoorSeam', s: [0.04, 2.1, 0.07], p: [3.01, 3.45, -2.15], c: C.yellowLo });
    s.box({ name: 'DoorSeam', s: [0.04, 2.1, 0.07], p: [3.01, 3.45, 0.55], c: C.yellowLo });
    s.box({ name: 'DoorHandle', s: [0.14, 0.16, 0.55], p: [3.07, 4.15, 0.1], c: '#141518' });
    for (const y of [3.0, 4.1]) s.box({ name: 'DoorHinge', s: [0.12, 0.3, 0.18], p: [3.05, y, -2.05], c: C.char });
    // rocker / side step
    s.box({ name: 'SideStep', s: [0.55, 0.22, 3.9], p: [3.15, 2.3, 0.05], c: C.char, m: 'DiamondPlate' });
    s.box({ name: 'StepBracket', s: [0.6, 0.35, 0.2], p: [2.95, 2.45, -1.6], c: C.char });
    s.box({ name: 'StepBracket', s: [0.6, 0.35, 0.2], p: [2.95, 2.45, 1.7], c: C.char });
    // Green fender flares (trapezoid arches) front & rear
    for (const z of [-4.0, 4.1]) {
      s.box({ name: 'FenderFlare', s: [0.7, 0.3, 2.3], p: [3.32, 3.68, z], c: C.green, studs: 'top' });
      s.beam([3.32, 3.68, z - 1.1], [3.32, 2.72, z - 1.8], 0.7, 0.3, { name: 'FenderFlare', c: C.green, extend: 0.25 });
      s.beam([3.32, 3.68, z + 1.1], [3.32, 2.72, z + 1.8], 0.7, 0.3, { name: 'FenderFlare', c: C.green, extend: 0.25 });
      for (const dz of [-0.8, 0, 0.8]) s.cyl({ name: 'FlareBolt', len: 0.08, d: 0.12, p: [3.7, 3.68, z + dz], c: C.metal, m: 'Metal' });
    }
    // Belt line trim stripe (two-tone)
    s.box({ name: 'BeltStripe', s: [0.04, 0.22, 12.0], p: [3.02, 4.25, 0.05], c: C.green });
  });
  // Tailgate
  body.box({ name: 'Tailgate', s: [6.0, 2.0, 0.4], p: [0, 3.6, 6.1], c: C.yellow, studs: 'sides' });
  body.box({ name: 'TailgateCap', s: [6.1, 0.14, 0.5], p: [0, 4.67, 6.1], c: C.greenLo });
  body.box({ name: 'TailgatePanel', s: [3.6, 1.2, 0.06], p: [0, 3.55, 6.33], c: C.yellowLo });
  body.box({ name: 'RearBumper', s: [6.4, 0.6, 0.65], p: [0, 2.55, 6.45], c: C.char });
  body.sym((s) => {
    s.box({ name: 'TailLight', s: [0.55, 0.42, 0.1], p: [2.45, 4.2, 6.34], c: C.red, m: 'Neon' });
    s.box({ name: 'TailLightFrame', s: [0.7, 0.56, 0.06], p: [2.45, 4.2, 6.31], c: C.char });
    s.box({ name: 'BumperEnd', s: [0.35, 0.7, 0.75], p: [3.15, 2.55, 6.45], c: C.charHi });
  });
  // Front fascia: grille housing + slats
  body.box({ name: 'GrilleHousing', s: [3.8, 1.6, 0.3], p: [0, 3.75, -6.1], c: C.char });
  for (let i = -3; i <= 3; i++) {
    if (i === 2) continue; // one slat missing — it's been through a lot
    body.box({ name: 'GrilleSlat', s: [0.26, 1.3, 0.14], p: [i * 0.5, 3.75, -6.3], c: i === 1 ? shade(C.metal, 0.9) : C.metal, m: 'Metal', r: i === 1 ? [0, 0, 7] : [0, 0, 0] });
  }
  body.box({ name: 'GrilleTopBar', s: [3.9, 0.18, 0.2], p: [0, 4.57, -6.25], c: C.charHi });
  body.sym((s, side) => {
    lamp(s, [2.35, 3.95, -6.15], { d: 0.95, name: 'Headlight', lens: C.light });
    s.box({ name: 'TurnSignal', s: [0.5, 0.25, 0.1], p: [2.35, 3.15, -6.05], c: C.amber, m: 'Neon' });
  });
  // Duct-tape X over the left headlight (battered charm)
  body.box({ name: 'DuctTape', s: [0.9, 0.16, 0.03], p: [-2.35, 3.95, -6.38], r: [0, 0, 35], c: '#b8b8b0', shadow: false });
  body.box({ name: 'DuctTape', s: [0.9, 0.16, 0.03], p: [-2.35, 3.95, -6.39], r: [0, 0, -35], c: '#a9a9a0', shadow: false });

  // Front bumper, bull bar, winch, plate
  body.box({ name: 'FrontBumper', s: [6.6, 0.75, 0.85], p: [0, 2.5, -6.42], c: C.char, studs: 'top' });
  body.box({ name: 'BumperEndL', s: [0.5, 0.75, 0.85], p: [-3.5, 2.5, -6.25], r: [0, -18, 0], c: C.charHi });
  body.box({ name: 'BumperEndR', s: [0.5, 0.75, 0.85], p: [3.48, 2.42, -6.2], r: [0, 24, -8], c: C.charHi }); // bent
  body.sym((s) => {
    s.tube([1.55, 2.85, -6.6], [1.55, 4.55, -6.6], 0.24, { name: 'BullBar', c: C.charHi, m: 'Metal' });
    s.tube([1.55, 4.55, -6.6], [0.0, 4.75, -6.6], 0.24, { name: 'BullBar', c: C.charHi, m: 'Metal', extend: 0.1 });
    lamp(s, [1.55, 4.95, -6.55], { d: 0.6, depth: 0.4, name: 'AuxLight', lens: '#fff8dc' });
    s.box({ name: 'TowHook', s: [0.18, 0.35, 0.35], p: [2.3, 2.05, -6.7], c: C.red });
  });
  body.cyl({ name: 'Winch', len: 1.3, d: 0.5, p: [0, 2.5, -6.95], c: C.charHi, m: 'Metal' });
  body.box({ name: 'WinchHook', s: [0.2, 0.3, 0.12], p: [0, 2.5, -7.25], c: C.red });
  const plate = body.box({ name: 'LicensePlate', s: [1.7, 0.5, 0.06], p: [0, 2.05, -6.88], c: C.cream });
  surfaceText(plate, 'Front', 'DINO-01', { color: '#234f2c', font: 'FredokaOne', pps: 80 });

  // Snorkel on the right side (expedition silhouette)
  body.tube([3.15, 3.9, -3.1], [3.15, 6.3, -2.85], 0.36, { name: 'Snorkel', c: C.char });
  body.box({ name: 'SnorkelHead', s: [0.55, 0.55, 0.8], p: [3.15, 6.45, -2.95], c: C.char });
  body.wedgeF({ name: 'SnorkelScoop', s: [0.55, 0.4, 0.35], p: [3.15, 6.53, -3.5], face: 'front', c: C.char });

  // Windshield (tilted back), green frame + tinted glass + glints
  const ws = body.at([0, 4.95, -2.55], [8, 0, 0]);
  ws.sym((s) => s.box({ name: 'APillar', s: [0.32, 1.95, 0.32], p: [2.75, 0.97, 0], c: C.green }));
  ws.box({ name: 'WindshieldTop', s: [5.82, 0.3, 0.34], p: [0, 1.9, 0], c: C.green });
  ws.box({ name: 'WindshieldBase', s: [5.82, 0.28, 0.36], p: [0, 0.14, 0], c: C.green });
  ws.box({ name: 'Windshield', s: [5.2, 1.5, 0.1], p: [0, 1.02, 0], c: C.glass, m: 'Glass', t: 0.4, refl: 0.15 });
  ws.box({ name: 'Glint', s: [0.16, 1.2, 0.02], p: [-1.4, 1.02, -0.07], r: [0, 0, -28], c: '#ffffff', t: 0.55, shadow: false });
  ws.box({ name: 'Glint', s: [0.08, 1.0, 0.02], p: [-1.05, 1.02, -0.07], r: [0, 0, -28], c: '#ffffff', t: 0.6, shadow: false });
  ws.sym((s) => s.cyl({ name: 'WiperPivot', axis: 'z', len: 0.1, d: 0.12, p: [1.2, 0.32, -0.2], c: C.char }));
  ws.box({ name: 'Wiper', s: [1.6, 0.06, 0.05], p: [-0.5, 0.36, -0.2], r: [0, 0, 8], c: '#141518' });
  ws.box({ name: 'Wiper', s: [1.6, 0.06, 0.05], p: [1.9, 0.36, -0.2], r: [0, 0, 8], c: '#141518' });

  // Side mirrors on the A-pillars
  body.sym((s) => {
    s.box({ name: 'MirrorArm', s: [0.6, 0.12, 0.12], p: [3.2, 5.25, -2.5], c: C.char });
    s.box({ name: 'Mirror', s: [0.18, 0.5, 0.62], p: [3.55, 5.35, -2.5], c: C.char });
    s.box({ name: 'MirrorGlass', s: [0.04, 0.4, 0.5], p: [3.66, 5.35, -2.5], c: '#a9d6e5', m: 'Glass', refl: 0.3 });
  });

  // Roll bar + safari roof rack
  const rackY = 6.85;
  body.sym((s) => {
    s.tube([2.7, 4.6, 0.6], [2.7, rackY, 0.6], 0.32, { name: 'RollBar', c: C.green, m: 'Metal' });
    s.tube([2.7, 4.7, 0.6], [2.7, 6.2, 2.0], 0.2, { name: 'RollBarBrace', c: C.green, m: 'Metal' });
    s.tube([2.7, 4.6, 5.6], [2.7, rackY, 5.6], 0.24, { name: 'RackPost', c: C.char, m: 'Metal' });
    s.tube([2.75, rackY, -2.4], [2.75, rackY, 5.75], 0.28, { name: 'RackRail', c: C.char, m: 'Metal', extend: 0.2 });
  });
  body.tube([-2.7, rackY, 0.6], [2.7, rackY, 0.6], 0.32, { name: 'RollBarTop', c: C.green, m: 'Metal', extend: 0.3 });
  for (const z of [-2.2, -0.8, 2.0, 3.6, 5.6]) body.tube([-2.75, rackY + 0.05, z], [2.75, rackY + 0.05, z], 0.16, { name: 'RackCrossbar', c: C.charHi, m: 'Metal' });
  // Rolled camping tarp with straps
  det.cyl({ name: 'RolledTarp', len: 3.8, d: 0.85, p: [0, rackY + 0.52, 3.0], c: C.tan, m: 'Fabric' });
  for (const x of [-1.2, 1.2]) det.cyl({ name: 'TarpStrap', len: 0.16, d: 0.9, p: [x, rackY + 0.52, 3.0], c: '#5a3d25', m: 'Fabric' });
  det.box({ name: 'TarpFlap', s: [3.0, 0.08, 0.5], p: [0, rackY + 0.15, 3.5], r: [-12, 0, 0], c: C.tanLo, m: 'Fabric' });
  // Jerry can on the rack
  det.box({ name: 'JerryCan', s: [0.9, 0.95, 0.5], p: [-1.6, rackY + 0.55, 5.0], c: C.green });
  det.box({ name: 'JerryCanHandle', s: [0.6, 0.12, 0.12], p: [-1.6, rackY + 1.08, 5.0], c: C.greenLo });
  det.cyl({ name: 'JerryCanCap', axis: 'y', len: 0.15, d: 0.2, p: [-1.35, rackY + 1.08, 5.0], c: C.char });
  // Amber warning beacon on the rack
  det.box({ name: 'BeaconBase', s: [0.75, 0.22, 0.75], p: [0, rackY + 0.2, -1.5], c: C.char });
  const beacon = det.cyl({ name: 'WarningBeacon', axis: 'y', len: 0.5, d: 0.55, p: [0, rackY + 0.56, -1.5], c: C.amber, m: 'Neon' });
  beacon.tag('BlinkLight');
  det.cyl({ name: 'BeaconCap', axis: 'y', len: 0.1, d: 0.6, p: [0, rackY + 0.86, -1.5], c: C.char });

  // Radio antenna (rear right), leaning back
  det.tube([2.6, 4.7, 5.9], [2.4, 7.55, 6.3], 0.06, { name: 'Antenna', c: '#1d1e21' });
  det.ball({ name: 'AntennaTip', d: 0.18, p: [2.4, 7.6, 6.3], c: C.red });
  det.box({ name: 'AntennaMount', s: [0.25, 0.2, 0.25], p: [2.6, 4.75, 5.9], c: C.char });

  // ---------------- Wheels ----------------
  const wOpt = { d: 3.2, w: 1.35, tire: '#26272b', rim: C.tan, rimAccent: C.yellow, lugs: 12 };
  const wctx = wheels;
  wheel(wctx, [2.9, 1.6, -4.0], Object.assign({ name: 'WheelFR' }, wOpt));
  wheel(wctx, [2.9, 1.6, 4.1], Object.assign({ name: 'WheelRR' }, wOpt));
  const wl = wctx.clone({ mirrored: true });
  wheel(wl, [2.9, 1.6, -4.0], Object.assign({ name: 'WheelFL' }, wOpt));
  wheel(wl, [2.9, 1.6, 4.1], Object.assign({ name: 'WheelRL' }, wOpt));
  // Spare tire on the tailgate (outer face toward the back)
  const spareMount = det.box({ name: 'SpareMount', s: [0.6, 0.6, 0.45], p: [0, 4.3, 6.5], c: C.char });
  wheel(wheels.at([0, 4.3, 7.0], [0, -90, 0]), [0, 0, 0], Object.assign({}, wOpt, { name: 'SpareTire', d: 2.5, w: 0.8, lugs: 10 }));
  void spareMount;

  // ---------------- Interior ----------------
  interior.box({ name: 'Dashboard', s: [5.2, 0.6, 0.75], p: [0, 4.35, -2.15], c: C.char });
  interior.box({ name: 'DashTop', s: [5.2, 0.12, 0.85], p: [0, 4.7, -2.1], c: C.tanLo, m: 'Fabric' });
  for (const x of [-1.75, -0.95]) interior.cyl({ name: 'Gauge', axis: 'z', len: 0.06, d: 0.32, p: [x, 4.4, -1.75], c: '#e8f0d0', m: 'Neon' });
  interior.box({ name: 'GloveBox', s: [1.0, 0.4, 0.05], p: [1.4, 4.3, -1.76], c: C.charHi });
  interior.tube([-1.35, 4.2, -1.9], [-1.35, 4.75, -1.35], 0.14, { name: 'SteeringColumn', c: '#141518' });
  const sw = interior.at([-1.35, 4.8, -1.3], [-35, 0, 0]);
  sw.cyl({ name: 'SteeringWheel', axis: 'z', len: 0.1, d: 1.0, c: '#141518' });
  sw.cyl({ name: 'SteeringHub', axis: 'z', len: 0.16, d: 0.32, c: C.green });
  interior.box({ name: 'GearStick', s: [0.1, 0.6, 0.1], p: [0, 3.35, -1.2], r: [-12, 0, 0], c: '#141518' });
  interior.ball({ name: 'GearKnob', d: 0.22, p: [0, 3.68, -1.27], c: C.tan });
  interior.box({ name: 'CenterConsole', s: [0.8, 0.45, 1.6], p: [0, 3.22, -0.9], c: C.char });
  interior.sym((s, side) => {
    const seatName = side > 0 ? 'PassengerSeat' : 'DriverSeat';
    const seat = s.box({ cls: side > 0 ? 'Seat' : 'VehicleSeat', name: seatName, s: [1.7, 0.42, 1.6], p: [1.35, 3.22, -0.75], c: C.tan, m: 'Fabric', collide: true });
    void seat;
    s.box({ name: 'SeatBase', s: [1.6, 0.25, 1.5], p: [1.35, 3.1, -0.75], c: C.char });
    s.box({ name: 'SeatBack', s: [1.7, 1.6, 0.36], p: [1.35, 4.15, 0.1], r: [10, 0, 0], c: C.tan, m: 'Fabric' });
    s.box({ name: 'SeatBackFrame', s: [1.8, 1.5, 0.2], p: [1.35, 4.12, 0.32], r: [10, 0, 0], c: C.char });
    s.box({ name: 'Headrest', s: [1.0, 0.5, 0.3], p: [1.35, 5.15, 0.3], r: [10, 0, 0], c: C.tanLo, m: 'Fabric' });
    s.box({ name: 'SeatStitch', s: [1.72, 0.05, 0.05], p: [1.35, 3.44, -0.75], c: C.tanLo });
  });

  // ---------------- Equipment (behind the seats) ----------------
  equip.box({ name: 'ResearchConsole', s: [2.6, 1.3, 0.8], p: [0, 3.65, 1.3], c: C.char });
  equip.box({ name: 'ConsoleScreen', s: [1.0, 0.6, 0.05], p: [-0.6, 3.85, 0.88], c: '#3bd16f', m: 'Neon' });
  equip.box({ name: 'ConsoleScreenFrame', s: [1.15, 0.75, 0.04], p: [-0.6, 3.85, 0.9], c: '#141518' });
  for (let i = 0; i < 3; i++) equip.cyl({ name: 'ConsoleKnob', axis: 'z', len: 0.1, d: 0.18, p: [0.35 + i * 0.32, 3.75, 0.88], c: [C.red, C.amber, C.tan][i] });
  equip.box({ name: 'ConsoleVent', s: [2.0, 0.08, 0.04], p: [0, 3.2, 0.89], c: '#141518' });
  equip.cyl({ name: 'RadioDish', axis: 'z', len: 0.12, d: 0.9, p: [0.9, 4.75, 1.4], r: [20, 0, 0], c: '#d6d9dc' });
  equip.tube([0.9, 4.3, 1.4], [0.9, 4.65, 1.4], 0.1, { name: 'RadioDishPost', c: C.char });
  equip.box({ name: 'Tracker', s: [0.7, 0.45, 0.5], p: [-0.7, 4.55, 1.35], c: C.green });
  equip.box({ name: 'TrackerScreen', s: [0.5, 0.25, 0.04], p: [-0.7, 4.6, 1.09], c: '#9cf0ff', m: 'Neon' });
  // Two wooden storage crates on the wheel tubs
  equip.sym((s) => {
    const cr = s.at([2.0, 4.3, 4.75], [0, 8, 0]);
    cr.box({ name: 'StorageCrate', s: [1.1, 1.1, 1.1], c: C.wood, m: 'WoodPlanks' });
    for (const y of [-0.45, 0.45]) cr.box({ name: 'CrateBand', s: [1.14, 0.14, 1.14], p: [0, y, 0], c: C.woodLo, m: 'Wood' });
    cr.box({ name: 'CrateStencil', s: [0.04, 0.4, 0.4], p: [-0.56, 0, 0], c: '#2b2216', shadow: false });
  });

  // ---------------- Egg storage: reinforced transport crate ----------------
  const ec = eggs.at([0, 3.0, 3.7]);
  // padded inner tray
  ec.box({ name: 'CratePadding', s: [2.6, 0.7, 2.3], p: [0, 0.5, 0], c: C.pad, m: 'Fabric' });
  // egg cups (2x2) + eggs in two of them
  const cups = [[-0.65, -0.55], [0.65, -0.55], [-0.65, 0.55], [0.65, 0.55]];
  cups.forEach(([x, z], i) => {
    ec.cyl({ name: 'EggCup', axis: 'y', len: 0.12, d: 0.95, p: [x, 0.9, z], c: shade(C.pad, 0.7), m: 'Fabric' });
    if (i === 0) egg(ec, [x, 1.4, z], { c: '#f3ead2', spot: '#6b8f3a', seed: 3 });
    if (i === 3) egg(ec, [x, 1.4, z], { c: '#cfe7f0', spot: '#3a6f8f', seed: 9 });
  });
  // thick metal frame: 4 posts + top & bottom rails
  for (const [x, z] of [[-1.35, -1.2], [1.35, -1.2], [-1.35, 1.2], [1.35, 1.2]]) ec.box({ name: 'CratePost', s: [0.28, 1.9, 0.28], p: [x, 0.95, z], c: C.charHi, m: 'Metal' });
  for (const y of [0.12, 1.85]) {
    for (const z of [-1.2, 1.2]) ec.box({ name: 'CrateRail', s: [2.9, 0.22, 0.24], p: [0, y, z], c: C.charHi, m: 'Metal' });
    for (const x of [-1.35, 1.35]) ec.box({ name: 'CrateRail', s: [0.24, 0.22, 2.6], p: [x, y, 0], c: C.charHi, m: 'Metal' });
  }
  // caution stripes on the crate front and back
  stripes(ec, [0, 0.42, -1.33], { len: 2.4, h: 0.32, n: 8 });
  stripes(ec, [0, 0.42, 1.33], { len: 2.4, h: 0.32, n: 8 });
  ec.sym((s) => stripes(s, [1.48, 0.42, 0], { len: 2.1, h: 0.32, n: 7, r: [0, 90, 0] }));
  // mechanical locking bars across the top
  for (const z of [-0.55, 0.55]) {
    ec.box({ name: 'LockBar', s: [2.9, 0.16, 0.2], p: [0, 2.02, z], c: C.metal, m: 'Metal' });
    ec.box({ name: 'LockLatch', s: [0.35, 0.3, 0.32], p: [1.25, 2.02, z], c: C.amber });
  }
  ec.box({ name: 'LockHandle', s: [0.12, 0.45, 0.12], p: [-1.25, 2.25, 0], c: C.red });
  ec.cyl({ name: 'StatusLight', axis: 'y', len: 0.1, d: 0.22, p: [0, 1.98, -1.2], c: '#5dff7a', m: 'Neon' });

  // ---------------- Details: mud, claw marks, patches ----------------
  det.sym((s) => {
    mud(s, R, { n: 9, x: 3.03, z0: -2.0, z1: 2.2, y0: 2.3, y1: 3.4 });
    mud(s, R, { n: 4, x: 3.03, z0: 4.3, z1: 5.8, y0: 3.55, y1: 4.0 });
  });
  for (let i = 0; i < 7; i++) det.box({ name: 'Mud', s: [0.3 + R() * 0.5, 0.15 + R() * 0.25, 0.04], p: [-2.8 + R() * 5.6, 2.35 + R() * 0.3, -6.86], r: [0, 0, R() * 50 - 25], c: ['#6b4a2e', '#7e5a38'][i % 2], shadow: false });
  for (let i = 0; i < 6; i++) det.box({ name: 'Mud', s: [0.3 + R() * 0.5, 0.15 + R() * 0.3, 0.04], p: [-2.8 + R() * 5.6, 2.75 + R() * 0.5, 6.32], r: [0, 0, R() * 50 - 25], c: ['#6b4a2e', '#5a3d25'][i % 2], shadow: false });
  // claw marks: driver door + right rear quarter + hood
  clawMarks(det.clone({ mirrored: true }), [3.03, 3.4, -0.9], { len: 1.5, ang: 35 });
  clawMarks(det, [3.03, 3.95, 4.4], { len: 1.2, ang: -30 });
  const hood = det.at([0.9, 5.0, -4.6], [0, 0, 0]);
  for (let i = -1; i <= 1; i++) hood.box({ name: 'ClawMark', s: [0.13, 0.03, 1.1], p: [1.0 + i * 0.28, 0, i * 0.06], r: [0, 28, 0], c: C.metal, m: 'Metal', shadow: false });
  // riveted repair patch on the left nose side
  const patch = det.clone({ mirrored: true });
  patch.box({ name: 'RepairPatch', s: [0.05, 0.75, 1.0], p: [3.03, 4.05, -4.6], r: [6, 0, 0], c: '#7d8288', m: 'Metal' });
  for (const [y, z] of [[0.28, 0.4], [-0.28, 0.4], [0.28, -0.4], [-0.28, -0.4]]) patch.cyl({ name: 'Rivet', len: 0.06, d: 0.1, p: [3.07, 4.05 + y, -4.6 + z], c: '#c0c4c8', m: 'Metal' });
  // tiny dino footprint decal on the hood bulge
  const fp = det.at([0, 5.15, -4.0]);
  fp.box({ name: 'FootprintDecal', s: [0.5, 0.02, 0.45], c: C.greenLo, shadow: false });
  for (const a of [-30, 0, 30]) fp.box({ name: 'FootprintToe', s: [0.14, 0.02, 0.45], p: [Math.sin(a * Math.PI / 180) * 0.4, 0, -0.38 * Math.cos(a * Math.PI / 180)], r: [0, -a, 0], c: C.greenLo, shadow: false });

  return model;
}

module.exports = { build };
