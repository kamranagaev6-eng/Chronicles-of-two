class_name CampaignStore
extends RefCounted
## One canonical campaign save holding both heroes. The current host is its only writer.
## A copy replaces another only when its history proves it is newer; computer clocks never decide.
##
## File layout (user://saves/<campaign_id>/):
##   campaign.json        latest checkpoint (header line + payload line)
##   campaign.json.tmp    written first, verified, then moved into place (atomic replacement)
##   backups/r<rev>_<hash>.json   retained previous checkpoints
##   branches/<hash>.json         divergent copies kept side by side, never merged
## The payload line is hashed exactly as written, so the checksum never depends on float formatting.

const FORMAT := "chronicle-campaign"
const LINEAGE_CAP := 4096

enum Relation { SAME, A_DESCENDS_FROM_B, B_DESCENDS_FROM_A, DIVERGENT, UNRELATED }

var root_dir: String = "user://saves"
var backups_to_keep: int = 8


class Checkpoint:
	extends RefCounted
	var campaign_id: String = ""
	var schema_version: int = SaveMigrations.CURRENT
	var revision: int = 0
	var parent_hash: String = ""
	## Content hashes of every ancestor, oldest first (the parent is last).
	var lineage: PackedStringArray = PackedStringArray()
	var content_hash: String = ""
	## Informational only: shown in the branch picker, never used to decide anything.
	var created_unix: int = 0
	var created_by: String = ""
	var payload_text: String = ""
	var data: Dictionary = {}

	func short_hash() -> String:
		return content_hash.substr(0, 10)


func _init(p_root: String = "user://saves") -> void:
	root_dir = p_root


static func hash_of(campaign_id: String, schema_version: int, revision: int, parent_hash: String, payload_text: String) -> String:
	var header := "%s|%d|%d|%s|" % [campaign_id, schema_version, revision, parent_hash]
	return (header + payload_text).sha256_text()


## Build the next checkpoint after `parent` (or the first one when parent is null).
static func make_checkpoint(campaign_id: String, data: Dictionary, parent: Checkpoint, created_by: String = "") -> Checkpoint:
	var cp := Checkpoint.new()
	cp.campaign_id = campaign_id
	cp.schema_version = SaveMigrations.CURRENT
	cp.data = data.duplicate(true)
	cp.payload_text = JSON.stringify(cp.data, "", true, true)
	cp.created_unix = int(Time.get_unix_time_from_system())
	cp.created_by = created_by
	if parent != null:
		cp.revision = parent.revision + 1
		cp.parent_hash = parent.content_hash
		cp.lineage = parent.lineage.duplicate()
		cp.lineage.append(parent.content_hash)
		if cp.lineage.size() > LINEAGE_CAP:
			cp.lineage = cp.lineage.slice(cp.lineage.size() - LINEAGE_CAP)
	else:
		cp.revision = 1
	cp.content_hash = hash_of(cp.campaign_id, cp.schema_version, cp.revision, cp.parent_hash, cp.payload_text)
	return cp


static func serialize(cp: Checkpoint) -> String:
	var header := {
		"format": FORMAT,
		"campaign_id": cp.campaign_id,
		"schema_version": cp.schema_version,
		"revision": cp.revision,
		"parent_hash": cp.parent_hash,
		"lineage": Array(cp.lineage),
		"content_hash": cp.content_hash,
		"created_unix": cp.created_unix,
		"created_by": cp.created_by,
	}
	return JSON.stringify(header, "", true) + "\n" + cp.payload_text + "\n"


## Parse and verify a checkpoint. Returns null when the format, checksum or payload is invalid.
static func parse(text: String) -> Checkpoint:
	var newline := text.find("\n")
	if newline < 0:
		return null
	var header_text := text.substr(0, newline)
	var payload := text.substr(newline + 1)
	if payload.ends_with("\n"):
		payload = payload.substr(0, payload.length() - 1)
	var header: Variant = JSON.parse_string(header_text)
	if not (header is Dictionary) or (header as Dictionary).get("format", "") != FORMAT:
		return null
	var h: Dictionary = header
	var cp := Checkpoint.new()
	cp.campaign_id = str(h.get("campaign_id", ""))
	cp.schema_version = int(h.get("schema_version", 0))
	cp.revision = int(h.get("revision", 0))
	cp.parent_hash = str(h.get("parent_hash", ""))
	cp.lineage = PackedStringArray(h.get("lineage", []) as Array)
	cp.content_hash = str(h.get("content_hash", ""))
	cp.created_unix = int(h.get("created_unix", 0))
	cp.created_by = str(h.get("created_by", ""))
	cp.payload_text = payload
	if hash_of(cp.campaign_id, cp.schema_version, cp.revision, cp.parent_hash, payload) != cp.content_hash:
		return null
	var data: Variant = JSON.parse_string(payload)
	if not (data is Dictionary):
		return null
	cp.data = data
	if cp.schema_version < SaveMigrations.CURRENT:
		var migrated := SaveMigrations.migrate(cp.data, cp.schema_version)
		if migrated.is_empty():
			return null
		cp.data = migrated
	elif cp.schema_version > SaveMigrations.CURRENT:
		return null
	return cp


## How two copies of a campaign relate. Ancestry decides; timestamps never do.
static func relation(a: Checkpoint, b: Checkpoint) -> int:
	if a == null or b == null or a.campaign_id != b.campaign_id:
		return Relation.UNRELATED
	if a.content_hash == b.content_hash:
		return Relation.SAME
	if a.lineage.has(b.content_hash):
		return Relation.A_DESCENDS_FROM_B
	if b.lineage.has(a.content_hash):
		return Relation.B_DESCENDS_FROM_A
	return Relation.DIVERGENT


func campaign_dir(campaign_id: String) -> String:
	return "%s/%s" % [root_dir, campaign_id]


func latest_path(campaign_id: String) -> String:
	return campaign_dir(campaign_id) + "/campaign.json"


## Atomically replace the latest checkpoint, keeping the previous one as a backup.
func write(cp: Checkpoint) -> Error:
	var dir := campaign_dir(cp.campaign_id)
	var err := DirAccess.make_dir_recursive_absolute(dir + "/backups")
	if err != OK:
		return err
	var final_path := latest_path(cp.campaign_id)
	var tmp_path := final_path + ".tmp"
	var text := serialize(cp)
	err = _write_text(tmp_path, text)
	if err != OK:
		return err
	var verify := parse(_read_text(tmp_path))
	if verify == null or verify.content_hash != cp.content_hash:
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(final_path):
		var previous := parse(_read_text(final_path))
		if previous != null and previous.content_hash != cp.content_hash:
			var backup := "%s/backups/r%06d_%s.json" % [dir, previous.revision, previous.short_hash()]
			DirAccess.copy_absolute(final_path, backup)
		DirAccess.remove_absolute(final_path)
	err = DirAccess.rename_absolute(tmp_path, final_path)
	if err != OK:
		return err
	_prune_backups(dir + "/backups")
	return OK


## Keep a divergent copy without touching the latest checkpoint.
func store_branch(cp: Checkpoint) -> Error:
	var dir := campaign_dir(cp.campaign_id) + "/branches"
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return err
	return _write_text("%s/%s.json" % [dir, cp.short_hash()], serialize(cp))


func list_branches(campaign_id: String) -> Array[Checkpoint]:
	var out: Array[Checkpoint] = []
	var dir := campaign_dir(campaign_id) + "/branches"
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		var cp := parse(_read_text(dir + "/" + f))
		if cp != null:
			out.append(cp)
	return out


## Load the newest valid checkpoint, recovering from interrupted writes and corrupt files:
## campaign.json, then a verified campaign.json.tmp, then the newest valid backup.
func load_latest(campaign_id: String) -> Checkpoint:
	var final_path := latest_path(campaign_id)
	var cp := parse(_read_text(final_path)) if FileAccess.file_exists(final_path) else null
	var tmp := parse(_read_text(final_path + ".tmp")) if FileAccess.file_exists(final_path + ".tmp") else null
	if cp != null and tmp != null and relation(tmp, cp) == Relation.A_DESCENDS_FROM_B:
		return tmp
	if cp != null:
		return cp
	if tmp != null:
		return tmp
	var best: Checkpoint = null
	var backups := campaign_dir(campaign_id) + "/backups"
	if DirAccess.dir_exists_absolute(backups):
		for f: String in DirAccess.get_files_at(backups):
			var b := parse(_read_text(backups + "/" + f))
			if b == null:
				continue
			if best == null or relation(b, best) == Relation.A_DESCENDS_FROM_B:
				best = b
	return best


func list_campaigns() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(root_dir):
		return out
	for d: String in DirAccess.get_directories_at(root_dir):
		out.append(d)
	return out


func _prune_backups(dir: String) -> void:
	var files: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		files.append(f)
	files.sort()
	while files.size() > backups_to_keep:
		DirAccess.remove_absolute(dir + "/" + files[0])
		files.remove_at(0)


static func _write_text(path: String, text: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.flush()
	f.close()
	return OK


static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t
