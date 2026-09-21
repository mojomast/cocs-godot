# Private-display native focus/click/pointer acceptance

**Overall acceptance remains FAILED: real OS focus loss has a mouse-look gating window.**
The final run passed 75 of 76 checks. Actual click capture, WASD/fire, Escape release,
settled focus-loss release, and focus-return/fresh-click behavior were exercised successfully.
Mouse motion 60 ms after OS focus loss still changed aim before the application-focus
notification arrived. This reproduces in attempts 05 and 06. No runtime fix is included.

## Executed environment and scope

- Worktree `/tmp/opencode/cocs-native-graphical-focus`, branch `subagent/native-graphical-focus`,
  based on `fb4cf04e2460121a23329913db78f0b5924d732c`. `git diff 1bf9832 fb4cf04 -- godot game server package.json package-lock.json`
  was empty. The primary had advanced by discovery time; it was not reset or merged.
- Exact Godot `4.5.2.stable.official.6ce3de25a`, read-only binary under the approved toolchain.
  Actual native X11 graphical session, Compatibility/OpenGL 4.5, Mesa llvmpipe software rendering.
  The runtime copy contains the unchanged `session.gd`, `viewer.gd` and protocol client.
- Fresh authenticated Xvfb, 1600×1000×24; actual native X11 focus-sink window beside Godot.
  XTest generates real X-server keyboard/button/motion events. `XSetInputFocus` changes OS focus.
  No Godot input-event injection, smoke controls, synthetic focus notifications or gameplay mutation.
- Xvfb allocates its own free **abstract Unix** display using `-displayfd`, `-nolisten tcp -nolisten unix`.
  Final allocation was `:0` in that namespace, owned by PID 1957804, not an inherited desktop connection.
  The harness removes inherited DISPLAY, WAYLAND_DISPLAY, XAUTHORITY and session-bus settings;
  HOME, XDG directories, TMPDIR and authentication cookie are private. The cookie is deleted, not recorded.
- Owned loopback Node source server on a free port, default 60 Hz simulation/30 Hz snapshots,
  `historyPath=null`, `progressionPath=null`. It loads existing dependencies read-only from the
  approved primary checkout after comparing all tracked game/server/package bytes to this worktree.
  Observation wrappers retain input controls and selected authoritative actor fields without modifying frames.
- Meridian active round with the session's ordinary two bots. All 227 local snapshot traces in the
  final run remained alive. No death/respawn, rules, dependencies or source assets were changed.

## Final findings: attempt 06

See [result.json](attempt-06/result.json), [actions.jsonl](attempt-06/actions.jsonl),
[native.jsonl.gz](attempt-06/native.jsonl.gz) and [wire.jsonl.gz](attempt-06/wire.jsonl.gz).

| Acceptance case | Actual result |
|---|---|
| Before click, with W physically down | Native and server controls neutral; competing XGrabPointer succeeds |
| Fresh left click | Program capture true; competing XGrabPointer returns AlreadyGrabbed with left button **up** |
| W, A, S, D separately | Each creates non-neutral native and live server input |
| Fire + movement | Server records 15 local shots; maximum horizontal displacement 14.628 m; ACK reaches 422 |
| Captured look | XTest relative motion changes yaw |
| Captured pointer confinement | Attempt to move root pointer to `(1400,180)` outside Godot remains inside Godot |
| Escape with held movement/fire | Neutral controls; capture released; competitor can grab; pointer can reach `(1400,180)` |
| OS focus loss, settled | Focus sink owns OS focus; neutral native/wire controls, program capture false, competitor can grab |
| Motion after settled loss | Pointer crosses into sink; yaw/pitch unchanged |
| Focus return while W, D **and left mouse button stay down** | OS key/button queries confirm held controls; neutral inputs, no capture, unchanged look |
| Release left button and fresh click | Capture/fire return; fresh movement reaches server |
| Motion during focus-notification delay | **FAIL: yaw and pitch change despite OS focus already belonging to sink** |

All **422** native queued input dictionaries match all **422** consecutive server-received
input dictionaries in order (numeric comparison tolerance 1e-9). The correlation check is offline;
the input itself was obtained from the live graphical run. No snapshots were authored by the harness.

### Focus timing failure and OS/program distinction

In attempt 06, OS focus was verified as sink window `2097153`, distinct from Godot `4194307`.
The immediate competing grab returned `1` (AlreadyGrabbed). Around 61 ms after focus change,
the pointer moved from `(570,370)` to `(610,378)` and a competing grab returned `0` (Success):
the X-server pointer grab was already released by then. Its exact release instant is not sampled.

Yet the native trace still reported `focused=true`, `pointer_captured=true`, and
`control_eligible=true`. The 40×8 relative motion changed:

```text
yaw:   1.96318531036377  -> 1.84318530559540   (~ -0.120 rad)
pitch: -0.564000010490417 -> -0.587999999523163 (~ -0.024 rad)
```

Those changed aim values reached the actual source server. Movement and all action flags were
neutral in the sampled post-100-ms transition packets. The first received trace with application
focus false and program capture released arrived **256.319 ms** after the focus command.
Attempt 05 independently observed the same aim change and **259.336 ms** notification delay.
These are wall-clock receipt measurements, including scheduling/trace delivery, not precise engine-event latency.

This is why the program's `Input.mouse_mode` field alone is insufficient physical-grab evidence.
The harness reports XGetInputFocus, XQueryPointer, XQueryKeymap, competing XGrabPointer status,
and actual pointer boundary crossing separately. Successful competing grabs are immediately released
by the harness and never call XUngrabPointer on Godot's connection. Probes while buttons are held
can in general be confounded by implicit grabs; click/Escape baseline comparisons also use button-up samples.

Owner follow-up should inspect the gap between `get_window().has_focus()` (already gates movement)
and the delayed `application_focused` latch used by `can_capture_pointer()` / `update_look()`.
The narrow graphical gate should remain open until the transition check passes on a runtime fix.

## Visual inspection

Inspected the PNGs directly. The native HUD is legible and shows the diagnostic warning,
Meridian name, HP, armor, weapon/ammo, LIVE state, controls and advancing ACK.
[Clicked view](attempt-06/02_clicked_capture.png) shows teal ground, blue-gray collision blocks,
yellow pickup cubes, and green markers. The opening view in attempt 05 was substantially occluded
by a bright green spawn marker. [Fresh click/fire](attempt-06/12_fresh_click_reactivation.png)
shows a thin yellow diagnostic tracer. [Focus-loss view](attempt-05/09_focus_lost_held.png)
shows both actual native windows and the labeled private focus sink.

These are semantic diagnostic graphics, not original-art fidelity or general playable acceptance.
Screenshots use XGetImage of the actual Xvfb framebuffer; this capture method does **not** include
the cursor sprite. Cursor visibility is consequently not established by the PNGs. OS grab/confinement
evidence applies to the virtual X-server pointer, not physical hardware, Wayland, a window manager's
Alt-Tab behavior, multiple monitors, or the owner's desktop. V-Sync unsupported warnings are retained;
there were no Godot script errors. Headless editor import was preparation only, not acceptance.

## Preserved attempt history

| Attempt | Exit | Outcome |
|---|---:|---|
| 01 | 1 | Before Godot launch: Xvfb default pathname-socket allocation failed; `/tmp/.X11-unix` is root-owned mode 0755 |
| 02 | 1 | `-pn` did not solve that allocation failure |
| 03 | 1 | Abstract-only Xvfb works; 46 checks passed, then the harness's 100-ms settled-focus assumption failed; application release arrived around 281 ms |
| 04 | 0 | 73 settled-state checks passed after explicitly awaiting the focus notification; did not yet probe motion during the transition or hold fire through focus return |
| 05 | 1 | 74/75 checks passed, including held fire through return; transition motion exposed the look leak |
| 06 | 1 | 75/76 checks passed; reproduces leak, adds immediate OS-grab samples and verifies changed aim on wire |

Failed discovery logs are retained losslessly as gzip, not replaced by excerpts. Attempts 01/02
produced 14.35 MB repetitive Xvfb logs each before the original size guard could run. The final harness
adds an OS 8 MB file-size limit to owned launched children and caps native trace consumption.
All attempts have explicit harness start/failure-or-status/termination evidence. Large text streams
are losslessly compressed with the raw duplicate removed; each attempt has just one result summary.

## Reproduce

No package installation is required here: Python standard library, Node, Xvfb,
`libX11.so.6`, `libXtst.so.6`, the existing Godot binary and existing Node dependencies suffice.
`xdotool`, `xwininfo`, `xprop`, `xwd` and ImageMagick `import` were not found; direct Xlib/XTest
calls provide the actual OS input/inspection equivalent. The harness deliberately creates its
own display; do not point it at an existing desktop.

Exact final command, executed from the worktree root:

```sh
python3 port/tools/graphical_acceptance/run.py \
  --source /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port \
  --godot /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --output port/graphical-acceptance/attempt-06
```

It returned exit **1**, `status=failed`, `checks=76`, `completionProven=false`.
For a new run, replace the output with a **new** directory (existing evidence is never overwritten).
Overall working deadline is 85 seconds plus bounded preparation/cleanup; each wait and preparation
command has its own timeout. Bot/spawn randomness remains ordinary source behavior; a death or early
process exit fails the run instead of being quietly retried or suppressed.

Offline evidence validation (does not turn failed acceptance into success):

```sh
python3 port/tools/graphical_acceptance/verify_evidence.py port/graphical-acceptance/attempt-06
sha256sum --quiet -c port/graphical-acceptance/SHA256SUMS
```

Tool/runtime/binary hashes are in each result's provenance; SHA256SUMS covers committed evidence
and final harness files. Timelines use wall-clock milliseconds; native records also retain engine
sequence and monotonic microseconds. Input sequence, local actor, ACK and selected wire state are
preserved; reconnect/progression credentials and the X authentication cookie are not serialized.

## Termination and cleanup

There is **no native standalone terminal marker**. Every attempt explicitly records
`completionProven=false`; the harness stops an active round after its checks. A harness status is
not proof that the native game independently completed a match or clean exit.

Final owned processes: Godot PID 1957912 (harness SIGTERM, exit -15), server PID 1957807
(SIGTERM handler, exit 0), Xvfb PID 1957804 (exit 0). All were waited/reaped and `/proc` entries
were verified absent; the owned server port, pathname socket and abstract display socket were
verified unavailable. Private runtime files and cookie were removed. Cleanup uses only retained
child handles, with bounded escalation, never name-based/broad kills. Other worktrees are preserved.
