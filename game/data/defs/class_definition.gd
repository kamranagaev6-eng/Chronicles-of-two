class_name ClassDefinition
extends Resource
## One playable class. Abilities are referenced by stable ID, never embedded.

@export var id: StringName
@export var display_name: String
@export var epithet: String
@export_multiline var description: String
@export var resource_id: StringName
@export var resource_label: String
@export var resource_max: float = 100.0
@export var resource_start: float = 0.0
@export var resource_regen_per_s: float = 0.0
@export var max_health: float = 200.0
@export var armour: float = 0.0
@export var move_speed: float = 6.0
@export var attr_str: int = 10
@export var attr_dex: int = 10
@export var attr_con: int = 10
@export var attr_int: int = 10
@export var attr_wis: int = 10
@export var attr_cha: int = 10
@export var basic_attack: StringName
## Core abilities in unlock order (levels 1, 1, 2, 3, 6, 9, 15, 20, 25, 30 when all exist).
@export var abilities: Array[StringName] = []
@export var primer_types: Array[StringName] = []
@export var finisher_type: StringName
@export var signature_name: String
@export_multiline var signature_text: String
@export var specializations: PackedStringArray = PackedStringArray()


func attributes() -> Dictionary:
	return {
		&"str": attr_str, &"dex": attr_dex, &"con": attr_con,
		&"int": attr_int, &"wis": attr_wis, &"cha": attr_cha,
	}
