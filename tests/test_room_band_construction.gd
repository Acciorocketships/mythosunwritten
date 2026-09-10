extends GutTest

const FrozenSource = preload("res://tests/fixtures/frozen_maze_source.gd")
static var _program: SettlementFabricProgram

func _check_source(seed_value: int, profile: String) -> void:
	if _program == null:
		_program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := FrozenSource.read("res://tests/fixtures/room-construction-%d-%s-source.txt" % [seed_value, profile])
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	var spatial := WarrenVolumetricSolver.from_volume(volume, -1, _program, false, true)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var fabric := WarrenSpatialFabricCompiler.generate(spatial, _program, true)
	assert_not_null(fabric, WarrenSpatialFabricCompiler.last_failure)
	if fabric == null: return
	assert_eq(WarrenSpatialFabricCompiler.validation_errors(fabric), PackedStringArray())

func test_paired_upper_rooms_keep_bearing_on_the_final_lower_floor() -> void:
	_check_source(3, "large")

func test_paired_projection_uses_the_final_parent_floorplate() -> void:
	_check_source(12, "grand")

func test_newly_exposed_lower_roof_is_owned_before_the_next_lineage() -> void:
	_check_source(1, "grand")
