# Identity Deathmatch — route and package lane

Scope: make **Lacuna Court**, **Vermilion Fold** and **Nacre Engine** playable as
source-authoritative **Deathmatch** in the next Windows release. This lane owns
the registry, source-match factory acceptance, launcher routing, package closure
and Windows menu entries. It does not own geometry, art or the identity map
scripts (`godot/identity_maps/**` is the art lane's; `port/native-identity-maps/**`
is read-only reference).

## Route

```sh
node tools/godot-dev/launch.mjs --experience=native-dm --map=lacuna-court
node tools/godot-dev/launch.mjs --experience=native-dm --map=vermilion-fold --smoke
node tools/godot-dev/launch.mjs --experience=native-dm --map=nacre-engine
```

The Windows package uses the same experience/map pair through `Play.cmd` or the
`Native Deathmatch.cmd` menu (options 4–6). Deathmatch is the only mode on this
route; identity recipe modes (`domination`, `horde`) are metadata for later waves
and are rejected here.

`res://native_arenas/demo.tscn` composes the shared session (presentation,
first-person/ADS, HUD, scoreboard, pickups, combat/effects, results/restart) with
each map's geometry. Native maps keep their own builders and atmosphere; identity
maps load `res://identity_maps/map.gd` (`build(id)`) plus the single documented
shared environment in `godot/native_arenas/identity_environment.gd` (one sun, one
`WorldEnvironment`, colors derived from the validated recipe palette).

## Registry and factory

- `port/native-arenas/catalog.mjs`: six reviewed entries (`native` / `identity`
  families); `NATIVE_ARENA_IDS` keeps its historical three-id value,
  `IDENTITY_ARENA_IDS` and `DEATHMATCH_ARENA_IDS` add the identity roster.
- `port/native-arenas/schema.mjs`: family-aware strict envelopes. Native
  envelopes are unchanged; identity envelopes additionally allow
  `mode/palette/art/cameras/landmarks/grayboxHash/artNotes` and the optional
  `spawnPoints/colliderSources/provenance`, and strictly validate
  `arena.objectiveZones` (exactly three on Vermilion Fold) and
  `arena.teamSpawns` (`0/1`, `red/blue`, `west/east` spellings) when present.
  `geometryHash` remains SHA-256 of canonical `arena` JSON only.
- `port/native-arenas/match.mjs` / `authority.mjs`: the scoped constructor
  accessor is unchanged, so identity maps construct plain source `Match`
  instances with their own spawns/pickups/nav/blocks under source Deathmatch
  rules. Bots 1–7, seconds 60–300, frags 5–50. Unknown authority options are
  rejected; HTTP readiness is GET `/` only.

## Verification

- `node --test port/native-arenas/tests/*.mjs` — native three, identity three,
  strict schema, real source-backed rounds.
- `tools/godot-dev` and `tools/godot-package` `*.test.mjs` — routing/menu/closure.
- `node port/native-identity-dm/verify.mjs` — the full route gate: Node suites,
  real launcher smoke per map at HEAD, then Xvfb captures. The consolidated run
  is recorded in `evidence/verify-report.json` (all eight steps exit 0) with its
  per-step logs.
- `port/native-identity-dm/captures/<map>-<stamp>/` — live graphical sessions at
  960x640 and 1280x800, first-person rig active, real Node authority; the
  screenshots were visually inspected by this lane.
- Detached package: `tools/godot-package/build.py` (linux/windows) hashes and
  copies the identity JSONs into the closure/PCK; `res://native_arenas/package_inspect.gd`
  runs from the exported PCK and proves the identity JSONs and the identity
  builder resolve, plus the source-operator resources.
  `evidence/package-staging.json` records the detached run, which used a private
  committed worktree snapshot of the art/geometry bytes. The release build must
  be re-run from the primary checkout once those lanes commit their
  `godot/identity_maps/**` and `godot/native_arenas/generated/**` bytes; the
  builder deliberately refuses uncommitted runtime data.

## Later waves (not this lane)

- **Domination (vermilion-fold)** needs a zone-mode composition route
  (`godot/zone_modes/demo.tscn` currently rejects map ids outside the locked
  nine-map catalog), a domination-capable authority path (`host` currently
  accepts `deathmatch` only), team-spawn usage, capture/contest/loss recovery
  acceptance, plus its own package/menu entries. This lane already validates and
  carries `arena.objectiveZones` (exactly three) and `arena.teamSpawns`.
- **Horde (nacre-engine)** needs `port/native-horde/authority.mjs` to accept a
  reviewed static identity map/factory hook under its existing loopback,
  single-human, epoch and bounded-message contract, plus wave/defeat/boss/endless
  acceptance. The identity envelope's own `mode` metadata is `horde` for this map.

