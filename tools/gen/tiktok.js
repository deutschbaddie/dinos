// TikTok director: bakes the shot library in tools/gen/anim/tiktok.js against the real generated maps.
//   node tools/gen/tiktok.js            -> src/.../Game/TikTok/Data.luau + QC frames + a QC report
//   node tools/gen/tiktok.js --qc-only  -> QC frames + report only
// Every shot is solved here once: anchors (road / nest / marker), actor paths snapped to the ground, the camera
// (keys, actor-relative, signature cameras) and the cues. The game only plays the baked numbers back, so a
// sequence is identical on every take and what tools/preview/tiktok.html shows is what records.
const fs = require('fs');
const path = require('path');
const B = require('./builder.js');
const { CF } = B;
const RT = require('./anim/runtime.js');
const { toLuau } = require('./anim/luau.js');
const SIG_SHOTS = require('./anim/shots.js');
const MAPQC = require('./mapqc.js');
const DATA = require('./anim/tiktok.js');

const ROOT = path.resolve(__dirname, '../..');
const OUT_PREVIEW = path.join(ROOT, 'tools/preview/out');
const QC_ONLY = process.argv.includes('--qc-only');
const ONLY = (process.argv.find((a) => a.startsWith('--seq=')) || '').slice(6);
const RATE = 30;
const ASPECT = 16 / 9; // the recordings are landscape 16:9
const BPM = DATA.Music.BPM;
const beatS = (b) => (b * 60) / BPM;

// ---------------------------------------------------------------- vectors
const V = {
  add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]],
  sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]],
  mul: (a, s) => [a[0] * s, a[1] * s, a[2] * s],
  dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
  len: (a) => Math.hypot(a[0], a[1], a[2]),
  lerp: (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t],
  unit: (a) => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; },
  flat: (a) => { const l = Math.hypot(a[0], a[2]) || 1; return [a[0] / l, 0, a[2] / l]; },
  cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]],
};
const yawOf = (f) => Math.atan2(-f[0], -f[2]); // Roblox: CFrame.Angles(0, yaw, 0).LookVector = (-sin, 0, -cos)
const fwdOf = (yaw) => [-Math.sin(yaw), 0, -Math.cos(yaw)];
const EASE = {
  linear: (u) => u, in: (u) => u * u * u, out: (u) => 1 - (1 - u) ** 3,
  inout: (u) => (u < 0.5 ? 4 * u * u * u : 1 - (-2 * u + 2) ** 3 / 2),
  sine: (u) => 0.5 - 0.5 * Math.cos(Math.PI * u), snap: (u) => 1 - (1 - u) ** 5,
};
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));

// ---------------------------------------------------------------- world
console.log('tiktok: building maps...');
const { buildFernValley } = require('./fernValley.js');
const { buildGiantPlains } = require('./giantPlains.js');
const { buildHub } = require('./hub.js');
// (2026-10-12: every era, so each boss can be filmed in its own arena)
const quiet = (fn) => { const log = console.log; console.log = () => {}; try { return fn(); } finally { console.log = log; } };
const fv = quiet(buildFernValley);
const gp = quiet(buildGiantPlains);
const hub = quiet(buildHub);
const sr = quiet(require('./spineRiver.js').buildSpineRiver);
const rc = quiet(require('./redCliffs.js').buildRedCliffs);
const ff = quiet(require('./frostForest.js').buildFrostForest);
const dd = quiet(require('./dawnDesert.js').buildDawnDesert);
for (const m of [fv.model, gp.model, hub, sr.model, rc.model, ff.model, dd.model]) quiet(() => MAPQC.check(m)); // the same decor pruning the real build does
const ZONES = {
  FernValley: { model: fv.model, data: fv.data },
  GiantPlains: { model: gp.model, data: gp.data },
  BaseCamp: { model: hub, data: null },
  SpineRiver: { model: sr.model, data: sr.data, water: require('./spineRiver.js').WATER_Y },
  RedCliffs: { model: rc.model, data: rc.data },
  FrostForest: { model: ff.model, data: ff.data },
  DawnDesert: { model: dd.model, data: dd.data },
};

const CELL = 24;
for (const [name, z] of Object.entries(ZONES)) {
  z.parts = [];
  z.model.walk((i) => {
    if (!i._preview || i._isBone || !i._cf) return;
    const s = i._preview.size;
    const cf = i._cf;
    const collide = !!(i.props.CanCollide && i.props.CanCollide[1]);
    // world AABB
    const ex = [0, 1, 2].map((k) => Math.abs(cf.r[k * 3]) * s[0] / 2 + Math.abs(cf.r[k * 3 + 1]) * s[1] / 2 + Math.abs(cf.r[k * 3 + 2]) * s[2] / 2);
    const c = [cf.x, cf.y, cf.z];
    z.parts.push({ i, cf, s, t: i._preview.t || 0, collide, name: i.name, min: V.sub(c, ex), max: V.add(c, ex), kind: i._preview.kind });
  });
  z.grid = new Map();
  z.parts.forEach((p, idx) => {
    for (let gx = Math.floor(p.min[0] / CELL); gx <= Math.floor(p.max[0] / CELL); gx++)
      for (let gz = Math.floor(p.min[2] / CELL); gz <= Math.floor(p.max[2] / CELL); gz++) {
        const k = gx + ',' + gz;
        if (!z.grid.has(k)) z.grid.set(k, []);
        z.grid.get(k).push(idx);
      }
  });
  z.preview = B.previewParts(z.model);
  console.log(`tiktok: ${name} ${z.parts.length} parts`);
}

// ray vs oriented box: returns entry distance or Infinity
function rayOBB(o, d, p) {
  const cf = p.cf, r = cf.r;
  const rel = [o[0] - cf.x, o[1] - cf.y, o[2] - cf.z];
  let tmin = -Infinity, tmax = Infinity;
  for (let k = 0; k < 3; k++) {
    const ax = [r[k], r[3 + k], r[6 + k]];
    const e = V.dot(ax, rel), f = V.dot(ax, d), h = p.s[k] / 2;
    if (Math.abs(f) < 1e-9) { if (-e - h > 0 || -e + h < 0) return Infinity; continue; }
    let t1 = (-e - h) / f, t2 = (-e + h) / f;
    if (t1 > t2) [t1, t2] = [t2, t1];
    tmin = Math.max(tmin, t1); tmax = Math.min(tmax, t2);
    if (tmin > tmax) return Infinity;
  }
  return tmin >= 0 ? tmin : (tmax >= 0 ? 0 : Infinity);
}
function cellParts(z, x, zz) { return z.grid.get(Math.floor(x / CELL) + ',' + Math.floor(zz / CELL)) || []; }
// the top of solid ground under (x, z), searching down from `from`
function groundY(zone, x, zz, from = 400) {
  const z = ZONES[zone];
  let best = -Infinity;
  for (const idx of cellParts(z, x, zz)) {
    const p = z.parts[idx];
    if (!p.collide || p.t > 0.6) continue;
    if (x < p.min[0] || x > p.max[0] || zz < p.min[2] || zz > p.max[2] || p.min[1] > from) continue;
    const d = rayOBB([x, from, zz], [0, -1, 0], p);
    if (d < Infinity) best = Math.max(best, from - d);
  }
  return best === -Infinity ? 0 : best;
}
// for small props (eggs, babies): also stand on non-colliding solid parts (nest bed, reveal pad) a little above
function propGroundY(zone, x, zz, base) {
  const z = ZONES[zone];
  let best = base;
  const from = base + 2.5;
  for (const idx of cellParts(z, x, zz)) {
    const p = z.parts[idx];
    if (p.t > 0.3 || p.collide) continue;
    if (x < p.min[0] || x > p.max[0] || zz < p.min[2] || zz > p.max[2] || p.min[1] > from || p.max[1] < base) continue;
    const d = rayOBB([x, from, zz], [0, -1, 0], p);
    if (d < Infinity) best = Math.max(best, from - d);
  }
  return best;
}
// first visible part between a and b (camera occlusion), ignoring parts within `skip` studs of b
function blocker(zone, a, b, skip = 2) {
  const z = ZONES[zone];
  const d = V.sub(b, a), L = V.len(d);
  if (L < 0.5) return null;
  const u = V.mul(d, 1 / L);
  const seen = new Set();
  let hit = null, hitD = L - skip;
  for (let s = 0; s <= L; s += CELL / 2) {
    const q = V.add(a, V.mul(u, s));
    for (const idx of cellParts(z, q[0], q[2])) {
      if (seen.has(idx)) continue;
      seen.add(idx);
      const p = z.parts[idx];
      if (p.t > 0.6) continue;
      const t = rayOBB(a, u, p);
      if (t < hitD) { hitD = t; hit = p.name; }
    }
  }
  return hit ? { name: hit, at: +hitD.toFixed(1) } : null;
}
// is a point inside solid geometry (camera inside a rock)?
function insideSolid(zone, p, collideOnly) {
  const z = ZONES[zone];
  for (const idx of cellParts(z, p[0], p[2])) {
    const q = z.parts[idx];
    if (q.t > 0.6 || (collideOnly && !q.collide)) continue;
    if (p[0] < q.min[0] || p[0] > q.max[0] || p[1] < q.min[1] || p[1] > q.max[1] || p[2] < q.min[2] || p[2] > q.max[2]) continue;
    const rel = [p[0] - q.cf.x, p[1] - q.cf.y, p[2] - q.cf.z];
    let inside = true;
    for (let k = 0; k < 3; k++) if (Math.abs(V.dot([q.cf.r[k], q.cf.r[3 + k], q.cf.r[6 + k]], rel)) > q.s[k] / 2) inside = false;
    if (inside) return q.name;
  }
  return null;
}

// ---------------------------------------------------------------- routes (mirror of RouteMath.luau)
function route(zone) {
  const z = ZONES[zone];
  if (z.route) return z.route;
  const vs = z.data.Variants.map((v) => {
    const pts = [];
    for (let i = 0; i < v.Points.length; i += 3) pts.push([v.Points[i], v.Points[i + 1], v.Points[i + 2]]);
    const cum = [0];
    for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][2] - pts[i - 1][2]));
    return { pts, cum, len: cum[cum.length - 1] };
  });
  const locate = (v, s) => {
    const n = v.cum.length;
    if (s <= 0) return [0, 0];
    if (s >= v.cum[n - 1]) return [n - 2, 1];
    let i = clamp(Math.floor(s / (v.cum[n - 1] / (n - 1))), 0, n - 2);
    while (i > 0 && v.cum[i] > s) i--;
    while (i < n - 2 && v.cum[i + 1] <= s) i++;
    return [i, (s - v.cum[i]) / Math.max(1e-6, v.cum[i + 1] - v.cum[i])];
  };
  z.route = {
    sample(vi, s) {
      const v = vs[vi - 1] || vs[0];
      const [i, t] = locate(v, s);
      const p = V.lerp(v.pts[i], v.pts[i + 1], t);
      const [ia] = locate(v, s - 3), [ib] = locate(v, s + 3);
      const d = V.sub(v.pts[Math.min(v.pts.length - 1, ib + 1)], v.pts[ia]);
      const f = V.flat(d);
      return { p, f, r: [-f[2], 0, f[0]] };
    },
    len: (vi) => (vs[vi - 1] || vs[0]).len,
  };
  return z.route;
}

// ---------------------------------------------------------------- anchors: a flat frame on the ground
function findNamed(zone, name) {
  let f = null;
  ZONES[zone].model.walk((i) => { if (!f && i.name === name && i._cf) f = i; });
  return f;
}
function frame(pos, fwd) {
  const f = V.flat(fwd);
  const r = [-f[2], 0, f[0]];
  return {
    pos, f, r,
    pt: (l) => [pos[0] + r[0] * l[0] - f[0] * l[2], pos[1] + l[1], pos[2] + r[2] * l[0] - f[2] * l[2]],
    vec: (l) => [r[0] * l[0] - f[0] * l[2], l[1], r[2] * l[0] - f[2] * l[2]],
  };
}
function anchorOf(shot) {
  const a = shot.At, zone = shot.Zone;
  if (a.Road) {
    const [s, x = 0, vi = 1] = a.Road;
    const R = route(zone);
    const smp = R.sample(vi, s);
    const p = V.add(smp.p, V.mul(smp.r, x));
    const fr = frame([p[0], groundY(zone, p[0], p[2]), p[2]], smp.f);
    fr.road = { s, x, vi };
    return fr;
  }
  if (a.Nest) {
    const nest = ZONES[zone].data.Nests.find((n) => n.Id === a.Nest);
    let core = null;
    ZONES[zone].model.walk((i) => { if (!core && i.attrs && i.attrs.NestId === a.Nest && i.cls === 'Model') i.walk((q) => { if (!core && q.name === 'NestCore') core = q; }); });
    const c = core._cf.pos();
    const R = route(zone);
    const vi = nest.S.findIndex((s) => s >= 0) + 1;
    const rp = R.sample(vi, nest.S[vi - 1]).p;
    const g = [c[0], groundY(zone, c[0], c[2], c[1] + 4), c[2]];
    // nest frame looks from the nest toward its road (the way you drive in)
    return frame(g, V.sub(rp, c));
  }
  if (a.Marker) {
    const m = findNamed(zone, a.Marker);
    const p = m._cf.pos();
    let fwd = m._cf.look();
    if (a.Away) { const o = findNamed(zone, a.Away)._cf.pos(); fwd = V.sub(p, o); }
    if (a.Toward) { const o = findNamed(zone, a.Toward)._cf.pos(); fwd = V.sub(o, p); }
    if (a.LookAttr) fwd = V.sub([m.attrs.LookX, m.attrs.LookY, m.attrs.LookZ], p);
    const ground = a.Air ? p[1] : groundY(zone, p[0], p[2], p[1] + 2);
    return frame([p[0], ground, p[2]], fwd);
  }
  if (a.Point) return frame([a.Point[0], a.Air ? a.Point[1] : groundY(zone, a.Point[0], a.Point[2], a.Point[1] + 40), a.Point[2]], a.Face || [0, 0, -1]);
  throw new Error('bad anchor ' + JSON.stringify(a));
}

// ---------------------------------------------------------------- models (built once)
const DINO_MOD = {
  Velociraptor: 'velociraptor', TyrannosaurusRex: 'trex', Triceratops: 'triceratops', Stegosaurus: 'stegosaurus',
  Parasaurolophus: 'parasaurolophus', Ankylosaurus: 'ankylosaurus', Carnotaurus: 'carnotaurus', Brachiosaurus: 'brachiosaurus',
  Spinosaurus: 'spinosaurus', Giganotosaurus: 'giganotosaurus', Mosasaurus: 'mosasaurus', PrimalRex: 'primalrex',
  Therizinosaurus: 'therizinosaurus', Yutyrannus: 'yutyrannus', Postosuchus: 'postosuchus', Coelophysis: 'coelophysis',
  Oviraptor: 'oviraptor', Protoceratops: 'protoceratops', Gallimimus: 'gallimimus', Microraptor: 'microraptor',
  Psittacosaurus: 'psittacosaurus', Compy: 'compy', Plateosaurus: 'plateosaurus', Dilophosaurus: 'dilophosaurus', Sarcosuchus: 'sarcosuchus',
};
const ANIM_MOD = DINO_MOD;
// the bosses at their fight size (Config.Bosses[].Scale)
const COMBAT_SCALE = { TyrannosaurusRex: 1.15, Giganotosaurus: 1.05, Velociraptor: 1.4, Triceratops: 1.1, Parasaurolophus: 1.0, Stegosaurus: 1.0, Ankylosaurus: 1.0, Brachiosaurus: 0.9,
  Mosasaurus: 0.9, Therizinosaurus: 1.0, Yutyrannus: 1.05, Postosuchus: 1.1 };
const dinoCache = {};
function dinoTemplate(species, scale, baby) {
  const key = species + '@' + scale + (baby ? 'b' : '');
  if (dinoCache[key]) return dinoCache[key];
  let m = require('./dinos/' + DINO_MOD[species] + '.js').build();
  if (baby) m = require('./babies.js').buildBaby(m);
  if (scale !== 1) B.scaleTree(m, scale);
  const b = B.bounds(m);
  let root = null, pelvis = null; const atts = {};
  m.walk((i) => { if (i.name === 'RootPart') root = i; if (i.cls === 'Attachment') atts[i.name] = i; if (i._isBone && i.name === 'Pelvis') pelvis = i; });
  const prof = require('./anim/' + ANIM_MOD[species] + '.js');
  // ground speed of a gait: authored Speed, or from stride geometry (a stance sweeps 2 * hip * sin(stride), two per cycle)
  const hip = pelvis ? pelvis._cf.y - b.min[1] : b.size[1] * 0.5;
  const speed = (mode) => { const g = prof.Gait[mode]; return g.Speed ? g.Speed * scale : 4 * hip * Math.sin(g.Stride || 0.3) * g.Freq; };
  return (dinoCache[key] = { m, b, root: root ? root._cf.pos() : [0, 0, 0], atts, prof, scale, speed });
}
const roverCache = {};
function roverTemplate(name) {
  if (roverCache[name]) return roverCache[name];
  const { buildTemplate } = require('./vehicleTemplate.js');
  const file = { RookieRanger: 'rookieRanger', RaptorRunner: 'raptorRunner', TitanTransport: 'titanTransport' }[name];
  const t = buildTemplate(require('./vehicles/' + file + '.js').build(), name);
  const seats = {}, slots = [];
  t.walk((i) => {
    if (/^(Driver|Passenger)Seat$/.test(i.name)) seats[i.name] = i._cf.pos();
    if (/^EggSlot\d$/.test(i.name) && i.props.CFrame && i.parent && i.parent._cf) slots[+i.name.slice(7) - 1] = i.parent._cf.mul(i.props.CFrame[1]).pos();
  });
  return (roverCache[name] = { m: t, rh: t.attrs.RootHeight, len: t.attrs.Length, parts: B.previewParts(t), seats, slots });
}
const eggCache = {};
function eggTemplate(species, scale = 1) {
  const key = species + '@' + scale;
  if (!eggCache[key]) { const e = require('./eggs.js').buildEgg(species); if (scale !== 1) B.scaleTree(e, scale); eggCache[key] = { parts: B.previewParts(e), b: B.bounds(e) }; }
  return eggCache[key];
}

// a blocky stand-in for a player in the QC frames (5 studs tall, R15-ish proportions)
function crewParts(cf, color) {
  const box = (s, p, c) => { const w = cf.mul(new CF(...p)); return { k: 'box', s, cf: [w.x, w.y, w.z, ...w.r], c, t: 0, m: 'Plastic', st: 0, n: 'Crew' }; };
  return [
    box([2, 2, 1], [0, 0.5, 0], color), box([1.2, 1.2, 1.2], [0, 2.1, 0], '#ffcc99'),
    box([1, 2, 1], [-1.5, 0.5, 0], color), box([1, 2, 1], [1.5, 0.5, 0], color),
    box([1, 2, 1], [-0.5, -1.5, 0], '#3a3f46'), box([1, 2, 1], [0.5, -1.5, 0], '#3a3f46'),
  ];
}
const xformParts = (parts, P) => parts.map((p) => { const w = P.mul(new CF(p.cf[0], p.cf[1], p.cf[2], p.cf.slice(3))); return Object.assign({}, p, { cf: [w.x, w.y, w.z, ...w.r].map((v) => +v.toFixed(3)) }); });

// ---------------------------------------------------------------- keyframe helpers
// a number or [[beat, value], ...] (piecewise linear, eased with 'sine')
function kf(spec, beat, dflt = 0) {
  if (spec === undefined) return dflt;
  if (typeof spec === 'number') return spec;
  if (beat <= spec[0][0]) return spec[0][1];
  for (let i = 0; i < spec.length - 1; i++) {
    const [b0, v0] = spec[i], [b1, v1] = spec[i + 1];
    if (beat <= b1) return v0 + (v1 - v0) * EASE[spec[i + 1][2] || 'sine']((beat - b0) / Math.max(1e-6, b1 - b0));
  }
  return spec[spec.length - 1][1];
}

// ---------------------------------------------------------------- actors
// each actor resolves to per-frame { g: ground point, yaw, pitch, roll, travel, steer }
function solveActor(shot, A, act, nFrames) {
  const zone = shot.Zone;
  const out = [];
  const mv = act.Move || {};
  let travel = 0, prev = null;
  for (let fi = 0; fi < nFrames; fi++) {
    const t = fi / RATE, beat = (t * BPM) / 60;
    let p, f;
    if (mv.Pin) {
      p = null; f = A.vec([0, 0, -1]); // resolved after the carrier is solved (see pins below)
    } else if (mv.Road) {
      const R = route(zone);
      const vi = A.road ? A.road.vi : 1;
      const v0 = mv.Road.Speed || 0;
      let run = v0 * t;
      if (mv.Road.Brake && v0 > 0) {
        const tb = beatS(mv.Road.Brake[0]), d = mv.Road.Brake[1];
        if (t > tb) { const tau = Math.min(t - tb, (2 * d) / v0); run = v0 * tb + v0 * tau - ((v0 * v0) / (4 * d)) * tau * tau; }
      }
      const s0 = (A.road ? A.road.s : 0) + kf(mv.Road.S, beat) + run;
      const x = kf(mv.Road.X, beat);
      const smp = R.sample(vi, s0);
      p = V.add(smp.p, V.mul(smp.r, x));
      // look a little ahead along the swerve so lateral moves turn the body
      const ahead = R.sample(vi, s0 + 4);
      const x2 = kf(mv.Road.X, beat + 0.25);
      const p2 = V.add(ahead.p, V.mul(ahead.r, x2));
      f = (mv.Road.Speed || 0) >= 0 ? V.sub(p2, p) : V.sub(p, p2);
      if (V.len([f[0], 0, f[2]]) < 0.01) f = smp.f;
    } else if (mv.Path) {
      const pts = mv.Path.map((q) => A.pt([q[0], 0, q[1]]));
      const segs = [];
      let tot = 0;
      for (let i = 0; i < pts.length - 1; i++) { const L = Math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][2] - pts[i][2]); segs.push(L); tot += L; }
      const dur = mv.Speed ? tot / mv.Speed : beatS(mv.Beats || shot.Beats);
      const t0 = beatS(mv.Start || 0);
      const u = EASE[mv.Ease || 'linear'](clamp((t - t0) / dur, 0, 1));
      let d = u * tot, i = 0;
      while (i < segs.length - 1 && d > segs[i]) { d -= segs[i]; i++; }
      p = V.lerp(pts[i], pts[i + 1], segs[i] ? d / segs[i] : 0);
      f = V.sub(pts[i + 1], pts[i]);
      if (mv.Face) f = V.sub(A.pt([mv.Face[0], 0, mv.Face[1]]), p);
    } else {
      const s = mv.Spot || [0, 0];
      p = A.pt([s[0], 0, s[1]]);
      f = mv.Face ? V.sub(A.pt([mv.Face[0], 0, mv.Face[1]]), p) : A.vec([0, 0, -1]);
      if (mv.Yaw !== undefined) f = A.vec([-Math.sin((mv.Yaw * Math.PI) / 180), 0, -Math.cos((mv.Yaw * Math.PI) / 180)]);
    }
    if (!p) { out.push({ g: [0, 0, 0], yaw: 0, pitch: 0, roll: 0, travel: 0, pin: true }); continue; }
    let yaw = yawOf(V.flat(f));
    if (mv.YawOff !== undefined) yaw += (kf(mv.YawOff, beat) * Math.PI) / 180;
    const gy = mv.Air !== undefined ? A.pos[1] + kf(mv.Air, beat) : groundY(zone, p[0], p[2], (prev ? prev[1] : p[1]) + 30);
    const gy2 = (act.Egg || act.Baby) && mv.Air === undefined ? propGroundY(zone, p[0], p[2], gy) : gy;
    const g = [p[0], gy2 + kf(mv.Lift, beat), p[2]];
    if (prev) travel += Math.hypot(g[0] - prev[0], g[2] - prev[2]);
    let pitch = 0, roll = 0;
    if (act.Rover) {
      const fw = fwdOf(yaw), rt = [-fw[2], 0, fw[0]];
      const half = 4;
      const yF = groundY(zone, g[0] + fw[0] * half, g[2] + fw[2] * half, g[1] + 8), yB = groundY(zone, g[0] - fw[0] * half, g[2] - fw[2] * half, g[1] + 8);
      const yR = groundY(zone, g[0] + rt[0] * 3, g[2] + rt[2] * 3, g[1] + 8), yL = groundY(zone, g[0] - rt[0] * 3, g[2] - rt[2] * 3, g[1] + 8);
      pitch = clamp(Math.atan2(yF - yB, half * 2), -0.35, 0.35) + kf(mv.Pitch, beat);
      roll = clamp(Math.atan2(yL - yR, 6), -0.25, 0.25);
      g[1] = Math.max(g[1], (yF + yB) / 2);
    }
    out.push({ g, yaw, pitch, roll, travel });
    prev = g;
  }
  // steer: yaw rate
  for (let i = 0; i < out.length; i++) {
    const a = out[Math.max(0, i - 2)], b = out[Math.min(out.length - 1, i + 2)];
    let dy = b.yaw - a.yaw; while (dy > Math.PI) dy -= 2 * Math.PI; while (dy < -Math.PI) dy += 2 * Math.PI;
    out[i].steer = clamp(dy * 4, -0.45, 0.45);
  }
  return out;
}

// the action an actor is in at time t: { name, T } (T = the action's own clock), or a signature clock
function actionAt(act, t, prof) {
  if (act.Sig !== undefined) {
    const name = prof.Intro || prof.Signature;
    const D = prof.Actions[name].Duration;
    return { name, T: clamp(sigClock(act, prof, t), 0, D) };
  }
  let cur = null;
  for (const [b, name, speed = 1] of act.Acts || []) {
    const t0 = beatS(b);
    if (t >= t0 && prof.Actions[name]) {
      const T = (t - t0) * speed;
      if (T <= prof.Actions[name].Duration || prof.Actions[name].Loop) cur = { name, T: prof.Actions[name].Loop ? T % prof.Actions[name].Duration : T };
    }
  }
  return cur;
}
// the signature's own clock, with its authored slow-motion ramps (mirror of DinosaurCinematics.rampSpeed)
const sigCache = new Map();
function sigClock(act, prof, t) {
  let arr = sigCache.get(act);
  if (!arr) {
    const name = prof.Intro || prof.Signature;
    const D = prof.Actions[name].Duration;
    const list = SIG_SHOTS[prof.IntroShots || 'Roar'];
    const k = list.Normalized ? D : 1;
    const ramp = (T) => {
      for (const [a, b, sp] of list.TimeRamps || []) {
        const t0 = a * k, t1 = b * k;
        if (T >= t0 && T <= t1) return 1 + (sp - 1) * Math.min(1, (T - t0) / 0.08, (t1 - T) / 0.12);
      }
      return 1;
    };
    arr = [act.Sig.From || 0];
    let T = arr[0];
    for (let i = 1; i < 60 * RATE; i++) { T += (1 / RATE) * ramp(T) * (act.Sig.Speed || 1); arr.push(T); }
    sigCache.set(act, arr);
  }
  const f = t * RATE, i = Math.floor(f);
  return arr[Math.min(i, arr.length - 2)] + (arr[Math.min(i + 1, arr.length - 1)] - arr[Math.min(i, arr.length - 2)]) * (f - i);
}
function locoAt(act, beat) {
  let mode = act.Loco || 'Idle';
  for (const [b, m] of act.LocoKeys || []) if (beat >= b) mode = m;
  return mode;
}

// posed world attachments + parts for a dino at frame state
function posedDino(tpl, st, act, t, wantParts) {
  const prof = tpl.prof;
  const a = actionAt(act, t, prof);
  const beat = (t * BPM) / 60;
  let pose;
  if (a) pose = RT.actionPose(prof, a.name, a.T);
  else {
    const mode = locoAt(act, beat);
    pose = RT.gaitPose(prof, mode, mode === 'Idle' ? 0 : (st.phase !== undefined ? st.phase : t * prof.Gait[mode].Freq));
  }
  const k = tpl.scale;
  if (k !== 1) for (const j of Object.keys(pose)) { const c = pose[j]; pose[j] = new CF(c.x * k, c.y * k, c.z * k, c.r.slice()); }
  const P = new CF(st.g[0], st.g[1], st.g[2]).mul(CF.angles(0, st.yaw, 0)).mul(new CF(-tpl.root[0], -tpl.b.min[1], -tpl.root[2]));
  const cache = new Map();
  const world = (name) => {
    const att = tpl.atts[name];
    if (!att) return null;
    const bone = att.parent;
    const w = (bone._isBone ? B.posedWorld(bone, pose, cache).mul(bone._cf.inv().mul(att._world)) : att._world).pos();
    return P.pt(w);
  };
  const res = { P, Head: world('VFX_Head'), Mouth: world('VFX_Mouth'), Chest: world('VFX_Chest'), Center: P.pt([tpl.root[0], (tpl.b.min[1] + tpl.b.max[1]) / 2, tpl.root[2]]), Action: a };
  res.Head = res.Head || res.Center; res.Mouth = res.Mouth || res.Head; res.Chest = res.Chest || res.Center;
  // (any other VFX_ attachment by its short name - part('sk', 'RightClaw') - 2026-10-14)
  res.att = (nm) => (nm in res ? res[nm] : world('VFX_' + nm));
  if (wantParts) res.parts = xformParts(B.previewParts(tpl.m, pose), P);
  return res;
}

// ---------------------------------------------------------------- bake one shot
function bakeShot(name) {
  const shot = DATA.Shots[name];
  if (!shot) throw new Error('unknown shot ' + name);
  const A = anchorOf(shot);
  const dur = beatS(shot.Beats);
  const n = Math.round(dur * RATE) + 1;
  const actors = {};
  for (const act of shot.Actors || []) {
    const st = solveActor(shot, A, act, n);
    const rec = { act, st };
    if (act.Dino || act.Baby) rec.tpl = dinoTemplate(act.Dino || act.Baby, act.Scale || (act.Baby ? 1 : COMBAT_SCALE[act.Dino] || 1), !!act.Baby);
    if (act.Rover) rec.tpl = roverTemplate(act.Rover);
    actors[act.Id] = rec;
  }
  // pins: an actor riding a point on another (a rodeo rider on the dino's back)
  const roverCF = (rv, fi) => { const s = rv.st[fi]; return new CF(s.g[0], s.g[1] + rv.tpl.rh, s.g[2]).mul(CF.angles(0, s.yaw, 0)).mul(CF.angles(s.pitch, 0, s.roll)).mul(new CF(0, -rv.tpl.rh, 0)); };
  for (const rec of Object.values(actors)) {
    const pin = rec.act.Move && rec.act.Move.Pin;
    if (!pin) continue;
    const host = actors[pin.Of];
    for (let fi = 0; fi < n; fi++) {
      const hs = host.st[fi];
      let p;
      if (host.tpl && host.tpl.prof) { const d = posedDino(host.tpl, hs, host.act, fi / RATE, false); p = V.add(d[pin.Part || 'Chest'], pin.Off || [0, 0, 0]); }
      else if (host.act.Rover && pin.Slot) p = roverCF(host, fi).pt(host.tpl.slots[pin.Slot - 1] || [0, 4, 3]);
      else p = V.add(hs.g, pin.Off || [0, 0, 0]);
      rec.st[fi] = { g: p, yaw: hs.yaw + ((pin.Yaw || 0) * Math.PI) / 180, pitch: 0, roll: 0, travel: 0, steer: 0 };
    }
  }
  // gait phase from real ground speed: legs cycle as fast as the body actually moves, so feet never skate
  for (const rec of Object.values(actors)) {
    if (!(rec.tpl && rec.tpl.prof)) continue;
    const G = rec.tpl.prof.Gait;
    let ph = 0;
    for (let fi = 0; fi < n; fi++) {
      const mode = locoAt(rec.act, (fi / RATE) * BPM / 60);
      if (fi > 0 && mode !== 'Idle') {
        const a = rec.st[fi - 1].g, c = rec.st[fi].g;
        const v = Math.hypot(c[0] - a[0], c[2] - a[2]) * RATE;
        const gs = rec.tpl.speed(mode);
        ph += (1 / RATE) * G[mode].Freq * (v > 0.5 ? clamp(v / gs, 0.5, 2.6) : 1);
      }
      rec.st[fi].phase = ph;
    }
  }
  // crew riding a rover follow its seat
  const seatCF = (rv, fi, which) => {
    const s = rv.st[fi];
    const seat = rv.tpl.seats[which === 2 ? 'PassengerSeat' : 'DriverSeat'];
    const P = new CF(s.g[0], s.g[1] + rv.tpl.rh, s.g[2]).mul(CF.angles(0, s.yaw, 0)).mul(CF.angles(s.pitch, 0, s.roll)).mul(new CF(0, -rv.tpl.rh, 0));
    return P.mul(new CF(seat[0], seat[1] + 1.6, seat[2]));
  };
  // a point spec at frame fi
  const poseCache = new Map();
  const dinoAt = (id, fi) => {
    const key = id + '#' + fi;
    if (!poseCache.has(key)) poseCache.set(key, posedDino(actors[id].tpl, actors[id].st[fi], actors[id].act, fi / RATE, false));
    return poseCache.get(key);
  };
  const point = (spec, fi) => {
    if (Array.isArray(spec)) return A.pt(spec);
    // { Gnd: [x, h, z] }: h studs above the ground at (x, z) - a sloped approach (2026-10-14)
    if (spec.Gnd) { const q = A.pt([spec.Gnd[0], 0, spec.Gnd[2]]); return [q[0], groundY(shot.Zone, q[0], q[2], q[1] + 80) + spec.Gnd[1], q[2]]; }
    const rec = actors[spec.Of];
    if (!rec) throw new Error(`${name}: no actor ${spec.Of}`);
    const s = rec.st[fi];
    if (spec.Part && rec.tpl && rec.tpl.prof) {
      const d = dinoAt(spec.Of, fi);
      return V.add(d.att(spec.Part) || d.Center, spec.Off || [0, 0, 0]);
    }
    const fr = frame(s.g, fwdOf(s.yaw));
    const base = rec.act.Rover ? [0, rec.tpl.rh, 0] : [0, 0, 0];
    return fr.pt(V.add(base, spec.At || [0, 0, 0]));
  };
  // camera
  const cam = [];
  const C = shot.Cam;
  let sigRig = null;
  if (C.Sig) {
    const rec = actors[C.Sig];
    const prof = rec.tpl.prof;
    const list = SIG_SHOTS[prof.IntroShots || 'Roar'];
    sigRig = { rec, prof, list, D: prof.Actions[prof.Intro || prof.Signature].Duration, u: list.Studs ? 1 : prof.CameraScale };
  }
  let sLook = null;
  let dcam = null; // drive camera smoothing state
  for (let fi = 0; fi < n; fi++) {
    const t = fi / RATE, beat = (t * BPM) / 60;
    let pos, look, fov, roll = 0;
    if (C.Player && actors[C.Player] && actors[C.Player].act.Rover) {
      // mirror of Drive.updateCamera (chase camera behind the rover, look-back swing)
      const rv = actors[C.Player], s0 = rv.st[fi], sp = rv.st[Math.max(0, fi - 1)];
      const speed = fi > 0 ? Math.hypot(s0.g[0] - sp.g[0], s0.g[2] - sp.g[2]) * RATE : (C.Speed || 30);
      const root = [s0.g[0], s0.g[1] + rv.tpl.rh, s0.g[2]];
      const flat = fwdOf(s0.yaw);
      const len = rv.tpl.len || 15;
      const back = len * 0.62 + 9 + clamp(speed, 0, 80) * 0.06, up = 5.2 + len * 0.12;
      const focus = V.add(V.add(root, [0, 2.2, 0]), V.mul(flat, 6 + speed * 0.08));
      const want = V.add(V.sub(root, V.mul(flat, back)), [0, up, 0]);
      const k = 1 - Math.exp(-(1 / RATE) * 7);
      dcam = dcam ? { p: V.lerp(dcam.p, want, k), l: V.lerp(dcam.l, focus, k) } : { p: want, l: focus };
      pos = dcam.p; look = dcam.l;
      const lb = kf(C.LookBack, beat);
      if (lb > 0) {
        const pivot = V.add(root, [0, 2.6, 0]);
        const off = V.sub(pos, pivot), yaw = Math.PI * lb;
        const c = Math.cos(yaw), sn = Math.sin(yaw);
        const rot = [off[0] * c + off[2] * sn, off[1] + V.len(off) * 0.12 * lb, -off[0] * sn + off[2] * c];
        pos = V.add(pivot, rot);
        look = V.lerp(V.add(dcam.p, V.mul(V.unit(V.sub(dcam.l, dcam.p)), 20)), pivot, clamp(lb * 3, 0, 1));
      }
      fov = 68 + clamp(speed - 30, 0, 50) * 0.18 + (C.Boost ? 9 : 0);
    } else if (C.Player && actors[C.Player]) {
      // Roblox's follow camera on a walking player (+ the encounter shoulder offset when Shoulder)
      const cr = actors[C.Player], s0 = cr.st[fi];
      const focus = [s0.g[0], s0.g[1] + 4.5, s0.g[2]];
      const yaw = yawOf(A.f) + (kf(C.Yaw, beat) * Math.PI) / 180;
      const pitch = (kf(C.Pitch, beat, -16) * Math.PI) / 180;
      const dir = [-Math.sin(yaw) * Math.cos(pitch), Math.sin(pitch), -Math.cos(yaw) * Math.cos(pitch)];
      const right = [-dir[2], 0, dir[0]];
      const sh = C.Shoulder ? V.add(V.mul(V.unit(right), 1.9), [0, 0.45, 0]) : [0, 0, 0];
      const dist = kf(C.Dist, beat, 12.5);
      pos = V.add(V.sub(focus, V.mul(dir, dist)), sh);
      look = V.add(focus, sh);
      fov = kf(C.Fov, beat, 70);
    } else if (sigRig) {
      const d = dinoAt(C.Sig, fi);
      const s = sigRig.rec.st[fi];
      const foot = d.P.pt([0, sigRig.rec.tpl.b.min[1], 0]);
      const G = new CF(s.g[0], s.g[1], s.g[2]).mul(CF.angles(0, s.yaw, 0));
      const targets = { Head: d.Head, Mouth: d.Mouth, Chest: d.Chest, HeadStart: dinoAt(C.Sig, 0).Head };
      const smp = RT.sampleShots(sigRig.list, d.Action ? d.Action.T : 0, sigRig.D, G, sigRig.u, targets);
      pos = smp.pos; look = smp.look; fov = smp.fov; roll = smp.roll || 0;
      void foot;
    } else {
      const keys = C.Keys || [{ B: 0, P: C.From, L: C.Look || C.LookFrom, F: Array.isArray(C.Fov) ? C.Fov[0] : C.Fov, R: Array.isArray(C.Roll) ? C.Roll[0] : C.Roll || 0 },
        { B: shot.Beats, P: C.To || C.From, L: C.LookTo || C.Look || C.LookFrom, F: Array.isArray(C.Fov) ? C.Fov[1] : C.Fov, R: Array.isArray(C.Roll) ? C.Roll[1] : C.Roll || 0, E: C.Ease || 'inout' }];
      let i = 0;
      while (i < keys.length - 2 && beat > keys[i + 1].B) i++;
      const k0 = keys[i], k1 = keys[Math.min(i + 1, keys.length - 1)];
      const u = k1 === k0 ? 0 : EASE[k1.E || 'inout'](clamp((beat - k0.B) / Math.max(1e-6, k1.B - k0.B), 0, 1));
      const lu = k1.LE ? EASE[k1.LE](clamp((beat - k0.B) / Math.max(1e-6, k1.B - k0.B), 0, 1)) : u;
      pos = V.lerp(point(k0.P, fi), point(k1.P || k0.P, fi), u);
      look = V.lerp(point(k0.L, fi), point(k1.L || k0.L, fi), lu);
      fov = (k0.F || 60) + ((k1.F || k0.F || 60) - (k0.F || 60)) * u;
      roll = (k0.R || 0) + ((k1.R || 0) - (k0.R || 0)) * u;
    }
    // smooth the look point a touch (head bob would jitter a locked frame), never across the cut
    const k = C.Player ? 0 : C.Smooth === undefined ? 0.35 : C.Smooth;
    sLook = sLook && k > 0 ? V.lerp(sLook, look, 1 - k) : look;
    // never under the ground
    const gy = groundY(shot.Zone, pos[0], pos[2], pos[1] + 2);
    if (pos[1] < gy + 0.6) pos = [pos[0], gy + 0.6, pos[2]];
    cam.push({ pos, look: sLook, fov, roll });
  }
  return { shot, A, n, dur, actors, cam, seatCF, dinoAt, point };
}

// ---------------------------------------------------------------- QC: projection into the 16:9 frame
function project(cam, p) {
  const f = V.unit(V.sub(cam.look, cam.pos));
  const r = V.unit(V.cross(f, [0, 1, 0]));
  const u = V.cross(r, f);
  const d = V.sub(p, cam.pos);
  const z = V.dot(d, f);
  if (z <= 0.1) return null;
  const th = Math.tan((cam.fov * Math.PI) / 360);
  const x = V.dot(d, r) / (z * th * ASPECT), y = V.dot(d, u) / (z * th);
  return [0.5 + x / 2, 0.5 - y / 2, z];
}
// the point QC frames a dino by: shot.Focus is a part name, or [[beat, part], ...] (a tilt from the feet to the head)
function focusOf(shot, t) {
  const F = shot.Focus || 'Head';
  if (typeof F === 'string') return F;
  let cur = F[0][1];
  for (const [bt, nm] of F) if (t >= beatS(bt)) cur = nm;
  return cur;
}
function qcShot(b) {
  const issues = [];
  const subs = b.shot.Subject || Object.keys(b.actors).slice(0, 1);
  const sample = [0, Math.floor(b.n / 2), b.n - 1];
  for (const fi of sample) {
    const cam = b.cam[fi];
    const inside = insideSolid(b.shot.Zone, cam.pos);
    if (inside) issues.push(`f${fi}: camera inside ${inside}`);
    for (const id of subs) {
      const rec = b.actors[id];
      if (!rec) continue;
      // (not on screen yet, or already gone: an actor that's hidden can't be off frame or blocked)
      if (rec.act.Hidden && fi / RATE < beatS(rec.act.Hidden[0])) continue;
      if (rec.act.Until !== undefined && fi / RATE >= beatS(rec.act.Until)) continue;
      const pts = rec.tpl && rec.tpl.prof ? [b.dinoAt(id, fi).att(focusOf(b.shot, fi / RATE))] : [b.point({ Of: id, At: [0, rec.act.Rover ? 1.5 : rec.act.Crew && b.shot.Strict ? 3.5 : 0.5, 0] }, fi)];
      for (const p of pts) {
        const pr = project(cam, p);
        if (!pr) { issues.push(`f${fi}: ${id} behind camera`); continue; }
        if (pr[0] < 0.05 || pr[0] > 0.95 || pr[1] < 0.04 || pr[1] > 0.96) issues.push(`f${fi}: ${id} off frame (${pr[0].toFixed(2)},${pr[1].toFixed(2)})`);
        else if (pr[1] > 0.85) issues.push(`f${fi}: ${id} in caption zone (y ${pr[1].toFixed(2)})`);
        const bl = blocker(b.shot.Zone, cam.pos, p, 3 + (rec.tpl && rec.tpl.b ? rec.tpl.b.size[2] / 3 : 2));
        if (bl) issues.push(`f${fi}: ${id} blocked by ${bl.name} at ${bl.at}`);
      }
    }
  }
  // bodies passing through each other: any rover against any dino's posed parts (every 3rd frame)
  const rovers = Object.entries(b.actors).filter(([, r]) => r.act.Rover);
  const dinos = Object.entries(b.actors).filter(([, r]) => r.tpl && r.tpl.prof);
  for (const [rid, rv] of rovers) {
    const half = [(rv.tpl.m.attrs.Width || 8) / 2, (rv.tpl.m.attrs.Height || 8) / 2, (rv.tpl.len || 15) / 2];
    for (const [did, dn] of dinos) {
      let worst = null;
      for (let fi = 0; fi < b.n; fi += 3) {
        if (dn.act.Hidden && fi / RATE < beatS(dn.act.Hidden[0])) continue;
        const s = rv.st[fi];
        const P = new CF(s.g[0], s.g[1] + rv.tpl.rh, s.g[2]).mul(CF.angles(0, s.yaw, 0)).mul(CF.angles(s.pitch, 0, s.roll));
        const inv = P.inv();
        const parts = posedDino(dn.tpl, dn.st[fi], dn.act, fi / RATE, true).parts;
        let n = 0; const names = new Set();
        for (const q of parts) {
          if (q.t >= 0.9) continue;
          const l = inv.pt([q.cf[0], q.cf[1], q.cf[2]]);
          if (Math.abs(l[0]) < half[0] && l[1] > -rv.tpl.rh && l[1] < half[1] * 2 - rv.tpl.rh && Math.abs(l[2]) < half[2]) { n++; names.add(q.bone || q.n); }
        }
        if (n > 2 && (!worst || n > worst.n)) worst = { fi, n, names: [...names].slice(0, 5).join('/') };
      }
      if (worst) issues.push(`f${worst.fi}: ${rid} drives through ${did} (${worst.n} parts: ${worst.names})`);
    }
  }
  if (b.shot.Strict) issues.push(...strictQc(b));
  return [...new Set(issues)];
}

// strict shots (the boss reveals, 2026-10-14): every 3rd frame instead of 3 per shot. The lens is never inside a
// rock or a body, the subject stays in frame and unblocked for the whole shot (not just at its ends), and no dino
// walks through the walls (an actor with ClipOK - one rising out of the mud - is let off that last one).
function strictQc(b) {
  const zone = b.shot.Zone;
  const found = new Map(); // message -> [first frame, count]
  const note = (fi, msg, at) => { const e = found.get(msg); if (e) e[1]++; else found.set(msg, [fi, 1, at]); };
  // a frame under a Black cue shows nothing: nothing in it can be off frame
  const cues = (b.shot.Cues || []).filter((c) => c[1] === 'Black' || c[1] === 'Unblack').sort((x, y) => x[0] - y[0]);
  const isBlack = (t) => { let on = false; for (const c of cues) if (beatS(c[0]) <= t) on = c[1] === 'Black'; return on; };
  const visible = (rec, t) => !(rec.act.Hidden && t < beatS(rec.act.Hidden[0])) && !(rec.act.Until !== undefined && t >= beatS(rec.act.Until));
  const inBox = (q, p) => {
    const rel = [p[0] - q.cf[0], p[1] - q.cf[1], p[2] - q.cf[2]];
    for (let k = 0; k < 3; k++) if (Math.abs(q.cf[3 + k] * rel[0] + q.cf[6 + k] * rel[1] + q.cf[9 + k] * rel[2]) > q.s[k] / 2 + 0.25) return false;
    return true;
  };
  const subs = b.shot.Subject || [];
  for (let fi = 0; fi < b.n; fi += 3) {
    const t = fi / RATE;
    const cam = b.cam[fi];
    const inside = insideSolid(zone, cam.pos);
    if (inside) note(fi, `camera inside ${inside}`);
    for (const [id, rec] of Object.entries(b.actors)) {
      if (!(rec.tpl && rec.tpl.prof) || !visible(rec, t)) continue;
      const d = posedDino(rec.tpl, rec.st[fi], rec.act, t, true);
      const hit = d.parts.find((q) => q.t < 0.9 && inBox(q, cam.pos));
      if (hit) note(fi, `lens inside ${id} (${hit.bone || hit.n})`);
      if (!rec.act.ClipOK) for (const k of ['Head', 'Chest']) { const w = insideSolid(zone, d[k], true); if (w) note(fi, `${id} ${k} inside ${w}`); }
    }
    if (isBlack(t)) continue;
    for (const id of subs) {
      const rec = b.actors[id];
      if (!rec || !visible(rec, t)) continue;
      const p = rec.tpl && rec.tpl.prof ? b.dinoAt(id, fi).att(focusOf(b.shot, t)) : b.point({ Of: id, At: [0, rec.act.Rover ? 1.5 : rec.act.Crew ? 3.5 : 0.5, 0] }, fi); // (a player by the chest)
      const pr = project(cam, p);
      if (!pr) { note(fi, `${id} behind camera`); continue; }
      const xy = `(${pr[0].toFixed(2)},${pr[1].toFixed(2)})`;
      if (pr[0] < 0.05 || pr[0] > 0.95 || pr[1] < 0.04 || pr[1] > 0.96) note(fi, `${id} off frame`, xy);
      else if (pr[1] > 0.85) note(fi, `${id} in caption zone`, xy);
      const bl = blocker(zone, cam.pos, p, 3 + (rec.tpl && rec.tpl.b ? rec.tpl.b.size[2] / 3 : 2));
      if (bl) note(fi, `${id} blocked by ${bl.name}`);
    }
  }
  return [...found].map(([msg, [fi, n, at]]) => `f${fi}${n > 1 ? ` (+${n - 1} more)` : ''}: ${msg}${at ? ' ' + at : ''} [strict]`);
}

// ---------------------------------------------------------------- QC frames (tools/preview/tiktok.html)
function qcFrames(b, picks) {
  const frames = [];
  for (const fi of picks) {
    const parts = [];
    for (const [id, rec] of Object.entries(b.actors)) {
      const s = rec.st[fi];
      if (rec.act.Hidden && fi / RATE < beatS(rec.act.Hidden[0])) continue;
      if (rec.act.Until !== undefined && fi / RATE >= beatS(rec.act.Until)) continue;
      if (rec.tpl && rec.tpl.prof) {
        let ps = posedDino(rec.tpl, s, rec.act, fi / RATE, true).parts;
        // a silhouette window: drawn near-black in the QC frames (the game uses a black Highlight + glowing eyes)
        const tt = fi / RATE;
        if ((rec.act.Silhouette || []).some((w, k, arr) => k % 2 === 0 && tt >= beatS(arr[k]) && tt < beatS(arr[k + 1]))) ps = ps.map((q) => Object.assign({}, q, { c: '#101014', m: 'Plastic' }));
        parts.push(...ps);
      } else if (rec.act.Prop) {
        const pr = rec.act.Prop, sz = pr.Size || [6, 0.1, 6];
        const P = new CF(s.g[0], s.g[1] + (pr.Lift || 0) + sz[1] / 2, s.g[2]).mul(CF.angles(0, s.yaw, 0));
        const shape = pr.Shape === 'Cylinder' ? 'cyl' : 'box';
        const cf = shape === 'cyl' ? P.mul(CF.angles(0, 0, Math.PI / 2)) : P;
        const size = shape === 'cyl' ? [sz[1], sz[0], sz[2]] : sz;
        parts.push({ k: shape, s: size, cf: [cf.x, cf.y, cf.z, ...cf.r], c: pr.Color || '#5aa0c8', t: pr.Transparency || 0, m: pr.Material || 'SmoothPlastic', st: 0, n: rec.act.Id });
      }
      else if (rec.act.Rover) {
        const P = new CF(s.g[0], s.g[1] + rec.tpl.rh, s.g[2]).mul(CF.angles(0, s.yaw, 0)).mul(CF.angles(s.pitch, 0, s.roll)).mul(new CF(0, -rec.tpl.rh, 0));
        parts.push(...xformParts(rec.tpl.parts, P));
      } else if (rec.act.Crew) {
        const rv = rec.act.Ride && b.actors[rec.act.Ride];
        const cf = rv ? b.seatCF(rv, fi, rec.act.Seat || 1) : new CF(s.g[0], s.g[1] + 3, s.g[2]).mul(CF.angles(0, s.yaw, 0));
        parts.push(...crewParts(cf, ['#f0aa3c', '#46a0dc', '#e65046', '#78c85a'][(rec.act.Crew - 1) % 4]));
      } else if (rec.act.Egg) {
        const e = eggTemplate(rec.act.Egg, rec.act.Scale || 1);
        const carrier = rec.act.HeldBy && fi / RATE >= beatS(rec.act.HeldFrom || 0) && b.actors[rec.act.HeldBy];
        let base = s.g;
        if (rec.act.Move && rec.act.Move.Pin && b.actors[rec.act.Move.Pin.Of].act.Rover) base = V.sub(s.g, [0, 0.5, 0]);
        else if (carrier) { const cs = carrier.st[fi]; base = V.add(cs.g, V.add(V.mul(fwdOf(cs.yaw), 1.4), [0, 2.4, 0])); }
        parts.push(...xformParts(e.parts, new CF(base[0], base[1] - e.b.min[1], base[2]).mul(CF.angles(0, s.yaw, 0))));
      }
    }
    const c = b.cam[fi];
    frames.push({ t: +(fi / RATE).toFixed(2), beat: +((fi / RATE) * BPM / 60).toFixed(2), shot: b.shot.Name, zone: b.shot.Zone, cam: { pos: c.pos, look: c.look, fov: c.fov, roll: c.roll }, parts });
  }
  return frames;
}

// ---------------------------------------------------------------- emit
const round = (x, d = 2) => +x.toFixed(d);
function emitShot(b) {
  const out = { Zone: b.shot.Zone, Beats: b.shot.Beats, Rate: RATE, N: b.n, Cam: [], Actors: [], Cues: [], Hand: b.shot.Cam.Hand || 0, Grade: b.shot.Grade || 'Hero' };
  // gameplay clips: the real HUD on screen (Camp hotbar, or the Run HUD staged with these numbers)
  if (b.shot.UI) out.UI = b.shot.UI;
  for (const c of b.cam) out.Cam.push(...c.pos.map((v) => round(v)), ...c.look.map((v) => round(v)), round(c.fov, 1), round(c.roll, 1));
  for (const [id, rec] of Object.entries(b.actors)) {
    const a = rec.act;
    const e = { Id: id };
    if (a.Dino) { e.Kind = 'Dino'; e.Species = a.Dino; e.Scale = rec.tpl.scale; }
    if (a.Baby) { e.Kind = 'Baby'; e.Species = a.Baby; }
    if (a.Rover) { e.Kind = 'Rover'; e.Name = a.Rover; }
    if (a.Crew) {
      e.Kind = 'Crew'; e.Crew = a.Crew;
      if (a.Ride) { e.Ride = a.Ride; e.Seat = a.Seat || 1; }
      if (a.Carry !== undefined) e.Carry = round(beatS(a.Carry === true ? 0 : a.Carry), 3);
      if (a.Combat) e.Combat = true;
    }
    if (a.Egg) {
      e.Kind = 'Egg'; e.Species = a.Egg; e.Scale = a.Scale || 1;
      if (a.HeldBy) { e.HeldBy = a.HeldBy; e.HeldFrom = round(beatS(a.HeldFrom || 0), 3); }
      if (a.Move && a.Move.Pin && a.Move.Pin.Slot) { e.Rack = a.Move.Pin.Of; e.Slot = a.Move.Pin.Slot; }
    }
    if (a.Prop) { e.Kind = 'Prop'; e.Prop = a.Prop; }
    if (a.Rarity) e.Rarity = a.Rarity;
    if (a.Hidden) e.ShowAt = round(beatS(a.Hidden[0]), 3);
    if (a.Until !== undefined) e.HideAt = round(beatS(a.Until), 3);
    if (a.Silhouette) e.Silhouette = a.Silhouette.map((x) => round(beatS(x), 3));
    if (a.EyesOnly) e.EyesOnly = true;
    if (a.Rim) e.Rim = a.Rim; // (the silhouette's rim light: a Fx.Colors name) // (a silhouette in the dark: no rim outline, just the eyes)
    if (a.Glow) e.Glow = a.Glow.map(([b0, b1]) => [round(beatS(b0), 3), round(beatS(b1), 3)]);
    if (a.Loop) e.Loop = a.Loop;
    if (a.Aim) e.Aim = a.Aim;
    if (a.Dino || a.Baby) {
      const prof = rec.tpl.prof;
      const loco = [[0, a.Loco || 'Idle']];
      for (const [bt, m] of a.LocoKeys || []) loco.push([round(beatS(bt), 3), m]);
      e.Loco = loco;
      e.Speeds = { Walk: prof.Gait.Walk.Freq, Run: prof.Gait.Run.Freq };
      if (a.Sig !== undefined) {
        e.Sig = { Action: prof.Intro || prof.Signature, From: a.Sig.From || 0 };
        e.SigT = rec.st.map((_, fi) => round(sigClock(a, prof, fi / RATE), 3));
      }
      e.Acts = (a.Acts || []).map(([bt, nm, sp = 1]) => [round(beatS(bt), 3), nm, sp]);
    }
    if (a.Crew) e.Acts = (a.Acts || []).map(([bt, nm]) => [round(beatS(bt), 3), nm]);
    const tr = [];
    for (const s of rec.st) {
      tr.push(round(s.g[0]), round(s.g[1]), round(s.g[2]), round(s.yaw, 3));
      if (a.Rover) tr.push(round(s.pitch, 3), round(s.roll, 3), round(s.travel, 2), round(s.steer, 3));
      if (a.Dino || a.Baby) tr.push(round(s.phase || 0, 3));
    }
    e.Track = tr;
    out.Actors.push(e);
  }
  // cues: positions resolved to world now
  for (const cue of b.shot.Cues || []) {
    const [bt, kind, ...args] = cue;
    const fi = clamp(Math.round(beatS(bt) * RATE), 0, b.n - 1);
    const res = args.map((x) => (x && typeof x === 'object' && !Array.isArray(x) && (x.Of || x.Gnd) ? { __v3: b.point(x, fi).map((v) => round(v)) } : Array.isArray(x) && x.length === 3 ? { __v3: b.A.pt(x).map((v) => round(v)) } : x));
    out.Cues.push([round(beatS(bt), 3), kind, ...res]);
  }
  out.Cues.sort((a, c) => a[0] - c[0]);
  return out;
}

const baked = {};
const reports = [];
const shotNames = Object.keys(DATA.Shots);
for (const nm of shotNames) {
  DATA.Shots[nm].Name = nm;
  try {
    const b = bakeShot(nm);
    baked[nm] = b;
    const issues = qcShot(b);
    reports.push({ nm, issues, score: DATA.Shots[nm].Score });
  } catch (e) {
    console.log(`tiktok: SHOT ${nm} FAILED: ${e.stack}`);
    reports.push({ nm, issues: ['BAKE FAILED: ' + e.message] });
  }
}

// --dump=Shot : print the solved anchor, actors and camera (debugging a placement)
const DUMP = (process.argv.find((a) => a.startsWith('--dump=')) || '').slice(7);
if (DUMP && baked[DUMP]) {
  const b = baked[DUMP];
  const f = (v) => v.map((x) => x.toFixed(1)).join(',');
  console.log('anchor', f(b.A.pos), 'fwd', f(b.A.f));
  for (const [id, r] of Object.entries(b.actors)) console.log(id, 'start', f(r.st[0].g), 'end', f(r.st[b.n - 1].g), 'yaw', r.st[0].yaw.toFixed(2));
  for (const fi of [0, b.n - 1]) console.log('cam', fi, f(b.cam[fi].pos), '->', f(b.cam[fi].look), 'fov', b.cam[fi].fov.toFixed(0));
}
// sequences must only use shots that exist and fit
for (const seq of DATA.Sequences) {
  for (const [nm, beats, off] of seq.Shots) {
    if (!DATA.Shots[nm]) console.log(`tiktok: ${seq.Id} uses unknown shot ${nm}`);
    else if (beats + (off || 0) > DATA.Shots[nm].Beats) console.log(`tiktok: ${seq.Id} wants ${beats} beats of ${nm} (baked ${DATA.Shots[nm].Beats})`);
  }
  // (a boss reveal is 15-25 s, and the den waits for it: Bosses.luau holds the fight for at most 30 s)
  if (seq.Boss) {
    const sec = beatS(seq.Shots.reduce((a, e) => a + e[1], 0));
    console.log(`tiktok: ${seq.Id} ${sec.toFixed(1)} s${sec < 15 || sec > 25 ? '  <-- outside 15-25 s' : ''}`);
  }
}

if (!QC_ONLY) {
  const shotsOut = {};
  for (const [nm, b] of Object.entries(baked)) if (!b.shot.Debug) shotsOut[nm] = emitShot(b);
  const seqs = DATA.Sequences.map((s) => Object.assign({ Id: s.Id, Name: s.Name, Category: s.Category, Hook: s.Hook || '', BPM: s.BPM || BPM, Shots: s.Shots.map(([nm, bt, off]) => (off ? [nm, bt, off] : [nm, bt])) }, s.Boss ? { Boss: s.Boss } : {}, s.Title ? { Title: s.Title } : {}));
  const lua = '-- GENERATED by tools/gen/tiktok.js from tools/gen/anim/tiktok.js — edit the JS source, then rebuild.\n--!nocheck\nreturn ' +
    toLuau({ Music: DATA.Music, Rate: RATE, Categories: DATA.Categories, Sequences: seqs, Shots: shotsOut }) + '\n';
  const p = path.join(ROOT, 'src/StarterPlayer/StarterPlayerScripts/DinoExpeditionClient/Game/TikTok/Data.luau');
  fs.writeFileSync(p, lua);
  console.log(`tiktok: wrote Data.luau (${(lua.length / 1024).toFixed(0)} KB, ${Object.keys(shotsOut).length} shots, ${seqs.length} sequences)`);
}

// QC frames: one file per sequence (3 frames per shot), env = parts near the cameras
function envFor(frames) {
  const keep = new Map();
  for (const fr of frames) {
    const z = ZONES[fr.zone];
    const c = fr.cam.pos;
    const f = V.unit(V.sub(fr.cam.look, c));
    z.preview.forEach((p, idx) => {
      const d = [p.cf[0] - c[0], p.cf[1] - c[1], p.cf[2] - c[2]];
      const L = Math.hypot(...d);
      if (L < 900 && (L < 60 || V.dot(d, f) / L > 0.35)) keep.set(fr.zone + idx, p);
    });
  }
  return [...keep.values()];
}
fs.mkdirSync(OUT_PREVIEW, { recursive: true });
// --shots=A,B : a QC sheet of just these shots (4 frames each) for fast iteration
const SHOTS_ARG = (process.argv.find((a) => a.startsWith('--shots=')) || '').slice(8);
if (SHOTS_ARG) {
  const frames = [];
  for (const nm of SHOTS_ARG.split(',')) {
    const b = baked[nm];
    if (!b) { console.log('tiktok: no shot ' + nm); continue; }
    const L = b.n - 1;
    frames.push(...qcFrames(b, [0, Math.round(L / 3), Math.round((2 * L) / 3), L]));
  }
  fs.writeFileSync(path.join(OUT_PREVIEW, 'tt_shots.json'), JSON.stringify({ env: envFor(frames), frames }));
  console.log(`tiktok: QC sheet tt_shots.json (${frames.length} frames)`);
}
for (const seq of DATA.Sequences) {
  if (SHOTS_ARG && !ONLY) continue;
  if (ONLY && seq.Id !== ONLY) continue;
  const frames = [];
  let at = 0;
  for (const shotEntry of seq.Shots) {
    const [nm, beats] = shotEntry;
    const b = baked[nm];
    if (!b) continue;
    const off = Math.round(beatS(shotEntry[2] || 0) * RATE);
    const last = Math.min(b.n - 1, off + Math.round(beatS(beats) * RATE) - 1);
    const fr = qcFrames(b, [off, Math.round((off + last) / 2), last]);
    for (const f of fr) { f.seqT = +(at + f.t).toFixed(2); f.seqBeat = +(at * BPM / 60 + f.beat).toFixed(2); }
    frames.push(...fr);
    at += beatS(beats);
  }
  const env = envFor(frames);
  fs.writeFileSync(path.join(OUT_PREVIEW, `tt_${seq.Id}.json`), JSON.stringify({ env, frames }));
  console.log(`tiktok: QC ${seq.Id}: ${frames.length} frames, ${env.length} env parts, ${at.toFixed(2)} s`);
}

// report
const lines = ['# TikTok QC report (generated)', '', `BPM ${BPM}; 1 beat = ${beatS(1).toFixed(3)} s`, ''];
for (const r of reports) {
  lines.push(`- **${r.nm}**${r.issues.length ? '' : ' — clean'}`);
  for (const i of r.issues) lines.push(`  - ${i}`);
}
fs.writeFileSync(path.join(OUT_PREVIEW, 'tt_report.md'), lines.join('\n'));
const bad = reports.filter((r) => r.issues.length);
console.log(`tiktok: ${reports.length} shots, ${bad.length} with QC notes (tools/preview/out/tt_report.md)`);
for (const r of bad) console.log('  ' + r.nm + ': ' + r.issues.slice(0, 4).join(' | '));
