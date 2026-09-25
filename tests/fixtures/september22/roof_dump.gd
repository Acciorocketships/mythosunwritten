extends SceneTree
## Dumps every roof run of a frozen town and whether the continuous roof plan joined it.
const FROZEN=preload("res://tests/fixtures/frozen_maze_source.gd")
func _init()->void:
	if OS.has_environment("ROOF_TRACE"): WarrenSpatialFabricCompiler.diagnostic_trace_timing=true
	var town:="town-e"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town="):town=arg.trim_prefix("--town=")
	var dir:="res://docs/qa/2026-09-22-manual/"+town
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source:=FROZEN.read(dir.path_join("source.txt"))
	var fabric:=FROZEN.spatial(source,program).compiled_fabric_cache()
	var saved:Dictionary=FileAccess.open(dir.path_join("payload.bin"),FileAccess.READ).get_var()
	var world:Transform3D=saved.transform
	var roofs:=fabric.continuous_roof_plan
	var joined:={}
	for run in roofs.compiled_runs: joined[run.unit_id]=false
	var rows:=[]
	for run:Dictionary in roofs.compiled_runs:
		var s:Vector3=world*(run.start as Vector3); var e:Vector3=world*(run.end as Vector3)
		var row:={"unit":String(run.unit_id),"kind":String(run.kind),"start":s,"end":e,"axis_x":run.axis_x,"cross":[run.cross_min,run.cross_max],"base_y":run.base_y,"peak_y":run.peak_y,"material":String(run.get("authored_material",""))}
		rows.append(row)
		print("RUN ",row.unit," ",row.kind," start=",s.snappedf(.01)," end=",e.snappedf(.01)," axisx=",run.axis_x," cross=",[snappedf(run.cross_min,.01),snappedf(run.cross_max,.01)]," base=",snappedf(run.base_y,.01)," peak=",snappedf(run.peak_y,.01)," mat=",row.material)
	print("AUDIT ",roofs.audit())
	for c in roofs.components: print("COMPONENT ",c)
	# Room footprints (occupied solid cells) grouped by unit, to reason about adjacency.
	for unit:FabricUnit in fabric.units:
		var recipe:=fabric.recipe(unit.recipe_id)
		if recipe==null or not (recipe.has_tag(&"room") or recipe.compact_roof_runs.size()>0): continue
		print("UNIT ",unit.stable_id," recipe=",unit.recipe_id," origin=",unit.lattice_origin," yaw=",unit.yaw_quarters," tags=",recipe.role_tags)
	quit()
