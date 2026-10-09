extends GutTest

const E := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")

func test_a_submerged_crest_keeps_its_rounding() -> void:
	# A submerged 8 m cliff: the current wet-crest early return leaves a raw
	# vertical slot amid the neighbouring rounded banks (photo 4, x=462).
	var ground := func(p: Vector2) -> float: return 8.0 if p.x<6.0 else 0.0
	var water := func(_p: Vector2) -> float: return 12.0
	var env = E._build(Rect2(-4,-4,24,8),ground,Callable(),2697992464,water,Callable(),Callable(),true,1)
	assert_gt(env.at(Vector2(6.5,0)),1.0,"the underwater bed rounds across the same cliff transition")
	assert_lt(env.at(Vector2(6.5,0)),11.6,"the rounded bed remains submerged")
	var native := preload("res://scripts/native/NativeCliffEnvelope.gd")
	native.setup()
	if ClassDB.class_exists(&"CSharpScript"):
		assert_true(native.enabled,"the native parity gate remains enabled")
		if native.enabled:
			var actual=E._build(Rect2(-4,-4,24,8),ground,Callable(),2697992464,water,Callable(),Callable(),true,2)
			assert_eq(actual.surface,env.surface,"drowned-crest rounding is bit-identical in C#")

func test_a_flowing_sill_does_not_grow_a_bank_over_its_drop() -> void:
	var ground := func(p:Vector2)->float:return 8.0 if p.x<6.0 else 0.0
	var water := func(p:Vector2)->float:return 8.5 if p.x<6.0 else 1.0
	var env=E._build(Rect2(-4,-4,24,8),ground,Callable(),2697992464,water,Callable(),Callable(),true,1)
	assert_eq(env.at(Vector2(6.5,0)),0.0,"a falling reach still keeps its downstream clearance")
