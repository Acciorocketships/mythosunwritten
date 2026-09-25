extends SceneTree
func _initialize()->void:
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for source:String in ["before","broad","tiered"]:
  var generator:GDScript=load("res://tests/fixtures/september17/cliff-terraced-base/"+source+".gd")
  var broad_area:=0.0;var thin_area:=0.0;var total:=0.0
  var deep:=0;var shallow:=0;var lower_width:=0.0;var top_width:=0.0
  for index in anchors.size():
   var a:Array=anchors[index];var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
   for i in range(0,form.green.size(),3):
    var p:Vector3=form.green[i];var q:Vector3=form.green[i+1];var r:Vector3=form.green[i+2]
    var width:=0.0
    for j in 3:
     var v:Vector3=form.green[i+j];var w:Vector3=form.green[i+(j+1)%3]
     if absf(v.x-w.x)<.001:width=maxf(width,absf(v.z-w.z))
    var area:float=(r-p).cross(q-p).length()*.5
    total+=area
    if width>=.8:broad_area+=area
    if width<.5:thin_area+=area
   var lows:Dictionary={};var highs:Dictionary={}
   for v:Vector3 in form.faces:
    if v.y>=-.001 and v.y<.21:lows[v.x]=maxf(lows.get(v.x,0.0),v.z)
    if absf(v.y-a[2]*.65)<.11:highs[v.x]=maxf(highs.get(v.x,0.0),v.z)
   for x:float in lows:
    if absf(x-roundf(x))>.01:continue
    if lows[x]>4.0:deep+=1
    if lows[x]<2.5:shallow+=1
    lower_width+=lows[x];top_width+=highs.get(x,0.0)
  print("BASE_MEASURE ",source," turf_area=",total," broad_80cm=",broad_area," narrow_50cm=",thin_area," deep_feet=",deep," quiet_feet=",shallow," bottom_sum=",lower_width," upper_sum=",top_width)
 quit()
