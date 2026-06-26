# scripts/terrain/tools/bake_level_tiles.gd
# Headless bake: regenerates the LEVEL edge tiles (0.5m terrace step) from the SAME
# parameterized slope components that produce the 4m cliffs, so level edges reach the
# full +/-12 cell boundary and drop EXACTLY 0.5m. The previously-authored level scenes
# stopped 0.25m short of the boundary and overshot to -0.71, leaving a visible gap/bank
# where ground meets a level edge. Generating them the cliff way removes that gap.
#
# Run: Godot --headless --path . -s scripts/terrain/tools/bake_level_tiles.gd
extends SceneTree

const MAT := "res://terrain/materials/ground.tres"
const GLTF_DIR := "res://terrain/gltf/level"
const SCENE_DIR := "res://terrain/scenes/level"
const SKIRT := SlopeMeshGenerator.SKIRT
const DROP := 0.5   # one 0.5m level/terrace step (cliffs use 4.0)

# Only top/edge/outer/inner are referenced by the single-storey VARIANT_MASKS layouts
# (no stacked: levels are 0.5m sub-steps, never 2-storey diagonal pits).
const COMPONENTS := {
	"top": "res://terrain/gltf/level/top.tscn",
	"edge": "res://terrain/gltf/level/edge.tscn",
	"outer": "res://terrain/gltf/level/outer_corner.tscn",
	"inner": "res://terrain/gltf/level/inner_corner.tscn",
}

func _init() -> void:
	SlopeProfile.HEIGHT = DROP   # parameterize the shared component generator for levels
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GLTF_DIR))
	# Pre-read the authored level sockets BEFORE we overwrite the scenes.
	var sockets_by_variant := _cache_authored_sockets()
	var gen := SlopeMeshGenerator.new()
	gen.grass_uv = SlopeAtlas.grass_uv()
	gen.material = load(MAT)
	_bake_components(gen)
	for cliff_name: String in SlopeVariantLayout.VARIANT_MASKS.keys():
		var level_name := "Level" + cliff_name.substr(5)
		var cells := SlopeVariantLayout.layout(cliff_name)
		_bake_variant(level_name, cells, sockets_by_variant.get(level_name))
	SlopeProfile.HEIGHT = 4.0   # restore the shared default for any later caller
	print("level bake complete")
	quit()

# Instantiate every authored level scene once (before any overwrite) and duplicate its
# Sockets node, so socket parity survives regenerating the geometry under it.
func _cache_authored_sockets() -> Dictionary:
	var out := {}
	for cliff_name: String in SlopeVariantLayout.VARIANT_MASKS.keys():
		var level_name := "Level" + cliff_name.substr(5)
		var path := "%s/%s.tscn" % [SCENE_DIR, level_name]
		var inst := (load(path) as PackedScene).instantiate()
		var sockets := inst.get_node_or_null("Sockets")
		if sockets != null:
			out[level_name] = sockets.duplicate()
		inst.free()
	return out

func _bake_components(gen: SlopeMeshGenerator) -> void:
	_save_component("top", gen.build_top(), [gen.build_top_collision()], Vector3(0, -SKIRT * 0.5, 0))
	_save_component("edge", gen.build_edge(), gen.build_edge_collision(), Vector3.ZERO)
	_save_component("outer_corner", gen.build_outer_corner(), gen.build_outer_corner_collision(), Vector3.ZERO)
	_save_component("inner_corner", gen.build_inner_corner(), gen.build_inner_corner_collision(), Vector3.ZERO)

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

func _bake_variant(name: String, cells: Array, sockets: Node) -> void:
	var root := Node3D.new()
	root.name = name
	var i := 0
	for cell in cells:
		var comp_scene := load(COMPONENTS[cell.component]) as PackedScene
		var node := comp_scene.instantiate()
		node.name = "%s_%d" % [cell.component, i]
		var basis := Basis(Vector3.UP, deg_to_rad(cell.angle_deg))
		node.transform = Transform3D(basis, Vector3(cell.x, 0.0, cell.z))
		root.add_child(node)
		node.owner = root   # only the instance root; internal nodes stay refs
		i += 1
	if sockets != null:
		_ground_surface_sockets(sockets, cells)
		root.add_child(sockets)
		_set_owner_recursive(sockets, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/%s.tscn" % [SCENE_DIR, name]
	var err := ResourceSaver.save(packed, path)
	assert(err == OK, "save failed: %s" % path)
	root.free()

# Drop top-surface decoration sockets onto the generated 0.5m slope so attached
# decorations rest on the ground. Adjacency sockets (front/back/.../bottom) keep y=0.
func _ground_surface_sockets(sockets: Node, cells: Array) -> void:
	for m in sockets.get_children():
		if m is Marker3D and String(m.name).begins_with("top"):
			var p: Vector3 = m.transform.origin
			m.transform.origin = Vector3(p.x, SlopeProfile.surface_height(cells, p.x, p.z), p.z)

func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	node.owner = owner_root
	for c in node.get_children():
		_set_owner_recursive(c, owner_root)
