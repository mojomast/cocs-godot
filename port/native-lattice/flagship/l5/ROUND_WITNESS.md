# L5 bounded full-round two-native-client witness (opt-in)

Status: **implemented, not run**. This documents an opt-in evidence path in
`port/tools/native_lattice_flagship/two_client.mjs`. It is a bounded,
engine-driven, two-independent-native-client *full-round* witness. It is **not**
an acceptance result, and it does **not** close MVP-C1. Only live execution plus
human/UI review can do that.

## What is new

`--full-round` (which requires `--engine-driver`) extends the existing two-client
runner from the short 45-input smoke to a bounded full source round:

1. Pre-start gate unchanged: both clients join one owned loopback room and the
   recipient-published roster must show the guest plus two distinct peers.
2. Engine-scripted Start is written only after that gate; the source `start` and
   two distinct recipient-assigned actors must be observed.
3. Both clients keep sending ordinary scripted inputs. When the source publishes a
   terminal `results` state, **both** independent recipient sockets must have
   received it, with the local assignment and the running round revision
   confirmed by a recipient snapshot.
4. The host probe then issues only the **ordinary restart request**
   (`res://lattice/world_demo.gd` `world_restart_requested`, i.e. a `start`
   frame). The server mints the authoritative restart. A clean restart means
   **both** sockets receive a later `start` round revision and a snapshot bearing
   that revision.
5. Each native client independently reports terminal/restart facts
   (`LATTICE_PAIR_PROBE`). Those reports must match the recipient socket's peer,
   actor and winner, and must be `engine_input: true, human_input: false`.

The short `--engine-driver` smoke keeps its existing semantics and status
(`ENGINE_SMOKE_OBSERVED`); the full-round path has its own evidence class and
status (`ENGINE_FULL_ROUND_OBSERVED`).

## Run (only after marker authorization)

```
GODOT_BIN=/path/to/Godot \
node port/tools/native_lattice_flagship/two_client.mjs \
  --engine-driver --full-round --map=asterion-relay --mode=cocs --limit=180
```

Optional bounds: `--limit` (60..900 source seconds), `--max_rows`, `--max_bytes`.
The marker (`/home/mojo/.tmp-on-disk/cocs-lattice-engine-slot-granted`) and
`GODOT_BIN` are required; the pinned source lock Godot version is checked.

## Classification and claims

The witness distinguishes:

- `terminal_class`: `source-winner-team-0`, `source-winner-team-1`, or `draw`.
- `operations_outcome` for `cocs-coop`:
  `operations-complete` (`winner 0`, `operation-complete`), `operations-failure`
  (`winner 1`, or `operation-failed` / `hq-destroyed` / `hq-lost` / `team-wipe`),
  or `operations-unknown`.

Claims `five_wave_win` and `human_identity` are **always false** on this path:
scripted engine input cannot earn either, even at `waves.cleared === 5`. Wave and
HQ numbers are reported only as recipient-observed values.

## Wire completeness or explicit cap failure

The recorder writes the full wire up to a hard cap and **counts** every dropped
record (`capture.dropped`). The old behaviour of silently truncating was removed.
For a full round, any drop makes the evidence `CAPTURE_CAPPED` and never
`ROUND_OBSERVED`; the artifact states the exact rows/bytes cap in force. The
default full-round cap is 500,000 rows / 512 MiB and can be lowered or raised
explicitly; a long 900 s round may legitimately exceed it, in which case the run
must be shortened with `--limit` or re-run with a larger cap.

## Negative tests (synthetic, no engine)

`node --test port/tools/native_lattice_flagship/two_client.test.mjs` covers:

- missing terminal `results` on one recipient socket;
- missing clean restart on one recipient socket;
- any dropped record forcing `CAPTURE_CAPPED`;
- shared/unsnapshotted identity forcing an identity mismatch;
- independent native reports that disagree on peer/actor/winner, or that claim
  human input, forcing `INCOMPLETE`;
- operations failure vs completion classification, with the five-wave and human
  claims staying false.

These tests were **not run** in this delivery (engine/marker constraints); only
`node --check` and `git diff --check` were run. The exact test results are unverified.

## Explicit limitations

- No live run and no screenshot/UI review were performed here. Nothing in this
  lane proves native behavior.
- Scripted engine input is not human input. A source winner is not a five-wave
  win, a capture, or an accepted rung.
- The restart is a host **request** recorded on the ordinary wire; the witness
  never synthesizes an authoritative `results`/`start` event.
- Guest inability to start/configure remains `UNVERIFIED` (outgoing frames are
  observational only).
- No source, server, source lock, or client gameplay rule was edited.
- C1 (and MVP-A/B/C2) remain **PENDING** until live execution and human/UI
  acceptance. Do not treat the static fixtures as acceptance.
