extends SceneTree
## Evidence helper: list differing pixels inside one rectangle of two PNGs.
## Usage: godot --headless --path godot --script <this> -- A.png B.png x y w h
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		print("usage: A.png B.png x y w h")
		quit(2)
		return
	var a := Image.load_from_file(args[0])
	var b := Image.load_from_file(args[1])
	if a == null or b == null or a.get_size() != b.get_size():
		print("image load/size mismatch")
		quit(2)
		return
	var rect := Rect2i(int(args[2]), int(args[3]), int(args[4]), int(args[5]))
	var counts := {"changed": 0}
	var samples: Array = []
	for y in range(rect.position.y, mini(rect.end.y, a.get_height())):
		for x in range(rect.position.x, mini(rect.end.x, a.get_width())):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var delta := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			if delta <= 0.02: continue
			counts.changed += 1
			if samples.size() < 24: samples.append([x, y, str(ca), str(cb)])
	print("changed=", counts.changed)
	for sample: Array in samples: print(sample)
	quit(0)
