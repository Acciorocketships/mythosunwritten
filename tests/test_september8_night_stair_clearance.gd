extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")
class FlatTerrain extends VillageTerrainView:
	func surface_y(_point: Vector2) -> float: return 0.0

func test_exterior_stair_approach_is_free_of_overhead_terrace_posts() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := Frozen.spatial(Frozen.read("res://tests/fixtures/september8-night-stair-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	for quarter in 4:
		var frame := Transform3D(Basis(Vector3.UP,quarter*PI*0.5).scaled(Vector3.ONE*2),Vector3.ZERO)
		var payload := EnvironmentInstancePayload.new()
		VillageWarrenFabricSolver._append_ground_supports(payload,FlatTerrain.new(),fabric,frame,VillageWarrenFabricSolver.terrain_contact_specs(spatial,fabric))
		var blocked: Array[String] = []
		var retained := 0
		var spec: Dictionary
		for contact: Dictionary in VillageWarrenFabricSolver.terrain_contact_specs(spatial,fabric):
			if contact.source_portal == Vector3i(0,1,3): spec=contact
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		var side := Vector3(spec.lateral)*float(geometry.half_width)
		var approach := AABB((geometry.inner_centre as Vector3)-side,Vector3.ZERO)
		approach=approach.expand((geometry.inner_centre as Vector3)+side).expand((geometry.outer_centre as Vector3)-side).expand((geometry.outer_centre as Vector3)+side)
		approach.size.y+=TraversalEnvelope.MIN_HEADROOM/2.0
		for asset: StringName in payload.asset_ids():
			var batch: Dictionary = payload.batches[asset]
			for i in batch.transforms.size():
				var box: AABB = batch.transforms[i]*catalog.descriptor(asset).measured_aabb
				if approach.intersects(box): blocked.append(str(batch.ids[i]))
				else: retained+=1
		assert_eq(blocked.size(),0,"Exterior stair/landing standing space blocked by "+str(blocked))
		assert_gt(retained,0,"Other terrace supports must remain")

func test_gate_checks_the_lower_landing_beyond_the_first_exterior_cell() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := Frozen.read("res://tests/fixtures/september8-night-stair-source.txt")
	var spatial := Frozen.spatial(source,program)
	for spec: Dictionary in VillageWarrenFabricSolver.terrain_contact_specs(spatial,spatial.compiled_fabric_cache()):
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		var portal: Vector3i = spec.source_portal
		var outward: Vector3i = spec.outward
		var reach := (geometry.outer_centre as Vector3).distance_to(geometry.inner_centre)
		for step in range(1,ceili(reach/WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M)+1):
			var column := Vector2i(portal.x+outward.x*step,portal.z+outward.z*step)
			assert_false(source.massif.has_column(column),"Gate lower landing re-enters the town at "+str(column))

func test_raised_gate_checks_full_run_in_all_directions_but_level_gate_needs_only_landing() -> void:
	for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		var columns: Dictionary = {Vector2i.ZERO:{"base":0,"top":4},direction*2:{"base":0,"top":4}}
		var massif := WarrenMassif.with_columns(17,columns,4)
		assert_false(WarrenPassageLatticeRules.exterior_approach_is_clear(massif,Vector3i.UP,direction),"Raised flight must not finish in the far bank")
		assert_true(WarrenPassageLatticeRules.exterior_approach_is_clear(massif,Vector3i.ZERO,direction),"Level half-macro landing fits in the clear first cell")
		columns.erase(direction*2)
		massif=WarrenMassif.with_columns(17,columns,4)
		assert_true(WarrenPassageLatticeRules.exterior_approach_is_clear(massif,Vector3i.UP,direction),"Complete open run remains a valid exit")
