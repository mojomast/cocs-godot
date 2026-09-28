# Native consolidation foundation — 2026-09-28

This pass implements NATIVE-01, NATIVE-02 and the bounded menu-preference slice
NATIVE-03-A. It does not complete the full consolidation roadmap.

## Final result

**199/199 aggregate gates passed, zero unrun**, at tested port commit
`6b782f2b9aea7571ef02ccb4baa1065ad5d611df`. The serial run took 594.72 seconds
across its gate executions. Full repository lint also passed after the final
code changes. These are local Linux results; a hosted CI pass is not claimed.

- [Canonical machine-readable report](../../reports/verification.json)
- [Complete aggregate console](consolidation-2026-09-28.log)
- All 199 executed gate logs in `port/reports/<gate>.log` were refreshed from
  this same final attempt, including the expected release-refusal check.
- Highlighted contracts: menu **776/776**, REQ catalog **197/197**, REQ purchase
  lifecycle **60/60**, tactical HUD **16/16**.

The report honestly marks the worktree dirty because generated reports/fixture
outputs from prior attempts were present. The tested source bytes were still
independently verified against the frozen inventory. The derivative manifest's
SHA-256 is `f53f0ef56f53cf49dd42814becb2e5beab8c1d5d90d1f85ca6380ac8bf33d32e`.
Subsequent publication changes contain this evidence, documentation and the
generated menu-script UID, not additional gameplay changes.

## Provenance and environment

- Original source: `515daf07589150dd3241f4ae1425cc1b093912f5`.
- Explicit frozen derivative: `fa6dda2dcac5ab41b5496517acab9055407e31ae`, selected
  through `COCS_SOURCE_DERIVATIVE` and checked against its exact inventory.
- Separate validation worktree:
  `/home/mojo/.tmp-on-disk/cocs-consolidation-verify-20260928`.
- A real `npm ci --no-audit --no-fund` populated the fresh checkout's own
  dependencies. Semantic data and both required browser GLB probes were newly
  generated there; generated game content was not copied from the development
  worktree.
- Engine: official pinned Godot 4.5.2 Linux, reusing the already installed
  toolchain. Chromium was the existing Playwright-pinned browser installation.
  This run did not repeat the toolchain download or OS dependency installation.
- Engine/import/render/suite work ran serially. The aggregate uses private Xvfb
  displays for rendered/input fixtures.

## Focused observations

- Full repository lint passed after the gallery `no-this-alias` fix; existing
  warnings remain nonfatal.
- Native workflow/source-selection contracts passed 3/3. They check original-pin
  rejection, selected-derivative acceptance and wrong-byte rejection before
  starting engines or browser servers.
- Report preflight/failure contracts passed 4/4; registration contracts passed
  2/2. Failed reports retain executed and unrun gate distinctions.
- Both browser probe exports passed with the explicitly selected derivative.
- Menu contracts passed **776 checks, zero failures**, including repeated menu
  lifetimes, per-route options, map-dependent validation, debug exclusion,
  oversized/versioned/malformed data and unknown-field filtering.
- Horde upgrade loopback passed after the fixture was changed to finish its
  WebSocket close handshake before exiting Godot. Transport-error assertions
  remain strict. This is an accelerated offer fixture, not natural Horde play.
- Corrected LATTICE fixtures passed focused checks with clean teardown: map
  **32/32**, world **18/18**, commands **27/27**, usability **25/25**. A separate
  read-only review traced the new explicit fixture facts and HUD expectations
  against production ownership, unknown-state and input behavior and found no
  material issue. The repairs change test fixtures, not gameplay authority.

## Preserved failures and fixes

1. Fresh browser export initially rejected the source tree because it did not
   load the explicitly selected derivative. Active source-verifying launch and
   export callers now pass the selected manifest; the core verifier's default
   strictness is unchanged.
2. First aggregate attempt at `b177af57` stopped at `horde-closure`. Its byte
   comparison assumed every file used the original source commit. The corrected
   test first verifies the complete selected inventory, then compares each file
   with its exact original/derivative revision, matching the package builder.
   The focused closure tests passed 3/3.
3. Second aggregate attempt at `d256db5c` executed 157/199 gates: **156 passed**,
   Horde upgrade loopback failed, and 42 were unrun. Upgrade behavior and native
   assertions passed, but teardown recorded `Send failed`. The fixture now
   closes gracefully while keeping network polling alive, with a bounded close
   deadline rather than filtering transport failures.
4. The first new menu test run exposed Godot's noisy static JSON parser on a
   deliberately malformed preference file. Instance parsing now checks the
   error return and recovers without emitting engine errors.
5. Third aggregate attempt at `4cf21e77` executed 167/199 gates: **166 passed**,
   `lattice-map` failed three synthetic supply/guidance assertions, and 32 gates
   were unrun. Three intended neutral nodes omitted the `owner` field, which
   correctly means unknown rather than neutral to the recipient model. The
  fixture now declares `owner: null` explicitly; production semantics and
  assertions are unchanged.
6. A separate diagnostic ran the remaining 31 regular gates without relabeling
   the failed aggregate: **28 passed**, including REQ, tactical, flagship,
   objective, recovery and two-client checks. World/command contracts passed
   their assertions but leaked test-owned UI resources. The usability fixture
   also used stale round context and aborted before normal teardown. Targeted
   fixture corrections subsequently passed focused checks and the full final
   aggregate.

The failed aggregate reports/logs remain in the validation worktree under
`.port-runtime/verification-attempts/`; they were not rewritten as successful
attempts. The canonical report is replaced only by the subsequent actual run.

## Remaining boundaries

- A successful aggregate establishes bounded contracts and fixtures, not human
  acceptance. Hardware feel, native Windows execution, natural full-wave play,
  eight-human multiplayer and live native REQ settlement remain owner-run gaps.
- Menu persistence stores local convenience options only; source outcomes,
  wallet balances, purchases and career unlocks remain authoritative upstream.
- The legacy extracted-package verifier still has older inventory assumptions.
  NATIVE-06 must bind source verification to the package manifest's recorded
  derivative commit/hash rather than an ambient development selection.
- Cinderwake/Nacre integration, shared general settings/navigation/UI styling,
  mainline promotion and a consolidated Windows/Linux release remain open.
- No new playable release was built during this foundation pass.
