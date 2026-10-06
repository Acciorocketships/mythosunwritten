extends RefCounted

## On-disk cache of pure planning results for one world seed, so a relaunch
## of the same (pinned) seed skips the minutes of cold hydraulic solves.
## Entries live in user://plan_cache/<seed>/<code hash>/; the hash covers the
## scripts a cached value is computed from (KEY_SOURCES), so a change to them
## starts a fresh directory (older ones for the seed are deleted). It once
## covered every script, and any edit to towns, biomes or the streamer threw
## away all solved water: a ~20 minute cold startup after nearly every change
## (October 5). test_planning_cache_key keeps KEY_SOURCES closed over what
## those scripts reference. Values are plain data
## (var_to_bytes, no objects) and round-trip exactly, so a cached result is
## the very result a fresh solve returns. No class_name: preload it.
##
## configure(seed) is called once by FieldTerrainStreamer._ready (main
## thread). Until then, and for any other seed, nothing is read or written:
## tests and harnesses always solve fresh.

const ROOT := "user://plan_cache"
## What the cached block water (WaterFieldContext over a natural heightfield
## region) is a function of: directories (every .gd/.cs inside, recursively)
## and single files. PathProgram and TerrainChunkMesher are read for constants.
const KEY_SOURCES: Array[String] = [
	"res://scripts/core/Helper.gd",
	"res://scripts/core/PriorityQueue.gd",
	"res://scripts/native",
	"res://scripts/terrain/heightfield",
	"res://scripts/terrain/water/WaterPlan.gd",
	"res://scripts/terrain/water/WaterField.gd",
	"res://scripts/terrain/water/WaterFieldContext.gd",
	"res://scripts/terrain/water/WaterContour.gd",
	"res://scripts/terrain/water/PondStamp.gd",
	"res://scripts/terrain/water/RiverTrace.gd",
	"res://scripts/terrain/water/WaterGroundSnapshot.gd",
	"res://scripts/terrain/TerrainWorldTuning.gd",
	"res://scripts/terrain/tools/SlopeProfile.gd",
	"res://scripts/terrain/field/TerrainTileField.gd",
	"res://scripts/terrain/field/TerrainGradePatch.gd",
	"res://scripts/terrain/field/NativeTerrainGrade.gd",
	"res://scripts/terrain/field/WorldFieldBlockCache.gd",
	"res://scripts/terrain/field/PlanningDiskCache.gd",
	"res://scripts/terrain/field/TerrainChunkMesher.gd",
	"res://scripts/terrain/features/PathProgram.gd",
]

static var _seed := 0
static var _dir := ""
static var hits := 0
static var misses := 0
static var writes := 0


static func configure(seed: int) -> void:
	var digest := _code_hash()
	if digest.is_empty():
		return
	var seed_dir := "%s/%d" % [ROOT, seed]
	DirAccess.make_dir_recursive_absolute(seed_dir + "/" + digest)
	# Keep only the current code's entries for this seed.
	for old: String in DirAccess.get_directories_at(seed_dir):
		if old != digest:
			_remove_tree(seed_dir + "/" + old)
	_dir = seed_dir + "/" + digest
	_seed = seed


static func active_for(seed: int) -> bool:
	return not _dir.is_empty() and seed == _seed


## The stored value for `key`, or null. Thread-safe (plain file reads).
static func load_entry(key: String) -> Variant:
	var path := "%s/%s.bin" % [_dir, key]
	if not FileAccess.file_exists(path):
		misses += 1
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		misses += 1
		return null
	hits += 1
	return bytes_to_var(bytes)


## Stores `value` if it is plain data that round-trips exactly. Writes go to
## a temporary file first, then rename, so a reader never sees half a file.
static func store_entry(key: String, value: Variant) -> void:
	var bytes := var_to_bytes(value)
	if bytes.is_empty() or bytes_to_var(bytes) != value:
		return
	var path := "%s/%s.bin" % [_dir, key]
	var temp := "%s.%d.tmp" % [path, OS.get_thread_caller_id()]
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()
	DirAccess.rename_absolute(temp, path)
	writes += 1


static func _code_hash() -> String:
	var files := key_files()
	if files.is_empty():
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path: String in files:
		ctx.update(path.to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode().left(20)


## Every script file KEY_SOURCES names, sorted.
static func key_files() -> Array[String]:
	var files: Array[String] = []
	for source: String in KEY_SOURCES:
		if source.ends_with(".gd") or source.ends_with(".cs"):
			files.append(source)
		else:
			_collect(source, files)
	files.sort()
	return files


static func _collect(dir: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") or file.ends_with(".cs"):
			out.append(dir + "/" + file)
	for sub: String in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + sub, out)


static func _remove_tree(dir: String) -> void:
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_tree(dir + "/" + sub)
	DirAccess.remove_absolute(dir)
