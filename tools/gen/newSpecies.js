// New species (2026-10-12 roster expansion, see tools/gen/NEW_DINOS_BRIEF.md). Each one is loaded only if its
// files exist and build cleanly, so a species that is still being made never breaks everyone else's build.
//   dinos/<file>.js  -> rig + geometry (exports build())
//   anim/<file>.js   -> animation profile (Signature / Intro / IntroShots / Gait / Actions)
// Group files (one per era, so parallel work never edits the same file):
//   anim/shots_<group>.js     -> signature shot lists (unique keys)
//   showcase_<group>.js       -> { SLOTS } extra showcase slots (cinematic QC stages)
const fs = require('fs');
const path = require('path');

const SPECIES = {
  // Red Cliffs
  Oviraptor: 'oviraptor', Protoceratops: 'protoceratops', Gallimimus: 'gallimimus', Therizinosaurus: 'therizinosaurus',
  // Frost Forest
  Microraptor: 'microraptor', Psittacosaurus: 'psittacosaurus', Compy: 'compy', Yutyrannus: 'yutyrannus',
  // Dawn Desert
  Coelophysis: 'coelophysis', Plateosaurus: 'plateosaurus', Dilophosaurus: 'dilophosaurus', Postosuchus: 'postosuchus',
  // Spine River (Croc Creek)
  Sarcosuchus: 'sarcosuchus',
};
const GROUPS = ['redcliffs', 'frostforest', 'dawndesert', 'spineriver'];

function tryRequire(rel) {
  const p = path.join(__dirname, rel);
  if (!fs.existsSync(p)) return null;
  try { return require(p); } catch (e) { console.log(`WARNING: ${rel} failed to load: ${e.message}`); return null; }
}

// { dinoMods, animProfiles } for every new species whose files exist and load
function load() {
  const dinoMods = {}, animProfiles = {};
  for (const [name, file] of Object.entries(SPECIES)) {
    const d = tryRequire(`dinos/${file}.js`);
    const a = tryRequire(`anim/${file}.js`);
    if (!d || !a) continue;
    // build once to make sure the rig is sound; build.js calls build() again for real
    try { d.build(); } catch (e) { console.log(`WARNING: ${name} rig failed to build: ${e.message}`); continue; }
    dinoMods[name] = d;
    animProfiles[name] = a;
  }
  return { dinoMods, animProfiles };
}
function shots() {
  const out = {};
  for (const g of GROUPS) Object.assign(out, tryRequire(`anim/shots_${g}.js`) || {});
  return out;
}
function showcaseSlots() {
  const out = {};
  for (const g of GROUPS) { const m = tryRequire(`showcase_${g}.js`); if (m && m.SLOTS) Object.assign(out, m.SLOTS); }
  return out;
}
module.exports = { SPECIES, GROUPS, load, shots, showcaseSlots, tryRequire };
