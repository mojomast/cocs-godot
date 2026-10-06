# Gate registry, tiers and candidate binding — F15

Full-registry complement to `GATE_STATUS.md`. That file records *which checks were
executed for the implementation*; this file records *what is registered*, how the
registrations are tiered by execution environment, and whether a verifier run is
bound to an exact candidate.

- Worktree: `/tmp/opencode/cocs-audit-f15-20261006`, branch `audit/f15-gate-tiers`,
  HEAD `db90f5507b6d8caf6cc5418fa95e09b5d09418f5`.
- Subject under audit: `tools/godot-dev/verify.py` (580 lines) and
  `tools/godot-dev/gate_runner.py` (58 lines).
- Method: `ast` parse of `verify.py` (no execution of the verifier), plus targeted
  reads of every script a registered gate launches in order to resolve its display /
  audio / engine dependency. No gate was executed for this document.

---

## 1. Registry inventory

### 1.1 How gates are registered

There are **two** registration mechanisms, and only one of them is a table.

**Mechanism A — a module-level list of `(id, argv)` tuples** (384 entries), opened at
`tools/godot-dev/verify.py:69-70` and closed at `:473`:

```python
69: commands = [
70:     ("gate-runner-tests", [sys.executable, "tools/godot-dev/test_gate_runner.py"]),
...
472:     ("local-render-motion", [binary, "--headless", "--path", "godot", "--script", "res://tests/world_motion/unit.gd"]),
473: ]
```

Driven by the loop at `:547-566`:

```python
547: for name, command in commands:
548:     report['active_gate'] = name
...
557:         result, output = run_gate(name, command, f'port/reports/{name}.log', **gate_options.get(name, {}))
```

Per-gate overrides live in two *adjacent* tables, not in the registration itself:

```python
527: gate_options = {
528:     'campaign-input-flow': {'timeout': 60},
...
536:     'combat-actions': {
537:         'success_marker': 'NATIVE_COMBAT_ACTIONS',
538:         'allowed_error_patterns': (r'^ERROR: Texture with GL ID of \d+: leaked \d+ bytes\.$',),
539:     },
540: }
541: gate_prerequisites = {
542:     'first-person-slide': ['godot/first_person/generated/weapon-0.glb'],
543: }
```

`gate_options` is the *only* place a gate may be exempted from the strict
`SCRIPT ERROR:`/`ERROR:` scan in `gate_runner.run_gate`
(`gate_runner.py:48-53`) — and it does so only together with a `success_marker`.
One gate (`combat-actions`) is the sole consumer of `allowed_error_patterns`.

**Mechanism B — two direct `run_gate(...)` calls** that never enter `commands`:

```python
516: version, output = run_gate('toolchain-version', [binary, '--version'], 'port/reports/toolchain-version.log', timeout=10)
...
569: release, output = run_gate('release-refused', ['node', 'tools/godot-export/semantic.mjs', '--release'], 'port/reports/release-refused.log')
```

`release-refused` is not a normal gate: it is an **inverted** assertion. The gate
passes only if the command *fails* in a specific way (`:570`):

```python
570: release['passed'] = release['exit_code'] not in (None, 0) and release['failure_reason'] == 'nonzero-exit' and 'Release disabled' in output
```

**No decorators exist.** There is no gate registry class, no `@gate` marker and no
plugin discovery anywhere in `tools/godot-dev/`. The list literal *is* the registry.

### 1.2 Total count and reconciliation with "384"

| Quantity | Value | Source |
|---|---|---|
| `commands` table entries (mechanism A) | **384** | `verify.py:69-473` (AST count) |
| `run_gate()` registrations outside the table (mechanism B) | **2** | `verify.py:516`, `verify.py:569` |
| **Total gate ids a full run executes** | **386** | derived |
| `report['planned_gate_names']` length | **386** | `verify.py:474` + `:491` |
| `report['execution']['planned']` | **386** | `verify.py:491` |
| Unique ids in `commands` | **384** (0 duplicates) | AST count; also asserted by `tools/godot-dev/test_playable_gates.py:32` |
| Distinct `argv` tuples in `commands` | **384** (0 duplicates) | AST count |

```python
474: report['planned_gate_names'] = ['toolchain-version', *(name for name, _ in commands), 'release-refused']
```

**Discrepancy.** The figure *"384 registered gates"* (used at
`docs/audit-2026-10-06/GATE_STATUS.md:102`) is exactly `len(commands)` and omits the
two gates the same file registers and executes. The aggregate's own self-description
is **386**. Anyone quoting "384" is quoting the table length, not the gate count. The
same file's own historical report disagrees with both
(`port/reports/verification.json` → `"planned": 318`).

Dead / disabled / always-skip gates: **none found.** Every one of the 386 ids is
executed on a full run unless a preflight aborts first (`verify.py:31-34`, `:45`,
`:513`, `:515`, `:521`). `COCS_VERIFY_KEEP_GOING` (`:544`) changes only whether the
loop aborts on the first failure (`:566`), never whether a gate runs. Duplicate
registrations inside the aggregate: **none** (0 duplicate ids, 0 duplicate argv).
The only near-duplicates are 4 gates that run the *same* Godot fixture with different
argv — `game-hud`, `game-hud-setup`, `game-hud-debug` (`verify.py:342-344`, all
`game_hud_session.gd`) and the 4 `competitive-native-*` gates
(`verify.py:383-386`, all `native-proof.mjs --mode=…`). These are distinct
assertions over one fixture, not duplicate registrations.

### 1.3 Registration-adjacent tables that are *not* the registry

`tools/godot-dev/test_playable_gates.py:33-141` holds a second, hand-maintained
table of **107** `(gate id → expected argv substring)` expectations. It asserts
*presence* of those ids and a handful of orderings (`:149-153`), and
`self.assertEqual(len(names), len(set(names)))` at `:32` is the only uniqueness
guarantee. It is a *floor* check: 384 − 107 = **277 registered gates have no
expected-substring binding** in that test. The test is itself gate
`playable-gate-registration` (`:72`).

---

## 2. Tier definitions and classification

The tiers are defined by **what the gate's process tree needs to exist**, determined
from the registered `argv` and, where `argv` is `node`/`python`, from the scripts it
launches. Each definition is mechanical enough to be re-derived.

### Definitions

- **Tier A — deterministic, engine-free gates.** The `argv` interpreter is `node` or
  `python3` and no script on the launch path starts Godot. Needs Node 22 + Python 3
  only. No display, no GPU, no audio device.
- **Tier B — Godot headless engine/runtime gates.** Godot is started with
  `--headless` (directly in `argv`, or by a launched script). Godot's headless
  display server and dummy audio driver satisfy it; no X server, no GL context.
- **Tier C — presentation / rendered / pointer-capture gates.** A real X display and
  a GL context are required: the gate is wrapped in `tools/godot-dev/xvfb_run.py`
  (or the bare `xvfb-run` helper), or a launched script spawns its own `Xvfb`, and
  Godot is started windowed with `--rendering-method gl_compatibility` (llvmpipe).
- **Tier D — frozen-inventory / source-oracle provenance pins.** Non-engine gates
  whose pass condition is agreement with a recorded inventory rather than new
  behaviour: a generator/checker invoked with `--check` (byte-equality against
  regenerated output), or a `*oracle*.mjs` script that steps the real `game/*.mjs`
  source and asserts recorded vectors. **D is a strict subset of the engine-free
  class (A-exclusive 98 + D 22 = 120)** and is counted separately so that
  A_exclusive + B + C + D = 386.
- **Tier E — environment-dependent / conditional.** *Not a partition.* An overlay:
  gates that cannot produce a result without an external condition (§5). Listed with
  its own count; gates appear in both their A–D tier and in E.

### Renderer census (all 386)

| Engine/display actually used | Gates |
|---|---|
| Godot `--headless` directly in `argv` (including `toolchain-version`) | 216 |
| Godot `--headless` launched transitively by a node/python script | 22 |
| Godot windowed directly in `argv` (six `xvfb_run.py`-wrapped Godot commands) | 6 |
| Godot windowed launched transitively (own `Xvfb` / `xvfb-run`) | 22 |
| **No engine at all** | **120** |

The only audio driver ever requested anywhere in the registry is `Dummy`
(9 gates); the only rendering method ever requested in `argv` is
`gl_compatibility` (5 gates; at least 4 further gates request it inside their
scripts). **No registered gate requests a real audio device** (§6, S5).

### Per-tier counts

| Tier | Definition (short) | Gates | % of 386 |
|---|---|---:|---:|
| **A** | deterministic, engine-free, behaviour tests | **98** | 25.4 % |
| **B** | Godot headless engine/runtime | **238** | 61.7 % |
| **C** | presentation / rendered / pointer capture | **28** | 7.3 % |
| **D** | frozen-inventory / source-oracle provenance pins (⊂ A) | **22** | 5.7 % |
| **E** | environment-dependent overlay (not a partition; 3 global rows + 9 gate rows, §5) | **12 rows** | — |

`98 + 238 + 28 + 22 = 386`. ✅

### Tier assignments

Full ID lists follow; Tier C and D carry the display / pin mechanism per gate.

### Tier A — deterministic, engine-free gates (98)

`gate-runner-tests`, `finish-runner-tests`, `playable-gate-registration`,
`verifier-report-tests`, `ci-artifact-tests`, `native-ci-contracts`, `export-tests`,
`moth-export`, `gltf-sides`, `health-hud-evidence`, `projectile-navigation`,
`objective-evidence`, `objective-progression-evidence`, `objective-completion-evidence`,
`launcher-options`, `package-options`, `product-shell-supervisor`, `native-graphics-options`,
`native-graphics-ownership`, `lobby-options`, `lobby-ownership`, `horde-closure`,
`native-arena-closure`, `package-identity-routes`, `native-arena-authority`, `local-24-roster`,
`horde-ownership`, `zone-routing`, `combined-arms-evidence`, `lattice-req-generator-tests`,
`semantic-export`, `source-inventory`, `package-manifest-contracts`, `finish-source-palette`,
`career-source-contracts`, `career-persistence`, `career-history-storage`,
`career-results-source`, `career-equipment-source`, `career-equipped-source`, `social-source`,
`source-tests`, `cadence-source`, `arms-race-source`, `horde-source`, `cinderwake-source`,
`horde-upgrade-adapter`, `horde-adapter`, `horde-death-wire`,
`career-player-flow-clarity-source`, `loadout-lifecycle`, `weapon-blender-source-audit`,
`finish-source-journey`, `weapon-export`, `world-weapon-identity`, `benchmark-tools`,
`material-derived`, `identity-zone-route`, `debug-tools`, `blood-live-harness`, `route-parity`,
`multiplayer-world-options`, `multiplayer-expansion-package-contract`,
`multiplayer-world-source-routes`, `multiplayer-world-mode-matrix`,
`multiplayer-urban-navigation`, `multiplayer-world-network`, `horde-robot-expansion`,
`campaign-options`, `solo-cheats-authority`, `campaign-feel-authority`,
`campaign-targeting-authority`, `animation-actor-fire`, `edge-source-hits`, `edge-map-fixtures`,
`campaign-interludes-authority`, `campaign-interludes-fixtures`, `campaign-ownership`,
`campaign-closure`, `campaign-authority`, `campaign-world-routes`, `campaign-story-authority`,
`material-coverage-floor`, `release-pipeline-tools`, `combat-integration-oracle`,
`native-arena-maps`, `identity-prototype-graybox`, `objective-expansion-routes`,
`objective-source-completion`, `competitive-source-modes`, `finish-challenge-source`,
`finish-audio-source`, `finish-replay-source`, `finish-replay-bridge-source`,
`finish-package-closure`, `lattice-flagship-l3-static`, `lattice-flagship-l5-static`,
`release-refused`

### Tier B — Godot headless engine/runtime gates (238)

`godot-import`, `career-projection`, `career-package-catalog`, `career-identity-native`,
`career-equipment-native`, `career-equipped-model`, `career-equipped-ui`,
`career-player-flow-clarity-model`, `career-player-flow-clarity-ui`, `career-equipped-lobby`,
`career-results-native`, `career-history-native`, `career-results-history-ui`, `social-native`,
`protocol-decode-once`, `reconnect-source-native`, `reconnect-offline-results`,
`reconnect-menu`, `career-modal`, `cinderwake-native`, `identity-horde-composition`,
`loadout-unit`, `loadout-source-parity`, `loadout-client`, `loadout-setup`, `loadout-lobby`,
`loadout-session`, `viewer-smoke`, `graphics-terrain`, `moth-resources`, `graphics-atmosphere`,
`graphics-fx`, `moth-scenery`, `shader-lab`, `particle-lab`, `showcase-startup`,
`aurora-traversal`, `cinder-traversal`, `exploration-walker`, `first-person-rig`,
`first-person-slide`, `weapon-blender-art`, `first-person-finishes`,
`finish-native-source-replay`, `first-person-ads`, `first-person-recoil`, `combat-shields`,
`combat-shield-capacity`, `combat-particles`, `combat-pickup-assets`, `weapon-effects`,
`weapon-effects-rig`, `muzzle-sight-geometry`, `muzzle-path-geometry`, `projectile-flight`,
`alt-fire`, `weapon-handling`, `weapon-detail`, `player-fx-direction`, `player-fx-low-health`,
`player-fx-lifecycle`, `player-fx-marks`, `player-fx-impacts`, `player-fx-overlay`,
`player-fx-integration`, `benchmark-contracts`, `material-language`, `debug-panel`,
`mode-diagnostics`, `campaign-feel-motion`, `campaign-input-flow`, `animation-physics`,
`animation-world-physics`, `campaign-targeting-geometry`, `animation-actors`,
`animation-actor-geometry`, `edge-map-geometry`, `edge-contact-contracts`,
`edge-weapon-effects`, `campaign-interludes-native`, `campaign-interludes-live`,
`campaign-robots`, `campaign-death-presentation`, `campaign-telegraphs`, `campaign-model`,
`campaign-environment`, `campaign-robot-voices`, `campaign-client`, `campaign-session`,
`campaign-story-presentation`, `campaign-story-gestures`, `campaign-structure-art`,
`campaign-landmark-art`, `campaign-environment-art`, `campaign-smoke-route`, `campaign-terrain`,
`campaign-rootfall`, `campaign-siltwake`, `campaign-emberline`, `campaign-crown`,
`main-menu-smoke`, `main-menu-contracts`, `main-menu-attract-lifetime`,
`product-shell-settings`, `blood-fx-contracts`, `blood-fx-surfaces`, `blood-fx-stress`,
`combat-integration`, `combat-combined-integration`, `combat-remote-muzzle`,
`identity-horde-occlusion`, `native-arena-session`, `native-arena-composition`,
`identity-prototype-rays`, `identity-prototype-lifecycle`, `native-arena-prism`,
`native-arena-aurora`, `native-arena-cinder`, `glb-import`, `glb-sides`, `input-queue`,
`protocol-envelopes`, `packet-replay`, `native-live`, `presentation-replay`, `round-boundaries`,
`native-lifecycle`, `combat-feedback`, `projectiles`, `audio-feedback`, `melee-feedback`,
`damage-numbers`, `local-lifecycle`, `pickup-presentation`, `entity-visuals`,
`operator-geometry`, `world-weapon-import`, `world-weapon-grips`, `operator-detail-textures`,
`native-trace`, `guest-session`, `lobby-flow`, `lobby-spectator-context`, `match-selection`,
`scoreboard`, `team-scores`, `scoreboard-session`, `game-hud`, `game-hud-setup`,
`game-hud-debug`, `puma-presentation`, `zone-modes`, `uplink-live-timeout`,
`holdout-live-timeout`, `assault-live-timeout`, `uplink-controlled-completion`,
`holdout-controlled-completion`, `assault-controlled-completion`, `objective-zone-variants`,
`objective-assault-state`, `objective-scoreboard`, `vehicle-fleet-visuals`,
`vehicle-shared-shot-owner`, `world-weather-native-look`, `world-weather-standalone`,
`experience-native-information`, `experience-combined-hud`, `player-gameplay-native`,
`competitive-native-contracts`, `finish-gameplay-contract`, `finish-challenge-contract`,
`finish-spectator-contract`, `finish-spectator-camera`, `finish-horde-guidance`,
`finish-audio-contract`, `finish-lattice-contract`, `finish-controls-contract`,
`finish-caption-integration`, `finish-home-replays`, `finish-replay-bridge-negative`,
`audiovisual-event-router`, `audiovisual-outcome`, `audiovisual-settings`,
`audiovisual-lifecycle`, `audiovisual-weather-ownership`, `audiovisual-weather-oracle`,
`audiovisual-score-form`, `audiovisual-soak`, `audiovisual-standalone-lifecycle`,
`audiovisual-independent-event-binding`, `audiovisual-horde-recipe-binding`,
`audiovisual-menu-rapid-lifetime`, `combined-arms-controls`, `combined-arms-graphics`,
`arms-race`, `horde-model`, `horde-death-presentation`, `horde-upgrade-native`,
`horde-controls`, `sports-controls`, `sports-polish`, `sports-progression`, `soccer-guidance`,
`soccer-coaching`, `sports-bearing`, `lattice-adapter`, `lattice-ui`, `lattice-map`,
`lattice-topology`, `lattice-economy`, `lattice-world`, `lattice-world-commands`,
`lattice-req-catalog`, `lattice-req-purchase`, `lattice-world-tactical`, `lattice-flagship-l1`,
`lattice-flagship-l2`, `lattice-flagship-l3-roles`, `lattice-flagship-l3-evidence`,
`lattice-flagship-assets`, `lattice-world-usability`, `objective-renderer`,
`objective-controls`, `objective-progression`, `objective-input-timing`, `payload-guidance`,
`payload-guidance-hud`, `control-safety`, `window-focus`, `session-recovery`, `stall-controls`,
`snapshot-watch`, `native-session`, `two-native-clients`, `motion-impairment`, `remote-motion`,
`local-render-motion`, `toolchain-version`

### Tier C — presentation / rendered / pointer-capture gates (28)

| gate id | verify.py line | display mechanism | engine invocation |
|---|---|---|---|
| `career-player-flow-clarity-journey` | 133 | own `Xvfb` at `clarity-journey.mjs:98` | `node port/native-player-flow/clarity-journey.mjs` |
| `career-equipped-journey` | 135 | own `Xvfb` at `equipped-journey.mjs:108` | `node port/native-career/equipped-journey.mjs` |
| `loadout-loopback` | 153 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py node godot/tests/loadouts/loopback.mjs` |
| `first-person-binding` | 178 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py GODOT --path godot --rendering-method gl_c...` |
| `combat-actions` | 181 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py GODOT --path godot --rendering-method gl_c...` |
| `benchmark-autostart` | 211 | `tools/godot-dev/xvfb_run.py` via `run_benchmark.mjs:92` | `node port/native-benchmark/run_benchmark.mjs --gate=all --resolution=640x400 ...` |
| `blood-live-native` | 221 | own `Xvfb` at `port/native-blood-fx/live.mjs:70` | `node port/native-blood-fx/live.mjs --ci-render-budget` |
| `edge-render-masks` | 250 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py GODOT --path godot --rendering-method gl_c...` |
| `campaign-compact-ui` | 274 | bare `xvfb-run` shell helper | `xvfb-run -a -s -screen 0 1280x800x24 node port/campaign/live-capture.mjs --ma...` |
| `main-menu-live-attract` | 283 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py GODOT --path godot --rendering-method gl_c...` |
| `product-shell-journey` | 285 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py node tools/godot-dev/product_journey.mjs -...` |
| `player-flow-journey` | 286 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py node tools/godot-dev/product_journey.mjs -...` |
| `player-flow-controls` | 287 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py GODOT --path godot --rendering-method gl_c...` |
| `product-shell-guest-leave` | 288 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py node tools/godot-dev/guest_leave_journey.mjs` |
| `vehicle-three-native-crew` | 362 | own Xvfb inside `port/native-vehicle-expansion/run.py` | `PYTHON port/native-vehicle-expansion/run.py` |
| `world-weather-source-journey` | 368 | `xvfb-run` at `scripts/world-weather-journey.mjs:48` | `node scripts/world-weather-journey.mjs source tidal-citadel {str(Path(os.envi...` |
| `world-weather-campaign-journey` | 369 | `xvfb-run` at `scripts/world-weather-journey.mjs:48` | `node scripts/world-weather-journey.mjs campaign siltwake-crossing {str(Path(o...` |
| `experience-mode-journey` | 373 | `xvfb-run` at `tools/experience/native-journey.mjs:71` | `node tools/experience/native-journey.mjs --mode=vip-escort --compact --output...` |
| `experience-campaign-journey` | 374 | `xvfb-run` at `tools/experience/native-journey.mjs:71` | `node tools/experience/native-journey.mjs --scenario=campaign --compact --outp...` |
| `experience-sports-journey` | 375 | `xvfb-run` at `tools/experience/native-journey.mjs:71` | `node tools/experience/native-journey.mjs --scenario=sports --compact --output...` |
| `experience-combined-arms-journey` | 376 | `xvfb-run` at `tools/experience/native-journey.mjs:71` | `node tools/experience/native-journey.mjs --scenario=combined_arms --compact -...` |
| `player-gameplay-live-input` | 380 | `xvfb-run` at `port/next-port/gameplay/live.mjs:29` | `node port/next-port/gameplay/live.mjs` |
| `competitive-native-arsenal` | 383 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py node port/next-port/modes/native-proof.mjs...` |
| `competitive-native-juggernaut` | 384 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py node port/next-port/modes/native-proof.mjs...` |
| `competitive-native-elimination` | 385 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py node port/next-port/modes/native-proof.mjs...` |
| `competitive-native-vip` | 386 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py node port/next-port/modes/native-proof.mjs...` |
| `finish-world-contract` | 392 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py GODOT --audio-driver Dummy --path godot --...` |
| `horde-upgrade-fixture` | 431 | `tools/godot-dev/xvfb_run.py` | `PYTHON tools/godot-dev/xvfb_run.py node godot/tests/horde/upgrade_loopback.mjs` |

### Tier D — frozen-inventory / source-oracle provenance pins (22)

| gate id | verify.py line | pin mechanism and command |
|---|---|---|
| `lattice-req-catalog-check` | 100 | regenerate-and-compare (`--check`) — `node port/tools/native_lattice_req_catalog/export.mjs --check` |
| `career-catalog-check` | 104 | regenerate-and-compare (`--check`) — `node tools/godot-export/career_catalog.mjs --check` |
| `finish-catalog-check` | 105 | regenerate-and-compare (`--check`) — `node tools/godot-weapons/finishes.mjs --check` |
| `horde-input-oracle` | 122 | source-oracle: steps real `game/*.mjs`, asserts recorded vectors — `node port/native-horde/input-oracle.mjs {str(root / 'port/reports/horde-input-vectors.json')}` |
| `multiplayer-world-derivatives` | 225 | regenerate-and-compare (`--check`) — `node port/multiplayer-worlds/generate-derivative.mjs --check` |
| `multiplayer-world-scenes` | 226 | regenerate-and-compare (`--check`) — `node tools/godot-multiplayer/generate-scenes.mjs --check` |
| `edge-structure-bake` | 244 | regenerate-and-compare (`--check`) — `node port/edge-effects/bake-structures.mjs --check` |
| `identity-prototype-oracle` | 307 | source-oracle: steps real `game/*.mjs`, asserts recorded vectors — `node port/native-identity-maps/ray-oracle.mjs` |
| `vehicle-source-oracle` | 358 | source-oracle: steps real `game/*.mjs`, asserts recorded vectors — `node port/native-vehicle-expansion/source-oracle.mjs` |
| `vehicle-room-edge-oracle` | 359 | source-oracle: steps real `game/*.mjs`, asserts recorded vectors — `node port/native-vehicle-expansion/room-edge-oracle.mjs` |
| `audiovisual-assets` | 363 | regenerate-and-compare (`--check`) — `node tools/godot-audiovisual/music_pack.mjs --check` |
| `weather-source-vectors` | 364 | regenerate-and-compare (`--check`) — `node port/native-audiovisual/weather-oracle.mjs --check` |
| `world-weather-source-look` | 365 | regenerate-and-compare (`--check`) — `node scripts/world-weather-oracle.mjs --check` |
| `experience-source-captions` | 370 | regenerate-and-compare (`--check`) — `node tools/experience/extract.mjs --check` |
| `player-gameplay-catalog` | 377 | regenerate-and-compare (`--check`) — `node port/next-port/gameplay/catalog.mjs --check` |
| `player-gameplay-source-fixtures` | 378 | regenerate-and-compare (`--check`) — `node port/next-port/gameplay/fixtures.mjs --check` |
| `finish-gameplay-source` | 389 | regenerate-and-compare (`--check`) — `node tools/port/pass-two-gameplay/source.mjs --check` |
| `finish-world-source` | 391 | regenerate-and-compare (`--check`) — `node scripts/world-weather-spatial-oracle.mjs --check` |
| `finish-spectator-source` | 395 | regenerate-and-compare (`--check`) — `node tools/experience/spectator-oracle.mjs --check` |
| `finish-lattice-source` | 401 | source-oracle: steps real `game/*.mjs`, asserts recorded vectors — `node tools/port/lattice/source-oracle.mjs` |
| `finish-controls-source` | 403 | source-oracle: steps real `game/*.mjs`, asserts recorded vectors — `node tools/port/input-bindings/source-oracle.mjs` |
| `finish-caption-source` | 406 | source-oracle: steps real `game/*.mjs`, asserts recorded vectors — `node tools/port/finish/caption-oracle.mjs` |

---

## 3. Exact-candidate binding

### 3.1 What a run does record

The report is constructed once at import time (`verify.py:16-30`):

```python
16: report_path = Path('port/reports/verification.json')
17: lock = json.loads(Path('port/contracts/source-lock.json').read_text())
18: report = {
19:     'status': 'running', 'gates': [],
20:     'source_commit': lock['source_commit'],
21:     'port_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
22:     'port_worktree_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
23:     'source_derivative': {'selection': 'none'},
```

and the source-side identity is added after the derivative resolves
(`verify.py:501-511`):

```python
505:         report['source_derivative'] = {
506:             'selection': 'active' if active_source else 'explicit', 'path': derivative_path,
507:             'sha256': hashlib.sha256(derivative_bytes).hexdigest(),
508:             'source_commit': derivative['source_commit'],
509:             'derivative_commit': derivative['derivative_commit'],
510:         }
```

Each gate row records its verbatim argv (`gate_runner.py:56-58`):

```python
56:     return {'gate': name, 'command': command, 'exit_code': code,
57:             'passed': reason is None, 'failure_reason': reason,
58:             'duration_seconds': round(time.monotonic() - start, 3)}, output
```

**So: the commit SHA is bound.** `port_commit` is a real 40-hex `git rev-parse
HEAD`, and `source_derivative.sha256` is a real digest of the derivative bytes
cross-checked against `active-source.json:7` at `verify.py:43-45`.

### 3.2 Verdict: **PARTIALLY BOUND — a gap, not an absence**

For a clean checkout, `port_commit` + `source_commit` + `source_derivative.sha256`
is a sufficient candidate record. It is *not* sufficient for a dirty tree, and the
repository's own committed report is a dirty tree.

Exact gaps, with evidence:

**G1 — Dirty-tree bytes are never identified.** `port_worktree_dirty` is a boolean
(`verify.py:22`). Nothing records *which* uncommitted bytes produced the result. The
committed `port/reports/verification.json` is exactly this case:

```
"port_commit": "e530c1c9ff67cede3516df60cc1d67d960383eee",
"port_worktree_dirty": true,
```

A reader cannot tell whether the 318 recorded gate results came from `e530c1c9` plus
one line of local edit or plus a thousand. `grep -nE "diff|sha256|rev-parse|porcelain"`
over `verify.py`, `gate_runner.py` and `ci_bootstrap.py` returns only five hits, all
already quoted: `verify.py:21`, `:22`, `:43`, `:44`, `:507`. There is no diff hash,
no tree hash, and no untracked-file fingerprint anywhere in the verifier.

**G2 — The dirty flag is a pre-run snapshot of a tree the gates then mutate.**
`port_worktree_dirty` is computed at line 22, before `godot-import`
(`verify.py:123`) writes `godot/.godot/`, before `semantic-export`
(`verify.py:101`) writes `godot/content/generated/` (both gitignored by
`godot/.gitignore`), and before `.port-runtime/` is created (`verify.py:49`,
gitignored by `.gitignore:53`). The post-run tree state is never recorded, so
`port_worktree_dirty: false` asserts only that the tree was clean *at import time*.
It is also a whole-tree boolean, so it cannot distinguish "one untracked scratch file"
from "modified production source" — the two cases with very different evidentiary
value.

**G3 — Gate logs carry no candidate identity and are overwritten every run.**
`gate_runner.py:54-55` writes raw child output only:

```python
54:     Path(log_path).parent.mkdir(parents=True, exist_ok=True)
55:     Path(log_path).write_text(output)
```

There is no header, no SHA, no timestamp, no gate id in the file. `port/reports/<gate>.log`
is a single-slot path reused by every run, so an individual log cannot be attributed
to a candidate. `ci_bootstrap.py:14-21` compensates with an mtime filter for the CI
artifact only:

```python
13: # Checkout already contains historical reports. Never upload them as new results.
14: if started.exists():
15:     reports = root / "port/reports"
...
20:     sources += [("gates", path) for path in sorted(reports.glob("*.log"))
21:                 if path.stat().st_mtime_ns >= since]
```

**G4 — Five unguarded fallback sites (six gate ids) can resolve an engine other
than the pinned one, but not inside a `verify.py` run.**
`toolchain-version` (`:516-518`) pins `binary = $GODOT_BIN` and refuses on mismatch
(`:517-518`), but these scripts resolve Godot themselves and fall back to a
hard-coded machine path when `GODOT_BIN` is unset:

| Fallback site | Affected gate(s) |
|---|---|
| `port/native-reconnect/journey.mjs:8` | `reconnect-source-native` |
| `port/native-reconnect/offline-results.mjs:8` | `reconnect-offline-results` |
| `scripts/world-weather-journey.mjs:45` | `world-weather-source-journey`, `world-weather-campaign-journey` |
| `port/native-vehicle-expansion/run.py:21` | `vehicle-three-native-crew` |
| `tools/release/options.mjs:11-12`, applied at `:190` (`options.godotBin ??= process.env.GODOT_BIN \|\| DEFAULT_PINNED_GODOT`) | `release-pipeline-tools` — the fallback is a default constant; `tools/release/release.test.mjs` injects a stub runner, so this gate currently exercises the constant, not the fallback |

These sites are `process.env.GODOT_BIN ?? '<hard-coded path>'` (or an `os.environ`
equivalent), so the fallback engages whenever the script is invoked directly with
`GODOT_BIN` unset. **Inside a `verify.py` aggregate it cannot engage:**
`verify.py:37` only *reads* `GODOT_BIN`, `:514-515` fails preflight before any gate
runs when it is absent, and `gate_runner.run_gate` spawns children with the
inherited environment, so every child sees the same pinned value.

The committed report proves the class is live: `gates[0].command` is
`["/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64", "--version"]`.
`tools/godot-package/verify.py:266` already *forbids* `/home/mojo/.hermes-instances/fresh/workspace/`
from appearing in packaged files, so the leak class is known — but the ban covers
packaged files, not `tools/` and `port/` scripts.

**G5 — The engine version string is not in the report at all.** `run_gate` returns
no stdout (`gate_runner.py:56-58`), so the version compared at `:517` survives only
in `port/reports/toolchain-version.log`. `verification.json` records the *path*, not
the version.

**G6 — No host/GL-stack field.** No OS, arch, kernel, driver or llvmpipe version is
recorded, so a Tier C result cannot be tied to the software rasteriser that produced
it (`verify.py:207-210` explicitly reasons about llvmpipe frame cost).

### 3.3 Minimal change (described only — not implemented here)

`verify.py` is owned by the orchestrator; the following is a description.

1. **Add two fields at report construction** (`verify.py:22`), computed with the same
   `subprocess.check_output` style already used on line 21:
   - `port_tree`: output of `git rev-parse HEAD^{tree}` — the exact tree object the
     index points at;
   - `port_worktree_diff_sha256`: `sha256` of `git diff HEAD --binary` output
     (`""` when clean), plus optionally `port_untracked`: `git ls-files --others
     --exclude-standard -z` entries each hashed.
   Keep `port_worktree_dirty`; it is a useful fast signal, it is just not
   sufficient. A single derived `port_candidate_id =
   f"{port_tree[:12]}{'-dirty' if dirty else ''}:{diff_sha[:16]}"` makes the id
   quotable in prose and in CI job summaries.
2. **Write an identity header into every gate log.** One signature change in
   `gate_runner.run_gate` (add `candidate_id=''`) and one change at
   `gate_runner.py:55` (`write_text(header + output)`), with `verify.py:557`
   passing the id from the report. This closes G3 for all 386 gates and makes
   `port/reports/*.log` self-attributing, which also lets `ci_bootstrap.py` drop its
   mtime heuristic.
3. **Record the resolved engine identity and make it non-optional.** Add
   `godot_version` (the probe stdout already available at `verify.py:516`) and
   `godot_binary_sha256` (`sha256` of the binary) to the initial `report` dict, and
   add one line next to `verify.py:37` that *always* exports the resolved binary
   into `os.environ['GODOT_BIN']` (today it is only read at `:37`). That single
   line closes G4 for all four affected registrations without editing the four
   tools, and it also makes `verify.py:515`'s `if not binary: fail_preflight`
   consistent with what the child processes actually see.
4. **Assert the invariant in the existing fixture test.**
   `tools/godot-dev/test_verifier_report.py:69` already asserts
   `assertFalse(report["port_worktree_dirty"])`; adding
   `self.assertEqual(report["port_candidate_id"], report["port_tree"])` there, and a
   mutated-tree case that asserts the diff hash is non-empty, closes the loop without
   a new test file.

**Precedent to copy, already in-tree.** The package path binds exact candidate bytes
and the gate aggregate does not:

- `tools/godot-package/manifest_validation.mjs:477`, `:620-627` resolve every
  package input as a *committed git blob* at `manifest.port_commit`
  (`gitObjectBytes(repo, identity.port_commit, path)`) and compare
  `gitObjectHash(...)` against the runtime file;
- `:599` reads `source-lock.json` **out of the commit** (`git show
  ${port_commit}:...`) instead of from the working tree, which is what `verify.py:17`
  does;
- `.github/workflows/windows-preview.yml:36,50` refuses unless a 40-hex `CANDIDATE`
  is given *and* `manifest.port_commit` equals it.

---

## 4. What CI and the dev workflow actually execute

| Workflow | Line | Command | Registered gates executed |
|---|---|---|---|
| `.github/workflows/godot-native.yml` | `:63` | `python3 tools/godot-dev/verify.py` | **all 386** → Tiers A, B, C, D |
| `.github/workflows/godot-native.yml` | `:60-61` | `GUEST_NODE_MODULES=… python3 port/native-vehicle-expansion/run.py` (`workflow_dispatch` scope `vehicle-diagnostic`) | 1 gate (Tier C: `vehicle-three-native-crew`); verify.py is skipped |
| `.github/workflows/ci.yml` | `:17-28` | `npm run typecheck` / `test:game` / `test:server` / `build` / `node --test tests/*.test.mjs` / `npm run lint` | **none** — no `godot-dev` gate appears in any of these scripts (`package.json`) |
| `.github/workflows/linux-demo.yml` | `:39` | `node tools/godot-package/verify_linux.mjs` | none (not a registered gate) |
| `.github/workflows/windows-source-preflight.yml` | `:22,24` | `node --test tools/godot-package/dependency_path.test.mjs source_state_windows.test.mjs build_channel.test.mjs` | none (not registered gates) |
| `.github/workflows/windows-helix-nav-source.yml` | `:29` | `node --test port/multiplayer-worlds/wall_candidates.test.mjs` | none (not registered) |
| `.github/workflows/windows-preview.yml` | `:64,71` | packaged `verify_preview_windows.mjs` / `verify_expansion.mjs` | none (not registered) |
| `.github/workflows/windows-demo.yml` | — | package/demo steps | none |

**Summary.** Exactly one workflow (`godot-native.yml`) executes the registry, and it
executes **all four tiers**, including Tier C on a software-GL runner — which is what
`verify.py:207-210` documents as the reason for the 640x400/low benchmark preset.
Trigger scope is `push` to `[main, port/lattice-flagship-next]`, `pull_request`, and
`workflow_dispatch` (`godot-native.yml:4-7`), so pull requests do run it.

**Only-exists-as-a-registration:**

- **`port/finish/matrix.json`** — 96 registered jobs, including an 8-job `manual`
  cohort and a 4-job `external` cohort. `verify.py:387-388` describes them as
  "opt-in serial jobs … with gate-specific deadlines". **No workflow runs this
  file.** Its in-repo consumers are `tools/godot-dev/finish_runner.py` (the actual
  runner, `:21`, `:366`), `tools/release/cinematic-v3/identity.py:17`
  (which loads `port/finish/final_matrix.json`, not `matrix.json`) and
  `tools/godot-dev/test_finish_runner.py` (unit tests of the loader).
- **The three `manual_acceptance` scopes** at `verify.py:24-28` —
  *"Rendered visual fidelity and actual player input"*, *"Natural full-round and
  multiplayer source outcomes"*, *"Human playable acceptance"*, all recorded as
  `owner-run / unrun`. They are report fields, not gates; nothing can ever execute
  them.
- **Real-driver audio acceptance** — `matrix.json`'s 2-job `audio` cohort
  (`real-driver-PCM`) is likewise unexecuted by CI.
- **`port/finish/final_matrix.json`** — a second matrix file consumed by
  `tools/release/cinematic-v3/identity.py:17` and by
  `tools/godot-dev/test_finish_runner.py:189`; also not run by any workflow.

---

## 5. Tier E — environment-dependent overlay (12 rows)

These gates are counted in A–D above and are listed again here because their result
depends on a condition outside the repository. Rows 1-3 are global (they constrain
every tier); rows 4-12 name specific gates.

| # | Gate(s) | Condition | Evidence |
|---|---|---|---|
| 1 | all 386 | `GODOT_BIN` must be set **and** be `4.5.2.stable.official.6ce3de25a`, else the whole aggregate is `failed` with all 386 `unrun` | `verify.py:37`, `:514-515`, `:516-521` |
| 2 | all 386 | a derivative must resolve and its bytes must match `active-source.json:7` | `verify.py:40-46`, `:501-513` |
| 3 | the 28 Tier C gates | Xvfb + `libX11.so.6` + a software GL stack. `xvfb_run.py:76-77` returns `False` when `libX11.so.6` cannot be loaded, and `xvfb_run.py:112-113` then exits 1 → the 15 wrapped gates all fail with *"No private display could be started"* | `tools/godot-dev/xvfb_run.py:69-90`, `:97-113` |
| 4 | `campaign-compact-ui` | evidence directory comes from `COCS_CAMPAIGN_CAPTURE_OUT`, defaulting to `/tmp/opencode/campaign-ui-verification` | `verify.py:274` |
| 5 | `benchmark-autostart` | writes to the hard-coded shared scratch root `/tmp/opencode/benchmark-autostart-gate` | `verify.py:211`; `verify.py:15` creates `/tmp/opencode` |
| 6 | `material-coverage-floor`, `campaign-compact-ui` | share `/tmp/opencode` with item 5 — concurrent verifier runs on one host collide | `verify.py:15`, `:274`, `:290` |
| 7 | `first-person-slide` | `missing-prerequisite` branch: fails without launching anything if `godot/first_person/generated/weapon-0.glb` is absent | `verify.py:541-543`, `:550-555` |
| 8 | `horde-controls` | reads `port/reports/horde-input-vectors.json`, which is **tracked in git** and is written by gate `horde-input-oracle`; see S10 | `verify.py:122`, `:432` |
| 9 | `reconnect-source-native`, `reconnect-offline-results`, `world-weather-source-journey`, `world-weather-campaign-journey`, `vehicle-three-native-crew` | engine identity is not bound when these scripts are invoked directly with `GODOT_BIN` unset; inside a `verify.py` run the fallback cannot engage (G4) | see §3.2 |
| 10 | `native-arena-composition` | asserts against a deliberately unreachable endpoint `ws://127.0.0.1:1` | `verify.py:302` |
| 11 | `career-player-flow-clarity-journey`, `career-equipped-journey` | both refuse to run if their output directory already exists (`clarity-journey.mjs:32`, `equipped-journey.mjs:31-32`), so they depend on `verify.py:50-52` having created a *fresh* `COCS_CAREER_ROOT`; they write real PNGs into the repo tree when `CAREER_CLARITY_OUT`/`CAREER_EQUIPPED_OUT` are unset | `verify.py:50-52`; `port/native-player-flow/clarity-journey.mjs:31-32`; `port/native-career/equipped-journey.mjs:30-32` |
| 12 | `edge-map-fixtures` → `edge-map-geometry`, `edge-render-masks` | `EDGE_MAP_CASES` is written by `port/edge-effects/measure.mjs:30` and read by `godot/tests/edge_effects/maps.gd:9`; `EDGE_RENDER_OUT` is read by `godot/tests/edge_effects/render.gd:35`. Both are set by `verify.py:57`, so the ordering is load-bearing and no prerequisite is declared for it | `verify.py:57`, `:246-250` |

---

## 6. Surprises

Every item below is backed by a command output or a quoted line in this worktree.

**S1 — "384 gates" omits two gates every run executes.** `commands` has 384 entries;
`planned_gate_names` has 386 (`verify.py:474`); `toolchain-version` (`:516`) and
`release-refused` (`:569`) are registered outside the table. The verifier's own
self-description is 386. `GATE_STATUS.md:102` says 384. **The number quoted in the
audit record is the table length, not the gate count.**

**S2 — The verifier's own `gate_tiers` block under-reports the rendered set by 15 of
28.** `report['gate_tiers']` (`verify.py:478-490`) has three overlapping lists:
`rendered/input` (13 ids), `live-source` (14), `controlled-source-placement` (3).
None of the 15 following display-requiring gates appears in `rendered/input`, and
nothing in the report declares them as rendered:
`campaign-compact-ui`, `edge-render-masks`, `main-menu-live-attract`,
`finish-world-contract`, `player-gameplay-live-input`,
`world-weather-source-journey`, `world-weather-campaign-journey`,
`experience-mode-journey`, `experience-campaign-journey`,
`experience-sports-journey`, `experience-combined-arms-journey`,
`competitive-native-arsenal`, `competitive-native-juggernaut`,
`competitive-native-elimination`, `competitive-native-vip`.
Every id in the declared `rendered/input` list *is* genuinely display-requiring (no
false positives), but the label cannot be used to bound the rendered surface.

**S3 — Eleven gates named like product smoke tests never open a window.** All eleven
`launch.mjs` gates (`showcase-startup`, `campaign-rootfall`, `campaign-siltwake`,
`campaign-emberline`, `campaign-crown`, `native-arena-prism`, `native-arena-aurora`,
`native-arena-cinder`, `native-live`, `native-lifecycle`, `native-session`) pass a
smoke flag, and `tools/godot-dev/launch_options.mjs` adds
`--headless --audio-driver Dummy` to **every** smoke plan — lines `96`, `111`, `127`,
`145`, `253`, and `301-302` (`smoke === '--network-smoke'` → `['--headless', …]`).
So `native-live`, `native-lifecycle` and `native-session` — listed in the report under
`'live-source'` — cannot fail for any rendering or input-device reason, and
`showcase-startup` produces no visual evidence despite the name.

**S4 — Five fallback sites (six gate ids) resolve the engine outside the pinned
preflight when invoked directly; none can engage inside a `verify.py` run.**
See §3.2 G4. The committed report contains the hard-coded path verbatim
(`gates[0].command[0]`).

**S5 — There is no audio-hardware gate, so no registered gate can produce audio
acceptance.** Across all 386 registrations the only `--audio-driver` value is `Dummy`
(9 gates) and the only rendering method in `argv` is `gl_compatibility` (5 gates;
at least 4 more request it inside their scripts); everything else is `--headless`. Real-driver PCM acceptance exists only as 2 unexecuted
`matrix.json` `audio`-cohort jobs and as the `manual_acceptance` scope *"Rendered
visual fidelity and actual player input"*. Consequently the 412 audio checks cited at
`GATE_STATUS.md:26` are a headless assertion count, not an audio-hardware result.

**S6 — 68 registered gates have no committed log; 9 committed logs have no
registered gate.** Cross-checking `port/reports/*.log` basenames (327 files) against
the 386 ids: 318 registered gates have a log, 68 do not, and 9 logs are orphans
(318 + 68 + 9 = 395 = 386 + 9).

- *Registered but never produced a committed artifact in this tree (68):*
  `finish-*` 24, `experience-*` 7, `competitive-native-*` 5, `animation-*` 5,
  `world-weather-*` 5, `campaign-interludes-*` 4, and 18 individually named gates:
  `cadence-source`, `campaign-input-flow`, `campaign-targeting-authority`,
  `campaign-targeting-geometry`, `competitive-source-modes`,
  `edge-contact-contracts`, `edge-map-fixtures`, `edge-map-geometry`,
  `edge-render-masks`, `edge-source-hits`, `edge-structure-bake`,
  `edge-weapon-effects`, `first-person-slide`, `player-gameplay-catalog`,
  `player-gameplay-live-input`, `player-gameplay-native`,
  `player-gameplay-source-fixtures`, `protocol-decode-once`.
- *Orphan logs — no registered gate can ever refresh them (9):*
  `campaign-ownership-repair.log`, `horde-death-presentation-repair.log`,
  `horde-ownership-repair.log`, `horde-upgrade-native-repair.log`,
  `lobby-ownership-repair.log`, `native-graphics-ownership-repair.log`,
  `product-shell-supervisor-repair.log`, `glb-build-1.log`, `glb-build-2.log`.
  Seven are `<registered-gate>-repair.log`, i.e. prior names of gates that now exist
  without the suffix. They are stale by construction: a current run writes
  `port/reports/<gate>.log` (`verify.py:553`, `:557`) and never touches these paths.
  The sample pair is not identical — `campaign-ownership-repair.log` is 1743 bytes of
  TAP output while `campaign-ownership.log` is 7238 bytes — which is consistent with a
  repair-era run of a differently-scoped command.

**S7 — 124 MB of `port/reports` evidence is produced by no registered gate and is
explicitly excluded from CI artifacts as "historical".** 67 evidence subdirectories
under `port/reports/` (68 counting the directory itself), 930 tracked `.log` files,
`du -sh port/reports` = 124 MB. `ci_bootstrap.py:13` says so outright:
`# Checkout already contains historical reports. Never upload them as new results.`
Trees such as `port/reports/horde-event-repair/`, `port/reports/horde-repair/`,
`port/reports/horde-repair-independent/` and `port/reports/arms-race-independent/`
even ship their own executable audit scripts (`horde-provenance.py`,
`horde-checks.py`, `horde-audit.mjs`, `final-checks-console.log`). None of these is
reachable from `verify.py`'s 386 argv entries, so no run can refresh or invalidate
them — yet they sit in the same directory the verifier writes its own evidence into.

**S8 — Two parallel gate registries with different candidate pins and almost no
overlap.** `port/finish/matrix.json` registers **96** jobs and pins
`"integrated_candidate": "5a4bc82d04856d35fc06c58786bb9da4a35d6369"` — not the
current HEAD. Only **3** of its ids exist in `verify.py` (`finish-runner-tests`,
`lattice-world-commands`, `lattice-world-tactical`); **93** do not. Its own
`canonical-full-integrated` criterion (`:107`) is prose: *"Parent runs existing
359-gate baseline plus registered additions after integration"*. Nothing in
`.github/workflows` runs it (§4).

**S9 — The registry's own accounting is stale, and gate-count claims across the
repository range from 105 to 384.**

- `port/finish/ACCEPTANCE_PLAN.md:24-26` is the most explicit published accounting
  of the aggregate: *"Canonical `verify.py` gains **24 focused registrations**.
  Static inventory is 381 commands plus version/release guards = **383 planned
  gates**, against the 359-gate published baseline. This is a count, **not a
  383-pass result**."* The live inventory is **384 commands / 386 planned**
  (§1.2), so this document is 3 commands and 3 planned gates behind the code it
  describes — and, notably, it applies the same "+2 guards" arithmetic that §1.2
  shows is required, while the audit record omits it.
- Earlier claims: `port/graphics-batch/README.md:92` "105 gates";
  `port/native-weapon-oomph/README.md:3` "167-gate";
  `port/release-notes/weapon-feel-2026-09-24.md:86` "176 registered gates";
  `port/handoffs/ACTIVE_LANES.md:705` "176 gates";
  `port/release-notes/horde-nacre-2026-09-25.md:21` "185/185 gates";
  `port/native-ci/evidence/CONSOLIDATION_2026-09-28.md:34` "199/199 gates, zero
  unrun"; `port/finish/matrix.json:107` "359-gate";
  `docs/audit-2026-10-06/GATE_STATUS.md:102` "384 registered gates".
- The committed `port/reports/verification.json` says **318**
  (`"planned": 318`).

There is no single source of truth for the count: it is restated by hand in at least
seven documents, all of which are now behind the code, and none of which is checked
by a gate. `test_playable_gates.py` asserts no count at all (§1.3).

**S10 — `horde-controls` can pass against a stale committed fixture.** Gate
`horde-input-oracle` writes `port/reports/horde-input-vectors.json`
(`verify.py:122`); gate `horde-controls` reads it (`verify.py:432`). That JSON file
is **tracked in git**. CI sets `COCS_VERIFY_KEEP_GOING: "1"`
(`godot-native.yml:31`), so a failure of `horde-input-oracle` does not stop the run
(`verify.py:566`). `horde-controls` can therefore pass against the committed fixture
from an older source while the run reports `horde-input-oracle` failed. Nothing in
`verification.json` records which copy of the vector file was consumed.

**S11 — `execution.executed` counts gates that never launched a process.**
The `missing-prerequisite` branch writes a result row with
`exit_code: None`, `duration_seconds: 0` (`verify.py:552-555`) and `record()`
increments `executed` for it (`verify.py:497`). So `executed` means "reached a
decision", not "ran". This is tested and intended
(`tools/godot-dev/test_verifier_report.py:124-139`) but the field name overstates it.

**S12 — `/tmp/opencode` is a hard-coded, shared scratch root.** Created
unconditionally at `verify.py:15` and used by `benchmark-autostart` (`:211`) and
`campaign-compact-ui` (`:274`); `material-coverage-floor`'s registration is at
`:290`, but its shared-scratch use is `tools/godot-dev/coverage_floor.py:22`.
Two verifier runs on one host share it.

---

### Post-verification corrections (T18)

Flash's independent verification recomputed the registry census and tier math
from scratch and corrected this document before shipment: the Tier D subset
relation is now stated against the engine-free class (A-exclusive 98 + D 22);
the renderer census cells match the tier-derived counts (216 direct headless +
22 transitive headless + 6 windowed-direct + 22 windowed-transitive + 120
no-engine = 386); G4/S4 list five fallback sites / six gate ids and state that
the fallbacks cannot engage inside a `verify.py` aggregate (`GODOT_BIN` is
required at `verify.py:515` and children inherit the environment); the
`gl_compatibility` figure is marked as the `argv` count; S9's arithmetic is
corrected to 3 commands behind; and S12 cites `coverage_floor.py:22` for the
shared scratch root.

---

## 7. Method limits — what this document does *not* claim

- **No gate was executed.** All classification is static: `ast` parsing of
  `verify.py` plus targeted reads of the **167** distinct scripts referenced by the
  **120** engine-free registrations (Tiers A ∪ D), to resolve transitive
  engine/display/audio use. Every tier assignment names the file:line that
  justifies it.
- Only the transitive launchers listed in §2 were inspected for display use. A
  non-engine gate whose launcher chain reaches a display server through a *second*
  hop that is not in the inspected set could be mis-tiered as A or D.
- Tier assignments are **not** claims about whether a gate passes. Nothing was run.
- `port/reports/*.log` contents were read only for the orphan-vs-missing
  cross-check in S6; no log content was treated as evidence that a gate passes.
- The committed `port/reports/verification.json` is used only as evidence about the
  *schema* and the *binding gap*; its 318 recorded results are historical and are
  not re-asserted here.