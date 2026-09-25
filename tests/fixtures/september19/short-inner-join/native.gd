extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var world:Node3D=load("res://docs/qa/2026-09-19-manual/97-inner-ledge-levels/fresh-P12/world.scn").instantiate();root.add_child(world)
 var corner:=Vector3(-421.5,28,-349.5)
 var walls:Array=[]
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if "Walls" not in str(node.name) and not node.has_meta("relief_recipe"):continue
  for i in node.multimesh.instance_count:
   var p:Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
   if Vector2(p.origin.x-corner.x,p.origin.z-corner.z).length()>23:continue
   if node.has_meta("relief_recipe"):print("FORM ",p," ",node.get_meta("relief_recipe"))
   else:
    print(node.name," ",p)
    if "Inner" not in str(node.name) and "Outer" not in str(node.name):walls.append(p)
 FileAccess.open("res://tests/fixtures/september19/short-inner-join/native-walls.bin",FileAccess.WRITE).store_var(walls)
 quit()
