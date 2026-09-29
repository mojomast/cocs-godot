extends "res://ui/objective_hud.gd"
var zone_panel: PanelContainer
var zone_title: Label
var zone_detail: Label
var zone_hint: Label
var zone_progress: ProgressBar

func build_ui() -> void:
	super.build_ui()
	zone_panel = objective_panel
	var box := stack(zone_panel)
	zone_title = label(16, ACCENT)
	zone_detail = label(15)
	zone_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zone_detail.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	zone_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zone_title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	zone_hint = label(13, MUTED)
	zone_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zone_hint.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	zone_progress = gauge(ACCENT)
	for item: Control in [zone_title, zone_detail, zone_progress, zone_hint]: box.add_child(item)

func apply_state(state: Dictionary, local_id: int) -> void:
	super.apply_state(state, local_id)
	refresh_zone()

func refresh_zone() -> void:
	if not is_instance_valid(session): return
	var model: Dictionary = session.zones.text()
	zone_title.text = model.title
	zone_detail.text = model.detail
	zone_hint.text = model.hint
	var finished: bool = session.phase == 4
	zone_detail.visible = not finished
	zone_hint.visible = not finished
	zone_progress.visible = model.has("progress") and not finished
	zone_progress.value = model.get("progress", 0)
	zone_panel.size.y = 0
	layout_objective()

func refresh_status() -> void:
	super.refresh_status()
	if not is_instance_valid(session): return
	zone_panel.visible = session.phase in [3, 4] and not debug_hud
	refresh_zone()
	if session.phase == 4: status_panel.hide()

func resize() -> void:
	super.resize()
	if not is_instance_valid(zone_panel): return
	layout_objective()
