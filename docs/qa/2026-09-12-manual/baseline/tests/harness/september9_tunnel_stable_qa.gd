extends "res://tests/harness/september9_reported_qa.gd"

# Keep the player and streaming footprint at the photographed site throughout
# paired capture. Walking has its own trace; it must not evict background
# feature owners between the two visual judgments.
func _run() -> void:
 await get_tree().create_timer(5.0).timeout
 _camera=get_viewport().get_camera_3d()
 _camera.set("target",null)
 _camera.set_physics_process(false)
 _camera.set_process(false)
 _character.set_physics_process(false)
 if not await _wait_for_site():
  get_tree().quit(1)
  return
 var super_cell:=Vector2i(floori(float(_spot[2].x)/SettlementPlan.SUPER_WORLD),floori(float(_spot[2].z)/SettlementPlan.SUPER_WORLD))
 var record:=_streamer._features.village_plan().record_for(_streamer._features.frame_for(super_cell))
 var urban:=record.urban_fabric
 var entries:Array=[]
 for entry:Dictionary in record.outskirts.entries:
  entries.append({"id":String(entry.stable_id),"asset":String(entry.asset_id),"transform":str(entry.transform)})
 var arches:Array=[]
 for placement in urban.fabric_plan.expanded_placements():
  if String(placement.stable_id).begins_with("tunnel-mouth/"):arches.append({"id":String(placement.stable_id),"transform":str(placement.transform)})
 var cameras:Array=[]
 for view in [["front",Vector3(-3.8,1.8,0.75)],["left",Vector3(-3.2,1.7,-0.2)],["right",Vector3(-3.2,1.7,1.7)],["inside",Vector3(2,1.8,0.75)],["overview",Vector3(-3.5,2.5,0.75)]]:
  _camera.global_position=urban.world_transform*view[1]
  _camera.look_at(urban.world_transform*Vector3(-0.65,1.9,0.75))
  _camera.force_update_transform()
  for frame in 4:await get_tree().process_frame
  await _shot("tunnel_"+String(view[0]))
  cameras.append({"view":view[0],"transform":str(_camera.global_transform)})
 FileAccess.open(_output_dir+"/construction.json",FileAccess.WRITE).store_string(JSON.stringify({"outskirts":entries,"arches":arches,"cameras":cameras,"player":str(_character.position),"world_transform":str(urban.world_transform)},"  "))
 await _capture_spot(_spot)
 get_tree().quit()
