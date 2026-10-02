# Pass two: spatial wet surfaces and rain contact

Status: **READY FOR ENGINE**, implemented and source-verified; native execution awaiting explicit engine grant.
Base: `51c29dc9`, branch `improvement/pass-two-world`.

## Confirmed gaps and source contracts

- `game/textures.mjs:9–27,670–699`: cached 128² wet texture, integer value-noise / FBM, seeds +411/+913, 75/25 blend, .18 roughness contrast. First pass explicitly deferred this texture (`port/next-port/world/PARITY.md:35`). Port exact pixels, linear data, no albedo tint.
- `game/view.mjs:4073–4090`: wet texture activates above .01; authored roughness map restores when dry. Retain existing clone-once material leases and scalar response. StandardMaterial uses source-equivalent roughness-map substitution. Three allowlisted native shader families preserve authored data/normal/color and multiply final roughness by the same wet field; world-space mapping adapts UV-less terrain.
- `game/view.mjs:3977–3989`, `game/effects-fx.mjs:225–272`: every fifth drop, maximum three schedules per update, sampled support, .02 contact offset, delayed .5-second expanding/fading ring, 18-slot oldest-first pool. Native must sample existing static support and never create colliders or use a guessed floor plane.
- `game/view.mjs:3004–3019`: boost exhaust and gun heat exist in source. Deferred from this coherent weather batch: binding those to native model anchors requires separate fleet ownership changes; no generic heat distortion is evidenced by source.

## Scope and budgets

Production ownership: `godot/ambience/`; focused fixtures under `godot/tests/world_weather/`; oracle scripts under `scripts/`. No source, authority, map registry, geometry or authored shader files changed. Preserve map-owned environment resolution, mute-independent visual tick, baseline restoration and existing 256 material / 16,384 binding caps.

One shared wet image per bound map (128² RGBA8 plus mipmaps); up to three leased shader variants. No surface geometry/pass added. One 18-instance splash MultiMesh (36 triangles maximum), at most six support queries per precipitation update. Disabled, reduced, zero-quality, stale/focus, rebind and rewind clear contacts. Repeated authority timestamps cannot emit again. Existing 48-drop pool retained.

Native acceptance must measure, rather than assume, shader compilation, bind CPU, resource bounds and visual quality. Software-renderer evidence supports no hardware GPU-performance claim.

## Explicit adaptations

- Shader variants are leased once per allowlisted original shader and released with the existing map lease. Exact reviewed final-roughness anchors are checked by the Node oracle; a changed anchor fails closed. Authored shader files are untouched. StandardMaterial preserves its original texture and channel for dry restoration; the source field replaces the roughness texture while wet. Native UV-less shaders multiply existing authored roughness detail using an eight-metre world-space tile.
- Contact rays accept only upward-facing support owned by the bound static map. A missing destination contact is rejected rather than using the source fallback height. Slopes orient the ring to the collider normal. The six-query budget can suppress more contacts near voids than the source's successful-spawn-only budget.
- Native ripple age uses authoritative timestamps. Source `RipplePool.update` spends one delta at the delay crossing; native starts at exact contact time and compares the same .5-second envelope at equivalent ages. Duplicate timestamps freeze both emission and envelope.
- The source 48² radial-mask equation is evaluated directly in the contact shader instead of allocating another image; its .75 rim, .1 width and 1.6 inner falloff remain intact. Per-texel byte rounding/filtering parity is not claimed for this analytic mask.
- Rain drift stays at its descriptor velocity so delayed contacts and drops follow the same horizontal trajectory; snow/ash retain the existing gust modulation. This changes presentation only.
- The round/seek AV hook is supplied as a separate commit: clear transients at explicit round/seek boundaries and wait for the first fresh context before advancing weather. Mute ordering remains visual-first.
