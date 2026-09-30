extends RefCounted
## Review probe for cliff_site_review: before a hot reload, refresh the
## listed class scripts outside the harness RELOAD list (and every terrain
## material shader include, as the reload itself now also does).
##   echo res://tests/harness/shader_include_reload_probe.gd > <output>/probe
const SCRIPTS := ["res://scripts/terrain/dressing/DressingCompiler.gd", "res://scripts/terrain/dressing/DressingField.gd"]

func run(_review: Node) -> void:
	var dir := "res://terrain/materials/"
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gdshaderinc"):
			var include := load(dir + file) as ShaderInclude
			include.code = FileAccess.get_file_as_string(dir + file)
	for path: String in SCRIPTS:
		var script := load(path) as GDScript
		script.source_code = FileAccess.get_file_as_string(path)
		print("[include_reload] ", path, " ", script.reload(false))
	print("[include_reload] done")
