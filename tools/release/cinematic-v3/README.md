# Cinematic v3 producer

Source gate registered in `port/finish/final_matrix.json`:

```sh
node --test tools/release/cinematic-v3/pipeline.test.mjs
node tools/release/cinematic-v3/pipeline.mjs --plan
```

These commands do not invoke an encoder/engine. The ordinary-source-input unit
test runs short offline match steps; a source-only grant excluding authority
journeys can select the other tests with `--test-skip-pattern='ordinary source'`.
`--prepare` advances offline source authority and is for the later production
grant under the current resume directive.

## Current scope and dependencies

This is the existing 75-second four-chapter campaign story, not a montage of the
ten registered multiplayer worlds or a new fighting story. Parent `5d33287a`
is merged. Nine produced fighting rigs, quiet Moth revisions and Parallax C are
real parent inputs; responsive fighting framing still needs native acceptance.
No fighting footage is claimed or inserted. The six remaining production units
must finish before final cinematic production, as RELEASE_COMPLETION requires.

`--plan` audits actual packaging-owned promotion records, masters, exported GLB
contents/fingerprints and runtime hooks using `productionResources()`; it reports
pending units without turning them into passes. Capture/menu/edit require its
strict closure. A missing scenery/robot asset cannot silently use the optional
runtime fallback. Native capture checks raw Godot asset SHA256s/import availability,
three installed scenery assemblies per chapter, and the existing switchyard skin
metadata on applicable actual robot visuals. Robot production owns those hooks;
this lane never installs a fake skin merely to make capture pass.

Asset byte hashes are resolved from the current checkout on preparation and
rechecked before/after native work, not copied from old trailer evidence. Existing
campaign geometry pins remain intentional authority/camera safety constraints.
The exact input plan binds the production inventory, source/render scripts,
recorded snapshots and installed menu bytes. Use a fresh attempt on changed inputs.

## Production rehearsal / installation (explicit heavy grant only)

After importing and reviewing **final accepted assets**, choose a new external
directory. No command overwrites an existing attempt/shot/edit/menu receipt.

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export LP_NUM_THREADS=1
E=/home/mojo/.tmp-on-disk/cocs-expansion-four-trailer-evidence-20261002/final-assets-rehearsal-01
node tools/release/cinematic-v3/pipeline.mjs --prepare --output="$E"
node tools/release/cinematic-v3/pipeline.mjs --capture --slot-granted --output="$E"
node tools/release/cinematic-v3/pipeline.mjs --menu-check --slot-granted --output="$E"
node tools/release/cinematic-v3/pipeline.mjs --edit --slot-granted --output="$E"
# Inspect native footage, full movie, audio and menu images before installing.
node tools/release/cinematic-v3/pipeline.mjs --install-menu --slot-granted --output="$E"
```

Installation first revalidates every shot's actual PNGs, source-clock ledger,
execution artifacts, candidate-menu proof and encoded master. It preserves the
exact previous `godot/ui/attract/demo.json` at
`installation/preserved-before.json`, records both hashes, atomically installs,
then runs **real Home against installed data without candidate injection**.
Native failure restores the preserved bytes; unrelated concurrent edits are not
overwritten. An interrupted installation can explicitly restore the backup:

```sh
node tools/release/cinematic-v3/pipeline.mjs --rollback-menu --output="$E"
```

Old v2 videos/captures/gallery are never touched. Parent reviews and commits the
accepted menu installation before freezing the release candidate. The old
`tests/main_menu/live_attract.gd` has four-clip/index assumptions: the new fixture
reuses its real capture/wait helpers but covers eight clips and all four chapters.
Do not interpret the old four-clip fixture as v3 acceptance.

## Exact final-matrix receipt

Installation changes runtime bytes, so a rehearsal **cannot** be re-stamped as a
final frozen-candidate receipt. After parent commits installation and final assets,
finishes stable imports, and creates its final ledger using the registered matrix,
run a new immutable final attempt in the same checkout/environment:

```sh
F=/home/mojo/.tmp-on-disk/cocs-expansion-four-trailer-evidence-20261002/frozen-native-01
LEDGER=/absolute/parent/final-ledger/report.json
node tools/release/cinematic-v3/pipeline.mjs --prepare --output="$F" --ledger="$LEDGER"
node tools/release/cinematic-v3/pipeline.mjs --capture --slot-granted --output="$F"
node tools/release/cinematic-v3/pipeline.mjs --menu-check --slot-granted --output="$F"
node tools/release/cinematic-v3/pipeline.mjs --menu-check --installed --slot-granted --output="$F"
node tools/release/cinematic-v3/pipeline.mjs --edit --slot-granted --output="$F"
node tools/release/cinematic-v3/pipeline.mjs --receipt --output="$F"
```

`identity.py` calls the existing runner's read-only `load_matrix/input_identity`:
same checkout, queue, environment and actual bytes must match at binding and
before/after production. Cache/import mutations also invalidate that identity;
they are not excluded here. `owner-reference.json` uses the existing
`owner-closure` adapter, exact `menu-trailer-native-production` gate,
`native-cinematic-and-menu-production` class, and its three required units. It
includes every actual frame/artifact hash, not just an owner-written `passed` flag.
Pass that reference to the parent's existing `--receipt` option. No final runner,
matrix or packaging contract is changed by this lane.

The independent `menu-trailer-listening-review` manual gate remains parent-owned.
An encoder's successful exit cannot assert full watching/listening/human review.

## Evidence model

Each native invocation has a random correlation nonce. Every ledger row binds the
exact JSONL record SHA256, source time, source frame, actual saved PNG SHA256 and
dimensions, monotonic draw/save times, engine-frame increments and camera/cast
trace. Node rereads the PNGs and original source records, checks the 60-Hz step
sequence, measures wall cadence separately from 24-fps offline output, and refuses
holes, altered bytes, mixed invocation identities or changed inputs. Receipts are
written only after awaited process exit and clean complete logs. Menu proofs bind
timestamped real viewport screenshots, candidate/installed hashes and cleanup.

This is tamper-evident local execution evidence, not hardware attestation against
a hostile account that can rewrite both tools and evidence. No source plan or
self-declared metadata alone qualifies as native production. Software offline
rendering is not human input or real-GPU performance. The music-only edit uses the
existing original score; it does not claim captured live effects/comms audio.
