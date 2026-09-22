extends RefCounted
## Colors are scenic maintenance finishes, never team/status/pickup colors.
## Ceilings include every mounted quad and every shader-driven ambient mote.
const MAPS := {
	"meridian-exchange": {"tint": "91acae", "light": "d2b187", "panel": "holographic_grid", "lut": "entanglement-arcane", "air": "dust", "air_color": "bcb4a5", "surfaces": 176, "pockets": 3, "motes": 120},
	"verdant-reliquary": {"tint": "939785", "light": "bcb296", "panel": "alien_chitin", "lut": "entanglement-ceramic", "air": "pollen", "air_color": "b7bb9f", "surfaces": 112, "pockets": 3, "motes": 120},
	"ember-crucible": {"tint": "a39383", "light": "ce956c", "panel": "circuit_board-etch", "lut": "entanglement-ember", "air": "ash", "air_color": "aea29c", "surfaces": 176, "pockets": 4, "motes": 192},
	"tidal-citadel": {"tint": "94afb7", "light": "bbccce", "panel": "holographic_grid", "lut": "entanglement-ceramic", "air": "snow", "air_color": "d0dde0", "surfaces": 168, "pockets": 4, "motes": 192},
	"sunscar-convoy": {"tint": "a99d87", "light": "ccad81", "panel": "circuit_board-etch", "lut": "entanglement", "air": "dust", "air_color": "c7af8f", "surfaces": 152, "pockets": 4, "motes": 160},
	"asterion-relay": {"tint": "96a5be", "light": "acbdd6", "panel": "holographic_grid", "lut": "entanglement-arcane", "air": "vent", "air_color": "aab5c7", "surfaces": 216, "pockets": 2, "motes": 64},
	"monsoon-foundry": {"tint": "93aaa7", "light": "b6c3b8", "panel": "circuit_board-etch", "lut": "entanglement", "air": "mist", "air_color": "b8c7c2", "surfaces": 216, "pockets": 3, "motes": 120},
	"ion-speedway": {"tint": "97aab8", "light": "b5cbd3", "panel": "holographic_grid", "lut": "entanglement-arcane", "air": "none", "air_color": "aab8c6", "surfaces": 88, "pockets": 0, "motes": 0},
	"aurora-stadium": {"tint": "9aaeb5", "light": "c7d2ce", "panel": "holographic_grid", "lut": "entanglement-ceramic", "air": "none", "air_color": "b8c7c2", "surfaces": 96, "pockets": 0, "motes": 0},
}

static func get_profile(id: String) -> Dictionary:
	# Unknown maps get no new decoration, rather than inheriting a wrong identity.
	return MAPS.get(id, {}).duplicate(true)
