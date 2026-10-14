// Route splines for guided expeditions.
// A route is a graph of segments (control points [x, y, z] in zone-local space) joined at nodes.
// Variants = every combination of fork choices; each is one continuous polyline the vehicle rides.
//   segment sampling: cubic Hermite through the control points (Catmull-Rom tangents inside a segment,
//   shared node tangents at segment ends so every branch joins smoothly).
const STEP = 2; // studs between samples

function sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
function add(a, b) { return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]; }
function mulv(a, k) { return [a[0] * k, a[1] * k, a[2] * k]; }
function len(a) { return Math.hypot(a[0], a[1], a[2]); }
function nrm(a) { const l = len(a) || 1; return mulv(a, 1 / l); }
function len2(a) { return Math.hypot(a[0], a[2]); }

function hermite(p0, m0, p1, m1, t) {
  const t2 = t * t, t3 = t2 * t;
  const h00 = 2 * t3 - 3 * t2 + 1, h10 = t3 - 2 * t2 + t, h01 = -2 * t3 + 3 * t2, h11 = t3 - t2;
  return [0, 1, 2].map((i) => h00 * p0[i] + h10 * m0[i] + h01 * p1[i] + h11 * m1[i]);
}

// def: { nodes: { name: { tangent?: [x,y,z] } }, segments: { id: { from, to, pts: [[x,y,z]...], width, name } } }
function sampleSegment(seg, nodeTan) {
  const P = seg.pts;
  const n = P.length;
  const tan = P.map((p, i) => {
    if (i === 0 && nodeTan[seg.from]) return nodeTan[seg.from];
    if (i === n - 1 && nodeTan[seg.to]) return nodeTan[seg.to];
    const a = P[Math.max(0, i - 1)], b = P[Math.min(n - 1, i + 1)];
    return mulv(sub(b, a), i === 0 || i === n - 1 ? 1 : 0.5);
  });
  const out = [];
  for (let i = 0; i < n - 1; i++) {
    const L = len(sub(P[i + 1], P[i]));
    const m0 = mulv(nrm(tan[i]), L), m1 = mulv(nrm(tan[i + 1]), L);
    // dense pre-sample, then resample at constant arc length
    const N = Math.max(8, Math.ceil(L * 2));
    for (let k = 0; k < N; k++) out.push(hermite(P[i], m0, P[i + 1], m1, k / N));
  }
  out.push(P[n - 1].slice());
  // arc-length resample
  const res = [out[0]];
  let acc = 0, prev = out[0];
  for (let i = 1; i < out.length; i++) {
    let d = len2(sub(out[i], prev));
    let cur = prev;
    while (acc + d >= STEP) {
      const t = (STEP - acc) / d;
      const q = add(cur, mulv(sub(out[i], cur), t));
      res.push(q);
      d -= STEP - acc; cur = q; acc = 0;
    }
    acc += d; prev = out[i];
  }
  const last = P[n - 1];
  if (len2(sub(res[res.length - 1], last)) > 0.3) res.push(last.slice());
  else res[res.length - 1] = last.slice();
  return res;
}

function buildRoute(def) {
  // node tangents: average of incoming end direction and outgoing start direction
  const nodeTan = {};
  for (const [name, nd] of Object.entries(def.nodes)) {
    if (nd.tangent) { nodeTan[name] = nd.tangent; continue; }
    let v = [0, 0, 0];
    for (const s of Object.values(def.segments)) {
      if (s.to === name) v = add(v, nrm(sub(s.pts[s.pts.length - 1], s.pts[s.pts.length - 2])));
      if (s.from === name) v = add(v, nrm(sub(s.pts[1], s.pts[0])));
    }
    if (len(v) > 0) nodeTan[name] = nrm([v[0], 0, v[2]]);
  }
  const segs = {};
  for (const [id, s] of Object.entries(def.segments)) segs[id] = Object.assign({ id, samples: sampleSegment(s, nodeTan) }, s);
  // variants: walk from the start node choosing every branch
  const variants = [];
  const walk = (node, path, choices) => {
    const outs = Object.values(segs).filter((s) => s.from === node);
    if (outs.length === 0) { variants.push({ segs: path, choices }); return; }
    if (outs.length === 1) return walk(outs[0].to, [...path, outs[0].id], choices);
    // fork: order branches so index 0 = the one that starts on the LEFT of travel
    const inTan = nodeTan[node];
    const right = [-inTan[2], 0, inTan[0]]; // Roblox-style right vector of a heading (x, z): (-z, 0, x)
    const ranked = outs.map((s) => ({ s, side: Math.sign(((s.samples[6] || s.samples[s.samples.length - 1])[0] - s.samples[0][0]) * right[0] + ((s.samples[6] || s.samples[s.samples.length - 1])[2] - s.samples[0][2]) * right[2]) })).sort((a, b) => a.side - b.side);
    ranked.forEach((r, k) => walk(r.s.to, [...path, r.s.id], [...choices, k]));
  };
  walk(def.start, [], []);
  // concatenate samples per variant with cumulative distance + per-sample segment index
  for (const v of variants) {
    const pts = [], segOf = [];
    v.segs.forEach((id, k) => {
      const smp = segs[id].samples;
      smp.forEach((p, i) => { if (k > 0 && i === 0) return; pts.push(p); segOf.push(k); });
    });
    const cum = [0];
    for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + len2(sub(pts[i], pts[i - 1])));
    v.pts = pts; v.cum = cum; v.segOf = segOf; v.length = cum[cum.length - 1];
    // segment start distances in this variant
    v.segStart = [];
    let k0 = -1;
    segOf.forEach((k, i) => { if (k !== k0) { v.segStart[k] = cum[i]; k0 = k; } });
  }
  return { segs, variants, nodeTan };
}

// frame at sample i of a polyline: pos, forward (xz), right
function frameAt(pts, i) {
  const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
  const f = nrm([b[0] - a[0], 0, b[2] - a[2]]);
  return { p: pts[i], f, r: [-f[2], 0, f[0]] };
}
// position at distance s and lateral x along a sample list (with its own cum array)
function at(pts, cum, s, x = 0, y = 0) {
  s = Math.max(0, Math.min(cum[cum.length - 1], s));
  let lo = 0, hi = cum.length - 1;
  while (hi - lo > 1) { const m = (lo + hi) >> 1; if (cum[m] <= s) lo = m; else hi = m; }
  const t = (s - cum[lo]) / Math.max(1e-6, cum[hi] - cum[lo]);
  const p = add(pts[lo], mulv(sub(pts[hi], pts[lo]), t));
  const f = nrm([pts[hi][0] - pts[lo][0], 0, pts[hi][2] - pts[lo][2]]);
  const r = [-f[2], 0, f[0]];
  return { p: [p[0] + r[0] * x, p[1] + y, p[2] + r[2] * x], f, r, base: p };
}
function cumOf(pts) { const c = [0]; for (let i = 1; i < pts.length; i++) c.push(c[i - 1] + len2(sub(pts[i], pts[i - 1]))); return c; }
// closest distance along a polyline to a point (xz)
function project(pts, cum, q) {
  let best = Infinity, bs = 0, bx = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i], b = pts[i + 1];
    const d = [b[0] - a[0], b[2] - a[2]];
    const L2 = d[0] * d[0] + d[1] * d[1] || 1e-6;
    let t = ((q[0] - a[0]) * d[0] + (q[2] - a[2]) * d[1]) / L2;
    t = Math.max(0, Math.min(1, t));
    const px = a[0] + d[0] * t, pz = a[2] + d[1] * t;
    const dist = Math.hypot(q[0] - px, q[2] - pz);
    if (dist < best) {
      best = dist; bs = cum[i] + Math.sqrt(L2) * t;
      const L = Math.sqrt(L2);
      const r = [-d[1] / L, d[0] / L];
      bx = (q[0] - px) * r[0] + (q[2] - pz) * r[1];
    }
  }
  return { s: bs, x: bx, dist: best };
}

module.exports = { buildRoute, frameAt, at, cumOf, project, STEP };
