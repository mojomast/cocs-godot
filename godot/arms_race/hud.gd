extends "res://ui/game_hud.gd"
const Progress = preload("res://arms_race/progress.gd")
var progress := Progress.new()
var ladder_panel: PanelContainer
var ladder_title: Label
var ladder_next: Label
var ladder_note: Label
var ladder_bar: ProgressBar

func build_ui() -> void:
	super.build_ui()
	ladder_panel = panel()
	var box := stack(ladder_panel)
	ladder_title = label(21, ACCENT)
	ladder_next = label(16)
	ladder_note = label(13, MUTED)
	ladder_bar = gauge(ACCENT)
	ladder_bar.max_value = Progress.COUNT
	for item: Control in [ladder_title, ladder_bar, ladder_next, ladder_note]: box.add_child(item)

func bind_session(target: Node) -> void:
	super.bind_session(target)
	controls.text = "WASD move · Mouse aim · Click fire · R reload · Space jump · Shift sprint\nEsc release · Tab ladder · Release held actions, then click to resume · Loadout locked"

func on_started(frame: Dictionary) -> void:
	progress.clear()
	super.on_started(frame)
	show_progress()

func on_error(message: String) -> void:
	progress.clear()
	super.on_error(message)
	show_progress()

func apply_state(state: Dictionary, id: int) -> void:
	super.apply_state(state, id)
	progress.apply_state(state, id)
	show_progress()

func show_progress() -> void:
	ladder_title.text = progress.current
	ladder_next.text = progress.next
	ladder_note.text = progress.outcome if not progress.outcome.is_empty() else progress.transition
	ladder_bar.value = maxi(0, progress.rung)

func refresh_status() -> void:
	super.refresh_status()
	if not is_instance_valid(session) or ladder_panel == null: return
	ladder_panel.visible = int(session.phase) in [3,4,20]
	if int(session.phase) == 4: status_panel.hide() # Results/restart are in scoreboard.
	if int(session.phase) == 3 and not session.fresh.capture_allowed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		status_detail.text = "Release held movement/action buttons, then click to resume"

func resize() -> void:
	super.resize()
	if ladder_panel == null: return
	ladder_panel.position = Vector2(20, 70)
	ladder_panel.size = Vector2(get_viewport().get_visible_rect().size.x - 40, 0)
	status_panel.position.y = 194
