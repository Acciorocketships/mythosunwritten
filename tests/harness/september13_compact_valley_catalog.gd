extends SceneTree

const GEO = preload("res://tools/environment_bake/EnvironmentBakeGeometry.gd")
const OUT = "res://docs/qa/2026-09-13-manual/11-roof-joins/catalog/"
var catalog: EnvironmentCatalog

func _init() -> void: run.call_deferred()

func stock(id: StringName, align: bool = true) -> ArrayMesh:
	var descriptor := catalog.descriptor(id)
	assert(descriptor != null, str(id))
	var visual := load(descriptor.visual_path) as EnvironmentVisual
	var parts: Array[ArrayMesh] = []
	for piece: EnvironmentVisualPiece in visual.pieces:
		var pose := piece.local_transform
		if align: pose.origin.y -= descriptor.measured_aabb.position.y
		var mesh := GEO.transform_mesh(piece.mesh, pose)
		for surface in mesh.get_surface_count():
			if piece.material_override != null:
				mesh.surface_set_material(surface, piece.material_override)
		parts.append(mesh)
	return merge(parts)

func merge(meshes: Array[ArrayMesh]) -> ArrayMesh:
	var result := ArrayMesh.new()
	for mesh in meshes:
		for index in mesh.get_surface_count():
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
				mesh.surface_get_arrays(index))
			result.surface_set_material(result.get_surface_count()-1,
				mesh.surface_get_material(index))
	return result

func shifted(mesh: ArrayMesh, x: float, z: float, yaw: int = 0) -> ArrayMesh:
	return GEO.transform_mesh(mesh,
		Transform3D(Basis(Vector3.UP, yaw*PI*.5), Vector3(x,0,z)))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	catalog = EnvironmentCatalog.load_default()
	root.size = Vector2i(1400,900)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("677782")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	stage.add_child(sun)
	sun.rotation_degrees = Vector3(-50,-30,0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	var records := []
	for family in ["slate", "orange"]:
		for tight in [true, false]:
			var base := "lpfv.fabric.roof.compact.%s.03" % family
			var profile := ".tight" if tight else ""
			var middle := stock(StringName(base+".run.middle"+profile))
			var adjacent := stock(StringName(base+".run.middle"+profile+".mirror_z"))
			var start := stock(StringName(base+".run.start"+profile))
			var end := stock(StringName(base+".run.end"+profile))
			var host := merge([shifted(middle,0,-1.5),adjacent,
				shifted(middle,0,1.5),shifted(start,0,-1.5),shifted(end,0,1.5)])
			var branch_middle := stock(StringName(base+".run.middle"))
			var branch_mirror := stock(StringName(base+".run.middle.mirror_z"))
			var branch_end := stock(StringName(base+".run.end"))
			var branch := merge([GEO.clip_axis_range(branch_middle,2,0,16),
				shifted(branch_mirror,0,1.5),shifted(branch_middle,0,3),
				shifted(branch_end,0,3)])
			for eave_sign in [-1,1]:
				for end_sign in [-1,1]:
					var label := "%s.%s.eave_%s.end_%s" % [family,
						"tight" if tight else "ordinary",
						"negative" if eave_sign<0 else "positive",
						"negative" if end_sign<0 else "positive"]
					var prefix := base+".valley."+label.trim_prefix(family+".")+"."
					var expected_branch := shifted(branch,0,end_sign*1.5,eave_sign)
					var joined := merge([
						shifted(middle,0,-end_sign*1.5),
						shifted(start if end_sign>0 else end,0,-end_sign*1.5),
						shifted(stock(StringName(prefix+"end"),false),0,end_sign*1.5),
						shifted(stock(StringName(prefix+"middle"),false),0,end_sign*1.5),
						stock(StringName(prefix+"adjacent"),false),
						shifted(stock(StringName(prefix+"branch"),false),0,end_sign*1.5)])
					var coverage := {}
					for key in ["host", "branch", "joined"]:
						var mesh := host if key=="host" else expected_branch if key=="branch" else joined
						var coordinates := []
						for vertex: Vector3 in GEO.triangle_faces(mesh):
							coordinates.append_array([vertex.x,vertex.y,vertex.z])
						coverage[key] = coordinates
					FileAccess.open(OUT+label+"-native-triangles.json",FileAccess.WRITE).store_string(JSON.stringify(coverage))
					var instance := MeshInstance3D.new()
					instance.mesh = joined
					stage.add_child(instance)
					for angle in 3:
						camera.position = [Vector3(6,6,7),Vector3(6,3,-6),Vector3(2,9,1)][angle] * Vector3(eave_sign,1,end_sign)
						camera.look_at(Vector3(eave_sign,1,0))
						for frame in 5: await process_frame
						RenderingServer.force_draw(false)
						root.get_texture().get_image().save_png(OUT+label+"-%d.png"%angle)
					instance.free()
					records.append({"label":label,"triangles":GEO.triangle_faces(joined).size()/3})
	FileAccess.open(OUT+"cases.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	print("COMPACT_VALLEY_CATALOG ",records.size()," cases")
	quit()
