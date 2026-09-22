# Cinder trap residual — lead re-acceptance (`5ebef3b0`)

New hashes: prism `c727d8ca…`, aurora `94f1c306…`, cinder `f372c98c…`.

- Real launcher smoke per map — **3/3** `NATIVE_DM_SMOKE_OK` on the new hashes
  (prism ack17, aurora ack13, cinder ack16).
- `actual-maps.mjs` — **3/3**.
- `movers.mjs` — every declared route finished on all three maps, 0 errors;
  Cinder cold construction **78 ms**, Prism 1,458 ms, Aurora 1,412 ms.
- `verify.mjs` — floors/rays/sealed volumes/spawns/pickups/route counts unchanged
  and navigation connected (prism 429, aurora 311, cinder 234 nodes).

Lead review of the three flagged judgment calls, all **accepted**:
1. Cinder `nextGen: true` — same source navigation mode already adopted for Aurora;
   required because walkable rail caps would otherwise bake isolated nav islands, and
   `pruneToLargestComponent` removes exactly those.
2. Thin low guard bands trimmed to support + 0.35 m — walkers stay refused by the
   source 30 cm step limit, a single hop clears them. **Accepted consequence:** a
   player can now hop a thin guard rail where before it was an unrecoverable trap.
   The alternative (97.5 s immobile bots) is strictly worse, and Cinder's void already
   handles falls through the source death/respawn path.
3. Burial tolerance 0.3 → 0.45 m — lips just above the step limit no longer create
   refusal pockets.

Also reviewed: Cinder movement bands drop 848 → 138 (prism 590 → 580,
aurora 4,849 → 4,842) while ray/collision parity and `walkableRayBlocked = 0` hold,
so visibility and projectiles are unchanged.

Accepted residual: one 3.5 s bouncing window at the bore causeway lip (seed 777,
maxRadius 0.04, one-hop escape) — removing that band would open a fall-through hole
into the sealed bore, so it stays; landed-lock detector reports zero everywhere.
Measurements are Linux GL Compatibility / llvmpipe, not Windows or GPU.
