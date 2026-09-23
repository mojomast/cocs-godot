extends SceneTree
## Authored-LATTICE link / connection-cue model checks (advisory, no authority).
##
## Fixtures are synthetic copies of the real authored shape
## (`source_map.nodes` + `source_map.lattice`); the guarded block at the end
## proves the fixture matches the generated locked map when it exists.
const Topology = preload("res://lattice/topology.gd")
const Catalog = preload("res://world/catalog.gd")

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
		print("TOPOLOGY_FAIL ", message)

func note(message: String) -> void:
	print("TOPOLOGY_NOTE ", message)

## Exact authored node/lattice shape of the locked `asterion-relay` map.
func asterion() -> Dictionary:
	return {
		"nodes": [
			{"id": "hq-0", "archetype": "hq", "label": "WEST / FLIGHT CONTROL", "r": 12, "x": -104, "z": 0},
			{"id": "hq-1", "archetype": "hq", "label": "EAST / FLIGHT CONTROL", "r": 12, "x": 104, "z": 0},
			{"id": "front-0", "archetype": "front", "label": "WEST / ARCHIVE GATE", "r": 14, "x": -52, "z": -8},
			{"id": "front-1", "archetype": "front", "label": "EAST / ARCHIVE GATE", "r": 14, "x": 52, "z": 8},
			{"id": "econ-n", "archetype": "economy", "label": "NORTH / SOLAR EXCHANGE", "r": 14, "x": 8, "z": -32},
			{"id": "econ-s", "archetype": "economy", "label": "SOUTH / DEEP ARRAY", "r": 14, "x": -8, "z": 32},
			{"id": "relay-0", "archetype": "relay", "label": "ASTERION / OCULUS", "r": 14, "x": 0, "z": 0},
		],
		"lattice": [["hq-0", "front-0"], ["hq-1", "front-1"], ["front-0", "relay-0"], ["relay-0", "front-1"],
			["front-0", "econ-n"], ["front-1", "econ-n"], ["relay-0", "econ-n"], ["front-0", "econ-s"],
			["front-1", "econ-s"], ["relay-0", "econ-s"]],
	}

## hq-0 — front-0 — relay-0 chain plus a siphon hanging off the HQ.
func chain() -> Dictionary:
	return {
		"nodes": [
			{"id": "hq-0", "archetype": "hq", "label": "WEST HQ", "r": 4, "x": 0, "z": 0},
			{"id": "front-0", "archetype": "front", "label": "WEST BASTION", "r": 6, "x": -20, "z": 0},
			{"id": "relay-0", "archetype": "relay", "label": "FOUNDRY RELAY", "r": 6, "x": -40, "z": 0},
			{"id": "econ-n", "archetype": "economy", "label": "NORTH SIPHON", "r": 6, "x": 20, "z": 0},
		],
		"lattice": [["hq-0", "front-0"], ["front-0", "relay-0"], ["hq-0", "econ-n"]],
	}

## Visible recipient nodes from the authored list (missing owner = neutral).
func visible(source: Dictionary, owners: Dictionary) -> Array:
	var out: Array = []
	for node: Dictionary in source.nodes:
		out.append({"id": node.id, "label": node.label, "archetype": node.archetype, "x": node.x, "z": node.z,
			"owner": owners.get(node.id), "live": node.archetype != "hq", "contested": false, "progress": [0, 0]})
	return out

func by_id(model: Dictionary, id: String) -> Dictionary:
	var entry: Variant = model.by_id.get(id)
	return entry if entry is Dictionary else {}

func edge_state(model: Dictionary, a: String, b: String) -> String:
	for link: Dictionary in model.edges:
		if (link.a == a and link.b == b) or (link.a == b and link.b == a): return link.state
	return ""

func _initialize() -> void: call_deferred("run")

func run() -> void:
	_parsing()
	_links()
	_connection()
	_advisory()
	_uncertified_home()
	_caps()
	_generated()
	print("LATTICE_TOPOLOGY_SYNTHETIC %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _parsing() -> void:
	var t := Topology.new()
	check(not t.set_authored(null) and not t.authored and not t.error.is_empty(), "absent authored map is refused with a reason")
	check(not t.set_authored({"nodes": "nope", "lattice": [["a", "b"]]}) and t.edges.is_empty(), "non-array node list authors no topology")
	check(t.set_authored(asterion()) and t.nodes.size() == 7 and t.edges.size() == 10, "the authored asterion shape parses to 7 nodes / 10 links with no invented edge")
	check(t.adjacency.get("hq-0") == ["front-0"] and t.adjacency.get("front-0").size() == 4, "adjacency is the authored undirected link list")
	var dirty := Topology.new()
	check(dirty.set_authored({"nodes": [{"id": "a", "x": 0, "z": 0}, {"id": "b", "x": 1, "z": 0}, {"id": "b", "x": 2, "z": 0}],
		"lattice": [["a", "b"], ["b", "a"], ["a", "a"], ["a", "ghost"], ["a"], "b", {"a": "b"}]})
		and dirty.nodes.size() == 2 and dirty.edges.size() == 1, "duplicate/self/unknown/malformed links are dropped and duplicate ids collapse")
	var nested := Topology.new()
	check(nested.set_authored({"nodes": asterion().nodes, "lattice": {"edges": [["hq-0", "front-0"]]}}) and nested.edges.size() == 1, "the nested lattice.edges spelling is accepted")
	var no_links := Topology.new()
	check(no_links.set_authored({"nodes": asterion().nodes}) and no_links.authored and not no_links.has_topology(), "nodes without authored links never invent a chain")
	var bad := Topology.new()
	bad.set_authored({"nodes": [{"id": "n", "archetype": "front", "x": NAN, "z": "4"}]})
	check(bad.nodes["n"].x == null and bad.nodes["n"].z == null and bad.nodes["n"].archetype == "front", "nonfinite coordinates stay unknown while authored data is kept")

func _links() -> void:
	var t := Topology.new()
	t.set_authored(asterion())
	var full := visible(asterion(), {"hq-0": 0, "hq-1": 1})
	check(t.visible_edges(["hq-0"]).is_empty() and t.visible_edges(["hq-0", "front-0"]).size() == 1, "a link needs both endpoints to be recipient-visible")
	check(t.visible_edges(["ghost", "front-0", "ghost"]).is_empty(), "unknown/duplicate ids cannot create a link")
	var model := t.model(full, 0)
	check(model.edges.size() == 10 and model.complete, "a full recipient view exposes every authored link")
	check(edge_state(model, "hq-0", "front-0") == "front" and edge_state(model, "hq-1", "front-1") == "other", "links are classified by ownership, not by colour")
	check(edge_state(model, "front-0", "econ-n") == "other", "neutral-to-neutral links stay other even when they are authored")
	var partial: Array = []
	for value: Variant in full:
		if value.id != "front-0": partial.append(value)
	var redacted := t.model(partial, 0)
	check(redacted.edges.size() == 6 and edge_state(redacted, "relay-0", "hq-0") == "" and not redacted.complete, "no link is exposed through a node the recipient cannot see")
	check(by_id(redacted, "relay-0").reach == null, "a hidden neighbour keeps the link home unknowable rather than false")
	var stranger := t.model([{"id": "cocs-9", "archetype": "front", "x": 0, "z": 0, "owner": 0, "live": true, "secret": "leak"}], 0)
	check(stranger.nodes.size() == 1 and by_id(stranger, "cocs-9").known == false and not by_id(stranger, "cocs-9").has("secret"), "a node outside the authored graph gains no link and no extra field")
	var malformed := t.model([{"id": 4}, {"id": ""}, "x", {"id": "hq-0", "archetype": "hq", "x": 0, "z": 0, "owner": "0", "live": "yes"}], 0)
	check(malformed.nodes.size() == 1 and by_id(malformed, "hq-0").owner == null, "non-node entries stay out and string ownership is not coerced")

func _connection() -> void:
	var t := Topology.new()
	t.set_authored(chain())
	var owned := visible(chain(), {"hq-0": 0, "front-0": 0, "relay-0": 0})
	var linked := t.model(owned, 0)
	check(by_id(linked, "front-0").supply == "LINKED" and by_id(linked, "relay-0").supply == "LINKED", "an owned chain that reaches the HQ is linked")
	check(edge_state(linked, "hq-0", "front-0") == "linked" and edge_state(linked, "front-0", "relay-0") == "linked", "owned links that trace home draw as linked")
	check(by_id(linked, "econ-n").supply == "LINKED" and edge_state(linked, "hq-0", "econ-n") == "front", "a neutral node staging off linked ground is linked but its link is a front line")
	check(linked.owned == 3 and linked.cut == 0, "the connection summary counts owned and cut-off nodes exactly")

	var cut := t.model(owned, 0, ["front-0"])
	check(by_id(cut, "front-0").supply == "CUT OFF" and by_id(cut, "relay-0").supply == "CUT OFF" and cut.cut == 2, "a team-visible cut breaks the chain behind it")
	check(edge_state(cut, "front-0", "relay-0") == "severed" and edge_state(cut, "hq-0", "econ-n") == "front", "severed ownership links are distinguishable from untouched links")
	check(by_id(cut, "econ-n").supply == "LINKED", "a siphon hanging directly off the HQ survives the cut")

	# Losing the middle node to the enemy severs the same chain without a cut.
	var lost := t.model(visible(chain(), {"hq-0": 0, "front-0": 1, "relay-0": 0}), 0)
	check(by_id(lost, "relay-0").supply == "CUT OFF" and edge_state(lost, "front-0", "relay-0") == "front", "an enemy-held middle node severs the owned link behind it")
	var anonymous := t.model(owned, null)
	check(by_id(anonymous, "front-0").supply == "UNKNOWN" and edge_state(anonymous, "hq-0", "front-0") == "unknown", "without a team identity every link is reported as unknown")

func _advisory() -> void:
	var t := Topology.new()
	check(t.guidance(t.model([], 0)).code == "no-topology", "an unauthored map says so instead of guessing links")
	check(t.set_authored(chain()) and t.guidance(t.model([], 0)).code == "no-nodes", "topology without visible objectives reports no targets")
	var t0 := Topology.new()
	t0.set_authored(asterion())
	var model := t0.model(visible(asterion(), {"hq-0": 0, "hq-1": 1}), 0)
	var next := t0.guidance(model)
	check(next.code == "next" and next.target_id == "front-0", "the next public target is the frontier adjacent to owned ground")
	check(next.text.contains("WEST / ARCHIVE GATE") and next.text.contains("linked"), "the cue names the authored objective and its link home")
	check(t0.guidance(model, "relay-0").text.contains("no owned link"), "an unlinked public selection is described, not forbidden")
	var own := t0.guidance(model, "hq-0")
	check(own.code == "selected" and own.text.contains("HOLD"), "an owned selection reads as an available HOLD")

	# A legal HOLD on a cut-off owned node must never be re-labelled by capture rules.
	var t1 := Topology.new()
	t1.set_authored(chain())
	var cut := t1.model(visible(chain(), {"hq-0": 0, "front-0": 0, "relay-0": 0}), 0, ["front-0"])
	var cut_cue := t1.guidance(cut, "relay-0")
	check(cut_cue.code == "selected" and cut_cue.text.contains("CUT OFF") and cut_cue.text.contains("HOLD"), "a cut-off owned node is still offered as a HOLD with its broken line named")
	check(not cut_cue.text.contains("not adjacent") and not cut_cue.text.contains("illegal") and not cut_cue.text.contains("BLOCKED"), "capture adjacency never downgrades a legal HOLD cue")
	check(by_id(cut, "relay-0").hold_legal and not by_id(cut, "relay-0").capture_legal, "the model separates HOLD legality from capture adjacency")
	var dead := t1.model(visible(chain(), {"hq-0": 0, "front-0": 0, "relay-0": 0}), 0, ["hq-0"])
	check(by_id(dead, "relay-0").supply == "UNKNOWN" and by_id(dead, "relay-0").hold_legal, "cutting the HQ itself is unknown supply, not a fabricated cut-off")

	var anonymous := Topology.new()
	anonymous.set_authored(chain())
	check(anonymous.guidance(anonymous.model(visible(chain(), {}), null)).code == "no-team", "without a recipient team the cue asks for identity")
	check(t1.guidance(t1.model([], null), "x").code == "no-nodes", "missing objectives outrank the missing team identity")

## Blocker regressions: an own link whose home line cannot be certified must
## never be rendered or described as a known cut, and a selected id outside the
## model must degrade to the ordinary cue instead of dereferencing an empty entry.
func _uncertified_home() -> void:
	var t := Topology.new()
	t.set_authored(chain())
	var no_home := t.model(visible(chain(), {"front-0": 0, "relay-0": 0}), 0)
	check(by_id(no_home, "front-0").supply == "UNKNOWN" and by_id(no_home, "relay-0").supply == "UNKNOWN" and no_home.cut == 0,
		"no visible friendly HQ keeps own supply unknown and counts no cut")
	check(edge_state(no_home, "front-0", "relay-0") == "unknown",
		"an own link whose home line is uncertified is not drawn as a known cut")
	check(t.guidance(no_home).text.contains("not confirmed linked") and not t.guidance(no_home).text.contains("cut off"),
		"the uncertified hold cue never claims a cut")

	var dead_home := t.model(visible(chain(), {"hq-0": 0, "front-0": 0, "relay-0": 0}), 0, ["hq-0"])
	check(by_id(dead_home, "econ-n").capture_legal and by_id(dead_home, "econ-n").supply == "UNKNOWN",
		"cutting the friendly HQ leaves a capture target's home line uncertified")
	var target_cue := t.guidance(dead_home, "econ-n")
	check(target_cue.code == "selected" and target_cue.text.contains("capture legal") and not target_cue.text.contains("cut off"),
		"an uncertified home line is not announced as a cut-off staging line")
	var next_cue := t.guidance(dead_home)
	check(next_cue.code == "next" and not next_cue.text.contains("reconnect"),
		"the next target cue does not demand a reconnect for an uncertified home line")
	check(edge_state(dead_home, "front-0", "relay-0") == "unknown",
		"own links behind a cut HQ stay unknown, not severed")

	# A team-visible cut with a certifiable home line is still a definite cut.
	var known := t.model(visible(chain(), {"hq-0": 0, "front-0": 0, "relay-0": 0}), 0, ["front-0"])
	check(edge_state(known, "front-0", "relay-0") == "severed" and by_id(known, "relay-0").supply == "CUT OFF",
		"a known cut with a visible friendly HQ still reads as a known cut")

	# Stale/unknown selection ids degrade to the ordinary cue, never a script error.
	var ghost := t.guidance(dead_home, "ghost-9")
	check(ghost.code == "next" and not str(ghost.text).is_empty(), "a selected id outside the model falls through instead of failing")
	var t0 := Topology.new()
	t0.set_authored(asterion())
	var star := t0.model(visible(asterion(), {"hq-0": 0, "hq-1": 1}), 0)
	check(t0.guidance(star, "hq-7").code == "next", "a stale selection id resolves through the same next-target cue")

func _caps() -> void:
	var big := {"nodes": [], "lattice": []}
	for i: int in range(200):
		big.nodes.append({"id": "n%d" % i, "archetype": "front", "x": float(i), "z": 0.0})
		if i > 0: big.lattice.append(["n%d" % (i - 1), "n%d" % i])
	var capped := Topology.new()
	capped.set_authored(big)
	check(capped.nodes.size() == 64 and capped.edges.size() == 63, "authored input is capped instead of unbounded")
	var many: Array = []
	for i: int in range(300): many.append({"id": "v%d" % i, "archetype": "front", "x": 0, "z": 0, "owner": 0, "live": true})
	var cuts: Array = []
	for i: int in range(200): cuts.append("n%d" % i)
	check(capped.model(many, 0, cuts).nodes.size() == 128 and capped.model(many, 0, cuts).cuts.size() == 64, "the visible projection and the cut list are capped")

func _generated() -> void:
	var catalog := Catalog.new()
	if not catalog.open():
		note("generated content absent: " + catalog.error + " (fixture checks still apply)")
		return
	var source: Dictionary = catalog.resolve_map("asterion-relay")
	if source.is_empty():
		note("generated asterion-relay unavailable: " + catalog.error)
		return
	var t := Topology.new()
	check(t.set_authored(source) and t.nodes.size() == 7 and t.edges.size() == 10, "generated asterion-relay matches the fixture topology")
	check(t.label_for("relay-0", "") == "ASTERION / OCULUS", "generated authored labels resolve for the marker cue")
	var monsoon: Dictionary = catalog.resolve_map("monsoon-foundry")
	var other := Topology.new()
	check(other.set_authored(monsoon) and other.nodes.size() == 7 and other.label_for("relay-0", "") == "MONSOON / TURBINE CONTROL", "generated monsoon-foundry authors its own labels")
