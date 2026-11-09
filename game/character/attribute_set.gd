class_name AttributeSet
extends RefCounted
## Six attributes. Combat bonuses come from attribute_effects.csv (per point above 10).
## Roleplay checks use permanent scores only, with the modifier capped at +5.

const NAMES: Array[StringName] = [&"str", &"dex", &"con", &"int", &"wis", &"cha"]
const ROLEPLAY_MOD_CAP := 5

var scores: Dictionary = {&"str": 10, &"dex": 10, &"con": 10, &"int": 10, &"wis": 10, &"cha": 10}


static func from_dictionary(d: Dictionary) -> AttributeSet:
	var a := AttributeSet.new()
	for n: StringName in NAMES:
		if d.has(n):
			a.scores[n] = int(d[n])
		elif d.has(String(n)):
			a.scores[n] = int(d[String(n)])
	return a


func score(attr: StringName) -> int:
	return int(scores.get(attr, 10))


static func modifier_for(score_value: int) -> int:
	return floori((score_value - 10) / 2.0)


func modifier(attr: StringName) -> int:
	return modifier_for(score(attr))


func roleplay_modifier(attr: StringName) -> int:
	return mini(modifier(attr), ROLEPLAY_MOD_CAP)


## Sum of a derived combat stat (e.g. &"physical_damage_inc") from the attribute effects table.
func stat(stat_name: StringName) -> float:
	var total := 0.0
	for row: Dictionary in GameData.attribute_effects:
		if row["stat"] == stat_name:
			total += float(score(row["attribute"]) - 10) * float(row["per_point"])
	return total
