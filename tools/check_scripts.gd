extends SceneTree
## Compiles every GDScript under res://game and res://tests and reports failures (exit code 1).
## Usage: godot --headless --path . -s tools/check_scripts.gd


func _initialize() -> void:
	var paths: PackedStringArray = PackedStringArray()
	for folder: String in ["res://game", "res://tests", "res://tools"]:
		_collect(folder, paths)
	var failed: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		if script == null or not script.can_instantiate():
			failed.append(path)
	for f: String in failed:
		printerr("SCRIPT FAILED: " + f)
	print("Script check: %d scripts, %d failed." % [paths.size(), failed.size()])
	quit(1 if not failed.is_empty() else 0)


func _collect(folder: String, out: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for f: String in DirAccess.get_files_at(folder):
		if f.ends_with(".gd"):
			out.append(folder.path_join(f))
	for d: String in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(d), out)
