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
  Finish selections persist through the source protocol; native finish rendering
  is still absent and is identified as such in that catalog category.
- **Multiplayer (Flash):** room listings from the selected source endpoint and
  source-echoed room-scoped text chat, with typing/focus and spectator boundaries.
- **Parent:** packaging dependency closure, fixture-state isolation, integrated
  lifecycle journeys and serial verification. No release publication this batch.

Authority remains the reviewed combined source `61fca35c`; this batch adds native
protocol/persistence/UI integration, not new progression rules or local grants.
Device preferences never carry profile balances, unlock authority or credentials.

## Persistence and equipment contracts

`COCS_CAREER_ROOT` selects an absolute private storage root. Development defaults
to `.port-runtime/career`; installed supervisors select the platform config
directory before creating any disposable route runtime. The source-owned
`progression.json` and hash-named credential files under `identities/` are separate.
The legacy `identities.json`, if present, is validated and migrated per scope
without deletion. Each credential file has a lifetime lease: an owned local host
can coexist with an external guest, while duplicate writers for the same scope
are refused. External guests never acquire the owned progression store.

The supervisor binds credentials to its resolved endpoint through child-only
path/scope metadata. No token travels through arguments, environment variables,
device preferences or public evidence. Direct engine invocation has no admitted
credential scope. Godot uses native file-permission APIs, so packaged Linux does
not depend on an external `chmod` executable. Storage failures are explicit.

Arsenal sends complete known gear/attachment maps. Malformed partial maps cannot
become destructive writes. The source's equipment-marked `progression` reply is
distinct from an XP award; a queue success never means equipment was accepted.
One request remains pending at a time. A timeout remains unknown until a late
source reply or explicit reconnect, avoiding ambiguous retries on a wire without
request IDs. Unequip preserves all other known slots; finish removal uses the
source-supported explicit `null`.

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

## Integrated observations

Evidence: `port/native-shell/evidence/expansion-2026-09-28/`.

- **86/86 Node checks passed** at `466c846f`: persistence/leases/migration,
  equipment lifecycle and source wire, social authority, manifest validation and
  launcher ownership. Native credential persistence also passed at this revision.
- **18-session captured product journey passed** at `cbc43ded`, with 19 Home
  and 18 live Career checks. The first combat route selected `extended-mag`
  through its native Arsenal button and waited for source confirmation. Subsequent
  source-backed processes recovered the same identity hash and attachment.
  All 18 owned server ports were closed. Unsupported profile adapters remained
  unknown rather than inheriting another route's profile.
- **Two-native-client social journey passed** at `5d72b955`: selected-server
  discovery, advertised Verdant map/mode selection, guest join, 150% chat layout,
  source-echoed text, neutral movement/fire while typing, recipient room isolation,
  explicit chat close and guest leave while the external host continued running.
- The first expanded aggregate stopped at gate 19/218 because native graphics
  fixture copies omitted the newly imported `career_path.mjs`. `0d8bd78c` adds
  it to the graphics and native arena fixture closures; the rerun is pending.

Failed attempts remain retained rather than being relabelled:

- `466c846f` native Arsenal fixture used a `StringName` dictionary key that cannot
  come from source JSON. `7cb3c394` corrects the fixture to a string key; complete
  equipment validation remains strict. The native actions/projection/modal tests
  then passed in the lane checkout.
- The same revision's captured Career journey sampled 150% nested containers one
  frame before reflow finished. `cbc43ded` waits the second frame and retains the
  unchanged viewport bounds assertions.
- Social journey attempts 1/2 incorrectly unpacked a two-value viewport as four
  values, then measured a hidden, unseated panel before its first container sort.
  Attempts are retained alongside the successful seated/visible acceptance.

Screenshots are retained locally with hashes. No new playable build, release or
public gallery has been published for this expansion.
