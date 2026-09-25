extends GutTest
const A=preload("res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd")
const Frozen=preload("res://tests/fixtures/frozen_maze_source.gd")
func test_photographed_tall_retaining_column_has_no_timber_below_ground()->void:
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var fabric:=Frozen.spatial(Frozen.read("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/town-P02/current-source.txt"),program).compiled_fabric_cache()
 var tx:=A.maze_ground_skin_transaction(fabric)
 var down:=A.STONE_FACE_DIRECTIONS.find(Vector3i.DOWN)
 for cell:Vector3i in [Vector3i(10,0,-4),Vector3i(11,0,-4)]:
  assert_true(tx.retained.has(cell),"The photographed column retains its supporting stone")
  assert_true(tx.retained.has(cell+Vector3i.UP),"Exercise a taller column, not a ground-level turf cap")
  for channel:String in ["exposed","faces","treatments"]:
   assert_false(tx.shell[channel].has(Vector4i(cell.x,cell.y,cell.z,down)),"Buried column base must not emit visible timber in "+channel)
 var payload:=A.terrace_retaining_payload(fabric)
 var ids:Array=[]
 for batch:Dictionary in payload.batches.values():ids.append_array(batch.ids)
 assert_false(ids.has(&"maze-soffit/10/0/-4/5"))
 assert_false(ids.has(&"maze-soffit/11/0/-4/5"))
