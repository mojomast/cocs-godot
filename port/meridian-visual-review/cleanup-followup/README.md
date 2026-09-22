# Owned graphical command cleanup follow-up

Addresses the lead's timeout blocker in the runner from `adb1a3b`.
Historical causal images, inventory bytes, logs and run records are unchanged
by this cleanup commit. No new full causal render is claimed.

`port/tools/meridian_visual_review/owned_process.py` now launches each command
with `start_new_session=True`. On timeout, exception, or normal wrapper exit,
it scans only that newly created PGID/SID, sends TERM when members remain,
allows a bounded grace period, then sends KILL if needed. Defaults are 1 second
TERM grace and 3 seconds KILL grace. Linux child-subreaper status is temporarily
enabled so orphaned Xvfb/Godot descendants can be reaped with `waitpid(-pgid)`;
the previous status is restored. The wrapper itself is reaped through Popen.
No global `waitpid(-1)`, inherited group signaling, or process-name cleanup is
used. `/proc` verification includes zombies: completion requires the owned
group to be absent. Commands run serially and must not deliberately escape
their owned session via `setsid()`.

Output uses private regular temporary files rather than inherited stdout
pipes. New run records preserve output on timeout, report PGID, observed and
remaining PIDs, TERM/KILL dispatch, timeout status and cleanup completion,
then fail the causal run on timeout or incomplete cleanup.

HOME, TMPDIR (also TMP/TEMP), XDG data/config/cache/runtime are private mode-0700
directories. DISPLAY, XAUTHORITY, Wayland socket/display and desktop session
bus variables are removed before `xvfb-run` creates its own display and auth.

## Actual execution

```sh
python3 port/tools/meridian_visual_review/test_owned_process.py \
  --evidence port/meridian-visual-review/cleanup-followup/test-run-1.json
```

**Exit 0, four tests passed in 2.318 seconds.**

- Real `xvfb-run` timeout with three nested Python processes that ignore TERM:
  timeout at 1.5 seconds, TERM then KILL, completion in 1.771 seconds; all five
  observed group members (wrapper, Xvfb, three fixture processes) absent from
  `/proc`, including zombies. A separately launched sentinel session survived.
- A normally exiting wrapper leaving a live orphan: orphan terminated/reaped,
  group absent, wrapper exit 0 retained.
- Representative private **graphical** pinned Godot invocation under Xvfb:
  `--audio-driver Dummy --path <private-project> --script res://bounded.gd`,
  20-second deadline, exit 0 in 0.428 seconds, `BOUNDED_NATIVE_OK`, Mesa llvmpipe,
  and group absent. Actual argv/output is in `test-run-1.json`.
- Environment test injects shared desktop variables and checks their removal
  and private directory permissions.

The original `../SHA256SUMS` describes the historical `adb1a3b` files, including
the old runner bytes; it is intentionally not rewritten to describe new code.
This follow-up has its own SHA256SUMS for the new helper/test, changed runner
and new evidence. Use a fresh evidence filename when repeating the tests.
