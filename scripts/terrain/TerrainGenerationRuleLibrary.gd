class_name TerrainGenerationRuleLibrary
extends Resource

# Array of TerrainGenerationRule instances
@export var rules: Array[TerrainGenerationRule] = []


func _init() -> void:
	# WaterRule runs first: it may swap the placed ground tile for water, and
	# the later rules must see the final base-plane piece.
	rules.append(WaterRule.new())
	rules.append(CliffEdgeRule.new())
	rules.append(LevelEdgeRule.new())
	# Runs last so it sees the final (possibly retiled) placement.
	rules.append(ClusterFillRule.new())
