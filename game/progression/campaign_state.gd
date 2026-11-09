class_name CampaignState
extends RefCounted
## Shape of the campaign data inside a checkpoint (plain JSON). Both heroes live in one save; each hero
## is bound to a player profile so both PCs load into the right identities whoever hosts.

const HERO_KEYS: Array[String] = ["a", "b"]


static func new_campaign(campaign_name: String, level: int) -> Dictionary:
	var total_xp := 0
	for row: Dictionary in GameData.xp_rows:
		if int(row["level"]) == level:
			total_xp = int(row["total_xp"])
	return {
		"campaign_name": campaign_name,
		"world_name": "",
		"level": level,
		"xp": total_xp,
		"heroes": {},
		"rune_library": {"fork": 1, "chain": 1, "pierce": 1, "reach": 1, "expansion": 1, "compression": 1},
		"materials": {},
		"bond": {"rank": "C", "nodes": [], "firsts": []},
		"emberrest": {"facilities": ["emberhearth"]},
		"quest_flags": {},
		"choices": {},
		"journal": [],
		"expedition": {"encounter": "arena_m1", "waves_cleared": 0, "victories": 0, "waystone": "arena_dais"},
		"stats": {"resonances": 0, "revives": 0, "slams": 0},
	}


static func default_loadout(class_id: StringName, level: int) -> Dictionary:
	var c := GameData.class_def(class_id)
	var abilities: Array = []
	if c != null:
		for ab: StringName in c.abilities:
			var def := GameData.ability(ab)
			if def != null and def.unlock_level <= level and abilities.size() < 4:
				abilities.append(String(ab))
	return {"abilities": abilities, "runes": {}}


static func make_hero(profile_id: String, hero_name: String, class_id: StringName, color: String, level: int) -> Dictionary:
	var c := GameData.class_def(class_id)
	var attrs: Dictionary = {}
	if c != null:
		for k: StringName in c.attributes().keys():
			attrs[String(k)] = c.attributes()[k]
	return {
		"profile_id": profile_id,
		"name": hero_name,
		"class_id": String(class_id),
		"color": color,
		"attributes": attrs,
		"loadouts": {String(class_id): default_loadout(class_id, level)},
	}


static func hero_key_for_profile(data: Dictionary, profile_id: String) -> String:
	var heroes: Dictionary = data.get("heroes", {})
	for key: String in HERO_KEYS:
		if heroes.has(key) and str((heroes[key] as Dictionary).get("profile_id", "")) == profile_id:
			return key
	return ""


## Bind a profile to its hero (creating one in a free slot if needed). Returns the hero key or "" when full.
static func bind_profile(data: Dictionary, profile_id: String, hero_name: String, class_id: StringName, color: String) -> String:
	var existing := hero_key_for_profile(data, profile_id)
	var heroes: Dictionary = data.get("heroes", {})
	if existing != "":
		var hero: Dictionary = heroes[existing]
		hero["name"] = hero_name
		select_class(data, existing, class_id)
		return existing
	for key: String in HERO_KEYS:
		if not heroes.has(key):
			heroes[key] = make_hero(profile_id, hero_name, class_id, color, int(data.get("level", 1)))
			data["heroes"] = heroes
			return key
	return ""


## Change class at Emberrest: the level stays, and each class keeps its own saved loadout.
static func select_class(data: Dictionary, hero_key: String, class_id: StringName) -> void:
	var heroes: Dictionary = data.get("heroes", {})
	if not heroes.has(hero_key):
		return
	var hero: Dictionary = heroes[hero_key]
	hero["class_id"] = String(class_id)
	var c := GameData.class_def(class_id)
	if c != null:
		var attrs: Dictionary = {}
		for k: StringName in c.attributes().keys():
			attrs[String(k)] = c.attributes()[k]
		hero["attributes"] = attrs
	var loadouts: Dictionary = hero.get("loadouts", {})
	if not loadouts.has(String(class_id)):
		loadouts[String(class_id)] = default_loadout(class_id, int(data.get("level", 1)))
	hero["loadouts"] = loadouts


static func loadout_of(data: Dictionary, hero_key: String) -> Dictionary:
	var hero: Dictionary = (data.get("heroes", {}) as Dictionary).get(hero_key, {})
	var cls := str(hero.get("class_id", ""))
	return ((hero.get("loadouts", {}) as Dictionary).get(cls, {"abilities": [], "runes": {}})) as Dictionary


static func add_journal(data: Dictionary, kind: String, text: String) -> void:
	var journal: Array = data.get("journal", [])
	journal.append({"kind": kind, "text": text, "entry": journal.size() + 1})
	data["journal"] = journal


static func summary(data: Dictionary) -> String:
	var heroes: Dictionary = data.get("heroes", {})
	var names: PackedStringArray = PackedStringArray()
	for key: String in HERO_KEYS:
		if heroes.has(key):
			var h: Dictionary = heroes[key]
			names.append("%s (%s)" % [h.get("name", "?"), h.get("class_id", "?")])
	var exp: Dictionary = data.get("expedition", {})
	return "Level %d · %s · %d waves cleared, %d victories" % [int(data.get("level", 1)), " & ".join(names), int(exp.get("waves_cleared", 0)), int(exp.get("victories", 0))]
