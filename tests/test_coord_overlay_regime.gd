extends GutTest

const Overlay := preload("res://scripts/terrain/tools/CoordOverlay.gd")

func test_regime_line_names_the_terrain_archetype_and_site() -> void:
	var line: String = Overlay.regime_line(2697992464, Vector3(2000, 0, -1500))
	var nearest: Dictionary = TerrainRegimeField.sample(2697992464, Vector2(2000, -1500))[0][0]
	assert_string_starts_with(line, "terrain ")
	assert_string_contains(line, String(nearest.archetype))
	assert_string_contains(line, "site %.0f, %.0f" % [nearest.site.x, nearest.site.y])
