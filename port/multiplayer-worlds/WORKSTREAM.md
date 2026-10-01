# Multiplayer / robot Horde expansion — integration checkpoint

The published campaign playtest remains runtime `614e11ad`:
https://github.com/mojomast/cocs-godot/releases/tag/quiet-relay-playtest-2026-10-01

Parent integration merge `ce4ec85f` brings in lane tip `b871ce98`: seven Blender
multiplayer maps / 43 explicit map-mode pairs and the Blackwater robot-Horde
expansion. This is a development checkpoint, not a newly verified release.

## Accepted evidence and remaining work

- The five nonurban maps passed scripted source-rule full rounds with two native
  observers and an explicitly labelled third movement-input fixture peer. The
  latest five-map art has 28 native captures, 94 ground probes, 10 overhead probes,
  seven bridge samples and 12 capsule-passage checks. Gameplay hashes did not
  change during the last art-only pass.
- Urban native acceptance at `bb4ef8bd` fixed a Blender export-axis mismatch and
  verified eight doors, curbs, counters, guards, ramps, roofs and objectives. CTF
  and Payload native clients received results, restart revision 2 and late-join
  state. New lighting review at `b871ce98` exposed a genuine missing roof at the
  Rainmarket east kiosk; a matching visible/authoritative roof repair is pending.
- Six Horde routes passed native robot presentation checks and Blackwater gate
  collision probes. The 17-second public clip shows wave one only. The natural
  native attempt lost at roughly 4 FPS with repeated control cancellation.
- Horde preparation `b580e2b6` fixes a phase-one-only Warden in the Horde adapter
  and adds native-input chain/boss fixtures. The phase change has controlled
  source-damage coverage; complete native mission/boss acceptance is pending.
- No expansion package export or new complete canonical run has passed yet.
  Human multiplayer balance and real-GPU performance remain unobserved.

## Active ownership

- Horde: `ses_f0a2032a7ffeXurQGXEp7rPDw6`, `expansion/horde-robots`, exclusive
  Godot slot for the complete native chain/boss fixtures. Merge `b871ce98` first.
- Urban: `ses_f0a216563ffecU5AKK7LRnpjbG`, `expansion/mp-urban`, roof correction
  and scoped static checks; one Blender slot, no Godot until Horde releases it.
- Worlds: `ses_f0a20dbd6ffessvYoMnKoRaK5B`, `expansion/mp-worlds`, native art pass
  complete and engine slot released.
- Parent owns canonical gate registration and package/integration verification.
  All eight newly registered source/route/network gates passed on the merged
  checkpoint. No competing local Godot run while Horde owns the engine slot.
- Worlds now owns preparation of cross-platform extracted-package expansion
  checks in `tools/godot-package/verify_expansion.mjs` and its native probe,
  with platform-verifier wiring. Code/static-only until an engine grant; actual
  package validation awaits the final export.

Evidence and exact scheduling history:
`/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/WORKSTREAM.md`.
Public previews and accurately labelled limitations:
https://github.com/mojomast/cocs-godot/releases/tag/quiet-relay-gallery-2026-09-30

## Package preflight

Parent launch/options/route checks passed 38 of 39 tests on the initial invocation;
the source-lock closure failed because the explicit existing derivative selection
was omitted. With `COCS_SOURCE_DERIVATIVE=port/contracts/lattice-catalog-derivative.json`,
all three closure tests passed. Both logs are retained. Generated multiplayer
derivatives and scene checks pass. This is not a full-suite or artifact result.
