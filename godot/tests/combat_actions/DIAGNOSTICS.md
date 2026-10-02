# Pending native attribution: campaign W / controls textures

Source-only diagnostics prepared after merging canonical `652b8f3c`. Neither
failure is claimed repaired. No engine or authority journey was run for this work.

## Findings

- Campaign W uses the same physical/keycode event, flush, capture click and `.003`
  relative/screen-relative look convention as `tests/campaign/feel_live.gd`.
  `world/session.gd` records it through `combat_actions`/bindings; `_process` samples
  world x/z and `native_arenas/client.gd` sends inputEpoch/seq/cancel/input. Campaign
  keeps at most four outstanding samples and retires applied or cancelled seqs.
  `port/native-campaign/authority.mjs` accepts these same x/z/yaw/pitch fields and
  already exposes a read-only `step` observer after FIFO application. No encoding
  mismatch was found. The old weather observer explicitly discarded all input
  and step records: ACK 7→24 at unchanged position cannot identify the cause.
- The controls fixture creates Session and ArmsRace detached from the tree,
  parents the ten constructor-owned nodes in `prepare`, and frees both sessions.
  It never runs their `_ready` material/UI composition. Their transitive script
  preloads and the real autoload tree still exist independently. The retained
  log identifies GL handles 27/28 at 87,380 bytes each, but no resource path.
  That size is consistent with a full mip chain of 128-square RGBA pixels, not
  proof of texture ownership or an application leak mechanism.

## Output contracts

Campaign's existing movement trace window now includes:

- `PORT_NATIVE_TRACE` events `w_input_entry`, `w_input_recorded`, `input_queue`.
  Input queue records carry exact controls, seq, ACK, queue result; gates include
  application/window focus, GUI focus path, pointer, overlay/social/stale,
  lifecycle, received pose, spectator, W down/held/mapping/blocked. Reading gates
  never calls `sample`, clears a ledger or changes input eligibility.
- `CAMPAIGN_MOVEMENT_WINDOW`: before-W-down / after-W-up source time, position,
  epoch, input seq, ACK, outstanding window and FIFO status.
- `campaign-input-diagnostic.json`: received wire seq/epoch/cancel/controls;
  applied FIFO seq/source time/controls/status; snapshot seq/ACK/epoch/pose.
  Join by round+epoch+seq, not wall-time alone. Max 16,384 rows; `dropped` and
  `complete` explicitly report exhaustion. No credentials or NPC/private fields.

Controls uses opt-in `BASELINE_CONTROLS_RESOURCE_PROBE=1`:

- `CONTROLS_RESOURCE_PROBE`: before-session, session-allocated/prepared/before-free/
  freed, arms-allocated/before-free/freed, existing-post-draw-boundary.
- Each texture: object_id, first stage, first discovered owner property path,
  alive; while alive also class/resource path, width/height, RID and native handle.
  Join native_handle to the GL leak log in **that same process** (27/28 are not
  stable across processes). First-discovery path is a reference, not sole ownership.
- Object/resource/orphan counts, visited count, truncation flag (2,048 objects).
  Node children, script constants/base scripts, stored/script object properties,
  direct array/dictionary resource values are inspected; opaque renderer/font
  caches and deeper nested containers may not be attributable by this probe.
  Texture RID/native-handle queries may realize a lazy backend resource; compare
  with the original non-probed receipt before interpreting allocations as leaks.
- Only WeakRefs/scalar metadata survive a probe call. No RID free, global cache
  clear, autoload removal, extra draw/sleep, image readback or relaxed error scan.
  Probe reference is cleared before quit. All 90 existing assertions remain.

## Next bounded native invocations — new grant required

From the integration root, set `GODOT_BIN` to the approved stock 4.5.2 executable.
After animation/assets scheduling and an explicit native regrant, run serially:

```sh
LP_NUM_THREADS=1 AUDIO_DRIVER=Dummy python3 tools/godot-dev/finish_runner.py \
  --run --grant engine --budget-seconds 360 --evidence /absolute/new-campaign-evidence \
  --select native-version --select native-import --select world-connected-campaign

BASELINE_CONTROLS_RESOURCE_PROBE=1 LP_NUM_THREADS=1 AUDIO_DRIVER=Dummy \
  python3 tools/godot-dev/finish_runner.py --run --grant engine \
  --budget-seconds 240 --evidence /absolute/new-controls-evidence \
  --select native-version --select native-import --select controls-combat
```

The probe variable deliberately avoids the runner's scrubbed `COCS_` prefix.
Retain it in the invocation receipt. Existing per-job limits and strict nested
engine-error/leak scanning remain. No full matrix, new native pass claim, or grant
B usage is authorized here. Integration owner retains both investigations.

Focused non-engine verification:
`node --test scripts/campaign-input-diagnostic.test.mjs` — 2 passed (detached
receipts, seq linkage, privacy, cancellation/default sample, cap reporting).
GDScript probe and trace extensions await native compilation under that grant.
