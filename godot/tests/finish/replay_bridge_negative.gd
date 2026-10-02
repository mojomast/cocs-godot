extends SceneTree
## Prepared native startup journey. Never run until the combined engine grant.
## Fixture modules are inert text; positive plans are inspected, never executed.
const Bridge = preload("res://replay/bridge.gd")
class Probe:
	extends "res://replay/bridge.gd"
	var fixture_bin := ""
	var checkout := ""
	var platform := "Linux"
	var launches := 0
	func startup_plan() -> Dictionary:
		return runtime_plan(false, fixture_bin, checkout, platform)
	func spawn_helper(_node: String, _arguments: PackedStringArray) -> int:
		launches += 1
		return -1

var checks := 0
var failures := 0
var base := ""
var manifest: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func restore() -> void:
	manifest = {"version":1, "kind":Bridge.RUNTIME_KIND, "files":{}}
	for path: String in Bridge.RUNTIME_FILES:
		var target := base.path_join("replay-runtime").path_join(path)
		put(target, "fixture " + path)
		manifest.files[path] = FileAccess.get_sha256(target)
	put(base.path_join("replay-runtime/manifest.json"), JSON.stringify(manifest))

func reject(label: String, platform: String = "Linux") -> void:
	var probe := Probe.new()
	probe.fixture_bin = base
	probe.checkout = base.path_join("checkout")
	probe.platform = platform
	var errors: Array[String] = []
	probe.failed.connect(func(message: String) -> void: errors.append(message))
	root.add_child(probe) # Real production _ready must reject before spawn_helper.
	await process_frame
	check(probe.stopped and errors.size() == 1 and not errors[0].is_empty(), label + ": readable rejection")
	check(probe.launches == 0 and probe.process_id == -1, label + ": no helper startup")
	check(probe.ready_path.is_empty() and probe.capability.is_empty(), label + ": no runtime handshake allocated")
	probe.free()

func _initialize() -> void: call_deferred("run")

func run() -> void:
	base = ProjectSettings.globalize_path("user://finish-bridge-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	# A perfectly discoverable checkout helper must not rescue an exported package.
	put(base.path_join("checkout/tools/port/replay/service.mjs"), "checkout sentinel")
	await reject("missing manifest with checkout available")
	restore()
	var plan := Bridge.runtime_plan(false, base, base.path_join("checkout"), "Linux")
	check(not plan.has("error") and plan.helper == base.path_join("replay-runtime/tools/port/replay/service.mjs") and plan.node == "node", "valid Linux plan is executable-relative")
	for path: String in Bridge.RUNTIME_FILES:
		restore()
		DirAccess.remove_absolute(base.path_join("replay-runtime").path_join(path))
		await reject("missing " + path)
		restore()
		put(base.path_join("replay-runtime").path_join(path), "corrupted bytes")
		await reject("corrupt " + path)
	restore()
	manifest.files["../checkout/tools/port/replay/service.mjs"] = "0".repeat(64)
	put(base.path_join("replay-runtime/manifest.json"), JSON.stringify(manifest))
	await reject("extra traversal manifest entry")
	restore()
	manifest.files.erase(Bridge.RUNTIME_FILES[0])
	manifest.files["authority.mjs"] = "0".repeat(64)
	put(base.path_join("replay-runtime/manifest.json"), JSON.stringify(manifest))
	await reject("substituted fourth manifest entry")
	restore()
	manifest.version = 2
	put(base.path_join("replay-runtime/manifest.json"), JSON.stringify(manifest))
	await reject("unsupported manifest version")
	restore()
	manifest.kind = "authority"
	put(base.path_join("replay-runtime/manifest.json"), JSON.stringify(manifest))
	await reject("wrong runtime kind")
	restore()
	put(base.path_join("replay-runtime/manifest.json"), "broken json")
	await reject("malformed manifest")
	restore()
	await reject("Windows missing bundled node", "Windows")
	put(base.path_join("node.exe"), "inert executable fixture")
	plan = Bridge.runtime_plan(false, base, "", "Windows")
	check(not plan.has("error") and plan.node == base.path_join("node.exe"), "Windows plan requires own bundled executable")
	plan = Bridge.runtime_plan(true, base, base.path_join("checkout"), "Linux")
	check(not plan.has("error") and plan.helper == base.path_join("checkout/tools/port/replay/service.mjs"), "explicit editor plan permits checkout")
	print("FINISH_REPLAY_BRIDGE_NEGATIVE ", checks, " checks / ", failures, " failures; fixtures ", base)
	quit(1 if failures else 0)
