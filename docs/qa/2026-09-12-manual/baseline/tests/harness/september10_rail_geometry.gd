extends SceneTree
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var report := {}
	for fixture in ["september10-stone-source.txt","september10-skywalk-source.txt"]:
		var fabric := frozen.spatial(frozen.read("res://tests/fixtures/"+fixture),program).compiled_fabric_cache()
		var meshes := {}
		for mesh: Dictionary in fabric.surface_plan.mesh_payloads:
			if not bool(mesh.get("is_transition",false)):continue
			var streams := {}
			for key in ["vertices","uvs","collision_faces","indices","normals"]:
				var ctx := HashingContext.new()
				ctx.start(HashingContext.HASH_SHA256)
				ctx.update(var_to_bytes(mesh[key]))
				streams[key]=ctx.finish().hex_encode()
			streams["triangle_count"]=mesh.indices.size()/3
			meshes[String(mesh.stable_id)]=streams
		report[fixture]=meshes
	var args := OS.get_cmdline_user_args()
	FileAccess.open(args[0],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RAIL_GEOMETRY ",args[0])
	quit()
