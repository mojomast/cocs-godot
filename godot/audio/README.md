# Native score and reviewed voice pack

`music_service.gd` is a self-contained Node. Instantiate it once, add it to the
scene tree, then call `bind(host)` and `start()` after an audio-unlocking user
action. The presentation loop calls `tick(delta)` once per frame. Set
`set_scene("menu" | "explore" | "combat" | "results")`, `set_mode_theme(mode_id)`,
`set_biome(mood)`, `set_intensity(0..1)`, `set_tension(0..1)`,
`set_escalation(0..3)`, `set_seed(int)` and `set_variation(int)` as game context
changes. `cue(id)` returns whether a voice take played; `status()` reports
transport/asset state. `set_settings({"music_volume":0..100,
"announcer_volume":0..100, "mute":bool, "music_enabled":bool,
"announcer_enabled":bool})` updates gain and switches. On blur call
`set_focus(false)`; on refocus call `set_focus(true)` and `start()` after user
interaction. `reset()` drops transport backlog and stops active voices. Free the
node at shutdown. No autoload, world references or shared project settings.

The composition entry point is `res://audio/av_service.gd`: it owns this
score, source-event dedupe, objective earcons, mounted-only foley and the
opt-in weather node. Use `bind_session(owner, camera, source_arena, mode,
round_identity, seed)`, `start_round(round_identity)`,
`apply_snapshot(authority_state, local_actor_id, freshness)`,
`apply_events(authority_events)`, `tick(delta)`, `finish(outcome)` and
`apply_settings(LocalSettings.values)`. `status()` includes bounded
voice/stream/route/weather counters. Detailed owner-only hooks are in
`port/native-audiovisual/HOOK_REQUEST.md`; no overlapping world/Horde/LATTICE
files are changed by this branch.
The delivered Moth `bed-ritual` clip is copied byte-for-byte with a SHA-256
manifest and a 0.5–10.5s loop in menu/exploration only. Its rights are not
relabelled as music-sample CC0; no unshipped beds or convolution IR are claimed.

Native score adapts the browser's original D minor COCS motif (16 degrees),
modal eight-chord sequences and scene-specific tempos. Its shared 32-bar form
has 8 intro, 8 build, 8 climax, 4 transition and 4 outro bars; escalation
compresses the form to 24/16/8 bars. Menu augmentation, exploration statement,
combat inversion, results' Picardy inflection, per-bar seeded ornaments,
palette-based register/percussion, harmonic thirds, fill gestures and adaptive
ostinato use 37 original CC0 Ogg instruments. This is a native rearrangement
of `game/music.mjs`, not a sample-perfect port: imported Godot Ogg streams
cannot use the browser sampler's attack/loop region API, and only a curated
subset of the browser's 172 samples ships. No choir recording is claimed.
Polyphony is capped at 19 score players plus one reserved announcer voice;
missing samples cause silence for that note. Frame gaps >300 ms are discarded.

The 36 reviewed `OmniVoice Studio` takes (three each for twelve phrases) are
byte-for-byte copies of `public/audio/announcer/`. The voice manifest preserves
their generator, text, seeds, SHA-256, duration, studio take ID and recipe; it
does **not** assert ownership or a licence absent from the source metadata.
Cue IDs map exactly to their recorded text:

| `cue(id)` | Phrase | Intended trigger |
| --- | --- | --- |
| `capture` | Flag captured! | flag capture confirmed |
| `flag-pickup` | Flag taken! | flag picked up |
| `flag-return` | Flag returned! | flag reset/return |
| `goal` | Goal! | soccer goal |
| `killstreak` | Kill streak! | streak milestone |
| `spree` | Killing spree! | spree milestone |
| `multikill` | Multi kill! | multi-kill window |
| `victory` | Victory! | confirmed win |
| `defeat` | Defeat. | confirmed loss |
| `score` | Score! | score event |
| `boss` | Boss incoming! | boss appearance |
| `objective` | Objective updated. | objective change |

The host must pass these cue IDs only for the corresponding confirmed event;
the service never infers an outcome from music state. Repeated IDs debounce
for 1.8 seconds and different IDs for 0.5 seconds. A busy announcer drops
incoming lower-priority cues instead of building a queue; goal and round result
can preempt. Muting/blur stops voice immediately. Take selection rotates
deterministically without an immediate repeat per cue.

Repackage from unchanged source files with
`node tools/godot-audiovisual/music_pack.mjs`; verify without writing with
`node tools/godot-audiovisual/music_pack.mjs --check`. The script verifies every WAV
against its source SHA-256 and writes native Ogg SHA-256 in
`music/manifest.json`. Upstream sample provenance and CC0 terms are documented
in `assets/music/THIRD_PARTY_LICENSES.md`; native manifests retain per-sample
source/licence URLs. No AAC fallbacks or intermediate generated audio ship here.
