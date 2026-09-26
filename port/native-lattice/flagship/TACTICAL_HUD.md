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
