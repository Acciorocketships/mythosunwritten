extends SceneTree
func _initialize()->void:
 var probe=load("res://tests/test_september16_continuous_cliffs.gd").new()
 for name:String in ["before","sloping","supported"]:
  var generator=load("res://tests/fixtures/september17/cliff-shelf-edges/"+name+".gd")
  var forms:Array=[]
  for x:float in [-24,0,24]:forms.append_array(generator.make(Transform3D(Basis.IDENTITY,Vector3(x,0,0)),24,16,2697992464))
  for y:float in [11.0,11.25,11.5,11.75,12.0,12.25,12.5]:
   for x in [19]:
    var front:float=probe._front(forms,x,y)
    var left:float=probe._front(forms,x-2.0,y)
    var right:float=probe._front(forms,x+2.0,y)
    var amount:=front-maxf(left,right)
    print(name," ",Vector2(x,y)," prominence=",amount," front=",front)
 probe.free();quit()
