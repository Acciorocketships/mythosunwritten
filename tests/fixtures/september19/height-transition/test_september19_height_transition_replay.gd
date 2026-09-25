extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
func test_actual_uneven_buried_floor_reconstructs_every_triangle()->void:
 ROCKS.prepare()
 var source:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/99-height-transition/replay-mismatch.bin",FileAccess.READ).get_var()
 var floors:Dictionary={}
 for p:Vector3 in source[1]:floors[p.x]=minf(floors.get(p.x,INF),p.y)
 var levels:Dictionary={}
 for y:float in floors.values():levels[y]=levels.get(y,0)+1
 print("SAVED_FLOOR_LEVELS ",levels)
 var rebuilt:=REPLAY.rebuild(source[0],source[1],source[3],CRAGS,CORNER)
 assert_eq(rebuilt.faces.size(),source[1].size())
 assert_true(rebuilt.faces==source[1],"Retain the actual uneven buried floor, not one global minimum")
 assert_true(rebuilt.green==source[2])
