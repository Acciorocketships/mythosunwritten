extends SceneTree
## Prints realized placement bounds (world) whose stable id contains a needle.
const FROZEN=preload("res://tests/fixtures/frozen_maze_source.gd")
func _init()->void:
	var town:="town-e"; var needles:=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town="):town=arg.trim_prefix("--town=")
		elif arg.begins_with("--"): pass
		else: needles.append(arg)
	var dir:="res://docs/qa/2026-09-22-manual/"+town
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var fabric:=FROZEN.spatial(FROZEN.read(dir.path_join("source.txt")),program).compiled_fabric_cache()
	var world:Transform3D=(FileAccess.open(dir.path_join("payload.bin"),FileAccess.READ).get_var() as Dictionary).transform
	for p:Dictionary in fabric.expanded_placements():
		var id:=String(p.get("stable_id",""))
		for n in needles:
			if n in id:
				var b:AABB=world*(p.bounds as AABB)
				print("B ",id," ",p.asset_id," min=",b.position.snappedf(.01)," max=",b.end.snappedf(.01))
				break
	quit()
