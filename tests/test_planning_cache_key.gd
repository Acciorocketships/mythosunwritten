extends GutTest

## The persisted water cache is keyed on PlanningDiskCache.KEY_SOURCES only
## (October 5: keying on every script made any edit cost a ~20 minute cold
## startup). The key must still cover everything the cached value is computed
## from: every script those sources reference (by class_name or res:// path,
## comments ignored) is in the key, or listed here as not affecting it.

const DISK_CACHE := preload("res://scripts/terrain/field/PlanningDiskCache.gd")
## Referenced by native rendering ports, but not by the cached fill. Bank
## bounds use CliffSlopeEnvelope directly without art settings or surface nets.
const NOT_IN_KEY := [
	"res://scripts/terrain/field/CliffSlopeField.gd", # NativeCliffSolid reference; not used by water bounds
	"res://scripts/terrain/field/CliffRockStyle.gd", # bank bounds explicitly omit art/bedrock detail
	"res://scripts/terrain/biome/BiomeRegistry.gd",
]
const CONSTANTS_ONLY := [
	"res://scripts/terrain/features/PathProgram.gd",
	"res://scripts/terrain/field/TerrainChunkMesher.gd",
]

func test_cache_is_inactive_after_the_tile_mode_changes() -> void:
	var saved := [DISK_CACHE._dir, DISK_CACHE._seed, DISK_CACHE._mode, TerrainTileField.cliff_end, DISK_CACHE._source_support]
	DISK_CACHE._dir = "test-only-no-file-access"
	DISK_CACHE._seed = 71
	DISK_CACHE._mode = TerrainTileField.CliffEnd.E3
	DISK_CACHE._source_support = WaterField.SOURCE_SUPPORT
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E3
	assert_true(DISK_CACHE.active_for(71))
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.SHARED_PROFILE
	assert_false(DISK_CACHE.active_for(71), "a review mode must not reuse a fill from the old geometry")
	DISK_CACHE._dir = saved[0]; DISK_CACHE._seed = saved[1]; DISK_CACHE._mode = saved[2]
	TerrainTileField.cliff_end = saved[3]
	DISK_CACHE._source_support = saved[4]

func test_key_sources_are_closed_over_their_references() -> void:
	var classes := {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		classes[String(entry["class"])] = String(entry["path"])
	var keyed := {}
	for path: String in DISK_CACHE.key_files():
		keyed[path] = true
	var word := RegEx.create_from_string("\\b[A-Z]\\w+\\b")
	var res_path := RegEx.create_from_string("res://(scripts/[\\w/.]+\\.gd)")
	var missing: Array[String] = []
	for path: String in keyed:
		if not path.ends_with(".gd") or path in CONSTANTS_ONLY:
			continue
		var code := ""
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			code += line.get_slice("#", 0) + "\n"
		var referenced := {}
		for m: RegExMatch in word.search_all(code):
			if classes.has(m.get_string()):
				referenced[classes[m.get_string()]] = true
		for m: RegExMatch in res_path.search_all(code):
			referenced["res://" + m.get_string(1)] = true
		for target: String in referenced:
			if not keyed.has(target) and not target in NOT_IN_KEY:
				missing.append("%s -> %s" % [path, target])
	assert_eq(missing, [] as Array[String],
		"add these to PlanningDiskCache.KEY_SOURCES (or to NOT_IN_KEY with a reason)")

func test_key_excludes_towns_and_the_streamer() -> void:
	var files := DISK_CACHE.key_files()
	assert_false(files.has("res://scripts/terrain/field/FieldTerrainStreamer.gd"))
	assert_false(files.has("res://scripts/terrain/biome/BiomeRegistry.gd"))
	for path: String in files:
		assert_false(path.begins_with("res://scripts/terrain/features/villages/"), path)
	assert_true(files.has("res://scripts/terrain/water/WaterField.gd"))
	assert_true(files.has("res://scripts/terrain/water/WaterBankBound.gd"))
	assert_true(files.has("res://scripts/terrain/field/CliffSlopeEnvelope.gd"))
	assert_true(files.has("res://scripts/terrain/heightfield/TerrainField.gd"))


func test_cache_is_inactive_after_source_support_mode_changes() -> void:
	var saved := [DISK_CACHE._dir, DISK_CACHE._seed, DISK_CACHE._mode,
		DISK_CACHE._source_support, WaterField.SOURCE_SUPPORT]
	DISK_CACHE._dir = "test-only-no-file-access"
	DISK_CACHE._seed = 71
	DISK_CACHE._mode = TerrainTileField.cliff_end
	DISK_CACHE._source_support = false
	WaterField.SOURCE_SUPPORT = false
	assert_true(DISK_CACHE.active_for(71))
	WaterField.SOURCE_SUPPORT = true
	assert_false(DISK_CACHE.active_for(71), "the review rule must not reuse the default fill")
	DISK_CACHE._dir = saved[0]; DISK_CACHE._seed = saved[1]; DISK_CACHE._mode = saved[2]
	DISK_CACHE._source_support = saved[3]; WaterField.SOURCE_SUPPORT = saved[4]
