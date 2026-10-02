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

## Original pre-grant handoff (historical)

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

## Native follow-up after exclusive grant — 2026-10-02

**Four connected native mode journeys PASS.** Engine: pinned Godot 4.5.2, software
OpenGL under Xvfb, `LP_NUM_THREADS=1`, Dummy audio. Tests ran sequentially. Each
journey has a 1280×720 native host, 960×640 native guest, 960×640 late native
spectator, and a read-only wire spectator collecting source outcomes. No source
state, score, actor position, geometry or frozen gameplay module was modified.

Current evidence root: **`/tmp/opencode/modes-engine-20261001`**.

| Run | Source outcome | Ordinary native shots | Evidence |
|---|---|---|---|
| Juggernaut, no bots | Actor 0 reaches 30.0125 points at 40.0167s | host 341 / guest 285 | `final5/juggernaut/` |
| Team Elimination | Source time/ticket tiebreak, Red wins at 60.0167s | host 509 / guest 432 | `final5/team-elimination/` |
| VIP Escort | Defender Blue timeout at 60.0167s, extraction 0/4s | host 512 / guest 407 | `final5/vip-escort/` |
| Full Arsenal | Source draw at 60.0167s | host 512 / guest 500 | `final5/arsenal/` |
| Juggernaut, two source bots | Real source combat transfers crown **0 → 3** at bounty 3; actor 3 wins at 44.4333s | Real native players and source bots fire | `combat-events/juggernaut/acceptance.json`, `wire-events.json` |

Every run asserts the actual guest reconnect resumes its player seat, both
players and the native spectator receive results and the next source round,
native spectator input is denied, results/Leave disable controls and release the
pointer, and all three native clients return to Home. The Home probe operates
the actual map/mode choice signals, checks the assembled route arguments, and
focuses/scrolls to START before capturing the compact setup. Reconnect start
envelopes no longer increment the displayed round count.

Screenshots inspected directly:

- `final5/juggernaut/{host,guest-results,guest-home}.png`
- `final5/team-elimination/{host,guest-home}.png`
- `final5/vip-escort/{host-results,guest-results,spectator}.png`
- `final5/arsenal/host-results.png`
- `combat-events/juggernaut/guest-results.png` (four-combatant compact paging)

Mode objective cards now reserve space below common status overlays. Scoreboards
reserve the card area, paginate larger rosters, use PTS/TIME headings, and show
source winners including actor/team zero. Spectators have an elevated fixed view,
read-only instructions, and no misleading “waiting for player” or combat-control
prompt. Common HUD/menu files are unchanged by this follow-up.

### Additional gates

- `contracts-final.log`: **MODE_NATIVE_CONTRACTS_OK**, no errors/leaks. Covers
  all four projections, zero-valued winners, carrier changes, clearing stale
  markers, VIP death and parsing the full scene dependency closure.
- `node-final.tap`: **81/81 pass** again after native work.
- Final native logs contain no `ERROR:`, `SCRIPT ERROR`, `Parse Error` or
  `MODE_NATIVE_ERROR`. Each directory retains `teardown.json` with all three
  processes reaped. The final runner waits for actual child close, using SIGKILL
  only as a timed fallback; server and spectator sockets are closed.

Parent gate commands (semantic assets must already be generated with the reviewed
derivative contract; no frozen-source bypass):

```sh
COCS_SOURCE_DERIVATIVE=port/contracts/lattice-catalog-derivative.json node tools/godot-export/semantic.mjs
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/mode_expansion/contracts.gd
# Run once per mode ID, sequentially under an available display or xvfb-run:
GODOT_BIN=/path/to/pinned/godot LP_NUM_THREADS=1 MODE_EVIDENCE=/tmp/opencode/unique-run node port/next-port/modes/native-proof.mjs --mode=juggernaut
```

Runner accepts `GODOT_BIN` with `GODOT` fallback, defaults evidence to a unique
`/tmp/opencode/mode-proof-<timestamp>` directory, and accepts optional `MODE_BOTS=2`
for additional real source combat. Canonical wiring remains parent-owned.

Parent integration registers the native contract and all four graphical journeys.
Contract and Home-probe scripts are moved into `godot/tests/mode_expansion/`,
outside production exports; the explicit developer fixture flag dynamically loads
the Home probe only during acceptance. Normal launches do not use that probe.

### Preserved native failures and corrections

- `attempt1`: missing semantic manifest in fresh worktree. An unqualified export
  correctly refused the derivative source; reviewed derivative export succeeded.
  Initial audio device failure prompted explicit Dummy audio for acceptance.
- `attempt2` / `attempt3`: empty inherited map selector caused an index error;
  selector now receives its catalog entries. A closing socket hit inherited input
  send failure before the reconnect ticket could survive; the mode scene now
  waits for Client's transport transition instead of treating this as fatal.
- Early screenshots overlapped objective instructions with the common status
  card. Mode-scoped layout and readable card background corrected this.
- `final1`: the initial Leave fixture mistook reconnect's repeated start envelope
  for a new round. Scene round accounting now respects `roundRevision`, and the
  fixture waits for actual prior results before leaving the restarted round.
- `contracts.log`: a detached scene-instantiation test leaked nodes normally
  attached in `_ready`. Contract now parses PackedScene state without constructing
  unattached composition nodes; `contracts-final.log` is clean.
- `combat/`: source combat transfer was visible in snapshots, but the runner read
  an incorrect event key. Source packets use `items`; `combat-events/` repeats
  the normal-rate round and preserves the actual crown-transfer event.

### Explicit limits

VIP successful extraction and VIP death-win are proven only by labeled bounded
source fixtures, not by these native full-round journeys. The additional
`vip-source-input-probe.json` comes from **accelerated source simulation with only
ordinary movement input**: following the VIP stalls near x=-32.35 while the
beacon is x=78, progress stays zero, defender wins at 180s. It is not native
evidence or a general impossibility claim. No source repair was smuggled in.

Native crown transfer is source-bot combat against the native host, not a claimed
human aiming/kill acceptance. Full Arsenal's connected proof is a draw; all-ten
weapon selection/unlimited grants are separately source-tested. Remaining four
Arsenal/Juggernaut map pairs and Linux/Windows 75-case packages are parent combined
acceptance responsibilities. This branch did not cherry-pick other lanes; the
parent must verify the final Experience HUD composition. **ENGINE SLOT RELEASED
at final handoff.**
