# COCS: DESTINATIONS — combat expansion (development prerelease)

This build turns the graphics demo into something you can actually play: six deathmatch
arenas, the original source operators, detailed weapons, and a full combat-effects pass.

## Download

- `cocs-native-windows.zip` (checksum in the adjacent `.sha256`)
- Windows 10/11 x64, OpenGL 3.3 driver, no install or account needed. Godot 4.5.2 and
  Node 22.22.0 are bundled.

## Play

1. Extract the ZIP, open the `cocs-native-windows` folder.
2. **Play.cmd** — Meridian Exchange deathmatch with bots.
3. **Native Deathmatch.cmd** — choose any of six maps:
   - Prism Foundry, Aurora Basin, Cinder Array (native arena variants)
   - Lacuna Court, Vermilion Fold, Nacre Engine (new visual-identity maps)
4. **Graphics Showcase.cmd** — the standalone exploration and effects labs.
5. **Demo Menu.cmd** — everything else: Horde, Arms Race, zone modes, vehicles, sports,
   Lattice and the operator viewer.

## What is new

**Six playable deathmatch maps.** Three arenas (Prism Foundry, Aurora Basin, Cinder Array)
plus three new visual identities: Lacuna Court (sunlit mineral court with a split
resonator), Vermilion Fold (folded civic ribbons over jade), Nacre Engine (pearl vaults
over ultramarine). All six run the authoritative source simulation with bots, pickups,
scoring, respawns, results and restart. Domination and Horde layouts for the new maps are
wired but not yet released.

**The original operators.** The high-detail source models now appear in matches with their
articulated rigs, real third-person weapons, and post-pose hand grips solved against the
actual weapon contacts.

**Detailed, distinct weapons.** All ten weapons were rebuilt with real geometry —
519 reusable detail primitives adding ~9,280 first-person triangles and tripling the
third-person models — and each commits to a distinct identity: receiver massing, feed type,
muzzle device, stock and grip, sight family, and a signature accent motif. Handling detail
includes animated bolts, charging handles, authored magazine motion driven strictly by the
authoritative reload, pooled casings for the weapons that eject them, and barrel heat that
never occludes the sights. ADS sight alignment remains exact.

**Combat effects.** Interference shields on real protection/armor state, directional
damage indicator, low-health state, shield-break cue, death and respawn feedback,
material-aware impacts, animated barrel-tip weapon effects with wall occlusion, and
bounded world particles. F9 cycles Low/High/Extreme; F10 shows real allocations.

**Blood and splatter.** Hits produce directional spurts scaled by real health damage;
deaths produce a dense burst, a growing pool and clusters of stains on floors and walls,
never through geometry. Shield- and armor-only hits never bleed. The fluid colour and
scale are tunable at one documented point (default crimson).

**Massive particles.** The particle pool supports Low 8K / High 32K (131K on native
arenas) / Extreme 1,000,000 total slots. The owner's GPU ran the million-particle lab
smoothly; this build's own measurements are software-renderer only.

## Controls

- **WASD** move, **mouse** look, **LMB** fire, **RMB** aim down sights
- **Space** jump, **Shift** sprint, **Ctrl/C** crouch, **R** reload
- **Q** power, **F** melee, **G** grenade, **E** interact, **X** mobility, **Z/MMB** alt fire
- **1–9 / 0 / wheel** weapons, **Tab** scores, **Esc** release the mouse
- **Enter** restart after results, **F8** scenery detail, **F9** combat effects quality,
  **F10** resource metrics

## Honest limitations

- All performance numbers in this project's evidence are Linux OpenGL Compatibility on
  **llvmpipe software rendering** — not hardware-GPU acceptance. Measure on your machine.
- The three new maps are stylized first-pass art: no baked lightmaps, no textures beyond
  the shared Moth palette.
- Domination (Vermilion Fold) and Horde (Nacre Engine) are not in this release; their
  layouts and data exist, the mode routes do not.
- Campaign remains deferred. Full Horde progression and the full Arms Race ladder are
  still open, as are the inherited combat setup popup, some small-resolution HUD
  overlaps, and mounted-combat acceptance.
- The source asset-rights audit remains unresolved; this package does not establish new
  rights to the original assets.

## Diagnostics

`Play.cmd --smoke` runs a headless network check. `manifest.json` records source and port
commits, every packaged file's SHA256, the runtime closure and the feature inventory.
