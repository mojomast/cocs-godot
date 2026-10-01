# The Quiet Relay — scripted in-engine trailer

## Delivery state

The trailer is rendered video. The menu uses a **live in-engine scripted replay**;
the owner canceled the earlier Theora menu-video plan.
**Completed:** `/home/mojo/.tmp-on-disk/cocs-trailer-evidence-20260930/quiet-relay-trailer.mp4`.
48.000 seconds, 1,152 frames, H.264 960×540 / 24 fps, stereo AAC 48 kHz,
15,639,711 bytes. SHA-256:
`28740c780f71ef88efbdfba94955e8492801e9c9085d937eac3551debb97c1f1`.

Initial base `8b1bacbc`, integrated with parent `19884ca1`, branch `campaign/trailer`.
Do not install a menu movie or substitute prerendered images for the live viewport.

The release caption and trailer credit are **“Scripted in-engine footage.”**
These are actual Godot campaign terrain, operators, robots, animation, effects
and HUD pixels. Composition, progression start points, camera paths and some AI
are staged. They do not demonstrate organic traversal, difficulty or performance.
There are no generated substitute game images or commercial media assets.

## Edit / storyboard

48 seconds, 24 fps, 960×540, **1,152 captured frames**. The orchestral score is
48 seconds / 16 bars / 80 BPM; every main edit is on a three-second bar boundary.
`tools/godot-campaign/trailer.json` is the executable source of timing and text.

| Time | Shot | Picture / action | Edit and sound |
|---|---|---|---|
| 00–03 | Forest | Closer Rootfall aerial reveal; foreground depth | “A SIGNAL BENEATH THE SILENCE”; strings establish |
| 03–06 | River | High Siltwake sweep, same screen direction | “FOUR CONNECTED CHAPTERS”; movement match cut |
| 06–09 | Forge | Closer Emberline ridge sweep | Let the environment breathe |
| 09–12 | Crown | High Crown terrain, elevated destination | Match direction, open scale |
| 12–15 | Mara | Textured operator, authored proximity dialogue | Three-frame dip, small namecard above subject |
| 15–18 | Ivo | Textured operator and authored greeting | Readable namecard; game caption retained |
| 18–24 | Patch | Approach held near puppy; logical E at 19s; accepted reaction | Six seconds for prompt, wag/reaction and caption; motion enters gently |
| 24–27 | Automata | External real scrapper/skirmisher/sentinel encounter | “BREAK THE QUARANTINE”; brass enters |
| 27–33 | Fire | First-person real attack/hit/damage presentation | No marketing text over combat; sparse event-aligned SFX |
| 33–36 | Kick | First-person bulwark melee, real damage/knockback/shockwave | Real melee impact, no fake hit animation |
| 36–39 | Danger | External mortar and actual authority danger ring | Warden layer builds; artillery punctuation |
| 39–42 | Warden | Low three-quarter hero camera on real boss chassis | “THE LAST GUARDIAN”; leave silhouette visible |
| 42–48 | Relay | Moving Crown vista under ending title | THE QUIET RELAY / FOUR CONNECTED CHAPTERS / PLAY THE CAMPAIGN; score cadence |

The opening and final vistas are animated inspection cameras. Encounter clips
replay the real production authority's fixed-step simulation; attacks, damage,
pet eligibility and reaction serials are never manufactured by the renderer.
NPC greetings are proximity-driven story interactions; the game does not offer
a separate conversation-choice mechanic. The short namecards are promotional
copy, not fabricated NPC quotations. Actual dialogue stays in the game widgets.

Typography uses local DejaVu Sans Bold by default (redistributed font is not
needed). Trailer-only letterbox is 22px top/bottom. No marketing overlays appear
during FP combat. Actor cameras use a restrained 0.8-radian arc with ground
clearance. Terrain cameras dolly across the authored overview with matched
direction; the initial near-ground prototype was rejected for ridge occlusion.

## Authority provenance and determinism

`trailer-fixture.mjs` is an isolated trusted fixture, never imported by runtime.
It instantiates production `createCampaignMatch`, validates the real input
envelope and applies the production `InputBuffer`. Rendering uses a streamed
JSONL replay rather than wall-clock networking: alternating two/three production
60 Hz ticks per 24 fps output frame. A seeded RNG and integer frame-indexed
actions fix simulation/camera timing. Each shot resets its authority and seed.

Patch receives a logical **E / `interact: true` input**, not a call to a visual
pet method. `receipt.json` includes the input sequence, applied FIFO ACK,
accepted pet count and `reactionSerial`; full states/events remain in JSONL.
These are **offline application ACKs, not WebSocket ACKs or a live-input test**.
If converted to a live fixture later, actual E delivery through the client and
authority wire ACK must replace this offline receipt, and its pet serial must
still be logged. The renderer only observes accepted story states.

AI suppression sets composed combat actors' bot controller to null; source
physics, collision, player fire/melee, damage, role updates and story rules run.
Mortar initial cooldown is staged to 0.75s, then its real role emits the ring.
Preparation fails if pet, damage, melee or artillery proof is missing. This is a
deliberate repair point: adjust fixture positions, never synthesize success.

PNG capture keeps one decoded snapshot/image at a time; each file is saved
immediately. Each shot has a separate Godot process. Fixed FPS controls visual
time; replay hashes identify the simulation. Pixel-identical output across
different GPUs/drivers is not promised (GPU particles/materials may differ).
The fixture subclasses the session solely to disable network-driven input and
wall-clock camera interpolation. It uses the production first-person rig with
the replay's actor/events; no gameplay changes are installed in runtime.

## Commands — after heavy-slot grant

Run in the integrated checkout once its required music/model/authority changes
are available. Prepare authority data in the slot as well if integrated checks
are still using substantial CPU. Evidence is outside the repository.

```bash
EVIDENCE=/home/mojo/.tmp-on-disk/cocs-trailer-evidence-20260930
STEMS=/home/mojo/.tmp-on-disk/cocs-relay-campaign-20260930/godot/audio/music/orchestral

# First: authority proof and a two-second sample at FINAL resolution.
node tools/godot-campaign/trailer-capture.mjs --prepare --shot=patch --output="$EVIDENCE"
node tools/godot-campaign/trailer-capture.mjs --render --slot-granted --shot=patch --frames=48 --output="$EVIDENCE"

# Visually inspect frames 000000, 000024, 000047 plus the receipt. Then sample
# fire and a terrain shot similarly. Check models, lighting, real hit numbers,
# framing, camera/rig visibility, readable story caption and pet serial > 0.
# --prepare does NOT launch Godot or render; --render requires imported assets.

# Full capture only after samples pass. Reuses/overwrites those initial frames.
node tools/godot-campaign/trailer-capture.mjs --prepare --render --slot-granted --output="$EVIDENCE"

# Resume only complete, error-free shots after interruption:
node tools/godot-campaign/trailer-capture.mjs --render --resume --slot-granted --output="$EVIDENCE"

# Export exact production PCM and align accents to actual event frames:
TRAILER_SFX_OUTPUT="$EVIDENCE/sfx" "$GODOT_BIN" --headless --path godot --script res://tests/campaign/trailer_sfx.gd
node tools/godot-campaign/trailer-sfx-cues.mjs --evidence="$EVIDENCE"

# Plan only: emits reproducible timeline and shell commands; no FFmpeg launched.
python3 tools/godot-campaign/trailer-edit.py --evidence="$EVIDENCE" --stems="$STEMS"

# Execute only while still owning the slot. Add --sfx=/path/to/cues.json after
# choosing actual game SFX and confirming event timestamps in replay JSONL.
python3 tools/godot-campaign/trailer-edit.py --evidence="$EVIDENCE" --stems="$STEMS" --sfx="$EVIDENCE/sfx-cues.json" --execute --slot-granted

# Compact live-engine menu data, no rendering/video decoding:
node tools/godot-campaign/trailer-demo.mjs --evidence="$EVIDENCE"
```

SFX cue schema: `[{"path":"/absolute/checkout/game-asset.wav","at":28.0,"gainDB":-12}]`.
Use real shot, melee and artillery sounds at the recorded event timestamps;
avoid continuous gunfire walls. Cues must point inside the current checkout or
the owned evidence/sfx export directory,
have in-range times and gain at most -6 dB. Empty cues are supported for the
music-only rough cut; the finished public cut should include reviewed accents.

Audio mix uses actual strings/motion/brass/warden stems without stretching,
bar-aligned layer changes, a soft ending and measured two-pass loudness
normalization to **-16 LUFS / -1.5 dBTP / LRA 9**. Preserve
`loudness-measured.json`; targets alone are not a measured result. The command
plan is generated first, but execute mode regenerates it with measured values.
The 72-second adaptive audition is not required: the exact 48-second stem form
provides the intended whole-phrase cadence.
The encoding ceiling is -2.2 dBTP to leave AAC headroom. The **decoded final AAC**
measures **-16.03 LUFS, -2.20 dBTP, LRA 4.80 LU**. The first master reached
-1.05 dBTP after AAC encoding and was remastered; its evidence is retained under
`pre-aac-headroom-*`. `--reuse-picture` reuses reviewed picture intermediates for
this audio-only remaster; copied H.264 stream MD5 remained
`d706e66d9cc97a24fe35b9b880c47cce`. No time-stretching or music tempo change.

## Separate live in-engine beneath-menu replay

The main menu remains **visible, functional and continuously over the 3D viewport**,
as in original CoCS: no idle wait, takeover, or “Press any key” screen.

`trailer-demo.mjs` exports `godot/ui/attract/demo.json` against the exact
`port/campaign/ATTRACT_DEMO.md` version-1 contract: fps 12, provenance with
scripted/authorityRevision, clips with id/map/kind/camera/duration/focus, frames
with t/state/events. Production actors and campaign/story state retain pet
reaction serials. **Every event** from both 24 Hz source frames is aggregated
into each retained 12 Hz frame; downsampling discards no events.

Four clips: forest (3s), Mara (3s), Patch (6s), fire (6s), approximately 1.43 MB
for 18 seconds. All request orbit cameras. The menu lane owns live camera
interpolation, looping, visibility and cleanup in its real Godot SubViewport.
This is state data, not video or images. No menu movie is generated/installed.
The menu's existing orchestral service owns audio; replay data adds no sound.
Input/ACK receipts remain in external evidence rather than the runtime asset.

Public output: `quiet-relay-trailer.mp4`, H.264/yuv420p + AAC 192k, faststart.
Evidence includes per-shot invocation/log/receipt, JSONL states/events, PNGs,
edit timeline/commands, loudness measurement, ffprobe metadata and SHA-256s.
The menu export records retained frame/event counts, source hashes and pet
receipts separately in `demo-export-audit.json`.

## Completed capture and review

- All 13 shot preparations and graphical runs pass. Exactly 1,152 numbered PNGs;
  all Godot logs contain success markers and no script/resource errors.
- Patch accepts E at frame 24 / input sequence 25, applied sequence 25,
  `pets=1`, `reactionSerial=1`. No visual pet method is called by capture tooling.
- Fire records ten actual player damage events. Kick records one melee hit and
  actual damage; the rendered foot, “45” number and shockwave were inspected.
- The actual artillery role emits a danger ring, visible in the final MP4.
- Samples were inspected before full capture. Repairs addressed imported-resource
  availability, NPC/puppy facing, rifle aim at the real small chassis hit volume,
  camera obstruction and NPC/Warden framing. Rejected evidence was preserved.
- Final contact sheet covers all acts; final decoded PNGs confirm readable
  captions, typography, Patch reaction, melee/ring and ending title. Picture
  stream identity was rechecked after the audio-only remaster.
- Five original production PCM cues were exported through the game synthesizer;
  27 sparse accents align to real recorded event frames. Audio QC checks decoded
  loudness/true peak and event timing. The source orchestral audition was reviewed
  by the parent; this lane does not claim a separate subjective listening pass.
- Full MP4 decode passed. `final-validation.json`, `final-loudness.json`, probe
  metadata, SHA-256 and edit command/timeline files accompany the media.
- Live-menu export retains every original event exactly once: forest 1, Mara 1,
  Patch 1, fire 227 (230 total). 216 runtime snapshots, 18 seconds, 1,428,193 bytes.
  Parent/menu lane owns the integrated live viewport/UI/focus/cleanup checks.

Useful extracted media in the evidence directory: `final-contact-sheet.png`,
`poster.png`, `pet-confirmed.png`, `melee-confirmed.png`,
`artillery-confirmed.png`, `end-frame.png`. These are actual decoded MP4 frames.
No Theora/menu video was generated or installed.
