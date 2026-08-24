class_name WarrenSolutionPinCache
extends RefCounted

## Persistent memo of the staged production search's outcome per settlement
## seed and scale. The staged search is deterministic but expensive (measured
## 12 s for a first-attempt seal and 250 s for an exhausted failure on the
## single terrain worker, which blocks all chunk streaming meanwhile). The pin
## is a hint, never authority: pinned solves rerun every composition, fabric,
## and production gate, and any failure falls back to the full search — so a
## stale entry can cost only time, never change what a settlement builds.
##
## SEARCHED MODES ONLY. The key is (salt, city seed, scale) and carries no
## generation mode, so an entry one pipeline wrote would be read by another as
## if it were about the same search. One-pass maze generation has a single
## deterministic carve per town, nothing to memo and no search to prove
## exhausted, so `VillageWarrenFabricSolver.solve` neither reads nor writes
## this cache in that mode; a third mode that does want a memo must put the
## mode in the key rather than repeat that hazard (task D2 report, 7.5).
##
## GENERATION_SALT must be bumped whenever generation logic changes meaningfully
## (new gates, carver changes, recipe changes). Success pins self-heal without
## it (the pinned re-solve fails and the search reruns), but FAILURE entries
## would otherwise suppress a settlement that new code could now seal.
const GENERATION_SALT := "2026-08-19a"
const DEFAULT_PATH := "user://warren_solution_pins.json"

static var _path := DEFAULT_PATH
static var _entries: Dictionary = {}
static var _loaded := false


static func pin_for(city_seed: int, scale_id: StringName) -> Dictionary:
	_ensure_loaded()
	return (_entries.get(_key(city_seed, scale_id), {}) as Dictionary) \
		.duplicate(true)


static func store_success(city_seed: int, scale_id: StringName,
		attempt: int, source_id: String, variant: int) -> void:
	_ensure_loaded()
	if attempt < 0 or source_id.is_empty() or variant < 0:
		return
	_entries[_key(city_seed, scale_id)] = {"attempt": attempt,
		"source_id": source_id, "variant": variant}
	_save()


static func store_failure(city_seed: int, scale_id: StringName) -> void:
	_ensure_loaded()
	_entries[_key(city_seed, scale_id)] = {"failed": true}
	_save()


static func store_progress(city_seed: int, scale_id: StringName,
		attempts_tried: int) -> void:
	## A time-budgeted search stopped before exhausting the deterministic
	## attempt rotation. Remember how far it got so the next visit resumes
	## instead of repeating the proven-failed prefix.
	_ensure_loaded()
	_entries[_key(city_seed, scale_id)] = {"attempts_tried": attempts_tried}
	_save()


static func override_path_for_tests(path: String) -> void:
	_path = DEFAULT_PATH if path.is_empty() else path
	_entries = {}
	_loaded = false


static func _key(city_seed: int, scale_id: StringName) -> String:
	return "%s/%d/%s" % [GENERATION_SALT, city_seed, String(scale_id)]


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_entries = {}
	if not FileAccess.file_exists(_path):
		return
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key_value: Variant in (parsed as Dictionary).keys():
			var entry: Variant = (parsed as Dictionary)[key_value]
			# Entries under an older generation salt are dead weight: drop
			# them on load so the file cannot grow without bound.
			if entry is Dictionary and String(key_value).begins_with(
					GENERATION_SALT + "/"):
				_entries[String(key_value)] = entry


static func _save() -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_entries))
