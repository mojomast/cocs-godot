# Windows cold-navigation source comparison — passed

Run: https://github.com/mojomast/cocs-godot/actions/runs/37095237382

Exact tested source: `a8987ba91ea19a77784a621d3d27f5f92389fb4e` on
`preview/helix-nav-source`. Parent canonical `b62f7562` (including scenery promotion
and the navigation candidate) was integrated as merge `787e610e`. The only merge
conflict was the channel test's pending list; parent scenery promotion's three
remaining units were retained. Workflow commit: `a8987ba9`.

Execution identity recorded by CI: **win32 / x64 / Node v22.22.0**, matching G3's
manifest `bundled_node.version` and `play_node`. Checkout SHA was asserted against GITHUB_SHA.
The five bounded equivalence tests and generated-derivative reproducibility check
passed. Then Helix and the other nine registered maps ran serially. Each original
and candidate graph used a separate process, with a 60-second per-process bound.

## Actual timings and graph identities

**All ten original/candidate geometry hashes and ordered graph SHA-256 values
match.** Nodes and ordered adjacency are serialized together for graph hashing.
Times measure `navigation(arena)` after catalog validation, not whole process,
whole match construction or native startup. Timings are observations from one
Windows runner execution, with no threshold-based timing acceptance.

| Map | Nodes | Directed edges | Original ms | Candidate ms |
|---|---:|---:|---:|---:|
| Helix Conservatory | 2,573 | 26,618 | 10,345.076 | 369.112 |
| Parallax Observatory | 688 | 4,076 | 2,535.796 | 158.102 |
| Gravemill Foundry | 3,698 | 21,624 | 11,412.286 | 320.248 |
| Switchyard Ward | 510 | 4,342 | 49.883 | 58.734 |
| Rainmarket Exchange | 530 | 5,124 | 45.954 | 64.520 |
| Breakwater Exchange | 1,068 | 6,518 | 93.238 | 105.053 |
| Thermal Divide | 921 | 5,118 | 80.369 | 91.315 |
| Sirocco Circuit | 209 | 854 | 32.560 | 31.648 |
| Copper Bowl | 272 | 1,996 | 21.992 | 37.071 |
| Tern Archipelago | 2,580 | 23,232 | 130.800 | 131.825 |

Helix measured approximately **28.03× faster**, Parallax **16.04×**, Gravemill
**35.64×**. Some inexpensive maps were slightly slower; their results are retained.
The unprofiled source-only Helix original time is not directly interchangeable with
the earlier 22.6-second profiled full-authority stall on a different Windows run.

Helix geometry hash (both):
`f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2`

Helix ordered graph SHA-256 (both):
`4192eb150c7ae96224b1ea37b394130de3a155174695ff7e6bb74b15ad25ad2e`

## Retained evidence

GitHub artifact name:
`windows-navigation-source-a8987ba91ea19a77784a621d3d27f5f92389fb4e`

Downloaded artifact directory:
`/tmp/opencode/windows-navigation-37095237382/windows-navigation-source-a8987ba91ea19a77784a621d3d27f5f92389fb4e/`

It includes `identity.json`, `unit-tests.log`, `derivative-check.log`, and each map's
JSON timing/count/hash pair and stderr log. Full CI log:
`/tmp/opencode/windows-navigation-37095237382.log`.

The source-only job was authorized explicitly. The incidental general CI run
`37095237315` triggered by the branch push was cancelled. Monitoring used a
background `gh run watch`; it completed successfully before artifact retrieval.

## Remaining native gate / scope

This is real Windows **source graph proof**, not native package acceptance. Next:
parent authorizes a new frozen candidate package after local grant H, then runs the
single-case native Helix command documented in `HELIX_NAVIGATION_SOURCE_FIX.md`,
retaining the unchanged product and fixture deadlines. A diagnostic runtime overlay
would require separate approval and has not been performed.

No local heavy process, engine, server, asset build, archive operation, publication,
or preview metadata change occurred. The published G3 archive remains immutable.
Parent owns the newly integrated scenery receipt review. Final seven-unit strict
production gating and full 142-case verification obligations remain in force.
