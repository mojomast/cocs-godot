# Release `combat-expansion-2026-09-22-v2` — pipeline record

Produced end to end by `tools/release/release.mjs` against frozen commit
`c00b370ab3ed6a3ad16c4f2f773d660f5f79f898`, in three invocations (dry run, execute
through package, resume through publish).

| Step | Result |
|---|---|
| preflight | refused the first attempt because the frozen commit was not on `godot/main` yet (the tag would have targeted the wrong revision); passed after the source push |
| verification | **147/147 gates**, source `51289b79c627`, 404.9 s |
| package | 80,197,227-byte ZIP, sha256 `1122aeee1daceec1b9e506fafd04c6d8b0191eb43c6ced26101c7b2a12ba0662`, manifest `ab23e114…`, port commit checked against HEAD |
| publish | https://github.com/mojomast/cocs-godot/releases/tag/combat-expansion-2026-09-22-v2 (prerelease, ZIP + `.sha256`) |
| verify | hosted Windows run 35783718168 — **success**, 15/15 cases, 134 packaged files re-hashed, port commit confirmed |
| push | `godot/main` fast-forwarded to the frozen commit |

Anonymous re-download reproduced the checksum exactly (`1122aeee…`, 80,197,227 bytes).

Two refusals are worth keeping as the pipeline's value: the dry-run state directory could
not back an execute resume, and the tag-target check caught the unpublished commit before
any build time was spent.
