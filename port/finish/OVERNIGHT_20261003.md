# Overnight feature and production directive — 2026-10-03

The user explicitly requested Luna and DeepSeek fan-out to determine what to
build next, begin implementation, and make substantial progress while they sleep.
This renews the production/release directive and authorizes the bounded feature
lanes below. Agents must inspect existing behavior before selecting improvements;
the listed themes are scope boundaries, not claims of completed features.

## Active feature lanes

All four start from `aa3b8f0f`, in separate worktrees. They may implement and run
small source checks/grammar validation. They must return clean commits, actual
results, package impacts and explicit pending native tests. No nested agents.

| Owner | Session | Owned scope | Lane report |
|---|---|---|---|
| Luna — Home | `ses_effc6d3fdffef7n32Sj1zzz9wZ` | Home menu and compatible menu preferences; discoverability, navigation and selection recovery | `overnight/LUNA_HOME.md` |
| Luna — controls | `ses_effc5ac7fffes3QLB37bSAxCUV` | Binding UI and isolated helpers; setup feedback, recovery and focus | `overnight/LUNA_CONTROLS.md` |
| DeepSeek V4.1 Flash — campaign | `ses_effc66f72ffeCOfJsHswRPX0gp` | Campaign HUD/demo and new read-only guidance helpers; objective/optional-content usability | `overnight/DEEPSEEK_CAMPAIGN.md` |
| DeepSeek V4.1 Flash — Fighting | `ses_effc60d59ffeuyLQ0Ab4Ig3qI3` | Fighting main UI and new presentation helpers; training/learning feedback | `overnight/DEEPSEEK_FIGHTING.md` |

The user named DeepSeek explicitly; model discovery resolved it to
`deepseek/deepseek-flash`. Luna uses the available `worker-luna` agent.

Home's first source checkpoint `d391dc5f` adds a catalog-backed Campaign shortcut
and restored-route focus. It is not yet integrated/native-verified. Parent asked
the same lane to continue with searchable destinations, explicit no-results and
clear behavior, and selection/focus preservation before returning the full bundle.

Controls first checkpoint `c5043683` clarifies full-profile reset scope; it is
unmerged and only grammar-checked. Parent requested continuation: searchable
existing editable bindings, persistent modified-from-default summary and truthful
swap feedback. The audit's initial "six actions" count was incorrect (current
`Model.LABELS` exposes 16); the lane must correct it. Hidden adapter-owned fixed
controls must not be presented as functional rebinding options.

## Implemented source bundles awaiting review/native execution

Parent integrated the returned bundles through `a78edd8d`:

- Home shortcut/search: `31ba6076`, `d6cc624b` (original `d391dc5f`, `e59d981d`).
- Binding search/modified overview/reset scope: `63d6cdeb`, `6669a124` (original
  `c5043683`, `c2f4a4cb`). Corrected audit is `../OVERNIGHT_LUNA_CONTROLS.md`.
- Campaign Relay Journal/route context: `1c84c843` (original `91903d85`).
- Fighting live training feedback/practice goals/bind hints: `84d06344`,
  `74f57d27`, `a78edd8d` (original `d344853d`, `63d4878c`, `1c346f7e`).

Astra reviewer `ses_f03a3885fffehx9yFhHubuPCft` completed the independent source
review. Fixes integrated as `00825bf1`, `22cd650a`, `18e1d627` and `c8eabea1`:
Home Escape/focus intent, filtered binding focus, valid Journal APIs and public
state provenance, and Fighting event attribution/idempotence/replay-prefix/HUD
corrections. Parent independently passed 17 route/options checks and six Fighting
source checks. The seven-case native runner printed its dry plan with
`executed:false`. **None of these features has yet passed its new native UI checks
or shipped.** Review details: `overnight/INTEGRATION_REVIEW.md`.

The user subsequently requested Flash research and Sol/Astra motion, vehicle and
melee implementation. See `../MOTION_20261003.md`; those lanes are independent.
Abyssal I has completed/released, and Stormglass owns the next heavy grant J.

## Production and integration sequence

1. Abyssal I completed and released; parent reviewed/integrated its six demonstrated
   pairs and package promotion at `c7c81c71`. Six units are promoted.
2. Stormglass owns exclusive local heavy grant
   `STORMGLASS-ASSET-PRODUCTION-20261003-J`, owner
   `ses_f0342d1ffffeyUHJkcUj3vqP7p`. Require explicit release and zero owned
   processes before granting native motion/vehicle/UI verification.
3. Review and integrate source-ready feature commits independently. Run meaningful
   source checks now; actual engine/UI/input checks require a later local slot or
   a separately authorized remote runner. Preserve receipt identities and record
   changed supporting inputs; old native results do not prove new features.
4. Finish Stormglass, then sequence unresolved native gameplay/UI checks and the
   prepared cinematic/menu production against accepted assets. Prioritize concrete
   failures and working player flows over expanding speculative scope.
5. Freeze a new candidate and build/verify Windows and Linux from the same anchor.
   Keep the published `cb6e4c9f` preview and its downloads immutable. A subsequent
   preview may be published with honest scope if full final acceptance is still
   blocked; do not call it final or waive the 142-job obligations.

Remote Windows navigation comparison `37095237382` remains owned by the packaging
agent and its watcher. It is independent of the local heavy slot. Parent awaits
the actual report; no timing, graph or native pass is inferred from dispatch.

## Completion standard

Preserve frozen authority, all nine operators, controller recovery, public
map/mode registration, campaign story/robots/optional objectives, animation import
policies and existing releases. Feature changes should use existing public state
and ordinary controls, with correct scene/round/reset cleanup and compact UI.
Avoid duplicate features, unrelated rewrites and unverified completion claims.

The morning summary should distinguish **implemented**, **source-tested**,
**native-verified** and **shipped**, include links to actual captures/downloads,
and list concrete remaining blockers without repeating historical plans.
