extends GutTest
const COURT := preload("res://scripts/terrain/features/villages/TownCourtTrees.gd")

func _tree() -> Dictionary:
	return {"asset":&"lpfv.tree.01","cell":Vector3i.ZERO,"origin":Vector3(.75,1.505+.036251962*.45,.75),
		"quarter":0,"scale":.45,"street_canopy":true,
		"cells":{Vector3i.ZERO:true,Vector3i.RIGHT:true,Vector3i.BACK:true,Vector3i(1,0,1):true}}

func _floor(y: float) -> Dictionary:
	var points := PackedVector3Array([Vector3(2.3,y,0),Vector3(3.8,y,0),Vector3(3.8,y,1.5),
		Vector3(2.3,y,0),Vector3(3.8,y,1.5),Vector3(2.3,y,1.5)])
	return {"faces":points,"bounds":AABB(Vector3(2.3,y,0),Vector3(1.5,0,1.5))}

func test_asymmetric_crown_rotates_before_losing_height() -> void:
	var tree := _tree()
	# A neighbouring eave catches only the long side of this authored crown.
	var eave := AABB(Vector3(.5,6.1,3.7),Vector3(.5,.3,.3))
	var footprints := {"boxes":[eave],"public_surfaces":[_floor(1.505)]}
	assert_false(COURT.clear(tree,footprints,[]))
	var fitted := COURT.fit_rotation(tree,footprints,[])
	assert_false(fitted.is_empty())
	if fitted.is_empty(): return
	assert_eq(fitted.quarter,1)
	assert_eq(fitted.scale,tree.scale,"Keep the complete mature tree")
	assert_eq(fitted.origin,tree.origin,"Roots stay on the same planting island")
	assert_eq(tree.quarter,0,"Searching does not mutate the caller's candidate")
	assert_true(COURT.clear(fitted,footprints,[]),"Rotated branches still clear actual walking headroom")
	assert_eq(COURT.fit_rotation(fitted,footprints,[]),fitted,"An already safe yaw remains stable")
	assert_eq(COURT.fit_rotation(tree,{},[]),tree,"Unobstructed seeded placement is unchanged")
	assert_true(COURT.fit_rotation(tree,{"boxes":[AABB(Vector3(-5,5,-5),Vector3(10,5,10))]},[]).is_empty(),
		"No rotation permits a tree inside a neighbouring building")

func test_crown_can_cover_a_street_but_never_its_headroom_or_a_neighbour() -> void:
	var tree := _tree()
	var footprints := {"public_surfaces":[_floor(1.505)]}
	assert_true(COURT.clear(tree,footprints,[]),"A measured crown may shelter the ground-level walk")
	assert_false(COURT.clear(tree,{"public_surfaces":[_floor(2.505)]},[]),
		"The same branches obstruct a higher walk and must be rejected")
	var crown: AABB = COURT.bands(tree)[5]
	assert_false(COURT.clear(tree,{"boxes":[crown]},[]),"No canopy enters a neighbouring roof or room")
	tree.cells.erase(Vector3i.ZERO)
	assert_false(COURT.clear(tree,{},[]),"The whole trunk needs a supported planting island")

func test_native_court_tree_shades_the_walk_without_colliding_with_it() -> void:
	for seed_value in [13,43,8,9]:
		_check_native_court(seed_value)

func _check_native_court(seed_value: int) -> void:
	var catalog := EnvironmentCatalog.load_default()
	var spatial := WarrenVolumetricSolver.generate(seed_value,{},SettlementFabricProgram.compile(catalog),WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial,"seed %d: %s" % [seed_value,WarrenVolumetricSolver.last_failure])
	if spatial==null: return
	var fabric := spatial.compiled_fabric_cache()
	var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	var feature := SettlementFabricAssembler.maze_plaza_centre_feature(fabric.planned_plaza_cells,
		SettlementFabricAssembler.maze_plaza_entries(fabric.planned_plaza_cells,transaction.walked),transaction.footprints,
		SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),transaction.walked,true,1)
	assert_false(feature.is_empty(),"seed %d has no preliminary court tree" % seed_value)
	if feature.is_empty(): return
	# Validate the emitted tree after the final native roof-clearance pass.
	# Preliminary module bounds can admit a taller crown than finished roofs.
	var payload := preload("res://tests/harness/suntail/kit_town_review.gd").town_payload(spatial,fabric,false)
	var emitted := false
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for i in batch.ids.size():
			if not String(batch.ids[i]).begins_with("maze-plaza-centre/"): continue
			emitted = true
			var actual: Transform3D = batch.transforms[i]
			feature.asset = asset
			feature.origin = actual.origin
			feature.scale = actual.basis.y.length()
			feature.quarter = posmod(roundi(atan2(actual.basis.z.x,actual.basis.z.z)/(PI*.5)),4)
	assert_true(emitted,"The native build must actually emit the courtyard tree")
	if not emitted: return
	var bands := COURT.bands(feature)
	var shaded := 0
	var headroom := TraversalEnvelope.MIN_HEADROOM/VillageWorldScale.VERTICAL_SCALE
	for claim: Dictionary in fabric.surface_plan._claims.values():
		var cell: Vector3i = claim.cell
		var body := AABB(Vector3(cell)*1.5-Vector3(.75,0,.75),Vector3(1.5,headroom,1.5))
		for band: AABB in bands:
			assert_false(SettlementFabricAssembler._boxes_share_volume(body,band),"Actual low branches stay out of walking headroom")
			var shadow := band
			shadow.position.y = body.position.y
			shadow.size.y = headroom
			shaded += int(band.position.y>=body.end.y and shadow.intersects(body))
	assert_gt(shaded,0,"The crown reaches over streets rather than being squeezed inside the tiny bed")
	var pose := Transform3D(Basis(Vector3.UP,float(feature.quarter)*PI*.5).scaled(Vector3.ONE*float(feature.scale)),feature.origin)
	var visual := load(catalog.descriptor(feature.asset).visual_path) as EnvironmentVisual
	assert_not_null(visual)
	for collider: EnvironmentCollisionPiece in visual.collisions:
		var box: AABB = pose*collider.local_transform*collider.shape.get_debug_mesh().get_aabb()
		for claim: Dictionary in fabric.surface_plan._claims.values():
			var body := AABB(Vector3(claim.cell)*1.5-Vector3(.75,0,.75),Vector3(1.5,headroom,1.5))
			assert_false(SettlementFabricAssembler._boxes_share_volume(body,box),"The baked trunk collider also clears the ring")

	var native := COURT.native_obstacles(payload,catalog)
	for band: AABB in bands:
		assert_true(SettlementFabricAssembler._box_clears_public_surfaces(band,
			{"public_surfaces":native.native_surfaces}),"Finished generated roofs clear the crown")

func test_generated_roof_triangles_exclude_canopy_without_filling_empty_roof_bounds() -> void:
	var tree := _tree()
	var roof := _floor(5.0)
	assert_false(COURT.clear(tree,{"native_surfaces":[roof]},[]),
		"Generated roof geometry is an obstacle even when it has no catalogue instance")
	# A sloping triangle can have a large box containing empty space. A remote
	# high corner must not turn that entire box into a solid roof obstacle.
	var points := PackedVector3Array([Vector3(-20,1,-20),Vector3(20,20,-20),Vector3(20,20,20)])
	var slope := {"faces":points,"bounds":AABB(Vector3(-20,1,-20),Vector3(40,19,40))}
	assert_true(COURT.clear(tree,{"native_surfaces":[slope]},[]),
		"A crown beneath the actual roof triangle remains available")

func test_notched_raised_court_keeps_a_native_tree_beside_its_house_door() -> void:
	_check_native_court(301)
