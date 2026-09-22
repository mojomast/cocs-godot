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

## Sports integration and audio fixture follow-up

Run <https://github.com/mojomast/cocs-godot/actions/runs/35677813370> at `da1f571`
failed the inherited fixed-delay audio fixture. Its original log/report and
diagnosis are retained in `../audio-ci-followup/`; it remains FAILED.

Run <https://github.com/mojomast/cocs-godot/actions/runs/35678348846> at
`7df027f5aaeea619d2f7bd9a7ed714b1f4137122` **PASS**, all **53 gates**, in 3m21s.
This includes sports progression and the bounded actual-playback/cooldown
fixture. `35678348846/` retains the downloaded report, artifact manifest and
audio/combined logs. The lead watched completion and checked the report count.

## Objective progression and GLB repair

Run <https://github.com/mojomast/cocs-godot/actions/runs/35679051417> at
`bfcc9eda96dfa1b1e6b0791db31be9cc83e40676` **PASS**, all **57 gates**, in 2m53s.
The fresh runner generated the repaired Meridian GLB and passed inward-sky
checks, side-geometry tests and objective progression/corruption gates.
Downloaded report, console, artifact manifest and native side log are in
`35679051417/`. The lead watched actual completion and validated the gate count.
