// Shared vehicle building blocks: wheels, lamps, hazard stripes, eggs, grime.
const { Inst, shade, rng } = require('../builder.js');

// Wheel authored for the RIGHT side (outer face +X). Use ctx.sym() for left wheels.
// o: { name, d, w, tire, rim, rimAccent, hub, lugs, style:'block'|'chevron'|'paddle', spokes }
function wheel(ctx, center, o) {
  const model = new Inst('Model', o.name);
  ctx.parent.add(model);
  const c = ctx.into(model).at(center);
  const d = o.d, w = o.w;
  const tire = o.tire || '#26272b';
  const coreD = d * 0.88;
  c.cyl({ name: 'Tire', len: w, d: coreD, c: tire, m: 'SmoothPlastic' });
  // Sidewall ring (slightly proud of the tread face)
  c.cyl({ name: 'Sidewall', len: w + 0.06, d: d * 0.8, c: shade(tire, 1.18), m: 'SmoothPlastic' });
  // Tread lugs
  const n = o.lugs || 12;
  const lugH = (d - coreD) / 2 + 0.04;
  const r = coreD / 2 + lugH / 2 - 0.04;
  const lugL = (Math.PI * coreD / n) * 0.55;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * 360;
    const rad = (a * Math.PI) / 180;
    const pos = (rr) => [0, Math.cos(rad) * rr, Math.sin(rad) * rr];
    if (o.style === 'chevron') {
      // two staggered half lugs for a deep off-road tread
      const off = i % 2 ? 0.22 : -0.22;
      const p = pos(r);
      c.box({ name: 'Tread', s: [w * 0.55, lugH, lugL], p: [off * w, p[1], p[2]], r: [a, 0, 0], c: tire });
      const p2 = pos(r);
      c.box({ name: 'Tread', s: [w * 0.3, lugH * 0.85, lugL * 0.8], p: [-off * w * 1.6, p2[1], p2[2]], r: [a + 180 / n, 0, 0], c: tire });
    } else {
      c.box({ name: 'Tread', s: [w * 0.94, lugH, lugL], p: pos(r), r: [a, 0, 0], c: tire });
    }
  }
  // Rim
  const rim = o.rim || '#c9a66b';
  c.cyl({ name: 'RimLip', len: w + 0.1, d: d * 0.6, c: shade(rim, 0.72), m: 'Metal' });
  c.cyl({ name: 'Rim', len: w + 0.16, d: d * 0.52, c: rim, m: 'SmoothPlastic' });
  if (o.rimAccent) c.cyl({ name: 'RimAccent', len: w + 0.18, d: d * 0.4, c: o.rimAccent, m: o.rimAccentM || 'SmoothPlastic' });
  // Hub (PrimaryPart) + spokes + lug nuts on the outer face
  const hub = c.cyl({ name: 'Hub', len: w + 0.3, d: d * 0.2, c: o.hub || '#3a3c41', m: 'Metal' });
  model.set('PrimaryPart', 'Ref', hub);
  const face = w / 2 + 0.1;
  const spokes = o.spokes || 5;
  for (let i = 0; i < spokes; i++) {
    const a = (i / spokes) * 360 + 90;
    const rad = (a * Math.PI) / 180;
    const rr = d * 0.16;
    c.box({ name: 'Spoke', s: [0.1, d * 0.07, d * 0.2], p: [face, Math.cos(rad) * rr, Math.sin(rad) * rr], r: [a + 90, 0, 0], c: shade(rim, 0.8) });
    const nr = d * 0.075;
    c.cyl({ name: 'LugNut', len: 0.12, d: d * 0.045, p: [face + 0.12, Math.cos(rad + 0.6) * nr, Math.sin(rad + 0.6) * nr], c: '#9aa0a6', m: 'Metal' });
  }
  return model;
}

// Round lamp facing -Z (front) in ctx space; returns lens part
function lamp(ctx, p, o = {}) {
  const d = o.d || 0.9;
  const facing = o.facing || 'front';
  const r = { front: [0, 0, 0], back: [0, 180, 0], up: [-90, 0, 0] }[facing];
  const c = ctx.at(p, r);
  c.cyl({ name: 'LampHousing', axis: 'z', len: o.depth || 0.35, d: d * 1.18, c: o.housing || '#2b2d31', m: 'Metal' });
  c.cyl({ name: 'LampRing', axis: 'z', len: (o.depth || 0.35) + 0.06, d: d, p: [0, 0, 0], c: o.ring || '#9aa0a6', m: 'Metal' });
  const lens = c.cyl({ name: o.name || 'LampLens', axis: 'z', len: 0.1, d: d * 0.78, p: [0, 0, -(o.depth || 0.35) / 2 - 0.02], c: o.lens || '#fff2b8', m: o.neon === false ? 'Glass' : 'Neon' });
  return lens;
}

// Square floodlight facing -Z
function flood(ctx, p, o = {}) {
  const w = o.w || 0.8, h = o.h || 0.6, dpt = o.depth || 0.5;
  const c = ctx.at(p, o.r || [0, 0, 0]);
  c.box({ name: 'FloodHousing', s: [w, h, dpt], c: o.housing || '#2b2d31', m: 'Metal' });
  c.box({ name: 'FloodBezel', s: [w + 0.08, h + 0.08, 0.1], p: [0, 0, -dpt / 2 + 0.02], c: o.bezel || '#3c3f45' });
  const lens = c.box({ name: o.name || 'FloodLens', s: [w - 0.16, h - 0.16, 0.08], p: [0, 0, -dpt / 2 - 0.04], c: o.lens || '#fff6d0', m: 'Neon' });
  if (o.cage) for (let i = -1; i <= 1; i++) c.box({ name: 'FloodCage', s: [0.05, h + 0.02, 0.05], p: [i * (w / 3), 0, -dpt / 2 - 0.12], c: '#1d1e21' });
  return lens;
}

// Alternating hazard stripes along local X: o.len total, n segments
function stripes(ctx, p, o) {
  const n = o.n || 6;
  const seg = o.len / n;
  const parts = [];
  for (let i = 0; i < n; i++) {
    const x = -o.len / 2 + seg * (i + 0.5);
    parts.push(ctx.at(p, o.r || [0, 0, 0]).box({ name: 'HazardStripe', s: [seg, o.h, o.d || 0.06], p: [x, 0, 0], c: i % 2 ? (o.c2 || '#1d1e21') : (o.c1 || '#f2c230'), m: 'SmoothPlastic' }));
  }
  return parts;
}

// Speckled dinosaur egg (ellipsoid), standing upright at p (p = egg center)
function egg(ctx, p, o = {}) {
  const w = o.w || 0.9, h = o.h || 1.2;
  const eg = ctx.at(p).ell({ name: 'Egg', s: [w, h, w], c: o.c || '#efe2c4', m: 'SmoothPlastic' });
  const R = rng(o.seed || 7);
  const spots = o.spots || 6;
  for (let i = 0; i < spots; i++) {
    const th = 0.5 + R() * 2.1, ph = R() * Math.PI * 2;
    const pos = [Math.sin(th) * Math.cos(ph) * w / 2 * 0.93, Math.cos(th) * h / 2 * 0.93, Math.sin(th) * Math.sin(ph) * w / 2 * 0.93];
    const sz = 0.14 + R() * 0.14;
    ctx.at(p).ell({ name: 'EggSpot', s: [sz, sz * 0.9, sz], p: pos, c: o.spot || '#7c9a3a', shadow: false });
  }
  return eg;
}

// Mud splats on a vertical side plane x = xPlane (normal +X for right side)
function mud(ctx, R, o) {
  const cols = o.colors || ['#6b4a2e', '#7e5a38', '#5a3d25'];
  for (let i = 0; i < o.n; i++) {
    const z = o.z0 + R() * (o.z1 - o.z0);
    const y = o.y0 + R() * (o.y1 - o.y0) * (0.4 + 0.6 * R());
    const w = 0.25 + R() * 0.6, h = 0.12 + R() * 0.3;
    ctx.box({ name: 'Mud', s: [0.04, h, w], p: [o.x, y, z], r: [R() * 60 - 30, 0, 0], c: cols[i % cols.length], shadow: false });
  }
}

// Three parallel claw scratches on a vertical side plane x = const
function clawMarks(ctx, p, o = {}) {
  const len = o.len || 1.4, ang = o.ang || 32, gap = o.gap || 0.28;
  for (let i = -1; i <= 1; i++) {
    ctx.box({ name: 'ClawMark', s: [0.04, 0.13, len * (1 - Math.abs(i) * 0.12)], p: [p[0], p[1] + i * gap, p[2] + i * 0.08], r: [ang, 0, 0], c: o.c || '#9aa0a6', m: 'Metal', shadow: false });
    ctx.box({ name: 'ClawMarkShadow', s: [0.035, 0.05, len * (1 - Math.abs(i) * 0.12) * 0.92], p: [p[0] + (o.inset || 0.01), p[1] + i * gap - 0.07, p[2] + i * 0.08 + 0.04], r: [ang, 0, 0], c: o.c2 || '#2b2216', shadow: false });
  }
}

module.exports = { wheel, lamp, flood, stripes, egg, mud, clawMarks };
