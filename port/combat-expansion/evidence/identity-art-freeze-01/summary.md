# Identity art freeze — lead acceptance

Data: art lane commits `e140e489` + `e17d6022`.

- `node --test port/native-arenas/tests/identity-maps.mjs` — **4/4 pass** (3 real source
  Deathmatch rounds + 1 real-time loopback authority round), 61.5 s.
- `node --test port/native-arenas/tests/schema.test.mjs` — **9/9 pass**.
- Launcher smoke, real authority per map — **all three** `NATIVE_DM_SMOKE_OK` with the
  delivered hashes: lacuna `a87f8e7a…` ack16, vermilion `6253164e…` ack16,
  nacre `b3636eff…` ack17; each 3 actors, moved, fired, clean cleanup.
- Cold construction after the collision fix (lane report): 27.4 / 19.4 / 39.2 ms versus
  6,059 / 2,950 / 14,828 ms before; parity proven by 19,976 rays with zero
  classification/visibility mismatches and 6,150 Godot ray checks.
- Lead visual review of `render-final-1790085699477045605/1280x800`: Vermilion's folds
  are now smooth ribbons with brushed-metal ribs and jade plinths; Lacuna reads as chalk
  stone with copper studs and indigo recesses. First-pass stylized, but distinct and
  textured; no final lighting/GPU acceptance claimed.

The first smoke attempt in this log shows an empty section because the shell lacked
`GODOT_BIN`; the corrected run is appended above. Retained deliberately.
