# Window-focus runtime correction — passing follow-up

**The fixed runtime passes all 76 checks of the unchanged private-display graphical harness.**
The earlier failed attempts under `port/graphical-acceptance/attempt-*` remain unchanged failures.
Original harness commit `57c30db7892ce66984687aa8c2c316d308e3c5bf` is unchanged.

Runtime/test commit: **`a7f5c1200abd71af43b58c565d66e44e50dd8e68`**.
Worktree: `/tmp/opencode/cocs-native-graphical-focus`, same `subagent/native-graphical-focus` branch.
No primary merge, cherry-pick, base switch, package installation or source/game-rule change.

## Confirmed cause and smallest correction

The old `can_capture_pointer()` gate depended only on the delayed `application_focused` latch
plus gameplay eligibility. `update_look()` and click capture both use that gate. Movement already
checks immediate `get_window().has_focus()`. During the actual X11 focus transition, the window
lost focus and its OS pointer grab was released while the application latch and program mouse
mode were still stale. Motion delivered while the pointer remained over Godot therefore changed
aim even though movement/fire were already neutral.

`session.gd` now immediately returns false from `can_capture_pointer()` when it is inside the
scene tree and its actual Window is unfocused. This is one runtime guard, with two explanatory
comments; `update_look()` and click capture both inherit the correction. It uses Godot's native
window state, with no external OS polling or new dependency.

Detached in-memory probes have no window, so they retain their existing application-latch
semantics. Attached windows—including headless/hidden windows—must use their real focus state.
There is no blanket headless focus exemption or invented true focus for real windows.

Evidence establishing the cause:

1. The new `window_focus.gd` regression attaches the actual session input methods under a real
   hidden Window, with the application latch intentionally true to model delayed notification.
   Before the guard, **3/7 assertions failed** (capture eligibility, look gating, and application
   focus overriding a truly unfocused window). These were assertion failures, not parser failures.
2. After the guard, **7/7 pass**, including unchanged look and unfocused capture eligibility.
3. In the fixed **actual graphical** run, transition snapshots 427–445 report
   `focused=true`, `pointer_captured=true`, but **`control_eligible=false`**. The same XTest
   40×8 motion leaves aim exactly unchanged:

   ```text
   yaw   =  1.96318531036377
   pitch = -0.564000010490417
   ```

   The server receives that unchanged aim. The first application-focus/release trace arrives
   about **284.244 ms** after the focus command; gating no longer depends on that delay.
   The immediate OS competitor grab returns AlreadyGrabbed, while the ~62 ms sample succeeds:
   as before, OS grab release and program mouse-mode release are distinct observations.

This confirms the session-level gate mismatch. It does not establish the engine-internal reason
for application-notification timing, or a precise OS release instant between probe samples.

## Executed checks

| Check | Before | After |
|---|---|---|
| `window_focus.gd` | Exit 1, 7 checks / 3 failures | Exit 0, 7 checks / 0 failures |
| Existing `control_safety.gd` | Not rerun before | Exit 0, **2,489** assertions |
| Existing `session_recovery.gd` | Not rerun before | Exit 0, **52** assertions |
| Private-display actual graphical acceptance | Earlier attempt 06 failed 1/76 | Exit 0, **76/76** checks |
| Offline full input correlation | Earlier evidence preserved | **422 native queues = 422 consecutive server inputs** |

Control-safety, session-recovery, local-lifecycle and presentation source/tests were not edited.
The new attached-window regression is deterministic headless evidence, deliberately distinguished
from the real Xvfb/XTest live run. The full combined verifier belongs to the lead's integration run.

The graphical run additionally confirms click/OS capture, each WASD key, fire, mouse look,
confinement, Escape, neutral controls on focus loss, gated transition and settled look,
**W + D + left button physically held across focus return without automatic capture/actions**,
and fresh-click recovery. Source server: 15 local shots, ACK 422, maximum displacement 8.728 m.
All recorded local snapshots remain alive. No death/respawn scenario was duplicated.

## Exact commands

Executed from the worktree root using the same pinned binary:

```sh
python3 port/tools/graphical_acceptance/focused.py \
  --godot /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --output port/graphical-acceptance/focus-fix/before window_focus
# Exit 1 before the runtime guard.

python3 port/tools/graphical_acceptance/focused.py \
  --godot /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --output port/graphical-acceptance/focus-fix/after window_focus control_safety session_recovery
# Exit 0 after the guard.

ln -s /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node_modules

python3 port/tools/graphical_acceptance/run.py \
  --source /tmp/opencode/cocs-native-graphical-focus \
  --godot /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --output port/graphical-acceptance/focus-fix/graphical-after
# Exit 0; status=passed, checks=76, completionProven=false.

python3 port/tools/graphical_acceptance/verify_evidence.py \
  port/graphical-acceptance/focus-fix/graphical-after
# Exit 0: all 422 queues match all 422 server inputs; all local snapshots alive.
```

The ignored dependency symlink was created only for read-only access to the approved existing
dependencies. The server's `--source` is this fixed checkout, **not primary**. The temporary link
was removed after verification; its target was untouched. For a rerun, recreate that link only
if absent, and use **new output directories**. Both runners generate their own semantic assets
and import caches inside disposable private project copies, with isolated HOME/XDG/TMPDIR.

## Evidence, visuals and cleanup

- [Before regression log](before/window_focus.log) and [before provenance](before/result.json).
- [After regression log](after/window_focus.log), [control-safety](after/control_safety.log),
  [session-recovery](after/session_recovery.log) and [after provenance](after/result.json).
- [Graphical result](graphical-after/result.json), [OS/action timeline](graphical-after/actions.jsonl),
  [native trace](graphical-after/native.jsonl.gz), [wire](graphical-after/wire.jsonl.gz).
- Directly inspected [captured view](graphical-after/02_clicked_capture.png),
  [focus loss with sink](graphical-after/09_focus_lost_held.png), and
  [held-control focus return](graphical-after/11_focus_return_held_no_click.png).
  HUD is legible; the initial clicked view shows diagnostic blue blocks, green markers and a
  yellow cube. The later focus views mostly show the dark background after the intentional
  large pointer-confinement motion changed camera orientation. This is not original-art acceptance.

Graphical acceptance used an authenticated, newly allocated private Xvfb display and a native
focus-sink window, with actual XTest/X11 focus/grab/pointer inspection. Software Mesa llvmpipe;
the retained V-Sync warning is expected. XGetImage screenshots omit the cursor sprite. Physical
hardware, Wayland and desktop-window-manager behavior remain outside this narrow result.

Godot PID 1992975, server PID 1992932 and Xvfb PID 1992929 were terminated through their owned
handles, waited/reaped and verified absent. Server port and both display socket forms were
unavailable after cleanup; private test/runtime directories and X authentication cookie were
removed. The game was explicitly terminated by the harness during the active round:
**`completionProven=false`**, with no native standalone terminal marker. A passing graphical
acceptance status does not claim independent match completion.

`SHA256SUMS` in this directory covers this follow-up's evidence, helper, runtime and regression.
The original checksum manifest and all original attempt files remain unchanged.
