# Native Sunscar combined-arms delivery

- Branch: `agent/combined-arms-native`
- Base: `013ad65`
- Worktree: `/tmp/opencode/combined-arms-native-013ad65`
- Implementation/tools/tests commit: `1126a08`; the following scoped commit carries discovery, evidence and integration handoff.

## Result

The required **Sunscar Convoy / combined-arms infantry → source Puma driver → motion → dismount → fresh infantry** slice passed against the ordinary, unseeded, default-rate source server with zero bots. No authority writes, teleports, handler calls, physics changes, forced seed, protocol additions or map-mode capability overrides were used.

Accepted evidence: [`evidence/9216ae2e-c5ad-4c37-8e04-772855d11fba/`](evidence/9216ae2e-c5ad-4c37-8e04-772855d11fba/).

| Observation | Accepted run |
|---|---:|
| Complete native route | 15.08 seconds |
| Real vehicle | `sunscar-0-puma` |
| Maximum source vehicle displacement | 26.833 m |
| Fresh post-exit infantry movement | 3.262 m |
| Queued / server-received input packets | 324 / 324 |
| E requests received, ACKed, applied | 2: mount and exit |
| Exact snapshot-sequence correlations | 393 |
| ACK-correlated neutral samples | 70 |
| Native synthetic checks | 43 |
| Offline replay / negative tests | 8 |

“Exact correlation” means matching recipient snapshot sequence, ACK, local actor and driver relation, plus every one of the ten rendered vehicle roots against source XYZ. JSON numbers use a 1e-12 comparison tolerance; Godot Vector3 roots use 1e-4 m. Camera position is separately recorded and is presentation-only. ACK high-water does not claim every received packet affected a simulation tick. Source braking is observed under a Space tap plus S deceleration/reverse; this is not an isolated brake-physics benchmark.

`hashes.json` records the exact executing temporary source root, original checkout, all game/server SHA-256 values, new scene/test scripts and generated semantic content. Source copy equality is checked before execution and immutable source hashes after it. Import, synthetic checks, graphical gallery and native logs are retained. The final summary verifies owned process reaping and temporary project removal; wire evidence verifies server closure and zero sockets. Each graphical run used a new private Xvfb with `-nolisten tcp -nolisten unix`, displayfd allocation, and port-0 loopback authority. Existing pinned Godot/dependencies were read-only.

The six successful parse-only banner logs have their extra trailing blank line removed for repository whitespace checks; native traces, wire records and screenshots are unchanged.

## Delivered ownership/API

- `godot/combined_arms/demo.tscn`: standalone host adapter.
- `demo.gd`: allowlisted create/configure/start, fresh local identity lease, timeout/results/round cleanup, source infantry and vehicle presentation.
- `controls.gd`: extends proven sports input gate; existing infantry movement math; E one-shot pending request; blocks held keys across release/seat changes; mouse capture, focus, stale/dead/missing identity release. Fresh Enter and fresh movement presses are required.
- `lease.gd`: resolves source actor↔vehicle relation, including JSON float actor 0, team-unlocked source entry, missing/wrong/dead/stale leases and full seat availability.
- `camera.gd`: extends existing presentation-only chase/camera obstruction cache; infantry eye uses source Y. No local physics or ground projection.
- `fleet.gd`: extends existing Puma renderer without editing it. Secondary chassis use new bounded procedural silhouettes; secondary/non-driver seats are exit-only previews, not accepted drive/flight controls.
- `hud.gd`: readable infantry/driver state, health/hull, source-derived speed/heat and fresh-capture prompts.
- `godot/tests/combined_arms/`: input/lease/renderer checks, harness-only native event route, synthetic model gallery.
- `port/native-combined-arms/`: standalone human launcher, isolated acceptance/server observer, replay validator, negative tests, discovery and unapplied integration patch.

Source routing and exact map locations are in [DISCOVERY.md](DISCOVERY.md). Of particular importance: **combined-arms Room forwards jump as an edge**, so Space is a brake tap. Sports held-handbrake semantics do not apply. The adapter preserves the ordinary protocol route. E is also an authoritative edge; native buffers one tap until its next send and never synthesizes repeated interactions.

## Run now

```sh
python3 -B port/native-combined-arms/play.py --map sunscar-convoy
python3 -B port/native-combined-arms/run.py
python3 -B port/native-combined-arms/validate.py port/native-combined-arms/evidence/9216ae2e-c5ad-4c37-8e04-772855d11fba
python3 -B -m unittest discover -s port/native-combined-arms -p 'test_validate.py' -v
```

The human launcher uses the caller-selected display and has no route automation. Enter engages; WASD walks or drives; mouse looks/aims; E mounts/exits; Space jumps or requests brake tap; Shift sprints/boosts; S decelerates/reverses; LMB uses source fire. Esc releases. Source mount/exit releases inputs, so press Enter and movement keys anew after each transition.

The exact `play.py --map sunscar-convoy --seconds 10` command was separately executed on another owned private Xvfb. It passed scene startup and bounded cleanup with no engine/script errors; logs and process-reaping summary are in `evidence/launcher-check/`. This idle launcher check is separate from driving evidence. `git apply --check` passed for the unapplied hook artifact; it was not applied. The final stricter replay additionally checks brake receipt/ACK and source deceleration; all eight replay/negative tests still pass.

`UNAPPLIED-launcher-hooks.patch` supplies precise common/package routing additions for `--experience=combined-arms`. It is a delivery artifact, not an applied edit. Lead owns help/tests/package rebuild/integration. Existing package native-file selection automatically includes the new tracked directory.

## Direct image inspection

Read directly with the image-capable file tool:

- [Live mounted, 960×600](evidence/9216ae2e-c5ad-4c37-8e04-772855d11fba/mounted-960.png): Puma body/wheels/roll cage clearly visible; hull/speed/driver line and controls legible. Exit prompt is below the silhouette.
- [Live released, 1280×800](evidence/9216ae2e-c5ad-4c37-8e04-772855d11fba/released-1280.png): source-stopped Puma, visible forward refinery wall, clear fresh-capture prompt, no camera/body overlap.
- [Synthetic silhouettes, 960×600](evidence/9216ae2e-c5ad-4c37-8e04-772855d11fba/silhouettes-960.png) and [1280×800](evidence/9216ae2e-c5ad-4c37-8e04-772855d11fba/silhouettes-1280.png): distinct light Scout, tracked cannon Titan, long boxy Transport, wing/pod Hornet, and reused open Puma. These are synthetic readability evidence, not secondary-vehicle gameplay acceptance.

No 1:1 source visual parity is claimed. This was injected native physical-input acceptance, not a human usability session. Model/scene images were actually inspected; human driving/camera sign-off remains available via the launcher.

## Retained failures and limits

- `ba75ab6f-d377-40b9-8d75-0228daea2673`: preflight synthetic test compared a float32 eye Y with exact decimal equality; corrected to approximate comparison. No server run.
- `ab358fc4-493b-40e0-9003-606b041e0392`: preflight GDScript inference failed after expanding seat availability; explicit boolean type fixed it. Bounded test process reaped. No server run.
- `15e8791c-60cb-4ba0-a3ca-25068f97ee0a`: first live route completed but validator rejected missing brake request. Harness down/up happened between network sends; holding physical Space for 200 ms fixed the test. Failed artifact remains failed, with original screenshots/wire/logs. Later HUD prompt placement and gallery framing improvements are visible in final captures.

Primary acceptance required two live attempts. Tidal secondary was not attempted. Death/stale/focus/lease release behavior is covered synthetically; the live route proves seat transition/explicit release/fresh infantry controls. No live disconnect impairment, OS focus switching, mounted combat outcome, gunner/passenger gameplay, aircraft flight, objective completion, restart, packaged binary, remote multiplayer or public deployment acceptance is claimed. New model positions correlate with live source roots, but only Puma driving is accepted.

Changes are restricted to the three new owned directories. Existing vehicles/sports/session/net/UI/objective/LATTICE/source/server/contracts/dependencies/root documentation/launchers/verifier remain untouched. No merge, push or public deploy.
