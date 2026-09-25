extends GutTest

func test_float32_stationary_surface_does_not_queue_phantom_lowering() -> void:
	var levels:=PackedFloat32Array([.2,1.1])
	var ground:=PackedFloat32Array([0,1])
	var before:=levels.to_byte_array()
	var offers:=WaterField._reconcile_connected_surface(levels,ground,2,3)
	assert_eq(levels.to_byte_array(),before,"The proposed double-precision ceiling rounds to the already stored value")
	assert_eq(offers,0,"Unchanged float32 nodes must not propagate redundant updates")
