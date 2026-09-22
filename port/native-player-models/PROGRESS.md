# Player model improvement: resumed implementation

Current status: staged candidate recovered from the missing external worktree's surviving Git index. Fresh numeric/staged lifecycle, normal-rate live correlation and editor-free preview export pass against d306205. All 40 matched images and three fresh live/release images inspected directly. Gameplay integration is held for distant readability and render cost; see REVIEW.md and HANDOFF.md. The discovery-only record below is retained as history.

# Historical discovery checkpoint

Status: partial discovery only. No replacement model implemented, no render/live/export acceptance claimed. No background worker is running.

Baseline: 2af744f8f2eef2087d056844dd7f973336215de2
Branch: external/player-model-improvement
Worktree: /tmp/opencode/cocs-player-model-improvement
Handoff read from primary: port/handoffs/external-player-model-improvement.md.
Current primary ACTIVE_LANES.md confirms this lane's reservation. Primary has unrelated uncommitted changes and remains untouched.
Research SHA256: 414f1a9e6d6285f87ad5aaf09027ff018e95d726653a9f0ae8401f84771a872e (file hashed; full research reading still pending).

## Runtime audit findings so far
- godot/world/actor_visual.gd:5–9 lists all nine character palettes; 10–12 exposes instance-owned armor/identity/team_marks.
- actor_visual.gd:31 names Helmet; 38 names Muzzle; 44–62 normalizes float team IDs, caches identity updates and distinguishes red/blue with one/two stripes.
- godot/world/presentation.gd:5 is the ActorVisual preload; search located construction at line 51. Full lifecycle audit pending.
- godot/tests/protocol/entity_visuals.gd:28–55 requires stable Helmet, meaningful Muzzle forward offset, instance-isolated materials and stable geometry on identity change. Lines 34–39 inspect immediate child bounds; nested geometry needs additional recursive validation, not weakening this gate.
- entity_visuals.gd:40–47 enforces 1.8m height, 0.7m width, source Y +0.9 origin and negative-Z facing. Lines 50–62 test dead/self hiding and cleanup.

## Actual measured baseline
Command:
`GODOT_BIN --headless --path godot --script res://tests/player_models/baseline.gd`
Pinned engine returned 4.5.2.stable.official.6ce3de25a; exit 0. Full output retained in baseline.log.
26 meshes, 26 surfaces, 624 vertices, 312 triangles, 4 materials, 27 nodes.
Measured bounds approximately (-0.35,-0.9,-0.615) to (0.35,0.9,0.28).
11 CPU construction samples each for populations 1/16/32 are retained. These are off-tree synthetic construction measurements, NOT rendered draw calls, GPU timings or gameplay acceptance.
Xvfb is installed. Blender was not found on PATH; no dependency installed.

## Harness failures
1. OpenCode default startup failed opening its log on read-only filesystem.
2. Codex ephemeral workspace-write fallback failed authentication (HTTP 401).
3. OpenCode with private XDG data/state directories started but failed missing authentication.
No subagent audits or implementation were completed by these harnesses. No credentials were inspected. All harness processes exited.

## Remaining work
Complete all three required discovery audits sequentially before implementing: full runtime/lifecycle/package audit, visual/operator-profile/screenshots audit, and backend/performance/API audit. Then write DISCOVERY.md and DESIGN.md and proceed through the handoff's implementation/verification/render/live/export phases. No design variants, performance budgets, completion or acceptance claims have been made yet.
