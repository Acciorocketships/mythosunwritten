extends GutTest
const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
const FIT := preload("res://scripts/terrain/features/villages/kit/KitRoofEaveFits.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

func test_low_landing_selects_complete_eave_without_headroom_clipping() -> void:
	var kit := PURE.roof_study()
	for axis in 2:
		var mass := BuildingMass.new()
		var wing := mass.add_roof(Rect2i(0,0,4,4),axis,4,&"red")
		wing.union_index = 0
		var landing := UNION.box_volume(AABB(Vector3(-2,4.525,-2),Vector3(2,1.2,2)))
		landing.open = true
		var before := UNION.prepare([wing],[landing],kit)
		var clipped := 0
		for p: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
			if String(p.role).contains(".eave") and not UNION.realize(p,before).is_empty(): clipped += 1
		assert_gt(clipped,0,"the authored curved corner genuinely crosses walking air")
		assert_eq(FIT.fit([wing],kit,{},[landing]),1)
		assert_eq(BuildingKitAssembler.tight_eave_sides(wing),2,"Only the negative-facing eave meets this corner landing")
		var after := UNION.prepare([wing],[landing],kit)
		var eaves := 0
		for p: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
			if not String(p.role).contains(".eave"): continue
			eaves += 1
			assert_true(UNION.realize(p,after).is_empty(),"the complete straight eave fits without clipping")
		assert_gt(eaves,4,"both full runs and corner caps remain")
		assert_eq(FIT.fit([wing],kit,{},[landing]),0,"fitting is idempotent")

func test_clear_roofs_and_solid_junctions_keep_the_native_cornice() -> void:
	var kit := PURE.roof_study()
	var mass := BuildingMass.new()
	var wing := mass.add_roof(Rect2i(0,0,4,4),0,4,&"red")
	var low := UNION.box_volume(AABB(Vector3(-2,0,-2),Vector3(2,1.2,2)))
	low.open = true
	assert_eq(FIT.fit([wing],kit,{},[low]),0)
	var solid := UNION.box_volume(AABB(Vector3(-2,4.525,-2),Vector3(2,1.2,2)))
	assert_eq(FIT.fit([wing],kit,{},[solid]),0,"a solid junction is a different roof union problem")
	assert_false(wing.has("tight_eave"))
	assert_eq(FIT.fit([wing],SuntailBuildingKit.create(),{},[low]),0)

func test_suntail_low_stair_uses_an_intact_straight_slope_and_matching_barge() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	var wing := mass.add_roof(Rect2i(0,0,3,2),0,2,&"blue")
	wing.union_index = 0
	var landing := UNION.box_volume(AABB(Vector3(0,1.525,-2),Vector3(6,1.2,2)))
	landing.open = true
	assert_eq(FIT.fit([wing],kit,{},[landing]),1)
	var ctx := UNION.prepare([wing],[landing],kit)
	var eaves := 0
	for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		if int(part.get("roof_side",-1))==1:
			assert_ne(part.role,&"trim.barge.eave","The obstructed side needs straight end trim.")
		if not String(part.role).contains(".eave"): continue
		eaves += 1
		if int(part.roof_side)==1:
			assert_eq(part.asset_id,&"suntail.roof.roof_1_blue")
		else:
			assert_true(part.role in [&"roof.blue.eave",&"trim.barge.eave"],"The clear facade keeps its native overhang and matching trim")
		assert_true(UNION.realize(part,ctx).is_empty(),"The complete slope clears the landing without surgery.")
	assert_gt(eaves,0)

func test_tight_corner_verge_retracts_as_a_complete_native_cap() -> void:
	var kit := PURE.roof_study()
	var mass := BuildingMass.new()
	var wing := mass.add_roof(Rect2i(-2,2,2,2),1,2,&"blue")
	wing.union_index = 0
	wing.tight_eave = true
	var landing := UNION.box_volume(AABB(Vector3(-6,3.025,2),Vector3(2,1.2,2)))
	landing.open = true
	var before := UNION.prepare([wing],[landing],kit)
	var clipped := 0
	for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		if String(part.role).contains(".eave") and not UNION.realize(part,before).is_empty(): clipped += 1
	assert_gt(clipped,0,"even the straight cap crosses the perpendicular landing at its verge")
	assert_eq(FIT.fit([wing],kit,{},[landing]),1)
	var after := UNION.prepare([wing],[landing],kit)
	var cap_count := 0
	for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		if not String(part.role).contains(".eave"): continue
		if String(part.role).ends_with(".start") or String(part.role).ends_with(".end"): cap_count += 1
		assert_true(UNION.realize(part,after).is_empty(),"native caps must fit whole, not be clipped")
	assert_eq(cap_count,4,"all four authored corner caps remain")
	assert_eq(FIT.fit([wing],kit,{},[landing]),0)

func test_positive_side_fit_preserves_opposite_native_eave_and_trim() -> void:
	var kit := PURE.roof_study()
	for axis in 2:
		var mass := BuildingMass.new()
		var wing := mass.add_roof(Rect2i(0,0,4,4),axis,4,&"red")
		wing.union_index = 0
		var landing := UNION.box_volume(AABB(Vector3(8,4.525,8),Vector3(2,1.2,2)))
		landing.open = true
		assert_eq(FIT.fit([wing],kit,{},[landing]),1)
		assert_eq(BuildingKitAssembler.tight_eave_sides(wing),1)
		var ctx := UNION.prepare([wing],[landing],kit)
		var intact := 0
		for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
			if not String(part.role).contains(".eave"):continue
			assert_true(UNION.realize(part,ctx).is_empty(),"Whole eave and trim clear the landing")
			if int(part.roof_side)==1:
				assert_false(String(part.role).contains("tight"))
				intact+=1
		assert_gt(intact,4,"Opposite full cornice and caps remain")
