extends SceneTree
func _init() -> void:
	for f in DirAccess.get_files_at("res://scripts/terrain/field"):
		if f.ends_with(".gd"):
			var s = load("res://scripts/terrain/field/" + f)
			if s == null or not (s as GDScript).can_instantiate(): print("BROKEN ", f)
	print("CHECKED")
	quit()
