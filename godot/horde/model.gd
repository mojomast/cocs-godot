extends RefCounted
## Pure snapshot projection; never advances gameplay or retains stale authority.
var state: Dictionary = {}
var text := "Waiting for Horde authority"

func clear() -> void:
	state.clear()
	text = "Waiting for Horde authority"

static func number(value: Variant, fallback: float = 0.0) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

func apply(snapshot: Dictionary, stale: bool = false) -> void:
	clear()
	if stale:
		text = "Horde snapshot stalled — release controls"
		return
	var raw: Variant = snapshot.get("singleplayer")
	if not raw is Dictionary or raw.get("kind") != "horde": return
	state = raw.duplicate(true)
	var phase: String = str(state.get("phase", "unknown"))
	var outcome := phase.to_upper()
	if phase == "won" and state.get("winner") != null and number(state.winner, -1) == 0: outcome = "VICTORY"
	elif phase == "lost": outcome = "DEFEAT"
	elif phase == "intermission": outcome = "NEXT WAVE IN %ds" % int(ceil(number(state.get("waveTimer"))))
	text = "HORDE · WAVE %d / %d · %s\nENEMIES %d / %d · LIVES %d · SCORE %d" % [int(number(state.get("wave"))), int(number(state.get("waveTarget"))), outcome, int(number(state.get("enemiesAlive"))), int(number(state.get("enemiesTotal"))), int(number(state.get("lives"))), int(number(state.get("score")))]
	var modifier: Variant = state.get("waveModifier")
	if modifier is Dictionary: text += " · " + str(modifier.get("name", ""))
	var boss: Variant = state.get("boss")
	if boss is Dictionary and boss.get("alive") == true:
		text += "\n%s · HP %d/%d · PHASE %d" % [str(boss.get("name", "Boss")), int(number(boss.get("hp"))), int(number(boss.get("maxHp"))), int(number(boss.get("phase")))]
	if state.get("upgrades") is Array and not state.upgrades.is_empty():
		text += "\nUPGRADES AVAILABLE · selection unsupported"
	if snapshot.get("over") == true: text += "\nEnter: restart · release held controls, then click to engage"
