extends GutTest

func test_embedded_frontage_rejects_only_the_complete_blocked_roof_run() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	mass.stable_id=&"kit.wall-room.fixture"
	var floor := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,2,2)),BuildingMass.MATERIAL_TIMBER)
	floor.pent_colour=&"red"
	var assembler := BuildingKitAssembler.new(kit)
	# The city cap carries construction above the room, while the street
	# remains outside its four walls. No free-standing pitched roof exists.
	assembler.external_blocked=func(cell:Vector2i,band:int)->bool:
		return band>=2 and floor.cells.has(cell)
	var pieces := assembler.assemble(mass)
	var hoods := pieces.filter(func(part:Dictionary)->bool:return String(part.role).begins_with("wallhood."))
	var ends := pieces.filter(func(part:Dictionary)->bool:return part.role in [&"wallhood.left",&"wallhood.right"])
	assert_eq(hoods.size(),12)
	assert_eq(ends.size(),0,"A closed perimeter uses four native corner connections instead of eight capped seams")
	var cap := EnvironmentCatalog.load_default().descriptor(hoods[0].asset_id).measured_aabb
	var pose: Transform3D = hoods[0].transform
	var box: AABB = pose*cap
	# Obstruct the middle of one native eave, away from corner joins.
	box = AABB(box.get_center()-Vector3.ONE*0.01,Vector3.ONE*0.02)
	var air: Array[Dictionary]=[preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").box_volume(box)]
	air[0]["open"]=true
	assembler.ornament_clear=func(id:StringName,at:Transform3D)->bool:
		return not preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd").intersects_air(
			EnvironmentCatalog.load_default().descriptor(id).measured_aabb,at,air)
	pieces=assembler.assemble(mass)
	var remaining := pieces.filter(func(part:Dictionary)->bool:return String(part.role).begins_with("wallhood."))
	assert_gt(remaining.size(),0,"Other clear faces retain their complete shed roofs")
	assert_lt(remaining.size(),12,"The blocked run is rejected")
	assert_eq(pieces.filter(func(part:Dictionary)->bool:return part.role in [&"wallhood.left",&"wallhood.right"]).size(),2,
		"Only the two new open ends need closed caps")
	for part: Dictionary in pieces:
		if String(part.role).begins_with("wallhood."):
			assert_true(assembler.ornament_clear.call(part.asset_id,part.transform))
	assert_gt(pieces.filter(func(part:Dictionary)->bool:return String(part.role).begins_with("wall.")).size(),0,
		"Refusing the optional hood never erases the inhabited wall")

func test_fully_blocked_shed_roofs_leave_the_inhabited_facade_intact() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	var floor := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,2,2)),BuildingMass.MATERIAL_TIMBER)
	floor.pent_colour=&"red"
	var assembler := BuildingKitAssembler.new(kit)
	assembler.external_blocked=func(cell:Vector2i,band:int)->bool:
		return band>=2 and floor.cells.has(cell)
	assembler.ornament_clear=func(_id:StringName,_pose:Transform3D)->bool:return false
	var pieces := assembler.assemble(mass)
	assert_eq(pieces.filter(func(part:Dictionary)->bool:return String(part.role).begins_with("wallhood.")).size(),0)
	assert_eq(pieces.filter(func(part:Dictionary)->bool:return part.role in [&"wallhood.left",&"wallhood.right"]).size(),0)
	assert_eq(pieces.filter(func(part:Dictionary)->bool:return String(part.role).begins_with("wall.")).size(),8)

func test_wall_hood_is_a_shallow_native_course_not_a_full_gable_slope() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	for role:StringName in [&"wallhood.middle",&"wallhood.left",&"wallhood.right"]:
		var box:AABB = catalog.descriptor(kit.asset(role)).measured_aabb
		assert_lt(box.end.y,0.2,"The hood must not climb into the structural cap above its attachment")
		assert_gt((kit.anchor(role)*box).position.y,-0.45,"Keep the native opening head below the shed roof")
		assert_lt((kit.anchor(role)*box).end.y,1.0,"The attachment must fit within the retained half-storey cap")
		assert_lt(box.size.z,1.2,"The shallow native cornice replaces the full three-metre gable strip")
		assert_true(kit.anchor(role).basis.is_equal_approx(Basis.IDENTITY),"Use authored geometry at native scale")

func test_generated_wall_hoods_clear_finished_public_routes() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := WarrenVolumetricSolver.generate(13,{},program,WarrenVillageScaleProfile.for_id(&"large"))
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial==null:return
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial,fabric,kit)
	var clearance := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
	var air := clearance.build(spatial,fabric,kit)
	var count := 0
	for part:Dictionary in built.placements:
		if not String(part.role).begins_with("wallhood."):continue
		count += 1
		assert_false(clearance.intersects_air(catalog.descriptor(part.asset_id).measured_aabb,part.transform,air),str(part.stable_id))
	assert_gt(count,0,"The shallow native hood must survive real-town admission, not just an isolated fixture")

func test_blocked_corner_keeps_both_complete_capped_frontages() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	var floor := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,3,2)),BuildingMass.MATERIAL_TIMBER)
	floor.pent_colour=&"blue"
	var assembler := BuildingKitAssembler.new(kit)
	assembler.external_blocked=func(cell:Vector2i,band:int)->bool:return band>=2 and floor.cells.has(cell)
	assembler.ornament_clear=func(id:StringName,_at:Transform3D)->bool:return not String(id).contains("outer_corner")
	var parts := assembler.assemble(mass)
	assert_eq(parts.filter(func(p:Dictionary)->bool:return p.role==&"wallhood.outer_corner").size(),0)
	assert_eq(parts.filter(func(p:Dictionary)->bool:return p.role in [&"wallhood.left",&"wallhood.right"]).size(),8)
	assert_eq(parts.filter(func(p:Dictionary)->bool:return String(p.role).begins_with("wallhood.")).size(),10)

func test_corner_rotation_is_owned_once_at_each_shared_convex_vertex() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	var floor := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(-3,-2,3,2)),BuildingMass.MATERIAL_TIMBER)
	floor.pent_colour=&"blue"
	var assembler := BuildingKitAssembler.new(kit)
	assembler.external_blocked=func(cell:Vector2i,band:int)->bool:return band>=2 and floor.cells.has(cell)
	var vertices := {}
	for part:Dictionary in assembler.assemble(mass):
		if part.role!=&"wallhood.outer_corner":continue
		var pose:Transform3D=part.transform
		var at:=Vector2(pose.origin.x,pose.origin.z)
		assert_false(vertices.has(at),"One native corner owns each vertex")
		vertices[at]=true
		assert_true(at.x in [-6.0,0.0] and at.y in [-4.0,0.0])
		assert_almost_eq(pose.origin.y,3.85,0.001,"Corners share the straight runs' source datum")
		var outward:=pose.basis*Vector3(-1,0,1)
		assert_true((at-Vector2(-3,-2)).dot(Vector2(outward.x,outward.z))>0,"The source quarter points outside the building")
	assert_eq(vertices.size(),4)

func test_native_inward_valley_reserves_its_run_instead_of_overlapping_full_bays() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	for rotation in 4:
		var cells := {}
		for x in 4:
			for z in 4:
				if x>=2 and z>=2:continue
				var cell := Vector2i(x,z)
				for turn in rotation:cell=Vector2i(-cell.y-1,cell.x)
				cells[cell]=true
		var mass := BuildingMass.new()
		var floor := mass.add_storey(0,cells,BuildingMass.MATERIAL_TIMBER)
		floor.pent_colour=&"blue"
		var assembler := BuildingKitAssembler.new(kit)
		assembler.external_blocked=func(cell:Vector2i,band:int)->bool:return band>=2 and cells.has(cell)
		var parts := assembler.assemble(mass)
		var valleys := parts.filter(func(p:Dictionary)->bool:return p.role==&"wallhood.inner_corner")
		var stubs := parts.filter(func(p:Dictionary)->bool:return p.role==&"wallhood.middle_half")
		assert_eq(valleys.size(),1,"The concave vertex has one native valley")
		assert_eq(stubs.size(),2,"Both faces give the valley its native 1.5m run")
		for stub:Dictionary in stubs:
			var box:AABB=catalog.descriptor(stub.asset_id).measured_aabb
			assert_almost_eq(box.size.x,0.5,0.001)
			assert_true((stub.transform as Transform3D).basis.get_scale().is_equal_approx(Vector3.ONE))
			var distance:float=(stub.transform as Transform3D).origin.distance_to((valleys[0].transform as Transform3D).origin)
			assert_almost_eq(distance,1.75,0.001,"Short strips begin at the source valley's 1.5m seam")

func test_inward_corner_keeps_tiles_and_timber_without_upright_transition_sheet() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var visual := load(catalog.descriptor(&"pure_village.wall_hood.inner_corner").visual_path) as EnvironmentVisual
	var source:Node3D=load("res://assets/PureVillage/Models/Architecture/Roof_Bottom_InCorner_5x5_1.glb").instantiate()
	var original := {}
	for node:MeshInstance3D in source.find_children("*","MeshInstance3D"):
		for i in node.mesh.get_surface_count():
			original[node.mesh.surface_get_material(i).resource_name]=node.mesh.surface_get_arrays(i)
	var retained := {}
	for piece:EnvironmentVisualPiece in visual.pieces:
		for i in piece.mesh.get_surface_count():
			var name := piece.mesh.surface_get_material(i).resource_name
			assert_ne(name,"RoofTransition_1","The native vertical transition sheet must not protrude above the valley")
			retained[name]=true
			assert_eq(piece.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX],original[name][Mesh.ARRAY_VERTEX],"Keep authored valley geometry")
			assert_eq(piece.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX],original[name][Mesh.ARRAY_INDEX],"Keep authored valley topology")
	assert_true(retained.has("RoofTiles"))
	assert_true(retained.has("Planks_Full"))
	source.free()

func test_connected_canopy_shares_projection_clearance_height_only_with_its_own_course() -> void:
	var slots := {}
	for slot:Dictionary in BuildingKitAssembler.wall_slots(BuildingMass.rect_cells(Rect2i(0,0,3,3)),false):
		slots[slot.centre]=slot
		if slot.dir==1:slot.wall_offset=0.25
	for slot:Dictionary in BuildingKitAssembler.wall_slots(BuildingMass.rect_cells(Rect2i(8,0,3,3)),false):
		slots[slot.centre]=slot
	var heights := BuildingKitAssembler._hood_attachment_heights(slots,3.0)
	for centre:Vector2 in slots:
		assert_almost_eq(heights[centre],3.35 if centre.x<4 else 3.0,0.001,"Connected corners share a height; disconnected courses do not")
	var mass := BuildingMass.new()
	var assembler := BuildingKitAssembler.new(SuntailBuildingKit.create())
	var parts: Array[Dictionary] = []
	var context := {"mass":mass,"out":parts,"serial":0}
	assembler._emit_pent_eaves(context,slots,&"blue",3.0)
	assert_eq(parts.filter(func(p:Dictionary)->bool:return p.role==&"wallhood.outer_corner").size(),8,"Both courses retain all four connected hips")
	assert_eq(parts.filter(func(p:Dictionary)->bool:return p.role in [&"wallhood.left",&"wallhood.right"]).size(),0,"A raised face cannot strand caps at its corners")
