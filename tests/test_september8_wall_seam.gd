extends GutTest

func test_photographed_inline_facades_share_one_full_height_timber_joint() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for turn in 4:
		var plan := SettlementFabricPlan.new(&"september8.wall-seam")
		plan.set_asset_visual_bounds(program.asset_visual_bounds)
		for recipe_id: StringName in [&"room.slim.base.orange",&"room.tower.upper.amber.e"]:
			plan.register_recipe(program.recipe(recipe_id))
		var left := FabricUnit.new(&"left",&"room.slim.base.orange",Vector3i(-4,4,1),2)
		left.suppressed_placement_ids.assign([&"north"])
		var right := FabricUnit.new(&"right",&"room.tower.upper.amber.e",Vector3i(-3,4,4),1)
		right.suppressed_placement_ids.assign([&"east",&"west"])
		for unit: FabricUnit in [left,right]:
			unit.lattice_origin=FabricRecipe.transform_cell(unit.lattice_origin,Vector3i.ZERO,turn)
			unit.yaw_quarters=posmod(unit.yaw_quarters+turn,4)
			plan.append_constructed_unit(unit)
		assert_true(plan.finish_construction())
		var hits := 0
		for placement: Dictionary in plan.expanded_placements():
			if not String(placement.stable_id).begins_with("facade-run-joint/"): continue
			var inverse := Transform3D(Basis(Vector3.UP,-turn*PI*0.5),Vector3.ZERO)
			var box: AABB = inverse*placement.bounds
			if absf(box.get_center().z-5.25)>0.01 or absf(box.end.x+3.75)>0.1: continue
			hits += 1
			assert_almost_eq(box.position.y,6.0,0.001)
			assert_almost_eq(box.end.y,9.0,0.001)
			assert_lte(box.end.x,-3.75+0.001,"the joint must remain behind the existing exterior envelope")
			var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
			var faces := PackedVector3Array()
			for piece: EnvironmentVisualPiece in visual.pieces:
				faces.append_array(inverse*placement.transform*piece.local_transform*piece.mesh.get_faces())
			for y in [6.2,6.8,7.6,8.7]:
				var closed := false
				for offset in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(Vector3(-3.5,y,5.25),Vector3(-4.5,y,5.25),faces[offset],faces[offset+1],faces[offset+2])!=null:
						closed=true
						break
				assert_true(closed,"the actual timber mesh closes the photographed seam")
		assert_eq(hits,1,"two abutting room panels declare one continuous join")
