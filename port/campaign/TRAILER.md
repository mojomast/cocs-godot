# The Quiet Relay — scripted in-engine trailer

## Delivery state

**Prepared tooling/storyboard; capture and media are pending the exclusive heavy
slot. No MP4 or OGV has been rendered or visually approved by this lane yet.**
Base: `8b1bacbc3d4128c84e0af101ac02d7ddd8d2875e`, branch `campaign/trailer`.
Do not publish a readiness flag or install a placeholder at the menu asset path.

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
| 00–03 | Forest | Low moving Rootfall terrain reveal; foreground depth | “A SIGNAL BENEATH THE SILENCE”; strings establish |
| 03–06 | River | High Siltwake sweep, same screen direction | “FOUR CONNECTED CHAPTERS”; movement match cut |
| 06–09 | Forge | Low Emberline ridge sweep | Let the environment breathe |
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
during FP combat. Camera movement is a restrained 0.8-radian arc with ground
clearance, matching left-to-right across chapters. Final visual review must
confirm the authored arc actually sees the biome and doesn't traverse props.

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

# Plan only: emits reproducible timeline and shell commands; no FFmpeg launched.
python3 tools/godot-campaign/trailer-edit.py --evidence="$EVIDENCE" --stems="$STEMS"

# Execute only while still owning the slot. Add --sfx=/path/to/cues.json after
# choosing actual game SFX and confirming event timestamps in replay JSONL.
python3 tools/godot-campaign/trailer-edit.py --evidence="$EVIDENCE" --stems="$STEMS" --execute --slot-granted
```

SFX cue schema: `[{"path":"/absolute/checkout/game-asset.wav","at":28.0,"gainDB":-12}]`.
Use real shot, melee and artillery sounds at the recorded event timestamps;
avoid continuous gunfire walls. Cues must point inside the current checkout,
have in-range times and gain at most -6 dB. Empty cues are supported for the
music-only rough cut; the finished public cut should include reviewed accents.

Audio mix uses actual strings/motion/brass/warden stems without stretching,
bar-aligned layer changes, a soft ending and measured two-pass loudness
normalization to **-16 LUFS / -1.5 dBTP / LRA 9**. Preserve
`loudness-measured.json`; targets alone are not a measured result. The command
plan is generated first, but execute mode regenerates it with measured values.
The 72-second adaptive audition is not required: the exact 48-second stem form
provides the intended whole-phrase cadence.

## Separate beneath-menu cut

The main menu remains **visible, functional and continuously over the movie**,
as in original CoCS: no idle wait, takeover, or “Press any key” screen.

Menu footage is selected from the clean intermediates (forest, river, forge,
Crown, Mara, Patch, fire). No promotional overlays, title cards, letterbox,
black-frame ending or audio are added. Internal 0.25s dissolves and a 0.5s
tail-to-head seam create an approximately **25-second loop**; movement remains
around the interface. Native dialogue/HUD may remain visible in the underlying
picture; review with the actual menu to avoid competing text at its controls.
The menu's own orchestral service supplies music; the Theora stream is silent.

Output: `quiet-relay.ogv`, Theora 960×540/24fps, 1.4 Mbit/s target, hard checked
at <=20 MiB and no audio stream. Install the approved output at
`godot/ui/attract/quiet-relay.ogv` (**`res://ui/attract/quiet-relay.ogv`**).
The separate menu component owner handles loading/looping/visibility. This
tooling does not alter the menu or mark an absent/broken movie ready.

Public output: `quiet-relay-trailer.mp4`, H.264/yuv420p + AAC 192k, faststart.
Evidence includes per-shot invocation/log/receipt, JSONL states/events, PNGs,
edit timeline/commands, loudness measurement, ffprobe metadata and SHA-256s.

## Pending acceptance before publication

1. Grant slot; prepare fixtures; repair any failed real-action receipts.
2. Godot parse/import and two-second graphical samples (Patch, fire, terrain).
3. Inspect the actual samples before rendering the 1,152-frame full sequence.
4. Listen to the measured stem mix; select and align real SFX accents.
5. Inspect MP4 start/mid/end and readable NPC/Patch beats; check real melee
   knockback/shockwave and mortar ring appear on camera, not only in the log.
6. Inspect menu seam twice beneath the actual menu UI, confirm moving scenery
   remains visible, no title crop/black flash/audio, and OGV decodes in Godot.
7. Install only approved OGV, provide public MP4 path/link and retain evidence.

No rendering, audio encoding or Godot import was performed while the music
audition lane held the exclusive slot. These are pending actions, not passes.
