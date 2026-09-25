extends GutTest
const Terraces = preload("res://scripts/terrain/field/CliffTerraces.gd")

func _region() -> HeightfieldRegion:
	var plan := HeightfieldPlan.new(17,128,32,"mean",4)
	plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 16.0 if cx<=3 else 0.0)
	return plan.compute_region(4,4,16)

func _water(region:HeightfieldRegion) -> WaterFieldContext:
	var water := WaterFieldContext.new()
	water._ctx={"ponds":[],"rivers":[],"buckets":{},"region":region}
	water._region=region
	water._shore_limit=4.0
	water._coverage=Rect2(Vector2(-120,-120),Vector2(480,480))
	return water

func test_cliff_habitat_requires_higher_nearby_ground_and_complete_dry_support() -> void:
	var region := _region()
	var water := _water(region)
	var data := {"surface_mode":DressingSet.SurfaceMode.GROUND_SUPPORT,"water_mode":DressingSet.WaterMode.LAND,
		"shore_range":Vector2.ZERO,"support_radius":1.0,"max_support_height_span":.3,"max_grade":.2,
		"feature_clearance":2.0,"relief_radius":8.0,"relief_range":Vector2(8,128)}
	assert_false(DressingField._qualify(data,Vector2(89,40),region,water).is_empty(),"Dry lower ground near a tall face can carry a rooted formation")
	assert_true(DressingField._qualify(data,Vector2(110,40),region,water).is_empty(),"Flat open ground is outside the cliff-foot habitat")
	assert_true(DressingField._qualify(data,Vector2(78,40),region,water).is_empty(),"High ground beside a drop is not a cliff foot")
	assert_true(DressingField._qualify(data,Vector2(84,40),region,water).is_empty(),"A discontinuous bearing cannot carry a new ground rock")

func test_native_jagged_formation_population_uses_the_common_compiler() -> void:
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"),EnvironmentCatalog.load_default())
	assert_not_null(program)
	if program==null:return
	var found := false
	for set_data:Dictionary in program.sets:
		if set_data.id!=&"ambient.cliff_rock":continue
		found=true
		assert_eq(set_data.spacing_group,&"natural_structural")
		assert_gte(set_data.feature_clearance,2.0)
		for choice:Dictionary in set_data.choices:
			assert_true(choice.asset_id in [&"kaykit.rock.03",&"kaykit.rock.05"])
			assert_false(choice.support_points.is_empty())
			assert_lte(choice.ground_radius*choice.scale_multiplier*set_data.scale_range.y*2,choice.spacing_radius,"Maximum native base diameter fits shared structural spacing")
	assert_true(found,"Jagged cliff rocks need an authored, shared-spacing population")

func test_cliff_population_is_chunk_stable_and_clears_native_terrain_footprints() -> void:
	Terraces.prepare()
	var region := _region()
	var water := _water(region)
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"),EnvironmentCatalog.load_default())
	var core := Rect2(Vector2.ZERO,Vector2(192,192))
	var signature_helper = autofree(preload("res://tests/test_dressing_field.gd").new())
	var total := 0
	for seed_value in 12:
		var terrain := Terraces.compute(region,0,0,8,seed_value)
		var full := DressingField.compute(program,seed_value,core,region,water,null,terrain.ground_reservations)
		var split := EnvironmentInstancePayload.new()
		for cell: Vector2i in [Vector2i(0,0),Vector2i(0,4),Vector2i(4,0),Vector2i(4,4)]:
			var subcore := Rect2(Vector2(cell)*24,Vector2.ONE*96)
			var subterrain := Terraces.compute(region,cell.x,cell.y,4,seed_value)
			var part := DressingField.compute(program,seed_value,subcore,region,water,null,subterrain.ground_reservations)
			for asset: StringName in part.asset_ids():
				var batch: Dictionary=part.batches[asset]
				for i in batch.transforms.size():split.add(asset,batch.transforms[i],batch.colors[i])
		assert_eq(signature_helper._signature(full),signature_helper._signature(split),"Halo reservations and common arbitration agree in all four chunks")
		for set_data:Dictionary in program.sets:
			for choice:Dictionary in set_data.choices:
				if not full.batches.has(choice.asset_id):continue
				for pose:Transform3D in full.batches[choice.asset_id].transforms:
					var footprint := Rect2(Vector2(pose.origin.x,pose.origin.z),Vector2.ZERO)
					for local:Vector2 in choice.support_points:
						var point:=pose*Vector3(local.x,0,local.y)
						footprint=footprint.expand(Vector2(point.x,point.z))
					for reserved:Rect2 in terrain.ground_reservations:assert_false(footprint.grow(.1).intersects(reserved),"Complete native base stays outside terrace reservations")
					if set_data.id!=&"ambient.cliff_rock":continue
					total+=1
					assert_almost_eq(pose.origin.y,TerrainSurfaceField.surface_y(region,pose.origin.x,pose.origin.z),.001)
					assert_lte(choice.ground_radius*pose.basis.get_scale().x*2,choice.spacing_radius,"Shared radius separates two complete native bases")
	print("CLIFF_POPULATION tested_formations=",total)
	assert_gte(total,6,"The actual tall-face fixture admits several independent native formations")

func test_terrain_reservation_removes_reproduced_native_base_intersections() -> void:
	Terraces.prepare()
	var region := _region()
	var water := _water(region)
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"),EnvironmentCatalog.load_default())
	var core := Rect2(Vector2.ZERO,Vector2.ONE*192)
	var reproduced := 0
	for seed_value in 4:
		var terrain := Terraces.compute(region,0,0,8,seed_value)
		var original := DressingField.compute(program,seed_value,core,region,water)
		for set_data:Dictionary in program.sets:
			for choice:Dictionary in set_data.choices:
				if not original.batches.has(choice.asset_id):continue
				for pose:Transform3D in original.batches[choice.asset_id].transforms:
					var footprint:=Rect2(Vector2(pose.origin.x,pose.origin.z),Vector2.ZERO)
					for local:Vector2 in choice.support_points:
						var point:=pose*Vector3(local.x,0,local.y)
						footprint=footprint.expand(Vector2(point.x,point.z))
					for p:Dictionary in terrain.placements:
						var box:AABB=p.bounds
						if footprint.intersects(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))):reproduced+=1;break
	print("CLIFF_UNRESERVED_INTERSECTIONS ",reproduced)
	assert_gt(reproduced,0,"The old surface-only qualification lets native ambient bases overlap placed terrain columns")

func test_cliff_leaf_groups_use_native_grounded_cover() -> void:
	var path := "res://terrain/dressing/sets/ambient_cliff_tuft.tres"
	assert_true(ResourceLoader.exists(path),"Cliff color accents need a supported native cover population")
	if not ResourceLoader.exists(path):return
	var source := load(path) as DressingSet
	assert_true(source.visual_ground_support)
	assert_eq(source.water_mode,DressingSet.WaterMode.LAND)
	assert_gte(source.feature_clearance,.3)
	assert_gt(source.relief_range.x,0.0)
	for choice:DressingChoice in source.choices:assert_eq(choice.asset_id,&"kaykit.grass.04","Pointed native leaf clumps retain the requested alternative to round shrubs")
