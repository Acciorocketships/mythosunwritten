extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var fixture:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-fixture.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(fixture.w-1,fixture.h-1));return p.y*fixture.w+p.x
 var ground:=func(q:Vector2)->float:return fixture.ground[index.call(q)]
 var style=load("res://scripts/terrain/field/CliffRockStyle.gd")
 var output:={}
 var smooth
 for mode:String in ["smooth","before","upright","after"]:
  var script=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
  if mode in ["before","upright"]:
   script=GDScript.new();script.source_code=FileAccess.get_file_as_string("res://docs/qa/2026-09-26-rock-ledge-restoration/"+("before" if mode=="before" else "upright")+"-envelope.gd.txt");assert(script.reload()==OK)
  style.apply("sheet" if mode=="smooth" else "sheet_bedrock")
  var env=script.build(Rect2(476,924,92,96),ground,func(q:Vector2)->bool:return fixture.excluded[index.call(q)]!=0,2697992464,func(q:Vector2)->float:return fixture.wet[index.call(q)])
  if mode=="smooth":smooth=env;continue
  var tread:=0;var faces:=0;var max_raise:=0.0;var min_raise:=0.0;var wide:=0;var patches:={};var examples:=[];var deviations:=[];var face_grades:=[]
  for x in range(960,1113):
   for z in range(1856,2017):
    var q:=Vector2(x,z)*.5
    if env.rock_at(q)<.6:continue
    var dx:=Vector2(.5,0);var dz:=Vector2(0,.5)
    var base_gradient:=Vector2(smooth.at(q+dx)-smooth.at(q-dx),smooth.at(q+dz)-smooth.at(q-dz))
    var gradient:=Vector2(env.at(q+dx)-env.at(q-dx),env.at(q+dz)-env.at(q-dz))
    var rise:float=env.at(q)-smooth.at(q);max_raise=maxf(max_raise,rise);min_raise=minf(min_raise,rise)
    if gradient.length()>2.0:faces+=1
    if base_gradient.length()>.6 and base_gradient.length()<1.6 and gradient.length()>base_gradient.length()*1.1:
     var a:=Vector3(-base_gradient.x,1,-base_gradient.y).normalized();var b:=Vector3(-gradient.x,1,-gradient.y).normalized()
     deviations.append(rad_to_deg(acos(clampf(a.dot(b),-1,1))))
     face_grades.append(rad_to_deg(atan(gradient.length())))
    if base_gradient.length()>.6 and gradient.length()<.35 and rise>.35:
     tread+=1;patches[Vector2i(q/8.0)]=true
     var fall:=base_gradient.normalized()
     if absf(env.sample(q+fall*.5)-env.sample(q-fall*.5))<.3:wide+=1
     if examples.size()<10:examples.append([q.x,q.y,env.at(q),rise])
  deviations.sort();face_grades.sort()
  output[mode]={"face_samples":deviations.size(),"median_normal_deviation_deg":deviations[deviations.size()/2],"p90_normal_deviation_deg":deviations[int(deviations.size()*.9)],"median_face_grade_deg":face_grades[face_grades.size()/2],"tread_samples":tread,"wide_treads":wide,"patches":patches.size(),"steep_face_samples":faces,"max_raise":max_raise,"min_raise":min_raise,"examples":examples}
 print(JSON.stringify(output," "))
 FileAccess.open("res://docs/qa/2026-09-26-rock-ledge-restoration/ledge-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(output," "))
 quit()
