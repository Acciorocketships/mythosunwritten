extends GutTest
func _sample(column:Dictionary,y:float)->float:
 var heights:Array=column.keys();heights.sort()
 for i in range(1,heights.size()):
  if heights[i]<y:continue
  return lerpf(column[heights[i-1]],column[heights[i]],(y-heights[i-1])/maxf(.00001,heights[i]-heights[i-1]))
 return column[heights[-1]]
func _correlation(a:Array[float],b:Array[float])->float:
 var mean_a:=0.0;var mean_b:=0.0
 for i in a.size():mean_a+=a[i];mean_b+=b[i]
 mean_a/=a.size();mean_b/=b.size()
 var product:=0.0;var va:=0.0;var vb:=0.0
 for i in a.size():
  product+=(a[i]-mean_a)*(b[i]-mean_b)
  va+=pow(a[i]-mean_a,2);vb+=pow(b[i]-mean_b,2)
 return product/sqrt(maxf(.000001,va*vb))
func test_tall_wall_does_not_repeat_its_lateral_outline_at_every_height()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var form:Dictionary=generator.make(Transform3D.IDENTITY,48,64,2697992464)[0]
 var columns:Dictionary={}
 for p:Vector3 in form.faces:
  if p.y<0 or p.z<0 or absf(p.x)>22:continue
  if not columns.has(p.x):columns[p.x]={}
  columns[p.x][p.y]=maxf(p.z,columns[p.x].get(p.y,-INF))
 var xs:Array=columns.keys();xs.sort()
 var previous:Array[float]=[];var correlation:=0.0;var count:=0
 for y:float in [8,16,24,32,40,48,56]:
  var profile:Array[float]=[]
  for x:float in xs:profile.append(_sample(columns[x],y))
  if not previous.is_empty():
   var c:=_correlation(previous,profile)
   print("TALL_OUTLINE_CORRELATION y=",y," r=",c)
   correlation+=c;count+=1
  previous=profile
 correlation/=count
 print("TALL_OUTLINE_MEAN ",correlation)
 assert_lt(correlation,.65,"Tall rock outlines must change with elevation instead of keeping the same lateral columns")
