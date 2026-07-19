extends RefCounted
## Deterministic combat resolution. An attack is an invisible d20 Check (ADR-0008)
## of the attacker's STR against the defender's `def`; a hit deals the attacker's
## `atk`. Static helper over the Primitives; emits "attack"/"died" for narration
## and UI. No LLM.

const D20 = preload("res://scripts/d20.gd")


static func attack(prim, attacker: String, defender: String) -> Dictionary:
	var dc := int(prim.get_prop(defender, "def", 10))
	var hit: bool = prim.roll_check(attacker, "str", dc)
	var dmg := 0
	if hit:
		dmg = maxi(1, int(prim.get_prop(attacker, "atk", 2)))
		prim.damage(defender, dmg)
	prim.emit("attack", {"attacker": attacker, "defender": defender, "hit": hit, "damage": dmg})
	if int(prim.get_prop(defender, "hp", 1)) <= 0:
		prim.emit("died", {"who": defender})
	return {"hit": hit, "damage": dmg}


## Chebyshev adjacency (8-directional) on the grid.
static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and maxi(absi(a.x - b.x), absi(a.y - b.y)) == 1
