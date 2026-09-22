# First run: visual FAIL (retained)

The driver completed ordinary approach/escort/release and cleanup successfully.
That observation exit is **not visual acceptance**. Direct review of all four
960x640 PNGs found the new cart guidance row invisible: auto-wrapped Label had
zero height. Runtime HUD text receipts alone did not reveal it. Fix: explicit
20 px minimum and no text trimming; regression asserts actual allocated height.

`guidance-off-cart.png` is actually a natural spawn **inside** radius, already
pushing without capture. Filename was planned, not a state assertion. The later
approach image is outside radius. Final helper labels natural spawn honestly and
requires an actual off-cart capture. No reroll, state or timing changes.
