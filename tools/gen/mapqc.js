// Map clipping QC + auto-fix.
// Classifies every part as GROUND (walkable surfaces, decals), DECOR (self-contained props: trees, bushes,
// rocks, lamps, flowers...) or STRUCT (buildings, fences, signs, gate...). Then:
//   - DECOR units that cut into STRUCT parts, roads, or other DECOR units are pruned (or reported)
//   - STRUCT parts of different owners that interpenetrate are reported for a manual fix
const { obb, penetration } = require('./qc.js');

const DECOR_UNITS = new Set(['JungleTree', 'PalmTree', 'Bush', 'Fern', 'Flowers', 'Rock', 'TreeFern', 'LampPost', 'Pond', 'Waterfall', 'Cycad', 'Araucaria', 'Sequoia', 'StillPool', 'Reeds', 'Mangrove']);
const GROUND = /^(Hill|HillTop|HillSide|Grass|PaddockGround|DirtPatch|GrassPatch|Road|RoadJoint|Rut|RingRoad|RingRoadEdge|Lawn|LawnCurb|Plaza\w*|PlotPad|PlotEdge|Driveway|Walkway|GateWalk|GateRoad|Tile|PlotSpoke|SpokeArrow|GateSpoke|PenGrass|Clearing|RiverBank|RiverWater|Ford|FordStone|LakeShore|LakeWater|Scuff|Deck|DeckTop|DriveLane|HazardEdge|HazardStripe|GuideLight|GarageFloor|ParkLine|ShedFloor|Foundation|Steps|SpawnPad|PondBed|PondWater|GorgeWater|LilyPad|Shelf|CliffTop|Strata|Ledge|Moss|Overhang|Vine|Ridge|RidgeTop|MountainTier|Volcano|Crater|HoloBase\w*|RevealPad\w*|Stage\w*|TurntableBase|Turntable\w*|KioskFloor|NestPad|NestInner|NestBed|Straw|SwellTop|SwellSide|FarMesa|Peak|MesaLayer|MesaTop|MesaScrub|HoodooRock|HoodooCap|GorgeSand|GorgeVertebra|ArchVertebra|MudPlate|MudCrack|ShoreMud|PoolShore|PoolWater|GameTrail|GiantPrint|ThroneGrass|NestMound|Seabed|HubShelf|HubWetSand|HubBeach|IslandShelf|WetSand|IslandBeach|IslandGrass|MainlandShelf|MainlandBeach|MainlandGrass|BridgeDeck|BridgeLine|BridgeCurb|LotDirt|GatePier|GatePierButtress|TowerFoot|HallFloor|HallSteps|Dais|PorchDeck|PorchStep|LodgeFloor|PierCap|Footpath)$/;

// opts.decor = extra decor unit Model names, opts.ground = extra walkable part-name regex (new eras pass mod.QC)
function partsOf(root, opts = {}) {
  const out = [];
  const extraDecor = new Set(opts.decor || []);
  const isGround = (n) => GROUND.test(n) || (opts.ground ? opts.ground.test(n) : false);
  const rec = (inst, unit, owner) => {
    let u = unit, o = owner;
    if (inst.cls === 'Model' && (DECOR_UNITS.has(inst.name) || extraDecor.has(inst.name)) && !u) u = inst;
    if (!u && /^(GrassTuft)$/.test(inst.name)) u = inst; // loose tufts are their own little unit
    if ((inst.cls === 'Model' || inst.cls === 'Folder') && !u) o = inst;
    if (inst._preview && !inst._isBone && inst._preview.t < 1 && inst.cls !== 'SpawnLocation') {
      const s = inst._preview.size;
      const cf = inst._cf;
      const p = { k: inst._preview.kind, s, cf: [cf.x, cf.y, cf.z, ...cf.r], n: inst.name, inst };
      const O = obb(p);
      if (p.k === 'cyl' || p.k === 'ball' || p.k === 'ellipsoid') { O.h = O.h.map((v, k) => (p.k === 'cyl' && k === 0) ? v : v * 0.78); O.r = Math.hypot(...O.h); }
      const ext = [0, 1, 2].map((k) => O.h[0] * Math.abs(O.ax[0][k]) + O.h[1] * Math.abs(O.ax[1][k]) + O.h[2] * Math.abs(O.ax[2][k]));
      out.push({
        inst, O, name: inst.name, unit: u, owner: o,
        cls: u ? 'DECOR' : (isGround(inst.name) || Math.min(...s) < 0.12 ? 'GROUND' : 'STRUCT'),
        min: [0, 1, 2].map((k) => O.c[k] - ext[k]), max: [0, 1, 2].map((k) => O.c[k] + ext[k]),
        collide: inst.props.CanCollide && inst.props.CanCollide[1],
      });
    }
    for (const c of inst.children) rec(c, u, o);
  };
  rec(root, null, root);
  return out;
}

function grid(parts, cell = 16) {
  const g = new Map();
  parts.forEach((p, i) => {
    for (let x = Math.floor(p.min[0] / cell); x <= Math.floor(p.max[0] / cell); x++)
      for (let z = Math.floor(p.min[2] / cell); z <= Math.floor(p.max[2] / cell); z++) {
        const k = x + ',' + z;
        if (!g.has(k)) g.set(k, []);
        g.get(k).push(i);
      }
  });
  return g;
}

function aabbHit(a, b) {
  for (let k = 0; k < 3; k++) if (a.max[k] < b.min[k] || b.max[k] < a.min[k]) return false;
  return true;
}

// opts: { pruneDecor: true, decorPen: 0.3, structPen: 0.25, roads: [{x,z,r}]? }
function check(root, opts = {}) {
  const parts = partsOf(root, opts);
  const g = grid(parts);
  const decorHits = new Map(); // unit -> reason
  const structHits = [];
  const seen = new Set();
  for (const bucket of g.values()) {
    for (let a = 0; a < bucket.length; a++) for (let b = a + 1; b < bucket.length; b++) {
      const i = bucket[a], j = bucket[b];
      const key = i < j ? i + ':' + j : j + ':' + i;
      if (seen.has(key)) continue;
      seen.add(key);
      const A = parts[i], B = parts[j];
      if (A.cls === 'GROUND' && B.cls === 'GROUND') continue;
      if (!aabbHit(A, B)) continue;
      // decor vs anything solid
      if (A.cls === 'DECOR' || B.cls === 'DECOR') {
        const D = A.cls === 'DECOR' ? A : B, O = D === A ? B : A;
        if (O.unit === D.unit) continue;
        if (/^(Pond|Waterfall)$/.test(D.unit.name) && O.cls === 'GROUND') continue; // pools are sunk into the ground on purpose
        // trees / bushes / ferns must not grow through a cliff face or the side of a taller hill column
        const wall = /^(Strata|CliffTop|Ledge|Overhang|HillSide|SwellSide|MesaLayer|MesaTop|HoodooRock)$/.test(O.name);
        if (wall && !/^(Pond|Waterfall|StillPool|Rock)$/.test(D.unit.name)) {
          const pw = penetration(D.O, O.O);
          if (pw > 0.8) { if (!decorHits.has(D.unit)) decorHits.set(D.unit, `${D.name} x ${O.name} (${pw.toFixed(2)})`); }
          continue;
        }
        if (O.cls === 'GROUND' && !/^(Road|RoadJoint|Walkway|GateWalk|GateRoad|Driveway|DriveLane|Deck|DeckTop|RingRoad|PlotPad|PenGrass|Ford|RiverWater|LakeWater|PondWater|BridgeDeck)$/.test(O.name)) continue;
        if (O.cls === 'DECOR' && !(/LampPost|Rock/.test(O.unit.name) || /LampPost|Rock/.test(D.unit.name))) continue;
        const pen = penetration(D.O, O.O);
        // roads/paths: anything sitting on top of a walkable surface counts if it pokes into its footprint above
        const onSurface = O.cls === 'GROUND' && D.O.c[1] > O.max[1] - 0.05;
        if (pen > (opts.decorPen || 0.3) || (onSurface && pen > 0.05)) {
          const victim = (O.cls === 'DECOR' && /LampPost/.test(O.unit.name)) ? D.unit : D.unit;
          if (!decorHits.has(victim)) decorHits.set(victim, `${D.name} x ${O.name} (${pen.toFixed(2)})`);
        }
        continue;
      }
      // structure vs structure, different owners
      const fence = (P) => /^Fence(Post|Rail)$/.test(P.name);
      const fenceClash = A.cls === 'STRUCT' && B.cls === 'STRUCT' && A.owner === B.owner && fence(A) !== fence(B);
      if (fenceClash || (A.cls === 'STRUCT' && B.cls === 'STRUCT' && A.owner !== B.owner)) {
        const pen = penetration(A.O, B.O);
        if (pen > (opts.structPen || 0.25)) structHits.push({ a: `${A.owner.name}/${A.name}`, b: `${B.owner.name}/${B.name}`, pen: +pen.toFixed(2), at: A.O.c.map((v) => +v.toFixed(1)) });
      }
    }
  }
  let pruned = 0;
  if (opts.pruneDecor !== false) {
    for (const unit of decorHits.keys()) {
      const par = unit.parent;
      if (!par) continue;
      const ix = par.children.indexOf(unit);
      if (ix >= 0) { par.children.splice(ix, 1); pruned++; }
    }
  }
  return { decor: [...decorHits.entries()].map(([u, r]) => `${u.name}: ${r}`), struct: structHits, pruned };
}

module.exports = { check };

// Road clearance: nothing solid may stand in the rover's lane, and nothing tall may block the view down it.
// roads: [{ x, z, y, hw }] world samples (y = road surface, hw = half road width). Units listed in DECOR_UNITS
// (and loose props) that intrude are removed; anything else is returned so the generator can be fixed.
const ROAD_KEEP = /^(ArrivalPortal|ReturnPortal|Roads|JumpLip|Kicker|Obstacles)$/;
// (not the big set pieces: hoodoos, ledges, standing stones are collidable and only reported)
const STONEY = /^(?!Hoodoo|Ledge|Standing|Arch)\w*(Stone|Pebble|Rubble|Boulder|Rock|EdgeLog|VergeLog)$/;
function clearRoad(root, roads, opts = {}) {
  const lane = opts.margin === undefined ? 2.5 : opts.margin; // rover body reaches ~2.5 past its centre clamp
  const clear = opts.clear || 11; // headroom above the road surface
  const parts = partsOf(root, opts);
  const cell = 24;
  const rg = new Map();
  for (const r of roads) {
    const k = Math.floor(r.x / cell) + ',' + Math.floor(r.z / cell);
    if (!rg.has(k)) rg.set(k, []);
    rg.get(k).push(r);
  }
  const kept = (inst) => { for (let i = inst; i; i = i.parent) if (ROAD_KEEP.test(i.name)) return true; return false; };
  const removeUnits = new Set(), removeParts = new Set(), report = [];
  for (const p of parts) {
    // stones / logs / rubble never belong on the road, however flat or wherever they're grouped (2026-10-12: verge
    // stones grouped under Roads were exempt and landed on the road at bends and forks; flat ford stones were "ground")
    const stoney = STONEY.test(p.name);
    if (p.cls === 'GROUND' && !p.collide && !stoney) continue;
    if (/^(Road|RoadJoint|Rut|Vine|Hill\w*|Swell\w*|Grass|GrassPatch|GroundPatch|Clearing|SaltCrust|SaltSeam|Shelf|GameTrail|Track\w*|Scuff|Trample|MudPuddle|Tile|Slipway|LilyPad|LilyFlower|Kelp|CrossBeam)$/.test(p.name)) continue;
    const tall = p.max[1] - p.min[1];
    // only paper-thin decals may sit in the lane (a thin fern leaf is still a plant on the road: units go whole)
    if (!p.collide && tall < 0.45 && !p.unit && !stoney) continue;
    if (kept(p.inst) && !stoney) continue;
    const cx = (p.min[0] + p.max[0]) / 2, cz = (p.min[2] + p.max[2]) / 2;
    const rad = Math.hypot(p.max[0] - p.min[0], p.max[2] - p.min[2]) / 2;
    let hit = null;
    const reach = Math.ceil((rad + 20) / cell);
    if (stoney && (!p.collide || rad < 3)) {
      // a stone just needs to look like it's on the road: its footprint reaching within 0.6 of any lane's edge
      for (let ix = Math.floor(cx / cell) - reach; ix <= Math.floor(cx / cell) + reach && !hit; ix++) {
        for (let iz = Math.floor(cz / cell) - reach; iz <= Math.floor(cz / cell) + reach && !hit; iz++) {
          for (const r of rg.get(ix + ',' + iz) || []) {
            if (p.max[1] <= r.y + 0.15 || p.min[1] >= r.y + clear) continue;
            if (Math.hypot(r.x - cx, r.z - cz) - rad < r.hw + 0.6) { hit = r; break; }
          }
        }
      }
    }
    for (let ix = Math.floor(cx / cell) - reach; ix <= Math.floor(cx / cell) + reach && !hit; ix++) {
      for (let iz = Math.floor(cz / cell) - reach; iz <= Math.floor(cz / cell) + reach && !hit; iz++) {
        for (const r of rg.get(ix + ',' + iz) || []) {
          const w = r.hw + (p.collide ? lane : (stoney ? 0.8 : 0));
          // cheap reject on the AABB, then the real box: distance from the part's oriented box to points up the
          // lane's centre line (surface + 1 .. headroom) must stay beyond the lane half-width
          const dx = Math.max(p.min[0] - r.x, 0, r.x - p.max[0]), dz = Math.max(p.min[2] - r.z, 0, r.z - p.max[2]);
          if (Math.hypot(dx, dz) >= w) continue;
          if (p.max[1] <= r.y + (stoney ? 0.15 : 0.35) || p.min[1] >= r.y + clear) continue;
          const O = p.O;
          let inside = false;
          for (let hy = 0.6; hy <= clear && !inside; hy += 2.1) {
            const q = [r.x - O.c[0], r.y + hy - O.c[1], r.z - O.c[2]];
            let d2 = 0, dv = 0;
            for (let k = 0; k < 3; k++) {
              const pr = q[0] * O.ax[k][0] + q[1] * O.ax[k][1] + q[2] * O.ax[k][2];
              const ex = Math.max(0, Math.abs(pr) - O.h[k]);
              // vertical axis distance doesn't widen the lane: measure it separately
              const vert = Math.abs(O.ax[k][1]);
              d2 += ex * ex * (1 - vert);
              dv += ex * vert;
            }
            if (Math.sqrt(d2) < w && dv < 1.05) inside = true;
          }
          if (!inside) continue;
          hit = r;
          break;
        }
      }
    }
    if (!hit) continue;
    if (p.unit) removeUnits.add(p.unit);
    else if ((opts.removeParts && opts.removeParts.test(p.name)) || (stoney && !p.collide)) removeParts.add(p.inst);
    else report.push(`${p.owner.name}/${p.name} @ ${[cx, (p.min[1] + p.max[1]) / 2, cz].map((v) => v.toFixed(1)).join(',')}`);
  }
  const drop = (inst) => { const par = inst.parent; if (!par) return false; const ix = par.children.indexOf(inst); if (ix < 0) return false; par.children.splice(ix, 1); return true; };
  let n = 0;
  for (const u of removeUnits) if (drop(u)) n++;
  for (const pi of removeParts) if (drop(pi)) n++;
  return { removed: n, report: [...new Set(report)] };
}

module.exports.clearRoad = clearRoad;
