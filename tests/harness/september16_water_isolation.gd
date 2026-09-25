extends "res://tests/harness/september16_manual_qa.gd"

func _capture_views(world: Node3D) -> void:
	var water_nodes := []
	for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if node.is_in_group("tactical_preserve_surface"): water_nodes.append(node)
	var output := _output_dir
	var base_code := FileAccess.get_file_as_string("res://terrain/water/water_unified.gdshader")
	for phase: String in ["original","no-simulation","no-water","flat-optics"]:
		var code := base_code
		if phase in ["no-simulation","flat-optics"]:
			code = code.replace("return ambient + packet_height_at(world_xz) + ripple_height_at(world_xz);","return ambient;")
			code = code.replace("vec2 interaction_gradient = ripple_normal_gradient(p) * surface_scale;","vec2 interaction_gradient = vec2(0.0);")
			code = code.replace("float packet_h = packet_height_at(p);","float packet_h = 0.0;")
			for sample in ["hx1","hx0","hz1","hz0"]:
				var start := code.find("float packet_" + sample + " =")
				var end := code.find(";",start)
				code = code.substr(0,start) + "float packet_" + sample + " = 0.0" + code.substr(end)
			code = code.replace("texture(packet_tex, packet_uv).g * packet_fade(p)","0.0")
		if phase == "flat-optics":
			code = code.replace("return ambient;","return 0.0;")
			code = code.replace("float depth = water_depth_world(depth_texture, SCREEN_UV,\n\t\tINV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);","float depth = 0.0;")
		var shader := Shader.new(); shader.code = code
		for water: MeshInstance3D in water_nodes:
			water.visible = phase != "no-water"
			var material := water.material_override as ShaderMaterial
			if material == null: material = water.mesh.surface_get_material(0) as ShaderMaterial
			material = material.duplicate()
			material.shader = shader
			water.material_override = material
		_output_dir = output.path_join(phase)
		DirAccess.make_dir_recursive_absolute(_output_dir)
		await super._capture_views(world)
	_output_dir = output
