# Discovery audits (sequential; no delegated agents)

All three audits completed before candidate implementation. Prior delegation failures remain in PROGRESS.md. Baseline 2af744f8f2eef2087d056844dd7f973336215de2; primary reservation rechecked on resume and still names this external lane. No primary changes copied.

## A — runtime, attachment and package
world/actor_visual.gd:5–12 owns nine palettes and per-instance armor/identity; :31/:38 expose Helmet/Muzzle. :44–62 normalizes float teams and uses one/two visible stripes. Repository consumer search finds these fields in protocol/entity_visuals.gd:28–55, not gameplay authority. presentation.gd:44–72 allocates once per actor ID, applies identity, adds 0.9 Y, uses bodyYaw, hides self/dead, frees absent actors. :31–43 frees the round. remote_motion.gd:10–44 bounds samples, interpolates shortest-angle yaw without authority or extrapolation. local_lifecycle.gd:20–33 treats health <=0 as dead even when wire dead timer reaches zero.

entity_visuals.gd:34–47 measures immediate mesh children, requires feet -0.9/top +0.9, width <=0.701, negative-Z muzzle beyond 0.5. Preserve direct semantic MeshInstance children and stable Helmet node, including across character changes; replace cached mesh references, not nodes. No colliders, animation or nested rig in first candidate. Integration proposal: one preload change in presentation.gd, returned unapplied.

project.godot:12–15 uses Compatibility. tools/godot-package/build.py:100 collects tracked native files excluding tests/generated data; :159–161 exports resources but JSON inclusion only names map data. Candidate recipe JSON needs explicit inclusion or a resource-safe embedded representation. No shared packaging edit authorized. glb_side_import.gd:37–43 verifies imported CW winding; no GLB conversion should be applied to native ArrayMesh.

## B — visual direction and references
Read source models.mjs:476–513, operator-anatomy.mjs, model-geometry.mjs and character-anim.mjs:58–160. Profiles are a compatibility shim over kits, not anatomy requirements. Source intent: Claude Warden, ceramic shield; Grok Outrider, asymmetric industrial frame; Meta Bulwark, twin-turbine heavy chassis. These three provide clear geometry contrasts without changing all nine gameplay identities. Remaining six retain their existing identity palette on the common Warden chassis; explicitly not a bespoke nine-model roster.

Direct browser vision review succeeded for gallery entities.png: box-dominant oversized helmets/shoulders, narrow hips, separate legs, generic forward weapon, exact tiny stripe count not independently readable. Actual gameplay.png reviewed separately: operators are too small/occluded to judge; dark street contrast is a concern, not a proven character defect. Screenshots are distinct controlled vs real gameplay evidence. Gallery service untouched.

Choose faceted ceramic/metal plates with tapered waist, continuous upper-arm/elbow/forearm/hand chains, ankle/shin/knee/thigh separation, inset visor, jaw and crown. Keep subdued identity accents and red/blue shell with geometric team stripes. Neutral, side/back and 3/10/25m captures must judge the result, not this written brief.

## C — backend and performance
Actual pinned engine: 4.5.2.stable.official.6ce3de25a. Xvfb present; Blender absent from PATH. Existing baseline.log: 26 mesh instances, 26 surfaces, 624 vertices, 312 triangles, 4 materials, 27 nodes. Eleven-sample off-tree population construction medians: 1=113us,16=1735us,32=3518us. Not frame time or draw calls.

Choose native ArrayMesh: small deterministic chamfered/tapered octagonal prism vocabulary; offline authored data recipes, shared cached geometry and per-actor materials. Blender is unnecessary for this first rigid stylized candidate; no dependency installed. Godot official 4.5 ArrayMesh.xml fetched and read: add_surface_from_arrays and CW winding confirmed; engine execution remains required. Cache only finite approved recipes, not arbitrary caller hashes. No random variation; seed=0 is provenance, not a reproducibility claim alone.

Research read in full; SHA256 414f1a9e6d6285f87ad5aaf09027ff018e95d726653a9f0ae8401f84771a872e. Original geometry is newly authored; identity intent/palette and generic weapon dimensions derive from this repository. Existing repository/asset redistribution rights remain unresolved, not cleared by this lane.
