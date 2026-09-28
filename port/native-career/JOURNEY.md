# Career coverage in the rendered product journey

The source-driven `product_journey.mjs` drives Home and an owned session for
each itinerary entry across three cycles. Each Home process opens the real
Career button, verifies **NO CONNECTED CAREER** and Back focus, then launches
the selected route. Each live process opens F12 Settings → Career, checks that
the overlay is exclusive and unpaused, and returns to SettingsBack before
Leave. Combat and LATTICE require a nonempty profile from their actual seated
source client (`career_seated` + `room_id`); other adapters report only what
their real welcome yielded. The final Home verifies that a previous process's
profile has not been silently restored. Six-entry 18-session runs require 19
Home Career and 18 live Career checks in the summary, plus the existing three
deck checks. Markers record only route, boolean profile presence and bounds;
no identity, tokens or profile values are emitted.

With `--capture`, the first Home and first LATTICE live profile are captured
at 1280×800, 760×520 and 760×520 at 150% UI scale. The fixture checks
horizontal bounds of the scroll surface, catalog rows, and Back action and
checks Back is reachable without scrolling at each sampled size. Captures
stay in the attempt directory under `.port-runtime/product-journeys/`; the
summary hashes their bytes.

Run from an integrated checkout with the pinned `GODOT_BIN` and the existing
`COCS_SOURCE_DERIVATIVE` environment, after source imports are ready:

```sh
node --check tools/godot-dev/product_journey.mjs
python3 tools/godot-dev/xvfb_run.py node tools/godot-dev/product_journey.mjs --capture
```

This is scripted source-session lifecycle evidence, not a purchase, equip,
cross-launch identity restoration or human visual-acceptance test.
