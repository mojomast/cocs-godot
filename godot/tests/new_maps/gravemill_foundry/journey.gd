extends "res://multiplayer_worlds/demo.gd"
## Test-only stimulus. All actions use the production client's ordinary input
## serialization; snapshots and production presentation own the player pose.
var controls_path := ""
var capture_root := ""
var command_elapsed := 0.0
var receipt_elapsed := 0.0
var capture_elapsed := 0.0
var sent := 0
var frames := 0
var capture_busy := false
var capture_enabled := false
var captured_labels := {}
var role := "host"
var vehicle_event_ids := {}

func _ready() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--foundry-controls="): controls_path = arg.trim_prefix("--foundry-controls=")
  if arg.begins_with("--foundry-capture="): capture_root = arg.trim_prefix("--foundry-capture=")
  if arg.begins_with("--foundry-role="): role = arg.trim_prefix("--foundry-role=")
 super._ready()
 client.events.connect(func(items: Array) -> void:
  for event: Dictionary in items:
   if event.get("type") == "vehicle-shot": vehicle_event_ids[event.id] = true
 )
 var settings := SettingsAccess.service()
 if settings != null: settings.set_value("ui_scale",150 if "--foundry-compact" in OS.get_cmdline_user_args() else 100,false)
 if not capture_root.is_empty():
  DirAccess.make_dir_recursive_absolute(capture_root)
  # Bounded software capture preset. Keep 1280x800 UI, reduce 3D raster work;
  # default-lighting architectural stills use inspection.gd independently.
  sun.shadow_enabled = false
  get_viewport().scaling_3d_scale = .75

func on_lobby(frame: Dictionary) -> void:
 if phase == 1:
  var target := 3 if selected_mode in ["payload", "assault"] else 50 if selected_mode == "combined-arms" else 10 if selected_mode == "domination" else 5
  client.send_frame({"type":"host", "mapId":current_id, "config":{"mode":selected_mode,"botCount":0,"timeLimit":900,"fragLimit":target}})
  phase = 2
  return
 if phase == 2 and frame.get("players", []).size() < 2: return
 super.on_lobby(frame)

func _process(delta: float) -> void:
 if has_method("foundry_hud_layout"): call("foundry_hud_layout")
 if phase != 3:
  super._process(delta)
  return
 command_elapsed += delta
 # Smooth only the review camera's angle; source input/actor state is untouched.
 camera.rotation = Vector3(lerp_angle(camera.rotation.x, pitch, 1.0-exp(-10.0*delta)), lerp_angle(camera.rotation.y, yaw, 1.0-exp(-10.0*delta)), 0)
 receipt_elapsed += delta
 capture_elapsed += delta
 if command_elapsed >= .05:
  command_elapsed = 0
  var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(controls_path)) if FileAccess.file_exists(controls_path) else {}
  if command is Dictionary:
   var input: Dictionary = command.get("input", {})
   yaw = float(input.get("yaw", yaw))
   pitch = float(input.get("pitch", pitch))
   if client.send_input(input) == OK: sent += 1
   if command.get("shot", "") != "" and not captured_labels.has(str(command.shot)) and not capture_busy:
    captured_labels[str(command.shot)] = true
    capture(str(command.shot))
   capture_enabled = bool(command.get("clip", false))
 if capture_enabled and not capture_root.is_empty() and capture_elapsed >= 1.0 / 20.0 and not capture_busy:
  capture_elapsed = 0
  capture("frame-%06d" % frames)
  frames += 1
 if receipt_elapsed >= 1:
  receipt_elapsed = 0
  print("FOUNDRY_NATIVE_INPUT ", JSON.stringify({"role":role,"actor":client.actor_id,"hash":expected_hash,"sent":sent,"ack":client.last_ack,"pose":presentation.local_actor,"camera":str(camera.global_position),"frames":frames,"engineFrames":Engine.get_frames_drawn(),"ticksMs":Time.get_ticks_msec(),"vehicleShotEvents":vehicle_event_ids.size()}))

func capture(label_name: String) -> void:
 if capture_root.is_empty() or capture_busy: return
 capture_busy = true
 await RenderingServer.frame_post_draw
 var error := get_viewport().get_texture().get_image().save_png(capture_root.path_join(label_name + ".png"))
 print("FOUNDRY_NATIVE_CAPTURE ", JSON.stringify({"label":label_name,"error":error,"hash":expected_hash,"camera":str(camera.global_position),"actor":presentation.local_actor,"ticksMs":Time.get_ticks_msec(),"viewport":str(get_viewport().get_visible_rect().size),"uiScale":get_window().content_scale_factor,"hudBounds":[str(label.get_global_rect()),str(combat_label.get_global_rect()),str(objective_text.get_global_rect())]}))
 capture_busy = false

func on_results(frame: Dictionary) -> void:
 print("FOUNDRY_NATIVE_RESULTS ", JSON.stringify({"role":role,"hash":expected_hash,"mode":selected_mode,"sent":sent,"ack":client.last_ack,"vehicleShotEvents":vehicle_event_ids.size(),"state":frame.state}))
 super.on_results(frame)

func on_error(message: String) -> void:
 push_error("FOUNDRY_NATIVE_ERROR " + message)
 super.on_error(message)
 get_tree().quit(2)
