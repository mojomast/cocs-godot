# Live in-engine menu demo

The owner explicitly requires the menu demo to render **in the engine beneath
the interface**. The public trailer remains a video. A movie, image sequence or
pre-rendered backdrop does not meet the menu requirement.

The menu owns an isolated 3D viewport, real campaign geometry, a cinematic camera,
production character/puppy visuals and bounded combat effects. Its scripted
sequence may replay recorded production-authority snapshots; it must be described
as an **in-engine scripted replay**, not a new live AI match. It never launches a
gameplay authority or intercepts menu controls. The existing menu music owns audio.

## Shared replay asset contract

Runtime path: `res://ui/attract/demo.json`. Version 1:

```text
{
  version: 1,
  fps: 12,
  provenance: {scripted: true, authorityRevision: string},
  clips: [{
    id: string, map: campaignMapId, kind: string,
    camera: "orbit" | "fp", duration: positiveSeconds,
    focus: {x,y,z},
    frames: [{t: secondsWithinClip,
              state: {time, actors, campaign},
              events: [authoritativeEvent]}]
  }]
}
```

`actors` retain the production fields needed for model/weapon/pose selection and
attack tells. `campaign.story` retains NPC, puppy, caption/prompt and pet reaction
serials. Each frame's `events` aggregates all original events since the previous
retained frame exactly once; downsampling must not discard hits or pet state.
The main menu need not display gameplay HUD, prompts or dialogue text; those are
shown in the trailer. Real-time animation/camera interpolation is rendered by
Godot rather than decoded from video.

Use a few short verified clips (terrain, operators/Patch and combat). Keep only
one chapter world resident, bound replay bytes/actors/events and stop updating
while hidden, unfocused, minimized or disabled. Respect reduced motion and the
Animated menu background setting. The underlying 3D world must not alter the
foreground UI's world, lights, camera or input. Missing/unready replay media
leaves the normal menu usable.

Trailer lane exports the versioned replay asset from verified capture states;
menu lane owns validation/playback/rendering. Parent verifies visible live 3D
motion under the real menu, button navigation, looping and cleanup.
