# Nacre Deathmatch recipe compatibility repair

Base: `79c7b8c7`. Trigger: real Windows `native-dm --map=nacre-engine`
failed with `Invalid native arena: arena fields`.

The committed `godot/identity_maps/generated/nacre-engine.json` contains
`arena.hordeCaches`, not `arena.singleplayer`. After that first rejection, the
old DM schema would also reject the source-supported `megahealth` pickup and
the single survivor spawn in `teamSpawns[0]`.

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
but is not named `*.test.mjs`; the new bounded regression is discoverable by
the standard native-arena test glob.

Package provenance: `schema.mjs` is already in the dynamically hashed adapter
closure via the authority/match imports. A rebuild incorporates its changed
bytes; the static map digest remains unchanged. Existing failed archives and
Windows logs must remain intact as evidence.

Verification at handoff: both edited/new JS modules pass `node --check`;
`git diff --check` passes. Runtime tests await the parent-controlled heavy slot.
Requested bounded command:

```sh
node --test --test-concurrency=1 port/native-arenas/tests/nacre-authority.test.mjs
```

Full native/server suites, Linux/Windows rebuilds and real platform smoke are
parent-owned follow-up gates after the runtime repair is integrated.
