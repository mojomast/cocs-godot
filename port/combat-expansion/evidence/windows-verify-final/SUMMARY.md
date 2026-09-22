# Hosted Windows verification — PASSED (run 35756373862)

The released `cocs-native-windows.zip` from tag `combat-expansion-2026-09-22` was
downloaded from the release, checksum-verified, extracted into a path with spaces, and
exercised on `windows-latest` with the repo checked out at the pushed `main`.

- **status: passed**, platform `win32`, **15/15 cases**, 133 packaged files re-hashed
  against the manifest, manifest SHA256 `94e490a5…` matching the build record.
- Port commit `d55da6b570e7adc4511e62a244e72ea1152d9825` — the exact packaged revision.
- Maps and routes (each passed with its owned listener closed and no stray process):
  `play/meridian-exchange`, `play/verdant-reliquary`, `play/ember-crucible`,
  `native-dm/{prism-foundry, aurora-basin, cinder-array, lacuna-court, vermilion-fold,
  nacre-engine}`, `native-dm-identity-resources`, `showcase`, `aurora-basin`,
  `cinder-array`, `particle-lab`, `shader-lab`.
- The PCK probes (`graphics-resources`, `identity-resources`) confirm the packaged
  runtime resolves the Moth resources and the identity map data and builder.

`graphical: false` — this is a **headless** verification of packaging, resources,
startup, gameplay authority and cleanup. It is not GUI, audio or human acceptance.

Earlier runs of this workflow against the same tag failed for two harness reasons that
were fixed and are worth retaining:

1. the run checked out `main` at the pre-push commit `64da4bc5`, whose verifier still
   asserted the retired `candidate` operator staging;
2. 13 evidence logs were committed with a colon in the filename, which Windows cannot
   check out. All were renamed, and the tree was audited for reserved device names,
   trailing dots/spaces and case-only collisions (all zero).
