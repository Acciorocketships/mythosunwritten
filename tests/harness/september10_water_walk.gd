extends "res://tests/harness/september10_water_qa.gd"

class SwimController extends CharacterController:
	var direction:=Vector2.ZERO
	func get_move_vector(_character:CharacterBody3D,_delta:float)->Vector2:return direction

func _grass_enabled()->bool:return false

func _run()->void:
	await get_tree().create_timer(5).timeout
	_camera=get_viewport().get_camera_3d()
	_camera.set("target",null);_camera.set_process(false);_camera.set_physics_process(false)
	var controller:=SwimController.new();_character.controller=controller
	var rows:=[];var passed:=true
	for route in [["15_downstream",Vector2(831,-1797),Vector2(831,-1821)],
			["19_upstream",Vector2(879,-1821),Vector2(879,-1797)],
			["18_channel",Vector2(831,-1782),Vector2(831,-1758)],
			["16_ledge",Vector2(696,-1722),Vector2(672,-1722)]]:
		var a:Vector2=route[1];var b:Vector2=route[2]
		_spot=[route[0],"physical route",Vector3(a.x,20,a.y),Vector3(a.x,20,a.y)]
		controller.direction=Vector2.ZERO
		if not await _wait_for_site():get_tree().quit(2);return
		var field:=_streamer._fields.water(Vector2i((a/192).floor()))
		var level:=WaterField.level_at(field.raw_context(),a)
		assert(is_finite(level))
		_character.set_physics_process(false)
		_character.position=Vector3(a.x,level-.5,a.y);_character.velocity=Vector3.ZERO
		for tick in 60:
			await get_tree().physics_frame
			_character.set_physics_process(false)
			_character._physics_process(1.0/60)
		var start:=Vector2(_character.position.x,_character.position.z)
		var axis:=(b-a).normalized();var trace:=[];var frozen:=0;var swimming:=0;var ticks:=0
		for tick in 1200:
			await get_tree().physics_frame
			_character.set_physics_process(false)
			var here:=Vector2(_character.position.x,_character.position.z)
			controller.direction=(b-here).normalized()
			if _streamer._player_frozen:frozen+=1
			else:_character._physics_process(1.0/60)
			if _character.in_water:swimming+=1
			ticks=tick+1
			if tick%6==0:trace.append({"tick":tick,"position":str(_character.position),"swimming":_character.in_water,"grounded":_character.is_on_floor(),"surface":_character.water_surface_y,"frozen":_streamer._player_frozen})
			if Vector2(_character.position.x,_character.position.z).distance_to(b)<.75:break
		controller.direction=Vector2.ZERO
		var end:=Vector2(_character.position.x,_character.position.z)
		var okay:=end.distance_to(b)<.75 and frozen==0 and swimming>30
		passed=passed and okay
		var row:Dictionary={"route":route[0],"start":str(start),"end":str(end),"target":str(b),"distance":(end-start).dot(axis),"ticks":ticks,"swim_ticks":swimming,"frozen_ticks":frozen,"passed":okay,"trace":trace}
		rows.append(row)
		FileAccess.open(_output_dir+"/water-walk.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"routes":rows},"  "))
		print("WATER_WALK ",route[0]," passed=",okay," distance=",row.distance," swimming=",swimming," frozen=",frozen)
	get_tree().quit(0 if passed else 1)
