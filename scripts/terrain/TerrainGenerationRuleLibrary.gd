class_name TerrainGenerationRuleLibrary
extends Resource

# Array of TerrainGenerationRule instances
@export var rules: Array[TerrainGenerationRule] = []


func _init() -> void:
	rules.append(CliffEdgeRule.new())
	rules.append(LevelEdgeRule.new())
	# Runs last so it sees the final (possibly retiled) placement.
	rules.append(ClusterFillRule.new())
