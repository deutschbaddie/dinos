// JS data -> Luau table literal serializer (used to generate profiles and shot lists).
function key(k) { return /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : `["${k}"]`; }
function num(n) { return Number.isInteger(n) ? String(n) : String(+n.toFixed(4)); }
function toLuau(v, ind = '') {
  const i2 = ind + '\t';
  if (v === null || v === undefined) return 'nil';
  if (typeof v === 'number') return num(v);
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'string') return JSON.stringify(v);
  if (v.__v3) return `Vector3.new(${v.__v3.map(num).join(', ')})`;
  if (Array.isArray(v)) {
    if (v.every((x) => typeof x !== 'object' || x === null || x.__v3)) return `{ ${v.map((x) => toLuau(x)).join(', ')} }`;
    return `{\n${v.map((x) => i2 + toLuau(x, i2) + ',').join('\n')}\n${ind}}`;
  }
  const entries = Object.entries(v).filter(([k]) => k[0] !== '_');
  if (!entries.length) return '{}';
  const simple = entries.every(([, x]) => typeof x !== 'object' || x === null || x.__v3 || (Array.isArray(x) && x.every((y) => typeof y !== 'object')));
  if (simple && entries.length <= 6) return `{ ${entries.map(([k, x]) => `${key(k)} = ${toLuau(x)}`).join(', ')} }`;
  return `{\n${entries.map(([k, x]) => `${i2}${key(k)} = ${toLuau(x, i2)},`).join('\n')}\n${ind}}`;
}
module.exports = { toLuau };
