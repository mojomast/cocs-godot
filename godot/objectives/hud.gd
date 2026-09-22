extends "res://ui/game_hud.gd"
## Objective-only composition of the shared combat HUD; legacy text stays observable.
var objective_panel: PanelContainer
var objective_title: Label
var objective_detail: Label
var objective_hint: Label
var objective_progress: ProgressBar

func build_ui() -> void:
	super.build_ui()
	objective_panel = panel()
	var box := stack(objective_panel)
	objective_title = label(18, ACCENT)
	objective_detail = label(16)
	objective_hint = label(13, MUTED)
	objective_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_hint.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	objective_hint.custom_minimum_size.y = 20
	objective_progress = gauge(WARNING)
	for item: Control in [objective_title, objective_detail, objective_progress, objective_hint]: box.add_child(item)
	clear_objective()

func clear_objective() -> void:
	objective_title.text = "OBJECTIVES · Waiting for authority"
	objective_detail.text = ""
	objective_hint.text = ""
	objective_progress.value = 0
	objective_progress.hide()

func on_started(frame: Dictionary) -> void:
	super.on_started(frame)
	clear_objective()

func on_error(message: String) -> void:
	super.on_error(message)
	clear_objective()

func apply_state(state: Dictionary, local_id: int) -> void:
	super.apply_state(state, local_id)
	var model: Dictionary = session.objectives.hud_model if is_instance_valid(session) else {}
	objective_title.text = model.get("title", "OBJECTIVES · Waiting for authority")
	objective_detail.text = model.get("detail", "")
	objective_hint.text = model.get("hint", "")
	objective_progress.visible = model.has("progress")
	objective_progress.value = model.get("progress", 0)

func refresh_status() -> void:
	super.refresh_status()
	if not is_instance_valid(session): return
	session.objective_label.visible = debug_hud
	objective_panel.visible = int(session.phase) in [3, 4] and not debug_hud
	if int(session.phase) == 4: status_panel.hide() # Scoreboard already supplies restart guidance.
	if int(session.phase) not in [3, 4]: clear_objective()
	if int(session.phase) == 3 and session.snapshot_watch.stale():
		clear_objective()
		objective_title.text = "OBJECTIVES · Waiting for fresh authority"

func resize() -> void:
	super.resize()
	if not is_instance_valid(objective_panel): return
	var viewport := get_viewport().get_visible_rect().size
	objective_panel.position = Vector2(20, 70)
	objective_panel.size = Vector2(viewport.x - 40, 0)
	status_panel.position.y = 186
