extends GutTest

func test_orb_motion_is_slow_bounded_and_keeps_its_light_attached() -> void:
	var fog := PackedColorArray()
	fog.resize(169)
	var ground := PackedFloat32Array()
	ground.resize(169)
	var fx := BiomeChunkFx.build_field({"origin":Vector3.ZERO,"fog":fog,
		"ground":ground,"lo":0.0,"hi":0.0,"points":{},"orbs":[Vector3(12,2.5,18)]})
	var orb := fx.find_child("SpiritOrb",true,false) as SpiritOrb
	var sprite := orb.get_child(0) as MeshInstance3D
	var light := orb.get_child(1) as OmniLight3D
	assert_gt((sprite.mesh as QuadMesh).size.x,3.0,"The luminous sprite must be larger than the former 2.2m quad")
	var low := Vector3(INF,INF,INF)
	var high := -low
	orb._process(0.0)
	var previous := orb.position
	var maximum_speed := 0.0
	for i in 1200:
		orb._process(0.05)
		maximum_speed = maxf(maximum_speed,orb.position.distance_to(previous)/0.05)
		low = low.min(orb.position)
		high = high.max(orb.position)
		previous = orb.position
	assert_gt(high.x-low.x,2.0,"Drift travels visibly beyond the old 1.2m envelope")
	assert_lt(maximum_speed,0.3,"The slow drift must not become a darting firefly")
	assert_gt(low.y,2.0,"The bob retains its grounded anchor clearance")
	assert_lt(high.y-low.y,1.0)
	assert_eq(sprite.position,light.position,"Sprite and light move together under one parent")
	fx.free()
