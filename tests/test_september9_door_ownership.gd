extends GutTest
const Compiler = preload("res://scripts/terrain/features/villages/fabric/WarrenSpatialFabricCompiler.gd")
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")
var program: SettlementFabricProgram

func before_all() -> void:
	program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())

func _row(turns: int, partial: bool = false, gap: int = 0, raised: bool = false) -> Dictionary:
	var grid := WarrenSpatialGrid.new(Vector3i(-16,-2,-16),Vector3i(32,10,32))
	var rooms: Array[WarrenRoomStamp] = []
	var occupied := {}
	var tx := grid.begin_transaction(&"row")
	for index in 3:
		var origin := FabricRecipe.transform_direction(Vector3i(index*(2+gap),1 if raised and index==2 else 0,0),turns)
		var id := StringName("room%d" % index)
		var room := WarrenRoomStamp.new(id,id,&"tower",origin,turns,0,true,true,
			origin,FabricRecipe.transform_direction(Vector3i.BACK,turns))
		var cells := WarrenRoomStamp.expected_private_cells(&"tower",origin,turns)
		assert_true(room.add_private_cells(cells))
		assert_true(tx.assign_use(cells,WarrenSpatialGrid.Use.PRIVATE_VOLUME,id))
		rooms.append(room)
		for cell: Vector3i in cells: occupied[cell] = index
	assert_true(tx.commit())
	tx = grid.begin_transaction(&"seams")
	for cell: Vector3i in occupied:
		for direction: Vector3i in [Vector3i.RIGHT,Vector3i.BACK]:
			var beside := cell+direction
			if not occupied.has(beside) or occupied[beside]==occupied[cell]: continue
			# Leave the upper band of the first shared wall closed. A partial
			# private contact must not turn into shared entrance access.
			if partial and mini(occupied[cell],occupied[beside])==0 and cell.y==1: continue
			assert_true(tx.claim_face(cell,direction,WarrenSpatialGrid.FaceKind.PARTY_WALL,&"shared"))
	assert_true(tx.commit())
	var source := WarrenSpatialPlan.new(&"row",42,grid)
	return {"source":source,"rooms":rooms}

func test_connected_native_party_openings_share_one_entry_in_four_orientations() -> void:
	for turns in 4:
		var row := _row(turns)
		var before: String = row.source.grid.deterministic_signature()
		var owners := Compiler.shared_facade_entrance_owners(row.source,program,row.rooms)
		assert_eq(owners.size(),3)
		for id: StringName in [&"room0",&"room1",&"room2"]: assert_eq(owners.get(id),&"room1")
		row.rooms.reverse()
		assert_eq(Compiler.shared_facade_entrance_owners(row.source,program,row.rooms),owners,
			"Entrance choice must not depend on room enumeration")
		assert_eq(row.source.grid.deterministic_signature(),before,"Ownership never changes private mass or public routes")

func test_partial_walls_gaps_and_staggered_floors_keep_separate_access() -> void:
	for turns in 4:
		for mode in 3:
			var row := _row(turns,mode==0,1 if mode==1 else 0,mode==2)
			var owners := Compiler.shared_facade_entrance_owners(row.source,program,row.rooms)
			if mode==1:
				assert_true(owners.is_empty(),"A gap cannot join neighboring buildings")
			else:
				assert_eq(owners.size(),2,"Only the two rooms with a complete level opening share access")
				assert_false(owners.has(&"room0" if mode==0 else &"room2"))

func test_photographed_frontage_keeps_its_central_door_and_corner_entrance() -> void:
	var source := Frozen.read("res://tests/fixtures/september9-east-source.txt")
	var spatial := Frozen.spatial(source,program)
	var plan := spatial.compiled_fabric_cache()
	var rooms: Array[WarrenRoomStamp] = []
	for building: WarrenBuildingVolume in spatial.buildings: rooms.append_array(building.room_records)
	var owners := Compiler.shared_facade_entrance_owners(spatial,program,rooms)
	var middle := &"spatial.parcel.maze.house.005.part00.room00"
	var left := &"spatial.parcel.maze.bridge.00.end.1.lower.part00.room00"
	var right := &"spatial.maze_back.01.room00"
	assert_eq(owners.get(left),middle)
	assert_eq(owners.get(right),middle)
	assert_eq(owners.get(middle),middle)
	assert_eq(owners.size(),3,"This photograph has one connected three-door facade")
	var entries := {}
	for entrance: Dictionary in plan.surface_plan.entrance_records:
		entries[String(entrance.unit_id).trim_prefix("spatial.fabric.")] = entrance
	assert_true(entries.has(middle))
	assert_false(entries.has(left))
	assert_false(entries.has(right))
	assert_true(entries.has("spatial.parcel.maze.house.013.part00.room00"),"Perpendicular face retains its entrance")
	assert_eq(entries.size(),12)
	for unit: FabricUnit in plan.units:
		var room_id := StringName(String(unit.stable_id).trim_prefix("spatial.fabric."))
		if room_id not in [left,right]: continue
		assert_true(String(unit.recipe_id).ends_with(".closed"))
		assert_true(plan.recipe(unit.recipe_id).entrances.is_empty())

func test_replacement_window_closes_into_the_deep_door_reveal_in_four_orientations() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for turn in 4:
		var plan := SettlementFabricPlan.new(&"september9.door-return")
		plan.set_asset_visual_bounds(program.asset_visual_bounds)
		for id: StringName in [&"room.slim.base.orange.closed",&"room.slim.base.rock"]:
			plan.register_recipe(program.recipe(id))
		var left := FabricUnit.new(&"left",&"room.slim.base.orange.closed",Vector3i(-3,4,-4),0)
		left.suppressed_placement_ids.assign([&"east.0",&"east.1",&"west.0",&"west.1"])
		var right := FabricUnit.new(&"right",&"room.slim.base.rock",Vector3i(-1,4,-4),0)
		right.suppressed_placement_ids.assign([&"east.1",&"west.0",&"west.1"])
		for unit: FabricUnit in [left,right]:
			unit.lattice_origin = FabricRecipe.transform_cell(unit.lattice_origin,Vector3i.ZERO,turn)
			unit.yaw_quarters = turn
			plan.append_constructed_unit(unit)
		assert_true(plan.finish_construction())
		var count := 0
		for placement: Dictionary in plan.expanded_placements():
			if not String(placement.stable_id).begins_with("facade-run-joint/"): continue
			var inverse := Transform3D(Basis(Vector3.UP,-turn*PI*0.5),Vector3.ZERO)
			var box: AABB = inverse*placement.bounds
			if absf(box.get_center().x+3.75)>0.01 or absf(box.end.z+3.77)>0.01: continue
			count += 1
			assert_lte(box.end.z,-3.75,"Joint stays behind the unchanged facade plane")
			assert_lte(box.size.x,0.121,"The member must remain narrow")
			var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
			var faces := PackedVector3Array()
			for piece: EnvironmentVisualPiece in visual.pieces:
				faces.append_array(inverse*placement.transform*piece.local_transform*piece.mesh.get_faces())
			for y in [6.2,6.8,7.6,8.7]:
				for z in [-3.8,-4.0,-4.3,-4.6,-4.85]:
					var closed := false
					for index in range(0,faces.size(),3):
						if Geometry3D.segment_intersects_triangle(Vector3(-4,y,z),Vector3(-3.5,y,z),faces[index],faces[index+1],faces[index+2])!=null:
							closed = true
							break
					assert_true(closed,"Actual timber closes the entire return, not only its front edge")
		assert_eq(count,1)
