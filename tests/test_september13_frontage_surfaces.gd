extends GutTest

func test_photographed_barrel_does_not_pierce_public_ramp() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/09-upper-wall/current-source.txt"),program)
	var payload := SettlementFabricAssembler.payload(spatial.compiled_fabric_cache())
	payload.append_from(SettlementFabricAssembler.structural_support_payload(spatial.compiled_fabric_cache()))
	var found := false
	for asset: StringName in payload.batches:
		for id: StringName in payload.batches[asset].ids:
			found = found or id == &"maze-frontage/-7/0/-2/1"
	assert_false(found,"Optional frontage must not grow through P36's public ramp; do not lift it onto the path")

func test_frontage_uses_actual_sloping_surface_in_all_directions() -> void:
	# Nominal upper-floor ownership is above this one-cell barrel. The actual
	# sloping triangles cross its body. A high bridge and a triangle whose AABB
	# overlaps but whose surface misses are negative controls.
	var site := {"cells":[Vector3i.ZERO],"direction":Vector3i.FORWARD,"band":0,
		"asset":&"lpfv.fabric.prop.barrel.01","offsets":Vector2.ZERO}
	var faces := PackedVector3Array([Vector3(-2,.3,-.8),Vector3(2,.3,-.8),Vector3(2,1.5,-2),
		Vector3(-2,.3,-.8),Vector3(2,1.5,-2),Vector3(-2,1.5,-2)])
	for side in 4:
		var turn := Basis(Vector3.UP,side*PI/2)
		site.direction = Vector3i((turn*Vector3.FORWARD).round())
		var rotated := PackedVector3Array()
		var high := PackedVector3Array()
		for vertex: Vector3 in faces:
			rotated.append(turn*vertex)
			high.append(turn*vertex+Vector3.UP*3)
		assert_false(SettlementFabricAssembler._frontage_site_clears_modules(site,{"public_surfaces":[_surface(rotated)]}),"Intersecting ramp, direction %d"%side)
		assert_true(SettlementFabricAssembler._frontage_site_clears_modules(site,{"public_surfaces":[_surface(high)]}),"Retain real headroom under a high bridge")

func _surface(faces: PackedVector3Array) -> Dictionary:
	var bounds := AABB(faces[0],Vector3.ZERO)
	for vertex: Vector3 in faces: bounds = bounds.expand(vertex)
	return {"bounds":bounds,"faces":faces}

func test_surface_intersection_keeps_contact_and_empty_triangle_corners() -> void:
	var triangle := PackedVector3Array([Vector3(0,.5,0),Vector3(4,.5,0),Vector3(0,.5,4)])
	var footprints := {"public_surfaces":[_surface(triangle)]}
	assert_true(SettlementFabricAssembler._box_clears_public_surfaces(AABB(Vector3(3,0,3),Vector3.ONE),footprints),"Empty corner inside the triangle's bounding box is still free")
	assert_false(SettlementFabricAssembler._box_clears_public_surfaces(AABB(Vector3(.5,0,.5),Vector3.ONE),footprints),"Crossing a flat public floor is forbidden too")
	assert_true(SettlementFabricAssembler._box_clears_public_surfaces(AABB(Vector3(.5,.5,.5),Vector3.ONE),footprints),"A prop may sit on its supporting floor")
	assert_true(SettlementFabricAssembler._box_clears_public_surfaces(AABB(Vector3(.5,-.5,.5),Vector3.ONE),footprints),"A prop may touch the underside without crossing it")
	var sliver := PackedVector3Array([Vector3(-2,.2,0),Vector3(2,.8,0),Vector3(0,.5,2)])
	assert_false(SettlementFabricAssembler._box_clears_public_surfaces(AABB(Vector3(-.1,0,-.1),Vector3(.2,1,.2)),{"public_surfaces":[_surface(sliver)]}),"A thin crossing cannot depend on sampled cell centers")

func test_surface_assignment_refreshes_previously_requested_footprints() -> void:
	var plan := SettlementFabricPlan.new(&"surface-cache")
	assert_true((plan.module_footprints().public_surfaces as Array).is_empty())
	var surface := PublicRealmSurfacePlan.new(&"court")
	assert_true(surface.add_claim(Vector3i.ZERO,PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,&"court"))
	assert_true(surface.seal())
	assert_true(plan.set_surface_plan(surface))
	assert_false((plan.module_footprints().public_surfaces as Array).is_empty(),"A prior footprint query must not hide subsequently sealed public geometry")
