extends GutTest

func test_actual_shader_protects_rising_ground_and_tapers_toward_the_camera() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Shader coverage is verified with the graphical renderer")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8,8)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = 'shader_type canvas_item;\n#include "res://scripts/camera/visibility_bubble.gdshaderinc"\nuniform vec3 probe; void fragment() { COLOR = vec4(vec3(tactical_coverage(probe)), 1.0); }'
	material.set_shader_parameter("tactical_eye", Vector3(0,16,26))
	material.set_shader_parameter("tactical_feet", Vector3.ZERO)
	material.set_shader_parameter("tactical_floor_y", 0.0)
	var rect := ColorRect.new()
	rect.size = Vector2(8,8)
	rect.material = material
	viewport.add_child(rect)
	for sample in [
		[Vector3(0,0.6,2), false, "rising ground below the projected feet"],
		[Vector3(2,13,21), false, "near-camera geometry outside the tapered cone"],
		[Vector3(0,0,2), false, "supporting ground"],
		[Vector3(2,3,3), true, "neighbouring building component"],
		[Vector3(0,4,4), true, "a hill genuinely obscuring the character"]]:
		material.set_shader_parameter("probe", sample[0])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var coverage := viewport.get_texture().get_image().get_pixel(4,4).r
		if sample[1]: assert_gt(coverage, 0.5, sample[2])
		else: assert_lt(coverage, 0.01, sample[2])
