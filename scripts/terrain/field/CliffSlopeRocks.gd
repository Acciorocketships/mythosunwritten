extends RefCounted
## Layered rocks set into the mossy slopes (owner trial, September 23), like
## the owner's reference: the Meadow pack's stratified P_Rock 01-05 and the
## Farmlands pack's low layered Cliff_Flat and stratified cliff masses. Both packs' rounded boulders and
## river stones were rejected. Shaded with the cliff stone and a grass top.
## Placement lives in CliffSlopeField; meshes are prepared on the main thread.
## Trial only: loaded from the source packs, visual only (no collision yet).
const ANGRY := "res://assets/ANGRY MESH/Models/Stylized_Pack_-_Meadow_Environment/Rocks/Rocks_-_Summer/"
const POLYART := "res://assets/Polyart/Models/Farmlands/Stones/"
## Measured source bounds (metres), used to scale each piece to its target size.
const PIECES := {
	"angry_01": [ANGRY + "P_Rock_01_Summer.glb", Vector3(5.79, 2.95, 5.47)],
	"angry_02": [ANGRY + "P_Rock_02_Summer.glb", Vector3(5.34, 2.11, 4.91)],
	"angry_03": [ANGRY + "P_Rock_03_Summer.glb", Vector3(4.48, 2.58, 3.72)],
	"angry_04": [ANGRY + "P_Rock_04_Summer.glb", Vector3(3.59, 2.32, 3.01)],
	"angry_05": [ANGRY + "P_Rock_05_Summer.glb", Vector3(2.84, 1.62, 2.66)],
	"polyart_flat": [POLYART + "PF_Farm_Cliff_Flat_01.glb", Vector3(8.42, 2.71, 9.62)],
	# The Farmlands cliff masses are rocks like any other, under the same rule.
	"cliff_large_01": [POLYART + "PF_Farm_Cliff_Large_01.glb", Vector3(8.88, 12.54, 7.56)],
	"cliff_large_02": [POLYART + "PF_Farm_Cliff_Large_02.glb", Vector3(5.0, 10.01, 4.55)],
	"cliff_large_03": [POLYART + "PF_Farm_Cliff_Large_03.glb", Vector3(14.98, 15.44, 14.14)],
}
static var _pieces: Dictionary = {}


static func prepare() -> void:
	if not _pieces.is_empty():
		return
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	var shader := load("res://terrain/materials/cliff_crag.gdshader") as Shader
	for name: String in PIECES:
		var root := (load(PIECES[name][0]) as PackedScene).instantiate()
		var instance := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var local := Transform3D.IDENTITY
		var node: Node = instance
		while node != root:
			local = (node as Node3D).transform * local
			node = node.get_parent()
		var box: AABB = local * instance.mesh.get_aabb()
		# Pivot at the centre of the rock.
		local = Transform3D(Basis(), -box.get_center()) * local
		var source := instance.get_active_material(0) as BaseMaterial3D
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("prop_mode", true)
		load("res://scripts/terrain/field/CliffRockCrags.gd").apply_moss(material)
		if source != null and source.albedo_texture != null:
			material.set_shader_parameter("prop_albedo", source.albedo_texture)
		_pieces[name] = [instance.mesh, local, material]
		root.free()


## One MultiMesh per piece. Each entry carries its world transform, the slope
## point and normal under it, and the formation's ground height.
static func build(entries: Dictionary, seed_value: int) -> Node3D:
	prepare()
	var root := Node3D.new()
	root.name = "CliffSlopeRocks"
	for name: String in entries:
		var rocks: Array = entries[name]
		var piece: Array = _pieces[name]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = piece[0]
		mm.instance_count = rocks.size()
		for i in rocks.size():
			var t: Transform3D = rocks[i].transform
			mm.set_instance_transform(i, t * (piece[1] as Transform3D))
			mm.set_instance_color(i, BiomeRegistry.ground_tint_at(t.origin, seed_value))
			# The slope plane under the rock and the formation's ground height:
			# the rock's base grows the same moss and lawn as the slope around it.
			var normal: Vector3 = rocks[i].normal
			mm.set_instance_custom_data(i, Color(normal.x, normal.z, normal.dot(rocks[i].point), rocks[i].ground))
		var node := MultiMeshInstance3D.new()
		node.name = name
		node.multimesh = mm
		node.material_override = piece[2]
		node.add_to_group("tactical_solid_earth", true)
		root.add_child(node)
	return root
