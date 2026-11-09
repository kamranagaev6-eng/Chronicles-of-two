class_name CsvTable
extends RefCounted
## Typed CSV table loader. The header names the columns; a schema maps each column to a type.
## Rows starting with '#' are comments. Every problem is collected in `errors` (never silently fixed).

enum ColumnType { STRING, NAME, INT, FLOAT, BOOL, NAME_LIST }

var path: String = ""
var columns: PackedStringArray = PackedStringArray()
var rows: Array[Dictionary] = []
var errors: PackedStringArray = PackedStringArray()


static func load_table(p_path: String, schema: Dictionary, key_column: String = "") -> CsvTable:
	var table := CsvTable.new()
	table.path = p_path
	var file := FileAccess.open(p_path, FileAccess.READ)
	if file == null:
		table.errors.append("%s: cannot open (%s)" % [p_path, error_string(FileAccess.get_open_error())])
		return table
	var text := file.get_as_text()
	file.close()
	table.parse_text(text, schema, key_column)
	return table


static func from_text(text: String, schema: Dictionary, key_column: String = "", p_path: String = "<memory>") -> CsvTable:
	var table := CsvTable.new()
	table.path = p_path
	table.parse_text(text, schema, key_column)
	return table


func parse_text(text: String, schema: Dictionary, key_column: String) -> void:
	var lines := _split_records(text)
	var header_found := false
	var seen_keys: Dictionary = {}
	var line_no := 0
	for record: PackedStringArray in lines:
		line_no += 1
		if record.is_empty():
			continue
		var first := record[0].strip_edges()
		if first.begins_with("#"):
			continue
		if record.size() == 1 and first == "":
			continue
		if not header_found:
			header_found = true
			for c: String in record:
				columns.append(c.strip_edges())
			for col: String in schema.keys():
				if not columns.has(col):
					errors.append("%s: missing column '%s'" % [path, col])
			for col: String in columns:
				if not schema.has(col):
					errors.append("%s: unexpected column '%s'" % [path, col])
			if key_column != "" and not columns.has(key_column):
				errors.append("%s: key column '%s' missing" % [path, key_column])
			continue
		if record.size() != columns.size():
			errors.append("%s:%d: expected %d fields, found %d" % [path, line_no, columns.size(), record.size()])
			continue
		var row: Dictionary = {}
		for i in columns.size():
			var col := columns[i]
			if not schema.has(col):
				continue
			var raw := record[i].strip_edges()
			var parsed: Variant = _parse_cell(raw, schema[col] as int, line_no, col)
			row[col] = parsed
		if key_column != "" and row.has(key_column):
			var key := str(row[key_column])
			if seen_keys.has(key):
				errors.append("%s:%d: duplicate key '%s'" % [path, line_no, key])
			seen_keys[key] = true
		rows.append(row)
	if not header_found:
		errors.append("%s: no header row" % path)


func is_ok() -> bool:
	return errors.is_empty()


## Rows keyed by the given column (as String keys of the original value).
func index_by(column: String) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		result[row.get(column)] = row
	return result


func _parse_cell(raw: String, column_type: int, line_no: int, col: String) -> Variant:
	match column_type:
		ColumnType.STRING:
			return raw
		ColumnType.NAME:
			return StringName(raw)
		ColumnType.INT:
			if raw == "":
				return 0
			if not raw.is_valid_int():
				errors.append("%s:%d: column '%s' expects an integer, got '%s'" % [path, line_no, col, raw])
				return 0
			return raw.to_int()
		ColumnType.FLOAT:
			if raw == "":
				return 0.0
			if not raw.is_valid_float():
				errors.append("%s:%d: column '%s' expects a number, got '%s'" % [path, line_no, col, raw])
				return 0.0
			return raw.to_float()
		ColumnType.BOOL:
			var lower := raw.to_lower()
			if lower in ["true", "1", "yes"]:
				return true
			if lower in ["false", "0", "no", ""]:
				return false
			errors.append("%s:%d: column '%s' expects true/false, got '%s'" % [path, line_no, col, raw])
			return false
		ColumnType.NAME_LIST:
			var out: Array[StringName] = []
			if raw == "":
				return out
			for part: String in raw.split(";", false):
				out.append(StringName(part.strip_edges()))
			return out
	errors.append("%s:%d: unknown column type for '%s'" % [path, line_no, col])
	return raw


## RFC 4180-style split that supports quoted fields with commas, doubled quotes and CRLF.
static func _split_records(text: String) -> Array[PackedStringArray]:
	var records: Array[PackedStringArray] = []
	var field := ""
	var record := PackedStringArray()
	var in_quotes := false
	var i := 0
	var n := text.length()
	while i < n:
		var ch := text[i]
		if in_quotes:
			if ch == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					in_quotes = false
			else:
				field += ch
		else:
			if ch == "\"":
				in_quotes = true
			elif ch == ",":
				record.append(field)
				field = ""
			elif ch == "\n" or ch == "\r":
				if ch == "\r" and i + 1 < n and text[i + 1] == "\n":
					i += 1
				record.append(field)
				records.append(record)
				record = PackedStringArray()
				field = ""
			else:
				field += ch
		i += 1
	if field != "" or not record.is_empty():
		record.append(field)
		records.append(record)
	return records
