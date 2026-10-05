# Runtime dressing profiles — vesper-viaduct, abyssal-pressureworks, stormglass-causeway, gravemill-foundry

Authoring and verification tooling for the runtime Moth dressing profiles.

Three of these maps had no profile and no `Profile.IDENTITIES` entry, so
`Dressing.apply()` returned `status: "ineligible"` for them; that is the set
`author.mjs` was written for. `gravemill-foundry` joined it later: its profile
already existed, but the reviewed Foundry R7 art promoted into the runtime world
path (`e7e330ae`) added ten finish-role materials the profile had never seen, so
the binder began reporting `incomplete_coverage` with those ten unmatched. The
cause was that its authoring source, `port/map-finish/gravemill-foundry/author.py`,
pins the pre-R7 GLB byte-for-byte and fails closed once the art changes, so the
profile could not be regenerated. `author.mjs` is now the source of truth for it
too, and the byte-drift check in `check.mjs` covers it. `helix-conservatory` and
`parallax-observatory` remain controls.

## What lives where

| File | Role |
| --- | --- |
| `author.mjs` | The authored source of truth. Holds the material/panel/sign/pocket tables for all four maps and emits the profile JSON byte for byte. |
| `check.mjs` | Independent verifier. Re-implements `profile.gd`'s closed schema in Node and cross-checks every selector against the map's own art GLB. |
| `negative.mjs` | Negative suite. Breaks one rule at a time in a throwaway copy of a control profile and asserts `check.mjs` rejects it, so the verifier is shown to fail as well as pass. |
| `validate_profiles.gd` | Headless Godot validator. Calls the real `Profile.validate()`, i.e. the authority `binder.gd` itself calls. |

The emitted profiles live at `godot/multiplayer_worlds/dressing/profiles/<map>.json`.

## Commands

```sh
# 1. authoring is reproducible: fail if the committed JSON drifted from author.mjs
node tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs --check

# 2. rewrite the four profiles (only needed after editing author.mjs)
node tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs --write

# 3. schema / budget / selector / Moth-resource check (no Godot needed)
node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs
#    controls: the checker must also accept the two maps it does not author
node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs \
  helix-conservatory parallax-observatory

# 4. the checker must also reject
node tools/godot-multiplayer/new-maps/runtime-dressing/negative.mjs
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

Note that `$S/multiplayer_worlds/dressing/profiles` is a **symlink** to the
worktree's profile directory, so a validator run reads the committed profiles
directly. To run a negative control against the validator, copy that directory
into the sandbox instead of symlinking it, otherwise the edit lands on the
worktree file.

## Rendering the profiles

`check.mjs` proves the profiles are schema-valid, in budget and grounded in each
map's own art. It cannot prove a plate is *visible*, because that depends on which
way the plate faces. A second sandbox renders the real `WorldMap` + binder path and
reads `binder.gd`'s own report back, which is what settles facing:

```sh
W=<worktree>
S=/tmp/opencode/dressing-engine
G=/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64

rm -rf "$S"; mkdir -p "$S"
printf 'config_version=5\n\n[application]\nconfig/name="dressing check"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n' > "$S/project.godot"
ln -s "$W/godot/moth" "$S/moth"
# symlink the whole world directory, so generated/, art/ and dressing/ all come
# from one commit. Mixing a generated/ from another checkout can make the binder
# return identity_mismatch and silently dress nothing.
ln -s "$W/godot/multiplayer_worlds" "$S/multiplayer_worlds"
( cd "$W" && git archive HEAD godot/moth_scenery godot/material_language ) | tar -x -C "$S" --strip-components=1

"$G" --headless --path "$S" --import
DISPLAY=:77 "$G" --path "$S" --script res://gallery_capture.gd -- --out=/tmp/shots
```

The GLB is 15 MB and takes a minute to import on a cold cache. `--headless` boots
and validates, but it cannot produce a frame, so any capture run needs a display
(`Xvfb :77 -screen 0 1600x900x24 -nolisten tcp` works). To compare two profile
revisions, build a second sandbox that differs only in its `dressing/profiles`
directory and render the identical eye/target list through both: a plate whose yaw
was inverted differs by the whole plate silhouette, not a few edge pixels.

## Placement convention

`binder.gd:_plate` builds every panel and sign as a `QuadMesh`, whose front face
is its local `+Z`, and both `panel.gdshader` and `wear_panel.gdshader` declare
`cull_back`. A yaw of 0 therefore faces `+Z`, 90 faces `+X`, 180 faces `-Z` and -90
faces `-X`, and a plate is mounted a short way off the solid it dresses, offset
along the direction it faces (`panel.gdshader`: "mounted 32 mm off an existing
solid"). Horizontal dressing uses pitch instead of yaw: `-90` faces up (floors,
decks, cap tops), `+90` faces down (canopy soffits). `author.mjs` exposes this as
`FACE_UP`, `FACE_DOWN` and `faceYaw(fx, fz)`.

The rule that follows from it: **a plate's yaw must point away from the solid it
is mounted on.** Getting this backwards is invisible in `check.mjs` — the entry is
schema-valid, inside budget and inside bounds — and invisible in `author.mjs
--check` too, because the profile on disk matches the table. It only shows up as a
missing plate on screen. Two first-pass families had it inverted (`vesper-viaduct`
`parcel-plate-*`, `stormglass-causeway` `gate-readout-*`) and were fixed in the R7
follow-up; the facing probe under "Rendering the profiles" is what proves it.

`check.mjs` cannot catch this class of error, so it is checked against the art
geometry by hand when a family is authored: read the mounting solid's own face
spans out of the map GLB, pick a plate that stands off one of them, and state which
face it faces.

## Scope

Source-only. Nothing here runs a native capture or a Blender export, so no native
acceptance is claimed. The rendering recipe above produces diagnostic frames in a
throwaway `/tmp` sandbox to answer facing and coverage questions; those frames are
review evidence, not a delivery capture, and they are not committed. See
`port/finish/map-variety/RUNTIME_DRESSING_THREE_MAPS_20261005.md` and its two
addenda, `port/finish/map-variety/RUNTIME_DRESSING_RICHER_20261005.md` and
`port/finish/map-variety/RUNTIME_DRESSING_GRAVEMILL_R7_20261005.md`.