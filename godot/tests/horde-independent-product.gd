extends "res://tests/horde/live.gd"
## Same committed steering, with the actual product scene's Scoreboard retained.
var independent_layouts := {}

func picture(tag: String) -> void:
	if independent_layouts.has(tag): return
	independent_layouts[tag] = true
	await super.picture(tag)
	var scoreboard: Node = get_node("Scoreboard")
	print("HORDE_PRODUCT_LAYOUT ", JSON.stringify({"tag":tag,
		"viewport":[get_window().size.x,get_window().size.y],
		"scoreboard_visible":scoreboard.panel.visible,
		"scoreboard":[scoreboard.panel.position.x,scoreboard.panel.position.y,scoreboard.panel.size.x,scoreboard.panel.size.y],
		"horde":[horde_label.position.x,horde_label.position.y,horde_label.size.x,horde_label.size.y],
		"intersects":scoreboard.panel.visible and scoreboard.panel.get_rect().intersects(horde_label.get_rect())}))
