# Broad source-feature migration and quality pass

Owner requests a fan-out of Astra subagents to improve every area of the game
and resume porting features from the Three.js version. Start from `29e242a0`;
the published Windows/Linux runtime is `1c1f6e34`, with 67 package cases passing
on each platform. Existing archives and evidence remain unchanged.

## Approach

Compare actual source and native implementations before selecting work. Historical
roadmaps contain features since completed and must not be treated as a current
gap list. Each lane produces an evidence-linked parity inventory, implements a
substantive batch of genuinely missing features, and verifies complete player
journeys. Parent consolidates coverage and remaining work rather than claiming
that a single batch completes every element of the port.

The Node simulation remains authoritative. Original source pin `515daf07` and
explicit derivative provenance remain intact. Preserve the latest targeting,
facade collision, decal, animation, input-flow and campaign-variety improvements.

## Four parallel Astra lanes

All use `openai/gpt-6-astra`, explicitly requested by the owner. No nested agents.

| Lane | Session | Branch / worktree suffix | Owned scope |
|---|---|---|---|
| Player gameplay | `ses_f057f005fffeyuSmQWGHfimLDp` | `improvement/port-gameplay` / `cocs-port-gameplay-20261001` | Source player mechanics, abilities/mobility, native controls and ability feedback; audit existing alt-fire/ADS before identifying gaps |
| Modes and progression | `ses_f057e7cefffe11e4yW40Ld7UVo` | `improvement/port-modes` / `cocs-port-modes-20261001` | Missing mode journeys, source rules/objectives/results, route capabilities and relevant progression; investigate Arsenal/Juggernaut/Team Elimination/VIP Escort |
| World presentation | `ses_f057da879ffeBImySFzLFoKnaf` | `improvement/port-world` / `cocs-port-world-20261001` | Source environment/vehicle/world presentation gaps, production effects/readability and bounded resource use |
| Experience | `ses_f057d1965ffev4yUJMNZ1M8P06` | `improvement/port-experience` / `cocs-port-experience-20261001` | Common UI/settings/audio/accessibility and player information; investigate source captions/recaps/spectator usability |

Worktrees and corresponding `*-evidence-20261001` evidence directories are under
`/home/mojo/.tmp-on-disk/`. Each lane records `PARITY.md` and `ACCEPTANCE.md` in
its `port/next-port/<lane>/` directory, with actual source/native anchors.

## Shared-file and engine coordination

- **World owns the exclusive Godot slot now.** Gameplay released the slot after
  its accepted live-input journeys. Other lanes are research,
  code and Node-only until explicitly granted the engine. Heavy native/Blender
  work is serialized with `LP_NUM_THREADS=1` and the pinned Godot 4.5.2 binary.
- Current handoff: Gameplay → World → next ready Modes/Experience, adjusted only through
  an explicit parent grant after the preceding owner releases its processes.
- Modes owns generated route capabilities and mode allowlists; Experience
  consumes those without rewriting the same files.
- Parent owns final shared session/presentation integration, package closure,
  canonical registration, root documentation, exports and platform verification.
- Small shared hooks must be isolated and documented. Prefer passive signal-based
  composition and helpers over whole-file rewrites.

## Acceptance and publication

### First implementation integrations (native acceptance pending)

- Gameplay `4d1b8b69` integrated as `ffd5fad2`: reliable short X taps, bounded
  source-backed ropes/grapple cues and ability/resource readouts. Native live
  Kimi/Qwen/ChatGPT input journeys, 75 source tests and new native contracts pass.
  The retained before-control produced zero X frames. Parent registers isolated
  live evidence and packages the source catalog; Experience is integrating its
  status model responsively. Combined/native platform acceptance remains pending.

- World implementation `656f0830` integrated as `8f602607`: source weather
  lighting, wet-surface material response and linear-space sky luminance.
  Source tests/oracle passed; native/rendered/connected checks await engine grant.
- Experience implementation `58c6f623` integrated as `74361407`: priority sound
  captions, persistent caption controls and passive incoming-hit/kill information.
  Source tests/oracle passed; native/rendered/connected checks await engine grant.
- Both lanes' oracle checks and native contracts are registered in the canonical
  verifier. Registration is not a passing native result or release approval.

Require real source inputs/events/results, lifecycle and privacy/control boundary
checks, native visual/audio evidence appropriate to the feature, and wide/compact
UI checks. Distinguish scripted fixtures, actual connected input, human feel and
hardware performance. Preserve failed attempts and previous releases.

Parent integrates verified lane commits, exercises cross-lane behavior, runs the
combined checks, and publishes fresh Windows/Linux packages after extracted
acceptance. Feature inventories must identify both newly completed and remaining
source gaps, including any previously open acceptance work they actually close.
