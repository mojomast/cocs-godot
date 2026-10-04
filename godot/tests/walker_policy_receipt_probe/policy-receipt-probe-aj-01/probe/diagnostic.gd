extends RefCounted
## SOURCE PROPOSAL ONLY. No entry point, world, file IO, or acceptance decision.
## Future caller must hash-bind the immutable AI receipt and these dependencies.
const Policy = preload("res://tests/walker_parity_admission/policy.gd")
const Evidence = preload("res://tests/walker_parity_admission/evidence.gd")

static func operand(v: Variant) -> Dictionary:
	return {"type":typeof(v),"number":v if Evidence.num(v) else null}

static func inspect_failed_negative(r: Dictionary, source_hash: String, grant_hash: String, engine_hash: String) -> Dictionary:
	# All state is per call. Never treat this report as campaign acceptance.
	var report := {"schema":"ai-policy-source-diagnostic-v1","originalPolicyResult":false,"location":"undetermined","nativeCountersKnown":false,"physicalCallCounts":null}
	if Policy.successful(r,"negative-controls",source_hash,grant_hash,engine_hash):
		report.originalPolicyResult = true
		return report
	var records: Variant = r.get("records")
	if not records is Array or records.size()!=34: return report
	var specs: Array = Evidence.canonical("negative-controls")
	for case_index in range(34):
		var profiles: Variant = Evidence.getv(records[case_index],"profiles")
		if not profiles is Array or profiles.size()!=2: return report
		for role in range(2):
			if not profiles[role] is Dictionary: return report
			var p: Dictionary = profiles[role]
			if Evidence.profile(p,specs[case_index],"negative-controls",role==1): continue
			report.location = "Evidence.profile.undetermined"
			report.caseIndex = case_index
			report.profileIndex = role
			# This is an independently failing invariant, not a claim that earlier
			# branches passed. The original predicate result remains authoritative.
			if role!=1: return report
			var settles: Variant = p.get("settle");var frames: Variant = p.get("frames")
			if not settles is Array or settles.size()>20 or not frames is Array or frames.size()>2: return report
			var rows: Array = settles+frames
			for record_index in rows.size():
				var row: Variant = rows[record_index]
				var life: Variant = Evidence.getv(row,"lifecycle")
				var up: Variant = Evidence.getv(row,"appliedUpCount")
				var accepted: Variant = Evidence.getv(Evidence.getv(life,"originalProof"),"accepted")
				var checks := [Evidence.flag(Evidence.getv(life,"returned"),true),Evidence.near(Evidence.getv(life,"frame"),Evidence.getv(row,"frame"),0),Evidence.integer(up),up in [0,1],Evidence.near(Evidence.getv(life,"parentCalls"),1,0),accepted is bool]
				if not false in checks: continue
				report.location = "Evidence.profile.lifecycle_invariant"
				report.sourceLine = 139
				report.recordSection = "settle" if record_index<settles.size() else "frames"
				report.recordIndex = record_index if record_index<settles.size() else record_index-settles.size()
				report.checks = checks
				report.checkOrder = ["returned","frame","integer_up","up_membership","parent_calls","accepted_type"]
				report.up = operand(up)
				report.allowed = [operand(0),operand(1)]
				report.numericAlternative = Evidence.num(up) and (up==0 or up==1)
				return report
			return report
	return report
