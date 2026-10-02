extends RefCounted
## Signed int64 division truncates toward zero, preserving x/-x symmetry.
## Validated operands are <= 1e9; products <= 1e18 < signed int64 maximum.
static func mul_div(a: int, b: int, denominator: int) -> int:
	assert(absi(a) <= 1000000000 and absi(b) <= 1000000000 and denominator != 0)
	@warning_ignore("integer_division")
	return (a * b) / denominator
