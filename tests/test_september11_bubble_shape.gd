extends GutTest

func test_actual_coverage_has_no_lower_horizontal_cutoff() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires shader execution")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8,8)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = 'shader_type canvas_item;\n#include "res://scripts/camera/visibility_bubble.gdshaderinc"\nuniform vec3 probe; void fragment(){ COLOR=vec4(vec3(tactical_coverage(probe)),1.0); }'
	var eye := Vector3(0,16,26)
	material.set_shader_parameter("tactical_eye",eye)
	material.set_shader_parameter("tactical_feet",Vector3.ZERO)
	material.set_shader_parameter("tactical_radius",3.8)
	var rect := ColorRect.new()
	rect.size = Vector2(8,8)
	rect.material = material
	viewport.add_child(rect)
	var axis := (eye-Vector3.UP).normalized()
	var up := (Vector3.UP-axis*axis.y).normalized()
	var centre := Vector3.UP+axis*8.0
	for index in 16:
		var angle := TAU*index/16.0
		var point := centre+(up*cos(angle)+Vector3.RIGHT*sin(angle))*1.8
		material.set_shader_parameter("probe",point)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var value := viewport.get_texture().get_image().get_pixel(4,4).r
		assert_gt(value,.99,"The complete projected circle covers angle %d, including its lower half" % index)

func test_radius_projects_to_half_the_viewport_width_in_both_camera_aspect_modes() -> void:
	var viewport := SubViewport.new()
	add_child_autofree(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0,16,26)
	camera.look_at(Vector3.UP)
	camera.fov = 50.0
	for size: Vector2i in [Vector2i(1920,1080),Vector2i(1080,1080),Vector2i(2560,1080)]:
		viewport.size = size
		for aspect in [Camera3D.KEEP_HEIGHT,Camera3D.KEEP_WIDTH]:
			camera.keep_aspect = aspect
			var radius := CameraVisibilityBubble.screen_radius(camera,Vector3.ZERO,.5)
			var centre := camera.unproject_position(Vector3.UP)
			var edge := camera.unproject_position(Vector3.UP+camera.global_basis.x*radius)
			assert_almost_eq(edge.x-centre.x,size.x*.25,.01,"Half-width diameter survives aspect and projection mode")
