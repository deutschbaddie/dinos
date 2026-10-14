// JS mirror of the Luau animation + camera evaluation (DinosaurAnimations/Gaits.luau and
// DinosaurCinematics). Used by the preview to render cinematic frames for QC. Keep in sync with Luau.
const { CF } = require('../cframe.js');

const TAU = Math.PI * 2;
const Ease = {
  Linear: (a) => a,
  Sine: (a) => 0.5 - Math.cos(a * Math.PI) * 0.5,
  In: (a) => a * a,
  Out: (a) => 1 - (1 - a) * (1 - a),
  Snap: (a) => 1 - Math.pow(1 - a, 4),
  Back: (a) => { const c1 = 1.70158, c3 = 2.70158; return 1 + c3 * Math.pow(a - 1, 3) + c1 * Math.pow(a - 1, 2); },
};
const ease = (n) => Ease[n] || Ease.Sine;
const ZERO = [0, 0, 0, 0, 0, 0];

function expandPose(pose) {
  const out = {};
  for (const [j, v] of Object.entries(pose)) {
    const vals = [0, 1, 2, 3, 4, 5].map((i) => v[i] || 0);
    if (j[0] === '~') {
      out['Right' + j.slice(1)] = vals;
      out['Left' + j.slice(1)] = [vals[0], -vals[1], -vals[2], -vals[3], vals[4], vals[5]];
    } else out[j] = vals;
  }
  return out;
}

function compileKeys(action) {
  const tracks = {};
  for (const [t, pose, e] of action.Keys || []) {
    for (const [j, vals] of Object.entries(expandPose(pose))) (tracks[j] = tracks[j] || []).push([t, vals, e || 'Sine']);
  }
  for (const tr of Object.values(tracks)) {
    tr.sort((a, b) => a[0] - b[0]);
    if (tr[0][0] > 0) tr.unshift([0, ZERO, 'Linear']);
    if (tr[tr.length - 1][0] < action.Duration - 1e-3 && !action.HoldEnd) tr.push([action.Duration, ZERO, action.EndEase || 'Sine']);
  }
  return tracks;
}

function sampleTrack(tr, t) {
  const n = tr.length;
  if (t <= tr[0][0]) return tr[0][1];
  if (t >= tr[n - 1][0]) return tr[n - 1][1];
  for (let i = 0; i < n - 1; i++) {
    const a = tr[i], b = tr[i + 1];
    if (t < b[0]) {
      const span = b[0] - a[0];
      const k = ease(b[2])(span > 1e-6 ? (t - a[0]) / span : 1);
      return a[1].map((v, c) => v + (b[1][c] - v) * k);
    }
  }
  return tr[n - 1][1];
}

class Acc {
  constructor() { this.v = {}; }
  add(j, rx = 0, ry = 0, rz = 0, px = 0, py = 0, pz = 0, w = 1) {
    const a = (this.v[j] = this.v[j] || [0, 0, 0, 0, 0, 0]);
    a[0] += rx * w; a[1] += ry * w; a[2] += rz * w; a[3] += px * w; a[4] += py * w; a[5] += pz * w;
  }
}

function chain(acc, joints, rx, ry, rz, w) {
  const n = joints.length;
  joints.forEach((j, idx) => { const k = ((idx + 1) / n) / ((n + 1) / 2); acc.add(j, rx * k, ry * k, rz * k, 0, 0, 0, w); });
}

const SIDES = [['Right', 1, 0], ['Left', -1, 0.5]];
function locomote(acc, phase, w, G, P, running) {
  const S = G.Scale || 1;
  const phi = phase * TAU;
  for (const [side, sign, off] of SIDES) {
    const sp = phi + off * TAU;
    const swing = Math.sin(sp), lift = Math.max(0, Math.cos(sp));
    const thigh = P.Stride * swing + (P.ThighBias || 0);
    const shin = -P.Knee * lift - (P.KneeBias || 0.08);
    const foot = -(thigh + shin) * 0.85 + 0.35 * lift;
    acc.add(side + 'Thigh', thigh, 0, -0.03 * sign, 0, 0, 0, w);
    acc.add(side + 'Shin', shin, 0, 0, 0, 0, 0, w);
    acc.add(side + 'Foot', foot, 0, 0, 0, 0, 0, w);
    acc.add(side + 'Toes', -0.35 * lift + 0.1 * Math.max(0, -Math.cos(sp)), 0, 0, 0, 0, 0, w);
    acc.add(side + 'SickleClaw', -0.25 - 0.2 * lift, 0, 0, 0, 0, 0, w);
    if (running) { acc.add(side + 'Arm', 0.45 + 0.08 * swing, 0, -0.08 * sign, 0, 0, 0, w); acc.add(side + 'Forearm', -0.55, 0, 0, 0, 0, 0, w); }
    else { acc.add(side + 'Arm', 0.1 - 0.12 * swing, 0, 0, 0, 0, 0, w); acc.add(side + 'Forearm', -0.1, 0, 0, 0, 0, 0, w); }
  }
  const c2 = Math.cos(2 * phi);
  acc.add('Pelvis', 0, P.Yaw * Math.sin(phi), P.Roll * Math.sin(phi), 0, P.Bob * S * 0.5 * c2, 0, w);
  acc.add('Torso', -P.Lean + 0.03 * Math.cos(2 * phi + 0.4), -P.Yaw * 0.6 * Math.sin(phi), 0, 0, 0, 0, w);
  acc.add('Chest', 0, 0, 0, 0, -0.03 * S * c2, 0, w);
  chain(acc, G.Neck, P.Lean * 0.7 + P.HeadBob * Math.cos(2 * phi - 0.6), -P.Yaw * 0.2 * Math.sin(phi), 0, w);
  acc.add('Head', P.Lean * 0.25 - P.HeadBob * 0.6 * Math.cos(2 * phi - 0.9), -P.Yaw * 0.25 * Math.sin(phi), 0, 0, 0, 0, w);
  acc.add('Jaw', running ? -0.12 - 0.06 * Math.sin(2 * phi) : -0.03, 0, 0, 0, 0, 0, w);
  G.Tail.forEach((j, idx) => {
    const i = idx + 1;
    acc.add(j, (running ? -0.05 : 0) + 0.04 * Math.cos(2 * phi - i * 0.5), P.TailSway * Math.sin(phi - i * 0.6) * (0.7 + i * 0.2), 0, 0, 0, 0, w);
  });
}

const QUAD_WALK = { RightHind: 0, RightFront: 0.25, LeftHind: 0.5, LeftFront: 0.75 };
const QUAD_TROT = { RightHind: 0, LeftFront: 0, LeftHind: 0.5, RightFront: 0.5 };
function quadLocomote(acc, phase, w, G, P, running) {
  const S = G.Scale || 1;
  const offs = running ? QUAD_TROT : QUAD_WALK;
  for (const [side] of SIDES) for (const limb of ['Hind', 'Front']) {
    const sp = (phase + offs[side + limb]) * TAU;
    const swing = Math.sin(sp), lift = Math.max(0, Math.cos(sp));
    if (limb === 'Hind') {
      const thigh = P.Stride * swing, shin = -P.Knee * lift - 0.04;
      acc.add(side + 'HindThigh', thigh, 0, 0, 0, 0, 0, w); acc.add(side + 'HindShin', shin, 0, 0, 0, 0, 0, w);
      acc.add(side + 'HindFoot', -(thigh + shin) * 0.9 + 0.2 * lift, 0, 0, 0, 0, 0, w);
    } else {
      const up = P.Stride * 0.9 * swing, lo = -P.Knee * 0.9 * lift;
      acc.add(side + 'FrontUpper', up, 0, 0, 0, 0, 0, w); acc.add(side + 'FrontLower', lo, 0, 0, 0, 0, 0, w);
      acc.add(side + 'FrontFoot', -(up + lo) * 0.9 + 0.25 * lift, 0, 0, 0, 0, 0, w);
    }
  }
  const phi = phase * TAU, beats = running ? 2 : 4, bob = Math.cos(beats * phi);
  acc.add('Pelvis', 0, P.Yaw * Math.sin(phi), P.Roll * Math.sin(phi), 0, P.Bob * S * 0.5 * bob, 0, w);
  acc.add('Torso', -P.Lean + 0.02 * Math.cos(beats * phi + 0.6), -P.Yaw * 0.5 * Math.sin(phi), -P.Roll * 0.7 * Math.sin(phi + 1.2), 0, 0, 0, w);
  acc.add('Chest', 0, 0, 0, 0, -0.02 * S * bob, 0, w);
  chain(acc, G.Neck, P.HeadBob * Math.cos(beats * phi - 0.7), -P.Yaw * 0.3 * Math.sin(phi), 0, w);
  acc.add('Head', -P.HeadBob * 0.5 * Math.cos(beats * phi - 1.0), 0, 0, 0, 0, 0, w);
  G.Tail.forEach((j, idx) => { const i = idx + 1; acc.add(j, 0.03 * Math.cos(beats * phi - i * 0.5), P.TailSway * Math.sin(phi - i * 0.55) * (0.7 + i * 0.18), 0, 0, 0, 0, w); });
}
function swimWave(acc, phase, w, G, amp, flip, bob) {
  const S = G.Scale || 1, phi = phase * TAU;
  acc.add('Pelvis', 0, amp * 0.25 * Math.sin(phi), 0, 0, bob * S * Math.sin(phi * 0.5), 0, w);
  acc.add('Torso', 0, -amp * 0.35 * Math.sin(phi + 0.6), 0, 0, 0, 0, w);
  chain(acc, G.Neck, 0.02 * Math.sin(phi), amp * 0.3 * Math.sin(phi + 1.4), 0, w);
  acc.add('Head', 0, amp * 0.2 * Math.sin(phi + 1.8), 0, 0, 0, 0, w);
  G.Tail.forEach((j, idx) => { const i = idx + 1; acc.add(j, 0.02 * Math.sin(phi - i * 0.4), amp * Math.sin(phi - i * 0.7) * (0.5 + i * 0.28), 0, 0, 0, 0, w); });
  for (const [side, sign] of SIDES) {
    const f = Math.sin(phi + (sign > 0 ? 0 : Math.PI) * 0.2);
    acc.add(side + 'FrontFlipper', 0.15 * flip * f, 0.25 * flip * Math.cos(phi) * sign, 0.35 * flip * f * sign, 0, 0, 0, w);
    acc.add(side + 'HindFlipper', 0.12 * flip * Math.sin(phi - 1.2), 0, 0.25 * flip * Math.sin(phi - 1.2) * sign, 0, 0, 0, w);
  }
}
const GAITS = {
  Biped: locomote,
  Quadruped: quadLocomote,
  Swim: (acc, phase, w, G, P) => swimWave(acc, phase, w, G, P.Amp, P.Flip, P.Bob),
};
function gaitPose(profile, mode, phase) {
  const acc = new Acc();
  const G = profile.Gait;
  if (mode === 'Idle' && G.Type === 'Swim') swimWave(acc, phase, 1, G, G.Idle.Amp, G.Idle.Flip, G.Idle.Bob);
  else if (mode !== 'Idle') GAITS[G.Type](acc, phase, 1, G, G[mode], mode === 'Run');
  const pose = {};
  for (const [j, v] of Object.entries(acc.v)) pose[j] = new CF(v[3], v[4], v[5]).mul(CF.angles(v[0], v[1], v[2]));
  return pose;
}

const Procedural = {
  Dizzy(acc, t, w, p, G) {
    if (t > p.T0 && t < p.T1) {
      const env = Math.min(1, (t - p.T0) / 0.3, (p.T1 - t) / 0.3);
      acc.add('Head', 0, p.Head[0] * Math.sin(t * p.Rate) * env, p.Head[1] * Math.cos(t * p.Rate) * env, 0, 0, 0, w);
      acc.add(G.Neck[G.Neck.length - 1], 0, p.Neck * Math.sin(t * p.Rate - 0.6) * env, 0, 0, 0, 0, w);
      acc.add('Pelvis', 0, 0, p.Roll * Math.sin(t * p.Rate * 0.5) * env, 0, 0, 0, w);
    }
  },
};

function evalAction(acc, profile, action, t, w) {
  action._tracks = action._tracks || compileKeys(action);
  t = Math.max(0, Math.min(action.Duration, t));
  for (const [j, tr] of Object.entries(action._tracks)) { const v = sampleTrack(tr, t); acc.add(j, ...v, w); }
  for (const [joint, t0, t1, amp, freq, axis = 3] of action.Shake || []) {
    if (t >= t0 && t <= t1) {
      const env = Math.min(1, (t - t0) / 0.12, (t1 - t) / 0.2);
      const v = amp * env * Math.sin(t * TAU * freq);
      const joints = joint[0] === '~' ? ['Right' + joint.slice(1), 'Left' + joint.slice(1)] : [joint];
      for (const j of joints) acc.add(j, axis === 1 ? v : 0, axis === 2 ? v : 0, axis === 3 ? v : 0, 0, 0, 0, w);
    }
  }
  const G = profile.Gait;
  for (const [t0, t1, mode, gw = 1, fm = 1] of action.Gait || []) {
    if (t >= t0 && t <= t1) {
      const ramp = Math.min(1, (t - t0) / 0.3, (t1 - t) / 0.3);
      const P = G[mode];
      GAITS[G.Type](acc, (t - t0) * P.Freq * fm, w * ramp * gw, G, P, mode === 'Run');
    }
  }
  if (action.Procedural) Procedural[action.Procedural.Type](acc, t, w, action.Procedural, G);
}

// Pose (joint -> CF) of `actionName` at time t (idle base loop ignored; cinematic actions suppress it)
function actionPose(profile, actionName, t) {
  const action = profile.Actions[actionName];
  const acc = new Acc();
  const fi = action.FadeIn ?? 0.18, fo = action.FadeOut ?? 0.3;
  const fade = Math.min(1, t / Math.max(fi, 1e-3), Math.max(0, Math.min(1, (action.Duration - t) / Math.max(fo, 1e-3))));
  evalAction(acc, profile, action, t, fade);
  const pose = {};
  for (const [j, v] of Object.entries(acc.v)) pose[j] = new CF(v[3], v[4], v[5]).mul(CF.angles(v[0], v[1], v[2]));
  return pose;
}

// ---------------- Camera (mirrors DinosaurCinematics.sampleShots) ----------------
function lerp3(a, b, k) { return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k]; }
function resolve(spec, G, u, targets) {
  if (spec && spec.__v3) return G.pt(spec.__v3.map((c) => c * u));
  if (typeof spec === 'string') return targets[spec] || G.pos();
  if (spec && spec.Follow) {
    const base = targets[spec.Follow] || G.pos();
    const off = G.vec(spec.Offset.__v3.map((c) => c * u));
    return [base[0] + off[0], base[1] + off[1], base[2] + off[2]];
  }
  return G.pos();
}
function shotState(shot, a, G, u, targets) {
  const f = shot.From, to = shot.To;
  return {
    pos: lerp3(resolve(f.Pos, G, u, targets), resolve(to.Pos, G, u, targets), a),
    look: lerp3(resolve(f.Look, G, u, targets), resolve(to.Look, G, u, targets), a),
    fov: f.Fov + (to.Fov - f.Fov) * a,
    roll: (f.Roll || 0) + ((to.Roll || 0) - (f.Roll || 0)) * a,
  };
}
function sampleShots(list, t, D, G, u, targets) {
  const k = list.Normalized ? D : 1;
  const shots = list.Shots;
  let i = shots.findIndex((s) => t >= s.T0 * k && t < s.T1 * k);
  if (i < 0) i = t < shots[0].T0 * k ? 0 : shots.length - 1;
  const s = shots[i];
  const a = ease(s.Ease)(Math.max(0, Math.min(1, (t - s.T0 * k) / ((s.T1 - s.T0) * k))));
  let st = shotState(s, a, G, u, targets);
  const blend = (s.Blend || 0) * k;
  if (blend > 0 && i > 0 && t - s.T0 * k < blend) {
    const prev = shotState(shots[i - 1], 1, G, u, targets);
    const b = Ease.Sine((t - s.T0 * k) / blend);
    st = { pos: lerp3(prev.pos, st.pos, b), look: lerp3(prev.look, st.look, b), fov: prev.fov + (st.fov - prev.fov) * b, roll: prev.roll + (st.roll - prev.roll) * b };
  }
  st.pos = [st.pos[0], Math.max(st.pos[1], G.y + 0.4), st.pos[2]];
  st.shot = s.Name;
  return st;
}

module.exports = { actionPose, gaitPose, sampleShots, compileKeys, Ease };
