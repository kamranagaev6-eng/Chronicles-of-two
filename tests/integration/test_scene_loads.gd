extends GutTest
## Instantiate authored scenes off-tree so the smoke test cannot start a real session.


func test_main_scene_exists_and_can_be_instantiated() -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	assert_false(main_scene.is_empty(), "A playable main scene must be configured")
	if main_scene.is_empty():
		return
	assert_true(ResourceLoader.exists(main_scene, "PackedScene"), "Main scene exists: " + main_scene)
	if ResourceLoader.exists(main_scene, "PackedScene"):
		_check_scene(main_scene)


func test_all_authored_scenes_and_resources_load() -> void:
	var paths: PackedStringArray = PackedStringArray()
	var extensions: PackedStringArray = ResourceLoader.get_recognized_extensions_for_type("")
	for folder: String in ["res://game", "res://data", "res://assets"]:
		_collect_files(folder, paths)
	var resource_count: int = 0
	for path: String in paths:
		var extension: String = path.get_extension().to_lower()
		if extension == "gd":
			continue
		var is_imported: bool = FileAccess.file_exists(path + ".import")
		if is_imported:
			var config: ConfigFile = ConfigFile.new()
			var status: Error = config.load(path + ".import")
			assert_eq(status, OK, "Import metadata loads: " + path)
			if status == OK and str(config.get_value("remap", "importer", "")) == "keep":
				continue
		if not is_imported and not extensions.has(extension):
			continue
		resource_count += 1
		var resource: Resource = ResourceLoader.load(path)
		assert_not_null(resource, "Resource loads: " + path)
		if resource is PackedScene:
			_check_scene(path)
	assert_gt(resource_count, 0, "Smoke discovery must find authored content")


func test_data_csvs_keep_their_source_format() -> void:
	var paths: PackedStringArray = PackedStringArray()
	_collect_files("res://data", paths)
	var csv_count: int = 0
	for path: String in paths:
		if path.get_extension().to_lower() != "csv":
			continue
		csv_count += 1
		var config: ConfigFile = ConfigFile.new()
		var status: Error = config.load(path + ".import")
		assert_eq(status, OK, "CSV import sidecar exists: " + path)
		if status == OK:
			assert_eq(str(config.get_value("remap", "importer", "")), "keep", "Use Keep File in the editor: " + path)
	assert_gt(csv_count, 0, "Data tables must be discovered")


func test_all_game_scripts_compile() -> void:
	var paths: PackedStringArray = PackedStringArray()
	_collect_files("res://game", paths)
	var script_count: int = 0
	for path: String in paths:
		if path.get_extension() != "gd":
			continue
		script_count += 1
		var script: Script = ResourceLoader.load(path) as Script
		assert_not_null(script, "Script loads: " + path)
		if script != null:
			assert_true(script.is_abstract() or script.can_instantiate(), "Script compiles: " + path)
	assert_gt(script_count, 0, "Gameplay scripts must be discovered")


func _check_scene(path: String) -> void:
	var scene: PackedScene = ResourceLoader.load(path) as PackedScene
	assert_not_null(scene, "Scene loads: " + path)
	if scene == null:
		return
	assert_true(scene.can_instantiate(), "Scene has a root: " + path)
	if not scene.can_instantiate():
		return
	var instance: Node = scene.instantiate()
	assert_not_null(instance, "Scene instantiates: " + path)
	if instance != null:
		instance.free()


func _collect_files(folder: String, paths: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	var directory: DirAccess = DirAccess.open(folder)
	assert_not_null(directory, "Content folder is readable: " + folder)
	if directory == null:
		return
	directory.include_hidden = true
	for file_name: String in directory.get_files():
		paths.append(folder.path_join(file_name))
	for child: String in directory.get_directories():
		if not directory.is_link(child):
			_collect_files(folder.path_join(child), paths)
