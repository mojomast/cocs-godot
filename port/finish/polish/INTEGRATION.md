# Reviewed polish source integration

Branch: `integration/polish-20261003`, foundation `5b5c8791`.
Five reviewed lanes assembled without conflicts through `6ac28c41`:

| Lane | Original commits | Integration commits |
|---|---|---|
| Explosion fallback | `60997c7c`, `8caa5cd9`, `7dab8fe8` | `721eb19d`, `a3594e2a`, `5f800254` |
| Identity atmosphere | `62c3d04d` | `ce914aa8` |
| Opaque/priority surfaces and wetness | `03a64083`, `3059de9a` | `a1d537d4`, `e3747ba5` |
| Muzzle sheet extraction | `e5a0f710` | `3cad92d3` |
| Integrated support cues | `e31de5d7`, `cebc8d33`, `1216527c`, `7ee7a33c` | `1dd15fa9`, `0d88aa84`, `3ef25e72`, `6ac28c41` |

Parent verified the combined tree with the executable shader parity check
(`MOTH_SHADER_PARITY_OK`), grammar parsing of all **14** changed/new GDScripts,
and `git diff --check`. No engine/import/render/server/build ran here.

This branch is separate from `feature/relay-campaign` and active native K.
It must adopt K's accepted runtime corrections after K releases, resolve overlap
deliberately (especially shared feedback/weather/preloads), and then undergo its
own native checks. Package receipts still pin the foundation; these changed
supporting files require exact reconciliation, not reuse of old native evidence.

## Required native follow-up

After a new explicit exclusive grant, import/type-check the combined project,
then run the relevant fixtures with exact commit identity, bounded process groups,
the nonwaiting shared lock and `LP_NUM_THREADS=1`:

- `tests/edge_effects/weapons.gd`: primary/alt/generic explosion behavior, malformed
  events, quality-toggle dedup and reduced-motion fallback.
- `tests/identity_maps/environment_parity.gd`: authored identity atmosphere,
  single environment/sun ownership, weather restore and biome baselines.
- `tests/graphics_depth/variants.gd` and `tests/moth/validate.gd`: both material
  variants and actual engine material parameters.
- `tests/world_weather/spatial.gd`: both shader wetness leases, retained parameters
  and repeated restore. Use graphical Compatibility for shader reflection.
- `tests/graphics_depth/capture.gd`: graphical Compatibility baseline/after
  priority ordering; preserve the documented 81 high-pixel contract.
- `tests/weapon_effects/moth_coverage.gd`: graphical Compatibility synthetic and
  real Moth-frame alpha/core/hue comparisons, retaining actual PNG/JSON output.
- `tests/combat_integration/support_cues.gd`: integrated heal/teleport ownership,
  immediate preference/focus clearing, no old-event replay and immutable inputs.

Capture actual gameplay for authored identity-map atmosphere and heal/teleport/
explosion/muzzle behavior. Source math and grammar do not establish rendered
quality, native acceptance or hardware performance. Keep failures and original
asset production receipts immutable. No new archive is built or published here.
