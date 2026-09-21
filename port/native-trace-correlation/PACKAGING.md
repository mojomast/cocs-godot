# Reviewed historical evidence packaging

The original `HANDOFF.md` and `result.json` are the subagent's report, not the
integrator's execution claims. Original evidence is retained byte-for-byte in
`evidence.tar.gz`; `evidence-index.json` records every file's size and SHA-256,
the original commit, and per-run reported outcomes. Original loose files also
remain on `subagent/native-trace-correlation` at `fbc8345f98c99b884abdb385403fd4f0c778fce7`.

The 37 evidence files total 6,273,983 bytes before compression and 223,383 bytes
after compression. All four summaries duplicate their per-case JSON exactly.
Compression retains even those duplicates so every historical byte can be
recovered. Review found no token/password/authorization fields or bearer/API-key
patterns; server observers retain allowlisted metadata rather than welcome
credentials. Local paths, ephemeral loopback ports and owned process IDs remain
as provenance. This evidence is development material, outside Godot's package.

Run interpretation is unchanged:

- `7d1a088a-1107-4b43-9e88-c620846dff9a`: initial harness failure (wrong boolean
  assumption for numeric `dead`), not runtime acceptance.
- `2e41a441-c6aa-49b2-86ac-a593192dde33`: intermediate success before final
  synchronous association hardening.
- `6e7af608-fa87-4e1e-b7b2-a749ae342808`: designated final subagent acceptance run.
- `a2b37402-8dab-4b13-9447-785192f4dd8a`: deliberate timeout; expected failure,
  useful for cleanup evidence only.

Extract into a new private directory to reproduce the historical replay:

```sh
review=$(mktemp -d /tmp/opencode/cocs-trace-replay-XXXXXX)
tar -xzf port/native-trace-correlation/evidence.tar.gz -C "$review"
node port/tools/native_trace_correlation/replay.mjs \
  "$review/evidence/6e7af608-fa87-4e1e-b7b2-a749ae342808/enabled.stdout.log" \
  "$review/evidence/6e7af608-fa87-4e1e-b7b2-a749ae342808/enabled.json"
```

No archive content is promoted to native trace completion or graphical evidence.
New independent runs are documented separately in `port/reports/`.
