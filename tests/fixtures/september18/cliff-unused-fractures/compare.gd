extends SceneTree
func _initialize()->void:
 var before:GDScript=load("res://tests/fixtures/september18/cliff-unused-fractures/before.gd")
 var after:GDScript=load("res://tests/fixtures/september18/cliff-unused-fractures/lean.gd")
 before.prepare();after.prepare()
 var cases:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for height:float in [16.0,32.0,64.0]:cases.append([Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48.0,height,false,false])
 var elapsed:Array[int]=[0,0];var checks:=0;var failures:=0
 for repeat in 2:
  for i in cases.size():
   var c:Array=cases[i];var outputs:Array=[[],[]]
   for index in ([0,1] if (i+repeat)%2==0 else [1,0]):
    var source:GDScript=before if index==0 else after
    var start:=Time.get_ticks_usec()
    outputs[index]=source.make(c[0],c[1],c[2],2697992464,null,c[3],c[4])
    elapsed[index]+=Time.get_ticks_usec()-start
   checks+=1
   if var_to_bytes(outputs[0])!=var_to_bytes(outputs[1]):failures+=1;print("MISMATCH ",i," repeat=",repeat)
 print("UNUSED_FRACTURES cases=",checks," mismatches=",failures," before_ms=",elapsed[0]/1000.0," after_ms=",elapsed[1]/1000.0)
 quit(0 if failures==0 else 1)
