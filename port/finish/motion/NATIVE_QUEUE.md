# Supplemental motion/UI native acceptance — K

Worktree: `cocs-motion-native-review-20261003`, branch `feature/motion-native-review`.
Initial parent merged: `e858c054`. Authorization: `MOTION-UI-NATIVE-20261003-K`.
**In progress; K has not been released.** No package is built by this queue.

## Evidence and checkpoints

Evidence root: `/home/mojo/.tmp-on-disk/cocs-motion-native-evidence-20261003`.
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
  Compact results/restart/audio restoration is a separate bounded run underway.

### Texture import policy observation

`moth-import-policy.json` records all 116 tracked Moth PNG SHA-256 values.
All 116 received local `.import` sidecars; none are tracked. Observed sidecars use
`compress/mode=0`, `compress/normal_map=0`. No speculative importer-mode change
was made. Native captures load these assets; the binder lifecycle gate explicitly
checks installation, texture resources, team isolation and teardown across nine
profiles. Sidecar commit completeness remains a package-owner decision.

## Fixture audit

Biomes' obsolete whole-leg-yaw expectation becomes finite imported ankles and
>8 cm lateral ankle travel, explicit absent support in its no-floor lane, and
grip residual within 3 mm after authored reach clamp. Animation transition tests
check actual leg reach, finite ankles, absent fabricated support, grip residual,
and matching physical-time samples across frame rates. The nine-operator world
fixture checks actual imported pivot membership and 0.69 m thigh+shin length,
in addition to existing world-plant checks. Legacy source transform comparisons
remain; an added channels-only `rig.update(...,false)` check asserts no joint writes.
Gallery captures fail on PNG errors or an incomplete 216-frame set.

Four Python runner-policy tests and five actual-GLB/math source tests passed.
Those results do not establish native physical or visual acceptance.

## Commands and grant scope

Dry plans launch no engine or server:

```sh
python3 tools/motion-review/native_queue.py --scope contracts
python3 tools/motion-review/native_queue.py --scope graphics
python3 tools/motion-review/native_queue.py --scope live-kick
```

Execution requires an exact reviewed candidate HEAD and explicit grant:

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

Integrate Astra's third-person bridge and Sol's sports/HUD/audio lifecycle fixes
when delivered, preserving exact original and merged evidence anchors. Verify
the new operator overlay, nine-profile/three-strike phase images, reduced motion,
ADS/FOV, shared race restart/leave/audio/UI150, and routed-input vehicle camera
journeys. Direct vehicle contracts are not live driving evidence. Existing old
camera/private Stormglass evidence does not validate the new camera behavior.

The final 142-case matrix remains parent-owned; this is a supplemental gate.
Runtime fixes cause package drift for the package owner to reconcile. Software
rendering captures establish observable output, not human feel or GPU cadence.
Before handing native ownership away, audit all owned process groups empty
three times and publish explicit K release evidence.
