extends GutTest
func test_photo_lips_do_not_recede_abruptly_immediately_below_their_edge()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var worst:=0.0;var at:=Vector3.ZERO;var checked:=0;var breaches:=0
 for a:Array in anchors:
  var form:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var columns:Dictionary={}
  for p:Vector3 in form.faces:
   if p.z<0 or p.y<=0 or p.y>a[2]-1.1 or absf(p.x)>a[1]*.5-2.6:continue
   if not columns.has(p.x):columns[p.x]={}
   columns[p.x][p.y]=maxf(columns[p.x].get(p.y,-INF),p.z)
  for x:float in columns:
   var column:Dictionary=columns[x]
   var ys:Array=column.keys();ys.sort();ys.reverse()
   for i in range(1,ys.size()):
    var drop:float=ys[i-1]-ys[i]
    if drop>.35 or drop<.0001:continue
    var recession:float=column[ys[i-1]]-column[ys[i]]
    checked+=1
    if recession>.5:breaches+=1
    if recession>worst:
     worst=recession;at=a[0]*Vector3(x,ys[i],column[ys[i]])
 print("PHOTO_LIP_BEARING samples=",checked," breaches=",breaches," max_recession=",worst," world=",at)
 assert_gt(checked,10000,"Measure the photo formations' actual exterior mesh")
 assert_lt(worst,.5,"A ledge cannot lose half a metre of bearing in the next 35 cm of descent")
