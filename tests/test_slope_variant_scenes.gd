# tests/test_slope_variant_scenes.gd
extends GutTest

const NAMES := [
	"CliffSide", "CliffCorner", "CliffLine", "CliffPeninsula", "CliffIsland",
	"CliffInCorner", "CliffInCornerDiag", "CliffInCornerSide", "CliffInCornerThree",
	"CliffInCornerAll", "CliffInCornerEdge1", "CliffInCornerEdge2",
	"CliffInCornerEdgeBoth", "CliffInCornerSideEdge",
]

func test_all_variant_scenes_load() -> void:
	for n in NAMES:
		var path := "res://terrain/scenes/slope/%s.tscn" % n
		assert_true(ResourceLoader.exists(path), path)
		var inst := (load(path) as PackedScene).instantiate()
		assert_not_null(inst, n)
		inst.free()

func test_socket_parity_with_original() -> void:
	for n in NAMES:
		var orig := (load("res://terrain/scenes/%s.tscn" % n) as PackedScene).instantiate()
		var slope := (load("res://terrain/scenes/slope/%s.tscn" % n) as PackedScene).instantiate()
		var orig_sockets := _socket_names(orig)
		var slope_sockets := _socket_names(slope)
		assert_eq(slope_sockets, orig_sockets, "socket mismatch for %s" % n)
		orig.free()
		slope.free()

func test_stacked_variant_scenes_load_with_socket_parity() -> void:
	var pairs := {"CliffCornerStacked": "CliffCorner", "CliffInCornerStacked": "CliffInCorner"}
	for name in pairs:
		var path := "res://terrain/scenes/slope/%s.tscn" % name
		assert_true(ResourceLoader.exists(path), path)
		var inst := (load(path) as PackedScene).instantiate()
		assert_not_null(inst, name)
		# Compare against the AUTHORED original (what the bake copies sockets from),
		# so this test is self-sufficient and matches the actual data flow.
		var base := (load("res://terrain/scenes/%s.tscn" % pairs[name]) as PackedScene).instantiate()
		assert_eq(_socket_names(inst), _socket_names(base), "socket mismatch %s" % name)
		inst.free(); base.free()

func _socket_names(root: Node) -> Array:
	var s := root.get_node_or_null("Sockets")
	if s == null:
		return []
	var names := []
	for c in s.get_children():
		names.append(c.name)
	names.sort()
	return names
