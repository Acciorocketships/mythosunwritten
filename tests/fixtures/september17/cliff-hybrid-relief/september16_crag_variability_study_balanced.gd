extends GutTest
const CRAGS=preload("res://tests/fixtures/september17/cliff-hybrid-relief/balanced.gd")
const BEFORE=preload("res://tests/fixtures/september16/crags_before_variability.gd")
const PROFILE=preload("res://tests/test_september16_continuous_cliffs.gd")
func _prominent_shoulders(generator:GDScript)->int:
 var forms:Array=[]
 for x:float in [-24,0,24]:forms.append_array(generator.make(Transform3D(Basis.IDENTITY,Vector3(x,0,0)),24,16,2697992464))
 var probe=PROFILE.new();var count:=0
 # Actual closed physical geometry around three elevations, including upper rock.
 # A curved cap may lower a shoulder through the exact section plane. Sample
 # the neighboring half-step of the 0.2 m physical lattice and count each
 # horizontal location once; retain the same prominence and count thresholds.
 for y:float in [4.0,8.0,12.0]:
  for x in range(-32,33,3):
   for offset:float in [-.1,0.0,.1]:
    var front:float=probe._front(forms,x,y+offset)
    var left:float=probe._front(forms,x-2.0,y+offset)
    var right:float=probe._front(forms,x+2.0,y+offset)
    if front>maxf(left,right)+.45:
     count+=1
     break
 probe.free()
 return count
func test_outcrops_have_relief_beyond_stacked_ledge_bands()->void:
 var old:=_prominent_shoulders(BEFORE);var current:=_prominent_shoulders(CRAGS)
 print("ROCK_PROMINENCE before=",old," current=",current)
 assert_gt(current,old+4,"Add several independently protruding physical rock faces, not only reshaped turf bands")
