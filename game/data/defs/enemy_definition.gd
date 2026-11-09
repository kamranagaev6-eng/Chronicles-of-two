class_name EnemyDefinition
extends Resource
## Data-driven enemy: stats, body, and the single attack its state machine uses.

@export var id: StringName
@export var display_name: String
## normal | elite | boss
@export var rank: StringName = &"normal"
@export var undead: bool = true
## light | medium | heavy (masses come from rules.csv)
@export var mass_class: StringName = &"medium"
@export var max_health: float = 100.0
@export var armour: float = 0.0
@export var resist_fire: float = 0.0
@export var resist_cold: float = 0.0
@export var resist_lightning: float = 0.0
@export var resist_holy: float = 0.0
@export var stagger_max: float = 50.0
@export var move_speed: float = 3.5
@export var radius: float = 0.45
@export var height: float = 1.8
## melee | ranged | none (which Combat Director pool it claims from)
@export var token_kind: StringName = &"melee"
## swipe | arrow | slam | none
@export var attack_kind: StringName = &"swipe"
@export var attack_range: float = 1.8
@export var preferred_range: float = 1.6
@export var telegraph_ticks: int = 36
@export var active_ticks: int = 4
@export var recovery_ticks: int = 48
@export var attack_damage: float = 10.0
@export var attack_damage_type: StringName = &"physical"
@export var attack_radius: float = 1.8
@export var attack_arc_deg: float = 100.0
@export var attack_impulse: float = 0.0
@export var projectile_speed: float = 0.0
@export var xp: int = 10
## Training dummies never die and never attack.
@export var immortal: bool = false
## Chained enemies never stray further than this from where they spawned (0 = free).
@export var leash_radius: float = 0.0
## Damage taken while warded (the Abbess while her anchors hold); 1 = no ward.
@export var ward_multiplier: float = 1.0
@export var body_color: Color = Color(0.45, 0.5, 0.45)
@export var accent_color: Color = Color(0.4, 0.9, 0.8)


func resist(damage_type: StringName) -> float:
	match damage_type:
		&"fire":
			return resist_fire
		&"cold":
			return resist_cold
		&"lightning":
			return resist_lightning
		&"holy":
			return resist_holy
	return 0.0


func is_elite_or_boss() -> bool:
	return rank == &"elite" or rank == &"boss"
