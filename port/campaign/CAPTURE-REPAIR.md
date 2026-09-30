# Capture repair handoff (base 5c14ab41)

The campaign world has one sky/sun. The first-person rig legitimately owns another
environment and two lights in its separate World3D. Capture lighting census now
uses effective World3D identity, records exclusions, rejects unresolved ownership,
and retains effective environment, map ownership, stable identity and daylight
checks. `tests/campaign/capture_lighting.gd` passed: separate worlds are excluded;
duplicate lights in a shared SubViewport and duplicate root environments count.

The pointer race was in fixture ordering: a click before client polling could be
cancelled by a queued 250 ms TTL reset. A late-process fixture node now clicks
through the normal handler after polling, refreshes policy-driven presenters, and
waits for that frame's render. Production eligibility, focus, epochs and TTL are
unchanged. Pre-draw proved too late for canvas submission and was rejected after
visual review. Final capture checks additionally compare opaque first-person
viewport pixels against the actual screenshot, scaling for UI150 and excluding
comms/vitals/footer occlusion. More than 80% of unoccluded samples must match.
Input-reset wire events and client boundaries are retained for diagnosis.

## Evidence

Base directory: `/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/capture-repair/`

- `run-dDgkhi`: final **8/8 passing**, all four maps wide/compact, 82 PNGs.
- `run-GhCH7B`: focused Rootfall wide/compact passing.
- `run-mwOhxQ`: late-process proof; Rootfall wide gameplay visually reviewed,
  showing real weapon, daylight, shadowed terrain and bubble-free robot silhouettes.
- `run-soUQC3/rootfall-verge-compact/long-subtitle.png`: visually reviewed compact
  weapon/comms overlap; this run correctly failed the then-unscaled/occlusion
  pixel oracle, which was subsequently corrected.
- `run-EDYJdz`: state assertions passed but visual review found the weapon absent;
  **not accepted**. Crown wide sky/terrain and bubble-free robots were reviewed.
- `run-p2b5Nj`: earlier pre-draw focused state-only pass; also not accepted.
- `run-0GAL2P`: interrupted by outer 240-second command timeout; retained incomplete.
- `run-OvgLuS`, `run-soUQC3`, `run-IcoV6d`: retained pixel-oracle failures during
  UI scaling/occlusion/sample-density correction, not accepted final evidence.

Final run used pinned Godot 4.5.2, LP_NUM_THREADS=1 and Xvfb/llvmpipe:

```bash
LP_NUM_THREADS=1 GODOT_BIN="$GODOT_BIN" xvfb-run -a -s '-screen 0 1280x800x24' \
  node port/campaign/live-capture.mjs \
  --output=/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/capture-repair
```

All logs and intermediate screenshots remain outside the repository. This is
scripted source visual acceptance, not exported-package or organic-play evidence.
Parent advanced to 2f9f81fe during this lane; newer feature integration must be
verified by parent. Heavy slot released at the final command boundary; no capture
or campaign Godot child remains. No further engine work launched after steering.
