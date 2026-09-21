# Historical evidence archive

`evidence.tar.gz` preserves every original evidence file byte-for-byte, including
the invalid initial run, intermediate success and final accepted run described
in `HANDOFF.md`. `evidence-index.json` records original-commit provenance,
per-member SHA-256 and reported outcomes. These are historical subagent reports.
Extract into a fresh private directory with `tar -xzf`; paths retain their
original `evidence/<run>/...` layout. Loose originals remain on
`subagent/guest-session-integration` at `389561510ac7c2223a22897c963f3440304ec928`.

Compression reduces duplicated summaries without deleting failed-run history.
The archive is development evidence, outside the Godot release package.
