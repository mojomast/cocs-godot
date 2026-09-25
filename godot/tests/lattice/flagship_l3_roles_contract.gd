extends SceneTree
const Roles = preload("res://lattice/world_roles.gd")
const Loadout = preload("res://ui/loadout.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var count := 0
	for character: String in Loadout.CHARACTER_IDS:
		for harness: String in Loadout.HARNESS_IDS:
			var card: Dictionary = Roles.describe(character, harness)
			if Loadout.valid(character, harness):
				count += 1
				check(card.ready and card.operator == character and card.harness == harness,
					"assigned legal pair %s/%s" % [character, harness])
				check(not card.operator_role.effect.is_empty() and not card.harness_role.effect.is_empty()
					and card.text.contains(card.operator_role.name) and card.text.contains(card.harness_role.name),
					"both source role hooks compose for %s/%s" % [character, harness])
			else:
				check(not card.ready and card.reason.contains("locked"), "Claude lock rejects %s" % harness)
	check(count == 57, "nine by seven less six Claude locks gives 57 legal pairs")
	var missing: Dictionary = Roles.from_session({})
	check(not missing.ready and missing.text.contains("Awaiting"), "no config cannot advertise assigned loadout")
	check(not Roles.from_session({"operator":"qwen"}).ready, "partial echo is unavailable")
	check(not Roles.from_session({"operator":"bogus", "harness":"roo"}).ready, "unknown echoed operator stays unknown")
	check(not Roles.from_session({"operator":"qwen", "harness":"bogus"}).ready, "unknown echoed harness stays unknown")
	check(not Roles.from_session({"operator":"claude", "harness":"openclaw"}).ready, "invalid assigned pair does not silently resolve")
	var assigned: Dictionary = Roles.from_session({"operator":"kimi", "harness":"codex", "mode":"cocs", "rung":"8v8"})
	check(assigned.ready and assigned.operator == "kimi" and assigned.harness == "codex", "session echo is the loadout authority")
	check(assigned.operator_role.effect.contains("2 m/s") and assigned.operator_role.limit.contains("Stopping"), "Kimi intel depends on movement")
	check(assigned.harness_role.limit.contains("4v4") and assigned.harness_role.limit.contains("sabotage cut"), "repair opportunity is cut-only, with 4v4 caveat")
	var supply: Dictionary = Roles.describe("chatgpt", "opencode")
	check(supply.operator_role.limit.contains("finite") and supply.harness_role.limit.contains("Pulse")
		and supply.harness_role.effect.contains("two allies"), "both supply hooks explain finite pickup ammo and recipient limits")
	var capture: Dictionary = Roles.describe("qwen", "cline")
	check(capture.text.contains("1.35×") and capture.text.contains("never stack")
		and capture.harness_role.effect.contains("physically"), "capture ceiling and physical presence are explicit")
	check(capture.text.contains("Puma") and capture.text.contains("board/drive/dismount") and capture.text.contains("owned depots"), "Puma loaner availability is distinct from native handling")
	var deepseek: Dictionary = Roles.describe("deepseek", "roo")
	check(deepseek.operator_role.effect.contains("stationary") and deepseek.operator_role.limit.contains("no SCAN damage")
		and deepseek.harness_role.limit.contains("FORTIFY"), "still recon and strongest ward limitations")
	var disrupt: Dictionary = Roles.describe("gemini", "openclaw")
	check(disrupt.harness_role.limit.contains("never grants ownership") and disrupt.operator_role.effect.contains("6 seconds"), "disruption is not a capture; swap has cooldown")
	var second: Dictionary = Roles.describe("chatgpt", "opencode")
	supply.operator_role.effect = "mutated"
	check(second.operator_role.effect != "mutated", "callers cannot mutate shared role definitions")
	print("flagship_l3_roles_contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
