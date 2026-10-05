# Runtime dressing profiles — vesper-viaduct, abyssal-pressureworks, stormglass-causeway

Authoring and verification tooling for the three runtime Moth dressing profiles that
were missing. `helix-conservatory`, `gravemill-foundry` and `parallax-observatory`
already had profiles and `Profile.IDENTITIES` entries; these three maps had neither,
so `Dressing.apply()` returned `status: "ineligible"` for them.

## What lives where

| File | Role |
| --- | --- |
| `author.mjs` | The authored source of truth. Holds the material/panel/sign/pocket tables for all three maps and emits the profile JSON byte for byte. |
| `check.mjs` | Independent verifier. Re-implements `profile.gd`'s closed schema in Node and cross-checks every selector against the map's own art GLB. |
| `validate_profiles.gd` | Headless Godot validator. Calls the real `Profile.validate()`, i.e. the authority `binder.gd` itself calls. |

The emitted profiles live at `godot/multiplayer_worlds/dressing/profiles/<map>.json`.

## Commands

```sh
# 1. authoring is reproducible: fail if the committed JSON drifted from author.mjs
node tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs --check

# 2. rewrite the three profiles (only needed after editing author.mjs)
node tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs --write

# 3. schema / budget / selector / Moth-resource check (no Godot needed)
node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs
#    controls: the checker must also accept the three already-shipped maps
node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs \
  helix-conservatory gravemill-foundry parallax-observatory
```

`check.mjs` reads `godot/material_language/{families,library}.gd` from the checkout
when the sparse worktree has materialised them and otherwise from
`git show HEAD:<path>`, so it runs in a sparse worktree without copying files into
the repository.

## Running the headless Godot check

The assigned worktree is a sparse checkout: `godot/material_language/**`,
`godot/moth_scenery/**` and every autoload target in `godot/project.godot` are
skipped, so `--path godot` cannot boot there. Build a throwaway sandbox that
symlinks only the `res://` paths the validator needs:

```sh
W=<worktree>
S=/tmp/opencode/dressing-godot
G=/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64

rm -rf "$S"; mkdir -p "$S/multiplayer_worlds/dressing"
printf 'config_version=5\n\n[application]\nconfig/name="COCS dressing validator (sandbox)"\n' > "$S/project.godot"
ln -s "$W/godot/moth" "$S/moth"
ln -s "$W/godot/multiplayer_worlds/dressing/profile.gd"  "$S/multiplayer_worlds/dressing/profile.gd"
ln -s "$W/godot/multiplayer_worlds/dressing/profiles"    "$S/multiplayer_worlds/dressing/profiles"
ln -s "$W/tools/godot-multiplayer/new-maps/runtime-dressing/validate_profiles.gd" "$S/validate_profiles.gd"
( cd "$W" && git archive HEAD godot/material_language ) | tar -x -C "$S" --strip-components=1

"$G" --headless --path "$S" --script res://validate_profiles.gd
```

Godot imports the Moth PNGs into the sandbox's own `.godot/` on first run; no
`--import` flag and nothing written back into the worktree. Omitting the map
arguments validates every entry in `Profile.IDENTITIES`.

## Scope

Source-only. Nothing here runs a native capture, a Blender export or a renderer, so
no visual or native acceptance is claimed. See
`port/finish/map-variety/RUNTIME_DRESSING_THREE_MAPS_20261005.md`.