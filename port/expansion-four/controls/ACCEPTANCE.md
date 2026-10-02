# Controls acceptance — READY FOR ENGINE

## Checks actually executed

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-expansion-four-controls-evidence-20261002/`

| Check | Result |
|---|---|
| `node tools/port/input-bindings/source-oracle.mjs` | PASS: 25 exact defaults, 9 malformed/duplicate normalization cases, **1,075 actual source swaps**, 14 actual page-handler input timelines / **98 source samples**, 4 source modal transitions |
| `node --test game/keybinds.test.mjs game/input.test.mjs game/movement-input.test.mjs game/cursor-mode.test.mjs game/onboarding.test.mjs` | **53/53 passed**, zero failures |
| `node --check tools/port/input-bindings/native-journey.mjs` | PASS, syntax only |
| `gdtoolkit.parser` on changed/new `.gd` files | PASS, syntax only; not Godot type/runtime acceptance |
| `git diff --check` | PASS |

The first source-oracle attempt failed because Node strict equality distinguishes
`-0` from `0`. The oracle now compares source samples at their actual JSON wire
boundary, which serializes signed zero as zero. Failure retained in
`source-oracle-initial-signed-zero-failure.log`; accepted output in
`source-oracle.log`. Source regression TAP is `source-regressions.log`; parser
result is `gdscript-syntax.log`. A preliminary stock gdtoolkit lint invocation
reported repository-style long lines / definition order / return-count style
violations; it was not an engine or parser failure. Only syntax acceptance is
claimed. The local parser dependency was installed under
`/tmp/opencode/controls-gdtoolkit`, not added to production dependencies.

**No engine, import, render, native test, screenshot, source-wire native journey,
Blender job or export ran. Parallax's slot was not used.**

## Prepared native contracts

`godot/tests/input_bindings/contracts.gd` consumes fixtures produced by actual
source functions, compares real native samplers, and exercises:

- Source defaults/ordered malformed repair and every source occupied-key swap.
- Old keys inert/new keys active, held sample counts, repeats, releases and
  one-shot consumption for world and Horde.
- Every offered physical key/button codec, reserved keys and unsupported chords.
- Fire/ADS/melee/mobility/movement/crouch/jump under all named boundary clears,
  keyboard/mouse/right-modifier targets, release-to-original-action after rebind.
- Short-X busy-queue retention; held crouch+jump; independent middle-mouse alt.
- Sports/Combined Arms one-pass remapping and fresh Enter/release requirements.
- Atomic local persistence, unknown-field retention, defaults reset.
- Signal-updated binding hints, reused-results-label ownership, physical
  modifier-side freshness and named/focusable native accessibility fields.

After the parent's explicit grant, from this worktree:

```bash
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
timeout 120s env LP_NUM_THREADS=1 "$GODOT_BIN" --headless --editor --path godot --import
timeout 60s env LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/input_bindings/contracts.gd
```

Then rerun existing gates sequentially, with isolated user preference paths and
the parent's normal native test runner/display configuration:

```text
godot/tests/combat_actions/controls.gd
godot/tests/player_gameplay/test.gd
godot/tests/horde/controls_test.gd
godot/tests/sports/test_controls.gd
godot/tests/combined_arms/test_controls.gd
godot/tests/arms_race/fixtures.gd
godot/tests/arms_race/independent_fixtures.gd
godot/tests/product_shell/settings_contract.gd
godot/tests/protocol/input_queue.gd
godot/tests/protocol/stall_controls.gd
```

## Prepared live GUI / wire journey

`tools/port/input-bindings/native-journey.mjs` has an explicit scheduling flag,
80-second process watchdog and teardown. It launches the normal source server,
real `world/session.tscn`, native Settings dropdowns and `Input.parse_input_event`.
It records every actual wire input and source events. It does not write actors,
health, position, source rules or simulation state. Its transport fixture only
temporarily suppresses snapshots/events to exercise staleness. The final
spectator identity check is expressly synthetic and labeled as such.

It prepares keyboard-operated choices for fire, melee, mobility, movement, power
and crouch; verifies persisted reload, default keys becoming inert, new power and
melee queueing exactly once and producing one source event, repeated held fire /
mobility / crouch / movement samples, release/typing through Settings, no replay
after recapture or staleness, no spectator neutral packet, and the **actual**
Experience power/grapple binding hints. Screenshots are captured for inspection.

Run wide and compact **serially**, after the contract gate passes:

```bash
EVIDENCE_DIR=/home/mojo/.tmp-on-disk/cocs-expansion-four-controls-evidence-20261002/native-wide \
  node tools/port/input-bindings/native-journey.mjs --engine-granted
EVIDENCE_DIR=/home/mojo/.tmp-on-disk/cocs-expansion-four-controls-evidence-20261002/native-compact \
  node tools/port/input-bindings/native-journey.mjs --engine-granted --compact
```

The runner expects the parent's existing `ws` dependency and `xvfb-run`. Its
software/Xvfb and synthetic InputEvent evidence must not be labeled OS/human,
hardware performance or screen-reader acceptance. Preserve failed runs.

## Next acceptance beyond the prepared base-world journey

1. Native side-button and left/right-modifier event round-trips on the actual OS;
   old fire/melee/mobility/movement bindings inert, new ones trigger once/hold as
   intended, keyup neutral. Test default and reset profiles.
2. Select an already occupied binding in Settings; both visible fields and
   accessible descriptions must swap, survive reload and update HUD hints.
3. Mouse-scroll and keyboard-scroll the entire Settings panel at 1280×800/UI100
   and 760×520/UI150. Inspect popups, focus ring, reset, Back and pointer capture.
4. Real lobby chat/Career/death/reconnect transitions while mapped keyboard and
   mouse actions are held; no stale actions or queued replay on resumption.
5. Execute each route in the PARITY matrix, including spectator/freecam seats,
   LATTICE C/number menus, Horde offers, sports Enter/reset and mounted/seat-change
   Combined Arms. Check source FIFO/sample counts rather than HUD alone.
6. Keep incoming Gameplay's actual Grok charge/release and held-X grapple/source
   rope tests. The mapper changes physical input resolution, not those mechanics.
7. Parent merges shared hooks, registers canonical gates/resources, validates
   export test exclusions, then rebuilds/exports and publishes separately.
