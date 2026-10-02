extends RefCounted
## Geometry-only recipe evaluator. Never reads gameplay or the scene tree.

static func point(raw: Array, motion: String, u: float, index: int, reduced: bool) -> Vector2:
	var p := Vector2(float(raw[0]), float(raw[1]))
	if reduced:
		return p * (0.94 + 0.06 * u)
	match motion:
		"track": p *= 1.2 - 0.25 * u
		"reel": p.x *= 1.0 - 0.65 * u; p.y *= 1.0 - u
		"ward": p.x += 0.22 * minf(u * 3.0, 1.0)
		"settle": p.y *= 0.8 + 0.2 * u
		"piston": p.x += 0.55 * minf(u * 4.0, 1.0); p.y += 0.08 * u
		"ember": p += Vector2(0.65 * u, 0.8 * u - 1.2 * u * u)
		"implode": p *= 1.35 - 0.95 * u; p = p.rotated(-0.5 * u)
		"brace": p.y *= 1.0 - 0.7 * u
		"petal_a": p = p.rotated(0.75 * u); p *= 0.65 + 0.5 * u
		"petal_b": p = p.rotated(-0.65 * u); p *= 0.7 + 0.45 * u
		"compress": p.y *= 1.0 - 0.8 * u; p.x += 0.22 * u * u
		"bubble": p.y += 0.5 * u; p.x += 0.05 * sin(u * PI + float(index))
		"sweep": p.x += 0.9 * u; p.y += 0.2 * u; p = p.rotated(-0.18 * u)
		"shear": p.x += 0.65 * u; p.y -= 0.16 * u
		"orbit": p = p.rotated(1.4 * u); p *= 0.85 + 0.3 * u
		"echo": p.x -= 0.45 * u
		"lock": p.x += 0.12 * floorf(u * 3.0)
		"lamella": p.x -= 0.18 * minf(u * 3.0, 1.0); p.y *= 1.15 - 0.25 * u
	return p

static func draw(mesh: ImmediateMesh, family: Dictionary, item: Dictionary, segment_cap: int, reduced: bool) -> int:
	mesh.clear_surfaces()
	var age: float = item.age
	var life: float = item.life
	var u := clampf(age / life, 0.0, 1.0)
	var color := Color(str(family.color))
	var mode: String = item.mode
	var opacity := 0.78 * (1.0 - u * u)
	if mode == "startup": opacity *= 0.55
	color.a = opacity
	var scale_value: float = item.scale
	var facing: float = item.facing
	var count := 0
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Small palette-independent level marker anchored outside the contact silhouette.
	# One underline = low, two downward slashes = overhead; mid has no extra marker.
	var level := str(item.get("level", "mid"))
	var marks: Array = []
	if level == "low": marks = [[Vector2(-0.22,-0.52),Vector2(0.22,-0.52)]]
	elif level == "overhead": marks = [[Vector2(-0.18,0.58),Vector2(-0.08,0.48)],[Vector2(0.08,0.58),Vector2(0.18,0.48)]]
	for mark in marks:
		var a: Vector2 = mark[0] * scale_value
		var b: Vector2 = mark[1] * scale_value
		var normal := Vector2(-(b-a).y,(b-a).x).normalized() * 0.014
		for v in [a-normal,a+normal,b+normal,a-normal,b+normal,b-normal]:
			mesh.surface_set_color(Color(0.95,0.95,0.95,opacity))
			mesh.surface_add_vertex(Vector3(v.x,v.y,0))
		count += 1
	if item.has("cable"):
		var source: Vector2 = item.cable
		for j in range(8):
			if count >= segment_cap: break
			var start := float(j) / 8.0
			var end := float(j + 1) / 8.0
			if item.operator == "qwen": end -= 0.045
			var a := source.lerp(Vector2.ZERO, start)
			var b := source.lerp(Vector2.ZERO, end)
			if item.operator == "chatgpt" and not reduced:
				a.y += sin(start * PI) * 0.08 * (1.0-u)
				b.y += sin(end * PI) * 0.08 * (1.0-u)
			var normal := Vector2(-(b-a).y,(b-a).x).normalized() * 0.009
			for v in [a-normal,a+normal,b+normal,a-normal,b+normal,b-normal]:
				mesh.surface_set_color(color)
				mesh.surface_add_vertex(Vector3(v.x,v.y,0))
			count += 1
	for segment in family.segments:
		var delay := float(segment.delay) * 0.25
		if u < delay: continue
		var local_u := clampf((u - delay) / (1.0 - delay), 0.0, 1.0)
		var points: Array = segment.points
		for j in range(points.size() - 1):
			if count >= segment_cap: break
			var a := point(points[j], str(segment.motion), local_u, j, reduced)
			var b := point(points[j + 1], str(segment.motion), local_u, j + 1, reduced)
			if item.get("shape_variant", "") == "palm":
				# Palm-band fan opens the split petals broadside and reverses the
				# interleaving order, distinct from the forward claw-band silhouette.
				a = Vector2(-a.y * 0.8, a.x * 1.25)
				b = Vector2(-b.y * 0.8, b.x * 1.25)
			# Common event grammar supplements the operator form, never replaces it.
			if mode == "guard": a.x *= 0.35; b.x *= 0.35
			elif mode == "tech":
				a.x += signf(a.x) * local_u * 0.35; b.x += signf(b.x) * local_u * 0.35
			elif mode == "release": a.y -= local_u * 0.25; b.y -= local_u * 0.25
			elif mode == "counter": a = a.rotated(0.3); b = b.rotated(0.3)
			elif mode == "whiff": a.y *= 0.45; b.y *= 0.45
			a *= scale_value; b *= scale_value
			a.x *= facing; b.x *= facing
			var normal := Vector2(-(b-a).y, (b-a).x).normalized() * float(segment.width) * scale_value * 0.5
			for v in [a-normal, a+normal, b+normal, a-normal, b+normal, b-normal]:
				mesh.surface_set_color(color)
				mesh.surface_add_vertex(Vector3(v.x, v.y, 0.0))
			count += 1
	mesh.surface_end()
	return count
