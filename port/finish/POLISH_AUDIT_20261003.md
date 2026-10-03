# Graphics, animation, presentation and QoL audit/implementation

The user explicitly renewed parallel work: Flash agents should scour the codebase
for improvements to graphics, animation, presentation, shaders, assets and QoL,
then Flash, Sol and Luna should implement the selected findings alongside current
production/verification. This is an implementation directive after discovery.

## Discovery lanes

Read-only foundation: `e43d2d38`.

| Audit | Flash session | Deliverable |
|---|---|---|
| Graphics/shaders/assets | `ses_eff8b0708ffenSWc5GEenftkVI` | Current runtime defects and scoped visual improvements, exact call sites, verification needs |
| Animation/presentation | `ses_eff8ad2f6ffeJ6vPvICcO44yfw` | Enemy/world/Fighting effects and animation opportunities outside active motion ownership |
| Usability/player feedback | `ses_eff8aa28effeAkil5fey20P6F6` | Concrete workflow, focus, feedback and readability fixes outside active UI ownership |

Each returns ranked evidence-backed findings and recommends bounded Flash/Luna/Sol
implementation scopes. Prioritize genuine player-visible defects and useful polish,
not speculative frameworks or features already implemented. Parent reviews findings,
assigns nonoverlapping files and receives tested commits from implementation lanes.
No discovery lane runs engines, servers, imports, renderers or nested agents.

## Coordination and verification

Exclusive local native grant remains **`MOTION-UI-NATIVE-20261003-K`**, owned by
`ses_f03a3885fffehx9yFhHubuPCft`. K is verifying the already integrated UI, operator
motion, first-/third-person kicks, player smoothing, vehicle views and race lifecycle
fixes. Its scope remains stable through `e43d2d38` plus necessary native corrections;
it does not wait for this new audit/implementation round.

New implementers work source-only in independent worktrees. They must avoid K's
runtime files unless parent explicitly transfers ownership. New shader/asset/input
behavior requires later native validation and screenshot comparison. No gameplay
authority changes, asset rebakes, lossless animation-import changes or new heavy
processes are implicitly authorized. Preserve original evidence, published builds
and identity/team colors.

Package owner `ses_f03437da1ffeli91L87Q6CVyRP` is separately promoting Stormglass
and reconciling already reviewed runtime dependencies. Later polish commits need
their own exact dependency reconciliation; they are not included in old receipts
or native results simply because they share a branch.

## Implementation selection

Pending the three Flash reports. Parent must follow through by assigning actual
Flash/Sol/Luna implementation, meaningful source verification and later native
acceptance, rather than stopping at recommendations.
