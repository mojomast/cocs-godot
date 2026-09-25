# LATTICE Strike — flagship gameplay direction

**Pitch:** Take ground, keep it connected, and use your operator, harness, squad
and support force to make the next push possible. Every successful fight should
have a visible strategic consequence: a legal capture, a restored income path,
a broken dominance clock, or a safe rotation for teammates.

This is an **Astra research/design brief**, not a shipped rule change. The
current selected source is `515daf07589150dd3241f4ae1425cc1b093912f5`
(`port/contracts/source-lock.json`). Observations below describe that code;
recommendations and targets are proposals for playtesting. The Godot client
remains a recipient of source-authoritative outcomes.

## The game already has a distinctive core

- Asterion Relay and Monsoon Foundry each have two HQs, two front nodes, two
  income nodes and a relay, with roads, infantry routes and flank traversal.
  Their current **node graph is shared**, despite different terrain/dressing
  (`game/destination-lattice-maps.mjs:67–107`). The relay's strategic value is
  access; connected fronts earn 1/s and siphons 3/s, while the relay pays 0/s.
- Legal capture requires an owned **adjacent** node; an owned **connected** path
  back to HQ is separately needed for income (`game/cocs.mjs:542–590`). A cut
  node can still be adjacent and capturable. Teach the difference explicitly.
- The PvP climax is majority **ownership** held for a dominance window: 90/45s
  in 4v4 and 120/60s in 8v8, with the fast timer for an extra node. Losing
  majority resets progress. Contesting without flipping ownership does not
  stop the clock (`game/config.mjs:16–30`; `game/cocs.mjs:1784–1799`). At the
  match deadline, score and then owned-node count decide the outcome.
- Five agent roles, nine operators and seven harness hooks already exist
  (`game/config.mjs:16–30`; `game/lattice-roles.mjs:11–46`). Owned depots can
  issue free Puma loaners (`game/cocs-traversal.mjs:486–551`). Siphon income
  affects **both score and team FLUX** (`game/cocs-economy.mjs:394–424`), so
  positioning can snowball without any new economy layer.
- 4v4 currently fields Fighter/Harvester/Builder agent roles; Scout and
  Saboteur join the 8v8 roster (`game/config.mjs:16–30`). Cut repair therefore
  needs measured opportunities, especially in 4v4.
- Native FPS traversal, HOLD and limited mode-specific purchases exist. The
  current native world panel surfaces HOLD plus Fighter/REINFORCE and pauses
  world controls while open (`godot/lattice/world_commands.gd:58–77,108–166`).
  Full natural strategy rounds across both maps and modes remain open in
  `port/RELEASE_MATRIX.md`.

### The first rule tension to resolve when source changes are authorized

HOLD/ATTACK tasks last two seconds, but an uncontested valid order can advance
capture even without a friendly actor on the node (`game/cocs.mjs:1737–1773`).
This weakens the promise that teams must **win a field fight to convert ground**.
Do not disguise this in the HUD, or simply lengthen order duration: that would
strengthen remote capture. A future **upstream source** revision should couple
the changes: make orders persistent squad intent, make physical players/agents
perform capture, retune bot duties and rewards, then advance the port source pin
only after that source revision lands. Until then, finish and honestly present
the existing rule set.

## The player-facing loop

**8v8 Strike** is the fullest competitive showcase; **4v4** is a compact
version, and the existing five-wave **Operations** is the co-op entry point.
Their victory conditions stay distinct: Operations protects HQ and clears
Director waves, with its own terminals/PRIME; do not teach co-op interactions
as current PvP mechanics (`game/cocs-coop.mjs:4–19`; `game/cocs-terminals.mjs:12–21`).

| Time in a typical 60–90s decision cycle | Player experience |
| --- | --- |
| First 10s | See one urgent legal frontier or supply cut, **why** it matters and the useful approach. |
| Next 15s | Select a weapon/route, recruit or redirect one support unit if appropriate, stage with a teammate. |
| Next 30s | Fight for an entry angle; scouts reveal, breachers dislodge, anchors cover, engineers repair or interact. |
| Last 15–35s | Convert to ownership/income or break a dominance clock; then hold or rotate before the enemy counterpush. |

Target an **observed median** of 15–25 minutes for evenly matched sessions:
opening front (0–2), first relay-versus-siphon choice (2–5), rotations and
interdiction (5–12), dominance push/response (12–20). This is a desired pacing
arc, **not** the current guaranteed duration: existing 45–120s dominance timers
can produce an early decisive win. Measure complete rounds before tuning.

The board answers **where/why**; the first-person game answers **how**. Keep
ordinary command visits brief and optional for every front-line player, with
commands enabling field play rather than substituting for it.

## Make roles produce different team stories

These are recommended jobs for current mechanics, not exclusive classes or a
mandatory composition. Pair the operator with a harness for a situational
synergy, then select weapons for the route and engagement distance.

| Operator / job | Example harness, loadout and teammate payoff | Counterplay / limitation |
| --- | --- | --- |
| **Mistral — rotation runner** | Moving-point capture bonus; Hermes converts personal REQ into FLUX at a connected economy point. SMG/scatter for arrival, then an anchor follows. | Catch the rotation before it becomes ownership; stopping loses Mistral's capture bonus. |
| **Gemini — entry duelist** | Post-swap capture window and two-primary identity; OpenClaw disrupts enemy progress. Scatter/SMG clears the point for Claude. | Force an exposed swap or defend from a second angle; disruption never grants ownership. |
| **Grok — sustained breach** | Heat-fueled capture and plasma/explosive affinity; OpenClaw opens a contested lane. Plasma/rockets trade burst for exposure. | Break contact to cool Heat, flank instead of feeding the same doorway. |
| **DeepSeek — stationary overwatch** | Still-on-point reveal, rail/marksman controlling an approach; Roo wards an owned point. | Rotate around sightlines; motion costs the stillness benefit. The reveal is intel, not a SCAN damage bonus. |
| **Meta — link maintenance** | Four-second braced cut repair; Codex can trigger emergency repair. Claude covers the channel. | Damage or movement interrupts the channel; no cut means no repair opportunity. |
| **Claude — defensive anchor** | Holding-ground resilience, slow cleanse; Claude Code is the locked thematic guardrail pair. Keep a repair or capture specialist alive. | Threaten another legal node rather than endlessly charging the strongest held angle. |
| **ChatGPT — finite-ammo quartermaster** | Post-swap supply; OpenCode can share with two allies using plasma/rail/marksman when the donor carries ammunition for each recipient's equipped weapon. | Donor pays real ammo; infinite-Pulse teammates cannot benefit from finite-ammo transfer. |
| **Kimi — moving reconnaissance** | Blink and short on-point visible-enemy marks; Hermes enables rapid rotation and a relay/economy response. | Break line of sight or counter-route; intel marks do not grant damage. |
| **Qwen — interaction/transport specialist** | 1.35× legal interaction speed, rope/vehicle identity; Codex suits cut repair, Hermes Puma delivery. Teammates cover the channel or dismount. | Intercept the vehicle and deny the point; Qwen is useful without being required for every capture. |

Mechanics: `game/kits.mjs:66–175`, `game/lattice-roles.mjs:11–46`,
`game/lattice-support.mjs:53–65,72–82,138–159`. Capture uses the **strongest**
contributor, capped at 1.35×, rather than multiplying stacked bonuses. Qwen's
interaction boost already exceeds other capture bonuses; more multipliers alone
will not create meaningful specialization. Default Pulse ammo is infinite, so
ammo support must be paired with **finite-ammo** weapons (`game/data.mjs:21–31`).
Current personal purchases are healing, self-ammo, haste and shield; many
catalogue mines/sentries/barriers/team drops are disabled (`game/cocs-economy.mjs:192–240`).

Examples worth creating space for in maps and onboarding:

1. Gemini/OpenClaw dislodges a defender; Claude holds the gained entrance;
   Qwen converts the opening to a legal capture.
2. Kimi finds a flank; Meta repairs a cut while the squad protects the channel;
   the next connected income tick becomes visible to everyone.
3. ChatGPT/OpenCode stocks a shared rail/plasma weapon to feed its user;
   DeepSeek holds a meaningful sightline; Mistral forces the second rotation.
4. A Puma crew uses the freight road for delivery and suppression, then
   dismounts onto an infantry objective. The counter is interception, rockets
   and defending the exit—not a requirement for another vehicle tier.

## Readability, variety and comeback

- One dominant HUD sentence: **“Retake East Siphon to reset their dominance
  timer”** or **“Restore West link to resume +3 FLUX/s.”** Show the source's
  `breakCount`, ownership, connectivity, contest and cut separately; do not
  infer a win timer from the client clock (`game/cocs.mjs:1802–1834`).
- Show outcomes, not just action receipts: accepted order vs completed order vs
  actual capture; intel mark vs SCAN damage mark; link restored vs repair
  attempted. Reuse `game/lattice-guide.mjs` legality and
  `game/lattice-feedback.mjs` objective-event audio.
- Let Asterion's galleries favor overwatch/flank choices and Monsoon's dam/
  filter-house routes favor road reinforcement and entrance fights. Their
  **current node topology is the same**; measure different player routes and
  pickup use before requesting an upstream topology experiment.
- Losing majority already resets dominance; trailing bots adjust posture, and
  support recruitment/bounties exist (`game/cocs-bots.mjs:69–100`;
  `game/cocs.mjs:1216–1236,1270–1294`). Make the recapture option legible before
  inventing catch-up damage. Track whether siphons' double score/FLUX reward
  creates an unrecoverable early lead.
- The first-session sequence should be move/fire → legal front capture → why
  supply is connected → one accepted command → one route/ride. Introduce
  Operations terminals and spending in their own chapter; existing training
  already distinguishes command receipt from completed action
  (`game/lattice-training.mjs:9–27,76–89,119–128`).

## Ranked execution

1. **Pin-compatible first playable flagship:** integrate world HUD, legal
   target guidance, loadout role explanations, compact command outcomes and
   results with the actual FPS scene. Exercise full natural PvP 4v4/8v8 and
   Operations rounds on both maps, including defeat and restart. Surface only
   actions the native route can legitimately send. Keep gameplay authority
   unchanged during this phase.
2. **Composition playtests:** test breacher/anchor, recon/repair, ammo-sustain
   and Puma delivery stories with mixed novice and experienced teams. Log
   opportunities as well as uses; show why a role was valuable. Prioritize
   situational roles with too few real opportunities over new abilities.
3. **Separately approved source revisions:** first replace order-only capture
   with field presence and persistent squad intent as one coherent rule change;
   then tune dominance pacing, siphon snowball and demonstrated role gaps using
   recorded complete rounds. Land source-owned changes upstream before moving
   `port/contracts/source-lock.json`; never fake them client-side.

**Proposed gates (unmeasured):** ≥80% of new players can identify the next
legal target/win condition after one round; ≥80% make a useful non-kill or kill
contribution within two minutes; a typical spawn reaches useful combat within
30s; routine command visits take under 5s and ≥85% of active time is in the
world. Track median 15–25-minute balanced-match length, first-majority-to-win
conversion, successful majority breaks, 1–4 territory recoveries, and each
operator's **opportunities** and useful outcomes. An exploratory >75%
first-majority win rate merits investigation, not an automatic balance patch.

## Design references (official/developer sources)

- [Battlefield 1 Operations — EA](https://www.ea.com/games/battlefield/news/battlefield-1-operations-mode): taking a sector and regrouping gives a clear territorial chapter; CoCS should use its existing nodes in a shorter arc, not borrow the hour-plus scope.
- [Natural Selection 2 Alien Commander design — Unknown Worlds](https://unknownworlds.com/en/news/alien-commander-v2-0-2): the commander shapes conditions and information without becoming the bottleneck to field players (a 2012 design intention).
- [Helldivers 2 hands-on — PlayStation](https://blog.playstation.com/2024/02/02/helldivers-2-hands-on-report-chaotic-co-op-and-empowering-stratagems/): loadout cooperation and support-weapon handoffs create visible teammate stories; borrow the cooperation principle, not its orbital arsenal.
- [PlanetSide 2 10-year Bastion update](https://www.planetside2.com/patch-notes/tenth-anniversary-pc-update): a vehicle can matter through capture pressure and access. Measure CoCS Puma deliveries and road denial before expanding the fleet.
