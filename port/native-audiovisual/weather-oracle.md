# Native weather parity oracle

`weather-oracle.mjs` extracts and evaluates the weather declarations directly
from `game/environment.mjs` with pure Node (`node:vm`); it neither imports the
graphics package nor starts a server, engine, or renderer. The committed
`weather-vectors.json` contains exact source outputs for uint32 map seeds,
hash salt pairs, biome precedence, weather selection, authored/reduced and
cycling time of day, gusts, lightning schedules, and precipitation coordinates
and attributes. Generate and check it from the repository root:

```sh
node port/native-audiovisual/weather-oracle.mjs
node port/native-audiovisual/weather-oracle.mjs --check
```

The native counterpart is `godot/tests/audio_new/weather_oracle.gd`. From the
repository root its Godot invocation is
`godot --headless --path godot --script res://tests/audio_new/weather_oracle.gd`.
The test loads the checked-in fixture, checks nested shape and numeric values
with a 0.00002 absolute tolerance, and prints `WEATHER_ORACLE_OK` on success.
The test was not run while generating these vectors (pure Node only).

Precipitation vectors specify the source helper's serial and origin explicitly.
The native weather service uses the same hash and spawn arithmetic, but salts
with `(serial + _seed) * 17` and fixes radius at 9; its quality setting also
changes spawn count. The oracle checks the native hash/profile formula with a
zero seed offset and the fixture's explicit radii/origins; it does not claim
that the service's nonzero-seed spawn sequence is identical to the source
helper called with the same unadjusted serial. `weather_profile.gd` does not
expose a particle-add helper; the precipitation assertion reconstructs the
service formula from native `hash_unit` and `KINDS` data.

The source sky-phase color/luminance fallback needs Three.js Color and is not
evaluated by this dependency-free exporter: time vectors use explicit sky
values or a source-recognized night map ID. If the source section markers move,
the exporter fails rather than silently using copied constants.
