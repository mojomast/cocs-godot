# Proposed saltstone face 11823 green revert — UNAPPROVED, UNAPPLIED

Source contract for a new successor revision that would restore X's usable
basis on the three reviewed exclusive corners of Parallax saltstone face 11823.

**Nothing here is applied.** AC (`parallax-districts-v4-glyph-tangents-v1`,
`0903dc4f…`) stays exactly as it is. No artifact, master, receipt, sidecar,
capture, registry or promotion state is written, and no engine, importer or
renderer is started. This file and `contract.py` are the reviewable source; the
unified diff that would place them in the pipeline is
`revert-11823-successor.patch` in the decision-package directory, and nothing
applies it.

## Exact authority

`dependencies` are pinned by hash in the decision package, not here, to keep this
directory inert: predecessor AC GLB `0903dc4f8487ff9011204a63421a398b3f647bd8b5baca4d1552aa67d00a660b`,
original X GLB `6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422`,
reviewed face 11823 of mesh 9 `art.accepted-craft.saltstone.001`, vertices
24049/24050/24051, `TANGENT` accessor 48, authority geometry
`3a5800e89876ebcc741381802def24415d5050651c0d3b831ea8b9ec3b77b4f9`.

## The change

| corner | vertex | X stored | AC | proposed |
| ---: | ---: | --- | --- | --- |
| 0 | 24049 | `(0,0,0,+1)` — **not usable** | `(+1,0,0,−1)` | `(+1,0,0,+1)` |
| 1 | 24050 | `(+1,0,0,+1)` | `(+1,0,0,−1)` | `(+1,0,0,+1)` |
| 2 | 24051 | `(+1,0,0,+1)` | `(+1,0,0,−1)` | `(+1,0,0,+1)` |

Corners 1 and 2 are restored to X's stored bytes exactly. Corner 0 is a
**declared choice, not a restoration**: X stored a zero tangent there, which is
spec-invalid and defines no tangent space at all, so there is no X appearance to
restore and no X basis to reuse. The proposal keeps X's stored `w = +1` and takes
the same usable unit `T.xyz = (+1,0,0)` its two face-mates carry, so the triangle
keeps one handedness. A byte-exact X restore is therefore **rejected by design**:
it would reinstate one of the 17 spec-invalid records AC exists to close.

Byte scope: three 16-byte records inside the 48 BIN positions the AA compiler
already declared for exactly these three vertices, and exactly **three** BIN bytes
change relative to AC — the last byte of each record's `w` float, `0xbf → 0x3f`.
`reviewed_state()` fails closed on a changed predecessor hash, a drifted
accessor layout, drifted face geometry, a vertex that is no longer exclusive to
face 11823, an AC record that is not `(+1,0,0,−1)`, or an X record that is not
the reviewed basis. `revert()` re-runs the AA compiler's own containment checks:
the change is exactly three bytes, it lies inside the 48-byte window, it aliases
no other accessor, and it aliases no embedded image. The container re-parses to
39 primitives / 155,553 triangles.

## What this deliberately does not claim

The revert restores X's *stored basis* on two of three corners. Whether that is
the appearance that should ship is a separate question, and the measured answer
is uncomfortable: at the reviewed `normal_scale` 0.4 the change moves the world
normal by **4.90° / 5.59°** at those two corners and reverses the green
contribution by exactly **180°**, and on the AC01 pinned sun the directional
diffuse term rises **7.6% / 9.1%**. The whole reviewed face is a 37.7 m needle
about 4.8 mm wide — 6.4 × 10⁻⁷ of the saltstone surface — and none of the twelve
committed probe cameras can resolve it. Those numbers are in
`../face-11823-revert.json`; this module does not decide them.

Nothing here claims MikkTSpace validity, a global tangent/green repair, artifact
approval, authored-X appearance acceptance, a render measurement or promotion.
The 4,729 remaining nonorthogonal entries, the 16 singular glyph records and the
five U-reversed corners are untouched and out of scope.

## Re-verification a real revert would still need

A new exclusive successor grant and revision string; a Blender 4.5.14
editable-master build and a **separate fresh-process reopen** proving canonical
byte equality; a fresh native mesh-local proof over all 155,553 faces with the
19 repaired entries and 51 incident occurrences re-mapped, 0 parallel native
corners, and every repaired native frame orthonormal; the frozen R7 native
material field (14 sets) and decoded image channel (39) gate; matched
before/after captures; and manual material appearance acceptance. `ensure_tangents`
may never be used to excuse a basis mismatch.

## Source verification

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s \
  tools/godot-multiplayer/new-maps/parallax-11823-revert -p 'test_*.py' -v
```

`contract.revert()` returns bytes in memory only; no test in that suite writes a
GLB.
