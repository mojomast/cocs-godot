# P second completed-failure diagnosis

Candidate: frozen `3e97453a`. This source-only follow-up builds on `cd2b2017`
in the isolated sparse diagnosis worktree. No native verification is claimed.
This analysis was performed while the existing P supervisor remained the sole
engine owner. It subsequently completed; final 142-job tally and explicit grant
release are recorded in P_PROGRESS.md. New Moth/Blender map work requires its own
future candidate and acceptance.

Immutable evidence inventory (attempt scopes and SHA256s of retained JSON/logs):
`/home/mojo/.tmp-on-disk/cocs-release-matrix-P-20261003/diagnosis/completed-new-10.json`.
Only the ten requested completed failed attempts were inspected. No historical
passes were copied or failed receipts edited.

## Findings: ten gates, eight primary clusters

| Gates | Primary cause and severity/scope |
|---|---|
| map-finish-helix-native, map-finish-foundry-native, map-finish-parallax-native (3) | Environment/command defect: ALSA `ERR_CANT_OPEN`; each actual dressing proof reports `failures: []`, ready mounts and no unmatched selectors. Canonical engine-error rejection is correct. These remain failed, not hardware/human acceptance. |
| fighting-input-native (1) | Fixture numerical comparison defect: exactly 163 left and 42 right silhouette assertions. Source float32 emulation reproduces both counts across 459 cases, maximum overshoot 9.536743261762126e-08 metres. Adopt existing camera gate's 0.00001 numerical epsilon; no movement/contact threshold changed. |
| fighting-shell-native (1) | Guard input assertion fails after actual scene start. ALSA error also present. Focus/buffer/physics-frame timing is a hypothesis, not a proven production fault. Added before/after focused, paused, tick and command diagnostics, viewport focus/current-scene setup and buffered-event flushing. Original guard/pause/results assertions retained. |
| fighting-production-ui-journey (1) | Host prerequisite blocker: `/dev/uinput write access required for real virtual hotplug; no injected-signal fallback`. No UI journey actually ran. |
| fighting-plan-native-slice (1) | Fixture parse blocker at slice.gd:134: inferred Variant warning treated as error from `abs(int(...))`. Changed to integer `absi`; ALSA auto-probe is an additional command defect. No rendered slice outcome exists. |
| fighting-plan-journeys (1) | Fixture JSON-key contract mismatch: predicate rejects StringName keys while core codec permits them. Saved inventory values are all JSON-compatible types. Accepting StringName keys matches core serialization; exact roundtrip equality remains required. The 100-entry failure cap prevents exhaustive attribution. Paired throws and paired-throw continuation remain explicitly unrun, so this correction alone does not establish a pass. |
| fighting-plan-mechanics-extended (1) | Obsolete fixture assumes top-level saved.fighters; current save_state returns a checksummed envelope with state.fighters. All three scenario groups returned before checks (zero checks, zero assertion failures). Use existing public training_place with the same position/height/meter values, checking last_error. Seven explicitly deferred mechanic families remain unrun and prevent complete acceptance. |
| horde-rendered-compact (1) | Real bounded-progress failure: `normal-clock bounded wall time expired` at 620.201275 seconds, stage B, wave 4, only north/south feeder stations, three rewards; max input gap 1841.275653 ms. One overshield receipt records applied=0. No chain/victory pass, no timeout relaxation. |

The shared ALSA cluster affects **five** jobs total (three map gates plus shell
and slice), overlapping the primary causes above. Non-audio commands now select
Dummy explicitly in the isolated patch; real-audio jobs retain their own contract.
No production runtime files, fixed-60 authority, damage, deadlines, animation keys
or package pins changed. All proposed changes need a fresh native candidate.

## Follow-up: journeys combos fixture migrated (source-only)

`47b3633b` converted only `mechanics.gd` to the public training placement API.
`journeys.gd` `combos()` still carried the same invalid envelope mutation
(`sim.save_state()` followed by `fixture.has("fighters")` and
`fixture.fighters[...]`), so once the StringName predicate fix removed the
100-entry failure cap the combo path would have deferred every combo. This
follow-up migrates `combos()` the same way:

- `fresh([operator.id, operator.id], 23017, true)` and
  `sim.training_place({"fighters": placements})`, preserving the original
  distance / attacker_y / defender_y / meter values. Training mode changes only
  the round-clock skip in `simulation.gd:115`; startup, hitstun, damage, contact
  and replay assertions below the fixture are unchanged.
- A corner defender is placed at `stage_half_width - 350`: the exact x the
  simulation clamps to on the first step (`simulation.gd:139`) and the placement
  API bound. This agrees with the existing authored-combo fixture in
  `godot/tests/fighting/core/actual_content.gd:39-44` and preserves the authored
  initial distance. The original `- 330` differed by 20 units; clamping only its
  defender would change that distance, and contacts resolve before the end-of-step
  clamp. Therefore identical traces to the old hypothetical placement are **not**
  established. Fresh native contact/distance/replay checks must validate this
  corrected reachable fixture; their assertions remain unchanged.
- A rejected placement now records a real failure through
  `expect(sim.last_error.is_empty(), ...)` instead of silently deferring.
- `fixture` is re-read from `sim.save_state()` after placement, so the evidence
  written beside each trace records a valid checksummed envelope.

`paired_throws`, the paired-throw continuation and the seven deferred mechanic
families remain owner-deferred. This follow-up still claims no pass; the journey
gate needs a fresh candidate and a native run.

## Disk correlation

All retained JSON/log files under these ten completed attempts were hashed and
searched for `ENOSPC` / `No space left`: **zero hits**. The failures carry specific
parse/assertion/prerequisite/progress causes above. This does not establish that
the entire concurrent run was unaffected by disk pressure: a failed write can
leave no artifact. Final runner output/identity/cleanup must still be assessed at
its completion boundary. No asset copies or old-evidence deletion were used.

## Source verification

- `python3 -m unittest discover -s tools/fighting/acceptance -p test_acceptance.py`: 16 passed.
- `python3 -m unittest discover -s tools/fighting/acceptance -p test_native_command.py`: 2 passed, including preserving the real-audio contract.
- `python3 -m unittest discover -s tools/fighting/acceptance -p test_combos_fixture.py`: 5 passed. The combo fixture uses the public training placement with its `last_error` guard, and the scanner rejects the invalid save-state envelope pattern on synthetic input while finding no analogous mutation across the acceptance suite.
- Initial broad test discovery: 27 passed, one error because sparse checkout lacks
  `port/fighting/content/ANIMATION_COVERAGE.json`; that test also requires actual
  operator GLBs. It was not bypassed or labelled passed; no assets copied.
- Source-only arithmetic reproduced the exact original camera failure counts.
- GDScript execution and native repairs remain unverified under the isolated
  changes. The completed original candidate's final status is in P_PROGRESS.md.
