extends RefCounted
## Deterministic combat. An attack is an invisible d20 STR check (ADR-0008) vs the
## defender's `def`; a hit deals the attacker's `atk`. Emits UNAMBIGUOUS events so
## it's clear who did what to whom:
##   player_hit_enemy  {enemy, name, hit, damage, killed}
##   enemy_hit_player  {enemy, name, hit, damage}
##   enemy_slain       {enemy, name}
## (the player's own death is emitted by the scheduler as player_died.)

const D20 = preload("res://scripts/d20.gd")


static func attack(prim, attacker: String, defender: String) -> Dictionary:
	var dc := int(prim.get_prop(defender, "def", 10))
	var hit: bool = prim.roll_check(attacker, "str", dc)
	var dmg := 0
	if hit:
		dmg = maxi(1, int(prim.get_prop(attacker, "atk", 2)))
		prim.damage(defender, dmg)
	var killed := int(prim.get_prop(defender, "hp", 1)) <= 0

	if attacker == "player":
		prim.emit("player_hit_enemy", {
			"enemy": defender, "name": _name(prim, defender),
			"hit": hit, "damage": dmg, "killed": killed})
	else:
		prim.emit("enemy_hit_player", {
			"enemy": attacker, "name": _name(prim, attacker),
			"hit": hit, "damage": dmg})

	if killed and "enemy" in prim.get_object(defender).get("tags", []):
		# A slain enemy becomes a corpse: no longer an enemy to be re-attacked, no
		# longer blocking (walk through it), but destructible.
		prim.remove_tag(defender, "enemy")
		prim.remove_tag(defender, "blocking")
		prim.add_tag(defender, "corpse")
		prim.add_tag(defender, "destructible")
		prim.emit("enemy_slain", {"enemy": defender, "name": _name(prim, defender)})
	return {"hit": hit, "damage": dmg, "killed": killed}


static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and maxi(absi(a.x - b.x), absi(a.y - b.y)) == 1


static func _name(prim, id: String) -> String:
	return str(prim.get_prop(id, "name", "существо"))
