extends GutTest

const Audit = preload("res://tools/license_audit.gd")
const PATH: String = "res://assets/example.svg"


func _original() -> Dictionary:
	return {"asset_id": "example", "path": PATH, "source_url": "", "author": "Chronicle of Two project",
		"licence": "Original work", "edition": "", "files_included": "example.svg", "attribution": "",
		"modifications": "", "date_verified": "2026-11-09"}


func test_original_work_needs_no_external_url() -> void:
	assert_eq(Audit.validate_assets([_original()], [PATH]).size(), 0)


func test_empty_asset_folder_is_valid_with_an_empty_ledger() -> void:
	assert_eq(Audit.validate_assets([], []).size(), 0)


func test_every_asset_file_including_sidecars_and_markdown_needs_a_row() -> void:
	var errors: PackedStringArray = Audit.validate_assets([_original()], [PATH, PATH + ".import", PATH + ".uid", "res://assets/README.md", "res://assets/.gdignore"])
	assert_eq(errors.size(), 4)
	assert_has(errors, "no ledger row for " + PATH + ".import")


func test_duplicate_content_ids_and_paths_are_reported() -> void:
	var errors: PackedStringArray = Audit.validate_assets([_original(), _original()], [PATH])
	assert_has(errors, "duplicate asset_id: example")
	assert_has(errors, "duplicate asset path: " + PATH)


func test_ledger_cannot_list_a_missing_asset() -> void:
	assert_has(Audit.validate_assets([_original()], []), "ledger path does not exist: " + PATH)


func test_traversal_and_wildcard_paths_are_rejected() -> void:
	for path: String in ["res://assets/../example.svg", "res://assets/*.svg", "assets/example.svg", "res://assets\\example.svg"]:
		var row: Dictionary = _original()
		row["path"] = path
		assert_has(Audit.validate_assets([row], [path]), "invalid asset path: " + path)


func test_cc0_assets_require_source_and_downloaded_edition() -> void:
	var row: Dictionary = _original()
	row["licence"] = "CC0-1.0"
	assert_eq(Audit.validate_assets([row], [PATH]).size(), 2)
	row["source_url"] = "https://example.com/pack"
	row["edition"] = "Free edition 1"
	assert_eq(Audit.validate_assets([row], [PATH]).size(), 0)


func test_other_licences_require_an_existing_written_approval_reference() -> void:
	var row: Dictionary = _original()
	row["licence"] = "CC-BY-4.0"
	row["source_url"] = "https://example.com/pack"
	row["edition"] = "1"
	row["approval"] = "yes"
	assert_eq(Audit.validate_assets([row], [PATH], ["yes"]).size(), 1)
	row["approval"] = "res://docs/approvals/example.md"
	assert_eq(Audit.validate_assets([row], [PATH]).size(), 1)
	assert_eq(Audit.validate_assets([row], [PATH], ["res://docs/approvals/example.md"]).size(), 0)


func test_required_asset_metadata_cannot_be_blank() -> void:
	var row: Dictionary = _original()
	row["author"] = " "
	row["date_verified"] = ""
	assert_eq(Audit.validate_assets([row], [PATH]).size(), 2)


func test_software_ledger_matches_pinned_versions() -> void:
	var pins: Dictionary[String, String] = {"GUT": "9.7.1"}
	var row: Dictionary = {"name": "GUT", "version": "9.7.1", "licence": "MIT",
		"source_url": "https://github.com/bitwes/Gut", "location": "addons/gut", "notes": "LICENSE.md included"}
	assert_eq(Audit.validate_software([row], pins).size(), 0)
	row["version"] = "9.0"
	assert_has(Audit.validate_software([row], pins), "GUT: software version must be 9.7.1")
	assert_has(Audit.validate_software([], pins), "missing software ledger row: GUT")


func test_csv_reader_reports_missing_columns_and_malformed_rows() -> void:
	var path: String = "user://license_audit_test.csv"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("asset_id,path\nexample,res://assets/example.svg,unexpected\n")
	file.close()
	var errors: PackedStringArray = PackedStringArray()
	var rows: Array[Dictionary] = Audit.read_csv(path, Audit.ASSET_COLUMNS, errors)
	assert_eq(rows.size(), 0)
	assert_has(errors, path + ": missing column licence")
	assert_has(errors, path + " record 2: expected 2 columns, found 3")
	assert_eq(DirAccess.remove_absolute(path), OK)


func test_csv_reader_preserves_quoted_commas() -> void:
	var path: String = "user://license_audit_test.csv"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("name,notes\nGUT,\"Bundled, unchanged\"\n")
	file.close()
	var errors: PackedStringArray = PackedStringArray()
	var rows: Array[Dictionary] = Audit.read_csv(path, ["name", "notes"], errors)
	assert_eq(errors.size(), 0)
	assert_eq(rows.size(), 1)
	if rows.size() == 1:
		assert_eq(rows[0]["notes"], "Bundled, unchanged")
	assert_eq(DirAccess.remove_absolute(path), OK)
