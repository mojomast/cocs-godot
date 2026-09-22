# Independent sports HUD / chase-camera polish

Integrated runtime `b55861f`; source hashes are in `sources.json`.

```sh
PORT=0 TMPDIR=/tmp/opencode python3 -B godot/tests/sports/run_polish.py
PORT=0 TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
python3 -B port/tools/native_vehicle_demo/driving.py
```

Both commands passed. The focused polish run is
[`1f2a772d-1f9b-454a-9863-fa5fa2dbeecd`](../../native-sports-polish/evidence/1f2a772d-1f9b-454a-9863-fa5fa2dbeecd/summary.json).
It passes **41 polish, 27 sports-controls and 19 Puma assertions** and actual
normal-rate sessions on both maps at **960×640 and 1280×800**. Every case captures
countdown, driving, near-wall obstruction and release with passive, on-screen
HUD checks. The lead directly opened all four new near-wall PNGs: readable
lap/checkpoint or Red/Blue score, speed, engagement and mode-correct instructions;
the soccer ball is visible. Tight clearance can put the vehicle behind the
bottom panel; this is retained as a camera limitation.

The original driving acceptance was rerun against the polished scene:
[`523d56b2-1898-4bc5-a9ca-264b79ad4d0d`](../../native-puma-driving/evidence/523d56b2-1898-4bc5-a9ca-264b79ad4d0d/summary.json).

| Map | Samples / source correlations | Receipts / ACK | Displacement | Reverse |
|---|---|---|---|---|
| Ion | 88 / 18 | 424 / 422 | 30.65 m | −5.83 m/s |
| Aurora | 88 / 14 | 420 / 416 | 32.31 m | −5.64 m/s |

Steering, exact rendered/source positions, release/resume and brake/boost receipts
pass; Ion's source reset was observed again. Focus notifications are synthetic.
Both helpers cleaned up owned processes, servers/sockets and private projects.
Neither completed laps, goals, results/restart nor human camera usability is
claimed. Camera clearance covers cached authored boxes, not terrain triangles,
decorative spans, dynamic objects or a full camera frustum. Recording completion
remains unproven. The original source-agent failures are retained unchanged.
