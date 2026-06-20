class_name TerrainGenerationRuleLibrary
extends Resource

# Array of TerrainGenerationRule instances
@export var rules: Array[TerrainGenerationRule] = []


func _init() -> void:
	# The heightfield plan is the sole structural source; the emergent edge rules
	# (CliffEdgeRule/LevelEdgeRule/ClusterFillRule) were removed. WaterRule still
	# swaps placed ground tiles to water/banks from the deterministic water field.
	rules.append(WaterRule.new())
