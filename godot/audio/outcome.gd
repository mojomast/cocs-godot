extends RefCounted
## A neutral outcome is safer than false DEFEAT for an unknown/spectator seat.
## Derived from game/outcome.mjs actorWon and game/config.mjs team rules.
const TEAM := ["ctf","koth","domination","assault","teamdeathmatch","combined-arms","cocs","cocs-coop","payload","puma-soccer","horde","campaign","team-elimination","vip-escort","holdout","uplink"]

static func resolve(state: Dictionary, mode: String, actor_id: int) -> String:
	if actor_id < 0 or state.get("over", false) != true: return "neutral"
	var actor: Dictionary = {}
	var actors: Variant = state.get("actors", [])
	if not actors is Array: return "neutral"
	for item: Variant in actors:
		if item is Dictionary and item.get("id") == actor_id: actor = item; break
	if actor.is_empty(): return "neutral"
	var winner: Variant = state.get("winner")
	if mode == "puma-race":
		var race: Variant = state.get("race")
		if race is Dictionary: winner = race.get("winnerId", winner)
		return "neutral" if winner == null else ("victory" if winner == actor_id else "defeat")
	if mode in ["horde", "campaign"]:
		var single: Variant = state.get("singleplayer")
		if single is Dictionary and single.get("winner") != null:
			return "victory" if single.winner == actor_id or single.winner == actor.get("team") else "defeat"
		return "neutral"
	if mode == "puma-soccer":
		var race: Variant = state.get("race")
		if race is Dictionary: winner = race.get("winnerTeam", winner)
	if mode in TEAM:
		if mode in ["cocs", "cocs-coop"] and winner == null:
			var cocs: Variant = state.get("cocs")
			var scores: Variant = cocs.get("scores") if cocs is Dictionary else state.get("scores")
			if scores is Dictionary:
				var red: Variant = scores.get("0", scores.get(0))
				var blue: Variant = scores.get("1", scores.get(1))
				if (red is int or red is float) and (blue is int or blue is float) and red != blue: winner = 0 if float(red) > float(blue) else 1
		if actor.get("team") == null or winner == null: return "neutral"
		return "victory" if winner == actor.team else "defeat"
	if winner != null: return "victory" if winner == actor_id else "defeat"
	# Source fallback for untimed FFA: only a positive best rank awards victory.
	# Ambiguous missing rank is neutral, not a fabricated defeat.
	var score_key := "points" if mode == "juggernaut" else ("ladder" if mode == "armsrace" else "frags")
	var best := -1
	for item: Variant in actors:
		if item is Dictionary and (item.get(score_key) is int or item.get(score_key) is float):
			best = maxi(best, int(item[score_key]))
	if best <= 0 or not (actor.get(score_key) is int or actor.get(score_key) is float): return "neutral"
	return "victory" if int(actor[score_key]) == best else "defeat"
