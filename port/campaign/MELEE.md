# Melee kick upgrade

## Requested behavior

- An audible swoosh for each accepted kick, including a miss.
- A distinct, satisfying impact smack when the kick actually connects.
- One kick attempt per fresh button press; holding the button never repeats.
- A short cooldown for rapid repeated tapping (initial tuning target: 0.30 s).
- Authority-controlled enemy knockback, respecting world collision.
- A brief shockwave at a confirmed impact, with no false hit effect on misses.

The existing F-bound first-person leg animation is already integrated. Its
authority-event admission and deduplication remain the basis for feedback.

## Implementation lanes

- `campaign/melee-authority`: shared authoritative mechanics, explicit source
  provenance where necessary, input edge behavior and gameplay regression tests.
- `campaign/melee-feedback`: shared native kick/impact audio, bounded shockwave
  visuals, settings/lifecycle integration and feedback regression tests.

Both lanes work in isolated worktrees. The campaign capture-repair lane retains
the heavy verification slot until it releases it. No new export is final until
this requested kick upgrade is integrated and verified.

## Acceptance

Check repeated tapping and held-button behavior, cooldown rejection, misses,
actual hits, protected/allied/dead targets, wall collision, and terrain support.
Effects must follow authoritative events, avoid duplicate replay, respect audio
and effects settings, and clear on session lifecycle boundaries. Automated
signal/geometry checks do not establish subjective audio satisfaction; an
audition artifact should accompany the implementation for review.

## Integration checkpoint

Feedback implementation `2d872ac3` is integrated as `a0f38f5a`: short synthesized
whoosh and impact layers, spatial Effects-bus playback, bounded event deduplication
and pooled contact rings. Engine verification and WAV audition export are pending
the heavy slot. The mechanics lane is implementing the matching event contract:
`pos` remains the origin; `impact` and `direction` describe contact; `hit` is null
unless a target actually received damage. See `docs/melee-feedback.md`.

The mechanics branch is merged preserving `0326b435` ancestry for explicit source
derivative verification. It implements the 0.30 s cooldown, fresh-press admission,
bounded 0.85 m collision-swept shove and actual-damage event contract. Its input,
gameplay and integration tests await the shared heavy verification slot; syntax
and three Git/text provenance checks passed in isolation. Full pending commands
and event fields are in `port/MELEE_AUTHORITY_2026-09-30.md`.
