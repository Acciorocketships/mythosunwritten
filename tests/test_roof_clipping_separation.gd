extends GutTest

const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

func test_sloped_cutters_preserve_original_mesh_and_collision_input() -> void:
	# Captured authored roof surfaces where box separation alone changes the
	# old clipper's tessellation. Preserve vertices, normals, UVs and indices.
	var cases: Array = FileAccess.open(
		"res://tests/fixtures/roof-clipping-separation.bin", FileAccess.READ).get_var()
	assert_eq(cases.size(), 3)
	for record: Dictionary in cases:
		var result := UNION.trim_surface(record.surface, record.transform, record.cutters)
		assert_eq(var_to_bytes(result), var_to_bytes(record.previous))
