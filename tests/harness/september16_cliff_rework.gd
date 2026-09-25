extends "res://tests/harness/september16_cliff_final_review.gd"
func _read_args()->void:
 super._read_args()

func _run()->void:
 if not "--snapshot-only" in OS.get_cmdline_user_args():
  await super._run()
  return
 # Keep full production readiness (including the feature visual queue), but
 # separate generation from GPU image capture when the live renderer stalls.
 assert(await _wait_for_site())
 var world:=_character.get_parent().get_parent()
 preload("res://tests/harness/september11_snapshot.gd").save(world,_character,_output_dir.path_join("world.scn"))
 print("CLIFF_SNAPSHOT_ONLY complete")
 get_tree().quit()
