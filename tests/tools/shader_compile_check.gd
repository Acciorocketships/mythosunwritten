# Headless compile check: loading a Shader resource parses+compiles it;
# any SHADER ERROR prints to stderr and get_code() round-trips the source.
# Run: Godot --headless --path . -s tests/tools/shader_compile_check.gd
extends SceneTree

func _init() -> void:
	for path in [
		"res://terrain/water/water_unified.gdshader",
		"res://terrain/water/waterfall.gdshader",
	]:
		var sh: Shader = load(path)
		if sh == null or sh.get_code().is_empty():
			print("COMPILE-CHECK FAIL: %s" % path)
		else:
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = sh
			print("COMPILE-CHECK OK: %s (%d uniforms)" % [
				path, sh.get_shader_uniform_list().size()])
	quit()
