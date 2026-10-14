// Spine River QC stages (tools/gen/newSpecies.js picks this up). Croc Creek: a muddy pool with three drifting logs,
// so Sarcosuchus' LOG THAT ISN'T signature has its company. The logs are one CinematicProp ("DriftLogs") whose child
// Models the LogDrift VFX event floats along the pool and RestoreProp puts back.
// Pool depth: the water stands 2.6 studs over its feet, the same as a water set's sinkTo(.., 0.6), so the floating
// pose lines up at the waterline in both places.
const { Inst, rng } = require('./builder.js');

const BARK = ['#5e4128', '#6b4a2b', '#7d5733'];

// a drifting log lying on the water: ~8 studs, bark rings, a snapped branch, moss on top, half awash
function driftLog(c, id, p, yaw, len, seed) {
  const m = new Inst('Model', id);
  c.parent.add(m);
  const c0 = c.into(m);
  const R = rng(seed);
  const L = c0.at(p, [0, yaw, 4 - R() * 8]);
  const n = Math.round(len / 1.6);
  for (let i = 0; i < n; i++) {
    const x = -len / 2 + 0.8 + i * 1.6;
    L.cyl({ name: 'LogSegment', len: 1.6, d: 1.9 - i * 0.04, p: [x, 0, 0], c: BARK[i % 3], m: 'Wood', anchored: true });
    if (i % 2) L.cyl({ name: 'BarkRing', len: 0.22, d: 2.04 - i * 0.04, p: [x - 0.8, 0, 0], c: '#4e3420', anchored: true });
  }
  L.cyl({ name: 'LogEnd', len: 0.06, d: 1.65, p: [-len / 2 - 0.02, 0, 0], c: '#c99a62', anchored: true });
  L.cyl({ name: 'LogEndCore', len: 0.07, d: 0.6, p: [-len / 2 - 0.03, 0, 0], c: '#a87a48', anchored: true });
  L.box({ name: 'BranchStub', s: [0.4, 1.3, 0.4], p: [len * 0.12, 1.05, 0.2], r: [20, 0, 28], c: '#5e4128', anchored: true });
  L.box({ name: 'Moss', s: [len * 0.35, 0.2, 1.0], p: [-len * 0.15, 0.94, 0], c: '#5f8f3e', studs: 'top', anchored: true });
  return m;
}

module.exports = {
  SLOTS: {
    Sarcosuchus: {
      pos: [0, -400], yaw: 90, type: 'pool', pool: [30, 50], depth: 2.35, radius: 16,
      build(c, top, H) {
        // the logs sit at the waterline (local y 0.25) out in front of the croc, where the opening shot sees them
        const [m, cc] = H.propModel(c, 'DriftLogs');
        const W = 0.25;
        const logs = [
          ['DriftLog1', [-10.0, W, -8.0], 20, 8.5, 7101],
          ['DriftLog2', [7.0, W, -15.0], 105, 9.5, 7102],
          ['DriftLog3', [8.0, W, 8.0], 82, 10.0, 7103],
        ];
        for (const [id, p, yaw, len, seed] of logs) driftLog(cc, id, p, yaw, len, seed);
        return m;
      },
    },
  },
};
