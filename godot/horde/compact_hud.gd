extends "res://ui/game_hud.gd"
## Blackwater's small viewport keeps vitals below mission/choice content. All
## values and connection/death warnings still come from the shared HUD.
var full_controls := ""

func resize() -> void:
	super()
	var viewport := get_viewport().get_visible_rect().size
	var compact := viewport.x<850 or viewport.y<600
	if full_controls.is_empty(): full_controls = controls.text
	if not compact:
		health_bar.show(); armor_bar.show(); weapon_detail.show()
		for row: Array in [[health_label,22],[armor_label,17],[weapon_label,20],[ammo_label,23],[weapon_detail,13],[map_label,16],[score_label,14],[controls,13]]:
			row[0].add_theme_font_size_override("font_size",row[1])
		score_label.custom_minimum_size.x = 220
		controls.text = full_controls
		return
	for item: Label in [health_label,armor_label,weapon_label,ammo_label,weapon_detail]: item.add_theme_font_size_override("font_size",13)
	map_label.add_theme_font_size_override("font_size",12)
	map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	score_label.add_theme_font_size_override("font_size",11)
	score_label.custom_minimum_size.x = 130
	health_bar.hide(); armor_bar.hide()
	# Reload detail remains visible, rather than hiding an empty-ammo explanation.
	weapon_detail.show()
	var column := (viewport.x-48)/2.0
	vitals.position = Vector2(20,viewport.y-108)
	vitals.size = Vector2(column,0)
	weapon_panel.position = Vector2(28+column,viewport.y-108)
	weapon_panel.size = Vector2(column,0)
	controls.text = "WASD move · LMB fire · R reload · E repair · Q power\nEsc release · number keys choose upgrades · wheel weapons"
	controls.add_theme_font_size_override("font_size",11)
	controls.position.y = viewport.y-34
	controls.size = Vector2(viewport.x-40,32)
