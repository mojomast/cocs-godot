# Second-pass modes/progression acceptance

## Current state: READY FOR ENGINE

No Godot, Blender, import, render, package build, or engine-version invocation
has been run in this lane. Helix, then Foundry/Parallax, have the scheduled heavy
slot. Native parsing, actual UI acceptance and screenshot inspection remain
pending an explicit grant.

Evidence root:
`/home/mojo/.tmp-on-disk/cocs-pass-two-modes-evidence-20261002`.

## Passed Node/source checks

`node-final.tap`: **116 tests, 116 passed, zero failures**.

`launcher-final.tap`: **8 additional process-boundary tests passed** (124 total
across the two final runs). These use explicitly synthetic Node executables,
not Godot: three menu/owned-route cycles in each launcher preserve settings,
flush history and close listeners; external lobby never creates owned authority.

```sh
node --test tools/godot-package/menu_journey.test.mjs tools/godot-package/lobby_ownership.test.mjs
```

```sh
node --test port/pass-two/modes/challenges.test.mjs port/next-port/modes/source-parity.test.mjs game/challenges.test.mjs server/progression.test.mjs tools/godot-package/options.test.mjs tools/godot-package/route_parity.test.mjs tools/godot-package/manifest_validation.test.mjs tools/godot-package/career_path.test.mjs tools/godot-dev/launch_options.test.mjs
```

New journey fixture:

- Twelve natural source Juggernaut rounds; source 1/60 stepping with accelerated
  wall time, no stat/position/XP seeding or forced result. Explicit deterministic
  source challenge date `2026-10-02`.
- **2,960 XP, 870 challenge XP included, 9 unlocks**; all per-round XP exactly
  matches direct source `applyMatchAll → awardMatch` composition.
- Equip the earned Precision Scope through existing owned source equipment
  authority; reject a wrong token; retain equipment through awards and reload.
- Disconnect/resume the actual Room seat after every settlement: replayed results
  and source profile, no new progression award.
- Duplicate settlement and copied result object refused; subsequent source tick
  does not increase matches/XP.
- Same atomic disk payload contains both exact XP and challenge counters.
- Two authority lifetimes, six rounds each; source history retains six records
  per isolated lifetime. Production native runner separately uses persisted history.
- Failed disk write preserves one in-memory settlement; existing source retry
  persists the same award. A new UTC day/week resets only rotation counters,
  preserving source XP.

`runtime-discovery.json` / `.log`: actual static runtime closure discovery passes,
including the new explicit adapter and source challenges module. Manifest fixture
regressions also pass. `node --check` of the native runner and `git diff --check`
pass; neither executes the engine.

Earlier passing files retained: `challenges-attempt1.tap` and `node-attempt2.tap`.
`launcher-attempt1.tap` is retained too: the synthetic menu fixtures still supplied
the old frozen-server entry path. They now supply the new owned-factory path;
all lifecycle assertions remain intact. External-lobby fixtures explicitly reject
construction of either factory.

## VIP failed attempts retained

- `vip-attempt1.log`: diagnostic import incorrectly requested `floorAt` from
  terrain; corrected to its actual `game/core.mjs` export. No source file edited.
- `vip-failed-input-attempt2.json` and `vip-attempt2.log`: full 180-second ordinary
  human-input source attempt with checkpoint samples, exact bulkhead and isolated
  copy-only locomotion witness. **No extraction, defender timeout, progress 0.**
- Historical first-pass failure remains at
  `/tmp/opencode/modes-engine-20261001/vip-source-input-probe.json`.

Reproduce without engine:

```sh
node port/pass-two/modes/vip-probe.mjs /absolute/new-evidence-path.json
```

## Prepared engine follow-up — not yet passed

Only after an explicit slot grant, pinned Godot 4.5.2, `LP_NUM_THREADS=1`:

```sh
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/mode_expansion/challenges_contracts.gd
CHALLENGE_ENGINE_GRANT=1 GODOT_BIN=/absolute/pinned/Godot_v4.5.2-stable_linux.x86_64 LP_NUM_THREADS=1 MODE_EVIDENCE=/absolute/new-evidence-directory node port/pass-two/modes/native-proof.mjs
```

The new test-only scene is `godot/tests/mode_expansion/challenges_live.tscn`.
It uses the actual mode-expansion scene and Career autoload, three naturally
completed 40-second crown rounds, wide/compact challenge and settlement panels,
real transport reconnect after earning a weekly bonus, source restart, then
complete process/authority recreation and one additional natural round.
The runner uses the source date above for reproducible real source rotation;
it never seeds rewards/counters or accelerates the authority clock.

Expected evidence: modal/control-release assertions, source award/read-only
reconnect checks, earned status on the second native process, private credential
continuity, sanitized persisted XP/gear/unlock/challenge proofs, all logs and
screenshots. Runtime credentials are removed with the isolated temporary tree.
The runner owns a private Xvfb and sequential Godot processes and records cleanup.

Follow-up must inspect screenshots directly and record actual native results,
preserving failed runs. Run existing `godot/tests/career` contracts and the mode
contract against the combined parent branch as appropriate. Shared session/HUD,
all-map checks, export visual checks, canonical gate counts and Linux/Windows
package acceptance remain parent integration responsibilities.

**No native success, package success, or ordinary-input VIP extraction success
is claimed by these prepared fixtures.**
