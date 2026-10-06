extends GutTest

## The persisted water cache is keyed on PlanningDiskCache.KEY_SOURCES only
## (October 5: keying on every script made any edit cost a ~20 minute cold
## startup). The key must still cover everything the cached value is computed
## from: every script those sources reference (by class_name or res:// path,
## comments ignored) is in the key, or listed here as not affecting it.

const DISK_CACHE := preload("res://scripts/terrain/field/PlanningDiskCache.gd")
## Referenced, but not by the cached fill: the cliff sheet's native kernels
## (NativeGridKernels names the GDScript it mirrors), the water mesh's biome
## tint (WaterSkin), and what PathProgram / TerrainChunkMesher pull in beyond
## the constants water reads from them.
const NOT_IN_KEY := [
	"res://scripts/terrain/field/CliffSlopeEnvelope.gd",
	"res://scripts/terrain/biome/BiomeRegistry.gd",
]
const CONSTANTS_ONLY := [
	"res://scripts/terrain/features/PathProgram.gd",
	"res://scripts/terrain/field/TerrainChunkMesher.gd",
]

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
	assert_true(files.has("res://scripts/terrain/heightfield/TerrainField.gd"))
