# Bounded native death/respawn: live acceptance and retained defect

**One final-code live run passed all bounded criteria. An earlier genuine run
reproduced an intermittent native lifecycle defect. Overall acceptance remains
qualified by that unresolved failure.** No runtime fix is included.

## Scope and provenance

Base `fb4cf04e2460121a23329913db78f0b5924d732c`, primary branch
`port/godot-destinations`. Owned branch `subagent/native-death-respawn`, worktree
`/tmp/opencode/cocs-native-death-respawn`. Changes are confined to this directory
and `port/tools/native_death_respawn/`.

Read primary `port/README.md`, contracts, gameplay acceptance HANDOFF/SPEC and
DEATH_RESPAWN_EVIDENCE, and the correlation HANDOFF/harness. Setup, cleanup,
synchronous observer association, and fresh-round queue inference are adapted
with attribution from `native_trace_correlation` at `fbc8345` and its vendored
guest helpers at `389561510ac7c2223a22897c963f3440304ec928`. Execution has no
dependency on those mutable worktrees. Runtime/source hashes and exact harness
source hashes are in each run's `summary.json`.

## Execute / reproduce

From the checkout to be evaluated, with existing dependencies and Godot:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node port/tools/native_death_respawn/run.mjs
node port/tools/native_death_respawn/analyze.mjs port/native-death-respawn/evidence/f6498d16-7394-4c58-ae8e-f7445d65f61e
node --test port/tools/native_death_respawn/test.mjs
```

The first command was executed three times; history below preserves all results.
Each invocation creates a UUID evidence directory and private temporary project;
it evaluates that checkout's runtime, so the lead can rerun against integration.
Live CLI exits 0 for all bounded criteria, 2 for evaluated failed criteria, 1 for
setup/structural evidence failure. Replay uses the same exit convention. A failed
run is never overwritten. Default server randomness and snapshot phase are
preserved, so the intermittent failure is not guaranteed on every invocation.

## Real gameplay and input path

The runner creates an isolated loopback `createGameServer({historyPath:null,
progressionPath:null})`, with **no** tick, snapshot, RNG, spawn, health, damage,
position, or timing overrides. A JavaScript host uses supported v3 CREATE, HOST,
START and INPUT packets. Configuration is Meridian deathmatch, zero bots,
180-second time limit and 100-frag limit; the actual normalized config is retained.

The native guest is the shipped `res://world/session.tscn`, instantiated in a
private project copy by `observe.gd`, running on the pinned real Godot 4.5.2
engine and an owned Xvfb display. It joins before host START. This is not an
exported release executable. Xvfb uses `-displayfd` allocation and abstract-local
sockets; TCP and filesystem UNIX listeners are disabled. No shared desktop is
attached, and the shared `/tmp/.X11-unix` mount is not modified.

The victim receives `Input.parse_input_event` with physical Ctrl and left mouse
pressed, plus mouse motion aiming away/up. `Input.flush_buffered_events` makes
the stimulus marker reflect delivery. There are no session-state writes, control
method overrides, fake snapshots, direct transport replacement, or focus/capture
state writes. Ctrl/fire remain physically held in engine input state through
death and two seconds after respawn. A real release/repress event pair then
provides the fresh click, followed by another 1.5-second observation. Cleanup
releases those injected inputs. This proves programmatic physical-key/mouse
event routing and program state, not human hardware input or graphical focus
acceptance.

The attacker derives movement from snapshot positions and source `navigation`,
`path`, `walkEdge`, `visible`, and `eye` helpers. It sends normalized x/z, yaw,
pitch, sprint, weapon 0, and fire through supported INPUT at 20Hz, stopping fire
when it first observes the victim dead. No Match mutation or bot fire API is
called. Navigation samples and every attacker input are retained. Authoritative
death events identify this host actor as the killer; spawn is automatic authority.

## Actual execution history

Evidence is compact: original native stdout/stderr and projected wire data are
gzip files; each appears only once per run. Summary files record artifact SHA256,
source provenance, actual commands, process IDs, termination, and cleanup.

1. `cddc0465-9968-47cb-854f-dc68b61e098e`: exit 1, setup failure before server or
   native gameplay. Filesystem Xvfb sockets could not bind under the environment's
   shared `/tmp/.X11-unix`; the 8MB stream cap terminated the loop and cleanup
   reaped Xvfb. The final harness disables filesystem sockets. Full capped output
   is retained compressed (about 31KB), not repeated in summaries.
2. `4b4af664-c092-4a8a-9336-4665ddeddb38`: exit 1 in the then-strict analyzer,
   which stopped on an ambiguous authoritative lifecycle sample. **Genuine live
   death/respawn occurred.** Native actor 1 was killed by host actor 0. The later
   analyzer reports the failed criteria while retaining the entire sample.
   This version's initial stimulus marker preceded buffered input delivery; the
   subsequent held-state samples and nonneutral input packets prove delivery.
   The final observer flushes input events before marking them.
3. `f6498d16-7394-4c58-ae8e-f7445d65f61e`: final-code run, exit 0. All 14 bounded
   criteria pass in **8.817716 seconds** of observed gameplay wall time. 760 native records, 264 correlated snapshots, 495 queued inputs
   exactly matched to server-received seq 1..495. Native actor 1, roundRevision 1.
   There are 146 predeath active inputs, 116 dead-neutral inputs, 120 postrespawn
   neutral inputs before fresh click, and 90 active inputs after click. ACK
   high-water is 494, so input 495 is receipt-only evidence.

The passing witness is snapshot 95 at time 3.167 (HP 6.61/dead 0), snapshot 96 at
3.200 (HP 0/dead 1.983), and snapshot 156 at 5.200 (HP 100/dead 0). Death event
264 and spawn event 267 corroborate the sequence. Respawn authority is
`[-44,0,10]`, eye height 1.45, yaw -1.347 and pitch 0; native camera is
`[-44,1.45000004768372,10]`, yaw -1.34700000286102, pitch 0, and
`camera_reseeded=true`. Camera rotation is independently sampled after the
session process loop. Capture remains released until the fresh click.

## Reproduced runtime defect: premature alive classification

In the earlier live recording, snapshot 156 at time 5.200 has HP 0/dead .033.
Snapshot **157** at **5.233** has **HP 0/dead 0**, old position `[44,0,-34]`.
Native trace sequence **442** reports `lifecycle=alive`,
`control_eligible=true`, and `camera_reseeded=true` at that zero-health sample.
The actual healthy respawn is snapshot **158** at **5.267**, position `[8,0,34]`,
HP 100; native trace sequence **444** reports `camera_reseeded=false`.

This is the audit's previously suspected zero-health/zero-timer issue reproduced
under normal-rate baseline deathmatch, consistent with wire quantization of a
near-expiry dead timer (`server/room.mjs` calls the three-decimal
`quantizeClone` from `game/quantize.mjs`). `godot/world/local_lifecycle.gd` currently classifies by
`dead > 0` alone. The lead owns any runtime correction. Pointer capture stayed
released and all dead/postrespawn inputs remained neutral; no unintended
movement/fire or camera angle mismatch is claimed in this failure. The defect is
premature lifecycle eligibility/reseed and missing actual respawn reseed.

The strict gameplay-audit continuity criterion fails on the ambiguous sample;
the analyzer does not discard it to manufacture a strict passing triple. The
later genuine successful run has no such ambiguous sample. Both must be kept
when assessing acceptance; the later pass does not fix the earlier failure.

## Correlation, bounds, and limitations

Native records still have no snapshot/input protocol IDs. The observer signal is
registered after shipped handlers; its stdout line must immediately follow the
runtime trace, supplying the accepted snapshot seq. Every observed seq is matched
to unchanged bytes emitted by the owned server, with actor, ACK, health/dead,
position and look checks. Start/roster identity is retained without credentials.
Successful queue ordinal from a complete fresh START prefix is compared to every
contiguous server-received input seq and every control field. This is not timestamp
proximity matching and never equates trace sequence with protocol sequence.
Receipt is distinct from individual application; ACKs are high-water marks.

**Native completion remains `completionProven=false` in every result.** The
HARNESS_BOUNDARY is explicitly a harness observation boundary. Native child exit
and process cleanup do not establish native trace completion. Native errors,
limits, gaps, unmatched input tails and malformed association fail closed.

Version probe: 10s. Export/import: 60s each. Private Xvfb setup: 5s. Connection and
configuration waits: 5s; native pre-start: 12s. Driver gameplay timeout: 105s;
supervisor gameplay wait: 118s, asserted <=120s. Child watchdog: 125s. Each output
stream and projected wire evidence are capped at 8MB. Source trace's own 10,000
record limit also fails acceptance. Each run's exact observed wall time is saved.

Only owned processes/sockets are closed. Cleanup escalates TERM to KILL after 2s,
reaps children, and verifies ESRCH for recorded PIDs. The owned server is closed,
client count is verified zero, and the private temporary project/HOME/XDG is
removed. Godot caches and generated assets never enter a checkout. The final run
has only a retained VSync driver warning, no Godot runtime errors. External
SIGKILL of the supervisor itself cannot run its finally cleanup.

No human visual review, OS focus transition acceptance, performance, adverse
networking, arbitrary reconnect, all-map/mode gameplay, or general absence of
the reproduced lifecycle defect is claimed. `test.mjs` checks the genuine pass
and genuine failure plus explicitly synthetic evidence corruptions; those tests
are analyzer checks, not additional gameplay evidence.

## Final checks actually executed

- `node --test port/tools/native_death_respawn/test.mjs > port/native-death-respawn/offline-tests.tap`:
  exit 0, seven tests passed (two genuine-recording checks and five synthetic
  corruption checks).
- The replay command above: exit 0, same final passing criteria/counts and
  `completionProven=false`. Replaying the earlier live directory returned exit 2
  with the zero-health eligibility/reseed failures.
- `git diff --check`: exit 0. Scoped staged paths were inspected before commit.
- Independent Python SHA256/length checks verified every artifact in all three
  summaries and verified the four final executed harness files against their
  saved source hashes. Compressed artifact payload total: **88,734 bytes**.
- Independent `os.kill(pid, 0)` checks returned ESRCH for every recorded importer,
  native and Xvfb PID. Final-run native PID 1954806, Xvfb 1954799, importer
  1954537; server closed, zero sockets, private temporary tree removed.
