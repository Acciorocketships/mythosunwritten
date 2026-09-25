extends "res://tests/harness/warren_maze_mode_sweep.gd"
func _run() -> void:
	var directory := "res://docs/qa/2026-09-13-manual/20-civic/"
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var reports := {}
	for variant: String in ["well","campfire"]:
		for original: bool in [true,false]:
			var label := variant+"/"+("before" if original else "after")
			var data: Dictionary = FileAccess.open(directory+label+"-payload.bin",FileAccess.READ).get_var()
			var payload := preload("res://tests/fixtures/september11/floating_payload.gd").payload(data,false)
			cache.prepare(payload.asset_ids())
			var stage := Node3D.new()
			root.add_child(stage)
			EnvironmentCollisionBuilder.commit(stage,payload,cache,&"CivicClearance")
			await physics_frame
			await physics_frame
			var space := root.world_3d.direct_space_state
			var capsule := CapsuleShape3D.new()
			capsule.radius = PLAYER_CAPSULE_RADIUS
			capsule.height = PLAYER_CAPSULE_HEIGHT
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.margin = CLEARANCE_MARGIN
			var checked := 0
			var blocked := []
			for route: Dictionary in data.routes:
				if not String(route.owner).contains(".square."): continue
				for shape: FeatureGroundShape in PathProgram.filleted_path_shapes(route.points,2,0,0,&"survey"):
					var tangent := (shape._b-shape._a).normalized()
					var normal := Vector2(-tangent.y,tangent.x)
					var steps := maxi(1,ceili(shape._a.distance_to(shape._b)/0.5))
					for offset: float in [-1.5,0,1.5]:
						for index in range(steps+1):
							var point := shape._a.lerp(shape._b,float(index)/steps)+normal*offset
							query.transform = Transform3D(Basis.IDENTITY,Vector3(point.x,12+PLAYER_CAPSULE_HEIGHT/2+CLEARANCE_MARGIN+0.03,point.y))
							checked += 1
							if not space.intersect_shape(query,1).is_empty(): blocked.append({"point":str(point),"route":str(route.owner),"offset":offset})
			reports[label] = {"checked":checked,"blocked":blocked}
			print("CIVIC_CLEARANCE ",label," checked=",checked," blocked=",blocked.size())
			stage.free()
			await physics_frame
	FileAccess.open(directory+"clearance.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	for report: Dictionary in reports.values(): assert(report.blocked.is_empty(), "The native civic walking corridor must remain clear")
	quit()
