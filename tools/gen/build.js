// Entry point:  node tools/gen/build.js [--preview-only]
// Generates every model into src/ (Rojo-synced .rbxmx) and tools/preview/out/scene.json (QC preview).
const fs = require('fs');
const path = require('path');
const B = require('./builder.js');
const { CF } = B;
const { buildVehicleShowcase, buildDinoShowcase } = require('./showcase.js');

const ROOT = path.resolve(__dirname, '../..');
const OUT_PREVIEW = path.join(ROOT, 'tools/preview/out');
fs.mkdirSync(OUT_PREVIEW, { recursive: true });
const previewOnly = process.argv.includes('--preview-only');

function writeFile(rel, content) {
  const p = path.join(ROOT, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, content);
}

function report(name, inst) {
  const parts = inst.count((i) => !!i._preview && !i._isBone);
  const b = B.bounds(inst);
  const joints = inst.count((i) => i.cls === 'Motor6D');
  console.log(`${name.padEnd(18)} parts=${String(parts).padStart(4)}  L=${b.size[2].toFixed(1)} W=${b.size[0].toFixed(1)} H=${b.size[1].toFixed(1)}${joints ? `  joints=${joints}` : ''}`);
}

const vehicleMods = {
  RookieRanger: require('./vehicles/rookieRanger.js'),
  RaptorRunner: require('./vehicles/raptorRunner.js'),
  TitanTransport: require('./vehicles/titanTransport.js'),
};
const dinoMods = {
  Velociraptor: require('./dinos/velociraptor.js'),
  TyrannosaurusRex: require('./dinos/trex.js'),
  Triceratops: require('./dinos/triceratops.js'),
  Stegosaurus: require('./dinos/stegosaurus.js'),
  Parasaurolophus: require('./dinos/parasaurolophus.js'),
  Ankylosaurus: require('./dinos/ankylosaurus.js'),
  Carnotaurus: require('./dinos/carnotaurus.js'),
  Brachiosaurus: require('./dinos/brachiosaurus.js'),
  Spinosaurus: require('./dinos/spinosaurus.js'),
  Giganotosaurus: require('./dinos/giganotosaurus.js'),
  Mosasaurus: require('./dinos/mosasaurus.js'),
  PrimalRex: require('./dinos/primalrex.js'),
};
// 2026-10-12 roster expansion: new species load only when their files exist and build (tools/gen/newSpecies.js)
const NEW_SPECIES = require('./newSpecies.js').load();
Object.assign(dinoMods, NEW_SPECIES.dinoMods);

// FK test pose (degrees) used to verify joint pivots in the preview.
// Sign convention: +X pitch raises forward-pointing segments, lowers the tail and swings legs forward.
function testPose(model) {
  const D = (x, y, z) => CF.deg(x, y, z);
  const pose = {};
  model.walk((i) => {
    if (!i._isBone) return;
    const n = i.name;
    if (n === 'Jaw') pose[n] = D(-35, 0, 0);
    if (/^Neck/.test(n)) pose[n] = D(14, 8, 0);
    if (n === 'Head') pose[n] = D(-10, 10, 8);
    if (/^Tail/.test(n)) pose[n] = D(-4, 14, 0);
    if (n === 'RightThigh') pose[n] = D(35, 0, 0);
    if (n === 'RightShin') pose[n] = D(-40, 0, 0);
    if (n === 'RightFoot') pose[n] = D(20, 0, 0);
    if (n === 'LeftThigh') pose[n] = D(-20, 0, 0);
    if (/Arm$/.test(n)) pose[n] = D(-30, 0, 0);
    if (/SickleClaw$/.test(n)) pose[n] = D(-30, 0, 0);
  });
  return pose;
}

const groups = [];
const vehicles = {};
const QCR = require('./qc.js');
for (const [name, mod] of Object.entries(vehicleMods)) {
  const m = mod.build();
  const zf = QCR.resolveZFight(m);
  report(name, m);
  if (zf) console.log(`${''.padEnd(18)} z-fight fixes=${zf}`);
  groups.push({ name, parts: B.previewParts(m) });
  vehicles[name] = m;
}
const dinos = {};
for (const [name, mod] of Object.entries(dinoMods)) {
  const m = mod.build();
  const zf = QCR.resolveZFight(m);
  let pelvis = null; m.walk((i) => { if (i._isBone && (i.name === 'Pelvis')) pelvis = i; });
  if (pelvis) m.attr('HipHeight', +(pelvis._cf.y - B.bounds(m).min[1]).toFixed(2));
  report(name, m);
  if (zf) console.log(`${''.padEnd(18)} z-fight fixes=${zf}`);
  groups.push({ name, parts: B.previewParts(m) });
  groups.push({ name: name + '_pose', parts: B.previewParts(m, testPose(m)) });
  dinos[name] = m;
}

// Lineup preview: every creature side by side (facing the camera at -Z)
{
  const lineup = [];
  let x = 0;
  for (const [name, m] of Object.entries(dinos)) {
    const b = B.bounds(m);
    const c = B.cloneTree(m);
    B.transformTree(c, new CF(x - b.min[0], 0, 0));
    lineup.push(...B.previewParts(c));
    x += b.size[0] + 3;
  }
  groups.push({ name: 'Lineup', parts: lineup });
}

// Templates (at origin) → ReplicatedStorage.DinoExpedition.Dinosaurs
if (!previewOnly) {
  for (const [name, m] of Object.entries(dinos)) writeFile(`src/ReplicatedStorage/DinoExpedition/Dinosaurs/${name}.rbxmx`, B.toRbxmx(m));
}
// Showcase scene (dinos are cloned; vehicle instances are moved into place)
const dinoShowcase = buildDinoShowcase(dinos);
const vehicleShowcase = buildVehicleShowcase(vehicles);
// (2026-10-12) Base Camp's lagoon and crater rim now reach world x 0 west of camp, where the showcase used to stand:
// the whole showcase moves south-west, clear of everything (DevTools "Showcase" teleport follows SHOWCASE_SHIFT).
// (2026-10-13) Further out (past the west rim, 700+ studs from the nearest island, so its 33 rigs never animate for
// camp players), standing on its own pad in the open sea: the template Baseplate it used to stand on is gone.
const SHOWCASE_SHIFT = [-1034, 0, 450];
B.transformTree(dinoShowcase, new B.CF(...SHOWCASE_SHIFT));
B.transformTree(vehicleShowcase, new B.CF(...SHOWCASE_SHIFT));
{
  const b1 = B.bounds(dinoShowcase), b2 = B.bounds(vehicleShowcase);
  const x0 = Math.min(b1.min[0], b2.min[0]) - 30, x1 = Math.max(b1.max[0], b2.max[0]) + 30;
  const z0 = Math.min(b1.min[2], b2.min[2]) - 30, z1 = Math.max(b1.max[2], b2.max[2]) + 30;
  const pad = new B.Ctx({ parent: dinoShowcase, frame: new B.CF(), defaults: { anchored: true } });
  pad.box({ name: 'ShowcasePad', s: [x1 - x0, 24, z1 - z0], p: [(x0 + x1) / 2, -12, (z0 + z1) / 2], c: '#6fae4a', m: 'Grass', collide: true });
  pad.box({ name: 'ShowcaseBeach', s: [x1 - x0 + 16, 22, z1 - z0 + 16], p: [(x0 + x1) / 2, -11.4, (z0 + z1) / 2], c: '#ecd9a4', m: 'Sand', collide: true, shadow: false });
  console.log(`showcase pad x ${x0.toFixed(0)}..${x1.toFixed(0)} z ${z0.toFixed(0)}..${z1.toFixed(0)}`);
}
if (!previewOnly) {
  writeFile('src/Workspace/DinoExpeditionShowcase.rbxmx', B.toRbxmx(dinoShowcase));
  writeFile('src/Workspace/DinoExpeditionVehicles.rbxmx', B.toRbxmx(vehicleShowcase));
}
groups.push({ name: 'Showcase', parts: [...B.previewParts(dinoShowcase), ...B.previewParts(vehicleShowcase)] });

// ---------------- Eggs, babies, gameplay vehicle templates ----------------
const { buildEgg, EGG_SPECIES } = require('./eggs.js');
const { buildBaby } = require('./babies.js');
const { buildTemplate } = require('./vehicleTemplate.js');
const { buildKits } = require('./vehicles/kits.js');
const kitGroups = [];
const KIT_LINEUPS = {
  Front: [null, 'RacerLip', 'BullBar', 'Plow', 'CrocJaw', 'TrikeRam'],
  Rear: [null, 'Ducktail', 'TwinPipes', 'GTWing', 'DinoTail', 'Rocket', 'Outboard'],
  Roof: [null, 'LightBar', 'Dish', 'Sirens', 'DinoHead', 'Crown'],
  Wrap: ['Stripe', 'Racing', 'Checker', 'Spots', 'Tiger', 'Camo', 'Lightning', 'Flames', 'Claws', 'Tide'],
  Rims: [null, 'Steelie', 'Spoke', 'Dish', 'Mesh', 'Star', 'Turbine', 'Claw'],
  Tires: [null, 'Whitewall', 'Redline', 'Slick', 'Knobby', 'Mud'],
};
// JS mirror of Rides.Apply's geometry (no paint): a template clone with one kit option fitted
function kitPreview(t, kits, picks) {
  const c = B.cloneTree(t);
  const drop = (pred) => c.walk((i) => { i.children = i.children.filter((ch) => !pred(ch)); });
  const graft = (src, into) => { if (src) into.add(B.cloneTree(src)); };
  const kitOf = (group, id) => { const g = kits.children.find((x) => x.name === group); return g && g.children.find((x) => x.name === id); };
  for (const slot of ['Front', 'Rear', 'Roof']) {
    if (!picks[slot]) continue;
    drop((i) => i.attrs && i.attrs.KitSlot === slot);
    graft(kitOf(slot, picks[slot]), c);
  }
  if (picks.Wrap) graft(kitOf('Wrap', picks.Wrap), c);
  // preview the colour roles the way Rides.Apply would with a sample wrap / rim colour
  c.walk((i) => {
    if (!i._preview || !i.attrs) return;
    const sample = { W: '#ff6a1f', R: picks.Rims ? '#d9dde3' : null }[i.attrs.Paint];
    if (sample) i._preview.color = B.shade(sample, i.attrs.Shade || 1);
  });
  for (const [slot, prefix, names] of [['Rims', 'Rim_', /^(Rim|RimLip|RimAccent|Spoke|LugNut)$/], ['Tires', 'Tire_', /^(Tire|Sidewall|Tread)$/]]) {
    if (!picks[slot]) continue;
    const kit = kitOf('Wheels', prefix + picks[slot]);
    const wheelModels = [];
    c.walk((m) => { if (m.cls === 'Model' && /^Wheel[A-Z]/.test(m.name)) wheelModels.push(m); });
    wheelModels.forEach((m) => {
      const src = kit && kit.children.find((x) => x.name === m.name);
      if (!src) return;
      m.walk((i) => { i.children = i.children.filter((ch) => !names.test(ch.name)); });
      graft(src, m);
    });
  }
  return c;
}
{
  const eggRow = [], babyRow = [];
  let ex = 0, bx = 0;
  for (const sp of Object.keys(EGG_SPECIES)) {
    if (!dinos[sp]) continue; // a new species whose rig isn't in yet: no egg/baby until it is
    const egg = buildEgg(sp);
    if (!previewOnly) writeFile(`src/ReplicatedStorage/DinoExpedition/Eggs/${sp}Egg.rbxmx`, B.toRbxmx(egg));
    groups.push({ name: sp + 'Egg', parts: B.previewParts(egg) });
    const ec = B.cloneTree(egg); B.transformTree(ec, new CF(ex, 0, 0)); eggRow.push(...B.previewParts(ec)); ex += 2.6;
    const baby = buildBaby(dinos[sp]);
    if (!previewOnly) writeFile(`src/ReplicatedStorage/DinoExpedition/Babies/${sp}.rbxmx`, B.toRbxmx(baby));
    groups.push({ name: sp + 'Baby', parts: B.previewParts(baby) });
    const bb = B.bounds(baby);
    const bc = B.cloneTree(baby); B.transformTree(bc, new CF(bx - bb.min[0], 0, 0)); babyRow.push(...B.previewParts(bc)); bx += bb.size[0] + 1.5;
  }
  groups.push({ name: 'Eggs', parts: eggRow });
  groups.push({ name: 'Babies', parts: babyRow });
  for (const [name, mod] of Object.entries(vehicleMods)) {
    const v = mod.build();
    QCR.resolveZFight(v);
    const t = buildTemplate(v, name);
    if (!previewOnly) writeFile(`src/ReplicatedStorage/DinoExpedition/Vehicles/${name}.rbxmx`, B.toRbxmx(t));
    groups.push({ name: name + 'Template', parts: B.previewParts(t) });
    // build-your-own rover kits for this body + QC lineups (one variant per slot option, side by side)
    const kits = buildKits(t, name);
    if (!previewOnly) writeFile(`src/ReplicatedStorage/DinoExpedition/RoverKits/${name}.rbxmx`, B.toRbxmx(kits));
    let kitParts = 0;
    kits.walk((i) => { if (i._preview) kitParts++; });
    console.log(`${(name + ' kits').padEnd(18)} parts=${kitParts}`);
    for (const [slot, ids] of Object.entries(KIT_LINEUPS)) {
      for (const id of ids) kitGroups.push({ name: `${name}_${slot}_${id || 'Stock'}`, parts: B.previewParts(kitPreview(t, kits, { [slot]: id })) });
    }
  }
}
fs.writeFileSync(path.join(OUT_PREVIEW, 'kits.json'), JSON.stringify({ groups: kitGroups }));
// pickups (boss keys): things that drop for you to walk over and pick up
{
  const { buildKey, KEYS } = require('./pickups.js');
  if (!previewOnly) for (const id of Object.keys(KEYS)) writeFile(`src/ReplicatedStorage/DinoExpedition/Pickups/BossKey_${id}.rbxmx`, B.toRbxmx(buildKey(id)));
}
// gear: armor sets (pieces by level), launchers, the outfitter's mannequin -> ReplicatedStorage.DinoExpedition.Gear
if (!previewOnly) writeFile('src/ReplicatedStorage/DinoExpedition/Gear.rbxmx', B.toRbxmx(require('./gear.js').buildGear()));
// ---------------- paddock props (Companion Machine, play corner) - cloned into each paddock by PaddockLife -------
{
  const { buildCampProps } = require('./campProps.js');
  let px = 0;
  const row = [];
  for (const [name, m] of Object.entries(buildCampProps())) {
    if (!previewOnly) writeFile(`src/ReplicatedStorage/DinoExpedition/CampProps/${name}.rbxmx`, B.toRbxmx(m));
    groups.push({ name, parts: B.previewParts(m) });
    const c = B.cloneTree(m); B.transformTree(c, new CF(px, 0, 0)); row.push(...B.previewParts(c)); px += 9;
  }
  groups.push({ name: 'CampProps', parts: row });
}
// ---------------- Base Camp ----------------
const { buildHub } = require('./hub.js');
// the buildings an island grows into (IslandView clones them onto each island): ReplicatedStorage.DinoExpedition.IslandKit
{
  const { buildIslandKit } = require('./islandKit.js');
  const kit = buildIslandKit();
  { const n = require('./calm.js').solidGarages(kit); console.log(`IslandKit: ${n} garage parts made solid`); }
  require('./calm.js').calmHub(kit); // same calm look as Base Camp (no neon, soft lights): it ends up standing in it
  if (!previewOnly) writeFile('src/ReplicatedStorage/DinoExpedition/IslandKit.rbxmx', B.toRbxmx(kit));
  fs.writeFileSync(path.join(OUT_PREVIEW, 'islandkit.json'), JSON.stringify({ groups: kit.children.map((m) => ({ name: m.name, parts: B.previewParts(m) })) }));
  console.log(`IslandKit: ${kit.children.length} models, parts=${kit.count((i) => !!i._preview)}`);
}
const hub = buildHub();
{ const n = require('./calm.js').solidGarages(hub); console.log(`BaseCamp: ${n} garage parts made solid`); }
{ const r = require('./calm.js').calmHub(hub); console.log(`BaseCamp calm: ${r.neon} neon off, ${r.lights} lights dimmed, ${r.stripes} stripes muted, ${r.emitters} emitters, ${r.dropped} dropped, ${r.gateGlow} Time Gate glows kept`); }
const MAPQC = require('./mapqc.js');

// 2026-10-14 user: "get rid of signs, they look out of place" - an era's name is on the map and the HUD already.
// Every name board in the eras goes (board, post, frame, trim, the skull / snow on top); the hub keeps its signs.
const SIGN_PARTS = /^Sign(Post|Frame|Trim|Skull|Snow)?$/;
function stripSigns(model) {
  let n = 0;
  model.walk((i) => { const before = i.children.length; i.children = i.children.filter((ch) => !SIGN_PARTS.test(ch.name)); n += before - i.children.length; });
  console.log(`  ${model.name}: removed ${n} sign parts`);
}
{ const r = MAPQC.check(hub); console.log(`BaseCamp QC: pruned ${r.pruned} clipping decor, ${r.struct.length} structure clips`); for (const h of r.struct.slice(0, 40)) console.log('   s', h.a, 'x', h.b, h.pen, h.at.join(',')); }
if (!previewOnly) writeFile('src/Workspace/BaseCamp.rbxmx', B.toRbxmx(hub));
fs.writeFileSync(path.join(OUT_PREVIEW, 'hub.json'), JSON.stringify({ groups: [{ name: 'BaseCamp', parts: B.previewParts(hub) }] }));
console.log(`BaseCamp parts=${hub.count((i) => !!i._preview)}`);
// ---------------- Fern Valley ----------------
{
  const { buildFernValley } = require('./fernValley.js');
  const { toLuau: L } = require('./anim/luau.js');
  const fv = buildFernValley();
  stripSigns(fv.model); { const r = MAPQC.check(fv.model); console.log(`FernValley QC: pruned ${r.pruned} clipping decor, ${r.struct.length} structure clips`); for (const h of r.struct.slice(0, 40)) console.log('   s', h.a, 'x', h.b, h.pen, h.at.join(',')); }
  if (!previewOnly) {
    writeFile('src/Workspace/FernValley.rbxmx', B.toRbxmx(fv.model));
    writeFile('src/ReplicatedStorage/DinoExpedition/Routes/FernValley.luau', '-- GENERATED by tools/gen/fernValley.js — edit the JS source, then rebuild.\n--!nocheck\nreturn ' + L(fv.data) + '\n');
  }
  fs.writeFileSync(path.join(OUT_PREVIEW, 'valley.json'), JSON.stringify({ groups: [{ name: 'FernValley', parts: B.previewParts(fv.model) }] }));
  console.log(`FernValley parts=${fv.model.count((i) => !!i._preview)} variants=${fv.data.Variants.map((v) => v.Length).join('/')}`);
}

// ---------------- Giant Plains ----------------
{
  const { buildGiantPlains } = require('./giantPlains.js');
  const { toLuau: L } = require('./anim/luau.js');
  const gp = buildGiantPlains();
  stripSigns(gp.model); { const r = MAPQC.check(gp.model); console.log(`GiantPlains QC: pruned ${r.pruned} clipping decor, ${r.struct.length} structure clips`); for (const h of r.struct.slice(0, 40)) console.log('   s', h.a, 'x', h.b, h.pen, h.at.join(',')); }
  if (!previewOnly) {
    writeFile('src/Workspace/GiantPlains.rbxmx', B.toRbxmx(gp.model));
    writeFile('src/ReplicatedStorage/DinoExpedition/Routes/GiantPlains.luau', '-- GENERATED by tools/gen/giantPlains.js — edit the JS source, then rebuild.\n--!nocheck\nreturn ' + L(gp.data) + '\n');
  }
  fs.writeFileSync(path.join(OUT_PREVIEW, 'plains.json'), JSON.stringify({ groups: [{ name: 'GiantPlains', parts: B.previewParts(gp.model) }] }));
  console.log(`GiantPlains parts=${gp.model.count((i) => !!i._preview)} variants=${gp.data.Variants.map((v) => v.Length).join('/')}`);
}

{
  const { toLuau: L } = require('./anim/luau.js');
  const { buildSpineRiver } = require('./spineRiver.js');
  const sr = buildSpineRiver();
  stripSigns(sr.model); { const r = MAPQC.check(sr.model); console.log(`SpineRiver QC: pruned ${r.pruned} clipping decor, ${r.struct.length} structure clips`); for (const h of r.struct.slice(0, 40)) console.log('   s', h.a, 'x', h.b, h.pen, h.at.join(',')); }
  if (!previewOnly) {
    writeFile('src/Workspace/SpineRiver.rbxmx', B.toRbxmx(sr.model));
    writeFile('src/ReplicatedStorage/DinoExpedition/Routes/SpineRiver.luau', '-- GENERATED by tools/gen/spineRiver.js — edit the JS source, then rebuild.\n--!nocheck\nreturn ' + L(sr.data) + '\n');
  }
  fs.writeFileSync(path.join(OUT_PREVIEW, 'river.json'), JSON.stringify({ groups: [{ name: 'SpineRiver', parts: B.previewParts(sr.model) }] }));
  console.log(`SpineRiver parts=${sr.model.count((i) => !!i._preview)} variants=${sr.data.Variants.map((v) => v.Length).join('/')}`);
}

// ---------------- 2026-10-12 new eras (tools/gen/NEW_ERAS_BRIEF.md) ----------------
// Each builds only when its generator exists; a generator that throws is reported and skipped so it can't
// break the rest of the build. Module exports build<Zone>() -> { model, data } and optionally QC = { decor, ground }.
for (const [zone, file, fn, preview] of [
  ['RedCliffs', 'redCliffs', 'buildRedCliffs', 'cliffs'],
  ['FrostForest', 'frostForest', 'buildFrostForest', 'frost'],
  ['DawnDesert', 'dawnDesert', 'buildDawnDesert', 'dawn'],
]) {
  const mod = require('./newSpecies.js').tryRequire(`${file}.js`);
  if (!mod || !mod[fn]) continue;
  let era;
  try { era = mod[fn](); } catch (e) { console.log(`WARNING: ${zone} failed to build: ${e.stack}`); continue; }
  const { toLuau: L } = require('./anim/luau.js');
  stripSigns(era.model); { const r = MAPQC.check(era.model, mod.QC); console.log(`${zone} QC: pruned ${r.pruned} clipping decor, ${r.struct.length} structure clips`); for (const h of r.struct.slice(0, 40)) console.log('   s', h.a, 'x', h.b, h.pen, h.at.join(',')); }
  if (!previewOnly) {
    writeFile(`src/Workspace/${zone}.rbxmx`, B.toRbxmx(era.model));
    writeFile(`src/ReplicatedStorage/DinoExpedition/Routes/${zone}.luau`, `-- GENERATED by tools/gen/${file}.js — edit the JS source, then rebuild.\n--!nocheck\nreturn ` + L(era.data) + '\n');
  }
  fs.writeFileSync(path.join(OUT_PREVIEW, `${preview}.json`), JSON.stringify({ groups: [{ name: zone, parts: B.previewParts(era.model) }] }));
  console.log(`${zone} parts=${era.model.count((i) => !!i._preview)} variants=${era.data.Variants.map((v) => v.Length).join('/')}`);
}

fs.writeFileSync(path.join(OUT_PREVIEW, 'scene.json'), JSON.stringify({ groups }));

// ---------------- Animation profiles + shot lists → Luau ----------------
const { toLuau } = require('./anim/luau.js');
const RT = require('./anim/runtime.js');
const animProfiles = {
  Velociraptor: require('./anim/velociraptor.js'), TyrannosaurusRex: require('./anim/trex.js'),
  Triceratops: require('./anim/triceratops.js'), Stegosaurus: require('./anim/stegosaurus.js'), Parasaurolophus: require('./anim/parasaurolophus.js'),
  Ankylosaurus: require('./anim/ankylosaurus.js'), Carnotaurus: require('./anim/carnotaurus.js'), Brachiosaurus: require('./anim/brachiosaurus.js'),
  Spinosaurus: require('./anim/spinosaurus.js'), Giganotosaurus: require('./anim/giganotosaurus.js'), Mosasaurus: require('./anim/mosasaurus.js'),
  PrimalRex: require('./anim/primalrex.js'),
  ...NEW_SPECIES.animProfiles,
};
const SHOTS = require('./anim/shots.js');
const GEN = '-- GENERATED by tools/gen/build.js from tools/gen/anim/*.js — edit the JS source, then rebuild.\n';
if (!previewOnly) {
  for (const [name, prof] of Object.entries(animProfiles)) {
    writeFile(`src/ReplicatedStorage/DinoExpedition/DinosaurAnimations/Profiles/${name}.luau`, GEN + `-- Pose entries: Joint = { rx, ry, rz, px, py, pz } (radians / studs); "~Joint" = mirrored Right/Left pair.\nreturn ${toLuau(prof)}\n`);
  }
  writeFile('src/ReplicatedStorage/DinoExpedition/DinosaurCinematics/Shots.luau', GEN + `return ${toLuau(SHOTS)}\n`);
}

// ---------------- Cinematic QC frames (posed creature + camera) ----------------
function placedCreature(root, species) {
  let found = null;
  root.walk((i) => { if (!found && i.cls === 'Model' && i.attrs.Species === species) found = i; });
  return found;
}
function cineFrames(species, actionName, shotsName) {
  const model = placedCreature(dinoShowcase, species);
  if (!model) return;
  const prof = animProfiles[species];
  const action = prof.Actions[actionName];
  const list = SHOTS[shotsName];
  const D = action.Duration, u = list.Studs ? 1 : prof.CameraScale;
  const bones = {}; let rootPart = null; const atts = {};
  model.walk((i) => {
    if (i._isBone) bones[i.name] = i;
    if (i.name === 'RootPart') rootPart = i;
    if (i.cls === 'Attachment') atts[i.name] = i;
  });
  let water = null; model.parent.walk((i) => { if (i.tags.includes('DinoWater')) water = i; });
  const waterY = water ? water._cf.y + water._preview.size[1] / 2 : -Infinity;
  const footY = Math.max(atts.VFX_RightFoot ? atts.VFX_RightFoot._world.y : -Infinity, waterY);
  const R = rootPart._cf;
  const G = new CF(R.x, footY, R.z, R.r.slice());
  // environment without the creature (and without the moving foliage curtain)
  const detach = [model];
  dinoShowcase.walk((i) => { if (i.tags.includes('CinematicFoliage')) detach.push(i); });
  const props = [];
  model.parent.walk((i) => { if (i.tags.includes('CinematicProp')) props.push(i); });
  const saved = detach.map((m) => { const par = m.parent; const ix = par.children.indexOf(m); par.children.splice(ix, 1); return [m, par, ix]; });
  const savedProps = props.map((m) => { const par = m.parent; const ix = par.children.indexOf(m); par.children.splice(ix, 1); return [m, par, ix]; });
  const env = [...B.previewParts(dinoShowcase)];
  for (const [m, par, ix] of savedProps.reverse()) par.children.splice(ix, 0, m);
  for (const [m, par, ix] of saved.reverse()) par.children.splice(ix, 0, m);
  // props: hidden after BreakProp; trees topple after FellTrees
  const evTime = (name, id) => { const e = (action.Events || []).find((x) => x[1] === name && (!id || (x[2] && x[2].Prop === id))); return e ? e[0] : Infinity; };
  const propParts = (t) => {
    const out = [];
    for (const pm of props) {
      const id = pm.attrs.PropId;
      if (t > evTime('BreakProp', id)) continue;
      const fell = evTime('FellTrees', id);
      if (t > fell) {
        const k = Math.min(1, (t - fell) / 0.9);
        for (const tree of pm.children.filter((c) => c.cls === 'Model')) {
          let base = null; tree.walk((q) => { if (q.name === 'TreeBase') base = q; });
          const bp = base._cf.pos();
          const away = [bp[0] - model.find('RootPart')._cf.x, 0, bp[2] - model.find('RootPart')._cf.z];
          const L = Math.hypot(...away) || 1;
          const axis = [away[2] / L, 0, -away[0] / L];
          const ang = -1.4 * k * k;
          const c = Math.cos(ang), sn = Math.sin(ang), [ax, , az] = axis;
          const rot = new CF(0, 0, 0, [c + ax * ax * (1 - c), -az * sn, ax * az * (1 - c), az * sn, c, -ax * sn, az * ax * (1 - c), ax * sn, c + az * az * (1 - c)]);
          const xf = new CF(...bp).mul(rot).mul(new CF(-bp[0], -bp[1], -bp[2]));
          for (const pp of B.previewParts(tree)) { const w = xf.mul(new CF(pp.cf[0], pp.cf[1], pp.cf[2], pp.cf.slice(3))); out.push(Object.assign({}, pp, { cf: [w.x, w.y, w.z, ...w.r] })); }
        }
        continue;
      }
      out.push(...B.previewParts(pm));
    }
    return out;
  };
  const curtains = detach.slice(1).map((c) => {
    let pv = null; c.walk((i) => { if (i.name === 'CurtainPivot') pv = i; });
    return { parts: B.previewParts(c), pivot: pv._cf, side: c.attrs.Side, close: c.attrs.CloseDistance || 7 };
  });
  const usesCurtain = (action.Events || []).some((e) => e[1] === 'CurtainClose');
  const curtainParts = (t) => {
    const out = [];
    for (const c of curtains) {
      let k = 0; // 1 = fully closed
      if (usesCurtain) {
        const open = (action.Events.find((e) => e[1] === 'CurtainOpen') || [0])[0];
        k = t < open ? 1 : Math.max(0, 1 - RT.Ease.Back(Math.min(1, (t - open) / 0.55)));
      }
      const off = c.pivot.mul(new CF(-c.side * c.close * k, 0, 0)).mul(c.pivot.inv());
      for (const p of c.parts) {
        const cf = new CF(p.cf[0], p.cf[1], p.cf[2], p.cf.slice(3));
        const w = off.mul(cf);
        out.push(Object.assign({}, p, { cf: [w.x, w.y, w.z, ...w.r] }));
      }
    }
    return out;
  };
  const k = list.Normalized ? D : 1;
  const times = [];
  for (const s of list.Shots) { const a = s.T0 * k, b = s.T1 * k; times.push([a + 0.04, s.Name], [(a + b) / 2, s.Name], [b - 0.04, s.Name]); }
  const restCache = new Map();
  const headStart = B.posedWorld(atts.VFX_Head.parent, {}, restCache).mul(atts.VFX_Head.parent._cf.inv().mul(atts.VFX_Head._world)).pos();
  let propPos = null, herdPos = null;
  model.parent.walk((i) => {
    if (list.Prop && i.attrs && i.attrs.PropId === list.Prop) { let pv = null; i.walk((q) => { if (!pv && q._cf) pv = q; }); propPos = i._pivot ? i._pivot.pos() : pv._cf.pos(); }
    if (i.attrs && i.attrs.HerdLeader === model.name && !herdPos) { let h = null; i.walk((q) => { if (q.name === 'VFX_Head') h = q; }); herdPos = h._world.pos(); }
  });
  const frames = times.map(([t]) => {
    const pose = RT.actionPose(prof, actionName, t);
    const cache = new Map();
    const world = (att) => { const bone = att.parent; return B.posedWorld(bone, pose, cache).mul(bone._cf.inv().mul(att._world)).pos(); };
    const targets = { Head: world(atts.VFX_Head), Mouth: world(atts.VFX_Mouth), Chest: world(atts.VFX_Chest), HeadStart: headStart, Prop: propPos, Herd: herdPos };
    for (const k of ['RightFoot', 'LeftFoot', 'TailTip', 'RightFrontFoot', 'RightClaw', 'Crest', 'Club']) if (atts['VFX_' + k]) targets[k] = world(atts['VFX_' + k]);
    const cam = RT.sampleShots(list, t, D, G, u, targets);
    return { t: +t.toFixed(2), shot: cam.shot, cam, parts: [...B.previewParts(model, pose), ...curtainParts(t), ...propParts(t)] };
  });
  fs.writeFileSync(path.join(OUT_PREVIEW, `cine_${species}_${shotsName}.json`), JSON.stringify({ env, frames, letterbox: 0.11 }));
  console.log(`cine ${species}/${shotsName}: ${frames.length} frames`);
}
// Gait QC sheet: walk + run across the cycle, side camera, template at origin
function gaitSheet(species) {
  const model = dinos[species];
  const prof = animProfiles[species];
  if (!model || !prof) return;
  const b = B.bounds(model);
  const L = b.size[2], H = b.size[1];
  const cz = (b.min[2] + b.max[2]) / 2;
  const frames = [];
  for (const mode of ['Walk', 'Run']) for (let i = 0; i < 6; i++) {
    const phase = i / 6;
    const pose = RT.gaitPose(prof, mode, phase);
    const cam = { pos: [L * 1.25 + 4, H * 0.45, cz], look: [0, H * 0.42, cz], fov: 40, roll: 0 };
    frames.push({ t: phase, shot: mode, cam, parts: B.previewParts(model, pose) });
  }
  frames.push({ t: 0, shot: 'Rest 3/4', cam: { pos: [L * 0.75, H * 0.75, -L * 0.85], look: [0, H * 0.45, cz], fov: 40, roll: 0 }, parts: B.previewParts(model) });
  fs.writeFileSync(path.join(OUT_PREVIEW, `gait_${species}.json`), JSON.stringify({ env: [], frames, letterbox: 0 }));
}
for (const n of Object.keys(dinos)) gaitSheet(n);

// ---------------- Clipping QC (node tools/gen/build.js --qc) ----------------
if (process.argv.includes('--qc')) {
  const QC = require('./qc.js');
  const WHEEL_OK = /Axle|Shock|Spring|Hub|AArm|TrailingArm|Differential|LeafSpring|Coil|Mount|Strut|Fender|Flare|Spare/;
  for (const [name, m] of Object.entries(vehicleMods)) {
    const v = m.build();
    QCR.resolveZFight(v);
    const parts = B.previewParts(v);
    const zf = QC.zFight(parts);
    // wheel vs body: parts under a Wheels/... model vs everything else
    const wheelNames = new Set();
    const wheels = v.find('Wheels');
    if (wheels) wheels.walk((i) => { if (i._preview) wheelNames.add(i); });
    const W = [], O = [];
    v.walk((i) => { if (!i._preview || i._preview.t >= 1) return; (wheelNames.has(i) ? W : O).push(i); });
    const pw = B.previewParts({ walk: (fn) => W.forEach(fn) }), po = B.previewParts({ walk: (fn) => O.forEach(fn) });
    const wheelHits = [];
    for (const a of pw) for (const b of po) {
      if (WHEEL_OK.test(b.n)) continue;
      const pen = QC.penetration(QC.obb(a), QC.obb(b));
      if (pen > 0.06) wheelHits.push(`${a.n} x ${b.n} ${pen.toFixed(2)}`);
    }
    console.log(`QC ${name}: zfight=${zf.length} wheelClips=${wheelHits.length}`);
    for (const h of zf.slice(0, 25)) console.log('   z', h.a, '|', h.b, h.area, h.at.join(','));
    for (const h of [...new Set(wheelHits)].slice(0, 25)) console.log('   w', h);
  }
  for (const [name, m] of Object.entries(dinos)) {
    const prof = animProfiles[name];
    if (!prof) continue;
    const rest = B.previewParts(m);
    const zf = QC.zFight(rest);
    const poses = [];
    for (const mode of ['Walk', 'Run']) for (let i = 0; i < 8; i++) poses.push({ name: `${mode}@${i / 8}`, parts: B.previewParts(m, RT.gaitPose(prof, mode, i / 8)) });
    for (const [an, a] of Object.entries(prof.Actions)) for (const [t] of a.Keys) poses.push({ name: `${an}@${t}`, parts: B.previewParts(m, RT.actionPose(prof, an, Math.max(t, 0.02))) });
    const adjacent = new Set();
    m.walk((i) => { if (i._isBone && i._parentBone) adjacent.add(i._parentBone.name + '>' + i.name); });
    const clips = QC.animatedClipping(rest, poses, { adjacent });
    console.log(`QC ${name}: zfight=${zf.length} animClips=${clips.length}`);
    for (const h of zf.slice(0, 20)) console.log('   z', h.a, '|', h.b, h.area, h.at.join(','));
    for (const c of clips.slice(0, 30)) console.log('   a', c.a, 'x', c.b, c.delta, c.pose);
  }
}

for (const [name, prof] of Object.entries(animProfiles)) {
  cineFrames(name, prof.Intro, prof.IntroShots);
  if (process.argv.includes('--allcine')) for (const k of ['Roar', 'Attack', 'Chase']) cineFrames(name, k === 'Chase' ? prof.Chase : k, k);
}
const total = dinoShowcase.count((i) => !!i._preview) + vehicleShowcase.count((i) => !!i._preview);
console.log(`showcase parts=${total}  ${previewOnly ? '(preview only)' : 'rbxmx written'}`);

// ---------------- TikTok recording sequences (baked against the maps above) ----------------
// separate process: a TikTok bake problem warns here instead of failing the whole build
if (!previewOnly) {
  try { require('child_process').execFileSync(process.execPath, [path.join(__dirname, 'tiktok.js')], { stdio: 'inherit' }); }
  catch (e) { console.log('WARNING: TikTok bake failed (node tools/gen/tiktok.js): ' + e.message); }
}
