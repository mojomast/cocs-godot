# Player flow polish · 2026-09-29

User-approved follow-up to the native finishes/loadout batch, with parallel
implementation and serial resource-heavy verification. Baseline `04d940a4`
records both hosted workflows passing at `b6eec0cf` (237 native gates, zero unrun).

## Scope and ownership

- **Sol:** navigation, keyboard/mouse focus, Settings/Back/Leave, room-browser and
  reconnect control recovery in the shared shell and multiplayer session.
- **Flash:** saved/current/pending/unknown presentation, Career result/XP clarity
  and compact layouts. Unknown source facts must never be presented as stock or
  as a zero award.
- **Parent:** integration and a complete scripted Home → browser → hosted match →
  transport interruption → explicit Retry → results → Arsenal → rematch → Home
  journey, using the shipping supervisor/scenes and owned source server.

The build/release hold remains in effect. This pass changes native presentation
and input ownership; source rules, balances, admission, progression and purchases
remain source-authoritative. F12 opens Settings/Leave and Career; F9/F10 retain
their existing functions. Back/Escape releases controls without pausing the
source simulation or automatically recapturing the pointer.

## Integrated journey

`tools/godot-dev/product_journey.mjs --player-flow` selects a single lobby route
through the existing Home/supervisor harness. The default multi-route journey
is preserved. The additional path verifies selected-server room-list retrieval,
explicit host setup, lobby Arsenal return, recoverable transport loss, same-seat
Retry, accepted source results and same-round award, confirmed next-match
equipment, rematch and final Home/owned-server cleanup.

Only UI actions and one socket interruption are scripted. The source uses its
normal 60-second round; there is no forced settlement, progression grant, local
simulation of rewards or bypass of room admission. Button signals are scripted
activations and F12 is delivered through engine input; this is not physical-input
or human gameplay acceptance. `--capture` retains the browser, Retry, compact
results and compact saved-loadout views. Tokens and source identity remain out
of the public report.

## Lane progress

Navigation commit `889ba831`, integrated as `e981a112`, adds:

- Lobby Escape backs out of browse/room setup; from the disconnected form it
  opens Settings/Leave. Live Escape retains its control-release behavior.
- Selecting a room focuses explicit Join; source phase changes focus Start or an
  eligible Retry without stealing focus from an open modal or chat.
- Compact lobby/browser action rows reflow; Settings Back/Career/Leave stay
  pinned outside the scroll body. Home has the existing F12 Settings shortcut.

The focused Xvfb fixture dispatches real engine key events at compact scales
against a labelled synthetic session. Existing Home/lobby/social/reconnect-menu
and Career-modal checks passed in the lane. The 11-check rendered real-source
guest Retry/Leave journey also passed, retaining the external host. Its report
records baseline HEAD `04d940a4` because the lane changes were uncommitted when
tested; integrated verification will provide the exact committed composition.

Clarity work and integrated verification remain in progress. Hardware feel,
natural full-wave outcomes and Windows execution remain owner-run checks.
