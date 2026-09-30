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
