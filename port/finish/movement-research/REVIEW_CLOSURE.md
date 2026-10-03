# Independent-review follow-up — 2026-10-03

Follows movement implementation `91f58a1c` and campaign source-generation closure
`9d95623d`. Production physics, native clients and weapon cue source remain
byte-identical to those commits; no generator or dependency-pin change is needed.

## Executable gate registration

`tools/godot-dev/verify.py` now registers **first-person-slide** alongside the
existing first-person rig gates. It runs
`res://tests/first_person/slide.gd` headlessly, after the existing `godot-import`
gate. Its explicit asset prerequisite is
`godot/first_person/generated/weapon-0.glb`; a missing file produces a failed
`missing-prerequisite` record without launching the fixture. The existing import
gate must have prepared that GLB and the project's script/resource dependencies.

Both **campaign-input-flow** and **first-person-slide** have 60-second execution
bounds. The executable gate inventory (`commands` / `planned_gate_names`) includes
the new supplemental gate; `test_playable_gates.py` checks unique registration,
script selection, import ordering, prerequisites and bounds. A verifier-report
test proves that a missing weapon fails rather than being counted as a pass.

This is a supplemental runnable regression gate, not an added canonical release
obligation. `port/finish/matrix.json`, `port/finish/final_matrix.json` and
`port/finish/acceptance/n_matrix.json` remain unchanged. The canonical **142** and
historic **96** obligations and their old evidence are untouched. Registration
is not execution or acceptance.

## Stronger source regressions

- Teleport coverage now primes `sliding=true`, `slideTap=true` and a live
  `slideTimer`, confirms an ordinary ground tick keeps that commitment, then
  actually teleports and asserts the event, destination, cleared slide and
  cleared tap latch. Ordinary grounded intent expiry cannot satisfy this test.
- Held-crouch coverage checks each of the first three post-press ticks:
  0.15 → 0.1333 → 0.1167 → 0.10 seconds. This detects timer refresh immediately,
  rather than relying solely on an eventual zero after 30 ticks.
- `IMPLEMENTATION.md` now documents frame quantization and the stance budgets:
  **17.6 m/s walking / 24.2 m/s grounded sprint** for base speed 8, not a universal
  17.6 m/s ceiling. A real flat-floor height sweep independently confirmed latest
  accepted landing offsets of 133 ms at 60 Hz and 100 ms at 30 Hz relative to the
  end of the initial press-processing tick. The configured timer remains 150 ms.

## Executed source checks

```sh
PYTHONDONTWRITEBYTECODE=1 TMPDIR=/tmp/opencode python3 tools/godot-dev/test_playable_gates.py
PYTHONDONTWRITEBYTECODE=1 TMPDIR=/tmp/opencode python3 tools/godot-dev/test_verifier_report.py
node --test --test-reporter=spec game/movement-refinement.test.mjs
node port/native-campaign/generate-core.mjs --check
git diff --check
```

Results: **2 gate-inventory tests, 6 verifier-report tests, 10 movement tests
passed**. Generator freshness and whitespace checks passed. Python report tests
use temporary fixture projects and a fake version-only executable; no actual
engine, import or server ran. Only four sparse-omitted source files required by
the existing registration test were restored; no asset or cache checkout.

## Proposed native sequence — pending parent grant

Run from the merged, prepared candidate root, with the pinned `GODOT_BIN` and its
scheduled import prerequisites already satisfied. Use a fresh evidence directory
under `/tmp/opencode`; do not run the complete verifier for this bounded probe.

1. `campaign-input-flow` — now exercises campaign, arena and Horde clients.
2. `first-person-slide` — requires imported weapon-0 GLB; run only after step 1
   passes. This is a headless cue contract, not rendered comfort acceptance.

Exact engine commands for the gate runner, each with `timeout=60`:

```sh
"$GODOT_BIN" --headless --path godot --script res://tests/campaign/input_flow.gd
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/slide.gd
```

Use `tools/godot-dev/gate_runner.py::run_gate` to retain logs and fail on any
Godot `SCRIPT ERROR` / `ERROR` even if the process exits zero. Expected fixture
summaries are `CAMPAIGN_INPUT_FLOW ... failures=0` and
`FIRST_PERSON_SLIDE ... failures=0`; record results against the exact merged
candidate, not the historical source-only commits. Save logs/results in a new
`/tmp/opencode/movement-native-<candidate>/` directory. Native parsing, execution,
rendered review and human fun evaluation are still pending.
