extends SceneTree
func _initialize()->void:
 var probe=load("res://tests/test_september16_continuous_cliffs.gd").new()
 var fields:Array=[]
 for path:String in ["before.gd","graded.gd"]:
  var generator:GDScript=load("res://tests/fixtures/september17/cliff-broad-shoulders/"+path)
  var forms:Array=[]
  for x:float in [-24,0,24]:forms.append_array(generator.make(Transform3D(Basis.IDENTITY,Vector3(x,0,0)),24,16,2697992464))
  fields.append(forms)
 for y:float in [4.0,8.0,12.0]:
  for x in range(-32,33,3):
   var prominence:Array=[]
   for forms:Array in fields:
    prominence.append(probe._front(forms,x,y)-maxf(probe._front(forms,x-2.0,y),probe._front(forms,x+2.0,y)))
   if prominence[0]>.45 or prominence[1]>.45:print("SHELF_PROMINENCE position=",Vector2(x,y)," before_current=",prominence)
 for step in 11:
  var y:=11.5+step*.1
  var prominence:Array=[]
  for forms:Array in fields:
   prominence.append(probe._front(forms,19.0,y)-maxf(probe._front(forms,17.0,y),probe._front(forms,21.0,y)))
  print("SHELF_LOCAL_HEIGHT y=",y," before_current=",prominence)
 probe.free()
 quit()
