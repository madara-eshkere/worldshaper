extends RefCounted
## Shared d20 rules helpers. Kept tiny and dependency-free so both the Character
## Sheet (display) and the roll_check Primitive (checks) use the same formula.
## Preload it; do not make it an autoload.

## Standard d20 ability modifier: floor((score - 10) / 2). Score 10-11 → +0.
static func ability_mod(score: int) -> int:
	return int(floor((score - 10) / 2.0))
