extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/101-short-corner-runs/"
const RELIEF=preload("res://scripts/terrain/field/CliffRockRelief.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var world:Node3D=load("res://docs/qa/2026-09-19-manual/100-corner-edge-profiles/fresh-P12/world.scn").instantiate();root.add_child(world)
 var rows:Array=[];var sources:Array=[]
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if "Walls" not in str(node.name):continue
  for i in node.multimesh.instance_count:
   var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
   if Vector2(pose.origin.x+421.5,pose.origin.z+349.5).length()>28:continue
   sources.append([str(node.name),pose])
   if "Outer" not in str(node.name) and "Inner" not in str(node.name):rows.append(pose)
 FileAccess.open(OUT+"native-rows.bin",FileAccess.WRITE).store_var(sources)
 var records:=RELIEF.panels(rows)
 FileAccess.open(OUT+"panels.bin",FileAccess.WRITE).store_var(records)
 var report:Array=[]
 for record:Dictionary in records:report.append(str(record))
 FileAccess.open(OUT+"panels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit()
