# Finish acceptance — source-only READY FOR ENGINE

Owner: `finish/acceptance-20261002`, based on `6cefd9eb`. No nested agents.
**No engine grant was received. No native version probe, import, rendering,
audio-driver capture, Blender or FFmpeg execution was performed.** Parallax owns
the heavy slot. The integrator owns composition/Home Replays; Packaging owns
runtime closure and extracted-package verification.

## Executable inventory

[`matrix.json`](matrix.json) is the machine-readable contract, not an evidence
summary. Defaults are expanded by `tools/godot-dev/finish_runner.py`; each run
report embeds the complete expanded queue with commands, environment overrides,
evidence kind, criteria, prerequisites, timeout and actual skip reason.

The current inventory is **90 unique jobs**: 17 source, 59 engine, 2 real-audio,
8 explicit human reviews and 4 separate-owner closures. Every job is critical.
Every prepared command is queued once per distinct scenario/layout. A Node
owner, controlled wallet/spawn, synthetic InputEvent, native player, real driver
and human review are explicitly different evidence kinds.

Canonical `verify.py` gains **18 focused registrations**. Static inventory is
375 commands plus version/release guards = **377 planned gates**, against the
359-gate published baseline. This is a count, **not a 377-pass result**. Existing
short canonical gates and first-pass journeys remain registered. Long acceptance
jobs live in this separate runner rather than inheriting a 180-second timeout.
New registrations intentionally require the feature commits to be integrated;
registration tests do not substitute another worktree for missing native files.

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

The lane's Horde launcher hardcodes its evidence root. Parent may adopt the
minimal [`horde-evidence-hook.patch`](horde-evidence-hook.patch) after integration:

```sh
git apply --check port/finish/horde-evidence-hook.patch
git apply port/finish/horde-evidence-hook.patch
```

This lane did not edit that owner’s harness. Horde jobs refuse to start until
`process.env.HORDE_EVIDENCE_DIR` is present. They then write into this run’s scope.
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

## Known missing completion work (critical, not silently waived)

1. World close-ground contact/native sports representative, current contact
   diagnostics and measured material/draw/query/resource deltas need completion.
   Existing overview/style captures do not establish connected contact visibility;
   the old zero-extra-draw aggregator cannot certify the new contact pool.
2. LATTICE shared-caption private-context integration and wide/compact graphical
   command/consent journeys still need an executable composed-runtime gate or
   explicit owner-inspected evidence. The three-peer headless fixture is narrower.
3. Physical OS side-button/modifier/assistive input and cross-route mapped held
   actions need real execution. Base-world synthetic input and its synthetic final
   spectator identity do not replace actual seat/privacy acceptance.
4. Replay Home/attract integration, real-driver playback/audio clearing and native
   disk-error UI need inspection. The current admitted scope is one map/four combat
   modes, not private-intel COCS. Extracted external runtime closure is Packaging’s.
5. Listening, actual transport stall/focus audio behavior, animation/gameplay clips,
   inspected wide/compact layout and hardware GPU measurements remain open.
6. Parent runs full integrated canonical **377 planned**, then Packaging’s baseline
   **75/platform plus additions**, updating actual counts after integration.
7. Production maps/art/masters/robots/vehicles/scenery/cinematic v3 are separately
   owned and unaccepted by this matrix. Sunscar VIP ordinary-input extraction
   remains a known source/geometry gap with retained timeout evidence.

READY FOR ENGINE means orchestration/source preparation only. It grants no slot,
native success, asset quality, package acceptance or release readiness.
