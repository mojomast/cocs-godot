# Horde delivery: lead intake and visual review

Commit `94690b6674e20f550990df68213376c554ec898c` is available locally, including
its handoff and evidence. The reported external worktree path is absent; no
worktree metadata was pruned or overwritten. Runtime integration is pending
independent adapter/gameplay review, session `ses_f38b0ffbbffe0wHBE1r8SUSnjM`.

The public Room server forbids Horde. Its delivered single-client loopback
adapter around unchanged Match requires a distinct reviewed common/package
launch path. It must not be routed to the ordinary public-room service.

The lead extracted byte-exact PNGs from the commit to
`/tmp/opencode/horde-delivery-visual-review/` and directly opened:

- `port/native-horde/evidence/5771ef43-a3d5-4bcb-b63b-7759fcb47824/gameplay-final.png` —960×640.
- Same archive `gameplay-alternate.png` —1280×800.

Both show Verdant/Horde, DEATHS1, WAVE1/1, ENEMIES3/3, LIVES2, HEALTH100 and the
weapon/control HUD. The final Horde strip is legible and does not overlap the
main status/vitals panels at either size. It is unbacked outlined text over the
world, so this limited view does not establish readability against every scene.
These are reviewed delivery screenshots, not a fresh gameplay run, human review,
or acceptance of all three maps' final layout. The independent reviewer owns
fresh gameplay, source/adapter semantics and new evidence. Full ten-wave,
boss/defeat, upgrades and release-package acceptance remain open.

## Independent review returned: HOLD

Review/evidence commit `59c2b33` independently reproduces the narrow gameplay
outcomes but finds six material issues: overwritten input edges/misleading ACK,
lost string-ID modifier events, oversized-input crash and missing traffic bounds,
interval clock drift, actual product Scoreboard/Horde overlap at960×640, and a
validator that can accept resource-error/harness-failed runs. Its product-scene
Meridian attempt remains FAIL despite reaching victory/restart.

The same isolated lane is authorized narrow Horde runtime/helper repairs and new
`port/reports/horde-repair/` evidence. Original runs/failures stay untouched. Public
Room's local-only restriction stays intact. Runtime/review commits are retained
outside primary until fixes are reviewed; original review helper preloads depend
on the unintegrated Horde scene. Common/package routing remains on HOLD.

Repairs have now arrived as `74d0e27`, `25eae77`, `48d1029`, `5052119`, with
evidence/report `272558e`. A fresh independent reviewer
`ses_f3874c776ffehVOLnjfMUkhZsl` is checking all six defects, differential source
input semantics, actual-product live outcomes and cleanup on the latest shared
runtime. This is separate from the repair author's29/70/15/31/3 checks and fresh
one-wave/death/startup claims. The final ADS sensitivity fix has fixture coverage
but was not exercised by the recorded repair gameplay runs. HOLD continues.

## Second independent review: event cursor still blocks integration

Review `3dbcceb91c2e1542c91e7e2e3fda55ff43a94cb2` passed the29 adapter tests and
nine old-fail/new-pass differentials,70 source/UI tests,15 Horde assertions,
31 input/3 look vectors and inherited controls. It nevertheless reproduced a
genuine missing case: `Match.serial` also allocates projectile/grenade/sentry IDs,
so deriving event positions from serial minus ring length replays old events.
An ordinary grenade input duplicated spawn; fresh Meridian recorded eight
duplicated event payloads. Native wire-ID deduplication cannot remove those.

The same review's Meridian run killed three NPCs and won a legal one-wave match,
but a self-kill reduced net frags/`singleplayer.kills` to2. The validator wrongly
required net kills==3. This remains a retained validation failure; source NPC
kills and net-frag totals need distinct predicates, not blanket relaxed counts.

The reviewer is authorized a per-round append-object event cursor with separate
adapter ordinals/preserved source IDs, explicit cursor-loss failure, mixed-serial
regressions, and a validator based on distinct actual local NPC-kill events.
New evidence belongs in `port/reports/horde-event-repair/`. Original119 evidence
files and94 repair-report files were independently verified unchanged. Public
Room's Horde rejection remains intact. No Horde runtime/package claim is made
until the remaining changes are independently reviewed.
