extends "res://tests/asset_production/hosted.gd"
## Only captures/observes. All actor inputs pass through inherited send_input.
var review: Array = []

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
