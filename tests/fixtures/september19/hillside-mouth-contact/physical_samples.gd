extends SceneTree
const FOLDER := "res://docs/qa/2026-09-19-manual/116-hillside-mouth-contact/"
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var reports: Array[Dictionary] = []
	var selected := PackedStringArray(["P10","P21"])
	var survey := "--survey" in OS.get_cmdline_user_args()
	var junction := "--junction" in OS.get_cmdline_user_args()
	var supply := "--supply" in OS.get_cmdline_user_args()
	var supply_points: Array[Vector2] = []
	if supply:
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-19-manual/113-hillside-stable-terrain/supply-route.json"))
		assert(route.termination == "native_terminal")
		for i in route.nodes.size()-1:
			var a := Vector2(route.nodes[i].point[0],route.nodes[i].point[1])
			var b := Vector2(route.nodes[i+1].point[0],route.nodes[i+1].point[1])
			var steps := maxi(1,ceili(a.distance_to(b)/3.0))
			for j in steps: supply_points.append(a.lerp(b,float(j)/steps))
		var last: Dictionary = route.nodes[-1]
		supply_points.append(Vector2(last.point[0],last.point[1]))
		FileAccess.open(FOLDER+"supply-route.json",FileAccess.WRITE).store_string(JSON.stringify(route,"  "))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spots="): selected=arg.trim_prefix("--spots=").split(",")
	for phase: String in ["before","after"]:
		for spot: String in selected:
			var source := "res://docs/qa/2026-09-19-manual/115-hillside-fill-stages/" if phase == "before" else FOLDER
			var stage: Node3D = load(source+"after/"+spot+"/geometry.scn").instantiate()
			root.add_child(stage)
			var water_faces := 0
			var controls: Array[Vector3] = []
			for mesh: MeshInstance3D in stage.find_children("*","MeshInstance3D",true,false):
				if not mesh.is_in_group("tactical_preserve_surface"): continue
				var body := StaticBody3D.new()
				body.collision_layer = 2
				body.collision_mask = 0
				var shape := CollisionShape3D.new()
				shape.shape = mesh.mesh.create_trimesh_shape()
				# Water skins are rendered double-sided; inspect the actual skin
				# from above irrespective of its visual triangle winding.
				shape.shape.backface_collision = true
				body.add_child(shape)
				mesh.add_child(body)
				water_faces += shape.shape.get_faces().size()/3
				var faces: PackedVector3Array = shape.shape.get_faces()
				for i in range(0,faces.size(),3):
					if absf((faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized().y)>.3:
						controls.append(mesh.to_global((faces[i]+faces[i+1]+faces[i+2])/3.0))
						break
			await physics_frame
			var control_hits := 0
			for p: Vector3 in controls:
				var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*.1,p-Vector3.UP*.1,2)
				if not stage.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): control_hits+=1
			if control_hits != controls.size() or controls.is_empty():
				push_error("Water mesh centroid controls failed; survey invalid")
				quit(1)
				return
			await physics_frame
			var pin := Vector2(-1110.7,-757.5) if spot=="P10" else Vector2(-1189.9,-609.4)
			var points: Array[Vector2] = []
			var offsets: Array = range(-120,121,12) if survey else [-12,0,12]
			for z in offsets:
				for x in offsets: points.append(pin+Vector2(x,z))
			if junction:
				points.clear()
				var profiles: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-19-manual/112-hillside-native-reaches/junction-profiles.json"))
				for sample: Dictionary in profiles[0].samples:
					points.append(Vector2(sample.point[0],sample.point[1]))
			if supply: points=supply_points
			var rows: Array[Dictionary] = []
			for p: Vector2 in points:
				var row := {"x":p.x,"z":p.y}
				for mask: int in [1,2]:
					var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,160,p.y),Vector3(p.x,-32,p.y),mask)
					var hit := stage.get_world_3d().direct_space_state.intersect_ray(query)
					row["ground" if mask==1 else "water"] = hit.position.y if not hit.is_empty() else null
				rows.append(row)
			print("NATIVE_WATER_SAMPLES ",phase," ",spot," water_faces=",water_faces," probes=",rows.size())
			reports.append({"phase":phase,"spot":spot,"water_faces":water_faces,"samples":rows,"water_controls":controls.size(),"control_hits":control_hits})
			stage.free()
			await physics_frame
	FileAccess.open(FOLDER+("supply-" if supply else ("junction-" if junction else ("survey-" if survey else "physical-")))+"-".join(selected)+".json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	quit()
