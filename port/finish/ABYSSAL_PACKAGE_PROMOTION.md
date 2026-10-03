# Abyssal I public registration and source-only package promotion

Foundation: **`f0e76bf7`**, merged before changes. Parent accepted overview,
reef-window, vessel-1-2 interior and compact CTF results for integration, retaining
room-shell repetition and software-performance limitations from `PRODUCTION_I.md`.
The six proven modes are now registered in both public catalogs: **DM, TDM, CTF,
KOTH, Domination and Holdout**. Unsupported modes still fail.

## Exact received assets

The GLB embeds five PNGs: copper, coral, ivory and navy albedos, plus the copper
normal map. Closure includes **5 extracted PNGs, 5 PNG sidecars and 1 GLB sidecar**.
`abyssal_i_inventory.json` records actual byte sizes/hashes from committed
`f0e76bf7`; the tests independently verify every row against Git. PNGs must equal
the embedded image bytes, with exact names/counts, valid PNG signatures/IHDR and
received import settings. H/F inventories remain unchanged.

The received scene policy enables tangents/generated LODs and uses default mesh
compression (`force_disable_compression=false`). Texture sidecars use lossless
mode 0, unchanged normal orientation and no size reduction. These tested settings
are retained without reimport or an unsupported lossless-mesh claim.

Original I receipt SHA:
`25ad4fc34e2fef196588219c548fde1cb0ec771f0e5141c192ef0173b38a8767`.
Its source/native fields, `accepted:false`, historical pending list and original
packageInputHashes are preserved. Current integration review is a separate field.

Unchanged identities:

- Master: `0b450d5ab0ad975aed1887f72c91601a4dce9757f3c7c2a1ba6965aa2bf64ee2`.
- GLB: `fa6888d11ed95dee670b3200b141962e74d6ea17523aef3bcbd7edee149f16b1`.
- Producer fingerprint: `68487ea2e93e97aa7e2dc0eed7e5f000d6ba64f467971f843f2a8b75acdaecfe`.
- Actual export: **32,500 triangles**.

## Six-unit supporting-input transaction

`reconcile_abyssal_promotion.mjs` reads original receipts from `f0e76bf7`, verifies
unchanged production assets/source, constructs and validates all six proposed
receipts plus requirements before writing. Each `abyssalPackageVerifierAdvance`
retains the previous receipt commit/hash, old/new package fingerprint, exact
changed/added hashes and narrowly permitted runtime-hook changes. Existing F/H
advances remain intact.

| Unit | Package inputs | Current receipt SHA-256 |
|---|---:|---|
| Abyssal | 90 → 129 | `c626aea965c14a28cb04716b870ce3118cd00c3dbd8fb46606cca771cc19e34f` |
| Parallax | 62 → 64 | `c12e87e81fcecf7ddf537fb86198074d4adfa1ed0e165dad0ca74c34e75e4116` |
| Robots | 133 → 134 | `e89daf7514c7f9233593933e87db068c36c5e4475e391801dc91e8a9d23a7146` |
| Vehicles | 203 → 204 | `bf3b7e95158af6357bdcb82950d282a4526decad70f7532172cd1d11a1a929bb` |
| Scenery | 391 → 392 | `29c2d4f26decc5de874984f666404c05113ac1316a6c6ca909f2a4b31996dd0c` |
| Vesper | 143 → 144 | `7172bc359e9793c48c2b74ca7e458e49d6455f479c005ede7443739dce427e68` |

Abyssal's 39 added inputs comprise 11 import paths, 24 inventory/evidence records,
native catalog, presentation script and two verifier dependencies. Parallax's
preload closure gains the existing Abyssal presentation script and new verifier;
other prior units gain only the verifier dependency. Changed existing package
inputs are narrowly limited to the shared verifier and applicable public catalogs,
plus Parallax's existing `map.gd`/`demo.gd` dependencies.

Parallax hook validation now walks **original native → Vesper → Abyssal** in order,
requiring each step's before hash to equal the prior result and its after hash to
match the reviewed pinned policy. Catalog/demo H advances are not overwritten;
map has a direct original→I advance. Vesper's map/demo supporting hooks also
advance to the received I bytes. These are supporting integration updates, not
new Parallax/H native passes. Abyssal's own runtime hooks already match I and do
not change. Original evidence trees are untouched.

The received `tools/asset-production/candidate-hosted.mjs` changed during I from
`9e1684796ccd781fae958da8dad5869a6aa6923a734095da31f93389b252206d`
(`99a4f597`) to
`5532c11702b7ed27fd2d1e7aa11ba17b031678e2fa21178f1161749e1d0a1076`
(`f0e76bf7`). This promotion does not edit it or add it retroactively to earlier
native attestations. I's six retained private-authority derivation records bind
the actual source identities used in those runs; package inputs retain those
records rather than relabeling them as new public runs.

## Registration and source checks

Public coverage is exactly **12 worlds / 72 pairs**: 43 original, 11 Helix/Foundry,
six Parallax, six Vesper and six Abyssal. Both catalogs agree on Abyssal's modes.
Private admission rejects registered Vesper/Abyssal; Stormglass still uses the
exact-byte private seam. The historical thirteen-job production queue is retained;
it is not a post-registration native requirement. No public gameplay rerun is
claimed.

Passed **31 source tests** for package/import/channel/candidate contracts, plus
**three registration coverage tests**. The committed-Git closure test verifies
all six promotions, unchanged old fields and receipt history after commit.
Negative checks include missing PNG/sidecars, wrong hashes, altered import
policies, omitted package inputs/exports, invented image identities and skipped
or rewritten multi-step native hook history.

```sh
node --test tools/godot-package/abyssal_imports.test.mjs tools/godot-package/vesper_imports.test.mjs tools/godot-package/scenery_imports.test.mjs tools/godot-package/production_resources.test.mjs tools/godot-package/build_channel.test.mjs tools/asset-production/candidate-contract.test.mjs tests/new_maps/abyssal_pressureworks/admission.test.mjs
node --test --test-name-pattern='single-case diagnostics|extracted manifest|missing manifest' tools/godot-package/expansion_verification.test.mjs
node --test tools/godot-package/promoted_assets_git.test.mjs
```

Future preview: **six promoted / Stormglass pending**. Default final remains strict
for all seven. Published preview `cb6e4c9f` and its historical pending inventory
are immutable. No engine, import, server, benchmark, rendering, encoding or build
ran. I remains released at `05:28:53.827101Z` with its retained 23-group audits;
J belongs to Stormglass. Frozen authority, I assets and evidence, gameplay/HUD/
input/first-person files and other workers' feature code are unchanged.
