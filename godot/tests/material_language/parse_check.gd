extends SceneTree
## Fast parse/compile check for every material-language script. A parse error in
## a sheet/props helper would otherwise only surface minutes into a capture run.
const SCRIPTS := [
	"res://material_language/families.gd",
	"res://material_language/library.gd",
	"res://material_language/props.gd",
	"res://material_language/sheet.gd",
	"res://material_language/gallery.gd",
	"res://tests/material_language/validate.gd",
	"res://tests/material_language/gallery_capture.gd",
]

func _initialize() -> void:
	var failures: Array[String] = []
	for path: String in SCRIPTS:
		var script := load(path)
		if not script is GDScript:
			failures.append("not a script: " + path)
		elif not (script as GDScript).can_instantiate() and not (script as GDScript).is_abstract():
			failures.append("cannot instantiate: " + path)
	for failure: String in failures: push_error("MATERIAL_LANGUAGE_PARSE: " + failure)
	print("MATERIAL_LANGUAGE_PARSE_%s scripts=%d" % ["FAIL" if not failures.is_empty() else "OK", SCRIPTS.size()])
	quit(1 if not failures.is_empty() else 0)
