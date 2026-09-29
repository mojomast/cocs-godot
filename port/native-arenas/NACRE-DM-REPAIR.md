# Nacre Deathmatch recipe compatibility repair

Base: `79c7b8c7`. Trigger: real Windows `native-dm --map=nacre-engine`
failed with `Invalid native arena: arena fields`.

The committed `godot/identity_maps/generated/nacre-engine.json` contains
`arena.hordeCaches`, not `arena.singleplayer`. After that first rejection, the
old DM schema would also reject the source-supported `megahealth` pickup.
The committed survivor pool has two spawns; the repair additionally validates
the reviewed Horde contract's asymmetric pool bounds (1–4 survivors, 4–32
enemies), rather than applying the generic two-team DM bounds.

The adapter now validates Nacre's Horde-only cache metadata explicitly against
the reviewed contract in `port/native-horde/authority.mjs`: bounded unique
pickup IDs naming approved weapons, ordered waves 1–30, bounded zone labels,
and no unknown cache keys. Only Nacre's `mode: horde` recipe gets this surface
and the asymmetric Horde team-pool bounds. Positions still require walkable
source support. The complete arena retains its canonical hash and geometry;
no recipe or source gameplay bytes change. Source Deathmatch uses the authored
ordinary spawn/pickup pools; Horde cache gates are applied only by the Horde
adapter. `megahealth` retains source `Match.useful/collect` semantics.

Regression: `tests/nacre-authority.test.mjs` loads the actual committed recipe,
checks strict rejection of tampering even with recomputed hashes, and opens
the real local DM authority for HTTP readiness plus WebSocket create/host/start
and a source snapshot, including supported actor placement and ungated caches.
It fails at recipe validation on the base revision. The separate existing
`tests/identity-maps.mjs` generated-map combat gate also covers all three maps,
but is not named `*.test.mjs`. The new bounded regression is discoverable by
the standard native-arena test glob and explicitly included in the canonical
`native-arena-authority` gate in `tools/godot-dev/verify.py` (which uses a file
list, not a glob). That gate now runs with `--test-concurrency=1`.

Package provenance: `schema.mjs` is already in the dynamically hashed adapter
closure via the authority/match imports. A rebuild incorporates its changed
bytes; the static map digest remains unchanged. Existing failed archives and
Windows logs must remain intact as evidence.

Verification after the parent granted the sole local heavy slot:

- Initial bounded run: real Nacre DM HTTP/create/host/start/snapshot passed.
  A test-only assertion incorrectly expected one survivor spawn instead of the
  committed two; corrected without changing the recipe.
- Serial native-arena `*.test.mjs`, actual `identity-maps.mjs`, and Nacre Horde
  regression run: 50 passed, one stale Horde catalog-count assertion failed
  because it omitted the already-shipped Cinderwake. Replaced that assertion
  with the exact five-map catalog, rather than relaxing it.
- All 37 native-arena tests in that run passed, including all three actual DM
  combat maps and live Lacuna authority results/restart. Nacre DM reached the
  frag limit at 37.6 simulated seconds: 408 shots, eight kills, bot movement and
  navigation routes observed, plus successful restart.
- Targeted final rerun of the changed Nacre DM and Horde test files: **17/17
  passed**, including the added live Horde create/host/start/snapshot test,
  all ten source Horde waves, and strict tamper checks.
- `node --check` and `git diff --check` passed before the first commit; final
  diff whitespace and verifier Python syntax checks also passed.

Preserved logs are under `evidence/nacre-dm-repair/`: `nacre-dm-authority-first.log`,
`nacre-dm-native-and-horde-first.log`, and `nacre-dm-horde-final.log`. The first failures are
retained alongside the passing targeted rerun.

Commands:

```sh
node --test --test-concurrency=1 port/native-arenas/tests/nacre-authority.test.mjs
node --test --test-concurrency=1 port/native-arenas/tests/*.test.mjs port/native-arenas/tests/identity-maps.mjs port/native-identity-horde/identity-horde.test.mjs
node --test --test-concurrency=1 port/native-arenas/tests/nacre-authority.test.mjs port/native-identity-horde/identity-horde.test.mjs
```

Full native/server suites, Linux/Windows rebuilds and real platform smoke are
parent-owned follow-up gates after the runtime repair is integrated.
