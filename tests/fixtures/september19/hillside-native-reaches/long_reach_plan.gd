extends "res://tests/fixtures/september19/hillside-native-reaches/reach_plan.gd"
const LONG_STUDY = preload("res://tests/fixtures/september19/hillside-native-reaches/long_reach_study.gd")

func _make_study() -> RefCounted:
	return LONG_STUDY.new(self)

func _study_radius() -> float:
	return LONG_STUDY.ROUTE_STATIONS*TRACE_STEP + POND_R_MAX*(1.0+PondStamp.WOBBLE) + ALLUVIAL_HALF_WIDTH + BANK_FEATHER
