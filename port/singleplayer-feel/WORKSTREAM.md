# Single-player feel and in-game cheats — owner playtest feedback

The owner reports bullet-sponge enemies, fragile player health, weak weapon
impact, occasional jerky movement and bland campaign pacing. They explicitly
requested an Astra subagent to research enjoyable gunplay and improve the game,
plus an in-game debug menu with weapons, ammo, invulnerability and flight.

## Ownership

- Astra `ses_f0849000fffe15qmvUqCVdBI4b`, branch `improvement/singleplayer-feel`,
  worktree `/home/mojo/.tmp-on-disk/cocs-singleplayer-feel-20261001`, base `6e2c6a32`:
  cited gunplay research, campaign balance/encounter pacing, weapon feedback and
  movement root-cause fixes, before/after measurements and meaningful checks.
  Avoids parent-owned campaign authority/demo cheat hooks and active Horde lane.
- Parent: `port/native-debug/solo_cheats.mjs`, `godot/debug/solo_cheats.gd`,
  campaign authority/demo integration and tests. Horde integration follows its
  active native-chain acceptance, avoiding concurrent edits to its authority.

## In-game menu design / current implementation

Visible Cheats button and F3 during single-player play; no environment flag or
special launcher. Authority-confirmed toggles for invulnerability, unlimited ammo
and flight/noclip; all ten weapons/ammo and health/armor actions; clear toggles.
Opening pauses the owned single-player simulation, while snapshots continue;
closing resumes with fresh input state. Flight uses WASD, Space up, Ctrl down,
Shift faster; switching off lands on a clear source-supported surface or returns
to takeoff if no supported landing is available. No multiplayer-room integration.

The parent implementation has **not been parsed or rendered by Godot**. Five
Node tests cover unchanged normal simulation, strict commands, reversible effects,
flight/landing, and a real campaign wire pause/resume/stale-command/new-connection
journey. The focused campaign authority/package-closure set passed 15/15 before
the fifth no-op test was added; all five cheat tests then passed. Initial failures
were a test assuming finite pistol ammo and a lifecycle stub missing its solo
identity fields; both were corrected. Native menu/flight acceptance and a new
build remain pending. Flight publishes actual velocity for smooth presentation.

## Scheduling / delivery

Horde retains exclusive Godot for the full Blackwater chain and Warden test.
Urban roof acceptance follows briefly, then Astra/parent single-player engine
verification. Astra currently has research/code/Node-only permission.
The existing campaign playtest remains published at `614e11ad`. The next testing
build should incorporate the owner's balance/feel and cheat-menu improvements,
alongside the separately verified multiplayer expansion, after integration checks.

Evidence target: `/home/mojo/.tmp-on-disk/cocs-singleplayer-feel-evidence-20261001/`.

## Astra implementation intake

`83480dfc` is integrated on parent as `0d987f9d`, alongside cheat checkpoint
`07023a8d`. Astra's 41 Node checks pass; no native execution yet. Consulted sources
and precise access scope are in RESEARCH.md (DOOM GDC abstract, Griesemer/Halo,
Vlambeer Gun Godz, Fiedler timestep/interpolation). CHANGELOG.md and the 140-row
ideal-hit matrix document measured before/after durability, not human TTK.

Normal now starts 140 health/60 armor, with campaign-only attack-lane/crossfire
budgets, recovery while returning fire, bounded close-kill salvage, readable
NPC attacks and breakable shields. Role positions, relief encounters and combat-
overlapping restores target pacing. Source-clock/velocity camera reconstruction
targets batched-snapshot jerk. Mechanical firing tails and robot reactions add
impact; subjective gunfeel and native playback still require review.

Parent added the new `feel.mjs` to the explicit package closure and registered
authority/motion verification gates. Integration run: 34/35 initially passed;
the cheat isolation test manually spawned an untagged source NPC rather than
using campaign deployment, causing the new robot policy to lack its model.
The test now uses actual campaign deployment; all five focused cheat tests pass
on the combined code, including enemy damage and unchanged disabled behavior.

Parent requested Horde yield Godot after its current bounded case so the owner's
campaign fixes can proceed. Do not start another engine until Horde explicitly
releases it. Brief urban roof acceptance and then Astra/cheat native checks follow.

## Engine handoff and Horde menu integration

Horde released Godot at `77dd1275`: its normal-clock fixture restored both
feeders, opened both gates and reached source stages B/C, then lost at wave seven
before pump/valve completion. 32,512 input samples, maximum gap 125 ms, no
active-play stale reset. Full mission/Warden acceptance remains incomplete;
routing fixes are committed but unrerun. Parent preserved that checkpoint.

Parent explicitly granted **exclusive Godot to Astra now**, prioritizing owner
campaign feedback. Urban roof remains code/Blender-only until Astra releases.
Astra owns native feel/movement/audio and cheat-menu interaction acceptance,
including parser/UI repairs if necessary; parent performs no competing engine run.

The parent additionally wired the shared solo menu/effects into ordinary Horde
launches, including Blackwater. Explicit legacy debug-panel launches retain that
existing panel. Source/Node checks across all six Horde maps prove unchanged
simulation with cheats off and functioning bounded flight/grants; a Blackwater
wire check proves ordinary-launch menu capability, pause, grant and resume.
The broader 17-test set first passed 16: the new test expected null for infinite
pistol ammo, but source snapshots use the string `∞`. Correcting that assertion
produced 2/2 focused passes. Native Horde menu acceptance is still pending.
