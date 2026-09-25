extends GutTest

# Pins the full-projection ("current") rock shape this test was written for.
# The owner-selected September 23 default compresses projection (subtle),
# which narrows ledges by design; test_september23_cliff_directions.gd
# covers that style, including its retained wall turf.
const _STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_STYLE.apply("current")
func after_all()->void:_STYLE.apply("chosen")
const JOIN=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const SOURCE="res://docs/qa/2026-09-19-manual/92-inner-shared-surface/extended/before-forms.bin"
func source()->Array:
 ROCKS.prepare()
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 JOIN.apply(forms)
 return forms
func test_broad_turf_continues_at_the_same_height_through_the_photographed_turn()->void:
 var corner:=Vector3(-445.5,32,-301.5)
 var pair:Array=[]
 for form:Dictionary in source():
  if corner in form.replay_recipe.get("inner_connections",[]):pair.append(form)
 assert_eq(pair.size(),2)
 var count:=0;var maximum:=0.0
 for ix in 17:
  for iz in 17:
   var at:=corner+Vector3(1.0+float(ix)*.25,6,1.0+float(iz)*.25)
   var hits:Array=[]
   for form:Dictionary in pair:
    var start:Vector3=form.transform.affine_inverse()*at
    var top:=-INF
    for i in range(0,form.green.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(start,Vector3.DOWN,form.green[i],form.green[i+1],form.green[i+2])
     if hit!=null and hit.y>2.0 and hit.y<3.6:top=maxf(top,hit.y)
    if is_finite(top):hits.append(top)
   if hits.size()!=2:continue
   count+=1;maximum=maxf(maximum,absf(hits[0]-hits[1]))
 print("INNER_LEDGE_SEAM overlap_samples=",count," max_height_difference=",maximum)
 assert_gte(count,30,"Keep the shared tread area instead of removing one side")
 assert_lt(maximum,.02,"The two exposed ledges must agree through their shared corner")
