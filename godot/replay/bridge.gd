extends Node
## No authority socket. Only the fixed source-demo presentation helper is launched.
signal reply(op: String, value: Dictionary)
signal failed(message: String)
const RUNTIME_FILES := ["game/demo.mjs", "godot/replay/admission.json", "tools/port/replay/adapter.mjs", "tools/port/replay/service.mjs"]
const RUNTIME_KIND := "read-only-source-demo-adapter"
var http := HTTPRequest.new()
var process_id := -1
var port := 0
var capability := ""
var ready_path := ""
var pending: Array[Dictionary] = []
var pending_sizes: Array[int] = []
var pending_bytes := 0
var busy := false
var active_op := ""
var active_epoch := 0
var startup_age := 0.0
var idle_age := 0.0
var stopped := false

static func runtime_plan(editor: bool, executable_dir: String, development_root: String, platform: String) -> Dictionary:
	var base := development_root if editor else executable_dir.path_join("replay-runtime")
	if not editor:
		var manifest_file := FileAccess.open(base.path_join("manifest.json"), FileAccess.READ)
		if manifest_file == null: return {"error":"Replay runtime manifest is missing from this installation."}
		if manifest_file.get_length() > 65536: return {"error":"Replay runtime manifest is invalid."}
		var parser := JSON.new()
		if parser.parse(manifest_file.get_as_text()) != OK: return {"error":"Replay runtime manifest is invalid."}
		var manifest: Variant = parser.data
		if not manifest is Dictionary or manifest.get("version") != 1 or manifest.get("kind") != RUNTIME_KIND or not manifest.get("files") is Dictionary:
			return {"error":"Replay runtime manifest is invalid."}
		var files: Dictionary = manifest.files
		if files.size() != RUNTIME_FILES.size(): return {"error":"Replay runtime must contain the exact four reviewed manifest paths."}
		var digest := RegEx.create_from_string("^[a-f0-9]{64}$")
		for path: String in RUNTIME_FILES:
			var expected: Variant = files.get(path)
			if not expected is String or digest.search(expected) == null:
				return {"error":"Replay runtime manifest hash is invalid: " + path}
			var installed := base.path_join(path)
			if not FileAccess.file_exists(installed): return {"error":"Replay runtime file is missing: " + path}
			if FileAccess.get_sha256(installed) != expected: return {"error":"Replay runtime file is corrupt: " + path}
	var helper := base.path_join("tools/port/replay/service.mjs")
	if not FileAccess.file_exists(helper): return {"error":"Replay source runtime is missing from this installation."}
	var bundled := executable_dir.path_join("node.exe" if platform == "Windows" else "node")
	if not editor and platform == "Windows" and not FileAccess.file_exists(bundled):
		return {"error":"Replay requires the bundled node.exe; reinstall this package."}
	return {"helper":helper, "node":bundled if FileAccess.file_exists(bundled) else "node"}

func startup_plan() -> Dictionary:
	# Only an editor build may discover checkout sources. An export never falls
	# back to res://../, its working directory, or an authority runtime.
	var editor := OS.has_feature("editor")
	var development_root := ProjectSettings.globalize_path("res://../") if editor else ""
	return runtime_plan(editor, OS.get_executable_path().get_base_dir(), development_root, OS.get_name())

func spawn_helper(node: String, arguments: PackedStringArray) -> int:
	return OS.create_process(node, arguments, false)

func _ready() -> void:
	add_child(http)
	http.timeout = 8.0
	http.body_size_limit = 2 * 1024 * 1024
	http.request_completed.connect(_completed)
	var plan := startup_plan()
	if plan.has("error"):
		_abort(str(plan.error))
		return
	var crypto := Crypto.new()
	capability = crypto.generate_random_bytes(32).hex_encode()
	var root := ProjectSettings.globalize_path("user://replays")
	DirAccess.make_dir_recursive_absolute(root.path_join("runtime"))
	ready_path = root.path_join("runtime/ready-" + crypto.generate_random_bytes(16).hex_encode() + ".json")
	process_id = spawn_helper(str(plan.node), PackedStringArray([str(plan.helper), root, ready_path, capability]))
	if process_id < 0: _abort("Could not start the local replay runtime.")

func send(request: Dictionary) -> bool:
	if stopped: return false
	var bytes := JSON.stringify(request).to_utf8_buffer().size()
	# Preserve delivered packets while amortizing HTTP overhead. Source Node still
	# owns the 18 Hz due decision; batching does not resample or drop events.
	if request.get("op") == "frame" and not pending.is_empty() and pending.back().get("op") in ["frame", "frames"]:
		var previous: Dictionary = pending.back()
		var frames: Array = previous.frames if previous.op == "frames" else [previous]
		if frames.size() < 32:
			var old_bytes: int = pending_sizes.back()
			var base_bytes: int = old_bytes if previous.op == "frames" else JSON.stringify({"op":"frames", "frames":frames}).to_utf8_buffer().size()
			var batch_bytes: int = base_bytes + bytes + 1 # comma plus exact JSON item bytes
			if batch_bytes < 512 * 1024 and pending_bytes - old_bytes + batch_bytes <= 4 * 1024 * 1024:
				frames.append(request.duplicate(true))
				pending[-1] = {"op":"frames", "frames":frames}
				pending_sizes[-1] = batch_bytes
				pending_bytes += batch_bytes - old_bytes
				return true
	if request.get("op") in ["seek", "speed"] and not pending.is_empty() and pending.back().get("op") == request.op:
		pending.pop_back()
		pending_bytes -= pending_sizes.pop_back()
	if pending.size() >= 32 or pending_bytes + bytes > 4 * 1024 * 1024:
		failed.emit("Replay queue is full; recording stopped. Save the delivered prefix.")
		return false
	pending.append(request.duplicate(true))
	pending_sizes.append(bytes)
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
	pending_bytes -= pending_sizes.pop_front()
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
		pending_sizes.clear()
		pending_bytes = 0
		return
	value["_epoch"] = active_epoch
	reply.emit(active_op, value)

func _abort(message: String) -> void:
	stopped = true
	pending.clear()
	pending_sizes.clear()
	pending_bytes = 0
	failed.emit(message)

func _exit_tree() -> void:
	stopped = true
	http.cancel_request()
	if process_id > 0 and OS.is_process_running(process_id): OS.kill(process_id)
	if not ready_path.is_empty() and FileAccess.file_exists(ready_path): DirAccess.remove_absolute(ready_path)
