extends RefCounted
## The save on disk: staged writes (a temporary file read back and checked
## before it replaces the save), a backup of the previous save, and reading
## the save or, failing that, the backup. What a valid save is lives in
## save_schema.gd; Progression decides what goes in it.


## Writes `snapshot` to `path` if `valid` accepts it both before writing and
## as read back. Returns "" on success, else what went wrong.
static func write(path: String, snapshot: Dictionary, valid: Callable) -> String:
	if not valid.call(snapshot):
		return "Refused to write an invalid save."
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Could not write the save."
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	if not valid.call(JSON.parse_string(FileAccess.get_file_as_string(temporary))):
		return "The written save did not read back."
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	if DirAccess.rename_absolute(temporary, path) != OK:
		return "Could not replace the save."
	return ""


## The save at `path`, else its backup, brought up to date by `migrate` and
## accepted by `valid`: {"data": Dictionary, "backup": bool}, or {} if neither reads.
static func read(path: String, migrate: Callable, valid: Callable) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate)) if FileAccess.file_exists(candidate) else null
		parsed = migrate.call(parsed)
		if valid.call(parsed):
			return {"data": parsed, "backup": candidate != path}
	return {}
