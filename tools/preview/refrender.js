// Reference renders of the REAL generated models, straight to PNG (no browser, no deps).
// A small software rasterizer: flat-shaded blocky parts (that's the Roblox look), Roblox studs, a sun with a soft
// shadow map, sky/ground ambient, a cool rim light, toon outlines from an id/depth edge pass, 2x supersampling,
// transparent background with a soft contact shadow. Used to make reference sheets for image models.
//
//   node tools/preview/refrender.js <job.json>
//   job: { file, out, w, h, groups: [...], az, el, zoom, fov, cam: [x,y,z], look: [x,y,z], bg: "none"|"#hex",
//          ground: "shadow"|"none", ss: 2, outline: 1.6, studs: true, pose: optional }
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// ------------------------------------------------------------------ math
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const mul = (a, k) => [a[0] * k, a[1] * k, a[2] * k];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm = (a) => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
const hex = (h) => { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => Math.pow(v / 255, 2.2)); };

// ------------------------------------------------------------------ unit meshes (triangles in local -0.5..0.5)
function boxTris() {
  const v = (x, y, z) => [x - 0.5, y - 0.5, z - 0.5];
  const q = (a, b, c, d) => [[a, b, c], [a, c, d]];
  return [
    ...q(v(0, 0, 0), v(1, 0, 0), v(1, 0, 1), v(0, 0, 1)), ...q(v(0, 1, 0), v(0, 1, 1), v(1, 1, 1), v(1, 1, 0)),
    ...q(v(0, 0, 0), v(0, 1, 0), v(1, 1, 0), v(1, 0, 0)), ...q(v(0, 0, 1), v(1, 0, 1), v(1, 1, 1), v(0, 1, 1)),
    ...q(v(0, 0, 0), v(0, 0, 1), v(0, 1, 1), v(0, 1, 0)), ...q(v(1, 0, 0), v(1, 1, 0), v(1, 1, 1), v(1, 0, 1)),
  ];
}
function wedgeTris() {
  const v = [[-.5, -.5, -.5], [.5, -.5, -.5], [.5, -.5, .5], [-.5, -.5, .5], [-.5, .5, .5], [.5, .5, .5]];
  return [[0, 2, 1], [0, 3, 2], [3, 4, 5], [3, 5, 2], [0, 1, 5], [0, 5, 4], [0, 4, 3], [1, 2, 5]].map((t) => t.map((i) => v[i]));
}
function cylTris(n, axis) { // axis 'x' (Roblox cylinder) or 'y' (a stud)
  const tris = [];
  const P = (a, h) => axis === 'x' ? [h, Math.cos(a) * 0.5, Math.sin(a) * 0.5] : [Math.cos(a) * 0.5, h, Math.sin(a) * 0.5];
  for (let k = 0; k < n; k++) {
    const a0 = (k / n) * Math.PI * 2, a1 = ((k + 1) / n) * Math.PI * 2;
    const A = P(a0, -0.5), B = P(a1, -0.5), C = P(a1, 0.5), D = P(a0, 0.5);
    tris.push([A, B, C], [A, C, D]);
    const c0 = axis === 'x' ? [-0.5, 0, 0] : [0, -0.5, 0], c1 = axis === 'x' ? [0.5, 0, 0] : [0, 0.5, 0];
    tris.push([c0, B, A], [c1, D, C]);
  }
  return tris;
}
function sphereTris(nu, nv) {
  const tris = [];
  const P = (u, v) => { const th = u * Math.PI * 2, ph = v * Math.PI; return [Math.sin(ph) * Math.cos(th) * 0.5, Math.cos(ph) * 0.5, Math.sin(ph) * Math.sin(th) * 0.5]; };
  for (let i = 0; i < nu; i++) for (let j = 0; j < nv; j++) {
    const a = P(i / nu, j / nv), b = P((i + 1) / nu, j / nv), c = P((i + 1) / nu, (j + 1) / nv), d = P(i / nu, (j + 1) / nv);
    tris.push([a, c, b], [a, d, c]);
  }
  return tris;
}
const MESH = { box: boxTris(), wedge: wedgeTris(), cyl: cylTris(28, 'x'), ball: sphereTris(24, 14), ellipsoid: sphereTris(24, 14) };
const STUD = cylTris(14, 'y');

// ------------------------------------------------------------------ scene
function loadParts(job) {
  const data = JSON.parse(fs.readFileSync(job.file, 'utf8'));
  const want = job.groups ? new Set(job.groups) : null;
  const parts = [];
  for (const g of data.groups) {
    if (want && !want.has(g.name)) continue;
    const off = (job.offsets && job.offsets[g.name]) || null;
    for (const p of g.parts) if (p.t < 1) parts.push(off ? Object.assign({}, p, { cf: [p.cf[0] + off[0], p.cf[1] + off[1], p.cf[2] + off[2], ...p.cf.slice(3)] }) : p);
  }
  // a lagoon/sea plane (Terrain water is filled at runtime, so it isn't in the model data)
  if (job.water) {
    const w = job.water;
    // tiled (a single huge quad loses its triangles once a corner is behind the camera)
    const size = w.size || 4000, tile = 50, n = Math.ceil(size / tile);
    const cx = w.x ?? 600, cz = w.z ?? 150;
    for (let a = 0; a < n; a++) for (let b = 0; b < n; b++) {
      parts.push({ k: 'box', s: [tile, 0.2, tile], cf: [cx - size / 2 + (a + 0.5) * tile, w.y ?? -1.3, cz - size / 2 + (b + 0.5) * tile, 1, 0, 0, 0, 1, 0, 0, 0, 1], c: w.color || '#2aa6b8', t: w.t ?? 0.12, m: 'Water', st: 0 });
    }
  }
  if (job.clip) { // keep parts whose centre is inside a world box [x0,y0,z0,x1,y1,z1]
    const [x0, y0, z0, x1, y1, z1] = job.clip;
    return parts.filter((p) => p.m === 'Water' || (p.cf[0] >= x0 && p.cf[0] <= x1 && p.cf[1] >= y0 && p.cf[1] <= y1 && p.cf[2] >= z0 && p.cf[2] <= z1));
  }
  return parts;
}
// world triangles: { v:[3][3], n:[3], c:[3] linear, emit, alpha, id }
function buildTris(parts, studs) {
  const out = [];
  parts.forEach((p, id) => {
    const [x, y, z, a, b, c, d, e, f, g, h, i] = p.cf;
    const s = p.s;
    const xf = (l) => { const lx = l[0] * s[0], ly = l[1] * s[1], lz = l[2] * s[2]; return [a * lx + b * ly + c * lz + x, d * lx + e * ly + f * lz + y, g * lx + h * ly + i * lz + z]; };
    const col = hex(p.c);
    const emit = p.m === 'Neon' ? 1 : 0;
    const alpha = 1 - (p.t || 0);
    if (p.m === 'Water') id = 999999; // (one id for every water tile: no outline lines between them)
    const shininess = p.m === 'Water' ? 0.5 : ((p.m === 'Metal' || p.m === 'DiamondPlate' || p.m === 'Glass') ? 0.35 : (p.m === 'SmoothPlastic' || p.m === 'Plastic' ? 0.18 : 0.06));
    for (const t of MESH[p.k] || MESH.box) {
      const v = t.map(xf);
      const n = norm(cross(sub(v[1], v[0]), sub(v[2], v[0])));
      out.push({ v, n, c: col, emit, alpha, id, spec: shininess });
    }
    if (studs && p.st && p.k === 'box') {
      const nx = Math.floor(s[0] + 0.01), nz = Math.floor(s[2] + 0.01);
      if (nx >= 1 && nz >= 1 && nx * nz <= 400) {
        const sc = col.map((v) => Math.min(1, v * 1.08 + 0.01));
        for (let u = 0; u < nx; u++) for (let w = 0; w < nz; w++) {
          const lx = -s[0] / 2 + (s[0] - nx) / 2 + u + 0.5, lz = -s[2] / 2 + (s[2] - nz) / 2 + w + 0.5;
          const sx = (l) => { const px = l[0] * 0.6 + lx, py = l[1] * 0.16 + s[1] / 2 + 0.08, pz = l[2] * 0.6 + lz; return [a * px + b * py + c * pz + x, d * px + e * py + f * pz + y, g * px + h * py + i * pz + z]; };
          for (const t of STUD) {
            const v = t.map(sx);
            const n = norm(cross(sub(v[1], v[0]), sub(v[2], v[0])));
            out.push({ v, n, c: sc, emit, alpha, id, spec: 0.18 });
          }
        }
      }
    }
  });
  return out;
}

// ------------------------------------------------------------------ rasterizer core
// project: world -> [sx, sy, depth(view z, positive), invw]
function rasterize(tris, W, H, project, onPixel, cull) {
  for (let ti = 0; ti < tris.length; ti++) {
    const t = tris[ti];
    const p = t.v.map(project);
    if (p.some((q) => q === null)) continue;
    const area = (p[1][0] - p[0][0]) * (p[2][1] - p[0][1]) - (p[2][0] - p[0][0]) * (p[1][1] - p[0][1]);
    if (cull && area >= 0) continue; // (screen y grows down: front faces come out negative)
    if (Math.abs(area) < 1e-9) continue;
    const minx = Math.max(0, Math.floor(Math.min(p[0][0], p[1][0], p[2][0])));
    const maxx = Math.min(W - 1, Math.ceil(Math.max(p[0][0], p[1][0], p[2][0])));
    const miny = Math.max(0, Math.floor(Math.min(p[0][1], p[1][1], p[2][1])));
    const maxy = Math.min(H - 1, Math.ceil(Math.max(p[0][1], p[1][1], p[2][1])));
    if (minx > maxx || miny > maxy) continue;
    const inv = 1 / area;
    for (let y = miny; y <= maxy; y++) {
      const py = y + 0.5;
      for (let x = minx; x <= maxx; x++) {
        const px = x + 0.5;
        let w0 = ((p[1][0] - px) * (p[2][1] - py) - (p[2][0] - px) * (p[1][1] - py)) * inv;
        let w1 = ((p[2][0] - px) * (p[0][1] - py) - (p[0][0] - px) * (p[2][1] - py)) * inv;
        let w2 = 1 - w0 - w1;
        if (w0 < -1e-6 || w1 < -1e-6 || w2 < -1e-6) continue;
        // perspective-correct weights
        const a0 = w0 * p[0][3], a1 = w1 * p[1][3], a2 = w2 * p[2][3];
        const sw = a0 + a1 + a2;
        const z = (w0 * p[0][2] + w1 * p[1][2] + w2 * p[2][2]);
        onPixel(x, y, z, ti, a0 / sw, a1 / sw, a2 / sw);
      }
    }
  }
}

// ------------------------------------------------------------------ PNG
function writePNG(file, W, H, rgba) {
  const crcTable = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
  const crc = (buf) => { let c = -1; for (const b of buf) c = crcTable[(c ^ b) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
    return Buffer.concat([len, td, c]);
  };
  const raw = Buffer.alloc((W * 4 + 1) * H);
  for (let y = 0; y < H; y++) { raw[y * (W * 4 + 1)] = 0; rgba.copy(raw, y * (W * 4 + 1) + 1, y * W * 4, (y + 1) * W * 4); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 6;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 6 })), chunk('IEND', Buffer.alloc(0))]));
}

// ------------------------------------------------------------------ render
function render(job) {
  const SS = job.ss || 2;
  const W = (job.w || 1400) * SS, H = (job.h || 1400) * SS;
  const parts = loadParts(job);
  if (!parts.length) throw new Error('no parts for ' + JSON.stringify(job.groups));
  const tris = buildTris(parts, job.studs !== false);
  // bounds
  const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  for (const t of tris) for (const v of t.v) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], v[k]); mx[k] = Math.max(mx[k], v[k]); }
  const center = mul(add(mn, mx), 0.5), size = sub(mx, mn), radius = Math.hypot(...size) / 2;
  // camera
  const fov = (job.fov || 28) * Math.PI / 180;
  let eye, look;
  if (job.cam) { eye = job.cam; look = job.look || center; }
  else {
    const A = (job.az ?? 35) * Math.PI / 180, E = (job.el ?? 14) * Math.PI / 180;
    const aspect = W / H;
    const fit = Math.max(size[1], Math.max(size[0], size[2]) / Math.max(0.6, aspect)) * 0.58;
    const dist = (fit / Math.tan(fov / 2)) / (job.zoom || 1) + radius * 0.3;
    eye = [center[0] + Math.sin(A) * Math.cos(E) * dist, center[1] + Math.sin(E) * dist, center[2] - Math.cos(A) * Math.cos(E) * dist];
    look = job.look || center;
  }
  const fwd = norm(sub(look, eye)), right = norm(cross(fwd, [0, 1, 0])), up = cross(right, fwd);
  const f = (H / 2) / Math.tan(fov / 2);
  const project = (v) => {
    const d = sub(v, eye);
    const z = dot(d, fwd);
    if (z < 0.05) return null;
    return [W / 2 + dot(d, right) * f / z, H / 2 - dot(d, up) * f / z, z, 1 / z];
  };
  // lights (sun from the camera's upper left, a little behind the subject's shoulder)
  const camAz = Math.atan2(eye[0] - center[0], -(eye[2] - center[2]));
  const sunAz = camAz - (job.sunAz ?? 0.9), sunEl = (job.sunEl ?? 52) * Math.PI / 180;
  const sunDir = norm([Math.sin(sunAz) * Math.cos(sunEl), Math.sin(sunEl), -Math.cos(sunAz) * Math.cos(sunEl)]); // towards the sun
  const rimDir = norm([-(eye[0] - center[0]), radius * 0.6, -(eye[2] - center[2])]);
  // shadow map (orthographic, along -sunDir)
  const SM = 2048;
  const sR = norm(cross(sunDir, Math.abs(sunDir[1]) > 0.99 ? [1, 0, 0] : [0, 1, 0])), sU = cross(sR, sunDir);
  const shadowSpan = (job.shadowSpan || radius * 1.25);
  const smDepth = new Float32Array(SM * SM).fill(Infinity);
  const sproj = (v) => { const d = sub(v, center); return [SM / 2 + dot(d, sR) / shadowSpan * SM / 2, SM / 2 - dot(d, sU) / shadowSpan * SM / 2, -dot(d, sunDir), 1]; };
  rasterize(tris.filter((t) => t.alpha > 0.7), SM, SM, sproj, (x, y, z) => { const k = y * SM + x; if (z < smDepth[k]) smDepth[k] = z; }, false);
  const texel = shadowSpan * 2 / SM;
  const shadowAt = (wp, n) => {
    const o = add(wp, mul(n, texel * 1.5));
    const s = sproj(o);
    let lit = 0, cnt = 0;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      const x = Math.floor(s[0]) + dx, y = Math.floor(s[1]) + dy;
      cnt++;
      if (x < 0 || y < 0 || x >= SM || y >= SM) { lit++; continue; }
      if (s[2] <= smDepth[y * SM + x] + texel * 2) lit++;
    }
    return lit / cnt;
  };
  // main pass: id + depth + colour
  const depth = new Float32Array(W * H).fill(Infinity);
  const ids = new Int32Array(W * H).fill(-1);
  const col = new Float32Array(W * H * 3);
  const nrm = new Float32Array(W * H * 3);
  const sky = [0.86, 0.9, 1.0], grd = [0.42, 0.38, 0.32];
  const shade = (t, wp, viewDir) => {
    const n = t.n;
    if (t.emit) return t.c.map((v) => v * 1.25 + 0.05);
    const hy = n[1] * 0.5 + 0.5;
    const amb = [sky[0] * hy + grd[0] * (1 - hy), sky[1] * hy + grd[1] * (1 - hy), sky[2] * hy + grd[2] * (1 - hy)];
    const nl = Math.max(0, dot(n, sunDir));
    const sh = nl > 0 ? shadowAt(wp, n) : 0;
    const sun = nl * sh * 1.55;
    const rim = Math.pow(Math.max(0, 1 - Math.abs(dot(n, viewDir))), 3) * Math.max(0, dot(n, rimDir)) * 0.9;
    const hvec = norm(add(sunDir, viewDir));
    const spec = Math.pow(Math.max(0, dot(n, hvec)), 40) * t.spec * sh * 2.2;
    return [0, 1, 2].map((k) => t.c[k] * (amb[k] * 0.62 + sun * [1.0, 0.96, 0.9][k]) + rim * [0.75, 0.86, 1.0][k] * 0.55 + spec);
  };
  const opaque = tris.map((t, i) => i).filter((i) => tris[i].alpha > 0.7);
  const glass = tris.map((t, i) => i).filter((i) => tris[i].alpha <= 0.7);
  rasterize(opaque.map((i) => tris[i]), W, H, project, (x, y, z, ti, a0, a1, a2) => {
    const k = y * W + x;
    if (z >= depth[k]) return;
    depth[k] = z;
    const t = tris[opaque[ti]];
    const wp = [0, 1, 2].map((c) => t.v[0][c] * a0 + t.v[1][c] * a1 + t.v[2][c] * a2);
    const viewDir = norm(sub(eye, wp));
    const c = shade(t, wp, viewDir);
    ids[k] = t.id;
    col[k * 3] = c[0]; col[k * 3 + 1] = c[1]; col[k * 3 + 2] = c[2];
    nrm[k * 3] = t.n[0]; nrm[k * 3 + 1] = t.n[1]; nrm[k * 3 + 2] = t.n[2];
  }, true);
  const alphaBuf = new Float32Array(W * H);
  for (let k = 0; k < W * H; k++) alphaBuf[k] = ids[k] >= 0 ? 1 : 0;
  // glass / see-through parts: blended on top (back to front by triangle centre)
  glass.sort((a, b) => {
    const ca = tris[a].v.reduce((s, v) => s + dot(sub(v, eye), fwd), 0), cb = tris[b].v.reduce((s, v) => s + dot(sub(v, eye), fwd), 0);
    return cb - ca;
  });
  rasterize(glass.map((i) => tris[i]), W, H, project, (x, y, z, ti, a0, a1, a2) => {
    const k = y * W + x;
    if (z >= depth[k]) return;
    const t = tris[glass[ti]];
    const wp = [0, 1, 2].map((c) => t.v[0][c] * a0 + t.v[1][c] * a1 + t.v[2][c] * a2);
    const c = shade(t, wp, norm(sub(eye, wp)));
    const al = t.alpha;
    for (let q = 0; q < 3; q++) col[k * 3 + q] = col[k * 3 + q] * (1 - al) + c[q] * al;
    alphaBuf[k] = Math.max(alphaBuf[k], al);
  }, false);
  // contact shadow on an invisible ground plane (transparent renders keep a soft shadow under the model)
  const groundY = mn[1] + 0.01;
  const shadowA = new Float32Array(W * H);
  if ((job.ground || 'shadow') === 'shadow') {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const k = y * W + x;
      if (ids[k] >= 0) continue;
      const dirx = (x + 0.5 - W / 2) / f, diry = -(y + 0.5 - H / 2) / f;
      const ray = norm(add(add(fwd, mul(right, dirx)), mul(up, diry)));
      if (ray[1] >= -1e-4) continue;
      const tt = (groundY - eye[1]) / ray[1];
      const wp = add(eye, mul(ray, tt));
      const dc = Math.hypot(wp[0] - center[0], wp[2] - center[2]);
      if (dc > radius * 2.2) continue;
      const lit = shadowAt(wp, [0, 1, 0]);
      shadowA[k] = (1 - lit) * 0.34 * Math.max(0, 1 - dc / (radius * 2.2));
    }
  }
  // toon outlines: where the part id changes across a depth jump, or the silhouette
  const ow = Math.max(1, Math.round((job.outline || 1.6) * SS));
  const edge = new Float32Array(W * H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const k = y * W + x, id = ids[k];
    let e = 0;
    for (let d = 1; d <= ow && e < 1; d++) {
      for (const [dx, dy] of [[d, 0], [-d, 0], [0, d], [0, -d]]) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
        const k2 = yy * W + xx, id2 = ids[k2];
        if (id2 === id) continue;
        if (id < 0 || id2 < 0) { e = Math.max(e, id >= 0 ? 1 : 0); continue; } // silhouette: drawn on the model side
        const z1 = depth[k], z2 = depth[k2];
        const jump = Math.abs(z1 - z2) / Math.min(z1, z2);
        if (z1 <= z2 && jump > 0.004) e = Math.max(e, 0.85);
        else if (d === 1) {
          const nd = nrm[k * 3] * nrm[k2 * 3] + nrm[k * 3 + 1] * nrm[k2 * 3 + 1] + nrm[k * 3 + 2] * nrm[k2 * 3 + 2];
          if (nd < 0.8 && z1 <= z2) e = Math.max(e, 0.35); // a crease between two touching parts
        }
      }
    }
    edge[k] = e;
  }
  // compose + tone map + downsample
  const bg = job.bg && job.bg !== 'none' ? hex(job.bg) : null;
  const ow2 = job.w || 1400, oh2 = job.h || 1400;
  const outBuf = Buffer.alloc(ow2 * oh2 * 4);
  const tone = (v) => { const a = v * 1.0; const m = (a * (2.51 * a + 0.03)) / (a * (2.43 * a + 0.59) + 0.14); return Math.pow(Math.min(1, Math.max(0, m)), 1 / 2.2); };
  const ink = [0.02, 0.025, 0.035];
  for (let y = 0; y < oh2; y++) for (let x = 0; x < ow2; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
      const k = (y * SS + sy) * W + (x * SS + sx);
      let pr, pg, pb, pa;
      if (ids[k] >= 0 || alphaBuf[k] > 0) {
        pr = tone(col[k * 3]); pg = tone(col[k * 3 + 1]); pb = tone(col[k * 3 + 2]); pa = alphaBuf[k];
        const e = edge[k];
        pr = pr * (1 - e) + ink[0] * e; pg = pg * (1 - e) + ink[1] * e; pb = pb * (1 - e) + ink[2] * e;
      } else if (bg) {
        const s = shadowA[k];
        pr = Math.pow(bg[0], 1 / 2.2) * (1 - s); pg = Math.pow(bg[1], 1 / 2.2) * (1 - s); pb = Math.pow(bg[2], 1 / 2.2) * (1 - s); pa = 1;
      } else { pr = 0; pg = 0; pb = 0; pa = shadowA[k]; }
      r += pr * pa; g += pg * pa; b += pb * pa; a += pa;
    }
    const o = (y * ow2 + x) * 4, n = SS * SS;
    outBuf[o + 3] = Math.round((a / n) * 255);
    if (a > 0) { outBuf[o] = Math.round((r / a) * 255); outBuf[o + 1] = Math.round((g / a) * 255); outBuf[o + 2] = Math.round((b / a) * 255); }
  }
  // crop to the model (+ its shadow) with a margin: references read best filled, not floating in empty space
  if (job.crop !== false) {
    let x0 = ow2, y0 = oh2, x1 = -1, y1 = -1;
    for (let y = 0; y < oh2; y++) for (let x = 0; x < ow2; x++) if (outBuf[(y * ow2 + x) * 4 + 3] > 10) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    if (x1 > x0 && y1 > y0) {
      const m = Math.round(Math.max(x1 - x0, y1 - y0) * (job.margin ?? 0.06));
      x0 = Math.max(0, x0 - m); y0 = Math.max(0, y0 - m); x1 = Math.min(ow2 - 1, x1 + m); y1 = Math.min(oh2 - 1, y1 + m);
      const cw = x1 - x0 + 1, ch = y1 - y0 + 1;
      const cb = Buffer.alloc(cw * ch * 4);
      for (let y = 0; y < ch; y++) outBuf.copy(cb, y * cw * 4, ((y + y0) * ow2 + x0) * 4, ((y + y0) * ow2 + x1 + 1) * 4);
      writePNG(job.out, cw, ch, cb);
      return { tris: tris.length, size, out: job.out, px: [cw, ch] };
    }
  }
  writePNG(job.out, ow2, oh2, outBuf);
  return { tris: tris.length, size, out: job.out, px: [ow2, oh2] };
}

module.exports = { render };
if (require.main === module) {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  for (const job of (Array.isArray(jobs) ? jobs : [jobs])) {
    const t0 = Date.now();
    const r = render(job);
    console.log(`${path.basename(r.out)}  ${r.px.join('x')}  ${r.tris} tris  ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  }
}
