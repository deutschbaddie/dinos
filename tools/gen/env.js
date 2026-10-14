// Environment kit shared by Base Camp and the eras: chunky studded jungle, cliffs, water, camp props.
// Everything is anchored. Decor never collides (cheap + no snagging); ground, buildings and big rocks do.
const { Inst, Ctx, CF, shade, mix, rng, styledText } = require('./builder.js');

const PAL = {
  grass: '#6cae45', grassHi: '#7fc152', grassLo: '#5a9a3a', grassDk: '#4a8432',
  dirt: '#b98a56', dirtLo: '#9c7046', dirtHi: '#cfa16a', mud: '#7a5636',
  leaf: ['#2f8a3a', '#3f9a3a', '#4fb043', '#2a7a34', '#5bbd4a'],
  trunk: ['#6b4a2b', '#7d5733'], root: '#5e3f22',
  rock: ['#7d7a73', '#6c6962', '#8a857b', '#5f5c56'], moss: '#5f8f3e',
  cliff: ['#9a7650', '#8a6a48', '#a8845a', '#7a5c3e', '#86705a'],
  water: '#5fc8f0', waterDeep: '#2f8fc8', foam: '#eaf8ff',
  wood: '#a8743f', woodLo: '#87592f', woodHi: '#c08a52', plank: '#b98450',
  metal: '#8c9399', char: '#2b2d31', amber: '#ffb02e', lamp: '#ffd27a',
};
const deg = (r) => (r * 180) / Math.PI;

// ------------------------------------------------------------------ vegetation
function jungleTree(ctx, p, h, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group(o.name || 'JungleTree');
  const t = g.at(p, [0, R() * 360, 0]);
  const w0 = o.w || 1.7;
  const SEG = 2.6;
  const n = Math.max(3, Math.round(h / SEG));
  let x = 0, z = 0;
  const lean = (R() - 0.5) * 0.35;
  for (let i = 0; i < n; i++) {
    const w = w0 * (1 - (i / n) * 0.35);
    t.box({ name: 'Trunk', s: [w, SEG + 0.1, w], p: [x, SEG / 2 + i * SEG, z], r: [0, i * 23, 0], c: PAL.trunk[i % 2], studs: 'sides', collide: i < 2 });
    x += lean * 0.3; z += Math.sin(i * 0.9) * 0.05;
  }
  for (let k = 0; k < 3; k++) {
    const a = k * 2.1 + R() * 0.5;
    t.wedgeF({ name: 'Buttress', s: [0.55, 1.6 + R() * 0.6, 1.4], p: [Math.cos(a) * (w0 * 0.75), 0.8, Math.sin(a) * (w0 * 0.75)], r: [0, -deg(a) - 90, 0], face: 'back', c: PAL.root });
  }
  // two branch arms carrying side canopies
  const top = [x, h, z];
  const arms = [];
  for (let k = 0; k < 2; k++) {
    const a = k * Math.PI + R() * 0.8;
    const len = 2.5 + R() * 1.5;
    const b0 = [x, h * (0.65 + R() * 0.15), z];
    const b1 = [x + Math.cos(a) * len, b0[1] + 1.6, z + Math.sin(a) * len];
    t.beam(b0, b1, 0.6, 0.6, { name: 'Branch', c: PAL.trunk[1], extend: 0.3 });
    arms.push(b1);
  }
  const canopy = (c, s) => {
    for (let k = 0; k < 3; k++) {
      const sz = s * (0.7 + R() * 0.45);
      t.box({ name: 'Canopy', s: [sz, sz * 0.62, sz], p: [c[0] + (R() - 0.5) * s * 0.7, c[1] + (R() - 0.3) * s * 0.4, c[2] + (R() - 0.5) * s * 0.7], r: [0, R() * 90, 0], c: PAL.leaf[Math.floor(R() * 4)], studs: 'top' });
    }
    t.box({ name: 'CanopyTop', s: [s * 0.6, s * 0.35, s * 0.6], p: [c[0], c[1] + s * 0.45, c[2]], r: [0, R() * 90, 0], c: PAL.leaf[4], studs: 'top' });
  };
  const S = o.canopy || 4.2 + h * 0.12;
  canopy(top, S);
  for (const a of arms) canopy(a, S * 0.62);
  for (let k = 0; k < 2; k++) {
    const vx = (R() - 0.5) * S, vz = (R() - 0.5) * S, vl = 2.5 + R() * 4;
    t.box({ name: 'Vine', s: [0.2, vl, 0.2], p: [x + vx, h - vl / 2 - 0.4, z + vz], c: '#3a7a2a', shadow: false });
    if (R() > 0.5) t.box({ name: 'VineLeaf', s: [0.6, 0.12, 0.4], p: [x + vx, h - vl - 0.3, z + vz], c: PAL.leaf[2], shadow: false });
  }
  return g;
}

function palm(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('PalmTree');
  const t = g.at(p, [0, R() * 360, 0]);
  let x = 0, y = 0;
  const SEG = 2.0;
  const n = Math.round(h / SEG);
  const bend = 3 + R() * 3;
  for (let i = 0; i < n; i++) {
    const lean = bend + i * 2.0;
    t.box({ name: 'Trunk', s: [1.05 - i * 0.04, SEG + 0.08, 1.05 - i * 0.04], p: [x, y + SEG / 2, 0], r: [0, i * 13, lean], c: i % 2 ? '#8a5a33' : '#9c6a3d', studs: 'sides', collide: i < 2 });
    x -= Math.sin((lean * Math.PI) / 180) * SEG; y += Math.cos((lean * Math.PI) / 180) * SEG;
  }
  const top = t.at([x, y + 0.2, 0]);
  top.box({ name: 'Crown', s: [1.3, 0.8, 1.3], c: '#5a7a2c' });
  for (let i = 0; i < 3; i++) top.ball({ name: 'Coconut', d: 0.6, p: [Math.cos(i * 2.1) * 0.55, -0.45, Math.sin(i * 2.1) * 0.55], c: '#6b4a2b' });
  const fr = 6;
  for (let i = 0; i < fr; i++) {
    const f = top.at([0, 0.25, 0], [0, (i / fr) * 360 + R() * 18, 0]);
    const droop = -16 - R() * 10;
    f.box({ name: 'Frond', s: [1.0, 0.18, 3.4], p: [0, -0.3, -1.75], r: [droop, 0, 0], c: i % 2 ? '#3f9a3a' : '#4fb043', studs: 'top' });
    f.box({ name: 'FrondTip', s: [0.75, 0.16, 2.2], p: [0, -1.45, -4.1], r: [droop - 26, 0, 0], c: '#3a8a35' });
  }
  return g;
}

function bush(ctx, p, k, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group('Bush');
  const b = g.at(p, [0, R() * 360, 0]);
  const n = o.n || 6;
  for (let i = 0; i < n; i++) {
    const s = (1.4 + R() * 1.4) * k;
    b.box({ name: 'Leaves', s: [s, s * 0.8, s], p: [(R() - 0.5) * 2.4 * k, s * 0.4 + (i > 3 ? s * 0.35 : 0), (R() - 0.5) * 2.4 * k], r: [0, R() * 90, 0], c: (o.colors || PAL.leaf)[i % (o.colors || PAL.leaf).length], studs: 'top' });
  }
  if (o.berries) for (let i = 0; i < 5; i++) b.box({ name: 'Berry', s: [0.35, 0.35, 0.35], p: [(R() - 0.5) * 2.6 * k, 1.2 * k + R() * k, (R() - 0.5) * 2.6 * k], c: o.berries, shadow: false });
  return g;
}

function fern(ctx, p, k, seed) {
  const R = rng(seed);
  const g = ctx.group('Fern');
  const b = g.at(p, [0, R() * 360, 0]);
  const n = 6;
  for (let i = 0; i < n; i++) {
    const f = b.at([0, 0, 0], [0, i * (360 / n) + R() * 20, 0]);
    f.box({ name: 'FernLeaf', s: [0.55 * k, 0.12, 1.6 * k], p: [0, 0.45 * k, -0.75 * k], r: [-34, 0, 0], c: i % 2 ? '#4fb043' : '#3f9a3a', shadow: false });
    f.box({ name: 'FernTip', s: [0.4 * k, 0.1, 1.1 * k], p: [0, 0.62 * k, -1.95 * k], r: [8, 0, 0], c: '#5bbd4a', shadow: false });
  }
  return g;
}

function flowers(ctx, p, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group('Flowers');
  const cols = o.colors || ['#ff5a7a', '#ffd23a', '#ff8a2a', '#c86bff', '#ffffff'];
  const n = o.n || 6;
  for (let i = 0; i < n; i++) {
    const x = p[0] + (R() - 0.5) * (o.spread || 3), z = p[2] + (R() - 0.5) * (o.spread || 3);
    const h = 0.5 + R() * 0.6;
    g.box({ name: 'Stem', s: [0.12, h, 0.12], p: [x, p[1] + h / 2, z], c: '#3f8a35', shadow: false });
    g.box({ name: 'Bloom', s: [0.45, 0.3, 0.45], p: [x, p[1] + h + 0.1, z], r: [0, R() * 90, 0], c: cols[Math.floor(R() * cols.length)], studs: 'top', shadow: false });
  }
  return g;
}

function grassTufts(ctx, p, seed, o = {}) {
  const R = rng(seed);
  const n = o.n || 5;
  for (let i = 0; i < n; i++) {
    const x = p[0] + (R() - 0.5) * (o.spread || 4), z = p[2] + (R() - 0.5) * (o.spread || 4);
    const k = o.scale || 1;
    const h = (0.5 + R() * 0.7) * k;
    ctx.wedgeF({ name: 'GrassTuft', s: [0.5 * k, h, 0.3 * k], p: [x, p[1] + h / 2, z], r: [0, R() * 180, 0], face: R() > 0.5 ? 'front' : 'back', c: o.colors ? o.colors[Math.floor(R() * o.colors.length)] : PAL.leaf[2 + Math.floor(R() * 3)], shadow: false });
  }
}

// a patch of ground colour (moss, clover, dry grass): a few overlapping thin plates so a big green floor reads
// as a living one. one or two parts per plate, no collision, no shadows - cheap
function groundPatch(ctx, p, r, seed, o = {}) {
  const R = rng(seed);
  const cols = o.colors || ['#5cbf4a', '#79cf52', '#4aa83c', '#9bd85a'];
  const n = o.n || 3;
  for (let i = 0; i < n; i++) {
    const w = r * (0.6 + R() * 0.6), d = r * (0.5 + R() * 0.5);
    const x = p[0] + (R() - 0.5) * r, z = p[2] + (R() - 0.5) * r;
    // (o.step: the rise between stacked pieces; 0.01 flickers where two overlap - Giant Plains passes 0.05, 2026-10-14)
    ctx.box({ name: 'GroundPatch', s: [w, 0.12, d], p: [x, p[1] + 0.06 + i * (o.step || 0.01), z], r: [0, R() * 180, 0], c: cols[Math.floor(R() * cols.length)], m: o.m || 'Grass', collide: false, shadow: false });
  }
}

function rock(ctx, p, k, seed, o = {}) {
  const R = rng(seed);
  const g = ctx.group(o.name || 'Rock');
  const b = g.at(p, [0, R() * 360, 0]);
  const col = (i) => o.colors ? o.colors[i % o.colors.length] : PAL.rock[i % 4];
  b.box({ name: 'Rock', s: [2.2 * k, 1.5 * k, 1.9 * k], p: [0, 0.62 * k, 0], r: [R() * 10, 0, R() * 12], c: col(0), m: 'Slate', collide: k > 1.2 });
  b.box({ name: 'Rock', s: [1.4 * k, 1.1 * k, 1.3 * k], p: [0.95 * k, 0.42 * k, 0.6 * k], r: [0, 30, R() * 15], c: col(1), m: 'Slate', collide: k > 1.2 });
  b.box({ name: 'Rock', s: [1.0 * k, 0.8 * k, 1.0 * k], p: [-1.0 * k, 0.3 * k, -0.5 * k], r: [R() * 20, 15, 0], c: col(2), m: 'Slate' });
  if (o.moss !== false) b.box({ name: 'Moss', s: [1.6 * k, 0.2 * k, 1.3 * k], p: [-0.1 * k, 1.38 * k, 0], c: PAL.moss, studs: 'top' });
  return g;
}

// ------------------------------------------------------------------ terrain
// Cliff band along a polyline of [x, z] points (local), face pointing to the LEFT of travel direction.
function cliffWall(ctx, pts, o = {}) {
  const R = rng(o.seed || 77);
  const g = ctx.group(o.name || 'Cliff');
  const H = o.h || 50, D = o.d || 18, base = o.y || 0;
  const cols = o.colors || PAL.cliff;
  for (let s = 0; s < pts.length - 1; s++) {
    const [ax, az] = pts[s], [bx, bz] = pts[s + 1];
    const L = Math.hypot(bx - ax, bz - az);
    const yaw = Math.atan2(-(bx - ax), -(bz - az)); // local -Z along travel
    const n = Math.max(1, Math.round(L / (o.chunk || 12)));
    for (let i = 0; i < n; i++) {
      const t = (i + 0.5) / n;
      const cx = ax + (bx - ax) * t, cz = az + (bz - az) * t;
      const c = g.at([cx, base, cz], [0, deg(yaw), 0]);
      const hh = H * (0.82 + R() * 0.3);
      const seg = L / n + 3;
      let y = 0, layer = 0;
      // strata: stacked, slightly stepped back as they rise
      while (y < hh) {
        const lh = 5 + R() * 6;
        const back = (y / hh) * (o.slope || 4) + R() * 1.5;
        const col = cols[(layer + Math.floor(R() * 2)) % cols.length];
        c.box({ name: 'Strata', s: [D, Math.min(lh, hh - y) + 0.2, seg * (0.92 + R() * 0.2)], p: [-D / 2 - back, y + Math.min(lh, hh - y) / 2, (R() - 0.5) * 2], r: [0, (R() - 0.5) * 6, 0], c: col, m: 'Slate', collide: true });
        if (R() > 0.72) c.box({ name: 'Ledge', s: [2.2 + R() * 2, 1.2, seg * 0.5], p: [-back + 0.6, y + lh * 0.2, (R() - 0.5) * seg * 0.4], c: shade(col, 0.88), m: 'Slate' });
        if (o.moss !== false && R() > 0.78) c.box({ name: 'Moss', s: [2.6, 0.5, seg * (0.3 + R() * 0.4)], p: [-back + 0.4, y + Math.min(lh, hh - y), (R() - 0.5) * seg * 0.3], c: PAL.moss, studs: 'top', shadow: false });
        y += lh; layer++;
      }
      // grassy top + overhanging bushes
      c.box({ name: 'CliffTop', s: [D + 2, 1.2, seg + 0.5], p: [-D / 2 - (o.slope || 4), hh + 0.6, 0], c: o.top || PAL.grassLo, studs: 'top', collide: true });
      const oh = o.overhang || PAL.leaf;
      if (R() > (o.overhang ? 0.7 : 0.35)) c.box({ name: 'Overhang', s: [3.5, 2, seg * 0.6], p: [-(o.slope || 4) + 1.0, hh + 0.4, (R() - 0.5) * seg * 0.3], c: oh[Math.floor(R() * oh.length) % oh.length], studs: 'top' });
      // vines
      const nv = o.vines === false ? 0 : Math.floor(R() * 3);
      for (let v = 0; v < nv; v++) {
        const vl = 6 + R() * 14;
        c.box({ name: 'Vine', s: [0.3, vl, 0.3], p: [-(o.slope || 4) + 0.6, hh - vl / 2, (R() - 0.5) * seg * 0.8], c: '#3a7a2a', shadow: false });
      }
      if (o.trees && R() > 0.55) jungleTree(c, [-D / 2 - 2, hh + 1.2, (R() - 0.5) * seg * 0.5], 8 + R() * 6, Math.floor(R() * 1e6));
    }
  }
  return g;
}

// Waterfall pouring off a cliff edge at p (top-centre), falling to y = p[1] - h, facing local -Z
function waterfall(ctx, p, w, h, o = {}) {
  const R = rng(o.seed || 9);
  const g = ctx.group(o.name || 'Waterfall');
  const c = g.at(p, [0, o.yaw || 0, 0]);
  const cols = 3;
  for (let i = 0; i < cols; i++) {
    const cw = w / cols + 0.6;
    c.box({ name: 'Water', s: [cw, h, 1.2 + i * 0.1], p: [-w / 2 + (i + 0.5) * (w / cols), -h / 2, -0.6 - (i % 2) * 0.4], c: i % 2 ? PAL.water : shade(PAL.water, 1.12), m: 'SmoothPlastic', t: 0.18, shadow: false }).tag('Waterfall');
  }
  // streaks (animated downward by the client)
  for (let i = 0; i < Math.round(w * 0.9); i++) {
    const sl = 4 + R() * 6;
    c.box({ name: 'WaterStreak', s: [0.35 + R() * 0.3, sl, 0.2], p: [-w / 2 + R() * w, -R() * (h - sl) - sl / 2, -1.45], c: PAL.foam, m: 'Neon', t: 0.45, shadow: false }).attr('FallHeight', h).tag('WaterStreak');
  }
  c.box({ name: 'Lip', s: [w + 1, 0.8, 2.2], p: [0, 0.2, -0.4], c: shade(PAL.water, 1.25), t: 0.1, shadow: false });
  // foam + mist at the base
  for (let i = 0; i < Math.round(w / 1.8); i++) c.box({ name: 'Foam', s: [1.5 + R() * 1.6, 0.8 + R() * 0.7, 1.5 + R() * 1.6], p: [-w / 2 + R() * w, -h + 0.3, -1.8 - R() * 2], r: [0, R() * 90, 0], c: PAL.foam, studs: 'top', shadow: false });
  const mistHost = c.box({ name: 'MistEmitter', s: [w, 1, 2], p: [0, -h + 1, -2.5], t: 1, shadow: false });
  const e = new Inst('ParticleEmitter', 'Mist');
  e.set('Texture', 'Content', 'rbxasset://textures/particles/smoke_main.dds');
  e.set('Rate', 'float', o.mist || 10).set('Lifetime', 'NumberRange', [1.5, 3]).set('Speed', 'NumberRange', [2, 5]);
  e.set('SpreadAngle', 'Vector2', [40, 40]).set('EmissionDirection', 'token', 1);
  e.set('Size', 'NumberSequence', [[0, 3], [1, 8]]).set('Transparency', 'NumberSequence', [[0, 0.55], [1, 1]]);
  e.set('Color', 'ColorSequence', [[0, [1, 1, 1]], [1, [0.85, 0.95, 1]]]).set('LightEmission', 'float', 0.2);
  mistHost.add(e);
  return g;
}

// Pool / pond: water surface top at y; rim stones; optional lily pads and reeds
function pond(ctx, p, w, d, o = {}) {
  const R = rng(o.seed || 31);
  const g = ctx.group(o.name || 'Pond');
  const c = g.at(p, [0, o.yaw || 0, 0]);
  const depth = o.depth || 1.4;
  c.box({ name: 'PondBed', s: [w, 0.4, d], p: [0, -depth, 0], c: '#3e6a5a', m: 'Slate' });
  c.box({ name: 'PondWater', s: [w - 0.4, depth - 0.1, d - 0.4], p: [0, -depth / 2 - 0.05, 0], c: o.color || PAL.water, m: 'Glass', t: 0.3, refl: 0.1, shadow: false }).tag('DinoWater');
  const per = 2 * (w + d);
  const n = Math.round(per / 2.2);
  for (let i = 0; i < n; i++) {
    const u = (i / n) * per;
    let x, z;
    if (u < w) { x = -w / 2 + u; z = -d / 2; } else if (u < w + d) { x = w / 2; z = -d / 2 + (u - w); } else if (u < 2 * w + d) { x = w / 2 - (u - w - d); z = d / 2; } else { x = -w / 2; z = d / 2 - (u - 2 * w - d); }
    const s = 1.2 + R() * 0.9;
    c.box({ name: 'RimStone', s: [s * 1.3, s * 0.7, s], p: [x, 0.05, z], r: [0, R() * 90, R() * 8], c: PAL.rock[i % 4], m: 'Slate' });
  }
  if (o.lilies !== false) for (let i = 0; i < Math.round(w * d / 30); i++) {
    const x = (R() - 0.5) * (w - 3), z = (R() - 0.5) * (d - 3);
    c.cyl({ name: 'LilyPad', axis: 'y', len: 0.1, d: 1.1 + R() * 0.6, p: [x, -0.02, z], c: '#4fb043', shadow: false });
    if (R() > 0.6) c.box({ name: 'LilyFlower', s: [0.35, 0.3, 0.35], p: [x + 0.2, 0.15, z], c: '#ff8ab0', shadow: false });
  }
  if (o.reeds !== false) for (let i = 0; i < 6; i++) {
    const side = i % 2 ? 1 : -1;
    const x = side * (w / 2 - 0.8), z = (R() - 0.5) * (d - 2);
    for (let k = 0; k < 3; k++) {
      const h = 1.6 + R() * 1.2;
      c.box({ name: 'Reed', s: [0.15, h, 0.15], p: [x + (R() - 0.5), h / 2 - 0.2, z + (R() - 0.5)], c: '#4f8a35', shadow: false });
      c.box({ name: 'Cattail', s: [0.28, 0.6, 0.28], p: [x + (R() - 0.5) * 0.2, h - 0.1, z], c: '#6b4a2b', shadow: false });
    }
  }
  return g;
}

// ------------------------------------------------------------------ camp props
function lampPost(ctx, p, o = {}) {
  const g = ctx.group('LampPost');
  const c = g.at(p, [0, o.yaw || 0, 0]);
  const h = o.h || 7;
  c.box({ name: 'PostBase', s: [1.2, 0.6, 1.2], p: [0, 0.3, 0], c: PAL.rock[1], m: 'Slate', collide: true });
  c.box({ name: 'Post', s: [0.6, h, 0.6], p: [0, h / 2 + 0.5, 0], c: PAL.woodLo, studs: 'sides', collide: true });
  c.box({ name: 'Arm', s: [0.35, 0.35, 2.2], p: [0, h + 0.2, -0.9], c: PAL.woodLo });
  const lantern = c.at([0, h - 0.8, -1.8]);
  lantern.box({ name: 'LanternCap', s: [1.0, 0.25, 1.0], p: [0, 0.7, 0], c: PAL.char, studs: 'top' });
  lantern.box({ name: 'LanternFrame', s: [0.8, 1.0, 0.8], c: PAL.char, t: 0.6 });
  const bulb = lantern.box({ name: 'LanternGlow', s: [0.55, 0.75, 0.55], c: o.color || PAL.lamp, m: 'Neon' });
  bulb.tag('CampLight');
  const pl = new Inst('PointLight', 'Light');
  pl.set('Color', 'Color3', [1, 0.82, 0.55]).set('Range', 'float', o.range || 16).set('Brightness', 'float', 0.75).set('Shadows', 'bool', false);
  bulb.add(pl);
  return g;
}

function logFence(ctx, a, b, o = {}) {
  const g = o.group || ctx;
  const L = Math.hypot(b[0] - a[0], b[2] - a[2]);
  const n = Math.max(1, Math.round(L / (o.spacing || 5)));
  const h = o.h || 2.4;
  const col = o.color || PAL.wood;
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const x = a[0] + (b[0] - a[0]) * t, z = a[2] + (b[2] - a[2]) * t;
    g.box({ name: 'FencePost', s: [0.7, h + 0.4, 0.7], p: [x, a[1] + (h + 0.4) / 2, z], c: PAL.woodLo, studs: 'top', collide: true });
  }
  for (const y of o.rails || [h * 0.45, h * 0.85]) g.beam([a[0], a[1] + y, a[2]], [b[0], b[1] + y, b[2]], 0.4, 0.45, { name: 'FenceRail', c: col, collide: true });
}

// Board with arcade text on its front (-Z) face (and back if twoSided)
function signBoard(ctx, p, w, h, text, o = {}) {
  const c = ctx.at(p, o.r || [0, 0, 0]);
  const board = c.box({ name: o.name || 'Sign', s: [w, h, 0.4], c: o.bg || '#2a2c31', collide: !!o.collide });
  c.box({ name: 'SignFrame', s: [w + 0.5, h + 0.5, 0.3], p: [0, 0, 0.12], c: o.frame || PAL.woodLo });
  if (o.trim) c.box({ name: 'SignTrim', s: [w + 0.6, 0.18, 0.5], p: [0, -h / 2 - 0.3, 0], c: o.trim, m: 'Neon', shadow: false });
  const mk = (face) => {
    const sg = new Inst('SurfaceGui', 'SignText' + face);
    sg.set('Face', 'token', face === 'Front' ? 5 : 2).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', o.pps || 40).set('LightInfluence', 'float', 0);
    sg.add(styledText(text, { name: 'Text', size: [0.92, 0, 0.7, 0], pos: [0.04, 0, 0.15, 0], color: o.color || '#fff4d6', color2: o.color2, strokeT: o.strokeT || 3, shadow: o.shadow || 4, align: 'Center' }));
    board.add(sg);
    return sg;
  };
  mk('Front');
  if (o.twoSided) mk('Back');
  return board;
}

function crate(ctx, p, k = 1, o = {}) {
  const c = ctx.at(p, [0, o.yaw || 0, 0]);
  c.box({ name: 'Crate', s: [2 * k, 2 * k, 2 * k], p: [0, k, 0], c: PAL.plank, m: 'WoodPlanks', collide: true });
  for (const y of [0.15, 1.85]) c.box({ name: 'CrateBand', s: [2.06 * k, 0.24 * k, 2.06 * k], p: [0, y * k, 0], c: PAL.woodLo, m: 'Wood' });
  if (o.stencil) c.box({ name: 'Stencil', s: [0.9 * k, 0.9 * k, 0.05], p: [0, k, -1.03 * k], c: o.stencil, shadow: false });
}

function barrel(ctx, p, o = {}) {
  const c = ctx.at(p);
  const col = o.color || '#c8452a';
  c.cyl({ name: 'Barrel', axis: 'y', len: 2.2, d: 1.6, p: [0, 1.1, 0], c: col, m: 'Metal', collide: true });
  for (const y of [0.35, 1.85]) c.cyl({ name: 'BarrelRing', axis: 'y', len: 0.18, d: 1.68, p: [0, y, 0], c: shade(col, 0.7), m: 'Metal' });
  c.cyl({ name: 'BarrelLid', axis: 'y', len: 0.06, d: 1.4, p: [0, 2.22, 0], c: shade(col, 0.85), m: 'Metal' });
}

function flag(ctx, p, color, o = {}) {
  const c = ctx.at(p);
  const h = o.h || 6;
  c.cyl({ name: 'FlagPole', axis: 'y', len: h, d: 0.3, p: [0, h / 2, 0], c: '#d9d9d9', m: 'Metal' });
  c.ball({ name: 'FlagTop', d: 0.5, p: [0, h + 0.15, 0], c: PAL.amber, m: 'Metal' });
  const fl = c.box({ name: 'Flag', s: [0.08, 1.6, 2.6], p: [0, h - 1.0, -1.35], c: color });
  fl.tag('FlagCloth');
  c.box({ name: 'FlagStripe', s: [0.12, 0.35, 2.66], p: [0, h - 1.0, -1.35], c: '#ffffff', shadow: false });
}

function particles(host, name, o) {
  const e = new Inst('ParticleEmitter', name);
  e.set('Texture', 'Content', o.texture || 'rbxasset://textures/particles/sparkles_main.dds');
  e.set('Rate', 'float', o.rate || 5);
  e.set('Lifetime', 'NumberRange', o.life || [1, 2]);
  e.set('Speed', 'NumberRange', o.speed || [1, 2]);
  e.set('SpreadAngle', 'Vector2', o.spread || [180, 180]);
  if (o.dir !== undefined) e.set('EmissionDirection', 'token', o.dir);
  e.set('Size', 'NumberSequence', o.size || [[0, 0.4], [1, 0]]);
  e.set('Transparency', 'NumberSequence', o.transp || [[0, 0.1], [1, 1]]);
  const col = o.color || [1, 1, 1];
  e.set('Color', 'ColorSequence', Array.isArray(col[0]) ? col : [[0, col], [1, col]]);
  e.set('LightEmission', 'float', o.emission !== undefined ? o.emission : 0.6);
  if (o.accel) e.set('Acceleration', 'Vector3', o.accel);
  if (o.drag) e.set('Drag', 'float', o.drag);
  if (o.locked) e.set('LockedToPart', 'bool', true);
  if (o.zoffset) e.set('ZOffset', 'float', o.zoffset);
  host.add(e);
  return e;
}

function pointLight(host, color, range, brightness = 1) {
  const pl = new Inst('PointLight', 'Light');
  pl.set('Color', 'Color3', color).set('Range', 'float', range).set('Brightness', 'float', brightness).set('Shadows', 'bool', false);
  host.add(pl);
  return pl;
}

// Scatter helper: deterministic points in an annulus / rect avoiding keep-out circles
function scatter(R, n, gen, keepOut = [], minGap = 0, placed = []) {
  const out = [];
  let tries = 0;
  while (out.length < n && tries < n * 40) {
    tries++;
    const p = gen(R);
    if (keepOut.some(([x, z, r]) => Math.hypot(p[0] - x, p[1] - z) < r)) continue;
    if (minGap && [...placed, ...out].some((q) => Math.hypot(p[0] - q[0], p[1] - q[1]) < minGap)) continue;
    out.push(p);
  }
  placed.push(...out);
  return out;
}

// Heightfield emitter: cells [{ i, j, x, z, h, top, topC, sideC, sideM }] on a CELL grid (cell (i, j) centred at x, z;
// i grows with x, j with z). Neighbouring cells with the same height and colours are merged into one rectangle
// (greedy meshing), so a hillside costs a handful of parts instead of two per cell.
function heightfield(G, cells, CELL, o = {}) {
  const ground = o.ground || 0;
  const groups = new Map();
  for (const c of cells) {
    const sig = [c.h, c.top, c.topC, c.sideC, c.sideM].join('|');
    if (!groups.has(sig)) groups.set(sig, new Map());
    groups.get(sig).set(c.i + ',' + c.j, c);
  }
  let parts = 0;
  for (const cellsOf of groups.values()) {
    const left = new Map(cellsOf);
    const keys = [...left.keys()].sort((a, b) => { const [ai, aj] = a.split(',').map(Number), [bi, bj] = b.split(',').map(Number); return aj - bj || ai - bi; });
    for (const k of keys) {
      if (!left.has(k)) continue;
      const c = left.get(k);
      // grow along i, then along j while the whole row is available
      let w = 1;
      while (left.has((c.i + w) + ',' + c.j) && w < (o.maxRun || 16)) w++;
      let d = 1;
      grow: while (d < (o.maxRun || 16)) {
        for (let u = 0; u < w; u++) if (!left.has((c.i + u) + ',' + (c.j + d))) break grow;
        d++;
      }
      for (let u = 0; u < w; u++) for (let v = 0; v < d; v++) left.delete((c.i + u) + ',' + (c.j + v));
      const cx = c.x + ((w - 1) / 2) * CELL, cz = c.z + ((d - 1) / 2) * CELL;
      if (c.h > c.top + 0.01) { G.box({ name: o.sideName || 'HillSide', s: [w * CELL, c.h - c.top, d * CELL], p: [cx, ground + (c.h - c.top) / 2, cz], c: c.sideC, m: c.sideM || 'Plastic', collide: true }); parts++; }
      G.box({ name: o.topName || 'HillTop', s: [w * CELL, c.top, d * CELL], p: [cx, ground + c.h - c.top / 2, cz], c: c.topC, studs: 'top', collide: true });
      parts++;
    }
  }
  return parts;
}

// Free-roam safety rails (2026-10-14): four invisible walls standing on an era's boundary cliffs (a rectangle in
// local x/z, `out` studs outside it - put that on the cliff tops), from y0 up `h`. Whoever climbs a cliff, or drives up a
// hill onto one, is stopped there instead of walking off the far side into the void. CanQuery stays on: the free-roam
// rover's bumper rays must see them (CanQuery off would let it drive straight through); cameras ignore invisible parts.
function roamBarrier(ctx, x0, x1, z0, z1, o = {}) {
  const g = ctx.group(o.name || 'RoamBarrier', 'Folder');
  const out = o.out === undefined ? 18 : o.out, y0 = o.y0 === undefined ? 26 : o.y0, h = o.h || 300, pad = 40;
  const wall = (p, s) => g.box({ name: 'RoamBarrier', s, p, t: 1, shadow: false, collide: true, c: '#ffffff' }).set('CanTouch', 'bool', false);
  wall([x0 - out, y0 + h / 2, (z0 + z1) / 2], [2, h, z1 - z0 + 2 * pad]);
  wall([x1 + out, y0 + h / 2, (z0 + z1) / 2], [2, h, z1 - z0 + 2 * pad]);
  wall([(x0 + x1) / 2, y0 + h / 2, z0 - out], [x1 - x0 + 2 * pad, h, 2]);
  wall([(x0 + x1) / 2, y0 + h / 2, z1 + out], [x1 - x0 + 2 * pad, h, 2]);
  return g;
}

module.exports = {
  PAL, jungleTree, palm, bush, fern, flowers, grassTufts, groundPatch, rock, cliffWall, waterfall, pond,
  lampPost, logFence, signBoard, crate, barrel, flag, particles, pointLight, scatter, deg, heightfield, roamBarrier,
};
