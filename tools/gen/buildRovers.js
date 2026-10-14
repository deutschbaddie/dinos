// Rovers only: gameplay vehicle templates + build-your-own kits (no maps).  node tools/gen/buildRovers.js
// The full build (build.js) writes the same files; this exists so rover work never regenerates the maps.
const fs = require('fs');
const path = require('path');
const B = require('./builder.js');
const QCR = require('./qc.js');
const { buildTemplate } = require('./vehicleTemplate.js');
const { buildKits } = require('./vehicles/kits.js');

const ROOT = path.resolve(__dirname, '../..');
const write = (rel, s) => { const p = path.join(ROOT, rel); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, s); };
const mods = {
  RookieRanger: require('./vehicles/rookieRanger.js'),
  RaptorRunner: require('./vehicles/raptorRunner.js'),
  TitanTransport: require('./vehicles/titanTransport.js'),
};
for (const [name, mod] of Object.entries(mods)) {
  const v = mod.build();
  QCR.resolveZFight(v);
  const t = buildTemplate(v, name);
  write(`src/ReplicatedStorage/DinoExpedition/Vehicles/${name}.rbxmx`, B.toRbxmx(t));
  const kits = buildKits(t, name);
  write(`src/ReplicatedStorage/DinoExpedition/RoverKits/${name}.rbxmx`, B.toRbxmx(kits));
  let n = 0; kits.walk((i) => { if (i._preview) n++; });
  console.log(`${name.padEnd(16)} template + ${n} kit parts written`);
}
