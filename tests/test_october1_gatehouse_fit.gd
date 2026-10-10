extends GutTest
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

func test_gate_frame_meets_carried_room_in_all_directions() -> void:
	var kit := SuntailBuildingKit.create()
	var assembler := BuildingKitAssembler.new(kit)
	var catalog := EnvironmentCatalog.load_default()
	for dir in 4:
		var edge := Vector3i(0,0,dir)
		assert_eq(assembler.gate_top(edge,0),BuildingKitAssembler.FORT_GATE_RISE)
		assembler.overhead_solids = [UNION.box_volume(AABB(Vector3(-10,3,-10),Vector3(20,3,20)))]
		assert_eq(assembler.gate_top(edge,0),3.0)
		var mass := BuildingMass.new()
		mass.stable_id = &"gatehouse"
		var ctx := {"mass":mass,"out":[],"serial":0}
		assembler._emit_gate(ctx,edge,0)
		assert_gt(ctx.out.size(),8,"complete supporting piers and header remain")
		for part: Dictionary in ctx.out:
			var box: AABB = part.transform*catalog.descriptor(part.asset_id).measured_aabb
			assert_lte(box.end.y,3.1,"no merlon or lintel reaches the room windows")
			var basis: Basis = part.transform.basis
			if basis.z.length()>5.0:
				assert_almost_eq(basis.x.length(),basis.y.length(),0.001,"header masonry keeps its native face aspect ratio")
		assembler.overhead_solids.clear()

func test_low_room_does_not_force_a_lintel_into_walking_headroom() -> void:
	var assembler := BuildingKitAssembler.new(SuntailBuildingKit.create())
	assembler.overhead_solids = [UNION.box_volume(AABB(Vector3(-10,1.5,-10),Vector3(20,3,20)))]
	var ctx := {"mass":BuildingMass.new(),"out":[],"serial":0}
	assembler._emit_gate(ctx,Vector3i.ZERO,0)
	assert_true(ctx.out.is_empty(),"the existing room bears its own header when a full stone frame cannot fit")

func test_tall_pier_uses_complete_unstretched_masonry_courses() -> void:
	var assembler := BuildingKitAssembler.new(SuntailBuildingKit.create())
	var ctx := {"mass":BuildingMass.new(),"out":[],"serial":0}
	assembler._emit_pier(ctx,Vector2.ZERO,0.0,10.5,1.3,false)
	var side_courses := []
	for part: Dictionary in ctx.out:
		var pose: Transform3D = part.transform
		if part.role != &"wall.fort": continue # the native closed cap is a different asset
		assert_lte(pose.basis.y.length(),1.0,"masonry never stretches beyond authored height")
		if pose.basis.z.z>0.9: side_courses.append(pose.origin.y)
	assert_eq(side_courses,[0.0,2.625,5.25,7.875],"equal full courses meet without a short top sliver")
	assert_eq(ctx.out.size(),17,"four complete sides per course and one closing cap")
