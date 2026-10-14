// Scene-graph builder that emits Roblox .rbxmx files (synced by Rojo) and preview JSON.
const { CF, D2R, sub, norm, cross, dot } = require('./cframe.js');

const MATERIALS = {
  Plastic: 256, SmoothPlastic: 272, Neon: 288, Wood: 512, WoodPlanks: 528, Marble: 784,
  Slate: 800, Concrete: 816, Granite: 832, Brick: 848, Pebble: 864, Cobblestone: 880, Rock: 896,
  CorrodedMetal: 1040, DiamondPlate: 1056, Foil: 1072, Metal: 1088, Grass: 1280, Sand: 1296,
  Fabric: 1312, Ice: 1536, Glass: 1568,
  // (2026-10-12) the rest of the Enum.Material values new eras use
  Basalt: 788, CrackedLava: 804, Limestone: 820, Pavement: 836, Sandstone: 912, LeafyGrass: 1284, Snow: 1328,
  Mud: 1344, Ground: 1360, Asphalt: 1376, Salt: 1392, Glacier: 1552,
};
const SURF = { Smooth: 0, Studs: 3, Inlet: 4 };
const warnedMat = {};
const SHAPE = { Ball: 0, Block: 1, Cylinder: 2 };

let refCounter = 0;
class Inst {
  constructor(cls, name, props = {}) {
    this.cls = cls;
    this.name = name || cls;
    this.props = props; // name -> [type, value]
    this.children = [];
    this.attrs = {};
    this.tags = [];
    this.ref = 'RBX' + (refCounter++).toString(16).toUpperCase();
    this.parent = null;
  }
  add(c) { c.parent = this; this.children.push(c); return c; }
  set(name, type, value) { this.props[name] = [type, value]; return this; }
  attr(k, v) { this.attrs[k] = v; return this; }
  tag(t) { this.tags.push(t); return this; }
  walk(fn) { fn(this); for (const c of this.children) c.walk(fn); }
  find(name) { let r = null; this.walk((i) => { if (!r && i.name === name) r = i; }); return r; }
  count(cls) { let n = 0; this.walk((i) => { if (!cls || cls(i)) n++; }); return n; }
}

function hexToRgb(h) {
  if (Array.isArray(h)) return h;
  h = h.replace('#', '');
  return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
}
function rgbToHex([r, g, b]) {
  const c = (v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0');
  return '#' + c(r) + c(g) + c(b);
}
// Shade a hex color by factor (>1 lighter, <1 darker)
function shade(hex, f) {
  const [r, g, b] = hexToRgb(hex);
  if (f >= 1) return rgbToHex([r + (255 - r) * (f - 1), g + (255 - g) * (f - 1), b + (255 - b) * (f - 1)]);
  return rgbToHex([r * f, g * f, b * f]);
}
function mix(a, b, t) {
  const A = hexToRgb(a), B = hexToRgb(b);
  return rgbToHex([A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t]);
}

// Deterministic PRNG so regenerating gives identical files
function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

// ---------------------------------------------------------------------------
// Part construction
// ---------------------------------------------------------------------------
// o: { name, s:[x,y,z], c:'#hex', m:'Plastic', t:transparency, refl, studs:true|'top'|'all',
//      collide, shadow, anchored, mesh:'sphere', cls:'Part'|'WedgePart'|'Seat'|..., shape }
function makePart(cf, o, defaults) {
  o = Object.assign({}, defaults || {}, o);
  const cls = o.cls || 'Part';
  const p = new Inst(cls, o.name || (cls === 'WedgePart' ? 'Wedge' : 'Part'));
  let size = o.s.slice();
  if (o.shape === 'Ball') { const d = Math.min(...size); size = [d, d, d]; }
  p.set('Anchored', 'bool', !!o.anchored);
  p.set('CFrame', 'CFrame', cf);
  p.set('Color3uint8', 'Color3uint8', hexToRgb(o.c || '#a3a2a5'));
  // an unknown name would write 'undefined' and Rojo rejects the whole file: warn and fall back instead
  const mat = MATERIALS[o.m || 'SmoothPlastic'];
  if (mat === undefined && !warnedMat[o.m]) { warnedMat[o.m] = true; console.log(`WARNING: unknown material '${o.m}' (using SmoothPlastic)`); }
  p.set('Material', 'token', mat === undefined ? MATERIALS.SmoothPlastic : mat);
  p.set('size', 'Vector3', size.map((v) => Math.max(0.05, +v.toFixed(4))));
  if (cls === 'Part' || cls === 'Seat' || cls === 'VehicleSeat') {
    if (o.shape) p.set('shape', 'token', SHAPE[o.shape]);
  }
  if (o.t) p.set('Transparency', 'float', o.t);
  if (o.refl) p.set('Reflectance', 'float', o.refl);
  p.set('CanCollide', 'bool', !!o.collide);
  p.set('CanTouch', 'bool', !!o.touch);
  p.set('CastShadow', 'bool', o.shadow !== false);
  if (o.massless) p.set('Massless', 'bool', true);
  // Surfaces: studs give the classic Roblox toy-brick texture (only renders on Plastic)
  const faces = ['TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface'];
  for (const f of faces) p.set(f, 'token', SURF.Smooth);
  if (o.studs) {
    p.set('Material', 'token', MATERIALS.Plastic);
    if (o.studs === 'all') for (const f of faces) p.set(f, 'token', SURF.Studs);
    else if (o.studs === 'sides') for (const f of ['TopSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface']) p.set(f, 'token', SURF.Studs);
    else p.set('TopSurface', 'token', SURF.Studs);
  }
  if (o.mesh === 'sphere') {
    const m = new Inst('SpecialMesh', 'Mesh');
    m.set('MeshType', 'token', 3);
    p.add(m);
  }
  p._preview = {
    kind: o.mesh === 'sphere' ? 'ellipsoid' : cls === 'WedgePart' ? 'wedge' : o.shape === 'Cylinder' ? 'cyl' : o.shape === 'Ball' ? 'ball' : 'box',
    size, color: o.c || '#a3a2a5', t: o.t || 0, mat: o.m || (o.studs ? 'Plastic' : 'SmoothPlastic'), studs: !!o.studs,
  };
  p._cf = cf;
  return p;
}

// ---------------------------------------------------------------------------
// Ctx: an authoring frame. Parts are placed in local coords of the frame.
// mirrored ctx flips X (left/right) for every placement it receives.
// ---------------------------------------------------------------------------
function placement(o) {
  if (o.cf) return o.cf;
  const p = o.p || [0, 0, 0];
  const r = o.r || [0, 0, 0];
  return new CF(p[0], p[1], p[2]).mul(CF.deg(r[0], r[1], r[2]));
}

class Ctx {
  constructor({ parent, frame, bone = null, mirrored = false, defaults = {}, sink = null, k = 1, korigin = [0, 0, 0] }) {
    this.k = k; // uniform scale applied to placements (about korigin) and sizes
    this.korigin = korigin;
    this.parent = parent; // Inst that receives parts
    this.frame = frame || new CF();
    this.bone = bone; // Inst bone part for welding (rigs)
    this.mirrored = mirrored;
    this.defaults = defaults;
    this.sink = sink; // optional list collecting created parts
  }
  _local(cf) {
    if (this.k !== 1) {
      const o = this.korigin, k = this.k;
      cf = cf.withPos(o[0] + (cf.x - o[0]) * k, o[1] + (cf.y - o[1]) * k, o[2] + (cf.z - o[2]) * k);
    }
    return this.mirrored ? cf.mirrorX() : cf;
  }
  world(cf) { return this.frame.mul(this._local(cf)); }
  wpt(p) { return this.world(new CF(p[0], p[1], p[2])).pos(); }
  clone(over) { return new Ctx(Object.assign({ parent: this.parent, frame: this.frame, bone: this.bone, mirrored: this.mirrored, defaults: this.defaults, sink: this.sink, k: this.k, korigin: this.korigin }, over)); }
  at(p, r) { return this.clone({ frame: this.world(placement({ p, r })), korigin: [0, 0, 0] }); }
  atCF(cf) { return this.clone({ frame: this.world(cf), korigin: [0, 0, 0] }); }
  // Uniformly scale everything authored through this ctx about `origin` (local coords)
  scaled(k, origin = [0, 0, 0]) { return this.clone({ k: this.k * k, korigin: origin }); }
  into(inst) { return this.clone({ parent: inst }); }
  with(defaults) { return this.clone({ defaults: Object.assign({}, this.defaults, defaults) }); }
  // Mirror helper: calls fn(ctx, side) for right (+1) and left (-1)
  sym(fn) {
    fn(this, 1, 'Right');
    fn(this.clone({ mirrored: !this.mirrored }), -1, 'Left');
  }
  group(name, cls = 'Model') {
    const g = new Inst(cls, name);
    this.parent.add(g);
    return this.into(g);
  }
  _add(cf, o) {
    if (this.k !== 1 && o.s) o = Object.assign({}, o, { s: o.s.map((v) => v * this.k) });
    const part = makePart(this.world(cf), o, this.defaults);
    this.parent.add(part);
    if (this.bone) weld(this.bone, part);
    if (this.sink) this.sink.push(part);
    return part;
  }
  box(o) { return this._add(placement(o), o); }
  wedge(o) { return this._add(placement(o), Object.assign({ cls: 'WedgePart' }, o)); }
  // Wedge whose slope faces `face` ('front' -Z, 'back' +Z, 'left' -X, 'right' +X).
  // s = [along-edge length, height, depth]. flip=true puts the slope on the underside.
  wedgeF(o) {
    const yaw = { front: 0, back: 180, left: 90, right: -90 }[o.face || 'front'];
    const p = o.p || [0, 0, 0];
    const cf = new CF(p[0], p[1], p[2]).mul(CF.deg(...(o.r || [0, 0, 0]))).mul(CF.deg(0, yaw, o.flip ? 180 : 0));
    return this._add(cf, Object.assign({ cls: 'WedgePart' }, o));
  }
  // Cylinder; axis 'x' (default), 'y' or 'z'. len along axis, d diameter
  cyl(o) {
    const axisRot = { x: [0, 0, 0], y: [0, 0, 90], z: [0, 90, 0] }[o.axis || 'x'];
    const cf = placement(o).mul(CF.deg(...axisRot));
    return this._add(cf, Object.assign({}, o, { shape: 'Cylinder', s: [o.len, o.d, o.d] }));
  }
  ball(o) { return this._add(placement(o), Object.assign({}, o, { shape: 'Ball', s: [o.d, o.d, o.d] })); }
  ell(o) { return this._add(placement(o), Object.assign({}, o, { mesh: 'sphere' })); }
  // Cylinder tube between two local points
  tube(a, b, d, o = {}) {
    const len = Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]);
    const cf = CF.alongX(a, b);
    return this._add(cf, Object.assign({}, o, { shape: 'Cylinder', s: [len + (o.extend || 0), d, d] }));
  }
  // Square beam between two points
  beam(a, b, w, h, o = {}) {
    const len = Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]);
    const cf = CF.alongX(a, b, o.up || [0, 1, 0]);
    return this._add(cf, Object.assign({}, o, { s: [len + (o.extend || 0), h, w] }));
  }
  attach(name, p = [0, 0, 0], r = [0, 0, 0]) {
    // Attachments are parented to the bone/part; CFrame is relative to that part
    const host = this.bone || this.parent;
    const a = new Inst('Attachment', name);
    const world = this.world(placement({ p, r }));
    const hostCF = host._cf || new CF();
    a.set('CFrame', 'CFrame', hostCF.inv().mul(world));
    a._world = world;
    host.add(a);
    return a;
  }
}

function weld(part0, part1) {
  const w = new Inst('Weld', 'Weld');
  w.set('Part0', 'Ref', part0);
  w.set('Part1', 'Ref', part1);
  w.set('C0', 'CFrame', part0._cf.inv().mul(part1._cf));
  w.set('C1', 'CFrame', new CF());
  part1.add(w);
  part1._weldTo = part0;
  return w;
}

// ---------------------------------------------------------------------------
// Rig: invisible bone parts connected by Motor6D joints (Animation Editor compatible)
// ---------------------------------------------------------------------------
class Rig {
  constructor(model, rootCF, rootSize) {
    this.model = model;
    this.bones = {};
    this.root = makePart(rootCF, { name: 'RootPart', s: rootSize, t: 1, anchored: true, collide: true, shadow: false, c: '#ffffff' });
    this.root._isBone = true;
    this.root._pose = new CF();
    model.add(this.root);
    model.set('PrimaryPart', 'Ref', this.root);
    this.bones.RootPart = this.root;
    const ac = model.add(new Inst('AnimationController', 'AnimationController'));
    ac.add(new Inst('Animator', 'Animator'));
  }
  // Create bone at world CF `pivot`; joint named `name` (Motor6D lives in the parent bone)
  bone(name, parent, pivot) {
    const parentPart = typeof parent === 'string' ? this.bones[parent] : parent;
    const b = makePart(pivot, { name, s: [0.25, 0.25, 0.25], t: 1, shadow: false, massless: true, c: '#ffffff' });
    b._isBone = true;
    b._parentBone = parentPart;
    b._pose = new CF();
    this.model.add(b);
    const m = new Inst('Motor6D', name);
    m.set('Part0', 'Ref', parentPart);
    m.set('Part1', 'Ref', b);
    m.set('C0', 'CFrame', parentPart._cf.inv().mul(pivot));
    m.set('C1', 'CFrame', new CF());
    parentPart.add(m);
    this.bones[name] = b;
    return b;
  }
  // Ctx authoring frame for a bone (local coords centered at the joint pivot)
  ctx(bone, defaults) {
    const b = typeof bone === 'string' ? this.bones[bone] : bone;
    return new Ctx({ parent: b, frame: b._cf, bone: b, defaults });
  }
}

// FK posing for preview verification: pose = { BoneName: CF transform }
function posedWorld(bone, pose, cache) {
  if (cache.has(bone)) return cache.get(bone);
  let w;
  if (!bone._parentBone) w = bone._cf;
  else {
    const pw = posedWorld(bone._parentBone, pose, cache);
    const c0 = bone._parentBone._cf.inv().mul(bone._cf);
    w = pw.mul(c0).mul(pose[bone.name] || new CF());
  }
  cache.set(bone, w);
  return w;
}

// ---------------------------------------------------------------------------
// GUI helpers
// ---------------------------------------------------------------------------
function fontFace(family = 'FredokaOne', weight = 700) {
  return { family: `rbxasset://fonts/families/${family}.json`, weight, style: 'Normal' };
}
function textLabel(text, o = {}) {
  const l = new Inst('TextLabel', o.name || 'Label');
  l.set('Text', 'string', text);
  l.set('FontFace', 'Font', fontFace(o.font || 'FredokaOne', o.weight || 700));
  l.set('TextColor3', 'Color3', hexToRgb(o.color || '#ffffff').map((v) => v / 255));
  l.set('TextScaled', 'bool', true);
  l.set('BackgroundTransparency', 'float', o.bgT !== undefined ? o.bgT : 1);
  if (o.bg) l.set('BackgroundColor3', 'Color3', hexToRgb(o.bg).map((v) => v / 255));
  l.set('BorderSizePixel', 'int', 0);
  l.set('Size', 'UDim2', o.size || [1, 0, 1, 0]);
  if (o.pos) l.set('Position', 'UDim2', o.pos);
  if (o.stroke) {
    const s = new Inst('UIStroke', 'UIStroke');
    s.set('Color', 'Color3', hexToRgb(o.stroke).map((v) => v / 255));
    s.set('Thickness', 'float', o.strokeT || 2);
    s.set('ApplyStrokeMode', 'token', 0);
    l.add(s);
  }
  return l;
}
// Arcade text style used everywhere: Press Start 2P, thick outline, vertical gradient, hard drop shadow.
const FONT_FAMILY = 'PressStart2P';
function styledText(text, o = {}) {
  const box = new Inst('Frame', o.name || 'Text');
  box.set('BackgroundTransparency', 'float', 1);
  box.set('Size', 'UDim2', o.size || [1, 0, 1, 0]);
  if (o.pos) box.set('Position', 'UDim2', o.pos);
  const mk = (name, color, offset, z) => {
    const l = new Inst('TextLabel', name);
    l.set('Text', 'string', text);
    l.set('FontFace', 'Font', fontFace(o.family || FONT_FAMILY, 400));
    l.set('TextColor3', 'Color3', hexToRgb(color).map((v) => v / 255));
    l.set('TextScaled', 'bool', true);
    l.set('BackgroundTransparency', 'float', 1);
    l.set('Size', 'UDim2', [1, 0, 1, 0]);
    l.set('Position', 'UDim2', [0, offset, 0, offset]);
    l.set('ZIndex', 'int', z);
    if (o.align) l.set('TextXAlignment', 'token', { Left: 0, Right: 1, Center: 2 }[o.align]);
    return l;
  };
  const shadowOff = o.shadow === undefined ? 4 : o.shadow;
  if (shadowOff) box.add(mk('Shadow', o.shadowColor || '#000000', shadowOff, 1)).set('TextTransparency', 'float', 0.35);
  const main = mk('Main', '#ffffff', 0, 2);
  const st = new Inst('UIStroke', 'UIStroke');
  st.set('Color', 'Color3', hexToRgb(o.stroke || '#101014').map((v) => v / 255));
  st.set('Thickness', 'float', o.strokeT || 3);
  st.set('LineJoinMode', 'token', 2); // Miter: crisp pixel corners
  main.add(st);
  const top = o.color || '#ffffff', bottom = o.color2 || shade(top, 0.72);
  const gr = new Inst('UIGradient', 'UIGradient');
  gr.set('Color', 'ColorSequence', [[0, hexToRgb(top).map((v) => v / 255)], [0.55, hexToRgb(top).map((v) => v / 255)], [1, hexToRgb(bottom).map((v) => v / 255)]]);
  gr.set('Rotation', 'float', 90);
  main.add(gr);
  box.add(main);
  return box;
}

// SurfaceGui with a single text label on a part face. face: Right=0 Top=1 Back=2 Left=3 Bottom=4 Front=5
function surfaceText(part, face, text, o = {}) {
  const FACES = { Right: 0, Top: 1, Back: 2, Left: 3, Bottom: 4, Front: 5 };
  const g = new Inst('SurfaceGui', o.name || 'Text' + face);
  g.set('Face', 'token', FACES[face]);
  g.set('SizingMode', 'token', 1);
  g.set('PixelsPerStud', 'float', o.pps || 60);
  g.set('LightInfluence', 'float', o.light !== undefined ? o.light : 1);
  g.add(styledText(text, Object.assign({ shadow: 2, strokeT: 2 }, o)));
  part.add(g);
  return g;
}

// ---------------------------------------------------------------------------
// rbxmx writer
// ---------------------------------------------------------------------------
function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
function num(v) { const n = Math.abs(v) < 1e-9 ? 0 : +v.toFixed(5); return String(n); }

function encodeAttrs(attrs) {
  const keys = Object.keys(attrs);
  const bufs = [];
  const u32 = (n) => { const b = Buffer.alloc(4); b.writeUInt32LE(n); return b; };
  const str = (s) => { const b = Buffer.from(s, 'utf8'); return Buffer.concat([u32(b.length), b]); };
  bufs.push(u32(keys.length));
  for (const k of keys) {
    const v = attrs[k];
    bufs.push(str(k));
    if (typeof v === 'string') { bufs.push(Buffer.from([0x02]), str(v)); }
    else if (typeof v === 'boolean') { bufs.push(Buffer.from([0x03, v ? 1 : 0])); }
    else if (typeof v === 'number') { const b = Buffer.alloc(8); b.writeDoubleLE(v); bufs.push(Buffer.from([0x06]), b); }
    else throw new Error('Unsupported attribute type for ' + k);
  }
  return Buffer.concat(bufs).toString('base64');
}

function propXml(name, type, v, ind) {
  const cfXml = (cf) => `<X>${num(cf.x)}</X><Y>${num(cf.y)}</Y><Z>${num(cf.z)}</Z>` + cf.r.map((x, i) => `<R${Math.floor(i / 3)}${i % 3}>${num(x)}</R${Math.floor(i / 3)}${i % 3}>`).join('');
  switch (type) {
    case 'string': return `${ind}<string name="${name}">${esc(v)}</string>`;
    case 'bool': return `${ind}<bool name="${name}">${v ? 'true' : 'false'}</bool>`;
    case 'float': return `${ind}<float name="${name}">${num(v)}</float>`;
    case 'double': return `${ind}<double name="${name}">${num(v)}</double>`;
    case 'int': return `${ind}<int name="${name}">${Math.round(v)}</int>`;
    case 'token': return `${ind}<token name="${name}">${v}</token>`;
    case 'CFrame': return `${ind}<CoordinateFrame name="${name}">${cfXml(v)}</CoordinateFrame>`;
    case 'Vector3': return `${ind}<Vector3 name="${name}"><X>${num(v[0])}</X><Y>${num(v[1])}</Y><Z>${num(v[2])}</Z></Vector3>`;
    case 'Vector2': return `${ind}<Vector2 name="${name}"><X>${num(v[0])}</X><Y>${num(v[1])}</Y></Vector2>`;
    case 'Color3': return `${ind}<Color3 name="${name}"><R>${num(v[0])}</R><G>${num(v[1])}</G><B>${num(v[2])}</B></Color3>`;
    case 'Color3uint8': return `${ind}<Color3uint8 name="${name}">${(v[0] << 16) | (v[1] << 8) | v[2]}</Color3uint8>`;
    case 'UDim2': return `${ind}<UDim2 name="${name}"><XS>${num(v[0])}</XS><XO>${Math.round(v[1])}</XO><YS>${num(v[2])}</YS><YO>${Math.round(v[3])}</YO></UDim2>`;
    case 'Ref': return `${ind}<Ref name="${name}">${v ? v.ref : 'null'}</Ref>`;
    case 'Font': return `${ind}<Font name="${name}"><Family><url>${v.family}</url></Family><Weight>${v.weight}</Weight><Style>${v.style}</Style></Font>`;
    case 'NumberSequence': return `${ind}<NumberSequence name="${name}">${v.map((k) => `${num(k[0])} ${num(k[1])} ${num(k[2] || 0)}`).join(' ')} </NumberSequence>`;
    case 'ColorSequence': return `${ind}<ColorSequence name="${name}">${v.map((k) => `${num(k[0])} ${num(k[1][0])} ${num(k[1][1])} ${num(k[1][2])} 0`).join(' ')} </ColorSequence>`;
    case 'NumberRange': return `${ind}<NumberRange name="${name}">${num(v[0])} ${num(v[1])} </NumberRange>`;
    case 'Content': return `${ind}<Content name="${name}"><url>${esc(v)}</url></Content>`;
    case 'BinaryString': return `${ind}<BinaryString name="${name}">${v}</BinaryString>`;
    default: throw new Error('Unknown prop type ' + type);
  }
}

function instXml(inst, depth) {
  const ind = '  '.repeat(depth);
  const out = [];
  out.push(`${ind}<Item class="${inst.cls}" referent="${inst.ref}">`);
  out.push(`${ind}  <Properties>`);
  out.push(propXml('Name', 'string', inst.name, ind + '    '));
  for (const [k, [t, v]] of Object.entries(inst.props)) out.push(propXml(k, t, v, ind + '    '));
  if (Object.keys(inst.attrs).length) out.push(propXml('AttributesSerialize', 'BinaryString', encodeAttrs(inst.attrs), ind + '    '));
  if (inst.tags.length) out.push(propXml('Tags', 'BinaryString', Buffer.from(inst.tags.join('\0')).toString('base64'), ind + '    '));
  out.push(`${ind}  </Properties>`);
  for (const c of inst.children) out.push(instXml(c, depth + 1));
  out.push(`${ind}</Item>`);
  return out.join('\n');
}

function toRbxmx(root) {
  return `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n${instXml(root, 1)}\n</roblox>\n`;
}

// Translate/rotate an entire instance tree (all CFrame props of parts) by `by` (world)
function transformTree(root, by) {
  root.walk((i) => {
    if (i._cf) { i._cf = by.mul(i._cf); i.props.CFrame[1] = i._cf; }
    if (i._world) i._world = by.mul(i._world);
  });
}

// Uniformly scale a built model about the origin (used for juveniles / baby variants)
function scaleTree(root, k) {
  const scaleCF = (cf) => new CF(cf.x * k, cf.y * k, cf.z * k, cf.r.slice());
  root.walk((i) => {
    if (i._cf) { i._cf = scaleCF(i._cf); i.props.CFrame[1] = i._cf; }
    if (i._preview) { i._preview.size = i._preview.size.map((v) => v * k); i.props.size[1] = i._preview.size.map((v) => Math.max(0.05, +v.toFixed(4))); }
    if (i._world) i._world = scaleCF(i._world);
    for (const key of ['C0', 'C1']) if (i.props[key]) i.props[key][1] = scaleCF(i.props[key][1]);
    if (i.cls === 'Attachment') i.props.CFrame[1] = scaleCF(i.props.CFrame[1]);
  });
}

// Deep clone an instance tree, remapping internal refs
function cloneTree(root) {
  const map = new Map();
  const rec = (i) => {
    const c = new Inst(i.cls, i.name, {});
    c.attrs = Object.assign({}, i.attrs);
    c.tags = i.tags.slice();
    for (const k of ['_cf', '_isBone', '_world']) if (i[k] !== undefined) c[k] = i[k];
    if (i._preview) c._preview = Object.assign({}, i._preview, { size: i._preview.size.slice() });
    map.set(i, c);
    for (const ch of i.children) c.add(rec(ch));
    return c;
  };
  const out = rec(root);
  root.walk((i) => {
    const c = map.get(i);
    for (const [k, [t, v]] of Object.entries(i.props)) c.props[k] = [t, t === 'Ref' ? (map.get(v) || v) : v];
    if (i._parentBone) c._parentBone = map.get(i._parentBone);
    if (i._weldTo) c._weldTo = map.get(i._weldTo);
  });
  return out;
}

// Preview export: flatten parts to world-space renderables, optionally FK-posed
function previewParts(root, pose) {
  const parts = [];
  const cache = new Map();
  root.walk((i) => {
    if (!i._preview || i._isBone) return;
    let cf = i._cf;
    if (pose && i._weldTo) {
      const bone = i._weldTo;
      cf = posedWorld(bone, pose, cache).mul(bone._cf.inv().mul(i._cf));
    }
    const pv = i._preview;
    parts.push({ k: pv.kind, s: pv.size.map((v) => +v.toFixed(3)), cf: [cf.x, cf.y, cf.z, ...cf.r].map((v) => +v.toFixed(4)), c: pv.color, t: pv.t, m: pv.mat, st: pv.studs ? 1 : 0, n: i.name, bone: i._weldTo ? i._weldTo.name : null, grp: i._grp || null });
  });
  return parts;
}

function bounds(root) {
  const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  root.walk((i) => {
    if (!i._preview || i._isBone || i._preview.t >= 1) return;
    const cf = i._cf, s = i._preview.size;
    for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (const sz of [-1, 1]) {
      const p = cf.pt([sx * s[0] / 2, sy * s[1] / 2, sz * s[2] / 2]);
      for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], p[k]); mx[k] = Math.max(mx[k], p[k]); }
    }
  });
  return { min: mn, max: mx, size: mx.map((v, k) => v - mn[k]) };
}

module.exports = {
  Inst, Ctx, Rig, CF, D2R, makePart, weld, shade, mix, hexToRgb, rng, toRbxmx, textLabel, surfaceText, fontFace,
  transformTree, cloneTree, scaleTree, styledText, previewParts, bounds, posedWorld, MATERIALS,
};
