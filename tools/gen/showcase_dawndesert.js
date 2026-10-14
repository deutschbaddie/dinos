// Dawn Desert QC stages (showcase row z = -335): an oasis for the Coelophysis pack, a cycad for the Plateosaurus,
// crest rocks for the Dilophosaurus pair and a dry mud wash for the Postosuchus. Each slot's props are
// CinematicProps the signature breaks (BreakProp) so the cutscene can be checked in tools/preview/cine.html.
const { CF } = require('./cframe.js');
const { rng } = require('./builder.js');

const SAND = '#e3a560', SANDLO = '#c9844a', CLAY = '#b8573a', CLAYLO = '#93432c', MUD = '#6b4630', MUDLO = '#563726', DRY = '#8c6a48';
const TEAL = '#3fb8c8', REED = '#6f9a3a', REEDLO = '#58802c', BONE = '#efe4c8', BONELO = '#d6c7a2', WOOD = '#7a5a3a', WOODLO = '#5e4430';

// place a clone of the display's own creature (a pack-mate / partner) at display-local x, z, yaw
function mate(H, c, top, name, scale, x, z, yaw) {
  const m = H.cloneTree(H.dino);
  H.transformTree(m, c.frame.inv());
  H.transformTree(m, new CF(0, -top, 0));
  H.scaleTree(m, scale);
  H.placeAt(m, x, z, yaw, top);
  H.transformTree(m, c.frame);
  m.name = name;
  m.attr('HerdLeader', H.dino.name).attr('AnimScale', scale).attr('DisplayName', H.dino.attrs.DisplayName);
  H.disp.add(m);
  return m;
}
const yawTo = (x, z, tx, tz) => Math.atan2(-(tx - x), -(tz - z)) * 180 / Math.PI; // yaw so -Z faces (tx, tz)

function reeds(c, x, z, top, n, h, seed) {
  const R = rng(seed);
  for (let i = 0; i < n; i++) {
    const k = h * (0.7 + R() * 0.5);
    c.box({ name: 'Horsetail', s: [0.22, k, 0.22], p: [x + (R() - 0.5) * 1.2, top + k / 2, z + (R() - 0.5) * 1.2], r: [R() * 14 - 7, R() * 90, R() * 14 - 7], c: i % 2 ? REED : REEDLO });
    if (i % 2 === 0) c.box({ name: 'HorsetailTip', s: [0.3, 0.3, 0.3], p: [x + (R() - 0.5) * 1.2, top + k + 0.1, z + (R() - 0.5) * 1.2], c: '#9a7a3a' });
  }
}
function redRock(c, x, z, top, k, seed, name = 'RedRock') {
  const R = rng(seed);
  const g = c.at([x, top, z], [0, R() * 360, 0]);
  g.box({ name, s: [2.2 * k, 1.5 * k, 1.8 * k], p: [0, 0.7 * k, 0], r: [R() * 8, 0, R() * 10], c: CLAY, m: 'Sandstone' });
  g.box({ name, s: [1.4 * k, 1.0 * k, 1.3 * k], p: [0.9 * k, 0.45 * k, 0.6 * k], r: [0, 30, R() * 12], c: CLAYLO, m: 'Sandstone' });
  g.box({ name: name + 'Band', s: [2.24 * k, 0.25 * k, 1.84 * k], p: [0, 0.95 * k, 0], r: [R() * 8, 0, R() * 10], c: '#e8d2b0', m: 'Sandstone' });
}

const SLOTS = {
  // ---------------- COELOPHYSIS: the oasis ----------------
  Coelophysis: {
    pos: [-62, -335], yaw: 180, radius: 9.5,
    build(c, top, H) {
      // the pool behind it (it drinks with its back to the audience), a sandy rim, horsetails
      c.box({ name: 'OasisBed', s: [5.0, 0.06, 3.6], p: [0, top + 0.03, 5.8], c: '#2a6f6a' });
      c.box({ name: 'OasisWater', s: [4.8, 0.1, 3.4], p: [0, top + 0.08, 5.8], c: TEAL, t: 0.25, refl: 0.12, shadow: false });
      const R = rng(215);
      for (let i = 0; i < 12; i++) {
        const a = (i / 12) * Math.PI * 2, s = 0.6 + R() * 0.35;
        c.box({ name: 'OasisRim', s: [s * 1.2, s * 0.45, s], p: [Math.cos(a) * 2.75, top + s * 0.2, 5.8 + Math.sin(a) * 2.0], r: [0, R() * 60, 0], c: i % 3 ? SAND : SANDLO, m: 'Sandstone' });
      }
      reeds(c, 3.3, 8.7, top, 6, 2.6, 21);
      reeds(c, -1.6, 9.3, top, 5, 2.2, 22);
      // the perch it leaps onto, with loose pebbles that scatter when it lands
      const perch = c.at([0.1, top, -3.1], [0, 12, 0]);
      perch.box({ name: 'PerchRock', s: [2.6, 1.1, 2.2], p: [0, 0.55, 0], c: CLAY, m: 'Sandstone', collide: true });
      perch.box({ name: 'PerchBand', s: [2.64, 0.22, 2.24], p: [0, 0.75, 0], c: '#e8d2b0', m: 'Sandstone' });
      perch.box({ name: 'PerchRock', s: [1.3, 0.8, 1.2], p: [1.5, 0.4, 0.6], r: [0, 25, 0], c: CLAYLO, m: 'Sandstone' });
      const [, pb] = H.propModel(c, 'Pebbles');
      for (const [x, z, s] of [[-0.8, -3.6, 0.3], [0.9, -2.5, 0.26], [-0.5, -2.4, 0.22], [0.7, -3.8, 0.24]]) pb.box({ name: 'Pebble', s: [s, s * 0.8, s], p: [x, top + 1.1 + s * 0.4, z], r: [0, x * 50, 0], c: '#d9c29a', m: 'Slate' });
      // the reeds its tail whips through as it spins round
      const [, rd] = H.propModel(c, 'Reeds');
      reeds(rd, 3.5, -1.0, top, 7, 2.8, 23);
      // the pack drinking along the banks
      mate(H, c, top, 'CoelophysisPackmate1', 0.85, -5.3, 5.4, yawTo(-5.3, 5.4, 0, 5.4));
      mate(H, c, top, 'CoelophysisPackmate2', 0.85, 5.3, 6.4, yawTo(5.3, 6.4, 0, 6.4));
      mate(H, c, top, 'CoelophysisPackmate3', 0.8, -3.4, 8.4, yawTo(-3.4, 8.4, 0, 5.8));
    },
  },
  // ---------------- PLATEOSAURUS: the tall cycad ----------------
  Plateosaurus: {
    pos: [-4, -335], yaw: 180, radius: 14,
    build(c, top, H) {
      // a tall cycad in front-right: its trunk stays, its crown is stripped bare (CycadCrown breaks)
      const tx = 4.0, tz = -3.0, th = 13.6;
      for (let i = 0; i < 9; i++) {
        const w = 1.5 - i * 0.04, y = top + 0.75 + i * (th / 9);
        c.box({ name: 'CycadTrunk', s: [w, th / 9 + 0.05, w], p: [tx + Math.sin(i * 0.6) * 0.08, y, tz], r: [0, i * 23, 0], c: i % 2 ? '#7a5a34' : '#8c6a3e', studs: 'sides' });
        if (i % 2 === 0) c.box({ name: 'CycadScale', s: [w + 0.08, 0.3, w + 0.08], p: [tx, y - 0.4, tz], r: [0, 45 + i * 23, 0], c: '#5e4426' });
      }
      const [, cr] = H.propModel(c, 'CycadCrown');
      const ctop = top + th + 0.4;
      cr.box({ name: 'CrownCore', s: [1.6, 1.0, 1.6], p: [tx, ctop, tz], c: '#6a7a2a', studs: 'top' });
      cr.box({ name: 'CrownCone', s: [0.9, 0.9, 0.9], p: [tx, ctop + 0.8, tz], r: [0, 45, 0], c: '#c9a548' });
      for (let i = 0; i < 9; i++) {
        const f = cr.at([tx, ctop + 0.2, tz], [0, i * 40 + 10, 0]);
        f.box({ name: 'CycadFrond', s: [0.8, 0.18, 2.6], p: [0, 0.3, -1.4], r: [24, 0, 0], c: i % 2 ? '#4f9a3a' : '#3f8a32', studs: 'top' });
        f.box({ name: 'CycadFrondTip', s: [0.65, 0.16, 1.8], p: [0, -0.35, -3.3], r: [-22, 0, 0], c: '#3a7a2e' });
      }
      // a short cycad and ferns at the back, scattered red rocks, fallen fronds on the sand
      for (let i = 0; i < 4; i++) c.box({ name: 'CycadTrunk', s: [1.2, 1.2, 1.2], p: [-7.5, top + 0.6 + i * 1.2, 7.0], r: [0, i * 30, 0], c: i % 2 ? '#7a5a34' : '#8c6a3e', studs: 'sides' });
      for (let i = 0; i < 6; i++) c.at([-7.5, top + 5.0, 7.0], [0, i * 60, 0]).box({ name: 'CycadFrond', s: [0.7, 0.16, 2.4], p: [0, 0, -1.3], r: [20, 0, 0], c: i % 2 ? '#4f9a3a' : '#3f8a32', studs: 'top' });
      redRock(c, 8.5, 5.5, top, 1.3, 31);
      redRock(c, -9.5, -4.0, top, 1.0, 32);
      H.fern(c, [7.5, top, -1.0], 1.2, 33);
      H.fern(c, [-6.5, top, 2.5], 1.1, 34);
    },
  },
  // ---------------- DILOPHOSAURUS: crest rocks, a dead snag, its partner ----------------
  Dilophosaurus: {
    pos: [-36, -335], yaw: 180, radius: 9,
    build(c, top, H) {
      // a dead, sun-bleached snag its tail smashes during the display
      const [, sg] = H.propModel(c, 'Snag');
      const sx = 6.2, sz = 5.6;
      for (let i = 0; i < 5; i++) sg.box({ name: 'SnagTrunk', s: [0.85 - i * 0.06, 1.3, 0.85 - i * 0.06], p: [sx + i * 0.06, top + 0.65 + i * 1.25, sz], r: [0, i * 21, -3], c: i % 2 ? '#a89478' : '#bba98c', m: 'Wood' });
      sg.beam([sx, top + 4.6, sz], [sx - 1.6, top + 6.0, sz - 0.9], 0.4, 0.4, { name: 'SnagBranch', c: '#a89478', m: 'Wood' });
      sg.beam([sx, top + 5.4, sz], [sx + 1.1, top + 6.6, sz + 0.4], 0.32, 0.32, { name: 'SnagBranch', c: '#bba98c', m: 'Wood' });
      sg.beam([sx - 1.0, top + 5.6, sz - 0.55], [sx - 1.6, top + 6.6, sz - 0.2], 0.24, 0.24, { name: 'SnagTwig', c: '#a89478', m: 'Wood' });
      // tall striped sandstone 'crest rocks' behind, and a ledge to the left
      const pillar = (x, z, h, seed) => {
        const R = rng(seed);
        for (let i = 0; i < Math.round(h / 1.4); i++) c.box({ name: 'CrestRock', s: [2.2 - i * 0.12, 1.4, 2.0 - i * 0.1], p: [x + (R() - 0.5) * 0.2, top + 0.7 + i * 1.4, z], r: [0, R() * 20, 0], c: i % 3 === 1 ? '#e8d2b0' : i % 2 ? CLAY : CLAYLO, m: 'Sandstone', studs: i % 3 === 2 ? 'top' : undefined });
      };
      pillar(-2.4, 7.4, 7.0, 41);
      pillar(1.6, 8.0, 5.6, 42);
      redRock(c, -7.0, -2.5, top, 0.9, 43);
      redRock(c, 7.4, -1.8, top, 0.7, 44);
      // its partner, crest to crest
      mate(H, c, top, 'DilophosaurusPartner', 0.9, -5.0, 3.6, yawTo(-5.0, 3.6, 0.5, -3.0));
    },
  },
  // ---------------- POSTOSUCHUS: the bone wash (a dry riverbed of cracked mud) ----------------
  Postosuchus: {
    pos: [40, -335], yaw: 180, radius: 16,
    build(c, top, H) {
      const R = rng(1215);
      // the wet mud it lies buried in, and the dry cracked crust over it (MudCrust bursts when it rises)
      c.box({ name: 'MudPit', s: [7.2, 0.06, 24], p: [0, top + 0.03, 0.8], c: MUDLO });
      for (let i = 0; i < 10; i++) c.box({ name: 'MudPuddle', s: [1.4 + R() * 1.6, 0.08, 1.2 + R() * 1.6], p: [(R() - 0.5) * 5.4, top + 0.05, -9.5 + i * 2.2], r: [0, R() * 60, 0], c: MUD, refl: 0.08 });
      const [, mc] = H.propModel(c, 'MudCrust');
      for (let z = -12.4; z < 5; z += 2.15) for (let x = -2.6; x <= 2.7; x += 2.6) {
        const w = 2.0 + R() * 0.35, d = 1.8 + R() * 0.3;
        mc.box({ name: 'CrustPlate', s: [w, 0.2, d], p: [x + (R() - 0.5) * 0.3, top + 0.12, z + (R() - 0.5) * 0.3], r: [(R() - 0.5) * 6, R() * 20 - 10, (R() - 0.5) * 6], c: (Math.round(z + x) % 2) ? DRY : '#9a7650', m: 'Slate' });
      }
      // a scatter of old bones in front-left (they fly when it slams down)
      const [, bn] = H.propModel(c, 'Bones');
      const bx = 3.9, bz = -9.0;
      bn.box({ name: 'BoneSpine', s: [0.35, 0.3, 3.2], p: [bx, top + 0.2, bz], r: [0, 20, 0], c: BONE });
      for (let i = 0; i < 5; i++) {
        const r = bn.at([bx + Math.sin(0.35) * (i - 2) * 0.62, top + 0.2, bz + Math.cos(0.35) * (i - 2) * 0.62], [0, 20, 0]);
        r.sym((s) => { s.beam([0.1, 0, 0], [0.9, 0.9, 0], 0.16, 0.16, { name: 'Rib', c: i % 2 ? BONE : BONELO }); s.beam([0.9, 0.9, 0], [1.25, 0.25, 0], 0.14, 0.14, { name: 'Rib', c: BONELO }); });
      }
      const sk = bn.at([bx - 1.2, top, bz - 2.6], [0, 30, 0]);
      sk.box({ name: 'BoneSkull', s: [0.9, 0.7, 1.3], p: [0, 0.35, 0], c: BONE });
      sk.box({ name: 'BoneSnout', s: [0.6, 0.45, 0.9], p: [0, 0.26, -1.0], c: BONELO });
      sk.box({ name: 'BoneEye', s: [0.92, 0.25, 0.3], p: [0, 0.45, -0.2], c: '#3a2a20' });
      // a dead riverbed tree, banks of red clay, bleached rocks
      const dt = c.at([7.5, top, 9.5], [0, 30, 0]);
      for (let i = 0; i < 6; i++) dt.box({ name: 'DeadTree', s: [1.0 - i * 0.08, 1.4, 1.0 - i * 0.08], p: [i * 0.08, 0.7 + i * 1.35, 0], r: [0, i * 17, -2], c: i % 2 ? '#8a7258' : '#9c8468', m: 'Wood' });
      dt.beam([0.2, 6.0, 0], [-2.2, 8.0, 0.4], 0.4, 0.4, { name: 'DeadBranch', c: '#8a7258', m: 'Wood' });
      dt.beam([0.3, 7.0, 0], [2.0, 9.0, -0.6], 0.32, 0.32, { name: 'DeadBranch', c: '#9c8468', m: 'Wood' });
      for (const [x, z, k, sd] of [[-9.5, 4.0, 1.4, 51], [10.5, -3.0, 1.1, 52], [-8.0, 11.0, 1.6, 53], [4.5, 13.0, 1.2, 54]]) redRock(c, x, z, top, k, sd, 'BankRock');
      for (let i = 0; i < 14; i++) {
        const a = R() * Math.PI * 2, d = 6 + R() * 8;
        c.box({ name: 'CrackedGround', s: [1.6 + R(), 0.08, 1.4 + R()], p: [Math.cos(a) * d, top + 0.04, Math.sin(a) * d], r: [0, R() * 90, 0], c: i % 2 ? SAND : SANDLO, m: 'Slate' });
      }
    },
  },
};

module.exports = { SLOTS };
