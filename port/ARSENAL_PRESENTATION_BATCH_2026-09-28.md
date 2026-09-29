# Native Arsenal presentation

User-approved follow-up to the reconnect/Career batch. Implementation baseline:
`683ead49`, branch `port/lattice-flagship-next`.

## Parallel lanes

- **Sol:** source-derived weapon-finish materials in the native first-person rig,
  lifecycle/material isolation checks and rendered/source-backed verification.
- **Flash:** readable source-confirmed equipped-loadout summaries in Arsenal and
  connected match setup, with explicit pending/unknown/next-match states.
- **Parent:** resource/package contract integration, integrated journeys,
  documentation and serial verification.

## Authority and presentation boundaries

- The source-owned profile is the saved loadout for the next match. The current
  match's accepted actor snapshot determines its visible finish. An equipment
  acknowledgment does not repaint or change the currently active actor.
- Source actor gear fields contain resolved modifiers, not necessarily the saved
  item IDs. The UI must not reverse-engineer item names from those modifiers or
  label saved profile choices as the current actor's loadout.
- Material colors and application rules come from the source cosmetics and
  rendering code. Generated presentation data records its source hashes. Native
  material changes cannot alter weapon behavior, aim, recoil simulation, hitboxes,
  balances, unlock eligibility or progression.
- Unknown/missing facts remain unknown in the UI. A renderer restores its neutral
  appearance when it lacks an applicable known finish; that is not a claim that
  the source equipped stock. Explicit source `null` means no finish.
- Shared materials must not leak one actor's finish into another rig, hands,
  effects or unrelated weapon surfaces. Repeated snapshots must not allocate a
  new set of materials every frame.
- Home remains authority-free. Connected setup summaries belong only to their
  actual seated source connection. Finishes and loadouts still require source
  eligibility and confirmation; reticle selection is outside the existing wire.

## Verification target

1. Compare all six finish colors with source-derived oracle data and retain the
   authored base appearance for stock/unknown states.
2. Exercise finish changes, weapon/actor switches, respawn, spectators/vehicles,
   disconnect/reconnect and multiple simultaneous rigs without material leakage.
3. Select an eligible finish/loadout through the source protocol; confirm the
   saved profile changes while the current match remains unchanged. Verify the
   next source match supplies the new actor finish and the native rig renders it.
4. Check readable equipped-item names, pending/adjusted/unknown states and compact
   150% layouts in Arsenal and match setup.
5. Run integrated native journeys and aggregate/server/lint checks serially.

The parent also found a pending package-probe issue: its Career schema required a
nonempty `slot` for every catalog item, whereas source finishes/reticles correctly
have an empty slot. Both probes now distinguish equipment slots from slotless
cosmetics; an editor contract check will exercise the exact probe functions.
Extracted-package acceptance remains a later step.

No playable build or release publication is part of this batch. Prior hosted CI
confirmation is tracked against `683ead49`; later implementation is separate.

## Implementation and review progress

- Finish implementation `8c3acba6` integrated as `d3a632df`. It follows the source
  viewmodel roles (dark/secondary, light/accent, glow/primary), mutates private
  per-rig materials and follows only the current source actor's `finish` field.
- Parent review found an incorrect extra sRGB-to-linear conversion. Godot's
  material uniforms use `source_color`; its glTF importer converts linear factors
  back to sRGB before assigning `StandardMaterial3D`. Repair `9883914e`, integrated
  as `0d239291`, supplies sRGB colors and checks their shader-linear equivalents
  against Three.js. The original rendered evidence is preserved and labelled
  under `port/native-finishes/evidence/historical-double-conversion/`.
- The deterministic finish generator now supports `--check` and records both
  cosmetics and source-renderer hashes. Package builds check freshness and record
  the generator/catalog as inputs, with committed catalog byte validation.
- The source journey uses a controlled source-owned progression grant to make
  Ion eligible. Ordered post-ACK snapshots prove the current actor stays stock;
  the next source round supplies Ion. A separate native rig replay checks those
  captured public actor fields against actual material channels. This is not a
  claim of natural eligibility or a fully interactive native equip journey.
- Aggregate registration covers generator freshness, the source palette oracle,
  material lifecycle, fresh source journey and native replay.
- Corrected finish evidence `19540503` integrated as `af253e94`: generator and
  Three.js oracle passed, material lifecycle 71 checks, existing rig lifecycle 63
  checks, source rounds 1→2 and native material replay passed. Fresh rendered
  captures show all six finishes distinct from stock (2,399–2,420 changed samples).
- Loadout commits `edf2a669` / `8897a35c` integrated as `7a42bde2` / `ac6129e4`.
  Focused model/UI/lobby and existing Career tests passed; a real native equip →
  source-confirmed Extended Magazine → next-match journey passed 18 checks. This
  uses a naturally eligible level-one attachment without a progression grant.
  The initial compact screenshot exposed insufficient visible content despite
  passing tab/Back geometry checks; a focused layout follow-up is underway.
- The aggregate also registers source-backed saved-loadout rules, native
  model/UI/lobby checks and the rendered native journey, with a fresh isolated
  output directory per invocation. Integrated verification remains pending.
