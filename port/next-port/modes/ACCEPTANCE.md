# Competitive modes acceptance

## Passed without engine use

Evidence root: `/home/mojo/.tmp-on-disk/cocs-port-modes-evidence-20261001`.

- `verification-final.tap`: **81 tests passed, zero failures** across bounded source
  parity, the existing `game/extra-modes.test.mjs`, package/dev options, route
  capabilities and route regression tests.
- `source-parity.test.mjs`: source-supported identity for all eight pairs;
  all-ten-weapon infinite Arsenal grants and switching; crown shield/transfer/
  scoring/winner; explicit unused source damage flag; friendly-fire attack
  filtering, enemy and self-death tickets, paid respawn and zero-life results;
  VIP proximity movement, hold/decay, extraction win, death failure and timeout.
  **These are bounded direct-source fixtures with explicit positioning/damage,
  not full-round gameplay or native acceptance.**
- `connected-round.log`: normal-rate source wire round, default 30-point crown
  target, 40.0167 source seconds / 38.627 wall seconds, two distinct players,
  late read-only spectator, real disconnect/resume, ordinary input, source
  winner, host restart and fresh revision. The initial resume assertion checked
  a missing welcome actor field; follow-up `connected-round-seat-verified.log`
  explicitly checks `welcome.reconnected` and the assigned lobby actor ID.
  Follow-up passed: 38.639 wall seconds, 40.0167 source seconds, resumed actor 1,
  1,537 ordinary input frames, source winner actor 0, restart revision 2.
- `node tools/godot-package/gen_routes.mjs --check` is also covered by route
  tests. The new route is parser-derived; all previous route tests remain.

Reproduce Node checks:

```sh
node --test port/next-port/modes/source-parity.test.mjs game/extra-modes.test.mjs tools/godot-package/options.test.mjs tools/godot-package/route_parity.test.mjs tools/godot-package/native_showcase_options.test.mjs tools/godot-package/native_arena_options.test.mjs tools/godot-dev/launch_options.test.mjs tools/godot-dev/native_showcase_options.test.mjs
node port/next-port/modes/connected-round.mjs
```

## Preserved failed attempts

- `source-parity-initial-failure.tap`: incorrect fixture input envelope and
  direct `damage()` call bypassing attack-layer friendly-fire filtering.
  Corrected to `{inputs:{0:{weapon}}}` and source `detonate()` filtering.
- `routes-initial-failure.tap`: pre-expansion expected route/experience lists and
  default bot argument assertions. Updated explicit expected rosters; no test
  removed or weakened.
- `routes.tap`: follow-up caught remaining 13 → 14 experience count assertion.
  Corrected before the passing `verification.tap` run.
- Initial `ws` resolution failed before linking the parent's `node_modules`.
  The requested symlink is now in place; no dependency installation occurred.

Final evidence SHA-256:

| File | SHA-256 |
|---|---|
| `verification-final.tap` | `9767c7df3e332dbe1fc502fddb9fe9dddb41f44d8697bf566f9476c35faee3a6` |
| `connected-round-seat-verified.log` | `680a1e61be9c2ab188e2a799c6e9ae935ad39e2e2309eb48553c40f43b88fa67` |
| `source-parity-initial-failure.tap` | `42ab1dc46470af0340abef84d41673ce1d77dce40c619793dd11dc08fc17a9a7` |
| `routes-initial-failure.tap` | `00379dd6433bcc83a17c6c213f4a99b44d79a06549856dcaee9a7b189d7dab27` |

## READY FOR ENGINE — not yet native accepted

No Godot/Blender/import process has run in this lane. Native scripts have not yet
been parsed by Godot. The parent must grant the engine slot before these steps.

Prepared `native-proof.mjs` uses two real Godot scene instances (1280×720 host,
960×640 guest), source authority at normal tick rate, native ordinary fire input,
late wire spectator, guest transport interruption/reconnect, source results,
host restart and native screenshots. It never mutates `Room`/`Match` state.

After grant, serialize these invocations (the runner requires explicit `GODOT`):

```sh
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 LP_NUM_THREADS=1 node port/next-port/modes/native-proof.mjs --mode=juggernaut
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 LP_NUM_THREADS=1 node port/next-port/modes/native-proof.mjs --mode=team-elimination
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 LP_NUM_THREADS=1 node port/next-port/modes/native-proof.mjs --mode=vip-escort
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 LP_NUM_THREADS=1 node port/next-port/modes/native-proof.mjs --mode=arsenal
```

This runner proves normal-round outcomes including VIP timeout; it does **not**
claim ordinary-input successful VIP extraction or gunplay-driven crown transfer.
Those remain additional native journey checks, as do Home selection, manual
Leave/Home, screenshot inspection, all-map smoke and packaged Linux/Windows
acceptance. Preserve engine failures and screenshots when running. Record actual
results here rather than treating this prepared harness as a pass.
