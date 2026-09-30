# Native menu cinematic background

The Godot main menu plays `res://ui/attract/quiet-relay.ogv` in a looping,
silent `VideoStreamPlayer` behind its ordinary route, Settings, Career and Quit
controls. The video fits within the viewport at 16:9, with dark letterboxing
and a translucent menu shell for legible text at compact sizes and UI scale.
There is no idle trigger or menu input takeover; the existing menu music remains
the only audio source. The original browser menu also places its live showcase
behind the selection interface and offers a Menu showcase setting.

Settings → **Animated menu background** is enabled by default, and **Reduced
weather motion** also suppresses the moving background. Both settings persist
in the existing version-1 `user://local_settings.json`; older files get the
enabled default. No video is loaded in headless runs. If the asset is absent,
the menu retains its dark background and prints one `MENU_ATTRACT unavailable`
line; route launch and menu startup remain unaffected. Playback stops on
Settings/Career overlay, focus loss, minimization, hiding, route launch and
scene exit, and resumes when the menu is visible and focused again.

The trailer lane supplies the silent Theora file at that exact resource path.
`godot/tests/main_menu/contracts.gd` uses a mock-media switch on the menu
instance to exercise placement, foreground controls, preferences and lifecycle
without importing or decoding a movie. Once the clip lands, verify the actual
import and rendering in the packaged Godot build as well.
