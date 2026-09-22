# Native procedural audio feedback

`godot/world/audio_feedback.gd` provides `PortAudioFeedback`, a self-contained
`Node` with four original generated mono 16-bit `AudioStreamWAV` cues. No imported
assets, packages, network access, global input handling, or audio-device probing.
Built against base `d06b681` and Godot **4.5.2.stable.official.6ce3de25a**.

## Integration (lead-owned combat feedback)

Create one child once the combat feedback node enters the tree:

```gdscript
const AudioFeedback = preload("res://world/audio_feedback.gd")
var audio_feedback := AudioFeedback.new()

func _ready() -> void:
    add_child(audio_feedback)
```

Add these calls inside the existing corresponding methods:

```gdscript
# CombatFeedback.apply_events(items: Array, local_id: int):
audio_feedback.apply_events(items, local_id)

# CombatFeedback.clear_round():
audio_feedback.clear_round()

# The separate mute/UI lane calls this on the audio child:
audio_feedback.set_muted(muted)
```

The caller supplies **active, deduplicated authoritative server events**. Event-ID
deduplication stays in the existing client, and round/session gating stays in the
caller. Calls while detached from the tree are ignored. Child ownership handles
freeing; `_exit_tree()` stops voices. Generation is synchronous, bounded to about
13k total samples, cached once at ready/lazy initialization; playback does not
regenerate samples, wait, or create nodes.

| Authoritative event | Cue | Length | Minimum interval |
|---|---|---:|---:|
| `shot`, actor = local | Damped noise + descending low tone | 110 ms | 65 ms |
| Positive `damage`, valid other actor, source = local | Short two-tone hit tick | 75 ms | 80 ms |
| Positive `damage`, actor = local | Descending low hurt tone | 180 ms | 140 ms |
| `pickup`, actor = local | Rising pickup chime | 220 ms | 180 ms |

`shot.hit` never triggers confirmation. Null/missing/invalid source cannot become
actor zero; environmental and self damage can hurt but never confirm a hit.
Remote shots/pickups, unknown event types, malformed/missing actor IDs, and
non-finite/nonpositive/nonnumeric damage are silent. JSON integral float IDs are
accepted, but strings, booleans, fractional IDs and negative IDs are rejected.

Eight fixed `AudioStreamPlayer` children route to **Master**, each at **−16 dB**.
A full pool drops new cues; per-kind monotonic-time limits suppress burst repeats
while allowing distinct shot/hit/hurt/pickup feedback together. Samples are
bounded to 0.65 full scale, so the conservative sum of eight voices is below 0.825
full scale at default gain. Other game audio or boosted Master gain is outside
that calculation. Attack/release envelopes end at zero. Total cached PCM is about
26 KB. `clear_round()` stops all players and resets cooldowns while retaining
cached sounds and mute preference. `set_muted(true)` also stops existing tails;
unmuting never replays muted events.

## Focused verification

```sh
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --headless --audio-driver Dummy --path godot \
  --script res://tests/protocol/audio_feedback.gd
```

**34 checks passed**, including authoritative filtering, actor zero/null handling,
no predicted hits, self/environmental damage, a 100-batch event burst, cooldown
recovery, fixed/full pool behavior, immediate round cleanup, persistent mute,
natural one-shot completion, and freeing during playback. The test allows an
AudioServer mix iteration after freeing to release stopped playback references.
Final exit **0**, no script errors or leak warnings. See
[`verification.txt`](verification.txt) for the retained final output.

The test measures generated PCM duration, peak, RMS, zero crossings, and zero
endpoints. These establish non-silence and source/mix headroom, not perceived
sound quality. **No human listening, live-server audio integration, or physical
audio-device acceptance is claimed.** The project uses Compatibility rendering;
the focused check runs headlessly with Dummy audio and needs no GPU/audio device.
# Integration status

The lead connected this module to `combat_feedback.gd`: active deduplicated
authority events now drive native cues, and round/session cleanup stops voices.
Use Godot's `--mute` user argument to silence these cues. The full verifier now
includes the audio gate. Independent module and attached-combat integration
checks pass **37/37** with Dummy audio; existing combat replay passes too.
Human listening remains pending.
