// Minimal Roblox-compatible CFrame math (row-major 3x3 rotation + position).
// Columns of the rotation are RightVector, UpVector, -LookVector (Roblox convention).
const D2R = Math.PI / 180;

function mul3(a, b) {
  const r = new Array(9);
  for (let i = 0; i < 3; i++)
    for (let j = 0; j < 3; j++)
      r[i * 3 + j] = a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j];
  return r;
}

class CF {
  constructor(x = 0, y = 0, z = 0, r = [1, 0, 0, 0, 1, 0, 0, 0, 1]) {
    this.x = x; this.y = y; this.z = z; this.r = r;
  }
  static p(x, y, z) { return new CF(x, y, z); }
  // Same as Roblox CFrame.Angles(rx, ry, rz) (radians) = Rx * Ry * Rz
  static angles(rx = 0, ry = 0, rz = 0) {
    const [cx, sx, cy, sy, cz, sz] = [Math.cos(rx), Math.sin(rx), Math.cos(ry), Math.sin(ry), Math.cos(rz), Math.sin(rz)];
    const Rx = [1, 0, 0, 0, cx, -sx, 0, sx, cx];
    const Ry = [cy, 0, sy, 0, 1, 0, -sy, 0, cy];
    const Rz = [cz, -sz, 0, sz, cz, 0, 0, 0, 1];
    return new CF(0, 0, 0, mul3(mul3(Rx, Ry), Rz));
  }
  static deg(rx = 0, ry = 0, rz = 0) { return CF.angles(rx * D2R, ry * D2R, rz * D2R); }
  // Build from position + right/up vectors (back = right x up)
  static fromAxes(pos, right, up) {
    const n = (v) => { const l = Math.hypot(...v) || 1; return v.map((c) => c / l); };
    right = n(right);
    let back = n(cross(right, up));
    up = cross(back, right);
    return new CF(pos[0], pos[1], pos[2], [right[0], up[0], back[0], right[1], up[1], back[1], right[2], up[2], back[2]]);
  }
  // CFrame at pos whose LookVector points at target
  static lookAt(pos, target, upHint = [0, 1, 0]) {
    const f = sub(target, pos);
    const l = Math.hypot(...f);
    const look = f.map((c) => c / l);
    let right = cross(look, upHint);
    if (Math.hypot(...right) < 1e-6) right = cross(look, [0, 0, 1]);
    return CF.fromAxes(pos, right, cross(right.map((c) => c), look).map((c) => -c)).fixUp(look);
  }
  fixUp(look) {
    // ensure LookVector == look (recompute from right & look)
    const right = this.right();
    const up = cross(right, look.map((c) => -c)).map((c) => -c);
    const back = look.map((c) => -c);
    this.r = [right[0], up[0], back[0], right[1], up[1], back[1], right[2], up[2], back[2]];
    return this;
  }
  // CFrame centered at midpoint of a->b with local X axis along (b - a)
  static alongX(a, b, upHint = [0, 1, 0]) {
    const d = sub(b, a);
    const mid = a.map((c, i) => (c + b[i]) / 2);
    let up = upHint;
    if (Math.abs(dot(norm(d), norm(up))) > 0.98) up = [0, 0, 1];
    return CF.fromAxes(mid, d, up);
  }
  mul(o) {
    const r = this.r;
    return new CF(
      this.x + r[0] * o.x + r[1] * o.y + r[2] * o.z,
      this.y + r[3] * o.x + r[4] * o.y + r[5] * o.z,
      this.z + r[6] * o.x + r[7] * o.y + r[8] * o.z,
      mul3(r, o.r)
    );
  }
  pt(v) {
    const r = this.r;
    return [this.x + r[0] * v[0] + r[1] * v[1] + r[2] * v[2], this.y + r[3] * v[0] + r[4] * v[1] + r[5] * v[2], this.z + r[6] * v[0] + r[7] * v[1] + r[8] * v[2]];
  }
  vec(v) {
    const r = this.r;
    return [r[0] * v[0] + r[1] * v[1] + r[2] * v[2], r[3] * v[0] + r[4] * v[1] + r[5] * v[2], r[6] * v[0] + r[7] * v[1] + r[8] * v[2]];
  }
  inv() {
    const r = this.r;
    const t = [r[0], r[3], r[6], r[1], r[4], r[7], r[2], r[5], r[8]];
    const c = new CF(0, 0, 0, t);
    const p = c.vec([this.x, this.y, this.z]);
    c.x = -p[0]; c.y = -p[1]; c.z = -p[2];
    return c;
  }
  // Conjugate by mirror across local X (M L M, M = diag(-1,1,1)): mirrors a placement left<->right
  mirrorX() {
    const r = this.r.slice();
    r[1] = -r[1]; r[2] = -r[2]; r[3] = -r[3]; r[6] = -r[6];
    return new CF(-this.x, this.y, this.z, r);
  }
  pos() { return [this.x, this.y, this.z]; }
  right() { return [this.r[0], this.r[3], this.r[6]]; }
  up() { return [this.r[1], this.r[4], this.r[7]]; }
  look() { return [-this.r[2], -this.r[5], -this.r[8]]; }
  rotOnly() { return new CF(0, 0, 0, this.r.slice()); }
  withPos(x, y, z) { return new CF(x, y, z, this.r.slice()); }
}

function sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
function add(a, b) { return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]; }
function scale(a, s) { return [a[0] * s, a[1] * s, a[2] * s]; }
function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
function norm(a) { const l = Math.hypot(...a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; }
function lerp(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }

module.exports = { CF, D2R, sub, add, scale, dot, cross, norm, lerp };
