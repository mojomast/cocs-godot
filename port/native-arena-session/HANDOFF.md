# Native Deathmatch session handoff

## Delivered

Production composition is `res://native_arenas/demo.tscn`, extending the shared
`world/session.gd`. Owned production files are only `demo.gd`, `demo.tscn`,
`catalog.gd`, and `hud.gd` in `godot/native_arenas/`. Tests are under
`godot/tests/native_arenas/session/`; scripts and evidence are in this directory.
The initial session delivery was intentionally untracked. This integration
follow-up preserves it and commits the session production/tests/evidence together
with the released launcher contract corrections.

### Launch contract

```text
Godot --path godot res://native_arenas/demo.tscn -- \
  --experience=native-dm --map=prism-foundry --mode=deathmatch \
  --endpoint=ws://127.0.0.1:<owned-port>/native-arenas \
  --bots=2 --round-seconds=180
```

Allowlisted map IDs: `prism-foundry`, `aurora-basin`, `cinder-array`.
Defaults: Prism Foundry, two bots, 180 seconds. Bots accept `1..7`; round seconds
accept `60..300`. Invalid map/mode/ranges and absent endpoints fail visibly.
Only the owned `ws://127.0.0.1:PORT/native-arenas` endpoint or compatible exact
root is accepted. The host request uses `fragLimit:50`, within the authority's
5..50 bounds, and checks the echoed mode/bot count/duration/frag limit before start.
`--autostart` skips setup; `--smoke` also skips setup and exits automatically.
The lead owns routing `--experience=native-dm` to this scene and packaging its
dynamically loaded map scripts/JSON/client adapter.

The in-window setup shows all three arena cards, instructions, callsign, roster,
bot count and duration. **The authority is pinned to its launch map.** Only that
map's card is enabled; the setup explicitly says to relaunch for another map.
This avoids offering a map change that the isolated authority's `host` command
rejects. A launcher-level three-map choice should spawn a fresh authority with
the selected ID, then pass the same ID to Godot.

### Composition and integration contract

- `NativeCatalog` extends the inherited catalog type. Its entries have `id`,
  `name`, `modes:["deathmatch"]`, `path`, `sha256`, and native geometry metadata.
  It validates all three generated envelopes and returns the envelope's `arena`
  from `resolve_map()`. A changed/missing file after catalog open is refused.
- Renderer paths are built only from allowlisted IDs. No map preloads mean
  absent generated geometry/renderers produce explicit startup errors rather
  than making the composition fail to parse.
- Map-only Node3D builders must implement `build()`, `get_spawn_points()`, and
  `get_arena_id()`. **They are added to the scene tree before build**, because
  their collider collection reads global transforms. `build()` must be
  idempotent (the delivered wrappers also invoke it from `_ready`).
- Native builders own the world environment and sun. Viewer defaults are freed;
  no exploration camera or walker is created. An empty, hidden
  `StaticPickupMarkers` node satisfies the shared compatibility hook. Pickup
  visuals come exclusively from public source state.
- Only the shared public local-actor pose drives gameplay camera position and
  spawn/respawn look reseeding. Shared controls/ADS, lifecycle, actors, combat,
  first person, GameHUD and scoreboard are retained. Results show source
  `leaders`, scores and Enter-to-restart. The HUD's status panel is refitted after
  wrapping to prevent its initial layout becoming a full-height overlay.
- The authority agent's `res://native_arenas/client.gd` is required and preloaded;
  it extends `res://net/client.gd`. The delivered adapter's `input_reset` signal releases
  capture; leaving live capture uses `send_controls({}, true)` to cancel FIFO
  held input. Ordinary controls still use the shared send loop. Do not replace
  the already-instantiated root script to wire the adapter.
- Every `start.geometryHash` must be a nonempty string matching the loaded native
  catalog entry, including restart. Missing hashes fail closed. The client requires
  the authority's input epoch on start/snapshot/results; results must set `over:true`.
- Shared FX integration can attach passive children to this root using its
  existing `client`, `presentation`, `camera`, `first_person`, lifecycle and
  `aim_requested()` hooks. Lead owns final cross-lane FX wiring.

### Smoke contract

Only the real production path emits:

```text
NATIVE_DM_SMOKE_OK {"map":"...","mode":"deathmatch","actors":3,
  "snapshots":N,"acks":N,"moved":true,"fired":true,"localAlive":true,
  "camera":"public-actor","geometryHash":"..."}
```

Success requires an accepted public local actor, alive lifecycle, camera equal
to its public eye pose, public movement from its initial pose, positive local
`shots`, normal input ACK > 10, expected `bots + 1` actor count, and matching
authority geometry identity. The shared explicit smoke stimulus sends ordinary
movement/fire inputs. It does not wait for a complete round or claim graphical
performance. Failure exits 1; shared smoke timeout is 20 seconds and handshake
timeout is 15 seconds. Missing-authority production smoke was measured at
15.395 seconds with exit 1 and no success marker.

## Contract-alignment verification (latest)

- **98 synthetic session checks passed**, Godot 4.5.2, exit 0, no script errors:
  `evidence/contract-alignment-session.log`. The transport fixture now extends
  the delivered native epoch adapter. Checks include bot bounds 1/7 and rejection
  of 0/8, exact endpoint paths, epoch negotiation/reset/regression, held-control
  clearing, FIFO cancellation, matching and missing start hashes, results,
  scoreboard, restart, and echoed configuration rejection.
- **117 launcher option/ownership/regression tests passed**, including endpoint
  negatives in real launcher processes, native smoke deadlines and legacy route
  ownership. Log: `../native-arena-launchers/evidence/contract-alignment-tests.log`.
- **9 actual-factory boundary tests passed**: both launchers run the delivered
  factory and source Match with 1/7 bots and 60/300 seconds, using synthetic
  geometry and a protocol-driving child. Launchers and factory reject 0/8.
  Two existing native closure tests also passed.
- **Real production Prism Foundry smoke passed** on the current generated map:
  three actors, seven snapshots, ACK 17, public movement and shots, matching hash
  `9ba6d451e7acb61847d1b5726ec52385c019e32bbc0805731f14396aca336572`.
  Independently observed authority local shots: 1; applied input ACK: 17.
- **Aurora Basin remains an integration blocker:** the next real smoke timed out
  waiting for round start (exit 1, about 30.1 wall seconds). The authority observer
  recorded one initial snapshot, zero shots and zero applied inputs. A subsequent
  one-off direct source Match construction on Aurora succeeded with three actors;
  this does not explain or clear the live startup timeout. Cinder was not run after
  the failure. Lead should diagnose/rerun after geometry integration settles.

Live evidence, including the failure, is preserved under
`evidence/contract-alignment-live/`. No all-map gameplay or rendered-performance
pass is claimed. Earlier evidence below is historical and remains intact.

`live-smoke.mjs` now allocates a fresh `evidence/live-*` directory by default, or
accepts `--output=<new-directory>` and refuses an existing directory. It pins the
Godot version, isolates XDG data, writes factory/startup failures and partial
reports, correlates the actual authority start hash, and cleans child/listener/data.
Subsequent runs also include observed authority handshake/error timings for timeout
diagnosis. Normal source simulation timing and existing session deadlines apply.

## Initial delivery verification (historical)

Pinned binary:
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.

1. **60 synthetic-public-frame checks passed**, exit 0, no script errors or
   leaked-instance warnings. These exercise argument validation, catalog
   identity/change rejection, dynamic renderer failures, actor zero, camera
   position/look, pickup/actor composition, death/respawn fresh-held gating,
   absent local actor, results/scoreboard/winner, restart sequence reset,
   cross-map transport rejection and geometry-hash rejection. These are
   composition/contract tests, not source simulation acceptance.
2. **All three actual geometry compositions passed**, exit 0: each contains
   exactly one world environment and one sun, zero map cameras, no initial
   public pickup markers, and an untouched gameplay camera until a snapshot.
   Observed MeshInstance3D counts: Prism 193, Aurora 370, Cinder 97 (this is an
   observation of those generated assets, not a fixed acceptance target).
3. **Actual native scene captured under private Xvfb/llvmpipe**, with explicitly
   labeled synthetic actor frames. `evidence/prism-native-actors-fixture.png`
   shows real Prism geometry, a rendered remote actor and native Deathmatch
   overlays. `evidence/setup-fixture.png` shows the start panel. Both images are
   stamped **synthetic frame fixture — not gameplay acceptance**. No project
   copy or existing display was used. The helper cleans its owned Xvfb.
4. Production missing-authority smoke exits 1 within its deadline.

Logs: `evidence/synthetic-lifecycle.log`,
`evidence/actual-geometry-composition.log`,
`evidence/missing-authority-smoke.log`, and `evidence/verification.json`.

## Initial real-authority blocker (historical)

`node port/native-arena-session/live-smoke.mjs` was attempted after both real
geometry and authority files appeared. It failed **before binding a listener**:

```text
TypeError: Invalid native arena: envelope
  at keys (port/native-arenas/schema.mjs:10)
  at parseNativeArena (port/native-arenas/schema.mjs:64)
```

At that attempt, generated JSON contained both `colliderSources` and
`provenance`; the authority envelope allowlist did not accept the full delivered
envelope. This lane did not modify another agent's schema or geometry to mask
the mismatch. **No real source gameplay pass is claimed by this handoff.**

The follow-up Prism pass above confirms that the envelope blocker was resolved
for that attempt. The owned-listener live runner validates its Godot JSON smoke marker against
independently observed authority snapshots, applied ACKs and local-actor shots,
stores per-map logs, and closes each listener/child. The lead's longer live
acceptance should separately exercise bot combat, damage, kills, respawn,
results/restart, native controls, final FX and Windows package cleanup.

## Reproduction commands

```sh
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT" --headless --path godot --script res://tests/native_arenas/session/test.gd -- --mute
"$GODOT" --headless --path godot --script res://tests/native_arenas/session/geometry_composition.gd -- --endpoint=ws://127.0.0.1:1 --mute
python3 port/native-arena-session/capture-fixture.py
TMPDIR=/tmp/opencode node port/native-arena-session/live-smoke.mjs --output=port/native-arena-session/evidence/lead-live-FRESH
```

`GODOT_BIN` overrides the helpers' binary path. The capture helper uses bubblewrap
only to give its owned Xvfb a private `/tmp` socket directory, avoiding the host's
read-only/shared `.X11-unix` directory.
