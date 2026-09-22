# Local Horde route and private package integration

## Scope and provenance

Isolated worktree `/tmp/opencode/horde-route-integration`, branch
`horde-route-integration`, based on the lead review worktree's resolved HEAD
`6a6b391a36b9caeba36117784fa7cb380abb5d0f`. Code commit:
`24d2e4a3b5557a6724f07fd7523f0f83f7c02b16`. The lead worktree was read-only.
Original reports, source `game/` and `server/`, `godot/horde/`, and
`port/native-horde/` are byte-unchanged from that base. No agents, merge, push or
deployment. This is a private local artifact; no new release/asset-rights claim.

Read the final event-repair API and the original independent source-boundary
review, retained defects, and proposals. The final reviewed authority is used
unchanged. The historical review's wave-option proposal is superseded by this
task's fixed default-ten-wave common-route contract.

## Implementation

- Dev and package `--experience=horde` select `res://horde/demo.tscn`, default
  Meridian, mode `horde`, and permit Meridian/Verdant/Ember only. No waves,
  round-target, endless, upgrades, endpoint, trace or evidence option is exposed.
- Only this route lazily imports `createAuthority`. Other owned routes still use
  `createGameServer`; external lobby constructs neither. CLI capability checking
  precedes authority creation. Exact service, numeric transport 1, boolean
  localOnly true and allocated health port are required for Horde readiness.
- Owned factory/listen/health/native failures and signal/native-window shutdown
  retain authority cleanup. Dev now also tracks signals during startup and reaps
  the native child before closing the authority.
- Discovery parses actual static ESM imports for both entry points. A conservative
  tripwire rejects computed/runtime loading for explicit review. Port-owned
  modules have a two-file allowlist, committed-byte check and independent manifest
  hashes. Immutable source verification and pinned-source byte checks stay strict.
- Actual closure: **84 immutable source modules**, **2 adapter modules**;
  Horde reaches **73 source modules + 2 adapters**. Its extra source set relative
  to the ordinary server is empty, established by traversal, not assumption.
  `runtime/port/native-horde/` preserves `../../game/` resolution. Only locked
  `ws` is external. No authority observer/oracle is shipped.
- Release resource inspection now requires **9 production scenes**, including
  the real Horde composition. Tests/probes and the new external observer remain
  outside the production PCK/runtime.
- Generic package verification preserves the inherited 14 startup/ownership
  cases and adds Horde normal-window/native-crash cases with local health
  identity checking. Horde health does not pretend to expose public Room counts.
  Separate passive exported-scene observation checks advancing public snapshots,
  default target/lives/NPC roster, source-origin events, HUD/help and held/released
  Tab at 960×640 and 1280×800 on all three maps. It uses no Match instrumentation,
  source state writes, scene replacement script, steering or alternate authority.

## Focused checks

`focused-tests-final.log`: **52/52 PASS**. This includes the inherited 17 routing
and lobby tests, 2 new Horde option matrices, 3 closure/public-boundary tests and
30 explicitly synthetic factory/native process cases. Synthetic fixtures prove
routing/readiness/cleanup only, never gameplay. Six inherited external-lobby
ownership tests still work without an adapter module in their fixtures.

The first focused run (`focused-tests.log`) retained **51 PASS / 1 FAIL**: the
closure test's `git show` exceeded Node's default output buffer on a large locked
source module. The test now permits 64 MiB; all 84 files compare byte-for-byte to
the source lock. No source or adapter was changed to resolve it.

## Artifact

Built with:

```sh
python3 -B tools/godot-package/build.py \
  --state /tmp/opencode/horde-route-package \
  --archive-directory /tmp/opencode/lobby-popup-free-package/toolchain
```

The official archive cache was read-only; the new state owns its copied,
official-SHA512-verified toolchain. Build result: `build.log`.

- Build: `/tmp/opencode/horde-route-package/builds/1790057444475947148`
- Archive SHA256: `cc34790c0356b9b5c9cea177a4dd2d4ea740e3d905ba44dfb34554fbb8a30089`
- Manifest SHA256: `27e6c8ef82b3c40fa0b2c61a28b84470252aa7392325afaefcb9ca0ebe6e2f67`
- Exact per-file runtime/source/adapter/product hashes: `artifact-inventory.json`.
- Exact import graph and each route's closure: `import-closure.json`.

## Fresh extraction and actual exported evidence — PASS

```sh
python3 -B tools/godot-package/verify.py \
  --build-result /tmp/opencode/horde-route-package/builds/1790057444475947148/build-result.json \
  --output /tmp/opencode/horde-route-package/verification-1
```

First package verification attempt: **PASS**, exit 0. All **14 inherited** generic
startup/ownership cases passed, plus Horde window close and Horde native SIGKILL
cleanup (**16 launcher cases**). Invalid CLI and missing-executable cleanup gates
also passed. Full lobby gameplay/popup automation was not invoked.

Fresh extraction `/tmp/opencode/cocs-package-play-dv_6knmc`, unrelated working
directory below it, PATH containing only a copied Node executable. No editor,
git, npm, checkout or symlinks were needed. Official release runtime inspected
all **9 maps / 9 scenes** with assertions disabled; tests and probes absent.
Manifest/file hashes remained identical after all launches. Locked source check
passed before/after build and after extracted play.

Six purposeful passive product runs, two sizes per map, **120-second outer /
110-second observer deadlines**, no retry or full-round attempt:

| Actual exported map | Size | Public snapshots | Startup |
|---|---:|---:|---|
| Meridian Exchange | 960×640 | 146 | PASS |
| Meridian Exchange | 1280×800 | 147 | PASS |
| Verdant Reliquary | 960×640 | 146 | PASS |
| Verdant Reliquary | 1280×800 | 146 | PASS |
| Ember Crucible | 960×640 | 146 | PASS |
| Ember Crucible | 1280×800 | 147 | PASS |

**878** recorded public snapshots total. Every first live-wave proof was at
source time ≈7.05 seconds: target **10**, wave **1**, lives **3**, enemies **3/3**,
three living `isNpc` roster entries, `over:false`. Public event signals included
constructor `spawn`, two `husk`, `spitter`, `horde-wave` and `horde-modifier` with
original string `sourceId:"swarm"`; adapter ordinals remained contiguous.
These are received source-origin transport events, not an independent source
object oracle or a repeated full event-repair differential.

The passive helper instantiates the exact packed `res://horde/demo.tscn`, checks
its Horde Scoreboard child, reads public signals/model/UI, and captures its
viewport. Production adapter import has **no `observe` callback**. Tab is genuine
XTest key input; held panel visibility, release closure, explicit native window
close and clean exit are checked. No movement/fire, seed selection, simulation
timing edit, Match access, actor mutation or one-wave target override is used.

### Direct PNG review

All six images were opened with the image reader, not just dimension-checked:

- Meridian: [960](evidence/horde-product-meridian-exchange-960.png),
  [1280](evidence/horde-product-meridian-exchange-1280.png).
- Verdant: [960](evidence/horde-product-verdant-reliquary-960.png),
  [1280](evidence/horde-product-verdant-reliquary-1280.png).
- Ember: [960](evidence/horde-product-ember-crucible-960.png),
  [1280](evidence/horde-product-ember-crucible-1280.png).

Map/mode banner, wave 1/10, enemies/lives/score/SWARM strip, four-entry Scoreboard
and two-line controls/help are readable. The Horde strip clears the scoreboard
at both sizes. At **960×640**, the held-Tab scoreboard overlays portions of the
lower health/ammo panels; at 1280×800 those panels remain separate. The inherited
scoreboard still labels the player-plus-NPC roster “4 players.” These presentation
limitations are retained, not corrected or described as complete HUD parity.
The common-launcher [Horde screenshot](evidence/horde.png) was also directly
opened; it is an earlier intermission image, not the live-wave proof.

### Cleanup and retained evidence

Private Xvfb used `-nolisten tcp -nolisten unix`; all authority listeners used
loopback port 0. Observer/native processes used isolated XDG directories and the
test-only null ALSA sink. Every child was reaped, each launcher removed its
temporary state, each observer's XDG tree was removed, and Xvfb was terminated
and waited. A separate post-run check re-tested **22** case ports/PID sets and
removed the extraction's top-level inspection XDG/HOME directories. Extraction
and build artifacts are retained for review; `cleanup.json` records the checks.

`evidence/verification.json` contains full verifier results, exact verifier-input
hashes and product proofs; `evidence/horde-product.json` is the focused product
summary. Raw snapshot/event/native logs are losslessly gzip-archived with mtime 0.
`evidence-sha256.json` inventories all **57** copied evidence files. Failed first
focused-test output remains alongside its successful rerun. No failed product or
package attempt was discarded.

## Exact owned code files

```text
godot/tests/package_inspect.gd
tools/godot-dev/launch.mjs
tools/godot-dev/launch_options.mjs
tools/godot-dev/launch_options.test.mjs
tools/godot-package/build.py
tools/godot-package/discover.mjs
tools/godot-package/options.mjs
tools/godot-package/options.test.mjs
tools/godot-package/run.mjs
tools/godot-package/verify.py
tools/godot-package/horde_authority.mjs          (new; test-only owner)
tools/godot-package/horde_closure.test.mjs      (new)
tools/godot-package/horde_observer.gd           (new; external observer)
tools/godot-package/horde_ownership.test.mjs    (new; synthetic fixtures)
tools/godot-package/horde_verify.py             (new)
```

Evidence changes are confined to this new report directory and committed
separately from code. Source/runtime/original-report diffs from the integration
base are empty. The main verifier, setup menu, root docs, PLAY and
`tools/godot-package/verify_lobby.py` were not edited.

## Shared hooks for lead

1. `godot/ui/match_setup.gd`: advertise Horde as a separate supported demo for
   the three combat maps, with `--experience=horde`; it requires the local-only
   adapter and cannot start in the public Room-backed combat scene.
2. `tools/godot-dev/verify.py`: include
   `node --test tools/godot-package/horde_closure.test.mjs tools/godot-package/horde_ownership.test.mjs`
   alongside existing launcher/package option tests (which already gain Horde
   matrices). Integrate the previously reviewed native/runtime Horde gates as
   appropriate; this task did not repeat the unchanged 50-test event-repair suite.
3. `port/native-linux-package/PLAY.md` and root documentation: document the new
   local-only ten-wave route, three-map support, controls and bounded evidence.
   Explain the separately manifested 2 port adapters plus 84 immutable source
   modules. This artifact retains the lead-owned pre-Horde PLAY text.
4. Independently rebuild/reverify the final lead integration. The updated package
   verifier runs passive Horde product checks automatically. Use the lead's
   popup-free lobby observer when doing full lobby gameplay; this task uses only
   the inherited generic menu ownership cases and never the old popup observer.

No full-ten-wave, boss, defeat, endless, upgrade, full-round, human aiming/audio
or public-server compatibility acceptance is claimed here.
