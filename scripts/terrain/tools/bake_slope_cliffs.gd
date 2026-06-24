# scripts/terrain/tools/bake_slope_cliffs.gd
# Headless bake: writes slope component scenes and (Task 6) variant scenes.
# Run: Godot --headless --path . -s scripts/terrain/tools/bake_slope_cliffs.gd
extends SceneTree

const MAT := "res://terrain/materials/ground.tres"
const GLTF_DIR := "res://terrain/gltf/slope"
const SCENE_DIR := "res://terrain/scenes/slope"
const SKIRT := SlopeMeshGenerator.SKIRT  # keep top-collision offset in sync with the generator

const COMPONENT_PATHS := {
	"top": "res://terrain/gltf/slope/top.tscn",
	"edge": "res://terrain/gltf/slope/edge.tscn",
	"outer": "res://terrain/gltf/slope/outer_corner.tscn",
	"inner": "res://terrain/gltf/slope/inner_corner.tscn",
	"outer_stacked": "res://terrain/gltf/slope/outer_corner_stacked.tscn",
	"inner_stacked": "res://terrain/gltf/slope/inner_corner_stacked.tscn",
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GLTF_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	var gen := SlopeMeshGenerator.new()
	gen.grass_uv = SlopeAtlas.grass_uv()
	gen.material = load(MAT)
	_bake_components(gen)
	_bake_variants(gen)   # implemented in Task 6
	print("slope bake complete")
	quit()

func _bake_components(gen: SlopeMeshGenerator) -> void:
	_save_component("top", gen.build_top(), [gen.build_top_collision()], Vector3(0, -SKIRT * 0.5, 0))
	_save_component("edge", gen.build_edge(), gen.build_edge_collision(), Vector3.ZERO)
	_save_component("outer_corner", gen.build_outer_corner(), gen.build_outer_corner_collision(), Vector3.ZERO)
	_save_component("inner_corner", gen.build_inner_corner(), gen.build_inner_corner_collision(), Vector3.ZERO)
	_save_component("outer_corner_stacked", gen.build_outer_corner_stacked(), gen.build_outer_corner_stacked_collision(), Vector3.ZERO)
	_save_component("inner_corner_stacked", gen.build_inner_corner_stacked(), gen.build_inner_corner_stacked_collision(), Vector3.ZERO)

func _save_component(cname: String, mesh: ArrayMesh, shapes: Array, col_offset: Vector3) -> void:
	var root := Node3D.new()
	root.name = cname
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	mi.mesh = mesh
	root.add_child(mi)
	mi.owner = root
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	root.add_child(body)
	body.owner = root
	var i := 0
	for shape in shapes:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D" if i == 0 else "CollisionShape3D%d" % (i + 1)
		cs.shape = shape
		cs.position = col_offset
		body.add_child(cs)
		cs.owner = root
		i += 1
	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/%s.tscn" % [GLTF_DIR, cname]
	var err := ResourceSaver.save(packed, path)
	assert(err == OK, "save failed: %s" % path)
	root.free()

func _bake_variants(_gen: SlopeMeshGenerator) -> void:
	for name in SlopeVariantLayout.VARIANT_MASKS.keys():
		_bake_variant_cells(name, SlopeVariantLayout.layout(name), name)
	for name in SlopeVariantLayout.STACKED_VARIANTS.keys():
		_bake_variant_cells(name, SlopeVariantLayout.stacked_layout(name), SlopeVariantLayout.STACKED_VARIANTS[name].base)
	# Generative 2-storey corner variants for peninsula/island (one per outer-corner subset).
	for v in SlopeVariantLayout.generated_stacked_variants():
		_bake_variant_cells(v.name, SlopeVariantLayout.stacked_layout_for(v.base, v.corners), v.base)

func _bake_variant_cells(name: String, cells: Array, socket_source: String) -> void:
	var root := Node3D.new()
	root.name = name
	var i := 0
	for cell in cells:
		var comp_scene := load(COMPONENT_PATHS[cell.component]) as PackedScene
		var node := comp_scene.instantiate()
		node.name = "%s_%d" % [cell.component, i]
		var basis := Basis(Vector3.UP, deg_to_rad(cell.angle_deg))
		node.transform = Transform3D(basis, Vector3(cell.x, 0.0, cell.z))
		root.add_child(node)
		# Only the instance root needs owner=root so it serializes as an
		# instance reference; setting owner on the instance's internal nodes
		# makes pack() inline their meshes/shapes (bloat + instantiate crash).
		node.owner = root
		i += 1
	# Copy sockets from the original scene for adjacency parity.
	var orig := (load("res://terrain/scenes/cliff/%s.tscn" % socket_source) as PackedScene).instantiate()
	var sockets := orig.get_node_or_null("Sockets")
	if sockets != null:
		var dup := sockets.duplicate()
		_ground_surface_sockets(dup, cells)
		root.add_child(dup)
		_set_owner_recursive(dup, root)
	orig.free()
	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/%s.tscn" % [SCENE_DIR, name]
	var err := ResourceSaver.save(packed, path)
	assert(err == OK, "save failed: %s" % path)
	root.free()

# Drop top-surface decoration sockets (topcenter/topfront/topback/topleft/topright)
# onto the slope surface so attached decorations rest on the ground instead of
# floating at the old flat y=0. Adjacency sockets (front/back/left/right, diagonals,
# bottom) are left untouched — they keep y=0 for adjacency parity and drive tile
# connection, not decoration placement.
func _ground_surface_sockets(sockets: Node, cells: Array) -> void:
	for m in sockets.get_children():
		if m is Marker3D and String(m.name).begins_with("top"):
			var p: Vector3 = m.transform.origin
			m.transform.origin = Vector3(p.x, SlopeProfile.surface_height(cells, p.x, p.z), p.z)

func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	node.owner = owner_root
	for c in node.get_children():
		_set_owner_recursive(c, owner_root)
