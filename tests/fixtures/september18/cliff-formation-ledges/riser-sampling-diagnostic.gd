extends GutTest
func test_photo_exposed_risers_have_vertices_for_physical_relief()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var a:Array=anchors[20]
 var rock:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 var turf:Dictionary={}
 for p:Vector3 in rock.green:turf[p]=true
 var maximum:=0.0;var unresolved:=0
 for i in range(0,rock.faces.size(),3):
  for j in 3:
   var p:Vector3=rock.faces[i+j];var q:Vector3=rock.faces[i+(j+1)%3]
   if minf(p.z,q.z)<=0.0 or (turf.has(p) and turf.has(q)):continue
   if absf(p.x)>=a[1]*.5-.001 or absf(q.x)>=a[1]*.5-.001:continue
   var span:=absf(p.y-q.y)
   maximum=maxf(maximum,span)
   if span>.651:unresolved+=1
 print("RISER_SAMPLING maximum=",maximum," unresolved=",unresolved," triangles=",rock.faces.size()/3)
 assert_eq(unresolved,0,"Exposed risers need intermediate physical vertices rather than long unshapeable faces")
