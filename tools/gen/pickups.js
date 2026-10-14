// PICKUPS — things that drop in the world for you to walk over and pick up (the pickup animation is reused).
// BossKey_<RulerId>: a chunky golden key with the ruler's emblem and gem. Frame: shaft along +X from the bow,
// key standing on its edge (bow up when spun on Y), origin = the key's middle. PrimaryPart "KeyRoot";
// attachment "Grip" (on KeyRoot) is where a hand holds it.
const { Inst, Ctx, CF } = require('./builder.js');

const GOLD = '#ffc824', GOLD_HI = '#ffe27a', GOLD_LO = '#c98a10';

const KEYS = {
  TyrantKing: { gem: '#ff6a1f', plate: '#7a1f22', emblem: 'tooth', name: 'TYRANT KING KEY' },
  Titan: { gem: '#2ee6c8', plate: '#0f4a46', emblem: 'plate', name: 'TITAN KEY' },
  Tidebreaker: { gem: '#46afeb', plate: '#123c5a', emblem: 'tooth', name: 'TIDEBREAKER KEY' },
  Scythe: { gem: '#f0e2c4', plate: '#6a2a18', emblem: 'tooth', name: 'SCYTHE KING KEY' },
  Frostfang: { gem: '#bfe6ff', plate: '#1e3a5a', emblem: 'tooth', name: 'FROSTFANG KEY' },
  DawnKing: { gem: '#ff7846', plate: '#4a1a14', emblem: 'plate', name: 'DAWN KING KEY' },
};

function buildKey(id) {
  const k = KEYS[id];
  const m = new Inst('Model', 'BossKey_' + id);
  m.attr('Boss', id).attr('DisplayName', k.name);
  const c = new Ctx({ parent: m, frame: new CF(), defaults: { anchored: true } });
  const root = c.box({ name: 'KeyRoot', s: [0.4, 0.4, 0.4], p: [0, 0, 0], t: 1, shadow: false });
  m.set('PrimaryPart', 'Ref', root);
  // bow: an octagon ring, thick and toy-like
  const bx = -1.15, R = 0.78;
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * 360 + 22.5;
    const rad = (a * Math.PI) / 180;
    c.at([bx + Math.cos(rad) * R, Math.sin(rad) * R, 0], [0, 0, a + 90]).box({ name: 'Bow', s: [0.66, 0.3, 0.34], c: i % 2 ? GOLD : GOLD_HI, refl: 0.25 });
  }
  // emblem inside the bow
  c.cyl({ name: 'BowPlate', axis: 'z', len: 0.18, d: 1.12, p: [bx, 0, 0], c: k.plate });
  if (k.emblem === 'tooth') {
    // a T. rex tooth: tall diamond, bone white, with the ruler's gem at its root
    c.at([bx, 0.08, 0], [0, 0, 45]).box({ name: 'Emblem', s: [0.46, 0.46, 0.26], c: '#fbf6e6' });
    c.at([bx, -0.26, 0], [0, 0, 45]).box({ name: 'Emblem', s: [0.3, 0.3, 0.27], c: '#fbf6e6' });
  } else {
    // a titan's back plate: stacked chevrons
    for (let i = 0; i < 3; i++) c.at([bx, -0.22 + i * 0.22, 0], [0, 0, 45]).box({ name: 'Emblem', s: [0.34 - i * 0.07, 0.34 - i * 0.07, 0.26], c: i === 1 ? '#bff7ec' : '#e6fffa' });
  }
  c.ball({ name: 'Gem', d: 0.3, p: [bx, -0.02, 0.17], c: k.gem, m: 'Neon' });
  c.ball({ name: 'Gem', d: 0.3, p: [bx, -0.02, -0.17], c: k.gem, m: 'Neon' });
  // collar + shaft
  c.cyl({ name: 'Collar', len: 0.26, d: 0.56, p: [bx + R + 0.18, 0, 0], c: GOLD_LO, refl: 0.25 });
  c.cyl({ name: 'Collar', len: 0.16, d: 0.66, p: [bx + R + 0.4, 0, 0], c: GOLD_HI, refl: 0.25 });
  c.box({ name: 'Shaft', s: [2.1, 0.3, 0.3], p: [0.85, 0, 0], c: GOLD, refl: 0.25 });
  // the bit: chunky teeth hanging under the shaft's end
  c.box({ name: 'Bit', s: [0.34, 0.62, 0.3], p: [1.62, -0.42, 0], c: GOLD, refl: 0.25 });
  c.box({ name: 'Bit', s: [0.3, 0.38, 0.3], p: [1.22, -0.3, 0], c: GOLD_HI, refl: 0.25 });
  c.box({ name: 'Bit', s: [0.22, 0.24, 0.3], p: [1.84, -0.82, 0], c: GOLD_LO, refl: 0.25 });
  c.box({ name: 'ShaftCap', s: [0.2, 0.42, 0.42], p: [1.95, 0, 0], c: GOLD_HI, refl: 0.25 });
  // where a hand holds it: just behind the collar
  const grip = new Inst('Attachment', 'Grip');
  grip.set('CFrame', 'CFrame', root._cf.inv().mul(new CF(bx + R + 0.55, 0, 0)));
  root.add(grip);
  return m;
}

function buildPickups() {
  const f = new Inst('Folder', 'Pickups');
  for (const id of Object.keys(KEYS)) f.add(buildKey(id));
  return f;
}

module.exports = { buildPickups, buildKey, KEYS };

// standalone: node tools/gen/pickups.js  (writes the models + a preview group)
if (require.main === module) {
  const fs = require('fs');
  const path = require('path');
  const B = require('./builder.js');
  const ROOT = path.resolve(__dirname, '../..');
  const dir = path.join(ROOT, 'src/ReplicatedStorage/DinoExpedition/Pickups');
  fs.mkdirSync(dir, { recursive: true });
  const groups = [];
  let x = 0;
  for (const id of Object.keys(KEYS)) {
    const m = buildKey(id);
    fs.writeFileSync(path.join(dir, `BossKey_${id}.rbxmx`), B.toRbxmx(m));
    const c = B.cloneTree(m);
    B.transformTree(c, new CF(x, 2, 0));
    groups.push(...B.previewParts(c));
    x += 5;
  }
  fs.writeFileSync(path.join(ROOT, 'tools/preview/out/pickups.json'), JSON.stringify({ groups: [{ name: 'Keys', parts: groups }] }));
  console.log('pickups written');
}
