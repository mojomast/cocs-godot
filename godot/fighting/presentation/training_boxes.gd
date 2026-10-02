extends MeshInstance3D
## Authored active attack envelopes only. No collisions or authority decisions.
## Hurt/push rectangles are displayed only when explicitly supplied by the core.
func present(state: Dictionary, roster: Dictionary) -> void:
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var count := 0
	for fighter: Dictionary in state.get("fighters",[]):
		for profile: Dictionary in roster.get("operators",[]):
			if profile.id != fighter.operator_id: continue
			var move: Dictionary = profile.get("moves",{}).get(fighter.move_id,{})
			for box: Dictionary in move.get("hitboxes",[]):
				if int(fighter.move_frame) < int(box.from) or int(fighter.move_frame) > int(box.to): continue
				_rectangle(lines,box,fighter,Color("f2a35e"))
				count += 1
		for key: String in ["hurtboxes","pushboxes"]:
			for box: Dictionary in fighter.get(key,[]):
				_rectangle(lines,box,fighter,Color("64ccbd") if key == "hurtboxes" else Color("ad9de2"))
				count += 1
	if count > 0:
		lines.surface_end()
		mesh = lines
	else:
		mesh = null
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _rectangle(lines: ImmediateMesh, box: Dictionary, fighter: Dictionary, color: Color) -> void:
	# Content contract: x/y are facing-local lower-left, not box centers.
	var x := (float(fighter.x)+(float(box.x)+float(box.w)*0.5)*float(fighter.facing))/1000.0
	var y := (float(fighter.y)+float(box.y)+float(box.h)*0.5)/1000.0
	var w := float(box.w)/2000.0
	var h := float(box.h)/2000.0
	var points := [Vector3(x-w,y-h,0.35),Vector3(x+w,y-h,0.35),Vector3(x+w,y+h,0.35),Vector3(x-w,y+h,0.35)]
	for i: int in 4:
		lines.surface_set_color(color)
		lines.surface_add_vertex(points[i])
		lines.surface_set_color(color)
		lines.surface_add_vertex(points[(i+1)%4])
