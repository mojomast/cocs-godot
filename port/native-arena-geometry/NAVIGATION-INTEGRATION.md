# Cold-navigation optimization / schema coordination

**Measured candidate is ready:** unchanged exact geometry + source `nextGen:true` + source-walkEdge-validated authored navigation chords at most 3m apart produces **303 connected nodes / 2,230 edges in 1,913ms cold source navigation**, versus 948 / 17,166 / 39s before. All dense authored route samples are within 1.5m of the graph. See `evidence/navigation-candidate.json`. Adopting this candidate now requires the one-line public-schema boolean adjustment below; the geometry owner has not edited the authority-owned file.

A second isolated cold navigation run measured **1,947ms**, confirmed no authored nav/spawn/pickup was pruned, and confirmed the maximum edge is 6.5m. Candidate arena hash: `2a8c06ba5b3a893135a3a6aef906a36f016107b5153fe5ec3b8a9efbfee66c86`. This is a navigation measurement, **not** a complete `createNativeMatch` measurement; the latter remains schema-blocked.

The retained valid export is hash `2dc5c0fa75ccb8bb9dc1a0fd35dee55b5a2c0497b38da0fad15dcd1c802a595e` (route thinning, `nextGen:false`, 796 nodes). Actual source movers completed every authored route in all three maps, and the actual-map AI/combat/results/restart gate passed 3/3 on those retained assets. Cold constructors in that mover run: Prism 1,853ms, Aurora 19,511ms, Cinder 2,235ms. No collision triangles or cover were removed to obtain these results. This retained Aurora still fails the requested <10s target.

The lead has requested source `nextGen:true` spatial navigation for the native DM export, retaining explicit dense authored ramp/route nodes and exact collision. The current public schema (`port/native-arenas/schema.mjs`, check following `raised`) rejects any value other than `nextGen:false`.

Minimal authority-owner adjustment needed if the measured candidate is adopted: accept a boolean `arena.nextGen` (true or false), rather than only false. Keep the existing key allowlist and canonical arena hash validation. This is an existing source navigation mode, not a new protocol field or a source gameplay change. Geometry will continue invoking the actual schema before writing any asset; it will not publish schema-rejected JSON or patch the authority validator outside its ownership.

Replace `if (a.nextGen !== undefined && a.nextGen !== false) fail('nextGen must be false');` with `if (a.nextGen !== undefined && typeof a.nextGen !== 'boolean') fail('nextGen must be boolean');` in the authority-owned validator. Prism and Cinder retain `false`; only Aurora opts into the existing spatial navigation path.

The previous cold-timeout and warm-cache screenshot evidence remains explicitly preliminary for startup performance. A fresh cold constructor and fresh normal server smoke are required after optimization; cache warming is not a performance fix.

The capture runner's warmup has been removed. After the authority-owned schema adjustment, regenerate through the real validator, rerun `rebuild.mjs --check-determinism`, `movers.mjs`, and `node --test port/native-arenas/tests/actual-maps.mjs`, then launch a fresh normal Aurora server with `GODOT_BIN=<pinned binary> node tools/godot-dev/launch.mjs --experience native-dm --map aurora-basin --smoke`. The requested post-spatial cold native-constructor and normal-server smoke remain blocked until adoption.
