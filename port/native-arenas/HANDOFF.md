# Native arenas: source-backed local Deathmatch authority

## Launcher API and package closure

```js
import {createNativeArenaAuthority} from './port/native-arenas/authority.mjs';
const authority = await createNativeArenaAuthority({
  port: 0, host: '127.0.0.1', mapId: 'prism-foundry',
  mode: 'deathmatch', bots: 2, roundSeconds: 180,
});
// authority.port: bound port; authority.endpoint: ws://127.0.0.1:PORT/native-arenas
// HTTP / readiness: {localOnly:true, port:PORT, v:3, mapId, geometryHash, ...}
await authority.close(); // idempotent; owns WS clients, HTTP listener and tick timer
```

`createAuthority(options)` is also exported with the unbound Horde-compatible
`{server,wss,close}` interface. Prefer the awaited bound API for launchers.
The bound API rejects non-loopback hosts. One local connection owns peer/actor 0;
additional connections/guests are rejected before upgrade. The remaining seats
are source bot actors. This release is explicitly **one local human plus bots**.

Rules can be provided through `config:{mode,botCount,difficulty,timeLimit,fragLimit}`
or top-level `mode,botCount,difficulty,timeLimit,fragLimit`. Launcher aliases are
`bots` → `botCount`, `roundSeconds` → `timeLimit`; conflicting aliases reject.
Defaults: deathmatch, **3 bots, normal difficulty, 180 seconds, 15 frags**.
Bounds: bots **1–7**, seconds **60–900**, frags **5–50**, difficulty
`easy|normal|hard|nightmare`. Other gameplay settings, modes and unknown
top-level option keys reject. HTTP serves the documented loopback readiness
probe on `GET /` only; other paths/methods are 404/405. These
are source-normalizer bounds, so e.g. a requested one-frag round cannot silently
become five frags. Normal source timed results apply without endless/sudden-death
mutators.

`catalog.mjs` exports `NATIVE_ARENA_CATALOG` (three frozen native `{id,name,family,path}`
entries), `IDENTITY_ARENA_CATALOG` (the three identity maps), `ARENA_CATALOG`,
`NATIVE_ARENA_IDS` (unchanged historical three), `IDENTITY_ARENA_IDS`,
`DEATHMATCH_ARENA_IDS` (all six) and `nativeArenaEntry(id)`. Native IDs are
exactly `prism-foundry`, `aurora-basin`, `cinder-array`; identity IDs are
`lacuna-court`, `vermilion-fold`, `nacre-engine`. Unknown IDs still fail before
any filesystem access, and only the catalog's static paths are ever opened.

Runtime module closure owned here:

- `port/native-arenas/authority.mjs`
- `port/native-arenas/catalog.mjs`
- `port/native-arenas/schema.mjs`
- `port/native-arenas/match.mjs`
- `port/native-arenas/input-buffer.mjs`
- `port/native-arenas/event-cursor.mjs`

Include the existing pinned `game/core.mjs`, `game/config.mjs`, `game/data.mjs`,
`game/protocol.mjs`, `game/terrain.mjs` dependency closure and `ws`. The authority
does not import native-Horde validation or server code. Test runners/fixtures
are outside the production import closure.

**Explicit dynamic-read package closure:** module scanning does not discover
the static JSON reads. Copy these files byte-for-byte at these relative paths:

```
runtime/port/native-arenas/schema.mjs
runtime/godot/native_arenas/generated/prism-foundry.json
runtime/godot/native_arenas/generated/aurora-basin.json
runtime/godot/native_arenas/generated/cinder-array.json
runtime/godot/identity_maps/generated/lacuna-court.json
runtime/godot/identity_maps/generated/vermilion-fold.json
runtime/godot/identity_maps/generated/nacre-engine.json
```

`discover.mjs` declares them as `dataFiles` (native family) and
`identityDataFiles` (identity family); `build.py` validates both against exact
allowlists, requires committed bytes, and adds
`identity_maps/generated/*.json` to the PCK include filter.

`readNativeArena(mapId)` resolves only the static catalog with
`readFileSync(new URL('../../' + entry.path, import.meta.url))`. No URL/path
override, dynamic import, client-supplied JSON, arbitrary ID, source-map alias,
or global source map registry write exists. Missing/invalid assets fail before
the bound authority opens its listener. Browser-Origin upgrades are rejected.

## Schema and source construction

`schema.mjs` exports `parseNativeArena(data, expectedId?)` (native family),
`parseIdentityArena(data, expectedId?)` (identity family),
`parseArenaEnvelope(data, expectedId?)` (family dispatch), `readNativeArena(mapId)`,
`canonicalArenaJSON(value)`, and `nativeArenaGeometryHash(arena)`. Parse/read return
the **envelope**, with `.arena` containing source gameplay geometry and
`.spawnPoints` containing native feet positions where the envelope authors them.
Deep allowlists validate simulation structures, numeric bounds, terrain
triangles/indices/winding/degeneracy, wall segments (identity envelopes may use
`{x,y,z}` wall endpoints), pickups, identity, support for spawn/nav/pickup
points, and spawn height agreement. Identity presentation metadata
(`mode/palette/art/cameras/landmarks/grayboxHash/artNotes`) and the optional
`objectiveZones`/`teamSpawns` fields are strictly bounded; Vermilion Fold must
author exactly three objective zones. Metadata never becomes simulation options.
Limit: 8 MiB per generated file.

`geometryHash` is SHA-256 of **arena only**, recursive lexicographic object-key
order, preserved array order, Node `JSON.stringify` number semantics. Parsing
recomputes and verifies it. Envelope and arena IDs/names must agree. Hashes bind
the copied arena content; package provenance still comes from the reviewed
geometry generator and package manifest, not from a client assertion.

`createNativeMatch({mapId,config,random,character,harness,arenaData?})` returns an
actual source `Match` instance. `random` defaults to `Math.random` and can be a
seeded function for deterministic source verification. The optional `arenaData`
is a **trusted in-process fixture seam** that undergoes the same schema/hash
validation; no wire message is permitted to select it.

Source `Match` ignores `options.arena`. This factory closes over the validated
arena in a local subclass accessor, intercepting **the constructor's own**
`this.arena = getMap(mapId)` assignment. Every subsequent floor bake, navigation,
spawn, pickup and actor initialization sees the native arena. A second arena
assignment rejects. There is no post-construction transplant and no temporary
global map registration. Combat, movement, bot policy, weapon damage, death,
scoring, respawn, pickups, results and snapshots remain source methods.

Geometry adaptations use source highest-walkable-XZ support; the geometry owner
visibly seals overlapping underdecks and supplies supported DM routes. This
authority preserves those source physics semantics.

## Protocol and optional native client

Ordinary protocol 3 works with existing `godot/net/client.gd`:

1. `create {v:3,delta:0}` → `welcome`, unconfigured `lobby`.
2. `host {mapId,config:{mode:'deathmatch',botCount:2,...}}` → configured `lobby`.
3. `start` → `start`, construction `events`, initial `snapshot` (`time:0`).
4. `input {seq,input:{...}}` → source steps, full 60 Hz `snapshot` (every source
   step; the client applies the authoritative pose directly, so the snapshot
   cadence is the on-screen translation cadence), `events`.
5. Source completion → final snapshot + one `results`; `start` starts a fresh
   round with reset source score/time, ACKs, snapshot sequence and event IDs.
   `host` may reconfigure rules after results. Map identity remains launch-fixed.

All controls run through source `parseInputEnvelope`, including **ADS true and
false**, alt-fire and mobility. FIFO: one received sample per source 60 Hz step;
held controls persist, reload/power/interact/melee/grenade/weapon pulses do not.
ACKs advance when a sample actually steps, never on receipt. Queue cap 16;
oldest queued/held input expires after 250 ms. Death, expiry, explicit cancel and
round restart discard queued controls. Tick backlog is bounded to five source
steps; constructor work does not count as source time.

`godot/native_arenas/client.gd` extends the normal client. Use it where focus loss,
pause or capture release needs reliable cancel semantics. It negotiates
`nativeArenaInput:1` in `create` and sends `inputEpoch` with every packet.
`send_controls(controls, cancel=false)` and ordinary `send_input(controls)` are
available. `send_controls({}, true)` immediately clears pending held/pulse input;
`input_reset(reason)` tells the controller to clear its local held state after
death/expiry. Start/snapshot/results include `inputEpoch`; additive
`native-arena-input-reset` advances it. Old epochs cannot re-arm controls.
`nativeArenaInput` in snapshots/results is an input-status dictionary with
`receivedSeq`, `appliedSeq`, `cancelledThrough`, `queueDepth`.

Ordinary clients omit the epoch and ignore the additive reset frame; TTL/FIFO
still apply. They cannot distinguish newly sent controls from pre-boundary
in-flight packets. Prefer the native client for the playable UI. Ordinary
client compatibility is tested rather than requiring every caller to migrate.

Events follow retained source **object identity** every source tick, not serial
arithmetic (source serial also allocates entities; payloads may replace `id`).
Each outgoing event gets a finite round-local ordinal `id`, preserving payload
identity as `sourceId`. Preserve these wire IDs through presentation dedup;
different events with the same `sourceId` must remain separate. Lost event-ring
cursor fails the owned connection rather than silently skipping effects.

## Verification commands

From repository root; set `TMPDIR` in the invoking environment for any harness
temporary work. These runners do not create a separate full worktree.

```sh
node --test port/native-arenas/tests/*.mjs
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 node port/native-arenas/godot-protocol.mjs
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 node port/native-arenas/godot-protocol.mjs --actual --map=prism-foundry
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 node tools/godot-dev/launch.mjs --experience=native-dm --map=lacuna-court --smoke
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 node port/native-identity-dm/verify.mjs
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/native_arenas/protocol/client_contract.gd
```

`tests/identity-maps.mjs` runs the same generated-data gate for the three
identity maps: strict family schema, canonical hash, source Deathmatch with bot
movement/routing/shots/damage/kills, results and restart, plus one real-time
loopback authority round. `port/native-identity-dm/` holds the route/package
evidence: launcher smokes, Xvfb screenshots and the detached package probe.

The default Node and Godot integration suites are explicitly **synthetic arena**
fixtures. Real-time Node WebSockets exercise source damage/frags/results/restart
without Match-state fabrication or injected clocks. Separate `actual-maps.mjs`
fails missing generated files and simulates source rounds using the real static
assets. Godot `--actual` likewise uses generated data. Visual scene/package
acceptance remains the integrating lead's owned gate.

## Source read-only audit pins

SHA-256 at implementation audit (source remains unedited):

| File | SHA-256 |
| --- | --- |
| `game/core.mjs` | `23d0a86acf720136c62a42547207b1c43f2146002fd26d8ac7d325b2d6312631` |
| `game/protocol.mjs` | `362716c6b5ba222a64a76580efae1513c65eededd5a33116ff53974bf07a7fdb` |
| `game/config.mjs` | `d2c8679e3a77bbe0dd3ccb8d010b8cb46345617f3758c58c8df31b1cecd88d9c` |
| `game/bots.mjs` | `2a6d3fcd7960711fc4aeefe77aaa39dc1a318c6c36097ede7010894a411cf95a` |
| `game/terrain.mjs` | `37fdacc8b120490254a15d5ec6bf7838f0a89ebe54ef6ead1675f909cbad456c` |
| `game/maps.mjs` | `729d94c4a3bc566d3c6b89c8c5c7d656babf338f2ab42edc988f383e021dd731` |
