extends Node
## Autoload "GameData": the single registry of immutable definitions and data tables.
## Typed Resources hold structured definitions; CSV tables hold tabular data. Validated at startup.

const T := CsvTable.ColumnType

const TABLE_DIR := "res://data/tables/"
const DEF_DIRS := {
	&"ability": "res://data/abilities/",
	&"class": "res://data/classes/",
	&"enemy": "res://data/enemies/",
	&"rune": "res://data/runes/",
}

var errors: PackedStringArray = PackedStringArray()
var loaded: bool = false

var rules: Dictionary = {}                # StringName -> float
var primers: Dictionary = {}              # StringName -> row
var finishers: Dictionary = {}            # StringName -> row
var signatures: Dictionary = {}           # "primer|finisher" -> row
var surface_materials: Dictionary = {}    # StringName -> row
var surface_codes: Dictionary = {}        # int -> StringName
var surface_reactions: Dictionary = {}    # "material|element" -> row
var attribute_effects: Array[Dictionary] = []
var xp_rows: Array[Dictionary] = []
var waves_by_encounter: Dictionary = {}   # StringName -> Array (index = wave-1) of Array[Dictionary]
var rooms_by_expedition: Dictionary = {}  # StringName -> Array[Dictionary] ordered by "order"
var character_roster: Dictionary = {}     # "for_kind|for_id" -> character and clip set row
var character_clips: Dictionary = {}      # StringName (clip_set) -> Array[Dictionary]

var abilities: Dictionary = {}            # StringName -> AbilityDefinition
var classes: Dictionary = {}              # StringName -> ClassDefinition
var enemies: Dictionary = {}              # StringName -> EnemyDefinition
var runes: Dictionary = {}                # StringName -> RuneDefinition

var _enemy_index: Array[StringName] = []
var _ability_index: Array[StringName] = []
var _content_hash: String = ""


func _ready() -> void:
	ensure_loaded()


func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	_load_tables()
	_load_definitions()
	_validate()
	_content_hash = _compute_content_hash()
	for e: String in errors:
		push_error("GameData: " + e)


# --- Lookups ---------------------------------------------------------------

func rule(key: StringName) -> float:
	if not rules.has(key):
		push_error("GameData: missing rule '%s'" % key)
		return 0.0
	return rules[key]


func rule_ticks(key: StringName) -> int:
	return roundi(rule(key) * rule(&"sim_tickrate"))


func ability(id: StringName) -> AbilityDefinition:
	return abilities.get(id) as AbilityDefinition


func class_def(id: StringName) -> ClassDefinition:
	return classes.get(id) as ClassDefinition


func enemy(id: StringName) -> EnemyDefinition:
	return enemies.get(id) as EnemyDefinition


func rune(id: StringName) -> RuneDefinition:
	return runes.get(id) as RuneDefinition


func signature_row(primer: StringName, finisher: StringName) -> Dictionary:
	return signatures.get("%s|%s" % [primer, finisher], {}) as Dictionary


func surface_reaction(material: StringName, element: StringName) -> Dictionary:
	return surface_reactions.get("%s|%s" % [material, element], {}) as Dictionary


func surface_code(material: StringName) -> int:
	var row: Dictionary = surface_materials.get(material, {})
	return int(row.get("code", 0))


func surface_name(code: int) -> StringName:
	return surface_codes.get(code, &"none") as StringName


func waves(encounter: StringName) -> Array:
	return waves_by_encounter.get(encounter, []) as Array


## Rooms of a multi-room expedition in order (empty for single-room encounters such as the arena).
func rooms(expedition: StringName) -> Array:
	return rooms_by_expedition.get(expedition, []) as Array


func xp_to_next(level: int) -> int:
	for row: Dictionary in xp_rows:
		if int(row["level"]) == level:
			return int(row["xp_to_next"])
	return 0


func mass_of(mass_class: StringName) -> float:
	return rule(StringName("mass_" + String(mass_class)))


func velocity_cap_of(mass_class: StringName) -> float:
	return rule(StringName("knockback_cap_" + String(mass_class)))


## Stable small integer for an enemy ID (same on both PCs when the content hash matches).
func enemy_index(id: StringName) -> int:
	return _enemy_index.find(id)


func enemy_id_at(index: int) -> StringName:
	if index < 0 or index >= _enemy_index.size():
		return &""
	return _enemy_index[index]


func ability_index(id: StringName) -> int:
	return _ability_index.find(id)


func ability_id_at(index: int) -> StringName:
	if index < 0 or index >= _ability_index.size():
		return &""
	return _ability_index[index]


func content_hash() -> String:
	return _content_hash


func build_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


# --- Loading ---------------------------------------------------------------

func _table(file_name: String, schema: Dictionary, key: String = "") -> CsvTable:
	var table := CsvTable.load_table(TABLE_DIR + file_name, schema, key)
	errors.append_array(table.errors)
	return table


func _load_tables() -> void:
	var rules_table := _table("rules.csv", {"key": T.NAME, "value": T.FLOAT, "unit": T.STRING, "description": T.STRING}, "key")
	for row: Dictionary in rules_table.rows:
		rules[row["key"]] = row["value"]

	var primer_table := _table("primers.csv", {
		"primer": T.NAME, "effect_id": T.NAME, "name": T.STRING, "element": T.NAME, "radius": T.FLOAT,
		"duration": T.FLOAT, "magnitude": T.FLOAT, "damage_scale": T.FLOAT, "description": T.STRING}, "primer")
	for row: Dictionary in primer_table.rows:
		primers[row["primer"]] = row

	var finisher_table := _table("finishers.csv", {
		"finisher": T.NAME, "twist_id": T.NAME, "name": T.STRING, "radius": T.FLOAT, "magnitude": T.FLOAT,
		"impulse": T.FLOAT, "description": T.STRING}, "finisher")
	for row: Dictionary in finisher_table.rows:
		finishers[row["finisher"]] = row

	var sig_table := _table("signature_reactions.csv", {
		"primer": T.NAME, "finisher": T.NAME, "reaction_id": T.NAME, "name": T.STRING, "pairing": T.STRING,
		"radius": T.FLOAT, "duration": T.FLOAT, "magnitude": T.FLOAT, "damage_scale": T.FLOAT, "impulse": T.FLOAT,
		"description": T.STRING}, "reaction_id")
	for row: Dictionary in sig_table.rows:
		var key := "%s|%s" % [row["primer"], row["finisher"]]
		if signatures.has(key):
			errors.append("signature_reactions.csv: two signatures for %s" % key)
		signatures[key] = row

	var mat_table := _table("surface_materials.csv", {
		"material": T.NAME, "code": T.INT, "speed_multiplier": T.FLOAT, "friction": T.FLOAT,
		"knockback_multiplier": T.FLOAT, "hazard_dps": T.FLOAT, "hazard_type": T.NAME, "undead_dps": T.FLOAT,
		"hero_regen_fraction": T.FLOAT, "description": T.STRING}, "material")
	for row: Dictionary in mat_table.rows:
		surface_materials[row["material"]] = row
		surface_codes[int(row["code"])] = row["material"]

	var react_table := _table("surface_reactions.csv", {
		"material": T.NAME, "element": T.NAME, "result": T.NAME, "base_after": T.NAME, "add_flags": T.NAME_LIST,
		"clear_flags": T.NAME_LIST, "event": T.NAME, "duration_s": T.FLOAT})
	for row: Dictionary in react_table.rows:
		var key := "%s|%s" % [row["material"], row["element"]]
		if surface_reactions.has(key):
			errors.append("surface_reactions.csv: duplicate rule %s" % key)
		surface_reactions[key] = row

	var attr_table := _table("attribute_effects.csv", {"attribute": T.NAME, "stat": T.NAME, "per_point": T.FLOAT, "description": T.STRING})
	attribute_effects.assign(attr_table.rows)

	var xp_table := _table("xp_curve.csv", {"level": T.INT, "xp_to_next": T.INT, "total_xp": T.INT}, "level")
	xp_rows.assign(xp_table.rows)

	var wave_table := _table("encounter_waves.csv", {"encounter": T.NAME, "wave": T.INT, "enemy": T.NAME, "count": T.INT, "spawn": T.NAME})
	for row: Dictionary in wave_table.rows:
		var enc: StringName = row["encounter"]
		var list: Array = waves_by_encounter.get(enc, [])
		var wave_index: int = int(row["wave"]) - 1
		while list.size() <= wave_index:
			list.append([])
		(list[wave_index] as Array).append(row)
		waves_by_encounter[enc] = list

	var room_table := _table("expedition_rooms.csv", {"expedition": T.NAME, "order": T.INT, "room": T.NAME, "kind": T.NAME,
		"encounter": T.NAME, "xp": T.INT, "label": T.STRING, "hint": T.STRING})
	for row: Dictionary in room_table.rows:
		var exp: StringName = row["expedition"]
		var list: Array = rooms_by_expedition.get(exp, [])
		list.append(row)
		rooms_by_expedition[exp] = list
	for exp: StringName in rooms_by_expedition.keys():
		(rooms_by_expedition[exp] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))

	var roster_table: CsvTable = _table("character_roster.csv", {"for_kind": T.NAME, "for_id": T.NAME,
		"character": T.NAME, "clip_set": T.NAME})
	for row: Dictionary in roster_table.rows:
		character_roster["%s|%s" % [row["for_kind"], row["for_id"]]] = row

	var clips_table: CsvTable = _table("character_clips.csv", {"clip_set": T.NAME, "role": T.NAME,
		"clip": T.NAME, "start_s": T.FLOAT, "contact_s": T.FLOAT, "end_s": T.FLOAT,
		"layer": T.NAME, "loop": T.BOOL, "speed_mps": T.FLOAT, "notes": T.STRING})
	for row: Dictionary in clips_table.rows:
		var clip_set: StringName = row["clip_set"]
		if not character_clips.has(clip_set):
			character_clips[clip_set] = [] as Array[Dictionary]
		(character_clips[clip_set] as Array[Dictionary]).append(row)


func _load_definitions() -> void:
	_load_kind(&"ability", abilities, "AbilityDefinition")
	_load_kind(&"class", classes, "ClassDefinition")
	_load_kind(&"enemy", enemies, "EnemyDefinition")
	_load_kind(&"rune", runes, "RuneDefinition")
	_enemy_index.clear()
	for id: StringName in enemies.keys():
		_enemy_index.append(id)
	_enemy_index.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	_ability_index.clear()
	for id: StringName in abilities.keys():
		_ability_index.append(id)
	_ability_index.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))


func _load_kind(kind: StringName, into: Dictionary, expected_class: String) -> void:
	var dir: String = DEF_DIRS[kind]
	if not DirAccess.dir_exists_absolute(dir):
		errors.append("missing definition folder %s" % dir)
		return
	var files := ResourceLoader.list_directory(dir)
	var names: Array[String] = []
	for f: String in files:
		if f.ends_with(".tres") or f.ends_with(".res"):
			names.append(f)
	names.sort()
	for f: String in names:
		var res := ResourceLoader.load(dir + f)
		if res == null:
			errors.append("%s%s failed to load" % [dir, f])
			continue
		var script := res.get_script() as Script
		if script == null or script.get_global_name() != expected_class:
			errors.append("%s%s is not a %s" % [dir, f, expected_class])
			continue
		var id: StringName = res.get("id")
		if id == &"":
			errors.append("%s%s has no id" % [dir, f])
			continue
		if into.has(id):
			errors.append("duplicate %s id '%s' (%s)" % [kind, id, f])
			continue
		into[id] = res


# --- Validation ------------------------------------------------------------

func _validate() -> void:
	var required_primers: Array[StringName] = [&"dazed", &"sanctified", &"frozen", &"shocked", &"marked", &"envenomed", &"rooted", &"terrified"]
	var required_finishers: Array[StringName] = [&"impact", &"arcane", &"precision", &"primal"]
	for p: StringName in required_primers:
		if not primers.has(p):
			errors.append("primers.csv lacks '%s'" % p)
	for f: StringName in required_finishers:
		if not finishers.has(f):
			errors.append("finishers.csv lacks '%s'" % f)
	for key: String in signatures.keys():
		var row: Dictionary = signatures[key]
		if not primers.has(row["primer"]) or not finishers.has(row["finisher"]):
			errors.append("signature %s references an unknown primer or finisher" % row["reaction_id"])
	for key: String in surface_reactions.keys():
		var row: Dictionary = surface_reactions[key]
		if not surface_materials.has(row["material"]) or not surface_materials.has(row["result"]):
			errors.append("surface rule %s references an unknown material" % key)
		if row["base_after"] != &"" and not surface_materials.has(row["base_after"]):
			errors.append("surface rule %s has unknown base_after" % key)
	for id: StringName in abilities.keys():
		var a: AbilityDefinition = abilities[id]
		if a.primer != &"" and not primers.has(a.primer):
			errors.append("ability %s applies unknown primer %s" % [id, a.primer])
		if a.finisher != &"" and not finishers.has(a.finisher):
			errors.append("ability %s has unknown finisher %s" % [id, a.finisher])
		if a.active_ticks < 1:
			errors.append("ability %s needs at least one active tick" % id)
		if a.class_id != &"any" and not classes.has(a.class_id):
			errors.append("ability %s belongs to unknown class %s" % [id, a.class_id])
	for id: StringName in classes.keys():
		var c: ClassDefinition = classes[id]
		if not abilities.has(c.basic_attack):
			errors.append("class %s basic attack %s missing" % [id, c.basic_attack])
		for ab: StringName in c.abilities:
			if not abilities.has(ab):
				errors.append("class %s references missing ability %s" % [id, ab])
	for enc: StringName in waves_by_encounter.keys():
		for wave: Array in waves_by_encounter[enc]:
			if wave.is_empty():
				errors.append("encounter %s has an empty wave" % enc)
			for row: Dictionary in wave:
				if not enemies.has(row["enemy"]):
					errors.append("encounter %s spawns unknown enemy %s" % [enc, row["enemy"]])
	var room_kinds: Array[StringName] = [&"combat", &"puzzle", &"elite", &"shrine", &"boss"]
	for exp: StringName in rooms_by_expedition.keys():
		for row: Dictionary in rooms_by_expedition[exp]:
			if not room_kinds.has(row["kind"]):
				errors.append("expedition %s room %s has unknown kind %s" % [exp, row["room"], row["kind"]])
			var enc: StringName = row["encounter"]
			if row["kind"] in [&"combat", &"elite", &"boss"] and not waves_by_encounter.has(enc):
				errors.append("expedition %s room %s needs encounter waves '%s'" % [exp, row["room"], enc])
	for key: String in ["sim_tickrate", "primer_duration_s", "resonance_multiplier", "mass_light", "mass_medium", "mass_heavy"]:
		if not rules.has(StringName(key)):
			errors.append("rules.csv lacks '%s'" % key)


# --- Content manifest -------------------------------------------------------

func _compute_content_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var table_files := DirAccess.get_files_at(TABLE_DIR)
	var csvs: Array[String] = []
	for f: String in table_files:
		if f.ends_with(".csv"):
			csvs.append(f)
	csvs.sort()
	for f: String in csvs:
		var file := FileAccess.open(TABLE_DIR + f, FileAccess.READ)
		if file == null:
			continue
		ctx.update(f.to_utf8_buffer())
		ctx.update(file.get_as_text().replace("\r\n", "\n").to_utf8_buffer())
	for kind: StringName in [&"ability", &"class", &"enemy", &"rune"]:
		var dict: Dictionary = {&"ability": abilities, &"class": classes, &"enemy": enemies, &"rune": runes}[kind]
		var ids: Array = dict.keys()
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		for id: StringName in ids:
			ctx.update(definition_signature(dict[id] as Resource).to_utf8_buffer())
	return ctx.finish().hex_encode()


## Canonical text of a definition's stored script properties (independent of .tres/.res encoding).
static func definition_signature(res: Resource) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for prop: Dictionary in res.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			parts.append("%s=%s" % [prop["name"], var_to_str(res.get(prop["name"]))])
	return "\n".join(parts)
