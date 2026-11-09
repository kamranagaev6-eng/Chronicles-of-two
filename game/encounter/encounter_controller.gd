class_name EncounterController
extends Node
## Host-only flow of the Milestone 1 arena: prepare at the Waystone, three waves from
## encounter_waves.csv, a Waystone checkpoint after every cleared wave, victory, and a restart from
## the latest Waystone when both heroes fall (XP and equipment are kept).

var arena: Node
var entities: EntityManager
var combat: CombatSystem
var encounter_id: StringName = &"arena_m1"
var waves: Array = []
var state: int = NetProtocol.WAVE_PREP
var wave: int = 0
var state_until: int = 0
var run_id: String = ""
var wave_entities: Array[int] = []
var xp_pending: int = 0
var victories: int = 0
var transactions := TransactionLog.new()
var _interact_ticks: int = 0
var _last_broadcast: Array = []


func setup(p_arena: Node, p_entities: EntityManager, p_combat: CombatSystem) -> void:
	arena = p_arena
	entities = p_entities
	combat = p_combat
	waves = GameData.waves(encounter_id)
	run_id = Crypto.new().generate_random_bytes(6).hex_encode()


func tick(t: int) -> void:
	match state:
		NetProtocol.WAVE_PREP:
			if _interacting_at_waystone():
				_start_wave(0, t)
		NetProtocol.WAVE_ACTIVE:
			if combat.all_heroes_down():
				_restart(t)
			elif _wave_cleared():
				_clear_wave(t)
		NetProtocol.WAVE_BREAK:
			if combat.all_heroes_down():
				_restart(t)
			elif t >= state_until or (_interacting_at_waystone() and t >= state_until - GameData.rule_ticks(&"wave_break_s") + 60):
				_start_wave(wave + 1, t)
		NetProtocol.WAVE_VICTORY:
			if t >= state_until:
				_set_state(NetProtocol.WAVE_PREP, 0, t)
		NetProtocol.WAVE_RESTART:
			if t >= state_until:
				_start_wave(wave, t)
	if t % 60 == 0:
		_broadcast(true)


func _interacting_at_waystone() -> bool:
	var near := false
	for slot in GameTypes.SLOT_COUNT:
		var h: Hero = arena.call("hero", slot)
		if h == null or not h.stats.is_alive():
			continue
		if GameTypes.flat(h.global_position - ArenaLayout.WAYSTONE).length() <= 2.6 and (h.input.held & GameTypes.BTN_INTERACT) != 0:
			near = true
	_interact_ticks = _interact_ticks + 1 if near else 0
	return _interact_ticks >= 20


func _wave_cleared() -> bool:
	for id: int in wave_entities:
		var e := entities.get_entity(id)
		if e != null and not e.dead:
			return false
	return true


func enemies_left() -> int:
	var n := 0
	for id: int in wave_entities:
		var e := entities.get_entity(id)
		if e != null and not e.dead:
			n += 1
	return n


func _start_wave(index: int, t: int) -> void:
	if index >= waves.size():
		index = 0
	wave = index
	_interact_ticks = 0
	wave_entities.clear()
	var rows: Array = waves[index]
	var spread := 0
	for row: Dictionary in rows:
		var base: Vector3 = ArenaLayout.SPAWNS.get(row["spawn"], Vector3.ZERO)
		for i in int(row["count"]):
			var angle := TAU * float(spread) / 7.0
			var pos := base + Vector3(cos(angle), 0, sin(angle)) * (0.9 + 0.5 * (spread % 3))
			spread += 1
			var e := entities.spawn_enemy(row["enemy"], pos, t)
			if e != null:
				wave_entities.append(e.id)
	_set_state(NetProtocol.WAVE_ACTIVE, index, t)
	print("[encounter] tick %d: wave %d/%d started with %d enemies" % [t, index + 1, waves.size(), wave_entities.size()])
	arena.call("toast_all", "Wave %d of %d" % [index + 1, waves.size()])


func _clear_wave(t: int) -> void:
	combat.restore_heroes(false)
	for slot in GameTypes.SLOT_COUNT:
		var h: Hero = arena.call("hero", slot)
		if h != null:
			h.queue_command({"type": &"flask_refill"})
	var last := wave >= waves.size() - 1
	print("[encounter] tick %d: wave %d/%d cleared%s" % [t, wave + 1, waves.size(), " (victory)" if last else ""])
	var data: Dictionary = arena.call("campaign_data")
	var exp: Dictionary = data.get("expedition", {})
	exp["waves_cleared"] = int(exp.get("waves_cleared", 0)) + 1
	data["expedition"] = exp
	_award_xp(data, "wave:%s:%d:%d" % [run_id, victories, wave])
	if last:
		victories += 1
		exp["victories"] = int(exp.get("victories", 0)) + 1
		transactions.execute("victory:%s:%d" % [run_id, victories], func() -> bool:
			CampaignState.add_journal(data, "victory", "The Drowned Hall was cleared together (victory %d)." % int(exp["victories"]))
			return true)
		arena.call("commit_checkpoint", "victory")
		_set_state(NetProtocol.WAVE_VICTORY, wave, t + 360)
		arena.call("toast_all", "Victory! The hall is quiet again.")
		run_id = Crypto.new().generate_random_bytes(6).hex_encode()
	else:
		arena.call("commit_checkpoint", "waystone")
		_set_state(NetProtocol.WAVE_BREAK, wave, t + GameData.rule_ticks(&"wave_break_s"))
		arena.call("toast_all", "Wave cleared. Waystone checkpoint saved.")


func _award_xp(data: Dictionary, txn: String) -> void:
	var amount := xp_pending
	xp_pending = 0
	transactions.execute(txn, func() -> int:
		data["xp"] = int(data.get("xp", 0)) + amount
		var level := int(data.get("level", 1))
		while level < 40 and int(data["xp"]) >= _total_xp_for(level + 1):
			level += 1
		data["level"] = level
		arena.call("emit_event", [NetProtocol.EV_XP, amount, level, int(data["xp"])])
		return amount)


static func _total_xp_for(level: int) -> int:
	for row: Dictionary in GameData.xp_rows:
		if int(row["level"]) == level:
			return int(row["total_xp"])
	return 1 << 30


func on_enemy_killed(e: Enemy) -> void:
	xp_pending += e.def.xp


## Both heroes fell: restart the wave from the latest Waystone. Progress already committed stays.
func _restart(t: int) -> void:
	for id: int in wave_entities:
		var e := entities.get_entity(id)
		if e != null:
			entities.despawn(e)
	wave_entities.clear()
	xp_pending = 0
	combat.reset_encounter_state()
	arena.call("reset_surfaces")
	combat.restore_heroes(true)
	for slot in GameTypes.SLOT_COUNT:
		var h: Hero = arena.call("hero", slot)
		if h != null:
			h.queue_command({"type": &"reset"})
			h.queue_command({"type": &"teleport", "position": ArenaLayout.HERO_SPAWNS[slot]})
	print("[encounter] tick %d: both heroes fell, restarting wave %d" % [t, wave + 1])
	arena.call("chronicle_add", "defeat", "The hall overwhelmed you both; you regrouped at the Waystone.")
	_set_state(NetProtocol.WAVE_RESTART, wave, t + 180)
	arena.call("toast_all", "You both fell. Regrouping at the Waystone...")


func _set_state(new_state: int, new_wave: int, until: int) -> void:
	state = new_state
	wave = new_wave
	state_until = until
	_broadcast(false)


func _broadcast(only_if_changed: bool) -> void:
	var ev := [NetProtocol.EV_WAVE, state, wave, waves.size(), enemies_left()]
	if only_if_changed and ev == _last_broadcast:
		return
	_last_broadcast = ev
	arena.call("emit_event", ev)
