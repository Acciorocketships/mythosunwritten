extends SceneTree

## Read-only source-pack probe used to choose a sealed roof vocabulary before
## baking it into the runtime catalogue. This never participates in runtime.
const SOURCES: Array[String] = [
	"res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_S_Preset_Blue_001.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_S_Blue_001.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_S_Blue_002.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Blue/MBlue/SFV_Roof_M_Preset_Blue_001.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Blue/LBlue/SFV_Roof_Preset_L_Blue_001.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Blue/XLBlue/SFV_Roof_Preset_Blue_XL_001.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_M/SFV_Roof_Attachable_Preset_M_001.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_M/SFV_Roof_Attachable_Preset_M_002.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_M/SFV_Roof_Attachable_Preset_M_003.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_L/SFV_Roof_Attachable_L_Preset_001.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_L/SFV_Roof_Attachable_L_Preset_002.fbx",
	"res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_L/SFV_Roof_Attachable_L_Preset_003.fbx",
	"res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Triangle/SFV_Roof_Triangle_001.fbx",
	"res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Triangle/SFV_Roof_Wall_S_001.fbx",
	"res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Triangle/SFV_Roof_Wall_M_001.fbx",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_01.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_02.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_03.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_04.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_05.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_06.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/Chimney_01.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_01.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_02.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_03.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_04.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_05.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_06.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_07.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_08.glb",
	"res://assets/LowPolyFantasyVillage/Models/HouseParts/DoorRoof_01.glb",
	"res://assets/LowPolyFantasyVillage/Models/Props/Market_Roof_01.glb",
	"res://assets/LowPolyFantasyVillage/Models/Props/Market_Roof_02.glb",
	"res://assets/LowPolyFantasyVillage/Models/Props/Market_Roof_03.glb",
]


func _init() -> void:
	var sources := SOURCES
	var args := OS.get_cmdline_user_args()
	var source_arg := args.find("--sources")
	if source_arg >= 0 and source_arg + 1 < args.size():
		sources = [] as Array[String]
		for source_path: String in args[source_arg + 1].split(",", false):
			sources.append(source_path)
	for source_path: String in sources:
		var scene := load(source_path) as PackedScene
		if scene == null:
			push_error("Could not load roof source %s" % source_path)
			continue
		var root := scene.instantiate()
		var result := {"has_bounds": false, "bounds": AABB(), "meshes": [],
			"vertices": []}
		_collect(root, Transform3D.IDENTITY, result)
		var ridge := _ridge_bounds(result.vertices as Array, result.bounds as AABB)
		print("[roof_probe] source=%s bounds=%s ridge=%s meshes=%s" % [source_path,
			result.bounds, ridge, result.meshes])
		root.free()
	quit()


static func _collect(node: Node, parent_transform: Transform3D,
		result: Dictionary) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var bounds := transform * mesh_instance.mesh.get_aabb()
			result.bounds = bounds if not bool(result.has_bounds) \
				else (result.bounds as AABB).merge(bounds)
			result.has_bounds = true
			(result.meshes as Array).append({
				"name": String(mesh_instance.name),
				"bounds": bounds,
			})
			for surface in mesh_instance.mesh.get_surface_count():
				var arrays := mesh_instance.mesh.surface_get_arrays(surface)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
					(result.vertices as Array).append(transform * vertex)
	for child: Node in node.get_children():
		_collect(child, transform, result)


static func _ridge_bounds(vertices: Array, bounds: AABB) -> AABB:
	var out := AABB()
	var has_vertex := false
	var threshold := bounds.end.y - 0.12
	for value: Variant in vertices:
		var vertex := value as Vector3
		if vertex.y < threshold:
			continue
		var point_bounds := AABB(vertex, Vector3(0.001, 0.001, 0.001))
		out = point_bounds if not has_vertex else out.merge(point_bounds)
		has_vertex = true
	return out
