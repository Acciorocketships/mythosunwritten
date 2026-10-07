extends GutTest

func test_face_noise_depends_on_world_seed() -> void:
	var differs := 0
	for x in 64:
		var face := Vector4i(x, 2, 3, 0)
		if SettlementFabricAssembler._face_noise(face, 11, 1) != SettlementFabricAssembler._face_noise(face, 11, 2):
			differs += 1
	assert_gt(differs, 50)
