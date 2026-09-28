# Pre-release expansion — Career, Arsenal and multiplayer

The user requested more features before shipping and selected all three lanes:
Career continuity, source-validated Arsenal equipment, and room discovery/chat.
The consolidation release is on hold until this batch is integrated and checked.

Starting implementation revision: `d36dc67d`.

## Ownership and source boundaries

- **Career continuity (Sol):** durable source-owned local progression, separate
  endpoint-scoped request credentials, stable supervisor paths and lifetime
  ownership of the local progression store. Home remains authority-free.
- **Arsenal actions (Sol):** gear/mod/finish selection and removal through the
  existing `GEAR` message. A send is pending until a source equipment reply;
  source normalization is reported honestly. The source reads saved equipment
  when constructing the next match, not at the current actor's next respawn.
  Reticles remain view-only because this wire does not carry their selection.
- **Multiplayer (Flash):** room listings from the selected source endpoint and
  source-echoed room-scoped text chat, with typing/focus and spectator boundaries.
- **Parent:** packaging dependency closure, fixture-state isolation, integrated
  lifecycle journeys and serial verification. No release publication this batch.

Authority remains the reviewed combined source `61fca35c`; this batch adds native
protocol/persistence/UI integration, not new progression rules or local grants.
Device preferences never carry profile balances, unlock authority or credentials.

## Verification foundation

The prior consolidation aggregate passed **211/211** at `ad8bdb31`, followed by
the source server suite and repository lint. Its retained report and logs are in
`port/native-shell/evidence/consolidation-2026-09-28/`.

Subsequent focused verification at `d36dc67d` passed the movement, Horde controls,
identity composition, first-person lifecycle/muzzle, Career projection and modal
contracts. Both Nacre and Cinderwake held-input motion observers and their source
correlation validators passed. The captured six-choice journey completed
**18 source sessions and 37 Career checks**, with all owned ports closed.
These checks predate the persistence, equipment and chat additions here.

## Integrated acceptance target

1. Start a source-backed route, receive a genuine owned Career profile and select
   an available starter attachment through the displayed native Arsenal action.
2. Wait for the source's equipment-marked reply; retain the confirmed selection
   through Leave → Home → another route and through authority-process restart.
3. Verify identity continuity without exposing IDs/tokens in public evidence;
   credentials for one server must never be sent to another endpoint.
4. Browse real room state, join a supported room and exchange source-echoed chat;
   another room must not receive it. Typing must release gameplay controls.
5. Retain unknown/pending/error states on malformed data, rate limiting,
   disconnects or missing acknowledgments. No local state invents an unlock.
6. Run focused checks, source-backed journeys and the final aggregate serially.
   Each test uses an isolated `COCS_CAREER_ROOT` so real careers are untouched.

Natural full campaigns, hardware feel, native Windows execution and eight-human
acceptance retain their prior owner-run status. The gear rank-invariance balance
failure is tracked separately from faithful source equipment behavior.
