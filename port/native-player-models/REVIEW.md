# Recovered operator candidate — lead review

Decision: **preserve and commit the candidate; HOLD gameplay integration**.
Review baseline: `d3062057cbfe433b8d953f1dc6fd51398b05ba1f`.
Machine-readable summary: `evidence/recovery-review.json`.

## Visual findings

The lead directly opened all 40 PNGs in `evidence/render-1790052439614620418/`:
baseline/candidate at 960×640 and 1280×800, front 3/10/25m, side, back,
perspective, top, underside, attachment and silhouette. These are recovered
matched fixtures, not new screenshots or a human playthrough. The fresh live
observer screenshot and both fresh release-preview screenshots were also opened.

- **Close-range improvement:** beveled helmet edges, separate chest plates,
  tapered limbs, knee bands and boots read as authored armor rather than stacked
  boxes. Leg separation remains clear. Top/underside/side views show closed
  geometry without an obvious missing face. Side/back packs have credible volume.
- **Proportion concern:** the tall exposed neck and small separated torso/shoulder
  plates give the models a thin, toy-robot character. This is coherent stylization,
  but less substantial than the operator names imply, particularly Bulwark.
- **Variant recognition HOLD:** Outrider's narrow/asymmetric upper body is the
  clearest close-range distinction. Warden and Bulwark are too similar to identify
  confidently at 10m, and all three lose most identity detail at 25m. The static
  lineup also gives outer actors oblique perspective, so silhouette differences
  cannot all be attributed to geometry. A future same-position/same-team
  comparison should isolate the variants.
- **Team cue HOLD:** red/blue shell color stays readily apparent; one-/two-stripe
  chest marks are visible close up but become difficult to count at 10m and are
  not a reliable non-color distinction at 25m. Side/back visibility is weak.
- **Grip:** front, side and attachment views show the supporting forearm crossing
  the waist toward the weapon; the hands are no longer simply unrelated hanging
  blocks. The pose remains rigid and the weapon/hand assembly visually crowded.
  Static contact is plausible; animated grip and aim are untested.
- **Map context:** the fresh Meridian image shows a readable blue actor and light
  knee/hand details against dark pavement. It is one controlled observer view,
  not broad dark-map contrast or first-person gameplay acceptance.

The browser-service failure is no longer an inspection blocker. These findings
are a lead image review, not independent human art/usability approval.

## Rendering cost

Recovered `METRICS.json` and raw samples remain historical, unchanged evidence:
2,760 triangles / 46 meshes versus 312 / 26. At 1280×800 with 32 synthetic actors
on llvmpipe, median frame interval was 14.865ms versus 6.153ms (~2.42×), and total
draw calls were 1,459 versus 819. Candidate p95 was 16.995ms. This is enough cost
to warrant optimization before replacement; it is not a hardware performance
failure or a complete-game frame budget measurement. No new timing claim is made.

Recommended next implementation: batch static parts sharing a material while
preserving Helmet/Muzzle semantics, identity/material isolation and stable actor
instances. Consider distance LOD after measuring batching. Strengthen major
helmet/shoulder/pack silhouettes and team marks rather than adding tiny parts.
Recheck all bounds, numerical invariants, live lifecycle, matched views and
editor-free resources after those changes.

## Fresh verification

| Evidence | Result |
|---|---|
| `1790061184437178759/` | Two clean deterministic recipe/geometry builds; 112,013 checks each; current inherited entity (72 checks), presentation and lifecycle gates pass |
| `live-1790061203072908510/` | 1,800 snapshots; 3,430 remote movement and 2,440 yaw transitions; source results at 60.0166666666645; one clean restart and old-instance destruction |
| `release-1790061295968348521/` | Linux preview exported/extracted; source staging removed before launch; both requested sizes rendered and inspected; exit 0 |

Recovered model/test input hashes and canonical geometry match the fresh run.
The live authority and Xvfb exited zero; loopback port 43401 was confirmed closed.
Fresh release Xvfb also exited zero. Godot's llvmpipe V-Sync warning is retained.
Python emitted a tar-extraction deprecation warning in the release runner; the
runner validates its own two regular-file archive members before extracting.

The original final unstaged patch/run could not be recovered. `RECOVERY.json`
records the 230 available staged files, their Git blob IDs and hashes. The new
zero-context patch is checked using `--unidiff-zero`; it differs from the reported
missing final hash because it was regenerated against current package line 167.
The model source itself was not modified. Historical failures remain intact.
`git diff --cached --check` and the final zero-context patch application check
both passed before committing the recovered delivery.

No full aggregate or complete Node-backed package claim is made for this held
candidate. The 87-gate published runtime continues using the existing actor.
