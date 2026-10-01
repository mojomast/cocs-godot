extends "res://tests/main_menu/live_attract.gd"
## Production menu and replay data, captured at --fixed-fps 30.
func run() -> void:
	output=OS.get_environment("COCS_ATTRACT_EVIDENCE")
	if output.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	var settings := root.get_node("LocalSettings")
	settings.set_value("attract_demo_enabled",true,false); settings.set_value("reduced_motion",false,false)
	menu=Menu.instantiate(); menu.preferences_path="user://actor_sequence_%d.json"%OS.get_process_id(); root.add_child(menu); current_scene=menu
	await wait_chapter(0)
	menu.attract_stage.advance_chapter(); await wait_chapter(1)
	require(menu.attract_stage.story_director.gestures.has("mara"),"Shared Mara controller in real menu")
	var controller: RefCounted = menu.attract_stage.story_director.gestures.mara
	for frame in 90:
		# Await exactly one draw. Waiting for both process and draw signals here
		# can consume two simulation frames per captured frame on this renderer.
		await RenderingServer.frame_post_draw
		require(root.get_texture().get_image().save_png(output+"/frame-%03d.png"%frame)==OK,"Menu frame %d"%frame)
	require(menu.attract_stage.story_director != null and menu.attract_stage.story_director.gestures.get("mara")==controller,"Snapshots preserve finite gesture controller")
	require(menu.start.visible and menu.settings_button.visible,"Foreground actions remain functional")
	menu.stop_attract()
	print("ACTOR_MENU_SEQUENCE frames=90 fps=30 checks=",checks," failures=",failures)
	quit(1 if failures else 0)
