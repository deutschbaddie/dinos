// NPC spots — the server spawns real R6 characters here (ServerScriptService/Game/Npcs.luau) and dresses
// them; the map only carries where they stand, their name tag and their Talk prompt.
const B = require('./builder.js');
const { Inst, CF } = B;

const TITLE = { Professor: 'THE PROFESSOR', Mechanic: 'THE ARMORER', EggKeeper: 'EGG KEEPER', Ranger: 'RANGER' };
const SHORT = { Professor: 'Professor', Mechanic: 'Armorer', EggKeeper: 'Egg Keeper', Ranger: 'Ranger' };

// cf: world CF of the character's feet, facing -Z
function buildNpc(parent, cf, kind) {
  const spot = parent.add(B.makePart(cf.mul(new CF(0, 3, 0)), { name: 'NpcSpot_' + kind, s: [2, 1, 1], t: 1, anchored: true, shadow: false, c: '#ffffff' }));
  spot.set('CanCollide', 'bool', false).set('CanQuery', 'bool', false);
  spot.attr('Npc', kind);
  spot.tag('DinoNpcSpot');
  const bb = new Inst('BillboardGui', 'NameTag');
  bb.set('Size', 'UDim2', [0, 220, 0, 50]).set('StudsOffset', 'Vector3', [0, 4.4, 0]).set('MaxDistance', 'float', 70).set('LightInfluence', 'float', 0);
  bb.add(B.styledText(TITLE[kind], { name: 'Name', size: [1, 0, 1, 0], pos: [0, 0, 0, 0], color: '#ffffff', strokeT: 3, shadow: 2, align: 'Center', family: 'FredokaOne' }));
  spot.add(bb);
  const a = new Inst('Attachment', 'TalkAttachment');
  a.set('CFrame', 'CFrame', new CF(0, 0.5, -1.4));
  spot.add(a);
  const pr = new Inst('ProximityPrompt', 'TalkPrompt');
  pr.set('ActionText', 'string', 'Talk').set('ObjectText', 'string', SHORT[kind]);
  pr.set('KeyboardKeyCode', 'token', 101).set('MaxActivationDistance', 'float', 11).set('HoldDuration', 'float', 0).set('RequiresLineOfSight', 'bool', false);
  pr.attr('Npc', kind);
  a.add(pr);
  return spot;
}

module.exports = { buildNpc };
