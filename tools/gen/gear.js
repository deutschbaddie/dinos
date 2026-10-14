// GEAR — armor you wear and the launcher you carry, one design per tier (the shop icons are the brief: a padded
// khaki explorer vest with orange shoulder plates and a dino-tooth badge; a stubby orange-and-steel dart pistol
// with a glass dart chamber glowing green), then every later tier riffs on its ruler.
//
// Armor/<Tier>: a Model of PIECES. Each piece is a Model authored in its bone's own space (R6 reference sizes:
// Torso 2x2x1, arm 1x2x1, head 1.2 cube) with an invisible PieceRoot at the origin, and attributes:
//   Bone     Torso | RightArm | LeftArm | Head        Align  Top | Bottom | Center (where it hugs the bone)
//   Part     UpperArm | LowerArm (R15 arm segment)    MinLevel  the armor level it appears at (1, 3, 6, 9, 10)
// Launchers/<Id>: a Model with PrimaryPart GripRoot at the hand's grip point; the barrel runs down -Y (along the
// arm), the sights face -Z; part "Tip" carries the Muzzle attachment. Mannequin: an R6-sized dummy on a stand.
const { Inst, Ctx, CF } = require('./builder.js');

// ---------------------------------------------------------------------------------------------------------
// armor tiers
// ---------------------------------------------------------------------------------------------------------
// (2026-10-13 redesign, user: "upgrade how the armor looks - I want it to be cool"). One chassis for every tier: a
// dark under-suit with layered plates over it (bevelled chest plate, segmented abs, a raised collar, the tier's
// diamond emblem with a small glowing core), stacked pauldrons, plated bracers with a wrist screen, knee + shin
// guards, a ranger helmet with goggles, a split cape. Each tier then adds its own boss's pieces. No "Fabric" plates:
// that texture made the old khaki vest read as cardboard.
//   suit  the under-layer      plate / plate2  the armour, two tones      trim  edges + emblems
//   glow  the small neon cores (kept tiny: camp stays calm)               metal  rivets, claws, blades
const ARMOR = {
  None: { suit: '#2f3833', plate: '#c99c5c', plate2: '#9c763f', trim: '#ff8a1f', glow: '#5fe36a', metal: '#8e959c', motif: 'explorer' },
  RaptorHide: { suit: '#261a14', plate: '#7a3f22', plate2: '#55301b', trim: '#e9d9b2', glow: '#ff9a2e', metal: '#efe4c8', motif: 'hide' },
  MatriarchPlate: { suit: '#1b2826', plate: '#3f7a70', plate2: '#2a5650', trim: '#c9d4d2', glow: '#6ee8d6', metal: '#b9c3c4', motif: 'plate' },
  TideShell: { suit: '#10263f', plate: '#2f6fb3', plate2: '#1f4f86', trim: '#f3fbff', glow: '#7fe3ff', metal: '#ff8a6a', motif: 'shell' },
  ScytheMail: { suit: '#25272b', plate: '#e8dcc0', plate2: '#c2b48f', trim: '#8a2f2a', glow: '#ff5a3a', metal: '#34373d', motif: 'bone' },
  FrostCoat: { suit: '#2b3f51', plate: '#eaf4ff', plate2: '#bfd5e6', trim: '#8fd8ff', glow: '#c8f6ff', metal: '#9fc6e0', motif: 'frost' },
  DawnScutes: { suit: '#26110b', plate: '#b33a22', plate2: '#7e2a18', trim: '#ffc824', glow: '#ffb347', metal: '#ffcf6a', motif: 'dawn' },
};
const PLATE = 'SmoothPlastic';

function pieceModel(parent, name, attrs) {
  const m = new Inst('Model', name);
  for (const [k, v] of Object.entries(attrs)) m.attr(k, v);
  parent.add(m);
  const c = new Ctx({ parent: m, frame: new CF(), defaults: { anchored: true } });
  const root = c.box({ name: 'PieceRoot', s: [0.2, 0.2, 0.2], t: 1, shadow: false });
  m.set('PrimaryPart', 'Ref', root);
  return c;
}

// the tier's emblem: a diamond in trim with a small glowing core. `face` = the axis it faces out of
function emblem(c, P, at, size, face) {
  const r = face === 'x' ? [45, 0, 0] : [0, 0, 45];
  const d = face === 'x' ? [0.05, size, size] : [size, size, 0.05];
  const dd = face === 'x' ? [0.06, size * 0.55, size * 0.55] : [size * 0.55, size * 0.55, 0.06];
  const o = face === 'x' ? [Math.sign(at[3] || 1) * 0.012, 0, 0] : [0, 0, -0.012];
  c.box({ name: 'Emblem', s: d, p: [at[0], at[1], at[2]], r, c: P.trim, m: 'Metal', shadow: false });
  c.box({ name: 'EmblemCore', s: dd, p: [at[0] + o[0], at[1], at[2] + o[2]], r, c: P.glow, m: 'Neon', shadow: false });
}

// a row of points (claws, teeth, coral, crystals, scutes) along x at `at`, pointing up (dir 1) or down (-1)
function points(c, P, at, n, len, dir, spread, col, mat) {
  for (let i = 0; i < n; i++) {
    const x = at[0] + (i - (n - 1) / 2) * spread;
    c.box({ name: 'Point', s: [0.15, len, 0.15], p: [x, at[1] + (len / 2) * dir, at[2]], r: [0, 45, (i - (n - 1) / 2) * 10 * dir], c: col, m: mat || 'SmoothPlastic' });
  }
}

// ---------------------------------------------------------------------------------------------------------
// LV 1: the vest (Torso space: R6 torso 2 x 2 x 1, front is -Z)
// ---------------------------------------------------------------------------------------------------------
function buildVest(A, P) {
  const c = pieceModel(A, 'Vest', { Bone: 'Torso', Align: 'Top', MinLevel: 1 });
  // the under-suit carrier (front panels stay thin: carried eggs and newborns are held against the chest)
  c.box({ name: 'SuitFront', s: [2.06, 1.88, 0.1], p: [0, 0.03, -0.53], c: P.suit, m: PLATE });
  c.box({ name: 'SuitBack', s: [2.06, 1.88, 0.12], p: [0, 0.03, 0.54], c: P.suit, m: PLATE });
  for (const sx of [-1, 1]) {
    c.box({ name: 'SuitSide', s: [0.1, 1.8, 1.06], p: [sx * 1.04, 0, 0], c: P.suit, m: PLATE });
    for (const y of [0.35, 0.05, -0.25]) c.box({ name: 'Webbing', s: [0.03, 0.07, 0.78], p: [sx * 1.095, y, 0], c: P.plate2, shadow: false });
    // over-the-shoulder straps
    c.box({ name: 'ShoulderStrap', s: [0.32, 0.12, 1.16], p: [sx * 0.66, 1.0, 0], c: P.suit, m: PLATE });
    c.box({ name: 'StrapTrim', s: [0.06, 0.13, 1.17], p: [sx * 0.8, 1.0, 0], c: P.trim, shadow: false });
  }
  // chest plate: bevelled corners (45-degree caps), a centre ridge, a trim line under it
  c.box({ name: 'ChestPlate', s: [1.72, 0.74, 0.1], p: [0, 0.5, -0.6], c: P.plate, m: PLATE, refl: 0.04 });
  for (const sx of [-1, 1]) c.box({ name: 'ChestBevel', s: [0.34, 0.34, 0.1], p: [sx * 0.86, 0.86, -0.6], r: [0, 0, 45], c: P.plate, m: PLATE, refl: 0.04 });
  c.box({ name: 'ChestTop', s: [1.3, 0.2, 0.1], p: [0, 0.92, -0.6], c: P.plate, m: PLATE, refl: 0.04 });
  c.box({ name: 'ChestRidge', s: [0.26, 0.9, 0.06], p: [0, 0.48, -0.66], c: P.plate2, m: PLATE });
  c.box({ name: 'ChestTrim', s: [1.74, 0.07, 0.08], p: [0, 0.12, -0.62], c: P.trim, shadow: false });
  emblem(c, P, [0, 0.56, -0.7], 0.4, 'z');
  // segmented ab plates (gaps show the suit)
  c.box({ name: 'AbPlate', s: [1.46, 0.3, 0.1], p: [0, -0.13, -0.6], c: P.plate2, m: PLATE });
  c.box({ name: 'AbPlate', s: [1.28, 0.28, 0.1], p: [0, -0.47, -0.6], c: P.plate2, m: PLATE });
  // the collar: a low gorget in front, a raised guard behind the head
  c.box({ name: 'Gorget', s: [1.0, 0.2, 0.14], p: [0, 1.05, -0.47], r: [-22, 0, 0], c: P.plate2, m: PLATE });
  c.box({ name: 'NeckGuard', s: [1.5, 0.44, 0.16], p: [0, 1.12, 0.5], r: [12, 0, 0], c: P.plate, m: PLATE });
  c.box({ name: 'NeckGuardTrim', s: [1.52, 0.07, 0.17], p: [0, 1.33, 0.53], r: [12, 0, 0], c: P.trim, shadow: false });
  // back plate + spine ridge
  c.box({ name: 'BackPlate', s: [1.6, 1.0, 0.1], p: [0, 0.35, 0.61], c: P.plate, m: PLATE, refl: 0.04 });
  c.box({ name: 'SpineRidge', s: [0.24, 1.02, 0.06], p: [0, 0.35, 0.68], c: P.plate2, m: PLATE });
  // belt: buckle emblem, hip pouches with trimmed flaps, three glowing dart vials
  c.box({ name: 'Belt', s: [2.14, 0.24, 1.18], p: [0, -0.84, 0], c: P.suit, m: PLATE });
  c.box({ name: 'BeltBand', s: [2.16, 0.06, 1.2], p: [0, -0.76, 0], c: P.plate2, shadow: false });
  emblem(c, P, [0, -0.85, -0.62], 0.3, 'z');
  for (const sx of [-1, 1]) {
    c.box({ name: 'Pouch', s: [0.4, 0.36, 0.3], p: [sx * 0.8, -0.88, -0.52], c: P.plate2, m: PLATE });
    c.box({ name: 'PouchFlap', s: [0.42, 0.1, 0.32], p: [sx * 0.8, -0.72, -0.52], c: P.trim, shadow: false });
  }
  for (let i = 0; i < 3; i++) {
    const x = -0.52 + i * 0.13;
    c.box({ name: 'Vial', s: [0.1, 0.3, 0.1], p: [x, -0.86, -0.64], c: '#d9f3ff', m: 'Glass', t: 0.35, shadow: false });
    c.box({ name: 'VialCore', s: [0.05, 0.2, 0.05], p: [x, -0.87, -0.64], c: P.glow, m: 'Neon', shadow: false });
  }
  // tier pieces (never over the chest's centre: eggs ride there)
  if (P.motif === 'hide') {
    points(c, P, [0, 1.02, -0.56], 5, 0.22, -1, 0.2, P.trim); // a necklace of rex teeth
    for (let i = 0; i < 6; i++) c.box({ name: 'Scale', s: [0.2, 0.2, 0.05], p: [-0.5 + (i % 3) * 0.5, -0.13 - Math.floor(i / 3) * 0.34, -0.66], r: [0, 0, 45], c: P.plate, shadow: false });
  }
  if (P.motif === 'plate') {
    for (const sx of [-1, 1]) for (const y of [0.75, 0.25, -0.13]) c.cyl({ name: 'Rivet', axis: 'z', len: 0.05, d: 0.11, p: [sx * 0.66, y, -0.66], c: P.metal, m: 'Metal' });
    for (let i = 0; i < 3; i++) c.box({ name: 'BackSlab', s: [1.7 - i * 0.28, 0.3, 0.12], p: [0, 0.68 - i * 0.36, 0.7], c: i % 2 ? P.plate2 : P.plate, m: PLATE });
  }
  if (P.motif === 'shell') for (let i = 0; i < 4; i++) c.cyl({ name: 'ShellRidge', axis: 'z', len: 0.06, d: 1.5 - i * 0.3, p: [0, 0.3 + i * 0.1, 0.68 + i * 0.03], c: i % 2 ? P.trim : P.plate });
  if (P.motif === 'bone') {
    for (let i = 0; i < 3; i++) for (const sx of [-1, 1]) c.box({ name: 'Rib', s: [0.5, 0.09, 0.06], p: [sx * 0.55, 0.72 - i * 0.2, -0.66], r: [0, 0, sx * -12], c: P.trim, shadow: false });
    for (let i = 0; i < 4; i++) c.box({ name: 'Vertebra', s: [0.3, 0.16, 0.16], p: [0, 0.75 - i * 0.28, 0.74], r: [0, 0, 45], c: P.plate });
  }
  if (P.motif === 'frost') {
    c.box({ name: 'FurCollar', s: [1.7, 0.34, 1.26], p: [0, 1.02, 0], c: '#ffffff', m: 'Fabric' });
    c.box({ name: 'FurHem', s: [2.2, 0.22, 1.22], p: [0, -0.64, 0], c: '#f4f8ff', m: 'Fabric' });
  }
  if (P.motif === 'dawn') {
    for (let i = 0; i < 5; i++) c.box({ name: 'Scute', s: [0.22, 0.22, 0.22], p: [0, 0.85 - i * 0.26, 0.74], r: [45, 0, 0], c: P.plate2 });
    c.cyl({ name: 'SunDisc', axis: 'z', len: 0.05, d: 0.7, p: [0, 0.35, 0.82], c: P.trim, refl: 0.2 });
  }
}

// ---------------------------------------------------------------------------------------------------------
// LV 3: pauldrons (UpperArm space, top at +1; +X is outward)
// ---------------------------------------------------------------------------------------------------------
function buildShoulder(A, P, side) {
  const nm = side > 0 ? 'ShoulderR' : 'ShoulderL';
  const c0 = pieceModel(A, nm, { Bone: side > 0 ? 'RightArm' : 'LeftArm', Part: 'UpperArm', Align: 'Top', MinLevel: 3 });
  const c = side > 0 ? c0 : c0.clone({ mirrored: true });
  const s = c.at([0.14, 0.9, 0], [0, 0, -16]);
  // three stacked plates, each trimmed along its outer edge
  const plates = [[1.34, 0.32, 1.28, 0, 0], [1.2, 0.27, 1.16, 0.1, -0.28], [1.04, 0.24, 1.02, 0.18, -0.52]];
  plates.forEach(([w, h, d, x, y], i) => {
    s.box({ name: 'Pauldron', s: [w, h, d], p: [x, y, 0], c: i === 1 ? P.plate2 : P.plate, m: PLATE, refl: 0.04 });
    s.box({ name: 'PauldronTrim', s: [0.06, h + 0.01, d + 0.01], p: [x + w / 2, y, 0], c: P.trim, shadow: false });
  });
  s.box({ name: 'PauldronCap', s: [1.0, 0.1, 0.94], p: [-0.04, 0.2, 0], c: P.plate2, m: PLATE });
  s.box({ name: 'PauldronStrap', s: [0.12, 0.5, 1.12], p: [-0.36, -0.26, 0], c: P.suit });
  emblem(s, P, [0.69, -0.02, 0, 1], 0.26, 'x');
  if (P.motif === 'hide') points(s, P, [0.1, 0.24, 0], 3, 0.44, 1, 0.3, P.metal); // claws
  if (P.motif === 'plate') for (const z of [-0.3, 0.3]) s.box({ name: 'Fin', s: [0.9, 0.36, 0.08], p: [0.05, 0.36, z], c: P.plate2, m: PLATE });
  if (P.motif === 'shell') { s.cyl({ name: 'ShellDome', axis: 'z', len: 1.1, d: 0.6, p: [0.05, 0.22, 0], c: P.plate }); points(s, P, [0.1, 0.5, 0], 3, 0.32, 1, 0.26, P.metal); }
  if (P.motif === 'bone') s.box({ name: 'ScytheBlade', s: [0.08, 1.5, 0.36], p: [0.5, 0.55, 0.25], r: [-35, 0, -18], c: P.metal, m: 'Metal' });
  if (P.motif === 'frost') { s.box({ name: 'Fur', s: [1.3, 0.2, 1.3], p: [0, -0.72, 0], c: '#ffffff', m: 'Fabric' }); points(s, P, [0.1, 0.24, 0], 3, 0.5, 1, 0.28, P.trim, 'Glass'); }
  if (P.motif === 'dawn') points(s, P, [0.05, 0.22, 0], 3, 0.3, 1, 0.34, P.trim);
}

// ---------------------------------------------------------------------------------------------------------
// LV 6: bracers (LowerArm space, bottom at -1) and knee + shin guards (lower leg, top at the knee)
// ---------------------------------------------------------------------------------------------------------
function buildGauntlet(A, P, side) {
  const nm = side > 0 ? 'GauntletR' : 'GauntletL';
  const c0 = pieceModel(A, nm, { Bone: side > 0 ? 'RightArm' : 'LeftArm', Part: 'LowerArm', Align: 'Bottom', MinLevel: 6 });
  const c = side > 0 ? c0 : c0.clone({ mirrored: true });
  c.box({ name: 'Bracer', s: [1.1, 0.95, 1.1], p: [0, -0.48, 0], c: P.suit, m: PLATE });
  c.box({ name: 'BracerPlate', s: [0.1, 0.86, 0.84], p: [0.58, -0.48, 0], c: P.plate, m: PLATE, refl: 0.04 });
  c.box({ name: 'BracerRidge', s: [0.06, 0.86, 0.22], p: [0.64, -0.48, 0], c: P.plate2, m: PLATE });
  for (const y of [-0.02, -0.94]) c.box({ name: 'BracerBand', s: [1.14, 0.09, 1.14], p: [0, y, 0], c: P.trim, shadow: false });
  // the wrist screen
  c.box({ name: 'WristScreen', s: [0.4, 0.26, 0.06], p: [0, -0.55, -0.58], c: '#16191d', m: PLATE });
  c.box({ name: 'WristScreenGlow', s: [0.3, 0.06, 0.07], p: [0, -0.52, -0.585], c: P.glow, m: 'Neon', shadow: false });
  if (P.motif === 'hide' || P.motif === 'dawn') points(c, P, [0.62, -0.3, 0], 3, 0.3, 1, 0.26, P.metal);
  if (P.motif === 'bone') c.box({ name: 'ForearmBlade', s: [0.08, 1.2, 0.3], p: [0.66, -0.2, 0.2], r: [-25, 0, 0], c: P.metal, m: 'Metal' });
  if (P.motif === 'frost') c.box({ name: 'Crystal', s: [0.16, 0.5, 0.16], p: [0.62, -0.3, 0], r: [0, 45, -25], c: P.trim, m: 'Glass' });
  if (P.motif === 'shell') c.cyl({ name: 'ShellCuff', axis: 'x', len: 0.12, d: 0.7, p: [0.62, -0.48, 0], c: P.trim });
  if (P.motif === 'plate') for (const y of [-0.25, -0.7]) c.cyl({ name: 'Rivet', axis: 'x', len: 0.05, d: 0.1, p: [0.64, y, 0.28], c: P.metal, m: 'Metal' });
}

function buildGreave(A, P, side) {
  const nm = side > 0 ? 'GreaveR' : 'GreaveL';
  // authored on a 1-stud-tall lower-leg segment: top (the knee) at +0.5
  const c0 = pieceModel(A, nm, { Bone: side > 0 ? 'RightLeg' : 'LeftLeg', Part: 'LowerLeg', Align: 'Top', MinLevel: 6 });
  const c = side > 0 ? c0 : c0.clone({ mirrored: true });
  c.box({ name: 'KneePad', s: [0.9, 0.42, 0.18], p: [0, 0.42, -0.56], c: P.plate, m: PLATE, refl: 0.04 });
  c.box({ name: 'KneePadTrim', s: [0.92, 0.07, 0.19], p: [0, 0.6, -0.56], c: P.trim, shadow: false });
  c.box({ name: 'KneeBevel', s: [0.3, 0.3, 0.18], p: [0, 0.22, -0.56], r: [0, 0, 45], c: P.plate, m: PLATE });
  c.box({ name: 'ShinPlate', s: [0.74, 0.62, 0.1], p: [0, -0.15, -0.53], c: P.plate2, m: PLATE });
  c.box({ name: 'ShinStrap', s: [1.06, 0.1, 1.06], p: [0, 0.02, 0], c: P.suit });
  if (P.motif === 'hide' || P.motif === 'dawn') points(c, P, [0, 0.62, -0.56], 1, 0.26, 1, 0, P.metal);
  if (P.motif === 'frost') c.box({ name: 'FurCuff', s: [1.1, 0.18, 1.1], p: [0, -0.4, 0], c: '#ffffff', m: 'Fabric' });
}

// ---------------------------------------------------------------------------------------------------------
// LV 9: the helmet (Head space, R6 head 1.2) - a ranger helmet with goggles up on the brow
// ---------------------------------------------------------------------------------------------------------
function buildHelmet(A, P) {
  const c = pieceModel(A, 'Helmet', { Bone: 'Head', Align: 'Center', MinLevel: 9 });
  c.box({ name: 'HelmDome', s: [1.34, 0.46, 1.36], p: [0, 0.6, 0.02], c: P.plate, m: PLATE, refl: 0.04 });
  c.box({ name: 'HelmTop', s: [1.0, 0.16, 1.04], p: [0, 0.89, 0.04], c: P.plate, m: PLATE, refl: 0.04 });
  c.box({ name: 'HelmRidge', s: [0.22, 0.12, 1.2], p: [0, 0.99, 0.04], c: P.plate2, m: PLATE });
  c.box({ name: 'HelmPeak', s: [1.38, 0.1, 0.3], p: [0, 0.38, -0.7], r: [12, 0, 0], c: P.plate2, m: PLATE });
  c.box({ name: 'HelmBack', s: [1.3, 0.4, 0.14], p: [0, 0.3, 0.66], c: P.plate2, m: PLATE });
  for (const sx of [-1, 1]) {
    c.box({ name: 'EarGuard', s: [0.14, 0.5, 0.7], p: [sx * 0.68, 0.22, 0.05], c: P.plate2, m: PLATE });
    c.box({ name: 'EarTrim', s: [0.15, 0.08, 0.72], p: [sx * 0.68, 0.46, 0.05], c: P.trim, shadow: false });
    // goggles pushed up on the brow
    c.box({ name: 'GoggleLens', s: [0.34, 0.22, 0.1], p: [sx * 0.28, 0.6, -0.7], c: P.glow, m: 'Glass', t: 0.25, refl: 0.2 });
    c.box({ name: 'GoggleRim', s: [0.4, 0.28, 0.06], p: [sx * 0.28, 0.6, -0.66], c: P.suit });
  }
  c.box({ name: 'GoggleStrap', s: [1.38, 0.08, 1.38], p: [0, 0.6, 0.02], c: P.suit, shadow: false });
  c.box({ name: 'Antenna', s: [0.05, 0.6, 0.05], p: [-0.74, 0.62, 0.2], c: P.metal, m: 'Metal', shadow: false });
  c.ball({ name: 'AntennaTip', d: 0.1, p: [-0.74, 0.94, 0.2], c: P.glow, m: 'Neon' });
  if (P.motif === 'hide') points(c, P, [0, 0.38, -0.82], 5, 0.18, -1, 0.24, P.trim);
  if (P.motif === 'plate') c.box({ name: 'Crest', s: [0.14, 0.4, 1.1], p: [0, 1.18, 0.04], c: P.trim, m: 'Metal' });
  if (P.motif === 'shell') points(c, P, [0, 1.02, 0.1], 5, 0.34, 1, 0.22, P.metal);
  if (P.motif === 'bone') for (const sx of [-1, 1]) c.box({ name: 'Horn', s: [0.16, 0.66, 0.16], p: [sx * 0.52, 1.08, 0.1], r: [0, 0, sx * -25], c: P.plate });
  if (P.motif === 'frost') { c.box({ name: 'FurBrim', s: [1.5, 0.2, 1.5], p: [0, 0.4, 0.04], c: '#ffffff', m: 'Fabric' }); c.box({ name: 'Crystal', s: [0.18, 0.5, 0.18], p: [0, 1.15, 0.04], r: [0, 45, 0], c: P.trim, m: 'Glass' }); }
  if (P.motif === 'dawn') for (let i = 0; i < 5; i++) { const a = Math.PI * (0.15 + i * 0.175); c.box({ name: 'Ray', s: [0.12, 0.34, 0.08], p: [Math.cos(a) * 0.82, 0.62 + Math.sin(a) * 0.82, 0.68], r: [0, 0, -90 + (0.15 + i * 0.175) * 180], c: P.trim }); }
}

// ---------------------------------------------------------------------------------------------------------
// LV 10: a split cape (three panels, trimmed hems, clasps with glowing gems)
// ---------------------------------------------------------------------------------------------------------
function buildCape(A, P) {
  const c = pieceModel(A, 'Cape', { Bone: 'Torso', Align: 'Top', MinLevel: 10 });
  const col = P.motif === 'frost' ? '#9fc6e0' : P.plate2;
  [[-0.6, 0.62, -5, 2.2], [0, 0.66, -7, 2.4], [0.6, 0.62, -5, 2.2]].forEach(([x, w, tilt, h]) => {
    c.box({ name: 'CapePanel', s: [w, h, 0.07], p: [x, 0.95 - h / 2, 0.76], r: [tilt, 0, x * -4], c: col, m: 'Fabric' });
    c.box({ name: 'CapeHem', s: [w + 0.02, 0.12, 0.09], p: [x, 0.95 - h + 0.06, 0.76 + Math.sin(-tilt * Math.PI / 180) * h], r: [tilt, 0, x * -4], c: P.trim, shadow: false });
  });
  for (const sx of [-1, 1]) {
    c.cyl({ name: 'Clasp', axis: 'z', len: 0.1, d: 0.32, p: [sx * 0.76, 0.86, 0.66], c: P.trim, m: 'Metal' });
    c.ball({ name: 'ClaspGem', d: 0.16, p: [sx * 0.76, 0.86, 0.6], c: P.glow, m: 'Neon' });
  }
}

function buildArmor(id) {
  const P = ARMOR[id];
  const A = new Inst('Model', id);
  A.attr('Tier', id);
  buildVest(A, P);
  buildShoulder(A, P, 1); buildShoulder(A, P, -1);
  buildGauntlet(A, P, 1); buildGauntlet(A, P, -1);
  buildGreave(A, P, 1); buildGreave(A, P, -1);
  buildHelmet(A, P);
  buildCape(A, P);
  return A;
}

// ---------------------------------------------------------------------------------------------------------
// launchers
// ---------------------------------------------------------------------------------------------------------
const LAUNCH = {
  Rookie: { body: '#f08a24', lo: '#c4661a', steel: '#9aa0a6', dart: '#5fe36a' },
  QueensFang: { body: '#ff8a3a', lo: '#b8461c', steel: '#c9b48a', dart: '#ffb347', extra: 'fangs' },
  MatriarchMortar: { body: '#3d8f84', lo: '#24544e', steel: '#b9c3c4', dart: '#6ee8d6', extra: 'drum' },
  TideHarpoon: { body: '#2f6fb3', lo: '#1c4675', steel: '#dfe9f2', dart: '#7fe3ff', extra: 'harpoon' },
  ScytheRepeater: { body: '#e8dcc0', lo: '#9e8f70', steel: '#2b2d31', dart: '#f2e6c6', extra: 'scythe' },
  FrostCannon: { body: '#cfe7f7', lo: '#7fa6c2', steel: '#eef6ff', dart: '#8fd8ff', extra: 'frost' },
  DawnBreaker: { body: '#d9502c', lo: '#7e2a18', steel: '#ffcf6a', dart: '#ffb347', extra: 'dawn' },
};

function buildLauncher(id) {
  const L = LAUNCH[id];
  const m = new Inst('Model', id);
  const c = new Ctx({ parent: m, frame: new CF(), defaults: { anchored: true } });
  const root = c.box({ name: 'GripRoot', s: [0.2, 0.2, 0.2], t: 1, shadow: false });
  m.set('PrimaryPart', 'Ref', root);
  const dark = '#2b2d31';
  // the stubby pistol: grip in the hand, chunky body, steel barrel, the glass chamber with a glowing dart
  c.box({ name: 'Grip', s: [0.46, 0.5, 0.9], p: [0, 0.05, 0.22], r: [-12, 0, 0], c: dark });
  c.box({ name: 'TriggerGuard', s: [0.12, 0.42, 0.42], p: [0, -0.32, 0.38], c: dark });
  c.box({ name: 'Body', s: [0.74, 1.25, 0.86], p: [0, -0.62, -0.15], c: L.body });
  c.box({ name: 'BodyTop', s: [0.6, 1.0, 0.16], p: [0, -0.62, -0.62], c: L.lo });
  c.cyl({ name: 'Chamber', axis: 'y', len: 0.9, d: 0.62, p: [0, -1.15, -0.15], c: '#d9f3ff', m: 'Glass', t: 0.45 });
  c.cyl({ name: 'ChamberDart', axis: 'y', len: 0.7, d: 0.18, p: [0, -1.15, -0.15], c: L.dart, m: 'Neon' });
  for (const y of [-0.68, -1.62]) c.cyl({ name: 'ChamberRing', axis: 'y', len: 0.1, d: 0.68, p: [0, y, -0.15], c: L.steel, m: 'Metal' });
  c.cyl({ name: 'Barrel', axis: 'y', len: 1.3, d: 0.42, p: [0, -2.25, -0.15], c: L.steel, m: 'Metal' });
  const tip = c.cyl({ name: 'Tip', axis: 'y', len: 0.28, d: 0.56, p: [0, -2.95, -0.15], c: L.lo, m: 'Metal' });
  c.box({ name: 'FrontSight', s: [0.1, 0.18, 0.16], p: [0, -2.85, -0.42], c: dark });
  c.box({ name: 'RearSight', s: [0.3, 0.16, 0.14], p: [0, -0.2, -0.72], c: dark });
  c.box({ name: 'Hammer', s: [0.16, 0.2, 0.26], p: [0, 0.02, -0.5], r: [-30, 0, 0], c: dark });
  // tier extras
  if (L.extra === 'fangs') for (const sx of [-1, 1]) c.box({ name: 'Fang', s: [0.14, 0.62, 0.14], p: [sx * 0.24, -3.05, -0.38], r: [-22, 0, sx * 8], c: '#fbf6e6' });
  if (L.extra === 'drum') { c.cyl({ name: 'Drum', axis: 'y', len: 0.9, d: 1.15, p: [0, -1.15, -0.15], c: L.body, m: 'Metal' }); c.cyl({ name: 'Bore', axis: 'y', len: 0.3, d: 0.78, p: [0, -3.05, -0.15], c: dark }); }
  if (L.extra === 'harpoon') { c.cyl({ name: 'HarpoonShaft', axis: 'y', len: 0.8, d: 0.14, p: [0, -3.35, -0.15], c: L.steel, m: 'Metal' }); for (const sx of [-1, 1]) c.box({ name: 'Barb', s: [0.12, 0.42, 0.12], p: [sx * 0.18, -3.55, -0.15], r: [0, 0, sx * 32], c: L.steel, m: 'Metal' }); c.cyl({ name: 'LineCoil', axis: 'x', len: 0.3, d: 0.66, p: [-0.5, -0.8, -0.15], c: '#c8a874' }); }
  if (L.extra === 'scythe') { for (const sx of [-1, 1]) { c.cyl({ name: 'SideBarrel', axis: 'y', len: 1.2, d: 0.26, p: [sx * 0.3, -2.2, -0.15], c: L.steel, m: 'Metal' }); c.box({ name: 'ScytheBlade', s: [0.08, 1.1, 0.3], p: [sx * 0.46, -1.4, 0.1], r: [0, 0, sx * -18], c: L.steel }); } }
  if (L.extra === 'frost') { for (let i = 0; i < 4; i++) c.box({ name: 'IceCrystal', s: [0.14, 0.44, 0.14], p: [Math.cos(i * 1.57) * 0.34, -2.75, -0.15 + Math.sin(i * 1.57) * 0.34], r: [Math.sin(i * 1.57) * 25, 0, -Math.cos(i * 1.57) * 25], c: L.dart, m: 'Glass' }); }
  if (L.extra === 'dawn') { c.cyl({ name: 'SunDisc', axis: 'x', len: 0.08, d: 1.0, p: [0, -1.15, -0.15], c: L.steel, refl: 0.25 }); for (let i = 0; i < 6; i++) { const a = (i / 6) * Math.PI * 2; c.box({ name: 'SunRay', s: [0.08, 0.3, 0.12], p: [0, -1.15 + Math.cos(a) * 0.62, -0.15 + Math.sin(a) * 0.62], r: [(a * 180) / Math.PI, 0, 0], c: L.steel }); } }
  const muzzle = new Inst('Attachment', 'Muzzle');
  muzzle.set('CFrame', 'CFrame', tip._cf.inv().mul(new CF(0, -3.15, -0.15)));
  tip.add(muzzle);
  return m;
}

// ---------------------------------------------------------------------------------------------------------
// the outfitter's mannequin: an R6-proportioned dummy on a stand (parts named like an R6 rig so armor fits)
// ---------------------------------------------------------------------------------------------------------
function buildMannequin() {
  const m = new Inst('Model', 'Mannequin');
  const c = new Ctx({ parent: m, frame: new CF(), defaults: { anchored: true } });
  const skin = '#d8cbb0', joint = '#8a7a5e';
  const root = c.box({ name: 'HumanoidRootPart', s: [2, 2, 1], p: [0, 4.5, 0], t: 1, shadow: false });
  m.set('PrimaryPart', 'Ref', root);
  c.box({ name: 'Torso', s: [2, 2, 1], p: [0, 4.5, 0], c: skin, m: 'Wood' });
  c.box({ name: 'Head', s: [2, 1, 1], p: [0, 6.0, 0], c: skin, t: 1 });
  c.ball({ name: 'HeadBall', d: 1.15, p: [0, 6.05, 0], c: skin, m: 'Wood' });
  c.box({ name: 'Left Arm', s: [1, 2, 1], p: [-1.5, 4.5, 0], c: skin, m: 'Wood' });
  c.at([1.5, 5.5, 0], [70, 0, 0]).box({ name: 'Right Arm', s: [1, 2, 1], p: [0, -1, 0], c: skin, m: 'Wood' }); // raised, holding the launcher out
  for (const x of [-0.5, 0.5]) c.box({ name: x < 0 ? 'Left Leg' : 'Right Leg', s: [1, 2, 1], p: [x, 2.5, 0], c: skin, m: 'Wood' });
  c.cyl({ name: 'NeckJoint', axis: 'y', len: 0.3, d: 0.5, p: [0, 5.55, 0], c: joint });
  c.cyl({ name: 'StandPole', axis: 'y', len: 1.6, d: 0.3, p: [0, 0.8, 0], c: joint, m: 'Metal' });
  c.cyl({ name: 'StandBase', axis: 'y', len: 0.2, d: 2.2, p: [0, 0.1, 0], c: '#2b2d31', m: 'Metal' });
  return m;
}

function buildGear() {
  const root = new Inst('Folder', 'Gear');
  const armor = new Inst('Folder', 'Armor'); root.add(armor);
  const launchers = new Inst('Folder', 'Launchers'); root.add(launchers);
  for (const id of Object.keys(ARMOR)) armor.add(buildArmor(id));
  for (const id of Object.keys(LAUNCH)) launchers.add(buildLauncher(id));
  root.add(buildMannequin());
  return root;
}

module.exports = { buildGear, ARMOR, LAUNCH };

// standalone: node tools/gen/gear.js  (writes ReplicatedStorage/DinoExpedition/Gear + a preview)
if (require.main === module) {
  const fs = require('fs');
  const path = require('path');
  const B = require('./builder.js');
  const ROOT = path.resolve(__dirname, '../..');
  const g = buildGear();
  // one file whose root Folder is ReplicatedStorage.DinoExpedition.Gear (Armor/, Launchers/, Mannequin)
  fs.writeFileSync(path.join(ROOT, 'src/ReplicatedStorage/DinoExpedition/Gear.rbxmx'), B.toRbxmx(g));
  // preview: every armor tier dressed on a mannequin (bone offsets as on an R6 rig), launchers in a row
  const groups = [];
  const BONES = { Torso: [0, 4.5, 0], RightArm: [1.5, 4.5, 0], LeftArm: [-1.5, 4.5, 0], Head: [0, 6.05, 0], RightLeg: [0.5, 2.0, 0], LeftLeg: [-0.5, 2.0, 0] };
  let x = 0;
  for (const id of Object.keys(ARMOR)) {
    const mq = buildMannequin();
    const a = buildArmor(id);
    for (const pc of a.children) {
      const b = BONES[pc.attrs.Bone];
      B.transformTree(pc, new CF(b[0], b[1], b[2]));
      mq.add(pc);
    }
    B.transformTree(mq, new CF(x, 0, 0));
    groups.push({ name: 'Armor_' + id, parts: B.previewParts(mq) });
    x += 5;
  }
  x = 0;
  const row = [];
  for (const id of Object.keys(LAUNCH)) {
    const l = buildLauncher(id);
    B.transformTree(l, new CF(x, 4, 0).mul(CF.deg(0, 0, 90)));
    row.push(...B.previewParts(l));
    x += 2.5;
  }
  groups.push({ name: 'Launchers', parts: row });
  fs.writeFileSync(path.join(ROOT, 'tools/preview/out/gear.json'), JSON.stringify({ groups }));
  console.log('gear written');
}
