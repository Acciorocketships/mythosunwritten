extends RefCounted
## cliff_site_review probe: world hit under chosen pixels of the side12 view.
func run(review) -> void:
	var cam: Camera3D = review._camera
	cam.fov = 60.0
	cam.look_at_from_position(Vector3(360, 95, 960), Vector3(397, 66, 925), Vector3.UP)
	cam.force_update_transform()
	await review.get_tree().process_frame
	var space := cam.get_world_3d().direct_space_state
	var lines := PackedStringArray()
	for px: Vector2 in [Vector2(1170, 480), Vector2(1200, 450), Vector2(1230, 420), Vector2(1030, 520), Vector2(1050, 470)]:
		var o := cam.project_ray_origin(px)
		var d := cam.project_ray_normal(px)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 400.0))
		lines.append("%s -> %s %s" % [px, hit.get("position", "none"), hit.get("collider", null)])
	FileAccess.open(review._output_dir + "/rays.txt", FileAccess.WRITE).store_string("\n".join(lines))
	print("[ray_probe] done")
