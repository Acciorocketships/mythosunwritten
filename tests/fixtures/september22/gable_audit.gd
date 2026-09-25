extends SceneTree
## For every realized roof placement with an exterior gable, measures the gable
## base plane (roof vertices within 0.35 local of the eave datum at the run's end)
## against the run's end wall plane. Negative = recessed behind the facade.
const FROZEN=preload("res://tests/fixtures/frozen_maze_source.gd")
func _init()->void:
	var town:="town-e"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town="):town=arg.trim_prefix("--town=")
	var dir:="res://docs/qa/2026-09-22-manual/"+town
	var catalog:=EnvironmentCatalog.load_default()
	var program:=SettlementFabricProgram.compile(catalog)
	var fabric:=FROZEN.spatial(FROZEN.read(dir.path_join("source.txt")),program).compiled_fabric_cache()
	var runs:=fabric.continuous_roof_plan.compiled_runs
	var faces_cache:={}
	for p:Dictionary in fabric.expanded_placements():
		var asset:=String(p.asset_id)
		if not asset.begins_with("lpfv.fabric.roof.compact"): continue
		var id:=String(p.stable_id)
		var run:Dictionary={}
		for r:Dictionary in runs:
			if id.begins_with(String(r.unit_id)+"/"): run=r
		if run.is_empty(): continue
		if not faces_cache.has(asset):
			var visual:EnvironmentVisual=load(catalog.descriptor(StringName(asset)).visual_path)
			var pts:=PackedVector3Array()
			for piece:EnvironmentVisualPiece in visual.pieces: pts.append_array(EnvironmentBakeGeometry.triangle_faces(piece.mesh,piece.local_transform))
			faces_cache[asset]=pts
		var t:Transform3D=p.transform
		var axis_x:bool=run.axis_x
		var lo:=INF; var hi:=-INF
		for v: Vector3 in faces_cache[asset]:
			var w: Vector3 = t*v
			if w.y>float(run.base_y)+0.35: continue
			var a: float = w.x if axis_x else w.z
			lo=minf(lo,a); hi=maxf(hi,a)
		var s:=(run.start as Vector3).x if axis_x else (run.start as Vector3).z
		var e:=(run.end as Vector3).x if axis_x else (run.end as Vector3).z
		# Only pieces reaching an end of their run carry that exterior gable.
		if absf(lo-s)<0.6: print("GABLE ",id," ",asset," start_offset=",snappedf(s-lo,.001))
		if absf(hi-e)<0.6: print("GABLE ",id," ",asset," end_offset=",snappedf(hi-e,.001))
	quit()
