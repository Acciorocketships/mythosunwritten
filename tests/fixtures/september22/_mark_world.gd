extends SceneTree
func _init():
	for path in OS.get_cmdline_user_args():
		var data: Dictionary = FileAccess.open(path, FileAccess.READ).get_var()
		data["world_space"] = true
		FileAccess.open(path, FileAccess.WRITE).store_var(data)
	quit()
