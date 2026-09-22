extends RefCounted
## Read-only impact surface classification.
##
## Every input here is already owned by the combat composition: the semantic
## catalog map dictionary (biome/blocks), a native collision-root node path, or
## the map identity itself. Nothing is inferred from gameplay state, and the
## fallback is a neutral family rather than a guessed material.
##
## Families are presentation-only buckets: metal, stone, ice, ground.

const METAL := "metal"
const STONE := "stone"
const ICE := "ice"
const GROUND := "ground"
const FAMILIES: Array[String] = [METAL, STONE, ICE, GROUND]

## Source `biome` strings, as exported into res://content/generated maps.
const BIOME_FAMILIES := {
	"glacier": ICE, "ice": ICE, "snow": ICE, "tundra": ICE, "arctic": ICE, "frost": ICE,
	"volcanic": STONE, "canyon": STONE, "ruins": STONE, "desert": STONE, "badlands": STONE, "cave": STONE, "crater": STONE,
	"urban": METAL, "industrial": METAL, "foundry": METAL, "relay": METAL, "citadel": STONE,
	"forest": GROUND, "grassland": GROUND, "jungle": GROUND, "wetland": GROUND, "field": GROUND, "meadow": GROUND,
}

## Semantic block `kind` values shared by the exported catalog maps.
const KIND_FAMILIES := {
	"rock": STONE, "cave": STONE, "column": STONE, "pillar": STONE, "base-wall": STONE, "wall": STONE, "tunnel": STONE,
	"building": METAL, "partition": METAL, "cover": METAL, "crate": METAL, "reactor": METAL, "bulkhead": METAL,
	"depot-wall": METAL, "base-hq": METAL, "base-bastion": METAL, "base-screen": METAL, "soccer-wall": METAL,
	"soccer-goal": METAL, "light-mast": METAL, "relay-feed": METAL, "pump": METAL, "sluice": METAL, "race-rail": METAL,
	"tree": GROUND, "race-infield": GROUND, "race-apron": GROUND, "foundation": GROUND, "dam-buttress": GROUND,
}

## Authored native collider names carry the real material intent; scanned in
## this order so "ice butte" never becomes stone and "ground trim" never wins
## over an explicit metal part name.
const NAME_KEYWORDS := {
	ICE: ["ice", "glacier", "glacial", "frost", "snow", "frozen", "hail", "crystal"],
	METAL: ["metal", "steel", "copper", "iron", "pipe", "reactor", "rail", "plate", "beam",
		"machine", "engine", "container", "vent", "antenna", "dish", "bulkhead", "foundry", "crucible", "relay", "sluice"],
	STONE: ["rock", "stone", "cliff", "ridge", "berm", "wall", "concrete", "brick", "marble", "plinth", "drum",
		"bastion", "column", "pillar", "partition", "building", "ruins", "foundation", "observatory", "pressure", "crown"],
	GROUND: ["ground", "floor", "deck", "apron", "landing", "pad", "grass", "dirt", "sand", "terrain",
		"tread", "incline", "ramp", "walk", "mezzanine", "vista"],
}

## Map-default families for the map identities the composition can load.
const MAP_DEFAULTS := {
	"aurora-basin": ICE, "cinder-array": STONE, "prism-foundry": METAL,
	"lacuna-court": STONE, "nacre-engine": METAL, "vermilion-fold": STONE,
	"tidal-citadel": ICE, "ember-crucible": STONE, "monsoon-foundry": METAL,
	"asterion-relay": STONE, "sunscar-convoy": STONE, "verdant-reliquary": GROUND,
	"meridian-exchange": METAL, "ion-speedway": GROUND, "aurora-stadium": ICE,
}

static func keyword_family(text: String) -> String:
	if text.is_empty(): return ""
	var lower := text.to_lower()
	for family: String in [ICE, METAL, STONE, GROUND]:
		for keyword: String in NAME_KEYWORDS[family]:
			if lower.contains(keyword): return family
	return ""

static func biome_family(biome: String) -> String:
	var key := biome.strip_edges().to_lower()
	return BIOME_FAMILIES.get(key, "")

static func kind_family(kind: String) -> String:
	return KIND_FAMILIES.get(kind.strip_edges().to_lower(), "")

static func map_default(map_id: String) -> String:
	return MAP_DEFAULTS.get(map_id.strip_edges().to_lower(), "")

## Deterministic classification order: an explicit named part wins over the
## block kind, which wins over the biome, which wins over the map default. A
## walkable/floor face only becomes "ground" when nothing named it otherwise.
static func classify(map: Dictionary, name_text: String, kind: String, on_ground_plane: bool) -> String:
	var family := keyword_family(name_text)
	if not family.is_empty(): return family
	if on_ground_plane: return GROUND
	family = kind_family(kind)
	if not family.is_empty(): return family
	family = biome_family(str(map.get("biome", "")))
	if not family.is_empty(): return family
	family = map_default(str(map.get("id", map.get("mapId", ""))))
	if not family.is_empty(): return family
	return STONE
