// Paddock props, cloned into every plot's paddock by the client (PaddockLife): the Companion Machine you use to
// pick the dino that follows you round camp, and the play corner (a treat barrel and a toy crate), plus the
// throwable ball and the treat you carry. Origin = floor centre, front faces -Z (into the paddock).
const { Inst, Ctx, CF, styledText } = require('./builder.js');

function newModel(name) {
  const m = new Inst('Model', name);
  const c = new Ctx({ parent: m, frame: new CF(), defaults: { anchored: true } });
  const root = c.box({ name: 'PropRoot', s: [0.4, 0.4, 0.4], p: [0, 0.2, 0], t: 1, shadow: false });
  root.set('CanQuery', 'bool', false);
  m.set('PrimaryPart', 'Ref', root);
  return { m, c };
}

function prompt(host, name, action, object, campAction, dist = 10) {
  const pr = new Inst('ProximityPrompt', name);
  pr.set('ActionText', 'string', action).set('ObjectText', 'string', object).set('KeyboardKeyCode', 'token', 101);
  pr.set('MaxActivationDistance', 'float', dist).set('HoldDuration', 'float', 0).set('RequiresLineOfSight', 'bool', false);
  pr.set('Enabled', 'bool', false); // PaddockLife switches it on for the owner
  pr.attr('CampAction', campAction);
  host.add(pr);
  return pr;
}

function surfaceLabel(part, face, text, o = {}) {
  const FACES = { Right: 0, Top: 1, Back: 2, Left: 3, Bottom: 4, Front: 5 };
  const sg = new Inst('SurfaceGui', o.name || 'Label');
  sg.set('Face', 'token', FACES[face]).set('SizingMode', 'token', 1).set('PixelsPerStud', 'float', o.pps || 40).set('LightInfluence', 'float', 0);
  sg.add(styledText(text, Object.assign({ name: 'Text', size: [0.92, 0, 0.74, 0], pos: [0.04, 0, 0.13, 0], strokeT: 3, shadow: 3, align: 'Center' }, o)));
  part.add(sg);
  return sg;
}

// the play corner: a barrel of treats and a crate of balls
function buildTreatBarrel() {
  const { m, c } = newModel('TreatBarrel');
  c.cyl({ name: 'Barrel', axis: 'y', len: 2.8, d: 2.6, p: [0, 1.4, 0], c: '#8a6238', m: 'WoodPlanks', collide: true });
  for (const y of [0.5, 2.3]) c.cyl({ name: 'BarrelBand', axis: 'y', len: 0.25, d: 2.7, p: [0, y, 0], c: '#3a3d42', m: 'Metal' });
  c.cyl({ name: 'Greens', axis: 'y', len: 0.3, d: 2.3, p: [0, 2.85, 0], c: '#4fb043', studs: 'top' });
  for (const [x, z, r] of [[-0.5, 0.2, 20], [0.45, -0.35, -35], [0.1, 0.6, 70]]) {
    const t = c.at([x, 3.15, z], [0, r, 25]);
    t.cyl({ name: 'TreatBone', axis: 'x', len: 1.3, d: 0.22, c: '#f3ead2' });
    t.ell({ name: 'TreatMeat', s: [0.8, 0.55, 0.55], p: [0.15, 0, 0], c: '#c8452a' });
  }
  const host = c.box({ name: 'TreatPromptHost', s: [0.4, 0.4, 0.4], p: [0, 2.2, -1.6], t: 1, shadow: false });
  prompt(host, 'TreatPrompt', 'Grab Treat', 'Dino Treats', 'Treat', 9);
  return m;
}

function buildToyCrate() {
  const { m, c } = newModel('ToyCrate');
  c.box({ name: 'Crate', s: [3.2, 1.8, 2.4], p: [0, 0.9, 0], c: '#a0723f', m: 'WoodPlanks', studs: 'sides', collide: true });
  for (const x of [-1.45, 1.45]) c.box({ name: 'CrateSlat', s: [0.3, 1.86, 2.46], p: [x, 0.9, 0], c: '#6b4a2b', m: 'WoodPlanks' });
  const cols = ['#e8473a', '#ffc21f', '#3d8be8', '#7cc242', '#e85aa8'];
  [[-0.8, 0.3], [0.1, -0.4], [0.9, 0.35], [-0.2, 0.55], [0.6, -0.5]].forEach(([x, z], i) => c.ball({ name: 'ToyBall', d: 1.0, p: [x, 2.05 + (i % 2) * 0.25, z], c: cols[i], studs: undefined }));
  const host = c.box({ name: 'BallPromptHost', s: [0.4, 0.4, 0.4], p: [0, 1.8, -1.6], t: 1, shadow: false });
  prompt(host, 'BallPrompt', 'Grab Ball', 'Toy Crate', 'Ball', 9);
  return m;
}

// carried / thrown: the ball (two-tone, so you can see it spin) and a treat on the bone
function buildBall() {
  const m = new Inst('Model', 'PlayBall');
  const c = new Ctx({ parent: m, frame: new CF(), defaults: { anchored: false } });
  const core = c.ball({ name: 'Ball', d: 1.1, c: '#e8473a' });
  m.set('PrimaryPart', 'Ref', core);
  return m;
}
function buildTreat() {
  const m = new Inst('Model', 'Treat');
  const c = new Ctx({ parent: m, frame: new CF(), defaults: { anchored: true } });
  const bone = c.cyl({ name: 'TreatBone', axis: 'x', len: 1.2, d: 0.22, c: '#f3ead2' });
  c.ball({ name: 'Knob', d: 0.38, p: [-0.62, 0, 0], c: '#f3ead2' });
  c.ell({ name: 'TreatMeat', s: [0.75, 0.55, 0.55], p: [0.2, 0, 0], c: '#c8452a' });
  m.set('PrimaryPart', 'Ref', bone);
  return m;
}

// ---- the companion station. A (the Pal Pad) was picked; B and C stay here as the other two options ----
// A: "Pal Pad" - a giant toy tablet on an easel: chunky rubber bumper, the three slots on its screen, a stylus
function buildOptionTablet(name) {
  const { m, c } = newModel(name || 'CompanionTablet');
  const teal = '#2fbfa8', tealLo = '#1f8f7e', ink = '#26282d', yellow = '#ffc21f', cream = '#f3ead2';
  c.box({ name: 'Base', s: [6.4, 0.6, 3.6], p: [0, 0.3, 0.4], c: '#7a746a', m: 'Slate', studs: 'top', collide: true });
  // easel legs and a sandbag
  c.sym((s) => {
    s.beam([2.0, 0.6, 1.6], [1.6, 6.2, 0.6], 0.5, 0.5, { name: 'EaselLeg', c: '#8a6238', m: 'WoodPlanks', collide: true });
    s.box({ name: 'Foot', s: [1.0, 0.4, 1.2], p: [2.0, 0.8, 1.6], c: ink });
  });
  c.beam([0, 0.6, 2.2], [0, 5.6, 0.9], 0.45, 0.45, { name: 'EaselBack', c: '#7d5733', m: 'WoodPlanks' });
  const t = c.at([0, 5.0, 0.2], [-12, 0, 0]);
  t.box({ name: 'Bumper', s: [7.2, 5.0, 0.9], c: teal, studs: 'sides', collide: true });
  t.box({ name: 'BumperLip', s: [7.4, 0.5, 1.0], p: [0, 2.35, 0], c: tealLo });
  t.box({ name: 'BumperLip', s: [7.4, 0.5, 1.0], p: [0, -2.35, 0], c: tealLo });
  t.box({ name: 'Bezel', s: [6.4, 4.2, 0.2], p: [0, 0, -0.5], c: ink });
  const screen = t.box({ name: 'Screen', s: [6.0, 3.8, 0.1], p: [0, 0, -0.62], c: '#123f3a', m: 'Neon', shadow: false });
  surfaceLabel(screen, 'Front', 'MY COMPANIONS', { name: 'ScreenTitle', pps: 30, size: [0.9, 0, 0.2, 0], pos: [0.05, 0, 0.04, 0], color: '#eafff8', color2: '#5ff2d8' });
  // the three slot tiles on the screen (lit / empty / locked are coloured by the client)
  [-2.0, 0, 2.0].forEach((x, i) => {
    const tile = t.box({ name: 'SlotTile' + (i + 1), s: [1.7, 2.3, 0.08], p: [x, -0.35, -0.7], c: i === 0 ? '#5ff2d8' : (i === 1 ? '#2a6b63' : '#3a3d42'), m: 'Neon', shadow: false });
    surfaceLabel(tile, 'Front', '', { name: 'TileText', pps: 40, size: [0.92, 0, 0.3, 0], pos: [0.04, 0, 0.66, 0], color: '#ffffff', color2: '#d8fff6' });
    t.box({ name: 'SlotFrame', s: [1.9, 2.5, 0.06], p: [x, -0.35, -0.66], c: cream });
  });
  t.cyl({ name: 'HomeButton', axis: 'z', len: 0.2, d: 0.5, p: [0, -2.1, -0.5], c: yellow });
  t.cyl({ name: 'Camera', axis: 'z', len: 0.15, d: 0.3, p: [0, 2.15, -0.5], c: ink });
  // a stylus clipped to the side
  t.cyl({ name: 'Stylus', axis: 'y', len: 3.2, d: 0.28, p: [3.85, 0, -0.1], c: yellow });
  t.cyl({ name: 'StylusTip', axis: 'y', len: 0.4, d: 0.2, p: [3.85, -1.75, -0.1], c: ink });
  const host = c.box({ name: 'MachinePromptHost', s: [0.4, 0.4, 0.4], p: [0, 2.6, -2.2], t: 1, shadow: false });
  prompt(host, 'CompanionPrompt', 'Open', 'Companions', 'Companion', 11);
  return m;
}
// B: "Companion Den" - a little wooden dino house with three arched doors (a door per slot; locked ones padlocked)
// and a tablet screen beside them; the roof has a dino-head weathervane
function buildOptionDen() {
  const { m, c } = newModel('CompanionDen');
  const wood = '#a0723f', woodLo = '#7d5733', roof = '#e8473a', roofLo = '#b8352b', ink = '#26282d', yellow = '#ffc21f';
  c.box({ name: 'Porch', s: [9.6, 0.6, 5.2], p: [0, 0.3, 0.2], c: '#8a8478', m: 'Slate', studs: 'top', collide: true });
  c.box({ name: 'Walls', s: [8.8, 4.6, 3.8], p: [0, 2.9, 0.6], c: wood, m: 'WoodPlanks', studs: 'sides', collide: true });
  for (const y of [1.2, 4.9]) c.box({ name: 'Beam', s: [9.0, 0.4, 4.0], p: [0, y, 0.6], c: woodLo, m: 'WoodPlanks' });
  // roof: two slopes and a ridge
  c.box({ name: 'RoofEaves', s: [9.8, 0.4, 5.0], p: [0, 5.3, 0.6], c: roofLo });
  c.wedgeF({ name: 'Roof', s: [9.6, 2.0, 2.4], p: [0, 6.5, -0.6], face: 'front', c: roof, studs: 'top' });
  c.wedgeF({ name: 'Roof', s: [9.6, 2.0, 2.4], p: [0, 6.5, 1.8], face: 'back', c: roof, studs: 'top' });
  c.box({ name: 'Ridge', s: [10.0, 0.5, 0.7], p: [0, 7.55, 0.6], c: roofLo });
  // three arched doors
  [-2.9, 0, 2.9].forEach((x, i) => {
    c.box({ name: 'DoorFrame', s: [2.3, 3.3, 0.3], p: [x, 2.25, -1.35], c: woodLo, m: 'WoodPlanks' });
    c.cyl({ name: 'DoorArch', axis: 'z', len: 0.3, d: 2.3, p: [x, 3.9, -1.35], c: woodLo, m: 'WoodPlanks' });
    c.box({ name: 'Door' + (i + 1), s: [1.8, 2.9, 0.2], p: [x, 2.05, -1.5], c: i === 0 ? '#2fbfa8' : '#5e3f22', m: i === 0 ? 'SmoothPlastic' : 'WoodPlanks' });
    c.cyl({ name: 'DoorTop', axis: 'z', len: 0.2, d: 1.8, p: [x, 3.5, -1.5], c: i === 0 ? '#2fbfa8' : '#5e3f22' });
    if (i > 0) {
      c.box({ name: 'Padlock', s: [0.6, 0.55, 0.25], p: [x, 2.1, -1.68], c: yellow, m: 'Metal' });
      c.cyl({ name: 'Shackle', axis: 'z', len: 0.12, d: 0.5, p: [x, 2.5, -1.68], c: '#9aa1a8', m: 'Metal' });
    }
    c.box({ name: 'NamePlate', s: [1.6, 0.4, 0.1], p: [x, 4.4, -1.55], c: '#f3ead2' });
  });
  // the tablet on a post at the front corner
  c.cyl({ name: 'TabletPost', axis: 'y', len: 2.6, d: 0.35, p: [4.6, 1.9, -2.0], c: ink });
  const t = c.at([4.6, 3.6, -2.0], [-25, -20, 0]);
  t.box({ name: 'TabletCase', s: [2.6, 1.9, 0.3], c: '#2fbfa8' });
  t.box({ name: 'Screen', s: [2.2, 1.5, 0.06], p: [0, 0, -0.16], c: '#123f3a', m: 'Neon', shadow: false });
  // weathervane
  c.cyl({ name: 'VanePole', axis: 'y', len: 2.0, d: 0.2, p: [0, 8.4, 0.6], c: ink });
  c.box({ name: 'VaneDino', s: [0.25, 0.8, 1.6], p: [0, 9.3, 0.6], c: yellow, m: 'Metal' });
  c.box({ name: 'VaneHead', s: [0.25, 0.6, 0.6], p: [0, 9.6, -0.4], c: yellow, m: 'Metal' });
  const host = c.box({ name: 'MachinePromptHost', s: [0.4, 0.4, 0.4], p: [0, 2.6, -2.8], t: 1, shadow: false });
  prompt(host, 'CompanionPrompt', 'Open', 'Companion Den', 'Companion', 11);
  return m;
}
// C: "Holo Pods" - three glass capsules on a tech base, each showing a hologram of the companion in that slot (a
// padlock in a locked one), with a tablet terminal on a stalk in front
function buildOptionPods() {
  const { m, c } = newModel('CompanionPods');
  const teal = '#2fbfa8', ink = '#26282d', metal = '#9aa1a8', yellow = '#ffc21f';
  c.box({ name: 'Base', s: [10.0, 0.8, 4.4], p: [0, 0.4, 0.6], c: '#3a3d42', m: 'DiamondPlate', collide: true });
  c.box({ name: 'BaseTrim', s: [10.2, 0.25, 4.6], p: [0, 0.9, 0.6], c: teal });
  [-3.2, 0, 3.2].forEach((x, i) => {
    c.cyl({ name: 'PodBase', axis: 'y', len: 0.8, d: 2.8, p: [x, 1.4, 0.6], c: metal, m: 'Metal', collide: true });
    c.cyl({ name: 'PodPad', axis: 'y', len: 0.1, d: 2.2, p: [x, 1.85, 0.6], c: i === 2 ? '#3a3d42' : '#5ff2d8', m: 'Neon', shadow: false });
    c.cyl({ name: 'PodGlass', axis: 'y', len: 3.6, d: 2.6, p: [x, 3.7, 0.6], c: '#bff6ff', m: 'Glass', t: 0.65, shadow: false });
    c.ball({ name: 'PodDome', d: 2.6, p: [x, 5.5, 0.6], c: '#bff6ff', m: 'Glass', t: 0.65, shadow: false });
    c.cyl({ name: 'PodRing', axis: 'y', len: 0.3, d: 2.8, p: [x, 5.5, 0.6], c: metal, m: 'Metal' });
    c.cyl({ name: 'PodCap', axis: 'y', len: 0.4, d: 1.0, p: [x, 6.9, 0.6], c: ink });
    const mark = c.box({ name: 'PodCenter' + (i + 1), s: [0.3, 0.3, 0.3], p: [x, 3.6, 0.6], t: 1, shadow: false });
    mark.set('CanQuery', 'bool', false);
    if (i === 2) c.box({ name: 'Padlock', s: [0.8, 0.7, 0.3], p: [x, 3.4, -0.75], c: yellow, m: 'Metal' });
    c.box({ name: 'PodLight', s: [0.5, 0.2, 0.2], p: [x, 1.2, -0.8], c: i === 2 ? '#e8473a' : '#7cf28a', m: 'Neon', shadow: false });
  });
  // cables to the back and a tablet terminal in front
  c.sym((s) => s.tube([4.8, 1.0, 2.6], [4.8, 3.6, 2.9], 0.4, { name: 'Cable', c: ink }));
  c.cyl({ name: 'TerminalStalk', axis: 'y', len: 2.4, d: 0.4, p: [5.6, 1.2, -1.2], c: ink });
  const t = c.at([5.6, 2.8, -1.2], [-28, -25, 0]);
  t.box({ name: 'TerminalCase', s: [2.4, 1.7, 0.35], c: teal, studs: 'sides' });
  t.box({ name: 'Screen', s: [2.0, 1.3, 0.06], p: [0, 0, -0.18], c: '#123f3a', m: 'Neon', shadow: false });
  const host = c.box({ name: 'MachinePromptHost', s: [0.4, 0.4, 0.4], p: [0, 2.6, -3.2], t: 1, shadow: false });
  prompt(host, 'CompanionPrompt', 'Open', 'Companion Pods', 'Companion', 11);
  return m;
}

// the yard kit: a builder's bench beside the Companion pad - fence planks, a half-built fence, a mallet and a plan of
// your yard. Its prompt buys one more yard space (2026-10-14, user: "have upgrading the amount of dinos allowed in pen
// inside the pen next to companion")
function buildYardKit() {
  const { m, c } = newModel('YardKit');
  const wood = '#a0723f', woodLo = '#7d5733', ink = '#26282d', yellow = '#ffc21f', paper = '#3f7fd0';
  // the bench
  c.box({ name: 'BenchTop', s: [4.6, 0.4, 2.6], p: [0, 2.6, 0], c: wood, m: 'WoodPlanks', studs: 'top', collide: true });
  for (const x of [-1.9, 1.9]) for (const z of [-0.9, 0.9]) c.box({ name: 'BenchLeg', s: [0.4, 2.4, 0.4], p: [x, 1.2, z], c: woodLo, m: 'WoodPlanks' });
  c.box({ name: 'BenchShelf', s: [4.0, 0.25, 2.0], p: [0, 0.8, 0], c: woodLo, m: 'WoodPlanks' });
  // the plan, pinned flat on the bench: a little yard with one fence side dashed (the bit you're adding)
  const plan = c.box({ name: 'YardPlan', s: [2.4, 0.06, 1.7], p: [-0.7, 2.83, 0.1], r: [0, -8, 0], c: paper });
  surfaceLabel(plan, 'Top', '+1 YARD', { name: 'PlanText', pps: 40, color: '#ffffff', color2: '#bfe3ff' });
  // the mallet
  c.box({ name: 'MalletHead', s: [0.9, 0.55, 0.55], p: [1.4, 3.1, -0.5], r: [0, 30, 0], c: ink });
  c.beam([1.4, 3.1, -0.5], [1.9, 2.9, 0.6], 0.2, 0.2, { name: 'MalletHandle', c: '#c08a4a' });
  // planks stacked on the shelf and leaning on the side
  for (let i = 0; i < 3; i++) c.box({ name: 'Plank', s: [3.6, 0.22, 0.6], p: [0, 1.05 + i * 0.24, -0.4 + i * 0.35], r: [0, (i - 1) * 4, 0], c: i % 2 ? wood : '#b5844c', m: 'WoodPlanks' });
  c.box({ name: 'LeanPlank', s: [0.6, 3.6, 0.22], p: [2.75, 1.7, 0.5], r: [0, 0, -14], c: '#b5844c', m: 'WoodPlanks' });
  // the half-built fence it's adding: two posts and one rail
  for (const x of [-3.6, -5.6]) c.box({ name: 'NewPost', s: [0.6, 3.0, 0.6], p: [x, 1.5, 0.6], c: woodLo, m: 'WoodPlanks', studs: 'top', collide: true });
  c.box({ name: 'NewRail', s: [2.4, 0.35, 0.3], p: [-4.6, 2.2, 0.6], c: wood, m: 'WoodPlanks' });
  c.box({ name: 'Stake', s: [0.3, 1.0, 0.3], p: [-5.6, 3.3, 0.6], c: yellow });
  const host = c.box({ name: 'YardPromptHost', s: [0.4, 0.4, 0.4], p: [0, 3.2, -1.8], t: 1, shadow: false });
  const pr = prompt(host, 'YardPrompt', 'Bigger yard', 'Yard', 'Yard', 10);
  pr.set('HoldDuration', 'float', 0.6);
  return m;
}

function buildCampProps() {
  return {
    CompanionMachine: buildOptionTablet('CompanionMachine'), // the Pal Pad (picked 2026-10-12)
    YardKit: buildYardKit(),
    TreatBarrel: buildTreatBarrel(),
    ToyCrate: buildToyCrate(),
    PlayBall: buildBall(),
    Treat: buildTreat(),
  };
}

module.exports = { buildCampProps, buildOptionTablet, buildOptionDen, buildOptionPods };
