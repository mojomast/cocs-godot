extends SceneTree
## Native owner test; run only after the shared Godot import/runtime grant.
const Lifecycle = preload("res://sports/av_lifecycle.gd")
const HUD = preload("res://sports/hud.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("FAIL sports lifecycle: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var eye := Camera3D.new()
	host.add_child(eye)
	var audio := Lifecycle.new()
	host.add_child(audio)
	audio.configure(host, eye, {}, "puma-race", "fixture://local")
	var vehicle := {"id":7, "kind":"puma", "vx":8.0, "vz":0.0, "yaw":0.0}
	var actor := {"vehicleId":7, "health":100}
	audio.service.vehicle.apply_vehicle(vehicle, actor)
	audio.service.vehicle.event_plan({"type":"vehicle-shot"})
	check(audio.service.vehicle.engine.stream != null, "source vehicle voice assigned before restart")
	var score_stream: Variant = audio.service.music.orchestra.player.stream
	var weather_stream: Variant = audio.service.weather.get("_audio").stream
	audio.release_audio(true)
	check(audio.voice_status().playing == 0, "restart releases every active voice")
	check(audio.service.vehicle.engine.stream == null and audio.service.vehicle.report.stream == null, "transient vehicle playbacks detached")
	check(score_stream != null and audio.service.music.orchestra.player.stream == score_stream and audio.service.weather.get("_audio").stream == weather_stream, "persistent music/weather stream reinstated after mixer drain")
	audio.service.start_round("fixture-round-2")
	audio.service.bind_session(host, eye, {}, "puma-race", "fixture-round-2")
	audio.service.apply_snapshot({"time":0.0, "actors":[{"id":1, "health":100, "vehicleId":7}], "vehicles":[vehicle], "race":{"phase":"countdown", "countdown":3}}, 1)
	check(audio.service.scene == "explore" and audio.service.music.outcome.is_empty() and audio.service.weather.get("_focused") == true, "next confirmed round restores score scene and weather")
	check(audio.service.vehicle.engine.stream != null, "next round can reassign engine audio")
	audio.release_audio(false)
	check(audio.voice_status() == {"playing":0,"streams":0}, "leave detaches all stream handles")
	var hud := HUD.new()
	root.add_child(hud)
	root.size = Vector2i(760,520)
	root.content_scale_factor = 1.5
	for frame in 4: await process_frame
	hud.layout_results()
	var race := {"phase":"finished", "standings":[]}
	for i in 8: race.standings.append({"actorId":i, "position":i+1, "completedLaps":2})
	var state := {"mapId":"sirocco-circuit", "mapName":"Sirocco Circuit", "race":race, "overReason":"race-finish"}
	hud.update({"mode":"puma-race", "map_id":"sirocco-circuit", "map_name":"Sirocco Circuit", "state":state, "phase":"results", "actor_id":0})
	for frame in 4: await process_frame
	check(hud.result_panel.size.x > 0 and hud.result_panel.size.y > 0, "laid-out result panel has physical size")
	check(hud.result_panel.visible and not hud.top_panel.visible and not hud.bottom_panel.visible, "results own compact viewport")
	check(hud.result_panel.position.x >= 0 and hud.result_panel.position.y >= 0 and hud.result_panel.position.x + hud.result_panel.size.x <= hud.size.x + 0.1 and hud.result_panel.position.y + hud.result_panel.size.y <= hud.size.y + 0.1, "result panel remains inside UI150 viewport")
	check(hud.result_label.autowrap_mode != TextServer.AUTOWRAP_OFF and hud.result_label.text.contains("F5") and hud.title.text.contains("Sirocco"), "wrapped standings, restart and public venue")
	root.size = Vector2i(1280,800)
	root.content_scale_factor = 1.0
	for frame in 4: await process_frame
	hud.layout_results()
	for frame in 4: await process_frame
	check(hud.result_panel.size.x <= 680 and hud.result_panel.position.x >= 0, "wide panel remains bounded after resize")
	root.remove_child(hud)
	hud.free()
	root.remove_child(host)
	host.free()
	print("SPORTS_LIFECYCLE_RELEASE failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
