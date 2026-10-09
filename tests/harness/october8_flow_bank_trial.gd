extends RefCounted
func run(review:Node)->void:
	# In-memory experiment only. Production source and native parity remain unchanged.
	var script:Script=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	var original:=FileAccess.get_file_as_string(script.resource_path)
	var reference:=GDScript.new();reference.source_code=original
	assert(reference.reload()==OK)
	var trial:=original.replace("extends RefCounted","extends RefCounted\nstatic var trial_reference:Script").replace("if not _wet(wet,env.ground,low) or minf(wet[top],wet[low])<=g[top]+WATER_SINK:return","pass # trial: retain the flowing crest")
	var marker:=" var uncut:=env.surface.duplicate()"
	assert(trial!=original and trial.contains(marker))
	trial=trial.replace(marker," var baseline=trial_reference._build(rect,ground_at,excluded_at,seed_value,water_at,ground_grid,ground_points,false,1)\n for idx in n:\n  var base_height:float=baseline.surface[idx]\n  var added:=maxf(0.0,env.surface[idx]-base_height)\n  var room:=maxf(0.0,wet_level[idx]-.3-base_height) if not wet_level.is_empty() and is_finite(wet_level[idx]) else 0.0\n  env.surface[idx]=base_height+minf(added,room)*smoothstep(0.0,.5,room)\n"+marker)
	preload("res://scripts/native/NativeCliffEnvelope.gd").force_off=true
	script.source_code=trial
	assert(script.reload(true)==OK)
	script.trial_reference=reference
	review._views.append({"id":"right_fan_detail","position":Vector3(180,85,1110),"target":Vector3(120,40,1036),"fov":62.0})
	await review._rebuild_full()
	await review._capture_all(3)
	await preload("res://tests/harness/october8_visible_rivers.gd").new().run(review)
	await preload("res://tests/harness/october8_lip_probe.gd").new().run(review)
	review._views.pop_back()
	print("FLOW_BANK_TRIAL done; in-memory envelope remains experimental")
