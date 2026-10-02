# Player gameplay source-parity lane — 2026-10-01

## Scope and authority

Base: `29e242a0`, branch `improvement/port-gameplay`. Published runtime supplied by
the parent: `1c1f6e34` / `quiet-relay-targeting-animation-2026-10-01`.
The actual files on this branch, rather than the historical integration roadmap,
were audited. Source remains `515daf07589150dd3241f4ae1425cc1b093912f5` with reviewed
derivative `0326b435a2fdd88e6e7a01b8a7325feccc4d15cb`. No `game/`, `server/`, source
lock, map, route, campaign-authority, shader or physics files were edited.

**Delivered:** reliable short X taps for the three tool-mobility operators;
snapshot-backed shared-rope/grapple presentation; readable ability, mobility,
passive, grenade and jam/ride states. These complete native access/feedback for
existing authoritative mechanics. They are not newly implemented source powers.

## Evidence-linked parity inventory

Paths below refer to this checkout. Source line references identify inspected
entrypoints; function names remain useful when later integration moves lines.

| Player journey / source entrypoint | Native state at base | Gap / decision | Delivered / remaining evidence |
|---|---|---|---|
| Q active powers: `app/page.tsx:623–624,883`; `game/core.mjs:1022–1033` (`power`) | Q already queued as a fresh-press pulse; source performs all seven harness actives, riders, costs and restrictions | No new mechanics needed. Active/cooldown identity was absent from the ordinary native HUD | All seven names from source-generated catalog; authoritative active/cooldown text; five added activation silhouettes. Existing Guardrail/Phase Step shield/dash effects retained. Live Q→accepted event→active→cooldown and rejected second press on three operators; nine-operator controlled source fixture |
| Kimi X Blink Step: `game/kits.mjs:104–107`; `movement.mjs:996–1002` | Held X worked; a complete press/release between samples disappeared | Restore legitimate input path, preserving held/release semantics | Before: zero mobility wire frames, no blink. After: one mobility frame, windup/start/end, **5.636m** authoritative displacement, source cooldown and native text |
| Qwen X Deployable Rope: `kits.mjs:109–112`; `movement.mjs:1004–1028`; `core.mjs:707–727,334` | Source could place/ride shared rope with held X; no native cable/boarding marker | Short tap plus missing world affordance | Live one X pulse→rope-place→anchor→source `zipRide`→**3.972m** travel. Native cable observed. Gold boarding marker and mint cable inspected in separately labeled controlled source fixture. Another player's ride is **pending**, not claimed |
| ChatGPT X Grapple: `movement.mjs:972–994`; `core.mjs:grappleLanding` | Source grapple/mantle physics already exist; held X reaches them | Short tap plus missing cable during source active phase | Live one X pulse→hook/start→**3.199m** movement→release; native cable observed during active snapshot. Upward roof mantle not exercised by this live journey |
| Mistral Air Dash, Gemini Double Jump, Grok Super Jump, DeepSeek Hover Jets, Meta Brace Slam, Claude Safety Glide: `kits.mjs:66–114`; `movement.mjs:stepMovement` | Existing Space/Ctrl held/edge controls and source movement state machines | Retain physics; expose actual resource/phase and appropriate input hint | All nine mobility names/hints, charges, fuel and cooldown projection tested. Full live journeys for these six remain pending |
| Nine signature passives: `game/operator-verbs.mjs:OPERATOR_VERBS,operatorVerbSnapshot`; Three.js `ability-vfx.mjs:1–35,86–99` | Source mechanics present. Native Alignment Review shield presentation already reads `verbState` (`combat_shields/controller.gd:45–50`) | Expose public passive state without reimplementing effects or duplicating shield shells | Heat, Compute, Review, Adaptive, Tool Use, Braced and Long Context numeric text; Effortless/Revision identity and description. Kimi trail geometry/radar and distinct world VFX for every passive remain pending |
| Slide / grapple mantle / wallrun: `core.mjs:moveActor,grappleLanding`; `first_person/rig.gd` | Source slide and grapple landing plus native posture/view presentation exist | No wallrun implementation found in source; do not invent one. Preserve recent physics/motion | Retained, no new source-physics claim |
| G grenades: `core.mjs:1196` (`throwGrenade`); `app/page.tsx:887`; `combat_actions.gd:EDGE_KEYS` | G already pulses; source throws weapon 5 frag with 7s cooldown | Source has no player grenade-type selector to port | Added public cooldown/readiness text. Existing grenade mechanics retained |
| Alternate fire / ADS / attachments: `core.mjs:altFire`; `world/combat_actions.gd`; `weapon_effects/controller.gd`; `career/service.gd` | Z/MMB alt fire, RMB ADS, loadout attachment persistence already available | Do not relabel previously ported features | Retained; no changes to first-person/shader/attachment mechanics |
| Buff/debuff readability | Public `active`, `slow`, rider timer, `movement`, `verbState` already arrive | Missing compact source-state readout | Added read-only model and fallback panel. Team buffs/recon beyond public fields are not inferred |

### Per-operator native status coverage

| Operator | Passive text | Mobility / input |
|---|---|---|
| Mistral | Effortless | Air Dash / airborne Space |
| Gemini | Revision | Double Jump / airborne Space |
| Grok | Heat fire-rate percentage | Super Jump / hold Ctrl then Space |
| DeepSeek | Deep Compute charge | Hover Jets / hold Space |
| Meta | Braced recovery timer | Brace Slam / Ctrl + Space |
| Claude | Alignment Review pool and charge | Safety Glide / hold Space |
| ChatGPT | Adaptive handling window | Grapple / X |
| Kimi | Long Context trail count | Blink Step / X |
| Qwen | Tool Use handling window | Deployable Rope / X |

## Integration contract

The only shared-session edit is seven lines in `world/session.gd:on_snapshot`,
immediately after `presentation.apply_state`. It lazily installs a child named
`PlayerGameplay` and binds the passive adapter. No `presentation.gd` rewrite.
Subsequent source `snapshot/events/started/results/connection_error` signals drive
the child. Route roots using the shared snapshot handler acquire it automatically.
Roots with a completely independent handler can install the same child with
`bind_session(session)` when they expose the ordinary session contract.

**EXPERIENCE hook:** `session.get_node("PlayerGameplay")` offers:

- `status_changed(model: Dictionary)` and current `model`.
- `show_compact_status = false` to replace the fallback panel with integrated HUD.
- `model.power = {name, state, active, cooldown}`.
- `model.mobility = {name, input, state}`.
- `model.passive`, `passive_description`, `statuses: Array[String]`, `grenade`.
- Empty model means absent/dead/spectator/unfocused/stale/paused or blocked overlay.

Model numbers are public source observations, not locally simulated timers.
The fallback panel uses the existing 1280×800 layout and does not own menus,
settings, pause, pointer capture or input remapping. EXPERIENCE should position
its replacement responsively with the rest of its HUD.

World cues read only `movement.anchor/from/life`, `movement.grapple/phase` and
accepted `power` events. Cable slots are capped at 32 and transient bursts at 16;
event history is bounded/deduplicated. Suspended events are consumed without
replaying on focus return. Missing actors/anchors drain geometry. Reduced-motion
setting disables burst growth. Rope indicator receives an 8cm presentation lift
to avoid floor z-fighting; source boarding/collision endpoints are untouched.

## Acceptance and reproducibility

Evidence root:
`/home/mojo/.tmp-on-disk/cocs-port-gameplay-evidence-20261001/`

| Check | Result / evidence |
|---|---|
| Source catalog + controlled fixtures | `fixtures-2.log`: nine operators; exact 45-point Recompile heal, 16s cooldown (Claude's locked Guardrail 10s), refused cooldown press; rope spends one charge and 10s cooldown |
| New native projection/input/lifecycle checks | `unit-final.log`: PASS, zero failures. Includes short tap, busy queue, fresh press across clear boundaries, all nine kits, death, disabled modes, mount/flag state, event dedup/expiry and immutable received-frame reset |
| Existing source tests | `source-tests.log`: **75/75** (`movement`, `operator-verbs`, `ability-vfx`) |
| Existing native controls regression | `existing-controls-windowed.log`: **90 checks, zero failures** |
| Existing campaign session regression | `existing-campaign-session.log`: `CAMPAIGN_SESSION_OK` |
| Live native input → real source server → native presentation | `live-final/results.json`, per-operator `*-wire.json`, `*-snapshots.json`, logs and screenshots; Kimi/Qwen/ChatGPT PASS |
| Independent measured summary | `acceptance-summary.json`: each final journey has **one mobility wire pulse**, **two power requests / one accepted power event**, source movement cooldown and displacement |
| Before-control reproduction | `before-short-tap/`: restored old sample expression for this run only; Kimi exit 1, **zero mobility wire frames**, no movement events. Final implementation restored |

Boundary tests in `test.gd` are controlled adapter tests, not nine separate real
window-focus/spectator/mode/vehicle journeys. Existing session tests exercise
their own lifecycle contract. No human playtest, hardware GPU, platform export,
full nine-operator movement matrix or full visual parity claim is made.

### Actually inspected screenshots

- `live-final/kimi-accepted.png`: active Recompile, readable Blink cooldown.
- `live-final/qwen-cooldown.png`: readable rope charge/cooldown and power cooldown.
- `controlled-rope.png`: clearly labeled controlled source fixture; gold board
  ring, mint route and floor separation visibly inspected.
- `controlled-powers.png`: clearly labeled event fixture; five bounded native
  activation silhouettes visibly inspected.

Live first-person shots do not clearly frame the rope behind/below the rider;
the live native node/authoritative ride witnesses and the separate controlled
visual capture serve different evidence purposes. Initial `live/` screenshots
are retained and show the corrected READY/cooldown ambiguity.

### Commands

```sh
node port/next-port/gameplay/catalog.mjs
node port/next-port/gameplay/fixtures.mjs
COCS_SOURCE_DERIVATIVE=port/contracts/lattice-catalog-derivative.json \
  node tools/godot-export/semantic.mjs godot/content/generated
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot \
  --script res://player_gameplay/test.gd
LP_NUM_THREADS=1 LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a "$GODOT_BIN" \
  --audio-driver Dummy --path godot --script res://tests/combat_actions/controls.gd
LP_NUM_THREADS=1 LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a "$GODOT_BIN" \
  --audio-driver Dummy --path godot --script res://tests/campaign/session.gd
GODOT_BIN="$GODOT_BIN" EVIDENCE_DIR="$EVIDENCE/live-final" \
  node port/next-port/gameplay/live.mjs
node --test game/movement.test.mjs game/operator-verbs.test.mjs game/ability-vfx.test.mjs
```

Pinned engine used:
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.
All engine runs were serial with `LP_NUM_THREADS=1`; visual runs used Mesa
llvmpipe through Xvfb. No Blender or nested agents were used.

### Retained failed attempts / limitations

- Initial strict semantic export refused the already-reviewed derivative.
  `semantic.log` preserved; rerun with the existing derivative manifest passed.
- Initial graphical runs attempted ALSA before falling back to Dummy; final
  journeys explicitly request Dummy and contain no script/engine errors.
- Headless legacy combat-controls run failed capture assertions because it needs
  a real window; windowed rerun passed. Original log is preserved.
- The existing controls and campaign test scripts report two GL texture leaks
  at teardown despite passing assertions. These scripts do not instantiate the
  new adapter in their detached session probes. No clean-teardown claim is made
  for those two legacy scripts; live-final journeys and new unit tests are clean.

Parent gates: merge the scoped session hook, integrate EXPERIENCE's status model
if desired, then run canonical/platform exports and the combined release suite.
Current batch has no dependency on the sibling MODES or WORLD changes.

**ENGINE SLOT RELEASED** after the serial acceptance runs; remaining lane work
was documentation and commit only.
