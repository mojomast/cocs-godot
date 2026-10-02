# Final completion acceptance

Follow-up to candidate `e38b3662`, merged into the existing acceptance worktree.
Adopt only at the parent checkpoint boundary after the active
`FINISH-COMBINED-NATIVE-20261002-A` invocation stops. This is source preparation;
no Godot, import, Blender, capture, encoding or Windows execution was performed.

## Contract and completion ledger

`final_matrix.json` extends the original `matrix.json` without removing or
downgrading its 96 critical jobs. It adds focused fighting, map/operator finish,
production and Windows closure. Existing `port/fighting/acceptance/plan.json`
entries are read directly, rather than copied into a competing fighting plan.
The resolved matrix currently has 135 jobs: 29 source, 83 engine, 4 audio,
13 manual and 6 external. These numbers describe scheduling, not quality.

Every report contains `completion_ledger`: ID, owner, cohort, execution status,
preparation, dependencies, missing inputs, next action and per-unit status.
`ready-to-run` describes preparation only. Skipped/unrun/deferred critical work
never becomes acceptance. Combo units are derived from the actual roster as
operator/route/facing, preserving each failed or successful executed trace.
The parent-reported 16/54 pass, 38 fail result is recorded as a historical
blocker, not imported as this candidate's evidence. Sol owns content repair.

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
| Fighting mechanics/invariants/27 routes both facings | Core + Sol content; repair reported contacts and execute existing harnesses | Native unrun here; 38 reported route failures unresolved |
| Nine exported rigs, unique motion/contact | Animation producer + independent fighting acceptance; real master/export/native slice before broader review | Nine production fighting GLBs missing here |
| Four stages, pause/input/AI/training | Fighting presentation; existing journey plus explicit missing training/device units | Native unrun; actual stages are Basalt, Canopy, Crown, Helix |
| Three Moth map finishes | Map owners + shared binder; existing proof and district inspection | Helix source adapter passed; native unrun; Parallax recipe/art and registration unresolved |
| Nine operator finishes | Content/runtime owners; reuse exact-anchor source receipts, execute lifetime and moving UV/team/LOD review | Source resources present; native/manual unrun |
| Vesper, Abyssal, robots, vehicles, Stormglass, scenery | Asset consolidator and six owners; follow owned `ASSET_PRODUCTION.md` | Missing producer/assets remain blocked; no recipe-only completion |
| Menu/trailer | Cinematic owner; existing production pipeline and full watch/listen | Producer absent here; capture/encode/review unrun |
| Final Windows archive | Packaging + Windows CI owner | Actual PCK/extracted clean Windows graphical/CI proof absent |
| Existing real audio, GPU, OS/accessibility and human gates | Existing owners | Remain critical in inherited matrix |

Targeted source verification: 19 runner tests and 10 receipt tests passed;
receipt fixtures are synthetic and never count as native or release evidence.
The Helix source adapter passed actual catalog/geometry/material coverage.
No full acceptance suite rerun or active-branch polling was used.
