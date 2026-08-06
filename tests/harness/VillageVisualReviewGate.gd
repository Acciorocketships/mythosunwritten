extends RefCounted

## Pure validation for the adversarial screenshot-review handoff. Finding a
## defect is a successful review outcome; unresolved defects block *closure*,
## not report validity. This distinction prevents the verifier from rewarding
## a rubber-stamped clean report.
const SEVERITIES := ["P0", "P1", "P2", "P3"]
const DISPOSITIONS := ["clear", "finding", "suspicion"]
const TERMINAL_STATUSES := ["fixed", "dismissed", "accepted"]


static func validate(capture_index: Dictionary, report: Dictionary,
		pins: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var contract: Dictionary = report.get("review_contract", {})
	if String(contract.get("intent", "")) != "falsification":
		errors.append("review intent must be falsification")
	if String(contract.get("success_definition", "")) \
			!= "finding_a_real_issue":
		errors.append("review success must explicitly reward finding a real issue")
	if not bool(contract.get("full_resolution_reviewed", false)):
		errors.append("review must attest original-resolution inspection")

	var capture_ids := _capture_ids(capture_index, errors)
	var finding_by_id: Dictionary = {}
	var findings: Variant = report.get("findings", [])
	if not findings is Array:
		errors.append("findings must be an array")
		findings = []
	for value: Variant in findings:
		if not value is Dictionary:
			errors.append("every finding must be an object")
			continue
		var finding: Dictionary = value
		var finding_id := String(finding.get("id", ""))
		if finding_id.is_empty() or finding_by_id.has(finding_id):
			errors.append("finding ids must be non-empty and unique")
			continue
		finding_by_id[finding_id] = finding
		_validate_finding(finding, capture_ids, errors)

	var accounted: Dictionary = {}
	var reviews: Variant = report.get("captures", [])
	if not reviews is Array:
		errors.append("captures must be an array")
		reviews = []
	for value: Variant in reviews:
		if not value is Dictionary:
			errors.append("every capture review must be an object")
			continue
		var review: Dictionary = value
		var screenshot_id := String(review.get("screenshot_id", ""))
		if not capture_ids.has(screenshot_id):
			errors.append("review references unknown screenshot: %s" % screenshot_id)
		elif accounted.has(screenshot_id):
			errors.append("screenshot reviewed more than once: %s" % screenshot_id)
		else:
			accounted[screenshot_id] = true
		var disposition := String(review.get("disposition", ""))
		if not DISPOSITIONS.has(disposition):
			errors.append("invalid capture disposition: %s" % disposition)
		if String(review.get("notes", "")).strip_edges().is_empty():
			errors.append("capture review requires concrete notes: %s" % screenshot_id)
		var review_findings: Variant = review.get("finding_ids", [])
		if not review_findings is Array:
			errors.append("capture finding_ids must be an array: %s" % screenshot_id)
			continue
		if disposition == "finding" and review_findings.is_empty():
			errors.append("finding disposition requires a finding id: %s" % screenshot_id)
		for id_value: Variant in review_findings:
			if not finding_by_id.has(String(id_value)):
				errors.append("capture references unknown finding: %s" % String(id_value))
	for screenshot_id: String in capture_ids:
		if not accounted.has(screenshot_id):
			errors.append("screenshot is unreviewed: %s" % screenshot_id)

	var pin_by_finding := _pin_findings(pins, errors)
	for finding_id: String in finding_by_id:
		var finding: Dictionary = finding_by_id[finding_id]
		if String(finding.get("status", "")) == "fixed" \
				and not pin_by_finding.has(finding_id):
			errors.append("fixed finding lacks a regression pin: %s" % finding_id)
	return errors


static func closure_errors(capture_index: Dictionary, report: Dictionary,
		pins: Dictionary) -> PackedStringArray:
	var errors := validate(capture_index, report, pins)
	var coverage: Dictionary = capture_index.get("source_coverage", {})
	if not bool(coverage.get("full_spec_complete", false)):
		errors.append("source corpus does not cover the full specification")
	var contract: Dictionary = report.get("review_contract", {})
	if not bool(contract.get("independent_reviewer", false)):
		errors.append("closing pass requires an independent reviewer")
	if not bool(report.get("closing_candidate", false)):
		errors.append("report is not marked as a closing candidate")
	var diagnostics: Dictionary = capture_index.get("view_diagnostics", {})
	if diagnostics.is_empty():
		errors.append("closing capture lacks camera-clearance diagnostics")
	else:
		if int(diagnostics.get("authored_obstructed", 0)) > 0:
			errors.append("closing capture contains obstructed authored views")
		if int(diagnostics.get("unresolved", 0)) > 0:
			errors.append("closing capture contains unresolved camera views")
	var findings: Variant = report.get("findings", [])
	if findings is Array:
		for value: Variant in findings:
			if not value is Dictionary:
				continue
			var finding: Dictionary = value
			if String(finding.get("severity", "")) in ["P0", "P1", "P2"] \
					and not TERMINAL_STATUSES.has(
						String(finding.get("status", ""))):
				errors.append("unresolved closure finding: %s" \
					% String(finding.get("id", "")))
	return errors


static func _capture_ids(capture_index: Dictionary,
		errors: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var captures: Variant = capture_index.get("captures", [])
	if not captures is Array or captures.is_empty():
		errors.append("capture index must contain captures")
		return out
	for value: Variant in captures:
		if not value is Dictionary:
			errors.append("capture index entries must be objects")
			continue
		var screenshot_id := String((value as Dictionary).get("screenshot_id", ""))
		if screenshot_id.is_empty() or out.has(screenshot_id):
			errors.append("capture screenshot ids must be non-empty and unique")
		else:
			out[screenshot_id] = true
	return out


static func _validate_finding(finding: Dictionary, capture_ids: Dictionary,
		errors: PackedStringArray) -> void:
	var finding_id := String(finding.get("id", ""))
	if not SEVERITIES.has(String(finding.get("severity", ""))):
		errors.append("invalid finding severity: %s" % finding_id)
	for field: String in ["evidence", "invariant", "confidence", "status"]:
		if String(finding.get(field, "")).strip_edges().is_empty():
			errors.append("finding %s requires %s" % [finding_id, field])
	var screenshot_ids: Variant = finding.get("screenshot_ids", [])
	if not screenshot_ids is Array or screenshot_ids.is_empty():
		errors.append("finding requires screenshot evidence: %s" % finding_id)
		return
	for value: Variant in screenshot_ids:
		if not capture_ids.has(String(value)):
			errors.append("finding references unknown screenshot: %s" % String(value))


static func _pin_findings(pins: Dictionary,
		errors: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var entries: Variant = pins.get("pins", [])
	if not entries is Array:
		errors.append("pins must be an array")
		return out
	for value: Variant in entries:
		if not value is Dictionary:
			errors.append("every pin must be an object")
			continue
		var pin: Dictionary = value
		var finding_id := String(pin.get("finding_id", ""))
		if finding_id.is_empty() or out.has(finding_id):
			errors.append("pin finding ids must be non-empty and unique")
			continue
		out[finding_id] = pin
		if not pin.has("seed") or String(pin.get("settlement_id", "")).is_empty() \
				or String(pin.get("recipe", "")).is_empty():
			errors.append("pin lacks exact reproduction metadata: %s" % finding_id)
		if String(pin.get("status", "")) == "fixed" \
				and (not pin.get("passing_recaptures", []) is Array \
				or (pin.get("passing_recaptures", []) as Array).is_empty()):
			errors.append("fixed pin lacks a passing recapture: %s" % finding_id)
	return out
