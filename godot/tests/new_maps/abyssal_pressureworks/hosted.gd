extends "res://tests/asset_production/hosted.gd"
## Only captures/observes. All actor inputs pass through inherited send_input.
var observed_respawn := false
var walk_clip_seconds := 0.0
var review: Array = []

func _process(delta: float) -> void:
 super._process(delta)
 if phase != 3 or role != "host": return
 var actor: Dictionary = presentation.local_actor
 if float(actor.get("deaths",0))>0 and float(actor.get("health",0))>0: observed_respawn = true
 if observed_respawn: walk_clip_seconds += delta
 capture_enabled = observed_respawn and walk_clip_seconds < 22

func foundry_hud_layout() -> void:
 # Use the same responsive layout for this private map as the reviewed worlds.
 if not is_instance_valid(objective_text.get_parent()): return
 var width := get_viewport().get_visible_rect().size.x-32
 var panel: Control = objective_text.get_parent()
 panel.size.x = maxf(240,width)
 for text: Label in [label,combat_label,objective_text]:
  text.custom_minimum_size.x = 0
  text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  text.add_theme_font_size_override("font_size",12 if width < 700 else 16)

func capture(label_name: String) -> void:
 if capture_root.is_empty() or capture_busy: return
 await super.capture(label_name)
 var size := get_viewport().get_visible_rect().size
 var clipped := 0
 var bounds: Array = []
 for control: Control in [label,combat_label,objective_text]:
  var rect := control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)
  var outside := control.is_visible_in_tree() and (rect.position.x<-.5 or rect.position.y<-.5 or rect.end.x>size.x+.5 or rect.end.y>size.y+.5)
  if outside: clipped += 1
  bounds.append({"name":control.name,"rect":str(rect),"visible":control.is_visible_in_tree(),"clipped":outside})
 review.append({"label":label_name,"ticksMs":Time.get_ticks_msec(),"viewport":str(size),"clipCounter":clipped,"bounds":bounds,"actor":presentation.local_actor.duplicate(true)})
 var file := FileAccess.open(capture_root.path_join("abyssal-native-review.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"map":"abyssal-pressureworks","geometryHash":expected_hash,"captures":review},"  "))
 print("ABYSSAL_HUD_CLIP_COUNTER ",clipped)

func on_results(frame: Dictionary) -> void:
 super.on_results(frame)
 if role == "host" and not capture_root.is_empty():
  while capture_busy: await get_tree().process_frame
  await capture("results")
