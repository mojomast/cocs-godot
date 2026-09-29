# Native objective destinations (source-owned rules)

Routes: `--experience=zones --mode=uplink|holdout` on Meridian Exchange,
Verdant Reliquary or Ember Crucible; `--experience=assault --mode=assault`
on Tidal Citadel or Sunscar Convoy. The existing KOTH, Domination, CTF,
Payload and Combined Arms routes retain their own identities.

The packaged and development parsers reject other map/mode pairs before
launching authority. `--bots=0..8` defaults to 2, `--round-seconds=60..900`
defaults to 60. `--score-limit=1..900` is the zone frag limit (default 100),
**not** Uplink stage count or Holdout duration. On Assault it selects 1..9
sectors (default 3), **not** a team frag target. The source server owns every
capture, progress update, winner, timeout and rematch; native projections are
read-only and clear rather than extrapolate missing snapshots.

Uplink banks three captures total over sequential authored hill positions.
Holdout requires ownership of two out of three zones for a continuous 30s;
losing the quorum resets progress. Assault attacks active sectors in order:
team 0 attacks, team 1 defends, and timeout favors defenders. Both Assault
maps source-enable vehicles; native vehicle presentation/control must be
verified independently rather than treating infantry capture as full parity.

Bounded checks (no server/render import):

```sh
node tools/godot-package/gen_routes.mjs --check
node --test tools/godot-package/objective_routes.test.mjs tools/godot-package/route_parity.test.mjs
```

Godot projection fixtures requiring the shared serial runtime slot:
`godot/tests/zone_modes/variants.gd`, `godot/tests/assault/state_test.gd`,
and `godot/tests/objective_scoreboard.gd`.
