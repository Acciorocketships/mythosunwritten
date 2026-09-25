extends GutTest

func test_all_native_cliff_face_roles_use_the_new_siding() -> void:
	# The photographed face is still emitted from the old smooth repeated stock.
	# A study render alone cannot satisfy integration into the production owner.
	for key: String in ["wall", "outer_wall", "inner_wall"]:
		assert_true(String(CliffDressing.ASSETS[key]).begins_with("mythos.cliff."),
			"Production cliff role must consume compatible fractured siding: "+key)

func test_native_caps_keep_their_original_assets() -> void:
	for key: String in ["lip", "outer_lip", "inner_lip"]:
		assert_eq(String(CliffDressing.ASSETS[key]),"kaykit.cliff."+key,
			"The new siding must retain the existing rounded grass cap: "+key)
