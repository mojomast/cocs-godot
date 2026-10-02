extends RefCounted
## Dynamic text from game/lattice-feedback.mjs latticeCaption. Caller MUST first
## apply the shared recipient/team/spectator event permission and source audio
## eligibility gates. This formatter grants no permission and retains no events.
## Empty means defer to the shared static catalogue; no second caption queue.

static func clean(value: Variant, fallback: String = "") -> String:
	if not value is String: return fallback
	return " ".join(value.replace("\n", " ").replace("\r", " ").replace("\t", " ").split(" ", false)).left(64)

static func label(value: Variant, fallback: String = "") -> String:
	return clean(value, fallback).replace("-", " ").to_upper()

static func numeric(value: Variant, fallback: String = "?") -> String:
	if (value is int or value is float) and is_finite(float(value)):
		return str(int(value)) if floorf(float(value)) == float(value) else "%.1f" % float(value)
	return fallback

static func positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0

static func count(value: Variant) -> int:
	return value.size() if value is Array else 0

static func suffix(text: String) -> String:
	return " · " + text if not text.is_empty() else ""

static func text_for(event: Dictionary) -> String:
	var kind := str(event.get("type", ""))
	var node := label(event.get("node", event.get("depot")))
	var role := label(event.get("role"), "role")
	match kind:
		"cocs-terminal-shard": return "Shard secured · return to your HQ vault" if event.get("action") == "collect" else "Shard returned · recover it at the relay"
		"cocs-capture": return "Node captured" + suffix(node)
		"cocs-depot-capture": return "Depot captured" + suffix(node)
		"cocs-depot-vehicle-spawn": return "LOANER READY" + suffix(node)
		"cocs-depot-purchase": return label(event.get("item"), "puma") + " REQUISITIONED" + suffix(node)
		"cocs-device-use": return "Route engaged · " + clean(event.get("kind"), "device").replace("-", " ")
		"director-wave": return "Director wave %s approaching" % numeric(event.get("wave"))
		"director-wave-cleared": return "Wave %s cleared" % numeric(event.get("wave"))
		"director-spawn": return "Wave %s contact" % numeric(event.get("wave"))
		"director-init": return "Operation online" + (" · tier " + (clean(event.tier) if event.tier is String else numeric(event.tier)) if event.has("tier") else "")
		"director-spawn-telegraph": return "Boss telegraph" if event.get("kind") == "boss" else "Spawn telegraph"
		"director-modifier": return "Wave modifier" + suffix(label(event.get("name", event.get("id"))))
		"director-escalation": return "Director escalation" + suffix(label(event.get("kind")))
		"director-boss": return "Boss deployed" + (" · phase " + numeric(event.phase) if event.has("phase") else "")
		"director-phase": return "Boss phase " + numeric(event.get("phase"))
		"director-retarget": return "Director retarget" + suffix(node)
		"director-retire": return "Director retires %s units" % numeric(event.get("count"), "0")
		"director-denial": return "Denial field" + suffix(node)
		"director-reinforce": return "Director reinforcement" + suffix(node)
		"cocs-order-complete": return "Order complete" + suffix(label(event.get("verb")))
		"cocs-order-rejected": return "Order rejected" + suffix(label(event.get("verb")))
		"coop-spend-rejected": return "Spend rejected" + suffix(label(event.get("verb")))
		"coop-bonus": return "Bonus " + clean(event.get("state"), "open") + suffix(clean(event.get("label")))
		"cocs-terminal-sabotage": return "Terminal sabotage" + suffix(label(event.get("terminal")))
		"cocs-sapper": return "Link cut" + suffix(node) + (" · %s DENIED" % numeric(event.denied) if positive(event.get("denied")) else "")
		"cocs-siphon": return "Flux siphoned" + (" · %d FLUX" % floori(float(event.flux) + 0.5) if positive(event.get("flux")) else "")
		"cocs-scan": return "Scan sweep" + (" · %s MARKED" % numeric(event.marked) if positive(event.get("marked")) else "")
		"cocs-role-spawn": return "Role deployed · " + role
		"cocs-role-killed": return "Role killed · " + role
		"cocs-role-expire": return "Role retired · " + role + (" · +%d FLUX" % floori(float(event.refund) + 0.5) if positive(event.get("refund")) else "")
		"cocs-role-rally": return "Rally" + (" · %d LINKED" % count(event.get("targets")) if count(event.get("targets")) > 0 else "")
		"cocs-role-repair": return "Repairs done" + (" · %d RESTORED" % count(event.get("repaired")) if count(event.get("repaired")) > 0 else "")
		"cocs-role-spot": return "Spot" + (" · %d MARKED" % count(event.get("targets")) if count(event.get("targets")) > 0 else "")
		"cocs-prime-start": return "Prime started" + suffix(node)
		"cocs-prime": return "Node primed" + suffix(node)
		"cocs-prime-interrupt": return "Prime interrupted" + suffix(node)
		"cocs-command":
			match str(event.get("action", "")):
				"take": return "Command assumed"
				"release": return "Command released"
				"mutiny-vote":
					var seat: Variant = event.get("seat")
					if (seat is bool and seat) or (seat is String and not seat.is_empty()): return "Mutiny carried · new commander"
					var votes := maxf(0.0, float(numeric(event.get("votes"), "0")))
					var needed := maxf(1.0, float(numeric(event.get("needed"), "1")))
					return "Mutiny vote · %s/%s" % [numeric(votes), numeric(needed)]
				"policy": return "Stance" + suffix(label(event.policy)) if event.get("policy") is String and not event.policy.is_empty() else "Stance cleared"
				"set-route": return "Route set" + suffix(label(event.value)) if event.get("value") is String and not event.value.is_empty() else "Route cleared"
			return "Command updated"
	return ""
