extends GutTest

func _field(points := PackedVector3Array([Vector3(12,2.5,18)])) -> Node3D:
	var fog := PackedColorArray()
	fog.resize(169)
	fog.fill(Color(0,0,0,0))
	var ground := PackedFloat32Array()
	ground.resize(169)
	return BiomeChunkFx.build_field({"origin":Vector3.ZERO,"fog":fog,
		"ground":ground,"lo":0.0,"hi":0.0,
		"points":{&"fireflies":points},"orbs":[Vector3(18,2.5,18)]})

func test_small_glows_have_moving_ground_lights_and_spherical_cores() -> void:
	var fx := _field()
	var particles := fx.find_child("fireflies",true,false)
	assert_null(particles,"The photographed static particle emitter must be replaced by moving lit orbs")
	var small := fx.find_child("SmallSpiritOrbs",true,false)
	assert_not_null(small,"Original ground-following small-orb anchors need an owned render adapter")
	if small != null:
		small.call("sample",10.0,Vector3(12,2.5,18))
		var cores := small.get_node("Cores") as MultiMeshInstance3D
		assert_true(cores.multimesh.mesh is SphereMesh,"Small cores have actual curved geometry")
		assert_eq(cores.multimesh.instance_count,1,"One orb per canonical anchor, without five overlapping particles")
		var lights := small.find_children("*","OmniLight3D",true,false)
		assert_eq(lights.size(),1,"Nearby small orb illuminates its real ground")
		if lights.size()==1:
			if DisplayServer.get_name() != "headless":
				assert_lt(lights[0].position.distance_to(cores.multimesh.get_instance_transform(0).origin),0.00001)
			assert_gt(lights[0].omni_range,2.9,"Range reaches ground throughout the bob")
	fx.free()

func test_large_orb_uses_spherical_core_and_restrained_halo() -> void:
	var fx := _field()
	var orb := fx.find_child("SpiritOrb",true,false)
	var core := orb.find_child("Core",true,false) as MeshInstance3D
	assert_not_null(core,"The large orb needs a 3D core, not only an additive flat disc")
	if core != null: assert_true(core.mesh is SphereMesh)
	var halo := orb.get_child(0) as MeshInstance3D
	assert_between((halo.mesh as QuadMesh).size.x,1.0,2.4,"Halo falls between the two formerly separate appearances")
	fx.free()

func test_light_pool_is_bounded_and_distant_visits_release_it() -> void:
	var points := PackedVector3Array()
	for i in 64: points.append(Vector3(i%8,2.5,i/8))
	var fx := _field(points)
	var small := fx.find_child("SmallSpiritOrbs",true,false)
	assert_not_null(small)
	if small != null:
		for visit in 40:
			small.sample(visit*17.0,Vector3(4,2.5,4))
			assert_eq(small._lights.size(),16,"Dense pathological placement cannot exceed the light budget")
			for light in small._lights: assert_false(light.shadow_enabled)
			small.sample(visit*17.0,Vector3(2000,2.5,2000))
			assert_true(small._lights.is_empty(),"Teleporting away releases the pool")
			assert_false(small.visible,"Distant batched geometry does not keep stale frozen visuals")
	fx.free()

func test_native_small_core_halo_and_light_follow_same_slow_path_after_revisit() -> void:
	if DisplayServer.get_name()=="headless":
		pending("MultiMesh transform readback needs a real rendering server; run this test graphically")
		return
	var fx := _field()
	var small := fx.find_child("SmallSpiritOrbs",true,false)
	assert_not_null(small)
	if small != null:
		var previous := Vector3.ZERO
		var low := Vector3(INF,INF,INF)
		var high := -low
		for i in 601:
			small.sample(i*0.1,Vector3(12,2.5,18))
			var core: Vector3 = small._cores.multimesh.get_instance_transform(0).origin
			var halo: Vector3 = small._halos.multimesh.get_instance_transform(0).origin
			assert_lt(core.distance_to(halo),0.00001)
			assert_lt(core.distance_to(small._lights[0].position),0.00001)
			if i>0: assert_lt(core.distance_to(previous)/0.1,0.3)
			low=low.min(core)
			high=high.max(core)
			previous=core
		assert_gt(high.x-low.x,2.0)
		assert_between(low.y,2.09,2.5)
		assert_lte(high.y,2.90001)
		var before: Transform3D = small._cores.multimesh.get_instance_transform(0)
		small.sample(60.0,Vector3(2000,0,2000))
		small.sample(60.0,Vector3(12,2.5,18))
		assert_eq(before,small._cores.multimesh.get_instance_transform(0),"Revisiting does not reset motion phase")
	fx.free()
