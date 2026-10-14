// Clipping QC: z-fighting faces, wheel/body interpenetration, and animated segment interpenetration.
// Usage (from build.js): qc.zFight(parts), qc.penetration(a, b), qc.animatedClipping(...)

function obb(p) {
  const [x, y, z, a, b, c, d, e, f, g, h, i] = p.cf;
  return {
    c: [x, y, z],
    ax: [[a, d, g], [b, e, h], [c, f, i]], // right, up, back
    h: p.s.map((v) => v / 2),
    r: Math.hypot(...p.s) / 2,
  };
}
const dot = (u, v) => u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
const cross = (u, v) => [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
const sub = (u, v) => [u[0] - v[0], u[1] - v[1], u[2] - v[2]];

// Minimum overlap depth along all separating axes (<= 0: separated)
function penetration(A, B) {
  const T = sub(B.c, A.c);
  if (Math.hypot(...T) > A.r + B.r) return 0;
  let min = Infinity;
  const axes = [...A.ax, ...B.ax];
  for (const a of A.ax) for (const b of B.ax) { const c = cross(a, b); const l = Math.hypot(...c); if (l > 1e-4) axes.push(c.map((v) => v / l)); }
  for (const L of axes) {
    const ra = A.h[0] * Math.abs(dot(A.ax[0], L)) + A.h[1] * Math.abs(dot(A.ax[1], L)) + A.h[2] * Math.abs(dot(A.ax[2], L));
    const rb = B.h[0] * Math.abs(dot(B.ax[0], L)) + B.h[1] * Math.abs(dot(B.ax[1], L)) + B.h[2] * Math.abs(dot(B.ax[2], L));
    const o = ra + rb - Math.abs(dot(T, L));
    if (o <= 0) return 0;
    if (o < min) min = o;
  }
  return min;
}

// Faces of a box-ish part: [normal, center, u-axis, v-axis, hu, hv]
function faces(p, O) {
  const out = [];
  const kinds = p.k === 'box' ? [0, 1, 2] : p.k === 'wedge' ? [0, 1, 2] : [];
  for (const k of kinds) for (const sgn of [-1, 1]) {
    if (p.k === 'wedge' && !((k === 1 && sgn < 0) || (k === 2 && sgn > 0) || k === 0)) continue; // wedge: bottom, back, sides
    const n = O.ax[k].map((v) => v * sgn);
    const c = O.c.map((v, i) => v + n[i] * O.h[k]);
    const [ui, vi] = [0, 1, 2].filter((x) => x !== k);
    out.push({ n, c, u: O.ax[ui], v: O.ax[vi], hu: O.h[ui], hv: O.h[vi] });
  }
  return out;
}

function rectOverlapArea(F, G) {
  // project G's corners into F's (u, v) basis and intersect AABBs (approximation for in-plane rotation)
  const corners = [];
  for (const su of [-1, 1]) for (const sv of [-1, 1]) corners.push(G.c.map((x, i) => x + G.u[i] * G.hu * su + G.v[i] * G.hv * sv));
  const us = corners.map((p) => dot(sub(p, F.c), F.u)), vs = corners.map((p) => dot(sub(p, F.c), F.v));
  const du = Math.min(F.hu, Math.max(...us)) - Math.max(-F.hu, Math.min(...us));
  const dv = Math.min(F.hv, Math.max(...vs)) - Math.max(-F.hv, Math.min(...vs));
  return du > 0 && dv > 0 ? du * dv : 0;
}

// Coplanar, overlapping faces of differently coloured/material parts (flicker in Roblox)
function zFight(parts, { tol = 0.012, minArea = 0.02 } = {}) {
  const items = parts.filter((p) => p.t < 1 && (p.k === 'box' || p.k === 'wedge')).map((p) => ({ p, O: obb(p) }));
  for (const it of items) it.F = faces(it.p, it.O);
  const hits = [];
  for (let i = 0; i < items.length; i++) for (let j = i + 1; j < items.length; j++) {
    const A = items[i], B = items[j];
    if (A.p.c === B.p.c && A.p.m === B.p.m) continue;
    if (Math.hypot(...sub(A.O.c, B.O.c)) > A.O.r + B.O.r + 0.05) continue;
    for (const F of A.F) for (const G of B.F) {
      if (dot(F.n, G.n) < 0.999) continue; // same-facing coplanar faces flicker; back-to-back contact doesn't
      if (Math.abs(dot(sub(G.c, F.c), F.n)) > tol) continue;
      const area = rectOverlapArea(F, G);
      if (area > minArea) hits.push({ a: A.p.n, b: B.p.n, area: +area.toFixed(3), at: F.c.map((v) => +v.toFixed(2)) });
    }
  }
  return hits;
}

// Pairs of parts on different bones whose overlap grows significantly in a pose vs. rest
function animatedClipping(restParts, poses, { min = 0.12, rel = 0.18, adjacent = new Set() } = {}) {
  const idx = restParts.map((p, i) => i).filter((i) => restParts[i].t < 1 && restParts[i].bone);
  const rest = restParts.map(obb);
  const restPen = new Map();
  const key = (i, j) => i * 100000 + j;
  for (const i of idx) for (const j of idx) if (j > i && restParts[i].bone !== restParts[j].bone) {
    const pv = penetration(rest[i], rest[j]);
    restPen.set(key(i, j), pv);
  }
  const worst = new Map();
  for (const { name, parts } of poses) {
    const O = parts.map(obb);
    for (const i of idx) for (const j of idx) {
      if (j <= i || restParts[i].bone === restParts[j].bone) continue;
      if (adjacent.has(restParts[i].bone + '>' + restParts[j].bone) || adjacent.has(restParts[j].bone + '>' + restParts[i].bone)) continue;
      const pen = penetration(O[i], O[j]);
      if (pen <= 0) continue;
      const delta = pen - (restPen.get(key(i, j)) || 0);
      const small = Math.min(...restParts[i].s, ...restParts[j].s);
      if (delta > Math.max(min, small * rel)) {
        const k = key(i, j);
        const w = worst.get(k);
        if (!w || w.delta < delta) worst.set(k, { a: `${restParts[i].bone}/${restParts[i].n}`, b: `${restParts[j].bone}/${restParts[j].n}`, delta: +delta.toFixed(2), pose: name });
      }
    }
  }
  return [...worst.values()].sort((x, y) => y.delta - x.delta);
}

// Nudge apart coplanar same-facing faces: the smaller part grows slightly along that face's axis
function resolveZFight(root, passes = 3) {
  let total = 0;
  for (let pass = 0; pass < passes; pass++) {
    const items = [];
    root.walk((i) => { if (i._preview && !i._isBone && i._preview.t < 1 && (i._preview.kind === 'box' || i._preview.kind === 'wedge')) items.push(i); });
    const objs = items.map((i) => { const cf = i._cf; const p = { k: i._preview.kind, s: i._preview.size, cf: [cf.x, cf.y, cf.z, ...cf.r] }; const O = obb(p); return { i, p, O, F: faces(p, O) }; });
    let fixed = 0;
    const touched = new Set();
    for (let a = 0; a < objs.length; a++) for (let b = a + 1; b < objs.length; b++) {
      const A = objs[a], Bo = objs[b];
      if (touched.has(A.i) || touched.has(Bo.i)) continue;
      if (A.i._preview.color === Bo.i._preview.color && A.i._preview.mat === Bo.i._preview.mat) continue;
      if (Math.hypot(...sub(A.O.c, Bo.O.c)) > A.O.r + Bo.O.r + 0.05) continue;
      let hit = null;
      for (const F of A.F) { for (const G of Bo.F) {
        if (dot(F.n, G.n) < 0.999 || Math.abs(dot(sub(G.c, F.c), F.n)) > 0.012) continue;
        if (rectOverlapArea(F, G) > 0.01) { hit = F.n; break; }
      } if (hit) break; }
      if (!hit) continue;
      const volA = A.p.s[0] * A.p.s[1] * A.p.s[2], volB = Bo.p.s[0] * Bo.p.s[1] * Bo.p.s[2];
      const small = volA <= volB ? A : Bo;
      // axis of the part most aligned with the face normal
      const k = [0, 1, 2].reduce((best, ax) => (Math.abs(dot(small.O.ax[ax], hit)) > Math.abs(dot(small.O.ax[best], hit)) ? ax : best), 0);
      const sz = small.i._preview.size;
      sz[k] += 0.04;
      small.i.props.size[1] = sz.map((v) => Math.max(0.05, +v.toFixed(4)));
      touched.add(small.i);
      fixed++;
    }
    total += fixed;
    if (!fixed) break;
  }
  return total;
}

module.exports = { obb, penetration, zFight, animatedClipping, resolveZFight };
