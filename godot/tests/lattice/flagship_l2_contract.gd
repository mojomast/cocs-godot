extends SceneTree
const Topology = preload("res://lattice/topology.gd")
const Target = preload("res://lattice/world_target.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _initialize() -> void:
	var t = Topology.new()
	var map := {"nodes":[{"id":"hq","archetype":"hq","x":-1,"z":0},{"id":"own","archetype":"front","x":0,"z":0},{"id":"near","archetype":"relay","x":0.1,"z":0},{"id":"far","archetype":"front","x":1,"z":0},{"id":"cut","archetype":"economy","x":-2,"z":0},{"id":"cut-front","archetype":"front","x":2,"z":0}],
		"edges":[["hq","own"],["near","far"],["own","far"],["hq","cut"],["cut","cut-front"]]}
	check(t.set_authored(map), "authored fixture loads")
	var projection := [
		{"id":"hq","owner":0,"live":true}, {"id":"own","owner":0,"live":true},
		{"id":"near","owner":1,"live":true}, {"id":"far","owner":null,"live":true},
		{"id":"cut","owner":0,"live":true}, {"id":"cut-front","owner":null,"live":true}]
	var model: Dictionary = t.model(projection, 0, ["cut"])
	check(not model.by_id.near.capture_legal and model.by_id.far.capture_legal, "closer enemy illegal while farther owned-adjacent frontier is legal")
	check(model.by_id["cut-front"].capture_legal and model.by_id["cut-front"].supply == "CUT OFF", "disconnected frontier adjacent to cut-owned node is legal but cut off")
	check(model.complete, "fully owned-known map is complete")
	var incomplete := projection.duplicate(true); incomplete[2].erase("owner")
	model = t.model(incomplete, 0)
	check(not model.complete and not model.by_id.near.capture_legal, "incomplete ownership cannot certify enemy target")
	var missing_dom: Dictionary = Target.new().select({"team":0,"dominance":null}, model, {})
	check(missing_dom.reason_code != "enemy-dominance" and not missing_dom.text.contains("3 flip"), "null dominance remains unknown without invented threshold")
	var selector = Target.new()
	var battle: Dictionary = t.model(projection, 0)
	var dom_projection := {"team":0,"dominance":{"team":1,"breakCount":1,"count":3,"counts":{"0":1,"1":3}},"source_sequence":12}
	var target: Dictionary = selector.select(dom_projection, battle, {"x":0.0,"z":0.0})
	check(target.reason_code == "dominance-prerequisite" and target.target_id == "far" and target.capture_legal, "legal neutral frontier returned as opponent dominance prerequisite")
	dom_projection.dominance.team = 1.0
	check(selector.select(dom_projection, battle, {"x":0.0,"z":0.0}).reason_code == "dominance-prerequisite", "JSON numeric team identity retains dominance priority")
	dom_projection.dominance.counts["1"] = 4; dom_projection.dominance.breakCount = 2
	target = selector.select(dom_projection, battle, {"x":0.0,"z":0.0})
	check(target.text.contains("2 flips"), "four-node dominance uses authoritative breakCount")
	dom_projection.dominance.erase("breakCount")
	target = selector.select(dom_projection, battle, {"x":0.0,"z":0.0})
	check(target.text.contains("flip count unknown"), "missing breakCount reported unknown")
	var no_frontier := projection.duplicate(true); no_frontier[3].owner = 0; no_frontier[5].owner = 0; no_frontier[2].live = false
	var no_legal: Dictionary = selector.select(dom_projection, t.model(no_frontier, 0), {})
	check(no_legal.reason_code == "dominance-prerequisite" and no_legal.target_id.is_empty(), "no legal prerequisite is described without fabricated target")
	var threatened := no_frontier.duplicate(true); threatened[1].contested = true
	var defense := selector.select({"team":0,"dominance":{"team":0,"breakCount":1}}, t.model(threatened, 0), {"x":0.0,"z":0.0})
	check(defense.reason_code == "own-contest" and defense.target_id == "own" and not defense.capture_legal, "own dominance defends published contest even with no legal frontier")
	var contested_with_frontier := projection.duplicate(true)
	contested_with_frontier[1].contested = true; contested_with_frontier[3].owner = 1
	var contested_model: Dictionary = t.model(contested_with_frontier, 0)
	check(contested_model.by_id.far.capture_legal and contested_model.by_id.far.enemy, "fixture has a legal enemy frontier beside a contested owned node")
	var own_dom := {"team":0,"dominance":{"team":0,"breakCount":1}}
	defense = selector.select(own_dom, contested_model, {"x":0.0,"z":0.0}, {}, "far")
	check(defense.reason_code == "own-contest" and defense.intent == "defend" and defense.target_id == "own", "explicit enemy frontier cannot replace the node named by own-contest defense")
	defense = selector.select(own_dom, t.model(threatened, 0), {"x":0.0,"z":0.0}, {}, "stale-node")
	check(defense.reason_code == "own-contest" and defense.target_id == "own", "stale explicit selection retains the defended contested node")
	var prerequisite_selection := selector.select(dom_projection, battle, {"x":0.0,"z":0.0}, {}, "near")
	check(prerequisite_selection.reason_code == "dominance-prerequisite" and prerequisite_selection.target_id == "far", "enemy selection cannot replace a neutral dominance prerequisite")
	var none := t.model([], 0)
	target = selector.select({"team":0}, none, {})
	check(target.target_id.is_empty() and not target.capture_legal, "no legal target remains advisory fallback")
	print("flagship_l2_contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
