# Supplemental motion/UI native acceptance — K

Worktree: `cocs-motion-native-review-20261003`, branch `feature/motion-native-review`.
Initial parent merged: `e858c054`. Authorization: `MOTION-UI-NATIVE-20261003-K`.
**K RELEASED at 2026-10-03T07:02:45.157525Z.** Native results include one failed
live-kick acceptance gate; this is not an all-green release. No package was built.

`release-K.json` under the evidence root contains three consecutive empty owned
process audits at 07:02:44.462254Z, 07:02:44.810703Z and 07:02:45.157525Z.
All 74 retained PGIDs are empty. Fifty early attempts predate PGID retention;
their bounded-runner receipts record reaped leaders and empty descendant cleanup,
and the final audits additionally scan worktree/evidence ownership tags.
An initial broad native-name scan found unrelated browser/viewer infrastructure;
its blocked receipt is retained. Final audits record these unowned services
separately. None were signalled or claimed as this lane's work.

## Evidence and checkpoints

Evidence root: `/home/mojo/.tmp-on-disk/cocs-motion-native-evidence-20261003`.
`NATIVE_RESULTS_K.json` indexes all retained stages and original source hashes:
latest status is 64 passed gate IDs (including typechecks) and one failed
`live-kick` gate. This is supplemental coverage, not 64 final-matrix approvals.
Each run retains `queue.json`, dependency hashes, argv, deadlines, exit status,
native logs, and descendant cleanup results. Native runs are serialized under
`/tmp/opencode/cocs-finish-acceptance.lock`, with isolated preferences and
`LP_NUM_THREADS=1`. Existing `finish_runner.run_bounded` provides subreaper cleanup.

- `k-initial`: import failed on binding-search inferred Variant types.
  Fix `7d2fa666` explicitly types the string and predicate.
- `k-import-fix`: import passed; Home dependency typecheck exposed operator
  discontinuity inference. Fix `85bb8855` is a one-line boolean annotation;
  operator overlay owner must incorporate it.
- `k-types-2`: all 22 UI/motion contract scripts passed native typechecking.
  Home behavioral test exposed deferred arrival focus stealing category focus.
  Fix `58bbe208` preserves existing foreground focus.
- `k-contracts-3`: Home search, Home contracts (1,127 checks), bindings,
  journal model, and journal input passed. Fighting real-core contact fixture
  failed: movement stopped after only 60 post-intro ticks. Revised ordinary
  command continues approach through recovery; replay equality remains required.
- `k-contracts-4`: fighting feedback/replay passed; HUD fixture timed out on a
  missing simulation instance. `8094fbec` fixes fixture initialization and the
  ordinary core approach; it also defers kick-chain anatomy queries until tree entry.
- `k-contracts-5`: HUD wide/compact and first-person lifecycle passed. Binding
  requires real pointer capture; its initial headless execution failed.
- `k-contracts-6`: binding under owned Xvfb and ADS contract passed. Kick fixture
  exposed early global-transform queries, corrected in `8094fbec`.
- `k-parent4cc-import-contracts`: parent `4cc0292d` merged at safe boundary;
  import, new sports type checks, and 76 kick-chain checks passed. Old sports
  camera test hardcoded discarded offsets; replacement checks physical rear/above
  placement, rotational covariance, and exact teleport translation.
- `k-contracts-7`: sports controls and initial lifecycle passed. Sports polish
  timed out because the worktree lacked `content/generated/manifest.json`.
  Standard semantic preparation with the existing locked derivative succeeded:
  `COCS_SOURCE_DERIVATIVE=port/contracts/lattice-catalog-derivative.json node tools/godot-export/semantic.mjs`.
  This generates diagnostic map JSON, not a package or visual asset export.
- Parent `38dfb3bd` merged at the next safe boundary. Melee typecheck found a
  dynamic eligibility inference error; runtime fix is `9351ed49`.
- `k-bridge-typed`: melee typecheck, 540 nine-operator gait cases and 27
  accepted-event operator/strike cases **passed natively**. Maximum stance drift
  0.000209365 m; maximum target residual 0.000208896 m; maximum grip residual
  0.000003847 m. Melee ankle travel 0.775980–0.870201 m; maximum support error
  0.000000043 m. These are fixed-step physical measurements, not visual acceptance.
- `k-operator-graphics`: **passed**, 216 gait PNGs and 243 melee PNGs. Inspected
  Gemini lateral gait and ChatGPT side/contact kick; both show articulated limbs.
- `k-rest-contracts` / `k-rest-fixes`: native results exposed stale fixed camera
  offsets, a diagonal expectation with the old steering sign, unowned eager
  nodes in the session stub, and an exact scalar/Vector3 precision mismatch.
  Corrected physical camera/command invariants and fixture teardown now pass.
  Sports lifecycle now awaits actual 760×520/UI150 layout, checking nonzero bounds.
  Operator legacy matrices, measured grips, biomes, ordinary/world motion and
  campaign motion pass. Animation transition convergence initially failed by
  up to 0.245460 m; this was a real frame-rate-dependent phase integration bug.
- `88c65c9f`: integrate the velocity-filter stride trajectory at bounded midpoint
  samples; decorate copied public presentation actors with real reduced-motion
  preferences. `k-motion-integral` passes the strict 3 cm cross-rate transition
  gate, 540 gait cases, 27 melee cases, and the actual settings-toggle pipeline.
- `k-fps-graphics`: **passed**, 135 normal + 135 reduced-ADS kick PNGs across
  nine profiles/three strikes/five phases, with camera FOV consistency assertions;
  native ADS projection and handling capture gates also passed.
- Parent `5b5c8791` promotion merged at a safe boundary. `b9e2a9eb` fixes the
  previously hardcoded generated shared sports route to admit public Stormglass;
  `generate-scenes.mjs --check` passes. No source authority was edited.
- `k-vehicle-live-authority`: **passed**, ordinary Enter/W/D/F4/Escape through
  the real shared public Stormglass client and accepted derived authority.
  Four native images show third/first-person driving and turning. Earlier retries
  retained missing Node dependency and wrong authority runner configuration errors.
  `k-vehicle-live-restart-compact` also **passed**: actual 60-second source results,
  UI150 physical bounds, F5 restart, cleared outcome/restored persistent music,
  drained driving latch and Home teardown. No private audio/HUD overrides.
- `k-finish-binder`: **passed**, actual ResourceLoader textures and material
  installation for all nine profiles, 200 team updates, rebind and double clear.
- Live kick producer: **not accepted**. `f272221f` adds explicit owned loopback
  Xvfb support after the Unix socket failure. `3576de58` prepares the validated
  semantic map JSON in its tracked-only private project. `278c4962` records an
  explicit software profile (3D scale 0.5, weapon MSAA off, 1280×720 PNG output).
  `k-live-kick-semantic` and `k-live-kick-software` reached real native F input,
  ADS, source-accepted 45-damage hits and PNG output. Both failed the unchanged
  early-press/contact timing gates: last attempt captured age 0.249558 s at
  694 ms receipt-to-render, outside required 0.095–0.160 s. The nominal early
  second press arrived 0.916 source seconds later, after cooldown/chain window.
  These captures are retained as failure evidence, not accepted contact images.
  No source clock, cooldown, pose age, acceptance threshold, or damage was altered.
- `k-final-operator-graphics`: **passed**, refreshed 216 gait + 243 accepted-event
  melee images on final runtime at `278c4962`. Earlier successful galleries
  retain their original per-stage source anchors.

## Results and remaining acceptance gaps

All completed direct UI, first-person, vehicle, world-motion, biome, legacy-rig,
gait, event-melee, reduced-settings and finish-binder gates pass after the recorded
fixes. This includes native APIs/runtime, not only grammar. First-person staged
kick/ADS projections and public race camera/restart journeys pass. Live-kick
normal-rate contact acceptance remains failed on this software renderer.

The new live vehicle journey proves the public Stormglass Puma race route only.
Combined-arms and ordinary world-session new camera behavior have native contract
coverage (including mounted orientation and cockpit), not new ordinary-input
mount/look/demount capture evidence. Those journeys remain a supplemental gap.
UI contracts pass; headless HUD geometry is not human rendered-layout approval.

Selected real images under the evidence root:

- `k-final-operator-graphics/operator-gallery/gemini-strafe-44.png`
- `k-final-operator-graphics/operator-melee-gallery/chatgpt-side-strike1-095.png`
- `k-fps-graphics/kick-captures/chatgpt-kick1-095ms.png`
- `k-fps-graphics/kick-reduced-ads/chatgpt-kick3-095ms.png`
- `k-vehicle-live-authority/vehicle-live/evidence/first-drive.png`
- `k-vehicle-live-restart-compact/vehicle-live/evidence/public-results.png`
- `k-vehicle-live-restart-compact/vehicle-live/evidence/public-restart.png`

The fixed-step galleries are staged pose evidence; only the public race and
live-kick producer use routed input plus normal authoritative transport. No GPU
performance or human-feel acceptance is inferred from software-rendered output.

### Texture import policy observation

`moth-import-policy.json` records all 116 tracked Moth PNG SHA-256 values.
All 116 received local `.import` sidecars; none are tracked. Observed sidecars use
`compress/mode=0`, `compress/normal_map=0`. No speculative importer-mode change
was made. Native captures load these assets; the binder lifecycle gate explicitly
checks installation, texture resources, team isolation and teardown across nine
profiles. Sidecar commit completeness remains a package-owner decision.

## Fixture audit

Fix/checkpoint commits (merge commits also retain the supplied parent anchors):

| Commit | Change |
| --- | --- |
| `7d2fa666` | Native binding-search string/boolean inference |
| `85bb8855` | Native operator snapshot discontinuity boolean |
| `58bbe208` | Deferred Home arrival preserves existing foreground focus |
| `8094fbec` | Real-core approach, HUD simulation init, kick fixture tree lifetime |
| `9351ed49` | Native melee eligibility boolean |
| `a0bc8b82` | Physical fixtures, phase galleries, supplemental bounded runner |
| `88c65c9f` | Frame-rate-independent stride integration and actual reduced settings |
| `b9e2a9eb` | Public Stormglass shared sports admission and generator |
| `ab943174` | Correct vehicle/motion fixture oracles, leak-free stub, public live race |
| `f272221f` | Explicit private loopback Xvfb option |
| `3576de58` | Locked semantic preparation inside live-kick private stage |
| `278c4962` | Explicitly recorded software-render live-kick profile |

Biomes' obsolete whole-leg-yaw expectation becomes finite imported ankles and
>8 cm lateral ankle travel, explicit absent support in its no-floor lane, and
grip residual within 3 mm after authored reach clamp. Animation transition tests
check actual leg reach, finite ankles, absent fabricated support, grip residual,
and matching physical-time samples across frame rates. The nine-operator world
fixture checks actual imported pivot membership and 0.69 m thigh+shin length,
in addition to existing world-plant checks. Legacy source transform comparisons
remain; an added channels-only `rig.update(...,false)` check asserts no joint writes.
Gallery captures fail on PNG errors or an incomplete 216-frame set.

Five Python runner-policy tests, twenty existing bounded-runner tests, nine
live-kick policy/contract tests, four melee-source tests, and five actual-GLB/math
source tests passed. Scene generator consistency also passed.
Those results do not establish native physical or visual acceptance.

## Commands and grant scope

Dry plans launch no engine or server:

```sh
python3 tools/motion-review/native_queue.py --scope contracts
python3 tools/motion-review/native_queue.py --scope graphics
python3 tools/motion-review/native_queue.py --scope live-kick
```

Execution requires an exact reviewed candidate HEAD and explicit grant. The
following are historical K command forms; after K release obtain a new grant:

```sh
python3 tools/motion-review/native_queue.py --scope contracts --execute --grant MOTION-UI-NATIVE-20261003-K --candidate "$(git rev-parse HEAD)" --output /tmp/opencode/motion-k-contracts
python3 tools/motion-review/native_queue.py --scope graphics --execute --grant MOTION-UI-NATIVE-20261003-K --candidate "$(git rev-parse HEAD)" --output /tmp/opencode/motion-k-graphics
python3 tools/motion-review/native_queue.py --scope live-kick --execute --grant MOTION-UI-NATIVE-20261003-K --candidate "$(git rev-parse HEAD)" --output /tmp/opencode/motion-k-live
```

Run sequentially. Live-kick owns the shared lock internally: the outer runner
does **not** hold it while launching the producer, and passes the grant explicitly.
Lock collision is a failed attempt, never a wait or implied authorization.
Direct gates flatten existing seven UI case definitions instead of nesting their
lock-owning runner. Missing success markers, explicit fixture failures, native
errors, resource leaks, timeouts, and remaining descendants fail acceptance.

## Remaining acceptance

The delivered operator bridge, Sol lifecycle fixes, and public Stormglass catalog
are integrated. Remaining gaps are explicitly listed above. Existing old
camera/private Stormglass evidence is not used to validate the new camera behavior.

The final 142-case matrix remains parent-owned; this is a supplemental gate.
Runtime fixes cause package drift for the package owner to reconcile. Software
rendering captures establish observable output, not human feel or GPU cadence.
Before handing native ownership away, audit all owned process groups empty
three times and publish explicit K release evidence. **Completed**, as recorded
above. All engine/server/render work has stopped. Generated untracked `.uid` and
`.import` metadata is archived externally in `generated-sidecars-final/` to keep
the source handoff clean; no generated metadata was silently promoted.
