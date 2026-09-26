# In-world tactical HUD

The LATTICE World route now presents three compact, non-interactive instrument
cards during a **fresh, owned, live pose**: a field directive, source-published
mission progress and wallet, and an action-status ribbon. The old large text
panel remains for setup, result and unavailable-state explanations. Opening the
command deck hides the in-world cards and releases pointer capture as before.

* The directive consumes `world_target.gd`'s advisory choice over the
  recipient's public nodes and own-team topology; it displays certified legal
  capture and supply separately from unknowns. 3D markers likewise separate
  owner/activity/capture/supply and show planar distance, without rendering a
  guessed capture radius or affecting collisions, navigation or sightlines.
* Operations shows source `outcome.waves`, HQ health, `director.waveLabel`, and
  `waves.forceAlive/forceTotal`, alongside own operator health; absence remains `—`/unknown. No locally ticking
  wave timer, threat calculation or inferred victory is displayed.
* PvP recon counts only **source-flagged `revealed` enemy entries** from this
  recipient's team-private `contacts[ownTeam]`. The transport drops every other
  team bucket and clears contacts on projection/identity loss. A globally
  visible enemy actor is never promoted to a private recon contact by the HUD.
  Recon Pulse remains an information-only effect.
* Personal REQ and team FLUX use the current recipient projection. Positive or
  negative REQ deltas are labeled *observed wallet changes*, never attributed
  to a purchase. The ribbon distinguishes locally QUEUED, server ACCEPTED,
  server SETTLED and REFUSED BUY card states. It does not treat a HOLD card as
  proof of capture or a button press as a successful purchase.

`godot/tests/lattice/world_tactical_contract.gd` verifies typed recipient
contact isolation, missing-data clearing, explicit wallet and wave fields,
card wording, and compact bounds (14 synthetic checks). The marker contract in
`world_hud_contract.gd` verifies known/unknown/legal/inactive labels.
`tactical_hud_capture.gd` renders synthetic Operations and PvP/Recon examples
at large and compact resolutions for visual review; the images do **not**
establish a real REQ purchase, live human play or a natural five-wave victory.

The [downloadable tactical HUD build](https://github.com/mojomast/cocs-godot/releases/tag/lattice-tactical-hud-2026-09-26)
contains Windows x64 and Linux x86_64 archives plus SHA-256 sidecars and the
two explicitly synthetic previews. It was packaged from port `9505f6ca`:
Linux SHA-256 `ceddd6efb54e9a6b98b5c73b3f90cd1efc86a0c50c0963387cdf420eb3bf5284`,
Windows SHA-256 `91d58a85c91f4b19139399a4166820b74915a47489f67c7b9a57fc91d589a2e0`.
