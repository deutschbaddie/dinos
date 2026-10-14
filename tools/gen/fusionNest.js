// THE FUSION NEST (2026-10-14): the Egg Keeper's egg-fusing machine beside the Hatch Stage in Base Camp.
// Three egg cradles (bone claws round an amber ring) feed glass tubes into a central amber pod held in a fossil
// ribcage; the new egg pops out of the pod into the middle cradle (client FusionView.luau plays the cutscene and
// opens the EGG FUSION window from its prompt). Chunky studded fossil stone + amber + a little neon (calm.js keeps the
// glow of this one model, like the trainers).
// Named parts the game uses (model-local, origin = floor centre, the front faces -Z):
//   FusionOrigin            the machine's frame (the cutscene's shots are relative to it)
//   FusionPod               the pod's centre (the eggs fly in here; Fusion.luau's range check)
//   FusionCradle1..3        where an egg's bottom sits in each cradle (left, middle, right)
//   FusionStand             where you stand to watch, facing the pod
//   FusionCore              the glowing heart in the pod; FusionGlow* parts light up when you have a trio to fuse
//   FusionPrompt            the ProximityPrompt (CampAction "Fusion")
const { Inst, styledText } = require('./builder.js');
const E = require('./env.js');

const AMBER = '#ffb02e', AMBER_LO = '#d9781f', AMBER_HI = '#ffd27a';
const BONE = '#e6dccb', BONE_LO = '#cfc3a4', BONE_HI = '#f2ece0';
const STONE = '#8a8274', STONE_LO = '#6f685c', IRON = '#5d6168', IRON_LO = '#4a4f57', BRONZE = '#c87533', STRAW = '#e2b85a';
const CRADLES = [[-2.35, -1.3], [0, -2.0], [2.35, -1.3]];
const POD = [0, 1.5]; // x, z
const POD_Y = 3.7;

function marker(c, name, p, yaw = 0) {
  const m = c.box({ name, s: [1, 1, 1], p, r: [0, yaw, 0], t: 1, shadow: false, c: '#ffffff' });
  m.set('CanQuery', 'bool', false);
  return m;
}

// a spiral ammonite fossil pressed into a face (axis z, facing -Z)
function ammonite(c, p, d) {
  const rings = [[1, BONE_LO], [0.74, BONE], [0.5, BONE_LO], [0.28, BONE_HI]];
  rings.forEach(([k, col], i) => c.cyl({ name: 'Ammonite', axis: 'z', len: 0.2 + i * 0.05, d: d * k, p: [p[0] + (1 - k) * d * 0.12, p[1], p[2] - i * 0.04], c: col, m: 'Slate', shadow: false }));
}

// one cradle: an iron post, a dark bowl ringed with amber, four bone claws curling up round the egg
function cradle(c, i, x, z) {
  const k = c.at([x, 0, z]);
  k.cyl({ name: 'CradlePost', axis: 'y', len: 1.3, d: 1.2, p: [0, 1.65, 0], c: STONE_LO, m: 'Slate', collide: true });
  k.cyl({ name: 'CradleCollar', axis: 'y', len: 0.3, d: 1.6, p: [0, 1.15, 0], c: AMBER_LO, m: 'Metal' });
  k.cyl({ name: 'CradleBowl', axis: 'y', len: 0.35, d: 2.0, p: [0, 2.42, 0], c: BRONZE, m: 'Metal', collide: true });
  k.cyl({ name: 'CradleStraw', axis: 'y', len: 0.2, d: 1.6, p: [0, 2.56, 0], c: STRAW, m: 'Fabric', shadow: false });
  const ring = k.cyl({ name: 'FusionGlowRing', axis: 'y', len: 0.18, d: 2.24, p: [0, 2.5, 0], c: AMBER, m: 'Neon', t: 0.15, shadow: false });
  ring.attr('Cradle', i);
  for (let a = 0; a < 4; a++) {
    const yaw = a * 90 + 45;
    const arm = k.at([0, 2.45, 0], [0, yaw, 0]);
    arm.box({ name: 'CradleClaw', s: [0.32, 1.1, 0.32], p: [0, 0.45, -1.05], r: [-24, 0, 0], c: a % 2 ? BONE : BONE_HI, studs: 'top' });
    arm.box({ name: 'CradleClawTip', s: [0.26, 0.5, 0.26], p: [0, 1.05, -1.2], r: [22, 0, 0], c: BONE_LO });
  }
  marker(c, 'FusionCradle' + i, [x, 2.6, z]);
  // the feed tube, lying on the plinth from the cradle's foot to the pod's base: amber glass round a glowing core
  const from = [x * 0.82, 1.28, z + 0.55], to = [POD[0] + x * 0.28, 1.28, POD[1] - 1.2];
  c.tube(from, to, 0.7, { name: 'FeedTube', c: AMBER_HI, m: 'Glass', t: 0.4, shadow: false });
  c.tube(from, to, 0.32, { name: 'FusionGlowFeed', c: AMBER, m: 'Neon', t: 0.1, shadow: false }).attr('Cradle', i);
  for (const u of [0.25, 0.7]) {
    const q = from.map((v, n) => v + (to[n] - v) * u);
    c.tube([q[0], q[1], q[2]], [q[0] + (to[0] - from[0]) * 0.04, q[1], q[2] + (to[2] - from[2]) * 0.04], 0.78, { name: 'TubeClamp', c: IRON, m: 'Metal' });
  }
}

// the pod: an iron base, the amber glass ball with the core in it, a cap, and a fossil ribcage over the back half
function pod(c) {
  const [px, pz] = POD;
  const p = c.at([px, 0, pz]);
  p.cyl({ name: 'PodBase', axis: 'y', len: 1.0, d: 3.8, p: [0, 1.5, 0], c: BRONZE, m: 'Metal', collide: true });
  p.cyl({ name: 'PodBaseRim', axis: 'y', len: 0.28, d: 4.1, p: [0, 2.0, 0], c: IRON, m: 'Metal' });
  for (let k = 0; k < 8; k++) {
    const a = (k / 8) * Math.PI * 2;
    p.cyl({ name: 'PodRivet', axis: 'y', len: 0.2, d: 0.34, p: [Math.cos(a) * 1.8, 2.2, Math.sin(a) * 1.8], c: BONE_HI, m: 'Metal', shadow: false });
  }
  p.cyl({ name: 'PodCradle', axis: 'y', len: 0.4, d: 2.6, p: [0, 2.3, 0], c: IRON_LO, m: 'Metal' });
  const glass = p.ball({ name: 'FusionGlass', d: 3.3, p: [0, POD_Y, 0], c: '#ffd88a', m: 'Glass', t: 0.66, shadow: false });
  void glass;
  const core = p.ball({ name: 'FusionCore', d: 1.3, p: [0, POD_Y, 0], c: AMBER, m: 'Neon', t: 0.1, shadow: false });
  E.pointLight(core, [1, 0.72, 0.3], 12, 0.7);
  E.particles(core, 'PodMotes', { rate: 3, life: [1.2, 2], speed: [0.2, 0.6], size: [[0, 0.22], [1, 0]], color: [1, 0.78, 0.35], emission: 0.5, spread: [180, 180] });
  marker(c, 'FusionPod', [px, POD_Y, pz]);
  // the cap: an iron crown with an amber gem
  p.cyl({ name: 'PodCap', axis: 'y', len: 0.5, d: 1.9, p: [0, 5.45, 0], c: BRONZE, m: 'Metal' });
  p.cyl({ name: 'PodCapRim', axis: 'y', len: 0.2, d: 2.2, p: [0, 5.25, 0], c: IRON, m: 'Metal' });
  for (let k = 0; k < 4; k++) p.at([0, 5.6, 0], [0, k * 90 + 45, 0]).box({ name: 'PodCapFin', s: [0.3, 0.7, 0.9], p: [0, 0.25, -0.75], r: [-18, 0, 0], c: BONE, studs: 'top' });
  p.ball({ name: 'FusionGlowGem', d: 0.75, p: [0, 6.05, 0], c: AMBER, m: 'Neon', shadow: false });
  // fossil ribs arching over the back half (the front stays open so you can watch the core)
  for (const deg of [-10, 35, 90, 145, 190]) {
    const rad = (deg * Math.PI) / 180;
    const dir = [Math.cos(rad), Math.sin(rad)];
    const pts = [[2.15, 1.9], [2.3, 3.0], [2.05, 4.1], [1.45, 4.95], [0.6, 5.35]];
    for (let s = 0; s < pts.length - 1; s++) {
      const [r0, y0] = pts[s], [r1, y1] = pts[s + 1];
      p.beam([dir[0] * r0, y0, dir[1] * r0], [dir[0] * r1, y1, dir[1] * r1], 0.42, 0.42, { name: 'FossilRib', c: s % 2 ? BONE_LO : BONE, extend: 0.24 });
    }
    p.ball({ name: 'RibKnuckle', d: 0.6, p: [dir[0] * 2.3, 3.0, dir[1] * 2.3], c: BONE_HI, shadow: false });
  }
}

// a cluster of amber crystals (glassy, a lit core)
function crystals(c, p, yaw, k) {
  const g = c.at(p, [0, yaw, 0]);
  const spikes = [[0, 0, 0, 0.9, 2.4, 0], [0.55, 0, 0.3, 0.6, 1.6, 18], [-0.5, 0, 0.25, 0.55, 1.3, -20], [0.1, 0, -0.5, 0.5, 1.1, 10]];
  for (const [x, y, z, w, h, tilt] of spikes) {
    g.box({ name: 'AmberCrystal', s: [w * k, h * k, w * k], p: [x * k, y + (h * k) / 2, z * k], r: [tilt * 0.4, 45, tilt], c: AMBER, m: 'Glass', t: 0.2 });
  }
  g.box({ name: 'FusionGlowCrystal', s: [0.4 * k, 1.6 * k, 0.4 * k], p: [0, 0.85 * k, 0], r: [0, 45, 0], c: AMBER_HI, m: 'Neon', t: 0.25, shadow: false });
}

// parent: the Hatch Stage's ctx (origin on the plaza floor); p / yaw: where the machine stands in it
function buildFusionNest(parent, p, yaw) {
  const g = parent.group('FusionNest');
  g.parent.tag('FusionNest');
  const c = g.at(p, [0, yaw, 0]);
  marker(c, 'FusionOrigin', [0, 0.5, 0]);
  // the plinth: fossil stone, an amber trim band, a front step; bones and ammonites set into the front face
  c.box({ name: 'NestPlinth', s: [7.4, 1.0, 6.6], p: [0, 0.5, 0.2], c: STONE, m: 'Slate', studs: 'top', collide: true });
  c.box({ name: 'NestPlinthBand', s: [7.6, 0.3, 6.8], p: [0, 0.15, 0.2], c: AMBER_LO, studs: 'sides' });
  c.box({ name: 'NestStep', s: [4.6, 0.5, 1.3], p: [0, 0.25, -3.75], c: STONE_LO, m: 'Slate', studs: 'top', collide: true });
  for (let v = 0; v < 7; v++) c.box({ name: 'FossilVertebra', s: [0.42, 0.42, 0.2], p: [-1.5 + v * 0.5, 0.7, -3.13], r: [0, 0, 45], c: v % 2 ? BONE : BONE_LO, shadow: false });
  ammonite(c, [-2.9, 0.6, -3.12], 0.75);
  ammonite(c, [2.9, 0.6, -3.12], 0.75);
  for (const [x, z] of [[-3.5, -2.9], [3.5, -2.9], [-3.5, 3.3], [3.5, 3.3]]) c.box({ name: 'CornerStud', s: [0.8, 0.5, 0.8], p: [x, 1.2, z], c: AMBER_LO, studs: 'top' });
  CRADLES.forEach(([x, z], i) => cradle(c, i + 1, x, z));
  pod(c);
  crystals(c, [-3.0, 1.0, 2.6], 20, 0.85);
  crystals(c, [3.1, 1.0, 2.5], -35, 0.7);
  // the sign: EGG FUSION on a board between two bone posts behind the pod
  for (const x of [-2.6, 2.6]) {
    c.box({ name: 'SignBone', s: [0.6, 6.8, 0.6], p: [x, 4.4, 3.2], c: BONE, studs: 'top', collide: true });
    c.ball({ name: 'SignBoneKnob', d: 0.95, p: [x, 7.9, 3.2], c: BONE_HI });
  }
  const sign = c.box({ name: 'FusionSign', s: [5.0, 1.3, 0.3], p: [0, 7.1, 3.2], c: '#3a2a1e' });
  c.box({ name: 'FusionSignFrame', s: [5.5, 1.75, 0.24], p: [0, 7.1, 3.42], c: AMBER_LO, studs: 'sides' });
  const sg = new Inst('SurfaceGui', 'Label');
  sg.set('Face', 'token', 5).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', 40).set('LightInfluence', 'float', 0);
  sg.add(styledText('EGG FUSION', { name: 'Text', size: [0.94, 0, 0.78, 0], pos: [0.03, 0, 0.11, 0], color: '#fff4d6', color2: AMBER, strokeT: 3, shadow: 3, align: 'Center' }));
  sign.add(sg);
  // where you watch from, and the prompt (on the step)
  marker(c, 'FusionStand', [0, 0.5, -7.2], 180);
  const host = marker(c, 'FusionPromptHost', [0, 2.4, -3.4]);
  const a = new Inst('Attachment', 'PromptAttachment');
  host.add(a);
  const pr = new Inst('ProximityPrompt', 'FusionPrompt');
  pr.set('ActionText', 'string', 'Fuse eggs').set('ObjectText', 'string', 'Fusion Nest').set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', 10).set('HoldDuration', 'float', 0).set('RequiresLineOfSight', 'bool', false);
  pr.attr('CampAction', 'Fusion').attr('PromptColor', 'Orange');
  a.add(pr);
  require('./qc.js').resolveZFight(g.parent); // (coplanar faces - the plinth band, claws on bowls - nudged apart)
  return g;
}

module.exports = { buildFusionNest };
