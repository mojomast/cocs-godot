# Horde narrow defect repair — integration remains HOLD

**The requested localized repairs are implemented and the bounded acceptance
cases pass. Common/launcher/package acceptance remains HOLD until the lead
independently replays the fixes.** Full aggregate and packaged Linux gameplay
verification were **not run**. Campaign remains deferred.

Worktree `/tmp/opencode/horde-repair-59c2b33`, branch `repair/horde-boundaries`,
was created from the independent review `59c2b33c3080845eb73f8490b3dc9e355117c000`.
The delivery/runtime ancestry remains separate from this repair. No agents,
merge, push, deployment or shared service restart was used.

## Commits and ownership

Runtime/helper commits, in order:

1. `74d0e277e193e90b860b46143857d9bda4ce060a` — input FIFO/ACK, event cursor,
   resource bounds, clock, local native controls/layout, observer and validator.
2. `25eae77fb593ddb0a4211850d5d1a7e0ea6b87aa` — compact control help and viewport
   bounds after direct inspection of the first Ember repair attempt.
3. `48d1029d7b29d730a85dfd47cd0af14f10dcc221` — JSON-representation correction in
   stepped-input evidence comparison; preserves optional-field semantics.
4. `50521191ee6922295a50448301e929d945926ef9` — source-default ADS look multiplier
   and source-derived look vectors. This is the **final runtime tip**.

All runtime changes are under `godot/horde/`, `godot/tests/horde/` and
`port/native-horde/`. This new report tree is committed separately. Source
`Match`, `game/`, `app/`, public `server/room.mjs`, shared session/client/HUD/
Scoreboard, launchers, packaging, aggregate gates, root files and source locks
are untouched. The localized `horde/scoreboard.gd` extends the shared class;
it does not edit that class.

`audit.json` verifies **119 original review/delivery evidence files byte-for-byte
against their baseline git blobs**, including the failed independent product
run. It also records original SHA256s, source Match SHA256, runtime/launch hashes,
all four fresh repair outcomes, PNG sizes/hashes and closed-port/absent-PID checks.

## Repairs and meaningful before/after evidence

Historical `PROPOSED-FIXES.md` enumerated outbound bounds separately (F1–F7).
The six requested repair areas are covered as follows:

| Area | Localized repair | Evidence |
|---|---|---|
| Ordinary inputs and applied ACK | Source desktop press/hold split, native tap latch, 16-sample FIFO, one sample per source step, explicit receipt/applied/cancel status and epochs | Old fire press/release: **ACK 2, shots 0**. New: **ACK 2, shots 1**, with steps 1/fire then 2/release. Cancellation and stale-epoch probes fail old/pass new. 31 native source-derived input vectors pass. |
| Source string event IDs | Cursor from source serial and event-ring append position; wire serial `id`, unchanged payload `sourceId` and `type` | Genuine first-wave `horde-modifier/sourceId:swarm` missing old, present new, including all live runs. Repeated opaque IDs and ring overflow tested. |
| Transport errors and bounded resources | Pre-upgrade rejection; WS error handlers; 16KiB payload; message-rate, input FIFO, outgoing frame/backlog and HTTP connection bounds; owned teardown | Old oversized frame crashes child with unhandled WS error; new peer closes and listener accepts reconnect. Valid-message flood and synthetic socket-backpressure probes fail old/pass new. |
| Source elapsed scheduling | Actual monotonic elapsed accumulator, unchanged 1/60 steps, source five-step backlog cap, round reset after construction | Old diagnostic: 4.65 source s / 4.485848458 wall s = **1.036593×**. Final diagnostic: 4.5 / 4.501154807 = **0.999743×**. No injected clock or dt. |
| Product HUD/Scoreboard composition | Horde-owned Scoreboard layout reserves the strip and recalculates paging; observer instances actual product scene as child | Old layout overlaps at both sizes (0/2); fixed layout **2/2**. Fresh real results screenshots show strip and full Scoreboard clear at 960×640 and 1280×800. |
| Fail-closed evidence and resource exits | CLI requires clean harness/resource/cleanup status, explicit trace end, actual product composition and source/receipt/step/native correlation | Retained independent failed run is rejected, including when its nominal exit is replaced with zero but resource log retained. Old validator accepts it. Root-script replacement leak independently attributed below. |

`regression-old.log`: **0/9 pass, 9/9 expected failures** against the actual
committed old adapter/validator loaded from `59c2b33` (imports resolve to the
unchanged source/dependency tree). `final-adapter.log`: **29/29 pass** = original
14 adapter/validator cases + 9 differential cases + 6 queue/event/boundary cases.
The cancellation/epoch probes exercise the explicit new local safety contract;
they are not claims that the old adapter advertised those extensions.

The failed TAP output is also preserved byte-for-byte in `regression-old.log.gz`
(uncompressed SHA256 `1f0c3b9bbbfd97258afd05b4d8cf8d56942ac9786f39b6641109d3d486fd72c5`).
The readable `.log` removes only trailing whitespace from nine blank TAP lines
so the complete repair diff passes the repository whitespace check.

The outgoing-backlog probe overrides only the server WebSocket's reported
buffered byte count. Layout tests use synthetic state. Neither is a source
gameplay or load-performance result. Clock ratios are **normal-rate diagnostics**,
not benchmarks or timing guarantees. Callback jitter and a discarded overloaded
backlog remain possible under the source five-step policy.

### Source research and input contract

The implementation follows `game/keybinds.mjs:5–12`,
`game/input.mjs:35–65`, `app/page.tsx:637,878–905` and
`game/config.mjs`'s default ADS sensitivity. Important distinctions:

- Fire is held plus a one-step tap latch. Jump is held/autohop plus a press latch.
  X mobility and Z/middle alt-fire are held; the source derives their edges.
- E interact, R reload, Q power, F melee, G grenade and weapon selection are
  per-step press actions. Holding E/R no longer reissues actions each send.
- Shift sprint, Ctrl/C crouch and right-mouse ADS are held. All ordinary source
  action fields are carried. Native mouse gain is 0.002, with source-default
  0.85 ADS scaling; defaults for per-sight scaling are all 1.
- Source Match normalizes diagonal motion. Native normalization before the
  existing protocol parser's per-axis clamps preserves that source direction.
- Samples are not coalesced over a fire edge. Queue overflow disconnects rather
  than silently dropping inputs or ACKing them. Between samples only held fields
  persist. Cancellation/expiry/reset cannot resurrect queued pre-boundary input.
- Escape/focus release, results, restart, death and stale snapshots clear native
  latches; transport cancellation discards queued/held controls. Death/expiry and
  restart use epochs to reject in-flight old commands. Fresh capture requires
  movement/action keys and right/middle buttons released. Match simulation
  continues while native controls are released, as the HUD explicitly states.
  A source pause-menu/second-Escape simulation pause is not implemented here.

`acks[0]` now names a sample actually supplied to a successful source step.
`hordeInput.receivedSeq` is separate. Cancellation can create sequence gaps, so
the ACK is **not a promise that every lower sample applied**. A stepped control
still does not prove a source action succeeded: cooldown, life state, ammo and
source rules decide effects. See [API.md](API.md) for precise shapes and semantics.

The **31 source-generated native input samples** cover taps between sends, holds,
one-shot consumption, key repeats, source X/Z bindings, posture alias, diagonal
direction, digit/wheel selection and cancellation. **Three source-derived look
vectors** cover hip-fire → ADS → release. The latter corrected a final default
multiplier omission. Live runs precede that ADS-only correction and never used
ADS look; live launch hashes remain exact and are not relabeled as final-tip
gameplay evidence. The final native script composition passed focused input/look
and layout checks after that correction.

## Fresh repair attempts (budget separate from independent review)

`BUDGET.json` records two attempts maximum per case, native deadline 170s and
outer native deadline 180s. No seed selection/retry, Match state writes, physics
edits, ladder modification or source scheduling-time injection was used. The
one-wave target is the existing legal config selected for the requested bounded
case; Ember uses the actual default ten-wave target.

| Case / UUID | Attempt / outer wall time | Outcome |
|---|---|---|
| Meridian combat `eb983c30-da2c-4e4b-888a-69a055898a45` | 1 / 22.844s | **PASS**: 3 distinct enemy deaths credited to actor 0, kills 3, score 94, winner 0, lives 3, wave 1/1 victory, results once and fresh released restart. |
| Verdant death `6447d73c-3e44-4657-ac91-852bf19c03ea` | 1 / 37.081s | **PASS**: actual dead actor and enemy-attributed death, lives 3→2, living respawn, pre-death E press/held physical E and held crouch, neutral boundary, blocked capture until release, then fresh capture. |
| Ember startup `0401dfb7-3677-4131-b811-47338e6c67ba` | 1 / 10.304s | **SUPERSEDED VISUAL FAILURE**: scenario validator and harness exit 0, real wave 1/10 and enemies; directly opened PNGs exposed a clipped third help line. All original run files and its initial PASS validation retained. |
| Ember startup `bcf9d964-252f-4780-864e-6774359a6136` | 2 / 10.354s | **PASS**: real wave 1/10 with three enemies and fixed two-line help at both sizes. No combat completion claim. |

No further real runs were performed. Ember's repair budget is exhausted.

| Passing run | Correlated native snapshots | Received input records | Distinct stepped samples | Native applied ACK high-water |
|---|---:|---:|---:|---:|
| Meridian | 376 | 1,000 | 997 across two rounds | 990 |
| Verdant | 663 | 991 | 871 | 989 |
| Ember second | 148 | 415 | 377 | 413 |

Meridian's first restart snapshot is source time 0.05, zero shots/kills and
released capture. Verdant's source crouching state appears at snapshot 41,
death at 588, respawn at 628; **121 neutral native input records** span the
death/respawn capture boundary. The audit checks all supported action fields,
not only E. Source events generated by enemies (e.g. power/grenade/alt-state)
are not evidence the local player exercised those actions.

All three passing runs have both `HORDE_DONE ok=true` and a complete native
`recording_end`, plus clean **harness exit 0**, no engine resource/error output,
reaped/absent native and Xvfb PIDs, removed XDG trees and closed loopback ports.
These are separate checks. The completed trace marker is a bounded recording
end, not a ten-wave gameplay completion marker.

### Screenshots directly opened

Nine fresh PNGs were directly opened, not merely checked for file existence:

- Meridian [960×640 results](evidence/eb983c30-da2c-4e4b-888a-69a055898a45/gameplay-results.png),
  [1280×800 results](evidence/eb983c30-da2c-4e4b-888a-69a055898a45/gameplay-results-alternate.png),
  [960×640 restart](evidence/eb983c30-da2c-4e4b-888a-69a055898a45/gameplay-restart.png).
- Verdant [1280×800 respawn](evidence/6447d73c-3e44-4657-ac91-852bf19c03ea/gameplay-final.png),
  [960×640 respawn](evidence/6447d73c-3e44-4657-ac91-852bf19c03ea/gameplay-alternate.png).
- Ember second [960×640 startup](evidence/bcf9d964-252f-4780-864e-6774359a6136/gameplay-final.png),
  [1280×800 startup](evidence/bcf9d964-252f-4780-864e-6774359a6136/gameplay-alternate.png).
- Ember first [960×640 clipped help](evidence/0401dfb7-3677-4131-b811-47338e6c67ba/gameplay-final.png),
  [1280×800 clipped help](evidence/0401dfb7-3677-4131-b811-47338e6c67ba/gameplay-alternate.png).

Meridian results strip is `[20,190,920,78]` at 960×640; Scoreboard begins at
y=280 and ends at y=581, leaving the lives/score/restart text visible. At
1280×800 the same reservation holds. Synthetic 13-entry layout checks also
recalculate paging (4 rows at 960, 10 at 1280) rather than pushing excess rows
offscreen. Compact help ends at y=632/792 respectively.

### Resource leak attribution

The old independent observer instanced the product and overrode its root
script. GDScript reinitializes field-created detached Nodes when replacing the
script. `leak_probe.gd` demonstrates the mechanism with an **empty subclass**:

- `leak-old.log`: root replaced, **20 orphan Nodes**, leaked Canvas/CanvasItem/
  rendering RIDs and seven resources, nonzero exit.
- `leak-fixed.log`: direct product instance, **0 orphan Nodes**, clean exit.

The fixed observer has a separate parent controller and never changes the
product node's script. Fresh gameplay/resource exits are clean. This attributes
the prior helper failure without changing or upgrading its retained FAIL.
The Horde client specialization explicitly frees the inherited detached client
before replacement during construction.

The first offline legacy-layout fixture also leaked two pre-ready field-created
Nodes during test-only child replacement. That failed diagnostic is retained in
`layout-old.log`; `layout-old-attributed.log` uses explicit pre-ready cleanup and
still reproduces both overlaps with no leaks. No production state change was
used to obtain either result.

## Verification and retained failures

| Check | Final applicable result / log |
|---|---|
| Adapter / validator / differential / queue-event bounds | **29/29** — `final-adapter.log` |
| Source singleplayer + source UI regressions | **70/70** — `check-1.log` |
| Native Horde model | **15/15** — `check-2.log` |
| Source-generated native ordinary input | **31/31** — `source-input-final.log` |
| Source-generated native look | **3/3** — `source-input-final.log` |
| Inherited synthetic control-safety suite | **2,497/2,497** — `check-3.log` |
| Inherited HUD session gate | **PASS** — `check-4.log` |
| Inherited Scoreboard | **25/25** — `scoreboard-inherited.log` |
| Inherited Scoreboard session gate | **PASS** — `scoreboard-session-inherited.log` |
| Final Horde product layout fixture | **2/2** — `layout-final.log` |
| Direct product leak isolation | **0 orphan delta / clean exit** — `leak-fixed.log` |
| Semantic generation / pinned import | **PASS**, nine maps — `semantic.log`, `import-initial.log` |
| Immutable source verification | **PASS** — `source-lock-final.log` |
| Fresh passing live cases | **3/3**, with first Ember retained superseded — `audit.json` |

No pass counts from repeated suites are added together. The original five-command
focused verifier run is in `verify-final.log` and `check-0..4.log`; it preceded
the small subsequent native-help/validator/ADS corrections, whose relevant final
checks are listed above.

`meridian-validator-initial.log` retains the initial validator failure on missing
JSON `weapon:undefined`. The comparison now serializes the source parser's
expected object to the same JSON representation as the step evidence. It does
not drop defined values, alter controls or change gameplay. The same Meridian
run was revalidated successfully without a second scenario attempt. Run manifests
continue to identify the original validator/runtime hashes; `audit.json` records
the later validation implementation hash explicitly.

## Replay commands and lead integration boundary

Pinned engine:
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`,
version `4.5.2.stable.official.6ce3de25a`, SHA256
`5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
Node `v22.23.1`; locked/installed `ws 8.21.3`. The primary dependency tree was
linked read-only for module resolution; no dependency install was performed.

Exact per-run native argv, source/engine/runtime hashes and allocated endpoint
are in each `launch.json`. Automated launcher commands were:

```sh
GODOT_BIN=/path/to/pinned/Godot TMPDIR=/tmp/opencode PORT=0 node port/native-horde/run.mjs --map=meridian-exchange --scenario=combat --resolution=960x640
GODOT_BIN=/path/to/pinned/Godot TMPDIR=/tmp/opencode PORT=0 node port/native-horde/run.mjs --map=verdant-reliquary --scenario=death --resolution=1280x800
GODOT_BIN=/path/to/pinned/Godot TMPDIR=/tmp/opencode PORT=0 node port/native-horde/run.mjs --map=ember-crucible --scenario=startup --resolution=960x640
```

These describe the recorded runs; do not consume another Ember attempt in this
completed repair lane. A lead replay needs its own isolated worktree and explicitly
recorded budget. The helper allocates PORT 0 itself and creates Xvfb with
`-nolisten tcp -nolisten unix`, screen 1280×800×24 and private isolated XDG dirs.
Its steering is **engine `Input.parse_input_event`**, not human or OS input.
Audio driver was Dummy; no audio acceptance is claimed.

For read-only evidence replay:

```sh
node port/native-horde/validate.mjs port/reports/horde-repair/evidence/eb983c30-da2c-4e4b-888a-69a055898a45
node port/native-horde/validate.mjs port/reports/horde-repair/evidence/6447d73c-3e44-4657-ac91-852bf19c03ea
node port/native-horde/validate.mjs port/reports/horde-repair/evidence/bcf9d964-252f-4780-864e-6774359a6136
python3 -B port/reports/horde-repair/audit.py
```

Focused test commands are recorded in `*-final.json`, other diagnostic JSONs,
and `port/native-horde/verify.py`. Fresh native checks require dependency
availability, semantic regeneration and pinned import after cleanup. Use private
XDG and owned-process cleanup as in the recorded wrappers.

**Lead adapter API:** `createAuthority({observe}) → {server,wss,close}`;
bind its server on owned loopback PORT 0, require JSON readiness
`{service:'cocs-local-horde',transport:1,localOnly:true,port}`, launch
`res://horde/demo.tscn` with that endpoint, and await owned cleanup/`close()`.
Input epochs, applied ACK metadata, event `sourceId`, bounds, packaging closure
requirements and exact field shapes are specified in [API.md](API.md).

The package owner must independently route this local factory/readiness and pin
the two new port-owned authority modules without weakening immutable source
closure verification. No hooks or package changes were made here.

Cleanup is complete: all eight native/Xvfb child PIDs are absent, all four former
live ports are closed, private XDG trees are removed, and the owned dependency
symlink/import cache/generated content tree are removed. `cleanup.json` preserves
the ten generated-resource SHA256s before deletion. The primary dependency tree
remains present. Final scope and whitespace checks passed.

## Remaining acceptance limits

Full ten-wave victory, boss, defeat, optional upgrade selection, endless play,
worst-wave resources/throughput, complete local-action gameplay-effect coverage,
human/OS input and audio remain **OPEN**. Touch, remapping, display-toggle
preferences and a source pause-menu simulation-pause UI are not exposed by this
narrow native scene. The documented ordinary default desktop action contract is
tested separately from full feature/UI parity. Final ADS look has focused source
vector coverage, not fresh live ADS aiming evidence.

Aggregate verification, common experience integration and packaged Linux Horde
gameplay were **not run**. Earlier baseline package acceptance for other scenes
does not certify Horde. **HOLD persists until the lead independently replays the
repairs and completes its own common/package acceptance.**
