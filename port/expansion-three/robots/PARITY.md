# Source / native parity contract

Read BRIEF in full before work. Audited current `robot_visual.gd`, `robot_parts.gd`,
existing robot-art generator, Horde factory/advance checks, source operator
`operator_visual.gd`/`motion_math.gd`, player-model directory, campaign
`enemies.mjs`, frozen `game/core.mjs` eye/muzzle/hit implementation and Horde
`robot-roles.mjs`. Player operator and robot rigs are separate pipelines;
`godot/player_models/source_operators` does not exist in this tree.

Exact source SHA-256 inputs are machine checked in
`godot/robot_assets/switchyard/contract.json`. Frozen source core remains
`58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.
Reviewed derivative/base sources remain untouched; recipe hashes and exported
byte hashes are emitted only by a real build, not fabricated in a planned registry.

Campaign scales: skirmisher .86, mortar 1.15, bulwark 1.5. Horde uses separate
existing scales/hit scales: lancer .86/1, spitter .9/1, mortar 1.02/1.55,
brute 1.06/1.65, bulwark 1.15/1.85. Never replace one mode's profile with another.
Campaign hit shapes are measured yaw-local chassis + sensor volumes with .06m
margin, not the frozen core's fallback .85 x 1.8 box. Shield contact is separately
defined. Literal profiles are recorded and compared with actual `robotHitVolume`.

Actor root is .9 above source feet; only FeetOrigin is -0.9, then existing
profile scale applies below it. Y is up, -Z forward. Eye fallback is 1.45 above
source actor feet; source muzzle is eye + .24 right + .42 forward - .24 vertical.
The cosmetic barrel is not allowed to override those shot origins. No socket is
added to authoritative state. Tests compare actual `eye`/`aim`, frozen muzzle
expression, unchanged snapshots and exact profile values.

Geometry checks conservatively bound all source recipe chassis/sensor pieces
inside campaign contact volumes, verify neutral sole contact and complete rigid
joint coverage in all LODs. A deliberate oversized-chassis mutation must fail.
One source check initially caught the shield rear grip outside the literal
shield depth; corrected the grip, not authority. Analytic recipe bounds are not
imported GLB bounds or full native animated pose acceptance. Those remain pending.

Native skin selection is additive and explicit, retaining baseline meshes.
No game/server, Horde controls, mission guidance, catalog, registry, exported
release or source hit target was changed. Grant-D production adds only the
reviewed cosmetic factory opt-ins, identity-rebuild hook and six terrain mounts.
The contract retains the original robot-visual baseline hash and pins the new
hooked hash. All rig, contact solver, pose and source event logic is unchanged.

## Actual imported-body control comparison

The final native contact probe extracted **12,792 actual imported triangle
centroids** from both original and new bodies: all three LODs, two body yaws,
three pitch values, idle/walk/attack/react. Campaign's actual primary fire
registered damage in **51,168 four-side probes**. Horde's frozen scalar-hit source
registered damage in **86,016 four-side probes**, covering lancer/spitter,
brute/bulwark and mortar at each original mode-specific scale. No shape/scale was
expanded to accommodate a mesh. Existing projectile, cover, ally and shield
reduction control regressions also passed.

Real native static-body floors exercised flat/slope/two-height-step and strafe.
**4,320 stock-vs-skin joint comparisons** matched; maximum settled planted foot
effector error was **0.000000123m**. This is deterministic solver precision, not
a claim of submicron visual quality. Actual imported sole vertices also met the
neutral contact tolerance. All animation keeps the actor root unchanged.
