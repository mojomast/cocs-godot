# O — exact Settings Return Home package advance

## Parent verification

Worker `76591715` integrated as **`14d8a72d`**. Parent independently passed all
**55 source tests**, including committed-Git verification of seven strict asset
inventories, exact O predecessor/evidence and rejection of future source drift.
Whitespace checks passed. P was notified to adopt the closure only after its
active connected batch, then stabilize candidate/import identity for a fresh
canonical ledger. No native acceptance was rerun or reassigned by this transaction.

Foundation: **`b17360c97d06040f6aa44a4ec9eed8cb863d7eb7`**, including parent
`3ee932e8` / original O candidate `f22fcc1e95c0b890f1ad656f16ab2b406b5b069b`.
Previous L closure was integrated as `623127c5` (worker `d5335f8b`).

## Sole runtime change

`godot/ui/local_settings.gd::leave_match()` now hides the Settings panel, clears
`return_focus`, and defers `change_scene_to_file("res://ui/main_menu.tscn")` instead
of quitting. The overlay/visible-button guard and mouse release remain. This is
the actual parent-reviewed runtime fix; it was adopted rather than reimplemented.

Exact SHA-256 predecessor/current:

- Before: `569765028c3a7029c6fee7972d3b3926fe2d4af8cfec755012f595a212cf50a7`
- After: `073a48948796a68680cd0f4242655374c5f8b7fc5b835347ebaf0dd35b7d42f9`

Audit of every existing package input found only this runtime drift. The Home
dependency is already inventoried. Every unit changes two existing inputs
(Settings and the supporting verifier), adds four bounded evidence JSONs, and
appends `oReviewAdvance` with exact previous receipt/hash and package deltas.
No declared activation hook changes. All original producer/native identities,
asset bytes, `accepted:false`, pending lists, `polishAdvance`, `lReviewAdvance`
and earlier history remain unchanged. The original `8921ed41` and L assertions
remain exact; O is independently required and cannot substitute for either step.

## Retained original O evidence

Copied exactly from `/home/mojo/.tmp-on-disk/cocs-gameplay-repair-O-20261003`
into `port/finish/acceptance/package-evidence-o/`:

| Record | SHA-256 |
|---|---|
| `HEAVY_GRANT_RELEASE.json` | `75e737cbf562be0601b83b73a09157fd0fce91632f7dc2fe2712b34ad7d7cde7` |
| `world-final-01/receipt.json` | `e35f5391b787d73c21e26a7ae98a18d5cb84070371b907c1b0438746ce640972` |
| `combined-home-regression-01/receipt.json` | `3b97393b6388145314535d7a5c8f91abffb2a2fd8173eb11f0942e16ce2fe4c1` |
| `controls-final-01/receipt.json` | `30affd0776ab8bfd1fb4b11810e987580e8450e40f5bcb4235bc2c3d6fe547ee` |

All three final receipts passed with code 0, empty remaining-process cleanup,
and source-input identity
`752f896a7768171785bb416b6aaea4660342d6548afa3b9332fbc0235c296747`.
Release at **2026-10-03T13:43:24.673890Z** retains 18 job cleanups and three empty
owned-process/live-engine audits. These are historical records, not processes
launched or native tests repeated by this transaction.

As detailed in `O_REPAIR.md`, both world and combined-arms routes passed separate
ordinary-input approach, mount, drive in both views, look, demount and actual
F12/Return Home journeys. The controls repair is fixture-only: complete the render
boundary while the owned sessions still exist, then dispose normally. All original
90 assertions remain, and the final stock-binary run is leak-free. No asset/import
policy or authority change is part of O. Screenshots and full wire/native artifacts
remain in the original evidence root; none are duplicated here.

O does not imply production-GPU/full-speed or human acceptance, a package export,
or all-142 completion. Live kick remains **not accepted**. Other N/P obligations
retain their own evidence and acceptance boundaries.

## Seven-unit closure

| Unit | Inputs | New receipt SHA-256 |
|---|---:|---|
| Parallax | 554 → 558 | `a04d631904a35983ccc6aa08bb24ff74f888fcc68d2f9b2ab60b5acff59db83f` |
| Robots | 632 → 636 | `e5b28e90bd27a7420402634a62f35e98d458b30da7a804f5df810b4358e444de` |
| Vehicles | 702 → 706 | `200f5d7827d8cba331ac4161e1e84933af7de5963514a4178b2b97b6b6f14c6b` |
| Scenery | 883 → 887 | `726c62f8dd3fe00b93e63d8cbf480fff6cdbd3cd40e2d0121ba6222743ba6072` |
| Vesper | 647 → 651 | `a6f642f97e6d938b66f5e82c1778d2e9d5e13732b945fe5992ecbe12eeff10da` |
| Abyssal | 631 → 635 | `5606d508ee887576a7ea37f668945a9734e93b06b03099871e6a1522d0807c97` |
| Stormglass | 572 → 576 | `b68176868a1afdf310fec4f034282f0d9212010e7f9018bb016431923046e7c7` |

`o-package-audit.json` records counts/hashes. The reconciler verifies the full
seven-receipt proposal before writing. Missing O history, forged predecessors,
stale Settings hashes, future runtime bytes, changed evidence and invented
live-kick acceptance fail closed.

## Actual source verification

**54 targeted source tests passed** before commit. The independent committed-Git
test additionally validates all seven strict inventories and exact predecessor
receipts/deltas from committed bytes. Commands:

```sh
node --test tools/godot-package/polish_dependencies.test.mjs tools/godot-package/stormglass_imports.test.mjs tools/godot-package/feature_dependencies.test.mjs tools/godot-package/abyssal_imports.test.mjs tools/godot-package/vesper_imports.test.mjs tools/godot-package/scenery_imports.test.mjs tools/godot-package/production_resources.test.mjs tools/godot-package/build_channel.test.mjs tools/asset-production/candidate-contract.test.mjs tests/new_maps/abyssal_pressureworks/admission.test.mjs
node --test tools/godot-package/promoted_assets_git.test.mjs
```

No engine/import/server/build/benchmark or child agent ran. Menu cinematic,
Windows workflow, unrelated parent documents, release artifacts and final matrix
were not added to asset dependencies or edited by this transaction. Future
runtime corrections require another exact reviewed step.
