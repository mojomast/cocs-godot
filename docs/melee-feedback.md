# Accepted melee audio and contact shockwave

`godot/world/combat_feedback.gd` composes `melee_feedback.gd` for the shared native/source combat, Horde and campaign presentation path. It consumes public events only. Input edges, acceptance cooldown, damage, protected-target handling and knockback belong to authority.

## Authority contract

```json
{
  "type": "melee", "id": 42, "time": 12.5, "actor": 7,
  "pos": {"x": 0, "y": 1, "z": 0},
  "hit": 8,
  "impact": {"x": 0, "y": 1, "z": -1.2},
  "direction": {"x": 0, "y": 0, "z": -1}
}
```

- Preserve `pos` as the accepted kick origin. Every accepted melee with a valid origin can play one short movement whoosh, including a miss.
- `hit` must be the **actually damaged** victim ID, or `null` on a miss, obstruction, protection rejection or other non-damaging target. It must not name merely a selected candidate. `blocked: true` / `protected: true`, if supplied, also suppress contact feedback.
- Additive optional `impact` is the actual world-space contact. Optional `direction` is the world-space strike direction (attacker toward target); ring normal follows that direction. Neither changes `pos`.
- For older accepted hit events without contact fields, the public victim position plus 0.9 m supplies body centre, and origin-to-contact supplies direction. If neither contact nor victim is available, the consumer plays only movement, rather than inventing a contact.
- Public event IDs are consumed once with a bounded 4096-ID window. Invalid IDs/actors/timestamps are rejected. Suspension consumes/drains events; a round boundary resets the ID epoch.

## Sound and visual design

`audio_feedback.gd` synthesizes two original deterministic, cached mono PCM cues from its existing noise banks. No external recording or rights dependency:

- **Whoosh (160 ms):** quick swelling filtered air sweep, falling cloth/body movement, light low movement tone.
- **Impact (220 ms):** dry broadband crack, falling 118–43 Hz thump, low material body and short tail. Same-batch source/victim/time-matched melee damage does not also play the last gun's generic hit voice.

Both cues share the existing 22.05 kHz, 16-bit, zero-ended envelope and 0.65 peak ceiling. Sixteen preallocated `AudioStreamPlayer3D` voices route through Effects → Master, with 3 m unit attenuation and a 32 m maximum distance. There is no client-side gameplay cooldown or repeated-key sound. Pool saturation drops excess presentation cues.

Confirmed contacts emit a depth-tested, world-oriented warm ring, expanding from 0.12 to 0.85 m over 220 ms. It is not a camera billboard or fullscreen shake. Twelve preallocated mesh/material slots share one torus mesh. Low quality and the device-local `reduced_motion` preference retain four slots with 160 ms / 0.55 m cues. Mute drains audio immediately; focus/staleness/round teardown drains sounds and rings. Settings changes use the existing `LocalSettings.audio_preferences_changed` path.

## Verification and human review

The following require the parent's engine/heavy-test slot; they were **not run in the implementation lane**:

```sh
godot --headless --path godot --script res://tests/protocol/melee_feedback.gd
godot --headless --path godot --script res://tests/protocol/audio_feedback.gd
godot --headless --path godot --script res://tests/protocol/export_melee_audio.gd
```

The new contract test covers accepted miss versus hit, duplicate/rejected/malformed events, blocked/protected/self targets, explicit and legacy contact placement, ring direction/expansion/expiry, muted playback and settings bus routing, suspended-event replay, fixed pool budgets, Low/reduced-motion settings, dedup-window expiry, round reset, missing legacy target, damage-voice matching, deterministic/cache-bounded and peak-bounded PCM. Existing protocol audio tests cover the shared weapon synthesis regression.

The export script prints paths for `user://melee-whoosh.wav` and `user://melee-impact.wav`, containing the exact dry cached PCM for audition. Those are pre-bus signals: in-game attenuation and volume settings still need listening in a live session. No listening or graphical acceptance is claimed here.

For live acceptance after merging authority changes: press F once into empty space, rapidly press/release F into a damageable target, hold F, then strike a protected target. Check one whoosh per accepted kick; one smack/ring per actual hit; authoritative enemy knockback; no held-key repetition. Repeat at Low and reduced motion, mute/unmute, focus loss, reconnect and round transition. View an oblique contact to confirm the ring stays world-oriented and respects depth.
