extends GutTest
## A remote shelf must not flatten a face merely because its 2D projection overlaps.
func _source()->GDScript:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 return load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
func test_distant_shelf_does_not_suppress_physical_rock_relief()->void:
 var source:GDScript=_source()
 source.prepare()
 var faces:=PackedVector3Array()
 for x in 48:
  for y in 40:
   var a:=Vector3(-6+x*.25,y*.2,3.0)
   var b:=a+Vector3(.25,0,0);var c:=a+Vector3(0,.2,0);var d:=a+Vector3(.25,.2,0)
   faces.append_array(PackedVector3Array([a,c,b,b,c,d]))
 var plain:=faces.duplicate()
 source._shape_stone_faces(plain,PackedVector3Array(),{},-13.5,12,8,2698134800,false,false)
 var remote:=PackedVector3Array([Vector3(-6,3.5,6),Vector3(6,3.5,6),Vector3(6,3.5,8),Vector3(-6,3.5,6),Vector3(6,3.5,8),Vector3(-6,3.5,8)])
 # Include the distant physical shelf in the same owner, as a deep curved tread can be.
 var combined:=faces.duplicate();combined.append_array(remote)
 source._shape_stone_faces(combined,remote,{},-13.5,12,8,2698134800,false,false)
 var suppressed:=0;var relief:=0
 for i in faces.size():
  if plain[i].z-faces[i].z>.08:relief+=1
  if plain[i].z-combined[i].z>.001:suppressed+=1
 print("SPATIAL_RELIEF actual_relief=",relief," falsely_suppressed=",suppressed)
 assert_gt(relief,100,"The control contains measurable physical rock bumps")
 assert_eq(suppressed,0,"A shelf three metres farther out must not flatten the unrelated face")
