@tool
class_name EnvironmentBakeBudget
extends RefCounted

## Declarative per-asset resource gates. The manifest owns limits; provenance
## owns measurements; this validator is deliberately unaware of asset families.
const GATES := {
	"max_mesh_bytes": "mesh_bytes",
	"max_visual_triangles": "visual_triangles",
	"max_collision_triangles": "collision_triangles",
	"max_surfaces": "surface_count",
	"max_collision_pieces": "collision_piece_count",
}

static func validate(metrics: Dictionary, entry: Dictionary) -> String:
	for gate_name: String in GATES:
		if not entry.has(gate_name):
			continue
		var limit := int(entry[gate_name])
		if limit < 0:
			return "%s must be a non-negative integer" % gate_name
		var metric_name: String = GATES[gate_name]
		var measured := int(metrics.get(metric_name, -1))
		if measured < 0:
			return "missing provenance metric %s" % metric_name
		if measured > limit:
			return "%s exceeds %s (%d > %d)" % [
				metric_name, gate_name, measured, limit]
	return ""
