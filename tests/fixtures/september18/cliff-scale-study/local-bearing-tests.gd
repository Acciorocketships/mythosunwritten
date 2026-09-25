extends GutTest
func _recession(column:Dictionary,reach:float)->float:
 var heights:Array=column.keys();heights.sort();heights.reverse()
 var worst:=0.0
 for i in heights.size():
  for j in range(i+1,heights.size()):
   if heights[i]-heights[j]>reach:break
   worst=maxf(worst,column[heights[i]]-column[heights[j]])
 return worst
func test_local_bearing_distinguishes_a_taper_from_an_unsupported_belly()->void:
 var slope:Dictionary={}
 for y in 21:slope[float(y)]=1.0+y*.20
 assert_almost_eq(_recession(slope,2.0),.4,.00001,"A coherent taper can change outline over its full height")
 assert_gt(_recession({4.0:5.0,3.0:1.0,2.0:1.0,1.0:1.0},2.0),.85,"A deep immediate underside must still fail")
func test_actual_photo_faces_keep_support_immediately_below_projections()->void:
 var source:GDScript=load(OS.get_environment("STORY_BUTTRESS_GENERATOR"))
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var worst:=0.0;var columns_checked:=0
 for a:Array in anchors:
  var form:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var columns:Dictionary={}
  for p:Vector3 in form.faces:
   if p.z<-.4 or p.y<0 or p.y>a[2]-1:continue
   if not columns.has(p.x):columns[p.x]={}
   columns[p.x][p.y]=maxf(p.z,columns[p.x].get(p.y,-INF))
  for column:Dictionary in columns.values():
   worst=maxf(worst,_recession(column,2.0));columns_checked+=1
 print("LOCAL_BEARING recession=",worst," columns=",columns_checked)
 assert_gt(columns_checked,500)
 assert_lt(worst,.85,"Immediate lower rock support must survive the irregular composition")
