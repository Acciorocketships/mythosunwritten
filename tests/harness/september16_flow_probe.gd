extends SceneTree
func _initialize()->void:
 var data:Array=FileAccess.open("res://docs/qa/2026-09-16-manual/baseline/P10/samplers.bin",FileAccess.READ).get_var()
 var all:=[];var worst:=[];var count:=0
 for values:Dictionary in data:
  var s:=WaterSampler.new()
  for key:String in values:s.set(key,values[key])
  if "--candidate" in OS.get_cmdline_user_args():
   var wet:=PackedByteArray();var gradients:=PackedVector2Array()
   for j in s._nz:
    for i in s._nx:
     var p:=s._origin+Vector2(i,j)*s._step
     var h:=s.level_at(p)
     wet.append(1 if is_finite(h) else 0)
     var gradient:=Vector2.ZERO
     if is_finite(h):
      for axis in 2:
       var offset:=Vector2(.375,0) if axis==0 else Vector2(0,.375)
       var a:=s.level_at(p-offset);var b:=s.level_at(p+offset)
       if not is_finite(a):a=h
       if not is_finite(b):b=h
       gradient[axis]=(b-a)/.75
     gradients.append(gradient)
   var bank:=WaterCurrentField.signed_distance(wet,s._nx,s._nz,s._step)
   s._velocity=WaterCurrentField.solve_local(s._velocity,bank,s._nx,s._nz,s._step,gradients).velocity
  print("P01 water: ",s.level_at(Vector2(-1175.3,-731))," current ",s.velocity_at(Vector2(-1175.3,-731)))
  for j in range(1,s._nz-1):
   for i in range(1,s._nx-1):
    for offset:Vector2 in [Vector2.ZERO,Vector2(.25,.25),Vector2(.5,.5),Vector2(.75,.75)]:
     var p:=s._origin+(Vector2(i,j)+offset)*s._step
     if p.distance_to(Vector2(-1110.7,-757.5))>160:continue
     var h:=s.level_at(p);var v:=s.velocity_at(p)
     if not is_finite(h) or v.length()<.1:continue
     var ahead:=s.level_at(p+v.normalized()*.5);var behind:=s.level_at(p-v.normalized()*.5)
     if not is_finite(ahead) or not is_finite(behind):continue
     count+=1
     if ahead-behind>.025:worst.append({"x":p.x,"z":p.y,"h":h,"vx":v.x,"vz":v.y,"rise_per_m":ahead-behind})
 worst.sort_custom(func(a,b):return a.rise_per_m>b.rise_per_m)
 FileAccess.open("res://docs/qa/2026-09-16-manual/03-water-flow/replay-candidate.json" if "--candidate" in OS.get_cmdline_user_args() else "res://docs/qa/2026-09-16-manual/flow-probe.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":count,"uphill":worst},"  "))
 print("FLOW_PROBE ",count," uphill=",worst.size()," worst=",worst.slice(0,10))
 quit()
