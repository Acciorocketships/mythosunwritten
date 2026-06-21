# tests/test_slope_components.gd
extends GutTest

const COMPONENTS := ["top", "edge", "outer_corner", "inner_corner"]

func test_component_scenes_exist_and_load() -> void:
	for c in COMPONENTS:
		var path := "res://terrain/gltf/slope/%s.tscn" % c
		assert_true(ResourceLoader.exists(path), path)
		var inst := (load(path) as PackedScene).instantiate()
		assert_not_null(inst)
		# has a mesh and a static body with a collision shape
		assert_not_null(_find(inst, "MeshInstance3D"))
		var body := _find(inst, "StaticBody3D")
		assert_not_null(body)
		assert_not_null(_find(body, "CollisionShape3D"))
		inst.free()

func test_stacked_component_scenes_exist_and_load() -> void:
	for c in ["outer_corner_stacked", "inner_corner_stacked"]:
		var path := "res://terrain/gltf/slope/%s.tscn" % c
		assert_true(ResourceLoader.exists(path), path)
		var inst := (load(path) as PackedScene).instantiate()
		assert_not_null(_find(inst, "MeshInstance3D"))
		var body := _find(inst, "StaticBody3D")
		assert_not_null(body)
		assert_not_null(_find(body, "CollisionShape3D"))
		inst.free()

func _find(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null
