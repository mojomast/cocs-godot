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
