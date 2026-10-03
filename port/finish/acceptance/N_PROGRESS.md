# Release acceptance N — execution checkpoint

## Parent integration and follow-up

N `7d4731e2` merged as **`17807ab9`**. Parent inspected the fixture/source-test
corrections and independently passed the weather spatial oracle, five receipt
tests, both changed-script grammar checks and whitespace checks. Parent verified
all three empty release audits and no live members of the 48 recorded groups.

Next exclusive grant **`GAMEPLAY-REPAIR-20261003-O`** belongs to gameplay owner
`ses_f0294303bffed6Fb8UJLKe4ZDz`, targeting the failed world vehicle approach and
two Controls texture leaks. Windows preparation runs source/remote-only in parallel.
N results retain their original source anchors; neither open failure is accepted.

Grant: `RELEASE-ACCEPTANCE-20261003-N`. Owner: acceptance. No child agents.
Adopted parent `701d4caf736a0c7f45f79fdef7475b1603f79768` before execution.
Evidence root: `/home/mojo/.tmp-on-disk/cocs-release-acceptance-N-20261003`.

## Evidence and exact boundaries

Each runner directory retains its own report, exact input/cache identity,
commands, deadlines, logs, artifact hashes and owned process cleanup. Reports
from earlier candidates remain earlier receipts. Final matrix still has 142
obligations; `n_matrix.json` adds three supplemental jobs separately.
No final-142 acceptance or release-ready claim is made.

| Stage | Result |
| --- | --- |
| semantic-preflight | Source semantic generation passed, 0.882 s; PGID 3156965 empty |
| import-01 | Latest installed Home/resources imported successfully |
| types-01 | Five Home, vehicle and campaign typechecks passed |
| diagnostics-01/run-6ttc6pi8 | Version/import passed; campaign movement and controls teardown failed |
| vehicles-01/run-wu8vqkoy | Version/import/typecheck passed; both vehicle routes failed |
| vehicles-campaign-02/run-b7jt0g63 | Version/import/typecheck, campaign journey and combined ordinary vehicle passed; world route failed |
| world-03/run-yat2qtql | Version/import/typecheck passed; admitted Payload route connected but approach failed after pointer release |
| world-04/run-00mydn2i | Version/import/typecheck passed; same approach failure with fresh-click recovery; candidate `bed09428` |
| regressions-01 | Five native contracts passed: Home search/input, vehicle controls/views, campaign motion; candidate `bed09428` |
| source-01/run-qeipeadf | Eight selected jobs passed; world-spatial-oracle and final-resource-contract-tests failed on stale fixture assumptions |
| source-02/run-0ghl3mk6 | Both corrected source groups passed; candidate `b2f72af4` |

The successful combined receipt is anchored to `1cb35ff0`. It retains
infantry approach, third-person, first-person and demounted screenshots,
actual authority input packets, driver relationship assertions and Home teardown.
This is synthetic physical-key/mouse event routing through production input,
not physical device or human acceptance.

Campaign diagnostic traced nonzero W packet round 1/epoch 3/seq 12 arriving
after an 812 ms view-render gap; authority advanced the input epoch and released
capture. Round 2 reuses sequence numbers and must not be mistaken for application
of this round-1 input. Fixture `1cb35ff0` warms the changed view before existing
ordinary fresh-click recovery. The resulting journey passed, moving about 2.68 m.
Later stale release still appears in the trace: this does not prove sustained
responsive rendering or repair production performance.

Controls ran 90 assertions with zero assertion failures, then leaked two
87,380-byte GL textures. Weak ownership probe handles did not identify these
two handles. The native gate remains failed; no teardown waiver or speculative
runtime resource fix was applied.

Source corrections in `b2f72af4` enumerate all four reviewed weather shader
anchors (including opaque Moth), and force missing master/export reads in
negative receipt tests rather than assuming promoted production files do not
exist. CLI missing-receipt rejection still verifies the fixed receipt is unchanged.
All 15 resource tests passed after correction. Unselected obligations remain
queued. A subset runner can exit 1 with all selected jobs passed because the
full ledger remains incomplete; per-job results are authoritative.

## Commands

All native stages set `LP_NUM_THREADS=1`, use the shared nonwaiting lock and
bounded serial runner. Binary:
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.

```sh
python3 tools/motion-review/native_queue.py --scope contracts --only native-import --execute --grant RELEASE-ACCEPTANCE-20261003-N --candidate "$CANDIDATE" --output "$ROOT/import-01"
python3 tools/motion-review/native_queue.py --scope contracts --only typecheck-ui-home-search --only typecheck-ui-home-input --only typecheck-vehicle-controls --only typecheck-vehicle-views --only typecheck-campaign-motion --execute --grant RELEASE-ACCEPTANCE-20261003-N --candidate "$CANDIDATE" --output "$ROOT/types-01"
```

Registered matrix stages use:

```sh
env LP_NUM_THREADS=1 AUDIO_DRIVER=Dummy GODOT_BIN="$BINARY" python3 tools/godot-dev/finish_runner.py --matrix "$MATRIX" --run --grant engine --grant-reference RELEASE-ACCEPTANCE-20261003-N --budget-seconds "$BUDGET" --evidence "$ROOT/$STAGE" $SELECTIONS
```

| Stage | Matrix | Budget | Selections |
| --- | --- | ---: | --- |
| diagnostics-01 | final_matrix.json | 600 | native-version, native-import, world-connected-campaign, controls-combat; additionally BASELINE_CONTROLS_RESOURCE_PROBE=1 |
| vehicles-01 | acceptance/n_matrix.json | 700 | native-version, native-import, n-vehicle-typecheck, n-combined-ordinary-vehicle, n-world-ordinary-vehicle |
| vehicles-campaign-02 | acceptance/n_matrix.json | 850 | preceding vehicle selection plus world-connected-campaign |
| world-03, world-04 | acceptance/n_matrix.json | 500 | native-version, native-import, n-vehicle-typecheck, n-world-ordinary-vehicle |

Matrix paths above are relative to `port/finish`; each selection is a separate
`--select ID`. Actual expanded per-job argv are preserved in the reports.

## Remaining obligations

- World ordinary vehicle acceptance failed: actor remains at `(-78,-10)`,
  pointer released. Fresh-click recovery did not resolve the approach. Future
  diagnostic should retain focus, capture eligibility, mapper release ledger,
  GUI event consumption and wire movement together; do not infer a runtime fix.
- Controls texture teardown attribution/fix remains open.
- Live-kick normal-rate window remains failed historically; llvmpipe is observed.
  An identical slow-render loop has not been repeated.
- `/dev/uinput` exists but is not readable/writable by this owner. Controller
  hardware acceptance remains blocked. Readable render node alone proves no
  responsive GPU renderer.
- Real audio, human full-speed film watch/listen, manual/GPU review, Horde victory
  and extracted Windows acceptance remain outstanding.
- M movie/Home production is a rehearsal, not a frozen receipt. No cinematic
  recapture, encoding, package export or Blender work was run under N.
- Changes so far are fixtures/adapters only; no production runtime package-pin
  transaction is requested. Candidate drift still requires fresh final receipts.

## Source/regression commands and release

`regressions-01` used `native_queue.py --scope contracts --execute`, the N grant,
candidate `bed09428`, and five `--only` selections: `ui-home-search`,
`ui-home-input`, `vehicle-controls`, `vehicle-views`, `campaign-motion`.

Source runs used `finish_runner.py --matrix port/finish/final_matrix.json --run`
with `LP_NUM_THREADS=1`, no engine grant, unique evidence directories and:

- `source-01`, budget 600: `finish-runner-tests`, `canonical-registration`,
  `final-receipt-tests`, `fighting-camera-source`, `cinematic-v3-source`,
  `final-resource-contract-tests`, `final-fighter-resource-closure`,
  `final-seven-unit-production-closure`, `world-spatial-oracle`, `controls-source`.
- `source-02`, budget 300: `world-spatial-oracle`, `final-resource-contract-tests`.

**N released at 2026-10-03T13:14:42.580650Z.** `release-N.json` retains all
48 owned PGIDs and three consecutive empty audits at 13:14:41.850741,
13:14:42.216900 and 13:14:42.580650 UTC, under the shared nonwaiting lock.
Each attempt additionally retains descendant cleanup. Future heavy work needs
renewed parent coordination. This release is resource handoff, not game approval.
