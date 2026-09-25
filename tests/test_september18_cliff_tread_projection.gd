extends GutTest

func test_projection_preserves_physical_tread_grade()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 if path.is_empty():path="res://scripts/terrain/field/CliffRockCrags.gd"
 # Observe semantic tread endpoints around the real projection pass. Matching
 # old (x,z) positions is invalid when new physical outcrops move those ledges.
 # This test-only copy adds no geometry; measurements are checked against its
 # final closed collision shell, including treads rejected by turf classification.
 var code:=FileAccess.get_file_as_string(path)
 var marker:="  columns.append(points);column_bands.append(bands)"
 assert_true(code.contains(marker))
 code=code.replace("var detail_cache:Dictionary={}","var detail_cache:Dictionary={}\n var tread_audit:Array=[]")
 code=code.replace(marker,"""  for audit_band:Array in bands:
   if not audit_band[2]:continue
   var ai:int=audit_band[0];var bi:int=audit_band[1]
   var old_width:float=original_points[bi].z-original_points[ai].z
   if old_width>.15:
    tread_audit.append([points[ai],points[bi],(original_points[ai].y-original_points[bi].y)/old_width])
"""+marker)
 code=code.replace('return [{"faces":faces', 'return [{"tread_audit":tread_audit,"faces":faces')
 var source:=GDScript.new();source.source_code=code
 assert_eq(source.reload(),OK)
 var checked:=0;var missing:=0;var steepened:=0;var worst:=0.0
 for height:float in [8,32]:
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
  var form:Dictionary=source.make(pose,48,height,2697992464)[0]
  var vertices:Dictionary={}
  for p:Vector3 in form.faces:vertices[p.snapped(Vector3.ONE*.0001)]=true
  for section:Array in form.tread_audit:
   var a:Vector3=section[0].snapped(Vector3.ONE*.0001)
   var b:Vector3=section[1].snapped(Vector3.ONE*.0001)
   if b.z-a.z<.15 or float(section[2])<.01:continue
   if not vertices.has(a) or not vertices.has(b):missing+=1;continue
   checked+=1
   var excess:float=(a.y-b.y)/(b.z-a.z)-float(section[2]);worst=maxf(worst,excess)
   if excess>.02:steepened+=1
 print("ACTUAL_TREADS checked=",checked," missing=",missing," steepened=",steepened," max_excess=",worst)
 assert_eq(missing,0,"Every measured cap endpoint must exist in the actual collision/rendered shell")
 assert_gt(checked,400)
 assert_eq(steepened,0,"Final body shaping must preserve a ledge's intended shallow grade")
