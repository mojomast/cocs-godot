extends Node
## No authority socket. Only the fixed source-demo presentation helper is launched.
signal reply(op: String, value: Dictionary)
signal failed(message: String)
var http := HTTPRequest.new()
var process_id := -1
var port := 0
var capability := ""
var ready_path := ""
var pending: Array[Dictionary] = []
var pending_bytes := 0
var busy := false
var active_op := ""
var active_epoch := 0
var startup_age := 0.0
var idle_age := 0.0
var stopped := false

func _ready() -> void:
	add_child(http)
	http.timeout = 8.0
	http.body_size_limit = 2 * 1024 * 1024
	http.request_completed.connect(_completed)
	var base := ProjectSettings.globalize_path("res://../")
	var packaged := OS.get_executable_path().get_base_dir().path_join("replay-runtime")
	if FileAccess.file_exists(packaged.path_join("tools/port/replay/service.mjs")): base = packaged
	var helper := base.path_join("tools/port/replay/service.mjs")
	if not FileAccess.file_exists(helper):
		_abort("Replay source runtime is missing from this installation.")
		return
	var crypto := Crypto.new()
	capability = crypto.generate_random_bytes(32).hex_encode()
	var root := ProjectSettings.globalize_path("user://replays")
	DirAccess.make_dir_recursive_absolute(root.path_join("runtime"))
	ready_path = root.path_join("runtime/ready-" + crypto.generate_random_bytes(16).hex_encode() + ".json")
	var node := "node"
	var bundled := OS.get_executable_path().get_base_dir().path_join("node.exe" if OS.get_name() == "Windows" else "node")
	if FileAccess.file_exists(bundled): node = bundled
	process_id = OS.create_process(node, [helper, root, ready_path, capability], false)
	if process_id < 0: _abort("Could not start the local replay runtime.")

func send(request: Dictionary) -> bool:
	if stopped: return false
	# Preserve delivered packets while amortizing HTTP overhead. Source Node still
	# owns the 18 Hz due decision; batching does not resample or drop events.
	if request.get("op") == "frame" and not pending.is_empty() and pending.back().get("op") in ["frame", "frames"]:
		var previous: Dictionary = pending.back()
		var frames: Array = previous.frames.duplicate() if previous.op == "frames" else [previous]
		if frames.size() < 4:
			frames.append(request)
			var batch := {"op":"frames", "frames":frames}
			var batch_bytes := JSON.stringify(batch).to_utf8_buffer().size()
			var old_bytes := JSON.stringify(previous).to_utf8_buffer().size()
			if batch_bytes < 512 * 1024 and pending_bytes - old_bytes + batch_bytes <= 4 * 1024 * 1024:
				pending.pop_back()
				pending_bytes += batch_bytes - old_bytes
				pending.append(batch.duplicate(true))
				return true
	if request.get("op") in ["seek", "speed"] and not pending.is_empty() and pending.back().get("op") == request.op:
		pending_bytes -= JSON.stringify(pending.pop_back()).to_utf8_buffer().size()
	var bytes := JSON.stringify(request).to_utf8_buffer().size()
	if pending.size() >= 32 or pending_bytes + bytes > 4 * 1024 * 1024:
		failed.emit("Replay queue is full; recording stopped. Save the delivered prefix.")
		return false
	pending.append(request.duplicate(true))
	pending_bytes += bytes
	return true

func _process(delta: float) -> void:
	if stopped: return
	idle_age += delta
	if port == 0:
		startup_age += delta
		if FileAccess.file_exists(ready_path):
			var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ready_path))
			if value is Dictionary and value.get("port") is float and int(value.port) > 0 and int(value.port) < 65536:
				port = int(value.port)
			else: _abort("Invalid local replay handshake.")
		elif startup_age > 8.0: _abort("Local replay runtime did not become ready.")
		return
	if busy: return
	if pending.is_empty() and idle_age > 8.0: send({"op":"ping"})
	if pending.is_empty(): return
	var request: Dictionary = pending.pop_front()
	var text := JSON.stringify(request)
	pending_bytes -= text.to_utf8_buffer().size()
	active_op = str(request.op)
	active_epoch = int(request.get("_epoch", 0))
	busy = true
	idle_age = 0.0
	var code := http.request("http://127.0.0.1:%d/replay" % port, ["Content-Type: application/json", "Authorization: Bearer " + capability], HTTPClient.METHOD_POST, text)
	if code != OK: _abort("Local replay request could not be sent.")

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if stopped: return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_abort("Local replay transport failed. Existing saved clips are preserved.")
		return
	var value: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not value is Dictionary:
		_abort("Invalid local replay response.")
		return
	if value.get("ok") != true:
		# Keep helper alive so a capped/interrupted recording can still be saved.
		failed.emit(str(value.get("error", "Replay rejected")))
		pending.clear()
		pending_bytes = 0
		return
	value["_epoch"] = active_epoch
	reply.emit(active_op, value)

func _abort(message: String) -> void:
	stopped = true
	pending.clear()
	pending_bytes = 0
	failed.emit(message)

func _exit_tree() -> void:
	stopped = true
	http.cancel_request()
	if process_id > 0 and OS.is_process_running(process_id): OS.kill(process_id)
	if not ready_path.is_empty() and FileAccess.file_exists(ready_path): DirAccess.remove_absolute(ready_path)
