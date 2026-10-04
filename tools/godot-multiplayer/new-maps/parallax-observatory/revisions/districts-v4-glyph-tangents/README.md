# Glyph tangent successor — source contract for independent review

Parent `1c661b95`; namespace `districts-v4-glyph-tangents`. The sixteen-entry
geometric policy was reviewed previously; **this production contract still needs
independent review and an explicit new grant**. No production attempt has run.

## Exact authority

`dependencies.py` pins actual AA GLB `95e9da98…3141cd5`, packed master
`2e661784…c0373d`, original X GLB/master names and identities through the frozen
AA compiler, and geometry `3a5800e8…7b4f9`. `dependency-lock.json` pins reused
source helpers and staging templates. AA's original compiler, recipe, failed
gate, census and 141-file archive remain immutable.

`successor.compile_art()` requires exact AA bytes. It applies the approved policy
to accessors **165 and 170**, vertices **1026, 1027, 1038, 1039, 1050, 1051, 1062,
1063** each, then writes distinct revision/provenance JSON metadata in memory.
Every one of 48 incidents must meet the reviewed rank-one zero-UV-edge policy;
all three incident candidates at each entry must agree. Unknown/changed input
fails before repair. Tangents become ±Y, retaining w=-1 and positive observable
V alignment. This is a geometric fallback for singular UVs, not MikkTSpace or a
unique UV derivative solution.

`verify_art()` requires deterministic byte equality, 64 changed BIN bytes within
256 allowed positions relative to AA, and 69 changed bytes within 304 positions
relative to X. The three original saltstone records are retained. All other BIN,
geometry, normal, UV, index and material payloads are preserved. No new GLB is
written by source tests. Artifact/master identities in `queue.json` are null.

## Editable master build and fresh-process reopen

`build.py` is inert on import. Under a future explicit receipt, it opens the
actual pinned AA packed master and checks original scene recipe, original text
recipe and original compiler text before deriving a new master. New text names
`PARALLAX_GLYPH_RECIPE.json`, `PARALLAX_GLYPH_COMPILER.py`, and
`PARALLAX_GLYPH_POLICY.py` retain AA provenance separately. The recipe includes
the new compiler SHA, all source file hashes and frozen dependency hashes.

Build selects the exact 39 named editable mesh roots, excludes hidden metadata
geometry, requires positive proper transforms, exports actual editable meshes,
and audits them against AA. Audit checks original leaf TRS, 155,553 oriented
world-space P/N/UV faces with full duplicate multiplicity, 14 material semantics
and decoded pixels/samplers using frozen R7 helpers. Only after audit does the
canonical compiler emit AA+16. The packed master stores the deterministic recipe;
plain Blender glTF is an intermediate, not the canonical artifact.

A **separate Blender process** must run `build.py --reopen`, opening the new
master, repeating packed provenance/compiler checks and actual editable export
audit, and requiring canonical byte equality. Actual artifact/master hashes are
then required in both build and reopen reports. No source report impersonates
either actual report. Blender version is pinned to 4.5.14.

Future invocation shape (not executed): Blender background factory startup with
`--python build.py -- --grant-receipt <receipt> --attempt glyph-<fresh-name>`, then
another process with the same arguments plus `--reopen`. Receipt must carry an
active exclusive grant and this exact revision. This source task creates none.

## Native gate and bounded staging

`native_gate.check_streams()` compares all 155,553 mesh-local faces using the
approved census: node/material/oriented position/UV geometry keys first, complete
attribute perfect matching inside duplicate groups second. No greedy closest
sign selection. Exact P/UV keys are intentionally stricter than the maximum
position tolerance 1e-5; an unexpected positional change fails closed. Normal
and tangent component tolerance remains .0002. Sign values must be exactly ±1.

The gate requires all 19 repaired entries (51 incident occurrences: 48 glyph,
3 saltstone), retaining complete source/native mapping and checking approximate
unit binormals/orthogonality there. Zero/nonunit tangents and all fully parallel
native corners fail. It does not apply a global orthogonality gate to inherited
nonparallel entries. The frozen old AA readback fails against the new source.
`check()` additionally requires real UID/full-precision/LOD-off sidecar and R7
native material fields (14 sets) plus decoded image channels (39). Native
sampler/alpha equivalence beyond measured fields is not claimed; source semantics
remain byte-preserved. `ensure_tangents` cannot waive any gate.

`stage.prepare()` is a write-once future bridge requiring actual build/reopen
hashes. It prepares a separate test stage, original geometry/profile and actual
new artifact, with **failed AA** as the before art. Both variants explicitly
replace WorldMap fallback art with the selected pinned GLB and assert 39 mesh
instances; both use the real Binder and Weather capture template. Manifest hashes
bind the selected artifacts and scripts. Twelve matched cameras are prepared:
ten frozen X standard views plus two glyph-close exterior views. Before is
labelled `failed-AA-before`, never accepted runtime. Native local-array proof is
distinct from structural source WorldMap proof; no native world-transform parity
claim is made.

Future stage sequence: prepare after fresh reopen; import both GLBs under the
grant; set and verify real generated sidecars to compression disabled/LOD off;
reimport; run the stage `import.gd`; pass its JSON/streams and actual artifact to
`native_gate.check`; only then run matched captures. The bridge and GDScript have
not been engine-executed. Camera visibility, dry effects/Binder lifecycle,
Weather lifecycle, imagery/material appearance, fresh aperture rays and manual
acceptance remain pending. The historical 13,587-cap fixture is not rerun or
re-certified here. No runtime catalog promotion occurs.

## Appearance and broader source boundary

The exact N||T glyph set is genuinely singular (cross product zero). The other
4,729 nonorthogonal entries and five opposed-U observations are separate math
findings, not established visible defects. Raw 452,050 derivative-handedness
disagreements alone **do not prove a global normal-map convention defect**:
Blender's V flip combined with negative image-row stride can preserve the same
PNG location and authored normal perturbation with the supplied binormal. No
global tangent/sign/green-channel repair is authorized.

AA is the approved baseline for this bounded successor. Retaining its three
saltstone changes means equality relative to AA, **not proof of authored X
appearance equivalence**: two historical sign changes follow a chosen derivative
policy and still need appearance review. Full native equality means faithful
import of this source, not universal UV/Mikk validity or final art acceptance.
The separate convention investigation is not duplicated. All manual/material
appearance and broader release decisions remain pending, without auto-promotion.

## Source verification

Run `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s
tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v4-glyph-tangents
-p 'test_*.py' -v` (as one command).

Tests cover exact BIN bounds, editable AA audit, changed-input/output rejection,
conflicting incident policy, old native rejection, synthetic all-face success,
wrong-w rejection, missing surface rejection and duplicate sign multiplicity.
A virtual-filesystem stage test verifies both selected-art bindings, successor
capture hash, twelve matched cameras and removal of inherited historical proof
fields without writing any artifact. Packed AA recipe/compiler mutants fail.
Synthetic arrays are explicitly not native evidence. Frozen R7 material helper
tests remain the delegated semantic counterexample authority; helpers are pinned
and untouched. `validation.json` records source tests and archive preservation.
