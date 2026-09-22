# Parallel development ownership

Coordination snapshot after `aca52f5`. This is an ownership record, not evidence
that an in-progress feature has passed acceptance. The lead integrates commits,
updates root documentation/shared verification and owns publication.

| Lane | Owner / baseline | Reserved files |
|---|---|---|
| Sports progression, checkpoints, results/restart | Internal agent; `8094d41` | `godot/sports/`, new progression tests in `godot/tests/sports/`, `port/native-sports-progression/` |
| Native CI / fresh-checkout verification | Internal agent; `aca52f5` | New `.github/workflows/godot-native.yml`, new CI/fresh-checkout helpers in `tools/godot-dev/`, `port/native-ci/` |
| CTF / Payload vertical slice | External harness; `8e91969` | `godot/objectives/`, `godot/tests/objectives/`, `port/tools/native_objective_demo/`, `port/native-objective-gameplay/` |
| Multiplayer lobby / leave / retry | External handoff; `8094d41` | New lobby-prefixed UI/tests, narrow `godot/world/session.gd` / scene and backward-compatible client hook if essential; `port/native-multiplayer-lobby/` |
| Pulse rifle preview | Existing external reservation | Preserve its preview/asset paths; no accepted delivery yet |

The LATTICE command and physical-input lanes are delivered and integrated at
`658b4e7` and `aca52f5`. The projectile navigation follow-up is integrated at
`cb908db`. Their current evidence remains separate from future gameplay work.

External tasks have complete scope/commands in
`external-native-objective-gameplay.md` and
`external-native-multiplayer-lobby.md`. They can be executed sequentially by
harnesses without subagents. No lane should change another owner's files,
silently merge shared branches, restart shared services or publish independently.

Published repository: <https://github.com/mojomast/cocs-godot>.
Screenshot gallery: <http://100.125.104.79:43595/> (Tailscale, screenshots only).
