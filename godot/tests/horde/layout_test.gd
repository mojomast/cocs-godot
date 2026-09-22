extends SceneTree
const Product = preload("res://horde/demo.tscn")
const LegacyBoard = preload("res://ui/scoreboard.gd")

func _initialize() -> void:
	call_deferred("probe")

func probe() -> void:
	var product := Product.instantiate()
	if "--legacy-layout" in OS.get_cmdline_user_args():
		var old := product.get_node("Scoreboard")
		product.remove_child(old)
		# This offline replacement is before _ready; its two field-created Nodes
		# have not yet been parented. Free them explicitly, unlike a live tree.
		old.panel.free()
		old.rows_box.free()
		old.free()
		var board := LegacyBoard.new()
		board.name = "Scoreboard"
		product.add_child(board)
	root.add_child(product)
	await process_frame
	await process_frame
	var actors := []
	for i in range(13):
		actors.append({"id":i,"name":"Player" if i==0 else "Husk","x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"pitch":0.0,"health":100 if i==0 else 0,"dead":0 if i==0 else 999,"frags":3 if i==0 else 0,"deaths":0 if i==0 else 1,"weapon":0,"ammo":["∞"]})
	var state := {"mapId":"meridian-exchange","config":{"mode":"horde"},"actors":actors,"over":true,
		"singleplayer":{"kind":"horde","phase":"won","winner":0,"wave":1,"waveTarget":1,"lives":3,"score":94,"enemiesAlive":0,"enemiesTotal":3}}
	product.client.actor_id = 0
	product.client.started.emit({})
	product.client.results.emit({"state":state})
	var failures := 0
	var checks := 0
	for size in [Vector2i(960,640),Vector2i(1280,800)]:
		root.size = size
		await process_frame
		await process_frame
		await process_frame
		var board: Node = product.get_node("Scoreboard")
		var rect: Rect2 = board.panel.get_rect()
		var strip: Rect2 = product.horde_label.get_rect()
		var help: Rect2 = product.get_node("GameHUD").controls.get_rect()
		var ok: bool = board.panel.visible and not strip.intersects(rect) and rect.end.y<=size.y and help.end.y<=size.y
		print("HORDE_LAYOUT_TEST ", JSON.stringify({"viewport":[size.x,size.y],"intersects":strip.intersects(rect),"bottom":rect.end.y,"controls_bottom":help.end.y,"page_size":board.page_size,"ok":ok}))
		checks += 1
		if not ok: failures += 1
	root.remove_child(product)
	product.free()
	print("HORDE_LAYOUT_CHECKS checks=",checks," failures=",failures," synthetic=true")
	quit(1 if failures else 0)
