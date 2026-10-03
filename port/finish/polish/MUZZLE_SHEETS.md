# MUZZLE_SHEETS — background-free Moth sheet extraction (Flash)

Scope: clear-graphics finding on `godot/weapon_effects/flash.gdshader` `use_sheet`,
implemented after the `POLISH_AUDIT_20261003.md` audit. Flash/Sol/Luna lane,
source-only. This file is the only new document; the only changed sources are the
shader and its focused test.

| | |
|---|---|
| Worktree | `/home/mojo/.tmp-on-disk/cocs-polish-flash-muzzle-20261003` |
| Branch | `feature/polish-flash-muzzle` |
| Base | `5b5c8791` (all seven Stormglass asset closures verified) |
| Exclusive native grant K | `ses_f03a3885fffehx9yFhHubuPCft` (untouched, remains stable) |
| Merge state | **unmerged** until K's native completion, to avoid invalidating the current native build |

Not touched: `weapon_effects/controller.gd` (Luna alt-blast ownership),
`graphics_fx/moth_world.gdshader` (other lane), first-person rig / source operators
(currently native K), `assets/`, `godot/.godot/`, any `.import`, any other test.

## 1. Finding, verified from the actual frame bytes

`world/combat_feedback.gd` binds the real Moth sheets
`{"pulse":"spark-impact", "plasma":"arc-burst", "shock":"arc-burst"}`. Decoded with
the Python stdlib (no PIL/pngjs available; zlib + PNG unfilter), 48×48 RGBA8:

| frame | sha256 | corner | corners uniform | alpha | authored peak |
|---|---|---|---|---|---|
| `spark-impact-0.png` | `8d398b14…ae1088` | `(26,8,6,255)` | yes | 255 everywhere | `(255,240,200)` at `(32,32)` |
| `arc-burst-0.png` | `d0a056dd…cf17fe` | `(10,4,30,255)` | yes | 255 everywhere | `(255,240,255)` at `(32,32)` |

Authored symmetry: mean `|signal(x,y) − signal(y,x)|` is `0.00111` (spark) /
`0.00112` (arc) versus `0.00894` / `0.00884` for the horizontal mirror, i.e. a
diagonal-dominant, uniform-corner card.

The audit's numbers reproduce exactly. Old coverage
`coverage = smoothstep(0.035,0.32,max(tex.r,tex.g,tex.b))` yields **0.1397**
(spark) / **0.2035** (arc) at every background pixel, and
`color = mix(color, tex.rgb*tint.rgb, 0.6)` folds the opaque card into the analytic
colour. The bright impulse sits off the quad centre `(32,32)` so a centre-only fix
would miss it.

## 2. Fix (`godot/weapon_effects/flash.gdshader`, sha256 `c9a539d0…527824`)

```glsl
vec3 background = texture(frame_texture, vec2(0.0)).rgb;
vec3 signal_color = max(tex.rgb - background, vec3(0.0));
float contrast = max(max(signal_color.r, signal_color.g), signal_color.b);
float coverage = smoothstep(0.0005, 0.015, contrast) * tex.a;
shape = max(shape*0.35, coverage);
color = mix(color, (vec3(1.0) - exp(-signal_color*10.0))*tint.rgb, 0.6*coverage);
```

- Background subtracted from **both** coverage and colour, the same extraction the
  validated `graphics_fx/moth_world.gdshader` already uses. Because `signal_color` is
  exactly zero on the uniform card, background coverage is exactly zero in either
  linear or raw sampling space (removes the 13–20 % veil).
- `1 - exp(-signal*10)` preserves the baked ember/plasma ratios; `tint.rgb` keeps
  profile identity; the ratio is weighted by `coverage`, so zero-signal pixels leave
  the analytic colour — and the core identity — untouched.
- `shape*0.35`, all `kind` profiles, `edge`, `phase`, `opacity`, billboard,
  `core_gain`/`brightness`, and reduced-motion behaviour are unchanged.
- `frame_texture` gains the `repeat_disable` hint for clean corner sampling (matches
  the world lane).

## 3. Verified source math (PENDING native)

Confirmed by decoding the on-disk PNGs (script `flash_sheet_math.py`, Python stdlib,
**no engine run**). `old → new` at the tested pixels:

| sample | spark old→new alpha | arc old→new alpha |
|---|---|---|
| background corner | `0.000 → 0.000` | `0.000 → 0.000` |
| off-core `0.75,0.75` | `0.1183 → 0.0022` | `0.1723 → 0.0169` |
| off-core `0.75,0.25` | `0.1295 → 0.0031` | `0.1887 → 0.0140` |
| off-core `0.25,0.25` | `0.1372 → 0.0049` | `0.1999 → 0.0105` |
| off-core `0.20,0.80` | `0.0524 → 0.0002` | `0.0763 → 0.0010` |
| analytic centre | `0.95 → 0.95` | `0.95 → 0.95` |
| authored peak | `0.95 → 0.95` | `0.95 → 0.95` |

Colour at the analytic centre, previously dimmed by the card
`(96,104,91)` / `(92,97,108)`, is now the untouched analytic colour
`(223,247,220)` / `(224,236,225)`; the authored peak stays the weapon tint.
Coverage of the retained core (`0.95`) and the analytic shape/edge are unchanged.

## 4. Focused test (`godot/tests/weapon_effects/moth_coverage.gd`)

Extended (synthetic-black contract preserved) to decode the real
`spark-impact-0.png` at kind 0 / `70ffe6` and `arc-burst-0.png` at kind 4 /
`72cfff`, and assert: source corner equals the authored background, corners
uniform, source alpha fully opaque, `corner alpha < 0.02`, off-core source
background `< 0.03`, analytic centre `> 0.4`, authored bright core retained
`> 0.5`, hue follows the tint rather than the baked background, and the sheet-on
vs analytic-only centre colour is unchanged. Fixtures are prepared in-test from the
real PNGs; the engine is **not executed**.

## 5. Changed shader inputs (package note)

- Sampler `frame_texture` hint added: `repeat_disable` (was `source_color, filter_linear`).
- No uniform added, removed or renamed: `tint`, `phase`, `kind`, `opacity`,
  `billboard`, `use_sheet`, `frame_texture`, `core_gain`, `brightness` signatures
  are unchanged.
- Runtime dependencies unchanged: `weapon_effects/controller.gd` (noted, unmodified)
  and `res://moth/generated/effects/{spark-impact,arc-burst}-*.png` (unmodified).

## 6. Native status: PENDING (not executed)

No engine, server, import, Blender, encode or benchmark was run. Later capture:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
python3 tools/godot-dev/xvfb_run.py "$GODOT_BIN" --path godot --rendering-method gl_compatibility \
    --audio-driver Dummy --script res://tests/weapon_effects/moth_coverage.gd \
    -- --evidence-out="$PWD/port/native-weapon-effects/evidence"
```

Expected: `WEAPON_EFFECTS_MOTH_COVERAGE {... "passed":true}`, corner alpha `0.0`,
`real_frames[*].corner_alpha < 0.02`, `off_core_max_alpha < 0.03`, centre and
retained-core alpha `~0.95`, `hue_to_tint < hue_to_background`.

## 7. Receipts

Original receipts/evidence were not rewritten; this commit is not included in any
pre-existing native result or published build and must be reconciled separately by
the package owner when native validation lands.
