# Native acceptance journal

Engine: Godot 4.5.2, exclusive slot granted by parent, `LP_NUM_THREADS=1`.
Evidence root: `/home/mojo/.tmp-on-disk/cocs-singleplayer-feel-evidence-20261001/`.
All rendered runs use private Xvfb and llvmpipe, **not human GPU performance evidence**.

## Final acceptance: PASS

Code checkpoint **`b800000d`**. Campaign: **`live-rdpsmH/acceptance.json`**, native exit 0,
`passed=true`, `wireOK=true`, no failures. Horde: **`live-gt49GI/acceptance.json`**, pass.

The final campaign journey confirmed:

* Ordinary movement to the first encounter and **7 confirmed hits / 1 robot kill** before enabling any cheat. Health/armor remained **140/60**. First aimed fire to kill was **11.90 source seconds** including approach, misses and input recaptures; this is not ideal-hit or human TTK.
* All ten actual authority weapon events with first-person recoil confirmation; all menu widget commands, wide/compact screenshots, pause time freeze and held-input cancellation.
* Flight rise **6.60 m**, settled eye error **0.0311 m**, authoritative landing after clear, final F3 resume and gameplay screenshot.
* All ten before/after weapon WAV pairs plus **17.090 s** Master-bus recording, peak **0.4166**, RMS **0.05441**. Files are in `live-rdpsmH/` under the evidence root.
* **10 explicit recaptures** after software-rendered freshness resets and **2,758** coalesced presentation snapshots. These counts remain visible limitations, not GPU performance acceptance. TTL and authority stale-command rejection were preserved.

**Engine slot released after this run.** The owned Godot child and local authority exited;
no further native execution is scheduled by this agent. Parent may proceed with urban
acceptance/integration/rebuild. Owner listening, subjective enjoyment, full-chapter pacing
and hardware-frame-time acceptance remain for the next playtest.

## First failures and repairs

1. `motion-first.log`: source velocity alone reduced a batched-camera spike from 50.74 to 18.05 m/s, still above the bound. Exponential correction was adding a second artificial velocity. Explicit-velocity campaign motion now caps correction speed at 6 m/s. Final irregular peak **14.70 m/s**; regular-stream peak **9.76 m/s**. Fixed exact float equality in two test assertions to use approximate Vector3 precision; source ordering assertions remain.
2. `world_motion-unit-native.log`: rejecting every equal source tick changed Horde's existing corrected-same-tick behavior. Preserve that zero-velocity duplicate policy for source-clock consumers without explicit velocity; campaign's explicit-velocity stream rejects duplicates. Shared motion passes **99 checks**.
3. `horde-identity_composition_test-native-2.log`: worktree lacked its generated semantic catalog. Plain exporter correctly refused the derivative; re-running with `COCS_SOURCE_DERIVATIVE=port/contracts/lattice-catalog-derivative.json` generated the declared derivative catalog. Source files were not edited. Horde composition then passed **28 checks**.
4. First live launch had no X11/Wayland display. Subsequent graphical runs use `xvfb-run -a -s '-screen 0 1280x800x24'`.
5. `live-xXsyd8`, `live-w0suJ8`, `live-iQfWUP`: native commands reached the authority, but initial rendering/audio/weapon setup stalls triggered legitimate stale-input resets. A fresh weapon key could expire before its first outgoing packet. The selection deadline now starts when queued, not before sending; sent-request expiry, release cancellation and ACK cancellation remain intact. The live driver explicitly clicks to recapture after observed resets and reports those recaptures, rather than retaining stale held controls or changing TTL.
6. `live-oRNv43`: Horde's first menu command carried an epoch superseded during first-frame rendering. The authority correctly rejected it, but the overlay could remain visible over running gameplay. The shared menu now retries only the current UI intent after observing a newer epoch with unchanged command revision. An actual pause acknowledgment advances the revision and therefore cannot create a retry loop. Timeout reconciles overlay visibility to confirmed pause state. Dead actors cannot enable actions; an existing pause remains resumable.
7. `live-DnHSQo`, `live-s62s6s`, `live-sYfvgN`: first encounter and successive weapon setup exposed recurring llvmpipe stalls. Campaign presentation now coalesces already-validated snapshots within one network-drain frame; sequence/ACK validation still processes every packet, ordered events remain immediate, and start/results clear pending poses. Client lifecycle tests cover terminal boundaries. The driver retries explicit key presses and recaptures for firing after resets; its measured recapture counts remain visible evidence of this environment's limitations. `live-DnHSQo` confirmed a cheats-off first encounter kill (4 hits, 140 health/60 armor retained), but timed out at weapon 2; that partial run is not full acceptance.
8. `weapon-selection-final.log`: the existing input fixture lacked an audiovisual arena, so newly integrated AV snapshot binding correctly rejected it before capture. Its transport stub now omits unrelated audiovisual binding; the actual production input/selection path passes in `weapon-selection-final-2.log`, including unsent-request preservation and sent-request expiry.
9. `live-Yxsifz`: full wire journey passed, including clear/landing/final resume. Its only failed assertion incorrectly required the hidden menu's Resume button in the final gameplay screenshot. Image inspection confirmed normal gameplay and the compact scrolled menu's accessible controls. The final gameplay capture now asserts that the overlay is closed; menu captures still require visible Resume and viewport containment.
10. `live-WMI2bB`: another legal stale-input reset occurred during flight ascent. The driver now releases held Space as part of explicit recapture and retries fresh ascent input, using the same bounded recovery already exercised for movement/weapon fire. Authority freshness limits remain unchanged.

## Passing scoped gates so far

* Campaign motion: regular/irregular packets, same-arrival updates, old source time, collision stop, step height, teleport, death and reset (`campaign-feel_motion-native-2.log`).
* Shared motion: **99** checks; Horde composition: **28**.
* Campaign session lifecycle: pass.
* Authored robot presentation: **459** checks, including damage sensor flare and authority-owned exposure color (`campaign-robots-closure.log`).
* Shared procedural audio: **411** checks, including voice limits, mute, peaks and per-weapon voices.
* First-person recoil: all ten weapons, bounded peak/shove/settle and reduced motion pass.
* Menu boundary test: stale command retries against new epoch; own pause ACK does not retry; dead-state actions disabled with resume retained (`menu-boundaries.log`).
* Weapon input/selection: **66** checks, production session with synthetic final transport (`weapon-selection-final-2.log`).
* Final focused Node run: **21/21** feel/campaign authority/shared cheats/Horde integration; generated-core provenance **3/3**, in `node-final.log` and `provenance-final.log`.
* Real native Horde shared-menu journey: **pass**, `live-gt49GI/acceptance.json`. Visible launcher → authority pause → invulnerability toggle → all-weapon grant → clear → F3 resume/new epoch/pointer capture. Standard Meridian map, no wave progression claim, no actor-state injection.

## Live harness contract

`port/singleplayer-feel/live.mjs --run-native` owns a normal campaign authority and an actual native scene. `--horde` runs the short shared-menu spotcheck. The driver uses widget signals and `Input.parse_input_event`; it has no fixture control endpoint, match replacement, teleport, health injection or forced win. UI captures retain full-resolution text; gameplay uses reduced internal 3D resolution to give llvmpipe scheduling headroom. The initial Normal encounter precedes any enabled cheats.

The campaign journey covers wide and 150%-scale compact menus (including scrolling to all lower actions), authority pause/time freeze, every cheat action, held-input cancellation across closing epochs, flight ascent/landing, ten actual weapon inputs/recoil events, and a source-authoritative robot kill. Reports must be consulted for actual completion; a prepared scenario is not acceptance.

The harness exports the **real-event cached weapon samples**, corresponding baseline samples, and the actual Master-bus gameplay recording. The comparison baseline `6e2c6a32` has byte-identical audio/recoil files to published `614e11ad` (`git diff --stat` empty for these files). Dummy audio rendering is used for deterministic native capture: no human listening or subjective improvement is claimed. Sample peaks, energy and native event delivery complement the listening artifacts; they do not prove enjoyment.

`live-euoPuK` completed cheats-off combat (3 hits/1 kill), all ten authority-confirmed weapons and recoil events, and exported all comparison WAVs plus a **14.675 s** actual gameplay mix (peak **0.2422**, RMS **0.05035**). The following resume/clear sequence failed because the fixture computed millions of PCM sample metrics synchronously before sending F3, starving the live connection. Offline analysis was moved after the complete live journey. This is a fixture scheduling failure, not accepted end-to-end completion. Pulse mechanical-region energy **9.102 → 13.615**, same **0.5463** peak. Existing rocket/rail/plasma/grenade sounds are intentionally identical; ballistic mechanical layers change five voices. The reported engine frame deltas are capped simulation deltas, **not wall-clock frame-time benchmarks** (the first report used the imprecise field name `renderFrameMilliseconds`).

## Reproduction

Obtain the shared engine slot first; run native commands serially.

```sh
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/campaign/feel_motion.gd
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/campaign/feel_menu.gd
xvfb-run -a -s '-screen 0 1280x800x24' env LP_NUM_THREADS=1 node port/singleplayer-feel/live.mjs --run-native
xvfb-run -a -s '-screen 0 1280x800x24' env LP_NUM_THREADS=1 node port/singleplayer-feel/live.mjs --run-native --horde
node --test port/singleplayer-feel/feel.test.mjs port/native-debug/solo_cheats.test.mjs port/native-debug/solo_horde.test.mjs port/native-campaign/authority.test.mjs port/native-campaign/core-provenance.test.mjs
```

`GODOT_BIN` must be exported to the harness; the verified executable was `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.
