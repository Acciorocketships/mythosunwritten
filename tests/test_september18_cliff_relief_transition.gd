extends GutTest
const RAW=preload("res://tests/fixtures/september18/cliff-relief-transitions/unshaped.gd")

func test_tall_ledge_transition_has_no_truncated_blend_step()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 var raw:PackedVector3Array=RAW.make(pose,48,32,2697992464)[0].faces
 var faces:PackedVector3Array=source.make(pose,48,32,2697992464)[0].faces
 # Reported study region: compare added relief across one 25 cm mesh interval,
 # excluding the underlying wall's own slope. The old truncated ledge search
 # adds a 65 cm sideways step here despite the broad intended blend.
 var samples:Dictionary={}
 for i in raw.size():
  var p:Vector3=raw[i]
  if p.z<=0.0 or absf(p.y-13.8)>.001:continue
  if absf(p.x+23.0)<.001 or absf(p.x+22.75)<.001:
   samples[p.x]=faces[i].z-p.z
 assert_eq(samples.size(),2,"Both sides of the sampled ledge transition must exist")
 if samples.size()!=2:return
 var step:float=absf(samples[-23.0]-samples[-22.75])
 print("LEDGE_RELIEF_STEP ",step)
 assert_lt(step,.45,"Added relief must not create a thin fin at the protection search boundary")
