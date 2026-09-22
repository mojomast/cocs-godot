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
