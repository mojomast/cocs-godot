# Final completion acceptance

Follow-up to candidate `dff733c0`, merged into the existing acceptance worktree.
Adopt only at the parent checkpoint boundary. Exclusive grant C remains with
Parallax `ses_f055a6b41ffe42yCL8AxbOL676`. This is source preparation;
no Godot, import, Blender, capture, encoding or Windows execution was performed.

## Contract and completion ledger

`final_matrix.json` extends the original `matrix.json` without removing or
downgrading its 96 critical jobs. It adds focused fighting, map/operator finish,
production and Windows closure. Existing `port/fighting/acceptance/plan.json`
entries are read directly, rather than copied into a competing fighting plan.
The resolved matrix preserves the previous 135 jobs and now has 141: 34 source, 84 engine, 4 audio,
13 manual and 6 external. These numbers describe scheduling, not quality.

Every report contains `completion_ledger`: ID, owner, cohort, execution status,
preparation, dependencies, missing inputs, next action and per-unit status.
`ready-to-run` describes preparation only. Skipped/unrun/deferred critical work
never becomes acceptance. Combo units are derived from the actual roster as
operator/route/facing, preserving each failed or successful executed trace.
The earlier 16/54 result was superseded by actual native B **54/54** at anchor
`1b690f01`. Parent also reports 137,046 native animation checks with nine actual
fighters now committed. These are historical executed B results, not passes for
the changed responsive-camera/current final matrix. No B receipt is re-stamped.

`integration_ready` still requires every critical source and engine job to
pass, including production-dependent engine closures. All audio, manual and
external gates remain release-critical. `status`, `incomplete_critical`, exit
semantics and conservative `release_ready: false` remain intact. A finished
engineering ledger is not release certification.

## Source preparation and later execution

Use an evidence directory outside the checkout. Planning launches no producer:

```sh
python3 tools/godot-dev/finish_runner.py \
  --matrix port/finish/final_matrix.json --evidence /absolute/final-evidence
python3 tools/godot-dev/test_finish_runner.py
python3 tools/godot-dev/test_finish_receipts.py
```

Select individual source jobs with `--run --select ID`; do not run the entire
extension while another owner holds the heavy slot. Native execution later
requires the existing grants and, for delegated fighting producers, the actual
parent `--grant-reference`. Jobs remain serial with individual deadlines and
the existing default 1800-second invocation budget. Existing import/cache hashing,
same-input resume, isolated stores, retained failures and atomic report writes
remain in force. Matrix/runner adoption changes identity: start a fresh ledger
after adoption rather than resuming an older matrix's report.

## Exact-anchor receipt references

### Current registration follow-up

New source IDs are `fighting-camera-source` (including nine real-rig bind-space
checks), `fighting-import-settings-source`, `final-resource-contract-tests`,
`final-fighter-resource-closure`, and `final-seven-unit-production-closure`.
Both closure commands are strict. The package tools' optional `--audit` may exit
zero while listing pending assets; it is diagnostic preparation, never this gate's
pass. Converted package receipts remain `accepted:false`; current manifests and
valid export hashes establish resource closure, not native or human acceptance.
Existing engine/manual/audio/external gates remain required even if strict closure
passes. No package producer or active Parallax files are modified by this lane.

After adoption, create a **fresh** ledger on the final frozen checkout. Targeted
source selection (no engine grant) can use:

```sh
python3 tools/godot-dev/finish_runner.py --matrix port/finish/final_matrix.json \
  --evidence /absolute/new-final-evidence --run \
  --select fighting-camera-source --select fighting-import-settings-source \
  --select final-resource-contract-tests
```

Select the two strict closure IDs when production/promotion is ready; missing
assets must fail, rather than switching those commands to audit. Planning and
execution use the shared supervisor lock; do not compete with grant C. Use the
committed matrix for source inspection until the owner releases that slot.

Later native selection `fighting-camera-native` requires passed `native-import`,
`fighting-camera-source`, and `fighting-import-settings-source` on the same
ledger, plus the engine grant. Selection does not implicitly execute prerequisites.
It requires exit zero, the existing engine-error scan, and exactly one
`FIGHTING_CAMERA_GATE {"passed":true,"failures":[]}` JSON record in `output.log`.
Missing, duplicate, malformed, false or incomplete records fail. The headless
envelope fixture does not certify actual rendered rigs.

The existing four-stage receipt now explicitly includes responsive-camera
readability, smoothing/reset and pose-cache costs per
`port/fighting/presentation/CAMERA_FOLLOWUP.md`. Use bounded representative
neutral/jump/throw/projectile/corner/separation views across actual stages,
wide/compact HUD100/150 and reduced motion; inspect real contact silhouettes,
floor line, crop seams and charged/double jumps. Record one-time bind-cache
construction and per-frame pose sampling separately from renderer cadence/GPU
cost. Source predicted pixels are not rendered measurements. This extends the
existing review, without registering a Cartesian capture suite.

Foundry uses the already-extended `proof.gd`: Off/Low/Full, reapply, cleanup and
reload verify preserved luminaire emission. The receipt adapter checks failures
and ready lifecycle states, with no obsolete requirement to dress all eight
selectors; preserved luminaires are valid and must remain untouched.

### Production map journey evidence and promotion

The 13 private hosted pairs are deliberately **not** runnable post-promotion
final jobs. Their admission rejects public registration. Vesper, Abyssal and
Stormglass owner-closure receipts instead require `map_journeys`, keyed by the
matrix's exact modes (6/6/1). Each entry names an `artifact` in the retained
artifact table and a `stage` of `private-production` or `public-current`.
The outcome JSON must identify `id`, `mode`, `recipeSha`, `artSha`,
`geometryHash`, successful `journeyPassed`/`success`, `processFailed:false`,
and successful teardown with two clean peers and no server error. The recipe
and GLB hashes must match actual current files. Changed recipes/exports require
new evidence or explicit owner reconciliation, never a hash rewrite.

Private outcome `accepted:false` correctly means the producer did not promote
the map. The **separate exact-current-anchor owner envelope** supplies acceptance
after reviewing retained production-stage evidence. Raw conversion output from
`tools/asset-production/package-receipt.mjs` cannot replace that envelope, the
native execution report, or the final seven-unit strict packaging gate. Later
public journey producers can supply the same normalized outcome fields while
retaining their original reports as hashed artifacts. No historical finish-ledger
input identity is relabelled to the current one.

`--receipt /absolute/reference.json` reads existing evidence; it never executes
the producer. The reference is:

```json
{
  "gate": "operator-finish-source-provenance",
  "adapter": "finish-job",
  "report": {"path": "/absolute/producer/report.json", "sha256": "SHA256"}
}
```

`finish-job` requires the **identical full input identity**, identical resolved
job contract/resource class, latest original passing exit-zero attempt, clean
descendant cleanup, and execution-time SHA256s of retained output/artifacts.
This permits referencing already executed inventory jobs on the same frozen
anchor instead of regenerating all inventories. Legacy reports without recorded
artifact hashes, a different matrix/environment/cache, or historical receipts
re-stamped with a new identity are rejected. Receipt chains are rejected.

`owner-closure` is restricted to `receipt_only` jobs. Its producer JSON must
contain the exact `input_identity`, `gate`, `resource_class` matching the cohort,
`evidence_kind`, named `owner`, `status: passed`, `executed: true`, and a `units`
object with every matrix unit explicitly `passed`. It must retain nonempty
`artifacts` (named objects containing absolute `path` and `sha256`) and name an
`execution_report` artifact. That report must be passed, contain actual checks
or cases, and have no failures/unrun/missing cases. Owner reviews remain owner
attestations backed by evidence, not automatically inferred visual quality.

Production GLB closures additionally require `resources`, keyed by every unit,
with nonempty arrays of checkout-relative path/SHA256 records. Missing exports,
wrong hashes, recipes renamed as GLBs and resource path escapes fail closed.
GLB header validation is a resource classification guard; native quality and
semantic validation remain the producer/reviewer's responsibility. Accepted
producer JSON is archived by hash in the ledger's `receipts` directory. Failed
receipt imports are retained in `rejected_receipts` and return failure.

## Actual Windows release proof

Packaging owns build, closure discovery and CI. The adapter consumes their
results; it does not replace package validation. The final Windows receipt
requires artifact roles `windows_report`, `package_manifest`,
`manifest_validation`, `windows_graphical`, `windows_ci`, `pck`, `executable`
and `archive`. Roles name entries in `artifacts`.

The existing Windows verifier must pass on `win32`, with matching manifest hash
and package commit. Packaging's manifest validator must pass for that Windows
commit. PCK/executable hashes must match the manifest. `package_inputs` must
equal the complete manifest `inputs` map and match current actual bytes.
The CI artifact must record success, `platform: win32`, `clean_extraction: true`,
`used_checkout_runtime: false`, HTTPS `run_url`, matching `port_commit` and
`archive_sha256`. The graphical report must independently pass on actual Windows,
declare `graphical: true`, match the commit, and contain passing `cases` with
units `fighting-Home-and-nine-rigs`, `three-map-and-operator-finishes`,
`replay-runtime` and `main-menu`. The existing headless Windows report explicitly
does not supply this graphical proof. All requested final units remain required.

## Outstanding ownership and evidence

| Work | Owner / next action | Current acceptance state |
|---|---|---|
| Fighting mechanics/invariants/27 routes both facings | Core + acceptance; final frozen-candidate execution | B 54/54 at `1b690f01`; current final matrix pending |
| Nine exported rigs, unique motion/contact | Animation producer + independent fighting acceptance; final responsive-view review | Nine real GLBs/masters/import settings committed; B native evidence historical |
| Four stages, pause/input/AI/training | Fighting presentation; existing journey plus explicit missing training/device units | Native unrun; actual stages are Basalt, Canopy, Crown, Helix |
| Three Moth map finishes | Map owners + shared binder; existing proof and district inspection | Helix source adapter passed; native unrun; Parallax recipe/art and registration unresolved |
| Nine operator finishes | Content/runtime owners; reuse exact-anchor source receipts, execute lifetime and moving UV/team/LOD review | Source resources present; native/manual unrun |
| Vesper, Abyssal, robots, vehicles, Stormglass, scenery | Asset consolidator and six owners; follow owned `ASSET_PRODUCTION.md` | Missing producer/assets remain blocked; no recipe-only completion |
| Menu/trailer | Cinematic owner; existing production pipeline and full watch/listen | Producer absent here; capture/encode/review unrun |
| Final Windows archive | Packaging + Windows CI owner | Actual PCK/extracted clean Windows graphical/CI proof absent |
| Existing real audio, GPU, OS/accessibility and human gates | Existing owners | Remain critical in inherited matrix |

Targeted follow-up source verification: 19 runner tests, 15 receipt tests,
6 camera/real-rig tests and 14 packaging/conversion contract tests passed.
Actual fighter import-settings and final-resource closure passed. Strict seven-unit
production closure failed closed with all seven units pending; audit returned the
same seven pending units with exit zero, and is not acceptance. Receipt fixtures
are synthetic and never count as native or release evidence. Logs are retained in
`/home/mojo/.tmp-on-disk/cocs-finish-acceptance-evidence-20261002/registration-dff733c0-c37u7oap/`.
No full acceptance suite rerun or active-branch polling was used.
