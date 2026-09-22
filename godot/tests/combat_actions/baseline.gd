extends SceneTree
## Reproduce the original missing-wire-fields defect from an immutable native
## session source file supplied by git show; never replaces the working session.
const Network = preload("res://net/client.gd")
class Recorder extends Network:
	var packet := {}
	func send_input(value: Dictionary) -> Error:
		packet = value.duplicate(true)
		return OK

func _initialize() -> void:
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): path = arg.trim_prefix("--source=")
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path)
	if script.reload() != OK:
		quit(1)
		return
	var session: Node = script.new()
	session.client.free()
	var recorder := Recorder.new()
	session.client = recorder
	for n: Node in [session.camera,session.label,session.selector,session.environment,session.sun,session.client,session.presentation,session.pickups,session.combat,session.combat_label]: session.add_child(n)
	session.phase = 3
	session.smoke = true
	session.received_pose = true
	session.snapshot_watch.observe()
	session.presentation.lifecycle.status = "alive"
	session._process(1.0/60.0)
	var missing: Array[String] = []
	for field: String in ["ads","power","melee","grenade","altFire"]:
		if not recorder.packet.has(field): missing.append(field)
	var absent: bool = not session.has_method("aim_requested")
	print("ORIGINAL_COMBAT_DEFECT ",JSON.stringify({"missing_fields":missing,"aim_contract_absent":absent,"original_packet":recorder.packet,"synthetic_transport":true}))
	session.free()
	quit(0 if absent and missing.size() == 5 else 1)
