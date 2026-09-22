# Parallel development ownership

Coordination snapshot after `aca52f5`. This is an ownership record, not evidence
that an in-progress feature has passed acceptance. The lead integrates commits,
updates root documentation/shared verification and owns publication.

| Lane | Owner / baseline | Reserved files |
|---|---|---|
| Objective completion paths | Internal follow-up; `ffa6aac` | New completion helpers/tests, narrow objective runtime only if needed, `port/native-objective-completion/` |
| LATTICE native world traversal | Internal agent; `642c615` | New `world_` LATTICE scene/helpers/tests only, `port/native-lattice-world/` |
| Multiplayer lobby / leave / retry | External handoff; `8094d41` | New lobby-prefixed UI/tests, narrow `godot/world/session.gd` / scene and backward-compatible client hook if essential; `port/native-multiplayer-lobby/` |
| Pulse rifle preview | Existing external reservation | Preserve its preview/asset paths; no accepted delivery yet |

The LATTICE command and physical-input lanes are delivered and integrated at
`658b4e7` and `aca52f5`. The projectile navigation follow-up is integrated at
`cb908db`. Their current evidence remains separate from future gameplay work.
The external objective slice is delivered as `91ce0bd` and integrated at
`d498479`; its original tools/evidence stay preserved during follow-up work.
The native CI lane is delivered as `3d6de79` and integrated at `a12d89f`.
The LATTICE tactical map is delivered as `596325d`, integrated at `c982d25` and
independently accepted through both Map and original List native-input paths.
The lead owns common launcher routing, verification, root docs and publication.
The sports progression lane is delivered as `0a07f5c` and integrated at
`e76acdb`; the lead is reproducing full-lap and round-lifecycle claims separately.
That independent sports verification passed. Objective progression is integrated
at `ffa6aac` and independently passes CTF return/capture and Payload contest/
checkpoint/results/restart. GLB-side repair at `0149cbb` / `0af3c51` independently
passes all-nine export/import and matched-camera review.
Soccer targeting is integrated at `e561f99` / `4eb0e36`; independent two-resolution
visual checks and archived source-goal audit pass. Local-driver scoring remains
unaccepted after two bounded agent attempts; seven bot/own goals are preserved.
Co-op recruitment is integrated at `642c615`; independent natural-window purchases
pass on both maps, with prior Map/List regressions intact.

External tasks have complete scope/commands in
`external-native-objective-gameplay.md` and
`external-native-multiplayer-lobby.md`. They can be executed sequentially by
harnesses without subagents. No lane should change another owner's files,
silently merge shared branches, restart shared services or publish independently.

Published repository: <https://github.com/mojomast/cocs-godot>.
Screenshot gallery: <http://100.125.104.79:43595/> (Tailscale, screenshots only).
