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

## Implementation selection — six active source-only lanes

All three audit reports returned. Implementers start from `5b5c8791` in independent
worktrees; these features remain separate while K completes its bounded native
scope. No new engine grants were issued.

| Lane | Agent/session | Exclusive implementation scope |
|---|---|---|
| Muzzle sheets | Flash `ses_eff83dcb6ffeOx4MDBGWgziYqF` | `weapon_effects/flash.gdshader`, focused real-frame coverage fixture |
| Explosion fallback | Luna `ses_eff83af12ffelI5Je1AWbG8N9D` | `weapon_effects/controller.gd` explosion dispatch and focused regression |
| Identity atmosphere | Sol `ses_eff835b6bffefGBhcNZUxC3HVD` | `native_arenas/identity_environment.gd`, scoped identity environment callers/helpers |
| Support cues | Flash `ses_eff831cf1ffebQPpZ24POXEwVB` | `world/combat_feedback.gd` supplemental integrated effects, `graphics_fx/moth_world.gd` if needed |
| Lobby QoL | Flash `ses_eff82e4f1ffeKeuDcNQtJrmO6i` | `social/room_browser.gd`, `ui/lobby_menu.gd`, `lobby_choice.gd`, `match_setup.gd` |
| Opaque surfaces | Sol `ses_eff82a739ffezappqlSkz8D77F` | `moth/surface.gdshader`, dedicated priority variant, surfaces helper and narrow terrain-material binding |

### Selected evidence and intended corrections

- Actual baked spark/arc frames have colored backgrounds, while muzzle coverage
  uses raw brightness. Remove background contribution without changing analytic
  silhouettes or authored weapon tints; test actual frame pixels.
- Legitimate attachment explosions can omit `weapon`, but burst dispatch currently
  only admits known primary weapons or alt kinds. Add a validated generic burst,
  preserving alt precedence, pool limits, quality and deduplication.
- The integrated feedback queue never forwards heal/pickup/teleport events to the
  existing Moth consumer. Restore only those non-overlapping effects; avoid a second
  explosion/damage cue and preserve inactive-event draining.
- Identity-map gameplay uses a different environment installer from its authored
  inspection path. Align installation and ownership while preserving distinct map
  atmosphere, weather controls and non-identity maps.
- Room-browser filters can produce a blank list without feedback; lobby choice
  setters redraw unchanged state each frame; missing map selections can index an
  invalid catalog key. Correct these workflows with selection/focus/error recovery.
- The general Moth shader writes `DEPTH` even when no priority bias is needed.
  Separate the terrain-priority variant while retaining exact coplanar raster
  behavior. Performance benefit is a hypothesis until measured, not an FPS claim.

### Findings requiring coordination or further evidence

- K was notified that third-person reduced-motion reads may lack an actual local
  settings producer. Verify route-level preference wiring, not only synthetic
  actor dictionaries. Existing essential gait must remain under reduced motion.
- Third-person flinch appears to consume an absent snapshot field. Defer that new
  event decorator until K's presentation-file ownership is released.
- Untracked operator finish import sidecars were flagged. Audit actual import and
  binder results before deciding policy; missing committed sidecars alone does not
  prove exports lack resources. Do not blindly change normal-map enum values.
- Black T LUT planes do not alone prove an authored brightness error. No blanket
  doubling of accents or cross-map tone-mapping change is approved.
- Missing exported tangents may be handled by the importer. Mirrored-UV artifacts
  require actual evidence before another asset rebake.
- Web-only history/keybinding/radar findings are recorded in the audit response;
  this pass prioritizes the native release's visible effects and player workflows.

Each lane must return working commits, source checks and executable native
follow-up requirements. Native/rendered results and package dependency updates
remain pending; existing captures do not validate these new changes.

## Review checkpoints

Luna explosion checkpoint `60997c7c` is **not integrated**. Parent found that an
unknown weaponless `alt:true` event would incorrectly take the generic branch,
despite its new fixture asserting rejection. Returned for explicit fallback
eligibility, quality-off consumption/replay checks and actual grammar validation.
The native fixture remains unrun; a clean diff alone does not establish behavior.

Sol atmosphere checkpoint **`62c3d04d`** is reviewed and source-ready on its own
branch, **not integrated** while K's candidate remains stable. The live identity
environment delegates to the existing authored style for its three explicit map
keys; Canopy/Basalt retain their procedural path. Parent inspected the change,
weather lease fixture and actual style signature, then independently parsed both
changed/new GDScripts and passed diff checks. Native single-environment ownership,
weather restoration and gameplay/inspection image parity remain pending. Report:
worker `port/finish/polish/IDENTITY_ATMOSPHERE.md`.

Luna correction **`8caa5cd9`** now excludes unknown alt markers from generic
explosions and remembers valid events while quality is zero. Parent reviewed the
dispatch and independently parsed controller/fixture. Source-contract assertions
were reported by the worker; the native fixture is still pending. Parent added
documentation correction **`7dab8fe8`**: the existing controller is hash-pinned,
so no new preload does not mean no package reconciliation. This three-commit
bundle (`60997c7c`, `8caa5cd9`, `7dab8fe8`) is source-ready, **unmerged**.

Sol depth checkpoint **`03a64083`** is **not yet accepted**. It preserves terrain
bias and routes general materials through a no-DEPTH shader, but omits the new
shader from weather wet-sheen recognition. Parent explicitly assigned the same
owner narrow `ambience/weather_look.gd` / `wet_surface.gd` compatibility changes
and both-variant lease/restore coverage. Identity atmosphere only changes the
separate native environment installer, so those ownership scopes do not overlap.

Flash muzzle checkpoint **`e5a0f710`** is reviewed and source-ready, **unmerged**.
It subtracts the frame's sampled corner background for both sheet coverage and
color, preserves the analytic core, and disables texture repeat at the card edge.
The worker decoded the actual spark/arc PNGs and reported scalar coverage checks;
these are not GPU output. Parent independently parsed the expanded graphical
fixture and passed diff checks. Native shader compilation, real-frame transparent
background/core/hue comparisons and captures remain pending. No original asset
bytes or imports changed; the shader hash requires later package reconciliation.

Flash support-cue checkpoints **`e31de5d7` / `cebc8d33`** remain **unmerged pending
correction**. Routing admits only heal/pickup/teleport cues through the integrated
fresh-event pipeline and leaves existing damage/explosion owners intact. Parent
requested immediate clearing of active cues when quality is disabled or reduced
motion enabled, retaining consumed event IDs so toggling cannot replay them.
The fixture must compare the actual passed snapshot for immutability and must not
print `authored_not_executed:true` when executed. Native validation remains pending.

Sol depth follow-up **`3059de9a`** completes both wet-sheen allowlists and expands
weather lease/restore coverage for both shader paths. Parent independently ran
`check_shader_parity.py` (**`MOTH_SHADER_PARITY_OK`**) and parsed six changed/new
GDScripts, with clean diff checks. Bundle **`03a64083` + `3059de9a`** is now
source-ready and remains **unmerged**. Native shader reflection/compilation,
weather restoration, Moth validation and Compatibility depth-pixel comparison
are pending. No measured performance improvement is claimed.
