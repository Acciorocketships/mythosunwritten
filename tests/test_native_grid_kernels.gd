extends GutTest
## NativeGridKernels: C# mirrors of CliffSlopeEnvelope's grid kernels. Under
## the .NET editor they must pass their own bit-for-bit parity check; under the
## standard editor they stay off and the GDScript kernels are used.
const K := preload("res://scripts/native/NativeGridKernels.gd")
const E := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")

func test_native_kernels_match_gdscript_or_stay_off() -> void:
	K.setup()
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(K.enabled, "standard editor: GDScript kernels")
		return
	assert_true(K.enabled, ".NET editor: kernels verified and on")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for case_index in 20:
		var w := rng.randi_range(1, 200)
		var h := rng.randi_range(1, 200)
		var f := PackedFloat64Array()
		f.resize(w * h)
		for i in f.size():
			f[i] = INF if rng.randf() < 0.2 else rng.randf_range(-100.0, 100.0)
		var columns := case_index % 2 == 0
		assert_eq(K.envelope_axis(f, w, h, 0.37, columns), E._envelope_axis(f, w, h, 0.37, columns))
		for i in f.size():
			if f[i] == INF: f[i] = 0.25
		assert_eq(K.blur(f, w, h, 2), E._blur(f, w, h, 2))
		assert_eq(K.window(f, w, h, 3.1, columns), E._window(f, w, h, 3.1, columns))
