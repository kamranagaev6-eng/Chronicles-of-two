class_name ClipSet
extends RefCounted
## Presentation rows from character_clips.csv. Times refer to the imported clips, in seconds.

class ClipRow extends RefCounted:
	var role: StringName
	var clip: StringName
	var start_s: float = 0.0
	var contact_s: float = 0.0
	var end_s: float = 0.0
	var layer: StringName = &"full"
	var loop: bool = false
	var speed_mps: float = 0.0


var _rows: Dictionary[StringName, ClipRow] = {}
var _fallback: ClipRow = ClipRow.new()


static func for_set(clip_set: StringName) -> ClipSet:
	GameData.ensure_loaded()
	if not GameData.character_clips.has(clip_set):
		return null
	var clips := new()
	for source: Dictionary in GameData.character_clips[clip_set]:
		var value: ClipRow = ClipRow.new()
		value.role = source["role"]
		value.clip = source["clip"]
		value.start_s = source["start_s"]
		value.contact_s = source["contact_s"]
		value.end_s = source["end_s"]
		value.layer = source["layer"]
		value.loop = source["loop"]
		value.speed_mps = source["speed_mps"]
		clips._rows[value.role] = value
	# Even a damaged table cannot hand a null ability row to a driver. The final empty
	# row has no clip, so it requests no action when neither authored fallback survives.
	clips._fallback = clips.row(&"action_default")
	if clips._fallback == null:
		clips._fallback = clips.row(&"idle")
	if clips._fallback == null:
		clips._fallback = ClipRow.new()
	return clips


func row(role: StringName) -> ClipRow:
	return _rows.get(role) as ClipRow


func all_rows() -> Array[ClipRow]:
	var rows: Array[ClipRow] = []
	rows.assign(_rows.values())
	return rows


func base_row(role: StringName) -> ClipRow:
	var found: ClipRow = row(role)
	return found if found != null else row(&"idle")


func ability_row(def: AbilityDefinition) -> ClipRow:
	if def != null:
		var found: ClipRow = row(StringName("ability:%s" % def.id))
		if found == null:
			found = row(StringName("delivery:%s" % def.delivery))
		if found != null:
			return found
	return _fallback


static func clip_time(value: ClipRow, windup_s: float, rest_s: float, elapsed_s: float) -> float:
	var e: float = maxf(elapsed_s, 0.0)
	if windup_s > 0.0 and e <= windup_s:
		return lerpf(value.start_s, value.contact_s, e / windup_s)
	var after: float = e - maxf(windup_s, 0.0)
	return lerpf(value.contact_s, value.end_s, 1.0 if rest_s <= 0.0 else minf(1.0, after / rest_s))


static func windup_rate(value: ClipRow, windup_s: float) -> float:
	return (value.contact_s - value.start_s) / windup_s if windup_s > 0.0 else 1.0
