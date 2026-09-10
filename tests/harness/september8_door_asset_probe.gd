extends SceneTree
func _init()->void:
	var catalog:=EnvironmentCatalog.load_default()
	for id:StringName in [&"lpfv.fabric.door.closed.01",&"lpfv.fabric.door.closed.02",&"lpfv.building.house.01"]:
		print(id," ",catalog.descriptor(id).measured_aabb)
	quit()
