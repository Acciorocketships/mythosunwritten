extends SceneTree

func _init() -> void:
	var folder := "res://docs/qa/2026-09-11-manual/12-landforms/"
	var source: Dictionary=FileAccess.open(folder+"fine-input.bin",FileAccess.READ).get_var()
	var region:=HeightfieldRegion.new(source.storeys,source.levels,source.carved)
	WaterField.profile_source_cost=true
	var started:=Time.get_ticks_msec()
	var result:=WaterField._build_sub_lattice_rescue(region,source.base,source.coarse,source.river,source.side)
	print("FINE_REPLAY_DONE ms=",Time.get_ticks_msec()-started)
	var args:=OS.get_cmdline_user_args()
	var name:=args[0] if not args.is_empty() else "fine-result.bin"
	FileAccess.open(folder+name,FileAccess.WRITE).store_var(result)
	quit()
