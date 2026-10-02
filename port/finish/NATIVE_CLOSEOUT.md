# Native integration closeout — 2026-10-02

Runtime checkpoint: `f2c82794de6f009a245b3464956277fc659aea3c`.
Branch: `finish/integration-20261002`. Overall acceptance remains incomplete.
This closes the granted pass so parent can schedule fighting animation production;
it does not remove any baseline gate from the release requirements.

Evidence root (`E` below):
`/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002`.

## Immutable checkpoints and evidence

- Canonical `e38b3662` merged once; content `672c81a7` cherry-picked as `d5eae157`.
- `e95e379a`: combat-clock landing recovery, including committed air attacks,
  decremented exactly once outside hitstop; native regression tests real landing,
  hitstop and legal grounded follow-up. Persistent pair recovery retained.
- `c05ea057`: Replay ownership and exact incremental queue accounting.
  `E/final-core-replay/` passes production, queue, core, invariants, actual content
  and pair-seek. `E/actual-content-54-route-summary.json` gives **54/54 passes**,
  both facings, route contacts/continuity/replay equality and full-report SHA-256.
- `cad1f411`: threaded Replay loopback transport. `E/run-31f339wh/` passes the
  connected 17-check record/save/discard/reopen/seek/play/pause/teardown journey,
  with no queue-full rejection or engine resource leak. The receipt pins the
  pre-commit bytes that became this commit.
- `3926d228`: LATTICE admits valid spectator starts and public snapshots without
  requiring an actor/private projection; diagnostic/ordinary pointer Retry fixture.
  Connected acceptance remains failed; see below. Production load passed in
  `E/closeout-signs-14/production.json`.
- `f2c82794`: Helix baked wayfinding front/culling correction. The original font
  meshes faced opposite the recipe's intended front; Moth architectural shaders
  also disabled culling. Rotate the three instances and preserve one-sided font
  materials, leaving shared meshes/GLB/text/authority unchanged. All three normal
  directions and culling checked in `E/closeout-signs-15/`; native Off/Low/Full,
  mounting and teardown pass. Same-camera Full image is
  `E/closeout-signs-15/helix-conservatory-2.png`, now readable rather than mirrored.
  Failed first proof (ShaderMaterial cull access) retained in `closeout-signs-14`.

## Moth evidence scope

`E/moth-native-02/`: clean production load, all-nine operator imported tangent/UV/
material/team lifecycle and both map proofs. `E/moth-districts-final/`: eleven
district Off/Low/Full runs, clean process teardown; original archive capture is
superseded by `closeout-signs-15` for sign quality. `E/operator-captures-refined/`:
17 production-lighting staged captures, all-nine sheet, motion/LOD phases, nine
four-way original/Moth red/blue comparisons. Parent reviewed Meta team contrast.
These llvmpipe captures are not production-GPU timing or human-feel acceptance.
`E/moth-original-glb-identity.json` pins eleven unchanged original map/operator GLBs.
Parallax is not registered or claimed as exported proof.

## Remaining ownership and exact repros

Parent schedules the **next integration acceptance owner** for every row below.
These remain assigned integration work, not externalized or waived failures.
Use `tools/godot-dev/finish_runner.py --run --grant engine --evidence <new-root>`
with `--select native-version --select native-import` and the listed job IDs;
include prerequisite IDs from `port/finish/matrix.json`. Stock Godot 4.5.2,
`LP_NUM_THREADS=1`, and a new explicit grant are required.

| Work / gate IDs | Retained exact receipt and remaining failure |
|---|---|
| `gameplay-rope-reconnect` | `E/run-1tdw_lph/report.json`: native guest journey failure; do not conflate with earlier interrupted signal-15 attempt |
| `world-connected-campaign` | Same run: ordinary input did not move public actor |
| `spectator-mode-wide` | `E/run-99yb89rp/`: ordinary keyboard target-cycle failure; previous `run-8hlgv472` and `run-d85qj9m4` retain reconnect admission timeout, phase -5 |
| `spectator-world-wide` | `E/run-99yb89rp/`: reaches public comparison but fails `exact received source-clock snapshot retained` in `connected-native.mjs:99`; earlier `run-d85qj9m4` timed out waiting for spectator live command. LATTICE code fix is compiled, not end-to-end accepted |
| Other `spectator-*-wide/compact` variants | `E/run-1tdw_lph/` and `E/run-4bkf0gxo/`: per-route focus, target-button, live-snapshot failures. Retest all variants on reconciled input; zero actor packets/privacy requirements remain intact |
| `controls-combat` | `E/run-4bkf0gxo/`: 90 assertions pass, two GL texture leaks still fail strict teardown |
| `horde-boss` | `E/run-1tdw_lph/`: clean prerequisite chain, boss victory not achieved within source 900-second limit; requires `horde-boss` grant too |
| `horde-rendered-wide`, `horde-rendered-compact` | Same run: rendered progression/cadence requirements failed |

`E/baseline-latest-observations.json` is a cross-candidate index only, not a
single-candidate acceptance attestation. Full failed nested logs remain retained.
No further full matrix was launched for closeout.

Parent/FX owner must reconcile **`60ce2132`** before packaging: this branch's FX
catalog/contract still pins `a736dcfe…`; actual revised roster is
`1cb28db7f34fefe3c37ccb8f4b5a54822465d2b28fa8a6401ab0fa8fd77e5e02`.
No parent `cbdaa3f5` merge was performed. Parent retains final art and Windows
closure reconciliation. No Windows export/CI was launched here.

Real driver audio remains blocked by inaccessible `/dev/snd` and absent Pulse
socket. Hardware input, human layout/feel, production GPU, extracted packages,
final fighting GLBs and publication remain with their respective acceptance owners.

## Explicit heavy release

**`FINISH-COMBINED-NATIVE-20261002-A` RELEASED at 2026-10-02T20:49:20Z.**
Current targeted run completed; focused sign proof stopped cleanly; fresh `/proc`
inspection found no owned Godot/runner/Blender/Node/Xvfb heavy process. Final
cleanup reports `remaining: []`. Exact receipt: `E/HEAVY_GRANT_RELEASE.json`.
Unrelated parent gallery/viewer processes were not stopped. No further heavy work
is authorized by this released grant. Parent can issue the next Blender grant.

All tracked edits are committed. Generated untracked `.uid`/`.import` metadata and
the existing `.godot` cache are preserved. No `game/` or `server/` changes made.
