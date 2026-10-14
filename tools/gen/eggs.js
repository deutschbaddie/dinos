// Blocky voxel eggs for every species, in the same studded-brick style as the dinosaurs.
// Each egg = stepped layers (a "pixel-art" egg silhouette in bricks) + a species pattern + rarity effects.
// Canonical height 2.4 studs; gameplay scales them per context with Model:ScaleTo.
const { Inst, Ctx, CF, shade } = require('./builder.js');

// relative widths of each layer, bottom → top
const PROFILE = [0.6, 0.84, 0.97, 1.0, 0.97, 0.88, 0.72, 0.5, 0.26];
const H = 2.4, W = 1.75;

const SPECIES = {
  Velociraptor: { rarity: 'Common', base: '#7b8a3a', alt: '#3e5226', bottom: '#e9dfbf', pattern: 'stripes' },
  Triceratops: { rarity: 'Common', base: '#c0763a', alt: '#6b3f22', bottom: '#d9b98a', pattern: 'band', top: '#f1e3c2', extra: 'horns' },
  Parasaurolophus: { rarity: 'Uncommon', base: '#e3b83a', alt: '#d27a2a', bottom: '#f3e6c0', pattern: 'stripes', top: '#d8452a' },
  Stegosaurus: { rarity: 'Uncommon', base: '#5f8a3a', alt: '#d2662a', bottom: '#e1d3a6', pattern: 'diamonds' },
  Ankylosaurus: { rarity: 'Rare', base: '#6f7378', alt: '#a4552c', bottom: '#b8b2a0', pattern: 'tiles' },
  Carnotaurus: { rarity: 'Rare', base: '#a8242a', alt: '#1e1414', bottom: '#d7b08c', pattern: 'spots', extra: 'bullhorns' },
  Brachiosaurus: { rarity: 'Epic', base: '#c9a46a', alt: '#5e4630', bottom: '#efe0bd', pattern: 'patches', top: '#7a8a45' },
  Spinosaurus: { rarity: 'Epic', base: '#1f6f73', alt: '#e0532a', bottom: '#e8dcc0', pattern: 'fin' },
  TyrannosaurusRex: { rarity: 'Legendary', base: '#4a8a3c', alt: '#1f5a3f', bottom: '#d8c08a', pattern: 'spots' },
  Giganotosaurus: { rarity: 'Legendary', base: '#3a3a44', alt: '#a8242a', bottom: '#8a8090', pattern: 'zigzag' },
  Mosasaurus: { rarity: 'Mythic', base: '#2a5aa8', alt: '#3fe0ff', bottom: '#a8c8e8', pattern: 'waves' },
  PrimalRex: { rarity: 'Secret', base: '#e8e2d4', alt: '#2e2e33', bottom: '#cfc7b4', pattern: 'armor', glow: '#ff2a2a' },
  // 2026-10-12 roster expansion (tools/gen/NEW_DINOS_BRIEF.md); built only once the species' rig exists
  Oviraptor: { rarity: 'Uncommon', base: '#2f6f8a', alt: '#ff6a2a', bottom: '#efe0bd', pattern: 'stripes', top: '#ff6a2a' },
  Protoceratops: { rarity: 'Common', base: '#d9b07a', alt: '#8a5a32', bottom: '#f1e3c2', pattern: 'band', top: '#e88a9a' },
  Gallimimus: { rarity: 'Rare', base: '#7d93b0', alt: '#b5532c', bottom: '#f4efe4', pattern: 'zigzag' },
  Therizinosaurus: { rarity: 'Legendary', base: '#5a5e34', alt: '#a8562a', bottom: '#e8dcc0', pattern: 'patches', top: '#efe2c4' },
  Microraptor: { rarity: 'Rare', base: '#1c2230', alt: '#3fd0ff', bottom: '#5a6478', pattern: 'waves' },
  Psittacosaurus: { rarity: 'Common', base: '#7a5634', alt: '#3e2a1a', bottom: '#f3e6c8', pattern: 'band' },
  Compy: { rarity: 'Uncommon', base: '#c9773a', alt: '#f6efe2', bottom: '#f3e6c8', pattern: 'stripes', top: '#2e2420' },
  Yutyrannus: { rarity: 'Legendary', base: '#e8ecf2', alt: '#4a5a78', bottom: '#cfd8e6', pattern: 'zigzag', top: '#a8c8f0' },
  Coelophysis: { rarity: 'Common', base: '#e09a4a', alt: '#6e3a1e', bottom: '#f6e2bf', pattern: 'stripes' },
  Plateosaurus: { rarity: 'Uncommon', base: '#7a8a3a', alt: '#e8c45a', bottom: '#f3e6c0', pattern: 'band' },
  Dilophosaurus: { rarity: 'Rare', base: '#b6c23a', alt: '#d8342a', bottom: '#efe8c8', pattern: 'spots', top: '#ff5a2a' },
  Postosuchus: { rarity: 'Legendary', base: '#7a2a24', alt: '#2a1a18', bottom: '#d8b89a', pattern: 'tiles' },
  Sarcosuchus: { rarity: 'Epic', base: '#4e5a2e', alt: '#2a3018', bottom: '#cfc39a', pattern: 'tiles', top: '#8a8a4a' },
};
const RARITY_GLOW = { Rare: '#4aa8ff', Epic: '#b46bff', Legendary: '#ffb02e', Mythic: '#ff4f8b', Secret: '#ff2a2a' };

function particle(host, name, color, o = {}) {
  const e = new Inst('ParticleEmitter', name);
  e.set('Texture', 'Content', 'rbxasset://textures/particles/sparkles_main.dds');
  e.set('Rate', 'float', o.rate || 6);
  e.set('Lifetime', 'NumberRange', o.life || [0.6, 1.2]);
  e.set('Speed', 'NumberRange', o.speed || [0.5, 1.5]);
  e.set('SpreadAngle', 'Vector2', [180, 180]);
  e.set('Size', 'NumberSequence', [[0, o.size || 0.35], [1, 0]]);
  e.set('Transparency', 'NumberSequence', [[0, 0.1], [1, 1]]);
  const c = color.match(/\w\w/g).map((x) => parseInt(x, 16) / 255);
  e.set('Color', 'ColorSequence', [[0, c], [1, c]]);
  e.set('LightEmission', 'float', 0.8);
  e.set('LockedToPart', 'bool', true);
  host.add(e);
}

function buildEgg(species) {
  const S = SPECIES[species];
  const m = new Inst('Model', species + 'Egg');
  m.attr('Species', species).attr('Rarity', S.rarity);
  m.tag('DinoEgg');
  const c = new Ctx({ parent: m, frame: new CF(), defaults: { anchored: true } });
  const root = c.box({ name: 'EggRoot', s: [0.4, 0.4, 0.4], p: [0, H / 2, 0], t: 1, shadow: false });
  m.set('PrimaryPart', 'Ref', root);
  const lh = H / PROFILE.length;
  const layerY = (i) => lh * (i + 0.5);
  // stepped layers: a plus-shaped pair of boxes per layer reads as a pixel-rounded silhouette
  PROFILE.forEach((k, i) => {
    let col = S.base;
    if (i === 0) col = S.bottom;
    if (i >= PROFILE.length - 2 && S.top) col = S.top;
    if (S.pattern === 'stripes' && (i === 2 || i === 4 || i === 6)) col = S.alt;
    if (S.pattern === 'band' && (i === 3 || i === 4)) col = S.alt;
    const w = W * k;
    const studs = i === PROFILE.length - 1 ? 'top' : undefined;
    c.box({ name: 'Shell', s: [w, lh + 0.02, w * 0.72], p: [0, layerY(i), 0], c: col, studs });
    c.box({ name: 'Shell', s: [w * 0.72, lh + 0.02, w], p: [0, layerY(i), 0], c: shade(col, 0.94) });
  });
  // pattern details on the faces
  const face = (i, side, axis, s, colr, o = {}) => {
    const w = W * PROFILE[i];
    const off = w / 2 + 0.02;
    const p = axis === 'x' ? [side * off, layerY(i) + (o.dy || 0), o.u || 0] : [o.u || 0, layerY(i) + (o.dy || 0), side * off];
    const size = axis === 'x' ? [0.08, s[1], s[0]] : [s[0], s[1], 0.08];
    return c.box({ name: o.name || 'Pattern', s: size, p, r: o.r || [0, 0, 0], c: colr, m: o.m, shadow: false });
  };
  const allFaces = (fn) => { for (const side of [-1, 1]) for (const axis of ['x', 'z']) fn(side, axis); };
  if (S.pattern === 'spots') allFaces((side, axis) => { face(3, side, axis, [0.34, 0.3], S.alt, { u: 0.25 * side }); face(5, side, axis, [0.26, 0.22], S.alt, { u: -0.2 * side }); face(2, side, axis, [0.22, 0.2], S.alt, { u: -0.3 }); });
  if (S.pattern === 'diamonds') allFaces((side, axis) => { face(3, side, axis, [0.36, 0.36], S.alt, { r: axis === 'x' ? [45, 0, 0] : [0, 0, 45], dy: 0.04 }); face(5, side, axis, [0.24, 0.24], S.alt, { r: axis === 'x' ? [45, 0, 0] : [0, 0, 45] }); });
  if (S.pattern === 'tiles') allFaces((side, axis) => { for (const i of [2, 3, 4, 5]) for (const u of [-0.3, 0.3]) face(i, side, axis, [0.4, lh * 0.75], i % 2 ? S.alt : shade(S.base, 0.8), { u }); });
  if (S.pattern === 'patches') allFaces((side, axis) => { face(4, side, axis, [0.5, 0.36], S.alt, { u: 0.15 * side }); face(2, side, axis, [0.3, 0.24], S.alt, { u: -0.25 * side }); });
  if (S.pattern === 'fin') for (const side of [-1, 1]) for (let i = 1; i < PROFILE.length - 1; i++) face(i, side, 'z', [0.26, lh + 0.02], S.alt);
  if (S.pattern === 'zigzag') allFaces((side, axis) => { [-0.36, -0.12, 0.12, 0.36].forEach((u, j) => face(j % 2 ? 4 : 3, side, axis, [0.22, lh * 0.9], S.alt, { u })); });
  if (S.pattern === 'waves') for (const i of [2, 5]) { const w = W * PROFILE[i]; c.box({ name: 'WaveBand', s: [w + 0.06, 0.12, w * 0.72 + 0.06], p: [0, layerY(i) + 0.1, 0], c: S.alt, shadow: false }); c.box({ name: 'WaveBand', s: [w * 0.72 + 0.06, 0.12, w + 0.06], p: [0, layerY(i) - 0.06, 0], c: S.alt, shadow: false }); }
  if (S.pattern === 'armor') {
    allFaces((side, axis) => { face(3, side, axis, [0.55, lh * 0.9], S.alt); face(5, side, axis, [0.4, lh * 0.9], S.alt); });
    // glowing crimson cracks
    for (const [i, side, axis, r] of [[4, 1, 'z', 30], [2, -1, 'x', -25], [6, 1, 'x', 40], [4, -1, 'z', -35]]) {
      const k = face(i, side, axis, [0.5, 0.07], S.glow, { r: axis === 'x' ? [r, 0, 0] : [0, 0, r], m: 'Neon', name: 'GlowCrack' });
      k.tag('EggGlow');
    }
  }
  if (S.extra === 'horns') for (const x of [-0.25, 0, 0.25]) c.wedgeF({ name: 'HornNub', s: [0.16, 0.26, 0.2], p: [x, H - lh * 0.15 + 0.1, 0], face: 'front', c: S.top });
  if (S.extra === 'bullhorns') c.sym((s) => s.wedgeF({ name: 'HornNub', s: [0.18, 0.3, 0.22], p: [0.22, H + 0.05, 0], face: 'right', c: '#efe2c4' }));

  // rarity effects
  const glow = RARITY_GLOW[S.rarity];
  if (glow) {
    const gem = c.box({ name: 'RarityGem', s: [0.3, 0.3, 0.12], p: [0, layerY(4), -(W * PROFILE[4]) / 2 - 0.04], r: [0, 0, 45], c: glow, m: 'Neon', shadow: false });
    gem.tag('EggGlow');
  }
  if (['Epic', 'Legendary', 'Mythic', 'Secret'].includes(S.rarity)) particle(root, 'Sparkles', glow, { rate: S.rarity === 'Epic' ? 4 : 8 });
  if (S.rarity === 'Legendary') {
    const i = PROFILE.length - 3, w = W * PROFILE[i];
    c.box({ name: 'GoldCrown', s: [w + 0.08, 0.16, w * 0.72 + 0.08], p: [0, layerY(i), 0], c: '#ffcf3a', m: 'Metal', refl: 0.2 });
    c.box({ name: 'GoldCrown', s: [w * 0.72 + 0.08, 0.16, w + 0.08], p: [0, layerY(i), 0], c: '#ffcf3a', m: 'Metal', refl: 0.2 });
    for (const [x, z] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) c.wedgeF({ name: 'CrownPoint', s: [0.2, 0.22, 0.2], p: [x * w * 0.46, layerY(i) + 0.19, z * w * 0.46], face: 'front', c: '#ffcf3a', m: 'Metal' });
  }
  if (S.rarity === 'Legendary' || S.rarity === 'Mythic' || S.rarity === 'Secret') {
    const pl = new Inst('PointLight', 'EggLight');
    pl.set('Color', 'Color3', glow.match(/\w\w/g).map((x) => parseInt(x, 16) / 255));
    pl.set('Range', 'float', 8).set('Brightness', 'float', 1.2).set('Shadows', 'bool', false);
    root.add(pl);
  }
  if (S.rarity === 'Mythic' || S.rarity === 'Secret') particle(root, 'Aura', glow, { rate: 12, size: 0.6, speed: [0.2, 0.6], life: [1, 1.6] });
  return m;
}

module.exports = { buildEgg, EGG_SPECIES: SPECIES, EGG_HEIGHT: H };
