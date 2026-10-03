extends "res://tests/asset_production/hosted.gd"
## Vesper-only capture extension. Production ordinary input and source poses stay
## in the canonical parent fixture; this observes health and screen rectangles.
var observed_dead := false
var observed_respawn := false
var walk_clip_seconds := 0.0
var review: Array = []

func _process(delta: float) -> void:
 super._process(delta)
 if phase != 3 or role != "host": return
 var actor: Dictionary = presentation.local_actor
 # Initial presentation may briefly contain the constructor's zero-health seat.
 # Only the source death counter distinguishes a real round death from startup.
 if float(actor.get("deaths",0))>0: observed_dead = true
 if observed_dead and float(actor.get("health",0))>0: observed_respawn = true
 if observed_respawn: walk_clip_seconds += delta
 # Capture real post-respawn movement instead of only the idle victim setup.
 capture_enabled = observed_respawn and walk_clip_seconds < 22

func capture(label_name: String) -> void:
 if capture_root.is_empty() or capture_busy: return
 await super.capture(label_name)
 var size := get_viewport().get_visible_rect().size
 var clipped := 0
 var bounds: Array = []
 for control: Control in [label,combat_label,objective_text]:
  var rect := control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,control.size)
  var outside := control.is_visible_in_tree() and (rect.position.x < -.5 or rect.position.y < -.5 or rect.end.x > size.x+.5 or rect.end.y > size.y+.5)
  if outside: clipped += 1
  bounds.append({"name":control.name,"rect":str(rect),"visible":control.is_visible_in_tree(),"clipped":outside})
 review.append({"label":label_name,"ticksMs":Time.get_ticks_msec(),"viewport":str(size),"clipCounter":clipped,"bounds":bounds,"actor":presentation.local_actor.duplicate(true)})
 var file := FileAccess.open(capture_root.path_join("vesper-native-review.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"map":"vesper-viaduct","geometryHash":expected_hash,"captures":review},"  "))
 print("VESPER_HUD_CLIP_COUNTER ",clipped)

func on_results(frame: Dictionary) -> void:
 super.on_results(frame)
 if role == "host" and not capture_root.is_empty():
  while capture_busy: await get_tree().process_frame
  await capture("results")
