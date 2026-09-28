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
deck checks. Connected source-backed processes must recover the same identity
hash. The first combat route selects an available starter attachment through the
displayed MODS tab/action button, waits for the source-marked equipment reply,
and subsequent source-backed routes must recover that confirmed selection.
Markers contain route, profile-presence flags, layout bounds and the public
catalog item ID. Source identity IDs and credentials are never emitted; only
an identity hash is retained to compare continuity.

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
python3 tools/godot-dev/xvfb_run.py node tools/godot-dev/product_journey.mjs --itinerary=port/native-shell/itineraries/consolidated.json --capture
```

The journey owns an isolated `COCS_CAREER_ROOT` beneath its unique attempt
directory. It exercises source-session lifecycle, native equipment selection and
cross-process identity restoration. It does not grant unlocks, perform a purchase,
or replace human visual/play acceptance.
