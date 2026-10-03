extends SceneTree
## Native-pending layout gate: production HUD methods, real initial core snapshot.
## Deliberately excludes rigs/world presentation; not a rendered gameplay proof.
class HudShell extends "res://fighting/main.gd":
	func _ready() -> void:
		add_child(layer)
		layer.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var shell := HudShell.new()
	root.add_child(shell)
	shell.roster = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	shell.simulation.configure(shell.roster,rules)
	shell.simulation.start_match({"operators":shell.operators,"stage_id":"test","seed":17,"training":true})
	shell.state = shell.simulation.snapshot()
	shell.mode = "training"
	shell.feedback.reset(shell.operators,shell.roster)
	shell._build_hud()
	for dimensions: Vector2i in [Vector2i(1280,800),Vector2i(760,520)]:
		root.size = dimensions
		root.content_scale_factor = 1.5 if dimensions.x==760 else 1.0
		for frame in 4: await process_frame
		shell._update_hud()
		for frame in 4: await process_frame
		shell._update_hud()
		var viewport := root.get_visible_rect()
		var bounds := shell.input_scroll.get_global_rect()
		assert(viewport.encloses(bounds),"training viewport stays inside safe height")
		assert(bounds.position.y>=shell.hud.get_global_rect().end.y,"training overlay never overlaps top HUD")
		assert(shell.timer_label.text.begins_with("Round 1"),"core round index is already one-based")
	shell.free()
	print("TRAINING_LAYOUT_OK")
	quit(0)
