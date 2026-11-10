class_name CharacterKit
extends RefCounted
## Resolve a roster entry into a local rig, or leave the caller's placeholder in place.

static var enabled: bool = DisplayServer.get_name() != "headless"
static var _warned: Dictionary[StringName, bool] = {}


static func scene_path(character: StringName) -> String:
	return "res://assets/characters/%s/%s.glb" % [character, character]


static func has_hero(class_id: StringName) -> bool:
	GameData.ensure_loaded()
	return GameData.character_roster.has("class|%s" % class_id)


static func hero_rig(class_id: StringName, accent: Color) -> CharacterRig:
	if not enabled or not has_hero(class_id):
		return null
	var row: Dictionary = GameData.character_roster["class|%s" % class_id]
	var character: StringName = row.get("character", &"")
	var path: String = scene_path(character)
	if not ResourceLoader.exists(path) or not _has_glb_header(path):
		_warn_once(character, "character scene is missing or invalid: " + path)
		return null
	var scene: PackedScene = ResourceLoader.load(path) as PackedScene
	if scene == null:
		_warn_once(character, "character scene could not be loaded: " + path)
		return null
	var rig: CharacterRig = CharacterRig.create(scene, row.get("clip_set", &"") as StringName)
	if rig == null:
		_warn_once(character, "character rig has no skeleton or a known clip set: " + path)
		return null
	rig.set_accent(accent)
	return rig


## A checked-out LFS pointer must not be passed to the scene loader. In an exported build the
## source file need not exist, so let ResourceLoader resolve its remapped scene there.
static func _has_glb_header(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return file.get_buffer(4) == PackedByteArray([0x67, 0x6c, 0x54, 0x46])


static func _warn_once(character: StringName, message: String) -> void:
	if not _warned.has(character):
		_warned[character] = true
		push_warning("CharacterKit: " + message)
