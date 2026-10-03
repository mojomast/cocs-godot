# Vesper H: source-only package promotion

Parent accepted overview, ticket-concourse, compact CTF results, civic-front-stair,
street-arcade, canal-bridge and actual DM-frame evidence for integration and public
six-mode registration. Canonical **`99a4f597`** was merged first. Assets are the H
production commit **`8adb9f05`**, HUD fix `136bfcbf`, fixture `7ed434d4`, evidence
`04fbbfa5` and registration `99a4f597`. Original H production/evidence identities
are preserved; this source-only promotion is not a new native attestation.

## Exact inventory

The actual GLB contains **16 embedded PNGs**: base and normal images for quay,
cobbles, asphalt, sandstone, brick, iron, slate and plaster. Package closure adds
those **16 extracted PNGs**, **16 PNG sidecars**, and **one GLB sidecar** (33 paths).
`tools/godot-package/vesper_h_inventory.json` records sizes and hashes read from
committed `99a4f597` files. Tests independently compare every row to those Git
bytes. Verification requires exact names/counts, embedded/extracted byte equality,
PNG signatures/IHDR and received sidecar identities and policies.

H scene import actually used `meshes/force_disable_compression=false`, generated
LODs, tangents and extracted images. These are preserved, not silently changed to
scenery's different import policy. PNG import is lossless `compress/mode=0`, with
unchanged normal orientation and no size reduction. No reimport was performed.

Unchanged production identities:

- Master: `e9068c9c7226a231d379359157aa4c1b5fe57d81406d87e90abbb096c474548b`.
- GLB: `6afe34c82d45f06c30dedc780f59ac6afa5200835b487d41705902d771fc0bfd`.
- Producer fingerprint: `1fbf980f118a179747e057d6dbb9661ddf6fcaa7cd17a7ef61012234bbfc15dd`.
- Original frozen core: `58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.

## Atomic supporting-input reconciliation

`reconcile_vesper_promotion.mjs` starts from exact receipts in `99a4f597`, checks
source/master/export identities, constructs the entire proposed five-unit
transaction in memory, validates preview closure and strict-final refusal, then
writes receipts and requirements. Each receipt retains previous reconciliation
history and records exact previous receipt SHA, before/after package fingerprints,
added hashes, changed hashes and supporting runtime advances under
`vesperPackageVerifierAdvance`.

| Unit | Previous → current package inputs | Receipt SHA-256 |
|---|---:|---|
| Vesper | 89 → 143 | `a732d1f38393a4317d8ef5ba6527e35634abe25d64b7f83aafbbe7061d72d689` |
| Parallax | 61 → 62 | `0e1d3815e6a47411a8dc52b9bf8d04f21d12cef8d97693f53e61f3f59e12e116` |
| Robots | 132 → 133 | `15d1e1fa1b8b03ae91091ed6bc69d83a7432eb2250e012cdaff608955c8ab827` |
| Vehicles | 202 → 203 | `73f4e885a0d2fe32e530cf23886984412b565d8bce3660e93d5b2d97bbf956d7` |
| Scenery | 390 → 391 | `67c235f345e6c447818ae2fb7ec425bce91cd3a99ae5625547194cbd483b9fc8` |

Vesper adds 33 import paths, 18 inventory/evidence files, the native catalog, and
two verifier dependencies. Existing Vesper inputs changed only for the JS public
catalog and shared package verifier. Its original runtime hooks are unchanged.

Robots, vehicles and scenery change only the shared package verifier plus one
new verifier dependency. Parallax additionally advances the JS/native catalogs and
`godot/multiplayer_worlds/demo.gd` supporting inputs, and the corresponding two
runtime-hook hashes. The original Parallax evidence file remains immutable. The
verifier allows only the explicitly pinned old/new supporting-hook pairs; forged
exceptions fail. No art, geometry or native result is replaced by these changes.

Original receipt `accepted:false`, old pending-check lists and H
`packageInputHashes` remain historical evidence. Parent integration review and
the requirements promotion are separate fields, not edits to the H attestation.

## Registration-aware coverage

Current public coverage is exactly **11 worlds / 66 pairs**: 43 original, 11
Helix/Foundry, six Parallax and six Vesper. Vesper supports DM, TDM, CTF, Domination,
KOTH and Uplink. Tests assert every named family and unique pair count.

Private candidate admission remains closed for registered Vesper and continues
to require exact bytes for Abyssal/Stormglass. The historical 6/6/1 job inventory
is retained; it is not interpreted as a requirement to re-admit Vesper privately
after registration. Public unsupported-mode refusal is tested separately.

Future preview closure is **five promoted / two pending**. Default final mode
still requires all seven and rejects Abyssal/Stormglass. Published preview
`cb6e4c9f` is unchanged, including its historical pending-unit list.

## Source checks and limitations

Passed **21/21** targeted import/receipt/channel/candidate tests plus **3/3**
registration coverage tests. Tests cover missing PNG and both sidecar types,
forged GLB/PNG bytes, altered import policy and forged supporting-hook history.
The committed-Git closure test checks all five promotions and immutable previous
receipt identities after commit. No engine/server or source benchmark is run.

```sh
node --test tools/godot-package/vesper_imports.test.mjs tools/godot-package/scenery_imports.test.mjs tools/godot-package/production_resources.test.mjs tools/godot-package/build_channel.test.mjs tools/asset-production/candidate-contract.test.mjs
node --test --test-name-pattern='single-case diagnostics|extracted manifest|missing manifest' tools/godot-package/expansion_verification.test.mjs
node --test tools/godot-package/promoted_assets_git.test.mjs
```

H release remains `04:36:05.466278Z`, 27 owned groups empty per retained audits.
Dark-interior final review and software-rendering performance review remain open.
H ran the original frozen authority: it is **not** proof for later Helix navigation
optimization `6b8c445f`. Remote runtime proof belongs to the packaging worker.
No Blender, Godot, imports, servers, rendering, encoding or builds ran here; heavy
I remains reserved for Abyssal. No published download or CI file was changed.
