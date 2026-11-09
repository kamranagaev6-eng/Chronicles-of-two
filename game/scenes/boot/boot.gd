extends Control
## Main menu: your name and colour, host or join (Tailscale address first, LAN second), solo practice,
## the asset test scene, settings and assists. Command-line switches automate local two-instance runs.

var _status: Label
var _name_edit: LineEdit
var _address_edit: LineEdit
var _port_edit: SpinBox
var _favourites: OptionButton
var _settings_panel: PanelContainer
var _menu: VBoxContainer


func _ready() -> void:
	UiKit.background(self)
	_menu = UiKit.centered_column(self, 520)
	UiKit.label(_menu, "Chronicle of Two", 44, UiKit.ACCENT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_menu, "The Last Hearth · Milestone 1 combat arena", 18, UiKit.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var card := UiKit.panel(_menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var r1 := UiKit.row(v)
	UiKit.label(r1, "Your hero's name", 15).custom_minimum_size.x = 150
	_name_edit = LineEdit.new()
	_name_edit.text = str(Settings.profile.get("name", "Hero"))
	_name_edit.custom_minimum_size.x = 220
	_name_edit.text_changed.connect(func(t: String) -> void:
		Settings.profile["name"] = t.strip_edges().left(24)
		Settings.save_profile())
	r1.add_child(_name_edit)
	var color := OptionButton.new()
	color.add_item("Gold")
	color.add_item("Violet")
	color.select(1 if str(Settings.profile.get("color", "gold")) == "violet" else 0)
	color.item_selected.connect(func(i: int) -> void:
		Settings.profile["color"] = "violet" if i == 1 else "gold"
		Settings.save_profile())
	r1.add_child(color)
	var r2 := UiKit.row(v)
	UiKit.button(r2, "Host a game", _host)
	UiKit.label(r2, "Port", 15)
	_port_edit = SpinBox.new()
	_port_edit.min_value = 1024
	_port_edit.max_value = 65535
	_port_edit.value = int(Settings.option("port", NetProtocol.DEFAULT_PORT))
	r2.add_child(_port_edit)
	var r3 := UiKit.row(v)
	UiKit.button(r3, "Join", _join)
	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "Partner's Tailscale or LAN address"
	_address_edit.text = str(Settings.option("last_address", "127.0.0.1"))
	_address_edit.custom_minimum_size.x = 260
	r3.add_child(_address_edit)
	var r4 := UiKit.row(v)
	_favourites = OptionButton.new()
	_favourites.custom_minimum_size.x = 260
	_favourites.item_selected.connect(func(i: int) -> void:
		if i > 0:
			_address_edit.text = str(_favourites.get_item_metadata(i)))
	r4.add_child(_favourites)
	UiKit.button(r4, "Save as favourite", func() -> void:
		Settings.add_favourite(_address_edit.text, _address_edit.text.strip_edges())
		_refresh_favourites())
	_refresh_favourites()
	UiKit.button(v, "Solo practice (dummies and waves, nothing saved)", _solo)
	UiKit.button(v, "Asset test scene (M0)", func() -> void: get_tree().change_scene_to_file("res://game/scenes/asset_test/asset_test.tscn"))
	UiKit.button(v, "Settings and assists", func() -> void: _settings_panel.visible = not _settings_panel.visible)
	UiKit.button(v, "Quit", func() -> void: get_tree().quit())
	_status = UiKit.label(_menu, Net.last_status, 15, UiKit.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Net.status_changed.connect(func(t: String) -> void:
		if is_instance_valid(_status):
			_status.text = t)
	_build_settings()
	_auto_start.call_deferred()


func _refresh_favourites() -> void:
	_favourites.clear()
	_favourites.add_item("Favourites...")
	for f: Variant in Settings.option("favourites", []):
		var fav := f as Dictionary
		_favourites.add_item("%s" % fav.get("name", fav.get("address", "")))
		_favourites.set_item_metadata(_favourites.item_count - 1, str(fav.get("address", "")))


func _host() -> void:
	Settings.set_option("port", int(_port_edit.value))
	if Net.host_game(int(_port_edit.value)) == OK:
		get_tree().change_scene_to_file(Net.LOBBY_SCENE)


func _join() -> void:
	var address := _address_edit.text.strip_edges()
	if address == "":
		_status.text = "Enter your partner's Tailscale or LAN address."
		return
	Settings.set_option("last_address", address)
	Settings.set_option("port", int(_port_edit.value))
	Net.join_game(address, int(_port_edit.value))


func _solo() -> void:
	if Net.host_game(int(_port_edit.value), true) == OK:
		var players: Array = Net.lobby["players"]
		(players[0] as Dictionary)["ready"] = true
		Net.start_session()


func _auto_start() -> void:
	var port := int(str(Settings.arg("port", str(Settings.option("port", NetProtocol.DEFAULT_PORT)))))
	_port_edit.value = port
	if str(Settings.arg("scene", "")) == "asset_test":
		get_tree().change_scene_to_file("res://game/scenes/asset_test/asset_test.tscn")
	elif Settings.has_arg("solo"):
		_solo()
	elif Settings.has_arg("host"):
		_host()
	elif Settings.has_arg("join"):
		var target := str(Settings.arg("join"))
		_address_edit.text = "127.0.0.1" if target == "true" else target
		var delay := float(str(Settings.arg("join-delay", "0.8")))
		await get_tree().create_timer(delay).timeout
		_join()


func _build_settings() -> void:
	_settings_panel = UiKit.panel(self)
	_settings_panel.position = Vector2(24, 24)
	_settings_panel.visible = false
	var v := VBoxContainer.new()
	_settings_panel.add_child(v)
	UiKit.label(v, "Settings", 22, UiKit.ACCENT)
	var shake := HSlider.new()
	shake.min_value = 0.0
	shake.max_value = 1.0
	shake.step = 0.05
	shake.value = float(Settings.option("camera_shake", 1.0))
	shake.custom_minimum_size.x = 200
	shake.value_changed.connect(func(x: float) -> void: Settings.set_option("camera_shake", x))
	var r := UiKit.row(v)
	UiKit.label(r, "Camera shake", 15)
	r.add_child(shake)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = float(Settings.option("master_volume", 0.8))
	vol.custom_minimum_size.x = 200
	vol.value_changed.connect(func(x: float) -> void: Settings.set_option("master_volume", x))
	var r2 := UiKit.row(v)
	UiKit.label(r2, "Volume", 15)
	r2.add_child(vol)
	UiKit.label(v, "Assists (private to you)", 17, UiKit.ACCENT)
	var assist_labels := {"aim": "Aim assistance (controller)", "dodge_timing": "Dodge timing assistance (+50% window)",
		"damage_taken": "Take 25% less damage", "telegraph_emphasis": "Telegraph emphasis", "hold_to_revive": "Hold to revive (instead of toggle)"}
	for key: String in assist_labels.keys():
		var cb := CheckBox.new()
		cb.text = assist_labels[key]
		cb.button_pressed = Settings.assist(key)
		cb.toggled.connect(func(on: bool) -> void: Settings.set_assist(key, on))
		v.add_child(cb)
	UiKit.label(v, "Keyboard bindings (click, then press a key or mouse button)", 17, UiKit.ACCENT)
	for action: StringName in Settings.ACTION_LABELS.keys():
		var rr := UiKit.row(v)
		UiKit.label(rr, Settings.ACTION_LABELS[action], 14).custom_minimum_size.x = 160
		var b := Button.new()
		b.text = Settings.binding_text(action)
		b.custom_minimum_size.x = 90
		b.pressed.connect(func() -> void:
			b.text = "..."
			_capture_binding(action, b))
		rr.add_child(b)
	UiKit.button(v, "Reset bindings", func() -> void:
		Settings.reset_bindings()
		_settings_panel.queue_free()
		_build_settings()
		_settings_panel.visible = true)


var _capturing: StringName = &""
var _capture_button: Button


func _capture_binding(action: StringName, b: Button) -> void:
	_capturing = action
	_capture_button = b


func _input(event: InputEvent) -> void:
	if _capturing == &"":
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		Settings.rebind(_capturing, event)
		_capture_button.text = Settings.binding_text(_capturing)
		_capturing = &""
		get_viewport().set_input_as_handled()
