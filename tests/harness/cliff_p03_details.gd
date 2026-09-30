extends RefCounted
func run(review:Node3D)->void:
 var views:=[
  {"id":"missing-wall","position":Vector3(511,30,942),"target":Vector3(524,30,948),"fov":65.0},
  {"id":"crest","position":Vector3(504,44,940),"target":Vector3(510,36,954),"fov":65.0},
  {"id":"strip","position":Vector3(491,47,949),"target":Vector3(497,39,954),"fov":60.0},
  {"id":"grass-ledge","position":Vector3(496,47,960),"target":Vector3(499,40,967),"fov":55.0},
  {"id":"rock-face","position":Vector3(541,38,960),"target":Vector3(542,36,973),"fov":60.0}]
 for view:Dictionary in views:
  if not review._views.any(func(v:Dictionary)->bool:return v.id==view.id):review._views.append(view)
 await review._capture_all(10)
 var source:=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").source_code as String
 source=source.replace("_bedrock(env,floor_level,wide_dilated,relief,seed_value,cut)","env.set_meta(\"before_rock\",env.surface.duplicate())\n  _bedrock(env,floor_level,wide_dilated,relief,seed_value,cut)")
 var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK)
 var input:Dictionary=review._inputs[Vector2i(2,5)]
 var area:=Rect2(484,936,64,40)
 var field=load("res://scripts/terrain/field/CliffSlopeField.gd").new([],2697992464,input.region,area,input.features,input.water)
 var env=script.build(area,field._ground_sampler(),field._exclusion(area),2697992464,field._water_level())
 var rows:=[]
 for q:Vector2 in [Vector2(497,953),Vector2(499,953),Vector2(501,953),Vector2(506,948),Vector2(516,948),Vector2(530,948),Vector2(499,967)]:
  var i:=roundi((q.x-env.origin.x)/.5);var k:=roundi((q.y-env.origin.y)/.5)
  rows.append({"q":str(q),"ground":env.ground[k*env.w+i],"before_rock":env.get_meta("before_rock")[k*env.w+i],"surface":env.at(q),"rock":env.rock_at(q),"excluded":field._exclusion(area).call(q)})
 FileAccess.open(review._output_dir+"/local-field.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("[p03_local_field] ",JSON.stringify(rows))
