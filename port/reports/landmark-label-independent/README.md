# Close-range landmark readability

The independently accepted objective screenshots showed WEST CITADEL growing
across the view near its authored location. Native landmark `Label3D` instances
now use a **10 m minimum visibility distance**. Their original font, pixel size,
depth testing and 120 m maximum range remain the same.

Controlled offline captures at 6 m and 30 m from the same authored Tidal label
passed at **960×640 and 1280×800**, with owned private displays and process-group
cleanup. `capture.py before` records baseline `424f74f`; `after-revised` records
the final change. Each summary includes the tested style hash and exact commands.

The lead directly inspected baseline close-up, the initial reduced-size variant,
and final close/far images. The first trial (`after/`) also reduced pixel size;
it was rejected because distant text became too small. Those trial images stay
retained. Final `after-revised/` hides the nearby label and restores the original
distant size. **Both final far PNGs are byte-identical to baseline.**

```sh
GODOT_BIN="$PINNED_GODOT" python3 -B port/reports/landmark-label-independent/capture.py after-revised
```

The script rejects an existing output directory to preserve prior observations.
Use a fresh copy of this fixture for another reproduction. These are deliberately
labeled **offline presentation views**, not source gameplay or new progression
acceptance. The runtime change touches only landmark presentation. The prior
59-gate local/hosted snapshots remain the accepted gameplay baseline.
