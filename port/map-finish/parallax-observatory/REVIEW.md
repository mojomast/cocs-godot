# Native review queue — Parallax surface finish

Status: source-ready, native not executed. Keep the accepted original imagery and
capture a new paired baseline using the same renderer/light/time/FOV as the finish.
Existing evidence is at
`/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/native-review/`.
Use root-local Godot coordinates below; the accepted art is identity-transform.
Before means dressing disabled; after means Full applied to the same accepted
GLB. Do not substitute the pending interiors-v2 candidate in this comparison.

## Existing comparable cameras

These coordinates are the actual accepted `art.cameras` source, not guessed from
screenshots. Capture all eight paired views and retain the full viewport.

| Camera | Eye [x,y,z] | Target [x,y,z] | Principal check |
| --- | --- | --- | --- |
| `overview` | [185,160,210] | [0,10,0] | Concrete/salt/cut-stone texture hierarchy; sea exclusion; dish silhouette |
| `arrival-eye` | [-111,13.65,-3] | [0,20,-60] | Arrival route plaques, cover contrast, long-distance floor readability |
| `lens-eye` | [8,13.65,5] | [-50,30,-85] | Optical glare control; untouched dish apertures and cross-map sightline |
| `cistern-eye` | [-10,1.65,78] | [24,2,78] | Lower-tier damp surface, T3 entrance and vent locality |
| `archive-interior` | [-45,13.65,0] | [-25,14,3] | Clean cabinet inserts, row indexing, unobstructed axial exit |
| `pump-interior` | [15,1.65,78] | [34,2.5,81] | Damp/oxide films, pipe/dial readability, supply/return labels |
| `polar-interior` | [-12,25.65,-84] | [13,28,-80] | Upper-wall-only frost, real spectrometer hubs, open four-way portals |
| `arcade-eye` | [54,13.65,0] | [89,16,0] | Brushed roof/optical stock, diagnostic pedestals, outgoing route |

Existing source uses 32 mm equivalent for overview and 22 mm for the other
Blender review cameras. For native before/after use the same actual Godot FOV
within each pair and record it, rather than treating those focal lengths as
identical projection. Gameplay uses the normal player camera.

## Additional player-height detail pairs

| Camera | Eye | Target | Bound equipment |
| --- | --- | --- | --- |
| `archive-row-close` | [-40,13.65,3.6] | [-40,13.8,7.105] | Cabinet-edge ceramic and unobscured slots on +Z wall |
| `archive-approach` | [-53,13.65,-4.4] | [-49.03,14.5,-5.4] | West-facing E1 jamb plaque, clear central doorway |
| `pump-pressure-close` | [28,1.65,80.8] | [30.2,2.1,85.08] | Pressure riser/dial beside damp cabinet films |
| `pump-service-close` | [24,1.65,79.8] | [24.2,3.3,85.17] | Oxidation service band, supply/return identification |
| `polar-optics-close` | [12,25.65,-90] | [12,28,-95.4] | Small hub readout beneath localized frost |
| `calibrator-close` | [78,13.65,-2.8] | [78,13.1,-5.475] | Diagnostic panel on source-backed real cover |
| `coastal-footing-close` | [-66,13.65,-3] | [-66,12.65,-7.475] | Salt weathering at an exposed institute plinth |

Capture the archive and pump with identical player height relative to their floor
(1.65 m) so material/story differentiation is judged fairly. Inspect glyphs at
normal gameplay distance; row indices are intended for close equipment retrieval,
while jamb and tier signs are route-scale. Plaque aspect-ratio checks do not prove
legible rasterized text. Rectangular wear edges may need native adjustment after
inspection; retain failed captures and source receipts if that occurs.

## Integration checks to record

- Full material coverage: six matched exact names, `sea` intentionally preserved,
  zero unmatched names; actual base/normal/packed-data references resolved.
- Counts at Full: 52 panels, 18 signs, five pockets / 32 motes before any common
  detail-level filtering. Off/Low behavior is the shared binder's API; record its
  actual counts and confirm no accumulated nodes after reapply or map swaps.
- All archive/pump jambs, polar doors, dish apertures and real cover silhouettes
  stay readable in normal gameplay, with UI at wide and compact presets.
- No lit mineral/salt/frost wallpaper: ordinary wear panels must remain restrained
  and the diagnostic readouts localized to the named actual equipment.
- Record renderer, viewport, actual process-frame cadence and observed counts.
  Software renderer capture cadence is not GPU FPS. No budget number is a
  performance result.
- Teardown/reload: original accepted materials restored after cleanup, no mutable
  mesh pollution across stages/maps; report actual shared-binder diagnostics.

The separate candidate interior build must repeat its own geometry/visual gates
and revalidate profile hosts before promotion. This finish does not grant that
promotion or provide a production claim for the source-only equipment recipe.
