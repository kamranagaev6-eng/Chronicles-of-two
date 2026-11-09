extends SceneTree
## Checks every file under res://assets, including import sidecars, plus software metadata.
## Usage: godot --headless --path . -s tools/check_ledger.gd

const Audit = preload("res://tools/license_audit.gd")


func _initialize() -> void:
	var errors: PackedStringArray = PackedStringArray()
	var files: PackedStringArray = PackedStringArray()
	var approvals: PackedStringArray = PackedStringArray()
	var assets: Array[Dictionary] = Audit.read_csv("res://docs/license_ledger.csv", Audit.ASSET_COLUMNS, errors)
	Audit.collect_files("res://assets", files, errors)
	var asset_count: int = files.size()
	for row: Dictionary in assets:
		var path: String = str(row.get("path", ""))
		if FileAccess.file_exists(path) and not files.has(path):
			files.append(path)
		var approval: String = str(row.get("approval", ""))
		if not approval.is_empty() and FileAccess.file_exists(approval):
			approvals.append(approval)
	errors.append_array(Audit.validate_assets(assets, files, approvals))
	var software: Array[Dictionary] = Audit.read_csv("res://docs/software_licenses.csv", Audit.SOFTWARE_COLUMNS, errors)
	var versions: Dictionary[String, String] = {"Godot Engine": "4.7.2-stable", "GUT": "9.7.1", "netfox": "1.35.3"}
	errors.append_array(Audit.validate_software(software, versions))
	for path: String in ["res://addons/gut/LICENSE.md", "res://addons/netfox/LICENSE", "res://addons/netfox.internals/LICENSE"]:
		if not FileAccess.file_exists(path):
			errors.append("missing software licence: " + path)
	for message: String in errors:
		printerr("LEDGER ERROR: " + message)
	print("Ledger check: %d asset files, %d software entries, %d errors." % [asset_count, software.size(), errors.size()])
	quit(0 if errors.is_empty() else 1)
