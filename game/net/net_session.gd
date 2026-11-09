extends Node
## Autoload "Net": host and join over ENet (Tailscale address or LAN), build and content checks,
## lobby readiness, campaign copy resolution by ancestry, session start, checkpoint mirroring,
## dropped-guest pause and reconnect, and the RPC gateway for in-session traffic.
## The host decides every gameplay outcome; this node only moves plain data.

signal status_changed(text: String)
signal lobby_changed(state: Dictionary)
signal session_ended(reason: String)
signal checkpoint_mirrored(revision: int)

enum Role { NONE, HOST, GUEST }

const ARENA_SCENE := "res://game/scenes/arena/arena.tscn"
const LOBBY_SCENE := "res://game/scenes/lobby/lobby.tscn"
const BOOT_SCENE := "res://game/scenes/boot/boot.tscn"
const CLASS_IDS: Array[StringName] = [&"vanguard", &"riftweaver"]

var role: int = Role.NONE
var local_slot: int = 0
var guest_peer: int = 0
var in_session: bool = false
var session_setup: Dictionary = {}
var lobby: Dictionary = {}
var handler: Node = null          ## the running arena; receives in-session messages
var store: CampaignStore
var campaign: CampaignStore.Checkpoint
var stats := NetStats.new()
var last_status: String = ""
var _guest_profile_in_session: String = ""
var _quit_at_msec: int = -1
var _pending_conflict: Array = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var quit_after: Variant = Settings.arg("quit-after")
	if quit_after != null:
		_quit_at_msec = Time.get_ticks_msec() + int(float(str(quit_after)) * 1000.0)
	var shot: Variant = Settings.arg("screenshot")
	if shot != null:
		_shot_path = str(shot)
		_shot_at_msec = Time.get_ticks_msec() + int(float(str(Settings.arg("screenshot-after", "8"))) * 1000.0)


var _shot_path: String = ""
var _shot_at_msec: int = -1


func _process(delta: float) -> void:
	var remote := guest_peer if role == Role.HOST else (1 if role == Role.GUEST else 0)
	stats.poll(multiplayer, remote, delta)
	if _shot_at_msec > 0 and Time.get_ticks_msec() >= _shot_at_msec:
		_shot_at_msec = -1
		var image := get_viewport().get_texture().get_image()
		if image != null:
			var path := ProjectSettings.globalize_path(_shot_path) if _shot_path.begins_with("res://") or _shot_path.begins_with("user://") else _shot_path
			print("[shot] saved %s (%s)" % [path, error_string(image.save_png(path))])
	if _quit_at_msec > 0 and Time.get_ticks_msec() >= _quit_at_msec:
		_quit_at_msec = -1
		print("[soak] %s %s" % ["host" if role == Role.HOST else "guest", stats.summary()])
		if handler != null and handler.has_method("soak_report"):
			print("[soak] ", handler.call("soak_report"))
		leave("quit-after elapsed")
		get_tree().quit(0)


func is_host() -> bool:
	return role == Role.HOST


func is_guest() -> bool:
	return role == Role.GUEST


func is_online() -> bool:
	return role != Role.NONE


func guest_connected() -> bool:
	return guest_peer != 0


func _set_status(text: String) -> void:
	last_status = text
	print("[net] ", text)
	status_changed.emit(text)


# --- Host and join ------------------------------------------------------------------

func host_game(port: int, solo: bool = false) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 2)
	if err != OK:
		_set_status("Could not host on port %d (%s)." % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	local_slot = GameTypes.SLOT_HOST
	store = CampaignStore.new(Settings.saves_dir())
	campaign = _load_latest_campaign()
	lobby = {"players": [_local_player_entry(GameTypes.SLOT_HOST), {}], "solo": solo, "conflict": [],
		"campaign": _campaign_summary(campaign)}
	_set_status("Hosting on port %d. Share this PC's Tailscale or LAN address with your partner." % port)
	_broadcast_lobby()
	return OK


func join_game(address: String, port: int) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_set_status("Could not start connecting to %s:%d (%s)." % [address, port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.GUEST
	store = CampaignStore.new(Settings.saves_dir())
	campaign = _load_latest_campaign()
	_set_status("Connecting to %s:%d ..." % [address, port])
	return OK


func leave(reason: String = "") -> void:
	var was_online := role != Role.NONE
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.NONE
	guest_peer = 0
	in_session = false
	handler = null
	lobby = {}
	stats.reset()
	if was_online and reason != "":
		_set_status(reason)


func _local_player_entry(slot: int) -> Dictionary:
	var class_arg: Variant = Settings.arg("class")
	var default_class: StringName = CLASS_IDS[slot % CLASS_IDS.size()]
	var class_id := StringName(str(class_arg)) if class_arg != null and CLASS_IDS.has(StringName(str(class_arg))) else StringName(str(Settings.profile.get("last_class", default_class)))
	if not CLASS_IDS.has(class_id):
		class_id = default_class
	return {
		"name": str(Settings.profile.get("name", "Hero")),
		"profile_id": str(Settings.profile.get("profile_id", "")),
		"class_id": String(class_id),
		"color": str(Settings.profile.get("color", "gold" if slot == 0 else "violet")),
		"ready": Settings.has_arg("auto-ready") or Settings.has_arg("bot"),
		"connected": true,
		"assists": Settings.gameplay_assists(),
	}


# --- Handshake ----------------------------------------------------------------------

func _on_connected_to_server() -> void:
	_set_status("Connected. Checking build and content...")
	var hello := {
		"protocol": NetProtocol.PROTOCOL_VERSION,
		"build": GameData.build_version(),
		"content": GameData.content_hash(),
		"player": _local_player_entry(GameTypes.SLOT_GUEST),
		"campaign": _campaign_head(campaign),
	}
	_c_hello.rpc_id(1, hello)


func _on_connection_failed() -> void:
	leave()
	_set_status("Connection failed. Check the address, that the host is running, and Tailscale.")


func _on_server_disconnected() -> void:
	var was_in_session := in_session
	leave()
	var reason := "The host disconnected. Either PC can resume from the latest shared checkpoint." if was_in_session else "Disconnected from the host."
	_set_status(reason)
	session_ended.emit(reason)
	get_tree().change_scene_to_file(BOOT_SCENE)


func _on_peer_connected(id: int) -> void:
	if role == Role.HOST:
		var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if enet != null and enet.get_peer(id) != null:
			enet.get_peer(id).set_timeout(32, 2000, 6000)


func _on_peer_disconnected(id: int) -> void:
	if role != Role.HOST or id != guest_peer:
		return
	guest_peer = 0
	var players: Array = lobby.get("players", [{}, {}])
	if in_session:
		if players.size() > 1 and not (players[1] as Dictionary).is_empty():
			(players[1] as Dictionary)["connected"] = false
		_set_status("Your partner dropped. The encounter is paused for up to 2 minutes while they reconnect.")
		if handler != null and handler.has_method("on_guest_dropped"):
			handler.call("on_guest_dropped")
	else:
		players[1] = {}
		_set_status("Your partner left the lobby.")
	_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func _c_hello(info: Dictionary) -> void:
	if role != Role.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	var reason := ""
	if int(info.get("protocol", -1)) != NetProtocol.PROTOCOL_VERSION:
		reason = "Different network protocol."
	elif str(info.get("build", "")) != GameData.build_version():
		reason = "Different build (host %s, you %s). Both PCs must run the same build." % [GameData.build_version(), info.get("build", "?")]
	elif str(info.get("content", "")) != GameData.content_hash():
		reason = "Different content manifest. Both PCs must run the same build and data."
	elif bool(lobby.get("solo", false)):
		reason = "The host is in solo practice."
	elif guest_peer != 0 and guest_peer != sender:
		reason = "This game already has two players."
	var player: Dictionary = info.get("player", {})
	if reason == "" and in_session and str(player.get("profile_id", "")) != _guest_profile_in_session:
		reason = "A session is running with a different partner."
	if reason == "" and str(player.get("profile_id", "")) == str(Settings.profile.get("profile_id", "")):
		reason = "Both PCs use the same profile. Start one with --profile=<name> when testing on one PC."
	if reason != "":
		_c_reject.rpc_id(sender, reason)
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(sender))
		_set_status("Refused a connection: " + reason)
		return
	guest_peer = sender
	player["connected"] = true
	var players: Array = lobby["players"]
	if in_session and not (players[1] as Dictionary).is_empty():
		(players[1] as Dictionary)["connected"] = true
	else:
		players[1] = player
	_resolve_campaign_copies(info.get("campaign", {}) as Dictionary)
	_c_welcome.rpc_id(sender, {"slot": GameTypes.SLOT_GUEST, "host_name": Settings.profile.get("name", "Host"), "in_session": in_session})
	if in_session:
		_set_status("Your partner is back. Restoring the encounter...")
		var heroes: Array = session_setup["heroes"]
		if heroes.size() > 1 and heroes[1] is Dictionary:
			(heroes[1] as Dictionary)["peer_id"] = sender
		_c_start.rpc_id(sender, session_setup)
		if campaign != null:
			mirror_checkpoint(campaign)
	else:
		_set_status("%s joined." % player.get("name", "Partner"))
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func _c_reject(reason: String) -> void:
	_set_status("The host refused the connection: " + reason)
	leave()


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func _c_welcome(info: Dictionary) -> void:
	local_slot = int(info.get("slot", 1))
	_set_status("Joined %s's game." % info.get("host_name", "the host"))
	if not bool(info.get("in_session", false)):
		get_tree().change_scene_to_file(LOBBY_SCENE)


# --- Lobby --------------------------------------------------------------------------

func _broadcast_lobby() -> void:
	if role != Role.HOST:
		return
	lobby["campaign"] = _campaign_summary(campaign)
	lobby_changed.emit(lobby)
	if guest_peer != 0:
		_c_lobby.rpc_id(guest_peer, lobby)


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func _c_lobby(state: Dictionary) -> void:
	lobby = state
	lobby_changed.emit(lobby)


## Change this player's lobby entry (class, colour, ready, assists).
func request_lobby_change(change: Dictionary) -> void:
	if role == Role.HOST:
		_apply_lobby_change(GameTypes.SLOT_HOST, change)
	elif role == Role.GUEST:
		_c_lobby_request.rpc_id(1, change)


@rpc("any_peer", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func _c_lobby_request(change: Dictionary) -> void:
	if role != Role.HOST or multiplayer.get_remote_sender_id() != guest_peer:
		return
	_apply_lobby_change(GameTypes.SLOT_GUEST, change)


func _apply_lobby_change(slot: int, change: Dictionary) -> void:
	var players: Array = lobby.get("players", [{}, {}])
	var entry: Dictionary = players[slot]
	if entry.is_empty():
		return
	for key: String in ["class_id", "color", "ready", "assists", "name"]:
		if change.has(key):
			if key == "class_id" and not CLASS_IDS.has(StringName(str(change[key]))):
				continue
			entry[key] = change[key]
	if change.has("choose_branch"):
		_choose_branch(int(change["choose_branch"]))
	if slot == GameTypes.SLOT_HOST and change.has("class_id"):
		Settings.profile["last_class"] = str(change["class_id"])
		Settings.save_profile()
	_broadcast_lobby()
	_maybe_auto_start()


func both_ready() -> bool:
	var players: Array = lobby.get("players", [{}, {}])
	if bool(lobby.get("solo", false)):
		return true
	return not (players[1] as Dictionary).is_empty() and bool((players[0] as Dictionary).get("ready", false)) \
		and bool((players[1] as Dictionary).get("ready", false)) and guest_peer != 0 \
		and (lobby.get("conflict", []) as Array).is_empty()


func _maybe_auto_start() -> void:
	if role == Role.HOST and (Settings.has_arg("bot") or Settings.has_arg("auto-start")) and both_ready() and not in_session:
		start_session.call_deferred()


# --- Campaign copies ----------------------------------------------------------------

func _load_latest_campaign() -> CampaignStore.Checkpoint:
	var best: CampaignStore.Checkpoint = null
	for id: String in store.list_campaigns():
		var cp := store.load_latest(id)
		if cp == null:
			continue
		if best == null or cp.created_unix > best.created_unix:
			best = cp  # picking which local campaign to open is a convenience, never a merge decision
	return best


static func _campaign_head(cp: CampaignStore.Checkpoint) -> Dictionary:
	if cp == null:
		return {}
	var tail := cp.lineage.slice(maxi(0, cp.lineage.size() - 256))
	return {"campaign_id": cp.campaign_id, "revision": cp.revision, "hash": cp.content_hash, "lineage_tail": Array(tail)}


static func _campaign_summary(cp: CampaignStore.Checkpoint) -> Dictionary:
	if cp == null:
		return {"exists": false}
	return {"exists": true, "campaign_id": cp.campaign_id, "revision": cp.revision, "hash": cp.short_hash(),
		"summary": CampaignState.summary(cp.data), "name": str(cp.data.get("campaign_name", ""))}


## Ancestry decides which copy is newer; divergent copies are shown side by side for the two of you.
func _resolve_campaign_copies(guest_head: Dictionary) -> void:
	lobby["conflict"] = []
	if guest_head.is_empty():
		return
	if campaign == null:
		_c_request_checkpoint.rpc_id(guest_peer)
		return
	if str(guest_head.get("campaign_id", "")) != campaign.campaign_id:
		return
	var guest_hash := str(guest_head.get("hash", ""))
	if guest_hash == campaign.content_hash:
		return
	if campaign.lineage.has(guest_hash):
		mirror_checkpoint(campaign)
		return
	var tail: Array = guest_head.get("lineage_tail", [])
	if tail.has(campaign.content_hash):
		_c_request_checkpoint.rpc_id(guest_peer)
		return
	_c_request_checkpoint.rpc_id(guest_peer)
	_pending_conflict = [_campaign_summary(campaign)]


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_BULK)
func _c_request_checkpoint() -> void:
	if campaign != null:
		_c_checkpoint_offer.rpc_id(1, CampaignStore.serialize(campaign))


@rpc("any_peer", "call_remote", "reliable", NetProtocol.CH_BULK)
func _c_checkpoint_offer(text: String) -> void:
	if role != Role.HOST or multiplayer.get_remote_sender_id() != guest_peer:
		return
	var offered := CampaignStore.parse(text)
	if offered == null:
		_set_status("Your partner's save failed verification and was ignored.")
		return
	if campaign == null:
		_adopt(offered, "Continuing your partner's campaign (they hosted last time).")
		return
	match CampaignStore.relation(offered, campaign):
		CampaignStore.Relation.A_DESCENDS_FROM_B:
			_adopt(offered, "Your partner's copy is newer; continuing from it.")
		CampaignStore.Relation.B_DESCENDS_FROM_A, CampaignStore.Relation.SAME:
			mirror_checkpoint(campaign)
		CampaignStore.Relation.DIVERGENT:
			store.store_branch(offered)
			lobby["conflict"] = [_campaign_summary(campaign), _campaign_summary(offered)]
			_set_status("Two different versions of the campaign exist. Pick one together in the lobby.")
		_:
			pass
	_broadcast_lobby()


func _adopt(cp: CampaignStore.Checkpoint, message: String) -> void:
	if campaign != null and CampaignStore.relation(cp, campaign) == CampaignStore.Relation.DIVERGENT:
		store.store_branch(campaign)
	store.write(cp)
	campaign = cp
	_set_status(message)
	_broadcast_lobby()


func _choose_branch(index: int) -> void:
	var conflict: Array = lobby.get("conflict", [])
	if conflict.size() < 2 or index < 0 or index > 1:
		return
	if index == 1:
		var chosen_hash := str((conflict[1] as Dictionary).get("hash", ""))
		for b: CampaignStore.Checkpoint in store.list_branches(campaign.campaign_id):
			if b.short_hash() == chosen_hash:
				store.store_branch(campaign)
				store.write(b)
				campaign = b
	lobby["conflict"] = []
	mirror_checkpoint(campaign)
	_set_status("Continuing from the chosen copy; the other one is kept as a branch.")


## Mirror a completed checkpoint so either PC can host the next session.
func mirror_checkpoint(cp: CampaignStore.Checkpoint) -> void:
	if role == Role.HOST and guest_peer != 0 and cp != null:
		var text := CampaignStore.serialize(cp)
		stats.count_sent("checkpoint", text.length())
		_c_checkpoint.rpc_id(guest_peer, text)


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_BULK)
func _c_checkpoint(text: String) -> void:
	var cp := CampaignStore.parse(text)
	if cp == null:
		push_warning("Mirrored checkpoint failed verification")
		return
	var local := store.load_latest(cp.campaign_id) if store != null else null
	if local == null or CampaignStore.relation(cp, local) == CampaignStore.Relation.A_DESCENDS_FROM_B:
		store.write(cp)
	elif CampaignStore.relation(cp, local) == CampaignStore.Relation.DIVERGENT:
		store.store_branch(cp)
	campaign = cp
	checkpoint_mirrored.emit(cp.revision)


## Host-only: commit a new checkpoint (after cleared rooms, rewards and camp changes) and mirror it.
func commit_campaign(data: Dictionary, reason: String) -> CampaignStore.Checkpoint:
	if role != Role.HOST or bool(session_setup.get("solo", false)):
		return null
	return _write_checkpoint(data, reason)


func _write_checkpoint(data: Dictionary, reason: String) -> CampaignStore.Checkpoint:
	var cp := CampaignStore.make_checkpoint(campaign.campaign_id if campaign != null else _new_campaign_id(), data, campaign, "%s:%s" % [Settings.profile.get("profile_id", ""), reason])
	var err := store.write(cp)
	if err != OK:
		push_error("Checkpoint write failed: %s" % error_string(err))
		return null
	campaign = cp
	mirror_checkpoint(cp)
	return cp


func _new_campaign_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


# --- Session start ------------------------------------------------------------------

func start_session() -> void:
	if role != Role.HOST or in_session or not both_ready():
		return
	var solo := bool(lobby.get("solo", false))
	var data: Dictionary = campaign.data.duplicate(true) if campaign != null else CampaignState.new_campaign("The Last Hearth", int(GameData.rule(&"arena_level")))
	var players: Array = lobby["players"]
	var heroes: Array = []
	for slot in 2:
		var p: Dictionary = players[slot]
		if p.is_empty() or (slot == 1 and solo):
			heroes.append(null)
			continue
		var key := CampaignState.bind_profile(data, str(p["profile_id"]), str(p["name"]), StringName(str(p["class_id"])), str(p["color"]))
		var hero_record: Dictionary = (data["heroes"] as Dictionary).get(key, {})
		heroes.append({
			"slot": slot,
			"hero_key": key,
			"name": str(p["name"]),
			"class_id": str(p["class_id"]),
			"color": _resolved_color(players, slot),
			"attributes": hero_record.get("attributes", {}),
			"loadout": CampaignState.loadout_of(data, key),
			"assists": p.get("assists", {}),
			"peer_id": 1 if slot == 0 else guest_peer,
			"profile_id": str(p["profile_id"]),
		})
	if not solo:
		_write_checkpoint(data, "session_start")
	session_setup = {
		"solo": solo,
		"encounter": "arena_m1",
		"level": int(data.get("level", 3)),
		"heroes": heroes,
		"campaign": data,
		"rune_library": data.get("rune_library", {}),
		"bot": Settings.has_arg("bot"),
	}
	_guest_profile_in_session = str((players[1] as Dictionary).get("profile_id", "")) if not solo else ""
	in_session = true
	if guest_peer != 0:
		_c_start.rpc_id(guest_peer, session_setup)
	get_tree().change_scene_to_file(ARENA_SCENE)


static func _resolved_color(players: Array, slot: int) -> String:
	var mine := str((players[slot] as Dictionary).get("color", "gold"))
	if slot == 1 and not (players[0] as Dictionary).is_empty() and str((players[0] as Dictionary).get("color", "gold")) == mine:
		return "violet" if mine == "gold" else "gold"
	return mine


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func _c_start(setup: Dictionary) -> void:
	session_setup = setup
	in_session = true
	get_tree().change_scene_to_file(ARENA_SCENE)


## Called by the arena once its scene is built on this PC.
func notify_scene_ready() -> void:
	if role == Role.GUEST:
		_c_scene_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func _c_scene_ready() -> void:
	if role == Role.HOST and multiplayer.get_remote_sender_id() == guest_peer and handler != null:
		handler.call("on_guest_ready", guest_peer)


func end_session(reason: String) -> void:
	in_session = false
	handler = null
	if role == Role.HOST and guest_peer != 0:
		_c_end.rpc_id(guest_peer, reason)
	if role != Role.NONE:
		get_tree().change_scene_to_file(LOBBY_SCENE)


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func _c_end(reason: String) -> void:
	in_session = false
	handler = null
	_set_status(reason)
	get_tree().change_scene_to_file(LOBBY_SCENE)


# --- In-session gateway --------------------------------------------------------------

func send_crowd(bytes: PackedByteArray) -> void:
	if role == Role.HOST and guest_peer != 0:
		stats.count_sent("snapshot", bytes.size())
		_s_crowd.rpc_id(guest_peer, bytes)


func send_events(batch: Array) -> void:
	if role == Role.HOST and guest_peer != 0 and not batch.is_empty():
		stats.count_sent("events", var_to_bytes(batch).size())
		_s_events.rpc_id(guest_peer, batch)


func send_surface(patches: Array) -> void:
	if role == Role.HOST and guest_peer != 0 and not patches.is_empty():
		stats.count_sent("surface", var_to_bytes(patches).size())
		_s_surface.rpc_id(guest_peer, patches)


func send_full_state(state: Dictionary) -> void:
	if role == Role.HOST and guest_peer != 0:
		_s_full_state.rpc_id(guest_peer, state)


## Requests from either player: pause, resume, ping, bond action, loadout and rune changes, start.
func send_command(cmd: Dictionary) -> void:
	if role == Role.HOST:
		if handler != null:
			handler.call("on_command", GameTypes.SLOT_HOST, cmd)
	elif role == Role.GUEST:
		_s_command.rpc_id(1, cmd)


@rpc("authority", "call_remote", "unreliable_ordered", NetProtocol.CH_SNAPSHOT)
func _s_crowd(bytes: PackedByteArray) -> void:
	if handler != null:
		handler.call("on_crowd", bytes)


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_EVENTS)
func _s_events(batch: Array) -> void:
	if handler != null:
		handler.call("on_events", batch)


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_SURFACE)
func _s_surface(patches: Array) -> void:
	if handler != null:
		handler.call("on_surface", patches)


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_BULK)
func _s_full_state(state: Dictionary) -> void:
	if handler != null:
		handler.call("on_full_state", state)


@rpc("any_peer", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func _s_command(cmd: Dictionary) -> void:
	if role == Role.HOST and multiplayer.get_remote_sender_id() == guest_peer and handler != null:
		handler.call("on_command", GameTypes.SLOT_GUEST, cmd)
