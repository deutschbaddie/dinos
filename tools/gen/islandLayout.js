// BASE CAMP ISLANDS — the one source of truth for where everything sits (hub.js builds from it, the mockup
// draws from it). Hub-local coordinates: origin = plaza centre (world 600,0,0), north = -Z, angles in degrees
// clockwise from north. Each island's local frame: origin at the middle of its front shore (where its bridge
// lands), +Z runs away from the hub, +X is to your LEFT when you stand on the bridge looking out (the Roblox
// frame from yaw 180 - angle, same as the v1 plots).
//
//   north    the MAINLAND: cliffs, waterfalls and the ridge Brachiosaurus behind the Time Gate (kept from v1)
//   centre   the HUB island: plaza, ring road, Time Gate deck on its north tip
//   ring     eight player ISLANDS on an arc that leaves the north open, each joined to the hub by a bridge
//
// World boxes we must stay out of: Fern Valley's south cliff at world z -500 (hub-local z -500), Red Cliffs at
// world x >= 1680 (hub-local x >= 1080).

const ISLANDS = 8;
const HUB_R = 128;               // hub island shore radius (plaza 55, lawn ring to 85, ring road 85..103, beach)
// Islands are WEDGES of the ring (narrow where the bridge lands, wide at the back) with rounded corners, so the
// eight of them sit around the lagoon with even water channels between them.
const RF = 280, RB = 520;        // front / back shore radius from the hub centre
const HALF = 15;                 // angular half-width of an island (deg)
const ISLAND_D = RB - RF;
const ARC0 = 52, ARC1 = 308;     // first and last island angle (north stays open for the gate + mainland)
const ISLAND_R = (RF + RB) / 2;  // hub centre -> island centre
const BRIDGE_W = 22;             // two rover lanes + walkways
const WATER_Y = -1.2;            // lagoon surface (the hub grass sits at y 0.5)
const SEABED_Y = -16;
// the cliff shore behind the Time Gate: narrow at the gate, widening north (clear of islands 1 and 8)
const MAINLAND = [[-118, -212], [118, -212], [178, -300], [226, -420], [240, -480], [-240, -480], [-226, -420], [-178, -300]];

const rad = (d) => (d * Math.PI) / 180;
const dirOf = (deg) => [Math.sin(rad(deg)), -Math.cos(rad(deg))];
const islandAngle = (i) => ARC0 + i * ((ARC1 - ARC0) / (ISLANDS - 1));

// island i's frame: front-shore centre, yaw so local +Z points away from the hub
function islandFrame(i) {
  const a = islandAngle(i);
  const [dx, dz] = dirOf(a);
  return { angle: a, dir: [dx, dz], front: [dx * RF, 0, dz * RF], centre: [dx * ISLAND_R, 0, dz * ISLAND_R], yaw: 180 - a };
}
// island-local [x, z] -> hub-local [x, z]
function toHub(i, x, z) {
  const f = islandFrame(i);
  const [dx, dz] = f.dir;
  // local +Z = dir; local +X = (dz, -dx) (CFrame.Angles(0, 180 - a, 0) maps +X to (-cos a, -sin a))
  return [f.front[0] + dz * x + dx * z, f.front[2] - dx * x + dz * z];
}
// usable half-width of an island at local depth z (the sides are straight lines from the hub centre)
const halfWidth = (z, inset = 0) => (RF + z) * Math.tan(rad(HALF)) - inset;

// the island outline in island-local [x, z]: the sector, corners rounded (Chaikin), a gentle wobble
function outline(seed = 1, wobble = 0) {
  const pts = [];
  const arc = (r, a0, a1, n) => { for (let k = 0; k <= n; k++) { const a = rad(a0 + (a1 - a0) * (k / n)); pts.push([-r * Math.sin(a), r * Math.cos(a) - RF]); } };
  arc(RF, -HALF, HALF, 6);            // front shore (the one facing the hub)
  arc(RB, HALF, -HALF, 10);           // back shore
  let poly = pts;
  for (let it = 0; it < 4; it++) {
    const next = [];
    for (let k = 0; k < poly.length; k++) {
      const a = poly[k], b = poly[(k + 1) % poly.length];
      next.push([a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25], [a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75]);
    }
    poly = next;
  }
  if (wobble) {
    // a smooth, low-frequency bulge (a few lobes round the outline), never per-vertex noise: the outline must
    // stay simple so the ground rows (scanlines) and the beach offset stay clean
    const cx = 0, cz = ISLAND_D / 2;
    poly = poly.map(([x, z]) => {
      const th = Math.atan2(z - cz, x);
      const w = 1 + wobble * (0.6 * Math.sin(3 * th + seed) + 0.4 * Math.sin(5 * th + seed * 2.1));
      return [cx + (x - cx) * w, cz + (z - cz) * w];
    });
  }
  return poly;
}

// the bridge: from the hub's ring road out to the island's front shore
function bridge(i) {
  const f = islandFrame(i);
  const [dx, dz] = f.dir;
  const r0 = 96, r1 = RF + 8; // starts on the ring road, lands on the island's front lawn
  return { a: [dx * r0, dz * r0], b: [dx * r1, dz * r1], len: r1 - r0, span: RF - HUB_R, shore: [dx * HUB_R, dz * HUB_R], w: BRIDGE_W };
}

// ISLAND PLAN (island-local studs; rects are [x0, z0, x1, z1]; +X is the left-hand side seen from the bridge).
// Usable half-width grows from 66 at the front shore to 129 at the back (halfWidth(z, beach)).
//   front   bridge landing + name gate, cash pad, GARAGE (+X; its door faces the aisle, the rover rolls out and
//           straight onto the bridge), LODGE (-X)
//   middle  the HATCHERY on the centre aisle (more room than v1: 76 x 52), the TROPHY HALL (-X, a plinth for
//           every boss) and the first STAR PEN (+X)
//   back    the PADDOCK behind the hatchery (gate on the aisle), a long STAR PEN either side, and a SEA PEN
//           built out into the lagoon off the back shore (Mosasaurus and friends)
const PLAN = {
  beach: 9,
  landing: [-12, -8, 12, 14],
  nameGate: [0, 20],
  cashPad: [-16, 30],
  garage: [22, 24, 66, 62],                  // 44 x 38 (v1: 24 x 26); grows into a hangar for flying dinos
  lodge: [-68, 26, -30, 60],                 // your home on the island
  aisle: [-6, 14, 6, 118],
  hatchery: [-38, 64, 38, 114],              // 76 x 50 (v1: 60 x 40): 2 x 6 nests, a third row with the upgrade
  trophy: [-84, 68, -46, 112],
  paddock: [-60, 118, 60, 228],              // 120 x 110, as v1 (the companion props sit by its back wall)
  // the POWER TRAINER (2026-10-14): a training range in the front yard, right of the drive as you walk in, by the
  // cash pad. The machine (islandKit.js Trainer1..7) is built round TrainerAnchor; its range runs from the glowing
  // pad (by the drive) out toward the shore. rect = the lot it may fill; anchor = [x, z], yaw = which way its front
  // (the pad end) faces: -90 turns the kit's -Z toward +X, the drive.
  trainer: { rect: [-63, 10, -27, 26], anchor: [-45, 18], yaw: -90 },
  // the SHOWCASE PEDESTAL (2026-10-14): the owner's star dino on a turning stand, the first thing a visitor sees off
  // the bridge - left of the drive as you walk in (the trainer is on the right), clear of the garage (its walls start
  // at z 31) and its apron. islandKit.js Showcase is built round ShowcaseAnchor (a round plinth, radius 9.5); yaw 70
  // turns its front (the kit's -Z: the plaque) toward the bridge landing.
  showcase: { rect: [32, 5, 54, 27], anchor: [43, 16], yaw: 70 },
  star: [
    { id: 'StarA', kind: 'pen', rect: [46, 68, 84, 114] },     // medium: 38 x 46
    { id: 'StarB', kind: 'pen', rect: [-98, 122, -64, 222] },  // long: 34 x 100 (a T. rex walks its length)
    { id: 'StarC', kind: 'pen', rect: [64, 122, 98, 222] },
    { id: 'StarD', kind: 'sea', rect: [-40, 246, 40, 300] },   // out in the water past the back shore
  ],
};

module.exports = {
  ISLANDS, HUB_R, RF, RB, HALF, ISLAND_D, ARC0, ARC1, ISLAND_R, BRIDGE_W, WATER_Y, SEABED_Y, MAINLAND, PLAN,
  dirOf, islandAngle, islandFrame, toHub, halfWidth, outline, bridge,
};
