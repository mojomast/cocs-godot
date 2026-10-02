# Finish acceptance — source-only READY FOR ENGINE

Owner: `finish/acceptance-20261002`, initially based on `6cefd9eb`, now merged with
parent candidate `5a4bc82d04856d35fc06c58786bb9da4a35d6369` at `749c0e2e`.
No nested agents. Parent coordination documents are preserved.
**No engine grant was received. No native version probe, import, rendering,
audio-driver capture, Blender or FFmpeg execution was performed.** Helix owns
the heavy slot. The integrator owns composition/Home Replays; Packaging owns
runtime closure and extracted-package verification.

## Executable inventory

[`matrix.json`](matrix.json) is the machine-readable contract, not an evidence
summary. Defaults are expanded by `tools/godot-dev/finish_runner.py`; each run
report embeds the complete expanded queue with commands, environment overrides,
evidence kind, criteria, prerequisites, timeout and actual skip reason.

The current inventory is **96 unique jobs**: 20 source, 62 engine, 2 real-audio,
8 explicit human reviews and 4 separate-owner closures. Every job is critical.
Every prepared command is queued once per distinct scenario/layout. A Node
owner, controlled wallet/spawn, synthetic InputEvent, native player, real driver
and human review are explicitly different evidence kinds.

Canonical `verify.py` gains **24 focused registrations**. Static inventory is
381 commands plus version/release guards = **383 planned gates**, against the
359-gate published baseline. This is a count, **not a 383-pass result**. Existing
short canonical gates and first-pass journeys remain registered. Long acceptance
jobs live in this separate runner rather than inheriting a 180-second timeout.
All feature commits are now integrated in this checkout. A registration test
checks every declared entrypoint against actual local files, excluding only the
explicit generated semantic-manifest prerequisite. It never substitutes another
worktree or interprets file existence as native execution.

| Family | Actual prepared coverage | External command deadline |
|---|---|---:|
| Gameplay | second-pass contract; all seven native operator journeys; separate guest-rope death/expiration/reconnect with scripted Node owner; first-pass Kimi/Qwen/ChatGPT inputs | contract 90s; seven 390s (7×50s); rope 100s each; first three 160s |
| World | actual Three.js spatial/first-pass oracles; native pixel/material/contact/resource contract; first-pass unit, AV ownership/standalone, campaign environment; original/campaign/urban/late spectator wire; two staged matched render suites | contracts 90s; wire 140s each; render 180s/130s |
| Challenges | actual-source settlement oracle and native contract; three natural 40s rounds plus fourth after full process/authority recreation, reconnect and persistence | contract 90s; full journey 330s (internal epochs 200s+90s) |
| Spectator | source targets/assist/privacy/free motion, process harness tests, native contract and actual competitive callback continuity; **four families × wide/compact**, two native players plus late spectator | 300s each (240s journey, 260s native watchdog plus cleanup) |
| Horde | exact target-range regression; guidance/upgrade contracts; normal-rate chain, then separately granted full mission; wide/compact rendered chain | chain/render 690s (internal 660s); boss 980s (internal 950s, source 900s) |
| Audio | source PCM/cooldown/priority; Dummy lifecycle only; isolated real-driver Effects PCM and controlled real-source-event journey; both PCM metrics; event-router/independent/robot/weather regression | lifecycle 90s; each real-driver job 100s including metrics |
| LATTICE | source caption/progress/recovery oracle and wire; native feedback, three native peers, tactical and command contracts | native peers 75s (internal 45s); contracts 90s |
| Controls | source defaults/normalization/swaps/timelines; native four-sampler contract; combat/Horde/sports/CA, arms-race fixtures, Settings, input queue/stall; base-world wide/compact real wire | contract 60s; base world 110s (internal 80s); regressions 90s |
| Replay | adapter/source tests; normal-rate record/save/discard/leave/library/exact seek; zero post-leave authority packets; external helper dependencies | 150s (internal 120s) |
| Composed integration | 208 source caption vectors; native 212-check caption consume/privacy gate; six Home Replay entry/cleanup checks; 48 exported bridge refusal checks; source replay vocabulary and four package closure contracts | native 90s each; source 120s each |

Graphical screenshots require actual inspection. The spectator eight jobs require
zero spectator input packets **including neutral packets**, correct read-only
public data and native controls. Mode uses Retry-seat; other families use their
supported Home/rejoin. Sports does not fabricate infantry death/assist support.
Horde full victory requires `mission-won`, not merely Warden death: the retained
source victory at 803.45s is not native completion. Challenge authority uses the
documented deterministic date `2026-10-02`, normal wall time and no seeded XP.

## Reviewed source of truth and integration dependencies

All three `port/{pass-two,expansion-three,expansion-four}/WORKSTREAM.md` files and
the exact per-lane `ACCEPTANCE.md` in **all sixteen isolated wave worktrees** were
reviewed, including production-art lanes. Feature commands were checked against
their actual launcher code, not just copied from prose. Lane code checkpoints:

| Lane | Audited worktree suffix / source checkpoint | Runtime/dynamic dependencies to retain |
|---|---|---|
| Gameplay | `pass-two-gameplay` / `f747c3ef` | player_gameplay helpers, source oracle JSON, production world/Experience, original server and semantic/operator assets |
| World | `pass-two-world` / `12f0aa1b` | spatial roughness/contact helpers, source vectors, composed weather+AV snapshot/reset ownership, semantic/campaign/urban resources |
| Modes | `pass-two-modes` / `e94b3da0` | `challenge-authority.mjs`, `game/challenges.mjs`, owned launcher factory and source progression/history; per-process private store paths |
| Experience | `pass-two-experience` / `8d1efc60` | `experience/public_event_types.json`, connected route factory imports, generated scenes, four real production route subclasses |
| Horde | `expansion-three-horde` / `05986449` | `native-horde/authority.mjs`, controller, HUD helpers, guidance/upgrade fixtures and Blackwater scene |
| Audio | `expansion-three-audio` / `bf4d8865` | all 160 `audio/telegraphs` PCM files/manifest, campaign authority, source events/snapshots, threat gate and real recording bus |
| LATTICE | `expansion-three-lattice` / `9f944afb` | **Tern derivative** `port/multiplayer-worlds/derived/game-server.mjs`; tactical/command adapters; shared dynamic-caption hunk requires deliberate privacy integration |
| Controls | `expansion-four-controls` / `9aa752a8` | merged mapping hooks and four samplers; both Gameplay/Experience dynamic-hint consumers; actual spectator/modal packet guards |
| Replay | `expansion-four-replay` / `9794575a` | `replay/admission.json`, renderer dependencies, `tools/port/replay/{service,adapter,package}.mjs`, source `game/demo.mjs`; external four-file replay-runtime, Home integration |

Full paths are `/home/mojo/.tmp-on-disk/cocs-<suffix>-20261002`.
Per-gate `requires` lists are resolved **only in the specified execution root**.
Reports additionally inventory literal transitive JS imports and GDScript
preloads/extends and external Node package names. Computed resource lookups are
not mistaken for a fully static graph: `dynamic_dependencies` explicitly hashes
semantic/generated content, audio, operators, effects, robots, map art/recipes,
biomes, imported resources, `ws`/`three` and external replay-runtime bytes.
Tracked source/runtime files are also byte-hashed, including dirty files. Literal
`new URL()` is deliberately not inferred as a required input: it also names the
optional `server/history.json` and `server/progression.json` output stores.

The inherited Horde launcher hardcoded its evidence root. The isolated one-line
launcher-only commit `52ce0963` now honors `HORDE_EVIDENCE_DIR`; no journey logic,
deadline or production behavior was changed. The original adoption diff remains
[`horde-evidence-hook.patch`](horde-evidence-hook.patch) for audit. Apply it only if
not adopting `52ce0963` or the complete branch:

```sh
git apply --check port/finish/horde-evidence-hook.patch
git apply port/finish/horde-evidence-hook.patch
```

Horde jobs refuse to start if the environment hook is absent, and then write into
this run’s scope. This is the only launcher-level change outside canonical tools.
Every other inspected launcher already accepts `GODOT_BIN`; no engine wrapper or
production changes were necessary. The finish runner supplies each lane's exact
grant flag/environment only after its own explicit cohort grant.

## Run after integration

Evidence defaults to
`/home/mojo/.tmp-on-disk/cocs-finish-acceptance-evidence-20261002/run-<unique>/`.
Never point it at tracked `port/reports` or an older attempt. All commands run from
the explicit repository root (default: runner’s checkout), serially. Source-only:

```sh
python3 tools/godot-dev/finish_runner.py              # plan, starts no children
python3 tools/godot-dev/finish_runner.py --run        # source only, native blocked
```

Both return **1 while any critical case is incomplete**. “Plan only”, absent
grant, missing integrated files, blocked prerequisites, budget exhaustion and
unselected cases are **unrun**, never passed. This is intentional even if every
selected source check passes.

Only after an explicit parent slot grant and normal semantic/asset preparation:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export LP_NUM_THREADS=1
python3 tools/godot-dev/finish_runner.py --run --grant engine --budget-seconds 1800
# Inspect retained chain receipts and screenshots before obtaining boss grant.
python3 tools/godot-dev/finish_runner.py --run --grant engine --grant horde-boss \
  --resume /absolute/same-input/run-XXXX/report.json --select horde-boss
# Real audio permission/device must be available; Dummy is rejected.
export AUDIO_DRIVER=PulseAudio
python3 tools/godot-dev/finish_runner.py --run --grant engine --grant audio
```

The default 1800s invocation budget admits a job only if its whole deadline plus
cleanup fits. Resume remaining cases in another granted interval. `--select ID`
is repeatable and does not auto-run dependencies; include them or use an existing
same-hash report. `--retry-failed` is necessary to rerun a failed job, preserving
its old attempt. Passed jobs never rerun on resume. Changing AUDIO_DRIVER is an
input change; for a single combined resume stream set the intended real driver
before the initial report, even when the audio cohort is not yet granted.

Resume checks the same matrix, runner, tracked/input/dynamic bytes, binary bytes
and relevant environment, not merely HEAD. Any change requires a fresh report.
An initial import may materialize/change ignored imported assets; prepare/import
first, then create a fresh final report bound to those bytes. This prevents
source-only worktree reports being promoted to integrated native evidence.

Each attempt records exact cwd/argv, environment overrides, isolated HOME/XDG,
settings/bindings/career/credentials and evidence paths. The runner removes
inherited store paths and lane grants. It uses the existing atomic report writer
and Xvfb wrapper. A Linux subreaper supervises detached descendants, bounds TERM/
KILL cleanup, reaps orphans even after leader exit, and treats leaks as failures.
There is one process-wide cohort lock across invocations. Native logs (including
nested artifact logs) have strict error scanning with **no broad allowlist**.
Real PCM metrics are a required post-check, not a listening substitute.

Manual/external closures can be attached explicitly with
`--resume REPORT --attest RECEIPT.json`. Receipt schema:

```json
{
  "gate": "integrated-layout-review",
  "input_sha256": "exact report input_identity.sha256",
  "reviewer": "actual reviewer identity",
  "verdict": "passed",
  "notes": "What was actually inspected and why the gate criteria passed",
  "evidence": [{"path": "/absolute/existing/review-file", "sha256": "actual file hash"}]
}
```

Receipts cannot replace executable gates. Missing/changed evidence or input hashes
are rejected. All prior attempts remain. `release_ready` stays false: this is an
acceptance ledger, not a release publisher.

### Additive engineering readiness labels

`integration_ready` is true only when every critical **source and engine** job
has a latest passed attempt in this exact-input ledger. Missing, unselected,
skipped, running or failed engineering jobs keep it false. An input identity and
at least one critical engineering job are required. This is engineering
completion, **not playtest certification**.

`blockers_by_cohort` exposes `unrun` and `failing` gate-ID lists for source,
engine, audio, manual and external cohorts. Thus integration can be ready while
real-audio failures, human listening, OS/assistive or GPU review and export
acceptance remain visible release blockers. Existing `status`,
`incomplete_critical`, exit semantics and the conservative `release_ready: false`
remain unchanged; every critical cohort still participates in the aggregate.

Use the existing selection/resume CLI to avoid repeating completed source jobs.
For the frozen native candidate, reuse one existing finish/integration worktree,
perform its required import once under the explicit grant, then bind the ledger
to the resulting cache bytes. Strict same-input validation and cache hashing
remain in force. Ignored cache files do not themselves imply a reimport; no
cache exclusions, lockfile-only dependency shortcuts or synthetic passes are used.

## Source execution actually completed

Seventeen distinct source registrations passed across this checkout and the
actual isolated lane roots. **None is integrated/native acceptance.** Reports
retain their root, input hash, exact command, scoped outputs, duration and cleanup:

| Evidence run under the external root | Passed source jobs |
|---|---|
| `run-_i6mh2ks` | initial runner 11 tests; canonical registration 2 tests |
| `run-sdds24dn` | seven gameplay/negative/shared-rope source vectors; first-pass gameplay oracle |
| `run-gui4juzo` | gameplay actual owner/guest wire/death/reconnect |
| `run-joom6dzo` | spatial and first-pass world source oracles |
| `run-d4ppkq5z` | challenge/source progression **33 tests** |
| `run-uyx1f0co` | spectator oracle; **6 process/route tests**; generated scene freshness |
| `run-3s3_viod` | Horde exact targeting **3 tests**, no full mission rerun |
| `run-tnmtfrt6` | audio PCM/cooldown/priority **6 tests** |
| `run-_46a602w` | LATTICE actual source caption/progress/recovery oracle |
| `run-aykyankn` | LATTICE actual source wire journey |
| `run-izegeju5` | input defaults/normalization/1,075 swaps/timelines oracle |
| `run-dp26ribm` | replay adapter/source **78 tests** |

The three initially skipped source jobs have their original reports retained
(`run-sdds24dn`, `run-5vlmbhz7`, `run-_46a602w`): dependency discovery mistakenly
treated optional history/progression output URLs as missing inputs. The scan was
corrected and only those unexecuted jobs were subsequently run. No source rule or
fixture assertion was relaxed. Later runner tests add resume/hash/receipt/audio/
cohort checks; final local verification is recorded in the handoff commit/tests.

Final source checks are retained in `final-source-0l5xq7g0/`: **16/16** finish
runner tests, **2/2** canonical registration tests, **5/5** verifier-report tests,
**6/6** existing watchdog tests, Python AST/matrix JSON validation, whitespace and
Horde hook `git apply --check` all pass. Deliberately failed synthetic child
processes and rejected hash changes in those tests are negative controls, not
native attempts. `development-failures.json` retains earlier registration-order
and zero-context patch failures and their narrow corrections.

### Integrated-candidate follow-up

After the parent steering update, `749c0e2e` merged the exact supplied candidate.
`INTEGRATION.md`, `HOME_REPLAY_HOOK.md` and `PACKAGING.md` were read; all three new
native contracts and their source checks are now critical entries in both the
canonical list and full matrix. The coordinator's notes and fighting research
documents were preserved; unbuilt fighting work is outside this acceptance scope.

`run-cpharx0k/report.json` records **20/20 source jobs passed in the integrated
checkout**, including **17 runner tests**, the 208-vector composed-caption oracle,
one replay manifest-vocabulary test and four finishing-closure tests. All engine,
audio, human and separate-owner jobs remain unrun/incomplete; exit 1 is correct.
The report predates only the isolated Horde evidence-root hook and documentation
follow-up, so a final engine run must start a fresh same-input ledger.

Every direct required file and literal import/preload resolves in the integrated
checkout except `godot/content/generated/manifest.json`, the explicitly declared
parent preparation output. This was checked using actual files, with no mock or
other-worktree fallback. The parent-provided committed closure is **86 source
modules, 39 adapters, 166 feature resources including 160 WAVs, four replay-runtime
files**; the source-only closure tests do not claim extracted native execution.

`final-integrated-source-7dtzjfqb/` retains the final **17/17 runner, 2/2
registration, 5/5 verifier-report, 6/6 existing watchdog** test logs, Horde
launcher Node syntax check and every gate's resolved dependency inventory.
`candidate-runtime-byte-parity.log` confirms this branch's `godot/`, `game/`,
`server/` and `tools/godot-package/` bytes exactly match parent `5a4bc82d`.
Whitespace, **96-job** matrix validation and **383 planned** canonical inventory
also pass. The only unresolved declared file is the generated semantic manifest.

## Known missing completion work (critical, not silently waived)

1. World close-ground contact/native sports representative, current contact
   diagnostics and measured material/draw/query/resource deltas need completion.
   Existing overview/style captures do not establish connected contact visibility;
   the old zero-extra-draw aggregator cannot certify the new contact pool.
2. LATTICE shared-caption private-context integration now has a real prepared
   212-check composed-runtime contract, still unrun. Wide/compact live caption and
   graphical command/consent journeys need inspected evidence beyond that contract
   and the three-peer headless fixture.
3. Physical OS side-button/modifier/assistive input and cross-route mapped held
   actions need real execution. Base-world synthetic input and its synthetic final
   spectator identity do not replace actual seat/privacy acceptance.
4. Replay Home/attract integration and exported startup repair are now implemented,
   with six/48-check native gates queued. Real-driver playback/audio clearing and
   native disk-error UI need inspection. The admitted scope is one map/four combat
   modes, not private-intel COCS. Extracted external runtime closure is Packaging’s.
5. Listening, actual transport stall/focus audio behavior, animation/gameplay clips,
   inspected wide/compact layout and hardware GPU measurements remain open.
6. Parent runs full integrated canonical **383 planned**, then Packaging’s baseline
   **75/platform plus additions**, updating actual counts after integration.
7. Production maps/art/masters/robots/vehicles/scenery/cinematic v3 are separately
   owned and unaccepted by this matrix. Sunscar VIP ordinary-input extraction
   remains a known source/geometry gap with retained timeout evidence.

READY FOR ENGINE means orchestration/source preparation only. It grants no slot,
native success, asset quality, package acceptance or release readiness.
