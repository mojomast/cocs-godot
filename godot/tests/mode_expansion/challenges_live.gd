extends "res://mode_expansion/demo.gd"
## Real production scene observer. Only ordinary lifecycle/UI actions; source
## rounds end naturally. This script is outside the production export closure.
var proof_dir := ""
var proof_career: Node

func _ready() -> void:
	proof_dir = OS.get_environment("CHALLENGE_EVIDENCE")
	super._ready()
	call_deferred("journey")

func wait_phase(wanted: int, seconds: float = 70.0) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while phase != wanted and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert(phase == wanted, "Challenge journey phase deadline")

func capture_panel(category_id: String, name: String, compact: bool = false) -> void:
	get_window().size = Vector2i(960, 640) if compact else Vector2i(1280, 720)
	proof_career.select_category(category_id)
	proof_career.open_panel()
	await get_tree().process_frame
	assert(proof_career.active() and not can_capture_pointer())
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(proof_dir.path_join(name + ".png")) == OK)
	print("CHALLENGE_PANEL ", JSON.stringify({"category":category_id, "name":name, "modal":true, "controls":can_capture_pointer()}))
	proof_career.close_panel()

func journey() -> void:
	proof_career = get_tree().root.get_node("Career")
	await wait_phase(3)
	assert(not proof_career.challenges.is_empty())
	var reloaded := OS.get_environment("CHALLENGE_RELOAD") == "1"
	if reloaded:
		assert(int(proof_career.profile.get("matches", 0)) == 3)
		assert(proof_career.challenges.weekly.any(func(row: Dictionary) -> bool: return row.done))
		await capture_panel("challenges", "new-session-earned", true)
		print("CHALLENGE_RELOADED ", JSON.stringify({"xp":proof_career.profile.xp,"matches":proof_career.profile.matches,"challenges":proof_career.challenges}))
	else:
		await capture_panel("challenges", "initial-wide")
	for round_index in range(1 if reloaded else 3):
		await wait_phase(4)
		await get_tree().process_frame
		var award: Dictionary = proof_career.attributed_award()
		assert(not award.is_empty() and award.has("challenges"))
		print("CHALLENGE_SETTLED ", JSON.stringify({"round":round_index,"xp":proof_career.profile.xp,"matches":proof_career.profile.matches,"award":award,"challenges":proof_career.challenges}))
		await capture_panel("results", "round-%d-results" % round_index, round_index % 2 == 1)
		await capture_panel("challenges", "round-%d-challenges" % round_index, true)
		if round_index == 1 and not reloaded:
			var xp: int = proof_career.profile.xp
			client.peer.close(1000, "Challenge acceptance reconnect")
			await wait_phase(-5, 10.0)
			retry_seat()
			await wait_phase(4, 15.0)
			assert(int(proof_career.profile.xp) == xp)
			assert(proof_career.attributed_award().is_empty())
			await capture_panel("results", "reconnect-read-only", true)
			await capture_panel("challenges", "reconnect-earned", true)
			print("CHALLENGE_RECONNECT_OK")
		if round_index < (0 if reloaded else 2):
			request_restart()
			await wait_phase(3)
	print("CHALLENGE_JOURNEY_OK")
	get_tree().quit()
