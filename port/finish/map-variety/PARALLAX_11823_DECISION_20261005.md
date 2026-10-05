# Parallax saltstone face 11823 — decision package — 2026-10-05

Source-only. Branch `spacebunny/parallax-11823-20261005` from
`feature/relay-campaign` (base `25c189bd`). Worktree
`/home/mojo/.tmp-on-disk/cocs-walker-snap-compare-af`. The main checkout at
`/home/mojo/.tmp-on-disk/cocs-relay-campaign-20260930` was not touched.

Deliverables:

- `tools/godot-multiplayer/new-maps/parallax-11823-revert/revert_proposal.py`
  (+ `face-11823-revert.json`, `test_revert_proposal.py`, `README.md`)
- `tools/godot-multiplayer/new-maps/parallax-11823-revert/proposed_successor_contract.py`
  and `PROPOSED_README.md` — the **proposed** revert, as reviewable source
- `tools/godot-multiplayer/new-maps/parallax-11823-revert/revert-11823-successor.patch`
  — a real unified diff that would place those two files under
  `revisions/districts-v5-saltstone-green-revert/`. **Emitted, never applied**

**No artifact, GLB, master, texture, receipt, sidecar, capture, registry or
promotion state was written or modified. No Godot or Blender process was
started.** AC `0903dc4f…` is unchanged and its approved three-corner edit is not
rewritten. Nothing was pushed, merged or rebased.

## 1. The re-derived corner set and tangent values

All of this is re-read from committed bytes through the committed parsers
(`classify_records`, `appearance_contract`, `districts-v4-tangent.contract`) and
hash-verified. X is `6356cf89…`; AA is re-derived from committed X by
`districts-v4-tangent.contract.repair` and asserted equal to the pinned failed-AA
`95e9da98…`; AC is the committed `0903dc4f…`.

Reviewed face: mesh 9 `art.accepted-craft.saltstone.001` (node
`kit.authority.saltstone.00`), face **11823**, vertices **24049 / 24050 / 24051**,
`TANGENT` **accessor 48**, BIN layout start `16073596` stride `16`. Each of the
three vertices is incident to face 11823 **and nothing else**. Face state
`fullRank`, `N = (0,1,0)` at all three corners, area `0.09058172586082947` m²,
`uvJacobian −0.04529086293041473`, `dP/du = (+1,0,0)`, `dP/dv = (0,0,+1)`.
UV-derived `w` is `−1` at all three corners. Role `saltstone`,
`normalScale 0.4`, `tilesPerMeter 0.5`, `OpenGL +Y`, normal map
`salt-limestone-normal.png` SHA-256 `203df36b…` byte-identical to the committed
Moth pack PNG and to the AC-embedded image bytes.

| corner | vertex | position | exported UV | X basis | AA / AC basis | X spec verdict |
| ---: | ---: | --- | --- | --- | --- | --- |
| 0 | 24049 | `(68.778976, 24.0, −66.255379)` | `(35.368114, −32.568043)` | **`(0,0,0,+1)`** | `(+1,0,0,−1)` | `zeroTangent+nonUnitTangent+degenerateFrame` |
| 1 | 24050 | `(35.520397, 24.0, −84.056709)` | `(18.738825, −41.468708)` | `(+1,0,0,+1)` | `(+1,0,0,−1)` | valid |
| 2 | 24051 | `(35.500000, 24.0, −84.062180)` | `(18.728626, −41.471443)` | `(+1,0,0,+1)` | `(+1,0,0,−1)` | valid |

BIN bytes, little-endian `<4f`:

```
v24049  X 0000000000000000000000000000803f   AC 0000803f0000000000000000000080bf
v24050  X 0000803f00000000000000000000803f   AC 0000803f0000000000000000000080bf
v24051  X 0000803f00000000000000000000803f   AC 0000803f0000000000000000000080bf
```

X has 17 spec-invalid records; AA 16; AC **0**. Corner 0 is the extra one in X.
AC's baseline classification is unchanged: 314,178 spec-valid-but-derivative-
disagreeing, 4,887 unaffected, corner disagreements 452,050 / 5 / 452,048.

**Corner 0 has no usable X basis.** X's record there is the zero tangent, so
`cross(N,T)*w` is the zero vector and the tangent space does not exist. This
matters for any revert and is the single most consequential fact in this
document: X cannot supply appearance for that corner, because X had none.

## 2. The source-level revert proposal

The three records were written by `districts-v4-tangent.contract.repair` (X→AA)
and inherited unchanged by `districts-v4-glyph-tangents.successor` (AA→AC). AC is
a closed, reviewed production attempt, so a revert **cannot** be an edit to
either compiler. It has to be a new revision that consumes AC bytes and writes
the basis back. That is what `proposed_successor_contract.py` is, and
`revert-11823-successor.patch` is the real diff that would place it in the
pipeline. It is not applied.

Three shapes were built in memory and measured, not asserted:

| candidate | basis | bytes vs AC | bytes vs X | in the 48-byte window | aliases other data | spec-invalid | admissible |
| --- | --- | ---: | ---: | --- | --- | ---: | --- |
| **R1 uniform `w=+1`** | `(1,0,0,+1)` ×3 | **3** | 66 | yes | no | **0** | **yes** |
| R2 mixed `w` | `(1,0,0,−1)`, `(1,0,0,+1)`, `(1,0,0,+1)` | 2 | 67 | yes | no | 0 | yes, with a caveat |
| literal X bytes | X's three records | 5 | 64 | yes | no | **1** | **no** |

The recommended shape is **R1**. It restores corners 1 and 2 to X's stored bytes
*exactly*, and for corner 0 keeps X's stored `w = +1` while supplying the usable
unit `T.xyz = (1,0,0)` its two face-mates carry, so the triangle keeps one
handedness.

**A byte-exact X restore is rejected by design.** It reinstates one spec-invalid
record — the exact class of defect AC exists to close — and `LITERAL_X_bytes` is
reported inadmissible for that reason, measured rather than asserted.

Byte scope: three 16-byte records inside the 48 BIN positions the AA compiler
already declared for exactly these three vertices. Exactly **three** BIN bytes
change relative to AC, at absolute positions `16458395`, `16458411`, `16458427` —
each the last byte of one record's `w` float, `0xbf → 0x3f`. Nothing else in the
container, scene, geometry, indices, materials or embedded images moves; the
container re-parses to 39 primitives / 155,553 triangles.

Classification consequence, which is the cost of the revert:

| metric | AC | R1 | R2 | literal X |
| --- | ---: | ---: | ---: | ---: |
| spec-invalid | 0 | 0 | 0 | **1** |
| spec-valid-derivative-disagreeing | 314,178 | 314,181 | 314,180 | 314,180 |
| `wSignDisagrees` | 452,050 | 452,053 | 452,052 | 452,053 |
| `storedBinormalOpposesDV` | 452,048 | 452,051 | 452,050 | 452,050 |
| saltstone unaffected | 3 | 0 | 1 | 1 |

The revert moves these three records *back into* the raw-derivative-disagreement
class, i.e. it restores X's own near-global convention for them. That is the
point — but it also means the revert makes the three records disagree with the
derivative-basis policy that AA and AC were built to satisfy. R2 avoids the
disagreement on corner 0 by leaving AC there, at the cost of one triangle
carrying two handednesses, which is an interpolated sign flip mid-face. R1 is
preferable: one handedness per face, at the price of three derivative
disagreements that X already had.

### What a rebuild and native re-verification would require

`proposed_successor_contract.revert()` is source arithmetic over committed AC
bytes. It is not a build. A real revert would need, at minimum:

1. a **new exclusive successor grant and revision string**
   (`parallax-districts-v5-saltstone-green-revert-v1`); AC's grant stays closed
   and its receipts stay immutable;
2. a **Blender 4.5.14 editable-master build** and a **separate fresh-process
   reopen** proving canonical byte equality, both under that grant — no Blender
   4.5.14 is reachable in this environment;
3. a fresh **native mesh-local all-face proof**: all 155,553 strict equivalent
   faces, the 19 repaired entries and 51 incident occurrences re-mapped with
   source/native correspondence, 0 parallel native corners, and every repaired
   native frame orthonormal. `ensure_tangents` may never be used to excuse a
   basis mismatch;
4. the **frozen R7 native material gate** — 14 material field sets and 39 decoded
   image channels;
5. **matched before/after captures** and **manual material appearance
   acceptance**. The native proof is mesh-local; native world transforms would
   still not be recorded.

None of that is claimed, started or approximated here.

## 3. Visual significance of the 4.90° / 5.59° deviation

All three corners address the **identical** texel under both pinned image
origins, so the difference is the basis, not the image.

| corner | vertex | sampled RGB | column/row | X→AC world angle (Blender) | (Godot) | max component error | green angle |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: |
| 0 | 24049 | `143,132,254` | 188 / 221 | not comparable — X has no frame | — | — | — |
| 1 | 24050 | `93,141,250` | 378 / 272 | **4.8981°** | **4.9058°** | 0.0855 / 0.0856 | **180.0°** |
| 2 | 24051 | `125,143,254` | 373 / 270 | **5.5852°** | **5.5847°** | 0.0974 / 0.0974 | **180.0°** |

Against the **committed AC01 sun** (`staged.gd:151`, rotation
`(−44,−30,0)`, energy 0.6, ambient 0.45; nearest staged omni 47.6 m away against a
20 m range, so the sun is the only directional contributor here):

| corner | N·L, X basis | N·L, AC basis | absolute delta | relative | linear radiance delta |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.702522 | 0.755762 | **+0.053240** | **+7.58%** | +0.0115 |
| 2 | 0.666287 | 0.726990 | **+0.060703** | **+9.11%** | +0.0131 |

So the deviation is **not** negligible in shading terms: it brightens the
directional diffuse response by 8–9% at those two corners, under both pinned
strength models.

It is, however, bounded by two facts about the surface:

**The reviewed face is a needle.** Longest edge 37.744 m, shortest edge
0.0211 m, mean width 0.0048 m, total area 0.0906 m². That is
**6.44 × 10⁻⁷ of the saltstone surface** (140,706 m²) and 1.42 × 10⁻⁷ of the whole
scene (637,139 m²). Nothing here is about a visible floor patch; it is about a
37.7 m long, 4.8 mm wide sliver.

**Over the face's own UV footprint**, sampled barycentrically on a 64× grid
through the pinned bilinear REPEAT filter (2,145 samples, green range
84.6–185.5, 99.6% non-neutral):

| model | min | median | mean | p90 | max | >1° | >5° | >10° |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Blender node | 0.0008° | 1.82° | 3.55° | 10.41° | 21.57° | 62% | 26% | 10% |
| Godot mix-depth | 0.0008° | 1.83° | 3.55° | 10.40° | 21.56° | 62% | 26% | 10% |

Over the **whole committed 512² salt-limestone normal map** the same reversal
reaches median 1.98°, p90 12.18°, **max 31.52°**. The two reviewed corners
(4.90°, 5.59°) sit near the *low* end of that distribution — the sampled green
there is only mildly non-neutral. A green reversal on this material is therefore
a much larger effect in general than these two particular texels show.

## 4. Render feasibility: not feasible, and here is exactly why

Assessed against the committed parity-glyph harness at
`godot/tests/new_maps/parallax_glyph/AC01/`, by reading its own literals rather
than by running it. The verdict is **NOT FEASIBLE**. Nine preconditions fail; the
first is decisive on its own:

1. **`harnessSupportsThreeVariants` — the harness expresses exactly two variants.**
   `capture.gd` iterates `for candidate: bool in [false,true]`
   (`failed-AA-before`, `candidate-runtime-after`) and asserts
   `records.size()==(2 if selected!="" else probes.cameras.size()*2)`. A third
   variant — X, or the proposed revert — cannot be expressed without editing a
   frozen staged script.
2. **`stagedScriptsAreRewritable`** — `staged.gd` asserts
   `FileAccess.get_sha256(path)` against `manifest.json["files"]` for every staged
   file, so editing `capture.gd`, `staged.gd` or `probes.json` invalidates the
   committed AC01 stage.
3. **`stageIsRerenderable`** — `stage.prepare()` calls `mkdir(exist_ok=False)`
   and `capture.gd` refuses an existing capture path or receipt.
4. **`committedCapturesDoNotBlockRerun`** — 24 capture PNGs already sit under
   `AC01/captures/`, each asserted absent before writing.
5. **`noNewGrantOrBuildReceiptNeeded`** — `stage.prepare()` requires an active
   exclusive successor grant plus actual `build-report.json` and
   `reopen-report.json` artifact/master hashes.
6. **`noRealUidSidecarCheck`** — `stage.check_sidecar` requires
   `importer="scene"`, a generated `uid://`, `force_disable_compression=true`
   and `generate_lods=false`.
7. **`projectImportCachePresent`** — this worktree has no `godot/.godot` import
   cache, so real generated-UID, full-precision, LOD-off sidecars would need a
   first editor import of the whole 709 MB project.
8. **`blenderAvailable`** — no Blender 4.5.14 is reachable, and `build.py`
   requires it to derive a new editable master and canonical bytes.
9. **`committedCamerasResolveTheFace` — no committed camera can see this face.**
   Of the twelve AC01 probes, four have the face in frustum and three are front
   facing, but the sets barely intersect: only `overview` is both, at 335 m. It
   projects the 4.8 mm needle to **0.0076 px**. The best committed width anywhere
   is `pump-interior` at 0.317 px, and that camera is out of frustum. At the
   widest committed fov (68° vertical, 720 px) the face reaches **one pixel only
   at 2.562 m** — inside its own 37.7 m length. A close-up needs a new probe
   camera and therefore a new stage.

### The missing fixture

To render X vs AC vs proposed revert with this harness, all of the following
would have to exist first:

- a new **write-once stage directory**; AC01 is populated and hash-pinned;
- a **third staged GLB variant** with its own manifest entry — which means a new
  artifact, and the X variant is not staged at all (only failed-AA is);
- a real **generated-UID, full-precision, LOD-off `.import` sidecar** for that
  variant, from an editor import pass over a project with no import cache here;
- a **new probe camera in `probes.json`** framing face 11823, at ~2 m or closer;
- a **`capture.gd` that iterates three variants** instead of `[false,true]`;
- an **actual artifact and editable master** for the revert — a Blender 4.5.14
  build plus a fresh-process reopen under a new exclusive successor grant.

That is a new production stage, not a render. **No render set was produced**, and
none was attempted.

A bounded alternative does exist and is worth naming: a purpose-built static
fixture — a minimal scene holding only the saltstone role plane plus the
committed normal map, one camera framing face 11823, and a frozen X / AC / revert
basis triple. It would be quick and it would demonstrate the basis arithmetic.
But it is a new fixture rather than the parity-glyph harness, and it would
demonstrate basis arithmetic rather than scene appearance, so **it could not
settle final art acceptance either**. Building it is out of scope here.

## 5. Options

| option | what it means | cost | evidence | verdict |
| --- | --- | --- | --- | --- |
| **A. Revert** (R1) | new successor restoring X's `w=+1` on the three corners; 3 BIN bytes; corners 1–2 byte-identical to X | new grant + revision, Blender 4.5.14 build + fresh reopen, full native re-proof, new captures, manual acceptance. Loses AC's 3-derivative-agreement and reintroduces 3 `wSignDisagrees` | 4.90°/5.59°, 180° green reversal, +7.6%/+9.1% diffuse on a 0.0906 m² needle | available and exactly specified, but unbuildable here and unrenderable here |
| **B. Accept with qualification** | keep AC; record the measured non-preservation, the quantified bound, and the unrendered status as accepted open risk on one 0.09 m² needle | no artifact work. Requires the acceptance to name the risk explicitly rather than defer it | same measurements, plus: 6.44 × 10⁻⁷ of saltstone, ≤0.32 px in every committed camera, one pixel needs 2.56 m | **recommended** |
| **C. Render-gated** | defer until a controlled close-up decides | blocked: nine harness preconditions fail; needs a whole new stage and an artifact for a third variant | `renderFeasibility` block | not available; becomes reachable only under option A's build anyway |

## 6. Recommendation

**Accept with qualification (B).**

The reasoning, in order of weight:

1. **The defect is real and is not wished away.** The sign change does reverse
   green exactly 180° and does move the world normal 4.90°/5.59°. "Invisible"
   would be false, and this document does not claim it.
2. **The surface it touches is negligible and unobservable in practice.** The
   reviewed face is 0.0906 m² — 6.44 × 10⁻⁷ of saltstone — and is a 37.7 m × 4.8 mm
   sliver. Every one of the twelve committed cameras projects it below a third of
   a pixel, and one pixel requires standing 2.56 m away. No player view, no
   supported inspection camera and no existing capture can resolve it.
3. **The revert is not free.** R1 is fully specified and byte-bounded, but it
   requires a new grant, a new revision, a Blender build with a fresh reopen, a
   complete native re-proof, new captures and manual acceptance — to change three
   bytes on a sliver no camera can see. That is a poor trade, and it is the reason
   not to pick A on principle.
4. **The render gate is not an escape hatch.** C is blocked on nine independent
   preconditions, and unblocking it costs the same new-stage work as A. Choosing
   C is choosing A's cost with A's uncertainty added.
5. **The decision is bounded, reversible and recorded.** Option B keeps AC's
   closure of all 17 spec-invalid records intact, changes nothing, and files the
   measured cost so the next reviewer starts from numbers rather than from the
   open question this task inherited.

What the acceptance must state, verbatim, so it is not a deferral dressed as a
decision:

> Parallax AC `0903dc4f…` retains its approved three-corner saltstone face 11823
> sign change. Source measurement establishes that this change does **not**
> preserve X's authored appearance on that face: at the two corners where X stored
> a usable basis, the world normal moves **4.90° / 5.59°** at the reviewed
> `normalScale` 0.4 under both pinned strength models, the normal-map green
> contribution reverses exactly **180°**, and the AC01 pinned sun's directional
> diffuse term rises **7.6% / 9.1%**. The third corner has no X basis to preserve,
> because X stored a spec-invalid zero tangent there.
>
> This is accepted as a bounded, quantified risk on the basis that the reviewed
> surface is **0.0906 m²**, a 37.7 m × 4.8 mm sliver equal to **6.44 × 10⁻⁷** of the
> saltstone surface, and is projected below **0.32 px** by every one of the twelve
> committed AC01 probe cameras, reaching one pixel only at **2.56 m**.
>
> **No controlled close-up render of this face exists or was attempted.** The
> committed parity-glyph capture harness cannot express a third variant, cannot be
> re-rendered in place, and has no committed camera that resolves the face.
>
> This acceptance is **not** artifact approval, **not** authored-X appearance
> acceptance for the face as a whole, **not** a render measurement, **not**
> universal UV/Mikk basis validity, and **not** a promotion.

## 7. Exact next steps

1. Record the qualification above against queue item **Q1** of
   `port/finish/map-variety/BLOCKERS_EFFICIENCY_20261005.md` §2, alongside the
   integrated `PARALLAX_TANGENT_CLASSIFICATION_20261005.md`, so the two are read
   together. Do not edit the integrated classification or appearance-contract
   documents.
2. Keep `revert-11823-successor.patch` **unapplied** as the standing, exactly
   specified option. It is a reviewed diff, not pending work: nothing in this
   task authorises a build.
3. If a reviewer later wants render evidence, do **not** extend the AC01 stage.
   Build a separate purpose-built static fixture as described in §4, and treat
   its result as basis-arithmetic demonstration only — **not** art acceptance.
   Scene appearance still needs a real stage under a real grant.
4. Leave the five U-reversed corners and the intended tangent direction there
   untouched. They are a separate, still-unanswered question that this package
   does not close.
5. If option A is ever authorised, follow the seven steps in §2 in order; the
   native gate must be re-run in full, not partially.

## 8. Scope statement

- **No artifact change.** No GLB, master, texture, receipt, sidecar, capture,
  registry or promotion state was written or modified. Every revert candidate was
  built in memory; `psc.revert()` returns bytes and writes nothing, and its tests
  assert that.
- **No native or render proof.** No Godot, Blender, importer or renderer was
  started. Everything is static source arithmetic over the two pinned shader
  expressions and the committed bytes, plus a frustum/geometry projection
  against the committed probe cameras. It is not renderer equivalence and not a
  sampled-pixel measurement; the diffuse figures are analytic.
- **No native claim.** The in-memory revert is not an artifact, not an import, not
  a native gate pass, and asserts no native world transform.
- **No promotion or acceptance.** Nothing is promoted, catalogued or accepted.
  AC stays exactly as it is; its approved three-corner edit is not rewritten,
  broadened or revoked by this document.
- **AC's own boundary retained.** All-face PASS remains faithful import of a
  bounded source, not universal UV/Mikk validity. The 4,729 remaining
  nonorthogonal entries, the 16 singular glyph records and the five U-reversed
  corners are untouched. The withdrawn shading-defect inference of `8c43b112` is
  not revived: the near-global raw derivative disagreement remains a measurement,
  not a defect.
- **Pinned bytes used.** X `6356cf89…`, AA `95e9da98…` (re-derived from committed
  X and hash-matched), AC `0903dc4f…`, salt-limestone normal `203df36b…`. A
  missing source is reported by the code and pinned by its tests, never
  fabricated.
- **The patch is not the work.** `revert-11823-successor.patch` is checked with
  `git apply --check --cached` against a scratch index so that it would apply,
  and the worktree is asserted afterwards to contain no
  `districts-v5-saltstone-green-revert` directory.

## 9. Reproduction

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/godot-multiplayer/new-maps/parallax-11823-revert/revert_proposal.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s \
  tools/godot-multiplayer/new-maps/parallax-11823-revert -p 'test_*.py' -v
```

## 10. Tests

`test_revert_proposal.py` — **48 tests**, all passing (73.9 s), zero failures,
zero errors, zero skips.

*Synthetic (18)* — every containment guard in
`proposed_successor_contract.plan` / `validate_rows`, driven over hand-built BIN
blobs and accessor tables so a pass cannot be vacuous: an unexpected AC record, an
unexpected X record, a vertex that picked up a second incident face, a wrong
corner/vertex set, a corner-0 record that is *not* the reviewed X zero tangent, an
over-wide byte delta, an accessor alias and an image alias are each **rejected**;
and the guards are shown *not* to be blanket rejections, because a disjoint decoy
accessor and an image starting one byte past the window are both accepted.
Together they pin that exactly three bytes move and each is the last byte of one
record's `w` float. The harness audit is driven from synthetic harness text, and
a `feasible` verdict is reachable only when every blocker is absent, so it cannot
be produced by accident.

*Committed-source (26)* — the real pinned X/AA/AC bytes assert every number in
this document: the corner set, the three bases per label, corner 0's spec verdict,
the face geometry and normal settings, the 180° green reversal, the
4.8981/4.9058/5.5852/5.5847° world angles to 9 decimals, `sameTexel` at all three
corners, the 8–9% diffuse deltas, the needle geometry and its 10⁻⁷ fractions, the
footprint and whole-map deviation distributions, the empty camera-resolving set,
the 2.562 m one-pixel distance, the named render blockers, all three revert
candidate measurements, the classification deltas, the in-memory proof's byte
positions, AC's zero spec-invalid baseline, run determinism, and the report's own
scope and boundary claims.

*Guard (4)* — the emitted diff is a two-file new-file diff, its added content
matches the proposal sources line for line, it touches no existing file, and it
applies cleanly under `git apply --check --cached` to a scratch index while the
worktree is asserted afterwards to contain no `districts-v5-saltstone-green-revert`
directory.