extends SceneTree
const BEFORE=preload("res://docs/qa/2026-09-13-manual/17-village-grade/baseline_grade.gd")
const FROZEN=preload("res://tests/fixtures/frozen_terrain_grade.gd")
const ORIGINAL_CLIFF=preload("res://tests/fixtures/september15/before_cliff.gd")
func _grade(data:Dictionary)->TerrainGradePatch:
 var result:=BEFORE.new(data.id,data.claims,data.origin,data.pitch)
 if not data.source.is_empty(): result._continuous_source=_grade(data.source)
 result._continuous_cells=data.continuous_cells
 result._continuous_datum=data.datum
 return result
func _init():
 var report:=[]
 for site:Array in [["P09",Vector2i(-21,-11)],["P07",Vector2i(-22,-82)],["P08",Vector2i(-25,-83)]]:
  var data:Dictionary=str_to_var(FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/01-grass/"+site[0]+"-field.txt"))
  var old:=HeightfieldRegion.new(data.storeys,data.levels,data.carved)
  var now:=HeightfieldRegion.new(data.storeys,data.levels,data.carved)
  for g:Dictionary in data.grades:
   old.terrain_grades.append(_grade(g));now.terrain_grades.append(FROZEN.grade(g))
  var a:=ORIGINAL_CLIFF.compute(old,site[1].x-1,site[1].y-1,3)
  var b:=ORIGINAL_CLIFF.compute(now,site[1].x-1,site[1].y-1,3)
  var natural:=ORIGINAL_CLIFF.compute(now.without_terrain_grades(),site[1].x-1,site[1].y-1,3)
  var row:={"spot":site[0],"natural_lips":natural.lip.size()+natural.outer_lip.size()+natural.inner_lip.size(),"pre_september13_lips":a.lip.size()+a.outer_lip.size()+a.inner_lip.size(),"current_suppressed_lips":b.lip.size()+b.outer_lip.size()+b.inner_lip.size()}
  report.append(row)
  print(row)
 FileAccess.open("res://docs/qa/2026-09-15-manual/01-grass/history.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 quit()
