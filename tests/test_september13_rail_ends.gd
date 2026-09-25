extends GutTest
var _fabric: SettlementFabricPlan
func _plan() -> SettlementFabricPlan:
	if _fabric == null:
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
		_fabric = frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/09-upper-wall/current-source.txt"),program).compiled_fabric_cache()
	return _fabric

func test_p40_garden_owns_a_level_guard_beside_the_descending_stair() -> void:
	var keys := {}
	for segment: Dictionary in _plan().surface_plan.guard_segments: keys[String(segment.stable_key)] = true
	for z in [6,7]:
		assert_true(keys.has("4:2:%d:-1:0" % z),"P40's raised garden must close its stair-side drop")
	for z in [4,5,6,7]:
		assert_true(keys.has("7:2:%d:1:0" % z),"The opposite roof-side boundary retains all its native guards")

func test_p40_no_diagonal_guard_projects_above_the_raised_garden() -> void:
	var fragments := 0
	for mesh: Dictionary in _plan().surface_plan.mesh_payloads:
		if String(mesh.get("stable_id","")) != "volume.transition.09.mesh": continue
		var vertices: PackedVector3Array = mesh.vertices
		for index in range(0,vertices.size(),4):
			var center := (vertices[index]+vertices[index+1]+vertices[index+2]+vertices[index+3])*.25
			if absf(center.x-5.25)<.12 and center.z>8.5 and center.z<11.15 and center.y>3.03:
				fragments += 1
	assert_eq(fragments,0,"The level garden guard owns this boundary; no clipped sloping rail sticks out over the lawn")

func test_stair_side_contacts_do_not_open_courts_in_any_orientation() -> void:
	for quarter in 4:
		var rotate := Basis(Vector3.UP,float(quarter)*PI*.5)
		var plan := PublicRealmSurfacePlan.new(&"rotated-stair")
		var run := Vector3i((rotate*Vector3.BACK).round())
		var side := Vector3i((rotate*Vector3.RIGHT).round())
		var cell := Vector3i.ZERO
		plan.add_claim(cell,PublicRealmSurfacePlan.SurfaceKind.STAIR,&"flight")
		plan.add_claim(cell+side,PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,&"court")
		plan._transition_claim_owners[PublicRealmSurfacePlan._cell_key(cell)] = &"flight"
		plan._transition_mesh_payloads.append({"stable_id":&"flight","run_direction":run})
		plan._classify_public_openings([
			{"from_cell":cell,"to_cell":cell+side},
			{"from_cell":cell,"to_cell":cell+side+Vector3i.UP},
			{"from_cell":cell,"to_cell":cell+run}])
		assert_false(plan._has_public_transition(cell+side,-side),"Rounded same-band occupancy is not a level side exit")
		assert_false(plan._has_public_transition(cell+side+Vector3i.UP,-side),"An abstract one-band seam cannot open the side of a flight")
		assert_true(plan._has_public_transition(cell+run,-run),"The longitudinal landing stays open")
