# Scenery verification and visual review

## Accepted run

**[run-8v2okgl0](evidence/run-8v2okgl0/summary.json)** passes all five native steps:
import, all-nine headless verification, 960×640 captures, 1280×800 captures and
all-nine real GL verification. The pixel/camera report is
[matched-pixels.json](evidence/run-8v2okgl0/matched-pixels.json), with
[review-summary.json](evidence/run-8v2okgl0/review-summary.json).

- Godot **4.5.2.stable.official.6ce3de25a**, GL Compatibility, Mesa 25.2.8,
  llvmpipe LLVM 20.1.8. The software driver's unsupported-VSync warning remains
  in logs; no script, shader, resource or leak errors in the accepted run.
- Exact existing source catalog: revision
  `51289b79c627a26a381ba556b92bab71f93f3732`, manifest SHA-256
  `5c756d02edff6bb85f71c4659508d0a941d936d90787d0752957fadda65f4ccf`.
- **Nine source maps**, every dictionary recursively frozen, all mounted corners
  independently checked against source faces. Ordinary viewer block/support
  counts and pre-existing child transforms preserved.
- Repeated same-frame `create`/`decorate`, double clear, full/low/off/full UI
  selection and map teardown pass. Prior nodes, MultiMeshes and materials are
  released; the visible settings control retains only a weak scene reference.
- Geometry hashes, every mounted position and every ambient initial point
  match exactly between the headless and actual Compatibility runs:
  [geometry.json](evidence/run-8v2okgl0/geometry.json),
  [geometry-graphical.json](evidence/run-8v2okgl0/geometry-graphical.json).
- Pocket motion is finite and stays inside explicit AABBs at sampled clocks
  0, 1, 20 and 4000 seconds. Spatial rejection excludes source solids and
  elevated terrain. No script processing callbacks or gameplay children.
- **36 scene PNGs**, including **12 matched before/after pairs**, plus **12
  no-LUT/alternate-clock probe PNGs**. Both requested resolutions are asserted
  from actual image bytes, not file names. All street/service cameras are at
  source support +1.8 m and outside source solids.

## Actual counts and hard ceilings

| Map | Full mounted quads / cap | Low quads | Motes / cap | Pockets | Full batches | Total triangles |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Meridian Exchange | 176 / 176 | 95 | 120 / 120 | 3 | 6 | 592 |
| Verdant Reliquary | 63 / 112 | 36 | 120 / 120 | 3 | 7 | 366 |
| Ember Crucible | 170 / 176 | 100 | 192 / 192 | 4 | 8 | 724 |
| Tidal Citadel | 168 / 168 | 92 | 192 / 192 | 4 | 7 | 720 |
| Sunscar Convoy | 152 / 152 | 89 | 160 / 160 | 4 | 7 | 624 |
| Asterion Relay | 216 / 216 | 154 | 64 / 64 | 2 | 7 | 560 |
| Monsoon Foundry | 216 / 216 | 152 | 120 / 120 | 3 | 7 | 672 |
| Ion Speedway | 44 / 88 | 28 | 0 / 0 | 0 | 3 | 88 |
| Aurora Stadium | 88 / 96 | 64 | 0 / 0 | 0 | 3 | 176 |

Low has **zero motes** on every map. Off has **zero renderer children**. Counts
are concurrent per selected map, not pooled across maps. The maximum observed
cost is eight MultiMeshes / 724 triangles; hard ceilings are 10 batches,
216 mounted quads and 192 motes, all well below the requested 512-particle cap.

## Direct image inspection

Opened the original before/after **street PNGs for all three review maps at
both 960×640 and 1280×800**, the original six 1280×800 service before/after PNGs,
the 960×640 service comparison sheet and the final other-six overview sheet.
The inherited source texture/normal and FX/LUT sheets were inspected first.
Review sheets only resize and label; they do not change color or exposure.

| Review | Links |
| --- | --- |
| Meridian street, 1280×800 | [Before](evidence/run-8v2okgl0/1280x800/meridian-exchange-street-before.png) · [After](evidence/run-8v2okgl0/1280x800/meridian-exchange-street-after.png) |
| Ember street, 1280×800 | [Before](evidence/run-8v2okgl0/1280x800/ember-crucible-street-before.png) · [After](evidence/run-8v2okgl0/1280x800/ember-crucible-street-after.png) |
| Asterion street, 1280×800 | [Before](evidence/run-8v2okgl0/1280x800/asterion-relay-street-before.png) · [After](evidence/run-8v2okgl0/1280x800/asterion-relay-street-after.png) |
| Relay-feed bank, first person | [Before](evidence/run-8v2okgl0/1280x800/asterion-relay-service-before.png) · [After](evidence/run-8v2okgl0/1280x800/asterion-relay-service-after.png) |
| Street comparison sheets | [960×640](evidence/run-8v2okgl0/review-960x640-street.jpg) · [1280×800](evidence/run-8v2okgl0/review-1280x800-street.jpg) |
| Service comparison sheets | [960×640](evidence/run-8v2okgl0/review-960x640-service.jpg) · [1280×800](evidence/run-8v2okgl0/review-1280x800-service.jpg) |
| Other six actual maps | [960×640](evidence/run-8v2okgl0/review-960x640-other-six.jpg) · [1280×800](evidence/run-8v2okgl0/review-1280x800-other-six.jpg) |

**Findings:** Meridian's previously plain civic faces gain small warm diagnostic
panels and thin segmented strips; their muted contrast stays below the baseline
white windows/cyan cover edges. Ember's furnace-column silhouettes remain
identical while etched panels, vents, warm vertical lights and local gray ash
make the machinery readable at ordinary eye height. Asterion's cool feed bank
has visible original circuit grid/etch detail, narrow white-blue service lights
and flanking louvers. No panel spans a door, extends into a walking gap or
requires an aerial camera to be seen. Labels, route openings and pickup
silhouettes match the before images. The ambient contribution is intentionally
small; it is clearest beside Ember's furnace columns, not as a whole-map veil.

The other-six overview sheet confirms that Verdant remains green daylight,
Tidal cold/snowy, Sunscar dusty warm, Monsoon damp green-gray, and both sports
maps keep their existing track/pitch silhouettes. Their accent placement and
budgets receive the same full geometry checks; these overview images are not
claimed as first-person review for those six maps.

### Actual pixel contributions

At 1280×800, adding scenery changes **8,420 / 13,485 / 12,882** pixels by more
than 5 RGB levels in the Meridian/Ember/Asterion street views: approximately
**0.82% / 1.32% / 1.26%** of the image. This is a localized accent layer.
The closer service views change 14,960 / 24,193 / 87,363 pixels.

Disabling only the original linear LUT changes **292 / 9 / 1,070** service-view
pixels by more than one RGB level, respectively. At 960×640 the values are
177 / 8 / 670. Ember's LUT is particularly sparse/subtle; its readable primary
accent comes from the baked circuitry and warm light strips, not a claimed
large LUT effect. Advancing only the shader clock from 12 to 25 seconds changes
3,855 / 4,330 / 15,587 pixels at 1280×800. No script advances particles or panels.
All per-view measurements and bounds are in the linked JSON.

## Preserved failures and superseded art pass

- **[run-lv7kclhs](evidence/run-lv7kclhs/verify-headless.log):** runtime failure
  assigning a conditional untyped Array to `Array[Vector3]`, followed by a test
  indexing the empty scene. The outer timeout interrupted summary generation;
  a clearly labeled reconstruction records that failure. Fixed the container
  typing, added early failure and bounded Godot frame count.
- **[run-9ue3dihw](evidence/run-9ue3dihw/verify-headless.log):** independent motion
  checks caught the initial vertical-offset sign error. The same run exposed
  Ion's three-metre solid apron hiding low plates. Fixed the signed initial
  mote height and explicitly raised Ion's source-mounted maintenance accents
  above that apron. Full original logs and geometry evidence retained.
- **[run-1a75im6r](evidence/run-1a75im6r/summary.json):** technical checks passed,
  but direct inspection found the displays too gray/indistinct, vertical strips
  insufficiently legible, and a relay service camera mostly showing a column.
  Preserved all images. Final pass uses original circuit-channel contrast,
  properly oriented thin strips, multiple relay-feed panels and a clear
  first-person service angle. `run-8v2okgl0` supersedes this earlier art pass.

## Exact staging boundary

The only shared-file adaptations exist in the **temporary copied project** and
are captured verbatim in
[private-staging.patch](evidence/run-8v2okgl0/private-staging.patch). The before
and after images share these adaptations: inherited triplanar surfaces,
Compatibility vertex colors and inherited atmosphere. The actual lead's richer
semantic texture mapping was not copied or edited. No shared viewer/style,
session, mode, map, atmosphere or source-Moth file is part of this commit.

The lead hook and visible performance control are in [README.md](README.md).
Final integrated live HUD/weapon/objective and package review remain with the
lead; this evidence establishes deterministic, bounded existing-world scenery.
