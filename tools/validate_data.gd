extends SceneTree
## Headless data validator: loads every table and definition through the typed loaders.
## Usage: godot --headless --path . -s tools/validate_data.gd   (exit code 1 on any error)


func _initialize() -> void:
	var data: Node = root.get_node_or_null("GameData")
	if data == null:
		data = (load("res://game/data/game_data.gd") as GDScript).new()
		root.add_child(data)
	data.call("ensure_loaded")
	var errors: PackedStringArray = data.get("errors")
	print("Data validation: %d abilities, %d classes, %d enemies, %d runes, %d rules, content hash %s" % [
		(data.get("abilities") as Dictionary).size(), (data.get("classes") as Dictionary).size(),
		(data.get("enemies") as Dictionary).size(), (data.get("runes") as Dictionary).size(),
		(data.get("rules") as Dictionary).size(), str(data.call("content_hash")).substr(0, 16)])
	for e: String in errors:
		printerr("DATA ERROR: " + e)
	if errors.is_empty():
		print("Data validation passed.")
	quit(1 if not errors.is_empty() else 0)
