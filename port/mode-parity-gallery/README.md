# Mode-parity gallery captures

`capture.mjs` runs the real Godot menu, local Native Deathmatch authority, and
source Horde authority serially on Xvfb/llvmpipe. The committed PNGs and
`evidence/captures.json` were made at the port revision recorded in the manifest;
the source remains pinned by `port/contracts/source-lock.json`.

To regenerate, use the pinned Godot 4.5.2 executable:

```sh
GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 \
  node port/mode-parity-gallery/capture.mjs all
```

The default output is `port/mode-parity-gallery/evidence`; use `GALLERY_OUT` to
stage an inspection run elsewhere. Each scene exits and its local authority
closes before the next scene starts. `capture.mjs` records PNG dimensions,
SHA-256 and event/actor evidence in `captures.json`. Horde's test-only lethal
damage is deliberately sent through the real source `Match.damage` method;
the game's event handling creates the fall and blood burst. Thumbnails ending
in `-detail.png` are explicitly labelled nearest-neighbour crops, with full
frames retained and linked.

To update the owner's existing LAN gallery, run:

```sh
GALLERY_SITE=/tmp/opencode/cocs-gallery-site node port/mode-parity-gallery/publish.mjs
```

The publisher validates all ten PNGs and the source pin, preserves older
screenshots and Moth pages, and updates the index idempotently. The 24-bot
image depicts the menu capacity, **not** a rendered 24-bot match. CPU-only
llvmpipe rendered attempts backed up the authority's outgoing queue and
disconnected; the separate headless 25-actor smokes passed. Hardware visual
quality, FPS and gameplay feel still require the owner's playtest.
