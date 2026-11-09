extends RefCounted
## Pure checks used by the command-line licence gate and its GUT tests.

const ASSET_COLUMNS: PackedStringArray = [
	"asset_id", "path", "source_url", "author", "licence", "edition",
	"files_included", "attribution", "modifications", "date_verified",
]
const SOFTWARE_COLUMNS: PackedStringArray = ["name", "version", "licence", "source_url", "location", "notes"]


static func validate_assets(
		rows: Array[Dictionary], existing_files: PackedStringArray,
		approval_files: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var paths: Dictionary[String, bool] = {}
	var ids: Dictionary[String, bool] = {}
	for row: Dictionary in rows:
		var path: String = str(row.get("path", "")).strip_edges()
		var asset_id: String = str(row.get("asset_id", "")).strip_edges()
		if not _canonical_path(path):
			errors.append("invalid asset path: " + path)
		if paths.has(path):
			errors.append("duplicate asset path: " + path)
		if ids.has(asset_id):
			errors.append("duplicate asset_id: " + asset_id)
		paths[path] = true
		ids[asset_id] = true
		for field: String in ["asset_id", "author", "licence", "files_included", "date_verified"]:
			if str(row.get(field, "")).strip_edges().is_empty():
				errors.append("%s: missing %s" % [path, field])
		if not existing_files.has(path):
			errors.append("ledger path does not exist: " + path)
		var licence: String = str(row.get("licence", "")).strip_edges()
		if licence != "Original work":
			if not _web_url(str(row.get("source_url", ""))):
				errors.append("%s: third-party asset needs a source_url" % path)
			if str(row.get("edition", "")).strip_edges().is_empty():
				errors.append("%s: third-party asset needs the downloaded edition" % path)
		if licence not in ["CC0", "CC0-1.0", "Original work"]:
			var approval: String = str(row.get("approval", "")).strip_edges()
			if not _canonical_path(approval) or not approval.begins_with("res://docs/") or not approval_files.has(approval):
				errors.append("%s: %s requires a written owner approval file in docs" % [path, licence])
	for path: String in existing_files:
		if path.begins_with("res://assets/") and not paths.has(path):
			errors.append("no ledger row for " + path)
	return errors


static func validate_software(rows: Array[Dictionary], expected_versions: Dictionary[String, String]) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var names: Dictionary[String, bool] = {}
	for row: Dictionary in rows:
		var software_name: String = str(row.get("name", "")).strip_edges()
		if names.has(software_name):
			errors.append("duplicate software name: " + software_name)
		names[software_name] = true
		for field: String in SOFTWARE_COLUMNS:
			if str(row.get(field, "")).strip_edges().is_empty():
				errors.append("%s: missing software %s" % [software_name, field])
		if not _web_url(str(row.get("source_url", ""))):
			errors.append("%s: software needs a source_url" % software_name)
		if expected_versions.has(software_name):
			if str(row.get("version", "")) != expected_versions[software_name]:
				errors.append("%s: software version must be %s" % [software_name, expected_versions[software_name]])
	for software_name: String in expected_versions:
		if not names.has(software_name):
			errors.append("missing software ledger row: " + software_name)
	return errors


static func read_csv(path: String, required_columns: PackedStringArray, errors: PackedStringArray) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("cannot open " + path)
		return rows
	var header: PackedStringArray = file.get_csv_line()
	var seen: Dictionary[String, bool] = {}
	for index: int in range(header.size()):
		header[index] = header[index].trim_prefix("\ufeff").strip_edges()
		if seen.has(header[index]):
			errors.append("%s: duplicate column %s" % [path, header[index]])
		seen[header[index]] = true
	for column: String in required_columns:
		if not header.has(column):
			errors.append("%s: missing column %s" % [path, column])
	var record: int = 1
	while not file.eof_reached():
		var values: PackedStringArray = file.get_csv_line()
		record += 1
		if values.size() == 1 and values[0].strip_edges().is_empty():
			continue
		if values.size() != header.size():
			errors.append("%s record %d: expected %d columns, found %d" % [path, record, header.size(), values.size()])
			continue
		var row: Dictionary = {}
		for index: int in range(header.size()):
			row[header[index]] = values[index].strip_edges()
		rows.append(row)
	file.close()
	return rows


static func collect_files(folder: String, files: PackedStringArray, errors: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	var directory: DirAccess = DirAccess.open(folder)
	if directory == null:
		errors.append("cannot read " + folder)
		return
	directory.include_hidden = true
	for file_name: String in directory.get_files():
		files.append(folder.path_join(file_name))
	for child: String in directory.get_directories():
		if directory.is_link(child):
			errors.append("asset directory links must be replaced with files: " + folder.path_join(child))
		else:
			collect_files(folder.path_join(child), files, errors)


static func _canonical_path(path: String) -> bool:
	return path.begins_with("res://") and path.length() > 6 and path == path.simplify_path() and not path.contains("\\") and not path.contains("*")


static func _web_url(value: String) -> bool:
	return (value.begins_with("https://") and value.length() > 8) or (value.begins_with("http://") and value.length() > 7)
