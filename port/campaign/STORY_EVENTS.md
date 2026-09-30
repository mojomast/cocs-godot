# Scripted operator encounters and recurring puppy

User requests Sol implementation of additional scripted campaign events,
friendly operator NPCs, and a recurring puppy the player can pet.

## Shared implementation contract

- Server owns trigger state, dialogue timing, supported entity positions and
  successful pet interactions. Client renders snapshots without advancing story.
- Friendly story entities are separate from combat actors: they never enter
  hostile AI targeting, kill counts or objective-clear counts.
- Reuse existing playable operator visuals for friendly maintenance/rescue NPCs.
- Recurring puppy identity is `patch`; its displayed name is **Patch**. At least
  one reachable appearance in each chapter and a callback at the finale.
- Optional story beats must not block any mandatory objective or route. They
  should include varied staging and operator actions, beyond extra radio text.
- Use existing Interact input for nearby petting. A fresh press within reach and
  line of sight is required; no simultaneous objective activation. Prioritize a
  valid mandatory objective interaction over petting if ranges overlap.

## Additive wire shape

`snapshot.campaign.story` (version 1) contains:

```text
{
  version: 1,
  entities: [{id, kind: "operator"|"puppy", name, character?,
              x,y,z,yaw, pose, active, reactionSerial}],
  prompt: null | {entityId, action: "pet", text},
  caption: null | {id, speaker, text},
  completed: [string],
  pets: integer
}
```

Positions are authoritative feet coordinates. Entity IDs and caption IDs are
stable strings; `reactionSerial` increments only for an accepted interaction.
Client puppy reactions trigger on a fresh serial, never replaying after resync.
Supported initial poses: `idle`, `wave`, `work`, `point`, `sit`, `happy`, `walk`.
Authority may animate short authored paths but must validate terrain support.
Optional additions require documentation and matching validation on both sides.

Session-local story continuity travels through checkpoint retry and chapter
Continue; restart semantics must be explicit and tested. Input epochs remain
mandatory. No new client-provided position/trigger claims or trusted wire fields.

## Ownership and verification

- Sol authority lane: `port/native-campaign/` story content/controller, match and
  authority integration, scripted-event progression/interaction/continuity tests.
- Sol presentation lane: campaign story/pup visuals and dialogue/prompt widgets,
  minimal session/model integration, animation/lifecycle/compact-layout tests.
- Existing terrain recipes, robot combat roles and shared audio/music remain
  outside these lanes. Parent integrates hooks and registers verification gates.
- Heavy engine/import/simulation/render work is serialized. Capture-repair lane
  currently owns the slot; initial work is editing and lightweight checks only.
- Require actual-authority interaction proof and captures of NPC staging,
  repeated puppy appearances and petting before claiming the feature accepted.

## Presentation implementation

`godot/campaign/story_director.gd` consumes validated `campaign.story` snapshots.
It owns distinct non-colliding visual nodes for Patch and friendly source operators;
it never inserts them into `presentation.actors` or sends controls. The first
observed reaction serial (including after a chapter start or retry) is a baseline;
only a subsequent higher serial plays Patch's nuzzle/wag. Hidden/reappearing
entities keep their serial within a chapter. Long authority staging cuts hide
briefly before revealing rather than visibly sliding an actor across the map.
Wire JSON integer counters accept finite, nonnegative integer-valued numbers
(including float-decoded literals) up to 2,147,483,647 and are converted to
integers only after validation.
Patch's paws sit at the supplied authoritative feet coordinates; source
operators use the shared center-root offset of +0.9m above authoritative feet.
Patch uses a cached 12-segment/6-ring sphere per coat color (roughly 18 draws,
under 2,200 triangles at near LOD); distant face details are hidden and all
actors are distance culled. `story_widgets.gd` overlays
short caption and `[E] Pet Patch` from the authority prompt, with the actual
physical E interaction still handled by shared controls. The story overlay
is non-interactive, hides immediately for settings, focus loss, errors,
disconnect, death and terminal phases; pet prompts show only while controlling
the player. It does not take input focus or capture the pointer.

Lightweight contract/animation/compact-layout probe:
`godot --headless --path godot --script res://tests/campaign/story_presentation.gd`.
Authored visual fixture gallery (four chapter identities and repeated Patch):
`godot --path godot --script res://tests/campaign/story_gallery.gd`.
The gallery uses local synthetic snapshots solely for presentation review;
acceptance still requires proof against real authority snapshots.
