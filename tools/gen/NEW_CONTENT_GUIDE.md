# How to add the 2026-10-12 species and eras (read fully before starting)

Briefs: tools/gen/NEW_DINOS_BRIEF.md (species) and tools/gen/NEW_ERAS_BRIEF.md (eras). Style bar: chunky studded
toy-brick Roblox (Ghost Catchers look), bold saturated colour, every cutscene unique and cinematic.

Other sessions are editing this repo at the same time (Spine River map session, animation session). RULES:
- Only create/edit the files listed for your job. Never edit another group's files.
- Shared files (Config.luau, Chase.luau, EraView.luau, ExpeditionView.luau, build.js, showcase.js, eggs.js,
  DinosaurVFX/init.luau, mapqc.js, default.project.json, Zone/Ambience/Audio.luau) are integrated by the lead
  session. Put what they need into your staging file instead (see below).
- Build with `node tools/gen/build.js --preview-only` ONLY (never without --preview-only; it would overwrite
  src/ files other sessions depend on). It takes ~10 s and writes tools/preview/out/*.json.
- Everything new is pre-wired: tools/gen/newSpecies.js loads dinos/<file>.js + anim/<file>.js when both exist,
  shots from anim/shots_<group>.js, showcase stages from showcase_<group>.js; build.js builds the eras
  redCliffs.js / frostForest.js / dawnDesert.js when they exist. A module that throws is skipped with a WARNING
  line, so grep the build output for WARNING and for your names.

## A. A new species (key = exact PascalCase id, e.g. Oviraptor)

1. tools/gen/dinos/<file>.js exporting build(); use makeDino(...) from dinos/common.js (see stegosaurus.js,
   velociraptor.js, trex.js, triceratops.js for patterns). Convention: forward = -Z, up = +Y, ground y = 0.
   Bone names the runtime relies on: Pelvis, Torso, Neck (or Neck1..n), Head, Jaw, Tail1..n;
   biped legs Right/LeftThigh, Shin, Foot (bipedLeg); quadruped {Side}HindThigh/HindShin/HindFoot and
   {Side}FrontUpper/FrontLower/FrontFoot (quadLeg); swimmers {Side}FrontFlipper/HindFlipper.
   REQUIRED attachments: VFX_Head, VFX_Mouth, VFX_Chest (build crashes without). Recommended VFX_RightFoot,
   VFX_LeftFoot, VFX_TailTip; optional VFX_Crest, VFX_RightClaw, VFX_RightFrontFoot. Eyes via eye() (blink lids).
   highlight(model) at the end. ~130-180 parts per creature. Rarity attr must be one of Common, Uncommon, Rare,
   Epic, Legendary, Mythic, Secret (match the egg rarity in eggs.js, already filled in for you).
2. tools/gen/anim/<file>.js profile (copy the shape of anim/stegosaurus.js / velociraptor.js / trex.js):
   Signature, Intro (= the signature action), IntroShots (= YOUR unique shot-list key), Chase, Special,
   CycleOrder, CameraScale, Gait { Type 'Biped'|'Quadruped'|'Swim', Scale, Neck:[...], Tail:[...], Idle, Walk, Run },
   Actions. MUST have actions Roar, Attack, Stunned, plus the signature action, LookAround, Chase.
   Name each takedown attack's action exactly like its attack Id (the client plays the action with the same
   name as the attack Id, then falls back to Attack/Roar), e.g. attack Id "BeakSnatch" -> Actions.BeakSnatch.
   Eases: Linear, Sine, In, Out, Snap, Back. Events handled by DinosaurVFX (Footstep, Roar, CameraShake, Growl,
   Bite, EyeGlow, TailSwing, Land, JumpDust, Stunned, Sniff, BreakProp{Prop,Power,At}, FellTrees, Impact{At,Scale},
   Charge, Call{At,Scale,Color,Count}, Scrape, Flush, Rustle, Alarm, HerdCall, Splash, FoliageBurst). New event
   names go in YOUR src/ReplicatedStorage/DinoExpedition/DinosaurVFX/Extra_<Group>.luau:
       return function(VFX) VFX.Extra.SpitGlob = function(model, arg, scale) ... end end
   (VFX has Burst, Cubes, BlockRing, Folder, findAttachment, FoliageBurst, FallingLeaves, WaterSplash, Shake,
   FootstepDust ... read DinosaurVFX/init.luau for what exists; reuse before inventing).
3. Signature shot list in tools/gen/anim/shots_<group>.js (module.exports = { YourKey: {...} }), format of
   anim/shots_signatures.js (Studs: true, Title, Hold: 8, DOF: true, Prop?, TimeRamps, Shots[...]). Keys must be
   globally unique: prefix with the species (e.g. OviHeist). Targets: Head, Mouth, Chest, HeadStart, Prop, Herd,
   RightFoot, LeftFoot, TailTip, RightFrontFoot, RightClaw, Crest, Club.
4. A QC stage in tools/gen/showcase_<group>.js: module.exports = { SLOTS: { Name: { pos:[x,z], yaw, radius,
   build(c, top, H) {...} } } }. H gives propModel(ctx,id) -> [model, ctx] (a CinematicProp your signature can
   target with Prop / BreakProp / FellTrees), log, boulder, crates, jungleTree, palm, bush, rock, fern.
   Pools: { type: 'pool', pool: [W, D], depth }. Row positions are assigned per group (see your task).
   build.js then writes tools/preview/out/cine_<Species>_<ShotKey>.json (contact sheet frames of the cutscene)
   and gait_<Species>.json. Run `node tools/gen/build.js --preview-only --qc` for clipping QC (zfight/animClips).
5. Reveal beat (mystery -> reveal, played when a site is discovered; every dino is found its own way, no
   captions during the mystery; see EraView.luau BEATS.pack/ferns/plates/ember/fin/ripple/shadow/deep/breach
   for the language). Write src/StarterPlayer/StarterPlayerScripts/DinoExpeditionClient/Game/Reveals/<Group>.luau:
       return function(BEATS, REVEAL, H)
         REVEAL.Oviraptor = { Kick = "THE EGG THIEF", Beat = "heist", Act = { "EggHeist", "Roar" }, Hero = "Low" }
         BEATS.heist = function(ctx, skipped) ... end
       end
   REVEAL fields: Kick (short caps line on the name card), Beat, Act (actions played at the reveal), Hero
   "Low"|"Up", optional AtMark, Warm, Ember, Alarm. ctx: Species, Model, Anim, Root, Lift, Set, Mark, Start, Face,
   Side, Size, Ext, Big, WaterY, Dark; ctx.Walk(to, dur, skipped, camFn?, dir?), ctx.Teleport(p, dir),
   ctx.Turn(dir, t), ctx.Head(), ctx.EyesShot(skipped); set ctx.Extras = { models } for extra stand-ins (they
   are cleaned up) and ctx.Pack = { {Model, Anim, Root, Rise} } to have them rise at the reveal.
   H: move(fromCF, toCF, dur, skipped, fovA, fovB, subject), hold(t, skipped), ground(p), standIn(species, scale,
   cf) -> (model, anim), scaleOf, siteScale, herdAt, clearSpot, safeCam, fade, flash, prop(set, props) -> Part,
   silhouette(model, eyes), shatter(set, part, from, power), birdsUp(set, at, n, spread), tree(set, at, h),
   topple(parts, pivot, dir, dur), playAny(anim, names), sinkTo, burst, punch, LEAF, CineKit, DinosaurVFX, Audio,
   Config. Use RunService.RenderStepped for per-frame camera (Workspace.CurrentCamera). Always `if skipped()
   then return end` between steps. Keep each beat 3-5 s. Strict Luau style of the file (--!strict not required).
6. Staging file tools/gen/staging/<group>.md with, per species, ready-to-paste Luau for the lead to merge:
   - Config.Species entry: { Name = "OVIRAPTOR", Era = "<Zone>", Income = n, KG = { a, b }, Color = Color3.fromRGB(...) }
   - Config.Combat entry (shape below; propose relative Dmg/Tele; lead sets Calm/Power):
       Stegosaurus = { Calm = 900, Speed = 12, Scale = 1.0, Gap = { 1.8, 3 }, Attacks = {
         { Id = "TailSwipe", Shape = "Cone", Len = 16, Angle = 120, Tele = 0.9, Dmg = 32, Back = true },
         { Id = "PlateRush", Shape = "Line", Len = 30, Width = 10, Tele = 1.1, Dmg = 34, Dash = true } } },
     Shapes: Cone{Len,Angle} | Line{Len,Width} | Circle{Radius} | Ring{Radius,Inner}; flags Dash, Back, Self,
     AtTarget, Stun, Reach.
   - Config.BuddyRole entry (fields Every, Mult, optional Stun, Area, Distract) with the role from the doc,
     plus a note if the doc's role needs new engine code.
   - Chase PURSUE line: { Scale, Run, Catchup, Lunge, Telegraph, Recover } (see Chase.luau for Stego/Raptor).
   - PaddockLife REACT line { Bow, Nuzzle, Butt, Wag }.
   - Whether it's a swimmer (water-only) or BIG (EraView gallery).
   - Icon prompt line for ICON_PROMPTS.md.
7. Water species (Sarcosuchus): see Spinosaurus/Mosasaurus files and the River reveal beat for patterns.

Babies are generated automatically from the adult (bigger head). Eggs are already defined in eggs.js.

## B. A new era (generator tools/gen/<file>.js)

Copy the structure of tools/gen/giantPlains.js (and look at spineRiver.js, the newest): origin constant, palette
P, marker(), route DEF with EXACTLY nodes { Arrival, ForkA, MergeA, ForkB, MergeB, Exit } (two forks, two
branches each), SECTIONS, NESTS (3, ids 1..3), FEATURES, DEN + FINAL (ruler arena), build<Zone>() returning
{ model, route, data }, routeData() with Zone, Name, Era, Year, Variants, Forks, Features, Sections, Nests,
Arrival. Export `module.exports = { build<Zone>, <X>_ORIGIN, QC: { decor: [...your decor Model names], ground:
/^(YourWalkableNames)$/ } }` so tools/gen/mapqc.js classifies your parts correctly.
Required markers (Luau looks them up by name): walkable folders Ground / Hills (or Swells) / Roads; nest Models
via the buildNestSite pattern (attrs NestId + Species, tag ExpeditionNest, NestCore with ProximityPrompt
GrabPrompt, GuardSpot1..3); ArrivalPortal + ReturnPortal (hexPortal with PortalLightHost); Cinematics folder
with EstShot1..4 markers (LookX/Y/Z attrs) framed on the era's best views; DenCenter (attrs RouteS, RouteX,
Variant), FinalArena, DenLedge1..6, Throne for the ruler; NpcSpot_Ranger via NPC.buildNpc. Run mapqc.clearRoad
like giantPlains.js (road clearance must print blocking 0). Eggs in nests: buildEgg(species) only works for
species in eggs.js (all new species are there). Part budget: aim for <= 22k parts (preview count printed).
The build writes tools/preview/out/<cliffs|frost|dawn>.json; view with
tools/preview/index.html?file=out/<name>.json&cam=x,y,z&look=x,y,z (world coords).
