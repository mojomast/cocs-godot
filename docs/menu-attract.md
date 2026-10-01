# Native menu in-engine scripted replay

The Godot home screen renders a silent, cosmetic **in-engine scripted replay**
behind its normal route, Settings, Career and Quit controls. A private 3D
`SubViewport` owns the current chapter's cropped production campaign terrain,
daylight, source operator and robot models, and the production story director
for Mara, Ivo and Patch (including poses and pet reactions). A bounded flash
uses a recorded combat event's position or source actor, not an invented menu
attack. The moving camera uses the recorded actor's yaw/pitch for FP clips and
an orbit for wide clips. These all run in
an animated 3D viewport. Its source is the compact version-1
authority replay at `res://ui/attract/demo.json`, documented in
`port/campaign/ATTRACT_DEMO.md`. This is recorded campaign activity presented
by Godot each frame, not live AI or a second campaign authority. The public
trailer remains an independent video; menu runtime uses no movie decoder.

The foreground remains usable immediately and never intercepts input. The
replay renderer has its own world, no physics picking, no audio, and a render
resolution capped at 960×540, updating at up to 18 frames per second. One
chapter world exists at a time; at most 3,200 local terrain triangles and 36
nearby cover pieces are constructed, yielding while terrain is assembled.
The existing menu music remains the only soundtrack. A dark base and
translucent shell keep route text legible; the stage letterboxes at 16:9.

Settings → **Animated menu background** is enabled by default; **Reduced
weather motion** also suppresses the replay. Older version-1 local settings
files receive the enabled default. Playback/render updates stop on Settings or
Career overlays, focus loss, minimization, hiding, route launch and scene exit.
If the replay file is absent or invalid, the normal dark menu stays usable and
the missing-file notice is printed once. No runtime path depends on tests,
Node, a capture generator, or external evidence.

`godot/tests/main_menu/contracts.gd` uses a headless mock stage for the
foreground and lifecycle contracts and checks the replay clip schema; final
integration uses `godot/tests/main_menu/live_attract.gd` under a visible display
with `COCS_ATTRACT_EVIDENCE` set to an absolute output directory. It loads the
packaged `demo.json`, captures two distinct rendered frames per chapter,
checks one isolated environment and one resident world through a full loop,
verifies Mara/Patch and the pet reaction serial, and compares a combat flash
with its recorded shot origin. It also exercises foreground route/focus,
settings/reduced-motion/animation toggles and focus-loss pause/resume.
