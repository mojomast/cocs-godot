extends "res://multiplayer_worlds/demo.gd"
## Ordinary native Input events -> unchanged production sampler -> WebSocket.
var out := ""
var guide_url := ""
var request: HTTPRequest
var requesting := false
var guide_elapsed := 0.0
var capture_elapsed := 0.0
var capture_index := 0
var capture_busy := false
var finished := false
var guide_frames := 0
var input_events := 0
var started_ms := 0
var frame_times: Array[float] = []
var native_events := {}
var visual := false
var clip_active := false
var capture_times: Array = []
var shot_labels := {}
var key_pulse := 0.0
var ui_checks: Array = []
var pending_shot := ""
func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--parallax-out="): out=arg.trim_prefix("--parallax-out=")
  if arg.begins_with("--parallax-guide="): guide_url=arg.trim_prefix("--parallax-guide=")
  if arg=="--parallax-visual": visual=true
 get_window().size=Vector2i(1280,800) if visual else Vector2i(640,400)
 request=HTTPRequest.new()
 add_child(request)
 request.request_completed.connect(on_guide)
 started_ms=Time.get_ticks_msec()
 super._ready()
 # Declared bounded software preset; production geometry/materials are intact.
 sun.shadow_enabled=false
 get_viewport().scaling_3d_scale=.65
 client.events.connect(func(items: Array) -> void:
  for item: Dictionary in items:
   var k := str(item.get("type","unknown"))
   native_events[k]=int(native_events.get(k,0))+1)
func on_lobby(frame: Dictionary) -> void:
 if phase==1:
  client.send_frame({"type":"host","mapId":"parallax-observatory","config":{"mode":selected_mode,"botCount":0,"timeLimit":900,"fragLimit":1 if selected_mode=="ctf" else 5,"startingWeapon":2,"unlimitedAmmo":true}})
  phase=2
  return
 if phase==2 and frame.get("players",[]).size()<2: return
 super.on_lobby(frame)
func key(code: int, pressed: bool) -> void:
 var e := InputEventKey.new()
 e.keycode=code
 e.physical_keycode=code
 e.pressed=pressed
 Input.parse_input_event(e)
 input_events+=1
func mouse(pressed: bool) -> void:
 var e := InputEventMouseButton.new()
 e.button_index=MOUSE_BUTTON_LEFT
 e.pressed=pressed
 e.position=Vector2(350,200)
 Input.parse_input_event(e)
 input_events+=1
func _process(delta: float) -> void:
 super._process(delta)
 key_pulse=maxf(0,key_pulse-delta)
 if key_pulse<=0: key(KEY_W,false)
 if finished: return
 if Time.get_ticks_msec()-started_ms>600000: fail("native watchdog"); return
 if not startup_error.is_empty(): fail(startup_error); return
 if phase==4:
  finished=true
  key(KEY_W,false)
  mouse(false)
  await finish()
  return
 if phase!=3 or not received_pose: return
 frame_times.append(delta*1000)
 guide_elapsed+=delta
 capture_elapsed+=delta
 if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED and can_capture_pointer(): mouse(true); mouse(false)
 if guide_elapsed>=.07 and not requesting:
  guide_elapsed=0
  requesting=true
  if request.request(guide_url+"/guide")!=OK: fail("guide request")
 if visual and not pending_shot.is_empty() and not capture_busy:
  var shot := pending_shot
  pending_shot=""
  shot_labels[shot]=true
  capture(shot)
 elif visual and clip_active and capture_elapsed>=.065 and not capture_busy:
  capture_elapsed=0
  capture_index+=1
  capture("frame-%05d"%capture_index)
func capture(label_name: String) -> void:
 if not visual or capture_busy: return
 capture_busy=true
 await RenderingServer.frame_post_draw
 var stamp := Time.get_ticks_msec()
 var result := get_viewport().get_texture().get_image().save_png(out.path_join(label_name+".png"))
 capture_times.append({"label":label_name,"ticksMs":stamp,"error":result})
 capture_busy=false
func on_guide(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
 requesting=false
 if finished or phase!=3: return
 if code!=200: fail("guide HTTP "+str(code)); return
 var g: Variant=JSON.parse_string(body.get_string_from_utf8())
 if not g is Dictionary: fail("guide decode"); return
 guide_frames+=1
 var e := InputEventMouseMotion.new()
 e.relative=Vector2(-wrapf(float(g.get("yaw",yaw))-yaw,-PI,PI),-(float(g.get("pitch",0))-pitch))/(.003*SettingsAccess.sensitivity())
 e.position=Vector2(350,200)
 Input.parse_input_event(e)
 input_events+=1
 key(KEY_W,bool(g.get("move",false)))
 key_pulse=(.4 if visual else .18) if bool(g.get("move",false)) else 0.0
 key(KEY_CTRL,bool(g.get("crouch",false)))
 mouse(bool(g.get("fire",false)))
 clip_active=bool(g.get("clip",false))
 var shot := str(g.get("shot",""))
 if not shot.is_empty() and not shot_labels.has(shot): pending_shot=shot
 if bool(g.get("finished",false)):
  finished=true
  key(KEY_W,false)
  mouse(false)
  finish()
func finish() -> void:
 if visual:
  var prefix := "results" if phase==4 else "gameplay"
  for compact in [false,true]:
   get_window().size=Vector2i(760,520) if compact else Vector2i(1280,800)
   SettingsAccess.service().set_value("ui_scale",150 if compact else 100,false)
   for i in range(5): await get_tree().process_frame
   check_ui(prefix+"-compact150" if compact else prefix+"-wide")
   await capture(prefix+"-compact150" if compact else prefix+"-wide")
   key(KEY_F1,true)
   key(KEY_F1,false)
   for i in range(3): await get_tree().process_frame
   check_ui("help-compact150" if compact else "help-wide")
   await capture("help-compact150" if compact else "help-wide")
   key(KEY_F1,true)
   key(KEY_F1,false)
 frame_times.sort()
 var report := {"map":current_id,"mode":selected_mode,"geometryHash":expected_hash,"roundResults":round_results,"objectiveText":objective_text.text,"guideFrames":guide_frames,"inputEvents":input_events,"captures":capture_times,"nativeEvents":native_events,"lastAck":client.last_ack,"renderer":RenderingServer.get_video_adapter_name(),"drawCalls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"frameMsP50":frame_times[frame_times.size()/2] if not frame_times.is_empty() else 0,"frameMsP95":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else 0,"uiChecks":ui_checks,"failures":[]}
 var file := FileAccess.open(out.path_join("native-journey.json"),FileAccess.WRITE)
 report["glbSha256"]=FileAccess.get_sha256("res://multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb")
 file.store_string(JSON.stringify(report,"  "))
 print("PARALLAX_NATIVE_OK ",JSON.stringify(report))
 client.disconnect_server()
 get_tree().quit()
func check_ui(label_name: String) -> void:
 var visible_rect := get_viewport().get_visible_rect()
 var rows: Array = []
 for node in get_tree().root.find_children("*","Label",true,false):
  if node is Label and node.is_visible_in_tree():
   var rect: Rect2=node.get_global_rect()
   var shown := rect
   var clipped := false
   var parent: Node=node.get_parent()
   while parent!=null:
    if parent is Control and parent.clip_contents:
     shown=shown.intersection(parent.get_global_rect())
     clipped=true
    parent=parent.get_parent()
   var fits: bool=shown.position.x>=0 and shown.position.y>=0 and shown.end.x<=visible_rect.end.x+1 and shown.end.y<=visible_rect.end.y+1
   rows.append({"text":node.text,"rect":str(rect),"visibleRect":str(shown),"scrollClipped":clipped,"fits":fits})
   if not fits: printerr("PARALLAX_UI_OVERFLOW ",label_name," ",node.text)
 ui_checks.append({"label":label_name,"window":str(get_window().size),"logicalViewport":str(visible_rect),"rows":rows})
func fail(note: String) -> void:
 if finished: return
 finished=true
 printerr("PARALLAX_NATIVE_FAIL ",note)
 client.disconnect_server()
 get_tree().quit(1)
