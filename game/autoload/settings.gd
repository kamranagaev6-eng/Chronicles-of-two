extends Node
## Autoload "Settings": this PC's profile, options, per-player assists, input bindings and the
## command-line switches used for local two-instance testing and soak runs.
##
## Command line (after `--`): --host  --join=ADDRESS  --port=N  --name=TEXT  --class=vanguard|riftweaver
##   --profile=NAME (separate profile and saves, for two instances on one PC)  --bot  --auto-ready
##   --quit-after=SECONDS  --solo  --scene=asset_test  --log-net

signal changed

const ACTIONS := {
	&"move_left": [{"key": KEY_A}, {"key": KEY_LEFT}, {"axis": JOY_AXIS_LEFT_X, "value": -1.0}],
	&"move_right": [{"key": KEY_D}, {"key": KEY_RIGHT}, {"axis": JOY_AXIS_LEFT_X, "value": 1.0}],
	&"move_up": [{"key": KEY_W}, {"key": KEY_UP}, {"axis": JOY_AXIS_LEFT_Y, "value": -1.0}],
	&"move_down": [{"key": KEY_S}, {"key": KEY_DOWN}, {"axis": JOY_AXIS_LEFT_Y, "value": 1.0}],
	&"aim_left": [{"axis": JOY_AXIS_RIGHT_X, "value": -1.0}],
	&"aim_right": [{"axis": JOY_AXIS_RIGHT_X, "value": 1.0}],
	&"aim_up": [{"axis": JOY_AXIS_RIGHT_Y, "value": -1.0}],
	&"aim_down": [{"axis": JOY_AXIS_RIGHT_Y, "value": 1.0}],
	&"attack": [{"mouse": MOUSE_BUTTON_LEFT}, {"axis": JOY_AXIS_TRIGGER_RIGHT, "value": 1.0}],
	&"ability_1": [{"mouse": MOUSE_BUTTON_RIGHT}, {"joy": JOY_BUTTON_RIGHT_SHOULDER}],
	&"ability_2": [{"key": KEY_Q}, {"joy": JOY_BUTTON_LEFT_SHOULDER}],
	&"ability_3": [{"key": KEY_E}, {"joy": JOY_BUTTON_Y}],
	&"ability_4": [{"key": KEY_R}, {"axis": JOY_AXIS_TRIGGER_LEFT, "value": 1.0}],
	&"dodge": [{"key": KEY_SPACE}, {"joy": JOY_BUTTON_A}],
	&"shove": [{"key": KEY_SHIFT}, {"joy": JOY_BUTTON_B}],
	&"interact": [{"key": KEY_F}, {"joy": JOY_BUTTON_X}],
	&"flask": [{"key": KEY_1}, {"joy": JOY_BUTTON_DPAD_UP}],
	&"bond": [{"key": KEY_T}, {"joy": JOY_BUTTON_RIGHT_STICK}],
	&"ping": [{"mouse": MOUSE_BUTTON_MIDDLE}, {"key": KEY_Z}, {"joy": JOY_BUTTON_DPAD_DOWN}],
	&"pause": [{"key": KEY_ESCAPE}, {"joy": JOY_BUTTON_START}],
	&"loadout": [{"key": KEY_TAB}, {"joy": JOY_BUTTON_BACK}],
	&"net_overlay": [{"key": KEY_F3}],
	&"help": [{"key": KEY_F1}],
}

const ACTION_LABELS := {
	&"attack": "Basic attack", &"ability_1": "Ability 1", &"ability_2": "Ability 2", &"ability_3": "Ability 3",
	&"ability_4": "Ability 4", &"dodge": "Dodge", &"shove": "Shove", &"interact": "Interact / revive",
	&"flask": "Healing flask", &"bond": "Bond action", &"ping": "Ping", &"pause": "Pause", &"loadout": "Loadout",
}

var profile_name: String = "default"
var profile: Dictionary = {}
var options: Dictionary = {}
var args: Dictionary = {}
var _overrides: Dictionary = {}  # action -> Array of serialised events


func _ready() -> void:
	_parse_args()
	profile_name = str(args.get("profile", "default")).validate_filename()
	_load_profile()
	_load_options()
	_apply_bindings()
	if args.has("name"):
		profile["name"] = str(args["name"])


func data_dir() -> String:
	var dir := "user://profiles/%s" % profile_name
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


func saves_dir() -> String:
	return data_dir() + "/saves"


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


# --- Command line ------------------------------------------------------------------

func _parse_args() -> void:
	for raw: String in OS.get_cmdline_user_args():
		if not raw.begins_with("--"):
			continue
		var body := raw.substr(2)
		var eq := body.find("=")
		if eq >= 0:
			args[body.substr(0, eq)] = body.substr(eq + 1)
		else:
			args[body] = true


func arg(key: String, default_value: Variant = null) -> Variant:
	return args.get(key, default_value)


func has_arg(key: String) -> bool:
	return args.has(key)


# --- Profile and options -------------------------------------------------------------

func _load_profile() -> void:
	profile = _read_json(data_dir() + "/profile.json")
	var dirty := false
	if not profile.has("profile_id"):
		var bytes := Crypto.new().generate_random_bytes(12)
		profile["profile_id"] = bytes.hex_encode()
		dirty = true
	if not profile.has("name"):
		profile["name"] = "Hero"
		dirty = true
	if not profile.has("color"):
		profile["color"] = "gold"
		dirty = true
	if dirty:
		save_profile()


func save_profile() -> void:
	_write_json(data_dir() + "/profile.json", profile)


func _load_options() -> void:
	var defaults := {
		"camera_shake": 1.0,
		"master_volume": 0.8,
		"damage_numbers": true,
		"assists": {"aim": true, "dodge_timing": false, "damage_taken": false, "telegraph_emphasis": false, "hold_to_revive": true, "subtitles": true},
		"last_address": "127.0.0.1",
		"port": NetProtocol.DEFAULT_PORT,
		"favourites": [],
		"bindings": {},
	}
	options = defaults
	var stored := _read_json(data_dir() + "/options.json")
	for key: String in stored.keys():
		options[key] = stored[key]
	var assists: Dictionary = defaults["assists"].duplicate()
	for key: String in (options.get("assists", {}) as Dictionary).keys():
		assists[key] = options["assists"][key]
	options["assists"] = assists
	_overrides = options.get("bindings", {}) as Dictionary
	AudioServer.set_bus_volume_db(0, linear_to_db(float(options["master_volume"])))


func save_options() -> void:
	options["bindings"] = _overrides
	_write_json(data_dir() + "/options.json", options)
	changed.emit()


func option(key: String, default_value: Variant = null) -> Variant:
	return options.get(key, default_value)


func set_option(key: String, value: Variant) -> void:
	options[key] = value
	if key == "master_volume":
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(value))))
	save_options()


func assist(key: String) -> bool:
	return bool((options.get("assists", {}) as Dictionary).get(key, false))


func set_assist(key: String, value: bool) -> void:
	var a: Dictionary = options.get("assists", {})
	a[key] = value
	options["assists"] = a
	save_options()


## Assists that change shared gameplay; sent to the host with the lobby state.
func gameplay_assists() -> Dictionary:
	return {"dodge_timing": assist("dodge_timing"), "damage_taken": assist("damage_taken")}


func add_favourite(label: String, address: String) -> void:
	var favs: Array = options.get("favourites", [])
	for f: Dictionary in favs:
		if str(f.get("address", "")) == address:
			return
	favs.append({"name": label, "address": address})
	options["favourites"] = favs
	save_options()


# --- Input bindings ------------------------------------------------------------------

func _apply_bindings() -> void:
	for action: StringName in ACTIONS.keys():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.25)
		var specs: Array = _overrides.get(String(action), ACTIONS[action]) as Array
		for spec: Variant in specs:
			var ev := _event_from_spec(spec as Dictionary)
			if ev != null:
				InputMap.action_add_event(action, ev)


func _event_from_spec(spec: Dictionary) -> InputEvent:
	if spec.has("key"):
		var k := InputEventKey.new()
		k.physical_keycode = int(spec["key"]) as Key
		return k
	if spec.has("mouse"):
		var m := InputEventMouseButton.new()
		m.button_index = int(spec["mouse"]) as MouseButton
		return m
	if spec.has("joy"):
		var j := InputEventJoypadButton.new()
		j.button_index = int(spec["joy"]) as JoyButton
		return j
	if spec.has("axis"):
		var a := InputEventJoypadMotion.new()
		a.axis = int(spec["axis"]) as JoyAxis
		a.axis_value = float(spec["value"])
		return a
	return null


static func spec_from_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {"key": int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)}
	if ev is InputEventMouseButton:
		return {"mouse": int((ev as InputEventMouseButton).button_index)}
	if ev is InputEventJoypadButton:
		return {"joy": int((ev as InputEventJoypadButton).button_index)}
	if ev is InputEventJoypadMotion:
		var a := ev as InputEventJoypadMotion
		return {"axis": int(a.axis), "value": signf(a.axis_value)}
	return {}


## Replace the keyboard/mouse binding of an action (controller bindings stay).
func rebind(action: StringName, ev: InputEvent) -> void:
	var specs: Array = []
	for spec: Dictionary in _overrides.get(String(action), ACTIONS.get(action, [])):
		if spec.has("joy") or spec.has("axis"):
			specs.append(spec)
	specs.push_front(spec_from_event(ev))
	_overrides[String(action)] = specs
	_apply_bindings()
	save_options()


func reset_bindings() -> void:
	_overrides = {}
	_apply_bindings()
	save_options()


func binding_text(action: StringName) -> String:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
		if ev is InputEventMouseButton:
			match (ev as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
	return "-"


# --- JSON helpers --------------------------------------------------------------------

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _write_json(path: String, data: Dictionary) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)
