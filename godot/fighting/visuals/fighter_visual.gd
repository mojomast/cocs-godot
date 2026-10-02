extends Node3D
## Simulation-frame-driven, presentation-only robot animation adapter.
## Missing exports are reported through configure(false); no finished-art fallback.

const OPERATORS: Array[String] = ["chatgpt", "claude", "grok", "meta", "gemini", "deepseek", "mistral", "kimi", "qwen"]
const ASSET_ROOT := "res://fighting/assets/operators/"
const MothFinish = preload("res://source_operators/moth_finish/binder.gd")

var available: bool = false
var unavailable_reason: String = "not_configured"
var timing_status: String = "unavailable"
var operator_id: String = ""
var _model: Node3D
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _manifest: Dictionary = {}
var _clip_names: Dictionary = {}
var _current_clip: String = ""
var _meshes: Array[MeshInstance3D] = []
var _finish := MothFinish.new()
var finish_report: Dictionary = {}


func configure(id: String) -> bool:
	_clear()
	operator_id = id
	if not OPERATORS.has(id):
		return _unavailable("unknown_operator")
	var manifest_path := ASSET_ROOT + id + ".json"
	var asset_path := ASSET_ROOT + id + ".glb"
	if not FileAccess.file_exists(manifest_path) or not ResourceLoader.exists(asset_path):
		return _unavailable("animation_assets_not_exported")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return _unavailable("invalid_manifest")
	_manifest = parsed
	if int(_manifest.get("version", 0)) != 1 or str(_manifest.get("operator_id", "")) != id:
		return _unavailable("manifest_identity_mismatch")
	for data_name: String in ["roster", "rules"]:
		var data_path := "res://fighting/data/" + data_name + ".json"
		if _manifest.get("content_hashes", {}).get(data_name, "") != FileAccess.get_sha256(data_path):
			return _unavailable("stale_content_timing:" + data_name)
	var scene: PackedScene = load(asset_path) as PackedScene
	if scene == null:
		return _unavailable("scene_load_failed")
	_model = scene.instantiate() as Node3D
	if _model == null:
		return _unavailable("invalid_scene_root")
	add_child(_model)
	_collect(_model)
	if _player == null or _skeleton == null:
		return _unavailable("missing_animation_player_or_skeleton")
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.set_process(false)
	_player.set_physics_process(false)
	for imported_name: StringName in _player.get_animation_list():
		var key := String(imported_name).get_file()
		if _clip_names.has(key):
			return _unavailable("ambiguous_animation_name")
		_clip_names[key] = String(imported_name)
		var animation: Animation = _player.get_animation(imported_name)
		for track_index: int in range(animation.get_track_count()):
			if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
				return _unavailable("method_tracks_forbidden")
	for clip: String in _manifest.get("clips", {}):
		if not _clip_names.has(clip):
			return _unavailable("missing_clip:" + clip)
		var data: Dictionary = _manifest["clips"][clip]
		var keys: Array = data.get("seek_keys", [])
		if keys.size() < 2 or float(data.get("duration", 0.0)) <= 0.0:
			return _unavailable("invalid_seek_map:" + clip)
		for index: int in range(1, keys.size()):
			if float(keys[index][0]) <= float(keys[index - 1][0]) or float(keys[index][1]) < float(keys[index - 1][1]):
				return _unavailable("nonmonotonic_seek_map:" + clip)
	for socket: String in _manifest.get("sockets", {}):
		if _skeleton.find_bone(str(_manifest["sockets"][socket]["bone"])) < 0:
			return _unavailable("missing_socket_bone:" + socket)
	timing_status = str(_manifest.get("timing_status", "draft"))
	available = true
	unavailable_reason = ""
	finish_report = _finish.bind(_model, id)
	if not finish_report.get("installed", false):
		push_warning("Fighter Moth finish fallback %s: %s" % [id, finish_report.get("errors", [])])
	set_lod(0)
	reset()
	return true


func present(fighter: Dictionary, _alpha: float) -> void:
	if not available:
		return
	position = Vector3(float(fighter.get("x", 0)) / 1000.0, float(fighter.get("y", 0)) / 1000.0, 0.0)
	# Source -Z -> fighting +X. Rotate facing; never negative-scale a skeleton.
	_model.rotation.y = float(_manifest.get("root_yaw_right", -PI / 2.0))
	if int(fighter.get("facing", 1)) < 0:
		_model.rotation.y += PI
	var clip := str(fighter.get("animation", "idle"))
	if not _clip_names.has(clip) or not _manifest["clips"].has(clip):
		_model.visible = false
		unavailable_reason = "snapshot_clip_missing:" + clip
		return
	_model.visible = true
	unavailable_reason = ""
	var data: Dictionary = _manifest["clips"][clip]
	var animation: Animation = _player.get_animation(_clip_names[clip])
	var seconds := _presentation_seconds(fighter, data)
	if seconds < 0.0:
		_model.visible = false
		unavailable_reason = "invalid_pair_animation_timeline"
		return
	# Import resampling may slightly alter duration. Explicit phase knots remain
	# authoritative; scaling is against the declared authored duration only.
	seconds *= animation.length / float(data["duration"])
	if _current_clip != clip:
		_player.play(_clip_names[clip], 0.0)
		_current_clip = clip
	_player.seek(seconds, true, true)


func socket_world(name: String) -> Vector3:
	var key := name.trim_prefix("Socket_")
	if not available or not _manifest.get("sockets", {}).has(key):
		return global_position
	var socket: Dictionary = _manifest["sockets"][key]
	var bone := _skeleton.find_bone(str(socket["bone"]))
	var offset: Array = socket["offset"]
	return _skeleton.global_transform * (_skeleton.get_bone_global_pose(bone) * Vector3(float(offset[0]), float(offset[1]), float(offset[2])))


func reset() -> void:
	_current_clip = ""
	position = Vector3.ZERO
	if _player != null:
		_player.stop()
	if _skeleton != null:
		_skeleton.reset_bone_poses()
	if _model != null:
		_model.visible = available
		_model.rotation = Vector3(0.0, float(_manifest.get("root_yaw_right", -PI / 2.0)), 0.0)


func set_lod(level: int) -> void:
	var bit := 1 << clampi(level, 0, 2)
	for mesh: MeshInstance3D in _meshes:
		var prefix := String(mesh.name).get_slice("_", 0).trim_prefix("LOD")
		var mask := int(prefix) if prefix.is_valid_int() else 7
		mesh.visible = (mask & bit) != 0


func _presentation_seconds(fighter: Dictionary, data: Dictionary) -> float:
	# Entirely snapshot-derived: no remembered catch, elapsed timer, or recovery
	# cache that could disagree after load/rewind or on a newly configured visual.
	var clip := str(fighter.get("animation", "idle"))
	var state := str(fighter.get("state", ""))
	if state in ["throw_tech", "win", "lose", "knockdown", "wakeup"]:
		return _seek_seconds(float(fighter.get("animation_frame", 0)), data)
	var phase: Dictionary = fighter.get("pair_phase", {})
	if phase.is_empty():
		# Core must retain this optional attacker-only projection through recovery.
		# pair_phase itself continues to mean that both actors are currently held.
		phase = fighter.get("animation_pair_phase", {})
	if phase.is_empty():
		return _seek_seconds(float(fighter.get("animation_frame", 0)), data)
	var move := str(phase.get("move_id", ""))
	var id := int(fighter.get("id", -1))
	var attacker := id == int(phase.get("actor", -2)) and clip == move
	var victim := id == int(phase.get("target", -2)) and clip.begins_with("victim_") and clip.ends_with("_" + move)
	if move.is_empty() or not (attacker or victim):
		# A tech, KO, new attack or reaction cannot inherit an old pair clock.
		return _seek_seconds(float(fighter.get("animation_frame", 0)), data)
	for field: String in ["caught_move_frame", "damage_frame", "release_frame", "end_frame", "frame"]:
		var value: Variant = phase.get(field)
		if not (value is int or value is float):
			return -1.0
		if not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 0.0:
			return -1.0
	var caught := float(phase["caught_move_frame"])
	var damage := float(phase["damage_frame"])
	var release := float(phase["release_frame"])
	var end := float(phase["end_frame"])
	var frame := float(fighter.get("animation_frame", 0))
	if damage <= caught or release <= damage or end <= release or float(phase["frame"]) != frame:
		return -1.0
	var keys: Array = [[caught, 0.28], [damage, 0.68], [release, 0.82], [end, 1.0]]
	if caught > 0.0:
		keys.push_front([0.0, 0.0])
	return _seek_knots(frame, keys, false)


func _seek_seconds(frame: float, data: Dictionary) -> float:
	var keys: Array = data["seek_keys"]
	return _seek_knots(frame, keys, bool(data.get("loop", false)))


func _seek_knots(frame: float, keys: Array, loop: bool) -> float:
	var end_frame := float(keys[-1][0])
	var cursor := fposmod(frame, end_frame) if loop else clampf(frame, float(keys[0][0]), end_frame)
	for index: int in range(1, keys.size()):
		var left: Array = keys[index - 1]
		var right: Array = keys[index]
		if cursor <= float(right[0]):
			var fraction := (cursor - float(left[0])) / (float(right[0]) - float(left[0]))
			return lerpf(float(left[1]), float(right[1]), fraction)
	return float(keys[-1][1])


func _collect(node: Node) -> void:
	if node is AnimationPlayer:
		_player = node as AnimationPlayer
	elif node is Skeleton3D:
		_skeleton = node as Skeleton3D
	elif node is MeshInstance3D:
		_meshes.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect(child)


func _unavailable(reason: String) -> bool:
	available = false
	unavailable_reason = reason
	if _model != null:
		_model.visible = false
	return false


func set_team_color(color: Color) -> void:
	_finish.set_team_color(color)


func _clear() -> void:
	_finish.clear()
	finish_report.clear()
	available = false
	timing_status = "unavailable"
	_player = null
	_skeleton = null
	_meshes.clear()
	_clip_names.clear()
	_manifest.clear()
	_current_clip = ""
	if _model != null:
		remove_child(_model)
		_model.free()
		_model = null
