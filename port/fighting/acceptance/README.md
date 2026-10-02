# Independent fighting acceptance

**Prepared for merged engine; native execution is unrun.** Base `37dd3da4` has no
`godot/fighting/` implementation/data/assets. This lane has not run Godot,
Blender, imports, audio or capture. Helix owns the heavy resource until the parent
explicitly grants a serial run. Prepared scripts have not received a native parse
check. Source checks cannot certify game mechanics, animation quality or shipping.

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
python3 tools/fighting/acceptance/run.py native --gate journeys \
  --heavy-grant PARENT-GRANT-REFERENCE --godot /absolute/path/to/Godot_v4.5.2-stable_linux.x86_64
python3 tools/fighting/acceptance/run.py native --gate native-assets \
  --heavy-grant PARENT-GRANT-REFERENCE --godot /absolute/path/to/Godot_v4.5.2-stable_linux.x86_64
```

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
  vertices and valid joints, state/data clip names, numeric channel fingerprints.
  Shared numeric curves in identity/move clips fail; curve differences do not
  establish distinctive art.
* `journeys.gd`: all nine mirrors and 36 distinct pairs in both actor orders,
  separate mirrored simulation (negated horizontal inputs) with damage/state/
  movement parity, 720 consecutive ticks each; two fresh instances and JSON
  save/load continuation every later frame; deep detached snapshot/save/load;
  required snapshot/event shape, non-colliding event content within match;
  held attack/negative-edge checks; ordinary-input forward/back paired throws
  for nine fighters on both sides, authored first-hit damage exactly once,
  back throw side swap, victim release and paired-state replay;
  authored move-ID combo scheduling through actual cancel windows with actual
  intended moves and consecutive damage in hitstun; nine full seeded AI matches,
  actual damage, complete rematch reset. No health/position writes or training
  cheat paths, including setup: actors walk together via ordinary inputs.
* `assets.gd`: actual native PackedScene, Skeleton3D, mesh skins,
  AnimationPlayer clip names and finite sampled rest/pose transforms, reject
  method-call tracks, actual visual configure per operator. Five samples/clip
  catch corrupt transforms; they are not contact/anatomy or visual approval.

## Merge blockers / clarify before interfaces diverge

The exact v1 APIs in DESIGN.md win over research proposals (neutral vertical SOCD,
negative edge off, independent guard button, nine fighters, no harness fighters).
These are recommendations to coordinate, **not new runtime API requirements**:

1. **Combo `inputs:[...]` entry shape is undefined.** Prepared adapter handles
   stable move-ID strings using data cancel windows; other entries are explicitly
   unrun. Prefer documented tick spans of real InputCommand values with pressed
   only on the first tick, relative-forward axis semantics, plus declared initial
   neutral/corner/air setup and expected move/contact sequence. Do not turn the
   simulator's observed answer into the oracle. Merge the actual content schema
   and extend this adapter before marking all 27 routes/both facings covered.
2. **Timeline indexing / buffer / tech boundary:** specify whether `move_frame`
   starts at 0 or 1, startup first active frame, six-frame inclusion, whether
   hitstop ages queued inputs, throw-tech start/last frame, and jump-axis polarity
   (+1 up assumed here). Tests must cover exact boundary and one-frame-late cases.
3. **Saved state inventory is semantic, not structurally enumerated.** Core owner
   should document all keys and meanings for RNG, input histories, held edges,
   buffers, hit ledgers, projectile IDs, throw pairs, invulnerability/cooldowns,
   resources, rounds/events. Current complete dictionary equality detects
   divergence but cannot prove an omitted latent field until its relevant
   transition is exercised. AI public API has no save/load: document the
   session-level persistence path for AI RNG/decisions before claiming AI replay.
4. **Events:** `step` versus retained snapshot event history needs documentation.
   Current ledger allows identical re-exposure and rejects reused IDs with
   different payloads. Document atomic contact IDs to distinguish a real duplicate
   damage application from legitimate repeated presentation of the same event.
5. **Mechanic option fields:** projectile range/clash/reflect, throw phases/range/
   damage frame, counter windows, juggle/scaling floor and resource subfields are
   pending. Coordinate exact keys and expected numeric outcomes rather than
   writing a second core or assuming unsupported mechanics pass.
6. **Stage, shell and FX observation hooks:** stable stage IDs/build API,
   input/device routing and release entry points, live Home route, tick/AI-call
   counters, FX live-node/event counters and budgets are not in v1. Coordinate
   read-only observations or use native scene inspection once merged. Merely
   calling `consume/reset` is not proof of dedup or budget behavior.
7. **Anatomy descriptors:** animation owner must provide authored contact sockets,
   planted-frame intervals, target coordinates and tolerances, throw victim clip
   coverage, Blender master paths and provenance. No self-generated reference
   from the same animation under test; compare to authored fixtures.

## Required follow-up, explicitly unrun

`plan.json` is the full acceptance inventory; prepared narrow scripts are not the
whole inventory. `mechanics-extended`, `shell-fx-capture`, `blender-reopen` refuse
execution until real fixtures/entrypoints exist. No placeholder pass markers.

Extended mechanics must cover each of 15 families for every fighter, independently
expected damage/guard/meter, all buffer/tech boundaries, command throws/escape/
trade, throw invulnerability and KO interruption, simultaneous trades, clash/
reflect ownership, swept projectile hit-once, queued hitstop inputs, real input
adapter SOCD, facing lock, finite resource/projectile/juggle/bounce/OTG loops,
negative malformed data/input. Add per-category save checkpoints for hitstop,
airborne, projectile, paired throw and pending input; compare every later frame
through the relevant transition, not merely one loaded snapshot. Current matrix
saves at the first live condition; the separate paired-throw route covers pairs.
AI matches require later explicit KO versus timeout coverage and persisted AI
save/load in addition to current fresh-instance seeded equality.

Native capture must produce nine operator side-on sheets **in the actual stage**,
1000 simulation units/metre, with both fighters, startup/contact/recovery and
paired-victim contact, native bone/socket measurements against the declared
fixtures. Record UTC capture timestamp, simulation tick, native animation frame,
render frame index and monotonic frame cadence for every image. Cover three
stages at maximum separation/jump, wide/compact/UI150, low/reduced modes.
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
