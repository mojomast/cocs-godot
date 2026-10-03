# Helix U artifact review — greenhouse assembly P1

**Corrective source delivered:** `da2e53eb` introduces Helix revision-4's radial,
grounded greenhouse frame with intended attachment checks and future actual-export
proof tools. It is under independent source review along with Parallax/Vesper
successors. U's artifact blocker remains open until a rebuilt successor passes
actual geometry/native review; no U image or result is restamped as corrected.

Independent Astra `ses_efd0e4deaffeke8j2rdXdxtbbn` reviewed `243223d3` and its
source prerequisites. **Helix artifact approval is withheld.** Shared export and
staging corrections are approved for source integration; they are integrated as
`c7cd4331` / `fb2af58d` from `68e3f21e` / `bdef2baf`. Parent passed eight harness
Python, 27 existing Python, one portal-probe Node and one committed-Git shipping
test. The U artifact bundle remains unmerged.

## Confirmed P1: disconnected new greenhouse ribs

`helix-conservatory/recipe-v3.mjs:144–149` defines five new ribs at radius 87 m,
angles 70/76/82/88/94, tangential spans (`−angle − π/2`), spring height Y=24.8
above the Y=16 terrace, and crest Y=39. The actual export faithfully reproduces
those source positions. This is not a transform or perspective error.

After matching the evaluated rib triangles to the GLB and excluding each rib's
own triangles, the reviewer measured distance to all remaining exported geometry:

| Endpoint | Actual position | Nearest other geometry |
|---|---|---:|
| Rib 70 outer | `(42.72351,24.8,77.03338)` | 8.72644 m |
| Rib 94 outer | `(-19.83520,24.8,85.82543)` | 8.72645 m |
| Rib 76 free | `(34.43729,24.8,81.07720)` | 4.63615 m |
| Rib 82 free | `(25.77376,24.8,84.23273)` | 4.76727 m |

Six of ten endpoint centers lack adjoining geometry; four intersect other new
ribs. Both outer cross-sections remain completely disconnected by over 8 m.
These thick upper grey arches are absent from the accepted-before view. The
thinner crossed framework is inherited and is not a newly introduced defect.

The original Astra producer owns the source-only corrective assembly, alongside
Parallax/Vesper repairs. It must explicitly connect ribs, spring supports and
ridge/longitudinal members, verify intended attachments and ground support, and
match any accessible supports with authority collision/clearance. Preserve useful
detail and all U attempts. Actual rebuild/review requires a later grant; V remains
the sole heavy owner. No tolerance change or rib deletion satisfies this finding.

## Independently supported technical results

- 157,166 actual triangles; totals remain advisory. All 5,240 decorative meshes'
  100,874 planned triangles match the export.
- Complete evaluated geometry matching preserves oriented positions, materials
  and multiplicity. All 270 new components are accounted for; 256 closed
  components have positive signed volume. Maximum bounds deviation: 0.026453 m.
- Actual normals are finite/unit-length within approximately `1.4e-7`; tangents
  are finite with valid handedness. Checked nondegenerate faces do not oppose
  their exported normals. Six zero-area font triangles remain a minor glyph issue.
- Fresh reopen includes a real re-export and evaluated/actual geometry proof.
- Master SHA: `ab879ae4955fb0cdd9c80085a257f7843e52044c4f6751d09efee448b888b457`.
- GLB SHA: `fe3a6912a1c6c1eafdb6266df6f9256d64129bc81637bced2e76c3262cd284dd`.
- Final logs show successful import, 32,763 actual WorldMap capsule checks
  (radius 0.41 m, height 1.7 m) and 16 captures. Routes, navigation, spawns,
  teams, flags, objectives and cameras are sampled.
- All 68 support-seam exceptions require four 5 mm diagonal neighbor hits at
  the intended height; capsule queries remain unchanged. Another 229 actual-GLB/
  authority rays supplement the probes. None tests greenhouse attachment intent.
- Binder retains 46 panels, 13 signs and 48 motes; 18 used materials are preserved,
  and 27 material instances restore correctly. RGBA8 image comparisons execute
  in Godot. Weather traverses without reaching its node cap, but evidence covers
  dry presentation/lifecycle: effects are suppressed during captures.
- Accepted-before uses the accepted authority/art and existing Binder finish.

## Visual and acceptance boundaries

The greenhouse defect appears in overview and player-height images. Grotto's
broad stripes/angular foliage, repetitive botanical surfacing, dense lightwell
silhouettes, the archive's foreground column and crown foliage still need visual/
gameplay-readability review. Static llvmpipe samples around 228–355 ms/frame are
not gameplay performance proof. No final polished-art approval is established.

Gallery: <http://100.125.104.79:8796/helix-u/>. Its separate current review status
now prominently labels **BLOCKED WIP**. All 25 follow-up HTTP/hash checks pass,
and all sixteen original images, manifests and reports remain byte-identical.
Hosted modes, manual review and public promotion remain
pending. Parallax and Vesper retain their separate actual-export blockers.
