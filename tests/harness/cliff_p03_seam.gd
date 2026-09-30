extends SceneTree
func _init()->void:
 var ENV=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
 var envs:=[]
 for z in [4,5]:
  var env=ENV.new()
  var data:Dictionary=FileAccess.open("res://docs/qa/2026-09-26-p03-followup/envelope-2-%s.var"%z,FileAccess.READ).get_var()
  for key:String in data:env.set(key,data[key])
  envs.append(env)
 var rows:=[];var worst:=0.0;var worst_ground:=0.0
 for x in range(480,561):
  for z in range(938,959):
   var q:=Vector2(x,z)
   worst=maxf(worst,absf(envs[0].at(q)-envs[1].at(q)))
   worst_ground=maxf(worst_ground,absf(envs[0].ground_node(q)-envs[1].ground_node(q)))
 for x in [497,506,516,526,536]:
  for z in [946.5,947.0,947.5,948.0,948.5,949.0]:
   var q:=Vector2(x,z)
   rows.append({"q":str(q),"n":envs[0].at(q),"s":envs[1].at(q),"gn":envs[0].ground_node(q),"gs":envs[1].ground_node(q)})
 print(JSON.stringify({"max_surface_difference":worst,"max_ground_difference":worst_ground,"rows":rows},"  "))
 quit()
