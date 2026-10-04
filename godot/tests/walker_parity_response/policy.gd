extends RefCounted
const PHASE := "parity-response-only-v1"
const MODE := "single-response"
const GROUP := "parity-response"
const KEYS := ["phase","mode","allowedGroups","grantId","authorized","expiresUnix","sourceSha256","engineSha256"]
static func hash_valid(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true
static func grant_valid(grant: Dictionary, group: String, mode: String, id: String, source_hash: String, binary_hash: String, now: float) -> bool:
	if grant.size()!=KEYS.size(): return false
	for key: String in KEYS:
		if not grant.has(key): return false
	if group!=GROUP or mode!=MODE or grant.phase!=PHASE or grant.mode!=MODE: return false
	if not grant.allowedGroups is Array or grant.allowedGroups!=[GROUP]: return false
	if not grant.authorized is bool or grant.authorized!=true or not grant.grantId is String or grant.grantId.is_empty() or grant.grantId!=id: return false
	if not (grant.expiresUnix is float or grant.expiresUnix is int) or not is_finite(float(grant.expiresUnix)) or float(grant.expiresUnix)<=now: return false
	return hash_valid(source_hash) and hash_valid(binary_hash) and grant.sourceSha256==source_hash and grant.engineSha256==binary_hash
