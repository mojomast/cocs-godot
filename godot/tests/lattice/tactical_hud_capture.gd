extends SceneTree
## Synthetic layout image only. No server, gameplay result or live intel claim.
const HUD = preload("res://lattice/world_tactical_hud.gd")

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	var output := ""
	var width := 1280
	var height := 720
	var mode := "ops"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output = arg.trim_prefix("--capture=")
		elif arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="): height = int(arg.trim_prefix("--height="))
		elif arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	if output.is_empty() or width < 760 or height < 520 or mode not in ["ops", "pvp"]:
		quit(2)
		return
	root.size = Vector2i(width, height)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color("102330")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	var fixture := Label.new()
	fixture.text = "SYNTHETIC RECIPIENT LAYOUT · NOT LIVE GAMEPLAY"
	fixture.position = Vector2(20, height * 0.48)
	fixture.add_theme_color_override("font_color", Color("668895"))
	layer.add_child(fixture)
	var hud := HUD.new()
	layer.add_child(hud)
	var projection := {"map":"monsoon-foundry","coop":mode == "ops","req":120,"flux":80,
		"context":{"revision":1,"actor":0},"source_sequence":10,
		"recruitment":{"phase":"peak","wave":3},
		"outcome":{"waves":{"cleared":2,"total":5},"hq":{"health":60,"max":100}},
		"threat":{"alive":7,"total":13,"wave_label":"DENIAL"},
		"dominance":{"team":1,"progress":22,"target":90,"breakCount":2},
		"recon_contacts":[{"id":2,"x":20,"z":5},{"id":3,"x":42,"z":8}]}
	var target := {"target_id":"front", "text":"Front · northeast · legal frontier; adjacency confirmed, supply LINKED."}
	var topology := {"by_id":{"front":{"id":"front","label":"Front", "x":20.0,"z":0.0,"capture_legal":true,"supply":"LINKED"}}}
	hud.present(projection, target, topology, {"x":0,"z":0,"health":100}, [{"kind":"buy","target":"sentry","status":"queued"}])
	for _frame: int in range(3): await RenderingServer.frame_post_draw
	var left := hud.objective_card.get_rect()
	var right := hud.status_card.get_rect()
	var bottom := hud.bottom.get_rect()
	if left.end.x > right.position.x or right.end.x > width or bottom.position.y < 0 or bottom.end.y > height:
		push_error("Tactical HUD clipped or overlapping viewport: %s / %s / %s" % [left, right, bottom])
		layer.free()
		quit(1)
		return
	var image := root.get_texture().get_image()
	var result := image.save_png(output)
	layer.free()
	for _frame: int in range(2): await RenderingServer.frame_post_draw
	print("TACTICAL_HUD_CAPTURE mode=",mode," size=",root.size)
	quit(result)
