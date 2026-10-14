// Turns a showcase vehicle (anchored display model) into a drivable gameplay template:
//  - every part unanchored, welded to VehicleRoot (wheels ride on Motor6Ds so clients can spin/steer them)
//  - baked display eggs removed; EggSlot attachments mark where carried eggs are shown
//  - stats from the GDD as attributes
const B = require('./builder.js');
const { tagTemplate } = require('./vehicles/kits.js');
const { CF, Inst, Ctx } = B;

const STATS = {
  RookieRanger: { Price: 0, EggSlots: 2, Cruise: 42, Boost: 62, MaxHP: 100, Order: 1 },
  RaptorRunner: { Price: 2500, EggSlots: 3, Cruise: 50, Boost: 76, MaxHP: 160, Order: 2 },
  TitanTransport: { Price: 25000, EggSlots: 6, Cruise: 40, Boost: 58, MaxHP: 420, Order: 3 },
};

function buildTemplate(src, name) {
  const m = B.cloneTree(src);
  const st = STATS[name];
  for (const [k, v] of Object.entries(st)) m.attr(k, v);
  m.tags = ['DinoVehicleTemplate'];
  // showcase-only idle tags off the drivable copy: VehicleIdle PivotTo's a "SpinRadar" model every frame, and on a
  // welded rover that spun the whole Titan in circles (2026-10-13)
  m.walk((i) => { if (i !== m && i.tags) i.tags = i.tags.filter((t) => t !== 'SpinRadar'); });
  let root = null;
  m.walk((i) => { if (i.name === 'VehicleRoot') root = i; });
  // strip baked eggs; remember their spots as egg slots (sorted front to back / left to right)
  const spots = [];
  const kill = [];
  m.walk((i) => {
    if (i.name === 'Egg') { spots.push(i._cf.pos()); kill.push(i); }
    if (i.name === 'EggSpot') kill.push(i);
  });
  for (const k of kill) k.parent.children.splice(k.parent.children.indexOf(k), 1);
  // slots: reuse egg cups (empty ones too) when present, else the baked egg spots
  const cups = [];
  m.walk((i) => { if (/EggCup|EggCradle|EggPod|EggTube/.test(i.name) && i._cf) cups.push(i._cf.pos()); });
  let slots = cups.length >= st.EggSlots ? cups.map((p) => [p[0], p[1] + 0.55, p[2]]) : spots;
  slots = slots.slice().sort((a, b) => a[2] - b[2] || a[0] - b[0]).slice(0, st.EggSlots);
  while (slots.length < st.EggSlots) slots.push([0, 4.5, 3 + slots.length]);
  // (2026-10-13) the rack can hold up to Config.Rack.Max + the VIP pass = 8 eggs on ANY body (bought rack slots aren't
  // per rover), but only the body's own cups had attachments: the rest floated at the world origin. Extra slots go in
  // pairs behind the rack, stacking up a row if they'd run off the back of the rover.
  {
    const RACK_MAX = 8;
    const bb = B.bounds(m);
    const base = slots.slice();
    const y0 = Math.max(...base.map((q) => q[1]));
    const zBack = Math.max(...base.map((q) => q[2]));
    for (let k = 0; slots.length < RACK_MAX; k++) {
      const row = Math.floor(k / 2);
      let z = zBack + 2.4 * (row + 1), y = y0;
      const room = Math.floor((bb.max[2] - 0.8 - zBack) / 2.4);
      if (row >= room) { z = zBack - 2.4 * (row - Math.max(0, room)); y = y0 + 1.5; }
      slots.push([k % 2 ? 1.3 : -1.3, y, z]);
    }
  }
  slots.forEach((p, i) => {
    const a = new Inst('Attachment', 'EggSlot' + (i + 1));
    a.set('CFrame', 'CFrame', root._cf.inv().mul(new CF(...p)));
    root.add(a);
  });
  // a few useful attachments for VFX / camera
  const b = B.bounds(m);
  const att = (n, p) => { const a = new Inst('Attachment', n); a.set('CFrame', 'CFrame', root._cf.inv().mul(new CF(...p))); root.add(a); };
  att('Exhaust', [0, 2.2, b.max[2] - 0.3]);
  att('FrontBumper', [0, 2.6, b.min[2] + 0.3]);
  att('BoostFlame', [0, 2.4, b.max[2] + 0.4]);
  m.attr('RootHeight', +root._cf.y.toFixed(3));
  m.attr('Length', +b.size[2].toFixed(2)).attr('Width', +b.size[0].toFixed(2)).attr('Height', +b.size[1].toFixed(2));

  // tranq dart launcher: a swivel turret on the highest point behind the cabin (yaw driven by the client)
  {
    const zc = (b.min[2] + b.max[2]) / 2 + b.size[2] * 0.12;
    let top = 0;
    m.walk((i) => {
      if (!i._cf || !i._preview || i._preview.t >= 1 || i._isBone) return;
      const s = i._preview.size;
      if (/Antenna|Flag|Tip|Tarp|Strap|Crate|Lamp|Light|Jerry|Can|Spare|Tire|Tread|Rim|Hub|Beacon|Siren|Dish/.test(i.name)) return;
      // world AABB of the part (rotation-aware)
      const r = i._cf.r, h = s.map((v) => v / 2);
      const ext = [0, 1, 2].map((k) => h[0] * Math.abs(r[k * 3]) + h[1] * Math.abs(r[k * 3 + 1]) + h[2] * Math.abs(r[k * 3 + 2]));
      if (i._cf.x - ext[0] <= 0.6 && i._cf.x + ext[0] >= -0.6 && i._cf.z - ext[2] <= zc + 0.6 && i._cf.z + ext[2] >= zc - 0.6) top = Math.max(top, i._cf.y + ext[1]);
    });
    const L = new Ctx({ parent: m, frame: new CF(0, top, zc), defaults: { anchored: true } });
    const lg = L.group('DartLauncher');
    const base = lg.cyl({ name: 'LauncherBase', axis: 'y', len: 0.5, d: 1.8, p: [0, 0.25, 0], c: '#2b2d31', m: 'Metal' });
    lg.box({ name: 'Yoke', s: [1.4, 0.9, 0.5], p: [0, 0.9, 0], c: '#3c3f45', m: 'Metal' });
    lg.cyl({ name: 'Barrel', axis: 'z', len: 2.6, d: 0.5, p: [0, 1.25, -1.0], c: '#3c3f45', m: 'Metal' });
    lg.cyl({ name: 'BarrelTip', axis: 'z', len: 0.35, d: 0.62, p: [0, 1.25, -2.35], c: '#f08a24', m: 'Metal' });
    lg.cyl({ name: 'GasTank', axis: 'z', len: 1.6, d: 0.55, p: [0, 0.75, -0.4], c: '#b8bec4', m: 'Metal' });
    lg.box({ name: 'Scope', s: [0.35, 0.35, 0.9], p: [0.42, 1.6, -0.6], c: '#1d1e21' });
    lg.box({ name: 'ScopeLens', s: [0.28, 0.28, 0.05], p: [0.42, 1.6, -1.07], c: '#5fd35a', m: 'Neon' });
    lg.box({ name: 'Magazine', s: [0.5, 0.6, 1.0], p: [-0.45, 1.05, -0.3], c: '#2f6b3a' });
    for (let k = 0; k < 3; k++) lg.box({ name: 'DartTip', s: [0.12, 0.12, 0.3], p: [-0.45, 1.45, -0.65 + k * 0.32], c: '#3fe0c8', m: 'Neon' });
    lg.box({ name: 'Grip', s: [0.25, 0.6, 0.25], p: [0, 0.75, 0.55], r: [15, 0, 0], c: '#1d1e21' });
    const muzzle = new Inst('Attachment', 'Muzzle');
    muzzle.set('CFrame', 'CFrame', base._cf.inv().mul(new CF(0, top + 1.25, zc - 2.6)));
    base.add(muzzle);
    lg.parent.attr('MountY', +top.toFixed(2));
    m._launcherBase = base;
  }

  // physics: drop old welds; one root, everything else welded (wheels via Motor6D to their hub)
  m.walk((i) => { i.children = i.children.filter((c) => c.cls !== 'Weld'); });
  const wheelModels = [];
  m.walk((i) => { if (i.cls === 'Model' && /^Wheel(F|R|Front|Middle|Rear)[LR]$/.test(i.name)) wheelModels.push(i); });
  const inWheel = new Map();
  for (const w of wheelModels) w.walk((i) => { if (i._cf) inWheel.set(i, w); });
  for (const w of wheelModels) {
    let hub = null;
    w.walk((i) => { if (i.name === 'Hub') hub = i; });
    const mo = new Inst('Motor6D', w.name);
    mo.set('Part0', 'Ref', root);
    mo.set('Part1', 'Ref', hub);
    // the joint frame sits at the hub centre, axle along X
    const pivot = new CF(...hub._cf.pos());
    mo.set('C0', 'CFrame', root._cf.inv().mul(pivot));
    mo.set('C1', 'CFrame', hub._cf.inv().mul(pivot));
    root.add(mo);
    w.attr('Front', /^WheelF/.test(w.name)).attr('Radius', +(B.bounds(w).size[1] / 2).toFixed(2));
  }
  const lb = m._launcherBase;
  const launcherParts = new Set();
  m.find('DartLauncher').walk((i) => { if (i._cf && i.cls !== 'Attachment') launcherParts.add(i); });
  {
    const mo = new Inst('Motor6D', 'LauncherYaw');
    mo.set('Part0', 'Ref', root).set('Part1', 'Ref', lb);
    const pivot = new CF(...lb._cf.pos());
    mo.set('C0', 'CFrame', root._cf.inv().mul(pivot)).set('C1', 'CFrame', lb._cf.inv().mul(pivot));
    root.add(mo);
  }
  m.walk((i) => {
    if (!i._cf || i.cls === 'Attachment' || i === root) return;
    if (!i.props.Anchored) return;
    i.props.Anchored[1] = false;
    i.set('Massless', 'bool', true);
    i.set('CanQuery', 'bool', false);
    if (i.cls !== 'Seat' && i.cls !== 'VehicleSeat') { i.props.CanCollide[1] = false; i.props.CanTouch[1] = false; }
    const w = inWheel.get(i);
    let to = root;
    if (launcherParts.has(i)) { if (i === lb) return; to = lb; }
    if (w) { w.walk((q) => { if (q.name === 'Hub') to = q; }); if (to === i) return; }
    const wd = new Inst('Weld', 'Weld');
    wd.set('Part0', 'Ref', to).set('Part1', 'Ref', i);
    wd.set('C0', 'CFrame', to._cf.inv().mul(i._cf)).set('C1', 'CFrame', new CF());
    i.add(wd);
  });
  root.props.Anchored[1] = false;
  root.set('CanCollide', 'bool', false).set('CanQuery', 'bool', false).set('CanTouch', 'bool', false);
  // a sturdy invisible chassis keeps a sane centre of mass for the AlignPosition drive
  root.set('size', 'Vector3', [4, 1, 8]);
  root._preview.size = [4, 1, 8];
  // seats: don't let them be sat on by touch; the server seats the driver
  m.walk((i) => {
    if (i.cls === 'VehicleSeat') { i.set('MaxSpeed', 'float', 0).set('Torque', 'float', 0).set('HeadsUpDisplay', 'bool', false); i.props.CanTouch[1] = false; }
    if (i.cls === 'Seat') { i.set('Disabled', 'bool', true); i.props.CanTouch[1] = false; }
  });
  // build-your-own: paint roles + which stock bits each kit slot replaces
  tagTemplate(m, name, launcherParts);
  return m;
}

module.exports = { buildTemplate, VEHICLE_STATS: STATS };
