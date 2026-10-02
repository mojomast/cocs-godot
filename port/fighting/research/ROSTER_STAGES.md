# ROSTER & STAGES — fighting-mode research

**Status:** research only. No runtime code was written or is proposed to land from
this branch until the research parent approves. This is the single deliverable of
the worktree `/home/mojo/.tmp-on-disk/cocs-fighting-research-roster-20261002`
(branch `fighting/research-roster-20261002`, base `ffcd7216`).

**Question answered:** for a distinct local fighting mode, what is the *actual,
complete* current operator roster, what fighting stat/movelist proposal does each
operator support from real code, and which existing maps are the best-looking
stage candidates evidenced by actual rendered images?

**Hard constraints honoured:** no nested agents; no heavy Helix/Foundry process;
no reads/writes of the active feature/integration lanes; no IP assets, move names
or character names copied from other fighting games; the only committed artifact
is this file.

---

## 0. Source-verified counts (short version)

Do **not** assume 4 or 6 classes. The current roster is:

| Thing | Count | Authority |
|---|---:|---|
| Operators (classes) | **9** | `game/data.mjs` `CHARACTERS`; `game/kits.mjs` `OPERATOR_KITS` (`kits.test.mjs:37` asserts 9) |
| Harnesses (specs) | **7** | `game/data.mjs` `HARNESSES`; `game/kits.mjs` `SPECS` |
| Ordered operator×harness pairs | **63** | `CHARACTERS.length × HARNESSES.length`; `kits.test.mjs:268`, `class-ui.test.mjs:157` |
| Valid loadouts (Claude lock) | **57** | `validLoadout` in `game/data.mjs:62`; Claude is locked to `claudecode`, so `63 − 6 = 57` |
| Weapons | **10** | `game/data.mjs` `WEAPONS`; `game/weapon-models/index.mjs` `WEAPON_BUILDERS` |
| Signature verbs (always-on class verbs) | **9** | `game/operator-verbs.mjs` `OPERATOR_VERBS` |
| Movement verbs | **9** | `game/kits.mjs` `MOVEMENT_VERBS` |
| Harness actives | **7** | `game/harness-profiles.mjs` `HARNESS_PROFILES` |
| Source operator GLB rigs | **9 + 10 weapons** | `godot/source_operators/generated/manifest.json`, `.../world_weapons/` |
| Godot native DM arenas | **8** | `godot/native_arenas/catalog.gd` `DM_MAP_IDS` |
| Web multiplayer maps | **41** | `docs/evidence/phase1/maps/manifest.json` (label: "from actual MAPS registry") |
| Campaign chapters (biomes) | **4** | `godot/campaign/generated/{rootfall-verge,siltwake-crossing,emberline-ascent,crown-array}.json` |
| New Blender maps | **3** (1 proof, 2 not art-accepted) | `port/new-maps/WORKSTREAM.md` |

Verified by execution during this audit:

```
operators 9 harnesses 7 pairs 63 validLoadout 57 lockedOut 6
OPERATOR_KITS 9
op ids chatgpt,claude,grok,meta,gemini,deepseek,mistral,kimi,qwen
resolveKit claude+openclaw -> claude / claudecode : alignment-review : safety-glide : buff
```

Enemy robots (`game/enemy-types.mjs`, 12 roles: husk/spitter/brute/warden/mender/
sapper/overseer/bulwark/mortar/lancer/sentinel/harbinger) are **not** operators and
are out of scope for the playable roster.

---

## 1. Exact operator catalogue (identity, class, rig, silhouette)

All nine ids, names, stats and colours are read verbatim from `game/data.mjs`
(`CHARACTERS`, lines 1–11). Class/wing, role, movement verb, signature verb and
weapon-affinity band are read from `game/kits.mjs` (`OPERATOR_KITS`, lines 118–233)
and `game/operator-profiles.mjs`. Distant-silhouette authoring is read from
`game/operator-anatomy.mjs` (`OPERATOR_ANATOMY`); close-up hard-surface authoring
from `game/operator-detail.mjs` (`styles` map, line 10). Rig metrics are read from
`godot/source_operators/generated/manifest.json`.

| ID | Name | Wing / role | Src HP/AR/SPD | Movement verb (input) | Signature verb | Preferred band (idx) | Anatomy design (`OPERATOR_ANATOMY`) | GLB rig | LOD0 tris / draws | Bind height | Width |
|---|---|---|---|---|---:|---:|---:|---:|
| `mistral` | Mistral | Striker / flanker | 112/0/9.2 | Air Dash (`jump`) | **Effortless** | Scatter 3, Flak 7, SMG 9 | swept aerofoil interceptor | `godot/source_operators/generated/mistral.glb` | 28,080 / 67 | 1.828 m | 0.953 m |
| `gemini` | Gemini | Striker / duelist | 100/10/9.0 | Double Jump (`jump`) | **Revision** | Scatter 3, Rail 2, Marksman 8 | bifurcated ceramic anatomy | `.../gemini.glb` | 29,960 / 68 | 1.793 m | 0.931 m |
| `grok` | Grok | Striker / disruptor | 110/0/8.9 | Super Jump (`crouch`) | **Heat** | Rocket 1, Grenade 5, Plasma 4 | asymmetric industrial outrider | `.../grok.glb` | 29,284 / 68 | 2.034 m | 0.932 m |
| `deepseek` | DeepSeek | Vanguard / ambusher | 126/0/7.7 | Hover Jets (`jump-hold`) | **Deep Compute** | Grenade 5, Plasma 4, Marksman 8 | pressure-vessel salvage frame | `.../deepseek.glb` | 29,400 / 71 | 1.891 m | 0.934 m |
| `meta` | Meta | Vanguard / connector | 104/20/7.6 | Brace Slam (`crouch-jump`) | **Braced** | Plasma 4, Shock 6, Rocket 1 | twin-turbine heavy chassis | `.../meta.glb` | 31,184 / 71 | 1.802 m | 0.988 m |
| `claude` | Claude | Vanguard / anchor | 120/10/7.8 | Safety Glide (`jump-hold`) | **Alignment Review** | Rail 2, Shock 6, Marksman 8 | ceramic warding chassis | `.../claude.glb` | 27,972 / 72 | 1.802 m | 0.961 m |
| `chatgpt` | ChatGPT | Tactician / adaptive | 100/5/8.6 | Grapple (`mobility`) | **Adaptive** | Pulse 0, Plasma 4, Marksman 8 | split-cage survey instrument | `.../chatgpt.glb` | 30,708 / 69 | 1.956 m | 0.932 m |
| `kimi` | Kimi | Tactician / orbiter | 90/10/8.7 | Blink Step (`mobility`) | **Long Context** | Shock 6, Pulse 0, Rail 2 | orbital gimbal reactor | `.../kimi.glb` | 31,872 / 69 | 1.956 m | 0.981 m |
| `qwen` | Qwen | Tactician / optimizer | 108/10/8.5 | Deployable Rope (`mobility`) | **Tool Use** | Pulse 0, Rail 2, SMG 9 | lamellar mechanical sentinel | `.../qwen.glb` | 28,760 / 70 | 1.956 m | 0.926 m |

Source paths (all inside this worktree):

- `game/data.mjs` — `CHARACTERS` (stats, colour, accent, tag, detail) and `HARNESSES`.
- `game/kits.mjs` — `WINGS`, `MOVEMENT_VERBS` (budgets), `OPERATOR_KITS`
  (role, `preferred` 3-weapon band, `strafe`, `verb`, `bot`, `affinity`).
- `game/operator-profiles.mjs` — compatibility shim; the legacy 2-weapon pair is
  `preferred.slice(0,2)`, roles are unique across the nine.
- `game/operator-verbs.mjs` — the nine signature verbs (`OPERATOR_VERBS`).
- `game/operator-anatomy.mjs` / `game/operator-detail.mjs` — per-id silhouette.
- `godot/source_operators/operator_visual.gd` + `godot/source_operators/generated/`
  — actual imported rigs, one `.glb` per id plus `manifest.json` provenance.
- `godot/player_models/recipes.json` — a *fallback* faceted builder with only
  three variants (`claude`, `grok`, `meta`); not the production roster.

### Distinct silhouettes vs classes — verified

Nine distinct anatomy designs, chest styles, limb families, widths, waists, depths
and shoulder envelopes in `OPERATOR_ANATOMY`; nine distinct close-up styles in
`operator-detail.mjs`. Within a wing operators share engagement band and movement
family by design (`docs/design/OPERATORS_AND_HARNESSES.md`), but the silhouettes
are individually authored. Bind heights (manifest) already differ by 0.24 m across
the roster (1.793 m Gemini → 2.034 m Grok) and widths by 0.062 m (Qwen 0.926 m →
Meta 0.988 m); because no anatomy is scaled to fit a nominal 1.8 m body
(`port/native-source-operators/README.md` §Export fidelity), those proportions are
real, not cosmetic. This is enough to read classes at fighting-camera distance
without nine bespoke models.

---

## 2. Harness (spec) catalogue — one active each

Read from `game/data.mjs` `HARNESSES` and `game/harness-profiles.mjs`. A harness is
*worn by* an operator in the shooter; in a fighting proposal it is the **EX/super
layer** the operator carries (see §4–5). Claude is locked to `claudecode`.

| Harness | Active (`Q`) | Kind | Magnitude | Tradeoff passive (`kits.mjs` `SPECS.passive`) |
|---|---|---|---|---|
| OpenClaw | Claw Burst (6 m, 30 dmg, knockback 14) | burst | 14 | Grip — melee arc +25% |
| Hermes | Courier Rush (1.6× speed, 3.5 s) | buff/speed | 1.6 | Express — sprint while reloading |
| OpenCode | Parallel Burst (1.82× fire rate, 3.5 s) | buff/fireRate | .55 | Multiplex — reload continues while swapped |
| Claude Code | Guardrail (50% resistance, 3.5 s) | buff/resistance | .5 | Linted — threat ping on bead |
| Codex | Recompile (+45 HP) | heal | 45 | Green Build — reload 15% faster |
| Cline | Phase Step (7 m dash, .35 s) | dash | 7 | Off-road — extra air control, longer slide |
| Roo Code | Context Jam (8 m, 50% slow, 3 s) | slow | .5 | Flood Fill — ability radius +25%, damage −5% |

---

## 3. Roster coverage & distinction matrix

### 3.1 Wing coverage (9/9)

| Wing | Operators | Movement family | Shared domain | Pays with |
|---|---|---|---|---|
| Strikers | Mistral, Gemini, Grok | burst | close/mid fights, flanks, rotations | sustain, range |
| Vanguards | DeepSeek, Meta, Claude | deliberate | holding space, attrition | tempo/escape, range |
| Tacticians | ChatGPT, Kimi, Qwen | tool | long range, info, objectives, vehicles | single-axis dominance |

### 3.2 Operator × harness (57 valid of 63)

Every operator resolves all seven harnesses except Claude, which redirects to
`claudecode` (`resolveKit('claude','openclaw') → claude/claudecode`, verified).
Each valid pair yields exactly one wing rider from the 21-row rider table
(`game/kits.mjs` `SPECS.rider`, `class-ui.test.mjs:143`). For a fighting mode the
EX layer therefore covers **9 × 7 = 63** move slots, of which 57 are legal; the
six Claude×non-Claude pairs collapse to Claude Code.

### 3.3 Unique FX identity (source tints)

`game/ability-vfx.mjs` owns two palettes; both are read from operator data, not
invented:

- Wing colours (`kits.mjs` `WINGS`): Striker `#ff9d5c`, Vanguard `#57b9ff`,
  Tactician `#b797ff`.
- Nine verb tints (`VERB_TINTS`): Effortless `#ffbd59`, Revision `#fff0c3`,
  Heat `#ff8b4d`, Deep Compute `#56c5f2`, Braced `#57b9ff`, Alignment Review
  `#f29d71`, Adaptive `#57e6cd`, Long Context `#ff82b2`, Tool Use `#b797ff`.
- Seven harness tints (`HARNESS_TINTS`) for the EX layer.

This gives a fighting HUD a ready, per-operator two-colour language without new
art direction: **wing colour for the health/portrait frame, verb tint for the
meter and strike trails.**

---

## 4. Proposed fighting stat matrix

**How to read it.** This translates the *actual* shooter numbers, not new ones.
The fighting bar is `fightHP`, computed as a bounded rescale of source effective
health `HP + AR` (data.mjs) so the roster keeps its real 1.30× EHP span:

`fightHP = round(9000 + 800 × (EHP − 100) / 26)`, EHP span 100 (Kimi/Gemini=110
with armour) → 126 (DeepSeek). `walk` is the source speed (m/s). `jump` is the
milestone from `RULES.jump=8.6`, `RULES.gravity=26` (apex ≈ 1.42 m) modified by the
class movement verb (`kits.mjs` `MOVEMENT_VERBS` budgets). `weight` (1 light →
10 immovable) is a normalised knockback resistor from EHP plus authored chassis
bulk (`OPERATOR_ANATOMY` width/waist). `reach` (1 short → 10 longest) is the
longest range in the 3-weapon affinity band (`WEAPONS.range`). `meter` is the
class resource and how the signature verb builds/spends it.

| ID | fightHP | walk | jump | weight | reach | meter (gain → payoff) | Archetype |
|---|---:|---:|---:|---:|---:|---|---|
| mistral | 9,369 | **9.2** | high (air dash) | **3** | 4 | Tempo: air-time/dash cancels → extra strings | Rushdown / mixup |
| gemini | 9,308 | 9.0 | high (double jump) | 4 | 7 | Band: land both primaries → stance switch EX | Stance duelist |
| grok | 9,308 | 8.9 | **highest** (super jump) | 5 | 7 | Heat: hits build up to +16% rate → long strings | Rushdown / setplay |
| deepseek | **9,800** | 7.7 | very high (hover) | 8 | 8 | Compute: charge → one heavy launcher | Heavy zoner |
| meta | 9,738 | 7.6 | mid (brace slam) | **10** | 6 | Braced: armor regen, crouch halves pushback | **Grappler** |
| claude | 9,615 | 7.8 | low (glide) | 9 | **10** | Review: hold ground → absorb-super | Zoner / footsie |
| chatgpt | 9,154 | 8.6 | mid (grapple) | 5 | 6 | Adaptive: fast swap → confirm any button | All-rounder |
| kimi | **9,000** | 8.7 | high (blink) | 3 | 9 | Context: land long pokes → radar-super | Zoner / teleport |
| qwen | 9,246 | 8.5 | mid (rope) | 6 | 6 | Tool: rope/pickup charges → OTG super | Grappler / setplay |

**Meaningful tradeoffs (design intent, not a balance claim):**

- **Mistral/Kimi** are the fragile extremes (weight 3): lose trades, win neutral
  through movement (air dash) and reach (blink + Shock/Rail).
- **DeepSeek/Meta** are the immovable anchors (weight 8/10, fightHP top two):
  slowest, best at holding a corner, poorest at escaping pressure.
- **Claude** is the longest-range zoner (reach 10) with the smallest jump and a
  retreat glide; Meta/DeepSeek close that gap with armour.
- **Grok** has the highest jump and a hit-built meter, so he snowballs but has no
  defensive resource; this mirrors `HEAT` decay (`operator-verbs.mjs`).
- **Gemini** is the only two-band stance, matching `REVISION` (two primaries, zero
  holster); it is the highest execution ceiling but low weight.
- **ChatGPT** is the honest all-rounder (no best axis), matching the design doc's
  "no bad matchup, nothing best-in-class".
- **Qwen** trades raw damage for rope/stage control and the longest melee envelope
  (+15% reach in the source `TOOL_USE`), making it the setplay grappler.

> Note: `docs/design/OPERATORS_AND_HARNESSES.md` lists a *planned* re-cut of
> HP/AR/SPD pending sign-off. This research uses the **current, code-authoritative**
> numbers in `game/data.mjs`; the planned numbers are not yet in data and must not
> be treated as shipped.

---

## 5. Per-operator fighting movelist proposal

**Universal fighting controls** reuse the shipped remappable bindings
(`game/keybinds.mjs` `DEFAULT_BINDINGS`) so no new input surface is needed:

| Fighting action | Shipped bind | Notes |
|---|---|---|
| Light strike | LMB | press = strike |
| Medium strike | **RMB tap** | hold = guard (reuses ADS) |
| Heavy strike | `KeyF` | reuses melee |
| Special 1 (projectile) | `KeyG` | reuses grenade |
| Special 2 (mobility/grapple) | `KeyX` | reuses mobility verb |
| Special 3 (throw/command grab/EX) | `KeyQ` | reuses harness power |
| Jump / crouch / dash | `Space` / `KeyC` / `Shift` | unchanged |
| Guard (hold) | RMB | high guard; `KeyC`+RMB = low guard |

Input model to implement later (not now): a short directional buffer plus
cancel windows, with press **and** release accepted for specials (negative-edge)
and a documented buffer length. References in §11. This is the accessibility
path: buffered cancels + release-inputs lower execution so combos are not
frame-perfect.

Below, `S1` is the projectile special, `S2` the mobility/grapple special, `S3`
the throw/command-grab/EX special. Move names are original to this project and
describe the operator's own source verb/weapon; no external fighter is imitated.

### 5.1 Mistral — Swept Aerofoil (Rushdown / mixup)

- Identity: `mistral`, Striker/flanker, Effortless, Air Dash, amber `#ffbd59`.
- Normals: **L** scatter snap jab · **M** lunging roundhouse · **H** rising spin
  kick (launcher). Strings: `L-L-M`, `cM-H`, `Air-Dash → aM-aH`.
- **S1 Flak Fan** — short 12-shard fan (Flak Cannon 12 pellets, `.19` spread).
- **S2 Air Dash** — burst dash (charges 1, 6 m, 2.2 s cd); cancels into air normals.
- **S3 Slide Takedown** — low slide (Effortless slide bonus) into throw.
- Combos: `L-L-M ×S2 > aM-aH` · `cM ×S1` · `S2 crossup > L-M > S3`.
- FX theme: amber dash ribbon + wing orange; meter = dash charges.

### 5.2 Gemini — Bifurcated Ceramic (Stance duelist)

- Identity: `gemini`, Striker/duelist, Revision, Double Jump, cream `#fff0c3`.
- Normals: **L** split-hand jab · **M** twin claw cross · **H** rail palm launcher.
- **S1 Rail Lance** — piercing charge shot (Rail 82 dmg, 90 m).
- **S2 Double Jump** — impulse 7.8; enables an aerial rave.
- **S3 Revision Grab** — swaps the active band on grab (Scatter ⇄ Rail).
- Strings: `L-M-H`, `aM-aH`, `Band-A L-M ×S3 > Band-B H`.
- Combos: `L-M ×Swap > H` · `S2 > aL-aM ×S1` · `S3 > H > aL-aM-aH`.
- FX theme: cream petal flash, two-band meter (one pip per primary).

### 5.3 Grok — Asymmetric Outrider (Rushdown / setplay)

- Identity: `grok`, Striker/disruptor, Heat, Super Jump, orange `#ff8b4d`.
- Normals: **L** hook jab · **M** piston elbow · **H** overhead hammer (launcher).
- **S1 Arc Grenade** — bouncing grenade (Grenade 3.0 s life) that sets up pressure.
- **S2 Super Jump** — impulse 12.5, 0.45 s windup, 5 s cd; a commitment.
- **S3 Rocket Tackle** — Heat body-slam command grab.
- Strings: `L-L-M`, `cM-M`, `S1 > dash > L-M-H`.
- Combos: `L-L-H ×Heat` · `S1 > S2 > aH` · `S3 > cM > S1`.
- FX theme: orange heat glow that brightens with the Heat meter.

### 5.4 DeepSeek — Pressure Vessel (Heavy zoner)

- Identity: `deepseek`, Vanguard/ambusher, Deep Compute, Hover Jets, cyan `#56c5f2`.
- Normals: **L** sleeve jab · **M** pressure wave · **H** diving elbow launcher.
- **S1 Deep Compute Shot** — charged plasma; single-hit cap 90 (source invariant).
- **S2 Hover Jets** — bounded 3 s fuel hover (climb .35, descent 2.2).
- **S3 Vessel Crush** — command grab with armour.
- Strings: `L-M-H`, `cH`, `S2 > aM-aH`.
- Combos: `L-M ×S1(charge)` · `S3 > H > S1` · `S2 > aM-aH`.
- FX theme: cyan charge bloom that grows with the compute meter.

### 5.5 Meta — Twin Turbine (Grappler)

- Identity: `meta`, Vanguard/connector, Braced, Brace Slam, blue `#57b9ff`.
- Normals: **L** turbine jab · **M** plating shoulder · **H** ground-slam launcher.
- **S1 Shock Beam** — short anti-air beam (Shock 52 m).
- **S2 Brace Slam** — radius 4.5, knockback 10, 7 s cd; a slow, walling drop.
- **S3 Twin Grab** — command throw; Braced halves pushback while crouching.
- Strings: `L-cM-H`, `cL-cM-cH`, `S2 > L > cH`.
- Combos: `cM ×S1` · `S3 > H > S2` · `S2 corner > cL-cH`.
- FX theme: blue plating glint + armour-regrow shimmer.

### 5.6 Claude — Ceramic Warding (Zoner / footsie)

- Identity: `claude`, Vanguard/anchor (locked Claude Code), Alignment Review,
  Safety Glide, salmon `#f29d71`.
- Normals: **L** ward jab · **M** chevron shield bash · **H** rail lance launcher.
- **S1 Long Rail** — Rail/Shock at 52–90 m; the roster's longest poke.
- **S2 Safety Glide** — descend 1.7, steer 4.5; disengage, not escape.
- **S3 Review Absorb** — counter-throw; builds the ~45 HP absorb pool.
- Strings: `L-cM-S1`, `M-H`, `S2 > aL`.
- Combos: `L-cM ×S1` · `S1(EX) > M-H` · `S3 > H > aL`.
- FX theme: salmon review pips filling to the absorb super.

### 5.7 ChatGPT — Split-Cage Survey (All-rounder)

- Identity: `chatgpt`, Tactician/adaptive, Adaptive, Grapple, teal `#57e6cd`.
- Normals: **L** survey jab · **M** cage swing · **H** plasma uppercut launcher.
- **S1 Survey Orb** — Pulse/Plasma mid projectile (65–70 m).
- **S2 Grapple** — 14 m reel, 6 s cd; pull-in or route.
- **S3 Adaptive Throw** — fast-swap command grab.
- Strings: `L-M-H`, `S2 > M-H`, `cM-H`.
- Combos: `L-M-H ×S1` · `S2 pull > M-H` · `L-cM ×S1 > S3`.
- FX theme: teal adaptive frame that recolours on swap.

### 5.8 Kimi — Orbital Gimbal (Zoner / teleport)

- Identity: `kimi`, Tactician/orbiter, Long Context, Blink Step, pink `#ff82b2`.
- Normals: **L** gimbal jab · **M** orbital ring poke · **H** shock launcher.
- **S1 Shock Rail** — longest-hitting beam (Shock 52 / Rail 90).
- **S2 Blink Step** — 6 m, 0.25 s windup, 5 s cd; the only in-place teleport.
- **S3 Context Grab** — command throw that leaves a radar trail.
- Strings: `L-cM-H`, `S1-S1`, `S2 > aM`.
- Combos: `L-M ×S1` · `S1(EX) > M-H` · `S3 > H > S1`.
- FX theme: pink radar trails (Long Context ttl ≤1.5 s).

### 5.9 Qwen — Lamellar Sentinel (Grappler / setplay)

- Identity: `qwen`, Tactician/optimizer, Tool Use, Deployable Rope, violet `#b797ff`.
- Normals: **L** lamellar jab · **M** rope-guided strike · **H** sentinel launcher;
  +15% melee reach (source `TOOL_USE`).
- **S1 Pulse Rail** — Pulse/Rail mid-long (70–90 m).
- **S2 Deployable Rope** — anchor life 20 s, 10 s cd; stage control / pull-in.
- **S3 Tool Throw** — command grab with the longest envelope.
- Strings: `L-cM-H`, `S2 > aH`, `cL-cM-S1`.
- Combos: `L-cM ×S1` · `S3 > H > S1` · `S2 anchor > aH > S3`.
- FX theme: violet rope channel + tool-window spark.

---

## 6. Clip requirements (pair-unique clips)

The source animation vocabulary already exists and must be extended, not replaced:
`game/character-anim.mjs` exposes stride/phase, crouch, ADS, strafe, reload, hit,
land, slide, bank, accel, lateral, plus `deathLimbPose`; the Godot rig
(`godot/source_operators/operator_visual.gd`) consumes grounded/crouch/ADS/reload/
slide/aim and shot-delta recoil. Fighting clips should be authored as additive
layers on the same `CharacterRig` (31 retained nodes per operator, manifest).

### 6.1 Shared clips (one implementation, all nine)

`idle`, `walk-f`, `walk-b`, `crouch`, `jump-rise`, `jump-apex`, `jump-fall`,
`land`, `hitstun`, `blockstun-hi`, `blockstun-lo`, `knockdown`, `wakeup`,
`dash-f`, `dash-b`, `guard-break`, `win`, `lose`. These come from the existing
locomotion/hit/land/slide channels and do not need per-operator animation.

### 6.2 Unique clips per operator (guard stance + strikes + movement vocab)

Each operator must supply **one guard stance**, a **three-strike set**, and a
**movement set** matching its anatomy and movement verb. The requirements:

| Operator | Guard stance (unique) | Strike set (unique) | Movement vocab (unique) |
|---|---|---|---|
| mistral | low aerodynamic guard | 3-hit scatter/flak string finisher | air-dash, slide-hop, hop-cancel |
| gemini | two-band alternation guard | split-claw 3-string, per-band finisher | double-jump, band-swap pose |
| grok | forward brawler guard | hook/elbow/hammer 3-string | super-jump charge, heat flare |
| deepseek | pressure-braced guard | sleeve/pressure/dive 3-string | hover-jets, heavy stomp |
| meta | anchor squat guard | turbine/plating/slam 3-string | brace-slam, armour-step |
| claude | ward-forward guard | jab/bash/lance 3-string | safety-glide, absorb brace |
| chatgpt | survey neutral guard | jab/swing/uppercut 3-string | grapple reel, adaptive swap |
| kimi | orbital open guard | jab/ring/poke 3-string | blink-step, trail pose |
| qwen | sentinel stance guard | jab/rope-strike/launcher 3-string | rope anchor, tool-use step |

### 6.3 Special/EX clips

Each operator additionally needs `S1`, `S2`, `S3` (and `S1-EX`) clips; the EX
variant reuses the operator's harness active as a super (e.g. Meta's EX =
Guardrail absorb; Qwen's EX = Climb Burst radius). That is 4 clips × 9 = 36
special clips, reusable across the 7 harnesses by tinting with `HARNESS_TINTS`
and the operator's verb tint.

---

## 7. Stage research — actual images and ranking

### 7.1 Method and evidence sources

- **Latest 12-hour gallery manifest (9,648 unique images):**
  `/home/mojo/.tmp-on-disk/cocs-screenshot-gallery-20261002-1229/manifest.json`
  (summary: `/home/mojo/.tmp-on-disk/cocs-screenshot-gallery-20261002-1229/summary.json`).
- **Original map-art/acceptance evidence:** `docs/evidence/phase1/maps/manifest.json`
  plus the 41 `docs/evidence/phase1/maps/<id>-overview.png` renders and matching
  `-metrics.json` measurement files. The manifest explicitly labels these
  captures "Captured; not ground-level visual or balance approval".
- **Original biome previews (actually committed to this worktree):**
  `port/biome-upgrade/previews/canopy-divide-{vista,valley}.jpg`,
  `port/biome-upgrade/previews/basalt-reach-{vista,valley}.jpg`.
- **Campaign biome gameplay:** gallery group `relay-campaign-20260930`.
- **New-map review:** gallery groups `new-map-conservatory-evidence-20261002`,
  `new-map-observatory-evidence-20261002`, `new-map-foundry-evidence-20261002`.

All images named below were **opened and inspected** during this audit (contact
sheets plus full-res individual reads), not merely listed.

### 7.2 Acceptance status of each candidate (read from source, not assumed)

- Original biome arenas `canopy-divide` / `basalt-reach`: playable native DM
  (`godot/native_arenas/catalog.gd` `DM_MAP_IDS`), previewed in
  `port/biome-upgrade/README.md`; **accepted for native deathmatch**, human
  competitive balance still noted as pending.
- Campaign chapters: integrated on `feature/relay-campaign`
  (`port/campaign/WORKSTREAM.md`); four distinct footprints and biome assets.
- **Parallax Observatory:** architecture + native proof at `9a6372b4`; current
  HEAD `3e9bf9e5` is a **source-only interior-differentiation (cosmetic) revision**
  and is **pending** art review. Proof assets: 148,239 GLB triangles, 7 batches,
  3,563 shape nodes / 4,686 collision triangles, geometry `906be2ae…`.
- **Helix Conservatory:** functional checkpoint `becef6b4` was **not** accepted on
  the architectural brief; revision 2 `4c486a9e` (137,928 recipe triangles, 10
  materials, 22 batches) is **NOT art accepted** and has had no Blender/import/art
  run.
- **Gravemill Foundry:** functional `afbe57dc` proof accepted, but the
  architectural revision (rev 3 `8d248904`) **NOT art accepted**; 66,284 triangles,
  8 batches, 2,808 collision triangles.
- Original Web multiplayer phase-1 renders are **not** visual approval.

### 7.3 Ranked candidates (best-looking first)

Evidence image paths are absolute; `…/images/<sha>.png` is the gallery copy and
the label is the original source file.

| # | Candidate (crop) | Actual image inspected | What the image shows | Acceptance | Background cost |
|---|---|---|---|---|---|
| 1 | **Helix Conservatory — lightwell** | `/home/mojo/.tmp-on-disk/cocs-screenshot-gallery-20261002-1229/images/ebeb729eb01def4f7c6a56b826612422c90af2c009db8c5db271d3b0a258662e.png` (`inspection-final/lightwell-eye.png`) | Bright glazed dome, teal/white ribs, green planters, broad polished floor, symmetrical bowl — the cleanest flat fight plane + true background of any candidate | rev2 `4c486a9e` **NOT art accepted** | planned 137,928 tri / 10 mat / 22 batches |
| 1b | Helix Conservatory — seed archive portal | `…/images/2155be255f8d7c366f50e203d214d4fc476629b5f2df307b3ec72fca663530db.png` (`inspection-final/archive-portal-eye.png`) | Green-topped `SEED ARCHIVE` portal over a broad floor; strong framed entrance for an arena | same | same |
| 2 | **Gravemill Foundry — cooling nave** | `…/images/69048343c4a78cc242bb196b19469d29bfe176c6b22c202b0442716e1e2377f4.png` (`native-final-views/cooling-eye.png`) | Grand dark arched nave, gold ceiling ribs, machinery drum, long central floor — dramatic industrial stage | functional `afbe57dc`; rev3 `8d248904` **NOT art accepted** | 66,284 tri / 8 batches; 2,808 collision tri |
| 3 | **Parallax Observatory — archive arcade** | `…/images/923deacb64469ac2097096bd02a233d042bbbbdc3413b34fbf18e7e5c88b1562.png` (`native-review/archive-interior.png`) | Long blue/white colonnade with gold ceiling ribs and a framed far opening — clean sightlines, very stage-like | native proof `9a6372b4`; cosmetic `3e9bf9e5` pending | 148,239 tri / 7 batches; 4,686 collision tri |
| 3b | Parallax Observatory — lens court | `…/images/6eb1a603af7a736fc3dbb5ae3782165402ca8ab916897a091d90a5b971b57393.png` (`native-review/lens-eye.png`) | Big faceted telescope dome over a broad pale court | same | same |
| 4 | **Basalt Reach — canyon channel** | `port/biome-upgrade/previews/basalt-reach-vista.jpg` + `basalt-reach-valley.jpg` (worktree) | Sunlit basalt canyon with a blue water channel, sandstone shelves, sparse scrub and relay gantries; open and readable | accepted native-dm biome | 3,840 terrain tri + MultiMesh scenery |
| 5 | **Canopy Divide — fern ravine** | `port/biome-upgrade/previews/canopy-divide-vista.jpg` + `canopy-divide-valley.jpg` (worktree) | Lush green ravine, moss/soil/gravel/rock, branching trees and ferns; flat clearings between ridge circuits | accepted native-dm biome | 3,840 terrain tri + MultiMesh scenery |
| 6 | **Campaign — Rootfall Verge** | `…/images/292cab5e597b604276a6d7d6ee0cbd5c54d60ba70b4d26e703544bf62d7b8752.png` (`experience-campaign/ability.png`), `…/images/2a8682e06052c4ac0463e384616a6c8bf7e378572a7bb65615f9bb126b21a3c6.png` (`muted-fire.png`) | First-person forest ravine, big trunks, green floor, visible operator and enemy — a genuine in-engine biome render | accepted campaign (relay) | Rootfall 8,960 terrain tri (WORLDS.md) |
| 7 | **Campaign — Crown Array** | `…/images/a902f708240490ff342f1ce68666fdf94e22c2abf9c1e974e832fac362226e59.png` (`crown-array-compact/gameplay.png`) | Highland/service court: light structures, green ground, an enemy robot and the player weapon; one of the four campaign biomes | accepted campaign (relay) | Crown 14,976 terrain tri |
| 8 | **Campaign — Siltwake Crossing** | `…/images/8d6e540964ce7520754fff71a8425020919df38873fc368b357a0c7812332c92.png` (`weather-campaign/round-two-weather.png`), `…/images/08f93fa9c200bc274cbb9a996bee415d7a5b7890c90b2b2e6775bc69dbed1888.png` (`recovered.png`) | Wide tan canyon riverbank with a lone robot on an open flat; strongest "arena bowl" flatness of the campaign biomes | accepted campaign (relay) | Siltwake 11,264 terrain tri |
| 9 | **Blood Gulch — central bowl** | `docs/evidence/phase1/maps/blood-gulch-overview.png` (50,296 tri / 394 calls) | Teal-sky box canyon, flat green centre, symmetric bases — clean, readable original MP backdrop | phase-1 capture, not visual approval | 50,296 tri / 394 draws |
| 10 | Exchange — reactor deck | `docs/evidence/phase1/maps/exchange-overview.png` (20,122 tri / 145 calls) | Dark blue neon arena, central reactor + raised deck; strong identity but a cluttered centre | phase-1 capture, not visual approval | 20,122 tri / 145 draws |
| 11 | Ember Caldera — caldera ring | `docs/evidence/phase1/maps/ember-caldera-overview.png` (45,070 tri / 166 calls) | Dark volcanic octagon arena with red glow; dramatic but low-key lighting | phase-1 capture, not visual approval | 45,070 tri / 166 draws |
| 12 | Longreach Plateau | `docs/evidence/phase1/maps/longreach-plateau-overview.png` (49,870 tri / 838 calls) | Blue-grey plateau with scattered structures; flat but visually plain | phase-1 capture, not visual approval | 49,870 tri / 838 draws |

Also inspected and deliberately **rejected** as initial stages: Foundry foundry
`native-final-views/overview.png` (flat grey), Conservatory `overview.png`
(sparse concentric terraces, the exact brief failure at `becef6b4`), Observatory
`native-review/pump-interior.png` (dark tunnel), and the `blender-*` sets under
both new-map groups (1.7–2.0 MB review renders; visually identical family to the
native ones).

### 7.4 Recommended initial stages (3–5)

Respecting the acceptance note above, the initial slate uses only **accepted or
near-accepted** art. Two high-look candidates are held as conditional.

1. **Basalt Reach — canyon channel floor** (original biome; accepted native-dm).
2. **Canopy Divide — fern ravine floor** (original biome; accepted native-dm).
3. **Parallax Observatory — archive arcade court** (new map; native proof
   `9a6372b4` accepted; cosmetic revision `3e9bf9e5` pending — use the proof GLB
   until the cosmetic revision is reviewed).
4. **Campaign — Crown Array guardian court** (accepted campaign biome; compact
   service court gives the flattest campaign plane).
5. **Blood Gulch — central bowl** (original multiplayer; flat symmetric centre,
   low cost 50,296 tri / 394 draws; note phase-1 capture is not visual approval).

**Conditional / hold for art gate (do not schedule as initial):**
- **Helix Conservatory — lightwell** (looks best; rev2 `4c486a9e` NOT art
  accepted).
- **Gravemill Foundry — cooling nave** (looks strong; rev3 `8d248904` NOT art
  accepted).

**Reserve:** Rootfall Verge, Siltwake Crossing, Emberline Ascent, Exchange,
Ember Caldera, Longreach Plateau, Observatory lens court.

### 7.5 Stage crop specification (own physics bound, not inherited)

Every fighting stage is a **self-contained crop** of the chosen map, not the
multiplayer map with its ramps. Requirements for the later implementation:

- **Fight plane.** Convex octagon, half-extents 14 m × 9 m, 2.5 m chamfers:
  `(-11.5,-9) (11.5,-9) (14,-6.5) (14,6.5) (11.5,9) (-11.5,9) (-14,6.5) (-14,-6.5)`.
  This is the only collider for the fight mode; its Y is a single sampled plane
  (flat), and it replaces the map's terrain/ramp collision entirely.
- **Walls.** A double-sided 1.5 m ring wall at the crop boundary (both faces
  collide) with no gaps; corners match the octagon so fighters cannot slide off.
- **Backdrop.** Reuse the existing map meshes as **non-colliding decor** (a
  `stage_only`/decor group whose collision is disabled except in fighting mode).
  No multiplayer ramp, lift, vehicle or objective collider is inherited. Where a
  crop exposes the back of map shells, materials must be set **double-sided**
  (`cull_disabled`) or replaced with a one-sided replacement mesh.
- **Camera.** Bounded side-on/three-quarter stage camera that frames both
  fighters and the backdrop; clamp to the crop's camera bounds below. Camera
  bounds are derived from the source identity-map cameras where they exist
  (`godot/identity_maps/generated/<id>.json` `cameras`).

| Stage | Crop source bounds | Proposed fight-plane centre (X,Z) | Stage camera bounds (min→max) | Double-sided note |
|---|---|---|---|---|
| Basalt Reach | `±48, ±40`, ceiling 60, void −12 (`identity_maps/generated/basalt-reach.json`) | a flat canyon-floor pocket near `(0, 2)`; sample Y in engine | X −30→30, Y 4→26, Z 12→46 (from `vista` cam `(-43,24,38)→(0,4,0)`) | cliff/rock shells cull-disabled |
| Canopy Divide | `±48, ±40`, ceiling 60, void −12 | a ravine-floor clearing near `(0, 2)` | X −30→30, Y 4→26, Z 12→46 | tree trunks solid decor; crowns cull-disabled |
| Parallax Observatory | `±160, ±128`, ceiling 100, void −18 | archive arcade centre; sample Y from source floor | frame the arcade long axis; clamp inside the 7 GLB batches | interior shells already closed; verify glazing |
| Crown Array | `±208, ±144`, ceiling/void in JSON | guardian court centre | tight court frame; clamp inside the court ring | structure shells cull-disabled where cropped |
| Blood Gulch | `±80, ±35`, void −12 | central green bowl near `(0,0)` | X −40→40, Y 8→30, Z 30→70 | canyon walls already closed |

**Foreground root bbox.** The stage root's expected top-down footprint is the
octagon above; its bounding box is 28 m × 18 m, centred at the crop centre. The
vertical bbox is `[planeY, planeY + 2.6 m]` for a standing fighter (bind heights
run 1.793–2.034 m per the rig manifest plus weapon). The fight-plane collider is
built from the octagon as a **ConvexPolygonShape2D-style prism** in its own
collision layer; projectiles and fighters are the only things on it.

**Background cost.** Reuse budget per stage should stay inside the measured
phase-1 figures where the map is an original Web map (e.g. Blood Gulch 50,296 tri
/ 394 draws), and inside the native GLB figures for the new maps (Observatory
148,239 tri / 7 batches). The two biome arenas are cheapest (3,840 terrain tri +
bounded MultiMesh batches, `port/biome-upgrade/README.md`). The fight-mode crop
should frustum-cull most of the map and keep the backdrop triangles below the
crop's camera far plane.

---

## 8. Roster coverage & test matrix

No runtime code lands from this branch; this is the proposed verification plan
for whichever implementation lane is approved.

### 8.1 Coverage (must be 100%)

- 9/9 operators resolve a fighting profile: stats, 3 strings, 3 specials, combos,
  FX tints, guard/strike/movement clips.
- 7/7 harnesses map to an EX/super per operator; 57/57 valid operator×harness
  pairs resolve (6 Claude→Claude Code redirects asserted).
- 10/10 weapons appear in at least one operator's special or normal set.
- 9/9 movement verbs map to a distinct `S2` with its `MOVEMENT_VERBS` budget.
- 5/5 recommended stages have a crop spec + plane Y sample + camera bounds.

### 8.2 Test matrix (proposed)

| Area | Test | Source of truth |
|---|---|---|
| Roster count | `OPERATOR_KITS.length === CHARACTERS.length === 9`; `SPECS.length === 7` | `kits.test.mjs`, `class-ui.test.mjs` |
| Valid loadouts | 57 valid, Claude lock redirects to `claudecode` | `validLoadout`, `resolveKit` |
| Stat bounds | fightHP within the derived 9,000–9,800 span; weight 1–10; reach ordered by band max range | `data.mjs`, `WEAPONS.range` |
| Movelist coverage | every operator has exactly 3 strings + `S1/S2/S3` classes (projectile/mobility/throw) | this doc §5 |
| Clip coverage | every operator supplies guard + 3 strikes + movement set; shared clips reused | `character-anim.mjs` channels |
| Input buffer | directional buffer length and cancel windows are data-driven; specials accept press + release | `game/keybinds.mjs`, §11 refs |
| Stage collision | fight-plane octagon is the only fight-mode collider; no map ramp/vehicle collider exposed | stage crop §7.5 |
| Stage double-sided | crop-exposed map shells render with cull disabled or replacement mesh | §7.5 |
| Camera bounds | stage camera never leaves the crop bounds; both fighters stay framed | §7.5 |
| Regression | existing shooter tests untouched while fighting mode is off | repo suite |

### 8.3 Acceptance gates

- **Art gate:** Helix/Foundry revisions and the Parallax cosmetic revision must
  pass actual image review before their stages are scheduled.
- **No IP:** move names, FX and data in this doc are derived only from this
  project's own operator/weapon/verb identities. No external fighter assets,
  names or move vocabulary are copied.
- **No runtime claim:** per the research parent, no code is written from this
  worktree until approval.

---

## 9. References (primary / reputable)

Fighting-genre archetypes and combo accessibility (for the stat/movelist design
rationale only — no assets or names reused):

- S. Stenström, *Fighting Genre Design Guidelines* (Chalmers IDC), eight archetype
  categorisation and learning-curve guidance.
- Red Bull, *Street Fighter 6 character guide* and Celia Wagar, *How to Pick a
  Fighting Game Character* (CritPoints) — rushdown / zoner / grappler / footsie /
  setplay definitions.
- Smack Studio wiki and Smashpedia, *Character Archetypes* — projectile/grapple/
  throw tool partitioning.
- CritPoints, *How to Code Fighting Game Motion Inputs*; Skyway666 *Input-Combos*;
  Wavu wiki *Input buffer*; Giant Bomb / SuperCombo / 3S Dojo on **negative edge**
  — input buffer, cancel windows and release-input accessibility.

Engine/input:

- Godot 4 *Using InputEvent* —
  `https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html`
  (InputMap, `_unhandled_input`, `Input.parse_input_event`).
- The project's own remappable standard: `game/keybinds.mjs`
  (`DEFAULT_BINDINGS`: WASD, Space, Shift, Ctrl, R, F, G, Q, X, E, V, Z;
  `RESERVED_CODES`; `normalizeBindings`/`rebindAction`), and the Godot control
  readers in `godot/combined_arms/controls.gd`, `godot/sports/controls.gd`.

Repo authorities cited above (all paths inside this worktree):

- `game/data.mjs`, `game/kits.mjs`, `game/harness-profiles.mjs`,
  `game/operator-profiles.mjs`, `game/operator-verbs.mjs`,
  `game/operator-anatomy.mjs`, `game/operator-detail.mjs`,
  `game/character-anim.mjs`, `game/ability-vfx.mjs`, `game/keybinds.mjs`,
  `game/maps.mjs`, `game/arenas.mjs`, `game/weapon-models/index.mjs`.
- `docs/design/CLASS_OVERHAUL.md`, `docs/design/OPERATORS_AND_HARNESSES.md`.
- `port/native-source-operators/README.md`,
  `godot/source_operators/generated/manifest.json`,
  `godot/source_operators/operator_visual.gd`.
- `port/new-maps/WORKSTREAM.md`, `port/biome-upgrade/README.md`,
  `port/campaign/WORLDS.md`, `port/campaign/WORKSTREAM.md`,
  `docs/evidence/phase1/maps/manifest.json`,
  `/home/mojo/.tmp-on-disk/cocs-screenshot-gallery-20261002-1229/manifest.json`.

---

## 10. Open decisions for the research parent

1. **Scope of the fight mode:** 1v1 only, or 1v1 plus 2v2? Wing/archetype balance
   above assumes 1v1.
2. **Stage slate:** approve the 5-stage initial slate, or swap Parallax for the
   conditional Helix lightwell if the art gate clears first.
3. **Harness role:** adopt the harness as the EX/super layer (this proposal), or
   keep harnesses out of the fight mode entirely and use only class verbs.
4. **Stat source:** use current `data.mjs` numbers (this proposal) or the planned
   re-cut in `OPERATORS_AND_HARNESSES.md` once signed off.
5. **Input model:** confirm buffered cancels + negative-edge for accessibility
   before any moveset is implemented.
6. **Crop authority:** confirm the fight-mode crop disables all inherited map
   collision (ramps/vehicles/objectives) and that exposed shells get double-sided
   or replacement materials.
