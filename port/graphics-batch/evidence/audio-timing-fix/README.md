# Hosted audio timing assertion correction

Hosted run `35714417241` passed both production map traversals and all graphics
gates, then failed the inherited audio fixture's exact-four-playing-voices check.
Audio mixing uses a separate clock/thread; four short sounds can drain and later
events can validly retrigger while the main thread is descheduled.

The fixture now checks each accepted replay against its actual monotonic cooldown
and verifies the fixed eight-player pool after every burst submission. It retains
the independent real Dummy playback, natural completion, mute/reset, saturated
pool and combat-forwarding checks. Production audio is unchanged.

- `normal.log`: 38 checks pass, four remaining voices, no retriggers.
- `stalls.log`: 38 checks pass with five explicit 100 ms scheduler stalls,
  14 lawful retriggers and five remaining voices. The former exact-four assertion
  would reject this valid execution.
- `removed-cooldown-mutant-final.log` / `mutation-result-final.json`: a temporary
  private audio-script copy with the cooldown guard removed fails the strengthened
  burst assertion, as intended. No runtime mutation was committed.
- The earlier subclass-based mutant erased timestamp entries during saturation
  and failed with a dictionary-access error instead. Its log/result remain as
  setup-failure evidence; the first unbounded attempt timed out at 30 seconds.
  The corrected mutation preserves timestamp bookkeeping and uses a frame limit.

Original hosted failure: `../hosted-audio-timing-failure/`.
