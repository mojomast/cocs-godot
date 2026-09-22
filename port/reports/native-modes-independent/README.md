# Independent team / rocket mode authority checks

Executed at `5ce0ae0` with the lead's fixture/gate integration changes:

```sh
PORT=0 TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
node port/native-mode-expansion/live.mjs --output=/tmp/opencode/native-modes-independent
```

Exit 0. All six normal-rate source rounds ran to authoritative time-limit
results: Meridian/Verdant/Ember × Team Deathmatch/Rockets. Each recorded 1,800
snapshots and movement/fire/ACK checks. Team score changes were observed on
Ember, ending Red 1 / Blue 0; the other two ended 0 / 0. Snapshot-derived team
totals agreed throughout. Actual shipped TDM session smoke additionally passed
on all three maps with visible-state updates, movement/fire and ACK 15.

The six longer cases use a dedicated headless native observer that exercises
source authority and scoreboard/combat modules. They are not graphical UI
acceptance or proof that a currently disabled mode is playable in the main menu.
In particular, Rockets remains pending: the observer confirms source weapon-1
launches and in-flight snapshot projectiles, but the current session does not
yet render them. The few ordinary-shot feedback events are not rocket visuals.
Health/armor pickups remain present in Rockets. No source rules were modified.

Per-case logs preserve exact counts/configuration findings. Recording completion
and individual application of every received input are not inferred from ACKs
or normal process exits.
