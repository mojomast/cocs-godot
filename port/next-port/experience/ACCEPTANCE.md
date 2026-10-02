# Experience acceptance — READY FOR ENGINE

**Implementation committed for serial engine review; native acceptance pending
explicit grant.** No Godot, Blender or import was started during the restricted
research/code stage. No release/package acceptance is claimed.

## Completed checks

- `node tools/experience/extract.mjs`: source oracle generated — 115 caption
  rows, 432 replacement cases, ten source range labels.
- `node --test game/audio-captions.test.mjs game/hud.test.mjs game/config.test.mjs`:
  **143 passed, 0 failed, 1 skipped** (the source's opt-in exhaustive 8-bot sweep).
  This is source verification, not native execution.
- Gameplay integration source check: the delivered kit catalog exactly matches
  the read-only source projection; fixture coverage is all nine operators
  (`chatgpt`, `claude`, `grok`, `meta`, `gemini`, `deepseek`, `mistral`, `kimi`,
  `qwen`). The gameplay cherry-pick is `5ef020a8`; upstream acceptance is not
  substituted for combined-UI acceptance.
- Initial extraction failed because `three` was unavailable; retained in
  `/home/mojo/.tmp-on-disk/cocs-port-experience-evidence-20261001/research-checks.txt`.
  Repaired with the authorized parent `node_modules` symlink, then extraction passed.

## Native commands after explicit serial grant

Use the lane's own `.godot` cache and `LP_NUM_THREADS=1`:

```sh
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --editor --import --quit
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/experience/contracts.gd
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/experience/combined.gd
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/product_shell/settings_contract.gd
```

Required after parser/contracts: actual connected input with native Settings
and authoritative events. Evidence goes in
`/home/mojo/.tmp-on-disk/cocs-port-experience-evidence-20261001`.

| Journey | Required observations | Current result |
|---|---|---|
| Home → F12 → enable captions → launch | Keyboard/mouse focus, saved preference reload, source off default on legacy saves | Not yet run |
| Muted match → fire/reload/pickup → protected wave/mission event | Caption text independent of audio mix, duplicate does not prolong, priority window expires | Oracle frozen; native pending |
| Take damage → death recap → respawn | Three authoritative hits, attribution only from received snapshot, unknown attacker fallback, clear on respawn | Contract authored; native pending |
| Local overkill | Worded OVERKILL, no invented ASSIST/streak | Contract authored; native pending |
| F12/Career/F3/open/close; focus loss/resume | No input leak, caption hiding, existing authoritative pause unchanged, no old caption replay | Not yet run |
| Handoff / stale / reconnect / results / Home | Clear ledger/captions, no previous actor attribution | Contract authored for model handoff; connected pending |
| Wide 1280×800 and compact 760×520/UI150 | Inspect screenshots; text bounds, caption/recap versus mode HUD and comms; retained failure captures | Not yet run |
| Combined PlayerGameplay readout | All nine operator details, exact power/movement state, concurrent active cooldown, passive descriptions, grenade/statuses; keyboard/mouse scroll with cursor released | Source coverage checked; signal/UI contract authored, native pending |
| Shared and independent route families | `client`/integer 3 and `net`/string active; lazy child, spectator seat handoff, fallback suppression/restoration | Contract authored; native pending |
| Campaign transcript composition | Objective/kit scroll, comms/story/caption rows, top/bottom preference, detach on route exit; preserved F3 authoritative pause | Contract authored; native pending |

No new audio signal generation, routing, buses or voice selection was changed.
No output PCM capture or human listening was performed, and neither is claimed.
If subsequent fixes change actual audio, capture PCM and distinguish observed
waveform from unobserved human listening before closing that scope.

## Parent integration contract

Normal application route launches get `LocalSettings/PlayerInformation`
automatically. Existing `client.snapshot/events/started/results/connection_error`
signals are read-only inputs. The client retains deduplication ownership.
`player_info.bind_session(session)` is available for a nonstandard route owner;
`apply_settings(normalized)`, `clear()` and `unbind()` are the explicit lifecycle
API. No changes are required in `world/session.gd`, presentation, route catalogs,
gen_routes or mode allowlists. No README edits were made.

The combined presenter also reads `PlayerGameplay.status_changed` and retains
its complete model; the gameplay source owner is unmodified. Campaign HUD/story
widgets have small docking hooks for the measured objective/comms areas. These
changes require native campaign screenshot/input regression checks after grant.
The intended documentation location is now `port/next-port/experience/`; the
mistyped `docsport` files were moved with patch operations, not duplicated.

Role coverage at this checkpoint: ordinary seated player (implemented), unknown
attacker (implemented), spectator personal events suppressed (implemented),
host/joiner/reconnect runtime (not observed), compact native runtime (not observed).

**Slot status:** never acquired; no engine process is running for this lane.
Await explicit grant before native work. Final EXPLICIT SLOT RELEASE must be
reported after granted acceptance work, not fabricated here.
