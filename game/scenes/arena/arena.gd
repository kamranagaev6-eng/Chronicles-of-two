extends Node3D
## Milestone 1 combat arena. Both PCs build the same world and heroes; the host additionally runs
## enemies, combat and the encounter, and streams results: packed crowd snapshots (20 Hz, unreliable),
## gameplay events (reliable), surface patches (10 Hz) and hero stats. The guest interpolates and
## presents. Shared pause, pings, loadout changes and reconnects all go through the host.

var setup: Dictionary = {}
var is_host: bool = false
var local_slot: int = 0
var heroes: Array = [null, null]
var world: Node3D
var surface_layer: SurfaceLayer
var entities: EntityManager
var combat: CombatSystem
var encounter: EncounterController
var presentation: Presentation
var camera_rig: CameraRig
var hud: Hud
var tether: BondTether
var snapshots := SnapshotBuffer.new()

var encounter_view: Dictionary = {"state": NetProtocol.WAVE_PREP, "wave": 0, "count": 3, "left": 0}
var bond_meter: float = 0.0
var paused: bool = false
var pause_reason: String = ""
var _pause_ready: Array[bool] = [false, false]
var _drop_deadline: int = -1
var _release_at: int = -1
var _guest_ready: bool = false
var _outgoing: Array = []
var _stats_counter: int = 0
var _firsts: Dictionary = {}
var _campaign: Dictionary = {}
var _txn := TransactionLog.new()
var _headless: bool = false
var _started_msec: int = 0


func _ready() -> void:
	setup = Net.session_setup
	if setup.is_empty() or not Net.is_online():
		get_tree().change_scene_to_file.call_deferred(Net.BOOT_SCENE)
		return
	_started_msec = Time.get_ticks_msec()
	_headless = Settings.is_headless()
	is_host = Net.is_host()
	local_slot = Net.local_slot
	_campaign = (setup.get("campaign", {}) as Dictionary).duplicate(true)
	Net.handler = self

	world = Node3D.new()
	world.name = "World"
	add_child(world)
	ArenaBuilder.build(world, _headless)
	surface_layer = SurfaceLayer.new()
	surface_layer.name = "Surfaces"
	add_child(surface_layer)
	surface_layer.setup(ArenaLayout.SIZE, ArenaLayout.ORIGIN)
	ArenaLayout.paint_surfaces(surface_layer.grid)
	surface_layer.grid.take_patches()

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	var colors: Array[Color] = [ProcMesh.GOLD, ProcMesh.VIOLET]
	var hero_setups: Array = setup.get("heroes", [])
	for slot in 2:
		if slot < hero_setups.size() and hero_setups[slot] is Dictionary:
			colors[slot] = ProcMesh.player_color(str((hero_setups[slot] as Dictionary).get("color", "gold" if slot == 0 else "violet")))
	presentation = Presentation.new()
	presentation.name = "Presentation"
	add_child(presentation)
	presentation.setup(self, local_slot, colors, camera_rig)

	var heroes_root := Node3D.new()
	heroes_root.name = "Heroes"
	add_child(heroes_root)
	for slot in 2:
		if slot >= hero_setups.size() or not (hero_setups[slot] is Dictionary):
			continue
		var h := Hero.create(slot, hero_setups[slot] as Dictionary, self)
		heroes_root.add_child(h)
		h.global_position = ArenaLayout.HERO_SPAWNS[slot]
		heroes[slot] = h
		var hv := presentation.add_hero(h)
		if slot == local_slot:
			camera_rig.target = hv
			camera_rig.snap_to(h.global_position)
			camera_rig.aim_source = func() -> Vector3: return h.input.aim
			h.input.camera = camera_rig.camera
			if bool(setup.get("bot", false)) or Settings.has_arg("bot"):
				h.input.bot = BotBrain.new(h, self)
	tether = BondTether.new()
	tether.name = "Tether"
	add_child(tether)
	if heroes[0] != null and heroes[1] != null:
		tether.hero_a = presentation.hero_visuals[0]
		tether.hero_b = presentation.hero_visuals[1]
		tether.color_a = colors[0]
		tether.color_b = colors[1]

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(self, local_slot, colors[local_slot])

	if is_host:
		combat = CombatSystem.new()
		combat.name = "Combat"
		entities = EntityManager.new()
		entities.name = "Entities"
		add_child(entities)
		add_child(combat)
		combat.setup(self, entities, surface_layer.grid, hash(str(setup.get("level", 3)) + str(Time.get_ticks_usec())))
		entities.setup(self, combat, ArenaLayout.configure_flow)
		encounter = EncounterController.new()
		encounter.name = "Encounter"
		add_child(encounter)
		encounter.setup(self, entities, combat)
		for h: Variant in heroes:
			if h != null:
				(h as Hero).action_event.connect(combat.on_hero_event)
		_spawn_props()
		_guest_ready = not Net.guest_connected()
	# Two-player sessions start with both heroes held (in rollback state, so both PCs agree) until the
	# guest has loaded; otherwise early guest inputs would be dropped and cause a large correction.
	if heroes[1] != null and not bool(setup.get("solo", false)):
		paused = true
		pause_reason = "loading"
		for h: Variant in heroes:
			(h as Hero).motor.paused = true
		hud.set_pause(true, "Waiting for both of you to load in...")
		if is_host and not Net.guest_connected():
			_drop_deadline = NetworkTime.tick + GameData.rule_ticks(&"guest_drop_pause_s")
	NetworkTime.on_tick.connect(_on_tick)
	if not is_host:
		Net.notify_scene_ready()
	hud.toast("The Drowned Hall · hold %s at the Waystone to begin" % Settings.binding_text(&"interact"), Color(1.0, 0.9, 0.7), 5.0)


func _exit_tree() -> void:
	if NetworkTime.on_tick.is_connected(_on_tick):
		NetworkTime.on_tick.disconnect(_on_tick)
	if Net.handler == self:
		Net.handler = null


func _spawn_props() -> void:
	for p: Vector3 in ArenaLayout.OIL_BARRELS:
		entities.spawn_prop(NetProtocol.KIND_OIL_BARREL, p, NetworkTime.tick)
	for p: Vector3 in ArenaLayout.WATER_BARRELS:
		entities.spawn_prop(NetProtocol.KIND_WATER_BARREL, p, NetworkTime.tick)
	for p: Vector3 in ArenaLayout.DUMMIES:
		entities.spawn_enemy(&"training_dummy", p, NetworkTime.tick)


# --- Ticks --------------------------------------------------------------------------------------

func _on_tick(delta: float, tick: int) -> void:
	if not is_host:
		return
	combat.paused = paused
	if _release_at > 0 and tick >= _release_at:
		_release_at = -1
		_set_paused(false, local_slot, "")
	if not paused:
		entities.tick(tick, delta)
		combat.tick(tick, delta)
		encounter.tick(tick)
	elif _drop_deadline > 0 and tick >= _drop_deadline:
		_drop_deadline = -1
		Net.end_session("Your partner did not return within 2 minutes. Progress up to the last Waystone is saved.")
		return
	_stats_counter += 1
	if _stats_counter >= int(60.0 / GameData.rule(&"stats_send_hz")):
		_stats_counter = 0
		for h: Variant in heroes:
			if h != null and (h as Hero).stats.dirty:
				(h as Hero).stats.dirty = false
				emit_event((h as Hero).stats.encode((h as Hero).slot, tick))
	if Net.guest_connected() and _guest_ready:
		if tick % int(60.0 / GameData.rule(&"enemy_snapshot_hz")) == 0:
			Net.send_crowd(entities.build_snapshot(tick))
		if tick % int(60.0 / GameData.rule(&"surface_update_hz")) == 1:
			Net.send_surface(surface_layer.grid.take_patches())
		Net.send_events(_outgoing)
	else:
		surface_layer.grid.take_patches()
	_outgoing = []


func _process(delta: float) -> void:
	if setup.is_empty():
		return
	if is_host:
		presentation.update_entities(entities.view_states(NetworkTime.tick), delta)
	else:
		var rt := snapshots.render_tick(float(NetworkTime.tick) + NetworkTime.tick_factor)
		presentation.update_entities(snapshots.sample(rt), delta)
		Net.stats.buffer_depth = snapshots.depth(rt)
		Net.stats.buffer_ms = (float(NetworkTime.tick) - rt) * 1000.0 / 60.0
	if Input.is_action_just_pressed(&"pause"):
		Net.send_command({"type": "resume" if paused else "pause"})
	if Input.is_action_just_pressed(&"ping"):
		var h := hero(local_slot)
		if h != null:
			Net.send_command({"type": "ping", "pos": h.input.aim})
	if Input.is_action_just_pressed(&"help"):
		hud.toggle_help()
	if Input.is_action_just_pressed(&"net_overlay"):
		hud.toggle_net()
	if Input.is_action_just_pressed(&"loadout"):
		hud.toggle_loadout()


# --- Events -------------------------------------------------------------------------------------

## Host: announce an outcome to both PCs (locally right away, to the guest with this tick's batch).
func emit_event(ev: Array) -> void:
	if not is_host:
		return
	_outgoing.append(ev)
	_dispatch(ev)


func _dispatch(ev: Array) -> void:
	match int(ev[0]):
		NetProtocol.EV_HERO_STATS:
			if not is_host:
				var h := hero(int(ev[1]))
				if h != null:
					h.stats.apply_encoded(ev)
			return
		NetProtocol.EV_WAVE:
			encounter_view = {"state": int(ev[1]), "wave": int(ev[2]), "count": int(ev[3]), "left": int(ev[4])}
		NetProtocol.EV_BOND:
			bond_meter = float(ev[1])
		NetProtocol.EV_PAUSE:
			paused = bool(ev[1])
			pause_reason = str(ev[3])
			hud.set_pause(paused, _pause_text(ev))
		NetProtocol.EV_LOADOUT:
			var h := hero(int(ev[1]))
			if h != null:
				h.set_loadout(ev[2] as Array, ev[3] as Dictionary)
				hud.toast("%s changed loadout." % h.hero_name, Color(0.8, 0.9, 1.0))
	presentation.handle_event(ev)
	hud.on_event(ev)


func _pause_text(ev: Array) -> String:
	if not bool(ev[1]):
		return ""
	var by := int(ev[2])
	var reason := str(ev[3])
	if reason == "partner_dropped":
		return "Paused: your partner dropped.\nWaiting up to %d s for them to reconnect..." % int(ev[4])
	var who := hero(by).hero_name if hero(by) != null else "Someone"
	return "Paused by %s.\nPress %s when you're ready to continue (both of you)." % [who, Settings.binding_text(&"pause")]


func on_events(batch: Array) -> void:
	for ev: Variant in batch:
		if ev is Array:
			_dispatch(ev as Array)


func on_crowd(bytes: PackedByteArray) -> void:
	var decoded := CrowdCodec.decode(bytes)
	if decoded.is_empty():
		return
	snapshots.push(int(decoded["tick"]), decoded["entities"] as Array, float(NetworkTime.tick))


func on_surface(patches: Array) -> void:
	for p: Variant in patches:
		var entry := p as Array
		surface_layer.grid.apply_patch(int(entry[0]), int(entry[1]), entry[2] as PackedByteArray)


## Guest: authoritative recovery after joining or reconnecting.
func on_full_state(state: Dictionary) -> void:
	surface_layer.grid.apply_full_snapshot(state.get("surface", []) as Array)
	var crowd: PackedByteArray = state.get("crowd", PackedByteArray())
	snapshots.clear()
	on_crowd(crowd)
	for ev: Variant in state.get("events", []):
		_dispatch(ev as Array)
	hud.toast("In sync with the host.", Color(0.7, 1.0, 0.8))


# --- Host: commands and peers -------------------------------------------------------------------

func on_command(slot: int, cmd: Dictionary) -> void:
	if not is_host:
		return
	match str(cmd.get("type", "")):
		"pause":
			if not paused:
				_set_paused(true, slot, "player")
		"resume":
			if paused and pause_reason != "partner_dropped" and pause_reason != "loading":
				_pause_ready[slot] = true
				var need_both := heroes[1] != null and Net.guest_connected()
				if not need_both or (_pause_ready[0] and _pause_ready[1]):
					_set_paused(false, slot, "")
				else:
					emit_event([NetProtocol.EV_REJECTED, slot, "Ready. Waiting for your partner to resume too."])
		"ping":
			var p: Vector3 = cmd.get("pos", Vector3.ZERO)
			emit_event([NetProtocol.EV_PING, slot, p.x, p.y, p.z])
		"loadout":
			_change_loadout(slot, cmd)


func _set_paused(value: bool, by: int, reason: String) -> void:
	paused = value
	pause_reason = reason
	_pause_ready = [false, false]
	var resume_tick := NetworkTime.tick + 45
	for h: Variant in heroes:
		if h != null:
			(h as Hero).queue_command({"type": &"paused", "value": value})
			if not value:
				(h as Hero).queue_command({"type": &"hold_until", "tick": resume_tick})
	var seconds_left := maxi(0, (_drop_deadline - NetworkTime.tick) / 60) if _drop_deadline > 0 else 0
	emit_event([NetProtocol.EV_PAUSE, value, by, reason, seconds_left])


func _change_loadout(slot: int, cmd: Dictionary) -> void:
	var h := hero(slot)
	var state := int(encounter_view.get("state", 0))
	if h == null or (state != NetProtocol.WAVE_PREP and state != NetProtocol.WAVE_BREAK):
		emit_event([NetProtocol.EV_REJECTED, slot, "Loadouts change only at the Waystone between waves."])
		return
	var level := int(setup.get("level", 3))
	var abilities: Array = []
	for id: Variant in cmd.get("abilities", []):
		var def := GameData.ability(StringName(str(id)))
		if def == null or def.class_id != h.class_def.id or def.unlock_level > level or abilities.has(String(def.id)):
			emit_event([NetProtocol.EV_REJECTED, slot, "That loadout isn't valid."])
			return
		abilities.append(String(def.id))
	if abilities.size() != 4:
		emit_event([NetProtocol.EV_REJECTED, slot, "Choose four different abilities."])
		return
	var library: Dictionary = _campaign.get("rune_library", setup.get("rune_library", {}))
	var runes: Dictionary = {}
	for ab: Variant in (cmd.get("runes", {}) as Dictionary).keys():
		var entry: Dictionary = (cmd["runes"] as Dictionary)[ab]
		var r := GameData.rune(StringName(str(entry.get("form", ""))))
		var def := GameData.ability(StringName(str(ab)))
		if r == null or def == null or not library.has(String(r.id)) or not r.fits(def) or not abilities.has(String(def.id)):
			emit_event([NetProtocol.EV_REJECTED, slot, "A rune doesn't fit that ability."])
			return
		runes[String(def.id)] = {"form": String(r.id)}
	_txn.execute(str(cmd.get("txn", "")), func() -> bool:
		h.set_loadout(abilities, runes)
		emit_event([NetProtocol.EV_LOADOUT, slot, abilities, runes])
		var key := str(h.setup.get("hero_key", ""))
		var heroes_data: Dictionary = _campaign.get("heroes", {})
		if heroes_data.has(key):
			var loadouts: Dictionary = (heroes_data[key] as Dictionary).get("loadouts", {})
			loadouts[String(h.class_def.id)] = {"abilities": abilities, "runes": runes}
		commit_checkpoint("loadout")
		return true)


func on_guest_ready(peer: int) -> void:
	_guest_ready = true
	var h := hero(1)
	if h != null:
		h.input.set_multiplayer_authority(peer)
		h.rollback.process_authority()
		h.setup["peer_id"] = peer
	var events: Array = [
		[NetProtocol.EV_WAVE, encounter_view["state"], encounter_view["wave"], encounter_view["count"], encounter_view["left"]],
		[NetProtocol.EV_BOND, bond_meter, -1, ""],
	]
	for hh: Variant in heroes:
		if hh != null:
			events.append((hh as Hero).stats.encode((hh as Hero).slot, NetworkTime.tick))
	if paused:
		events.append([NetProtocol.EV_PAUSE, true, local_slot, pause_reason, 0])
	Net.send_full_state({"surface": surface_layer.grid.full_snapshot(), "crowd": entities.build_snapshot(NetworkTime.tick), "events": events})
	if paused and pause_reason == "loading":
		_drop_deadline = -1
		_release_at = NetworkTime.tick + 30
	elif paused and pause_reason == "partner_dropped":
		_drop_deadline = -1
		_set_paused(true, 1, "player")
		hud.toast("Your partner is back. Both press %s to continue." % Settings.binding_text(&"pause"), Color(0.7, 1.0, 0.8), 5.0)


func on_guest_dropped() -> void:
	if not is_host:
		return
	_guest_ready = false
	_drop_deadline = NetworkTime.tick + GameData.rule_ticks(&"guest_drop_pause_s")
	_set_paused(true, 1, "partner_dropped")


# --- Services for heroes, bots, systems and HUD ---------------------------------------------------

func hero(slot: int) -> Hero:
	if slot < 0 or slot >= heroes.size():
		return null
	return heroes[slot] as Hero


func partner_of(slot: int) -> Hero:
	return hero(1 - slot)


func partner_connected() -> bool:
	if heroes[1] == null:
		return true
	return Net.guest_connected() if is_host else Net.is_online()


func camera() -> Camera3D:
	return camera_rig.camera if camera_rig != null else null


func targetable_heroes() -> Array:
	var out: Array = []
	for h: Variant in heroes:
		if h != null and (h as Hero).stats.is_alive():
			out.append(h)
	return out


func view_tick() -> int:
	if is_host:
		return NetworkTime.tick
	return int(snapshots.render_tick(float(NetworkTime.tick)))


func enemy_positions() -> Array[Vector3]:
	return presentation.enemy_positions()


func nearest_enemy_position(from: Vector3) -> Variant:
	var best: Variant = null
	var best_d := INF
	for p: Vector3 in presentation.enemy_positions():
		var d := from.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


## Nearest visible enemy carrying a primer owned by the given player (bots use it to combo).
func primed_enemy_position(owner_slot: int, from: Vector3, max_dist: float) -> Variant:
	var best: Variant = null
	var best_d := max_dist * max_dist
	for v: EnemyVisual in presentation.enemies.values():
		if v.state == null or v.state.anim == GameTypes.Anim.DEAD or v.kind >= NetProtocol.KIND_OIL_BARREL:
			continue
		var p := v.state.primer0 if owner_slot == 0 else v.state.primer1
		if p == 0:
			continue
		var d := from.distance_squared_to(v.global_position)
		if d < best_d:
			best_d = d
			best = v.global_position
	return best


func telegraph_threatens(pos: Vector3) -> bool:
	return presentation.telegraph_threatens(pos)


func waystone_position() -> Vector3:
	return ArenaLayout.WAYSTONE


func encounter_state() -> int:
	return int(encounter_view.get("state", 0))


func hero_surface_query(pos: Vector3) -> Dictionary:
	return surface_layer.hero_query(pos)


func surface_material_at(pos: Vector3) -> int:
	return surface_layer.material_at(pos)


func reset_surfaces() -> void:
	var grid := surface_layer.grid
	grid.setup(grid.width, grid.height, grid.cell_size, grid.origin, grid.chunk_cells)
	grid.configure_from_data()
	ArenaLayout.paint_surfaces(grid)
	for e: Enemy in entities.entities.values():
		if e.is_prop:
			entities.despawn(e)
	for p: Vector3 in ArenaLayout.OIL_BARRELS:
		entities.spawn_prop(NetProtocol.KIND_OIL_BARREL, p, NetworkTime.tick)
	for p: Vector3 in ArenaLayout.WATER_BARRELS:
		entities.spawn_prop(NetProtocol.KIND_WATER_BARREL, p, NetworkTime.tick)
	if Net.guest_connected():
		Net.send_full_state({"surface": grid.full_snapshot(), "crowd": entities.build_snapshot(NetworkTime.tick), "events": []})


func on_enemy_killed(e: Enemy, _slot: int) -> void:
	if encounter != null:
		encounter.on_enemy_killed(e)


func toast_all(text: String) -> void:
	emit_event([NetProtocol.EV_JOURNAL, text])


func campaign_data() -> Dictionary:
	return _campaign


func commit_checkpoint(reason: String) -> void:
	if not is_host or bool(setup.get("solo", false)):
		return
	var cp := Net.commit_campaign(_campaign, reason)
	if cp != null:
		emit_event([NetProtocol.EV_SAVED, cp.revision, cp.short_hash()])


## Chronicle: a shared memory, recorded once per session for each kind of first.
func chronicle_first(key: String, text: String) -> void:
	if _firsts.has(key):
		return
	_firsts[key] = true
	var bond: Dictionary = _campaign.get("bond", {})
	var firsts: Array = bond.get("firsts", [])
	if not firsts.has(key):
		firsts.append(key)
		bond["firsts"] = firsts
		_campaign["bond"] = bond
	chronicle_add(key, text)


func chronicle_add(kind: String, text: String) -> void:
	if not is_host:
		return
	CampaignState.add_journal(_campaign, kind, text)
	emit_event([NetProtocol.EV_JOURNAL, text])


func net_overlay_text() -> String:
	var s := Net.stats
	var role := "HOST" if is_host else "GUEST"
	var lines := PackedStringArray([
		"%s  peer %d  tick %d" % [role, multiplayer.get_unique_id(), NetworkTime.tick],
		"RTT %.0f ms  jitter %.0f ms  loss %.1f%%" % [s.rtt_ms, s.jitter_ms, s.loss_percent],
		"up %.1f KB/s  down %.1f KB/s" % [s.sent_kbps, s.recv_kbps],
	])
	if is_host:
		lines.append("entities %d  tokens %d (reclaimed %d)  projectiles %d" % [entities.entities.size(), entities.director.token_count(), entities.tokens_reclaimed, combat.projectiles.size()])
		lines.append("surface active cells %d" % surface_layer.grid.active_count())
	else:
		lines.append("snapshot buffer %d (%.0f ms)" % [s.buffer_depth, s.buffer_ms])
		lines.append("reconciliations %d  last %.3f m  p95 %.3f m" % [s.reconciliations, s.last_correction, s.correction_percentile(0.95)])
	lines.append("fps %d" % Engine.get_frames_per_second())
	return "\n".join(lines)


func soak_report() -> String:
	var seconds := (Time.get_ticks_msec() - _started_msec) / 1000.0
	if is_host:
		return "host %.0fs: %s, waves cleared %d, victories %d, tokens held %d, tokens reclaimed %d" % [
			seconds, JSON.stringify(combat.counters), int((_campaign.get("expedition", {}) as Dictionary).get("waves_cleared", 0)),
			encounter.victories, entities.director.token_count(), entities.tokens_reclaimed]
	return "guest %.0fs: snapshots buffered %d, reconciliations %d, p95 correction %.3f m" % [
		seconds, snapshots.depth(), Net.stats.reconciliations, Net.stats.correction_percentile(0.95)]
