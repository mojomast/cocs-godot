extends RefCounted
const Evidence = preload("evidence.gd")
const PHASE := "parity-admission-synthetic-v1"
const MODE := "synthetic-controls"
const GROUPS := ["negative-controls","inclined-landing-rejections","positive-step-admission"]
const COUNTS := [34,4,4]
const KEYS := ["phase","mode","allowedGroups","grantId","authorized","expiresUnix","sourceSha256","engineSha256"]
static func hash_valid(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true
static func grant_valid(g: Dictionary, group: String, mode: String, id: String, source_hash: String, engine_hash: String, now: float) -> bool:
	if g.size()!=KEYS.size(): return false
	for key: String in KEYS:
		if not g.has(key): return false
	if g.phase!=PHASE or g.mode!=MODE or mode!=MODE or not group in GROUPS: return false
	if not g.allowedGroups is Array or g.allowedGroups.is_empty() or not group in g.allowedGroups: return false
	var last := -1
	for item: Variant in g.allowedGroups:
		if not item is String or not item in GROUPS or GROUPS.find(item)<=last: return false
		last = GROUPS.find(item)
	if not g.authorized is bool or not g.authorized or not g.grantId is String or g.grantId!=id or id.is_empty(): return false
	if not (g.expiresUnix is float or g.expiresUnix is int) or not is_finite(float(g.expiresUnix)) or float(g.expiresUnix)<=now: return false
	return hash_valid(source_hash) and hash_valid(engine_hash) and g.sourceSha256==source_hash and g.engineSha256==engine_hash
static func number(value: Variant, expected: int) -> bool:
	return (value is int or value is float) and value==expected
static func successful(r: Dictionary, group: String, source_hash: String, grant_hash: String, engine_hash: String) -> bool:
	if not group in GROUPS: return false
	if r.get("phase")!=PHASE or r.get("mode")!=MODE or r.get("group")!=group or r.get("scope")!="synthetic-admission": return false
	if r.get("sourceSha256")!=source_hash or r.get("grantSha256")!=grant_hash or r.get("engineSha256")!=engine_hash: return false
	if r.get("failed")!=false or r.get("passed")!=true or r.get("nativeStepAdmission")!=false or r.get("productionPromotion")!=false: return false
	for key: String in ["failed","passed","nativeStepAdmission","productionPromotion","positiveAdmission"]:
		if not r.get(key) is bool: return false
	var n: int = COUNTS[GROUPS.find(group)]
	var required := {"attemptedPairs":n,"completedPairs":n,"passedPairs":n,"failedPairs":0,"interruptedPairs":0,"unrunPairs":0,
		"attemptedProfiles":2*n,"completedProfiles":2*n,"failedProfiles":0,"interruptedProfiles":0,"unrunProfiles":0,"candidateMapWalks":0}
	for key: String in required:
		if not number(r.get(key),required[key]): return false
	if r.get("positiveAdmission")!=(group==GROUPS[2]) or not r.get("records") is Array or r.records.size()!=n: return false
	for i in range(n):
		if not r.records[i] is Dictionary: return false
		var row: Dictionary = r.records[i]
		if not number(row.get("caseIndex"),i) or row.get("status")!="passed" or not row.get("profiles") is Array or row.profiles.size()!=2: return false
		for j in range(2):
			if not row.profiles[j] is Dictionary: return false
			var p: Dictionary = row.profiles[j]
			if p.get("status")!="completed" or not p.get("experimental") is bool or p.get("experimental")!=(j==1): return false
			if group!=GROUPS[2] and (not number(p.get("appliedUpCount"),0) or not number(p.get("verifiedLifts"),0)): return false
			if group==GROUPS[2]:
				if not p.get("reached") is bool: return false
				if j==0 and (p.get("outcome")!="expected_baseline_blocked" or p.get("reached")!=false or not number(p.get("appliedUpCount"),0) or not number(p.get("verifiedLifts"),0)): return false
				if j==1 and (p.get("outcome")!="full_tread_guarded_arrival" or p.get("reached")!=true or not (p.get("verifiedLifts") is int or p.get("verifiedLifts") is float) or p.verifiedLifts<1 or p.get("appliedUpCount")!=p.verifiedLifts): return false
	return Evidence.campaign(r,group)
