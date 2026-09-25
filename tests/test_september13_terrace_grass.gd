extends GutTest

const Terraces=preload("res://scripts/terrain/field/CliffTerraces.gd")

func _fixture()->Dictionary:
	Terraces.prepare()
	var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
	plan.set_raw_height_override(func(x:int,_z:int)->float:return 16.0 if x<=3 else 0.0)
	var region:=plan.compute_region(4,4,12)
	var water:=WaterFieldContext.new()
	water._region=region;water._coverage=Rect2(-48,-48,288,288)
	water._ctx={"ponds":[],"rivers":[],"buckets":{},"region":region}
	water._shore_curves_ready=true
	water._shore_limit=.3
	var data:=Terraces.compute(region,0,0,8,99,null,water)
	assert_gt(data.placements.size(),0,"the fixture has real native ledges")
	var catalog:=EnvironmentCatalog.load_default()
	var program:=GrassProgram.compile(load("res://terrain/grass/settings.tres"),catalog,EnvironmentRenderCache.new(catalog))
	return {"region":region,"water":water,"data":data,"program":program}

func test_ordinary_grass_roots_on_exposed_native_terrace_caps()->void:
	var f:=_fixture()
	var region:HeightfieldRegion=f.region
	var water:WaterFieldContext=f.water
	var data:Dictionary=f.data
	var program:GrassProgram=f.program
	var rooted:=0
	var patches:=0
	var unsupported_roots:=0
	var unsupported_edges:=0
	var native_faces:=PackedVector3Array()
	for placement:Dictionary in data.placements:
		if placement.kind!="rock":Terraces._append_faces(native_faces,placement.asset,placement.transform)
	for z in 8:
		var payload:=GrassField.compute(program,99,Vector2i(3,z),region,water,null,data.grass_supports)
		for asset_id:StringName in payload.batches:
			var batch:Dictionary=payload.batches[asset_id]
			for i in batch.count:
				var k:int=i*GrassPayload.FLOATS_PER_INSTANCE
				var p:=Vector3(batch.buffer[k+3],batch.buffer[k+7],batch.buffer[k+11])
				patches+=1
				for placement:Dictionary in data.placements:
					if placement.kind=="rock":continue
					if absf(p.y-placement.top)<.1 and p.y>TerrainSurfaceField.surface_y(region,p.x,p.z)+.5:
						rooted+=1
						var found:=_native_top(native_faces,p)
						if not is_finite(found) or absf(found-p.y)>.001:unsupported_roots+=1
						var asset:Dictionary=program.assets[asset_id]
						var radius:float=asset.footprint_radius*Vector3(batch.buffer[k],batch.buffer[k+4],batch.buffer[k+8]).length()/(asset.piece_transform as Transform3D).basis.x.length()
						for angle in 16:
							var q:=p+Vector3(cos(angle*TAU/16),0,sin(angle*TAU/16))*radius
							var edge:=_native_top(native_faces,q)
							if not is_finite(edge) or absf(edge-p.y)>.001:unsupported_edges+=1
						break
	print("TERRACE_GRASS patches=",patches," rooted_on_caps=",rooted)
	assert_gt(patches,0,"ordinary ground grass is present in this fixture")
	assert_gt(rooted,0,"ordinary grass must use the exposed native terrace top instead of the ground buried below it")
	assert_eq(unsupported_roots,0,"every new root touches actual native triangles")
	assert_eq(unsupported_edges,0,"the complete grass patch remains inside the authored cap")

func _native_top(faces:PackedVector3Array,p:Vector3)->float:
	var top:float=-INF
	for i in range(0,faces.size(),3):
		var hit=Geometry3D.ray_intersects_triangle(p+Vector3.UP,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
		if hit!=null:top=maxf(top,hit.y)
	return top

func test_cap_grass_keeps_identical_chunk_boundary_ownership()->void:
	var f:=_fixture()
	var full:Dictionary=f.data
	for z in [3,4]:
		for x in [3,4]:
			var tile:=Vector2i(x,z)
			var owner:=Vector2i(0 if x<4 else 4,0 if z<4 else 4)
			var split:=Terraces.compute(f.region,owner.x,owner.y,4,99,null,f.water)
			var a:=GrassField.compute(f.program,99,tile,f.region,f.water,null,full.grass_supports)
			var b:=GrassField.compute(f.program,99,tile,f.region,f.water,null,split.grass_supports)
			assert_eq(var_to_bytes(a.batches),var_to_bytes(b.batches),"the same tile retains every grass transform across construction boundaries")

func test_grass_support_copy_does_not_share_mutable_buffers()->void:
	var f:=_fixture()
	var copy:=GrassSamplingContext.detached(f.region,f.water,null,f.data.grass_supports)
	assert_gt(copy.supports.size(),0)
	var before:=var_to_bytes(f.data.grass_supports)
	copy.supports[0].triangles[0]+=Vector2.ONE
	copy.supports[0].obstacles.append(Rect2(0,0,1,1))
	assert_eq(var_to_bytes(f.data.grass_supports),before,"visual worker changes cannot alter committed terrain input")
	assert_null(copy.region.plan)
