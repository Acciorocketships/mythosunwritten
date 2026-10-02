extends GutTest

func test_terminal_lake_cannot_raise_an_excavated_river() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	# Re-pinned (terrain regimes, 2026-10-02): the four named districts no
	# longer fire, so check the first rivers of the central 5x5 window.
	var checked := 0
	var sources: Array[Vector2i] = []
	for z in range(-2, 3):
		for x in range(-2, 3):
			if sources.size() < 4 and water.has_source(Vector2i(x, z)):
				sources.append(Vector2i(x, z))
	for source in sources:
		checked += 1
		var river := water.river_for(source, 0)
		var target := river.beds[-1] + WaterField.SURFACE_RIDE
		assert_lte(river.pond.surface_y(), target + 0.0001,
			"a high natural terminal basin must not lift kilometres of already-descended water")
		var levels: PackedFloat32Array = WaterField.profile(river).levels
		for i in river.beds.size():
			assert_lte(levels[i], river.beds[i] + WaterField.SURFACE_RIDE + 0.0001)
		assert_almost_eq(river.pond.bed_y(), river.pond.surface_y() + PondStamp.SURFACE_DROP - river.pond.depth, 0.0001,
			"the terrain carve follows the same lowered lake datum")
	assert_gte(checked, 3, "the datum rule is exercised on several real rivers")

func test_standalone_pool_retains_storey_aligned_datum() -> void:
	var pond := PondStamp.new(Vector2.ZERO, 40, 7, 4, 3.5)
	assert_eq(pond.surface_y(), 15.0)
	assert_eq(pond.bed_y(), 12.5)
