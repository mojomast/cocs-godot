# Independent native Puma driving verification

Integrated delivery: `a34054e`; the lead reran its bounded real-session driver:

```sh
TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
python3 -B port/tools/native_vehicle_demo/driving.py
```

The first attempt, `e25d0d45-7406-40e8-a318-d3548fd61e64`, failed **before
gameplay**: Xvfb could not bind the shared pathname socket directory. The driver
then supplied an empty display and Godot could not create X11/Wayland output.
All output and the failed summary remain in `port/native-puma-driving/evidence/`.
The lead added `-nolisten unix` (Linux abstract sockets remain available) and a
display-number/live-process check. No shared directory permissions were changed.

The corrected run, [`ca24ec1d-e9e5-41c0-91d8-db16af415f40`](../../native-puma-driving/evidence/ca24ec1d-e9e5-41c0-91d8-db16af415f40/summary.json),
passed both real normal-rate cases with exact server/native vehicle correlations:

| Map | Native samples / server correlations | Input receipts / ACK high-water | Displacement | Reverse | Neutral ACK samples |
|---|---|---|---|---|---|
| Ion Speedway | 93 / 18 | 439 / 438 | 31.54 m | −6.00 m/s | 27 |
| Aurora Stadium | 92 / 19 | 432 / 427 | 33.02 m | −5.76 m/s | 26 |

Both turned and rendered vehicle positions matched accepted source snapshots.
Ion's source race reset was observed. Aurora's authoritative ball state was
present. Brake/boost receipts were verified, not isolated physics performance.
All owned processes were reaped, server sockets closed and private project
removed. Input was physical native key events; focus notifications were synthetic.

The lead opened both new PNGs and the external delivery's original two PNGs.
Vehicle orientation/chase framing, race track and soccer pitch were visible.
The sampled soccer frame does not show the ball, so that image alone is not ball
visibility evidence. Raw sports HUD formatting is functional but needs polish;
camera-wall avoidance and compact HUD work are assigned to a separate agent.

Focused checks also pass: **27 sports assertions** and **7 evidence-validator
tests**, with strict logs/results saved beside this README. The previously
combined **40-gate** pass predated sports integration. The subsequent combined
**42-gate** run includes and passes sports controls plus rendered-HUD evidence.
No completed lap, goal scoring, human camera
usability, OS focus transitions or sports results/restart acceptance is claimed.
Native recording completion remains unproven.
