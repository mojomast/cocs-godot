# Independent fighting acceptance

**Prepared for merged engine; native execution is unrun.** Base `37dd3da4` had no
`godot/fighting/` implementation/data/assets. Content `827d24a8` + `79d98652` is
now consumed: real data has 138 moves, 27 proposed combo routes and 25 paired
timelines resolving for nine possible victims each. Common rest skeletons,
shared motion libraries and victim aliases are permitted by parent correction;
225 duplicated stored clips are **not** required. Independent source checks pass real
data; core/AI and all nine authored GLBs are still absent here. This lane has not run Godot,
Blender, imports, audio or capture. Foundry owns the heavy resource until the parent
explicitly grants a serial run. Prepared scripts have not received a native parse
check. Source checks cannot certify game mechanics, animation quality or shipping.
The latest parent update assigns the heavy slot to Foundry; no grant is implied.

## Commands

From the merged candidate root:

```sh
python3 tools/fighting/acceptance/run.py plan
python3 -m unittest discover -s tools/fighting/acceptance -p 'test_*.py' -v
python3 tools/fighting/acceptance/run.py source
```

Source returns 2 for absent dependencies, 1 for invalid real data/GLBs, 0 only
for completed source checks. Unit fixtures test the validator and evidence
refusal, and never substitute for missing production assets or simulation.

After an explicit parent grant and merge of the finish supervisor:

```sh
python3 tools/fighting/acceptance/run.py native --gate native-slice \
  --heavy-grant PARENT-GRANT-REFERENCE --godot /absolute/path/to/Godot_v4.5.2-stable_linux.x86_64
python3 tools/fighting/acceptance/run.py native --gate journeys \
  --heavy-grant PARENT-GRANT-REFERENCE --godot /absolute/path/to/Godot_v4.5.2-stable_linux.x86_64
python3 tools/fighting/acceptance/run.py native --gate native-assets \
  --heavy-grant PARENT-GRANT-REFERENCE --godot /absolute/path/to/Godot_v4.5.2-stable_linux.x86_64
```

Run the actual Meta/Mistral slice first; then inexpensive parametric mechanics
and all-roster checks, then representative visuals/hazards across the nine actors.
There is no 81-match visual sweep or 480-case synthetic FX capture prerequisite.
One native job per invocation; the parent schedules the exclusive slot. A local
lock prevents this runner's overlap but is not permission to overlap Helix or
another resource owner. Reuses `gate_runner.save_report` now and the parent-owned
`finish_runner.run_bounded` + `isolated_environment` after merge: deadlines,
Linux subreaper, owned descendants only, leak failure, isolated HOME/XDG/stores,
`LP_NUM_THREADS=1`. Missing finish supervisor is a deferred dependency, not a
reason to fork another process-management framework. No global runner/package
files are modified.

Evidence defaults to
`/home/mojo/.tmp-on-disk/cocs-fighting-verification-evidence-20261002`.
Every invocation creates a unique timestamp/nonce directory, candidate path→SHA256
inventory (including dirty runtime/data/GLB bytes), Git HEAD, command, binary hash,
grant reference, bounded logs, native report, before/after identity and final
`SHA256SUMS.json`. A later invocation never overwrites earlier evidence. Preserve
this directory as immutable archival evidence; final hashes reveal alteration.
Native success requires zero exit, no engine errors, exact whole-line marker,
nonempty structured checks and zero failures/unrun within that gate's scope.
The global acceptance plan retains separate unrun criticals even if a narrow
gate passes.

## Implemented independent gates

* `source.py`: exact nine roster/135 required move families/three combos each,
  required fields, bounds, legal cancel targets and intervals, rules at v1 values;
  actual GLB JSON+BIN/accessor decoding, finite numbers, skins with weighted
  vertices and valid joints, numeric channel fingerprints. Shared libraries and
  aliases may supply clips outside the body GLB. Identical stored signature
  curves are reported for effective-native-motion review, not rejected by name
  hashes; distinctive authored signature motion still needs proof. Common rig
  rest equality never proves mesh/contact/penetration/body extents across nine.
* `journeys.gd`: all nine mirrors and 36 distinct pairs in both actor orders,
  separate mirrored simulation (negated horizontal inputs) with damage/state/
  movement parity, 720 consecutive ticks each; two fresh instances and JSON
  save/load continuation every later frame; deep detached snapshot/save/load;
  required snapshot/event shape, non-colliding event content within match;
  held attack/negative-edge/forged-pressed checks, derived edges without caller
  hints, C1 down=-1/up=+1, hitstop freeze of move/stun/physics, JSON-restored
  authoritative integer types; ordinary-input forward/back paired throws
  for nine fighters on both sides, authored first-hit damage exactly once,
  back throw side swap, victim release and paired-state replay;
  actual content sparse InputCommand traces, missing ticks release, duration
  holds without repeating edges, initial-facing axis conversion, real charge
  setup; actual intended damaging event order and strictly positive consecutive
  hitstun; nine full seeded AI matches, actual damage, complete rematch reset.
  Combos use exactly one documented initial save/load fixture for x/y/meter,
  no HP edits and no writes after setup. Defender follows charge walking using
  ordinary inputs to preserve relative distance. All other journeys approach by
  walking. No training cheat paths. Per-combo full command/state traces are saved.
* `assets.gd`: actual native PackedScene, Skeleton3D, mesh skins,
  **configured** AnimationPlayer library/alias resolution and finite sampled
  rest/pose transforms, reject method-call tracks, real visual configure per operator. Five samples/clip
  catch corrupt transforms; they are not contact/anatomy or visual approval.
* `mechanics.gd`: 15 families × nine × both sides, actual charge commands,
  authored single-hit damage, projectile lifetime, movement probes, independent
  high/low guard outcomes, real paired tech first/tenth/late boundary, uncharged
  DeepSeek/Grok rejection. Its explicit unrun list refuses full mechanics success
  until remaining scenarios are implemented. Prepared against content, not yet
  reconciled by native execution; finite movement/counter cases need scrutiny.
* `slice.gd`: first rendered native Meta/Mistral proof on actual Basalt builder,
  ordinary walking/strike/throw-tech, visual/FX/camera adapters, 1000-unit actual
  event-contact measurement, real event dedup, projectile presentation bridge,
  pause/reset/malformed-event/bounded-node metrics. Native PNG captures record UTC,
  monotonic cadence, render frame and authoritative fighter frames. Muted first
  slice explicitly leaves audio, human art and authored contact anatomy unrun.

## Merge blockers / clarify before interfaces diverge

The exact v1 APIs in DESIGN.md win over research proposals (neutral vertical SOCD,
negative edge off, independent guard button, nine fighters, no harness fighters).
These are recommendations to coordinate, **not new runtime API requirements**:

1. **Combo schema resolved by content CONTRACT_DETAILS.md.** Sparse absolute ticks,
   setup_inputs, explicit durations and proposed routes now drive the test.
   Ground fixture distance 550 is smaller than authored 660-wide pushboxes;
   an exact first-attack-distance assertion exposes this instead of silently
   altering fixtures. DeepSeek setup charge lasts 36 ticks, normal attacks retain
   back before release into S1; the harness does not grant charge by writing it.
   Core must document safe initial fixture keys (currently requires saved
   `fighters`) and authoritative treatment of overlapping ground pushboxes.
2. **Timeline indexing resolved as zero-based** by content. C1 pins down=-1/up=+1,
   derives pressed from held history (caller hint is not authority), and hitstop
   records inputs while freezing move/stun/physics. JSON roundtrip must restore
   validated authoritative integers, not just accept raw save/load equality.
   Still coordinate
   six-frame buffer inclusion, whether
   hitstop ages queued inputs, throw-tech start/last frame, and jump-axis polarity
   Tests must cover exact boundary and one-frame-late cases.
3. **Saved state inventory is semantic, not structurally enumerated.** Core owner
   should document all keys and meanings for RNG, input histories, held edges,
   buffers, hit ledgers, projectile IDs, throw pairs, invulnerability/cooldowns,
   resources, rounds/events. Current complete dictionary equality detects
   divergence and records a recursive observed key/type inventory, but cannot
   prove an omitted latent field until its relevant
   transition is exercised. AI public API has no save/load: document the
   session-level persistence path for AI RNG/decisions before claiming AI replay.
4. **Events:** `step` versus retained snapshot event history needs documentation.
   Current ledger allows identical re-exposure and rejects reused IDs with
   different payloads. Document atomic contact IDs to distinguish a real duplicate
   damage application from legitimate repeated presentation of the same event.
5. **Mechanic option fields now authored:** consume CONTRACT_DETAILS.md and rules
   literally, with core reconciliation pending. DeepSeek back charge36/release6,
   Grok down18, Gemini three stance moves and independent air-use counter, Qwen
   120-ground-tick regen/one-hit anchor, Claude reflect/counter-grab. Coordinate
   numeric expectations rather than assuming unsupported mechanics pass.
6. **Stage/FX now concrete in supplied fixed commits:** slice consumes
   `backdrop.build`, `camera.present`, FX `metrics`, `present_projectiles`,
   `present_fighter`, `set_paused`, `reset`, and measures actual node/counter
   changes. The source was read at `c995ba66` / `52c74a0c`, not polled on active
   branches. Core/rig/FX/presentation still need combined native run. Shell
   focus/device/live Home and AI-call observations remain separate work.
7. **Anatomy descriptors:** animation owner must provide authored contact sockets,
   planted-frame intervals, target coordinates and tolerances, throw victim clip
   coverage, Blender master paths and provenance. No self-generated reference
   from the same animation under test; compare to authored fixtures.

## Required follow-up, explicitly unrun

`plan.json` is the full acceptance inventory; prepared narrow scripts are not the
whole inventory. `mechanics-extended` executes prepared checks but refuses success
with unresolved criticals. `shell-fx-capture` and `blender-reopen` refuse execution
until real fixtures/entrypoints exist. No placeholder pass markers.

Extended mechanics must complete independent meter, all buffer/tech boundaries, command throws/escape/
trade, throw invulnerability and KO interruption, simultaneous trades, clash/
reflect ownership, swept projectile hit-once, queued hitstop inputs, real input
adapter SOCD, facing lock, finite resource/projectile/juggle/bounce/OTG loops,
negative malformed data/input. Matrix forks at hitstop, airborne and projectile
conditions and compares every later frame; paired-throw routes separately fork
the pair. Each category must actually be reached somewhere. Pending-input
checkpoint coverage and full semantic saved inventory still need reconciliation.
AI matches require later explicit KO versus timeout coverage and persisted AI
save/load in addition to current fresh-instance seeded equality.

After the first slice compiles/plays, native capture must produce nine representative
operator side-on sheets **in the actual stage**,
1000 simulation units/metre, with both fighters, startup/contact/recovery and
paired-victim contact, native bone/socket measurements against the declared
fixtures. Record UTC capture timestamp, simulation tick, native animation frame,
render frame index and monotonic frame cadence for every image. Cover three
initial stages plus accepted-parent Helix revision2 lightwell (four total) at
maximum separation/jump, wide/compact/UI150, low/reduced modes. Helix's fighting
stage framing still requires actual native inspection.
Numeric fingerprints, procedural sketches or a neutral studio cannot replace
these sheets. Blender reopen and human inspection remain separate criticals.

Shell/FX journeys must measure actual dedup/reset/malformed-event behavior and
node/particle/audio budgets; bind two actors; release on focus/modal/device loss;
verify no AI stepping while inactive/paused and exact resume tick count; live
Home unload and optional authority-runner PID inventory; assert isolated stores
unchanged by fight results. Real GPU performance, native audio, human feel/balance,
Windows/Linux exported resource closure remain unrun.

Package proposal is data in `plan.json` only: fighting main/data/assets plus
dynamic stage dependencies, tests excluded like normal repository packaging.
Parent applies canonical hooks only after actual focused gates pass.
