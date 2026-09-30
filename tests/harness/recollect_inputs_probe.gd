extends RefCounted
## Review probe for cliff_site_review: re-frames the rock rebuild inputs from
## the current view list (views added later through views.txt), so the next
## reload also rebuilds the chunks those views frame.
func run(review: Node) -> void:
	review._collect_inputs()
	print("[recollect_inputs] ", review._inputs.size())
