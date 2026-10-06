extends SceneTree
## Deterministic structural gate for audit finding F03 (decode-once protocol path).
##
## This does not measure runtime cost. It proves the source chain has exactly one
## `JSON.parse_string` and that it lives in the base hook, then proves each
## protocol subclass routes through `deliver_frame` and still hands the decoded
## frame to `super.deliver_frame` exactly once.
const CHAIN := {
	"net/client.gd": "res://net/client.gd",
	"native_arenas/client.gd": "res://native_arenas/client.gd",
	"campaign/client.gd": "res://campaign/client.gd",
}
const PARSE_CALL := "JSON.parse_string"
const DELIVER_DECL := "func deliver_frame("
const DELIVER_SUPER := "return super.deliver_frame(frame)"
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		check(false, "Cannot open decode-once chain source %s" % path)
		return ""
	return file.get_as_text()

func _initialize() -> void:
	var sources := {}
	var parses := {}
	for name: String in CHAIN:
		sources[name] = read_source(CHAIN[name])
		parses[name] = sources[name].count(PARSE_CALL)
	var total_parses := 0
	for name: String in parses:
		total_parses += parses[name]
	check(total_parses == 1, "Exactly one JSON.parse_string across the three-file chain (found %d)" % total_parses)
	check(parses.get("net/client.gd", 0) == 1, "The single parse occurs in net/client.gd")
	check(parses.get("native_arenas/client.gd", 0) == 0, "native_arenas/client.gd must not parse text")
	check(parses.get("campaign/client.gd", 0) == 0, "campaign/client.gd must not parse text")
	# Base and both subclasses must expose the decoded-frame hook.
	for name: String in CHAIN:
		check(sources[name].contains(DELIVER_DECL), "%s declares %s" % [name, DELIVER_DECL])
	# Subclass overrides must terminate by handing the frame to their super.
	for name: String in ["native_arenas/client.gd", "campaign/client.gd"]:
		check(sources[name].contains(DELIVER_SUPER), "%s calls %s" % [name, DELIVER_SUPER])
	# The parse itself must be inside the base hook, not a helper or a subclass.
	check(sources["net/client.gd"].contains("func decode_text(text: String) -> bool:"), "base decode_text is unchanged")
	print("DECODE_ONCE ", JSON.stringify({
		"ok": failures == 0,
		"checks": checks,
		"failures": failures,
		"parses": parses,
		"singleParseInBase": total_parses == 1 and parses.get("net/client.gd", 0) == 1,
	}))
	if failures == 0: print("DECODE_ONCE_OK")
	quit(0 if failures == 0 else 1)
