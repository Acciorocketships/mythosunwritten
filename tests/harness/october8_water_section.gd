extends SceneTree
const E=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
func _init() -> void:
	var fixture:="/tmp/oct8-trial-water-inputs.var.gz" if "--trial" in OS.get_cmdline_user_args() else "res://tests/fixtures/october8/water-inputs.var.gz"
	var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes(fixture).decompress_dynamic(100000000,FileAccess.COMPRESSION_GZIP))
	var region:=HeightfieldRegion.new(d.storeys,d.levels,d.carved)
	region.native_control_heights=d.native
	var wr:=HeightfieldRegion.new(d.water_region.storeys,d.water_region.levels,d.water_region.carved)
	wr.native_control_heights=d.water_region.native
	var water:=WaterFieldContext.new()
	water._region=wr;water._coverage=d.coverage
	water._ctx={"ponds":[],"rivers":[],"buckets":{},"region":wr,"fill":d.water,"fill_base":d.fill_base,"fill_size":d.fill_size}
	var ground:=func(p:Vector2)->float:return TerrainTileField.surface_y(region,p.x,p.y)
	var wet:=func(p:Vector2)->float:return water.level_at(p) if water.covers(p) else NAN
	var capture:Dictionary={}
	var env=E._build(Rect2(462,1090,48,64),ground,Callable(),2697992464,wet,Callable(),Callable(),true,1,capture)
	var walls:=E._walls(env,env.ground,ground,E._levels(env,wet))
	walls[2].fill(-INF)
	var no_corners:=E._close_walls(env.ground,walls,env.w,env.h,E.TIGHT.x,E.TIGHT.y)
	for z in range(1104,1145,2):
		var p:=Vector2(490,z)
		var idx:int=roundi((p.y-env.origin.y)/E.H)*env.w+roundi((p.x-env.origin.x)/E.H)
		print("SECTION ",p," ground=",ground.call(p)," water=",wet.call(p)," sheet=",env.at(p)," crest=",Vector2(capture.crest0[idx],capture.crest1[idx]))
	var failures:=0
	var samples:Array=[]
	for river:Dictionary in d.rivers:
		for i in river.points.size():
			if Rect2(440,1090,70,74).has_point(river.points[i]):
				var at:Vector2=river.points[i]
				var cell:Vector2i=Vector2i(((at-env.origin)/E.H).round())
				var idx:int=clampi(cell.y*env.w+cell.x,0,env.ground.size()-1)
				var stages:Dictionary={}
				for key in ["narrow","wide","tight","tight_wide","blend","fillet","bedrock","channel"]:stages[key]=capture[key][idx]
				stages["no_corners_tight"]=no_corners[idx]
				var level:float=wet.call(at)
				var bed:float=ground.call(at)
				var sheet:float=env.at(at)
				if is_finite(level) and level>bed and sheet>=level:failures+=1
				samples.append({"x":at.x,"z":at.y,"raw_bed":river.beds[i],"profile":river.profile.levels[i],"kernel":bed,"water":level if is_finite(level) else null,"sheet":sheet,"stages":stages})
				print("STAGES ",at," ",stages)
				print("TRACE ",river.points[i]," bed=",river.beds[i]," width=",river.widths[i]," profile=",river.profile.levels[i]," ground=",ground.call(river.points[i])," water=",wet.call(river.points[i])," sheet=",env.at(river.points[i]))
	var path_samples:=0
	var path_buried:=0
	var path_worst:=0.0
	for river:Dictionary in d.rivers:
		for i in range(1,river.points.size()):
			var a:Vector2=river.points[i-1];var b:Vector2=river.points[i]
			var steps:=ceili(a.distance_to(b)/.5)
			for j in steps:
				var at:=a.lerp(b,float(j)/steps)
				if not Rect2(440,1090,70,74).has_point(at):continue
				path_samples+=1
				var level:float=wet.call(at)
				if not is_finite(level) or env.at(at)>=level:
					path_buried+=1
					if is_finite(level):path_worst=maxf(path_worst,env.at(at)-level)
	print("WATER_PATH samples=",path_samples," buried=",path_buried," worst=",path_worst)
	var wet_samples:=0
	var buried_samples:=0
	var worst:=0.0
	var worst_at:=Vector2.ZERO
	for z in range(1090,1154):
		for x in range(462,510):
			var at:=Vector2(x,z)
			var level:float=wet.call(at)
			if not is_finite(level) or level<=ground.call(at)+.05:continue
			wet_samples+=1
			var above:float=env.at(at)-level
			if above>=0.0:buried_samples+=1
			if above>worst:worst=above;worst_at=at
	print("WATER_GRID wet=",wet_samples," buried=",buried_samples," worst=",worst," at=",worst_at)
	FileAccess.open("/tmp/oct8-section.var.gz",FileAccess.WRITE).store_buffer(var_to_bytes({"origin":env.origin,"w":env.w,"h":env.h,"g":env.ground,"surface":env.surface,"stages":capture}).compress(FileAccess.COMPRESSION_GZIP))
	FileAccess.open("/tmp/oct8-water-sections.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":2697992464,"buried_centerline_samples":failures,"path_samples":path_samples,"path_buried":path_buried,"path_worst":path_worst,"samples":samples},"  "))
	print("WATER_CLEARANCE buried_centerline_samples=",failures)
	quit(1 if "--verify-water" in OS.get_cmdline_user_args() and (failures>0 or path_buried>0) else 0)
