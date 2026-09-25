extends GutTest

func test_near_obstacle_reveal_expands_to_viewport_with_fixed_player_neighbourhood() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native shader rendering")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8,8)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = 'shader_type canvas_item;\n#include "res://scripts/camera/visibility_bubble.gdshaderinc"\nuniform vec3 probe; uniform bool receiver_mode = false; void fragment() { COLOR = vec4(vec3(receiver_mode ? tactical_receiver_mask(probe.xy) : tactical_coverage(probe)), 1.0); }'
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0,1,30)
	material.set_shader_parameter("tactical_eye",camera.position)
	material.set_shader_parameter("tactical_feet",Vector3.ZERO)
	# Production half-width at the player's depth for a 16:9, 75 degree view.
	var half_width := 30.0*tan(deg_to_rad(75.0)*0.5)*16.0/9.0
	var radius := half_width*.5
	material.set_shader_parameter("tactical_radius",radius)
	var rect := ColorRect.new()
	rect.size = Vector2(8,8)
	rect.material = material
	viewport.add_child(rect)
	# These are screen-space rays expressed on obstacle planes, not samples
	# chosen relative to the implementation's radius formula.
	for sample in [
		[Vector3(half_width*.60,1,1),false,"far obstacle outside original player neighbourhood"],
		[Vector3(half_width*.30,1,1),true,"far obstacle within player neighbourhood"],
		[Vector3(half_width*.30,1,15),true,"half-depth obstacle reveals beyond old projected circle"],
		[Vector3(half_width/30,1+half_width/30*9/16,29),true,"one-metre obstacle clears viewport corner"],
		[Vector3(-half_width/30,1-half_width/30*9/16,29),true,"opposite viewport corner also clears"],
		[Vector3(0,1,-2),false,"ordinary geometry behind actor remains opaque"],
		[Vector3(0,1,31),false,"outside the finite camera segment"]]:
		material.set_shader_parameter("probe",sample[0])
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		var value := viewport.get_texture().get_image().get_pixel(4,4).r
		if sample[1]: assert_gt(value,.99,sample[2])
		else: assert_lt(value,.01,sample[2])

	# A filled ground image has no hole at the viewport border. Feathering
	# must not leave a rectangular trace of the canopy there.
	var ground := Image.create(64,64,false,Image.FORMAT_RGB8)
	ground.fill(Color(1,0,0))
	material.set_shader_parameter("tactical_ground_depth",ImageTexture.create_from_image(ground))
	material.set_shader_parameter("tactical_receiver_texel",Vector2.ONE/64.0)
	material.set_shader_parameter("receiver_mode",true)
	for uv in [Vector2(.001,.001),Vector2(.999,.999),Vector2(.5,.5)]:
		material.set_shader_parameter("probe",Vector3(uv.x,uv.y,0))
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		assert_gt(viewport.get_texture().get_image().get_pixel(4,4).r,.99,"Full ground support also clears the viewport boundary")
