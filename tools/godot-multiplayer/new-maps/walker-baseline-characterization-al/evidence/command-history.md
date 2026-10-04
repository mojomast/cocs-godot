# AL command history

This is a transcription of tool commands/results, not a replacement for the raw
engine/supervisor logs. All commands used the fresh AL worktree after creation.

1. Created isolated worktree and branch from parent `b5deca56`:
   `git worktree add -b astra/walker-baseline-characterization-al /home/mojo/.tmp-on-disk/cocs-walker-baseline-characterization-al b5deca56`
2. Read-only preflight snapshot (exit0):
   `python3 -B tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/audit_al.py before`
3. Fresh approved preparation (exit0; returned the exact stage path):
   `python3 -B tools/godot-multiplayer/new-maps/walker-baseline-characterization-run/prepare.py baseline-characterization-al-01 --ak-root /home/mojo/.tmp-on-disk/cocs-walker-parity-admission-ak`
4. One-off Python sealing used approved `validate_stage`, verified absolute
   nonsymlink engine path/hash, and created `grant.json` with exclusive creation.
   It called `policy.validate` on the exact eight-key dictionary before writing.
   `expiresUnix` was sealing time+600 seconds, **1791104045.8649895**. The exact
   dictionary is the archived grant; source/grant/engine hashes, size, issuance
   UTC, authority and limits are in `authorization.json`. No grant tool or reusable
   authorization service was created. This sealing step invoked no binary.
5. Exactly one nonwaiting supervisor command (tool shell
   `sh_10615d2ec001aR8WpfPOxYBBeV`, exit0):

```sh
python3 -B tools/godot-multiplayer/new-maps/walker-baseline-characterization-run/supervisor.py --fixture /home/mojo/.tmp-on-disk/cocs-walker-baseline-characterization-al/godot/tests/walker_baseline_characterization/baseline-characterization-al-01 --ak-root /home/mojo/.tmp-on-disk/cocs-walker-parity-admission-ak --engine /tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64 --group radius-rise --mode baseline-only --grant-id MOTH-BLENDER-20261004-AL --grant-sha256 f5fca7640bcb438c1a3b9d1c1895c9c30c0d485e1a41330a9c00278f63f4cfcd > tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/evidence/supervisor-command.log 2>&1
```

The wrapper's raw redirected log is empty; the separate raw engine log and native
argv are archived in the stage. Completion was received by tool notification;
there was no owner polling/second launch.

6. Owner release followed by post-run snapshot and read-only analysis (each exit0):
   `python3 -B tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/audit_al.py release`
   `python3 -B tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/audit_al.py after`
   `python3 -B tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/inspect_al.py`
   `python3 -B tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/audit_al.py analyze`
   `python3 -B tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/independent_proofs.py`
7. Post-release source-only tests (each exit0):
   `python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/walker-baseline-characterization-run -p 'test_*.py' > tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/evidence/current-source-tests.log 2>&1`
   `python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/walker-baseline-characterization -p 'test_*.py' > tools/godot-multiplayer/new-maps/walker-baseline-characterization-al/evidence/approved-design-tests.log 2>&1`

The read-only owner also inspected raw contact/state arrays, verified timestamps,
binary/source/grant/dependency hashes, distinct body/shape identities, and recorded
those derivations in `execution-record.json` and the bound analysis/proof files.
No native engine was invoked by any of these inspection/test commands.
