# Audio fixture timing follow-up

GitHub-hosted run
<https://github.com/mojomast/cocs-godot/actions/runs/35677813370> at `da1f571`
failed the inherited audio test at “shot available again after original ends
and monotonic cooldown”. The preceding hosted run passed that same test. The
downloaded failed gate log and full partial verification report are preserved
here; that run remains FAILED.

The fixture waited for a fixed 160 ms SceneTree timer, then assumed two
independent preconditions: the Dummy mix thread had finished the original cue,
and the runtime monotonic cooldown had expired. Neither was observed before
replaying the cue. The failed log does not identify which precondition lagged.

The fixture now yields frames until **both actual conditions** hold, bounded by
two seconds of real monotonic time, then performs the original replay assertion.
The later natural-finish assertion likewise observes all voices stopping under
a two-second deadline. No forced stop, playback completion signal injection,
cooldown mutation or production sound/runtime change was introduced. A cue that
never finishes still fails. The new assertion increases the fixture to 38 checks.

Focused runs pass under the normal clock and synthetic `--fixed-fps 240` and
`--fixed-fps 30` clocks, retaining exact commands and logs in `results.json`.
Those two fixtures deliberately decouple engine delta from wall time; they do
not run or accelerate an authoritative gameplay server. Hosted resolution
requires a new observed Actions run rather than relabeling the failed one.
