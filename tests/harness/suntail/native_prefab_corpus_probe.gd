extends SceneTree
## Validate exported examples against independently loaded original prefabs.
## --input JSON-array-of-derivations --output JSON-report
const ORACLE := preload("res://tests/fixtures/native_prefab_reconstruction.gd")
var input := ""
var output := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--input":
			input = args[i + 1]
		if args[i] == "--output":
			output = args[i + 1]
	call_deferred("run")


func equivalent(a: MeshInstance3D, b: MeshInstance3D) -> bool:
	if a.mesh.get_surface_count() != b.mesh.get_surface_count():
		return false
	if not (a.global_transform * a.get_aabb()).is_equal_approx(b.global_transform * b.get_aabb()):
		return false
	var normal_a := a.global_basis.inverse().transposed()
	var normal_b := b.global_basis.inverse().transposed()
	for s in a.mesh.get_surface_count():
		if a.get_active_material(s) != b.get_active_material(s):
			return false
		var aa := a.mesh.surface_get_arrays(s)
		var bb := b.mesh.surface_get_arrays(s)
		if (
			aa[Mesh.ARRAY_INDEX] != bb[Mesh.ARRAY_INDEX]
			or aa[Mesh.ARRAY_TEX_UV] != bb[Mesh.ARRAY_TEX_UV]
		):
			return false
		var av: PackedVector3Array = aa[Mesh.ARRAY_VERTEX]
		var bv: PackedVector3Array = bb[Mesh.ARRAY_VERTEX]
		if av.size() != bv.size():
			return false
		for i in av.size():
			if (a.global_transform * av[i]).distance_to(b.global_transform * bv[i]) > .0002:
				return false
		var an: PackedVector3Array = aa[Mesh.ARRAY_NORMAL]
		var bn: PackedVector3Array = bb[Mesh.ARRAY_NORMAL]
		if an.size() != bn.size():
			return false
		for i in an.size():
			if (normal_a * an[i]).normalized().distance_to((normal_b * bn[i]).normalized()) > .0002:
				return false
	return true


func run() -> void:
	var documents: Array = JSON.parse_string(FileAccess.get_file_as_string(input))
	var rows: Array = []
	var failures := 0
	for document: Dictionary in documents:
		if not document.complete:
			rows.append(
				{
					"source": document.source,
					"complete": false,
					"unmatched_stock": document.unmatched
				}
			)
			continue
		var reference: Node3D = load("res://" + String(document.source)).instantiate()
		get_root().add_child(reference)
		var reconstructed := ORACLE.instantiate(document, reference)
		get_root().add_child(reconstructed)
		var expected := reference.find_children("*", "MeshInstance3D", true, false)
		var actual := reconstructed.find_children("*", "MeshInstance3D", true, false)
		var missing: Array[String] = []
		var vertices := 0
		for mesh: MeshInstance3D in actual:
			var found := -1
			for i in expected.size():
				if equivalent(mesh, expected[i]):
					found = i
					break
			if found < 0:
				missing.append(String(mesh.name))
			else:
				expected.remove_at(found)
			for surface in mesh.mesh.get_surface_count():
				vertices += (
					(mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
					. size()
				)
		var passed := missing.is_empty() and expected.is_empty()
		failures += int(not passed)
		rows.append(
			{
				"source": document.source,
				"complete": true,
				"passed": passed,
				"modules": document.parts.size(),
				"meshes": actual.size(),
				"vertices": vertices,
				"unmatched_generated": missing,
				"unmatched_source": expected.size()
			}
		)
		print(JSON.stringify(rows.back()))
		reconstructed.free()
		reference.free()
	var report := {"houses": rows, "failures": failures}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	quit(0 if failures == 0 else 1)
