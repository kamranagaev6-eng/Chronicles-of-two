class_name StaggerState
extends RefCounted
## One stagger meter per enemy, separate from health and from primer tags.
## Ordinary enemies: a full meter stuns them. Elites and bosses: a full meter Staggers them
## (they take more damage: the Double Tech window), then a recovery period prevents a repeat.
## Elites take shortened control with diminishing returns; bosses ignore hard control and convert it to stagger.

enum Event { NONE, STUN, STAGGER }

var max_value: float = 50.0
var value: float = 0.0
var rank: StringName = &"normal"
var stunned_until: int = -1
var staggered_until: int = -1
var recovery_until: int = -1
var _dr_count: int = 0
var _dr_window_until: int = -1

var stun_ticks: int = 90
var staggered_ticks: int = 360
var recovery_ticks: int = 480
var primed_multiplier: float = 2.0
var dr_window_ticks: int = 600
var dr_step: float = 0.5


func _init(p_max: float = 50.0, p_rank: StringName = &"normal") -> void:
	max_value = p_max
	rank = p_rank


func configure_from_rules() -> void:
	stun_ticks = GameData.rule_ticks(&"stun_s")
	staggered_ticks = GameData.rule_ticks(&"staggered_s")
	recovery_ticks = GameData.rule_ticks(&"stagger_recovery_s")
	primed_multiplier = GameData.rule(&"primed_stagger_multiplier")
	dr_window_ticks = GameData.rule_ticks(&"control_dr_window_s")
	dr_step = GameData.rule(&"control_dr_step")


func is_elite_or_boss() -> bool:
	return rank == &"elite" or rank == &"boss"


func is_stunned(tick: int) -> bool:
	return tick < stunned_until


func is_staggered(tick: int) -> bool:
	return tick < staggered_until


func in_recovery(tick: int) -> bool:
	return tick >= staggered_until and tick < recovery_until


func fraction() -> float:
	return clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0


## Add stagger damage. Primed enemies take stagger twice as fast. Returns the resulting event.
func add(amount: float, primed: bool, tick: int) -> int:
	if amount <= 0.0 or max_value <= 0.0:
		return Event.NONE
	if is_staggered(tick) or in_recovery(tick) or is_stunned(tick):
		return Event.NONE
	value += amount * (primed_multiplier if primed else 1.0)
	if value < max_value:
		return Event.NONE
	value = 0.0
	if is_elite_or_boss():
		staggered_until = tick + staggered_ticks
		recovery_until = staggered_until + recovery_ticks
		return Event.STAGGER
	stunned_until = tick + stun_ticks
	return Event.STUN


## Duration (ticks) a hard control effect actually lasts on this enemy.
## Ordinary: full. Elite: halved, then halved again per repeat inside the window, immune after three.
## Boss: zero (callers convert the control to stagger with control_to_stagger()).
func control_duration(base_ticks: int, tick: int) -> int:
	if rank == &"boss":
		return 0
	if rank != &"elite":
		return base_ticks
	if tick >= _dr_window_until:
		_dr_count = 0
	_dr_window_until = tick + dr_window_ticks
	_dr_count += 1
	if _dr_count > 3:
		return 0
	return int(base_ticks * pow(dr_step, _dr_count))


## Stagger granted when a boss (or an immune elite) resists a control effect.
static func control_to_stagger(base_ticks: int) -> float:
	return float(base_ticks) * 0.25
