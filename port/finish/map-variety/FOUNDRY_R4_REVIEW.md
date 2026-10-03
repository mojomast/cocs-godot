# Foundry R4 independent review — rejected

Worker commit `6ff4079e`, foundation `190fa2a2`; reviewer Astra
`ses_efd30e1f6ffeLbhHTPoh266kZW`. Review used source/artifacts only, with no engine,
import, rendering or server. Complete candidate remains **unmerged/unapproved**.

## Confirmed exported defects

- `revision4/author.py:64–68`: `strut()` passes a world midpoint to `Kit.prism`,
  which bakes it into vertices, then rotates the object around the origin. Actual
  sloping-hopper pieces occur at heights 39–61 m instead of 2.3–7.5 m. G1 legs,
  G2 ribs, G4 trestles and G5 sloping members share this path. Model about local
  zero, then apply a rigid placement. Recheck roof anchors: planned height 32
  differs from source roof hits 24.91 and 22.126; one leg is outside the roof.
- `author.py:70–81`: Z-axis drums have inward winding and exported normals.
  Radius-2/height-3 signed volume is −37.082039 for Z, +37.082039 for X. Actual
  chimney, furnace casing and bunker surge components have zero outward-facing
  triangles/normals in the inspected sets. Double-sided materials do not repair
  topology. X-running conveyor rollers also incorrectly use vertical cylinders.
- Visible bodies extend beyond authoritative collision. New bunker wall additions
  stop at 2.25 m and original hopper solids at 3.5 m, while visible new bodies
  reach 6.05/8.6 m with higher caps. Ground-level tipple jambs lack matching
  collision. The transverse conveyor ignores accepted shear `z=center+.14*x`.

Actual exported-art versus `rayWorld` counterexamples:

| Origin | Direction | Max distance | GLB hit distance | Authority hit |
|---|---|---:|---:|---|
| `(-139,5.5,-112.48)` | +X | 14 | 3.200409 | None |
| `(-57,4,-101)` | +X | 14 | 2.709999 | None |
| `(44,2,-30)` | +X | 2.2 | 1.000000 | None |
| `(56,2,-30)` | +X | 2.2 | .779999 | None |
| `(-45,33,-6.5)` | +Z | 5 | .800000 | None |

The 1,026 ground probes and six low bunker rays check specific authority
properties, not visual G1–G6 collision agreement.

## Integration and evidence findings

- Accepted `GM / orange` base RGB `.8,.19,.025` becomes `.8,.07,.005`;
  emission factor `1,.2375,.03125` becomes `1,.05,.00125`; roughness `.53`
  becomes `.5`. Checking only nonzero emission does not establish preservation.
- Native stills use standalone GLB plus simple sun/ambient. They do not exercise
  runtime weather/dressing, whose profile requires the accepted geometry hash.
- Camera-under-floor suspicion was **rejected**: sampled eyes are above source
  support. Do not attribute image artifacts to an underground camera.
- Export report incorrectly says authority is unchanged. R4 adds 48 wall triangles
  (2,320 → 2,368); surfaces/routes/nav nodes remain unchanged.
- Blender “before” images omit new geometry but retain new materials. They are
  geometry-only comparisons, not accepted-runtime finish comparisons.
- R release records are three empty matching-process scans with available locks,
  without owned-group lineage or timestamps. Do not strengthen that claim.
- GLB is 13,363,544 bytes, exceeding its 7,000,000-byte target by 90.9%; no parent
  budget exception is granted.
- Shared `receipt.py` calls `digest(None)` for supported `normal:false` bindings.
  Foundry's enabled normals avoid that branch; generic coverage needs correction.

## Independently passing evidence

Source generation/check receipts, export verifier, built pack receipt and seven
focused tests passed. GLB has 111,454 triangles, 16 mesh/primitives, ten textured
PBR materials plus one emissive material and 30 embedded images. Albedo conversion,
normal hashes, extracted PNGs and packed roughness are verified (maximum roughness
pixel error zero). Master/GLB hashes and all 22 PNG hashes/dimensions match their
records. Shared curved-rib winding has positive volume and passes outward-face
testing. These facts do not approve the defective complete map.

## Corrective ownership

Astra reviewer owns implementation and actual rebuild under exclusive
**`MOTH-BLENDER-20261003-S`**, from a fresh worktree at `6ff4079e`. Produce revision
5; preserve R4 masters/exports/receipts/screenshots as the rejected attempt. No
public map promotion or package export is authorized.

Parent pre-grant check found the shared nonwaiting lock available. The sole
matching Godot process was the unrelated environment viewer (`pid 2598700`,
`pgid 2598689`, started September 21, `/opt/viewer/godot-bin`), outside S ownership
and left untouched. S must record bounded owned groups, exact input identities
and timestamped empty audits before explicit release.

Required corrective evidence: actual exported placement/normals, targeted
visual/authority ray and capsule probes, preserved luminaires, truthful metadata
and new screenshots. Hosted modes, human approval and final packaging remain
separate obligations.
