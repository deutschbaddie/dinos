// DAILY SPIN WHEEL (2026-10-14): the prize wheel on Base Camp's north lawn, beside the walk to the Time Gate.
// A chunky carnival wheel on fossil-bone A-frame legs, a ring of amber bulbs, a fossil T. rex skull on top whose
// amber tooth is the pointer, and an amber hub with a bug caught in it. Its eight slices match the spin UI
// (src/ReplicatedStorage/DinoExpedition/Game/SpinWheel.luau Segments: same order, clockwise from the top, and colours).
//
// What the client drives (Game/SpinView.luau):
//   Rotor            Model, PrimaryPart "Axle": turned about its local Z (the wheel's normal) when anyone spins
//   Flapper          Model, PrimaryPart "FlapperHinge": the tooth pointer, kicked by every peg that passes
//   Bulb (tag SpinBulb, attribute Seq)   the amber marquee ring (a slow chase while you have a spin ready)
//   SpinTag          BillboardGui (Title, Status) over the skull
//   SpinPrompt       ProximityPrompt, CampAction "Spin" (opens the spin UI)
// Wheel frame: origin on the ground under the wheel, the wheel faces local -Z. A viewer in front sees local -X on
// their right, so a slice at angle a (clockwise from the top, as seen from the front) sits at (-sin a, cos a).
const { Inst, CF, styledText } = require('./builder.js');
const E = require('./env.js');
const { PAL } = E;

// clockwise from the top: the same order as SpinWheel.luau
const SLICES = [
  { id: 'CoinsS', c: '#ffd447', token: 'coins1' },
  { id: 'Power', c: '#2fcdb4', token: 'bolt' },
  { id: 'CoinsM', c: '#ff9633', token: 'coins2' },
  { id: 'EraEgg', c: '#a8ed48', token: 'egg' },
  { id: 'Jackpot', c: '#ff5252', token: 'crown' },
  { id: 'Luck', c: '#ad66ff', token: 'clover' },
  { id: 'CoinsL', c: '#ffb02e', token: 'coins3' },
  { id: 'RareEgg', c: '#48a8ff', token: 'rareEgg' },
];
const R = 6.4; // wheel radius
const HUB_Y = 10.2; // axle height
const BONE = ['#efe2c4', '#d4c49d'];
const AMBER = '#ffb02e', AMBER_HI = '#ffd27a', GOLD = '#f2b632', GOLD_LO = '#c98a1a', INK = '#2b2d31';

const rad = (d) => (d * Math.PI) / 180;
const onWheel = (a, r) => [-Math.sin(rad(a)) * r, HUB_Y + Math.cos(rad(a)) * r];

function marker(ctx, name, p, o = {}) {
  const m = ctx.box({ name, s: o.s || [0.4, 0.4, 0.4], p, t: 1, shadow: false, c: '#ffffff' });
  m.set('CanQuery', 'bool', false);
  return m;
}

// one slice: an isosceles triangle (two right-angle wedges) from the hub out to the rim chord
function slice(ctx, a, color) {
  const half = 22.5;
  const k = 1.03; // a touch past the chord: the rim covers the rest, no dark sliver shows at a slice's middle
  const h = R * Math.cos(rad(half)) * k, b = R * Math.sin(rad(half)) * k;
  const ur = [-Math.sin(rad(a)), Math.cos(rad(a)), 0]; // radial, outward
  const t = [-Math.cos(rad(a)), -Math.sin(rad(a)), 0]; // tangent (toward the viewer's clockwise side)
  const M = [ur[0] * h, HUB_Y + ur[1] * h, -0.25];
  for (const s of [1, -1]) {
    const ts = t.map((v) => v * s);
    const centre = [M[0] - ur[0] * h / 2 + ts[0] * b / 2, M[1] - ur[1] * h / 2 + ts[1] * b / 2, M[2]];
    const right = [ts[1] * ur[2] - ts[2] * ur[1], ts[2] * ur[0] - ts[0] * ur[2], ts[0] * ur[1] - ts[1] * ur[0]];
    ctx._add(CF.fromAxes(centre, right, ts), { cls: 'WedgePart', name: 'Slice', s: [0.5, b, h], c: color, m: 'SmoothPlastic' });
  }
}

// the prize on each slice, small and chunky, standing proud of the face (ctx: radial up, facing front)
function token(ctx, kind) {
  const coin = (x, y, z = 0) => {
    ctx.cyl({ name: 'TokenCoin', axis: 'z', len: 0.32, d: 1.5, p: [x, y, -0.2 + z], c: '#ffd447', m: 'Metal' });
    ctx.cyl({ name: 'TokenCoinFace', axis: 'z', len: 0.34, d: 0.95, p: [x, y, -0.21 + z], c: '#ffe98a', m: 'Metal' });
    ctx.box({ name: 'TokenCoinMark', s: [0.22, 0.6, 0.36], p: [x, y, -0.22 + z], c: GOLD_LO });
  };
  if (kind === 'coins1') coin(0, 0);
  else if (kind === 'coins2') { coin(-0.5, -0.25); coin(0.5, 0.3, -0.12); }
  else if (kind === 'coins3') { coin(-0.62, -0.42); coin(0.62, -0.42, -0.06); coin(0, 0.5, -0.12); }
  else if (kind === 'bolt') {
    ctx.box({ name: 'TokenBolt', s: [0.55, 1.15, 0.36], p: [0.22, 0.5, -0.2], r: [0, 0, -24], c: '#7df9ff', m: 'Neon' });
    ctx.box({ name: 'TokenBolt', s: [1.1, 0.34, 0.36], p: [0, 0, -0.2], c: '#7df9ff', m: 'Neon' });
    ctx.box({ name: 'TokenBolt', s: [0.55, 1.15, 0.36], p: [-0.22, -0.5, -0.2], r: [0, 0, -24], c: '#7df9ff', m: 'Neon' });
  } else if (kind === 'egg' || kind === 'rareEgg') {
    const shell = kind === 'egg' ? '#fff1d6' : '#8cccff';
    ctx.ell({ name: 'TokenEgg', s: [1.3, 1.7, 0.7], p: [0, 0.05, -0.25], c: shell });
    const spot = kind === 'egg' ? '#6fb322' : '#ffffff';
    for (const [x, y, d] of [[-0.3, 0.35, 0.34], [0.32, -0.05, 0.28], [-0.1, -0.45, 0.24]]) ctx.ball({ name: 'TokenSpot', d, p: [x, y, -0.52], c: spot });
    if (kind === 'rareEgg') {
      ctx.box({ name: 'TokenSparkle', s: [0.4, 0.4, 0.2], p: [0.75, 0.85, -0.45], r: [0, 0, 45], c: '#ffffff', m: 'Neon' });
      ctx.box({ name: 'TokenSparkle', s: [0.25, 0.25, 0.2], p: [-0.8, 0.7, -0.45], r: [0, 0, 45], c: '#ffffff', m: 'Neon' });
    }
  } else if (kind === 'clover') {
    for (const [x, y] of [[-0.36, 0.36], [0.36, 0.36], [-0.36, -0.2], [0.36, -0.2]]) ctx.ball({ name: 'TokenLeaf', d: 0.8, p: [x, y + 0.1, -0.3], c: '#5fd84f' });
    ctx.box({ name: 'TokenStem', s: [0.18, 0.75, 0.25], p: [0.12, -0.62, -0.28], r: [0, 0, -18], c: '#3f9a3a' });
  } else if (kind === 'crown') {
    ctx.box({ name: 'TokenCrown', s: [1.7, 0.55, 0.36], p: [0, -0.35, -0.22], c: '#ffd447', m: 'Metal' });
    for (const x of [-0.65, 0, 0.65]) {
      ctx.box({ name: 'TokenCrownTip', s: [0.38, 0.6, 0.36], p: [x, 0.18, -0.22], c: '#ffd447', m: 'Metal' });
      ctx.box({ name: 'TokenCrownTip', s: [0.3, 0.3, 0.36], p: [x, 0.55, -0.22], r: [0, 0, 45], c: '#ffd447', m: 'Metal' });
    }
    ctx.box({ name: 'TokenGem', s: [0.34, 0.34, 0.3], p: [0, -0.35, -0.42], r: [0, 0, 45], c: '#ff3b5c', m: 'Neon' });
  }
}

// a fossil bone between two points: vertebra blocks with knuckled ends
function bone(ctx, a, b, w) {
  const n = 6;
  for (let i = 0; i < n; i++) {
    const t0 = i / n, t1 = (i + 1) / n;
    const p0 = a.map((v, k) => v + (b[k] - v) * t0), p1 = a.map((v, k) => v + (b[k] - v) * t1);
    const big = i % 2 === 0;
    ctx.beam(p0, p1, big ? w : w * 0.72, big ? w : w * 0.72, { name: 'BoneLeg', c: BONE[i % 2], studs: big ? 'top' : undefined, collide: true });
  }
  ctx.ball({ name: 'BoneKnuckle', d: w * 1.35, p: a, c: BONE[0], collide: true });
}

function buildSpinWheel(H, p, yaw) {
  const g = H.group('SpinWheel');
  g.parent.attr('Spin', true);
  const c = g.at(p, [0, yaw, 0]);

  // ---- the stone base, a front step, amber crystals growing from the rim
  c.cyl({ name: 'SpinBase', axis: 'y', len: 1.0, d: 17, p: [0, 0.5, 0], c: '#8a8478', m: 'Slate', collide: true });
  c.cyl({ name: 'SpinBaseTop', axis: 'y', len: 0.4, d: 15.6, p: [0, 1.2, 0], c: '#a89c82', m: 'Slate', collide: true });
  c.cyl({ name: 'SpinBaseTrim', axis: 'y', len: 0.14, d: 16.1, p: [0, 1.06, 0], c: AMBER, m: 'Metal', shadow: false });
  c.box({ name: 'Steps', s: [9, 0.5, 2.6], p: [0, 0.25, -9.2], c: '#8a8478', m: 'Slate', studs: 'top', collide: true });
  for (const a of [70, 110, 150, 210, 250, 290]) {
    const x = -Math.sin(rad(a)) * 7.3, z = -Math.cos(rad(a)) * 7.3;
    const cr = c.at([x, 1.3, z], [0, a * 3.1, 0]);
    cr.box({ name: 'AmberCrystal', s: [0.9, 2.2, 0.9], p: [0, 1.0, 0], r: [12, 0, -8], c: AMBER, m: 'Glass', t: 0.12, collide: true });
    cr.box({ name: 'AmberCrystal', s: [0.7, 1.5, 0.7], p: [0.6, 0.6, 0.3], r: [-10, 20, 22], c: AMBER_HI, m: 'Glass', t: 0.15 });
    cr.box({ name: 'AmberCrystal', s: [0.55, 1.1, 0.55], p: [-0.5, 0.45, -0.3], r: [8, -15, -26], c: '#ff9a1f', m: 'Glass', t: 0.15 });
    cr.box({ name: 'AmberCore', s: [0.35, 1.3, 0.35], p: [0, 0.9, 0], r: [12, 0, -8], c: '#ffcf6a', m: 'Neon', shadow: false });
  }
  // a little pile of fossil bones by the step (the dig that found the wheel's amber)
  const pile = c.at([5.6, 1.4, -4.4], [0, -25, 0]);
  pile.box({ name: 'FossilBone', s: [2.4, 0.5, 0.5], p: [0, 0.25, 0], c: BONE[0] });
  pile.ball({ name: 'FossilBoneEnd', d: 0.8, p: [1.25, 0.3, 0], c: BONE[1] });
  pile.ball({ name: 'FossilBoneEnd', d: 0.8, p: [-1.25, 0.3, 0], c: BONE[1] });
  pile.box({ name: 'FossilBone', s: [1.8, 0.4, 0.4], p: [0.2, 0.62, 0.3], r: [0, 40, 0], c: BONE[1] });

  // ---- fossil-bone A-frame legs behind the wheel, the axle, a post under the ring
  for (const s of [1, -1]) bone(c, [s * 5.4, 1.4, 2.8], [s * 0.9, HUB_Y - 0.4, 1.7], 1.3);
  c.box({ name: 'LegBrace', s: [8.4, 0.7, 0.7], p: [0, 4.6, 2.35], c: '#7a4f2a', m: 'WoodPlanks', collide: true });
  c.cyl({ name: 'AxleShaft', axis: 'z', len: 2.4, d: 1.3, p: [0, HUB_Y, 1.3], c: '#3a3d42', m: 'Metal' });
  c.box({ name: 'AxleBlock', s: [2.6, 2.6, 1.2], p: [0, HUB_Y, 2.2], c: INK, m: 'Metal', studs: 'all' });

  // ---- the static outer ring with the marquee bulbs (the rotor turns inside it)
  const RING = R + 1.25;
  const N_RING = 28;
  for (let k = 0; k < N_RING; k++) {
    const a = (k / N_RING) * 360;
    const [x, y] = onWheel(a, RING);
    c.box({ name: 'FrameRing', s: [(2 * Math.PI * RING) / N_RING + 0.06, 1.0, 1.3], p: [x, y, 0.45], r: [0, 0, a], c: k % 2 ? '#7a4f2a' : '#8a5a33', studs: 'top', collide: true });
  }
  for (let k = 0; k < 16; k++) {
    const a = (k / 16) * 360 + 360 / 32;
    const [x, y] = onWheel(a, RING);
    const bulb = c.ball({ name: 'Bulb', d: 0.75, p: [x, y, -0.35], c: k % 2 ? AMBER_HI : AMBER, m: 'Neon', shadow: false });
    bulb.tag('SpinBulb').attr('Seq', k);
    c.cyl({ name: 'BulbSocket', axis: 'z', len: 0.3, d: 0.95, p: [x, y, -0.12], c: INK, m: 'Metal' });
  }
  c.box({ name: 'FramePost', s: [1.6, HUB_Y - RING - 0.4 - 1.3, 1.3], p: [0, 1.4 + (HUB_Y - RING - 0.4 - 1.4) / 2, 0.45], c: '#7a4f2a', m: 'WoodPlanks', collide: true });
  for (const s of [1, -1]) {
    const [x, y] = onWheel(s * 128, RING);
    c.beam([x, y, 0.7], [s * 3.9, 3.5, 2.5], 0.6, 0.6, { name: 'RingStrut', c: '#5e3f22' });
  }

  // ---- the rotor: back plate, eight slices, the gold rim with its pegs, dividers, prizes, the amber hub
  const rotor = c.group('Rotor');
  const axle = rotor.box({ name: 'Axle', s: [0.4, 0.4, 0.4], p: [0, HUB_Y, 0], t: 1, shadow: false });
  axle.set('CanQuery', 'bool', false);
  rotor.parent.set('PrimaryPart', 'Ref', axle);
  rotor.cyl({ name: 'BackPlate', axis: 'z', len: 0.5, d: 2 * R + 0.6, p: [0, HUB_Y, 0.25], c: INK, collide: true });
  SLICES.forEach((sl, i) => slice(rotor, i * 45, sl.c));
  const N_RIM = 32;
  for (let k = 0; k < N_RIM; k++) {
    const a = (k / N_RIM) * 360;
    const [x, y] = onWheel(a, R + 0.12);
    rotor.box({ name: 'Rim', s: [(2 * Math.PI * (R + 0.12)) / N_RIM + 0.05, 1.05, 0.9], p: [x, y, -0.2], r: [0, 0, a], c: k % 2 ? GOLD : GOLD_LO, m: 'Metal' });
  }
  for (let k = 0; k < 8; k++) {
    const a = k * 45 + 22.5;
    const [x0, y0] = onWheel(a, 1.75), [x1, y1] = onWheel(a, R - 0.42);
    rotor.beam([x0, y0, -0.53], [x1, y1, -0.53], 0.16, 0.06, { name: 'Divider', c: '#3a2614', shadow: false });
    const [px, py] = onWheel(a, R + 0.12);
    rotor.cyl({ name: 'Peg', axis: 'z', len: 0.9, d: 0.5, p: [px, py, -0.95], c: '#fff1c4', m: 'Metal' });
  }
  SLICES.forEach((sl, i) => {
    const a = i * 45;
    const [x, y] = onWheel(a, R * 0.6);
    token(rotor.at([x, y, -0.5], [0, 0, a]), sl.token);
  });
  rotor.cyl({ name: 'HubRing', axis: 'z', len: 0.6, d: 3.8, p: [0, HUB_Y, -0.55], c: GOLD, m: 'Metal' });
  for (let k = 0; k < 8; k++) {
    const [x, y] = onWheel(k * 45 + 22.5, 1.55);
    rotor.box({ name: 'HubRivet', s: [0.3, 0.3, 0.2], p: [x, y, -0.9], r: [0, 0, 45], c: GOLD_LO, m: 'Metal' });
  }
  rotor.cyl({ name: 'HubAmber', axis: 'z', len: 0.5, d: 2.7, p: [0, HUB_Y, -0.95], c: AMBER, m: 'Glass', t: 0.12 });
  const core = rotor.cyl({ name: 'HubCore', axis: 'z', len: 0.3, d: 1.5, p: [0, HUB_Y, -0.9], c: '#ffcf6a', m: 'Neon', shadow: false });
  E.pointLight(core, [1, 0.72, 0.3], 14, 0.8);
  // the bug in the amber (a little mosquito, wings out)
  const bug = rotor.at([0, HUB_Y, -1.12], [0, 0, 20]);
  bug.box({ name: 'AmberBug', s: [0.55, 0.16, 0.1], c: '#3a2614', shadow: false });
  bug.box({ name: 'AmberBugWing', s: [0.32, 0.12, 0.06], p: [0.05, 0.14, 0], r: [0, 0, 30], c: '#6b4a2b', shadow: false });
  bug.box({ name: 'AmberBugWing', s: [0.32, 0.12, 0.06], p: [0.05, -0.14, 0], r: [0, 0, -30], c: '#6b4a2b', shadow: false });

  // ---- the fossil T. rex skull on top, its amber tooth hanging over the rim: the pointer
  const top = HUB_Y + RING + 0.5;
  const sk = c.at([0, top, 0.2]);
  sk.box({ name: 'SkullCranium', s: [3.4, 2.4, 3.0], p: [0, 1.7, 0.6], c: BONE[0], studs: 'top' });
  sk.box({ name: 'SkullBrow', s: [3.6, 0.6, 1.2], p: [0, 2.8, -0.4], c: BONE[1] });
  sk.box({ name: 'SkullSnout', s: [2.4, 1.5, 2.6], p: [0, 1.25, -1.9], c: BONE[0] });
  sk.box({ name: 'SkullNose', s: [2.0, 0.5, 0.9], p: [0, 2.05, -2.6], c: BONE[1] });
  sk.box({ name: 'SkullJaw', s: [2.2, 0.6, 2.4], p: [0, 0.2, -1.6], r: [-10, 0, 0], c: BONE[1] });
  for (const s of [1, -1]) {
    sk.box({ name: 'SkullEye', s: [0.25, 0.85, 0.85], p: [s * 1.62, 1.8, -0.1], c: '#2a1d12' });
    sk.box({ name: 'SkullEyeGlow', s: [0.12, 0.3, 0.3], p: [s * 1.72, 1.75, -0.1], c: AMBER, m: 'Neon', shadow: false });
    sk.box({ name: 'SkullCheek', s: [0.5, 1.0, 1.4], p: [s * 1.5, 0.9, 0.9], c: BONE[1] });
    for (let i = 0; i < 3; i++) sk.wedgeF({ name: 'SkullTooth', s: [0.22, 0.45, 0.3], p: [s * (0.95 - i * 0.05), 0.35, -2.9 + i * 0.6], face: 'front', flip: true, c: '#fffaf0' });
  }
  sk.box({ name: 'SkullStand', s: [2.2, 0.6, 2.0], p: [0, 0.0, 0.8], c: '#7a4f2a', m: 'WoodPlanks' });
  // the pointer: an amber tooth on an arm, hinged under the snout (the client swings it on each peg)
  const fl = c.group('Flapper');
  const hingeY = HUB_Y + R + 1.85;
  const hinge = fl.box({ name: 'FlapperHinge', s: [0.5, 0.5, 0.6], p: [0, hingeY, -1.05], c: INK, m: 'Metal' });
  fl.parent.set('PrimaryPart', 'Ref', hinge);
  fl.box({ name: 'FlapperArm', s: [0.35, 1.1, 0.35], p: [0, hingeY - 0.6, -1.05], c: GOLD, m: 'Metal' });
  fl.box({ name: 'FlapperTooth', s: [0.9, 0.9, 0.45], p: [0, hingeY - 1.25, -1.05], r: [0, 0, 45], c: AMBER, m: 'Neon', shadow: false });
  fl.wedgeF({ name: 'FlapperTip', s: [0.6, 0.55, 0.45], p: [0, hingeY - 1.75, -1.05], face: 'front', flip: true, r: [0, 90, 0], c: AMBER_HI, m: 'Glass', t: 0.05 });

  // ---- the plaque, the floating title + status, the prompt
  const plq = c.at([0, 1.4, -6.6], [-16, 0, 0]);
  const plaque = plq.box({ name: 'SpinPlaque', s: [7.4, 1.6, 0.5], p: [0, 0.8, 0], c: '#2a2c31' });
  plq.box({ name: 'SpinPlaqueFrame', s: [8.0, 2.1, 0.35], p: [0, 0.8, 0.2], c: AMBER, m: 'Metal', studs: 'top' });
  const sg = new Inst('SurfaceGui', 'Label');
  sg.set('Face', 'token', 5).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', 34).set('LightInfluence', 'float', 0);
  sg.add(styledText('SPIN & WIN', { name: 'Text', size: [0.92, 0, 0.72, 0], pos: [0.04, 0, 0.14, 0], color: '#fff4d6', color2: '#ffb02e', strokeT: 3, shadow: 4, align: 'Center' }));
  plaque.add(sg);
  const tagHost = marker(c, 'SpinTagHost', [0, top + 5.2, 0.2]);
  const bb = new Inst('BillboardGui', 'SpinTag');
  bb.set('Size', 'UDim2', [0, 300, 0, 84]).set('StudsOffset', 'Vector3', [0, 0, 0]).set('MaxDistance', 'float', 140).set('LightInfluence', 'float', 0);
  bb.add(styledText('DAILY SPIN', { name: 'Title', size: [1, 0, 0.55, 0], pos: [0, 0, 0, 0], color: '#ffe9a0', color2: '#ffb02e', strokeT: 3, shadow: 3, align: 'Center', family: 'FredokaOne' }));
  bb.add(styledText('', { name: 'Status', size: [1, 0, 0.36, 0], pos: [0, 0, 0.6, 0], color: '#ffffff', strokeT: 2, shadow: 2, align: 'Center', family: 'FredokaOne' }));
  tagHost.add(bb);
  const host = marker(c, 'SpinPromptHost', [0, 3.2, -7.4]);
  const pr = new Inst('ProximityPrompt', 'SpinPrompt');
  pr.set('ActionText', 'string', 'Spin').set('ObjectText', 'string', 'Daily Spin').set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 13).set('HoldDuration', 'float', 0).set('RequiresLineOfSight', 'bool', false);
  pr.attr('CampAction', 'Spin').attr('PromptColor', 'Orange');
  host.add(pr);

  // ---- a little planting round the base
  for (const [x, z, s] of [[-6.8, -3.6, 31], [6.9, 2.6, 32], [-6.2, 3.8, 33]]) E.fern(c, [x, 1.4, z], 0.75, 9100 + s);
  E.flowers(c, [-4.6, 1.4, -5.6], 9140, { n: 5, spread: 2.2 });
  E.flowers(c, [3.4, 1.4, -6.4], 9141, { n: 4, spread: 2 });
  return g;
}

module.exports = { buildSpinWheel, SLICES, R, HUB_Y };
