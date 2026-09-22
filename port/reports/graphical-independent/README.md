# Independent combined-runtime graphical acceptance

The lead executed the unchanged private-display harness against primary at
`5e8136dbcaa99127694b5bd4b4078862ce486146`, with both healthy-respawn and immediate
window-focus corrections integrated:

```sh
# From /tmp/opencode/cocs-native-integration at the same revision:
python3 port/tools/graphical_acceptance/run.py \
  --source /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port \
  --godot /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --output port/graphical-acceptance/independent-combined
python3 port/tools/graphical_acceptance/verify_evidence.py \
  port/graphical-acceptance/independent-combined
```

Live exit **0**, **76/76 checks pass**. Independent offline correlation also
exited 0: **424 native queues matched 424 consecutive server inputs**; all local
snapshots remained alive. The harness uses owned authenticated Xvfb, actual XTest
keyboard/button/motion events, a native focus sink and the unchanged normal-rate
source server. The private runtime copies primary sources; dependencies are
read-only. The owner's desktop is never connected.

The reproduced failure is fixed in this execution: motion 60 ms after OS focus
loss preserved yaw/pitch `[1.96318531036377, -0.564000010490417]`, including on the
server wire, even though the application-focus release notification arrived
278.803 ms after the focus command. Immediate window focus gates look before
that delayed latch changes. Click/capture/confinement, WASD/fire, Escape, settled
focus loss, held W/D/fire across focus return and fresh-click recovery all pass.

`02_clicked_capture.png` and `09_focus_lost_held.png` were directly inspected:
they show the native diagnostic world/HUD and separate focus sink on the private
display. Screenshots alone do not establish pointer capture or cursor visibility;
those conclusions use the retained X11 grab/confinement and input observations.
This is software-rendered X11 acceptance, not hardware/Wayland or human usability
acceptance, and does not establish original-art parity.

The lead independently checked all three recorded child PIDs absent. Cleanup
records also establish the owned server port and both display socket forms
absent. Raw files were copied without modification and indexed with SHA-256 in
`artifact-index.json`; credential-field/bearer/API-key pattern scans found no
matches. Earlier failed focus runs remain under `port/graphical-acceptance/`.

`completionProven=false`: the harness intentionally terminates an active round;
passing behavioral checks and process cleanup are not native recording completion.

The combined full verifier was then executed with `PORT=0`, the same pinned
`GODOT_BIN`, and `TMPDIR=/tmp/opencode`: exit 0, **all 30 implemented gates pass**,
including the new attached-window focus regression. Actual logs and report are
in `port/reports/verification.json` and its named gate logs.
