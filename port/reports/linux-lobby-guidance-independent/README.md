# Nine-route Linux package: lobby, spectator and world/cart guidance

**Attempt02 PASS for exported startup, launcher ownership and cleanup.** This
does not imply complete exported multiplayer gameplay acceptance; the separate
first full two-client run failed its clean-log condition and is under triage.

## Artifact

`/tmp/opencode/lead-native-linux-package/builds/1790054125934591826/cocs-native-linux.tar.gz`

- Archive SHA256: `ee3839f59f56ee82eb4b8f810daa6dacb9ceb9fe34043850659b2e7e5b7dad44`
- Manifest SHA256: `8f602b1cc48ab07a05378365a5890d96efea6b8b3d90e9d1c8a916ee085f40cc`
- Build inputs SHA256: `c6063243cedb645445391a4e9704380658f35ea204a6e56abc21ca32a9c80df6`

The manifest records build-time source/native/tool inputs. The external verifier
was subsequently repaired; its exact new hashes are in attempt02's verification
report. Verifier code is not shipped, and the package bytes were not changed.

```sh
python3 -B tools/godot-package/build.py --state /tmp/opencode/lead-native-linux-package
python3 -B tools/godot-package/verify.py --build-result /tmp/opencode/lead-native-linux-package/builds/1790054125934591826/build-result.json --output NEW_DIRECTORY --world-commands-capture
node /tmp/opencode/cocs-package-play-uxest1hv/cocs-native-linux/run.mjs --experience=lobby
```

## Initial attempt: retained verifier failure

Ten cases passed before Xlib terminated the verifier with **BadWindow** during
Ion startup. A helper window disappeared between enumeration and property lookup.
The default Xlib handler exits the process instead of returning a Python error.
Root files retain all initial images/logs and `failure-cleanup.json`: all11
recorded native PIDs and9 owned-authority launcher PIDs/ports were subsequently
confirmed absent/closed. No unrelated process was signalled.

The new error callback ignores only BadWindow for metadata queries during window
discovery. Other X11 errors become Python exceptions so owned cleanup can run.
`test_x11.py` creates and destroys a real window, then queries the stale handle:
the original verifier exits with BadWindow; the repaired version survives that
discovery race and still rejects the same error outside discovery. Logs and
results are in `x11-regression/`.

## Attempt02: complete startup/ownership checks

Fresh unrelated extraction, Node-only play PATH, exact file inventory/hashes,
no checkout paths/symlinks, all9 maps and8 compiled release scenes pass. The ninth
route is the opt-in lobby using the existing session scene. No tests/probes ship.

Actual exported windows passed for setup, owned lobby, external lobby, combat,
LATTICE world/C-panel, Domination, KOTH, Puma, Arms Race, Ion and Aurora. Closing
and interrupting an external-lobby client leaves its independently owned authority
healthy; only the verifier later stops that server. Normal close, interrupt,
native crash, invalid arguments and missing binary checks also pass.

The lead opened attempt02 owned/external lobby PNGs and LATTICE world PNG: the
endpoint/form and released/public-node guidance are legible. Source bytes and
package bytes remain unchanged after all cases. Hardware audio, human usability,
adverse networking and asset-rights remain open.

## Separate exported multiplayer gameplay attempt

`../linux-lobby-play-independent/` uses the actual exported executable/PCK and
unchanged packaged authority, with an external engine-event observer instantiating
the product scene. All requested functional assertions reached completion:
create/join/start, movement/fire, active Leave/spectator rejoin, natural60s results,
host-only restart, fresh guest recapture and final Leave. **Overall FAIL** remains:
guest stderr logged nonexistent `focus_entered`/`tree_exited` disconnects. That
acceptance is neither silently relabelled nor inferred from ACKs. An independent
bounded triage owns attribution/repair; initial evidence stays unchanged.
