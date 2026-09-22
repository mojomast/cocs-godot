# Observed GitHub-hosted native CI

Run: <https://github.com/mojomast/cocs-godot/actions/runs/35677168297>

Published revision: `a12d89f8c815297feb187b4bedbb27c247bfa328`.
The lead pushed the integrated objective/LATTICE/CI snapshot to public `godot`
remote `main`, watched the actual run to completion and downloaded its artifact.

**PASS**, Ubuntu 24.04 GitHub-hosted runner, 3-minute job:

- Full repository history, Node 22 and real `npm ci`.
- Official pinned Godot download and SHA256/version validation.
- Playwright Chromium and OS dependencies installed on the runner.
- Both ignored GLB probes and locked semantic content generated from source.
- Native import and all **50 implemented gates passed**.
- Whitespace check and bounded artifact collection/upload succeeded.

`35677168297/` retains GitHub run/job metadata, the downloaded verification
report, console gate results and artifact manifest. The original artifact is
retained by Actions for seven days; these selected files are committed history.
This is independently observed hosted success, superseding only the earlier
agent handoff's “hosted unobserved” limitation. Its local 46-gate baseline and
original missing-probes failure stay historically accurate and unchanged.

Hosted CI exercises headless authority/transport/presentation regressions; it
does not establish graphical, audio, hardware or full-mode acceptance.
