extends GutTest

# Pins the full-projection ("current") rock shape this test was written for.
# The owner-selected September 23 default compresses projection (subtle),
# which narrows ledges by design; test_september23_cliff_directions.gd
# covers that style, including its retained wall turf.
const _STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_STYLE.apply("current")
func after_all()->void:_STYLE.apply("chosen")
## A closed shell and clear lip can still erase the wider ledges the owner wants.
## Keep meaningful turf area at both ordinary and tall wall scales.
const BEFORE=preload("res://tests/fixtures/september18/cliff-angular-bumps/before.gd")
func _area(faces:PackedVector3Array)->float:
 var result:=0.0
 for i in range(0,faces.size(),3):result+=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length()*.5
 return result
func _check(height:float)->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 var before:Dictionary=BEFORE.make(pose,48,height,2697992464)[0]
 var current:Dictionary=source.make(pose,48,height,2697992464)[0]
 var expected:=_area(before.green);var actual:=_area(current.green)
 print("LEDGE_AREA_RETENTION height=",height," before=",expected," current=",actual," fraction=",actual/expected)
 assert_gt(expected,40.0,"The fixed control contains substantial ledge area")
 assert_gte(actual,expected*.75,"Improving rock faces must not erase the broad turf ledges")
func test_ordinary_cliff_retains_broad_ledge_area()->void:_check(8.0)
func test_tall_cliff_retains_broad_ledge_area()->void:_check(32.0)
