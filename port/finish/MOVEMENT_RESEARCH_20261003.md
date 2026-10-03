# Research-led infantry movement revision

## User directive

The user requests Flash subagents to research movement in similar games and find
ways to make this game's movement more fun and appealing, followed by an Astra
subagent implementing the best findings. This adds a movement workstream alongside
the ongoing new Moth resources and Blender map production.

Foundation: `49f46278`. Research is read-only; implementation follows review of
the findings. The earlier motion pass already introduced gait/IK improvements,
first-person inertia, sprint FOV feedback, reduced-motion propagation and vehicle
camera corrections. Source movement already includes coyote time, jump buffering,
variable jumps, slide/hop and air control. Research must inspect actual behavior
and native access rather than propose those features as absent.

## Research owners

| Lane | Flash session | Deliverable |
|---|---|---|
| Arena movement | `ses_efda33518ffeZyti0rauM454Cm` | Credible arena-FPS references, actual acceleration/friction/air-control audit, ranked tuning or algorithm changes and exploit limits |
| Traversal and movement feel | `ses_efda2dbfcffelgOeljGpaZJWej` | Referenced jump/slide/landing-flow and perceptual-feedback findings with current code touchpoints, readability and comfort constraints |
| Native input and authority parity | `ses_efda28a6effeHES0828WktLlL6` | Input edge/held routing and network responsiveness audit; separate actual logic defects from software-render scheduling symptoms |

All three are assigned actual web research with cited URLs and precise source
observations. They must distinguish documented mechanics from recommendations,
rank practical improvements, identify meaningful tests, and explain ideas to defer.
No engine, Blender, import, server or native benchmark is authorized by research.

## Implementation handoff

**Astra implementation is active:** `ses_efd9f7a16ffebB54Qq3YBwuZ3t`.
The arena and traversal Flash reports are complete; native-input research remains
in progress. Parent supplied both completed reports and the selected scope below.
The implementation agent must verify its actual isolated
worktree/branch before editing; parent owns shared-branch integration.

The renewed user request permits reviewed changes to infantry movement behavior,
not merely camera polish. Preserve authoritative simulation/input ordering,
operator-specific abilities, campaign and multiplayer behavior, replay consistency,
ADS aiming, reduced-motion options, and mounted vehicle camera ownership.
The separate Fighting mode's fixed-60 Hz integer authority is outside this scope.

Do not loosen jump/cooldown/contact windows, epoch/sequence validation or test
deadlines to mask slow input delivery. P's Gemini and campaign delivery gaps are
evidence to investigate, not proof that movement physics is wrong. Old acceptance
results remain tied to their old candidate.

P is released, but **no new heavy grant is active**. Source implementation can run
alongside remote Moth generation. Parent coordinates serial Blender/native slots,
fresh movement evidence, changed dependency reconciliation and eventual packages.
No source test or staged capture establishes human feel or hardware performance.

## Selected implementation scope

1. **Consistent self-generated speed bounds.** Parent source inspection confirms
   the total-speed clamp sits only in the airborne acceleration branch of
   `game/core.mjs`; ground/takeoff acceleration can escape it. Flash reports a
   160-second orthogonal strafe-hop probe reaching 25.24 m/s. Astra must reproduce
   the actual grounded cadence and fix the gap while preserving legitimate
   incoming impulse/traversal speed, slide momentum and stance-specific budgets.
   The current 2.2 multiplier stays the initial baseline; the proposed 2.35 is
   not justified merely by calling it more fun.
2. **Buffered air-to-ground slide intent.** A short eligible airborne crouch tap
   should survive a near landing. Existing slide speed/cooldown/ability eligibility
   stays authoritative. A finite commitment, explicit cancellation, lifecycle
   resets and protection for Grok/Meta crouch abilities are required. The proposed
   0.15-second window is a tuning hypothesis, not a measured universal optimum.
3. **Camera-neutral slide readability.** Add a bounded first-person weapon pose
   that yields to ADS and reduced motion and clears for mounted/dead/hidden actors.
   Preserve camera/reticle/shot-ray ownership. Reuse existing slide status text;
   an extra HUD overlay is not part of the selected work.
4. **Evaluate modest air steering improvement.** Compare the current 3.5/1.6
   acceleration/projection-cap settings with a restrained candidate, preserve
   Mistral's relative identity, and report measured tradeoffs before selection.
   Broad ground-friction, base-speed and jump-window changes are deferred.

The reference mechanics inform these choices, but exact numerical settings are
proposals. References include id Software's Quake III `bg_pmove.c`, the community
`ioquakelive` implementation, Respawn's movement-design interview, Mirror's Edge
first-person animation discussions, and Celeste's intent-forgiveness principle.
Community wikis, mirrors and third-party videos must not be labelled official
implementation proof. No copied controller or new wall-running system is planned.

- https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/bg_pmove.c
- https://github.com/tjone270/ioquakelive/blob/1487e89c/code/game/bg_pmove.c
- https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right
- https://www.gdcvault.com/play/1012171/Creating-First-Person-Movement-for
- https://www.maddymakesgames.com/articles/celeste_and_forgiveness/
