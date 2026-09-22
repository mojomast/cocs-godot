extends SceneTree
## Passive native scene observer. The runner supplies ordinary XTest input.
var demo: Node
var previous := ""
var elapsed := 0.0

func _initialize() -> void:
	call_deferred("attach")

func attach() -> void:
	demo = load("res://lattice/world_demo.tscn").instantiate()
	root.add_child(demo)

func _process(delta: float) -> bool:
	if not is_instance_valid(demo) or not is_instance_valid(demo.world_commands): return false
	elapsed += delta
	var panel: Control = demo.world_commands
	var record := {"phase":demo.phase,"focused":demo.application_focused,"eligible":demo.can_capture_pointer(),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"wait_release":demo.world_wait_release,"panel":panel.visible,"label":demo.label.text,"goal":demo.world_label.text,"receipt":panel.history.text,"ack":demo.client.last_ack,"seq":demo.client.last_snapshot_seq}
	# Ignore sequence/ACK for transition detection; include them in each record.
	var signature: String = JSON.stringify([record.phase,record.focused,record.eligible,record.captured,record.wait_release,record.panel,record.label,record.goal,record.receipt])
	if signature != previous or elapsed >= 1.0:
		previous = signature
		elapsed = 0.0
		record["monotonic_usec"] = Time.get_ticks_usec()
		record["controls"] = {}
		for name: String in ["nodes","hold_button","confirm_spend","spend_button"]:
			var control: Control = panel.get(name)
			var rect := control.get_global_rect()
			record.controls[name] = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
		if is_instance_valid(demo.get("world_panel")):
			var hud: Control = demo.get("world_panel")
			record["hud_rect"] = [hud.position.x,hud.position.y,hud.size.x,hud.size.y]
			record["hud_visible"] = hud.visible
		print("USABILITY_OBSERVE ", JSON.stringify(record))
	return false
