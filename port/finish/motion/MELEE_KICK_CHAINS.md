# First-person articulated accepted-kick chains

## Implemented

- Replaces the rigid four-piece foot with a Hip → Knee → Ankle → Toe hierarchy: shaped thigh and calf, thigh plate, trouser seams, kneepad/inset, shin armor and vents, calf straps/buckles, boot cuff/bellows, heel counter, laces, welt, outsole, individual angled tread lugs, toe cap and scuff plate. Rounded elliptical section meshes are generated once, not per frame.
- Nine explicitly named operator profiles use the existing source catalog's linear palette converted to display colors; proportion differences preserve a recognizable shared armored operator silhouette. No external generated assets or new import pipeline.
- Lead push, opposite-leg cross snap, heel drive have distinct hip rotation, side, knee extension and weapon counterbalance. Six eased phases finish in **0.290 s**, before the **0.300 s** authority cooldown. Visual contact is **0.095 s after event receipt**; damage and contact sound/ring already happen at authoritative acceptance. This deliberate presentation offset is not a second hit.
- Ordinary accepted melee events advance the sequence if the previous action confirmed a hit and the source-time gap is 0.299–0.850 s. A miss/blocked result animates the current strike but breaks the next continuation. The third strike wraps to lead. Timeout and interruption reset to lead.
- Existing rig event deduplication (4096 bounded entries), hidden consumption, and hit feedback remain authoritative. The new model also rejects non-monotonic/replayed IDs/timestamps. No input buffering, synthetic presses, delayed retry, damage multiplier, extra damage event, target lock or combat protocol change.
- ADS yields during the kick and can resume from held aim after recovery. Existing reload/sprint/switch snapshot gates interrupt the pose; weapon selection, death, actor change, focus/session hide, round/reset clear it. Reduced motion decreases weapon weight shift; essential leg articulation stays readable. Mesh surfaces are detached by the existing rig teardown before resources are released.
- Leg stays in the existing isolated first-person viewport, inheriting its FOV/aspect/projection synchronization and near plane. World hit feedback was intentionally left at its existing one-confirmation behavior.

## Public contracts for other lanes

`rig.interrupt_kick()` clears presentation and continuation while retaining replay watermark. Call it for any additional locomotion interruption the movement lane introduces. No `inertia.gd` or `session_binding.gd` changes are required here.

`rig.get_kick_state()` returns `step` (1–3), `strike`, `age`, `active`, `confirmed`, `accepted`, `contact_seconds`, `duration`, `chain_window`. Third-person consumers can explicitly preload `res://first_person/kick_motion.gd`, feed **accepted authoritative melee events only**, and use its `sample()` hip/knee/ankle/toe rotations. Camera-space `root` and weapon offsets are FPS-specific and must not be applied to world actors. This lane does not edit operator files.

These are **sequenced accepted kicks**, not a new bonus-damage combat combo system. A buffered or damage-changing system would need a separately approved port-owned action adapter and protocol agreement; none is proposed as necessary for this accepted-press sequence.

## Verification completed (source-only grant)

- `node --test game/melee.test.mjs`: **9/9 pass**, including real authority rising-edge input, discarded early presses, held input beyond cooldown, exactly three fresh accepted events, damage/cooldown, misses, protected targets, occlusion, team and lifecycle rejection.
- `uv tool run --from gdtoolkit gdparse ...`: parser checks on changed rig/helper scripts and prepared native tests. Parser checks are not Godot static-type/import validation.
- Native regression prepared: `godot --headless --path godot --script res://tests/first_person/kick_chains.gd`. It exercises timeout, miss reset, replay suppression, interruption, frame-rate-independent settle, three contact poses, reduced motion, all nine profiles and joint hierarchy. **Not executed: exclusive native grant pending.**

## Native evidence pending

After exclusive grant, run the regression above plus existing `tests/protocol/melee_feedback.gd` and first-person lifecycle/ADS suites. Import/type-check all explicit preloads. Then run:

`godot --path godot --script res://tests/first_person/kick_capture.gd`

This prepares 1280×720 images in `user://kick-capture/`, all nine profiles × three strikes × 35/65/95/185/290 ms, with the actual first-person weapon viewport. Inspect near-plane clipping, toe/sole silhouette, leg/receiver overlap and exact recovery. These offline pose captures are **not authoritative-input evidence**.

For live acceptance, record normal F press/release at ≥0.30 s intervals against a surviving target, plus early press held through cooldown, miss, blocked contact, timeout, ADS, reload, swap, sprint, death/respawn and Home. Log authoritative melee IDs/outcomes beside `get_kick_state().accepted`; each accepted ID must increment once and feedback must remain one whoosh plus at most one confirmed impact. Preserve counts and screenshots for kick1/2/3. No screenshots, runtime type-check, live event trace or native visual-quality claim exists yet.

## Sources

- Authority audit: `game/core.mjs` `MELEE`, `melee()`, rising-edge `meleeHeld` handling; `game/melee.test.mjs`.
- Existing adapter: `godot/first_person/session_binding.gd` routes session accepted events; rig has no action send path.
- Anticipation: https://education.siggraph.org/static/Drupal_2025/education.siggraph.org/static/HyperGraph/animation/character_animation/principles/anticipation.html
- Weight shift: https://studio.blender.org/training/animation-fundamentals/5d69b398c4769bb8cceb0709
- Animation principles: https://www.dgp.toronto.edu/~patrick/csc418/notes/tutorial11.pdf
