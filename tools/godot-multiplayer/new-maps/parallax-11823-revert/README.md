# Parallax saltstone face 11823 — bounded revert decision package

Source-only. Branch `spacebunny/parallax-11823-20261005` from
`feature/relay-campaign`. This directory decides one question: whether the
approved AA sign change on Parallax saltstone face 11823 — inherited unchanged by
AC — should stand, be accepted with a qualification, or be reverted.

**No artifact, master, receipt, sidecar, capture, registry or promotion state is
written. No Godot, Blender, importer or renderer is started.** Every revert
candidate is built in memory; the revert diff is emitted as a file that nothing
here applies; AC stays exactly as it is.

## Files

| file | role |
| --- | --- |
| `revert_proposal.py` | the decision package: corner derivation, revert measurement, visual significance, render-feasibility audit, patch emission |
| `proposed_successor_contract.py` | the **proposed** successor step, as reviewable source. Not wired into any pipeline |
| `PROPOSED_README.md` | the same proposal's scope note, as the pipeline file it would be |
| `revert-11823-successor.patch` | a real unified diff that would place those two files under `revisions/districts-v5-saltstone-green-revert/`. **Emitted, never applied** |
| `face-11823-revert.json` | the report |
| `test_revert_proposal.py` | 47 tests |

Nothing is copied from, and no dependency is added to, the committed
`appearance-contract.json`. That file is an integrated artifact of
`parallax-tangent-provenance` and is left untouched.

## What it derives

The reviewed corner set, the X/AA/AC tangent values and the byte layout, all
re-read from committed bytes through the committed parsers
(`classify_records`, `appearance_contract`, `districts-v4-tangent.contract`) and
hash-verified against X `6356cf89…`, AA `95e9da98…` (re-derived from committed X)
and AC `0903dc4f…`.

The reviewed face is mesh 9 face 11823, vertices 24049/24050/24051, `TANGENT`
accessor 48, exclusive to that one face, `N = (0,1,0)`, area
0.09058172586082947 m², `uvJacobian` −0.04529086293041473, `normalScale` 0.4.

## What it measures

Three revert shapes, each built in memory and each classified and
containment-checked:

| candidate | bytes vs AC | bytes vs X | spec-invalid | admissible |
| --- | ---: | ---: | ---: | --- |
| `R1_uniform_w_plus1` | 3 | 66 | 0 | yes |
| `R2_mixed_w` | 2 | 67 | 0 | yes, but mixes handedness inside one triangle |
| `LITERAL_X_bytes` | 5 | 64 | **1** | **no** — reinstates the spec-invalid zero tangent |

The appearance consequence, at the reviewed strength: the two comparable
corners reverse green exactly 180°, move the world normal 4.90° / 5.59°, and
raise the AC01 directional diffuse term 7.6% / 9.1%. The whole reviewed face is a
37.7 m needle about 4.8 mm wide — 6.4 × 10⁻⁷ of the saltstone surface — and none
of the twelve committed probe cameras resolves it.

## Render feasibility

Audited against the committed `godot/tests/new_maps/parallax_glyph/AC01` harness
by reading its own literals. The verdict is **not feasible**, with the failing
preconditions and the missing fixture named in `face-11823-revert.json` under
`renderFeasibility`.

## Reproduction

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/godot-multiplayer/new-maps/parallax-11823-revert/revert_proposal.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s \
  tools/godot-multiplayer/new-maps/parallax-11823-revert -p 'test_*.py' -v
```

`run()` writes only `face-11823-revert.json` and, if its content changed,
`revert-11823-successor.patch`. It never writes a GLB.