# Independent world-panel co-op acceptance

This owned runner opens the native LATTICE world panel and waits for ordinary
source recruitment on Asterion and Monsoon. See [PLAN.md](PLAN.md) for the
source-first strategy and [HANDOFF.md](HANDOFF.md) for measured results.

## Reproduce

From an isolated worktree based on `8a58c97`:

```sh
git worktree add /tmp/opencode/lattice-world-coop-review 8a58c97
```

Apply this lane's commit to that worktree, then run these commands there:

```sh
ln -s /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node_modules
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
python3 port/native-lattice-world-coop/verify.py checks
python3 port/native-lattice-world-coop/verify.py live
```

No dependency installation is used. The primary node_modules symlink is used
read-only. `checks` exports isolated generated content, imports with the pinned
engine, parses the observer and runs the existing world-command fixture. The
fixture has synthetic lease rotation; it is **separate from live acceptance**.
Godot import may generate untracked sports `.uid` files; they are not lane files.

`live` runs Asterion at 960×640 and Monsoon at 1280×800 sequentially. Each case
owns its dynamic IPv4 loopback authority, Xvfb display (`-nolisten tcp -nolisten
unix`), native child and isolated XDG directories. Native termination begins by
203 s; the outer wrapper bounds each attempt to 210 s. It retains all failures
and never retries automatically. A purposeful retry can target one map:

```sh
python3 port/native-lattice-world-coop/verify.py live --map=asterion-relay
```

Respect the lane's maximum two purposeful attempts per map. The runner refuses
to overwrite existing output directories. Direct invocation (also owns Xvfb):

```sh
node port/native-lattice-world-coop/run.mjs --map=asterion-relay --size=960x640 --output=/tmp/opencode/world-coop-review-case
```

Offline re-audit, without launching any server or engine:

```sh
node port/native-lattice-world-coop/audit.mjs PATH_TO_CASE_DIRECTORY
node port/native-lattice-world-coop/audit_negative.mjs PATH_TO_PASSING_CASE_DIRECTORY
```

## Witness and interpretation

`wire.jsonl` keeps allow-listed recipient snapshots, input and command requests,
and relevant events. It includes own actor pose/shots, own team FLUX/cumulative
spent, own REQ cumulative spent, source recruitment count, intermission/lease
permission, and own cards. It does not access or change authoritative match
objects, add a second gameplay socket, or accelerate simulation.

The input adapter is exercised through Godot engine key/mouse events, including
C, held W/fire, explicit checkbox clicks and Tab/Enter purchase. Purchase success
requires a matching round/peer/actor/card `done` with `ok:true`, cumulative FLUX
spent +50 and spawned +1 with unchanged REQ spent. ACK remains a movement-input
high-water receipt. No objective captures, full rounds, human/OS input, or strict
action-keyed spawned-actor attribution under concurrent purchases are claimed.

The actual lease check first authorizes and **waits for a natural 600-tick epoch
change**. Old consent must clear, and a purchase click must send nothing. A new
authorization is required to queue the only economy action. Closing/releasing/
fresh-click movement and stale duplicate suppression are checked afterwards.

Each case saves exact commands and SHA-256 hashes in `manifest.json`, source
receipt/counter results in `result.json`, native observations/screenshots and
cleanup in `cleanup.json`. The wrapper additionally confirms all three recorded
native/server/Xvfb PIDs are gone in `process-cleanup.json`.

The negative audit mutates copies of accepted evidence in memory. It requires
failure for missing done receipts (even with ACKs/counters intact), wrong actor,
duplicate purchase, REQ debit, missing spawn, absent lease rotation, overlay fire,
and a second gameplay socket. It leaves the original witness intact.
