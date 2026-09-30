extends GutTest
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func after_each()->void:STYLE.apply("sheet_bedrock")
func test_rounded_shoulder_normals_follow_the_continuous_surface()->void:
 STYLE.apply("sheet")
 var field=FIELD.new([],2697992464)
 field.ground_at=func(q:Vector2)->float:return 12.0 if q.y<=0 else 0.0
 var env=field.envelope()
 STYLE.apply("sheet_bedrock")
 var placements=field.solid(Rect2(-3,-3,6,24))
 var maximum:=0.0;var samples:=0
 for p:Dictionary in placements:
  for point:Vector3 in p.native_roots:
   if point.x< -1 or point.x>1 or point.z< -3 or point.z>2:continue
   var q:=Vector2(point.x,point.z)
   var expected:=Vector3(env.sample(q-Vector2(.25,0))-env.sample(q+Vector2(.25,0)),.5,env.sample(q-Vector2(0,.25))-env.sample(q+Vector2(0,.25))).normalized()
   maximum=maxf(maximum,expected.distance_to(p.native_roots[point][0]));samples+=1
 assert_gt(samples,20,"Sample the flat crown and rounded shoulder")
 assert_lt(maximum,.08,"Lighting normals must follow actual surface derivatives, not saturated out-of-band values")

func test_native_plateau_normals_do_not_tilt_toward_absent_mesh_columns()->void:
 STYLE.apply("sheet_bedrock")
 var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1));return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var env=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").build(Rect2(476,924,92,96),ground,func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0,2697992464,func(q:Vector2)->float:return d.wet[index.call(q)])
 var field=FIELD.new([],2697992464);field._env=env;field.ground_at=ground
 var maximum:=0.0;var samples:=0
 for p:Dictionary in field.solid(Rect2(480,930,36,44)):
  for point:Vector3 in p.native_roots:
   var q:=Vector2(point.x,point.z)
   var flat:=true
   for offset:Vector2 in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:
    if absf(env.sample(q+offset)-env.sample(q))>.001:flat=false;break
   if not flat:continue
   maximum=maxf(maximum,Vector3.UP.distance_to(p.native_roots[point][0]));samples+=1
 assert_gt(samples,100,"Actual plateau vertices around the reported mountain")
 assert_lt(maximum,.01,"A flat native plateau must not acquire a false shaded recess")
