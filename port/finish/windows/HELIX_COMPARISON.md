# Windows Helix comparison: retrieved result and next-package preflight

## Parent review and integration

Worker `c1aa94ef` integrated as **`08f3b1f9`**. Parent independently verified the
downloaded ZIP SHA-256 and all ten original/candidate geometry, node/edge count
and ordered-graph identities. Two channel tests, three targeted coverage tests,
JavaScript syntax and whitespace checks pass.

The navigation workflow previously existed only on the dedicated comparison
branch. Parent admitted its reviewed 13-world version as a new canonical file;
its push trigger remains limited to `preview/helix-nav-source`. This merge does
not launch a new navigation benchmark.

Current source-only Windows preflight **37125999742** was launched at exact
`c1aa94ef31e41d7f75a93b1cfd0a0a6bbd7901e2`. Its owner monitors completion; the
dispatch/running checkpoint is not a pass or current-package acceptance:
<https://github.com/mojomast/cocs-godot/actions/runs/37125999742>.

## Completed remote evidence, re-fetched from GitHub

Run **37095237382**: https://github.com/mojomast/cocs-godot/actions/runs/37095237382

GitHub API reports **completed / success**, created `2026-10-03T04:03:03Z`,
updated `2026-10-03T04:04:44Z`. Exact tested commit:
`a8987ba91ea19a77784a621d3d27f5f92389fb4e`, Windows x64, Node **22.22.0**.
This matches the immutable G3 manifest's `bundled_node.version`, not its Linux
build-host Node version. This is historical ten-world source evidence, not evidence
that today's thirteen-world package has run on Windows.

Artifact **11264186003** is available, not expired (expiry `2027-01-01T04:03:03Z`).
Fresh API download is **6,896 bytes**, SHA-256:
`057658ebf1a8d16388d74208b8e133c183d560e940c30257011fa82b4481daca`.
The downloaded ZIP hash exactly matches GitHub's artifact digest.

Retained retrieval paths:

- ZIP: `/tmp/opencode/helix-37095237382-refetched.zip`
- Run API response: `/tmp/opencode/helix-run-refetched.json`
- Artifact API response: `/tmp/opencode/helix-artifacts-refetched.json`
- Original extracted JSON/logs:
  `/tmp/opencode/windows-navigation-37095237382/windows-navigation-source-a8987ba91ea19a77784a621d3d27f5f92389fb4e/`

## Actual results, including costs

Five equivalence tests and derivative reproducibility passed on Windows. All ten
original/candidate geometry hashes and ordered graph hashes matched. Each graph
was built in a separate cold process; original/candidate ran serially with individual
60-second bounds. The graph hash includes ordered nodes and adjacency.

| World | Nodes | Directed edges | Original ms | Candidate ms |
|---|---:|---:|---:|---:|
| Helix | 2573 | 26618 | 10345.076 | 369.112 |
| Gravemill | 3698 | 21624 | 11412.286 | 320.248 |
| Parallax | 688 | 4076 | 2535.796 | 158.102 |
| Breakwater | 1068 | 6518 | 93.238 | 105.053 |
| Copper Bowl | 272 | 1996 | 21.992 | 37.071 |
| Rainmarket | 530 | 5124 | 45.954 | 64.520 |
| Sirocco | 209 | 854 | 32.560 | 31.648 |
| Switchyard | 510 | 4342 | 49.883 | 58.734 |
| Tern | 2580 | 23232 | 130.800 | 131.825 |
| Thermal Divide | 921 | 5118 | 80.369 | 91.315 |

Helix improved **28.03×** in this measurement; several cheap graphs became slightly
slower. Timing is reported, not used as a flaky pass threshold. Catalog validation
precedes the timer: this is cold navigation time, not complete native launch time.
There was no comparison failure branch in this run; the comparator fails on a
nonzero/timed-out child, geometry mismatch or ordered-graph mismatch.

Helix original and candidate geometry:
`f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2`.
Both ordered graph hashes:
`4192eb150c7ae96224b1ea37b394130de3a155174695ff7e6bb74b15ad25ad2e`.

Freshly downloaded JSON file SHA-256 values:

| File | SHA-256 |
|---|---|
| identity.json | `74026e7521662b843a56b5a6e70d83e2286d222d108f9a95278725a5ac44b9dc` |
| helix-conservatory.json | `7314eb8bc2bc682bd151a3fa1793c38ea5cdb694c0dc40fdbe65eea518562656` |
| gravemill-foundry.json | `ce9a75eabc54d1cac1f4e8546b78d5195ebbd1ab6ebfeeb22aff9ea209411f2c` |
| parallax-observatory.json | `69bc6833af4d5c91fc6f6592f56d0456e6b26b9caeea8d69fa39a7c0aa37a12f` |
| breakwater-exchange.json | `113987d4ea4f0ec0b524150f08f8260e5ec162848bfc0c11065469bd2b097cad` |
| copper-bowl.json | `816461d0117ba41528ebeb6b9c780ac00986cd06486ad94150f5c4edc1a6d82e` |
| rainmarket-exchange.json | `cdb335ccdd8d4ed39f9bb2620d5ce27bcfadd7c912805f0e40c25cade767af4f` |
| sirocco-circuit.json | `01dd9c12e9db0436050c7c6b93366a7801226723e87cf28886b4ec1386f3712e` |
| switchyard-ward.json | `aa1be17db6d5a2659951434e02e36bed4157ef9292f3abbde93d26f93c89af96` |
| tern-archipelago.json | `1dec68dfe160d6b77edf4d5678ddeeaff4014f1990c49608703590d245e4eef2` |
| thermal-divide.json | `df5d2f1a2c486b8fd22443deea00c61bcba5c28b5062328cafdc66865e15dde2` |

## Current source adoption and actual stale-preflight repair

Adopted parent `17807ab977cacb4d2a43d2621999b143fb597a2c` into the existing clean
packaging lane. Current scope is **13 worlds / 73 pairs / all seven production
units promoted**. No final candidate is frozen while O changes runtime.

Found and repaired two stale assumptions:

1. `windows_source_preflight.mjs` still expected ten worlds, four pending units and
   final rejection. It now binds the registry to committed Git bytes, requires exact
   13-world closure and 73 unique pairs, and validates strict final production with
   pending `[]`, nine fighter imports and recorded provenance.
2. The reusable cold-navigation workflow still required ten worlds. Its future
   invocation now requires thirteen. The old successful run remains ten-world proof;
   no redundant full-map benchmark is dispatched just to relabel it.

Next source workflow: `.github/workflows/windows-source-preflight.yml`, dedicated
push branch `preview/windows-source-preflight-next`, Node 22.22.0 / Windows latest,
30-minute source-only job budget. It runs path/command-length regressions, seven-unit
positive and missing/tampered/unpromoted negative tests, then exact recorded-Git
discovery, resource/import and strict production validation. JSON/stderr are uploaded.
No engine, server, import, export or graph benchmark is in that workflow.

Local source checks: channel tests **2/2 passed**; the three selected coverage tests
passed for registered single-case filtering, exact 73 pairs and missing-family
rejection. Server/native test cases were not selected or executed.

## L pins, M/N scope, and actionable Windows release sequence

L reconciliation is `623127c5`, with parent's 52 source checks retained in
`port/finish/polish/L_PACKAGE_RECONCILIATION.md`. Comparing L to adopted parent,
Godot changes are four test scripts and **`godot/ui/attract/demo.json`**. None
intersects any of the seven receipts' `sourceHashes` or `packageInputs`. M's installed
Home playlist is a runtime change outside those asset pins; a newly frozen package
must still hash its current bytes. This does not make M rehearsal or old L evidence
new frozen-candidate acceptance. O's upcoming runtime changes need a new inventory
intersection/reconciliation check after integration.

1. Complete the corrected Windows source-only preflight and retain its exact source
   commit and results. It is a pre-freeze check, not permission to export.
2. After O releases and parent integrates its fixes, check all seven receipt inputs,
   sidecars and current runtime inventory. Reconcile changed pinned dependencies
   explicitly; preserve old producer/native identities and historical failures.
3. Parent freezes an exact candidate, grants packaging work, and builds both
   platforms from that candidate using strict final production (no preview bypass).
   Record archive/manifest hashes and fresh-extraction validation. Published
   `cb6e4c9f` preview remains untouched, including its known Helix limitation.
4. Use `mojomast/cocs-godot`, `.github/workflows/windows-demo.yml`, exact candidate
   verifier checkout, and a new unpublished release tag with the new Windows ZIP.
   Run bundled-Node manifest validation, targeted Helix diagnostic, Fighting/final
   probe and full package runtime coverage. Expansion derives **73 registered pairs**
   plus its separate Blackwater/eight source-mode checks; this is not the final-142
   ledger. Do not replace final acceptance with a focused preview workflow.
5. Keep `port/finish/acceptance/N_PROGRESS.md` limits explicit: combined ordinary
   vehicle journey passed at its original anchor; campaign W warmup moved ~2.68 m
   but did not establish sustained responsive rendering. World pointer approach and
   two 87,380-byte GL texture leaks were unresolved in N and are owned by O now.
   Live-kick timing, physical controller devices, real audio, human film watch/listen,
   manual/GPU review, Horde victory, final frozen receipts and extracted Windows
   acceptance remain obligations. Neither M's installed Home counts nor this source
   graph result closes the 142-case ledger.

No local heavy grant acquired or requested; O retains exclusivity. No published
archive, asset, runtime overlay or preview metadata was modified by this work.
