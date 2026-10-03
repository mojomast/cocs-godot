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

Parent combines the research into a bounded brief and assigns **Astra** to
implement the strongest justified changes. The implementation agent has not yet
been launched at this research checkpoint. It must verify its actual isolated
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
