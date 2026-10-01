extends SceneTree
func _initialize()->void:
 var water:=TerrainWorldTuning.make_water(2697992464)
 var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
 var base:=Vector2(-1248,-816);var side:=41;var rows:=49
 var rect:=Rect2(base,Vector2(side-1,rows-1)*6)
 var region:=plan.compute_rect_region(Rect2i(Vector2i((rect.position/24).floor())-Vector2i.ONE*3,Vector2i((rect.size/24).ceil())+Vector2i.ONE*7))
 var sources:=water.bodies_in_rect(rect)
 var ground:=WaterField._sample_ground_lattice(region,base,side,6,rows)
 var samplers:Array[WaterSampler]=[]
 for values:Dictionary in FileAccess.open("res://docs/qa/2026-09-16-manual/03-water-flow/production-final/P10/samplers.bin",FileAccess.READ).get_var():
  var sampler:=WaterSampler.new()
  for key:String in values:sampler.set(key,values[key])
  samplers.append(sampler)
 var seed_owners:Dictionary={};var river_reports:=[]
 for river:RiverTrace in sources.rivers:
  var levels:=ground.duplicate();levels.fill(-INF)
  var heads:=levels.duplicate();var queue:=PriorityQueue.new()
  WaterField._seed_rivers({"water":water,"rivers":[river],"ponds":sources.ponds},region,base,side,levels,ground,heads,queue)
  for entry:Dictionary in queue.heap:
   var index:int=entry.item[0]
   if not seed_owners.has(index):seed_owners[index]=[]
   seed_owners[index].append({"source":str(river.source_cell),"head":entry.item[1]})
  var nearest:=0;var distance:=INF;var point:=Vector2(-1190.7,-604.5)
  for i in river.points.size():
   if river.points[i].distance_to(point)<distance:distance=river.points[i].distance_to(point);nearest=i
  var owned:=WaterField._trace_owned_region(river,plan,region)
  var profile:=WaterField.profile(river,region)
  var centerline:=[]
  for i in river.points.size():
   var p:Vector2=river.points[i]
   centerline.append({"x":p.x,"z":p.y,"ground":TerrainTileField.surface_y(owned,p.x,p.y),"bed":river.beds[i],"head":profile.levels[i]})
  river_reports.append({"source":str(river.source_cell),"source_pool":river.source_pool!=null,"nearest":str(river.points[nearest]),"bed":river.beds[nearest],"width":river.widths[nearest],"level":profile.levels[nearest],"ground":TerrainTileField.surface_y(region,river.points[nearest].x,river.points[nearest].y),"centerline":centerline})
  queue.free()
 var samples:=[]
 for j in rows:
  for i in side:
   var p:=base+Vector2(i,j)*6;var level:=NAN
   for sampler:WaterSampler in samplers:
    level=sampler.level_at(p)
    if is_finite(level):break
   var index:=j*side+i
   samples.append({"x":p.x,"z":p.y,"ground":ground[index],"level":level if is_finite(level) else null,"sources":seed_owners.get(index,[])})
 var path:="res://docs/qa/2026-09-16-manual/17-hillside-sources"
 DirAccess.make_dir_recursive_absolute(path)
 FileAccess.open(path+"/probe.json",FileAccess.WRITE).store_string(JSON.stringify({"rivers":river_reports,"samples":samples},"  "))
 for report:Dictionary in river_reports:
  var summary:=report.duplicate();summary.erase("centerline")
  print("HILLSIDE_SOURCE ",JSON.stringify(summary))
 for sample:Dictionary in samples:
  if Vector2(sample.x,sample.z).distance_to(Vector2(-1190.7,-604.5))<12:print("HILLSIDE_SAMPLE ",JSON.stringify(sample))
 quit()
