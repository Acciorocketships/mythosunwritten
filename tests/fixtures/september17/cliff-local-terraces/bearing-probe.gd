extends SceneTree
func _initialize()->void:
 for version:String in ["res://scripts/terrain/field/CliffRockCrags.gd","res://tests/fixtures/september17/cliff-local-terraces/localized.gd"]:
  var g:GDScript=load(version)
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
  var form:Dictionary=g.make(pose,48,32,2697992464)[0]
  var columns:Dictionary={}
  for p:Vector3 in form.faces:
   if p.z<-.4 or p.y<0.0 or p.y>31:continue
   if not columns.has(p.x):columns[p.x]={}
   columns[p.x][p.y]=maxf(columns[p.x].get(p.y,-INF),p.z)
  var worst:=0.0;var pair:Array=[]
  for x:float in columns:
   var column:Dictionary=columns[x]
   var heights:Array=column.keys();heights.sort();heights.reverse()
   var upper:=-INF;var upper_y:=0.0
   for y:float in heights:
    if upper-column[y]>worst:worst=upper-column[y];pair=[x,upper_y,upper,y,column[y]]
    if column[y]>upper:upper=column[y];upper_y=y
  print("BEARING_LOCATION version=",version," recession=",worst," pair[x,upper_y,upper_z,lower_y,lower_z]=",pair)
 quit()
