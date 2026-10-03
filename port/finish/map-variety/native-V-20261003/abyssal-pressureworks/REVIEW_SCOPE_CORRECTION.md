# Post-delivery review scope correction

The original `README.md` and capture reports are hash-pinned historical records
from `03b3db50`; they remain byte-identical. Their claim that the parent snapshot
has no WeatherService is incorrect.

**WeatherService exists in the parent but is excluded from this isolated stage.**
`godot/ambience/weather_service.gd` exists in `a8b3fe6b` and the delivery tree.
The stage archive allowlist excludes `godot/ambience/`, and the generated project
does not install production autoloads. No native rebuild is needed to correct
this explanation. Future capture scripts now use the correct scope text.

The 518 capsule checks are **static finite-body placements**, including nine
ramp-only placements with a conservative 0.15 m lift. They are not exact grounded
controller poses or continuous journeys. Near-player interior camera eyes are
2 m above valid support, versus `MOVE.eyeStanding` at 1.45 m; exterior inspection
views are unsupported and are not player-eye acceptance.

Independent review approves this specific `b010a076…9ee3aa86` successor for staged
source/artifact integration and closes the demonstrated interior T contact defect.
Hosted modes, controller journeys, swept cameras, exterior/special traversal,
weather finish, gameplay performance and manual visual acceptance remain pending.
Full parent review: `../../ABYSSAL_V_REVIEW.md`.
