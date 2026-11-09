class_name HeroStats
extends RefCounted
## Health, barrier and downed state. The host owns these numbers; guests display the replicated copy.

var max_health: float = 200.0
var health: float = 200.0
var barrier: float = 0.0
var barrier_until: int = -1
## NetProtocol.LIFE_ALIVE / LIFE_DOWNED / LIFE_FALLEN
var life: int = 0
var downed_until: int = -1
var revive_progress: float = 0.0
var reviver_slot: int = -1
var protected_until: int = -1
## Guests receive the remaining downed time directly.
var downed_left_s: float = 0.0
var dirty: bool = true


func is_alive() -> bool:
	return life == NetProtocol.LIFE_ALIVE


func health_fraction() -> float:
	return clampf(health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0


func encode(slot: int, tick: int) -> Array:
	var left := maxf(0.0, (downed_until - tick) / 60.0) if life == NetProtocol.LIFE_DOWNED else 0.0
	return [NetProtocol.EV_HERO_STATS, slot, snappedf(health, 0.1), max_health, snappedf(barrier, 0.1), life, snappedf(left, 0.1), snappedf(revive_progress, 0.01)]


func apply_encoded(ev: Array) -> void:
	health = float(ev[2])
	max_health = float(ev[3])
	barrier = float(ev[4])
	life = int(ev[5])
	downed_left_s = float(ev[6])
	revive_progress = float(ev[7])
