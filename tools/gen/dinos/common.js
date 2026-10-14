// Shared dinosaur construction helpers.
// Convention: model space, forward = -Z, up = +Y, ground at y = 0, x = 0 is the spine.
// Every bone has an identity (world-aligned) rotation at its pivot, so in Luau a Transform of
// CFrame.Angles(x, 0, 0) pitches, (0, y, 0) yaws and (0, 0, z) rolls — the same for every joint.
const { Inst, Ctx, Rig, CF, shade } = require('../builder.js');

function makeDino(name, attrs, rootSize, rootPos) {
  const model = new Inst('Model', name);
  for (const [k, v] of Object.entries(attrs)) model.attr(k, v);
  model.attr('Species', name);
  model.tag('DinoExpeditionDinosaur');
  model.set('ModelStreamingMode', 'token', 1); // Atomic: animate only when fully streamed in
  const rig = new Rig(model, new CF(...rootPos), rootSize);
  return { model, rig };
}

// Ctx in model space whose parts are parented & welded to `bone`
function seg(bone, defaults, mirrored = false) {
  return new Ctx({ parent: bone, frame: new CF(), bone, defaults, mirrored });
}

// Create a bone at model-space position p (respecting ctx mirroring) and return [bone, ctx]
function boneAt(rig, ctx, name, parent, p, defaults) {
  const pivot = ctx.world(new CF(p[0], p[1], p[2]));
  const b = rig.bone(name, parent, new CF(pivot.x, pivot.y, pivot.z));
  return [b, seg(b, defaults, ctx.mirrored)];
}

// Row of teeth along local -Z from z0 to z1 at height y, x offset; dir 'down' (upper jaw) or 'up'
function teeth(ctx, o) {
  const n = o.n;
  const out = [];
  for (let i = 0; i < n; i++) {
    const t = n === 1 ? 0 : i / (n - 1);
    const z = o.z0 + (o.z1 - o.z0) * t;
    const big = o.sizes ? o.sizes[i % o.sizes.length] : 1;
    const h = o.h * big, d = o.d * big;
    out.push(ctx.wedgeF({ name: 'Tooth', s: [o.w || 0.14, h, d], p: [o.x, o.y + (o.dir === 'down' ? -h / 2 : h / 2), z], face: 'front', flip: o.dir === 'down', c: o.c || '#f4ecd6', shadow: false, r: o.r || [0, 0, 0] }));
  }
  return out;
}

// Curved claw pointing forward-down from p: two stacked wedges
function claw(ctx, p, o = {}) {
  const s = o.s || 0.3;
  const c = ctx.at(p, o.r || [0, 0, 0]);
  c.wedgeF({ name: o.name || 'Claw', s: [s * 0.55, s * 0.7, s * 0.9], p: [0, s * 0.35, -s * 0.45], face: 'front', c: o.c || '#22201d' });
  c.wedgeF({ name: o.name || 'Claw', s: [s * 0.45, s * 0.9, s * 0.45], p: [0, -s * 0.45, -s * 0.68], face: 'front', flip: true, c: o.c || '#22201d' });
}

// Row of dorsal scales/plates along a polyline of [y, z] points at x = 0
function dorsal(ctx, pts, o = {}) {
  for (let i = 0; i < pts.length; i++) {
    const [y, z, k = 1] = pts[i];
    const h = (o.h || 0.3) * k, d = (o.d || 0.4) * k, w = (o.w || 0.18) * k;
    ctx.wedgeF({ name: o.name || 'DorsalScale', s: [w, h, d], p: [0, y + h / 2, z], face: o.face || 'back', c: o.c, r: o.r || [0, 0, 0] });
  }
}

// Eye on the right side (+X) at p: socket, iris, slit pupil, and a hidden eyelid for blinking
function eye(ctx, p, o = {}) {
  const h = o.h || 0.3, d = o.d || 0.4;
  const c = ctx.at(p, o.r || [0, 0, 0]);
  c.box({ name: 'EyeSocket', s: [0.08, h + 0.14, d + 0.16], p: [-0.02, 0, 0], c: o.socket || '#1a1a1a' });
  const iris = c.box({ name: 'Eye', s: [0.08, h, d], p: [0.02, 0, 0], c: o.c || '#ffb21a', m: o.neon ? 'Neon' : 'SmoothPlastic' });
  iris.tag('DinoEye');
  c.box({ name: 'Pupil', s: [0.06, h * 0.9, d * 0.18], p: [0.06, 0, -d * 0.05], c: '#0d0d0d' });
  c.box({ name: 'EyeGlint', s: [0.04, h * 0.25, d * 0.15], p: [0.08, h * 0.22, -d * 0.3], c: '#ffffff', shadow: false });
  const lid = c.box({ name: 'Eyelid', s: [0.14, h + 0.06, d + 0.08], p: [0.05, 0, 0], c: o.lid || '#555555', t: 1, shadow: false });
  lid.tag('DinoEyelid');
  return iris;
}

// Layered stripe band: a slightly larger shell over the upper part of a box segment
function band(ctx, p, s, o = {}) {
  return ctx.box({ name: o.name || 'Stripe', s, p, r: o.r || [0, 0, 0], c: o.c, shadow: false });
}

function highlight(model, color = '#141414', t = 0.45) {
  const h = new Inst('Highlight', 'Outline');
  const rgb = color.match(/\w\w/g).map((x) => parseInt(x, 16) / 255);
  h.set('FillTransparency', 'float', 1);
  h.set('OutlineColor', 'Color3', rgb);
  h.set('OutlineTransparency', 'float', t);
  h.set('DepthMode', 'token', 1); // Occluded
  model.add(h);
}


// Box whose local Y runs exactly from joint a down/along to joint b (width sx along X, depth sz)
function segBox(ctx, a, b, sx, sz, o = {}) {
  const d = [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const len = Math.hypot(...d);
  const up = d.map((v) => v / len);
  let right = [1 - up[0] * up[0], -up[0] * up[1], -up[0] * up[2]];
  const rl = Math.hypot(...right);
  right = rl > 1e-3 ? right.map((v) => v / rl) : [0, 0, 1];
  const mid = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2];
  const cf = CF.fromAxes(mid, right, up);
  return ctx.box(Object.assign({}, o, { cf, s: [sx, len + (o.extend === undefined ? sz * 0.5 : o.extend), sz] }));
}

// Three-bone quadruped leg. kind 'Hind' -> {Side}HindThigh/HindShin/HindFoot, 'Front' -> {Side}FrontUpper/FrontLower/FrontFoot
// j: { hip, knee, ankle } pivots (right-side coords); o: { upper:[w,d], lower:[w,d], foot:[w,h,d], muscle:{s,p}, toes, c, cLo, claw }
function quadLeg(rig, s, parentBone, n, kind, j, o) {
  const names = kind === 'Hind' ? ['HindThigh', 'HindShin', 'HindFoot'] : ['FrontUpper', 'FrontLower', 'FrontFoot'];
  const D = { c: o.c };
  const [b1, U] = boneAt(rig, s, n + names[0], parentBone, j.hip, D);
  segBox(U, j.hip, j.knee, o.upper[0], o.upper[1], { name: names[0] });
  if (o.muscle) U.box(Object.assign({ name: 'Muscle', c: o.c, studs: 'top' }, o.muscle));
  const [b2, Lw] = boneAt(rig, U, n + names[1], b1, j.knee, D);
  segBox(Lw, j.knee, j.ankle, o.lower[0], o.lower[1], { name: names[1], c: o.cLo || o.c });
  const [b3, F] = boneAt(rig, Lw, n + names[2], b2, j.ankle, D);
  const f = o.foot;
  F.box({ name: 'FootPad', s: f, p: [j.ankle[0], f[1] / 2, j.ankle[2] + (o.footZ || 0)], c: o.cLo || o.c });
  segBox(F, j.ankle, [j.ankle[0], f[1] * 0.8, j.ankle[2] + (o.footZ || 0) * 0.5], o.lower[0] * 0.92, o.lower[1] * 0.92, { name: 'Ankle', c: o.cLo || o.c, extend: 0.1 });
  const nt = o.toes || 3;
  for (let i = 0; i < nt; i++) {
    const dx = nt === 1 ? 0 : (i / (nt - 1) - 0.5) * f[0] * 0.75;
    F.wedgeF({ name: 'Toenail', s: [f[0] / (nt + 1.2), f[1] * 0.7, f[2] * 0.28], p: [j.ankle[0] + dx, f[1] * 0.35, j.ankle[2] + (o.footZ || 0) - f[2] / 2 - f[2] * 0.12], face: 'front', c: o.claw || '#efe2c4' });
  }
  F.attach(`VFX_${n}${kind === 'Hind' ? '' : 'Front'}Foot`, [j.ankle[0], 0.05, j.ankle[2] + (o.footZ || 0)]);
  return { bones: [b1, b2, b3], ctx: [U, Lw, F] };
}

// Biped leg: {Side}Thigh / Shin / Foot (+ optional Toes bone). j: { hip, knee, ankle, ball }
function bipedLeg(rig, s, parentBone, n, j, o) {
  const D = { c: o.c };
  const [thigh, T] = boneAt(rig, s, n + 'Thigh', parentBone, j.hip, D);
  segBox(T, j.hip, j.knee, o.thigh[0], o.thigh[1], { name: 'Thigh', studs: 'top' });
  if (o.muscle) T.box(Object.assign({ name: 'ThighMuscle', c: o.c }, o.muscle));
  const [shin, S] = boneAt(rig, T, n + 'Shin', thigh, j.knee, D);
  segBox(S, j.knee, j.ankle, o.shin[0], o.shin[1], { name: 'Shin', c: o.cLo || o.c });
  const [foot, F] = boneAt(rig, S, n + 'Foot', shin, j.ankle, D);
  segBox(F, j.ankle, j.ball, o.meta[0], o.meta[1], { name: 'Metatarsus', c: o.cLo || o.c });
  const [toesB, To] = boneAt(rig, F, n + 'Toes', foot, j.ball, D);
  const tl = o.toeLen || 1.0, tw = o.toeW || 0.35, th = o.toeH || 0.35;
  To.box({ name: 'ToePad', s: [tw * 3, th, tw * 2.2], p: [j.ball[0], th / 2, j.ball[2]], c: o.cLo || o.c });
  for (const [dx, ry, k] of [[-tw * 1.05, 12, 0.85], [0, 0, 1], [tw * 1.05, -12, 0.85]]) {
    const toe = To.at([j.ball[0] + dx, th / 2, j.ball[2]], [0, ry, 0]);
    toe.box({ name: 'Toe', s: [tw, th, tl * k], p: [0, 0, -tl * k / 2] });
    claw(toe, [0, 0.02, -tl * k - 0.02], { s: tw * 1.15, c: o.claw || '#1b1b1b' });
  }
  To.attach(`VFX_${n}Foot`, [j.ball[0], 0.05, j.ball[2] - tl * 0.3]);
  return { bones: [thigh, shin, foot, toesB], ctx: [T, S, F, To] };
}

// Tail chain: defs = [{ p: pivot, s: size, c: centre }...]; returns { bones, ctxs }
function tailChain(rig, parentCtx, parentBone, defs, o) {
  let parent = parentBone, pc = parentCtx;
  const bones = [], ctxs = [];
  defs.forEach((d, i) => {
    const [tb, Tc] = boneAt(rig, pc, `Tail${i + 1}`, parent, d.p, { c: o.c });
    Tc.box({ name: 'TailSegment', s: d.s, p: d.c, studs: o.studs === false ? undefined : 'top' });
    if (o.under) Tc.box({ name: 'TailUnderside', s: [d.s[0] * 0.75, Math.min(0.2, d.s[1] * 0.12), d.s[2] * 0.92], p: [0, d.c[1] - d.s[1] / 2 - 0.03, d.c[2]], c: o.under });
    if (o.band) band(Tc, [0, d.c[1] + d.s[1] * 0.3, d.c[2] + d.s[2] * 0.15], [d.s[0] + 0.06, d.s[1] * 0.45, d.s[2] * 0.32], { c: o.band });
    if (o.each) o.each(Tc, d, i);
    bones.push(tb); ctxs.push(Tc);
    parent = tb; pc = Tc;
  });
  const last = defs[defs.length - 1];
  ctxs[ctxs.length - 1].attach('VFX_TailTip', [0, last.c[1], last.c[2] + last.s[2] / 2]);
  return { bones, ctxs };
}

module.exports = { makeDino, seg, boneAt, teeth, claw, dorsal, eye, band, highlight, shade, CF, segBox, quadLeg, bipedLeg, tailChain };
