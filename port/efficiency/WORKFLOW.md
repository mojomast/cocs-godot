# Workflow efficiency — shortening verified playable build delivery

Owner request (verbatim intent): *"fan out flash subagents to research best
practice to make sure you are doing this in the most efficient way possible."*
This is the **workflow / critical-path** lane's report. It is deliberately scoped
to process, integration, queue and build order. It does **not** re-research which
engine to use for fighting (that audit is done and accepted in
`port/fighting/research/ENGINE_MECHANICS.md` and `port/fighting/DESIGN.md`).

Base: `efficiency/workflow-20261002` at `10a90fd0`.
Deliverable: this file only. No runtime, engine, asset or package files were
written.

## 0. Method, independence and evidence policy

- Independent research/audit subagent. No nested agents. No writes to any other
  agent branch or worktree, and no polling of other lanes' live progress.
- Read (actual files in this checkout): `port/finish/{WORKSTREAM,ACCEPTANCE_PLAN}.md`,
  `port/finish/matrix.json`, `tools/godot-dev/finish_runner.py`,
  `tools/godot-dev/{gate_runner,verify}.py`, `port/fighting/{WORKSTREAM,DESIGN}.md`,
  `port/fighting/research/ANIMATION_ASSETS.md`, `port/fighting/content/{RESULTS.md,ANIMATION_COVERAGE.json}`,
  `port/{pass-two,expansion-three,expansion-four,new-maps,animation-pass}/WORKSTREAM.md`,
  `port/contracts/source-lock.json`, `godot/.gitignore`, plus git branch/worktree
  topology and lightweight host resource probes.
- **Not run:** Godot, Blender, import, baking, rendering, audio capture, FFmpeg,
  and no benchmark of any kind. Per the task constraint, `--grant`, `--run`,
  heavy-slot start and active-worker polling were not touched.
- No runtimes are measured here. Every "expected benefit" below is **qualitative**;
  no time or percentage is fabricated. Where a number appears it is either a
  static count read from the repository (jobs, timeouts, commits, disk) or a
  primary-source fact.

## 1. Lightweight system resource facts (observed, not benchmarked)

Probed with `nproc`, `/proc/cpuinfo`, `free`, `/proc/loadavg`, `df`, `command -v`
and `du`. Read-only; no load was added.

| Fact | Observed value | Why it matters here |
|---|---|---|
| CPU | 32 logical, `AMD RYZEN AI MAX+ 395` | Ample cores, but they are not the binding constraint. |
| Memory | 121 GiB total, **4.9 GiB free**, 47 GiB available, buff/cache 83 GiB | Available headroom is thin; heavy native + llvmpipe work is memory-hungry. |
| Swap | 31 GiB total, **31 GiB used / 466 Mi free** | Swap is effectively exhausted — a strong signal the host is already over-committed by concurrent background lanes. |
| Load / threads | loadavg `3.05 4.29 4.95`; 5760 threads | Many parallel agent processes already running. |
| Root filesystem | 1.9 TB, **95% used, 99 GB free** | Multi-GB evidence trees are accumulating. |
| `/tmp` (tmpfs) | 61 GB, **94% used, ~4.0 GB free** | `/tmp/opencode` alone is ~55 GB. Rendered captures and scratch risk `ENOSPC`. |
| `.tmp-on-disk` | **306 GB across 205 `cocs-*` worktrees** | Branch/worktree sprawl is itself a resource cost. |
| Toolchain | Godot `4.5.2.stable.official.6ce3de25a` (pinned in `source-lock.json`), Node `v22.23.1`, Python `3.13.7`, FFmpeg `7.1.1`; **Blender not on `PATH`** | Confirms the heavy slot is a scarce, serialized resource; Blender runs only inside a granted lane. |

**Implication.** The machine has many cores but almost no spare memory and very
little scratch space. This alone argues against introducing *more* concurrent
heavy processes right now. The correct lever is to do **less heavy work per unit
of verified progress**, not to parallelize heavy work.

## 2. Observed bottlenecks, ranked by impact on time-to-verified-playable-build

Ranked 1 (highest leverage) → 10. "Owner" names the concrete role from the active
workstreams. Effort is Low/Med. Benefit is qualitative.

| # | Observed bottleneck | Source evidence (actual) | Proposed change | Owner | Effort | Expected benefit (qualitative) | Validation | Rollback / decision |
|---|---|---|---|---|---|---|---|---|
| 1 | **No bounded exit for art/review churn.** Helix and Foundry each ran a functional pass and then reopened into larger revisions; published runtime is still `e731fd53`. Review re-opens without a cap. | `port/new-maps/WORKSTREAM.md` (Helix functional→rev2, Foundry functional→rev3; "functional acceptance does not satisfy… yet"); `port/finish/WORKSTREAM.md` (published runtime `e731fd53`). | Give each art lane a bounded budget: at most two revision passes after functional acceptance, then **accept or explicitly park**; park does not block the playable build. Keep the owner's roster and feature scope intact — this caps revisions, not content. | Parent (policy); map lanes execute | Low | Stops reviews from indefinitely pre-empting the critical path; releases the single heavy slot sooner. | Parent records a per-lane "revision budget" and a park/accept decision in each `WORKSTREAM.md`; no new gate code. | Decision is reversible: a parked lane can be re-granted later. Default = accept a demonstrably distinct revision rather than iterate indefinitely. |
| 2 | **Acceptance ledger cannot ever be "passed" because human/GPU jobs are critical in the same list as code jobs**, so the local code loop is gated by evidence it cannot produce. | `matrix.json` `manual` + `external` cohorts (8 + 4 jobs, timeout 1, `critical:true`); `finish_runner.py::summarize` sets `incomplete_critical` and `release_ready=False` whenever any critical is unrun. | Split the ledger into **(a) automated integration gate** (source + engine/audio contracts) that can go green, and **(b) release-acceptance gate** (manual/human/GPU/external) tracked separately. Publish a two-part status: `integration_ready` vs `release_ready`. Cannot force human/GPU per local code check. | Parent; `finish/acceptance-20261002` | Low–Med | Local iterations stop waiting on evidence that only a human/GPU can produce; release claims stay truthful because human/GPU gates remain mandatory for `release_ready`. | A report where all automated critical pass shows `integration_ready=true`, `release_ready=false`; existing attestation path preserved for manual/external. | Keep the current single ledger as fallback. If the split hides a needed blocker, re-merge. |
| 3 | **Source tests are duplicated across the canonical suite and the finish matrix**, so the same scripts run in two inventories. | `verify.py`: 381 command tuples + `toolchain-version` + `release-refused` = 383 planned; 216 use `--script`. `matrix.json`: 96 jobs incl. 20 source. Same scripts (`test_finish_runner.py`, `test_playable_gates.py`, `caption-oracle.mjs`, `replay-bridge-contract.test.mjs`, `finishing_closure.test.mjs`) appear in both. | One owner per check. During development, run a **diff-targeted subset**; at a candidate/Release, run the **full canonical suite once**. The finish matrix keeps only finish-specific and native scenarios, referencing (not re-running) canonical source results. | Parent; `finish/acceptance-20261002` | Med | Removes duplicated compute and a class of "which inventory is authoritative" drift. Aligns with test-pyramid and predictive/diff selection practice. | `tools/godot-dev/test_playable_gates.py` extended to assert each source script is registered in exactly one authoritative inventory; run once. | If a check is genuinely needed in both layers, record the explicit reason in the matrix. Otherwise fall back to duplicated registration. |
| 4 | **Godot import cache is gitignored and rebuilt per fresh report**, and the cache bytes are part of the input hash, so a fresh report re-imports and a re-import can invalidate prior reports. | `godot/.gitignore` ignores `.godot/`; `matrix.json::dynamic_dependencies` includes `godot/.godot/imported`; `native-import` runs `--editor --import --quit` (timeout 180); `ACCEPTANCE_PLAN.md` warns "prepare/import first, then create a fresh final report". | Once per accepted anchor, run import inside the **integration sandbox**, snapshot `.godot/` to a retained cache path, and reuse it for all same-input reports. Never commit it. Treat the cache as a hashed input. | `finish/integration-20261002` + `finish/acceptance-20261002` | Low–Med | Removes a repeated 180 s-class import from every fresh report and reduces hash-invalidation churn. Godot docs confirm keeping `.godot/` shortens reimport; we keep it out of git. | Confirm `native-import` finds an up-to-date cache and that the same imported bytes back subsequent reports; publish the cache manifest hash. | Delete the retained cache and re-import. Note: Godot issue #111048 shows headless import can be timing-sensitive; `--import` is recommended over `--editor` for robustness (already the project's choice). |
| 5 | **Long-branch / cherry-pick churn: the same logical commit was re-authored onto many lane branches.** | The fighting content commit `feat(fighting): author full nine-operator content…` exists as **6 distinct hashes** (`77676c4c`, `7fe3aa66`, `72c409ae`, `b1766e00`, `b0669433`, `79d98652`); the mechanic-contract commit likewise 6×. 205 worktrees, 274 refs, 1923 commits. | Freeze the shared fight/presentation APIs, then merge lane branches into **one integration sandbox** branch in order. Stop cherry-picking the same logical commit onto multiple lanes; parent rebases only at integration. | Parent | Med | Fewer conflicts, fewer duplicate commits, one place to verify closure. Directly follows trunk-based "short-lived branches / small batches" practice. | Before/after `git patch-id` dedupe report and an integration manifest listing each lane's HEAD and merge order. | Old lane branches are preserved; revert to per-lane merging only if the sandbox becomes unstable. |
| 6 | **Heavy work is serialized by an unenforced prose convention with a hard 1800 s invocation budget**, so a green engine cohort needs many grant round-trips. | `finish/WORKSTREAM.md` "exclusive heavy slot"; `new-maps/WORKSTREAM.md` grant queue; `finish_runner.py` line 279 default `--budget-seconds 1800`, line 357 skips a gate whose deadline will not fit. Static engine+audio deadline sum = **11,185 s (~3.11 h)**, 14 jobs ≥ 300 s, 42 engine/audio jobs depend on `native-import`. | **Do not add a parallel heavy scheduler now** (memory/swap/disk make it unsafe). Instead reduce heavy *count*: import once (row 4), vertical slice first (row 8), diff tests (row 3), and let the runner keep serializing. If parallelism is ever added, make it bounded and memory-aware and keep the existing lock. | Parent | Low (policy) | Fewer grant cycles and less idle time without risking OOM/`ENOSPC`. | Track "heavy grants consumed per accepted artifact" as a process metric; no code change required for the serial decision. | Decision: keep global heavy serialization while swap is exhausted. Revisit only after memory/disk headroom is restored. |
| 7 | **Evidence / scratch disk pressure threatens rendered captures.** | §1: root 95% (99 GB free), `/tmp` tmpfs 94% (~4 GB free), swap full; evidence roots of 0.1–4.2 GB each (`cocs-consolidated-evidence-20260929` 4.2 GB, `cocs-new-map-conservatory-evidence-20261002` 2.8 GB, observatory 1.9 GB). | Retain failures but **compress/rotate** large PNG/video evidence to an archive; cap per-run screenshot counts; keep one evidence root per lane. Do not delete originals before checksums are recorded. | Parent; lane owners | Low | Avoids capture failures caused by `ENOSPC` and keeps the heavy slot productive. | `df` before/after; verify archived artifacts by hash before removing hot copies. | Restore from archive if a review needs original files. |
| 8 | **Fighting content is ready (138 moves, 336 clip requirements, 225 victim instances) but zero rigs/clips/playable evidence exist**, so the 336-clip bulk would be built before any proof. | `port/fighting/content/RESULTS.md` (336 clips + 225 victim instances; "requirements, not built"); `godot/fighting/` contains only `data/{roster,rules}.json`; `godot/fighting/assets` absent; `ANIMATION_ASSETS.md` finds zero skins/animations in the operator GLBs. | Build a **2-character visual vertical slice first**: **Meta vs Mistral** (DESIGN's own heavy/light contrast), covering one stage, core sim, presentation, FX and one native capture/replay, before authoring the full clip library. | `fighting/animation-20261002` + `core` + `presentation` + `effects`; `fighting/verification-20261002` accepts | High (bounded) | Early playable evidence de-risks all nine; a failure in rig/timing/contact is found once, not nine times. Matches the research report's ~26-clip-per-operator slice and the DESIGN's stated first proof. | A native side-on slice: rig, clip set, hit/hurt contact alignment, one throw pair and one FX family inspected at gameplay scale. | Keep all existing FPS operator files untouched (see row 9). Extend to nine only after slice acceptance. |
| 9 | **Risk of overwriting working procedural "core animations."** The shipped operator/robot/gesture locomotion is procedural and already published; a fighting skeletal pipeline could be tempted to replace it. | `port/animation-pass/WORKSTREAM.md` (published `1c1f6e34`; contact-aware procedural motion, bounded springs; 18,468 native samples); `grep AnimationPlayer/AnimationTree godot/**/*.gd` = **no matches** — the port is procedural. | Make the fighting visual pipeline **strictly additive** under `godot/fighting/visuals/`; never rewrite the source operator solver, `player_gameplay/`, or frozen `game/`/`server/`. Reuse the existing GLBs as the mesh source; add a fighting rig/clips alongside. | `fighting/animation-20261002`; parent reviews diff boundary | Low | Preserves the accepted playable game while the new mode is built; avoids regressing a published build. | Diff check: no changes under existing operator/gameplay paths; native FPS regression cohort still passes. | Revert any accidental overwrite from the frozen source/derivative. |
| 10 | **Input-hash cost scales with dynamic content.** `input_identity` walks and hashes every tracked file plus `dynamic_dependencies` (including the import cache, `node_modules/ws`, `node_modules/three`) in 1 MiB blocks on every invocation. | `finish_runner.py` lines 46–77. | Hash the import cache via a retained manifest instead of re-reading every file; keep the tracked-file hash. Consider excluding `node_modules` in favour of lockfile + resolved-version hashes. | `finish/acceptance-20261002` | Low | Faster report creation and fewer surprise invalidations, without weakening the "hash bytes, not HEAD" guarantee. | Compare input identity before/after on an unchanged tree; same value with one run each. | Revert to full directory hashing if the manifest misses a change. |

## 3. Heavy serialization: explicit recommendation

**Keep global heavy serialization as it is. Do not introduce a bounded parallel
heavy scheduler now, and do not change the grant/start/poll mechanics.**

Rationale from observed facts, not speculation:

- Swap is **100% used** with only ~4.9 GiB RAM free while ~83 GiB sits in
  buff/cache and 5760 threads are already running. Adding concurrent
  Godot/llvmpipe processes risks OOM and thrash.
- `/tmp` has ~4 GiB free; rendered capture jobs would be the first to fail.
- The runner already implements the safe parts of bounded execution: one
  process-wide cohort lock (`COHORT_LOCK`), start-new-session supervision, a
  Linux subreaper, bounded TERM/KILL cleanup, orphan reaping, and a budget check
  that refuses to start a gate whose deadline cannot fit. Those are the right
  behaviours and should be preserved.
- Godot 4.5 exposes `--single-threaded-scene` and `--render-thread`, and the
  project already pins `LP_NUM_THREADS=1`; these reduce per-process contention
  but do not create safe headroom.

**What to optimize instead:** reduce the *number* of heavy jobs (rows 3, 4, 8),
reduce grant round-trips (row 6), and keep the serial lock. A bounded
parallelism design is a **later, separate decision**, gated on measured memory
and scratch headroom — not part of this change.

## 4. Test strategy: diff-targeted plus release-canonical once

- **During development:** select tests from the diff (changed module → owning
  suite) rather than re-running all 383 canonical gates + 96 matrix jobs. This is
  the practical form of test-pyramid + predictive/impact selection.
- **At a candidate:** run the canonical suite once, then the finish native matrix
  under grants. Authoritative counts are stated as counts, never inferred passes.
- **Never** treat source registration or file existence as native execution, and
  keep the existing fail-closed semantics (`unrun ≠ passed`, `release_ready=false`
  until human/GPU evidence exists).
- **Avoid** adding a third inventory; consolidate source ownership (row 3).

## 5. Queue priority: original finish + fighting before endless art/reviews

The executable priority implied by the documents:

1. **Finish the verified playable build** (finish integration + packaging +
   acceptance) — this is the original owner request and the only path to a new
   published runtime.
2. **Fighting vertical slice** as the owner's newest explicit feature request —
   bounded to two contrasting characters first.
3. **Already-queued feature lanes** (pass-two, expansion-three, expansion-four)
   once the shared hooks are frozen and merged in the integration sandbox.
4. **New art/maps/reviews** (Helix rev, Foundry rev, Vesper, Abyssal, robots,
   vehicles, scenery, Stormglass) — bounded by row 1, accepted or parked; they
   must not pre-empt the heavy slot indefinitely.

**No arbitrary roster cut.** The fighting acceptance requirement stays nine
operators; the vertical slice is an *ordering* device, not a reduction of the
roster or feature set. All nine operators, signatures and effects remain in scope.

## 6. Stage gating and truthful release claims

- **Local code check** (fast, headless/source): may be green and repeatable.
- **Critical build integration** (merged candidate, native contracts): green only
  after an explicit grant and real engine execution.
- **Human feel / listening / assistive tech / real-GPU**: cannot be forced per
  local code check; they remain mandatory exactly once, at release acceptance.
- Publish status in those terms. Never promote a source-green run, an isolated
  lane, a package check, or a staged screenshot to a release claim. Preserve
  failures and earlier releases (published runtime stays `e731fd53` until a newly
  verified release is actually published).

## 7. Top 3 parent actions now

1. **Create the single integration sandbox and freeze shared APIs.** Merge lane
   branches into it in order; stop re-authoring the same logical commit across
   lanes. (Rows 5, 7.)
2. **Split the acceptance ledger** into an automated integration gate and a
   separate human/GPU release gate, and run source checks once (diff during
   development, canonical once at candidate). (Rows 2, 3, 10.)
3. **Approve the bounded fighting vertical slice (Meta vs Mistral) and cap art
   revisions.** Keep the fighting pipeline additive; do not overwrite the
   published procedural animations. (Rows 1, 8, 9.)

## 8. Phased critical-path order

- **Phase 0 (code-only, now):** freeze APIs; prune/compress evidence; warm and
  retain the Godot import cache in the sandbox.
- **Phase 1:** finish integration + packaging merged; finish source cohort green;
  automated integration gate green (no native claim).
- **Phase 2:** one explicit grant → `native-import` once, then headless native
  contracts; heavy scenarios individually with retained receipts.
- **Phase 3:** fighting vertical slice (Meta vs Mistral) code + rig + one stage,
  then native slice acceptance.
- **Phase 4:** extend fighting to all nine; canonical 383 once; packages for both
  platforms against one runtime anchor.
- **Phase 5:** human/GPU/release acceptance and publication; keep `e731fd53`
  until then.

## 9. Facts vs assumptions

**Observed facts:** all commit hashes, job/timeout counts, file paths, `.gitignore`
and `source-lock.json` contents, host resource values, the absence of
`AnimationPlayer`/`AnimationTree` in GDScript, and the absence of fighting
rigs/clips in `godot/fighting/`. Numbers quoted (11,185 s sum; 14 jobs ≥300 s; 42
`native-import` dependents; 381+2 canonical gates; 205 worktrees; 6 duplicate
content-commit hashes; 336 clip requirements; 225 victim instances) are direct
static reads.

**Assumptions / proposals (not measured):** that import-cache reuse removes
meaningful repeated work; that a two-character slice de-risks the full roster;
that splitting the ledger improves iteration speed; that art lanes will respect a
two-pass budget; that memory/disk headroom is needed before any parallel heavy
work. All qualitative benefits are labelled as such; **no runtime or percentage
was benchmarked** and none should be quoted as measured from this report.

## 10. References (primary; 8)

1. Godot Engine 4.5 documentation, *Command line tutorial* — `--import` "Starts
   the editor, waits for any resources to be imported, and then quits. Implies
   `--editor` and `--quit`."; `--headless` = `--display-driver headless
   --audio-driver Dummy`. <https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html>
   (4.5; accessed 2026-10-02).
2. Godot Engine 4.5 documentation, *Import process* — imported resources live in
   the hidden `res://.godot/imported/`; deleting the folder forces reimport;
   committing `.godot/` "can shorten reimporting time when checking out on another
   computer" but is not recommended. <https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/import_process.html>
   (4.5; accessed 2026-10-02).
3. Godot Engine issue #111048 (Calinou, opened 2025-09-29), *Crash in GDExtension
   documentation generation when using `--headless --import`…* — timing-sensitive;
   `--import` generally more robust than `--editor`.
   <https://github.com/godotengine/godot/issues/111048>.
4. Trunk Based Development (Paul Hammant), *Short-Lived Feature Branches* —
   "should only last a couple of days."
   <https://trunkbaseddevelopment.com/short-lived-feature-branches/>.
5. Atlassian, *Trunk-based development* — "Develop in small batches."
   <https://www.atlassian.com/continuous-delivery/continuous-integration/trunk-based-development>.
6. Martin Fowler, *Test Pyramid* (published 2012-05-01) — many more low-level
   tests than slow high-level broad-stack tests.
   <https://martinfowler.com/bliki/TestPyramid.html>.
7. Reproducible Builds, *Definitions* — same source, environment and instructions
   must yield bit-identical artifacts, verified by hash.
   <https://reproducible-builds.org/docs/definition/>.
8. Machalica, Samylkin, Porth, Chandra, *Predictive Test Selection* (arXiv:1810.05286v2;
   Facebook Engineering, 2018-11-21) — select the subset of tests most likely to
   fail for each change. <https://arxiv.org/abs/1810.05286>.
