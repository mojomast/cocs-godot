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

Package verifier follow-ups `94aefa39 → 6951123e` are integrated as `cc1babfd`.
All 43 world pairs plus Blackwater will run against extracted runtime/PCK files.
Authority shutdown uses an explicit stdin handshake, with bounded forced cleanup
only on failure; native exit is bounded and teardown logs are checked for errors.
Parent also corrected the lifecycle test's file-URL conversion for Windows and
registered this package-contract gate in the canonical verifier. Its six Node
tests pass locally, including actual normal/hung authority subprocesses and a
Blackwater wire/hash exchange. Actual Linux/Windows artifact runs remain pending.

## Urban roof correction awaiting native acceptance

Roof commit `41027018` is integrated as `9bae914c`. All eight enclosed shops now
have matching closed Blender roofs and authoritative ceiling slabs (underside,
top and four sides). The new slabs do not add nav routes; existing upper routes
remain connected. Urban-specific lighting adds four interior lights per map.

- Switchyard hash: `9152ef1cfe7204e7c2f6a5e704d75ccd7a57d37596b0818938647c82ad3808e9`.
- Rainmarket hash: `3d2cbb9a8d59b8534a2f476ad01f24632ddd5f16a9e7ca7e4bcc6441e8808587`.

Lane source slab/door/navigation, 43-pair and two-WebSocket checks pass. Parent's
post-integration generated-scene check and urban navigation audit pass. Fresh
native import/ceiling/capsule/lighting/peer evidence is still required at these
new hashes. Previous post-art native evidence applies only to the prior hashes.
Astra currently owns Godot for the higher-priority campaign feel/cheat work;
urban roof native acceptance follows its explicit release.

## Final roof acceptance integrated

Urban `75cd3dc2` is merged on the parent. Fresh native import and all eight
interior images passed review, including the continuous lit east-kiosk ceiling.
Native probes passed eight ceiling underside/top pairs, 32 sides, standing
capsules, 72 doorway floor/capsule samples and the prior roof/ramp/curb/guard
routes. New-hash two-native-client CTF and Payload journeys reached results,
late-spectator synchronization and revision-2 restarts. Payload's first contested
cart stall is preserved; the guest fixture now moves its defender away via normal
inputs. Evidence: `urban/post-roof/` in the multiplayer evidence root.

Astra's final native campaign/cheat fixes `b800000d` and passing journey record
`04e7ddc6` are also integrated. Both lanes explicitly released Godot. Parent now
owns the engine for canonical integrated verification, followed by serialized
Linux/Windows exports and extracted-artifact verification. The canonical run uses
the explicit LATTICE derivative and keep-going reporting. Its prior report tree
was archived under the single-player evidence root's
`integrated-release/reports-before-integrated/`; new aggregate output is
`integrated-release/canonical.log`. No expansion download is published yet.
