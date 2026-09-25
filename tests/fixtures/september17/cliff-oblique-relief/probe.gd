extends SceneTree
func _initialize()->void:
 var g=load("res://tests/fixtures/september17/cliff-oblique-relief/planes.gd")
 var jump:=0.0;var at:=Vector2.ZERO
 for salt in [17,42,2697992464]:
  for axis in 2:
   for i in range(-10,11):
    for j in range(-400,401):
     var p:=Vector2(i,j*.025) if axis==0 else Vector2(j*.025,i)
     var delta:=Vector2(.0001,0) if axis==0 else Vector2(0,.0001)
     var difference:float=absf(g._rock_planes(p-delta,salt)-g._rock_planes(p+delta,salt))
     if difference>jump:jump=difference;at=p
 print("PLANE_GRID_CONTINUITY max_jump=",jump," at=",at)
 quit(0 if jump<.005 else 1)
