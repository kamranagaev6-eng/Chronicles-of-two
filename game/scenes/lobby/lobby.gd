extends Control
## Lobby: both players pick a class (either of you can play any class; both may pick the same one),
## ready up, and see the build/content check, the shared campaign and any save conflict to resolve.

var _cards: Array[VBoxContainer] = []
var _status: Label
var _campaign: Label
var _conflict_box: VBoxContainer
var _start: Button
var _addresses: Label


func _ready() -> void:
	UiKit.background(self)
	var col := UiKit.centered_column(self, 760)
	UiKit.label(col, "Lobby", 36, UiKit.ACCENT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_addresses = UiKit.label(col, "", 15, UiKit.MUTED)
	_addresses.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Net.is_host():
		var addrs := UiKit.join_addresses()
		_addresses.text = "Your partner joins at: %s · port %d" % [", ".join(addrs) if not addrs.is_empty() else "this PC's address", int(Settings.option("port", NetProtocol.DEFAULT_PORT))]
	var row := UiKit.row(col)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 2:
		var p := UiKit.panel(row)
		p.custom_minimum_size = Vector2(360, 200)
		var v := VBoxContainer.new()
		p.add_child(v)
		_cards.append(v)
	_campaign = UiKit.label(col, "", 15, UiKit.INK)
	_conflict_box = VBoxContainer.new()
	col.add_child(_conflict_box)
	var buttons := UiKit.row(col)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_start = UiKit.button(buttons, "Start the arena", func() -> void: Net.start_session())
	_start.visible = Net.is_host()
	UiKit.button(buttons, "Leave", func() -> void:
		Net.leave("You left.")
		get_tree().change_scene_to_file(Net.BOOT_SCENE))
	_status = UiKit.label(col, Net.last_status, 15, UiKit.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Net.status_changed.connect(_on_status)
	Net.lobby_changed.connect(_refresh)
	_refresh(Net.lobby)
	if Net.is_guest() and (Settings.has_arg("auto-ready") or Settings.has_arg("bot")):
		Net.request_lobby_change({"ready": true})
	Net._maybe_auto_start()


func _on_status(t: String) -> void:
	if is_instance_valid(_status):
		_status.text = t


func _refresh(state: Dictionary) -> void:
	if not is_inside_tree():
		return
	var players: Array = state.get("players", [{}, {}])
	for i in 2:
		var v := _cards[i]
		for c: Node in v.get_children():
			c.queue_free()
		var p: Dictionary = players[i] if i < players.size() else {}
		var mine := i == Net.local_slot
		if p.is_empty():
			UiKit.label(v, "Waiting for your partner..." if i == 1 else "-", 18, UiKit.MUTED)
			continue
		var color := ProcMesh.player_color(str(p.get("color", "gold")))
		UiKit.label(v, "%s%s" % [p.get("name", "?"), " (you)" if mine else ""], 22, color)
		UiKit.label(v, "Host" if i == 0 else "Guest", 13, UiKit.MUTED)
		if mine:
			var cls := OptionButton.new()
			var ids: Array[StringName] = Net.CLASS_IDS
			for k in ids.size():
				var def := GameData.class_def(ids[k])
				cls.add_item("%s, %s" % [def.display_name, def.epithet])
				if StringName(str(p.get("class_id", ""))) == ids[k]:
					cls.select(k)
			cls.item_selected.connect(func(k: int) -> void: Net.request_lobby_change({"class_id": String(ids[k])}))
			v.add_child(cls)
			var ready := CheckBox.new()
			ready.text = "Ready"
			ready.button_pressed = bool(p.get("ready", false))
			ready.toggled.connect(func(on: bool) -> void: Net.request_lobby_change({"ready": on, "assists": Settings.gameplay_assists()}))
			v.add_child(ready)
		else:
			var def := GameData.class_def(StringName(str(p.get("class_id", "vanguard"))))
			UiKit.label(v, def.display_name if def != null else "?", 17)
			UiKit.label(v, "Ready" if bool(p.get("ready", false)) else "Not ready", 15, Color(0.6, 1.0, 0.6) if bool(p.get("ready", false)) else UiKit.MUTED)
		var def2 := GameData.class_def(StringName(str(p.get("class_id", "vanguard"))))
		if def2 != null:
			UiKit.label(v, "%s: %s" % [def2.signature_name, def2.signature_text], 12, UiKit.MUTED)
		if not bool(p.get("connected", true)):
			UiKit.label(v, "Reconnecting...", 14, Color(1.0, 0.6, 0.4))
	var camp: Dictionary = state.get("campaign", {})
	_campaign.text = ("Campaign: %s (revision %d, %s)" % [camp.get("summary", ""), int(camp.get("revision", 0)), camp.get("hash", "")]) if bool(camp.get("exists", false)) else "A new campaign will begin when you start."
	for c: Node in _conflict_box.get_children():
		c.queue_free()
	var conflict: Array = state.get("conflict", [])
	if conflict.size() == 2:
		UiKit.label(_conflict_box, "Your two PCs hold different versions of the campaign. Neither is newer, so pick one together; the other is kept as a branch.", 15, Color(1.0, 0.8, 0.5))
		for k in 2:
			var c: Dictionary = conflict[k]
			UiKit.button(_conflict_box, "%s: %s (rev %d)" % ["Host's copy" if k == 0 else "Guest's copy", c.get("summary", ""), int(c.get("revision", 0))],
				func() -> void: Net.request_lobby_change({"choose_branch": k}))
	if _start != null:
		_start.disabled = not Net.both_ready()
