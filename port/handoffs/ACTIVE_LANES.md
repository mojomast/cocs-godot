# Parallel development ownership

Coordination snapshot after `aca52f5`. This is an ownership record, not evidence
that an in-progress feature has passed acceptance. The lead integrates commits,
updates root documentation/shared verification and owns publication.

| Lane | Owner / baseline | Reserved files |
|---|---|---|
| Sports progression, checkpoints, results/restart | Internal agent; `8094d41` | `godot/sports/`, new progression tests in `godot/tests/sports/`, `port/native-sports-progression/` |
| Native CI / fresh-checkout verification | Internal agent; `aca52f5` | New `.github/workflows/godot-native.yml`, new CI/fresh-checkout helpers in `tools/godot-dev/`, `port/native-ci/` |
| Objective progression / HUD polish | Internal follow-up; `d498479` | `godot/objectives/`, new progression tests in `godot/tests/objectives/`, `port/native-objective-progression/` |
| LATTICE tactical map | Internal agent; `d498479` | New `godot/lattice/map_view.gd`, narrow board integration, new map tests, `port/native-lattice-map/` |
| Multiplayer lobby / leave / retry | External handoff; `8094d41` | New lobby-prefixed UI/tests, narrow `godot/world/session.gd` / scene and backward-compatible client hook if essential; `port/native-multiplayer-lobby/` |
| Pulse rifle preview | Existing external reservation | Preserve its preview/asset paths; no accepted delivery yet |

The LATTICE command and physical-input lanes are delivered and integrated at
`658b4e7` and `aca52f5`. The projectile navigation follow-up is integrated at
`cb908db`. Their current evidence remains separate from future gameplay work.
The external objective slice is delivered as `91ce0bd` and integrated at
`d498479`; its original tools/evidence stay preserved during follow-up work.

External tasks have complete scope/commands in
`external-native-objective-gameplay.md` and
`external-native-multiplayer-lobby.md`. They can be executed sequentially by
harnesses without subagents. No lane should change another owner's files,
silently merge shared branches, restart shared services or publish independently.

Published repository: <https://github.com/mojomast/cocs-godot>.
Screenshot gallery: <http://100.125.104.79:43595/> (Tailscale, screenshots only).
