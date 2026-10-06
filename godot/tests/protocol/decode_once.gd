extends SceneTree
## Deterministic structural gate for audit finding F03 (decode-once protocol path).
##
## This does not measure runtime cost. It proves the source chain has exactly one
## JSON parse entry point, that it lives in the base hook, and that each protocol
## subclass routes through `deliver_frame` and hands the decoded frame to
## `super.deliver_frame` exactly once.
##
## Counting runs on a lexed view of each file: `#` comments and string literals
## are blanked first, so documenting the old code (or naming the API inside a
## string) can no longer change a verdict. The checker's own logic is exercised
## by the self-test table below, which keeps the negative controls permanent.
##
## KNOWN LIMITS (accepted, not closed by this gate):
##   * A parse reached only through a callable/reflection indirection, or via a
##     JSON API whose spelling differs from the tokens below, is not detected.
##     The token list is a denylist, not a proof of absence.
##   * Structural presence of `super.deliver_frame` is not proof that the base
##     state machine runs semantically once. A subclass can still swallow a
##     frame type, reorder a check against the base envelope contract, or return
##     `true` early and skip dispatch entirely while satisfying every rule here.
##   * Only the three-file chain is covered. `horde/client.gd` and
##     `lattice/transport.gd` deliberately keep their own text path and are not
##     gated, so those routes are still not decode-once.
##   * No runtime behaviour is measured here; frame-level parity is covered by
##     `tests/campaign/client.gd` and
##     `tests/native_arenas/protocol/client_contract.gd`.

const CHAIN := {
	"net/client.gd": "res://net/client.gd",
	"native_arenas/client.gd": "res://native_arenas/client.gd",
	"campaign/client.gd": "res://campaign/client.gd",
}
const BASE_KEY := "net/client.gd"

# Any spelling of a JSON text parser. The base is allowed exactly one and it must
# be the static call; a subclass is allowed none.
const PARSE_STATIC := "JSON.parse_string"
const PARSE_ALT_CTOR := "JSON.new("
const PARSE_ALT_METHOD := ".parse("
const DELIVER_DECL := "func deliver_frame("
const SUPER_DELIVER := "super.deliver_frame"
const SUPER_DECODE := "return super.decode_text("
const BASE_DECODE_DECL := "func decode_text(text: String) -> bool:"

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

# ---------------------------------------------------------------------------
# Lexer: blank `#` comments and string literals, preserving newlines so that
# tokens either side of a blanked span cannot be spliced into one another.
# ---------------------------------------------------------------------------
static func strip_comments_and_strings(text: String) -> String:
	var out := ""
	var i := 0
	var n := text.length()
	while i < n:
		var ch := text[i]
		if ch == "#":
			while i < n and text[i] != "\n":
				out += " "
				i += 1
			continue
		if ch == "\"" or ch == "'":
			var quote := ch
			var triple := i + 2 < n and text[i + 1] == quote and text[i + 2] == quote
			if triple:
				out += "   "
				i += 3
				while i < n:
					if text[i] == quote and i + 2 < n and text[i + 1] == quote and text[i + 2] == quote:
						out += "   "
						i += 3
						break
					out += "\n" if text[i] == "\n" else " "
					i += 1
				continue
			out += " "
			i += 1
			while i < n:
				if text[i] == "\\" and i + 1 < n:
					out += "  "
					i += 2
					continue
				if text[i] == quote:
					out += " "
					i += 1
					break
				out += "\n" if text[i] == "\n" else " "
				i += 1
			continue
		out += ch
		i += 1
	return out

static func parse_entry_points(code: String) -> Array[String]:
	var found: Array[String] = []
	for token: String in [PARSE_STATIC, PARSE_ALT_CTOR, PARSE_ALT_METHOD]:
		if code.contains(token): found.append(token)
	return found

# Pure checker. Returns the list of failures for one file; empty means clean.
static func analyze_source(key: String, text: String) -> Array[String]:
	var found: Array[String] = []
	var code := strip_comments_and_strings(text)
	var parses := parse_entry_points(code)
	if key == BASE_KEY:
		if parses.size() != 1:
			found.append("%s must own exactly one JSON parse entry point, found %d %s" % [key, parses.size(), str(parses)])
		elif not parses.has(PARSE_STATIC):
			found.append("%s single parse must be %s, found %s" % [key, PARSE_STATIC, str(parses)])
		if not code.contains(BASE_DECODE_DECL):
			found.append("%s must keep the base decode_text declaration" % key)
	else:
		if not parses.is_empty():
			found.append("%s must not parse text, found %s" % [key, str(parses)])
		var supers := code.count(SUPER_DELIVER)
		if supers != 1:
			found.append("%s must hand the frame to the base exactly once, found %d %s" % [key, supers, SUPER_DELIVER])
		var decode_handoffs := code.count(SUPER_DECODE)
		if decode_handoffs != 1:
			found.append("%s must hand the text to the base exactly once, found %d %s" % [key, decode_handoffs, SUPER_DECODE])
	var decls := code.count(DELIVER_DECL)
	if decls != 1:
		found.append("%s must declare exactly one %s, found %d" % [key, DELIVER_DECL, decls])
	return found

# ---------------------------------------------------------------------------
# Self-tests: every rule above, plus every evasion it is meant to close.
# ---------------------------------------------------------------------------
const SNIPPET_BASE_HONEST := "func decode_text(text: String) -> bool:\n\tvar value: Variant = JSON.parse_string(text)\n\treturn deliver_frame(value)\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\treturn true\n"
const SNIPPET_SUBCLASS_HONEST := "func decode_text(text: String) -> bool:\n\tif text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return fail(\"Oversized frame\")\n\treturn super.decode_text(text)\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\tif frame.get(\"type\") == \"start\": pass\n\treturn super.deliver_frame(frame)\n"
const SNIPPET_DOUBLE_SUPER := "func decode_text(text: String) -> bool:\n\treturn super.decode_text(text)\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\tif not super.deliver_frame(frame): return false\n\treturn super.deliver_frame(frame)\n"
const SNIPPET_COMMENT_ONLY := "# this layer used to call JSON.parse_string per packet\n## and also JSON.new( with .parse( inline\nfunc decode_text(text: String) -> bool:\n\treturn super.decode_text(text)\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\treturn super.deliver_frame(frame)\n"
const SNIPPET_STRING_ONLY := "const LEGACY := \"JSON.parse_string\" # JSON.new( and .parse(\nfunc decode_text(text: String) -> bool:\n\treturn super.decode_text(text)\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\treturn super.deliver_frame(frame)\n"
const SNIPPET_ALT_PARSE := "func decode_text(text: String) -> bool:\n\tvar j := JSON.new()\n\tif j.parse(text) != OK: return fail(\"Malformed JSON envelope\")\n\treturn super.decode_text(text)\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\treturn super.deliver_frame(frame)\n"
const SNIPPET_SUBCLASS_PARSE := "func decode_text(text: String) -> bool:\n\tvar peek: Variant = JSON.parse_string(text)\n\treturn super.decode_text(text)\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\treturn super.deliver_frame(frame)\n"
const SNIPPET_NO_SUPER := "func decode_text(text: String) -> bool:\n\treturn super.decode_text(text)\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\tif frame.get(\"type\") == \"start\": return true\n\treturn true\n"
const SNIPPET_NO_HANDOFF := "func decode_text(text: String) -> bool:\n\treturn true\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\treturn super.deliver_frame(frame)\n"
const SNIPPET_SEMANTIC_SWALLOW := "func decode_text(text: String) -> bool:\n\treturn super.decode_text(text)\n\nfunc deliver_frame(frame: Dictionary) -> bool:\n\tif frame.get(\"type\") == \"start\": return true\n\treturn super.deliver_frame(frame)\n"

func self_tests() -> Dictionary:
	var cases: Array = [
		{"case": "base-honest", "key": BASE_KEY, "text": SNIPPET_BASE_HONEST, "expect": "pass"},
		{"case": "subclass-honest", "key": "campaign/client.gd", "text": SNIPPET_SUBCLASS_HONEST, "expect": "pass"},
		{"case": "comment-only-mention", "key": "campaign/client.gd", "text": SNIPPET_COMMENT_ONLY, "expect": "pass"},
		{"case": "string-only-mention", "key": "campaign/client.gd", "text": SNIPPET_STRING_ONLY, "expect": "pass"},
		{"case": "double-super-deliver", "key": "campaign/client.gd", "text": SNIPPET_DOUBLE_SUPER, "expect": "fail"},
		{"case": "alt-json-parse-api", "key": "campaign/client.gd", "text": SNIPPET_ALT_PARSE, "expect": "fail"},
		{"case": "static-parse-in-subclass", "key": "native_arenas/client.gd", "text": SNIPPET_SUBCLASS_PARSE, "expect": "fail"},
		{"case": "missing-super-deliver", "key": "campaign/client.gd", "text": SNIPPET_NO_SUPER, "expect": "fail"},
		{"case": "missing-decode-handoff", "key": "campaign/client.gd", "text": SNIPPET_NO_HANDOFF, "expect": "fail"},
		{"case": "semantic-swallow", "key": "campaign/client.gd", "text": SNIPPET_SEMANTIC_SWALLOW, "expect": "known-limit"},
	]
	var results: Array = []
	var case_checks := 0
	var case_failures := 0
	for entry: Dictionary in cases:
		var got := analyze_source(String(entry["key"]), String(entry["text"]))
		var actual := "pass" if got.is_empty() else "fail"
		# "known-limit" cases are expected to pass the structural gate; the limit
		# is that the gate cannot see them, which the header records explicitly.
		var expect := String(entry["expect"])
		var ok := actual == expect or (expect == "known-limit" and actual == "pass")
		case_checks += 1
		if not ok: case_failures += 1
		var row := {"case": entry["case"], "expect": expect, "actual": actual, "ok": ok}
		if not got.is_empty(): row["failures"] = got
		results.append(row)
	# Lexer self-test: a `#` inside a string literal is not a comment, and a
	# real comment is not code.
	var lexer_code := strip_comments_and_strings("const S := \"a # b JSON.parse_string\"\nvar v := JSON.new()\n")
	check(not lexer_code.contains(PARSE_STATIC), "lexer: a quoted mention must not be read as a parse call")
	check(lexer_code.contains(PARSE_ALT_CTOR), "lexer: real code outside strings must survive")
	return {"results": results, "checks": case_checks, "failures": case_failures, "ok": case_failures == 0}

func read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		check(false, "Cannot open decode-once chain source %s" % path)
		return ""
	return file.get_as_text()

func _initialize() -> void:
	# 1. The checker itself, against crafted snippets.
	var self_run := self_tests()
	var results: Array = self_run["results"]
	for row: Dictionary in results:
		checks += 1
		if not row["ok"]:
			failures += 1
			push_error("self-test %s expected %s, got %s (%s)" % [row["case"], row["expect"], row["actual"], str(row.get("failures", []))])
		var detail := "" if row.has("failures") else ""
		if row.has("failures"): detail = "  -> " + String((row["failures"] as Array)[0])
		print("DECODE_ONCE_SELFTEST ", row["case"], " expect=", row["expect"], " actual=", row["actual"], " ok=", row["ok"], detail)

	# 2. The real tree.
	var parses := {}
	var total_parses := 0
	for key: String in CHAIN:
		var code := strip_comments_and_strings(read_source(String(CHAIN[key])))
		var found := parse_entry_points(code)
		parses[key] = found.size()
		total_parses += found.size()
		var found_list: Array[String] = []
		for f: String in analyze_source(key, read_source(String(CHAIN[key]))): found_list.append(f)
		for problem: String in found_list:
			check(false, problem)
	check(total_parses == 1, "Exactly one JSON parse entry point across the three-file chain (found %d) %s" % [total_parses, str(parses)])
	check(int(parses.get(BASE_KEY, 0)) == 1, "The single parse entry point is in net/client.gd")

	print("DECODE_ONCE_SELFTEST ", JSON.stringify({"ok": self_run["ok"], "cases": results.size(), "checks": self_run["checks"], "failures": self_run["failures"]}))
	print("DECODE_ONCE ", JSON.stringify({
		"ok": failures == 0,
		"checks": checks,
		"failures": failures,
		"parses": parses,
		"singleParseInBase": total_parses == 1 and int(parses.get(BASE_KEY, 0)) == 1,
		"selftests": results.size(),
		"selftests_ok": self_run["ok"],
	}))
	if failures == 0: print("DECODE_ONCE_OK")
	quit(0 if failures == 0 else 1)