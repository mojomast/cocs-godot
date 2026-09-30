extends SceneTree
## Repeated real Home instantiation with score already playing, then immediate
## ownership teardown; no UI click automation or fixture-only player stop.
const Menu = preload("res://ui/main_menu.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for index in 8:
		var menu := Menu.instantiate()
		root.add_child(menu)
		assert(menu.audiovisual.music != null)
		menu.audiovisual.music.start()
		menu.audiovisual.music.tick(0.1)
		menu.free()
		assert(not is_instance_valid(menu), "Home owns its AV service across rapid teardown")
	print("AUDIO_MENU_LIFETIME_OK menus=8")
	await create_timer(0.75).timeout
	quit(0)
