# P1 follow-up to 902c3bbb — exact Vesper art binding

Source preparation is ready for focused re-review. **Native readiness remains
pending: neither GDScript parsing nor imports nor journeys have run.** No grant
was consumed, no child agents launched and no heavy work queued.

## Closed identity pairs

| Variant | Authority SHA256 | Geometry hash | GLB SHA256 | Actual source inventory |
|---|---|---|---|---|
| accepted | `e273264a789036b26bda83bf8e390c8ae53f78e4357da241ce4a49368e8af885` | `27c71cc8895eab2ca3a0b5cae3c2b8f96ed9afd75db3deec4a5c96bd2f395ea7` | `6afe34c82d45f06c30dedc780f59ac6afa5200835b487d41705902d771fc0bfd` | 54,804 triangles, 11 meshes/surfaces/materials |
| candidate X | `397cedc8f5583a229bb3f65ed94d9a8c74c30fd4132b57bd4e754299a47c67ec` | `fd8e7134c8933e908336d7b0409c66bdc90f4adc03fcfc6e596d5b4579f1c740` | `f859d49cc1b462b4a88e351d915518c49940ce24a7b8c2047c2d8f94f419e1db` | 64,311 triangles, 29 meshes/surfaces, 17 materials |

Accepted bytes independently matched parent `70995941`'s tracked
`godot/multiplayer_worlds/art/worlds/vesper-viaduct.glb`. Candidate bytes require
the explicit X archive root; there is no discovery or accepted-art fallback.
`art_binding.py` checks authority bytes, map ID, geometry/recipe identity,
exact GLB bytes and embedded recipe identity, then runs the strict embedded GLB
geometry gate to derive actual counts and material names. Both pairs must pass
before setup creates an attempt directory. No editable master is required.

`art_binding.gd` independently holds the reviewed identities. It verifies both
variant paths/bytes and actual import settings/retained UID, loads both imported
scenes and counts nonempty meshes, triangles, surfaces and named materials.
It checks finite imported positions/UVs and the actual mesh compression flag.
Then WorldMap builds the selected authority, its runtime geometry hash is
checked, Binder is cleaned, the helper-loaded art is removed and the **selected
staged GLB is explicitly instantiated before the first physics wait**. Candidate
authority display meshes are removed as in the reviewed staging helper; all
authority colliders remain. A successful `WorldMap.build()` alone cannot pass.

Each journey receipt includes both variants' authority/art hashes, import UID,
import-sidecar/cache hashes, exact loaded and instance resource paths, actual
counts/materials, selected runtime geometry hash and `bindingReady` /
`bothVariantsRuntimeVerified`. Those flags are produced only after checks and
selected scene attachment; source manifests keep `nativeReady: false`.

This is explicitly a **JSON/art movement diagnostic**, not a Binder/Weather
lifecycle or presentation-stage claim. The test cleans inherited Binder state;
it does not certify restored material lifecycle behavior.

## Scope and success interpretation

Six groups contain ten walks each: five lanes, both directions. Sprint is false
on every movement step. These **60 native walk-only cases** differ from the
80 source walk/sprint trials already archived. Direct `Walker.step` exercises
the movement API, not keyboard focus or a network session. Radius .35 is the
real exploration controller; .42 is a separately labelled test-only capsule
envelope, not a production resize. Initial 5cm spawn separation is the only
placement lift. Grounded landing, stall and reset checks remain enforced.

Intermediate contacts are logged, not treated as a full-flight clearance gate.
Expected stair stalls must remain failures; neither an eventual successful walk
nor this binding correction waives the **184 failed static contacts** or proves
full-map acceptance. No controller or geometry behavior changes were made.
The approved three-corner Parallax proposal is unchanged and remains separate.

## Future grant commands — prepared only, none executed

After parent approval **and a new explicit grant to this lane**, acquire the
shared lock without waiting and use that grant's owned bounded runner. Set
`LP_NUM_THREADS=1`, `OMP_NUM_THREADS=1`. `$GODOT` must be Godot 4.5.2; scripts
assert its version. These commands supersede the original README setup.

```sh
set -eu
export COCS_BOTANICAL_X_FIXTURE_ROOT=/home/mojo/.tmp-on-disk/cocs-botanical-source-correction
export LP_NUM_THREADS=1 OMP_NUM_THREADS=1
BRIDGE=tools/godot-multiplayer/new-maps/botanical-post-x
ATTEMPT=vesper-binding-01
python3 -B "$BRIDGE/prepare_native.py" "$ATTEMPT"
# First import creates genuine UIDs. The source helper retains those UIDs,
# disables compression/LOD generation and records the actual sidecar changes.
python3 -B "$OWNED_RUNNER" run 900 "$GODOT" --headless --single-threaded-scene --path godot --editor --import --quit
python3 -B "$BRIDGE/prepare_native.py" "$ATTEMPT" --pin-import
python3 -B "$OWNED_RUNNER" run 900 "$GODOT" --headless --single-threaded-scene --path godot --editor --import --quit
# Run only after every preceding command succeeded; preserve all failed receipts.
for CASE in accepted-civic-r035 accepted-civic-r042 candidate-civic-r035 candidate-civic-r042 candidate-roof-r035 candidate-roof-r042
do
  python3 -B "$OWNED_RUNNER" run 180 "$GODOT" --headless --path godot \
    --script "res://tests/new_maps/botanical_post_x/$ATTEMPT/controller_journey.gd" -- \
    --fixture="res://tests/new_maps/botanical_post_x/$ATTEMPT/" --case="$CASE" || break
done
```

Each group also has an internal 170-second timeout. Runtime checks require the
actual `.import` UID, loaded resource UID, exact post-policy sidecar, retained
source path, compression disabled and LOD generation disabled. Missing imports
fail; the helper never invents an import UID or launches an engine. A failed
group stops this diagnostic sequence for review; retries use fresh namespaces.

## Verification

13 portable Python tests pass, including real accepted GLB census, missing and
tampered candidate rejection, accepted-GLB substitution rejection, and a
recipe-less authority rejected even when its supplied byte pin is changed.
`verify_art_fixture.py` additionally passes against the actual explicitly pinned
X archive: both strict GLB censuses, 60 cases, write-once setup, missing import,
missing/tampered candidate and accepted substitution with an edited manifest.
Only that integration test's unique scratch copies are removed afterwards.

The original `source-provenance.json` and every 902c3bbb evidence JSON remain
historical, unchanged. Follow-up provenance is additive; the original 15
dependency hashes are checked against this checkout and parent `70995941`.
Frozen inventories are verified again: 600 X and 264 U, zero mismatches.
