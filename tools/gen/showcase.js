// Showcase environment: vehicle motor pool, 12-slot dinosaur exhibition, stages, pools, props, decor.
const { Inst, Ctx, CF, shade, rng, styledText, surfaceText, transformTree, cloneTree, scaleTree, bounds } = require('./builder.js');

const RARITY = {
  Common: '#9fd36b', Uncommon: '#4fd1a5', Rare: '#4aa8ff', Epic: '#b46bff', Legendary: '#ffb02e', Mythic: '#ff4f8b', Secret: '#ff3030',
};
const STONE = { base: '#5d5a55', top: '#8a8478', trim: '#3f3d3a', moss: '#5f8f3e' };

// Exhibition layout (world x, z). Small creatures in front, giants at the back. yaw 180 faces the spawn.
const DINO_SLOTS = {
  Velociraptor: { pos: [-62, -40], yaw: 200, radius: 6 },
  Ankylosaurus: { pos: [-44, -40], yaw: 190, radius: 9, props: ['Boulder'] },
  Triceratops: { pos: [-16, -40], yaw: 180, radius: 13, props: ['Crates'] },
  Parasaurolophus: { pos: [12, -40], yaw: 175, radius: 11, juveniles: 2 },
  Stegosaurus: { pos: [38, -40], yaw: 170, radius: 11, props: ['Log'] },
  Carnotaurus: { pos: [64, -40], yaw: 160, radius: 11, curtain: true },
  Spinosaurus: { pos: [-46, -92], yaw: 195, type: 'pool', pool: [30, 34], depth: 3.5 },
  TyrannosaurusRex: { pos: [0, -92], yaw: 180, type: 'stage' },
  Giganotosaurus: { pos: [48, -92], yaw: 165, radius: 16, props: ['JungleWall'] },
  Brachiosaurus: { pos: [-58, -152], yaw: 200, radius: 19 },
  Mosasaurus: { pos: [-2, -156], yaw: 180, type: 'pool', pool: [36, 52], depth: 4.0 },
  PrimalRex: { pos: [50, -152], yaw: 175, type: 'containment' },
};
const VEHICLE_SLOTS = [
  { name: 'RookieRanger', x: -28, label: 'ROOKIE RANGER', tier: 'STARTER JEEP', color: '#f2b632' },
  { name: 'RaptorRunner', x: 0, label: 'RAPTOR RUNNER', tier: 'PURSUIT JEEP', color: '#ff7a1a' },
  { name: 'TitanTransport', x: 34, label: 'TITAN TRANSPORT', tier: 'ARMORED TRUCK', color: '#d9642b' },
];
const VEHICLE_Z = 40, VEHICLE_YAW = 20;

function billboard(host, title, subtitle, subColor, o = {}) {
  const g = new Inst('BillboardGui', 'NameLabel');
  g.set('Size', 'UDim2', [o.w || 13, 0, o.h || 3.0, 0]);
  g.set('LightInfluence', 'float', 0);
  g.set('MaxDistance', 'float', o.maxDist || 240);
  g.set('AlwaysOnTop', 'bool', false);
  g.add(styledText(title, { name: 'Title', size: [1, 0, 0.56, 0], color: '#fff4d6', color2: '#ffb02e', strokeT: 3, shadow: 4, align: 'Center' }));
  g.add(styledText(subtitle, { name: 'Subtitle', size: [1, 0, 0.3, 0], pos: [0, 0, 0.66, 0], color: subColor, strokeT: 2, shadow: 2, align: 'Center' }));
  host.add(g);
  return g;
}

function prompt(att, action, text, key, objectText) {
  const KEYS = { E: 101, F: 102, G: 103, R: 114 };
  const p = new Inst('ProximityPrompt', 'Prompt_' + action);
  p.set('ActionText', 'string', text);
  p.set('ObjectText', 'string', objectText);
  p.set('KeyboardKeyCode', 'token', KEYS[key]);
  p.set('MaxActivationDistance', 'float', 14);
  p.set('HoldDuration', 'float', 0);
  p.set('RequiresLineOfSight', 'bool', false);
  p.set('Exclusivity', 'token', 2);
  p.attr('DinoAction', action);
  att.add(p);
  return p;
}

// ---------------- Decor ----------------
function palm(ctx, p, h, seed) {
  const R = rng(seed);
  const g = ctx.group('PalmTree');
  const t = g.at(p, [0, R() * 360, 0]);
  let x = 0, y = 0;
  const n = Math.round(h / 1.3);
  for (let i = 0; i < n; i++) {
    const lean = 4 + i * 1.4;
    t.box({ name: 'Trunk', s: [1.0 - i * 0.04, 1.35, 1.0 - i * 0.04], p: [x, y + 0.65, 0], r: [0, i * 13, lean], c: i % 2 ? '#8a5a33' : '#9c6a3d', studs: 'sides', anchored: true });
    x -= Math.sin(lean * Math.PI / 180) * 1.3; y += Math.cos(lean * Math.PI / 180) * 1.3;
  }
  const top = t.at([x, y + 0.2, 0]);
  top.box({ name: 'Crown', s: [1.2, 0.7, 1.2], c: '#5a7a2c', anchored: true });
  for (let i = 0; i < 7; i++) {
    const f = top.at([0, 0.2, 0], [0, (i / 7) * 360 + R() * 20, 0]);
    f.box({ name: 'Frond', s: [0.9, 0.18, 3.2], p: [0, -0.35, -1.7], r: [-22, 0, 0], c: i % 2 ? '#3f9a3a' : '#4fb043', studs: 'top', anchored: true });
    f.box({ name: 'FrondTip', s: [0.7, 0.16, 1.8], p: [0, -1.35, -3.9], r: [-48, 0, 0], c: '#3a8a35', anchored: true });
  }
  return g;
}
// broadleaf jungle tree (Model with a base pivot so it can topple)
function jungleTree(ctx, p, h, seed, name = 'Tree') {
  const R = rng(seed);
  const g = ctx.group(name);
  const t = g.at(p, [0, R() * 360, 0]);
  const pivot = t.box({ name: 'TreeBase', s: [0.6, 0.6, 0.6], p: [0, 0.3, 0], t: 1, shadow: false, anchored: true });
  g.parent.set('PrimaryPart', 'Ref', pivot);
  const n = Math.round(h / 1.6);
  for (let i = 0; i < n; i++) t.box({ name: 'Trunk', s: [1.5 - i * 0.07, 1.65, 1.5 - i * 0.07], p: [Math.sin(i * 0.7) * 0.15, 0.8 + i * 1.6, 0], r: [0, i * 17, 0], c: i % 2 ? '#6b4a2b' : '#7d5733', studs: 'sides', anchored: true });
  for (let k = 0; k < 4; k++) {
    const a = k * 1.6 + R();
    t.box({ name: 'Root', s: [0.5, 0.6, 1.4], p: [Math.cos(a) * 0.9, 0.3, Math.sin(a) * 0.9], r: [0, -a * 57, 0], c: '#5e3f22', anchored: true });
  }
  const cols = ['#2f8a3a', '#3f9a3a', '#4fb043', '#2a7a34'];
  for (let k = 0; k < 6; k++) {
    const s = 3 + R() * 2.2;
    t.box({ name: 'Canopy', s: [s, s * 0.7, s], p: [(R() - 0.5) * 3.6, h - 1 + R() * 2.2, (R() - 0.5) * 3.6], r: [0, R() * 90, 0], c: cols[k % 4], studs: 'top', anchored: true });
  }
  for (let k = 0; k < 3; k++) t.box({ name: 'Vine', s: [0.18, 3 + R() * 3, 0.18], p: [(R() - 0.5) * 3, h - 3.5 - R(), (R() - 0.5) * 3], c: '#3a7a2a', anchored: true });
  return g;
}
function bush(ctx, p, k, seed, name = 'Bush') {
  const R = rng(seed);
  const g = ctx.group(name);
  const b = g.at(p, [0, R() * 360, 0]);
  const cols = ['#3f9a3a', '#4fb043', '#36863a', '#5bbd4a'];
  for (let i = 0; i < 6; i++) {
    const s = (1.4 + R() * 1.4) * k;
    b.box({ name: 'Leaves', s: [s, s * 0.8, s], p: [(R() - 0.5) * 2.4 * k, s * 0.4 + (i > 3 ? s * 0.4 : 0), (R() - 0.5) * 2.4 * k], r: [0, R() * 90, 0], c: cols[i % 4], studs: 'top', anchored: true });
  }
  return g;
}
function rock(ctx, p, k, seed, name = 'Rock') {
  const R = rng(seed);
  const g = ctx.group(name);
  const b = g.at(p, [0, R() * 360, 0]);
  b.box({ name: 'Rock', s: [2.2 * k, 1.4 * k, 1.8 * k], p: [0, 0.6 * k, 0], r: [R() * 10, 0, R() * 12], c: '#7d7a73', m: 'Slate', anchored: true });
  b.box({ name: 'Rock', s: [1.3 * k, 1.0 * k, 1.2 * k], p: [0.9 * k, 0.4 * k, 0.6 * k], r: [0, 30, R() * 15], c: '#6c6962', m: 'Slate', anchored: true });
  b.box({ name: 'Moss', s: [1.6 * k, 0.2 * k, 1.2 * k], p: [-0.1 * k, 1.32 * k, 0], c: STONE.moss, studs: 'top', anchored: true });
  return g;
}
function fern(ctx, p, k, seed) {
  const R = rng(seed);
  const g = ctx.group('Fern');
  const b = g.at(p, [0, R() * 360, 0]);
  for (let i = 0; i < 5; i++) b.at([0, 0, 0], [0, i * 72, 0]).box({ name: 'FernLeaf', s: [0.5 * k, 0.12, 2.0 * k], p: [0, 0.5 * k, -0.9 * k], r: [-30, 0, 0], c: i % 2 ? '#4fb043' : '#3f9a3a', anchored: true });
  return g;
}

// ---------------- Props (tagged CinematicProp, with a PropId) ----------------
function propModel(ctx, id) {
  const m = new Inst('Model', id);
  m.tag('CinematicProp');
  m.attr('PropId', id);
  ctx.parent.add(m);
  return [m, ctx.into(m)];
}
function crates(ctx, p) {
  const [m, c0] = propModel(ctx, 'Crates');
  const c = c0.at(p);
  const crate = (q, s, r) => {
    const k = c.at(q, [0, r, 0]);
    k.box({ name: 'Crate', s: [s, s, s], c: '#b07a45', m: 'WoodPlanks', anchored: true, collide: true });
    for (const y of [-s * 0.42, s * 0.42]) k.box({ name: 'CrateBand', s: [s + 0.04, 0.16, s + 0.04], p: [0, y, 0], c: '#6a4626', anchored: true });
    k.box({ name: 'CrateStencil', s: [s * 0.5, s * 0.3, 0.04], p: [0, 0, -s / 2 - 0.02], c: '#2b2216', anchored: true });
  };
  crate([-1.0, 0.9, 0], 1.8, 8); crate([1.0, 0.9, 0.2], 1.8, -6); crate([0, 2.6, 0.1], 1.6, 18); crate([2.4, 0.6, -0.8], 1.2, 30);
  return m;
}
function log(ctx, p, yaw) {
  const [m, c0] = propModel(ctx, 'Log');
  const c = c0.at(p, [0, yaw, 0]);
  for (let i = 0; i < 5; i++) {
    c.cyl({ name: 'LogSegment', len: 1.5, d: 1.5 - i * 0.04, p: [-3 + i * 1.5, 0.75, 0], c: i % 2 ? '#6b4a2b' : '#7d5733', m: 'Wood', anchored: true, collide: true });
    c.cyl({ name: 'BarkRing', len: 0.2, d: 1.62, p: [-2.25 + i * 1.5, 0.75, 0], c: '#4e3420', anchored: true });
  }
  c.cyl({ name: 'LogEnd', len: 0.06, d: 1.3, p: [-3.78, 0.75, 0], c: '#c99a62', anchored: true });
  c.box({ name: 'BranchStub', s: [0.4, 1.2, 0.4], p: [0.5, 1.6, 0.2], r: [0, 0, 25], c: '#6b4a2b', anchored: true });
  c.box({ name: 'Moss', s: [2.4, 0.2, 1.0], p: [-0.8, 1.52, 0], c: STONE.moss, studs: 'top', anchored: true });
  return m;
}
function boulder(ctx, p) {
  const [m, c0] = propModel(ctx, 'Boulder');
  const c = c0.at(p);
  c.box({ name: 'Boulder', s: [3.0, 2.6, 2.8], p: [0, 1.3, 0], r: [8, 20, 6], c: '#7d7a73', m: 'Slate', anchored: true, collide: true });
  c.box({ name: 'Boulder', s: [2.0, 2.0, 2.2], p: [1.2, 2.2, 0.6], r: [-10, 40, 12], c: '#6c6962', m: 'Slate', anchored: true });
  c.box({ name: 'Boulder', s: [1.6, 1.4, 1.6], p: [-1.3, 0.8, -0.9], r: [0, 15, -8], c: '#8a867e', m: 'Slate', anchored: true });
  c.box({ name: 'Moss', s: [2.2, 0.25, 1.8], p: [0.3, 3.1, 0.3], r: [6, 20, 0], c: STONE.moss, studs: 'top', anchored: true });
  return m;
}
function jungleWall(ctx, pts) {
  const [m, c0] = propModel(ctx, 'JungleWall');
  pts.forEach(([x, z, h], i) => jungleTree(c0, [x, 0, z], h, 900 + i));
  return m;
}

// ---------------- Displays ----------------
function platform(ctx, r, color, seed, top = 1.5) {
  const R = rng(seed);
  ctx.cyl({ name: 'PlatformBase', axis: 'y', len: top - 0.3, d: r * 2 + 1.2, p: [0, (top - 0.3) / 2, 0], c: STONE.base, m: 'Slate', anchored: true, collide: true });
  ctx.cyl({ name: 'PlatformTop', axis: 'y', len: 0.3, d: r * 2, p: [0, top - 0.15, 0], c: STONE.top, m: 'Slate', anchored: true, collide: true });
  ctx.cyl({ name: 'RarityTrim', axis: 'y', len: 0.22, d: r * 2 + 0.6, p: [0, top - 0.39, 0], c: color, anchored: true });
  ctx.cyl({ name: 'RarityGlow', axis: 'y', len: 0.08, d: r * 2 + 1.35, p: [0, 0.35, 0], c: color, m: 'Neon', anchored: true });
  const n = Math.max(10, Math.round(r * 2.2));
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    const s = 0.9 + R() * 0.5;
    ctx.box({ name: 'EdgeStone', s: [s * 1.3, s * 0.9, s], p: [Math.cos(a) * (r + 0.85), s * 0.4, Math.sin(a) * (r + 0.85)], r: [0, -a * 180 / Math.PI + R() * 20, R() * 6], c: i % 3 ? '#6e6a63' : '#7f7a71', m: 'Slate', anchored: true, collide: true });
  }
}

const DINO_ACTIONS = [
  ['Roar', 'Roar', 'E'],
  ['Signature', 'Signature Cutscene', 'R'],
  ['CycleAnimation', 'Cycle Animation', 'F'],
  ['Reset', 'Reset', 'G'],
];

function pedestal(ctx, name, rarity, color, target) {
  const g = ctx.group('ControlPedestal');
  g.box({ name: 'PedestalBase', s: [3.2, 0.6, 2.2], p: [0, 0.3, 0], c: STONE.trim, m: 'Slate', anchored: true, collide: true });
  g.box({ name: 'Pedestal', s: [2.6, 2.6, 1.6], p: [0, 1.9, 0], c: STONE.base, m: 'Slate', anchored: true, collide: true });
  g.wedgeF({ name: 'InfoPanel', s: [2.8, 0.7, 1.8], p: [0, 3.55, 0], face: 'back', c: '#2a2c31', anchored: true, collide: true });
  const sign = g.at([0, 3.6, 0.02], [0, 180, 0]).at([0, 0, 0], [69, 0, 0]).box({ name: 'InfoScreen', s: [2.4, 1.55, 0.06], c: '#1b1d22', anchored: true });
  const sg = new Inst('SurfaceGui', 'InfoText');
  sg.set('Face', 'token', 5).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', 80).set('LightInfluence', 'float', 0);
  sg.add(styledText(name.toUpperCase(), { name: 'Name', size: [0.94, 0, 0.42, 0], pos: [0.03, 0, 0.12, 0], color: '#ffffff', strokeT: 2, shadow: 3, align: 'Center' }));
  sg.add(styledText(rarity.toUpperCase(), { name: 'Rarity', size: [0.9, 0, 0.24, 0], pos: [0.05, 0, 0.62, 0], color, strokeT: 2, shadow: 2, align: 'Center' }));
  sign.add(sg);
  g.box({ name: 'PanelGlow', s: [2.9, 0.08, 0.08], p: [0, 3.2, 0.92], c: color, m: 'Neon', anchored: true });
  const host = g.box({ name: 'PromptHost', s: [0.4, 0.4, 0.4], p: [0, 2.2, 0], t: 1, anchored: true, shadow: false });
  DINO_ACTIONS.forEach(([action, text, key], i) => {
    const a = new Inst('Attachment', 'PromptAttachment_' + action);
    a.set('CFrame', 'CFrame', new CF(0, 1.9 - i * 1.25, -1.0));
    host.add(a);
    prompt(a, action, text, key, name);
  });
  const tv = new Inst('ObjectValue', 'Target');
  tv.set('Value', 'Ref', target);
  g.parent.add(tv);
  return g;
}

function placeAt(inst, x, z, yaw, y = 0) {
  transformTree(inst, new CF(x, y, z).mul(CF.deg(0, yaw, 0)));
}

function labelFor(ctx, dino, y) {
  const color = RARITY[dino.attrs.Rarity];
  const anchor = ctx.box({ name: 'LabelAnchor', s: [0.5, 0.5, 0.5], p: [0, y, 0], t: 1, shadow: false });
  billboard(anchor, dino.attrs.DisplayName.toUpperCase(), `${dino.attrs.Rarity.toUpperCase()} - ${dino.attrs.Classification.toUpperCase()}`, color, { w: Math.max(13, y * 0.9), h: Math.max(3, y * 0.2) });
}

// ---------------- Vehicles ----------------
function buildVehicleShowcase(vehicles) {
  const folder = new Inst('Folder', 'DinoExpeditionVehicles');
  const displays = new Inst('Folder', 'ShowcaseDisplays');
  for (const slot of VEHICLE_SLOTS) {
    const v = vehicles[slot.name];
    if (!v) continue;
    const b = bounds(v);
    const r = Math.max(b.size[0], b.size[2]) / 2 + 1.5;
    placeAt(v, slot.x, VEHICLE_Z, VEHICLE_YAW, 1.0);
    folder.add(v);
    const d = new Inst('Model', slot.name + 'Display');
    displays.add(d);
    const c = new Ctx({ parent: d, frame: new CF(slot.x, 0, VEHICLE_Z), defaults: { anchored: true } });
    c.cyl({ name: 'Turntable', axis: 'y', len: 0.8, d: r * 2, p: [0, 0.4, 0], c: '#2b2d31', m: 'Metal', collide: true });
    c.cyl({ name: 'TurntableTop', axis: 'y', len: 0.2, d: r * 2 - 1.2, p: [0, 0.9, 0], c: '#3c3f45', m: 'DiamondPlate', collide: true });
    c.cyl({ name: 'TierRing', axis: 'y', len: 0.12, d: r * 2 + 0.3, p: [0, 0.75, 0], c: slot.color, m: 'Neon' });
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2;
      c.box({ name: 'TurntableBolt', s: [0.5, 0.15, 0.5], p: [Math.cos(a) * (r - 0.35), 0.86, Math.sin(a) * (r - 0.35)], c: '#9aa0a6', m: 'Metal' });
    }
    const anchor = c.box({ name: 'LabelAnchor', s: [0.5, 0.5, 0.5], p: [0, b.size[1] + 3.6, 0], t: 1, shadow: false });
    billboard(anchor, slot.label, slot.tier, slot.color, { w: 15, h: 3.2 });
  }
  folder.add(displays);
  return folder;
}

// ---------------- Dinosaurs ----------------
function buildDinoShowcase(dinoTemplates) {
  const root = new Inst('Folder', 'DinoExpeditionShowcase');
  const displays = new Inst('Folder', 'DinosaurDisplays');
  root.add(displays);
  const stages = new Inst('Model', 'CinematicStage');
  root.add(stages);
  const decor = new Inst('Folder', 'Decor');

  // new species add their QC stages from showcase_<group>.js (tools/gen/newSpecies.js)
  const SLOTS = Object.assign({}, DINO_SLOTS, require('./newSpecies.js').showcaseSlots());
  for (const [name, slot] of Object.entries(SLOTS)) {
    const tmpl = dinoTemplates[name];
    if (!tmpl) continue;
    const dino = cloneTree(tmpl);
    const color = RARITY[dino.attrs.Rarity];
    const [x, z] = slot.pos;
    const type = slot.type || 'platform';
    const disp = new Inst('Model', name + 'Display');
    disp.attr('DinoName', name);
    (type === 'stage' || type === 'containment' ? stages : displays).add(disp);
    const c = new Ctx({ parent: disp, frame: new CF(x, 0, z).mul(CF.deg(0, slot.yaw, 0)), defaults: { anchored: true } });
    const dc = new Ctx({ parent: decor, frame: c.frame, defaults: { anchored: true } });
    let pedPos = null, labelY;

    if (type === 'platform') {
      const top = 1.5;
      platform(c, slot.radius, color, name.length * 31, top);
      placeAt(dino, 0, 0, 0, top);
      transformTree(dino, c.frame);
      disp.add(dino);
      labelY = bounds(dino).max[1] + 2.6;
      pedPos = [slot.radius * 0.6, 0, -(slot.radius + 3.2)];
      for (const pr of slot.props || []) {
        if (pr === 'Crates') crates(c, [0, top, -10.2]);
        if (pr === 'Log') log(c, [5.8, top, 6.4], 30);
        if (pr === 'Boulder') boulder(c, [5.6, top, 5.2]);
        if (pr === 'JungleWall') jungleWall(c, [[-5.6, 8.0, 15], [5.8, 8.6, 16], [-6.6, 12.0, 14], [6.8, 12.5, 15], [-2.8, 16.5, 17], [3.2, 16.8, 16]]);
      }
      // a slot's own props: slot.build(ctx, top, H) — H.propModel(ctx, id) makes a CinematicProp the signature can target
      if (slot.build) slot.build(c, top, { propModel, crates, log, boulder, jungleWall, jungleTree, palm, bush, rock, fern, disp, dino, decor: dc, cloneTree, scaleTree, transformTree, placeAt });
      if (slot.juveniles) {
        for (let i = 0; i < slot.juveniles; i++) {
          const juv = cloneTree(tmpl);
          scaleTree(juv, 0.5);
          juv.name = `${name}Juvenile${i + 1}`;
          juv.attr('HerdLeader', name).attr('AnimScale', 0.5).attr('DisplayName', `${dino.attrs.DisplayName} (Juvenile)`);
          const side = i % 2 ? -1 : 1;
          placeAt(juv, side * 5.0, 3.6, side * -18, top);
          transformTree(juv, c.frame);
          disp.add(juv);
        }
      }
      if (slot.curtain) {
        for (const side of [-1, 1]) {
          const cur = new Inst('Model', side < 0 ? 'FoliageCurtainLeft' : 'FoliageCurtainRight');
          cur.tag('CinematicFoliage');
          cur.attr('Side', side).attr('CloseDistance', 8);
          disp.add(cur);
          const cc = c.into(cur);
          for (let i = 0; i < 2; i++) bush(cc, [side * (8.6 + i * 2.6), top, -9.4 + i * 1.0], 1.7 - i * 0.2, 470 + i + (side > 0 ? 10 : 0), 'CurtainBush');
          const pv = cc.box({ name: 'CurtainPivot', s: [0.5, 0.5, 0.5], p: [side * 9, 2, -9.2], t: 1, shadow: false });
          cur.set('PrimaryPart', 'Ref', pv);
        }
      }
      if (!slot.build) palm(dc, [-slot.radius - 3, 0, slot.radius * 0.6], 8 + slot.radius * 0.3, 11 + x); // new stages dress themselves
      if (!slot.build) bush(dc, [-slot.radius - 2, 0, -slot.radius * 0.4], 0.8, 12 + x);
      rock(dc, [slot.radius + 2.5, 0, slot.radius * 0.5], 0.9, 13 + x);
      fern(dc, [slot.radius + 1.8, 0, -slot.radius * 0.3], 1, 14 + x);
    } else if (type === 'pool') {
      const [W, D] = slot.pool;
      c.box({ name: 'PoolBed', s: [W, 0.06, D], p: [0, 0.03, 0], c: '#0f3352', collide: true });
      const water = c.box({ name: 'Water', s: [W, 0.25, D], p: [0, 0.125, 0], c: '#2f86c9', t: 0.3, refl: 0.12, shadow: false });
      water.tag('DinoWater');
      const R = rng(x * 7 + 3);
      const rim = (px, pz, len, alongX) => {
        for (let i = 0; i < Math.round(len / 2.2); i++) {
          const t = -len / 2 + 1.1 + i * 2.2;
          const s = 1.1 + R() * 0.6;
          c.box({ name: 'RimStone', s: [alongX ? 2.3 : s * 1.4, s, alongX ? s * 1.4 : 2.3], p: [alongX ? px + t : px, s * 0.45, alongX ? pz : pz + t], r: [0, R() * 14 - 7, R() * 6], c: i % 3 ? '#6e6a63' : '#7f7a71', m: 'Slate', collide: true });
        }
      };
      rim(0, -D / 2 - 0.8, W + 2, true); rim(0, D / 2 + 0.8, W + 2, true); rim(-W / 2 - 0.8, 0, D, false); rim(W / 2 + 0.8, 0, D, false);
      for (let i = 0; i < 10; i++) {
        const side = i % 2 ? 1 : -1;
        const rx = side * (W / 2 - 1.5 - R() * 2), rz = (R() - 0.5) * (D - 4);
        for (let k = 0; k < 3; k++) c.box({ name: 'Reed', s: [0.18, 2 + R() * 1.6, 0.18], p: [rx + (R() - 0.5), 1.2, rz + (R() - 0.5)], r: [R() * 14 - 7, 0, R() * 14 - 7], c: k % 2 ? '#5f8f3e' : '#7aa64a' });
      }
      placeAt(dino, 0, 0, 0, -slot.depth);
      transformTree(dino, c.frame);
      disp.add(dino);
      if (slot.build) slot.build(c, 0, { propModel, crates, log, boulder, jungleWall, jungleTree, palm, bush, rock, fern, disp, dino, decor: dc, cloneTree, scaleTree, transformTree, placeAt });
      labelY = bounds(dino).max[1] + 3;
      pedPos = [W / 2 - 4, 0, -(D / 2 + 4.5)];
      palm(dc, [-W / 2 - 4, 0, D / 2 - 2], 12, 40 + x); palm(dc, [W / 2 + 4, 0, D / 2 - 4], 11, 41 + x); rock(dc, [-W / 2 - 3, 0, -D / 2 + 2], 1.2, 42 + x);
    } else if (type === 'stage') {
      buildTRexStage(c, disp, dino);
      labelY = bounds(dino).max[1] + 3;
      pedPos = [9, 0, -22];
    } else if (type === 'containment') {
      buildContainment(c, disp, dino);
      labelY = bounds(dino).max[1] + 4;
      pedPos = [12, 0, -28];
    }
    labelFor(c, dino, labelY);
    pedestal(c.at(pedPos, [0, 180, 0]), dino.attrs.DisplayName, dino.attrs.Rarity, color, dino);
  }
  root.add(decor);
  return root;
}

// T. rex cinematic stage (display-local: the creature faces -Z toward the audience)
function buildTRexStage(S, disp, dino) {
  const W = 40, D = 34;
  S.box({ name: 'StageBase', s: [W, 1.6, D], p: [0, 0.8, 0], c: STONE.base, m: 'Slate', collide: true });
  S.box({ name: 'StageTop', s: [W - 1.5, 0.3, D - 1.5], p: [0, 1.75, 0], c: STONE.top, m: 'Slate', collide: true });
  S.box({ name: 'StageFrontTrim', s: [W + 0.4, 0.3, 0.6], p: [0, 1.45, -D / 2], c: RARITY.Legendary, m: 'Neon' });
  for (let i = 0; i < 9; i++) S.box({ name: 'StageStep', s: [4, 0.8, 1.6], p: [-16 + i * 4, 0.4, -D / 2 - 0.9], c: i % 2 ? '#6e6a63' : '#7f7a71', m: 'Slate', collide: true });
  S.sym((s) => {
    s.box({ name: 'TorchPost', s: [1.2, 6, 1.2], p: [W / 2 - 1.2, 4.6, -D / 2 + 1.2], c: '#6b4a2b', m: 'WoodPlanks' });
    const fire = s.box({ name: 'TorchFire', s: [1.0, 1.0, 1.0], p: [W / 2 - 1.2, 8.1, -D / 2 + 1.2], r: [0, 45, 0], c: '#ffb02e', m: 'Neon' });
    const pl = new Inst('PointLight', 'TorchLight');
    pl.set('Color', 'Color3', [1, 0.7, 0.35]).set('Range', 'float', 22).set('Brightness', 'float', 1.6).set('Shadows', 'bool', false);
    fire.add(pl);
    s.box({ name: 'TorchBowl', s: [1.6, 0.5, 1.6], p: [W / 2 - 1.2, 7.6, -D / 2 + 1.2], c: '#3f3d3a', m: 'Slate' });
  });
  const plaque = S.box({ name: 'StagePlaque', s: [14, 1.2, 0.3], p: [0, 0.9, -D / 2 - 1.85], c: '#2a2c31' });
  surfaceText(plaque, 'Front', 'CINEMATIC STAGE', { color: '#ffd27a', pps: 40, light: 0 });
  const J = S.into(disp).group('JungleBackdrop', 'Model');
  const back = D / 2 - 3;
  for (let i = 0; i < 7; i++) palm(J, [-17 + i * 5.6 + (i % 2) * 1.2, 1.9, back + (i % 2) * 2.2], 12 + (i % 3) * 3, 100 + i);
  for (let i = 0; i < 6; i++) bush(J, [-16 + i * 6.4, 1.9, back - 0.5 + (i % 2)], 1.0, 200 + i);
  for (let i = 0; i < 4; i++) rock(J, [-15 + i * 10, 1.9, back - 4], 1.2, 300 + i);
  for (const side of [-1, 1]) {
    const cur = new Inst('Model', side < 0 ? 'FoliageCurtainLeft' : 'FoliageCurtainRight');
    cur.tag('CinematicFoliage');
    cur.attr('Side', side).attr('CloseDistance', 7);
    disp.add(cur);
    const cc = S.into(cur);
    for (let i = 0; i < 2; i++) bush(cc, [side * (10.5 + i * 3.6), 1.9, -5.0 + i * 1.8], 2.0 - i * 0.3, 400 + i + (side > 0 ? 10 : 0), 'CurtainBush');
    const pv = cc.box({ name: 'CurtainPivot', s: [0.5, 0.5, 0.5], p: [side * 10, 2, -5], t: 1, shadow: false });
    cur.set('PrimaryPart', 'Ref', pv);
    palm(J, [side * 15, 1.9, -2], 11, 450 + (side > 0 ? 1 : 0));
  }
  placeAt(dino, 0, -1, 0, 1.9);
  transformTree(dino, S.frame);
  disp.add(dino);
}

// Primal Rex containment cell: concrete walls, a barred destructible gate with crack stages, alarm lights
function buildContainment(S, disp, dino) {
  const W = 36, D = 48, gateZ = -10, H = 18;
  const concrete = '#6a6e74', concreteLo = '#55595f', steel = '#2e3036', hazard = '#f2c230';
  S.box({ name: 'Foundation', s: [W, 0.6, D], p: [0, 0.3, 1], c: '#4a4d52', m: 'Concrete', collide: true });
  S.box({ name: 'CellFloor', s: [W - 6, 0.1, 33], p: [0, 0.65, gateZ + 17], c: '#3a3d42', m: 'DiamondPlate' });
  for (let i = 0; i < 10; i++) S.box({ name: 'FloorHazard', s: [1.2, 0.06, 2.2], p: [-11.2 + i * 2.5, 0.63, gateZ - 1.8], r: [0, 35, 0], c: i % 2 ? '#1d1e21' : hazard, shadow: false });
  S.sym((s) => {
    s.box({ name: 'CellWall', s: [2.4, H, 34], p: [W / 2 - 4.2, H / 2 + 0.6, gateZ + 17.2], c: concrete, m: 'Concrete', collide: true });
    s.box({ name: 'WallStripe', s: [0.1, 1.2, 34], p: [W / 2 - 5.45, 3.0, gateZ + 17.2], c: hazard });
    s.box({ name: 'GatePillar', s: [3.2, H + 1.5, 3.2], p: [11.8, (H + 1.5) / 2 + 0.6, gateZ], c: concreteLo, m: 'Concrete', collide: true, studs: 'top' });
    for (const y of [5, 11, 17]) {
      const l = s.box({ name: 'AlarmLight', s: [0.9, 0.9, 0.5], p: [11.8, y, gateZ - 1.75], c: '#7a1010', m: 'SmoothPlastic' });
      l.tag('AlarmLight');
    }
    s.box({ name: 'PillarHazard', s: [3.3, 1.2, 3.3], p: [11.8, 2.0, gateZ], c: hazard });
  });
  S.box({ name: 'BackWall', s: [W - 6, H, 2.4], p: [0, H / 2 + 0.6, gateZ + 34.2], c: concrete, m: 'Concrete', collide: true });
  S.box({ name: 'GateLintel', s: [27, 3, 3.2], p: [0, H + 0.1, gateZ], c: concreteLo, m: 'Concrete', collide: true, studs: 'top' });
  const sign = S.box({ name: 'ContainmentSign', s: [12, 2, 0.3], p: [0, H + 0.1, gateZ - 1.75], c: '#1b1d22' });
  surfaceText(sign, 'Front', 'CONTAINMENT 12', { color: '#ff4040', pps: 40, light: 0 });
  const gate = new Inst('Model', 'Gate');
  gate.tag('CinematicProp');
  gate.attr('PropId', 'Gate');
  disp.add(gate);
  const G = S.into(gate);
  const pivot = G.box({ name: 'GatePivot', s: [0.5, 0.5, 0.5], p: [0, 8, gateZ], t: 1, shadow: false });
  gate.set('PrimaryPart', 'Ref', pivot);
  for (let i = 0; i < 13; i++) G.box({ name: 'GateBar', s: [0.7, H - 1.5, 0.7], p: [-9.6 + i * 1.6, (H - 1.5) / 2 + 0.6, gateZ], c: steel, m: 'Metal', collide: true });
  for (const y of [4, 9.5, 15]) G.box({ name: 'GateCrossbar', s: [21, 0.9, 1.0], p: [0, y, gateZ], c: '#3c3f45', m: 'Metal', collide: true });
  for (let i = 0; i < 10; i++) G.box({ name: 'GateHazard', s: [2.1, 0.92, 0.06], p: [-9.45 + i * 2.1, 4, gateZ - 0.53], c: i % 2 ? '#1d1e21' : hazard, shadow: false });
  const cracks = [[1, [[-0.8, 10.5], [1.6, 11.6]]], [2, [[0, 12.4], [-2.4, 7.8], [2.4, 8.6]]], [3, [[-1.6, 11.0], [0.8, 13.2], [3.2, 10.4], [-3.2, 12.6]]]];
  for (const [stage, pts] of cracks) for (const [cx, cy] of pts) {
    const k = G.box({ name: 'Crack', s: [1.4, 0.18, 0.08], p: [cx, cy, gateZ - 0.4], r: [0, 0, ((cx * 37 + cy * 11) % 70) - 35], c: '#0c0c0e', t: 1, shadow: false });
    k.attr('HiddenUntilStage', stage);
    const dent = G.box({ name: 'BentBar', s: [0.74, 1.6, 0.74], p: [Math.round(cx / 1.6) * 1.6, cy, gateZ - 0.25], r: [-14, 0, 0], c: '#45484f', m: 'Metal', t: 1, shadow: false });
    dent.attr('HiddenUntilStage', stage);
  }
  placeAt(dino, 0, gateZ + 16, 0, 0.6);
  transformTree(dino, S.frame);
  disp.add(dino);
}

module.exports = { buildVehicleShowcase, buildDinoShowcase, RARITY, DINO_SLOTS };
