# Source match recording and replay — first native admission

Status: **READY FOR ENGINE**. Implemented code, not native acceptance. No Godot,
Blender, import, render, encoding or authority-source edit was performed.

## Audit and ownership

- `game/demo.mjs:132–209`: actual `DemoRecorder`, 18 Hz due policy, two-decimal
  positional rounding, removal of `bot`, event-ID deduplication, duration cap.
- `game/demo.mjs:211–277,394–491`: actual `DemoPlayer`/`DemoPlayback`, relative
  cursor versus absolute event time, shortest-path yaw, actor birth/despawn,
  stepped non-interpolated fields, version-1 JSON/gzip and `trimDemo`.
- `game/demo-store.mjs`: browser IndexedDB library, metadata, import/export,
  retention/bookmarks. Native needs a local file adapter, not IndexedDB emulation.
- `app/page.tsx:627,649,669`: received network-state recording versus offline
  snapshots; playback uses first-frame time offset when querying events.
- `game/demo-session.mjs` and `demo-playlist.mjs`: attract session/rotation are
  different features. `game/replay.mjs` is quick-match selection, not playback.
- `godot/ui/attract/demo.gd:1–14,75–133`: fixed cosmetic campaign reel with its own
  compact clip schema. It is not a version-1 user demo player/library.
- `server/room.mjs:778–822`: recipient filtering is performed before network
  delivery. Capture connects only to native client's delivered state/events;
  neither the recorder nor replay helper can access Room/Match.

## Implemented surface

`godot/replay/capture.gd`: Record replay / Save clip / Discard recording in an
admitted session with the mouse released. Explicit REC status, source time/frame
counts, round/seat/transport interruption, bounded queues, reusable saved clips.
Leaving with an unsaved recording discards its in-memory data. Saved files remain.

`godot/replay/library.tscn`: discoverable Home-route target with list metadata,
open, source JSON import, play/pause, exact scrub and ±5-second seek, readable
0.25×/0.5×/1×/2×/4× speed, subject cycling, Settings and Home/Library controls.
Unknown/corrupt clips show errors. Open-player layout hides the browser controls
to preserve compact transport space. Native wide/compact inspection is pending.

The native bridge launches a fixed local helper, uses one in-flight authenticated
loopback HTTP request, and caps its queue at 32 requests / 4 MiB. Each operation
can batch up to four ordered delivered packets; source Node still owns the due
decision, preventing HTTP overhead from forcing a second native sampling policy.
Each operation
has a fixed verb; there is no authority/input/script/path-loading API. Playback
is sampled by the **actual unchanged source Node module**, not a GDScript copy
or a second physics simulation. The renderer reuses `world/viewer.gd`,
`world/presentation.gd`, pickup visuals, combat feedback/audio and projectile
bodies. Live remote interpolation/projectile dead reckoning are disabled.

Replay scenes expose `read_only_context=true` and deliberately have **no `client`
or `net` member**. Existing Experience binding requires those members and cannot
attach a live/private PlayerInformation HUD. The helper imports no Match, server,
career or progression module. Source-import recipient claims are not trusted:
metadata labels those files `source import (unattested recipient)`.

## Admission and provenance

First batch: **Meridian Exchange**, on-foot deathmatch, team deathmatch, instagib,
rockets. Campaign, vehicles, COCS/private-intel and other maps are explicitly
unsupported. Native capture controls are disabled outside this admission.

`godot/replay/admission.json` binds source commit `515daf07589150dd3241f4ae1425cc1b093912f5`,
reviewed derivative `0326b435a2fdd88e6e7a01b8a7325feccc4d15cb`, both contract-file
SHA-256s, core SHA-256, source demo module SHA-256, and exact normalized semantic
map SHA-256 `e1332aa73fddbd75e2cd3fec87c157a515572a9a27a27f130b9cd605b70bf914`.
Native loading verifies the existing catalog and asset hash before rendering;
there is no arbitrary clip-provided resource path or fallback map. Original and
reviewed derivative use the same admitted Meridian geometry. These hashes attest
installed catalog compatibility, **not cryptographic identity of a remote host**;
native clip metadata explicitly says `catalogCompatibilityOnly`.

Native files retain source demo version 1 and add version-1 `meta.nativeReplay`.
Limits: 32 MiB file/inflated gzip, 10 minutes, 10,801 frames, 32,000 events,
64 actors, 512 snapshot items, depth 24, bounded strings/tree nodes and finite
numbers. Frames are strictly increasing with matching snapshot times; identity,
mode, map and native provenance mismatches fail. Credential/prototype keys fail.
Native storage uses exclusive-create random `clip-UUID.json` files under
`user://replays`, up to 200 clips, with no automatic retention/deletion or overwrite.
Library identities cannot contain paths; symlinks are rejected. Native file picker
currently imports plain JSON up to 4 MiB (queue bound); Node codec also validates
bounded gzip. Arbitrary extra source fields remain inert data; the native visual
projection is a small allowlist and excludes ammo, movement/intel/private HUD data.

## Clock and cue contract

Source `sample()` and `trimDemo()` semantics are retained, including stepped
`bodyYaw`/health/over fields and source's next-frame actor membership rule. Ended
is separately represented by the playback controller, not inferred by awarding
a match result. The adapter returns exact sampled positions, not extrapolation.

Cues query `(firstFrame.time + before, firstFrame.time + after]`, only during
forward 1× ticks of at most 100 ms and at most 64 events. Other windows consume
time without a catch-up burst. Seek/pause/speed/focus/settings clear effects/audio;
native request epochs reject stale in-flight tick cues after those transitions.
Import/open starts paused. Scrubbing produces no history sound. Replaying an
interval intentionally can play that interval again; repeated zero-time ticks do
not duplicate its events. The visual cue subset is shot/launch/explosion/death;
full source event analysis/bookmarks/objective timelines are outside this batch.

## Parent integration and package closure

1. Cherry-pick owned feature commit, then the separate **optional session hook**.
   It adds only the capture child to ordinary `world/session.gd` composition.
   No wholesale world/session, settings, spectator or input rewrite is needed.
2. Home **Replays** button opens `res://replay/library.tscn`, without launching an
   authority. If embedding instead of changing scenes, connect `back_requested`
   to free the library and restore Home/attract. Its standalone Home fallback is
   `res://ui/main_menu.tscn`. Parent owns this final single entry/route binding.
3. Include `godot/replay/**` and reused renderer dependencies in native closure;
   exclude `godot/tests/replay/**` from exports. Existing semantic map/operator/
   projectile/audio assets are required; this worktree has no generated assets.
4. Run `node tools/port/replay/package.mjs <fresh-package>/replay-runtime` to copy
   four checked runtime files (source `game/demo.mjs`, admission and two adapter
   files) with their hash manifest. No npm dependency is needed for playback.
   In development the bridge finds the repository one level above `godot/`;
   packages use adjacent `replay-runtime/`, adjacent Windows `node.exe`, or Linux
   `node` on PATH. Parent must add this closure to package verification.

No shared Experience hook is needed because the replay scene has no authority
client. Any future decision to emulate a client must retain explicit read-only
binding and must not inherit the live/private player HUD.
