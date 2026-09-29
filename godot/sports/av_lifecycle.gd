extends Node
## Shared composition for the two standalone vehicle/sports sessions. The
## network owner supplies authority-confirmed state; this node never polls it.
const Service = preload("res://audio/av_service.gd")
const SettingsAccess = preload("res://ui/settings_access.gd")
var service
var owner: Node
var eye: Camera3D
var arena: Dictionary
var mode := ""
var endpoint := ""
var round_key := ""
var started := false

func configure(session: Node, camera: Camera3D, source_arena: Dictionary, match_mode: String, server: String) -> void:
	owner = session
	eye = camera
	arena = source_arena
	mode = match_mode
	endpoint = server
	service = Service.new()
	service.name = "NativeAudiovisual"
	add_child(service)
	var settings := SettingsAccess.service()
	if settings != null:
		settings.audio_preferences_changed.connect(service.apply_settings)
		service.apply_settings(settings.values)
	else: service.apply_settings({"mute":"--mute" in OS.get_cmdline_user_args() or "--mute-capture" in OS.get_cmdline_user_args()})

func begin(frame: Dictionary, room: String) -> void:
	var revision: Variant = frame.get("roundRevision")
	if not (revision is int or revision is float): return
	var key := "%s|%s|%s" % [endpoint, room, str(revision)]
	if key != round_key:
		round_key = key
		service.bind_session(owner, eye, arena, mode, key, int(revision))
	service.start_round(key)
	started = true

func snapshot(state: Dictionary, actor_id: int) -> void:
	if started: service.apply_snapshot(state, actor_id, true)

func events(items: Array) -> void:
	if started: service.apply_events(items)

func finish(state: Dictionary, actor_id: int) -> void:
	if started: service.finish_state(state, actor_id, mode)

func advance(delta: float, fresh: bool, focused: bool, overlay: bool) -> void:
	if not started: return
	if not focused:
		service.set_focus(false)
		return
	if not service.focused: service.set_focus(true)
	if not fresh or overlay:
		service.suspend("settings" if overlay else "stale_snapshot")
		return
	service.tick(delta)

func dropped() -> void:
	if started: service.suspend("transport")
