# First detached contract attempt — failed

Command: pinned Godot `--headless --path godot --script res://tests/lattice/world_contract.gd`.

First attempt timed out after 20 seconds following `valid wire accepted false`, `owned living pose enables capture false`, `camera uses exact source eye position false`, then invalid `flux` dictionary access in the test. A 5-second diagnostic repeat printed:

```
RAW true FLOATMEM false decoded false
```

Cause: Godot Array membership is type-sensitive (`0.0 in [0,1]` is false); JSON numbers decode as floats. The world-only guard incorrectly rejected legitimate team/owner IDs. Corrected to wire-integer validation and numeric comparisons, as the existing transport does. No graphical run occurred in these two attempts. Timed-out child processes were terminated by the harness. This failure is retained rather than reported as passing verification.
