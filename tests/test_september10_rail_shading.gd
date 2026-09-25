extends GutTest
const Builder = preload("res://scripts/terrain/features/villages/fabric/WarrenTransitionSurfaceBuilder.gd")

func test_guard_beams_and_posts_shade_their_outer_faces_in_all_orientations() -> void:
	for quarter in 4:
		var rotate := Basis(Vector3.UP,quarter*PI*0.5)
		for end: Vector3 in [Vector3(0,1.5,0),Vector3(0,1.5,3),Vector3(0,0,3)]:
			var payload := Builder._empty_payload(&"guard-shading",[] as Array[Vector3i])
			Builder._append_beam(payload,Vector3.ZERO,rotate*end,0.22)
			var center := rotate*end*0.5
			for face in 6:
				var i := face*4
				var face_center: Vector3 = (payload.vertices[i]+payload.vertices[i+1]+payload.vertices[i+2]+payload.vertices[i+3])*0.25
				assert_gt((face_center-center).dot(payload.normals[i]),0.0,"Every exposed timber side/end must shade outward")
				var offset := face*6
				var a: Vector3 = payload.vertices[payload.indices[offset]]
				var b: Vector3 = payload.vertices[payload.indices[offset+1]]
				var c: Vector3 = payload.vertices[payload.indices[offset+2]]
				assert_gt((face_center-center).dot(-(b-a).cross(c-a)),0.0,"Godot's clockwise front face must face outside the solid timber")
