extends GutTest

const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func test_finished_skywalk_landings_have_no_wall_canopy_obstruction() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var source := frozen.read("res://tests/fixtures/october5-skywalk-hood-source.txt")
	var spatial := frozen.spatial(source, SettlementFabricProgram.compile(catalog))
	assert_not_null(spatial)
	if spatial == null:
		return
	var fabric := spatial.compiled_fabric_cache()
	var kit := SuntailBuildingKit.create()
	var spans := SettlementFabricAssembler.maze_skywalk_spans(fabric)
	assert_false(spans.is_empty(), "Exercise a finished crossing, including its abutments")
	var air: Array[Dictionary] = []
	for span: Dictionary in spans:
		for step in range(int(span.gap) + 2):
			var cell: Vector3i = span.cell + span.step * step
			var width := int(span.get("width", 1))
			for lane in width:
				var at := (
					cell
					+ (span.get("cross", Vector3i(span.step.z, 0, span.step.x)) as Vector3i) * lane
				)
				var volume := UNION.box_volume(
					AABB(
						Vector3(
							at.x * kit.module_width,
							at.y * kit.band_height(),
							at.z * kit.module_width
						),
						Vector3(
							kit.module_width,
							kit.storey_height if bool(span.get("enclosed", false)) else TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.VERTICAL_SCALE,
							kit.module_width
						)
					)
				)
				volume.open = true
				air.append(volume)
	var built := KitVillageBuildings.build(spatial, fabric, kit)
	var obstructions := []
	for part: Dictionary in built.placements:
		if not String(part.role).begins_with("wallhood."):
			continue
		if CLEARANCE.intersects_air(
			catalog.descriptor(part.asset_id).measured_aabb, part.transform, air
		):
			obstructions.append(part.stable_id)
	assert_eq(
		obstructions, [], "Keep complete canopy runs out of late skywalks: %s" % [obstructions]
	)
