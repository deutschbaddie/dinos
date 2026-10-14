// ROVER KITS — every bolt-on part for build-your-own rovers, generated per body so each one fits that body exactly.
// Output: one Folder per body with Front / Rear / Roof / Wrap / Wheels kit models, all in the body template's own
// frame (forward = -Z, origin = ground centre). Rides.Apply (Luau) grafts them onto a fresh template clone.
//
// Paint roles (attributes) let the player's colours flow into the parts:
//   Paint = 'P' body colour, 'S' trim colour, 'R' rim colour, 'W' wrap colour; Shade = brightness factor.
const { Inst, Ctx, CF, rng } = require('../builder.js');
const { lamp, stripes } = require('./common.js');

const D = Math.PI / 180;
const DARK = '#1d1e21', DARK2 = '#2b2d31', STEEL = '#9aa0a6', CHROME = '#d4d8de', BONE = '#f1e6c8';

// ---------------------------------------------------------------------------------------------------------
// per-body fitting data (measured from the templates; see tools/gen/build.js --kits for the QC renders)
// ---------------------------------------------------------------------------------------------------------
const SPEC = {
  RookieRanger: {
    P: ['#f2b632', '#f7c95a', '#cf921f'], S: ['#2f6b3a', '#234f2c', '#3d8249'],
    slot: {
      Front: (i) => i._cf.z < -6.5,
      Rear: (i) => (i._cf.z > 6.45 && i._cf.y > 3.2) || /^Antenna/.test(i.name),
      Roof: (i) => i._cf.y > 6.95 && i._cf.z < -0.3 && Math.abs(i._cf.x) < 2.4,
    },
    front: { z: -6.85, y: 2.5, w: 6.6, top: 4.6 },
    rear: { top: 4.74, tailZ: 6.1, bz: 6.78, by: 2.55, w: 6.0 },
    roof: { y: 6.98, z: -1.5, w: 5.4 },
    sides: { zones: [
      { x: 3.05, z0: -6.0, z1: -2.6, y0: 3.6, y1: 4.6 },
      { x: 3.05, z0: -2.25, z1: 2.35, y0: 2.35, y1: 4.6 },
      { x: 3.05, z0: 2.35, z1: 5.9, y0: 3.6, y1: 4.6 },
    ], band: [3.6, 4.6] },
    hood: { y: 4.98, x: 2.8, z0: -5.55, z1: -2.75, bulge: { x: 1.1, y: 5.14, z0: -5.45, z1: -2.65 } },
    tail: { z: 6.37, x: 2.9, y0: 2.65, y1: 4.6 },
    stripeX: [0.25, 0.75],
  },
  RaptorRunner: {
    P: ['#ff7a1a', '#ff9d4d', '#d65c0b'], S: ['#1b1c1f', '#2a2c31'],
    slot: {
      Front: (i) => i._cf.z < -7.4,
      Rear: (i) => (i._cf.z > 7.2 && i._cf.y > 3.2) || /^Antenna/.test(i.name),
      Roof: (i) => i._cf.y > 7.2 && i._cf.z < -1.6 && Math.abs(i._cf.x) < 2.6 && !/Rack|RollBar|Windshield/.test(i.name),
    },
    front: { z: -7.75, y: 2.85, w: 6.8, top: 5.1 },
    rear: { top: 5.15, tailZ: 6.85, bz: 7.65, by: 2.75, w: 6.0 },
    roof: { y: 7.28, z: -2.3, w: 5.4 },
    sides: { zones: [
      { x: 3.08, z0: -6.7, z1: -2.75, y0: 3.85, y1: 4.95 },
      { x: 3.08, z0: -2.7, z1: 2.4, y0: 2.45, y1: 4.95 },
      { x: 3.08, z0: 2.55, z1: 6.6, y0: 3.85, y1: 4.95 },
    ], band: [3.85, 4.95] },
    hood: { y: 5.32, x: 2.75, z0: -6.6, z1: -2.85 },
    tail: { z: 7.1, x: 2.9, y0: 3.1, y1: 4.95 },
    stripeX: [1.3, 1.9],
  },
  TitanTransport: {
    P: ['#4a5d33', '#5c7340', '#38482a', '#2c3a21'], S: ['#d9642b', '#ec7b3e'],
    slot: {
      Front: (i) => i._cf.z < -10.55,
      Rear: (i) => i.name === 'RearFloodlight',
      Roof: (i) => (i._cf.y > 9.1 && i._cf.z > -7.6 && i._cf.z < -4.2 && Math.abs(i._cf.x) < 3.2 && !/RoofRack/.test(i.name)) || /^Radar/.test(i.name),
    },
    front: { z: -10.5, y: 3.0, w: 9.6, top: 6.2 },
    rear: { top: 8.45, tailZ: 9.6, bz: 10.75, by: 3.2, w: 8.8 },
    roof: { y: 9.02, z: -5.4, w: 7.4 },
    sides: { zones: [
      { x: 4.26, z0: -7.0, z1: -3.4, y0: 4.6, y1: 6.7 },
      { x: 4.43, z0: -2.6, z1: 9.6, y0: 4.3, y1: 5.8 },
      { x: 4.36, z0: -2.6, z1: 9.6, y0: 7.4, y1: 8.0 },
    ], band: [4.6, 5.8] },
    hood: { y: 6.8, x: 3.5, z0: -8.7, z1: -7.05 },
    roofStripes: [{ y: 8.45, z0: -2.4, z1: 9.6 }, { y: 9.02, z0: -7.1, z1: -3.3 }],
    stripeX: [0.9, 1.7],
  },
};

function role(p, r, f = 1) {
  p.attr('Paint', r);
  if (Math.abs(f - 1) > 1e-3) p.attr('Shade', +f.toFixed(3));
  return p;
}

// relative brightness of `hex` vs `base` as the Shade factor Rides.Apply uses (>1 lightens toward white)
function lum(h) { const n = parseInt(h.slice(1), 16); return (0.299 * (n >> 16) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255; }
function shadeOf(hex, base) {
  const a = lum(hex), b = lum(base);
  if (a >= b) return b >= 0.999 ? 1 : 1 + (a - b) / (1 - b);
  return b <= 0 ? 1 : a / b;
}

// tag the template: paint roles on body / trim / rim parts, KitSlot on the stock bits a kit replaces
function tagTemplate(t, name, launcherParts) {
  const sp = SPEC[name];
  if (!sp) return;
  const inWheel = new Set();
  t.walk((m) => { if (m.cls === 'Model' && (/^Wheel[A-Z]/.test(m.name) || m.name === 'SpareTire')) m.walk((i) => inWheel.add(i)); });
  const norm = (h) => h.toLowerCase();
  const P = sp.P.map(norm), S = sp.S.map(norm);
  t.walk((i) => {
    if (!i._preview || i._preview.t >= 1 || launcherParts.has(i)) return;
    const c = norm(i._preview.color);
    if (inWheel.has(i)) {
      const f = { Rim: 1, RimLip: 0.72, Spoke: 0.8, RimAccent: 1.15 }[i.name];
      if (f) role(i, 'R', f);
      return;
    }
    if (P.includes(c)) role(i, 'P', shadeOf(c, P[0]));
    else if (S.includes(c)) role(i, 'S', shadeOf(c, S[0]));
  });
  for (const [slot, fn] of Object.entries(sp.slot)) {
    t.walk((i) => {
      if (!i._cf || i.cls === 'Attachment' || !i._preview || launcherParts.has(i) || i.name === 'VehicleRoot') return;
      if (inWheel.has(i) && !(slot === 'Rear')) return;
      if (fn(i)) i.attr('KitSlot', slot);
    });
  }
  t.attr('StockP', sp.P[0].slice(1)).attr('StockS', sp.S[0].slice(1));
}

// ---------------------------------------------------------------------------------------------------------
// FRONT
// ---------------------------------------------------------------------------------------------------------
const FRONT = {
  RacerLip(c, F, pal) {
    c.box({ name: 'Splitter', s: [F.w + 0.3, 0.16, 1.2], p: [0, F.y - 0.42, F.z - 0.5], c: DARK });
    role(c.box({ name: 'SplitterEdge', s: [F.w + 0.34, 0.12, 0.16], p: [0, F.y - 0.42, F.z - 1.16], c: pal.P }), 'P');
    for (const x of [-0.3, -0.1, 0.1, 0.3]) c.box({ name: 'SplitterFin', s: [0.1, 0.34, 1.1], p: [x * F.w, F.y - 0.2, F.z - 0.5], c: DARK });
    c.sym((s) => {
      role(s.wedgeF({ name: 'Canard', s: [1.0, 0.12, 0.7], p: [F.w / 2 - 0.15, F.y + 0.15, F.z - 0.32], face: 'front', c: pal.P }), 'P');
      role(s.wedgeF({ name: 'Canard', s: [0.75, 0.12, 0.55], p: [F.w / 2 - 0.2, F.y + 0.45, F.z - 0.26], face: 'front', c: pal.P }), 'P', 0.85);
    });
    c.box({ name: 'LipLight', s: [F.w * 0.6, 0.08, 0.06], p: [0, F.y - 0.3, F.z - 1.1], c: '#c9f6ff', m: 'Neon' });
  },
  BullBar(c, F, pal) {
    const zb = F.z - 0.55, x1 = F.w * 0.3, yTop = F.top + 0.35;
    c.sym((s) => {
      role(s.tube([x1, F.y - 0.25, zb], [x1, yTop, zb], 0.36, { name: 'RhinoBar', c: pal.S, m: 'Metal', extend: 0.18 }), 'S');
      role(s.tube([x1, yTop, zb], [F.w / 2 - 0.05, F.y + 0.35, zb + 0.4], 0.3, { name: 'RhinoBar', c: pal.S, m: 'Metal', extend: 0.15 }), 'S');
      role(s.tube([x1, F.y + 0.75, zb], [F.w / 2 + 0.05, F.y + 0.6, zb + 0.35], 0.26, { name: 'RhinoBar', c: pal.S, m: 'Metal', extend: 0.1 }), 'S');
      lamp(s, [x1, yTop + 0.5, zb - 0.05], { d: 0.8, depth: 0.45, name: 'RhinoLamp', lens: '#fff6d0' });
      s.box({ name: 'BumpPad', s: [0.5, 0.8, 0.3], p: [x1, F.y + 0.25, zb - 0.3], c: '#141518' });
    });
    role(c.tube([-x1, yTop, zb], [x1, yTop, zb], 0.36, { name: 'RhinoBar', c: pal.S, m: 'Metal', extend: 0.36 }), 'S');
    role(c.tube([-x1, F.y + 1.05, zb], [x1, F.y + 1.05, zb], 0.28, { name: 'RhinoBar', c: pal.S, m: 'Metal' }), 'S');
    lamp(c, [0, yTop + 0.5, zb - 0.05], { d: 0.8, depth: 0.45, name: 'RhinoLamp', lens: '#fff6d0' });
    c.box({ name: 'SkidPlate', s: [F.w * 0.66, 0.2, 1.1], p: [0, F.y - 0.55, F.z - 0.5], r: [-12, 0, 0], c: STEEL, m: 'DiamondPlate' });
  },
  Plow(c, F, pal) {
    const ang = 22, H = 1.8, yc = F.y + 0.45, z0 = F.z - 1.7;
    const Lh = (F.w / 2 + 0.5) / Math.cos(ang * D);
    c.sym((s) => {
      const cx = Math.cos(ang * D) * Lh / 2, cz = Math.sin(ang * D) * Lh / 2;
      const b = s.at([cx, yc, z0 + cz], [0, -ang, 0]);
      role(b.box({ name: 'PlowBlade', s: [Lh, H, 0.3], c: pal.P }), 'P');
      role(b.box({ name: 'PlowTop', s: [Lh + 0.04, 0.26, 0.5], p: [0, H / 2 + 0.05, 0.05], c: pal.P }), 'P', 0.78);
      b.box({ name: 'PlowEdge', s: [Lh, 0.24, 0.44], p: [0, -H / 2 + 0.06, -0.06], c: STEEL, m: 'Metal' });
      stripes(b, [0, 0.2, -0.18], { len: Lh * 0.86, h: 0.46, n: 7 });
      for (let k = 0; k < 5; k++) b.box({ name: 'PlowTooth', s: [0.3, 0.3, 0.22], p: [-Lh / 2 + 0.4 + k * (Lh - 0.8) / 4, -H / 2 - 0.1, -0.06], r: [0, 0, 45], c: STEEL, m: 'Metal' });
      const ax = F.w * 0.24;
      s.tube([ax, F.y, F.z + 0.05], [ax, F.y + 0.3, z0 + Math.tan(ang * D) * ax + 0.2], 0.34, { name: 'PlowArm', c: DARK, m: 'Metal' });
      s.cyl({ name: 'PlowPiston', axis: 'z', len: 0.9, d: 0.22, p: [ax, F.y + 0.75, F.z - 0.45], c: CHROME, m: 'Metal' });
    });
    c.box({ name: 'PlowNose', s: [0.5, H + 0.1, 0.5], p: [0, yc, z0 - 0.05], r: [0, 45, 0], c: pal.P }).attr('Paint', 'P').attr('Shade', 0.85);
  },
  CrocJaw(c, F, pal) {
    const zj = F.z - 0.42;
    role(c.box({ name: 'JawUpper', s: [F.w + 0.2, 0.52, 0.84], p: [0, F.y + 0.62, zj], c: pal.P }), 'P', 0.72);
    role(c.box({ name: 'JawLower', s: [F.w + 0.2, 0.46, 0.92], p: [0, F.y - 0.5, zj - 0.04], c: pal.P }), 'P', 0.72);
    c.box({ name: 'JawMouth', s: [F.w - 0.1, 0.72, 0.2], p: [0, F.y + 0.06, F.z - 0.12], c: '#7a1f22' });
    const n = 9;
    for (let i = 0; i < n; i++) {
      const x = -F.w / 2 + 0.4 + i * (F.w - 0.8) / (n - 1);
      c.box({ name: 'Tooth', s: [0.28, 0.28, 0.24], p: [x, F.y + 0.3, zj - 0.22], r: [0, 0, 45], c: '#fbf6e6' });
      if (i < n - 1) c.box({ name: 'Tooth', s: [0.26, 0.26, 0.24], p: [x + (F.w - 0.8) / (n - 1) / 2, F.y - 0.18, zj - 0.26], r: [0, 0, 45], c: '#fbf6e6' });
    }
    c.sym((s) => {
      role(s.box({ name: 'CrocEyeBump', s: [0.8, 0.5, 0.7], p: [F.w / 2 - 0.65, F.y + 1.1, zj + 0.05], c: pal.P }), 'P', 0.85);
      s.box({ name: 'CrocEye', s: [0.46, 0.3, 0.08], p: [F.w / 2 - 0.65, F.y + 1.14, zj - 0.32], c: '#ffd21f', m: 'Neon' });
      s.box({ name: 'CrocPupil', s: [0.08, 0.28, 0.06], p: [F.w / 2 - 0.65, F.y + 1.14, zj - 0.37], c: '#111111' });
      s.box({ name: 'CrocNostril', s: [0.22, 0.12, 0.18], p: [0.45, F.y + 0.9, zj - 0.32], c: '#2a1414' });
      for (let k = 0; k < 3; k++) role(s.box({ name: 'CrocScale', s: [0.34, 0.16, 0.34], p: [F.w / 2 - 1.6 - k * 0.7, F.y + 0.94, zj + 0.05], r: [0, 45, 0], c: pal.P }), 'P', 0.6);
    });
  },
  TrikeRam(c, F, pal) {
    const zf = F.z - 0.45, k = F.w / 6.6;
    role(c.box({ name: 'Frill', s: [F.w * 0.9, 1.7 * k, 0.36], p: [0, F.y + 0.55 * k, zf], c: pal.P }), 'P', 0.9);
    const n = 7;
    for (let i = 0; i < n; i++) {
      const x = (i - (n - 1) / 2) * (F.w * 0.9 / n);
      role(c.box({ name: 'FrillSpike', s: [0.62 * k, 0.62 * k, 0.3], p: [x, F.y + 0.55 * k + 0.85 * k, zf], r: [0, 0, 45], c: pal.S }), 'S');
    }
    for (const [x, y] of [[-0.3, 0.5], [0.3, 0.5], [-0.12, 0.85], [0.12, 0.85]]) {
      role(c.cyl({ name: 'FrillSpot', axis: 'z', len: 0.08, d: 0.42 * k, p: [x * F.w, F.y + y * k, zf - 0.2], c: pal.S }), 'S');
    }
    const horn = (x0, y0, segs, d0, len, lift) => {
      let p = [x0, y0, zf - 0.15];
      const dir = [0, Math.sin(lift * D), -Math.cos(lift * D)];
      c.cyl({ name: 'HornBase', axis: 'z', len: 0.3, d: d0 + 0.18, p: [x0, y0, zf - 0.2], c: DARK2 });
      for (let i = 0; i < segs; i++) {
        const q = [p[0], p[1] + dir[1] * len, p[2] + dir[2] * len];
        c.tube(p, q, d0 * (1 - i / (segs + 0.6)), { name: 'Horn', c: i === segs - 1 ? '#fffaf0' : BONE, extend: 0.08 });
        p = q;
      }
    };
    horn(-F.w * 0.24, F.y + 1.0 * k, 4, 0.6 * k, 0.75 * k, 16);
    horn(F.w * 0.24, F.y + 1.0 * k, 4, 0.6 * k, 0.75 * k, 16);
    horn(0, F.y + 0.05 * k, 3, 0.5 * k, 0.5 * k, 8);
  },
};

// ---------------------------------------------------------------------------------------------------------
// REAR
// ---------------------------------------------------------------------------------------------------------
// where the boost trail streams from (the client prefers these over the body's own BoostFlame point)
function trailPoint(part, back) {
  const a = new Inst('Attachment', 'TrailPoint');
  a.set('CFrame', 'CFrame', part._cf.inv().mul(new CF(part._cf.x, part._cf.y, part._cf.z + back)));
  part.add(a);
}
const REAR = {
  Ducktail(c, R, pal) {
    role(c.wedgeF({ name: 'Ducktail', s: [R.w, 0.42, 0.8], p: [0, R.top + 0.21, R.tailZ + 0.12], face: 'front', c: pal.P }), 'P');
    c.sym((s) => role(s.box({ name: 'DucktailCap', s: [0.14, 0.5, 0.85], p: [R.w / 2 + 0.07, R.top + 0.23, R.tailZ + 0.12], c: pal.S }), 'S'));
  },
  TwinPipes(c, R) {
    c.sym((s) => {
      const x = R.w * 0.3, y = R.by - 0.12, z = R.bz + 0.45;
      s.cyl({ name: 'Pipe', axis: 'z', len: 1.6, d: 0.56, p: [x, y, z], c: CHROME, m: 'Metal' });
      s.cyl({ name: 'PipeHeat', axis: 'z', len: 0.12, d: 0.62, p: [x, y, z + 0.55], c: '#5b6cff', m: 'Metal' });
      const tip = s.cyl({ name: 'PipeTip', axis: 'z', len: 0.4, d: 0.72, p: [x, y, z + 0.95], c: CHROME, m: 'Metal' });
      s.cyl({ name: 'PipeHole', axis: 'z', len: 0.42, d: 0.48, p: [x, y, z + 0.96], c: '#111111' });
      s.box({ name: 'PipeHanger', s: [0.14, 0.5, 0.2], p: [x, y + 0.36, z - 0.3], c: DARK });
      trailPoint(tip, 0.25);
    });
  },
  GTWing(c, R, pal) {
    const y = R.top + 1.55, z = R.tailZ + 0.35;
    c.sym((s) => {
      role(s.box({ name: 'WingPost', s: [0.2, 1.6, 0.55], p: [R.w * 0.3, R.top + 0.78, R.tailZ + 0.18], r: [-12, 0, 0], c: pal.S }), 'S');
      role(s.box({ name: 'WingEndplate', s: [0.12, 0.85, 1.55], p: [R.w / 2 + 0.22, y - 0.1, z], c: pal.P }), 'P');
    });
    role(c.box({ name: 'Wing', s: [R.w + 0.32, 0.18, 1.25], p: [0, y, z], r: [7, 0, 0], c: pal.S }), 'S');
    role(c.box({ name: 'WingGurney', s: [R.w + 0.32, 0.24, 0.08], p: [0, y + 0.12, z + 0.62], c: pal.P }), 'P', 0.8);
  },
  DinoTail(c, R, pal) {
    const k = R.w / 6;
    let y = R.by + 0.4 * k, z = R.bz + 0.1;
    c.box({ name: 'TailMount', s: [1.3 * k, 0.9 * k, 0.5], p: [0, y, R.bz - 0.05], c: DARK });
    for (let i = 0; i < 6; i++) {
      const s = (1.05 - i * 0.14) * k;
      const len = 0.95 * k;
      const zc = z + len / 2;
      role(c.box({ name: 'TailSeg', s: [s, s * 0.85, len + 0.05], p: [Math.sin(i * 0.7) * 0.12 * k, y, zc], r: [-4 * i, 0, 0], c: pal.P }), 'P', 0.82);
      // stego plates: a diamond standing up on each segment
      if (i < 5) role(c.box({ name: 'TailPlate', s: [0.12, s * 0.75, s * 0.75], p: [0, y + s * 0.42 + s * 0.2, zc], r: [45, 0, 0], c: pal.S }), 'S');
      z += len;
      y += 0.14 * k;
    }
    for (const [dx, dy] of [[1, 1], [-1, 1], [1, -0.3], [-1, -0.3]]) c.tube([0, y, z - 0.3 * k], [dx * 0.9 * k, y + dy * 0.45 * k, z + 0.35 * k], 0.2 * k, { name: 'TailSpike', c: BONE });
  },
  // the Tidebreaker's reward: an outboard boat motor hung off the back, prop and all (boost streams from the prop)
  Outboard(c, R, pal) {
    const k = R.w / 6;
    const z = R.bz + 0.35, y = R.by + 0.9 * k;
    c.box({ name: 'OutboardMount', s: [0.9 * k, 0.5, 0.6], p: [0, R.by + 0.2, R.bz + 0.15], c: DARK });
    role(c.box({ name: 'OutboardCowl', s: [1.2 * k, 1.3 * k, 1.4 * k], p: [0, y + 0.65 * k, z + 0.6 * k], c: pal.P }), 'P');
    role(c.box({ name: 'OutboardCap', s: [1.26 * k, 0.3 * k, 1.46 * k], p: [0, y + 1.42 * k, z + 0.6 * k], c: pal.S }), 'S');
    c.box({ name: 'OutboardStripe', s: [1.22 * k, 0.16 * k, 1.42 * k], p: [0, y + 0.35 * k, z + 0.6 * k], c: '#f4fbff' });
    c.box({ name: 'OutboardLeg', s: [0.45 * k, 1.6 * k, 0.5 * k], p: [0, y - 0.6 * k, z + 0.75 * k], c: DARK2 });
    c.wedgeF({ name: 'OutboardSkeg', s: [0.12, 0.5 * k, 0.6 * k], p: [0, y - 1.62 * k, z + 0.85 * k], face: 'back', flip: true, c: DARK2 });
    const hub = c.cyl({ name: 'PropHub', axis: 'z', len: 0.5 * k, d: 0.42 * k, p: [0, y - 1.35 * k, z + 1.05 * k], c: STEEL, m: 'Metal' });
    for (const a of [0, 120, 240]) c.at([0, y - 1.35 * k, z + 1.3 * k], [0, 0, a]).box({ name: 'PropBlade', s: [0.16 * k, 0.7 * k, 0.08], p: [0, 0.36 * k, 0], r: [0, 25, 0], c: CHROME, m: 'Metal' });
    trailPoint(hub, 0.5 * k);
    c.box({ name: 'Tiller', s: [0.14, 0.14, 1.2 * k], p: [0.45 * k, y + 0.6 * k, z - 0.15], r: [10, 0, 0], c: DARK });
  },
  Rocket(c, R, pal) {
    c.sym((s) => {
      const x = R.w / 2 - 0.6, y = R.by + 0.15, z0 = R.bz - 0.55;
      role(s.cyl({ name: 'RocketBody', axis: 'z', len: 2.4, d: 1.0, p: [x, y, z0 + 1.2], c: pal.S }), 'S');
      role(s.cyl({ name: 'RocketBand', axis: 'z', len: 0.26, d: 1.05, p: [x, y, z0 + 0.95], c: pal.P }), 'P');
      s.cyl({ name: 'RocketNozzle', axis: 'z', len: 0.3, d: 0.82, p: [x, y, z0 + 2.55], c: '#3c3f45', m: 'Metal' });
      const bell = s.cyl({ name: 'RocketBell', axis: 'z', len: 0.32, d: 1.06, p: [x, y, z0 + 2.82], c: '#2b2d31', m: 'Metal' });
      s.cyl({ name: 'RocketGlow', axis: 'z', len: 0.34, d: 0.62, p: [x, y, z0 + 2.84], c: '#ff8a2a', m: 'Neon' });
      for (const a of [0, 120, 240]) role(s.at([x, y, z0 + 2.1], [0, 0, a]).box({ name: 'RocketFin', s: [0.08, 0.72, 0.8], p: [0, 0.75, 0], c: pal.P }), 'P', 0.9);
      s.box({ name: 'RocketStrap', s: [1.15, 0.16, 0.24], p: [x, y + 0.45, z0 + 0.5], c: DARK });
      trailPoint(bell, 0.2);
    });
  },
};

// ---------------------------------------------------------------------------------------------------------
// ROOF
// ---------------------------------------------------------------------------------------------------------
const ROOF = {
  LightBar(c, O) {
    const w = O.w * 0.84;
    c.box({ name: 'LightBarHousing', s: [w, 0.46, 0.55], p: [0, O.y + 0.42, O.z], c: DARK });
    const n = Math.round(w / 0.62);
    for (let i = 0; i < n; i++) c.box({ name: 'LightBarLED', s: [w / n - 0.1, 0.3, 0.06], p: [-w / 2 + (i + 0.5) * (w / n), O.y + 0.42, O.z - 0.29], c: '#fffbe8', m: 'Neon' });
    c.sym((s) => {
      s.box({ name: 'LightBarFoot', s: [0.3, 0.3, 0.5], p: [w / 2 - 0.4, O.y + 0.14, O.z], c: DARK2 });
      s.box({ name: 'LightBarEnd', s: [0.14, 0.46, 0.56], p: [w / 2 + 0.07, O.y + 0.42, O.z], c: '#ffa21f', m: 'Neon' });
    });
  },
  Dish(c, O) {
    const k = O.w / 5.4;
    c.box({ name: 'DishBase', s: [1.0 * k, 0.26, 1.0 * k], p: [0, O.y + 0.13, O.z], c: DARK2 });
    c.cyl({ name: 'DishMast', axis: 'y', len: 0.8 * k, d: 0.3 * k, p: [0, O.y + 0.26 + 0.4 * k, O.z], c: STEEL, m: 'Metal' });
    const hy = O.y + 0.3 + 1.25 * k;
    const d = c.at([0, hy, O.z], [-20, 0, 0]);
    d.cyl({ name: 'DishPlate', axis: 'z', len: 0.12, d: 1.9 * k, c: '#eceff2' }).attr('Spin', 1);
    d.cyl({ name: 'DishRim', axis: 'z', len: 0.1, d: 2.05 * k, p: [0, 0, 0.05], c: DARK2 }).attr('Spin', 1);
    d.cyl({ name: 'DishFeed', axis: 'z', len: 0.9 * k, d: 0.1, p: [0, 0, -0.45 * k], c: STEEL }).attr('Spin', 1);
    d.ball({ name: 'DishTip', d: 0.24, p: [0, 0, -0.92 * k], c: '#ff3b30', m: 'Neon' }).attr('Spin', 1);
    c.box({ name: 'DishHinge', s: [0.5 * k, 0.4 * k, 0.4 * k], p: [0, hy - 0.4 * k, O.z], c: DARK }).attr('Spin', 1);
  },
  Sirens(c, O) {
    const w = O.w * 0.74;
    c.box({ name: 'SirenBase', s: [w, 0.26, 0.66], p: [0, O.y + 0.2, O.z], c: DARK });
    c.box({ name: 'SirenRed', s: [w * 0.42, 0.46, 0.56], p: [-w * 0.27, O.y + 0.56, O.z], c: '#ff2a2a', m: 'Neon' });
    c.box({ name: 'SirenBlue', s: [w * 0.42, 0.46, 0.56], p: [w * 0.27, O.y + 0.56, O.z], c: '#2a6bff', m: 'Neon' });
    c.box({ name: 'SirenMid', s: [w * 0.12, 0.42, 0.52], p: [0, O.y + 0.54, O.z], c: '#f4f4f4' });
    c.box({ name: 'SirenCap', s: [w + 0.06, 0.08, 0.68], p: [0, O.y + 0.82, O.z], c: DARK2 });
  },
  DinoHead(c, O, pal) {
    const k = O.w / 5.4;
    const h = c.at([0, O.y, O.z]).scaled(k);
    role(h.box({ name: 'RexNeck', s: [1.3, 0.8, 1.3], p: [0, 0.4, 0.3], c: pal.S }), 'S', 0.85);
    role(h.box({ name: 'RexSkull', s: [2.0, 1.35, 2.1], p: [0, 1.3, -0.2], c: pal.S }), 'S');
    role(h.box({ name: 'RexSnout', s: [1.55, 0.85, 1.7], p: [0, 1.3, -1.9], c: pal.S }), 'S');
    role(h.box({ name: 'RexJaw', s: [1.45, 0.36, 2.2], p: [0, 0.62, -1.45], r: [-10, 0, 0], c: pal.S }), 'S', 0.8);
    h.box({ name: 'RexMouth', s: [1.25, 0.5, 1.8], p: [0, 0.83, -1.55], c: '#7a1f22' });
    for (let i = 0; i < 5; i++) {
      const z = -2.5 + i * 0.34;
      h.sym((s) => {
        s.box({ name: 'RexTooth', s: [0.16, 0.24, 0.16], p: [0.62, 0.78, z], r: [0, 0, 45], c: '#fbf6e6' });
        s.box({ name: 'RexTooth', s: [0.14, 0.2, 0.14], p: [0.58, 0.82, z + 0.17], r: [0, 0, 45], c: '#fbf6e6' });
      });
    }
    h.sym((s) => {
      role(s.box({ name: 'RexBrow', s: [0.55, 0.26, 0.95], p: [0.62, 2.02, -0.75], r: [0, 0, -10], c: pal.S }), 'S', 0.7);
      s.box({ name: 'RexEye', s: [0.08, 0.34, 0.4], p: [1.0, 1.6, -0.85], c: '#ffd21f', m: 'Neon' });
      s.box({ name: 'RexPupil', s: [0.06, 0.3, 0.1], p: [1.04, 1.6, -0.88], c: '#111111' });
      s.box({ name: 'RexNostril', s: [0.26, 0.16, 0.1], p: [0.42, 1.55, -2.76], c: '#2a1414' });
    });
    for (let i = 0; i < 4; i++) role(h.box({ name: 'RexSpine', s: [0.12, 0.42, 0.42], p: [0, 2.0 - i * 0.12, -0.4 + i * 0.32], r: [45, 0, 0], c: pal.P }), 'P', 0.9);
  },
  Crown(c, O) {
    const k = O.w / 5.4;
    const h = c.at([0, O.y, O.z]).scaled(k);
    const G = '#ffc824', GL = '#d99a12';
    const gems = ['#ff2a4a', '#2a8bff', '#2aff7a', '#b44aff'];
    const W = 2.2, T = 0.24;
    for (let i = 0; i < 4; i++) {
      const a = i * 90;
      const f = h.at([0, 0, 0], [0, a, 0]);
      f.box({ name: 'CrownBand', s: [W, 0.62, T], p: [0, 0.42, -W / 2 + T / 2], c: G, m: 'SmoothPlastic', refl: 0.3 });
      f.box({ name: 'CrownTrim', s: [W + 0.02, 0.12, T + 0.06], p: [0, 0.12, -W / 2 + T / 2], c: GL });
      for (const x of [-0.55, 0.55]) f.box({ name: 'CrownPoint', s: [0.55, 0.55, T], p: [x, 0.78, -W / 2 + T / 2], r: [0, 0, 45], c: G, refl: 0.3 });
      f.ball({ name: 'CrownBall', d: 0.24, p: [-0.55, 1.2, -W / 2 + T / 2], c: '#fff6d0' });
      f.ball({ name: 'CrownBall', d: 0.24, p: [0.55, 1.2, -W / 2 + T / 2], c: '#fff6d0' });
      f.box({ name: 'CrownGem', s: [0.36, 0.3, 0.08], p: [0, 0.42, -W / 2 - 0.02], r: [0, 0, 45], c: gems[i], m: 'Neon' });
    }
    h.box({ name: 'CrownVelvet', s: [W - 0.4, 0.4, W - 0.4], p: [0, 0.32, 0], c: '#9c1f3a', m: 'Fabric' });
  },
};

// ---------------------------------------------------------------------------------------------------------
// WHEELS: rims and tyres, built around each road wheel's hub (outer face +X; left wheels are mirrored)
// ---------------------------------------------------------------------------------------------------------
const RIM_BASE = { Steelie: '#2b2d31', Spoke: '#c3c8cf', Dish: '#e8eaed', Mesh: '#c9a64a', Star: '#d4d8de', Turbine: '#b8bec6', Claw: BONE };
function rim(c, style, d, w) {
  const base = RIM_BASE[style];
  const R = (p, f = 1) => role(p, 'R', f);
  const face = w / 2 + 0.1;
  R(c.cyl({ name: 'RimLip', len: w + 0.1, d: d * 0.62, c: base, m: 'SmoothPlastic' }), 0.78);
  const barrel = style === 'Dish' || style === 'Steelie';
  if (barrel) R(c.cyl({ name: 'Rim', len: w + 0.18, d: d * 0.56, c: base }));
  else c.cyl({ name: 'Rim', len: w + 0.14, d: d * 0.54, c: '#232427' });
  const spokes = (n, s, r0, off = 0, rot = 0) => {
    for (let i = 0; i < n; i++) {
      const a = (i / n) * 360 + off;
      const rad = a * D;
      R(c.at([face, Math.cos(rad) * r0, Math.sin(rad) * r0], [a + 90 + rot, 0, 0]).box({ name: 'Spoke', s, c: base }));
    }
  };
  if (style === 'Steelie') {
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * Math.PI * 2;
      c.cyl({ name: 'Spoke', len: 0.08, d: d * 0.09, p: [w / 2 + 0.06, Math.cos(a) * d * 0.17, Math.sin(a) * d * 0.17], c: '#111111' });
    }
    c.cyl({ name: 'RimAccent', len: w + 0.34, d: d * 0.17, c: CHROME, m: 'Metal' });
  } else if (style === 'Spoke') {
    spokes(5, [0.16, d * 0.1, d * 0.25], d * 0.15);
    R(c.cyl({ name: 'RimAccent', len: w + 0.34, d: d * 0.16, c: base }), 1.1);
  } else if (style === 'Dish') {
    R(c.cyl({ name: 'RimAccent', len: w + 0.24, d: d * 0.34, c: base }), 1.15);
    c.cyl({ name: 'RimAccent', len: w + 0.3, d: d * 0.12, c: DARK2 });
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2;
      c.cyl({ name: 'LugNut', len: 0.08, d: d * 0.045, p: [w / 2 + 0.14, Math.cos(a) * d * 0.1, Math.sin(a) * d * 0.1], c: CHROME, m: 'Metal' });
    }
  } else if (style === 'Mesh') {
    spokes(10, [0.1, d * 0.05, d * 0.26], d * 0.15);
    spokes(10, [0.08, d * 0.04, d * 0.2], d * 0.17, 18);
    R(c.cyl({ name: 'RimAccent', len: w + 0.3, d: d * 0.14, c: base }), 1.1);
  } else if (style === 'Star') {
    spokes(5, [0.16, d * 0.13, d * 0.13], d * 0.1);
    spokes(5, [0.14, d * 0.07, d * 0.15], d * 0.2);
    R(c.cyl({ name: 'RimAccent', len: w + 0.34, d: d * 0.17, c: base }), 1.12);
  } else if (style === 'Turbine') {
    spokes(9, [0.1, d * 0.2, d * 0.07], d * 0.17, 0, 35);
    R(c.cyl({ name: 'RimAccent', len: w + 0.36, d: d * 0.15, c: base }), 1.15);
    c.cyl({ name: 'RimAccent', len: w + 0.4, d: d * 0.06, c: '#111111' });
  } else if (style === 'Claw') {
    for (let i = 0; i < 3; i++) {
      const a0 = (i / 3) * 360;
      for (let j = 0; j < 3; j++) {
        const a = (a0 + j * 22) * D, r = d * (0.1 + j * 0.075);
        R(c.at([face, Math.cos(a) * r, Math.sin(a) * r], [a0 + j * 22 + 90 + 28 + j * 14, 0, 0]).box({ name: 'Spoke', s: [0.16, d * (0.1 - j * 0.022), d * 0.12], c: base }), 1 - j * 0.04);
      }
    }
    c.cyl({ name: 'RimAccent', len: w + 0.34, d: d * 0.16, c: DARK2 });
    c.cyl({ name: 'RimAccent', len: w + 0.38, d: d * 0.07, c: '#ff3030', m: 'Neon' });
  }
}

function tire(c, style, d, w) {
  const T = '#202124';
  const core = { Slick: 0.95, Knobby: 0.84, Mud: 0.84 }[style] || 0.88;
  const coreD = d * core;
  c.cyl({ name: 'Tire', len: style === 'Slick' ? w * 0.96 : w, d: coreD, c: T });
  c.cyl({ name: 'Sidewall', len: w + 0.06, d: d * 0.8, c: '#2a2b30' });
  if (style === 'Whitewall') c.cyl({ name: 'Sidewall', len: w + 0.08, d: d * 0.74, c: '#f4f2ea' });
  if (style === 'Redline') c.cyl({ name: 'Sidewall', len: w + 0.08, d: d * 0.71, c: '#e8322b' });
  if (style === 'Slick') c.cyl({ name: 'Sidewall', len: w + 0.08, d: d * 0.7, c: '#f2c230' });
  const ring = (n, fn) => { for (let i = 0; i < n; i++) { const a = (i / n) * 360; fn(a, a * D); } };
  const lugH = (d - coreD) / 2 + 0.04, r = coreD / 2 + lugH / 2 - 0.04;
  const at = (rad, rr) => [Math.cos(rad) * rr, Math.sin(rad) * rr];
  if (style === 'Whitewall' || style === 'Redline') {
    const n = 12, L = (Math.PI * coreD / n) * 0.55;
    ring(n, (a, rad) => { const [y, z] = at(rad, r); c.box({ name: 'Tread', s: [w * 0.94, lugH, L], p: [0, y, z], r: [a, 0, 0], c: T }); });
  } else if (style === 'Knobby') {
    const n = 14, L = (Math.PI * coreD / n) * 0.5;
    ring(n, (a, rad) => {
      const [y, z] = at(rad, r);
      c.box({ name: 'Tread', s: [w * 0.34, lugH, L], p: [0, y, z], r: [a, 0, 0], c: T });
      const [y2, z2] = at(rad + Math.PI / n, r);
      for (const sx of [-1, 1]) c.box({ name: 'Tread', s: [w * 0.28, lugH * 0.9, L], p: [sx * w * 0.34, y2, z2], r: [a + 180 / n, 0, 0], c: T });
    });
  } else if (style === 'Mud') {
    const n = 10, L = (Math.PI * coreD / n) * 0.62;
    ring(n, (a, rad) => {
      const off = (n && (Math.round(a / 36) % 2)) ? 0.24 : -0.24;
      const [y, z] = at(rad, r + 0.04);
      c.box({ name: 'Tread', s: [w * 0.6, lugH + 0.1, L], p: [off * w, y, z], r: [a, 0, 0], c: T });
      const [y2, z2] = at(rad, r);
      c.box({ name: 'Tread', s: [w * 0.34, lugH * 0.9, L * 0.8], p: [-off * w * 1.6, y2, z2], r: [a + 180 / n, 0, 0], c: T });
      // sidewall shoulder lugs
      const [y3, z3] = at(rad, d * 0.42);
      c.box({ name: 'Tread', s: [w + 0.12, 0.22, 0.34], p: [0, y3, z3], r: [a, 0, 0], c: '#28292d' });
    });
  }
}

// ---------------------------------------------------------------------------------------------------------
// WRAPS: flat decals laid on the side panels (both sides), the hood and the tail
// ---------------------------------------------------------------------------------------------------------
const INK = '#17181b';
function wrapKit(c, sp, id) {
  const Z = sp.sides.zones;
  const zf = Math.min(...Z.map((z) => z.z0)), zb = Math.max(...Z.map((z) => z.z1));
  const L = zb - zf;
  const [b0, b1] = sp.sides.band;
  const H = b1 - b0;
  const side = []; // { z0, z1, y0, y1, c, role, f, layer }
  const hood = []; // { x0, x1, z0, z1, ... }
  const tail = []; // { x0, x1, y0, y1, ... }
  const W = (o) => Object.assign({ c: '#ffffff', role: 'W', f: 1, layer: 0 }, o);
  const R = rng(9001 + id.length * 31);
  const SX = sp.stripeX;
  if (id === 'Stripe') {
    side.push(W({ z0: zf, z1: zb, y0: b0 + H * 0.38, y1: b0 + H * 0.72 }));
    side.push(W({ z0: zf, z1: zb, y0: b0 + H * 0.2, y1: b0 + H * 0.28, f: 0.85 }));
  } else if (id === 'Racing') {
    for (const sx of [1, -1]) {
      hood.push(W({ x0: sx > 0 ? SX[0] : -SX[1], x1: sx > 0 ? SX[1] : -SX[0], z0: -1e9, z1: 1e9 }));
      tail.push(W({ x0: sx > 0 ? SX[0] : -SX[1], x1: sx > 0 ? SX[1] : -SX[0], y0: -1e9, y1: 1e9 }));
    }
    side.push(W({ z0: zf, z1: zb, y0: b0 + H * 0.05, y1: b0 + H * 0.16 }));
  } else if (id === 'Checker') {
    const cell = H / 3;
    for (let row = 0; row < 2; row++) {
      for (let i = 0; i * cell < L; i++) {
        const on = (i + row) % 2 === 0;
        side.push(on ? W({ z0: zf + i * cell, z1: zf + (i + 1) * cell, y0: b0 + H * 0.3 + row * cell, y1: b0 + H * 0.3 + (row + 1) * cell })
          : { z0: zf + i * cell, z1: zf + (i + 1) * cell, y0: b0 + H * 0.3 + row * cell, y1: b0 + H * 0.3 + (row + 1) * cell, c: INK, layer: 0 });
      }
    }
    const hc = 0.5;
    for (let row = 0; row < 2; row++) for (let i = -8; i < 8; i++) {
      const on = (i + row) % 2 === 0;
      const r = { x0: i * hc, x1: (i + 1) * hc, z0: sp.hood.z0 + 0.15 + row * hc, z1: sp.hood.z0 + 0.15 + (row + 1) * hc };
      hood.push(on ? W(r) : Object.assign(r, { c: INK, layer: 0 }));
    }
  } else if (id === 'Spots') {
    const placed = [];
    const zoneArea = Z.map((z) => (z.z1 - z.z0) * (z.y1 - z.y0));
    const total = zoneArea.reduce((a, b) => a + b, 0);
    let tries = 0;
    while (placed.length < Math.round(total * 1.1) && tries++ < 4000) {
      let pick = R() * total, zi = 0;
      while (pick > zoneArea[zi]) { pick -= zoneArea[zi]; zi++; }
      const zn = Z[Math.min(zi, Z.length - 1)];
      const s = 0.24 + R() * 0.36;
      const z = zn.z0 + s / 2 + R() * (zn.z1 - zn.z0 - s), y = zn.y0 + s / 2 + R() * (zn.y1 - zn.y0 - s);
      if (placed.some((p) => Math.abs(p[0] - z) < (p[2] + s) / 2 + 0.25 && Math.abs(p[1] - y) < (p[2] + s) / 2 + 0.25)) continue;
      placed.push([z, y, s]);
      side.push(W({ z0: z - s / 2, z1: z + s / 2, y0: y - s / 2, y1: y + s / 2, f: R() < 0.5 ? 1 : 0.72 }));
    }
  } else if (id === 'Tiger') {
    for (let u = 0.6; u < L - 0.4; u += 1.25 + R() * 0.4) {
      const steps = 4 + Math.floor(R() * 2);
      const depth = H * (0.55 + R() * 0.4);
      for (let k = 0; k < steps; k++) {
        const w = 0.42 * (1 - k / (steps + 1)) + 0.08;
        const z = zf + u + k * 0.2;
        side.push(W({ z0: z, z1: z + w, y0: b1 - depth * (k + 1) / steps, y1: b1 - depth * k / steps + 0.02 }));
      }
    }
  } else if (id === 'Camo') {
    const tones = [[1, 0], [0.7, 1], [1.3, 2]];
    for (const zn of Z) {
      const n = Math.round((zn.z1 - zn.z0) * (zn.y1 - zn.y0) * 0.9) + 2;
      for (let i = 0; i < n; i++) {
        const [f, layer] = tones[i % 3];
        const z = zn.z0 + R() * (zn.z1 - zn.z0), y = zn.y0 + R() * (zn.y1 - zn.y0);
        const w = 0.6 + R() * 1.0, h = 0.35 + R() * 0.45;
        side.push(W({ z0: z - w / 2, z1: z + w / 2, y0: y - h / 2, y1: y + h / 2, f, layer }));
        side.push(W({ z0: z - w * 0.2, z1: z + w * 0.45, y0: y + h / 2 - 0.05, y1: y + h / 2 + h * 0.4, f, layer }));
      }
    }
  } else if (id === 'Lightning') {
    const s0 = zf + L * 0.3, s1 = zf + L * 0.64;
    const pts = [[0, 1.0], [0.45, 0.3], [0.3, 0.3], [0.78, -0.45], [0.6, -0.45], [1.0, -1.15]].map(([u, v]) => [s0 + u * (s1 - s0), b0 + v * H]);
    const th = H * 0.2;
    for (let i = 0; i < pts.length - 1; i++) {
      const [za, ya] = pts[i], [zb2, yb] = pts[i + 1];
      const n = Math.max(1, Math.ceil(Math.abs(zb2 - za) / 0.28));
      for (let k = 0; k < n; k++) {
        const t = (k + 0.5) / n;
        const z = za + (zb2 - za) * t, y = ya + (yb - ya) * t;
        const half = Math.abs(zb2 - za) / n / 2 + 0.02;
        const fat = th * (1 - (i + t) / pts.length * 0.5);
        side.push(W({ z0: z - half, z1: z + half, y0: y - fat, y1: y + fat }));
        side.push({ z0: z - half, z1: z + half, y0: y - fat * 0.3, y1: y + fat * 0.3, c: '#ffffff', layer: 1 });
      }
    }
  } else if (id === 'Flames') {
    const tongues = [[0.12, 0.34], [0.32, 0.46], [0.52, 0.4], [0.72, 0.52], [0.9, 0.3]];
    side.push(W({ z0: zf, z1: zf + 0.7, y0: b0, y1: b1 }));
    tongues.forEach(([v, len], ti) => {
      const total = L * len;
      const n = Math.ceil(total / 0.45);
      for (let k = 0; k < n; k++) {
        const t = k / n;
        const h = H * 0.2 * (1 - t * 0.85);
        const yc = b0 + H * v + Math.sin(t * 5 + ti) * H * 0.05;
        const z = zf + 0.6 + k * 0.45;
        side.push(W({ z0: z, z1: z + 0.47, y0: yc - h, y1: yc + h }));
        if (t < 0.7) side.push(W({ z0: z, z1: z + 0.47, y0: yc - h * 0.45, y1: yc + h * 0.45, f: 1.45, layer: 1 }));
      }
    });
    // flames licking back over the hood from the nose
    const hz = sp.hood.z0;
    [-0.62, -0.31, 0, 0.31, 0.62].forEach((xv, ti) => {
      const total = (sp.hood.z1 - hz) * (0.5 + 0.3 * Math.abs(Math.sin(ti * 1.7)));
      const n = Math.ceil(total / 0.4);
      for (let k = 0; k < n; k++) {
        const t = k / n, w = 0.36 * (1 - t * 0.8);
        const x = xv * sp.hood.x + Math.sin(t * 4 + ti) * 0.15;
        hood.push(W({ x0: x - w, x1: x + w, z0: hz + k * 0.4, z1: hz + k * 0.4 + 0.42 }));
        if (t < 0.6) hood.push(W({ x0: x - w * 0.45, x1: x + w * 0.45, z0: hz + k * 0.4, z1: hz + k * 0.4 + 0.42, f: 1.45, layer: 1 }));
      }
    });
  } else if (id === 'Tide') {
    // rolling waves along the lower sides, a white foam line on every crest, flecks of spray above
    const low = Math.min(...Z.map((z) => z.y0));
    const step = 0.3;
    for (let z = zf; z < zb; z += step) {
      const crest = b0 + H * (0.45 + 0.22 * Math.sin((z - zf) * 1.1));
      side.push(W({ z0: z, z1: z + step + 0.01, y0: low, y1: crest }));
      side.push({ z0: z, z1: z + step + 0.01, y0: crest - 0.02, y1: crest + 0.14, c: '#f4fbff', layer: 1 });
    }
    for (let i = 0; i < L * 0.8; i++) {
      const z = zf + R() * (L - 0.2), y = b0 + H * (0.72 + R() * 0.3);
      side.push({ z0: z, z1: z + 0.18, y0: y, y1: y + 0.14, c: '#f4fbff', layer: 0 });
    }
  } else if (id === 'Claws') {
    for (let i = 0; i < 3; i++) {
      const zs = zf + L * 0.4 + i * 0.75;
      const n = 12;
      for (let k = 0; k < n; k++) {
        const t = k / (n - 1);
        const z = zs + t * 1.6, y = b1 + H * 0.1 - t * H * 2.1;
        const th = H * 0.15 * Math.sin(Math.PI * (0.12 + t * 0.85));
        side.push(W({ z0: z - 0.16, z1: z + 0.16, y0: y - th - 0.03, y1: y + th + 0.03 }));
        side.push({ z0: z - 0.14, z1: z + 0.14, y0: y - th * 0.4, y1: y + th * 0.4, c: INK, layer: 1 });
      }
    }
  }
  // ---- emit: clip to the panels, lay it 0.02 off the paint (stacked layers step out so nothing z-fights)
  const deco = (o, s, p) => {
    const part = c.box({ name: 'Wrap', s, p, c: o.c || '#ffffff', shadow: false });
    if (o.role) role(part, o.role, o.f || 1);
  };
  for (const r of side) {
    for (const zn of Z) {
      const z0 = Math.max(r.z0, zn.z0), z1 = Math.min(r.z1, zn.z1), y0 = Math.max(r.y0, zn.y0), y1 = Math.min(r.y1, zn.y1);
      if (z1 - z0 < 0.06 || y1 - y0 < 0.06) continue;
      const x = zn.x + 0.02 + (r.layer || 0) * 0.016;
      for (const sx of [1, -1]) deco(r, [0.04, y1 - y0, z1 - z0], [sx * x, (y0 + y1) / 2, (z0 + z1) / 2]);
    }
  }
  const hd = sp.hood;
  for (const r of hood) {
    const segs = [];
    const b = hd.bulge;
    const x0 = Math.max(r.x0, -hd.x), x1 = Math.min(r.x1, hd.x);
    if (b) {
      // split across the bulge edge so each piece sits on its own surface
      const cuts = [x0, Math.max(x0, Math.min(x1, -b.x)), Math.max(x0, Math.min(x1, b.x)), x1];
      for (let i = 0; i < 3; i++) if (cuts[i + 1] - cuts[i] > 0.05) segs.push([cuts[i], cuts[i + 1], i === 1 ? b.y : hd.y, i === 1 ? [b.z0, b.z1] : [hd.z0, hd.z1]]);
    } else if (x1 - x0 > 0.05) segs.push([x0, x1, hd.y, [hd.z0, hd.z1]]);
    for (const [a0, a1, y, zr] of segs) {
      const z0 = Math.max(r.z0, zr[0]), z1 = Math.min(r.z1, zr[1]);
      if (z1 - z0 < 0.06) continue;
      deco(r, [a1 - a0, 0.04, z1 - z0], [(a0 + a1) / 2, y + 0.03 + (r.layer || 0) * 0.016, (z0 + z1) / 2]);
    }
  }
  if (sp.tail) {
    const t = sp.tail;
    for (const r of tail) {
      const x0 = Math.max(r.x0, -t.x), x1 = Math.min(r.x1, t.x), y0 = Math.max(r.y0, t.y0), y1 = Math.min(r.y1, t.y1);
      if (x1 - x0 < 0.06 || y1 - y0 < 0.06) continue;
      deco(r, [x1 - x0, y1 - y0, 0.04], [(x0 + x1) / 2, (y0 + y1) / 2, t.z + 0.02 + (r.layer || 0) * 0.016]);
    }
  }
  if (id === 'Racing' && sp.roofStripes) {
    for (const rs of sp.roofStripes) for (const sx of [1, -1]) {
      deco({ role: 'W' }, [SX[1] - SX[0], 0.04, rs.z1 - rs.z0], [sx * (SX[0] + SX[1]) / 2, rs.y + 0.03, (rs.z0 + rs.z1) / 2]);
    }
  }
}

// ---------------------------------------------------------------------------------------------------------
function buildKits(template, name) {
  const sp = SPEC[name];
  const root = new Inst('Folder', name);
  const pal = { P: sp.P[0], S: sp.S[0] };
  const group = (n) => { const g = new Inst('Folder', n); root.add(g); return g; };
  const ctxFor = (folder, id) => {
    const m = new Inst('Model', id);
    folder.add(m);
    return new Ctx({ parent: m, frame: new CF(), defaults: { anchored: true } });
  };
  const F = group('Front'), Rr = group('Rear'), Rf = group('Roof'), Wr = group('Wrap'), Wh = group('Wheels');
  for (const [id, fn] of Object.entries(FRONT)) fn(ctxFor(F, id), sp.front, pal);
  for (const [id, fn] of Object.entries(REAR)) fn(ctxFor(Rr, id), sp.rear, pal);
  for (const [id, fn] of Object.entries(ROOF)) fn(ctxFor(Rf, id), sp.roof, pal);
  for (const id of ['Stripe', 'Racing', 'Checker', 'Spots', 'Tiger', 'Camo', 'Lightning', 'Flames', 'Claws', 'Tide']) wrapKit(ctxFor(Wr, id), sp, id);
  // wheels: measure every road wheel on the template
  const wheels = [];
  template.walk((m) => {
    if (m.cls !== 'Model' || !/^Wheel[A-Z]/.test(m.name)) return;
    let hub = null, tireP = null;
    m.walk((i) => { if (i.name === 'Hub') hub = i; if (i.name === 'Tire') tireP = i; });
    if (!hub || !tireP) return;
    const w = tireP._preview.size[0], d = tireP._preview.size[1] / 0.88;
    wheels.push({ name: m.name, c: hub._cf.pos(), w, d });
  });
  const place = (folder, id, fn) => {
    const m = new Inst('Model', id);
    folder.add(m);
    for (const wh of wheels) {
      const wm = new Inst('Model', wh.name);
      m.add(wm);
      const base = new Ctx({ parent: wm, frame: new CF(), defaults: { anchored: true } });
      const right = wh.c[0] >= 0;
      const ctx = (right ? base : base.clone({ mirrored: true })).at([Math.abs(wh.c[0]), wh.c[1], wh.c[2]]);
      fn(ctx, wh.d, wh.w);
    }
  };
  for (const style of Object.keys(RIM_BASE)) place(Wh, 'Rim_' + style, (c, d, w) => rim(c, style, d, w));
  for (const style of ['Whitewall', 'Redline', 'Slick', 'Knobby', 'Mud']) place(Wh, 'Tire_' + style, (c, d, w) => tire(c, style, d, w));
  return root;
}

module.exports = { buildKits, tagTemplate, KIT_SPEC: SPEC };
