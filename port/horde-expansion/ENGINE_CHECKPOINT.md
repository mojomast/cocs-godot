# Horde engine checkpoint — exclusive slot released

Integrated base: `b871ce98` (worlds/urban art); Horde headless fixture follow-up
is on `expansion/horde-robots`. This checkpoint does **not** claim the full
Blackwater chain or live Warden acceptance.

## Latest bounded run (failed honestly)

Command: `node port/native-horde/blackwater-headless-live.mjs chain`

Evidence: `/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/horde/headless-chain.{log,json}`
and `chain-run-console.log`. Source ran at normal wall clock for ~546 seconds.
Native InputEvent -> HordeControls.sample -> HordeClient.send_controls applied
32,512 samples; largest input gap ~125 ms; resets were three **source deaths**,
not an active-play stale-input failure. Both feeders were restored by real E
input and hold progress. Wave 3 opened west floodgate (mask 1) and source event
`horde-stage-entered` committed B; wave 6 opened east floodgate (mask 3) and
`horde-stage-entered` committed C. The native scene received matching gate-body
revisions. The match then **lost in wave 7** with only the two feeder objectives
complete. `headless-chain.json` reports `passed:false`, wave 7, stage C, two
completed stations, and no Warden receipt.

The fixture's old rule chased enemies whenever the switch pump or relief valve
became available, rather than approaching those **during** their gated wave.
It only tried to visit them in short intermissions, and therefore missed both.
The controller priority has now been changed to route to any available station
first and fight from its holding zone. Station paths now start at the actor's
actual snapshot position in the current gate-mask nav graph, rather than a
fixed post-arrival anchor; these edits are **unverified**. No new engine run
was launched after those edits, at the parent's scheduling request.

Earlier diagnostic outputs are `headless-chain-diagnostic.{log,json}` and
`chain-diagnostic-{75,100,220,250}-console.log`; diagnostics reuse their
`headless-chain-diagnostic` path, so only its **last** contents remain. Initial
Godot editor import crashed after filesystem scan; its stack trace is preserved
in `import-headless-fixture.log`. Direct `--headless` product scene launches
and runs (including the latest full run). Dummy renderer reports shutdown RID
leaks separately in JSON; runtime GDScript errors were fixed before the latest
full run, which reports `errors:[]`.

## Next exclusive-slot commands

Only after an explicit new grant, in this worktree:

```sh
node port/native-horde/blackwater-headless-live.mjs chain
node port/native-horde/blackwater-headless-live.mjs boss
```

Run `boss` only after inspecting the actual chain result. Both invoke the
normal-clock easy/ten-wave **shipping** Blackwater client with a test-only
headless OS-focus seam; cheats/debug disabled, source TTL/epochs unchanged.
The test-only source navigation graph is reproducibly generated with
`node tools/godot-horde/fixture_routes.mjs` if the Blackwater recipe changes.
Do not interpret source-graph or controlled intermission tests as a completed
live objective chain. A separate rendered graphical checkpoint should only be
taken after real source chain receipts exist; prior `blackwater-live-gameplay.mp4`
is labeled wave-one footage.
