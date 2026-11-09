class_name SaveMigrations
extends RefCounted
## Tested, one-way migration chain for campaign data. Each step upgrades exactly one schema version.
## Never serialise engine objects: campaign data is plain JSON (dictionaries, arrays, strings, numbers).

const CURRENT := 2


## Returns migrated data (a deep copy) or an empty dictionary when the version is unknown or newer.
static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version > CURRENT or from_version < 1:
		return {}
	var out: Dictionary = data.duplicate(true)
	var v := from_version
	while v < CURRENT:
		match v:
			1:
				out = _v1_to_v2(out)
			_:
				return {}
		v += 1
	return out


## v1 stored the heroes as top-level "hero_a"/"hero_b" and had no shared rune library.
## v2 groups them under "heroes" and adds "rune_library" (rune id -> tier).
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	var heroes: Dictionary = {}
	if d.has("hero_a"):
		heroes["a"] = d["hero_a"]
		d.erase("hero_a")
	if d.has("hero_b"):
		heroes["b"] = d["hero_b"]
		d.erase("hero_b")
	d["heroes"] = heroes
	if not d.has("rune_library"):
		d["rune_library"] = {}
	return d
