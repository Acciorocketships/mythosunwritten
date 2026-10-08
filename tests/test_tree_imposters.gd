extends GutTest

const BAKE := preload("res://tools/environment_bake/environment_bake.gd")

func test_visual_carries_an_optional_imposter() -> void:
	var visual := EnvironmentVisual.new()
	assert_null(visual.imposter)
	visual.imposter = EnvironmentImposter.new()
	assert_eq(visual.imposter.frames, 8)

func test_a_rebake_without_the_pass_keeps_the_baked_imposter() -> void:
	var dir := "user://imposter_carry_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/visual.tres"
	var old := EnvironmentVisual.new()
	old.imposter = EnvironmentImposter.new()
	old.imposter.frames = 6
	ResourceSaver.save(old, path)
	var fresh := EnvironmentVisual.new()
	BAKE._carry_imposter(path, fresh)
	assert_not_null(fresh.imposter, "a headless re-bake must not drop every imposter")
	assert_eq(fresh.imposter.frames, 6)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
