# Next Windows release — gated checklist

Owner has confirmed the weapon detail/differentiation work must ship in this release.
Execute in order; do not start the package build until every gate below is committed
and green on one frozen tree.

## 0. Preconditions (all must be true before starting)

- [ ] All active lanes committed: first-person weapon detail, third-person weapon detail,
      Cinder caldera terrain fix, blood FX (landed `80d755a8`, wired by lead), identity
      art, operators, weapon handling, player-state FX, arena trap fix.
- [ ] `git status --short` shows no uncommitted runtime files under `godot/**`,
      `tools/**` or `port/native-arenas/**`. The builder refuses uncommitted data on
      purpose (`dataFiles` / `identityDataFiles` must match committed bytes).
- [ ] `port/combat-expansion/evidence/` contains the acceptance records for the freeze.
- [ ] No lane is writing to shared files.

## 1. Frozen-tree verification

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export PORT=0
export TMPDIR=/tmp/opencode
python3 tools/godot-dev/verify.py            # full aggregate, all gates
git diff --check
git status --short
```

The aggregate now includes, beyond the original suites:

- identity prototypes: graybox/oracle/rays/lifecycle gates
- native arenas: authority, actual-maps, session, composition, per-map launcher smokes
- weapon handling (5,295), ADS contract, first-person binding (owned private display)
- player-state FX: direction/low-health/lifecycle/impacts/overlay/integration
- blood/fluid FX: contracts/surfaces/stress
- identity route/package acceptance: `port/native-identity-dm/evidence/`

Any failure blocks the build. Fix or revert — never weaken a gate to pass.

## 2. Windows package build

```sh
python3 tools/godot-package/build.py --target windows \
  --state /tmp/opencode/cocs-rebuild-<date> \
  --archive-directory /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain
```

- Toolchain archives are present and SHA-512 verified in that directory.
- Default `--operator-models source-operators` (no staging patch).
- Expected closure: locked source modules, port adapters, three native arena JSONs,
  three identity JSONs, all Godot natives (including `source_operators/**`,
  `identity_maps/**`, `blood_fx/**`, `player_fx/**`, `weapon_effects/**`).
- Record ZIP size, SHA256, manifest SHA256 and the source commit in the evidence dir.

## 3. Hosted Windows verification

```sh
gh workflow run windows-demo.yml -f tag=<new-tag>
gh run watch <run-id>
```

`tools/godot-package/verify_windows.mjs` must pass: bundled runtimes, three combat maps,
three identity Deathmatch maps, five native-only graphics routes, packaged source-operator
inventory, PCK probe, listener/process cleanup, and `NATIVE_DM_SMOKE_OK` per map.

## 4. Manual smoke on the built package

1. Extract the ZIP into a path with spaces.
2. `Native Deathmatch.cmd` → each of the six maps: bots move and fight, weapons swap,
   ADS aligns, effects render, results + Enter restart.
3. Confirm the weapon detail is visible and distinct per weapon in the first person
   **and** on remote operators.
4. Blood spurts on hits and a death splatter with staining; F9 Low removes the heavy
   layers and F10 shows real counts with `gpu_live_readback:false`.
5. Confirm no script/engine errors in any console window.

## 5. Publication

```sh
gh release create <new-tag> path/to/cocs-native-windows.zip path/to/cocs-native-windows.zip.sha256 \
  --title "..." --notes-file port/combat-expansion/RELEASE_NOTES.md --prerelease
```

- Preserve the previous release untouched (`graphics-demo-2026-09-22`,
  `windows-demo-2026-09-22`).
- Verify anonymous download and checksum access after publishing.
- State plainly in the notes: llvmpipe/software measurements, no hardware-GPU acceptance,
  Domination/Horde content not yet released, campaign deferred.

## 6. Post-release

- [ ] Update `port/RELEASE_MATRIX.md` and `port/handoffs/ACTIVE_LANES.md`.
- [ ] Push source to `godot/main` after the release assets are verified.
- [ ] Keep generated binaries outside git.
