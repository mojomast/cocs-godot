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
