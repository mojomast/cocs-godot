# Trap-fix re-acceptance (lead)

Lane commit `bdfa4203`. New hashes: prism `1901d0ae…`, aurora `8457812f…`, cinder `2d5e5cfa…`.

- Real launcher smoke per map — **3/3** `NATIVE_DM_SMOKE_OK` with the new hashes:
  prism ack16, aurora ack13, cinder ack17; each moved, fired, clean cleanup.
- `node --test port/native-arenas/tests/actual-maps.mjs` on the regenerated data — **3/3**.
- Reviewed the flagged `probe.gd` retarget: the sealed-volume ray origin moved from y=1.5 to
  y=3.0 so it clears the now-walkable DM guard rail and reaches the west service bank, with an
  explanatory comment; the sealed-volume movement assertion is unchanged. **Accepted.**
- Original High-severity defect: bot frozen 71 s at the west Prism ramp; now `obstructed`
  false at the contact radii and escape measured in three directions plus jump
  (per the lane's `trap-min` reproduction).
- Known residual, assigned back to the same lane: Cinder natural caldera steps still
  trap at seed 20260922 (97.5 s / 22 s / ≤2 s) — a pre-existing class on non-walkable
  terrain, requiring authored terrain reshaping rather than a source change.
