# Independent native rocket pickup and return

Two actual runs from `/tmp/opencode/cocs-native-integration`, with the combined
health-aware lifecycle and immediate-window-focus runtime:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/tools/native_pickup_acceptance/run.mjs
node port/tools/native_pickup_acceptance/audit.mjs <recording-directory>
```

| Run | Source | Independent outcome |
|---|---|---|
| `2026-09-22T00-09-25.115Z` | `6a6582a` | **FAIL**: live checker exited 0 but offline audit exited 1 because the route crossed SMG before rocket, violating the required weapon-0 baseline. Original summary is preserved, not silently rewritten. |
| `2026-09-22T00-10-59.236Z` | `3991990` | **PASS**: live exit 0; 22.892-second capture; revised route avoids unrelated pickups and live checker requires the baseline. Offline audit passes with correction `497555d` described below. |

Accepted run: actor 1, rocket pickup 0 at `(-14,0,-19)`, snapshot 173 available,
174 collected, 624 returned. Weapon 0→1; rocket ammo 0→6; native HUD agrees.
The same marker hides during cooldown and returns after **15.000 simulation
seconds**, with the actor outside pickup radius. **656 native snapshots** and
**1,260 native input queues/server receipts** correlate. Actual W/mouse events
use the shipped native input path; no game rules or actor state were edited.
The lead inspected the returned screenshot: marker and weapon/ammo HUD are
visible in the diagnostic native world.

The second recording initially failed an overly strict offline last-line check:
`SceneTree.quit()` is deferred, so a final valid snapshot followed `harness_end`.
Correction `497555d` requires exactly one explicit boundary and allows only
returned/available marker snapshots afterward. Those samples remain retained and
fully correlated. This is a checker correction on the original recording, not a
third live run. It does not promote the boundary to a native completion marker.

Both recordings use the tightened process/error gate and Dummy audio driver;
no error/limit/forced exit was accepted. Credentials were redacted before
retention, including `profile.ownerToken`; the lead checked all retained welcome
records. Every owned PID was independently checked absent. Server closure, zero
sockets and removed private runtime are recorded in each unchanged summary.
Archive/index preserve both complete attempts and their distinct verdicts.

The historical sanitized subagent archive was also independently compared to the
original in memory: exactly six credential fields changed across two wire logs,
all other gameplay semantics and 34 files unchanged. Its gameplay replay passes;
its original ALSA fallback error means it does not pass the new no-error gate.

`completionProven=false` throughout. Queue/receipt correlation and ACK high-water
do not prove application of each input. This establishes one default-loadout
weapon-pickup/return scenario, not all pickups, damage, audio or broader playability.
