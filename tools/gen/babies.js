// Baby dinosaurs: a scaled clone of the adult with a proportionally bigger head (cute "chibi" ratio).
// The rig is untouched (same bones / joints), so every adult animation profile plays on the baby;
// AnimScale shrinks the profile's translations to match.
const B = require('./builder.js');
const { CF } = B;

const BODY = 0.45, HEAD = 1.45;

function scaleAbout(cf, o, k) {
  return new CF(o[0] + (cf.x - o[0]) * k, o[1] + (cf.y - o[1]) * k, o[2] + (cf.z - o[2]) * k, cf.r.slice());
}

// Rebuild every joint / weld / attachment offset from the parts' current world CFrames
function recomputeJoints(model) {
  model.walk((i) => {
    if ((i.cls === 'Weld' || i.cls === 'Motor6D') && i.props.Part0 && i.props.Part1) {
      const p0 = i.props.Part0[1], p1 = i.props.Part1[1];
      i.props.C0[1] = p0._cf.inv().mul(p1._cf);
      i.props.C1[1] = new CF();
    }
    if (i.cls === 'Attachment' && i._world && i.parent && i.parent._cf) i.props.CFrame[1] = i.parent._cf.inv().mul(i._world);
  });
}

function buildBaby(adult) {
  const m = B.cloneTree(adult);
  B.scaleTree(m, BODY);
  // head subtree: the Head bone and every bone below it (jaw, crest, horns...)
  let head = null;
  m.walk((i) => { if (i._isBone && i.name === 'Head') head = i; });
  if (head) {
    const o = head._cf.pos();
    const inHead = (bone) => { for (let b = bone; b; b = b._parentBone) if (b === head) return true; return false; };
    m.walk((i) => {
      const owner = i._isBone ? i : i._weldTo || (i.cls === 'Attachment' && i.parent && (i.parent._isBone ? i.parent : i.parent._weldTo));
      if (!owner || !inHead(owner)) return;
      if (i._cf) { i._cf = scaleAbout(i._cf, o, HEAD); i.props.CFrame[1] = i._cf; }
      if (i._preview && !i._isBone) { i._preview.size = i._preview.size.map((v) => v * HEAD); i.props.size[1] = i._preview.size.map((v) => Math.max(0.05, +v.toFixed(4))); }
      if (i._world) i._world = scaleAbout(i._world, o, HEAD);
    });
  }
  recomputeJoints(m);
  // stand on the ground again (a bigger head can't change foot height, but keep it exact)
  const b = B.bounds(m);
  if (Math.abs(b.min[1]) > 0.01) B.transformTree(m, new CF(0, -b.min[1], 0));
  recomputeJoints(m);
  m.attr('Baby', true).attr('AnimScale', BODY);
  if (adult.attrs.HipHeight) m.attr('HipHeight', +(adult.attrs.HipHeight * BODY).toFixed(2));
  m.tags = m.tags.filter((t) => t !== 'DinoExpeditionDinosaur');
  m.tag('DinoBaby');
  return m;
}

module.exports = { buildBaby, recomputeJoints, BABY_SCALE: BODY };
