# Operator surface improvement using Moth bake

Owner asked to extend visual improvement to operator surfaces using Moth bake.
Two `openai/gpt-6.1-sol` agents implement the pass in the background, using
[CONTRACT.md](CONTRACT.md) and preserving all nine operator identities.

| Lane | Session | Branch/worktree suffix | Ownership |
|---|---|---|---|
| Authored finishes | `ses_f02255f9affeoL4eRCQ3V6A1xs` | `operator-finish/content-20261002`, `cocs-operator-finish-content-20261002` | All-nine role profiles, actual Moth-derived pixels, deterministic image authoring, hashes/provenance and material coverage |
| Runtime integration | `ses_f0224d30bffeD625JFkaiB42Nk` | `operator-finish/runtime-20261002`, `cocs-operator-finish-runtime-20261002` | UV-stable body/overlay material binding, team/cache isolation, FPS integration, separate fighting hook and native review fixtures |

Both worktrees start at `b6380107` under `/home/mojo/.tmp-on-disk/`.
No nested agents or heavy grant. The combined native integration Astra retains
`FINISH-COMBINED-NATIVE-20261002-A`; its matrix is running at checkpoint
`a84f6961` with evidence in
`/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002/run-8j2z5iot/`.
That checkpoint is not an acceptance result or explicit slot release.

## Acceptance targets

- Real baked Moth surface information with operator-specific authored patterns,
  material response, localized edge wear/recess grime and restrained markings.
- Preserve palettes, silhouette, team color/shape signals, visor/sensor emission,
  LOD, weapons and all animation/authority state.
- Surface-attached UV sampling during rigid and skeletal motion; no map-style
  world projection that slides through characters as they move.
- Reuse source UVs and protect source GLB/rig hashes. Fighting export must retain
  those UVs and demonstrate them in animated native inspection, not just scripts.
- All-nine before/after gallery and closeups, two-team simultaneous instances,
  identity switching, LOD and configure/free lifetime checks. Meta/Mistral first
  for fighting motion, then all-nine coverage. Source pixels are not native art
  acceptance; improvements remain pending until inspected in actual gameplay.

## Merged source checkpoints

Authored content `8d84b3ff` is merged as `2b54a442`: nine profiles, 63 finish
records, 116 unique 256px PNGs (1,071,133 bytes), deterministic authoring and
provenance. Lane audit covered all 1,014 primitives: 538 body primitives bound,
476 intentionally preserved. Normal maps are omitted on matte hand/rubber UVs
with degenerate triangles. Parent inspected the all-nine 2D texture study; this
does not prove rendered appearance. Preview studies are served at
`http://100.125.104.79:8796/operator-finish-preview/`, explicitly labelled 2D.

Runtime `3a2bf1ee`, fighting hook `88fb2d94`, and JSON export filters `12e4eca2`
are merged as `48b3e431`, `5ed5f989`, `d5ff6773`. Lane checks covered grammar and
eight validator tests, but did not yet include actual authored manifest closure.
Parent combined validator exposed a provenance-record schema mismatch for
`shared-rubber-albedo.png`. Runtime owner has the exact failure and actual content
commit for reconciliation; do not treat merged hooks as working native finishes.
Imported tangent availability, final package closure, actual body/overlay binding
and animated appearance remain native gates. No extra heavy grant was issued.
