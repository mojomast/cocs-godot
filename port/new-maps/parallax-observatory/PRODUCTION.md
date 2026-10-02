# Parallax Observatory — production proof ledger

Runtime merge: `e731fd536d31d16a7014402afe6670fca644f9c1` was merged before engine work. Original map/source byte comparisons are retained in `original-worlds-unchanged.json` under the evidence root.

## Architecture revision

The first Blender review was rejected locally for sparse districts, generic vaults and overlapping-floor shading. Its four images remain in `blender-rejected-first/`. Revision two added the four-portal polar instrument hall, the optical arcade, six source-solid institute wings, faceted roof lanterns, wall-mounted instruments and coastal masonry strata. Further review corrected buried archive panels, foundation-fin coplanar caps and repeated route-node paving discs. Native image review then drove an art-only refinement: source-backed blind facade bays, engaged cliff piers, optical survey paving, fluted portal panels, archive dados and a radial polar measuring court/coffered ceiling. The authoring script subtracts previously covered floor footprints to render the exact supported union without duplicate coplanar floors.

There are now three enclosed interiors (plate archive, tidal pump vault, polar hall) plus a columned optical arcade and the walk-under meridian service gallery. Five source ceiling slabs have complete undersides, tops and individually triangulated perimeter walls. Visible coastal cliff faces also belong to source collision, preventing lower-tier shots passing through rendered masonry. Floors retain the highest-support-compatible single-valued height field.

The editable master is outside Godot. Its named meshes remain individually editable; the production GLB contains seven material batches. Test scripts live in `godot/tests/new_maps/parallax_observatory/`, not the runtime art folder. `presentation.gd` in the art folder is the actual scoped runtime interior-light/route-help implementation.

## Reproduce in exclusive heavy slot

Use `LP_NUM_THREADS=1`, one heavy job at a time. Blender CPU Cycles is used for review because the environment lacks `libEGL.so.1`. Use `--python-exit-code 1` so a Blender script assertion cannot masquerade as a successful shell exit.

```sh
node tools/godot-multiplayer/new-maps/parallax-observatory/generate.mjs --check
node port/new-maps/parallax-observatory/acceptance.mjs
node port/new-maps/parallax-observatory/wall-contacts.mjs
node port/new-maps/parallax-observatory/audit-art.mjs
node port/new-maps/parallax-observatory/native-journey.mjs ctf
```

`PARALLAX_VISUAL=1` enables the actual native viewport capture preset. The native driver creates ordinary key/mouse events; the production sampler and WebSocket protocol remain intact. A separate wire peer provides passive opposition. The Node controller reads source positions/navigation but writes no actor positions, health, flags, scores or objective state. These are controlled functional fixtures, not competitive-balance evidence. `bots.mjs` separately observes unscripted source AI for bounded 90-second windows.

The software capture driver uses crouched movement, paced key holds and a 2.5 m viewing-stop tolerance; source waypoints/flag interaction distances retain their source rules. The first all-district visual tour exceeded its original seven-minute watchdog while still moving through the lower route and remains in `native-walkthrough-timeout-retained/`. The final driver permits a bounded ten-minute tour and uses longer input pulses at the measured rendering cadence. Neither attempt changes gameplay authority or teleports the actor.

The physics probe verifies the source/native triangle multiset, 859 route support rays and standing capsules, imported-art floor rays, open arches, both-face wall/parapet contacts and upward capsule contacts against all five slab undersides. Temporary art-ray colliders, isolated contact layers and gravity-disabled outside-wall contact isolation belong only to the test script. Six temporary-art rays exactly on clipped triangle edges require a recorded 1 cm X/Z offset; all authoritative center rays pass exactly. Independent barycentric checks on the actual GLB verify all 859 center floors with maximum error below 0.8 micrometres.

Measured assets: 148,239 triangles, seven mesh/material batches, 8,646,208 GLB bytes. The `.blend` retains 24,619 individually editable objects and eight review cameras. Production source physics has 3,563 shape nodes / 4,686 gameplay triangles. These counts are budgets/parity evidence, not visual quality or frame-rate evidence.

## Integration and packaging

Shared bindings are a separate commit: source/native catalogs, development/package options, route metadata/generated routes, explicit nested GLB coverage, and a map-specific presentation hook. The standalone source generator must be used; the legacy overhead-expansion loop would duplicate the authored slabs.

Parent-owned package allowlists and manifest verifiers were not changed. Parent export closure must include the generated arena, nested GLB and its runtime `presentation.gd`. The editable master, authoring scripts and test scenes are provenance/verification inputs, not implicit Blender-import runtime assets.

All final measurements, hashes, accepted modes, receipts and limitations are collected in `provenance.json`, `source-validation.json`, `native-validation.json`, `capabilities.json`, and the evidence root. The Blender-time `asset-manifest.json` retains its build-time `nativeAcceptance: pending`; `native-validation.json` is the later native acceptance receipt. Encoded clips carry their actual timestamp-derived capture cadence in `clip.json`; 15 fps output encoding is resampling, not a performance claim.
