# Walker baseline characterization — accepted design, no native readiness

Independent Astra `ses_efc89c2afffeKQvhqPUs4YwsaY` approved `cdc81f7a`, integrated
as **`5d8c2b94`**. Parent passed five offline and thirteen package checks and
verified all seven delivery-file hashes. This is source diagnosis/design acceptance.

## Verified diagnosis

Independent in-memory regeneration exactly matches `comparison.json` and
`frames.csv`. The 317 input responses comprise .35 baselines (127 each), .35
candidates (21 each), and the .42/−45° baseline (21). Settling is checked separately.
AK51, current source/host pins and fifteen production dependencies remain intact.

The pinned Godot 4.5.2 source uses the recorded floor setting .802851438522339 rad
plus .01 rad, approximately 46.5729568°. First .35 target normals are 51.306892°;
.42/−45° target normals are 46.552733° and 46.229696°. Normalization changes these
angles by less than .0001° without changing their threshold relationship.

Mixed base-floor contacts are present. Grounded state alone cannot identify which
contact caused classification. Normals, selected floor normal, wall state and
subsequent rise support the interpretation but do not trace individual internal
recovery/slide/snap branches or establish unique normal-generation causality.
Explicit candidate/support 46° checks remain unchanged. AK remains failed, and
.42/+45° is unmeasured.

## Accepted fixed design

Eight ordinary-Walker profiles, each at most twenty settling plus 240 input
responses (2,080 total):

- .35 radius / .15 rise, both yaws: references.
- .42 radius / .15, .18 and .20 rises, both yaws: six study/control profiles.

Ordering and heights are fixed. No adaptive search, retries, candidate bodies,
step proposals or UP/lookahead candidate queries. Scoped observational support
queries are permitted. Each fixture, landing height and certificate must derive
from its actual rise; unchanged hard-coded .15 helpers are insufficient.

Qualified ordinary arrival is valid characterization. Blocked classification
requires sustained stall, grounded base support and an intended target witness.
Unresolved-at-cap is not blocked; fault/unrun-after-fault cannot become completion.
The spherical-cap model is heuristic. New heights are strictly below the planner's
.2499 m scalar rise ceiling, but native blocking and candidate feasibility are unknown.

## Implementation and selection boundary

A dedicated fixture/validator, preparation, supervisor and evidence-schema package
is assigned source-only. It needs independent review before any grant. Only after
native evidence review may the smallest eligible .18/.20 rise be selected, requiring
both yaws blocked and no unexplained reference contradiction; otherwise select none.
Any later assist campaign needs separately reviewed sources and fresh prerequisites.
No heavy grant is active. AK's failure, sixty unrun map journeys and unresolved
production motion accounting remain unchanged.
