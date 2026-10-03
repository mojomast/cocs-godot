extends Node
## Shared composition for the two standalone vehicle/sports sessions. The
## network owner supplies authority-confirmed state; this node never polls it.
const Service = preload("res://audio/av_service.gd")
const SettingsAccess = preload("res://ui/settings_access.gd")
const PlaybackCleanup = preload("res://audio/playback_cleanup.gd")
var service
var session_host: Node
var eye: Camera3D
var arena: Dictionary
var mode := ""
var endpoint := ""
var round_key := ""
var started := false
var closed := false

func audio_players(node: Node) -> Array[Node]:
	var players: Array[Node] = []
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		players.append(node)
	for child: Node in node.get_children(): players.append_array(audio_players(child))
	return players

func voice_status() -> Dictionary:
	if not is_instance_valid(service): return {"playing":0, "streams":0}
	var playing := 0
	var streams := 0
	for player: Node in audio_players(service):
		if player.get("playing") == true: playing += 1
		if player.get("stream") != null: streams += 1
	return {"playing":playing, "streams":streams}

func release_audio(reuse: bool) -> void:
	if closed or not is_instance_valid(service): return
	# Stop event/loop voices and detach their streams before the Godot mixer
	# deletes pending playbacks. Persist only streams that are constructed once
	# at service startup and are required again on the next confirmed round.
	service.suspend("sports_restart" if reuse else "sports_exit")
	var retained: Dictionary = {}
	for player: Node in audio_players(service):
		var stream: Variant = player.get("stream")
		if reuse and (player == service.music.orchestra.player or player == service.weather.get("_audio") or player == service.moth_bed):
			retained[player] = stream
		player.call("stop")
		player.set("stream", null)
	PlaybackCleanup.drain()
	if reuse:
		for player: Node in retained:
			if is_instance_valid(player): player.set("stream", retained[player])
	else:
		started = false
		closed = true

func _exit_tree() -> void:
	release_audio(false)

func configure(session: Node, camera: Camera3D, source_arena: Dictionary, match_mode: String, server: String) -> void:
	session_host = session
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
	if closed: return
	var revision: Variant = frame.get("roundRevision")
	if not (revision is int or revision is float): return
	var key := "%s|%s|%s" % [endpoint, room, str(revision)]
	if key != round_key:
		round_key = key
		# start_round must see the *old* router identity. bind_session also
		# seeds the router; calling start_round afterwards would skip the new
		# explore/score reset and leave results audio active after F5.
		service.start_round(key)
		service.bind_session(session_host, eye, arena, mode, key, int(revision))
		var viewer: Variant = session_host.get("world")
		if is_instance_valid(viewer) and viewer is Node:
			service.weather.bind_presentation(viewer.get("world"), viewer.get("environment"), viewer.get("sun"))
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
