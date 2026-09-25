extends "res://tests/harness/september15_gut.gd"
func _init() -> void:
	# Isolated process: use the archived pre-topology entry point while keeping
	# current tests, assets and all unrelated working-tree changes identical.
	var region := load("res://scripts/terrain/heightfield/HeightfieldRegion.gd") as GDScript
	var text := FileAccess.get_file_as_string(region.resource_path)
	var old := FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/01-grass/HeightfieldRegion-pre-topology.gd.txt")
	var begin := "func with_terrain_grades("
	var end := "func without_terrain_grades("
	region.source_code=text.substr(0,text.find(begin))+old.substr(old.find(begin),old.find(end)-old.find(begin))+text.substr(text.find(end))
	assert(region.reload(true)==OK)
	super._init()
