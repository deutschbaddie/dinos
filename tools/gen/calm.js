// Calm pass for Base Camp (tester feedback 2026-10-12: "very harmful to the eyes, overstimulating").
// Runs after buildHub(): no neon anywhere, lights dimmed, plaza stripes muted, glitter emitters softened.
// Kept out of hub.js so the layout author and the look pass never fight over the same lines.
const B = require('./builder.js');

const NEON = 288, SMOOTH = 272, GLASS = 1568;
const TILE = '#cbbb95'; // the plaza paving tone everything loud gets pulled toward
const STRIPES = new Set(['PlotSpoke', 'SpokeArrow', 'GateSpoke']);
const DROP = new Set(['HoloBeam']); // a 16-stud cyan light column in the middle of the plaza: just gone

function hex(rgb) { return B.rgbToHex ? B.rgbToHex(rgb) : '#' + rgb.map((v) => Math.round(v).toString(16).padStart(2, '0')).join(''); }
function mixRgb(a, b, t) { return a.map((v, i) => v + (b[i] - v) * t); }
function rgbOf(h) { h = h.replace('#', ''); return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)); }
// pull toward its own grey, then toward the paving tone, then a touch darker: reads as painted, not lit
function soften(rgb, toTile, sat = 0.45, dark = 0.9) {
  const g = (rgb[0] + rgb[1] + rgb[2]) / 3;
  let c = mixRgb(rgb, [g, g, g], sat);
  c = mixRgb(c, rgbOf(TILE), toTile);
  return c.map((v) => v * dark);
}
function setColor(p, rgb) {
  p.set('Color3uint8', 'Color3uint8', rgb.map((v) => Math.max(0, Math.min(255, Math.round(v)))));
  if (p._preview) p._preview.color = hex(rgb);
}

// (2026-10-12, the user: "make the time gate glow blue") the Time Gate is the one thing in camp that glows: its
// blue neon (membrane, node cores, guide lights, deck strips, coils) and its own lights are left as built
function blueish(rgb) { return rgb && rgb[2] > rgb[0] + 40 && rgb[2] >= rgb[1]; }
function calmHub(root) {
  const stats = { neon: 0, lights: 0, stripes: 0, emitters: 0, dropped: 0, gateGlow: 0 };
  const kill = [];
  const gate = new Set();
  const tg = root.find('TimeGate');
  if (tg) tg.walk((i) => gate.add(i));
  // (2026-10-14) the POWER TRAINER machines (IslandKit Trainer1..7) keep their glow: the user asked for a "glowing
  // pad" and neon on the top tiers - it's each island's showpiece. Their lights are authored soft, and nothing in
  // them blinks fast (TrainerView only pulses slowly).
  const trainer = new Set();
  root.walk((m) => { if (m.cls === 'Model' && /^Trainer\d+$/.test(m.name)) m.walk((i) => trainer.add(i)); });
  // (2026-10-14) the Egg Keeper's FUSION NEST keeps its amber glow too (the user asked for neon on it): small parts,
  // authored soft, and FusionView only breathes it slowly - bright only during its own cutscene
  root.walk((m) => { if (m.cls === 'Model' && m.name === 'FusionNest') m.walk((i) => trainer.add(i)); });
  root.walk((i) => {
    if (DROP.has(i.name)) { kill.push(i); return; }
    if (trainer.has(i)) return;
    const mat = i.props.Material;
    const col = i.props.Color3uint8;
    if (gate.has(i)) {
      if (mat && mat[1] === NEON && col && blueish(col[1])) { stats.gateGlow++; return; }
      if (i.cls === 'PointLight' || i.cls === 'SpotLight' || i.cls === 'SurfaceLight') return;
    }
    if (STRIPES.has(i.name) && col) {
      i.set('Material', 'token', SMOOTH);
      if (i._preview) i._preview.mat = 'SmoothPlastic';
      setColor(i, soften(col[1], 0.55, 0.4, 0.95));
      stats.stripes++;
      return;
    }
    if (mat && mat[1] === NEON) {
      const tags = i.tags || [];
      const glassy = /Window/.test(i.name) || tags.includes('PortalSurface') || tags.includes('PortalCore');
      i.set('Material', 'token', glassy ? GLASS : SMOOTH);
      if (i._preview) i._preview.mat = glassy ? 'Glass' : 'SmoothPlastic';
      if (col) setColor(i, soften(col[1], glassy ? 0.1 : 0.15, glassy ? 0.35 : 0.3, glassy ? 0.85 : 0.92));
      if (glassy) {
        const t = i.props.Transparency ? i.props.Transparency[1] : 0;
        i.set('Transparency', 'float', Math.max(t, 0.35));
      }
      stats.neon++;
      return;
    }
    if (i.cls === 'PointLight' || i.cls === 'SpotLight' || i.cls === 'SurfaceLight') {
      const b = i.props.Brightness ? i.props.Brightness[1] : 1;
      const r = i.props.Range ? i.props.Range[1] : 12;
      i.set('Brightness', 'float', +(b * 0.35).toFixed(3));
      i.set('Range', 'float', +(r * 0.7).toFixed(2));
      stats.lights++;
      return;
    }
    if (i.cls === 'ParticleEmitter') {
      i.set('LightEmission', 'float', 0);
      const rate = i.props.Rate ? i.props.Rate[1] : 5;
      i.set('Rate', 'float', +(rate * 0.5).toFixed(2));
      stats.emitters++;
    }
  });
  for (const k of kill) {
    if (k.parent) k.parent.children = k.parent.children.filter((c) => c !== k);
    stats.dropped++;
  }
  return stats;
}

// Garages are solid, sign and all (user 2026-10-13: "the camera goes through it"). Roblox's camera only pops in
// front of parts that collide, so every visible part of a garage model collides - except the flat floor paint
// (it would put bumps under the tyres) and the invisible gameplay markers.
// (lane-checked 2026-10-13 - rover driving raycasts collide too: the door handle stays put when the door rolls
// up, so it would be a kerb in the open doorway; the back-wall clutter overlaps a Titan Transport parked in the bay;
// the lift arms sit a hair off the drive lane. Those stay non-solid, and the roll-up door is left as it was.)
const GARAGE_MODELS = /^Garage(T\d)?$/;
const KEEP_SOFT = new Set(['DoorHandle', 'Pegboard', 'Tool', 'BenchLeg', 'Vise', 'Drawer', 'LiftArm']);
function solidGarages(root) {
  let n = 0;
  root.walk((m) => {
    if (m.cls !== 'Model' || !GARAGE_MODELS.test(m.name)) return;
    m.walk((i) => {
      if (!i._preview || !i.props.size || KEEP_SOFT.has(i.name)) return;
      for (let a = i.parent; a && a !== m; a = a.parent) if (a.name === 'RollerDoor') return;
      const t = i.props.Transparency ? i.props.Transparency[1] : 0;
      if (t >= 0.99) return; // markers (VehicleSpawn, RollOutPoint, prompt hosts...)
      const sz = i.props.size[1];
      if (Math.min(sz[0], sz[1], sz[2]) <= 0.1) return; // floor paint, hazard stripes
      if (i.props.CanCollide && i.props.CanCollide[1]) return;
      i.set('CanCollide', 'bool', true);
      n++;
    });
  });
  return n;
}

module.exports = { calmHub, solidGarages };
