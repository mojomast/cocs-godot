extends "res://ui/scoreboard.gd"
const Progress = preload("res://arms_race/progress.gd")
var result := ""

func build_ui() -> void:
	super.build_ui()
	var header: HBoxContainer = rows_box.get_parent().get_child(3)
	header.get_child(2).text = "RUNG"

func clear_round() -> void:
	super.clear_round()
	result = ""

func apply_state(state: Dictionary, id: int, is_results: bool = false) -> void:
	super.apply_state(state, id, is_results)
	var actors: Array = state.get("actors", [])
	for entry: Dictionary in entries:
		var actor: Dictionary = actors[entry.order]
		var rung := Progress.integer(actor.get("ladder"), 0, Progress.COUNT)
		entry["rung_sort"] = rung
		entry.team = "%d/10" % mini(rung + 1, 10) if rung >= 0 else "—"
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.rung_sort != b.rung_sort: return a.rung_sort > b.rung_sort
		if a.frags_sort != b.frags_sort: return a.frags_sort > b.frags_sort
		return a.order < b.order)
	result = Progress.result_text(state) if is_results else ""
	dirty = true

func render() -> void:
	super.render()
	title.text = "ARMS RACE · RESULTS" if finished else "ARMS RACE · LADDER"
	if not result.is_empty(): summary.text += "\n" + result
