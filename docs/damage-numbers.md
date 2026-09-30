# Authority damage numbers

`godot/world/damage_numbers.gd` is the shared combat composition's passive
damage-number renderer. Native combat, Horde and campaign use the existing
`combat_feedback.gd` integration.

- `damage.actor` is the victim, `damage.source` is the attacker, and `amount`
  is the only numeric authority. The core emitter includes absorbed damage in
  this amount; the number therefore reports the event total, not health lost.
- Outgoing local hits use an explicit event `pos` when present, otherwise the
  received victim position plus a cosmetic one-unit body anchor. The current
  core damage emitter supplies no position. The anchor is frozen, never follows
  a moving target, and camera/map occlusion is checked again while drawing.
- Incoming local damage, including environmental/self damage, is signed and
  orange in the lower-left central clear lane. Other actors' exchanges do not
  appear. There are no critical-hit predictions or labels.
- A fixed 100ms same-victim window sums source fractions before half-up integer
  display rounding (`0 < total < 0.5` reads `<1`). The first hit appears
  immediately. Later bursts use separate, collision-separated slots.
- Sixteen reusable custom-draw slots, no per-hit nodes, 650ms lifetime, bounded
  4096-ID replay window. Pool exhaustion drops additional cosmetic bursts.
- Warm bold outlined digits have a brief squash/stretch overshoot, five tiny
  rays, a small arc/tumble and a final fade. Magnitude increases visual weight,
  capped at 32 logical font units. Low quality/reduced motion removes rays,
  rotation and travel, retaining steady readable text and fade.
- The logical viewport inherits UI scale. Reserved top/bottom regions and the
  crosshair are excluded; overlapping numbers stack if space permits, otherwise
  are suppressed. Offscreen hits do not become edge indicators. Focus loss,
  inactive effects and local death drain slots; round/retry resets clear epochs.

## Verification handoff

Godot 4.5.2 `--check-only` passed for the renderer, both fixture scripts and
`combat_feedback.gd` during implementation. Runtime tests and rendered evidence
are pending the parent's exclusive heavy-slot grant. No capture is claimed yet.

After that grant, from the worktree with `GODOT_BIN` pointing to pinned 4.5.2:

```bash
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/damage_numbers.gd
```

The contract covers source totals, fractional aggregation/rounding, duplicates,
stale IDs, bounded storage/pool, malformed values, frozen anchors, camera and
wall rejection, death/focus/epoch lifecycle, compact/wide logical layout.
The parent should register it in the central verifier.

Renderer evidence fixture (synthetic authority-shaped events, actual Godot
viewport frames; this is explicitly not live-server gameplay evidence):

```bash
EVIDENCE=/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/damage-numbers
python3 tools/godot-dev/xvfb_run.py "$GODOT_BIN" --path godot --script res://tests/protocol/damage_numbers_capture.gd -- --output="$EVIDENCE/wide"
python3 tools/godot-dev/xvfb_run.py "$GODOT_BIN" --path godot --script res://tests/protocol/damage_numbers_capture.gd -- --compact --output="$EVIDENCE/compact"
python3 tools/godot-dev/xvfb_run.py "$GODOT_BIN" --path godot --script res://tests/protocol/damage_numbers_capture.gd -- --compact --reduced-motion --output="$EVIDENCE/reduced"
ffmpeg -y -framerate 30 -i "$EVIDENCE/wide/frame-%03d.png" -filter_complex '[0:v]split[a][b];[a]palettegen[p];[b][p]paletteuse' "$EVIDENCE/wide/sequence.gif"
```

Each run writes `before.png`, 25 numbered static sequence frames, and
`after.png` after expiration. Use frame 009 for the multi-hit/incoming comparison.
The live capture lane can additionally record this integration without changing
its existing campaign capture script here.
