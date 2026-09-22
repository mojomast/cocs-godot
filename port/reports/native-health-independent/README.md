# Independent nonlethal damage and health pickup

Executed in private integration at `f7b586d`, with both input/lifecycle fixes and
the native combat overlay integrated:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/tools/native_health_damage/run.mjs
```

Exit 0, **PASS**, run `304508a5-de9e-46d1-93f2-ca186fd03a48`, 28.687 seconds:

- Native actor 1 remained alive. Five supported attacker damage events totaled
  54.513, reconciling 49.514 HP and 5 armor lost within the 0.012 wire-rounding
  tolerance. Incoming fire stopped at 50.486 HP.
- Native combat text and actual Label displayed `TAKING DAMAGE`; HUD tracked
  authoritative HP/armor. This run does not separately claim a screenshot of the
  new damage-edge animation.
- Authored health pickup 6 at `(-6,22)` raised HP **50.486→85.486**, exactly +35.
  Same marker instance hid, remained hidden through 360 snapshots, and returned
  after **12.000 simulation seconds**. Actor remained outside collection radius
  through 344 snapshots. Snapshots 492/493/853 bracket before/collected/returned.
- **876 snapshots** and **1,683 queue/receipt pairs** correlated; ACK high-water
  1683. This is not individual input-application evidence. `completionProven=false`.

Movement used native physical W/mouse events, with unchanged source rules and a
normal-rate owned loopback server. Incidental weapon collection en route does
not affect the health scenario's damage accounting or target pickup identity.
The lead verified artifact/runtime SHA-256 and all owned child PIDs absent;
cleanup reports closed server, zero sockets and removed private runtime.

The reviewed original subagent recording and nine passing analyzer/privacy tests
remain in `port/native-health-damage/`. Maximum-HP capping, other modifiers and
human audio/visual acceptance remain outside this scenario.
