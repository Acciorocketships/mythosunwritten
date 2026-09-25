extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/127-bank-preserved-relief"
const FIT=preload("res://tests/fixtures/september19/bank-preserved-relief/fit.gd")
const OLD=preload("res://tests/fixtures/september19/bank-relief/fit.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init()->void:run.call_deferred()
func run()->void:
 ROCKS.prepare()
 var hydraulic:=TerrainWorldTuning.make_water(2697992464)
 var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,0,8)
 var region:=fields.region(Vector2i(-3,1));var water:=fields.water(Vector2i(-3,1))
 var sources:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
 var rows:Array=[]
 for source:Dictionary in sources:
  if source.replay_recipe.kind!="corner" or source.anchor.y!=20 or source.anchor.z!=205.5 or source.anchor.x not in [-586.5,-541.5]:continue
  var old:=OLD.fit(source,region,water)
  var current:=FIT.fit(source,region,water)
  rows.append({"id":source.id,"old_admitted":not old.is_empty(),"current_admitted":not current.is_empty(),"conflicts":FIT.last_rejections.duplicate(true)})
 FileAccess.open(OUT.path_join("corner-conflicts.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("BANK_CORNER_CONFLICTS ",rows.size())
 quit()
