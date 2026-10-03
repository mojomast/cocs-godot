# Campaign source-generation closure — 2026-10-03

Follow-up to implementation `91f58a1c5dcd85544574ba9cd11fcecd0d50d522`.
This closes the generated-core/source-oracle items marked pending in
`IMPLEMENTATION.md`; package inventory and native acceptance remain separate.
No game physics, native client or weapon-cue source was edited during this pass.

## Provenance policy

`port/contracts/source-lock.json` identifies upstream
`515daf07589150dd3241f4ae1425cc1b093912f5`.
`port/contracts/lattice-catalog-derivative.json` identifies historical derivative
`0326b435a2fdd88e6e7a01b8a7325feccc4d15cb`. Its hashes are tied to those historical
Git objects, not floating expected values. Both contracts remain byte-identical.

The new **candidate overlay**, `port/contracts/movement-candidate-derivative.json`,
names its historical parent, exact pre-movement baseline
`90be2af7755674e470db638c3e4df63bbebbedab`, implementation commit `91f58a1c…`, and
four explicit before/after runtime hashes. It is labelled
`source-candidate-not-native-acceptance`. The parent inventory plus these
overrides contains 13 changed game/server runtime files relative to upstream.
Tests validate the complete inventory against Git, each historical parent hash,
each baseline/candidate hash, ancestry and current working bytes. Test files are
excluded from the runtime inventory using the existing convention.

## Exact old/new audit

| File | Before SHA256 | Candidate SHA256 |
|---|---|---|
| `game/core.mjs` | `58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9` | `655f112934b7b4a4f1d9f043a8c545511e7284f557e4c9586dfd72d3e5a8e7a3` |
| `game/operator-verbs.mjs` | `f3bbcd2e13bc04dabf2a81a74ddee3848d6835d11d8ac063e4603ea689bf96b3` | `357b7b2174f6f280c3cf386612d886a725c772ca2c14bb66ecce3b6e32024a6e` |
| `game/feedback.mjs` | `9b99d61463a0edc64ad681949c7eb4b6993f879f4ab7bf3f30383aa8043b193f` | `bce79610e67236a16e135e05338809e6dd29411be40ac8aff4fbe99f9f69e923` |
| `game/weapon-ads.mjs` | `01d9eb7ddbb304b0bca39899e393730cbdf04fffb5024f28886399e76f20452b` | `133a10f85e9c59928c16e5e25e240e1aa0e89200f81cecd77bb62482f6ef795f` |
| `port/native-campaign/core.generated.mjs` | `2800bec533c3810a94d61e2f7f20f93574e44b13346dee2085200a0467759cca` | `949e8a599d0bea5773e35043fefdc1d58d38a3f0ea678ad76f76ba5e47e78abb` |

The operator change in `91f58a1c` updates comments describing shared multipliers;
the exact dependency bytes are still pinned and drift-checked. Feedback/ADS
hashes belong in the source overlay even though campaign physics does not
import these presentation modules directly.

## Generation and source parity

`port/native-campaign/generate-core.mjs` now expects the exact candidate core
hash and checks the exact operator dependency before CLI generation/check.
The intended generator produced `core.generated.mjs`; no generated body was
hand-edited. Its four reviewed adaptations remain unchanged: relative imports,
NPC hit volumes, projectile weapon lookup and blocked-shot event classification.
Independent inverse comparison proves every other source byte is preserved.

`port/native-campaign/match.mjs` already imports this generated `Match`, so the
campaign path now includes the acceleration bound, air tuning and landing-slide
buffer. Arena/Horde continue to import `game/core.mjs` directly.

The lattice oracle serves as a source-function/fixture conformance check. It now
checks the explicit candidate overlay while retaining the historical derivative
identity assertions. Its caption/progress/recovery output fixture did not change
and was checked without `--write`; no historical evidence was replaced.

Executed bounded source-only checks:

```sh
node port/native-campaign/generate-core.mjs
node port/native-campaign/generate-core.mjs --check
node --test --test-reporter=spec port/native-campaign/core-provenance.test.mjs port/native-campaign/movement-parity.test.mjs port/native-campaign/hit-volume.test.mjs
node tools/port/lattice/source-oracle.mjs
git diff --check
```

Results: **9 tests passed, 0 failed** in 0.86 seconds. Generated/source
`moveActor` parity includes landing taps, impulses and launchers at 30/60/120 Hz.
Generated/source authoritative `Match.step` parity includes 60 seconds of real
ground-hop cadence at fixed 60 Hz and the 17.6 m/s input budget. NPC hit-volume,
projectile and melee adapter regression checks passed. Generator drift-negative
checks reject changed core and operator bytes. The oracle passed **47 captions,
4 progress cases, 13 recovery cases and 13 runtime hashes** against the unchanged
checked-in fixture.

## Remaining closure owned by parent/package integration

- Reconcile the new source-candidate contract and generated adapter into the
  future package's source/hash inventory. This overlay is not an asset producer
  receipt or a native package acceptance record.
- Existing production receipts (`abyssal-pressureworks`, `robots`, `scenery`,
  `vesper-viaduct`) and `port/finish/ASSET_PRODUCTION.json` retain their original
  dependencies/evidence. Reuse eligibility or fresh production validation belongs
  to their owner; nothing here re-stamps them.
- Inventory the changed native arena/campaign/Horde clients and first-person rig
  from `91f58a1c`, run the expanded input-flow/slide fixtures, then native campaign
  and other affected-route acceptance under the parent's engine/storage schedule.
- Integrate independent review findings before freezing the final candidate. If
  review changes game/runtime bytes, explicitly advance the candidate overlay to
  the new implementation commit and regenerate/recheck; these pins intentionally
  reject silent drift.

No Godot, Blender, import, headless engine, server or native benchmark was run.
No old producer/native-package receipt or acceptance artifact was changed.
Storage checks returned concrete output: 245 MiB free before generation,
244 MiB afterward on the disk-backed filesystem; `/tmp` had 16 GiB free.
The small generated-text update completed without a storage blocker.
