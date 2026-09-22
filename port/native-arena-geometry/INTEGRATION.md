# Integration findings for the session/authority owners

Geometry checks pass for all three generated assets (see `verification.json`).

The initial unmodified integrated graphical session could not start: `godot/native_arenas/demo.gd:on_lobby()` sent `fragLimit:100`, while `port/native-arenas/match.mjs:validateNativeConfig()` permits 5..50. The session owner has since aligned shipping configuration and its echoed-config check to 50. The first graphical attempt timed out without an authoritative pose; retain this as a resolved integration failure.

A temporary test-only session subclass using limit 15 produced preliminary Prism views with controls released (no visible weapon). It was removed after the shipping handshake was fixed. Final capture uses `res://native_arenas/demo.tscn` directly, five real bots, captured controls and the shared first-person rig. Screenshots and logs from each run are written to a unique timestamped folder.

Cold source navigation measurements on this host: Prism 378 nodes / 2.814s; Aurora 948 nodes / 39.892s; Cinder 369 nodes / 2.586s. Source Match caches navigation by collision hash afterward. Aurora's exact original collision meshes and source's all-pairs/segment scan make its first preparation expensive; account for this in launch/handshake timing. No source navigation or collision code was edited.

**Still requiring launch-owner handling:** the cold Aurora graphical session hit `Connection/round-start timed out. Relaunch to reconnect.` Final graphical capture therefore explicitly warms the existing source Match navigation cache before opening the socket. This is not evidence that the shipping cold-start timeout has been resolved. A launcher/authority warmup before announcing readiness or a sufficient preparation timeout is required; avoid a source-physics change to hide it.
