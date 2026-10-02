extends SceneTree
## Test supervisor's post-Leave real Home process, after authority/scene teardown.
var output := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	assert(not output.is_empty())
	root.size=Vector2i(760,520) if "--compact" in OS.get_cmdline_user_args() else Vector2i(1280,800)
	assert(change_scene_to_file("res://ui/main_menu.tscn")==OK)
	await scene_changed
	for i: int in 12: await process_frame
	assert(current_scene.scene_file_path=="res://ui/main_menu.tscn")
	assert(str(current_scene.registry_error).is_empty())
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join("home-return.png"))==OK)
	var file := FileAccess.open(output.path_join("home.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scene":current_scene.scene_file_path,"capturedUsec":Time.get_ticks_usec(),"newHomeOwnedSceneryPacks":root.find_children("BiomeExpansionFour","",true,false).size(),"restoredAfterOwnedCampaignExit":true}))
	print("SCENERY_HOME_READY")
	current_scene.quit_menu()
