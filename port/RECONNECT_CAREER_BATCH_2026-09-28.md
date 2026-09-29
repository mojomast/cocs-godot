# Reconnect and Career results/history

User-approved follow-up to the locally verified 218-gate expansion. Baseline:
`fd70d25e`, branch `port/lattice-flagship-next`.

## Parallel lanes

- **Sol:** explicit native multiplayer reconnect, in-memory source-issued room
  ticket, same-endpoint/room admission, input-sequence continuity, spectator and
  host authority, and real-source reconnect verification.
- **Flash:** Career round-result and progression-award projection, recent server
  history browsing, bounded native UI and source/projection fixtures.
- **Parent:** source-owned history persistence in both supervisors, packaging
  metadata, integration contracts and serial aggregate/journey verification.

The simulation source and combined derivative remain unchanged. New UI requests
and displays existing authority behavior; it does not create progression or
reconnect rules.

## Source facts that constrain the product

### Reconnect

`Room.join` recognizes its own welcome `token` and can restore a reserved peer
within its grace policy. This token is separate from the Career progress token.
It belongs only in native process memory, bound to one endpoint and room. A
dropped connection is different from an intentional Leave. Reconnect must
restore the authority's current actor/spectator/host assignment and round, not
assume the previous role or restart a match. Held input and pointer capture must
not resume automatically.

### Results and progression

At settlement the source records history, sends each eligible player's
`progression` award, and then sends recipient-filtered `results`. Equipment
confirmation is also a `progression` frame, but is not an XP award. Reconnect may
replay results without replaying an award. Missing award facts stay unknown;
neither replay nor a repeated UI visit can create or multiply progression.

### History

The `history` reply is **recent server matches**, not a personal career archive.
Ordinary history player entries contain display names and scores but no stable
Career player ID. The native UI must not infer participation from a matching
name or attach a server match to the current career without source evidence.

Owned source-backed supervisors persist `MatchHistory` at
`<COCS_CAREER_ROOT>/history.json` under the same lifetime lease as their progression
store. The source retains its existing newest-first 50-match policy. External
guests only request their selected server's history. The native UI never reads
or edits the authority's file. Corrupt stored history must not silently reset and
overwrite itself on the next result.

## Acceptance target

1. Disconnect and explicitly reconnect a native player to the same live source
   round; confirm actor assignment, input ACK progress and pointer release.
2. Exercise spectator reconnect, expired/refused tickets, intentional Leave,
   endpoint isolation and a round that completes while the client is offline.
3. Display genuine source results and eligible progression awards, distinguishing
   replay/missing facts from a new award and preserving private source views.
4. Browse source history, restart an owned authority and observe retained records
   through the wire. Verify empty/loading/error/malformed/disconnected states.
5. Keep compact 150% layouts usable and existing Career equipment actions intact.
6. Run heavy imports, live checks and aggregate/server/lint suites serially.

No build or release publication is part of this batch. Native Windows execution,
natural full campaigns, hardware feel and eight-human acceptance remain owner-run.

## Implemented behavior

- Multiplayer transport loss offers **Retry / Reconnect** and **Leave**. Retry
  sends the in-memory room token only to its original endpoint/room/map, with
  separately endpoint-bound Career credentials. An expired room ticket can
  therefore become a source-admitted fresh spectator seat without creating a
  different Career. Leaving, cancelling, or rejecting the protocol clears the
  admission context. An unsolicited late welcome cannot bind a profile or ticket.
- A resumed same-round roster must retain the actor; a source-authorized new
  revision can reseat it. Source reattachment resets its receive counters; the
  native client keeps its own sequence monotonic for an existing round and verifies
  fresh source ACKs. Snapshots, events and chat state are cleared on transport loss.
- Career now has **RESULTS** and **HISTORY** tabs. Results display known source
  round facts and a same-profile, same-actor, same-revision witnessed award. A
  reconnect replay with no award witness stays unknown. Equipment confirmation
  cannot be mistaken for an award, including malformed mixed frames.
- History is read-only and labelled **Recent server matches**. Requests are
  bounded; timeouts and delayed replies remain distinguishable from a fresh
  response. All-invalid records cannot fabricate an empty history. Fractional IDs,
  counters and XP remain unknown, while valid decimal durations are preserved.

## Integrated verification

Implementation tested at `b5b0ac4f` unless noted. Retained records:
`port/native-shell/evidence/reconnect-career-2026-09-28/`.

- **11/11 Node checks passed** at `025a531b`: source awards/results/history,
  Career storage/leases, source history retention/reload, corrupt-store refusal,
  external guest isolation, and dev/package supervisor persistence plumbing.
- Pinned Godot import passed at `025a531b`; the source-backed native reconnect
  fixture passed **59 checks**, including fresh-seat Career continuity and late
  welcome rejection. Offline source-settled result recovery also passed.
- Native Career projection/actions/modal/results/history/UI, protocol envelope,
  reconnect menu and social checks passed on the integrated implementation.
- **Rendered reconnect journey passed 11 checks**: an external source host and a
  real `world/session.tscn` guest, genuine socket termination, visible Retry/Leave
  at 960×640 / 150%, same actor/round/Career, fresh ACKs, no pointer recapture,
  cleared chat, and explicit Leave while the external host kept running.
- **Career results/history journey passed 19 checks**: a real 60-second source
  match, source award-before-results order, confirmed +40 XP, server history
  request and persistence, and 760×520 / 150% reader bounds.
- **18-session captured product journey passed**, with 19 Home and 18 live Career
  checks, source-confirmed equipment retained across processes and all owned ports
  closed. Existing combat/LATTICE/sports/Horde/Cinderwake/Nacre routes remain covered.
- The first full aggregate at `b5b0ac4f` stopped at gate 138/226 on the native-arena
  session fixture's missing queued-welcome context. `c62c3753` repairs that and
  related detached LATTICE fixtures. `05d7e5c3` replays the recorded outbound
  create/join before captured responses and omits only declared redacted
  credential placeholders. Live admission/token validation is unchanged.
  All affected headless fixtures passed, including the captured protocol and
  presentation replays. The render-only REQ fixture also passed with its required
  capture argument; an initial invocation without that argument exited 2.
- The second aggregate at `5555e402` reached gate 216/226 and caught a control
  safety regression: deferring failed input sends for reconnect had also deferred
  failures outside multiplayer. `5c519b5d` limits deferral to a previously open
  multiplayer transport with an actual reconnect ticket. Control safety, window
  focus, session recovery, stall controls and snapshot-watch checks passed, and
  the rendered Retry/Leave journey passed again. Both failed aggregates remain
  retained in the validation checkout and this batch's evidence directory.
- **Final aggregate passed 226/226 with zero unrun**, followed serially by
  **228/228 server tests** and lint with **zero errors** (916 warnings), at
  `5c519b5d35ebb82b3bebc30b8a989901a0ced203`. The source derivative remains
  `61fca35c65488502b794900cde0a5247bfb123bf`; its manifest SHA-256 remains
  `d1809086734c3df66573db5b7efc023b23a337ab2b05d4f5019e985d26e7cff7`.
  Retained report `verification-226.json` has SHA-256
  `f1b99980c605e2335b737e339ce1d3ad372ccadeb07bb95d23e772205c31de55`.
  Canonical `port/reports/verification.json` and gate logs now record this run.
- **General hosted CI passed** at pushed revision
  `683ead4998796910936e9db0b3910d540643f4be`: typecheck, game/server tests, web
  build, rendered deployment checks and lint. See
  [run 36513677793](https://github.com/mojomast/cocs-godot/actions/runs/36513677793).
  This result predates the subsequent Arsenal presentation batch.
- **Hosted native CI failed** at the same revision:
  [run 36513677768](https://github.com/mojomast/cocs-godot/actions/runs/36513677768)
  executed 184/226 gates: **183 passed, 1 failed, 42 unrun**. The failure was
  `horde-upgrade-fixture`: a stale input epoch refused the selection, then the
  native child hit its 30-second timeout. Input TTL resets surrounded the
  rendered offer capture; the test had launched that capture without awaiting
  completion before its key-delivery stage. Clean-runner acceptance remains open.
  The complete bounded hosted artifact is retained at
  `port/native-shell/evidence/reconnect-career-2026-09-28/hosted-native-36513677768/`.
  Its `reports/verification.json` SHA-256 is
  `b382630fd19fd6979232fef4d62a560853177bc2e7a9f193b416a28b51b05d65`;
  GitHub artifact ID `11010910764`, archive digest
  `7270282814d053c28b3103255fcdc9d4418acbcd494acf22038cc7082684be29`.
  A fixture repair is being verified with the subsequent Arsenal batch: await
  optional capture, settle ordinary acknowledged input before the synthetic
  press, and use a wall-clock observer deadline. Authority TTL, epoch validation
  and all existing positive-loopback assertions remain intact.
- **Subsequent hosted confirmation passed:** the integrated Arsenal batch at
  `b6eec0cf` passed **237/237 native gates, zero unrun**, including that fixture
  repair, in [run 36517857172](https://github.com/mojomast/cocs-godot/actions/runs/36517857172).
  General hosted CI also passed at the same revision. The earlier failed attempt
  above remains historical evidence; see
  [the Arsenal batch record](ARSENAL_PRESENTATION_BATCH_2026-09-28.md) for the
  retained successful artifact and report hashes.

The first rendered reconnect attempt at `025a531b` timed out before guest join:
the observer reused one mutable pressed/released event without allowing native
input processing. `b5b0ac4f` uses distinct events, settled focus/layout, and scaled
pointer coordinates. The failed attempt is retained separately.

Earlier Career lane evidence records `cdfbeaa8` with Sol's routing patch applied
locally during its run. The integrated `b5b0ac4f` journey above supersedes that
provisional composition for acceptance; neither historical report is rewritten.
