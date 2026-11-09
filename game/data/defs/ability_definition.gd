class_name AbilityDefinition
extends Resource
## Immutable description of one ability (or basic attack / shove). Runtime state lives elsewhere.
## Timing is in simulation ticks (60 Hz). Every number here is a tuning seed.

@export var id: StringName
@export var display_name: String
## Class that owns it, or &"any" for universal actions such as the shove.
@export var class_id: StringName
@export var unlock_level: int = 1
@export_multiline var description: String
## Tag shown on tooltips: "Primer: Frozen", "Finisher: Impact", "Support", ...
@export var tag_label: String
## Behaviour tags used by runes and the resolver (melee, projectile, area, charge, line, blink, support, ...).
@export var tags: Array[StringName] = []
## Primer applied on hit (&"" if none).
@export var primer: StringName
## Finisher type that consumes primers (&"" if none).
@export var finisher: StringName
## melee_arc | projectile | line | charge | self_area | ground_area | blink | flask
@export var delivery: StringName
@export var damage_type: StringName = &"physical"
## Element used by Elemental Weave and by surfaces (&"" for none).
@export var element: StringName
@export var base_damage: float = 0.0
@export var added_effectiveness: float = 1.0
@export var stagger: float = 0.0
## Knockback impulse J (velocity change = J / mass).
@export var impulse: float = 0.0
@export var range_m: float = 0.0
@export var radius_m: float = 0.0
@export var arc_deg: float = 0.0
@export var projectile_speed: float = 0.0
@export var projectile_radius: float = 0.3
@export var pierce: int = 0
@export var windup_ticks: int = 0
@export var active_ticks: int = 1
@export var recovery_ticks: int = 0
## Ticks after the start from which another action or a dodge may cancel this one (-1: only after it ends).
@export var cancel_tick: int = -1
@export var cooldown_ticks: int = 0
@export var cost: float = 0.0
@export var resource_gain: float = 0.0
## Movement multiplier while this action runs (1 = full speed, 0 = rooted).
@export var move_multiplier: float = 0.35
## Charges and leaps: speed and duration of the authored movement.
@export var move_speed: float = 0.0
@export var move_ticks: int = 0
## Surface element written by the ability (&"" for none) and its footprint.
@export var surface_element: StringName
@export var surface_radius_m: float = 0.0
## Barrier granted as a fraction of max health (support abilities).
@export var barrier_fraction: float = 0.0
@export var barrier_duration_s: float = 0.0
## Status applied on hit (&"" for none): burning, frozen, ...
@export var status: StringName
@export var status_duration_s: float = 0.0
@export var status_magnitude: float = 0.0
## Rune compatibility tags.
@export var rune_tags: Array[StringName] = []


func total_ticks() -> int:
	return windup_ticks + active_ticks + recovery_ticks


func is_primer() -> bool:
	return primer != &""


func is_finisher() -> bool:
	return finisher != &""


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
