# Adopted efficiency changes

Parent review of Flash reports `f4a160c0`, `aa3f9bff`, `284e6938` (2026-10-02).
These are decisions and assigned changes, not measured speedups or native proof.

## Adopt now

1. **Reuse one integration checkout for native work.** Reuse the existing
   `cocs-finish-integration-20261002` worktree after synchronizing the next reviewed
   candidate. Parent `feature/relay-campaign` remains the canonical integration
   branch. Do not create another sandbox or copy every source dependency into
   additional worktrees. Preserve old branches/evidence; consolidate completed
   implementation commits once, then issue bounded owner-specific fixes.
2. **Retain import cache in that checkout.** Import after a heavy grant, then keep
   the same `.godot/` for the same source/toolchain/import-settings identity. Cache
   validity still requires actual imported bytes and resource identities. Being
   gitignored does not itself force reimport; avoid needless directory deletion.
3. **Target verification during edits, complete canonical acceptance at the stable
   candidate.** No new third test inventory and no blanket repeat of every source
   suite after documentation edits. Do not skip required checks using an unbound
   or different-input receipt. Native failures still get targeted reruns and final
   candidate coverage.
4. **Expose engineering readiness separately.** Existing acceptance owner is
   adding `integration_ready` for complete passing source+engine contracts, plus
   cohort blockers. Existing `release_ready` keeps every critical audio, manual
   and external requirement. Unrun checks never become passes. This is an additive
   status change, not permission to claim human/GPU acceptance.
5. **Finish Foundry's already-granted pass, then combined native acceptance.**
   New map aesthetic iteration will not repeatedly displace that grant. Accept
   an adequate, distinct result or retain a clearly labelled deferred candidate;
   blocking collision/geometry/gameplay defects still require repair. All requested
   assets remain in scope, with their real acceptance status retained.
6. **Meta versus Mistral first for fighting native art.** Complete code/data/recipes
   for all nine, but prove one integrated heavy/light scene, attacks, guard, throw,
   projectile, real animation and effects before bulk Blender export/capture.
   Then expand to all nine. Hundreds of synthetic FX screenshots are available
   diagnostics, not the first native task.
7. **Exploit the verified common rig.** Parent independently parsed all nine source
   GLBs: their 34 named non-mesh nodes have identical transform dictionaries.
   Avoid per-body rest normalization/retarget passes. Share compatible rig/library
   data and author the 25 victim timelines once, resolving the 225 required uses
   through explicit aliases if native import/playback supports this cleanly.
   Per-operator stance, locomotion and attack motion remain distinctly authored.
8. **Pin ambiguous simulation rules now.** Down is axis_y=-1, up +1. Core derives
   press edges from held-state history, with caller `pressed` only a hint. Input
   continues recording during hitstop; move/stun/physics progression freezes.
   Use bounded integer arithmetic with truncate-toward-zero division and an
   explicit typed JSON load codec. Core owner has corresponding negative/replay
   tests assigned. UI owner must latch very short taps for a tick and clear those
   latches at modal/focus/device boundaries.
9. **One validated content contract.** Content owner is covering every actual
   optional mechanic field, rejecting unknown/malformed fields, and moving initial
   balance targets to machine-readable data. Runtime roster remains authoritative;
   prose tables and DESIGN text no longer determine whether frame data is valid.
   Historical provenance remains preserved, while editable prose hashes leave the
   enforced generated-content freeze.
10. **Resolve concrete integration gaps early.** UI owner is wiring persistent
    projectiles, socket accents and paused audio to the completed FX API. Core
    owner must emit true contact coordinates for projectile interactions. This
    prevents expensive visual debugging of event/schema mismatches later.

## Corrections and limits to the research

- Low `free` RAM is not equivalent to low usable memory. Both audit and parent
  readings show about **47 GiB available**, despite 4–5 GiB free and nearly full
  swap. Full swap alone does not establish active thrashing or overcommit. Keep
  serial heavy work for predictable capture/resource ownership; reconsider only
  with measured concurrent workload behavior, not a mistaken free-memory reading.
- Parent confirmed ~99 GB free disk and ~4 GB free `/tmp` at review time. Prefer
  existing on-disk evidence roots for large captures. Do not compress/delete prior
  evidence or clean unfamiliar worktrees automatically. Such work consumes the
  same scarce resources and risks the user's preserved artifacts.
- The acceptance ledger is **incomplete**, not incapable of ever passing. Pending
  hardware/human attestations are truthful; engineering status is simply useful
  separately. A real-audio or manual failure remains a release blocker.
- Identical joint rest transforms do not make all visible contacts body-independent:
  operator meshes, new sockets and silhouettes can differ. Keep all-nine mesh/
  contact checks and visible body-extreme inspection. A shared animation track
  cannot certify that a hand actually grasps another character's visible torso.
- Do not replace dependency-byte checks with lockfile-only hashes or unverified
  cache manifests. Optimization must retain invalidation on actual changed bytes.
- Avoid imposing an arbitrary revision-count cap as an art-quality standard.
  Bounded scope and explicit acceptance/defer decisions are useful; known severe
  defects cannot be accepted just because the counter reached two.

## Adoption owners and next evidence

| Owner | Assigned change | Evidence still required |
|---|---|---|
| Parent | One reusable integration checkout, stable-candidate testing, queue order | Actual granted native run and cache/resource record |
| Finish acceptance Astra | Additive integration/release status and cohort blockers | Focused runner tests; actual native results remain pending |
| Fighting core Astra | Input/math/hitstop/JSON/contact-event contract | Native deterministic replay, collision and input cases |
| Fighting content Sol | Complete schema and machine-readable balance intent | Source positive/negative tests; native combos later |
| Fighting animation Astra | Shared rig/timelines and heavy/light slice before bulk | Real Blender export/reopen and native side-on contact review |
| Fighting UI Sol | Precise FX lifecycle and very-short-tap handling | Input/pause/device/native presentation journey |
| Fighting verification Astra | Alias-aware animation coverage and prioritized slice | Actual core/rig/stage/FX integration, then all-nine gates |
